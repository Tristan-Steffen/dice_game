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

# --- Die Anzeigefläche ist ihr Rechteck ----------------------------------------
# Das Tisch-GLB brachte eine ovale Platte mit; ihre Rundungen schnitten alles an,
# was in einer Ecke lag, obwohl die UI dort längst gezeichnet war. attach_to legt
# darum den eigenen Hüllquader der Platte als Fläche auf - die Abbildung hängt
# ohnehin am Quader, es kommen nur die Ecken dazu.

func test_attach_lays_a_rectangular_surface_over_the_mesh() -> void:
	var plane := mesh.mesh as PlaneMesh
	assert_not_null(plane, "die Anzeige ist eine ebene Fläche, kein Möbelstück")
	assert_almost_eq(plane.size.x, 31.2, 0.01, "so breit wie der Hüllquader")
	assert_almost_eq(plane.size.y, 21.2, 0.01, "und so tief")

func test_a_round_platter_becomes_its_own_bounding_rect() -> void:
	# Die Probe aufs Exempel: eine runde Platte trägt danach bis in die Ecken.
	var round_mesh := MeshInstance3D.new()
	round_mesh.mesh = SphereMesh.new()  # in der Draufsicht ein Kreis
	add_child_autofree(round_mesh)
	var round_screen := TableScreen.new()
	add_child_autofree(round_screen)
	var before := round_mesh.get_aabb()
	round_screen.attach_to(round_mesh)
	var plane := round_mesh.mesh as PlaneMesh
	assert_not_null(plane, "auch die Kugel wird zur Fläche")
	assert_almost_eq(plane.size.x, before.size.x, 0.01)
	assert_almost_eq(plane.size.y, before.size.z, 0.01)

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

func test_pit_info_bar_fuellt_und_leert_das_wuerfelnetz():
	# Das ständige Netz-Feld: set_pit_die baut das Würfelnetz (ohne Neubau bei
	# gleichem Würfel), clear_pit_die leert es - die Sichtbarkeit des Felds
	# selbst steuert scene_root zusammen mit den Aktions-Knöpfen.
	screen.place_pit_info_bar(Rect2(Vector2(200, 800), Vector2(900, 180)))
	assert_eq(screen.pit_info_bar.position, Vector2(200, 800))
	assert_eq(screen.pit_net_holder.get_child_count(), 0, "startet leer")
	var def := DieDefinition.new()
	screen.set_pit_die(def, 3)
	assert_eq(screen.pit_net_holder.get_child_count(), 1, "Netz gebaut")
	# Gleicher Würfel + Lage: kein Neubau (der Hover ruft jeden Frame).
	screen.set_pit_die(def, 3)
	assert_eq(screen.pit_net_holder.get_child_count(), 1, "kein Doppel-Netz")
	screen.clear_pit_die()
	await wait_frames(2)  # queue_free räumt erst im nächsten Frame
	assert_eq(screen.pit_net_holder.get_child_count(), 0, "clear_pit_die leert")

