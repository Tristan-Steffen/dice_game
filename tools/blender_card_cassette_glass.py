"""Fumble: die KLARSICHT-Kassette - ein Fenster in das Paket, dahinter liegen die Data-Cards
selbst, getönt in der Farbe ihrer Sorte, ohne Inhalt (Spieler-Wunsch 2026-11-15).
Drei Varianten:
  faecher   - Klarsicht-Deckel über einer Mulde, die Karten liegen leicht aufgefächert
  treppe    - Klarsicht-Deckel, die Karten liegen gestaffelt wie eine Treppe; je Karte ein Streifen
  sandwich  - Metallplatte oben und unten, dazwischen ein Glasband ringsum; die Karten liegen
              als farbige Schichten darin, ein Fenster oben zeigt die oberste

Aufruf (kopflos):
  blender -b -P tools/blender_card_cassette_glass.py -- <ausgabe-ordner> [variante]
Werkzeuge (Material, gerundete Box, Bühne, Kamera) aus blender_card_cassette_led.py.
"""
import bpy, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led

W, L, H = led.W, led.L, led.H
MIX = ["zahl", "material", "rune", "material", "zahl"]
CT = 0.028


def card_mats(sort):
    # Durchsichtiger Körper, leuchtende Kante: so liest jede Karte einzeln, auch im Stapel.
    body = led.mat("Glaskarte_" + sort, led.SORTS[sort], 0.0, 0.08, 0.18, 0.28, 1.0)
    body.blend_method = "HASHED"
    rim = led.mat("Kartenrand_" + sort, led.SORTS[sort], 0.0, 0.2, 3.5)
    return body, rim


def glass(name, alpha, tint=(0.75, 0.8, 0.9)):
    m = led.mat(name, tint, 0.0, 0.02, 0.0, alpha, 1.0)
    m.blend_method = "HASHED"
    return m


def glass_card(parent, sort, size, loc, turn=0.0, name="Karte"):
    """Eine Data-Card aus getöntem Glas mit leuchtender Kante - ohne Netz, ohne Inhalt."""
    bpy.ops.object.empty_add(location=loc)
    holder = bpy.context.active_object
    holder.name = name
    holder.rotation_euler = (0, 0, turn)
    holder.parent = parent
    body, rim = card_mats(sort)
    cw, cl = size
    led.rounded_box(holder, name + "Koerper", (cw, cl, CT), (0, 0, 0), body, 0.03, 0.004, 6)
    edge = 0.022
    for part, s, p in [("L", (edge, cl, CT * 1.04), (-(cw - edge) * 0.5, 0)),
                       ("R", (edge, cl, CT * 1.04), ((cw - edge) * 0.5, 0)),
                       ("O", (cw - edge * 2, edge, CT * 1.04), (0, (cl - edge) * 0.5)),
                       ("U", (cw - edge * 2, edge, CT * 1.04), (0, -(cl - edge) * 0.5))]:
        led.rounded_box(holder, name + "Rand" + part, s, (p[0], p[1], 0), rim, 0.0, 0.0)
    return holder


def card_sort(sort, i):
    return MIX[i] if sort == "misch" else sort


def tray(parent, quality, pocket, depth):
    body = led.rounded_box(parent, "Gehaeuse", (W, L, H), (0, 0, H * 0.5), led.metal(quality),
                           0.1, 0.02, 12)
    hole = led.rounded_box(parent, "Mulde", (pocket[0], pocket[1], depth * 2), (0, 0, H),
                           led.DARK, 0.07, 0.0, 12)
    led.cut(body, hole)
    led.rounded_box(parent, "MuldeBoden", (pocket[0], pocket[1], 0.01),
                    (0, 0, H - depth + 0.005), led.DARK, 0.07, 0.0, 12)
    return H - depth + 0.01


def glass_lid(parent, pocket):
    led.rounded_box(parent, "Deckelglas", (pocket[0] + 0.02, pocket[1] + 0.02, 0.012),
                    (0, 0, H - 0.004), glass("Klarglas", 0.12), 0.075, 0.003, 12)
    led.frame_ring(parent, "Luenette", (pocket[0] + 0.05, pocket[1] + 0.05),
                   (pocket[0] - 0.005, pocket[1] - 0.005), H + 0.004, 0.012, led.CHROME, 0.07,
                   0.0)


def seam(parent, sort):
    led.seam(parent, sort if sort != "misch" else "misch", 0.3)


