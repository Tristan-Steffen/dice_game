"""Fumble: ENTWURF für das LABOR unter dem Schwarzmarkt (2026-11-26).
Eine Station mit wechselndem Auftrag (Seelen-Transfer, Charm-Kopierer, Modul-Kopierer, Karten-Presse):
Einsatz hinein, Glückswürfel würfelt, sechs Runden-Lampen laufen voll, Ergebnis heraus.
  a - PRÜFSTAND: Lack-Deck im Stahlrahmen, Arbeitsbucht unter Glashaube, Anzeige links, Würfel und Start rechts.
  b - REAKTOR: runde Kammer auf der Massefläche, die sechs Runden als Leuchtring, Sockel als Satelliten.
  c - EINSCHUB: Gehäuse wie der Schwarzmarkt, EIN breites Fach fährt aus; läuft der Auftrag, ist es zu.
Gebaut in Welt-Einheiten (Grundriß 28 × 12), gerendert mal S.

Aufruf (kopflos):
  blender -b -P tools/blender_labor_variants.py -- <ausgabe-ordner> [ansicht,...]
Ansichten: a_schraeg, a_stationen, b_…, c_…, vergleich.
"""
import bpy, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms
import blender_chip_screens as cs
import blender_luck_variants as lv
import blender_secret_shop_variants as ss

led = dm.led
S = 0.12
W, H = 28.0, 12.0
BW, BH = ss.BAY_W, ss.BAY_H
dm.HEX["glueck"] = "#ffc24a"
dm.HEX["seele"] = "#40e6ff"
dm.HEX["gruen"] = "#50fa7b"

NAMES = {"seele": "SEELEN-TRANSFER", "charm": "CHARM-KOPIERER", "modul": "MODUL-KOPIERER", "karten": "KARTEN-PRESSE"}


def job(station, phase, roll=0, passed=0, price=0):
    return {"station": station, "phase": phase, "roll": roll, "passed": passed, "price": price}


LAEUFT = job("seele", "laeuft", 2, 1, 1)
STATES = [("SEELEN-TRANSFER · läuft, noch 3 Runden", LAEUFT),
          ("CHARM-KOPIERER · bereit, 2 Energie", job("charm", "bereit", 0, 0, 2)),
          ("MODUL-KOPIERER · fertig", job("modul", "fertig", 3, 3, 3)),
          ("KARTEN-PRESSE · läuft, noch 1 Runde", job("karten", "laeuft", 4, 1, 3))]


def violet(e):
    return ss.violet(e)


def gold(e):
    return dm.glow("glueck", e)


def m_hood():
    return led.mat("Haubenglas", (0.55, 0.6, 0.75), 0.0, 0.04, 0.0, 0.14, clearcoat=1.0)


def lit_of(st):
    return st["roll"] + st["passed"]


def lamp_mat(st, i):
    if i < st["roll"]:
        return gold(2.6)
    if i < lit_of(st):
        return violet(2.6)
    return led.mat("LampeAus", (0.03, 0.025, 0.05), 0.0, 0.3)


def status_text(st):
    if st["phase"] == "bereit":
        return "BEREIT"
    if st["phase"] == "fertig":
        return "FERTIG"
    return "NOCH %d" % (6 - lit_of(st))


# --- Einsatz je Station ------------------------------------------------------------------------

def seats(r, st, x, y, z):
    kind = st["station"]
    if kind == "seele":
        for s in (-1, 1):
            cs.boxes(r, "Sitz", cs.ring_items(x + s * 2.3, y, 2.6, 2.6, 2.3, 2.3, z + 0.01, 0.02), dm.glow("seele", 1.4))
            ss.die(r, x + s * 2.3, y, z)
        cs.strips(r, "SeelenPfeil", [[(x - 0.8, y), (x + 0.8, y)], [(x + 0.4, y + 0.4), (x + 0.8, y), (x + 0.4, y - 0.4)]],
                  0.14, z + 0.012, dm.glow("seele", 2.4))
    elif kind == "charm":
        ss.disk(r, x, y, z, "selten")
    elif kind == "modul":
        led.rounded_box(r, "ModulSockel", (3.4, 2.7, 0.2), (x, y, z + 0.1), cs.m_epoxy(), 0.15, 0.03)
        cs.boxes(r, "SockelBeine", [(x - 1.4 + j * 0.56, y + s * 1.45, z + 0.05, 0.2, 0.3, 0.08)
                                    for s in (-1, 1) for j in range(6)], cs.m_steel())
        ss.module(r, x, y, z + 0.2)
    else:
        for i in range(6):
            ss.card(r, x - 1.35 + i * 0.54, y + 1.5 - i * 0.6, z + i * 0.12, False)


