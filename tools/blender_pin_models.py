"""Fumble: je MODUL sein PIN - der EINE Körper eines Moduls (Welle D, Plan
docs/plan_kombi_grosschip.md; Familien und Bauteile docs/plan_modul_bauteile.md), im
PRÄZISIONS-Stil (Licht als Vertexfarben eingemalt).

Aufruf (kopflos):
  blender -b -P tools/blender_pin_models.py -- assets/models/hardware [id ...]

pin_<id>.glb und pin_empty.glb (der leere Platz: nur ein dunkler Grund - den
Rahmen des Platzes baut Godot). Ursprung = die rechte Gehäusekante des Chips auf dem Tisch; der
Pin zeigt nach Bild-rechts (u), quer ist Bild-oben (v), z die Höhe. Hüllmaß PIN_U × PIN_V × PIN_Z
(spiegelt ComboPartBody.HULL). glTF: Godot (x, y, z) = (v, z, u).
Die FAMILIE gibt Grundform und Material (Speicher Keramik-Riegel, Wandler Graphit mit Gold,
Kontakte Stahl-Gabel, Röhren Glas, Abgriffe Stahl-Klinge, Brücken Pfeil), jedes Modul eine
eigene Silhouette und ein großes Licht-Merkmal. Knoten: Korpus, Licht, optional Glas und Abbild,
Zustands-Teile (Ziffer0-2, Lampe0-4, Ring0-4, Klemme0-2, Flamme) setzt Godot.
"""
import bmesh, bpy, math, os, sys
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/hardware"
ONLY = set(ARGS[1:])
os.makedirs(OUT, exist_ok=True)
STEPS = 48

# Spiegelt ComboPartBody.HULL: wer es dort ändert, zieht es hier nach.
PIN_U, PIN_V, PIN_Z = 1.7, 0.85, 0.6
NECK = -0.04  # so weit steckt jeder Pin im Gehäuse
AX = 0.28     # Achshöhe der liegenden Körper

STEEL = (0.7, 0.73, 0.8)
COPPER = (1.0, 0.52, 0.26)
GOLD = (1.0, 0.76, 0.32)
BLACK = (0.04, 0.043, 0.055)
GRAPHITE = (0.3, 0.31, 0.37)
CERAMIC = (0.9, 0.85, 0.72)
SOLDER = (0.8, 0.82, 0.86)
ALU = (0.78, 0.8, 0.86)
GLASS_VIOLET = (0.8, 0.66, 1.0)

LIGHT = Vector((-0.35, 0.45, 0.82)).normalized()
VIEW = Vector((-0.42, 0.1, 0.9)).normalized()
HALF = (LIGHT + VIEW).normalized()


# --- Helfer (aus dem gestorbenen tools/blender_part_models.py) ---------------------------------

def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def matcap(kind, base, n):
    n = n.normalized()
    ndl = max(0.0, n.dot(LIGHT))
    spec = max(0.0, n.dot(HALF))
    fres = 1.0 - abs(n.dot(VIEW))
    r = 2.0 * n.dot(VIEW) * n - VIEW
    env = 0.3 + 0.72 * smooth(0.05, 0.75, r.z) + 0.55 * smooth(0.965, 0.995, r.dot(LIGHT))
    alpha = 1.0
    if kind == "metal":
        col = [c * env for c in base]
        add = spec ** 90 * 0.8
    elif kind == "gloss":
        col = [c * (0.7 + 0.7 * ndl) for c in base]
        add = spec ** 120 * 1.1 + fres ** 3 * 0.22
    elif kind == "glass":
        col = list(base)
        add = spec ** 150 * 1.3
        alpha = min(1.0, 0.1 + fres ** 2.2 * 0.6 + spec ** 150)
    else:
        col = [c * (0.85 + 0.2 * ndl) for c in base]
        add = 0.0
    return (*[min(1.6, c + add) for c in col], alpha)


