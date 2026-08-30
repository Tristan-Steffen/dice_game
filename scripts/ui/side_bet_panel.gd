class_name SideBetPanel
extends Panel
## Tisch-Fenster rechts vom Würfelbecher: DIE DREI KNÖPFE, sonst nichts. Vor der
## Annahme trägt ein Knopf die Bedingung und den Handel, danach ist er die FASSUNG
## seines Stellplatzes und trägt an dessen Unterkante seinen MELDER. Platzieren
## mutiert den Zustand über GameRun.

## Nach dem Platzieren einer Wette - scene_root aktualisiert ggf. die Anzeige.
signal changed
## VOR der Einsatz-Zahlung (scene_root unterdrückt das generische Geld-Licht und
## merkt sich, was gleich fliegt) bzw. DANACH (scene_root wirft den Einsatz).
signal bet_selected(index: int)
signal bet_placed(index: int)

enum Mode { BETTING, PROGRESS }

## Anzahl Wett-Angebote je Runde.
const OFFER_COUNT := 3

## Der WETT-TRESEN IST das Fenster: DER SETZEN-KNOPF IST DER STELLPLATZ, und außer
## den drei Knöpfen steht hier nichts - kein Kopf, keine Text-Spalte, keine Zeile.
## Dasselbe Rechteck in jedem Zustand, und es ist eine reine Funktion der
## Fenstergröße: nur so sind die gemeldeten Plätze über Setzen, Fassung und Modi
## byteweise dieselben.
## Das Fenster malt nur die Fassung und MELDET die Plätze - die Körper gehören
## scene_root (die Grammatik der Kassetten-Schlitzreihe im Laden). Vor dem Setzen
## liegt NICHTS: der Tresen ist kein Schaufenster, der Knopf NENNT den Handel.

const PLOT_WIDTH_UNITS := 26.0
const PLOT_HEIGHT_UNITS := 12.5   # zugleich die feste Höhe einer Angebots-Zeile
const PLOT_GAP_UNITS := 2.0       # Fuge zwischen zwei Zeilen
const MARGIN_UNITS := 2.0         # seitlicher Rand = Fuge zwischen den Zeilen
const COUNTER_TOP_UNITS := 2.0    # Luft über der ersten Zeile - ein Rand, kein Kopf
const PLOT_RADIUS_UNITS := 0.7    # Eckenrundung der Fassung - und des Lochs darunter

## Die EINHEIT des Fensters: seine Breite geteilt durch die Knopf-Spalte.
## Pixelgleich zur alten Einheit, also behalten Plots, Fassungen, Löcher
## und Schrift ihre Maße, während allein das Fenster schrumpft.
const UNIT_DIV := MARGIN_UNITS * 2.0 + PLOT_WIDTH_UNITS

## Die Maße des Fensters in EIGENEN Einheiten - die Knopf-Spalte und ihre Ränder.
## EINE Quelle: scene_root schneidet das Fenster daraus, _unit() teilt durch sie.
static func preferred_units() -> Vector2:
	return Vector2(UNIT_DIV, COUNTER_TOP_UNITS
		+ PLOT_HEIGHT_UNITS * float(OFFER_COUNT)
		+ PLOT_GAP_UNITS * float(OFFER_COUNT - 1) + MARGIN_UNITS)

func _unit() -> float:
	return maxf(size.x, UNIT_DIV * 2.0) / UNIT_DIV

## Luft zwischen Aufschrift und Saum der Fassung - ohne sie klebt der Umbruch am Rahmen.
const SEAT_PAD_X_UNITS := 1.4
const SEAT_PAD_Y_UNITS := 0.8

## Die Grad-Leiter des Setzen-Knopfs: Bedingung UND Handel müssen ganz auf den Plot,
## also wird der größte Grad genommen, bei dem beide hineinbrechen - die längste
## Bedingung des Katalogs ragte sonst aus dem Knopf.
const SEAT_STEPS: Array[float] = [2.4, 2.2, 2.0, 1.85, 1.7, 1.55, 1.4, 1.3, 1.2, 1.1,
	1.0, 0.9, 0.8]