func test_pit_actions_flankieren_das_wuerfelnetz():
	# Nehmen dockt links ans Netz-Feld, Würfeln rechts (feste Knopfhöhe, bündig
	# mit der Feld-Unterkante), "Beenden" links neben "Nehmen"; die
	# Maus-Weiterleitung (pit_actions_hit) trifft NUR die sichtbaren Knöpfe.
	var bar := Rect2(Vector2(600, 700), Vector2(400, 300))
	screen.place_pit_window(Rect2(Vector2(200, 400), Vector2(1200, 700)), 40.0)
	screen.place_pit_actions(bar)
	var gap := TableScreen.PIT_ACTION_GAP
	var size := TableScreen.PIT_ACTION_SIZE
	var take_pos := screen.pit_actions_root.position + screen.take_action_button.position
	assert_eq(take_pos, Vector2(600 - gap - size.x, 1000 - size.y),
		"Nehmen an der linken unteren Feldecke")
	assert_eq(screen.take_action_button.custom_minimum_size, size, "Nehmen in fester Knopfgröße")
	var take_rect := Rect2(take_pos, screen.take_action_button.size)
	var roll_pos := screen.pit_actions_root.position + screen.roll_action_button.position
	assert_eq(roll_pos, Vector2(1000 + gap, 1000 - size.y), "Würfeln an der rechten unteren Feldecke")
	var roll_rect := Rect2(roll_pos, screen.roll_action_button.size)
	# "Beenden" hängt mit der RECHTEN Kante an "Nehmen" - es wächst mit seiner
	# Zahl nach links zur Grubenwand, nie in den Nachbarn hinein.
	var bank_pos := screen.pit_actions_root.position + screen.bank_action_button.position
	var bank_rect := Rect2(bank_pos, screen.bank_action_button.size)
	assert_eq(bank_pos.y, take_pos.y, "Beenden steht in der Reihe von Nehmen")
	assert_eq(bank_rect.end.x, take_pos.x - gap, "Beenden dockt links an Nehmen")
	screen.set_bank_label("Beenden ⚡×12")
	var grown := Rect2(screen.pit_actions_root.position + screen.bank_action_button.position,
		screen.bank_action_button.size)
	assert_gt(grown.size.x, bank_rect.size.x, "der längere Text macht den Knopf breiter")
	assert_eq(grown.end.x, take_pos.x - gap, "und er wächst nach links, nicht über Nehmen")
	# Der Rückblick steht in der oberen rechten Grubenecke.
	var log_pos := screen.pit_actions_root.position + screen.log_action_button.position
	var margin := TableScreen.PIT_WALL_MARGIN
	assert_eq(log_pos, Vector2(200 + 1200 - margin - size.x, 400 + margin), "Rückblick oben rechts")
	assert_true(screen.pit_actions_hit(take_rect.get_center()))
	assert_true(screen.pit_actions_hit(roll_rect.get_center()))
	assert_false(screen.pit_actions_hit(bar.get_center()), "Feld-Mitte gehört dem Netz, nicht den Knöpfen")
	assert_false(screen.pit_actions_hit(grown.get_center()), "Bank unsichtbar -> kein Treffer")
	screen.bank_action_button.visible = true
	assert_true(screen.pit_actions_hit(grown.get_center()))

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

func test_fumble_flashes_the_red_word_and_a_table_wide_wave():
	# Ein echter Farkle quittiert: rotes Neon-"FUMBLE" quer über die Grube und
	# EINE Stoßwelle aus der Grubenmitte, die bis über die entfernteste
	# Bildschirm-Ecke hinauswächst (passiert also jedes Fenster).
	screen.place_pit_window(Rect2(Vector2(100, 200), Vector2(800, 400)), 75.0)
	screen.pit_fumble()
	var word: Label = null
	for child in screen.pit_window.get_children():
		if child is Label and child.text == TableScreen.FUMBLE_WORD:
			word = child
	assert_not_null(word, "das rote Neon-Wort steht über der Grube")
	var material: ShaderMaterial = screen.fumble_wave.material
	assert_eq(material.get_shader_parameter("center"), Vector2(500, 400), "Welle aus der Grubenmitte")
	var far_corner := Vector2(500, 400).distance_to(Vector2(screen.size))
	assert_gt(float(material.get_shader_parameter("max_radius")), far_corner,
		"der Ring wächst über die entfernteste Ecke hinaus")
	# Nur auf den Fenstern sichtbar: die Welle trägt dieselbe Maske wie das Glas.
	assert_gt(int(material.get_shader_parameter("window_count")), 0,
		"die Fenster-Maske ist gespeist")
	await wait_seconds(TableScreen.FUMBLE_WAVE_TIME * 0.4)
	assert_between(float(material.get_shader_parameter("progress")), 0.001, 0.999,
		"mitten im Lauf ist die Welle unterwegs")
	await wait_seconds(TableScreen.FUMBLE_WAVE_TIME)
	assert_almost_eq(float(material.get_shader_parameter("progress")), 1.0, 0.001,
		"ausgelaufen: das Overlay ist wieder still")

