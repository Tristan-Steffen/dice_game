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

const PIT_SCORE_SIZE := Vector2(620, 150) * SUPERSAMPLE
const GLOW_COLOR := Color(1.9, 1.55, 0.6, 0.85)  # überhelles Gold (bloomt)
const TOTAL_FLY_FONT := 44 * SUPERSAMPLE

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
## Display-Glas-Material: bekommt über _sync_reflection_windows die Fenster-
## Rechtecke - NUR dort spiegelt das Glas, der Filz dazwischen bleibt matt.
var _glass_material: ShaderMaterial
## Wertungs-Bildschirm: EIN Fenster-Rahmen HINTER Basis-Zähler, Zielbalken und
## Mult-Zähler (die bleiben eigenständige Kinder mit Screen-globaler Position -
## die Zähl-Animation rechnet unverändert weiter). Analog zu cluster_frame.
var score_frame: Panel
var score_rect := Rect2()
## Leisten, die in den Wertungs-Bildschirm münden: Grube (dicker Datenbus, von
## unten), Kombinationen (von unten-links), Charm-Dock (von oben).
var pit_score_strip: LedStripView
var combos_score_strip: LedStripView
var charm_dock_score_strip: LedStripView
## Charm-Dock (Kontakt-Pads unter der 3D-Charm-Reihe); mündet von oben in den Score.
var charm_dock: CharmDockView
var goal_bar: Panel
var goal_bar_fill: ColorRect
var goal_bar_label: Label
## Basis- und Mult-Zähler getrennt, je an eigenem Editor-Anker.
var base_counter: PitScoreView
var mult_counter: PitScoreView
var hub: HubView
## Verschmolzene Gesamtzahl: erscheint AM Zielbalken (die Grubenmitte wäre
## vom Käfig verdeckt) und schrumpft am Ende in den Balken.
var pit_total_label: Label

## Trägerfläche ist klick-durchlässig; nur die Buttons fangen ihre Klicks.
var pit_actions_root: Control
var take_action_button: Button
var roll_action_button: Button

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

	combos_score_strip = LedStripView.new()
	combos_score_strip.name = "CombosScoreStrip"
	combos_score_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(combos_score_strip)

	charm_dock_score_strip = LedStripView.new()
	charm_dock_score_strip.name = "CharmDockScoreStrip"
	charm_dock_score_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(charm_dock_score_strip)

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
		rects.append(Vector4(charm_dock.position.x, charm_dock.position.y,
			charm_dock.position.x + charm_dock.size.x, charm_dock.position.y + charm_dock.size.y))
		radii.append(10.0)
	if goal_bar != null:
		rects.append(Vector4(goal_bar.position.x, goal_bar.position.y,
			goal_bar.position.x + goal_bar.size.x, goal_bar.position.y + goal_bar.size.y))
		radii.append(10.0)
	if side_bet_window != null and side_bet_window.visible:
		rects.append(Vector4(side_bet_window.position.x, side_bet_window.position.y,
			side_bet_window.position.x + side_bet_window.size.x, side_bet_window.position.y + side_bet_window.size.y))
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
	goal_bar_label.modulate = GOAL_BAR_TEXT_COLOR
	goal_bar.add_child(goal_bar_label)
	set_goal_progress(0, 1)

## Zentriert den Balken auf das gegebene Display-Pixel.
func place_goal_bar(center_px: Vector2) -> void:
	goal_bar.position = center_px - GOAL_BAR_SIZE / 2.0
	_sync_reflection_windows()

## Rahmt Basis-Zähler, Zielbalken und Mult-Zähler zu EINEM Bildschirm (Rahmen
## hinter den Elementen). NACH place_goal_bar UND configure_pit_score rufen.
const SCORE_SCREEN_PADDING := 16.0 * SUPERSAMPLE

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

func set_goal_progress(points: int, goal: int) -> void:
	var fraction := clampf(float(points) / float(maxi(1, goal)), 0.0, 1.0)
	goal_bar_fill.size.x = (GOAL_BAR_SIZE.x - GOAL_BAR_INSET * 2.0) * fraction
	goal_bar_label.text = "%d / %d" % [points, goal]

