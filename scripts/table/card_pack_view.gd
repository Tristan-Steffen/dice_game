class_name CardPackView
extends DataCellView
## Der Körper eines PAKETS, eine Spur größer als die liegende Karte. Ein KARTEN-Paket kommt
## seit dem 2026-11-20 aus der Welt seines Datenträgers (Spieler-Wahl aus je drei Entwürfen,
## tools/blender_card_pack_media.py, Export tools/blender_card_pack_export.py): Zahlen die
## LOCHTASCHE (Manila, schräg aufgeschnitten, die Kartenzahl als Stanzlöcher), Material das
## KASSETTENFACH (Rauchglas-Klappe, Laufwerkstasten), Runen die TONHÜLLE (aufgebrochen,
## leuchtende Keile, Siegel), Sonder der BLISTER (Euro-Loch, klare Haube). Darin liegen
## ECHTE Data-Cards; die VORDERSTE ist die Karte, die das Paket garantiert (CardPack.front).
## Ein WÜRFEL-Paket ist die
## SCHALE (Spieler-Wahl 2026-11-16, tools/blender_dice_tray_export.py): sechs Mulden in der
## Sortenfarbe unter einer Klarsicht-Haube, darin so viele Würfel wie die Grundzahl - leere
## Mulden bleiben sichtbar -, am Fuß eine Banderole mit Name und Augen, die Güte als
## Prägefolie. Bewegt wird sie wie eine Karte.
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
## EINE Dicke für jedes Karten-Paket, so dick wie die Schale.
const CASSETTE_THICKNESS := DICE_THICKNESS
## Je Sorte und Kartenzahl ein Modell (Roh-Maß der Zelle, Ursprung = Mitte der Grundfläche).
const PACK_SCENE := "res://assets/models/hardware/card_pack_%s_%d.glb"
## Die TREPPE der Karten je Sorte, im Roh-Maß des Modells: Kartenmaßstab, Mitte längs,
## Oberkante ("top") oder Unterkante ("bottom") des Stapels über dem Paketboden, Teilung
## ("pitch", sonst die Dicke des Trägers), Platz in der Höhe ("room" - mehr Karten liegen
## flacher) und Versatz je Karte zum Fuß ("step").
const STAIRS := {
	CardPack.SORT_NUMBER: {"scale": 0.9, "y": 0.0, "top": 0.448},
	CardPack.SORT_MATERIAL: {"scale": 0.72, "y": 0.17, "bottom": 0.024, "room": 0.44},
	CardPack.SORT_RUNE: {"scale": 0.72, "y": 0.2, "top": 0.409, "room": 0.359},
	CardPack.SORT_SPECIAL: {"scale": 0.68, "y": -0.2, "bottom": 0.14, "pitch": 0.055,
		"step": 0.025},
}
## Anthrazit statt Schwarz: auf dem dunklen Tisch las Schwarz als Loch (Spieler-Wunsch).
const BOARD_ALBEDO := Color(0.2, 0.2, 0.23)
const BOARD_GLOW_ENERGY := 0.35
## Eigenlicht der übrigen Flächen (Manila, Ton, Papier): auf dem Tisch beleuchtet sie nichts.
const PLAIN_GLOW_ENERGY := 0.5
const FILM_ALBEDO := Color(0.85, 0.9, 1.0, 0.08)
const SMOKE_ALBEDO := Color(0.1, 0.1, 0.13, 0.32)
const BLACK_INK := Color(0.012, 0.012, 0.014)
## Die GÜTE ist die PRÄGEFOLIE: Standard weißer Druck, Edel Silber, Royal Gold.
const FOIL_ALBEDOS := [Color(0.92, 0.92, 0.92), Color(0.9, 0.9, 0.92), Color(0.96, 0.77, 0.4)]
const FOIL_METALLICS := [0.0, 0.7, 0.7]
const FOIL_ROUGHNESSES := [0.5, 0.22, 0.22]
const FOIL_ENERGIES := [0.3, 0.25, 0.3]
## Die GÜTE liest an JEDEM Karten- und Würfel-Paket gleich (Spieler-Wahl 2026-11-20):
## die SCHÄRPE über der Kopf-Ecke nennt sie (Edel silbern, Royal golden und breiter), und
## die MATERIALIEN der Hülle SCHIMMERN - ein Lichtstreif wandert darüber, silbern bzw.
## golden, Royal funkelt dazu. Standard trägt nichts davon. Je Paket: Höhe an der
## Kopf-Ecke über dem Boden (Roh-Maß).
const SASH_SEATS := {
	CardPack.SORT_NUMBER: CASSETTE_THICKNESS,
	CardPack.SORT_MATERIAL: CASSETTE_THICKNESS,
	CardPack.SORT_RUNE: CASSETTE_THICKNESS,
	CardPack.SORT_SPECIAL: 0.024,
}
const SASH_SEAT_DICE := DICE_THICKNESS + 0.002
const SASH_HEIGHT := 0.008
## Die Schärpe: Abstand ihrer Mitte von der Ecke und ihre Breite.
const SASH_REACH := [0.0, 0.3, 0.38]
const SASH_WIDTH := [0.0, 0.17, 0.23]
const SASH_NAMES := ["", "EDEL", "ROYAL"]
const SASH_INK := Color(0.07, 0.06, 0.05)
const QUALITY_TINTS := [Color(0.5, 0.5, 0.5), Color(0.86, 0.9, 1.0), Color(1.0, 0.76, 0.28)]
const QUALITY_ENERGIES := [0.0, 0.9, 1.05]
const SHIMMER_SHADER := "res://assets/shaders/pack_shimmer.gdshader"
const SHIMMER_STRENGTH := [0.0, 0.34, 0.5]
const SHIMMER_GLITTER := [0.0, 0.0, 0.9]
var _quality_material: StandardMaterial3D
var _sash_ink: StandardMaterial3D
var _shimmer: ShaderMaterial
var _cassette_model: Node3D
var _film: StandardMaterial3D
var _smoke: StandardMaterial3D
var _foil: StandardMaterial3D
var _black_ink: StandardMaterial3D
var _graphite: StandardMaterial3D
var _plain := {}
var _stair: Array[DataCellView] = []
var _stair_holders: Array[Node3D] = []

