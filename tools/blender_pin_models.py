"""Fumble: je MODUL sein FACH-EINSATZ - der EINE Körper eines Moduls (2026-11-23; Familien und
Bauteile docs/plan_modul_bauteile.md), Licht als Vertexfarben eingemalt.

Aufruf (kopflos):
  blender -b -P tools/blender_pin_models.py -- assets/models/hardware [id ...]

pin_<id>.glb und pin_empty.glb (das Blindfach). Ein Modul ist ein Block, der ein Fach des
Kombinations-Chips füllt, rechts sein Beinchen bis auf den Tisch - für alle gleich. Ursprung = die
Naht am Chip auf dem Tisch; längs ist Bild-rechts (u), quer Bild-oben (v), z die Höhe. Hüllmaß
PIN_U × PIN_V × PIN_Z (spiegelt ComboPartBody.HULL). glTF: Godot (x, y, z) = (v, z, u).
Die FAMILIE gibt den Ton der Schale, jedes Modul sein Merkmal auf dem Deckel. Knoten: Korpus,
Licht (Art: Statusstrich, Merkmal, Fuß-LED), Seltenheit (Schulter-LED), optional Glas und Abbild,
Zustands-Teile (Ziffer0-2, Lampe0-4, Ring0-4, Klemme0-2, Flamme) setzt Godot. Das Blindfach trägt
Gehaeuse, Glas und Bein - seine Materialien gibt der Chip.
"""
import bmesh, bpy, math, os, sys
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/hardware"
ONLY = set(ARGS[1:])
os.makedirs(OUT, exist_ok=True)
STEPS = 48

# Spiegelt ComboPartBody.HULL: wer es dort ändert, zieht es hier nach.
PIN_U, PIN_V, PIN_Z = 2.3, 0.82, 1.68
BLOCK = 1.845        # Länge des Blocks; der Rest ist das Beinchen
CHIP_TOP = 1.28      # Deckelhöhe des Chips: so hoch steht das Blindfach
T = 1.32             # Deckel des Blocks (ComboPartBody.TOP); darüber stehen nur die Merkmale
AX = T + 0.03        # Achshöhe der liegenden Körper: halb im Deckel versenkt

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
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "pin_%s.glb" % name), use_selection=True,
                              export_apply=True, export_format="GLB", export_colors=True)
    print("BUILT pin", name)


def arrow(name, pts, width, head_w, head_len, z0, z1):
    """Flacher Pfeil: Schaft längs pts, die Spitze sitzt am letzten Punkt und zeigt in Laufrichtung."""
    a, b = pts[-2], pts[-1]
    du, dv = b[0] - a[0], b[1] - a[1]
    length = math.hypot(du, dv)
    du, dv = du / length, dv / length
    base = (b[0] - du * head_len, b[1] - dv * head_len)
    shaft = list(pts[:-1]) + [base]
    pieces = [bar(name, p, q, width, z0, z1) for p, q in zip(shaft, shaft[1:])]
    pieces += [box(name, width, width, z0, z1, p[0], p[1]) for p in shaft[1:-1]]
    nu, nv = -dv * head_w / 2, du * head_w / 2
    pieces.append(prism(name, uv_outline([(base[0] + nu, base[1] + nv), b, (base[0] - nu, base[1] - nv)]), z0, z1))
    return pieces


# --- Schale und Beinchen: für jedes Modul gleich ------------------------------------------------

LEG = [(0.0, 0.68), (0.17, 0.68), (0.32, 0.1), (0.475, 0.1), (0.475, 0.0), (0.27, 0.0), (0.12, 0.56), (0.0, 0.56)]
LEG_W = 0.4

SPEICHER = (0.27, 0.24, 0.19)
WANDLER = (0.13, 0.13, 0.17)
KONTAKT = (0.1, 0.17, 0.19)
ROEHRE = (0.16, 0.08, 0.22)
ABGRIFF = (0.13, 0.17, 0.11)
BRUECKE = (0.21, 0.08, 0.19)


def leg(name="Bein"):
    """Gull-Wing-Beinchen: Schulter am Block, Knick, Fuß auf dem Tisch."""
    bm = bmesh.new()
    sides = [[bm.verts.new(B(BLOCK - 0.02 + u, v, z)) for u, z in LEG] for v in (-LEG_W / 2, LEG_W / 2)]
    n = len(LEG)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((sides[0][i], sides[0][j], sides[1][j], sides[1][i]))
    caps = [bm.faces.new(sides[0]), bm.faces.new(sides[1])]
    bmesh.ops.triangulate(bm, faces=caps)
    return finish(name, bm, False)


