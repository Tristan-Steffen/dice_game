class_name RepairBayView
extends Panel
## Die REPARATUR-BUCHT - die Station RECHTS neben dem Werkstatt-Streifen, in
## derselben Zeile. Sie hat EINEN Kunden: den ZIELWÜRFEL auf dem Podest
## (Spieler-Entscheid 2026-09-07; die Liste aller Fälle ist tot). Sie zeigt KEINEN
## Körper und seit 2026-09-07 auch keine Netz-Zelle mehr (Spieler: nutzlos - der
## Würfel schwebt eine Spalte weiter links): seine Vorrats-Nummer im Kopf, die
## LADUNGS-LEITER (die drei Ladungs-Lampen des Netzes in groß) und darunter
## SENKRECHT die drei Handlungen, IMMER alle drei: "Aufladen 1 ⚡", "Ableiten $5",
## "Reparieren 3 ⚡" - was der Kunde nicht braucht, steht grau. Zuunterst die CAPTION.
##
## Grammatik wie FachNetView/WorkshopView: StyleBoxEmpty (die Bucht liegt auf dem
## Filz), unsichtbar geboren, statische Maß-Löser, idempotentes refresh per
## Signatur, sie MELDET Rechtecke - und sie faßt keinen Körper an und bucht nichts:
## jede Buchung liegt in GameRun, ausgelöst von scene_root.

## Der Spieler will den Zielwürfel reparieren (durchgebrannt -> Ladung 0) ...
signal repair_requested(die: DieDefinition)
## ... ihn EINE Stufe ableiten ...
signal drain_requested(die: DieDefinition)
## ... oder EINE Stufe aufladen.
signal charge_requested(die: DieDefinition)

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")
const TITLE := "REPARATUR"
const EMPTY_TEXT := "Wähle einen Würfel im Vorrat"
## Die Warnung vor der letzten Sprosse: wer auf 3 geht, spielt ums Durchbrennen.
const WARN_TOP := "Bei 3 brennt die nächste Zündung durch"

## Ein Boden, unter den die Einheit der Bucht nie fällt.
const MIN_UNIT := 1.5
## Ränder, Kopfzeile, Fugen.
const MARGIN := 4.0
const HEADER_UNITS := 8.0
const HEADER_GAP := 1.6
const ROW_GAP := 1.6
## Die Leiter und die drei Knöpfe darunter. GEMESSEN an der längsten Aufschrift
## ("Reparieren 3 ⚡"): schmaler schneidet clip_text sie ab.
const LADDER_HEIGHT := 9.0
const BUTTON_WIDTH := 58.0
const BUTTON_HEIGHT := 9.0
const CAPTION_GAP := 2.0
const CAPTION_UNITS := 8.0  # zwei Zeilen: die Bucht ist schmal, die Warnung lang
## Schriftgrade (in u): Kopf, Knopf, Caption.
const TITLE_STEP := 5.0
const BUTTON_STEP := 2.6
const CAPTION_STEP := 3.0

## Die GRÜNDE, aus denen ein Knopf grau steht - kurze Zeilen in der Caption.
const BLOCK_LOCKED := "Wartungsvertrag - Bucht geschlossen"
const BLOCK_ROUND := "Runde läuft"
const BLOCK_ENERGY := "Nicht genug Energie"
const BLOCK_MONEY := "Nicht genug Geld"

var run: GameRun
## Der Kunde: der Zielwürfel auf dem Podest (null = keiner).
var target: DieDefinition
## Bedienbarkeit wie die Werkstatt (scene_root._dice_editing_locked() false).
var enabled := true

var _content: Control
var _caption: Label
## Die Leiter in FENSTER-Koordinaten (das Ziel der Kometen).
var _ladder_rect := Rect2()
## Was zuletzt gebaut wurde - nur der WECHSEL baut neu.
var _signature := ""

func _init() -> void:
	name = "RepairBayWindow"
	visible = false
	# Die Bucht liegt auf dem Filz wie der Werkstatt-Streifen - kein Schirm.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Knöpfe fangen selbst

func _ready() -> void:
	refresh()

# --- Maße ------------------------------------------------------------------------

