"""Fumble: ENTWURF - die Station WETTEN als Bauteil der Platine (2026-11-24).
A Logikgatter, B Relais-Riegel, C Sicherungshalter; drei Wett-Module untereinander.

Aufruf (kopflos):
  blender -b -P tools/blender_bet_variants.py -- <ausgabe-ordner> [ansicht,...]
Ansichten: a_schraeg, a_oben, a_detail, a_zustaende (ebenso b_, c_) und vergleich.
Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tisch Z = 0; gebaut in Welt-Einheiten des Spiels.
"""
import bpy, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_chip_screens as cs

led = dm.led
glow = dm.glow
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
FONTS = "C:/Windows/Fonts/"

S = 0.2                         # Blender-Einheit je Welt-Einheit
FW, FH = 10.36, 15.20           # Grundriß der Station
PW, PH = 9.0, 4.3               # ein Wett-Plot
PITCH_Y = (FH - 3 * PH) / 4 + PH
CHIP_R, CHIP_T = 0.5, 0.13

dm.HEX.update({"auf": "#50fa7b", "rot": "#ff4757", "offen": "#8be9fd", "bern": "#ffb347",
               "oled": "#d6f1ff", "faden": "#d9ffe6", "glut": "#ff5a2a"})
CHIP_COL = {1: "#e9e9f2", 5: "#e8364f", 25: "#2fbf71"}

BETS = [dict(cond="Nimm ein Full House oder besser.", stake="$6", chips=[5, 1],
             prize=("karten", 2, "faktor"), seg="2× MULT", trade="$6 → 2 Multiplikator-Karten",
             stand=(2, 3)),
        dict(cond="Wirf drei Sechsen in einer Runde.", stake="$4", chips=[1, 1, 1, 1],
             prize=("chips", [5, 5, 1, 1]), seg="$12", trade="$4 → $12", stand=(3, 3)),
        dict(cond="Schaffe den Blind mit höchstens zwei Würfen.", stake="$8", chips=[5, 1, 1, 1],
             prize=("karten", 1, "rune"), seg="1 RUNE", trade="$8 → 1 Runen-Karte", stand=(2, 2))]
STATION_STATES = ["gesetzt", "erfuellt", "gescheitert"]
STATES = [("angebot", "ANGEBOT"), ("gesetzt", "GESETZT · Gewinn wartet"),
          ("erfuellt", "ERFÜLLT · Gewinn oben"), ("gescheitert", "GESCHEITERT")]


# --- Materialien -----------------------------------------------------------------------------

def mat(name, rgb, metal=0.0, rough=0.5, emit=0.0, alpha=1.0, cc=0.0):
    return led.mat(name, rgb, metal, rough, emit, alpha, cc)


def m_lack(): return mat("Lack", (0.012, 0.012, 0.016), 0.0, 0.22, 0.0, cc=0.9)
def m_graphit(): return mat("Graphit", (0.04, 0.042, 0.05), 0.4, 0.42, cc=0.3)
def m_steel(): return cs.m_steel()
def m_dsteel(): return mat("StahlDunkel", (0.28, 0.29, 0.32), 1.0, 0.34)
def m_bezel(): return mat("Einfassung", (0.035, 0.035, 0.04), 0.6, 0.35)
def m_win(): return mat("Fenster", (0.004, 0.005, 0.008), 0.0, 0.08, cc=1.0)
def m_paper(): return mat("EPaper", (0.70, 0.73, 0.68), 0.0, 0.7, 0.55)
def m_ink(): return mat("Tinte", (0.012, 0.013, 0.018), 0.0, 0.8)
def m_kapton(): return mat("Kapton", (0.6, 0.3, 0.04), 0.0, 0.35, 0.35)
def m_smoke(): return mat("Rauchglas", (0.03, 0.03, 0.045), 0.0, 0.04, 0.0, alpha=0.42)
def m_clear(): return mat("Klarglas", (0.7, 0.75, 0.8), 0.0, 0.02, 0.0, alpha=0.14)
def m_soot(): return mat("Russglas", (0.05, 0.035, 0.03), 0.0, 0.25, 0.0, alpha=0.8)
def m_hole(): return mat("Mulde", (0.004, 0.004, 0.006), 0.0, 0.8)
def m_silk(): return mat("Druck", (0.72, 0.78, 0.72), 0.0, 0.6, 0.5)
def m_ground(): return mat("Masse", (0.012, 0.05, 0.03), 0.1, 0.45, 0.5, cc=0.5)
def m_trace(): return mat("Zug", (0.03, 0.1, 0.055), 0.3, 0.35, 0.7)
def m_off(): return mat("ZugAus", (0.06, 0.07, 0.065), 0.4, 0.4, 0.2)
def m_ledoff(): return mat("LedAus", (0.07, 0.075, 0.08), 0.0, 0.3, 0.15)
def m_note(): return mat("Notiz", (0.62, 0.64, 0.7), 0.0, 0.6, 0.6)
def m_copper(on): return mat("Spule%d" % on, (0.8, 0.4, 0.18), 0.7, 0.3, 0.9 if on else 0.0)
def m_ceramic(): return mat("Keramik", (0.025, 0.026, 0.032), 0.0, 0.45, cc=0.4)


def m_chip(v, dim):
    c = led.lin(CHIP_COL[v])
    if dim:
        c = tuple(k * 0.3 for k in c)
    return mat("Chip%d%s" % (v, "d" if dim else ""), c, 0.0, 0.4, 0.12 if dim else 0.35, cc=0.5)


def m_card(key, dim):
    c = (0.55, 0.45, 0.3) if key == "rune" else (0.62, 0.6, 0.55)
    if dim:
        c = tuple(k * 0.3 for k in c)
    return mat("Karton_%s%d" % (key, dim), c, 0.0, 0.85, 0.25)


STATE_KEY = {"angebot": "bern", "gesetzt": "auf", "erfuellt": "auf", "gescheitert": "rot"}


# --- Bausteine --------------------------------------------------------------------------------

def pivot(parent, x, y, z):
    bpy.ops.object.empty_add(location=(x, y, z))
    p = bpy.context.active_object
    p.parent = parent
    return p


def rod(parent, name, r, length, loc, m, verts=48):
    o = dm.cyl(parent, name, r, length, loc, m, verts)
    o.rotation_euler = (0, math.radians(90), 0)
    return o


def txt(r, body, x, y, z, size, material, font="segoeuib.ttf", align="CENTER", space=1.0):
    bpy.ops.object.text_add(location=(x, y, z))
    t = bpy.context.active_object
    t.data.body = body
    t.data.size = size * (1.5 if font.startswith("seg") else 1.0)
    t.data.align_x = align
    t.data.align_y = "CENTER"
    t.data.space_line = space
    t.data.font = bpy.data.fonts.load(FONTS + font, check_existing=True)
    t.data.materials.append(material)
    t.parent = r
    return t


def wrap(s, n):
    out, line = [], ""
    for w in s.split():
        if line and len(line) + 1 + len(w) > n:
            out.append(line)
            line = w
        else:
            line = (line + " " + w).strip()
    out.append(line)
    return "\n".join(out)


def display(r, x, y, z0, w, h, kind, conn="s"):
    """Etikett-Display: Einfassung, Scheibe, Flexkabel samt Stecker. Gibt die Schrifthöhe zurück."""
    f = 0.09
    led.rounded_box(r, "Einfassung", (w + 2 * f, h + 2 * f, 0.08), (x, y, z0 + 0.04), m_bezel(), 0.06, 0.012)
    cs.boxes(r, "Scheibe", [(x, y, z0 + 0.085, w, h, 0.01)], m_paper() if kind == "paper" else m_win())
    fx, fy = {"s": (x + w * 0.3, y - h * 0.5 - f), "n": (x + w * 0.3, y + h * 0.5 + f),
              "w": (x - w * 0.5 - f, y), "e": (x + w * 0.5 + f, y)}[conn]
    sx, sy = (1, 0) if conn in "we" else (0, 1)
    sgn = -1 if conn in "sw" else 1
    fw = min(0.5, (h if sx else w) * 0.45)
    cs.boxes(r, "Flex", [(fx + sgn * sx * 0.16, fy + sgn * sy * 0.16, z0 + 0.012,
                          0.32 if sx else fw, fw if sx else 0.32, 0.016)], m_kapton())
    cs.boxes(r, "Stecker", [(fx + sgn * sx * 0.36, fy + sgn * sy * 0.36, z0 + 0.04,
                             0.12 if sx else fw + 0.1, fw + 0.1 if sx else 0.12, 0.08)], m_steel())
    return z0 + 0.096


