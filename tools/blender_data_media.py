"""Fumble: vier DATENTRÄGER für die Werkstatt-Karten, einer je Sorte (Entwurf 2026-11-18,
zweite Runde: echte, verschiedene Träger statt einer Karte mit anderem Bild). Jeder trägt
das Würfelnetz sichtbar auf sich.
  cd       - ZAHLEN: schillernde Scheibe mit Mittelloch, das Netz neben der Nabe aufgedruckt;
             Faktor-Netz = violette Scheibe
  kassette - MATERIAL: Rauchglas-Kassette mit zwei Spulen, Band über die Führungsrollen,
             das Netz liegend auf dem Etikett zwischen den Spulenfenstern
  karte    - RUNEN: die gläserne Data-Card, Runen als geätzte Leuchtpunkte, Platinen-Zunge
             mit Goldkontakten
  key      - SONDERBESTAND: wuchtiger Service-Schlüssel mit Öse und Chromklinge, das Netz als
             gravierter Umriß mit der Wirkung (Reparatur gold, Kühlung eisblau, Rohling stahlblau)

Aufruf (kopflos):
  blender -b -P tools/blender_data_media.py -- <ausgabe-ordner> [ansicht]
Achsen: X = Breite, Y = Länge (Kopf +Y), Z = Höhe, Ursprung = Mitte unten.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_card_box as box

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
CROSS = [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (1, 3)]
FREE = [(0, 0), (2, 0), (0, 2), (2, 2), (0, 3), (2, 3)]
CROSS_OUTLINE = [(-0.5, 0), (0.5, 0), (0.5, -1), (1.5, -1), (1.5, -2), (0.5, -2), (0.5, -4),
                 (-0.5, -4), (-0.5, -2), (-1.5, -2), (-1.5, -1), (-0.5, -1)]

HEX = {"zahl": "#50fa7b", "faktor": "#9a4dff", "material": "#ff79c6", "rune": "#ffd319",
       "gold": "#ffc83d", "kuehl": "#8be9fd", "rohling": "#5fa8c8"}


def col(key):
    return led.lin(HEX[key])


def glow(key, e=1.6):
    return led.mat("Glut_%s_%.2f" % (key, e), col(key), 0.0, 0.3, e)


def top(z):
    return box.frame((0, 0, z), (1, 0, 0), (0, 1, 0))


def grid_pos(cells, c, x0, y0, horizontal=False):
    """Zell-Mitten eines Kreuzes, Mittelpunkt des Umrisses bei (x0, y0)."""
    out = []
    for cc, r in cells:
        x, y = (cc - 1) * c, -(r - 1.5) * c
        if horizontal:
            x, y = y, -x
        out.append((x0 + x, y0 + y))
    return out


def seg(parent, name, fr, a0, b0, a1, b1, w, material):
    d = Vector((a1 - a0, b1 - b0))
    if d.length < 1e-6:
        return
    p = Vector((-d.y, d.x)).normalized() * w * 0.5
    box.decal(parent, name, fr, [(a0 + p.x, b0 + p.y), (a1 + p.x, b1 + p.y),
                                 (a1 - p.x, b1 - p.y), (a0 - p.x, b0 - p.y)], material)


def dots(parent, name, pts, r, material):
    verts, faces = [], []
    for x, y, z in pts:
        k = len(verts)
        verts += [(x + r, y, z), (x - r, y, z), (x, y + r, z), (x, y - r, z), (x, y, z + r),
                  (x, y, z - r)]
        for a, b in ((0, 2), (2, 1), (1, 3), (3, 0)):
            faces += [[k + a, k + b, k + 4], [k + b, k + a, k + 5]]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = parent
    return o


def cyl(parent, name, r, depth, loc, material, verts=96):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    o.parent = parent
    return o


def annulus(parent, name, cx, cy, z, r0, r1, material, segs=96):
    verts, faces = [], []
    for i in range(segs):
        t = math.tau * i / segs
        for r in (r0, r1):
            verts.append((cx + math.cos(t) * r, cy + math.sin(t) * r, z))
    for i in range(segs):
        j = (i + 1) % segs
        faces.append([i * 2, i * 2 + 1, j * 2 + 1, j * 2])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = parent
    return o


def iridescent(key):
    """Schillernde Datenseite: Regenbogen über den Winkel, in der Sortenfarbe verankert."""
    name = "Schiller_" + key
    if name in led._mats:
        return led._mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ang = nt.nodes.new("ShaderNodeMath")
    ang.operation = "ARCTAN2"
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 3.0 / math.tau
    fr = nt.nodes.new("ShaderNodeMath")
    fr.operation = "FRACT"
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    t = col(key)
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.0, (*t, 1)
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 1.0, (*t, 1)
    for pos, c in ((0.25, (0.2, 0.75, 1.0)), (0.5, (0.95, 0.35, 0.9)), (0.75, (1.0, 0.8, 0.3))):
        e = ramp.color_ramp.elements.new(pos)
        e.color = (*c, 1)
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    nt.links.new(sep.outputs["Y"], ang.inputs[0])
    nt.links.new(sep.outputs["X"], ang.inputs[1])
    nt.links.new(ang.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], fr.inputs[0])
    nt.links.new(fr.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], p.inputs["Base Color"])
    nt.links.new(ramp.outputs[0], p.inputs["Emission"])
    p.inputs["Emission Strength"].default_value = 0.18
    p.inputs["Metallic"].default_value = 1.0
    p.inputs["Roughness"].default_value = 0.1
    led._mats[name] = m
    return m


# --- Zell-Inhalte ----------------------------------------------------------------------

RUNES = [
    [(0, -1, 0, 1), (0, 0.1, 0.6, 0.7), (0, -0.4, 0.6, 0.2)],
    [(0, -1, 0, 1), (0, 0.2, -0.6, 0.9), (0, 0.2, 0.6, 0.9)],
    [(-0.6, -0.9, -0.6, 0.9), (0.6, -0.9, 0.6, 0.9), (-0.6, 0.9, 0.6, -0.9),
     (-0.6, -0.9, 0.6, 0.9)],
    [(-0.5, 0.9, 0.3, 0.2), (0.3, 0.2, -0.3, -0.2), (-0.3, -0.2, 0.5, -0.9)],
    [(0, -1, 0, 1), (0, 1, -0.6, 0.4), (0, 1, 0.6, 0.4)],
    [(0, 0.95, -0.5, 0.3), (0, 0.95, 0.5, 0.3), (-0.5, 0.3, 0.5, -0.4),
     (0.5, 0.3, -0.5, -0.4), (-0.5, -0.4, -0.7, -0.95), (0.5, -0.4, 0.7, -0.95)],
]

MATERIALS = {"gold": ((1.0, 0.72, 0.26), 1.0, 0.18), "kupfer": ((0.95, 0.45, 0.28), 1.0, 0.25),
             "glas": ((0.55, 0.85, 1.0), 0.0, 0.03), "obsidian": ((0.02, 0.015, 0.03), 0.0, 0.05),
             "stahl": ((0.6, 0.62, 0.66), 1.0, 0.3)}


def printed_net(parent, z, key, cells, pos, c, notch=None):
    """Die Zelle wie im Spiel: dunkler Grund mit Rand in der Sortenfarbe, darauf der Inhalt.
    notch = (x, y, r): ein Loch, um das die Zellen ausgespart sind (die CD-Nabe)."""
    navy = led.mat("Zellgrund", (0.0015, 0.003, 0.012), 0.0, 0.45, clearcoat=0.5)
    for i, (x, y) in enumerate(pos):
        plates = [led.rounded_box(parent, "Zellrand%d" % i, (c * 0.92, c * 0.92, 0.004),
                                  (x, y, z + 0.002), glow(key, 1.4), c * 0.1, 0.0, 4)]
        plates.append(led.rounded_box(parent, "Zelle%d" % i, (c * 0.8, c * 0.8, 0.004),
                                      (x, y, z + 0.004), navy, c * 0.08, 0.0, 4))
        if notch and math.hypot(x - notch[0], y - notch[1]) < c:
            for k, p in enumerate(plates):
                led.cut(p, cyl(parent, "Aussparung%d_%d" % (i, k), notch[2] + 0.025 * k,
                               0.1, (notch[0], notch[1], z), led.DARK, 64))
            d = Vector((x - notch[0], y - notch[1])).normalized() * c * 0.1
            x, y = x + d.x, y + d.y
        kind, val = cells[i]
        fr = top(z + 0.007)
        if kind == "num":
            box.text(parent, val, fr, x, y, c * 0.42, glow(key, 2.4), "Zahl%d" % i)
        elif kind == "mat":
            cc, m, r = MATERIALS[val]
            swatch = led.mat("Stoff_" + val, cc, m, r, clearcoat=1.0)
            cyl(parent, "Stoff%d" % i, c * 0.27, 0.012, (x, y, z + 0.012), swatch, 48)
            annulus(parent, "StoffRing%d" % i, x, y, z + 0.0185, c * 0.27, c * 0.31,
                    glow(key, 1.2), 48)
        elif kind == "rune":
            s = c * 0.3
            for k, (a0, b0, a1, b1) in enumerate(RUNES[val]):
                seg(parent, "Rune%d_%d" % (i, k), fr, x + a0 * s, y + b0 * s, x + a1 * s,
                    y + b1 * s, c * 0.055, glow(key, 2.4))


# --- ZAHLEN: die CD -----------------------------------------------------------------------

CD_R = 1.0
CD_T = 0.024


def cd(parent, key="zahl", cells=None):
    cells = cells or [("num", "+3"), ("num", "+1"), ("num", "+2"), ("num", "+1"),
                      ("num", "+4"), ("empty", None)]
    disc = cyl(parent, "Scheibe", CD_R, CD_T, (0, 0, CD_T * 0.5), iridescent(key), 128)
    hole = cyl(parent, "Loch", 0.11, 0.2, (0, 0, 0), led.DARK, 48)
    led.cut(disc, hole)
    clear = led.mat("Stapelring", (0.85, 0.9, 0.95), 0.0, 0.05, 0.0, 0.35)
    annulus(parent, "Stapelring", 0, 0, CD_T + 0.0008, 0.11, 0.3, clear)
    annulus(parent, "Spiegelband", 0, 0, CD_T + 0.0009, 0.3, 0.345,
            led.mat("Spiegel", (0.9, 0.9, 0.92), 1.0, 0.04))
    annulus(parent, "Nabenring", 0, 0, CD_T + 0.001, 0.11, 0.125, glow(key, 1.6), 48)
    annulus(parent, "Rand", 0, 0, CD_T + 0.0009, CD_R - 0.012, CD_R, glow(key, 1.4), 160)
    # Das Netz neben der Nabe: das Loch liegt im freien Block links unten des Kreuzes.
    c = CD_R / 3.42
    pos = grid_pos(CROSS, c, c, c)
    printed_net(parent, CD_T, key, cells, pos, c)
    box.text(parent, "ZAHLEN", top(CD_T), -0.55, 0.55, 0.07, glow(key, 1.2), "Sorte")
    box.text(parent, "DISC", top(CD_T), -0.62, 0.45, 0.05, glow(key, 0.8), "Typ")


def cd_factor(parent):
    cd(parent, "faktor", [("num", "×2"), ("empty", None), ("num", "×2"), ("empty", None),
                          ("num", "×2"), ("empty", None)])


# --- MATERIAL: die Kassette ---------------------------------------------------------------

CW, CH, CT = 2.4, 1.52, 0.18


def cassette(parent, key="material", cells=None):
    cells = cells or [("mat", "gold"), ("mat", "kupfer"), ("mat", "glas"), ("empty", None),
                      ("mat", "obsidian"), ("mat", "stahl")]
    smoke = led.mat("Rauchgehaeuse", (0.05, 0.01, 0.035), 0.0, 0.12, 0.0, 0.55)
    led.rounded_box(parent, "Gehaeuse", (CW, CH, CT), (0, 0, CT * 0.5), smoke, 0.08, 0.02)
    led.frame_ring(parent, "Naht", (CW + 0.008, CH + 0.008), (CW - 0.03, CH - 0.03), CT * 0.5,
                   0.012, glow(key, 1.8), 0.06, 0.0)
    reel_y = 0.12
    tape_mat = led.mat("Band", (0.05, 0.03, 0.022), 0.5, 0.25, clearcoat=0.6)
    hub = led.mat("Nabe_" + key, (0.92, 0.9, 0.92), 0.0, 0.35, clearcoat=0.5)
    chrome = led.mat("Chrom2", (0.9, 0.9, 0.92), 1.0, 0.05)
    for s in (-1, 1):
        x = s * 0.86
        cyl(parent, "Wickel%d" % s, 0.36 if s < 0 else 0.22, CT * 0.5, (x, reel_y, CT * 0.5),
            tape_mat, 64)
        cyl(parent, "Spule%d" % s, 0.12, CT * 0.6, (x, reel_y, CT * 0.5), hub, 48)
        cyl(parent, "Spulenloch%d" % s, 0.06, CT * 0.62, (x, reel_y, CT * 0.5), led.DARK, 6)
        for k in range(6):
            t = k * math.tau / 6
            led.rounded_box(parent, "Zahn%d_%d" % (s, k), (0.018, 0.018, CT * 0.62),
                            (x + math.cos(t) * 0.07, reel_y + math.sin(t) * 0.07, CT * 0.5),
                            hub, 0.0, 0.0)
        cyl(parent, "Fenster%d" % s, 0.26, 0.006, (x, reel_y, CT + 0.003),
            led.mat("Fensterglas", (0.9, 0.9, 1.0), 0.0, 0.02, 0.0, 0.08), 64)
        annulus(parent, "Fensterring%d" % s, x, reel_y, CT + 0.007, 0.26, 0.29, glow(key, 1.6),
                64)
        cyl(parent, "Rolle%d" % s, 0.045, CT * 0.7, (s * 0.72, -0.6, CT * 0.5), chrome, 24)
    led.rounded_box(parent, "Bandlauf", (1.5, 0.012, CT * 0.4), (0, -0.645, CT * 0.5), tape_mat,
                    0.0, 0.0)
    # Das ETIKETT mit dem liegenden Netz zwischen den Spulen.
    c = 0.27
    label = led.mat("Etikett", (0.012, 0.008, 0.014), 0.0, 0.6)
    led.rounded_box(parent, "Etikett", (1.16, 0.9, 0.006), (0, reel_y, CT + 0.003), label, 0.04,
                    0.0)
    pos = grid_pos(CROSS, c, 0, reel_y, horizontal=True)
    printed_net(parent, CT + 0.006, key, cells, pos, c)
    box.text(parent, "MATERIAL", top(CT + 0.006), 0, 0.66, 0.08, glow(key, 1.4), "Sorte")
    box.text(parent, "A", top(CT + 0.006), -1.05, 0.62, 0.1, glow(key, 1.0), "Seite")
    # Der KOPF unten: Trapez mit den Antriebslöchern.
    head = led.mat("Kopfplatte", (0.03, 0.01, 0.025), 0.0, 0.4, clearcoat=0.4)
    box.decal(parent, "Kopf", top(CT + 0.001), [(-0.82, -0.76), (0.82, -0.76), (0.66, -0.46),
                                                (-0.66, -0.46)], head)
    for x in (-0.48, -0.16, 0.16, 0.48):
        box.dot(parent, "Antrieb%.2f" % x, top(CT + 0.002), x, -0.6, 0.035, led.DARK)
    screw = led.mat("Schraube", (0.85, 0.86, 0.88), 1.0, 0.15)
    for x, y in ((-1.1, 0.66), (1.1, 0.66), (-1.1, -0.66), (1.1, -0.66), (0, -0.52)):
        cyl(parent, "Schraube%.1f%.1f" % (x, y), 0.03, 0.01, (x, y, CT + 0.004), screw, 16)


# --- RUNEN: die gläserne Data-Card ---------------------------------------------------------

DW, DL, DD = 1.08, 1.5, 0.15


def glass_card(parent, key="rune", glyphs=(0, 1, 2, 3, 4, 5)):
    glass = led.mat("Quarz", (0.98, 0.92, 0.7), 0.0, 0.02, 0.06, 0.2)
    led.chamfer_box(parent, "Platte", (DW, DL, DD), (0, 0.08, DD * 0.5), glass, 0.04, 0.02)
    led.rounded_box(parent, "Kopfleiste", (DW * 0.94, 0.014, 0.02),
                    (0, 0.08 + DL * 0.5 - 0.004, DD * 0.6), glow(key, 2.0), 0.0, 0.0)
    c, zc, y0 = 0.3, DD * 0.5, 0.2
    pos = grid_pos(CROSS, c, 0, y0)
    frost = led.mat("Mattiert", (0.9, 0.85, 0.7), 0.0, 0.7, 0.05, 0.22)
    rim = led.mat("Aetzrand", col(key), 0.0, 0.3, 0.9)
    bright = led.mat("Aetzpunkt", col(key), 0.0, 0.3, 4.0)
    rim_pts, glyph_pts = [], []
    step = 0.018
    for i, (x, y) in enumerate(pos):
        led.rounded_box(parent, "Matt%d" % i, (c * 0.86, c * 0.86, 0.002), (x, y, zc - 0.02),
                        frost, c * 0.08, 0.0, 4)
        h = c * 0.43
        n = int(2 * h / step)
        for k in range(n + 1):
            t = -h + k * 2 * h / n
            rim_pts += [(x + t, y - h, zc), (x + t, y + h, zc), (x - h, y + t, zc),
                        (x + h, y + t, zc)]
        s = c * 0.3
        for a0, b0, a1, b1 in RUNES[glyphs[i]]:
            m = max(2, int(math.hypot(a1 - a0, b1 - b0) * s / (step * 0.6)))
            for k in range(m + 1):
                f = k / m
                glyph_pts.append((x + (a0 + (a1 - a0) * f) * s, y + (b0 + (b1 - b0) * f) * s,
                                  zc + 0.012))
    dots(parent, "Aetzrand", rim_pts, 0.0045, rim)
    dots(parent, "Aetzrune", glyph_pts, 0.008, bright)
    field = []
    for x, y in grid_pos(FREE, c, 0, y0):
        for layer, z in enumerate((zc - 0.03, zc + 0.03)):
            for ix in range(8):
                for iy in range(8):
                    if (ix * 7 + iy * 13 + layer * 5) % 5 < 3:
                        field.append((x - c * 0.4 + ix * 0.038 + layer * 0.019,
                                      y + c * 0.4 - iy * 0.038 - layer * 0.019, z))
    dots(parent, "Datenfeld", field, 0.0035, led.mat("Datenpunkt", col(key), 0.0, 0.3, 0.5))
    # Die PLATINEN-ZUNGE mit Goldkontakten und Kodierkerbe.
    pcb = led.mat("Platine", (0.01, 0.02, 0.015), 0.0, 0.4, clearcoat=0.6)
    tongue_y = 0.08 - DL * 0.5 - 0.11
    t = led.rounded_box(parent, "Zunge", (DW * 0.82, 0.24, 0.05), (0, tongue_y, DD * 0.5), pcb,
                        0.01, 0.0)
    led.cut(t, led.rounded_box(parent, "Kerbe", (0.05, 0.12, 0.2),
                               (0.18, tongue_y - 0.08, DD * 0.5), pcb, 0.0, 0.0))
    gold = led.mat("Kontaktgold", (1.0, 0.72, 0.3), 1.0, 0.2)
    for k in range(10):
        x = -0.38 + k * 0.08
        if abs(x - 0.18) < 0.05:
            continue
        led.rounded_box(parent, "Finger%d" % k, (0.05, 0.15, 0.054),
                        (x, tongue_y - 0.03, DD * 0.5), gold, 0.006, 0.0)


# --- SONDERBESTAND: der Service-Schlüssel -----------------------------------------------------

KW, KL, KT = 1.1, 1.36, 0.22


def service_key(parent, key="gold", mode="repair"):
    shell = led.mat("Anodisiert", (0.012, 0.012, 0.016), 0.6, 0.32, clearcoat=0.5)
    led.chamfer_box(parent, "Kopf", (KW, KL, KT), (0, 0, KT * 0.5), shell, 0.22, 0.03)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.15, minor_radius=0.035,
                                     location=(0, KL * 0.5 + 0.08, KT * 0.5))
    ring = bpy.context.active_object
    ring.name = "Oese"
    ring.data.materials.append(led.mat("Oesenchrom", (0.85, 0.86, 0.88), 1.0, 0.1))
    bpy.ops.object.shade_smooth()
    ring.parent = parent
    for s in (-1, 1):
        for k in range(6):
            led.rounded_box(parent, "Rippe%d_%d" % (s, k), (0.02, 0.05, KT * 0.6),
                            (s * KW * 0.5, -0.25 + k * 0.1, KT * 0.5), shell, 0.008, 0.004, 4)
    led.rounded_box(parent, "Leuchtrand", (KW * 0.86, KL * 0.9, 0.006), (0, 0, KT + 0.001),
                    glow(key, 0.5), 0.18, 0.0)
    led.rounded_box(parent, "Front", (KW * 0.84, KL * 0.88, 0.008), (0, 0, KT + 0.003),
                    led.mat("Frontglas", (0.003, 0.003, 0.005), 0.0, 0.05, clearcoat=1.0), 0.17,
                    0.0)
    # Die KLINGE mit den Kontakten und dem Ladelicht am Hals.
    blade_y = -KL * 0.5 - 0.24
    led.rounded_box(parent, "Hals", (0.5, 0.08, KT * 0.7), (0, -KL * 0.5 - 0.02, KT * 0.5),
                    shell, 0.02, 0.01)
    led.rounded_box(parent, "Klinge", (0.38, 0.46, 0.07), (0, blade_y, KT * 0.5),
                    led.mat("Klingenchrom", (0.86, 0.87, 0.9), 1.0, 0.08), 0.03, 0.006)
    gold = led.mat("Kontaktgold", (1.0, 0.72, 0.3), 1.0, 0.2)
    for k in range(4):
        led.rounded_box(parent, "Kontakt%d" % k, (0.05, 0.24, 0.074),
                        (-0.105 + k * 0.07, blade_y - 0.04, KT * 0.5), gold, 0.006, 0.0)
    led.rounded_box(parent, "Ladelicht", (0.4, 0.016, 0.02), (0, -KL * 0.5 + 0.04, KT + 0.004),
                    glow(key, 3.0), 0.0, 0.0)
    # Das NETZ als gravierter Umriß; die Wirkung gilt dem ganzen Würfel.
    c, y0 = 0.27, 0.0
    z = KT + 0.008
    fr = top(z)
    line = glow(key, 2.2)
    outline = [(x * c, y0 + (y + 2) * c) for x, y in CROSS_OUTLINE]
    for k in range(len(outline)):
        a, b = outline[k], outline[(k + 1) % len(outline)]
        if mode != "blank":
            seg(parent, "Umriss%d" % k, fr, a[0], a[1], b[0], b[1], 0.012, line)
            continue
        n = max(1, int(Vector((b[0] - a[0], b[1] - a[1])).length / 0.05))
        for j in range(n):
            f0, f1 = j / n, (j + 0.55) / n
            seg(parent, "Strich%d_%d" % (k, j), fr, a[0] + (b[0] - a[0]) * f0,
                a[1] + (b[1] - a[1]) * f0, a[0] + (b[0] - a[0]) * f1, a[1] + (b[1] - a[1]) * f1,
                0.01, line)
    pos = grid_pos(CROSS, c, 0, y0)
    big = glow(key, 3.0)
    cx, cy = pos[2]
    if mode == "blank":
        for i, (x, y) in enumerate(pos[:-1]):
            box.text(parent, "?", fr, x, y, c * 0.4, glow(key, 0.9), "Frage%d" % i)
        box.text(parent, "ROHLING", fr, *pos[5], c * 0.17, big, "Rohling")
    elif mode == "repair":
        seg(parent, "Schluessel", fr, cx - 0.08, cy - 0.08, cx + 0.05, cy + 0.05, 0.035, big)
        annulus(parent, "Maul", cx + 0.07, cy + 0.07, z + 0.001, 0.025, 0.048, big, 32)
        box.text(parent, "0", fr, *pos[0], c * 0.5, big, "Null")
        box.text(parent, "HEIL", fr, *pos[4], c * 0.26, big, "Heil")
    else:
        for k in range(3):
            t = k * math.pi / 3
            dx, dy = math.cos(t) * 0.1, math.sin(t) * 0.1
            seg(parent, "Flocke%d" % k, fr, cx - dx, cy - dy, cx + dx, cy + dy, 0.018, big)
            for s in (-1, 1):
                ex, ey = cx + s * dx * 0.7, cy + s * dy * 0.7
                for side in (-1, 1):
                    tt = t + side * 0.6
                    seg(parent, "Ast%d%d%d" % (k, s, side), fr, ex, ey,
                        ex + s * math.cos(tt) * 0.035, ey + s * math.sin(tt) * 0.035, 0.012, big)
        box.text(parent, "-1", fr, *pos[0], c * 0.5, big, "Minus")
        box.text(parent, "LADUNG", fr, *pos[4], c * 0.2, big, "Ladung")


# --- Bühne ------------------------------------------------------------------------------

MEDIA = [("ZAHLEN", cd, (-3.6, 0.9)), ("MATERIAL", cassette, (-0.9, 0.9)),
         ("RUNEN", glass_card, (1.2, 0.9)), ("SONDER", lambda p: service_key(p), (2.9, 0.9))]
VARIANTS = [("FAKTOR", cd_factor, (-2.2, -1.5)),
            ("KUEHL", lambda p: service_key(p, "kuehl", "cool"), (0.4, -1.5)),
            ("ROHLING", lambda p: service_key(p, "rohling", "blank"), (2.0, -1.5))]


def empty_stage():
    led.stage(lambda *a: None, False, True)
    for o in list(bpy.data.objects):
        if o.name.startswith("Paket"):
            bpy.data.objects.remove(o)
    # Eevee zeigt die Softboxen der Kamera: hoch über sie damit.
    for o in bpy.data.objects:
        mats = getattr(o.data, "materials", None) if o.data is not None else None
        if mats and mats[0] is not None and mats[0].name.startswith("Softbox"):
            o.location.z += 10.0
    cam = bpy.context.scene.camera
    return cam, cam.constraints[0].target


def build(fn, name, loc, rot=(0, 0, 0)):
    bpy.ops.object.empty_add(location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = name
    fn(root)
    root.location = loc
    root.rotation_euler = rot
    return root


def view_overview(flat):
    cam, aim = empty_stage()
    for name, fn, (x, y) in MEDIA + VARIANTS:
        build(fn, name, (x, y, 0.001))
    aim.location = (-0.3, -0.35, 0)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 9.6
        cam.location = (-0.3, -0.35, 14)
    else:
        cam.location = (2.0, -8.6, 7.6)
        cam.data.lens = 40


def view_hero(i, dist):
    cam, aim = empty_stage()
    name, fn, _ = MEDIA[i]
    build(fn, name, (0, 0, 0.001))
    aim.location = (0, -0.05, 0.05)
    cam.location = Vector((0.55, -1.25, 1.1)) * dist
    cam.data.lens = 50


VIEWS = {"uebersicht": lambda: view_overview(False), "draufsicht": lambda: view_overview(True),
         "nah_zahlen": lambda: view_hero(0, 1.9), "nah_material": lambda: view_hero(1, 2.2),
         "nah_runen": lambda: view_hero(2, 1.6), "nah_sonder": lambda: view_hero(3, 1.6)}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[sys.argv.index("--") + 2] if len(sys.argv) > sys.argv.index("--") + 2 else ""
    for name, make in VIEWS.items():
        if only and name != only:
            continue
        make()
        bpy.context.scene.eevee.taa_render_samples = 48
        bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
        bpy.ops.render.render(write_still=True)
    print("ok")