## Die SCHALE: EIN Modell für jedes Würfel-Paket; Godot zeigt je Paket die passenden Teile.
const DICE_CASE_SCENE := "res://assets/models/hardware/dice_tray.glb"
const DICE_THICKNESS := DataCellView.DEPTH * 3.2
## Die Schale in der Sortenfarbe: glänzender Kunststoff mit etwas Eigenlicht.
const TRAY_ENERGY := 0.35
## Die Würfel der Mulden: dunkler Körper, leuchtende Ziffer, die obere Seite spricht die Sorte.
const TRAY_DIE_ALBEDO := Color(0.03, 0.03, 0.045)
const TRAY_DIGIT := Color(1.0, 0.97, 0.92)
const TRAY_DIGIT_SOUL := Color(0.9, 0.84, 1.0)
const TRAY_DIGIT_ENERGY := 2.2
const TRAY_EDGE_TINTS := {DicePack.SORT_NORMAL: Color("#cfe6ff"),
	DicePack.SORT_SOUL: Color("#b47bff")}
const TRAY_EDGE_ENERGIES := {DicePack.SORT_NORMAL: 1.2, DicePack.SORT_SOUL: 3.0}
## Je Mulde ein Material bzw. eine Rune, in der Reihenfolge des Modells (Rubin, Gold, Glas,
## Bernstein, Kupfer, Knochen; Ring, Dreieck, Quadrat, Stern, Raute, Ring).
const TRAY_MATERIAL_TINTS := [Color("#e0115f"), Color("#f2c14e"), Color("#9fdcff"),
	Color("#ffa20a"), Color("#d07a3c"), Color("#e6dcc2")]
const TRAY_MATERIAL_ENERGIES := [0.6, 0.4, 0.5, 0.6, 0.3, 0.0]
const TRAY_RUNE_TINTS := [Color("#ffffff"), Color("#ffc23a"), Color("#ff7a1f"),
	Color("#35e8ff"), Color("#b77bff"), Color("#ffffff")]
const TRAY_RUNE_ENERGY := 3.0
static var _dice_case_scenes := {}
## Das STANGENMAGAZIN des Modul-Pakets: EIN Modell für jede Größe und Stufe, für alle gleich dick.
const MODULE_CASE_SCENE := "res://assets/models/hardware/module_tubes.glb"
const MODULE_CASE_THICKNESS := DataCellView.DEPTH * 3.0
const CASE_MODULE := Color(0.17, 0.17, 0.22)
const CASE_MODULE_GLOW := 0.55
const CASE_DARK := Color(0.03, 0.03, 0.04)
const CASE_PAPER := Color(0.85, 0.86, 0.9)
const TUBE_GLASS := Color(0.7, 0.86, 1.0, 0.17)
const TUBE_RIM := Color(0.75, 0.9, 1.0, 0.5)
## Das ÖFFNEN: die rechte Kappe zieht nach Bild-rechts ab und vergeht.
const TEAR_TIME := 0.45
const CAP_PULL := 0.6
## Die STUFE liest wie die Güte der anderen Pakete: Schärpe über der Kopf-Ecke und Schimmer.
const GRADE_SASH_NAMES := ["", "SELTEN", "EPISCH", "LEGENDÄR"]
const GRADE_SASH_REACH := [0.0, 0.34, 0.37, 0.4]
const GRADE_SASH_WIDTH := [0.0, 0.17, 0.19, 0.22]
const GRADE_SASH_ENERGY := [0.0, 0.9, 0.9, 0.85]
const GRADE_SHIMMER := [0.0, 0.3, 0.4, 0.5]
const GRADE_GLITTER := [0.0, 0.0, 0.0, 0.9]
var _case_model: Node3D
var _tray: StandardMaterial3D
var _tray_materials := {}
var _tray_dice: Array[MeshInstance3D] = []
var _case_materials := {}
var _lid := 0.0
## Ein Modul-Paket (das Stangenmagazin) und seine Seltenheits-Stufe.
var module_bag := false
var grade: int = ModulePack.GRADE_COMMON
var _tear_strip: Node3D
var _tear_rest := Transform3D()
var _tear_tween: Tween
var _torn := false
var card_pack_sort: String = CardPack.SORT_NUMBER
var card_pack_size: int = CardPack.SIZE_NORMAL
## Die vorderste Karte eines Karten-Pakets (null = eine leere Karte seiner Sorte).
var front: Pack
## Ein Würfel-Paket (dieselbe Hülle, andere Kennung).
var dice_pack := false
## Die Güte (Würfel- und Karten-Paket): die Prägefolie.
var quality: int = DicePack.QUALITY_STANDARD
## Augen der Würfel-Kennung: eine Würfelseite mit drei Augen.
const PIP_SIZE := DataCellView.HEIGHT * 0.06
const DIE_FACE_SHARE := 0.5
var _stripe_materials: Array[StandardMaterial3D] = []
var _steel_material: StandardMaterial3D
var _gold_material: StandardMaterial3D