## Die Umrisse der verworfenen Würfel (Fumble-Nachglühen).
func _fumble_marks() -> Array:
	if screen._fumble_marks == null or not is_instance_valid(screen._fumble_marks):
		return []
	return screen._fumble_marks.get_children()

func test_the_fumble_leaves_an_outline_per_discarded_die():
	# Beim Fumble fliegen die Würfel zu schnell weg: an ihrer Stelle bleibt ein
	# Umriss mit der Augenzahl stehen, die oben lag.
	screen.place_pit_window(Rect2(Vector2(100, 200), Vector2(800, 400)), 75.0)
	var marks: Array[Dictionary] = [
		{"pixel": Vector2(300, 350), "value": 5, "fresh": true},
		{"pixel": Vector2(500, 400), "value": 2, "fresh": false},
	]
	screen.show_fumble_marks(marks, 40.0)
	var built := _fumble_marks()
	assert_eq(built.size(), 2, "je verworfenem Würfel ein Umriss")
	var first: Panel = built[0]
	assert_eq(first.position, Vector2(280, 330), "auf der Stelle des Würfels zentriert")
	assert_eq(first.size, Vector2(40, 40))
	var box: StyleBoxFlat = first.get_theme_stylebox("panel")
	assert_eq(box.bg_color.a, 0.0, "eine Silhouette, kein gefülltes Fenster")
	assert_eq(box.border_color, TableScreen.FUMBLE_COLOR, "der frische Wurf im Fumble-Rot")
	var label: Label = first.get_child(0)
	assert_eq(label.text, "5", "die Augenzahl, die oben lag")
	var calm: Panel = built[1]
	var calm_box: StyleBoxFlat = calm.get_theme_stylebox("panel")
	assert_eq(calm_box.border_color, TableScreen.FUMBLE_MARK_CALM,
		"der schon liegende Würfel steht blass daneben")

func test_the_fumble_outlines_go_with_the_rest_of_the_pit():
	screen.place_pit_window(Rect2(Vector2(100, 200), Vector2(800, 400)), 75.0)
	var marks: Array[Dictionary] = [{"pixel": Vector2(300, 350), "value": 5, "fresh": true}]
	screen.show_fumble_marks(marks, 40.0)
	screen.clear_fumble_marks()
	assert_eq(_fumble_marks().size(), 0, "die Kamera verlässt die Grube, das Nachglühen geht mit")

func test_pit_info_bar_shares_the_one_window_look():
	var info_style: StyleBoxFlat = screen.pit_info_bar.get_theme_stylebox("panel")
	assert_eq(info_style.border_color, screen.window_style().border_color)

func test_pit_window_shares_the_one_window_look():
	# Alle Tisch-"Fenster" tragen denselben Stil (window_style): das Gruben-
	# Fenster muss in Grund- und Rahmenfarbe der gemeinsamen Vorlage gleichen.
	var pit_style: StyleBoxFlat = screen.pit_window.get_theme_stylebox("panel")
	var shared := screen.window_style()
	assert_eq(pit_style.bg_color, shared.bg_color)
	assert_eq(pit_style.border_color, shared.border_color)
	assert_eq(pit_style.border_width_top, shared.border_width_top)

func test_glass_gets_the_window_rects_for_reflection_masking():
	# NUR die Fenster spiegeln (der Filz dazwischen nicht): das Glas-Material
	# muss die Fenster-Rechtecke kennen (siehe _sync_reflection_windows) -
	# nach attach_to mindestens der Zielbalken, mit dem Gruben-Fenster eines mehr.
	var material := mesh.material_override as ShaderMaterial
	var before: int = material.get_shader_parameter("window_count")
	assert_gt(before, 0, "der Zielbalken ist schon gemeldet")
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

# --- Chip-Adernetz & Kauf-Lichtlauf ---------------------------------------------

