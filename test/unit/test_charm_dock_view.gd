extends GutTest
## Tier-1-Tests des Charm-Docks (CharmDockView): je Platz eine eigene senkrechte
## Konsole (Projektor oben, Karte darunter), Treffer auf der ganzen Konsole,
## Ablageziel beim 2D-Drag und der Bild->Text-Wechsel der Karte bei Hover.

func _dock() -> CharmDockView:
	var d := CharmDockView.new()
	add_child_autofree(d)
	return d

func _charm(id: String, rarity := Charm.RARITY_COMMON) -> Charm:
	var c := Charm.new()
	c.id = id
	c.display_name = id.capitalize()
	c.description = "Wirkung von %s" % id
	c.rarity = rarity
	return c

func _ids(ids: Array) -> Array[Charm]:
	var out: Array[Charm] = []
	for id in ids:
		out.append(_charm(id))
	return out

## Drei Projektor-Mitten waagerecht bei y=200, Mittenabstand 100, Karte 60x60.
func _apertures() -> PackedVector2Array:
	return PackedVector2Array([Vector2(100, 200), Vector2(200, 200), Vector2(300, 200)])

func _card_drop() -> float:
	# Fallback-Projektor (kein Beam-Radius im Test): Radius + Lücke + halbe Karte.
	return 60.0 * (CharmDockView.PROJECTOR_FALLBACK + CharmDockView.PROJECTOR_GAP + 0.5)

func test_card_sits_below_projector():
	var d := _dock()
	d.place(_apertures(), Vector2(60, 60))
	# pad_center = Karte = Projektor + CARD_DROP nach unten.
	assert_almost_eq(d.pad_center(1).x, 200.0, 0.01)
	assert_almost_eq(d.pad_center(1).y, 200.0 + _card_drop(), 0.01)

func test_each_slot_gets_its_own_console():
	var d := _dock()
	d.place(_apertures(), Vector2(60, 60))
	var consoles := d.console_rects()
	assert_eq(consoles.size(), 3, "eine Konsole je Platz")
	assert_lt(consoles[0].end.x, consoles[1].position.x, "Konsolen berühren sich nicht")
	# Senkrecht: höher als breit, umschließt Projektor (oben) und Karte (unten).
	assert_gt(consoles[0].size.y, consoles[0].size.x, "Konsole ist hochkant")
	assert_lt(consoles[0].position.y, 200.0, "Projektor liegt in der Konsole")
	assert_gt(consoles[0].end.y, 200.0 + _card_drop() + 30.0, "Karte liegt in der Konsole")

func test_pad_index_at_hits_whole_console_of_occupied_slots():
	var d := _dock()
	d.place(_apertures(), Vector2(60, 60))
	d.set_charms(_ids(["a", "b"]))  # Platz 3 bleibt leer
	var card_y := 200.0 + _card_drop()
	assert_eq(d.pad_index_at(Vector2(100, card_y)), 0, "Karte trifft")
	assert_eq(d.pad_index_at(Vector2(200, 200)), 1, "Projektor zählt zur Konsole")
	assert_eq(d.pad_index_at(Vector2(300, card_y)), -1, "leere Konsole ist kein Treffer")
	assert_eq(d.pad_index_at(Vector2(150, 250)), -1, "Lücke zwischen Konsolen")
	assert_eq(d.pad_index_at(Vector2(1000, 1000)), -1, "außerhalb des Docks")

func test_drop_target_follows_drag_x_and_resets():
	var d := _dock()
	d.place(_apertures(), Vector2(60, 60))
	d.set_charms(_ids(["a", "b", "c"]))
	d.begin_drag(0)
	d.drag_to(d.pad_center(2))  # über Karte 2 gezogen
	assert_eq(d.drop_target(), 2, "nächster Platz nach x wird Ablageziel")
	d.end_drag()
	assert_eq(d.drop_target(), -1, "nach dem Loslassen kein Ziel mehr")

func test_hover_swaps_card_image_for_text():
	var d := _dock()
	d.place(_apertures(), Vector2(60, 60))
	d.set_charms(_ids(["a", "b"]))
	d.set_hover(1)
	assert_false(d._thumbs[1].visible, "Bild weicht dem Text")
	assert_true(d._thumbs[0].visible, "Nachbar-Konsole bleibt beim Bild")
	assert_eq(d._name_label.text, "B", "Name in der Konsole")
	assert_ne(d._body_label.text, "", "Wirkung in der Konsole")
	d.set_hover(-1)
	assert_true(d._thumbs[1].visible, "Bild kehrt zurück")
	assert_false(d._name_label.visible, "Text verschwindet")

func test_hover_suppressed_during_drag():
	var d := _dock()
	d.place(_apertures(), Vector2(60, 60))
	d.set_charms(_ids(["a", "b"]))
	d.begin_drag(0)
	d.set_hover(1)  # während des Ziehens ignoriert
	assert_true(d._thumbs[1].visible, "kein Bild->Text-Wechsel während des Drags")
	d.end_drag()

func test_hover_shows_sell_chip_where_clicks_sell():
	var d := _dock()
	d.place(_apertures(), Vector2(60, 60))
	var values: Array[int] = [5, 7]
	d.set_charms(_ids(["a", "b"]), values)
	d.set_hover(1)
	assert_true(d._sell_label.visible, "Chip auf der gehoverten Karte")
	assert_eq(d._sell_label.text, "Verkaufen $7")
	var chip_center: Vector2 = d.position + d._sell_rect.get_center()
	assert_eq(d.sell_index_at(chip_center), 1, "Chip-Treffer meldet den Platz")
	assert_eq(d.sell_index_at(d.pad_center(0)), -1, "fremde Karte hat keinen Chip")
	d.set_hover(-1)
	assert_eq(d.sell_index_at(chip_center), -1, "ohne Hover kein Verkauf")

func test_hover_without_sell_values_shows_no_chip():
	var d := _dock()
	d.place(_apertures(), Vector2(60, 60))
	d.set_charms(_ids(["a"]))
	d.set_hover(0)
	assert_false(d._sell_label.visible, "ohne Verkaufswert kein Chip")
	assert_eq(d.sell_index_at(d.pad_center(0)), -1)

func test_mult_badge_shows_value_on_its_slot_and_hides_at_zero():
	var d := _dock()
	d.place(_apertures(), Vector2(60, 60))
	d.set_charms(_ids(["a", "b"]))
	d.set_mult_badge(1, 15)
	assert_true(d._badge_label.visible, "Chip an seiner Karte sichtbar")
	assert_eq(d._badge_label.text, "+15")
	d.set_mult_badge(1, 0)
	assert_false(d._badge_label.visible, "bei 0 verschwindet der Chip")

func test_mult_badge_hidden_for_unoccupied_or_missing_slot():
	var d := _dock()
	d.place(_apertures(), Vector2(60, 60))
	d.set_charms(_ids(["a"]))  # nur Platz 0 belegt
	d.set_mult_badge(2, 15)  # leerer Platz
	assert_false(d._badge_label.visible, "kein Chip auf leerem Platz")
	d.set_mult_badge(-1, 15)  # Charm nicht im Besitz
	assert_false(d._badge_label.visible, "kein Chip ohne Ziel")