## Die Bedingung steht GROSS — sie sagt, was zu tun ist.
const SEAT_GOAL_GAIN := 1.3
## Der Handel steht eine Spur kleiner als die Bedingung: er ist der Preis.
const SEAT_TRADE_GAIN := 1.15

## Die MELDER-Zeile der Fassung liegt an der Plot-UNTERKANTE: darüber steht der
## Gewinn, und was er deckt, ist verloren. Ihr Band ist dieser Anteil des Plots.
const NOTE_BAND_SHARE := 0.42
const NOTE_STEPS: Array[float] = [1.9, 1.75, 1.6, 1.45, 1.35, 1.25, 1.15, 1.05, 0.95,
	0.85, 0.75]
## Und ihr AUFLEUCHTEN: eine eingetroffene Steuer-Buchung hebt sie kurz an und läßt
## sie in ihren Ton zurückfallen - dieselbe Meldung, die der Gruben-Schirm zeigt.
const NOTE_FLASH_GAIN := 2.2
const NOTE_FLASH_TIME := 0.5

## Der LEBENSZYKLUS - die Timeline des Spielers auf dem Tresen.
## OPEN  = die Wettannahme steht offen, ROUND = die Runde läuft. Beide tragen
##         DASSELBE: vom EINSATZ liegt nichts (der Tisch hat ihn beim Kauf
##         geschluckt), statt dessen wartet der GEWINN unten in der offenen Grube -
##         JEDER, bis er verdient ist; der Melder sagt, wie es steht.
## WON   = die Abrechnung, allein die gewonnenen Preise stehen noch.
const STAGE_NONE := ""
const STAGE_OPEN := "open"
const STAGE_ROUND := "round"
const STAGE_WON := "won"

## Was auf einem Plot LIEGT - eine Liste, denn der Bestand ist die Regel und nicht
## die Zahl. Vom EINSATZ liegt nie etwas: der Tisch hat ihn beim Kauf geschluckt.
const LIE_PRIZE_PIT := "prize_pit"  # der Gewinn wartet UNTEN in der offenen Grube
const LIE_PRIZE_UP := "prize_up"    # der Gewinn steht oben, ausgefahren

const TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (Glow)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GREEN := Color("#50fa7b")
const RED := Color("#ff5555")
const GOLD := Color("#ffd319")
const ENGRAVING_GLOW := Color("#c77dff")  # Gravur-Licht (violett)
const CHARGE_COLOR := CasinoStyle.CHARGE

var run: GameRun
var mode: int = Mode.PROGRESS
var locked := true
var _lock_overlay: Panel

## Wett-Auslage dieser Runde (nur im BETTING-Modus).
var offers: Array[SideBet] = []
var placed: Array[bool] = []
var bet_buttons: Array[Button] = []
## Platzierte Wetten, deren geworfener Einsatz gelandet ist: index -> Glühfarbe.
## Getrennt von placed, damit der Sitz erst bei ANKUNFT golden leuchtet (und
## nach jedem Abgleich wieder). Von scene_root über glow_bet gesetzt.
var bet_glow: Dictionary = {}

## Der LEBENSZYKLUS-Stand, gemeldet von scene_root (reine Daten): Stufe und die drei
## Listen, aus denen counter_lies den Bestand rechnet. Das Fenster hält ihn selbst,
## damit Melder und Körper AUS DERSELBEN Antwort leben.
var stage: String = STAGE_NONE
var fulfilled: Array[SideBet] = []
var failed: Array[SideBet] = []
var won: Array[SideBet] = []

var _result: Dictionary = {}

## Die SITZE des Tresens (einer je Angebot). Sie SIND die Setzen-Knöpfe
## (bet_buttons zeigt auf dieselben).
var _counter: Control
## Je Sitz sein ANGEBOT: der Block aus Bedingung und Handel. Er ist fort, sobald der
## Sitz zur Fassung wird - unter einem Körper steht kein Angebot mehr.
var _seat_offers: Array[Control] = []
var _seat_goals: Array[Label] = []
var _seat_trades: Array[Label] = []
## Und je Sitz sein MELDER an der Plot-Unterkante: Bedingung plus Live-Stand, getönt
## nach live_state. Über einer offenen Grube schneidet der Shader ihn weg - dort
## übernimmt der Gruben-Schirm.
var _seat_notes: Array[Label] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Setzen-Knöpfe fangen selbst
	clip_contents = true  # nichts ragt über den Neon-Rahmen hinaus
	add_theme_stylebox_override("panel", TableScreen.window_style())
	resized.connect(_lay_counter)

