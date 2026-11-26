"""Fumble: ENTWURF für den SCHWARZMARKT als Bauteil auf dem Grundriß der Automaten (2026-11-26).
  a - LUKEN-DECK: schwarzes Lack-Deck im Stahlrahmen, drei gleiche Hub-Buchten mit violettem
      Leuchtboden, je Bucht Etikett-Display, Preis-Fenster und Kauf-Leiste, verkauft schließt
      ein Lamellen-Rolltor; unten die Taste NEU MISCHEN und der Abgang zum Hub.
Gebaut in Welt-Einheiten (Grundriß 28,5 × 17,7), gerendert mal S.

Aufruf (kopflos):
  blender -b -P tools/blender_secret_shop_variants.py -- <ausgabe-ordner> [ansicht,...]
Ansichten: a_schraeg, a_oben, a_detail, a_zustaende.
Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tisch Z = 0.
"""
import bpy, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms
import blender_chip_screens as cs
import blender_luck_variants as lv

led = dm.led
S = 0.12
W, H = 28.5, 17.7
BAY_W, BAY_H, BAY_PITCH, BAY_Y = 8.2, 7.4, 9.1, 2.45
WALL = 0.55
dm.HEX["energie"] = "#9d68ff"
dm.HEX["etikett"] = "#e9e4ff"
dm.HEX["cyan"] = "#40e6ff"
dm.HEX["rot"] = "#ff4d5e"
dm.HEX["sonder"] = "#c9a6ff"
dm.HEX["stahlblau"] = "#5fa8c8"
dm.HEX["selten"] = "#4aa8ff"
dm.HEX["episch"] = "#c26bff"


def ware(kind, name, price, **kw):
    return dict(kw, kind=kind, name=name, price=price)


def state(name, energy, bays, rerolls=0):
    return {"name": name, "energy": energy, "bays": bays, "rerolls": rerolls}


DISK = ware("disk", "QUECKSILBERLAMPE", 5, tint="selten")
ANGEBOT = state("ANGEBOT · Energie 9", 9, [DISK, ware("card", "GENERALSCHLÜSSEL", 4), ware("die", "ESSENZ · NEON", 9)])
KNAPP = state("VERKAUFT / ZU TEUER · Energie 3", 3,
              [dict(DISK, sold=True), ware("module", "VERSTÄRKERRÖHRE", 4), ware("card", "ROHLING", 3, blank=True)])
PROJEKTOR = state("PROJEKTOR-ANGEBOT · Energie 12", 12,
                  [dict(DISK, name="LEERER SOCKEL", tint="episch"), ware("projector", "PROJEKTOR", 10), None])
LEER = state("AUSVERKAUFT", 2, [dict(DISK, sold=True), dict(DISK, sold=True), dict(DISK, sold=True)])
STATES = [ANGEBOT, KNAPP, PROJEKTOR, LEER]


# --- Materialien ---------------------------------------------------------------------------

def m_steel():
    return led.mat("RahmenStahl", (0.62, 0.64, 0.68), 0.9, 0.3, 0.08)


def m_dark_steel():
    return led.mat("Lamelle", (0.16, 0.17, 0.2), 0.85, 0.36, 0.05)


def m_deck():
    return led.mat("LackDeck", (0.012, 0.011, 0.02), 0.0, 0.14, clearcoat=1.0)


def m_floor():
    return led.mat("Buchtboden", (0.02, 0.012, 0.045), 0.0, 0.25, clearcoat=0.6)


def m_etch():
    return led.mat("Laserschrift", (0.42, 0.42, 0.5), 0.0, 0.6, 0.25)


def violet(e):
    return dm.glow("energie", e)


def bolt(r, name, x, y, z, h, material):
    """Das Energie-Zeichen als Zickzack."""
    cs.strips(r, name, [[(x + 0.2 * h, y + 0.5 * h), (x - 0.18 * h, y - 0.04 * h), (x + 0.18 * h, y + 0.04 * h),
                         (x - 0.2 * h, y - 0.5 * h)]], 0.13 * h, z, material)


