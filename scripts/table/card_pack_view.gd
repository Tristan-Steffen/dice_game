class_name CardPackView
extends DataCellView
## Der Körper eines PAKETS, eine Spur größer als die liegende Karte. Ein KARTEN-Paket ist
## eine DATEN-KASSETTE (Spieler-Wahl 2026-11-10): Metallgehäuse, Glasfenster mit einer
## leuchtenden Kartenkante je Option, Sorte = Farbe; die Größe macht sie DICKER und edler
## (Band, Stahlrahmen, Goldecken), der Grundriß bleibt EINER. Ein WÜRFEL-Paket ist die
## SCHATULLE aus Blender (tools/blender_dice_case.py): ihre Naht leuchtet in der Sortenfarbe,
## die Augen auf dem Deckel zählen die Optionen, Riesig trägt Gold. Bewegt wird sie wie eine Karte.

## Grundriß gegenüber der Karte und Dicke der Hülle (Kartenmaß, vor CASSETTE_SCALE).
const FOOT_ROOM := 1.04
const THICKNESS := DataCellView.DEPTH * 2.6
const SHELL_ALBEDO := Color(0.10, 0.10, 0.14)
const SHELL_EMISSION_ENERGY := 0.12
const SEAL_SHARE := 0.16
const RIM_SHARE := 0.035
const MARK_COUNT_MAX := 4
const MARK_LENGTH_SHARE := 0.42
const MARK_WIDTH := DataCellView.HEIGHT * 0.035
const MARK_GAP := DataCellView.HEIGHT * 0.035
const LID_PROUD := DataCellView.DEPTH * 0.06
## Die Kassette wächst je Größe nur in die Dicke.
const CASSETTE_THICKNESS := [DataCellView.DEPTH * 2.0, DataCellView.DEPTH * 2.3,
	DataCellView.DEPTH * 2.6, DataCellView.DEPTH * 2.9]
const CASSETTE_ALBEDO := Color(0.17, 0.18, 0.21)
const WINDOW_ALBEDO := Color(0.05, 0.06, 0.09)
const WINDOW_EMISSION_ENERGY := 0.18
const WINDOW_SHARE := Vector2(0.62, 0.5)
const WINDOW_Y_SHARE := 0.06
const CARD_EDGE_LENGTH_SHARE := 0.82
const CARD_EDGE_WIDTH_SHARE := 0.035
const SEAM_HEIGHT_SHARE := 0.07
const SEAM_Z_SHARE := 0.42
const SEAM_PROUD := DataCellView.DEPTH * 0.03
const CORNER_SHARE := Vector2(0.13, 0.09)
const DICE_CASE_SCENE := "res://assets/models/hardware/dice_case.glb"
const DICE_THICKNESS := DataCellView.DEPTH * 3.2
const CASE_ALBEDO := Color(0.2, 0.2, 0.24)
const CASE_GLOW := Color(0.5, 0.52, 0.6)
const CASE_GLOW_ENERGY := 0.2
const CASE_STEEL_ENERGY := 0.45
## Welche Augen der Schatulle je Optionszahl stehen (Auge0 Mitte, 1/2 quer, 3/4 längs).
const CASE_PIPS := {3: [0, 3, 4], 4: [1, 2, 3, 4], 5: [0, 1, 2, 3, 4]}
static var _dice_case_scene: PackedScene
## Der Innenraum im Roh-Maß - spiegelt WALL/FLOOR aus tools/blender_dice_case.py.
const CASE_WALL := 0.05
const CASE_FLOOR := 0.03
const LID_OPEN_DEGREES := 105.0
const LID_TIME := 0.35
const VELVET_ALBEDO := Color(0.05, 0.035, 0.08)
const VELVET_GLOW := Color(0.16, 0.1, 0.24)
const VELVET_TINT_SHARE := 0.2
const VELVET_ENERGY := 0.35
var _case_model: Node3D
var _hinge: Node3D
var _hinge_rest := Transform3D()
var _lid_share := 0.0
var _lid_tween: Tween
var _velvet: StandardMaterial3D
## Misch-Paket: das Siegel trägt die drei Regal-Farben nebeneinander.
const MIXED_STRIPES := [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL,
	Engraving.CATEGORY_DICE]

