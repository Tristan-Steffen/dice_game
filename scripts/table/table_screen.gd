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
## Adern des Chip-Netzes: dünner als die Fenster-Verbindungen (Stiche an Pins).
const COMBO_WIRING_WIDTH := 4.0 * SUPERSAMPLE
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

## Rundenpuls: Einrückung des Wellen-Overlays (der Fensterrahmen bleibt frei)
## und Ein-/Ausblendzeit beim Rundenwechsel.
const PIT_WAVES_INSET := 2.0 * SUPERSAMPLE
const PIT_WAVES_FADE := 1.2
## Punkt-Pulse (pit_impulse): Laufzeit einer Stoßwelle und Zahl der Bahnen
## (rotierend - mehr gleichzeitige Pulse recyceln die älteste Bahn).
const PIT_IMPULSE_TIME := 0.45
const PIT_IMPULSE_SLOTS := 6

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
## Der Rückblick tönt den Tisch, statt ihn zu verstellen - dunkles Violettblau,
## gerade so viel, dass die Gegenwart erkennbar abwesend ist.
const MEMORY_VEIL_COLOR := Color(0.05, 0.04, 0.14, 0.16)
const CRIT_COLOR := Color(2.2, 0.45, 1.15, 0.95)
const CRIT_HITSTOP := 0.12
const CRIT_ECHO_DELAY := 0.08
const CRIT_SHAKE_TIME := 0.3
const CRIT_SHAKE_PX := 5.0 * SUPERSAMPLE

## Aktions-Buttons unten mittig in der Grube, bedient über die Maus-Weiterleitung.
const PIT_ACTION_SIZE := Vector2(66, 24) * SUPERSAMPLE
const PIT_ACTION_GAP := 10.0 * SUPERSAMPLE
const PIT_ACTION_FONT := 12 * SUPERSAMPLE
## Abstand der wandnahen Knöpfe (Beenden, Rückblick) zur Grubenwand.
const PIT_WALL_MARGIN := 5.0 * SUPERSAMPLE

## Licht-Trails: LEITERBAHNEN (rein achsenparallel, siehe ScoreTraceView) -
## Cyan in die Basis, Gold in Mult/Gesamtzahl.
const TRAIL_MARGIN := 26.0 * SUPERSAMPLE  # Rand-Klemmung für Quellen außerhalb
const TRAIL_BASE_COLOR := Color(0.5, 2.0, 2.0, 0.9)
const TRAIL_MULT_COLOR := Color(2.0, 1.6, 0.3, 0.9)
## Fumble-Zeremonie: heißes Rot (bloomt) für das Neon-Wort und die EINE
## Stoßwelle, die aus der Grubenmitte über den ganzen Tisch läuft.
const FUMBLE_COLOR := Color(2.4, 0.16, 0.18, 0.95)
const FUMBLE_WORD := "FUMBLE"
const FUMBLE_WORD_FONT := 92 * SUPERSAMPLE
const FUMBLE_HOLD := 0.9
const FUMBLE_FADE := 0.6
## Gemächlich: die Welle braucht spürbar Zeit bis zur entferntesten Ecke.
const FUMBLE_WAVE_TIME := 2.0
const FUMBLE_WAVE_WIDTH := 55.0 * SUPERSAMPLE
## Punkt-Puls-Farbe je Punktart - dieselbe Sprache wie Kometen und Zuwachs-Zahlen.
const PIT_IMPULSE_COLORS := {"base": TRAIL_BASE_COLOR, "mult": TRAIL_MULT_COLOR, "crit": CRIT_COLOR}
const TRACE_CORE_WIDTH := 5.0 * SUPERSAMPLE
const TRACE_GLOW_WIDTH := 16.0 * SUPERSAMPLE
## Erster senkrechter Hub aus der Quelle (~2.4 Weltmeter): hebt die Querstrecke
## über Nachbar-Würfel, hält sie unter Zählern und Punktebalken.
const TRACE_RISE := 30.0 * SUPERSAMPLE

var combo_cells: Dictionary = {}  # DiceScoring-Key -> ComboCellView

## Adernetz der Kombi-Chips: senkrechte Sammelschienen zwischen den Spalten,
## kurze Stiche an jeden Pin. Ersetzt Fenster UND gezeichnete Leiterbahnen -
## die Chips stehen direkt auf dem Filz.
var combo_wiring: LedStripView
## LED-Leiste Hub <-> Kombinationen (Geometrie via link_hub_to_cluster).
var led_strip: LedStripView
## Schatz-Screen (Geldstand als goldene Truhe) rechts des Hubs, plus die
## LED-Leiste Hub <-> Schatz (Geld-Lichtläufe wie beim Übertakten).
var treasure_window: TreasureChestView
var treasure_strip: LedStripView
var pit_window: Panel
## Rundenpuls: Wellen-Overlay im Gruben-Fenster (siehe pit_waves.gdshader).
var pit_waves: ColorRect
var _pit_waves_tween: Tween
## Fumble-Welle: Vollbild-Overlay ÜBER allen Fenstern (fumble_wave.gdshader).
var fumble_wave: ColorRect
var _fumble_wave_tween: Tween
## Filz-Material: braucht die Fenster-Rechtecke, um seine Textur unter den
## durchscheinenden Fenstergründen auszublenden.
var _felt_material: ShaderMaterial
## Punkt-Pulse: CPU-seitiger Spiegel der Impuls-Uniform-Arrays (je Bahn Ort,
## Farbe, Fortschritt) - ein Tween je Bahn schreibt nur seinen eigenen Eintrag.
var _pit_impulse_pos := PackedVector2Array()
var _pit_impulse_colors := PackedColorArray()
var _pit_impulse_progress := PackedFloat32Array()
var _pit_impulse_tweens: Array = []
var _pit_impulse_next := 0
## Nebenwetten-Fenster rechts vom Becher (eigenständige Anzeige, kein Hub-Panel).
var side_bet_window: SideBetPanel
## Fumble-Automaten links vom Hub (unter der Ablage); wie das Nebenwetten-Fenster
## eigenständig, sichtbar erst ab der ersten Automaten-Freischaltung.
var slot_bank_window: SlotBankView
## Schwarzmarkt UNTER den Automaten (in der Glas-Tasche links unten); steht
## immer da, vergittert bis zum Eintrittsgeld (SecretShopView.set_locked).
var secret_shop_window: SecretShopView
## Werkstatt rechts vom Hub: das Lager der versiegelten Pakete.
var workshop_window: WorkshopView
## Die vier Vorrats-Schubladen unter der Werkbank (Zahlen/Material/Würfel +
## Sonderbestand), je eine Ader zur Werkbank - sie sollen als ANGEBAUT lesen,
## nicht als fremde Fenster daneben.
var supply_drawers: Array[SupplyDrawerView] = []
var supply_strips: Array[LedStripView] = []
var workshop_hub_strip: LedStripView
## Ader Automaten <-> Hub: Einsatz fährt hin, Gewinne fahren zurück.
var slot_hub_strip: LedStripView
## Ader Schwarzmarkt <-> Hub: der Zwilling der Automaten-Ader eine Etage tiefer -
## alles, was der Hinterzimmer-Laden kostet, fährt als Ladung hier hinüber.
var secret_hub_strip: LedStripView
## Ständiges Würfelnetz-Feld unter den Grubenwürfeln (DieNetView): gefüllt vom
## Hover (set_pit_die/clear_pit_die), sichtbar mit den Aktions-Knöpfen.
var pit_info_bar: Panel
var pit_net_holder: Control
## Material-Erklärzeile unter dem Netz-Feld: erscheint, wenn die Maus IM Feld
## eine Netz-Zelle mit Material überfährt (set_pit_net_hint).
var pit_net_hint: Label
## Netz-Neubau nur bei Würfel-/Lagewechsel - der Hover ruft jeden Frame.
var _pit_net_def: DieDefinition
var _pit_net_face := -2
var _pit_net_cell := 0.0
## Deal-Marken am oberen Grubenrand: derselbe Streifen wie am Hub-Rad, nur dort,
## wo gewürfelt wird. Die Hinweis-Karte hängt IM Grubenfenster (ihre Bühne).
var pit_deal_rail: DealTokenRow
var pit_deal_hint: HintCard
var _pit_deal_rect := Rect2()
var _pit_deal_u := 1.0
var _pit_deal_sides: Array[Dictionary] = []
## Streifenhöhe in u: eine Block-Marke (5.6u) füllt den Streifen zu 80 %.
const PIT_DEAL_U_DIV := 7.0
## Display-Glas-Material: bekommt über _sync_reflection_windows die Fenster-
## Rechtecke - NUR dort spiegelt das Glas, der Filz dazwischen bleibt matt.
var _glass_material: ShaderMaterial
## Umriss der Anzeigefläche als Dreiecke in Display-Pixeln (siehe glass_*_limit).
var _glass_tris: Array = []
## Wertungs-Bildschirm: EIN Fenster-Rahmen HINTER Basis-Zähler, Zielbalken und
## Mult-Zähler (die bleiben eigenständige Kinder mit Screen-globaler Position -
## die Zähl-Animation rechnet unverändert weiter).
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
## Irrlicht-Mobiliar: der Kipp-Knopf und die vier Nachbarseiten darüber.
var tip_action_button: Button
var tip_face_row: HBoxContainer
var tip_face_buttons: Array[Button] = []
var take_action_button: Button
var roll_action_button: Button
var bank_action_button: Button  # Runde bei ≥1 Überladungs-Stufe vorzeitig beenden
var log_action_button: Button  # Rückblick: die Chronik der laufenden Runde
## Zeile, in der "Beenden" neben "Nehmen" sitzt (aus place_pit_actions).
var _bank_row_y := 0.0
## Schleier des Erinnerungs-Modus - ein Rechteck über den Fenstern, sonst nichts.
var memory_veil: ColorRect

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
	_capture_glass_outline(screen_mesh)
	_sync_reflection_windows()

