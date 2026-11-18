"""Fumble: die vier DATENTRÄGER als SATZ (Entwurf 2026-11-18). Jeder Träger paßt in den Umriß
der liegenden Data-Card (1,62 × 1,08 × höchstens 0,1512), das Netz liegt quer (4 × 3 Zellen à
0,33) und sitzt auf jedem Träger an derselben Stelle - gestapelt decken sich die Zellen.
  lochkarte - ZAHLEN: schwarzer Karton mit Leuchtsohle, Stanzungen scheinen durch; Faktor violett
  kassette  - MATERIAL: Rauchschale mit Leuchtnaht, Spulen und Bandfenster am Kopf
  tontafel  - RUNEN: gebrannter Ton, glasierte Runen-Kacheln, Keilschrift in den freien Feldern
  holo      - SONDERBESTAND: flacher Emitter mit Eck-Knoten; AUS nur Sockel, AN schwebt das Netz
Kontakt-Ende +X (steckt im Turm), Kopf-Ende -X (ragt als Stummel heraus).

Aufruf (kopflos):
  blender -b -P tools/blender_data_media_set.py -- <ausgabe-ordner> [ansicht | check]
Achsen: X = Länge, Y = Breite, Z = Höhe, Ursprung = Mitte der Grundfläche, unten.
"""
import bpy, math, os, random, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm

led, box = dm.led, dm.box
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."

L, W, TMAX = 1.62, 1.08, 0.1512
C = 0.33
POS = dm.grid_pos(dm.CROSS, C, 0, 0, horizontal=True)
FREE = dm.grid_pos(dm.FREE, C, 0, 0, horizontal=True)
# Das liegende Kreuz in Zell-Einheiten: langer Arm längs X, Querbalken bei x 0..1.
OUTLINE = [(-2, -0.5), (0, -0.5), (0, -1.5), (1, -1.5), (1, -0.5), (2, -0.5), (2, 0.5), (1, 0.5),
           (1, 1.5), (0, 1.5), (0, 0.5), (-2, 0.5)]
DIVIDERS = [(-1, -0.5, -1, 0.5), (0, -0.5, 0, 0.5), (1, -0.5, 1, 0.5), (0, 0.5, 1, 0.5),
            (0, -0.5, 1, -0.5)]

glow, col, top, seg = dm.glow, dm.col, dm.top, dm.seg


def in_net(x, y, pad=0.52):
    return any(abs(x - px) < C * pad and abs(y - py) < C * pad for px, py in POS)


def number_vals(rnd, key):
    if key == "faktor":
        vals = [""] * 6
        for i in rnd.sample(range(6), rnd.randint(1, 3)):
            vals[i] = rnd.choice(("×2", "×2", "×3"))
        return vals
    vals = [rnd.choice(("+1", "+2", "+3", "+4")) for _ in range(6)]
    for i in rnd.sample(range(6), rnd.randint(0, 2)):
        vals[i] = ""
    return vals


# --- ZAHLEN: die Lochkarte ------------------------------------------------------------------

PT, PLAYER, PCORE = 0.04, 0.017, 0.006
CORNER_CUT = 0.22


def punch_card(parent, seed=1, key="zahl"):
    rnd = random.Random(seed)
    vals = number_vals(rnd, key)
    black = led.mat("Neonkarton", (0.03, 0.03, 0.036), 0.0, 0.55, clearcoat=0.3)
    # Der LEUCHTKERN liegt mitten in der Kante: Saum von der Seite, Licht durch die Stanzungen.
    lower = led.rounded_box(parent, "Unterlage", (L, W, PLAYER), (0, 0, PLAYER * 0.5), black,
                            0.02, 0.002)
    core = led.rounded_box(parent, "Leuchtkern", (L - 0.002, W - 0.002, PCORE),
                           (0, 0, PLAYER + PCORE * 0.5), glow(key, 4.0), 0.02, 0.0)
    body = led.rounded_box(parent, "Karte", (L, W, PT - PLAYER - PCORE),
                           (0, 0, (PT + PLAYER + PCORE) * 0.5), black, 0.02, 0.002)
    bpy.ops.mesh.primitive_cube_add(size=CORNER_CUT, location=(-L * 0.5, W * 0.5, 0),
                                    rotation=(0, 0, math.radians(45)))
    corner = bpy.context.active_object
    corner.parent = parent
    for o in (lower, core, body):
        led.cut(o, corner)
    leg = CORNER_CUT / math.sqrt(2)
    ink, faint = glow(key, 2.0), led.mat("Neonziffer_" + key, col(key), 0.0, 0.6, 0.12)
    fr = top(PT)
    e = 0.014
    rim = [(-L * 0.5 + e, W * 0.5 - leg - e * 0.4), (-L * 0.5 + leg + e * 0.4, W * 0.5 - e),
           (L * 0.5 - e, W * 0.5 - e), (L * 0.5 - e, -W * 0.5 + e), (-L * 0.5 + e, -W * 0.5 + e)]
    for k in range(len(rim) - 1):
        a, b = rim[k], rim[k + 1]
        seg(parent, "Saum%d" % k, fr, a[0], a[1], b[0], b[1], 0.006, glow(key, 1.4))
    x0s = -L * 0.5 + leg + 0.02
    box.rect(parent, "Streifen", fr, x0s, 0.488, L * 0.5 - 0.03, 0.518, glow(key, 1.1))
    # Die KOPFREIHE: Stanzungen dicht an der Kopfkante, das Kennzeichen des Stummels.
    shapes = []
    y = -0.47
    while (W * 0.5 - y) > leg + 0.05:
        shapes.append(("rect", -0.797, y - 0.017, -0.769, y + 0.017))
        y += 0.06
    cols = 20
    for i in range(cols):
        x = -0.72 + i * 1.49 / (cols - 1)
        for d in range(10):
            y = 0.44 - d * 0.88 / 9
            if in_net(x, y) or (x + L * 0.5) + (W * 0.5 - y) < leg + 0.06:
                continue
            if rnd.random() < 0.11:
                shapes.append(("rect", x - 0.011, y - 0.022, x + 0.011, y + 0.022))
            else:
                box.text(parent, str(d), fr, x, y, 0.04, faint, "Ziffer%d_%d" % (i, d))
        box.text(parent, str(i + 1), fr, x, -0.505, 0.022, faint, "Spalte%d" % i)
    for i, (x, y) in enumerate(POS):
        dm.box_outline(parent, "Zellrand%d_" % i, top(PT + 0.0006), x, y, C * 0.46, 0.008, ink)
        if vals[i]:
            box.text(parent, vals[i], top(PT + 0.0006), x, y + C * 0.08, C * 0.42, ink,
                     "Wert%d" % i)
            dm.value_holes(shapes, x, y, C, vals[i])
    led.cut(body, dm.hole_cutter(parent, "Stanzungen", shapes))