def shell(tone):
    """Block, Beinchen und die festen Lichter: Statusstrich an der Naht, Fuß-LED (Art), Schulter-LED."""
    parts = [paint(slab("Schale", BLOCK / 2, PIN_V / 2, 0.06, 0.03, T, BLOCK / 2, 0.0), "gloss", tone),
             paint(leg(), "metal", STEEL)]
    lights = [box("Status", 0.09, 0.56, T, T + 0.012, 0.13, 0.0),
              box("FussLed", 0.09, 0.28, 0.1, 0.115, BLOCK + 0.36, 0.0)]
    box("Seltenheit", 0.09, 0.28, 0.68, 0.695, BLOCK + 0.055, 0.0)
    return parts, lights


def done(name, parts, lights):
    join("Korpus", parts)
    join("Licht", lights)
    export(name)


def top(z):
    return T + z


# --- SPEICHER (Punkte) -------------------------------------------------------------------------

def resistor():
    """Widerstand: Keramik-Riegel im Deckel, drei breite Farbringe."""
    reset()
    parts, lights = shell(SPEICHER)
    parts.append(paint(along("Riegel", capsule(0.2, 0.62), 1.02, squash=(1.3, 1.0)), "gloss", CERAMIC))
    lights += [band("Ring", 0.202, 0.215, 0.08, u, squash=(1.3, 1.0)) for u in (0.66, 1.02, 1.38)]
    done("resistor", parts, lights)


def coil():
    """Spule: Kupferwicklung zwischen zwei Leucht-Flanschen."""
    reset()
    parts, lights = shell(SPEICHER)
    parts.append(paint(along("Wicklung", ribbed(0.19, 0.175, -0.46, 0.46, 16), 1.02, squash=(1.2, 1.0)), "metal", COPPER))
    lights += [along("Flansch", capsule(0.25, 0.05, 0.015), u, squash=(1.25, 1.0)) for u in (0.5, 1.54)]
    done("coil", parts, lights)


def series_resistor():
    """Vorwiderstand: ein Kamm - Riegel oben, sechs leuchtende Zinken."""
    reset()
    parts, lights = shell(SPEICHER)
    parts.append(paint(box("Riegel", 1.36, 0.14, T, top(0.07), 1.02, 0.24), "gloss", CERAMIC))
    lights += [box("Zinke", 0.11, 0.4, T, top(0.03), 0.42 + i * 0.24, -0.06) for i in range(6)]
    done("series_resistor", parts, lights)


def series_terminal():
    """Reihenklemme: drei Schrauben, ihr Ring leuchtet je Modul."""
    reset()
    parts, lights = shell(SPEICHER)
    for i in range(3):
        u = 0.52 + i * 0.5
        parts.append(paint(cyl("Schraube", 0.12, T, top(0.06), u, 0.08, 0.02, 24), "metal", STEEL))
        parts.append(paint(box("Schlitz", 0.03, 0.18, top(0.06), top(0.065), u, 0.08), "gloss", BLACK))
        ring("Klemme%d" % i, 0.14, 0.2, T, top(0.03), u, 0.08, 32)
        lights.append(box("Lichtstrich", 0.26, 0.07, T, top(0.02), u, -0.27))
    done("series_terminal", parts, lights)


# --- WANDLER (Mult +) --------------------------------------------------------------------------

def capacitor():
    """Kondensator: runder Becher im Deckel, ein großes Kreuz."""
    reset()
    parts, lights = shell(WANDLER)
    parts += [paint(cyl("Becher", 0.31, T, top(0.08), 1.02, 0.0, 0.03, 56), "gloss", BLACK),
              paint(ring("Huelse", 0.31, 0.35, T, top(0.05), 1.02, 0.0, 56), "metal", GOLD)]
    lights += [box("Kreuz", 0.48, 0.12, top(0.08), top(0.1), 1.02, 0.0), box("Kreuz", 0.12, 0.48, top(0.08), top(0.1), 1.02, 0.0)]
    done("capacitor", parts, lights)


