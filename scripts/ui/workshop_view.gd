class_name WorkshopView
extends Panel
## Die Werkbank unter den Trays - das EINZIGE Fenster der Ecke. Seit der
## SERIENSCHALTUNG (2026-09-01) liest sich ihre Grundseite von links nach rechts:
## links die ZIEL-SÄULE (oben die Projektor-Bühne, auf der der gewählte Würfel
## schwebt - scene_root stellt ihn auf -, darunter das SUMMEN-NETZ als
## Live-Vorschau), rechts das POOL-RASTER, in dem der Zielwürfel gewählt wird
## (Sitz i = Zelle i, die Grammatik der Glas-Ansicht).
##
## Alles darunter liegt in der SCHÜRZE, und sie beginnt UNTER der Fensterkante:
## eine Naht, dann das Konsolen-Band (in seiner Mitte die SERIEN-SLOT-REIHE, in
## seiner rechten Flanke der EINE Handlungs-Sitz - der GRIFF -, dahinter der
## Serien-Schirm, in seiner linken die Hinweiskarte), dieselbe Naht noch einmal,
## dann das MAGAZIN über die volle Fensterbreite: EIN eingelassenes Fach, in dem
## jedes versiegelte Paket als eigene Kassette in Spieler-Ordnung liegt
## (owned_packs); es endet auf der Unterkante des Hubs (scene_root misst das und
## schiebt es als apron_bottom herein).
##
## Die REIHE IST die Rechnung: getippt geht eine Kassette in den nächsten freien
## Slot, gezogen sortiert sie um (Reihenfolge = Rechenreihenfolge), geklickt kommt
## sie zurück ins Magazin. Ihre Zahl ist GameRun.series_slots() - die Reihe wächst
## mit dem Hub, sie ist kein festes Sechser-Möbel.
##
## Zustands-Mutation läuft ausschließlich über GameRun (resolve_series als
## Vorschau, apply_series als Griff); die Vorschau ist buchstäblich dieselbe
## Rechnung wie die Buchung.

## Der Zielwürfel wurde gewählt, gewechselt oder abgewählt (null = keiner) -
## scene_root holt ihn per Hebebühne aus dem Pool auf die Projektor-Bühne und
## fährt ihn denselben Weg zurück.
signal target_chosen(die: DieDefinition)
## Der GRIFF ist durch: gebucht hat GameRun schon beim Auslösen, hier ist die
## Zeremonie zu Ende und scene_root läßt den Zielwürfel aufblitzen. Der Anker
## reist MIT - das Fenster ist inzwischen neu gebaut.
signal series_applied(result: Dictionary, from_px: Vector2)
## Die Bühne des Zielwürfels hat sich geändert (Wahl, Neuaufbau) - scene_root
## stellt den ECHTEN Würfel darüber neu auf.
signal die_stages_changed
## Ein Liefer-Licht ist auf seinem Magazin-Platz eingeschlagen - scene_root lässt
## den Körper dort aufleuchten (der Pluster lebt nicht mehr im 2D-Knopf).
signal pack_landed(uid: int)
## Eine Karte ist aus ihrem Serien-Slot zurück ins Magazin gegangen - die Zelle
## dieses Platzes fliegt heim auf ihren Platz. Gebucht ist da längst.
signal pack_unslotted(slot_index: int, uid: int)
## Der Griff beginnt: die gesteckten Zellen geben ihre Daten an die Reihe ab.
## Gemeldet wird VOR dem Buchen, solange die Sockel noch stehen.
signal press_started
## Ein Schlüsselwort auf dem Serien-Schirm wurde geklickt - scene_root schlägt das
## Lexikon auf (dieselbe Verweis-Grammatik wie im Laden-Tooltip).
signal lexikon_requested(entry_id: String)

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")
## Operator-Karten stehen amber ab - die eine Farbtrennung der Serie (Wert-Karten
## behalten ihre Sortenfarbe). Die Quelle ist das Netz, nicht dieses Fenster.
const OPERATOR_TINT := PressNetView.OPERATOR_TINT

## Spaltenzahl der Pool-Auswahl = Spaltenzahl der echten Trays (DiceTrayView),
## damit das Raster wie das Tray darüber liest.
const POOL_COLUMNS := 6
## Maße des Hinweis-Schirms (Magazin-Kassette, Serien-Karte, Netz-Zelle).
const INFO_TITLE := 2.4
const INFO_BODY := 1.9
## Innenrand des Schirms und der Abstand zwischen Titel und Wirkung. Nach außen
## hat er keinen: links steht er auf der Fensterkante, rechts trennt ihn die
## Naht des Handlungs-Sitzes (ACTION_GAP) vom Blech.
const INFO_PAD := 0.9
const INFO_LINE_GAP := 0.3
## Schriftgrade der Wirkungszeile, absteigend: der Schirm hat eine feste Größe,
## also nimmt der Text den ersten Grad, dessen Umbruch noch hineinpaßt.
const INFO_BODY_STEPS := [1.9, 1.65, 1.4, 1.2, 1.05, 0.92, 0.8, 0.7, 0.62]
## Auch der TITEL paßt sich ein - ein Würfelname samt Seelennamen bricht bei vollem
## Grad auf drei Zeilen und schöbe die Wirkungszeile sonst aus dem Schirm.
const INFO_TITLE_STEPS := [2.4, 2.05, 1.75, 1.5, 1.3, 1.15]
## Höchster Anteil des Schirms, den die Kennung belegen darf.
const INFO_TITLE_SHARE := 0.42

## Höhe der Bühne des schwebenden Zielwürfels (Breiteneinheiten u): Platz für den
## Würfel UND seine Stasis-Station, die durch die Parallaxe ein Stück unter ihm
## auf der Fläche steht.
const STAGE_HEIGHT := 9.3
## Zellgröße des Summen-Netzes: die Kachel, in der ein Würfel gezeigt wird, wenn
## man ÜBER ihn entscheidet.
const CHOICE_CELL := DieNetView.TRAY_TILE
## Fuge zwischen der Ziel-Säule links und dem 30er-Raster rechts. Sie ist der
## SEITENRAND des Inhalts (CONTENT_MARGIN_X, per Test festgenagelt): das Raster
## soll nach oben, unten und zu seiner Säule hin genauso viel Luft haben wie zum
## rechten Fensterrand - eine Zahl, vier Abstände.
const BODY_GAP := 2.4
## Spaltenluft der Serien-Reihe und Maße EINER Karte (Einheiten u). Die Kassette
## steht SENKRECHT im Slot: oben ihr Prägenetz, darunter ihr Name.
const BENCH_GAP := 1.2
const CARD_WIDTH := 4.8
const CARD_HEIGHT := 8.0
const CARD_PAD := 0.4
## Anteil der Kartenhöhe, den das Mini-Netz nimmt - der Rest trägt den Namen.
const CARD_NET_SHARE := 0.56
const CARD_NAME_STEPS := [1.25, 1.1, 0.95, 0.82, 0.7]
## Ein Leseschlitz ist ein LOCH, kein Ding: die Datenzelle STECKT senkrecht darin
## und ragt nur mit ihrer Kopfkante heraus.
const SOCKET_BG := Color("#0b0a18dd")
const SOCKET_RIM := Color("#3b356acc")
const SOCKET_LIVE_RIM := Color("#8be9fdcc")
## Der Schlitz muss die Zelle schlucken, und zwar in dem EINEN Maß, in dem sie
## überall steht (PackDrawerView.CASSETTE_SCALE): ihre Kappe gibt Breite UND Tiefe
## vor. Flach bleibt er trotzdem - ein Schlitz ist eine Kante, keine Bucht.
const SOCKET_ROOM := 1.30
const SLIT_HEIGHT := 1.6
const SLIT_DISPLAY_GAP := 0.4
## Die Slots liegen in einem erhabenen KONSOLEN-BLECH: dieselbe gemalte Tiefe wie
## die Magazin-Fassung (Lichtkante oben, Schattenkante unten), aber neutral - die
## Sortenfarbe gehört der Ware, nicht dem Gerät.
const CONSOLE_BASE := Color("#2f2c3c")
const CONSOLE_SHEEN := Color("#bab7cd")
const CONSOLE_SHEEN_MIX := 0.44
const CONSOLE_SHADOW := Color(0.0, 0.0, 0.0, 0.7)
const CONSOLE_PAD_X := 1.2
const CONSOLE_PAD_Y := 0.72
const CONSOLE_EDGE := 0.33
const CONSOLE_RADIUS := 0.9
## Die Tasche eines Slots: Karte und Schlitz liegen IM Blech, also Schatten oben
## und Licht unten - die Umkehrung der Konsolenkante.
const POCKET_BASE := Color("#14121f")
const POCKET_SHEEN := Color(0.66, 0.64, 0.76, 0.5)
const POCKET_SHADOW := Color(0.0, 0.0, 0.0, 0.75)
const POCKET_BLEED := 0.26
const POCKET_EDGE := 0.22
const POCKET_RADIUS := 0.7
## Kopfhöhe über der Projektor-Zeile: der schwebende Zielwürfel ragt über seine
## Bühne hinaus, und in der Nahsicht sitzt die obere Fensterkante exakt am
## Bildrand - ohne diese Luft schnitte der Rahmen ihm die Oberseite ab.
const STAGE_HEAD_ROOM := 1.0
## Luft zwischen der Projektor-Bühne und dem Netz darunter: der Würfel soll über
## seinem Diagramm STEHEN, nicht darauf aufliegen.
const STAGE_NET_GAP := 1.0
## Die NAHT der Schürze - zweimal dasselbe Maß: Fensterkante zu Konsolenband und
## Konsolenband zu Magazin.
const CONSOLE_SHELF_GAP := 2.1
## Mindesthöhe des Magazin-Streifens (Einheiten u).
const SHELF_MIN_HEIGHT := 6.0
## Sollhöhe des Streifens (Einheiten u). Am Tisch ist sie der REST bis zur
## Hub-Unterkante - scene_root rechnet daraus die Fensterhöhe (apron_units).
const SHELF_STRIP_UNITS := 15.0
## Ränder und Zeilenabstand des Fensterinhalts (Einheiten u).
const CONTENT_MARGIN_X := 2.4
const CONTENT_MARGIN_Y := 1.4
const CONTENT_GAP := 1.0

## Der EINE Handlungs-Sitz rechts neben der Konsole: er trägt "Griff (n)" bzw.
## "Fertig". EIN Maß für beide - der Sitz steht fest, nur seine Aufschrift
## wechselt, und die Grundseite fließt nie um. Bemessen an der breitesten
## Aufschrift ("Griff (8)", die volle Serienlänge) plus Rand; der Rest der rechten
## Flanke gehört dem Serien-Schirm dahinter.
const ACTION_WIDTH := 15.0
const ACTION_HEIGHT := 4.0
## Luft zwischen Konsolenblech und Sitz bzw. Sitz und Serien-Schirm.
const ACTION_GAP := 1.6

## DER SERIEN-SCHIRM in der rechten Ecke des Bandes, rechts neben dem Sitz: das
## Gegenstück zum Hinweis-Schirm links. Er sagt, wie lang die Schaltung sein darf
## und was die gesteckten Katalysatoren zulegen - dunkel, solange nichts steckt.
const SERIES_MIN_WIDTH := 7.0
## Schriftgrade des Kopfes und der Zeilen, absteigend. Der Kopf ist EIN Wort und
## muss auf EINE Zeile.
const SERIES_TITLE_STEPS := [1.7, 1.5, 1.3, 1.15, 1.0]
const SERIES_BODY_STEPS := [1.5, 1.35, 1.2, 1.05, 0.95, 0.85, 0.75, 0.68, 0.6]
## Sicherheitsabschlag auf die gemessene Höhe: die Schrift misst sich ohne den
## Zeilenabstand des Labels, und ein halb abgeschnittener Fuß wäre die Folge.
const SERIES_ROOM_SHARE := 0.9
const SERIES_HEAD := "SERIE"

