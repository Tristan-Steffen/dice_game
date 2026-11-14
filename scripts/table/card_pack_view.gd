class_name CardPackView
extends DataCellView
## Der Körper eines PAKETS, eine Spur größer als die liegende Karte. Ein KARTEN-Paket ist
## eine DATEN-KASSETTE (Spieler-Wahl 2026-11-10): Metallgehäuse, Glasfenster mit einer
## leuchtenden Kartenkante je Option, Sorte = Farbe; die Größe macht sie DICKER und edler
## (Band, Stahlrahmen, Goldecken), der Grundriß bleibt EINER. Ein WÜRFEL-Paket ist die
## SCHATULLE aus Blender (tools/blender_dice_case.py): Naht = Sorte, Augen auf dem Deckel =
## GRUNDZAHL der Würfel, Metall von Schließe und Augen = GÜTE. Bewegt wird sie wie eine Karte.
## Ein MODUL-Paket ist ein silberner ESD-BEUTEL: Siegelnaht mit Quetschrillen, darunter ein
## Streifen in der Farbe der Stufe, schwarzes Etikett mit Warndreieck und „ESD“, goldene
## Kontakte = Grund-Optionen, Reißkerbe rechts; die Größe macht ihn nur dicker.

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
const RIM_PROUD := DataCellView.DEPTH * 0.02
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
## Welche Augen der Schatulle je Grundzahl stehen (Auge0 Mitte, 1/2 quer, 3/4 längs).
const CASE_PIPS := {2: [3, 4], 3: [0, 3, 4], 4: [1, 2, 3, 4], 5: [0, 1, 2, 3, 4]}
## Royal: dunkles Chrom mit violettem Schimmer, die Naht pulst leise.
const ROYAL_ALBEDO := Color(0.09, 0.08, 0.12)
const ROYAL_ENERGY := 1.0
const ROYAL_PULSE_RATE := 2.4
const ROYAL_PULSE_DEPTH := 0.35
static var _dice_case_scene: PackedScene
## Der ESD-BEUTEL: Dicke je Größe, Anteile der Länge, Folie mit leichtem Rosa-Stich.
const BAG_THICKNESS := [DataCellView.DEPTH * 1.3, DataCellView.DEPTH * 1.5,
	DataCellView.DEPTH * 1.7, DataCellView.DEPTH * 1.9]
const BAG_ALBEDO := Color(0.82, 0.76, 0.79)
const BAG_GLOW := Color(0.55, 0.5, 0.56)
const BAG_GLOW_ENERGY := 0.5
const BAG_SEAL_SHARE := 0.13
const BAG_STRIPE_SHARE := 0.05
const BAG_RIDGES := 5
const BAG_FILM_SHARE := 0.45
const BAG_BULGE_SHARE := 0.86
const BAG_LABEL_SHARE := Vector2(0.62, 0.36)
const BAG_LABEL_ALBEDO := Color(0.03, 0.03, 0.035)
const BAG_WARN := Color(1.0, 0.82, 0.1)
const BAG_NOTCH_SHARE := 0.07
const BAG_CONTACT_SHARE := 0.07
const BAG_TEXT_SHARE := 0.11
## Das AUFREISSEN: der Siegelstreifen hebt ab, kippt und vergeht.
const TEAR_TIME := 0.45
const TEAR_LIFT := DataCellView.HEIGHT * 0.35
const TEAR_DRIFT := DataCellView.WIDTH * 0.6
const TEAR_TILT := 1.1
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