# --- Ware in ihrer echten Größe ----------------------------------------------------------------

def disk(r, x, y, z, tint):
    led.rounded_box(r, "Diskette", (6.39, 6.67, 0.23), (x, y, z + 0.115), m_steel(), 0.3, 0.05)
    cs.boxes(r, "Schieber", [(x + 0.4, y + 2.35, z + 0.24, 3.4, 1.75, 0.03)],
             led.mat("Chrom", (0.85, 0.86, 0.9), 1.0, 0.12, 0.1))
    cs.boxes(r, "SchieberFenster", [(x + 1.2, y + 2.35, z + 0.26, 0.8, 1.25, 0.02)], lv.m_mulde())
    cs.boxes(r, "Etikett", [(x, y - 1.0, z + 0.24, 5.4, 4.1, 0.03)], lv.m_glas())
    cs.boxes(r, "Bild", [(x, y - 0.25, z + 0.26, 4.9, 2.2, 0.02)], dm.glow(tint, 0.5))
    cs.boxes(r, "Zeilen", [(x - 0.6, y - 1.75 - i * 0.42, z + 0.26, 3.7 - i * 0.7, 0.16, 0.02) for i in range(2)],
             dm.glow("etikett", 0.9))
    cs.boxes(r, "Rar", [(x, y - 2.85, z + 0.26, 5.4, 0.22, 0.02)], dm.glow(tint, 2.2))


def card(r, x, y, z, blank):
    key = "stahlblau" if blank else "sonder"
    led.rounded_box(r, "Karte", (5.18, 3.46, 0.11), (x, y, z + 0.055),
                    led.mat("Platine_" + key, (0.02, 0.05, 0.07) if blank else (0.012, 0.012, 0.016), 0.0, 0.5), 0.2, 0.02)
    cell = 0.78
    cells = [(col, row) for row, col in dm.CROSS]
    for i, (c, w) in enumerate(cells):
        cx, cy = x - 0.5 + (c - 1.5) * cell, y + (1 - w) * cell
        cs.boxes(r, "Zelle%d" % i, cs.ring_items(cx, cy, cell - 0.08, cell - 0.08, cell - 0.22, cell - 0.22, z + 0.12, 0.02),
                 dm.glow(key, 0.6 if blank else 2.0))
        if not blank and i in (1, 3, 4):
            cs.boxes(r, "Wert%d" % i, [(cx, cy, z + 0.12, 0.3, 0.3, 0.02)], dm.glow(key, 2.4))
    cs.boxes(r, "Kontakte", [(x + 2.25, y - 1.2 + k * 0.3, z + 0.115, 0.42, 0.16, 0.02) for k in range(9)], cs.m_gold())


def die(r, x, y, z):
    edge = 1.7
    d = cs.root("Essenzwuerfel")
    d.parent = r
    led.rounded_box(d, "Koerper", (edge, edge, edge), (0, 0, 0),
                    led.mat("Essenz", (0.02, 0.2, 0.09), 0.0, 0.2, 0.3, clearcoat=1.0), 0.2, 0.18)
    cs.boxes(d, "Saum", cs.ring_items(0, 0, edge - 0.2, edge - 0.2, edge - 0.36, edge - 0.36, edge * 0.5 + 0.005, 0.01),
             dm.glow("zahl", 2.2))
    cs.text(d, "3", 0, 0, edge * 0.5 + 0.006, 1.0, dm.glow("etikett", 2.4), "Auge")
    d.location = (x, y, z + edge * 0.5 + 0.55)
    d.rotation_euler = (0.0, 0.0, 0.3)
    dm.annulus(r, "WuerfelLache", x, y, z + 0.012, 0.0, 1.05, dm.glow("zahl", 0.1), 48)


