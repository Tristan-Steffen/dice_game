class_name RepairBayView
extends Panel
## Die REPARATUR-BUCHT - die Station RECHTS neben dem Werkstatt-Streifen, in
## derselben Zeile. Sie zeigt KEINE Körper, sondern NETZ-ZELLEN: je Vorrats-Würfel,
## der durchgebrannt ist oder Ladung trägt, eine Zeile in Vorrats-Reihenfolge -
## gezeichnet wie die Kacheln der Glas-Ansicht (DiceGridView.tile_box, EINE Quelle
## für Ladungs-Farbstufe und Ruß), daneben seine Vorrats-Nummer und EIN Knopf.
## Die Fußzeile trägt "Alle entladen" und die CAPTION.
##
## Grammatik wie FachNetView/WorkshopView: StyleBoxEmpty (die Bucht liegt auf dem
## Filz), unsichtbar geboren, statische Maß-Löser, idempotentes refresh per
## Signatur, sie MELDET Rechtecke - und sie faßt keinen Körper an und bucht nichts:
## jede Buchung liegt in GameRun, ausgelöst von scene_root.

## Der Spieler will diesen Würfel reparieren (durchgebrannt -> Ladung 0).
signal repair_requested(die: DieDefinition)
## ... oder ihn EINE Stufe ableiten.
signal drain_requested(die: DieDefinition)
## ... oder den ganzen Vorrat entladen.
signal discharge_all_requested
## Der Zeiger liegt auf einer Fall-Zelle (null = auf keiner).
signal case_hovered(die: DieDefinition)

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")
const TITLE := "REPARATUR"
const EMPTY_TEXT := "Keine Fälle"

## Die u-Konvention des Fensters plus ein Boden, unter den die Bucht nie fällt.
const UNIT_DIV := 100.0
const MIN_UNIT := 1.5
## Ränder, Kopfzeile, Fuge zwischen den Zeilen.
const MARGIN := 4.0
const HEADER_UNITS := 8.0
const HEADER_GAP := 1.6
const ROW_GAP := 1.6
## Eine Fall-Zeile: die Netz-Zelle, die Vorrats-Nummer, der Knopf.
const NET_CELL := 4.0
const NUMBER_WIDTH := 9.0
const COLUMN_GAP := 1.4
## GEMESSEN an der längsten Aufschrift ("Reparieren 1 ⚡"): schmaler schneidet
## clip_text sie ab.
const BUTTON_WIDTH := 58.0
const BUTTON_HEIGHT := 9.0
## Fußzeile: der Entladen-Knopf und darunter die CAPTION.
const FOOTER_GAP := 2.0
const FOOTER_HEIGHT := 9.0
const CAPTION_GAP := 1.0
const CAPTION_UNITS := 6.0
## So viele Zeilen paßt die Bucht in ihr gegebenes Rechteck ein; mehr Fälle lassen
## sie nach unten wachsen (bay_rect meldet es).
const FIT_ROWS := 4
## Schriftgrade (in u): Kopf, Zeilen-Nummer, Knopf, Caption.
const TITLE_STEP := 5.0
const NUMBER_STEP := 3.6
const BUTTON_STEP := 2.6
const CAPTION_STEP := 3.0

## Die GRÜNDE, aus denen ein Knopf grau steht - kurze Zeilen, sie teilen sich die
## Caption mit dem Hover-Hinweis.
const BLOCK_LOCKED := "Wartungsvertrag - Bucht geschlossen"
const BLOCK_ROUND := "Runde läuft"
const BLOCK_ENERGY := "Nicht genug Energie"
const BLOCK_MONEY := "Nicht genug Geld"

var run: GameRun
## Bedienbarkeit wie die Werkstatt (scene_root._dice_editing_locked() false).
var enabled := true

var _content: Control
var _caption: Label
var _cases: Array[DieDefinition] = []
## Zell-Rechtecke in FENSTER-Koordinaten (case_rects rechnet sie global).
var _case_rects: Array[Rect2] = []
## Was zuletzt gebaut wurde - nur der WECHSEL baut neu.
var _signature := ""
## Der Würfel unter dem Zeiger (null = keiner): er schreibt die Caption.
var _hovered: DieDefinition
## Wie hoch der gebaute Inhalt WIRKLICH steht (Knöpfe klemmen sich hoch) - daran
## mißt bay_rect, damit kein Klick unter der Kante durchfällt.
var _content_height := 0.0