def faecher(parent, sort, count, quality):
    pocket = (W - 0.11, L - 0.11)
    floor = tray(parent, quality, pocket, H - 0.06)
    size = (W * 0.6, L * 0.66)
    spread = math.radians(7.0)
    for i in range(count):
        t = (i - (count - 1) * 0.5)
        glass_card(parent, card_sort(sort, i), size,
                   (t * 0.05, -abs(t) * 0.02, floor + CT * 0.5 + i * (CT + 0.01)),
                   -t * spread, "Karte%d" % i)
    glass_lid(parent, pocket)
    seam(parent, sort)


def treppe(parent, sort, count, quality):
    pocket = (W - 0.11, L - 0.11)
    floor = tray(parent, quality, pocket, H - 0.06)
    step = 0.13
    size = (W * 0.76, pocket[1] - 0.06 - step * 4)
    for i in range(count):
        # Die unterste liegt am Kopf; jede höhere rückt eine Stufe zum Fuß.
        y = (pocket[1] - 0.06 - size[1]) * 0.5 - step * i
        glass_card(parent, card_sort(sort, i), size,
                   (0, y, floor + CT * 0.5 + i * (CT + 0.006)), 0.0, "Karte%d" % i)
    glass_lid(parent, pocket)
    seam(parent, sort)


def sandwich(parent, sort, count, quality):
    plate = 0.065
    m = led.metal(quality)
    led.rounded_box(parent, "Boden", (W, L, plate), (0, 0, plate * 0.5), m, 0.1, 0.02, 12)
    top = led.rounded_box(parent, "Deckel", (W, L, plate), (0, 0, H - plate * 0.5), m, 0.1, 0.02,
                          12)
    win = (W * 0.62, L * 0.58)
    hole = led.rounded_box(parent, "Fenster", (win[0], win[1], plate * 3), (0, L * 0.06, H),
                           led.DARK, 0.06, 0.0, 12)
    led.cut(top, hole)
    led.rounded_box(parent, "Fensterglas", (win[0] + 0.02, win[1] + 0.02, 0.008),
                    (0, L * 0.06, H - plate * 0.5), glass("Klarglas", 0.1), 0.06, 0.0, 12)
    band = H - plate * 2
    led.rounded_box(parent, "Glasband", (W - 0.03, L - 0.03, band), (0, 0, H * 0.5),
                    glass("Glasband", 0.16), 0.09, 0.004, 12)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.03, depth=band,
                                                location=(sx * (W * 0.5 - 0.07),
                                                          sy * (L * 0.5 - 0.07), H * 0.5))
            post = bpy.context.active_object
            post.data.materials.append(led.CHROME)
            bpy.ops.object.shade_smooth()
            post.parent = parent
    pitch = band / 5.6
    size = (W * 0.78, L * 0.8)
    for i in range(count):
        glass_card(parent, card_sort(sort, i), size,
                   (0, 0, plate + pitch * (i + 0.6)), 0.0, "Karte%d" % i)


# --- Die Überarbeitung (Spieler-Wunsch 2026-11-15): Sandwich mit RAHMEN-FENSTERN, innen die
# Treppe, die Karten wie im Spiel (Glas, Rahmen, Netz). Spiegelt tools/blender_card_cassette.py.
PLATE = 0.065
WALL = 0.05
TOP_WINDOW = (W * 0.72, L * 0.78)
SIDE_WINDOW_SHARE = (0.82, 0.8)
# So dick wie die Schatulle (CardPackView.CASSETTE_THICKNESS = DICE_THICKNESS): die Karten
# lehnen darin schräg, damit sie im Lager durch die Seitenfenster lesen.
SHELL_H = 0.1512 * 3.2
STAIR_CARD = (W * 0.66, 0.9)
STAIR_STEP = 0.09