def module(r, x, y, z):
    led.rounded_box(r, "ModulBlock", (2.3, 1.68, 1.32), (x, y, z + 0.66),
                    led.mat("ModulSchale", (0.03, 0.03, 0.04), 0.2, 0.35, clearcoat=0.5), 0.14, 0.06)
    dm.cyl(r, "Roehre", 0.5, 0.5, (x - 0.25, y, z + 1.5), lv.m_glas(), 40)
    dm.cyl(r, "Gluehen", 0.26, 0.52, (x - 0.25, y, z + 1.5), dm.glow("bernstein", 2.4), 32)
    cs.boxes(r, "Bein", [(x + 1.4, y, z + 0.3, 0.5, 0.34, 0.6)], cs.m_steel())
    cs.boxes(r, "Schulter", [(x + 0.95, y + 0.5, z + 1.33, 0.22, 0.22, 0.02)], dm.glow("selten", 2.6))
    cs.boxes(r, "Strich", [(x, y - 0.72, z + 1.33, 1.6, 0.1, 0.02)], dm.glow("bernstein", 2.0))


def projector(r, x, y, z):
    led.rounded_box(r, "ProjSockel", (7.95, 5.68, 0.5), (x, y, z + 0.25), lv.m_lack(), 0.25, 0.06)
    led.rounded_box(r, "ProjKoerper", (7.5, 5.2, 1.5), (x, y, z + 1.25), lv.m_lack(), 0.3, 0.12)
    cs.boxes(r, "ProjPlatte", [(x, y + 0.35, z + 2.02, 6.6, 3.9, 0.06)], m_steel())
    dm.annulus(r, "ProjRing", x, y + 0.5, z + 2.07, 1.25, 1.75, led.mat("Chrom", (0.85, 0.86, 0.9), 1.0, 0.12, 0.1), 64)
    dm.annulus(r, "ProjLinse", x, y + 0.5, z + 2.06, 0.0, 1.25, lv.m_glas(), 64)
    dm.annulus(r, "ProjBereit", x, y + 0.5, z + 2.075, 1.05, 1.2, dm.glow("cyan", 0.9), 64)
    cs.boxes(r, "ProjSchlitz", [(x, y - 2.3, z + 1.2, 6.4, 0.7, 0.3)], lv.m_mulde())
    cs.boxes(r, "ProjUmriss", cs.ring_items(x, y, 7.6, 5.3, 7.4, 5.1, z + 0.52, 0.03), dm.glow("cyan", 0.8))


def place_ware(r, w, x, y, z):
    kind = w["kind"]
    if kind == "disk":
        disk(r, x, y, z, w["tint"])
    elif kind == "card":
        card(r, x, y, z, w.get("blank", False))
    elif kind == "die":
        die(r, x, y, z)
    elif kind == "module":
        module(r, x, y, z)
    else:
        projector(r, x, y, z)


# --- Das Deck ----------------------------------------------------------------------------------

def base(r):
    hx, hy, k = W * 0.5, H * 0.5, 0.9
    corners = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            corners.append([(sx * hx, sy * (hy - k)), (sx * hx, sy * hy), (sx * (hx - k), sy * hy)])
    cs.strips(r, "Ecken", corners, 0.07, 0.003, lv.m_silk())
    lv.silk(r, "U6 NICHT BESTÜCKT", -hx + 4.3, hy - 0.5, 0.5)
    # Abgang zum Hub: vier Spuren nach Bild-rechts
    ys = [-6.9 + i * 0.42 for i in range(4)]
    cs.strips(r, "HubBus", [[(hx - 1.0, y), (hx + 3.2, y)] for y in ys], 0.2, 0.004, lv.m_bahn())
    cs.strips(r, "HubLicht", [[(hx - 1.0, y), (hx + 3.2, y)] for y in ys[1:3]], 0.06, 0.008, violet(1.6))


