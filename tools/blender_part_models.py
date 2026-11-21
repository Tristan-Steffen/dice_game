"""Fumble: je MODUL ein Bauteil auf der Signalleitung (Welle B, Plan docs/plan_kombi_grosschip.md
und docs/plan_modul_bauteile.md), im PRÄZISIONS-Stil (Spieler-Wahl 2026-11-06).

Aufruf (kopflos):
  blender -b -P tools/blender_part_models.py -- assets/models/hardware [id ...]

part_<id>.glb, Ursprung = Mitte des HÜLLMASSES auf der Oberseite der PLATTE (die Platte baut
Godot, ComboPartBody.PLATE; das Modell steht um ComboPartBody.MODEL_SHIFT zur Bild-oberen
Kante gerückt). Hüllmaß HULL_U längs der Leitung (Bild-rechts) × HULL_V quer (Bild-oben),
Höhe über der Platte nach Seltenheit (RISE). glTF: Godot (x, y, z) = Blender (x, -z, y),
also Bild-oben = Blender +X, Bild-rechts = Blender -Y; gebaut wird in (u, v, z) = (Bild-rechts,
Bild-oben, Höhe) über die Helfer unten.

Knoten: Korpus (Licht eingemalt als Vertexfarben, der Tisch ist zu dunkel für Metall), Licht
(Godot leuchtet in der Tönung der Modulart), optional Glas. Zustands-Teile setzt Godot
(ComboPartBody._write_state): Ziffer0-2 (Leer-Objekte), Lampe0-4, Ring0-9, Klemme0-4, Rand,
Flamme, Abbild (Leer-Objekt). tools/blender_pin_models.py leiht sich die Helfer hier.
"""
import bmesh, bpy, math, os, sys
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/hardware"
ONLY = set(ARGS[1:])
os.makedirs(OUT, exist_ok=True)
STEPS = 56

# Spiegeln ComboPartBody.HULL und RISE: wer sie dort ändert, zieht sie hier nach.
HULL_U, HULL_V = 1.4, 1.3
RISE = {"common": 0.2, "rare": 0.3, "epic": 0.4, "legendary": 0.5}

STEEL = (0.62, 0.65, 0.72)
TITAN = (0.42, 0.44, 0.5)
COPPER = (0.95, 0.46, 0.22)
GOLD = (1.0, 0.72, 0.3)
BLACK = (0.035, 0.038, 0.05)
GRAPHITE = (0.2, 0.21, 0.25)
CERAMIC = (0.78, 0.73, 0.62)
SOLDER = (0.72, 0.74, 0.78)
CYAN_HOT = (0.25, 1.25, 1.35)
GLASS_VIOLET = (0.78, 0.62, 1.0)
GLASS_CLEAR = (0.75, 0.9, 1.0)

LIGHT = Vector((-0.35, 0.45, 0.82)).normalized()
VIEW = Vector((-0.42, 0.1, 0.9)).normalized()
HALF = (LIGHT + VIEW).normalized()


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def matcap(kind, base, n):
    n = n.normalized()
    ndl = max(0.0, n.dot(LIGHT))
    spec = max(0.0, n.dot(HALF))
    fres = 1.0 - abs(n.dot(VIEW))
    r = 2.0 * n.dot(VIEW) * n - VIEW
    env = 0.22 + 0.72 * smooth(0.05, 0.75, r.z) + 0.55 * smooth(0.965, 0.995, r.dot(LIGHT))
    alpha = 1.0
    if kind == "metal":
        col = [c * env for c in base]
        add = spec ** 90 * 0.8
    elif kind == "gloss":
        col = [c * (0.6 + 0.75 * ndl) for c in base]
        add = spec ** 120 * 1.1 + fres ** 3 * 0.22
    elif kind == "glass":
        col = list(base)
        add = spec ** 150 * 1.3
        alpha = min(1.0, 0.08 + fres ** 2.2 * 0.6 + spec ** 150)
    else:  # flat: leuchtet aus sich, kaum Schatten
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
        # Kontaktschatten: wo der Aufbau auf der Platte steht, wird er dunkler.
        if kind not in ("glass", "flat"):
            ao = 0.5 + 0.5 * smooth(-0.01, 0.07, co.z)
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
    for radius, along in profile:
        ring = []
        for i in range(steps):
            a = 2 * math.pi * i / steps
            c, s = radius * math.cos(a) * squash[0], radius * math.sin(a) * squash[1]
            co = {"Z": (c, s, along), "Y": (c, along, s), "X": (along, c, s)}[axis]
            ring.append(bm.verts.new(Vector(co) + Vector(center)))
        rings.append(ring)
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


def prism(name, outline, z0, z1, top_inset=0.0, smooth_on=False):
    bm = bmesh.new()
    low = [bm.verts.new((x, y, z0)) for x, y in outline]
    high = [bm.verts.new((x, y, z1 - (0.006 if top_inset else 0))) for x, y in outline]
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((low[i], low[j], high[j], high[i]))
    bm.faces.new(low)
    if top_inset:
        cx = sum(p[0] for p in outline) / n
        cy = sum(p[1] for p in outline) / n
        cap = [bm.verts.new((x + (cx - x) * top_inset, y + (cy - y) * top_inset, z1)) for x, y in outline]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((high[i], high[j], cap[j], cap[i]))
        bm.faces.new(cap)
    else:
        bm.faces.new(high)
    return finish(name, bm, smooth_on)


def join(name, objects):
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


