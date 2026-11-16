class_name CardPackView
extends DataCellView
## Der Körper eines PAKETS, eine Spur größer als die liegende Karte. Ein KARTEN-Paket ist
## seit dem 2026-11-16 eine bedruckte PAPPSCHACHTEL wie die eines RAM-Riegels (Spieler-Wahl
## "Retail", tools/blender_card_box_export.py): Euro-Lasche am Kopf, Sortenband, Prägefolie
## der GÜTE, Augen der Kartenzahl - und durch ein Fenster mit Klarsichtfolie sieht man ECHTE
## Data-Cards, fast so groß wie die Schachtel, also nie alle ganz. Ein WÜRFEL-Paket ist die
## SCHATULLE aus Blender (tools/blender_dice_case.py): die Augen ihrer Würfelseite sind die
## Grund-Würfelzahl, die Sorte eine BANDEROLE samt Symbol, die Güte der Lack der ganzen Box
## (Graphit, Silber, Gold). Bewegt wird sie wie eine Karte.
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
## EINE Dicke für jede Schachtel, so dick wie die Schatulle - das Lager mißt seine Teilung
## ohnehin am dicksten Paket.
const CASSETTE_THICKNESS := DICE_THICKNESS
const CASSETTE_SCENE := "res://assets/models/hardware/card_box.glb"
## Spiegeln WALL und die Lasche in tools/blender_card_box_export.py (Roh-Maß).
const BOX_WALL := 0.015
const BOX_TAB := 0.13
## Die Karten sind fast so groß wie die Schachtel, das Fenster nur halb so groß: man sieht
## nie alle ganz - sonst las das Fenster wie ein Bild (Spieler-Wunsch 2026-11-16).
## Die Treppe fächert zum KOPF (Bild-links, unter das Fenster): jede tiefere Karte lugt eine
## Stufe weiter hervor, so blitzen alle auf (Spieler-Wunsch 2026-11-16).
const STAIR_LENGTH := 1.22
const STAIR_STEP := 0.07
const STAIR_FLATTEN := 0.25
const STAIR_PITCH := 0.045
## So tief liegt die oberste Karte unter der Folie: dicht darunter las sie wie ein Bild, mit
## Luft sieht man in die Schachtel hinein (Spieler-Wunsch 2026-11-16).
const STAIR_TOP_AIR := 0.17
## Alle so viele Sekunden zeigt eine Karte ein anderes Netz ihrer Sorte.
const NET_CYCLE := 1.6
## So viele Netze je Sorte und Größe liegen bereit (geteilt, einmal gebacken).
const NET_POOL := 6
## Anthrazit statt Schwarz: auf dem dunklen Tisch las Schwarz als Loch (Spieler-Wunsch).
const BOARD_ALBEDO := Color(0.2, 0.2, 0.23)
const BOARD_GLOW_ENERGY := 0.35
const KRAFT_ALBEDO := Color(0.66, 0.56, 0.42)
## Innen bleibt es schattig - das Dunkel unter dem Fenster sagt die Tiefe.
const KRAFT_GLOW_ENERGY := 0.05
const FILM_ALBEDO := Color(0.85, 0.9, 1.0, 0.08)
const BLACK_INK := Color(0.012, 0.012, 0.014)
const PRINT_WHITE := Color(0.92, 0.92, 0.92)
## Die GÜTE ist die PRÄGEFOLIE: Standard weißer Druck, Edel Silber, Royal Gold.
const FOIL_ALBEDOS := [Color(0.92, 0.92, 0.92), Color(0.9, 0.9, 0.92), Color(0.96, 0.77, 0.4)]
const FOIL_METALLICS := [0.0, 0.7, 0.7]
const FOIL_ROUGHNESSES := [0.5, 0.22, 0.22]
const FOIL_ENERGIES := [0.3, 0.25, 0.3]
## Der Name jeder Sorte im Modell - die Schrift liegt einmal je Sorte darin.
const BOX_SORT_KEYS := {CardPack.SORT_NUMBER: "zahl", CardPack.SORT_MATERIAL: "material",
	CardPack.SORT_RUNE: "rune", CardPack.SORT_MIXED: "misch"}
