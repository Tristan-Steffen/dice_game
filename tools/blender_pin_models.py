"""Fumble: je MODUL sein PIN am kompakten Kombinations-Chip (Welle C, Plan
docs/plan_kombi_grosschip.md; Skizzen pin_* in tools/blender_combo_module_variants.py), im
PRÄZISIONS-Stil der Module (tools/blender_part_models.py, dessen Helfer hier geliehen sind).

Aufruf (kopflos):
  blender -b -P tools/blender_pin_models.py -- assets/models/hardware [id ...]

pin_<id>.glb und pin_empty.glb (der leere Sockel: ein schlichter Stahlpin). Ursprung = die
rechte Gehäusekante des Chips auf dem Tisch; der Pin zeigt nach Bild-rechts (u), quer ist
Bild-oben (v), z die Höhe. Hüllmaß PIN_U × PIN_V × PIN_Z (spiegelt ComboPartBody.PIN_HULL).
Die FAMILIE gibt die Form (Riegel, Block, Gabel, Röhre, Klinge, Pfeil), das Modul das Zeichen.
Knoten wie bei den Modulen: Korpus (Licht eingemalt), Licht, optional Glas, Zustands-Teile
(Ziffer0-2, Lampe0-4, Ring0-4, Klemme0-2, Flamme) setzt Godot.
"""
import math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_part_models as pm  # noqa: E402
import bpy  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/hardware"
ONLY = set(ARGS[1:])
os.makedirs(OUT, exist_ok=True)

PIN_U, PIN_V, PIN_Z = 0.9, 0.56, 0.5
NECK = -0.04  # der Hals steckt ein Stück im Gehäuse
AX = 0.24     # Achshöhe der liegenden Körper
TOP_BLOCK = 0.44

box, slab, cyl, along, ring, torus, bar, prism = pm.box, pm.slab, pm.cyl, pm.along, pm.ring, pm.torus, pm.bar, pm.prism
paint, join, anchor, uv_outline, capsule, ribbed = pm.paint, pm.join, pm.anchor, pm.uv_outline, pm.capsule, pm.ribbed
STEEL, TITAN, COPPER, GOLD, BLACK = pm.STEEL, pm.TITAN, pm.COPPER, pm.GOLD, pm.BLACK
GRAPHITE, CERAMIC, SOLDER, CYAN_HOT = pm.GRAPHITE, pm.CERAMIC, pm.SOLDER, pm.CYAN_HOT
GLASS_VIOLET, GLASS_CLEAR = pm.GLASS_VIOLET, pm.GLASS_CLEAR
ALU = (0.7, 0.72, 0.78)


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "pin_%s.glb" % name), use_selection=True,
                              export_apply=True, export_format="GLB", export_colors=True)
    print("BUILT pin", name)


def neck():
    """Der Hals: ein Stahlstummel aus der Gehäusekante - jeder Modul-Pin ist ein Anschluß."""
    return paint(box("Hals", 0.18, 0.18, 0.16, 0.32, NECK + 0.09, 0.0, 0.02), "metal", STEEL)


# --- Familien ---------------------------------------------------------------------------------

def f_bar(material=CERAMIC):
    """Speicher: liegender Keramikriegel längs."""
    return [neck(), paint(along("Riegel", capsule(0.16, 0.35, 0.05), 0.5, 0.0, AX, squash=(1.35, 1.0)),
                          "gloss", material)]


def f_block():
    """Wandler: gedrungener dunkler Block mit goldener Stirn; liefert die Teile."""
    return [neck(), paint(slab("Block", 0.31, 0.26, 0.08, 0.04, TOP_BLOCK, 0.44, 0.0, 0.04), "gloss", GRAPHITE),
            paint(box("Stirn", 0.04, 0.38, 0.1, 0.38, 0.77, 0.0), "metal", GOLD)]