## Ein Modul-Paket (der Beutel) und seine Seltenheits-Stufe.
var module_bag := false
var grade: int = ModulePack.GRADE_COMMON
var _tear_strip: Node3D
var _tear_rest := Transform3D()
var _tear_tween: Tween
var _torn := false
var card_pack_sort: String = CardPack.SORT_NUMBER
var card_pack_size: int = CardPack.SIZE_NORMAL
## Ein Würfel-Paket (dieselbe Hülle, andere Kennung).
var dice_pack := false
## Würfel-Paket: seine Güte (Metall) und die Zahl der Augen.
var quality: int = DicePack.QUALITY_STANDARD
var pips := 0
var _case_metal: StandardMaterial3D
var _royal_seam: StandardMaterial3D
var _pulse_time := 0.0
## Augen der Würfel-Kennung: eine Würfelseite mit drei Augen.
const PIP_SIZE := DataCellView.HEIGHT * 0.06
const DIE_FACE_SHARE := 0.5
var _stripe_materials: Array[StandardMaterial3D] = []
var _window_material: StandardMaterial3D
var _steel_material: StandardMaterial3D
var _gold_material: StandardMaterial3D

func _init() -> void:
	name = "CardPack"

## Einziger Eingang: baut die Hülle eines Pakets dieser Sorte und Größe (Würfel: und Güte).
func setup_pack(pack_sort: String, pack_size: int, dice := false,
		pack_quality := DicePack.QUALITY_STANDARD) -> void:
	card_pack_sort = pack_sort
	card_pack_size = pack_size
	dice_pack = dice
	quality = clampi(pack_quality, DicePack.QUALITY_STANDARD, DicePack.QUALITY_ROYAL)
	pips = DicePack.base_count(pack_size)
	sort = pack_sort
	tint = PackDrawerView.dice_pack_tint(pack_sort) if dice \
		else PackDrawerView.card_pack_tint(pack_sort)
	_finish_setup()

## Der ESD-BEUTEL eines Modul-Pakets dieser Größe und Stufe.
func setup_module_bag(pack_size: int, pack_grade: int) -> void:
	module_bag = true
	dice_pack = false
	card_pack_size = pack_size
	grade = clampi(pack_grade, ModulePack.GRADE_COMMON, ModulePack.GRADE_LEGENDARY)
	card_pack_sort = ""
	sort = ""
	tint = ModulePack.grade_tint(grade)
	_finish_setup()

func _finish_setup() -> void:
	tier = Pack.TIER_KOLOSSAL  # volle Intensität: die Hülle kennt keine Kartengröße
	stamp_net = StampNet.empty_net()
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
	if module_bag:
		return float(BAG_THICKNESS[clampi(card_pack_size, 0, BAG_THICKNESS.size() - 1)])
	if dice_pack:
		return DICE_THICKNESS if dice_case_model() != null else THICKNESS
	return float(CASSETTE_THICKNESS[clampi(card_pack_size, 0, CASSETTE_THICKNESS.size() - 1)])

func rise_depth() -> float:
	return thickness() * _body_scale

# --- HOCHKANT im LAGER ------------------------------------------------------------
# Stehend ist der Ursprung die Mitte des RÜCKENS (oben). Wie jede Hülle steht sie um -90°
# um Y gedreht (scene_root._spawn_hull): lokal +X ist Bild-rechts, dorthin zeigt die Fläche.

## Wie lange Aufrichten bzw. Hinlegen in Ruhe dauert, und wie lange der Griff hebt und kippt.
const STAND_TIME := 0.3
const PRESENT_TIME := 0.36
## Bis zu diesem Anteil des Griffs HEBT er senkrecht, danach KIPPT er die Fläche zur Kamera.
const PRESENT_RISE_SHARE := 0.5
## Luft zwischen der präsentierten Hülle und dem Filz (Welt).
const PRESENT_AIR := 0.12
## Die RÜCKEN-MARKE: Sortenfarbe bzw. Stufe, bei der Schatulle innen die Güte.
const SPINE_PROUD := DataCellView.DEPTH * 0.06
const SPINE_WIDTH_SHARE := 0.62
const SPINE_DEPTH_SHARE := 0.5
const SPINE_CORE_SHARE := 0.3
var _stand := 0.0
var _stand_tween: Tween
var _spine: Node3D