def chip(r, x, y, z, v, dim=False, standing=False, top=True):
    o = dm.cyl(r, "Chip", CHIP_R, CHIP_T * 0.97, (x, y, z), m_chip(v, dim), 48)
    mark = mat("ChipMarke%d" % dim, (0.85, 0.85, 0.9) if not dim else (0.2, 0.2, 0.22), 0.0, 0.4, 0.4)
    if v == 1:
        mark = mat("ChipMarkeB%d" % dim, (0.1, 0.25, 0.9) if not dim else (0.03, 0.06, 0.2), 0.0, 0.4, 0.5)
    if standing:
        o.rotation_euler = (0, math.radians(90), 0)
        cs.boxes(r, "Randmarke", [(x, y + s * CHIP_R, z, CHIP_T, 0.05, 0.16) for s in (-1, 1)]
                 + [(x, y, z + s * CHIP_R, CHIP_T, 0.16, 0.05) for s in (-1, 1)], mark)
        return
    cs.boxes(r, "Randmarke", [(x + s * CHIP_R, y, z, 0.05, 0.16, CHIP_T) for s in (-1, 1)]
             + [(x, y + s * CHIP_R, z, 0.16, 0.05, CHIP_T) for s in (-1, 1)], mark)
    if top:
        dm.annulus(r, "Inlay", x, y, z + CHIP_T * 0.5 + 0.004, 0.26, 0.34, mark, 48)


def stack(r, x, y, z0, values, dim=False):
    for i, v in enumerate(values):
        chip(r, x, y, z0 + CHIP_T * (i + 0.5), v, dim, top=(i == len(values) - 1))


def data_card(r, x, y, z0, key, dim=False, portrait=False):
    w, h = (1.5, 2.3) if portrait else (2.3, 1.5)
    led.rounded_box(r, "Karte", (w, h, 0.05), (x, y, z0 + 0.025), m_card(key, dim), 0.1, 0.01)
    c = 0.3
    pos = dm.grid_pos(dm.CROSS, c, x, y, horizontal=not portrait)
    cs.boxes(r, "Netz", [(px, py, z0 + 0.056, c * 0.84, c * 0.84, 0.01) for px, py in pos],
             glow(key, 0.35 if dim else 2.2))


def prize(r, x, y, z0, bet, dim, portrait=False):
    kind = bet["prize"][0]
    if kind == "karten":
        n, key = bet["prize"][1], bet["prize"][2]
        for i in range(n):
            d = (i - (n - 1) * 0.5) * 0.14
            data_card(r, x + d, y - d, z0 + i * 0.06, key, dim, portrait)
        return
    vals = bet["prize"][1]
    half = (len(vals) + 1) // 2
    for k, part in enumerate((vals[:half], vals[half:])):
        off = (k - 0.5) * 1.1
        stack(r, x + (0 if portrait else off), y + (off if portrait else 0), z0, part, dim)


def leds(r, pts, z, n_on, key):
    for i, (px, py) in enumerate(pts):
        dm.cyl(r, "LED", 0.08, 0.05, (px, py, z + 0.025), glow(key, 2.6) if i < n_on else m_ledoff(), 24)


def trace_mat(on, fail=False):
    if fail:
        return glow("rot", 2.2)
    return glow("auf", 2.2) if on else m_off()


# --- A · LOGIKGATTER ---------------------------------------------------------------------------

def plot_a(r, cx, cy, bet, st):
    T = 0.28
    placed, won, fail = st != "angebot", st == "erfuellt", st == "gescheitert"
    led.rounded_box(r, "ModulA", (PW, PH, T), (cx, cy, T * 0.5), m_lack(), 0.3, 0.04)
    cs.boxes(r, "Zierlinie", cs.ring_items(cx, cy, PW - 0.3, PH - 0.3, PW - 0.36, PH - 0.36, T + 0.002, 0.004),
             m_dsteel())
    # Einsatz-Sockel mit Federclips
    sx, sy = cx - 3.0, cy - 0.35
    dm.cyl(r, "Sockel", 0.86, 0.1, (sx, sy, T + 0.05), m_steel(), 64)
    dm.cyl(r, "Mulde", 0.68, 0.104, (sx, sy, T + 0.052), m_hole(), 64)
    dm.annulus(r, "SockelLicht", sx, sy, T + 0.106, 0.69, 0.76, glow(STATE_KEY[st], 2.2), 64)
    cs.boxes(r, "Federclip", [(sx + s * 0.6, sy, T + 0.17, 0.08, 0.26, 0.14) for s in (-1, 1)]
             + [(sx, sy + s * 0.6, T + 0.17, 0.26, 0.08, 0.14) for s in (-1, 1)], m_steel())
    if st in ("gesetzt", "erfuellt"):
        stack(r, sx, sy, T + 0.106, bet["chips"])
    zt = display(r, sx, cy + 1.62, T, 1.2, 0.5, "seg", "e")
    txt(r, bet["stake"], sx, cy + 1.62, zt + 0.008, 0.38, glow("bern", 0.6 if fail else 2.2), "consolab.ttf")
    # Bedingung auf dem E-Paper
    px, py = cx - 0.3, cy + 1.1
    zt = display(r, px, py, T, 3.2, 1.4, "paper", "s")
    txt(r, "BEDINGUNG", px - 1.5, py + 0.57, zt + 0.008, 0.1, m_ink(), "segoeuib.ttf", "LEFT")
    txt(r, wrap(bet["cond"], 21), px - 1.5, py - 0.1, zt + 0.008, 0.25, m_ink(), "seguisb.ttf", "LEFT", 0.9)
    # das UND-Gatter im Bestückungsdruck
    gx, gy, R = cx - 0.35, cy - 0.8, 0.42
    back = gx - 0.55
    arc = [(gx + R * math.cos(a), gy + R * math.sin(a))
           for a in [math.radians(90 - 180 * i / 16) for i in range(17)]]
    cs.strips(r, "Gatter", [[(back, gy + R), (back, gy - R)], [(back, gy + R), (gx, gy + R)],
                            [(back, gy - R), (gx, gy - R)], arc], 0.045, T + 0.002, m_silk())
    txt(r, "&", gx - 0.1, gy, T + 0.004, 0.24, m_silk())
    txt(r, "B", back - 0.18, gy + 0.36, T + 0.004, 0.16, m_silk())
    txt(r, "A", back - 0.18, gy - 0.4, T + 0.004, 0.16, m_silk())
    in_b, in_a, out = (back, gy + 0.2), (back, gy - 0.2), (gx + R, gy)
    bx, by = cx + 2.75, cy - 0.2
    cs.strips(r, "ZugA", [[(sx + 0.86, sy), (cx - 1.55, sy), (cx - 1.55, in_a[1]), in_a]], 0.1, T + 0.004,
              trace_mat(placed))
    cs.strips(r, "ZugB", [[(cx - 1.15, py - 0.79), (cx - 1.15, in_b[1]), in_b]], 0.1, T + 0.004,
              trace_mat(won, fail))
    cs.strips(r, "ZugAus", [[out, (bx - 1.45, gy)]], 0.1, T + 0.004, trace_mat(won, fail))
    n_on = bet["stand"][1] if won else (bet["stand"][0] if placed else 0)
    leds(r, [(cx - 0.75 + i * 0.3, cy + 0.02) for i in range(bet["stand"][1])], T, n_on,
         "rot" if fail else "auf")
    # Gewinn-Bucht unter der Rauchglas-Klappe
    cs.boxes(r, "BuchtRahmen", cs.ring_items(bx, by, 2.9, 2.3, 2.6, 2.0, T + 0.07, 0.14), m_steel())
    cs.boxes(r, "BuchtBoden", [(bx, by, T + 0.004, 2.6, 2.0, 0.008)], glow("gold", 0.5) if won else m_hole())
    lip = {"angebot": m_off(), "gesetzt": glow("offen", 1.2), "erfuellt": glow("gold", 2.4),
           "gescheitert": glow("rot", 0.9)}[st]
    cs.boxes(r, "BuchtLicht", cs.ring_items(bx, by, 2.6, 2.0, 2.48, 1.88, T + 0.012, 0.012), lip)
    if st == "gesetzt":
        prize(r, bx, by, T + 0.012, bet, True)
    if won:
        cs.boxes(r, "Hubteller", [(bx, by, T + 0.1, 2.5, 1.9, 0.04)], m_dsteel())
        prize(r, bx, by, T + 0.12, bet, False)
    # Scharnier rechts: offen steht die Klappe am Plot-Rand und deckt keine Anzeige
    piv = pivot(r, bx + 1.45, by, T + 0.15)
    cs.boxes(piv, "Klappe", [(-1.45, 0, 0.02, 2.86, 2.26, 0.035)], m_smoke())
    cs.boxes(piv, "KlappenRahmen", cs.ring_items(-1.45, 0, 2.88, 2.28, 2.7, 2.1, 0.045, 0.03), m_dsteel())
    dm.cyl(piv, "Scharnier", 0.06, 2.0, (0, 0, 0.02), m_steel(), 32).rotation_euler.x = math.radians(90)
    if won:
        piv.rotation_euler.y = math.radians(96)
    cs.boxes(r, "Riegelkasten", [(bx, by - 1.42, T + 0.08, 1.0, 0.3, 0.16)], m_graphit())
    bolt_y = by - 1.4 if won else by - 1.12
    cs.boxes(r, "Riegel", [(bx, bolt_y, T + 0.2, 0.3, 0.3, 0.08)], m_steel())
    leds(r, [(bx + 0.36, by - 1.42)], T + 0.16, 1, {"angebot": "offen", "gesetzt": "bern", "erfuellt": "auf",
                                                      "gescheitert": "rot"}[st])
    zt = display(r, bx, cy + 1.62, T, 1.9, 0.5, "seg", "w")
    txt(r, bet["seg"], bx, cy + 1.62, zt + 0.008, 0.34, glow("gold", 0.6 if fail else 2.2), "consolab.ttf")


