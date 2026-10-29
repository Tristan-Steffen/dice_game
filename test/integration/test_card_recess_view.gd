extends GutTest
## Die Mulde eines Kassetten-Platzes in Laden und Schwarzmarkt (2026-10-29) und der
## Hover-Spielraum der Karte darin.

const SCALE := PackDrawerView.CASSETTE_SCALE

func _recess(pitch := 0.0) -> CardRecessView:
	var recess := CardRecessView.new()
	add_child_autofree(recess)
	recess.seat(Vector3(1.0, 0.0, 2.0), SCALE, pitch)
	return recess

func test_the_card_lies_flush_with_the_table() -> void:
	var recess := _recess()
	var glass := Vector3(1.0, 0.0, 2.0)
	assert_almost_eq(recess.global_position.y, -recess.depth(), 0.0001,
		"der Muldenboden liegt eine Muldentiefe unter der Fläche")
	var card := recess.card_point(glass)
	assert_almost_eq(card.y + DataCellView.DEPTH * SCALE, glass.y, 0.0001,
		"die Oberkante der Karte schließt mit der Fläche ab")
	assert_almost_eq(recess.depth(), ShelfStackView.deck_height_for(SCALE), 0.0001,
		"dieselbe Tiefe wie im Magazin")

func test_it_is_the_magazine_bay() -> void:
	var recess := _recess()
	assert_eq(recess.opening_half() * 2.0, ShelfStackView.bay_size_for(SCALE))
	for part in ["Saum", "Boden", "WandLA", "WandLB", "WandQA", "WandQB"]:
		assert_not_null(recess.get_node_or_null(part), "die Mulde trägt %s" % part)

func test_a_tight_row_keeps_a_lip_between_bays() -> void:
	var card := DataCellView.HEIGHT * SCALE
	var recess := _recess(card + 0.02)
	assert_lt(recess.opening_half().y * 2.0, card + 0.02, "zwischen zwei Mulden steht ein Steg")
	assert_true(recess.opening_half().y * 2.0 >= card - 0.0001, "die Karte paßt trotzdem")

## Der SPIELRAUM: die gehoverte Karte hält den Zeiger noch knapp neben ihrem Netz.
func test_a_card_holds_the_pointer_a_little_beyond_its_net() -> void:
	var cell := DataCellView.new()
	add_child_autofree(cell)
	cell.setup(Engraving.CATEGORY_NUMBER, Pack.TIER_NORMAL, StampNet.empty_net())
	cell.set_body_scale(SCALE)
	cell.lie_on_glass(Vector3.ZERO)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.look_at_from_position(Vector3(0.0, 12.0, 0.0), Vector3.ZERO, Vector3.FORWARD)
	camera.current = true
	await wait_frames(1)
	var mid := camera.unproject_position(cell.global_position)
	var edge := 0
	var held := 0
	for step in 600:
		var probe := mid + Vector2(step, 0)
		if cell.holds_pointer(camera, probe, 0.0):
			edge = step
		if cell.holds_pointer(camera, probe):
			held = step
	assert_gt(edge, 0, "die Karte liegt im Bild")
	assert_gt(held, edge, "über den Netzrand hinaus hält sie noch")
	assert_lt(held, edge * 3, "aber nicht beliebig weit")
