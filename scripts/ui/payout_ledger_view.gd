class_name PayoutLedgerView
extends Control
## Die AUSZAHLUNGS-SEITE des Hubs (HubView.attach_panel, wie Laden und Lexikon):
## sie zeigt, WODURCH die Runde Geld einbringt, und zählt LIVE mit, während die
## Rundenende-Zeremonie bucht. Reine Anzeige - sie kennt GameRun nicht und faßt
## nichts an: scene_root MELDET neben jeder bestehenden Buchung.
## Eine Zeile entsteht bei ihrer ERSTEN Meldung (Reihenfolge = Zeremonie), jede
## weitere tickt sie hoch. Die ⚡-Zeile steht getrennt und zählt nicht mit.

## "Kassieren" gedrückt - erst danach macht der Laden auf.
signal cashout_pressed

## Ticken eines Betrags auf seinen neuen Stand.
const TICK_TIME := 0.3
## Goldenes Aufblitzen der Zeile beim Zuwachs.
const FLASH_TIME := 0.35
const FLASH_COLOR := Color(2.2, 1.9, 1.2)

## Zeilenhöhe in Fenster-Einheiten: 12 Zeilen plus ⚡ passen in die Hub-Höhe
## (4 feste Quellen + bis 5 Geld-Charms + 3 Wetten ist der Extremfall).
const ROW_HEIGHT_UNITS := 5.2
## Luft zwischen zwei Zeilen. Mit der Zeilenhöhe zusammen ist das der TAKT der Seite -
## die Namensliste der Ablage geht denselben.
const ROW_GAP_UNITS := 0.8
## Und die Zeile mit UNTERTITEL (die Wetten): Name oben, darunter ihre Bedingung.
const NOTE_ROW_HEIGHT_UNITS := 7.6
const NOTE_FONT_UNITS := 2.8

## Die ABLAGE zwischen GESAMT und Kassieren: links die Namen der gewonnenen Ware als
## Zeilen im Takt der Seite, RECHTS in ihrer Spalte (dort, wo oben die Beträge stehen)
## die Ware selbst - NEBENEINANDER auf EINER knappen Plattform, je Stück eine Zelle.
## Gemalt werden hier nur die NAMEN: die Ablage hat keine Fassung, und ist die Ware
## erst oben, steht kein Rest der Maschine mehr da. Die Körper gehören scene_root.
## Je Stück eine Zelle - so knapp, dass die Kassette hineinpaßt und sonst nichts.
const PLOT_CELL_UNITS := 9.0
const PLOT_HEIGHT_UNITS := 11.0
## Unterkante der Ablage über der Seitenunterkante - darunter steht der Knopf.
const PLOT_BOTTOM_UNITS := 17.0
const PLOT_RADIUS_UNITS := 0.7
## Seitenrand der Ablage - derselbe wie der Rand der Zeilenspalte.
const PLOT_MARGIN_UNITS := 6.0
## Luft zwischen der Namensspalte und der Ware rechts.
const PLOT_LABEL_GAP_UNITS := 1.6

## Flag statt nacktem Signal: die Warte-Schleife in scene_root pollt, damit ein
## Reset nicht auf ein Signal wartet, das nie kommt.
var cashout_requested := false

var round_label: Label
var charge_label: Label
var charge_value: Label
var total_value: Label
var cashout_button: Button

var _u := 10.0
var _built := false
var _rows_box: VBoxContainer
var _charge_row: Control
## id -> {"host": Control, "value": Label, "amount": int, "shown": float, "tween": Tween}
var _rows: Dictionary = {}
var _order: Array[String] = []
## Die gemeldete Ware in ihrer Reihenfolge (Zeilen-id und Name je Stück).
var _plot_ids: Array[String] = []
var _plot_labels: Array[String] = []
var _plot_layer: Control
var _plot_frames: Array[Control] = []
## Die gemessene Zeilenhöhe der Namen (einmal am echten Zeilen-Bauer genommen).
var _name_height := 0.0
var _money_total := 0
var _charge_total := 0
var _charge_tween: Tween
var _total_tween: Tween
var _total_shown := 0.0
var _charge_shown := 0.0

