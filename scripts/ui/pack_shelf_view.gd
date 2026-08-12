class_name PackShelfView
extends HBoxContainer
## Die Regal-Leiste der Werkbank: je Sorte EINE feste Bucht mit ihrem Stapel
## versiegelter Pakete - alle fünf stehen immer, gefüllt oder leer, damit auf der
## Grundseite nie etwas nachrückt. Der Stapel selbst liegt als KÖRPER auf dem Glas
## (DataCellView, aufgestellt von scene_root) - hier steht nur noch sein
## unsichtbarer Fußabdruck, und über einer leeren Bucht steht er trotzdem: er ist
## der Anker, auf den die nächste Lieferung einschlägt. Das ist die
## Chip-Schalen-Regel: kein Panel unter einem physischen Ding, aber der Knopf
## bleibt als Klick- und Überfahr-Ziel bestehen (StyleBoxEmpty in jedem Zustand),
## damit die vorhandene Maus-Weiterleitung der einzige Trefferweg bleibt.
## Reiner Renderer: gezählt wird in WorkshopView (dort liegen Vormerkungen und
## unterwegs befindliche Lieferungen), hier steht nur, was ankommt.

## Ein Stapel wurde angefasst: sein oberstes Paket wandert in den nächsten freien
## Presse-Platz - Würfel-Pakete öffnen stattdessen ihre Wahl.
signal stack_pressed(stack_category: String)

const GOLD := Color("#ffd319")

## Pseudo-Kategorie der Sonderposten (Engraving.SPECIAL_IDS) und der
## Würfel-Pakete: beide tragen keine Gravur-Kategorie, brauchen aber ihr Regal.
const CATEGORY_SPECIAL := "special"
const CATEGORY_DICE_PACK := "dice_pack"

## Kanonische Reihenfolge der Stapel - EINE Quelle für Leiste und Vormerkung.
const SHELF_ORDER := [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL,
	Engraving.CATEGORY_DICE, CATEGORY_DICE_PACK, CATEGORY_SPECIAL]

## Kategorie-Farbe wie das passende Siegel im Laden; data/ und ui/ spiegeln die
## Literale, statt sich gegenseitig zu importieren.
const COLORS := {
	Engraving.CATEGORY_NUMBER: Color("#50fa7b"),
	Engraving.CATEGORY_MATERIAL: Color("#ff79c6"),
	Engraving.CATEGORY_DICE: Color("#ffd319"),
	CATEGORY_DICE_PACK: Color("#8be9fd"),
	CATEGORY_SPECIAL: Color("#bd93f9"),
}

## Fußabdruck EINES Stapels, in Anteilen der liegenden Zelle: seitliche Greifluft
## und darüber der Kopfraum, in dem die goldene ×n-Marke über der obersten
## Kassette steht. Größer darf er nicht werden - ein Knopf, der weiter reicht als
## sein Ding, meldet beim Überfahren etwas, wo nichts liegt.
const STACK_SPAN := 1.35
const BADGE_ROOM := 0.45
## Rückfall-Zellhöhe (Einheiten u), solange niemand die echte Projektion gemeldet
## hat: der Fußabdruck steht dann wenigstens plausibel im Layout.
const CELL_FALLBACK := 5.0

## Das Segment: die SCHALE, in der ein Stapel liegt - erhabene Metall-Lippe um
## einen farbigen Metallgrund. Bewusste, in CLAUDE.md dokumentierte Ausnahme von
## der Regel "kein Panel unter einem physischen Ding": ein Sitz ist Möbel, kein
## Schild neben der Ware. Die Tiefe ist GEMALT, nicht gebaut - bei 15°/0°
## projiziert eine echte Kante fast nichts (die sin-15°-Lehre des Einschubs).
const SEGMENT_PAD := Vector2(0.18, 0.12)
const SEGMENT_RADIUS := 0.16
## Breite der Lippe und ihrer gemalten Kanten (Einheiten u). Jedes Band ist
## mindestens ZWEI Texturpixel breit: bei einem löst die weite Werkbank-Sicht es
## auf - dieselbe Messung, an der schon der alte Saum hing.
const LIP_WIDTH := 0.75
const LIP_EDGE := 0.33
## Der Innenschatten gleich innerhalb der Lippe - er IST die Tiefe. Oben am
## breitesten, weil das Licht von oben kommt und dort die Wand am tiefsten steht.
const WELL_SINK := 0.34
const WELL_SINK_TOP := 1.8