var _cassette_model: Node3D
var _film: StandardMaterial3D
var _foil: StandardMaterial3D
var _kraft: StandardMaterial3D
var _black_ink: StandardMaterial3D
var _print_white: StandardMaterial3D
var _cycling_forced := false
var _stair: Array[DataCellView] = []
var _stair_holders: Array[Node3D] = []
var _cycle_clock := 0.0
static var _net_pools := {}
const SEAM_HEIGHT_SHARE := 0.07
const SEAM_Z_SHARE := 0.42
const SEAM_PROUD := DataCellView.DEPTH * 0.03
## EIN Modell für jedes Paket: die WÜRFELSEITE trägt die Augen (2..6), nicht die Breite.
const DICE_CASE_SCENE := "res://assets/models/hardware/dice_case.glb"
## Die Würfelseite: Kante auf Deckel und Rücken, Abstand zur Mitte (Blender X, neben der
## Banderole), erhaben wie das Symbol.
## Der Rücken trägt die Seite so groß, wie die Bodenhälfte es zuläßt: sie ist das größte Zeichen.
const FACE_LID := 0.26
const FACE_SPINE := 0.19
const FACE_LID_X := -0.31
const FACE_SPINE_X := -0.275
const FACE_PROUD := 0.008
const FACE_RIM := 1.12
const PIP_SHARE := 0.24
const PIP_STEP := 0.28
## Schwarze Platte, weiß leuchtende Augen: die Zahl liest auf jedem Lack gleich hell.
const FACE_ALBEDO := Color(0.03, 0.03, 0.04)
const PIP_ALBEDO := Color(1.0, 0.98, 0.94)
const PIP_ENERGY := 1.4
const DICE_THICKNESS := DataCellView.DEPTH * 3.2
## Die GÜTE ist das VERHALTEN im Licht, nicht nur die Farbe: Standard mattes Graphit,
## Edel poliertes Chrom, Royal Gold - und nur Royal leuchtet selbst. Ein Rest Eigenlicht
## bleibt, denn in die Rinne fällt kaum Licht und ein Metall ohne Umgebung läse schwarz.
## Neutrale Metalle statt bläulicher Grautöne und Senf: Gunmetal, Silber, Gelbgold.
const CASE_ALBEDOS := [Color(0.32, 0.32, 0.34), Color(0.9, 0.9, 0.92), Color(0.96, 0.77, 0.4)]
const CASE_GLOWS := [Color(0.34, 0.34, 0.36), Color(0.84, 0.84, 0.87), Color(1.0, 0.78, 0.4)]
const CASE_GLOW_ENERGIES := [0.4, 0.62, 0.55]
## Mäßig metallisch: ohne Umgebung zum Spiegeln läse volles Metall im dunklen Tisch schwarz.
const CASE_METALLICS := [0.3, 0.45, 0.45]
const CASE_ROUGHNESSES := [0.45, 0.25, 0.3]
## Die NAHT je Güte: Graphit ein stumpfer Stahlstrich, Edel eine helle Silberlinie, Royal
## ein glühender Goldsaum (über der Bloom-Schwelle).
const SEAM_COLORS := [Color(0.45, 0.45, 0.47), Color(0.85, 0.87, 0.9), Color(1.0, 0.8, 0.42)]
const SEAM_ENERGIES := [0.2, 0.6, 1.1]
## Die OBERFLÄCHE: feine Narbung als Normal-Map, triplanar (das Modell trägt keine UVs, auf die Verlaß ist).
## Die OBERFLÄCHE: Clous de Paris (tools/gen_case_texture.py), triplanar im Raum des
## Modells - es trägt keine UVs, auf die Verlaß ist. Die Albedo schattiert nur die
## Facetten, der Lack bleibt die Güte.
const CASE_SURFACE_ALBEDO := preload("res://assets/textures/case_hobnail_albedo.png")
const CASE_SURFACE_NORMAL := preload("res://assets/textures/case_hobnail_normal.png")
const CASE_SURFACE_SCALE := 2.2
const CASE_SURFACE_DEPTH := 0.8
const CASE_STEEL_ENERGY := 0.45
## Das SYMBOL der Sorte auf der Banderole, im Roh-Maß des Modells: groß auf dem Deckel,
## klein auf dem Rücken, dunkel und eine Spur erhaben.
const BAND_OUTER := 0.012
const SYMBOL_LID := 0.2
const SYMBOL_SPINE := 0.12
const SYMBOL_PROUD := 0.006
const SYMBOL_STROKE := 0.16
const SYMBOL_ALBEDO := Color(0.03, 0.03, 0.04)
static var _dice_case_scenes := {}
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
## Würfel-Paket: seine Güte (der Lack der Box).
var quality: int = DicePack.QUALITY_STANDARD
var _case_metal: StandardMaterial3D
var _seam: StandardMaterial3D
var _symbol: StandardMaterial3D
var _face: StandardMaterial3D
var _pip: StandardMaterial3D
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
		pack_quality := DicePack.QUALITY_STANDARD) -> void:
	card_pack_sort = pack_sort
	card_pack_size = pack_size
	dice_pack = dice
	quality = clampi(pack_quality, DicePack.QUALITY_STANDARD, DicePack.QUALITY_ROYAL)
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
	set_process(_cycling())