def paint(obj, kind, base=(1, 1, 1)):
    mesh = obj.data
    mesh.calc_normals_split()
    attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    world = obj.matrix_world
    for loop in mesh.loops:
        co = world @ mesh.vertices[loop.vertex_index].co
        c = matcap(kind, base, world.to_3x3() @ Vector(loop.normal))
        # Kontaktschatten: wo der Körper auf dem Tisch steht, wird er dunkler.
        if kind not in ("glass", "flat"):
            ao = 0.6 + 0.4 * smooth(-0.01, 0.07, co.z)
            c = (c[0] * ao, c[1] * ao, c[2] * ao, c[3])
        attr.data[loop.index].color = c
    mesh.color_attributes.active_color = attr
    return obj


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    global MAT
    MAT = bpy.data.materials.new("Basis")
    MAT.use_nodes = True


def finish(name, bm, smooth_on=True, angle=38.0):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(MAT)
    for poly in mesh.polygons:
        poly.use_smooth = smooth_on
    mesh.use_auto_smooth = True
    mesh.auto_smooth_angle = math.radians(angle)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def lathe(name, profile, center=(0, 0, 0), axis="Z", steps=STEPS, angle=38.0, squash=(1, 1), caps=True):
    bm = bmesh.new()
    rings = []
    for radius, along_ in profile:
        ring_ = []
        for i in range(steps):
            a = 2 * math.pi * i / steps
            c, s = radius * math.cos(a) * squash[0], radius * math.sin(a) * squash[1]
            co = {"Z": (c, s, along_), "Y": (c, along_, s), "X": (along_, c, s)}[axis]
            ring_.append(bm.verts.new(Vector(co) + Vector(center)))
        rings.append(ring_)
    for k in range(len(rings) - 1):
        for i in range(steps):
            j = (i + 1) % steps
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    if caps and profile[0][0] > 0:
        bm.faces.new(rings[0])
    if caps and profile[-1][0] > 0:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return finish(name, bm, True, angle)


def prism(name, outline, z0, z1, smooth_on=False):
    bm = bmesh.new()
    low = [bm.verts.new((x, y, z0)) for x, y in outline]
    high = [bm.verts.new((x, y, z1)) for x, y in outline]
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((low[i], low[j], high[j], high[i]))
    bm.faces.new(low)
    bm.faces.new(high)
    return finish(name, bm, smooth_on)