func _init() -> void:
	name = "RepairBayWindow"
	visible = false
	# Die Bucht liegt auf dem Filz wie der Werkstatt-Streifen - kein Schirm.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Knöpfe fangen selbst

func _ready() -> void:
	refresh()

# --- Maße ------------------------------------------------------------------------

## Die u-Kette der festen Teile: Ränder, Kopfzeile samt Fuge, Fußzeile und Caption.
static func chrome_units() -> float:
	return MARGIN * 2.0 + HEADER_UNITS + HEADER_GAP + FOOTER_GAP + FOOTER_HEIGHT \
		+ CAPTION_GAP + CAPTION_UNITS

## Die Höhe EINER Fall-Zeile in u: das Netz oder der Knopf, was höher steht.
static func row_units() -> float:
	return maxf(DieNetView.net_size(NET_CELL).y, BUTTON_HEIGHT)

## Wie BREIT die Bucht bei dieser Einheit sein muß: Ränder, Netz, Nummer, Knopf
## und die beiden Fugen.
static func width_for(unit: float) -> float:
	return unit * (MARGIN * 2.0 + COLUMN_GAP * 2.0 + NUMBER_WIDTH + BUTTON_WIDTH) \
		+ DieNetView.net_size(unit * NET_CELL).x

## Wie HOCH die Bucht mit count Fällen steht (leer trägt sie EINE Zeile: den Satz
## "Keine Fälle").
static func height_for(unit: float, count: int) -> float:
	var rows := maxi(count, 1)
	return unit * (chrome_units() + row_units() * float(rows)
		+ ROW_GAP * float(rows - 1))

## Die Maßeinheit, bei der Chrome plus FIT_ROWS Zeilen in rect passen - so liest
## die Bucht in jedem Zuschnitt gleich, und eine längere Liste wächst nach unten.
static func unit_for(rect: Rect2) -> float:
	var by_height := rect.size.y / (chrome_units() + row_units() * float(FIT_ROWS)
		+ ROW_GAP * float(FIT_ROWS - 1))
	var by_width := rect.size.x / UNIT_DIV
	return maxf(minf(by_height, by_width), MIN_UNIT)

## Die Maßeinheit dieses Fensters: die u-Konvention aus der eigenen Breite.
func unit() -> float:
	return maxf(size.x, MIN_UNIT * UNIT_DIV) / UNIT_DIV

## Fenster ODER Liste, was länger ist: genau wie WorkshopView.bench_rect streckt
## sich die Bucht nach UNTEN, wenn die Fälle mehr Platz brauchen - sonst fiele ein
## Klick auf die unterste Zeile durch die eine Weiterleitungs-Region.
func bay_rect() -> Rect2:
	var rect := get_global_rect()
	rect.size.y = maxf(rect.size.y, maxf(_content_height,
		height_for(unit(), _cases.size())))
	return rect

## Die Zell-Rechtecke in DISPLAY-Pixeln, in Vorrats-Reihenfolge - die Ziele der
## Reparatur-Kometen.
func case_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var at := global_position
	for rect in _case_rects:
		out.append(Rect2(at + rect.position, rect.size))
	return out

## Die Fälle in der Reihenfolge, in der sie stehen (Vorrats-Reihenfolge).
func cases() -> Array[DieDefinition]:
	return _cases.duplicate()

# --- Zustand ---------------------------------------------------------------------

func set_run(new_run: GameRun) -> void:
	run = new_run
	_signature = ""
	refresh()

func set_enabled(on: bool) -> void:
	if enabled == on:
		return
	enabled = on
	refresh()

## Idempotent: nur der WECHSEL baut die Liste neu.
func refresh() -> void:
	if not is_inside_tree():
		return
	var wanted := _collect_cases()
	var signature := _signature_of(wanted)
	if signature == _signature and _content != null and is_instance_valid(_content):
		return
	_signature = signature
	_cases = wanted
	_build()

## Die Fälle: jeder Vorrats-Würfel, der durchgebrannt ist oder Ladung trägt.
func _collect_cases() -> Array[DieDefinition]:
	var out: Array[DieDefinition] = []
	if run == null:
		return out
	for die in run.owned_pool:
		if die != null and (die.burned_out or die.charge > 0):
			out.append(die)
	return out