def luck_seat(r, x, y, z, st, tag="Glueck"):
    """Sockel des Glückswürfels; solange der Auftrag läuft, liegt er mit seinem Wurf darauf."""
    led.rounded_box(r, tag + "Sockel", (3.0, 3.0, 0.3), (x, y, z + 0.15), lv.m_gold(), 0.3, 0.05)
    cs.boxes(r, tag + "Mulde", [(x, y, z + 0.3, 2.3, 2.3, 0.02)], lv.m_mulde())
    here = st["phase"] == "laeuft"
    cs.boxes(r, tag + "Ring", cs.ring_items(x, y, 2.3, 2.3, 2.05, 2.05, z + 0.315, 0.012),
             gold(2.4) if here else dm.glow("gruen", 0.8))
    if here:
        e = 1.53
        led.rounded_box(r, tag + "Wuerfel", (e, e, e), (x, y, z + 0.32 + e * 0.5), lv.m_die(), 0.18, 0.16)
        lv.pips_flat(r, tag, max(1, st["roll"]), x, y, z + 0.32 + e, e, "etikett")


def start_key(r, x, y, z, st, tag="Start"):
    ready = st["phase"] == "bereit"
    led.rounded_box(r, tag + "Sockel", (6.4, 2.0, 0.3), (x, y, z + 0.15), ss.m_steel(), 0.3, 0.05)
    led.rounded_box(r, tag + "Kappe", (5.9, 1.5, 0.3), (x, y, z + 0.35), lv.m_lack(), 0.25, 0.08)
    if ready:
        cs.text(r, "START", x - 1.3, y, z + 0.51, 0.62, dm.glow("etikett", 1.6), tag + "Text")
        tw = lv.seg_window(r, tag + "Preis", str(st["price"]), x + 1.2, y, 0.8, "energie", ss.m_steel(), z + 0.4, 0.2)
        ss.bolt(r, tag + "Blitz", x + 1.2 + tw * 0.5 + 0.5, y, z + 0.56, 0.95, violet(2.6))
    else:
        cs.text(r, "FERTIG" if st["phase"] == "fertig" else "LÄUFT", x, y, z + 0.51, 0.62,
                dm.glow("gruen" if st["phase"] == "fertig" else "etikett", 1.2 if st["phase"] == "fertig" else 0.5), tag + "Text")


def name_plate(r, x, y, z, st, width=8.6, tag="Name"):
    led.rounded_box(r, tag + "Rahmen", (width, 1.3, 0.16), (x, y, z + 0.08), ss.m_steel(), 0.1, 0.03)
    cs.boxes(r, tag + "Glas", [(x, y, z + 0.17, width - 0.3, 1.0, 0.02)], lv.m_glas())
    cs.text(r, NAMES[st["station"]], x, y, z + 0.185, 0.6, dm.glow("etikett", 1.5), tag + "Text")


def lamp_row(r, x, y, z, st, pitch=1.3, rad=0.42):
    for i in range(6):
        lx = x + (i - 2.5) * pitch
        dm.annulus(r, "LampeFassung%d" % i, lx, y, z + 0.004, rad, rad + 0.12, ss.m_steel(), 40)
        dm.annulus(r, "Lampe%d" % i, lx, y, z + 0.006, 0.0, rad, lamp_mat(st, i), 40)


def corners(r):
    hx, hy, k = W * 0.5, H * 0.5, 0.9
    cs.strips(r, "Ecken", [[(sx * hx, sy * (hy - k)), (sx * hx, sy * hy), (sx * (hx - k), sy * hy)]
                           for sx in (-1, 1) for sy in (-1, 1)], 0.07, 0.003, lv.m_silk())


# --- A · PRÜFSTAND -----------------------------------------------------------------------------

