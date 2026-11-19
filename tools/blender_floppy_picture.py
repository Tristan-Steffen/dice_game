"""Fumble: zwei Entwürfe, das Charm-BILD auf der Diskette größer zu machen (Spieler-Wunsch
2026-11-18). Das Textfeld bleibt, wie es im Spiel steht (kurzer Einschub, große Schrift).
  heute    - die kleine Kachel links neben dem Schieber (Stand im Spiel)
  schieber - das Bild ist auf den Metallschieber GEDRUCKT, ein schmaler Schlitz bleibt am Rand
  fenster  - der Schieber bleibt blank, sein Fenster ist breit, dahinter liegt das Bild wie auf
             der Magnetscheibe

Aufruf (kopflos):
  blender -b -P tools/blender_floppy_picture.py -- <ausgabe-ordner>
"""
import bpy, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_floppy_charm as fc
import blender_floppy_layouts as fl

DW, DL, DT, ZT = fc.DW, fc.DL, fc.DT, fl.ZT
SHUTTER = (-0.03, DL * 0.5 - 0.15, 0.4, 0.3)   # Mitte x, Mitte y, Breite, Höhe
SHUTTER_TOP = ZT + 0.0035
GLASS = (-0.405, -0.455, 0.405, 0.15)
# Die Felder des Spiels (CharmDiskView): Name, Wirkung, Fuß.
NAME_Y, DESC_TOP, DESC_BOTTOM, FOOT_Y = 0.085, 0.035, -0.385, -0.415
TEXT_LEFT, TEXT_WIDTH = -0.365, 0.73
TAG = (0.31, 0.33)


def materials(rarity):
    rc = fc.srgb(fc.RARITY[rarity][1])
    return {
        "body": led.mat("Schwarzlack", (0.075, 0.075, 0.09), 0.1, 0.28, clearcoat=0.6),
        "shutter": led.mat("Schieberstahl", (0.32, 0.33, 0.37), 0.6, 0.3),
        "dark": led.mat("Scheibe", (0.03, 0.022, 0.018), 0.2, 0.35),
        "hole": led.mat("Loch", (0.004, 0.004, 0.006), 0.0, 0.5),
        "glass": led.mat("Glasfront", (0.02, 0.032, 0.04), 0.0, 0.35, 0.6, clearcoat=0.25),
        "name": fl.emissive("Name_" + rarity, rc, 3.0),
        "cyan": fl.emissive("Bildschirm", (0.55, 0.95, 1.0), 1.6),
        "dim": fl.emissive("BildschirmDunkel", (0.19, 0.33, 0.35), 1.0),
        "gold": fl.emissive("Preis", (1.0, 0.83, 0.1), 2.0),
        "rc": rc,
    }


def body(parent, m, window):
    """Gehäuse, Schieber und Löcher; window = (mitte x, mitte y, breite, höhe) oder None."""
    b = led.rounded_box(parent, "Gehaeuse", (DW, DL, DT), (0, 0, 0), m["body"], 0.012, 0.003, 6)
    bpy.ops.mesh.primitive_cube_add(size=0.07, location=(DW * 0.5, DL * 0.5, 0),
                                    rotation=(0, 0, math.radians(45)))
    corner = bpy.context.active_object
    corner.parent = parent
    led.cut(b, corner)
    sx, sy, sw, sh = SHUTTER
    shutter = led.rounded_box(parent, "Schieber", (sw, sh, DT + 0.007), (sx, sy, 0), m["shutter"], 0.006,
                              0.0015, 4)
    # Die Naht, an der der Schieber gleitet - auch bedruckt liest er so als Schieber.
    fl.plane(parent, "Naht", sx - sw * 0.5, sy - sh * 0.5 - 0.006, sx + sw * 0.5, sy - sh * 0.5 - 0.002,
             m["hole"], 0.0005)
    if window:
        wx, wy, ww, wh = window
        fc.box(parent, "Fenster", (ww, wh, DT + 0.0075), (wx, wy, 0), m["dark"])
    for side in (-1, 1):
        fc.box(parent, "Loch%d" % side, (0.03, 0.03, DT + 0.001), (side * 0.418, -DL * 0.5 + 0.04, 0),
               m["hole"])
    return shutter