# --- Modus-Umschaltung (scene_root) --------------------------------------------

## Öffnet den Wett-Modus mit frischer Auslage (vor dem ersten Wurf).
func open_betting(new_offers: Array[SideBet]) -> void:
	mode = Mode.BETTING
	offers = new_offers
	placed.resize(offers.size())
	placed.fill(false)
	bet_glow.clear()
	_lay_counter()

## Schließt den Wett-Modus (erster Wurf) - ab jetzt nur noch Melder.
func close_betting() -> void:
	mode = Mode.PROGRESS
	_lay_counter()

## Baut die offene Wett-Auslage neu auf (gleiche Angebote, gleiche Einsätze-
## Marken): ein mitten in der Runde unterschriebener Deal (Quotenpaket) ändert
## die Preise - der Knopf muss den WIRKLICH fälligen Einsatz zeigen.
func refresh_betting() -> void:
	if mode == Mode.BETTING:
		_lay_counter()

## Zieht NUR die Bezahlbarkeit der offenen Auslage nach (Geld, Pakete, Energie
## ändern sich während der Wettannahme). Der angekommene Einsatz-Glanz bleibt stehen.
func refresh_affordability() -> void:
	if mode != Mode.BETTING:
		return
	for i in mini(bet_buttons.size(), offers.size()):
		if placed[i] or not is_instance_valid(bet_buttons[i]):
			continue
		_sync_affordability(i, offers[i])

## Aktualisiert den Live-Stand. Auch die offene Wettannahme hört zu: eine GESETZTE
## Wette zeigt dort schon ihren Melder, und der soll nicht alt aussehen.
func update_progress(result: Dictionary) -> void:
	_result = result
	_sync_seats()

# --- Der MELDER: Bedingung und Live-Stand ---------------------------------------
# Zwei Quellen, kein dritter Formulierer - dieselbe Zeile trägt der Gruben-Schirm.

func meter_line(index: int) -> String:
	if index < 0 or index >= offers.size() or offers[index] == null:
		return ""
	var bet := offers[index]
	var stand := bet.status_label(_result)
	return bet.description if stand == "" else "%s  %s" % [bet.description, stand]

## Über einer OFFENEN Grube SCHWEIGT der Sitz: dort trägt der SCHIRM dieselbe Zeile,
## und die gesenkte Plattform zeigt das Display ihres Plots ein zweites Mal (der
## Mahjong-Deckel) - der Melder stünde also doppelt. Offen ist eine Grube genau dann,
## wenn ihr Gewinn unten wartet, und das sagt counter_lies: EINE Quelle für Bestand,
## Ort und Schweigen, damit die drei nie wieder auseinanderdriften.
func plot_parked(index: int) -> bool:
	return (lies().get(index, []) as Array).has(LIE_PRIZE_PIT)

## Die reine Regel auf den eigenen Stand angewandt - was auf welchem Plot liegt.
func lies() -> Dictionary:
	return counter_lies(stage, offers, placed, fulfilled, failed, won)

## Den Lebenszyklus melden (scene_root ist sein Buchhalter) und die Sitze danach
## stellen: kippt eine Wette, schweigt oder spricht ihr Melder im selben Bild.
func set_lifecycle(new_stage: String, new_fulfilled: Array[SideBet],
		new_failed: Array[SideBet], new_won: Array[SideBet]) -> void:
	stage = new_stage
	fulfilled = new_fulfilled.duplicate()
	failed = new_failed.duplicate()
	won = new_won.duplicate()
	_sync_seats()

