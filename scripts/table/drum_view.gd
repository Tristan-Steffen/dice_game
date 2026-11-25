class_name DrumView
extends Node3D
## Die WALZE der Werkstatt (Layout A, docs/plan_werkstatt_walze.md): sechs SCHEIBEN entlang
## Welt-Z (Bild-links → Bild-rechts), Scheibe 1 links. Jede ist ein Vierkant um diese
## Achse, gemessen an der KURZEN Kartenseite, je Seite die Mulde des Magazin-Trays EINER
## Sorte (Pack.SHELF_ORDER) samt ihrem Leser; die Karte liegt mit ihrer Langseite längs der Achse. Belegt liegt
## der Leser ihrer Sorte oben, bündig Y = 0; leer steht sie auf Kante. Die Scheibe trägt
## keinen Klick. Jeder Leser hat drei Stellungen (POSE_*): flach, bereit, zugegriffen.

const SLICES := 6
## Eine Vierteldrehung dauert so lange.
const QUARTER_TIME := 0.25
## Leer steht die Scheibe auf Kante.
const EMPTY_ANGLE := PI * 0.25
## Die Scheibe ist so lang wie ihre Teilung mal diesem Anteil - länger als die Karte.
const SLICE_SHARE := 0.97
## Die drei Stellungen eines Lesers: flach (die Scheibe darf drehen), bereit (die Karte
## kommt), zugegriffen (die Karte liegt).
const POSE_REST := 0
const POSE_READY := 1
const POSE_LOADED := 2
const POSE_TIME := 0.22
const REST_TIME := 0.1
## Das Rollsiegel rollt beim Lesen so lange hin und ebenso lange zurück.
const SWEEP_TIME := 0.3
const LAMP_DIM := 0.3
const LAMP_ON := 1.7
const LAMP_FLASH := 3.0
const FEELERS := 10
const FEELER_BAR := 0.3
const FEELER_REACH := 1.1
const LID_BAR := 0.05
const LID_OPEN := 0.5
const ROLLER_R := 0.19
const BURNER_ARM := 0.36
## Luft der Mulde um die Karte (Welt).
const WELL_AIR := 0.012
## Das Licht eines Platzes (Dioden, Bandweg) und sein Saum: ohne Karte gedimmt, mit ihr hell.
const FLOOR_DARK := 0.2
const FLOOR_LIT := 1.25
const SEAM_DIM := 0.5
const SEAM_ON := 0.9
const BODY_ALBEDO := Color(0.16, 0.155, 0.21)
const BODY_EMISSION := Color(0.36, 0.38, 0.52)
const BODY_EMISSION_ENERGY := 0.3
## Eine GESPERRTE Scheibe (noch nicht freigeschaltet) liegt flach und dunkel unter ihrer
## HAUBE; die nächste käufliche nennt darauf ihren Preis.
const LOCKED_ALBEDO := Color(0.06, 0.06, 0.08)
const LOCKED_EMISSION_ENERGY := 0.03
const LOCKED_ANGLE := 0.0
const HOOD_SHADER := preload("res://assets/shaders/drum_hood.gdshader")
const HOOD_HEIGHT := 0.07
const HOOD_LIFT := 0.012
const HOOD_SHARE := 0.96
const HOOD_BAND := 0.22
const HOOD_SLIDE_TIME := 0.45
const HOOD_FLAT := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
const HOOD_TEXT := Color(0.62, 0.65, 0.72)
const HOOD_PRICE_OFF := Color(0.75, 0.42, 0.38)
const HOOD_PRICE_ON := Color(0.45, 1.5, 1.7)
const HOOD_WORD_SHARE := 0.11
const HOOD_PRICE_SHARE := 0.3
## Hinter der nächsten: ruhig, dunkel, "GESPERRT" klein und gedämpft.
const HOOD_CALM_WORD_SHARE := 0.075
const HOOD_CALM_TEXT := Color(0.3, 0.32, 0.37)
## STROMLOS (die Prägung der Runde ist verbraucht): Lampen und Körper auf diesen Anteil.
const POWER_OFF := 0.08
const POWER_TIME := 0.5

## Der STROM der Übertragung läuft über die Scheiben von 1 nach rechts: eine additive
## Ebene in Kartengröße, knapp über der liegenden Karte.
const LIGHT_COLOR := Color(0.55, 0.91, 0.99)
const LIGHT_ALPHA := 0.30
const LIGHT_ENERGY := 1.25
const LIGHT_RISE := DataCellView.DEPTH * PackDrawerView.CASSETTE_SCALE + 0.02
## Der Blitz einer Scheibe, wenn sie verriegelt.
const FLASH_ENERGY := 1.4
const FLASH_TIME := 0.3

var _pivots: Array[Node3D] = []
## Ziel-Winkel je Scheibe - der Endzustand, nicht der gerade gezeigte.
var _target: Array[float] = []
var _tweens: Array[Tween] = []
var _bodies: Array[StandardMaterial3D] = []
var _flashes: Array[Tween] = []
## Je Scheibe ihre vier Leser (nach Sorten-Rang), der Rang der belegten Seite (-1 = leer),
## die Stellung ihres Lesers und dessen Fahrt.
var _readers: Array = []
var _rank: Array[int] = []
var _pose: Array[int] = []
var _pose_tweens: Array[Tween] = []
## Je Scheibe: um wie viel der Spieler die LEERE Scheibe weitergedreht hat (ganze Viertel).
var _free: Array[float] = []
var _locked: Array[bool] = []
var _lock_known := false
var _hoods: Array[Node3D] = []
var _hood_tweens: Array[Tween] = []
var _hood_key := ""
var _powered := true
var _power := 1.0
var _power_tween: Tween
var _side := 1.0
var _pitch := 1.0
var _light: Node3D
var _light_plane: MeshInstance3D
var _light_material: StandardMaterial3D
var _light_ride: Tween