def f_fork(prongs, lit):
    """Kontakte: Joch und Zinken; lit = Indizes der leuchtenden Spitzen."""
    parts = [neck(), paint(box("Joch", 0.14, 0.52, 0.08, 0.36, 0.16, 0.0, 0.02), "metal", STEEL)]
    lights = []
    width = 0.08 if len(prongs) < 3 else 0.06
    for i, v in enumerate(prongs):
        parts.append(paint(box("Zinke", 0.56, width, 0.14, 0.3, 0.51, v, 0.01), "metal", STEEL))
        tip = box("Spitze", 0.09, width + 0.02, 0.12, 0.32, 0.835, v, 0.02)
        if i in lit:
            lights.append(tip)
        else:
            parts.append(paint(tip, "gloss", BLACK))
    return parts, lights


def f_tube(u0, u1, r):
    """Röhren: liegender Glaskolben mit Glutkern und Stahlfuß; liefert (Teile, Licht-Kern)."""
    mid, half = (u0 + u1) * 0.5, (u1 - u0) * 0.5
    paint(along("Glas", capsule(r, half, 0.05), mid, 0.0, AX), "glass", GLASS_VIOLET)
    core = along("Kern", [(0.0, -half * 0.8), (r * 0.42, -half * 0.8), (r * 0.42, half * 0.8), (0.0, half * 0.8)],
                 mid, 0.0, AX)
    foot = paint(along("Fuss", [(0.0, -0.03), (r + 0.02, -0.03), (r + 0.02, 0.03), (0.0, 0.03)], u0, 0.0, AX),
                 "metal", STEEL)
    return [neck(), foot], core


def f_blade():
    """Abgriffe: flache Stahlklinge."""
    return [neck(), paint(slab("Klinge", 0.41, 0.25, 0.05, 0.08, 0.16, 0.47, 0.0, 0.02), "metal", STEEL)]


def f_link():
    """Brücken: dunkle Bahn auf einem Stahlfuß, darauf der Pfeil."""
    return [paint(box("Fuss", 0.2, 0.2, 0.0, 0.2, NECK + 0.1, 0.0, 0.02), "metal", STEEL),
            paint(slab("Bahn", 0.39, 0.25, 0.06, 0.03, 0.1, 0.47, 0.0, 0.02), "gloss", GRAPHITE)]


def arrow(name, pts, head, width, z0, z1):
    """Ein flacher Pfeil: Schaft längs pts, Spitze am Ende in Richtung head (du, dv)."""
    pieces = [bar(name, a, b, width, z0, z1) for a, b in zip(pts, pts[1:])]
    tip = pts[-1]
    du, dv = head
    nu, nv = -dv, du
    s = width * 2.2
    pieces.append(prism(name, uv_outline([(tip[0] + nu * s, tip[1] + nv * s), (tip[0] + du * s * 1.3, tip[1] + dv * s * 1.3),
                                          (tip[0] - nu * s, tip[1] - nv * s)]), z0, z1))
    return pieces


# --- Speicher ---------------------------------------------------------------------------------

def resistor():
    pm.reset()
    join("Korpus", f_bar())
    join("Licht", [along("Ring", [(0.168, u - 0.03), (0.168, u + 0.03)], 0.0, 0.0, AX, squash=(1.35, 1.0), caps=False)
                   for u in (0.36, 0.5, 0.64)])
    export("resistor")


def coil():
    pm.reset()
    parts = f_bar(GRAPHITE)
    parts.append(paint(along("Wicklung", ribbed(0.172, 0.164, 0.24, 0.76, 14), 0.0, 0.0, AX, squash=(1.35, 1.0), angle=18),
                       "metal", COPPER))
    for u in (0.2, 0.8):
        parts.append(paint(along("Kern", [(0.0, -0.025), (0.17, -0.025), (0.17, 0.025), (0.0, 0.025)], u, 0.0, AX,
                                 squash=(1.35, 1.0)), "flat", CYAN_HOT))
    join("Korpus", parts)
    box("Licht", 0.46, 0.05, AX + 0.17, AX + 0.18, 0.5, 0.0)
    export("coil")


def series_resistor():
    pm.reset()
    parts = f_bar()
    lights = []
    for i in range(6):
        u = 0.22 + i * 0.112
        parts.append(paint(box("Zahn", 0.05, 0.1, 0.12, 0.3, u, -0.22), "gloss", CERAMIC))
        lights.append(box("Zinke", 0.04, 0.16, AX + 0.16, AX + 0.17, u, -0.03))
    join("Korpus", parts)
    join("Licht", lights)
    export("series_resistor")


