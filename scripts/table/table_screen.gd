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
var pit_window: Panel
## Display-Glas-Material: bekommt über _sync_reflection_windows die Fenster-
## Rechtecke - NUR dort spiegelt das Glas, der Filz dazwischen bleibt matt.
var _glass_material: ShaderMaterial
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
	for i in total:
		_add_combo_cell(DiceScoring.HAND_PRIORITY[i], positions[i])

	_build_goal_bar()
	_build_pit_score()

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
	if goal_bar != null:
		rects.append(Vector4(goal_bar.position.x, goal_bar.position.y,
			goal_bar.position.x + goal_bar.size.x, goal_bar.position.y + goal_bar.size.y))
		radii.append(10.0)
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

## Leiterbahn von from_px zur wachsenden Zahl (target: "base"/"mult"/"total").
## Quellen außerhalb des Displays werden an den Rand geklemmt. Räumt sich
## selbst weg; der Aufrufer wartet die Trail-Zeit ab, bevor die Zahl steigt.
func spawn_score_trail(from_px: Vector2, target: String, duration: float) -> void:
	var to_px: Vector2
	if target == "total":
		to_px = goal_bar.position + goal_bar.size / 2.0
	else:
		var counter := base_counter if target == "base" else mult_counter
		to_px = counter.position + counter.value_anchor()
	var color := TRAIL_BASE_COLOR if target == "base" else TRAIL_MULT_COLOR
	spawn_trace(from_px, to_px, color, duration)

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
