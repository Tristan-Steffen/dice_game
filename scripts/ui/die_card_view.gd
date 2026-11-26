class_name DieCardView
extends FaceCardView
## Die WÜRFEL-AUSKUNFT (Spieler-Wahl „C“ 2026-11-26): drei Fächer wie die Seiten-Auskunft -
## links die SEELE (Element-Kachel mit Kürzel und Ordnungszahl, Name, Seltenheit, Wirkung
## auf einer Platte), in der Mitte die SEITEN (je End-Ziffer eine Reihe aus sechs Feldern,
## so viele leuchten, wie oft sie vorkommt, jedes in der Farbe seines Materials), rechts
## SUMME und SCHNITT der Augen. `show_die` ist der EINE Schreiber, nur der Wechsel baut.

const SOUL_SHARE := 0.34
const STATS_SHARE := 0.24
const PIP_OFF := Color(0.18, 0.2, 0.34)
const PIP_PLAIN := Color(0.51, 0.55, 0.86)
const SOULLESS_BG := Color(0.13, 0.145, 0.27)

var _def: DieDefinition

## Der EINE Schreiber.
func show_die(def: DieDefinition) -> void:
	if def == null:
		_def = null
		_clear()
		_key = ""
		return
	var key := "die|%s|%s|%s|%s" % [def.essence_id, str(def.faces), str(def.materials),
		str(def.levels)]
	if key == _key:
		return
	_def = def.instantiate()
	_key = key
	_rebuild_from_key(key)

## Die Wirkung einer Seele, zerlegt in Wert, Art und Rest (die Worte von Essence.short).
## Ohne Zahl vorn spricht der ganze Satz.
static func effect_parts(short: String) -> Array:
	var tokens := short.split(" ", false, 1)
	if tokens.is_empty():
		return ["", KIND_PLAIN, ""]
	var first := tokens[0]
	var rest := tokens[1] if tokens.size() > 1 else ""
	if not first.contains("$") and first.to_int() == 0 and not first.contains("0"):
		return ["", KIND_PLAIN, short]
	if first.contains("$"):
		return [first, KIND_MONEY, rest]
	if first.contains("⚡"):
		return [first.replace("⚡", ""), KIND_ENERGY, ("Energie " + rest).strip_edges()]
	if rest.begins_with("Mult"):
		return [first, KIND_MULT, rest]
	if rest.begins_with("Krit") or first.begins_with("×"):
		return [first, KIND_CRIT, rest]
	if rest.begins_with("Basis"):
		return [first, KIND_BASE, rest]
	return [first, KIND_PLAIN, rest]

## Wie oft jede END-ZIFFER vorkommt (Spieler-Wunsch 2026-11-26: 8, 80008 und 233458 zählen
## alle als 8), von 0 bis 9: [[Ziffer, [Seiten…]], …].
static func face_groups(def: DieDefinition) -> Array:
	var by_value := {}
	for face in def.faces.size():
		var value := absi(int(def.faces[face])) % 10
		if not by_value.has(value):
			by_value[value] = []
		(by_value[value] as Array).append(face)
	var values := by_value.keys()
	values.sort()
	var out := []
	for value in values:
		out.append([value, by_value[value]])
	return out

## Der Schnitt je Seite in Worten ("3,7").
static func average_text(def: DieDefinition) -> String:
	var total := 0
	for value: int in def.faces:
		total += value
	var avg := float(total) / float(maxi(def.faces.size(), 1))
	if is_equal_approx(avg, roundf(avg)):
		return str(int(roundf(avg)))
	return ("%.1f" % avg).replace(".", ",")

