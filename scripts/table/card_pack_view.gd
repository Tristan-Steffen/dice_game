class_name CardPackView
extends DataCellView
## Der Körper eines PAKETS, eine Spur größer als die liegende Karte. Ein KARTEN-Paket ist
## seit dem 2026-11-16 eine bedruckte PAPPSCHACHTEL wie die eines RAM-Riegels (Spieler-Wahl
## "Retail", tools/blender_card_box_export.py): Euro-Lasche am Kopf, Sortenband, Prägefolie
## der GÜTE, Augen der Kartenzahl - und durch ein Fenster mit Klarsichtfolie sieht man ECHTE
## Data-Cards, fast so groß wie die Schachtel, also nie alle ganz. Ein WÜRFEL-Paket ist die
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
## EINE Dicke für jede Schachtel, so dick wie die Schale - das Lager mißt seine Teilung
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
var _case_model: Node3D
var _tray: StandardMaterial3D
var _tray_materials := {}
var _tray_dice: Array[MeshInstance3D] = []
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
## Die RÜCKEN-MARKE: Sortenfarbe bzw. Stufe; Schale und Schachtel brauchen keine.
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
	# Schale und Schachtel brauchen keine Marke: ihr Kopfdruck liest von selbst.
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
		_dress_tray_part(mesh)
	if _cells.is_empty():
		_case_model = model
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

## Die Lage eines Knotens für den Grundriß: der Körper zählt immer LIEGEND.
func _pose_free(node: Node) -> Transform3D:
	return _lying_body_transform() if node == _body else (node as Node3D).transform