def bay(r, i, w, energy):
    x, y = (i - 1) * BAY_PITCH, BAY_Y
    tag = "Bucht%d" % i
    shut = w is None or w.get("sold", False)
    afford = not shut and energy >= w["price"]
    cs.boxes(r, tag + "Wand", cs.ring_items(x, y, BAY_W + 0.4, BAY_H + 0.4, BAY_W, BAY_H, 0.3 + WALL * 0.5, WALL), m_steel())
    cs.boxes(r, tag + "Boden", [(x, y, 0.32, BAY_W, BAY_H, 0.04)], m_floor())
    if shut:
        n = 12
        step = BAY_H / n
        cs.boxes(r, tag + "Rolltor", [(x, y - BAY_H * 0.5 + (k + 0.5) * step, 0.3 + WALL - 0.08, BAY_W, step - 0.07, 0.08)
                                     for k in range(n)], m_dark_steel())
        cs.boxes(r, tag + "Griffleiste", [(x, y - BAY_H * 0.5 + 0.3, 0.3 + WALL - 0.02, 2.4, 0.2, 0.06)], m_steel())
    else:
        glowing = 1.3 if afford else 0.35
        pts = [lv.flat(x + (a - 7.5) * 0.5, y + (b - 6.5) * 0.5, 0.342) for a in range(16) for b in range(14)]
        lv.discs(r, tag + "Leuchtraster", pts, 0.05, violet(glowing * 0.7), 8)
        cs.boxes(r, tag + "Saum", cs.ring_items(x, y, BAY_W - 0.1, BAY_H - 0.1, BAY_W - 0.32, BAY_H - 0.32, 0.345, 0.012),
                 violet(glowing * 1.6))
        place_ware(r, w, x, y, 0.345)
    # Etikett-Display: der Name der Ware
    ly = y - BAY_H * 0.5 - 1.15
    led.rounded_box(r, tag + "EtikettRahmen", (BAY_W + 0.4, 1.3, 0.16), (x, ly, 0.38), m_steel(), 0.1, 0.03)
    cs.boxes(r, tag + "EtikettGlas", [(x, ly, 0.47, BAY_W + 0.1, 1.0, 0.02)], lv.m_glas())
    if w is not None and not w.get("sold", False):
        cs.text(r, w["name"], x, ly, 0.485, 0.62, dm.glow("etikett", 1.5 if afford else 0.6), tag + "Name")
    else:
        cs.text(r, "VERKAUFT" if w is not None else "— — —", x, ly, 0.485, 0.62, dm.glow("rot" if w is not None else "etikett", 0.7),
                tag + "Name")
    # Preis-Fenster und Kauf-Leiste
    py = ly - 1.75
    if not shut:
        tw = lv.seg_window(r, tag + "Preis", str(w["price"]), x - 0.5, py, 1.05, "energie", m_steel(), 0.3, 0.26)
        bolt(r, tag + "Blitz", x - 0.5 + tw * 0.5 + 0.75, py, 0.46, 1.25, violet(2.6 if afford else 0.5))
    bar = violet(2.6) if afford else (led.mat("LeisteAus", (0.03, 0.02, 0.05), 0.0, 0.3) if shut else violet(0.25))
    cs.boxes(r, tag + "Kaufleiste", [(x, y - BAY_H * 0.5 - 0.3, 0.34 + WALL, BAY_W - 0.6, 0.16, 0.05)], bar)