def series_terminal():
    pm.reset()
    parts = f_bar(GRAPHITE)
    for i in range(3):
        u = 0.3 + i * 0.2
        parts.append(paint(cyl("Schraube", 0.06, AX + 0.15, AX + 0.2, u, 0.0, 0.012, 20), "metal", STEEL))
        parts.append(paint(box("Schlitz", 0.018, 0.08, AX + 0.2, AX + 0.204, u, 0.0), "gloss", BLACK))
        ring("Klemme%d" % i, 0.065, 0.09, AX + 0.155, AX + 0.165, u, 0.0, 32)
    join("Korpus", parts)
    box("Licht", 0.62, 0.03, AX + 0.12, AX + 0.13, 0.5, -0.2)
    export("series_terminal")


# --- Wandler ----------------------------------------------------------------------------------

def capacitor():
    pm.reset()
    join("Korpus", f_block())
    join("Licht", [box("Kreuz", 0.36, 0.08, TOP_BLOCK, TOP_BLOCK + 0.012, 0.44, 0.0),
                   box("Kreuz", 0.08, 0.36, TOP_BLOCK, TOP_BLOCK + 0.012, 0.44, 0.0)])
    export("capacitor")


def solder_joint():
    pm.reset()
    parts = f_block()
    lights = []
    for a in range(3):
        for b in (-1, 1):
            u, v = 0.3 + a * 0.14, b * 0.11
            dome = pm.dome("Kuppe", [(0.05, TOP_BLOCK), (0.048, TOP_BLOCK + 0.03), (0.03, TOP_BLOCK + 0.05),
                                     (0.0, TOP_BLOCK + 0.055)], u, v, steps=20)
            if (a + (b > 0)) % 2:
                lights.append(dome)
            else:
                parts.append(paint(dome, "metal", SOLDER))
    join("Korpus", parts)
    join("Licht", lights)
    export("solder_joint")


def counter_part():
    pm.reset()
    parts = f_block()
    parts.append(paint(slab("Fenster", 0.22, 0.12, 0.03, TOP_BLOCK, TOP_BLOCK + 0.01, 0.44, 0.04), "gloss", BLACK))
    for i in range(3):
        anchor("Ziffer%d" % i, 0.3 + i * 0.14, 0.04, TOP_BLOCK + 0.016)
    join("Korpus", parts)
    box("Licht", 0.44, 0.03, TOP_BLOCK, TOP_BLOCK + 0.012, 0.44, -0.16)
    export("counter")


def error_memory():
    pm.reset()
    parts = f_block()
    parts.append(paint(ring("Fassung", 0.075, 0.1, TOP_BLOCK, TOP_BLOCK + 0.012, 0.44, 0.1), "metal", STEEL))
    for i in range(5):
        cyl("Lampe%d" % i, 0.038, TOP_BLOCK, TOP_BLOCK + 0.02, 0.22 + i * 0.11, -0.12, 0.01, 16)
    join("Korpus", parts)
    paint(cyl("Glas", 0.075, TOP_BLOCK, TOP_BLOCK + 0.016, 0.44, 0.1, steps=24), "glass", GLASS_VIOLET)
    box("Licht", 0.06, 0.03, TOP_BLOCK + 0.016, TOP_BLOCK + 0.02, 0.44, 0.1)
    export("error_memory")


def starter():
    pm.reset()
    join("Korpus", f_block())
    lights = []
    for k in range(10):
        a0, a1 = math.radians(120 + 30 * k), math.radians(150 + 30 * k)
        lights.append(bar("Zeichen", (0.44 + 0.13 * math.cos(a0), 0.13 * math.sin(a0)),
                          (0.44 + 0.13 * math.cos(a1), 0.13 * math.sin(a1)), 0.04, TOP_BLOCK, TOP_BLOCK + 0.012))
    lights.append(bar("Zeichen", (0.44, 0.02), (0.44, 0.17), 0.045, TOP_BLOCK, TOP_BLOCK + 0.014))
    join("Licht", lights)
    export("starter")