def build_a(r, st):
    corners(r)
    led.rounded_box(r, "Rahmen", (W - 0.3, H - 0.3, 0.3), (0, 0, 0.15), ss.m_steel(), 0.45, 0.05)
    led.rounded_box(r, "Deck", (W - 0.8, H - 0.8, 0.06), (0, 0, 0.31), ss.m_deck(), 0.3, 0.01)
    cs.boxes(r, "DeckSaum", cs.ring_items(0, 0, W - 0.86, H - 0.86, W - 1.0, H - 1.0, 0.345, 0.012), violet(0.9))
    by = 0.9
    cs.boxes(r, "BuchtWand", cs.ring_items(0, by, BW + 0.4, BH + 0.4, BW, BH, 0.3 + 0.35, 0.7), ss.m_steel())
    ss.light_floor(r, "Bucht", 0, by, 0.36, st["phase"] != "bereit")
    seats(r, st, 0, by, 0.365)
    if st["phase"] == "laeuft":
        cs.boxes(r, "Haube", [(0, by, 2.75, BW + 0.2, BH + 0.2, 0.06)], m_hood())
        cs.boxes(r, "HaubenRahmen", cs.ring_items(0, by, BW + 0.4, BH + 0.4, BW + 0.1, BH + 0.1, 2.75, 0.12), ss.m_steel())
        cs.boxes(r, "HaubenPfosten", [(sx * (BW * 0.5 + 0.12), by + sy * (BH * 0.5 + 0.12), 1.85, 0.16, 0.16, 1.7)
                                      for sx in (-1, 1) for sy in (-1, 1)], ss.m_steel())
    cs.text(r, "LABOR", 0, -H * 0.5 + 1.15, 0.345, 0.7, ss.m_etch(), "Gravur")
    lx = -9.4
    name_plate(r, lx, 3.4, 0.34, st, 7.6)
    lamp_row(r, lx, 0.9, 0.34, st)
    cs.text(r, "RUNDEN", lx, -0.4, 0.345, 0.42, ss.m_etch(), "RundenDruck")
    led.rounded_box(r, "StatusRahmen", (5.6, 1.7, 0.16), (lx, -2.6, 0.42), ss.m_steel(), 0.1, 0.03)
    cs.boxes(r, "StatusGlas", [(lx, -2.6, 0.51, 5.3, 1.4, 0.02)], lv.m_glas())
    cs.text(r, status_text(st), lx, -2.6, 0.525, 0.8, violet(2.2), "Status")
    rx = 9.4
    luck_seat(r, rx, 2.2, 0.34, st)
    cs.text(r, "GLÜCK", rx, 0.2, 0.345, 0.42, ss.m_etch(), "GlueckDruck")
    start_key(r, rx, -2.6, 0.34, st)


# --- B · REAKTOR -------------------------------------------------------------------------------

def arc(cx, cy, rad, a0, a1, n=10):
    return [(cx + math.cos(math.radians(a0 + (a1 - a0) * k / n)) * rad,
             cy + math.sin(math.radians(a0 + (a1 - a0) * k / n)) * rad) for k in range(n + 1)]