## Wie hoch die HÖCHSTE liegende Hülle über ihrem Glaspunkt aufragt - das Maß der Schächte.
static func lying_height(cell_scale: float) -> float:
	return maxf(DICE_THICKNESS, CASSETTE_THICKNESS) * cell_scale

func thickness() -> float:
	if module_bag:
		return float(BAG_THICKNESS[clampi(card_pack_size, 0, BAG_THICKNESS.size() - 1)])
	if dice_pack:
		return DICE_THICKNESS if dice_case_model() != null else THICKNESS
	return CASSETTE_THICKNESS

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
## Die RÜCKEN-MARKE: Sortenfarbe bzw. Stufe; die Schatulle trägt statt ihrer die Banderole,
## nur die normale einen schlichten neutralen Rücken.
const SPINE_PROUD := DataCellView.DEPTH * 0.06
const SPINE_WIDTH_SHARE := 0.62
const SPINE_DEPTH_SHARE := 0.5
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
	# Schatulle und Schachtel brauchen keine Marke: Würfelseite bzw. Kopfdruck lesen von selbst.
	if _spine != null or _cells.is_empty() or (dice_pack and _case_model != null) \
			or _cassette_model != null:
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
	if not dice_pack and not module_bag:
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

## Die SCHACHTEL: die Hülle aus Blender, darin die Treppe der Karten.
func _build_cassette() -> Node3D:
	var cell := Node3D.new()
	cell.name = "Hull%d" % _cells.size()
	var scene := cassette_model()
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
		_dress_box_part(mesh)
	if _cells.is_empty():
		_cassette_model = model
	_build_stair(cell)
	return cell

## Ein Teil der Schachtel: zeigt es sich für dieses Paket, und was trägt es?
func _dress_box_part(mesh: MeshInstance3D) -> void:
	var part := String(mesh.name)
	var mixed := card_pack_sort == CardPack.SORT_MIXED
	var key := String(BOX_SORT_KEYS.get(card_pack_sort, "zahl"))
	if part.begins_with("AugeFront") or part.begins_with("AugeKopf"):
		var group := part.trim_prefix("AugeFront").trim_prefix("AugeKopf")
		mesh.visible = group.begins_with("%d_" % CardPack.option_count(card_pack_size))
		# Am Kopf sitzen sie dunkel auf dem Ring der Sortenfarbe.
		mesh.material_override = _black_ink_material() if part.begins_with("AugeKopf") \
			else _print_white_material()
	elif part.begins_with("Folie"):
		mesh.material_override = _film_material()
	elif part.begins_with("Praegung"):
		mesh.material_override = _foil_material()
	elif part.begins_with("Streifen"):
		mesh.visible = mixed
		var stripe := int(part.substr(8, 1))
		if stripe < _stripe_materials.size():
			mesh.material_override = _stripe_materials[stripe]
	elif part.begins_with("DruckSorte_"):
		mesh.visible = part.ends_with("_" + key)
		mesh.material_override = _edge_material
	elif part.begins_with("DruckBand") or part.begins_with("DruckRuecken"):
		mesh.visible = not mixed
		mesh.material_override = _edge_material
	elif part.begins_with("Druck"):
		mesh.material_override = _edge_material
	elif part.begins_with("Schwarz"):
		mesh.visible = part.ends_with("_" + key)
		mesh.material_override = _black_ink_material()
	else:
		# Karton und Lasche; der Hohlraum trägt innen rohen Karton.
		for surface in mesh.get_surface_override_material_count():
			var source := mesh.mesh.surface_get_material(surface)
			var inside := source != null and source.resource_name.begins_with("Kraft")
			mesh.set_surface_override_material(surface,
				_kraft_material() if inside else _shell_material)

