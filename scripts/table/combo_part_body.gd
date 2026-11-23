class_name ComboPartBody
extends Node3D
## Ein MODUL als Körper: ein Block, der ein FACH des Kombinations-Chips füllt, rechts sein
## Beinchen bis auf den Tisch (pin_<id>.glb aus tools/blender_pin_models.py) - der EINE Körper
## überall. Ohne Teil ist er das BLINDFACH (pin_empty.glb). Das Beinchen ist für alle gleich:
## die Schulter-LED nennt die Seltenheit, die Fuß-LED die Art. Den ZUSTAND setzt allein
## set_state. Ursprung = Mitte des Grundrisses auf dem Tisch; lokal +Z = Bild-rechts (das
## Beinchen zeigt vom Chip weg), +X = Bild-oben.

const PIN_MODEL := "res://assets/models/hardware/pin_%s.glb"
const PIN_EMPTY := "res://assets/models/hardware/pin_empty.glb"
## Hüllmaß (längs, quer, hoch) - tools/blender_pin_models.py spiegelt es.
const HULL := Vector3(2.3, 0.82, 1.68)
## Deckelhöhe des Blocks; darüber stehen nur die Merkmale.
const TOP := 1.32
## Länge des Blocks allein (ohne Beinchen) - so tief ist ein Fach des Chips.
const BLOCK := 1.845
## Deckelhöhe des Blindfachs: bündig mit dem Chip.
const BLANK_TOP := 1.28
## Die lange Kante - das Maß für Hub, Schweben und Teilung.
const SIDE := HULL.x

## Zustands-Teile des Modells (Knotennamen aus tools/blender_pin_models.py).
const DIGITS := 3
const ERROR_LAMPS := 5
const RING_SEGMENTS := 5
const TERMINALS := 3
const LAMP_COLOR := Color(1.0, 0.22, 0.16)
const FLAME_COLOR := Color(1.0, 0.55, 0.95)
const DIGIT_PIXEL := 0.0095
const DIGIT_FONT := 48

const WINDOW_ENERGY := 1.6
const DIM_ENERGY := 0.12
const DIM_ALBEDO := Color(0.16, 0.17, 0.2)
const OFF_COLOR := Color(0.24, 0.25, 0.3)
## Ein Zustands-Teil, das nicht brennt, glimmt in seiner Farbe - so liest die Form auch leer.
const UNLIT_ENERGY := 0.3
## Am Chip ruht ein Modul fast voll; feuernd blitzt es.
const REST_SHARE := 0.8
## Wertungs-Blitz: Leuchten und Größe springen an und klingen ab.
const FLASH_ENERGY := 4.0
const FLASH_POP := 0.1
const FLASH_TIME := 0.45
## Die Kopplung zeigt im Feld die Farbe des kopierten Moduls.
const COPY_ENERGY := 1.4

static var _scenes: Dictionary = {}

var part: ComboPart
var _dimmed := false
var _resting := false
var _lit: StandardMaterial3D
var _flash := 0.0
var _flash_tween: Tween
## Der gemeldete Zustand (set_state) und was daraus am Körper steht.
var _state: Dictionary = {}
var _model: Node3D
var _parts_lit: Array = []  # [Mesh, Material] je Zustands-Teil, in Modell-Reihenfolge
var _flame: MeshInstance3D
var _digits: Array[Label3D] = []
var _copy_material: StandardMaterial3D
var _copy_id := ""
var _rarity: StandardMaterial3D

static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

## Der Pin eines Moduls, leer der freie Platz.
static func pin_path(p_part: ComboPart) -> String:
	if p_part != null:
		var own := PIN_MODEL % p_part.id
		if ResourceLoader.exists(own):
			return own
	return PIN_EMPTY

## Ein gerundetes Rechteck als flacher Block (half = halbe Maße in X und Z), oben und an den Seiten.
static func slab_mesh(half: Vector2, radius: float, height: float) -> ArrayMesh:
	var ring := ChipFrameView.loop(half, radius, 0.0, height)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.0, height, 0.0)
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		tool.set_normal(Vector3.UP)
		for p in [top, a, b]:
			tool.add_vertex(p)
		var out := Vector3(b.z - a.z, 0.0, a.x - b.x).normalized()
		if out.dot((a + b) * 0.5 - top) < 0.0:
			out = -out
		tool.set_normal(out)
		var a0 := Vector3(a.x, 0.0, a.z)
		var b0 := Vector3(b.x, 0.0, b.z)
		for p in [a, b0, b, a, a0, b0]:
			tool.add_vertex(p)
	return tool.commit()