func test_wiring_paths_converge_on_pins():
	# Mittelspalte hängt an ZWEI Schienen: vier Zulauf-Pfade, gleiche Zielhöhe,
	# Enden an der linken bzw. rechten Pin-Spitze - gleiche Laufzeit, gleiche Ankunft.
	var paths := screen.wiring_paths_to_cell(1)
	assert_eq(paths.size(), 4, "vier Zulauf-Pfade")
	var target_y: float = paths[0][paths[0].size() - 1].y
	for path in paths:
		assert_eq(path[path.size() - 1].y, target_y, "alle enden auf derselben Höhe")
	assert_eq(paths[0][paths[0].size() - 1].x, paths[1][paths[1].size() - 1].x, "links: gleiche Pin-Spitze")
	assert_eq(paths[2][paths[2].size() - 1].x, paths[3][paths[3].size() - 1].x, "rechts: gleiche Pin-Spitze")

func test_wiring_paths_use_only_existing_buses():
	# Randspalten haben nur EINE Nachbarschiene - es darf kein Komet über eine
	# Schiene laufen, die gar nicht liegt.
	var paths := screen.wiring_paths_to_cell(0)
	assert_eq(paths.size(), 2, "Randspalte: zwei Zulauf-Pfade")
	var buses := screen.combo_bus_xs()
	for path in paths:
		assert_true(buses.has(path[0].x), "Pfad startet auf einer verlegten Schiene")

func test_wiring_paths_start_at_the_bus_ends():
	for path in screen.wiring_paths_to_cell(3):
		var start_y: float = path[0].y
		assert_true(is_equal_approx(start_y, screen.cluster_rect.position.y)
				or is_equal_approx(start_y, screen.cluster_rect.end.y),
			"Pfad startet an einem Ende der Sammelschiene")

func test_wiring_keeps_only_the_shared_buses():
	# Drei Spalten -> zwei geteilte Lücken; die äußeren Schienen entfallen.
	assert_eq(screen.combo_bus_xs().size(), 2, "nur die inneren Sammelschienen")

func test_wiring_gives_every_chip_exactly_one_stub_per_bus():
	# Sparsam verdrahtet: ein Stich je Nachbarschiene (nicht je Pin-Höhe), dazu
	# die zwei Senkrechten und EINE Quer-Schiene unten.
	var stubs := 0
	for key: String in screen.combo_cells:
		var cell: ComboCellView = screen.combo_cells[key]
		var buses := screen.combo_bus_xs()
		var stub := TableScreen.CELL_GAP.x * 0.5
		for bus: float in buses:
			if is_equal_approx(bus, cell.position.x - stub) \
					or is_equal_approx(bus, cell.position.x + cell.size.x + stub):
				stubs += 1
	assert_gt(stubs, 0, "jeder Chip hängt an mindestens einer Schiene")
	assert_eq(screen.combo_wiring.rail_paths.size(), stubs + 3,
		"Stiche + zwei Senkrechte + eine Quer-Schiene")

func test_link_hub_to_cluster_builds_led_strip():
	screen.place_hub(Vector2(3400, 2200), Vector2(1500, 1500))
	screen.link_hub_to_cluster()
	assert_gt(screen.led_strip.strip_path.size(), 2, "eine Ader in Z-Führung mit Knicken")

func test_hub_and_score_adern_meet_opposite_net_corners():
	# Die Hub-Ader endet in der Ecke unten rechts, die Score-Ader startet oben
	# links - beide auf einem Knoten des Chip-Netzes, nie auf freier Strecke.
	screen.place_hub(Vector2(3400, 2200), Vector2(1500, 1500))
	screen.place_score_screen()  # ohne Wertungs-Rahmen legt link_score_strips nichts
	screen.link_hub_to_cluster()
	screen.link_score_strips()
	var buses := screen.combo_bus_xs()
	var hub_end: Vector2 = screen.led_strip.strip_path[screen.led_strip.strip_path.size() - 1]
	assert_almost_eq(hub_end.x, buses[buses.size() - 1], 0.5, "Hub trifft die rechte Schiene")
	assert_almost_eq(hub_end.y, screen.cluster_rect.end.y, 0.5, "auf Höhe der Quer-Schiene")
	var score_start: Vector2 = screen.combos_score_strip.strip_path[0]
	assert_almost_eq(score_start.x, buses[0], 0.5, "Score startet an der linken Schiene")
	assert_almost_eq(score_start.y, screen.cluster_rect.position.y, 0.5, "an deren oberem Ende")