## Aufrichten (true) oder Hinlegen; Zeit 0 setzt hart.
func set_standing(on: bool, time := 0.0) -> void:
	var wanted := 1.0 if on else 0.0
	_kill(_stand_tween)
	hover_time = PRESENT_TIME if on else HOVER_TIME
	if time <= 0.0 or is_equal_approx(_stand, wanted):
		_set_stand(wanted)
		return
	_stand_tween = create_tween()
	var turn := _stand_tween.tween_method(_set_stand, _stand, wanted, time)
	turn.set_trans(Tween.TRANS_SINE)
	turn.set_ease(Tween.EASE_IN_OUT)

func standing() -> bool:
	return _stand >= 1.0

## Der harte Schreiber im Lager: steht hochkant, der Rücken mittig auf at.
func stand_on(at: Vector3) -> void:
	set_standing(true)
	lie_on_glass(at)

func _set_stand(value: float) -> void:
	_stand = clampf(value, 0.0, 1.0)
	_apply_pose()

func _apply_pose() -> void:
	if _body == null:
		return
	if _stand <= 0.0:
		super._apply_pose()
		return
	var length := DataCellView.HEIGHT * FOOT_ROOM * _body_scale
	var depth := thickness() * _body_scale
	var rise := clampf(_hover_share / PRESENT_RISE_SHARE, 0.0, 1.0)
	var tip := smoothstep(PRESENT_RISE_SHARE, 1.0, _hover_share)
	var angle := PI * 0.5 * _stand * (1.0 - tip)
	var center := Vector3(0.0, depth * 0.5, 0.0).lerp(Vector3(0.0, -length * 0.5, 0.0), _stand)
	center.y += rise * (length + PRESENT_AIR) * _stand
	if tip > 0.0:
		# Gekippt liegt sie flach über dem Filz - nie mit einem Ende darunter.
		center.y = maxf(lerpf(center.y, depth * 0.5 + PRESENT_AIR, tip),
			length * 0.5 * sin(angle) + depth * 0.5 * cos(angle) + PRESENT_AIR)
	var turn := Basis(Quaternion.IDENTITY.slerp(_stand_turn(), _stand))
	var basis := Basis(Vector3.BACK, PI * 0.5 * tip) * turn * _lying_basis()
	var core := Vector3(0.0, 0.0, (thickness() - DataCellView.DEPTH) * 0.5)
	_body.transform = Transform3D(basis, center - basis * core)

## Die Drehung aus der Liege-Lage in den Stand: der Kopf nach oben, die Fläche nach lokal +X.
func _stand_turn() -> Quaternion:
	var lying := _lying_basis().orthonormalized()
	var source := Basis(lying.y, lying.z, lying.y.cross(lying.z))
	var target := Basis(Vector3.UP, Vector3.RIGHT, Vector3.UP.cross(Vector3.RIGHT))
	return Quaternion(target * source.inverse())

## Die Lage, in der sie LIEGT (ohne Griff) - der Grundriß gilt für sie, nicht für den Stand.
func _lying_body_transform() -> Transform3D:
	return Transform3D(_lying_basis(), Vector3(0.0, DataCellView.DEPTH * 0.5 * _body_scale, 0.0))

## Die Rücken-Marke auf der Kopfseite: was von oben aus der Rinne liest.
func add_spine() -> void:
	if _spine != null or _cells.is_empty():
		return
	var width := DataCellView.WIDTH * FOOT_ROOM
	var depth := thickness()
	var y := DataCellView.HEIGHT * FOOT_ROOM * 0.5
	var z := (depth - DataCellView.DEPTH) * 0.5
	_spine = Node3D.new()
	_spine.name = "Spine"
	_cells[0].add_child(_spine)
	# Halb in der Kopfseite versenkt: keine Fläche teilt sie mit dem Gehäuse.
	TableProps.box(_spine, "Mark", Vector3(width * SPINE_WIDTH_SHARE, SPINE_PROUD * 2.0,
		depth * SPINE_DEPTH_SHARE), Vector3(0.0, y, z), _edge_material)
	if dice_pack:
		TableProps.box(_spine, "Quality", Vector3(width * SPINE_CORE_SHARE, SPINE_PROUD * 3.0,
			depth * SPINE_DEPTH_SHARE * 0.5), Vector3(0.0, y, z), case_metal())

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
	if module_bag:
		return _build_bag()
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
	_build_rims(cell, width, length, lid)
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
	_build_rims(cell, width, length, lid)
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