# --- MATERIAL: die Kassette -------------------------------------------------------------------

CT = 0.126
TAPE_TYPES = {"stahl": ("TYPE I", "FERRO"), "glas": ("TYPE II", "CHROM"),
              "kupfer": ("TYPE III", "FECR"), "gold": ("TYPE IV", "METAL"),
              "obsidian": ("TYPE IV", "METAL")}


def cassette(parent, seed=1, key="material"):
    rnd = random.Random(seed)
    names = list(dm.MATERIALS)
    cells = [("mat", rnd.choice(names)) for _ in range(6)]
    if rnd.random() < 0.6:
        cells[rnd.randrange(6)] = ("empty", None)
    shell = led.mat("Kassettenrauch", (0.03, 0.008, 0.024), 0.0, 0.18, clearcoat=0.7)
    body = led.rounded_box(parent, "Gehaeuse", (L - 0.008, W - 0.008, CT), (0, 0, CT * 0.5),
                           shell, 0.06, 0.012)
    led.frame_ring(parent, "Naht", (L, W), (L - 0.03, W - 0.03), CT * 0.5, 0.01, glow(key, 1.8),
                   0.06, y=0)
    dm.printed_net(parent, CT, key, cells, POS, C)
    # Die GRIFFLEISTE an der Kopfkante: Rippen oben, Rillen in der Stirn über und unter der Naht.
    grip = led.mat("Griffleiste", (0.02, 0.006, 0.016), 0.0, 0.55)
    led.rounded_box(parent, "Griffleiste", (0.058, 0.9, 0.012), (-0.779, 0, CT + 0.006), grip,
                    0.01, 0.003)
    ys = [-0.42 + k * 0.035 for k in range(25)]
    for k, y in enumerate(ys):
        led.rounded_box(parent, "Rippe%d" % k, (0.052, 0.012, 0.008), (-0.779, y, CT + 0.016),
                        grip, 0.0, 0.002)
        # Zwischen den Rippen leuchten lange Schlitze in Sortenfarbe - Rippen, keine Löcher.
        if k < len(ys) - 1:
            led.rounded_box(parent, "Lichtschlitz%d" % k, (0.046, 0.009, 0.002),
                            (-0.779, y + 0.0175, CT + 0.0128), glow(key, 2.8), 0.0, 0.0)
    for name, z0, z1 in (("RillenUnten", 0.016, 0.052), ("RillenOben", 0.074, 0.11)):
        led.cut(body, dm.hole_cutter(parent, name, [("rect", -0.83, y - 0.0055, -0.797,
                                                     y + 0.0055) for y in ys], z0, z1))
    # Die SPULEN so nah am Kopf, wie das Netz es zuläßt.
    rx, ry, rr = -0.598, 0.35, 0.13
    fill = rnd.uniform(0.55, 0.95)
    for s, f in ((1, fill), (-1, 1.5 - fill)):
        dm.tape_reel(parent, "Spule%d" % s, rx, s * ry, rr, CT, key, f)
    tape = led.mat("Band", (0.05, 0.03, 0.022), 0.5, 0.25, clearcoat=0.6)
    chrome = led.mat("Chrom2", (0.9, 0.9, 0.92), 1.0, 0.05)
    # Der BANDKOPF am Kontakt-Ende: Öffnung, Band, Andruckfilz, Capstan-Löcher.
    head = led.mat("Kopfoeffnung", (0.004, 0.003, 0.004), 0.0, 0.6)
    led.rounded_box(parent, "Kopfoeffnung", (0.1, 0.72, 0.004), (0.738, 0, CT + 0.002), head,
                    0.02, 0.0)
    seg(parent, "Kopfband", top(CT + 0.004), 0.776, -0.34, 0.776, 0.34, 0.014, tape)
    box.rect(parent, "Andruckfilz", top(CT + 0.0045), 0.745, -0.05, 0.768, 0.05,
             led.mat("Filzpolster", (0.5, 0.45, 0.4), 0.0, 0.9))
    for s in (-1, 1):
        dm.cyl(parent, "Rolle%d" % s, 0.022, 0.006, (0.74, s * 0.3, CT + 0.006), chrome, 20)
        box.dot(parent, "Capstan%d" % s, top(CT + 0.004), 0.735, s * 0.18, 0.016, led.DARK)
    # Die freien Felder: Seite, Sorte, BANDSORTE (wie bei echten Kassetten nach Bandmaterial).
    main = max(set(n for k, n in cells if n), key=lambda n: [c[1] for c in cells].count(n))
    tname, tmat = TAPE_TYPES[main]
    tx, ty = FREE[0]
    box.text(parent, "MATERIAL", top(CT), tx, ty + 0.045, 0.045, glow(key, 1.3), "Sorte")
    box.text(parent, "C-%d" % rnd.choice((46, 60, 90)), top(CT), tx, ty - 0.035, 0.035,
             glow(key, 0.8), "Laenge")
    bx, by = FREE[1]
    box.rect(parent, "Typschild", top(CT + 0.0003), bx - 0.14, by - 0.1, bx + 0.14, by + 0.1,
             led.mat("Typschild_" + key, tuple(v * 0.12 for v in col(key)), 0.0, 0.5, 0.2))
    box.text(parent, tname, top(CT + 0.0006), bx, by + 0.035, 0.05, glow(key, 1.6), "Typ")
    box.text(parent, "· %s ·" % tmat, top(CT + 0.0006), bx, by - 0.045, 0.036, glow(key, 1.0),
             "Bandsorte")
    sx, sy = FREE[2]
    box.text(parent, rnd.choice(("A", "B")), top(CT), sx, sy, 0.13, glow(key, 1.0), "Seite")
    mx, my = FREE[3]
    for k in range(8):
        h = 0.03 + k * 0.012
        box.rect(parent, "Pegel%d" % k, top(CT + 0.0004), mx - 0.12 + k * 0.032, my - 0.08,
                 mx - 0.1 + k * 0.032, my - 0.08 + h, glow(key, 0.6 + 0.15 * k))
    dm.screws(parent, [(mx - 0.1, my + 0.09), (mx + 0.1, my + 0.09)], CT)
    for x, y in ((0.69, 0.47), (0.69, -0.47)):
        dm.screws(parent, [(x, y)], CT)


