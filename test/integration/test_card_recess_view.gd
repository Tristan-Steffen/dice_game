extends GutTest
## Die Mulde eines Kassetten-Platzes in Laden und Schwarzmarkt (2026-10-29).

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