func test_cluster_rect_covers_all_cells():
	# cluster_rect ist die Hülle des Chip-Felds (Zoomziel, Spill-Licht,
	# Schienenlänge) - sie muss jede Zelle umschließen.
	assert_gt(screen.cluster_rect.size.x, 0.0)
	for key: String in screen.combo_cells:
		var cell: ComboCellView = screen.combo_cells[key]
		assert_true(screen.cluster_rect.encloses(Rect2(cell.position, cell.size)),
			"Zelle '%s' liegt außerhalb des Cluster-Rahmens" % key)

# --- Liefer-Routen (Kauf/Inhalt fahren die Adern statt quer über den Filz) -------

func _place_workbench_corner() -> void:
	screen.place_hub(Vector2(2400, 2200), Vector2(1400, 1200))
	screen.place_workshop_window(Rect2(Vector2(3300, 2000), Vector2(900, 500)))

# --- Das Ausgabefach rechts der Werkbank ----------------------------------------

func test_the_out_tray_stands_right_of_the_bench_with_a_seam() -> void:
	_place_workbench_corner()
	var bench := Rect2(screen.workshop_window.position, screen.workshop_window.size)
	var fach := screen.ausgabefach_rect()
	assert_gt(fach.size.x, 0.0, "sie steht")
	assert_gt(fach.position.x, bench.end.x, "rechts NEBEN dem Fenster, nicht darauf")
	var u := bench.size.x / 100.0
	assert_almost_eq(fach.position.x - bench.end.x, u * TableScreen.FACH_GAP_UNITS, 0.01,
		"die Naht ist ein Maß des Fensters, kein geratener Abstand")
	assert_almost_eq(fach.position.y, bench.position.y, 0.01, "oben bündig mit ihm")
	assert_lt(fach.size.y, bench.size.y, "und niedriger als das Fenster selbst")

func test_the_out_tray_keeps_clear_of_the_hub_workshop_lane() -> void:
	# Licht und Fracht fahren die Ader zwischen Hub und Bank - dort darf keine
	# Schale stehen. Sie liegt LINKS des Fensters, die Schale rechts davon.
	_place_workbench_corner()
	var fach := screen.ausgabefach_rect()
	for point in screen.workshop_hub_strip.strip_path:
		assert_false(fach.has_point(point), "die Ader läuft an der Schale vorbei")
	assert_gt(fach.position.x, screen.workshop_hub_strip.strip_path[1].x,
		"und zwar auf der anderen Seite des Fensters")

func test_the_out_tray_grows_with_the_bench() -> void:
	_place_workbench_corner()
	var narrow := screen.ausgabefach_rect()
	screen.place_workshop_window(Rect2(Vector2(3300, 2000), Vector2(1800, 500)))
	var wide := screen.ausgabefach_rect()
	assert_gt(wide.size.x, narrow.size.x, "eine breitere Bank trägt eine größere Schale")
	assert_almost_eq(wide.size.x / wide.size.y, narrow.size.x / narrow.size.y, 0.001,
		"in denselben Verhältnissen")

func test_without_a_bench_there_is_no_out_tray() -> void:
	assert_eq(screen.ausgabefach_rect(), Rect2(), "kein Fenster, keine Schale")

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
	var travel := screen.meteor_comet(Vector2(3400, 2000), Vector2(3900, 2400), Color.WHITE, 0)
	assert_gt(travel, 0.0, "der Meteor bekommt eine echte Flugzeit")

func test_meteor_flies_from_the_seal_into_its_slot():
	_place_workbench_corner()
	var from := Vector2(3400, 2000)
	var slot := Vector2(3900, 2400)
	var route := screen.meteor_route(from, slot, 0)
	assert_eq(route[0], from, "der Meteor startet am Siegel")
	assert_eq(route[route.size() - 1], slot, "und endet genau im Chip")

