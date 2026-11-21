class_name ComboPartBody
extends Node3D
## Ein MODUL als Körper: eine dunkle, abgerundete PLATTE (PLATE, die EINE Größe überall -
## Steckplatz, Bucht, Wurfgruben-Reihe, Geist), darauf sein Bauteil (part_<id>.glb aus
## tools/blender_part_models.py, ohne eigenes das Grundgehäuse part_module.glb). Den ZUSTAND
## am Körper und die PUNKTREIHE der Würfel-Module setzt allein set_state. Ursprung =
## Unterseite der Platte; lokal +X = Bild-oben, +Z = Bild-rechts.
## Als PIN (setup(part, true)) ist er der rechte Anschluß eines Sockels: pin_<id>.glb aus
## tools/blender_pin_models.py ohne Platte, leer pin_empty.glb; Ursprung = Gehäusekante auf
## der Pin-Achse, der Pin zeigt nach lokal +Z. Zustand über denselben Schreiber.

const MODULE_SCENE := "res://assets/models/hardware/part_module.glb"
const OWN_MODEL := "res://assets/models/hardware/part_%s.glb"
const PIN_MODEL := "res://assets/models/hardware/pin_%s.glb"
const PIN_EMPTY := "res://assets/models/hardware/pin_empty.glb"
## Hüllmaß eines Pins (längs, quer, hoch) - tools/blender_pin_models.py spiegelt es.
const PIN_HULL := Vector3(0.9, 0.56, 0.5)
## Die Platte trägt einen Hauch Seltenheit - sie soll den Aufbau tragen, nicht überstrahlen.
const PLATE_RARITY_SHARE := 0.2

## Die PLATTE: X quer zum Chip (1,9), Z längs (1,5), Ecken gerundet.
const PLATE := Vector3(1.9, 0.07, 1.5)
const PLATE_RADIUS := 0.3
## Die kurze Plattenkante - das Maß für Hub, Schweben und Teilung.
const SIDE := 1.5
const PLATE_COLOR := Color(0.2, 0.21, 0.25)
const PLATE_EMISSION := 0.25
## Die Lichtleiste vorn auf der Platte (Bild-unten) in der Tönung der Modulart.
const PLATE_LIGHT := Vector3(0.05, 0.012, 0.9)
const PLATE_LIGHT_INSET := 0.13
## Hüllmaß eines Bauteils auf der Platte (quer, längs) - tools/blender_part_models.py spiegelt es.
const HULL := Vector2(1.3, 1.4)
## Das Bauteil rückt zur Bild-oberen Kante, unten bleiben Punktreihe und Lichtleiste frei.
const MODEL_SHIFT := 0.12
## Macht zeigt sich in der Höhe über der Platte (doppelt so hoch wie die alte 0,8er-Leiter).
const RISE := {
	ComboPart.RARITY_COMMON: 0.2,
	ComboPart.RARITY_RARE: 0.3,
	ComboPart.RARITY_EPIC: 0.4,
	ComboPart.RARITY_LEGENDARY: 0.5,
}

## Die PUNKTREIHE: je Würfel der Kombination ein Punkt, zwischen Bauteil und Lichtleiste.
const DOT_PARTS := [ComboPart.RELAY, ComboPart.OUTPUT_STAGE, ComboPart.SERIES_RESISTOR,
	ComboPart.SOLDER_JOINT, ComboPart.PARALLEL_CIRCUIT, ComboPart.SHUNT]
const DOT_ROW_X := -0.66
const DOT_PITCH := 0.21
const DOT_RADIUS := 0.055
const DOT_HEIGHT := 0.014
## Mehr Würfel hat keine Hand - der Nebenschluss zeigt die übrigen als Ringe daneben.
const DOT_MAX := 6
const DOT_DIM := Color(0.24, 0.25, 0.3)