## Stellt die Walze auf: je Scheibe ihre Mitte AUF dem Glas (Welt, Y = 0), die Kante des
## Vierkants (Welt-X und -Y) und die Teilung längs der Achse (Welt-Z).
func setup(centers: Array[Vector3], side: float, pitch: float) -> void:
	if _same_geometry(centers, side, pitch):
		return  # dieselben Maße bauen nichts neu - das Licht samt Reiter bleibt
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_pivots.clear()
	_target.clear()
	_tweens.clear()
	_bodies.clear()
	_flashes.clear()
	_readers.clear()
	_rank.clear()
	_pose.clear()
	_pose_tweens.clear()
	_free.clear()
	_locked.clear()
	_lock_known = false
	_hoods.clear()
	_hood_tweens.clear()
	_hood_key = ""
	_light = null
	_light_ride = null
	_side = side
	_pitch = pitch
	for i in centers.size():
		var pivot := Node3D.new()
		pivot.name = "Scheibe%d" % (i + 1)
		add_child(pivot)
		pivot.global_position = centers[i] + Vector3.DOWN * side * 0.5
		_readers.append(_build_slice(pivot, side, pitch * SLICE_SHARE))
		_pivots.append(pivot)
		_rank.append(-1)
		_pose.append(POSE_REST)
		_pose_tweens.append(null)
		_target.append(EMPTY_ANGLE)
		_free.append(0.0)
		_locked.append(false)
		_hoods.append(_build_hood(i, centers[i], side, pitch * SLICE_SHARE))
		_hood_tweens.append(null)
		_tweens.append(null)
		_flashes.append(null)
		pivot.rotation.z = EMPTY_ANGLE
	_ensure_light()

func _same_geometry(centers: Array[Vector3], side: float, pitch: float) -> bool:
	if centers.size() != _pivots.size() or not is_equal_approx(side, _side) \
			or not is_equal_approx(pitch, _pitch):
		return false
	for i in centers.size():
		if not top_point(i).is_equal_approx(centers[i]):
			return false
	return true

## Der Winkel, unter dem die Seite der Sorte rank oben liegt.
static func face_angle(rank: int) -> float:
	return float(posmod(rank, 4)) * PI * 0.5

## Der Winkel für eine Scheibe: belegt die Seite ihrer Sorte, leer auf Kante.
static func angle_for(pack: Pack) -> float:
	return EMPTY_ANGLE if pack == null else face_angle(Pack.shelf_rank(pack))

## Der EINE Schreiber: packs[i] liegt auf Scheibe i (null = leer). Endzustand zuerst,
## die Drehung ist nur die Fahrt dorthin; ein gleicher Stand fährt nichts.
func seat(packs: Array) -> void:
	for i in _pivots.size():
		var pack: Pack = packs[i] if i < packs.size() else null
		var want := _rest_angle(i) if pack == null else angle_for(pack)
		if is_equal_approx(_target[i], want):
			continue
		_target[i] = want
		_set_rank(i, -1 if pack == null else Pack.shelf_rank(pack), false)
		_drop_spin(i)
		_turn(i, want)

## Wie seat, aber ohne Fahrt.
func seat_hard(packs: Array) -> void:
	for i in _pivots.size():
		var pack: Pack = packs[i] if i < packs.size() else null
		_target[i] = _rest_angle(i) if pack == null else angle_for(pack)
		_set_rank(i, -1 if pack == null else Pack.shelf_rank(pack), true)
		_free[i] = 0.0
		_kill(i)
		_pivots[i].rotation.z = _target[i]

# --- Das freie Drehen der leeren Scheibe -------------------------------------------------------

func side() -> float:
	return _side

## Nur eine LEERE Scheibe läßt sich von Hand drehen - reine Anzeige, die Kante bleibt ihre Ruhe.
func spinnable(index: int) -> bool:
	return index >= 0 and index < _pivots.size() and _rank[index] == -1 \
		and not _locked[index] and is_equal_approx(_target[index], EMPTY_ANGLE)

## Leer steht eine Scheibe auf Kante - gesperrt liegt sie flach unter ihrer Haube.
func _rest_angle(index: int) -> float:
	return LOCKED_ANGLE if _locked[index] else EMPTY_ANGLE

## Der EINE Schreiber der Sperre: die ersten open Scheiben sind frei, der Rest liegt unter
## Hauben; price ist der Energie-Preis der nächsten (<= 0 = keiner), payable färbt ihn.
## Idempotent, je Bild gefragt. Eine frei gewordene Haube fährt nach hinten unter den Tisch.
func set_lock_state(open: int, price := 0, payable := false) -> void:
	var hard := not _lock_known or not is_inside_tree()
	_lock_known = true
	for i in _pivots.size():
		var locked := i >= open
		if _locked[i] != locked:
			_locked[i] = locked
			_write_body(i)
			_ride_hood(i, locked, hard)
			if _rank[i] < 0:
				_free[i] = 0.0
				_target[i] = _rest_angle(i)
				if hard:
					_kill(i)
					_pivots[i].rotation.z = _target[i]
				else:
					_turn(i, _target[i])
	var key := "%d:%d:%s" % [open, price, payable]
	if key == _hood_key:
		return
	_hood_key = key
	for i in _hoods.size():
		var next := i == open and price > 0
		var word: Label3D = _hoods[i].get_node("Wort")
		var tag: Label3D = _hoods[i].get_node("Preis")
		word.text = "FREISCHALTEN" if next else "GESPERRT"
		word.position.x = -_side * 0.2 if next else 0.0
		word.pixel_size = _side * (HOOD_WORD_SHARE if next else HOOD_CALM_WORD_SHARE) / 64.0
		word.modulate = HOOD_TEXT if next else HOOD_CALM_TEXT
		tag.visible = next
		tag.text = "%d ⚡" % price
		tag.modulate = HOOD_PRICE_ON if payable else HOOD_PRICE_OFF
		var plate: MeshInstance3D = _hoods[i].get_node("Platte")
		(plate.material_override as ShaderMaterial).set_shader_parameter("hazard",
			1.0 if next else 0.0)