## Neutrales Dunkelmetall der Lippe mit einem Hauch Sortenfarbe, ihre Lichtkante
## und ihr Gegenschatten. Undurchsichtig: durch Blech scheint kein Filz.
const LIP_BASE := Color("#34313f")
const LIP_TINT := 0.12
const LIP_SHEEN := Color("#c9c6dd")
const LIP_SHEEN_MIX := 0.40
const LIP_SHADOW := Color(0.0, 0.0, 0.0, 0.72)
const WELL_SHADOW := Color(0.0, 0.0, 0.0, 0.58)
## Der Schlagschatten unter der Schale: er ist es, der sie aus der weiten Sicht
## noch als erhaben liest - dort verschwimmen die drei Pixel der Lichtkante, der
## Schatten in der Naht nicht. Nach unten versetzt, Licht kommt von oben.
const LIP_DROP := Color(0.0, 0.0, 0.0, 0.55)
const LIP_DROP_SIZE := 0.34
const LIP_DROP_DOWN := 0.22

## Der Grund der Schale: die Sortenfarbe als DUNKLES Metall. Erst ein Stich ins
## Stahlgraue (die Sorte ist Metall, kein Neon), dann in einen fast schwarzen
## Grund gemischt - vier Stufen von oben nach unten: Schatten unter der Lippe,
## Glanzband, satter Mittelton, dunklerer Boden. Alle bleiben unter dem Glühen
## einer ruhenden Kassette; sie ist das Helle in ihrer Schale.
const WELL_BASE := Color("#08070f")
const METAL_GREY := Color(0.62, 0.62, 0.68)
const METAL_MIX := 0.22
const WELL_STOPS := [0.0, 0.34, 0.62, 1.0]
## Gemessen an der Kassette, nicht gewählt: bei 0,42 Glanz stand der Grund im Bild
## so hell wie das Glühen der Zelle darin (Grün 130 gegen 146) - die Schale wurde
## zur Hauptsache. Ein Viertel darunter bleibt sie satt farbig und die Kassette
## das Hellste in ihrer Bucht.
const WELL_MIX := [0.07, 0.22, 0.155, 0.10]

## Zustände einer Schale: Greifen hebt sie, die Unterschrift dämpft sie ganz.
## Leer und gefüllt sehen gleich aus - der farbige Grund trägt die Sorte in
## beiden Fällen, die alte Saum-Unterscheidung ist damit erledigt.
const BAY_REST := Color(1.0, 1.0, 1.0)
const BAY_HOVER_LIFT := Color(1.28, 1.28, 1.28)
const BAY_LOCK_DIM := Color(0.42, 0.42, 0.46)

## Naht zwischen zwei Schalen: jede ist ein eigenes Ding, ihre Lippen dürfen sich
## nicht berühren. Aus der Streifenbreite abgeleitet und auf ganze Pixel
## abgerundet, damit die Buchten exakt so breit werden, wie der Kasten sie legt.
const BAY_GAP_SHARE := 0.0065
const BAY_GAP_MIN := 2.0

## Randluft IN der Bucht - der Stapel steht darin, er füllt sie nicht aus. Sie
## trägt die Lippe und ihren Innenschatten mit, sonst läge die Kassette darauf.
const BAY_INSET := 0.10
## Deckel der Anzeige-Vergrößerung der Regal-Kassetten: darüber überragten sie die
## Zwingen-Würfel, und das Regal wäre plötzlich die Hauptsache.
const SHELF_SCALE_MAX := 1.4