def export(part_id):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "part_%s.glb" % part_id), use_selection=True,
                              export_apply=True, export_format="GLB", export_colors=True)
    print("BUILT", part_id)


# --- Bild-Koordinaten: u = Bild-rechts (längs der Leitung), v = Bild-oben, z = Höhe ---------------

def B(u, v, z=0.0):
    return (v, -u, z)


def uv_outline(points):
    return [(v, -u) for u, v in points]


def R(wu, hv, cu=0.0, cv=0.0):
    return uv_outline([(cu - wu / 2, cv - hv / 2), (cu + wu / 2, cv - hv / 2), (cu + wu / 2, cv + hv / 2), (cu - wu / 2, cv + hv / 2)])


def box(name, wu, hv, z0, z1, cu=0.0, cv=0.0, inset=0.0):
    return prism(name, R(wu, hv, cu, cv), z0, z1, inset)


def rounded_uv(hu, hv, radius, cu=0.0, cv=0.0):
    out = []
    for su, sv, start in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for k in range(7):
            a = math.radians(start + 90 * k / 6)
            out.append((cu + su * (hu - radius) + radius * math.cos(a), cv + sv * (hv - radius) + radius * math.sin(a)))
    return uv_outline(out)


def slab(name, hu, hv, radius, z0, z1, cu=0.0, cv=0.0, inset=0.0):
    return prism(name, rounded_uv(hu, hv, radius, cu, cv), z0, z1, inset)


def cyl(name, r, z0, z1, cu=0.0, cv=0.0, chamfer=0.0, steps=40, squash=(1, 1)):
    prof = [(r, z0), (r, z1 - chamfer)]
    if chamfer:
        prof.append((r - chamfer, z1))
    prof.append((0.0, z1))
    return lathe(name, prof, B(cu, cv), steps=steps, angle=30, squash=squash)


def dome(name, profile, cu=0.0, cv=0.0, steps=40, squash=(1, 1), caps=True):
    """Drehkörper um die Hochachse: profile = (Radius, Höhe)."""
    return lathe(name, profile, B(cu, cv), steps=steps, angle=40, squash=squash, caps=caps)


def ring(name, r0, r1, z0, z1, cu=0.0, cv=0.0, steps=48):
    return lathe(name, [(r0, z0), (r1, z0), (r1, z1), (r0, z1), (r0, z0)], B(cu, cv), steps=steps, angle=30, caps=False)


def along(name, profile, cu=0.0, cv=0.0, zc=0.1, squash=(1, 1), steps=STEPS, caps=True, angle=30.0):
    """Drehkörper längs der Leitung: profile = (Radius, u relativ zu cu); squash = (Bild-oben, Höhe)."""
    return lathe(name, [(r, -u) for r, u in profile], B(cu, cv, zc), "Y", steps, angle, squash, caps)


def across(name, profile, cu=0.0, cv=0.0, zc=0.1, squash=(1, 1), steps=32, caps=True):
    """Drehkörper quer zur Leitung: profile = (Radius, v relativ zu cv); squash = (Bild-rechts, Höhe)."""
    return lathe(name, profile, B(cu, cv, zc), "X", steps, 30, squash, caps)


def strut(name, a, b, r, steps=10):
    a, b = Vector(B(*a)), Vector(B(*b))
    d = b - a
    obj = lathe(name, [(r, 0.0), (r, d.length)], steps=steps, angle=60)
    obj.data.transform(Matrix.Translation(a) @ Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4())
    return obj


def bar(name, a, b, width, z0, z1):
    """Flacher Steg von a nach b (je (u, v)), width quer dazu."""
    du, dv = b[0] - a[0], b[1] - a[1]
    length = math.hypot(du, dv)
    nu, nv = -dv / length * width / 2, du / length * width / 2
    pts = [(a[0] + nu, a[1] + nv), (b[0] + nu, b[1] + nv), (b[0] - nu, b[1] - nv), (a[0] - nu, a[1] - nv)]
    return prism(name, uv_outline(pts), z0, z1)


def torus(name, R, r, z, cu=0.0, cv=0.0, ribs=0, amp=0.1, nu=96, nv=14):
    bm = bmesh.new()
    at = B(cu, cv)
    rows = []
    for i in range(nu):
        a = 2 * math.pi * i / nu
        minor = r * (1 + amp * math.cos(ribs * a)) if ribs else r
        row = []
        for j in range(nv):
            b = 2 * math.pi * j / nv
            big = R + minor * math.cos(b)
            row.append(bm.verts.new((at[0] + big * math.cos(a), at[1] + big * math.sin(a), z + minor * math.sin(b))))
        rows.append(row)
    for i in range(nu):
        for j in range(nv):
            a, b = rows[i][j], rows[(i + 1) % nu][j]
            c, d = rows[(i + 1) % nu][(j + 1) % nv], rows[i][(j + 1) % nv]
            bm.faces.new((a, b, c, d))
    return finish(name, bm, True, 45)


def nut(name, r, z0, z1, cu, cv):
    return lathe(name, [(r, z0), (r, z1 - 0.01), (r * 0.7, z1), (0.0, z1)], B(cu, cv), steps=6, angle=25)