def join(name, objects):
    objects = [o for o in objects if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    joined.data.name = name
    return joined


def B(u, v, z=0.0):
    return (v, -u, z)


def uv_outline(points):
    return [(v, -u) for u, v in points]


def R(wu, hv, cu=0.0, cv=0.0):
    return uv_outline([(cu - wu / 2, cv - hv / 2), (cu + wu / 2, cv - hv / 2), (cu + wu / 2, cv + hv / 2), (cu - wu / 2, cv + hv / 2)])


def box(name, wu, hv, z0, z1, cu=0.0, cv=0.0):
    return prism(name, R(wu, hv, cu, cv), z0, z1)


def rounded_uv(hu, hv, radius, cu=0.0, cv=0.0):
    out = []
    for su, sv, start in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for k in range(7):
            a = math.radians(start + 90 * k / 6)
            out.append((cu + su * (hu - radius) + radius * math.cos(a), cv + sv * (hv - radius) + radius * math.sin(a)))
    return uv_outline(out)


def slab(name, hu, hv, radius, z0, z1, cu=0.0, cv=0.0):
    return prism(name, rounded_uv(hu, hv, radius, cu, cv), z0, z1)


def cyl(name, r, z0, z1, cu=0.0, cv=0.0, chamfer=0.0, steps=40):
    prof = [(r, z0), (r, z1 - chamfer)]
    if chamfer:
        prof.append((r - chamfer, z1))
    prof.append((0.0, z1))
    return lathe(name, prof, B(cu, cv), steps=steps, angle=30)


def dome(name, profile, cu=0.0, cv=0.0, steps=32):
    """Drehkörper um die Hochachse: profile = (Radius, Höhe)."""
    return lathe(name, profile, B(cu, cv), steps=steps, angle=40)


def ring(name, r0, r1, z0, z1, cu=0.0, cv=0.0, steps=48):
    return lathe(name, [(r0, z0), (r1, z0), (r1, z1), (r0, z1), (r0, z0)], B(cu, cv), steps=steps, angle=30, caps=False)


def along(name, profile, cu=0.0, cv=0.0, zc=AX, squash=(1, 1), steps=STEPS, caps=True):
    """Drehkörper längs des Pins: profile = (Radius, u relativ zu cu); squash = (Bild-oben, Höhe)."""
    return lathe(name, [(r, -u) for r, u in profile], B(cu, cv, zc), "Y", steps, 30, squash, caps)


def band(name, r0, r1, half, cu, cv=0.0, zc=AX, squash=(1, 1)):
    """Ein Ring um die Pin-Achse (Wicklung, Gitter, Korona)."""
    return along(name, [(r0, -half), (r1, -half), (r1, half), (r0, half), (r0, -half)], cu, cv, zc, squash, caps=False)


def bar(name, a, b, width, z0, z1):
    """Flacher Steg von a nach b (je (u, v)), width quer dazu."""
    du, dv = b[0] - a[0], b[1] - a[1]
    length = math.hypot(du, dv)
    nu, nv = -dv / length * width / 2, du / length * width / 2
    pts = [(a[0] + nu, a[1] + nv), (b[0] + nu, b[1] + nv), (b[0] - nu, b[1] - nv), (a[0] - nu, a[1] - nv)]
    return prism(name, uv_outline(pts), z0, z1)


def anchor(name, u, v, z):
    empty = bpy.data.objects.new(name, None)
    empty.location = B(u, v, z)
    bpy.context.collection.objects.link(empty)
    return empty


def capsule(r, half, edge=0.04):
    return [(0.0, -half), (r - edge, -half), (r, -half + edge), (r, half - edge), (r - edge, half), (0.0, half)]


def ribbed(r_out, r_in, u0, u1, turns):
    prof = [(0.0, u0), (r_in, u0)]
    for i in range(turns + 1):
        prof.append((r_out if i % 2 == 0 else r_in, u0 + (u1 - u0) * i / turns))
    prof += [(r_in, u1), (0.0, u1)]
    return prof


def export(name):
    # Jeder Pin sitzt DIREKT am Gehäuse: alles rückt, bis sein Anfang im Chip steckt.
    # Ohne Hals füllt er den Platz wieder aus: gleichmäßig wachsen, bis Länge, Tiefe oder Höhe anstößt.
    pts = [o.matrix_world @ v.co for o in bpy.data.objects if o.type == "MESH" for v in o.data.vertices]
    length = max(q.y for q in pts) - min(q.y for q in pts)
    grow = min((PIN_U - 0.02) / length, PIN_V / (2.0 * max(abs(q.x) for q in pts)), PIN_Z / max(q.z for q in pts))
    if name == "empty":
        grow = 1.0
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.data.transform(Matrix.Scale(grow, 4) @ o.matrix_world)
            o.matrix_world = Matrix.Identity(4)
        elif o.parent is None:
            o.location = o.location * grow
    reach = max(q.y for q in pts) * grow
    for o in bpy.data.objects:
        if o.parent is None:
            o.location.y += -NECK - reach
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "pin_%s.glb" % name), use_selection=True,
                              export_apply=True, export_format="GLB", export_colors=True)
    print("BUILT pin", name)


def neck():
    """Kein Hals mehr (Spieler-Wunsch 2026-11-21): das Modul sitzt selbst am Gehäuse."""
    return None


def arrow(name, pts, width, head_w, head_len, z0, z1):
    """Flacher Pfeil: Schaft längs pts, die Spitze sitzt am letzten Punkt und zeigt in Laufrichtung."""
    a, b = pts[-2], pts[-1]
    du, dv = b[0] - a[0], b[1] - a[1]
    length = math.hypot(du, dv)
    du, dv = du / length, dv / length
    base = (b[0] - du * head_len, b[1] - dv * head_len)
    shaft = list(pts[:-1]) + [base]
    pieces = [bar(name, p, q, width, z0, z1) for p, q in zip(shaft, shaft[1:])]
    # Knicke bekommen ein volles Eck, sonst fehlte dort eine Ecke.
    pieces += [box(name, width, width, z0, z1, p[0], p[1]) for p in shaft[1:-1]]
    nu, nv = -dv * head_w / 2, du * head_w / 2
    pieces.append(prism(name, uv_outline([(base[0] + nu, base[1] + nv), b, (base[0] - nu, base[1] - nv)]), z0, z1))
    return pieces


