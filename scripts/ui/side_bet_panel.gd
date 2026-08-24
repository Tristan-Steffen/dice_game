class_name SideBetPanel
extends Panel
## Tisch-Fenster rechts vom Würfelbecher: platziert die Nebenwetten VOR dem
## ersten Wurf einer Runde (Wett-Modus mit Setzen-Knöpfen, über die
## Maus-Weiterleitung bedient) und zeigt danach den Live-Fortschritt
## (Fortschritts-Modus). Platzieren mutiert den Zustand über GameRun.

## Nach dem Platzieren einer Wette - scene_root aktualisiert ggf. die Anzeige.
signal changed
## VOR der Einsatz-Zahlung (scene_root unterdrückt das generische Geld-Licht und
## merkt sich, was gleich fliegt) bzw. DANACH (scene_root wirft den Einsatz).
signal bet_selected(index: int)
signal bet_placed(index: int)

enum Mode { BETTING, PROGRESS }

## Anzahl Wett-Angebote je Runde.
const OFFER_COUNT := 3

## Der WETT-TRESEN steht IN DEN ANGEBOTS-ZEILEN: DER SETZEN-KNOPF IST DER STELLPLATZ.
## Je Angebot EIN Plot, rechts in seiner Zeile neben Name und Beschreibung - vor dem
## Setzen der Knopf (er NENNT den Handel), danach die FASSUNG, in deren Grube der
## GEWINN wartet. Dasselbe Rechteck in jedem Zustand, und es ist eine reine Funktion der
## Fenstergröße: nur so sind die gemeldeten Plätze über Setzen, Fassung und Modi
## byteweise dieselben. Die ZEILENHÖHE ist darum fest - kein Text verschiebt je
## einen Plot.
## Das Fenster malt nur die Fassung und MELDET die Plätze - die Körper gehören
## scene_root (die Grammatik der Kassetten-Schlitzreihe im Laden). Vor dem Setzen
## liegt NICHTS: der Tresen ist kein Schaufenster, der Knopf NENNT den Preis.
const PLOT_WIDTH_UNITS := 26.0
const PLOT_HEIGHT_UNITS := 12.5   # zugleich die feste Höhe einer Angebots-Zeile
const PLOT_GAP_UNITS := 2.0       # Fuge zwischen zwei Zeilen und zwischen Text und Plot
const COUNTER_TOP_UNITS := 14.4   # gemessene Luft über der ersten Zeile: Titel und Anrede
const MARGIN_UNITS := 3.0         # seitlicher Rand des Fensters

## Der LEBENSZYKLUS - die Timeline des Spielers auf dem Tresen.
## OPEN  = die Wettannahme steht offen, ROUND = die Runde läuft. Beide tragen
##         DASSELBE: vom EINSATZ liegt nichts (der Tisch hat ihn beim Kauf
##         geschluckt), statt dessen steht der GEWINN da - unten in der offenen
##         Grube, solange die Wette noch kippen kann, sonst oben ausgefahren.
## WON   = die Abrechnung, allein die gewonnenen Preise stehen noch.
const STAGE_NONE := ""
const STAGE_OPEN := "open"
const STAGE_ROUND := "round"
const STAGE_WON := "won"

## Die Plot-Seiten. Gewöhnlich steht der GEWINN mittig auf seinem Plot; nur die
## Steuerwette teilt ihn: links ihre Zählplatte, rechts daneben ihr Gewinn.
const SEAT_FULL := 0
const SEAT_LEFT := 1
const SEAT_RIGHT := 2
## Der linke Anteil eines geteilten Plots - gemessen an der Zählplatte (46,7 px im
## 259 px breiten Plot), der Rest gehört dem Gewinn (breitester: 147,3 px).
const PLOT_TALLY_SHARE := 0.28

## Was auf einem Plot LIEGT - ein Plot kann MEHRERES tragen (die Steuerwette ihre
## Zählplatte UND ihren Gewinn daneben).
const LIE_TALLY := "tally"          # die Zählplatte einer Steuerwette
const LIE_PRIZE_PIT := "prize_pit"  # der Gewinn wartet UNTEN in der offenen Grube
const LIE_PRIZE_UP := "prize_up"    # der Gewinn steht oben, ausgefahren

const TITLE_COLOR := Color("#ff79c6")
const TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (Glow)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GREEN := Color("#50fa7b")
const RED := Color("#ff5555")
const GOLD := Color("#ffd319")
const ENGRAVING_GLOW := Color("#c77dff")  # Gravur-Licht (violett)
const CHARGE_COLOR := CasinoStyle.CHARGE
const BAR_BG := Color("#100e20")

