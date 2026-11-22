"""Fumble: drei RUHIGERE Entwürfe der Kassette - das Netz soll zuerst lesen (2026-11-22).
  JETZT          der Stand im Spiel zum Vergleich
  A · RUHIG      dunkles Etikett, Naben und Wickel im Rauchglas, Kleinteile nur noch als Relief
  B · NETZPLATTE wie A, dazu eine Platte in Kreuzform unter dem Netz, leere Zellen heller
  C · SCHLITZ    wie B, das Sichtfenster nur noch ein schmaler Schlitz um die Naben
Zweite Runde (farbe): D · PAPIER, E · FARBBAND, F · HELL - die Farben der Kassette zurück,
das Netz auf seiner Platte.
Jede Kassette trägt zur Probe ein Netz mit EINER gefüllten Zelle.

Aufruf (kopflos):
  blender -b -P tools/blender_cassette_calm_variants.py -- <ausgabe-ordner> [ruhig|farbe]
"""
import bpy, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media_export as em

led, dm = em.led, em.dm
L, W, C, P, CT, RX, RR, ARM = em.L, em.W, em.C, em.P, em.CT, em.RX, em.RR, em.ARM
PINK = dm.col("material")


def mat(name, color, rough=0.5, glow=0.0, metal=0.0, coat=0.0, dull=False):
    m = led.mat("Ruhig_" + name, color, metal, rough, glow, clearcoat=coat)
    if dull:
        # Die Softbox der Bühne spiegelt sonst grau auf jeder dunklen Fläche.
        for node in m.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                node.inputs["Specular"].default_value = 0.0
    return m


def cross(name, z, pad, material, corner):
    """Das Kreuz des Netzes als zwei Platten: Arm und Querbalken."""
    cx = (ARM[0] + ARM[3]) * 0.5
    em.box(name + "Arm", (3 * P + C + 2 * pad, C + 2 * pad, 0.001), (cx, 0, z), material, corner)
    em.box(name + "Quer", (C + 2 * pad, 2 * P + C + 2 * pad, 0.001), (ARM[1], 0, z), material,
           corner)


def sample_net(z, lifted):
    """Sechs Zellen wie im Spiel: dunkler Grund, Saum in der Sortenfarbe, eine trägt Gold."""
    ground = mat("Zelle_hell" if lifted else "Zelle", (0.02, 0.016, 0.05) if lifted else
                 (0.004, 0.004, 0.016), 0.45, coat=0.5)
    rim = mat("Zellsaum_hell" if lifted else "Zellsaum", PINK, 0.3, 1.5 if lifted else 0.55)
    gold = mat("Gold", (1.0, 0.72, 0.1), 0.3, 2.2)
    inner = C * (0.84 if lifted else 0.9)
    for k, (x, y) in enumerate(em.CELLS):
        em.box("Zellsaum%d" % k, (C, C, 0.001), (x, y, z), rim, C * 0.1)
        em.box("Zelle%d" % k, (inner, inner, 0.001), (x, y, z + 0.0008),
               gold if k == 1 else ground, C * 0.08)