func _rebuild_from_key(key: String) -> void:
	if not key.begins_with("die|"):
		super(key)
		return
	_clear()
	_key = key
	if _def == null or size.x <= 8.0 or size.y <= 8.0:
		return
	var gap := size.y / 30.0 * SLOT_GAP_UNITS
	var soul_w := size.x * SOUL_SHARE
	var stats_w := size.x * STATS_SHARE
	var faces_w := size.x - soul_w - stats_w - gap * 2.0
	_build_soul(Rect2(Vector2.ZERO, Vector2(soul_w, size.y)))
	_build_faces(Rect2(Vector2(soul_w + gap, 0.0), Vector2(faces_w, size.y)))
	_build_stats(Rect2(Vector2(soul_w + faces_w + gap * 2.0, 0.0), Vector2(stats_w, size.y)))

# --- Die Fächer ---------------------------------------------------------------

func _build_soul(rect: Rect2) -> void:
	var essence := Essence.by_id(_def.essence_id)
	if essence == null:
		var slot := _panel("Seele", rect, SOULLESS_BG, NUMBER_RIM, 3.0)
		_text(slot, "Name", WorkshopInfoView.SOULLESS, Rect2(Vector2(0, rect.size.y * 0.3),
			Vector2(rect.size.x, rect.size.y * 0.24)), Color.WHITE, true, rect.size.y * 0.22)
		_text(slot, "Was", "ohne Seele", Rect2(Vector2(0, rect.size.y * 0.54),
			Vector2(rect.size.x, rect.size.y * 0.14)), EMPTY_TEXT, false, rect.size.y * 0.1)
		return
	var glow := _peak_one(essence.glow)
	var slot := _panel("Seele", rect, Color(glow.r * 0.16, glow.g * 0.12, glow.b * 0.12),
		glow, 3.0)
	var pad := rect.size.x * 0.05
	var side := minf(rect.size.y * 0.3, rect.size.x * 0.36)
	var tile := _panel("Kachel", Rect2(Vector2(pad, pad), Vector2.ONE * side),
		Color(glow.r * 0.26, glow.g * 0.18, glow.b * 0.14), glow, 3.0, slot)
	_text(tile, "Ordnungszahl", str(Essence.number_of(essence.id)), Rect2(Vector2(side * 0.07,
		side * 0.04), Vector2(side * 0.5, side * 0.26)), glow, true, side * 0.22).horizontal_alignment \
		= HORIZONTAL_ALIGNMENT_LEFT
	# Das Kürzel in der Tisch-Schrift: die Würfel-Schrift kennt weder Tiefzahlen noch γ.
	_text(tile, "Kuerzel", Essence.symbol_of(essence.id), Rect2(Vector2(0, side * 0.26),
		Vector2(side, side * 0.66)), glow, false, side * 0.5)
	var beside := pad * 2.0 + side
	_text(slot, "Seltenheit", Essence.rarity_name(essence.rarity), Rect2(Vector2(beside,
		pad), Vector2(rect.size.x - beside - pad, side * 0.3)), EMPTY_TEXT, false,
		side * 0.24).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Der Name bekommt eine eigene Zeile über die ganze Breite - neben der Kachel las er klein.
	var name_h := rect.size.y * 0.15
	_text(slot, "Name", essence.display_name, Rect2(Vector2(pad, pad + side + pad * 0.3),
		Vector2(rect.size.x - pad * 2.0, name_h)), glow, false, name_h * 0.85) 		.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var parts := effect_parts(essence.short)
	var plate_top := pad * 1.6 + side + name_h
	var plate_rect := Rect2(Vector2(pad, plate_top), Vector2(rect.size.x - pad * 2.0,
		rect.size.y - plate_top - pad))
	var color := kind_color(String(parts[1])) if String(parts[0]) != "" else glow
	var plate := _panel("Platte", plate_rect, PLATE_BG, color, 3.0, slot)
	if String(parts[0]) == "":
		var line := _text(plate, "Wirkung", String(parts[2]), Rect2(Vector2(pad * 0.5, 0),
			Vector2(plate_rect.size.x - pad, plate_rect.size.y)), Color(0.89, 0.9, 0.96), false,
			plate_rect.size.y * 0.2)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", _wrapped_size(line, plate_rect.size.y * 0.2))
		return
	_text(plate, "Wert", String(parts[0]), Rect2(Vector2(0, plate_rect.size.y * 0.04),
		Vector2(plate_rect.size.x, plate_rect.size.y * 0.56)), color, true,
		plate_rect.size.y * 0.52)
	var rest := _text(plate, "Wirkung", String(parts[2]), Rect2(Vector2(pad * 0.5,
		plate_rect.size.y * 0.6), Vector2(plate_rect.size.x - pad, plate_rect.size.y * 0.36)),
		Color(0.89, 0.9, 0.96), false, plate_rect.size.y * 0.17)
	rest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rest.add_theme_font_size_override("font_size", _wrapped_size(rest, plate_rect.size.y * 0.17))