func hood_shown(index: int) -> bool:
	return index >= 0 and index < _hoods.size() and _hoods[index].visible

## Trägt die Haube die Warnschraffur (nur die nächste käufliche)?
func hood_warns(index: int) -> bool:
	if index < 0 or index >= _hoods.size():
		return false
	var plate: MeshInstance3D = _hoods[index].get_node("Platte")
	return float((plate.material_override as ShaderMaterial).get_shader_parameter("hazard")) > 0.5

func hood_word(index: int) -> Label3D:
	return _hoods[index].get_node("Wort") if index >= 0 and index < _hoods.size() else null

func hood_price_text(index: int) -> String:
	if index < 0 or index >= _hoods.size():
		return ""
	var tag: Label3D = _hoods[index].get_node("Preis")
	return tag.text if tag.visible else ""

func _build_hood(index: int, center: Vector3, side: float, length: float) -> Node3D:
	var hood := Node3D.new()
	hood.name = "Haube%d" % (index + 1)
	hood.visible = false
	add_child(hood)
	hood.global_position = center + Vector3.UP * HOOD_LIFT
	hood.set_meta(&"home", hood.position)
	var half := Vector2(side, length) * HOOD_SHARE * 0.5
	var plate := MeshInstance3D.new()
	plate.name = "Platte"
	var box := BoxMesh.new()
	box.size = Vector3(half.x * 2.0, HOOD_HEIGHT, half.y * 2.0)
	plate.mesh = box
	plate.position.y = HOOD_HEIGHT * 0.5
	var material := ShaderMaterial.new()
	material.shader = HOOD_SHADER
	material.set_shader_parameter("half_size", half)
	material.set_shader_parameter("band", side * HOOD_BAND * 0.5)
	material.set_shader_parameter("stripe", side * 0.09)
	plate.material_override = material
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hood.add_child(plate)
	_hood_label(hood, "Wort", side * HOOD_WORD_SHARE, HOOD_TEXT)
	var tag := _hood_label(hood, "Preis", side * HOOD_PRICE_SHARE, HOOD_PRICE_OFF)
	tag.position.x = side * 0.1
	return hood