def arc_segment(name, ru, rv, width, a0, a1, z0, z1, cu=0.0, cv=0.0, n=8):
    """Ein Stück eines elliptischen Rings (Winkel in Grad, 0 = Bild-rechts, gegen den Uhrzeigersinn)."""
    outer, inner = [], []
    for k in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * k / n)
        outer.append((cu + (ru + width / 2) * math.cos(a), cv + (rv + width / 2) * math.sin(a)))
        inner.append((cu + (ru - width / 2) * math.cos(a), cv + (rv - width / 2) * math.sin(a)))
    return prism(name, uv_outline(outer + inner[::-1]), z0, z1)


def anchor(name, u, v, z):
    empty = bpy.data.objects.new(name, None)
    empty.location = B(u, v, z)
    bpy.context.collection.objects.link(empty)
    return empty


def ribbed(r_out, r_in, u0, u1, turns):
    prof = [(0.0, u0), (r_in, u0)]
    for i in range(turns + 1):
        prof.append((r_out if i % 2 == 0 else r_in, u0 + (u1 - u0) * i / turns))
    prof += [(r_in, u1), (0.0, u1)]
    return prof


def capsule(r, half, edge=0.03):
    return [(0.0, -half), (r - edge, -half), (r, -half + edge), (r, half - edge), (r - edge, half), (0.0, half)]


# --- SPEICHER (Punkte): liegende Walze längs der Leitung ------------------------------------------

def resistor():
    """Gewöhnlich: ein flacher Keramikkörper, drei Farbringe, Drähte zu zwei Lötaugen."""
    reset()
    parts = []
    for s in (-1, 1):
        parts.append(paint(along("Draht", [(0.028, s * 0.4), (0.028, s * 0.62)], zc=0.05), "metal", STEEL))
        parts.append(paint(cyl("Loetauge", 0.075, 0.0, 0.03, s * 0.62, 0.0, 0.01), "metal", GOLD))
    parts.append(paint(along("Koerper", [(0.0, -0.46), (0.07, -0.46), (0.1, -0.42), (0.1, -0.34), (0.085, -0.28),
                                         (0.085, 0.28), (0.1, 0.34), (0.1, 0.42), (0.07, 0.46), (0.0, 0.46)],
                             zc=0.1, squash=(2.4, 0.98)), "gloss", CERAMIC))
    join("Korpus", parts)
    join("Licht", [along("Ring", [(0.092, u - 0.04), (0.092, u + 0.04)], zc=0.1, squash=(2.4, 0.98), caps=False)
                   for u in (-0.17, 0.0, 0.17)])
    export("resistor")


def coil():
    """Gewöhnlich: Spulenkörper mit zwei Flanschen, Kupferwicklung, cyanfarbener Kern."""
    reset()
    parts = []
    for s in (-1, 1):
        parts.append(paint(box("Flansch", 0.07, 0.6, 0.0, 0.195, s * 0.42, 0.0, 0.03), "gloss", GRAPHITE))
        parts.append(paint(along("Kern", [(0.0, s * 0.46), (0.09, s * 0.46), (0.09, s * 0.56), (0.0, s * 0.56)],
                                 zc=0.1, squash=(1.6, 1.0)), "flat", CYAN_HOT))
    parts.append(paint(along("Wicklung", ribbed(0.096, 0.086, -0.38, 0.38, 22), zc=0.1, squash=(2.9, 1.0), angle=18),
                       "metal", COPPER))
    join("Korpus", parts)
    join("Licht", [box("Saum", 0.05, 0.5, 0.195, 0.2, s * 0.42) for s in (-1, 1)])
    export("coil")


def series_resistor():
    """Gewöhnlich: Widerstandsnetz - ein Kamm aus sechs Zinken, einer je Würfel."""
    reset()
    parts = [paint(box("Schiene", 1.26, 0.13, 0.0, 0.1, 0.0, 0.38, 0.03), "metal", STEEL)]
    lights = []
    for i in range(6):
        u = (i - 2.5) * 0.205
        parts.append(paint(across("Zinken", [(0.0, 0.34), (0.07, 0.34), (0.078, 0.31), (0.078, -0.17), (0.07, -0.2), (0.0, -0.2)],
                                  u, 0.0, 0.088, squash=(1.0, 1.1)), "gloss", CERAMIC))
        parts.append(paint(box("Fuss", 0.03, 0.2, 0.0, 0.03, u, -0.3), "metal", STEEL))
        parts.append(paint(cyl("Pad", 0.055, 0.0, 0.025, u, -0.43, 0.008, 20), "metal", GOLD))
        for v in (0.15, 0.0):
            lights.append(across("Band", [(0.082, v - 0.03), (0.082, v + 0.03)], u, 0.0, 0.088, squash=(1.0, 1.1), caps=False))
    join("Korpus", parts)
    join("Licht", lights)
    export("series_resistor")


def series_terminal():
    """Selten: Klemmleiste, fünf Zellen mit Schraube - so viele leuchten, wie Module stecken."""
    reset()
    parts = []
    for i in range(5):
        u = (i - 2) * 0.26
        parts.append(paint(box("Zelle", 0.22, 0.62, 0.0, 0.22, u, 0.06, 0.03), "gloss", GRAPHITE))
        parts.append(paint(cyl("Schraube", 0.072, 0.22, 0.275, u, 0.2, 0.015, 24), "metal", STEEL))
        parts.append(paint(box("Schlitz", 0.022, 0.11, 0.275, 0.279, u, 0.2), "gloss", BLACK))
        parts.append(paint(box("Einfuehrung", 0.13, 0.12, 0.22, 0.224, u, -0.12), "gloss", BLACK))
        ring("Klemme%d" % i, 0.08, 0.11, 0.222, 0.228, u, 0.2, 32)
    join("Korpus", parts)
    box("Licht", 1.24, 0.035, 0.0, 0.03, 0.0, -0.32)
    export("series_terminal")


