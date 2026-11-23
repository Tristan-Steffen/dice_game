"""Fumble: FÜNF VERPACKUNGS-TYPEN für das Modul-Paket (2026-11-23) - jede nach einer echten
Verpackung, keine wie die Hüllen der anderen Pakete (Lochtasche, Kassettenfach, Tonhülle, Blister,
Schale mit Haube):
  a_kopfkarte - Polybeutel mit Kopfkarte und Euro-Loch (Bastelladen)
  b_stange    - Stangenmagazin: antistatische Röhren unter einer Banderole (Bauteil-Handel)
  c_rolle     - Gurtrolle: Blistergurt auf der Spule, das Ende zeigt die Module
  d_schieber  - Schiebeschachtel: Hülse und Schublade mit Schaum-Einlage
  e_dose      - Blechdose mit Sichtfenster im Deckel
Regel aller Pakete: EINE Farbe (Petrol), die Zahl als Augen, die Stufe als Schärpe/Siegel.
Je Typ drei Pakete: 2er Gewöhnlich, 4er Episch, 6er Legendär.

Aufruf (kopflos):
  blender -b -P tools/blender_module_pack_types.py -- <ausgabe-ordner> [ansicht,...]
Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tischfläche bei Z = 0.
"""
import bpy, math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms
import blender_chip_screens as cs
import blender_combo_module_variants as cv
import blender_combo_bay_variants as bv
import blender_module_pack_variants as mv

led = dm.led
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
PW, PD = mv.PW, mv.PD
dm.HEX["modul"] = "#3fb8d6"
TEAL = dm.col("modul")


def black(name="Schwarzdruck", rough=0.45):
    return led.mat(name, (0.018, 0.018, 0.024), 0.0, rough, clearcoat=0.3)


def white():
    return led.mat("Weissdruck", (0.85, 0.86, 0.9), 0.0, 0.6, 0.25)


def teal(e=1.8):
    return dm.glow("modul", e)


def pips(r, count, x, y, z, pitch=0.09, size=0.06, vertical=False):
    for i in range(6):
        px, py = (x, y - i * pitch) if vertical else (x + i * pitch, y)
        cs.boxes(r, "Auge", [(px, py, z, size, size, 0.004)], teal(2.6) if i < count else
                 led.mat("AugeLeer", (0.07, 0.08, 0.1), 0.0, 0.5))


def barcode(r, x, y, z, w=0.3, h=0.12):
    cs.boxes(r, "CodeFeld", [(x, y, z, w, h, 0.003)], white())
    rnd = random.Random(7)
    bars, at = [], x - w * 0.5 + 0.02
    while at < x + w * 0.5 - 0.03:
        bw = rnd.choice((0.006, 0.01, 0.016))
        bars.append((at + bw * 0.5, y, z + 0.003, bw, h - 0.03, 0.003))
        at += bw + rnd.choice((0.006, 0.01))
    cs.boxes(r, "Code", bars, black("Tinte", 0.7))


def grade_mark(r, grade, x, y, z, ang=0.0, w=0.46, h=0.11):
    """Die Stufe als Aufkleber in ihrer Farbe (Gewöhnlich trägt keinen)."""
    if grade == "gewoehnlich":
        return
    s = cs.root("Stufe")
    s.parent = r
    cs.boxes(s, "Aufkleber", [(0, 0, 0.003, w, h, 0.006)], led.mat("Stufe_" + grade, mv.METAL[grade], 0.7, 0.3, 0.5))
    cv.txt(s, mv.GRADES[grade], 0, 0, 0.008, h * 0.5, "weiss", 0.0, "CENTER").data.materials[0] = black("Tinte", 0.7)
    s.location = (x, y, z)
    s.rotation_euler = (0, 0, ang)


