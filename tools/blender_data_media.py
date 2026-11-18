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

# Die EINE Netzgröße: jede Zelle auf jedem Träger gleich groß, der Träger wächst ums Netz.
NET = 0.36

CD_R = 2.14 * NET
CD_T = 0.024


def cd(parent, key="zahl", cells=None):
    cells = cells or [("num", "+3"), ("num", "+1"), ("num", "+2"), ("num", "+1"),
                      ("num", "+4"), ("empty", None)]
    disc = cyl(parent, "Scheibe", CD_R, CD_T, (0, 0, CD_T * 0.5), iridescent(key), 128)
    hole = cyl(parent, "Loch", 0.1, 0.2, (0, 0, 0), led.DARK, 48)
    led.cut(disc, hole)
    clear = led.mat("Stapelring", (0.85, 0.9, 0.95), 0.0, 0.05, 0.0, 0.35)
    annulus(parent, "Stapelring", 0, 0, CD_T + 0.0008, 0.1, 0.2, clear)
    annulus(parent, "Spiegelband", 0, 0, CD_T + 0.0009, 0.2, 0.23,
            led.mat("Spiegel", (0.9, 0.9, 0.92), 1.0, 0.04))
    annulus(parent, "Rand", 0, 0, CD_T + 0.0009, CD_R - 0.012, CD_R, glow(key, 1.4), 160)
    # Das Netz mitten auf der Scheibe; die zwei Zellen an der Nabe sind um sie ausgespart.
    pos = grid_pos(CROSS, NET, 0, 0)
    printed_net(parent, CD_T, key, cells, pos, NET, notch=(0, 0, 0.1))
    fx, fy = grid_pos([(0, 0)], NET, 0, 0)[0]
    box.text(parent, "ZAHLEN", top(CD_T), fx, fy + 0.03, 0.06, glow(key, 1.2), "Sorte")
    box.text(parent, "DISC", top(CD_T), fx, fy - 0.04, 0.045, glow(key, 0.8), "Typ")


def cd_factor(parent):
    cd(parent, "faktor", [("num", "×2"), ("empty", None), ("num", "×2"), ("empty", None),
                          ("num", "×2"), ("empty", None)])


# --- MATERIAL: die Kassette ---------------------------------------------------------------

CW, CH, CT = 2.12, 1.68, 0.18


def cassette(parent, key="material", cells=None):
    cells = cells or [("mat", "gold"), ("mat", "kupfer"), ("mat", "glas"), ("empty", None),
                      ("mat", "obsidian"), ("mat", "stahl")]
    smoke = led.mat("Rauchgehaeuse", (0.05, 0.01, 0.035), 0.0, 0.12, 0.0, 0.55)
    led.rounded_box(parent, "Gehaeuse", (CW, CH, CT), (0, 0, CT * 0.5), smoke, 0.08, 0.02)
    led.frame_ring(parent, "Naht", (CW + 0.008, CH + 0.008), (CW - 0.03, CH - 0.03), CT * 0.5,
                   0.012, glow(key, 1.8), 0.06, 0.0)
    y0 = 0.03
    reel_x = 0.8
    tape_mat = led.mat("Band", (0.05, 0.03, 0.022), 0.5, 0.25, clearcoat=0.6)
    hub = led.mat("Nabe_" + key, (0.92, 0.9, 0.92), 0.0, 0.35, clearcoat=0.5)
    chrome = led.mat("Chrom2", (0.9, 0.9, 0.92), 1.0, 0.05)
    for s in (-1, 1):
        x = s * reel_x
        cyl(parent, "Wickel%d" % s, 0.3 if s < 0 else 0.18, CT * 0.5, (x, y0, CT * 0.5),
            tape_mat, 64)
        cyl(parent, "Spule%d" % s, 0.1, CT * 0.6, (x, y0, CT * 0.5), hub, 48)
        cyl(parent, "Spulenloch%d" % s, 0.05, CT * 0.62, (x, y0, CT * 0.5), led.DARK, 6)
        for k in range(6):
            t = k * math.tau / 6
            led.rounded_box(parent, "Zahn%d_%d" % (s, k), (0.016, 0.016, CT * 0.62),
                            (x + math.cos(t) * 0.06, y0 + math.sin(t) * 0.06, CT * 0.5),
                            hub, 0.0, 0.0)
        cyl(parent, "Fenster%d" % s, 0.2, 0.006, (x, y0, CT + 0.003),
            led.mat("Fensterglas", (0.9, 0.9, 1.0), 0.0, 0.02, 0.0, 0.08), 64)
        annulus(parent, "Fensterring%d" % s, x, y0, CT + 0.007, 0.2, 0.225, glow(key, 1.6), 64)
        cyl(parent, "Rolle%d" % s, 0.04, CT * 0.7, (s * 0.72, -0.66, CT * 0.5), chrome, 24)
    led.rounded_box(parent, "Bandlauf", (1.44, 0.012, CT * 0.4), (0, -0.7, CT * 0.5), tape_mat,
                    0.0, 0.0)
    # Das ETIKETT trägt das Netz in voller Größe, die Spulen links und rechts daneben.
    label = led.mat("Etikett", (0.012, 0.008, 0.014), 0.0, 0.6)
    led.rounded_box(parent, "Etikett", (3 * NET + 0.08, 4 * NET + 0.08, 0.006),
                    (0, y0, CT + 0.003), label, 0.04, 0.0)
    pos = grid_pos(CROSS, NET, 0, y0)
    printed_net(parent, CT + 0.006, key, cells, pos, NET)
    fl, fr_ = grid_pos([(0, 0), (2, 0)], NET, 0, y0)
    box.text(parent, "MATERIAL", top(CT + 0.006), fl[0], fl[1], 0.05, glow(key, 1.4), "Sorte")
    box.text(parent, "A", top(CT + 0.006), fr_[0], fr_[1], 0.12, glow(key, 1.0), "Seite")
    # Der KOPF unten: Trapez mit den Antriebslöchern.
    head = led.mat("Kopfplatte", (0.03, 0.01, 0.025), 0.0, 0.4, clearcoat=0.4)
    box.decal(parent, "Kopf", top(CT + 0.001), [(-0.8, -CH * 0.5 + 0.02), (0.8, -CH * 0.5 + 0.02),
                                                (0.68, -0.74), (-0.68, -0.74)], head)
    for x in (-0.6, -0.35, 0.35, 0.6):
        box.dot(parent, "Antrieb%.2f" % x, top(CT + 0.002), x, -0.79, 0.025, led.DARK)
    screw = led.mat("Schraube", (0.85, 0.86, 0.88), 1.0, 0.15)
    for x, y in ((-0.98, 0.76), (0.98, 0.76), (-0.98, -0.76), (0.98, -0.76)):
        cyl(parent, "Schraube%.1f%.1f" % (x, y), 0.028, 0.01, (x, y, CT + 0.004), screw, 16)


# --- RUNEN: die gläserne Data-Card ---------------------------------------------------------

DW, DL, DD = 3 * NET + 0.12, 4 * NET + 0.16, 0.15


def glass_card(parent, key="rune", glyphs=(0, 1, 2, 3, 4, 5)):
    cy0 = 0.1
    glass = led.mat("Quarz", (0.98, 0.92, 0.7), 0.0, 0.02, 0.06, 0.2)
    led.chamfer_box(parent, "Platte", (DW, DL, DD), (0, cy0, DD * 0.5), glass, 0.04, 0.02)
    led.rounded_box(parent, "Kopfleiste", (DW * 0.94, 0.014, 0.02),
                    (0, cy0 + DL * 0.5 - 0.004, DD * 0.6), glow(key, 2.0), 0.0, 0.0)
    c, zc = NET, DD * 0.5
    pos = grid_pos(CROSS, c, 0, cy0)
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
    dots(parent, "Aetzrune", glyph_pts, 0.009, bright)
    field = []
    for x, y in grid_pos(FREE, c, 0, cy0):
        for layer, z in enumerate((zc - 0.03, zc + 0.03)):
            for ix in range(9):
                for iy in range(9):
                    if (ix * 7 + iy * 13 + layer * 5) % 5 < 3:
                        field.append((x - c * 0.4 + ix * 0.038 + layer * 0.019,
                                      y + c * 0.4 - iy * 0.038 - layer * 0.019, z))
    dots(parent, "Datenfeld", field, 0.0035, led.mat("Datenpunkt", col(key), 0.0, 0.3, 0.5))
    # Die PLATINEN-ZUNGE mit Goldkontakten und Kodierkerbe.
    pcb = led.mat("Platine", (0.01, 0.02, 0.015), 0.0, 0.4, clearcoat=0.6)
    tongue_y = cy0 - DL * 0.5 - 0.1
    t = led.rounded_box(parent, "Zunge", (DW * 0.82, 0.22, 0.05), (0, tongue_y, DD * 0.5), pcb,
                        0.01, 0.0)
    led.cut(t, led.rounded_box(parent, "Kerbe", (0.05, 0.12, 0.2),
                               (0.2, tongue_y - 0.08, DD * 0.5), pcb, 0.0, 0.0))
    gold = led.mat("Kontaktgold", (1.0, 0.72, 0.3), 1.0, 0.2)
    for k in range(12):
        x = -0.43 + k * 0.078
        if abs(x - 0.2) < 0.05:
            continue
        led.rounded_box(parent, "Finger%d" % k, (0.048, 0.14, 0.054),
                        (x, tongue_y - 0.03, DD * 0.5), gold, 0.006, 0.0)


# --- SONDERBESTAND: der Service-Schlüssel -----------------------------------------------------

KW, KL, KT = 3 * NET + 0.14, 4 * NET + 0.18, 0.22