## Zustands-Teile des Modells (Knotennamen aus tools/blender_part_models.py).
const DIGITS := 3
const ERROR_LAMPS := 5
const RING_SEGMENTS := 10
const TERMINALS := 5
const LAMP_COLOR := Color(1.0, 0.22, 0.16)
const FLAME_COLOR := Color(1.0, 0.55, 0.95)
const DIGIT_PIXEL := 0.0068
const DIGIT_FONT := 48
## Am Pin stehen die Ziffern kleiner - sein Fenster ist schmaler als die Rollen.
const PIN_DIGIT_SHARE := 0.55
## Die Kopplung zeigt das kopierte Modul als blasses Abbild über ihrem Feld.
const COPY_SCALE := 0.42
const COPY_ALPHA := 0.32

## Der SOCKEL ist genau so groß wie die Platte plus ein dünner Stahlrand.
const SOCKET_RIM := 0.06
const SOCKET_RIM_H := 0.05
const SOCKET_OUTER := Vector2(PLATE.x + 2.0 * SOCKET_RIM, PLATE.z + 2.0 * SOCKET_RIM)
## So hoch über dem Sockelgrund liegt die Platte: über Kontaktfeld und Leitung.
const SOCKET_SEAT := 0.026


const WINDOW_ENERGY := 1.6
const DIM_ENERGY := 0.12
const DIM_ALBEDO := Color(0.16, 0.17, 0.2)
const HOUSING_ALBEDO := Color(0.1, 0.1, 0.13)
const HOUSING_EMISSION := 0.08
const GOLD_ALBEDO := Color(1.0, 0.78, 0.36)
const GOLD_EMISSION := 0.35
## Auf dem Chip ruht ein Modul gedimmt und leuchtet erst voll, wenn es feuert.
const REST_SHARE := 0.4
const REST_KORPUS := 0.72
## Wertungs-Blitz: Leuchten und Größe springen an und klingen ab.
const FLASH_ENERGY := 4.0
const FLASH_POP := 0.35
const FLASH_TIME := 0.45

static var _scenes: Dictionary = {}
static var _meshes: Dictionary = {}
static var _shared: Dictionary = {}

var part: ComboPart
var _dimmed := false
var _resting := false
var _lit: StandardMaterial3D
var _korpus: StandardMaterial3D
var _flash := 0.0
var _flash_tween: Tween
## Der gemeldete Zustand (set_state) und was daraus am Körper steht.
var _state: Dictionary = {}
var _model: Node3D
var _parts_lit: Array = []  # [Mesh, Material] je Zustands-Teil, in Modell-Reihenfolge
var _flame: MeshInstance3D
var _digits: Array[Label3D] = []
var _dots: Node3D
var _dot_materials: Array[StandardMaterial3D] = []
var _dot_count := -1
var _dot_flash: Array[float] = []
var _copy_id := ""
var _pin := false

static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

## Das eigene Modell des Teils (tools/blender_part_models.py), sonst das Grundgehäuse.
static func model_path(p_part: ComboPart) -> String:
	if p_part != null:
		var own := OWN_MODEL % p_part.id
		if ResourceLoader.exists(own):
			return own
	return MODULE_SCENE

## Der Pin eines Sockels: das Modul als Anschluß, leer ein schlichter Stahlpin.
static func pin_path(p_part: ComboPart) -> String:
	if p_part != null:
		var own := PIN_MODEL % p_part.id
		if ResourceLoader.exists(own):
			return own
	return PIN_EMPTY

## Ein gerundetes Rechteck als flacher Block (half = halbe Maße in X und Z), oben und an den Seiten.
static func slab_mesh(half: Vector2, radius: float, height: float) -> ArrayMesh:
	var key := "%s|%.4f|%.4f" % [half, radius, height]
	if _meshes.has(key):
		return _meshes[key]
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
	var mesh := tool.commit()
	_meshes[key] = mesh
	return mesh