var run: GameRun
var mode: int = Mode.PROGRESS

## Wett-Auslage dieser Runde (nur im BETTING-Modus).
var offers: Array[SideBet] = []
var placed: Array[bool] = []
var bet_buttons: Array[Button] = []
## Platzierte Wetten, deren geworfener Einsatz gelandet ist: index -> Glühfarbe.
## Getrennt von placed, damit der Sitz erst bei ANKUNFT golden leuchtet (und
## nach jedem _rebuild wieder). Von scene_root über glow_bet gesetzt.
var bet_glow: Dictionary = {}

var _result: Dictionary = {}
var _content: VBoxContainer

## Die SITZE des Tresens (einer je Angebot), unabhängig vom Seiteninhalt - ein
## Neuaufbau der Zeilen rührt sie nicht an, sonst wanderten die Plätze bei jeder
## Fortschritts-Meldung. Sie SIND die Setzen-Knöpfe (bet_buttons zeigt auf dieselben).
var _counter: Control
## Je Sitz seine Aufschrift: der Handel "Einsatz → Gewinn". Sie ist fort, sobald der
## Sitz zur Fassung wird - unter einem Körper steht kein Text. Den Namen trägt die
## Zeile links daneben, er stünde hier ein zweites Mal.
var _seat_trades: Array[Label] = []
## Je Zeile ihr Textplatz links vom Stellplatz - dieselbe feste Höhe wie der Plot,
## und darum vom Inhalt ebenso unberührt.
var _row_hosts: Array[Control] = []

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
	_rebuild()

## Schließt den Wett-Modus (erster Wurf) - ab jetzt nur noch Fortschritt.
func close_betting() -> void:
	mode = Mode.PROGRESS
	_rebuild()

## Baut die offene Wett-Auslage neu auf (gleiche Angebote, gleiche Einsätze-
## Marken): ein mitten in der Runde unterschriebener Deal (Quotenpaket) ändert
## die Preise - der Knopf muss den WIRKLICH fälligen Einsatz zeigen.
func refresh_betting() -> void:
	if mode == Mode.BETTING:
		_rebuild()

## Zieht NUR die Bezahlbarkeit der offenen Auslage nach (Geld, Pakete, Energie
## ändern sich während der Wettannahme). Kein Neuaufbau: der angekommene
## Einsatz-Glanz bleibt stehen.
func refresh_affordability() -> void:
	if mode != Mode.BETTING:
		return
	for i in mini(bet_buttons.size(), offers.size()):
		if placed[i] or not is_instance_valid(bet_buttons[i]):
			continue
		_sync_affordability(i, offers[i])

## Aktualisiert den Live-Fortschritt (nur im Fortschritts-Modus wirksam).
func update_progress(result: Dictionary) -> void:
	_result = result
	if mode == Mode.PROGRESS:
		_rebuild()

# --- Aufbau --------------------------------------------------------------------

func _rebuild() -> void:
	var u := maxf(size.x, 200.0) / 100.0
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = u * MARGIN_UNITS
	_content.offset_right = -u * MARGIN_UNITS
	_content.offset_top = u * 2.2
	# Der KOPF endet über der ersten Zeile: die Zeilen sind kein Layout-Kind, ihre
	# Plätze bleiben von jeder Fortschritts-Meldung unberührt.
	_content.offset_bottom = -maxf(size.y - u * COUNTER_TOP_UNITS, u * 2.2)
	_content.add_theme_constant_override("separation", int(u * 1.6))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_content.add_child(_label("NEBENWETTEN", u * 5.2, TITLE_COLOR))
	_lay_counter()  # erst die Zeilen legen, dann füllen
	if mode == Mode.BETTING:
		_build_betting(u)
	else:
		_build_progress(u)

## Wett-Modus: je Angebot SEINE Zeile - Name und Bedingung links, der Setzen-Knopf
## als Stellplatz rechts daneben.
func _build_betting(u: float) -> void:
	_content.add_child(_label("Vor dem ersten Wurf setzen:", u * 2.5, MUTED_COLOR))
	for i in mini(offers.size(), OFFER_COUNT):
		_fill_row(i, _offer_row(offers[i], u))

