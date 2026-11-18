"""Fumble: exportiert die HÜLLEN der vier Datenträger (Welle 3, 2026-11-18) nach
assets/models/hardware/ - data_punch_card.glb, data_cassette.glb, data_clay_tablet.glb,
data_holo_emitter.glb. Vorbild ist tools/blender_data_media_set.py; dies ist die Fassung OHNE
Inhalt: kein Netz, keine Werte, keine Runen, kein Text. Das Netz backt Godot (StampNetOven).

Aufruf (kopflos):
  blender -b -P tools/blender_data_media_export.py -- <ausgabe-ordner> [render <bild-ordner>]

Achsen: X = Länge (Kopf -X, Fuß +X), Y = Breite, Z = Höhe, Ursprung = Mitte der Grundfläche.
Der Umriß ist der der liegenden Karte (1,62 x 1,08), das Netz-Feld liegt GENAU wie im Spiel
(DataCellView: Mitte 0,0486 zum Kopf, Zelle 0,2924, Teilung 0,3216, Querbalken in Reihe 2
vom Kopf). Jedes Objekt heißt nach seiner ROLLE (Koerper, Kern, Saum, Metall, Dunkel, Glanz,
Ton, Hell); je Rolle wird EIN Netz exportiert, Godot gibt die Materialien nach dem Namen.
"""
import bpy, bmesh, math, os, random, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_data_media as dm

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/hardware"
RENDER = ARGS[2] if len(ARGS) > 2 and ARGS[1] == "render" else ""

L, W = 1.62, 1.08
C = 1.08 * (1.0 - 2.0 * 0.0668) / 3.2   # Zelle wie DataCellView.net_size()
P = C * 1.1                              # Teilung samt Fuge
NX = -1.62 * (0.135 - 0.075) * 0.5       # Netz-Mitte, zum Kopf verschoben
ARM = [NX - (1.5 - k) * P for k in range(4)]
CELLS = [(x, 0.0) for x in ARM] + [(ARM[1], P), (ARM[1], -P)]
FREE = [(ARM[0], P), (ARM[0], -P), (ARM[2], P), (ARM[2], -P), (ARM[3], P), (ARM[3], -P)]
NET_HX, NET_HY = 2.15 * C, 1.6 * C
ROLES = ("Koerper", "Kern", "Saum", "Druck", "Metall", "Dunkel", "Glanz", "Ton", "Hell")
LIFT = 0.0015


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    led._mats.clear()
    led.base_materials()


def mats(key):
    """Vorschau-Materialien je Rolle; Godot ersetzt sie alle."""
    glow = dm.col(key)
    return {
        "Kern": led.mat("Kern_" + key, glow, 0.0, 0.3, 2.4),
        "Saum": led.mat("Saum_" + key, glow, 0.0, 0.3, 1.5),
        "Druck": led.mat("Druck_" + key, glow, 0.0, 0.6, 0.12),
        "Metall": led.mat("Metall", (0.62, 0.64, 0.68), 0.9, 0.25),
        "Dunkel": led.mat("Dunkel", (0.006, 0.006, 0.008), 0.0, 0.6),
        "Glanz": led.mat("Glanz", (0.02, 0.035, 0.05), 0.0, 0.05, clearcoat=1.0),
        "Ton": led.mat("Ton", (0.29, 0.22, 0.16), 0.0, 0.92),
        "Hell": led.mat("Hell", (0.78, 0.74, 0.68), 0.0, 0.8),
    }


def box(name, size, loc, material, corner=0.0, edge=0.0, segs=3):
    return led.rounded_box(None, name, size, loc, material, corner, edge, segs)