# --- WANDLER (Mult +): stehende runde Dose ----------------------------------------------------------

def capacitor():
    """Gewöhnlich: Becher mit Kreuzkerbe im Deckel."""
    reset()
    parts = [paint(cyl("Dose", 0.42, 0.0, 0.185, chamfer=0.03, steps=64), "gloss", GRAPHITE),
             paint(ring("Huelse", 0.42, 0.44, 0.0, 0.12, steps=64), "metal", STEEL)]
    for wu, hv in ((0.56, 0.07), (0.07, 0.56)):
        parts.append(paint(box("Kerbe", wu, hv, 0.19, 0.2), "gloss", BLACK))
    join("Korpus", parts)
    cyl("Licht", 0.33, 0.185, 0.19, steps=64)
    export("capacitor")


def starter():
    """Gewöhnlich: Startknopf in eckiger Blende, Leuchtring und Ein-Zeichen."""
    reset()
    parts = [paint(slab("Blende", 0.46, 0.46, 0.1, 0.0, 0.06, inset=0.03), "metal", STEEL),
             paint(dome("Knopf", [(0.3, 0.06), (0.3, 0.1), (0.27, 0.155), (0.15, 0.185), (0.0, 0.19)]), "gloss", GRAPHITE)]
    for su in (-1, 1):
        for sv in (-1, 1):
            parts.append(paint(cyl("Schraube", 0.035, 0.06, 0.075, su * 0.36, sv * 0.36, 0.01, 12), "metal", TITAN))
    join("Korpus", parts)
    lights = [ring("Ring", 0.31, 0.39, 0.06, 0.066, steps=64)]
    for k in range(10):
        a0, a1 = math.radians(120 + 30 * k), math.radians(150 + 30 * k)
        lights.append(bar("Zeichen", (0.1 * math.cos(a0), 0.1 * math.sin(a0)), (0.1 * math.cos(a1), 0.1 * math.sin(a1)),
                          0.03, 0.188, 0.196))
    lights.append(bar("Zeichen", (0.0, 0.02), (0.0, 0.13), 0.035, 0.188, 0.197))
    join("Licht", lights)
    export("starter")


def thermistor():
    """Selten: flache Scheibe auf zwei Beinen; ihr Rand glüht in der Ladung der Hand."""
    reset()
    parts = [paint(cyl("Scheibe", 0.35, 0.17, 0.235, 0.0, 0.06, 0.02, 64), "gloss", GRAPHITE)]
    for s in (-1, 1):
        parts.append(paint(strut("Bein", (s * 0.15, -0.15, 0.18), (s * 0.27, -0.48, 0.02), 0.026), "metal", STEEL))
        parts.append(paint(cyl("Pad", 0.065, 0.0, 0.03, s * 0.27, -0.48, 0.01, 20), "metal", GOLD))
    join("Korpus", parts)
    ring("Rand", 0.355, 0.44, 0.2, 0.245, 0.0, 0.06, 64)
    cyl("Licht", 0.08, 0.235, 0.24, 0.0, 0.06, steps=32)
    export("thermistor")


def counter_part():
    """Episch: Rollenzählwerk mit drei Ziffernrollen - Godot schreibt den Stand darauf."""
    reset()
    parts = [paint(slab("Gehaeuse", 0.56, 0.29, 0.06, 0.0, 0.2, inset=0.02), "gloss", GRAPHITE),
             paint(along("Rad", [(0.0, -0.04), (0.13, -0.04), (0.13, 0.04), (0.0, 0.04)], 0.62, 0.0, 0.2, steps=24), "metal", GOLD)]
    for i in range(3):
        u = (i - 1) * 0.32
        parts.append(paint(along("Rolle", capsule(0.15, 0.14, 0.02), u, 0.0, 0.18), "gloss", BLACK))
        anchor("Ziffer%d" % i, u, 0.0, 0.335)
    for u in (-0.48, -0.16, 0.16, 0.48):
        parts.append(paint(box("Steg", 0.04, 0.42, 0.18, 0.31, u, 0.0, 0.0), "metal", STEEL))
    join("Korpus", parts)
    join("Licht", [box("Rahmen", 0.98, 0.035, 0.2, 0.205, 0.0, s * 0.22) for s in (-1, 1)])
    export("counter")


def error_memory():
    """Selten: EPROM mit Quarzfenster, darunter fünf Fehlerlampen - je Fumble eine."""
    reset()
    parts = [paint(box("Baustein", 0.94, 0.44, 0.03, 0.22, 0.0, 0.2, 0.02), "gloss", GRAPHITE),
             paint(ring("Fassung", 0.1, 0.135, 0.22, 0.232, -0.2, 0.2), "metal", STEEL)]
    for i in range(7):
        for s in (-1, 1):
            parts.append(paint(box("Bein", 0.05, 0.12, 0.0, 0.08, (i - 3) * 0.13, 0.2 + s * 0.26), "metal", STEEL))
    for i in range(5):
        parts.append(paint(ring("Lampenring", 0.06, 0.085, 0.0, 0.05, (i - 2) * 0.24, -0.4, 32), "metal", STEEL))
        cyl("Lampe%d" % i, 0.06, 0.0, 0.06, (i - 2) * 0.24, -0.4, 0.015, 24)
    join("Korpus", parts)
    paint(cyl("Glas", 0.1, 0.22, 0.235, -0.2, 0.2, steps=32), "glass", GLASS_VIOLET)
    box("Licht", 0.34, 0.06, 0.22, 0.225, 0.2, 0.2)
    export("error_memory")