## Die TREPPE: eine echte Karte je Option, in der Sorte des Pakets (Misch: reihum), in der
## Größe, die die Güte verspricht. Nur die erste Hülle trägt sie - ein Stapel zeigt nur sie.
func _build_stair(cell: Node3D) -> void:
	if not _cells.is_empty():
		return
	_stair.clear()
	_stair_holders.clear()
	var count := CardPack.option_count(card_pack_size)
	# Die Karte LIEGT in ihrem eigenen Rahmen; diese Drehung legt ihren in den der Schachtel.
	var into_cell := (Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, PI * 0.5)).inverse()
	for i in count:
		var holder := Node3D.new()
		holder.name = "StairCard%d" % i
		cell.add_child(holder)
		holder.transform = stair_pose(i, count)
		var shelf := _stair_shelf(i)
		var card := DataCellView.new()
		card.name = "Card"
		holder.add_child(card)
		card.setup(shelf, _stair_tier(), _stair_net(shelf, i))
		card.transform = Transform3D(into_cell, Vector3.ZERO)
		card.set_body_scale(STAIR_LENGTH / DataCellView.HEIGHT)
		# Die obere (die höchste i) zeichnet zuletzt - sonst stanzte jedes Netz durch.
		card.set_layer_depth(count - 1 - i)
		_stair_holders.append(holder)
		_stair.append(card)
	_cycle_clock = 0.0

## Der Platz der i-ten Karte im Hohlraum (die Lasche kürzt die Schachtel am Kopf): die
## oberste unter der Folie zum Fuß hin, jede tiefere eine Stufe weiter zum Kopf.
static func stair_pose(index: int, count: int) -> Transform3D:
	var center := -BOX_TAB * 0.5
	var span := STAIR_LENGTH + STAIR_STEP * float(count - 1)
	var top := -DataCellView.DEPTH * 0.5 + CASSETTE_THICKNESS - BOX_WALL - STAIR_TOP_AIR
	var thick := DataCellView.DEPTH * STAIR_FLATTEN
	var at := Vector3(0.0,
		center + (span * 0.5 - STAIR_LENGTH * 0.5) - STAIR_STEP * float(index),
		top - thick * 0.5 - STAIR_PITCH * float(count - 1 - index))
	return Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, STAIR_FLATTEN)), at)

## Die Sorte der i-ten Karte: die des Pakets, im Misch-Paket reihum durch die Regal-Sorten.
func _stair_shelf(index: int) -> String:
	if card_pack_sort == CardPack.SORT_MIXED:
		return String(MIXED_STRIPES[index % MIXED_STRIPES.size()])
	var pack_type := String(CardPack.SORT_TYPES.get(card_pack_sort, Pack.TYPE_NUMBER))
	return Pack.shelf_for_pack_type(pack_type)

## Die Größe der Karten folgt der Güte: Standard, Edel = Groß, Royal = Kolossal.
func _stair_tier() -> int:
	return clampi(quality, Pack.TIER_NORMAL, Pack.TIER_KOLOSSAL)

## Ein Netz aus dem geteilten Vorrat dieser Sorte und Größe.
func _stair_net(shelf: String, step: int) -> Array:
	var pool := net_pool(shelf, _stair_tier())
	return pool[(step + randi()) % pool.size()]

## Der VORRAT an Netzen je Sorte und Größe - fest gewürfelt, damit die Backungen geteilt
## bleiben und der Ofen nicht mit jedem Wechsel wächst.
static func net_pool(shelf: String, card_tier: int) -> Array:
	var key := "%s|%d" % [shelf, card_tier]
	if not _net_pools.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key)
		var pool: Array = []
		# Lauter VERSCHIEDENE Netze - ein Wechsel soll sichtbar wechseln.
		for attempt in NET_POOL * 8:
			var net := StampNet.roll(shelf, card_tier, rng)
			if not pool.has(net):
				pool.append(net)
			if pool.size() >= NET_POOL:
				break
		_net_pools[key] = pool
	return _net_pools[key]