func _signature_of(list: Array[DieDefinition]) -> String:
	var parts := PackedStringArray()
	for die in list:
		parts.append("%d:%d:%d" % [die.get_instance_id(), die.charge,
			1 if die.burned_out else 0])
	var money := run.money if run != null else 0
	var energy := run.energy if run != null else 0
	var locked := run != null and run.repair_locked()
	# Der PREIS gehört in die Signatur: das Isolierband tauscht ihn, ohne daß sich
	# am Vorrat etwas ändert.
	var price := str(run.repair_price()) if run != null else ""
	return "%s|%d|%d|%d|%d|%s|%dx%d" % [",".join(parts), money, energy,
		1 if locked else 0, 1 if enabled else 0, price, int(size.x), int(size.y)]

# --- Aufbau ----------------------------------------------------------------------

func _build() -> void:
	if _content != null and is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_content = null
	_caption = null
	_case_rects.clear()
	_content_height = 0.0
	# Ein Neuaufbau tötet die Zelle unter dem Zeiger, ohne daß sie es meldet.
	if _hovered != null and not _cases.has(_hovered):
		_hovered = null
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := unit()
	var content := Control.new()
	content.name = "BayContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	_content = content

	var margin := u * MARGIN
	var inner := maxf(size.x - margin * 2.0, 1.0)
	var y := margin
	_line(content, "Titel", Vector2(margin, y), Vector2(inner, u * HEADER_UNITS),
		u * TITLE_STEP, GOLD, HORIZONTAL_ALIGNMENT_LEFT).text = TITLE
	y += u * (HEADER_UNITS + HEADER_GAP)

	if _cases.is_empty():
		_line(content, "Leer", Vector2(margin, y), Vector2(inner, u * row_units()),
			u * NUMBER_STEP, MUTED_COLOR, HORIZONTAL_ALIGNMENT_LEFT).text = EMPTY_TEXT
		y += u * row_units()
	else:
		for i in _cases.size():
			var row_h := u * row_units()
			_build_case(content, _cases[i], Vector2(margin, y), Vector2(inner, row_h), u)
			y += row_h + u * ROW_GAP
		y -= u * ROW_GAP

	y += u * FOOTER_GAP
	var footer := _button(content, "Entladen", Vector2(margin, y),
		Vector2(inner, u * FOOTER_HEIGHT), u, _discharge_label())
	footer.disabled = not _discharge_live()
	footer.pressed.connect(func() -> void: discharge_all_requested.emit())
	# Ein Knopf klemmt sich an seiner Mindestgröße hoch: die CAPTION mißt an der
	# ECHTEN Höhe, sonst läge sie auf ihm.
	y += maxf(footer.size.y, u * FOOTER_HEIGHT) + u * CAPTION_GAP
	_caption = _line(content, "Caption", Vector2(margin, y),
		Vector2(inner, u * CAPTION_UNITS), u * CAPTION_STEP, MUTED_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT)
	_write_caption()
	_content_height = y + u * (CAPTION_UNITS + MARGIN)

## EINE Fall-Zeile: Netz-Zelle (mit Ladungs-Farbstufe bzw. Ruß), Vorrats-Nummer und
## der eine Knopf, den dieser Fall braucht.
func _build_case(host: Control, die: DieDefinition, at: Vector2, span: Vector2,
		u: float) -> void:
	var cell := u * NET_CELL
	var net_span := DieNetView.net_size(cell)
	var index := _case_rects.size() + 1
	var seat := Button.new()
	seat.name = "Fall%d" % index
	seat.focus_mode = Control.FOCUS_NONE
	seat.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var box := DiceGridView.tile_box(die, u, false)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		seat.add_theme_stylebox_override(state, box)
	seat.position = at
	seat.size = net_span
	seat.tooltip_text = DieNetView.hint_for(die, DieNetView.EDGE)
	seat.mouse_entered.connect(func() -> void: _set_hovered(die))
	seat.mouse_exited.connect(func() -> void: _set_hovered(null))
	host.add_child(seat)
	var net := DieNetView.build(die, -1, cell)
	if die.burned_out:
		net.modulate = DiceGridView.BURNED_NET_DIM
	seat.add_child(net)
	_case_rects.append(Rect2(at, net_span))

	var number_at := Vector2(at.x + net_span.x + u * COLUMN_GAP, at.y)
	var seat_index := run.owned_pool.find(die) if run != null else -1
	_line(host, "Nummer%d" % index, number_at, Vector2(u * NUMBER_WIDTH, span.y),
		u * NUMBER_STEP, TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER).text = \
			"#%d" % (seat_index + 1) if seat_index >= 0 else "-"

	var button_at := Vector2(number_at.x + u * (NUMBER_WIDTH + COLUMN_GAP),
		at.y + (span.y - u * BUTTON_HEIGHT) * 0.5)
	var burned := die.burned_out
	var button := _button(host, "Aktion%d" % index, button_at,
		Vector2(u * BUTTON_WIDTH, u * BUTTON_HEIGHT), u,
		repair_label() if burned else drain_label())
	button.disabled = not (repair_live(die) if burned else drain_live(die))
	if burned:
		button.pressed.connect(func() -> void: repair_requested.emit(die))
	else:
		button.pressed.connect(func() -> void: drain_requested.emit(die))