def solder_joint():
    """Selten: Leiste mit sechs blanken Zinnkuppen, eine je Würfel."""
    reset()
    parts = [paint(box("Leiste", 1.32, 0.36, 0.0, 0.04, 0.0, 0.05, 0.01), "metal", GOLD)]
    lights = []
    for i in range(6):
        u = (i - 2.5) * 0.21
        parts.append(paint(dome("Kuppe", [(0.09, 0.04), (0.088, 0.12), (0.07, 0.2), (0.04, 0.24), (0.0, 0.25)], u, 0.05), "metal", SOLDER))
        lights.append(ring("Auge", 0.094, 0.118, 0.04, 0.046, u, 0.05, 32))
    join("Korpus", parts)
    join("Licht", lights)
    export("solder_joint")


# --- KONTAKTE (Würfel) ------------------------------------------------------------------------------

def relay():
    """Selten: Spule mit Schaltzunge, die nach LINKS zeigt - auf den ersten Würfel."""
    reset()
    parts = [paint(slab("Sockel", 0.62, 0.32, 0.05, 0.0, 0.06, 0.0, 0.12, 0.02), "metal", STEEL),
             paint(along("Spule", ribbed(0.115, 0.104, -0.22, 0.22, 14), 0.26, 0.24, 0.17, angle=18), "metal", COPPER),
             paint(box("Joch", 0.06, 0.3, 0.06, 0.29, 0.52, 0.24, 0.0), "metal", TITAN),
             paint(cyl("Kontakt", 0.07, 0.06, 0.13, -0.48, 0.0, 0.015, 24), "metal", GOLD)]
    for s in (-1, 1):
        parts.append(paint(along("Kappe", [(0.0, -0.02), (0.13, -0.02), (0.13, 0.02), (0.0, 0.02)], 0.26 + s * 0.23, 0.24, 0.17),
                           "metal", TITAN))
    join("Korpus", parts)
    join("Licht", [strut("Zunge", (0.48, 0.3, 0.25), (-0.44, 0.02, 0.15), 0.04),
                   cyl("Spitze", 0.075, 0.13, 0.15, -0.48, 0.0, 0.0, 24),
                   bar("Pfeil", (-0.2, 0.02), (-0.6, 0.02), 0.04, 0.06, 0.066)])
    export("relay")


def output_stage():
    """Selten: ovales Transistorgehäuse auf Kühlblech, die Marke RECHTS - der letzte Würfel."""
    reset()
    parts = [paint(slab("Blech", 0.6, 0.36, 0.04, 0.0, 0.04, 0.0, 0.08), "metal", STEEL)]
    for k in range(9):
        parts.append(paint(box("Rippe", 0.035, 0.68, 0.04, 0.17, -0.56 + k * 0.14, 0.08), "metal", TITAN))
    parts.append(paint(dome("Flansch", [(0.36, 0.17), (0.36, 0.19), (0.0, 0.19)], 0.0, 0.08, squash=(0.6, 1.0)), "metal", STEEL))
    parts.append(paint(dome("Kappe", [(0.21, 0.19), (0.21, 0.25), (0.19, 0.285), (0.0, 0.29)], 0.0, 0.08, squash=(0.95, 1.55)), "metal", STEEL))
    for s in (-1, 1):
        parts.append(paint(cyl("Schraube", 0.045, 0.19, 0.22, s * 0.47, 0.08, 0.012, 16), "metal", GOLD))
    join("Korpus", parts)
    join("Licht", [cyl("Marke", 0.09, 0.29, 0.296, 0.24, 0.08, steps=24),
                   bar("Pfeil", (0.2, -0.2), (0.6, -0.2), 0.04, 0.17, 0.176)])
    export("output_stage")


def shunt():
    """Episch: dicke Kupferschiene, die im Bogen um die Leitung herumführt."""
    reset()
    parts = []
    for s in (-1, 1):
        parts.append(paint(box("Pfosten", 0.2, 0.62, 0.0, 0.3, s * 0.52, 0.06, 0.03), "metal", COPPER))
        parts.append(paint(nut("Mutter", 0.06, 0.3, 0.37, s * 0.52, -0.12), "metal", STEEL))
        parts.append(paint(cyl("Fuss", 0.08, 0.0, 0.03, s * 0.52, -0.33, 0.01, 20), "metal", STEEL))
    parts.append(paint(box("Bruecke", 1.24, 0.2, 0.22, 0.34, 0.0, 0.44, 0.03), "metal", COPPER))
    join("Korpus", parts)
    join("Licht", [box("Abgriff", 0.12, 0.1, 0.34, 0.346, s * 0.22, 0.44) for s in (-1, 1)]
         + [box("Strich", 0.24, 0.03, 0.34, 0.344, 0.0, 0.44)])
    export("shunt")