def service_key(parent, key="gold", mode="repair"):
    shell = led.mat("Anodisiert", (0.012, 0.012, 0.016), 0.6, 0.32, clearcoat=0.5)
    led.chamfer_box(parent, "Kopf", (KW, KL, KT), (0, 0, KT * 0.5), shell, 0.2, 0.03)
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
    led.rounded_box(parent, "Leuchtrand", (KW - 0.04, KL - 0.04, 0.006), (0, 0, KT + 0.001),
                    glow(key, 0.5), 0.17, 0.0)
    led.rounded_box(parent, "Front", (KW - 0.06, KL - 0.06, 0.008), (0, 0, KT + 0.003),
                    led.mat("Frontglas", (0.003, 0.003, 0.005), 0.0, 0.05, clearcoat=1.0), 0.16,
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
    led.rounded_box(parent, "Ladelicht", (0.4, 0.016, 0.02), (0, -KL * 0.5 + 0.03, KT + 0.004),
                    glow(key, 3.0), 0.0, 0.0)
    effect_net(parent, KT + 0.008, key, mode)


def effect_net(parent, z, key, mode, x0=0.0, y0=0.0, gain=1.0, outline_only=False):
    """Das NETZ als Umriß in voller Größe mit der Wirkung; sie gilt dem ganzen Würfel."""
    c, f = NET, NET / 0.27
    fr = top(z)
    line = glow(key, 2.2 * gain)
    outline = [(x0 + x * c, y0 + (y + 2) * c) for x, y in CROSS_OUTLINE]
    for k in range(len(outline)):
        a, b = outline[k], outline[(k + 1) % len(outline)]
        if mode != "blank":
            seg(parent, "Umriss%d" % k, fr, a[0], a[1], b[0], b[1], 0.014, line)
            continue
        n = max(1, int(Vector((b[0] - a[0], b[1] - a[1])).length / 0.06))
        for j in range(n):
            f0, f1 = j / n, (j + 0.55) / n
            seg(parent, "Strich%d_%d" % (k, j), fr, a[0] + (b[0] - a[0]) * f0,
                a[1] + (b[1] - a[1]) * f0, a[0] + (b[0] - a[0]) * f1, a[1] + (b[1] - a[1]) * f1,
                0.012, line)
    pos = grid_pos(CROSS, c, x0, y0)
    big = glow(key, 3.0 * gain)
    cx, cy = pos[2]
    if outline_only:
        return
    if mode == "blank":
        for i, (x, y) in enumerate(pos[:-1]):
            box.text(parent, "?", fr, x, y, c * 0.4, glow(key, 0.9), "Frage%d" % i)
        box.text(parent, "ROHLING", fr, *pos[5], c * 0.17, big, "Rohling")
    elif mode == "repair":
        seg(parent, "Schluessel", fr, cx - 0.08 * f, cy - 0.08 * f, cx + 0.05 * f, cy + 0.05 * f,
            0.035 * f, big)
        annulus(parent, "Maul", cx + 0.07 * f, cy + 0.07 * f, z + 0.001, 0.025 * f, 0.048 * f,
                big, 32)
        box.text(parent, "0", fr, *pos[0], c * 0.5, big, "Null")
        box.text(parent, "HEIL", fr, *pos[4], c * 0.26, big, "Heil")
    else:
        for k in range(3):
            t = k * math.pi / 3
            dx, dy = math.cos(t) * 0.1 * f, math.sin(t) * 0.1 * f
            seg(parent, "Flocke%d" % k, fr, cx - dx, cy - dy, cx + dx, cy + dy, 0.018 * f, big)
            for s in (-1, 1):
                ex, ey = cx + s * dx * 0.7, cy + s * dy * 0.7
                for side in (-1, 1):
                    tt = t + side * 0.6
                    seg(parent, "Ast%d%d%d" % (k, s, side), fr, ex, ey,
                        ex + s * math.cos(tt) * 0.035 * f, ey + s * math.sin(tt) * 0.035 * f,
                        0.012 * f, big)
        box.text(parent, "-1", fr, *pos[0], c * 0.5, big, "Minus")
        box.text(parent, "LADUNG", fr, *pos[4], c * 0.2, big, "Ladung")


# === Runde 4 (2026-11-18): kleinere Kassetten, Lochkarte, drei neue Träger ===================

MAT_CELLS = [("mat", "gold"), ("mat", "kupfer"), ("mat", "glas"), ("empty", None),
             ("mat", "obsidian"), ("mat", "stahl")]


def tape_reel(parent, name, x, y, r, z_top, key, fill):
    """Ein Spulenfenster: Wickel, Nabe mit Zähnen, Glas und Leuchtring."""
    tape_mat = led.mat("Band", (0.05, 0.03, 0.022), 0.5, 0.25, clearcoat=0.6)
    hub = led.mat("Nabe_" + key, (0.92, 0.9, 0.92), 0.0, 0.35, clearcoat=0.5)
    led.rounded_box(parent, name + "Mulde", (r * 2, r * 2, 0.004), (x, y, z_top + 0.0005),
                    led.DARK, r * 0.98, 0.0)
    cyl(parent, name + "Wickel", r * fill, 0.004, (x, y, z_top + 0.003), tape_mat, 48)
    cyl(parent, name + "Nabe", r * 0.36, 0.008, (x, y, z_top + 0.005), hub, 32)
    cyl(parent, name + "Loch", r * 0.18, 0.009, (x, y, z_top + 0.0055), led.DARK, 6)
    for k in range(6):
        t = k * math.tau / 6
        led.rounded_box(parent, name + "Zahn%d" % k, (r * 0.08, r * 0.08, 0.01),
                        (x + math.cos(t) * r * 0.26, y + math.sin(t) * r * 0.26, z_top + 0.006),
                        hub, 0.0, 0.0)
    cyl(parent, name + "Glas", r, 0.004, (x, y, z_top + 0.011),
        led.mat("Fensterglas", (0.9, 0.9, 1.0), 0.0, 0.02, 0.0, 0.08), 48)
    annulus(parent, name + "Ring", x, y, z_top + 0.0135, r, r * 1.12, glow(key, 1.6), 48)


def screws(parent, pts, z):
    screw = led.mat("Schraube", (0.85, 0.86, 0.88), 1.0, 0.15)
    for k, (x, y) in enumerate(pts):
        cyl(parent, "Schraube%d" % k, 0.026, 0.01, (x, y, z + 0.004), screw, 16)
        seg(parent, "Schlitz%d" % k, top(z + 0.0095), x - 0.018, y, x + 0.018, y, 0.006,
            led.DARK)


def cassette_kompakt(parent, key="material", cells=None):
    """KOMPAKT: quer, das Netz liegt; die Spulen in den freien oberen Ecken, der Bandkopf im
    freien Block unten links - kein Rand, der nichts trägt."""
    c, T = NET, 0.16
    w, h = 4 * c + 0.16, 3 * c + 0.12
    y0 = 0.0
    shell = led.mat("Kompaktschale", (0.03, 0.008, 0.022), 0.0, 0.35, clearcoat=0.5)
    led.rounded_box(parent, "Gehaeuse", (w, h, T), (0, 0, T * 0.5), shell, 0.07, 0.015)
    led.frame_ring(parent, "Naht", (w + 0.008, h + 0.008), (w - 0.03, h - 0.03), T * 0.5, 0.012,
                   glow(key, 1.8), 0.05, 0.0)
    pos = grid_pos(CROSS, c, 0, y0, horizontal=True)
    printed_net(parent, T, key, cells or MAT_CELLS, pos, c)
    for s in (-1, 1):
        tape_reel(parent, "Spule%d" % s, s * 1.5 * c, y0 + c, c * 0.42, T, key,
                  0.95 if s < 0 else 0.6)
    box.text(parent, "A", top(T), -0.5 * c, y0 + c, 0.12, glow(key, 1.0), "Seite")
    fx, fy = 1.5 * c, y0 - c
    box.text(parent, "MATERIAL", top(T), fx, fy + 0.03, 0.05, glow(key, 1.3), "Sorte")
    box.text(parent, "C-46", top(T), fx, fy - 0.04, 0.04, glow(key, 0.8), "Typ")
    # Der KOPF im freien Block unten links: Trapez, Band in der Öffnung, zwei Antriebslöcher.
    head = led.mat("Kopfplatte", (0.14, 0.05, 0.1), 0.0, 0.4, clearcoat=0.4)
    tape = led.mat("Band", (0.05, 0.03, 0.022), 0.5, 0.25, clearcoat=0.6)
    yb, yt = -h * 0.5, y0 - 0.5 * c - 0.03
    trap = [(-2 * c + 0.02, yb + 0.012), (-0.02, yb + 0.012), (-0.12, yt), (-2 * c + 0.12, yt)]
    box.decal(parent, "Kopf", top(T + 0.001), trap, head)
    for k in (1, 2, 3):
        a, b = trap[k], trap[(k + 1) % 4]
        seg(parent, "Kopfkante%d" % k, top(T + 0.0018), a[0], a[1], b[0], b[1], 0.01,
            glow(key, 1.2))
    box.rect(parent, "BandOeffnung", top(T + 0.0015), -2 * c + 0.08, yb + 0.018, -0.08,
             yb + 0.045, tape)
    for x in (-1.5 * c, -0.5 * c):
        box.dot(parent, "Antrieb%.2f" % x, top(T + 0.002), x, (yb + yt) * 0.5 + 0.02, 0.022,
                led.DARK)


def cassette_mikro(parent, key="material", cells=None):
    """MIKRO: hochkant, die Spulen flankieren den Stiel, das Band läuft am Fuß durch einen Schlitz."""
    c, T = NET, 0.14
    w, h = 3 * c + 0.14, 4 * c + 0.22
    y0 = h * 0.5 - 0.06 - 2 * c
    shell = led.mat("Mikroschale", (0.16, 0.16, 0.17), 0.3, 0.42, clearcoat=0.4)
    body = led.rounded_box(parent, "Gehaeuse", (w, h, T), (0, 0, T * 0.5), shell, 0.1, 0.02)
    led.rounded_box(parent, "Kappe", (w - 0.04, h * 0.3, 0.006), (0, h * 0.35, T + 0.001),
                    led.mat("Mikrokappe_" + key, col(key), 0.0, 0.4, 0.15), 0.08, 0.0)
    label = led.mat("Etikett", (0.012, 0.008, 0.014), 0.0, 0.6)
    led.rounded_box(parent, "Etikett", (w - 0.06, 4 * c + 0.04, 0.006), (0, y0, T + 0.004),
                    label, 0.07, 0.0)
    pos = grid_pos(CROSS, c, 0, y0)
    printed_net(parent, T + 0.007, key, cells or MAT_CELLS, pos, c)
    for s in (-1, 1):
        tape_reel(parent, "Spule%d" % s, s * c, y0 - c, c * 0.42, T + 0.007, key,
                  0.95 if s < 0 else 0.6)
    tl, tr = grid_pos([(0, 0), (2, 0)], c, 0, y0)
    box.text(parent, "MAT", top(T + 0.007), tl[0], tl[1], 0.07, glow(key, 1.3), "Sorte")
    box.text(parent, "MC-30", top(T + 0.007), tr[0], tr[1], 0.045, glow(key, 0.8), "Typ")
    # Der SCHLITZ am Fuß mit Band und zwei Andruckrollen.
    yb = -h * 0.5 + 0.07
    slot = led.rounded_box(parent, "Schlitz", (w - 0.18, 0.06, 0.2), (0, yb, T), shell, 0.02, 0.0)
    led.cut(body, slot)
    led.rounded_box(parent, "Bandlauf", (w - 0.2, 0.012, T * 0.4), (0, yb - 0.012, T * 0.5),
                    led.mat("Band", (0.05, 0.03, 0.022), 0.5, 0.25, clearcoat=0.6), 0.0, 0.0)
    for s in (-1, 1):
        cyl(parent, "Rolle%d" % s, 0.022, T * 0.7, (s * 0.36, yb, T * 0.5),
            led.mat("Chrom2", (0.9, 0.9, 0.92), 1.0, 0.05), 20)


# --- ZAHLEN, ganz alte Schule: die LOCHKARTE ---------------------------------------------

def punch_card(parent, key="zahl", vals=("+3", "+1", "+2", "+1", "+4", "")):
    c, T = NET, 0.012
    w, h = 4 * c + 0.5, 3 * c + 0.2
    stock = led.mat("Karton", (0.74, 0.64, 0.44), 0.0, 0.85)
    card = led.rounded_box(parent, "Lochkarte", (w, h, T), (0, 0, T * 0.5), stock, 0.025, 0.0)
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(-w * 0.5, h * 0.5, 0),
                                    rotation=(0, 0, math.radians(45)))
    corner = bpy.context.active_object
    corner.parent = parent
    led.cut(card, corner)
    ink = led.mat("Tinte_" + key, tuple(v * 0.45 for v in col(key)), 0.0, 0.6, 0.6)
    faint = led.mat("Graudruck", (0.2, 0.16, 0.1), 0.0, 0.8)
    hole = led.mat("Stanzloch", (0.012, 0.008, 0.016), 0.0, 0.9)
    paper = led.mat("Zellpapier", (0.84, 0.76, 0.56), 0.0, 0.85)
    x0 = w * 0.5 - 0.08 - 2 * c
    pos = grid_pos(CROSS, c, x0, 0, horizontal=True)
    fr = top(T)
    inside = lambda x, y: any(abs(x - px) < c * 0.5 and abs(y - py) < c * 0.5 for px, py in pos)
    # Der Ziffernraster der Karte: zehn Zeilen 0-9 in jeder Spalte, dazu verstreute Stanzungen.
    cols = 26
    for i in range(cols):
        x = -w * 0.5 + 0.08 + i * (w - 0.16) / (cols - 1)
        for d in range(10):
            y = h * 0.5 - 0.12 - d * (h - 0.2) / 10.0
            if inside(x, y):
                continue
            if (i * 7 + d * 3) % 11 == 0:
                box.rect(parent, "Stanz%d_%d" % (i, d), fr, x - 0.011, y - 0.024, x + 0.011,
                         y + 0.024, hole)
            else:
                box.text(parent, str(d), fr, x, y, 0.045, faint, "Ziffer%d_%d" % (i, d))
    # Das NETZ: aufgedruckte Kästen, die Zahl in Tinte, je Wert ein Stanzloch.
    for i, (x, y) in enumerate(pos):
        box.rect(parent, "Zellgrund%d" % i, top(T + 0.0004), x - c * 0.46, y - c * 0.46,
                 x + c * 0.46, y + c * 0.46, paper)
        for k, (a0, b0, a1, b1) in enumerate(((-1, -1, 1, -1), (1, -1, 1, 1), (1, 1, -1, 1),
                                              (-1, 1, -1, -1))):
            s = c * 0.46
            seg(parent, "Zellrand%d_%d" % (i, k), top(T + 0.0008), x + a0 * s, y + b0 * s,
                x + a1 * s, y + b1 * s, 0.012, ink)
        v = vals[i]
        if not v:
            continue
        box.text(parent, v, top(T + 0.0008), x, y + c * 0.08, c * 0.42, ink, "Wert%d" % i)
        n = int(v[1:])
        for k in range(n):
            px = x + (k - (n - 1) * 0.5) * c * 0.16
            box.rect(parent, "Wertloch%d_%d" % (i, k), top(T + 0.0012), px - 0.012,
                     y - c * 0.3, px + 0.012, y - c * 0.2, hole)
    box.text(parent, "FUMBLE  ·  ZAHLEN", top(T + 0.0008), -w * 0.5 + 0.38, h * 0.5 - 0.05,
             0.04, ink, "Kopf")
    seg(parent, "Kopflinie", top(T + 0.0008), -w * 0.5 + 0.16, h * 0.5 - 0.08, w * 0.5 - 0.06,
        h * 0.5 - 0.08, 0.004, ink)


