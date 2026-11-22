class_name CharmDiskView
extends Node3D
## Die CHARM-DISKETTE (Spieler-Entscheid 2026-11-18, Layout TERMINAL; seit dem 2026-11-22 die
## Fassung „Stahl“: gebürstete Stahlschale, Chrom-Schieber, Raritäts-Streifen links): eine
## 3,5"-Diskette mit schwarzer Glasfront. OBEN (steckt im Laufwerk) der Schieber, durch sein breites Fenster sieht man
## die HOLO-SCHEIBE mit dem Charm-Bild unter Glas,
## UNTEN (bleibt draußen) die Wirkung in Bildschirm-Cyan, Raritätswort und vier LEDs - den NAMEN
## trägt das Display des Projektors. Ursprung = Mitte der Unterseite; lokal +X = Schieber-Ende
## (steckt zuerst), +Z = Bild-rechts, +Y = oben. EINE Größe überall (SIZE).

## Blender-Einheit → Welt: die Diskette mißt so 6,39 × 6,67 (Laufwerk ~8 breit, Reihe 9).
const BLENDER_SCALE := 7.1
const BLENDER_WIDTH := 0.9
const BLENDER_LENGTH := 0.94
const BLENDER_THICK := 0.033
## Welt-Maße: x = Länge (Einschub-Achse), y = Dicke, z = Breite.
const SIZE := Vector3(BLENDER_LENGTH * BLENDER_SCALE, BLENDER_THICK * BLENDER_SCALE,
	BLENDER_WIDTH * BLENDER_SCALE)
## So tief steckt sie: Schieber und die frühere Namenszeile, draußen bleibt die Wirkung.
const INSERT := 0.43
const INSERT_DEPTH := INSERT * BLENDER_SCALE

const MODEL_PATH := "res://assets/models/hardware/charm_disk.glb"
const FONT_PATH := "res://assets/fonts/AnonymousPro-Bold.ttf"
## Die Hüllen-Materialien des Exports ersetzt (Name -> Albedo, Metallic, Roughness, Rim): aus
## Blender kamen fast schwarzes Gußgrau und Chrom mit Metallic 1, die auf dem dunklen Tisch ohne
## Umgebung nichts zu spiegeln haben und schwarz lasen (Spieler-Befund 2026-11-18). Die Tischlichter
## erreichen die Reihe nicht: Licht gibt allein der Strahler des Charms (MODEL_LIGHT_LAYER), dazu
## ein schwaches Eigenlicht (SHELL_SELF_GLOW), damit leere Laufwerke und Laden-Disketten nicht verschwinden.
const SHELL_LOOK := {
	"Gussgrau": [Color(0.2, 0.2, 0.24), 0.35, 0.38, 0.45],
	"Front": [Color(0.06, 0.06, 0.075), 0.0, 0.22, 0.35],
	"Schwarzlack": [Color(0.075, 0.075, 0.09), 0.1, 0.28, 0.45],
	"Chrom": [Color(0.6, 0.62, 0.66), 0.55, 0.22, 0.0],
	"Schwarzchrom": [Color(0.32, 0.33, 0.37), 0.45, 0.3, 0.0],
	"Displayglas": [Color(0.02, 0.035, 0.045), 0.0, 0.3, 0.0],
	"Glasfront": [Color(0.02, 0.032, 0.04), 0.0, 0.35, 0.0],
	"Kabelmantel": [Color(0.05, 0.05, 0.065), 0.0, 0.55, 0.3],
	"Portstahl": [Color(0.3, 0.31, 0.35), 0.5, 0.3, 0.0],
	"Portgrund": [Color(0.012, 0.012, 0.016), 0.0, 0.4, 0.0],
	"Zungenblau": [Color(0.1, 0.36, 0.95), 0.0, 0.4, 0.0],
	"Leistengrund": [Color(0.05, 0.05, 0.065), 0.3, 0.35, 0.25],
}
const SHELL_SELF_GLOW := 0.55
## Weltmaß eines Label-Pixels.
const PIXEL := 0.01
## Oberkante der Glasfront über der Unterseite (Blender DT + 0,0029).
const FACE_Y := (BLENDER_THICK + 0.0029) * BLENDER_SCALE
const FACE_LIFT := 0.006