## Dreiecke des Anzeige-Meshes in Display-Pixeln. Die Anzeige ist NICHT das
## volle Rechteck, sondern eine abgerundete Fläche - Fenster in den Rundungen
## würden von der Glaskante schräg angeschnitten (siehe glass_*_limit).
func _capture_glass_outline(screen_mesh: MeshInstance3D) -> void:
	_glass_tris.clear()
	if screen_mesh.mesh == null or screen_mesh.mesh.get_surface_count() == 0:
		return
	var arrays := screen_mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var to_world := screen_mesh.global_transform
	var flat: Array[Vector2] = []
	for v in verts:
		flat.append(world_to_pixel(to_world * v))
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if index.is_empty():
		for i in range(0, flat.size() - 2, 3):
			_glass_tris.append([flat[i], flat[i + 1], flat[i + 2]])
		return
	for i in range(0, index.size() - 2, 3):
		_glass_tris.append([flat[index[i]], flat[index[i + 1]], flat[index[i + 2]]])

## Weiteste Spalte, die in Zeile pixel_y noch auf dem Glas liegt (bzw. tiefste
## Zeile in Spalte pixel_x). Ohne Umriss die volle Rechteckkante - dann gibt es
## nichts zu beschneiden.
func glass_right_limit(pixel_y: float) -> float:
	return _glass_limit(pixel_y, true, float(size.x))

func glass_bottom_limit(pixel_x: float) -> float:
	return _glass_limit(pixel_x, false, float(size.y))

## Schnitt aller Dreiecke mit einer Achsengeraden; along = waagerecht schneiden
## (Zeile) und das größte x melden, sonst senkrecht und das größte y.
func _glass_limit(coordinate: float, along_row: bool, fallback: float) -> float:
	if _glass_tris.is_empty():
		return fallback
	var best := -INF
	for tri in _glass_tris:
		for e in 3:
			var a: Vector2 = tri[e]
			var b: Vector2 = tri[(e + 1) % 3]
			var a_fix := a.y if along_row else a.x
			var b_fix := b.y if along_row else b.x
			if is_equal_approx(a_fix, b_fix):
				continue
			var t := (coordinate - a_fix) / (b_fix - a_fix)
			if t < 0.0 or t > 1.0:
				continue
			var hit := a.lerp(b, t)
			best = maxf(best, hit.x if along_row else hit.y)
	return best if best > -INF else fallback

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
	_felt_material = ShaderMaterial.new()
	_felt_material.shader = load("res://assets/shaders/table_felt.gdshader")
	_felt_material.set_shader_parameter("rect_size", Vector2(RESOLUTION))
	background.material = _felt_material
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

	# Rundenpuls-Overlay: leicht eingerückt, damit der Fensterrahmen frei bleibt.
	pit_waves = ColorRect.new()
	pit_waves.name = "PitWaves"
	pit_waves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var waves_material := ShaderMaterial.new()
	waves_material.shader = preload("res://assets/shaders/pit_waves.gdshader")
	waves_material.set_shader_parameter("intensity", 0.0)  # still bis zur ersten Runde
	_pit_impulse_pos.resize(PIT_IMPULSE_SLOTS)
	_pit_impulse_colors.resize(PIT_IMPULSE_SLOTS)
	_pit_impulse_progress.resize(PIT_IMPULSE_SLOTS)
	_pit_impulse_progress.fill(1.0)  # >= 1 heißt: Bahn frei
	_pit_impulse_tweens.resize(PIT_IMPULSE_SLOTS)
	waves_material.set_shader_parameter("impulse_pos", _pit_impulse_pos)
	waves_material.set_shader_parameter("impulse_color", _pit_impulse_colors)
	waves_material.set_shader_parameter("impulse_progress", _pit_impulse_progress)
	pit_waves.material = waves_material
	pit_window.add_child(pit_waves)

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
	# KEIN Fenster unter den Chips: sie stehen auf dem Filz und sind mit echten
	# LED-Adern verdrahtet (combo_wiring) - vor den Zellen angelegt, damit die
	# Schienen hinter den Sockeln liegen.
	combo_wiring = LedStripView.new()
	combo_wiring.name = "ComboWiring"
	combo_wiring.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(combo_wiring)
	for i in total:
		_add_combo_cell(DiceScoring.HAND_PRIORITY[i], positions[i])
	_lay_combo_wiring()

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

	# Schwarzmarkt: Position/Größe setzt scene_root über place_secret_shop_window;
	# sichtbar erst mit der Entdeckung.
	secret_shop_window = SecretShopView.new()
	secret_shop_window.name = "SecretShopWindow"
	secret_shop_window.visible = false
	add_child(secret_shop_window)

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

	# Ader Schwarzmarkt -> Hub (verlegt place_secret_shop_window).
	secret_hub_strip = LedStripView.new()
	secret_hub_strip.name = "SecretHubStrip"
	add_child(secret_hub_strip)

	# Vorrats-Schubladen (drei Kategorien + der Sonderbestand als vierte): Maße
	# und Position setzt scene_root über place_supply_drawers. Die Adern zuerst,
	# damit sie UNTER den Schubladen liegen.
	var drawer_categories: Array = Engraving.CATEGORIES.duplicate()
	drawer_categories.append(SupplyDrawerView.CATEGORY_SPECIAL)
	for i in drawer_categories.size():
		var strip := LedStripView.new()
		strip.name = "SupplyStrip%d" % i
		add_child(strip)
		supply_strips.append(strip)
	for drawer_category in drawer_categories:
		var drawer := SupplyDrawerView.new()
		drawer.name = "SupplyDrawer_%s" % drawer_category
		drawer.category = drawer_category
		drawer.visible = false
		add_child(drawer)
		supply_drawers.append(drawer)

	# Würfelnetz-Feld der Grube: Position/Größe setzt scene_root über
	# place_pit_info_bar; ein-/ausgeblendet zusammen mit den Aktions-Knöpfen.
	pit_info_bar = Panel.new()
	pit_info_bar.name = "PitInfoBar"
	pit_info_bar.visible = false
	pit_info_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pit_info_bar.add_theme_stylebox_override("panel", window_style())
	add_child(pit_info_bar)
	pit_net_holder = Control.new()
	pit_net_holder.name = "NetHolder"
	pit_net_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pit_info_bar.add_child(pit_net_holder)
	# Material-Erklärung als eigene, EINZEILIGE Leiste UNTER der Grube (nicht im
	# Netz-Feld) - darf breit sein, damit sie nie umbricht.
	pit_net_hint = Label.new()
	pit_net_hint.name = "NetHint"
	pit_net_hint.visible = false
	pit_net_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pit_net_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pit_net_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pit_net_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	pit_net_hint.modulate = Color(1.35, 1.35, 1.3)
	pit_net_hint.add_theme_color_override("font_outline_color", CasinoStyle.SHADOW)
	pit_net_hint.add_theme_constant_override("outline_size", 3 * SUPERSAMPLE)
	add_child(pit_net_hint)
	# Deal-Marken-Streifen am oberen Grubenrand (Platz: place_pit_deal_rail).
	pit_deal_rail = DealTokenRow.new()
	pit_deal_rail.name = "PitDealRail"
	pit_deal_rail.visible = false
	pit_deal_rail.self_hover = false  # in der Grube fragt scene_root je Frame
	add_child(pit_deal_rail)

	# Hub-Inhalt entsteht erst in place_hub (Maße aus der endgültigen Größe).
	hub = HubView.new()
	hub.name = "Hub"
	add_child(hub)

	_build_pit_actions()

	# Fumble-Welle: als LETZTES gebaut, damit sie über jedem Fenster liegt;
	# still (progress 1), bis pit_fumble sie aus der Grubenmitte losschickt.
	fumble_wave = ColorRect.new()
	fumble_wave.name = "FumbleWave"
	fumble_wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fumble_wave.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fumble_material := ShaderMaterial.new()
	fumble_material.shader = preload("res://assets/shaders/fumble_wave.gdshader")
	fumble_material.set_shader_parameter("rect_size", Vector2(RESOLUTION))
	fumble_material.set_shader_parameter("progress", 1.0)
	fumble_material.set_shader_parameter("width", FUMBLE_WAVE_WIDTH)
	fumble_material.set_shader_parameter("color", FUMBLE_COLOR)
	fumble_wave.material = fumble_material
	add_child(fumble_wave)

