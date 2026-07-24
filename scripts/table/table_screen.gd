class_name TableScreen
extends SubViewport
## Der Tisch-Bildschirm: rendert die 2D-Oberfläche (Kinder dieses SubViewports)
## in eine ViewportTexture auf dem "Screen"-Mesh des Tischs (attach_to).
## Koordinaten-Versprechen (world_to_pixel): Pixel (0,0) = obere linke Ecke aus
## Sicht der Grubenkamera; u wächst entlang Welt+Z, v entlang Welt−X
## ("Bildschirm-oben" = +X). Weltgrenzen kommen aus der AABB des Meshs.

## Überabtastung: beim Heranzoomen wird die Textur stark vergrößert; alle
## Layout-Maße wachsen mit demselben Faktor mit.
const SUPERSAMPLE := 3
const RESOLUTION := Vector2i(1560, 1060) * SUPERSAMPLE
## Farbwelt = Obsidian-Theme "80s Neon".
const BACKGROUND_COLOR := Color("#171520")
const EMISSION_ENERGY := 1.2

## Kombinations-Cluster: kleine Zellen in 3 Spalten, Reihenfolge =
## DiceScoring.HAND_PRIORITY, unvollständige letzte Zeile mittig.
const CELL_SIZE := Vector2(98, 31) * SUPERSAMPLE
const CELL_GAP := Vector2(6, 4) * SUPERSAMPLE
const CLUSTER_COLUMNS := 3
const CLUSTER_TOP := 440.0 * SUPERSAMPLE
const CLUSTER_CENTER_X := 400.0 * SUPERSAMPLE

const CLUSTER_PADDING := 13.0 * SUPERSAMPLE
const FRAME_COLOR := Color("#8be9fd")  # Neon-Cyan
const FRAME_BG := Color("#1a1836aa")

## Rundenziel-Balken: goldene Füllung = erspielte Punkte.
const GOAL_BAR_SIZE := Vector2(220, 30) * SUPERSAMPLE
const GOAL_BAR_INSET := 5.0 * SUPERSAMPLE
const GOAL_BAR_FILL_COLOR := Color("#ffd319aa")
const GOAL_BAR_TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (Glow)

## Überladung: je Stufe eine eigene Füllfarbe; jede neue Bahn liegt über der
## vorigen (die gefüllt bleibt). GOAL_STAGE_COLOR/-DARK dienen auch dem Bank-Knopf.
const GOAL_STAGE_COLOR := Color("#8be9fd")
const GOAL_STAGE_DARK := Color("#1c4b57")
const GOAL_STAGE_FILL_COLORS := [
	Color("#ffd319ee"),  # 1 Gold
	Color("#8be9fdee"),  # 2 Cyan
	Color("#50fa7bee"),  # 3 Grün
	Color("#ff79c6ee"),  # 4 Magenta
	Color("#ff5555ee"),  # 5 Rot-heiß
]

const PIT_SCORE_SIZE := Vector2(620, 150) * SUPERSAMPLE
const GLOW_COLOR := Color(1.9, 1.55, 0.6, 0.85)  # überhelles Gold (bloomt)

## Wachstumskonstanten der Orbs (1 - exp(-value/K)): Basis-Werte laufen groß,
## Mult klein, die Gesamtzahl am größten.
const BASE_GROWTH_K := 260.0
const MULT_GROWTH_K := 20.0
const TOTAL_GROWTH_K := 650.0
## Verschmelzungs-Zeremonie in vier Takten: Aufladen (Anticipation), Umkreisen
## (beschleunigend), Hit-Stop (Einschlag-Freeze), Halten (das Produkt wirkt nach).
const MERGE_CHARGE_TIME := 0.5
const MERGE_ORBIT_TIME := 0.55
const MERGE_HITSTOP := 0.1
const MERGE_HOLD := 1.0
const MERGE_ARC_FRAC := 0.5   # Bogenhöhe als Anteil des Abstands zur Mitte
const DRAIN_SPARKS := 5

## Krit-Einschlag auf dem Mult-Orb (siehe crit_pit_mult): Hit-Stop (Anspannung),
## Slam mit Doppel-Stoßwelle, abklingendes Beben. Heißes Magenta als EIGENE
## Farbe - Krits sollen sofort als eigene Klasse lesbar sein.
const CRIT_COLOR := Color(2.2, 0.45, 1.15, 0.95)
const CRIT_HITSTOP := 0.12
const CRIT_ECHO_DELAY := 0.08
const CRIT_SHAKE_TIME := 0.3
const CRIT_SHAKE_PX := 5.0 * SUPERSAMPLE

## Aktions-Buttons unten mittig in der Grube, bedient über die Maus-Weiterleitung.
const PIT_ACTION_SIZE := Vector2(79, 28) * SUPERSAMPLE
const PIT_ACTION_GAP := 10.0 * SUPERSAMPLE
const PIT_ACTION_FONT := 14 * SUPERSAMPLE

## Licht-Trails: LEITERBAHNEN (rein achsenparallel, siehe ScoreTraceView) -
## Cyan in die Basis, Gold in Mult/Gesamtzahl.
const TRAIL_MARGIN := 26.0 * SUPERSAMPLE  # Rand-Klemmung für Quellen außerhalb
const TRAIL_BASE_COLOR := Color(0.5, 2.0, 2.0, 0.9)
const TRAIL_MULT_COLOR := Color(2.0, 1.6, 0.3, 0.9)
const TRACE_CORE_WIDTH := 5.0 * SUPERSAMPLE
const TRACE_GLOW_WIDTH := 16.0 * SUPERSAMPLE
## Erster senkrechter Hub aus der Quelle (~2.4 Weltmeter): hebt die Querstrecke
## über Nachbar-Würfel, hält sie unter Zählern und Punktebalken.
const TRACE_RISE := 30.0 * SUPERSAMPLE

var combo_cells: Dictionary = {}  # DiceScoring-Key -> ComboCellView

var cluster_frame: Panel
## Platinen-Ebene zwischen Rahmen und Chips (Leiterbahnen/Vias).
var circuit_board: CircuitBoardView
## LED-Leiste Hub <-> Kombinationen (Geometrie via link_hub_to_cluster).
var led_strip: LedStripView
## Schatz-Screen (Geldstand als goldene Truhe) rechts des Hubs, plus die
## LED-Leiste Hub <-> Schatz (Geld-Lichtläufe wie beim Übertakten).
var treasure_window: TreasureChestView
var treasure_strip: LedStripView
var pit_window: Panel
## Nebenwetten-Fenster rechts vom Becher (eigenständige Anzeige, kein Hub-Panel).
var side_bet_window: SideBetPanel
## Fumble-Automaten links vom Hub (unter der Ablage); wie das Nebenwetten-Fenster
## eigenständig, sichtbar erst ab der ersten Automaten-Freischaltung.
var slot_bank_window: SlotBankView
## Werkstatt rechts vom Hub: das Lager der versiegelten Pakete.
var workshop_window: WorkshopView
## Die drei Vorrats-Schubladen unter der Werkbank (Zahlen/Material/Kanten),
## je eine Ader zur Werkbank - sie sollen als ANGEBAUT lesen, nicht als
## drei fremde Fenster daneben.
var supply_drawers: Array[SupplyDrawerView] = []
var supply_strips: Array[LedStripView] = []
var workshop_hub_strip: LedStripView
## Ader Automaten <-> Hub: Einsatz fährt hin, Gewinne fahren zurück.
var slot_hub_strip: LedStripView
var supply_info_bar: Panel
## RichTextLabel: der Gravur-Name steht fett in seiner Seltenheits-Farbe (BBCode).
var supply_info_label: RichTextLabel
## Hover-Erklärfeld unter den Grubenwürfeln: zeigt die Materialwirkung der Seite
## unter der Maus (Seite + Kanten). Nur sichtbar, während set_pit_info Text hat.
var pit_info_bar: Panel
var pit_info_label: Label
## Display-Glas-Material: bekommt über _sync_reflection_windows die Fenster-
## Rechtecke - NUR dort spiegelt das Glas, der Filz dazwischen bleibt matt.
var _glass_material: ShaderMaterial
## Wertungs-Bildschirm: EIN Fenster-Rahmen HINTER Basis-Zähler, Zielbalken und
## Mult-Zähler (die bleiben eigenständige Kinder mit Screen-globaler Position -
## die Zähl-Animation rechnet unverändert weiter). Analog zu cluster_frame.
var score_frame: Panel
var score_rect := Rect2()
## Leisten, die in den Wertungs-Bildschirm münden: Grube (dicker Datenbus, von
## unten), Kombinationen (von unten-links), und je Charm-Konsole eine kurze Ader
## auf EINE gemeinsame Sammelschiene (charm_bus_strip), die als Stamm in den Score
## läuft.
var pit_score_strip: LedStripView
## Bank-Leiste: Grube-Unterkante -> Hub-Oberkante. Über sie fährt der Bank-Komet
## der Rundenauszahlung (Zielbalken -> um die Grube -> Hub).
var pit_hub_strip: LedStripView
var combos_score_strip: LedStripView
var charm_score_strips: Array[LedStripView] = []
var charm_bus_strip: LedStripView
## Geometrie der Charm-Sammelschiene (für die Kometen-Route Konsole -> Schiene ->
## Stamm -> Score).
var _charm_rail_y := 0.0
var _charm_trunk_x := 0.0
## Charm-Dock (eigene Konsolen-Screens unter der 3D-Charm-Reihe).
var charm_dock: CharmDockView
var goal_bar: Panel
## Zwei Füllschichten: goal_bar_base = die bereits gefüllten Stufen (volle Breite,
## Farbe der letzten Stufe), goal_bar_fill = die AKTUELLE Stufe darüber in neuer
## Farbe. So bleibt der Balken nach jeder Überladung gefüllt, die nächste startet
## eine neue Bahn obendrauf.
var goal_bar_base: ColorRect
var goal_bar_fill: ColorRect
var goal_bar_label: Label
## Rollover-Erkennung (Stufe frisch gefüllt) für Blitz + Stoßwelle.
var _goal_last_cleared := 0
## Basis- und Mult-Zähler getrennt, je an eigenem Editor-Anker.
var base_counter: PitScoreView
var mult_counter: PitScoreView
var hub: HubView
## Verschmolzene Gesamtzahl als dritter Orb: erscheint AM Zielbalken (die
## Grubenmitte wäre vom Käfig verdeckt) und drainiert am Ende in den Balken.
var total_orb: PitScoreView
## Ruhepositionen der Zähler (die Merge zieht sie zur Mitte; danach zurück).
var _base_home := Vector2.ZERO
var _mult_home := Vector2.ZERO

## Trägerfläche ist klick-durchlässig; nur die Buttons fangen ihre Klicks.
var pit_actions_root: Control
var take_action_button: Button
var roll_action_button: Button
var bank_action_button: Button  # Runde bei ≥1 Überladungs-Stufe vorzeitig beenden

## Bildschirm-Rechteck des Kombi-Clusters inkl. Rahmen (Zoomziel/Klickzone).
var cluster_rect := Rect2()

## Weltgrenzen der Screen-Fläche (aus attach_to).
var _z_min := 0.0
var _z_span := 1.0
var _x_max := 0.0
var _x_span := 1.0
var _surface_y := 0.0

func _ready() -> void:
	size = RESOLUTION
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	use_hdr_2d = true  # Überhell-Farben dürfen blühen
	_build_content()

## Legt die ViewportTexture aufs Screen-Mesh und leitet die Weltgrenzen aus
## dessen globaler AABB ab (robust gegen Tisch-Verschiebungen). Mit reflection
## spiegelt das Glas zusätzlich die Würfel (kein SSR im Compatibility-Renderer).
func attach_to(screen_mesh: MeshInstance3D, reflection: ScreenReflection = null) -> void:
	var aabb := screen_mesh.get_aabb()
	var to_world := screen_mesh.global_transform
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for i in 8:
		var corner := to_world * (aabb.position + Vector3(
			aabb.size.x * float(i & 1),
			aabb.size.y * float((i >> 1) & 1),
			aabb.size.z * float((i >> 2) & 1)))
		min_x = minf(min_x, corner.x)
		max_x = maxf(max_x, corner.x)
		min_z = minf(min_z, corner.z)
		max_z = maxf(max_z, corner.z)
		_surface_y = corner.y  # flache Fläche - alle Ecken (fast) gleich hoch
	_z_min = min_z
	_z_span = max_z - min_z
	_x_max = max_x
	_x_span = max_x - min_x

	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/screen_glass.gdshader")
	material.set_shader_parameter("screen_texture", get_texture())
	material.set_shader_parameter("emission_energy", EMISSION_ENERGY)
	if reflection != null:
		reflection.plane_height = _surface_y
		material.set_shader_parameter("reflection_texture", reflection.get_texture())
	material.set_shader_parameter("screen_px", Vector2(size))
	screen_mesh.material_override = material
	_glass_material = material
	_sync_reflection_windows()