def solder_joint():
    """Lötpunkt: sechs leuchtende Zinnkuppen (eine je Würfel)."""
    reset()
    parts, lights = shell(WANDLER)
    for a in range(3):
        for b in (-1, 1):
            u, v = 0.56 + a * 0.46, b * 0.18
            parts.append(paint(ring("Pad", 0.13, 0.16, T, top(0.02), u, v, 32), "metal", SOLDER))
            lights.append(dome("Kuppe", [(0.13, T), (0.125, top(0.06)), (0.08, top(0.1)), (0.0, top(0.12))], u, v))
    done("solder_joint", parts, lights)


def counter_part():
    """Zählwerk: großes schwarzes Ziffernfenster."""
    reset()
    parts, lights = shell(WANDLER)
    parts.append(paint(box("Fenster", 1.2, 0.5, T, top(0.012), 1.04, 0.05), "gloss", BLACK))
    for i in range(3):
        anchor("Ziffer%d" % i, 0.66 + i * 0.38, 0.05, top(0.02))
    lights.append(box("Unterstrich", 1.2, 0.06, T, top(0.02), 1.04, -0.29))
    done("counter", parts, lights)


def starter():
    """Anlasser: der große runde Knopf mit Ein-Zeichen."""
    reset()
    parts, lights = shell(WANDLER)
    parts += [paint(ring("Kragen", 0.3, 0.35, T, top(0.04), 1.02, 0.0, 48), "metal", STEEL),
              paint(dome("Knopf", [(0.3, T), (0.3, top(0.06)), (0.27, top(0.1)), (0.0, top(0.11))], 1.02, 0.0), "gloss", BLACK)]
    for k in range(10):
        a0, a1 = math.radians(120 + 30 * k), math.radians(150 + 30 * k)
        lights.append(bar("Zeichen", (1.02 + 0.19 * math.cos(a0), 0.19 * math.sin(a0)),
                          (1.02 + 0.19 * math.cos(a1), 0.19 * math.sin(a1)), 0.06, top(0.1), top(0.125)))
    lights.append(bar("Zeichen", (1.02, 0.0), (1.02, 0.26), 0.07, top(0.105), top(0.13)))
    done("starter", parts, lights)


# --- KONTAKTE (Würfel): eine Reihe Kontaktfelder, die gemeinten leuchten -------------------------

PADS = [0.5 + i * 0.36 for i in range(4)]


def pad_row(lit, parts, lights):
    for i, u in enumerate(PADS):
        if i in lit:
            lights.append(slab("Kontakt", 0.13, 0.22, 0.04, T, top(0.05), u, 0.0))
        else:
            parts.append(paint(slab("Kontakt", 0.13, 0.22, 0.04, T, top(0.035), u, 0.0), "metal", STEEL))


def relay():
    """Relais: der ERSTE Kontakt leuchtet, darunter die Kupferspule."""
    reset()
    parts, lights = shell(KONTAKT)
    pad_row({0}, parts, lights)
    parts.append(paint(box("Spule", 0.3, 0.1, T, top(0.03), PADS[0], -0.32), "metal", COPPER))
    done("relay", parts, lights)


def output_stage():
    """Endstufe: der LETZTE Kontakt leuchtet, daneben Kühlrippen."""
    reset()
    parts, lights = shell(KONTAKT)
    pad_row({3}, parts, lights)
    parts += [paint(box("Rippe", 0.3, 0.035, T, top(0.05), PADS[3], s * (0.29 + k * 0.06)), "metal", ALU)
              for s in (-1, 1) for k in range(2)]
    done("output_stage", parts, lights)


def shunt():
    """Nebenschluss: die Kontakte, drumherum eine leuchtende Schleife."""
    reset()
    parts, lights = shell(KONTAKT)
    pad_row(set(), parts, lights)
    u0, u1 = PADS[0] - 0.22, PADS[3] + 0.22
    lights += [bar("Schleife", (u0, 0.31), (u1, 0.31), 0.07, T, top(0.03)), bar("Schleife", (u0, -0.31), (u1, -0.31), 0.07, T, top(0.03)),
               bar("Schleife", (u0, 0.34), (u0, -0.34), 0.07, T, top(0.03)), bar("Schleife", (u1, 0.34), (u1, -0.34), 0.07, T, top(0.03))]
    done("shunt", parts, lights)


def parallel_circuit():
    """Parallelschaltung: alle vier Kontakte leuchten, zwei Sammelschienen."""
    reset()
    parts, lights = shell(KONTAKT)
    pad_row({0, 1, 2, 3}, parts, lights)
    parts += [paint(box("Schiene", 1.36, 0.06, T, top(0.03), 1.04, s * 0.31), "metal", COPPER) for s in (-1, 1)]
    done("parallel_circuit", parts, lights)