## Der Neon-Saum um die Deckelkante: steht um RIM_PROUD über die Gehäuseseiten vor - bündig
## stritten Saum und Gehäuse im Tiefenpuffer (Flimmern an der Kante).
func _build_rims(cell: Node3D, width: float, length: float, lid: float) -> void:
	var rim := width * RIM_SHARE
	var rim_z := lid - rim * 0.5 + LID_PROUD
	var outer := Vector2(width, length) + Vector2.ONE * RIM_PROUD * 2.0
	TableProps.box(cell, "RimLeft", Vector3(rim, outer.y, rim),
		Vector3(-(outer.x - rim) * 0.5, 0.0, rim_z), _edge_material)
	TableProps.box(cell, "RimRight", Vector3(rim, outer.y, rim),
		Vector3((outer.x - rim) * 0.5, 0.0, rim_z), _edge_material)
	TableProps.box(cell, "RimTop", Vector3(outer.x, rim, rim),
		Vector3(0.0, (outer.y - rim) * 0.5, rim_z), _edge_material)
	TableProps.box(cell, "RimFoot", Vector3(outer.x, rim, rim),
		Vector3(0.0, -(outer.y - rim) * 0.5, rim_z), _edge_material)

## Klein schlicht, Normal ein Stahlband, Groß ein Stahlrahmen ums Fenster, Riesig dazu Goldecken.
func _build_cassette_trim(cell: Node3D, width: float, length: float, depth: float,
		bottom: float, window: Vector2, window_y: float, face_z: float) -> void:
	if card_pack_size == CardPack.SIZE_NORMAL:
		# Das Band endet IN den Säumen und bleibt unter ihrer Oberkante - keine gemeinsame Fläche.
		var rim := width * RIM_SHARE
		var band_h := LID_PROUD * 0.7
		TableProps.box(cell, "Band", Vector3(width - rim, length * 0.06, band_h),
			Vector3(0.0, -length * 0.33, face_z - (LID_PROUD - band_h) * 0.5), _steel_material)
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
		# Die Ecken überragen Saum und Naht nach oben wie zur Seite - nie bündig mit ihnen.
		var reach := depth + LID_PROUD * 2.5
		var i := 0
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				TableProps.box(cell, "Corner%d" % i, Vector3(corner.x + SEAM_PROUD * 3.0,
					corner.y + SEAM_PROUD * 3.0, reach), Vector3(sx * (width - corner.x) * 0.5,
					sy * (length - corner.y) * 0.5, bottom + reach * 0.5 - LID_PROUD),
					_gold_material)
				i += 1

