extends GutTest
## Tier-2-Tests der Charm-Reihe (CharmRowView). Prüft, dass je Charm eine
## HOLOGRAMM (Emitter-Ring, Lichtgestalt) auf einem festen Platz landet, die Plätze
## bei mehr Charms als Plätzen gekappt werden, die sechs Plätze eine gleichmäßige,
## spiegelsymmetrische Reihe auf der Tischfläche bilden - und dass das Modell als
## additive Lichtgestalt in gesättigten Originalfarben liest.

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

func test_row_is_a_straight_line():
	# Gerade Reihe: alle Plätze teilen dasselbe X (fester hinterer Rand).
	for i in CharmRowView.SPOT_COUNT:
		assert_almost_eq(row._spot_transform(i).origin.x, CharmRowView.LINE_X, 0.001)

func test_spots_mirror_across_z_axis():
	# Äußerste Plätze (0 und 5) spiegeln sich über Z=0: gleiches X, entgegengesetztes Z.
	var t0 := row._spot_transform(0)
	var t5 := row._spot_transform(5)
	assert_almost_eq(t0.origin.x, t5.origin.x, 0.001)
	assert_almost_eq(t0.origin.z, -t5.origin.z, 0.001)

func test_models_hover_over_the_emitter():
	# Das Hologramm schwebt über seinem Emitter - eine Projektion steht nicht auf.
	for i in CharmRowView.SPOT_COUNT:
		assert_almost_eq(row._spot_transform(i).origin.y,
			CharmRowView.SPOT_Y + CharmRowView.HOVER_HEIGHT, 0.001)

func test_reported_spot_stays_on_the_table():
	# Der gemeldete Platz (Sockelring des Docks, Drop-Ziel) bleibt die Tischfläche.
	for i in CharmRowView.SPOT_COUNT:
		assert_almost_eq(row.spot_global_position(i).y, CharmRowView.SPOT_Y, 0.001)

func test_row_evenly_spaced_in_z():
	# Benachbarte Plätze haben in Z stets denselben Abstand (LINE_SPACING).
	var z: Array = []
	for i in CharmRowView.SPOT_COUNT:
		z.append(row._spot_transform(i).origin.z)
	for i in range(1, CharmRowView.SPOT_COUNT):
		assert_almost_eq(z[i] - z[i - 1], CharmRowView.LINE_SPACING, 0.001)

# --- Emitter-Körper -------------------------------------------------------------

func test_one_emitter_per_occupied_spot():
	row.set_charms(_charms(2))
	assert_eq(row.ring_nodes.size(), 2, "je besetztem Platz genau ein Emitter-Ring")

func test_emitters_cleared_with_charms():
	row.set_charms(_charms(3))
	row.set_charms([])
	assert_eq(row.ring_nodes.size(), 0, "leere Reihe hat keine Emitter mehr")

## Kein Sockel (Spieler-Entscheid 2026-09-09): der Emitter liegt flach auf dem
## Filz, das Modell schwebt darüber, und der Strahler sieht nur die Modelle.
func test_the_emitter_lies_flat_on_the_felt():
	row.set_charms(_charms(1))
	assert_almost_eq(row.ring_nodes[0].position.y, CharmRowView.RING_HEIGHT * 0.5, 0.001,
		"der Ring liegt auf der Tischfläche")
	assert_eq(row.spot_lights.size(), 1, "je Platz ein Strahler")
	assert_eq(row.spot_lights[0].light_cull_mask, CharmRowView.MODEL_LIGHT_LAYER,
		"der Filz sieht ihn nicht")

func test_ring_color_follows_rarity():
	# Gewöhnlich (Hasenpfote) und Legendär (Zerbrochener Spiegel) leuchten
	# verschieden; gleiche Rarität teilt ihre Farbe.
	var charms: Array[Charm] = [Charm.rabbits_foot(), Charm.broken_mirror(), Charm.lucky_cigarettes()]
	row.set_charms(charms)
	assert_ne(row.ring_materials[0].albedo_color, row.ring_materials[1].albedo_color,
		"Gewöhnlich und Legendär leuchten verschieden")
	assert_eq(row.ring_materials[0].albedo_color, row.ring_materials[2].albedo_color,
		"gleiche Rarität teilt dieselbe Kantenlicht-Farbe")