func pulse_goal_bar() -> void:
	goal_bar.scale = Vector2(1.18, 1.18)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(goal_bar, "scale", Vector2.ONE, 0.35)

## --- Wertungszahlen & Goldlicht der Zähl-Animation ----------------------------

func _build_pit_score() -> void:
	base_counter = _make_counter("BaseCounter", PitScoreView.BASE_COLOR)
	mult_counter = _make_counter("MultCounter", PitScoreView.MULT_COLOR)

	pit_total_label = Label.new()
	pit_total_label.name = "PitTotal"
	pit_total_label.add_theme_font_size_override("font_size", TOTAL_FLY_FONT)
	pit_total_label.modulate = PitScoreView.TOTAL_COLOR
	pit_total_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pit_total_label.visible = false
	add_child(pit_total_label)

func _make_counter(node_name: String, counter_color: Color) -> PitScoreView:
	var counter := PitScoreView.new()
	counter.name = node_name
	counter.color = counter_color
	counter.size = PIT_SCORE_SIZE
	counter.position = (Vector2(RESOLUTION) - PIT_SCORE_SIZE) / 2.0
	counter.pivot_offset = PIT_SCORE_SIZE / 2.0
	add_child(counter)
	return counter

## Setzt Größe und Mitte BEIDER Zähler (aus den Anker-Weltpositionen).
func configure_pit_score(base_center_px: Vector2, mult_center_px: Vector2, new_size: Vector2) -> void:
	_place_counter(base_counter, base_center_px, new_size)
	_place_counter(mult_counter, mult_center_px, new_size)

func _place_counter(counter: PitScoreView, center_px: Vector2, new_size: Vector2) -> void:
	counter.size = new_size
	counter.pivot_offset = new_size / 2.0
	counter.position = center_px - new_size / 2.0
	counter.queue_redraw()

## Setzt Basis + Mult - Pop nur auf dem GEÄNDERTEN Zähler und nur bei echter
## Änderung (wird wiederholt gerufen). Blendet eine stehende Gesamtzahl aus.
func update_pit_score(base: int, mult: int) -> void:
	if base_counter.visible and base_counter.value == base and mult_counter.value == mult:
		return
	pit_total_label.visible = false
	base_counter.visible = true
	mult_counter.visible = true
	if base_counter.value != base:
		base_counter.set_value(base)
		_pop(base_counter, 1.12)
	if mult_counter.value != mult:
		mult_counter.set_value(mult)
		_pop(mult_counter, 1.12)

## Pop BEIDER Zähler ohne Wertänderung (Ankunft der Kombi-Leiterbahnen).
func pulse_pit_score() -> void:
	_pop(base_counter, 1.12)
	_pop(mult_counter, 1.12)

## Verschmilzt die Seiten-Zahlen zur Gesamtzahl am Zielbalken.
func show_pit_total(total: int) -> void:
	base_counter.visible = false
	mult_counter.visible = false
	pit_total_label.text = str(total)
	pit_total_label.visible = true
	pit_total_label.reset_size()
	pit_total_label.pivot_offset = pit_total_label.size / 2.0
	pit_total_label.position = goal_bar.position + goal_bar.size / 2.0 - pit_total_label.size / 2.0
	_pop(pit_total_label, 1.4)

## Setzt die Daueranzeige still auf 0 / 0 und blendet die Gesamtzahl aus.
func reset_pit_score() -> void:
	pit_total_label.visible = false
	base_counter.visible = true
	mult_counter.visible = true
	base_counter.set_value(0)
	mult_counter.set_value(0)