# --- B · RELAIS-RIEGEL --------------------------------------------------------------------------

RAIL_H = 0.15


def rails_b(r, ox, oy):
    for x in (ox - 2.9, ox + 1.95):
        cs.boxes(r, "Tragschiene", [(x, oy, 0.02, 0.9, FH - 0.5, 0.04),
                                    (x - 0.36, oy, 0.09, 0.08, FH - 0.5, 0.12),
                                    (x + 0.36, oy, 0.09, 0.08, FH - 0.5, 0.12)], m_steel())
        cs.boxes(r, "Endhalter", [(x, oy + s * (FH * 0.5 - 0.35), 0.2, 1.1, 0.3, 0.4) for s in (-1, 1)],
                 m_graphit())


def plot_b(r, cx, cy, bet, st):
    placed, won, fail = st != "angebot", st == "erfuellt", st == "gescheitert"
    hx, hw, T = cx - 2.075, 4.85, RAIL_H + 0.9
    led.rounded_box(r, "Relaismodul", (hw, PH, 0.9), (hx, cy, RAIL_H + 0.45), m_graphit(), 0.18, 0.05)
    cs.boxes(r, "Rasthaken", [(x, cy + s * (PH * 0.5 + 0.06), RAIL_H + 0.1, 0.5, 0.14, 0.12)
                              for x in (cx - 2.9,) for s in (-1, 1)], m_steel())
    # OLED längs der Vorderkante
    oy_ = cy - 1.38
    zt = display(r, hx, oy_, T, 4.5, 1.15, "oled", "n")
    txt(r, wrap(bet["cond"], 34), hx - 2.12, oy_ + 0.2, zt + 0.008, 0.23, glow("oled", 1.5),
        "seguisb.ttf", "LEFT", 0.95)
    txt(r, bet["trade"], hx - 2.12, oy_ - 0.38, zt + 0.008, 0.2, glow("bern", 2.0), "seguisb.ttf", "LEFT")
    tag = {"angebot": ("ANGEBOT", "bern"), "gesetzt": ("Stand %d/%d" % bet["stand"], "auf"),
           "erfuellt": ("ERFÜLLT", "gold"), "gescheitert": ("GESCHEITERT", "rot")}[st]
    txt(r, tag[0], hx + 2.12, oy_ - 0.38, zt + 0.008, 0.2, glow(tag[1], 2.2), "segoeuib.ttf", "RIGHT")
    # Einwurf-Schlitz oben am Modul
    sx = cx - 3.95
    cs.boxes(r, "Schlitzplatte", [(sx, cy + 0.85, T + 0.025, 0.9, 2.2, 0.05)], m_steel())
    cs.boxes(r, "Schlitz", [(sx, cy + 0.6, T + 0.052, 0.2, 1.2, 0.01)], m_hole())
    cs.boxes(r, "SchlitzLicht", cs.ring_items(sx, cy + 0.6, 0.36, 1.36, 0.22, 1.22, T + 0.055, 0.01),
             glow(STATE_KEY[st], 2.2))
    zt = display(r, sx, cy + 1.66, T + 0.05, 0.62, 0.36, "seg", "e")
    txt(r, bet["stake"], sx, cy + 1.66, zt + 0.008, 0.28, glow("bern", 0.6 if fail else 2.2), "consolab.ttf")
    # Haube mit Relais
    hcx, hcy = cx - 1.575, cy + 0.85
    cs.boxes(r, "HaubenFuss", cs.ring_items(hcx, hcy, 3.55, 2.2, 3.35, 2.0, T + 0.03, 0.06), m_steel())
    cs.boxes(r, "Traeger", [(hcx, hcy, T + 0.01, 3.35, 2.0, 0.02)], m_ceramic())
    energized = st in ("gesetzt", "erfuellt")
    rod(r, "Spule", 0.38, 1.3, (cx - 2.45, cy + 1.25, T + 0.42), m_copper(energized))
    for dx in (-0.69, 0.69):
        rod(r, "Flansch", 0.46, 0.08, (cx - 2.45 + dx, cy + 1.25, T + 0.42), m_graphit())
    rod(r, "Kern", 0.18, 0.4, (cx - 1.6, cy + 1.25, T + 0.42), m_steel())
    cs.boxes(r, "Joch", [(cx - 2.45, cy + 0.72, T + 0.12, 1.6, 0.14, 0.2)], m_steel())
    # Anker: schwenkt in der Ebene, damit man den Spalt von oben sieht
    piv = pivot(r, cx - 1.65, cy + 0.55, T + 0.32)
    dm.cyl(piv, "Lager", 0.1, 0.12, (0, 0, -0.02), m_steel(), 24)
    cs.boxes(piv, "Anker", [(0.55, 0, 0, 1.1, 0.16, 0.08)], m_steel())
    cs.boxes(piv, "Kontakt", [(1.12, 0, 0, 0.12, 0.22, 0.12)], cs.m_gold())
    if not won:
        piv.rotation_euler.z = math.radians(-24)
    cs.boxes(r, "Festkontakt", [(cx - 0.4, cy + 0.55, T + 0.18, 0.18, 0.3, 0.32)], m_dsteel())
    cs.boxes(r, "FestkontaktGold", [(cx - 0.46, cy + 0.55, T + 0.32, 0.08, 0.24, 0.12)], cs.m_gold())
    if won:
        cs.boxes(r, "Bogen", [(cx - 0.52, cy + 0.55, T + 0.32, 0.1, 0.36, 0.02)], glow("auf", 4.0))
        cs.strips(r, "Strompfad", [[(cx - 0.4, cy + 0.38), (cx - 0.4, cy - 0.05), (cx + 0.6, cy - 0.05)]],
                  0.09, T + 0.022, glow("auf", 2.4))
    # Fahne im Haubenfenster
    cs.boxes(r, "Fahnenkasten", [(cx - 0.25, cy + 1.5, T + 0.15, 0.62, 0.7, 0.3)], m_graphit())
    flag = {"angebot": m_dsteel(), "gesetzt": glow("auf", 1.8), "erfuellt": glow("gold", 2.2),
            "gescheitert": glow("rot", 2.0)}[st]
    f = cs.boxes(r, "Fahne", [(0, 0, 0, 0.5, 0.06, 0.5)], flag)
    f.location = (cx - 0.25, cy + 1.5, T + 0.42)
    f.rotation_euler.x = math.radians(-55)
    led.rounded_box(r, "Haube", (3.38, 2.02, 0.78), (hcx, hcy, T + 0.06 + 0.39), m_clear(), 0.12, 0.08)
    # Hot-Swap-Schacht mit Schublade
    cgx = cx + 1.95
    cs.boxes(r, "Schacht", [(cgx, cy + s * 1.25, RAIL_H + 0.4, 2.9, 0.1, 0.8) for s in (-1, 1)]
             + [(cx + 0.55, cy, RAIL_H + 0.4, 0.1, 2.6, 0.8), (cgx, cy, RAIL_H + 0.01, 2.9, 2.6, 0.02)],
             m_dsteel())
    cs.boxes(r, "Dach", [(cx + 0.95, cy, RAIL_H + 0.83, 0.9, 2.6, 0.06),
                         (cx + 2.35, cy + 1.2, RAIL_H + 0.83, 1.9, 0.2, 0.06),
                         (cx + 2.35, cy - 1.2, RAIL_H + 0.83, 1.9, 0.2, 0.06),
                         (cx + 3.33, cy, RAIL_H + 0.83, 0.06, 2.6, 0.06)], m_steel())
    cs.boxes(r, "Lueftung", [(cx + 0.95, cy + (i - 3) * 0.32, RAIL_H + 0.865, 0.6, 0.08, 0.01) for i in range(7)],
             m_hole())
    cs.boxes(r, "Dachfenster", [(cx + 2.35, cy, RAIL_H + 0.83, 1.9, 2.2, 0.03)], m_smoke())
    dx = 1.75 if won else 0.0
    cs.boxes(r, "Schublade", [(cx + 1.93 + dx, cy, RAIL_H + 0.05, 2.75, 2.36, 0.06)]
             + [(cx + 1.93 + dx, cy + s * 1.15, RAIL_H + 0.2, 2.75, 0.06, 0.3) for s in (-1, 1)], m_hole())
    cs.boxes(r, "Front", [(cx + 3.38 + dx, cy, RAIL_H + 0.4, 0.15, 2.5, 0.8)], m_graphit())
    cs.boxes(r, "Griff", [(cx + 3.52 + dx, cy, RAIL_H + 0.45, 0.1, 1.2, 0.12)], m_steel())
    front_led = {"angebot": m_off(), "gesetzt": glow("bern", 2.2), "erfuellt": glow("auf", 2.6),
                 "gescheitert": glow("rot", 2.2)}[st]
    cs.boxes(r, "FrontLicht", [(cx + 3.38 + dx, cy, RAIL_H + 0.81, 0.08, 2.2, 0.02)], front_led)
    if st == "gesetzt":
        prize(r, cx + 2.35, cy, RAIL_H + 0.08, bet, True, portrait=True)
    if won:
        cs.boxes(r, "LadeLicht", cs.ring_items(cx + 2.35 + dx, cy, 1.75, 2.3, 1.6, 2.15, RAIL_H + 0.09, 0.01),
                 glow("gold", 2.4))
        prize(r, cx + 2.35 + dx, cy, RAIL_H + 0.1, bet, False, portrait=True)


