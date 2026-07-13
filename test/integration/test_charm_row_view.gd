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

func test_spot_angles_symmetric_and_evenly_spaced():
	var angles: Array = CharmRowView.SPOT_ANGLES_DEG
	assert_eq(angles.size(), 6)
	# Spiegelpaare
	assert_almost_eq(angles[0], -angles[5], 0.001)
	assert_almost_eq(angles[1], -angles[4], 0.001)
	assert_almost_eq(angles[2], -angles[3], 0.001)
	# gleichmäßiger Abstand
	assert_almost_eq(angles[1] - angles[0], angles[2] - angles[1], 0.001)

# --- Lichtzylinder --------------------------------------------------------------

func test_one_beam_per_occupied_spot():
	row.set_charms(_charms(2))
	assert_eq(row.beam_nodes.size(), 2, "je besetztem Platz genau ein Lichtzylinder")

func test_beams_cleared_with_charms():
	row.set_charms(_charms(3))
	row.set_charms([])
	assert_eq(row.beam_nodes.size(), 0, "leere Reihe hat keine Lichtzylinder mehr")