## Die u-Kette der Höhe: Ränder, Kopfzeile, Leiter, drei Knöpfe mit Fugen, Caption.
static func height_units() -> float:
	return MARGIN * 2.0 + HEADER_UNITS + HEADER_GAP + LADDER_HEIGHT + ROW_GAP \
		+ BUTTON_HEIGHT * 3.0 + ROW_GAP * 2.0 + CAPTION_GAP + CAPTION_UNITS

## Wie BREIT die Bucht bei dieser Einheit sein muß: Ränder und der Knopf.
static func width_for(unit: float) -> float:
	return unit * (MARGIN * 2.0 + BUTTON_WIDTH)

## Wie HOCH die Bucht steht - EIN Kunde, eine feste Höhe.
static func height_for(unit: float) -> float:
	return unit * height_units()

## Die Maßeinheit, bei der die Bucht in rect paßt - so liest sie in jedem
## Zuschnitt gleich.
static func unit_for(rect: Rect2) -> float:
	return maxf(minf(rect.size.y / height_units(), rect.size.x / width_for(1.0)), MIN_UNIT)

## Die Maßeinheit dieses Fensters: die, bei der width_for die eigene Breite trifft.
func unit() -> float:
	return maxf(size.x / width_for(1.0), MIN_UNIT)

## Fenster ODER Inhalt, was höher steht (die Knöpfe klemmen sich an ihrer
## Mindestgröße hoch) - so fällt kein Klick unter der Kante durch.
func bay_rect() -> Rect2:
	var rect := get_global_rect()
	rect.size.y = maxf(rect.size.y, height_for(unit()))
	return rect

## Die Leiter in DISPLAY-Pixeln - das Ziel der Kometen (ohne Kunden die Mitte).
func ladder_px() -> Vector2:
	if target == null or _ladder_rect.size == Vector2.ZERO:
		return bay_rect().get_center()
	return global_position + _ladder_rect.get_center()

# --- Zustand ---------------------------------------------------------------------

func set_run(new_run: GameRun) -> void:
	run = new_run
	_signature = ""
	refresh()

## Der Zielwürfel des Podests - scene_root meldet ihn, wenn er dort steht.
func set_target(die: DieDefinition) -> void:
	if target == die:
		return
	target = die
	refresh()

func set_enabled(on: bool) -> void:
	if enabled == on:
		return
	enabled = on
	refresh()

## Idempotent: nur der WECHSEL baut neu.
func refresh() -> void:
	if not is_inside_tree():
		return
	if run != null and target != null and not run.owned_pool.has(target):
		target = null  # der Kunde hat den Vorrat verlassen
	var signature := _signature_of()
	if signature == _signature and _content != null and is_instance_valid(_content):
		return
	_signature = signature
	_build()

func _signature_of() -> String:
	var who := "%d:%d:%d" % [target.get_instance_id(), target.charge,
		1 if target.burned_out else 0] if target != null else "-"
	var money := run.money if run != null else 0
	var energy := run.energy if run != null else 0
	var locked := run != null and run.repair_locked()
	# Der PREIS gehört in die Signatur: das Isolierband tauscht ihn, ohne daß sich
	# am Würfel etwas ändert.
	var price := str(run.repair_price()) if run != null else ""
	return "%s|%d|%d|%d|%d|%s|%dx%d" % [who, money, energy, 1 if locked else 0,
		1 if enabled else 0, price, int(size.x), int(size.y)]

# --- Aufbau ----------------------------------------------------------------------