# --- SONDERBESTAND, neu: Spielmodul, EPROM, Dia -------------------------------------------

def cartridge(parent, key="gold", mode="repair"):
    """Das SPIELMODUL: Griffrillen oben, Etikett mit dem Netz, Platine mit Goldkontakten unten."""
    c, T = NET, 0.3
    w, h = 3 * c + 0.22, 4 * c + 0.34
    shell = led.mat("Modulgrau", (0.07, 0.07, 0.08), 0.0, 0.55, clearcoat=0.2)
    body = led.rounded_box(parent, "Gehaeuse", (w, h, T), (0, 0, T * 0.5), shell, 0.05, 0.02)
    yt = h * 0.5
    for k in range(5):
        groove = led.rounded_box(parent, "Rille%d" % k, (w - 0.2, 0.018, 0.04),
                                 (0, yt - 0.04 - k * 0.032, T), shell, 0.005, 0.0)
        led.cut(body, groove)
    notch = led.rounded_box(parent, "Kerbe", (0.18, 0.08, T * 3), (0, yt, T * 0.5), shell, 0.03,
                            0.0)
    led.cut(body, notch)
    for s in (-1, 1):
        led.rounded_box(parent, "Zierlinie%d" % s, (0.012, h * 0.7, 0.012),
                        (s * (w * 0.5 + 0.002), -0.05, T * 0.6), glow(key, 1.6), 0.0, 0.0)
    y0 = yt - 0.22 - 2 * c
    led.rounded_box(parent, "Etikettmulde", (3 * c + 0.1, 4 * c + 0.1, 0.02),
                    (0, y0, T - 0.005), led.mat("Mulde", (0.03, 0.03, 0.035), 0.0, 0.5), 0.03,
                    0.0)
    led.rounded_box(parent, "Etikett", (3 * c + 0.06, 4 * c + 0.06, 0.006), (0, y0, T + 0.004),
                    led.mat("Modulglanz", (0.004, 0.004, 0.006), 0.0, 0.08, clearcoat=1.0),
                    0.02, 0.0)
    effect_net(parent, T + 0.008, key, mode, 0, y0)
    pcb = led.mat("Platine", (0.01, 0.03, 0.02), 0.0, 0.4, clearcoat=0.6)
    gold = led.mat("Kontaktgold", (1.0, 0.72, 0.3), 1.0, 0.2)
    yb = -h * 0.5 - 0.05
    led.rounded_box(parent, "Platine", (w - 0.3, 0.12, 0.04), (0, yb, T * 0.35), pcb, 0.01, 0.0)
    for k in range(9):
        led.rounded_box(parent, "Finger%d" % k, (0.045, 0.09, 0.044),
                        (-0.32 + k * 0.08, yb - 0.01, T * 0.35), gold, 0.005, 0.0)


def eprom(parent, key="kuehl", mode="cool"):
    """Der EPROM: Keramik, zwei Beinreihen, Quarzfenster über dem Chip, Netz im Siebdruck."""
    c, T, lift = NET, 0.16, 0.07
    w, h = 3 * c + 0.16, 4 * c + 0.24
    ceramic = led.mat("Keramik", (0.035, 0.035, 0.04), 0.0, 0.62)
    body = led.rounded_box(parent, "Keramik", (w, h, T), (0, 0, lift + T * 0.5), ceramic, 0.02,
                           0.012)
    zt = lift + T
    notch = cyl(parent, "Kerbe", 0.07, 0.4, (0, h * 0.5, zt), ceramic, 32)
    led.cut(body, notch)
    tin = led.mat("Zinn", (0.75, 0.76, 0.78), 1.0, 0.25)
    pins = 14
    for s in (-1, 1):
        for k in range(pins):
            y = (k - (pins - 1) * 0.5) * (h - 0.16) / (pins - 1)
            led.rounded_box(parent, "Bein%d_%d" % (s, k), (0.1, 0.05, 0.02),
                            (s * (w * 0.5 + 0.04), y, lift + T * 0.4), tin, 0.004, 0.0)
            led.rounded_box(parent, "Fuss%d_%d" % (s, k), (0.02, 0.05, lift + T * 0.4),
                            (s * (w * 0.5 + 0.09), y, (lift + T * 0.4) * 0.5), tin, 0.004, 0.0)
    y0 = 0.0
    effect_net(parent, zt, key, mode, 0, y0)
    wx, wy = -c, y0 - c
    gold = led.mat("Fenstergold", (1.0, 0.75, 0.35), 1.0, 0.2)
    annulus(parent, "Fensterrand", wx, wy, zt + 0.001, 0.13, 0.155, gold, 48)
    disc = cyl(parent, "Fenstergrund", 0.13, 0.004, (wx, wy, zt + 0.0005), led.DARK, 48)
    led.rounded_box(parent, "Chip", (0.11, 0.11, 0.004), (wx, wy, zt + 0.003),
                    led.mat("Silizium", (0.35, 0.3, 0.45), 1.0, 0.2), 0.0, 0.0)
    dots(parent, "Chipstruktur", [(wx - 0.045 + i * 0.015, wy - 0.045 + j * 0.015, zt + 0.006)
                                  for i in range(7) for j in range(7) if (i + j) % 2],
         0.003, glow(key, 1.4))
    cyl(parent, "Quarz", 0.13, 0.006, (wx, wy, zt + 0.006),
        led.mat("Quarzfenster", (0.85, 0.9, 1.0), 0.0, 0.02, 0.0, 0.12), 48)
    tx, ty = c, y0 - c
    box.text(parent, "27C-K", top(zt), tx, ty + 0.06, 0.05, glow(key, 1.0), "Typ")
    box.text(parent, "KÜHL", top(zt), tx, ty - 0.02, 0.06, glow(key, 1.4), "Sorte")
    box.text(parent, "-12", top(zt), tx, ty - 0.1, 0.04, glow(key, 0.7), "Takt")
    box.dot(parent, "Pin1", top(zt), -c, y0 + 1.5 * c, 0.02, glow(key, 1.2))