def build_a(r, st):
    base(r)
    hx = W * 0.5
    top, bottom = BAY_Y + BAY_H * 0.5 + 0.75, -H * 0.5 + 0.2
    cy, dh = (top + bottom) * 0.5, top - bottom
    led.rounded_box(r, "Rahmen", (W - 0.3, dh, 0.3), (0, cy, 0.15), m_steel(), 0.45, 0.05)
    led.rounded_box(r, "Deck", (W - 0.8, dh - 0.5, 0.06), (0, cy, 0.31), m_deck(), 0.3, 0.01)
    cs.boxes(r, "DeckSaum", cs.ring_items(0, cy, W - 0.86, dh - 0.56, W - 1.0, dh - 0.7, 0.345, 0.012), violet(0.9))
    for i, w in enumerate(st["bays"]):
        bay(r, i, w, st["energy"])
    # Fußband: Taste NEU MISCHEN links, Gravur mittig, Kontaktleiste zum Hub rechts
    fy = -7.1
    can = st["energy"] >= 3
    kx = -BAY_PITCH
    led.rounded_box(r, "TasteSockel", (5.6, 1.9, 0.3), (kx - 1.1, fy, 0.45), m_steel(), 0.3, 0.05)
    led.rounded_box(r, "TasteKappe", (5.1, 1.4, 0.3), (kx - 1.1, fy, 0.65), lv.m_lack(), 0.25, 0.08)
    dm.annulus(r, "TastePfeil", kx - 2.9, fy, 0.81, 0.3, 0.42, violet(2.4 if can else 0.4), 40)
    cs.boxes(r, "TastePfeilSpitze", [(kx - 2.48, fy + 0.12, 0.81, 0.3, 0.3, 0.012)], violet(2.4 if can else 0.4))
    cs.text(r, "NEU MISCHEN", kx - 0.55, fy, 0.81, 0.5, dm.glow("etikett", 1.4 if can else 0.5), "TasteText")
    tw = lv.seg_window(r, "MischPreis", "3", kx + 2.75, fy, 0.8, "energie", m_steel(), 0.3, 0.2)
    bolt(r, "MischBlitz", kx + 2.75 + tw * 0.5 + 0.55, fy, 0.46, 0.95, violet(2.6 if can else 0.5))
    cs.text(r, "SCHWARZMARKT", 2.2, fy, 0.345, 0.7, m_etch(), "Gravur")
    cs.boxes(r, "Luefter", [(7.0 + k * 0.42, fy, 0.345, 0.16, 1.2, 0.012) for k in range(8)], lv.m_mulde())
    cs.boxes(r, "HubKontakte", [(hx - 1.1, -6.9 + i * 0.42, 0.36, 1.2, 0.26, 0.04) for i in range(4)], cs.m_gold())


def shut_of(w):
    return w is None or w.get("sold", False)


def name_plate(r, tag, w, afford, x, y, z):
    """Etikett-Display mit Stahl-Einfassung: der Name der Ware."""
    led.rounded_box(r, tag + "EtikettRahmen", (BAY_W + 0.4, 1.3, 0.16), (x, y, z + 0.08), m_steel(), 0.1, 0.03)
    cs.boxes(r, tag + "EtikettGlas", [(x, y, z + 0.17, BAY_W + 0.1, 1.0, 0.02)], lv.m_glas())
    if shut_of(w):
        cs.text(r, "VERKAUFT" if w is not None else "— — —", x, y, z + 0.185, 0.62,
                dm.glow("rot" if w is not None else "etikett", 0.7), tag + "Name")
    else:
        cs.text(r, w["name"], x, y, z + 0.185, 0.62, dm.glow("etikett", 1.5 if afford else 0.6), tag + "Name")


def light_floor(r, tag, x, y, z, afford):
    glowing = 1.3 if afford else 0.35
    cs.boxes(r, tag + "Boden", [(x, y, z - 0.02, BAY_W, BAY_H, 0.04)], m_floor())
    pts = [lv.flat(x + (a - 7.5) * 0.5, y + (b - 6.5) * 0.5, z + 0.002) for a in range(16) for b in range(14)]
    lv.discs(r, tag + "Leuchtraster", pts, 0.05, violet(glowing * 0.7), 8)
    cs.boxes(r, tag + "Saum", cs.ring_items(x, y, BAY_W - 0.1, BAY_H - 0.1, BAY_W - 0.32, BAY_H - 0.32, z + 0.005, 0.012),
             violet(glowing * 1.6))


