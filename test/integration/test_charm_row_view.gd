extends GutTest
## Tier-2-Tests der Charm-Reihe (CharmRowView): sechs LAUFWERKE in einer Reihe, je Charm
## eine Diskette im Schlitz und ein Hologramm über der Linse, der EINE Schreiber
## (set_charms) fährt Körper statt sie neu zu bauen.

var row: CharmRowView

func before_each() -> void:
	row = CharmRowView.new()
	add_child_autofree(row)

func _charms(n: int) -> Array[Charm]:
	var list: Array[Charm] = []
	for i in n:
		list.append(Charm.rabbits_foot())
	return list

# --- set_charms ---------------------------------------------------------------

func test_places_one_model_per_charm():
	row.set_charms(_charms(3))
	assert_eq(row.charm_nodes.size(), 3)

func test_caps_at_six_spots():
	row.set_charms(_charms(10))
	assert_eq(row.charm_nodes.size(), CharmRowView.SPOT_COUNT)

func test_empty_clears_the_row():
	row.set_charms(_charms(4))
	row.set_charms([])
	assert_eq(row.charm_nodes.size(), 0)

func test_rebuild_replaces_previous_models():
	row.set_charms(_charms(5))
	row.set_charms(_charms(2))
	assert_eq(row.charm_nodes.size(), 2, "alte Modelle werden ersetzt, nicht angehängt")

# --- Platz-Geometrie ----------------------------------------------------------

func test_six_readers_stand_in_a_straight_row():
	assert_eq(row.readers.size(), CharmRowView.SPOT_COUNT, "je Platz ein Laufwerk")
	for i in CharmRowView.SPOT_COUNT:
		assert_almost_eq(row.readers[i].position.x, CharmRowView.LINE_X, 0.001)
		assert_almost_eq(row.readers[i].position.y, CharmRowView.SPOT_Y, 0.001,
			"das Laufwerk steht auf dem Filz")

func test_readers_mirror_across_z_axis():
	assert_almost_eq(row.readers[0].position.z, -row.readers[5].position.z, 0.001)

func test_readers_evenly_spaced_in_z():
	for i in range(1, CharmRowView.SPOT_COUNT):
		assert_almost_eq(row.readers[i].position.z - row.readers[i - 1].position.z,
			CharmRowView.LINE_SPACING, 0.001)

func test_a_reader_fits_between_its_neighbours():
	assert_lt(CharmReaderView.SIZE.z, CharmRowView.LINE_SPACING, "Laufwerke berühren sich nie")

func test_hologram_hovers_over_the_lens():
	row.set_charms(_charms(2))
	for i in 2:
		var lens := row.spot_global_position(i)
		var holo := row.charm_nodes[i].global_position
		assert_almost_eq(holo.y, lens.y + CharmRowView.HOVER_HEIGHT, 0.001, "über der Linse")
		assert_almost_eq(holo.z, lens.z, 0.001)
		assert_gt(lens.y, CharmReaderView.SIZE.y, "die Linse sitzt auf dem Laufwerk")

func test_the_disk_sits_in_the_slot_and_its_text_stays_outside():
	row.set_charms(_charms(1))
	var disk: CharmDiskView = row.disks[0]
	var reader := row.readers[0]
	var local := reader.to_local(disk.global_position)
	assert_almost_eq(local.x, CharmReaderView.LOADED_X, 0.001, "mitten im Schlitz")
	# Was im Schlitz steckt, endet an der Front; der Text liegt ganz davor.
	var front := -CharmReaderView.SIZE.x * 0.5
	var inside := local.x + CharmDiskView.SIZE.x * 0.5 - front
	assert_almost_eq(inside, CharmDiskView.INSERT_DEPTH, 0.05, "nur Schieber und Bild stecken")
	var text_top := reader.to_local(disk.desc_label.global_position).x
	assert_lt(text_top, front, "die Wirkung liegt vor dem Schlitz")

func test_the_row_front_edge_is_the_disk_front():
	row.set_charms(_charms(1))
	var front := row.to_local(row.disks[0].global_position).x - CharmDiskView.SIZE.x * 0.5
	assert_almost_eq(front, CharmRowView.front_edge_x(), 0.001)

# --- Laufwerke ----------------------------------------------------------------

func test_occupied_readers_glow_and_empty_ones_stay_dark():
	row.set_charms(_charms(2))
	assert_ne(row.readers[0].glow_color(), CharmReaderView.DARK, "belegt leuchtet")
	assert_eq(row.readers[3].glow_color(), CharmReaderView.DARK, "leer bleibt dunkel")

