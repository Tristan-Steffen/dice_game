"""Fumble: je MODUL ein eigenes 3D-Modell im PRÄZISIONS-Stil (Spieler-Wahl 2026-11-06 aus
fünf Entwürfen): gefräste Tasche in der Plattform, Klemmen und Schrauben wie an teurer Messtechnik.

Aufruf (kopflos):
  blender -b -P tools/blender_part_models.py -- assets/models/hardware

part_<id>.glb, Ursprung = Mitte der Sockel-UNTERSEITE. glTF: Godot (x, y, z) = Blender
(x, -z, y), also Bild-oben = Blender +X, Bild-rechts = Blender -Y.

Knoten: Stecker, Gehaeuse, Plattform (Godot tönt nach Seltenheit), Korpus, Licht (Godot
leuchtet in der Tönung der Modulart). Das Licht von Korpus und Plattform ist in die
Vertexfarben gemalt: der Tisch ist zu dunkel, um Metall zu tragen.

Stecker und Außenmaß spiegeln blender_combo_hardware.py und ComboPartBody: wer SIDE oder die
PIN-Maße ändert, zieht sie hier nach.
"""
import bmesh, bpy, math, os, sys
from mathutils import Matrix, Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/models/hardware"
os.makedirs(OUT, exist_ok=True)
SIDE, PIN_R, PIN_LEN, PIN_PITCH = 0.8, 0.03, 0.095, 0.8 * 0.26
BODY_TOP = 0.24
PT = 0.345  # Oberkante der Plattform
STEPS = 56

STEEL = (0.62, 0.65, 0.72)
TITAN = (0.42, 0.44, 0.5)
PEARL = (0.66, 0.67, 0.71)
COPPER = (0.95, 0.46, 0.22)
GOLD = (1.0, 0.72, 0.3)
BLACK = (0.035, 0.038, 0.05)
# Schwarzer Lack auf schwarzem Taschenboden verschwände: Teile tragen Graphit.
GRAPHITE = (0.2, 0.21, 0.25)
CERAMIC = (0.78, 0.73, 0.62)

LIGHT = Vector((-0.35, 0.45, 0.82)).normalized()
VIEW = Vector((-0.42, 0.1, 0.9)).normalized()
HALF = (LIGHT + VIEW).normalized()


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def matcap(kind, base, n, co):
    n = n.normalized()
    ndl = max(0.0, n.dot(LIGHT))
    spec = max(0.0, n.dot(HALF))
    fres = 1.0 - abs(n.dot(VIEW))
    # Studio-Umgebung: dunkler Horizont, helle Lichtwanne, eine schmale Lichtkante.
    r = 2.0 * n.dot(VIEW) * n - VIEW
    env = 0.16 + 0.72 * smooth(0.05, 0.75, r.z) + 0.55 * smooth(0.965, 0.995, r.dot(LIGHT))
    if kind == "metal":
        col = [c * env for c in base]
        add = spec ** 90 * 0.8
        alpha = 1.0
    elif kind == "gloss":
        col = [c * (0.55 + 0.75 * ndl) for c in base]
        add = spec ** 120 * 1.1 + fres ** 3 * 0.22
        alpha = 1.0
    elif kind == "satin":
        col = [c * (0.3 + 0.8 * ndl) for c in base]
        add = spec ** 28 * 0.22
        alpha = 1.0
    elif kind == "glass":
        col = list(base)
        add = spec ** 150 * 1.3
        alpha = min(1.0, 0.05 + fres ** 2.2 * 0.6 + spec ** 150)
    else:  # plate: Graustufen, Godot multipliziert die Seltenheitsfarbe
        sheen = 0.84 + 0.16 * (co.x + 0.4) / 0.8
        v = (0.34 + 0.72 * ndl) * sheen
        col = [v, v, v]
        add = spec ** 60 * 0.28
        alpha = 1.0
    return (*[min(1.6, c + add) for c in col], alpha)


def paint(obj, kind, base=(1, 1, 1)):
    mesh = obj.data
    mesh.calc_normals_split()
    attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    world = obj.matrix_world
    for loop in mesh.loops:
        co = world @ mesh.vertices[loop.vertex_index].co
        c = matcap(kind, base, world.to_3x3() @ Vector(loop.normal), co)
        # Kontaktschatten: wo der Aufbau in die Plattform läuft, wird er dunkler.
        if kind != "glass" and kind != "plate":
            ao = 0.45 + 0.55 * smooth(PT - 0.035, PT + 0.05, co.z)
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