## DER Fenster-Stil des Tisch-Displays: dunkler, leicht durchscheinender Grund
## + Neon-Rahmen - jedes "Fenster" trägt diesen einen Look.
static func window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_BG
	style.border_color = FRAME_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style

## Spannt das Gruben-Fenster über rect auf: der Rahmen zeichnet exakt die
## Kollisionslinie der Energiewände nach (Radius = DicePit.CORNER_RADIUS in px).
func place_pit_window(rect: Rect2, corner_radius: float) -> void:
	pit_window.position = rect.position
	pit_window.size = rect.size
	var style: StyleBoxFlat = pit_window.get_theme_stylebox("panel")
	style.set_corner_radius_all(int(corner_radius))
	var inset := PIT_WAVES_INSET
	pit_waves.position = Vector2.ONE * inset
	pit_waves.size = rect.size - Vector2.ONE * inset * 2.0
	var waves_material: ShaderMaterial = pit_waves.material
	waves_material.set_shader_parameter("rect_size", pit_waves.size)
	waves_material.set_shader_parameter("corner_radius", maxf(0.0, corner_radius - inset))
	# Punkt-Pulse skalieren mit der Grubenhöhe (auflösungsunabhängig).
	waves_material.set_shader_parameter("impulse_radius", pit_waves.size.y * 0.75)
	waves_material.set_shader_parameter("impulse_width", pit_waves.size.y * 0.1)
	pit_window.visible = true
	_sync_reflection_windows()

## Punkt-Puls: schnelle Stoßwelle vom Würfel (screen_px) in der Farbe der
## Punktart - "base" (Cyan), "mult" (Gold), "crit" (Magenta). Hell bei Geburt,
## verklingt beim Auslaufen; läuft unabhängig vom Rundenpuls.
func pit_impulse(screen_px: Vector2, kind: String) -> void:
	if pit_waves == null or not pit_window.visible:
		return
	var slot := _pit_impulse_next
	_pit_impulse_next = (slot + 1) % PIT_IMPULSE_SLOTS
	var old: Tween = _pit_impulse_tweens[slot]
	if old != null and old.is_valid():
		old.kill()
	_pit_impulse_pos[slot] = screen_px - pit_window.position - pit_waves.position
	_pit_impulse_colors[slot] = PIT_IMPULSE_COLORS.get(kind, TRAIL_BASE_COLOR)
	var waves_material: ShaderMaterial = pit_waves.material
	waves_material.set_shader_parameter("impulse_pos", _pit_impulse_pos)
	waves_material.set_shader_parameter("impulse_color", _pit_impulse_colors)
	# Schnell raus, hart abbremsen (EASE_OUT) - der Ring wirkt wie ein Schlag.
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_pit_impulse_progress[slot] = v
		waves_material.set_shader_parameter("impulse_progress", _pit_impulse_progress),
		0.0, 1.0, PIT_IMPULSE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pit_impulse_tweens[slot] = tween

## Schaltet den Rundenpuls der Grube ein/aus (weich über PIT_WAVES_FADE).
func set_round_pulse(active: bool) -> void:
	if pit_waves == null:
		return
	if _pit_waves_tween != null and _pit_waves_tween.is_valid():
		_pit_waves_tween.kill()
	var waves_material: ShaderMaterial = pit_waves.material
	_pit_waves_tween = create_tween()
	_pit_waves_tween.tween_property(waves_material,
		"shader_parameter/intensity", 1.0 if active else 0.0, PIT_WAVES_FADE)

## Fumble-Zeremonie: die verlorene Hand wird sichtbar quittiert - rotes
## Neon-"FUMBLE" quer über die Grube, ein kurzes Zucken des Rundenpulses und
## EINE rote Stoßwelle aus der Grubenmitte über den GANZEN Tisch, bis sie
## jedes Fenster passiert hat.
func pit_fumble() -> void:
	if pit_window == null or not pit_window.visible:
		return
	var center := pit_window.position + pit_window.size * 0.5
	_fire_fumble_wave(center)
	_stutter_round_pulse()
	_spawn_fumble_word()

