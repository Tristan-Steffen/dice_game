"""Fumble: SPIELARTEN des STANGENMAGAZINS für das Modul-Paket (2026-11-23, Typ B aus
tools/blender_module_pack_types.py):
  b1_banderole - drei Röhren unter einer weißen Papier-Banderole (die Ausgangsfassung)
  b2_quer      - sechs kurze Röhren quer, je ein Modul, an einer Kopfleiste (Panflöte)
  b3_getoent   - rauchblau getönte, bedruckte Röhren, zwei Gummibänder, Anhänger
  b4_kappen    - zwei bedruckte Karton-Endkappen halten die Röhren, die Mitte bleibt frei
  b5_flach     - EIN breites Flachrohr mit Stegen, lange Stopfenleisten, Etikett obenauf
Regel: EINE Farbe (Petrol), die Zahl als Augen, die Stufe als Aufkleber.

Aufruf (kopflos):
  blender -b -P tools/blender_module_tube_variants.py -- <ausgabe-ordner> [ansicht,...]
"""
import bpy, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms
import blender_chip_screens as cs
import blender_combo_module_variants as cv
import blender_module_pack_variants as mv
import blender_module_pack_types as mt

led = dm.led
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
PW, PD = mv.PW, mv.PD
black, white, teal, pips, barcode, grade_mark = mt.black, mt.white, mt.teal, mt.pips, mt.barcode, mt.grade_mark


def clear(name="Antistatikrohr", color=(0.7, 0.86, 1.0), alpha=0.2):
    return led.mat(name, color, 0.0, 0.08, 0.0, alpha, 1.0)


def edge(name="Rohrkante", color=(0.75, 0.9, 1.0), alpha=0.5):
    return led.mat(name, color, 0.0, 0.2, 0.0, alpha)


def tube(r, y, length, material, rim, x=0.0, width=0.32):
    """Eine Röhre längs X: Hülle, zwei Längskanten oben, die Führungsschiene unten."""
    led.rounded_box(r, "Rohr", (length, width, 0.34), (x, y, 0.18), material, 0.03, 0.03)
    cs.boxes(r, "Rohrkante", [(x, y + s * (width * 0.5 - 0.012), 0.347, length - 0.02, 0.012, 0.01) for s in (-1, 1)], rim)
    cs.boxes(r, "Schiene", [(x, y, 0.022, length - 0.04, width * 0.5, 0.014)], rim)


def plug(r, x, y, material, pin=True, width=0.26):
    cs.boxes(r, "Stopfen", [(x, y, 0.18, 0.05, width, 0.28)], material)
    if pin:
        s = 1 if x > 0 else -1
        cs.boxes(r, "Stopfenstift", [(x + s * 0.03, y, 0.18, 0.03, 0.08, 0.08)], teal(1.2))


def rows3(r, count, grade, material, rim, plugs=True, length=PW - 0.08):
    stop = led.mat("Stopfen", (0.03, 0.03, 0.04), 0.0, 0.6)
    for row in range(3):
        y = (1 - row) * 0.35
        tube(r, y, length, material, rim)
        if plugs:
            for s in (-1, 1):
                plug(r, s * (length * 0.5 - 0.03), y, stop)
        for col in range(2):
            if row * 2 + col < count:
                mv.mod(r, (col - 0.5) * 0.74 - 0.02, y, 0.03, grade)


# --- b1: Banderole -------------------------------------------------------------------------

def banderole(r, count, grade):
    rows3(r, count, grade, clear(), edge())
    bx, bw = 0.02, 0.5
    cs.boxes(r, "Banderole", [(bx, 0, 0.356, bw, PD + 0.02, 0.006), (bx, PD * 0.5 + 0.008, 0.18, bw, 0.006, 0.35),
                              (bx, -PD * 0.5 - 0.008, 0.18, bw, 0.006, 0.35)], white())
    cs.boxes(r, "BanderolenDruck", [(bx, PD * 0.5 - 0.09, 0.36, bw, 0.16, 0.004)], black("Etikettschwarz"))
    cs.boxes(r, "BanderolenBand", [(bx, PD * 0.5 - 0.185, 0.36, bw, 0.025, 0.004)], teal())
    cv.txt(r, "MODULE", bx, PD * 0.5 - 0.09, 0.364, 0.085, "modul", 2.2, "CENTER")
    pips(r, count, bx - 0.14, 0.2, 0.362, 0.1, 0.07, True)
    barcode(r, bx + 0.08, -0.3, 0.36, 0.22, 0.3)
    grade_mark(r, grade, bx + 0.08, 0.06, 0.362, math.radians(90), 0.4, 0.1)


# --- b2: sechs kurze Röhren quer -----------------------------------------------------------