def slide(parent, key="rohling", mode="blank"):
    """Das DIA: Kunststoff-Rähmchen, auf dem Film leuchtet das Netz als Positiv."""
    c, T = NET, 0.06
    iw, ih = 3 * c + 0.08, 4 * c + 0.08
    w, h = iw + 0.32, ih + 0.3
    frame = led.mat("Rahmchen", (0.62, 0.64, 0.66), 0.0, 0.55)
    led.frame_ring(parent, "Rahmen", (w, h), (iw, ih), T * 0.5, T, frame, 0.03, 0.0)
    led.frame_ring(parent, "Innenkante", (iw + 0.03, ih + 0.03), (iw, ih), T + 0.001, 0.004,
                   glow(key, 1.4), 0.02, 0.0)
    film = led.mat("Film", (0.01, 0.015, 0.025), 0.0, 0.15, 0.0, 0.9)
    led.rounded_box(parent, "Film", (iw + 0.02, ih + 0.02, 0.003), (0, 0, T * 0.5), film, 0.0,
                    0.0)
    effect_net(parent, T * 0.5 + 0.002, key, mode)
    ink = led.mat("Rahmendruck", (0.12, 0.13, 0.15), 0.0, 0.6)
    box.text(parent, "SONDERBESTAND", top(T), 0, h * 0.5 - 0.08, 0.05, ink, "Kopf")
    box.text(parent, "Nr. 07", top(T), 0, -h * 0.5 + 0.08, 0.05, ink, "Nummer")
    box.dot(parent, "Marke", top(T), -w * 0.5 + 0.08, h * 0.5 - 0.08, 0.025, glow(key, 1.6))


# === Runde 5 (2026-11-18): drei Lochkarten =====================================================

ZAHL_VALS = ("+3", "+1", "+2", "+1", "+4", "")


def hole_cutter(parent, name, shapes, z0=-0.1, z1=0.1):
    """Alle Stanzungen einer Karte in EINEM Schneidkörper: ('rect', x0, y0, x1, y1) oder
    ('rund', x, y, r)."""
    verts, faces = [], []
    for sh in shapes:
        if sh[0] == "rect":
            _, a0, b0, a1, b1 = sh
            ring = [(a0, b0), (a1, b0), (a1, b1), (a0, b1)]
        else:
            _, x, y, r = sh
            ring = [(x + math.cos(math.tau * i / 12) * r, y + math.sin(math.tau * i / 12) * r)
                    for i in range(12)]
        k, n = len(verts), len(ring)
        verts += [(a, b, z0) for a, b in ring] + [(a, b, z1) for a, b in ring]
        faces.append(list(range(k + n - 1, k - 1, -1)))
        faces.append(list(range(k + n, k + 2 * n)))
        for i in range(n):
            j = (i + 1) % n
            faces.append([k + i, k + j, k + n + j, k + n + i])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    return o


def card_stock(parent, name, w, h, color, corner="tl", T=0.012, cut=0.3):
    stock = led.mat("Karton_" + name, color, 0.0, 0.85)
    card = led.rounded_box(parent, name, (w, h, T), (0, 0, T * 0.5), stock, 0.025, 0.0)
    if corner:
        sx = -1 if corner[1] == "l" else 1
        bpy.ops.mesh.primitive_cube_add(size=cut, location=(sx * w * 0.5, h * 0.5, 0),
                                        rotation=(0, 0, math.radians(45)))
        cut_obj = bpy.context.active_object
        cut_obj.parent = parent
        led.cut(card, cut_obj)
    return card


def box_outline(parent, name, fr, x, y, half, w, material):
    for k, (a0, b0, a1, b1) in enumerate(((-1, -1, 1, -1), (1, -1, 1, 1), (1, 1, -1, 1),
                                          (-1, 1, -1, -1))):
        seg(parent, "%s%d" % (name, k), fr, x + a0 * half, y + b0 * half, x + a1 * half,
            y + b1 * half, w, material)


def value_holes(shapes, x, y, c, v):
    n = int(v[1:]) if v else 0
    for k in range(n):
        px = x + (k - (n - 1) * 0.5) * c * 0.16
        shapes.append(("rect", px - 0.012, y - c * 0.33, px + 0.012, y - c * 0.21))


def punch_klassik(parent, key="zahl", vals=ZAHL_VALS):
    """KLASSIK: Manila mit Farbstreifen, Spaltenziffern, echte Rechteck-Stanzungen."""
    c, T = NET, 0.012
    w, h = 4 * c + 0.5, 3 * c + 0.24
    card = card_stock(parent, "Klassik", w, h, (0.8, 0.71, 0.5))
    black = led.mat("Schwarzdruck", (0.03, 0.03, 0.035), 0.0, 0.7)
    faint = led.mat("Graudruck", (0.24, 0.2, 0.13), 0.0, 0.8)
    stripe = led.mat("Streifen_" + key, tuple(v * 0.55 for v in col(key)), 0.0, 0.6, 0.3)
    fr = top(T)
    box.rect(parent, "Streifen", fr, -w * 0.5 + 0.22, h * 0.5 - 0.075, w * 0.5 - 0.02,
             h * 0.5 - 0.02, stripe)
    box.text(parent, "FUMBLE   ZAHLEN-KARTE   80 SPALTEN", top(T + 0.0004), 0.1, h * 0.5 - 0.048,
             0.035, led.mat("Streifenschrift", (0.9, 0.95, 0.88), 0.0, 0.6), "Kopf")
    x0, y0 = w * 0.5 - 0.06 - 2 * c, -0.035
    pos = grid_pos(CROSS, c, x0, y0, horizontal=True)
    inside = lambda x, y: any(abs(x - px) < c * 0.52 and abs(y - py) < c * 0.52 for px, py in pos)
    shapes = []
    cols = 26
    for i in range(cols):
        x = -w * 0.5 + 0.08 + i * (w - 0.16) / (cols - 1)
        for d in range(10):
            y = h * 0.5 - 0.12 - d * (h - 0.22) / 10.0
            if inside(x, y):
                continue
            if (i * 7 + d * 3) % 11 == 0:
                shapes.append(("rect", x - 0.011, y - 0.022, x + 0.011, y + 0.022))
            else:
                box.text(parent, str(d), fr, x, y, 0.042, faint, "Ziffer%d_%d" % (i, d))
        box.text(parent, str(i + 1), fr, x, -h * 0.5 + 0.035, 0.026, faint, "Spalte%d" % i)
    for i, (x, y) in enumerate(pos):
        box_outline(parent, "Zellrand%d_" % i, top(T + 0.0006), x, y, c * 0.46, 0.008, black)
        if vals[i]:
            box.text(parent, vals[i], top(T + 0.0006), x, y + c * 0.08, c * 0.42, black,
                     "Wert%d" % i)
            value_holes(shapes, x, y, c, vals[i])
    led.cut(card, hole_cutter(parent, "Stanzungen", shapes))


def punch_randloch(parent, key="zahl", vals=ZAHL_VALS):
    """RANDLOCH: hochkant, ringsum ein Lochkranz, manche Löcher zum Rand hin aufgeschlitzt."""
    c, T = NET, 0.014
    w, h = 3 * c + 0.34, 4 * c + 0.34
    card = card_stock(parent, "Randloch", w, h, (0.86, 0.84, 0.77), "tr", T)
    ink = led.mat("Tinte_" + key, tuple(v * 0.45 for v in col(key)), 0.0, 0.6, 0.6)
    shapes, slots = [], []
    inset, pitch, r = 0.06, 0.068, 0.018
    edges = []
    nx, ny = int((w - 0.2) / pitch), int((h - 0.2) / pitch)
    for k in range(nx + 1):
        x = -(nx * pitch) * 0.5 + k * pitch
        edges += [(x, h * 0.5 - inset, 0, 1), (x, -h * 0.5 + inset, 0, -1)]
    for k in range(ny + 1):
        y = -(ny * pitch) * 0.5 + k * pitch
        edges += [(-w * 0.5 + inset, y, -1, 0), (w * 0.5 - inset, y, 1, 0)]
    for i, (x, y, dx, dy) in enumerate(edges):
        if dx > 0 and y > h * 0.5 - 0.2:
            continue
        shapes.append(("rund", x, y, r))
        if (i * 5) % 7 < 2:
            if dx:
                slots.append(("rect", min(x, x + dx * 0.2), y - r * 0.9, max(x, x + dx * 0.2),
                              y + r * 0.9))
            else:
                slots.append(("rect", x - r * 0.9, min(y, y + dy * 0.2), x + r * 0.9,
                              max(y, y + dy * 0.2)))
    seg_y = h * 0.5 - 0.12
    seg(parent, "Randlinie", top(T), -w * 0.5 + 0.11, seg_y, w * 0.5 - 0.2, seg_y, 0.004, ink)
    pos = grid_pos(CROSS, c, 0, -0.02)
    for i, (x, y) in enumerate(pos):
        box_outline(parent, "Zellrand%d_" % i, top(T + 0.0006), x, y, c * 0.46, 0.012, ink)
        if vals[i]:
            box.text(parent, vals[i], top(T + 0.0006), x, y + c * 0.08, c * 0.44, ink,
                     "Wert%d" % i)
            value_holes(shapes, x, y, c, vals[i])
    tl, tr = grid_pos([(0, 0), (2, 0)], c, 0, -0.02)
    box.text(parent, "ZAHLEN", top(T + 0.0006), tl[0], tl[1] + 0.02, 0.06, ink, "Sorte")
    box.text(parent, "Nr. 12", top(T + 0.0006), tr[0], tr[1] + 0.02, 0.05, ink, "Nummer")
    led.cut(card, hole_cutter(parent, "Stanzungen", shapes))
    led.cut(card, hole_cutter(parent, "Schlitze", slots))


