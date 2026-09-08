extends GutTest
## Tier-2-Tests der Charm-Reihe (CharmRowView). Prüft, dass je Charm ein
## Hologramm-Modell samt Lichtzylinder auf einem festen Platz landet, die Plätze
## bei mehr Charms als Plätzen gekappt werden, und dass die sechs Plätze einen
## gleichmäßigen, spiegelsymmetrischen Bogen auf der Tischfläche bilden.

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

func test_all_spots_share_table_height():
	# Kein Podest mehr: die Charms sitzen direkt auf der Tischfläche (SPOT_Y).
	for i in CharmRowView.SPOT_COUNT:
		assert_almost_eq(row._spot_transform(i).origin.y, CharmRowView.SPOT_Y, 0.001)

func test_row_evenly_spaced_in_z():
	# Benachbarte Plätze haben in Z stets denselben Abstand (LINE_SPACING).
	var z: Array = []
	for i in CharmRowView.SPOT_COUNT:
		z.append(row._spot_transform(i).origin.z)
	for i in range(1, CharmRowView.SPOT_COUNT):
		assert_almost_eq(z[i] - z[i - 1], CharmRowView.LINE_SPACING, 0.001)

# --- Lichtzylinder --------------------------------------------------------------

func test_one_beam_per_occupied_spot():
	row.set_charms(_charms(2))
	assert_eq(row.beam_nodes.size(), 2, "je besetztem Platz genau ein Lichtzylinder")

func test_beams_cleared_with_charms():
	row.set_charms(_charms(3))
	row.set_charms([])
	assert_eq(row.beam_nodes.size(), 0, "leere Reihe hat keine Lichtzylinder mehr")

func test_beam_color_follows_rarity():
	# Gewöhnlich (Hasenpfote) und Legendär (Zerbrochener Spiegel) bekommen
	# unterschiedlich getönte Kegel-Materialien; gleiche Rarität teilt ihres.
	var charms: Array[Charm] = [Charm.rabbits_foot(), Charm.broken_mirror(), Charm.lucky_cigarettes()]
	row.set_charms(charms)
	assert_ne(row.beam_nodes[0].material_override, row.beam_nodes[1].material_override,
		"Gewöhnlich und Legendär schimmern verschieden")
	assert_eq(row.beam_nodes[0].material_override, row.beam_nodes[2].material_override,
		"gleiche Rarität teilt dasselbe Kegel-Material")

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

func test_flash_charm_tolerates_invalid_index():
	row.set_charms(_charms(1))
	row.flash_charm(-1)
	row.flash_charm(5)  # außerhalb - darf nicht abstürzen
	assert_eq(row.charm_nodes.size(), 1)