def reroll(r, x, y, z, can):
    led.rounded_box(r, "TasteSockel", (5.6, 1.9, 0.3), (x, y, z + 0.15), m_steel(), 0.3, 0.05)
    led.rounded_box(r, "TasteKappe", (5.1, 1.4, 0.3), (x, y, z + 0.35), lv.m_lack(), 0.25, 0.08)
    dm.annulus(r, "TastePfeil", x - 1.8, y, z + 0.51, 0.3, 0.42, violet(2.4 if can else 0.4), 40)
    cs.boxes(r, "TastePfeilSpitze", [(x - 1.38, y + 0.12, z + 0.51, 0.3, 0.3, 0.012)], violet(2.4 if can else 0.4))
    cs.text(r, "NEU MISCHEN", x + 0.55, y, z + 0.51, 0.5, dm.glow("etikett", 1.4 if can else 0.5), "TasteText")
    tw = lv.seg_window(r, "MischPreis", "3", x + 3.85, y, 0.8, "energie", m_steel(), z, 0.2)
    bolt(r, "MischBlitz", x + 3.85 + tw * 0.5 + 0.55, y, z + 0.16, 0.95, violet(2.6 if can else 0.5))


# --- B · DREI SOCKEL: keine eigene Platte, drei Sockel auf der Massefläche -------------------

def build_b(r, st):
    hx, hy, k = W * 0.5, H * 0.5, 0.9
    corners = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            corners.append([(sx * hx, sy * (hy - k)), (sx * hx, sy * hy), (sx * (hx - k), sy * hy)])
    cs.strips(r, "Ecken", corners, 0.07, 0.003, lv.m_silk())
    lv.silk(r, "U6 NICHT BESTÜCKT", -hx + 4.3, hy - 0.5, 0.5)
    by = -6.6
    any_afford = False
    for i, w in enumerate(st["bays"]):
        x, y = (i - 1) * BAY_PITCH - 0.35, 3.2
        tag = "Sockel%d" % i
        shut = shut_of(w)
        afford = not shut and st["energy"] >= w["price"]
        any_afford = any_afford or afford
        led.rounded_box(r, tag, (BAY_W + 0.5, BAY_H + 0.5, 0.5), (x, y, 0.25),
                        led.mat("SockelEpoxid", (0.016, 0.016, 0.022), 0.0, 0.4, clearcoat=0.4), 0.2, 0.04)
        cs.boxes(r, tag + "Beine", [(x + s * (BAY_W * 0.5 + 0.38), y - 3.3 + j * 0.55, 0.06, 0.34, 0.22, 0.1)
                                    for s in (-1, 1) for j in range(13)], cs.m_steel())
        cs.boxes(r, tag + "Pin1", [(x - BAY_W * 0.5 + 0.05, y + BAY_H * 0.5 + 0.05, 0.505, 0.26, 0.26, 0.01)], violet(2.2))
        if shut:
            cs.boxes(r, tag + "Boden", [(x, y, 0.5, BAY_W, BAY_H, 0.02)], lv.m_mulde())
            pts = [lv.flat(x + (a - 7.5) * 0.5, y + (b - 6.5) * 0.5, 0.512) for a in range(16) for b in range(14)]
            lv.discs(r, tag + "Kontakte", pts, 0.09, cs.m_gold(), 10)
        else:
            light_floor(r, tag, x, y, 0.52, afford)
            place_ware(r, w, x, y, 0.525)
        # der Hebel: zu = Ware verriegelt, offen = Sockel leer
        pivot = cs.root(tag + "Hebel")
        pivot.parent = r
        cs.boxes(pivot, "Stange", [(0, 3.2, 0, 0.3, 6.4, 0.26)], m_steel())
        dm.cyl(pivot, "Knauf", 0.36, 0.34, (0, 6.5, 0), lv.m_lack(), 40)
        dm.cyl(pivot, "KnaufLicht", 0.24, 0.36, (0, 6.5, 0),
               dm.glow("rot", 1.2) if shut else violet(2.6 if afford else 0.4), 40)
        cs.boxes(r, tag + "Lager", [(x + BAY_W * 0.5 + 0.75, y - BAY_H * 0.5 + 0.1, 0.25, 0.6, 0.6, 0.5)], m_steel())
        pivot.location = (x + BAY_W * 0.5 + 0.75, y - BAY_H * 0.5 + 0.1, 0.52)
        pivot.rotation_euler = (math.radians(65) if shut else 0, 0, 0)
        name_plate(r, tag, w, afford, x, y - BAY_H * 0.5 - 1.2, 0.0)
        # Preis-Chip mit Stich auf den Bus
        py = y - BAY_H * 0.5 - 3.3
        led.rounded_box(r, tag + "PreisChip", (4.6, 2.1, 0.3), (x, py, 0.15),
                        led.mat("SockelEpoxid", (0.016, 0.016, 0.022), 0.0, 0.4, clearcoat=0.4), 0.1, 0.03)
        cs.boxes(r, tag + "PreisBeine", [(x - 1.95 + j * 0.56, py + s * 1.15, 0.05, 0.2, 0.3, 0.08)
                                         for s in (-1, 1) for j in range(8)], cs.m_steel())
        if not shut:
            tw = lv.seg_window(r, tag + "Preis", str(w["price"]), x - 0.5, py, 1.05, "energie", None, 0.22, 0.2)
            bolt(r, tag + "Blitz", x - 0.5 + tw * 0.5 + 0.7, py, 0.31, 1.2, violet(2.6 if afford else 0.5))
        stubs = [[(x + d, py - 1.2), (x + d, by + 0.42 * (1 if d < 0 else 0))] for d in (-0.5, 0.5)]
        cs.strips(r, tag + "Stich", stubs, 0.2, 0.004, lv.m_bahn())
        cs.strips(r, tag + "StichLicht", stubs, 0.06, 0.008, violet(1.6 if afford else 0.2))
    bus = [[(-hx + 7.6, by + j * 0.42), (hx + 3.2, by + j * 0.42)] for j in range(2)]
    cs.strips(r, "Bus", bus, 0.2, 0.004, lv.m_bahn())
    cs.strips(r, "BusLicht", bus, 0.06, 0.008, violet(1.6 if any_afford else 0.3))
    reroll(r, -hx + 3.2, by - 0.9, 0.0, st["energy"] >= 3)
    lv.silk(r, "SCHWARZMARKT", 6.0, by - 1.2, 0.55)