## Die Netze wechseln nur unter dem Griff und auf dem Weg zur Öffnung - in Ruhe stehen sie still
## (ein volles Lager flimmerte sonst im Augenwinkel).
func _ready() -> void:
	set_process(_cycling())

func _cycling() -> bool:
	return not _stair.is_empty() and (_hovered or _cycling_forced)

## Die Öffnung läßt die Netze laufen, bis die Schachtel aufbricht.
func set_net_cycling(on: bool) -> void:
	_cycling_forced = on
	_sync_cycling()

func set_hovered(on: bool) -> void:
	super.set_hovered(on)
	_sync_cycling()

func _sync_cycling() -> void:
	var on := _cycling()
	if on and not is_processing() and not _stair.is_empty():
		# Der erste Wechsel kommt sofort - der Griff soll antworten.
		_cycle_clock = NET_CYCLE / float(_stair.size())
	set_process(on)

func _process(delta: float) -> void:
	if not _cycling():
		set_process(false)
		return
	if not is_visible_in_tree():
		return
	_cycle_clock += delta
	var step := NET_CYCLE / float(_stair.size())
	while _cycle_clock >= step:
		_cycle_clock -= step
		_cycle_next()

var _cycle_index := 0

func _cycle_next() -> void:
	_cycle_index = (_cycle_index + 1) % _stair.size()
	var card := _stair[_cycle_index]
	if not is_instance_valid(card):
		return
	var pool := net_pool(card.sort, card.tier)
	var current := pool.find(card.stamp_net)
	card.stamp_net = (pool[(current + 1 + randi() % (pool.size() - 1)) % pool.size()] as Array).duplicate()
	card._apply_net_texture()

## Die Karten leuchten mit, wenn die Schachtel aufflammt.
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

func _kraft_material() -> StandardMaterial3D:
	if _kraft == null:
		_kraft = StandardMaterial3D.new()
		_kraft.albedo_color = KRAFT_ALBEDO
		_kraft.roughness = 0.9
		_kraft.emission_enabled = true
		_kraft.emission = KRAFT_ALBEDO
		_kraft.emission_energy_multiplier = KRAFT_GLOW_ENERGY
	return _kraft

func _black_ink_material() -> StandardMaterial3D:
	if _black_ink == null:
		_black_ink = StandardMaterial3D.new()
		_black_ink.albedo_color = BLACK_INK
		_black_ink.roughness = 0.5
	return _black_ink

## Weißer Druck der Augen: ein Rest Eigenlicht, damit die Zahl auf dem dunklen Tisch liest.
func _print_white_material() -> StandardMaterial3D:
	if _print_white == null:
		_print_white = StandardMaterial3D.new()
		_print_white.albedo_color = PRINT_WHITE
		_print_white.emission_enabled = true
		_print_white.emission = PRINT_WHITE
		_print_white.emission_energy_multiplier = 1.1
	return _print_white

## Die Folie zieht beim Ebenen-Versatz mit.
func _apply_layer_bias() -> void:
	super._apply_layer_bias()
	if _film != null:
		_film.render_priority = _prio(PRIORITY_PANE)

## Das Blender-Modell der Schachtel (null = kein Import, dann das schlichte Gehäuse).
## Kein eigener Zwischenspeicher: der des ResourceLoaders hält es, solange eine Schachtel lebt
## - ein statischer hielte es bis nach dem Beenden (Godot meldet das als Leck).
static func cassette_model() -> PackedScene:
	if not ResourceLoader.exists(CASSETTE_SCENE):
		return null
	return load(CASSETTE_SCENE) as PackedScene

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
	if not _dice_case_scenes.has(DICE_CASE_SCENE) and ResourceLoader.exists(DICE_CASE_SCENE):
		_dice_case_scenes[DICE_CASE_SCENE] = load(DICE_CASE_SCENE) as PackedScene
	return _dice_case_scenes.get(DICE_CASE_SCENE) as PackedScene