## Der ESD-BEUTEL: flache Folie mit gewölbter Mitte, oben die Siegelnaht mit Rillen (sie
## reißt ab), darunter der Stufen-Streifen, auf der Wölbung das schwarze Etikett. Gebaut im
## BILD-Rahmen: der liegende Grundriß ist quer, Bild-oben ist die Zelle +x, Bild-rechts -y.
func _build_bag() -> Node3D:
	var cell := Node3D.new()
	cell.name = "Hull%d" % _cells.size()
	var wide := DataCellView.HEIGHT * FOOT_ROOM
	var high := DataCellView.WIDTH * FOOT_ROOM
	var depth := thickness()
	var bottom := -DataCellView.DEPTH * 0.5
	_shell_material.albedo_color = BAG_ALBEDO
	_shell_material.metallic = 0.35
	_shell_material.roughness = 0.32
	_shell_material.emission = BAG_GLOW
	_shell_material.emission_energy_multiplier = BAG_GLOW_ENERGY
	var seal := high * BAG_SEAL_SHARE
	var body_h := high - seal
	var body_y := -seal * 0.5
	var film := depth * BAG_FILM_SHARE
	_bag_box(cell, "Film", Vector2(wide, body_h), film, Vector2(0.0, body_y), bottom,
		_shell_material)
	var bulge := Vector2(wide, body_h) * BAG_BULGE_SHARE
	var bulge_y := body_y - body_h * (1.0 - BAG_BULGE_SHARE) * 0.3
	_bag_box(cell, "Bulge", bulge, depth, Vector2(0.0, bulge_y), bottom, _shell_material)
	# Die Siegelnaht: dünner als die Folie, die Quetschrillen stehen um LID_PROUD vor.
	var strip := Node3D.new()
	strip.name = "TearStrip"
	cell.add_child(strip)
	var seal_h := film * 0.7
	var seal_y := high * 0.5 - seal * 0.5
	_bag_box(strip, "Seal", Vector2(wide, seal), seal_h, Vector2(0.0, seal_y), bottom,
		_shell_material)
	for i in BAG_RIDGES:
		var y := high * 0.5 - seal * (float(i) + 0.5) / float(BAG_RIDGES)
		_bag_box(strip, "Ridge%d" % i, Vector2(wide * 0.98, seal / float(BAG_RIDGES) * 0.4),
			seal_h + LID_PROUD, Vector2(0.0, y), bottom, _steel_material)
	if _cells.is_empty():
		_tear_strip = strip
		_tear_rest = strip.transform
		_apply_torn()
	# Der STREIFEN der Stufe unter der Naht - er trägt Hover und Flare.
	var stripe := high * BAG_STRIPE_SHARE
	var stripe_y := high * 0.5 - seal - stripe * 0.9
	_bag_box(cell, "Stripe", Vector2(wide * 0.999, stripe), film + LID_PROUD,
		Vector2(0.0, stripe_y), bottom, _edge_material)
	# Die REISSKERBE rechts, auf der Linie zwischen Naht und Streifen.
	var notch := high * BAG_NOTCH_SHARE
	var cut := _bag_box(cell, "Notch", Vector2(notch, notch), film + LID_PROUD * 2.0,
		Vector2(wide * 0.5, high * 0.5 - seal), bottom - LID_PROUD, _label_material())
	if cut != null:
		cut.rotation.z = PI * 0.25
	# Das ETIKETT auf der Wölbung: Warndreieck, „ESD“ und die Kontakte.
	var top := bottom + depth
	var label := Vector2(bulge.x * BAG_LABEL_SHARE.x, bulge.y * BAG_LABEL_SHARE.y * 2.0)
	var label_c := Vector2(0.0, bulge_y)
	_bag_box(cell, "Label", label, LID_PROUD, label_c, top, _label_material())
	var face := top + LID_PROUD
	var row_y := label_c.y + label.y * 0.16
	var warn := MeshInstance3D.new()
	warn.name = "Warning"
	var prism := PrismMesh.new()
	prism.size = Vector3(label.y * 0.42, label.y * 0.38, LID_PROUD)
	warn.mesh = prism
	warn.material_override = _warn_material()
	warn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warn.rotation.z = -PI * 0.5
	warn.position = _bag_point(Vector2(-label.x * 0.27, row_y), face + LID_PROUD * 0.5)
	cell.add_child(warn)
	var text := Label3D.new()
	text.name = "Esd"
	text.text = "ESD"
	text.font_size = 64
	text.pixel_size = high * BAG_TEXT_SHARE / 64.0 * 1.6
	text.modulate = BAG_WARN
	text.outline_size = 0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.render_priority = _prio(PRIORITY_NET)
	text.rotation.z = -PI * 0.5
	text.position = _bag_point(Vector2(label.x * 0.12, row_y), face + LID_PROUD * 0.2)
	cell.add_child(text)
	var contacts := CardPack.option_count(card_pack_size)
	var side := high * BAG_CONTACT_SHARE
	var span := label.x * 0.7
	for i in contacts:
		var x := -span * 0.5 + span * (float(i) + 0.5) / float(contacts)
		_bag_box(cell, "Contact%d" % i, Vector2(side, side), LID_PROUD,
			Vector2(x, label_c.y - label.y * 0.27), face, _gold_material)
	return cell