# --- C · SICHERUNGSHALTER ---------------------------------------------------------------------

def plot_c(r, cx, cy, bet, st):
    placed, won, fail = st != "angebot", st == "erfuellt", st == "gescheitert"
    x0, x1, y0, y1 = cx - PW * 0.5, cx + PW * 0.5, cy - PH * 0.5, cy + PH * 0.5
    cs.strips(r, "Umriss", [[(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)]], 0.04, 0.002, m_silk())
    c1, c2, ty, tz = cx - 4.05, cx - 0.75, cy + 0.3, 0.95
    tx = (c1 + c2) * 0.5
    for x in (c1, c2):
        cs.boxes(r, "Pad", [(x, ty, 0.004, 0.95, 1.95, 0.008)], cs.m_gold())
        led.rounded_box(r, "Klemme", (0.7, 1.7, 0.5), (x, ty, 0.25), m_steel(), 0.08, 0.03)
        cs.boxes(r, "Gabel", [(x, ty + s * 0.7, 0.5 + 0.4, 0.62, 0.28, 0.8) for s in (-1, 1)], m_steel())
        for s in (-1, 1):
            dm.cyl(r, "Schraube", 0.12, 0.06, (x, ty + s * 0.7, 1.33), m_dsteel(), 24)
            cs.boxes(r, "Schlitz", [(x, ty + s * 0.7, 1.365, 0.2, 0.03, 0.01)], m_hole())
        rod(r, "Kappe", 0.66, 0.5, (x, ty, tz), m_steel())
    length = c2 - c1 - 0.5
    glass = m_soot() if fail else m_clear()
    if placed:
        vals = bet["chips"]
        for i, v in enumerate(vals):
            chip(r, tx + (i - (len(vals) - 1) * 0.5) * (CHIP_T + 0.05), ty, tz, v, fail, standing=True)
    fz = tz + 0.55
    if fail:
        rod(r, "Faden", 0.03, length * 0.42, (c1 + 0.25 + length * 0.21, ty, fz), mat("Kohle", (0.05, 0.04, 0.04)))
        rod(r, "Faden", 0.03, length * 0.42, (c2 - 0.25 - length * 0.21, ty, fz), mat("Kohle", (0.05, 0.04, 0.04)))
        for x in (tx - length * 0.08, tx + length * 0.08):
            dm.cyl(r, "Glut", 0.05, 0.06, (x, ty, fz), glow("glut", 3.0), 16)
    else:
        rod(r, "Faden", 0.03, length, (tx, ty, fz), glow("faden", 2.6) if placed else m_off(), 16)
    rod(r, "Patrone", 0.62, length, (tx, ty, tz), glass)
    n_on = 6 if won else (round(6 * bet["stand"][0] / bet["stand"][1]) if placed else 0)
    leds(r, [(c1 + 0.45 + i * (c2 - c1 - 0.9) / 5, ty - 1.05) for i in range(6)], 0.0, n_on,
         "rot" if fail else "auf")
    zt = display(r, tx, cy - 1.68, 0.0, 1.1, 0.42, "seg", "e")
    txt(r, bet["stake"], tx, cy - 1.68, zt + 0.008, 0.32, glow("bern", 0.6 if fail else 2.2), "consolab.ttf")
    cs.strips(r, "Stromkreis", [[(c2 + 0.36, ty), (cx + 0.4, ty)]], 0.22, 0.004,
              glow("rot", 1.0) if fail else (glow("auf", 2.2) if placed else m_off()))
    # der Tresor
    tsx, tw, th, H = cx + 2.425, 4.05, 4.0, 1.15
    cs.boxes(r, "Tresor", cs.ring_items(tsx, cy, tw, th, tw - 0.3, th - 0.3, H * 0.5, H), m_graphit())
    cs.boxes(r, "TresorBoden", [(tsx, cy, 0.04, tw - 0.3, th - 0.3, 0.08)], m_hole())
    if won:
        cs.boxes(r, "TresorLicht", cs.ring_items(tsx, cy, tw - 0.3, th - 0.3, tw - 0.45, th - 0.45, 0.09, 0.01),
                 glow("gold", 2.4))
    if st == "gesetzt":
        cs.boxes(r, "Zwischenboden", [(tsx - 0.65, cy - 0.95, 0.3, 2.6, 1.8, 0.5)], m_hole())
        prize(r, tsx - 0.65, cy - 0.95, 0.55, bet, True)
    if won:
        cs.boxes(r, "Hub", [(tsx - 0.65, cy - 0.95, 0.5, 0.5, 0.5, 0.8)], m_steel())
        cs.boxes(r, "Hubteller", [(tsx - 0.65, cy - 0.95, 0.92, 2.5, 1.7, 0.04)], m_dsteel())
        prize(r, tsx - 0.65, cy - 0.95, 0.95, bet, False)
    piv = pivot(r, tsx + (1.75 if won else 0.0), cy, H)
    wl, wr, wb, wt = -1.9, 0.6, -1.75, -0.15
    cs.boxes(piv, "Deckel", [(0, (wt + 2.0) * 0.5, 0.06, tw, 2.0 - wt, 0.12),
                             (0, (wb - 2.0) * 0.5, 0.06, tw, 2.0 + wb, 0.12),
                             ((wl - 2.025) * 0.5, (wb + wt) * 0.5, 0.06, 2.025 + wl, wt - wb, 0.12),
                             ((wr + 2.025) * 0.5, (wb + wt) * 0.5, 0.06, 2.025 - wr, wt - wb, 0.12)], m_dsteel())
    cs.boxes(piv, "Sichtfenster", [((wl + wr) * 0.5, (wb + wt) * 0.5, 0.07, wr - wl, wt - wb, 0.02)], m_smoke())
    zt = display(piv, 0, 1.05, 0.12, 3.6, 1.45, "oled", "w")
    txt(piv, wrap(bet["cond"], 27), -1.72, 1.2, zt + 0.008, 0.24, glow("oled", 1.5), "seguisb.ttf", "LEFT", 0.95)
    txt(piv, "→ " + bet["trade"].split("→ ")[1], -1.72, 0.52, zt + 0.008, 0.2, glow("gold", 2.0),
        "seguisb.ttf", "LEFT")
    # Schloßring
    lx, ly = 1.35, -0.95
    dm.cyl(piv, "Schloss", 0.58, 0.1, (lx, ly, 0.17), m_steel(), 48)
    dm.cyl(piv, "SchlossKern", 0.38, 0.104, (lx, ly, 0.172), m_hole(), 48)
    ring = {"angebot": "bern", "gesetzt": "offen", "erfuellt": "gold", "gescheitert": "rot"}[st]
    dm.annulus(piv, "SchlossLicht", lx, ly, 0.226, 0.39, 0.47, glow(ring, 2.4), 48)
    cs.boxes(piv, "Kerben", [(lx + 0.52 * math.cos(a), ly + 0.52 * math.sin(a), 0.23, 0.08, 0.08, 0.02)
                             for a in [math.radians(45 + 90 * i) for i in range(4)]], m_dsteel())
    bar = cs.boxes(piv, "Zunge", [(0, 0, 0, 0.6, 0.1, 0.04)], m_steel())
    bar.location = (lx, ly, 0.24)
    bar.rotation_euler.z = math.radians(90 if won else 0)


# --- Runde 2: drei Fassungen des Gatters --------------------------------------------------------