def loose(r, count, cx, cy, z, grade, seed, cols=2, dx=0.76, dy=0.3, wobble=0.16):
    """count Module als lockeres Raster um (cx, cy)."""
    rnd = random.Random(seed)
    rows = (count + cols - 1) // cols
    for k in range(count):
        col, row = k % cols, k // cols
        x = cx + (col - (cols - 1) * 0.5) * dx + rnd.uniform(-0.03, 0.03)
        y = cy + ((rows - 1) * 0.5 - row) * dy + rnd.uniform(-0.02, 0.02)
        m = mv.mod(r, x, y, z, grade)
        m.rotation_euler = (0, 0, rnd.uniform(-wobble, wobble))


# --- a: Polybeutel mit Kopfkarte -------------------------------------------------------------

def kopfkarte(r, count, grade):
    head = 0.34
    hy = PD * 0.5 - head * 0.5
    cs.boxes(r, "Kopfkarte", [(0, hy, 0.012, PW, head, 0.024)], black())
    cs.boxes(r, "Druckband", [(0, hy - head * 0.5 + 0.03, 0.026, PW, 0.05, 0.004)], teal())
    # Euro-Loch: Langloch mit rundem Auge
    cs.boxes(r, "EuroLoch", [(0, hy + 0.09, 0.026, 0.3, 0.035, 0.004)], led.mat("Loch", (0, 0, 0), 0.0, 1.0))
    dm.cyl(r, "EuroAuge", 0.045, 0.004, (0, hy + 0.1, 0.027), led.mat("Loch", (0, 0, 0), 0.0, 1.0), 24)
    cv.txt(r, "MODULE", -PW * 0.5 + 0.08, hy - 0.03, 0.028, 0.12, "modul", 2.2)
    pips(r, count, PW * 0.5 - 0.6, hy - 0.03, 0.028)
    cs.boxes(r, "Klammer", [(s * 0.5, hy - head * 0.5 + 0.09, 0.028, 0.09, 0.012, 0.006) for s in (-1, 1)], cs.m_steel())
    # der Beutel: klare Folie, unten verschweißt, die Module liegen lose darin
    by = -head * 0.5
    led.rounded_box(r, "Beutel", (PW - 0.05, PD - head + 0.03, 0.3), (0, by, 0.155),
                    led.mat("Polyfolie", (0.82, 0.9, 1.0), 0.0, 0.08, 0.0, 0.14, 1.0), 0.05, 0.12)
    cs.boxes(r, "Schweissnaht", [(0, -PD * 0.5 + 0.03, 0.02, PW - 0.08, 0.035, 0.012)],
             led.mat("Naht", (0.7, 0.8, 0.9), 0.0, 0.2, 0.0, 0.35))
    loose(r, count, 0.0, by + 0.0, 0.012, grade, count, dy=0.235, wobble=0.1)
    grade_mark(r, grade, PW * 0.5 - 0.3, by + 0.24, 0.31, -0.2)


# --- b: Stangenmagazin -----------------------------------------------------------------------