def cassette(style):
    """style: "jetzt" | "a" | "b" | "c"."""
    now = style == "jetzt"
    shell = mat("Schale", (0.02, 0.02, 0.024), 0.42, coat=0.2)
    em.box("Koerper", (L - 0.008, W - 0.008, CT), (0, 0, CT * 0.5), shell, 0.05, 0.01, 3)
    seam = em.box("KernNaht", (L, W, 0.01), (0, 0, CT * 0.5), mat("Naht", PINK, 0.3, 2.0), 0.054)
    led.cut(seam, em.box("SchnittNaht", (L - 0.03, W - 0.03, 0.05), (0, 0, CT * 0.5), shell, 0.04))
    z = CT
    label = mat("Etikett_jetzt", (0.3, 0.3, 0.31), 0.8) if now else mat(
        "Etikett", (0.035, 0.035, 0.04), 0.7)
    em.box("Etikett", (1.5, 0.74, 0.0015), (0, 0.13, z + 0.00075), label, 0.04)
    if now:
        em.line("Etikettlinie", z + 0.0015, -0.74, -0.2, 0.74, -0.2, 0.01,
                mat("Linie", PINK, 0.3, 1.2), 0.0006)
    # Das Sichtfenster: im Schlitz nur noch so hoch wie die Naben.
    slit = style == "c"
    glass = mat("Fenster", (0.003, 0.003, 0.005), 0.35, dull=True)
    em.box("Fenster", (1.38, 0.2 if slit else 0.33, 0.0015), (0, P, z + 0.00225), glass,
           0.09 if slit else 0.06)
    tape = mat("Wickel_jetzt", (0.3, 0.15, 0.09), 0.4, 0.5, 0.2) if now else mat(
        "Wickel", (0.022, 0.016, 0.014), 0.35, 0.0, 0.2)
    hub = mat("Nabe_jetzt", (0.55, 0.42, 0.3), 0.6, 0.35) if now else mat(
        "Nabe", (0.075, 0.075, 0.085), 0.45)
    zw = z + 0.003
    for s, f in ((-1, 0.75), (1, 0.3)):
        x = s * RX
        if not slit:
            dm.cyl(None, "Wickel%d" % (s + 1), RR * (0.72 + 0.34 * f), 0.002, (x, P, zw + 0.001),
                   tape, 48)
        dm.annulus(None, "Nabe%d" % (s + 1), x, P, zw + 0.0035, RR * 0.38, RR * 0.62, hub, 48)
        for k in range(6):
            a = k * math.tau / 6
            em.line("Zahn%d_%d" % (s + 1, k), zw + 0.0035, x + math.cos(a) * RR * 0.18,
                    P + math.sin(a) * RR * 0.18, x + math.cos(a) * RR * 0.4,
                    P + math.sin(a) * RR * 0.4, RR * 0.12, hub, 0.0)
        if now:
            dm.annulus(None, "Fensterring%d" % (s + 1), x, P, zw + 0.004, RR * 1.08, RR * 1.17,
                       mat("Ring", PINK, 0.3, 1.5), 48)
    if now:
        for k, (a, b) in enumerate(((-RX, ARM[1] - C * 0.5 - 0.02),
                                    (ARM[1] + C * 0.5 + 0.02, RX))):
            em.line("Fensterband%d" % k, zw, a, P - 0.135, b, P - 0.135, 0.012, tape, 0.0008)
    # Die Kopfpartie: ruhig nur noch Relief in der Farbe der Schale.
    trap = [(-0.66, -0.536), (0.66, -0.536), (0.56, -0.2), (-0.56, -0.2)]
    em.quad_prism("Kopfpartie", trap, z - 0.001, z + 0.003, shell)
    hole = mat("Loch_jetzt", (0.0, 0.0, 0.0), 0.9) if now else mat("Loch", (0.011, 0.011, 0.013),
                                                                   0.6)
    for k, x in enumerate((-0.47, 0.47)):
        if not em.in_net(x, -0.4, 0.05):
            dm.cyl(None, "Loch%d" % k, 0.04, 0.001, (x, -0.4, z + 0.0041), hole, 24)
    screw = mat("Schraube_jetzt", (0.62, 0.64, 0.68), 0.25, 0.0, 0.9) if now else mat(
        "Schraube", (0.05, 0.05, 0.056), 0.4, 0.0, 0.6)
    for k, (x, y) in enumerate(((0.76, 0.49), (0.76, -0.49), (-0.76, 0.49), (-0.76, -0.49))):
        dm.cyl(None, "Schraube%d" % k, 0.024, 0.006, (x, y, z + 0.003), screw, 16)
    zn = z + 0.0045
    if style in ("b", "c"):
        cross("Plattensaum", zn, 0.034, mat("Plattensaum", PINK, 0.3, 0.45), 0.05)
        cross("Platte", zn + 0.0006, 0.024, mat("Platte", (0.006, 0.005, 0.009), 0.5, dull=True),
              0.042)
        zn += 0.0014
    sample_net(zn, style in ("b", "c"))