# --- Kontakte ---------------------------------------------------------------------------------

def relay():
    pm.reset()
    parts, lights = f_fork((0.15, -0.15), (0,))
    parts.append(paint(along("Spule", ribbed(0.1, 0.09, -0.06, 0.06, 6), 0.16, 0.0, 0.38, angle=18), "metal", COPPER))
    join("Korpus", parts)
    join("Licht", lights)
    export("relay")


def output_stage():
    pm.reset()
    parts, lights = f_fork((0.15, -0.15), (1,))
    for i in range(3):
        parts.append(paint(box("Rippe", 0.025, 0.5, 0.36, 0.46, 0.11 + i * 0.05, 0.0), "metal", ALU))
    join("Korpus", parts)
    join("Licht", lights)
    export("output_stage")


def shunt():
    pm.reset()
    parts, lights = f_fork((0.15, -0.15), (0, 1))
    parts.append(paint(box("Buegel", 0.1, 0.44, 0.3, 0.38, 0.52, 0.0, 0.02), "metal", COPPER))
    join("Korpus", parts)
    join("Licht", lights)
    export("shunt")


def parallel_circuit():
    pm.reset()
    parts, lights = f_fork((0.22, 0.075, -0.075, -0.22), (0, 1, 2, 3))
    join("Korpus", parts)
    join("Licht", lights)
    export("parallel_circuit")


# --- Röhren -----------------------------------------------------------------------------------

def amplifier_tube():
    pm.reset()
    parts, core = f_tube(0.14, 0.86, 0.15)
    for u in (0.42, 0.6):
        parts.append(paint(along("Gitter", [(0.158, -0.015), (0.158, 0.015)], u, 0.0, AX, caps=False), "metal", STEEL))
    join("Korpus", parts)
    core.name = "Licht"
    export("amplifier_tube")


def high_voltage_tube():
    pm.reset()
    parts, core = f_tube(0.14, 0.68, 0.18)
    parts.append(paint(along("Kugel", [(0.0, -0.1), (0.07, -0.08), (0.1, 0.0), (0.07, 0.08), (0.0, 0.1)], 0.79, 0.0, AX,
                             steps=24), "metal", STEEL))
    join("Korpus", parts)
    join("Licht", [core, along("Korona", [(0.215, -0.025), (0.24, -0.025), (0.24, 0.025), (0.215, 0.025), (0.215, -0.025)],
                                0.41, 0.0, AX, caps=False)])
    export("high_voltage_tube")


def resonator():
    pm.reset()
    parts, core = f_tube(0.14, 0.86, 0.12)
    join("Korpus", parts)
    core.name = "Licht"
    for k in range(5):
        along("Ring%d" % k, [(0.135, -0.022), (0.165, -0.022), (0.165, 0.022), (0.135, 0.022), (0.135, -0.022)],
              0.3 + k * 0.1, 0.0, AX, caps=False)
    export("resonator")


def afterburner():
    pm.reset()
    parts, core = f_tube(0.14, 0.44, 0.13)
    parts.append(paint(along("Duese", [(0.13, -0.08), (0.2, 0.08)], 0.52, 0.0, AX, caps=False), "metal", STEEL))
    for k in range(8):
        a = math.tau * k / 8
        p0 = (0.44, 0.13 * math.cos(a), AX + 0.13 * math.sin(a))
        p1 = (0.6, 0.2 * math.cos(a), AX + 0.2 * math.sin(a))
        parts.append(paint(pm.strut("Lamelle", p0, p1, 0.012, 6), "gloss", BLACK))
    join("Korpus", parts)
    core.name = "Licht"
    along("Flamme", [(0.0, -0.14), (0.16, -0.1), (0.07, 0.0), (0.11, 0.06), (0.04, 0.12), (0.0, 0.16)], 0.72, 0.0, AX,
          steps=24)
    export("afterburner")


# --- Abgriffe ---------------------------------------------------------------------------------