def quer(r, count, grade):
    head = 0.24
    stop = led.mat("Stopfen", (0.03, 0.03, 0.04), 0.0, 0.6)
    length = PD - head
    for k in range(6):
        x = (k - 2.5) * 0.275
        y = -head * 0.5
        led.rounded_box(r, "Rohr", (0.26, length, 0.34), (x, y, 0.18), clear(), 0.03, 0.03)
        cs.boxes(r, "Rohrkante", [(x + s * 0.118, y, 0.347, 0.012, length - 0.02, 0.01) for s in (-1, 1)], edge())
        cs.boxes(r, "Stopfen", [(x, -PD * 0.5 + 0.03, 0.18, 0.2, 0.05, 0.28)], stop)
        cs.boxes(r, "Stopfenstift", [(x, -PD * 0.5 + 0.0, 0.18, 0.07, 0.03, 0.08)], teal(1.2))
        if k < count:
            m = mv.mod(r, x, y + 0.07, 0.03, grade)
            m.rotation_euler = (0, 0, math.radians(-90))
            m.location = (x, y + 0.07, 0.03)
    # die Kopfleiste: ein schwarzer Clip, in dem alle sechs stecken
    hy = PD * 0.5 - head * 0.5
    led.rounded_box(r, "Kopfleiste", (PW, head, 0.4), (0, hy, 0.2), black("Clipschwarz"), 0.03, 0.015)
    cs.boxes(r, "Leistenband", [(0, hy - head * 0.5 + 0.025, 0.402, PW, 0.035, 0.004)], teal())
    cv.txt(r, "MODULE", -PW * 0.5 + 0.07, hy + 0.02, 0.404, 0.1, "modul", 2.2)
    pips(r, count, 0.0, hy + 0.02, 0.404, 0.09, 0.06)
    grade_mark(r, grade, PW * 0.5 - 0.3, hy + 0.02, 0.404, 0.0, 0.48, 0.1)


# --- b3: getönt, bedruckt, Gummibänder -----------------------------------------------------

def getoent(r, count, grade):
    smoke = clear("Rauchrohr", (0.25, 0.42, 0.6), 0.42)
    rows3(r, count, grade, smoke, edge("Rauchkante", (0.4, 0.65, 0.9), 0.6))
    for row in range(3):
        y = (1 - row) * 0.35
        cv.txt(r, "FUMBLE  ·  MODULE  ·  ESD", -0.28, y + 0.095, 0.352, 0.042, "weiss", 0.9, "CENTER")
    rubber = led.mat("Gummi", (0.015, 0.015, 0.018), 0.0, 0.7)
    for x in (-0.5, 0.3):
        cs.boxes(r, "Gummiband", [(x, 0, 0.357, 0.045, PD + 0.012, 0.008), (x, PD * 0.5 + 0.004, 0.18, 0.045, 0.008, 0.36),
                                  (x, -PD * 0.5 - 0.004, 0.18, 0.045, 0.008, 0.36)], rubber)
    # der Anhänger: schwarzes Kärtchen unter dem rechten Band
    tx = 0.56
    cs.boxes(r, "Anhaenger", [(tx, 0.0, 0.366, 0.42, 0.78, 0.006)], black("Anhaengerkarton"))
    cs.boxes(r, "AnhaengerBand", [(tx - 0.19, 0.0, 0.37, 0.025, 0.78, 0.004)], teal())
    dm.cyl(r, "Oese", 0.03, 0.004, (tx - 0.12, 0.33, 0.371), cs.m_steel(), 20)
    cv.txt(r, "MODULE", tx + 0.02, 0.2, 0.371, 0.075, "modul", 2.2, "CENTER")
    pips(r, count, tx - 0.13, 0.05, 0.371, 0.058, 0.044, False)
    barcode(r, tx + 0.03, -0.26, 0.37, 0.3, 0.12)
    grade_mark(r, grade, tx + 0.03, -0.09, 0.372, 0.0, 0.36, 0.09)


# --- b4: Karton-Endkappen ------------------------------------------------------------------

def kappen(r, count, grade):
    rows3(r, count, grade, clear(), edge(), plugs=False, length=PW - 0.1)
    cap = 0.36
    for s in (-1, 1):
        x = s * (PW * 0.5 - cap * 0.5)
        led.rounded_box(r, "Endkappe", (cap, PD, 0.4), (x, 0, 0.2), black("Kappenkarton"), 0.02, 0.008)
        cs.boxes(r, "Kappenband", [(x - s * (cap * 0.5 - 0.02), 0, 0.402, 0.035, PD, 0.004)], teal())
        cs.boxes(r, "Kappenseite", [(x - s * (cap * 0.5 - 0.02), -PD * 0.5 - 0.002, 0.2, 0.035, 0.004, 0.4)], teal())
    lx, rx = -PW * 0.5 + cap * 0.5 - 0.02, PW * 0.5 - cap * 0.5 + 0.02
    t = cv.txt(r, "MODULE", lx, 0.0, 0.404, 0.1, "modul", 2.2, "CENTER")
    t.rotation_euler = (0, 0, math.radians(90))
    pips(r, count, rx + 0.07, 0.3, 0.404, 0.1, 0.065, True)
    barcode(r, rx - 0.06, -0.33, 0.402, 0.2, 0.2)
    grade_mark(r, grade, rx - 0.07, 0.06, 0.404, math.radians(90), 0.44, 0.1)