def parallel_circuit():
    """Legendär: die Leitung teilt sich in zwei Schienen mit Sprossen und läuft wieder zusammen."""
    reset()
    parts = []
    for s in (-1, 1):
        parts.append(paint(box("Schiene", 0.92, 0.12, 0.0, 0.32, 0.0, s * 0.3, 0.03), "metal", STEEL))
    for k in range(5):
        u = (k - 2) * 0.2
        parts.append(paint(across("Sprosse", [(0.045, -0.3), (0.045, 0.3)], u, 0.0, 0.24, caps=False), "metal", COPPER))
        for s in (-1, 1):
            parts.append(paint(nut("Mutter", 0.045, 0.32, 0.4, u, s * 0.3), "metal", GOLD))
    join("Korpus", parts)
    lights = [box("Doppel", 0.84, 0.035, 0.32, 0.325, 0.0, s * 0.3) for s in (-1, 1)]
    for e in (-1, 1):
        lights.append(bar("Weiche", (e * 0.66, 0.0), (e * 0.46, 0.3), 0.045, 0.0, 0.02))
        lights.append(bar("Weiche", (e * 0.66, 0.0), (e * 0.46, -0.3), 0.045, 0.0, 0.02))
    join("Licht", lights)
    export("parallel_circuit")


# --- RÖHREN (Mult ×): Glaskolben mit Glut -----------------------------------------------------------

def amplifier_tube():
    """Episch: kleine liegende Röhre mit Gitter, in zwei Schellen."""
    reset()
    parts = []
    for s in (-1, 1):
        parts.append(paint(along("Kappe", [(0.0, -0.05), (0.15, -0.05), (0.15, 0.05), (0.0, 0.05)], s * 0.43, 0.0, 0.2), "metal", STEEL))
        parts.append(paint(strut("Stift", (s * 0.47, 0.0, 0.12), (s * 0.62, 0.0, 0.02), 0.025), "metal", GOLD))
        parts.append(paint(box("Schelle", 0.07, 0.4, 0.0, 0.13, s * 0.22, 0.0, 0.02), "metal", TITAN))
    parts.append(paint(along("Anode", [(0.1, -0.3), (0.1, 0.3)], 0.0, 0.0, 0.2, squash=(1.0, 0.4), caps=False), "metal", STEEL))
    join("Korpus", parts)
    paint(along("Glas", capsule(0.17, 0.39, 0.06), 0.0, 0.0, 0.2), "glass", GLASS_VIOLET)
    along("Licht", [(0.0, -0.32), (0.065, -0.32), (0.065, 0.32), (0.0, 0.32)], 0.0, 0.0, 0.2)
    export("amplifier_tube")


def resonator():
    """Episch: Spule und Kondensator als Paar, darum ein Ring - er füllt sich mit dem Wachstum."""
    reset()
    parts = [paint(torus("Spule", 0.14, 0.075, 0.09, -0.24, 0.0, ribs=20, amp=0.14, nu=72), "metal", COPPER),
             paint(cyl("Bolzen", 0.05, 0.0, 0.2, -0.24, 0.0, 0.015, 20), "metal", STEEL),
             paint(cyl("Becher", 0.16, 0.0, 0.3, 0.24, 0.0, 0.025, 40), "gloss", GRAPHITE),
             paint(strut("Draht", (-0.05, 0.0, 0.08), (0.1, 0.0, 0.08), 0.022), "metal", COPPER)]
    join("Korpus", parts)
    for k in range(10):
        a0 = 90 - k * 36 - 3
        arc_segment("Ring%d" % k, 0.61, 0.52, 0.07, a0, a0 - 30, 0.0, 0.02)
    cyl("Licht", 0.12, 0.3, 0.306, 0.24, 0.0, steps=32)
    export("resonator")


def afterburner():
    """Episch: Düse mit Blendenlamellen; nach einem Fumble offen mit Flamme (Godot zeigt sie)."""
    reset()
    zc = 0.2
    parts = [paint(along("Kammer", capsule(0.15, 0.2, 0.03), -0.44, 0.0, zc), "metal", STEEL),
             paint(along("Kegel", [(0.15, -0.24), (0.19, 0.06)], 0.0, 0.0, zc, caps=False), "metal", STEEL)]
    for u in (-0.56, -0.44, -0.32):
        parts.append(paint(along("Reif", [(0.155, u - 0.015), (0.155, u + 0.015)], 0.0, 0.0, zc, caps=False), "gloss", BLACK))
    for k in range(8):
        a = math.tau * k / 8
        p0 = (-0.24, 0.15 * math.cos(a) * 0.98, zc + 0.15 * math.sin(a) * 0.98)
        p1 = (0.06, 0.19 * math.cos(a) * 1.01, zc + 0.19 * math.sin(a) * 1.01)
        parts.append(paint(strut("Lamelle", p0, p1, 0.012, 6), "gloss", BLACK))
    for s in (-1, 1):
        parts.append(paint(box("Sattel", 0.08, 0.36, 0.0, 0.08, -0.44 + s * 0.12, 0.0, 0.02), "metal", TITAN))
    join("Korpus", parts)
    along("Licht", [(0.17, 0.05), (0.198, 0.05), (0.198, 0.09), (0.17, 0.09), (0.17, 0.05)], 0.0, 0.0, zc, caps=False)
    along("Flamme", [(0.0, 0.08), (0.14, 0.16), (0.04, 0.28), (0.1, 0.36), (0.03, 0.46), (0.06, 0.53), (0.0, 0.66)], 0.0, 0.0, zc, steps=24)
    export("afterburner")


