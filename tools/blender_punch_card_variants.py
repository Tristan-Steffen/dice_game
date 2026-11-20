"""Fumble: drei Entwürfe der LOCHKARTE, die deutlicher als Lochkarte lesen (2026-11-20).
  A · STANZFELD  schwarze Karte, ein volles Raster von Lochpositionen, die gestanzten leuchten
  B · MANILA     helle Karton-Karte wie das Vorbild, dunkler Druck, grün durchscheinende Löcher
  C · ZEILEN     schwarze Karte, zehn numerierte Zeilen-Linien, die Löcher sitzen auf ihnen
Jede Karte trägt zur Probe ein Netz, wie es im Spiel darauf liegt.

Aufruf (kopflos):
  blender -b -P tools/blender_punch_card_variants.py -- <ausgabe-ordner>
"""
import bpy, math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media_export as em

L, W, C = em.L, em.W, em.C
PT, PLAYER, PCORE = em.PT, em.PLAYER, em.PCORE
LEG = em.CORNER_CUT / math.sqrt(2.0)


def flats(name, polys, z, material):
    verts, faces = [], []
    for poly in polys:
        k = len(verts)
        verts += [(x, y, z) for x, y in poly]
        faces.append(list(range(k, k + len(poly))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def rect(x, y, w, h):
    return [(x - w / 2, y - h / 2), (x + w / 2, y - h / 2), (x + w / 2, y + h / 2),
            (x - w / 2, y + h / 2)]


def stock(m, body, role):
    """Die drei Lagen der Karte mit gekappter Ecke; zurück kommt die obere (zum Stanzen)."""
    lower = em.box(role + "Unterlage", (L, W, PLAYER), (0, 0, PLAYER * 0.5), body, 0.02)
    core = em.box("KernSchicht", (L - 0.004, W - 0.004, PCORE), (0, 0, PLAYER + PCORE * 0.5),
                  m["Kern"], 0.02)
    top = em.box(role + "Karte", (L, W, PT - PLAYER - PCORE), (0, 0, (PT + PLAYER + PCORE) * 0.5),
                 body, 0.02)
    cutter = em.corner_cutter(em.CORNER_CUT)
    for o in (lower, core, top):
        em.led.cut(o, cutter)
    return top


def punch(top, holes):
    shapes = [("rect", x - w / 2, y - h / 2, x + w / 2, y + h / 2) for x, y, w, h in holes]
    em.led.cut(top, em.dm.hole_cutter(None, "SchnittStanzungen", shapes, PLAYER + PCORE * 0.5,
                                      0.1))


def rim(m, role="Saum"):
    e = 0.014
    pts = [(-L * 0.5 + e, W * 0.5 - LEG - e * 0.4), (-L * 0.5 + LEG + e * 0.4, W * 0.5 - e),
           (L * 0.5 - e, W * 0.5 - e), (L * 0.5 - e, -W * 0.5 + e), (-L * 0.5 + e, -W * 0.5 + e),
           (-L * 0.5 + e, W * 0.5 - LEG - e * 0.4)]
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        em.line("%s%d" % (role, k), PT, a[0], a[1], b[0], b[1], 0.006, m[role])


def free(x, y, pad=0.03):
    """Frei für Druck und Löcher: in keiner Netz-Zelle, nicht an der gekappten Ecke."""
    if em.in_net(x, y, pad):
        return False
    return (x + L * 0.5) + (W * 0.5 - y) > LEG + 0.07


def net(m):
    """Das Netz des Spiels zur Probe: sechs Zellen, zwei davon mit Wert."""
    for k, (cx, cy) in enumerate(em.CELLS):
        flats("DunkelZelle%d" % k, [rect(cx, cy, C, C)], PT + 0.002, m["Dunkel"])
        h = C * 0.5
        for j, (a, b) in enumerate((((-h, -h), (h, -h)), ((h, -h), (h, h)), ((h, h), (-h, h)),
                                    ((-h, h), (-h, -h)))):
            em.line("SaumZelle%d_%d" % (k, j), PT + 0.002, cx + a[0], cy + a[1], cx + b[0],
                    cy + b[1], 0.012, m["Saum"])
    for k, body in ((0, "+2"), (2, "+1")):
        cx, cy = em.CELLS[k]
        em.glyph("SaumWert%d" % k, body, cx, cy, PT + 0.004, 0.16, m["Saum"])


def grid(cols, rows, x0=-0.72, x1=0.74, y0=0.42, y1=-0.44):
    return [(x0 + i * (x1 - x0) / (cols - 1), y0 + d * (y1 - y0) / (rows - 1), i, d)
            for i in range(cols) for d in range(rows)]


def card_stanzfeld():
    """A: jede Lochposition ist da - als feiner Strich, gestanzt als leuchtendes Loch."""
    m = em.mats("zahl")
    black = em.led.mat("Neonkarton", (0.03, 0.03, 0.036), 0.0, 0.55, clearcoat=0.3)
    top = stock(m, black, "Koerper")
    rnd = random.Random(3)
    holes, ticks = [], []
    for x, y, _i, _d in grid(18, 10):
        if not free(x, y):
            continue
        if rnd.random() < 0.3:
            holes.append((x, y, 0.036, 0.056))
        else:
            ticks.append(rect(x, y, 0.03, 0.008))
    punch(top, holes)
    flats("DruckRaster", ticks, PT + em.LIFT, m["Druck"])
    rim(m)
    em.line("KernStreifen", PT, -L * 0.5 + LEG + 0.02, 0.503, L * 0.5 - 0.03, 0.503, 0.026,
            m["Kern"])
    net(m)


def card_manila():
    """B: die helle Karton-Karte - dunkle Zeilen-Ziffern am Rand, Striche, grüne Löcher."""
    m = em.mats("zahl")
    top = stock(m, m["Hell"], "Hell")
    rnd = random.Random(5)
    holes, ticks = [], []
    for x, y, i, d in grid(18, 10):
        if not free(x, y):
            continue
        if i in (0, 17):
            em.glyph("DunkelZiffer%d_%d" % (i, d), str(d), x, y, PT + em.LIFT, 0.05, m["Dunkel"])
        elif rnd.random() < 0.3:
            holes.append((x, y, 0.036, 0.056))
        else:
            ticks.append(rect(x, y, 0.03, 0.007))
    punch(top, holes)
    flats("DunkelRaster", ticks, PT + em.LIFT, m["Dunkel"])
    flats("DunkelKopfzeile", [rect(0.06, 0.495, L - 0.4, 0.008)], PT + em.LIFT, m["Dunkel"])
    em.line("KernStreifen", PT, -L * 0.5 + LEG + 0.02, 0.518, L * 0.5 - 0.03, 0.518, 0.02,
            m["Kern"])
    rim(m)
    net(m)


def card_zeilen():
    """C: zehn numerierte Zeilen-Linien über die ganze Karte, die Löcher sitzen auf ihnen."""
    m = em.mats("zahl")
    black = em.led.mat("Neonkarton", (0.03, 0.03, 0.036), 0.0, 0.55, clearcoat=0.3)
    top = stock(m, black, "Koerper")
    rnd = random.Random(8)
    holes, lines = [], []
    for d in range(10):
        y = 0.42 - d * 0.86 / 9
        left = -0.66 if (-0.66 + L * 0.5) + (W * 0.5 - y) > LEG + 0.07 else -0.5
        spans, start, x = [], None, left
        while x <= 0.76 + 1e-6:
            clear = not em.in_net(x, y, 0.025)
            if clear and start is None:
                start = x
            if (not clear or x + 0.01 > 0.76) and start is not None:
                spans.append((start, x))
                start = None
            x += 0.01
        for a, b in spans:
            if b - a > 0.05:
                lines.append(rect((a + b) * 0.5, y, b - a, 0.005))
        if free(-0.73, y, 0.0):
            em.glyph("DruckZiffer%d" % d, str(d), -0.73, y, PT + em.LIFT, 0.055, m["Druck"])
    for x, y, _i, _d in grid(13, 10, -0.6, 0.72):
        if free(x, y) and rnd.random() < 0.34:
            holes.append((x, y, 0.05, 0.062))
    punch(top, holes)
    flats("DruckZeilen", lines, PT + em.LIFT, m["Druck"])
    rim(m)
    em.line("KernStreifen", PT, -L * 0.5 + LEG + 0.02, 0.503, L * 0.5 - 0.03, 0.503, 0.026,
            m["Kern"])
    net(m)


VARIANTS = [("lochkarte_a_stanzfeld", card_stanzfeld), ("lochkarte_b_manila", card_manila),
            ("lochkarte_c_zeilen", card_zeilen)]


def render(view, flat):
    cam, aim = em.dm.empty_stage()
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = 2400, 900
    for i, (name, _build) in enumerate(VARIANTS):
        bpy.ops.import_scene.gltf(filepath=os.path.join(em.OUT, name + ".glb"))
        for o in bpy.context.selected_objects:
            if o.parent is None:
                o.location.x += (i - (len(VARIANTS) - 1) * 0.5) * 1.8
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 2.0 * len(VARIANTS)
        aim.location = (0, 0, 0)
        cam.location = (0, 0, 13)
    else:
        aim.location = (0, 0.05, 0.02)
        cam.location = (0.4, -4.6 - (len(VARIANTS) - 3) * 1.6, 3.4 + (len(VARIANTS) - 3) * 1.1)
        cam.data.lens = 46
    scene.eevee.taa_render_samples = 48
    scene.render.filepath = os.path.join(em.OUT, view + ".png")
    bpy.ops.render.render(write_still=True)


# --- Zweite Runde: vier Karton-Karten in Richtung B ------------------------------------------

def manila(tone, ink, cols, hole, share, digits, band=False, row_lines=False, col_numbers=False):
    """Eine helle Karte. ink = Rolle des Drucks, digits = "rand" | "alle" | "",
    band = farbiges Kopfband, row_lines = Zeilen-Linien, col_numbers = Spalten-Nummern am Fuß."""
    m = em.mats("zahl")
    body = em.led.mat("Karton_%.2f" % tone[0], tone, 0.0, 0.8)
    top = stock(m, body, "Hell")
    rnd = random.Random(5)
    holes, ticks = [], []
    cells = grid(cols, 10)
    for x, y, i, d in cells:
        if not free(x, y):
            continue
        edge = i in (0, cols - 1)
        if digits == "rand" and edge:
            em.glyph("%sZiffer%d_%d" % (ink, i, d), str(d), x, y, PT + em.LIFT, 0.05, m[ink])
        elif rnd.random() < share and not (digits == "rand" and edge):
            holes.append((x, y, hole[0], hole[1]))
        elif digits == "alle":
            em.glyph("%sZiffer%d_%d" % (ink, i, d), str(d), x, y, PT + em.LIFT, 0.042, m[ink])
        elif not row_lines:
            ticks.append(rect(x, y, 0.03, 0.007))
    punch(top, holes)
    if row_lines:
        for d in range(10):
            y = 0.42 - d * 0.86 / 9
            start, x = None, -0.74
            while x <= 0.76 + 1e-6:
                clear = free(x, y, 0.025)
                if clear and start is None:
                    start = x
                if (not clear or x + 0.01 > 0.76) and start is not None:
                    if x - start > 0.04:
                        ticks.append(rect((start + x) * 0.5, y, x - start, 0.004))
                    start = None
                x += 0.01
    if ticks:
        flats(ink + "Raster", ticks, PT + em.LIFT, m[ink])
    if col_numbers:
        for i in range(0, cols, 2):
            x = -0.72 + i * 1.46 / (cols - 1)
            if free(x, -0.505, 0.0):
                em.glyph("%sSpalte%d" % (ink, i), str(i + 1), x, -0.505, PT + em.LIFT, 0.03, m[ink])
    if band:
        flats("KernBand", [rect(0.07, 0.495, L - 0.34, 0.05)], PT + em.LIFT, m["Kern"])
    else:
        flats(ink + "Kopfzeile", [rect(0.06, 0.495, L - 0.4, 0.008)], PT + em.LIFT, m[ink])
        em.line("KernStreifen", PT, -L * 0.5 + LEG + 0.02, 0.518, L * 0.5 - 0.03, 0.518, 0.02,
                m["Kern"])
    rim(m)
    net(m)


CREAM = (0.78, 0.74, 0.68)
MANILA = (0.72, 0.6, 0.4)


def card_b1():
    """B1 · KLASSIK: jede Lochposition trägt ihre Ziffer - das Bild der IBM-Karte."""
    manila(CREAM, "Dunkel", 14, (0.036, 0.062), 0.28, "alle")


def card_b2():
    """B2 · KOPFBAND: ein breites grünes Band am Kopf, Zeilen-Ziffern am Rand, Spalten-Nummern."""
    manila(CREAM, "Dunkel", 18, (0.036, 0.056), 0.3, "rand", band=True, col_numbers=True)


def card_b3():
    """B3 · MANILA: gelbbrauner Karton, Zeilen-Linien, hohe schmale Löcher in dichten Spalten."""
    manila(MANILA, "Dunkel", 22, (0.03, 0.066), 0.36, "rand", row_lines=True)


def card_b4():
    """B4 · GRÜNDRUCK: der ganze Druck in der Sortenfarbe - Ziffern, Linien, Band."""
    manila(CREAM, "Druck", 14, (0.036, 0.062), 0.28, "alle", band=True)


# --- Dritte Runde: die Karte leuchtet NICHT - nur das Netz; das Licht kommt vom Grund ----------

def inert(tone, cols, hole, share, digits, band=False, row_lines=False, col_numbers=False):
    """Eine stumpfe Karton-Karte: echte Löcher durch die ganze Karte, dunkler Druck, kein
    Kern, kein Saum. Liegt sie auf leuchtendem Grund, scheint er durch die Löcher."""
    m = em.mats("zahl")
    body = em.led.mat("Karton_%.2f" % tone[0], tone, 0.0, 0.85)
    ink = m["Dunkel"]
    top = em.box("HellKarte", (L, W, PT), (0, 0, PT * 0.5), body, 0.02)
    em.led.cut(top, em.corner_cutter(em.CORNER_CUT))
    rnd = random.Random(5)
    holes, ticks = [], []
    for x, y, i, d in grid(cols, 10):
        if not free(x, y):
            continue
        edge = i in (0, cols - 1)
        if digits == "rand" and edge:
            em.glyph("DunkelZiffer%d_%d" % (i, d), str(d), x, y, PT + em.LIFT, 0.05, ink)
        elif rnd.random() < share and not (digits == "rand" and edge):
            holes.append((x, y, hole[0], hole[1]))
        elif digits == "alle":
            em.glyph("DunkelZiffer%d_%d" % (i, d), str(d), x, y, PT + em.LIFT, 0.042, ink)
        elif not row_lines:
            ticks.append(rect(x, y, 0.03, 0.007))
    shapes = [("rect", x - w / 2, y - h / 2, x + w / 2, y + h / 2) for x, y, w, h in holes]
    em.led.cut(top, em.dm.hole_cutter(None, "SchnittStanzungen", shapes, -0.1, 0.1))
    if row_lines:
        for d in range(10):
            y = 0.42 - d * 0.86 / 9
            start, x = None, -0.74
            while x <= 0.76 + 1e-6:
                clear = free(x, y, 0.025)
                if clear and start is None:
                    start = x
                if (not clear or x + 0.01 > 0.76) and start is not None:
                    if x - start > 0.04:
                        ticks.append(rect((start + x) * 0.5, y, x - start, 0.004))
                    start = None
                x += 0.01
    if ticks:
        flats("DunkelRaster", ticks, PT + em.LIFT, ink)
    if col_numbers:
        for i in range(0, cols, 2):
            x = -0.72 + i * 1.46 / (cols - 1)
            if free(x, -0.505, 0.0):
                em.glyph("DunkelSpalte%d" % i, str(i + 1), x, -0.505, PT + em.LIFT, 0.03, ink)
    if band:
        flats("DunkelBand", [rect(0.07, 0.495, L - 0.34, 0.05)], PT + em.LIFT,
              em.led.mat("Bandtinte", (0.06, 0.3, 0.16), 0.0, 0.8))
    else:
        flats("DunkelKopfzeile", [rect(0.06, 0.5, L - 0.4, 0.008)], PT + em.LIFT, ink)
    net(m)


def card_c1():
    """C1 · KLASSIK: jede Lochposition trägt ihre Ziffer."""
    inert(CREAM, 14, (0.04, 0.066), 0.3, "alle")


def card_c2():
    """C2 · KOPFBAND: ein gedrucktes grünes Band, Zeilen-Ziffern am Rand, Spalten-Nummern."""
    inert(CREAM, 18, (0.038, 0.06), 0.32, "rand", band=True, col_numbers=True)


def card_c3():
    """C3 · MANILA: gelbbrauner Karton, Zeilen-Linien, hohe schmale Löcher."""
    inert(MANILA, 22, (0.032, 0.068), 0.36, "rand", row_lines=True)


def render_inert(view, flat):
    """Oben auf dunklem Grund, unten auf grün leuchtendem - dort scheint er durch die Löcher."""
    cam, aim = em.dm.empty_stage()
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = 2400, 1300
    lit = em.led.mat("Grundlicht", em.dm.col("zahl"), 0.0, 0.4, 2.2)
    for row, y in enumerate((0.72, -0.72)):
        for i, (name, _build) in enumerate(VARIANTS):
            bpy.ops.import_scene.gltf(filepath=os.path.join(em.OUT, name + ".glb"))
            x = (i - 1) * 1.95
            for o in bpy.context.selected_objects:
                if o.parent is None:
                    o.location.x += x
                    o.location.y += y
                    o.location.z += 0.012
            if row == 1:
                em.led.rounded_box(None, "Grund%d" % i, (L + 0.14, W + 0.14, 0.01),
                                   (x, y, 0.005), lit, 0.03, 0.0)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 6.3
        aim.location = (0, 0, 0)
        cam.location = (0, 0, 13)
    else:
        aim.location = (0, -0.1, 0.02)
        cam.location = (0.4, -5.6, 4.6)
        cam.data.lens = 44
    scene.eevee.taa_render_samples = 48
    scene.render.filepath = os.path.join(em.OUT, view + ".png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    VARIANTS[:] = [("lochkarte_c1_klassik", card_c1), ("lochkarte_c2_kopfband", card_c2),
                   ("lochkarte_c3_manila", card_c3)]
    em.CARRIERS = VARIANTS
    em.export_all()
    render_inert("lochkarte_c_draufsicht", True)
    render_inert("lochkarte_c_schraeg", False)
    print("ok")