func _init() -> void:
	name = "CardPack"

## Einziger Eingang: baut die Hülle eines Pakets dieser Sorte und Größe (Würfel: und Güte).
func setup_pack(pack_sort: String, pack_size: int, dice := false,
		pack_quality := DicePack.QUALITY_STANDARD, front_card: Pack = null) -> void:
	front = front_card
	card_pack_sort = pack_sort
	card_pack_size = pack_size
	dice_pack = dice
	quality = clampi(pack_quality, DicePack.QUALITY_STANDARD, DicePack.QUALITY_ROYAL)
	sort = pack_sort
	tint = PackDrawerView.dice_pack_tint(pack_sort) if dice \
		else PackDrawerView.card_pack_tint(pack_sort)
	_finish_setup()

## Das STANGENMAGAZIN eines Modul-Pakets dieser Größe und Stufe.
func setup_module_bag(pack_size: int, pack_grade: int) -> void:
	module_bag = true
	dice_pack = false
	card_pack_size = pack_size
	grade = clampi(pack_grade, ModulePack.GRADE_COMMON, ModulePack.GRADE_LEGENDARY)
	card_pack_sort = ""
	sort = ""
	tint = ModulePack.TINT
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
	return maxf(DICE_THICKNESS, CASSETTE_THICKNESS) * cell_scale

func thickness() -> float:
	if module_bag:
		return MODULE_CASE_THICKNESS
	if dice_pack:
		return DICE_THICKNESS if dice_case_model() != null else THICKNESS
	return CASSETTE_THICKNESS

func rise_depth() -> float:
	return thickness() * _body_scale

## Die Lage, in der sie LIEGT (ohne Griff) - der Grundriß gilt für sie, nicht für den Stand.
func _lying_body_transform() -> Transform3D:
	return Transform3D(_lying_basis(), Vector3(0.0, DataCellView.DEPTH * 0.5 * _body_scale, 0.0))

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

func _build_cassette_materials() -> void:
	if not module_bag:
		# Schwarz bedruckter, laminierter Karton - ein Rest Eigenlicht, sonst läse er als Loch.
		_shell_material.albedo_color = BOARD_ALBEDO
		_shell_material.metallic = 0.0
		_shell_material.roughness = 0.38
		_shell_material.emission = BOARD_ALBEDO
		_shell_material.emission_energy_multiplier = BOARD_GLOW_ENERGY
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

## Das KARTEN-PAKET: die Hülle seiner Sorte aus Blender, darin die Treppe der Karten.
func _build_cassette() -> Node3D:
	var cell := Node3D.new()
	cell.name = "Hull%d" % _cells.size()
	var scene := pack_model(card_pack_sort, CardPack.option_count(card_pack_size))
	if scene == null:
		# Ohne Import: ein schlichtes Gehäuse, damit nichts fehlt.
		TableProps.box(cell, "Shell", Vector3(DataCellView.WIDTH * FOOT_ROOM,
			DataCellView.HEIGHT * FOOT_ROOM, thickness()), Vector3(0.0, 0.0,
			-DataCellView.DEPTH * 0.5 + thickness() * 0.5), _shell_material)
		return cell
	var model := scene.instantiate() as Node3D
	model.name = "Cassette"
	# Blender baut Z nach oben, die Zelle liest Z als Höhe: +90° um X stellt es gleich.
	model.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	model.position = Vector3(0.0, 0.0, -DataCellView.DEPTH * 0.5)
	cell.add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.material_overlay = _shimmer_material()
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface,
				_pack_material(mesh.mesh.surface_get_material(surface)))
	if _cells.is_empty():
		_cassette_model = model
	_build_stair(cell)
	_build_quality_sash(cell, float(SASH_SEATS.get(card_pack_sort, CASSETTE_THICKNESS)))
	return cell