## Baut die Seite einmalig aus der (vom Hub gesetzten) Größe.
func layout() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_u = maxf(size.x, 1.0) / 100.0
	var u := _u

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(u * 6.0))
	margin.add_theme_constant_override("margin_right", int(u * 6.0))
	margin.add_theme_constant_override("margin_top", int(u * 4.0))
	margin.add_theme_constant_override("margin_bottom", int(u * 4.0))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 1.4))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var title := Label.new()
	title.text = "AUSZAHLUNG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(title, int(u * 6.4), CasinoStyle.GOLD)
	column.add_child(title)

	round_label = Label.new()
	round_label.text = ""
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_body_label(round_label, int(u * 3.0), CasinoStyle.MUTED)
	column.add_child(round_label)

	column.add_child(_rule(u))

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", int(u * ROW_GAP_UNITS))
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_rows_box)

	_charge_row = _build_row("⚡ Energie", CasinoStyle.CHARGE)
	_charge_row.visible = false
	charge_label = _charge_row.get_child(0) as Label
	charge_value = _charge_row.get_child(1) as Label
	column.add_child(_charge_row)

	column.add_child(_rule(u))

	var total_row := HBoxContainer.new()
	total_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(total_row)
	var total_name := Label.new()
	total_name.text = "GESAMT"
	total_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(total_name, int(u * 5.4), CasinoStyle.GOLD)
	total_row.add_child(total_name)
	total_value = Label.new()
	total_value.text = "0$"
	total_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(total_value, int(u * 8.0), CasinoStyle.GOLD_INTENSE)
	total_row.add_child(total_value)

	# Die Summe folgt den Zeilen (in der Übersicht ist nur das obere Drittel der
	# Seite im Bild); die Luft steht darunter, der Knopf an der Unterkante.
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(filler)

	cashout_button = Button.new()
	cashout_button.name = "CashoutButton"
	cashout_button.text = "Kassieren"
	cashout_button.visible = false
	cashout_button.focus_mode = Control.FOCUS_NONE
	cashout_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cashout_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cashout_button.custom_minimum_size = Vector2(u * 34.0, u * 9.0)
	cashout_button.add_theme_font_size_override("font_size", int(u * 4.2))
	CasinoStyle.style_primary_button(cashout_button, CasinoStyle.GOLD, u)
	cashout_button.pressed.connect(_on_cashout_pressed)
	column.add_child(cashout_button)

	# Der Ablage-Streifen liegt ÜBER der Spalte, nicht in ihr: sein Ort ist eine reine
	# Funktion der Seitengröße, sonst verschöbe ihn jede neue Zeile - und die Körper
	# darauf stünden dann woanders als das gemeldete Rechteck.
	_plot_layer = Control.new()
	_plot_layer.name = "Ablage"
	_plot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plot_layer)
	resized.connect(_lay_plots)  # der Streifen hängt an der Seitengröße, sonst an nichts

## Dünne Trennlinie im Neon-Ton der Seite.
func _rule(u: float) -> Control:
	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(0, maxf(1.0, u * 0.25))
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(CasinoStyle.GOLD.r, CasinoStyle.GOLD.g, CasinoStyle.GOLD.b, 0.35)
	rule.add_theme_stylebox_override("panel", box)
	return rule