## Weltposition -> Display-Pixel (y der Weltposition ist egal).
func world_to_pixel(world: Vector3) -> Vector2:
	var u := (world.z - _z_min) / _z_span
	var v := (_x_max - world.x) / _x_span
	return Vector2(u * float(size.x), v * float(size.y))

## Display-Pixel -> Weltposition auf der Tischfläche (y = Screen-Oberfläche).
func pixel_to_world(pixel: Vector2) -> Vector3:
	var u := pixel.x / float(size.x)
	var v := pixel.y / float(size.y)
	return Vector3(_x_max - v * _x_span, _surface_y, _z_min + u * _z_span)

func _build_content() -> void:
	# Grundfläche = Casino-Filz; die Fenster-Panels darüber spiegeln als einzige.
	var background := ColorRect.new()
	background.name = "Background"
	background.color = BACKGROUND_COLOR  # Rückfall, falls der Shader fehlt
	background.material = ShaderMaterial.new()
	background.material.shader = load("res://assets/shaders/table_felt.gdshader")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# LED-Leisten (Hub<->Kombinationen, Hub<->Schatz): bewusst früh gebaut, damit
	# sie UNTER allen Fenstern liegen; verlegt werden sie erst in
	# link_hub_to_cluster/_treasure (brauchen die endgültigen Fenster-Positionen).
	led_strip = LedStripView.new()
	led_strip.name = "LedStrip"
	led_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(led_strip)

	treasure_strip = LedStripView.new()
	treasure_strip.name = "TreasureStrip"
	treasure_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(treasure_strip)

	# Wertungs-Leisten (Grube/Kombis -> Score): früh gebaut, damit sie UNTER den
	# Fenstern liegen; verlegt werden sie in link_score_strips.
	pit_score_strip = LedStripView.new()
	pit_score_strip.name = "PitScoreStrip"
	pit_score_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pit_score_strip)

	# Bank-Leiste: Grube-Unterkante -> Hub-Oberkante (Rundenauszahlung fährt hier
	# als Bank-Komet in den Hub). Vervollständigt die Verdrahtung der Hub-Oberkante.
	pit_hub_strip = LedStripView.new()
	pit_hub_strip.name = "PitHubStrip"
	pit_hub_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pit_hub_strip)

	combos_score_strip = LedStripView.new()
	combos_score_strip.name = "CombosScoreStrip"
	combos_score_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(combos_score_strip)

	# Sammelschiene zuerst (liegt unter den Konsolen-Adern), dann je Konsole eine
	# kurze Ader auf die Schiene.
	charm_bus_strip = LedStripView.new()
	charm_bus_strip.name = "CharmBusStrip"
	charm_bus_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(charm_bus_strip)
	for i in CharmRowView.SPOT_COUNT:
		var strip := LedStripView.new()
		strip.name = "CharmScoreStrip%d" % i
		strip.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(strip)
		charm_score_strips.append(strip)

	# Charm-Dock: über den Leisten, aber unter den restlichen Fenstern; Position
	# setzt scene_root über place_charm_dock (Maße aus den Charm-Plätzen).
	charm_dock = CharmDockView.new()
	charm_dock.name = "CharmDock"
	charm_dock.visible = false
	add_child(charm_dock)

	# Schatz-Screen: Position/Größe setzt scene_root über place_treasure_window.
	treasure_window = TreasureChestView.new()
	treasure_window.name = "TreasureWindow"
	treasure_window.visible = false
	add_child(treasure_window)

	# Gruben-Fenster: bewusst früh gebaut - hinter allem, was später dazukommt.
	# Position/Größe setzt scene_root über place_pit_window; bis dahin unsichtbar.
	pit_window = Panel.new()
	pit_window.name = "PitWindow"
	pit_window.visible = false
	pit_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pit_window.add_theme_stylebox_override("panel", window_style())
	add_child(pit_window)

	# Zellpositionen vorab berechnen - der Neon-Rahmen muss hinter die Zellen.
	var total := DiceScoring.HAND_PRIORITY.size()
	var positions: Array[Vector2] = []
	var bounds := Rect2()
	for i in total:
		var row := i / CLUSTER_COLUMNS
		var column := i % CLUSTER_COLUMNS
		var cells_in_row: int = mini(CLUSTER_COLUMNS, total - row * CLUSTER_COLUMNS)
		var row_width := float(cells_in_row) * CELL_SIZE.x + float(cells_in_row - 1) * CELL_GAP.x
		var at := Vector2(
			CLUSTER_CENTER_X - row_width / 2.0 + float(column) * (CELL_SIZE.x + CELL_GAP.x),
			CLUSTER_TOP + float(row) * (CELL_SIZE.y + CELL_GAP.y))
		positions.append(at)
		var cell_rect := Rect2(at, CELL_SIZE)
		bounds = cell_rect if i == 0 else bounds.merge(cell_rect)

	cluster_rect = bounds.grow(CLUSTER_PADDING)
	_add_cluster_frame(cluster_rect)
	# Platine unter die Chips: Leiterbahnen setzen an den Zell-Pins an.
	circuit_board = CircuitBoardView.new()
	circuit_board.name = "CircuitBoard"
	circuit_board.position = cluster_rect.position
	circuit_board.size = cluster_rect.size
	add_child(circuit_board)
	var local_cells: Array[Rect2] = []
	for i in total:
		local_cells.append(Rect2(positions[i] - cluster_rect.position, CELL_SIZE))
	circuit_board.setup(local_cells, CELL_GAP.x * 0.5)
	for i in total:
		_add_combo_cell(DiceScoring.HAND_PRIORITY[i], positions[i])

	# Wertungs-Bildschirm-Rahmen: VOR Zielbalken/Zählern gebaut, damit er HINTER
	# ihnen zeichnet; Position/Größe setzt scene_root über place_score_screen.
	score_frame = Panel.new()
	score_frame.name = "ScoreFrame"
	score_frame.visible = false
	score_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_frame.add_theme_stylebox_override("panel", window_style())
	add_child(score_frame)

	_build_goal_bar()
	_build_pit_score()

	# Nebenwetten-Fenster: Position/Größe setzt scene_root über
	# place_side_bet_window; bis dahin unsichtbar.
	side_bet_window = SideBetPanel.new()
	side_bet_window.name = "SideBetWindow"
	side_bet_window.visible = false
	add_child(side_bet_window)

	# Fumble-Automaten: Position/Größe setzt scene_root über
	# place_slot_bank_window; sichtbar erst ab Automaten-Freischaltung.
	slot_bank_window = SlotBankView.new()
	slot_bank_window.name = "SlotBankWindow"
	slot_bank_window.visible = false
	add_child(slot_bank_window)

	# Werkstatt: Position/Größe setzt scene_root über place_workshop_window.
	workshop_window = WorkshopView.new()
	workshop_window.name = "WorkshopWindow"
	workshop_window.visible = false
	add_child(workshop_window)

	# Ader Hub -> Werkstatt (verlegt place_workshop_window).
	workshop_hub_strip = LedStripView.new()
	workshop_hub_strip.name = "WorkshopHubStrip"
	add_child(workshop_hub_strip)

	# Ader Automaten -> Hub (verlegt place_slot_bank_window).
	slot_hub_strip = LedStripView.new()
	slot_hub_strip.name = "SlotHubStrip"
	add_child(slot_hub_strip)

	# Vorrats-Schubladen: Maße/Position setzt scene_root über place_supply_drawers.
	# Die Adern zuerst, damit sie UNTER den Schubladen liegen.
	for i in Engraving.CATEGORIES.size():
		var strip := LedStripView.new()
		strip.name = "SupplyStrip%d" % i
		add_child(strip)
		supply_strips.append(strip)
	for drawer_category in Engraving.CATEGORIES:
		var drawer := SupplyDrawerView.new()
		drawer.name = "SupplyDrawer_%s" % drawer_category
		drawer.category = drawer_category
		drawer.visible = false
		add_child(drawer)
		supply_drawers.append(drawer)

	# Info-Leiste unter den Schubladen: die Hinweiszeile der Gravur-Station
	# (die Station schreibt direkt in supply_info_label, siehe set_prompt_label).
	supply_info_bar = Panel.new()
	supply_info_bar.name = "SupplyInfoBar"
	supply_info_bar.visible = false
	supply_info_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	supply_info_bar.add_theme_stylebox_override("panel", window_style())
	add_child(supply_info_bar)
	supply_info_label = RichTextLabel.new()
	supply_info_label.name = "InfoLabel"
	supply_info_label.bbcode_enabled = true
	supply_info_label.scroll_active = false
	supply_info_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	supply_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	supply_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	supply_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	supply_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	supply_info_bar.add_child(supply_info_label)

	# Hover-Erklärfeld der Grube: Position/Größe setzt scene_root über
	# place_pit_info_bar; leer = unsichtbar (set_pit_info).
	pit_info_bar = Panel.new()
	pit_info_bar.name = "PitInfoBar"
	pit_info_bar.visible = false
	pit_info_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pit_info_bar.add_theme_stylebox_override("panel", window_style())
	add_child(pit_info_bar)
	pit_info_label = Label.new()
	pit_info_label.name = "InfoLabel"
	pit_info_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	pit_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pit_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pit_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pit_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pit_info_label.modulate = Color(1.35, 1.35, 1.3)
	pit_info_bar.add_child(pit_info_label)

	# Hub-Inhalt entsteht erst in place_hub (Maße aus der endgültigen Größe).
	hub = HubView.new()
	hub.name = "Hub"
	add_child(hub)

	_build_pit_actions()

## DER Fenster-Stil des Tisch-Displays: dunkler, leicht durchscheinender Grund
## + Neon-Rahmen - jedes "Fenster" trägt diesen einen Look.
static func window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_BG
	style.border_color = FRAME_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style

func _add_cluster_frame(rect: Rect2) -> void:
	var frame := Panel.new()
	frame.name = "ClusterFrame"
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", window_style())
	add_child(frame)
	cluster_frame = frame

## Spannt das Gruben-Fenster über rect auf: der Rahmen zeichnet exakt die
## Kollisionslinie der Energiewände nach (Radius = DicePit.CORNER_RADIUS in px).
func place_pit_window(rect: Rect2, corner_radius: float) -> void:
	pit_window.position = rect.position
	pit_window.size = rect.size
	var style: StyleBoxFlat = pit_window.get_theme_stylebox("panel")
	style.set_corner_radius_all(int(corner_radius))
	pit_window.visible = true
	_sync_reflection_windows()

## Spannt das Nebenwetten-Fenster über rect auf (rechts vom Becher).
func place_side_bet_window(rect: Rect2) -> void:
	side_bet_window.position = rect.position
	side_bet_window.size = rect.size
	side_bet_window.visible = true
	_sync_reflection_windows()

## Spannt das Automaten-Fenster über rect auf (links vom Hub). Bleibt bis zur
## ersten Freischaltung unsichtbar (set_slot_bank_installed).
func place_slot_bank_window(rect: Rect2) -> void:
	slot_bank_window.position = rect.position
	slot_bank_window.size = rect.size
	slot_bank_window.refresh()
	_link_slot_to_hub()
	_sync_reflection_windows()

## Blendet das Automaten-Fenster ein/aus (erste Automaten-Stufe erreicht).
func set_slot_bank_installed(installed: bool) -> void:
	if slot_bank_window == null or slot_bank_window.size.x <= 0.0:
		return  # noch nicht platziert
	if slot_bank_window.visible == installed:
		return
	slot_bank_window.visible = installed
	slot_hub_strip.visible = installed  # ohne Automaten liegt dort keine Ader
	_sync_reflection_windows()

## Ader Automaten -> Hub: der spiegelbildliche Zwilling der Werkstatt-Ader, gerade
## waagerecht durch die Lücke an der LINKEN Hub-Kante.
func _link_slot_to_hub() -> void:
	if slot_hub_strip == null or hub == null or hub.size.x <= 0.0 or slot_bank_window == null:
		return
	var top := maxf(hub.position.y, slot_bank_window.position.y)
	var bottom := minf(hub.position.y + hub.size.y,
		slot_bank_window.position.y + slot_bank_window.size.y)
	if bottom <= top:
		return  # keine Höhen-Überlappung - keine gerade Ader möglich
	slot_hub_strip.link_horizontal(slot_bank_window.position.x + slot_bank_window.size.x,
		hub.position.x, (top + bottom) * 0.5, HUB_STRIP_WIDTH)
	slot_hub_strip.visible = slot_bank_window.visible

## Spannt die Werkstatt über rect auf (rechter Zwilling der Automaten).
func place_workshop_window(rect: Rect2) -> void:
	workshop_window.position = rect.position
	workshop_window.size = rect.size
	workshop_window.visible = true
	workshop_window.refresh()
	_link_workshop_to_hub()
	_sync_reflection_windows()