## Eine Steuer-Buchung ist eingetroffen: die Bedingungs-Zeile des Sitzes leuchtet kurz
## auf und fällt in ihren Ton zurück. Über einer geparkten Grube spricht statt dessen
## der Schirm - dort steht der Melder gar nicht.
func flash_note(index: int) -> void:
	if index < 0 or index >= _seat_notes.size():
		return
	var note := _seat_notes[index]
	if not is_instance_valid(note) or not note.visible:
		return
	var rest := meter_tint(index)
	note.modulate = Color(rest.r * NOTE_FLASH_GAIN, rest.g * NOTE_FLASH_GAIN,
		rest.b * NOTE_FLASH_GAIN)
	var tween := create_tween()
	tween.tween_property(note, "modulate", rest, NOTE_FLASH_TIME) \
		.set_trans(Tween.TRANS_SINE)

## Und ihr Ton: grün heißt erfüllt, rot gescheitert, sonst neutral.
func meter_tint(index: int) -> Color:
	if index < 0 or index >= offers.size() or offers[index] == null:
		return MUTED_COLOR
	match offers[index].live_state(_result):
		SideBet.Live.ON_TRACK:
			return GREEN
		SideBet.Live.FAILED:
			return RED
	return MUTED_COLOR

# --- Bezahlbarkeit und Kauf ------------------------------------------------------

## Bezahlbarkeit auf dem Setzen-Knopf: rot heißt "der Einsatz reicht nicht" -
## dieselbe Grammatik wie die Preiszeile im Laden (ShopController.price_tint). Rot
## wird der HANDEL, denn er nennt den Preis.
## can_place_side_bet entscheidet allein; Steuerwetten kosten beim Platzieren
## nichts und werden darum nie rot.
func _sync_affordability(index: int, bet: SideBet) -> void:
	var button := bet_buttons[index]
	var short := run == null or not run.can_place_side_bet(bet)
	button.disabled = short
	_style_button(button, CasinoStyle.RED if short else payout_accent(bet))
	_seat_trades[index].modulate = CasinoStyle.RED if short else GOLD

## Knopffarbe verrät die Wett-Sorte: Bargeld gold, Ladung cyan, alles übrige
## (Gravuren, Sonderposten, Paket, Chipstufe) grün.
static func payout_accent(bet: SideBet) -> Color:
	match bet.payout_kind:
		SideBet.Payout.MONEY:
			return GOLD
		SideBet.Payout.CHARGE:
			return CHARGE_COLOR
	return GREEN

## Legt den glühenden Einsatz-Saum auf den gesetzten Sitz. Er ist jetzt die FASSUNG
## des Stellplatzes, also glüht sein Rand - eine Füllung läge unter dem Körper.
## animate = Ankunft (der Saum fährt hell hoch), sonst sofort (Neuaufbau).
func _apply_stake_glow(button: Button, color: Color, animate: bool) -> void:
	var box := _plot_box(color, _unit(), true)
	button.add_theme_stylebox_override("disabled", box)
	if not animate:
		return
	var lit := box.border_color
	box.border_color = Color(color.r, color.g, color.b, 0.0)
	var tween := create_tween()
	tween.tween_property(box, "border_color", lit, 0.35).set_trans(Tween.TRANS_SINE)

func _on_bet_pressed(index: int) -> void:
	if mode != Mode.BETTING or placed[index] or run == null:
		return
	if not run.can_place_side_bet(offers[index]):
		return
	bet_selected.emit(index)  # scene_root: Geld-Licht unterdrücken, Wurfgut merken
	run.place_side_bet(offers[index])
	placed[index] = true
	_lay_counter()
	bet_placed.emit(index)  # scene_root: den Einsatz werfen
	changed.emit()

## Der Einsatz ist "angekommen": der Sitz glüht ab jetzt in color (bleibt über jeden
## Abgleich erhalten, solange die Wette platziert ist).
func glow_bet(index: int, color: Color) -> void:
	bet_glow[index] = color
	if index >= 0 and index < bet_buttons.size() and is_instance_valid(bet_buttons[index]):
		_apply_stake_glow(bet_buttons[index], color, true)