GLYPHS = {"+": ["...", ".#.", "###", ".#.", "..."], "1": [".#.", "##.", ".#.", ".#.", "###"],
          "2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", ".#.", "..#", "##."],
          "4": ["#.#", "#.#", "###", "..#", "..#"]}


def punch_matrix(parent, key="zahl", vals=ZAHL_VALS):
    """MATRIX: jede Zelle ein Feld vorgestanzter Plättchen - die Zahl IST ausgestanzt."""
    c, T = NET, 0.012
    w, h = 4 * c + 0.3, 3 * c + 0.24
    card = card_stock(parent, "Matrix", w, h, (0.58, 0.7, 0.58))
    ink = led.mat("Gruendruck", (0.03, 0.12, 0.05), 0.0, 0.7)
    chad = led.mat("Plaettchen", (0.42, 0.53, 0.42), 0.0, 0.8)
    x0, y0 = w * 0.5 - 0.06 - 2 * c, -0.035
    pos = grid_pos(CROSS, c, x0, y0, horizontal=True)
    shapes = []
    p, r = 0.042, 0.013
    for i, (x, y) in enumerate(pos):
        box_outline(parent, "Zellrand%d_" % i, top(T + 0.0006), x, y, c * 0.46, 0.01, ink)
        text = vals[i] or "  "
        for gx in range(7):
            for gy in range(5):
                px, py = x + (gx - 3) * p, y + (2 - gy) * p
                ch = text[gx // 4] if gx != 3 else " "
                on = ch in GLYPHS and GLYPHS[ch][gy][gx % 4] == "#"
                if on:
                    shapes.append(("rund", px, py, r))
                else:
                    annulus(parent, "Plaettchen%d_%d_%d" % (i, gx, gy), px, py, T + 0.0004,
                            r * 0.8, r, chad, 16)
    box.text(parent, "FUMBLE · ZAHLEN · MATRIX", top(T + 0.0006), -0.2, h * 0.5 - 0.06, 0.045,
             ink, "Kopf")
    for k in range(12):
        x = -w * 0.5 + 0.08 + k * 0.05
        seg(parent, "Takt%d" % k, top(T + 0.0006), x, -h * 0.5 + 0.04, x, -h * 0.5 + 0.08, 0.012,
            ink)
    seg(parent, "Kopflinie", top(T + 0.0006), -w * 0.5 + 0.18, h * 0.5 - 0.1, w * 0.5 - 0.04,
        h * 0.5 - 0.1, 0.004, ink)
    led.cut(card, hole_cutter(parent, "Stanzungen", shapes))


# === Runde 6 (2026-11-18): drei Spielarten der KLASSIK-Lochkarte ==================================

def klassik_card(parent, name, vals, stock, ink, faint, stripe, stripe_ink, cell_fill=None,
                 ladder=False, stub=False, backlight=None, trim=False):
    c, T = NET, 0.012
    # Getrimmt: die Karte ist so breit wie das Netz plus Saum, kein Leerfeld links.
    w, h = (4 * c + 0.12, 3 * c + 0.2) if trim else (4 * c + 0.5, 3 * c + 0.24)
    card = card_stock(parent, name, w, h, stock, cut=0.22 if trim else 0.3)
    edge, s0 = (0.06, 0.17) if trim else (0.08, 0.22)
    if backlight:
        e = 0.015
        box.decal(parent, "Hinterlicht", top(-0.002),
                  [(-w * 0.5 + 0.25, h * 0.5 - e), (w * 0.5 - e, h * 0.5 - e),
                   (w * 0.5 - e, -h * 0.5 + e), (-w * 0.5 + e, -h * 0.5 + e),
                   (-w * 0.5 + e, h * 0.5 - 0.25)], backlight)
    fr = top(T)
    xs = w * 0.5 - 0.3 if stub else w * 0.5
    box.rect(parent, "Streifen", fr, -w * 0.5 + s0, h * 0.5 - 0.075, xs - 0.02, h * 0.5 - 0.02,
             stripe)
    box.text(parent, "FUMBLE   ZAHLEN-KARTE   80 SPALTEN", top(T + 0.0004),
             (-w * 0.5 + s0 + xs - 0.02) * 0.5, h * 0.5 - 0.048, 0.035, stripe_ink, "Kopf")
    x0, y0 = (0.0 if trim else xs - 0.06 - 2 * c), -0.035
    pos = grid_pos(CROSS, c, x0, y0, horizontal=True)
    inside = lambda x, y: any(abs(x - px) < c * 0.52 and abs(y - py) < c * 0.52 for px, py in pos)
    shapes, fills = [], []
    cols = 21 if trim else (26 if not stub else 22)
    for i in range(cols):
        x = -w * 0.5 + edge + i * (xs - edge - (-w * 0.5 + edge)) / (cols - 1)
        for d in range(10):
            y = h * 0.5 - 0.12 - d * (h - 0.22) / 10.0
            if inside(x, y):
                continue
            if (i * 7 + d * 3) % 11 == 0:
                shapes.append(("rect", x - 0.011, y - 0.022, x + 0.011, y + 0.022))
            else:
                box.text(parent, str(d), fr, x, y, 0.042, faint, "Ziffer%d_%d" % (i, d))
        box.text(parent, str(i + 1), fr, x, -h * 0.5 + 0.035, 0.026, faint, "Spalte%d" % i)
    for i, (x, y) in enumerate(pos):
        if cell_fill:
            fills.append(led.rounded_box(parent, "Zellgrund%d" % i, (c * 0.92, c * 0.92, 0.0008),
                                         (x, y, T + 0.0004), cell_fill, 0.0, 0.0))
        box_outline(parent, "Zellrand%d_" % i, top(T + 0.0006), x, y, c * 0.46, 0.008, ink)
        v = vals[i]
        if not v:
            continue
        if ladder:
            # Die Ziffernleiter der Spalte: der Wert ist an seiner Ziffer ausgestanzt.
            box.text(parent, v, top(T + 0.0006), x, y + c * 0.1, c * 0.4, ink, "Wert%d" % i)
            n = int(v[1:])
            for d in range(10):
                px, py = x + (d - 4.5) * c * 0.084, y - c * 0.3
                if d == n:
                    shapes.append(("rect", px - 0.01, py - 0.02, px + 0.01, py + 0.02))
                else:
                    box.text(parent, str(d), top(T + 0.0006), px, py, 0.03, faint,
                             "Leiter%d_%d" % (i, d))
        else:
            box.text(parent, v, top(T + 0.0006), x, y + c * 0.08, c * 0.42, ink, "Wert%d" % i)
            value_holes(shapes, x, y, c, v)
    if stub:
        perf = []
        n = int((h - 0.08) / 0.032)
        for k in range(n + 1):
            perf.append(("rund", xs, -h * 0.5 + 0.04 + k * 0.032, 0.007))
        led.cut(card, hole_cutter(parent, "Perforation", perf))
        side = box.frame((0, 0, T + 0.0006), (0, 1, 0), (-1, 0, 0))
        sx = xs + 0.15
        box.text(parent, "ZAHLEN", side, 0.12, -sx - 0.05, 0.07, ink, "Abrissorte")
        box.text(parent, "Nr. 0423", side, 0.12, -sx + 0.05, 0.045, ink, "Abrissnummer")
        box.rect(parent, "Abrissstreifen", fr, xs + 0.03, -h * 0.5 + 0.03, w * 0.5 - 0.03,
                 -h * 0.5 + 0.09, stripe)
        box.text(parent, "BEHALTEN", top(T + 0.0004), sx, -h * 0.5 + 0.06, 0.03, stripe_ink,
                 "Abrissfuss")
    cutter = hole_cutter(parent, "Stanzungen", shapes)
    for o in [card] + fills:
        led.cut(o, cutter)


def klassik_farbe(parent, key="zahl", vals=ZAHL_VALS):
    """FARBKARTE: grün getönter Karton, die Zellen als weiße Papierfelder."""
    klassik_card(parent, "Farbkarte", vals, (0.6, 0.73, 0.54),
                 led.mat("Schwarzdruck", (0.03, 0.03, 0.035), 0.0, 0.7),
                 led.mat("Gruengrau", (0.17, 0.26, 0.15), 0.0, 0.8),
                 led.mat("Dunkelstreifen", tuple(v * 0.3 for v in col(key)), 0.0, 0.6, 0.1),
                 led.mat("Streifenschrift", (0.9, 0.95, 0.88), 0.0, 0.6),
                 cell_fill=led.mat("Papierfeld", (0.93, 0.91, 0.85), 0.0, 0.8))


def klassik_abriss(parent, key="zahl", vals=ZAHL_VALS):
    """ABRISS: Manila, Perforation mit Abrissstreifen, der Wert in der Ziffernleiter gestanzt."""
    klassik_card(parent, "Abriss", vals, (0.8, 0.71, 0.5),
                 led.mat("Schwarzdruck", (0.03, 0.03, 0.035), 0.0, 0.7),
                 led.mat("Graudruck", (0.24, 0.2, 0.13), 0.0, 0.8),
                 led.mat("Streifen_" + key, tuple(v * 0.55 for v in col(key)), 0.0, 0.6, 0.3),
                 led.mat("Streifenschrift", (0.9, 0.95, 0.88), 0.0, 0.6),
                 ladder=True, stub=True)


def klassik_neon(parent, key="zahl", vals=ZAHL_VALS, trim=True):
    """NEON: schwarzer Karton, Druck in Sortenfarbe, durch die Stanzungen scheint Licht."""
    klassik_card(parent, "Neonkarte", vals, (0.03, 0.03, 0.036), glow(key, 2.0),
                 led.mat("Neonziffer", col(key), 0.0, 0.6, 0.12), glow(key, 1.1),
                 led.mat("Neonschrift", (0.01, 0.02, 0.012), 0.0, 0.6),
                 backlight=glow(key, 5.0), trim=trim)


# === Runde 7 (2026-11-18): Runen als moderne Altform, futuristischer Sonderbestand ==============

def bumpy(name, color, rough, scale=40.0, strength=0.25, metal=0.0, clearcoat=0.0):
    """Ein Material mit Rauschen in der Normalen - Stein, Ton, gehämmertes Gold."""
    m = led.mat(name, color, metal, rough, clearcoat=clearcoat)
    nt = m.node_tree
    if "Rauschen" in nt.nodes:
        return m
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.name = "Rauschen"
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 8.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], nt.nodes["Principled BSDF"].inputs["Normal"])
    return m


