class_name LexikonText
extends Control
## Wirkungstext mit Lexikon-Verweisen, aus Wort-Labels gesetzt: Schlüsselwörter
## tragen die Link-Farbe und sind selbst Maus-Ziele (STOP), alles andere ist taub.
## Kein RichTextLabel-Meta: dessen Link-Hover springt bei den in die Tisch-Anzeige
## weitergereichten Ereignissen nie an (gemessen 2026-11-09), Knopf-Hover schon.

signal entry_requested(id: String)

## Der unmarkierte Quelltext.
var source := ""
## Eintrag unter dem Zeiger ("" = keiner).
var hovered_id := ""
var hint: HintCard
var font_px := 16
var color := Color.WHITE
var outline := 0
var outline_color := Color.BLACK
var center_h := false
var center_v := false
var _stage: Control
var _pieces: Array[Label] = []
var _words: Array = []  # je Wort: Array von {text, id}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	visibility_changed.connect(_drop_hover)
	tree_exiting.connect(_drop_hover)

func set_style(px: int, tint: Color, outline_px := 0, outline_tint := Color.BLACK) -> void:
	font_px = maxi(8, px)
	color = tint
	outline = outline_px
	outline_color = outline_tint
	_rebuild()

func set_source(text_in: String) -> void:
	source = text_in
	_drop_hover()
	_words = _split_words(text_in)
	_rebuild()

## Die Hover-Karte wohnt auf stage (sie darf über die eigene Fläche hinausragen).
func attach_hint(stage: Control, unit: float) -> void:
	var card := HintCard.new(unit)
	card.z_index = 10
	stage.add_child(card)
	share_hint(stage, card)

## Dieselbe, aber eine geteilte Karte (mehrere Texte einer Seite, eine Karte).
func share_hint(stage: Control, card: HintCard) -> void:
	_stage = stage
	hint = card

func text_font() -> Font:
	return get_theme_font("font", "Label")

## Höhe des gesetzten Texts bei width und px - dieselbe Zeilenregel wie _layout.
func measure(width: float, px: int) -> float:
	return _lines(width, px).size() * text_font().get_height(px)

## Liegt der (globale) Punkt auf einem Schlüsselwort?
func keyword_at(point: Vector2) -> String:
	for label in _pieces:
		if label.has_meta("id") and label.get_global_rect().has_point(point):
			return String(label.get_meta("id"))
	return ""

# --- Satz -------------------------------------------------------------------------

static func _split_words(text_in: String) -> Array:
	var words: Array = []
	var current: Array = []
	for span in Lexikon.spans(text_in):
		var id: String = span["id"]
		if id != "":
			current.append({"text": span["text"], "id": id})
			continue
		var chunk: String = span["text"]
		var buffer := ""
		for ch in chunk:
			if ch == " " or ch == "\n":
				if buffer != "":
					current.append({"text": buffer, "id": ""})
					buffer = ""
				if not current.is_empty():
					words.append(current)
					current = []
				if ch == "\n":
					words.append([{"text": "\n", "id": ""}])
			else:
				buffer += ch
		if buffer != "":
			current.append({"text": buffer, "id": ""})
	if not current.is_empty():
		words.append(current)
	return words

func _word_width(word: Array, font: Font, px: int) -> float:
	var w := 0.0
	for piece in word:
		w += font.get_string_size(piece["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	return w

## Zeilen als [{words, width}] - gierig umbrochen, \n erzwingt einen Umbruch.
func _lines(width: float, px: int) -> Array:
	var font := text_font()
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var lines: Array = []
	var line: Array = []
	var line_w := 0.0
	for word in _words:
		if word.size() == 1 and word[0]["text"] == "\n":
			lines.append({"words": line, "width": line_w})
			line = []
			line_w = 0.0
			continue
		var w := _word_width(word, font, px)
		var add := w if line.is_empty() else space + w
		if not line.is_empty() and line_w + add > width:
			lines.append({"words": line, "width": line_w})
			line = [word]
			line_w = w
		else:
			line.append(word)
			line_w += add
	if not line.is_empty():
		lines.append({"words": line, "width": line_w})
	return lines

func _rebuild() -> void:
	for label in _pieces:
		label.queue_free()
	_pieces.clear()
	for word in _words:
		for piece in word:
			if piece["text"] == "\n":
				continue
			var label := Label.new()
			label.text = piece["text"]
			label.add_theme_font_size_override("font_size", font_px)
			label.add_theme_color_override("font_color",
				CasinoStyle.LEXIKON_LINK if piece["id"] != "" else color)
			if outline > 0:
				label.add_theme_constant_override("outline_size", outline)
				label.add_theme_color_override("font_outline_color", outline_color)
			if piece["id"] != "":
				var id: String = piece["id"]
				label.set_meta("id", id)
				label.mouse_filter = Control.MOUSE_FILTER_STOP
				label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				label.mouse_entered.connect(_on_keyword_entered.bind(label))
				label.mouse_exited.connect(_on_keyword_exited.bind(label))
				label.gui_input.connect(_on_keyword_input.bind(label))
			else:
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(label)
			_pieces.append(label)
	_layout()

func _layout() -> void:
	if _pieces.is_empty():
		return
	var font := text_font()
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	var line_h := font.get_height(font_px)
	var lines := _lines(size.x, font_px)
	var y := (size.y - lines.size() * line_h) * 0.5 if center_v else 0.0
	var index := 0
	for line in lines:
		var x := (size.x - float(line["width"])) * 0.5 if center_h else 0.0
		var first := true
		for word in line["words"]:
			if not first:
				x += space
			first = false
			for piece in word:
				var label := _pieces[index]
				index += 1
				var w := font.get_string_size(piece["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
				label.position = Vector2(x, y)
				label.size = Vector2(w, line_h)
				x += w
		y += line_h

# --- Zeiger -----------------------------------------------------------------------

func _on_keyword_entered(label: Label) -> void:
	hovered_id = String(label.get_meta("id"))
	if hint == null or not is_instance_valid(hint) or _stage == null:
		return
	var e := Lexikon.entry(hovered_id)
	if e.is_empty():
		return
	var anchor := Rect2(label.global_position - _stage.global_position, label.size)
	hint.show_at(anchor, _stage.size, String(e["title"]), Lexikon.summary(hovered_id),
		CasinoStyle.LEXIKON_LINK, font_px * 0.4)

func _on_keyword_exited(label: Label) -> void:
	if hovered_id == String(label.get_meta("id")):
		_drop_hover()

func _on_keyword_input(event: InputEvent, label: Label) -> void:
	var press := event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	# Druck UND Loslassen schlucken, sonst kauft der Knopf darunter mit.
	label.accept_event()
	if press.pressed:
		entry_requested.emit(String(label.get_meta("id")))

func _drop_hover() -> void:
	if hovered_id == "":
		return
	hovered_id = ""
	if hint != null and is_instance_valid(hint):
		hint.hide_card()