## Ein Bild-Punkt (rechts, oben) in der Zelle - Bild-oben ist +x, Bild-rechts -y.
static func _bag_point(screen: Vector2, z: float) -> Vector3:
	return Vector3(screen.y, -screen.x, z)

## Eine Box im Bild-Rahmen, ihre Unterseite auf z_bottom.
func _bag_box(host: Node3D, box_name: String, screen_size: Vector2, height: float,
		center: Vector2, z_bottom: float, material: Material) -> MeshInstance3D:
	return TableProps.box(host, box_name, Vector3(screen_size.y, screen_size.x, height),
		_bag_point(center, z_bottom + height * 0.5), material)

var _bag_label_material: StandardMaterial3D
var _bag_warn_material: StandardMaterial3D

func _label_material() -> StandardMaterial3D:
	if _bag_label_material == null:
		_bag_label_material = StandardMaterial3D.new()
		_bag_label_material.albedo_color = BAG_LABEL_ALBEDO
		_bag_label_material.roughness = 0.6
	return _bag_label_material

func _warn_material() -> StandardMaterial3D:
	if _bag_warn_material == null:
		_bag_warn_material = _lit_material(BAG_WARN)
		_bag_warn_material.emission_energy_multiplier = 0.8
	return _bag_warn_material

## Der Beutel REISST an der Kerbe auf: der Siegelstreifen hebt ab, kippt nach rechts
## und vergeht. Endzustand zuerst - gerissen ist er sofort; zurück kommt die Dauer.
func tear_open(time := TEAR_TIME) -> float:
	_torn = true
	_kill(_tear_tween)
	if _tear_strip == null or not is_instance_valid(_tear_strip) or time <= 0.0:
		_apply_torn()
		return 0.0
	_tear_strip.visible = true
	_tear_tween = create_tween()
	_tear_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(_tear_strip):
			_tear_strip.transform = _tear_rest.translated_local(Vector3(TEAR_LIFT * t * 0.3,
				-TEAR_DRIFT * t, TEAR_LIFT * sin(t * PI) * 0.6)).rotated_local(
				Vector3.UP, TEAR_TILT * t)
			_tear_strip.scale = Vector3.ONE * maxf(1.0 - t * t, 0.01), 0.0, 1.0, time)
	_tear_tween.tween_callback(_apply_torn)
	return time

## Gerissen oder ganz - hart gesetzt.
func set_torn(on: bool) -> void:
	_torn = on
	_kill(_tear_tween)
	_apply_torn()

func torn() -> bool:
	return _torn

func _apply_torn() -> void:
	if _tear_strip == null or not is_instance_valid(_tear_strip):
		return
	_tear_strip.transform = _tear_rest
	_tear_strip.visible = not _torn

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
	var metal := case_metal()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var part := String(mesh.name)
		if part.begins_with("Naht"):
			mesh.material_override = _seam_material()
		elif part.begins_with("Deckel") or part.begins_with("Boden"):
			# Außen Lack, innen der Samt - je Fläche nach ihrem Blender-Material.
			for i in mesh.mesh.get_surface_count():
				var source := mesh.mesh.surface_get_material(i)
				var velvet := source != null and source.resource_name.begins_with("Samt")
				mesh.set_surface_override_material(i,
					_velvet_material() if velvet else _shell_material)
		elif part != "SchliesseMulde" and not part.begins_with("AugeMulde"):
			mesh.material_override = metal
	if _cells.is_empty():
		_case_model = model
		_hinge = model.find_child("Scharnier", true, false) as Node3D
		if _hinge != null:
			_hinge_rest = _hinge.transform
			_apply_lid()
	_show_pips(model)
	set_process(_royal_seam != null)
	return cell