def build_b(r, st):
    corners(r)
    ri, ro = 4.85, 5.75
    dm.cyl(r, "KammerSockel", ro, 0.7, (0, 0, 0.35), lv.m_lack(), 96)
    dm.annulus(r, "KammerRing", 0, 0, 0.705, ri, ri + 0.22, ss.m_steel(), 96)
    dm.annulus(r, "KammerBoden", 0, 0, 0.703, 0.0, ri, ss.m_floor(), 96)
    run = st["phase"] != "bereit"
    pts = [lv.flat(a * 0.5, b * 0.5, 0.706) for a in range(-9, 10) for b in range(-9, 10) if (a * a + b * b) * 0.25 < (ri - 0.3) ** 2]
    lv.discs(r, "KammerRaster", pts, 0.05, violet(0.9 if run else 0.25), 8)
    seats(r, st, 0, 0, 0.71)
    # die sechs Runden als Ring: oben beginnend im Uhrzeigersinn
    for i in range(6):
        a1 = 90 - i * 60 - 4
        cs.strips(r, "Runde%d" % i, [arc(0, 0, ro - 0.36, a1, a1 - 52)], 0.36, 0.708, lamp_mat(st, i))
    if st["phase"] == "laeuft":
        dm.cyl(r, "Glocke", ri + 0.1, 2.3, (0, 0, 1.86), m_hood(), 96)
        dm.annulus(r, "GlockenRand", 0, 0, 3.02, ri - 0.15, ri + 0.12, ss.m_steel(), 96)
    # Satelliten auf der Massefläche, mit Stich zur Kammer
    lx, rx = -10.2, 10.2
    for name, pts in (("StichGlueck", [(lx + 1.6, 1.6), (-ro + 0.2, 1.6)]), ("StichStart", [(rx - 3.2, -2.6), (ro - 1.2, -2.6)]),
                      ("StichName", [(rx - 4.3, 2.6), (ro - 1.0, 2.6)])):
        for d in (-0.21, 0.21):
            line = [[(pts[0][0], pts[0][1] + d), (pts[1][0], pts[1][1] + d)]]
            cs.strips(r, name, line, 0.2, 0.004, lv.m_bahn())
            cs.strips(r, name + "Licht", line, 0.06, 0.008, violet(1.6 if run else 0.3))
    led.rounded_box(r, "GlueckChip", (4.4, 4.4, 0.3), (lx, 1.6, 0.15), cs.m_epoxy(), 0.2, 0.04)
    cs.boxes(r, "GlueckBeine", [(lx + s * 2.35, 1.6 - 1.65 + j * 0.55, 0.06, 0.34, 0.22, 0.1) for s in (-1, 1) for j in range(7)],
             cs.m_steel())
    luck_seat(r, lx, 1.6, 0.3, st)
    lv.silk(r, "GLÜCK", lx, -1.2, 0.5)
    led.rounded_box(r, "StatusChip", (5.0, 1.9, 0.3), (lx, -3.4, 0.15), cs.m_epoxy(), 0.1, 0.03)
    cs.boxes(r, "StatusGlas", [(lx, -3.4, 0.31, 4.6, 1.5, 0.02)], lv.m_glas())
    cs.text(r, status_text(st), lx, -3.4, 0.325, 0.75, violet(2.2), "Status")
    name_plate(r, rx - 0.3, 2.6, 0.0, st, 8.0)
    start_key(r, rx - 0.3, -2.6, 0.0, st)
    lv.silk(r, "LABOR", rx - 0.3, 4.6, 0.6)


# --- C · EINSCHUB ------------------------------------------------------------------------------

def build_c(r, st):
    corners(r)
    front, top, depth = 1.6, 1.5, 4.2
    led.rounded_box(r, "Gehaeuse", (W - 0.6, depth, top), (0, front + depth * 0.5, top * 0.5), lv.m_lack(), 0.35, 0.1)
    cs.boxes(r, "Zierleiste", [(0, front + 0.12, top + 0.01, W - 1.4, 0.1, 0.02)], violet(1.2))
    name_plate(r, -8.6, front + 2.6, top, st)
    cs.text(r, "LABOR", -8.6, front + 1.0, top + 0.005, 0.6, ss.m_etch(), "Gravur")
    lamp_row(r, 1.0, front + 2.6, top, st, 1.35, 0.46)
    cs.text(r, status_text(st), 1.0, front + 1.0, top + 0.005, 0.6, violet(2.0), "Status")
    luck_seat(r, 10.4, front + 2.2, top, st)
    # EIN breites Fach: draußen zum Laden und Abholen, zu solange der Auftrag läuft
    fw = BW + 3.0
    cs.boxes(r, "Schacht", [(0, front + 0.02, 0.6, fw + 0.5, 0.06, 1.1)], lv.m_mulde())
    out = 0.0 if st["phase"] == "laeuft" else BH + 0.4
    if out > 0.0:
        y = front - out + BH * 0.5 + 0.2
        cs.strips(r, "Schienen", [[(s * (fw * 0.5 - 1.0), front), (s * (fw * 0.5 - 1.0), front - BH - 0.6)] for s in (-1, 1)],
                  0.3, 0.012, ss.m_dark_steel())
        cs.boxes(r, "FachWand", cs.ring_items(0, y, fw + 0.4, BH + 0.4, fw, BH, 0.3, 0.5), ss.m_steel())
        cs.boxes(r, "FachBoden", [(0, y, 0.18, fw, BH, 0.04)], ss.m_floor())
        ss.light_floor(r, "Fach", 0, y, 0.2, st["phase"] == "fertig")
        seats(r, st, 0, y, 0.205)
    ny = front - out - 1.15
    led.rounded_box(r, "Nase", (fw + 0.4, 2.3, 0.9), (0, ny, 0.45), lv.m_lack(), 0.25, 0.08)
    cs.boxes(r, "Griff", [(-fw * 0.5 + 2.2, ny - 0.85, 0.92, 3.2, 0.22, 0.08)], ss.m_steel())
    bar = dm.glow("gruen", 1.6) if st["phase"] == "fertig" else violet(2.4 if st["phase"] == "bereit" else 0.6)
    cs.boxes(r, "Leiste", [(0, ny + 0.98, 0.91, fw - 0.4, 0.12, 0.02)], bar)
    start_key(r, 1.6, ny, 0.9, st)