func _build_faces(rect: Rect2) -> void:
	var slot := _panel("Seiten", rect, RUNE_BG, NUMBER_RIM, 3.0)
	var groups := face_groups(_def)
	var pad := rect.size.y * 0.06
	var row_h := (rect.size.y - pad * 2.0) / float(maxi(groups.size(), 3))
	var top := pad + (rect.size.y - pad * 2.0 - row_h * float(groups.size())) * 0.5
	var label_w := rect.size.x * 0.3
	var cell := minf(row_h * 0.56, (rect.size.x - label_w - pad * 2.0) / 6.6)
	for i in groups.size():
		var value := int(groups[i][0])
		var faces: Array = groups[i][1]
		var y := top + row_h * float(i)
		_text(slot, "Augen%d" % i, str(value), Rect2(Vector2(pad * 0.5, y),
			Vector2(label_w, row_h)), Color.WHITE, true, row_h * 0.7)
		for k in 6:
			var fill := PIP_OFF
			if k < faces.size():
				var face := int(faces[k])
				var material_id := String(_def.materials[face])
				fill = DieMaterial.tint_for(material_id, _def.material_level(face)) \
					if material_id != "" else PIP_PLAIN
			var box := Rect2(Vector2(label_w + pad + float(k) * cell * 1.1,
				y + (row_h - cell) * 0.5), Vector2.ONE * cell)
			_panel("Feld%d_%d" % [i, k], box, fill, fill.darkened(0.35), 1.0, slot)

func _build_stats(rect: Rect2) -> void:
	var gap := rect.size.y * 0.05
	var high := (rect.size.y - gap) * 0.5
	var total := 0
	for value: int in _def.faces:
		total += value
	_stat("Summe", Rect2(rect.position, Vector2(rect.size.x, high)), str(total), "Augen gesamt")
	_stat("Schnitt", Rect2(rect.position + Vector2(0, high + gap), Vector2(rect.size.x, high)),
		average_text(_def), "Ø je Seite")

func _stat(stat_name: String, rect: Rect2, value: String, caption: String) -> void:
	var slot := _panel(stat_name, rect, NUMBER_BG, NUMBER_RIM, 3.0)
	_text(slot, "Wert", value, Rect2(Vector2(0, rect.size.y * 0.04),
		Vector2(rect.size.x, rect.size.y * 0.66)), Color.WHITE, true, rect.size.y * 0.56)
	_text(slot, "Einheit", caption, Rect2(Vector2(0, rect.size.y * 0.7),
		Vector2(rect.size.x, rect.size.y * 0.24)), Color(0.67, 0.7, 0.84), false,
		rect.size.y * 0.16)

## Der größte Grad bis top_px, in dem der umbrochene Text in sein Label paßt.
func _wrapped_size(label: Label, top_px: float) -> int:
	var font: Font = label.get_theme_font("font")
	var px := maxi(6, int(top_px))
	while px > 6 and ShopController.wrapped_height(font, label.text, label.size.x, px, 0) \
			> label.size.y:
		px -= 1
	return px