# --- RÖHREN (Mult ×): Glaskolben liegend im Deckel ---------------------------------------------

def tube_feet(parts, r, u0, u1):
    for u in (u0, u1):
        parts.append(paint(band("Fassung", r, r + 0.03, 0.035, u), "metal", STEEL))


def amplifier_tube():
    """Verstärkerröhre: schlanke lange Röhre, heller Kern, zwei Gitter."""
    reset()
    parts, lights = shell(ROEHRE)
    paint(along("Glas", capsule(0.19, 0.64), 1.04), "glass", GLASS_VIOLET)
    tube_feet(parts, 0.19, 0.44, 1.64)
    parts += [paint(band("Gitter", 0.19, 0.205, 0.02, u), "metal", STEEL) for u in (0.86, 1.22)]
    lights.append(along("Kern", capsule(0.1, 0.56, 0.03), 1.04))
    done("amplifier_tube", parts, lights)


def high_voltage_tube():
    """Hochspannungsröhre: dicker Kolben, breiter Koronaring, Anodenkugel."""
    reset()
    parts, lights = shell(ROEHRE)
    paint(along("Glas", capsule(0.27, 0.42), 0.86), "glass", GLASS_VIOLET)
    tube_feet(parts, 0.27, 0.48, 1.24)
    parts.append(paint(dome("Kugel", [(0.15, T), (0.15, top(0.06)), (0.1, top(0.12)), (0.0, top(0.14))], 1.56, 0.0), "metal", STEEL))
    lights += [along("Kern", capsule(0.13, 0.32, 0.03), 0.86),
               band("Korona", 0.275, 0.31, 0.06, 0.86),
               cyl("Anode", 0.07, top(0.14), top(0.16), 1.56, 0.0, steps=24)]
    done("high_voltage_tube", parts, lights)


def resonator():
    """Schwingkreis: dünne Röhre in fünf Windungen - sie füllen sich mit dem Wachstum."""
    reset()
    parts, lights = shell(ROEHRE)
    paint(along("Glas", capsule(0.13, 0.64), 1.04), "glass", GLASS_VIOLET)
    tube_feet(parts, 0.13, 0.44, 1.64)
    lights.append(along("Kern", capsule(0.07, 0.58, 0.02), 1.04))
    for k in range(5):
        band("Ring%d" % k, 0.15, 0.25, 0.05, 0.64 + k * 0.2)
    done("resonator", parts, lights)


def afterburner():
    """Nachbrenner: Kühlrippen und die Düse im Deckel; scharf brennt die Flamme."""
    reset()
    parts, lights = shell(ROEHRE)
    parts += [paint(box("Rippe", 0.07, 0.56, T, top(0.07), 0.4 + i * 0.16, 0.0), "metal", ALU) for i in range(4)]
    parts.append(paint(ring("Duese", 0.2, 0.3, T, top(0.07), 1.4, 0.0, 48), "metal", STEEL))
    lights.append(box("Glut", 0.62, 0.5, T, top(0.012), 0.64, 0.0))
    lights.append(ring("Brennring", 0.15, 0.2, T, top(0.04), 1.4, 0.0, 40))
    dome("Flamme", [(0.15, T), (0.13, top(0.06)), (0.06, top(0.11)), (0.0, top(0.12))], 1.4, 0.0, 24)
    done("afterburner", parts, lights)


# --- ABGRIFFE (Ökonomie) -----------------------------------------------------------------------

def coin_validator():
    """Münzprüfer: Einwurfschlitz und eine große Goldmünze."""
    reset()
    parts, lights = shell(ABGRIFF)
    parts += [paint(dome("Muenze", [(0.3, T), (0.3, top(0.05)), (0.27, top(0.08)), (0.0, top(0.08))], 1.34, 0.0, 48), "metal", GOLD),
              paint(box("Blende", 0.62, 0.3, T, top(0.03), 0.62, 0.0), "metal", STEEL)]
    lights += [box("Schlitz", 0.48, 0.08, top(0.03), top(0.045), 0.62, 0.0),
               cyl("Praegung", 0.14, top(0.08), top(0.1), 1.34, 0.0, steps=32)]
    done("coin_validator", parts, lights)


