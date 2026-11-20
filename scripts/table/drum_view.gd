class_name DrumView
extends Node3D
## Die WALZE der Werkstatt (Layout A, docs/plan_werkstatt_walze.md): sechs SCHEIBEN entlang
## Welt-Z (Bild-links → Bild-rechts), Scheibe 1 links. Jede ist ein Vierkant um diese
## Achse, gemessen an der KURZEN Kartenseite, je Seite der Leser EINER Sorte
## (Pack.SHELF_ORDER); die Karte liegt mit ihrer Langseite längs der Achse. Belegt liegt
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
## Das Bett einer Seite: seine Drucke liegen in Schichten dieser Höhe, höchstens BED_HIGH
## über der Seite - die Karte deckt sie. Was sich deckt, liegt nie in derselben Schicht.
const BED_HIGH := 0.02
const BED_STEP := 0.004
## Luft der Mulde um die Karte (Welt).
const WELL_AIR := 0.012
## Der Leuchttisch unter der Lochkarte: dunkel ohne Karte, hell mit ihr (Anteil der Sortenfarbe).
const FLOOR_DARK := 0.2
const FLOOR_LIT := 1.25
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
## Je Scheibe ihre vier Leser (nach Sorten-Rang), der Rang der belegten Seite (-1 = leer),
## die Stellung ihres Lesers und dessen Fahrt.
var _readers: Array = []
var _rank: Array[int] = []
var _pose: Array[int] = []
var _pose_tweens: Array[Tween] = []
## Je Scheibe: um wie viel der Spieler die LEERE Scheibe weitergedreht hat (ganze Viertel).
var _free: Array[float] = []
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
		_set_rank(i, -1 if pack == null else Pack.shelf_rank(pack), false)
		_drop_spin(i)
		_turn(i, want)

## Wie seat, aber ohne Fahrt.
func seat_hard(packs: Array) -> void:
	for i in _pivots.size():
		var pack: Pack = packs[i] if i < packs.size() else null
		_target[i] = angle_for(pack)
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
		and is_equal_approx(_target[index], EMPTY_ANGLE)

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

## Wo die Karte auf Scheibe index liegt: am Boden ihrer Mulde.
func seat_point(index: int) -> Vector3:
	return top_point(index) - Vector3.UP * well_depth(_side)

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
	_build_bed(face, reader, shelf, tint, top, side, across, length, thickness, k)
	match DataCellView.carrier_of(shelf):
		DataCellView.CARRIER_PUNCH:
			_build_feelers(face, reader, tint, top, across, edge, k, well_depth(side))
		DataCellView.CARRIER_CASSETTE:
			_build_lid(face, reader, tint, top, across, length, edge, k, well_depth(side))
		DataCellView.CARRIER_CLAY:
			_build_roller(face, reader, tint, top, across, length, edge, k, well_depth(side))
		_:
			_build_burner(face, reader, tint, top, across, length, edge, k)
	return reader

## Das BETT einer Seite: eine MULDE, in die die Karte sinkt (well_depth tief), mit einem Rand
## im Material ihres Mediums, einer Lichtlippe in der Sortenfarbe und EINEM Motiv am Boden.
## Maße der Drucke im Karten-Maß: x längs der Achse (Kopf = -x), y quer.
func _build_bed(face: Node3D, reader: Dictionary, shelf: String, tint: Color, top: float,
		side: float, across: float, length: float, thickness: float, k: float) -> void:
	var half := Vector2(length * 0.5 / k, across * 0.5 / k)
	var well := well_depth(side)
	var floor_y := top - well + BED_STEP
	var inner := Vector2(length * 0.5 + WELL_AIR, side * 0.5 - well)
	var ground := Color.BLACK
	var floor_material: Material = null
	var rim := Color.BLACK
	match DataCellView.carrier_of(shelf):
		DataCellView.CARRIER_PUNCH:
			# Der Boden ist ein LEUCHTTISCH: liegt die Karte, scheint er durch ihre Löcher.
			floor_material = _lamp(reader, tint, [FLOOR_DARK, FLOOR_DARK, FLOOR_LIT])
			rim = Color(0.05, 0.05, 0.06)
			_bed_punch(face, tint, floor_y, k, half)
			_pin(face, "Juwel", 0.07, 0.03,
				Vector3(0.0, top, (inner.x + thickness * 0.5) * 0.5), _flat(_lit(tint, 0.95), 1.0))
		DataCellView.CARRIER_CASSETTE:
			ground = Color(0.07, 0.07, 0.085)
			rim = Color(0.5, 0.51, 0.55)
			_bed_cassette(face, tint, floor_y, k)
		DataCellView.CARRIER_CLAY:
			ground = Color(0.34, 0.245, 0.14)
			rim = Color(0.24, 0.165, 0.09)
			_bed_clay(face, tint, floor_y, k, half)
		_:
			ground = _lit(tint, 0.1)
			rim = _lit(tint, 0.22)
			_bed_module(face, tint, floor_y, k, half)
	_part(face, "Grund", Vector3(inner.y * 2.0, BED_STEP, inner.x * 2.0),
		Vector3(0.0, top - well + BED_STEP * 0.5, 0.0),
		floor_material if floor_material != null else _flat(ground, 1.0))
	_well_frame(face, _flat(rim, 1.0), tint, top, well, inner, thickness)