## Treibt die Vollbild-Welle: der Ring startet in center und wächst, bis er die
## entfernteste Bildschirm-Ecke passiert hat (gemächlich, sanft auslaufend).
func _fire_fumble_wave(center: Vector2) -> void:
	if fumble_wave == null:
		return
	var mat: ShaderMaterial = fumble_wave.material
	var far := 0.0
	for corner in [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size), Vector2(0.0, size.y)]:
		far = maxf(far, center.distance_to(corner))
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("max_radius", far + FUMBLE_WAVE_WIDTH * 3.0)
	fumble_wave.move_to_front()  # auch über später gebauten Fenstern
	if _fumble_wave_tween != null and _fumble_wave_tween.is_valid():
		_fumble_wave_tween.kill()
	_fumble_wave_tween = create_tween()
	_fumble_wave_tween.tween_property(mat, "shader_parameter/progress", 1.0, FUMBLE_WAVE_TIME) \
		.from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Kurzes Zucken: der Rundenpuls sackt weg und kommt zurück (die Grube
## "erschrickt"). Nur solange die Runde läuft; endet sie, überschreibt der
## folgende set_round_pulse(false) das Zucken ohnehin.
func _stutter_round_pulse() -> void:
	if pit_waves == null:
		return
	var mat: ShaderMaterial = pit_waves.material
	var cur := 0.0
	var raw: Variant = mat.get_shader_parameter("intensity")
	if raw != null:
		cur = raw
	if cur <= 0.01:
		return
	if _pit_waves_tween != null and _pit_waves_tween.is_valid():
		_pit_waves_tween.kill()
	_pit_waves_tween = create_tween()
	_pit_waves_tween.tween_property(mat, "shader_parameter/intensity", cur * 0.12, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pit_waves_tween.tween_property(mat, "shader_parameter/intensity", cur, FUMBLE_FADE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Rotes Neon-"FUMBLE" quer über die Grube: reingestanzt, Flackern wie eine
## defekte Leuchtreklame, kurz gehalten, dann ausgeblendet. Skaliert auf die
## Grube (füllt die Breite, läuft nicht über).
func _spawn_fumble_word() -> void:
	var label := Label.new()
	label.text = FUMBLE_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font_size := int(minf(FUMBLE_WORD_FONT, minf(pit_window.size.x / 4.5, pit_window.size.y * 0.55)))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", FUMBLE_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.5, 0.0, 0.02, 0.9))
	label.add_theme_constant_override("outline_size", 5 * SUPERSAMPLE)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.pivot_offset = pit_window.size * 0.5
	pit_window.add_child(label)
	label.modulate = Color(1, 1, 1, 0)
	label.scale = Vector2.ONE * 1.25
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.06)
	for a in [0.35, 1.0, 0.6, 1.0]:
		tween.tween_property(label, "modulate:a", a, 0.045)
	tween.tween_interval(FUMBLE_HOLD)
	tween.tween_property(label, "modulate:a", 0.0, FUMBLE_FADE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "scale", Vector2.ONE * 1.08, FUMBLE_FADE)
	tween.chain().tween_callback(label.queue_free)

## Nachglüh-Silhouetten des Fumbles: Standzeit, Ausblenden, Blinktakt der frisch
## geworfenen Würfel.
const FUMBLE_MARK_HOLD := 2.0
const FUMBLE_MARK_FADE := 0.35
const FUMBLE_MARK_BLINK := 0.22
## Ruhende Würfel stehen still und blass - sie haben den Fumble nicht ausgelöst.
const FUMBLE_MARK_CALM := Color(1.1, 0.45, 0.45, 0.55)

var _fumble_marks: Control

## Silhouetten der verworfenen Würfel: je Würfel ein Umriss an seiner Stelle in
## der Grube, mit der Augenzahl, die oben lag. marks = [{pixel, value, fresh}] -
## fresh (der letzte Wurf, der den Fumble auslöste) blinkt, der Rest steht still.
## Gruben-Mobiliar: verlässt die Kamera die Grube, räumt clear_fumble_marks auf.
func show_fumble_marks(marks: Array[Dictionary], side_px: float) -> void:
	clear_fumble_marks()
	if pit_window == null or not pit_window.visible or marks.is_empty() or side_px <= 0.0:
		return
	_fumble_marks = Control.new()
	_fumble_marks.name = "FumbleMarks"
	_fumble_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fumble_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fumble_marks)
	for mark in marks:
		var frame := _build_fumble_mark(mark, side_px)
		_fumble_marks.add_child(frame)
		# Der Blinktakt hängt am Umriss selbst: er stirbt mit ihm.
		if bool(mark.get("fresh", false)):
			var blink := frame.create_tween().set_loops()
			blink.tween_property(frame, "modulate:a", 0.25, FUMBLE_MARK_BLINK)
			blink.tween_property(frame, "modulate:a", 1.0, FUMBLE_MARK_BLINK)
	var tween := _fumble_marks.create_tween()
	tween.tween_interval(FUMBLE_MARK_HOLD)
	tween.tween_property(_fumble_marks, "modulate:a", 0.0, FUMBLE_MARK_FADE).set_ease(Tween.EASE_IN)
	tween.tween_callback(clear_fumble_marks)

## EIN Umriss: dünne Linien statt Fläche - es ist eine Silhouette, kein Fenster.
func _build_fumble_mark(mark: Dictionary, side_px: float) -> Control:
	var fresh: bool = bool(mark.get("fresh", false))
	var tint := FUMBLE_COLOR if fresh else FUMBLE_MARK_CALM
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center: Vector2 = mark.get("pixel", Vector2.ZERO)
	frame.size = Vector2.ONE * side_px
	frame.position = center - frame.size * 0.5
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = tint
	box.set_border_width_all(maxi(1, int(side_px * 0.055)))
	box.set_corner_radius_all(int(side_px * 0.18))
	frame.add_theme_stylebox_override("panel", box)

	var value := int(mark.get("value", 0))
	if value > 0:
		var label := Label.new()
		label.text = str(value)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", maxi(8, int(side_px * 0.52)))
		label.add_theme_color_override("font_color", tint)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.add_child(label)
	return frame

func clear_fumble_marks() -> void:
	if _fumble_marks != null and is_instance_valid(_fumble_marks):
		_fumble_marks.queue_free()
	_fumble_marks = null

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

## Spannt den Schwarzmarkt über rect auf (Tasche unter den Automaten). Sichtbar
## macht ihn scene_root beim Verdrahten (set_secret_shop_installed).
func place_secret_shop_window(rect: Rect2) -> void:
	secret_shop_window.position = rect.position
	secret_shop_window.size = rect.size
	secret_shop_window.refresh()
	_link_secret_shop_to_hub()
	_sync_reflection_windows()

## Ader Schwarzmarkt -> Hub: dieselbe gerade Waagerechte wie die Automaten-Ader,
## nur eine Etage tiefer - auf halber Höhe der Überlappung beider Fenster, wo nur
## Filz liegt. Sie wird immer gelegt, aber wie der Laden erst mit ihm sichtbar.
func _link_secret_shop_to_hub() -> void:
	if secret_hub_strip == null or hub == null or hub.size.x <= 0.0 \
			or secret_shop_window == null or secret_shop_window.size.x <= 0.0:
		return
	var top := maxf(hub.position.y, secret_shop_window.position.y)
	var bottom := minf(hub.position.y + hub.size.y,
		secret_shop_window.position.y + secret_shop_window.size.y)
	if bottom <= top:
		return  # keine Höhen-Überlappung - keine gerade Ader möglich
	secret_hub_strip.link_horizontal(secret_shop_window.position.x + secret_shop_window.size.x,
		hub.position.x, (top + bottom) * 0.5, HUB_STRIP_WIDTH)

## Blendet den Schwarzmarkt ein/aus (Entdeckung bzw. frischer Lauf).
func set_secret_shop_installed(installed: bool) -> void:
	if secret_shop_window == null or secret_shop_window.size.x <= 0.0:
		return  # noch nicht platziert
	if secret_hub_strip != null:
		secret_hub_strip.visible = installed  # ohne Laden liegt dort keine Ader
	if secret_shop_window.visible == installed:
		return
	secret_shop_window.visible = installed
	if installed:
		secret_shop_window.refresh()
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
	if workshop_hub_strip == null or hub == null or hub.size.x <= 0.0 \
			or workshop_window == null or not workshop_window.visible:
		return
	var top := maxf(hub.position.y, workshop_window.position.y)
	var bottom := minf(hub.position.y + hub.size.y, workshop_window.position.y + workshop_window.size.y)
	if bottom <= top:
		return  # keine Höhen-Überlappung - keine gerade Ader möglich
	workshop_hub_strip.link_horizontal(hub.position.x + hub.size.x,
		workshop_window.position.x, (top + bottom) * 0.5, HUB_STRIP_WIDTH)

## Legt die Schubladen unter der Werkbank aus (Reihenfolge = CATEGORIES, danach
## der Sonderbestand).
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

func _drawer_index(category: String) -> int:
	for i in supply_drawers.size():
		if supply_drawers[i].category == category:
			return i
	return -1

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
	# Der Kombi-Cluster ist KEIN Fenster mehr: die Chips stehen auf dem Filz.
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
	if secret_shop_window != null and secret_shop_window.visible:
		rects.append(Vector4(secret_shop_window.position.x, secret_shop_window.position.y,
			secret_shop_window.position.x + secret_shop_window.size.x,
			secret_shop_window.position.y + secret_shop_window.size.y))
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
	# Die Fumble-Welle leuchtet NUR auf den Fenstern - gleiche Maske wie das Glas.
	if fumble_wave != null:
		var wave_material: ShaderMaterial = fumble_wave.material
		wave_material.set_shader_parameter("window_count", rects.size())
		wave_material.set_shader_parameter("window_rects", rects)
		wave_material.set_shader_parameter("window_radius", radii)
	# Der Filz blendet seine Textur unter den Fenstern aus (gleiche Rechtecke).
	if _felt_material != null:
		_felt_material.set_shader_parameter("window_count", rects.size())
		_felt_material.set_shader_parameter("window_rects", rects)
		_felt_material.set_shader_parameter("window_radius", radii)

## Freie Rasterplätze des Chip-Netzes - die letzte Reihe ist nie voll (13
## Kombinationen auf CLUSTER_COLUMNS Spalten). Zeilenweise sortiert, der letzte
## Eintrag ist also der Platz unten rechts. Abgeleitet aus den ECHTEN Zellen,
## damit ein Umbau des Clusters die freien Plätze automatisch mitnimmt.
func free_cluster_slots() -> Array[Rect2]:
	var slots: Array[Rect2] = []
	if combo_cells.is_empty():
		return slots
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var taken := {}
	var cell_size := Vector2.ZERO
	for key in combo_cells:
		var cell: ComboCellView = combo_cells[key]
		cell_size = cell.size
		var spot := Vector2(snappedf(cell.position.x, 0.5), snappedf(cell.position.y, 0.5))
		if not xs.has(spot.x):
			xs.append(spot.x)
		if not ys.has(spot.y):
			ys.append(spot.y)
		taken[spot] = true
	xs.sort()
	ys.sort()
	for y: float in ys:
		for x: float in xs:
			if not taken.has(Vector2(x, y)):
				slots.append(Rect2(Vector2(x, y), cell_size))
	return slots

## Verschiebt den ganzen Kombi-Cluster (Sockel + Adernetz) mittig auf center_px
## (Pixelposition des Editor-Ankers CombosBlock); cluster_rect wandert mit.
func place_combo_cluster(center_px: Vector2) -> void:
	var delta := center_px - cluster_rect.get_center()
	for key in combo_cells:
		combo_cells[key].position += delta
	cluster_rect.position += delta
	_lay_combo_wiring()
	_sync_reflection_windows()

## Sammelschienen-x: je Zelle einen halben Spaltenabstand links und rechts
## daneben, behalten werden aber nur die INNEREN - die, die zwei Spalten teilen.
## Die äußeren bedienten nur je eine Seite und verstellten den Filz.
func combo_bus_xs() -> PackedFloat32Array:
	var stub := CELL_GAP.x * 0.5
	var left := {}
	var right := {}
	for key: String in combo_cells:
		var cell: ComboCellView = combo_cells[key]
		left[roundi(cell.position.x - stub)] = true
		right[roundi(cell.position.x + cell.size.x + stub)] = true
	var kept := PackedFloat32Array()
	for x in left:
		if right.has(x):
			kept.append(float(x))
	kept.sort()
	return kept

## Verlegt das Adernetz der Chips, so sparsam wie möglich: zwei senkrechte
## Sammelschienen in den Spaltenlücken, EINE Quer-Schiene unten (dort speist die
## Hub-Ader ein), und je Chip nur EIN Stich pro Nachbarschiene - auf der
## mittleren Pin-Höhe, die auch die Kauf-Kometen anfahren. Alles in Screen-Pixeln.
func _lay_combo_wiring() -> void:
	if combo_wiring == null or combo_cells.is_empty():
		return
	var buses := combo_bus_xs()
	if buses.is_empty():
		return
	var offsets := ComboChipView.pin_offsets_px(CELL_SIZE)
	var tip_dx: float = offsets["tip_dx"]
	var row: float = offsets["rows"][1]
	var stub := CELL_GAP.x * 0.5
	var rails: Array[PackedVector2Array] = []
	for key: String in combo_cells:
		var cell: ComboCellView = combo_cells[key]
		var rect := Rect2(cell.position, cell.size)
		var y := rect.get_center().y + row
		var left_x := roundi(rect.position.x - stub)
		var right_x := roundi(rect.end.x + stub)
		for bus: float in buses:
			if roundi(bus) == left_x:
				rails.append(PackedVector2Array([
					Vector2(bus, y), Vector2(rect.get_center().x - tip_dx, y)]))
			elif roundi(bus) == right_x:
				rails.append(PackedVector2Array([
					Vector2(bus, y), Vector2(rect.get_center().x + tip_dx, y)]))
	for bus: float in buses:
		rails.append(PackedVector2Array([
			Vector2(bus, cluster_rect.position.y), Vector2(bus, cluster_rect.end.y)]))
	if buses.size() > 1:
		rails.append(PackedVector2Array([
			Vector2(buses[0], cluster_rect.end.y),
			Vector2(buses[buses.size() - 1], cluster_rect.end.y)]))
	combo_wiring.link_rails(rails, COMBO_WIRING_WIDTH)

## Kometen-Pfade zum Chip index: von beiden Enden JEDER benachbarten Sammel-
## schiene über die Schiene auf die mittlere Pin-Höhe, dann in die Pin-Spitze.
## Randspalten hängen nur an einer Schiene, also zwei Pfade statt vier - gleiche
## Laufzeit, gleichzeitige Ankunft.
func wiring_paths_to_cell(index: int) -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	if index < 0 or index >= DiceScoring.HAND_PRIORITY.size():
		return paths
	var key: String = DiceScoring.HAND_PRIORITY[index]
	if not combo_cells.has(key):
		return paths
	var cell: ComboCellView = combo_cells[key]
	var rect := Rect2(cell.position, cell.size)
	var offsets := ComboChipView.pin_offsets_px(CELL_SIZE)
	var tip_dx: float = offsets["tip_dx"]
	var y: float = rect.get_center().y + float(offsets["rows"][1])
	var stub := CELL_GAP.x * 0.5
	var neighbours := PackedFloat32Array()
	for bus: float in combo_bus_xs():
		if roundi(bus) == roundi(rect.position.x - stub) or roundi(bus) == roundi(rect.end.x + stub):
			neighbours.append(bus)
	for bus_x: float in neighbours:
		var tip_x: float = rect.get_center().x + (tip_dx if bus_x > rect.get_center().x else -tip_dx)
		for from_y: float in [cluster_rect.position.y, cluster_rect.end.y]:
			paths.append(PackedVector2Array([
				Vector2(bus_x, from_y), Vector2(bus_x, y), Vector2(tip_x, y)]))
	return paths

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
func update_pit_score(base: int, mult: float) -> void:
	if base_counter.visible and is_equal_approx(base_counter.value, float(base)) \
			and is_equal_approx(mult_counter.value, mult):
		return
	total_orb.visible = false
	base_counter.position = _base_home
	mult_counter.position = _mult_home
	base_counter.visible = true
	mult_counter.visible = true
	base_counter.set_value(base)
	mult_counter.set_value(mult)

## Nimmt die Wertungs-Orbs vom Grubenboden (die Vertragswahl braucht die Fläche).
## Der nächste update_pit_score holt sie von selbst zurück.
func hide_pit_score() -> void:
	base_counter.visible = false
	mult_counter.visible = false
	total_orb.visible = false

var _crit_tween: Tween

## Krit-Einschlag (Ankunft eines Krit-Kometen): die Basis zieht normal nach,
## der Mult-Orb spannt sich überhell an (Hit-Stop), slammt dann auf den neuen
## Wert - Stoßwelle + Nachhall-Welle in Krit-Farbe, ×N-Zahl, abklingendes
## Beben, sauber zurück auf den Ruheplatz. Liefert die Gesamtdauer.
func crit_pit_mult(base: int, mult_after: float, crit_x: float) -> float:
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
		pit_impulse(center, "crit")  # die Stoßwelle wäscht durch die Grube
		spawn_gain_number(center, ScoreBreakdown.format_mult(crit_x), CRIT_COLOR, 1.5))
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