def power_pickup():
    """Stromabnehmer: ein großer Blitz, am Ende der Schleifbügel."""
    reset()
    parts, lights = shell(ABGRIFF)
    parts.append(paint(box("Buegel", 0.14, 0.62, T, top(0.07), 1.64, 0.0), "metal", COPPER))
    zig = [(0.36, -0.14), (0.68, 0.18), (0.9, -0.14), (1.2, 0.18), (1.46, -0.06)]
    lights += [bar("Funke", a, b, 0.1, T, top(0.03)) for a, b in zip(zig, zig[1:])]
    done("power_pickup", parts, lights)


def blocking_diode():
    """Sperrdiode: groß das Schaltzeichen Dreieck-Strich auf einer Stahlbahn."""
    reset()
    parts, lights = shell(ABGRIFF)
    parts.append(paint(box("Bahn", 1.4, 0.1, T, top(0.02), 1.02, 0.0), "metal", STEEL))
    lights += [prism("Dreieck", uv_outline([(0.62, 0.27), (0.62, -0.27), (1.26, 0.0)]), top(0.02), top(0.05)),
               box("Strich", 0.12, 0.56, top(0.02), top(0.05), 1.34, 0.0)]
    done("blocking_diode", parts, lights)


# --- BRÜCKEN (Verbindung): der Pfeil auf dem Deckel --------------------------------------------

def cross_bridge():
    """Querbrücke: ein großer Pfeil nach Bild-rechts."""
    reset()
    parts, lights = shell(BRUECKE)
    lights += arrow("Pfeil", [(0.34, 0.0), (1.72, 0.0)], 0.16, 0.56, 0.42, T, top(0.03))
    done("cross_bridge", parts, lights)


def down_bridge():
    """Längsbrücke: ein Haken - erst nach rechts, dann nach Bild-unten."""
    reset()
    parts, lights = shell(BRUECKE)
    lights += arrow("Pfeil", [(0.34, 0.2), (1.4, 0.2), (1.4, -0.36)], 0.16, 0.5, 0.3, T, top(0.03))
    done("down_bridge", parts, lights)


def coupling():
    """Kopplung: ein Pfeil zurück nach links, rechts das Feld, in dem das kopierte Modul leuchtet."""
    reset()
    parts, lights = shell(BRUECKE)
    lights += arrow("Pfeil", [(1.0, 0.0), (0.34, 0.0)], 0.16, 0.5, 0.3, T, top(0.03))
    parts += [paint(f, "metal", STEEL) for f in (
        bar("Rahmen", (1.14, 0.31), (1.7, 0.31), 0.07, T, top(0.05)), bar("Rahmen", (1.14, -0.31), (1.7, -0.31), 0.07, T, top(0.05)),
        bar("Rahmen", (1.17, 0.34), (1.17, -0.34), 0.07, T, top(0.05)), bar("Rahmen", (1.67, 0.34), (1.67, -0.34), 0.07, T, top(0.05)))]
    box("Abbild", 0.42, 0.54, T, top(0.025), 1.42, 0.0)
    done("coupling", parts, lights)


# --- Das Blindfach -----------------------------------------------------------------------------

def empty():
    """Ein kleiner Chip: Gehäuse, dunkles Glas, Beinchen - bündig mit dem Deckel des Chips."""
    reset()
    slab("Gehaeuse", BLOCK / 2, PIN_V / 2, 0.06, 0.03, CHIP_TOP, BLOCK / 2, 0.0)
    slab("Glas", BLOCK / 2 - 0.14, PIN_V / 2 - 0.11, 0.05, CHIP_TOP, CHIP_TOP + 0.012, BLOCK / 2, 0.0)
    leg("Bein")
    export("empty")


BUILDS = {"resistor": resistor, "coil": coil, "series_resistor": series_resistor, "series_terminal": series_terminal,
          "capacitor": capacitor, "solder_joint": solder_joint, "counter": counter_part,
          "starter": starter, "relay": relay, "output_stage": output_stage, "shunt": shunt,
          "parallel_circuit": parallel_circuit, "amplifier_tube": amplifier_tube,
          "high_voltage_tube": high_voltage_tube, "resonator": resonator,
          "afterburner": afterburner, "coin_validator": coin_validator, "power_pickup": power_pickup,
          "blocking_diode": blocking_diode, "cross_bridge": cross_bridge, "down_bridge": down_bridge,
          "coupling": coupling, "empty": empty}

for name, build in BUILDS.items():
    if not ONLY or name in ONLY:
        build()