func test_reader_glow_follows_rarity():
	var charms: Array[Charm] = [Charm.rabbits_foot(), Charm.broken_mirror(), Charm.lucky_cigarettes()]
	row.set_charms(charms)
	assert_ne(row.readers[0].glow_color(), row.readers[1].glow_color(),
		"Gewöhnlich und Legendär leuchten verschieden")
	assert_eq(row.readers[0].glow_color(), row.readers[2].glow_color(),
		"gleiche Rarität teilt ihre Farbe")

func test_reader_rests_below_the_bloom_threshold():
	row.set_charms(_charms(1))
	var rest := row.readers[0].glow_color()
	assert_lt(maxf(maxf(rest.r, rest.g), rest.b), 0.95, "Ruhe bleibt unter der Schwelle")

func test_flash_charm_lifts_the_reader_and_falls_back():
	row.set_charms(_charms(1))
	var rest := row.readers[0].glow_color()
	row.flash_charm(0)
	await wait_seconds(0.09)
	assert_gt(row.readers[0].glow_color().b, rest.b, "der Saum steigt")
	await wait_seconds(0.6)
	assert_almost_eq(row.readers[0].glow_color().b, rest.b, 0.02, "und fällt zurück")

func test_flash_charm_tolerates_invalid_index():
	row.set_charms(_charms(1))
	row.flash_charm(-1)
	row.flash_charm(5)  # außerhalb - darf nicht abstürzen
	assert_eq(row.charm_nodes.size(), 1)

func test_one_light_per_occupied_spot_sees_only_models():
	row.set_charms(_charms(2))
	assert_eq(row.spot_lights.size(), 2, "je Platz ein Strahler")
	assert_eq(row.spot_lights[0].light_cull_mask, CharmRowView.MODEL_LIGHT_LAYER,
		"der Filz sieht ihn nicht")

# --- Der EINE Schreiber -------------------------------------------------------

func test_reorder_keeps_the_bodies_and_moves_them():
	var charms := _charms(3)
	row.set_charms(charms)
	var disk: CharmDiskView = row.disks[0]
	var moved: Array[Charm] = [charms[1], charms[2], charms[0]]
	row.set_charms(moved)
	assert_eq(row.disks[2], disk, "dieselbe Diskette, nur ein anderer Platz")
	assert_true(disk.carrying(), "sie fährt im Trage-Bogen")
	row.settle_hard()
	assert_almost_eq(disk.global_position.distance_to(
		row.readers[2].disk_global_transform().origin), 0.0, 0.001, "hart steckt sie")

func test_an_incoming_disk_flies_in_and_its_reader_waits():
	var charm := Charm.rabbits_foot()
	var disk := CharmDiskView.new(charm)
	add_child_autofree(disk)
	disk.global_position = Vector3(0.0, 1.0, 0.0)
	var charms: Array[Charm] = [charm]
	row.set_charms(charms, {charm: disk})
	assert_eq(row.disks[0], disk, "die gekaufte Diskette wird die der Reihe")
	assert_true(row.arriving(), "bis zur Landung fliegt sie")
	assert_eq(row.readers[0].glow_color(), CharmReaderView.DARK, "das Laufwerk zeigt den Platz leer")
	assert_false(row.charm_nodes[0].visible, "kein Hologramm vor der Landung")
	row.settle_hard()
	assert_false(row.arriving())
	assert_ne(row.readers[0].glow_color(), CharmReaderView.DARK, "danach leuchtet es")
	assert_true(row.charm_nodes[0].visible)

func test_release_disk_hands_the_body_over():
	row.set_charms(_charms(2))
	var disk := row.release_disk(0)
	assert_not_null(disk)
	assert_null(disk.get_parent(), "die Reihe gibt ihn frei")
	disk.free()

func test_drag_lifts_the_disk_and_end_drag_returns_it():
	row.set_charms(_charms(2))
	row.begin_drag(1)
	assert_true(row.dragging())
	row.drag_to(Vector3(30.0, 0.0, 0.0))
	assert_almost_eq(row.disks[1].global_position.y, CharmRowView.DRAG_HEIGHT, 0.001)
	assert_eq(row.drop_target(row.readers[0].global_position), 0, "das nächste Laufwerk quer")
	row.end_drag()
	assert_false(row.dragging())
	row.settle_hard()
	assert_almost_eq(row.disks[1].global_position.distance_to(
		row.readers[1].disk_global_transform().origin), 0.0, 0.001)

func test_sale_text_lands_on_the_hovered_reader_only():
	row.set_charms(_charms(3))
	row.set_badges({0: "+2"})
	row.set_sale(1, "VERKAUF $4")
	assert_eq(row.readers[1].display_text(), "VERKAUF $4")
	assert_eq(row.readers[0].display_text(), "+2", "der Nachbar zeigt weiter seinen Zähler")
	row.set_sale(-1, "")
	assert_eq(row.readers[1].display_text(), "")

# --- Lichtgestalt ---------------------------------------------------------------