## Die SCHÄRPE: ein Band schräg über die Kopf-Ecke (Bild-oben-links), darauf der Name der
## Güte; Royal ist breiter und trägt zwei dunkle Säume. seat = Höhe der Ecke über dem Boden.
func _build_quality_sash(cell: Node3D, seat: float) -> void:
	if quality <= DicePack.QUALITY_STANDARD:
		return
	var foot := Vector2(DataCellView.WIDTH, DataCellView.HEIGHT) * FOOT_ROOM * 0.5
	var reach: float = SASH_REACH[quality]
	var width: float = SASH_WIDTH[quality]
	var band := Node3D.new()
	band.name = "QualitySash"
	cell.add_child(band)
	band.position = Vector3(foot.x - reach * 0.7071, foot.y - reach * 0.7071,
		-DataCellView.DEPTH * 0.5 + seat + 0.002)
	band.rotation.z = -PI * 0.25
	var length := reach * 2.0 - width
	TableProps.box(band, "Band", Vector3(length, width, SASH_HEIGHT),
		Vector3(0.0, 0.0, SASH_HEIGHT * 0.5), _quality_sash_material())
	if quality >= DicePack.QUALITY_ROYAL:
		for side in [-1.0, 1.0]:
			TableProps.box(band, "Seam", Vector3(length, width * 0.07, 0.003),
				Vector3(0.0, side * width * 0.38, SASH_HEIGHT + 0.0015), _sash_ink_material())
	var text := Label3D.new()
	text.name = "Name"
	text.text = SASH_NAMES[quality]
	text.font_size = 64
	text.pixel_size = width * 0.5 / 64.0
	text.modulate = SASH_INK
	text.outline_size = 0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.render_priority = _prio(PRIORITY_NET)
	text.position = Vector3(0.0, 0.0, SASH_HEIGHT + 0.004)
	band.add_child(text)

## Silber bzw. Gold, selbstleuchtend: auf dem dunklen Tisch muß die Güte von weitem lesen.
func _quality_sash_material() -> StandardMaterial3D:
	if _quality_material == null:
		_quality_material = StandardMaterial3D.new()
		_quality_material.albedo_color = QUALITY_TINTS[quality]
		_quality_material.metallic = 0.6
		_quality_material.roughness = 0.25
		_quality_material.emission_enabled = true
		_quality_material.emission = QUALITY_TINTS[quality]
		_quality_material.emission_energy_multiplier = QUALITY_ENERGIES[quality]
	return _quality_material

func _sash_ink_material() -> StandardMaterial3D:
	if _sash_ink == null:
		_sash_ink = StandardMaterial3D.new()
		_sash_ink.albedo_color = SASH_INK
		_sash_ink.roughness = 0.6
	return _sash_ink

## Der SCHIMMER der Hülle (null bei Standard): ein Overlay über allen ihren Flächen.
func _shimmer_material() -> ShaderMaterial:
	if quality <= DicePack.QUALITY_STANDARD or not ResourceLoader.exists(SHIMMER_SHADER):
		return null
	if _shimmer == null:
		_shimmer = ShaderMaterial.new()
		_shimmer.shader = load(SHIMMER_SHADER) as Shader
		_shimmer.set_shader_parameter("tint", QUALITY_TINTS[quality])
		_shimmer.set_shader_parameter("strength", SHIMMER_STRENGTH[quality])
		_shimmer.set_shader_parameter("glitter", SHIMMER_GLITTER[quality])
		_shimmer.render_priority = _prio(PRIORITY_PANE)
	return _shimmer

## Das Material einer Fläche nach dem NAMEN ihres Blender-Materials.
func _pack_material(source: Material) -> Material:
	var part := String(source.resource_name) if source != null else ""
	if part.begins_with("Tinte_"):
		return _edge_material
	if part.begins_with("Sorte_"):
		return _core_material
	if part.begins_with("Praegung"):
		# Auf hellem Manila ist der Standard-Druck schwarz statt weiß.
		return _black_ink_material() if card_pack_sort == CardPack.SORT_NUMBER \
			and quality == DicePack.QUALITY_STANDARD else _foil_material()
	if part.begins_with("MetallGuete"):
		return [_graphite_material(), _steel_material, _gold_material][quality]
	if part.begins_with("Klar_Rauchglas"):
		return _smoke_material()
	if part.begins_with("Klar"):
		return _film_material()
	if part.begins_with("Kunststoff") or part.begins_with("Karton"):
		return _shell_material
	if part.begins_with("TinteSchwarz") or part.begins_with("Stempeltinte"):
		return _black_ink_material()
	return _plain_material(part, source)

## Jede übrige Fläche behält ihre Blender-Farbe und bekommt etwas Eigenlicht.
func _plain_material(part: String, source: Material) -> StandardMaterial3D:
	if not _plain.has(part):
		var material := StandardMaterial3D.new()
		var base := source as BaseMaterial3D
		material.albedo_color = base.albedo_color if base != null else BOARD_ALBEDO
		material.roughness = base.roughness if base != null else 0.8
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = PLAIN_GLOW_ENERGY
		_plain[part] = material
	return _plain[part]