func test_meteor_swings_out_instead_of_flying_straight():
	# Start und Ziel liegen BEIDE im Werkstatt-Fenster - da ist keine Ader zu
	# fahren, nur der Bogen aus dem zerbrochenen Siegel.
	_place_workbench_corner()
	var from := Vector2(3400, 2100)
	var slot := Vector2(3900, 2400)
	var route := screen.meteor_route(from, slot, 0)
	assert_gt(route.size(), 2, "der Wurf ist eine Kurve, keine Luftlinie")
	var straight := from.lerp(slot, 0.5)
	assert_gt(route[route.size() / 2].distance_to(straight), 1.0, "und weicht sichtbar aus")

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

# --- Schwarzmarkt-Ader (Ladung fährt zum Hinterzimmer) --------------------------

## Der Laden ist der Zwilling der Automaten eine Etage tiefer: rechte Kante wie
## der Automat, Unterkante bündig mit dem Hub (der spannt 2000..3200).
func _place_secret_corner() -> void:
	screen.place_hub(Vector2(3400, 2600), Vector2(1400, 1200))
	screen.place_slot_bank_window(Rect2(Vector2(1500, 2000), Vector2(1000, 850)))
	screen.set_slot_bank_installed(true)
	screen.place_secret_shop_window(Rect2(Vector2(1500, 2900), Vector2(1000, 300)))
	screen.set_secret_shop_installed(true)

func test_the_secret_shop_strip_runs_through_the_gap_to_the_hub():
	_place_secret_corner()
	var path := screen.secret_hub_strip.strip_path
	assert_gt(path.size(), 1, "eine verlegte Ader")
	assert_eq(path[0].x, 2500.0, "sie beginnt an der rechten Laden-Kante")
	assert_eq(path[path.size() - 1].x, screen.hub.position.x, "und endet an der linken Hub-Kante")
	for point in path:
		assert_eq(point.y, path[0].y, "gerade waagerecht durch die Lücke")
	assert_between(path[0].y, 2900.0, 3200.0, "im Höhen-Überlapp von Laden und Hub")

func test_the_charge_travels_from_the_hub_to_the_secret_shop():
	_place_secret_corner()
	# Verlegt ist die Ader Laden -> Hub; die Zahlung fährt dagegen (wie der
	# Automaten-Einsatz), sonst käme die Ladung aus dem Laden heraus.
	assert_gt(screen.secret_shop_pay_comet(CasinoStyle.CHARGE), 0.0,
		"Eintrittsgeld, Kauf und Neuwurf bekommen eine Laufzeit")

func test_without_a_placed_secret_shop_no_charge_comet_flies():
	assert_eq(screen.secret_shop_pay_comet(CasinoStyle.CHARGE), 0.0, "ohne Ader kein Komet")

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

# --- Automaten ohne Freischaltung ----------------------------------------------

func test_without_machines_no_strip_is_lit():
	screen.place_hub(Vector2(3400, 2600), Vector2(1400, 1200))
	screen.place_slot_bank_window(Rect2(Vector2(1500, 2100), Vector2(1000, 1100)))
	assert_false(screen.slot_hub_strip.visible, "ohne freigeschaltete Automaten keine Ader")

func test_two_meteors_fling_in_different_directions():
	_place_workbench_corner()
	var from := Vector2(3400, 2000)
	var slot := Vector2(3900, 2400)
	var first := screen.meteor_route(from, slot, 0)
	var second := screen.meteor_route(from, slot, 1)
	# Gleicher Start, gleiches Ziel - aber der Ausbruch muss sichtbar auseinander
	# laufen, sonst wirken mehrere Stücke wie ein einziger Strahl.
	assert_gt(first[6].distance_to(second[6]), 1.0, "die Bahnen brechen verschieden aus")

# --- Deal-Marken am Grubenrand ------------------------------------------------