## DIE DURCHLICHT-FAHRT - die Zeremonie des Griffs. Der Schlitten verläßt seinen
## Parkplatz in der Ziel-Säule, fährt die Schiene über der Reihe ab und kehrt zum
## Zielwürfel zurück. Klick überspringt jederzeit; bei sechs Karten ~4,5 s.
## Das ENTLEEREN in Geister-Ziffern: die Vorschau tritt ab, die Rechnung beginnt
## bei 0 (das Netz tickt dabei HINUNTER auf die nackten Augenzahlen).
const SCAN_EMPTY_TIME := 0.3
const SCAN_TO_RAIL_TIME := 0.42
## Der Takt EINER Karte, mit RAMPE: die letzte fährt in diesem Anteil der ersten.
## Ein Operator bekommt seinen Sondermoment obendrauf.
const SCAN_STEP_TIME := 0.4
const SCAN_STEP_RAMP := 0.55
const SCAN_OPERATOR_EXTRA := 0.3
## Wieviel eines Takts die FAHRT nimmt - der Rest ist das Ticken am Ort.
const SCAN_MOVE_SHARE := 0.45
const SCAN_LEAVE_TIME := 0.55
const SCAN_FOLD_TIME := 0.8
const SCAN_FLASH_TIME := 0.24
## Anteil der Blechhöhe, den das Netz auf der SCHIENE einnimmt - dort fährt der
## Schlitten klein, in der Säule steht er in voller Größe.
const SCAN_RAIL_SHARE := 0.94
## Die SCHIENE selbst: ein Strich im oberen Rand des Blechs (er paßt in
## CONSOLE_PAD_Y, also verrückt er nichts).
const RAIL_TOP := 0.16
const RAIL_HEIGHT := 0.34
const RAIL_TINT := Color("#8be9fdaa")

## EINSETZEN und Umlegen: die Kassette FÄHRT aus ihrem Leseschlitz hoch, sinkt
## denselben Weg zurück und gleitet beim Umsortieren seitlich.
const CARD_RISE_TIME := 0.32
const CARD_SINK_TIME := 0.26
const CARD_SLIDE_TIME := 0.22

## Wieviel Serien-Slots ohne Lauf angezeigt werden (kopfloser Aufbau, Tests).
const FALLBACK_SLOTS := 2

var run: GameRun:
	set(value):
		if run == value:
			return
		if run != null and run.packs_changed.is_connected(refresh):
			run.packs_changed.disconnect(refresh)
			run.pool_changed.disconnect(refresh)
			run.press_changed.disconnect(refresh)
		_pending_arrivals.clear()  # Lieferungen des alten Laufs verfallen
		_queued_pops.clear()
		_drop_series()  # eine Serie des alten Laufs schuldet nichts mehr
		run = value
		if run != null:
			run.packs_changed.connect(refresh)
			run.pool_changed.connect(refresh)  # Raster und Summen-Netz zeigen den Pool
			run.press_changed.connect(refresh)  # der Griff der Sitzung hängt daran
		refresh()

var _content: VBoxContainer
## Das EINE Summen-Netz - es gehört dem SCHLITTEN, nicht der Säule (null = der
## Schlitten steht noch nicht).
var _net: PressNetView
## Der SCHLITTEN samt seinem Netz. Er überlebt jeden Neuaufbau des Fensters: seine
## Fahrt darf nicht daran zerbrechen, dass eine Kassette umsortiert wird.
var _scanner: SeriesScannerView
## Sein PARKPLATZ in der Ziel-Säule: ein leerer Platz in Netzgröße. Er ist es, den
## das Fenster als Netzmitte meldet - der Schlitten fährt, der Platz nie.
var _net_host: Control
## Die leere Projektor-Bühne über ihm: dort schwebt der echte Zielwürfel.
var _stage_host: Control
## Das Pool-Raster der Zielwahl.
var _pool_grid: DiceGridView
## Die Serien-Slots; jeder ist eine Kartentasche mit ihrem Leseschlitz.
var _slot_buttons: Array[Button] = []
## Die gezeichneten Schlitze selbst - IHRE Mitte ist der Steckplatz der Zelle,
## nicht die des Knopfes (der reicht bis über die Karte).
var _slit_panels: Array[Panel] = []
## Die Kartenplätze derselben Reihe (der HALTER, nicht die fahrende Karte darin)
## und das Glühen der Karten.
var _card_panels: Array[Control] = []
var _portals: Array[PressPortalView] = []
## Das Magazin der Bank (null = gerade nicht gebaut).
var _drawer: PackDrawerView
## Das Konsolen-Band auf der unteren Fensterkante (null = gerade nicht gebaut).
var _band: Control
## Unterkante der SCHÜRZE in Fenster-Koordinaten: scene_root misst sie an der
## Unterkante des Hubs und schiebt sie herein (<= size.y = noch nichts gemeldet).
var apron_bottom := 0.0:
	set(value):
		if is_equal_approx(apron_bottom, value):
			return
		apron_bottom = value
		refresh()
## Paket-uids, deren Liefer-Licht noch fährt (der Komet IST das Paket).
var _pending_arrivals: Dictionary = {}
## Ankunfts-Pluster, die noch auf ihr Fach warten (es stand gerade nicht).
var _queued_pops: Array[int] = []

## Gesperrt, sobald die Runde unterschrieben ist - dasselbe Zeitfenster wie fürs
## Gravieren; scene_root schiebt den Stand herein.
var editing_locked: bool = false:
	set(value):
		if editing_locked == value:
			return
		editing_locked = value
		refresh()
## Fußabdruck einer STEHENDEN Datenzelle in Display-Pixeln (ihre Kappe: Breite ×
## Kappentiefe); scene_root misst ihn an der Welt-Projektion und schiebt ihn
## herein (ZERO = noch unbekannt, dann trägt das Rückfallmaß der Leiste).
var data_cell_px := Vector2.ZERO:
	set(value):
		if data_cell_px.is_equal_approx(value):
			return
		data_cell_px = value
		refresh()

## Der Hinweis-Schirm am Konsolen-Band samt der Einheit, für die er gebaut wurde.
var _info_screen: Panel
var _info_title: Label
var _info_body: Label
var _info_tint: Color = CasinoStyle.CREAM

## Der Serien-Schirm in der rechten Ecke desselben Bandes.
var _series_screen: Panel
var _series_title: Label
var _series_body: RichTextLabel

## DIE SERIE: die uids der gesteckten Karten in STECKREIHENFOLGE - sie SIND die
## Rechnung. uids, nicht Indizes: das Magazin darf darunter umsortiert werden.
var _series: Array[int] = []
## Plätze im Pool: der Zielwürfel und (nur mit Doppelmatrize) der zweite.
var _target_index := -1
var _second_index := -1
## Die Karte unter dem Zeiger (-1 = keine): ihre Beitrags-Zellen leuchten im
## Summen-Netz, alles andere verblaßt.
var _hover_slot := -1
## Der Slot, auf dem ein Zug begonnen hat (-1 = keiner).
var _drag_from := -1
## Karten, die beim nächsten Aufbau aus ihrem Schlitz HOCHFAHREN (uid -> true),
## und Karten, die dabei seitlich gleiten (uid -> Weg in Pixeln).
var _fresh_slots: Dictionary = {}
var _slide_from: Dictionary = {}

## DIE LAUFENDE ZEREMONIE. _burning trägt die Kartendaten des Griffs (die Karten
## selbst sind da längst verbraucht), _burn_step, wie viele davon die Welle schon
## erfaßt hat, und _burn_die den Zielwürfel, wie er VOR dem Griff aussah - nur so
## kann das Summen-Netz von 0 hochticken.
var _burning: Array[Dictionary] = []
var _burn_step := -1
var _burn_gen := 0
var _burn_die: DieDefinition
var _burn_terms: Dictionary = {}
var _burn_result: Dictionary = {}
var _burn_anchor := Vector2.ZERO

## Das Blech der Serien-Reihe (null = steht gerade nicht).
var _console: Panel
## Der Knopf des Handlungs-Sitzes.
var _action_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Knöpfe fangen selbst
	# NICHT beschnitten: Konsolen-Band und Magazin hängen absichtlich unter der
	# Fensterkante heraus (die Schürze).
	clip_contents = false
	add_theme_stylebox_override("panel", TableScreen.window_style())
	set_process(true)  # der geparkte Schlitten hält seinen Platz in der Säule
	refresh()

## Der Schlitten PARKT, solange er nicht fährt - er folgt damit jedem Neuaufbau
## der Säule, ohne dass die Zeremonie ihn je zurückschreiben müßte.
func _process(_delta: float) -> void:
	_sync_scanner_park()

## Der HINWEIS-SCHIRM in der linken Flanke des Konsolen-Bandes: ein eigenes
## kleines Display neben der Reihe, auf dem steht, was gerade überfahren wird.
## Er STEHT (dunkel und leer, wenn nichts unter dem Zeiger liegt), denn Text auf
## blankem Filz ist Text im Nichts.
## tint färbt die WIRKUNGSZEILE - rot ist die eine Auskunft, die der Schirm selbst
## gibt: was gerade nicht zu haben ist.
func show_hover_info(title: String, body: String, tint: Color = CasinoStyle.CREAM) -> void:
	if _info_title == null or not is_instance_valid(_info_title):
		return
	_info_title.text = title
	_info_title.visible = title != ""
	_info_body.text = body
	_info_body.visible = body != ""
	_info_body.modulate = tint if tint == CasinoStyle.RED else Color.WHITE
	_info_tint = tint
	_fit_info_body()

func clear_hover_info() -> void:
	show_hover_info("", "")

## Steht gerade ein Hinweis auf dem Schirm? (Der Schirm selbst steht immer.)
func hover_info_visible() -> bool:
	return _info_title != null and is_instance_valid(_info_title) \
		and (_info_title.visible or _info_body.visible)

## Breite des SCHIRMS: die ganze linke Flanke bis auf die Naht zum Blech. Links
## endet er nicht früher als das Fenster darüber.
func info_width() -> float:
	var u := maxf(size.x, 200.0) / 100.0
	var flank := (size.x - console_size(u).x) * 0.5
	return maxf(flank - u * ACTION_GAP, u * 14.0)

## Sein Platz im Fenster: bündig mit dessen linker Kante, in der Höhe das Band -
## dieselben zwei Nähte, die auch das Blech von Fenster und Magazin trennen.
func info_screen_rect() -> Rect2:
	var u := maxf(size.x, 200.0) / 100.0
	var top := size.y + u * CONSOLE_SHELF_GAP
	return Rect2(Vector2(0.0, top),
		Vector2(info_width(), maxf(shelf_top() - u * CONSOLE_SHELF_GAP - top, u * 6.0)))

## Breite seines TEXTES: der Schirm abzüglich seines eigenen Randes.
func _info_text_width() -> float:
	var u := maxf(size.x, 200.0) / 100.0
	return maxf(info_width() - u * INFO_PAD * 2.0, u * 10.0)

## Wie hoch ein umbrochener Block WIRKLICH steht. Die nackte Schriftmessung
## unterschlägt zwei Dinge, und beide zusammen kosteten fast die Hälfte: sie
## bricht nur an Wortgrenzen (das Label bricht notfalls IM Wort) und sie zählt
## den Zeilenabstand des Labels nicht mit.
static func text_block_lines(font: Font, text: String, width: float, px: int) -> int:
	if font == null or px <= 0 or text == "":
		return 0
	var line := maxf(font.get_height(px), 1.0)
	var block := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER,
		width, px, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
			| TextServer.BREAK_ADAPTIVE)
	return maxi(int(round(block.y / line)), 1)

static func text_block_height(font: Font, text: String, width: float, px: int,
		spacing: int) -> float:
	var lines := text_block_lines(font, text, width, px)
	if lines <= 0:
		return 0.0
	return float(lines) * font.get_height(px) + float(lines - 1) * float(spacing)

## Der Schirm hat eine FESTE Größe, also passen sich BEIDE Zeilen ein: erst die
## Kennung in ihren Anteil, dann die Auskunft in den Rest.
func _fit_info_body() -> void:
	if _info_body == null or not is_instance_valid(_info_body):
		return
	var u := maxf(size.x, 200.0) / 100.0
	var width := _info_text_width()
	var room := info_screen_rect().size.y - u * INFO_PAD * 2.0
	room -= _fit_info_title(u, width, room)
	var font := _info_body.get_theme_font("font")
	var spacing := _info_body.get_theme_constant("line_spacing")
	for step in INFO_BODY_STEPS:
		var px := int(u * float(step))
		_info_body.add_theme_font_size_override("font_size", px)
		if font == null or px <= 0:
			return
		if text_block_height(font, _info_body.text, width, px, spacing) <= room:
			return