## Die TREPPE: eine echte Karte je Option. Die VORDERSTE (oberste) ist die Karte des
## Pakets mit ihrem Netz, die übrigen sind leer - ihr Inhalt fällt erst beim Öffnen.
## Nur die erste Hülle trägt sie - ein Stapel zeigt nur sie.
func _build_stair(cell: Node3D) -> void:
	if not _cells.is_empty():
		return
	_stair.clear()
	_stair_holders.clear()
	var count := CardPack.option_count(card_pack_size)
	var shelf := stair_shelf(card_pack_sort)
	var layout: Dictionary = STAIRS.get(card_pack_sort, STAIRS[CardPack.SORT_NUMBER])
	# Die Karte LIEGT in ihrem eigenen Rahmen; diese Drehung legt ihren in den der Hülle.
	var into_cell := (Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, PI * 0.5)).inverse()
	for i in count:
		var holder := Node3D.new()
		holder.name = "StairCard%d" % i
		cell.add_child(holder)
		holder.transform = stair_pose(card_pack_sort, i, count)
		var card := DataCellView.new()
		card.name = "Card"
		holder.add_child(card)
		if i == count - 1 and front != null:
			card.setup(Pack.shelf_of(front), front.tier, front.stamp_net)
		else:
			card.setup(shelf, Pack.TIER_NORMAL)
		card.transform = Transform3D(into_cell, Vector3.ZERO)
		card.set_body_scale(float(layout["scale"]))
		# Die obere (die höchste i) zeichnet zuletzt - sonst stanzte jedes Netz durch.
		card.set_layer_depth(count - 1 - i)
		_stair_holders.append(holder)
		_stair.append(card)

## Die vorderste Karte der Treppe (null ohne Modell).
func front_cell() -> DataCellView:
	return _stair[_stair.size() - 1] if not _stair.is_empty() else null

## Die Regal-Sorte der Karten eines Pakets.
static func stair_shelf(pack_sort: String) -> String:
	if not CardPack.SORT_TYPES.has(pack_sort):
		return Pack.SHELF_SPECIAL
	return Pack.shelf_for_pack_type(String(CardPack.SORT_TYPES[pack_sort]))

## Der Platz der i-ten Karte im Paket (Zell-Rahmen, Ursprung der Karte = ihre Unterseite):
## die oberste ist die vorderste; reicht die Höhe nicht, liegen alle flacher.
static func stair_pose(pack_sort: String, index: int, count: int) -> Transform3D:
	var layout: Dictionary = STAIRS.get(pack_sort, STAIRS[CardPack.SORT_NUMBER])
	var card_scale := float(layout["scale"])
	var rank := maxi(Pack.SHELF_ORDER.find(stair_shelf(pack_sort)), 0)
	var thick := float(DataCellView.CARRIER_TOPS[rank]) * card_scale
	var pitch := float(layout.get("pitch", thick))
	if layout.has("room"):
		pitch = minf(pitch, float(layout["room"]) / float(maxi(count, 1)))
	var squash := minf(pitch / thick, 1.0)
	var bottom := float(layout["bottom"]) + pitch * float(index) if layout.has("bottom") \
		else float(layout["top"]) - thick * squash - pitch * float(count - 1 - index)
	var along := float(layout["y"]) \
		- (float(index) - float(count - 1) * 0.5) * float(layout.get("step", 0.0))
	return Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, squash)),
		Vector3(0.0, along, -DataCellView.DEPTH * 0.5 + bottom))

## Die Karten leuchten mit, wenn das Paket aufflammt.
func flare() -> void:
	super.flare()
	for card in _stair:
		if is_instance_valid(card):
			card.flare()

## Klarsichtfolie im Fenster: kaum Farbe, nur Glanz.
func _film_material() -> StandardMaterial3D:
	if _film == null:
		_film = StandardMaterial3D.new()
		_film.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_film.albedo_color = FILM_ALBEDO
		_film.roughness = 0.05
		_film.metallic_specular = 1.0
		_film.render_priority = _prio(PRIORITY_PANE)
	return _film

func _foil_material() -> StandardMaterial3D:
	if _foil == null:
		_foil = StandardMaterial3D.new()
		_foil.albedo_color = FOIL_ALBEDOS[quality]
		_foil.metallic = FOIL_METALLICS[quality]
		_foil.roughness = FOIL_ROUGHNESSES[quality]
		_foil.emission_enabled = true
		_foil.emission = FOIL_ALBEDOS[quality]
		_foil.emission_energy_multiplier = FOIL_ENERGIES[quality]
	return _foil

## Rauchglas über dem Kassettenfach.
func _smoke_material() -> StandardMaterial3D:
	if _smoke == null:
		_smoke = StandardMaterial3D.new()
		_smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke.albedo_color = SMOKE_ALBEDO
		_smoke.roughness = 0.05
		_smoke.metallic_specular = 1.0
		_smoke.render_priority = _prio(PRIORITY_PANE)
	return _smoke

## Graphit: das Metall der Standard-Güte.
func _graphite_material() -> StandardMaterial3D:
	if _graphite == null:
		_graphite = _metal(Color(0.3, 0.3, 0.34), Color(0.3, 0.3, 0.34), 0.25)
	return _graphite

