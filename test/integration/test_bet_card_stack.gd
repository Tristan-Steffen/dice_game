extends GutTest
## Der Karten-Gewinn in der Wett-Grube: jede Karte einzeln, geliefert und eingebrannt.

func _stack(count: int) -> BetCardStack:
	var packs: Array[Pack] = []
	for i in count:
		packs.append(Pack.tiered(Pack.by_type(Pack.TYPE_NUMBER), Pack.TIER_KOLOSSAL))
	var stack := BetCardStack.new()
	add_child_autofree(stack)
	stack.setup(packs, DataCellView.HEIGHT * PackDrawerView.CASSETTE_SCALE * 2.0)
	return stack

func test_every_card_lies_on_its_own() -> void:
	var stack := _stack(3)
	assert_eq(stack.cards.size(), 3)
	assert_lt(stack.cards[0].position.z, stack.cards[2].position.z, "gefächert nach Bild-rechts")
	assert_lt(stack.cards[0].position.y, stack.cards[2].position.y, "und übereinander")
	assert_gt(stack.body_height(), DataCellView.DEPTH * PackDrawerView.CASSETTE_SCALE)

func test_every_card_shows_its_net() -> void:
	var stack := _stack(2)
	for i in 2:
		assert_eq(stack.cards[i].stamp_net, stack.packs[i].stamp_net, "die Karte trägt ihr Netz")
		assert_true(stack.cards[i].visible)