## Ader Hub -> Werkstatt: gerade waagerecht durch die Lücke, auf halber Höhe der
## Überlappung beider Fenster (dort liegt nur Filz).
func _link_workshop_to_hub() -> void:
	if workshop_hub_strip == null or hub == null or hub.size.x <= 0.0 			or workshop_window == null or not workshop_window.visible:
		return
	var top := maxf(hub.position.y, workshop_window.position.y)
	var bottom := minf(hub.position.y + hub.size.y, workshop_window.position.y + workshop_window.size.y)
	if bottom <= top:
		return  # keine Höhen-Überlappung - keine gerade Ader möglich
	workshop_hub_strip.link_horizontal(hub.position.x + hub.size.x,
		workshop_window.position.x, (top + bottom) * 0.5, HUB_STRIP_WIDTH)

## Legt die drei Schubladen unter der Werkbank aus (Reihenfolge = CATEGORIES).
func place_supply_drawers(rects: Array[Rect2], unit: float) -> void:
	for i in mini(rects.size(), supply_drawers.size()):
		supply_drawers[i].place(rects[i], unit)
		supply_drawers[i].visible = true
	_link_supply_strips()
	_sync_reflection_windows()

## Je Schublade eine kurze Ader von der Werkbank-Unterkante in die Schubladen-
## Oberkante - in DERSELBEN Breite wie alle anderen Adern des Tisches.
func _link_supply_strips() -> void:
	if workshop_window == null or not workshop_window.visible:
		return
	var bench_bottom := workshop_window.position.y + workshop_window.size.y
	for i in mini(supply_strips.size(), supply_drawers.size()):
		var drawer := supply_drawers[i]
		if not drawer.visible:
			continue
		var enter_x := drawer.position.x + drawer.size.x * 0.5
		var lane_y := (bench_bottom + drawer.position.y) * 0.5
		supply_strips[i].link_edges(bench_bottom, enter_x, drawer.position.y, enter_x,
			lane_y, HUB_STRIP_WIDTH)

## Spannt die Info-Leiste unter der Schubladen-Reihe auf.
func place_supply_info_bar(rect: Rect2, unit: float) -> void:
	supply_info_bar.position = rect.position
	supply_info_bar.size = rect.size
	supply_info_label.offset_left = unit * 1.6
	supply_info_label.offset_right = -unit * 1.6
	var info_font := maxi(8, int(unit * 2.4))
	supply_info_label.add_theme_font_size_override("normal_font_size", info_font)
	supply_info_label.add_theme_font_size_override("bold_font_size", info_font)
	supply_info_label.modulate = Color(1.35, 1.35, 1.3)
	supply_info_bar.visible = true
	_sync_reflection_windows()

## Schaltet alle Schubladen in die Station-Betriebsart (Werkzeug-Bord) und zurück.
func set_drawers_in_ceremony(active: bool) -> void:
	for drawer in supply_drawers:
		drawer.set_ceremony(active)

## Spannt den Schatz-Screen über rect auf (rechts des Hubs).
func place_treasure_window(rect: Rect2) -> void:
	treasure_window.position = rect.position
	treasure_window.size = rect.size
	treasure_window.visible = true
	_sync_reflection_windows()

## Meldet dem Display-Glas die aktuellen Fenster-Rechtecke samt Eckenradius.
## Nach jedem place_* neu gerufen; ohne Glas (headless) passiert nichts.
func _sync_reflection_windows() -> void:
	if _glass_material == null:
		return
	var rects := PackedVector4Array()
	var radii := PackedFloat32Array()
	if pit_window != null and pit_window.visible:
		var style: StyleBoxFlat = pit_window.get_theme_stylebox("panel")
		rects.append(Vector4(pit_window.position.x, pit_window.position.y,
			pit_window.position.x + pit_window.size.x, pit_window.position.y + pit_window.size.y))
		radii.append(float(style.corner_radius_top_left))
	if cluster_frame != null:
		rects.append(Vector4(cluster_rect.position.x, cluster_rect.position.y,
			cluster_rect.end.x, cluster_rect.end.y))
		radii.append(10.0)
	if score_frame != null and score_frame.visible:
		rects.append(Vector4(score_rect.position.x, score_rect.position.y,
			score_rect.end.x, score_rect.end.y))
		radii.append(10.0)
	if charm_dock != null and charm_dock.visible:
		# Je Charm-Konsole ein eigenes Glas-Fenster (gekapselte Sub-Screens).
		for console in charm_dock.console_rects():
			rects.append(Vector4(console.position.x, console.position.y,
				console.end.x, console.end.y))
			radii.append(charm_dock.console_corner_radius())
	if goal_bar != null:
		rects.append(Vector4(goal_bar.position.x, goal_bar.position.y,
			goal_bar.position.x + goal_bar.size.x, goal_bar.position.y + goal_bar.size.y))
		radii.append(10.0)
	if side_bet_window != null and side_bet_window.visible:
		rects.append(Vector4(side_bet_window.position.x, side_bet_window.position.y,
			side_bet_window.position.x + side_bet_window.size.x, side_bet_window.position.y + side_bet_window.size.y))
		radii.append(10.0)
	if slot_bank_window != null and slot_bank_window.visible:
		rects.append(Vector4(slot_bank_window.position.x, slot_bank_window.position.y,
			slot_bank_window.position.x + slot_bank_window.size.x, slot_bank_window.position.y + slot_bank_window.size.y))
		radii.append(10.0)
	if workshop_window != null and workshop_window.visible:
		rects.append(Vector4(workshop_window.position.x, workshop_window.position.y,
			workshop_window.position.x + workshop_window.size.x, workshop_window.position.y + workshop_window.size.y))
		radii.append(10.0)
	for drawer in supply_drawers:
		if drawer != null and drawer.visible:
			rects.append(Vector4(drawer.position.x, drawer.position.y,
				drawer.position.x + drawer.size.x, drawer.position.y + drawer.size.y))
			radii.append(10.0)
	if supply_info_bar != null and supply_info_bar.visible:
		rects.append(Vector4(supply_info_bar.position.x, supply_info_bar.position.y,
			supply_info_bar.position.x + supply_info_bar.size.x,
			supply_info_bar.position.y + supply_info_bar.size.y))
		radii.append(10.0)
	if treasure_window != null and treasure_window.visible:
		rects.append(Vector4(treasure_window.position.x, treasure_window.position.y,
			treasure_window.position.x + treasure_window.size.x, treasure_window.position.y + treasure_window.size.y))
		radii.append(treasure_window.size.x / 100.0 * 3.0)
	if hub != null and hub.size.x > 0.0:
		rects.append(Vector4(hub.position.x, hub.position.y,
			hub.position.x + hub.size.x, hub.position.y + hub.size.y))
		radii.append(hub.size.x / 100.0 * 1.6)  # = Rahmenradius aus HubView.layout
	_glass_material.set_shader_parameter("window_count", rects.size())
	_glass_material.set_shader_parameter("window_rects", rects)
	_glass_material.set_shader_parameter("window_radius", radii)

## Verschiebt den ganzen Kombi-Cluster (Rahmen + Zellen) mittig auf center_px
## (Pixelposition des Editor-Ankers CombosBlock); cluster_rect wandert mit.
func place_combo_cluster(center_px: Vector2) -> void:
	var delta := center_px - cluster_rect.get_center()
	if cluster_frame != null:
		cluster_frame.position += delta
	if circuit_board != null:
		circuit_board.position += delta
	for key in combo_cells:
		combo_cells[key].position += delta
	cluster_rect.position += delta
	_sync_reflection_windows()

func _add_combo_cell(key: String, at: Vector2) -> void:
	var cell := ComboCellView.new()
	cell.name = "Combo_%s" % key
	cell.position = at
	cell.size = CELL_SIZE
	add_child(cell)
	cell.setup(DiceScoring.label_for(key), DiceScoring.EXAMPLE_DICE[key],
		DiceScoring.points_for(key), DiceScoring.mult_for(key))
	combo_cells[key] = cell

## --- Rundenziel-Balken -------------------------------------------------------

func _build_goal_bar() -> void:
	goal_bar = Panel.new()
	goal_bar.name = "GoalBar"
	goal_bar.size = GOAL_BAR_SIZE
	goal_bar.position = (Vector2(RESOLUTION) - GOAL_BAR_SIZE) / 2.0
	goal_bar.pivot_offset = GOAL_BAR_SIZE / 2.0
	goal_bar.add_theme_stylebox_override("panel", window_style())
	add_child(goal_bar)

	# Basis-Bahn (bereits gefüllte Stufen, volle Breite) UNTER der aktuellen Bahn.
	goal_bar_base = ColorRect.new()
	goal_bar_base.name = "FillBase"
	goal_bar_base.position = Vector2.ONE * GOAL_BAR_INSET
	goal_bar_base.size = Vector2(0.0, GOAL_BAR_SIZE.y - GOAL_BAR_INSET * 2.0)
	goal_bar.add_child(goal_bar_base)

	goal_bar_fill = ColorRect.new()
	goal_bar_fill.name = "Fill"
	goal_bar_fill.color = GOAL_BAR_FILL_COLOR
	goal_bar_fill.position = Vector2.ONE * GOAL_BAR_INSET
	goal_bar_fill.size = Vector2(0.0, GOAL_BAR_SIZE.y - GOAL_BAR_INSET * 2.0)
	goal_bar.add_child(goal_bar_fill)

	goal_bar_label = Label.new()
	goal_bar_label.name = "GoalLabel"
	goal_bar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	goal_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_bar_label.add_theme_font_size_override("font_size", 16 * SUPERSAMPLE)
	# Dunkle Kontur, damit die Zahl auch auf heller (heißer) Füllung lesbar bleibt.
	goal_bar_label.add_theme_color_override("font_outline_color", CasinoStyle.SHADOW)
	goal_bar_label.add_theme_constant_override("outline_size", 4 * SUPERSAMPLE)
	goal_bar_label.modulate = GOAL_BAR_TEXT_COLOR
	goal_bar.add_child(goal_bar_label)
	set_goal_progress(0, GameRun.BASE_GOAL, 1, 0)

## Zentriert den Balken auf das Display-Pixel.
func place_goal_bar(center_px: Vector2) -> void:
	goal_bar.position = center_px - GOAL_BAR_SIZE / 2.0
	_sync_reflection_windows()

## Rahmt Basis-Zähler, Zielbalken und Mult-Zähler zu EINEM Bildschirm (Rahmen
## hinter den Elementen). NACH place_goal_bar UND configure_pit_score rufen.
const SCORE_SCREEN_PADDING := 10.0 * SUPERSAMPLE

func place_score_screen() -> void:
	if score_frame == null or base_counter == null or mult_counter == null or goal_bar == null:
		return
	var r := Rect2(base_counter.position, base_counter.size)
	r = r.merge(Rect2(mult_counter.position, mult_counter.size))
	r = r.merge(Rect2(goal_bar.position, goal_bar.size))
	score_rect = r.grow(SCORE_SCREEN_PADDING)
	score_frame.position = score_rect.position
	score_frame.size = score_rect.size
	score_frame.visible = true
	_sync_reflection_windows()

## Fortschritt innerhalb der aktuellen Überladungs-Stufe: Füllung, Beschriftung
## (mit ×N ab Stufe 1), Lämpchen und - beim frischen Füllen einer Stufe - der
## Rollover-Blitz. into_stage/stage_size = Punkte in der Stufe, cleared = gefüllte Stufen.
func set_goal_progress(into_stage: int, stage_size: int, _stage: int, cleared: int) -> void:
	var full_w := GOAL_BAR_SIZE.x - GOAL_BAR_INSET * 2.0
	# Basis-Bahn: bei ≥1 gefüllter Stufe volle Breite in der Farbe der LETZTEN Stufe.
	goal_bar_base.size.x = full_w if cleared >= 1 else 0.0
	goal_bar_base.color = _stage_fill_color(cleared)
	# Aktuelle Bahn: Fortschritt der laufenden Stufe in der NÄCHSTEN Farbe, darüber.
	var fraction := clampf(float(into_stage) / float(maxi(1, stage_size)), 0.0, 1.0)
	goal_bar_fill.size.x = full_w * fraction
	goal_bar_fill.color = _stage_fill_color(mini(cleared + 1, GameRun.OVERCHARGE_STAGES))
	if cleared >= 1:
		goal_bar_label.text = "%d / %d  ⚡×%d" % [into_stage, stage_size, cleared]
	else:
		goal_bar_label.text = "%d / %d" % [into_stage, stage_size]
	# Rollover: eine Stufe wurde frisch gefüllt -> Blitz + Stoßwelle.
	if cleared > _goal_last_cleared:
		_goal_rollover()
	_goal_last_cleared = cleared

## Füllfarbe der Stufe (1-basiert, gedeckelt); Stufe 0 = keine Füllung.
func _stage_fill_color(stage: int) -> Color:
	if stage <= 0:
		return Color.TRANSPARENT
	return GOAL_STAGE_FILL_COLORS[mini(stage, GameRun.OVERCHARGE_STAGES) - 1]

## Rollover-Moment: Balken pocht kurz auf, Stoßwelle am Balkenzentrum.
func _goal_rollover() -> void:
	pulse_goal_bar()
	var center := goal_bar.position + goal_bar.size / 2.0
	var wave := ScoreShockwave.new()
	add_child(wave)
	wave.setup(center, Color(2.2, 2.0, 1.3, 0.9), GOAL_BAR_SIZE.x * 0.7, 0.55)

