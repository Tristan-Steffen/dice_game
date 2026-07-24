extends GutTest
## Tier-2-Tests des Tisch-Displays (TableScreen): attach_to legt das Material
## mit ViewportTexture auf das Mesh und leitet die Weltgrenzen aus der
## globalen AABB ab; world_to_pixel bildet Weltpunkte auf Bildschirm-Pixel ab
## (u entlang Welt+Z, v entlang Welt-X, "Bildschirm-oben" = +X).

var screen: TableScreen
var mesh: MeshInstance3D

func before_each() -> void:
	var world := Node3D.new()
	add_child_autofree(world)

	# Nachbau der Tisch-Situation: Screen-Fläche lokal 31.2 x 21.2, Tisch um
	# 90 Grad gedreht und mit Scale 4 (lokal X -> Welt +Z, lokal Z -> Welt -X).
	mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(31.2, 0.2, 21.2)
	mesh.mesh = box
	world.add_child(mesh)
	mesh.global_transform = Transform3D(
		Basis(Vector3(0, 0, 4), Vector3(0, 4, 0), Vector3(-4, 0, 0)),
		Vector3(0, -3.8, 0))

	screen = TableScreen.new()
	world.add_child(screen)
	screen.attach_to(mesh)

func test_attach_sets_viewport_material():
	# Display-Glas als ShaderMaterial (siehe screen_glass.gdshader): die
	# UI-ViewportTexture ist die Anzeige, emission_energy lässt sie leuchten.
	var material := mesh.material_override as ShaderMaterial
	assert_not_null(material)
	assert_eq(material.get_shader_parameter("screen_texture"), screen.get_texture())
	assert_gt(float(material.get_shader_parameter("emission_energy")), 0.0,
		"ohne Emission liest sich die Anzeige nicht als Display")

func test_attach_wires_reflection_into_the_glass():
	# Mit ScreenReflection bekommt das Glas die Spiegeltextur, und die
	# Spiegelebene liegt auf der Glas-Oberfläche (Tisch bei -3.8, siehe unten).
	var reflection := ScreenReflection.new()
	add_child_autofree(reflection)
	screen.attach_to(mesh, reflection)
	var material := mesh.material_override as ShaderMaterial
	assert_eq(material.get_shader_parameter("reflection_texture"), reflection.get_texture())
	assert_almost_eq(reflection.plane_height, -3.8 + 0.2 / 2.0 * 4.0, 0.5)

func test_pit_window_hidden_until_placed_then_traces_the_walls():
	# Die Grube ist ein eigenes "Fenster" des Displays: vor place_pit_window
	# (Maße erst nach attach_to bekannt) unsichtbar, danach exakt das Rechteck
	# der Energiewände - samt DEREN Eckenrundung (der Rahmen zeichnet die
	# Kollisionslinie nach).
	assert_false(screen.pit_window.visible)
	screen.place_pit_window(Rect2(Vector2(100, 200), Vector2(800, 400)), 75.0)
	assert_true(screen.pit_window.visible)
	assert_eq(screen.pit_window.position, Vector2(100, 200))
	assert_eq(screen.pit_window.size, Vector2(800, 400))
	var style: StyleBoxFlat = screen.pit_window.get_theme_stylebox("panel")
	assert_eq(style.corner_radius_top_left, 75)

func test_pit_info_bar_hidden_until_it_has_text():
	# Das Hover-Erklärfeld ist vor der Platzierung unsichtbar und trägt danach
	# den Fenster-Look; leerer Text blendet es aus, echter Text ein.
	assert_false(screen.pit_info_bar.visible)
	screen.place_pit_info_bar(Rect2(Vector2(200, 800), Vector2(900, 180)), 9.0)
	assert_false(screen.pit_info_bar.visible, "platziert, aber ohne Text noch aus")
	assert_eq(screen.pit_info_bar.position, Vector2(200, 800))
	screen.set_pit_info("Rubin – +4 Mult")
	assert_true(screen.pit_info_bar.visible, "mit Text erscheint das Feld")
	assert_eq(screen.pit_info_label.text, "Rubin – +4 Mult")
	screen.set_pit_info("")
	assert_false(screen.pit_info_bar.visible, "leerer Text blendet wieder aus")