## Name einer Bucht, wenn sie leer ist - genannt wird die SORTE, nicht ihre Ware.
## Der Sonderbestand trägt keine Paketsorte, also nennt er sich selbst.
const BAY_NAME_SPECIAL := "Sonderbestand"
const BAY_EMPTY_BODY := "Diese Bucht ist leer."

## Gemeinsame Maßeinheit der Werkbank (setzt WorkshopView über build).
var u := 8.0
## Fußabdruck einer LIEGENDEN Datenzelle in Display-Pixeln (scene_root misst ihn
## an der Welt-Projektion, WorkshopView reicht ihn durch).
var cell_px := Vector2.ZERO
## Der Streifen, den WorkshopView der Leiste zumisst - das untere Viertel des
## Fensters (ZERO = keiner gemeldet, dann trägt der Fußabdruck wie früher).
var strip := Vector2.ZERO
## Kategorie -> Stapel-Knopf, in SHELF_ORDER gebaut.
var _chips: Dictionary = {}
## Kategorie -> gezeichnetes Segment (der Sitz des Stapels).
var _segments: Dictionary = {}
## Kategorien, die gerade wirklich Ware führen - alle anderen Buchten stehen leer.
var _stocked: Dictionary = {}
var _locked := false

func _init() -> void:
	name = "PackShelf"
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Baut die Leiste neu: JEDE Sorte aus SHELF_ORDER bekommt ihre Bucht, ob sie
## gerade Ware führt oder nicht. Feste Plätze sind die ganze Regel - eine
## erschöpfte Sorte leert ihre Bucht, sie nimmt sie nie weg, und darum verrückt
## weder ein Auslaufen noch eine Lieferung irgendetwas. Fünf Schalen und vier
## Nähte teilen sich die GANZE Zeilenbreite.
func build(entries: Array[Dictionary], unit: float, locked: bool,
		footprint := Vector2.ZERO, row := Vector2.ZERO) -> void:
	u = maxf(unit, 1.0)
	_locked = locked
	strip = row
	cell_px = footprint if footprint.x > 0.0 and footprint.y > 0.0 else _fallback_cell()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_chips.clear()
	_segments.clear()
	_stocked.clear()
	add_theme_constant_override("separation", int(bay_gap_for(strip)))
	custom_minimum_size = Vector2(0, segment_footprint().y)
	var stock := _stock_by_category(entries)
	for category: String in SHELF_ORDER:
		var entry: Dictionary = stock.get(category, {})
		var pack: Pack = entry.get("pack")
		var count := int(entry.get("count", 0))
		var stocked := pack != null and count > 0
		var column := CenterContainer.new()
		column.name = "StackColumn"
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var segment := _segment(category)
		column.add_child(segment)
		var chip := _stack_button(category, pack, count, stocked)
		column.add_child(chip)
		add_child(column)
		_chips[category] = chip
		_segments[category] = segment
		if stocked:
			_stocked[category] = true

## Die gemeldeten Einträge nach Sorte - der Aufbau geht über SHELF_ORDER, nicht
## über den Bestand.
func _stock_by_category(entries: Array[Dictionary]) -> Dictionary:
	var stock := {}
	for entry in entries:
		var category := String(entry.get("category", ""))
		if category != "":
			stock[category] = entry
	return stock

## Führt diese Bucht gerade Ware?
func bay_stocked(stack_category: String) -> bool:
	return _stocked.has(stack_category)

## Der Fußabdruck EINES Stapels: die liegende Zelle plus Greifluft und Kopfraum
## für ihre Marke - im Anzeige-Maßstab der Bucht.
func stack_footprint() -> Vector2:
	return base_stack_footprint(cell_px) * cell_scale()