func setup(p_part: ComboPart) -> void:
	part = p_part
	for child in get_children():
		child.queue_free()
	_model = null
	_parts_lit.clear()
	_flame = null
	_digits.clear()
	_copy_material = null
	_copy_id = ""
	_rarity = null
	_lit = StandardMaterial3D.new()
	_lit.emission_enabled = true
	_lit.roughness = 0.3
	var inst := _scene(pin_path(part)).instantiate() as Node3D
	inst.name = "Model"
	# Das glb setzt an der Gehäusekante an - der Körper mißt von seiner Mitte.
	inst.position = Vector3(0.0, 0.0, -HULL.x * 0.5)
	add_child(inst)
	_model = inst
	_skin(inst, "Licht", _lit)
	if inst.find_child("Seltenheit", true, false) != null:
		_rarity = _glow_material()
		_skin(inst, "Seltenheit", _rarity)
	_apply_baked(inst)
	_build_state_parts(inst)
	var copy := inst.find_child("Abbild", true, false) as MeshInstance3D
	if copy != null:
		_copy_material = _glow_material()
		copy.material_override = _copy_material
	_apply()

## Höhe des Körpers über seinem Fuß.
func height() -> float:
	return HULL.z

## Die Zustands-Teile des Modells bekommen je ein eigenes Material; die Ziffern des Zählwerks
## stehen als Schrift in seinem Fenster.
func _build_state_parts(inst: Node3D) -> void:
	for prefix_count in [["Lampe", ERROR_LAMPS], ["Ring", RING_SEGMENTS], ["Klemme", TERMINALS]]:
		for i in int(prefix_count[1]):
			var mesh := inst.find_child("%s%d" % [prefix_count[0], i], true, false) as MeshInstance3D
			if mesh != null:
				var material := _glow_material()
				mesh.material_override = material
				_parts_lit.append([mesh, material])
	_flame = inst.find_child("Flamme", true, false) as MeshInstance3D
	if _flame != null:
		var fire := _glow_material()
		fire.albedo_color = FLAME_COLOR
		fire.emission = FLAME_COLOR
		fire.emission_energy_multiplier = FLASH_ENERGY * 0.5
		fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fire.albedo_color.a = 0.85
		_flame.material_override = fire
	for i in DIGITS:
		var at := inst.find_child("Ziffer%d" % i, true, false) as Node3D
		if at == null:
			continue
		var label := Label3D.new()
		label.name = "Ziffer"
		label.pixel_size = DIGIT_PIXEL
		label.font_size = DIGIT_FONT
		label.outline_size = 8
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
		label.shaded = false
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		# Flach im Fenster, Kopf nach Bild-oben (+X), Lesrichtung Bild-rechts (+Z).
		label.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
		at.add_child(label)
		_digits.append(label)

func _glow_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.roughness = 0.35
	return material

## Der EINE Schreiber des Zustands: state = {dice, chip_parts, first_hand, copy}
## (ComboChipView reicht Chip und Lauf). Der Stand am Teil selbst (counter) liest _apply.
func set_state(state: Dictionary) -> void:
	_state = state.duplicate()
	_apply()

func state() -> Dictionary:
	return _state

## Das kopierte Modul der Kopplung (leer = "").
func copy_id() -> String:
	return _copy_id

## Was die Zustands-Teile gerade zeigen: Zahl leuchtender Lampen/Ringe/Klemmen.
func lit_state_parts() -> int:
	var lit := 0
	for entry in _parts_lit:
		if (entry[1] as StandardMaterial3D).emission_energy_multiplier > UNLIT_ENERGY + 0.001:
			lit += 1
	return lit

func digits_text() -> String:
	var text := ""
	for label in _digits:
		text += label.text
	return text

## Die Schulter-LED: die Farbe der Seltenheit (schwarz = keine).
func rarity_light() -> Color:
	return _rarity.emission if _rarity != null else Color.BLACK

func flame_shown() -> bool:
	return _flame != null and _flame.visible

## Hitzestau oder Drossel: das Teil ist still - stumpf statt leuchtend.
func set_dimmed(on: bool) -> void:
	if _dimmed == on:
		return
	_dimmed = on
	_apply()

func dimmed() -> bool:
	return _dimmed