# --- Zweite Runde: die FARBEN der Kassette zurück, das Netz bleibt auf seiner Platte --------------

CREAM = (0.8, 0.76, 0.68)
TAN = (0.3, 0.15, 0.09)
PALETTES = {
    # D · PAPIER: schwarze Schale, Papier-Etikett, braune Wickel - der Stand im Spiel plus Platte
    "d": {"shell": (0.02, 0.02, 0.024), "label": CREAM, "hub": CREAM, "tape": TAN,
          "hole": (0.0, 0.0, 0.0), "screw": (0.62, 0.64, 0.68), "band": False, "rings": False},
    # E · FARBBAND: wie D, das Etikett trägt ein gedrucktes Band in der Sortenfarbe
    "e": {"shell": (0.02, 0.02, 0.024), "label": CREAM, "hub": CREAM, "tape": TAN,
          "hole": (0.0, 0.0, 0.0), "screw": (0.05, 0.05, 0.056), "band": True, "rings": False},
    # F · HELL: hellgraue Schale, weißes Etikett - die ganze Kassette hell, das Netz dunkel darauf
    "f": {"shell": (0.36, 0.36, 0.39), "label": (0.9, 0.9, 0.88), "hub": (0.9, 0.9, 0.88),
          "tape": TAN, "hole": (0.1, 0.1, 0.11), "screw": (0.62, 0.64, 0.68), "band": False,
          "rings": False},
}


def cassette_color(kind):
    pal = PALETTES[kind]
    shell = mat("Schale_" + kind, pal["shell"], 0.42, coat=0.2)
    em.box("Koerper", (L - 0.008, W - 0.008, CT), (0, 0, CT * 0.5), shell, 0.05, 0.01, 3)
    seam = em.box("KernNaht", (L, W, 0.01), (0, 0, CT * 0.5), mat("Naht", PINK, 0.3, 2.0), 0.054)
    led.cut(seam, em.box("SchnittNaht", (L - 0.03, W - 0.03, 0.05), (0, 0, CT * 0.5), shell, 0.04))
    z = CT
    em.box("Etikett", (1.5, 0.74, 0.0015), (0, 0.13, z + 0.00075),
           mat("Etikett_" + kind, pal["label"], 0.8), 0.04)
    ink = mat("Druckfarbe", tuple(v * 0.75 for v in PINK), 0.7, 0.25)
    if pal["band"]:
        em.line("Etikettband", z + 0.0015, -0.75, -0.195, 0.75, -0.195, 0.07, ink, 0.0004)
        em.line("Etikettstrich", z + 0.0015, -0.75, -0.135, 0.75, -0.135, 0.012, ink, 0.0004)
    else:
        em.line("Etikettlinie", z + 0.0015, -0.74, -0.2, 0.74, -0.2, 0.01, ink, 0.0006)
    glass = mat("Fenster", (0.003, 0.003, 0.005), 0.35, dull=True)
    em.box("Fenster", (1.38, 0.33, 0.0015), (0, P, z + 0.00225), glass, 0.06)
    tape = mat("Wickel_" + kind, pal["tape"], 0.4, 0.3, 0.2)
    hub = mat("Nabe_" + kind, pal["hub"], 0.6, 0.15)
    zw = z + 0.003
    for s, f in ((-1, 0.75), (1, 0.3)):
        x = s * RX
        dm.cyl(None, "Wickel%d" % (s + 1), RR * (0.72 + 0.34 * f), 0.002, (x, P, zw + 0.001),
               tape, 48)
        dm.annulus(None, "Nabe%d" % (s + 1), x, P, zw + 0.0035, RR * 0.38, RR * 0.62, hub, 48)
        for k in range(6):
            a = k * math.tau / 6
            em.line("Zahn%d_%d" % (s + 1, k), zw + 0.0035, x + math.cos(a) * RR * 0.18,
                    P + math.sin(a) * RR * 0.18, x + math.cos(a) * RR * 0.4,
                    P + math.sin(a) * RR * 0.4, RR * 0.12, hub, 0.0)
    for k, (a, b) in enumerate(((-RX, ARM[1] - C * 0.5 - 0.05), (ARM[1] + C * 0.5 + 0.05, RX))):
        em.line("Fensterband%d" % k, zw, a, P - 0.135, b, P - 0.135, 0.012, tape, 0.0008)
    trap = [(-0.66, -0.536), (0.66, -0.536), (0.56, -0.2), (-0.56, -0.2)]
    em.quad_prism("Kopfpartie", trap, z - 0.001, z + 0.003, shell)
    hole = mat("Loch_" + kind, pal["hole"], 0.8)
    for k, x in enumerate((-0.47, 0.47)):
        dm.cyl(None, "Loch%d" % k, 0.04, 0.001, (x, -0.4, z + 0.0041), hole, 24)
    screw = mat("Schraube_" + kind, pal["screw"], 0.3, 0.0, 0.8)
    for k, (x, y) in enumerate(((0.76, 0.49), (0.76, -0.49), (-0.76, 0.49), (-0.76, -0.49))):
        dm.cyl(None, "Schraube%d" % k, 0.024, 0.006, (x, y, z + 0.003), screw, 16)
    zn = z + 0.0045
    cross("Plattensaum", zn, 0.034, mat("Plattensaum", PINK, 0.3, 0.45), 0.05)
    cross("Platte", zn + 0.0006, 0.024, mat("Platte", (0.006, 0.005, 0.009), 0.5, dull=True), 0.042)
    sample_net(zn + 0.0014, True)