def screen(parent, charm, m):
    """Glasfront, Rahmen, Name, Wirkung, LEDs - genau wie im Spiel."""
    cid, name, desc, rarity = charm
    x0, y0, x1, y1 = GLASS
    led.rounded_box(parent, "Glasfront", (x1 - x0, y1 - y0, 0.003), (0, (y0 + y1) * 0.5, ZT + 0.0012),
                    m["glass"], 0.015, 0.0008, 4)
    z = 0.0029
    t = 0.006
    for (a, b, c, e) in ((x0 + 0.012, y1 - 0.012 - t, x1 - 0.012, y1 - 0.012),
                         (x0 + 0.012, y0 + 0.012, x1 - 0.012, y0 + 0.012 + t),
                         (x0 + 0.012, y0 + 0.012, x0 + 0.012 + t, y1 - 0.012),
                         (x1 - 0.012 - t, y0 + 0.012, x1 - 0.012, y1 - 0.012)):
        fl.plane(parent, "Rahmen", a, b, c, e, m["name"], z)
    n = fl.fit_line(parent, "> " + name.upper(), TEXT_LEFT, NAME_Y, m["name"], fl.MONO, TEXT_WIDTH,
                    "LEFT", 0.135)
    n.location.z = ZT + z
    d = fl.fit(parent, desc, TEXT_LEFT, DESC_TOP, DESC_BOTTOM, m["cyan"], fl.MONO, TEXT_WIDTH, "LEFT", 0.13)
    d.location.z = ZT + z
    off = led.mat("LedAus", (0.02, 0.02, 0.025), 0.0, 0.15, clearcoat=1.0)
    for k in range(4):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.014, location=(x1 - 0.045 - (3 - k) * 0.042,
                                                                     FOOT_Y, ZT + z))
        o = bpy.context.active_object
        o.scale = (1, 1, 0.4)
        o.data.materials.append(m["name"] if k < fl.TIER[rarity] else off)
        o.parent = parent
    fl.txt(parent, fc.RARITY[rarity][0], TEXT_LEFT, FOOT_Y, 0.03, m["dim"], fl.MONO, "LEFT",
           name="Raritaet").location.z = ZT + z


def price(parent, m, text="$8"):
    fl.txt(parent, text, TAG[0], TAG[1], 0.075, m["gold"], fl.MONO, name="Preis").location.z = ZT + 0.002


def art(cid, rc, path, name):
    return fl.art_mat(name + "_" + cid, path, [c * 0.4 for c in rc], (0.01, 0.008, 0.02))


HUB = (0.0, 0.03)       # Mitte der Scheibe = Nabe auf der Rückseite
DISC_R = 0.405