func test_pit_waves_ride_inside_the_pit_window():
	# Der Rundenpuls lebt als Overlay IM Gruben-Fenster, leicht eingerückt
	# (der Rahmen bleibt frei); der Shader kennt Maß und Eckenradius.
	screen.place_pit_window(Rect2(Vector2(100, 200), Vector2(800, 400)), 75.0)
	assert_eq(screen.pit_waves.get_parent(), screen.pit_window)
	var inset := TableScreen.PIT_WAVES_INSET
	assert_eq(screen.pit_waves.size, Vector2(800, 400) - Vector2.ONE * inset * 2.0)
	var material: ShaderMaterial = screen.pit_waves.material
	assert_eq(material.get_shader_parameter("rect_size"), screen.pit_waves.size)
	assert_almost_eq(float(material.get_shader_parameter("corner_radius")), 75.0 - inset, 0.01)

func test_round_pulse_fades_in_and_out():
	# set_round_pulse blendet die Wellen weich ein und wieder aus - zwischen den
	# Runden (Shop) ist die Grube still (intensity 0).
	var material: ShaderMaterial = screen.pit_waves.material
	assert_almost_eq(float(material.get_shader_parameter("intensity")), 0.0, 0.001, "still vor der Runde")
	screen.set_round_pulse(true)
	await wait_seconds(TableScreen.PIT_WAVES_FADE + 0.3)
	assert_almost_eq(float(material.get_shader_parameter("intensity")), 1.0, 0.001, "Runde läuft: voller Puls")
	screen.set_round_pulse(false)
	await wait_seconds(TableScreen.PIT_WAVES_FADE + 0.3)
	assert_almost_eq(float(material.get_shader_parameter("intensity")), 0.0, 0.001, "nach der Runde still")

func test_pit_impulse_claims_a_lane_and_frees_it():
	# Punkt-Puls: belegt eine Impuls-Bahn (Ort lokal im Overlay, Farbe der
	# Punktart), läuft in PIT_IMPULSE_TIME aus und gibt die Bahn wieder frei.
	screen.place_pit_window(Rect2(Vector2(100, 200), Vector2(800, 400)), 75.0)
	screen.pit_impulse(Vector2(500, 400), "mult")
	var material: ShaderMaterial = screen.pit_waves.material
	var colors: PackedColorArray = material.get_shader_parameter("impulse_color")
	assert_eq(colors[0], TableScreen.TRAIL_MULT_COLOR, "Mult-Puls trägt die Mult-Farbe")
	var pos: PackedVector2Array = material.get_shader_parameter("impulse_pos")
	assert_eq(pos[0], Vector2(400, 200) - screen.pit_waves.position, "Ort lokal im Overlay")
	await wait_seconds(TableScreen.PIT_IMPULSE_TIME * 0.4)
	var running: PackedFloat32Array = material.get_shader_parameter("impulse_progress")
	assert_between(running[0], 0.001, 0.999, "mitten im Lauf ist die Bahn belegt")
	await wait_seconds(TableScreen.PIT_IMPULSE_TIME)
	var done: PackedFloat32Array = material.get_shader_parameter("impulse_progress")
	assert_almost_eq(done[0], 1.0, 0.001, "ausgelaufen: die Bahn ist wieder frei")

func test_pit_info_bar_shares_the_one_window_look():
	var info_style: StyleBoxFlat = screen.pit_info_bar.get_theme_stylebox("panel")
	var cluster_style: StyleBoxFlat = screen.cluster_frame.get_theme_stylebox("panel")
	assert_eq(info_style.border_color, cluster_style.border_color)

func test_pit_window_shares_the_one_window_look():
	# Alle Tisch-"Fenster" tragen denselben Stil (window_style): das Gruben-
	# Fenster muss in Grund- und Rahmenfarbe dem Kombi-Cluster gleichen.
	var pit_style: StyleBoxFlat = screen.pit_window.get_theme_stylebox("panel")
	var cluster_style: StyleBoxFlat = screen.cluster_frame.get_theme_stylebox("panel")
	assert_eq(pit_style.bg_color, cluster_style.bg_color)
	assert_eq(pit_style.border_color, cluster_style.border_color)
	assert_eq(pit_style.border_width_top, cluster_style.border_width_top)

