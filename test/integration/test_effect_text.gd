extends GutTest

func _phrases(text: String) -> Array:
	var out := []
	for r: Dictionary in EffectText.ranges(text):
		out.append([text.substr(int(r["start"]), int(r["end"]) - int(r["start"])), r["kind"]])
	return out

func test_crit_phrase_takes_its_value() -> void:
	assert_eq(_phrases("Erstwertung der Runde kritet ×10"),
		[["kritet ×10", EffectText.KIND_CRIT]])
	assert_eq(_phrases("Jede Auslösung: Krit ×(1 + Fumbles der Runde)."),
		[["Krit ×(1 + Fumbles der Runde)", EffectText.KIND_CRIT]])
	assert_eq(_phrases("Augen negativ, Krit ×Augen"), [["Krit ×Augen", EffectText.KIND_CRIT]])
	assert_eq(_phrases("kritet ×1,5"), [["kritet ×1,5", EffectText.KIND_CRIT]])

func test_mult_and_base_phrases() -> void:
	assert_eq(_phrases("Jede gewertete 1 und 2: +5 Basispunkte, +2 Mult."),
		[["+5 Basispunkte", EffectText.KIND_BASE], ["+2 Mult", EffectText.KIND_MULT]])
	assert_eq(_phrases("+(Augenzahl) Mult."), [["+(Augenzahl) Mult", EffectText.KIND_MULT]])
	assert_eq(_phrases("×1,5 Mult."), [["×1,5 Mult", EffectText.KIND_MULT]])
	assert_eq(_phrases("+20 Basis +Augensumme"), [["+20 Basis", EffectText.KIND_BASE]])

func test_bare_words_color_but_compounds_do_not() -> void:
	assert_eq(_phrases("Krit ×2 auf den Mult, statt zu addieren."),
		[["Krit ×2", EffectText.KIND_CRIT], ["Mult", EffectText.KIND_MULT]])
	assert_eq(_phrases("Ein Multiplikator-Netz, Tscherenkow-Krits und Basis-Textur."), [])
	assert_eq(_phrases("Veredelte Seiten wirken doppelt."), [])

func test_bbcode_colors_only_the_phrase() -> void:
	var hex := EffectText.color_of(EffectText.KIND_CRIT).to_html(false)
	assert_eq(EffectText.bbcode("Runde [x] kritet ×10"),
		"Runde [lb]x] [color=#%s]kritet ×10[/color]" % hex)

func test_colorize_overlays_a_label() -> void:
	var label := Label.new()
	add_child_autofree(label)
	label.size = Vector2(300, 40)
	label.text = "Erstwertung der Runde kritet ×10"
	EffectText.colorize(label)
	var rich := EffectText.overlay_of(label)
	assert_not_null(rich)
	assert_true(rich.visible, "bunter Text steht über dem Label")
	assert_eq(label.self_modulate.a, 0.0, "das Label selbst schweigt")
	assert_eq(rich.get_parsed_text(), label.text)
	label.text = "Veredelte Seiten wirken doppelt."
	await wait_frames(2)
	assert_false(rich.visible, "ohne Phrase spricht das Label selbst")
	assert_eq(label.self_modulate.a, 1.0)

func test_lexikon_text_colors_pieces_by_kind() -> void:
	var words := LexikonText._split_words("Erstwertung der Runde kritet ×10")
	var kinds := {}
	for word: Array in words:
		for piece: Dictionary in word:
			kinds[piece["text"]] = piece["kind"]
	assert_eq(kinds.get("×10"), EffectText.KIND_CRIT)
	assert_eq(kinds.get("Runde"), "")