## Derselbe Fußabdruck bei Maßstab 1 - die Bezugsgröße, an der die Vergrößerung
## gemessen wird (sonst hinge sie an sich selbst).
static func base_stack_footprint(cell: Vector2) -> Vector2:
	return Vector2(cell.x * STACK_SPAN, cell.y * (1.0 + BADGE_ROOM))

## Der Sitz darum herum. Mit gemeldetem Streifen ist er ein DOCK: volle
## Streifenhöhe, Breite gedeckelt auf Hochformat. Ohne ihn (Rückfall) reicht er
## wie früher knapp über den Griff hinaus.
func segment_footprint() -> Vector2:
	if strip.x > 0.0 and strip.y > 0.0:
		return bay_size_for(strip)
	var stack := base_stack_footprint(cell_px)
	return Vector2(stack.x * (1.0 + SEGMENT_PAD.x), stack.y * (1.0 + SEGMENT_PAD.y))

## Maße einer Bucht im gemeldeten Streifen: die volle Streifenhöhe, in der Breite
## ihr Anteil an dem, was nach den vier Nähten übrig bleibt - fünf Schalen und
## vier Lücken ergeben den ganzen Streifen.
static func bay_size_for(row: Vector2) -> Vector2:
	var bays := float(SHELF_ORDER.size())
	return Vector2((row.x - bay_gap_for(row) * (bays - 1.0)) / bays, row.y)

## Die Naht zwischen zwei Schalen, in ganzen Pixeln (ohne Streifen: das Minimum).
static func bay_gap_for(row: Vector2) -> float:
	return maxf(BAY_GAP_MIN, floorf(row.x * BAY_GAP_SHARE))

## Anzeige-Maßstab der Regal-Kassetten: die Bucht ist der ganze untere Streifen,
## eine Kassette in Würfelgröße läge verloren darin. REINE Darstellung - Schlitz,
## Einschub und Steckplatz bleiben bei 1 (scene_root skaliert nur die Stapel).
func cell_scale() -> float:
	return cell_scale_for(cell_px, strip)

static func cell_scale_for(cell: Vector2, row: Vector2) -> float:
	if row.x <= 0.0 or row.y <= 0.0:
		return 1.0
	var base := base_stack_footprint(cell)
	if base.x <= 0.0 or base.y <= 0.0:
		return 1.0
	var room := bay_size_for(row) * (1.0 - BAY_INSET * 2.0)
	return clampf(minf(room.x / base.x, room.y / base.y), 1.0, SHELF_SCALE_MAX)

## Die liegende Zelle, wie sie im Regal WIRKLICH erscheint.
func scaled_cell_px() -> Vector2:
	return cell_px * cell_scale()

## Das Segment einer Sorte (nie null: jede Sorte hat ihre Bucht).
func segment_of(stack_category: String) -> Panel:
	var seat: Panel = _segments.get(stack_category)
	return seat if seat != null and is_instance_valid(seat) else null

## Der Grund einer Schale - der farbige Metallverlauf, an dem ihre Sorte hängt.
func well_of(stack_category: String) -> TextureRect:
	var seat := segment_of(stack_category)
	if seat == null:
		return null
	return seat.get_node_or_null("WellWash") as TextureRect

## Die gezeichnete Schale: erhabene Lippe um einen farbigen Metallgrund. Kein
## Zeichen, keine Schrift - der Grund trägt die Sorte, gefüllt wie leer; der Name
## steht auf der Hinweiskarte, das Siegel auf der Kassette.
func _segment(category: String) -> Panel:
	var seat := Panel.new()
	seat.name = "StackSegment"
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seat.custom_minimum_size = segment_footprint()
	seat.add_theme_stylebox_override("panel", _lip_box(category))
	seat.add_child(_well_wash(category))
	seat.add_child(_well_sink())
	seat.add_child(_lip_ring(category))
	seat.add_child(edge_band("LipLight", _lip_sheen(category), _edge_px(), _radius_px(), true))
	seat.add_child(edge_band("LipShade", LIP_SHADOW, _edge_px(), _radius_px(), false))
	seat.modulate = BAY_LOCK_DIM if _locked else BAY_REST
	return seat