## Was die Schatulle QUER mißt (Roh-Maß) - daran messen Rinne, Laden-Bucht und Öffnungs-Fläche.
static func max_case_across() -> float:
	return DataCellView.WIDTH * FOOT_ROOM

## Die Augen der Würfelseite: die Grund-Würfelzahl des Pakets.
static func case_pips(pack_size: int) -> int:
	return DicePack.base_count(pack_size)

## Trägt diese Hülle eine Banderole (Seele, Material, Runen)?
func has_band() -> bool:
	return dice_pack and _case_model != null and card_pack_sort != DicePack.SORT_NORMAL

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
	# Der Tisch ist zu dunkel für den Lack des Modells: Gehäuse und Metall tragen eigene
	# Materialien, die Naht einen neutralen Stahlton, die Banderole die Sortenfarbe.
	_apply_quality_metal(CASE_SURFACE_ALBEDO, CASE_SURFACE_NORMAL, CASE_SURFACE_SCALE,
		CASE_SURFACE_DEPTH)
	var banded := card_pack_sort != DicePack.SORT_NORMAL
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var part := String(mesh.name)
		if part.begins_with("Band"):
			mesh.material_override = _edge_material
			mesh.visible = banded
		elif part.begins_with("Naht"):
			mesh.material_override = _seam_material()
		elif part.begins_with("Deckel") or part.begins_with("Boden"):
			# Außen Lack, innen der Samt - je Fläche nach ihrem Blender-Material.
			for i in mesh.mesh.get_surface_count():
				var source := mesh.mesh.surface_get_material(i)
				var velvet := source != null and source.resource_name.begins_with("Samt")
				mesh.set_surface_override_material(i,
					_velvet_material() if velvet else _shell_material)
		elif part != "SchliesseMulde":
			mesh.material_override = case_metal()
	if _cells.is_empty():
		_case_model = model
		_hinge = model.find_child("Scharnier", true, false) as Node3D
		if _hinge != null:
			_hinge_rest = _hinge.transform
			_apply_lid()
		if banded:
			_build_symbols(model)
		_build_die_faces(model)
	return cell

## Das Gehäuse der Schatulle im Metall der GÜTE: Lack, Licht und Oberfläche.
func _apply_quality_metal(surface: Texture2D, normal: Texture2D, surface_scale: float,
		surface_depth: float) -> void:
	_shell_material.albedo_color = CASE_ALBEDOS[quality]
	_shell_material.metallic = CASE_METALLICS[quality]
	_shell_material.roughness = CASE_ROUGHNESSES[quality]
	_shell_material.emission = CASE_GLOWS[quality]
	_shell_material.emission_energy_multiplier = CASE_GLOW_ENERGIES[quality]
	_shell_material.normal_enabled = true
	_shell_material.albedo_texture = surface
	# Auch das Eigenlicht trägt die Oberfläche, sonst überstrahlt es sie flach.
	_shell_material.emission_texture = surface
	_shell_material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_shell_material.normal_texture = normal
	_shell_material.normal_scale = surface_depth
	_shell_material.uv1_triplanar = true
	_shell_material.uv1_scale = Vector3.ONE * surface_scale

## Das Metall von Schließe, Lasche und Scharnier: Stahl, für jede Güte gleich.
func case_metal() -> StandardMaterial3D:
	if _case_metal == null:
		_case_metal = _metal(Color(0.62, 0.64, 0.7), Color(0.62, 0.64, 0.7), CASE_STEEL_ENERGY)
	return _case_metal

## Die Naht sagt die Güte, unabhängig von der Sorte.
func _seam_material() -> StandardMaterial3D:
	if _seam == null:
		_seam = _lit_material(SEAM_COLORS[quality])
		_seam.emission_energy_multiplier = SEAM_ENERGIES[quality]
		_seam.render_priority = _prio(PRIORITY_FRAME)
	return _seam

# --- Das SYMBOL der Sorte auf der Banderole -----------------------------------------
# Gebaut im Raum des Modells (glTF: Blender (x, y, z) liegt als (x, z, -y)); ein Symbol-Knoten
# hat lokal X quer, Y = Flächennormale, -Z = "oben" der Figur; SYMBOL_TURN stellt "oben" quer
# zur Banderole (Blender X): so steht das Zeichen im Laden wie in der Rinne aufrecht.
const SYMBOL_TURN := Basis(Vector3(0.0, 0.0, 1.0), Vector3.UP, Vector3(-1.0, 0.0, 0.0))