LIVE = {"angebot": "bern", "gesetzt": "offen", "erfuellt": "auf", "gescheitert": "rot"}


def prism(r, name, pts, z0, z1, material):
    n = len(pts)
    verts = [(x, y, z) for z in (z0, z1) for x, y in pts]
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = r
    return o


def gate_pts(x0, x1, cy, h, inset=0.0):
    """Umriß eines UND-Gatters: links flach, rechts der Bogen."""
    rr = h * 0.5 - inset
    pts = [(x0 + inset, cy - rr), (x1 - h * 0.5, cy - rr)]
    pts += [(x1 - h * 0.5 + rr * math.cos(a), cy + rr * math.sin(a))
            for a in [math.radians(-90 + 180 * i / 20) for i in range(1, 20)]]
    pts += [(x1 - h * 0.5, cy + rr), (x0 + inset, cy + rr)]
    return pts


def socket2(r, x, y, bet, st, label_y):
    """Einsatz-Sockel: Stahlring, Zustandslicht, der Stapel liegt nur, solange die Wette läuft."""
    dm.cyl(r, "Sockel", 0.92, 0.16, (x, y, 0.08), m_steel(), 64)
    dm.cyl(r, "Mulde", 0.7, 0.164, (x, y, 0.082), m_hole(), 64)
    dm.annulus(r, "SockelLicht", x, y, 0.166, 0.72, 0.82, glow(LIVE[st], 2.2), 64)
    if st == "gesetzt":
        stack(r, x, y, 0.166, bet["chips"])
    txt(r, "EINSATZ", x, label_y, 0.003, 0.2, m_silk(), "consolab.ttf")
    zt = display(r, x, label_y - 0.55, 0.0, 1.1, 0.46, "seg", "e")
    txt(r, bet["stake"], x, label_y - 0.55, zt + 0.008, 0.34, glow("bern", 0.6 if st == "gescheitert" else 2.2),
        "consolab.ttf")


def bay2(r, x, y, bet, st, w=2.7, h=2.1):
    """Gewinn-Bucht: unter Rauchglas, bis sie verdient ist; dann offen, angehoben, golden."""
    won = st == "erfuellt"
    cs.boxes(r, "BuchtRahmen", cs.ring_items(x, y, w + 0.3, h + 0.3, w, h, 0.09, 0.18), m_steel())
    cs.boxes(r, "BuchtBoden", [(x, y, 0.004, w, h, 0.008)], glow("gold", 0.5) if won else m_hole())
    lip = {"angebot": m_off(), "gesetzt": glow("offen", 1.2), "erfuellt": glow("gold", 2.6),
           "gescheitert": glow("rot", 0.9)}[st]
    cs.boxes(r, "BuchtLicht", cs.ring_items(x, y, w, h, w - 0.12, h - 0.12, 0.014, 0.012), lip)
    if st == "gesetzt":
        prize(r, x, y, 0.014, bet, True)
        cs.boxes(r, "Glas", [(x, y, 0.2, w + 0.1, h + 0.1, 0.03)], m_smoke())
    elif won:
        cs.boxes(r, "Hubteller", [(x, y, 0.16, w - 0.1, h - 0.1, 0.04)], m_dsteel())
        prize(r, x, y, 0.18, bet, False)
    else:
        cs.boxes(r, "Glas", [(x, y, 0.2, w + 0.1, h + 0.1, 0.03)], m_smoke())
    txt(r, "GEWINN", x, y + h * 0.5 + 0.42, 0.003, 0.2, m_silk(), "consolab.ttf")


def progress(r, x, y, z, bet, st):
    n = bet["stand"][1]
    on = n if st == "erfuellt" else (bet["stand"][0] if st != "angebot" else 0)
    leds(r, [(x + (i - (n - 1) * 0.5) * 0.34, y) for i in range(n)], z, on,
         "rot" if st == "gescheitert" else "auf")


def plot_d(r, cx, cy, bet, st):
    """GATTER-CHIP: Einsatz - großes Gatter mit der Bedingung auf dem Deckel - Gewinn, EINE Zeile."""
    placed, won, fail = st != "angebot", st == "erfuellt", st == "gescheitert"
    sx, bx = cx - 3.55, cx + 3.0
    socket2(r, sx, cy + 0.25, bet, st, cy - 1.15)
    gx0, gx1, gh, T = cx - 2.0, cx + 1.25, 2.9, 0.42
    prism(r, "Gatter", gate_pts(gx0, gx1, cy, gh), 0.06, T, m_lack())
    prism(r, "GatterSaum", gate_pts(gx0, gx1, cy, gh, 0.07), T, T + 0.012, glow(LIVE[st], 1.8))
    prism(r, "GatterDeckel", gate_pts(gx0, gx1, cy, gh, 0.15), T + 0.012, T + 0.02, m_win())
    txt(r, "WENN", gx0 + 0.35, cy + 0.98, T + 0.024, 0.15, glow(LIVE[st], 1.6), "consolab.ttf", "LEFT")
    txt(r, wrap(bet["cond"], 17), gx0 + 0.35, cy + 0.1, T + 0.024, 0.27, glow("oled", 1.9), "seguisb.ttf",
        "LEFT", 0.9)
    progress(r, cx - 0.65, cy - 1.02, T + 0.02, bet, st)
    # Beinchen: A vom Einsatz, B vom Würfel-Bus, rechts der Ausgang
    ya, yb = cy - 0.55, cy + 0.75
    cs.boxes(r, "Beine", [(gx0 - 0.2, ya, 0.1, 0.5, 0.3, 0.12), (gx0 - 0.2, yb, 0.1, 0.5, 0.3, 0.12),
                          (gx1 + 0.2, cy, 0.1, 0.5, 0.3, 0.12)], m_steel())
    cs.strips(r, "ZugA", [[(sx + 0.92, cy + 0.25), (gx0 - 0.75, cy + 0.25), (gx0 - 0.75, ya), (gx0 - 0.4, ya)]],
              0.13, 0.004, trace_mat(placed and not fail, fail and False))
    cs.strips(r, "ZugB", [[(gx0 - 0.4, yb), (gx0 - 0.75, yb), (gx0 - 0.75, cy + PH * 0.5 - 0.1),
                           (cx - 4.4, cy + PH * 0.5 - 0.1)]], 0.13, 0.004, trace_mat(won, fail))
    txt(r, "WÜRFEL", cx - 3.7, cy + PH * 0.5 - 0.4, 0.003, 0.16, m_silk(), "consolab.ttf")
    cs.strips(r, "ZugAus", [[(gx1 + 0.4, cy), (bx - 1.5, cy)]], 0.13, 0.004, trace_mat(won, fail))
    bay2(r, bx, cy - 0.2, bet, st)


def plot_e(r, cx, cy, bet, st):
    """REIHENSCHALTER: EINE Stromschiene, zwei Lücken - der Einsatz schließt die erste, die Bedingung die zweite."""
    placed, won, fail = st != "angebot", st == "erfuellt", st == "gescheitert"
    ry, bh = cy - 0.75, 0.16
    x_src, g1, g2, bx = cx - 4.3, cx - 2.75, cx - 0.05, cx + 3.2
    segs = [(x_src, g1 - 0.95, True, False), (g1 + 0.95, g2 - 0.95, placed and not fail, False),
            (g2 + 0.95, bx - 1.35, won, fail)]
    for i, (a, b, on, bad) in enumerate(segs):
        cs.boxes(r, "Schiene%d" % i, [((a + b) * 0.5, ry, bh * 0.5, b - a, 0.36, bh)], cs.m_gold())
        cs.boxes(r, "SchieneLicht%d" % i, [((a + b) * 0.5, ry, bh + 0.006, b - a - 0.1, 0.12, 0.012)],
                 trace_mat(on, bad) if not (i == 0) else glow("bern", 1.6))
    dm.cyl(r, "Quelle", 0.3, 0.2, (x_src, ry, 0.1), m_steel(), 32)
    # Lücke 1: der Stapel selbst ist die Brücke
    dm.cyl(r, "Napf", 0.95, 0.14, (g1, ry, 0.07), m_steel(), 64)
    dm.cyl(r, "NapfMulde", 0.72, 0.144, (g1, ry, 0.072), m_hole(), 64)
    dm.annulus(r, "NapfLicht", g1, ry, 0.146, 0.74, 0.84, glow(LIVE[st], 2.2), 64)
    if st == "gesetzt":
        stack(r, g1, ry, 0.146, bet["chips"])
    txt(r, "1 · EINSATZ", g1, cy + 0.95, 0.003, 0.2, m_silk(), "consolab.ttf")
    zt = display(r, g1, cy + 0.4, 0.0, 1.1, 0.46, "seg", "e")
    txt(r, bet["stake"], g1, cy + 0.4, zt + 0.008, 0.34, glow("bern", 0.6 if fail else 2.2), "consolab.ttf")
    # Lücke 2: Messerschalter, zu erst mit erfüllter Bedingung
    cs.boxes(r, "Lager", [(g2 + s * 0.95, ry, 0.2, 0.22, 0.7, 0.4) for s in (-1, 1)], m_steel())
    piv = pivot(r, g2 - 0.95, ry, 0.36)
    cs.boxes(piv, "Messer", [(0.98, 0, 0, 1.96, 0.3, 0.09)], cs.m_gold())
    cs.boxes(piv, "Griff", [(1.9, 0, 0.1, 0.26, 0.62, 0.22)], mat("Griff", (0.02, 0.02, 0.025), 0.0, 0.4, cc=0.5))
    piv.rotation_euler.y = 0 if won else math.radians(-82 if fail else -38)
    dm.cyl(r, "Gelenk", 0.11, 0.76, (g2 - 0.95, ry, 0.36), glow(LIVE[st], 2.0), 24).rotation_euler.x = \
        math.radians(90)
    txt(r, "2 · BEDINGUNG", g2, cy + 1.95, 0.003, 0.2, m_silk(), "consolab.ttf")
    zt = display(r, g2, cy + 1.1, 0.0, 3.0, 1.15, "oled", "w")
    txt(r, wrap(bet["cond"], 20), g2 - 1.38, cy + 1.1, zt + 0.008, 0.25, glow("oled", 1.9), "seguisb.ttf",
        "LEFT", 0.9)
    progress(r, g2, cy - 1.55, 0.0, bet, st)
    bay2(r, bx, cy - 0.3, bet, st, 2.4, 2.1)


