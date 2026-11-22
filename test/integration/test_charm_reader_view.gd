extends GutTest
## Ein LAUFWERK der Charm-Reihe (2026-11-18): leer dunkel, belegt in der Rarität, das
## Front-Display trägt Zähler und Verkaufspreis, die Auswurf-Taste ist treffbar.

var reader: CharmReaderView

func before_each() -> void:
	reader = CharmReaderView.new()
	add_child_autofree(reader)

func test_empty_reader_is_dark_and_silent() -> void:
	assert_eq(reader.glow_color(), CharmReaderView.DARK)
	reader.set_badge("+3")
	assert_eq(reader.display_text(), "", "ein leeres Laufwerk zeigt keinen Zähler")

func test_occupied_reader_glows_in_its_rarity() -> void:
	reader.set_charm(Charm.broken_mirror())
	var expected := CharmDiskView.energized(CharmDiskView.rarity_color(Charm.broken_mirror().rarity),
		CharmReaderView.RING_REST)
	assert_eq(reader.glow_color(), expected)
	reader.set_charm(null)
	assert_eq(reader.glow_color(), CharmReaderView.DARK, "ausgeworfen wird es wieder dunkel")

func test_display_shows_badge_and_sale_wins_while_hovered() -> void:
	reader.set_charm(Charm.rabbits_foot())
	reader.set_badge("+4")
	assert_eq(reader.display_text(), "+4")
	reader.set_sale("VERKAUF $5")
	assert_eq(reader.display_text(), "VERKAUF $5", "beim Hover der Preis")
	reader.set_sale("")
	assert_eq(reader.display_text(), "+4", "danach wieder der Zähler")

func test_the_glow_parts_are_found_in_the_model() -> void:
	for part in CharmReaderView.GLOW_PARTS:
		assert_true(reader._parts.has(part), "%s ist ein eigenes Netz" % part)

func test_eject_button_is_hit_on_screen() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = Vector3(-6.0, 30.0, 0.0)
	camera.look_at(Vector3.ZERO, Vector3.RIGHT)
	camera.current = true
	await wait_frames(1)
	var eject := reader.eject_screen_rect(camera)
	assert_gt(eject.size.x, 0.0, "die Taste hat eine Fläche im Bild")
	assert_true(reader.screen_rect(camera).encloses(eject), "und liegt im Laufwerk")
	var center := camera.unproject_position(reader.to_global(CharmReaderView.EJECT_CENTER))
	assert_true(eject.has_point(center))

func test_the_disk_sits_at_slot_height() -> void:
	var at := reader.disk_global_transform().origin
	assert_almost_eq(at.y + CharmDiskView.SIZE.y * 0.5, CharmReaderView.SLOT_Y, 0.001)
	assert_lt(reader.lens_global_position().y - CharmReaderView.SIZE.y, 1.0,
		"die Linse sitzt oben auf")

func test_the_display_carries_the_charm_name() -> void:
	reader.set_charm(Charm.rabbits_foot())
	assert_eq(reader.name_text(), Charm.rabbits_foot().display_name.to_upper())
	reader.set_sale("VERKAUF $5")
	assert_eq(reader.name_text(), "", "der Preis steht allein")
	reader.set_sale("")
	reader.set_charm(null)
	assert_eq(reader.name_text(), "", "leer nennt es nichts")

func test_a_long_name_shrinks_to_fit_beside_its_counter() -> void:
	reader.set_charm(Charm.four_leaf_clover())
	var alone := reader.name_label.font_size
	reader.set_badge("+12")
	assert_lte(reader.name_label.font_size, alone, "neben dem Zähler bleibt weniger Breite")
