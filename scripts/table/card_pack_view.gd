class_name CardPackView
extends DataCellView
## Der Körper eines PAKETS (CardPack oder DicePack): EINE undurchsichtige Hülle für
## jede Art, Sorte und Größe, eine Spur größer als die liegende Karte. Sorte = Farbe von
## Siegel und Saum, Größe = Strich-Marken (1-4); ein Würfel-Paket trägt statt des
## Siegelbands eine Würfelseite mit Augen. Bewegt wird sie wie eine Karte - Hebebühne,
## Griff und Gleiten erbt sie von DataCellView.

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

## Wie hoch die liegende Hülle über ihrem Glaspunkt aufragt (cell_scale = Anzeigemaß).
static func lying_height(cell_scale: float) -> float:
	return THICKNESS * cell_scale

func rise_depth() -> float:
	return lying_height(_body_scale)

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
	if not dice_pack and card_pack_sort == CardPack.SORT_MIXED:
		for shelf: String in MIXED_STRIPES:
			var stripe := _lit_material(PackDrawerView.COLORS.get(shelf, tint))
			stripe.render_priority = _prio(PRIORITY_NET)
			_stripe_materials.append(stripe)

func _build_cell() -> Node3D:
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
