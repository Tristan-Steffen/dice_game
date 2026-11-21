"""Fumble: Charm-Modelle aus Blender statt aus dem Bild-zu-3D-Generator (PILOT, sechs Stück).

Aufruf (kopflos, aus dem Projektordner):
  blender -b -P tools/blender_charm_models.py -- <ausgabe-ordner> [charm_id ...]

Je Charm: <id>.blend (benannte Teile, benannte Materialien, Modifier unangewandt), <id>.glb und
<id>.png (links das alte Modell, Mitte und rechts das neue von vorn und hinten).

Maß wie die alten Modelle: Ursprung = Mitte der Unterseite, größte Ausdehnung 1, Blender-Z oben,
Vorderseite = Blender -Y.
"""
import bmesh, bpy, math, os, random, sys
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "charm_pilot")
OLD = os.path.abspath("assets/models")
PI = math.pi
ROOT = None
GROUP = None
MATS = {}


# --- Werkzeug ---------------------------------------------------------------------------

def reset(name):
    global ROOT, GROUP
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()
    ROOT = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(ROOT)
    GROUP = None


def mat(name, color, metallic=0.0, rough=0.5, glow=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    if glow > 0:
        p.inputs["Emission"].default_value = (*color, 1)
        p.inputs["Emission Strength"].default_value = glow
    m.diffuse_color = (*color, 1)
    MATS[name] = m
    return m


def link(obj):
    bpy.context.collection.objects.link(obj)
    obj.parent = GROUP or ROOT
    return obj


def finish(name, bm, mats, smooth=True, angle=40.0):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in mats if isinstance(mats, (list, tuple)) else [mats]:
        mesh.materials.append(m)
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    mesh.use_auto_smooth = True
    mesh.auto_smooth_angle = math.radians(angle)
    return link(bpy.data.objects.new(name, mesh))


def bevel(obj, width, segments=2):
    mod = obj.modifiers.new("Fase", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    return obj


def box(name, size, loc, material, rot=None, fase=0.0):
    bm = bmesh.new()
    m = Matrix.Translation(loc) @ (rot or Matrix.Identity(4)) @ Matrix.Diagonal((*size, 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    obj = finish(name, bm, material, False)
    return bevel(obj, fase) if fase else obj


def ball(name, radius, loc, material, scale=(1, 1, 1), rot=None, seg=24):
    bm = bmesh.new()
    m = Matrix.Translation(loc) @ (rot or Matrix.Identity(4)) @ Matrix.Diagonal((*scale, 1))
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=radius, matrix=m)
    return finish(name, bm, material)


def lathe(name, profile, material, center=(0, 0, 0), axis="Z", steps=48, angle=40.0):
    """profile = Folge aus (Radius, Lage längs der Achse)."""
    bm = bmesh.new()
    rings = []
    for radius, along in profile:
        ring = []
        for i in range(steps):
            a = 2 * PI * i / steps
            c, s = radius * math.cos(a), radius * math.sin(a)
            co = {"Z": (c, s, along), "Y": (c, along, s), "X": (along, c, s)}[axis]
            ring.append(bm.verts.new(Vector(co) + Vector(center)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(steps):
            j = (i + 1) % steps
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    if profile[0][0] > 0:
        bm.faces.new(rings[0])
    if profile[-1][0] > 0:
        bm.faces.new(rings[-1])
    return finish(name, bm, material, True, angle)


def slab(name, points, normal, thick, material):
    """Flache Platte: ebenes Vieleck, um thick längs der Normale ausgezogen."""
    bm = bmesh.new()
    half = Vector(normal).normalized() * thick * 0.5
    low = [bm.verts.new(Vector(p) - half) for p in points]
    high = [bm.verts.new(Vector(p) + half) for p in points]
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((low[i], low[j], high[j], high[i]))
    bm.faces.new(low)
    bm.faces.new(high)
    return finish(name, bm, material, False)


def text(name, body, size, depth, material, matrix):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.extrude = depth
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    obj = link(bpy.data.objects.new(name, curve))
    obj.matrix_local = matrix
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    obj.data.materials.append(material)
    return obj


def catmull(points, per=8):
    p = [Vector(q) for q in points]
    p = [p[0]] + p + [p[-1]]
    out = []
    for i in range(1, len(p) - 2):
        for k in range(per):
            u = k / per
            out.append(0.5 * (2 * p[i] + (p[i + 1] - p[i - 1]) * u
                              + (2 * p[i - 1] - 5 * p[i] + 4 * p[i + 1] - p[i + 2]) * u * u
                              + (3 * p[i] - p[i - 1] - 3 * p[i + 1] + p[i + 2]) * u ** 3))
    out.append(p[-2])
    return out


def curve1d(xs, ys):
    """Glatte Kennlinie durch Stützpunkte."""
    def f(t):
        t = max(xs[0], min(xs[-1], t))
        i = 0
        while i < len(xs) - 2 and t > xs[i + 1]:
            i += 1
        u = (t - xs[i]) / (xs[i + 1] - xs[i])
        y0, y1, y2, y3 = ys[max(i - 1, 0)], ys[i], ys[i + 1], ys[min(i + 2, len(ys) - 1)]
        v = 0.5 * (2 * y1 + (y2 - y0) * u + (2 * y0 - 5 * y1 + 4 * y2 - y3) * u * u
                   + (3 * y1 - y0 - 3 * y2 + y3) * u ** 3)
        return max(0.0, v)
    return f


def round_section(corner=0.35, steps=4):
    out = []
    for sx, sy, start in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for k in range(steps + 1):
            a = math.radians(start + 90 * k / steps)
            out.append((sx * (1 - corner) + corner * math.cos(a), sy * (1 - corner) + corner * math.sin(a)))
    return out


def sweep(name, path, radius, mats, sides=16, section=None, normals=None, up=(0, 1, 0),
          mat_fn=None, closed=False, caps=(True, True), cap_mats=(0, 0)):
    """Querschnitt längs eines Pfads. radius: Zahl, (a, b) oder f(t) -> Zahl | (a, b).
    Liefert (Objekt, Rahmen je Ring: p, t, n, b, ra, rb, tan)."""
    pts = [Vector(p) for p in path]
    n = len(pts)
    tans = []
    for i in range(n):
        a = pts[i - 1] if (i > 0 or closed) else pts[i]
        b = pts[(i + 1) % n] if (i < n - 1 or closed) else pts[i]
        tans.append((b - a).normalized())
    ns = []
    if normals:
        for i in range(n):
            v = Vector(normals[i])
            ns.append((v - tans[i] * tans[i].dot(v)).normalized())
    else:
        v = Vector(up)
        v = v - tans[0] * tans[0].dot(v)
        if v.length < 1e-4:
            v = Vector((1, 0, 0)) - tans[0] * tans[0].x
        v.normalize()
        for i in range(n):
            if i > 0:
                v = tans[i - 1].rotation_difference(tans[i]) @ v
                v = (v - tans[i] * tans[i].dot(v)).normalized()
            ns.append(v.copy())
    section = section or [(math.cos(2 * PI * j / sides), math.sin(2 * PI * j / sides)) for j in range(sides)]
    m = len(section)
    bm = bmesh.new()
    rings, frames = [], []
    for i in range(n):
        t = i / (n - 1) if n > 1 else 0.0
        r = radius(t) if callable(radius) else radius
        ra, rb = r if isinstance(r, (tuple, list)) else (r, r)
        bi = tans[i].cross(ns[i]).normalized()
        frames.append({"p": pts[i], "t": t, "n": ns[i], "b": bi, "ra": ra, "rb": rb, "tan": tans[i]})
        rings.append([bm.verts.new(pts[i] + ns[i] * a * ra + bi * b * rb) for a, b in section])
    for i in range(n if closed else n - 1):
        k = (i + 1) % n
        for j in range(m):
            l = (j + 1) % m
            face = bm.faces.new((rings[i][j], rings[i][l], rings[k][l], rings[k][j]))
            if mat_fn:
                face.material_index = mat_fn(i, j, frames[i]["t"])
    if not closed:
        if caps[0] and frames[0]["ra"] > 0:
            bm.faces.new(rings[0]).material_index = cap_mats[0]
        if caps[1] and frames[-1]["ra"] > 0:
            bm.faces.new(rings[-1]).material_index = cap_mats[1]
    return finish(name, bm, mats), frames


def circle_path(center, radius, axis="Y", count=48):
    out = []
    for i in range(count):
        a = 2 * PI * i / count
        c, s = radius * math.cos(a), radius * math.sin(a)
        out.append(Vector(center) + Vector({"Y": (c, 0, s), "Z": (c, s, 0), "X": (0, c, s)}[axis]))
    return out


def ring(name, center, radius, tube, material, axis="Y", sides=10, count=48):
    up = {"Y": (0, 1, 0), "Z": (0, 0, 1), "X": (1, 0, 0)}[axis]
    return sweep(name, circle_path(center, radius, axis, count), tube, [material], sides=sides, up=up, closed=True)[0]


def group(name, matrix=None):
    """Leer-Objekt, unter dem die folgenden Teile hängen (bis GROUP = None)."""
    global GROUP
    GROUP = None
    GROUP = link(bpy.data.objects.new(name, None))
    if matrix:
        GROUP.matrix_local = matrix
    return GROUP


def limb(name, points, r0, r1, material, pointed=False, sides=12):
    def r(t):
        base = r0 + (r1 - r0) * t
        return base * (1 - t ** 3) if pointed else base
    return sweep(name, catmull(points, 6) if len(points) > 2 else points, r, [material], sides=sides, up=(0, 0, 1))[0]


def frame_at(frames, t):
    return min(frames, key=lambda f: abs(f["t"] - t))


def aim_z(direction):
    return Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized()).to_matrix().to_4x4()


# --- Die sechs Piloten ------------------------------------------------------------------

def horseshoe():
    chrome = mat("Chrom", (0.8, 0.8, 0.84), 0.85, 0.2)
    enamel = mat("Emaille", (0.025, 0.025, 0.035), 0.3, 0.25)
    R = 0.4

    def pt(deg):
        a = math.radians(deg)
        return Vector((R * math.cos(a), 0, R * 1.18 * math.sin(a)))

    def wide(t):
        return 0.85 + 0.25 * math.sin(PI * t)

    section = round_section(0.45)
    sweep("Eisen", [pt(140 + 260 * i / 72) for i in range(73)], lambda t: (0.05, 0.1 * wide(t)), [chrome], section=section)
    sweep("Einlage", [pt(158 + 224 * i / 60) for i in range(61)], lambda t: (0.053, 0.064 * wide(0.07 + 0.86 * t)),
          [enamel], section=section)
    for side in (-1, 1):
        for deg in (196, 221, 246, 270, 294, 319, 344):
            ring("Nagelloch", pt(deg) + Vector((0, side * 0.054, 0)), 0.021, 0.008, chrome, "Y", 8, 16)
    for deg in (140, 400):
        spin = Matrix.Rotation(-(math.radians(deg) + PI / 2), 4, "Y")
        box("Stollen", (0.13, 0.15, 0.21), pt(deg), chrome, spin, 0.035)


def silver_dollar():
    silver = mat("Silber", (0.86, 0.88, 0.93), 0.85, 0.2)
    field = mat("Feld", (0.13, 0.14, 0.17), 0.7, 0.35)
    steel = mat("Halter", (0.3, 0.32, 0.38), 0.8, 0.3)
    neon = mat("Neon", (0.15, 0.9, 1.0), 0.0, 0.3, 5.0)
    c = (0, 0, 0.5)
    lathe("Muenze", [(0, -0.026), (0.425, -0.026), (0.44, -0.04), (0.495, -0.04), (0.495, 0.04),
                     (0.44, 0.04), (0.425, 0.026), (0, 0.026)], silver, c, "Y", 96)
    lathe("Lichtrand", [(0.499, -0.026), (0.499, 0.026)], neon, c, "Y", 64)
    for i in range(48):
        a = 2 * PI * i / 48
        box("Riffel", (0.03, 0.082, 0.014), (0.5 * math.cos(a), 0, 0.5 + 0.5 * math.sin(a)), silver,
            Matrix.Rotation(-a, 4, "Y"))
    for side in (-1, 1):
        lathe("Feld", [(0, side * 0.027), (0.425, side * 0.027)], field, c, "Y", 64)
        ring("Neonring", (0, side * 0.03, 0.5), 0.405, 0.013, neon, "Y", 8)
        face = Matrix.Translation((0, side * 0.027, 0.5)) @ Matrix.Rotation(PI / 2, 4, "X")
        if side > 0:
            face = Matrix.Translation((0, 0.027, 0.5)) @ Matrix.Rotation(PI, 4, "Z") @ Matrix.Rotation(PI / 2, 4, "X")
        text("Dollar", "$", 0.72, 0.014, silver, face)
    arc = [Vector((0.58 * math.cos(math.radians(d)), 0, 0.5 + 0.58 * math.sin(math.radians(d)))) for d in range(208, 334, 3)]
    sweep("Gabel", arc, (0.085, 0.05), [steel], section=round_section(0.4))
    for d in (208, 332):
        a = math.radians(d)
        box("Klaue", (0.13, 0.2, 0.13), (0.56 * math.cos(a), 0, 0.5 + 0.56 * math.sin(a)), steel,
            Matrix.Rotation(-a, 4, "Y"), 0.03)
    box("Hals", (0.26, 0.2, 0.14), (0, 0, -0.14), steel, fase=0.02)
    lathe("Sockel", [(0.4, -0.3), (0.4, -0.26), (0.32, -0.2), (0.0, -0.2)], steel, steps=6)
    lathe("Sockellicht", [(0.405, -0.262), (0.405, -0.25)], neon, steps=6)


PIPS = {1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)], 4: [(-1, -1), (-1, 1), (1, -1), (1, 1)],
        5: [(-1, -1), (-1, 1), (1, -1), (1, 1), (0, 0)], 6: [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)]}


def die(name, size, matrix, body, pip):
    global GROUP
    group(name, matrix)
    box("Koerper", (size, size, size), (0, 0, 0), body, fase=size * 0.12)
    faces = (((0, 0, 1), (1, 0, 0), (0, 1, 0), 5), ((0, -1, 0), (1, 0, 0), (0, 0, 1), 6),
             ((1, 0, 0), (0, 1, 0), (0, 0, 1), 3), ((-1, 0, 0), (0, 1, 0), (0, 0, 1), 4),
             ((0, 1, 0), (1, 0, 0), (0, 0, 1), 1), ((0, 0, -1), (1, 0, 0), (0, 1, 0), 2))
    for normal, u, v, count in faces:
        for a, b in PIPS[count]:
            at = Vector(normal) * size * 0.485 + Vector(u) * a * size * 0.27 + Vector(v) * b * size * 0.27
            ball("Auge", size * 0.085, at, pip, seg=10)
    GROUP = None


def heat_sink():
    alu = mat("Aluminium", (0.74, 0.77, 0.83), 0.8, 0.3)
    copper = mat("Kupfer", (0.95, 0.48, 0.22), 0.8, 0.28)
    black = mat("Eloxal", (0.07, 0.075, 0.09), 0.4, 0.5)
    frost = mat("Kaelte", (0.25, 0.85, 1.0), 0.0, 0.3, 4.0)
    blue = mat("Wuerfelblau", (0.06, 0.16, 0.85), 0.1, 0.12)
    white = mat("Wuerfelauge", (0.97, 0.97, 0.97), 0.0, 0.3)
    box("Sockel", (1.0, 0.9, 0.1), (0, 0, 0.05), black, fase=0.012)
    for i in range(11):
        box("Rippe", (0.036, 0.86, 0.4), (-0.45 + 0.9 * i / 10, 0, 0.3), alu, fase=0.006)
    box("Deckplatte", (0.74, 0.7, 0.05), (0, 0, 0.525), alu, fase=0.012)
    for k, y in enumerate((-0.3, 0.3)):
        path = catmull([(-0.3, y, 0.075), (-0.54, y, 0.075), (-0.62, y, 0.14), (-0.62, y, 0.27), (-0.54, y, 0.34),
                        (0.54, y, 0.34), (0.62, y, 0.27), (0.62, y, 0.14), (0.54, y, 0.075), (0.3, y, 0.075)], 6)
        sweep("Waermerohr%d" % k, path, 0.034, [copper], sides=14, up=(0, 1, 0))
    lathe("Kaeltefeld", [(0.0, 0.553), (0.2, 0.553), (0.21, 0.55)], frost, steps=40)
    ring("Kaeltering", (0, 0, 0.552), 0.26, 0.008, frost, "Z", 6, 40)
    die("Wuerfel", 0.24, Matrix.Translation((0, 0, 0.7)) @ Matrix.Rotation(math.radians(25), 4, "Z"), blue, white)


def fox_tail():
    fur = mat("Fell", (0.9, 0.27, 0.04), 0.0, 0.4)
    tip = mat("Spitze", (0.99, 0.94, 0.84), 0.0, 0.45)
    gold = mat("Beschlag", (1.0, 0.7, 0.25), 0.85, 0.25)
    path = catmull([(0.0, 0, 0.86), (0.03, 0, 0.72), (0.14, 0, 0.52), (0.13, 0, 0.3), (-0.02, 0, 0.12), (-0.2, 0, 0.0)], 10)
    girth = curve1d([0, 0.12, 0.35, 0.6, 0.8, 0.93, 1], [0.06, 0.11, 0.185, 0.215, 0.17, 0.085, 0.0])
    sides = 20

    def paint(_i, j, t):
        return 1 if t > 0.68 + (0.05 if (j // 2) % 2 else -0.05) else 0

    _body, frames = sweep("Schweif", path, girth, [fur, tip], sides=sides, mat_fn=paint)
    for k, t in enumerate((0.84, 0.9, 0.95)):
        f = frame_at(frames, t)
        for q in range(4):
            a = 2 * PI * (q / 4 + k * 0.13)
            out = f["n"] * math.cos(a) + f["b"] * math.sin(a)
            length = 0.07 + 0.45 * f["ra"]
            m = Matrix.Translation(f["p"] + out * f["ra"] * 0.55) @ aim_z(f["tan"] + out * 0.45)
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=False, segments=10, radius1=0.045, radius2=0.0, depth=length,
                                  matrix=m @ Matrix.Translation((0, 0, length / 2)))
            finish("Strähne", bm, tip)
    for t, grow in ((0.1, 1.12), (0.16, 1.1)):
        f = frame_at(frames, t)
        band = [f["p"] + (f["n"] * math.cos(2 * PI * q / 32) + f["b"] * math.sin(2 * PI * q / 32)) * f["ra"] * grow
                for q in range(32)]
        sweep("Reif", band, (0.022, 0.014), [gold], section=round_section(0.5), up=f["tan"], closed=True)
    lathe("Kappe", [(0.05, 0.8), (0.075, 0.81), (0.075, 0.89), (0.04, 0.925), (0, 0.925)], gold, steps=32)
    ring("Oese", (0, 0, 0.945), 0.026, 0.01, gold, "X", 8, 24)
    ring("Ring", (0, 0, 1.02), 0.075, 0.014, gold, "Y", 10, 40)


def rainbow_trout():
    back = mat("Ruecken", (0.05, 0.5, 0.42), 0.3, 0.3)
    band = mat("Regenbogen", (1.0, 0.2, 0.5), 0.3, 0.28)
    flank = mat("Flanke", (0.75, 0.6, 0.95), 0.4, 0.28)
    belly = mat("Bauch", (0.98, 0.95, 0.9), 0.1, 0.35)
    fin = mat("Flosse", (1.0, 0.7, 0.22), 0.85, 0.25)
    dark = mat("Auge", (0.02, 0.02, 0.03), 0.0, 0.08)
    white = mat("Glanz", (1.0, 1.0, 1.0), 0.0, 0.2, 1.0)
    water = mat("Wasser", (0.3, 0.8, 1.0), 0.0, 0.15, 1.5)
    path = catmull([(-0.1, 0, 0.14), (-0.16, 0, 0.34), (-0.12, 0, 0.56), (0.0, 0, 0.76), (0.2, 0, 0.9)], 10)
    high = curve1d([0, 0.1, 0.25, 0.45, 0.62, 0.78, 0.9, 0.97, 1], [0.045, 0.06, 0.105, 0.155, 0.175, 0.16, 0.12, 0.07, 0.0])
    sides = 24

    def paint(_i, j, _t):
        v = math.sin(2 * PI * (j + 0.5) / sides)
        return 0 if v > 0.55 else 1 if v > 0.05 else 2 if v > -0.5 else 3

    _body, frames = sweep("Leib", path, lambda t: (0.72 * high(t), high(t)), [back, band, flank, belly],
                          sides=sides, mat_fn=paint)

    def flosse(name, t, outline, y=0.0, lean=0.0):
        f = frame_at(frames, t)
        pts = [f["p"] + f["tan"] * u + f["b"] * v + f["n"] * (y + lean * abs(v)) for u, v in outline]
        bevel(slab(name, pts, f["n"], 0.02, fin), 0.006)

    flosse("Schwanzflosse", 0.0, [(0.05, 0.04), (-0.07, 0.16), (-0.15, 0.2), (-0.09, 0.0), (-0.15, -0.2),
                                  (-0.07, -0.16), (0.05, -0.04)])
    h = frame_at(frames, 0.52)["rb"]
    flosse("Rueckenflosse", 0.52, [(-0.1, h * 0.8), (-0.085, h + 0.1), (0.0, h + 0.085), (0.08, h * 0.8)])
    h = frame_at(frames, 0.24)["rb"]
    flosse("Afterflosse", 0.24, [(-0.04, -h * 0.8), (-0.07, -h - 0.075), (0.0, -h - 0.055), (0.05, -h * 0.8)])
    for side in (-1, 1):
        f = frame_at(frames, 0.7)
        flosse("Brustflosse", 0.7, [(0.03, -f["rb"] * 0.35), (-0.1, -f["rb"] * 0.75), (-0.13, -f["rb"] * 1.05),
                                    (-0.02, -f["rb"] * 0.8)], side * f["ra"] * 0.8, side * 0.45)
        f = frame_at(frames, 0.88)
        eye = f["p"] + f["n"] * side * f["ra"] * 0.72 + f["b"] * f["rb"] * 0.25
        ball("Iris", 0.05, eye, fin, seg=16)
        ball("Auge", 0.042, eye + f["n"] * side * 0.016, dark, seg=16)
        ball("Glanz", 0.012, eye + f["n"] * side * 0.05 + f["b"] * 0.02 + f["tan"] * 0.012, white, seg=8)
    rng = random.Random(7)
    for _k in range(26):
        f = frame_at(frames, rng.uniform(0.12, 0.8))
        a = math.radians(rng.uniform(40, 140))
        at = f["p"] + f["n"] * math.cos(a) * f["ra"] + f["b"] * math.sin(a) * f["rb"]
        ball("Tupfen", rng.uniform(0.008, 0.013), at, dark, seg=8)
    ring("Welle1", (-0.1, 0, 0.02), 0.19, 0.022, water, "Z", 8)
    ring("Welle2", (-0.1, 0, 0.012), 0.31, 0.013, water, "Z", 8)
    for a, r, z, s in ((0.6, 0.24, 0.2, 0.03), (2.3, 0.28, 0.13, 0.022), (3.6, 0.22, 0.26, 0.026),
                       (4.7, 0.29, 0.1, 0.02), (5.5, 0.21, 0.16, 0.017)):
        ball("Tropfen", s, (-0.1 + r * math.cos(a), r * math.sin(a), z), water, (1, 1, 1.35), seg=10)


def poker_chip(name, center, normal, radius, thick, color):
    global GROUP
    white = mat("ChipWeiss", (0.96, 0.96, 0.93), 0.0, 0.35)
    group(name, Matrix.Translation(center) @ aim_z(normal))
    h = thick / 2
    lathe("Scheibe", [(0, -h), (radius * 0.95, -h), (radius, -h * 0.6), (radius, h * 0.6), (radius * 0.95, h), (0, h)],
          color, steps=40)
    for i in range(6):
        a = 2 * PI * i / 6
        box("Einsatz", (radius * 0.2, radius * 0.36, thick * 1.04),
            (radius * 0.915 * math.cos(a), radius * 0.915 * math.sin(a), 0), white, Matrix.Rotation(a, 4, "Z"))
    for side in (-1, 1):
        ring("Kreis", (0, 0, side * h), radius * 0.6, radius * 0.035, white, "Z", 6, 32)
    GROUP = None


def hermit_crab():
    global GROUP
    shell = mat("Panzer", (0.93, 0.8, 0.66), 0.0, 0.4)
    steel = mat("Stahl", (0.55, 0.58, 0.66), 0.85, 0.22)
    black = mat("Gelenk", (0.05, 0.05, 0.07), 0.3, 0.4)
    eye = mat("Auge", (0.15, 0.9, 1.0), 0.0, 0.2, 4.0)
    chips = [("ChipRot", (0.8, 0.06, 0.09)), ("ChipBlau", (0.08, 0.18, 0.75)), ("ChipGelb", (0.96, 0.74, 0.08)),
             ("ChipGruen", (0.08, 0.58, 0.24))]
    spine = [Vector(p) for p in ((0, 0.1, 0.34), (0, 0.2, 0.37), (0, 0.3, 0.36), (0, 0.39, 0.3), (0, 0.45, 0.21), (0, 0.47, 0.11))]
    for i, at in enumerate(spine):
        tangent = spine[min(i + 1, len(spine) - 1)] - spine[max(i - 1, 0)]
        name, color = chips[i % 4]
        poker_chip("Chip%d" % i, at, tangent, 0.34 - 0.042 * i, 0.09, mat(name, color, 0.0, 0.3))
    group("Krebs", Matrix.Translation((0, -0.07, 0.15)))
    drop = -0.15
    ball("Leib", 1.0, (0, 0.03, 0.0), shell, (0.15, 0.16, 0.12))
    for sx in (-1, 1):
        limb("Stielauge", [(sx * 0.05, -0.09, 0.07), (sx * 0.07, -0.14, 0.2)], 0.014, 0.012, shell, sides=8)
        ball("Auge", 0.036, (sx * 0.072, -0.145, 0.225), eye, seg=14)
        limb("Fuehler", [(sx * 0.02, -0.12, 0.05), (sx * 0.1, -0.24, 0.2), (sx * 0.17, -0.3, 0.3)], 0.008, 0.005, eye, sides=6)
        size = 1.3 if sx < 0 else 1.0
        limb("Scherenarm", [(sx * 0.1, -0.05, -0.01), (sx * 0.22, -0.1, 0.01), (sx * 0.23, -0.2, -0.02)],
             0.032 * size, 0.044 * size, black)
        palm = Vector((sx * 0.23, -0.27, -0.03))
        ball("Schere", 1.0, palm, steel, (0.075 * size, 0.095 * size, 0.07 * size))
        limb("Finger", [palm + Vector((sx * 0.025, -0.04, 0.02)) * size, palm + Vector((sx * 0.04, -0.13, 0.02)) * size,
                        palm + Vector((sx * 0.0, -0.19, -0.01)) * size], 0.036 * size, 0.014 * size, steel, True)
        limb("Daumen", [palm + Vector((-sx * 0.025, -0.04, -0.01)) * size, palm + Vector((-sx * 0.04, -0.12, -0.02)) * size,
                        palm + Vector((sx * 0.0, -0.185, -0.02)) * size], 0.028 * size, 0.012 * size, steel, True)
        limb("Bein1", [(sx * 0.1, 0.0, -0.01), (sx * 0.25, -0.07, 0.08), (sx * 0.36, -0.12, drop)], 0.03, 0.022, steel, True)
        limb("Bein2", [(sx * 0.11, 0.05, -0.01), (sx * 0.3, 0.03, 0.08), (sx * 0.42, 0.04, drop)], 0.03, 0.022, steel, True)
    GROUP = None


CHARMS = {
    "horseshoe": horseshoe, "silver_dollar": silver_dollar, "heat_sink": heat_sink,
    "fox_tail": fox_tail, "rainbow_trout": rainbow_trout, "hermit_crab": hermit_crab,
}


# --- Ausgabe ----------------------------------------------------------------------------

def normalize():
    bpy.context.view_layer.update()
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for v in obj.data.vertices:
            w = obj.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    size = hi - lo
    scale = 1.0 / max(size)
    ROOT.scale = (scale,) * 3
    ROOT.location = (-(lo.x + hi.x) / 2 * scale, -(lo.y + hi.y) / 2 * scale, -lo.z * scale)
    bpy.context.view_layer.update()
    faces = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
    return faces, size


def place_import(path, x, turn):
    bpy.ops.import_scene.gltf(filepath=path)
    for obj in bpy.context.selected_objects:
        if obj.parent is None:
            obj.matrix_world = Matrix.Translation((x, 0, 0)) @ Matrix.Rotation(turn, 4, "Z") @ obj.matrix_world


def look(obj, at):
    obj.rotation_euler = (Vector(at) - obj.location).to_track_quat("-Z", "Y").to_euler()


def render(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    old = os.path.join(OLD, name + ".glb")
    if os.path.exists(old):
        place_import(old, -1.3, math.radians(-30))
    new = os.path.join(OUT, name + ".glb")
    place_import(new, 0.0, math.radians(-30))
    place_import(new, 1.3, math.radians(150))
    world = bpy.data.worlds.new("Welt")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.07, 0.08, 0.1, 1)
    scene.world = world
    cam = bpy.data.objects.new("Kamera", bpy.data.cameras.new("Kamera"))
    scene.collection.objects.link(cam)
    cam.data.lens = 70
    cam.location = (0, -8.4, 1.9)
    look(cam, (0, 0, 0.5))
    scene.camera = cam
    for loc, energy, kind in (((-3, -5, 6), 2.2, "SUN"), ((4, -4, 3), 220.0, "AREA"), ((0, 5, 4), 200.0, "AREA")):
        light = bpy.data.objects.new("Licht", bpy.data.lights.new("Licht", kind))
        light.data.energy = energy
        if kind == "AREA":
            light.data.size = 4
        scene.collection.objects.link(light)
        light.location = loc
        look(light, (0, 0, 0.5))
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.use_gtao = True
    scene.eevee.use_ssr = True
    scene.eevee.taa_render_samples = 32
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 1500, 620
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in (ARGS[1:] or list(CHARMS)):
        reset(name)
        CHARMS[name]()
        faces, size = normalize()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, name + ".blend"), check_existing=False)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                                  export_apply=True, export_yup=True)
        render(name)
        print("CHARM %s: %d Flächen, Rohmaß %.2f x %.2f x %.2f" % (name, faces, size.x, size.y, size.z))


if __name__ == "__main__":
    main()