def slab(name, x0, y0, x1, y1, z0, z1, material):
    return box(name, (abs(x1 - x0), abs(y1 - y0), z1 - z0),
               ((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), material)


def line(name, z, a0, b0, a1, b1, w, material, lift=LIFT):
    """Ein flacher Streifen, Normale nach OBEN (Godot kappt Rückseiten)."""
    d = Vector((a1 - a0, b1 - b0))
    p = Vector((-d.y, d.x)).normalized() * w * 0.5
    zz = z + lift
    pts = [(a0 - p.x, b0 - p.y, zz), (a1 - p.x, b1 - p.y, zz), (a1 + p.x, b1 + p.y, zz),
           (a0 + p.x, b0 + p.y, zz)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(pts, [], [[0, 1, 2, 3]])
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def prism(name, tris, z0, z1, material):
    """Flache Dreiecks-Prismen in EINEM Netz (Keile, Kerben)."""
    verts, faces = [], []
    for tri in tris:
        k = len(verts)
        verts += [(x, y, z0) for x, y in tri] + [(x, y, z1) for x, y in tri]
        faces += [[k + 2, k + 1, k], [k + 3, k + 4, k + 5], [k, k + 1, k + 4, k + 3],
                  [k + 1, k + 2, k + 5, k + 4], [k + 2, k, k + 3, k + 5]]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def wedge(x, y, s, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    return [(x + a * ca - b * sa, y + a * sa + b * ca)
            for a, b in ((0.0, s * 0.5), (0.0, -s * 0.5), (s, 0.0))]


def in_net(x, y, pad):
    """Liegt der Punkt in einer Netz-Zelle (samt Rand)?"""
    half = C * 0.5 + pad
    return any(abs(x - cx) < half and abs(y - cy) < half for cx, cy in CELLS)


def in_field(x, y, pad=0.0):
    return abs(x - NX) < NET_HX + pad and abs(y) < NET_HY + pad


def corner_cutter(size):
    bpy.ops.mesh.primitive_cube_add(size=size, location=(-L * 0.5, W * 0.5, 0.0),
                                    rotation=(0, 0, math.radians(45)))
    o = bpy.context.active_object
    o.name = "SchnittEcke"
    return o


# --- ZAHLEN: die Lochkarte ------------------------------------------------------------------

PT, PLAYER, PCORE = 0.04, 0.017, 0.006
CORNER_CUT = 0.22


def punch_card():
    m = mats("zahl")
    black = led.mat("Neonkarton", (0.03, 0.03, 0.036), 0.0, 0.55, clearcoat=0.3)
    lower = box("KoerperUnterlage", (L, W, PLAYER), (0, 0, PLAYER * 0.5), black, 0.02)
    core = box("KernSchicht", (L - 0.004, W - 0.004, PCORE), (0, 0, PLAYER + PCORE * 0.5),
               m["Kern"], 0.02)
    top = box("KoerperKarte", (L, W, PT - PLAYER - PCORE),
              (0, 0, (PT + PLAYER + PCORE) * 0.5), black, 0.02)
    cutter = corner_cutter(CORNER_CUT)
    for o in (lower, core, top):
        led.cut(o, cutter)
    leg = CORNER_CUT / math.sqrt(2.0)
    # Die STANZUNGEN gehen nur durch die obere Lage: der Kern scheint hindurch.
    shapes = []
    y = -0.47
    while (W * 0.5 - y) > leg + 0.05:
        shapes.append(("rect", -0.797, y - 0.017, -0.769, y + 0.017))
        y += 0.06
    rnd = random.Random(7)
    for i in range(20):
        x = -0.72 + i * 1.49 / 19
        for d in range(10):
            yy = 0.44 - d * 0.88 / 9
            if in_net(x, yy, 0.03) or (in_field(x, yy) and not any(
                    abs(x - fx) < C * 0.5 and abs(yy - fy) < C * 0.5 for fx, fy in FREE)):
                continue
            if (x + L * 0.5) + (W * 0.5 - yy) < leg + 0.06 or yy > 0.46:
                continue
            if rnd.random() < 0.16:
                shapes.append(("rect", x - 0.011, yy - 0.022, x + 0.011, yy + 0.022))
            else:
                # Statt der Ziffern des Entwurfs ein stilles Raster: der Rhythmus, kein Text.
                line("Druck%d_%d" % (i, d), PT, x - 0.006, yy, x + 0.006, yy, 0.012, m["Druck"])
    led.cut(top, dm.hole_cutter(None, "SchnittStanzungen", shapes, PLAYER + PCORE * 0.5, 0.1))
    e = 0.014
    rim = [(-L * 0.5 + e, W * 0.5 - leg - e * 0.4), (-L * 0.5 + leg + e * 0.4, W * 0.5 - e),
           (L * 0.5 - e, W * 0.5 - e), (L * 0.5 - e, -W * 0.5 + e), (-L * 0.5 + e, -W * 0.5 + e),
           (-L * 0.5 + e, W * 0.5 - leg - e * 0.4)]
    for k in range(len(rim) - 1):
        a, b = rim[k], rim[k + 1]
        line("Saum%d" % k, PT, a[0], a[1], b[0], b[1], 0.006, m["Saum"])
    line("KernStreifen", PT, -L * 0.5 + leg + 0.02, 0.503, L * 0.5 - 0.03, 0.503, 0.026, m["Kern"])
    # Die Spalten-Teilung als feine Haarlinien im Fuß - der Rhythmus der Karte.
    for i in range(12):
        x = 0.06 + i * 0.045
        line("Dunkel%d" % i, PT, x, -0.52, x, -0.49, 0.004, m["Dunkel"])


# --- MATERIAL: die Kassette ------------------------------------------------------------------

CT = 0.126


def reel(name, x, y, r, z, m, fill):
    dm.cyl(None, "Dunkel" + name + "Mulde", r, 0.004, (x, y, z + 0.002), m["Dunkel"], 20)
    dm.cyl(None, "Dunkel" + name + "Wickel", r * fill, 0.003, (x, y, z + 0.0055),
           led.mat("Band", (0.05, 0.03, 0.022), 0.4, 0.3), 20)
    dm.cyl(None, "Hell" + name + "Nabe", r * 0.36, 0.008, (x, y, z + 0.008), m["Hell"], 12)
    dm.cyl(None, "Dunkel" + name + "Loch", r * 0.16, 0.009, (x, y, z + 0.0085), m["Dunkel"], 6)
    dm.annulus(None, "Saum" + name + "Ring", x, y, z + 0.0045, r, r * 1.12, m["Saum"], 20)


def cassette():
    m = mats("material")
    shell = led.mat("Kassettenrauch", (0.05, 0.012, 0.035), 0.0, 0.18, clearcoat=0.7)
    body = box("Koerper", (L - 0.008, W - 0.008, CT), (0, 0, CT * 0.5), shell, 0.06, 0.01, 3)
    seam = box("KernNaht", (L, W, 0.01), (0, 0, CT * 0.5), m["Kern"], 0.064)
    led.cut(seam, box("SchnittNaht", (L - 0.03, W - 0.03, 0.05), (0, 0, CT * 0.5), m["Dunkel"],
                      0.05))
    bpy.data.objects["SchnittNaht"].display_type = "WIRE"
    # Die GRIFFLEISTE am Kopf: Rippen, dazwischen Lichtschlitze in der Sortenfarbe.
    gx = -0.779
    box("DunkelGriffleiste", (0.058, 0.9, 0.012), (gx, 0, CT + 0.006), m["Dunkel"], 0.01)
    ys = [-0.42 + k * 0.06 for k in range(15)]
    for k, y in enumerate(ys):
        slab("DunkelRippe%d" % k, gx - 0.026, y - 0.007, gx + 0.026, y + 0.007, CT + 0.012,
             CT + 0.02, m["Dunkel"])
        if k < len(ys) - 1:
            slab("KernSchlitz%d" % k, gx - 0.023, y + 0.012, gx + 0.023, y + 0.048, CT + 0.012,
                 CT + 0.0135, m["Kern"])
    # Die SPULEN in den freien Fuß-Ecken des Netzes.
    rx = (ARM[2] + ARM[3]) * 0.5
    for s, f in ((1, 0.82), (-1, 0.58)):
        reel("Spule%d" % (s + 1), rx, s * P, 0.135, CT, m, f)
    # Der BANDKOPF am Fuß: Öffnung, Band, Andruckfilz, Rollen.
    box("DunkelKopf", (0.1, 0.72, 0.004), (0.735, 0, CT + 0.002), m["Dunkel"], 0.02)
    line("DunkelKopfband", CT + 0.004, 0.772, -0.34, 0.772, 0.34, 0.014,
         led.mat("Band", (0.05, 0.03, 0.022), 0.4, 0.3))
    slab("HellFilz", 0.745, -0.05, 0.765, 0.05, CT + 0.004, CT + 0.007, m["Hell"])
    for s in (-1, 1):
        dm.cyl(None, "MetallRolle%d" % (s + 1), 0.022, 0.006, (0.74, s * 0.3, CT + 0.006),
               m["Metall"], 12)
    # Die freien Kopf-Ecken: Typschild und Pegel.
    hx = ARM[0]
    box("GlanzTypschild", (0.22, 0.24, 0.003), (hx, P, CT + 0.0015), m["Glanz"], 0.02)
    for k in range(7):
        h = 0.04 + k * 0.026
        slab("KernPegel%d" % k, hx - 0.105 + k * 0.032, -P - 0.11, hx - 0.085 + k * 0.032,
             -P - 0.11 + h, CT, CT + 0.003, m["Kern"])
    for k, (x, y) in enumerate(((0.69, 0.47), (0.69, -0.47), (-0.69, 0.47), (-0.69, -0.47))):
        dm.cyl(None, "MetallSchraube%d" % k, 0.024, 0.008, (x, y, CT + 0.004), m["Metall"], 10)
        line("DunkelSchlitz%d" % k, CT + 0.0085, x - 0.016, y, x + 0.016, y, 0.005, m["Dunkel"])


# --- RUNEN: die Tontafel ---------------------------------------------------------------------

TT, LIP_H = 0.128, 0.146


def clay_tablet():
    m = mats("rune")
    clay = led.mat("Steinzeug", (0.2, 0.15, 0.11), 0.0, 0.95)
    box("Koerper", (L - 0.012, W - 0.012, TT), (0.003, 0, TT * 0.5), clay, 0.1, 0.03, 3)
    lx = -0.768
    box("TonLippe", (0.08, W - 0.05, LIP_H), (lx, 0, LIP_H * 0.5), m["Ton"], 0.035, 0.02, 3)
    # Die Keile der LIPPE tragen leuchtende Glasur, die im Feld sind dunkle Eindrücke.
    lip = []
    y = -0.43
    while y < 0.44:
        lip.append(wedge(-0.787, y, 0.032, 0.0))
        y += 0.054
    prism("KernLippenkeile", lip, LIP_H - 0.004, LIP_H + LIFT, m["Kern"])
    line("SaumLippe", TT, lx + 0.052, -0.45, lx + 0.052, 0.45, 0.008, m["Saum"])
    rnd = random.Random(11)
    marks = []
    spots = [(x, y, 0.12, 0.12) for x, y in FREE] + [(0.7, 0.0, 0.05, 0.44)]
    for x, y, hw, hh in spots:
        rows = max(1, int(hh * 2 / 0.08))
        cols = max(1, int(hw * 2 / 0.08))
        for r in range(rows):
            for j in range(cols):
                if rnd.random() < 0.3:
                    continue
                px = x - hw + 0.03 + j * (hw * 2 - 0.05) / max(1, cols - 0.5)
                py = y + hh - 0.03 - r * (hh * 2 - 0.05) / max(1, rows - 0.6)
                ang = rnd.choice((-math.pi * 0.5, -math.pi * 0.5, 0.0, math.pi * 0.75))
                marks.append(wedge(px, py, 0.036, ang))
    prism("DunkelKeile", marks, TT - 0.002, TT + LIFT, m["Dunkel"])


# --- SONDERBESTAND: der Holo-Emitter ---------------------------------------------------------

HT = 0.06


def cross_outline():
    """Der Umriß des Netz-Kreuzes, wie es im Spiel liegt (Querbalken in Reihe 2 vom Kopf)."""
    h = P * 0.5
    a0, a3 = ARM[0] - h, ARM[3] + h
    b0, b1 = ARM[1] - h, ARM[1] + h
    return [(a0, -h), (b0, -h), (b0, -3 * h), (b1, -3 * h), (b1, -h), (a3, -h), (a3, h),
            (b1, h), (b1, 3 * h), (b0, 3 * h), (b0, h), (a0, h)]


def holo_emitter():
    m = mats("gold")
    base = led.mat("Emitter", (0.025, 0.028, 0.035), 0.6, 0.25, clearcoat=0.8)
    box("Koerper", (L - 0.006, W - 0.006, HT), (0, 0, HT * 0.5), base, 0.08, 0.008, 3)
    ring = box("SaumRand", (L, W, 0.008), (0, 0, HT * 0.5), m["Saum"], 0.083)
    led.cut(ring, box("SchnittRand", (L - 0.02, W - 0.02, 0.05), (0, 0, HT * 0.5), m["Dunkel"],
                      0.075))
    bpy.data.objects["SchnittRand"].display_type = "WIRE"
    box("GlanzLinse", (1.36, 1.02, 0.003), (NX, 0, HT + 0.0015), m["Glanz"], 0.05)
    zl = HT + 0.003
    pts = cross_outline()
    for k in range(len(pts)):
        a, b = pts[k], pts[(k + 1) % len(pts)]
        line("KernUmriss%d" % k, zl, a[0], a[1], b[0], b[1], 0.010, m["Kern"])
    h = P * 0.5
    for k, (a0, b0, a1, b1) in enumerate((
            (ARM[0] + h, -h, ARM[0] + h, h), (ARM[1] + h, -h, ARM[1] + h, h),
            (ARM[2] + h, -h, ARM[2] + h, h), (ARM[1] - h, h, ARM[1] + h, h),
            (ARM[1] - h, -h, ARM[1] + h, -h))):
        line("SaumTeiler%d" % k, zl, a0, b0, a1, b1, 0.004, m["Saum"], LIFT * 0.6)
    dots = []
    for x, y in CELLS:
        for i in range(3):
            for j in range(3):
                dots.append((x + (i - 1) * C * 0.28, y + (j - 1) * C * 0.28, zl + 0.002))
    dm.dots(None, "KernPunkte", dots, 0.0055, m["Kern"])
    for k, (x, y) in enumerate([(sx, sy * 0.44) for sx in (-0.768, 0.735) for sy in (-1, 1)]):
        dm.cyl(None, "MetallKnotenfuss%d" % k, 0.04, 0.006, (x, y, HT + 0.003), m["Metall"], 14)
        dm.cyl(None, "KernKnoten%d" % k, 0.03, 0.01, (x, y, HT + 0.005), m["Kern"], 14)
    box("KernKopfbalken", (0.016, 0.8, 0.004), (-0.785, 0, HT + 0.002), m["Kern"])
    box("KernStirnbalken", (0.004, 0.8, 0.022), (-0.8075, 0, HT * 0.5), m["Kern"])


# --- Abschluß ------------------------------------------------------------------------------

def bake_down():
    """Schnitte anwenden, Schnittkörper fort, je ROLLE ein Netz."""
    for o in list(bpy.data.objects):
        if o.type != "MESH" or o.display_type == "WIRE":
            continue
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    for o in list(bpy.data.objects):
        if o.type == "MESH" and (o.display_type == "WIRE" or o.name.startswith("Schnitt")):
            bpy.data.objects.remove(o, do_unlink=True)
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    for role in ROLES:
        parts = [o for o in bpy.data.objects if o.name.startswith(role)]
        if not parts:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        if len(parts) > 1:
            bpy.ops.object.join()
        parts[0].name = role
        parts[0].data.name = role
    stray = [o.name for o in bpy.data.objects if o.name not in ROLES]
    assert not stray, "ohne Rolle: %s" % stray


def report(name):
    dg = bpy.context.evaluated_depsgraph_get()
    total = 0
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in bpy.data.objects:
        bm = bmesh.new()
        bm.from_object(o, dg)
        bm.transform(o.matrix_world)
        tris = len(bm.calc_loop_triangles())
        total += tris
        for v in bm.verts:
            lo = Vector(min(a, b) for a, b in zip(lo, v.co))
            hi = Vector(max(a, b) for a, b in zip(hi, v.co))
        bm.free()
        print("  %-8s %5d Dreiecke" % (o.name, tris))
    print("TRAEGER %-18s %5d Dreiecke  X %.4f..%.4f  Y %.4f..%.4f  Z %.4f..%.4f" %
          (name, total, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))


CARRIERS = [("data_punch_card", punch_card), ("data_cassette", cassette),
            ("data_clay_tablet", clay_tablet), ("data_holo_emitter", holo_emitter)]


def export_all():
    os.makedirs(OUT, exist_ok=True)
    for name, build in CARRIERS:
        reset()
        build()
        bake_down()
        report(name)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                                  export_apply=True)


def render_all():
    """Die exportierten Hüllen nebeneinander, zum Vergleich mit dem Entwurf."""
    os.makedirs(RENDER, exist_ok=True)
    for view, flat in (("huellen_draufsicht", True), ("huellen_schraeg", False)):
        cam, aim = dm.empty_stage()
        for i, (name, _build) in enumerate(CARRIERS):
            bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, name + ".glb"))
            for o in bpy.context.selected_objects:
                if o.parent is None:
                    o.location.x += -3.45 + i * 2.3
        aim.location = (0, 0, 0)
        if flat:
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = 9.4
            cam.location = (0, 0, 13)
        else:
            aim.location = (0, 0.1, 0.05)
            cam.location = (0.8, -7.2, 4.4)
            cam.data.lens = 40
        bpy.context.scene.eevee.taa_render_samples = 48
        bpy.context.scene.render.filepath = os.path.join(RENDER, view + ".png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    export_all()
    if RENDER:
        render_all()
    print("ok")