# --- C · SCHUBFÄCHER: ein Gehäuse hinten, drei Fächer fahren zum Spieler aus ------------------

def build_c(r, st):
    base(r)
    hx = W * 0.5
    front, top = 3.9, 1.3
    led.rounded_box(r, "Gehaeuse", (W - 0.6, 4.6, top), (0, front + 2.3, top * 0.5), lv.m_lack(), 0.35, 0.1)
    cs.boxes(r, "Zierleiste", [(0, front + 0.12, top + 0.01, W - 1.4, 0.1, 0.02)], violet(1.2))
    cs.text(r, "SCHWARZMARKT", 0, front + 3.95, top + 0.005, 0.6, m_etch(), "Gravur")
    for i, w in enumerate(st["bays"]):
        x = (i - 1) * BAY_PITCH
        tag = "Fach%d" % i
        shut = shut_of(w)
        afford = not shut and st["energy"] >= w["price"]
        name_plate(r, tag, w, afford, x, front + 2.1, top)
        cs.boxes(r, tag + "Schacht", [(x, front + 0.02, 0.5, BAY_W + 0.5, 0.06, 0.9)], lv.m_mulde())
        cs.strips(r, tag + "Schienen", [[(x + s * 3.0, front), (x + s * 3.0, front - BAY_H - 0.6)] for s in (-1, 1)],
                  0.3, 0.012, m_dark_steel())
        out = 0.0 if shut else BAY_H + 0.4
        y = front - out + BAY_H * 0.5 + 0.2
        if not shut:
            cs.boxes(r, tag + "Wand", cs.ring_items(x, y, BAY_W + 0.4, BAY_H + 0.4, BAY_W, BAY_H, 0.3, 0.5), m_steel())
            light_floor(r, tag, x, y, 0.2, afford)
            place_ware(r, w, x, y, 0.205)
        # die Nase: Blende mit Griff und Preis, verkauft sitzt sie bündig am Gehäuse
        ny = front - out - 1.05
        led.rounded_box(r, tag + "Nase", (BAY_W + 0.4, 2.1, 0.7), (x, ny, 0.35), lv.m_lack(), 0.25, 0.08)
        cs.boxes(r, tag + "Griff", [(x, ny - 0.8, 0.72, 3.2, 0.22, 0.08)], m_steel())
        bar = dm.glow("rot", 1.0) if shut else violet(2.6 if afford else 0.25)
        cs.boxes(r, tag + "Leiste", [(x, ny + 0.88, 0.71, BAY_W - 0.4, 0.12, 0.02)], bar)
        if not shut:
            tw = lv.seg_window(r, tag + "Preis", str(w["price"]), x - 0.5, ny + 0.05, 0.95, "energie", m_steel(), 0.62, 0.2)
            bolt(r, tag + "Blitz", x - 0.5 + tw * 0.5 + 0.7, ny + 0.05, 0.78, 1.15, violet(2.6 if afford else 0.5))
    reroll(r, -hx + 3.4, -7.75, 0.0, st["energy"] >= 3)
    cs.boxes(r, "HubKontakte", [(hx - 1.1, -6.9 + i * 0.42, 0.02, 1.2, 0.26, 0.04) for i in range(4)], cs.m_gold())