## So tief ist die Mulde - und so breit ihre Wand längs der Kanten: tiefer brächen die
## Mulden zweier Nachbarseiten an der Kante ineinander.
static func well_depth(side: float) -> float:
	return (side - side / (1.0 + WorkshopView.DRUM_SIDE_AIR)) * 0.5 - WELL_AIR

## Der Rand der Mulde: die Stirnwände im Material der Seite, ihre Kappen auf den Kanten-
## Holmen der Scheibe, darauf die Lichtlippe um die Öffnung. inner = halbe Öffnung (längs, quer).
func _well_frame(face: Node3D, rim: Material, tint: Color, top: float, well: float,
		inner: Vector2, thickness: float) -> void:
	var deep := thickness * 0.5 - inner.x
	for z: float in [-1.0, 1.0]:
		_part(face, "Stirnwand", Vector3(inner.y * 2.0, well, deep),
			Vector3(0.0, top - well * 0.5, z * (inner.x + deep * 0.5)), rim)
	var cap := well - 0.01
	_prints(face, "Randkappe", [_box2(0.0, inner.y + cap * 0.5, thickness, cap),
		_box2(0.0, -inner.y - cap * 0.5, thickness, cap)], top + 0.002, 1.0, rim)
	_prints(face, "Lippe", [_box2(0.0, inner.y + 0.015, inner.x * 2.0 + 0.06, 0.03),
		_box2(0.0, -inner.y - 0.015, inner.x * 2.0 + 0.06, 0.03),
		_box2(inner.x + 0.015, 0.0, 0.03, inner.y * 2.0),
		_box2(-inner.x - 0.015, 0.0, 0.03, inner.y * 2.0)], top + 0.004, 1.0,
		_flat(_lit(tint, 0.85), 1.0))

## Die Tabelliermaschine von 1934: grünes Email, am Fuß die Elfenbein-Skala.
func _bed_punch(face: Node3D, _tint: Color, floor_y: float, k: float, half: Vector2) -> void:
	_prints(face, "Skala", [_box2(0.0, -half.y + 0.07, half.x * 2.0 - 0.06, 0.08)],
		floor_y + BED_STEP, k, _flat(Color(0.82, 0.76, 0.6), 1.0))
	var ticks: Array = []
	for i in 20:
		ticks.append(_box2(-half.x + 0.03 + (float(i) + 0.5) * (half.x * 2.0 - 0.06) / 20.0,
			-half.y + 0.07, 0.007, 0.06 if i % 5 == 0 else 0.03))
	_prints(face, "Teilung", ticks, floor_y + BED_STEP * 2.0, k,
		_flat(Color(0.03, 0.03, 0.03), 1.0))

## Der Walkman von 1992: im dunklen Schacht nur die pinken Laufwerks-Zeichen.
func _bed_cassette(face: Node3D, tint: Color, floor_y: float, k: float) -> void:
	_prints(face, "Zeichen", [_tri2(-0.5, -0.38, 0.1, -1.0), _tri2(-0.41, -0.38, 0.1, -1.0),
		_tri2(-0.2, -0.38, 0.11, 1.0), _box2(0.03, -0.38, 0.095, 0.095),
		_box2(0.22, -0.38, 0.034, 0.1), _box2(0.285, -0.38, 0.034, 0.1),
		_tri2(0.46, -0.38, 0.1, 1.0), _tri2(0.55, -0.38, 0.1, 1.0)],
		floor_y + BED_STEP, k, _flat(_lit(tint, 0.95), 1.0))

## Lehmziegel: ein ockergelber Fries mit vier Rosetten.
func _bed_clay(face: Node3D, tint: Color, floor_y: float, k: float, half: Vector2) -> void:
	_prints(face, "Fries", [_box2(0.0, 0.0, half.x * 2.0, 0.3)], floor_y + BED_STEP, k,
		_flat(_lit(tint, 0.6), 1.0))
	var petals: Array = []
	var cores: Array = []
	for i in 4:
		var x := (float(i) - 1.5) * 0.4
		for p in 8:
			var a := TAU * float(p) / 8.0
			petals.append(_disc2(x + cos(a) * 0.062, sin(a) * 0.062, 0.03))
		cores.append(_disc2(x, 0.0, 0.026))
	_prints(face, "Rosetten", petals, floor_y + BED_STEP * 2.0, k,
		_flat(Color(0.8, 0.75, 0.56), 1.0))
	_prints(face, "Rosettenkerne", cores, floor_y + BED_STEP * 3.0, k,
		_flat(_lit(tint, 0.95), 1.0))