# --- b5: ein breites Flachrohr -------------------------------------------------------------

def flach(r, count, grade):
    length = PW - 0.1
    led.rounded_box(r, "Flachrohr", (length, PD - 0.02, 0.34), (0, 0, 0.18), clear(), 0.04, 0.03)
    # Stege teilen die drei Bahnen, Rippen laufen außen längs
    cs.boxes(r, "Steg", [(0, s * 0.175, 0.18, length - 0.02, 0.014, 0.3) for s in (-1, 1)], edge())
    cs.boxes(r, "Rippe", [(0, y, 0.348, length - 0.02, 0.012, 0.01) for y in (-0.52, -0.35, -0.175, 0.175, 0.35, 0.52)], edge())
    cs.boxes(r, "Schiene", [(0, (1 - row) * 0.35, 0.022, length - 0.04, 0.16, 0.014) for row in range(3)], edge())
    stop = led.mat("Stopfen", (0.03, 0.03, 0.04), 0.0, 0.6)
    for s in (-1, 1):
        led.rounded_box(r, "Stopfenleiste", (0.09, PD + 0.01, 0.38), (s * (PW * 0.5 - 0.045), 0, 0.19), stop, 0.02, 0.01)
        cs.boxes(r, "Leistenlicht", [(s * (PW * 0.5 - 0.045), 0, 0.382, 0.03, PD - 0.2, 0.004)], teal(1.4))
    for k in range(count):
        mv.mod(r, (k % 2 - 0.5) * 0.72 - 0.02, (1 - k // 2) * 0.35, 0.03, grade)
    # das Etikett liegt schräg über der Kopf-Ecke wie ein Siegel
    cs.boxes(r, "Etikett", [(-0.38, PD * 0.5 - 0.11, 0.356, 0.62, 0.2, 0.004)], white())
    cs.boxes(r, "Etikettkopf", [(-0.58, PD * 0.5 - 0.11, 0.359, 0.2, 0.2, 0.004)], black("Etikettschwarz"))
    t = cv.txt(r, "MODULE", -0.58, PD * 0.5 - 0.11, 0.363, 0.036, "modul", 2.2, "CENTER")
    barcode(r, -0.3, PD * 0.5 - 0.11, 0.358, 0.3, 0.14)
    pips(r, count, 0.2, PD * 0.5 - 0.11, 0.356, 0.09, 0.06)
    grade_mark(r, grade, 0.45, -PD * 0.5 + 0.1, 0.357, 0.0, 0.5, 0.11)


TYPES = [("B1 · BANDEROLE", banderole), ("B2 · QUER, SECHS RÖHREN", quer), ("B3 · GETÖNT, GUMMIBAND, ANHÄNGER", getoent),
         ("B4 · KARTON-ENDKAPPEN", kappen), ("B5 · FLACHROHR", flach)]


def view_alle():
    for row, (name, build) in enumerate(TYPES):
        y = (2 - row) * 1.55
        ms.label(name, -4.9, y, 0.14)
        for col, (count, grade) in enumerate(mv.SETS):
            mt.pack(build, count, grade, (col - 1) * 2.2 + 0.7, y)
    return [((-0.4, 0.0, 0.1), (-0.4, -6.4, 16.5), 50)]


def view_one(index):
    def run():
        name, build = TYPES[index]
        for col, (count, grade) in enumerate(mv.SETS):
            mt.pack(build, count, grade, (col - 1) * 2.1, 0)
        ms.label(name, 0.0, -0.95, 0.14)
        return [((2.1, 0.0, 0.2), (3.5, -2.4, 2.0), 50), ((0.0, 0.0, 0.2), (0.2, -2.6, 2.6), 50)]
    return run


VIEWS = {"0_alle": view_alle}
for i, key in enumerate(["b1_banderole", "b2_quer", "b3_getoent", "b4_kappen", "b5_flach"]):
    VIEWS[key] = view_one(i)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    argv = sys.argv[sys.argv.index("--") + 1:]
    only = argv[1].split(",") if len(argv) > 1 else []
    for name, fn in VIEWS.items():
        if only and name not in only:
            continue
        cam, aim = dm.empty_stage()
        for o in bpy.data.objects:
            mats = getattr(o.data, "materials", None) if o.data is not None else None
            if mats and mats[0] is not None and mats[0].name.startswith("Softbox"):
                o.location.z += 30.0
        scene = bpy.context.scene
        scene.eevee.taa_render_samples = 48
        scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
        for k, (target, eye, lens) in enumerate(fn()):
            aim.location = target
            cam.location = eye
            cam.data.lens = lens
            scene.render.filepath = os.path.join(OUT, "%s%s.png" % (name, "" if k == 0 else "_%d" % (k + 1)))
            bpy.ops.render.render(write_still=True)
    print("ok")
