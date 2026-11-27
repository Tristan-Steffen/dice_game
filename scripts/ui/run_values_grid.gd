class_name RunValuesGrid
extends Control
## Die LAUFWERTE der Hub-Startseite als Raster gleich großer Kacheln: Titel klein, Wert
## groß, darunter eine Zeile Zusatz. Ein weiterer Wert ist nur ein weiterer Eintrag in der
## Liste, die set_values bekommt; läuft das Raster über, rollt es senkrecht.

## Der Zeiger steht auf einer Kachel (der Hub zeigt ihren Hinweis).
signal tile_hovered(tile: Control, title: String, hint: String, color: Color)
signal tile_left

const COLUMNS := 3
## Maße in Einheiten u (die Einheit des Hubs).
const TILE_HEIGHT_UNITS := 9.8
const GAP_UNITS := 1.0
const PAD_UNITS := 0.9
const TITLE_UNITS := 2.0
const VALUE_UNITS := 3.4
const SUB_UNITS := 1.75
const TILE_BG := Color(0.07, 0.065, 0.16, 0.85)
const TITLE_COLOR := Color("#9a93c9")
const SUB_COLOR := Color("#b9b4dc")
const FLASH_TIME := 0.5

## Einheit in Display-px (der Hub meldet seine).
var unit_px := 10.0
var scroll := 0.0
## Je Kachel {key, title, text, sub, color, hint} in Reihenfolge.
var entries: Array[Dictionary] = []
var _tiles: Dictionary = {}  # key -> Panel

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_lay_out)

## Setzt alle Werte; neue Schlüssel bekommen eine Kachel, ein geänderter Wert blitzt kurz.
func set_values(values: Array) -> void:
	var keys: Array[String] = []
	var fresh: Array[Dictionary] = []
	for value: Dictionary in values:
		keys.append(String(value["key"]))
		fresh.append(value)
	for key: String in _tiles.keys():
		if not keys.has(key):
			(_tiles[key] as Node).queue_free()
			_tiles.erase(key)
	for entry in fresh:
		var key := String(entry["key"])
		if not _tiles.has(key):
			_tiles[key] = _make_tile(key)
		_write_tile(_tiles[key], entry)
	entries = fresh
	_lay_out()

func tile(key: String) -> Control:
	return _tiles.get(key)

func tile_height() -> float:
	return unit_px * TILE_HEIGHT_UNITS

func tile_width() -> float:
	var gap := unit_px * GAP_UNITS
	return maxf((size.x - gap * float(COLUMNS - 1)) / float(COLUMNS), 1.0)

func rows() -> int:
	return ceili(float(entries.size()) / float(COLUMNS))

func content_height() -> float:
	var n := rows()
	return 0.0 if n == 0 else float(n) * tile_height() + float(n - 1) * unit_px * GAP_UNITS

func max_scroll() -> float:
	var over := content_height() - size.y
	return over if over > 0.5 else 0.0  # Rundungsrest ist kein Überlauf

## Rollt um steps Kachel-Reihen (positiv = nach unten); true, wenn sich etwas bewegt hat.
func scroll_by(steps: float) -> bool:
	var before := scroll
	scroll = clampf(scroll + steps * (tile_height() + unit_px * GAP_UNITS), 0.0, max_scroll())
	_lay_out()
	return not is_equal_approx(before, scroll)

## Rechteck der i-ten Kachel in eigenen Koordinaten (vor dem Rollen).
func tile_rect(index: int) -> Rect2:
	var gap := unit_px * GAP_UNITS
	var col := index % COLUMNS
	var row := index / COLUMNS
	return Rect2(float(col) * (tile_width() + gap), float(row) * (tile_height() + gap),
		tile_width(), tile_height())

func _lay_out() -> void:
	scroll = clampf(scroll, 0.0, max_scroll())
	for i in entries.size():
		var panel: Control = _tiles.get(String(entries[i]["key"]))
		if panel == null:
			continue
		var rect := tile_rect(i)
		panel.position = rect.position - Vector2(0.0, scroll)
		panel.size = rect.size
		_lay_tile(panel)

func _make_tile(key: String) -> Panel:
	var panel := Panel.new()
	panel.name = "Tile_" + key
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := StyleBoxFlat.new()
	box.bg_color = TILE_BG
	box.set_corner_radius_all(int(unit_px * 0.8))
	panel.add_theme_stylebox_override("panel", box)
	for part in ["Title", "Value", "Sub"]:
		var label := CasinoStyle.label("", 12.0, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		label.name = part
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		panel.add_child(label)
	panel.mouse_entered.connect(func() -> void:
		var entry := _entry_of(key)
		tile_hovered.emit(panel, String(entry.get("title", "")), String(entry.get("hint", "")),
			entry.get("color", Color.WHITE)))
	panel.mouse_exited.connect(func() -> void: tile_left.emit())
	add_child(panel)
	return panel

func _entry_of(key: String) -> Dictionary:
	for entry in entries:
		if String(entry["key"]) == key:
			return entry
	return {}

func _write_tile(panel: Control, entry: Dictionary) -> void:
	var color: Color = entry.get("color", Color.WHITE)
	(panel.get_node("Title") as Label).text = String(entry.get("title", ""))
	var value := panel.get_node("Value") as Label
	var changed := value.text != "" and value.text != String(entry.get("text", ""))
	value.text = String(entry.get("text", ""))
	value.modulate = color
	(panel.get_node("Sub") as Label).text = String(entry.get("sub", ""))
	if changed and panel.is_inside_tree():
		value.modulate = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, color.a)
		panel.create_tween().tween_property(value, "modulate", color, FLASH_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Eine Schriftleiter für alle Kacheln: Titel, Wert, Zusatz untereinander.
func _lay_tile(panel: Control) -> void:
	var u := unit_px
	var pad := u * PAD_UNITS
	var w := panel.size.x - pad * 2.0
	var y := pad * 0.7
	for part: Array in [["Title", TITLE_UNITS, TITLE_COLOR], ["Value", VALUE_UNITS, null],
			["Sub", SUB_UNITS, SUB_COLOR]]:
		var label := panel.get_node(String(part[0])) as Label
		var px := int(u * float(part[1]))
		var font := label.get_theme_font("font")
		# Ein langer Wert wird kleiner, nie abgeschnitten (bis zum Zusatz-Grad).
		while font != null and px > int(u * SUB_UNITS) \
				and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w:
			px -= 1
		label.add_theme_font_size_override("font_size", px)
		if part[2] != null:
			label.modulate = part[2]
		var h := u * float(part[1]) * 1.25
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(pad, y)
		label.size = Vector2(w, h)
		y += h