func test_glass_gets_the_window_rects_for_reflection_masking():
	# NUR die Fenster spiegeln (der Filz dazwischen nicht): das Glas-Material
	# muss die Fenster-Rechtecke kennen (siehe _sync_reflection_windows) -
	# nach attach_to mindestens Cluster + Zielbalken, mit dem Gruben-Fenster
	# eines mehr.
	var material := mesh.material_override as ShaderMaterial
	var before: int = material.get_shader_parameter("window_count")
	assert_gt(before, 0, "Cluster/Zielbalken sind schon gemeldet")
	screen.place_pit_window(Rect2(Vector2(100, 200), Vector2(800, 400)), 75.0)
	var count: int = material.get_shader_parameter("window_count")
	assert_eq(count, before + 1, "das Gruben-Fenster kommt dazu")
	var rects: PackedVector4Array = material.get_shader_parameter("window_rects")
	assert_eq(rects.size(), count)
	assert_eq(rects[0], Vector4(100, 200, 900, 600), "Gruben-Rechteck in Pixeln (Min/Max)")

func test_center_maps_to_screen_center():
	var pixel := screen.world_to_pixel(Vector3.ZERO)
	assert_almost_eq(pixel.x, float(screen.size.x) / 2.0, 0.5)
	assert_almost_eq(pixel.y, float(screen.size.y) / 2.0, 0.5)

func test_screen_up_is_world_plus_x():
	# Welt +X ist "Bildschirm-oben" (siehe scene_root PIT_TOP_ROW_X): der
	# vordere Flächenrand (+42.4) muss auf Pixelzeile 0 fallen.
	var pixel := screen.world_to_pixel(Vector3(42.4, 0, 0))
	assert_almost_eq(pixel.y, 0.0, 0.5)
	assert_almost_eq(pixel.x, float(screen.size.x) / 2.0, 0.5)

func test_u_runs_along_world_plus_z():
	var left := screen.world_to_pixel(Vector3(0, 0, -62.4))
	var right := screen.world_to_pixel(Vector3(0, 0, 62.4))
	assert_almost_eq(left.x, 0.0, 0.5)
	assert_almost_eq(right.x, float(screen.size.x), 0.5)

func test_pixel_to_world_round_trips():
	# Umkehrung von world_to_pixel: ein Pixel -> Welt -> Pixel muss dorthin
	# zurückführen (Grundlage für Kamera-Zoomziel/Klickzone des Clusters).
	for pixel: Vector2 in [Vector2(300, 200), Vector2(780, 530), Vector2(1200, 900)]:
		var world := screen.pixel_to_world(pixel)
		var back := screen.world_to_pixel(world)
		assert_almost_eq(back.x, pixel.x, 0.5)
		assert_almost_eq(back.y, pixel.y, 0.5)

func test_pixel_to_world_uses_surface_height():
	# y der zurückgegebenen Weltposition ist die Screen-Oberfläche (Tisch bei
	# -3.8, Fläche knapp darüber), nicht 0 - sonst zielt der Zoom zu tief.
	var world := screen.pixel_to_world(Vector2(780, 530))
	assert_almost_eq(world.y, -3.8 + 0.2 / 2.0 * 4.0, 0.5)

# --- Platine & Kauf-Lichtlauf ---------------------------------------------------

func test_circuit_board_paths_converge_on_cell():
	# Vier Zulauf-Pfade: gleiche Zielhöhe, Enden an linker bzw. rechter
	# Gehäusekante - gestartet mit gleicher Laufzeit treffen sie gleichzeitig ein.
	var paths := screen.circuit_board.paths_to_cell(0)
	assert_eq(paths.size(), 4, "vier Zulauf-Pfade")
	var target_y: float = paths[0][paths[0].size() - 1].y
	for path in paths:
		assert_eq(path[path.size() - 1].y, target_y, "alle enden auf derselben Höhe")
	assert_eq(paths[0][paths[0].size() - 1].x, paths[1][paths[1].size() - 1].x, "links: gleiche Kante")
	assert_eq(paths[2][paths[2].size() - 1].x, paths[3][paths[3].size() - 1].x, "rechts: gleiche Kante")