func _sides(entries: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	typed.assign(entries)
	return typed

## Wie GameRun.active_deal_sides: Bonus/Malus steckt in der Klausel selbst.
func _side(clause_id: String) -> Dictionary:
	var clause := DealClause.find(clause_id)
	return {"id": clause_id, "bonus": clause.kind == DealClause.Kind.BONUS,
		"scope": clause.scope}

func _place_pit_with_rail() -> Rect2:
	screen.place_pit_window(Rect2(Vector2(1800, 1300), Vector2(1100, 600)), 60.0)
	var rail := Rect2(Vector2(1900, 1340), Vector2(700, 70))
	screen.place_pit_deal_rail(rail)
	screen.pit_deal_rail.visible = true  # in der Grubensicht schaltet scene_root ihn ein
	return rail

func test_the_pit_rail_centers_its_tokens_in_the_strip():
	var rail := _place_pit_with_rail()
	screen.set_pit_deal_tokens(_sides([
		_side(DealClause.SAVINGS_BONUS), _side(DealClause.EMPTIES)]))
	await wait_frames(2)
	var row := Rect2(screen.pit_deal_rail.position, screen.pit_deal_rail.size)
	assert_eq(row.get_center().x, rail.get_center().x, "mittig über der Grubenachse")
	assert_almost_eq(row.get_center().y, rail.get_center().y, 1.0)
	assert_lte(row.size.y, rail.size.y, "die Marken bleiben im Streifen")

func test_tokens_set_before_the_rail_is_placed_survive():
	# _refresh_hub_info läuft im Aufbau VOR der Grubenplatzierung - die Seiten
	# dürfen dabei nicht verlorengehen.
	screen.set_pit_deal_tokens(_sides([_side(DealClause.SAVINGS_BONUS)]))
	_place_pit_with_rail()
	assert_eq(screen.pit_deal_rail.get_child_count(), 1)

func test_the_pit_hint_explains_the_hovered_token():
	_place_pit_with_rail()
	screen.set_pit_deal_tokens(_sides([_side(DealClause.EMPTIES)]))
	await wait_frames(2)
	var token := screen.pit_deal_rail.get_child(0) as Control
	assert_false(screen.pit_deal_hint.visible, "ohne Zeiger kein Hinweis")
	screen.show_pit_deal_hint(screen.pit_deal_token_at(token.get_global_rect().get_center()))
	assert_true(screen.pit_deal_hint.visible)
	assert_eq(screen.pit_deal_hint.title_label.text, DealClause.empties().display_name)
	screen.hide_pit_deal_hint()
	assert_false(screen.pit_deal_hint.visible)

func test_the_pit_hint_stays_inside_the_pit():
	# Die Karte hängt im Grubenfenster: sie darf nicht über den Filz hinausragen.
	var rail := _place_pit_with_rail()
	screen.set_pit_deal_tokens(_sides([_side(DealClause.EMPTIES)]))
	await wait_frames(2)
	var token := screen.pit_deal_rail.get_child(0) as Control
	screen.show_pit_deal_hint(token)
	await wait_frames(2)
	var card := Rect2(screen.pit_deal_hint.position, screen.pit_deal_hint.size)
	assert_gte(card.position.x, 0.0)
	assert_gte(card.position.y, 0.0)
	assert_lte(card.end.x, screen.pit_window.size.x + 1.0)
	assert_lte(card.end.y, screen.pit_window.size.y + 1.0)
	assert_gt(card.position.y, rail.size.y * 0.5, "unter dem Streifen, nicht über ihm")

func test_the_pit_rail_sweeps_with_the_hub_tokens():
	_place_pit_with_rail()
	assert_eq(screen.sweep_pit_deal_tokens(), 0.0, "ohne Marken nichts zu wischen")
	screen.set_pit_deal_tokens(_sides([_side(DealClause.SAVINGS_BONUS)]))
	assert_gt(screen.sweep_pit_deal_tokens(), 0.0)

# --- Das Förderwerk (Ware unter dem Filz) --------------------------------------
# Licht fliegt über dem Filz, Ware fährt darunter: das Unterlicht hängt darum in
# einer eigenen Ebene, die VOR allen Fenstern gezeichnet wird - auf offenen
# Filzstrecken sichtbar, unter Fenstern ehrlich verdeckt.

func test_the_underlight_layer_lies_below_every_window():
	assert_not_null(screen.underlight_layer, "die Ebene steht ab dem Aufbau")
	for window: Control in [screen.hub, screen.workshop_window, screen.pit_window,
			screen.treasure_window, screen.slot_bank_window]:
		assert_lt(screen.underlight_layer.get_index(), window.get_index(),
			"%s liegt über dem Förderwerk" % window.name)

func test_an_underlight_runs_inside_that_layer_at_comet_speed():
	var path := PackedVector2Array([Vector2(100, 100), Vector2(100, 400)])
	var travel := screen.underlight_travel(path, Color.WHITE)
	assert_eq(screen.underlight_layer.get_child_count(), 1,
		"das Glimmen hängt unter den Fenstern, nicht an der Wurzel")
	# Gleiche Reisegeschwindigkeit wie die Kometen - sonst trüge die Routen-
	# Zeitrechnung nicht, auf der jede Ankunft steht.
	assert_almost_eq(travel, 300.0 / TableScreen.PULSE_SPEED, 0.0001)

func test_an_empty_route_carries_nothing():
	assert_eq(screen.underlight_travel(PackedVector2Array([Vector2.ZERO]), Color.WHITE), 0.0)
	assert_eq(screen.underlight_layer.get_child_count(), 0)

func test_the_freight_route_runs_from_hatch_to_pit_edge():
	# Ohne verlegte Ader bleibt die gerade Verbindung (headless) - Anfang und Ende
	# gehören aber IMMER dem Aufrufer: die Luke und die Grubenkante.
	var hatch := Vector2(220, 640)
	var edge := Vector2(980, 300)
	var route := screen.underlight_workshop_route(hatch, edge)
	assert_gte(route.size(), 2)
	assert_eq(route[0], hatch, "sie startet an der Luke")
	assert_eq(route[route.size() - 1], edge, "und endet an der Grubenkante")

func test_the_backroom_freight_runs_the_same_way():
	# Aus dem Hinterzimmer geht es über zwei Adern (Schwarzmarkt -> Hub ->
	# Werkbank); Anfang und Ende bleiben Luke und Grubenkante.
	var hatch := Vector2(140, 700)
	var edge := Vector2(980, 300)
	var route := screen.underlight_secret_route(hatch, edge)
	assert_gte(route.size(), 2)
	assert_eq(route[0], hatch)
	assert_eq(route[route.size() - 1], edge)

# --- Die zwei Vitrinen-Löcher ---------------------------------------------------
# Index 0 gehört dem Laden, Index 1 dem Schwarzmarkt. Beide sind Löcher mit
# Vorhang und kosten keinen MAX_WINDOWS-Platz.

func test_each_vitrine_keeps_its_own_hole():
	var shop := Rect2(100, 200, 300, 150)
	var market := Rect2(900, 800, 280, 190)
	screen.set_vitrine_hole(0, shop, 1.0)
	screen.set_vitrine_hole(1, market, 0.25)
	assert_eq(screen.vitrine_rects[0], shop, "der Laden behält sein Rechteck")
	assert_eq(screen.vitrine_rects[1], market, "und das Hinterzimmer seins")
	assert_almost_eq(screen.vitrine_open[0], 1.0, 0.0001)
	assert_almost_eq(screen.vitrine_open[1], 0.25, 0.0001)
	# Der Vorhang der einen Bucht rührt die andere nicht an.
	screen.set_vitrine_open(1, 1.0)
	assert_almost_eq(screen.vitrine_open[0], 1.0, 0.0001)
	assert_eq(screen.vitrine_rects[0], shop)

func test_a_third_hole_is_refused():
	screen.set_vitrine_hole(0, Rect2(10, 10, 20, 20), 1.0)
	screen.set_vitrine_hole(TableScreen.VITRINE_HOLES, Rect2(50, 50, 60, 60), 1.0)
	assert_eq(screen.vitrine_rects.size(), TableScreen.VITRINE_HOLES,
		"zwei Buchten, mehr kennt der Shader nicht")