## Schwebende Zuwachs-Zahl der Zähl-Animation ("+3", "×2"): schießt aus dem
## Würfel heraus, bremst hart ab und verlischt kurz vor dem Stillstand. Rein
## schmückend - die maßgeblichen Zahlen laufen über die Zähler.
const GAIN_FONT := 19 * SUPERSAMPLE
const GAIN_DRIFT := 62.0 * SUPERSAMPLE
const GAIN_TIME := 0.9
## Ausblenden ab GAIN_FADE_DELAY: endet vor dem Stillstand der Bahn.
const GAIN_FADE_DELAY := 0.34
const GAIN_FADE_TIME := 0.34
## Mindestabstand, den die Zahl über der Würfelnetz-Karte hält.
const GAIN_NET_GAP := 12.0 * SUPERSAMPLE
const GAIN_OUTLINE := Color(0.05, 0.03, 0.08)
## Bewegungs-Unschärfe: kontinuierlicher Farbschleier hinter der Zahl (am
## Glyph deckend, zum Schwanz auslaufend), begrenzt auf GAIN_BLUR_LENGTH.
const GAIN_BLUR_LENGTH := 55.0 * SUPERSAMPLE
const GAIN_BLUR_WIDTH := 0.8   # Anteil der Zahlbreite
const GAIN_BLUR_ALPHA := 0.6

var _gain_blur_texture: GradientTexture2D  # geteilter Verlauf, einmalig gebaut

## rise = die Zahl STEIGT statt zu fallen (Geld aus einem zählenden Würfel).
## Der Schleier hängt dann unter dem Kopf statt darüber, und die Netz-Karten-
## Kappung entfällt: sie hält nur fallende Zahlen von der Karte fern.
func spawn_gain_number(from_px: Vector2, text: String, color: Color, font_scale: float = 1.0, rise: bool = false) -> void:
	var label := _make_gain_label(text, color, font_scale)
	var streak := _make_gain_blur(color, rise)
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
	# EXPO_OUT: der Weg ist fast sofort zurückgelegt, danach kriecht die Zahl nur
	# noch aus - genau in diesem Auslauf blendet sie weg.
	tween.tween_method(
		func(dist: float) -> void: _advance_gain_number(label, streak, start, center_x, width, half_h, dist, rise),
		0.0, GAIN_DRIFT if rise else _gain_drift(center_x, start.y + half_h), GAIN_TIME).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, GAIN_FADE_TIME).set_delay(GAIN_FADE_DELAY) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(streak, "modulate:a", 0.0, GAIN_FADE_TIME).set_delay(GAIN_FADE_DELAY) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		label.queue_free()
		streak.queue_free())

## Gleitweg, gekappt an der Oberkante der Würfelnetz-Karte: die Zahl darf nie
## in den Netz-Screen hineinlaufen.
func _gain_drift(center_x: float, from_center_y: float) -> float:
	if pit_info_bar == null:
		return GAIN_DRIFT
	var bar := pit_info_bar.get_rect()
	# Nur Zahlen, die von oben auf die Karte zulaufen, werden gekappt.
	if center_x < bar.position.x or center_x > bar.end.x or from_center_y > bar.position.y:
		return GAIN_DRIFT
	return clampf(bar.position.y - GAIN_NET_GAP - from_center_y, 0.0, GAIN_DRIFT)

## Rückt die Zahl auf ihre Gleithöhe und spannt den Schleier von der Kopfmitte
## um bis zu GAIN_BLUR_LENGTH gegen die Flugrichtung auf.
func _advance_gain_number(label: Label, streak: TextureRect, start: Vector2, center_x: float, width: float, half_h: float, dist: float, rise: bool = false) -> void:
	label.position.y = (start.y - dist) if rise else (start.y + dist)
	var head := label.position.y + half_h
	var origin := start.y + half_h
	var top := minf(head, origin) if rise else maxf(origin, head - GAIN_BLUR_LENGTH)
	var bottom := minf(origin, head + GAIN_BLUR_LENGTH) if rise else head
	streak.position = Vector2(center_x - width / 2.0, top)
	streak.size = Vector2(width, maxf(bottom - top, 1.0))