func _black_ink_material() -> StandardMaterial3D:
	if _black_ink == null:
		_black_ink = StandardMaterial3D.new()
		_black_ink.albedo_color = BLACK_INK
		_black_ink.roughness = 0.5
	return _black_ink

## Die Folie zieht beim Ebenen-Versatz mit.
func _apply_layer_bias() -> void:
	super._apply_layer_bias()
	if _film != null:
		_film.render_priority = _prio(PRIORITY_PANE)
	if _smoke != null:
		_smoke.render_priority = _prio(PRIORITY_PANE)

## Das Blender-Modell eines Karten-Pakets (null = kein Import, dann das schlichte Gehäuse).
## Kein eigener Zwischenspeicher: der des ResourceLoaders hält es, solange ein Paket lebt
## - ein statischer hielte es bis nach dem Beenden (Godot meldet das als Leck).
static func pack_model(pack_sort: String, count: int) -> PackedScene:
	var path := PACK_SCENE % [pack_sort, clampi(count, 3, 5)]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene

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

## Das STANGENMAGAZIN (module_tubes.glb): drei antistatische Röhren zwischen zwei bedruckten
## Karton-Kappen; in den Röhren so viele Module, wie das Paket Optionen hat, auf der rechten
## Kappe zählen die Augen sie mit.
func _build_bag() -> Node3D:
	var cell := Node3D.new()
	cell.name = "Hull%d" % _cells.size()
	var scene := module_case_model()
	if scene == null:
		return cell
	var model := scene.instantiate() as Node3D
	model.name = "Case"
	# Blender baut Z nach oben, die Zelle liest Z als Höhe: +90° um X stellt es gleich.
	model.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	model.position = Vector3(0.0, 0.0, -DataCellView.DEPTH * 0.5)
	cell.add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dress_case_part(mesh)
	_build_grade_sash(cell)
	if _cells.is_empty():
		_case_model = model
		_tear_strip = model.find_child("Kappe", true, false) as Node3D
		if _tear_strip != null:
			_tear_rest = _tear_strip.transform
		_apply_torn()
	return cell

static func module_case_model() -> PackedScene:
	if not _dice_case_scenes.has(MODULE_CASE_SCENE) and ResourceLoader.exists(MODULE_CASE_SCENE):
		_dice_case_scenes[MODULE_CASE_SCENE] = load(MODULE_CASE_SCENE) as PackedScene
	return _dice_case_scenes.get(MODULE_CASE_SCENE) as PackedScene

## Wie viele Module in den Röhren liegen.
func case_modules() -> int:
	return CardPack.option_count(card_pack_size) if module_bag else 0

## Ein Teil des Magazins: zeigt es sich für dieses Paket, und was trägt es?
func _dress_case_part(mesh: MeshInstance3D) -> void:
	var part := String(mesh.name)
	var filled := part.right(1).is_valid_int() and part.right(1).to_int() < case_modules()
	if part.begins_with("Endkappe"):
		mesh.material_override = _shell_material
		mesh.material_overlay = _grade_shimmer()
	elif part.begins_with("Kappenband") or part == "Schrift":
		mesh.material_override = _edge_material
	elif part.begins_with("Auge"):
		mesh.material_override = _core_material if filled else _case_plain(CASE_DARK, 0.0)
	elif part == "CodeFeld":
		mesh.material_override = _case_plain(CASE_PAPER, 0.5)
	elif part == "Code":
		mesh.material_override = _case_plain(CASE_DARK, 0.0)
	elif part.begins_with("Rohrkante") or part.begins_with("Schiene"):
		mesh.material_override = _tube_material(TUBE_RIM, "rim")
	elif part.begins_with("Rohr"):
		mesh.material_override = _tube_material(TUBE_GLASS, "glass")
	elif part.begins_with("ModulLicht"):
		mesh.visible = filled
		mesh.material_override = _grade_light_material()
	elif part.begins_with("ModulGlas"):
		mesh.visible = filled
		mesh.material_override = _case_plain(CASE_DARK, 0.0)
	elif part.begins_with("Modul"):
		mesh.visible = filled
		mesh.material_override = _case_plain(CASE_MODULE, CASE_MODULE_GLOW)
	elif part.begins_with("Bein"):
		mesh.visible = filled
		mesh.material_override = _steel_material

## Die Farbe der Stufe (Gewöhnlich bis Legendär).
func grade_color() -> Color:
	return ModulePack.grade_tint(grade)

## Die LEDs der Module unter dem Glas leuchten in der Stufe - wie die Schulter-LED am Chip.
func _grade_light_material() -> StandardMaterial3D:
	if not _case_materials.has("grade"):
		_case_materials["grade"] = _lit_material(grade_color())
	return _case_materials["grade"]