func _hood_label(hood: Node3D, part: String, height: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = part
	label.font_size = 64
	label.pixel_size = height / 64.0
	label.outline_size = 0
	label.modulate = color
	label.shaded = false
	label.transform = Transform3D(HOOD_FLAT, Vector3.UP * (HOOD_HEIGHT + 0.01))
	hood.add_child(label)
	return label

## Endzustand zuerst: die Haube steht oder ist fort; frei geworden gleitet sie nach hinten
## (Welt +X) knapp unter die Anzeige.
func _ride_hood(index: int, locked: bool, hard: bool) -> void:
	var hood := _hoods[index]
	_kill_tween(_hood_tweens[index])
	_hood_tweens[index] = null
	var home: Vector3 = hood.get_meta(&"home")
	hood.position = home
	hood.visible = locked
	if locked or hard:
		return
	hood.visible = true
	var away := home + Vector3(_side * 1.05, -(HOOD_HEIGHT + HOOD_LIFT * 2.0), 0.0)
	var tween := hood.create_tween()
	_hood_tweens[index] = tween
	tween.tween_property(hood, "position:y", away.y, HOOD_SLIDE_TIME * 0.2)
	tween.tween_property(hood, "position:x", away.x, HOOD_SLIDE_TIME * 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		hood.visible = false
		hood.position = home)

func _write_body(index: int) -> void:
	var material := _bodies[index]
	material.albedo_color = LOCKED_ALBEDO if _locked[index] else BODY_ALBEDO
	material.emission_energy_multiplier = _body_energy(index)
	# Unter der Haube ragte sonst ein Leser durch die Platte.
	for child in _pivots[index].get_children():
		if String(child.name).begins_with("Leser_"):
			(child as Node3D).visible = not _locked[index]

func _body_energy(index: int) -> float:
	return LOCKED_EMISSION_ENERGY if _locked[index] else BODY_EMISSION_ENERGY * _power

# --- STROM: nach der Prägung der Runde steht die Walze dunkel ---------------------------------

func powered() -> bool:
	return _powered

## Der EINE Schreiber des Stroms. Aus: Lampen und Körper dunkel, bereitstehende Leser legen
## sich flach (zugegriffene halten ihre Karte). Idempotent, je Bild gefragt.
func set_powered(on: bool, hard := false) -> void:
	if _powered == on:
		return
	_powered = on
	_kill_tween(_power_tween)
	_power_tween = null
	for i in _pose.size():
		if _rank[i] < 0:
			continue
		if not on and _pose[i] == POSE_READY:
			_pose_to(i, POSE_REST, 0.0 if hard else REST_TIME)
		elif on and _pose[i] == POSE_REST:
			_pose_to(i, POSE_READY, 0.0 if hard else POSE_TIME)
	var want := 1.0 if on else POWER_OFF
	if hard or not is_inside_tree():
		_write_power(want)
		return
	_power_tween = create_tween()
	_power_tween.tween_method(_write_power, _power, want, POWER_TIME)

func _write_power(share: float) -> void:
	_power = share
	for i in _readers.size():
		_bodies[i].emission_energy_multiplier = _body_energy(i)
		var faces: Array = _readers[i]
		for rank in faces.size():
			var pose := _pose[i] if rank == _rank[i] else POSE_REST
			for lamp: Dictionary in faces[rank]["lamps"]:
				(lamp["material"] as StandardMaterial3D).albedo_color = _lamp_color(lamp, pose)

func _lamp_color(lamp: Dictionary, pose: int) -> Color:
	return _lit(lamp["tint"], float((lamp["energies"] as Array)[pose]) * _power)

func locked(index: int) -> bool:
	return index >= 0 and index < _locked.size() and _locked[index]

## Das Rad: um ganze Viertel weiter.
func spin_by(index: int, quarters: int) -> void:
	if not spinnable(index) or quarters == 0:
		return
	_free[index] += float(quarters) * PI * 0.5
	_turn(index, EMPTY_ANGLE + _free[index])

## Der Zug: die Scheibe folgt dem Zeiger um diesen Winkel.
func spin_drag(index: int, angle: float) -> void:
	if not spinnable(index):
		return
	_kill(index)
	_pivots[index].rotation.z += angle

## Losgelassen rastet sie auf der nächsten Kante ein.
func spin_release(index: int) -> void:
	if not spinnable(index):
		return
	_free[index] = snappedf(_pivots[index].rotation.z - EMPTY_ANGLE, PI * 0.5)
	_turn(index, EMPTY_ANGLE + _free[index])

## Vor einer Fahrt der Scheibe: der Hand-Versatz ist fort, und sie dreht den kurzen Weg.
func _drop_spin(index: int) -> void:
	_free[index] = 0.0
	var pivot := _pivots[index]
	pivot.rotation.z = _target[index] + wrapf(pivot.rotation.z - _target[index], -PI, PI)

func target_angle(index: int) -> float:
	return _target[index] if index >= 0 and index < _target.size() else EMPTY_ANGLE

func shown_angle(index: int) -> float:
	return _pivots[index].rotation.z if index >= 0 and index < _pivots.size() else EMPTY_ANGLE

func turning(index: int) -> bool:
	return index >= 0 and index < _tweens.size() and _tweens[index] != null \
		and _tweens[index].is_valid() and _tweens[index].is_running()

## Wo eine Karte auf Scheibe index liegt: ihre Mitte auf der Oberseite (Y = 0).
func top_point(index: int) -> Vector3:
	if index < 0 or index >= _pivots.size():
		return global_position
	return _pivots[index].global_position + Vector3.UP * _side * 0.5

## Wo die Karte auf Scheibe index liegt: in der Halterung ihrer Mulde.
func seat_point(index: int) -> Vector3:
	return top_point(index) - Vector3.UP * card_sink(_side)

# --- DIE ÜBERTRAGUNG ----------------------------------------------------------

## Wo der Strom über Scheibe index steht; hinter der letzten eine Teilung weiter
## (Bild-rechts = Welt +Z).
func light_stop(index: int) -> Vector3:
	if _pivots.is_empty():
		return global_position
	var last := _pivots.size() - 1
	var at := top_point(mini(index, last))
	if index > last:
		at += Vector3(0.0, 0.0, _pitch * float(index - last))
	return at + Vector3.UP * LIGHT_RISE

## Das Ende der Walze auf dem Glas: die Kammer-seitige Stirn hinter der letzten Scheibe.
func end_point() -> Vector3:
	if _pivots.is_empty():
		return global_position
	return top_point(_pivots.size() - 1) + Vector3(0.0, 0.0, _pitch * 0.5)

func light_on(accent: Color) -> void:
	_ensure_light()
	_light_material.albedo_color = Color(accent.r * LIGHT_ENERGY,
		accent.g * LIGHT_ENERGY, accent.b * LIGHT_ENERGY, LIGHT_ALPHA)
	_light.visible = true
	light_hard(light_stop(0) - Vector3(0.0, 0.0, _pitch))

## Die Ebene fährt auf einen Weltpunkt; bei time <= 0 steht sie sofort dort.
func light_to(point: Vector3, time: float) -> void:
	_ensure_light()
	if time <= 0.0:
		light_hard(point)
		return
	_kill_tween(_light_ride)
	_light_ride = create_tween()
	_light_ride.tween_property(_light, "global_position", point, time)
	_light_ride.tween_callback(func() -> void: light_hard(point))

func light_hard(point: Vector3) -> void:
	_ensure_light()
	_kill_tween(_light_ride)
	_light.global_position = point

## Der EINE Aufräum-Pfad des Lichts.
func light_off() -> void:
	_kill_tween(_light_ride)
	if _light != null and is_instance_valid(_light):
		_light.visible = false

## Ein Reiter auf der Strom-Ebene (das LICHT-NETZ) fährt mit ihr.
func attach_to_light(rider: Node3D) -> void:
	_ensure_light()
	if rider.get_parent() == _light:
		return
	if rider.get_parent() != null:
		rider.get_parent().remove_child(rider)
	_light.add_child(rider)

## Die Scheibe index blitzt auf (sie verriegelt).
func flash(index: int) -> void:
	if index < 0 or index >= _bodies.size():
		return
	var material := _bodies[index]
	_kill_tween(_flashes[index])
	material.emission_energy_multiplier = FLASH_ENERGY
	var tween := create_tween()
	_flashes[index] = tween
	tween.tween_property(material, "emission_energy_multiplier", _body_energy(index),
		FLASH_TIME)
	_pulse_reader(index)

func _ensure_light() -> void:
	if _light != null and is_instance_valid(_light):
		return
	_light = Node3D.new()
	_light.name = "Light"
	_light.visible = false
	add_child(_light)
	_light_material = StandardMaterial3D.new()
	_light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_light_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_light_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_light_material.render_priority = DataCellView.PRIORITY_NET
	_light_material.albedo_color = Color(LIGHT_COLOR.r * LIGHT_ENERGY,
		LIGHT_COLOR.g * LIGHT_ENERGY, LIGHT_COLOR.b * LIGHT_ENERGY, LIGHT_ALPHA)
	_light_plane = MeshInstance3D.new()
	_light_plane.name = "Plane"
	var quad := QuadMesh.new()
	# Quer die kurze Kartenseite (Welt-X), längs die Scheibenlänge (Welt-Z).
	quad.size = Vector2(_side / (1.0 + WorkshopView.DRUM_SIDE_AIR),
		_pitch * SLICE_SHARE / (1.0 + WorkshopView.DRUM_AIR))
	_light_plane.mesh = quad
	_light_plane.material_override = _light_material
	_light_plane.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_light_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light.add_child(_light_plane)

func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

func _turn(index: int, want: float) -> void:
	_kill(index)
	var pivot := _pivots[index]
	if not pivot.is_inside_tree():
		pivot.rotation.z = want
		return
	var from := pivot.rotation.z
	var time := QUARTER_TIME * absf(want - from) / (PI * 0.5)
	if time <= 0.001:
		pivot.rotation.z = want
		return
	var tween := pivot.create_tween()
	tween.tween_property(pivot, "rotation:z", want, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens[index] = tween

func _kill(index: int) -> void:
	if _tweens[index] != null and _tweens[index].is_valid():
		_tweens[index].kill()
	_tweens[index] = null

## Der Vierkant samt seinen vier Leser-Seiten: Seite k liegt oben bei face_angle(k).
func _build_slice(pivot: Node3D, side: float, thickness: float) -> Array:
	var body := MeshInstance3D.new()
	body.name = "Koerper"
	var box := BoxMesh.new()
	var wall := well_depth(side)
	box.size = Vector3(side - wall * 2.0, side - wall * 2.0, thickness)
	body.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = BODY_ALBEDO
	material.metallic = 0.4
	material.roughness = 0.5
	material.emission_enabled = true
	material.emission = BODY_EMISSION
	material.emission_energy_multiplier = BODY_EMISSION_ENERGY
	body.material_override = material
	_bodies.append(material)
	pivot.add_child(body)
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			_part(pivot, "Holm", Vector3(wall, wall, thickness),
				Vector3(x * (side - wall) * 0.5, y * (side - wall) * 0.5, 0.0), material)
	var readers: Array = []
	for rank in Pack.SHELF_ORDER.size():
		var shelf: String = Pack.SHELF_ORDER[rank]
		var face := Node3D.new()
		face.name = "Leser_%s" % shelf
		# Rückwärts gedreht: die Pivot-Drehung um face_angle bringt sie nach oben.
		face.basis = Basis(Vector3.BACK, -face_angle(rank))
		pivot.add_child(face)
		readers.append(_build_reader(face, shelf, side, thickness))
	return readers

## Der LESER einer Seite (Spieler-Wahl 2026-11-19 aus Blender-Entwürfen,
## tools/blender_drum_readers.py): FÜHLHEBEL (Lochkarte), KLAPPE (Kassette), ROLLSIEGEL
## (Tontafel), BRENNER (Service-Modul). Kopf der Karte = -Z der Seite. Feste Teile bleiben
## im Drehkreis (clear_height); was höher ragt, ist ein MOVER und liegt in POSE_REST flach.
func _build_reader(face: Node3D, shelf: String, side: float, thickness: float) -> Dictionary:
	var tint: Color = PackDrawerView.COLORS.get(shelf, Color.WHITE)
	var reader := {"movers": [], "lamps": []}
	var top := side * 0.5
	var across := side / (1.0 + WorkshopView.DRUM_SIDE_AIR)
	var length := thickness / (1.0 + WorkshopView.DRUM_AIR)
	var k := across / DataCellView.WIDTH if DataCellView.WIDTH > 0.0 else 1.0
	var edge := length * 0.5 + (thickness - length) * 0.25
	var rank: int = Pack.SHELF_ORDER.find(shelf)
	var sink := card_sink(side)
	_build_bed(face, reader, rank, tint, top, side, length, thickness, k)
	match DataCellView.carrier_of(shelf):
		DataCellView.CARRIER_PUNCH:
			_build_feelers(face, reader, tint, top, across, edge, k, sink)
		DataCellView.CARRIER_CASSETTE:
			_build_lid(face, reader, tint, top, across, length, edge, k, sink)
		DataCellView.CARRIER_CLAY:
			_build_roller(face, reader, tint, top, across, length, edge, k, sink)
		_:
			_build_burner(face, reader, tint, top, across, length, edge, k)
	return reader

## Das BETT einer Seite IST die Mulde ihres Magazin-Trays: Saum, Boden und Halterung des
## Geräts, ohne Wandauskleidung - die Wände sind Holme und Stirnwände der Scheibe.
func _build_bed(face: Node3D, reader: Dictionary, rank: int, tint: Color, top: float,
		side: float, length: float, thickness: float, k: float) -> void:
	var well := well_depth(side)
	var inner := Vector2(length * 0.5 + WELL_AIR, side * 0.5 - well)
	var bay := Node3D.new()
	bay.name = "Mulde"
	bay.position.y = top - well
	face.add_child(bay)
	var size := Vector2(inner.y, inner.x) * 2.0
	ShelfStackView.build_bay(bay, size, _lamp(reader, tint, [SEAM_DIM, SEAM_ON, SEAM_ON]), k,
		null, MagazinTrayDress.floor_material(rank), false)
	var light: StandardMaterial3D = null
	if rank == MagazinTrayDress.ZAHL or rank == MagazinTrayDress.MATERIAL:
		light = _lamp(reader, tint, [FLOOR_DARK, FLOOR_DARK, FLOOR_LIT])
	if rank == MagazinTrayDress.ZAHL:
		MagazinTrayDress.build_dots(bay, ShelfStackView.FLOOR_RISE, k, light)
	MagazinTrayDress.build_holder(bay, rank, size, ShelfStackView.FLOOR_RISE,
		ShelfStackView.PROUD, k, light, false)
	_well_frame(face, MagazinTrayDress.inside_material(rank), top, well, inner, thickness)

## So tief ist die Mulde - und so breit ihre Wand längs der Kanten: tiefer brächen die
## Mulden zweier Nachbarseiten an der Kante ineinander.
static func well_depth(side: float) -> float:
	return (side - side / (1.0 + WorkshopView.DRUM_SIDE_AIR)) * 0.5 - WELL_AIR

## So tief liegt die Unterseite der Karte unter der Seite: wie im Magazin um PROUD über
## dem Muldenboden.
static func card_sink(side: float) -> float:
	return well_depth(side) - ShelfStackView.PROUD

## Der Rand der Mulde im Grubeninneren ihres Trays: die Stirnwände und ihre Kappen auf den
## Kanten-Holmen der Scheibe. inner = halbe Öffnung (längs, quer).
func _well_frame(face: Node3D, rim: Material, top: float, well: float,
		inner: Vector2, thickness: float) -> void:
	var deep := thickness * 0.5 - inner.x
	for z: float in [-1.0, 1.0]:
		_part(face, "Stirnwand", Vector3(inner.y * 2.0, well, deep),
			Vector3(0.0, top - well * 0.5, z * (inner.x + deep * 0.5)), rim)
	var cap := well - 0.01
	_prints(face, "Randkappe", [_box2(0.0, inner.y + cap * 0.5, thickness, cap),
		_box2(0.0, -inner.y - cap * 0.5, thickness, cap)], top + 0.002, 1.0, rim)

## Flache Drucke (Karten-Maß) als EIN Körper auf Höhe y; beidseitig, die Wicklung ist gleich.
func _prints(face: Node3D, part_name: String, polys: Array, y: float, k: float,
		material: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for poly: PackedVector2Array in polys:
		for i in range(1, poly.size() - 1):
			for j: int in [0, i, i + 1, 0, i + 1, i]:
				tool.add_vertex(Vector3(poly[j].y * k, y, poly[j].x * k))
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = tool.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.add_child(node)

static func _box2(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x - w * 0.5, y - h * 0.5), Vector2(x + w * 0.5, y - h * 0.5),
		Vector2(x + w * 0.5, y + h * 0.5), Vector2(x - w * 0.5, y + h * 0.5)])

## So hoch darf ein festes Teil im Abstand x von der Mittellinie über die Seite ragen,
## ohne aus dem Drehkreis des Vierkants zu treten.
static func clear_height(side: float, x: float) -> float:
	var room := side * side * 0.5 - x * x
	return maxf(sqrt(maxf(room, 0.0)) - side * 0.5, 0.0)

## FÜHLHEBEL: ein Balken am Kopf, zehn gefederte Finger. Liegt die Karte, senken sie sich
## auf sie; wer ein Loch findet, fällt hinein, und seine Lampe am Balken geht an.
func _build_feelers(face: Node3D, reader: Dictionary, tint: Color, top: float, across: float,
		edge: float, k: float, well: float) -> void:
	var metal := DataCellView.neutral_material("Metall")
	var dark := DataCellView.neutral_material("Dunkel")
	var span := across * 0.36
	_part(face, "Balken", Vector3(span * 2.0 + 0.2, FEELER_BAR, 0.16),
		Vector3(0.0, top + FEELER_BAR * 0.5, -edge), dark)
	var hit := _lamp(reader, tint, [LAMP_DIM, LAMP_DIM, LAMP_ON])
	var miss := _lamp(reader, tint, [LAMP_DIM, LAMP_DIM, LAMP_DIM])
	var card_top := float(DataCellView.CARRIER_TOPS[DataCellView.CARRIER_PUNCH]) * k - well
	var pivot_y := FEELER_BAR - 0.05
	var slice := _pivots.size()
	for i in FEELERS:
		var x := (float(i) - float(FEELERS - 1) * 0.5) * span * 2.0 / float(FEELERS - 1)
		var found := feeler_hits(slice, i)
		_part(face, "Lampe%d" % i, Vector3(0.1, 0.02, 0.1),
			Vector3(x, top + FEELER_BAR + 0.01, -edge), hit if found else miss)
		var finger := Node3D.new()
		finger.name = "Finger%d" % i
		finger.position = Vector3(x, top + pivot_y, -edge + 0.06)
		face.add_child(finger)
		_part(finger, "Hebel", Vector3(0.035, 0.035, FEELER_REACH),
			Vector3(0.0, 0.0, FEELER_REACH * 0.5), metal)
		_part(finger, "Taster", Vector3(0.07, 0.09, 0.07), Vector3(0.0, -0.03, FEELER_REACH),
			DataCellView.neutral_material("Pad"))
		var lies := card_top + 0.07 if not found else card_top - 0.08 + 0.07
		_mover(reader, finger, [_tilt(finger, pivot_y - 0.08), _tilt(finger, pivot_y + 0.2),
			_tilt(finger, pivot_y - lies)])

## Trifft Finger i der Scheibe ein Loch? Fest je Scheibe, vier von zehn.
static func feeler_hits(slice: int, finger: int) -> bool:
	return posmod(finger * 7 + slice * 3, 10) < 4

## Der Finger so geneigt, daß seine Spitze um drop unter dem Drehpunkt liegt.
func _tilt(finger: Node3D, drop: float) -> Transform3D:
	var angle := asin(clampf(drop / FEELER_REACH, -1.0, 1.0))
	return Transform3D(Basis(Vector3.RIGHT, angle), finger.position)

## KLAPPE: ein Klarsicht-Rahmen über dem Deck. In Ruhe liegt er flach auf der Seite, vor
## der Ankunft steht er offen, über der Kassette schließt er sich und leuchtet.
func _build_lid(face: Node3D, reader: Dictionary, tint: Color, top: float, across: float,
		length: float, edge: float, k: float, well: float) -> void:
	var metal := DataCellView.neutral_material("Metall")
	_rod(face, "Scharnier", 0.04, across * 0.8, Vector3(0.0, top + 0.05, -edge), metal)
	var frame := _lamp(reader, tint, [LAMP_DIM, 1.0, LAMP_ON])
	var lid := Node3D.new()
	lid.name = "Klappe"
	face.add_child(lid)
	var half := across * 0.5 - 0.06
	var far := length + (edge - length * 0.5)
	for x: float in [-1.0, 1.0]:
		_part(lid, "Holm", Vector3(0.07, LID_BAR, far), Vector3(x * half, 0.0, far * 0.5), frame)
	for z: float in [0.035, far - 0.035]:
		_part(lid, "Riegel", Vector3(half * 2.0, LID_BAR, 0.07), Vector3(0.0, 0.0, z), frame)
	_part(lid, "Griff", Vector3(0.6, LID_BAR, 0.08), Vector3(0.0, 0.0, far + 0.03), metal)
	var glass := MeshInstance3D.new()
	glass.name = "Glas"
	var pane := BoxMesh.new()
	pane.size = Vector3(half * 2.0, 0.01, far)
	glass.mesh = pane
	glass.position = Vector3(0.0, 0.0, far * 0.5)
	glass.material_override = _lid_glass()
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lid.add_child(glass)
	var hinge_z := -edge
	var closed := float(DataCellView.CARRIER_TOPS[DataCellView.CARRIER_CASSETTE]) * k - well \
		+ 0.06
	_mover(reader, lid, [
		Transform3D(Basis.IDENTITY, Vector3(0.0, top + LID_BAR * 0.5, hinge_z)),
		Transform3D(Basis(Vector3.RIGHT, -LID_OPEN), Vector3(0.0, top + closed, hinge_z)),
		Transform3D(Basis.IDENTITY, Vector3(0.0, top + closed, hinge_z))])

func _lid_glass() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.75, 0.82, 0.95, 0.07)
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	return glass