# --- SPEICHER (Punkte): liegender Keramik-Riegel -----------------------------------------------

def resistor():
    """Widerstand: der schlichte Riegel, drei breite Farbringe."""
    reset()
    join("Korpus", [neck(), paint(along("Riegel", capsule(0.22, 0.66), 0.96, squash=(1.3, 1.0)), "gloss", CERAMIC)])
    join("Licht", [band("Ring", 0.222, 0.232, 0.07, u, squash=(1.3, 1.0)) for u in (0.62, 0.96, 1.3)])
    export("resistor")


def coil():
    """Spule: Spulenkörper mit zwei breiten Leucht-Flanschen (Hantel), Kupferwicklung dazwischen."""
    reset()
    parts = [neck(), paint(along("Kern", capsule(0.12, 0.68), 0.96), "gloss", GRAPHITE),
             paint(along("Wicklung", ribbed(0.19, 0.175, -0.48, 0.48, 16), 0.96, squash=(1.2, 1.0)), "metal", COPPER)]
    join("Korpus", parts)
    join("Licht", [along("Flansch", capsule(0.27, 0.05, 0.015), u, squash=(1.5, 1.0)) for u in (0.4, 1.52)])
    export("coil")


def series_resistor():
    """Vorwiderstand: ein Kamm - Riegel oben, sechs Zinken hängen nach Bild-unten."""
    reset()
    parts = [neck(), paint(along("Riegel", capsule(0.12, 0.66), 0.96, 0.24, AX, (1.0, 1.0)), "gloss", CERAMIC)]
    lights = []
    for i in range(6):
        u = 0.45 + i * 0.205
        parts.append(paint(box("Zahn", 0.09, 0.34, 0.12, 0.3, u, 0.04), "gloss", CERAMIC))
        lights.append(box("Spitze", 0.12, 0.2, 0.1, 0.32, u, -0.31))
    join("Korpus", parts)
    join("Licht", lights)
    export("series_resistor")


def series_terminal():
    """Reihenklemme: Klemmleiste mit drei breiten Klemmen (Sägezahn), Schrauben leuchten je Modul."""
    reset()
    parts = [neck(), paint(box("Leiste", 1.3, 0.42, 0.0, 0.28, 0.95, 0.0), "gloss", CERAMIC)]
    for i in range(3):
        u = 0.55 + i * 0.4
        parts.append(paint(slab("Klemmblock", 0.15, 0.41, 0.04, 0.0, 0.38, u, 0.0), "gloss", CERAMIC))
        parts.append(paint(cyl("Schraube", 0.09, 0.38, 0.44, u, 0.12, 0.02, 24), "metal", STEEL))
        parts.append(paint(box("Schlitz", 0.03, 0.14, 0.44, 0.445, u, 0.12), "gloss", BLACK))
        ring("Klemme%d" % i, 0.1, 0.15, 0.38, 0.41, u, 0.12, 32)
    join("Korpus", parts)
    join("Licht", [box("Lichtstrich", 0.11, 0.08, 0.38, 0.4, 0.55 + i * 0.4, -0.25) for i in range(3)])
    export("series_terminal")


# --- WANDLER (Mult +): Graphit mit goldener Stirn ----------------------------------------------

def gold_stirn(u, hv, z1):
    return paint(box("Stirn", 0.06, hv, 0.0, z1, u, 0.0), "metal", GOLD)


def capacitor():
    """Kondensator: der hohe runde Becher, ein großes Kreuz im Deckel."""
    reset()
    parts = [neck(), paint(box("Fuss", 0.6, 0.3, 0.0, 0.2, 0.5, 0.0), "gloss", GRAPHITE),
             paint(cyl("Becher", 0.38, 0.0, 0.5, 1.2, 0.0, 0.04, 56), "gloss", GRAPHITE),
             paint(ring("Huelse", 0.38, 0.4, 0.0, 0.4, 1.2, 0.0, 56), "metal", GOLD)]
    join("Korpus", parts)
    join("Licht", [box("Kreuz", 0.56, 0.14, 0.5, 0.52, 1.2, 0.0), box("Kreuz", 0.14, 0.56, 0.5, 0.52, 1.2, 0.0)])
    export("capacitor")


