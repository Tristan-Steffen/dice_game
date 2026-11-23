"""Fumble: ENTWURF - der Kombinations-Chip mit drei MODUL-SEKTIONEN (2026-11-23).
Das rechte Viertel des Chips sind drei Fächer; ein Modul ERSETZT sein Fach, sein Pin ist das
rechte Ende. Drei Test-Module: Zählwerk, Querbrücke, Nachbrenner.

Aufruf (kopflos):
  blender -b -P tools/blender_combo_bay_variants.py -- <ausgabe-ordner> [ansicht,...]
Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tischfläche bei Z = 0.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms
import blender_chip_screens as cs
import blender_combo_module_variants as cv

led = dm.led
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
dm.HEX["link"] = "#ff73d9"
dm.HEX["krit"] = "#bf59ff"
dm.HEX["flamme"] = "#ff8a2a"

CW, CD, CH, Z0 = 2.6, 1.0, 0.28, 0.03
BAY = 0.66            # das rechte Viertel
RAIL, WEB = 0.03, 0.02
PITCH = (CD - 2 * RAIL - 2 * WEB) / 3 + WEB
ML, MD, MH = BAY - 0.01, PITCH - WEB - 0.01, CH + 0.015
PZ = 0.09             # Pin-Achse über dem Modulboden


def poly(r, name, pts, z0, z1, material):
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


def lying(r, name, radius, depth, x, z, material, y=0.0):
    o = dm.cyl(r, name, radius, depth, (x, y, z), material, 48)
    o.rotation_euler = (0, math.radians(90), 0)
    return o


PIN = (0.08, 0.16, 0.1)   # der EINE Pin: Länge, Breite, Höhe - wie der Stummel des Blindfachs
RARITY = {"gewoehnlich": "#d9e6ff", "selten": "#408cff", "episch": "#bf59ff", "legendaer": "#ffbf33"}
for _k, _v in RARITY.items():
    dm.HEX["r_" + _k] = _v
RARITY_NAMES = {"gewoehnlich": "GEWÖHNLICH", "selten": "SELTEN", "episch": "EPISCH", "legendaer": "LEGENDÄR"}


LEG = [(0, 0.17), (0.07, 0.17), (0.13, 0.04), (0.21, 0.04), (0.21, 0.0), (0.11, 0.0), (0.05, 0.13), (0, 0.13)]
ZT = -(Z0 + 0.02)     # die Tischfläche, vom Modulboden aus


def leg(r, name, x0, y, zt, width, material, sign=1):
    """Gull-Wing-Beinchen: Schulter am Gehäuse, Knick, Fuß auf dem Tisch."""
    n = len(LEG)
    verts = [(x0 + sign * px, y + dy, zt + pz) for dy in (-width * 0.5, width * 0.5) for px, pz in LEG]
    faces = [list(range(n)), list(range(n, 2 * n))[::-1]]
    faces += [[i, n + i, n + (i + 1) % n, (i + 1) % n] for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    o.select_set(False)
    o.data.materials.append(material)
    o.parent = r
    return o


def pin(r, rarity=None, key=None):
    """EIN Beinchen für alle: die Schulter-LED nennt die Seltenheit, die Fuß-LED die Art."""
    leg(r, "Bein", ML, 0, ZT, 0.16, cs.m_steel())
    if rarity:
        cs.boxes(r, "LedSeltenheit", [(ML + 0.035, 0, ZT + 0.172, 0.03, 0.11, 0.006)], dm.glow("r_" + rarity, 3.4))
    if key:
        cs.boxes(r, "LedArt", [(ML + 0.17, 0, ZT + 0.042, 0.03, 0.11, 0.006)], dm.glow(key, 3.2))


def shell(r, key, tone, rarity):
    led.rounded_box(r, "Modul", (ML, MD, MH), (ML * 0.5, 0, MH * 0.5),
                    led.mat("Schale_" + key, tone, 0.7, 0.32, clearcoat=0.3), 0.025, 0.012)
    cs.boxes(r, "Status", [(0.04, 0, MH + 0.002, 0.03, MD - 0.08, 0.006)], dm.glow(key, 3.2))
    pin(r, rarity, key)


# --- die drei Test-Module (lokal: Fach x 0..ML, der Pin sitzt rechts davor) ----------------

def mod_zaehlwerk(r, rarity, count="008"):
    shell(r, "mult", (0.09, 0.09, 0.12), rarity)
    cs.boxes(r, "Fenster", [(0.34, 0, MH + 0.003, 0.4, MD - 0.08, 0.008)], cv.m_glass())
    cv.txt(r, count, 0.34, 0.0, MH + 0.009, 0.17, "mult", 3.4, "CENTER")
    cs.boxes(r, "Steg", [(0.34 + s * 0.065, 0, MH + 0.009, 0.008, MD - 0.1, 0.006) for s in (-1, 1)],
             cs.m_steel())


def mod_querbruecke(r, rarity):
    shell(r, "link", (0.13, 0.05, 0.15), rarity)
    cs.strips(r, "Pfeil", [[(0.13, 0), (0.56, 0)], [(0.46, 0.085), (0.56, 0), (0.46, -0.085)]], 0.04,
              MH + 0.003, dm.glow("link", 3.4))


def mod_nachbrenner(r, rarity):
    shell(r, "krit", (0.14, 0.085, 0.06), rarity)
    cs.boxes(r, "Glut", [(0.22, 0, MH + 0.002, 0.24, MD - 0.1, 0.004)], dm.glow("flamme", 1.6))
    cs.boxes(r, "Rippe", [(0.13 + i * 0.06, 0, MH + 0.012, 0.025, MD - 0.07, 0.022) for i in range(4)],
             cs.m_steel())
    # die Düse sitzt im Deckel
    dm.cyl(r, "Duese", 0.1, 0.03, (0.49, 0, MH + 0.012), cs.m_steel(), 48)
    dm.cyl(r, "Brennkammer", 0.07, 0.008, (0.49, 0, MH + 0.026), dm.glow("flamme", 4.0), 48)
    dm.cyl(r, "Kern", 0.03, 0.008, (0.49, 0, MH + 0.03), led.mat("Kern", (1.0, 0.95, 0.7), 0.0, 0.3, 6.0), 32)


def mod_leer(r, rarity=None):
    """Das Blindfach: ein kleiner Chip - Gehäuse, dunkles Glas, Stahl-Pin."""
    led.rounded_box(r, "Blind", (ML, MD, CH), (ML * 0.5, 0, CH * 0.5), cv.m_body(False), 0.025, 0.012)
    led.rounded_box(r, "BlindGlas", (ML - 0.1, MD - 0.08, 0.008), (ML * 0.5, 0, CH), cv.m_glass(), 0.02, 0.0)
    pin(r)


MODS = {"zaehlwerk": (mod_zaehlwerk, "mult", "ZÄHLWERK", "+1 Mult, wächst je Wertung", "episch"),
        "querbruecke": (mod_querbruecke, "link", "QUERBRÜCKE", "aktiviert den Chip rechts", "legendaer"),
        "nachbrenner": (mod_nachbrenner, "krit", "NACHBRENNER", "×2 Mult nach einem Fumble", "episch")}


def module(parent, mod, x, y, z, scale=1.0, rarity=None):
    r = cs.root("Modul_" + (mod or "leer"))
    r.parent = parent
    (MODS[mod][0] if mod else mod_leer)(r, rarity or (MODS[mod][4] if mod else None))
    r.location = (x, y, z)
    r.scale = (scale, scale, scale)
    return r


# --- der Chip ------------------------------------------------------------------------------

def chip(r, ux, cy, name, pts, mult, mods, lift=None):
    """mods: drei Einträge (Modul-Schlüssel oder None), Fach 0 oben. lift: (Fach, dx, dz)."""
    left, right = ux - CW * 0.5, ux + CW * 0.5
    mw = CW - BAY
    mx = left + mw * 0.5
    seam = right - BAY
    body = cv.m_body(False)
    led.rounded_box(r, "Body", (mw, CD, CH), (mx, cy, Z0 + CH * 0.5), body, 0.06, 0.02)
    zc = Z0 + CH * 0.5
    rails = [(seam + BAY * 0.5, cy + s * (CD - RAIL) * 0.5, zc, BAY, RAIL, CH) for s in (-1, 1)]
    webs = [(seam + BAY * 0.5, cy + s * PITCH * 0.5, zc - 0.01, BAY, WEB, CH - 0.02) for s in (-1, 1)]
    cs.boxes(r, "Faecher", rails + webs + [(seam + BAY * 0.5, cy, Z0 + 0.01, BAY, CD, 0.02)], body)
    top = Z0 + CH
    for k in (-1, 0, 1):
        leg(r, "PinLinks", left, cy + k * PITCH, 0.0, 0.16, cs.m_steel(), -1)
    pads = [(x, cy + k * PITCH, 0.002, 0.16, 0.2, 0.004) for k in (-1, 0, 1) for x in (left - 0.16, right + 0.155)]
    cs.boxes(r, "Pads", pads, led.mat("Pad", (0.16, 0.13, 0.07), 0.8, 0.45))
    gw = mw - 0.2
    led.rounded_box(r, "Glas", (gw, CD - 0.18, 0.012), (left + 0.08 + gw * 0.5, cy + 0.01, top),
                    cv.m_glass(), 0.04, 0.0)
    x0, z = left + 0.2, top + 0.008
    cv.txt(r, name, x0, cy + 0.2, z, 0.2 if len(name) < 16 else 0.15, "name")
    cv.txt(r, pts, x0, cy - 0.2, z, 0.28, "punkte")
    cv.txt(r, mult, x0 + 0.175 * len(pts) + 0.1, cy - 0.2, z, 0.28, "mult")
    cv.band(r, mx, cy - CD * 0.5 - 0.03, 0.2, mw - 0.2)
    for k in range(3):
        mod = mods[k]
        row = cy + (1 - k) * PITCH
        cs.boxes(r, "Naht", [(seam - 0.05, row, top + 0.003, 0.025, MD - 0.08, 0.006)],
                 dm.glow(MODS[mod][1], 2.6) if mod else cv.m_dim())
        dx, dz = (lift[1], lift[2]) if lift and lift[0] == k else (0.0, 0.0)
        module(r, mod, seam + 0.005 + dx, row, Z0 + 0.02 + dz)


# --- Ansichten -----------------------------------------------------------------------------

def view_voll():
    r = cs.root("Voll")
    chip(r, 0, 0, "Doppelter Dreierpasch", "51", "×8", ["querbruecke", "zaehlwerk", "nachbrenner"])
    return [((0.35, 0.0, 0.12), (2.3, -2.5, 2.3), 50)]


def view_stufen():
    r = cs.root("Stufen")
    chip(r, 0, 1.5, "Full House", "28", "×4", [None, None, None])
    chip(r, 0, 0, "Drei Zweierpäsche", "32", "×5", [None, "zaehlwerk", None], (1, 0.5, 0.42))
    chip(r, 0, -1.5, "Große Straße", "45", "×8", ["querbruecke", "zaehlwerk", "nachbrenner"])
    ms.label("LEER — drei Blindfächer", -2.75, 1.5, 0.13)
    ms.label("EINBAU — das Modul ersetzt sein Fach", -2.75, 0.0, 0.13)
    ms.label("VOLL — jedes Modul steht auf seinem Pin", -2.75, -1.5, 0.13)
    return [((-0.5, 0.0, 0.1), (-0.1, -5.0, 7.6), 50), ((1.0, -0.1, 0.2), (3.6, -3.1, 2.7), 50)]


def view_module():
    r = cs.root("Module")
    for i, key in enumerate(MODS):
        x = (i - 1) * 2.3 - 0.8
        module(r, key, x, 0.9, -ZT * 2.2, 2.2)
        ms.label(MODS[key][2], x + 0.8, 0.3, 0.17)
        ms.label(MODS[key][3], x + 0.8, 0.06, 0.11)
    names = list(RARITY) + [None]
    for i, rarity in enumerate(names):
        x = (i - 2) * 1.85 - 0.75
        module(r, "zaehlwerk" if rarity else None, x, -1.1, -ZT * 2.0, 2.0, rarity)
        ms.label(RARITY_NAMES[rarity] if rarity else "BLINDFACH", x + 0.75, -1.62, 0.12)
    ms.label("DER PIN: überall gleich — Schulter-LED = Seltenheit, Fuß-LED = Art", 0.0, -2.0, 0.13)
    return [((0.0, -0.4, 0.1), (0.0, -5.6, 13.5), 50), ((0.3, 0.8, 0.2), (4.4, -3.4, 3.4), 50)]


FIELD = [("5 of a Kind", "50", "×10", [None, None, None]),
         ("Große Straße", "45", "×8", ["zaehlwerk", None, None]),
         ("Doppelter Dreierpasch", "51", "×8", ["querbruecke", "zaehlwerk", "nachbrenner"]),
         ("Drei Zweierpäsche", "32", "×5", [None, None, None]),
         ("Full House", "28", "×4", [None, "nachbrenner", None]),
         ("Kleine Straße", "22", "×4", ["zaehlwerk", "zaehlwerk", None]),
         ("Zwei Paare", "15", "×3", [None, None, "querbruecke"]),
         ("Paar", "10", "×2", [None, None, None])]


def view_feld():
    r = cs.root("Feld")
    lines = []
    for i, (name, pts, mult, mods) in enumerate(FIELD):
        ux, cy = (i % 2 - 0.5) * 3.75, 1.95 - (i // 2) * 1.3
        chip(r, ux, cy, name, pts, mult, mods)
        for k in (-1, 0, 1):
            lines.append([(ux - CW * 0.5 - 0.08, cy + k * PITCH), (ux - CW * 0.5 - 0.3, cy + k * PITCH)])
    for c in (-1, 0):
        x = c * 3.75 + 1.875 - CW * 0.5 - 0.3
        lines.append([(x, 2.7), (x, -2.7)])
    cs.strips(r, "Bus", lines, 0.035, 0.002, led.mat("Bahn2", (0.03, 0.035, 0.07), 0.2, 0.5))
    return [((0.1, 0.0, 0.0), (0.1, -2.6, 13.5), 50), ((0.2, 0.5, 0.1), (1.3, -4.6, 4.8), 50)]


VIEWS = {"1_chip_voll": view_voll, "2_stufen": view_stufen, "3_module": view_module, "4_feld": view_feld}

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