ROUNDS = {
    "ruhig": [("JETZT", "jetzt"), ("A · RUHIG", "a"), ("B · NETZPLATTE", "b"),
              ("C · SCHLITZ", "c")],
    "farbe": [("JETZT", "jetzt"), ("D · PAPIER", "d"), ("E · FARBBAND", "e"), ("F · HELL", "f")],
}
VARIANTS = ROUNDS["ruhig"]
SPOTS = [(-0.98, 0.7), (0.98, 0.7), (-0.98, -0.7), (0.98, -0.7)]


def build_all():
    ink = mat("Titel", (0.8, 0.8, 0.8), 0.6, 0.6)
    for (title, style), (x, y) in zip(VARIANTS, SPOTS):
        before = set(bpy.data.objects)
        (cassette_color if style in PALETTES else cassette)(style)
        for o in set(bpy.data.objects) - before:
            if o.name.startswith("Schnitt"):
                o.hide_render = True
            if o.parent is None:
                o.location.x += x
                o.location.y += y
        em.glyph("Titel_" + style, title, x, y - 0.64, 0.002, 0.075, ink)


def render(out, name, flat, width, height):
    cam, aim = dm.empty_stage()
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = width, height
    build_all()
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 4.1
        aim.location = (0, -0.04, 0)
        cam.location = (0, -0.04, 12)
    else:
        aim.location = (0, -0.2, 0.0)
        cam.location = (0.3, -5.0, 4.2)
        cam.data.lens = 50
    scene.eevee.taa_render_samples = 48
    scene.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("gerendert", name)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    out = argv[0]
    which = argv[1] if len(argv) > 1 else "farbe"
    VARIANTS = ROUNDS[which]
    os.makedirs(out, exist_ok=True)
    render(out, "kassette_%s_draufsicht" % which, True, 1800, 1260)
    render(out, "kassette_%s_spielgroesse" % which, True, 460, 322)
    render(out, "kassette_%s_schraeg" % which, False, 1800, 1100)
    print("ok")