def framed_shell(parent, quality):
    H = SHELL_H
    m = led.metal(quality)
    led.rounded_box(parent, "Boden", (W, L, PLATE), (0, 0, PLATE * 0.5), m, 0.1, 0.02, 12)
    top = led.rounded_box(parent, "Deckel", (W, L, PLATE), (0, 0, H - PLATE * 0.5), m, 0.1,
                          0.02, 12)
    hole = led.rounded_box(parent, "SchnittFenster", (TOP_WINDOW[0], TOP_WINDOW[1], PLATE * 3),
                           (0, 0, H), led.DARK, 0.06, 0.0, 12)
    led.cut(top, hole)
    clear = glass("Fensterglas", 0.06)
    led.rounded_box(parent, "Fensterglas", (TOP_WINDOW[0] + 0.02, TOP_WINDOW[1] + 0.02, 0.008),
                    (0, 0, H - PLATE * 0.5), clear, 0.06, 0.0, 12)
    band = H - PLATE * 2
    # Die WAND zwischen den Platten: Metall mit großen Fenstern - ein Rahmen, kein Glasband.
    outer = (W - 0.02, L - 0.02)
    wall = led.rounded_box(parent, "Wand", (outer[0], outer[1], band + 0.004), (0, 0, H * 0.5), m,
                           0.09, 0.0, 12)
    inner = led.rounded_box(parent, "SchnittInnen", (outer[0] - WALL * 2, outer[1] - WALL * 2,
                            band * 3), (0, 0, H * 0.5), led.DARK, 0.06, 0.0, 12)
    led.cut(wall, inner)
    win_h = band * SIDE_WINDOW_SHARE[1]
    long_w = outer[1] * SIDE_WINDOW_SHARE[0]
    short_w = outer[0] * SIDE_WINDOW_SHARE[0]
    for i, (size, loc) in enumerate([((WALL * 4, long_w, win_h), (outer[0] * 0.5, 0, H * 0.5)),
                                     ((WALL * 4, long_w, win_h), (-outer[0] * 0.5, 0, H * 0.5)),
                                     ((short_w, WALL * 4, win_h), (0, outer[1] * 0.5, H * 0.5)),
                                     ((short_w, WALL * 4, win_h), (0, -outer[1] * 0.5, H * 0.5))]):
        cutter = led.rounded_box(parent, "SchnittSeite%d" % i, size, loc, led.DARK, 0.0, 0.0)
        led.cut(wall, cutter)
    pane = glass("Seitenglas", 0.08)
    for i, (size, loc) in enumerate([((0.006, long_w, win_h), (outer[0] * 0.5 - WALL * 0.5, 0, H * 0.5)),
                                     ((0.006, long_w, win_h), (-outer[0] * 0.5 + WALL * 0.5, 0, H * 0.5)),
                                     ((short_w, 0.006, win_h), (0, outer[1] * 0.5 - WALL * 0.5, H * 0.5)),
                                     ((short_w, 0.006, win_h), (0, -outer[1] * 0.5 + WALL * 0.5, H * 0.5))]):
        led.rounded_box(parent, "Seitenglas%d" % i, size, loc, pane, 0.0, 0.0)
    return band


def game_card(parent, sort, size, loc, name, seed):
    """Eine Data-Card wie im Spiel: Glaskörper, Rahmen in der Sortenfarbe und das Netz."""
    holder = glass_card(parent, sort, size, loc, 0.0, name)
    cell = min(size[0] / 4.6, size[1] / 3.6)
    lit = led.mat("Zelle_" + sort, led.SORTS[sort], 0.0, 0.3, 2.4)
    dim = led.mat("ZelleLeer", (0.02, 0.02, 0.025), 0.0, 0.5)
    for i, (cx, cy) in enumerate([(-1.5, 0), (-0.5, 0), (0.5, 0), (1.5, 0), (-0.5, 1), (-0.5, -1)]):
        on = ((seed * 7 + i * 3) % 5) < 3
        led.rounded_box(holder, name + "Netz%d" % i, (cell * 0.84, cell * 0.84, 0.004),
                        (cx * cell, cy * cell, CT * 0.5 + 0.002), lit if on else dim,
                        cell * 0.12, 0.0, 4)
    return holder


def rahmenfenster(parent, sort, count, quality):
    band = framed_shell(parent, quality)
    pitch = band / 5.6
    span = STAIR_CARD[1] + STAIR_STEP * (count - 1)
    for i in range(count):
        # Die unterste liegt am Kopf, jede höhere eine Stufe zum Fuß - die Treppe.
        y = span * 0.5 - STAIR_CARD[1] * 0.5 - STAIR_STEP * i
        game_card(parent, card_sort(sort, i), STAIR_CARD,
                  (0, y, PLATE + pitch * (i + 0.6)), "Karte%d" % i, i + count)


VARIANTS = [("faecher", faecher), ("treppe", treppe), ("sandwich", sandwich)]
REWORK = [("rahmenfenster", rahmenfenster)]

if __name__ == "__main__":
    led.render_all(REWORK if "rahmenfenster" in sys.argv else VARIANTS)