func _offer_row(bet: SideBet, u: float) -> Control:
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", int(u * 0.2))
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(_label(bet.display_name, u * 3.4, TEXT_COLOR))
	var desc := _label(bet.description, u * 2.4, MUTED_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(desc)
	return text

## Legt EINEN Textblock in seine Zeile. Die Zeile selbst gehört _lay_counter - hier
## steht nur, WAS darin steht.
func _fill_row(index: int, block: Control) -> void:
	if index < 0 or index >= _row_hosts.size():
		return
	var host := _row_hosts[index]
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(block)

## Bezahlbarkeit auf dem Setzen-Knopf: rot heißt "der Einsatz reicht nicht" -
## dieselbe Grammatik wie die Preiszeile im Laden (ShopController.price_tint). Rot
## wird die AUFSCHRIFT, denn sie trägt hier den Text, nicht der Knopf.
## can_place_side_bet entscheidet allein; Steuerwetten kosten beim Platzieren
## nichts und werden darum nie rot.
func _sync_affordability(index: int, bet: SideBet) -> void:
	var button := bet_buttons[index]
	var short := run == null or not run.can_place_side_bet(bet)
	button.disabled = short
	_style_button(button, CasinoStyle.RED if short else payout_accent(bet))
	_seat_trades[index].modulate = CasinoStyle.RED if short else TEXT_COLOR

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
	var box := _plot_box(color, maxf(size.x, 200.0) / 100.0, true)
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
	_rebuild()
	bet_placed.emit(index)  # scene_root: den Einsatz werfen
	changed.emit()

## Der Einsatz ist "angekommen": der Sitz glüht ab jetzt in color (bleibt
## über _rebuild erhalten, solange die Wette platziert ist).
func glow_bet(index: int, color: Color) -> void:
	bet_glow[index] = color
	if index >= 0 and index < bet_buttons.size() and is_instance_valid(bet_buttons[index]):
		_apply_stake_glow(bet_buttons[index], color, true)

## Fortschritts-Modus: jede laufende Wette steht in IHRER Angebots-Zeile, also neben
## ihrem eigenen Stellplatz. Was die Auslage nicht kennt, bekommt die nächste freie.
func _build_progress(u: float) -> void:
	var bets: Array[SideBet] = []
	if run != null:
		bets = run.active_side_bets
	if bets.is_empty():
		_content.add_child(_label("Keine Wetten aktiv.", u * 3.5, MUTED_COLOR))
		return
	var line: Array[SideBet] = []
	line.resize(OFFER_COUNT)
	for i in mini(offers.size(), OFFER_COUNT):
		if bets.has(offers[i]):
			line[i] = offers[i]
	for bet in bets:
		if line.has(bet):
			continue
		var free := line.find(null)
		if free < 0:
			break
		line[free] = bet
	for i in OFFER_COUNT:
		if line[i] != null:
			_fill_row(i, _progress_row(line[i], u))

func _progress_row(bet: SideBet, u: float) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(u * 1.2))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var state := bet.live_state(_result)
	var color := GREEN if state == SideBet.Live.ON_TRACK \
		else (RED if state == SideBet.Live.FAILED else MUTED_COLOR)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(bet.display_name, u * 4.2, TEXT_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	header.add_child(_label(bet.status_label(_result), u * 3.8, color))
	box.add_child(header)

	box.add_child(_bar(bet.progress_fraction(_result), color, u))
	return box

## Fortschrittsbalken: dunkle Wanne mit farbiger Füllung (Anteil per Anker).
func _bar(fraction: float, color: Color, u: float) -> Control:
	var track := Panel.new()
	track.custom_minimum_size = Vector2(0, u * 2.2)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = BAR_BG
	bg.set_corner_radius_all(int(u * 0.9))
	track.add_theme_stylebox_override("panel", bg)

	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_right = clampf(fraction, 0.0, 1.0)
	fill.anchor_bottom = 1.0
	var inset := u * 0.35
	fill.offset_left = inset
	fill.offset_top = inset
	fill.offset_right = -inset
	fill.offset_bottom = -inset
	track.add_child(fill)
	return track

# --- Der WETT-TRESEN -------------------------------------------------------------
# Der SETZEN-KNOPF ist der Stellplatz, und er steht rechts in seiner Angebots-Zeile:
# gemeldet werden seine Rechtecke, die Körper stellt scene_root. Vor dem Setzen liegt
# nichts darauf - der Knopf nennt den Preis.

## Der Stellplatz EINES Angebots in Display-Pixeln - in Fenster-Einheiten
## geschrieben, denn er ist ein Knopf und kein geschnittener Warenplatz: die Körper
## liegen in ECHTER Größe darauf und dürfen über ihn hinausragen.
func counter_plot_size() -> Vector2:
	var u := maxf(size.x, 200.0) / 100.0
	var plot := Vector2(u * PLOT_WIDTH_UNITS, u * PLOT_HEIGHT_UNITS)
	# Die Zeilen stehen ÜBEREINANDER: sie müssen unter Titel und Anrede in die
	# Fensterhöhe passen, sonst rückt der Tresen zusammen, statt hinauszulaufen.
	var fugues := u * PLOT_GAP_UNITS * float(OFFER_COUNT - 1)
	var room := maxf(size.y - u * (COUNTER_TOP_UNITS + MARGIN_UNITS) - fugues, u * 6.0)
	var high := room / float(OFFER_COUNT)
	if plot.y > high:
		plot *= high / plot.y  # Seitenverhältnis halten, sonst verzerrt der Platz
	# Und links davon muss der Text der Zeile noch stehen können.
	var wide := maxf(size.x - u * (MARGIN_UNITS * 2.0 + PLOT_GAP_UNITS + 12.0), u * 6.0)
	if plot.x > wide:
		plot *= wide / plot.x
	return plot

## Die Plätze in FENSTER-eigenen Pixeln, einer je Angebot - rechts in seiner Zeile.
## Reine Funktion der Fenstergröße - darum in jedem Modus und Zustand dasselbe
## Rechteck.
func counter_local_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var u := maxf(size.x, 200.0) / 100.0
	var plot := counter_plot_size()
	var pitch := plot.y + u * PLOT_GAP_UNITS
	var left := size.x - u * MARGIN_UNITS - plot.x
	var top := u * COUNTER_TOP_UNITS
	for i in OFFER_COUNT:
		out.append(Rect2(Vector2(left, top + float(i) * pitch), plot))
	return out

## Dieselben Plätze in globalen Display-Pixeln - danach schneidet scene_root Loch
## und Sitze.
func counter_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for rect in counter_local_rects():
		out.append(Rect2(global_position + rect.position, rect.size))
	return out

## Die beiden STEUERWETTEN sind die AUSNAHME der Timeline: ihr Einsatz entsteht erst
## während der Runde, darum bleibt ihre ZÄHLPLATTE liegen, sammelt weiter Chips und
## wird erst bei der Abrechnung geschluckt.
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
## Die Steuerwette trägt ZWEI Körper: ihre wachsende Zählplatte und ihren Gewinn.
static func counter_lies(stage: String, bets: Array[SideBet], is_placed: Array[bool],
		fulfilled: Array[SideBet], failed: Array[SideBet],
		won: Array[SideBet]) -> Dictionary:
	var out: Dictionary = {}
	if stage == STAGE_NONE:
		return out
	for i in mini(bets.size(), OFFER_COUNT):
		var bet := bets[i]
		if bet == null:
			continue
		if stage == STAGE_WON:
			if won.has(bet):
				out[i] = [LIE_PRIZE_UP] as Array[String]
			continue
		if i >= is_placed.size() or not is_placed[i]:
			continue
		var lies: Array[String] = []
		if is_tax_bet(bet) and not bet.voided:
			lies.append(LIE_TALLY)
		if not failed.has(bet) and not (is_tax_bet(bet) and bet.voided):
			# Erfüllt heißt oben; noch offen heißt unten, aber nur, wenn die Wette
			# mitten in der Runde überhaupt kippen kann.
			lies.append(LIE_PRIZE_UP if fulfilled.has(bet) or not bet.decides_early()
				else LIE_PRIZE_PIT)
		if not lies.is_empty():
			out[i] = lies
	return out

## Wo ein Körper AUF seinem Plot sitzt. Gewöhnlich steht er MITTIG; nur der geteilte
## Steuer-Plot setzt links die Zählplatte und rechts daneben den Gewinn. Jeder rückt
## nur so weit ein, dass sein gemessener Fußabdruck den Plot nicht verläßt; was
## breiter ist als der ganze Plot, steht mittig und ragt nach beiden Seiten hinaus.
## Reine Funktion aus Plot und gemessenem Fußabdruck - scene_root reicht den Abdruck.
static func seat_in(plot: Rect2, footprint: Vector2, side: int = SEAT_FULL) -> Vector2:
	var middle := plot.get_center()
	if plot.size.x <= 0.0:
		return middle
	var zone := middle.x
	if side == SEAT_LEFT:
		zone = plot.position.x + plot.size.x * PLOT_TALLY_SHARE * 0.5
	elif side == SEAT_RIGHT:
		zone = plot.position.x + plot.size.x * (1.0 + PLOT_TALLY_SHARE) * 0.5
	var half := maxf(footprint.x, 0.0) * 0.5
	if half * 2.0 >= plot.size.x:
		return middle
	return Vector2(clampf(zone, plot.position.x + half, plot.end.x - half), middle.y)

## Die GEWINN-Beschriftung eines Angebots - die EINE Formulierung des Hauses, samt
## Deal-Faktor und Quotenblatt. Der Setzen-Knopf nennt sie, und der SCHIRM über der
## geparkten Grube nennt genau dieselbe: was im Gewinn-Fach liegt, wird nicht zweimal
## formuliert.
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

## Baut Sitze und Textplätze einmal und legt sie auf ihre Zeilen. Sie hängen NICHT am
## Seiteninhalt: ein Neuaufbau der Zeilen darf die Ware nicht verrücken.
func _lay_counter() -> void:
	if _counter == null or not is_instance_valid(_counter):
		_counter = Control.new()
		_counter.name = "Tresen"
		_counter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_counter)
		bet_buttons.clear()
		_seat_trades.clear()
		_row_hosts.clear()
		for i in OFFER_COUNT:
			_counter.add_child(_build_row_host(i))
			_counter.add_child(_build_seat(i))
	move_child(_counter, 0)  # die Möbel bleiben hinter dem Seiteninhalt
	var u := maxf(size.x, 200.0) / 100.0
	var rects := counter_local_rects()
	for i in mini(bet_buttons.size(), rects.size()):
		bet_buttons[i].position = rects[i].position
		bet_buttons[i].size = rects[i].size
		# Die Aufschrift bekommt Luft zum Saum, sonst klebt der Umbruch am Rahmen.
		var box: Control = _seat_trades[i].get_parent()
		box.offset_left = u * 1.4
		box.offset_right = -u * 1.4
		_row_hosts[i].position = Vector2(u * MARGIN_UNITS, rects[i].position.y)
		_row_hosts[i].size = Vector2(maxf(rects[i].position.x
			- u * (MARGIN_UNITS + PLOT_GAP_UNITS), u), rects[i].size.y)
	_sync_seats()