def high_voltage_tube():
    """Legendär: stehende Röhre auf geripptem Isolator, Anodenkappe und Koronaring."""
    reset()
    prof = [(0.36, 0.0)]
    for k in range(3):
        z = 0.02 + k * 0.05
        prof += [(0.4, z), (0.4, z + 0.025), (0.36, z + 0.03), (0.36, z + 0.05)]
    prof += [(0.32, 0.17), (0.0, 0.17)]
    parts = [paint(dome("Isolator", prof), "gloss", CERAMIC),
             paint(ring("Anode", 0.08, 0.1, 0.17, 0.42), "metal", STEEL),
             paint(dome("Kappe", [(0.075, 0.42), (0.075, 0.47), (0.05, 0.495), (0.0, 0.5)], steps=24), "metal", GOLD)]
    for su in (-1, 1):
        for sv in (-1, 1):
            parts.append(paint(cyl("Fuss", 0.07, 0.0, 0.08, su * 0.5, sv * 0.45, 0.02, 16), "gloss", CERAMIC))
            parts.append(paint(strut("Stuetze", (su * 0.5, sv * 0.45, 0.06), (su * 0.27, sv * 0.24, 0.12), 0.025), "metal", STEEL))
    join("Korpus", parts)
    paint(dome("Glas", [(0.27, 0.17), (0.27, 0.32), (0.2, 0.42), (0.0, 0.46)], caps=False), "glass", GLASS_VIOLET)
    join("Licht", [cyl("Kern", 0.05, 0.17, 0.4, steps=20), torus("Korona", 0.33, 0.028, 0.3, nu=72, nv=10)])
    export("high_voltage_tube")


def magnetron():
    """Legendär: Kupferanode mit Hohlraum-Rosette zwischen zwei Magneten."""
    reset()
    parts = [paint(dome("Anode", [(0.38, 0.0), (0.38, 0.26), (0.36, 0.28), (0.0, 0.28)], steps=64), "metal", COPPER),
             paint(cyl("Antenne", 0.035, 0.28, 0.5, 0.0, 0.3, 0.01, 16), "metal", GOLD)]
    for s in (-1, 1):
        parts.append(paint(box("Magnet", 0.16, 0.72, 0.0, 0.34, s * 0.57, 0.0, 0.03), "gloss", GRAPHITE))
        parts.append(paint(box("Polschuh", 0.06, 0.5, 0.0, 0.3, s * 0.46, 0.0, 0.0), "metal", STEEL))
    for k in range(8):
        a = math.tau * k / 8 + math.pi / 8
        parts.append(paint(bar("Kammer", (0.12 * math.cos(a), 0.12 * math.sin(a)), (0.3 * math.cos(a), 0.3 * math.sin(a)),
                               0.07, 0.28, 0.286), "gloss", BLACK))
    join("Korpus", parts)
    join("Licht", [cyl("Kathode", 0.085, 0.28, 0.29, steps=32), ring("Spalt", 0.31, 0.335, 0.28, 0.284, steps=64)])
    export("magnetron")


# --- ABGRIFFE (Ökonomie) ----------------------------------------------------------------------------

def coin_validator():
    """Gewöhnlich: Münzprüfer mit Schlitz, eine Münze liegt davor."""
    reset()
    parts = [paint(slab("Pruefer", 0.46, 0.44, 0.08, 0.0, 0.11, inset=0.03), "metal", STEEL),
             paint(box("Schlitz", 0.62, 0.08, 0.105, 0.114, 0.0, 0.24), "gloss", BLACK),
             paint(dome("Muenze", [(0.22, 0.11), (0.22, 0.17), (0.2, 0.185), (0.15, 0.185), (0.14, 0.175), (0.0, 0.175)], 0.05, -0.1),
                   "metal", GOLD),
             paint(ring("Praegung", 0.07, 0.1, 0.175, 0.18, 0.05, -0.1, 32), "metal", COPPER)]
    join("Korpus", parts)
    box("Licht", 0.54, 0.03, 0.114, 0.118, 0.0, 0.24)
    export("coin_validator")


def power_pickup():
    """Selten: gefederter Scherenbügel, der Strom von der Leitung abgreift."""
    reset()
    parts = [paint(box("Fuss", 0.52, 0.16, 0.0, 0.08, 0.0, -0.46, 0.03), "metal", STEEL),
             paint(box("Buegel", 1.1, 0.15, 0.22, 0.28, 0.0, 0.34, 0.02), "metal", COPPER)]
    for s in (-1, 1):
        parts.append(paint(cyl("Isolator", 0.05, 0.08, 0.13, s * 0.17, -0.46, 0.01, 16), "gloss", CERAMIC))
        parts.append(paint(strut("Arm", (s * 0.17, -0.46, 0.12), (s * 0.4, -0.06, 0.19), 0.038), "metal", STEEL))
        parts.append(paint(strut("Arm", (s * 0.4, -0.06, 0.19), (s * 0.14, 0.32, 0.23), 0.038), "metal", STEEL))
        parts.append(paint(strut("Horn", (s * 0.55, 0.34, 0.255), (s * 0.64, 0.4, 0.16), 0.02), "metal", COPPER))
    join("Korpus", parts)
    lights = [box("Schleifer", 1.0, 0.06, 0.28, 0.285, 0.0, 0.34)]
    for s in (-1, 1):
        zig = [(s * 0.5, 0.42), (s * 0.58, 0.5), (s * 0.52, 0.52), (s * 0.62, 0.62)]
        for a, b in zip(zig, zig[1:]):
            lights.append(bar("Funke", a, b, 0.025, 0.27, 0.278))
    join("Licht", lights)
    export("power_pickup")