func pulse_goal_bar() -> void:
	goal_bar.scale = Vector2(1.18, 1.18)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(goal_bar, "scale", Vector2.ONE, 0.35)

## --- Wertungszahlen & Goldlicht der Zähl-Animation ----------------------------

func _build_pit_score() -> void:
	base_counter = _make_counter("BaseCounter", PitScoreView.BASE_COLOR, BASE_GROWTH_K)
	mult_counter = _make_counter("MultCounter", PitScoreView.MULT_COLOR, MULT_GROWTH_K)
	total_orb = _make_counter("TotalOrb", PitScoreView.TOTAL_COLOR, TOTAL_GROWTH_K)
	total_orb.is_total = true
	total_orb.visible = false

func _make_counter(node_name: String, counter_color: Color, k: float) -> PitScoreView:
	var counter := PitScoreView.new()
	counter.name = node_name
	counter.color = counter_color
	counter.growth_k = k
	counter.size = PIT_SCORE_SIZE
	counter.position = (Vector2(RESOLUTION) - PIT_SCORE_SIZE) / 2.0
	counter.pivot_offset = PIT_SCORE_SIZE / 2.0
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(counter)
	return counter

## Setzt Größe und Mitte BEIDER Zähler (aus den Anker-Weltpositionen); der
## Gesamt-Orb sitzt mittig auf dem Zielbalken.
func configure_pit_score(base_center_px: Vector2, mult_center_px: Vector2, new_size: Vector2) -> void:
	_place_counter(base_counter, base_center_px, new_size)
	_place_counter(mult_counter, mult_center_px, new_size)
	_base_home = base_counter.position
	_mult_home = mult_counter.position
	_place_counter(total_orb, goal_bar.position + goal_bar.size / 2.0, new_size)

func _place_counter(counter: PitScoreView, center_px: Vector2, new_size: Vector2) -> void:
	counter.size = new_size
	counter.pivot_offset = new_size / 2.0
	counter.position = center_px - new_size / 2.0
	counter.queue_redraw()

## Setzt Basis + Mult (die Orbs ploppen bei echter Änderung selbst). Blendet
## den Gesamt-Orb aus und holt die Zähler an ihre Ruheplätze zurück.
func update_pit_score(base: int, mult: int) -> void:
	if base_counter.visible and base_counter.value == base and mult_counter.value == mult:
		return
	total_orb.visible = false
	base_counter.position = _base_home
	mult_counter.position = _mult_home
	base_counter.visible = true
	mult_counter.visible = true
	base_counter.set_value(base)
	mult_counter.set_value(mult)

var _crit_tween: Tween

## Krit-Einschlag (Ankunft eines Krit-Kometen): die Basis zieht normal nach,
## der Mult-Orb spannt sich überhell an (Hit-Stop), slammt dann auf den neuen
## Wert - Stoßwelle + Nachhall-Welle in Krit-Farbe, ×N-Zahl, abklingendes
## Beben, sauber zurück auf den Ruheplatz. Liefert die Gesamtdauer.
func crit_pit_mult(base: int, mult_after: int, crit_x: int) -> float:
	update_pit_score(base, mult_counter.value)
	if _crit_tween != null and _crit_tween.is_valid():
		_crit_tween.kill()
	var center := _mult_home + mult_counter.size / 2.0
	_crit_tween = create_tween()
	# 1) Hit-Stop: der Orb spannt sich an, die Zeit steht kurz still.
	_crit_tween.tween_callback(func() -> void:
		mult_counter.set_overbright(true)
		mult_counter.scale = Vector2.ONE * 1.3)
	_crit_tween.tween_interval(CRIT_HITSTOP)
	# 2) Slam: neuer Wert, Stoßwelle, ×N in Krit-Farbe.
	_crit_tween.tween_callback(func() -> void:
		mult_counter.scale = Vector2.ONE
		mult_counter.set_value(mult_after)
		_spawn_crit_wave(center, 1.1, 0.45, 1.0)
		spawn_gain_number(center, "×%d" % crit_x, CRIT_COLOR, 1.5))
	# Nachhall: zweite, kleinere Welle kurz versetzt.
	_crit_tween.tween_interval(CRIT_ECHO_DELAY)
	_crit_tween.tween_callback(func() -> void: _spawn_crit_wave(center, 0.7, 0.35, 0.6))
	# 3) Beben: abklingender Versatz, dann exakt auf den Ruheplatz zurück.
	_crit_tween.tween_method(func(p: float) -> void:
		var amp := CRIT_SHAKE_PX * (1.0 - p)
		mult_counter.position = _mult_home + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)),
		0.0, 1.0, CRIT_SHAKE_TIME)
	_crit_tween.tween_callback(func() -> void:
		mult_counter.position = _mult_home
		mult_counter.set_overbright(false))
	return CRIT_HITSTOP + CRIT_ECHO_DELAY + CRIT_SHAKE_TIME

func _spawn_crit_wave(center: Vector2, radius_frac: float, duration: float, alpha: float) -> void:
	var wave := ScoreShockwave.new()
	add_child(wave)
	wave.setup(center, Color(CRIT_COLOR.r, CRIT_COLOR.g, CRIT_COLOR.b, CRIT_COLOR.a * alpha),
		mult_counter.size.y * radius_frac, duration)

## Verschmelzungs-Zeremonie (siehe MERGE_*-Konstanten): Aufladen -> Umkreisen
## (beschleunigend) -> Hit-Stop -> Einschlag (überheiß, Stoßwelle) -> Halten.
## Liefert die GESAMTDAUER, damit der Aufrufer exakt so lange wartet.
func merge_orbs(total: int, clears_goal: bool) -> float:
	var gc := goal_bar.position + goal_bar.size / 2.0
	var base_target := gc - base_counter.size / 2.0
	var mult_target := gc - mult_counter.size / 2.0
	var base_start := base_counter.position
	var mult_start := mult_counter.position
	var tween := create_tween()
	# 1) Aufladen: beide Orbs leuchten heller, schwellen an und zittern.
	tween.tween_method(_apply_merge_charge, 0.0, 1.0, MERGE_CHARGE_TIME)
	# 2) Umkreisen: hart eingeblendet -> sichtbar in den Einschlag beschleunigen.
	tween.tween_method(func(p: float) -> void:
		base_counter.position = _merge_arc(base_start, base_target, p, 1.0)
		mult_counter.position = _merge_arc(mult_start, mult_target, p, -1.0),
		0.0, 1.0, MERGE_ORBIT_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	# 3) Hit-Stop: kurzer Freeze am Kontaktpunkt, dann 4) Einschlag.
	tween.tween_interval(MERGE_HITSTOP)
	tween.tween_callback(func() -> void: _slam_total(total, clears_goal))
	# 5) Halten: das Produkt wirkt nach, bevor irgendetwas weiterläuft.
	tween.tween_interval(MERGE_HOLD)
	return MERGE_CHARGE_TIME + MERGE_ORBIT_TIME + MERGE_HITSTOP + MERGE_HOLD

## Auflade-Takt: Basis/Mult heller (überhell -> bloomt), größer, mit feinem Zittern.
func _apply_merge_charge(c: float) -> void:
	var glow := 1.0 + 0.9 * c
	base_counter.modulate = Color(glow, glow, glow)
	mult_counter.modulate = Color(glow, glow, glow)
	var s := 1.0 + 0.14 * c
	base_counter.scale = Vector2(s, s)
	mult_counter.scale = Vector2(s, s)
	var tr := c * 7.0
	base_counter.position = _base_home + Vector2(randf_range(-tr, tr), randf_range(-tr, tr))
	mult_counter.position = _mult_home + Vector2(randf_range(-tr, tr), randf_range(-tr, tr))

## Bogen von a nach b: Grundfahrt plus seitlicher Ausschlag (sin), Seite je Orb.
func _merge_arc(a: Vector2, b: Vector2, p: float, side: float) -> Vector2:
	var straight := a.lerp(b, p)
	var span := a.distance_to(b)
	var dir := (b - a).normalized() if span > 0.001 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x) * side
	return straight + perp * sin(p * PI) * span * MERGE_ARC_FRAC

func _slam_total(total: int, clears_goal: bool) -> void:
	base_counter.visible = false
	mult_counter.visible = false
	base_counter.position = _base_home
	mult_counter.position = _mult_home
	# Auflade-Effekte zurücksetzen (die Orbs werden nächste Runde wiederverwendet).
	base_counter.modulate = Color.WHITE
	mult_counter.modulate = Color.WHITE
	base_counter.scale = Vector2.ONE
	mult_counter.scale = Vector2.ONE
	var gc := goal_bar.position + goal_bar.size / 2.0
	total_orb.position = gc - total_orb.size / 2.0
	total_orb.scale = Vector2.ONE
	total_orb.modulate = Color.WHITE
	total_orb.set_overbright(clears_goal)
	total_orb.set_value_silent(0)  # von 0 hochploppen
	total_orb.visible = true
	total_orb.set_value(total)     # eigener Squash-Pop
	total_orb.pop()
	var wave := ScoreShockwave.new()
	add_child(wave)
	var wave_color := Color(2.4, 2.2, 1.6, 0.9) if clears_goal else Color(2.0, 1.6, 0.3, 0.85)
	wave.setup(gc, wave_color, total_orb.size.y * 0.9, 0.5)

## Aktualisiert die Gesamtzahl (Nach-Schritte auf der Summe) - kein neuer Merge.
func update_pit_total(total: int, clears_goal: bool) -> void:
	total_orb.set_overbright(clears_goal)
	total_orb.set_value(total)

## Setzt die Daueranzeige still auf 0 / 0 und blendet den Gesamt-Orb aus.
## Bricht auch einen laufenden Krit-Einschlag ab (sonst setzte er nach dem
## Reset noch seinen alten Wert).
func reset_pit_score() -> void:
	if _crit_tween != null and _crit_tween.is_valid():
		_crit_tween.kill()
	total_orb.visible = false
	base_counter.position = _base_home
	mult_counter.position = _mult_home
	base_counter.visible = true
	mult_counter.visible = true
	mult_counter.scale = Vector2.ONE
	mult_counter.set_overbright(false)
	base_counter.set_value_silent(0)
	mult_counter.set_value_silent(0)

## Drain-API (der Aufrufer treibt einen segmentierten Tween, damit der Balken 1:1
## mitfüllt und an jeder Überladungs-Schwelle kurz innehält):
## begin_total_drain streut die Funken über die Gesamtdauer, set_total_drain(f)
## schrumpft/verblasst den Orb nach Fortschritt f (0..1), finish räumt auf.
func begin_total_drain(duration: float) -> void:
	var gc := goal_bar.position + goal_bar.size / 2.0
	var sparks := maxi(DRAIN_SPARKS, int(duration * 6.0))
	for i in sparks:
		var delay := duration * float(i) / float(sparks)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			_drain_spark(gc, 0.35))

func set_total_drain(f: float) -> void:
	var t := clampf(f, 0.0, 1.0)
	var s := lerpf(1.0, 0.25, t)
	total_orb.scale = Vector2(s, s)
	total_orb.modulate.a = 1.0 - t

func finish_total_drain() -> void:
	total_orb.scale = Vector2.ONE
	total_orb.modulate = Color.WHITE
	reset_pit_score()
	pulse_goal_bar()

## Ein kurzer Funke vom schrumpfenden Orb in den Balken (kleiner Radialversatz).
func _drain_spark(center_px: Vector2, travel: float) -> void:
	var angle := randf() * TAU
	var from := center_px + Vector2(cos(angle), sin(angle)) * total_orb.size.y * 0.35
	var pulse := TracePulseView.new()
	add_child(pulse)
	pulse.setup(PackedVector2Array([from, center_px]), PitScoreView.TOTAL_COLOR,
		SCORE_PULSE_CORE, SCORE_PULSE_GLOW, travel, SCORE_COMET * 0.5)

## Schwebende Zuwachs-Zahl der Zähl-Animation ("+3", "×2"): steigt aus dem
## Würfel auf und gleitet ausblendend nach unten weg. Rein schmückend -
## die maßgeblichen Zahlen laufen über die Zähler. Räumt sich selbst weg.
const GAIN_FONT := 19 * SUPERSAMPLE
const GAIN_DRIFT := 170.0 * SUPERSAMPLE
const GAIN_TIME := 1.6
const GAIN_OUTLINE := Color(0.05, 0.03, 0.08)
## Bewegungs-Unschärfe: kontinuierlicher Farbschleier hinter der Zahl (am
## Glyph deckend, zum Schwanz auslaufend), begrenzt auf GAIN_BLUR_LENGTH.
const GAIN_BLUR_LENGTH := 55.0 * SUPERSAMPLE
const GAIN_BLUR_WIDTH := 0.8   # Anteil der Zahlbreite
const GAIN_BLUR_ALPHA := 0.6