func test_every_spot_owns_its_ring_material():
	# Geteilt blitzten beim Feuern alle Emitter derselben Rarität mit.
	row.set_charms(_charms(3))
	assert_ne(row.ring_materials[0], row.ring_materials[1],
		"je Platz eine eigene Ring-Instanz")

func test_ring_rests_below_the_bloom_threshold():
	# Ruhe darf nicht dauerhaft bloomen (Schwelle 0,95), das Feuern muss darüber.
	row.set_charms(_charms(1))
	var rest: Color = row.ring_materials[0].albedo_color
	assert_lt(maxf(maxf(rest.r, rest.g), rest.b), 0.95, "Ruhe bleibt unter der Schwelle")
	var flash := CharmRowView.ring_color(Charm.rabbits_foot().rarity,
		CharmRowView.RING_FLASH_ENERGY)
	assert_gt(maxf(maxf(flash.r, flash.g), flash.b), 0.95, "der Puls bloomt")

func test_flash_charm_lifts_the_ring_and_falls_back():
	row.set_charms(_charms(1))
	var material: StandardMaterial3D = row.ring_materials[0]
	var rest: Color = material.albedo_color
	row.flash_charm(0)
	await wait_seconds(0.09)
	assert_gt(material.albedo_color.b, rest.b, "das Kantenlicht steigt")
	await wait_seconds(0.6)
	assert_almost_eq(material.albedo_color.b, rest.b, 0.02, "und fällt zurück")

func test_flash_charm_tolerates_invalid_index():
	row.set_charms(_charms(1))
	row.flash_charm(-1)
	row.flash_charm(5)  # außerhalb - darf nicht abstürzen
	assert_eq(row.charm_nodes.size(), 1)

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

## Jedes Preset ist vollständig und wendet sich auf die Flächen an.
func test_every_preset_applies():
	for i in CharmRowView.HOLO_PRESETS.size():
		CharmRowView.holo_variant = i
		row.set_charms(_charms(1))
		var first: ShaderMaterial = row.charm_materials[0][0]
		var chosen: Dictionary = CharmRowView.HOLO_PRESETS[i]
		assert_almost_eq(float(first.get_shader_parameter("alpha")), float(chosen["alpha"]), 0.001,
			chosen["name"])
		assert_eq(row.cone_nodes.size(), 1 if bool(chosen["cone"]) else 0, chosen["name"])
	CharmRowView.holo_variant = 0

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

func test_the_loader_caps_how_many_models_are_in_flight():
	# Die Bibliothek fordert beim Öffnen ALLE Charm-Modelle an. Ohne Deckel musste
	# sich das blockierende model_scene() durch die ganze Schlange warten - gemessen
	# 35 s für dieses Skript statt 0,2 s.
	var paths: Array[String] = []
	for charm in Charm.all():
		if charm.model_path != "" and CharmRowView.cached_model_scene(charm.model_path) == null:
			paths.append(charm.model_path)
		if paths.size() == CharmRowView.MAX_IN_FLIGHT * 3:
			break
	assert_gt(paths.size(), CharmRowView.MAX_IN_FLIGHT, "genug ungeladene Modelle für die Probe")
	for path in paths:
		CharmRowView.request_model_scene(path)
	assert_eq(CharmRowView.models_in_flight(), CharmRowView.MAX_IN_FLIGHT,
		"nie mehr als der Deckel im Ladethread")
	assert_gt(CharmRowView.models_queued(), 0, "der Rest wartet in der Schlange")
	# Wer nur wartet, wird selbst geladen statt abgewartet - das ist der Ausweg.
	for path in paths:
		assert_not_null(CharmRowView.model_scene(path), "auch ein Wartender wird geliefert")