def rect(w, h, cx=0.0, cy=0.0):
    return [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h / 2), (cx - w / 2, cy + h / 2)]


def rounded(half, radius, inset=0.0):
    half -= inset
    out = []
    for sx, sy, start in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for k in range(7):
            a = math.radians(start + 90 * k / 6)
            out.append((sx * (half - radius) + radius * math.cos(a), sy * (half - radius) + radius * math.sin(a)))
    return out


def slot_outline(length, width, cx=0.0):
    """Langloch längs Y."""
    r = width / 2
    out = []
    for k in range(13):
        a = math.pi * k / 12
        out.append((cx + r * math.cos(a), (length / 2 - r) + r * math.sin(a)))
    for k in range(13):
        a = math.pi + math.pi * k / 12
        out.append((cx + r * math.cos(a), -(length / 2 - r) + r * math.sin(a)))
    return out


def circle(radius, count=64):
    return [(radius * math.cos(2 * math.pi * i / count), radius * math.sin(2 * math.pi * i / count)) for i in range(count)]


def cut(target, cutter):
    mod = target.modifiers.new("Schnitt", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def join(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    return joined


def base(pockets=(), radius=0.05):
    """Stecker und Gehäuse wie immer; die Plattform trägt die Taschen, in denen der Aufbau sitzt."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, 0, BODY_TOP / 2)) @ Matrix.Diagonal((SIDE, SIDE, BODY_TOP, 1)))
    finish("Gehaeuse", bm, False)
    pins = []
    for i in (-1, 0, 1):
        for j in (-1, 0, 1):
            pins.append(lathe("Stift", [(PIN_R, -PIN_LEN), (PIN_R, 0.0)], (PIN_PITCH * i, PIN_PITCH * j, 0), steps=12))
    join("Stecker", pins)
    bm = bmesh.new()
    outline = rounded(SIDE / 2, radius)
    n = len(outline)
    ring0 = [bm.verts.new((x, y, BODY_TOP - 0.001)) for x, y in outline]
    ring1 = [bm.verts.new((x, y, PT - 0.012)) for x, y in outline]
    inner = rounded(SIDE / 2, radius, 0.012)
    ring2 = [bm.verts.new((x, y, PT)) for x, y in inner]
    for a, b in ((ring0, ring1), (ring1, ring2)):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(ring0)
    bm.faces.new(ring2)
    plate = finish("Plattform", bm, False)
    for outline2, floor in pockets:
        cut(plate, prism("Tasche", outline2, floor, PT + 0.1))
    for poly in plate.data.polygons:
        poly.use_smooth = True
    plate.data.auto_smooth_angle = math.radians(30)
    paint(plate, "plate")
    return plate


def floor_disc(outline, z, kind="gloss", color=BLACK):
    return paint(prism("Boden", outline, z - 0.004, z), kind, color)


def export(part_id):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "part_%s.glb" % part_id), use_selection=True,
                              export_apply=True, export_format="GLB", export_colors=True)
    print("BUILT", part_id)


def screws(z=PT):
    out = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            at = (sx * 0.325, sy * 0.325, 0)
            out.append(paint(lathe("Schraube", [(0.03, z - 0.002), (0.03, z + 0.008), (0.022, z + 0.012), (0.0, z + 0.012)], at, steps=16), "metal", STEEL))
    return out


def chevrons(z_of, xs=(0.2, -0.0, -0.2), wide=0.14, thick=0.05, reach=0.09, zoff=0.006):
    """Pfeilwinkel längs -Y, jeder folgt z_of(y)."""
    out = []
    for y0 in xs:
        bm = bmesh.new()
        pts = [(-wide, y0 + reach), (0.0, y0 - reach + thick * 0.0), (wide, y0 + reach),
               (wide, y0 + reach - thick), (0.0, y0 - reach - thick), (-wide, y0 + reach - thick)]
        verts = [bm.verts.new((x, y, z_of(y) + zoff)) for x, y in pts]
        bm.faces.new((verts[0], verts[1], verts[4], verts[5]))
        bm.faces.new((verts[1], verts[2], verts[3], verts[4]))
        out.append(finish("Winkel", bm, False))
    return out


def resistor():
    """Gewöhnlich, bis 0,10 hoch: ein Teil in seiner Tasche, zwei flache Schellen halten es."""
    reset()
    pocket = slot_outline(0.66, 0.31)
    base([(pocket, PT - 0.07)], 0.03)
    cz = PT - 0.015
    parts = [floor_disc(pocket, PT - 0.065)] + screws()
    # Wenige, tiefe Windungen: feine verschwimmen schon aus der Nähe.
    prof = [(0.0, -0.285), (0.085, -0.285), (0.1, -0.27)]
    turns = 18
    for i in range(turns + 1):
        prof.append((0.105 if i % 2 == 0 else 0.09, -0.25 + 0.5 * i / turns))
    prof += [(0.1, 0.27), (0.085, 0.285), (0.0, 0.285)]
    parts.append(paint(lathe("Wicklung", prof, (0, 0, cz), "Y", angle=18), "metal", COPPER))
    for s in (-1, 1):
        parts.append(paint(lathe("Schelle", [(0.113, s * 0.205 - 0.022), (0.113, s * 0.205 + 0.022)], (0, 0, cz), "Y"), "metal", STEEL))
    join("Korpus", parts)
    lathe("Licht", [(0.11, -0.022), (0.11, 0.022)], (0, 0, cz), "Y")
    export("resistor")


def magnetron():
    """Legendär, bis 0,25 hoch: Rippenkühler, Anode mit acht Kammern, um den Kern ein Lichtspalt."""
    reset()
    base([(circle(0.345), PT - 0.07)], 0.03)
    parts = [floor_disc(circle(0.345), PT - 0.065)] + screws()
    prof = [(0.33, PT - 0.065)]
    for i in range(4):
        z = PT + i * 0.05
        prof += [(0.335, z), (0.335, z + 0.026), (0.295, z + 0.028), (0.295, z + 0.05)]
    top = PT + 0.2
    prof += [(0.335, top), (0.335, top + 0.01), (0.32, top + 0.02), (0.0, top + 0.02)]
    parts.append(paint(lathe("Rippen", prof, angle=30), "metal", STEEL))
    parts.append(paint(lathe("Anode", [(0.27, top + 0.02), (0.27, top + 0.035), (0.265, top + 0.04), (0.125, top + 0.04),
                                       (0.115, top + 0.03), (0.115, top + 0.02), (0.27, top + 0.02)], angle=25, caps=False), "metal", COPPER))
    for i in range(8):
        v = prism("Kammer", rect(0.105, 0.05, 0.195, 0), top + 0.03, top + 0.045)
        v.data.transform(Matrix.Rotation(math.pi * i / 4 + math.pi / 8, 4, "Z"))
        parts.append(paint(v, "gloss", BLACK))
    # Der Kern bleibt Stahl, leuchten darf nur der schmale Spalt um ihn: Licht ist ein Akzent.
    parts.append(paint(lathe("Kern", [(0.072, top + 0.02), (0.072, top + 0.04), (0.06, top + 0.05), (0.0, top + 0.05)], steps=32), "metal", STEEL))
    join("Korpus", parts)
    lathe("Licht", [(0.074, top + 0.022), (0.113, top + 0.022), (0.113, top + 0.024), (0.074, top + 0.024), (0.074, top + 0.022)], caps=False)
    export("magnetron")


def arrow(half_tail, shaft, head, tail_y=0.3, neck_y=-0.03, tip_y=-0.335):
    """Pfeil längs -Y, also im Bild nach rechts."""
    return [(-shaft, tail_y), (-shaft, neck_y), (-head, neck_y), (0.0, tip_y), (head, neck_y), (shaft, neck_y), (shaft, tail_y)]


F = PT - 0.065  # Taschenboden
POCKET = PT - 0.07
SOLDER = (0.72, 0.74, 0.78)


def cyl(name, r, z0, z1, at=(0, 0), chamfer=0.0, steps=32):
    prof = [(r, z0), (r, z1 - chamfer)]
    if chamfer:
        prof.append((r - chamfer, z1))
    prof.append((0.0, z1))
    return lathe(name, prof, (at[0], at[1], 0), steps=steps, angle=30)


def ring(name, r0, r1, z0, z1, at=(0, 0), steps=48):
    return lathe(name, [(r0, z0), (r1, z0), (r1, z1), (r0, z1), (r0, z0)], (at[0], at[1], 0), steps=steps, angle=30, caps=False)


def block(name, w, h, z0, z1, cx=0.0, cy=0.0, inset=0.05):
    return prism(name, rect(w, h, cx, cy), z0, z1, inset)


def flat(name, w, h, z, cx=0.0, cy=0.0):
    return prism(name, rect(w, h, cx, cy), z, z + 0.002)


def strut(name, a, b, r, steps=10):
    a, b = Vector(a), Vector(b)
    d = b - a
    obj = lathe(name, [(r, 0.0), (r, d.length)], steps=steps, angle=60)
    obj.data.transform(Matrix.Translation(a) @ Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4())
    return obj


def torus(name, R, r, z, at=(0, 0), ribs=0, amp=0.1, nu=96, nv=14):
    bm = bmesh.new()
    rows = []
    for i in range(nu):
        u = 2 * math.pi * i / nu
        minor = r * (1 + amp * math.cos(ribs * u)) if ribs else r
        row = []
        for j in range(nv):
            v = 2 * math.pi * j / nv
            big = R + minor * math.cos(v)
            row.append(bm.verts.new((at[0] + big * math.cos(u), at[1] + big * math.sin(u), z + minor * math.sin(v))))
        rows.append(row)
    for i in range(nu):
        for j in range(nv):
            a, b = rows[i][j], rows[(i + 1) % nu][j]
            c, d = rows[(i + 1) % nu][(j + 1) % nv], rows[i][(j + 1) % nv]
            bm.faces.new((a, b, c, d))
    return finish(name, bm, True, 45)


def nut(name, r, z0, z1, at):
    return lathe(name, [(r, z0), (r, z1 - 0.008), (r * 0.7, z1), (0.0, z1)], (at[0], at[1], 0), steps=6, angle=25)


def seat(pocket):
    """Die gefräste Tasche samt Boden und den vier Schrauben."""
    base([(pocket, POCKET)], 0.03)
    return [floor_disc(pocket, F)] + screws()


def cross_bridge(part_id="cross_bridge", turn=0.0):
    """Legendär, bis 0,25 hoch: ein goldener Pfeil auf Isolatoren, über der schwarzen Tasche."""
    reset()
    spin = Matrix.Rotation(turn, 4, "Z")

    def turned(obj, kind, color=(1, 1, 1)):
        obj.data.transform(spin)
        obj.data.update()
        return paint(obj, kind, color)

    pocket = rect(0.5, 0.72) if turn == 0.0 else rect(0.72, 0.5)
    parts = seat(pocket)
    deck = PT + 0.17
    plate_top = deck + 0.04
    parts.append(turned(prism("Schiene", arrow(0.3, 0.11, 0.23), deck, plate_top, 0.035), "metal", GOLD))
    # Gerippte Keramik-Stützen tragen die Schiene, von der Seite liest sie als Hochspannung.
    for y in (0.2, 0.0, -0.17):
        prof = [(0.05, F)]
        for k in range(3):
            z = PT - 0.03 + k * 0.065
            prof += [(0.065, z), (0.065, z + 0.03), (0.04, z + 0.034), (0.04, z + 0.065)]
        prof += [(0.04, deck)]
        parts.append(turned(lathe("Stuetze", prof, (0, y, 0), steps=20, angle=25, caps=False), "gloss", CERAMIC))
    parts.append(turned(prism("Klemme", rect(0.3, 0.07, 0, 0.255), PT + 0.14, plate_top + 0.012, 0.05), "metal", STEEL))
    for x in (-1, 1):
        parts.append(turned(nut("Mutter", 0.03, plate_top + 0.012, PT + 0.248, (x * 0.09, 0.255)), "metal", STEEL))
    join("Korpus", parts)
    light = prism("Licht", arrow(0.2, 0.022, 0.09, 0.18, -0.09, -0.255), plate_top, plate_top + 0.002)
    light.data.transform(spin)
    export(part_id)


def down_bridge():
    cross_bridge("down_bridge", -math.pi / 2)


# --- Gewöhnlich: bis 0,10, ein Teil in seiner Tasche ---------------------------------------

def capacitor():
    reset()
    parts = seat(circle(0.3))
    parts.append(paint(ring("Fassung", 0.255, 0.295, F, PT + 0.02), "metal", STEEL))
    parts.append(paint(cyl("Dose", 0.25, F, PT + 0.085, chamfer=0.02), "gloss", GRAPHITE))
    join("Korpus", parts)
    z = PT + 0.085
    join("Licht", [flat("Kerbe", 0.3, 0.024, z), flat("Kerbe", 0.024, 0.3, z)])
    export("capacitor")


def coil():
    reset()
    parts = seat(circle(0.335))
    parts.append(paint(torus("Ringkern", 0.2, 0.09, PT - 0.005, ribs=26, amp=0.1), "metal", COPPER))
    parts.append(paint(cyl("Bolzen", 0.05, F, PT + 0.03, chamfer=0.012), "metal", STEEL))
    join("Korpus", parts)
    ring("Licht", 0.055, 0.1, PT - 0.03, PT - 0.027)
    export("coil")


def series_resistor():
    reset()
    parts = seat(rect(0.36, 0.68))
    parts.append(paint(block("Block", 0.26, 0.5, F, PT + 0.08), "gloss", CERAMIC))
    for s in (-1, 1):
        parts.append(paint(block("Lasche", 0.16, 0.08, F, PT + 0.02, 0, s * 0.285, 0.1), "metal", GOLD))
    join("Korpus", parts)
    flat("Licht", 0.032, 0.34, PT + 0.08)
    export("series_resistor")


def coin_validator():
    reset()
    parts = seat(circle(0.29))
    parts.append(paint(lathe("Muenze", [(0.255, F), (0.255, PT + 0.04), (0.24, PT + 0.05), (0.205, PT + 0.05), (0.195, PT + 0.035), (0.0, PT + 0.035)], angle=25), "metal", GOLD))
    half = [(0.31 * math.cos(math.pi * i / 24), 0.31 * math.sin(math.pi * i / 24)) for i in range(25)]
    parts.append(paint(prism("Schieber", half, PT, PT + 0.09, 0.03), "metal", STEEL))
    join("Korpus", parts)
    flat("Licht", 0.5, 0.022, PT + 0.05, 0, -0.022)
    export("coin_validator")


def starter():
    reset()
    parts = seat(circle(0.285))
    parts.append(paint(ring("Fassung", 0.24, 0.285, F, PT + 0.03), "metal", STEEL))
    parts.append(paint(lathe("Knopf", [(0.2, F), (0.2, PT + 0.04), (0.17, PT + 0.08), (0.1, PT + 0.095), (0.0, PT + 0.098)]), "gloss", GRAPHITE))
    join("Korpus", parts)
    ring("Licht", 0.2, 0.24, PT - 0.002, PT + 0.001)
    export("starter")


# --- Selten: bis 0,15, das Teil und ein mechanisches Merkmal --------------------------------

def relay():
    reset()
    parts = seat(rect(0.58, 0.58))
    for s in (-1, 1):
        parts.append(paint(block("Wand", 0.56, 0.03, F, PT + 0.11, 0, s * 0.265, 0.0), "metal", STEEL))
        parts.append(paint(block("Wand", 0.03, 0.5, F, PT + 0.11, s * 0.265, 0, 0.0), "metal", STEEL))
    prof = [(0.0, -0.17), (0.085, -0.17)]
    for i in range(13):
        prof.append((0.095 if i % 2 == 0 else 0.082, -0.15 + 0.3 * i / 12))
    prof += [(0.085, 0.17), (0.0, 0.17)]
    parts.append(paint(lathe("Spule", prof, (-0.07, 0, PT - 0.005), "Y", angle=18), "metal", COPPER))
    join("Korpus", parts)
    flat("Licht", 0.05, 0.36, PT + 0.03, 0.145, 0)
    paint(prism("Glas", rect(0.5, 0.5), PT + 0.104, PT + 0.112), "glass", (0.75, 0.9, 1.0))
    export("relay")


def output_stage():
    reset()
    parts = seat(rect(0.6, 0.66))
    for y in (0.14, 0.175, 0.21, 0.245, 0.28):
        for s in (-1, 1):
            parts.append(paint(block("Rippe", 0.52, 0.022, F, PT + 0.14, 0, s * y, 0.0), "metal", STEEL))
    parts.append(paint(block("Transistor", 0.3, 0.2, F, PT + 0.1), "gloss", GRAPHITE))
    parts.append(paint(cyl("Schraube", 0.035, PT + 0.1, PT + 0.13, (0.07, 0), 0.01, 16), "metal", GOLD))
    join("Korpus", parts)
    flat("Licht", 0.02, 0.15, PT + 0.1, -0.08)
    export("output_stage")


def solder_joint():
    reset()
    parts = seat(rect(0.62, 0.62))
    spots = [(0.2 * math.cos(math.radians(a)), 0.2 * math.sin(math.radians(a))) for a in (0, 120, 240)]
    lights = []
    for at in spots:
        parts.append(paint(lathe("Kegel", [(0.12, F), (0.105, PT - 0.03), (0.06, PT + 0.03), (0.03, PT + 0.095), (0.014, PT + 0.135), (0.0, PT + 0.142)], (at[0], at[1], 0), angle=60), "metal", SOLDER))
        parts.append(paint(strut("Bahn", (at[0], at[1], F + 0.006), (0, 0, F + 0.006), 0.016), "metal", GOLD))
        lights.append(ring("Saum", 0.125, 0.145, F, F + 0.004, at))
    join("Korpus", parts)
    join("Licht", lights)
    export("solder_joint")


def thermistor():
    reset()
    parts = seat(circle(0.32))
    z = PT + 0.015
    sphere = [(0.125 * math.sin(math.pi * i / 16), z - 0.125 * math.cos(math.pi * i / 16)) for i in range(17)]
    parts.append(paint(lathe("Perle", sphere, angle=70), "gloss", GRAPHITE))
    for s in (-1, 1):
        parts.append(paint(strut("Bein", (0, s * 0.09, z), (0, s * 0.265, F + 0.02), 0.018), "metal", GOLD))
        parts.append(paint(cyl("Kontakt", 0.04, F, F + 0.03, (0, s * 0.265), 0.008, 16), "metal", GOLD))
    join("Korpus", parts)
    lathe("Licht", [(0.127, z - 0.014), (0.127, z + 0.014)], caps=False)
    export("thermistor")


def series_terminal():
    reset()
    parts = seat(rect(0.38, 0.74))
    for y in (-0.235, 0.0, 0.235):
        parts.append(paint(block("Klemme", 0.32, 0.2, F, PT + 0.09, 0, y, 0.04), "metal", STEEL))
        parts.append(paint(cyl("Kopf", 0.068, PT + 0.09, PT + 0.135, (0.03, y), 0.012, 24), "metal", GOLD))
        parts.append(paint(flat("Schlitz", 0.1, 0.018, PT + 0.135, 0.03, y), "gloss", BLACK))
    join("Korpus", parts)
    flat("Licht", 0.022, 0.62, PT + 0.09, -0.125)
    export("series_terminal")


def blocking_diode():
    reset()
    parts = seat(slot_outline(0.68, 0.3))
    z = PT + 0.015
    parts.append(paint(lathe("Koerper", [(0.0, -0.16), (0.1, -0.16), (0.122, -0.14), (0.122, 0.14), (0.1, 0.16), (0.0, 0.16)], (0, 0, z), "Y", angle=30), "gloss", GRAPHITE))
    for s in (-1, 1):
        parts.append(paint(strut("Draht", (0, s * 0.16, z), (0, s * 0.27, F + 0.02), 0.022), "metal", GOLD))
        parts.append(paint(cyl("Kontakt", 0.045, F, F + 0.03, (0, s * 0.27), 0.008, 16), "metal", GOLD))
    join("Korpus", parts)
    lathe("Licht", [(0.125, -0.115), (0.125, -0.07)], (0, 0, z), "Y", caps=False)
    export("blocking_diode")


def power_pickup():
    reset()
    parts = seat(rect(0.36, 0.66))
    top = PT + 0.12
    for s in (-1, 1):
        parts.append(paint(block("Fuss", 0.3, 0.09, F, PT + 0.02, 0, s * 0.265, 0.05), "metal", STEEL))
        for x in (-0.1, 0.1):
            parts.append(paint(strut("Arm", (x, s * 0.265, PT + 0.01), (x * 0.5, 0, top), 0.018), "metal", STEEL))
    parts.append(paint(block("Buegel", 0.66, 0.075, top - 0.01, PT + 0.148, 0, 0, 0.03), "metal", GOLD))
    join("Korpus", parts)
    flat("Licht", 0.54, 0.018, PT + 0.148)
    export("power_pickup")


# --- Episch: bis 0,20, mehrere verbundene Stücke ----------------------------------------------

def amplifier_tube():
    reset()
    parts = seat(circle(0.31))
    parts.append(paint(ring("Sockel", 0.205, 0.31, F, PT + 0.012), "gloss", CERAMIC))
    for i in range(8):
        a = math.pi * i / 4
        parts.append(paint(cyl("Stift", 0.018, PT, PT + 0.03, (0.26 * math.cos(a), 0.26 * math.sin(a)), 0.004, 12), "metal", GOLD))
    parts.append(paint(ring("Anode", 0.1, 0.13, F, PT + 0.125), "metal", STEEL))
    join("Korpus", parts)
    cyl("Licht", 0.05, PT - 0.02, PT + 0.115, steps=20)
    paint(lathe("Glas", [(0.2, PT - 0.02), (0.2, PT + 0.1), (0.17, PT + 0.16), (0.09, PT + 0.192), (0.0, PT + 0.198)], angle=70, caps=False), "glass", (0.75, 0.9, 1.0))
    export("amplifier_tube")


def counter_part():
    reset()
    parts = seat(rect(0.5, 0.72))
    for y in (-0.22, 0.0, 0.22):
        prof = [(0.0, -0.16), (0.1, -0.16), (0.1, -0.15), (0.112, -0.145), (0.112, 0.145), (0.1, 0.15), (0.1, 0.16), (0.0, 0.16)]
        parts.append(paint(lathe("Rolle", prof, (0, y, PT + 0.01), "X", angle=30), "gloss", CERAMIC))
        for dy in (-0.05, 0.05):
            parts.append(paint(flat("Teilung", 0.2, 0.012, PT + 0.122 - 0.012, 0, y + dy), "gloss", BLACK))
    for s in (-1, 1):
        parts.append(paint(block("Wange", 0.05, 0.68, F, PT + 0.15, s * 0.205, 0, 0.0), "metal", STEEL))
    parts.append(paint(cyl("Rad", 0.05, PT + 0.15, PT + 0.195, (0.205, 0.28), 0.012, 24), "metal", GOLD))
    join("Korpus", parts)
    flat("Licht", 0.02, 0.6, PT + 0.123)
    export("counter")


def shunt():
    reset()
    parts = seat(rect(0.42, 0.72))
    for s in (-1, 1):
        parts.append(paint(block("Block", 0.36, 0.17, F, PT + 0.13, 0, s * 0.255, 0.04), "metal", COPPER))
        for x in (-0.09, 0.09):
            parts.append(paint(nut("Mutter", 0.04, PT + 0.13, PT + 0.188, (x, s * 0.255)), "metal", STEEL))
    for x in (-0.13, -0.065, 0.065, 0.13):
        parts.append(paint(block("Streifen", 0.034, 0.38, PT + 0.03, PT + 0.06, x, 0, 0.0), "metal", STEEL))
    join("Korpus", parts)
    block("Licht", 0.034, 0.38, PT + 0.03, PT + 0.06, 0, 0, 0.0)
    export("shunt")


def resonator():
    reset()
    parts = seat(rect(0.42, 0.74))
    parts.append(paint(torus("Spule", 0.095, 0.062, PT + 0.03, (0, 0.18), ribs=18, amp=0.14, nu=72), "metal", COPPER))
    parts.append(paint(cyl("Becher", 0.105, F, PT + 0.1, (0, -0.18), 0.018), "gloss", GRAPHITE))
    parts.append(paint(ring("Band", 0.106, 0.118, PT + 0.02, PT + 0.055, (0, -0.18)), "metal", STEEL))
    join("Korpus", parts)
    arc = []
    points = 12
    for i in range(points):
        def spot(t):
            y = 0.18 - 0.36 * t
            return (0, y, PT + 0.1 + 0.085 * math.sin(math.pi * t))
        arc.append(strut("Bogen", spot(i / points), spot((i + 1) / points), 0.014, 8))
    join("Licht", arc)
    export("resonator")


# --- Legendär: bis 0,25, eine kleine Baugruppe ------------------------------------------------

def high_voltage_tube():
    reset()
    parts = seat(circle(0.345))
    prof = [(0.33, F)]
    for k in range(3):
        z = PT - 0.04 + k * 0.05
        prof += [(0.338, z), (0.338, z + 0.025), (0.3, z + 0.03), (0.3, z + 0.05)]
    prof += [(0.3, PT + 0.11), (0.215, PT + 0.12), (0.215, F)]
    parts.append(paint(lathe("Isolator", prof, angle=30, caps=False), "gloss", CERAMIC))
    parts.append(paint(ring("Anode", 0.1, 0.125, F, PT + 0.165), "metal", STEEL))
    parts.append(paint(lathe("Kappe", [(0.06, PT + 0.205), (0.06, PT + 0.24), (0.045, PT + 0.25), (0.0, PT + 0.25)], steps=24, caps=True), "metal", GOLD))
    join("Korpus", parts)
    cyl("Licht", 0.05, PT, PT + 0.155, steps=20)
    paint(lathe("Glas", [(0.21, PT + 0.11), (0.2, PT + 0.17), (0.13, PT + 0.215), (0.0, PT + 0.235)], angle=70, caps=False), "glass", (0.75, 0.9, 1.0))
    export("high_voltage_tube")


def coupling():
    reset()
    parts = seat(rect(0.5, 0.74))
    for s in (-1, 1):
        parts.append(paint(block("Halfte", 0.38, 0.27, F, PT + 0.17, 0, s * 0.18, 0.03), "gloss", GRAPHITE))
        parts.append(paint(block("Band", 0.4, 0.05, PT + 0.08, PT + 0.12, 0, s * 0.18, 0.0), "metal", STEEL))
        for x in (-0.1, 0.1):
            parts.append(paint(nut("Mutter", 0.03, PT + 0.17, PT + 0.245, (x, s * 0.2)), "metal", STEEL))
        for y in (0.09, 0.18, 0.27):
            for side in (-1, 1):
                parts.append(paint(cyl("Stift", 0.016, F, PT + 0.025, (side * 0.222, s * y), 0.004, 10), "metal", GOLD))
    join("Korpus", parts)
    block("Licht", 0.32, 0.028, F, PT + 0.17, 0, 0, 0.0)
    export("coupling")


def parallel_circuit():
    reset()
    parts = seat(rect(0.52, 0.74))
    for s in (-1, 1):
        parts.append(paint(block("Schiene", 0.48, 0.09, F, PT + 0.2, 0, s * 0.3, 0.03), "metal", STEEL))
    lights = []
    for x in (-0.16, 0.0, 0.16):
        parts.append(paint(lathe("Stab", [(0.05, -0.27), (0.05, 0.27)], (x, 0, PT + 0.13), "Y", angle=60, caps=False), "metal", COPPER))
        lights.append(lathe("Band", [(0.053, -0.026), (0.053, 0.026)], (x, 0, PT + 0.13), "Y", caps=False))
        for s in (-1, 1):
            parts.append(paint(nut("Mutter", 0.03, PT + 0.2, PT + 0.248, (x, s * 0.3)), "metal", GOLD))
    join("Korpus", parts)
    join("Licht", lights)
    export("parallel_circuit")


# --- Die Platine: ihre Buchsen setzt Godot ein, die Maße spiegeln ComboPartBody --------------

def expansion_board():
    reset()
    outer, pitch, shift = 0.868, 0.874, 0.17
    depth, width, thick = outer + 0.02, pitch + outer + 0.02, 0.19 + 0.11 + 0.012
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, 0, 0.16)) @ Matrix.Diagonal((SIDE, SIDE, 0.32, 1)))
    finish("Gehaeuse", bm, False)
    pins = []
    for i in (-1, 0, 1):
        for j in (-1, 0, 1):
            pins.append(lathe("Stift", [(PIN_R, -PIN_LEN), (PIN_R, 0.0)], (PIN_PITCH * i, PIN_PITCH * j, 0), steps=12))
    join("Stecker", pins)
    z0 = 0.32
    top = z0 + thick
    by = -shift
    board = prism("Plattform", rect(depth, width, 0, by), z0, top, 0.004)
    for s in (-1, 1):
        cut(board, prism("Loch", rect(outer, outer, 0, by + s * pitch * 0.5), z0 - 0.1, top + 0.1))
    paint(board, "plate")
    join("Korpus", [paint(prism("Steg", rect(depth - 0.002, 0.006, 0, by), top - 0.002, top + 0.002), "metal", GOLD)])
    export("riser")
    bpy.ops.object.select_all(action="DESELECT")


for build in (resistor, magnetron, cross_bridge, down_bridge, capacitor, coil, series_resistor, coin_validator,
              starter, relay, output_stage, solder_joint, thermistor, series_terminal, blocking_diode, power_pickup,
              amplifier_tube, counter_part, shunt, resonator, high_voltage_tube, coupling, parallel_circuit,
              expansion_board):
    build()