func test_circuit_board_paths_start_at_window_border():
	for path in screen.circuit_board.paths_to_cell(3):
		var start_y: float = path[0].y
		assert_true(is_equal_approx(start_y, 0.0) or is_equal_approx(start_y, screen.circuit_board.size.y),
			"Pfad startet am Ober- oder Unterrand des Fensters")

func test_link_hub_to_cluster_builds_led_strip():
	screen.place_hub(Vector2(3400, 2200), Vector2(1500, 1500))
	screen.link_hub_to_cluster()
	assert_gt(screen.led_strip.strip_path.size(), 2, "eine Ader in Z-Führung mit Knicken")

func test_cluster_rect_covers_all_cells():
	# Der Neon-Rahmen (cluster_rect) muss jede Zelle umschließen.
	assert_gt(screen.cluster_rect.size.x, 0.0)
	for key: String in screen.combo_cells:
		var cell: ComboCellView = screen.combo_cells[key]
		assert_true(screen.cluster_rect.encloses(Rect2(cell.position, cell.size)),
			"Zelle '%s' liegt außerhalb des Cluster-Rahmens" % key)

# --- Liefer-Routen (Kauf/Inhalt fahren die Adern statt quer über den Filz) -------

func _place_workbench_corner() -> void:
	screen.place_hub(Vector2(2400, 2200), Vector2(1400, 1200))
	screen.place_workshop_window(Rect2(Vector2(3300, 2000), Vector2(900, 500)))
	var rects: Array[Rect2] = []
	for i in Engraving.CATEGORIES.size():
		rects.append(Rect2(Vector2(3300 + i * 300, 2600), Vector2(280, 200)))
	screen.place_supply_drawers(rects, 8.0)

func test_pack_delivery_runs_along_the_hub_workshop_strip():
	_place_workbench_corner()
	var route := screen._route_via_strip(Vector2(2000, 2400),
		screen.workshop_hub_strip, Vector2(3750, 2250))
	assert_gt(route.size(), 2, "Route mit L-Anschlüssen, keine Luftlinie")
	for point in screen.workshop_hub_strip.strip_path:
		assert_true(route.has(point), "die Ader selbst liegt in der Route")

func test_every_route_leg_is_axis_parallel():
	# Leiterbahn-Look: keine Diagonalen, sonst sieht der Komet aus wie ein Flug.
	_place_workbench_corner()
	var route := screen._route_via_strip(Vector2(2000, 2400),
		screen.workshop_hub_strip, Vector2(3750, 2250))
	for i in route.size() - 1:
		var leg: Vector2 = route[i + 1] - route[i]
		assert_true(is_zero_approx(leg.x) or is_zero_approx(leg.y),
			"Abschnitt %d läuft achsenparallel" % i)

func test_route_starts_at_the_source_and_ends_at_the_target():
	_place_workbench_corner()
	var from := Vector2(2000, 2400)
	var to := Vector2(3750, 2250)
	var route := screen._route_via_strip(from, screen.workshop_hub_strip, to)
	assert_eq(route[0], from)
	assert_eq(route[route.size() - 1], to)

func test_route_without_a_strip_falls_back_to_a_straight_line():
	var route := screen._route_via_strip(Vector2(100, 100), null, Vector2(400, 400))
	assert_eq(route.size(), 2, "ohne verlegte Ader bleibt die direkte Verbindung")

func test_meteor_gets_a_real_travel_time():
	_place_workbench_corner()
	# Ohne sichtbare Werkstatt gäbe es keine Laufzeit - hier ist sie gesetzt.
	var travel := screen.meteor_comet(Vector2(3400, 2000), Engraving.CATEGORY_MATERIAL,
		Vector2(3900, 2700), Color.WHITE, 0)
	assert_gt(travel, 0.0, "der Meteor bekommt eine echte Flugzeit")

func test_meteor_flies_from_the_seal_into_its_slot():
	_place_workbench_corner()
	var from := Vector2(3400, 2000)
	var slot := Vector2(3900, 2700)
	var route := screen.meteor_route(from, Engraving.CATEGORY_MATERIAL, slot, 0)
	assert_eq(route[0], from, "der Meteor startet am Siegel")
	assert_eq(route[route.size() - 1], slot, "und endet genau im Platz")