## Lässt die Gesamtzahl in den Zielbalken schrumpfen; der Balken pocht beim
## Einschlag. Liefert den Tween (für await finished).
func fly_total_to_goal(duration: float) -> Tween:
	var target := goal_bar.position + goal_bar.size / 2.0 - pit_total_label.size / 2.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(pit_total_label, "position", target, duration)
	tween.tween_property(pit_total_label, "scale", Vector2(0.4, 0.4), duration)
	tween.tween_property(pit_total_label, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(func() -> void:
		pit_total_label.modulate = PitScoreView.TOTAL_COLOR
		pit_total_label.scale = Vector2.ONE
		reset_pit_score()
		pulse_goal_bar())
	return tween

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

func spawn_gain_number(from_px: Vector2, text: String, color: Color) -> void:
	var label := _make_gain_label(text, color)
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

func _make_gain_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", GAIN_FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", GAIN_OUTLINE)
	label.add_theme_constant_override("outline_size", 3 * SUPERSAMPLE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Goldenes Leucht-Podest unter einem zählenden/ausgewählten Würfel.
## side_px = Kantenlänge; der Aufrufer hält und entsorgt die Knoten.
func spawn_glow(center_px: Vector2, side_px: float) -> Control:
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
	tween.tween_property(glow, "modulate:a", 1.0, 0.25)
	return glow

## --- Wertungs-Kometen (Zähl-Animation über die Score-Leisten) ------------------

## EINE Licht-Geschwindigkeit für alle Zähl-Kometen (px/s im SUPERSAMPLE-Raum):
## die Dauer folgt der Pfadlänge, so überholt kein Komet auf gleicher Leiste.
const SCORE_PULSE_SPEED := 1400.0 * SUPERSAMPLE
const SCORE_PULSE_CORE := 4.0 * SUPERSAMPLE
const SCORE_PULSE_GLOW := 12.0 * SUPERSAMPLE
const SCORE_COMET := 90.0 * SUPERSAMPLE  # Kometen-Fensterlänge

## Farben der Zähl-Kometen (überhell, bloomen): Basis cyan, Mult gold.
const SCORE_BASE_COLOR := Color(0.5, 2.0, 2.0, 0.95)
const SCORE_MULT_COLOR := Color(2.0, 1.6, 0.3, 0.95)

func _score_strip(source: String) -> LedStripView:
	match source:
		"combos": return combos_score_strip
		"charm": return charm_dock_score_strip
		_: return pit_score_strip

## Ziel-Ankerpunkt (Screen-px) im Score-Bildschirm.
func _score_target_px(target: String) -> Vector2:
	if target == "total":
		return goal_bar.position + goal_bar.size / 2.0
	var counter := base_counter if target == "base" else mult_counter
	return counter.position + counter.value_anchor()

## Vollständige Route eines Zähl-Kometen: Quelle -> passende Leiste -> Zähler.
## L-Anschlüsse an beiden Enden halten alles achsenparallel (Leiterbahn-Look).
func score_route(from_px: Vector2, source: String, target: String) -> PackedVector2Array:
	var strip := _score_strip(source)
	var to_px := _score_target_px(target)
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
## (Ankunft = wenn der Aufrufer die Zahl setzt).
func score_comet(from_px: Vector2, source: String, target: String) -> float:
	var path := score_route(from_px, source, target)
	if path.size() < 2:
		return 0.0
	var travel := maxf(0.15, _path_length(path) / SCORE_PULSE_SPEED)
	var color := SCORE_BASE_COLOR if target == "base" else SCORE_MULT_COLOR
	if target == "total":
		color = PitScoreView.TOTAL_COLOR
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
	# Kombinationen -> Score: von der Kombi-Oberkante in einen linken Score-Port.
	if combos_score_strip != null and cluster_frame != null:
		var exit_x := cluster_rect.get_center().x + cluster_rect.size.x * 0.25
		var enter_x := score_rect.position.x + score_rect.size.x * 0.25
		combos_score_strip.link_edges(cluster_rect.position.y, exit_x, score_bottom, enter_x,
			lane, SCORE_STRIP_WIDTH)
	# Charm-Dock -> Score: von der Dock-UNTERKANTE senkrecht in die Score-OBERKANTE.
	if charm_dock_score_strip != null and charm_dock != null and charm_dock.visible:
		var dock_bottom := charm_dock.position.y + charm_dock.size.y
		var dock_cx := charm_dock.position.x + charm_dock.size.x * 0.5
		var score_top := score_rect.position.y
		var up_lane := (dock_bottom + score_top) * 0.5
		charm_dock_score_strip.link_edges(dock_bottom, dock_cx, score_top, dock_cx,
			up_lane, SCORE_STRIP_WIDTH)

## Spannt das Charm-Dock über die 6 Platz-Pixelmitten auf (pad_size = Kachel).
func place_charm_dock(pad_centers_px: PackedVector2Array, pad_size: Vector2) -> void:
	if charm_dock == null:
		return
	charm_dock.place(pad_centers_px, pad_size)
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

## Farben der Nebenwetten-Lichter: Geld goldgelb (Schatz-seitig), Sigill violett
## (Hub-seitig) - so verrät die Farbe schon die Herkunft des Lichts.
const SIDE_MONEY_COLOR := Color(2.0, 1.55, 0.35, 0.9)
const SIDE_SIGIL_COLOR := Color(1.5, 0.7, 2.0, 0.9)

## Pfad Schatz <-> Nebenwetten (Geld-Einsatz): Truhen-Unterkante in den Korridor,
## über die Abzweigung zur Nebenwetten-Unterkante. Leer, falls die Adern fehlen.
func _treasure_to_side_path() -> PackedVector2Array:
	var trunk := treasure_strip.strip_path
	var branch := treasure_strip.branch_path
	if trunk.size() < 4 or branch.size() < 3:
		return PackedVector2Array()
	return PackedVector2Array([trunk[3], trunk[2], branch[1], branch[2]])

## Pfad Hub <-> Nebenwetten (Sigill-Einsatz): Hub-Austritt über den Korridor und
## die Abzweigung zur Nebenwetten-Unterkante.
func _hub_to_side_path() -> PackedVector2Array:
	var trunk := treasure_strip.strip_path
	var branch := treasure_strip.branch_path
	if trunk.size() < 4 or branch.size() < 3:
		return PackedVector2Array()
	return PackedVector2Array([trunk[0], trunk[1], trunk[2], branch[1], branch[2]])

## Einsatz-Komet ZUM Nebenwetten-Fenster (from_hub = Sigill-Einsatz vom Hub,
## sonst Geld-Einsatz vom Schatz). Liefert die Laufzeit für die Ankunfts-Planung.
func side_bet_stake_comet(from_hub: bool, color: Color) -> float:
	var path := _hub_to_side_path() if from_hub else _treasure_to_side_path()
	if path.size() < 2:
		return 0.0
	var travel := _travel_time(path)
	_pulse_along(path, travel, color)
	return travel

## Auszahlungs-Komet VOM Nebenwetten-Fenster (to_hub = Sigill-Gewinn zum Hub,
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
	pit_actions_root = Control.new()
	pit_actions_root.name = "PitActions"
	pit_actions_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pit_actions_root.size = Vector2(PIT_ACTION_SIZE.x * 2.0 + PIT_ACTION_GAP, PIT_ACTION_SIZE.y)
	add_child(pit_actions_root)

	take_action_button = _make_pit_button("Nehmen", CasinoStyle.GOLD, CasinoStyle.GOLD_DARK)
	take_action_button.position = Vector2.ZERO
	pit_actions_root.add_child(take_action_button)

	roll_action_button = _make_pit_button("Würfeln", CasinoStyle.GREEN, CasinoStyle.GREEN_DARK)
	roll_action_button.position = Vector2(PIT_ACTION_SIZE.x + PIT_ACTION_GAP, 0.0)
	pit_actions_root.add_child(roll_action_button)

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

## Setzt die Aktions-Buttons mittig auf center_px.
func place_pit_actions(center_px: Vector2) -> void:
	if pit_actions_root == null:
		return
	pit_actions_root.position = center_px - pit_actions_root.size / 2.0

## Bildschirm-Rechteck der Aktions-Buttons (für die Maus-Weiterleitung).
func pit_actions_rect() -> Rect2:
	if pit_actions_root == null:
		return Rect2()
	return Rect2(pit_actions_root.position, pit_actions_root.size)

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

func _pop(control: Control, strength: float) -> void:
	control.scale = Vector2.ONE * strength
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.3)