## Geteilte Materialien (Platte, Stahl, Gold, Sockelgrund) - je Name einmal.
static func shared_material(name: String) -> StandardMaterial3D:
	if _shared.has(name):
		return _shared[name]
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	match name:
		"plate":
			material.albedo_color = PLATE_COLOR
			material.roughness = 0.45
			material.metallic = 0.4
			material.emission = PLATE_COLOR
			material.emission_energy_multiplier = PLATE_EMISSION
		"gold":
			material.albedo_color = GOLD_ALBEDO
			material.metallic = 0.7
			material.roughness = 0.35
			material.emission = GOLD_ALBEDO
			material.emission_energy_multiplier = GOLD_EMISSION
		"floor":
			material.albedo_color = Color(0.012, 0.012, 0.022)
			material.roughness = 0.8
			material.emission = Color(0.012, 0.012, 0.022)
			material.emission_energy_multiplier = 0.0
		"steel":
			material.albedo_color = Color(0.5, 0.53, 0.6)
			material.metallic = 0.5
			material.roughness = 0.4
			material.emission = Color(0.5, 0.53, 0.6)
			material.emission_energy_multiplier = 0.25
	_shared[name] = material
	return material

## Die Platte trägt einen Hauch ihrer Seltenheit - je Seltenheit EIN geteiltes Material.
static func plate_material(rarity: String) -> StandardMaterial3D:
	var key := "plate:" + rarity
	if _shared.has(key):
		return _shared[key]
	var material := (shared_material("plate") as StandardMaterial3D).duplicate() as StandardMaterial3D
	var tone := PLATE_COLOR.lerp(ComboPart.RARITY_COLORS.get(rarity, Color.WHITE), PLATE_RARITY_SHARE)
	material.albedo_color = tone
	material.emission = tone
	_shared[key] = material
	return material

func setup(p_part: ComboPart, as_pin := false) -> void:
	part = p_part
	_pin = as_pin
	for child in get_children():
		child.queue_free()
	_korpus = null
	_model = null
	_parts_lit.clear()
	_flame = null
	_digits.clear()
	_dots = null
	_dot_materials.clear()
	_dot_flash.clear()
	_dot_count = -1
	_copy_id = ""
	_lit = StandardMaterial3D.new()
	_lit.emission_enabled = true
	_lit.roughness = 0.3
	if _pin:
		_build_model(pin_path(part), Vector3.ZERO)
		_apply()
		return
	var plate := MeshInstance3D.new()
	plate.name = "Platte"
	plate.mesh = slab_mesh(Vector2(PLATE.x, PLATE.z) * 0.5, PLATE_RADIUS, PLATE.y)
	plate.material_override = plate_material(part.rarity if part != null else ComboPart.RARITY_COMMON)
	add_child(plate)
	var strip := MeshInstance3D.new()
	strip.name = "PlattenLicht"
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = PLATE_LIGHT
	strip.mesh = strip_mesh
	strip.material_override = _lit
	strip.position = Vector3(-PLATE.x * 0.5 + PLATE_LIGHT_INSET, PLATE.y + PLATE_LIGHT.y * 0.5, 0.0)
	add_child(strip)
	_build_model(model_path(part), Vector3(MODEL_SHIFT, PLATE.y, 0.0))
	_sync_dots()
	_sync_copy()
	_apply()

func _build_model(path: String, at: Vector3) -> void:
	var inst := _scene(path).instantiate() as Node3D
	inst.name = "Model"
	inst.position = at
	add_child(inst)
	_model = inst
	var plug := inst.find_child("Stecker", true, false) as Node3D
	if plug != null:
		plug.visible = false  # das Grundgehäuse: die Platte trägt, kein Stecker darunter
	_skin(inst, "Gehaeuse", _flat(HOUSING_ALBEDO, HOUSING_EMISSION))
	_skin(inst, "Fenster", _lit)
	_skin(inst, "Licht", _lit)
	_apply_baked(inst)
	_build_state_parts(inst)

func is_pin() -> bool:
	return _pin

## Höhe des Körpers über seinem Fuß.
func height() -> float:
	return PLATE.y + float(RISE.get(part.rarity if part != null else "", RISE[ComboPart.RARITY_COMMON]))

## Die Zustands-Teile des Modells bekommen je ein eigenes Material; die Ziffern des Zählwerks
## stehen als Schrift auf seinen Rollen.
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
		label.pixel_size = DIGIT_PIXEL * (PIN_DIGIT_SHARE if _pin else 1.0)
		label.font_size = DIGIT_FONT
		label.outline_size = 8
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
		label.shaded = false
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		# Flach auf der Rolle, Kopf nach Bild-oben (+X), Lesrichtung Bild-rechts (+Z).
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
	_sync_dots()
	_sync_copy()
	_apply()