## Das Metall der Güte: Stahl, Gold oder dunkles Royal-Chrom mit violettem Schimmer.
func case_metal() -> StandardMaterial3D:
	if _case_metal != null:
		return _case_metal
	match quality:
		DicePack.QUALITY_FINE:
			_case_metal = _gold_material
		DicePack.QUALITY_ROYAL:
			_case_metal = _metal(ROYAL_ALBEDO, DicePack.quality_tint(DicePack.QUALITY_ROYAL), ROYAL_ENERGY)
			_case_metal.roughness = 0.12
		_:
			_case_metal = _metal(Color(0.62, 0.64, 0.7), Color(0.62, 0.64, 0.7), CASE_STEEL_ENERGY)
	return _case_metal

## Die Naht: Royal bekommt eine eigene, pulsende - die geteilte Kante gehört Hover und Flare.
func _seam_material() -> StandardMaterial3D:
	if quality != DicePack.QUALITY_ROYAL:
		return _edge_material
	if _royal_seam == null:
		_royal_seam = _edge_material.duplicate() as StandardMaterial3D
	return _royal_seam

## Die Grundzahl auf dem Deckel (2-5) - eine Auswahl mit Beigabe setzt sie nach.
func set_pips(count: int) -> void:
	pips = clampi(count, 2, 5)
	if _case_model != null and is_instance_valid(_case_model):
		_show_pips(_case_model)

func shown_pips() -> int:
	return pips

func _show_pips(model: Node3D) -> void:
	var shown: Array = CASE_PIPS[clampi(pips, 2, 5)]
	for mesh: MeshInstance3D in model.find_children("Auge*", "MeshInstance3D", true, false):
		var part := String(mesh.name)
		var index := part.trim_prefix("AugeMulde") if part.begins_with("AugeMulde") \
			else part.trim_prefix("Auge")
		if index.is_valid_int():
			mesh.visible = int(index) in shown

func _process(delta: float) -> void:
	if _royal_seam == null:
		set_process(false)
		return
	_pulse_time += delta
	_royal_seam.emission_energy_multiplier = edge_rest_energy() \
		* (1.0 + ROYAL_PULSE_DEPTH * sin(_pulse_time * ROYAL_PULSE_RATE))

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
	var half := Vector2(DataCellView.WIDTH, DataCellView.HEIGHT) * FOOT_ROOM * 0.5
	if module_bag:
		return _bag_corners(half)
	return _case_corners(half, 0.0)

## Der Beutel hat kein Modell: seine Ecken liegen in der Zelle selbst (x Breite, y Länge).
func _bag_corners(half: Vector2) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _cells.is_empty():
		return out
	var to_self := Transform3D()
	var node: Node = _cells[0]
	while node != null and node != self:
		to_self = _pose_free(node) * to_self
		node = node.get_parent()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		out.append(to_self * Vector3(half.x * corner.x, half.y * corner.y,
			-DataCellView.DEPTH * 0.5))
	return out

func _case_corners(half_raw: Vector2, height: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _case_model == null or not is_instance_valid(_case_model):
		return out
	var to_self := Transform3D()
	var node: Node = _case_model
	while node != null and node != self:
		to_self = _pose_free(node) * to_self
		node = node.get_parent()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		# Blender (x, y, z) liegt im glTF als (x, z, -y).
		out.append(to_self * Vector3(half_raw.x * corner.x, height, -half_raw.y * corner.y))
	return out

## Die Hälften des Innenraums im Roh-Maß (Blender X = Breite, Y = Länge).
static func case_inner_half() -> Vector2:
	return Vector2(DataCellView.WIDTH * FOOT_ROOM * 0.5 - CASE_WALL,
		DataCellView.HEIGHT * FOOT_ROOM * 0.5 - CASE_WALL)

## Die Lage eines Knotens für den Grundriß: der Körper zählt immer LIEGEND.
func _pose_free(node: Node) -> Transform3D:
	return _lying_body_transform() if node == _body else (node as Node3D).transform