def solder_joint():
    """Lötpunkt: lange flache Leiste, sechs große leuchtende Zinnkuppen (eine je Würfel)."""
    reset()
    parts = [neck(), paint(slab("Leiste", 0.68, 0.36, 0.06, 0.0, 0.16, 0.96, 0.0), "gloss", GRAPHITE),
             gold_stirn(1.64, 0.6, 0.2)]
    lights = []
    for a in range(3):
        for b in (-1, 1):
            u, v = 0.55 + a * 0.4, b * 0.17
            parts.append(paint(ring("Pad", 0.13, 0.15, 0.16, 0.18, u, v, 32), "metal", SOLDER))
            lights.append(dome("Kuppe", [(0.13, 0.16), (0.125, 0.22), (0.08, 0.27), (0.0, 0.29)], u, v))
    join("Korpus", parts)
    join("Licht", lights)
    export("solder_joint")


def counter_part():
    """Zählwerk: Kasten mit großem schwarzem Ziffernfenster."""
    reset()
    parts = [neck(), paint(slab("Kasten", 0.66, 0.41, 0.08, 0.0, 0.4, 0.96, 0.0), "gloss", GRAPHITE),
             paint(box("Fenster", 1.08, 0.54, 0.4, 0.41, 0.92, 0.04), "gloss", BLACK),
             gold_stirn(1.63, 0.7, 0.42)]
    for i in range(3):
        anchor("Ziffer%d" % i, 0.56 + i * 0.36, 0.04, 0.415)
    join("Korpus", parts)
    box("Licht", 1.08, 0.07, 0.4, 0.42, 0.92, -0.3)
    export("counter")


def error_memory():
    """Fehlerspeicher: EPROM mit Beinchen (Tausendfüßler), Quarzfenster, fünf rote Lampen."""
    reset()
    parts = [neck(), paint(box("Baustein", 1.3, 0.46, 0.05, 0.3, 0.96, 0.0), "gloss", GRAPHITE),
             paint(ring("Fassung", 0.17, 0.21, 0.3, 0.32, 0.5, 0.0, 40), "metal", GOLD)]
    for i in range(6):
        for s in (-1, 1):
            parts.append(paint(box("Bein", 0.08, 0.16, 0.0, 0.12, 0.45 + i * 0.205, s * 0.33), "metal", STEEL))
    for i in range(5):
        cyl("Lampe%d" % i, 0.08, 0.3, 0.34, 0.82 + i * 0.19, 0.0, 0.02, 24)
    join("Korpus", parts)
    paint(cyl("Glas", 0.17, 0.3, 0.33, 0.5, 0.0, steps=40), "glass", GLASS_VIOLET)
    cyl("Licht", 0.13, 0.3, 0.325, 0.5, 0.0, steps=32)
    export("error_memory")


def starter():
    """Anlasser: eckige Blende, darauf der große runde Knopf mit Ein-Zeichen."""
    reset()
    parts = [neck(), paint(slab("Blende", 0.5, 0.41, 0.08, 0.0, 0.2, 1.12, 0.0), "gloss", GRAPHITE),
             paint(box("Steg", 0.3, 0.3, 0.0, 0.2, 0.47, 0.0), "gloss", GRAPHITE),
             paint(dome("Knopf", [(0.33, 0.2), (0.33, 0.3), (0.3, 0.36), (0.0, 0.38)], 1.12, 0.0), "gloss", BLACK)]
    join("Korpus", parts)
    lights = []
    for k in range(10):
        a0, a1 = math.radians(120 + 30 * k), math.radians(150 + 30 * k)
        lights.append(bar("Zeichen", (1.12 + 0.22 * math.cos(a0), 0.22 * math.sin(a0)),
                          (1.12 + 0.22 * math.cos(a1), 0.22 * math.sin(a1)), 0.07, 0.36, 0.39))
    lights.append(bar("Zeichen", (1.12, 0.0), (1.12, 0.3), 0.08, 0.37, 0.4))
    join("Licht", lights)
    export("starter")


