class_name DrumView
extends Node3D
## Die WALZE der Werkstatt (Layout A, docs/plan_werkstatt_walze.md): sechs SCHEIBEN entlang
## Welt-Z (Bild-links → Bild-rechts), Scheibe 1 links. Jede ist ein Vierkant um diese
## Achse, gemessen an der KURZEN Kartenseite, je Seite der Leser EINER Sorte
## (Pack.SHELF_ORDER); die Karte liegt mit ihrer Langseite längs der Achse. Belegt liegt
## der Leser ihrer Sorte oben, bündig Y = 0; leer steht sie auf Kante. Die Scheibe trägt
## keinen Klick.

const SLICES := 6
## Eine Vierteldrehung dauert so lange.
const QUARTER_TIME := 0.25
## Leer steht die Scheibe auf Kante.
const EMPTY_ANGLE := PI * 0.25
## Die Scheibe ist so lang wie ihre Teilung mal diesem Anteil - länger als die Karte.
const SLICE_SHARE := 0.97
## Die Wiegen: Leuchtkraft, flache Höhe, Wangen und Stifte (Welt).
const RIM_ENERGY := 1.3
const CRADLE_FLAT := 0.012
const CRADLE_CHEEK := 0.05
const CRADLE_PIN_R := 0.035
const CRADLE_PIN_H := 0.07
const BODY_ALBEDO := Color(0.16, 0.155, 0.21)
const BODY_EMISSION := Color(0.36, 0.38, 0.52)
const BODY_EMISSION_ENERGY := 0.3

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
	_light = null
	_light_ride = null
	_side = side
	_pitch = pitch
	for i in centers.size():
		var pivot := Node3D.new()
		pivot.name = "Scheibe%d" % (i + 1)
		add_child(pivot)
		pivot.global_position = centers[i] + Vector3.DOWN * side * 0.5
		_build_slice(pivot, side, pitch * SLICE_SHARE)
		_pivots.append(pivot)
		_target.append(EMPTY_ANGLE)
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
		var want := angle_for(pack)
		if is_equal_approx(_target[i], want):
			continue
		_target[i] = want
		_turn(i, want)

## Wie seat, aber ohne Fahrt.
func seat_hard(packs: Array) -> void:
	for i in _pivots.size():
		var pack: Pack = packs[i] if i < packs.size() else null
		_target[i] = angle_for(pack)
		_kill(i)
		_pivots[i].rotation.z = _target[i]

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

## Das Ende der Walze auf dem Glas: die Kammer-seitige Stirn hinter Scheibe 6.
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
	tween.tween_property(material, "emission_energy_multiplier", BODY_EMISSION_ENERGY,
		FLASH_TIME)

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
	quad.size = Vector2(_side / (1.0 + WorkshopView.DRUM_AIR),
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
func _build_slice(pivot: Node3D, side: float, thickness: float) -> void:
	var body := MeshInstance3D.new()
	body.name = "Koerper"
	var box := BoxMesh.new()
	box.size = Vector3(side, side, thickness)
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
	for rank in Pack.SHELF_ORDER.size():
		var shelf: String = Pack.SHELF_ORDER[rank]
		var face := Node3D.new()
		face.name = "Leser_%s" % shelf
		# Rückwärts gedreht: die Pivot-Drehung um face_angle bringt sie nach oben.
		face.basis = Basis(Vector3.BACK, -face_angle(rank))
		pivot.add_child(face)
		_build_reader(face, shelf, side, thickness)

## Die WIEGE ihres Trägers an den Enden der Seite (längs der Achse), wo die Karte sie
## freiläßt: Leuchtbett (Lochkarte), Deck mit zwei Dornen (Kassette), Steinwiege
## (Tontafel), Kontakt-Dock mit Eckstiften (Holo-Emitter). Jedes Teil steht weiter von der
## Kante ab, als es hoch ist - sonst wüchse der Drehkreis der Scheibe über den Graben.
func _build_reader(face: Node3D, shelf: String, side: float, thickness: float) -> void:
	var tint: Color = PackDrawerView.COLORS.get(shelf, Color.WHITE)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = tint * RIM_ENERGY
	var top := side * 0.5
	var across := side / (1.0 + WorkshopView.DRUM_AIR)
	var card := thickness / (1.0 + WorkshopView.DRUM_AIR)
	var margin := (thickness - card) * 0.5
	var end := card * 0.5 + margin * 0.5
	for z: float in [-1.0, 1.0]:
		var at := z * end
		match DataCellView.carrier_of(shelf):
			DataCellView.CARRIER_PUNCH:
				_part(face, "Leuchtbett", Vector3(across * 0.9, CRADLE_FLAT, margin * 0.6),
					Vector3(0.0, top + CRADLE_FLAT * 0.5, at), glow)
			DataCellView.CARRIER_CASSETTE:
				_part(face, "Deck", Vector3(across * 0.9, CRADLE_FLAT, margin * 0.6),
					Vector3(0.0, top + CRADLE_FLAT * 0.5, at),
					DataCellView.neutral_material("Dunkel"))
				if z > 0.0:
					for x: float in [-1.0, 1.0]:
						_pin(face, "Dorn", CRADLE_PIN_R, CRADLE_PIN_H,
							Vector3(x * across * 0.22, top, card * 0.5 + CRADLE_PIN_R * 1.6),
							DataCellView.neutral_material("Metall"))
				_part(face, "Saum", Vector3(across * 0.9, CRADLE_FLAT * 1.5, margin * 0.12),
					Vector3(0.0, top + CRADLE_FLAT * 0.75, at - z * margin * 0.24), glow)
			DataCellView.CARRIER_CLAY:
				_part(face, "Wange", Vector3(across * 0.8, CRADLE_CHEEK, margin * 0.55),
					Vector3(0.0, top + CRADLE_CHEEK * 0.5, at), DataCellView.neutral_material("Ton"))
				_part(face, "Glasur", Vector3(across * 0.8, 0.004, margin * 0.14),
					Vector3(0.0, top + CRADLE_CHEEK + 0.002, at), glow)
			_:
				_part(face, "Kontakt", Vector3(across * 0.7, CRADLE_FLAT, margin * 0.3),
					Vector3(0.0, top + CRADLE_FLAT * 0.5, at), glow)
				for x: float in [-1.0, 1.0]:
					_pin(face, "Eckstift", CRADLE_PIN_R, CRADLE_FLAT * 3.0,
						Vector3(x * across * 0.4, top, at), DataCellView.neutral_material("Metall"))

func _part(face: Node3D, part_name: String, size: Vector3, at: Vector3,
		material: Material) -> void:
	TableProps.box(face, part_name, size, at, material)

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
