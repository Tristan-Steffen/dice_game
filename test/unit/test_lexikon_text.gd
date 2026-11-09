extends GutTest
## Wirkungstext mit Lexikon-Verweisen: Farbe, Hover-Karte, Klick.

func _text() -> LexikonText:
	var stage := Control.new()
	stage.size = Vector2(600, 400)
	add_child_autofree(stage)
	var label := LexikonText.new()
	label.size = Vector2(300, 100)
	stage.add_child(label)
	label.attach_hint(stage, 4.0)
	label.set_source("Paar: +4 Mult.")
	return label

func _keyword(label: LexikonText, id: String) -> Label:
	for piece in label._pieces:
		if piece.has_meta("id") and String(piece.get_meta("id")) == id:
			return piece
	return null

func test_keywords_are_their_own_targets_and_plain_text_is_deaf() -> void:
	var label := _text()
	assert_eq(label.source, "Paar: +4 Mult.")
	var mult := _keyword(label, Lexikon.MULT)
	assert_not_null(mult, "Mult ist ein eigenes Wort-Label")
	assert_eq(mult.mouse_filter, Control.MOUSE_FILTER_STOP, "das Wort nimmt den Zeiger")
	assert_eq(mult.get_theme_color("font_color"), CasinoStyle.LEXIKON_LINK)
	for piece in label._pieces:
		if not piece.has_meta("id"):
			assert_eq(piece.mouse_filter, Control.MOUSE_FILTER_IGNORE, "der Rest läßt durch")
	assert_eq(label.keyword_at(mult.get_global_rect().get_center()), Lexikon.MULT)

func test_hover_shows_the_one_sentence_card() -> void:
	var label := _text()
	var mult := _keyword(label, Lexikon.MULT)
	mult.mouse_entered.emit()
	assert_eq(label.hovered_id, Lexikon.MULT)
	assert_true(label.hint.visible, "die Karte erscheint beim Hover")
	assert_eq(label.hint.body_label.text, Lexikon.summary(Lexikon.MULT))
	mult.mouse_exited.emit()
	assert_false(label.hint.visible, "und nur beim Hover")

func test_click_on_a_keyword_requests_its_entry() -> void:
	var label := _text()
	watch_signals(label)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	_keyword(label, Lexikon.MULT).gui_input.emit(press)
	assert_signal_emitted_with_parameters(label, "entry_requested", [Lexikon.MULT])

func test_lines_break_and_punctuation_sticks_to_its_keyword() -> void:
	var label := _text()
	label.set_source("Jede gewertete 1 und 2: +5 Basispunkte, +2 Mult.")
	label.size = Vector2(60, 300)
	var basis := _keyword(label, Lexikon.BASISPUNKTE)
	var comma: Label = label._pieces[label._pieces.find(basis) + 1]
	assert_eq(comma.text, ",")
	assert_eq(comma.position.y, basis.position.y, "das Komma bleibt in der Zeile seines Worts")
	assert_gt(label.measure(60, label.font_px), label.measure(600, label.font_px), "schmal heißt mehr Zeilen")
