class_name CharmReaderView
extends Node3D
## Ein PROJEKTOR der Charm-Reihe („Halo“, Spieler-Wahl 2026-11-22): Gehäuse mit Schlitz nach
## Bild-unten (lokal -X), oben die versenkte Emitter-Schale, vorn auf dem Deckel FRONT-DISPLAY
## und AUSWURF-TASTE, hinten das USB-Kabel zum Port der Leiste (PORT). Belegt leuchten Lippe,
## Bodensaum, Ringe, Kanten und die Kabel-Ader in der Rarität, und der LICHTHOF fällt auf den
## Filz; leer ist er dunkel, nur der Stecker glimmt. Ursprung = Mitte unten; Diskette und
## Hologramm stellt die Reihe.

const MODEL_PATH := "res://assets/models/hardware/charm_reader.glb"
const S := CharmDiskView.BLENDER_SCALE
## Blender-Maße (blender_floppy_charm.py: RW, RL, RH, SLOT_Z, LOADED_Y).
const BLENDER_SIZE := Vector3(0.8, 0.3, 1.12)  # x = Tiefe, y = Höhe, z = Breite
const SIZE := BLENDER_SIZE * S
const SLOT_Y := 0.17 * S
## Mitte der eingelegten Diskette, längs (Blender LOADED_Y = -RL/2 + INSERT - DL/2).
const LOADED_X := (-0.4 + CharmDiskView.INSERT - 0.47) * S
## Linsenmitte in der Schale (Blender pc + Linse).
const LENS := Vector3(0.08 * S, (0.3 + 0.006) * S, 0.0)
## Mitte des USB-Ports an der Wand hinter dem Gehäuse (Blender PORT_Y, PLUG_Z).
const PORT := Vector3(0.76 * S, 0.14 * S, 0.0)
## Namens-Display und Auswurf-Taste auf dem Deckel (blender_projector_baked.py DISPLAY, EJECT_X).
const DISPLAY_CENTER := Vector3((-0.4 + 0.105) * S, (0.3 + 0.004) * S, -0.085 * S)
const DISPLAY_SIZE := Vector2(0.8 * S, 0.115 * S)  # x quer, y längs
const EJECT_CENTER := Vector3((-0.4 + 0.105) * S, (0.3 + 0.024) * S, 0.41 * S)
const EJECT_SIZE := Vector3(0.085 * S, 0.024 * S, 0.13 * S)
const DISPLAY_PAD := 0.03 * S
const NAME_ENERGY := 1.15
## Treffer-Saum um die Taste in Bildschirm-Pixeln - sie ist klein im Bild.
const EJECT_PICK_PAD := 8.0

const GLOW_PARTS := ["Lippe", "Bodensaum", "Ring", "Linse", "Kabellicht"]
## Glimmen auch leer (STANDBY), belegt in der Rarität.
const STANDBY_PARTS := ["Steckerlicht", "Umriss"]
const HALO_SHADER := preload("res://assets/shaders/projector_halo.gdshader")
## Der Lichthof ragt so weit über den Grundriß hinaus.
const HALO_REACH := 1.5
const HALO_REST := 0.5
const HALO_FLASH := 0.9
const HALO_Y := 0.02
## Angeschlossen, aber leer: der Stecker glimmt.
const STANDBY := Color(0.1, 0.42, 0.5)
const APPEAR_TIME := 0.35
const DARK := Color(0.05, 0.06, 0.07)
const RING_REST := 0.62
const RING_FLASH := 2.2
const LENS_COLOR := Color(0.25, 0.9, 1.0)
const DISPLAY_TEXT := Color(1.4, 1.16, 0.14)
const SELL_TEXT := Color(1.5, 1.24, 0.15)
## Die Schrift füllt das Display fast in seiner Tiefe (0,115 Blender).
const DISPLAY_FONT := 0.092 * S / CharmDiskView.PIXEL
const NAME_SMALLEST := 12

var charm: Charm
var display_label: Label3D
var name_label: Label3D
var _glow: StandardMaterial3D
var _lens: StandardMaterial3D
var _eject: StandardMaterial3D
var _plug: StandardMaterial3D
var _halo: ShaderMaterial
var _shell: Node3D
var _lens_at := LENS
var _parts := {}  # Name -> MeshInstance3D
var _flash_tween: Tween
var _badge := ""
var _sale := ""

func _ready() -> void:
	if _glow == null:
		_build()