func _line(host: Control, line_name: String, at: Vector2, span: Vector2,
		font_size: float, tint: Color, align: int) -> Label:
	var label := Label.new()
	label.name = line_name
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.add_theme_color_override("font_color", tint)
	label.clip_text = true
	label.horizontal_alignment = align as HorizontalAlignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(label)
	label.position = at
	label.size = span
	return label

func _button(host: Control, button_name: String, at: Vector2, span: Vector2,
		u: float, text: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	CasinoStyle.style_button(button, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK,
		maxi(8, int(u * BUTTON_STEP)))
	host.add_child(button)
	button.position = at
	button.size = span
	button.custom_minimum_size = Vector2.ZERO
	return button

# --- Aufschriften und Bremsen ------------------------------------------------------

## Der Reparatur-Preis, wie ihn GameRun nennt - mit Isolierband kostet sie Geld.
func repair_label() -> String:
	var price := run.repair_price() if run != null else {"energy": GameRun.REPAIR_ENERGY}
	if price.has("money"):
		return "Reparieren $%d" % int(price["money"])
	return "Reparieren %d ⚡" % int(price["energy"])

func drain_label() -> String:
	return "Ableiten $%d" % GameRun.DRAIN_MONEY

func _discharge_label() -> String:
	return "Alle entladen %d ⚡" % GameRun.DISCHARGE_ALL_ENERGY

## Ist die Bucht überhaupt offen? Bedienbarkeit wie die Werkstatt, plus die Sperre
## des Wartungsvertrags.
func bay_open() -> bool:
	return run != null and enabled and not run.repair_locked()

func repair_live(die: DieDefinition) -> bool:
	if not bay_open() or die == null or not die.burned_out:
		return false
	var price := run.repair_price()
	if price.has("money"):
		return run.money >= int(price["money"])
	return run.energy >= int(price["energy"])

func drain_live(die: DieDefinition) -> bool:
	if not bay_open() or die == null or die.burned_out or die.charge <= 0:
		return false
	return run.money >= GameRun.DRAIN_MONEY

func _discharge_live() -> bool:
	if not bay_open() or run.energy < GameRun.DISCHARGE_ALL_ENERGY:
		return false
	for die in run.owned_pool:
		if die != null and not die.burned_out and die.charge > 0:
			return true
	return false

## WARUM ein FALL-Knopf schweigt ("" = keiner schweigt). Genannt wird die erste
## geschlossene Bremse - erst die Sperren, dann das fehlende Guthaben. Der
## Entladen-Knopf spricht bewußt NICHT mit: er steht grau da und nennt seinen
## Preis in der eigenen Aufschrift, sonst stünde die Zeile fast immer voll.
func bay_blocker() -> String:
	if run == null:
		return ""
	if not enabled:
		return BLOCK_ROUND
	if run.repair_locked():
		return BLOCK_LOCKED
	var wants_energy := false
	var wants_money := false
	var price := run.repair_price()
	for die in _cases:
		if die.burned_out:
			if price.has("money"):
				wants_money = wants_money or run.money < int(price["money"])
			else:
				wants_energy = wants_energy or run.energy < int(price["energy"])
		elif run.money < GameRun.DRAIN_MONEY:
			wants_money = true
	if wants_money:
		return BLOCK_MONEY
	if wants_energy:
		return BLOCK_ENERGY
	return ""

func caption_text() -> String:
	return _caption.text if _caption != null and is_instance_valid(_caption) else ""

## Der Zeiger schlägt den Grund: liegt er auf einer Zelle, spricht sie.
func _set_hovered(die: DieDefinition) -> void:
	if _hovered == die:
		return
	_hovered = die
	_write_caption()
	case_hovered.emit(die)

func _write_caption() -> void:
	if _caption == null or not is_instance_valid(_caption):
		return
	var text := DieNetView.hint_for(_hovered, DieNetView.EDGE) if _hovered != null \
		else bay_blocker()
	if _caption.text == text:
		return
	_caption.text = text