def plot_f(r, cx, cy, bet, st):
    """GATTER-TRESOR: das Gatter IST die Gewinn-Bucht; links stecken Bedingung und Einsatz als seine Eingänge."""
    placed, won, fail = st != "angebot", st == "erfuellt", st == "gescheitert"
    gx0, gx1, gh, T = cx - 0.55, cx + 4.3, 3.7, 0.5
    prism(r, "Tresor", gate_pts(gx0, gx1, cy, gh), 0.0, T, m_steel())
    prism(r, "TresorInnen", gate_pts(gx0, gx1, cy, gh, 0.3), T, T + 0.004,
          mat("TresorWarm", (0.09, 0.07, 0.03), 0.2, 0.5, 0.25) if won else m_hole())
    lip = {"angebot": m_off(), "gesetzt": glow("offen", 1.4), "erfuellt": glow("gold", 2.6),
           "gescheitert": glow("rot", 1.0)}[st]
    prism(r, "TresorLicht", gate_pts(gx0, gx1, cy, gh, 0.22), T, T + 0.002, lip)
    px, py = cx + 1.65, cy
    if st == "gesetzt":
        prize(r, px, py, T + 0.006, bet, True)
    elif won:
        prize(r, px, py, T + 0.06, bet, False)
    if not won:
        prism(r, "TresorGlas", gate_pts(gx0, gx1, cy, gh, 0.26), T + 0.2, T + 0.23, m_smoke())
    txt(r, "&", gx1 - 0.75, cy, T + (0.006 if won else 0.235), 0.42, glow(LIVE[st], 1.8), "consolab.ttf")
    # Eingang B oben: die Bedingung; Eingang A unten: der Einsatz
    yb, ya = cy + 1.05, cy - 1.05
    cs.boxes(r, "Eingaenge", [(gx0 - 0.25, yb, 0.14, 0.6, 0.36, 0.16), (gx0 - 0.25, ya, 0.14, 0.6, 0.36, 0.16)],
             m_steel())
    dx = cx - 2.7
    zt = display(r, dx, yb, 0.0, 3.0, 1.3, "oled", "w")
    txt(r, wrap(bet["cond"], 20), dx - 1.38, yb + 0.05, zt + 0.008, 0.25, glow("oled", 1.9), "seguisb.ttf",
        "LEFT", 0.9)
    cs.strips(r, "ZugB", [[(dx + 1.6, yb), (gx0 - 0.5, yb)]], 0.14, 0.004, trace_mat(won, fail))
    progress(r, dx, yb - 0.95, 0.0, bet, st)
    sx = cx - 3.2
    dm.cyl(r, "Sockel", 0.8, 0.16, (sx, ya - 0.1, 0.08), m_steel(), 64)
    dm.cyl(r, "Mulde", 0.62, 0.164, (sx, ya - 0.1, 0.082), m_hole(), 64)
    dm.annulus(r, "SockelLicht", sx, ya - 0.1, 0.166, 0.64, 0.72, glow(LIVE[st], 2.2), 64)
    if st == "gesetzt":
        stack(r, sx, ya - 0.1, 0.166, bet["chips"])
    zt = display(r, sx + 1.75, ya - 0.1, 0.0, 1.1, 0.46, "seg", "s")
    txt(r, bet["stake"], sx + 1.75, ya - 0.1, zt + 0.008, 0.34, glow("bern", 0.6 if fail else 2.2), "consolab.ttf")
    cs.strips(r, "ZugA", [[(sx + 0.8, ya + 0.45), (gx0 - 0.9, ya + 0.45), (gx0 - 0.9, ya), (gx0 - 0.5, ya)]],
              0.14, 0.004, trace_mat(placed and not fail))


# --- Runde 3: Kosten, Aufgabe, Gewinn GROSS; das Gatter nennt die ART der Bedingung -----------------

BETS3 = [dict(cond="Nimm ein Full House oder besser.", short="FULL\nHOUSE", gate="und", stake="$6", chips=[5, 1],
              prize=("karten", 2, "faktor"), seg="2× MULT", stand=(0, 1)),
         dict(cond="Beende die Runde ohne Fumble.", short="KEIN\nFUMBLE", gate="nicht", stake="$4",
              chips=[1, 1, 1, 1], prize=("chips", [5, 5, 1, 1]), seg="$12", stand=(1, 1)),
         dict(cond="Wirf drei Sechsen in einer Runde.", short="3× SECHS", gate="zaehl", stake="$8",
              chips=[5, 1, 1, 1], prize=("karten", 1, "rune"), seg="1 RUNE", stand=(2, 3)),
         dict(cond="Schaffe den Blind mit höchstens zwei Würfen.", short="MAX.\n2 WÜRFE", gate="grenze", stake="$5",
              chips=[5], prize=("chips", [5, 5, 5]), seg="$15", stand=(1, 2))]
GATE_TAG = {"und": "&", "nicht": "NICHT", "zaehl": "≥3", "grenze": "≤2"}
GATE_NAME = {"und": "UND · etwas schaffen", "nicht": "NICHT · etwas vermeiden",
             "zaehl": "ZÄHLER · n-mal schaffen", "grenze": "GRENZE · höchstens n"}


def live(bet, st):
    """Vermeiden und Grenze liegen ab dem Setzen auf Kurs (grün), der Rest wartet (cyan)."""
    if st == "gesetzt" and bet["gate"] in ("nicht", "grenze"):
        return "auf"
    return LIVE[st]


def gate_local(kind, L, h, inset=0.0):
    """Umriß je Gatter-Art in (u längs des Flusses, v quer)."""
    hl, hh = L * 0.5, h * 0.5
    if kind == "und":
        rr = hh - inset
        pts = [(-hl + inset, -rr), (hl - hh, -rr)]
        pts += [(hl - hh + rr * math.cos(a), rr * math.sin(a))
                for a in [math.radians(-90 + 180 * i / 20) for i in range(1, 20)]]
        return pts + [(hl - hh, rr), (-hl + inset, rr)]
    if kind == "nicht":
        return [(-hl + inset, -hh + inset), (hl - 1.3, -hh + inset), (hl - 0.62 - inset * 1.3, 0),
                (hl - 1.3, hh - inset), (-hl + inset, hh - inset)]
    c = 0.4
    a, b = hl - inset, hh - inset
    if kind == "grenze":
        e = hl - 0.75 - inset
        return [(-a, -b), (e, -b), (e, b), (-a, b)]
    return [(-a, -b + c), (-a + c, -b), (a - c, -b), (a, -b + c), (a, b - c), (a - c, b), (-a + c, b), (-a, b - c)]


def place(pts, cx, cy, down):
    return [(cx + v, cy - u) if down else (cx + u, cy + v) for u, v in pts]


