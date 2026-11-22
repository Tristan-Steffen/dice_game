extends GutTest
## Die CHARM-DISKETTE (2026-11-18): Wirkung so groß wie das Feld erlaubt, LEDs je Rarität,
## Raritätsfarbe am Rahmen, EINE Größe.

const WIDTH := CharmDiskView.TEXT_WIDTH * CharmDiskView.BLENDER_SCALE / CharmDiskView.PIXEL
const HEIGHT := (CharmDiskView.DESC_TOP - CharmDiskView.DESC_BOTTOM) \
	* CharmDiskView.BLENDER_SCALE / CharmDiskView.PIXEL
const BIGGEST := int(CharmDiskView.DESC_BIGGEST * CharmDiskView.BLENDER_SCALE / CharmDiskView.PIXEL)

func _disk(charm: Charm) -> CharmDiskView:
	var disk := CharmDiskView.new(charm)
	add_child_autofree(disk)
	return disk

func test_the_longest_text_fits_its_field() -> void:
	var font := CharmDiskView.disk_font()
	for charm in Charm.all():
		var size := CharmDiskView.fit_size(charm.description, WIDTH, HEIGHT, BIGGEST)
		var block := font.get_multiline_string_size(charm.description, HORIZONTAL_ALIGNMENT_LEFT,
			WIDTH, size)
		assert_lte(block.y, HEIGHT + 0.5, "%s paßt ins Feld" % charm.id)

func test_short_texts_grow_and_the_cap_holds() -> void:
	var short := CharmDiskView.fit_size("Jede 3 zählt als 4.", WIDTH, HEIGHT, BIGGEST)
	var long := CharmDiskView.fit_size(Charm.phoenix_feather().description, WIDTH, HEIGHT, BIGGEST)
	assert_gt(short, long, "ein kurzer Text wird größer")
	assert_eq(CharmDiskView.fit_size("x", WIDTH, HEIGHT, BIGGEST), BIGGEST, "der Deckel hält")

func test_fit_size_never_falls_below_its_floor() -> void:
	var text := "lang ".repeat(400)
	assert_eq(CharmDiskView.fit_size(text, WIDTH, HEIGHT, BIGGEST, 12), 12)

func test_leds_count_the_rarity() -> void:
	var cases := {
		Charm.RARITY_COMMON: 1, Charm.RARITY_UNCOMMON: 2,
		Charm.RARITY_RARE: 3, Charm.RARITY_LEGENDARY: 4,
	}
	for rarity: String in cases:
		assert_eq(CharmDiskView.rarity_tier(rarity), cases[rarity], rarity)
	var disk := _disk(Charm.phoenix_feather())
	assert_eq(disk.leds.size(), 4, "immer vier LEDs")
	assert_eq(disk.led_lit_count(), CharmDiskView.rarity_tier(Charm.phoenix_feather().rarity))

func test_frame_wears_the_rarity_color() -> void:
	var common := _disk(Charm.rabbits_foot())
	var legendary := _disk(Charm.broken_mirror())
	assert_eq(common.frame_color(), CharmDiskView.energized(
		Charm.RARITY_COLORS[Charm.RARITY_COMMON], CharmDiskView.FRAME_REST))
	assert_ne(common.frame_color(), legendary.frame_color(), "jede Rarität ihre Farbe")

func test_the_text_lives_outside_the_slot() -> void:
	# Lokal +X steckt zuerst: die Wirkung liegt im Teil, der draußen bleibt.
	var disk := _disk(Charm.anchor())
	var mouth := CharmDiskView.SIZE.x * 0.5 - CharmDiskView.INSERT_DEPTH
	assert_lt(disk.desc_label.position.x, mouth, "die Wirkung beginnt vor dem Schlitz")
	assert_eq(disk.find_children("*", "Label3D", true, false).filter(
		func(label: Label3D) -> bool: return label.text.contains(Charm.anchor().display_name.to_upper())
	).size(), 0, "den Namen trägt der Projektor, nicht die Diskette")

func test_one_size_everywhere() -> void:
	assert_almost_eq(CharmDiskView.SIZE.x, 0.94 * CharmDiskView.BLENDER_SCALE, 0.001)
	assert_almost_eq(CharmDiskView.SIZE.z, 0.9 * CharmDiskView.BLENDER_SCALE, 0.001)
	assert_lt(CharmDiskView.SIZE.z, CharmRowView.LINE_SPACING, "paßt zwischen zwei Plätze")

func test_the_price_tag_shows_and_hides() -> void:
	var disk := _disk(Charm.anchor())
	disk.set_tag("$12")
	assert_eq(disk.tag_text(), "$12")
	disk.set_tag("")
	assert_eq(disk.tag_text(), "", "im Laufwerk trägt sie kein Schild")

func test_lift_and_carry_end_in_their_end_state() -> void:
	var disk := _disk(Charm.anchor())
	disk.set_lifted(true)
	await wait_seconds(CharmDiskView.LIFT_TIME + 0.05)
	assert_true(disk.lifted())
	var goal := Transform3D(Basis(), Vector3(4.0, 0.0, 2.0))
	disk.carry_to(goal, 0.5, 1.0)
	assert_true(disk.carrying())
	disk.settle_carry()
	assert_false(disk.carrying())
	assert_almost_eq(disk.global_position.distance_to(goal.origin), 0.0, 0.001, "hart am Ziel")