def coin_validator():
    pm.reset()
    parts = f_blade()
    parts.append(paint(pm.dome("Muenze", [(0.15, 0.16), (0.15, 0.2), (0.13, 0.215), (0.0, 0.215)], 0.62, 0.0),
                       "metal", GOLD))
    parts.append(paint(ring("Praegung", 0.05, 0.075, 0.215, 0.22, 0.62, 0.0, 32), "metal", COPPER))
    join("Korpus", parts)
    box("Licht", 0.05, 0.36, 0.16, 0.172, 0.28, 0.0)
    export("coin_validator")


def power_pickup():
    pm.reset()
    parts = f_blade()
    parts.append(paint(box("Schleifer", 0.08, 0.5, 0.16, 0.24, 0.82, 0.0, 0.02), "metal", COPPER))
    join("Korpus", parts)
    zig = [(0.2, -0.14), (0.34, 0.12), (0.46, -0.1), (0.6, 0.13), (0.7, -0.06)]
    join("Licht", [bar("Funke", a, b, 0.04, 0.16, 0.172) for a, b in zip(zig, zig[1:])])
    export("power_pickup")


def blocking_diode():
    pm.reset()
    join("Korpus", f_blade())
    join("Licht", [prism("Dreieck", uv_outline([(0.3, 0.17), (0.3, -0.17), (0.58, 0.0)]), 0.16, 0.172),
                   box("Strich", 0.05, 0.36, 0.16, 0.172, 0.62, 0.0)])
    export("blocking_diode")


# --- Brücken ----------------------------------------------------------------------------------

def cross_bridge():
    pm.reset()
    join("Korpus", f_link())
    join("Licht", arrow("Pfeil", [(0.14, 0.0), (0.66, 0.0)], (1, 0), 0.08, 0.1, 0.14))
    export("cross_bridge")


def down_bridge():
    pm.reset()
    join("Korpus", f_link())
    join("Licht", arrow("Pfeil", [(0.14, 0.1), (0.56, 0.1), (0.56, -0.04)], (0, -1), 0.08, 0.1, 0.14))
    export("down_bridge")


def coupling():
    pm.reset()
    join("Korpus", f_link())
    lights = arrow("Pfeil", [(0.5, 0.0), (0.24, 0.0)], (-1, 0), 0.07, 0.1, 0.14)
    for su in (-1, 1):
        lights.append(bar("Abbild", (0.7 + su * 0.11, -0.14), (0.7 + su * 0.11, 0.14), 0.04, 0.1, 0.14))
        lights.append(bar("Abbild", (0.59, su * 0.12), (0.81, su * 0.12), 0.04, 0.1, 0.14))
    join("Licht", lights)
    export("coupling")


# --- Der leere Pin ----------------------------------------------------------------------------

def empty():
    """Ein schlichter Stahlpin wie die linken: aus der Kante, hinunter auf den Tisch, ein Fuß."""
    pm.reset()
    join("Korpus", [paint(box("Arm", 0.3, 0.4, 0.38, 0.48, NECK + 0.12, 0.0, 0.015), "metal", STEEL),
                    paint(box("Bug", 0.09, 0.4, 0.0, 0.48, 0.24, 0.0, 0.015), "metal", STEEL),
                    paint(box("Fuss", 0.26, 0.4, 0.0, 0.07, 0.33, 0.0, 0.015), "metal", STEEL)])
    export("empty")


BUILDS = {"resistor": resistor, "coil": coil, "series_resistor": series_resistor, "series_terminal": series_terminal,
          "capacitor": capacitor, "solder_joint": solder_joint, "counter": counter_part, "error_memory": error_memory,
          "starter": starter, "relay": relay, "output_stage": output_stage, "shunt": shunt,
          "parallel_circuit": parallel_circuit, "amplifier_tube": amplifier_tube,
          "high_voltage_tube": high_voltage_tube, "resonator": resonator,
          "afterburner": afterburner, "coin_validator": coin_validator, "power_pickup": power_pickup,
          "blocking_diode": blocking_diode, "cross_bridge": cross_bridge, "down_bridge": down_bridge,
          "coupling": coupling, "empty": empty}

for name, build in BUILDS.items():
    if not ONLY or name in ONLY:
        build()