func _build() -> void:
	_glow = CharmDiskView._unshaded(DARK)
	_lens = CharmDiskView._unshaded(DARK)
	_eject = CharmDiskView._unshaded(Color(0.06, 0.06, 0.07))
	_plug = CharmDiskView._unshaded(STANDBY)
	var shell: Node3D
	if ResourceLoader.exists(MODEL_PATH):
		var scene := load(MODEL_PATH) as PackedScene
		if scene != null:
			shell = scene.instantiate() as Node3D
	if shell != null:
		_mount_shell(shell)
	else:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = SIZE
		box.mesh = mesh
		box.position.y = SIZE.y * 0.5
		box.material_override = CharmDiskView._unshaded(Color(0.04, 0.04, 0.05))
		add_child(box)
	_build_halo()
	display_label = Label3D.new()
	display_label.name = "DisplayText"
	display_label.font = CharmDiskView.disk_font()
	display_label.font_size = int(DISPLAY_FONT)
	display_label.pixel_size = CharmDiskView.PIXEL
	display_label.shaded = false
	display_label.double_sided = false
	display_label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	display_label.modulate = DISPLAY_TEXT
	display_label.basis = CharmDiskView._flat_basis()
	display_label.position = DISPLAY_CENTER + Vector3(0.0, 0.03, 0.0)
	display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label = display_label.duplicate() as Label3D
	name_label.name = "NameText"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.position.z = DISPLAY_CENTER.z - DISPLAY_SIZE.x * 0.5 + DISPLAY_PAD
	add_child(name_label)
	add_child(display_label)
	_refresh()

## Hängt ein Hüllen-Modell ein und gibt seinen benannten Teilen ihre Materialien.
func _mount_shell(shell: Node3D) -> void:
	_shell = shell
	_parts.clear()
	shell.name = "Gehaeuse"
	shell.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	shell.scale = Vector3.ONE * S
	CharmDiskView.dress_shell(shell)
	add_child(shell)
	for part in GLOW_PARTS:
		var mesh := shell.find_child(part, true, false) as MeshInstance3D
		if mesh != null:
			mesh.material_override = _lens if part == "Linse" else _glow
			_parts[part] = mesh
	for part in STANDBY_PARTS:
		var mesh := shell.find_child(part, true, false) as MeshInstance3D
		if mesh != null:
			mesh.material_override = _plug
	var button := shell.find_child("Auswurf", true, false) as MeshInstance3D
	if button != null:
		button.material_override = _eject
	# Eingemaltes Licht (Vertexfarben): am Tisch beleuchtet die Hülle nichts.
	var korpus := shell.find_child("Korpus", true, false) as MeshInstance3D
	if korpus != null and korpus.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR:
		korpus.material_override = _baked_material()
	_lens_at = LENS
	var lens := shell.find_child("LinseMitte", true, false) as Node3D
	if lens != null:
		var at := lens.transform
		var up := lens.get_parent() as Node3D
		while up != null and up != self:
			at = up.transform * at
			up = up.get_parent() as Node3D
		_lens_at = at.origin

## Tauscht die Hülle (Sichtproben neuer Fassungen).
func set_shell(shell: Node3D) -> void:
	if _glow == null:
		_build()
	if _shell != null:
		remove_child(_shell)
		_shell.queue_free()
	_mount_shell(shell)
	_refresh()

static var _baked: StandardMaterial3D

static func _baked_material() -> StandardMaterial3D:
	if _baked == null:
		_baked = StandardMaterial3D.new()
		_baked.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_baked.vertex_color_use_as_albedo = true
	return _baked

func _build_halo() -> void:
	var quad := MeshInstance3D.new()
	quad.name = "Lichthof"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(SIZE.x + HALO_REACH * 2.0, SIZE.z + HALO_REACH * 2.0)
	quad.mesh = mesh
	_halo = ShaderMaterial.new()
	_halo.shader = HALO_SHADER
	_halo.set_shader_parameter("body", Vector2(SIZE.x / mesh.size.x, SIZE.z / mesh.size.y))
	_halo.set_shader_parameter("tint", Color.BLACK)
	quad.material_override = _halo
	quad.position.y = HALO_Y
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)

## Ein neu gekaufter Projektor wächst an seinem Port auf.
func appear() -> void:
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, APPEAR_TIME) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func halo_color() -> Color:
	return _halo.get_shader_parameter("tint") if _halo != null else Color.BLACK

func port_global_position() -> Vector3:
	return to_global(PORT)

## Belegt (Rarität tönt die Leuchtteile) oder leer (dunkel).
func set_charm(value: Charm) -> void:
	charm = value
	if _glow == null:
		_build()
	_refresh()

## Der Zähler-Chip des Charms (leer = nichts).
func set_badge(text: String) -> void:
	_badge = text
	_write_display()

## Beim Hover: der Verkaufspreis ("" = zurück zum Zähler).
func set_sale(text: String) -> void:
	_sale = text
	_write_display()

func display_text() -> String:
	return display_label.text if display_label != null else ""

func _refresh() -> void:
	var lit := charm != null
	var tint := CharmDiskView.rarity_color(charm.rarity) if lit else DARK
	_glow.albedo_color = CharmDiskView.energized(tint, RING_REST) if lit else DARK
	_lens.albedo_color = CharmDiskView.energized(LENS_COLOR, 1.4) if lit else DARK
	_eject.albedo_color = Color(0.18, 0.18, 0.2) if lit else Color(0.06, 0.06, 0.07)
	_plug.albedo_color = CharmDiskView.energized(tint, RING_REST) if lit else STANDBY
	_halo.set_shader_parameter("tint", tint * HALO_REST if lit else Color.BLACK)
	_write_display()