const SCREEN_COLOR := Color(0.55, 0.95, 1.0)
const SCREEN_ENERGY := 1.25
const DIM_SHARE := 0.42
const NAME_ENERGY := 1.15
const FRAME_REST := 1.0
const FRAME_FLASH := 2.6
const LED_OFF := Color(0.03, 0.03, 0.04)
const DISC_GLOW_SHARE := 0.65
const LIFT_HEIGHT := 0.9
const LIFT_TIME := 0.12

## Felder in Blender-Koordinaten (x = quer, y = längs) - dieselben wie terminal().
const TEXT_LEFT := -0.365
const TEXT_WIDTH := 0.73
const DESC_TOP := 0.035
const DESC_BOTTOM := -0.385
const DESC_BIGGEST := 0.13
const DESC_SMALLEST := 0.02
const FOOT_Y := -0.415
const GLASS := Rect2(-0.405, -0.455, 0.81, 0.605)
## Das Preisschild liegt rechts neben dem Schieber, auf dem Gehäuse (nicht auf dem Glas).
const TAG_CENTER := Vector2(0.31, 0.33)
const TAG_WIDTH := 0.22
const TAG_BIGGEST := 0.1
const TAG_COLOR := Color(1.4, 1.16, 0.14)
const TAG_MUTED := Color(0.5, 0.5, 0.58)
## Das HOLO-FENSTER im Schieber (Spieler-Wahl 2026-11-18): Mitte -0,03 / 0,314, 0,33 × 0,225 wie
## der Schnitt in tools/blender_floppy_export.py (WINDOW). Darunter die Scheibe, darüber das Glas.
const WINDOW := Rect2(-0.195, 0.2015, 0.33, 0.225)
## Die Scheibe dreht um die Nabe; ihr Rand streift nur die oberen Fensterecken.
const DISC_HUB := Vector2(0.0, 0.03)
const DISC_RADIUS := 0.405
## Höhen über der Glasfront (Blender): die Scheibe knapp über dem Gehäuse, das Glas unter dem Schieber.
const DISC_LIFT := -0.0025 * BLENDER_SCALE
const WINDOW_GLASS_LIFT := 0.0001 * BLENDER_SCALE
const DISC_SHADER := preload("res://assets/shaders/charm_disc.gdshader")
const DISC_GLASS_SHADER := preload("res://assets/shaders/charm_disc_glass.gdshader")

const RARITY_TIERS := {
	Charm.RARITY_COMMON: 1, Charm.RARITY_UNCOMMON: 2,
	Charm.RARITY_RARE: 3, Charm.RARITY_LEGENDARY: 4,
}
const RARITY_WORDS := {
	Charm.RARITY_COMMON: "GEWÖHNLICH", Charm.RARITY_UNCOMMON: "UNGEWÖHNLICH",
	Charm.RARITY_RARE: "SELTEN", Charm.RARITY_LEGENDARY: "LEGENDÄR",
}

var charm: Charm
var desc_label: Label3D
var leds: Array[MeshInstance3D] = []
var _frame_material: StandardMaterial3D
var _led_material: StandardMaterial3D
var _body: Node3D
var _tag: Label3D
var _lift := 0.0
var _lift_tween: Tween
var _flash_tween: Tween
var _carry_tween: Tween
var _carry_from := Transform3D()
var _carry_to := Transform3D()
var _carry_hump := 0.0

static var _font: Font
static var _model: PackedScene
static var _pictures := {}  # Charm-Id -> ViewportTexture (EINMAL gerendert)
static var _studio: Node
static var _shell_materials := {}  # Blender-Materialname -> StandardMaterial3D

func _init(for_charm: Charm = null) -> void:
	charm = for_charm

func _ready() -> void:
	if _body == null:
		_build()

## Die Wirkung so groß, wie das Feld erlaubt - kurze Texte werden größer, der Deckel
## (biggest) hält. Reine Rechnung in Label-Pixeln.
static func fit_size(text: String, width: float, height: float, biggest: int,
		smallest := 8, font: Font = null) -> int:
	var face := font if font != null else disk_font()
	var size := biggest
	while size > smallest:
		var block := face.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size)
		if block.y <= height and block.x <= width + 0.5:
			break
		size -= 1
	return maxi(size, smallest)

## Eine Zeile, so groß wie die Breite erlaubt.
static func fit_line(text: String, width: float, biggest: int, smallest := 8) -> int:
	var face := disk_font()
	var size := biggest
	while size > smallest and face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size