# --- RUNEN: die Tontafel ----------------------------------------------------------------------

TT = 0.128


def wedge_prism(verts, faces, x, y, s, ang, z_top, depth):
    """Ein Keil-Eindruck als Prisma: am Kopf tief, zur Spitze flach auslaufend."""
    ca, sa = math.cos(ang), math.sin(ang)
    tri = [(0, s * 0.5), (0, -s * 0.5), (s, 0)]
    k = len(verts)
    for (a, b), d in zip(tri, (depth, depth, depth * 0.25)):
        verts.append((x + a * ca - b * sa, y + a * sa + b * ca, z_top - d))
    for a, b in tri:
        verts.append((x + a * ca - b * sa, y + a * sa + b * ca, z_top + 0.02))
    faces += [[k + 3, k + 4, k + 5], [k + 2, k + 1, k], [k, k + 1, k + 4, k + 3],
              [k + 1, k + 2, k + 5, k + 4], [k + 2, k, k + 3, k + 5]]


def clay_mat(gain=1.0):
    """Steinzeug: matt, isotrope Brand-Flecken und Schamotte-Körner, keine Maserung."""
    name = "Steinzeug_%.2f" % gain
    if name in led._mats:
        return led._mats[name]
    m = led.mat(name, (0.2, 0.15, 0.11), 0.0, 0.95)
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Specular"].default_value = 0.25
    tc = nt.nodes.new("ShaderNodeTexCoord")
    # Objekt-Koordinaten: gleich groß in jeder Achse, sonst streckt die flache Tafel das Rauschen.
    pores = nt.nodes.new("ShaderNodeTexNoise")
    pores.inputs["Scale"].default_value = 160.0
    pores.inputs["Detail"].default_value = 2.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.18
    nt.links.new(tc.outputs["Object"], pores.inputs["Vector"])
    nt.links.new(pores.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], p.inputs["Normal"])
    blot = nt.nodes.new("ShaderNodeTexNoise")
    blot.inputs["Scale"].default_value = 5.0
    blot.inputs["Detail"].default_value = 2.0
    nt.links.new(tc.outputs["Object"], blot.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.38
    ramp.color_ramp.elements[0].color = (0.13 * gain, 0.095 * gain, 0.07 * gain, 1)
    ramp.color_ramp.elements[1].position = 0.66
    ramp.color_ramp.elements[1].color = (0.24 * gain, 0.18 * gain, 0.13 * gain, 1)
    nt.links.new(blot.outputs["Fac"], ramp.inputs[0])
    grog = nt.nodes.new("ShaderNodeTexVoronoi")
    grog.inputs["Scale"].default_value = 70.0
    grog.inputs["Randomness"].default_value = 1.0
    nt.links.new(tc.outputs["Object"], grog.inputs["Vector"])
    grains = nt.nodes.new("ShaderNodeValToRGB")
    grains.color_ramp.elements[0].position = 0.0
    grains.color_ramp.elements[0].color = (1, 1, 1, 1)
    grains.color_ramp.elements[1].position = 0.09
    grains.color_ramp.elements[1].color = (0, 0, 0, 1)
    nt.links.new(grog.outputs["Distance"], grains.inputs[0])
    tint = nt.nodes.new("ShaderNodeMixRGB")
    tint.inputs["Color2"].default_value = (0.42, 0.37, 0.31, 1)
    nt.links.new(grains.outputs[0], tint.inputs["Fac"])
    nt.links.new(ramp.outputs[0], tint.inputs["Color1"])
    nt.links.new(tint.outputs[0], p.inputs["Base Color"])
    return m


def kneaded(obj, strength):
    """Von Hand gedrückt: eine leichte Unruhe in Kante und Fläche."""
    tex = bpy.data.textures.get("Tonknete") or bpy.data.textures.new("Tonknete", "CLOUDS")
    tex.noise_scale = 0.12
    mod = obj.modifiers.new("Knete", "DISPLACE")
    mod.texture = tex
    mod.texture_coords = "GLOBAL"
    mod.strength = strength
    mod.mid_level = 0.5


def clay_tablet(parent, seed=1, key="rune"):
    rnd = random.Random(seed)
    glyphs = [rnd.randrange(len(dm.RUNES)) for _ in range(6)]
    if rnd.random() < 0.4:
        glyphs[rnd.randrange(6)] = None
    clay = clay_mat()
    body = led.rounded_box(parent, "Tafel", (L - 0.012, W - 0.012, TT), (0.003, 0, TT * 0.5 + 0.002),
                           clay, 0.1, 0.045)
    kneaded(body, 0.008)
    # Die LIPPE am Kopf: erhabener, runder Tonwulst, dicker als die Tafel.
    lip_h = 0.146
    lip = led.rounded_box(parent, "Lippe", (0.08, W - 0.05, lip_h),
                          (-0.768, 0, lip_h * 0.5 + 0.002), clay_mat(1.45), 0.035, 0.024)
    kneaded(lip, 0.005)
    glaze = led.mat("Glasur_matt", (0.012, 0.013, 0.02), 0.0, 0.3, clearcoat=0.25)
    for i, (x, y) in enumerate(POS):
        led.rounded_box(parent, "Kachel%d" % i, (C * 0.86, C * 0.86, 0.016), (x, y, TT + 0.002),
                        glaze if glyphs[i] is not None else
                        led.mat("Kachel_leer", (0.01, 0.011, 0.016), 0.0, 0.85), C * 0.1, 0.004, 4)
        if glyphs[i] is not None:
            dm.rune_glyph(parent, "Rune%d" % i, top(TT + 0.0105), x, y, C * 0.3, glyphs[i],
                          C * 0.06, glow(key, 2.6))
    # KEILSCHRIFT als echte Eindrücke: senkrechte und waagerechte Keile, dazu Winkelhaken.
    verts, faces = [], []
    spots = [(x, y, 0.14, 0.14) for x, y in FREE] + [(0.712, 0.0, 0.035, 0.44)]
    for x, y, hw, hh in spots:
        rows = max(1, int(hh * 2 / 0.095))
        cols = max(1, int(hw * 2 / 0.09))
        for r in range(rows):
            for j in range(cols):
                if rnd.random() < 0.25:
                    continue
                px = x - hw + 0.03 + j * (hw * 2 - 0.04) / max(1, cols - 0.5)
                py = y + hh - 0.04 - r * (hh * 2 - 0.05) / max(1, rows - 0.6)
                ang = rnd.choice((-math.pi * 0.5, -math.pi * 0.5, 0.0, math.pi * 0.75))
                wedge_prism(verts, faces, px, py, 0.04, ang, TT, 0.012)
    lip_verts, lip_faces = [], []
    y = -0.43
    while y < 0.44:
        wedge_prism(lip_verts, lip_faces, -0.787, y, 0.032, 0.0, lip_h, 0.011)
        y += 0.054
    mark = led.mat("Keil", (0.03, 0.02, 0.015), 0.0, 0.95)
    # Die Keile der Lippe tragen leuchtende Glasur, die im Feld bleiben roh.
    for target, name, vs, fs, m in ((body, "Keile", verts, faces, mark),
                                    (lip, "Lippenkeile", lip_verts, lip_faces, glow(key, 1.9))):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(vs, [], fs)
        cutter = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(cutter)
        cutter.data.materials.append(m)
        cutter.parent = parent
        box.cut(target, cutter, transfer=True)


# --- SONDERBESTAND: der Holo-Emitter -----------------------------------------------------------

HT = 0.06
HOLO_MODES = {"repair": ("gold", "GENERAL-", "ÜBERHOLUNG"), "cool": ("kuehl", "KÜHL-", "RIPPE"),
              "bath": ("kuehl", "KÄLTE-", "BAD"), "blank": ("rohling", "ROH-", "LING")}


def wrench(parent, name, fr, z, x, y, s, material):
    seg(parent, name, fr, x - 0.7 * s, y - 0.7 * s, x + 0.3 * s, y + 0.3 * s, 0.26 * s, material)
    dm.annulus(parent, name + "Maul", x + 0.5 * s, y + 0.5 * s, z + 0.0012, 0.17 * s, 0.38 * s,
               material, 32)


def snowflake(parent, name, fr, x, y, s, material):
    for k in range(3):
        t = k * math.pi / 3 + math.pi / 6
        dx, dy = math.cos(t) * s, math.sin(t) * s
        seg(parent, "%s%d" % (name, k), fr, x - dx, y - dy, x + dx, y + dy, 0.16 * s, material)
        for sg in (-1, 1):
            ex, ey = x + sg * dx * 0.65, y + sg * dy * 0.65
            for side in (-1, 1):
                tt = t + side * 0.65
                seg(parent, "%s%d%d%d" % (name, k, sg, side), fr, ex, ey,
                    ex + sg * math.cos(tt) * 0.32 * s, ey + sg * math.sin(tt) * 0.32 * s,
                    0.11 * s, material)


def status_glyph(parent, z, x, y, s, mode, material):
    fr = top(z)
    if mode == "repair":
        wrench(parent, "Status", fr, z, x, y, s, material)
    elif mode == "blank":
        box.text(parent, "?", fr, x, y, s * 1.6, material, "Status")
    else:
        snowflake(parent, "Status", fr, x, y, s, material)


def cross_lines(parent, name, z, key, gain, dashed=False, dividers=True):
    fr = top(z)
    line = glow(key, 2.2 * gain)
    pts = [(x * C, y * C) for x, y in OUTLINE]
    for k in range(len(pts)):
        a, b = pts[k], pts[(k + 1) % len(pts)]
        if not dashed:
            seg(parent, "%sUmriss%d" % (name, k), fr, a[0], a[1], b[0], b[1], 0.012, line)
            continue
        n = max(1, int(Vector((b[0] - a[0], b[1] - a[1])).length / 0.06))
        for j in range(n):
            f0, f1 = j / n, (j + 0.55) / n
            seg(parent, "%sStrich%d_%d" % (name, k, j), fr, a[0] + (b[0] - a[0]) * f0,
                a[1] + (b[1] - a[1]) * f0, a[0] + (b[0] - a[0]) * f1,
                a[1] + (b[1] - a[1]) * f1, 0.011, line)
    if dividers:
        for k, (a0, b0, a1, b1) in enumerate(DIVIDERS):
            seg(parent, "%sTeiler%d" % (name, k), top(z - 0.0004), a0 * C, b0 * C, a1 * C,
                b1 * C, 0.004, glow(key, 0.8 * gain))


def effect_content(parent, z, key, mode, gain=1.0):
    """Die WIRKUNG im liegenden Kreuz; alle Schrift liest aufrecht bei +X nach rechts."""
    fr = top(z)
    big = glow(key, 3.0 * gain)
    cx, cy = POS[2]
    if mode == "blank":
        for i in (0, 1, 2, 3, 4):
            box.text(parent, "?", fr, *POS[i], C * 0.42, glow(key, 0.9 * gain), "Frage%d" % i)
        box.text(parent, "ROHLING", fr, *POS[5], C * 0.17, big, "Rohling")
        return
    if mode == "repair":
        wrench(parent, "Schluessel", fr, z, cx, cy, C * 0.3, big)
        box.text(parent, "0", fr, *POS[0], C * 0.5, big, "Null")
        box.text(parent, "HEIL", fr, *POS[4], C * 0.26, big, "Heil")
        box.text(parent, "LADUNG", fr, *POS[5], C * 0.17, glow(key, 1.4 * gain), "Ladung")
    else:
        snowflake(parent, "Flocke", fr, cx, cy, C * 0.33, big)
        box.text(parent, "-1" if mode == "cool" else "0", fr, *POS[0], C * 0.5, big, "Wert")
        box.text(parent, "LADUNG", fr, *POS[4], C * 0.18, big, "Ladung")
        box.text(parent, "KÜHL", fr, *POS[5], C * 0.2, glow(key, 1.4 * gain), "Kuehl")


def mark_projection(before):
    for o in set(bpy.data.objects) - before:
        o["proj"] = 1


def holo(parent, seed=1, mode="repair", on=False, float_h=0.2, clip=None):
    """clip = (x, z): über x und z liegt ein fremder Stummel, dort bleibt die Projektion aus."""
    rnd = random.Random(seed)
    key, w0, w1 = HOLO_MODES[mode]
    base = led.mat("Emitter", (0.02, 0.022, 0.028), 0.8, 0.25, clearcoat=0.8)
    led.rounded_box(parent, "Sockel", (L - 0.006, W - 0.006, HT), (0, 0, HT * 0.5), base, 0.08,
                    0.01)
    led.frame_ring(parent, "Rand", (L, W), (L - 0.02, W - 0.02), HT * 0.5, 0.008, glow(key, 2.0),
                   0.08, y=0)
    lens = led.mat("Linse", (0.03, 0.05, 0.07), 0.0, 0.05, clearcoat=1.0)
    led.rounded_box(parent, "Linsenfeld", (1.36, 1.02, 0.003), (0, 0, HT + 0.0015), lens, 0.05,
                    0.0)
    zl = HT + 0.003
    pts = []
    for x, y in POS:
        for i in range(6):
            for j in range(6):
                pts.append((x + (i - 2.5) * C * 0.15, y + (j - 2.5) * C * 0.15, zl + 0.002))
    dm.dots(parent, "Emitterpunkte", pts, 0.0045, glow(key, 1.2 if on else 0.45))
    cross_lines(parent, "Linse", zl, key, 0.5 if on else 0.3, mode == "blank")
    # Die ECK-KNOTEN: vier Emitter in den Ecken, am Kopf zwischen ihnen das Status-Zeichen.
    nodes = [(-0.768 if sx < 0 else 0.735, sy * 0.44) for sx in (-1, 1) for sy in (-1, 1)]
    metal = led.mat("Knotenring", (0.6, 0.62, 0.66), 1.0, 0.2)
    for k, (x, y) in enumerate(nodes):
        dm.cyl(parent, "Knotenfuss%d" % k, 0.04, 0.006, (x, y, HT + 0.003), metal, 24)
        dm.cyl(parent, "Knoten%d" % k, 0.03, 0.01, (x, y, HT + 0.005), glow(key, 4.0 if on else 2.6),
               24)
    # Der LICHTBALKEN zwischen den Kopf-Knoten, oben und auf der Stirn.
    bar = glow(key, 3.2 if on else 2.4)
    led.rounded_box(parent, "Kopfbalken", (0.016, 0.8, 0.004), (-0.785, 0, HT + 0.002), bar, 0.0,
                    0.0)
    led.rounded_box(parent, "Stirnbalken", (0.004, 0.8, 0.022), (-0.8075, 0, HT * 0.5), bar, 0.0,
                    0.0)
    status_glyph(parent, HT, -0.708, 0.0, 0.05, mode, glow(key, 2.4))
    tx, ty = FREE[0]
    box.text(parent, w0, top(zl), tx, ty + 0.03, 0.042, glow(key, 1.2), "Name0")
    box.text(parent, w1, top(zl), tx, ty - 0.03, 0.042, glow(key, 1.2), "Name1")
    bx, by = FREE[1]
    box.text(parent, "SB-%02d" % rnd.randint(1, 99), top(zl), bx, by, 0.04, glow(key, 0.7),
             "Serie")
    if not on:
        return
    before = set(bpy.data.objects)
    zh = HT + float_h
    cross_lines(parent, "Netz", zh, key, 1.0, mode == "blank")
    effect_content(parent, zh, key, mode)
    for k in range(14):
        y = -1.5 * C + k * 3 * C / 13
        hw = 2 * C if abs(y) < 0.5 * C else (0.5 * C)
        x0 = -hw if abs(y) < 0.5 * C else 0
        x1 = hw if abs(y) < 0.5 * C else C
        seg(parent, "Zeile%d" % k, top(zh - 0.002), x0, y, x1, y, 0.003, glow(key, 0.5))
    vol = led.mat("Lichtsaeule_" + key, col(key), 0.0, 0.5, 0.15, 0.025)
    z0 = zl + 0.002
    cols = []
    for name, sx, sy, x, y in (("Arm", 4 * C, C, 0, 0), ("Oben", C, C, 0.5 * C, C),
                               ("Unten", C, C, 0.5 * C, -C)):
        x0, x1 = x - sx * 0.5, x + sx * 0.5
        if clip and x1 > clip[0]:
            cols.append((name + "Fuss", x0, x1, y, sy, z0, clip[1]))
            if x0 < clip[0]:
                cols.append((name + "Kopf", x0, clip[0], y, sy, clip[1], zh - 0.002))
        else:
            cols.append((name, x0, x1, y, sy, z0, zh - 0.002))
    for name, x0, x1, y, sy, za, zb in cols:
        led.rounded_box(parent, "Saeule" + name, (x1 - x0, sy, zb - za),
                        ((x0 + x1) * 0.5, y, (za + zb) * 0.5), vol, 0.0, 0.0)
    ray = led.mat("Strahl_" + key, col(key), 0.0, 0.4, 2.0, 0.5)
    for k, (x, y) in enumerate(nodes):
        p0 = Vector((x, y, HT + 0.012))
        p1 = Vector((math.copysign(2 * C, x), math.copysign(0.5 * C, y), zh))
        if clip and max(p0.x, p1.x) > clip[0] and p1.z > clip[1]:
            p1 = p0 + (p1 - p0) * ((clip[1] - p0.z) / (p1.z - p0.z))
        dm.beam(parent, "Strahl%d" % k, p0, p1, 0.005, ray)
    mark_projection(before)


# --- Prüfung und Bühne --------------------------------------------------------------------------

def bounds(root, skip_proj=True):
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in root.children_recursive:
        if o.hide_render or o.type not in ("MESH", "FONT") or (skip_proj and o.get("proj")):
            continue
        ev = o.evaluated_get(dg)
        for c in ev.bound_box:
            p = ev.matrix_world @ Vector(c) - root.matrix_world.translation
            lo = Vector(min(a, b) for a, b in zip(lo, p))
            hi = Vector(max(a, b) for a, b in zip(hi, p))
    return lo, hi


def make(kind, seed=1, **kw):
    if kind == "zahl":
        return lambda p: punch_card(p, seed, "zahl")
    if kind == "faktor":
        return lambda p: punch_card(p, seed, "faktor")
    if kind == "material":
        return lambda p: cassette(p, seed)
    if kind == "rune":
        return lambda p: clay_tablet(p, seed)
    return lambda p: holo(p, seed, kind, **kw)


def label(text, x, y, size=0.11):
    bpy.ops.object.empty_add()
    o = bpy.context.active_object
    box.text(o, text, top(0.0005), x, y, size, led.mat("Beschriftung", (0.75, 0.76, 0.82), 0.0,
                                                       0.6, 0.4), "Etikett_" + text)


ROW = [("ZAHLEN", "zahl", {}), ("MATERIAL", "material", {}), ("RUNEN", "rune", {}),
       ("SONDER · AUS", "repair", {}), ("FAKTOR", "faktor", {}), ("REPARATUR · AN", "repair",
                                                                    {"on": True}),
       ("KÜHLUNG · AN", "cool", {"on": True}), ("ROHLING · AN", "blank", {"on": True})]


def view_row(flat):
    cam, aim = dm.empty_stage()
    for i, (name, kind, kw) in enumerate(ROW):
        x, y = -3.45 + (i % 4) * 2.3, 0.9 if i < 4 else -1.3
        dm.build(make(kind, 11 + i, **kw), name, (x, y, 0.001))
        label(name, x, y - 0.72)
    aim.location = (0, -0.25, 0)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 8.9
        cam.location = (0, -0.25, 13)
    else:
        aim.location = (0, -0.2, 0.1)
        cam.location = (1.0, -9.6, 6.6)
        cam.data.lens = 38


PITCH, PLATE, WALL = 0.17, 0.016, 0.02
FELT_T, TOP_GAP = 0.03, 0.05
PIT_L, PIT_W = 1.1 * L, W + 0.12
TOWER = [("zahl", {}), ("material", {}), ("rune", {}), ("faktor", {}), ("cool", {}),
         ("material", {})]


def floor_z(k):
    """Unterkante der Karte in Etage k (0 = unten); die oberste endet TOP_GAP unter dem Filz."""
    return -TOP_GAP - TMAX - (5 - k) * PITCH


def stub_len(k, peek):
    return (0.2 + peek * (5 - k)) * L


def table_with_pit():
    """Der Tisch: Filzplatte mit der AUSWURF-BAHN als Grube; der Turm steckt +X unter dem Filz."""
    for o in list(bpy.data.objects):
        mats = getattr(o.data, "materials", None) if o.data is not None else None
        if mats and mats[0] is not None and mats[0].name == "Filz":
            bpy.data.objects.remove(o)
    felt = led.mat("Filz", (0.018, 0.011, 0.03), 0.0, 0.9)
    lining = led.mat("Grubenfutter", (0.03, 0.027, 0.04), 0.0, 0.7)
    seam = led.mat("Grubensaum", (0.6, 0.62, 0.75), 0.0, 0.5, 0.25)
    bpy.ops.object.empty_add()
    root = bpy.context.active_object
    root.name = "Tisch"
    slab = led.rounded_box(root, "Filzplatte", (40, 40, FELT_T), (0, 0, -FELT_T * 0.5), felt, 0.0,
                           0.0)
    hole = led.rounded_box(root, "Grubenloch", (PIT_L, PIT_W, 1.0), (-PIT_L * 0.5, 0, 0), felt,
                           0.0, 0.0)
    led.cut(slab, hole)
    depth = -floor_z(0) + PLATE + 0.1
    zc = -depth * 0.5
    hw = PIT_W * 0.5
    led.rounded_box(root, "Grubenboden", (PIT_L + 2 * WALL, PIT_W + 2 * WALL, WALL),
                    (-PIT_L * 0.5, 0, -depth - WALL * 0.5), lining, 0.0, 0.0)
    led.rounded_box(root, "Grubenkopf", (WALL, PIT_W, depth), (-PIT_L - WALL * 0.5, 0, zc), lining,
                    0.0, 0.0)
    for s in (-1, 1):
        led.rounded_box(root, "Grubenwand%d" % s, (PIT_L + 2 * WALL, WALL, depth),
                        (-PIT_L * 0.5, s * (hw + WALL * 0.5), zc), lining, 0.0, 0.0)
    # Die +X-Wand der Grube hat die Öffnung der Turmtasche.
    yi = W * 0.5 + 0.025
    pocket_bottom = floor_z(0) - PLATE - 0.0005
    led.rounded_box(root, "Grubenfuss", (WALL, PIT_W, pocket_bottom + depth),
                    (WALL * 0.5, 0, (pocket_bottom - depth) * 0.5), lining, 0.0, 0.0)
    for s in (-1, 1):
        led.rounded_box(root, "Taschenrand%d" % s, (WALL, hw - yi, -pocket_bottom - FELT_T),
                        (WALL * 0.5, s * (yi + hw) * 0.5, (pocket_bottom - FELT_T) * 0.5),
                        lining, 0.0, 0.0)
    # Ein schwacher Saum unter der Filzkante: die Grube liest als gefütterter Schacht.
    for s in (-1, 1):
        led.rounded_box(root, "Saum%d" % s, (PIT_L, 0.004, 0.004),
                        (-PIT_L * 0.5, s * (hw - 0.002), -FELT_T - 0.004), seam, 0.0, 0.0)
    led.rounded_box(root, "SaumKopf", (0.004, PIT_W, 0.004), (-PIT_L + 0.002, 0, -FELT_T - 0.004),
                    seam, 0.0, 0.0)
    return root


def tower(griff, peek=0.03):
    """Der TURM: sechs Etagen unter dem Filz, offen nach -X in die Grube; die unteren ragen weiter."""
    table_with_pit()
    housing = led.mat("Turmgehaeuse", (0.02, 0.02, 0.026), 0.5, 0.4, clearcoat=0.3)
    edge = led.mat("Etagenkante", (0.6, 0.66, 0.8), 0.0, 0.5, 0.8)
    bpy.ops.object.empty_add()
    root = bpy.context.active_object
    root.name = "Turm"
    depth = 0.8 * L + 0.01
    yi = W * 0.5 + 0.025
    for k in range(6):
        z = floor_z(k) - 0.0005 - PLATE
        led.rounded_box(root, "Platte%d" % k, (depth, yi * 2, PLATE),
                        (WALL + depth * 0.5, 0, z + PLATE * 0.5), housing, 0.0, 0.002)
        led.rounded_box(root, "Kante%d" % k, (0.004, yi * 2 - 0.02, 0.004),
                        (WALL + 0.002, 0, z + PLATE - 0.003), edge, 0.0, 0.0)
    zb, zt = floor_z(0) - 0.0005 - PLATE, -FELT_T
    for s in (-1, 1):
        led.rounded_box(root, "Wand%d" % s, (depth + WALL, WALL, zt - zb),
                        (WALL + (depth + WALL) * 0.5, s * (yi + WALL * 0.5), (zb + zt) * 0.5),
                        housing, 0.0, 0.0)
    led.rounded_box(root, "Rueckwand", (WALL, yi * 2 + WALL * 2, zt - zb),
                    (WALL + depth + WALL * 0.5, 0, (zb + zt) * 0.5), housing, 0.0, 0.0)
    for k, (kind, kw) in enumerate(TOWER):
        stub = stub_len(k, peek)
        kw = dict(kw)
        if griff and k == 4:
            stub = 1.05 * L
            # Über dem Netz liegt nur der Stummel von Etage 5: dort bleibt die Projektion aus.
            x_card = -stub + L * 0.5
            kw.update(on=True, float_h=-floor_z(4) - HT + 0.04,
                      clip=(-stub_len(5, peek) - x_card - 0.01, floor_z(5) - floor_z(4) - 0.006))
        dm.build(make(kind, 31 + k, **kw), "Etage%d" % (k + 1), (-stub + L * 0.5, 0, floor_z(k)))
    return root


def station(cam, aim, target, dist, lens=50):
    aim.location = target
    t = math.radians(15)
    cam.location = Vector(target) + Vector((0, -math.sin(t), math.cos(t))) * dist
    cam.data.lens = lens


def view_tower(griff, mode, peek=0.03):
    cam, aim = dm.empty_stage()
    tower(griff, peek)
    if mode == "station":
        if griff:
            station(cam, aim, (-0.89, 0, 0.0), 3.5, 50)
        else:
            station(cam, aim, (-0.62, 0, -0.45), 4.7, 50)
    elif mode == "schraeg":
        aim.location = (-0.4, 0, -0.6) if not griff else (-0.85, 0, -0.1)
        cam.location = (-1.75, -0.75, 0.75) if not griff else (-2.6, -1.9, 1.6)
        cam.data.lens = 26 if not griff else 36
    elif mode == "draufsicht":
        aim.location = (-0.33, 0, -0.5)
        cam.location = (-0.33, 0, 6.0)
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 2.3
    else:
        aim.location = (-0.35, 0, -0.55)
        cam.location = (-1.6, -0.35, 0.3)
        cam.data.lens = 40


TRAY_COLS, TRAY_LANES, TRAY_GAP = 4, 2, 0.1
TRAY_IN = (TRAY_COLS * (L + TRAY_GAP) + TRAY_GAP, TRAY_LANES * (W + TRAY_GAP) + TRAY_GAP)
TRAY_RIM, TRAY_WALL = 0.14, 0.22
TRAYS = [("ZAHLEN", "zahl", [("zahl", {}), ("faktor", {}), ("zahl", {}), None, ("zahl", {}),
                             ("zahl", {}), ("faktor", {}), None]),
         ("MATERIAL", "material", [("material", {})] * 5 + [None, ("material", {}), None]),
         ("RUNEN", "rune", [("rune", {}), ("rune", {}), ("rune", {}), ("rune", {}), None,
                            ("rune", {}), None, None]),
         ("SONDERBESTAND", "gold", [("repair", {}), ("cool", {}), ("blank", {}),
                                    ("bath", {"on": True}), ("repair", {}), None, ("blank", {}),
                                    None])]


def tray(name, key, items, cx, cy, seed):
    bed = led.mat("Tablettbett", (0.008, 0.008, 0.011), 0.0, 0.7)
    rim = led.mat("Tablettrand", (0.03, 0.03, 0.038), 0.6, 0.35, clearcoat=0.4)
    bpy.ops.object.empty_add()
    root = bpy.context.active_object
    iw, ih = TRAY_IN
    led.rounded_box(root, "Bett", (iw, ih, 0.01), (0, 0, 0.005), bed, 0.03, 0.0)
    led.frame_ring(root, "Rahmen", (iw + TRAY_RIM * 2, ih + TRAY_RIM * 2), (iw, ih),
                   TRAY_WALL * 0.5, TRAY_WALL, rim, 0.03, y=0)
    led.frame_ring(root, "Saum", (iw + 0.03, ih + 0.03), (iw, ih), TRAY_WALL + 0.001, 0.004,
                   glow(key, 1.4), 0.03, y=0)
    box.text(root, name, top(TRAY_WALL + 0.001), -iw * 0.5 + 0.6, ih * 0.5 + TRAY_RIM * 0.5,
             0.075, glow(key, 1.6), "Name")
    root.location = (cx, cy, 0)
    for k, item in enumerate(items):
        if not item:
            continue
        kind, kw = item
        c, lane = k // 2, k % 2
        x = cx - iw * 0.5 + TRAY_GAP + L * 0.5 + c * (L + TRAY_GAP)
        y = cy + ih * 0.5 - TRAY_GAP - W * 0.5 - lane * (W + TRAY_GAP)
        dm.build(make(kind, seed + k, **kw), "%s%d" % (name, k), (x, y, 0.011))


def tray_pos(i):
    ow, oh = TRAY_IN[0] + TRAY_RIM * 2, TRAY_IN[1] + TRAY_RIM * 2
    return (i % 2 - 0.5) * (ow + 0.35), (0.5 - i // 2) * (oh + 0.35)


def view_magazin(near):
    cam, aim = dm.empty_stage()
    for i, (name, key, items) in enumerate(TRAYS):
        if near and i != 3:
            continue
        x, y = (0, 0) if near else tray_pos(i)
        tray(name, key, items, x, y, 101 + i * 10)
    if near:
        station(cam, aim, (0, 0.05, 0.1), 11.0, 50)
    else:
        station(cam, aim, (0, 0, 0.1), 13.4, 28)


def view_check():
    dm.empty_stage()
    for name, kind, kw in ROW + [("BAD", "bath", {}), ("BAD · AN", "bath", {"on": True})]:
        root = dm.build(make(kind, 5, **kw), name, (0, 0, 0))
        lo, hi = bounds(root)
        print("HUELLE %-16s X %.4f..%.4f  Y %.4f..%.4f  Z %.4f..%.4f  -> %.4f x %.4f x %.4f" %
              (name, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z))
        if kw.get("on"):
            lo, hi = bounds(root, False)
            print("  mit Projektion Z bis %.4f" % hi.z)


VIEWS = {
    "reihe_draufsicht": lambda: view_row(True),
    "reihe_schraeg": lambda: view_row(False),
    "turm_station": lambda: view_tower(False, "station"),
    "turm_schraeg": lambda: view_tower(False, "schraeg"),
    "turm_griff_station": lambda: view_tower(True, "station"),
    "turm_griff_schraeg": lambda: view_tower(True, "schraeg"),
    "magazin": lambda: view_magazin(False),
    "magazin_nah": lambda: view_magazin(True),
    "stummel_nah": lambda: view_tower(False, "stummel"),
    "stummel_draufsicht": lambda: view_tower(False, "draufsicht"),
    "turm_station_peek6": lambda: view_tower(False, "station", 0.06),
    "stummel_draufsicht_peek6": lambda: view_tower(False, "draufsicht", 0.06),
}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    argv = sys.argv[sys.argv.index("--") + 1:]
    only = argv[1].split(",") if len(argv) > 1 else []
    if "check" in only:
        view_check()
    for name, build_view in VIEWS.items():
        if only and name not in only:
            continue
        build_view()
        bpy.context.scene.eevee.taa_render_samples = 48
        bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
        bpy.ops.render.render(write_still=True)
    print("ok")