func _build_symbols(model: Node3D) -> void:
	var lid := Node3D.new()
	lid.name = "SymbolDeckel"
	var lid_at := Transform3D(SYMBOL_TURN, Vector3(0.0, DICE_THICKNESS + BAND_OUTER, 0.0))
	if has_lid():
		_hinge.add_child(lid)
		lid.transform = _hinge_rest.affine_inverse() * lid_at
	else:
		model.add_child(lid)
		lid.transform = lid_at
	_draw_symbol(lid, SYMBOL_LID)
	var spine := Node3D.new()
	spine.name = "SymbolRuecken"
	model.add_child(spine)
	# Auf der Bodenhälfte des Rückens (+Y in Blender = -Z im Modell), mittig ihrer flachen Fläche.
	var end := DataCellView.HEIGHT * FOOT_ROOM * 0.5 + BAND_OUTER
	spine.transform = Transform3D(Basis(Vector3.RIGHT, Vector3(0.0, 0.0, -1.0), Vector3.UP)
		* SYMBOL_TURN, Vector3(0.0, DICE_THICKNESS * 0.25, -end))
	_draw_symbol(spine, SYMBOL_SPINE)

func _draw_symbol(host: Node3D, size: float) -> void:
	var stroke := size * SYMBOL_STROKE
	match card_pack_sort:
		DicePack.SORT_SOUL:
			var gem := _symbol_box(host, "Raute", Vector2(size * 0.62, size * 0.62), Vector2.ZERO)
			gem.rotation.y = PI * 0.25
		DicePack.SORT_MATERIAL:
			# Ein Sechseck - die Silhouette eines Würfels über Eck (Spieler-Wahl 2026-11-15).
			var hexagon := CylinderMesh.new()
			hexagon.top_radius = size * 0.5
			hexagon.bottom_radius = hexagon.top_radius
			hexagon.height = SYMBOL_PROUD
			hexagon.radial_segments = 6
			hexagon.rings = 1
			_symbol_mesh(host, "Sechseck", hexagon, Vector2.ZERO)
		DicePack.SORT_RUNE:
			# Ein Dreieck im Ring (Spieler-Wahl 2026-11-15), die Spitze zeigt nach oben.
			var ring := TorusMesh.new()
			ring.outer_radius = size * 0.5
			ring.inner_radius = size * 0.5 - stroke
			ring.rings = 32
			ring.ring_segments = 6
			var circle := _symbol_mesh(host, "Ring", ring, Vector2.ZERO)
			circle.scale = Vector3(1.0, SYMBOL_PROUD / stroke, 1.0)
			var reach := size * 0.5 - stroke * 1.15
			var corners: Array[Vector2] = []
			for i in 3:
				var angle := TAU * float(i) / 3.0
				corners.append(Vector2(sin(angle), cos(angle)) * reach)
			for i in 3:
				var a: Vector2 = corners[i]
				var b: Vector2 = corners[(i + 1) % 3]
				var side := _symbol_box(host, "Dreieck%d" % i,
					Vector2(stroke, a.distance_to(b) + stroke * 0.6), (a + b) * 0.5)
				side.rotation.y = atan2(b.x - a.x, a.y - b.y)

# --- Die WÜRFELSEITE der Größe ------------------------------------------------------
# Neben der Banderole (Blender -X, die Seite der Schließe): groß auf dem Deckel, klein auf der
# Bodenhälfte des Rückens. Ein Knoten hat lokal Y = Flächennormale, X und Z in der Fläche.