func _build() -> void:
	if _content != null and is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_content = null
	_caption = null
	_ladder_rect = Rect2()
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
	var seat_index := run.owned_pool.find(target) if run != null and target != null else -1
	_line(content, "Titel", Vector2(margin, y), Vector2(inner, u * HEADER_UNITS),
		u * TITLE_STEP, GOLD, HORIZONTAL_ALIGNMENT_LEFT).text = \
			"%s #%d" % [TITLE, seat_index + 1] if seat_index >= 0 else TITLE
	y += u * (HEADER_UNITS + HEADER_GAP)

	# Die Leiter: ohne Kunden steht dort die Bitte um die Wahl.
	if target != null:
		var lamps := DieNetView.charge_lamps(target, u * LADDER_HEIGHT)
		lamps.name = "Leiter"
		lamps.position = Vector2(margin, y)
		lamps.size = Vector2(inner, u * LADDER_HEIGHT)
		content.add_child(lamps)
		_ladder_rect = Rect2(lamps.position, lamps.size)
	else:
		_line(content, "Leer", Vector2(margin, y), Vector2(inner, u * LADDER_HEIGHT),
			u * CAPTION_STEP, MUTED_COLOR, HORIZONTAL_ALIGNMENT_LEFT).text = EMPTY_TEXT
	y += u * (LADDER_HEIGHT + ROW_GAP)

	# Die drei Handlungen, IMMER alle drei, von oben nach unten: hinauf, herunter,
	# Reparatur - was der Kunde nicht braucht, steht grau.
	var die := target
	var charge := _button(content, "Aufladen", Vector2(margin, y), Vector2(inner, u * BUTTON_HEIGHT),
		u, charge_label())
	charge.disabled = not charge_live()
	charge.pressed.connect(func() -> void: charge_requested.emit(die))
	y += maxf(charge.size.y, u * BUTTON_HEIGHT) + u * ROW_GAP
	var drain := _button(content, "Ableiten", Vector2(margin, y), Vector2(inner, u * BUTTON_HEIGHT),
		u, drain_label())
	drain.disabled = not drain_live()
	drain.pressed.connect(func() -> void: drain_requested.emit(die))
	y += maxf(drain.size.y, u * BUTTON_HEIGHT) + u * ROW_GAP
	var repair := _button(content, "Reparieren", Vector2(margin, y),
		Vector2(inner, u * BUTTON_HEIGHT), u, repair_label())
	repair.disabled = not repair_live()
	repair.pressed.connect(func() -> void: repair_requested.emit(die))
	y += maxf(repair.size.y, u * BUTTON_HEIGHT) + u * CAPTION_GAP

	_caption = _line(content, "Caption", Vector2(margin, y),
		Vector2(inner, u * CAPTION_UNITS), u * CAPTION_STEP, MUTED_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT)
	_caption.clip_text = false
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_caption.text = caption_for_state()

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

func charge_label() -> String:
	return "Aufladen %d ⚡" % GameRun.CHARGE_UP_ENERGY

## Ist die Bucht überhaupt offen? Bedienbarkeit wie die Werkstatt, plus die Sperre
## des Wartungsvertrags.
func bay_open() -> bool:
	return run != null and enabled and not run.repair_locked()

func repair_live() -> bool:
	if not bay_open() or target == null or not target.burned_out:
		return false
	var price := run.repair_price()
	if price.has("money"):
		return run.money >= int(price["money"])
	return run.energy >= int(price["energy"])

func drain_live() -> bool:
	if not bay_open() or target == null or target.burned_out or target.charge <= 0:
		return false
	return run.money >= GameRun.DRAIN_MONEY

func charge_live() -> bool:
	if not bay_open() or target == null or target.burned_out \
			or target.charge >= DieDefinition.CHARGE_MAX:
		return false
	return run.energy >= GameRun.CHARGE_UP_ENERGY

## WARUM ein Knopf schweigt ("" = keiner). Genannt wird die erste geschlossene
## Bremse - erst die Sperren, dann das fehlende Guthaben; ein kalter, voller oder
## heiler Würfel ist keine Bremse, sein Knopf steht einfach grau.
func bay_blocker() -> String:
	if run == null or target == null:
		return ""
	if not enabled:
		return BLOCK_ROUND
	if run.repair_locked():
		return BLOCK_LOCKED
	if target.burned_out:
		var price := run.repair_price()
		if price.has("money"):
			return BLOCK_MONEY if run.money < int(price["money"]) else ""
		return BLOCK_ENERGY if run.energy < int(price["energy"]) else ""
	if target.charge > 0 and run.money < GameRun.DRAIN_MONEY:
		return BLOCK_MONEY
	if target.charge < DieDefinition.CHARGE_MAX and run.energy < GameRun.CHARGE_UP_ENERGY:
		return BLOCK_ENERGY
	return ""

## Die Caption: der Zustand des Kunden, dann die Bremse, dann die Warnung vor
## der letzten Sprosse.
func caption_for_state() -> String:
	if target == null:
		return ""
	var blocker := bay_blocker()
	if blocker != "":
		return blocker
	if not target.burned_out and target.charge == DieDefinition.CHARGE_MAX - 1:
		return WARN_TOP
	return DieNetView.hint_for(target, DieNetView.EDGE)

func caption_text() -> String:
	return _caption.text if _caption != null and is_instance_valid(_caption) else ""