func _grade_shimmer() -> ShaderMaterial:
	if grade <= ModulePack.GRADE_COMMON or not ResourceLoader.exists(SHIMMER_SHADER):
		return null
	if _shimmer == null:
		_shimmer = ShaderMaterial.new()
		_shimmer.shader = load(SHIMMER_SHADER) as Shader
		_shimmer.set_shader_parameter("tint", grade_color())
		_shimmer.set_shader_parameter("strength", GRADE_SHIMMER[grade])
		_shimmer.set_shader_parameter("glitter", GRADE_GLITTER[grade])
		_shimmer.render_priority = _prio(PRIORITY_PANE)
	return _shimmer

## Die SCHÄRPE über der Kopf-Ecke nennt die Stufe (Gewöhnlich trägt keine).
func _build_grade_sash(cell: Node3D) -> void:
	if grade <= ModulePack.GRADE_COMMON:
		return
	var foot := Vector2(DataCellView.WIDTH, DataCellView.HEIGHT) * FOOT_ROOM * 0.5
	var reach: float = GRADE_SASH_REACH[grade]
	var width: float = GRADE_SASH_WIDTH[grade]
	var band := Node3D.new()
	band.name = "QualitySash"
	cell.add_child(band)
	band.position = Vector3(foot.x - reach * 0.7071, foot.y - reach * 0.7071,
		-DataCellView.DEPTH * 0.5 + MODULE_CASE_THICKNESS + 0.012)
	band.rotation.z = -PI * 0.25
	var material := StandardMaterial3D.new()
	material.albedo_color = grade_color()
	material.metallic = 0.6
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = grade_color()
	material.emission_energy_multiplier = GRADE_SASH_ENERGY[grade]
	var length := reach * 2.0 - width
	TableProps.box(band, "Band", Vector3(length, width, SASH_HEIGHT),
		Vector3(0.0, 0.0, SASH_HEIGHT * 0.5), material)
	if grade >= ModulePack.GRADE_LEGENDARY:
		for side in [-1.0, 1.0]:
			TableProps.box(band, "Seam", Vector3(length, width * 0.07, 0.003),
				Vector3(0.0, side * width * 0.38, SASH_HEIGHT + 0.0015), _sash_ink_material())
	var text := Label3D.new()
	text.name = "Name"
	text.text = GRADE_SASH_NAMES[grade]
	text.font_size = 64
	text.pixel_size = width * 0.42 / 64.0
	text.modulate = SASH_INK
	text.outline_size = 0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.render_priority = _prio(PRIORITY_NET)
	text.position = Vector3(0.0, 0.0, SASH_HEIGHT + 0.004)
	band.add_child(text)

## Matte Fläche mit einem Rest Eigenlicht - der Tisch beleuchtet nichts.
func _case_plain(color: Color, glow: float) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), glow]
	if not _case_materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.45
		material.emission_enabled = glow > 0.0
		material.emission = color
		material.emission_energy_multiplier = glow
		_case_materials[key] = material
	return _case_materials[key]

## Antistatisches Rohr: klar mit einem Hauch Blau; die Kanten lesen etwas kräftiger.
func _tube_material(color: Color, key: String) -> StandardMaterial3D:
	if not _case_materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.08
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 0.25
		_case_materials[key] = material
	return _case_materials[key]

## Das Magazin ÖFFNET: die rechte Kappe zieht ab. Endzustand zuerst - offen ist es sofort;
## zurück kommt die Dauer.
func tear_open(time := TEAR_TIME) -> float:
	_torn = true
	_kill(_tear_tween)
	if _tear_strip == null or not is_instance_valid(_tear_strip) or time <= 0.0:
		_apply_torn()
		return 0.0
	_tear_tween = create_tween()
	_tear_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tear_tween.tween_method(_set_lid, 0.0, 1.0, time)
	return time

## Offen oder zu - hart gesetzt.
func set_torn(on: bool) -> void:
	_torn = on
	_kill(_tear_tween)
	_apply_torn()

func torn() -> bool:
	return _torn

## Wie weit die Kappe abgezogen ist (0 = sitzt, 1 = fort).
func lid_share() -> float:
	return _lid

func _set_lid(share: float) -> void:
	_lid = share
	if _tear_strip != null and is_instance_valid(_tear_strip):
		_tear_strip.transform = _tear_rest.translated_local(Vector3.RIGHT * CAP_PULL * share)
		_tear_strip.scale = Vector3.ONE * maxf(1.0 - share * share, 0.001)
		_tear_strip.visible = share < 0.999

func _apply_torn() -> void:
	_set_lid(1.0 if _torn else 0.0)

## Das Blender-Modell der Schale (null = kein Import, dann bleibt die alte Hülle).
static func dice_case_model() -> PackedScene:
	if not _dice_case_scenes.has(DICE_CASE_SCENE) and ResourceLoader.exists(DICE_CASE_SCENE):
		_dice_case_scenes[DICE_CASE_SCENE] = load(DICE_CASE_SCENE) as PackedScene
	return _dice_case_scenes.get(DICE_CASE_SCENE) as PackedScene

## Was die Schale QUER mißt (Roh-Maß) - daran messen Rinne, Laden-Platz und Öffnungs-Fläche.
static func max_case_across() -> float:
	return DataCellView.WIDTH * FOOT_ROOM