## Eine Zeile: Beschriftung links, Betrag rechts. Feste Höhe, damit kein Text je
## eine Zeile verschiebt. Mit note trägt die linke Seite ZWEI Zeilen - Name oben, die
## Bedingung klein darunter (die Wetten); der Betrag steht rechts wie überall.
func _build_row(caption: String, tint: Color, note := "") -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0,
		_u * (NOTE_ROW_HEIGHT_UNITS if note != "" else ROW_HEIGHT_UNITS))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.text = caption
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_body_label(name_label, int(_u * 4.0), tint)
	if note == "":
		row.add_child(name_label)
	else:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 0)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.alignment = BoxContainer.ALIGNMENT_CENTER
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.size_flags_horizontal = Control.SIZE_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		block.add_child(name_label)
		var note_label := Label.new()
		note_label.name = "Bedingung"
		note_label.text = note
		note_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		note_label.clip_text = true
		note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		CasinoStyle.style_body_label(note_label, int(_u * NOTE_FONT_UNITS),
			CasinoStyle.MUTED)
		block.add_child(note_label)
		row.add_child(block)
	var value_label := Label.new()
	value_label.text = ""
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_body_label(value_label, int(_u * 4.4), tint)
	row.add_child(value_label)
	return row

# --- Melde-API (nur scene_root ruft sie) --------------------------------------

## Rundennummer im Kopf (0 = nichts).
func set_round(number: int) -> void:
	if round_label != null:
		round_label.text = "Runde %d" % number if number > 0 else ""

## Meldet GELD einer Quelle. Neue id = neue Zeile ganz unten, bekannte id tickt
## hoch. Beträge <= 0 legen keine Zeile an. note ist der Untertitel der Zeile (die
## Wetten tragen dort ihre BEDINGUNG) und gilt ab ihrer Geburt.
func add_money(id: String, caption: String, amount: int, note := "") -> void:
	if amount <= 0 or not _built:
		return
	var row: Dictionary = _rows.get(id, {})
	if row.is_empty():
		var host := _build_row(caption, CasinoStyle.CREAM, note)
		_rows_box.add_child(host)
		row = {"host": host, "value": host.get_child(1), "amount": 0, "shown": 0.0, "tween": null}
		_rows[id] = row
		_order.append(id)
	row["amount"] = int(row["amount"]) + amount
	_money_total += amount
	_tick_row(row, "+%d$")
	_flash(row["host"])
	_tick_total()

## Meldet ENERGIE (Bank-Entladung, Dynamo, ⚡-Wetten) - eigene Zeile, cyan, und
## sie fließt NICHT in die Geld-Summe.
func add_charge(amount: int) -> void:
	if amount <= 0 or not _built:
		return
	_charge_total += amount
	_charge_row.visible = true
	if _charge_tween != null and _charge_tween.is_valid():
		_charge_tween.kill()
	_charge_tween = _tick_label(charge_value, "⚡ +%d", _charge_shown, _charge_total)
	_charge_shown = float(_charge_total)
	_flash(_charge_row)

# --- Die ABLAGE der Gewinn-Körper ---------------------------------------------
# ui/ faßt nie einen Körper an: die Seite malt EINE Fassung samt Namensliste und
# MELDET Plattform und Zellen in Display-Pixeln - scene_root stellt darauf. Geld
# und ⚡ stehen oben als Zeilen und stellen nichts.

## Meldet die Waren-Plots: je Eintrag {"id": Zeilen-id, "label": Name der Ware},
## in dieser Reihenfolge. Leere Liste = keine Ablage, wie bisher.
func set_plots(entries: Array[Dictionary]) -> void:
	_plot_ids.clear()
	_plot_labels.clear()
	for entry in entries:
		_plot_ids.append(String(entry.get("id", "")))
		_plot_labels.append(String(entry.get("label", "")))
	_lay_plots()

func plot_count() -> int:
	return _plot_ids.size()

## Welcher Plot zu einer Zeilen-id gehört (-1 = keiner).
func plot_index(id: String) -> int:
	return _plot_ids.find(id)

## Die Waren-Namen in Plot-Reihenfolge (ablesbar für Tests).
func plot_labels() -> Array[String]:
	return _plot_labels.duplicate()