## ROLLSIEGEL: eine gravierte Walze. In Ruhe liegt sie flach am Kopf, vor der Ankunft
## hebt sie sich, auf der Tafel liegt sie auf - und beim Lesen rollt sie über sie hin.
func _build_roller(face: Node3D, reader: Dictionary, tint: Color, top: float, across: float,
		length: float, edge: float, k: float, well: float) -> void:
	var brass := DataCellView.neutral_material("Pad")
	for x: float in [-1.0, 1.0]:
		_part(face, "Schiene", Vector3(0.05, 0.035, length),
			Vector3(x * (across * 0.5 + 0.045), top + 0.0175, 0.0), brass)
	var roller := Node3D.new()
	roller.name = "Rollsiegel"
	face.add_child(roller)
	var span := across * 0.74
	_rod(roller, "Stein", ROLLER_R, span, Vector3.ZERO, DataCellView.neutral_material("Kerbe"))
	_rod(roller, "Achse", 0.04, span + 0.24, Vector3.ZERO, DataCellView.neutral_material("Metall"))
	var band := _lamp(reader, tint, [LAMP_DIM, 0.8, LAMP_ON])
	for i in 7:
		_rod(roller, "Band%d" % i, ROLLER_R + 0.008, 0.05,
			Vector3((float(i) - 3.0) * span / 7.0, 0.0, 0.0), band)
	var tablet := float(DataCellView.CARRIER_TOPS[DataCellView.CARRIER_CLAY]) * k - well
	var park := -edge + 0.02
	var poses := [
		Transform3D(Basis.IDENTITY, Vector3(0.0, top + ROLLER_R, park)),
		Transform3D(Basis.IDENTITY, Vector3(0.0, top + tablet + ROLLER_R + 0.12, park)),
		Transform3D(Basis.IDENTITY, Vector3(0.0, top + tablet + ROLLER_R, -length * 0.5 + 0.5))]
	var mover := _mover(reader, roller, poses)
	mover["sweep"] = Transform3D(Basis.IDENTITY,
		Vector3(0.0, top + tablet + ROLLER_R, length * 0.5 - 0.5))