## rise dreht den Verlauf: der deckende Kopf steht dann oben, der Schwanz unten.
func _make_gain_blur(color: Color, rise: bool = false) -> TextureRect:
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
	streak.flip_v = rise
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
	# Eintritt genau in die ECKE unten rechts des Chip-Netzes (rechte Schiene ×
	# Quer-Schiene) statt mittig auf die Quer-Schiene: so trifft die Ader einen
	# Knoten des Netzes, nicht seine Mitte.
	var buses := combo_bus_xs()
	var enter_x: float = buses[buses.size() - 1] if not buses.is_empty() \
		else cluster_rect.get_center().x
	led_strip.link_edges(hub.position.y, _hub_strip_exit_x(false),
		cluster_rect.end.y, enter_x, _hub_strip_lane_y(), HUB_STRIP_WIDTH)

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

## Entdeckung des Schwarzmarkts: der frisch aufgedeckte Laden meldet sich mit
## einer Stoßwelle - dieselbe Sprache wie ein neu installierter Automat.
func celebrate_secret_shop_install(color: Color) -> float:
	if secret_shop_window == null or not secret_shop_window.visible:
		return 0.0
	var center := secret_shop_window.position + secret_shop_window.size * 0.5
	var wave := ScoreShockwave.new()
	add_child(wave)
	wave.setup(center, Color(color.r, color.g, color.b, 0.9), secret_shop_window.size.x * 0.9, 0.9)
	return 0.9

## Lieferung ins Lager (Hub-Belohnung): eine Stoßwelle über der Werkbank, in
## derselben Sprache wie ein frisch installierter Automat. Bewusst KEIN Komet:
## die Paket-Ablage hat keinen Adern-Anschluss, und eine neue Ader nur für diesen
## Moment zu legen wäre teurer als die Geste wert ist.
func celebrate_workshop_delivery(color: Color) -> void:
	if workshop_window == null or not workshop_window.visible:
		return
	var center := workshop_window.position + workshop_window.size * 0.5
	var wave := ScoreShockwave.new()
	add_child(wave)
	wave.setup(center, Color(color.r, color.g, color.b, 0.9), workshop_window.size.x * 0.5, 0.7)

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
	if combos_score_strip != null and not combo_cells.is_empty():
		# Austritt am OBEREN Ende der LINKEN Sammelschiene: die Hub-Ader speist
		# unten rechts ein, also verlässt das Licht das Netz diagonal gegenüber -
		# und beide Adern treffen je eine Ecke, keine freie Strecke.
		var buses := combo_bus_xs()
		var exit_x: float = buses[0] if not buses.is_empty() \
			else cluster_rect.get_center().x
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
## Kurzer, gedämpfter Komet (deutlich dünner/dunkler als die Wertungs-Trails).
const OVERCLOCK_PULSE_COLOR := Color(1.3, 1.0, 0.3, 0.6)
const OVERCLOCK_PULSE_CORE := 3.0 * SUPERSAMPLE
const OVERCLOCK_PULSE_GLOW := 7.0 * SUPERSAMPLE
const OVERCLOCK_COMET := 34.0 * SUPERSAMPLE  # Kometen-Länge (sehr kurz)
## Aus der Bank bezahlte Übertaktung: dieselbe ⚡-Signalfarbe, gleiche Dämpfung.
const CHARGE_PULSE_COLOR := Color(CasinoStyle.CHARGE.r, CasinoStyle.CHARGE.g,
	CasinoStyle.CHARGE.b, 0.6)

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
	await get_tree().create_timer(_pulse_wiring_to_chip(combo_key, OVERCLOCK_PULSE_COLOR)).timeout

## Energie-Übertaktung: die Kondensatorbank steht an der Ecke des Chip-Netzes,
## ihr Licht fährt also nur noch die verlegten Schienen zum Chip - kein Hub-Weg,
## denn bezahlt wird aus der Bank. Gebucht ist beim Start längst.
func play_charge_overclock_pulse(combo_key: String) -> void:
	await get_tree().create_timer(
		_pulse_wiring_to_chip(combo_key, CHARGE_PULSE_COLOR)).timeout

## Bus-Kometen von den Randkontakten zum Chip; liefert ihre Laufzeit.
func _pulse_wiring_to_chip(combo_key: String, color: Color) -> float:
	var paths := wiring_paths_to_cell(DiceScoring.HAND_PRIORITY.find(combo_key))
	if paths.is_empty():
		return 0.3
	# Gleiche Dauer für alle vier Pfade (gleichzeitige Ankunft); die Dauer
	# folgt dem LÄNGSTEN Pfad bei einheitlicher Geschwindigkeit.
	var longest := 0.0
	for path in paths:
		longest = maxf(longest, _path_length(path))
	var board_time := maxf(0.12, longest / PULSE_SPEED)
	for path in paths:
		_pulse_along(path, board_time)
	return board_time

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

## Ladungs-Komet Hub -> Kondensator-Bank: die zweite Etappe einer Überladungs-
## Stufe. Sie fährt die Hub-Cluster-Ader, an deren Eintritt die Bank steht.
func charge_comet(to_px: Vector2, color: Color) -> float:
	if led_strip == null or led_strip.strip_path.size() < 2 or hub == null:
		return 0.0
	var path := _route_via_strip(hub.position + hub.size * 0.5, led_strip, to_px)
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

## Zahlungs-Komet Hub -> Schwarzmarkt: Eintrittsgeld, Kauf und Neuwurf fahren als
## Ladung die Hinterzimmer-Ader hinüber (verlegt ist sie Laden -> Hub, die Zahlung
## fährt dagegen - wie der Automaten-Einsatz). Liefert die Laufzeit.
func secret_shop_pay_comet(color: Color) -> float:
	if secret_hub_strip == null or secret_hub_strip.strip_path.size() < 2:
		return 0.0
	var path := secret_hub_strip.strip_path.duplicate()
	path.reverse()
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

## Gewonnenes Paket Automat -> Werkbank: Automaten-Ader in den Hub, Werkstatt-Ader
## zur Werkbank. Liefert die Laufzeit.
func slot_pack_comet(from_px: Vector2, color: Color) -> float:
	if workshop_window == null or not workshop_window.visible:
		return 0.0
	var to_px := workshop_window.position + workshop_window.size * 0.5
	var path := _route_via_strips(from_px, [slot_hub_strip, workshop_hub_strip], to_px)
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

## Geld-Komet eines Zuges (Goldseiten, Seelen-Geld, Streulicht): er startet am
## Datenbus der Grube, umrundet die Grubenhälfte am RAHMEN, fährt über die
## Bank-Leiste in den Hub und von dort über die Geld-Leiste in die Truhe -
## dieselbe Bahn wie ein Rundenende-Charm, nur ohne dessen Konsolen-Vorlauf.
## from_px (optional): Geld EINER Zündung startet am WÜRFEL und läuft von dort
## im eigenen Fenster auf den Datenbus - danach dieselbe Bahn.
func take_money_comet(color := SIDE_MONEY_COLOR, from_px := Vector2.INF) -> float:
	if pit_window == null or hub == null or treasure_strip == null \
			or treasure_strip.strip_path.size() < 2:
		return 0.0
	var pr := Rect2(pit_window.position, pit_window.size)
	var pcx := pr.get_center().x
	var entry := Vector2(pcx, pr.position.y)
	var exit := Vector2(pcx, pr.end.y)
	var path := PackedVector2Array()
	if from_px.is_finite():
		path.append(from_px)
	path.append(entry)
	for corner in _border_route(pr, entry, exit):
		path.append(corner)
	path.append(exit)
	path.append(Vector2(hub.position.x + hub.size.x * 0.5, hub.position.y))
	var to_px := treasure_strip.strip_path[treasure_strip.strip_path.size() - 1]
	var tail := _route_via_strips(path[path.size() - 1], [treasure_strip], to_px)
	for i in range(1, tail.size()):
		path.append(tail[i])
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

## Rundenende-Komet zur WERKSTATT selbst (Politur greift an die Würfel, nicht in
## eine Schublade): dieselbe Bahn wie der Gravur-Meteor, nur endet sie im Fenster.
func charm_workshop_comet(from_px: Vector2, color: Color) -> float:
	if workshop_window == null or not workshop_window.visible:
		return 0.0
	var to_px := workshop_window.position + workshop_window.size * 0.5
	var path := _round_end_route(from_px, [workshop_hub_strip], to_px)
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