var _gain_blur_texture: GradientTexture2D  # geteilter Verlauf, einmalig gebaut

func spawn_gain_number(from_px: Vector2, text: String, color: Color, font_scale: float = 1.0) -> void:
	var label := _make_gain_label(text, color, font_scale)
	var streak := _make_gain_blur(color)
	add_child(streak)  # zuerst = unter der Zahl
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size / 2.0
	var start := from_px - label.size / 2.0
	label.position = start
	label.scale = Vector2.ONE * 1.35
	var width := label.size.x * GAIN_BLUR_WIDTH
	var center_x := start.x + label.size.x / 2.0
	var half_h := label.size.y / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		func(dist: float) -> void: _advance_gain_number(label, streak, start, center_x, width, half_h, dist),
		0.0, GAIN_DRIFT, GAIN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, GAIN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(streak, "modulate:a", 0.0, GAIN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		label.queue_free()
		streak.queue_free())

## Rückt die Zahl auf ihre Gleithöhe und spannt den Schleier von der Kopfmitte
## um bis zu GAIN_BLUR_LENGTH nach oben auf.
func _advance_gain_number(label: Label, streak: TextureRect, start: Vector2, center_x: float, width: float, half_h: float, dist: float) -> void:
	label.position.y = start.y + dist
	var bottom := start.y + dist + half_h
	var top := maxf(start.y + half_h, bottom - GAIN_BLUR_LENGTH)
	streak.position = Vector2(center_x - width / 2.0, top)
	streak.size = Vector2(width, maxf(bottom - top, 1.0))

func _make_gain_blur(color: Color) -> TextureRect:
	if _gain_blur_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0)])
		_gain_blur_texture = GradientTexture2D.new()
		_gain_blur_texture.gradient = gradient
		_gain_blur_texture.fill_from = Vector2(0, 0)  # oben (Schwanz) transparent
		_gain_blur_texture.fill_to = Vector2(0, 1)    # unten (Kopf) deckend
		_gain_blur_texture.width = 8
		_gain_blur_texture.height = 64
	var streak := TextureRect.new()
	streak.texture = _gain_blur_texture
	streak.stretch_mode = TextureRect.STRETCH_SCALE
	streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak.modulate = Color(color.r, color.g, color.b, GAIN_BLUR_ALPHA)
	return streak