# --- Der WETT-TRESEN -------------------------------------------------------------
# Der SETZEN-KNOPF ist der Stellplatz: gemeldet werden seine Rechtecke, die Körper
# stellt scene_root. Vor dem Setzen liegt nichts darauf - der Knopf nennt den Handel.

## Der Stellplatz EINES Angebots in Display-Pixeln - in Fenster-Einheiten
## geschrieben, denn er ist ein Knopf und kein geschnittener Warenplatz: die Körper
## liegen in ECHTER Größe darauf und dürfen über ihn hinausragen.
func counter_plot_size() -> Vector2:
	var u := _unit()
	var plot := Vector2(u * PLOT_WIDTH_UNITS, u * PLOT_HEIGHT_UNITS)
	# Die Zeilen stehen ÜBEREINANDER: sie müssen unter dem oberen Rand in die
	# Fensterhöhe passen, sonst rückt der Tresen zusammen, statt hinauszulaufen.
	var fugues := u * PLOT_GAP_UNITS * float(OFFER_COUNT - 1)
	var room := maxf(size.y - u * (COUNTER_TOP_UNITS + MARGIN_UNITS) - fugues, u * 6.0)
	var high := room / float(OFFER_COUNT)
	if plot.y > high:
		plot *= high / plot.y  # Seitenverhältnis halten, sonst verzerrt der Platz
	var wide := maxf(size.x - u * MARGIN_UNITS * 2.0, u * 6.0)
	if plot.x > wide:
		plot *= wide / plot.x
	return plot

## Die Plätze in FENSTER-eigenen Pixeln, einer je Angebot. Reine Funktion der
## Fenstergröße - darum in jedem Modus und Zustand dasselbe Rechteck.
func counter_local_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var u := _unit()
	var plot := counter_plot_size()
	var pitch := plot.y + u * PLOT_GAP_UNITS
	var left := (size.x - plot.x) * 0.5
	var top := u * COUNTER_TOP_UNITS
	for i in OFFER_COUNT:
		out.append(Rect2(Vector2(left, top + float(i) * pitch), plot))
	return out

## Die Eckenrundung des Stellplatzes in Display-Pixeln. EINE Quelle: die FASSUNG
## rundet damit ihre Ecken, und dieselbe Zahl schneidet das Loch darunter - Grube und
## Knopf sind eine Form, nicht zwei ähnliche.
func counter_plot_radius() -> float:
	return float(int(_unit() * PLOT_RADIUS_UNITS))

## Dieselben Plätze in globalen Display-Pixeln - danach schneidet scene_root Loch
## und Sitze.
func counter_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for rect in counter_local_rects():
		out.append(Rect2(global_position + rect.position, rect.size))
	return out

## Die beiden STEUERWETTEN kosten beim Setzen NICHTS: ihre Rechnung kommt Hand für
## Hand, und sie reist als Licht statt als Wurf (siehe Der WETT-TRESEN).
static func is_tax_bet(bet: SideBet) -> bool:
	if bet == null:
		return false
	return bet.stake_kind == SideBet.Stake.MONEY_PER_HAND \
		or bet.stake_kind == SideBet.Stake.MONEY_PER_DIE