static func disk_font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font

static func rarity_tier(rarity: String) -> int:
	return int(RARITY_TIERS.get(rarity, 1))

static func rarity_color(rarity: String) -> Color:
	return Charm.RARITY_COLORS.get(rarity, Charm.RARITY_COLORS[Charm.RARITY_COMMON])

static func energized(color: Color, energy: float) -> Color:
	return Color(color.r * energy, color.g * energy, color.b * energy, color.a)

## Blender-Punkt auf der Glasfront → lokal (x = längs, z = quer).
static func face_point(bx: float, by: float, lift := FACE_LIFT) -> Vector3:
	return Vector3(by * BLENDER_SCALE, FACE_Y + lift, bx * BLENDER_SCALE)

## Mitte des Textfelds (lokal) - dort hängt der Schlüsselwort-Tip.
static func text_center_local() -> Vector3:
	return face_point(0.0, (DESC_TOP + DESC_BOTTOM) * 0.5)

## Die Vorderkante (lokal -X): dort, wo der Text endet.
static func front_x() -> float:
	return -SIZE.x * 0.5

## Wieviele LEDs leuchten.
func led_lit_count() -> int:
	return rarity_tier(charm.rarity) if charm != null else 0

func frame_color() -> Color:
	return _frame_material.albedo_color if _frame_material != null else Color.BLACK

func _build() -> void:
	_body = Node3D.new()
	_body.name = "Koerper"
	add_child(_body)
	_mount_shell()
	if charm == null:
		return
	var tint := rarity_color(charm.rarity)
	_frame_material = _unshaded(energized(tint, FRAME_REST))
	_led_material = _unshaded(energized(tint, NAME_ENERGY))
	# Der Raritäts-Streifen der Stahlschale trägt das Rahmen-Licht (und pulst mit ihm).
	for node in _body.find_children("Rar*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = _frame_material
	# Rahmen in der Raritätsfarbe - auch aus der Ferne die Stufe.
	var inset := 0.012
	var t := 0.006
	var g := GLASS
	_quad(Rect2(g.position.x + inset, g.end.y - inset - t, g.size.x - inset * 2.0, t), _frame_material)
	_quad(Rect2(g.position.x + inset, g.position.y + inset, g.size.x - inset * 2.0, t), _frame_material)
	_quad(Rect2(g.position.x + inset, g.position.y + inset, t, g.size.y - inset * 2.0), _frame_material)
	_quad(Rect2(g.end.x - inset - t, g.position.y + inset, t, g.size.y - inset * 2.0), _frame_material)
	# Drinnen: die Holo-Scheibe im Fenster des Schiebers, darüber das Glas.
	var picture := _quad(WINDOW, _disc_material(charm, tint), DISC_LIFT)
	picture.name = "Bild"
	var glass := ShaderMaterial.new()
	glass.shader = DISC_GLASS_SHADER
	_quad(WINDOW, glass, WINDOW_GLASS_LIFT).name = "Fensterglas"
	# Draußen: die Wirkung in Cyan, so groß wie das Feld erlaubt.
	var width := TEXT_WIDTH * BLENDER_SCALE / PIXEL
	var field_h := (DESC_TOP - DESC_BOTTOM) * BLENDER_SCALE / PIXEL
	var desc_size := fit_size(charm.description, width, field_h,
		int(DESC_BIGGEST * BLENDER_SCALE / PIXEL), int(DESC_SMALLEST * BLENDER_SCALE / PIXEL))
	desc_label = _label(charm.description, TEXT_LEFT, DESC_TOP, desc_size,
		energized(SCREEN_COLOR, SCREEN_ENERGY), VERTICAL_ALIGNMENT_TOP, width)
	_label(String(RARITY_WORDS.get(charm.rarity, "")), TEXT_LEFT, FOOT_Y,
		int(0.03 * BLENDER_SCALE / PIXEL), energized(SCREEN_COLOR, DIM_SHARE), VERTICAL_ALIGNMENT_CENTER)
	# Vier LEDs, so viele leuchten wie die Stufe.
	var off := _unshaded(LED_OFF)
	var led_mesh := SphereMesh.new()
	led_mesh.radius = 0.014 * BLENDER_SCALE
	led_mesh.height = 0.014 * BLENDER_SCALE * 0.8
	led_mesh.radial_segments = 12
	led_mesh.rings = 6
	for k in 4:
		var lamp := MeshInstance3D.new()
		lamp.name = "Led%d" % k
		lamp.mesh = led_mesh
		lamp.material_override = _led_material if k < led_lit_count() else off
		lamp.position = face_point(g.end.x - 0.045 - float(3 - k) * 0.042, FOOT_Y, 0.0)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(lamp)
		leds.append(lamp)

func _mount_shell() -> void:
	if _model == null and ResourceLoader.exists(MODEL_PATH):
		_model = load(MODEL_PATH) as PackedScene
	if _model != null:
		var shell := _model.instantiate() as Node3D
		shell.name = "Huelle"
		shell.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		shell.scale = Vector3.ONE * BLENDER_SCALE
		dress_shell(shell)
		# Eingemaltes Licht (Vertexfarben) wie beim Projektor; ohne Charm bleibt der Streifen dunkel.
		for node in shell.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.name == "Korpus" and mesh.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR:
				mesh.material_override = CharmReaderView._baked_material()
			elif String(mesh.name).begins_with("Rar"):
				mesh.material_override = _unshaded(LED_OFF)
		_body.add_child(shell)
		return
	# Ohne Import ein schlichter schwarzer Kasten.
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(SIZE.x, FACE_Y, SIZE.z)
	box.mesh = mesh
	box.position.y = FACE_Y * 0.5
	box.material_override = _unshaded(Color(0.012, 0.014, 0.02))
	_body.add_child(box)

func _quad(rect: Rect2, material: Material, lift := FACE_LIFT) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	# Das Quad liegt flach: lokal x quer zur Fläche (Z), y längs (X).
	mesh.size = Vector2(rect.size.x, rect.size.y) * BLENDER_SCALE
	quad.mesh = mesh
	quad.basis = _flat_basis()
	quad.position = face_point(rect.get_center().x, rect.get_center().y, lift)
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(quad)
	return quad

## Flach auf der Fläche: rechts = +Z, oben = +X, Normale = +Y.
static func _flat_basis() -> Basis:
	return Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))