func state() -> Dictionary:
	return _state

## Würfel der Kombination (Punktreihe); 0 ohne Meldung.
func _dice() -> int:
	return clampi(int(_state.get("dice", 0)), 0, DOT_MAX)

## Welche Punkte das Modul meint: Relais den ersten, Endstufe den letzten, die übrigen alle;
## der Nebenschluss die Würfel AUSSERHALB der Kombination (seine Ringe).
func dot_lit(index: int) -> bool:
	var count := _dice()
	match part.id:
		ComboPart.RELAY:
			return index == 0
		ComboPart.OUTPUT_STAGE:
			return index == count - 1
		ComboPart.SHUNT:
			return index >= count
	return index < count

## So viele Punkte stehen: die Würfel der Kombination, beim Nebenschluss bis DOT_MAX.
func dot_count() -> int:
	if _pin or part == null or not DOT_PARTS.has(part.id):
		return 0
	return DOT_MAX if part.id == ComboPart.SHUNT and _dice() > 0 else _dice()

func _sync_dots() -> void:
	var count := dot_count()
	if count == _dot_count:
		return
	_dot_count = count
	if _dots != null:
		_dots.queue_free()
		_dots = null
	_dot_materials.clear()
	_dot_flash.clear()
	if count == 0:
		return
	_dots = Node3D.new()
	_dots.name = "Punkte"
	add_child(_dots)
	var solid := CylinderMesh.new()
	solid.top_radius = DOT_RADIUS
	solid.bottom_radius = DOT_RADIUS
	solid.height = DOT_HEIGHT
	solid.radial_segments = 20
	var hollow := TorusMesh.new()
	hollow.inner_radius = DOT_RADIUS * 0.55
	hollow.outer_radius = DOT_RADIUS
	hollow.rings = 20
	hollow.ring_segments = 6
	for i in count:
		var dot := MeshInstance3D.new()
		dot.name = "Punkt%d" % i
		dot.mesh = hollow if i >= _dice() else solid
		dot.position = Vector3(DOT_ROW_X, PLATE.y + DOT_HEIGHT * 0.5,
			(float(i) - float(count - 1) * 0.5) * DOT_PITCH)
		var material := _glow_material()
		dot.material_override = material
		_dots.add_child(dot)
		_dot_materials.append(material)
		_dot_flash.append(0.0)

## In der Wertung blitzt der Punkt des Würfels, der gerade auslöst (index = Platz in der Reihe).
func flash_die(index: int, strength := 1.0) -> void:
	if index < 0 or index >= _dot_flash.size():
		return
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		if index < _dot_flash.size():
			_dot_flash[index] = v
			_apply(),
		strength, 0.0, FLASH_TIME * maxf(strength, 1.0))

func dot_energy(index: int) -> float:
	if index < 0 or index >= _dot_materials.size():
		return 0.0
	return _dot_materials[index].emission_energy_multiplier

## Die Kopplung: das kopierte Modul als blasses Abbild über ihrem Feld (keins = leer).
func _sync_copy() -> void:
	var copy: ComboPart = _state.get("copy")
	var id := copy.id if copy != null else ""
	if id == _copy_id or _model == null:
		return
	_copy_id = id
	var at := _model.find_child("Abbild", true, false) as Node3D
	if at == null:
		return
	for child in at.get_children():
		child.queue_free()
	if copy == null:
		return
	var ghost := _scene(model_path(copy)).instantiate() as Node3D
	ghost.name = "Kopie"
	ghost.scale = Vector3.ONE * COPY_SCALE
	at.add_child(ghost)
	var veil := StandardMaterial3D.new()
	veil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil.cull_mode = BaseMaterial3D.CULL_DISABLED
	veil.no_depth_test = false
	var tone := copy.tint()
	veil.albedo_color = Color(tone.r, tone.g, tone.b, COPY_ALPHA)
	for mesh in ghost.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = veil
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Das kopierte Modul (leer = "").
func copy_id() -> String:
	return _copy_id