func test_meteor_is_caught_by_the_strip_of_its_category():
	_place_workbench_corner()
	var strip: LedStripView = screen._supply_strip(Engraving.CATEGORY_MATERIAL)
	var route := screen.meteor_route(Vector2(3400, 2000), Engraving.CATEGORY_MATERIAL,
		Vector2(3900, 2700), 0)
	var caught := false
	for p in route:
		if p.is_equal_approx(strip.strip_path[0]):
			caught = true
	assert_true(caught, "die Ader der Kategorie fängt ihn an der Werkbank-Unterkante auf")

# --- Automaten-Ader (Einsatz hin, Gewinn zurück) --------------------------------

## Automaten links, Hub rechts daneben - dieselbe Höhen-Überlappung wie am Tisch.
## place_hub nimmt die MITTE, die linke Hub-Kante liegt also bei 3400-700 = 2700.
func _place_slot_corner() -> void:
	screen.place_hub(Vector2(3400, 2600), Vector2(1400, 1200))
	screen.place_slot_bank_window(Rect2(Vector2(1500, 2100), Vector2(1000, 1100)))
	screen.set_slot_bank_installed(true)

func test_the_slot_strip_runs_through_the_gap_to_the_hub():
	_place_slot_corner()
	var path := screen.slot_hub_strip.strip_path
	assert_gt(path.size(), 1, "eine verlegte Ader")
	assert_eq(path[0].x, 2500.0, "sie beginnt an der rechten Automaten-Kante")
	assert_eq(path[path.size() - 1].x, screen.hub.position.x, "und endet an der linken Hub-Kante")
	for point in path:
		assert_eq(point.y, path[0].y, "gerade waagerecht durch die Lücke")

func test_the_stake_travels_from_the_hub_to_the_machines():
	_place_slot_corner()
	# Verlegt ist die Ader Automat -> Hub; der Einsatz muss GEGEN diese Richtung
	# fahren, sonst käme die Münze aus dem Automaten heraus.
	assert_gt(screen.slot_pay_comet(Color.WHITE), 0.0, "der Einsatz bekommt eine Laufzeit")
	assert_gt(screen.slot_pay_travel_time(), 0.0, "und die Wartezeit ist planbar")

func test_a_won_charm_rides_the_strip_up_into_the_hub():
	_place_slot_corner()
	var from := Vector2(2000, 2600)
	var route := screen._route_via_strip(from, screen.slot_hub_strip,
		screen.hub.position + screen.hub.size * 0.5)
	assert_eq(route[0], from, "der Charm startet am Token im Fenster")
	for point in screen.slot_hub_strip.strip_path:
		assert_true(route.has(point), "er fährt die Automaten-Ader")

func test_a_won_die_flies_a_free_arc_to_the_tray():
	# Zu den 3D-Ablagen führt keine Ader - der letzte Teil ist ein Bogen.
	var from := Vector2(2000, 2600)
	var to := Vector2(3800, 1500)
	assert_gt(screen.tray_comet(from, to, Color.WHITE, 0), 0.0, "auch der Bogen hat eine Flugzeit")
	var first := screen._meteor_launch(from, to, 0)
	var second := screen._meteor_launch(from, to, 1)
	assert_eq(first[0], from, "er startet am Token")
	assert_true(first[first.size() - 1].is_equal_approx(to), "und landet auf dem Platz")
	assert_gt(first[6].distance_to(second[6]), 1.0, "zwei Würfel fliegen nicht dieselbe Bahn")

# --- Gewonnene Gravur: den ganzen Weg über die Adern ----------------------------

func _place_slots_hub_and_bench() -> void:
	_place_workbench_corner()   # Hub + Werkstatt + Schubladen
	screen.place_slot_bank_window(Rect2(Vector2(300, 2000), Vector2(1000, 1100)))
	screen.set_slot_bank_installed(true)