func _label(text: String, bx: float, by: float, size: int, color: Color,
		valign: VerticalAlignment, width := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = disk_font()
	label.font_size = maxi(size, 1)
	label.pixel_size = PIXEL
	label.outline_size = 0
	label.modulate = color
	label.shaded = false
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.alpha_scissor_threshold = 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = valign
	if width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.width = width
	label.basis = _flat_basis()
	label.position = face_point(bx, by, FACE_LIFT * 1.5)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(label)
	return label

## Gibt jeder Fläche einer Hülle das Tisch-Material ihres Blender-Namens (geteilt je Name).
static func dress_shell(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		mesh_node.layers |= CharmRowView.MODEL_LIGHT_LAYER
		for i in mesh_node.mesh.get_surface_count():
			var source := mesh_node.mesh.surface_get_material(i)
			if source == null or not SHELL_LOOK.has(source.resource_name):
				continue
			mesh_node.set_surface_override_material(i, shell_material(source.resource_name))

static func shell_material(look: String) -> StandardMaterial3D:
	if _shell_materials.has(look):
		return _shell_materials[look]
	var spec: Array = SHELL_LOOK[look]
	var material := StandardMaterial3D.new()
	material.albedo_color = spec[0]
	material.metallic = spec[1]
	material.roughness = spec[2]
	material.emission_enabled = true
	material.emission = spec[0]
	material.emission_energy_multiplier = SHELL_SELF_GLOW
	if float(spec[3]) > 0.0:
		material.rim_enabled = true
		material.rim = spec[3]
		material.rim_tint = 0.6
	_shell_materials[look] = material
	return material

static func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

## Die Holo-Scheibe: das Charm-Bild (EINMAL je Id gerendert und geteilt) über einem Verlauf in der
## Rarität, rund beschnitten um die Nabe.
func _disc_material(for_charm: Charm, tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = DISC_SHADER
	material.set_shader_parameter("picture", charm_picture(for_charm))
	material.set_shader_parameter("rect", Vector4(WINDOW.position.x, WINDOW.position.y,
		WINDOW.end.x, WINDOW.end.y))
	material.set_shader_parameter("hub", DISC_HUB)
	material.set_shader_parameter("radius", DISC_RADIUS)
	material.set_shader_parameter("bg_inner", tint * DISC_GLOW_SHARE)
	return material

static func charm_picture(for_charm: Charm) -> Texture2D:
	if _pictures.has(for_charm.id):
		return _pictures[for_charm.id]
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if _studio == null or not is_instance_valid(_studio):
		_studio = Node.new()
		_studio.name = "CharmDiskStudio"
		tree.root.add_child.call_deferred(_studio)
	var thumb := CharmThumb.new(for_charm, 256)
	thumb.visible = false
	_studio.add_child(thumb)
	var texture := thumb.get_child(0).get_texture() as Texture2D
	_pictures[for_charm.id] = texture
	return texture

## Das PREISSCHILD im Laden: rechts neben dem Schieber auf dem Gehäuse ("" = keines).
func set_tag(text: String, muted := false) -> void:
	if _body == null:
		_build()
	if text == "":
		if _tag != null:
			_tag.visible = false
		return
	if _tag == null:
		_tag = _label("", TAG_CENTER.x, TAG_CENTER.y, 1, TAG_COLOR, VERTICAL_ALIGNMENT_CENTER)
		_tag.name = "Preis"
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.visible = true
	_tag.text = text
	_tag.font_size = fit_line(text, TAG_WIDTH * BLENDER_SCALE / PIXEL,
		int(TAG_BIGGEST * BLENDER_SCALE / PIXEL))
	_tag.modulate = TAG_MUTED if muted else TAG_COLOR

func tag_text() -> String:
	return _tag.text if _tag != null and _tag.visible else ""

# --- Gesten ------------------------------------------------------------------

## Der Griff hebt sie aus ihrer Ruhe (lokal, der Platz bleibt).
func set_lifted(on: bool) -> void:
	var goal := LIFT_HEIGHT if on else 0.0
	if is_equal_approx(_lift, goal) and _lift_tween == null:
		return
	if _lift_tween != null:
		_lift_tween.kill()
	_lift_tween = create_tween()
	_lift_tween.tween_method(_set_lift, _lift, goal, LIFT_TIME)
	_lift_tween.finished.connect(func() -> void: _lift_tween = null)

func lifted() -> bool:
	return _lift > 0.001

func _set_lift(value: float) -> void:
	_lift = value
	if _body != null:
		_body.position.y = value

## Rahmen, LEDs und Name pulsen ("dieser Charm feuert").
func flash() -> void:
	if charm == null or _frame_material == null:
		return
	var tint := rarity_color(charm.rarity)
	if _flash_tween != null:
		_flash_tween.kill()
	var paint := func(energy: float) -> void:
		_frame_material.albedo_color = energized(tint, energy)
		_led_material.albedo_color = energized(tint, energy)
	_flash_tween = create_tween()
	_flash_tween.tween_method(paint, FRAME_REST, FRAME_FLASH, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_method(paint, FRAME_FLASH, FRAME_REST, 0.42) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Trage-Bogen (Endzustand zuerst: das Ziel steht, der Weg ist nur Anzeige). XZ gerade,
## Y als Parabel über der Sehne; die Lage dreht mit.
func carry_to(target: Transform3D, time: float, peak: float) -> Tween:
	settle_carry()
	_carry_from = global_transform
	_carry_to = target
	var chord := (_carry_from.origin.y + target.origin.y) * 0.5
	_carry_hump = maxf(maxf(_carry_from.origin.y, target.origin.y) + maxf(peak, 0.0) - chord, 0.0)
	if time <= 0.0:
		_set_carry(1.0)
		return null
	_carry_tween = create_tween()
	_carry_tween.tween_method(_set_carry, 0.0, 1.0, time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_carry_tween.finished.connect(func() -> void: _carry_tween = null)
	return _carry_tween

func carrying() -> bool:
	return _carry_tween != null and _carry_tween.is_valid() and _carry_tween.is_running()

## Der harte Weg: eine laufende Fahrt steht sofort am Ziel.
func settle_carry() -> void:
	if _carry_tween != null:
		_carry_tween.kill()
		_carry_tween = null
		_set_carry(1.0)

func _set_carry(share: float) -> void:
	var at := _carry_from.interpolate_with(_carry_to, share)
	at.origin.y += 4.0 * _carry_hump * share * (1.0 - share)
	global_transform = at