## BRENNER: eine Steckleiste am Fuß und ein Schwenkarm, dessen Linse über dem Fenster des
## Chips steht. In Ruhe liegt der Arm quer über der Leiste.
func _build_burner(face: Node3D, reader: Dictionary, tint: Color, top: float, across: float,
		_length: float, edge: float, k: float) -> void:
	var dark := DataCellView.neutral_material("Dunkel")
	var metal := DataCellView.neutral_material("Metall")
	var strip := across * 0.8
	_part(face, "Leiste", Vector3(strip, 0.14, 0.15), Vector3(0.0, top + 0.07, edge), dark)
	for i in 11:
		_part(face, "Feder%d" % i, Vector3(0.12, 0.012, 0.1),
			Vector3((float(i) - 5.0) * 0.085 * k, top + 0.146, edge - 0.02),
			DataCellView.neutral_material("Pad"))
	var light := _lamp(reader, tint, [LAMP_DIM, 0.8, LAMP_ON])
	_part(face, "Leistenlicht", Vector3(strip - 0.2, 0.012, 0.03),
		Vector3(0.0, top + 0.146, edge + 0.05), light)
	# Das Chip-Fenster liegt 0,375 quer und 0,3 längs der Kartenmitte (Roh-Maß des Modells).
	var post := Vector3(0.375 * k, top, edge)
	_pin(face, "Armfuss", 0.09, BURNER_ARM, post, dark)
	var arm := Node3D.new()
	arm.name = "Arm"
	face.add_child(arm)
	var reach := edge - 0.3 * k
	_part(arm, "Ausleger", Vector3(0.12, 0.05, reach), Vector3(0.0, 0.0, -reach * 0.5), metal)
	_pin(arm, "Kopf", 0.2, 0.07, Vector3(0.0, -0.035, -reach), dark)
	_pin(arm, "Linse", 0.13, 0.012, Vector3(0.0, 0.035, -reach), light)
	var at := post + Vector3.UP * BURNER_ARM
	_mover(reader, arm, [Transform3D(Basis(Vector3.UP, PI * 0.5), at),
		Transform3D(Basis(Vector3.UP, PI * 0.25), at), Transform3D(Basis.IDENTITY, at)])