var card_pack_sort: String = CardPack.SORT_NUMBER
var card_pack_size: int = CardPack.SIZE_NORMAL
## Ein Würfel-Paket (dieselbe Hülle, andere Kennung).
var dice_pack := false
## Augen der Würfel-Kennung: eine Würfelseite mit drei Augen.
const PIP_SIZE := DataCellView.HEIGHT * 0.06
const DIE_FACE_SHARE := 0.5
var _stripe_materials: Array[StandardMaterial3D] = []
var _window_material: StandardMaterial3D
var _steel_material: StandardMaterial3D
var _gold_material: StandardMaterial3D

func _init() -> void:
	name = "CardPack"

## Einziger Eingang: baut die Hülle eines Pakets dieser Sorte und Größe.
func setup_pack(pack_sort: String, pack_size: int, dice := false) -> void:
	card_pack_sort = pack_sort
	card_pack_size = pack_size
	dice_pack = dice
	sort = pack_sort
	tier = Pack.TIER_KOLOSSAL  # volle Intensität: die Hülle kennt keine Kartengröße
	stamp_net = StampNet.empty_net()
	tint = PackDrawerView.dice_pack_tint(pack_sort) if dice \
		else PackDrawerView.card_pack_tint(pack_sort)
	_build_materials()
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_badge = _build_badge()
	_body.add_child(_badge)
	_apply_pose()
	set_count(1)

## Wie hoch die HÖCHSTE liegende Hülle über ihrem Glaspunkt aufragt - das Maß der Schächte.
static func lying_height(cell_scale: float) -> float:
	return maxf(DICE_THICKNESS, CASSETTE_THICKNESS.max()) * cell_scale

func thickness() -> float:
	if dice_pack:
		return DICE_THICKNESS if dice_case_model() != null else THICKNESS
	return float(CASSETTE_THICKNESS[clampi(card_pack_size, 0, CASSETTE_THICKNESS.size() - 1)])

func rise_depth() -> float:
	return thickness() * _body_scale

## Der Moment des Aufbrechens: das Siegel lodert, dann zerfällt die Hülle.
func burst() -> void:
	flare()
	dematerialize()

func _build_materials() -> void:
	_shell_material = StandardMaterial3D.new()
	_shell_material.albedo_color = SHELL_ALBEDO
	_shell_material.metallic = 0.55
	_shell_material.roughness = 0.35
	_shell_material.emission_enabled = true
	_shell_material.emission = _scaled(tint, 1.0)
	_shell_material.emission_energy_multiplier = SHELL_EMISSION_ENERGY
	_shell_material.render_priority = _prio(PRIORITY_BODY)
	# Siegel und Saum leuchten in der Sortenfarbe - sie sind der Kern der Hülle.
	_core_material = _lit_material(tint)
	_core_material.render_priority = _prio(PRIORITY_FRAME)
	_edge_material = _lit_material(tint)
	_edge_material.emission_energy_multiplier = EDGE_REST_ENERGY
	_edge_material.render_priority = _prio(PRIORITY_FRAME)
	_stripe_materials.clear()
	_build_cassette_materials()
	if not dice_pack and card_pack_sort == CardPack.SORT_MIXED:
		for shelf: String in MIXED_STRIPES:
			var stripe := _lit_material(PackDrawerView.COLORS.get(shelf, tint))
			stripe.render_priority = _prio(PRIORITY_NET)
			_stripe_materials.append(stripe)

func _build_cassette_materials() -> void:
	_shell_material.albedo_color = CASSETTE_ALBEDO
	_shell_material.metallic = 0.75
	_shell_material.roughness = 0.32
	_shell_material.emission_energy_multiplier = SHELL_EMISSION_ENERGY * 0.5
	_window_material = StandardMaterial3D.new()
	_window_material.albedo_color = WINDOW_ALBEDO
	_window_material.roughness = 0.12
	_window_material.metallic = 0.1
	_window_material.emission_enabled = true
	_window_material.emission = _scaled(tint, 1.0)
	_window_material.emission_energy_multiplier = WINDOW_EMISSION_ENERGY
	_steel_material = _metal(Color(0.55, 0.57, 0.62), Color(0.55, 0.57, 0.62), 0.12)
	_gold_material = _metal(CasinoStyle.GOLD, CasinoStyle.GOLD_INTENSE, 0.35)