## Was auf welchem Plot LIEGT - die reine Regel der Timeline (Plot-Index -> Liste von
## LIE_*), damit sie prüfbar ist, statt in scene_root zu wohnen. Vom EINSATZ liegt
## NICHTS: der Tisch hat ihn beim Kauf geschluckt. Statt dessen steht ab dem Kauf der
## GEWINN da - UNTEN in der offenen Grube, solange die Wette mitten in der Runde noch
## kippen kann (decides_early), sonst sofort oben ausgefahren. Erfüllung hebt ihn,
## Scheitern nimmt ihn fort; in der Abrechnung steht allein, was gewonnen hat.
static func counter_lies(life_stage: String, bets: Array[SideBet],
		is_placed: Array[bool], is_fulfilled: Array[SideBet],
		is_failed: Array[SideBet], is_won: Array[SideBet]) -> Dictionary:
	var out: Dictionary = {}
	if life_stage == STAGE_NONE:
		return out
	for i in mini(bets.size(), OFFER_COUNT):
		var bet := bets[i]
		if bet == null:
			continue
		if life_stage == STAGE_WON:
			if is_won.has(bet):
				out[i] = [LIE_PRIZE_UP] as Array[String]
			continue
		if i >= is_placed.size() or not is_placed[i]:
			continue
		# Zahlungsunfähig (die Steuer hat die Wette gerissen) ist verloren wie jedes
		# andere Scheitern: der Gewinn verläßt seine Grube unten.
		if bet.voided or is_failed.has(bet):
			continue
		# JEDER Gewinn wartet UNTEN, bis er verdient ist - auch der einer Wette, die
		# grün startet und nur noch reißen kann. Sie sähe sonst aus wie schon gewonnen;
		# ihr GRÜNER Melder sagt, dass sie auf Kurs liegt, und gehoben wird sie erst bei
		# der Abrechnung (STAGE_WON).
		out[i] = [LIE_PRIZE_UP if is_fulfilled.has(bet) else LIE_PRIZE_PIT] as Array[String]
	return out

## Wo ein Körper AUF seinem Plot sitzt: MITTIG, denn er ist das Einzige, was dort je
## steht - vom Einsatz bleibt nichts, und die Zählplatte, die den Plot einst teilte,
## ist tot. Reine Funktion des Plots; die echte Größe des Körpers weitet nichts.
static func seat_in(plot: Rect2) -> Vector2:
	return plot.get_center()

## Die GEWINN-Beschriftung eines Angebots - die EINE Formulierung des Hauses, samt
## Deal-Faktor und Quotenblatt. Der Setzen-Knopf nennt sie, und der SCHIRM über der
## geparkten Grube nennt beim Hover genau dieselbe: was im Gewinn-Fach liegt, wird
## nicht zweimal formuliert.
func prize_label(index: int) -> String:
	if index < 0 or index >= offers.size() or offers[index] == null:
		return ""
	var factor := run.side_bet_payout_factor() if run != null else 1
	var charms := run.charm_ids() if run != null else [] as Array[String]
	return offers[index].reward_label(factor, charms)

## Und ihr Akzent - derselbe, den Knopf und Fassung tragen.
func prize_accent(index: int) -> Color:
	if index < 0 or index >= offers.size() or offers[index] == null:
		return MUTED_COLOR
	return payout_accent(offers[index])

## Hat das Fenster schon ein Rechteck? Ein Tresen ohne Maß meldet keine Plätze.
func counter_laid_out() -> bool:
	return size.x > 1.0 and size.y > 1.0

## Baut die Sitze einmal und legt sie auf ihre Plätze. Die Geometrie hängt NICHT am
## Inhalt: ein neuer Melder darf die Ware nicht verrücken.
func _lay_counter() -> void:
	if _counter == null or not is_instance_valid(_counter):
		_counter = Control.new()
		_counter.name = "Tresen"
		_counter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_counter)
		bet_buttons.clear()
		_seat_offers.clear()
		_seat_goals.clear()
		_seat_trades.clear()
		_seat_notes.clear()
		for i in OFFER_COUNT:
			_counter.add_child(_build_seat(i))
	var u := _unit()
	var rects := counter_local_rects()
	var pad := Vector2(u * SEAT_PAD_X_UNITS, u * SEAT_PAD_Y_UNITS)
	for i in mini(bet_buttons.size(), rects.size()):
		bet_buttons[i].position = rects[i].position
		bet_buttons[i].size = rects[i].size
		var block := _seat_offers[i]
		block.offset_left = pad.x
		block.offset_right = -pad.x
		block.offset_top = pad.y
		block.offset_bottom = -pad.y
		block.add_theme_constant_override("separation", int(u * 0.7))
		# Der Melder hängt an der UNTERKANTE des Plots, nicht an der Blockmitte.
		var note := _seat_notes[i]
		note.offset_left = pad.x
		note.offset_right = -pad.x
		note.offset_top = -rects[i].size.y * NOTE_BAND_SHARE
		note.offset_bottom = -pad.y
	_sync_seats()
	if _lock_overlay == null or not is_instance_valid(_lock_overlay):
		_build_lock_overlay()