## Was die Zustands-Teile gerade zeigen: Zahl leuchtender Lampen/Ringe/Klemmen.
func lit_state_parts() -> int:
	var lit := 0
	for entry in _parts_lit:
		if (entry[1] as StandardMaterial3D).emission_energy_multiplier > DIM_ENERGY + 0.001:
			lit += 1
	return lit

func digits_text() -> String:
	var text := ""
	for label in _digits:
		text += label.text
	return text

func flame_shown() -> bool:
	return _flame != null and _flame.visible

## Hitzestau: das Teil ist für die Runde still - stumpf statt leuchtend.
func set_dimmed(on: bool) -> void:
	if _dimmed == on:
		return
	_dimmed = on
	_apply()

func dimmed() -> bool:
	return _dimmed

## Auf dem Chip ruht es gedimmt (REST_SHARE); in Hand, Grube und Bucht leuchtet es voll.
func set_resting(on: bool) -> void:
	if _resting == on:
		return
	_resting = on
	_apply()

func resting() -> bool:
	return _resting

## Das Licht, das gerade brennt (ohne Blitz) - für Tests und den Rückblick.
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
	var base := WINDOW_ENERGY
	var rest := REST_SHARE if _resting else 1.0
	# Feuert es, brennt es voll - der Ruhe-Anteil weicht mit dem Blitz.
	rest = lerpf(rest, 1.0, clampf(_flash, 0.0, 1.0))
	# Der Anlasser leuchtet nur vor der ersten Hand der Runde.
	var spent := part != null and part.id == ComboPart.STARTER and not bool(_state.get("first_hand", true))
	_lit.albedo_color = DIM_ALBEDO if _dimmed or spent else tint.darkened(0.2)
	_lit.emission = tint
	_lit.emission_energy_multiplier = (DIM_ENERGY if _dimmed or spent else base * rest) + FLASH_ENERGY * _flash
	if _korpus != null:
		var shade := lerpf(REST_KORPUS, 1.0, clampf(_flash, 0.0, 1.0)) if _resting else 1.0
		_korpus.albedo_color = Color(shade, shade, shade)
	_write_state(tint, base * rest)

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
		_glow(_parts_lit[i][1], color, energy + FLASH_ENERGY * _flash if i < lit else -1.0)
	if _flame != null:
		_flame.visible = part.counter > 0 and not _dimmed
	if not _digits.is_empty():
		var value := ComboPartEffects.combo_values(part).y
		var text := str(clampi(value, 0, int(pow(10, _digits.size())) - 1)).pad_zeros(_digits.size())
		for i in _digits.size():
			_digits[i].text = text[i]
			_digits[i].modulate = (DIM_ALBEDO if _dimmed else tint.lightened(0.2))
	for i in _dot_materials.size():
		var flash := _dot_flash[i] if i < _dot_flash.size() else 0.0
		_glow(_dot_materials[i], tint, energy + FLASH_ENERGY * flash if dot_lit(i) or flash > 0.0 else -1.0)

## Ein Zustands-Licht: energy < 0 = aus (dunkler Stahl), sonst in color.
func _glow(material: StandardMaterial3D, color: Color, energy: float) -> void:
	if _dimmed or energy < 0.0:
		material.albedo_color = DOT_DIM if not _dimmed else DIM_ALBEDO
		material.emission = DOT_DIM
		material.emission_energy_multiplier = DIM_ENERGY
		return
	material.albedo_color = color.darkened(0.2)
	material.emission = color
	material.emission_energy_multiplier = energy

## Modelle mit eingemaltem Licht (Vertexfarben): der Tisch ist zu dunkel, um Metall zu tragen.
func _apply_baked(inst: Node3D) -> void:
	var korpus := inst.find_child("Korpus", true, false) as MeshInstance3D
	if korpus == null or not (korpus.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR):
		return
	_korpus = _baked(false)
	korpus.material_override = _korpus
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

func _flat(albedo: Color, emission: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = 0.45
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = albedo
		material.emission_energy_multiplier = emission
	return material