# --- REAKTOR, zweite Runde: heller, ohne festen Sitz für den Glückswürfel -----------------------

dm.HEX["boden"] = "#b9a4ff"
WURF = job("seele", "wurf", 2, 0, 1)


def running(st):
    return st["phase"] in ("laeuft", "wurf")


def m_pearl():
    return led.mat("Perlweiss", (0.78, 0.78, 0.84), 0.0, 0.22, 0.12, clearcoat=1.0)


def m_brushed():
    return led.mat("StahlHell", (0.8, 0.82, 0.86), 0.9, 0.28, 0.1)


def lit_floor(r, ri, z, st):
    dm.annulus(r, "Leuchtboden", 0, 0, z, 0.0, ri, dm.glow("boden", 0.45 if st["phase"] != "bereit" else 0.28), 96)
    pts = [lv.flat(a * 0.5, b * 0.5, z + 0.003) for a in range(-10, 11) for b in range(-10, 11)
           if (a * a + b * b) * 0.25 < (ri - 0.3) ** 2]
    lv.discs(r, "Raster", pts, 0.06, dm.glow("etikett", 1.4), 8)


def ring_segments(r, rad, width, z, st, gap=5.0):
    for i in range(6):
        a = 90 - i * 60 - gap * 0.5
        cs.strips(r, "Runde%d" % i, [arc(0, 0, rad, a, a - 60 + gap, 14)], width, z, lamp_mat(st, i))


def luck_die(r, x, y, z, st):
    """Der Glückswürfel ist nur für den Wurf hier."""
    if st["phase"] != "wurf":
        return
    e = 1.53
    d = cs.root("Glueckswuerfel")
    d.parent = r
    led.rounded_box(d, "Koerper", (e, e, e), (0, 0, 0), lv.m_die(), 0.18, 0.16)
    lv.pips_flat(d, "Wurf", st["roll"], 0, 0, e * 0.5, e, "etikett")
    d.location = (x, y, z + e * 0.5)
    d.rotation_euler = (0, 0, 0.35)


def bright_trace(r, name, a, b, on):
    for d in (-0.21, 0.21):
        line = [[(a[0], a[1] + d), (b[0], b[1] + d)]]
        cs.strips(r, name, line, 0.2, 0.004, lv.m_bahn())
        cs.strips(r, name + "Licht", line, 0.08, 0.008, violet(2.4 if on else 0.8))


def status_chip(r, x, y, z, st, w=5.0):
    led.rounded_box(r, "StatusChip", (w, 1.9, 0.3), (x, y, z + 0.15), m_brushed(), 0.12, 0.04)
    cs.boxes(r, "StatusGlas", [(x, y, z + 0.31, w - 0.4, 1.5, 0.02)], lv.m_glas())
    cs.text(r, status_text(st), x, y, z + 0.325, 0.75, violet(2.6), "Status")


def glass_bell(r, ri, z0, h):
    dm.cyl(r, "Glocke", ri, h, (0, 0, z0 + h * 0.5), m_hood(), 96)
    dm.annulus(r, "GlockenRand", 0, 0, z0 + h + 0.01, ri - 0.2, ri + 0.1, m_brushed(), 96)