def disc_mat(cid, rc, path, rect):
    """Das Bild liegt auf der runden Scheibe: außerhalb ihres Rands dunkles Gehäuse, am Rand ein Saum."""
    m = art(cid, rc, path, "Holoscheibe")
    nt = m.node_tree
    nodes, link = nt.nodes, nt.links.new
    p = nodes["Principled BSDF"]
    src = p.inputs["Base Color"].links[0].from_socket
    tc = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    link(tc.outputs["UV"], sep.inputs[0])
    comb = nodes.new("ShaderNodeCombineXYZ")
    for axis, lo, hi in ((0, rect[0], rect[2]), (1, rect[1], rect[3])):
        mr = nodes.new("ShaderNodeMapRange")
        mr.inputs["To Min"].default_value = lo
        mr.inputs["To Max"].default_value = hi
        link(sep.outputs[axis], mr.inputs[0])
        link(mr.outputs[0], comb.inputs[axis])
    dist = nodes.new("ShaderNodeVectorMath")
    dist.operation = "DISTANCE"
    dist.inputs[1].default_value = (HUB[0], HUB[1], 0)
    link(comb.outputs[0], dist.inputs[0])
    inside = nodes.new("ShaderNodeMath")
    inside.operation = "LESS_THAN"
    inside.inputs[1].default_value = DISC_R
    link(dist.outputs["Value"], inside.inputs[0])
    rim = nodes.new("ShaderNodeMapRange")
    rim.inputs["From Min"].default_value = DISC_R - 0.012
    rim.inputs["From Max"].default_value = DISC_R
    link(dist.outputs["Value"], rim.inputs[0])
    rim_band = nodes.new("ShaderNodeMath")
    rim_band.operation = "MULTIPLY"
    link(rim.outputs[0], rim_band.inputs[0])
    link(inside.outputs[0], rim_band.inputs[1])
    dark = nodes.new("ShaderNodeMixRGB")
    link(inside.outputs[0], dark.inputs[0])
    dark.inputs[1].default_value = (0.006, 0.006, 0.008, 1)
    link(src, dark.inputs[2])
    edge = nodes.new("ShaderNodeMixRGB")
    link(rim_band.outputs[0], edge.inputs[0])
    link(dark.outputs[0], edge.inputs[1])
    edge.inputs[2].default_value = (0.3, 0.29, 0.28, 1)
    link(edge.outputs[0], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.25
    p.inputs["Metallic"].default_value = 0.15
    return m


def glass_mat():
    """Versiegeltes Fenster: fast klar, glänzend, mit einem schrägen Lichtstreif."""
    if "Fensterglas" in bpy.data.materials:
        return bpy.data.materials["Fensterglas"]
    m = bpy.data.materials.new("Fensterglas")
    m.use_nodes = True
    m.blend_method = "BLEND"
    m.shadow_method = "NONE"
    nt = m.node_tree
    nodes, link = nt.nodes, nt.links.new
    p = nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.9, 0.95, 1.0, 1)
    p.inputs["Roughness"].default_value = 0.03
    p.inputs["Specular"].default_value = 1.0
    p.inputs["Clearcoat"].default_value = 1.0
    tc = nodes.new("ShaderNodeTexCoord")
    dot = nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = (0.62, 0.45, 0)
    link(tc.outputs["UV"], dot.inputs[0])
    ramp = nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.36, (0, 0, 0, 1)
    els[1].position, els[1].color = 0.39, (1, 1, 1, 1)
    e2 = els.new(0.41)
    e2.color = (1, 1, 1, 1)
    e3 = els.new(0.44)
    e3.color = (0, 0, 0, 1)
    link(dot.outputs["Value"], ramp.inputs[0])
    alpha = nodes.new("ShaderNodeMapRange")
    alpha.inputs["To Min"].default_value = 0.02
    alpha.inputs["To Max"].default_value = 0.13
    link(ramp.outputs[0], alpha.inputs[0])
    link(alpha.outputs[0], p.inputs["Alpha"])
    link(ramp.outputs[0], p.inputs["Emission"])
    p.inputs["Emission Strength"].default_value = 0.12
    return m


# --- die drei Fassungen -------------------------------------------------------------------

def heute(parent, charm, arts):
    m = materials(charm[3])
    body(parent, m, (0.04, DL * 0.5 - 0.145, 0.11, 0.2))
    fl.plane(parent, "Kachel", -0.435, 0.205, -0.245, 0.395, art(charm[0], m["rc"], arts["kachel"], "Kachel"))
    screen(parent, charm, m)
    price(parent, m)


def schieber(parent, charm, arts):
    m = materials(charm[3])
    body(parent, m, None)
    sx, sy, sw, sh = SHUTTER
    # Ein schmaler Schlitz am rechten Rand bleibt - das Fenster, das jeder Schieber hat.
    slot = 0.045
    sx0, sx1 = sx + sw * 0.5 - 0.02 - slot, sx + sw * 0.5 - 0.02
    sy0, sy1 = sy - sh * 0.5 + 0.03, sy + sh * 0.5 - 0.03
    fl.plane(parent, "Schlitz", sx0, sy0, sx1, sy1, m["hole"], SHUTTER_TOP - ZT)
    # Durch den Schlitz sieht man die braune Magnetscheibe - der Schieber bleibt ein Schieber.
    fl.plane(parent, "Magnetscheibe", sx0 + 0.008, sy0 + 0.008, sx1 - 0.008, sy1 - 0.008,
             led.mat("Magnetschicht", (0.09, 0.055, 0.035), 0.3, 0.45), SHUTTER_TOP - ZT + 0.0002)
    x0, x1 = sx - sw * 0.5 + 0.018, sx + sw * 0.5 - 0.03 - slot
    y0, y1 = sy - sh * 0.5 + 0.018, sy + sh * 0.5 - 0.018
    fl.plane(parent, "Druck", x0, y0, x1, y1, art(charm[0], m["rc"], arts["schieber"], "Druck"),
             SHUTTER_TOP - ZT + 0.0003)
    screen(parent, charm, m)
    price(parent, m)