func test_a_won_engraving_rides_every_vein_to_its_drawer():
	# Der Automat liegt LINKS, die Schublade RECHTS vom Hub: das Licht darf nicht
	# quer über den Tisch fliegen, sondern fährt Automaten-, Werkstatt- und
	# Schubladen-Ader hintereinander ab.
	_place_slots_hub_and_bench()
	var from := Vector2(800, 2400)
	var slot := Vector2(3900, 2700)
	var route := screen.slot_engraving_route(from, Engraving.CATEGORY_MATERIAL, slot)
	assert_eq(route[0], from, "sie startet am Token im Automaten")
	assert_eq(route[route.size() - 1], slot, "und endet genau im Platz")
	for strip in [screen.slot_hub_strip, screen.workshop_hub_strip,
			screen._supply_strip(Engraving.CATEGORY_MATERIAL)]:
		for point in strip.strip_path:
			assert_true(route.has(point), "die Ader %s liegt in der Route" % strip.name)

func test_the_long_way_stays_axis_parallel():
	# Kein Diagonalflug über den Hub - Leiterbahn-Look über die ganze Strecke.
	_place_slots_hub_and_bench()
	var route := screen.slot_engraving_route(Vector2(800, 2400),
		Engraving.CATEGORY_MATERIAL, Vector2(3900, 2700))
	for i in route.size() - 1:
		var leg: Vector2 = route[i + 1] - route[i]
		assert_true(is_zero_approx(leg.x) or is_zero_approx(leg.y),
			"Abschnitt %d läuft achsenparallel" % i)

func test_passing_light_hugs_the_frame_instead_of_crossing_the_screen():
	# Fremde Bildschirme werden am RAHMEN passiert, nie mittendurch: kein
	# Streckenabschnitt darf im Inneren von Hub oder Werkstatt liegen.
	_place_slots_hub_and_bench()
	var route := screen.slot_engraving_route(Vector2(800, 2400),
		Engraving.CATEGORY_MATERIAL, Vector2(3900, 2700))
	var hub_inner := Rect2(screen.hub.position, screen.hub.size).grow(-2.0)
	var bench_inner := Rect2(screen.workshop_window.position,
		screen.workshop_window.size).grow(-2.0)
	for i in route.size() - 1:
		var mid: Vector2 = (route[i] + route[i + 1]) * 0.5
		assert_false(hub_inner.has_point(mid), "Abschnitt %d quert das Hub-Innere" % i)
		assert_false(bench_inner.has_point(mid), "Abschnitt %d quert die Werkstatt" % i)

func test_the_frame_walk_takes_the_shorter_side():
	# Ein- und Ausstieg liegen in der unteren Hub-Hälfte: der Umweg führt über die
	# UNTEREN Ecken, nicht einmal oben herum.
	_place_slots_hub_and_bench()
	var route := screen.slot_engraving_route(Vector2(800, 2400),
		Engraving.CATEGORY_MATERIAL, Vector2(3900, 2700))
	var hub_rect := Rect2(screen.hub.position, screen.hub.size)
	assert_true(route.has(Vector2(hub_rect.position.x, hub_rect.end.y)),
		"über die linke untere Ecke")
	assert_true(route.has(hub_rect.end), "und die rechte untere Ecke")
	assert_false(route.has(hub_rect.position), "aber nicht oben herum")

func test_without_machines_no_strip_is_lit():
	screen.place_hub(Vector2(3400, 2600), Vector2(1400, 1200))
	screen.place_slot_bank_window(Rect2(Vector2(1500, 2100), Vector2(1000, 1100)))
	assert_false(screen.slot_hub_strip.visible, "ohne freigeschaltete Automaten keine Ader")

func test_two_meteors_fling_in_different_directions():
	_place_workbench_corner()
	var from := Vector2(3400, 2000)
	var slot := Vector2(3900, 2700)
	var first := screen.meteor_route(from, Engraving.CATEGORY_MATERIAL, slot, 0)
	var second := screen.meteor_route(from, Engraving.CATEGORY_MATERIAL, slot, 1)
	# Gleicher Start, gleiches Ziel - aber der Ausbruch muss sichtbar auseinander
	# laufen, sonst wirken mehrere Stücke wie ein einziger Strahl.
	assert_gt(first[6].distance_to(second[6]), 1.0, "die Bahnen brechen verschieden aus")