## Ein bewegliches Teil mit seinen drei Stellungen; es steht sofort in POSE_REST.
func _mover(reader: Dictionary, node: Node3D, poses: Array) -> Dictionary:
	var mover := {"node": node, "poses": poses}
	node.transform = poses[POSE_REST]
	(reader["movers"] as Array).append(mover)
	return mover

## Eine Leuchtfläche des Lesers mit ihrer Helligkeit je Stellung.
func _lamp(reader: Dictionary, tint: Color, energies: Array) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _lit(tint, float(energies[POSE_REST]))
	(reader["lamps"] as Array).append({"material": material, "tint": tint, "energies": energies})
	return material

static func _lit(tint: Color, energy: float) -> Color:
	return Color(tint.r * energy, tint.g * energy, tint.b * energy, 1.0)

# --- Die Stellungen der Leser ----------------------------------------------------------------

func reader_pose(index: int) -> int:
	return _pose[index] if index >= 0 and index < _pose.size() else POSE_REST

## Liegt die Karte auf Scheibe index? Dann greift ihr Leser zu (POSE_LOADED), sonst steht
## er bereit, solange die Scheibe belegt ist. Idempotent; gefragt je Bild.
func set_loaded(index: int, on: bool) -> void:
	if index < 0 or index >= _pose.size() or _rank[index] < 0:
		return
	var idle := POSE_READY if _powered else POSE_REST
	_pose_to(index, POSE_LOADED if on else idle, POSE_TIME)