## Die EINE Plattform in FENSTER-eigenen Pixeln - reine Funktion aus Seitengröße und
## Anzahl, darum byte-stabil. Sie steht RECHTS in der Betrags-Spalte und ist nur so
## breit wie ihre Zellen; senkrecht sitzt sie mittig zur Namensliste daneben.
## Ohne Ware ein leeres Rechteck.
func payout_local_platform() -> Rect2:
	var count := _plot_ids.size()
	if count <= 0 or size.x <= 1.0 or size.y <= 1.0:
		return Rect2()
	var u := maxf(size.x, 1.0) / 100.0
	var deck := Vector2(u * PLOT_CELL_UNITS * float(count), u * PLOT_HEIGHT_UNITS)
	var bottom := size.y - u * PLOT_BOTTOM_UNITS
	# Die Namen daneben geben die Höhe des Blocks vor; die Plattform sitzt mittig davor.
	var block := maxf(deck.y, _name_line() * float(count))
	return Rect2(Vector2(size.x - u * PLOT_MARGIN_UNITS - deck.x,
		bottom - block + (block - deck.y) * 0.5), deck)

## Der Takt EINER Namenszeile: die Mindesthöhe der Zeilen-Schrift plus die
## (ganzzahlige) Fuge - dieselbe Regel, nach der die Geld-Zeilen oben stehen.
func _name_line() -> float:
	var u := maxf(size.x, 1.0) / 100.0
	if not _built:
		return u * (ROW_HEIGHT_UNITS + ROW_GAP_UNITS)  # ungebaut: die reine Rechnung
	if _name_height <= 0.0:
		var probe := _build_row("Wg", CasinoStyle.CREAM)
		add_child(probe)
		_name_height = probe.get_combined_minimum_size().y
		remove_child(probe)
		probe.queue_free()
	return _name_height + float(int(u * ROW_GAP_UNITS))

## Dieselbe Plattform in globalen Display-Pixeln - danach schneidet scene_root ihr Loch.
func payout_platform() -> Rect2:
	var rect := payout_local_platform()
	if rect.size.x <= 0.0:
		return rect
	return Rect2(global_position + rect.position, rect.size)

## Die ZELLEN auf der Plattform: je Stück Ware eine, nebeneinander in Melde-Reihenfolge.
## Auf ihrer Mitte sitzt der Körper.
func payout_local_cells() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var count := _plot_ids.size()
	var deck := payout_local_platform()
	if count <= 0 or deck.size.x <= 0.0:
		return out
	var cell := Vector2(deck.size.x / float(count), deck.size.y)
	for i in count:
		out.append(Rect2(deck.position + Vector2(cell.x * float(i), 0.0), cell))
	return out

func payout_cells() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for rect in payout_local_cells():
		out.append(Rect2(global_position + rect.position, rect.size))
	return out

## Die Eckenrundung, mit der das Loch geschnitten wird. Gemalt wird davon nichts -
## die Ablage hat keine Fassung.
func payout_plot_radius() -> float:
	return float(int(maxf(size.x, 1.0) / 100.0 * PLOT_RADIUS_UNITS))

## Malt allein die Waren-NAMEN, links neben der Ware: dasselbe Zeilenmaß und derselbe
## linke Rand wie "Benchmark" und "Übrige Würfel", damit die Seite EIN Schriftbild hat.
## KEINE Fassung: was da steht, ist der Körper, und ist er oben, steht nichts mehr da.
func _lay_plots() -> void:
	if _plot_layer == null or not is_instance_valid(_plot_layer):
		return
	for frame in _plot_frames:
		if is_instance_valid(frame):
			frame.queue_free()
	_plot_frames.clear()
	var deck := payout_local_platform()
	if deck.size.x <= 0.0:
		return
	var u := maxf(size.x, 1.0) / 100.0
	# Die Namen sind ZEILEN wie oben - gebaut vom SELBEN Bauer, nur ohne Betrag
	# rechts (den trägt die Ware selbst). So ist ihr Takt der Takt der Seite, ohne
	# eine zweite Rechnung.
	var names: Array[Control] = []
	for i in _plot_labels.size():
		var row := _build_row(_plot_labels[i], CasinoStyle.CREAM)
		row.name = "Ware%d" % i
		_plot_layer.add_child(row)
		_plot_frames.append(row)
		names.append(row)
	if names.is_empty():
		return
	var line := _name_line()
	var left := float(int(u * PLOT_MARGIN_UNITS))
	# Die Liste steht mittig zur Ware daneben und endet vor ihr.
	var top := deck.get_center().y - line * float(names.size()) * 0.5
	var width := maxf(deck.position.x - u * PLOT_LABEL_GAP_UNITS - left, u * 10.0)
	for i in names.size():
		names[i].position = Vector2(left, top + line * float(i))
		names[i].size = Vector2(width, line)