## Gravur-Gewinn einer Nebenwette bis in seinen Schubladen-Platz: der
## Auszahlungs-Komet zum Hub, dann Werkstatt- und Schubladen-Ader (derselbe
## Aderweg wie ein Automaten-Gewinn). Liefert die Laufzeit.
func side_bet_engraving_comet(category: String, slot_px: Vector2, color: Color) -> float:
	var path := _hub_to_side_path()
	if path.size() < 2 or workshop_window == null or not workshop_window.visible:
		return 0.0
	path.reverse()
	var tail := _route_via_strips(path[path.size() - 1],
		[workshop_hub_strip, _supply_strip(category)], slot_px)
	for i in range(1, tail.size()):
		path.append(tail[i])
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

func _build_pit_actions() -> void:
	pit_actions_root = Control.new()
	pit_actions_root.name = "PitActions"
	pit_actions_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pit_actions_root.size = Vector2(PIT_ACTION_SIZE.x * 4.0, PIT_ACTION_SIZE.y)  # bis place_pit_actions
	add_child(pit_actions_root)

	take_action_button = _make_pit_button("Nehmen", CasinoStyle.GOLD, CasinoStyle.GOLD_DARK)
	pit_actions_root.add_child(take_action_button)

	roll_action_button = _make_pit_button("Würfeln", CasinoStyle.GREEN, CasinoStyle.GREEN_DARK)
	pit_actions_root.add_child(roll_action_button)

	# Bank-Knopf: über Würfeln im rechten Flügel, erscheint erst ab Stufe 1;
	# kleinere Schrift, damit "Beenden ⚡×N" in die Knopfbreite passt.
	bank_action_button = _make_pit_button("Beenden", GOAL_STAGE_COLOR, GOAL_STAGE_DARK)
	# Kleinere Schrift als die Nachbarn: links von "Nehmen" steht nur die Lücke
	# zur Grubenwand zur Verfügung, und "Beenden ⚡×N" muss ganz hineinpassen.
	bank_action_button.add_theme_font_size_override("font_size", 7 * SUPERSAMPLE)
	bank_action_button.visible = false
	pit_actions_root.add_child(bank_action_button)

	# Rückblick: über dem Bank-Knopf im rechten Flügel, nur zwischen zwei Händen.
	log_action_button = _make_pit_button("Rückblick", CasinoStyle.BLUE, CasinoStyle.BLUE_DARK)
	log_action_button.add_theme_font_size_override("font_size", 9 * SUPERSAMPLE)
	log_action_button.visible = false
	pit_actions_root.add_child(log_action_button)

	# Irrlicht: der Kipp-Knopf klappt eine Reihe mit den vier Nachbarseiten auf.
	# Beides ist Gruben-Mobiliar und geht mit dem Rest, wenn die Kamera abreist.
	tip_action_button = _make_pit_button("Kippen", CasinoStyle.BLUE, CasinoStyle.BLUE_DARK)
	tip_action_button.visible = false
	pit_actions_root.add_child(tip_action_button)
	tip_face_row = HBoxContainer.new()
	tip_face_row.name = "TipFaces"
	tip_face_row.add_theme_constant_override("separation", int(PIT_ACTION_GAP))
	tip_face_row.visible = false
	pit_actions_root.add_child(tip_face_row)
	for i in 4:
		var face_button := _make_pit_button("?", CasinoStyle.BLUE, CasinoStyle.BLUE_DARK)
		face_button.custom_minimum_size = Vector2(PIT_ACTION_SIZE.y, PIT_ACTION_SIZE.y)
		face_button.size = Vector2(PIT_ACTION_SIZE.y, PIT_ACTION_SIZE.y)
		tip_face_row.add_child(face_button)
		tip_face_buttons.append(face_button)

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

## Passt die Aktions-Knöpfe an das Würfelnetz-Feld an: Nehmen links daneben,
## Würfeln rechts daneben - beide in fester Knopfhöhe, bündig mit der
## Feld-Unterkante -, "Beenden" links neben "Nehmen" in derselben Reihe und der
## Rückblick oben rechts in der Grubenecke.
func place_pit_actions(bar_rect: Rect2) -> void:
	if pit_actions_root == null:
		return
	for button: Button in [take_action_button, roll_action_button, log_action_button]:
		button.custom_minimum_size = PIT_ACTION_SIZE
		button.size = PIT_ACTION_SIZE
	# "Beenden" darf schmaler bleiben als die anderen (siehe _anchor_bank_button).
	bank_action_button.custom_minimum_size = Vector2(0.0, PIT_ACTION_SIZE.y)
	pit_actions_root.position = bar_rect.position - Vector2(PIT_ACTION_SIZE.x + PIT_ACTION_GAP, 0.0)
	pit_actions_root.size = Vector2(
		bar_rect.size.x + 2.0 * (PIT_ACTION_SIZE.x + PIT_ACTION_GAP),
		bar_rect.size.y)
	# Bündig mit der Feld-Unterkante (Feldhöhe minus Knopfhöhe).
	var side_y := bar_rect.size.y - PIT_ACTION_SIZE.y
	take_action_button.position = Vector2(0.0, side_y)
	# Der Kipp-Knopf sitzt über "Nehmen", seine Seiten-Reihe direkt darüber.
	tip_action_button.position = Vector2(0.0, side_y - PIT_ACTION_SIZE.y - PIT_ACTION_GAP)
	tip_face_row.position = Vector2(0.0, tip_action_button.position.y - PIT_ACTION_SIZE.y - PIT_ACTION_GAP)
	roll_action_button.position = Vector2(pit_actions_root.size.x - PIT_ACTION_SIZE.x, side_y)
	_place_pit_wing_buttons(side_y)

## "Beenden" und der Rückblick hängen an der GRUBENWAND, nicht am Netzfeld: der
## Bank-Knopf füllt die Lücke zwischen Wand und "Nehmen" (seine Breite ist damit
## gerechnet, nicht geraten - links bleiben nur ~1,1 Knopfbreiten), der Rückblick
## steht in der oberen rechten Ecke. Ohne Grubenfenster (2D-Rückfall) bleibt es
## beim alten rechten Flügel.
func _place_pit_wing_buttons(side_y: float) -> void:
	if pit_window == null:
		bank_action_button.position = Vector2(pit_actions_root.size.x - PIT_ACTION_SIZE.x,
			side_y - PIT_ACTION_GAP - PIT_ACTION_SIZE.y)
		log_action_button.position = Vector2(pit_actions_root.size.x - PIT_ACTION_SIZE.x,
			side_y - 2.0 * (PIT_ACTION_GAP + PIT_ACTION_SIZE.y))
		return
	_bank_row_y = side_y
	_anchor_bank_button()
	var right := pit_window.position.x + pit_window.size.x - pit_actions_root.position.x
	log_action_button.position = Vector2(right - PIT_WALL_MARGIN - PIT_ACTION_SIZE.x,
		pit_window.position.y - pit_actions_root.position.y + PIT_WALL_MARGIN)

## "Beenden ⚡×N" wächst mit seiner Zahl, darum hängt es mit der RECHTEN Kante an
## "Nehmen" - so läuft es nie in den Nachbarn, sondern höchstens zur Wand hin.
func set_bank_label(text: String) -> void:
	if bank_action_button == null or bank_action_button.text == text:
		return
	bank_action_button.text = text
	_anchor_bank_button()

## Es wird NICHT an der Wand geklemmt: lieber ragt der Knopf im Extremfall in den
## Grubenrand, als dass er "Nehmen" überdeckt - in der echten Grube reicht der
## Platz auch für die zweistellige Stufenzahl.
func _anchor_bank_button() -> void:
	if pit_actions_root == null or pit_window == null:
		return
	bank_action_button.reset_size()
	bank_action_button.position = Vector2(
		take_action_button.position.x - PIT_ACTION_GAP - bank_action_button.size.x, _bank_row_y)

## Trifft pixel einen sichtbaren Aktions-Knopf? Die Wurzel spannt die ganze
## Grubenbreite - für die Maus-Weiterleitung zählen nur die Knöpfe selbst,
## sonst schluckt der Streifen Klicks auf Würfel am Grubenrand.
func pit_actions_hit(pixel: Vector2) -> bool:
	if pit_actions_root == null or not pit_actions_root.visible:
		return false
	for button in [take_action_button, roll_action_button, bank_action_button, log_action_button]:
		if button.visible and Rect2(pit_actions_root.position + button.position, button.size).has_point(pixel):
			return true
	return false

## Schleier des Erinnerungs-Modus: ein dunkles Rechteck über den Fenstern, unter
## dem Rückblick selbst. Kein Licht, kein Shader - der Boden hat ein Lichtbudget,
## und der Schleier muss beim Schließen restlos verschwinden.
func set_memory_veil(active: bool) -> void:
	if memory_veil == null:
		if not active:
			return
		memory_veil = ColorRect.new()
		memory_veil.name = "MemoryVeil"
		memory_veil.color = MEMORY_VEIL_COLOR
		memory_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		memory_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(memory_veil)
	memory_veil.visible = active
	if active:
		move_child(memory_veil, get_child_count() - 1)