func _build_die_faces(model: Node3D) -> void:
	var lid := Node3D.new()
	lid.name = "SeiteDeckel"
	var lid_at := Transform3D(Basis.IDENTITY, Vector3(FACE_LID_X, DICE_THICKNESS, 0.0))
	if has_lid():
		_hinge.add_child(lid)
		lid.transform = _hinge_rest.affine_inverse() * lid_at
	else:
		model.add_child(lid)
		lid.transform = lid_at
	_draw_die_face(lid, FACE_LID)
	var spine := Node3D.new()
	spine.name = "SeiteRuecken"
	model.add_child(spine)
	spine.transform = Transform3D(Basis(Vector3.RIGHT, Vector3(0.0, 0.0, -1.0), Vector3.UP),
		Vector3(FACE_SPINE_X, DICE_THICKNESS * 0.25, -DataCellView.HEIGHT * FOOT_ROOM * 0.5))
	_draw_die_face(spine, FACE_SPINE)

## Eine Würfelseite: schwarze Platte im Stahlrahmen, darauf weiß leuchtende Augen im Klassik-Muster.
func _draw_die_face(host: Node3D, side: float) -> void:
	TableProps.box(host, "Rand", Vector3(side * FACE_RIM, FACE_PROUD * 0.8, side * FACE_RIM),
		Vector3(0.0, FACE_PROUD * 0.1, 0.0), case_metal())
	TableProps.box(host, "Platte", Vector3(side, FACE_PROUD, side),
		Vector3(0.0, FACE_PROUD * 0.3, 0.0), _face_material())
	var step := side * PIP_STEP
	var spots := pip_spots(case_pips(card_pack_size))
	var pip := CylinderMesh.new()
	pip.top_radius = side * PIP_SHARE * 0.5
	pip.bottom_radius = pip.top_radius
	pip.height = FACE_PROUD * 0.5
	pip.radial_segments = 16
	pip.rings = 1
	for i in spots.size():
		var mesh := MeshInstance3D.new()
		mesh.name = "Auge%d" % i
		mesh.mesh = pip
		mesh.material_override = _pip_material()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position = Vector3(spots[i].x * step, FACE_PROUD * 0.8, spots[i].y * step)
		host.add_child(mesh)

## Die Augen-Plätze (Einheit = PIP_STEP): 2 und 3 diagonal, 4 Ecken, 5 dazu die Mitte, 6 zwei Reihen.
static func pip_spots(pips: int) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	match pips:
		2:
			spots = [Vector2(-1, -1), Vector2(1, 1)]
		3:
			spots = [Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)]
		4, 5:
			spots = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
			if pips == 5:
				spots.append(Vector2.ZERO)
		_:
			for column: float in [-1.0, 1.0]:
				for row: float in [-1.0, 0.0, 1.0]:
					spots.append(Vector2(column, row))
	return spots

func _face_material() -> StandardMaterial3D:
	if _face == null:
		_face = StandardMaterial3D.new()
		_face.albedo_color = FACE_ALBEDO
		_face.roughness = 0.6
	return _face

func _pip_material() -> StandardMaterial3D:
	if _pip == null:
		_pip = StandardMaterial3D.new()
		_pip.albedo_color = PIP_ALBEDO
		_pip.emission_enabled = true
		_pip.emission = PIP_ALBEDO
		_pip.emission_energy_multiplier = PIP_ENERGY
	return _pip

## Ein flaches Figur-Mesh mit Achse auf der Normalen: center in (quer, oben).
func _symbol_mesh(host: Node3D, mesh_name: String, mesh: Mesh,
		center: Vector2) -> MeshInstance3D:
	var figure := MeshInstance3D.new()
	figure.name = mesh_name
	figure.mesh = mesh
	figure.material_override = _symbol_material()
	figure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	figure.position = Vector3(center.x, SYMBOL_PROUD * 0.3, -center.y)
	host.add_child(figure)
	return figure

## Eine flache Figur-Box: center in (quer, oben), ihre Unterseite eine Spur IN der Banderole.
func _symbol_box(host: Node3D, box_name: String, extent: Vector2,
		center: Vector2) -> MeshInstance3D:
	return TableProps.box(host, box_name, Vector3(extent.x, SYMBOL_PROUD, extent.y),
		Vector3(center.x, SYMBOL_PROUD * 0.3, -center.y), _symbol_material())

func _symbol_material() -> StandardMaterial3D:
	if _symbol == null:
		_symbol = StandardMaterial3D.new()
		_symbol.albedo_color = SYMBOL_ALBEDO
		_symbol.roughness = 0.5
		_symbol.render_priority = _prio(PRIORITY_NET)
	return _symbol

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