def stange(r, count, grade):
    tube = led.mat("Antistatikrohr", (0.7, 0.86, 1.0), 0.0, 0.08, 0.0, 0.2, 1.0)
    plug = led.mat("Stopfen", (0.03, 0.03, 0.04), 0.0, 0.6)
    for row in range(3):
        y = (1 - row) * 0.35
        led.rounded_box(r, "Rohr", (PW - 0.08, 0.32, 0.34), (0, y, 0.18), tube, 0.03, 0.03)
        cs.boxes(r, "Rohrkante", [(0, y + s * 0.15, 0.345, PW - 0.1, 0.012, 0.012) for s in (-1, 1)],
                 led.mat("Rohrkante", (0.75, 0.9, 1.0), 0.0, 0.2, 0.0, 0.45))
        for s in (-1, 1):
            cs.boxes(r, "Stopfen", [(s * (PW * 0.5 - 0.035), y, 0.18, 0.05, 0.26, 0.28)], plug)
            cs.boxes(r, "Stopfenstift", [(s * (PW * 0.5 - 0.005), y, 0.18, 0.03, 0.08, 0.08)], teal(1.2))
        for col in range(2):
            if row * 2 + col < count:
                mv.mod(r, (col - 0.5) * 0.74 - 0.02, y, 0.03, grade)
    # die Banderole: weißes Etikett mit Druck, hält die drei Röhren zusammen
    bx, bw = 0.02, 0.5
    cs.boxes(r, "Banderole", [(bx, 0, 0.356, bw, PD + 0.02, 0.006), (bx, PD * 0.5 + 0.008, 0.18, bw, 0.006, 0.35),
                              (bx, -PD * 0.5 - 0.008, 0.18, bw, 0.006, 0.35)], white())
    cs.boxes(r, "BanderolenDruck", [(bx, PD * 0.5 - 0.09, 0.36, bw, 0.16, 0.004)], black("Etikettschwarz"))
    cv.txt(r, "MODULE", bx, PD * 0.5 - 0.09, 0.364, 0.085, "modul", 2.2, "CENTER")
    pips(r, count, bx - 0.14, 0.24, 0.362, 0.1, 0.07, True)
    barcode(r, bx + 0.08, -0.3, 0.36, 0.22, 0.3)
    grade_mark(r, grade, bx + 0.08, 0.08, 0.362, math.radians(90), 0.4, 0.1)


# --- c: Gurtrolle ----------------------------------------------------------------------------

def rolle(r, count, grade):
    cx, rad = -PW * 0.5 + PD * 0.5, PD * 0.5
    flange = led.mat("Spulenflansch", (0.02, 0.02, 0.028), 0.2, 0.35, clearcoat=0.6)
    dm.cyl(r, "FlanschUnten", rad, 0.02, (cx, 0, 0.01), flange, 64)
    dm.cyl(r, "Wickel", rad * 0.8, 0.26, (cx, 0, 0.15), led.mat("Gurtwickel", (0.05, 0.05, 0.065), 0.1, 0.5), 64)
    # der obere Flansch: Ring, Nabe und drei Speichen - dazwischen sieht man den Gurt
    dm.annulus(r, "FlanschRing", cx, 0, 0.29, rad * 0.86, rad, flange)
    dm.cyl(r, "Nabe", rad * 0.34, 0.03, (cx, 0, 0.295), flange, 48)
    dm.cyl(r, "Nabenloch", 0.06, 0.034, (cx, 0, 0.296), led.mat("Loch", (0, 0, 0), 0.0, 1.0), 24)
    for k in range(3):
        a = math.radians(90 + k * 120)
        cs.strips(r, "Speiche", [[(cx + rad * 0.3 * math.cos(a), rad * 0.3 * math.sin(a)),
                                  (cx + rad * 0.9 * math.cos(a), rad * 0.9 * math.sin(a))]], 0.16, 0.292, flange)
    dm.annulus(r, "Flanschsaum", cx, 0, 0.296, rad * 0.955, rad * 0.985, teal(1.6))
    # Etikett auf der Nabe
    cs.boxes(r, "Etikett", [(cx, -0.21, 0.312, 0.36, 0.12, 0.004)], white())
    cv.txt(r, "MODULE", cx, -0.21, 0.316, 0.07, "weiss", 0.0, "CENTER").data.materials[0] = black("Tinte", 0.7)
    pips(r, count, cx - 0.2, 0.2, 0.312, 0.08, 0.055)
    # das Gurtende läuft nach rechts aus der Rolle: Transportlöcher, Taschen, Deckfolie
    x0, x1 = cx + rad * 0.5, PW * 0.5
    ty = -rad + 0.19
    cs.boxes(r, "Gurt", [((x0 + x1) * 0.5, ty, 0.012, x1 - x0, 0.36, 0.024)],
             led.mat("Gurt", (0.03, 0.03, 0.04), 0.0, 0.5))
    n = int((x1 - x0) / 0.07)
    cs.boxes(r, "Transportloch", [(x0 + 0.04 + i * 0.07, ty + 0.15, 0.025, 0.03, 0.03, 0.004) for i in range(n)],
             led.mat("Loch", (0, 0, 0), 0.0, 1.0))
    mv.mod(r, x1 - 0.42, ty - 0.02, 0.02, grade)
    led.rounded_box(r, "Deckfolie", (0.8, 0.3, 0.26), (x1 - 0.42, ty - 0.02, 0.14),
                    led.mat("Deckfolie", (0.8, 0.9, 1.0), 0.0, 0.06, 0.0, 0.13, 1.0), 0.03, 0.04)
    grade_mark(r, grade, x1 - 0.3, 0.28, 0.006, 0.0, 0.5, 0.12)
    barcode(r, x1 - 0.3, 0.08, 0.004, 0.36, 0.16)