func _lip_px() -> int:
	return maxi(2, int(u * LIP_WIDTH))

func _edge_px() -> int:
	return maxi(2, int(u * LIP_EDGE))

func _radius_px() -> int:
	return int(segment_footprint().y * SEGMENT_RADIUS)

## Sortenfarbe als Metall: ein Stich ins Stahlgraue nimmt ihr das Neon.
static func sort_metal(stack_category: String) -> Color:
	var sort: Color = COLORS.get(stack_category, GOLD)
	return sort.lerp(METAL_GREY, METAL_MIX)

## Eine Stufe des Schalengrunds - EINE Quelle für Verlauf und Prüfung.
static func well_color(stack_category: String, mix: float) -> Color:
	var tone := WELL_BASE.lerp(sort_metal(stack_category), mix)
	return Color(tone.r, tone.g, tone.b, 1.0)

## Der Verlauf im Grund: Schatten unter der Lippe, Glanzband, satter Mittelton,
## dunklerer Boden - senkrecht, weil das Licht von oben kommt.
static func well_gradient(stack_category: String) -> GradientTexture2D:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in WELL_STOPS.size():
		offsets.append(float(WELL_STOPS[i]))
		colors.append(well_color(stack_category, float(WELL_MIX[i])))
	var ramp := Gradient.new()
	ramp.offsets = offsets
	ramp.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 8
	texture.height = 96
	return texture

## Eine gemalte Kante: Lichtband oben ODER Schattenband unten, gerundet wie das
## Blech, auf dem es liegt. Die EINE Rezeptur der gemalten Tiefe - Regal-Schale
## wie Schlitz-Konsole holen sie hier.
static func edge_band(band_name: String, tint: Color, edge: int, radius: int,
		top: bool) -> Panel:
	var band := Panel.new()
	band.name = band_name
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = tint
	if top:
		box.border_width_top = edge
	else:
		box.border_width_bottom = edge
	box.set_corner_radius_all(radius)
	band.add_theme_stylebox_override("panel", box)
	return band

func _lip_color(category: String) -> Color:
	return LIP_BASE.lerp(sort_metal(category), LIP_TINT)

func _lip_sheen(category: String) -> Color:
	return _lip_color(category).lerp(LIP_SHEEN, LIP_SHEEN_MIX)