def rune_glyph(parent, name, fr, x, y, s, idx, w, material, ang=0.0):
    ca, sa = math.cos(ang), math.sin(ang)
    for k, (a0, b0, a1, b1) in enumerate(RUNES[idx % len(RUNES)]):
        p0 = (a0 * ca - b0 * sa, a0 * sa + b0 * ca)
        p1 = (a1 * ca - b1 * sa, a1 * sa + b1 * ca)
        seg(parent, "%s_%d" % (name, k), fr, x + p0[0] * s, y + p0[1] * s, x + p1[0] * s,
            y + p1[1] * s, w, material)


def wire_frame(parent, name, x, y, half, z, t, height, material):
    for k, (dx, dy, sx, sy) in enumerate(((0, 1, 2, 0), (0, -1, 2, 0), (1, 0, 0, 2),
                                          (-1, 0, 0, 2))):
        size = (half * 2 + t if sx else t, half * 2 + t if sy else t, height)
        led.rounded_box(parent, "%s%d" % (name, k), size, (x + dx * half, y + dy * half,
                                                           z + height * 0.5), material, 0.0, 0.0)


RUNE_GLYPHS = (0, 1, 2, 3, 4, 5)


def runestone(parent, key="rune"):
    """RUNENSTEIN: Basalt mit gefräster, polierter Deckfläche; die Zellen eingetieft, die Runen
    leuchten aus dem Grund; Messingband mit Kontakten am Fuß."""
    c, T = NET, 0.2
    w, h = 3 * c + 0.16, 4 * c + 0.3
    y0 = 0.07
    basalt = bumpy("Basalt", (0.035, 0.034, 0.038), 0.8, 30.0, 0.5)
    body = led.chamfer_box(parent, "Stein", (w, h, T), (0, 0, T * 0.5), basalt, 0.05, 0.025)
    polish = led.mat("Politur", (0.012, 0.012, 0.014), 0.0, 0.08, clearcoat=1.0)
    plate = led.rounded_box(parent, "Deckflaeche", (w - 0.07, h - 0.07, 0.006),
                            (0, 0, T + 0.002), polish, 0.03, 0.0)
    pos = grid_pos(CROSS, c, 0, y0)
    deep = 0.03
    cutter = hole_cutter(parent, "Ritzung", [("rect", x - c * 0.42, y - c * 0.42, x + c * 0.42,
                                               y + c * 0.42) for x, y in pos],
                         T - deep, T + 0.1)
    led.cut(body, cutter)
    led.cut(plate, cutter)
    brass = led.mat("Messing", (0.85, 0.62, 0.3), 1.0, 0.25)
    for i, (x, y) in enumerate(pos):
        rune_glyph(parent, "Rune%d" % i, top(T - deep), x, y, c * 0.3, RUNE_GLYPHS[i], c * 0.06,
                   glow(key, 3.0))
        box_outline(parent, "Messingrand%d_" % i, top(T + 0.005), x, y, c * 0.45, 0.012, brass)
    for k, (x, y) in enumerate(grid_pos([(0, 0), (2, 0)], c, 0, y0)):
        for j in range(3):
            rune_glyph(parent, "Zier%d_%d" % (k, j), top(T + 0.005), x - 0.09 + j * 0.09, y,
                       0.035, k * 3 + j, 0.008, glow(key, 0.7))
    led.rounded_box(parent, "Fussband", (w + 0.01, 0.12, T + 0.012), (0, -h * 0.5 + 0.07, T * 0.5),
                    brass, 0.02, 0.004)
    for k in range(8):
        led.rounded_box(parent, "Pad%d" % k, (0.07, 0.07, 0.004),
                        (-0.35 + k * 0.1, -h * 0.5 + 0.07, T + 0.008),
                        led.mat("Kontaktgold", (1.0, 0.72, 0.3), 1.0, 0.2), 0.008, 0.0)


def clay_tablet(parent, key="rune"):
    """TONTAFEL: gebrannter Ton, die Zellen als glasierte Kacheln, in den freien Feldern
    Keilschrift-Eindrücke; eine Stahlleiste am Rand trägt die Kontakte."""
    c, T = NET, 0.16
    w, h = 3 * c + 0.2, 4 * c + 0.2
    clay = bumpy("Ton", (0.5, 0.26, 0.15), 0.85, 25.0, 0.35)
    led.rounded_box(parent, "Tafel", (w, h, T), (0, 0, T * 0.5), clay, 0.1, 0.05)
    glaze = led.mat("Glasur", (0.01, 0.012, 0.02), 0.0, 0.06, clearcoat=1.0)
    pos = grid_pos(CROSS, c, 0, 0)
    for i, (x, y) in enumerate(pos):
        led.rounded_box(parent, "Kachel%d" % i, (c * 0.86, c * 0.86, 0.016), (x, y, T + 0.004),
                        glaze, c * 0.1, 0.004, 4)
        rune_glyph(parent, "Rune%d" % i, top(T + 0.0125), x, y, c * 0.3, RUNE_GLYPHS[i],
                   c * 0.06, glow(key, 2.6))
    wedge = led.mat("Keil", (0.2, 0.09, 0.05), 0.0, 0.9)
    for k, (x, y) in enumerate(grid_pos(FREE, c, 0, 0)):
        for r in range(4):
            for j in range(4):
                if (k + r * 3 + j) % 4 == 0:
                    continue
                px, py = x - c * 0.33 + j * c * 0.22, y + c * 0.3 - r * c * 0.2
                box.decal(parent, "Keil%d_%d_%d" % (k, r, j), top(T), [(px, py + 0.025),
                          (px + 0.05, py), (px, py - 0.025)], wedge)
    steel = led.mat("Stahlleiste", (0.62, 0.64, 0.68), 1.0, 0.3)
    led.rounded_box(parent, "Leiste", (0.06, h - 0.3, 0.02), (-w * 0.5 + 0.0, 0, T * 0.6), steel,
                    0.01, 0.004)
    for k in range(3):
        cyl(parent, "Lampe%d" % k, 0.012, 0.01, (-w * 0.5 - 0.02, -0.2 + k * 0.2, T * 0.6),
            glow(key, 3.0), 12).rotation_euler = (0, math.radians(90), 0)


def bracteate(parent, key="rune"):
    """BRAKTEAT: Goldmedaille, die Zellen in Zellenschmelz, ein Runenkranz am Rand, oben die Öse."""
    c, T = NET, 0.06
    R = 2.12 * c + 0.12
    gold = bumpy("Hammergold", (1.0, 0.74, 0.34), 0.28, 60.0, 0.08, 1.0)
    cyl(parent, "Scheibe", R, T, (0, 0, T * 0.5), gold, 128)
    bpy.ops.mesh.primitive_torus_add(major_radius=R - 0.02, minor_radius=0.025,
                                     location=(0, 0, T), major_segments=128)
    rim = bpy.context.active_object
    rim.name = "Wulst"
    rim.data.materials.append(gold)
    bpy.ops.object.shade_smooth()
    rim.parent = parent
    bpy.ops.mesh.primitive_torus_add(major_radius=0.1, minor_radius=0.03,
                                     location=(0, R + 0.07, T * 0.5))
    bail = bpy.context.active_object
    bail.name = "Oese"
    bail.data.materials.append(gold)
    bpy.ops.object.shade_smooth()
    bail.parent = parent
    enamel = led.mat("Schmelz", (0.02, 0.03, 0.08), 0.0, 0.08, clearcoat=1.0)
    pos = grid_pos(CROSS, c, 0, 0)
    for i, (x, y) in enumerate(pos):
        led.rounded_box(parent, "Schmelz%d" % i, (c * 0.9, c * 0.9, 0.008), (x, y, T + 0.004),
                        enamel, 0.0, 0.0)
        wire_frame(parent, "Draht%d_" % i, x, y, c * 0.46, T, 0.014, 0.014, gold)
        rune_glyph(parent, "Rune%d" % i, top(T + 0.0085), x, y, c * 0.3, RUNE_GLYPHS[i],
                   c * 0.06, glow(key, 2.6))
    n = 30
    for k in range(n):
        t = math.tau * k / n + math.pi * 0.5
        rr = R - 0.075
        rune_glyph(parent, "Kranz%d" % k, top(T + 0.001), math.cos(t) * rr, math.sin(t) * rr,
                   0.028, k, 0.008, led.mat("Kranzgravur", (0.35, 0.2, 0.06), 0.8, 0.5),
                   t - math.pi * 0.5)


# --- SONDERBESTAND, futuristisch ---------------------------------------------------------