## Zeigt den Kassieren-Knopf: erst wenn nichts mehr zählt, gibt es etwas zu
## klicken.
func show_cashout() -> void:
	if cashout_button != null:
		cashout_button.visible = true

## Leert die Seite (neuer Auftritt, Abbruch, Laufwechsel).
func reset() -> void:
	cashout_requested = false
	if not _built:
		return
	for id: String in _rows:
		var row: Dictionary = _rows[id]
		var tween: Tween = row["tween"]
		if tween != null and tween.is_valid():
			tween.kill()
		var host: Control = row["host"]
		if is_instance_valid(host):
			host.queue_free()
	_rows.clear()
	_order.clear()
	set_plots([] as Array[Dictionary])
	_money_total = 0
	_charge_total = 0
	_total_shown = 0.0
	_charge_shown = 0.0
	if _charge_tween != null and _charge_tween.is_valid():
		_charge_tween.kill()
	if _total_tween != null and _total_tween.is_valid():
		_total_tween.kill()
	_charge_row.visible = false
	charge_value.text = ""
	total_value.text = "0$"
	cashout_button.visible = false
	cashout_button.disabled = false

# --- Ablesbar für Tests und scene_root ----------------------------------------

func money_total() -> int:
	return _money_total

func charge_total() -> int:
	return _charge_total

func money_of(id: String) -> int:
	var row: Dictionary = _rows.get(id, {})
	return int(row["amount"]) if not row.is_empty() else 0

## Die Zeilen in ihrer Melde-Reihenfolge.
func row_ids() -> Array[String]:
	return _order.duplicate()

# --- Tick-Mechanik ------------------------------------------------------------

func _tick_row(row: Dictionary, fmt: String) -> void:
	var tween: Tween = row["tween"]
	if tween != null and tween.is_valid():
		tween.kill()
	row["tween"] = _tick_label(row["value"], fmt, float(row["shown"]), int(row["amount"]))
	row["shown"] = float(row["amount"])

func _tick_total() -> void:
	if _total_tween != null and _total_tween.is_valid():
		_total_tween.kill()
	_total_tween = _tick_label(total_value, "%d$", _total_shown, _money_total)
	_total_shown = float(_money_total)

## Endzustand zuerst: der fertige Text steht, DANN läuft das Ticken dorthin -
## ein abgebrochener Tween schuldet nichts.
func _tick_label(label: Label, fmt: String, from_value: float, to_value: int) -> Tween:
	label.text = fmt % to_value
	if not is_inside_tree() or absf(from_value - float(to_value)) < 0.5:
		return null
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		label.text = fmt % roundi(v), from_value, float(to_value), TICK_TIME)
	tween.tween_callback(func() -> void: label.text = fmt % to_value)
	return tween

func _flash(node: Control) -> void:
	if node == null or not is_inside_tree():
		return
	node.modulate = FLASH_COLOR
	var tween := create_tween()
	tween.tween_property(node, "modulate", Color.WHITE, FLASH_TIME)

func _on_cashout_pressed() -> void:
	if cashout_requested:
		return
	cashout_requested = true
	cashout_button.disabled = true
	cashout_pressed.emit()