# --- KONTAKTE (Würfel): Stahl-Gabel, leuchtende Spitzen ----------------------------------------

def yoke(hv):
    return paint(box("Joch", 0.18, hv, 0.0, 0.32, 0.34, 0.0), "metal", STEEL)


def prong(u1, v, width=0.12):
    return paint(box("Zinke", u1 - 0.42, width, 0.12, 0.26, (0.42 + u1) * 0.5, v), "metal", STEEL)


def relay():
    """Relais: die OBERE Zinke lang mit großer Leuchtspitze, die untere kurz in einer Kupferspule."""
    reset()
    parts = [neck(), yoke(0.74), prong(1.36, 0.24), prong(0.95, -0.22),
             paint(along("Spule", ribbed(0.17, 0.15, -0.22, 0.22, 8), 0.68, -0.22, 0.19), "metal", COPPER)]
    join("Korpus", parts)
    box("Licht", 0.32, 0.28, 0.1, 0.3, 1.52, 0.24)
    export("relay")


def output_stage():
    """Endstufe: Spiegelbild des Relais - die UNTERE Zinke leuchtet, breite Kühlrippen am Joch."""
    reset()
    parts = [neck(), yoke(0.74), prong(1.36, -0.24), prong(0.95, 0.22)]
    for i in range(4):
        parts.append(paint(box("Rippe", 0.05, 0.84, 0.0, 0.4, 0.5 + i * 0.1, 0.0), "metal", ALU))
    join("Korpus", parts)
    box("Licht", 0.32, 0.28, 0.1, 0.3, 1.52, -0.24)
    export("output_stage")


def shunt():
    """Nebenschluss: zwei Zinken, am Ende zu einem geschlossenen Kupfer-Ring verbunden."""
    reset()
    parts = [neck(), yoke(0.74), prong(1.2, 0.28), prong(1.2, -0.28),
             paint(box("Buegel", 0.14, 0.7, 0.1, 0.3, 0.72, 0.0), "metal", COPPER)]
    join("Korpus", parts)
    join("Licht", [bar("Schleife", (1.2, 0.3), (1.6, 0.3), 0.12, 0.1, 0.3),
                   bar("Schleife", (1.6, 0.36), (1.6, -0.36), 0.14, 0.1, 0.3),
                   bar("Schleife", (1.6, -0.3), (1.2, -0.3), 0.12, 0.1, 0.3)])
    export("shunt")


def parallel_circuit():
    """Parallelschaltung: ein Rechen aus vier Zinken, alle Spitzen leuchten."""
    reset()
    parts = [neck(), yoke(0.84)]
    lights = []
    for v in (0.33, 0.11, -0.11, -0.33):
        parts.append(prong(1.36, v, 0.09))
        lights.append(box("Spitze", 0.3, 0.13, 0.1, 0.3, 1.52, v))
    join("Korpus", parts)
    join("Licht", lights)
    export("parallel_circuit")


# --- RÖHREN (Mult ×): Glaskolben mit Glutkern --------------------------------------------------

def foot(u, r):
    return paint(along("Fuss", [(0.0, -0.04), (r, -0.04), (r, 0.04), (0.0, 0.04)], u), "metal", STEEL)


def amplifier_tube():
    """Verstärkerröhre: die schlanke lange Röhre, ein langer heller Kern, zwei Gitter."""
    reset()
    paint(along("Glas", capsule(0.18, 0.62), 0.98), "glass", GLASS_VIOLET)
    parts = [neck(), foot(0.36, 0.2)]
    for u in (0.8, 1.16):
        parts.append(paint(band("Gitter", 0.18, 0.2, 0.025, u), "metal", STEEL))
    join("Korpus", parts)
    along("Licht", capsule(0.1, 0.56, 0.03), 0.98)
    export("amplifier_tube")