def crystal(parent, key="kuehl", mode="cool"):
    """DATENKRISTALL: facettierte Glasplatte mit leuchtendem Kern; das Netz auf der Tafel."""
    c, T = NET, 0.22
    w, h = 3 * c + 0.2, 4 * c + 0.2
    glass = led.mat("Kristall_" + key, tuple(0.55 + 0.45 * v for v in col(key)), 0.0, 0.02, 0.05,
                    0.2)
    body = led.rounded_box(parent, "Kristall", (w, h, T), (0, 0, T * 0.5), glass, 0.24, 0.0, 1)
    facet = body.modifiers.new("Facette", "BEVEL")
    facet.limit_method = "ANGLE"
    facet.angle_limit = math.radians(60)
    facet.width = 0.07
    facet.segments = 1
    body.data.use_auto_smooth = True
    body.data.auto_smooth_angle = math.radians(20)
    core = led.mat("Kristallkern_" + key, col(key), 0.0, 0.3, 0.3, 0.25)
    led.rounded_box(parent, "Kern", (w - 0.34, h - 0.34, 0.04), (0, 0, T * 0.4), core, 0.14, 0.0,
                    1)
    effect_net(parent, T + 0.002, key, mode)
    for sx in (-1, 1):
        for sy in (-1, 1):
            dots(parent, "Funke%d%d" % (sx, sy), [(sx * (w * 0.5 - 0.12), sy * (h * 0.5 - 0.12),
                                                   T * 0.6)], 0.018, glow(key, 4.0))


def holo_emitter(parent, key="rohling", mode="blank"):
    """HOLO-EMITTER: flacher Sockel mit Linsenfeld; das Netz SCHWEBT als Projektion darüber."""
    c, T = NET, 0.07
    w, h = 3 * c + 0.2, 4 * c + 0.2
    base = led.mat("Emitter", (0.02, 0.022, 0.028), 0.8, 0.25, clearcoat=0.8)
    led.rounded_box(parent, "Sockel", (w, h, T), (0, 0, T * 0.5), base, 0.12, 0.02)
    led.frame_ring(parent, "Rand", (w + 0.006, h + 0.006), (w - 0.03, h - 0.03), T * 0.6, 0.012,
                   glow(key, 2.0), 0.12, 0.0)
    lens = led.mat("Linse", (0.03, 0.05, 0.07), 0.0, 0.05, clearcoat=1.0)
    led.rounded_box(parent, "Linse", (3 * c + 0.06, 4 * c + 0.06, 0.004), (0, 0, T + 0.002), lens,
                    0.06, 0.0)
    pts = [(-1.5 * c + i * 0.06, -2 * c + j * 0.06, T + 0.006)
           for i in range(int(3 * c / 0.06) + 1) for j in range(int(4 * c / 0.06) + 1)]
    dots(parent, "Emitterpunkte", pts, 0.005, glow(key, 1.2))
    zh = T + 0.26
    effect_net(parent, zh, key, mode)
    led.rounded_box(parent, "Lichtkegel", (3 * c + 0.04, 4 * c + 0.04, zh - T - 0.01),
                    (0, 0, (zh + T) * 0.5), led.mat("Kegel_" + key, col(key), 0.0, 0.5, 0.15, 0.02),
                    0.04, 0.0)
    scan = glow(key, 0.6)
    for k in range(16):
        y = -2 * c + k * 4 * c / 15
        seg(parent, "Zeile%d" % k, top(zh - 0.0015), -1.5 * c, y, 1.5 * c, y, 0.003, scan)


def plasma_capsule(parent, key="gold", mode="repair"):
    """PLASMA-KAPSEL: Perlmutt-Schale, darin ein glimmender Kern unter einer Glaskuppel."""
    c, T = NET, 0.24
    w, h = 3 * c + 0.24, 4 * c + 0.26
    pearl = led.mat("Perlmutt", (0.82, 0.83, 0.88), 0.2, 0.18, clearcoat=1.0)
    led.rounded_box(parent, "Schale", (w, h, T * 0.5), (0, 0, T * 0.25), pearl, 0.5, 0.03)
    led.frame_ring(parent, "Naht", (w + 0.008, h + 0.008), (w - 0.03, h - 0.03), T * 0.5, 0.014,
                   glow(key, 2.2), 0.48, 0.0)
    core = led.mat("Plasma_" + key, tuple(v * 0.35 for v in col(key)), 0.0, 0.3, 0.12, 0.7)
    led.rounded_box(parent, "Kern", (w - 0.16, h - 0.16, 0.05), (0, 0, T * 0.55), core, 0.42, 0.02)
    import random
    rnd = random.Random(7)
    bubbles = [(rnd.uniform(-w * 0.35, w * 0.35), rnd.uniform(-h * 0.38, h * 0.38),
                rnd.uniform(T * 0.6, T * 0.85)) for _ in range(40)]
    dots(parent, "Blasen", bubbles, 0.012, glow(key, 2.5))
    dome = led.mat("Kuppel", (0.9, 0.92, 1.0), 0.0, 0.02, 0.0, 0.15)
    led.rounded_box(parent, "Kuppel", (w - 0.02, h - 0.02, T * 0.5), (0, 0, T * 0.75), dome, 0.49,
                    0.08)
    effect_net(parent, T + 0.002, key, mode)
    led.rounded_box(parent, "Kontakt", (0.34, 0.05, 0.02), (0, -h * 0.5 + 0.05, T * 0.5),
                    led.mat("Chrom2", (0.9, 0.9, 0.92), 1.0, 0.05), 0.01, 0.0)


# === Runde 8 (2026-11-18): Spielarten der HOLO-Projektion für den Sonderbestand ===============

def beam(parent, name, p0, p1, r, material):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=d.length,
                                        location=(p0 + p1) * 0.5)
    o = bpy.context.active_object
    o.name = name
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    o.data.materials.append(material)
    o.parent = parent
    return o


def holo_box_outline(parent, name, z, half_w, half_h, material, w=0.004):
    pts = [(-half_w, -half_h), (half_w, -half_h), (half_w, half_h), (-half_w, half_h)]
    for k in range(4):
        a, b = pts[k], pts[(k + 1) % 4]
        seg(parent, "%s%d" % (name, k), top(z), a[0], a[1], b[0], b[1], w, material)


def scanlines(parent, name, z, key, n=16, gain=0.6):
    c = NET
    for k in range(n):
        y = -2 * c + k * 4 * c / (n - 1)
        seg(parent, "%s%d" % (name, k), top(z - 0.0015), -1.5 * c, y, 1.5 * c, y, 0.003,
            glow(key, gain))


def holo_portal(parent, key="kuehl", mode="cool"):
    """PORTAL: offener Rahmen auf vier Eck-Emittern; ihre Strahlen spannen das schwebende Netz."""
    c, T = NET, 0.08
    w, h = 3 * c + 0.24, 4 * c + 0.24
    metal = led.mat("Portalmetall", (0.05, 0.055, 0.065), 0.9, 0.22, clearcoat=0.6)
    led.frame_ring(parent, "Rahmen", (w, h), (w - 0.14, h - 0.14), T * 0.5, T, metal, 0.06, 0.0)
    led.frame_ring(parent, "Innenlicht", (w - 0.13, h - 0.13), (w - 0.15, h - 0.15), T + 0.001,
                   0.004, glow(key, 2.4), 0.05, 0.0)
    zh, post_h = 0.3, 0.34
    tip = glow(key, 4.0)
    ray = led.mat("Strahl_" + key, col(key), 0.0, 0.4, 2.0, 0.5)
    for sx in (-1, 1):
        for sy in (-1, 1):
            px, py = sx * (w * 0.5 - 0.07), sy * (h * 0.5 - 0.07)
            cyl(parent, "Pfosten%d%d" % (sx, sy), 0.035, post_h, (px, py, post_h * 0.5), metal, 16)
            dots(parent, "Spitze%d%d" % (sx, sy), [(px, py, post_h + 0.01)], 0.03, tip)
            beam(parent, "Strahl%d%d" % (sx, sy), (px, py, post_h + 0.01),
                 (sx * 1.5 * c, sy * 2 * c, zh), 0.006, ray)
    holo_box_outline(parent, "Spannrahmen", zh, 1.5 * c, 2 * c, glow(key, 1.2))
    effect_net(parent, zh, key, mode)
    scanlines(parent, "Zeile", zh, key, 16, 0.4)