func _surfaces_of(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_surfaces_of(child, out)

func test_model_wears_the_hologram():
	# Jede Fläche trägt den Hologramm-Shader mit gesättigter Originalfarbe/-textur.
	row.set_charms(_charms(1))
	var meshes: Array = []
	_surfaces_of(row.charm_models[0], meshes)
	assert_gt(meshes.size(), 0, "das Modell bringt Flächen mit")
	var checked := 0
	for mesh_instance: MeshInstance3D in meshes:
		var count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0
		for s in count:
			var material := mesh_instance.get_active_material(s) as ShaderMaterial
			assert_not_null(material, "die Fläche trägt den Hologramm-Shader")
			assert_eq(material.shader, CharmRowView.HOLO_SHADER)
			assert_gt(float(material.get_shader_parameter("saturation")), 1.0,
				"die Farbe wird gesättigt, nicht ausgegraut")
			checked += 1
	assert_gt(checked, 0, "mindestens eine Fläche geprüft")

## Das Modell bleibt MASSIV und beleuchtet: der Effekt liegt darüber, nie additiv
## (der additive Ersatz war viel zu hell).
func test_the_hologram_is_not_additive():
	var code: String = CharmRowView.HOLO_SHADER.code
	assert_false(code.contains("blend_add"), "nicht additiv")
	assert_false(code.contains("unshaded"), "beleuchtet")
	assert_false(code.contains("flicker"), "kein Flackern - clean, nicht CRT")

## Lichtkante plus Kegel (Spieler-Wahl 2026-09-09): je Platz ein kurzer Kegel aus der
## Linse, das Modell schwebt auf und ab, der Saum trägt das Blau.
func test_emitter_cone_and_hover_bob():
	row.set_charms(_charms(2))
	assert_eq(row.cone_nodes.size(), 2, "je Platz ein Kegel")
	var cone := row.cone_nodes[0].mesh as CylinderMesh
	assert_almost_eq(cone.height, CharmRowView.CONE_HEIGHT, 0.001)
	assert_lt(cone.height, 3.0, "kurz - kein Splitter unter der 15°-Kamera")
	var first: ShaderMaterial = row.charm_materials[0][0]
	assert_almost_eq(float(first.get_shader_parameter("rim_gain")), CharmRowView.HOLO_RIM, 0.001)
	var before: float = row.charm_models[0].position.y
	await wait_seconds(0.6)
	assert_ne(row.charm_models[0].position.y, before, "das Modell schwebt auf und ab")
	assert_lte(absf(row.charm_models[0].position.y) * CharmRowView.MODEL_SCALE,
		CharmRowView.BOB_HEIGHT + 0.001, "und bleibt im Hub")

func test_flash_charm_lifts_the_holo_sheen():
	row.set_charms(_charms(1))
	var materials: Array = row.charm_materials[0]
	assert_gt(materials.size(), 0, "die Flächen sind gemerkt")
	var first: ShaderMaterial = materials[0]
	assert_almost_eq(float(first.get_shader_parameter("flash")), 0.0, 0.001)
	row.flash_charm(0)
	await wait_seconds(0.09)
	assert_gt(float(first.get_shader_parameter("flash")), 0.0, "der Schimmer zieht mit")
	await wait_seconds(0.6)
	assert_almost_eq(float(first.get_shader_parameter("flash")), 0.0, 0.02,
		"und fällt zurück")

func test_cached_model_resource_stays_untouched():
	# Die Materialien liegen im geteilten GLB-Cache - die Reihe legt ihren Shader
	# als Flächen-Override DARÜBER, statt die Ressource anzufassen.
	var path := Charm.rabbits_foot().model_path
	var probe: Node3D = autofree(CharmRowView.model_scene(path).instantiate())
	var meshes: Array = []
	_surfaces_of(probe, meshes)
	var first: MeshInstance3D = meshes[0]
	row.set_charms(_charms(1))
	assert_true(first.get_active_material(0) is BaseMaterial3D,
		"die gecachte Ressource bleibt ein Originalmaterial")

func test_headless_starts_no_load_thread():
	# Kopflos ist der Texturspeicher der Renderer-Attrappe nicht fadensicher: kein
	# Ladeauftrag darf laufen, model_scene() liefert trotzdem blockierend.
	assert_false(CharmRowView.threaded_loads(), "die Suite läuft kopflos")
	var path := ""
	for charm in Charm.all():
		if charm.model_path != "" and CharmRowView.cached_model_scene(charm.model_path) == null:
			path = charm.model_path
			break
	assert_ne(path, "", "ein ungeladenes Modell für die Probe")
	CharmRowView.request_model_scene(path)
	assert_eq(CharmRowView.models_in_flight(), 0, "kein Ladethread")
	assert_eq(CharmRowView.models_queued(), 0, "und keine Schlange")
	assert_not_null(CharmRowView.model_scene(path), "geliefert wird trotzdem")