def gate_body(r, bet, st, cx, cy, L, h, T, down=False, size=0.5, tag=0.24):
    """Gatter als Körper: Form = Art, Saum = Zustand, auf dem Deckel die Kurzform GROSS."""
    kind, key = bet["gate"], live(bet, st)
    prism(r, "Gatter", place(gate_local(kind, L, h), cx, cy, down), 0.05, T, m_lack())
    prism(r, "GatterSaum", place(gate_local(kind, L, h, 0.07), cx, cy, down), T, T + 0.012, glow(key, 1.8))
    prism(r, "GatterDeckel", place(gate_local(kind, L, h, 0.16), cx, cy, down), T + 0.012, T + 0.02, m_win())
    if kind == "nicht":
        bx, by = place([(L * 0.5 - 0.3, 0)], cx, cy, down)[0]
        dm.cyl(r, "Blase", 0.3, T, (bx, by, T * 0.5 + 0.03), m_lack(), 40)
        dm.annulus(r, "BlasenLicht", bx, by, T + 0.032, 0.16, 0.26, glow(key, 2.2), 40)
    if kind == "grenze":
        bar = [(L * 0.5 - 0.42, -h * 0.5), (L * 0.5, -h * 0.5), (L * 0.5, h * 0.5), (L * 0.5 - 0.42, h * 0.5)]
        prism(r, "Schranke", place(bar, cx, cy, down), 0.05, T, m_lack())
        lit = [(L * 0.5 - 0.3, -h * 0.5 + 0.12), (L * 0.5 - 0.12, -h * 0.5 + 0.12), (L * 0.5 - 0.12, h * 0.5 - 0.12),
               (L * 0.5 - 0.3, h * 0.5 - 0.12)]
        prism(r, "SchrankenLicht", place(lit, cx, cy, down), T, T + 0.012, glow(key, 2.2))
    # Text sitzt im breiten Teil, das Zeichen der Art oben links
    shift = -0.3 if kind in ("und", "nicht", "grenze") else 0.0
    tx, ty = place([(shift, 0)], cx, cy, down)[0]
    txt(r, bet["short"], tx, ty - 0.05, T + 0.024, size, glow("oled", 2.0), "segoeuib.ttf", "CENTER", 0.85)
    hx, hy = (cx - h * 0.5 + 0.5, cy + L * 0.5 - 0.55) if down else (cx - L * 0.5 + 0.5, cy + h * 0.5 - 0.55)
    txt(r, GATE_TAG[kind], hx, hy, T + 0.024, tag, glow(key, 1.9), "segoeuib.ttf", "LEFT")
    n = bet["stand"][1]
    if n > 1 or kind == "und":
        px, py = (cx, cy - L * 0.5 + 1.05) if down else (cx + shift, cy - h * 0.5 + 0.45)
        progress(r, px, py, T + 0.02, bet, st)


def socket3(r, x, y, bet, st, rad=0.82):
    dm.cyl(r, "Sockel", rad + 0.1, 0.16, (x, y, 0.08), m_steel(), 64)
    dm.cyl(r, "Mulde", rad - 0.1, 0.164, (x, y, 0.082), m_hole(), 64)
    dm.annulus(r, "SockelLicht", x, y, 0.166, rad - 0.08, rad + 0.02, glow(live(bet, st), 2.2), 64)
    if st == "gesetzt":
        stack(r, x, y, 0.166, bet["chips"])


def bay3(r, x, y, bet, st, w=2.7, h=2.1, portrait=False):
    won = st == "erfuellt"
    cs.boxes(r, "BuchtRahmen", cs.ring_items(x, y, w + 0.3, h + 0.3, w, h, 0.09, 0.18), m_steel())
    cs.boxes(r, "BuchtBoden", [(x, y, 0.004, w, h, 0.008)], m_hole())
    lip = {"angebot": m_off(), "gesetzt": glow(live(bet, st), 1.2), "erfuellt": glow("gold", 2.6),
           "gescheitert": glow("rot", 0.9)}[st]
    cs.boxes(r, "BuchtLicht", cs.ring_items(x, y, w, h, w - 0.12, h - 0.12, 0.014, 0.012), lip)
    if st == "gesetzt":
        prize(r, x, y, 0.014, bet, True, portrait)
    elif won:
        cs.boxes(r, "Hubteller", [(x, y, 0.16, w - 0.1, h - 0.1, 0.04)], m_dsteel())
        prize(r, x, y, 0.18, bet, False, portrait)
    if not won:
        cs.boxes(r, "Glas", [(x, y, 0.2, w + 0.1, h + 0.1, 0.03)], m_smoke())


def tile(r, name, x, y, w, h, T=0.12):
    led.rounded_box(r, name, (w, h, T), (x, y, T * 0.5), m_bezel(), 0.14, 0.02)
    cs.boxes(r, name + "Scheibe", [(x, y, T + 0.003, w - 0.18, h - 0.18, 0.006)], m_win())
    return T + 0.01


def big(r, body, x, y, z, size, key, e=2.2, font="consolab.ttf", align="CENTER"):
    return txt(r, body, x, y, z, size, glow(key, e), font, align)


def link(r, name, pts, on, fail=False, w=0.2):
    cs.strips(r, name, [pts], w, 0.004, trace_mat(on, fail))


def plot_g(r, cx, cy, bet, st):
    """SATZ-LEISTE: drei große Felder - ZAHLE · Gatter mit der Aufgabe · BEKOMME."""
    placed, won, fail = st != "angebot", st == "erfuellt", st == "gescheitert"
    x1, x2, x3 = cx - 3.27, cx - 0.2, cx + 3.1
    z = tile(r, "Preis", x1, cy, 2.4, 3.9)
    txt(r, "ZAHLE", x1, cy + 1.55, z, 0.2, m_note(), "consolab.ttf")
    big(r, bet["stake"], x1, cy + 0.8, z, 1.0, "bern", 0.7 if fail else 2.4)
    socket3(r, x1, cy - 0.85, bet, st, 0.78)
    link(r, "ZugA", [(x1 + 1.2, cy), (x2 - 1.6, cy)], placed and not fail)
    gate_body(r, bet, st, x2, cy, 3.3, 3.9, 0.42, False, 0.52)
    link(r, "ZugAus", [(x2 + 1.65, cy), (x3 - 1.5, cy)], won, fail)
    z = tile(r, "GewinnSchild", x3, cy + 1.42, 2.85, 1.05)
    big(r, bet["seg"], x3, cy + 1.42, z, 0.5, "gold", 0.7 if fail else 2.4)
    bay3(r, x3, cy - 0.65, bet, st, 2.6, 2.1)


def plot_h(r, cx, cy, bet, st):
    """KANALZUG: jede Wette eine SPALTE - oben zahlen, durch das Gatter, unten der Gewinn."""
    placed, won, fail = st != "angebot", st == "erfuellt", st == "gescheitert"
    W = 3.1
    y1, y2, y3 = cy + 5.55, cy + 0.9, cy - 4.9
    z = tile(r, "Preis", cx, y1 + 0.55, W, 1.5)
    big(r, bet["stake"], cx, y1 + 0.55, z, 1.0, "bern", 0.7 if fail else 2.4)
    socket3(r, cx, y1 - 1.3, bet, st, 0.8)
    link(r, "ZugA", [(cx, y1 - 2.2), (cx, y2 + 2.25)], placed and not fail)
    gate_body(r, bet, st, cx, y2, 4.5, W, 0.42, True, 0.5)
    link(r, "ZugAus", [(cx, y2 - 2.25), (cx, y3 + 2.9)], won, fail)
    z = tile(r, "GewinnSchild", cx, y3 + 2.35, W, 0.95)
    big(r, bet["seg"], cx, y3 + 2.35, z, 0.5, "gold", 0.7 if fail else 2.4)
    bay3(r, cx, y3, bet, st, 2.5, 3.3, True)


def gate_glyph(r, bet, st, cx, cy, L, h):
    """Gatter als Lichtzeichen auf der Platine."""
    kind, key = bet["gate"], live(bet, st)
    pts = place(gate_local(kind, L, h), cx, cy, False)
    cs.strips(r, "Zeichen", [pts + [pts[0]]], 0.09, 0.006, glow(key, 2.0))
    if kind == "nicht":
        dm.annulus(r, "Blase", cx + L * 0.5 - 0.3, cy, 0.008, 0.2, 0.29, glow(key, 2.0), 40)
    if kind == "grenze":
        cs.strips(r, "Schranke", [[(cx + L * 0.5 - 0.2, cy - h * 0.5), (cx + L * 0.5 - 0.2, cy + h * 0.5)]], 0.16,
                  0.006, glow(key, 2.0))
    shift = -0.25 if kind in ("und", "nicht", "grenze") else 0.0
    txt(r, GATE_TAG[kind], cx + shift, cy + (0.18 if bet["stand"][1] > 1 else 0), 0.008,
        0.3 if kind == "nicht" else 0.42, glow(key, 2.0), "segoeuib.ttf")
    if bet["stand"][1] > 1:
        progress(r, cx + shift, cy - 0.5, 0.0, bet, st)