func _lip_box(category: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _lip_color(category)
	box.set_corner_radius_all(_radius_px())
	box.shadow_color = LIP_DROP
	box.shadow_size = maxi(2, int(u * LIP_DROP_SIZE))
	box.shadow_offset = Vector2(0.0, maxf(2.0, u * LIP_DROP_DOWN))
	return box

func _well_wash(category: String) -> TextureRect:
	var wash := TextureRect.new()
	wash.name = "WellWash"
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset(wash, _lip_px())
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.texture = well_gradient(category)
	return wash

## Der Innenschatten am Lippenfuß - das eigentliche Tiefensignal.
func _well_sink() -> Panel:
	var sink := Panel.new()
	sink.name = "WellSink"
	sink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset(sink, _lip_px())
	var band := maxi(2, int(u * WELL_SINK))
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = WELL_SHADOW
	box.border_width_left = band
	box.border_width_right = band
	box.border_width_bottom = band
	box.border_width_top = maxi(2, int(float(band) * WELL_SINK_TOP))
	box.set_corner_radius_all(maxi(0, _radius_px() - _lip_px()))
	sink.add_theme_stylebox_override("panel", box)
	return sink

## Der Ring der Lippe, ÜBER dem Grund: seine gerundete Innenkante schneidet den
## rechteckigen Verlauf zur Schale - clip_contents rundet nicht.
func _lip_ring(category: String) -> Panel:
	var ring := Panel.new()
	ring.name = "LipRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = _lip_color(category)
	box.set_border_width_all(_lip_px())
	box.set_corner_radius_all(_radius_px())
	ring.add_theme_stylebox_override("panel", box)
	return ring

func _inset(node: Control, margin: int) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.offset_left = margin
	node.offset_top = margin
	node.offset_right = -margin
	node.offset_bottom = -margin

## Der Zeiger liegt auf einer gefüllten Schale: sie hebt sich als Ganzes - Lippe
## und Grund zugleich. Gemeldet vom Griff, der ohnehin jeden Klick fängt; über
## einer leeren Bucht bleibt es aus, dort ist nichts zu greifen.
func _set_segment_hover(category: String, on: bool) -> void:
	var seat := segment_of(category)
	if seat == null or _locked or not _stocked.has(category):
		return
	seat.modulate = BAY_HOVER_LIFT if on else BAY_REST

func _fallback_cell() -> Vector2:
	return fallback_cell(u)

static func fallback_cell(unit: float) -> Vector2:
	return Vector2(unit * CELL_FALLBACK * 2.0 / 3.0, unit * CELL_FALLBACK)

## Der unsichtbare Griff eines Stapels: er trägt keinen Rahmen, kein Siegel und
## keine Zahl - all das liegt als Körper auf dem Glas. Er fängt nur Klick und
## Zeiger, wie die Einzelstücke in der Chip-Schale des Ladens. Über einer leeren
## Bucht fängt er keinen Klick, NENNT aber seine Sorte: das ist Auskunft über den
## Platz, keine Führung - und er hält den Anker der nächsten Lieferung.
func _stack_button(category: String, pack: Pack, count: int, stocked: bool) -> Button:
	var chip := Button.new()
	chip.name = "PackStack"
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = stack_footprint()
	chip.disabled = _locked or not stocked
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		chip.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if not stocked:
		chip.set_meta("title", bay_name(category))
		chip.set_meta("body", BAY_EMPTY_BODY)
		return chip
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.tooltip_text = "%s\n%s" % [pack.display_name, pack.description]
	chip.set_meta("title", "%d × %s" % [count, pack.display_name])
	chip.set_meta("body", pack.description)
	chip.pressed.connect(func() -> void: stack_pressed.emit(category))
	chip.mouse_entered.connect(_set_segment_hover.bind(category, true))
	chip.mouse_exited.connect(_set_segment_hover.bind(category, false))
	return chip

## Der Knopf einer Bucht (nie null: jede Sorte hat ihre eigene).
func stack_button(stack_category: String) -> Button:
	var chip: Button = _chips.get(stack_category)
	return chip if chip != null and is_instance_valid(chip) else null

## Display-Pixel eines Stapels (Ziel der Liefer-Kometen und Standplatz seines
## Körpers). Er steht auch über einer LEEREN Bucht - genau dorthin ploppt die
## nächste Lieferung. Nicht die Mitte des Fußabdrucks: die Zelle liegt in seinem
## UNTEREN Band, der Kopfraum darüber gehört der Marke.
func stack_anchor_px(stack_category: String) -> Vector2:
	var chip := stack_button(stack_category)
	if chip == null:
		return Vector2(-1, -1)
	var rect := chip.get_global_rect()
	return Vector2(rect.get_center().x, rect.end.y - scaled_cell_px().y * 0.5)

## Derselbe Standplatz, GERECHNET statt gemessen: aus dem Streifen, in dem die
## Leiste liegt, ihrer Sorte und dem Zellmaß. Das ist der Weg, wenn gerade keine
## Leiste steht (Presse, Paket-Wahl) - dieselbe Formel, die der Knopf oben
## abmisst, damit ein Liefer-Komet nicht springt, sobald das Regal zurückkommt.
static func stack_anchor_in(row: Rect2, stack_category: String,
		cell: Vector2) -> Vector2:
	var index := SHELF_ORDER.find(stack_category)
	if index < 0 or row.size.x <= 0.0 or row.size.y <= 0.0:
		return Vector2(-1, -1)
	var bay := bay_size_for(row.size)
	var left := row.position.x + (bay.x + bay_gap_for(row.size)) * float(index)
	var scale := cell_scale_for(cell, row.size)
	# Der Griff sitzt mittig in seiner Bucht; die Zelle liegt in seinem unteren
	# Band, darüber steht der Kopfraum der Marke.
	var stack := base_stack_footprint(cell) * scale
	var bottom := row.position.y + (row.size.y + stack.y) * 0.5
	return Vector2(left + bay.x * 0.5, bottom - cell.y * scale * 0.5)

## Name und Wirkung dessen, was unter pixel liegt ({} = keine Bucht dort). Eine
## leere Bucht nennt ihre SORTE - Auskunft über den Platz. GEFRAGT statt gemeldet:
## der Zeiger liegt auf dem Tisch, ein mouse_exited käme nie an.
func hint_at(pixel: Vector2) -> Dictionary:
	if not visible:
		return {}
	for category: String in _chips:
		var chip: Button = _chips[category]
		if not is_instance_valid(chip) or not chip.has_meta("title"):
			continue
		if not chip.get_global_rect().has_point(pixel):
			continue
		return {"title": String(chip.get_meta("title", "")),
			"body": String(chip.get_meta("body", ""))}
	return {}

# --- Taxonomie: welches Paket liegt auf welchem Stapel --------------------------

## Ein Fixinhalt-Paket mit Sonderposten gehört ins Sonderbestand-Regal.
## Würfel-Pakete haben ihr eigenes, alles andere zählt zu seiner Gravur-Sorte.
static func pack_belongs(pack: Pack, stack_category: String) -> bool:
	if pack == null:
		return false
	if pack.is_dice_pack():
		return stack_category == CATEGORY_DICE_PACK
	var fixed := pack.fixed_engraving
	if fixed != null and Engraving.is_special_id(fixed.id):
		return stack_category == CATEGORY_SPECIAL
	return pack.engraving_category() == stack_category

## Der Stapel, auf dem dieses Paket liegt ("" = keiner).
static func shelf_of(pack: Pack) -> String:
	for stack_category: String in SHELF_ORDER:
		if pack_belongs(pack, stack_category):
			return stack_category
	return ""

## Die Umkehrung: der Pakettyp, dessen Siegel diese Sorte zeichnet ("" = der
## Sonderbestand, dessen Zeichen der Eckrahmen ist). EINE Zuordnung, in beide
## Richtungen gelesen - eine zweite Tabelle liefe auseinander.
static func pack_type_of(stack_category: String) -> String:
	for pack_type: String in [Pack.TYPE_DICE, Pack.TYPE_NUMBER, Pack.TYPE_MATERIAL,
			Pack.TYPE_DICE_MOD]:
		if shelf_category_for_pack_type(pack_type) == stack_category:
			return pack_type
	return ""

## Der Name einer Bucht: die Paketsorte, die dort wohnt. Er kommt aus Pack, damit
## Regal und Laden dasselbe Wort benutzen.
static func bay_name(stack_category: String) -> String:
	if stack_category == CATEGORY_SPECIAL:
		return BAY_NAME_SPECIAL
	return String(Pack.TYPE_NAMES.get(pack_type_of(stack_category), stack_category))

## Stapel, in dem ein Paket dieser Sorte landet (Lieferweg des Ladens - dort ist
## nur der Typ bekannt, nie ein Fixinhalt).
static func shelf_category_for_pack_type(pack_type: String) -> String:
	match pack_type:
		Pack.TYPE_DICE:
			return CATEGORY_DICE_PACK
		Pack.TYPE_MATERIAL:
			return Engraving.CATEGORY_MATERIAL
		Pack.TYPE_DICE_MOD:
			return Engraving.CATEGORY_DICE
	return Engraving.CATEGORY_NUMBER