# --- d: Schiebeschachtel ---------------------------------------------------------------------

def schieber(r, count, grade):
    sl = PW * 0.66                      # die Hülse; die Schublade schaut rechts heraus
    sx = -PW * 0.5 + sl * 0.5
    led.rounded_box(r, "Huelse", (sl, PD, 0.36), (sx, 0, 0.18), black("Huelsenkarton"), 0.02, 0.008)
    cs.boxes(r, "Huelsenband", [(sx, -PD * 0.5 + 0.15, 0.362, sl, 0.1, 0.004)], teal())
    cv.txt(r, "MODULE", -PW * 0.5 + 0.09, 0.2, 0.364, 0.15, "modul", 2.2)
    cv.txt(r, "FUMBLE HARDWARE", -PW * 0.5 + 0.09, 0.02, 0.364, 0.055, "weiss", 0.8)
    pips(r, count, -PW * 0.5 + 0.12, -PD * 0.5 + 0.15, 0.366, 0.1, 0.06)
    dm.cyl(r, "Daumenkerbe", 0.1, 0.37, (sx + sl * 0.5, 0, 0.18), led.mat("Kerbe", (0.01, 0.01, 0.012), 0.0, 0.8), 32)
    # die Schublade: Kartonwanne mit Schaum, zwei Nester sichtbar
    dx0, dx1 = sx + sl * 0.5, PW * 0.5
    dw = dx1 - dx0
    cs.boxes(r, "Schublade", [((dx0 + dx1) * 0.5, 0, 0.09, dw, PD - 0.05, 0.18),
                              (dx1 - 0.012, 0, 0.17, 0.024, PD - 0.05, 0.3)],
             led.mat("Graukarton", (0.16, 0.16, 0.18), 0.0, 0.8))
    cs.boxes(r, "Schaum", [((dx0 + dx1) * 0.5 - 0.01, 0, 0.185, dw - 0.05, PD - 0.12, 0.012)],
             led.mat("Schaum", (0.01, 0.01, 0.013), 0.0, 0.95))
    cs.boxes(r, "Zuglasche", [(dx1 + 0.0, 0, 0.3, 0.012, 0.22, 0.12)], teal(1.4))
    for k in range(3):
        y = (1 - k) * 0.32
        cs.boxes(r, "Nest", [((dx0 + dx1) * 0.5 - 0.01, y, 0.192, dw - 0.1, 0.27, 0.004)],
                 led.mat("Nestgrund", (0.03, 0.03, 0.04), 0.0, 0.9))
        if k * 2 < count:
            m = mv.mod(r, dx0 + 0.13, y, 0.19, grade)
    grade_mark(r, grade, sx + 0.16, 0.3, 0.364, math.radians(0), 0.5, 0.11)
    barcode(r, sx + 0.3, -0.12, 0.362, 0.3, 0.12)


# --- e: Blechdose ----------------------------------------------------------------------------