def build_r1(r, st):
    """LEUCHTTISCH: perlweißer Zylinder, breiter Rundenring, der Würfel fällt auf den Glasdeckel."""
    ri, ro, top = 4.85, 6.1, 0.8
    dm.cyl(r, "Sockel", ro, top, (0, 0, top * 0.5), m_pearl(), 96)
    dm.annulus(r, "Kragen", 0, 0, top + 0.004, ri, ri + 0.25, m_brushed(), 96)
    lit_floor(r, ri, top + 0.002, st)
    seats(r, st, 0, 0, top + 0.01)
    ring_segments(r, ro - 0.5, 0.55, top + 0.006, st)
    if running(st):
        glass_bell(r, ri + 0.1, top, 2.3)
    luck_die(r, 0, 0, top + 2.34, st)
    rx = 11.4
    bright_trace(r, "StichName", (rx - 4.2, 2.4), (ro - 0.8, 2.4), True)
    bright_trace(r, "StichStart", (rx - 3.2, -2.4), (ro - 0.8, -2.4), st["phase"] == "bereit")
    bright_trace(r, "StichStatus", (-9.4, 0), (-ro + 0.2, 0), running(st))
    name_plate(r, rx, 2.4, 0.0, st, 8.4)
    start_key(r, rx, -2.4, 0.0, st)
    status_chip(r, -10.6, 0, 0.0, st)
    lv.silk(r, "LABOR", -10.6, 1.9, 0.6)


def build_r2(r, st):
    """KRONE: sechs Lichtsäulen tragen den Deckel, Pult vorn, der Würfel fällt auf ein gedrucktes Feld."""
    ri, ro, top = 4.85, 5.6, 0.5
    dm.cyl(r, "Sockel", ro, top, (0, 0, top * 0.5), m_brushed(), 96)
    dm.annulus(r, "Kragen", 0, 0, top + 0.004, ri, ro - 0.1, m_pearl(), 96)
    lit_floor(r, ri, top + 0.002, st)
    seats(r, st, 0, 0, top + 0.01)
    for i in range(6):
        a = math.radians(60 - i * 60)
        px, py = math.cos(a) * (ro + 0.75), math.sin(a) * (ro + 0.75)
        dm.cyl(r, "SaeuleFuss%d" % i, 0.6, 0.3, (px, py, 0.15), m_brushed(), 40)
        dm.cyl(r, "Saeule%d" % i, 0.46, 2.3, (px, py, 1.45), lamp_mat(st, i), 40)
        dm.annulus(r, "SaeuleRing%d" % i, px, py, 2.605, 0.4, 0.56, m_brushed(), 40)
    if running(st):
        dm.cyl(r, "Deckel", ro + 0.1, 0.08, (0, 0, 2.5), m_hood(), 96)
        dm.annulus(r, "DeckelRand", 0, 0, 2.55, ro - 0.1, ro + 0.2, m_brushed(), 96)
    cy = -8.3
    led.rounded_box(r, "Pult", (16.6, 2.6, 0.5), (0, cy, 0.25), m_pearl(), 0.5, 0.1)
    cs.boxes(r, "PultLicht", [(0, cy + 1.2, 0.51, 15.6, 0.1, 0.02)], violet(2.2))
    name_plate(r, -3.7, cy, 0.5, st, 8.2)
    start_key(r, 4.7, cy, 0.5, st)
    status_chip(r, 0, 7.6, 0.0, st)
    wx, wy = 10.2, 0.0
    dm.annulus(r, "Wurfplatz", wx, wy, 0.004, 1.5, 1.62, lv.m_silk(), 64)
    lv.silk(r, "WURF", wx, wy - 2.2, 0.45)
    luck_die(r, wx, wy, 0.0, st)
    lv.silk(r, "LABOR", -9.6, 0, 0.6)