## Die Kennung zuerst: sie nimmt den ersten Grad, der in ihren Anteil paßt, und
## meldet, wie viel Schirm sie samt Fuge verbraucht hat. EINE Zeile wird immer
## genommen - kleiner als einzeilig wird eine Kennung nicht.
func _fit_info_title(u: float, width: float, room: float) -> float:
	if _info_title == null or not is_instance_valid(_info_title):
		return 0.0
	var font := _info_title.get_theme_font("font")
	var spacing := _info_title.get_theme_constant("line_spacing")
	var used := 0.0
	for step in INFO_TITLE_STEPS:
		var px := int(u * float(step))
		_info_title.add_theme_font_size_override("font_size", px)
		if font == null or px <= 0:
			return 0.0
		used = text_block_height(font, _info_title.text, width, px, spacing)
		if used <= room * INFO_TITLE_SHARE \
				or text_block_lines(font, _info_title.text, width, px) <= 1:
			break
	if not _info_title.visible:
		return 0.0
	return used + u * INFO_LINE_GAP

## Baut den Schirm in die linke Flanke des Bandes - er gehört zum Band wie das
## Blech und der Sitz und wird mit ihm neu gelegt.
func _build_info_screen(band: Control, u: float) -> void:
	var standing_title := _info_title_text()  # VOR dem Neubau: gleich sind die Zeilen fort
	var standing_body := _info_body_text()
	var rect := info_screen_rect()
	var screen := Panel.new()
	screen.name = "InfoScreen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override("panel", TableScreen.window_style())
	screen.position = rect.position - band.position
	screen.size = rect.size
	band.add_child(screen)
	_info_screen = screen
	var column := VBoxContainer.new()
	column.name = "InfoText"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = u * INFO_PAD
	column.offset_right = -u * INFO_PAD
	column.offset_top = u * INFO_PAD
	column.offset_bottom = -u * INFO_PAD
	column.add_theme_constant_override("separation", int(u * INFO_LINE_GAP))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(column)
	_info_title = _info_label(int(u * INFO_TITLE), CasinoStyle.GOLD)
	column.add_child(_info_title)
	_info_body = _info_label(int(u * INFO_BODY), CasinoStyle.CREAM)
	column.add_child(_info_body)
	show_hover_info(standing_title, standing_body, _info_tint)