## Wie viele Mulden gefüllt sind: die Grund-Würfelzahl des Pakets.
static func case_pips(pack_size: int) -> int:
	return DicePack.base_count(pack_size)

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
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.material_overlay = _shimmer_material()
		_dress_tray_part(mesh)
	if _cells.is_empty():
		_case_model = model
	_build_quality_sash(cell, SASH_SEAT_DICE)
	return cell

## Ein Teil der Schale: zeigt es sich für dieses Paket, und was trägt es?
func _dress_tray_part(mesh: MeshInstance3D) -> void:
	var part := String(mesh.name)
	var count := case_pips(card_pack_size)
	if part.begins_with("AugeBand") or part.begins_with("AugeKopf"):
		mesh.visible = part.substr(8).begins_with("%d_" % count)
		# Am Kopf leuchten sie in der Sortenfarbe - dort liest das Lager.
		mesh.material_override = _edge_material if part.begins_with("AugeKopf") \
			else _black_ink_material()
	elif part.begins_with("Wuerfel") or part.begins_with("Ziffer") or part.begins_with("Deko"):
		var well := int(part.trim_prefix("Wuerfel").trim_prefix("Ziffer").trim_prefix("Deko")
			.substr(0, 1))
		mesh.visible = well < count and (not part.begins_with("Deko")
			or part.contains("_%s_" % card_pack_sort))
		mesh.material_override = _tray_die_material(part, well)
		_tray_dice.append(mesh)
	elif part.begins_with("Haube"):
		mesh.material_override = _film_material()
	elif part.begins_with("Schale") or part.begins_with("Muldenboden"):
		mesh.material_override = _tray_material()
	elif part.begins_with("Praegung"):
		mesh.material_override = _foil_material()
	elif part.begins_with("Druck"):
		mesh.material_override = _edge_material
	elif part.begins_with("SchwarzSorte_"):
		mesh.visible = part.ends_with("_" + card_pack_sort)
		mesh.material_override = _black_ink_material()
	elif part.begins_with("Schwarz"):
		mesh.material_override = _black_ink_material()
	else:
		# Boden und Banderole: schwarz laminierter Karton.
		mesh.material_override = _shell_material

## Die Schale in der Sortenfarbe.
func _tray_material() -> StandardMaterial3D:
	if _tray == null:
		_tray = StandardMaterial3D.new()
		_tray.albedo_color = tint
		_tray.roughness = 0.2
		_tray.clearcoat_enabled = true
		_tray.emission_enabled = true
		_tray.emission = tint
		_tray.emission_energy_multiplier = TRAY_ENERGY
	return _tray

## Was ein Teil des Mulden-Würfels trägt: Körper, Ziffer oder die Zeichnung seiner Sorte.
func _tray_die_material(part: String, well: int) -> StandardMaterial3D:
	var key := "body"
	var color := TRAY_DIE_ALBEDO
	var energy := 0.0
	var at := clampi(well, 0, TRAY_MATERIAL_TINTS.size() - 1)
	if part.begins_with("Ziffer"):
		key = "digit"
		color = TRAY_DIGIT_SOUL if card_pack_sort == DicePack.SORT_SOUL else TRAY_DIGIT
		energy = TRAY_DIGIT_ENERGY
	elif part.ends_with("Hof") or part.contains("RuneInnen"):
		pass
	elif part.contains("_Kante"):
		key = "edge"
		color = TRAY_EDGE_TINTS.get(card_pack_sort, TRAY_DIGIT)
		energy = TRAY_EDGE_ENERGIES.get(card_pack_sort, 1.2)
	elif part.contains("_Seite"):
		key = "face%d" % at
		color = TRAY_MATERIAL_TINTS[at]
		energy = TRAY_MATERIAL_ENERGIES[at]
	elif part.contains("_Rune"):
		key = "rune%d" % at
		color = TRAY_RUNE_TINTS[at]
		energy = TRAY_RUNE_ENERGY
	if not _tray_materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.3
		if energy > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = energy
		_tray_materials[key] = material
	return _tray_materials[key]

## Wie viele Würfel die Schale in ihren Mulden zeigt.
func tray_dice_shown() -> int:
	var shown := 0
	for mesh in _tray_dice:
		if is_instance_valid(mesh) and mesh.visible and String(mesh.name).begins_with("Wuerfel"):
			shown += 1
	return shown

# --- Der GRUNDRISS der Hülle --------------------------------------------------

## Der Außen-Grundriß auf der Unterseite im EIGENEN Raum der Hülle (ohne ihre Skalierung) -
## der Zuschnitt einer Sektion; der Aufrufer rechnet ihn auf jede Lage um.
func case_outline_local() -> Array[Vector3]:
	var half := Vector2(DataCellView.WIDTH, DataCellView.HEIGHT) * FOOT_ROOM * 0.5
	return _case_corners(half, 0.0)

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

## Die Lage eines Knotens für den Grundriß: der Körper zählt immer LIEGEND.
func _pose_free(node: Node) -> Transform3D:
	return _lying_body_transform() if node == _body else (node as Node3D).transform