def build_r3(r, st):
    """SEKTOREN: flache Messing-Schale, die sechs Runden als breite Leuchtfelder um den Einsatz."""
    ri, ro, top = 4.75, 6.6, 0.5
    dm.cyl(r, "Schale", ro, top, (0, 0, top * 0.5), lv.m_gold(), 96)
    dm.annulus(r, "Feldgrund", 0, 0, top + 0.002, ri, ro - 0.25, lv.m_lack(), 96)
    ring_segments(r, (ri + ro - 0.25) * 0.5 + 0.02, ro - 0.25 - ri - 0.3, top + 0.006, st, 4.0)
    dm.annulus(r, "Kragen", 0, 0, top + 0.01, ri - 0.12, ri + 0.12, lv.m_gold(), 96)
    lit_floor(r, ri - 0.12, top + 0.004, st)
    seats(r, st, 0, 0, top + 0.012)
    if running(st):
        glass_bell(r, ri, top, 2.0)
    luck_die(r, 0, 0, top + 2.04, st)
    rx = 11.0
    bright_trace(r, "StichName", (rx - 4.0, 3.0), (ro - 1.0, 3.0), True)
    bright_trace(r, "StichStart", (rx - 3.2, 0.0), (ro - 0.1, 0.0), st["phase"] == "bereit")
    bright_trace(r, "StichStatus", (rx - 2.5, -3.0), (ro - 1.0, -3.0), running(st))
    name_plate(r, rx, 3.0, 0.0, st, 8.0)
    start_key(r, rx, 0.0, 0.0, st)
    status_chip(r, rx, -3.0, 0.0, st)
    lv.silk(r, "LABOR", rx, 4.7, 0.6)


def sector(r, name, r0, r1, a0, a1, z, material, n=16):
    verts, faces = [], []
    for k in range(n + 1):
        t = math.radians(a0 + (a1 - a0) * k / n)
        verts += [(math.cos(t) * r0, math.sin(t) * r0, z), (math.cos(t) * r1, math.sin(t) * r1, z)]
    for k in range(n):
        faces.append((k * 2, k * 2 + 1, k * 2 + 3, k * 2 + 2))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = r
    return o


# Maße des Spiel-Bauteils: Grundriß 28 × 10,6, die Schale ein Oval, die Runden auf den Flanken.
R4_DISH = (16.4, 10.2)
R4_X = -5.4
R4_FIELDS = (38.0, 5.4, 7.6)


def r4_angles(i):
    """Feld i im Uhrzeigersinn: 0-2 rechte Flanke von oben, 3-5 linke Flanke von unten."""
    half, _r0, _r1 = R4_FIELDS
    step = half * 2.0 / 3.0
    if i < 3:
        return half - i * step - 1.5, half - (i + 1) * step + 1.5
    j = i - 3
    return 180 + half - j * step - 1.5, 180 + half - (j + 1) * step + 1.5


def build_r4(r, st):
    """SEKTOREN im Spielmaß: ovale Messing-Schale, je drei Rundenfelder auf beiden Flanken."""
    corners_of(r, 28.0, 10.6)
    ri, top = 4.75, 0.5
    d = cs.root("Schale")
    d.parent = r
    d.location = (R4_X, 0, 0)
    led.rounded_box(d, "Koerper", (R4_DISH[0], R4_DISH[1], top), (0, 0, top * 0.5), lv.m_gold(), R4_DISH[1] * 0.5 - 0.01, 0.06)
    led.rounded_box(d, "Feldgrund", (R4_DISH[0] - 0.5, R4_DISH[1] - 0.5, 0.02), (0, 0, top + 0.002), lv.m_lack(),
                    R4_DISH[1] * 0.5 - 0.26, 0.004)
    for i in range(6):
        a0, a1 = r4_angles(i)
        sector(d, "Runde%d" % i, R4_FIELDS[1], R4_FIELDS[2], a0, a1, top + 0.016, lamp_mat(st, i))
    dm.annulus(d, "Kragen", 0, 0, top + 0.018, ri - 0.12, ri + 0.14, lv.m_gold(), 96)
    lit_floor(d, ri - 0.12, top + 0.014, st)
    seats(d, st, 0, 0, top + 0.02)
    if running(st):
        glass_bell(d, ri, top, 2.0)
    luck_die(d, 0, 0, top + 2.04, st)
    rx = 8.9
    edge = R4_X + R4_DISH[0] * 0.5
    bright_trace(r, "StichName", (rx - 4.0, 3.2), (edge - 1.6, 3.2), True)
    bright_trace(r, "StichStart", (rx - 3.2, 0.0), (edge - 0.1, 0.0), st["phase"] == "bereit")
    bright_trace(r, "StichStatus", (rx - 2.5, -3.2), (edge - 1.6, -3.2), running(st))
    name_plate(r, rx, 3.2, 0.0, st, 8.0)
    start_key(r, rx, 0.0, 0.0, st)
    status_chip(r, rx, -3.2, 0.0, st)
    lv.silk(r, "LABOR", rx, 4.75, 0.5)