## Eine Zeile des Schirms: mittig, umbrechend, ohne Maus.
func _info_label(px: int, tint: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(_info_text_width(), 0)
	label.visible = false
	if tint == CasinoStyle.GOLD:
		CasinoStyle.style_score_label(label, px, tint)
	else:
		CasinoStyle.style_body_label(label, px, tint)
	return label

## --- Der SERIEN-SCHIRM ---------------------------------------------------------
## Er steht in der rechten Ecke des Bandes und sagt zwei Sachen: wie lang die
## Schaltung sein darf und was die gesteckten Katalysatoren zulegen.

## Breite des Schirms: was von der rechten Flanke bleibt, wenn der Sitz mit seinen
## beiden Nähten darin steht. Er endet bündig an der Fensterkante.
func series_width() -> float:
	var u := maxf(size.x, 200.0) / 100.0
	var flank := (size.x - console_size(u).x) * 0.5
	return maxf(flank - u * (ACTION_WIDTH + ACTION_GAP * 2.0), u * SERIES_MIN_WIDTH)

func series_screen_rect() -> Rect2:
	var u := maxf(size.x, 200.0) / 100.0
	var top := size.y + u * CONSOLE_SHELF_GAP
	var width := series_width()
	return Rect2(Vector2(size.x - width, top),
		Vector2(width, maxf(shelf_top() - u * CONSOLE_SHELF_GAP - top, u * 6.0)))

## Die Zeilen, die auf dem Schirm stehen: die Länge der Schaltung und je
## gestecktem Katalysator seine Wirkzeile - die Namensquelle ist Pack, hier wird
## nichts zweitformuliert.
func series_lines() -> Array[String]:
	var lines: Array[String] = []
	if run == null:
		return lines
	var cards := _slot_cards()
	if cards.is_empty():
		return lines
	lines.append("%d / %d Slots" % [cards.size(), slot_count()])
	var seen := {}
	for card in cards:
		var catalyst := String(card.get("catalyst", ""))
		if catalyst == "" or seen.has(catalyst):
			continue
		seen[catalyst] = true
		lines.append("%s: %s" % [Pack.catalyst_name(catalyst),
			Pack.catalyst_effect(catalyst)])
	if needs_second() and second_die() == null:
		lines.append("Doppelmatrize: zweiten Würfel wählen")
	return lines

## Was gerade auf dem Schirm steht ("" = er ist dunkel).
func series_text() -> String:
	var lines := series_lines()
	if lines.is_empty():
		return ""
	return "\n".join(lines)

func _build_series_screen(band: Control, u: float) -> void:
	var rect := series_screen_rect()
	var screen := Panel.new()
	screen.name = "SeriesScreen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override("panel", TableScreen.window_style())
	screen.position = rect.position - band.position
	screen.size = rect.size
	band.add_child(screen)
	_series_screen = screen
	var column := VBoxContainer.new()
	column.name = "SeriesText"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = u * INFO_PAD
	column.offset_right = -u * INFO_PAD
	column.offset_top = u * INFO_PAD
	column.offset_bottom = -u * INFO_PAD
	column.add_theme_constant_override("separation", int(u * INFO_LINE_GAP))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(column)
	_series_title = _series_label(int(u * float(SERIES_TITLE_STEPS[0])), CasinoStyle.GOLD)
	_series_title.text = SERIES_HEAD
	column.add_child(_series_title)
	_series_body = _series_body_label(int(u * float(SERIES_BODY_STEPS[0])))
	column.add_child(_series_body)
	_fit_series_title()
	_sync_series_screen()

## Der Kopf ist EIN Wort: er nimmt den ersten Grad, bei dem er noch ohne Umbruch
## in den Schirm paßt.
func _fit_series_title() -> int:
	var u := maxf(size.x, 200.0) / 100.0
	var width := _series_text_width()
	var font := _series_title.get_theme_font("font")
	var px := int(u * float(SERIES_TITLE_STEPS[0]))
	for step in SERIES_TITLE_STEPS:
		px = int(u * float(step))
		if font == null or px <= 0:
			break
		if font.get_string_size(SERIES_HEAD, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
			break
	_series_title.add_theme_font_size_override("font_size", px)
	return px

func _series_label(px: int, tint: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(_series_text_width(), 0)
	label.visible = false
	if tint == CasinoStyle.GOLD:
		CasinoStyle.style_score_label(label, px, tint)
	else:
		CasinoStyle.style_body_label(label, px, tint)
	return label

## Die Zeilen sind ein RichTextLabel, kein Label: Wörter darin sind Lexikon-
## Verweise wie im Laden-Tooltip - gefärbt und klickbar. Darum STOP statt IGNORE.
func _series_body_label(px: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.custom_minimum_size = Vector2(_series_text_width(), 0)
	label.visible = false
	CasinoStyle.style_rich_body(label, px, CasinoStyle.CREAM)
	label.meta_clicked.connect(func(meta: Variant) -> void:
		lexikon_requested.emit(String(meta)))
	return label

func _series_text_width() -> float:
	var u := maxf(size.x, 200.0) / 100.0
	return maxf(series_width() - u * INFO_PAD * 2.0, u * 4.0)

## Schreibt den Schirm neu. Der Schirm selbst STEHT immer - nur seine Zeilen
## kommen und gehen, und sein Rechteck rührt sich dabei nie.
func _sync_series_screen() -> void:
	if _series_body == null or not is_instance_valid(_series_body):
		return
	var text := series_text()
	_series_body.text = "[center]%s[/center]" % Lexikon.linkify(text)
	_series_body.visible = text != ""
	_series_title.visible = text != ""
	_fit_series_body(text)

## Derselbe Einpasser wie beim Hinweis-Schirm, nur an dessen viel schmalerem
## Bruder gemessen. Gemessen wird der NACKTE Text, nicht der verlinkte - das
## BBCode-Markup ist keine Schrift.
func _fit_series_body(plain: String) -> void:
	var u := maxf(size.x, 200.0) / 100.0
	var width := _series_text_width()
	var font := _series_body.get_theme_font("normal_font")
	var room := (series_screen_rect().size.y - u * INFO_PAD * 2.0) * SERIES_ROOM_SHARE
	if _series_title.visible and font != null:
		room -= font.get_multiline_string_size(_series_title.text,
			HORIZONTAL_ALIGNMENT_CENTER, width,
			_series_title.get_theme_font_size("font_size")).y + u * INFO_LINE_GAP
	for step in SERIES_BODY_STEPS:
		var px := int(u * float(step))
		if font == null or px <= 0:
			_series_body.add_theme_font_size_override("normal_font_size", px)
			return
		var block := font.get_multiline_string_size(plain,
			HORIZONTAL_ALIGNMENT_CENTER, width, px)
		_series_body.add_theme_font_size_override("normal_font_size", px)
		if block.y <= room:
			return

## Der stehende Text übersteht den Neuaufbau des Bandes.
func _info_title_text() -> String:
	return _info_title.text if _info_title != null and is_instance_valid(_info_title) else ""

func _info_body_text() -> String:
	return _info_body.text if _info_body != null and is_instance_valid(_info_body) else ""

## Baut das Fenster neu und meldet danach, wo die Würfel-Bühne jetzt liegt - der
## ECHTE Würfel darüber gehört scene_root, nicht diesem Fenster.
func refresh() -> void:
	_refresh_content()
	die_stages_changed.emit()

func _refresh_content() -> void:
	if not is_inside_tree():
		return
	_slot_buttons.clear()
	_slit_panels.clear()
	_card_panels.clear()
	_portals.clear()
	_stage_host = null
	_net_host = null
	_pool_grid = null
	_free_own(_drawer)  # Band und Magazin hängen am Panel, nicht am Inhalt
	_drawer = null
	_free_own(_band)
	_band = null
	_prune_series()
	var u := maxf(size.x, 200.0) / 100.0
	_free_own(_content)
	_content = null  # queue_free wirkt erst am Bildende - sonst hängt hier ein Zombie
	_console = null
	_action_button = null

	# Die Schürze steht IMMER: Konsolen-Band und Magazin gehören zur Bank, nicht zu
	# einem Ablauf - gesperrt wird nur, was gerade niemand anfassen darf.
	_build_series_band(u)
	_build_drawer(u)

	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = u * CONTENT_MARGIN_X
	_content.offset_right = -u * CONTENT_MARGIN_X
	_content.offset_top = u * CONTENT_MARGIN_Y
	_content.offset_bottom = -u * CONTENT_MARGIN_Y
	_content.add_theme_constant_override("separation", int(u * CONTENT_GAP))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	# Kein WERKSTATT-Titel: die Seite gehört der Zielwahl.
	_build_body(u)
	_ensure_scanner(u)  # zuletzt: der Schlitten liegt über allem

## Der SCHLITTEN wird nie neu gebaut, nur neu ausgelegt - sonst risse jeder
## Neuaufbau des Fensters die laufende Fahrt samt Zähl-Takt ab.
func _ensure_scanner(u: float) -> void:
	if _scanner == null or not is_instance_valid(_scanner):
		_scanner = SeriesScannerView.new()
		add_child(_scanner)
	_net = _scanner.net
	_scanner.lay(u * CHOICE_CELL)
	move_child(_scanner, get_child_count() - 1)
	if not burning():
		_refresh_preview_net()
	_sync_scanner_park()

## Sein Platz, solange er nicht fährt: die Mitte des Parkplatzes in der Säule.
func _sync_scanner_park() -> void:
	if _scanner == null or not is_instance_valid(_scanner) or _scanner.riding():
		return
	if _net_host == null or not is_instance_valid(_net_host):
		return
	var host := _net_host.get_global_rect()
	if host.size.x <= 0.0:
		return
	_scanner.seat_at(host.get_center() - get_global_rect().position)

## Hängt ein eigenes Kind aus und gibt es frei; queue_free wirkt erst am
## Bildende, ein Neuaufbau träfe sonst auf seinen eigenen Vorgänger.
func _free_own(node: Node) -> void:
	if node != null and is_instance_valid(node):
		remove_child(node)
		node.queue_free()

# --- Grundseite: Ziel-Säule und Pool-Raster -------------------------------------

## Der Kopfraum, dann die Zeile: links die Ziel-Säule, rechts das Raster.
func _build_body(u: float) -> void:
	var head := Control.new()
	head.name = "StageHeadRoom"
	head.custom_minimum_size = Vector2(0, u * STAGE_HEAD_ROOM)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(head)
	var row := HBoxContainer.new()
	row.name = "BenchBody"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(u * BODY_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(row)
	row.add_child(_target_column(u))
	row.add_child(_pool_column(u))

## Die ZIEL-SÄULE: oben die leere Projektor-Bühne (über ihr schwebt der echte
## Würfel im Stasis-Feld, scene_root stellt ihn auf), darunter das Summen-Netz.
func _target_column(u: float) -> Control:
	var column := VBoxContainer.new()
	column.name = "TargetColumn"
	column.add_theme_constant_override("separation", int(u * 0.4))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stage := Control.new()
	stage.name = "TargetStage"
	stage.custom_minimum_size = Vector2(DieNetView.net_size(u * CHOICE_CELL).x,
		u * STAGE_HEIGHT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage)
	_stage_host = stage

	var air := Control.new()
	air.name = "TargetNetGap"
	air.custom_minimum_size = Vector2(0, u * STAGE_NET_GAP)
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(air)

	# Der PARKPLATZ des Schlittens: ein leerer Platz in Netzgröße. Das Netz selbst
	# fährt, dieser Platz nie - er ist die gemeldete Netzmitte.
	var host := Control.new()
	host.name = "TargetNet"
	host.custom_minimum_size = DieNetView.net_size(u * CHOICE_CELL)
	host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_net_host = host
	column.add_child(host)
	column.add_child(_slack("TargetSlack"))
	return column

## Das POOL-RASTER: Sitz i = Zelle i, die Grammatik der Glas-Ansicht - nur schlicht
## im Fenster statt am Gruben-Glas. Ein Tipp wählt, derselbe Tipp wählt ab.
func _pool_column(u: float) -> Control:
	# Ein CenterContainer, kein nacktes Control: ein Raster ohne gesetzte Größe
	# fiele sonst auf 0 zusammen und legte seine Kacheln übereinander.
	var host := CenterContainer.new()
	host.name = "PoolChoice"
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var defs := pool_defs()
	var rows := maxi(ceili(float(defs.size()) / float(POOL_COLUMNS)), 1)
	var avail := Vector2(maxf(size.x - u * (CONTENT_MARGIN_X * 2.0 + BODY_GAP)
			- DieNetView.net_size(u * CHOICE_CELL).x, u * 20.0),
		maxf(size.y - u * (CONTENT_MARGIN_Y * 2.0 + STAGE_HEAD_ROOM), u * 20.0))
	var grid := DiceGridView.new()
	grid.name = "PoolGrid"
	grid.place(POOL_COLUMNS, DiceGridView.unit_for(POOL_COLUMNS, rows, avail), true)
	grid.fill(defs)
	grid.set_highlights(_chosen_indices())
	grid.slot_pressed.connect(_on_pool_slot_pressed)
	host.add_child(grid)
	_pool_grid = grid
	return host

## Die Würfel des Vorrats (ohne Lauf leer) - das Raster IST der Pool.
func pool_defs() -> Array[DieDefinition]:
	if run == null:
		return [] as Array[DieDefinition]
	return run.owned_pool

## Die gewählten Plätze (Ziel zuerst) - das Raster hebt sie hervor.
func _chosen_indices() -> Array[int]:
	var chosen: Array[int] = []
	if _target_index >= 0:
		chosen.append(_target_index)
	if _second_index >= 0:
		chosen.append(_second_index)
	return chosen

## Der gewählte Zielwürfel (null = keiner).
func target_die() -> DieDefinition:
	var defs := pool_defs()
	if _target_index < 0 or _target_index >= defs.size():
		return null
	return defs[_target_index]

## Der zweite Würfel der Doppelmatrize (null = keiner / keine gesteckt).
func second_die() -> DieDefinition:
	var defs := pool_defs()
	if not needs_second() or _second_index < 0 or _second_index >= defs.size():
		return null
	return defs[_second_index]

func target_index() -> int:
	return _target_index

func second_index() -> int:
	return _second_index

## Steckt eine Doppelmatrize in der Reihe? Dann verlangt der Griff einen ZWEITEN
## Würfel - die Zweitprojektion braucht ein Ziel.
func needs_second() -> bool:
	for card in _slot_cards():
		if String(card.get("catalyst", "")) == Pack.CATALYST_MATRIX:
			return true
	return false

## Der Tipp im Raster: derselbe Platz wählt ab, ein anderer wechselt. Steckt eine
## Doppelmatrize und steht das Ziel schon, wählt der nächste Tipp den ZWEITEN.
func _on_pool_slot_pressed(index: int) -> void:
	if editing_locked or burning():
		return
	if index == _target_index:
		_target_index = -1
		_second_index = -1
		_announce_target()
		return
	if index == _second_index:
		_second_index = -1
		refresh()
		return
	if _target_index >= 0 and needs_second():
		_second_index = index
		refresh()
		return
	_target_index = index
	_announce_target()

## Wählt den Zielwürfel programmatisch (Tests, Debug) - am Tisch tippt der Spieler.
func choose_target(index: int) -> void:
	_on_pool_slot_pressed(index)

func _announce_target() -> void:
	refresh()
	target_chosen.emit(target_die())

## Der Zielwürfel, den das Summen-Netz zeigt: während der Zeremonie der Stand VOR
## dem Griff (nur so kann das Netz von 0 hochticken), sonst der echte.
func preview_target() -> DieDefinition:
	if burning():
		return _burn_die
	return target_die()

## DIE LIVE-VORSCHAU: was die gesteckte Serie auf dem Zielwürfel ergäbe. Sie ist
## buchstäblich dieselbe Rechnung, die der Griff bucht ({} = keine).
## Während der Zeremonie zählt sie nur die Karten, die die Welle schon erfaßt hat.
func preview() -> Dictionary:
	if burning():
		return SeriesResolver.resolve(_burn_nets_so_far(), _burn_die, _burn_terms)
	if run == null or target_die() == null or _series.is_empty():
		return {}
	return run.resolve_series(_series, target_die())

## Die Seiten, die die überfahrene Karte beiträgt (leer = kein Hover).
func _highlight_faces() -> Array[int]:
	var cards := _slot_cards()
	if _hover_slot < 0 or _hover_slot >= cards.size():
		return [] as Array[int]
	var faces: Array[int] = []
	var net: Array = cards[_hover_slot].get("net", [])
	for face in StampNet.FACES:
		if StampNet.is_filled(StampNet.cell_at(net, face)):
			faces.append(face)
	return faces

## Display-Pixel der Netz-Mitte (Vector2(-1,-1) = die Säule steht gerade nicht) -
## dort stellt scene_root den echten Würfel darüber auf. Gemeldet wird der
## PARKPLATZ, nie der fahrende Schlitten: sonst zöge die Fahrt den Würfel mit.
func target_net_center() -> Vector2:
	if _net_host == null or not is_instance_valid(_net_host):
		return Vector2(-1, -1)
	return _net_host.get_global_rect().get_center()

## Die ZEILE dazu: Bildschirm-Höhe des Projektors. Sie liegt im Fenster, ein Stück
## unter seinem oberen Rand. Ohne Layout die Fenstermitte.
func target_projector_y() -> float:
	if _stage_host != null and is_instance_valid(_stage_host):
		return _stage_host.get_global_rect().get_center().y
	return get_global_rect().get_center().y

## Steht die Bank gerade so da, dass ein Würfel darüber schweben darf? Sie steht
## IMMER - die Ziel-Säule ist Möbel, kein Ablauf. (Die KAMERA fragt hier nicht mit.)
func bench_open() -> bool:
	return true

## Das Konsolen-Band: es liegt GANZ unter dem Fenster, eine Naht unter seiner
## Kante - und dieselbe Naht trennt es vom Magazin.
func console_band_rect() -> Rect2:
	var u := maxf(size.x, 200.0) / 100.0
	return Rect2(Vector2(0.0, size.y + u * CONSOLE_SHELF_GAP),
		Vector2(size.x, console_size(u).y))

## Fenster PLUS Schürze in Display-Pixeln: alles, was zur Werkbank gehört.
func bench_rect() -> Rect2:
	var rect := get_global_rect()
	rect.size.y = maxf(rect.size.y, apron_bottom_y())
	return rect

## Breite/Höhe des Fensters, bei dem die GRUNDSEITE bündig aufgeht: links die
## Ziel-Säule (so breit wie ihr Netz), rechts der Platz des 30er-Rasters. Die
## Breite ist damit nicht gesetzt, sondern gelöst.
## Alles außer der Fensterhöhe misst in u = Breite/100, die Gleichung schließt
## sich also über die Breite; die Höhe kürzt sich heraus.
static func dossier_aspect() -> float:
	var rows := ceili(float(GameRun.POOL_SIZE) / float(POOL_COLUMNS))
	var span := DiceGridView.detail_span(POOL_COLUMNS, rows)
	var ratio := span.x / span.y
	# Was die Breite VOR dem Raster verbraucht: beide Inhaltsränder, die
	# Netzspalte und die Fuge dazwischen.
	var used := CONTENT_MARGIN_X * 2.0 + DieNetView.net_size(CHOICE_CELL).x + BODY_GAP
	# Oben und unten steht auf DIESER Seite derselbe Rand wie zur Seite.
	return 100.0 * ratio / (100.0 - used + ratio * CONTENT_MARGIN_X * 2.0)

## Wie tief die Schürze unter der Fensterkante hängt, in Einheiten u: Naht, ganzes
## Konsolen-Band, Naht, Magazin-Streifen. scene_root löst damit die Fensterhöhe
## aus der Spanne bis zur Hub-Unterkante auf.
## Das Band wird in ECHTEN u gemessen und zurückgerechnet: seit der Schlitz die
## Kappe der Kassette schluckt, hängt seine Höhe an einem Weltmaß (data_cell_px).
func apron_units() -> float:
	var u := maxf(size.x, 200.0) / 100.0
	return CONSOLE_SHELF_GAP * 2.0 + console_size(u).y / u + SHELF_STRIP_UNITS

## Unterkante der Schürze in Fenster-Koordinaten (siehe apron_bottom).
func apron_bottom_y() -> float:
	if apron_bottom > size.y:
		return apron_bottom
	return size.y + maxf(size.x, 200.0) / 100.0 * apron_units()

# --- Die SERIEN-SLOT-REIHE -------------------------------------------------------

## Wie viele Slots die Reihe trägt: die Serienlänge des Laufs, mindestens so
## viele, wie gerade stecken (eine geschrumpfte Leiter wirft keine Karte fort).
func slot_count() -> int:
	var slots := run.series_slots() if run != null else FALLBACK_SLOTS
	return maxi(slots, _slot_cards().size())

## Die Serien-Reihe als flache Leiste, eingelassen in ihr Konsolen-Blech. Ein
## belegter Slot trägt seine Kassette samt Prägenetz; ein Klick nimmt sie zurück
## ins Magazin, ein ZUG sortiert die Reihe um.
## Das Blech steht MITTIG im Band, der Handlungs-Sitz in dessen rechter Flanke.
func _build_series_band(u: float) -> void:
	var band := Control.new()
	band.name = "SeriesBand"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)  # direktes Kind: das Band liegt auf der Fensterkante
	_band = band
	var rect := console_band_rect()
	band.position = rect.position
	band.size = rect.size
	var console := _series_console(u)
	band.add_child(console)
	console.add_child(_series_rail(u))
	_build_action_seat(band, u)
	_build_info_screen(band, u)
	_build_series_screen(band, u)
	var row := HBoxContainer.new()
	row.name = "SeriesSlots"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = u * CONSOLE_PAD_X
	row.offset_right = -u * CONSOLE_PAD_X
	row.offset_top = u * CONSOLE_PAD_Y
	row.offset_bottom = -u * CONSOLE_PAD_Y
	row.add_theme_constant_override("separation", int(u * BENCH_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	console.add_child(row)
	var cards := _slot_cards()
	var slots := slot_count()
	_portals.resize(slots)
	for i in slots:
		row.add_child(_series_slot(i, u, cards[i] if i < cards.size() else {}))

## Das Blech hinter der Reihe: erhabene Platte in neutralem Dunkelmetall. Es hängt
## mittig im Band - der Sitz daneben darf es nicht verschieben.
func _series_console(u: float) -> Panel:
	var console := Panel.new()
	console.name = "SeriesConsole"
	console.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var span := console_size(u)
	console.anchor_left = 0.5
	console.anchor_right = 0.5
	console.anchor_bottom = 1.0
	console.offset_left = -span.x * 0.5
	console.offset_right = span.x * 0.5
	_console = console
	var radius := int(u * CONSOLE_RADIUS)
	var box := StyleBoxFlat.new()
	box.bg_color = CONSOLE_BASE
	box.set_corner_radius_all(radius)
	box.shadow_color = PackDrawerView.LIP_DROP
	box.shadow_size = maxi(2, int(u * PackDrawerView.LIP_DROP_SIZE))
	box.shadow_offset = Vector2(0.0, maxf(2.0, u * PackDrawerView.LIP_DROP_DOWN))
	console.add_theme_stylebox_override("panel", box)
	var edge := maxi(2, int(u * CONSOLE_EDGE))
	console.add_child(PackDrawerView.edge_band("ConsoleLight",
		CONSOLE_BASE.lerp(CONSOLE_SHEEN, CONSOLE_SHEEN_MIX), edge, radius, true))
	console.add_child(PackDrawerView.edge_band("ConsoleShade", CONSOLE_SHADOW,
		edge, radius, false))
	return console

## Die SCHIENE über der Reihe: der Weg des Schlittens, als Strich im oberen Rand
## des Blechs. Sie liegt IN CONSOLE_PAD_Y - die Reihe rückt für sie nicht.
func _series_rail(u: float) -> Panel:
	var rail := Panel.new()
	rail.name = "ScanRail"
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rail.offset_left = u * CONSOLE_PAD_X * 0.5
	rail.offset_right = -u * CONSOLE_PAD_X * 0.5
	rail.offset_top = u * RAIL_TOP
	rail.offset_bottom = u * (RAIL_TOP + RAIL_HEIGHT)
	var box := StyleBoxFlat.new()
	box.bg_color = RAIL_TINT
	box.set_corner_radius_all(maxi(1, int(u * RAIL_HEIGHT * 0.5)))
	rail.add_theme_stylebox_override("panel", box)
	return rail

## Maße des Blechs: die Slots mit ihrer Luft dazwischen, plus Rand.
func console_size(u: float) -> Vector2:
	var slot := socket_size(u)
	var columns := float(slot_count())
	var row := columns * slot.x + (columns - 1.0) * u * BENCH_GAP
	return Vector2(row + u * CONSOLE_PAD_X * 2.0, slot.y + u * CONSOLE_PAD_Y * 2.0)

## Die Vertiefung, in der Karte und Schlitz eines Slots liegen.
func _slot_pocket(u: float) -> Panel:
	var pocket := Panel.new()
	pocket.name = "SlotPocket"
	pocket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pocket.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bleed := u * POCKET_BLEED
	pocket.offset_left = -bleed
	pocket.offset_top = -bleed
	pocket.offset_right = bleed
	pocket.offset_bottom = bleed
	var radius := int(u * POCKET_RADIUS)
	var box := StyleBoxFlat.new()
	box.bg_color = POCKET_BASE
	box.set_corner_radius_all(radius)
	pocket.add_theme_stylebox_override("panel", box)
	var edge := maxi(2, int(u * POCKET_EDGE))
	pocket.add_child(PackDrawerView.edge_band("PocketShade", POCKET_SHADOW, edge, radius, true))
	pocket.add_child(PackDrawerView.edge_band("PocketLight", POCKET_SHEEN, edge, radius, false))
	return pocket

## Ein SERIEN-SLOT: seine Tasche im Blech, darin oben die senkrechte Kassette (das
## Prägenetz und der Name) und darunter der Leseschlitz. Der KNOPF spannt alles und
## fängt allein Klick und Zeiger - gezeichnet wird von seinen Kindern.
func _series_slot(index: int, u: float, card: Dictionary) -> Button:
	var slot := Button.new()
	slot.name = "SeriesSlot"
	slot.focus_mode = Control.FOCUS_NONE
	slot.custom_minimum_size = socket_size(u)
	slot.disabled = true
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		slot.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	slot.add_child(_slot_pocket(u))

	var column := VBoxContainer.new()
	column.name = "SlotColumn"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", int(u * SLIT_DISPLAY_GAP))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var seat := _slot_card(card, u, index)
	column.add_child(seat)
	var slit := Panel.new()
	slit.name = "Slit"
	slit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slit.custom_minimum_size = slit_size(u)
	slit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slit.add_theme_stylebox_override("panel", _slit_box(_slot_tint(card), u))
	column.add_child(slit)
	slot.add_child(column)

	_arm_slot(slot, index, card)
	_slot_buttons.append(slot)
	_slit_panels.append(slit)
	_card_panels.append(seat)
	return slot

## Ein Klick auf den belegten Slot nimmt seine Karte zurück ins Magazin, ein ZUG
## legt sie an eine andere Stelle der Reihe - dieselbe Trennung wie im Vorrat:
## gezogen sortiert um, getippt handelt.
func _arm_slot(slot: Button, index: int, card: Dictionary) -> void:
	if card.is_empty() or burning():
		return
	slot.disabled = editing_locked
	slot.tooltip_text = "%s\n%s" % [String(card.get("name", "")), String(card.get("body", ""))]
	slot.set_meta("title", String(card.get("name", "")))
	slot.set_meta("body", _card_hint_body(card))
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.pressed.connect(clear_press_slot.bind(index))
	slot.gui_input.connect(_on_slot_input.bind(index))

## Die Auskunft einer gesteckten Karte: ihre Wirkzeile plus die Zeile ihres
## Prägenetzes - die eine Textquelle ist Pack, hier wird nichts zweitformuliert.
static func _card_hint_body(card: Dictionary) -> String:
	var body := String(card.get("body", ""))
	var line := String(card.get("line", ""))
	if line == "" or body.contains(line):
		return body
	return "%s\n%s" % [body, line]

## Der KARTENPLATZ eines Slots: er steht fest (an ihm messen die Anker), und die
## Kassette darin FÄHRT - beim Einsetzen aus dem Leseschlitz hoch, beim Umlegen
## seitlich. Beides ist reines Licht: der Platz schuldet nichts, wenn ein Tween
## abbricht.
func _slot_card(card: Dictionary, u: float, index: int) -> Control:
	var span := card_size(u)
	var seat := Control.new()
	seat.name = "SlotCardSeat"
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seat.custom_minimum_size = span
	var face := _card_face(card, u, index)
	face.size = span
	seat.add_child(face)
	var uid := int(card.get("uid", 0))
	var rise: bool = uid > 0 and bool(_fresh_slots.erase(uid))
	var slide := float(_slide_from.get(uid, 0.0)) if uid > 0 else 0.0
	if uid > 0:
		_slide_from.erase(uid)
	if rise:
		# EINSETZEN: sie steigt aus ihrem Schlitz ins Bild und glüht dabei an.
		seat.clip_contents = true
		face.position = Vector2(0.0, span.y)
		_glide_card(face, CARD_RISE_TIME)
		var portal: PressPortalView = _portals[index] if index < _portals.size() else null
		if portal != null and is_instance_valid(portal):
			portal.charge()
	elif not is_zero_approx(slide):
		face.position = Vector2(slide, 0.0)
		_glide_card(face, CARD_SLIDE_TIME)
	return seat

## Die Fahrt einer Karte auf ihren Platz. Der Tween hängt an der KARTE, nicht am
## Fenster: ein Neuaufbau nimmt ihn mit sich.
func _glide_card(face: Control, time: float) -> void:
	var glide := face.create_tween()
	glide.tween_property(face, "position", Vector2.ZERO, time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Die KASSETTE selbst: senkrecht, oben ihr Mini-Netz, darunter ihr Name.
## Ein leerer Slot bleibt dunkel - dort steht keine Karte, die etwas sagen könnte.
## index < 0 = ein Abbild ohne Slot (das sinkende Rückwurf-Bild).
func _card_face(card: Dictionary, u: float, index: int) -> Panel:
	var span := card_size(u)
	var tint := _slot_tint(card)
	var field := Panel.new()
	field.name = "SlotCard"
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.clip_contents = true
	field.custom_minimum_size = span
	field.add_theme_stylebox_override("panel", _card_box(tint, u))
	var portal := PressPortalView.new()
	portal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.add_child(portal)
	portal.setup(String(card.get("sort", "")), tint)
	if index >= 0 and index < _portals.size():
		_portals[index] = portal
	if card.is_empty():
		return field
	var pad := u * CARD_PAD
	var net_room := Vector2(span.x - pad * 2.0, span.y * CARD_NET_SHARE)
	var mini := PressNetView.stamp_net(card.get("net", []),
		DieNetView.cell_for(net_room), tint)
	mini.position = Vector2((span.x - mini.size.x) * 0.5, pad)
	field.add_child(mini)
	field.add_child(_card_name(String(card.get("name", "")), span,
		pad + mini.size.y, tint, u))
	return field

## Der Name unter dem Netz: er paßt sich in die Karte ein, statt sie zu verbreitern.
func _card_name(text: String, span: Vector2, top: float, tint: Color, u: float) -> Label:
	var label := Label.new()
	label.name = "CardName"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.text = text
	label.position = Vector2(u * CARD_PAD, top)
	label.size = Vector2(span.x - u * CARD_PAD * 2.0, maxf(span.y - top - u * CARD_PAD, 1.0))
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", CasinoStyle.INK)
	label.add_theme_constant_override("outline_size", maxi(1, int(u * 0.16)))
	var font := label.get_theme_font("font")
	var spacing := label.get_theme_constant("line_spacing")
	for step in CARD_NAME_STEPS:
		var px := int(u * float(step))
		label.add_theme_font_size_override("font_size", px)
		if font == null or px <= 0:
			break
		if text_block_height(font, text, label.size.x, px, spacing) <= label.size.y:
			break
	return label

## Maße einer Karte, eines ganzen Slots und des Schlitzes allein.
func card_size(u: float) -> Vector2:
	return Vector2(maxf(u * CARD_WIDTH, slit_size(u).x), u * CARD_HEIGHT)

func socket_size(u: float) -> Vector2:
	var card := card_size(u)
	return Vector2(card.x, card.y + u * SLIT_DISPLAY_GAP + slit_size(u).y)

## Der Schlitz: so groß, dass die Kappe der Zelle hindurchgeht - in ihrem festen
## Anzeigemaß, denn genau so steckt sie später darin. Bewusst flach.
func slit_size(u: float) -> Vector2:
	var cap := data_cell_px * PackDrawerView.CASSETTE_SCALE * SOCKET_ROOM
	return Vector2(maxf(u * CARD_WIDTH, cap.x), maxf(u * SLIT_HEIGHT, cap.y))

## Die Farbe eines Slots: leer der stumpfe Rand, belegt AMBER für Operatoren und
## sonst die Sortenfarbe - eine Quelle für Schlitzrand und Kartenrahmen.
func _slot_tint(card: Dictionary) -> Color:
	if card.is_empty():
		return SOCKET_RIM
	if String(card.get("operator", "")) != "":
		return OPERATOR_TINT
	return PackDrawerView.COLORS.get(String(card.get("sort", "")), SOCKET_LIVE_RIM)

func _slit_box(rim: Color, u: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = SOCKET_BG
	box.border_color = rim
	box.set_border_width_all(maxi(1, int(u * 0.18)))
	box.set_corner_radius_all(int(slit_size(u).y * 0.35))
	return box

func _card_box(rim: Color, u: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = SOCKET_BG
	box.border_color = Color(rim.r, rim.g, rim.b, rim.a * 0.7)
	box.set_border_width_all(maxi(1, int(u * 0.14)))
	box.set_corner_radius_all(int(u * 0.4))
	return box

## Die Sorten der belegten Slots, in Reihenfolge - scene_root legt daran seine
## Zellen ab.
func press_slot_sorts() -> Array[String]:
	var sorts: Array[String] = []
	for card in _slot_cards():
		sorts.append(String(card.get("sort", "")))
	return sorts

## Die uids derselben Reihe - scene_root übernimmt daran die Magazin-Körper in die
## Schlitze und gibt sie beim Auswerfen an ihre Plätze zurück.
func press_slot_uids() -> Array[int]:
	var uids: Array[int] = []
	for card in _slot_cards():
		uids.append(int(card.get("uid", 0)))
	return uids

## Display-Pixel der SCHLITZ-Mitten (leere eingeschlossen) - dort steckt die Zelle
## eines belegten Slots. Nicht die Knopfmitte: der Knopf reicht bis über die Karte.
func press_slot_anchors() -> Array[Vector2]:
	var anchors: Array[Vector2] = []
	for slit in _slit_panels:
		if is_instance_valid(slit):
			anchors.append(slit.get_global_rect().get_center())
	return anchors

## Display-Pixel der KARTENPLÄTZE derselben Reihe (leere eingeschlossen) - sie
## sind die Stützpunkte der Schiene, und der Platz steht still, während die
## Kassette darin fährt.
func press_display_anchors() -> Array[Vector2]:
	var anchors: Array[Vector2] = []
	for field in _card_panels:
		if is_instance_valid(field):
			anchors.append(field.get_global_rect().get_center())
	return anchors

## Das Magazin ist zu: unterschrieben oder die Zeremonie läuft.
func shelf_locked() -> bool:
	return editing_locked or burning()

## Legt GENAU diese Karte in den nächsten freien Serien-Slot. false = keine solche
## Karte, kein Platz frei oder das Magazin ist zu.
func slot_pack(uid: int) -> bool:
	if run == null or shelf_locked():
		return false
	if _series.size() >= slot_count():
		return false
	var pack := run.pack_by_uid(uid)
	if pack == null:
		return false
	if _series.has(uid) or _pending_arrivals.has(uid):
		return false
	_series.append(uid)
	_fresh_slots[uid] = true  # sie FÄHRT beim nächsten Aufbau aus dem Schlitz hoch
	refresh()
	return true

## Legt die VORDERSTE Karte einer Sorte ein - der programmatische Griff (Tests,
## Debug); am Tisch wählt der Spieler seine Kassette selbst.
func slot_pack_from_stack(stack_category: String) -> bool:
	if run == null:
		return false
	for pack in run.owned_packs:
		if _series.has(pack.pack_uid) or _pending_arrivals.has(pack.pack_uid):
			continue
		if not Pack.pack_belongs(pack, stack_category):
			continue
		return slot_pack(pack.pack_uid)
	return false

## Nimmt eine Karte wieder aus ihrem Slot - sie liegt danach wieder auf ihrem
## Magazin-Platz. Gemeldet wird VOR dem Neuaufbau: die Zelle dieses Platzes muss
## sich ausklinken, bevor die Sockel neu abgezählt werden.
func clear_press_slot(index: int) -> void:
	if index < 0 or index >= _series.size() or editing_locked or burning():
		return
	var uid := _series[index]
	var before := _series.duplicate()
	_sink_card(index)  # das Abbild fährt zurück in den Schlitz, solange sie noch steht
	_series.remove_at(index)
	_mark_slides(before)
	pack_unslotted.emit(index, uid)
	refresh()

## Die zurückgeworfene Karte SINKT denselben Weg, den sie kam: ein Abbild von ihr
## fährt in den Schlitz zurück und erlischt. Es hängt am Fenster, nicht am Band -
## der Neuaufbau darf es nicht mitreißen -, und es räumt sich selbst weg.
func _sink_card(index: int) -> void:
	if index < 0 or index >= _card_panels.size():
		return
	var seat: Control = _card_panels[index]
	var cards := _slot_cards()
	if seat == null or not is_instance_valid(seat) or index >= cards.size():
		return
	var rect := seat.get_global_rect()
	if rect.size.x <= 0.0:
		return
	var ghost := _card_face(cards[index], maxf(size.x, 200.0) / 100.0, -1)
	ghost.size = rect.size
	ghost.position = rect.position - get_global_rect().position
	add_child(ghost)
	var sink := ghost.create_tween()
	sink.set_parallel(true)
	sink.tween_property(ghost, "position:y", ghost.position.y + rect.size.y,
		CARD_SINK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sink.tween_property(ghost, "modulate:a", 0.0, CARD_SINK_TIME)
	sink.chain().tween_callback(ghost.queue_free)

## Wie weit jede Karte seitlich gleitet: aus der Verschiebung ihres PLATZES
## gerechnet, nicht gemessen - beim Umlegen ist das Blech noch gar nicht neu
## gelegt, und ein Bild später wäre der Sprung längst zu sehen.
func _mark_slides(before: Array[int]) -> void:
	var u := maxf(size.x, 200.0) / 100.0
	var step := socket_size(u).x + u * BENCH_GAP
	for i in _series.size():
		var was := before.find(_series[i])
		if was >= 0 and was != i:
			_slide_from[_series[i]] = float(was - i) * step

## UMSORTIEREN in der Reihe: die Karte wird an from herausgenommen und bei to
## eingesetzt, alles dazwischen rückt eine Stelle - dieselbe move-statt-swap-
## Semantik wie reorder_pool. Die Reihenfolge IST die Rechenreihenfolge.
func move_slot(from_index: int, to_index: int) -> void:
	if editing_locked or burning():
		return
	if from_index < 0 or from_index >= _series.size():
		return
	if to_index < 0 or to_index == from_index:
		return
	var uid := _series[from_index]
	var before := _series.duplicate()
	_series.remove_at(from_index)
	_series.insert(mini(to_index, _series.size()), uid)
	_mark_slides(before)
	refresh()

## Drücken merkt sich den Slot, Loslassen über einem ANDEREN legt die Karte dort
## ein. Losgelassen über demselben Slot bleibt es ein Klick - dafür feuert der
## Knopf ohnehin sein pressed, und die beiden Gesten können nie beide zünden.
func _on_slot_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed:
		_drag_from = index
		return
	var target := slot_at(click.global_position)
	if _drag_from >= 0 and target >= 0 and target != _drag_from:
		move_slot(_drag_from, target)
	_drag_from = -1

## Der Slot unter der globalen Position (-1 = keiner) - das Loslassen landet auf
## dem Slot unter dem Zeiger, nicht auf dem, auf dem gedrückt wurde.
func slot_at(global_point: Vector2) -> int:
	for i in _slot_buttons.size():
		var slot := _slot_buttons[i]
		if slot != null and is_instance_valid(slot) \
				and slot.get_global_rect().has_point(global_point):
			return i
	return -1

## Die Karten der Reihe in Steckreihenfolge, als reine Anzeigedaten. Während der
## Zeremonie sind es die des Griffs - die Karten selbst sind da längst verbraucht.
func _slot_cards() -> Array[Dictionary]:
	if burning():
		return _burning
	var cards: Array[Dictionary] = []
	if run == null:
		return cards
	for uid in _series:
		var pack := run.pack_by_uid(uid)
		if pack != null:
			cards.append(card_data(uid, pack))
	return cards

## Die Anzeigedaten EINER Kassette - EINE Quelle für Slot, Schirm und Zeremonie.
static func card_data(uid: int, pack: Pack) -> Dictionary:
	return {"uid": uid, "name": pack.display_name, "sort": Pack.shelf_of(pack),
		"net": pack.stamp_net, "operator": pack.operator_id,
		"catalyst": pack.catalyst_id, "line": Pack.net_line(pack),
		"body": pack.description}

## Die gesteckten Karten als Pakete, in Reihenfolge - was inzwischen aus dem Lager
## verschwand, fehlt.
func slotted_packs() -> Array[Pack]:
	var packs: Array[Pack] = []
	if run == null:
		return packs
	for uid in _series:
		var pack := run.pack_by_uid(uid)
		if pack != null:
			packs.append(pack)
	return packs

## Wie viele Karten der Reihe wirklich PRÄGEN. Eine Serie aus lauter Katalysatoren
## prägt nicht: sie verstärken eine Projektion, sie sind keine.
func stamping_card_count() -> int:
	var count := 0
	for pack in slotted_packs():
		if not pack.is_catalyst():
			count += 1
	return count

## Wirft uids aus der Reihe, hinter denen keine Karte mehr liegt (Wett-Einsatz,
## Laufwechsel), und einen Zielwürfel, den der Pool nicht mehr hergibt.
func _prune_series() -> void:
	var kept: Array[int] = []
	for uid in _series:
		if run != null and run.pack_by_uid(uid) != null:
			kept.append(uid)
	_series = kept
	var pool := pool_defs().size()
	if _target_index >= pool:
		_target_index = -1
	if _second_index >= pool or not needs_second():
		_second_index = -1

# --- Der GRIFF -------------------------------------------------------------------

## Der EINE Handlungs-Sitz, rechts neben dem Blech. Sein Rechteck ist in JEDEM
## Zustand dasselbe - der Sitz ist ein fester Platz, die Aufschrift wechselt darin.
func _build_action_seat(band: Control, u: float) -> void:
	var seat := Control.new()
	seat.name = "ActionSeat"
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(seat)
	var span := action_size(u)
	var button := _seat_button(u)
	if button != null:
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		seat.add_child(button)
		# Erst im Baum messen: die Zeilenhöhe der Schrift ist der wahre Boden des
		# Sitzes - und sie ist für beide Aufschriften dieselbe.
		span.y = maxf(span.y, button.get_combined_minimum_size().y)
		# Danach trägt der SITZ das Maß allein: seine Größe fällt aus zwei
		# Ankerabständen heraus und weicht um ein Bit von action_size ab.
		button.custom_minimum_size = Vector2.ZERO
	# Der Sitz rückt um den Serien-Schirm nach links: der steht in der Ecke.
	var right := series_width() + u * ACTION_GAP
	seat.anchor_left = 1.0
	seat.anchor_right = 1.0
	seat.anchor_top = 0.5
	seat.anchor_bottom = 0.5
	seat.offset_left = -span.x - right
	seat.offset_right = -right
	seat.offset_top = -span.y * 0.5
	seat.offset_bottom = span.y * 0.5

## Der Knopf auf dem Sitz. Zwei Zustände: der GRIFF und, solange die Serie sich
## entlädt, das Überspringen.
func _seat_button(u: float) -> Button:
	if burning():
		_action_button = _seat_fit(_action_button_new("Fertig", GOLD, u,
			skip_ceremony), u)
		return _action_button
	_action_button = _seat_fit(_action_button_new("Griff (%d)" % _series.size(),
		GOLD, u, pull_lever), u)
	_action_button.disabled = not can_pull()
	_action_button.visible = not _series.is_empty()
	_seat_hint(_action_button)
	return _action_button

## Darf jetzt gegriffen werden? Drei Bremsen: die eine Pressung der Sitzung, ein
## gewählter Zielwürfel und mindestens eine Karte, die überhaupt prägt. Steckt
## eine Doppelmatrize, will sie ihren zweiten Würfel.
func can_pull() -> bool:
	if run == null or editing_locked or burning():
		return false
	if target_die() == null or stamping_card_count() <= 0:
		return false
	if needs_second() and second_die() == null:
		return false
	return run.press_allowed()

## Wie es um den Griff steht, sagt NICHT der Knopf (sein Rechteck ist fest) - das
## sagt der Hinweis-Schirm, sobald der Zeiger ihn greift.
func _seat_hint(button: Button) -> void:
	if run == null:
		return
	button.set_meta("title", "Griff")
	if target_die() == null:
		button.set_meta("body", "Wähle im Raster den Würfel, auf den die Serie prägt.")
		button.set_meta("tint", CasinoStyle.RED)
		button.tooltip_text = String(button.get_meta("body", ""))
		return
	if stamping_card_count() <= 0:
		button.set_meta("body",
			"Katalysatoren verstärken eine Projektion - lege eine Karte mit Netz dazu.")
		button.set_meta("tint", CasinoStyle.RED)
		button.tooltip_text = String(button.get_meta("body", ""))
		return
	if needs_second() and second_die() == null:
		button.set_meta("body", "Die Doppelmatrize braucht einen zweiten Würfel.")
		button.set_meta("tint", CasinoStyle.RED)
		button.tooltip_text = String(button.get_meta("body", ""))
		return
	var body := "Der Griff dieser Runde ist bereits verbraucht."
	if run.press_allowed():
		body = "Der eine Griff dieser Runde steht bereit."
		if bool(GameRun.catalyst_terms(slotted_packs())["free"]):
			body = "Die Erdungsklemme bewahrt den Griff - dieser verbraucht ihn nicht."
	button.set_meta("body", body)
	button.tooltip_text = body

## Zwingt einen Knopf auf das Sitzmaß: clip_text nimmt der Aufschrift das Recht,
## das Rechteck zu verbreitern.
func _seat_fit(button: Button, u: float) -> Button:
	button.clip_text = true
	button.custom_minimum_size = action_size(u)
	return button

## Maße des Sitzes: EIN Rechteck für beide Aufschriften.
func action_size(u: float) -> Vector2:
	return Vector2(u * ACTION_WIDTH, u * ACTION_HEIGHT)

## DER GRIFF: EINE atomare Buchung in GameRun, dann die Zeremonie. Gemeldet wird
## press_started VOR dem Buchen (die Dekompression der Zellen braucht sie noch in
## ihren Schlitzen); series_applied kommt am ENDE der Zeremonie - gebucht ist da
## längst, es ist nur noch das Licht.
func pull_lever() -> void:
	if not can_pull():
		return
	var cards := _slot_cards()
	var before := target_die().instantiate()
	var terms := GameRun.catalyst_terms(slotted_packs())
	var anchor := hand_anchor_px()
	press_started.emit()
	var result := run.apply_series(_series.duplicate(), target_die(), second_die())
	if result.is_empty():
		refresh()  # der Griff war verbraucht: die Karten bleiben in ihren Slots
		return
	_series.clear()
	_burning = cards
	_burn_die = before
	_burn_terms = terms
	_burn_result = result
	_burn_anchor = anchor
	_burn_step = 0
	_burn_gen += 1
	refresh()
	# Das geparkte Netz ENTLEERT sich: die Vorschau tritt ab, die Rechnung beginnt
	# bei 0 - die Ziffern ticken auf die nackten Augenzahlen hinunter.
	_refresh_preview_net(SCAN_EMPTY_TIME)
	if _scanner != null and is_instance_valid(_scanner):
		_scanner.flare()
	_play_series_ceremony(_burn_gen)  # nicht erwartet: die Fahrt läuft für sich

## Läuft die Serie gerade durch?
func burning() -> bool:
	return _burn_step >= 0

## Wie lange die Fahrt dauert - scene_root staffelt daran nichts, aber ein Test
## darf sie abwarten.
func ceremony_time() -> float:
	var beats := 0.0
	for i in _burning.size():
		beats += card_beat(i)
	return SCAN_EMPTY_TIME + SCAN_TO_RAIL_TIME + beats + SCAN_LEAVE_TIME \
		+ SCAN_FOLD_TIME + SCAN_FLASH_TIME

## Der Takt EINER Karte: die RAMPE macht die späteren schneller, ein Operator
## bekommt seinen Sondermoment obendrauf.
func card_beat(index: int) -> float:
	var count := maxi(_burning.size(), 1)
	var share := 0.0 if count <= 1 else float(index) / float(count - 1)
	var beat := SCAN_STEP_TIME * lerpf(1.0, SCAN_STEP_RAMP, share)
	if index >= 0 and index < _burning.size() \
			and String(_burning[index].get("operator", "")) != "":
		beat += SCAN_OPERATOR_EXTRA
	return beat

## Die Netze der Karten, die die Welle SCHON erfaßt hat - daran tickt das
## Summen-Netz kartenweise hoch.
func _burn_nets_so_far() -> Array:
	var nets: Array = []
	for i in mini(maxi(_burn_step, 0), _burning.size()):
		if String(_burning[i].get("catalyst", "")) != "":
			continue  # ein Katalysator prägt nicht, er legt Terme bei
		nets.append(_burning[i].get("net", []))
	return nets

## DIE DURCHLICHT-FAHRT: der Schlitten verläßt die Ziel-Säule, fährt die Schiene
## über der Reihe ab und geht dabei durch jede stehende Karte HINDURCH - sie
## flammt auf, ihre Zellen ticken auf dem Netz hoch, ein Operator schlägt
## perkussiv zu. Nach der letzten Karte fährt er zum Zielwürfel und faltet sein
## Netz über ihm zusammen; am Ende meldet er den Griff, und scene_root schlägt auf
## den Körper.
func _play_series_ceremony(generation: int) -> void:
	var launched := run
	if not await _scan_wait(SCAN_EMPTY_TIME, generation, launched):
		return
	var cards := press_display_anchors()
	var rail := _rail_seat_y()
	var entry := Vector2(cards[0].x, rail) if not cards.is_empty() else _die_seat()
	entry.x -= card_size(maxf(size.x, 200.0) / 100.0).x * 0.8  # der Reihenanfang
	_scanner.ride_to(_scan_seat(entry), _rail_scale(), SCAN_TO_RAIL_TIME)
	if not await _scan_wait(SCAN_TO_RAIL_TIME, generation, launched):
		return
	for i in _burning.size():
		var beat := card_beat(i)
		var travel := beat * SCAN_MOVE_SHARE
		var seat := Vector2(cards[i].x, rail) if i < cards.size() else entry
		_scanner.ride_to(_scan_seat(seat), _rail_scale(), travel)
		if not await _scan_wait(travel, generation, launched):
			return
		_read_card(i, beat - travel)
		if not await _scan_wait(beat - travel, generation, launched):
			return
	# DIE ÜBERTRAGUNG: zurück zum Zielwürfel, Faltung, Entladung.
	_scanner.ride_to(_scan_seat(_die_seat()), 1.0, SCAN_LEAVE_TIME)
	if not await _scan_wait(SCAN_LEAVE_TIME, generation, launched):
		return
	_scanner.fold(SCAN_FOLD_TIME)
	if not await _scan_wait(SCAN_FOLD_TIME, generation, launched):
		return
	_scanner.flare()
	if not await _scan_wait(SCAN_FLASH_TIME, generation, launched):
		return
	_end_ceremony()

## Ein Takt der Fahrt. false = die Zeremonie gehört nicht mehr uns (übersprungen,
## Laufwechsel, Fenster fort) - der Aufrufer steigt dann sofort aus, und der EINE
## Aufräum-Pfad hat längst alles gerichtet.
func _scan_wait(time: float, generation: int, launched: GameRun) -> bool:
	if generation != _burn_gen or run != launched or not is_inside_tree():
		return false
	if _scanner == null or not is_instance_valid(_scanner):
		return false
	await get_tree().create_timer(maxf(time, 0.0)).timeout
	return generation == _burn_gen and run == launched and is_inside_tree() and burning() \
		and _scanner != null and is_instance_valid(_scanner)

## Der Schlitten steht über Karte i: sie flammt auf, das Netz übernimmt ihre
## Zellen (tickend), und ein Operator schlägt statt dessen zu.
func _read_card(index: int, tick: float) -> void:
	var card: Dictionary = _burning[index]
	var operator := String(card.get("operator", ""))
	var portal: PressPortalView = _portals[index] if index < _portals.size() else null
	if portal != null and is_instance_valid(portal):
		if operator != "":
			portal.punch(StampNet.operator_glyph(operator))
		else:
			portal.charge()
	var before := preview()
	_burn_step = index + 1
	_refresh_preview_net(maxf(tick, 0.01))
	var faces := _moved_faces(before, preview(), card.get("net", []))
	if operator != "":
		_scanner.punch(StampNet.operator_glyph(operator), faces)
	else:
		_scanner.strike(faces)

## Welche Seiten diese Karte BEWEGT hat - der Vergleich zweier Zwischenstände. So
## bekommt jeder Operator seinen Einschlag, ohne dass die Anzeige seine Regel noch
## einmal nachbaute; was ohne Zahl wirkt (Material, Rune, Pointer), fällt auf die
## gefüllten Zellen der Karte zurück.
static func _moved_faces(before: Dictionary, after: Dictionary, net: Array) -> Array[int]:
	var faces: Array[int] = []
	var was: Array = before.get("bonus", []) if not before.is_empty() else []
	var now: Array = after.get("bonus", []) if not after.is_empty() else []
	for face in StampNet.FACES:
		var old_value := int(was[face]) if face < was.size() else 0
		var new_value := int(now[face]) if face < now.size() else 0
		if old_value != new_value:
			faces.append(face)
	if not faces.is_empty():
		return faces
	for face in StampNet.FACES:
		if StampNet.is_filled(StampNet.cell_at(net, face)):
			faces.append(face)
	return faces

## Der Platz eines Schlitten-Sitzes in Fenster-Koordinaten (gemeldet wird in
## Display-Pixeln, gefahren wird im Fenster).
func _scan_seat(global_point: Vector2) -> Vector2:
	return global_point - get_global_rect().position

## Die Höhe der Schiene: die Mitte des Konsolen-Blechs - dort geht das Netz durch
## die stehenden Karten hindurch.
func _rail_seat_y() -> float:
	if _console != null and is_instance_valid(_console) \
			and _console.get_global_rect().size.y > 0.0:
		return _console.get_global_rect().get_center().y
	return console_band_rect().get_center().y + get_global_rect().position.y

## Der Platz des Würfels: über dem Netz-Parkplatz, auf der Projektor-Zeile.
func _die_seat() -> Vector2:
	var middle := target_net_center()
	if middle.x < 0.0:
		return get_global_rect().get_center()
	return Vector2(middle.x, target_projector_y())

## Auf der SCHIENE fährt der Schlitten klein: sein Netz mißt sich dort an der Höhe
## des Blechs. In der Säule steht es in voller Größe.
func _rail_scale() -> float:
	var u := maxf(size.x, 200.0) / 100.0
	var room := console_size(u).y * SCAN_RAIL_SHARE
	return clampf(DieNetView.cell_for(Vector2(room * 4.0, room)) / (u * CHOICE_CELL),
		0.2, 1.0)

## Klick auf den Sitz: die Fahrt springt ans Ende. Der Stand ist längst gebucht -
## übersprungen wird nur Licht.
func skip_ceremony() -> void:
	if not burning():
		return
	_burn_step = _burning.size()
	_end_ceremony()

## Der EINE Aufräum-Pfad der Zeremonie: der Schlitten steht wieder geparkt in der
## Säule, sein Netz zeigt ungefaltet den echten Würfel, die Reihe ist leer, und
## der Griff wird gemeldet. Egal, wo die Fahrt abbrach.
func _end_ceremony() -> void:
	if not burning():
		return
	var result := _burn_result
	var anchor := _burn_anchor
	_burn_gen += 1
	_burning = []
	_burn_step = -1
	_burn_die = null
	_burn_terms = {}
	_burn_result = {}
	if _scanner != null and is_instance_valid(_scanner):
		_scanner.settle()
	refresh()
	_sync_scanner_park()
	series_applied.emit(result, anchor)

## Eine Serie gehört dem laufenden Spiel: beim Laufwechsel verfällt sie samt jeder
## Zeremonie, die noch liefe.
func _drop_series() -> void:
	_burn_gen += 1
	_series.clear()
	_burning = []
	_burn_step = -1
	_burn_die = null
	_burn_terms = {}
	_burn_result = {}
	_target_index = -1
	_second_index = -1
	_hover_slot = -1
	_drag_from = -1
	_fresh_slots.clear()
	_slide_from.clear()
	if _scanner != null and is_instance_valid(_scanner):
		_scanner.settle()
		_scanner.net.reset_ticks()  # der Stand des alten Laufs tickt nirgends hin

## Nur das Netz neu, ohne die ganze Seite: die Fahrt tickt je Karte, und ein
## voller Neuaufbau nähme den Slots ihr laufendes Glühen.
## tick > 0 = die Ziffern LAUFEN zu ihrem neuen Wert, statt zu springen.
func _refresh_preview_net(tick: float = 0.0) -> void:
	if _net == null or not is_instance_valid(_net):
		return
	_net.def = preview_target()
	_net.projection = preview()
	_net.highlight = _highlight_faces()
	_net.tick_time = tick
	_net.build()

## Display-Pixel der Konsole (ohne sie die Fenstermitte) - dort sitzt die Reihe,
## und von dort geht das Licht des Griffs aus.
func hand_anchor_px() -> Vector2:
	if _console != null and is_instance_valid(_console) \
			and _console.get_global_rect().size.x > 0.0:
		return _console.get_global_rect().get_center()
	return get_global_rect().get_center()

# --- Das Magazin (versiegelte Ware) ---------------------------------------------

## Das Magazin: EIN eingelassenes Fach über die volle Fensterbreite, je Paket seine
## eigene Kassette. Es ist die einzige Auslage versiegelter Ware.
func _build_drawer(u: float) -> void:
	_drawer = PackDrawerView.new()
	_drawer.pack_pressed.connect(_on_pack_pressed)
	_drawer.packs_reordered.connect(_on_packs_reordered)
	_drawer.tidy_requested.connect(_on_tidy_requested)
	add_child(_drawer)  # direktes Kind: das Fach liegt AUSSERHALB des Fensters
	var rect := shelf_rect()
	_drawer.position = rect.position
	_drawer.size = rect.size
	_drawer.build(drawer_entries(), u, shelf_locked(), data_cell_px, rect.size)
	if not _queued_pops.is_empty():
		_flush_queued_pops.call_deferred()  # der Pluster braucht das fertige Layout

## Der Streifen des Magazins: AUSSERHALB des Fensters, auf der GANZEN Fensterbreite
## (ganze Pixel, damit die Platz-Rechnung nicht driftet).
func shelf_strip_size() -> Vector2:
	var u := maxf(size.x, 200.0) / 100.0
	return Vector2(floorf(maxf(size.x, u * 20.0)),
		maxf(apron_bottom_y() - shelf_top(), u * SHELF_MIN_HEIGHT))

## Oberkante des Magazins: eine Naht unter dem Konsolen-Band. Der Abstand zur
## Konsole ist gesetzt, die HÖHE folgt daraus.
func shelf_top() -> float:
	return console_band_rect().end.y + maxf(size.x, 200.0) / 100.0 * CONSOLE_SHELF_GAP

## Der Platz des Magazins: unter dem Band, mittig auf der Fensterbreite.
func shelf_rect() -> Rect2:
	var strip := shelf_strip_size()
	return Rect2(Vector2(roundf((size.x - strip.x) * 0.5), shelf_top()), strip)

## Derselbe Platz in Display-Pixeln (der Streifen misst sich am Fenster).
func shelf_rect_global() -> Rect2:
	var rect := shelf_rect()
	rect.position += get_global_rect().position
	return rect

## Das LOCH des Magazins in Display-Pixeln: der Streifen abzüglich seiner gemalten
## Fassung. scene_root schneidet danach das Glas und stellt die Grube darunter.
func shelf_pit_rect() -> Rect2:
	return PackDrawerView.pit_rect_in(shelf_rect_global(), shelf_unit())

## Eckenradius des Lochs: der des Rahmens, um dessen Breite verkleinert.
func shelf_pit_radius() -> float:
	var unit := shelf_unit()
	return maxf(unit * PackDrawerView.RADIUS - PackDrawerView.rim_inset(unit), 0.0)

## Die Maßeinheit, in der die Schürze rechnet (u = Fensterbreite/100).
func shelf_unit() -> float:
	return maxf(size.x, 200.0) / 100.0

## Das Zellmaß, an dem sich das Magazin misst (ohne gemeldetes das Rückfallmaß).
func shelf_cell_px() -> Vector2:
	if data_cell_px.x > 0.0 and data_cell_px.y > 0.0:
		return data_cell_px
	return PackDrawerView.fallback_cell(maxf(size.x, 200.0) / 100.0)

## Anzeige-Maßstab der Magazin-Kassetten (scene_root skaliert die Körper darauf).
func shelf_cell_scale() -> float:
	if _drawer != null and is_instance_valid(_drawer):
		return _drawer.cell_scale()
	return PackDrawerView.cell_scale_for(shelf_cell_px(),
		shelf_pit_rect().size, drawer_entries().size())

## Die Kassette unter dem Display-Pixel (0 = keine): scene_root zieht daran den
## Körper ein Stück aus der Grube.
func shelf_hover_uid_at(pixel: Vector2) -> int:
	if _drawer != null and is_instance_valid(_drawer):
		return _drawer.hover_uid_at(pixel)
	return 0

## Ankunfts-Pluster, die auf ihr Fach gewartet haben.
func _flush_queued_pops() -> void:
	if _drawer == null or not is_instance_valid(_drawer):
		return
	for uid in _queued_pops:
		pack_landed.emit(uid)
	_queued_pops.clear()

## Eine dehnbare Leerzeile.
func _slack(slack_name: String) -> Control:
	var slack := Control.new()
	slack.name = slack_name
	slack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slack

## Je Paket {uid, pack, withheld} in Magazin-Ordnung (= run.owned_packs). Was in
## einem Serien-Slot steckt, fehlt ganz; was noch als Licht fliegt, hält seinen
## Platz und bleibt bis zur Landung verdeckt.
func drawer_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if run == null:
		return entries
	for pack in run.owned_packs:
		if _series.has(pack.pack_uid):
			continue
		entries.append({"uid": pack.pack_uid, "pack": pack,
			"withheld": _pending_arrivals.has(pack.pack_uid)})
	return entries

## Ein Paket ist unterwegs: sein Platz steht, sein Chip erscheint erst mit der
## Landung (scene_root ruft das VOR dem Kometen).
func expect_pack_delivery(uid: int) -> void:
	_pending_arrivals[uid] = true
	refresh()

## Die Lieferung ist da: die Kassette kommt zum Vorschein und steigt auf ihren
## Platz. true = sie war wirklich unterwegs.
func deliver_pack(uid: int) -> bool:
	if not _pending_arrivals.has(uid):
		return false
	_pending_arrivals.erase(uid)
	refresh()
	if _drawer != null and is_instance_valid(_drawer):
		pack_landed.emit(uid)
		return true
	_queued_pops.append(uid)  # das Fach steht gerade nicht - er wartet auf es
	return true

## Display-Pixel eines Magazin-Platzes - Standplatz des Körpers und Ziel der
## Liefer-Kometen. Steht das Fach gerade nicht, wird der Platz GERECHNET.
func pack_anchor_px(uid: int) -> Vector2:
	if _drawer != null and is_instance_valid(_drawer):
		var anchor := _drawer.pack_anchor_px(uid)
		if anchor.x >= 0.0:
			return anchor
	var index := -1
	var count := 0
	if run != null:
		for pack in run.owned_packs:
			if _series.has(pack.pack_uid) and pack.pack_uid != uid:
				continue
			if pack.pack_uid == uid:
				index = count
			count += 1
	var derived := PackDrawerView.anchor_in(shelf_pit_rect(), index, count,
		shelf_cell_px())
	return derived if derived.x >= 0.0 else shelf_rect_global().get_center()

## Der Platz, auf dem die NÄCHSTE Lieferung landet (extra staffelt eine Salve).
func arrival_anchor_px(extra: int = 0) -> Vector2:
	var count := drawer_entries().size()
	return PackDrawerView.anchor_in(shelf_pit_rect(), count + extra,
		count + extra + 1, shelf_cell_px())

## Eine Kassette wurde angetippt: sie wandert in den nächsten freien Serien-Slot.
func _on_pack_pressed(uid: int) -> void:
	slot_pack(uid)

## Kassette auf Kassette gezogen: das Magazin legt um - dieselbe remove/insert-
## Semantik wie reorder_pool.
func _on_packs_reordered(from_uid: int, to_uid: int) -> void:
	if run == null or shelf_locked():
		return
	run.reorder_packs(run.pack_index_of(from_uid), run.pack_index_of(to_uid))

## Doppelklick auf leere Fach-Fläche: aufräumen nach Sorte, Inhalt, uid.
func _on_tidy_requested() -> void:
	if run == null or shelf_locked():
		return
	run.tidy_packs()

# --- Auskunft --------------------------------------------------------------------

## Name und Wirkung des Dings unter pixel ({} = keins): das Magazin spricht zuerst,
## dann die Serien-Reihe, zuletzt der Handlungs-Sitz - alle schreiben auf denselben
## Hinweis-Schirm. Nebenher stellt der Zeiger das HOVER-HIGHLIGHT: die überfahrene
## Karte hebt ihre Beitrags-Zellen im Summen-Netz hervor.
func chip_hint_at(pixel: Vector2) -> Dictionary:
	_set_hover_slot(slot_at(pixel))
	if _drawer != null and is_instance_valid(_drawer):
		var hint := _drawer.hint_at(pixel)
		if hint.has("stock"):
			return _stock_hint()
		if not hint.is_empty():
			return hint
	if _hover_slot >= 0 and _hover_slot < _slot_buttons.size():
		var found := _meta_hint(_slot_buttons[_hover_slot], pixel)
		if not found.is_empty():
			return found
	return _meta_hint(_action_button, pixel)

## Nur der WECHSEL baut das Netz neu - chip_hint_at läuft je Bild.
func _set_hover_slot(index: int) -> void:
	var wanted := index if index < _slot_cards().size() else -1
	if wanted == _hover_slot:
		return
	_hover_slot = wanted
	_refresh_preview_net()

## Die Fach-Fläche nennt den BESTAND am Deckel. Live vom Lauf gefragt.
func _stock_hint() -> Dictionary:
	var capacity := run.pack_capacity if run != null else 0
	if capacity <= 0:
		return {"title": PackDrawerView.EMPTY_TITLE, "body": PackDrawerView.EMPTY_BODY}
	var stock := run.owned_packs.size()
	var free := maxi(capacity - stock, 0)
	var body := PackDrawerView.EMPTY_BODY
	if stock > 0:
		body = PackDrawerView.FULL_BODY if free == 0 else PackDrawerView.STOCK_BODY % free
	return {"title": PackDrawerView.STOCK_TITLE % [stock, capacity], "body": body}

## Die Meta-Auskunft eines Knopfes, wenn der Zeiger auf ihm steht ({} = nicht).
func _meta_hint(node: Control, pixel: Vector2) -> Dictionary:
	if node == null or not is_instance_valid(node) or not node.visible \
			or not node.has_meta("title") or not node.get_global_rect().has_point(pixel):
		return {}
	return {"title": String(node.get_meta("title", "")),
		"body": String(node.get_meta("body", "")),
		"tint": node.get_meta("tint", CasinoStyle.CREAM)}

## Erklärzeile zur Netz-Zelle unter einem Display-Pixel ("" = keine). GEFRAGT statt
## gemeldet: Godot reicht die erste Bewegung über einem Knopf nicht als gui_input
## durch, und wer genau dort stehen bleibt, bekäme nie einen Text.
func net_hint_at(pixel: Vector2) -> String:
	if _net == null or not is_instance_valid(_net):
		return ""
	var face := _net.face_at_pixel(pixel)
	if face == -1:
		return ""
	return _net.hint_for_face(face)

func _action_button_new(text: String, accent: Color, u: float,
		handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(u * 22.0, u * 6.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", maxi(8, int(u * 2.6)))
	_style_button(button, accent)
	button.pressed.connect(handler)
	return button

# --- Bausteine -----------------------------------------------------------------

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color",
		Color(MUTED_COLOR.r, MUTED_COLOR.g, MUTED_COLOR.b, 0.45))
	button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#2c2757dd"), GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#3a2f66"), GOLD))
	button.add_theme_stylebox_override("focus", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("disabled",
		_button_box(Color("#1a183666"), Color(accent.r, accent.g, accent.b, 0.25)))

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var u := maxf(size.x, 200.0) / 100.0
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.6))
	return box