## EIN Sitz: der Knopf selbst, darin sein ANGEBOT (Bedingung über Handel) und, an der
## Plot-Unterkante, sein MELDER. Beide fangen nichts ab - der Klick gehört dem Knopf.
func _build_seat(index: int) -> Button:
	var button := Button.new()
	button.name = "Sitz%d" % index
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.pressed.connect(_on_bet_pressed.bind(index))
	var block := VBoxContainer.new()
	block.name = "Angebot"
	block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(block)
	var goal := _wrapped_label(TEXT_COLOR)
	block.add_child(goal)
	var trade := _wrapped_label(GOLD)
	block.add_child(trade)
	var note := _wrapped_label(MUTED_COLOR)
	note.name = "Melder"
	note.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	note.clip_text = true  # der Melder klippt lieber, als aus der Fassung zu laufen
	note.anchor_left = 0.0
	note.anchor_right = 1.0
	note.anchor_top = 1.0
	note.anchor_bottom = 1.0
	note.visible = false
	button.add_child(note)
	bet_buttons.append(button)
	_seat_offers.append(block)
	_seat_goals.append(goal)
	_seat_trades.append(trade)
	_seat_notes.append(note)
	return button

func _wrapped_label(color: Color) -> Label:
	var label := _label("", 10.0, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

## Der Zustand der Sitze - NIE ihre Geometrie: offen ist ein Sitz der Setzen-Knopf und
## trägt Bedingung und Handel, gesetzt (oder außerhalb der Wettannahme) ist er die
## FASSUNG seines Stellplatzes und trägt dort seinen Melder.
func _sync_seats() -> void:
	var u := _unit()
	var inner := _seat_inner()
	for i in bet_buttons.size():
		var button := bet_buttons[i]
		var bet: SideBet = offers[i] if i < offers.size() else null
		var open := mode == Mode.BETTING and bet != null \
			and i < placed.size() and not placed[i]
		var lit := bet != null and i < placed.size() and placed[i]
		_seat_offers[i].visible = open
		_seat_notes[i].visible = lit and not open and not plot_parked(i)
		if _seat_notes[i].visible:
			_seat_notes[i].text = meter_line(i)
			_seat_notes[i].modulate = meter_tint(i)
			_fit_note(i, u, inner.x)
		if not open:
			_style_seat_frame(button, i, u)
			continue
		# Deal-Faktoren gehören auf den Sitz: sonst verspricht er einen Preis, den
		# die Buchung nicht einhält (Quotenpaket).
		var stake_factor := run.side_bet_stake_factor() if run != null else 1
		_seat_goals[i].text = bet.description
		_seat_trades[i].text = "%s → %s" % [bet.stake_label(stake_factor),
			prize_label(i)]
		_fit_seat(i, u, inner)
		_sync_affordability(i, bet)  # stellt Grund, Saum und Bezahlbarkeit

## Der Textraum EINES Sitzes: der Plot abzüglich seiner Ränder. Gerechnet, nicht
## gemessen - ein eben gelegter Knopf hat noch kein Rechteck.
func _seat_inner() -> Vector2:
	var u := _unit()
	var plot := counter_plot_size()
	return Vector2(maxf(plot.x - u * SEAT_PAD_X_UNITS * 2.0, u),
		maxf(plot.y - u * SEAT_PAD_Y_UNITS * 2.0, u))

## Der größte Grad, bei dem Bedingung UND Handel ganz auf den Knopf passen.
func _fit_seat(index: int, u: float, inner: Vector2) -> void:
	var goal := _seat_goals[index]
	var trade := _seat_trades[index]
	var font := goal.get_theme_default_font()
	var gap := float(_seat_offers[index].get_theme_constant("separation"))
	# Der Zeilenabstand des Labels gehört in die Messung: ohne ihn untermißt der
	# gemessene Block, und die letzte Zeile fällt aus der Fassung.
	var lead := goal.get_theme_constant("line_spacing")
	var grade: float = SEAT_STEPS[SEAT_STEPS.size() - 1]
	for step in SEAT_STEPS:
		var goal_px := maxi(8, int(u * step * SEAT_GOAL_GAIN))
		var trade_px := maxi(8, int(u * step * SEAT_TRADE_GAIN))
		var block := ShopController.wrapped_height(font, goal.text, inner.x, goal_px, lead) \
			+ ShopController.wrapped_height(font, trade.text, inner.x, trade_px, lead) + gap
		if block <= inner.y:
			grade = step
			break
	goal.add_theme_font_size_override("font_size", maxi(8, int(u * grade * SEAT_GOAL_GAIN)))
	trade.add_theme_font_size_override("font_size",
		maxi(8, int(u * grade * SEAT_TRADE_GAIN)))

## Und der größte, bei dem der Melder in sein Band an der Plot-Unterkante paßt.
func _fit_note(index: int, u: float, wide: float) -> void:
	var note := _seat_notes[index]
	var font := note.get_theme_default_font()
	var band := maxf(counter_plot_size().y * NOTE_BAND_SHARE
		- u * SEAT_PAD_Y_UNITS, u)
	var lead := note.get_theme_constant("line_spacing")
	var grade: float = NOTE_STEPS[NOTE_STEPS.size() - 1]
	for step in NOTE_STEPS:
		if ShopController.wrapped_height(font, note.text, wide,
				maxi(8, int(u * step)), lead) <= band:
			grade = step
			break
	note.add_theme_font_size_override("font_size", maxi(8, int(u * grade)))

## Ein Sitz als FASSUNG: nur ein Saum, kein Grund - unter einem physischen Ding
## steht kein Panel (die Magazin-Regel). Ein angekommener Einsatz läßt ihn glühen.
func _style_seat_frame(button: Button, index: int, u: float) -> void:
	button.disabled = true
	var accent := MUTED_COLOR
	if index < offers.size() and offers[index] != null:
		accent = payout_accent(offers[index])
	var box := _plot_box(accent, u)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, box)
	if index < placed.size() and placed[index] and bet_glow.has(index):
		_apply_stake_glow(button, bet_glow[index], false)

