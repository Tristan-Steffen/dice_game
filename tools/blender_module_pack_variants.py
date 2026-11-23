"""Fumble: ENTWÜRFE für das MODUL-PAKET (2026-11-23) - es ersetzt den ESD-Beutel.
  a_tray   - Bauteil-Tray: schwarzer Waffel-Träger mit sechs Nestern unter klarer Haube
  b_rohr   - Stangenmagazin: drei klare Röhren, je zwei Module hintereinander, Stopfen in der Stufe
  c_koffer - Modulkoffer: eloxierte Kassette, Rauchglas-Fenster, Schaum-Einlage, LED-Zähler
Je Entwurf drei Pakete: 2er Gewöhnlich, 4er Episch, 6er Legendär. Gefüllt sind so viele Nester,
wie die Größe sagt; die Stufe ist die Farbe von Band, Stopfen bzw. Beschlag und der Modul-LEDs.

Aufruf (kopflos):
  blender -b -P tools/blender_module_pack_variants.py -- <ausgabe-ordner> [ansicht,...]
Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tischfläche bei Z = 0.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms
import blender_chip_screens as cs
import blender_combo_module_variants as cv
import blender_combo_bay_variants as bv

led = dm.led
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
PW, PD = 1.69, 1.12            # der EINE Paket-Grundriß (Karte × 1,04)
MS = 0.85                      # Maßstab der Module im Paket
GRADES = {"gewoehnlich": "GEWÖHNLICH", "selten": "SELTEN", "episch": "EPISCH", "legendaer": "LEGENDÄR"}
METAL = {"gewoehnlich": (0.62, 0.64, 0.68), "selten": (0.1, 0.3, 0.85), "episch": (0.45, 0.14, 0.8),
         "legendaer": (0.95, 0.62, 0.12)}
SETS = [(2, "gewoehnlich"), (4, "episch"), (6, "legendaer")]
dm.HEX["warn"] = "#ffd21a"
dm.HEX["weiss"] = "#e8ecf5"


def nest(k):
    """Mitte des Nests k (0 = oben links) im Paket: zwei Spalten, drei Reihen."""
    return ((k % 2 - 0.5) * 0.8, (1 - k // 2) * 0.33)


def mod(parent, x, y, z, grade):
    """Ein noch unbekanntes Modul: dunkler Block, Glas, Beinchen - nur die LEDs nennen die Stufe."""
    r = cs.root("Modul")
    r.parent = parent
    g = dm.glow("r_" + grade, 3.0)
    led.rounded_box(r, "Block", (bv.ML, bv.MD, bv.MH), (0, 0, bv.MH * 0.5),
                    led.mat("Rohmodul", (0.07, 0.07, 0.1), 0.6, 0.35, clearcoat=0.3), 0.025, 0.012)
    led.rounded_box(r, "Glas", (bv.ML - 0.2, bv.MD - 0.09, 0.008), (0.04, 0, bv.MH), cv.m_glass(), 0.02, 0.0)
    cs.boxes(r, "Status", [(-bv.ML * 0.5 + 0.045, 0, bv.MH + 0.002, 0.03, bv.MD - 0.08, 0.006)], g)
    bv.leg(r, "Bein", bv.ML * 0.5, 0, 0.0, 0.16, cs.m_steel())
    cs.boxes(r, "Led", [(bv.ML * 0.5 + 0.035, 0, 0.172, 0.03, 0.11, 0.006)], g)
    r.location = (x - 0.09 * MS, y, z)
    r.scale = (MS, MS, MS)
    return r


def esd_mark(r, x, y, z, s=0.11):
    bv.poly(r, "Warnung", [(x - s, y - s * 0.8), (x + s, y - s * 0.8), (x, y + s * 0.9)], z, z + 0.004,
            dm.glow("warn", 1.6))
    cs.boxes(r, "WarnStrich", [(x, y - s * 0.1, z + 0.005, s * 0.16, s * 0.7, 0.003)],
             led.mat("Schwarz", (0.01, 0.01, 0.012), 0.0, 0.6))


def title(r, count, grade, x, y, z, size=0.085):
    cv.txt(r, "%dER MODUL-PAKET" % count, x, y, z, size, "weiss", 1.6)
    cv.txt(r, GRADES[grade], x, y - size * 1.45, z, size * 0.85, "r_" + grade, 2.4)


# --- a: Bauteil-Tray -----------------------------------------------------------------------

def tray(r, count, grade):
    esd = led.mat("EsdSchwarz", (0.025, 0.025, 0.035), 0.1, 0.55)
    led.rounded_box(r, "Traeger", (PW, PD, 0.1), (0, 0, 0.05), esd, 0.07, 0.015)
    # Waffel: Stege um jedes Nest, der Kopfstreifen rechts trägt die Aufschrift
    ribs = [(-0.13, 0, 0.14, 1.36, 0.03, 0.08)]
    ribs += [(-0.13, s * 0.165, 0.14, 1.36, 0.025, 0.08) for s in (-1, 1)]
    ribs += [(-0.13, s * 0.5, 0.14, 1.36, 0.03, 0.08) for s in (-1, 1)]
    ribs += [(x, 0, 0.14, 0.03, 1.03, 0.08) for x in (-0.81, -0.13, 0.55)]
    cs.boxes(r, "Waffel", ribs, esd)
    for k in range(6):
        x, y = nest(k)
        x = x - 0.13
        cs.boxes(r, "Nestgrund", [(x, y, 0.102, 0.6, 0.28, 0.004)],
                 dm.glow("r_" + grade, 0.5) if k < count else led.mat("NestLeer", (0.01, 0.01, 0.014), 0.0, 0.7))
        if k < count:
            mod(r, x, y, 0.1, grade)
    led.rounded_box(r, "Haube", (PW - 0.34, PD - 0.06, 0.34), (-0.13, 0, 0.27),
                    led.mat("Haube", (0.8, 0.9, 1.0), 0.0, 0.05, 0.0, 0.13, 1.0), 0.06, 0.03)
    # Kopfstreifen in der Stufe: eloxiertes Band mit Aufschrift
    led.rounded_box(r, "Band", (0.22, PD - 0.06, 0.05), (PW * 0.5 - 0.15, 0, 0.125),
                    led.mat("Band_" + grade, METAL[grade], 1.0, 0.28), 0.03, 0.01)
    cs.boxes(r, "Bandlicht", [(PW * 0.5 - 0.27, 0, 0.11, 0.02, PD - 0.14, 0.02)], dm.glow("r_" + grade, 2.6))
    for i in range(6):
        cs.boxes(r, "Zaehler", [(PW * 0.5 - 0.15, 0.4 - i * 0.16, 0.152, 0.1, 0.09, 0.006)],
                 led.mat("Schwarz", (0.01, 0.01, 0.012), 0.0, 0.6) if i < count else
                 led.mat("BandMatt_" + grade, tuple(c * 0.55 for c in METAL[grade]), 1.0, 0.4))
    esd_mark(r, -PW * 0.5 + 0.12, -PD * 0.5 + 0.11, 0.1, 0.07)


# --- b: Stangenmagazin ---------------------------------------------------------------------

def rohr(r, count, grade):
    clear = led.mat("Rohr", (0.75, 0.88, 1.0), 0.0, 0.05, 0.0, 0.16, 1.0)
    plug = led.mat("Stopfen_" + grade, METAL[grade], 0.4, 0.35, 0.6)
    for row in range(3):
        y = (1 - row) * 0.345
        led.rounded_box(r, "Rohr", (PW - 0.16, 0.31, 0.36), (0, y, 0.2), clear, 0.05, 0.04)
        cs.boxes(r, "Schiene", [(0, y, 0.035, PW - 0.2, 0.2, 0.03)],
                 led.mat("Schiene", (0.03, 0.03, 0.04), 0.3, 0.5))
        for s in (-1, 1):
            led.rounded_box(r, "Stopfen", (0.1, 0.33, 0.38), (s * (PW * 0.5 - 0.05), y, 0.2), plug, 0.04, 0.02)
        for col in range(2):
            k = row * 2 + col
            if k < count:
                mod(r, (col - 0.5) * 0.76, y, 0.05, grade)
    # zwei Klammern halten die Röhren, die vordere trägt das Etikett
    steel = led.mat("Klammer", (0.05, 0.05, 0.065), 0.8, 0.35)
    for x in (-0.02,):
        cs.boxes(r, "Klammer", [(x, 0, 0.4, 0.07, PD + 0.02, 0.03), (x, PD * 0.5, 0.2, 0.07, 0.03, 0.4),
                                (x, -PD * 0.5, 0.2, 0.07, 0.03, 0.4)], steel)
    cs.boxes(r, "Etikett", [(0.0, -PD * 0.5 - 0.016, 0.2, 1.0, 0.004, 0.26)],
             led.mat("EtikettSchwarz", (0.012, 0.012, 0.016), 0.0, 0.5))
    cs.boxes(r, "EtikettSaum", [(0.0, -PD * 0.5 - 0.019, 0.085, 1.0, 0.004, 0.025)], dm.glow("r_" + grade, 2.4))


# --- c: Modulkoffer ------------------------------------------------------------------------

def koffer(r, count, grade):
    shell = led.mat("Kofferschwarz", (0.02, 0.02, 0.028), 0.7, 0.3, clearcoat=0.5)
    trim = led.mat("Beschlag_" + grade, METAL[grade], 1.0, 0.25)
    led.rounded_box(r, "Schale", (PW, PD, 0.2), (0, 0, 0.1), shell, 0.09, 0.02)
    cs.boxes(r, "Wand", [(sx * (PW * 0.5 - 0.06), 0, 0.31, 0.12, PD, 0.22) for sx in (-1, 1)]
             + [(0, PD * 0.5 - 0.04, 0.31, PW, 0.08, 0.22), (0, -PD * 0.5 + 0.13, 0.31, PW, 0.26, 0.22)], shell)
    # Fenster: Rauchglas über der Schaum-Einlage
    led.rounded_box(r, "Schaum", (PW - 0.24, PD - 0.34, 0.02), (0, 0.09, 0.2),
                    led.mat("Schaum", (0.012, 0.012, 0.016), 0.0, 0.9), 0.05, 0.0)
    for k in range(6):
        x, y = nest(k)
        x, y = x * 0.9, y * 0.76 + 0.09
        cs.boxes(r, "Nest", [(x + 0.0, y, 0.212, 0.6, 0.22, 0.004)],
                 dm.glow("r_" + grade, 0.7) if k < count else led.mat("NestLeer", (0.004, 0.004, 0.006), 0.0, 0.8))
        if k < count:
            m = mod(r, x, y, 0.2, grade)
            m.scale = (MS * 0.86, MS * 0.86, MS * 0.6)
    cs.boxes(r, "Rahmen", cs.ring_items(0, 0.09, PW - 0.16, PD - 0.26, PW - 0.24, PD - 0.34, 0.415, 0.03), trim)
    led.rounded_box(r, "Rauchglas", (PW - 0.24, PD - 0.34, 0.012), (0, 0.09, 0.415),
                    led.mat("Rauchglas", (0.25, 0.28, 0.36), 0.0, 0.04, 0.0, 0.22, 1.0), 0.05, 0.0)
    # Front: LED-Zähler (so viele leuchten, wie Module darin sind) und der Verschluss
    for i in range(6):
        cs.boxes(r, "Zaehler", [(-0.6 + i * 0.13, -PD * 0.5 + 0.1, 0.423, 0.09, 0.05, 0.008)],
                 dm.glow("r_" + grade, 3.0) if i < count else cv.m_dim())
    led.rounded_box(r, "Verschluss", (0.3, 0.1, 0.05), (0.56, -PD * 0.5 + 0.1, 0.43), trim, 0.03, 0.012)
    cs.boxes(r, "Ecken", [(sx * (PW * 0.5 - 0.06), sy * (PD * 0.5 - 0.06), 0.21, 0.13, 0.13, 0.44)
                          for sx in (-1, 1) for sy in (-1, 1)], trim)
    cs.boxes(r, "Saum", [(0, -PD * 0.5 - 0.004, 0.26, PW - 0.3, 0.008, 0.02)], dm.glow("r_" + grade, 2.4))


VARIANTS = [("A · BAUTEIL-TRAY", tray), ("B · STANGENMAGAZIN", rohr), ("C · MODULKOFFER", koffer)]


def pack(build, count, grade, x, y):
    r = cs.root("Paket")
    build(r, count, grade)
    r.location = (x, y, 0.002)
    return r


def view_alle():
    for row, (name, build) in enumerate(VARIANTS):
        y = (1 - row) * 1.75
        ms.label(name, -4.1, y + 0.1, 0.15)
        for col, (count, grade) in enumerate(SETS):
            pack(build, count, grade, (col - 1) * 2.25 + 0.5, y)
            if row == 2:
                ms.label("%der · %s" % (count, GRADES[grade]), (col - 1) * 2.25 + 0.5, y - 0.82, 0.11)
    return [((0.0, -0.1, 0.1), (0.0, -5.0, 11.5), 50)]


def view_one(index):
    def run():
        name, build = VARIANTS[index]
        for col, (count, grade) in enumerate(SETS):
            pack(build, count, grade, (col - 1) * 2.1, 0)
        ms.label(name, 0.0, -0.95, 0.14)
        return [((0.0, -0.1, 0.2), (0.6, -4.4, 3.6), 50), ((2.1, 0.0, 0.2), (3.7, -2.3, 1.7), 50)]
    return run


VIEWS = {"0_alle": view_alle, "a_tray": view_one(0), "b_rohr": view_one(1), "c_koffer": view_one(2)}

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