def high_voltage_tube():
    """Hochspannungsröhre: dicker Kolben, breiter Koronaring, große Anodenkugel am Ende."""
    reset()
    paint(along("Glas", capsule(0.24, 0.38), 0.78), "glass", GLASS_VIOLET)
    parts = [neck(), foot(0.36, 0.26),
             paint(along("Kugel", [(0.0, -0.22), (0.15, -0.16), (0.22, 0.0), (0.15, 0.16), (0.0, 0.22)], 1.42),
                   "metal", STEEL)]
    join("Korpus", parts)
    join("Licht", [along("Kern", capsule(0.12, 0.3, 0.03), 0.78),
                   band("Korona", 0.26, 0.4, 0.04, 0.78, squash=(1.0, 0.68)),
                   along("Anode", [(0.0, -0.1), (0.1, -0.06), (0.12, 0.0), (0.1, 0.06), (0.0, 0.1)], 1.42, zc=AX + 0.17)])
    export("high_voltage_tube")


def resonator():
    """Schwingkreis: dünne Röhre in fünf breiten Windungen - sie füllen sich mit dem Wachstum."""
    reset()
    paint(along("Glas", capsule(0.13, 0.62), 0.98), "glass", GLASS_VIOLET)
    join("Korpus", [neck(), foot(0.36, 0.15)])
    along("Licht", capsule(0.07, 0.58, 0.02), 0.98)
    for k in range(5):
        band("Ring%d" % k, 0.15, 0.27, 0.045, 0.62 + k * 0.18)
    export("resonator")


def afterburner():
    """Nachbrenner: kurze Röhre, weit offene Düse (Trompete), dahinter die Flamme."""
    reset()
    paint(along("Glas", capsule(0.16, 0.26), 0.62), "glass", GLASS_VIOLET)
    parts = [neck(), foot(0.36, 0.18),
             paint(along("Duese", [(0.15, -0.26), (0.2, -0.1), (0.3, 0.06), (0.4, 0.2), (0.36, 0.2), (0.26, 0.06),
                                   (0.16, -0.1), (0.12, -0.26)], 1.1, squash=(1.0, 0.68), caps=False), "metal", STEEL)]
    join("Korpus", parts)
    along("Licht", capsule(0.09, 0.22, 0.02), 0.62)
    along("Flamme", [(0.0, -0.08), (0.28, -0.04), (0.2, 0.1), (0.1, 0.22), (0.0, 0.28)], 1.38, squash=(1.0, 0.95), steps=24)
    export("afterburner")


# --- ABGRIFFE (Ökonomie): flache Stahl-Klinge --------------------------------------------------

def blade(u0, u1, hv):
    return paint(slab("Klinge", (u1 - u0) * 0.5, hv, 0.06, 0.08, 0.16, (u0 + u1) * 0.5, 0.0), "metal", STEEL)


def coin_validator():
    """Münzprüfer: kurze Klinge, am Ende eine große Goldmünze."""
    reset()
    parts = [neck(), blade(0.2, 1.0, 0.2),
             paint(dome("Muenze", [(0.38, 0.08), (0.38, 0.2), (0.35, 0.24), (0.0, 0.24)], 1.3, 0.0, 48), "metal", GOLD),
             paint(ring("Rand", 0.28, 0.32, 0.24, 0.25, 1.3, 0.0, 48), "metal", COPPER)]
    join("Korpus", parts)
    join("Licht", [box("Schlitz", 0.5, 0.08, 0.16, 0.18, 0.62, 0.0), cyl("Praegung", 0.16, 0.24, 0.26, 1.3, 0.0, steps=32)])
    export("coin_validator")


def power_pickup():
    """Stromabnehmer: Klinge mit großem Blitz, am Ende der Schleifbügel quer (ein T)."""
    reset()
    parts = [neck(), blade(0.2, 1.42, 0.2),
             paint(box("Buegel", 0.16, 0.84, 0.0, 0.26, 1.54, 0.0), "metal", COPPER)]
    join("Korpus", parts)
    zig = [(0.32, -0.12), (0.62, 0.15), (0.82, -0.12), (1.12, 0.15), (1.36, -0.06)]
    join("Licht", [bar("Funke", a, b, 0.09, 0.16, 0.19) for a, b in zip(zig, zig[1:])])
    export("power_pickup")