## Spannt das kompakte Würfelnetz-Feld über rect auf (mit Abstand zur
## Grubenwand): das Netz sitzt mittig, Zellgröße füllt das Feld.
func place_pit_info_bar(rect: Rect2) -> void:
	if pit_info_bar == null:
		return
	pit_info_bar.position = rect.position
	pit_info_bar.size = rect.size
	var pad := rect.size.y * 0.1
	# Zellgröße füllt das Feld (kleinere der beiden Achsen bestimmt, Netz ist 4:3).
	var cell_w := (rect.size.x - pad * 2.0) / (4.0 + 3.0 * DieNetView.GAP_FACTOR)
	var cell_h := (rect.size.y - pad * 2.0) / (3.0 + 2.0 * DieNetView.GAP_FACTOR)
	_pit_net_cell = minf(cell_w, cell_h)
	pit_net_holder.size = DieNetView.net_size(_pit_net_cell)
	pit_net_holder.position = (rect.size - pit_net_holder.size) / 2.0

## Spannt die einzeilige Material-Erklärleiste UNTER der Grube auf (breit, damit
## der Text nie umbricht); zentriert auf rect.
func place_pit_net_hint(rect: Rect2) -> void:
	if pit_net_hint == null:
		return
	pit_net_hint.position = rect.position
	pit_net_hint.size = rect.size
	pit_net_hint.add_theme_font_size_override("font_size", maxi(10, int(rect.size.y * 0.55)))

## Spannt den Marken-Streifen am oberen Grubenrand auf. Die Hinweis-Karte
## entsteht erst hier: ihre Schriftgrade hängen an der Streifenhöhe.
func place_pit_deal_rail(rect: Rect2) -> void:
	if pit_deal_rail == null:
		return
	_pit_deal_rect = rect
	_pit_deal_u = maxf(rect.size.y / PIT_DEAL_U_DIV, 1.0)
	if pit_deal_hint == null:
		pit_deal_hint = HintCard.new(_pit_deal_u)
		pit_deal_hint.name = "PitDealHint"
		pit_window.add_child(pit_deal_hint)
	set_pit_deal_tokens(_pit_deal_sides)

## Setzt die wirkenden Deal-Seiten (GameRun.active_deal_sides) - dieselben, die
## am Hub-Rad hängen. Merkt sie sich, weil der Streifen erst später Maße bekommt.
func set_pit_deal_tokens(sides: Array[Dictionary]) -> void:
	if pit_deal_rail == null:
		return
	_pit_deal_sides = sides.duplicate()
	hide_pit_deal_hint()
	pit_deal_rail.set_sides(_pit_deal_sides, _pit_deal_u)
	_layout_pit_deal_rail()

## Reihe mittig in den Streifen (sie wächst mit der Markenzahl).
func _layout_pit_deal_rail() -> void:
	if pit_deal_rail == null or _pit_deal_rect.size.y <= 0.0:
		return
	pit_deal_rail.reset_size()
	pit_deal_rail.position = _pit_deal_rect.position \
		+ (_pit_deal_rect.size - pit_deal_rail.size) * 0.5

## Der Streifen der Grubenmarken - der Rückblick stellt seine Leiste dorthin.
func pit_deal_rect() -> Rect2:
	return _pit_deal_rect

## Abrechnung: die Grubenmarken wischen mit denen am Hub (gleiche Dauer).
func sweep_pit_deal_tokens() -> float:
	if pit_deal_rail == null:
		return 0.0
	hide_pit_deal_hint()
	return pit_deal_rail.sweep(_pit_deal_rect.size.y)

## Marke unter dem Display-Pixel, oder null (scene_root fragt je Frame).
func pit_deal_token_at(pixel: Vector2) -> Control:
	return pit_deal_rail.token_at(pixel) if pit_deal_rail != null else null

func show_pit_deal_hint(token: Control) -> void:
	if pit_deal_hint == null:
		return
	var hint := pit_deal_rail.hint_for(token)
	if hint.is_empty():
		return
	pit_deal_hint.show_for(token, pit_window, hint["title"], hint["body"],
		hint["accent"], _pit_deal_u * 1.2)

func hide_pit_deal_hint() -> void:
	if pit_deal_hint != null:
		pit_deal_hint.hide_card()

## Zeigt das Würfelnetz des überfahrenen Würfels; up_face (-1 = keiner)
## bekommt den Gold-Rahmen. Die Hover-Logik in scene_root ruft das jeden Frame.
## Die Sichtbarkeit des Felds selbst steuert _sync_screen_action_buttons.
func set_pit_die(def: DieDefinition, up_face: int) -> void:
	if pit_info_bar == null:
		return
	if def != _pit_net_def or up_face != _pit_net_face:
		_pit_net_def = def
		_pit_net_face = up_face
		_clear_pit_net()
		pit_net_holder.add_child(DieNetView.build(def, up_face, _pit_net_cell))

## Lässt die Runen EINER Seite in der Grubenkarte mit aufblitzen - dieselbe Uhr
## wie am Würfel drei Meter weiter, aber NUR über Farbe und Breite. Ein wandernder
## Kopf ist bei Kartengröße nicht darstellbar; heller und dicker ist die ehrliche
## Übersetzung von "hat gefeuert".
##
## Das ist die einzige Stelle im Spiel, an der ein Würfelnetz animiert: die Karte
## lebt in diesem Moment ohnehin schon (Leiterbahn-Pulse). Das 30-Würfel-Raster
## bleibt still, weil es sonst bis zu 180 Controls je Frame neu zeichnen müsste -
## die Werkbank ist eine Lesefläche, keine Bühne. Der Aufrufer gibt seine Def mit:
## zeigt die Karte gerade einen ANDEREN Würfel, passiert nichts.
func flare_pit_runes(def: DieDefinition, face_index: int, duration: float) -> void:
	if pit_net_holder == null or def == null or def != _pit_net_def:
		return
	if pit_net_holder.get_child_count() == 0:
		return
	for child in pit_net_holder.get_child(0).get_children():
		var crack := child as DieNetView.RuneGlyph
		if crack == null or (face_index >= 0 and crack.face != face_index):
			continue
		crack.flare = 1.0
		crack.queue_redraw()
		var tween := create_tween()
		tween.tween_method(func(strength: float) -> void:
			if is_instance_valid(crack):
				crack.flare = strength
				crack.queue_redraw(), 1.0, 0.0, duration)

## Leert das Netz (kein Würfel unter der Maus); das Feld bleibt stehen.
func clear_pit_die() -> void:
	if pit_info_bar == null:
		return
	_pit_net_def = null
	_pit_net_face = -2
	_clear_pit_net()
	if pit_net_holder != null:
		pit_net_holder.modulate.a = 1.0

## Deckkraft des Netz-Inhalts (0 = unsichtbar, 1 = voll) - fürs Ausblenden.
func set_pit_net_alpha(a: float) -> void:
	if pit_net_holder != null:
		pit_net_holder.modulate.a = a

## Zeigt der Würfel im Netz-Feld gerade ein Netz?
func has_pit_die() -> bool:
	return _pit_net_def != null

## Face-Index der Netz-Zelle unter dem Display-Pixel (-1 = keine Zelle/leer).
func pit_net_face_at(pixel: Vector2) -> int:
	if _pit_net_def == null:
		return -1
	var local := pixel - pit_info_bar.position - pit_net_holder.position
	return DieNetView.face_at(local, _pit_net_cell)

## Setzt die Material-Erklärzeile unter dem Netz-Feld ("" = ausblenden).
func set_pit_net_hint(text: String) -> void:
	if pit_net_hint == null:
		return
	pit_net_hint.text = text
	pit_net_hint.visible = text != ""

func _clear_pit_net() -> void:
	for child in pit_net_holder.get_children():
		child.queue_free()

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

## Ob unter dem Display-Pixel ein sichtbarer, aktiver Knopf im Teilbaum liegt -
## so unterscheidet scene_root Knopf-Klick von Klick auf freie Fläche.
static func interactive_under(node: Node, point: Vector2) -> bool:
	for child in node.get_children():
		var control := child as Control
		if control != null:
			if not control.visible:
				continue
			if control is BaseButton and not (control as BaseButton).disabled \
					and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
					and control.get_global_rect().has_point(point):
				return true
		if interactive_under(child, point):
			return true
	return false

## Umrechnungsfaktor Weltmeter -> Display-Pixel (aus der Screen-Breite).
func pixels_per_world() -> float:
	return float(size.x) / _z_span