def corners_of(r, w, h):
    hx, hy, k = w * 0.5, h * 0.5, 0.9
    cs.strips(r, "Ecken", [[(sx * hx, sy * (hy - k)), (sx * hx, sy * hy), (sx * (hx - k), sy * hy)]
                           for sx in (-1, 1) for sy in (-1, 1)], 0.07, 0.003, lv.m_silk())


REACTORS = {"r1": ("R1 · LEUCHTTISCH", build_r1), "r2": ("R2 · KRONE", build_r2), "r3": ("R3 · SEKTOREN", build_r3),
            "r4": ("R4 · SEKTOREN im Spielmaß", build_r4)}
FIRST = ("a", "b", "c")
VARIANTS = {"a": ("A · PRÜFSTAND", build_a), "b": ("B · REAKTOR", build_b), "c": ("C · EINSCHUB", build_c)}
VARIANTS.update(REACTORS)


def brighten():
    for o in bpy.data.objects:
        if o.type == "LIGHT":
            o.data.energy = 520


def reactor_sheet(out):
    cam, aim = lv.stage()
    brighten()
    for i, key in enumerate(REACTORS):
        y = (1 - i) * 1.75
        for j, st in enumerate((STATES[1][1], WURF, LAEUFT)):
            station(key, st, (j - 1) * 2.35 + 0.35, y, 0.07)
        ms.label(REACTORS[key][0], -3.95, y, 0.09)
    for j, title in enumerate(("bereit", "der Wurf", "läuft")):
        ms.label(title, (j - 1) * 2.35 + 0.35, 2.5, 0.09)
    lv.shoot(cam, aim, os.path.join(out, "reaktor.png"), (-0.3, -0.1, 0), (-0.3, -2.6, 11.4), 50)


def station(key, st, x=0.0, y=0.0, scale=S):
    r = cs.root("Labor_" + key)
    VARIANTS[key][1](r, st)
    r.location = (x, y, 0.001)
    r.scale = (scale, scale, scale)
    return r


def view(key, kind, out):
    cam, aim = lv.stage()
    if key in REACTORS:
        brighten()
    path = os.path.join(out, "%s_%s.png" % (key, kind))
    if kind == "stationen":
        k = 0.075
        for i, (title, st) in enumerate(STATES):
            x, y = (i % 2 - 0.5) * 2.5, (0.5 - i // 2) * 1.75
            station(key, st, x, y, k)
            ms.label(title, x, y - 0.82, 0.075)
        lv.shoot(cam, aim, path, (0, -0.1, 0), (0, -2.2, 8.0), 50)
        return
    station(key, WURF if key in REACTORS else LAEUFT)
    lv.shoot(cam, aim, path, (0, -0.05, 0), (0, -2.4, 6.4), 50)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
    out = argv[0]
    os.makedirs(out, exist_ok=True)
    only = argv[1].split(",") if len(argv) > 1 else []
    for job_name in ["%s_%s" % (k, v) for k in VARIANTS for v in ("schraeg", "stationen")] + ["vergleich", "reaktor"]:
        if only and not any(job_name == o or job_name.startswith(o + "_") for o in only):
            continue
        if job_name == "vergleich":
            cam, aim = lv.stage()
            for i, key in enumerate(FIRST):
                y = (1 - i) * 1.62
                station(key, STATES[1][1], -1.25, y, 0.075)
                station(key, LAEUFT, 1.25, y, 0.075)
                ms.label(VARIANTS[key][0], -2.95, y, 0.09)
            lv.shoot(cam, aim, os.path.join(out, "vergleich.png"), (-0.3, -0.1, 0), (-0.3, -2.4, 10.4), 50)
            continue
        if job_name == "reaktor":
            reactor_sheet(out)
            continue
        key, kind = job_name.split("_")
        view(key, kind, out)
    print("ok")