func _write_display() -> void:
	if display_label == null:
		return
	var selling := _sale != "" and charm != null
	display_label.text = _sale if selling else (_badge if charm != null else "")
	display_label.modulate = SELL_TEXT if selling else DISPLAY_TEXT
	# Der Preis steht mittig allein, der Zähler rechtsbündig neben dem Namen.
	var right := DISPLAY_CENTER.z + DISPLAY_SIZE.x * 0.5 - DISPLAY_PAD
	display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if selling \
		else HORIZONTAL_ALIGNMENT_RIGHT
	display_label.position.z = DISPLAY_CENTER.z if selling else right
	var room := DISPLAY_SIZE.x - DISPLAY_PAD * 2.0
	if display_label.text != "" and not selling:
		room -= CharmDiskView.disk_font().get_string_size(display_label.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, display_label.font_size).x * CharmDiskView.PIXEL \
			+ DISPLAY_PAD
	var title := charm.display_name.to_upper() if charm != null and not selling else ""
	name_label.text = title
	name_label.font_size = CharmDiskView.fit_line(title, room / CharmDiskView.PIXEL,
		int(DISPLAY_FONT), NAME_SMALLEST)
	if charm != null:
		name_label.modulate = CharmDiskView.energized(CharmDiskView.rarity_color(charm.rarity),
			NAME_ENERGY)

func name_text() -> String:
	return name_label.text if name_label != null else ""

## Leuchtteile in der Ruhe-Energie oder im Puls.
func flash() -> void:
	if charm == null:
		return
	var tint := CharmDiskView.rarity_color(charm.rarity)
	if _flash_tween != null:
		_flash_tween.kill()
	var paint := func(energy: float) -> void:
		_glow.albedo_color = CharmDiskView.energized(tint, energy)
		_halo.set_shader_parameter("tint", tint * remap(energy, RING_REST, RING_FLASH,
			HALO_REST, HALO_FLASH))
	_flash_tween = create_tween()
	_flash_tween.tween_method(paint, RING_REST, RING_FLASH, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_method(paint, RING_FLASH, RING_REST, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func glow_color() -> Color:
	return _glow.albedo_color if _glow != null else DARK

## Weltpunkt der Linse - darüber schwebt das Hologramm.
func lens_global_position() -> Vector3:
	return to_global(_lens_at)

## Lage der eingelegten Diskette (Ursprung = Mitte ihrer Unterseite).
func disk_global_transform() -> Transform3D:
	return global_transform * Transform3D(Basis(),
		Vector3(LOADED_X, SLOT_Y - CharmDiskView.SIZE.y * 0.5, 0.0))

## Mitte des Displays in Weltkoordinaten (Anker der Charm-Kometen).
func display_global_position() -> Vector3:
	return to_global(DISPLAY_CENTER)

## Die acht Ecken eines lokalen Kastens in Welt.
func _corners(center: Vector3, size: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				out.append(to_global(center + Vector3(size.x * sx, size.y * sy, size.z * sz)))
	return out

## Das Bildschirm-Rechteck eines Kastens unter dieser Kamera.
func _screen_rect(camera: Camera3D, corners: Array[Vector3]) -> Rect2:
	var rect := Rect2()
	var first := true
	for corner in corners:
		if camera.is_position_behind(corner):
			return Rect2()
		var at := camera.unproject_position(corner)
		rect = Rect2(at, Vector2.ZERO) if first else rect.expand(at)
		first = false
	return rect

## Treffer-Rechteck des Laufwerks samt eingelegter Diskette (Bildschirm-Pixel).
func screen_rect(camera: Camera3D) -> Rect2:
	var back := SIZE.x * 0.5
	var front := LOADED_X - CharmDiskView.SIZE.x * 0.5
	var center := Vector3((back + front) * 0.5, SIZE.y * 0.5, 0.0)
	return _screen_rect(camera, _corners(center, Vector3(back - front, SIZE.y, SIZE.z)))

## Treffer-Rechteck der Auswurf-Taste (Bildschirm-Pixel, samt Saum).
func eject_screen_rect(camera: Camera3D) -> Rect2:
	var rect := _screen_rect(camera, _corners(EJECT_CENTER, EJECT_SIZE))
	return rect.grow(EJECT_PICK_PAD) if rect.size != Vector2.ZERO else rect

## Der Grundriß (Welt-XZ) samt der vorstehenden Diskette - für die Display-Pixel.
func footprint_world() -> Array[Vector3]:
	var back := SIZE.x * 0.5
	var front := LOADED_X - CharmDiskView.SIZE.x * 0.5
	return [to_global(Vector3(back, 0.0, -SIZE.z * 0.5)), to_global(Vector3(front, 0.0, SIZE.z * 0.5))]