VARIANTS = {"a": ("A · LUKEN-DECK", build_a), "b": ("B · DREI SOCKEL", build_b), "c": ("C · SCHUBFÄCHER", build_c)}


# --- Bühne und Ansichten -------------------------------------------------------------------

def station(key, st, x=0.0, y=0.0, scale=S):
    r = cs.root("Station_" + key)
    VARIANTS[key][1](r, st)
    r.location = (x, y, 0.001)
    r.scale = (scale, scale, scale)
    return r


def view(key, kind, out):
    cam, aim = lv.stage()
    path = os.path.join(out, "%s_%s.png" % (key, kind))
    if kind == "zustaende":
        k = 0.075
        for i, st in enumerate(STATES):
            x, y = (i % 2 - 0.5) * 2.5, (0.5 - i // 2) * 1.75
            station(key, st, x, y, k)
            ms.label(st["name"], x, y - 0.82, 0.075)
        lv.shoot(cam, aim, path, (0, -0.1, 0), (0, -2.2, 8.0), 50)
        return
    station(key, ANGEBOT)
    if kind == "schraeg":
        lv.shoot(cam, aim, path, (0, -0.05, 0), (0, -2.4, 6.4), 50)
    elif kind == "oben":
        lv.shoot(cam, aim, path, (0, 0, 0), (0, 0, 12), ortho=4.4)
    else:
        lv.shoot(cam, aim, path, (-0.9, 0.0, 0.1), (-1.2, -1.7, 2.3), 50)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
    out = argv[0]
    os.makedirs(out, exist_ok=True)
    only = argv[1].split(",") if len(argv) > 1 else []
    for job in ["%s_%s" % (k, v) for k in VARIANTS for v in ("schraeg", "oben", "detail", "zustaende")] + ["vergleich"]:
        if only and not any(job == o or job.startswith(o + "_") for o in only):
            continue
        if job == "vergleich":
            cam, aim = lv.stage()
            for i, key in enumerate(VARIANTS):
                y = (1 - i) * 1.62
                station(key, KNAPP, -1.25, y, 0.075)
                station(key, ANGEBOT, 1.25, y, 0.075)
                ms.label(VARIANTS[key][0], -2.95, y, 0.09)
            lv.shoot(cam, aim, os.path.join(out, "vergleich.png"), (-0.3, -0.1, 0), (-0.3, -2.4, 10.4), 50)
            continue
        key, kind = job.split("_")
        view(key, kind, out)
    print("ok")