func _make_gain_label(text: String, color: Color, font_scale: float = 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(GAIN_FONT * font_scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", GAIN_OUTLINE)
	label.add_theme_constant_override("outline_size", 3 * SUPERSAMPLE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Goldenes Leucht-Podest unter einem zählenden/ausgewählten Würfel.
## side_px = Kantenlänge; der Aufrufer hält und entsorgt die Knoten.
func spawn_glow(center_px: Vector2, side_px: float, intensity: float = 1.0) -> Control:
	var glow := Panel.new()
	glow.size = Vector2(side_px, side_px)
	glow.position = center_px - glow.size / 2.0
	glow.pivot_offset = glow.size / 2.0
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = GLOW_COLOR
	box.set_corner_radius_all(int(side_px * 0.22))
	glow.add_theme_stylebox_override("panel", box)
	glow.modulate = Color(1, 1, 1, 0)
	add_child(glow)
	var tween := create_tween()
	tween.tween_property(glow, "modulate:a", clampf(intensity, 0.0, 1.0), 0.25)
	return glow

## --- Wertungs-Kometen (Zähl-Animation über die Score-Leisten) ------------------

## EINE Licht-Geschwindigkeit für alle Zähl-Kometen (px/s im SUPERSAMPLE-Raum):
## die Dauer folgt der Pfadlänge, so überholt kein Komet auf gleicher Leiste.
## Schnell genug, dass die ankunfts-getaktete Sequenz nicht zäh wird.
const SCORE_PULSE_SPEED := 2400.0 * SUPERSAMPLE
const SCORE_PULSE_CORE := 4.0 * SUPERSAMPLE
const SCORE_PULSE_GLOW := 12.0 * SUPERSAMPLE
const SCORE_COMET := 90.0 * SUPERSAMPLE  # Kometen-Fensterlänge

## Farben der Zähl-Kometen (überhell, bloomen): Basis cyan, Mult gold.
const SCORE_BASE_COLOR := Color(0.5, 2.0, 2.0, 0.95)
const SCORE_MULT_COLOR := Color(2.0, 1.6, 0.3, 0.95)

## Bank-Entladung (Rundenauszahlung): gemächlicherer, dickerer Komet aus dem
## Zielbalken, der die Grube umrundet und in den Hub fährt. Bewusst langsamer als
## die Zähl-Kometen (feierlicher Abtransport der geronnenen Punkte).
const BANK_PULSE_SPEED := 1500.0 * SUPERSAMPLE
const BANK_PULSE_CORE := 5.5 * SUPERSAMPLE
const BANK_PULSE_GLOW := 18.0 * SUPERSAMPLE
const BANK_COMET := 170.0 * SUPERSAMPLE

## Öffentlicher Zugriff auf die Stufenfarbe (scene_root taktet die Bank-Entladung).
func stage_fill_color(stage: int) -> Color:
	return _stage_fill_color(stage)

## Bank-Komet: fährt vom Zielbalken senkrecht auf den Grube-Datenbus, an der
## Grube-Oberkante SPALTET er sich (zwei Halb-Kometen um den Grubenrand, links und
## rechts), vereint sich unten wieder und fährt über die Bank-Leiste in den Hub.
## Beide Hälften teilen sich Bus und Bank-Leiste (dort überlagern sie zu EINEM
## Kometen) und laufen nur um die Grube auseinander. Liefert die Laufzeit.
func bank_comet(stage_color: Color) -> float:
	var left := _bank_route(false)
	var right := _bank_route(true)
	if left.size() < 2:
		return 0.0
	var travel := maxf(0.2, _path_length(left) / BANK_PULSE_SPEED)
	var color := _bank_comet_color(stage_color)
	for route in [left, right]:
		var pulse := TracePulseView.new()
		add_child(pulse)
		pulse.setup(route, color, BANK_PULSE_CORE, BANK_PULSE_GLOW, travel, BANK_COMET)
	return travel

## Überhelle Kometenfarbe aus einer Stufen-Füllfarbe (Alpha weg, Werte hoch -> Bloom).
func _bank_comet_color(stage_color: Color) -> Color:
	return Color(stage_color.r * 1.8, stage_color.g * 1.8, stage_color.b * 1.8, 0.95)

## Halb-Route des Bank-Kometen (to_right = rechte Grubenhälfte, sonst linke).
## Zielbalken -> Grube-Datenbus -> um die Grubenhälfte -> Bank-Leiste -> Hub-Oberkante.
func _bank_route(to_right: bool) -> PackedVector2Array:
	var path := PackedVector2Array()
	if goal_bar == null or pit_window == null or hub == null:
		return path
	var gb := goal_bar.position + goal_bar.size * 0.5
	var pr := Rect2(pit_window.position, pit_window.size)
	var pcx := pr.get_center().x
	var pit_top := pr.position.y
	var pit_bottom := pr.end.y
	var side_x := pr.end.x if to_right else pr.position.x
	var hub_cx := hub.position.x + hub.size.x * 0.5
	var hub_top := hub.position.y
	path.append(gb)                          # Start: Zielbalken-Mitte
	path.append(Vector2(gb.x, score_rect.end.y))  # runter auf die Score-Unterkante
	path.append(Vector2(pcx, score_rect.end.y))   # rüber auf die Grubenspalte
	path.append(Vector2(pcx, pit_top))       # Datenbus runter an die Grube-Oberkante
	path.append(Vector2(side_x, pit_top))    # Spaltung: an die Ecke der Grubenhälfte
	path.append(Vector2(side_x, pit_bottom)) # an der Grubenseite entlang nach unten
	path.append(Vector2(pcx, pit_bottom))    # Wiedervereinigung unten mittig
	path.append(Vector2(hub_cx, hub_top))    # Bank-Leiste in die Hub-Oberkante
	return path

## Entlädt den Zielbalken auf die gegebene Restfüllung (0..1) in der neuen Farbe -
## eine Stufe „fließt" mit ihrem Bank-Komet aus dem Balken. Läuft nebenher.
func drain_goal_bar(fraction: float, color: Color, duration: float) -> void:
	if goal_bar_base == null:
		return
	goal_bar_fill.size.x = 0.0  # Teilstufe zuerst räumen (nur volle Stufen entladen)
	var full_w := GOAL_BAR_SIZE.x - GOAL_BAR_INSET * 2.0
	goal_bar_base.color = color
	var tween := create_tween()
	tween.tween_property(goal_bar_base, "size:x", full_w * clampf(fraction, 0.0, 1.0), duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _score_strip(source: String) -> LedStripView:
	match source:
		"combos": return combos_score_strip
		_: return pit_score_strip

## Ziel-Ankerpunkt (Screen-px) im Score-Bildschirm.
func _score_target_px(target: String) -> Vector2:
	if target == "total":
		return goal_bar.position + goal_bar.size / 2.0
	var counter := base_counter if target == "base" else mult_counter
	return counter.position + counter.value_anchor()

## Vollständige Route eines Zähl-Kometen: Quelle -> passende Leiste -> Zähler.
## L-Anschlüsse an beiden Enden halten alles achsenparallel (Leiterbahn-Look).
## Charm-Quellen laufen über die Sammelschiene (Konsole -> Schiene -> Stamm).
func score_route(from_px: Vector2, source: String, target: String) -> PackedVector2Array:
	var to_px := _score_target_px(target)
	if source == "charm":
		return _charm_route(from_px, to_px)
	var strip := _score_strip(source)
	var path := PackedVector2Array([from_px])
	if strip != null and strip.strip_path.size() >= 2:
		var entry := strip.strip_path[0]
		var exit := strip.strip_path[strip.strip_path.size() - 1]
		path.append(Vector2(from_px.x, entry.y))  # senkrecht auf die Quell-Kante
		for p in strip.strip_path:
			path.append(p)
		path.append(Vector2(exit.x, to_px.y))     # senkrecht auf Zähler-Höhe
	path.append(to_px)
	return path

## Feuert einen Zähl-Kometen entlang der Route und liefert seine Laufzeit
## (Ankunft = wenn der Aufrufer die Zahl setzt). color_override (Alpha > 0)
## übersteuert die Leisten-Farbe - Krit-Kometen laufen in Krit-Magenta.
func score_comet(from_px: Vector2, source: String, target: String, color_override := Color(0, 0, 0, 0)) -> float:
	var path := score_route(from_px, source, target)
	if path.size() < 2:
		return 0.0
	var travel := maxf(0.15, _path_length(path) / SCORE_PULSE_SPEED)
	var color := SCORE_BASE_COLOR if target == "base" else SCORE_MULT_COLOR
	if target == "total":
		color = PitScoreView.TOTAL_COLOR
	if color_override.a > 0.0:
		color = color_override
	var pulse := TracePulseView.new()
	add_child(pulse)
	pulse.setup(path, color, SCORE_PULSE_CORE, SCORE_PULSE_GLOW, travel, SCORE_COMET)
	return travel

## Allgemeine Leiterbahn zwischen zwei Display-Punkten (achsenparallele Treppe).
func spawn_trace(from_px: Vector2, to_px: Vector2, color: Color, duration: float) -> void:
	from_px = from_px.clamp(Vector2.ONE * TRAIL_MARGIN, Vector2(size) - Vector2.ONE * TRAIL_MARGIN)
	var trace := ScoreTraceView.new()
	add_child(trace)
	trace.setup(_orthogonal_path(from_px, to_px), color, TRACE_CORE_WIDTH, TRACE_GLOW_WIDTH, duration)

## Treppe in drei Stufen: senkrecht aus der Quelle (TRACE_RISE, über die
## Nachbar-Würfel), waagerecht auf die Ziel-Spalte, senkrecht ins Ziel.
## Liegen Quelle und Ziel auf einer Achse, reicht die gerade Linie.
func _orthogonal_path(from_px: Vector2, to_px: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array()
	path.append(from_px)
	if absf(to_px.x - from_px.x) <= 1.0 or absf(to_px.y - from_px.y) <= 1.0:
		path.append(to_px)
		return path
	# Hub Richtung Ziel, höchstens bis zur halben Strecke (kein Überschwingen).
	var direction := signf(to_px.y - from_px.y)
	var lane_y := from_px.y + direction * minf(TRACE_RISE, absf(to_px.y - from_px.y) * 0.5)
	path.append(Vector2(from_px.x, lane_y))
	path.append(Vector2(to_px.x, lane_y))
	path.append(to_px)
	return path

## Spannt den Hub auf (Mitte + Größe in Display-Pixeln) und baut den Inhalt.
func place_hub(center_px: Vector2, size_px: Vector2) -> void:
	hub.size = size_px
	hub.position = center_px - size_px / 2.0
	hub.layout()
	_sync_reflection_windows()

## Aderbreite beider Hub-Leisten (schlank = zurückhaltend).
const HUB_STRIP_WIDTH := 3.4 * SUPERSAMPLE

## Gemeinsame Korridor-Höhe beider Hub-Leisten: mittig zwischen Grube-Unterkante
## und Hub-Oberkante - dort läuft ihr waagerechter Teil (unter der Grube).
func _hub_strip_lane_y() -> float:
	var hub_top := hub.position.y
	var obstacle_bottom := hub_top
	if pit_window != null and pit_window.visible:
		obstacle_bottom = pit_window.position.y + pit_window.size.y
	var lane_y := (obstacle_bottom + hub_top) * 0.5
	return minf(lane_y, hub_top - 6.0 * SUPERSAMPLE)  # zur Not knapp über der Hub-Oberkante

## Gespiegelte Austrittspunkte an der Hub-Oberkante (Kombi links, Schatz rechts).
func _hub_strip_exit_x(to_right: bool) -> float:
	var cx := hub.position.x + hub.size.x * 0.5
	var d := hub.size.x * 0.25
	return cx + d if to_right else cx - d

## Verlegt die LED-Leiste zwischen Hub (oben links) und Kombinationen-Fenster
## (nach place_hub UND place_combo_cluster rufen).
func link_hub_to_cluster() -> void:
	if led_strip == null or hub == null or hub.size.x <= 0.0:
		return
	led_strip.link_from_hub_top(Rect2(hub.position, hub.size), cluster_rect,
		HUB_STRIP_WIDTH, _hub_strip_exit_x(false), _hub_strip_lane_y())

## Installiert bzw. entfernt das Nebenwetten-Fenster (Hub-Stufe 3). Blendet das
## Fenster ein/aus, synchronisiert die Glas-Spiegelung und die Schatz-Ader-
## Abzweigung (Fork). place_side_bet_window muss zuvor Position/Größe gesetzt haben.
func set_side_bet_installed(installed: bool) -> void:
	if side_bet_window == null or side_bet_window.size.x <= 0.0:
		return  # noch nicht platziert
	if side_bet_window.visible == installed:
		return
	side_bet_window.visible = installed
	_sync_reflection_windows()
	link_hub_to_treasure()  # Fork zum Fenster erscheint/verschwindet mit der Sichtbarkeit

## Installations-Zeremonie (Hub-Stufe 3): Stoßwelle am frisch installierten
## Nebenwetten-Fenster + ein Komet vom Hub die Schatz-Ader entlang zur neuen
## Hardware. Liefert die Kometen-Laufzeit.
func celebrate_side_bet_install(color: Color) -> float:
	if side_bet_window == null or not side_bet_window.visible:
		return 0.0
	var center := side_bet_window.position + side_bet_window.size * 0.5
	var wave := ScoreShockwave.new()
	add_child(wave)
	wave.setup(center, Color(color.r, color.g, color.b, 0.9), side_bet_window.size.x * 0.6, 0.6)
	return side_bet_stake_comet(true, color)

## Freischaltungs-Zeremonie eines Automaten: Stoßwelle am Automaten-Fenster.
func celebrate_slot_bank_install(color: Color) -> void:
	if slot_bank_window == null or not slot_bank_window.visible:
		return
	var center := slot_bank_window.position + slot_bank_window.size * 0.5
	var wave := ScoreShockwave.new()
	add_child(wave)
	wave.setup(center, Color(color.r, color.g, color.b, 0.9), slot_bank_window.size.x * 0.6, 0.6)

## Verlegt die LED-Leiste vom Hub (oben rechts) an die UNTERKANTE des Schatz-Screens.
func link_hub_to_treasure() -> void:
	if treasure_strip == null or hub == null or hub.size.x <= 0.0 \
			or treasure_window == null or not treasure_window.visible:
		return
	treasure_strip.link_from_hub_top(Rect2(hub.position, hub.size),
		Rect2(treasure_window.position, treasure_window.size),
		HUB_STRIP_WIDTH, _hub_strip_exit_x(true), _hub_strip_lane_y())
	# T-Stück: die Geld-Ader zweigt im Korridor zusätzlich zu den Nebenwetten ab.
	if side_bet_window != null and side_bet_window.visible:
		treasure_strip.fork_to(Rect2(side_bet_window.position, side_bet_window.size))

## --- Wertungs-Leisten (Grube/Kombis -> Score) ----------------------------------

## Die Grube-Leiste ist der Datenbus (dicker); die Kombi-Leiste bleibt schlank.
const SCORE_STRIP_WIDTH := 3.4 * SUPERSAMPLE
const SCORE_BUS_WIDTH := 4.8 * SUPERSAMPLE

## Korridor zwischen Score-Unterkante und Grube-Oberkante (dort läuft der
## waagerechte Teil der Kombi-Leiste, klar über der Grube).
func _score_lane_y() -> float:
	var score_bottom := score_rect.end.y
	var pit_top := score_bottom + 24.0 * SUPERSAMPLE
	if pit_window != null and pit_window.visible:
		pit_top = pit_window.position.y
	return (score_bottom + pit_top) * 0.5

## Verlegt die Grube- und Kombi-Leiste in den Wertungs-Bildschirm (nach
## place_score_screen, place_pit_window UND place_combo_cluster rufen).
func link_score_strips() -> void:
	if score_frame == null or not score_frame.visible:
		return
	var lane := _score_lane_y()
	var score_bottom := score_rect.end.y
	# Grube -> Score: senkrechter Datenbus (Grubenmitte in die Score-Mitte).
	if pit_score_strip != null and pit_window != null and pit_window.visible:
		var pit_cx := pit_window.position.x + pit_window.size.x * 0.5
		pit_score_strip.link_edges(pit_window.position.y, pit_cx, score_bottom, pit_cx,
			lane, SCORE_BUS_WIDTH)
	# Grube -> Hub: Bank-Leiste im Korridor zwischen Grube-Unterkante und Hub-Oberkante
	# (mittig, zwischen den beiden Hub-Ecken-Austritten von Kombi/Schatz).
	if pit_hub_strip != null and pit_window != null and pit_window.visible \
			and hub != null and hub.size.x > 0.0:
		var pcx := pit_window.position.x + pit_window.size.x * 0.5
		var pit_bottom := pit_window.position.y + pit_window.size.y
		var hub_cx := hub.position.x + hub.size.x * 0.5
		var hub_top := hub.position.y
		pit_hub_strip.link_edges(pit_bottom, pcx, hub_top, hub_cx,
			(pit_bottom + hub_top) * 0.5, SCORE_BUS_WIDTH)
	# Kombinationen -> Score: von der Kombi-Oberkante in einen linken Score-Port.
	if combos_score_strip != null and cluster_frame != null:
		var exit_x := cluster_rect.get_center().x + cluster_rect.size.x * 0.25
		var enter_x := score_rect.position.x + score_rect.size.x * 0.25
		combos_score_strip.link_edges(cluster_rect.position.y, exit_x, score_bottom, enter_x,
			lane, SCORE_STRIP_WIDTH)
	# Charm-Konsolen -> Score: je Konsole eine Ader, gebündelt wie ein Kabelbaum.
	_link_charm_strips()

## Verlegt die Charm-Adern geordnet: je Konsole eine kurze senkrechte Ader auf
## EINE gemeinsame waagerechte Sammelschiene unter den Charms; die Schiene läuft
## als Stamm mittig in die Score-Oberkante.
func _link_charm_strips() -> void:
	if charm_dock == null or not charm_dock.visible or score_frame == null or not score_frame.visible:
		return
	var consoles := charm_dock.console_rects()
	var n := mini(consoles.size(), charm_score_strips.size())
	if n == 0:
		return
	var score_top := score_rect.position.y
	var console_bottom := consoles[0].end.y
	_charm_rail_y = lerpf(console_bottom, score_top, 0.32)  # Schiene knapp unter den Charms
	_charm_trunk_x = score_rect.get_center().x
	var rail_left := consoles[0].get_center().x
	var rail_right := consoles[n - 1].get_center().x
	for i in n:
		var cx := consoles[i].get_center().x
		# Kurze senkrechte Ader von der Konsolen-Unterkante auf die Schiene.
		charm_score_strips[i].link_edges(console_bottom, cx, _charm_rail_y, cx,
			_charm_rail_y, SCORE_STRIP_WIDTH)
	charm_bus_strip.link_tee(minf(rail_left, _charm_trunk_x), maxf(rail_right, _charm_trunk_x),
		_charm_rail_y, _charm_trunk_x, score_top, SCORE_BUS_WIDTH)

## Kometen-Route eines Charm-Schritts: Karte -> senkrecht auf die Schiene ->
## waagerecht zum Stamm -> senkrecht in den Score bis zur Zielzahl.
func _charm_route(from_px: Vector2, to_px: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		from_px,
		Vector2(from_px.x, _charm_rail_y),
		Vector2(_charm_trunk_x, _charm_rail_y),
		Vector2(_charm_trunk_x, score_rect.position.y),
		Vector2(_charm_trunk_x, to_px.y),
		to_px])

## Spannt das Charm-Dock über die 6 Blenden-Pixelmitten auf (pad_size = Kachel,
## proj_radius = Kraftfeld-/Beam-Radius in px für den Projektor).
func place_charm_dock(pad_centers_px: PackedVector2Array, pad_size: Vector2, proj_radius: float) -> void:
	if charm_dock == null:
		return
	charm_dock.place(pad_centers_px, pad_size, proj_radius)
	charm_dock.visible = true
	_sync_reflection_windows()

## --- Kauf-Lichtlauf einer Übertaktung ------------------------------------------

## EINE Licht-Geschwindigkeit für ALLE Leisten-Läufe zwischen Screens (px/s):
## die Dauer folgt aus der Pfadlänge, damit jede Verbindung gleich schnell wirkt.
const PULSE_SPEED := 680.0 * SUPERSAMPLE
const OVERCLOCK_FLASH_COLOR := Color("#ffd319")
## Kurzer, gedämpfter Komet (deutlich dünner/dunkler als die Wertungs-Trails).
const OVERCLOCK_PULSE_COLOR := Color(1.3, 1.0, 0.3, 0.6)
const OVERCLOCK_PULSE_CORE := 3.0 * SUPERSAMPLE
const OVERCLOCK_PULSE_GLOW := 7.0 * SUPERSAMPLE
const OVERCLOCK_COMET := 34.0 * SUPERSAMPLE  # Kometen-Länge (sehr kurz)

var _cluster_flash_tween: Tween

## Der (durch die Geld-Ankünfte) voll geladene Hub entlädt sich RESTLOS in die
## Leiste: das Licht schießt los, der Rahmen erlischt ohne Nachglühen, der
## Fenster-Rahmen pulst bei Ankunft, dann laufen vier Bus-Kometen GLEICHZEITIG
## von den Randkontakten zum Chip. Der Aufrufer wartet das await ab und wendet
## erst bei Ankunft die sichtbare Wert-Änderung an.
func play_overclock_pulse(combo_key: String) -> void:
	var link_time := 0.4
	if led_strip != null and led_strip.strip_path.size() >= 2:
		link_time = _travel_time(led_strip.strip_path)
		_pulse_along(led_strip.strip_path, link_time)
	if hub != null:
		hub.charge_gold(1.0)  # sicherstellen: voll geladen, dann komplett abgeben
		hub.discharge_gold(minf(0.35, link_time * 0.6))
	await get_tree().create_timer(link_time).timeout
	flash_cluster_frame(OVERCLOCK_FLASH_COLOR)
	var index := DiceScoring.HAND_PRIORITY.find(combo_key)
	var board_time := 0.3
	if circuit_board != null and index != -1:
		var paths := circuit_board.paths_to_cell(index)
		# Gleiche Dauer für alle vier Pfade (gleichzeitige Ankunft); die Dauer
		# folgt dem LÄNGSTEN Pfad bei einheitlicher Geschwindigkeit.
		var longest := 0.0
		for path in paths:
			longest = maxf(longest, _path_length(path))
		board_time = maxf(0.12, longest / PULSE_SPEED)
		for path in paths:
			var screen_path := PackedVector2Array()
			for p in path:
				screen_path.append(p + circuit_board.position)
			_pulse_along(screen_path, board_time)
	await get_tree().create_timer(board_time).timeout

## Leiterbahn-Route Quelle -> Ader -> Ziel: L-Anschluss auf den Ader-Anfang, die
## Ader selbst, L-Anschluss ins Ziel. Alles achsenparallel, wie score_route.
## Ohne verlegte Ader bleibt die gerade Verbindung (headless/Tests).
func _route_via_strip(from_px: Vector2, strip: LedStripView, to_px: Vector2) -> PackedVector2Array:
	return _route_via_strips(from_px, [strip], to_px)

## Dasselbe über MEHRERE Adern hintereinander: das Licht fährt von Ader zu Ader,
## statt quer über den Tisch zu fliegen (Automaten -> Hub -> Werkbank). Endet die
## eine Ader am Rand eines Fensters und beginnt die nächste an einem anderen Rand
## DESSELBEN Fensters, fährt das Licht den Fensterrahmen entlang - nie mitten
## durch einen fremden Bildschirm.
func _route_via_strips(from_px: Vector2, strips: Array, to_px: Vector2) -> PackedVector2Array:
	var laid: Array[LedStripView] = []
	for strip: LedStripView in strips:
		if strip != null and strip.strip_path.size() >= 2:
			laid.append(strip)
	if laid.is_empty():
		return PackedVector2Array([from_px, to_px])
	var path := PackedVector2Array([from_px])
	var here := from_px
	for strip in laid:
		var entry := strip.strip_path[0]
		var crossed := _window_between(here, entry)
		if crossed.size.x > 0.0:
			for corner in _border_route(crossed, here, entry):
				path.append(corner)
		else:
			path.append(Vector2(entry.x, here.y))  # waagerecht an den Ader-Kopf heran
		for p in strip.strip_path:
			path.append(p)
		here = strip.strip_path[strip.strip_path.size() - 1]
	path.append(Vector2(here.x, to_px.y))
	path.append(to_px)
	return path

## Fenster, auf dessen RAND beide Punkte liegen (das Licht müsste sonst quer
## hindurch); Rect2() wenn keins. Kandidaten sind die großen Durchfahrt-Fenster.
func _window_between(a: Vector2, b: Vector2) -> Rect2:
	var candidates: Array = [hub, workshop_window, slot_bank_window, side_bet_window]
	for window in candidates:
		if window == null or not window.visible or window.size.x <= 0.0:
			continue
		var rect := Rect2(window.position, window.size)
		if _perimeter_t(rect, a) >= 0.0 and _perimeter_t(rect, b) >= 0.0:
			return rect
	return Rect2()

## Lauflänge eines Randpunkts im Uhrzeigersinn ab der linken oberen Ecke;
## -1, wenn der Punkt nicht auf dem Rand liegt (Toleranz 1 px).
func _perimeter_t(rect: Rect2, p: Vector2) -> float:
	const EPS := 1.0
	var w := rect.size.x
	var h := rect.size.y
	var inside_x := p.x >= rect.position.x - EPS and p.x <= rect.end.x + EPS
	var inside_y := p.y >= rect.position.y - EPS and p.y <= rect.end.y + EPS
	if absf(p.y - rect.position.y) <= EPS and inside_x:
		return clampf(p.x - rect.position.x, 0.0, w)
	if absf(p.x - rect.end.x) <= EPS and inside_y:
		return w + clampf(p.y - rect.position.y, 0.0, h)
	if absf(p.y - rect.end.y) <= EPS and inside_x:
		return w + h + clampf(rect.end.x - p.x, 0.0, w)
	if absf(p.x - rect.position.x) <= EPS and inside_y:
		return w + h + w + clampf(rect.end.y - p.y, 0.0, h)
	return -1.0

func _perimeter_point(rect: Rect2, t: float) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	if t <= w:
		return Vector2(rect.position.x + t, rect.position.y)
	if t <= w + h:
		return Vector2(rect.end.x, rect.position.y + (t - w))
	if t <= w + h + w:
		return Vector2(rect.end.x - (t - w - h), rect.end.y)
	return Vector2(rect.position.x, rect.end.y - (t - w - h - w))

## Die Ecken des Fensterrahmens zwischen from und to, über die KÜRZERE Seite.
## from/to selbst hängt der Aufrufer an; beide müssen auf dem Rand liegen.
func _border_route(rect: Rect2, from: Vector2, to: Vector2) -> PackedVector2Array:
	var w := rect.size.x
	var h := rect.size.y
	var perim := 2.0 * (w + h)
	var t0 := _perimeter_t(rect, from)
	var t1 := _perimeter_t(rect, to)
	var path := PackedVector2Array()
	if t0 < 0.0 or t1 < 0.0 or perim <= 0.0:
		return path
	var cw := fposmod(t1 - t0, perim)
	var dir := 1.0 if cw <= perim - cw else -1.0
	var dist := cw if dir > 0.0 else perim - cw
	# Ecken in Laufrichtung einsammeln (nur die ECHT zwischen den Punkten).
	var ahead_list: Array[float] = []
	for corner_t in [0.0, w, w + h, w + h + w]:
		var ahead := fposmod((corner_t - t0) * dir, perim)
		if ahead > 0.5 and ahead < dist - 0.5:
			ahead_list.append(ahead)
	ahead_list.sort()
	for ahead in ahead_list:
		path.append(_perimeter_point(rect, fposmod(t0 + dir * ahead, perim)))
	return path

## Liefer-Komet Laden -> Werkstatt: das gekaufte Paket FÄHRT als Licht die
## Hub-Werkstatt-Ader entlang, statt im Lager zu erscheinen. Liefert die Laufzeit.
func pack_delivery_comet(from_px: Vector2, color: Color) -> float:
	if workshop_window == null or not workshop_window.visible:
		return 0.0
	var to_px := workshop_window.position + workshop_window.size * 0.5
	var path := _route_via_strip(from_px, workshop_hub_strip, to_px)
	var travel := _travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## Laufzeit der Automaten-Ader (Hub <-> Automaten) für die Ablauf-Planung außen.
func slot_pay_travel_time() -> float:
	if slot_hub_strip == null or slot_hub_strip.strip_path.size() < 2:
		return 0.0
	return _travel_time(slot_hub_strip.strip_path)

## Einsatz-Komet Hub -> Automaten: die zweite Etappe der Münze (die erste fuhr als
## money_comet vom Münzfenster in den Hub). Liefert die Laufzeit.
func slot_pay_comet(color: Color) -> float:
	if slot_hub_strip == null or slot_hub_strip.strip_path.size() < 2:
		return 0.0
	var path := slot_hub_strip.strip_path.duplicate()
	path.reverse()  # verlegt ist sie Automaten -> Hub; der Einsatz fährt dagegen
	var travel := _travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## Gewinn-Komet Automaten -> Hub (Charms): fährt die Automaten-Ader in ihrer
## verlegten Richtung. Liefert die Laufzeit.
func slot_prize_comet(from_px: Vector2, color: Color) -> float:
	if slot_hub_strip == null or slot_hub_strip.strip_path.size() < 2 or hub == null:
		return 0.0
	var path := _route_via_strip(from_px, slot_hub_strip, hub.position + hub.size * 0.5)
	var travel := _travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## Gewonnene Gravur: den ganzen Weg über die Adern - Automaten-Ader in den Hub,
## Werkstatt-Ader zur Werkbank, Schubladen-Ader in den Platz. Quer über den Tisch
## fliegt hier nichts; erst der letzte Meter ist ein freier Bogen wie beim Paket.
func slot_engraving_route(from_px: Vector2, category: String, slot_px: Vector2) -> PackedVector2Array:
	var supply := _supply_strip(category)
	return _route_via_strips(from_px, [slot_hub_strip, workshop_hub_strip, supply], slot_px)

func slot_engraving_comet(from_px: Vector2, category: String, slot_px: Vector2,
		color: Color) -> float:
	var path := slot_engraving_route(from_px, category, slot_px)
	var travel := _travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## Freiflug ohne Ader (gewonnener Würfel -> Vorrats-Ablage): zu den 3D-Ablagen
## führt keine Leiterbahn, also fliegt das Licht als Bogen wie ein Meteor. Start
## ist das Ende der Automaten-Ader am Hub, nicht das Fenster - so hängt auch der
## Würfel am Adernetz, statt quer über den Tisch zu schießen.
func tray_comet(from_px: Vector2, to_px: Vector2, color: Color, spread_index: int) -> float:
	var launch := from_px
	if slot_hub_strip != null and slot_hub_strip.strip_path.size() >= 2:
		launch = slot_hub_strip.strip_path[slot_hub_strip.strip_path.size() - 1]
	var path := _route_via_strips(from_px, [slot_hub_strip], launch)
	for p in _meteor_launch(launch, to_px, spread_index):
		path.append(p)
	var travel := _travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## Seitliche Ausbruch-Weiten der Meteore, zyklisch je Stück - so fliegen mehrere
## Stücke sichtbar AUSEINANDER, statt dieselbe Kurve zu wiederholen.
const METEOR_LANES := [-1.0, 0.72, -0.45, 1.0, -0.85, 0.35]
## Ausbruch-Weite und Steighöhe als Anteil der Luftlinie zum Ader-Kopf.
const METEOR_SWING := 0.5
const METEOR_RISE := 0.3
const METEOR_STEPS := 24

## Flugbahn eines Meteors: aus dem zerbrochenen Siegel geschleudert (freie Kurve -
## im Bildschirm braucht Licht keine rechten Winkel), aber schon im Flug auf den
## Kopf der Kategorie-Ader zu, die es an der Fenster-Unterkante auffängt. Von dort
## fährt es geführt in seinen Platz. Chaos beim Bruch, Ordnung bei der Zustellung.
func meteor_route(from_px: Vector2, category: String, slot_px: Vector2,
		spread_index: int) -> PackedVector2Array:
	var strip := _supply_strip(category)
	if strip == null or strip.strip_path.size() < 2:
		return PackedVector2Array([from_px, slot_px])
	var head := strip.strip_path[0]   # link_edges beginnt an der Werkbank-Unterkante
	var path := _meteor_launch(from_px, head, spread_index)
	for i in range(1, strip.strip_path.size()):
		path.append(strip.strip_path[i])
	var tail := strip.strip_path[strip.strip_path.size() - 1]
	path.append(Vector2(tail.x, slot_px.y))
	path.append(slot_px)
	return path

## Der geschleuderte Teil: quadratische Bézier vom Siegel über einen seitlich
## versetzten, höher liegenden Kontrollpunkt zum Ader-Kopf.
func _meteor_launch(from_px: Vector2, head: Vector2, spread_index: int) -> PackedVector2Array:
	var span := maxf(from_px.distance_to(head), 1.0)
	var lane: float = METEOR_LANES[posmod(spread_index, METEOR_LANES.size())]
	var control := from_px + Vector2(lane * span * METEOR_SWING, -span * METEOR_RISE)
	var path := PackedVector2Array()
	for i in METEOR_STEPS + 1:
		var t := float(i) / float(METEOR_STEPS)
		path.append(from_px.lerp(control, t).lerp(control.lerp(head, t), t))
	return path

func _supply_strip(category: String) -> LedStripView:
	for i in mini(supply_drawers.size(), supply_strips.size()):
		if supply_drawers[i].category == category:
			return supply_strips[i]
	return null

## Schickt einen Meteor los; liefert die Flugzeit (einheitliche Lichtgeschwindigkeit,
## die Kurve macht ihn dadurch von selbst etwas langsamer als eine gerade Ader).
func meteor_comet(from_px: Vector2, category: String, slot_px: Vector2, color: Color,
		spread_index: int) -> float:
	if workshop_window == null or not workshop_window.visible:
		return 0.0
	var path := meteor_route(from_px, category, slot_px, spread_index)
	var travel := _travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## Kurzer, gedämpfter Komet entlang eines FESTEN Pfads (siehe TracePulseView).
func _pulse_along(path: PackedVector2Array, duration: float, color := OVERCLOCK_PULSE_COLOR) -> void:
	if path.size() < 2:
		return
	var pulse := TracePulseView.new()
	add_child(pulse)
	pulse.setup(path, color, OVERCLOCK_PULSE_CORE, OVERCLOCK_PULSE_GLOW, duration, OVERCLOCK_COMET)

func _path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	return length

## Laufzeit eines Pfads bei der einheitlichen Licht-Geschwindigkeit.
func _travel_time(path: PackedVector2Array) -> float:
	return maxf(0.12, _path_length(path) / PULSE_SPEED)

## Laufzeit der Geld-Leiste (Schatz <-> Hub) für die Ablauf-Planung außen.
func money_travel_time() -> float:
	if treasure_strip == null or treasure_strip.strip_path.size() < 2:
		return 0.4
	return _travel_time(treasure_strip.strip_path)

## Gemeinsame Rundenende-Bahn eines Charm-Kometen bis zur Hub-Oberkante:
## Konsole -> Sammelschiene -> Stamm in den Punkte-Bildschirm, an dessen
## RAHMEN zur Grubenspalte, der Datenbus an die Grube, um die Grubenhälfte
## (Rahmen, nicht quer durchs Fenster) und über die Bank-Leiste an die
## Hub-Oberkante - dieselbe Bahn wie der Bank-Komet der Rundenauszahlung.
func _round_end_prefix(from_px: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array()
	path.append(from_px)
	path.append(Vector2(from_px.x, _charm_rail_y))
	path.append(Vector2(_charm_trunk_x, _charm_rail_y))
	var score_entry := Vector2(_charm_trunk_x, score_rect.position.y)
	path.append(score_entry)
	var pr := Rect2(pit_window.position, pit_window.size)
	var pcx := pr.get_center().x
	var score_exit := Vector2(clampf(pcx, score_rect.position.x, score_rect.end.x), score_rect.end.y)
	for corner in _border_route(score_rect, score_entry, score_exit):
		path.append(corner)
	path.append(score_exit)
	var pit_entry := Vector2(pcx, pr.position.y)
	var pit_exit := Vector2(pcx, pr.end.y)
	path.append(pit_entry)
	for corner in _border_route(pr, pit_entry, pit_exit):
		path.append(corner)
	path.append(pit_exit)
	path.append(Vector2(hub.position.x + hub.size.x * 0.5, hub.position.y))
	return path

## Volle Rundenende-Route: die gemeinsame Bahn bis zum Hub, dann von dessen
## Rand über die Ziel-Adern (Geld-Leiste bzw. Werkstatt + Schublade) ans Ziel -
## _route_via_strips fährt Fensterrahmen entlang, nie quer durch einen Screen.
func _round_end_route(from_px: Vector2, tail_strips: Array, to_px: Vector2) -> PackedVector2Array:
	if pit_window == null or hub == null or score_rect.size.x <= 0.0:
		return _orthogonal_path(from_px, to_px)
	var path := _round_end_prefix(from_px)
	var tail := _route_via_strips(path[path.size() - 1], tail_strips, to_px)
	for i in range(1, tail.size()):
		path.append(tail[i])
	return path

## Geld-Komet eines Rundenende-Charms (EIN Chip-Paket in seiner Stückelungs-
## farbe): die Rundenende-Bahn bis zum Hub, dann am Hub-Rahmen zur Geld-Leiste
## und über sie in die Schatztruhe - der Aufrufer bucht bei Ankunft.
func charm_money_comet(from_px: Vector2, color := SIDE_MONEY_COLOR) -> float:
	if treasure_strip == null or treasure_strip.strip_path.size() < 2:
		return 0.0
	var to_px := treasure_strip.strip_path[treasure_strip.strip_path.size() - 1]
	var path := _round_end_route(from_px, [treasure_strip], to_px)
	var travel := _round_end_travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## Gravur-Meteor der Frankiermaschine: die Rundenende-Bahn bis zum Hub, dann
## Werkstatt-Ader und Schubladen-Ader bis in den Platz - derselbe Aderweg wie
## ein Automaten-Gewinn (slot_engraving_route). Liefert die Laufzeit.
func charm_engraving_comet(from_px: Vector2, category: String, slot_px: Vector2, color: Color) -> float:
	if workshop_window == null or not workshop_window.visible:
		return 0.0
	var path := _round_end_route(from_px, [workshop_hub_strip, _supply_strip(category)], slot_px)
	var travel := _round_end_travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## Die Rundenende-Bahn ist lang (Score -> Grube -> Hub -> Ziel) - ihre Kometen
## fahren doppelt so schnell wie die normale Licht-Geschwindigkeit, damit die
## Zeremonie bei mehreren Charms nicht zäh wird.
const ROUND_END_PULSE_SPEED := PULSE_SPEED * 2.0

func _round_end_travel_time(path: PackedVector2Array) -> float:
	return maxf(0.12, _path_length(path) / ROUND_END_PULSE_SPEED)

## Geld-Lichtlauf im Übertaktungs-Stil: ein kurzer Komet fährt die Hub<->Schatz-
## Leiste (to_treasure = Gutschrift Hub->Schatz, sonst Kauf Schatz->Hub).
## Liefert die Laufzeit für die Ankunfts-Planung.
func money_comet(to_treasure: bool, color: Color) -> float:
	if treasure_strip == null or treasure_strip.strip_path.size() < 2:
		return 0.0
	var path := treasure_strip.strip_path.duplicate()
	if not to_treasure:
		path.reverse()
	var travel := _travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## --- Nebenwetten-Lichter (Einsatz/Auszahlung über die Schatz-Leiste) ----------

## Farben der Nebenwetten-Lichter: Geld goldgelb (Schatz-seitig), Gravur violett
## (Hub-seitig) - so verrät die Farbe schon die Herkunft des Lichts.
const SIDE_MONEY_COLOR := Color(2.0, 1.55, 0.35, 0.9)
const SIDE_ENGRAVING_COLOR := Color(1.5, 0.7, 2.0, 0.9)

## Pfad Schatz <-> Nebenwetten (Geld-Einsatz): Truhen-Unterkante in den Korridor,
## über die Abzweigung zur Nebenwetten-Unterkante. Leer, falls die Adern fehlen.
func _treasure_to_side_path() -> PackedVector2Array:
	var trunk := treasure_strip.strip_path
	var branch := treasure_strip.branch_path
	if trunk.size() < 4 or branch.size() < 3:
		return PackedVector2Array()
	return PackedVector2Array([trunk[3], trunk[2], branch[1], branch[2]])

## Pfad Hub <-> Nebenwetten (Gravur-Einsatz): Hub-Austritt über den Korridor und
## die Abzweigung zur Nebenwetten-Unterkante.
func _hub_to_side_path() -> PackedVector2Array:
	var trunk := treasure_strip.strip_path
	var branch := treasure_strip.branch_path
	if trunk.size() < 4 or branch.size() < 3:
		return PackedVector2Array()
	return PackedVector2Array([trunk[0], trunk[1], trunk[2], branch[1], branch[2]])

## Einsatz-Komet ZUM Nebenwetten-Fenster (from_hub = Gravur-Einsatz vom Hub,
## sonst Geld-Einsatz vom Schatz). Liefert die Laufzeit für die Ankunfts-Planung.
func side_bet_stake_comet(from_hub: bool, color: Color) -> float:
	var path := _hub_to_side_path() if from_hub else _treasure_to_side_path()
	if path.size() < 2:
		return 0.0
	var travel := _travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## Auszahlungs-Komet VOM Nebenwetten-Fenster (to_hub = Gravur-Gewinn zum Hub,
## sonst Geld-Gewinn zum Schatz). Liefert die Laufzeit.
func side_bet_payout_comet(to_hub: bool, color: Color) -> float:
	var path := _hub_to_side_path() if to_hub else _treasure_to_side_path()
	if path.size() < 2:
		return 0.0
	path.reverse()
	var travel := _travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## Lässt das Einsatz-Licht am Fenster-Eintritt weiter "in den Setzen-Knopf
## diffundieren": ein kurzer, gedämpfter Komet vom Ader-Eintritt zur Knopfmitte
## (Screen-Pixel). Liefert die Laufzeit.
func diffuse_into_side_bet(button_center_px: Vector2, color: Color) -> float:
	var branch := treasure_strip.branch_path
	if branch.size() < 3:
		return 0.0
	var entry := branch[branch.size() - 1]
	var path := _orthogonal_path(entry, button_center_px)
	var travel := maxf(0.18, _path_length(path) / PULSE_SPEED)
	_pulse_along(path, travel, color)
	return travel

## Lässt den Neon-Rahmen des Kombinationen-Fensters kurz in color aufleuchten.
func flash_cluster_frame(color: Color) -> void:
	if cluster_frame == null:
		return
	var style: StyleBoxFlat = cluster_frame.get_theme_stylebox("panel")
	if _cluster_flash_tween != null:
		_cluster_flash_tween.kill()
	style.border_color = color
	_cluster_flash_tween = create_tween()
	_cluster_flash_tween.tween_property(style, "border_color", FRAME_COLOR, 0.5) \
		.set_delay(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _build_pit_actions() -> void:
	var row_width := PIT_ACTION_SIZE.x * 2.0 + PIT_ACTION_GAP
	pit_actions_root = Control.new()
	pit_actions_root.name = "PitActions"
	pit_actions_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Zweite Reihe für den Bank-Knopf (Runde vorzeitig beenden).
	pit_actions_root.size = Vector2(row_width, PIT_ACTION_SIZE.y * 2.0 + PIT_ACTION_GAP)
	add_child(pit_actions_root)

	take_action_button = _make_pit_button("Nehmen", CasinoStyle.GOLD, CasinoStyle.GOLD_DARK)
	take_action_button.position = Vector2.ZERO
	pit_actions_root.add_child(take_action_button)

	roll_action_button = _make_pit_button("Würfeln", CasinoStyle.GREEN, CasinoStyle.GREEN_DARK)
	roll_action_button.position = Vector2(PIT_ACTION_SIZE.x + PIT_ACTION_GAP, 0.0)
	pit_actions_root.add_child(roll_action_button)

	# Bank-Knopf: über volle Breite unter den beiden, erscheint erst ab Stufe 1.
	bank_action_button = _make_pit_button("Runde beenden", GOAL_STAGE_COLOR, GOAL_STAGE_DARK)
	bank_action_button.size = Vector2(row_width, PIT_ACTION_SIZE.y)
	bank_action_button.custom_minimum_size = bank_action_button.size
	bank_action_button.position = Vector2(0.0, PIT_ACTION_SIZE.y + PIT_ACTION_GAP)
	bank_action_button.visible = false
	pit_actions_root.add_child(bank_action_button)

## Neon-Button im Casino-Look mit supersampled-skalierten Rändern/Radien
## (CasinoStyle rechnet in Fenster-Pixeln - 3px wären hier fast unsichtbar).
func _make_pit_button(text: String, accent: Color, dark: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.size = PIT_ACTION_SIZE
	button.custom_minimum_size = PIT_ACTION_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _pit_button_box(accent, dark))
	button.add_theme_stylebox_override("hover", _pit_button_box(accent.lightened(0.14), CasinoStyle.GOLD))
	button.add_theme_stylebox_override("pressed", _pit_button_box(dark, dark.darkened(0.2)))
	button.add_theme_stylebox_override("disabled", _pit_button_box(CasinoStyle.DISABLED_FILL, CasinoStyle.DISABLED_BORDER))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", PIT_ACTION_FONT)
	button.add_theme_color_override("font_color", CasinoStyle._readable_text(accent))
	button.add_theme_color_override("font_hover_color", CasinoStyle._readable_text(accent.lightened(0.14)))
	button.add_theme_color_override("font_pressed_color", CasinoStyle.CREAM)
	button.add_theme_color_override("font_disabled_color", CasinoStyle.MUTED)
	button.add_theme_color_override("font_outline_color", CasinoStyle.SHADOW)
	button.add_theme_constant_override("outline_size", 1 * SUPERSAMPLE)
	return button

func _pit_button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2 * SUPERSAMPLE)
	box.set_corner_radius_all(7 * SUPERSAMPLE)
	box.set_content_margin_all(4 * SUPERSAMPLE)
	box.shadow_color = CasinoStyle.SHADOW
	box.shadow_size = 3 * SUPERSAMPLE
	box.shadow_offset = Vector2(0, 2) * SUPERSAMPLE
	return box

## Setzt die Aktions-Buttons so, dass die OBERE Reihe (Nehmen/Würfeln) mittig auf
## center_px sitzt; der Bank-Knopf hängt darunter, ohne die Hauptreihe zu verschieben.
func place_pit_actions(center_px: Vector2) -> void:
	if pit_actions_root == null:
		return
	pit_actions_root.position = center_px - Vector2(pit_actions_root.size.x / 2.0, PIT_ACTION_SIZE.y / 2.0)

## Bildschirm-Rechteck der Aktions-Buttons (für die Maus-Weiterleitung).
func pit_actions_rect() -> Rect2:
	if pit_actions_root == null:
		return Rect2()
	return Rect2(pit_actions_root.position, pit_actions_root.size)

## Spannt das Hover-Erklärfeld über rect auf (unter den Grubenwürfeln); unit
## staffelt die Schriftgröße wie bei den übrigen Info-Leisten.
func place_pit_info_bar(rect: Rect2, unit: float) -> void:
	if pit_info_bar == null:
		return
	pit_info_bar.position = rect.position
	pit_info_bar.size = rect.size
	pit_info_label.offset_left = unit * 2.0
	pit_info_label.offset_right = -unit * 2.0
	pit_info_label.add_theme_font_size_override("font_size", maxi(10, int(unit * 3.0)))

## Setzt den Erklärtext ("" = Feld ausblenden). Die Grubenwürfel-Hover-Logik in
## scene_root ruft das jeden Frame.
func set_pit_info(text: String) -> void:
	if pit_info_bar == null:
		return
	pit_info_label.text = text
	pit_info_bar.visible = text != ""

## Schneidet einen Kamerastrahl mit der Bildschirm-Ebene und liefert den
## Display-Pixel - (-1,-1) bei Verfehlen oder außerhalb der Fläche.
func pixel_from_ray(origin: Vector3, direction: Vector3) -> Vector2:
	if absf(direction.y) < 0.0001:
		return Vector2(-1, -1)  # Strahl (fast) parallel zur Tischebene
	var t := (_surface_y - origin.y) / direction.y
	if t <= 0.0:
		return Vector2(-1, -1)  # Ebene hinter der Kamera
	var hit := origin + direction * t
	var pixel := world_to_pixel(hit)
	if pixel.x < 0.0 or pixel.y < 0.0 or pixel.x > float(size.x) or pixel.y > float(size.y):
		return Vector2(-1, -1)
	return pixel

## Umrechnungsfaktor Weltmeter -> Display-Pixel (aus der Screen-Breite).
func pixels_per_world() -> float:
	return float(size.x) / _z_span