## Die FASSUNG eines Stellplatzes. strong = der angekommene Einsatz, der sie zum
## Glühen bringt.
func _plot_box(accent: Color, u: float, strong := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Color(accent.r, accent.g, accent.b, 0.85 if strong else 0.42)
	box.set_border_width_all(maxi(1, int(u * (0.3 if strong else 0.18))))
	box.set_corner_radius_all(int(counter_plot_radius()))
	return box

# --- Sperre (Fenster vor Freischaltung) ----------------------------------------

func set_locked(is_locked: bool) -> void:
	locked = is_locked
	if _lock_overlay != null and is_instance_valid(_lock_overlay):
		_lock_overlay.visible = locked

func _build_lock_overlay() -> void:
	_lock_overlay = Panel.new()
	_lock_overlay.name = "LockOverlay"
	_lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lock_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.01, 0.06, 0.72)
	box.set_corner_radius_all(int(_unit() * 1.2))
	_lock_overlay.add_theme_stylebox_override("panel", box)
	add_child(_lock_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_overlay.add_child(center)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	var u := _unit()
	var title := _label("Ab Lizenzstufe %d" % GameRun.HUB_SIDE_BETS_LEVEL, u * 2.8, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var name_lbl := _label(GameRun.HUB_LEVEL_NAMES[GameRun.HUB_SIDE_BETS_LEVEL - 1],
		u * 2.2, MUTED_COLOR)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_lbl)
	_lock_overlay.visible = locked

# --- Bausteine -----------------------------------------------------------------

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color(MUTED_COLOR.r, MUTED_COLOR.g, MUTED_COLOR.b, 0.5))
	button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#2c2757dd"), GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#3a2f66"), GOLD))
	button.add_theme_stylebox_override("disabled", _button_box(Color("#1a183666"), Color(accent.r, accent.g, accent.b, 0.25)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var u := _unit()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.8))
	box.set_content_margin_all(int(u * 0.6))
	return box