## Der EINE Schreiber der Leser-Stellung: Endzustand zuerst, die Fahrt folgt.
func _pose_to(index: int, pose: int, time: float, delay := 0.0) -> void:
	if _pose[index] == pose:
		return
	_pose[index] = pose
	_kill_tween(_pose_tweens[index])
	_pose_tweens[index] = null
	var reader := _reader_of(index)
	if reader.is_empty():
		return
	if time <= 0.0 or not is_inside_tree():
		_pose_hard(reader, pose)
		return
	var tween := create_tween().set_parallel(true)
	_pose_tweens[index] = tween
	for mover: Dictionary in reader["movers"]:
		tween.tween_property(mover["node"], "transform", (mover["poses"] as Array)[pose], time) \
			.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for lamp: Dictionary in reader["lamps"]:
		tween.tween_property(lamp["material"], "albedo_color", _lamp_color(lamp, pose), time) \
			.set_delay(delay)

func _pose_hard(reader: Dictionary, pose: int) -> void:
	for mover: Dictionary in reader["movers"]:
		(mover["node"] as Node3D).transform = (mover["poses"] as Array)[pose]
	for lamp: Dictionary in reader["lamps"]:
		(lamp["material"] as StandardMaterial3D).albedo_color = _lamp_color(lamp, pose)

func _reader_of(index: int) -> Dictionary:
	if index < 0 or index >= _readers.size() or _rank[index] < 0:
		return {}
	return (_readers[index] as Array)[_rank[index]]

## Die Seite der Scheibe wechselt: der alte Leser legt sich flach, der neue steht bereit,
## sobald die Scheibe gedreht hat.
func _set_rank(index: int, rank: int, hard: bool) -> void:
	if _rank[index] == rank:
		return
	if _rank[index] >= 0:
		_pose_to(index, POSE_REST, 0.0 if hard else REST_TIME)
	_rank[index] = rank
	_pose[index] = POSE_REST
	if rank >= 0 and _powered:
		_pose_to(index, POSE_READY, 0.0 if hard else POSE_TIME, 0.0 if hard else QUARTER_TIME)

## Der Leser LIEST (die Scheibe verriegelt): seine Lampen blitzen, das Rollsiegel rollt
## einmal über die Tafel und zurück.
func _pulse_reader(index: int) -> void:
	var reader := _reader_of(index)
	if reader.is_empty() or _pose[index] != POSE_LOADED or not is_inside_tree():
		return
	_kill_tween(_pose_tweens[index])
	var tween := create_tween().set_parallel(true)
	_pose_tweens[index] = tween
	for lamp: Dictionary in reader["lamps"]:
		var material: StandardMaterial3D = lamp["material"]
		material.albedo_color = _lit(lamp["tint"], LAMP_FLASH)
		tween.tween_property(material, "albedo_color", _lamp_color(lamp, POSE_LOADED),
			SWEEP_TIME * 2.0)
	for mover: Dictionary in reader["movers"]:
		if not mover.has("sweep"):
			continue
		var node: Node3D = mover["node"]
		var home: Transform3D = (mover["poses"] as Array)[POSE_LOADED]
		tween.tween_property(node, "transform", mover["sweep"], SWEEP_TIME)
		tween.tween_property(node, "transform", home, SWEEP_TIME).set_delay(SWEEP_TIME)

func _part(face: Node3D, part_name: String, size: Vector3, at: Vector3,
		material: Material) -> void:
	TableProps.box(face, part_name, size, at, material)

## Ein liegender Zylinder quer zur Achse (längs X der Seite).
func _rod(host: Node3D, part_name: String, radius: float, span: float, at: Vector3,
		material: Material) -> void:
	var rod := MeshInstance3D.new()
	rod.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = span
	mesh.radial_segments = 16
	mesh.rings = 1
	rod.mesh = mesh
	rod.material_override = material
	rod.rotation = Vector3(0.0, 0.0, PI * 0.5)
	rod.position = at
	rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(rod)

func _pin(face: Node3D, part_name: String, radius: float, height: float, foot: Vector3,
		material: Material) -> void:
	var pin := MeshInstance3D.new()
	pin.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	pin.mesh = mesh
	pin.material_override = material
	pin.position = foot + Vector3.UP * height * 0.5
	pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.add_child(pin)