def blocking_diode():
    """Sperrdiode: lange schmale Klinge, darauf groß das Schaltzeichen Dreieck-Strich."""
    reset()
    join("Korpus", [neck(), blade(0.2, 1.66, 0.3)])
    join("Licht", [prism("Dreieck", uv_outline([(0.45, 0.25), (0.45, -0.25), (1.15, 0.0)]), 0.16, 0.19),
                   box("Strich", 0.12, 0.54, 0.16, 0.19, 1.24, 0.0)])
    export("blocking_diode")


# --- BRÜCKEN (Verbindung): der Pfeil selbst ist die Form ---------------------------------------

def bridge_parts(pts, head_w, head_len):
    """Dunkler Pfeil-Körper und darauf derselbe Pfeil in Licht, eine Spur schmaler."""
    body = [paint(p, "gloss", GRAPHITE) for p in arrow("Bahn", pts, 0.3, head_w, head_len, 0.1, 0.18)]
    light = arrow("Pfeil", pts, 0.18, head_w - 0.16, head_len - 0.1, 0.18, 0.22)
    return body, light


def cross_bridge():
    """Querbrücke: ein großer Pfeil nach Bild-rechts."""
    reset()
    body, light = bridge_parts([(0.2, 0.0), (1.68, 0.0)], 0.84, 0.5)
    join("Korpus", [neck()] + body)
    join("Licht", light)
    export("cross_bridge")


def down_bridge():
    """Längsbrücke: ein Haken - erst nach rechts, dann nach Bild-unten."""
    reset()
    body, light = bridge_parts([(0.2, 0.18), (1.3, 0.18), (1.3, -0.42)], 0.7, 0.36)
    join("Korpus", [neck()] + body)
    join("Licht", light)
    export("down_bridge")


def coupling():
    """Kopplung: ein Pfeil zurück nach links, rechts das Feld, in dem das kopierte Modul leuchtet."""
    reset()
    body, light = bridge_parts([(1.0, 0.0), (0.26, 0.0)], 0.7, 0.36)
    frame = [bar("Rahmen", (1.08, 0.36), (1.66, 0.36), 0.1, 0.1, 0.2), bar("Rahmen", (1.08, -0.36), (1.66, -0.36), 0.1, 0.1, 0.2),
             bar("Rahmen", (1.13, 0.4), (1.13, -0.4), 0.1, 0.1, 0.2), bar("Rahmen", (1.61, 0.4), (1.61, -0.4), 0.1, 0.1, 0.2)]
    join("Korpus", [neck()] + body + [paint(f, "metal", STEEL) for f in frame])
    join("Licht", light)
    box("Abbild", 0.38, 0.58, 0.1, 0.17, 1.37, 0.0)
    export("coupling")


# --- Der leere Platz ---------------------------------------------------------------------------

def empty():
    """Nur ein dunkler Grund - kein Pin, ein freier Platz (den Rahmen baut Godot)."""
    reset()
    join("Korpus", [paint(slab("Grund", 0.7, 0.34, 0.1, 0.0, 0.015, 0.95, 0.0), "gloss", BLACK)])
    export("empty")


BUILDS = {"resistor": resistor, "coil": coil, "series_resistor": series_resistor, "series_terminal": series_terminal,
          "capacitor": capacitor, "solder_joint": solder_joint, "counter": counter_part, "error_memory": error_memory,
          "starter": starter, "relay": relay, "output_stage": output_stage, "shunt": shunt,
          "parallel_circuit": parallel_circuit, "amplifier_tube": amplifier_tube,
          "high_voltage_tube": high_voltage_tube, "resonator": resonator,
          "afterburner": afterburner, "coin_validator": coin_validator, "power_pickup": power_pickup,
          "blocking_diode": blocking_diode, "cross_bridge": cross_bridge, "down_bridge": down_bridge,
          "coupling": coupling, "empty": empty}

for name, build in BUILDS.items():
    if not ONLY or name in ONLY:
        build()