## Am Chip ruht es (REST_SHARE); in Hand, Grube und Bucht leuchtet es voll.
func set_resting(on: bool) -> void:
	if _resting == on:
		return
	_resting = on
	_apply()

func resting() -> bool:
	return _resting

## Das Licht, das gerade brennt - für Tests und den Rückblick.
func light_energy() -> float:
	return _lit.emission_energy_multiplier if _lit != null else 0.0

## Das Teil feuert in der Wertung; strength 1 = ein Schritt, mehr = Krit-Schlag.
func flash(strength := 1.0) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, strength, 0.0, FLASH_TIME * maxf(strength, 1.0))

func flash_level() -> float:
	return _flash

func _set_flash(value: float) -> void:
	_flash = value
	scale = Vector3.ONE * (1.0 + FLASH_POP * value)
	_apply()

func _apply() -> void:
	if _lit == null:
		return
	var tint := part.tint() if part != null else ComboPart.BOARD_TINT
	var rest := lerpf(REST_SHARE if _resting else 1.0, 1.0, clampf(_flash, 0.0, 1.0))
	# Der Anlasser leuchtet nur vor der ersten Hand der Runde.
	var spent := part != null and part.id == ComboPart.STARTER and not bool(_state.get("first_hand", true))
	_lit.albedo_color = DIM_ALBEDO if _dimmed or spent else tint.darkened(0.2)
	_lit.emission = tint
	_lit.emission_energy_multiplier = (DIM_ENERGY if _dimmed or spent else WINDOW_ENERGY * rest) \
		+ FLASH_ENERGY * _flash
	if _rarity != null and part != null:
		_glow(_rarity, part.rarity_color(), WINDOW_ENERGY)
	_write_state(tint, WINDOW_ENERGY * rest)

## Zustand am Körper - je Modul aus _state und dem eigenen Zähler gerechnet.
func _write_state(tint: Color, energy: float) -> void:
	if part == null:
		return
	var lit := 0
	var color := tint
	match part.id:
		ComboPart.ERROR_MEMORY:
			lit = clampi(part.counter, 0, ERROR_LAMPS)
			color = LAMP_COLOR
		ComboPart.RESONATOR:
			lit = clampi(part.counter, 0, RING_SEGMENTS)
		ComboPart.SERIES_TERMINAL:
			lit = clampi(int(_state.get("chip_parts", 0)), 0, TERMINALS)
	for i in _parts_lit.size():
		_glow(_parts_lit[i][1], color, energy + FLASH_ENERGY * _flash if i < lit else UNLIT_ENERGY)
	if _flame != null:
		_flame.visible = part.counter > 0 and not _dimmed
	if not _digits.is_empty():
		var value := ComboPartEffects.combo_values(part).y
		var text := str(clampi(value, 0, int(pow(10, _digits.size())) - 1)).pad_zeros(_digits.size())
		for i in _digits.size():
			_digits[i].text = text[i]
			_digits[i].modulate = (DIM_ALBEDO if _dimmed else tint.lightened(0.2))
	if _copy_material != null:
		var copy: ComboPart = _state.get("copy")
		_copy_id = copy.id if copy != null else ""
		_glow(_copy_material, copy.tint() if copy != null else color,
			COPY_ENERGY + FLASH_ENERGY * _flash if copy != null else -1.0)

## Ein Zustands-Licht: energy < 0 = aus (dunkler Stahl), sonst in color.
func _glow(material: StandardMaterial3D, color: Color, energy: float) -> void:
	if _dimmed or energy < 0.0:
		material.albedo_color = OFF_COLOR if not _dimmed else DIM_ALBEDO
		material.emission = OFF_COLOR
		material.emission_energy_multiplier = DIM_ENERGY
		return
	material.albedo_color = color.darkened(0.2)
	material.emission = color
	material.emission_energy_multiplier = energy

## Licht als Vertexfarben eingemalt: der Tisch ist zu dunkel, um Metall zu tragen.
func _apply_baked(inst: Node3D) -> void:
	var korpus := inst.find_child("Korpus", true, false) as MeshInstance3D
	if korpus == null or not (korpus.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR):
		return
	korpus.material_override = _baked(false)
	var glass := inst.find_child("Glas", true, false) as MeshInstance3D
	if glass != null:
		glass.material_override = _baked(true)

func _baked(transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _skin(inst: Node3D, node_name: String, material: Material) -> void:
	var mesh := inst.find_child(node_name, true, false) as MeshInstance3D
	if mesh != null:
		mesh.material_override = material