## EIN Sitz: der Knopf selbst, darin seine Aufschrift. Sie fängt nichts ab - der
## Klick gehört dem Knopf.
func _build_seat(index: int) -> Button:
	var button := Button.new()
	button.name = "Sitz%d" % index
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.pressed.connect(_on_bet_pressed.bind(index))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var trade := _label("", 10.0, TEXT_COLOR)
	trade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trade.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(trade)
	bet_buttons.append(button)
	_seat_trades.append(trade)
	return button

## Der TEXTPLATZ einer Zeile, links vom Stellplatz. Er klippt: kein Wort läuft je in
## den Plot oder in die Nachbarzeile.
func _build_row_host(index: int) -> Control:
	var host := Control.new()
	host.name = "Zeile%d" % index
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.clip_contents = true
	_row_hosts.append(host)
	return host

## Der Zustand der Sitze - NIE ihre Geometrie: offen ist ein Sitz der Setzen-Knopf,
## gesetzt (oder außerhalb der Wettannahme) ist er die FASSUNG seines Stellplatzes.
func _sync_seats() -> void:
	var u := maxf(size.x, 200.0) / 100.0
	for i in bet_buttons.size():
		var button := bet_buttons[i]
		var open := mode == Mode.BETTING and i < offers.size() \
			and i < placed.size() and not placed[i]
		_seat_trades[i].visible = open
		if not open:
			_style_seat_frame(button, i, u)
			continue
		var bet := offers[i]
		# Deal-Faktoren gehören auf den Sitz: sonst verspricht er einen Preis, den
		# die Buchung nicht einhält (Quotenpaket).
		var stake_factor := run.side_bet_stake_factor() if run != null else 1
		_seat_trades[i].text = "%s → %s" % [bet.stake_label(stake_factor),
			prize_label(i)]
		_seat_trades[i].add_theme_font_size_override("font_size", maxi(8, int(u * 2.6)))
		_sync_affordability(i, bet)  # stellt Grund, Saum und Bezahlbarkeit

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
	box.set_corner_radius_all(int(u * 0.7))
	return box

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
	var u := maxf(size.x, 200.0) / 100.0
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.8))
	box.set_content_margin_all(int(u * 0.6))
	return box