# --- BRÜCKEN und FASSUNGEN --------------------------------------------------------------------------

def cross_bridge(part_id="cross_bridge", turn=0.0):
    """Legendär: ein Flachband-Bogen auf Keramik-Isolator, der Pfeil verläßt den Platz zum Nachbarn."""
    reset()
    spin = Matrix.Rotation(turn, 4, "Z")
    built = []

    def keep(obj):
        obj.data.transform(spin)
        obj.data.update()
        built.append(obj)
        return obj

    prof = [(0.1, 0.0)]
    for k in range(3):
        z = 0.03 + k * 0.08
        prof += [(0.13, z), (0.13, z + 0.04), (0.08, z + 0.045), (0.08, z + 0.08)]
    prof += [(0.08, 0.27), (0.0, 0.27)]
    parts = [paint(keep(dome("Isolator", prof, -0.42, 0.0, steps=24)), "gloss", CERAMIC),
             paint(keep(cyl("Kappe", 0.1, 0.27, 0.31, -0.42, 0.0, 0.02, 24)), "metal", STEEL)]
    path = []
    for k in range(13):
        t = k / 12
        u = -0.42 + 0.84 * t
        path.append((u, 0.31 + 0.15 * math.sin(math.pi * t * 0.85) - 0.29 * t * t))
    for a, b in zip(path, path[1:]):
        parts.append(paint(keep(strut("Band", (a[0], 0.0, a[1]), (b[0], 0.0, b[1]), 0.05, 8)), "gloss", GRAPHITE))
    join("Korpus", parts)
    lights = [keep(strut("Ader", (a[0], 0.0, a[1] + 0.045), (b[0], 0.0, b[1] + 0.045), 0.022, 6)) for a, b in zip(path, path[1:])]
    lights.append(keep(prism("Pfeil", uv_outline([(0.36, -0.24), (0.64, 0.0), (0.36, 0.24)]), 0.0, 0.05)))
    join("Licht", lights)
    export(part_id)


def down_bridge():
    cross_bridge("down_bridge", -math.pi / 2)


def coupling():
    """Legendär: links eine Spule am Band vom Nachbarn, rechts das Feld - darüber das Abbild."""
    reset()
    parts = [paint(along("Spule", ribbed(0.15, 0.135, -0.15, 0.15, 12), -0.28, 0.0, 0.2, angle=18), "metal", COPPER),
             paint(slab("Feld", 0.31, 0.31, 0.06, 0.0, 0.03, 0.34, 0.0), "gloss", BLACK),
             paint(torus("Gegenspule", 0.16, 0.035, 0.05, 0.34, 0.0, ribs=18, amp=0.18, nu=64), "metal", COPPER)]
    for s in (-1, 1):
        parts.append(paint(along("Kappe", [(0.0, -0.015), (0.17, -0.015), (0.17, 0.015), (0.0, 0.015)], -0.28 + s * 0.16, 0.0, 0.2),
                           "metal", TITAN))
    join("Korpus", parts)
    lights = [box("Band", 0.3, 0.07, 0.0, 0.03, -0.55, 0.0)]
    for su in (-1, 1):
        for sv in (-1, 1):
            cu, cv = 0.34 + su * 0.27, sv * 0.27
            lights.append(bar("Ecke", (cu, cv), (cu - su * 0.12, cv), 0.035, 0.03, 0.04))
            lights.append(bar("Ecke", (cu, cv + sv * 0.0175), (cu, cv - sv * 0.12), 0.035, 0.03, 0.04))
    join("Licht", lights)
    anchor("Abbild", 0.34, 0.0, 0.1)
    export("coupling")


def blocking_diode():
    """Selten: schwarzer Zylinder mit Silberring, darunter das Schaltzeichen Dreieck-Strich."""
    reset()
    parts = [paint(along("Koerper", capsule(0.13, 0.32, 0.03), 0.0, 0.22, 0.14, squash=(1.0, 1.0)), "gloss", GRAPHITE),
             paint(along("Ring", [(0.134, -0.04), (0.134, 0.04)], 0.2, 0.22, 0.14, caps=False), "metal", STEEL)]
    for s in (-1, 1):
        parts.append(paint(strut("Draht", (s * 0.32, 0.22, 0.12), (s * 0.58, 0.22, 0.02), 0.025), "metal", STEEL))
        parts.append(paint(cyl("Pad", 0.07, 0.0, 0.03, s * 0.6, 0.22, 0.01, 20), "metal", GOLD))
    join("Korpus", parts)
    join("Licht", [prism("Dreieck", uv_outline([(-0.2, -0.12), (-0.2, -0.5), (0.12, -0.31)]), 0.0, 0.025),
                   box("Strich", 0.05, 0.4, 0.0, 0.025, 0.15, -0.31),
                   box("Draht", 1.1, 0.025, 0.0, 0.012, 0.0, -0.31)])
    export("blocking_diode")


BUILDS = (resistor, coil, series_resistor, series_terminal, capacitor, starter, thermistor, counter_part, error_memory,
          solder_joint, relay, output_stage, shunt, parallel_circuit, amplifier_tube, resonator, afterburner,
          high_voltage_tube, magnetron, coin_validator, power_pickup, cross_bridge, down_bridge, coupling, blocking_diode)
NAMES = {counter_part: "counter"}

if __name__ == "__main__":
    for build in BUILDS:
        if not ONLY or NAMES.get(build, build.__name__) in ONLY:
            build()