def plot_i(r, cx, cy, bet, st):
    """BANNER: oben EINE Zeile groß - Preis · ganze Bedingung · Gewinn; darunter die Schaltung."""
    placed, won, fail = st != "angebot", st == "erfuellt", st == "gescheitert"
    by = cy + 1.3
    led.rounded_box(r, "Banner", (PW, 1.8, 0.14), (cx, by, 0.07), m_bezel(), 0.14, 0.02)
    cs.boxes(r, "BannerScheibe", [(cx, by, 0.143, PW - 0.2, 1.6, 0.006)], m_win())
    cs.boxes(r, "BannerTeiler", [(cx - 2.85, by, 0.147, 0.03, 1.1, 0.004), (cx + 2.35, by, 0.147, 0.03, 1.1, 0.004)],
             glow(live(bet, st), 1.2))
    z = 0.15
    big(r, bet["stake"], cx - 3.65, by, z, 1.0, "bern", 0.7 if fail else 2.4)
    txt(r, wrap(bet["cond"], 19), cx - 2.6, by, z, 0.37, glow("oled", 2.0), "seguisb.ttf", "LEFT", 0.85)
    big(r, bet["seg"], cx + 3.4, by, z, 0.5, "gold", 0.7 if fail else 2.4)
    # die Schaltung darunter: Sockel - Gatter-Zeichen - Bucht, jeweils unter ihrem Wort
    ry = cy - 1.05
    sx, gx, bx = cx - 3.65, cx - 0.25, cx + 3.2
    socket3(r, sx, ry, bet, st, 0.78)
    link(r, "ZugA", [(sx + 0.9, ry), (gx - 1.3, ry)], placed and not fail, False, 0.16)
    gate_glyph(r, bet, st, gx, ry, 2.6, 1.9)
    link(r, "ZugAus", [(gx + 1.3, ry), (bx - 1.45, ry)], won, fail, 0.16)
    bay3(r, bx, ry - 0.05, bet, st, 2.5, 2.0)


# --- Station und Bühne ------------------------------------------------------------------------

PLOTS = {"a": plot_a, "b": plot_b, "c": plot_c, "d": plot_d, "e": plot_e, "f": plot_f,
         "g": plot_g, "h": plot_h, "i": plot_i}
NAMES = {"a": "A · LOGIKGATTER", "b": "B · RELAIS-RIEGEL", "c": "C · SICHERUNGSHALTER",
         "d": "D · GATTER-CHIP", "e": "E · REIHENSCHALTER", "f": "F · GATTER-TRESOR",
         "g": "G · SATZ-LEISTE", "h": "H · KANALZUG", "i": "I · BANNER"}
NEW = "ghi"


def station(r, kind, ox=0.0, oy=0.0):
    silk = m_silk()
    hx, hy = FW * 0.5, FH * 0.5
    corners = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            px, py = ox + sx * hx, oy + sy * hy
            corners.append([(px - sx * 0.8, py), (px, py), (px, py - sy * 0.8)])
    cs.strips(r, "Bestueckung", corners, 0.06, 0.002, silk)
    txt(r, "U5 WETTEN", ox - hx, oy + hy + 0.55, 0.003, 0.55, silk, "consolab.ttf", "LEFT")
    dm.cyl(r, "Pin1", 0.12, 0.004, (ox - hx + 0.3, oy + hy - 0.3, 0.002), silk, 24)
    if kind == "b":
        rails_b(r, ox, oy)
    for i in range(3):
        if kind == "h":
            plot_h(r, ox + (i - 1) * 3.45, oy, BETS3[i], ("gesetzt", "gesetzt", "erfuellt")[i])
        elif kind in NEW:
            PLOTS[kind](r, ox, oy + (1 - i) * PITCH_Y, BETS3[i], ("gesetzt", "gesetzt", "erfuellt")[i])
        else:
            PLOTS[kind](r, ox, oy + (1 - i) * PITCH_Y, BETS[i], STATION_STATES[i])
    yb = oy - hy - 1.5
    cs.strips(r, "Bus", [[(ox - 6.5, yb), (ox + 6.5, yb)]], 0.32, 0.003, m_trace())
    cs.strips(r, "Abgang", [[(ox + d, oy - hy + 0.4), (ox + d, yb)] for d in (-1.2, 0.0, 1.2)], 0.16, 0.003,
              m_trace())
    for d in (-1.2, 0.0, 1.2):
        cs.boxes(r, "GoldPad", [(ox + d, oy - hy + 0.35, 0.004, 0.45, 0.3, 0.008)], cs.m_gold())
        dm.cyl(r, "Via", 0.22, 0.01, (ox + d, yb, 0.006), cs.m_gold(), 24)


def stage():
    cam, aim = dm.empty_stage()
    for o in list(bpy.data.objects):
        mats = getattr(o.data, "materials", None) if o.data is not None else None
        if mats and mats[0] is not None and mats[0].name == "Filz":
            bpy.data.objects.remove(o)
    for o in bpy.data.objects:
        if o.type == "LIGHT":
            o.data.energy *= 0.35
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.0004))
    bpy.context.active_object.data.materials.append(m_ground())
    sc = bpy.context.scene
    sc.eevee.taa_render_samples = 48
    sc.render.resolution_x, sc.render.resolution_y = 1600, 1000
    return cam, aim


def shoot(cam, aim, name, target, eye, lens=50):
    aim.location = target
    cam.location = eye
    cam.data.lens = lens
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


def note(r, body, x, y, size=0.5):
    txt(r, body, x, y, 0.004, size, m_note(), "segoeuib.ttf")


def view_station(kind, which):
    cam, aim = stage()
    r = cs.root("Welt")
    station(r, kind)
    r.scale = (S, S, S)
    if which == "schraeg":
        shoot(cam, aim, kind + "_schraeg", (0.1, -0.05, 0), (0.1, -2.3, 7.4))
    elif which == "oben":
        shoot(cam, aim, kind + "_oben", (0.1, -0.15, 0), (0.1, -0.1501, 9.4))
    else:
        y = PITCH_Y * S
        shoot(cam, aim, kind + "_detail", (0.08, y - 0.05, 0.05), (0.55, y - 2.3, 2.75))


def view_states(kind):
    cam, aim = stage()
    r = cs.root("Welt")
    if kind == "h":
        for i, (st, label) in enumerate(STATES):
            x = (i - 1.5) * 6.2
            plot_h(r, x, 0.5, BETS3[2], st)
            note(r, label.split(" · ")[0], x, -7.6)
        r.scale = (S, S, S)
        shoot(cam, aim, kind + "_zustaende", (0.0, -0.2, 0), (0.0, -3.2, 9.6))
        return
    for i, (st, label) in enumerate(STATES):
        x, y = (i % 2 - 0.5) * 11.2, (0.5 - i // 2) * 6.6 + 0.3
        PLOTS[kind](r, x, y, BETS3[2] if kind in NEW else BETS[0], st)
        note(r, label, x, y - PH * 0.5 - 0.55)
    r.scale = (S, S, S)
    shoot(cam, aim, kind + "_zustaende", (0.1, -0.1, 0), (0.1, -1.7, 6.6))


def view_gates():
    """Die vier Gatter-Arten nebeneinander, je gesetzt."""
    cam, aim = stage()
    r = cs.root("Welt")
    for i, bet in enumerate(BETS3):
        x = (i - 1.5) * 5.4
        gate_body(r, bet, "gesetzt", x, 0.6, 4.2, 3.9, 0.42, False, 0.6, 0.3)
        note(r, GATE_NAME[bet["gate"]], x, -2.3, 0.34)
        note(r, wrap(bet["cond"], 26), x, -3.2, 0.22)
    r.scale = (S, S, S)
    shoot(cam, aim, "gatter_arten", (0.0, -0.1, 0), (0.0, -1.6, 7.6))


def view_compare(kinds="abc", name="vergleich"):
    cam, aim = stage()
    r = cs.root("Welt")
    for i, kind in enumerate(kinds):
        ox = (i - 1) * 14.0
        station(r, kind, ox)
        note(r, NAMES[kind], ox, -FH * 0.5 - 2.7, 0.75)
    r.scale = (S, S, S)
    shoot(cam, aim, name, (0.15, -0.25, 0), (0.15, -3.6, 11.4))


VIEWS = {}
for _k in "abcdefghi":
    for _w in ("schraeg", "oben", "detail"):
        VIEWS["%s_%s" % (_k, _w)] = (lambda k=_k, w=_w: view_station(k, w))
    VIEWS[_k + "_zustaende"] = (lambda k=_k: view_states(k))
VIEWS["vergleich"] = view_compare
VIEWS["vergleich2"] = (lambda: view_compare("def", "vergleich2"))
VIEWS["vergleich3"] = (lambda: view_compare("ghi", "vergleich3"))
VIEWS["gatter_arten"] = view_gates

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    argv = sys.argv[sys.argv.index("--") + 1:]
    only = argv[1].split(",") if len(argv) > 1 else []
    for name, fn in VIEWS.items():
        if not only or name in only:
            fn()
    print("ok")
