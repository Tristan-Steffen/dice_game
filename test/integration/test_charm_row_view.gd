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

func test_flash_charm_tolerates_invalid_index():
	row.set_charms(_charms(1))
	row.flash_charm(-1)
	row.flash_charm(5)  # außerhalb - darf nicht abstürzen
	assert_eq(row.charm_nodes.size(), 1)

# --- Das echte Modell ---------------------------------------------------------

## Der Ladethread legt Texturen an, der Hauptfaden auch - und der Texturspeicher
## der Kopf-los-Attrappe ist nicht fadensicher. Kopflos darf darum KEIN Auftrag
## laufen, sonst kippt irgendein fremder Test mit 'Parameter "t" is null'.
func test_no_loader_thread_runs_without_a_renderer():
	if CharmRowView.models_wanted():
		pass_test("mit echtem Renderer lädt der Ladethread - hier nichts zu prüfen")
		return
	var path := Charm.horseshoe().model_path
	assert_null(CharmRowView.cached_model_scene(path), "ungeladen - sonst prüft der Test nichts")
	CharmRowView.request_model_scene(path)
	assert_eq(CharmRowView.pending_model_loads(), 0, "kein Auftrag im Ladethread")

## Kopflos zeigt die Reihe den Platzhalter (siehe CharmRowView.models_wanted).
## EIN echtes Modell wird trotzdem geholt, sonst bliebe der ganze Ladeweg -
## GLB, Geometrie, Hologramm-Auflage - in der Suite ungefahren.
func test_a_real_model_loads_with_geometry_and_takes_the_hologram():
	var scene := CharmRowView.model_scene(Charm.rabbits_foot().model_path)
	assert_not_null(scene, "das GLB lädt")
	var model: Node3D = autofree(scene.instantiate())
	assert_gt(CharmThumb.merged_aabb(model).size.length(), 0.0, "es bringt Geometrie mit")
	var materials: Array[ShaderMaterial] = []
	CharmRowView.apply_hologram(model, materials)
	assert_gt(materials.size(), 0, "jede Fläche trägt ihr Hologramm-Material")