def dose(r, count, grade):
    tin = led.mat("Weissblech", (0.62, 0.64, 0.68), 1.0, 0.22)
    win = (PW - 0.56, PD - 0.52)
    body = led.rounded_box(r, "Dose", (PW, PD, 0.26), (0, 0, 0.13), tin, 0.16, 0.03)
    lid = led.rounded_box(r, "Deckel", (PW + 0.02, PD + 0.02, 0.1), (0, 0, 0.29), tin, 0.17, 0.03)
    for target in (body, lid):
        led.cut(target, cs.boxes(r, "Schnitt", [(0, 0.06, 0.4, win[0], win[1], 0.4)], tin))
    cs.boxes(r, "Scharnier", [(s * 0.3, PD * 0.5 + 0.012, 0.24, 0.16, 0.024, 0.03) for s in (-1, 1)], tin)
    # bedruckter Deckel: schwarzes Feld, Fenster in der Mitte
    druck = led.rounded_box(r, "Deckeldruck", (PW - 0.12, PD - 0.12, 0.006), (0, 0, 0.342), black("Lackdruck", 0.3), 0.12, 0.0)
    led.cut(druck, cs.boxes(r, "Schnitt", [(0, 0.06, 0.4, win[0], win[1], 0.4)], tin))
    cs.boxes(r, "Fensterrand", cs.ring_items(0, 0.06, win[0] + 0.05, win[1] + 0.05, win[0], win[1], 0.348, 0.012), tin)
    cs.boxes(r, "Fenstergrund", [(0, 0.06, 0.2, win[0], win[1], 0.004)], led.mat("Schaum", (0.01, 0.01, 0.013), 0.0, 0.95))
    cs.boxes(r, "Fenster", [(0, 0.06, 0.346, win[0], win[1], 0.006)],
             led.mat("Fensterfolie", (0.8, 0.9, 1.0), 0.0, 0.05, 0.0, 0.14, 1.0))
    for k in range(count):
        m = mv.mod(r, (k % 2 - 0.5) * 0.56 + 0.02, 0.06 + (1 - k // 2) * 0.2, 0.2, grade)
        m.scale = (0.68, 0.68, 0.45)
    cv.txt(r, "MODULE", -PW * 0.5 + 0.16, -PD * 0.5 + 0.17, 0.347, 0.1, "modul", 2.2)
    pips(r, count, PW * 0.5 - 0.66, -PD * 0.5 + 0.17, 0.348, 0.09, 0.06)
    cs.boxes(r, "Druckband", [(0, PD * 0.5 - 0.13, 0.346, PW - 0.4, 0.03, 0.004)], teal())
    grade_mark(r, grade, -PW * 0.5 + 0.34, PD * 0.5 - 0.3, 0.35, 0.6, 0.5, 0.11)


TYPES = [("A · KOPFKARTE", kopfkarte), ("B · STANGENMAGAZIN", stange), ("C · GURTROLLE", rolle),
         ("D · SCHIEBESCHACHTEL", schieber), ("E · BLECHDOSE", dose)]


def pack(build, count, grade, x, y):
    r = cs.root("Paket")
    build(r, count, grade)
    r.location = (x, y, 0.002)


def view_alle():
    for row, (name, build) in enumerate(TYPES):
        y = (2 - row) * 1.6
        ms.label(name, -4.6, y, 0.16)
        for col, (count, grade) in enumerate(mv.SETS):
            pack(build, count, grade, (col - 1) * 2.2 + 0.4, y)
    return [((-0.4, 0.0, 0.1), (-0.4, -6.0, 15.5), 50)]


def view_one(index):
    def run():
        name, build = TYPES[index]
        for col, (count, grade) in enumerate(mv.SETS):
            pack(build, count, grade, (col - 1) * 2.1, 0)
        ms.label(name, 0.0, -0.95, 0.14)
        return [((0.0, -0.1, 0.2), (0.4, -4.6, 4.4), 50), ((2.1, 0.0, 0.2), (3.5, -2.4, 2.0), 50)]
    return run


VIEWS = {"0_alle": view_alle, "a_kopfkarte": view_one(0), "b_stange": view_one(1), "c_rolle": view_one(2),
         "d_schieber": view_one(3), "e_dose": view_one(4)}

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