def fenster(parent, charm, arts):
    m = materials(charm[3])
    sx, sy, sw, sh = SHUTTER
    win = (sx, sy - 0.006, sw - 0.07, sh - 0.075)
    shutter = body(parent, m, None)
    wx, wy, ww, wh = win
    # Das Fenster ist in den Schieber geschnitten; darunter liegt die Holo-Scheibe, darüber Glas.
    cutter = fc.box(parent, "SchnittFenster", (ww, wh, 0.01), (wx, wy, SHUTTER_TOP), m["hole"])
    led.cut(shutter, cutter)
    rect = (wx - ww * 0.5, wy - wh * 0.5, wx + ww * 0.5, wy + wh * 0.5)
    fl.plane(parent, "Scheibe", *rect, disc_mat(charm[0], m["rc"], arts["fenster"], rect), 0.0004)
    fl.plane(parent, "Glas", *rect, glass_mat(), 0.0026)
    screen(parent, charm, m)
    price(parent, m)


VARIANTS = [("heute", heute), ("schieber", schieber), ("fenster", fenster)]
SHOP = [fc.CHARMS[3], fc.CHARMS[5], fc.CHARMS[0]]


def render_arts(cids):
    """Je Charm drei Bild-Zuschnitte: Kachel (quadratisch), Schieberdruck, Fenster."""
    sx, sy, sw, sh = SHUTTER
    out = {}
    for cid in cids:
        out[cid] = {
            "kachel": fl.render_art(cid, 1.0, 0.82, 0.5, "kachel"),
            "schieber": fl.render_art(cid, (sw - 0.083) / (sh - 0.036), 0.88, 0.5, "schieber"),
            "fenster": fl.render_art(cid, (sw - 0.086) / (sh - 0.091), 0.86, 0.5, "fenster"),
        }
    return out


def lay(build, charm, arts, x, y=0.0):
    root = fc.empty("Diskette_%s_%s" % (build.__name__, charm[0]))
    build(root, charm, arts[charm[0]])
    root.location = (x, y, ZT + 0.001)
    return root


def main():
    charms = {c[0]: c for c in SHOP + [fc.CHARMS[2]]}
    arts = render_arts(list(charms))
    hero = fc.CHARMS[2]
    # 1. Vergleich: dieselbe Diskette in allen drei Fassungen, aus dem Winkel des Ladens.
    fc.stage((2400, 1000))
    for i, (_, build) in enumerate(VARIANTS):
        lay(build, hero, arts, (i - 1) * 1.08)
    fc.camera((0, -1.25, 4.7), (0, -0.02, 0), 50)
    fc.shoot("1_vergleich")
    # 2./3. Je Entwurf eine Laden-Reihe aus drei Charms, plus eine Nahaufnahme.
    for name, build in VARIANTS[1:]:
        fc.stage((2400, 1000))
        for i, charm in enumerate(SHOP):
            lay(build, charm, arts, (i - 1) * 1.08)
        fc.camera((0, -1.25, 4.7), (0, -0.02, 0), 50)
        fc.shoot("2_laden_" + name)
        fc.stage((1400, 1200))
        lay(build, hero, arts, 0.0)
        fc.camera((0.35, -1.05, 1.45), (0, 0.05, 0), 50)
        fc.shoot("3_nah_" + name, True)
    print("ok")


if __name__ == "__main__":
    main()