func _metal(albedo: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.9
	material.roughness = 0.24
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = energy
	return material

func _build_cell() -> Node3D:
	if not dice_pack:
		return _build_cassette()
	var case := _build_dice_case()
	if case != null:
		return case
	var cell := Node3D.new()
	cell.name = "Hull%d" % _cells.size()
	var width := DataCellView.WIDTH * FOOT_ROOM
	var length := DataCellView.HEIGHT * FOOT_ROOM
	var bottom := -DataCellView.DEPTH * 0.5
	var lid := bottom + THICKNESS
	TableProps.box(cell, "Shell", Vector3(width, length, THICKNESS),
		Vector3(0.0, 0.0, bottom + THICKNESS * 0.5), _shell_material)
	# Der SAUM läuft rund um die Deckelkante.
	var rim := width * RIM_SHARE
	var rim_z := lid - rim * 0.5 + LID_PROUD
	TableProps.box(cell, "RimLeft", Vector3(rim, length, rim),
		Vector3(-(width - rim) * 0.5, 0.0, rim_z), _edge_material)
	TableProps.box(cell, "RimRight", Vector3(rim, length, rim),
		Vector3((width - rim) * 0.5, 0.0, rim_z), _edge_material)
	TableProps.box(cell, "RimTop", Vector3(width, rim, rim),
		Vector3(0.0, (length - rim) * 0.5, rim_z), _edge_material)
	TableProps.box(cell, "RimFoot", Vector3(width, rim, rim),
		Vector3(0.0, -(length - rim) * 0.5, rim_z), _edge_material)
	# Das SIEGELBAND quer über den Deckel, ein Drittel vom Kopf.
	var seal := length * SEAL_SHARE
	var seal_y := length * 0.18
	var band_z := lid + LID_PROUD * 0.5
	if dice_pack:
		_build_die_face(cell, width, length * 0.16, band_z)
	elif _stripe_materials.is_empty():
		TableProps.box(cell, "Seal", Vector3(width, seal, LID_PROUD), Vector3(0.0, seal_y,
			band_z), _core_material)
	else:
		var stripe := seal / float(_stripe_materials.size())
		for i in _stripe_materials.size():
			TableProps.box(cell, "Seal%d" % i, Vector3(width, stripe, LID_PROUD),
				Vector3(0.0, seal_y - seal * 0.5 + stripe * (float(i) + 0.5), band_z),
				_stripe_materials[i])
	# Die GRÖSSE als Strich-Marken in der Fußhälfte.
	var marks := clampi(card_pack_size + 1, 1, MARK_COUNT_MAX)
	var span := float(marks) * MARK_WIDTH + float(marks - 1) * MARK_GAP
	for i in marks:
		var y := -length * (0.30 if dice_pack else 0.22) - span * 0.5 + MARK_WIDTH * 0.5 \
			+ float(i) * (MARK_WIDTH + MARK_GAP)
		TableProps.box(cell, "Mark%d" % i, Vector3(width * MARK_LENGTH_SHARE, MARK_WIDTH,
			LID_PROUD), Vector3(0.0, y, band_z), _core_material)
	return cell

## Die Kennung des Würfel-Pakets: ein quadratischer Saum mit drei Augen diagonal.
func _build_die_face(cell: Node3D, width: float, center_y: float, z: float) -> void:
	var side := width * DIE_FACE_SHARE
	var rim := width * RIM_SHARE
	for edge in [Vector2(-1, 0), Vector2(1, 0)]:
		TableProps.box(cell, "FaceSide%d" % int(edge.x), Vector3(rim, side, LID_PROUD),
			Vector3(edge.x * (side - rim) * 0.5, center_y, z), _edge_material)
	for edge in [-1.0, 1.0]:
		TableProps.box(cell, "FaceCap%d" % int(edge), Vector3(side, rim, LID_PROUD),
			Vector3(0.0, center_y + edge * (side - rim) * 0.5, z), _edge_material)
	var step := side * 0.28
	for i in 3:
		var offset := float(i - 1) * step
		TableProps.box(cell, "Pip%d" % i, Vector3(PIP_SIZE, PIP_SIZE, LID_PROUD),
			Vector3(offset, center_y - offset, z), _core_material)

## Die DATEN-KASSETTE: Gehäuse, Leuchtnaht zwischen Deckel und Boden, Glasfenster mit
## einer Kartenkante je Option, Riegel und Kontakte; die Größe legt Band, Rahmen und Gold an.
func _build_cassette() -> Node3D:
	var cell := Node3D.new()
	cell.name = "Hull%d" % _cells.size()
	var width := DataCellView.WIDTH * FOOT_ROOM
	var length := DataCellView.HEIGHT * FOOT_ROOM
	var depth := thickness()
	var bottom := -DataCellView.DEPTH * 0.5
	var lid := bottom + depth
	TableProps.box(cell, "Shell", Vector3(width, length, depth),
		Vector3(0.0, 0.0, bottom + depth * 0.5), _shell_material)
	var seam_h := depth * SEAM_HEIGHT_SHARE
	var seam_z := bottom + depth * SEAM_Z_SHARE
	TableProps.box(cell, "SeamLong", Vector3(width + SEAM_PROUD * 2.0, length * 0.999, seam_h),
		Vector3(0.0, 0.0, seam_z), _edge_material)
	TableProps.box(cell, "SeamShort", Vector3(width * 0.999, length + SEAM_PROUD * 2.0, seam_h),
		Vector3(0.0, 0.0, seam_z), _edge_material)
	var rim := width * RIM_SHARE
	var rim_z := lid - rim * 0.5 + LID_PROUD
	TableProps.box(cell, "RimLeft", Vector3(rim, length, rim),
		Vector3(-(width - rim) * 0.5, 0.0, rim_z), _edge_material)
	TableProps.box(cell, "RimRight", Vector3(rim, length, rim),
		Vector3((width - rim) * 0.5, 0.0, rim_z), _edge_material)
	TableProps.box(cell, "RimTop", Vector3(width, rim, rim),
		Vector3(0.0, (length - rim) * 0.5, rim_z), _edge_material)
	TableProps.box(cell, "RimFoot", Vector3(width, rim, rim),
		Vector3(0.0, -(length - rim) * 0.5, rim_z), _edge_material)
	# Undurchsichtig: im Fenster leuchten nur die Kanten der Karten, je Option eine.
	var window := Vector2(width * WINDOW_SHARE.x, length * WINDOW_SHARE.y)
	var window_y := length * WINDOW_Y_SHARE
	var face_z := lid + LID_PROUD * 0.5
	TableProps.box(cell, "Window", Vector3(window.x, window.y, LID_PROUD),
		Vector3(0.0, window_y, face_z), _window_material)
	var edges := CardPack.option_count(card_pack_size)
	var span := window.x * 0.78
	for i in edges:
		var x := -span * 0.5 + span * (float(i) + 0.5) / float(edges)
		var material := _core_material
		if not _stripe_materials.is_empty():
			material = _stripe_materials[i % _stripe_materials.size()]
		TableProps.box(cell, "CardEdge%d" % i, Vector3(width * CARD_EDGE_WIDTH_SHARE,
			window.y * CARD_EDGE_LENGTH_SHARE, LID_PROUD),
			Vector3(x, window_y, face_z + LID_PROUD * 0.5), material)
	TableProps.box(cell, "Latch", Vector3(SEAM_PROUD * 3.0, length * 0.14, depth * 0.3),
		Vector3(width * 0.5 + SEAM_PROUD, -length * 0.12, seam_z), _steel_material)
	TableProps.box(cell, "Contacts", Vector3(width * 0.42, SEAM_PROUD * 2.0, depth * 0.22),
		Vector3(0.0, -length * 0.5 - SEAM_PROUD, bottom + depth * 0.22), _gold_material)
	_build_cassette_trim(cell, width, length, depth, bottom, window, window_y, face_z)
	return cell

## Klein schlicht, Normal ein Stahlband, Groß ein Stahlrahmen ums Fenster, Riesig dazu Goldecken.
func _build_cassette_trim(cell: Node3D, width: float, length: float, depth: float,
		bottom: float, window: Vector2, window_y: float, face_z: float) -> void:
	if card_pack_size == CardPack.SIZE_NORMAL:
		TableProps.box(cell, "Band", Vector3(width * 1.001, length * 0.06, LID_PROUD),
			Vector3(0.0, -length * 0.33, face_z), _steel_material)
	if card_pack_size >= CardPack.SIZE_LARGE:
		var frame := width * 0.035
		var outer := window + Vector2(frame, frame) * 2.0
		var frame_z := LID_PROUD * 1.4
		TableProps.box(cell, "FrameLeft", Vector3(frame, outer.y, frame_z),
			Vector3(-(window.x + frame) * 0.5, window_y, face_z), _steel_material)
		TableProps.box(cell, "FrameRight", Vector3(frame, outer.y, frame_z),
			Vector3((window.x + frame) * 0.5, window_y, face_z), _steel_material)
		TableProps.box(cell, "FrameTop", Vector3(outer.x, frame, frame_z),
			Vector3(0.0, window_y + (window.y + frame) * 0.5, face_z), _steel_material)
		TableProps.box(cell, "FrameFoot", Vector3(outer.x, frame, frame_z),
			Vector3(0.0, window_y - (window.y + frame) * 0.5, face_z), _steel_material)
	if card_pack_size >= CardPack.SIZE_HUGE:
		var corner := Vector2(width * CORNER_SHARE.x, length * CORNER_SHARE.y)
		var reach := depth + LID_PROUD * 2.0
		var i := 0
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				TableProps.box(cell, "Corner%d" % i, Vector3(corner.x + SEAM_PROUD * 2.0,
					corner.y + SEAM_PROUD * 2.0, reach), Vector3(sx * (width - corner.x) * 0.5,
					sy * (length - corner.y) * 0.5, bottom + reach * 0.5 - LID_PROUD),
					_gold_material)
				i += 1

## Das Blender-Modell der Schatulle (null = kein Import, dann bleibt die alte Hülle).
static func dice_case_model() -> PackedScene:
	if _dice_case_scene == null and ResourceLoader.exists(DICE_CASE_SCENE):
		_dice_case_scene = load(DICE_CASE_SCENE) as PackedScene
	return _dice_case_scene

func _build_dice_case() -> Node3D:
	var scene := dice_case_model()
	if scene == null:
		return null
	var cell := Node3D.new()
	cell.name = "Hull%d" % _cells.size()
	var model := scene.instantiate() as Node3D
	model.name = "Case"
	# Blender baut Z nach oben, die Zelle liest Z als Höhe: +90° um X stellt es gleich.
	model.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	model.position = Vector3(0.0, 0.0, -DataCellView.DEPTH * 0.5)
	cell.add_child(model)
	# Der Tisch ist zu dunkel für den Lack des Modells: Gehäuse und Metall tragen die
	# Materialien der Kassette, die Naht die Sortenfarbe.
	_shell_material.albedo_color = CASE_ALBEDO
	_shell_material.metallic = 0.35
	_shell_material.roughness = 0.28
	_shell_material.emission = CASE_GLOW
	_shell_material.emission_energy_multiplier = CASE_GLOW_ENERGY
	var metal := _gold_material if card_pack_size >= CardPack.SIZE_HUGE 		else _metal(Color(0.62, 0.64, 0.7), Color(0.62, 0.64, 0.7), CASE_STEEL_ENERGY)
	var shown: Array = CASE_PIPS.get(CardPack.option_count(card_pack_size), CASE_PIPS[5])
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var part := String(mesh.name)
		if part.begins_with("Naht"):
			mesh.material_override = _edge_material
		elif part.begins_with("Deckel") or part.begins_with("Boden"):
			# Außen Lack, innen der Samt - je Fläche nach ihrem Blender-Material.
			for i in mesh.mesh.get_surface_count():
				var source := mesh.mesh.surface_get_material(i)
				var velvet := source != null and source.resource_name.begins_with("Samt")
				mesh.set_surface_override_material(i,
					_velvet_material() if velvet else _shell_material)
		elif part.begins_with("AugeMulde"):
			mesh.visible = int(part.trim_prefix("AugeMulde")) in shown
		elif part.begins_with("Auge"):
			mesh.visible = int(part.trim_prefix("Auge")) in shown
			mesh.material_override = metal
		elif part != "SchliesseMulde":
			mesh.material_override = metal
	if _cells.is_empty():
		_case_model = model
		_hinge = model.find_child("Scharnier", true, false) as Node3D
		if _hinge != null:
			_hinge_rest = _hinge.transform
			_apply_lid()
	return cell

func _velvet_material() -> StandardMaterial3D:
	if _velvet == null:
		_velvet = StandardMaterial3D.new()
		_velvet.albedo_color = VELVET_ALBEDO
		_velvet.roughness = 1.0
		_velvet.emission_enabled = true
		_velvet.emission = VELVET_GLOW.lerp(tint, VELVET_TINT_SHARE)
		_velvet.emission_energy_multiplier = VELVET_ENERGY
		_velvet.render_priority = _prio(PRIORITY_BODY)
	return _velvet

# --- Der DECKEL und der INNENRAUM der Schatulle ------------------------------------

## Hat diese Hülle einen Scharnier-Deckel (nur die importierte Schatulle)?
func has_lid() -> bool:
	return _hinge != null and is_instance_valid(_hinge)

## 0 = zu, 1 = offen - hart gesetzt, eine laufende Fahrt endet.
func set_lid_open(share: float) -> void:
	_kill(_lid_tween)
	_lid_share = clampf(share, 0.0, 1.0)
	_apply_lid()

func lid_share() -> float:
	return _lid_share

## Der Deckel klappt in `time` auf (1) bzw. zu (0); zurück kommt die Fahrzeit.
func swing_lid(open: bool, time := LID_TIME) -> float:
	var goal := 1.0 if open else 0.0
	_kill(_lid_tween)
	if not has_lid() or time <= 0.0 or is_equal_approx(_lid_share, goal):
		set_lid_open(goal)
		return 0.0
	_lid_tween = create_tween()
	var swing := _lid_tween.tween_method(func(value: float) -> void:
		_lid_share = value
		_apply_lid(), _lid_share, goal, time)
	swing.set_trans(Tween.TRANS_BACK if open else Tween.TRANS_QUAD)
	swing.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	return time

func lid_swinging() -> bool:
	return _lid_tween != null and _lid_tween.is_valid()

## Blender-Y ist im glTF -Z: positive Drehung um Blender-Y öffnet, also -Z hier.
func _apply_lid() -> void:
	if not has_lid():
		return
	_hinge.transform = _hinge_rest * Transform3D(
		Basis(Vector3.BACK, -deg_to_rad(LID_OPEN_DEGREES) * _lid_share), Vector3.ZERO)

## Die vier Bodenecken des Innenraums im EIGENEN Raum der Hülle (ohne ihre
## Skalierung) - so rechnet der Aufrufer sie auf jede Lage um, auch vor der Landung.
func case_interior_local() -> Array[Vector3]:
	return _case_corners(case_inner_half(), CASE_FLOOR)

## Dasselbe für den Außen-Grundriß auf der Unterseite (der Zuschnitt der Sektion).
func case_outline_local() -> Array[Vector3]:
	return _case_corners(Vector2(DataCellView.WIDTH, DataCellView.HEIGHT) * FOOT_ROOM * 0.5, 0.0)

func _case_corners(half_raw: Vector2, height: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _case_model == null or not is_instance_valid(_case_model):
		return out
	var to_self := Transform3D()
	var node: Node = _case_model
	while node != null and node != self:
		to_self = (node as Node3D).transform * to_self
		node = node.get_parent()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		# Blender (x, y, z) liegt im glTF als (x, z, -y).
		out.append(to_self * Vector3(half_raw.x * corner.x, height, -half_raw.y * corner.y))
	return out

## Die Hälften des Innenraums im Roh-Maß (Blender X = Breite, Y = Länge).
static func case_inner_half() -> Vector2:
	return Vector2(DataCellView.WIDTH * FOOT_ROOM * 0.5 - CASE_WALL,
		DataCellView.HEIGHT * FOOT_ROOM * 0.5 - CASE_WALL)