def holo_puck(parent, key="gold", mode="repair"):
    """PROJEKTOR-PUCK: ein kleiner Puck, sein Lichtkegel weitet sich zum vollen Netz."""
    c, T = NET, 0.12
    r = 0.34
    shell = led.mat("Puck", (0.03, 0.032, 0.04), 0.7, 0.25, clearcoat=0.8)
    cyl(parent, "Puck", r, T, (0, 0, T * 0.5), shell, 64)
    annulus(parent, "Puckring", 0, 0, T + 0.001, r - 0.04, r - 0.015, glow(key, 2.5), 64)
    cyl(parent, "Linse", 0.12, 0.01, (0, 0, T + 0.004),
        led.mat("Pucklinse", (0.05, 0.07, 0.1), 0.0, 0.03, clearcoat=1.0), 48)
    dots(parent, "Linsenkern", [(0, 0, T + 0.012)], 0.035, glow(key, 5.0))
    zh = 0.5
    hw, hh = 1.5 * c, 2 * c
    verts = [(-0.09, -0.09, T + 0.01), (0.09, -0.09, T + 0.01), (0.09, 0.09, T + 0.01),
             (-0.09, 0.09, T + 0.01), (-hw, -hh, zh), (hw, -hh, zh), (hw, hh, zh), (-hw, hh, zh)]
    faces = [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    mesh = bpy.data.meshes.new("Kegel")
    mesh.from_pydata(verts, [], faces)
    cone = bpy.data.objects.new("Kegel", mesh)
    bpy.context.collection.objects.link(cone)
    cone.data.materials.append(led.mat("Puckkegel_" + key, col(key), 0.0, 0.5, 0.25, 0.04))
    cone.parent = parent
    ray = led.mat("Puckstrahl_" + key, col(key), 0.0, 0.4, 1.5, 0.35)
    for k, (x, y) in enumerate(grid_pos(CROSS, c, 0, 0)):
        beam(parent, "Strahl%d" % k, (0, 0, T + 0.015), (x, y, zh), 0.003, ray)
    holo_box_outline(parent, "Rahmen", zh, hw, hh, glow(key, 0.8), 0.003)
    effect_net(parent, zh, key, mode)
    scanlines(parent, "Zeile", zh, key, 16, 0.4)


def holo_layers(parent, key="rohling", mode="blank"):
    """SCHICHTEN: Rauchglas auf schmalem Sockel; das Netz steht in drei Tiefen übereinander,
    unten blass, oben voll - eine Abtastlinie fährt hindurch."""
    c, T = NET, 0.05
    w, h = 3 * c + 0.16, 4 * c + 0.16
    metal = led.mat("Schichtsockel", (0.05, 0.055, 0.065), 0.9, 0.22, clearcoat=0.6)
    led.rounded_box(parent, "Sockel", (w, h, T), (0, 0, T * 0.5), metal, 0.05, 0.01)
    led.frame_ring(parent, "Sockellicht", (w + 0.006, h + 0.006), (w - 0.02, h - 0.02), T * 0.5,
                   0.01, glow(key, 2.0), 0.05, 0.0)
    smoke = led.mat("Rauchglas", (0.05, 0.07, 0.09), 0.0, 0.03, 0.0, 0.3)
    led.rounded_box(parent, "Glasblock", (w - 0.04, h - 0.04, 0.3), (0, 0, T + 0.15), smoke, 0.04,
                    0.01)
    for k, (z, g) in enumerate(((T + 0.08, 0.25), (T + 0.17, 0.5))):
        effect_net(parent, z, key, mode, gain=g, outline_only=True)
    zt = T + 0.3 + 0.002
    effect_net(parent, zt, key, mode)
    seg(parent, "Abtastung", top(T + 0.17), -w * 0.5 + 0.03, 0.15, w * 0.5 - 0.03, 0.15, 0.01,
        glow(key, 4.0))


# --- Bühne ------------------------------------------------------------------------------

MEDIA = [("ZAHLEN", cd, (-3.5, 1.0)), ("MATERIAL", cassette, (-1.3, 1.0)),
         ("RUNEN", glass_card, (0.6, 1.0)), ("SONDER", lambda p: service_key(p), (2.3, 1.0))]
VARIANTS = [("FAKTOR", cd_factor, (-2.6, -1.6)),
            ("KUEHL", lambda p: service_key(p, "kuehl", "cool"), (-0.3, -1.6)),
            ("ROHLING", lambda p: service_key(p, "rohling", "blank"), (1.4, -1.6))]


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
    aim.location = (-0.7, -0.45, 0)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 9.6
        cam.location = (-0.7, -0.45, 14)
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


ROUND4 = [("LOCHKARTE", punch_card, (-2.7, 0.95)), ("KOMPAKT", cassette_kompakt, (-0.6, 0.95)),
          ("MIKRO", cassette_mikro, (1.2, 0.95)), ("MODUL", cartridge, (-2.6, -1.2)),
          ("EPROM", eprom, (-0.6, -1.2)), ("DIA", slide, (1.3, -1.2))]


def view_round4(flat):
    cam, aim = empty_stage()
    for name, fn, (x, y) in ROUND4:
        build(fn, name, (x, y, 0.001))
    aim.location = (-0.75, -0.15, 0)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 8.4
        cam.location = (-0.75, -0.15, 14)
    else:
        cam.location = (1.6, -7.8, 6.8)
        cam.data.lens = 40


def view_hero_fn(i, dist):
    cam, aim = empty_stage()
    name, fn, _ = ROUND4[i]
    build(fn, name, (0, 0, 0.001))
    aim.location = (0, -0.05, 0.05)
    cam.location = Vector((0.55, -1.25, 1.1)) * dist
    cam.data.lens = 50


ROUND5 = [("KLASSIK", punch_klassik, (-1.2, 0.85)), ("MATRIX", punch_matrix, (1.0, 0.85)),
          ("RANDLOCH", punch_randloch, (-1.35, -1.0)), ("KOMPAKT", cassette_kompakt, (0.9, -0.85))]


def view_round5(flat):
    cam, aim = empty_stage()
    for name, fn, (x, y) in ROUND5:
        build(fn, name, (x, y, 0.001))
    aim.location = (-0.15, -0.05, 0)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 7.0
        cam.location = (-0.15, -0.05, 14)
    else:
        cam.location = (1.2, -6.4, 5.6)
        cam.data.lens = 40


def view_hero5(i, dist):
    cam, aim = empty_stage()
    name, fn, _ = ROUND5[i]
    build(fn, name, (0, 0, 0.001))
    aim.location = (0, -0.05, 0.02)
    cam.location = Vector((0.55, -1.25, 1.1)) * dist
    cam.data.lens = 50


ROUND6 = [("KLASSIK", punch_klassik, (-1.1, 0.8)), ("FARBKARTE", klassik_farbe, (1.1, 0.8)),
          ("ABRISS", klassik_abriss, (-1.1, -0.8)), ("NEON", klassik_neon, (1.1, -0.8))]


def view_round6(flat):
    cam, aim = empty_stage()
    for name, fn, (x, y) in ROUND6:
        build(fn, name, (x, y, 0.001))
    aim.location = (0, 0, 0)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 6.0
        cam.location = (0, 0, 14)
    else:
        cam.location = (1.0, -5.6, 4.9)
        cam.data.lens = 40


def view_hero6(i, dist):
    cam, aim = empty_stage()
    name, fn, _ = ROUND6[i]
    build(fn, name, (0, 0, 0.001))
    aim.location = (0, -0.05, 0.02)
    cam.location = Vector((0.55, -1.25, 1.1)) * dist
    cam.data.lens = 50


# === Die AUSWAHL (2026-11-18): je Sorte der gewählte Träger, der Sonderbestand noch offen ===

def neon_factor(parent):
    klassik_neon(parent, "faktor", ("×2", "", "×2", "", "×2", ""))


FINAL = [("ZAHLEN · Lochkarte Neon", klassik_neon, (-3.3, 1.1)),
         ("FAKTOR · Lochkarte Neon", neon_factor, (-1.1, 1.1)),
         ("MATERIAL · Kassette Kompakt", cassette_kompakt, (0.95, 1.1)),
         ("RUNEN · Glas-Data-Card", glass_card, (2.65, 1.1)),
         ("SONDER? · Spielmodul", cartridge, (-1.8, -1.3)),
         ("SONDER? · EPROM", eprom, (0.0, -1.3)),
         ("SONDER? · Dia", slide, (1.8, -1.3))]


def view_final(flat):
    cam, aim = empty_stage()
    bpy.ops.object.empty_add()
    labels = bpy.context.active_object
    ink = led.mat("Beschriftung", (0.75, 0.76, 0.82), 0.0, 0.6, 0.4)
    for name, fn, (x, y) in FINAL:
        build(fn, name, (x, y, 0.001))
        ly = 0.02 if y > 0 else -2.38
        box.text(labels, name, top(0.0005), x, ly, 0.09, ink, "Etikett_" + name)
    aim.location = (-0.5, -0.2, 0)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 8.8
        cam.location = (-0.5, -0.2, 14)
    else:
        cam.location = (1.4, -9.0, 8.0)
        cam.data.lens = 40


GROUPS = {
    "holo": ([("HOLO", holo_emitter, (-2.25, 0.0)), ("PORTAL", holo_portal, (-0.75, 0.0)),
              ("PUCK", holo_puck, (0.75, 0.0)), ("SCHICHTEN", holo_layers, (2.25, 0.0))],
             (0.0, 0.0), 6.4),
    "trim": ([("NEON", klassik_neon, (-0.95, 0.0)), ("KOMPAKT", cassette_kompakt, (0.95, 0.0))],
             (0.0, 0.0), 4.2),
    "runen": ([("GLASKARTE", glass_card, (-2.3, 0.0)), ("RUNENSTEIN", runestone, (-0.8, 0.0)),
               ("TONTAFEL", clay_tablet, (0.7, 0.0)), ("BRAKTEAT", bracteate, (2.4, -0.05))],
              (0.05, 0.05), 6.9),
    "sonder": ([("KRISTALL", crystal, (-1.5, 0.0)), ("HOLO", holo_emitter, (0.0, 0.0)),
                ("KAPSEL", plasma_capsule, (1.5, 0.0))], (0.0, 0.0), 5.0),
}


def view_group(key, flat):
    items, (cx, cy), scale = GROUPS[key]
    cam, aim = empty_stage()
    for name, fn, (x, y) in items:
        build(fn, name, (x, y, 0.001))
    aim.location = (cx, cy, 0.05)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = scale
        cam.location = (cx, cy, 14)
    else:
        cam.location = (cx + 0.25 * scale, cy - 0.78 * scale, 0.7 * scale)
        cam.data.lens = 40


def view_single(fn, dist, lift=0.05):
    cam, aim = empty_stage()
    build(fn, "Einzel", (0, 0, 0.001))
    aim.location = (0, -0.05, lift)
    cam.location = Vector((0.55, -1.25, 1.1)) * dist
    cam.data.lens = 50


VIEWS = {}
for _g in GROUPS:
    VIEWS["r7_%s_draufsicht" % _g] = (lambda g: lambda: view_group(g, True))(_g)
    VIEWS["r7_%s_uebersicht" % _g] = (lambda g: lambda: view_group(g, False))(_g)
for _n, _fn, _d, _l in (("neon", klassik_neon, 1.6, 0.02), ("kompakt", cassette_kompakt, 1.6, 0.05),
                        ("runenstein", runestone, 1.7, 0.05), ("tontafel", clay_tablet, 1.7, 0.05),
                        ("brakteat", bracteate, 1.7, 0.03), ("kristall", crystal, 1.7, 0.08),
                        ("holo", holo_emitter, 1.8, 0.18), ("kapsel", plasma_capsule, 1.7, 0.1),
                        ("portal", holo_portal, 1.9, 0.2), ("puck", holo_puck, 2.0, 0.28),
                        ("schichten", holo_layers, 1.9, 0.2)):
    VIEWS["nah_" + _n] = (lambda f, d, l: lambda: view_single(f, d, l))(_fn, _d, _l)


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