## Die lila ESD-Matte: grobes Raster, Lagewinkel, ein Warnzeichen.
func _bed_module(face: Node3D, tint: Color, floor_y: float, k: float, half: Vector2) -> void:
	var grid: Array = []
	for i in range(-4, 5):
		grid.append(_box2(float(i) * 0.18, 0.0, 0.007, half.y * 2.0))
	for j in range(-2, 3):
		grid.append(_box2(0.0, float(j) * 0.18, half.x * 2.0, 0.007))
	_prints(face, "Raster", grid, floor_y + BED_STEP, k, _flat(_lit(tint, 0.3), 1.0))
	var corners: Array = []
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			corners.append(_box2(sx * (half.x - 0.1), sy * (half.y - 0.03), 0.16, 0.014))
			corners.append(_box2(sx * (half.x - 0.027), sy * (half.y - 0.1), 0.014, 0.16))
	var a := Vector2(-0.17, -0.13)
	var b := Vector2(0.17, -0.13)
	var d := Vector2(0.0, 0.16)
	corners.append_array([_line2(a, b, 0.024), _line2(b, d, 0.024), _line2(d, a, 0.024),
		PackedVector2Array([Vector2(0.02, 0.07), Vector2(-0.05, -0.02), Vector2(-0.005, -0.02),
			Vector2(0.005, 0.0)]),
		PackedVector2Array([Vector2(-0.005, -0.02), Vector2(-0.02, -0.1), Vector2(0.05, 0.0),
			Vector2(0.005, 0.0)])])
	_prints(face, "Zeichen", corners, floor_y + BED_STEP * 2.0, k, _flat(_lit(tint, 0.85), 1.0))

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

static func _disc2(x: float, y: float, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 12:
		points.append(Vector2(x + cos(TAU * float(i) / 12.0) * r, y + sin(TAU * float(i) / 12.0) * r))
	return points

## Ein Dreieck, dessen Spitze nach +x (flip 1) oder -x (flip -1) zeigt.
static func _tri2(x: float, y: float, s: float, flip: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x - s * 0.5 * flip, y - s * 0.55),
		Vector2(x + s * 0.5 * flip, y), Vector2(x - s * 0.5 * flip, y + s * 0.55)])

static func _line2(from: Vector2, to: Vector2, width: float) -> PackedVector2Array:
	var across := (to - from).orthogonal().normalized() * width * 0.5
	return PackedVector2Array([from + across, from - across, to - across, to + across])

static func _rrect2(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [Vector3(x + w * 0.5 - r, y - h * 0.5 + r, -0.25),
		Vector3(x + w * 0.5 - r, y + h * 0.5 - r, 0.0), Vector3(x - w * 0.5 + r, y + h * 0.5 - r, 0.25),
		Vector3(x - w * 0.5 + r, y - h * 0.5 + r, 0.5)]
	for corner: Vector3 in corners:
		for i in 5:
			var a := TAU * (corner.z + 0.25 * float(i) / 4.0)
			points.append(Vector2(corner.x + cos(a) * r, corner.y + sin(a) * r))
	return points

## Ein mattes Material mit Eigenlicht (der Tisch beleuchtet nichts); energy 1 = unbeleuchtet hell.
func _flat(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	if energy >= 1.0:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		return material
	material.albedo_color = color
	material.roughness = 0.7
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

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
	# Die zwei Mitnehmer-Dorne des Decks greifen von unten in die Naben.
	for z: float in [-1.0, 1.0]:
		_pin(face, "Dorn", 0.1, 0.16, Vector3(0.3216 * k, top - well, z * 0.52 * k), metal)
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
	_pose_to(index, POSE_LOADED if on else POSE_READY, POSE_TIME)

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
		tween.tween_property(lamp["material"], "albedo_color",
			_lit(lamp["tint"], float((lamp["energies"] as Array)[pose])), time).set_delay(delay)

func _pose_hard(reader: Dictionary, pose: int) -> void:
	for mover: Dictionary in reader["movers"]:
		(mover["node"] as Node3D).transform = (mover["poses"] as Array)[pose]
	for lamp: Dictionary in reader["lamps"]:
		(lamp["material"] as StandardMaterial3D).albedo_color = _lit(lamp["tint"],
			float((lamp["energies"] as Array)[pose]))

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
	if rank >= 0:
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
		tween.tween_property(material, "albedo_color",
			_lit(lamp["tint"], float((lamp["energies"] as Array)[POSE_LOADED])), SWEEP_TIME * 2.0)
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
