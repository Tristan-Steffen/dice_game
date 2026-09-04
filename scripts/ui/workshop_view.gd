class_name WorkshopView
extends Panel
## Der STATIONS-STREIFEN UNTER dem Pool (2026-09-04). Er hat KEINEN
## Schirm-Hintergrund - seine Teile liegen auf dem Filz - und liest in ZWEI ZEILEN
## plus Grube:
##   Zeile 1:  [ZIEL-PODEST]   [SCHACHT-REIHE]   [ERGEBNIS-PODEST]
##   Zeile 2:  [IST-NETZ]      [TOOLTIP-SCHIRM]  [SOLL-NETZ]
##   Grube:    [MAGAZIN über die volle Streifenbreite]
## Der Streifen liest damit GANZ AUS SICH SELBST: die linke Spalte ist das
## Spiegelbild der rechten, und das Ausgabefach am Pool hat mit ihm nichts mehr zu
## tun (seine Info-Säule zeigt nur noch den Neuzugang).
##  - Zeile 1 in der Mitte die SCHACHT-REIHE: je Serien-Slot ein Loch im erhabenen
##    Konsolen-Blech, in dem die ECHTE Data-Cell aus dem Magazin aufsteigt und
##    steht. Das Fenster malt nur die Münder und MELDET ihre Anker - die Körper
##    gehören scene_root, die beiden Podeste ebenso.
##  - Zeile 2 - das BAND - IST-NETZ | TOOLTIP-SCHIRM | SOLL-NETZ. Beide Netze sind
##    GLEICH GROSS (EIN Zellmaß, aus der engeren Spalte) und stehen IMMER da: ohne
##    Ziel und ohne Karten als leeres Kreuz.
##
## Alles darunter liegt in der SCHÜRZE, und sie beginnt UNTER der Fensterkante:
## eine Naht, dann das KONSOLEN-BAND (nur noch der GRIFF, mittig unter der
## Schacht-Reihe), dieselbe Naht noch einmal, dann das MAGAZIN; seine Unterkante
## sitzt bündig mit der Pool-Unterkante (die gemeldete apron_bottom-Linie) - es sei
## denn, die FLACH LIEGENDE Karte braucht mehr Tiefe, dann wächst der Streifen nach
## unten in den freien Filz (shelf_min_height).
##
## Die REIHE IST die Rechnung: getippt geht eine Kassette in den nächsten freien
## Schacht, gezogen sortiert sie um (Reihenfolge = Rechenreihenfolge), geklickt
## kommt sie zurück ins Magazin. Ihre Zahl ist GameRun.series_slots() - die Reihe
## wächst mit dem Hub, sie ist kein festes Sechser-Möbel.
##
## Zustands-Mutation läuft ausschließlich über GameRun (resolve_series als
## Vorschau, apply_series als Griff); die Vorschau ist buchstäblich dieselbe
## Rechnung wie die Buchung.

## Der Zielwürfel wurde gewählt, gewechselt oder abgewählt (null = keiner) -
## scene_root holt ihn per Hebebühne aus dem Pool auf das Podest und fährt ihn
## denselben Weg zurück.
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
## Eine Karte ist aus ihrem Serien-Schacht zurück ins Magazin gegangen - die Zelle
## dieses Platzes fliegt heim auf ihren Platz. Gebucht ist da längst.
signal pack_unslotted(slot_index: int, uid: int)
## Der Griff beginnt: die Reihe gehört ab jetzt der Zeremonie. Gemeldet wird VOR
## dem Buchen, solange die Sockel noch stehen.
signal press_started
## DIE SCHABLONEN-FAHRT, im Takt gemeldet - GEFAHREN wird sie von scene_root, das
## Fenster nennt nur Plätze in Display-Pixeln und Zeiten (ui/ faßt nie Körper an).
## Die GEBURT liegt am IST-NETZ der linken Spalte (ist_net_center).
signal stencil_launched(time: float)
## Eine Etappe auf der Schiene über der Reihe.
signal stencil_moved(to_px: Vector2, time: float)
## Karte i ist AUFGENOMMEN: ihre Zellen dunkeln ab (faces), die Schablone tickt auf
## den aufgelaufenen Stand (values) und schlägt zu, wenn ein Operator darin steckt.
signal stencil_read(index: int, faces: Array, values: Array, operator: String,
	time: float)
## DER WÜRFEL WECHSELT DIE SEITE: er versinkt am Bench-Podest und steigt am
## ERGEBNIS-Podest auf, während die Schablone ihre letzte Etappe fährt. time ist die
## Zeit, die dafür bleibt - er soll STEHEN, wenn sich die Schablone in ihn faltet.
signal die_handover(time: float)
## Die Abfahrt zum ERGEBNIS-Podest - wo der Zielwürfel dann steht, weiß scene_root.
signal stencil_landed(time: float)
## Und die FALTUNG in ihn hinein.
signal stencil_folded(time: float)

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")
## Operator-Karten stehen amber ab - die eine Farbtrennung der Serie (Wert-Karten
## behalten ihre Sortenfarbe). Die Quelle ist das Netz, nicht dieses Fenster.
const OPERATOR_TINT := PressNetView.OPERATOR_TINT

## Höhe der Bühne des schwebenden Zielwürfels (Breiteneinheiten u): Platz für den
## Würfel UND seine Stasis-Station, die durch die Parallaxe ein Stück unter ihm
## auf der Fläche steht.
const STAGE_HEIGHT := 9.3
## Zellgröße des Summen-Netzes: die Kachel, in der ein Würfel gezeigt wird, wenn
## man ÜBER ihn entscheidet.
const CHOICE_CELL := DieNetView.TRAY_TILE

## --- DIE STRASSE: drei Stationen von links nach rechts ---------------------------
## Breite der beiden Podest-Spalten in u (links Ziel, rechts Ergebnis - Spiegel-
## bilder); die SCHACHT-REIHE bekommt, was dazwischen bleibt und ist damit die
## einzige Spalte, die mit der Serienlänge atmet.
const DIFF_WIDTH_UNITS := 28.0
## Die Fuge zwischen einer Podest-Spalte und der Reihe - zweimal dasselbe Maß.
const STREET_GAP := 1.8
## Kopfraum über dem Podest: der schwebende Würfel ragt über seinen Platz hinaus,
## und in der Nahsicht sitzt die obere Fensterkante exakt am Bildrand - ohne diese
## Luft schnitte der Rahmen ihm die Oberseite ab.
const STAGE_HEAD_ROOM := 1.0
## Luft zwischen Podest und Diff-Schirm darunter: der Würfel soll über seinem
## Diagramm STEHEN, nicht darauf aufliegen.
const STAGE_NET_GAP := 1.0
## Höhe des BANDES (Zeile 2) in u - Tooltip links und Soll-Schirm rechts teilen sie.
## Sie ist zugleich die Höhenregel der ganzen Seite: bench_aspect löst die
## Fensterbreite so, daß beide Spalten der Zeile 1 samt Band senkrecht aufgehen.
const DIFF_HEIGHT_UNITS := 24.0
## Die Fuge zwischen der Schacht-Reihe (Zeile 1) und dem Band darunter.
const ROW_BAND_GAP := 1.5

## Ränder und Zeilenabstand des Fensterinhalts (Einheiten u).
const CONTENT_MARGIN_X := 2.4
const CONTENT_MARGIN_Y := 1.4
const CONTENT_GAP := 1.0

## --- Die beiden NETZ-SCHIRME: IST links, SOLL rechts -----------------------------
## Beide tragen NUR ihr Netz (der physische Würfel steht über ihnen auf seinem
## Podest), auf BLANKEM Filz - ohne eigenen Hintergrund und ohne Aufschlüsselungs-
## Zeilen. Links steht der Würfel, WIE ER IST, rechts, was die Serie aus ihm macht
## (grüne Deltas). Das Zellmaß rechnet das Fenster EINMAL für beide.
const DIFF_PAD := 0.9
## Anteil des Schirms, den ein Netz höchstens nimmt - der Rest bleibt Luft.
const DIFF_NET_SHARE := 0.92

## --- Die SCHACHT-REIHE ----------------------------------------------------------
## Die FUGE zwischen zwei Schacht-Mündern (in u). Seit der Welle L ist sie ein
## SUMMAND: Kartengröße plus Fuge ergibt die Teilung der Reihe, und daraus folgt,
## wie breit der Streifen sein muß - nie umgekehrt.
const MOUTH_GAP := 1.6
const CONSOLE_PAD_X := 1.2
const CONSOLE_PAD_Y := 0.9
## Seitenverhältnis der KASSETTE selbst (Höhe / Breite, 2 : 3).
const CARD_ASPECT := 1.5
## ... und das des MUNDES: die Karte liegt QUER im Schacht (um die Blickachse
## gerollt, Langseite waagerecht), also ist das Loch BREITER als hoch - das
## Verhältnis der Kassette gekippt.
const MOUTH_ASPECT := 1.0 / CARD_ASPECT
## HÖHENRESERVE der Reihe in u: an ihr hängt das Höhenbudget der ganzen Seite
## (bench_aspect), und sie deckelt zugleich die Mundhöhe. Die BREITE des Mundes
## deckelt sie NICHT - die kommt aus der festen Kartengröße (Welle L: die Reihe
## paßt sich der Karte an, nie umgekehrt).
const MOUTH_HEIGHT_UNITS := 16.5
## Luft um die Karte im Loch: der Mund ist eine Spur größer als ihr Fußabdruck,
## sonst schlösse das Blech bündig an ihre Kante an.
const MOUTH_ROOM := 1.09
## Und der BODEN der Teilung, wenn der Tisch den Streifen gekappt hat: enger als
## so rücken die Münder nie zusammen, sonst deckten sich die Karten zu.
const MOUTH_TIGHT := 0.62

## Der Schacht-MUND selbst: ein Loch, kein Ding - dunkle Fläche, Saum in der
## Sortenfarbe der Karte, die darin steht.
const SOCKET_BG := Color("#0b0a18dd")
const SOCKET_RIM := Color("#3b356acc")
const SOCKET_LIVE_RIM := Color("#8be9fdcc")
## Die Münder liegen in einem erhabenen KONSOLEN-BLECH: dieselbe gemalte Tiefe wie
## die Magazin-Fassung (Lichtkante oben, Schattenkante unten), aber neutral - die
## Sortenfarbe gehört der Ware, nicht dem Gerät.
const CONSOLE_BASE := Color("#2f2c3c")
const CONSOLE_SHEEN := Color("#bab7cd")
const CONSOLE_SHEEN_MIX := 0.44
const CONSOLE_SHADOW := Color(0.0, 0.0, 0.0, 0.7)
const CONSOLE_EDGE := 0.33
const CONSOLE_RADIUS := 0.9
## Die Tasche eines Mundes: er liegt IM Blech, also Schatten oben und Licht unten -
## die Umkehrung der Konsolenkante.
const POCKET_BASE := Color("#14121f")
const POCKET_SHEEN := Color(0.66, 0.64, 0.76, 0.5)
const POCKET_SHADOW := Color(0.0, 0.0, 0.0, 0.75)
const POCKET_BLEED := 0.26
const POCKET_EDGE := 0.22
const POCKET_RADIUS := 0.7

## Die NAHT der Schürze - zweimal dasselbe Maß: Fensterkante zu Konsolenband und
## Konsolenband zu Magazin.
const CONSOLE_SHELF_GAP := 2.1
## Höhe des Konsolen-Bandes in u: es trägt seit der KORREKTUR-WELLE J nur noch den
## GRIFF - der Info-Text-Schirm ist ins Fenster gezogen (Zeile 2). Ein Streifen für
## EINEN Knopf, mehr nicht.
const BAND_HEIGHT_UNITS := 6.4

## --- Der TOOLTIP-SCHIRM (KORREKTUR-WELLE J) -------------------------------------
## Er steht DIREKT UNTER der Schacht-Reihe und ist GENAU so breit wie sie (Zeile 2,
## links im BAND; rechts daneben das Soll-Netz). Er erklärt den GEWÄHLTEN Würfel
## (Name, Seele im Essenz-Glühen, Wirkung); beim Hover über eine Magazin-Kassette
## oder eine Netz-Zelle übersteuert DEREN Text. scene_root ist der EINE Schreiber
## (set_info) - das Fenster hält nur die Fassung. Ränder/Grade in u.
## Die Grade sind 2026-09-04 rund verdreifacht worden: in einem 24 u hohen Schirm
## stand die alte Schrift bei 1,3-1,6 u und war schlicht unlesbar.
const INFO_MARGIN := 1.2
const INFO_NAME_UNITS := 5.0
const INFO_SOUL_UNITS := 4.0
const INFO_GAP := 0.6
const INFO_NAME_FONT := 0.8
const INFO_SOUL_FONT := 0.8
## Der Wirkungstext läuft um und PASST SICH EIN: der Schirm ist so breit wie die
## Schacht-Reihe, also mal schmal (zwei Schächte) und mal sehr breit (acht) - ein
## GESETZTER Grad wäre dort abgeschnitten und hier winzig. Genommen wird die größte
## Stufe, die umgebrochen noch in den Restblock paßt.
const INFO_BODY_STEPS := [3.4, 3.0, 2.6, 2.2, 1.9, 1.6, 1.4]
## Absolute Mindesthöhe des Magazin-Streifens (Einheiten u) - der Boden unter dem
## gemessenen Kartenmaß (siehe shelf_min_height).
const SHELF_MIN_HEIGHT := 6.0
## Sollhöhe des Magazin-Streifens (Einheiten u). Die Schürze (Naht + Band + Naht +
## Streifen) wird von scene_root aus der Pool-Höhe herausgerechnet, so dass die
## MAGAZIN-Unterkante bündig mit der Pool-Unterkante säße (apron_span_units) -
## seit die Karte dort FLACH LIEGT (2026-09-04) braucht sie mehr, und der Streifen
## wächst dann nach unten in den freien Filz (Spieler-Entscheid: lieber tiefer als
## ein geschrumpftes Fenster).
const SHELF_STRIP_UNITS := 12.0

## Der EINE Handlungs-Sitz im Band, MITTIG unter der Schacht-Reihe: er trägt
## "Griff n/m" (gesteckt / Serienlänge - der Zähler wohnt seit dem Tod des
## Serien-Schirms in der Aufschrift) bzw. "Fertig". EIN Maß für beide - der Sitz
## steht fest, nur seine Aufschrift wechselt, und die Grundseite fließt nie um.
## Bemessen an der breitesten Aufschrift ("Griff 8/8") plus Rand.
const ACTION_WIDTH := 15.0
const ACTION_HEIGHT := 4.0

## DIE SCHABLONEN-FAHRT - die Zeremonie des Griffs. Die Schablone löst sich aus
## dem IST-NETZ links, fährt die Schiene über der Reihe ab und setzt sich rechts
## in den Zielwürfel. Klick überspringt jederzeit; bei sechs Karten ~4 s.
## Die GEBURT: das Ist-Netz dimmt kurz, die Schablone wächst an seiner Stelle - und
## das Summen-Netz im Diff-Schirm ENTLEERT sich zugleich auf die nackten
## Augenzahlen (die Vorschau tritt ab, die Rechnung beginnt bei 0).
const STENCIL_BIRTH_TIME := 0.3
const STENCIL_TO_RAIL_TIME := 0.42
## Der Takt EINER Karte, mit RAMPE: die letzte fährt in diesem Anteil der ersten.
## Ein Operator bekommt seinen Sondermoment obendrauf.
const STENCIL_STEP_TIME := 0.4
const STENCIL_STEP_RAMP := 0.55
const STENCIL_OPERATOR_EXTRA := 0.3
## Wieviel eines Takts die FAHRT nimmt - der Rest ist das Ticken am Ort.
const STENCIL_MOVE_SHARE := 0.45
const STENCIL_LEAVE_TIME := 0.55
const STENCIL_FOLD_TIME := 0.8
## So dunkel steht das IST-NETZ im Moment der Geburt - es hat seine Schablone eben
## abgegeben (dim_ist_net).
const BIRTH_DIM := 0.3
## Die SCHIENE selbst: ein Strich im oberen Rand des Blechs (er paßt in
## CONSOLE_PAD_Y, also verrückt er nichts). Die Schablone fährt darüber.
const RAIL_TOP := 0.16
const RAIL_HEIGHT := 0.34
const RAIL_TINT := Color("#8be9fdaa")

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
			run.pool_changed.connect(refresh)  # Ist-Schirm und Summen-Netz zeigen den Pool
			run.press_changed.connect(refresh)  # der Griff der Sitzung hängt daran
		refresh()

var _content: Control
## Das EINE Summen-Netz des Fensters. Es überlebt jeden Neuaufbau (es ist kein Kind
## des Inhalts): sein ZÄHL-Takt darf nicht daran zerbrechen, daß eine Kassette
## umsortiert wird - nur so tickt es beim Griff von der Vorschau herunter.
var _net: PressNetView
## Sein PARKPLATZ im Soll-Schirm: ein leerer Platz in Netzgröße, auf den es je
## Bild zurückgesetzt wird. Der Platz ist die gemeldete Netzmitte.
var _net_host: Control
## Der PLATZHALTER im Soll-Schirm: das leere Kreuz, das steht, solange kein Ziel
## gewählt ist - das Soll-Netz ist NIE versteckt.
var _empty_net: Control
## Das leere ERGEBNIS-PODEST rechts: dorthin wechselt der fertige Würfel.
var _stage_host: Control
## Sein Spiegelbild links: das ZIEL-PODEST, auf das der Vorrats-Würfel fährt.
var _target_stage_host: Control
## Der IST-SCHIRM links und das Feld, in dem sein Netz sitzt.
var _ist_screen: Panel
var _ist_net_host: Control
## Die Schacht-Münder; jeder ein Loch mit seinem Knopf darüber.
var _slot_buttons: Array[Button] = []
## Die gezeichneten Münder selbst - IHRE Mitte ist der Steckplatz der Zelle, nicht
## die des Knopfes (der spannt die ganze Tasche).
var _slit_panels: Array[Panel] = []
## Dieselbe Reihe als KARTEN-FLÄCHEN (heute deckungsgleich mit dem Mund: die Karte
## liegt geneigt darüber) und das Glühen der Schächte.
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
## Fußabdruck einer LIEGENDEN Datenzelle in Display-Pixeln (ihre Kartenfläche:
## LANGSEITE × Breite - sie liegt quer); scene_root misst ihn an der
## Welt-Projektion und schiebt ihn herein (ZERO = noch unbekannt, dann trägt das
## Rückfallmaß der Leiste).
var data_cell_px := Vector2.ZERO:
	set(value):
		if data_cell_px.is_equal_approx(value):
			return
		data_cell_px = value
		refresh()
## Die Maßeinheit u des Fensters (0 = die u-Konvention, Fensterbreite/100). Seit
## der Welle L kann der STREIFEN breiter sein, als seine 100 u ausmachen: die
## Schacht-Reihe wächst mit der FESTEN Kartengröße nach rechts, das Fenster mit
## ihr. Dann gibt scene_root die Einheit aus der HÖHE vor (dasselbe
## apron_bottom-Muster), sonst zerrisse die breitere Reihe die senkrechte
## Rechnung (bench_aspect).
var unit_px := 0.0:
	set(value):
		if is_equal_approx(unit_px, value):
			return
		unit_px = value
		refresh()

## Der SOLL-SCHIRM rechts - er trägt NUR noch das Ergebnis-Netz, ohne Hintergrund.
var _diff_screen: Panel

## DIE SERIE: die uids der gesteckten Karten in STECKREIHENFOLGE - sie SIND die
## Rechnung. uids, nicht Indizes: das Magazin darf darunter umsortiert werden.
var _series: Array[int] = []
## Plätze im Pool: der Zielwürfel und (nur mit Doppelmatrize) der zweite.
var _target_index := -1
var _second_index := -1
## Die Karte unter dem Zeiger (-1 = keine): ihre Beitrags-Zellen leuchten im
## Summen-Netz, alles andere verblaßt - und ihre Diff-Zeile leuchtet mit.
var _hover_slot := -1
## Der Slot, auf dem ein Zug begonnen hat (-1 = keiner).
var _drag_from := -1

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

## DAS ERGEBNIS DER LETZTEN BUCHUNG - es bleibt im Soll-Schirm STEHEN, bis ein
## anderes Ziel gewählt oder abgewählt wird (siehe showing_result). _result_die ist
## der Stand VOR dem Griff: erst der Vergleich mit der Projektion macht die grünen
## Deltas.
var _result_die: DieDefinition
var _result_projection: Dictionary = {}

## Das Blech der Schacht-Reihe (null = steht gerade nicht).
var _console: Panel
## Der Knopf des Handlungs-Sitzes.
var _action_button: Button
## Die drei Zeilen des Info-Text-Schirms (null = Band steht gerade nicht) und der
## zuletzt gesetzte Seelen-Ton (Farbwechsel bei gleichem Text sähe der Text-Vergleich
## sonst nicht).
var _info_name: Label
var _info_soul: Label
var _info_body: Label
## Der Restblock des Wirkungstextes und die Einheit, in der seine Leiter mißt.
var _info_body_span := Vector2.ZERO
var _info_unit := 0.0
var _info_soul_tint := Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Knöpfe fangen selbst
	# NICHT beschnitten: Konsolen-Band und Magazin hängen absichtlich unter der
	# Fensterkante heraus (die Schürze).
	clip_contents = false
	# KEIN Fenster-Hintergrund: die Teile des Streifens liegen auf dem Filz, das
	# Rechteck lebt nur noch für Klick-Zone und Kamera weiter.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	set_process(true)  # das Summen-Netz hält seinen Platz im Diff-Schirm
	refresh()

## Das Summen-Netz PARKT auf seinem Platz - es folgt damit jedem Neuaufbau des
## Schirms, ohne daß irgendwer es zurückschreiben müßte.
func _process(_delta: float) -> void:
	_sync_sum_net_park()

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

## Baut das Fenster neu und meldet danach, wo das Podest jetzt liegt - der ECHTE
## Würfel darüber gehört scene_root, nicht diesem Fenster.
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
	_target_stage_host = null
	_ist_screen = null
	_ist_net_host = null
	_net_host = null
	_empty_net = null
	_diff_screen = null
	_free_own(_drawer)  # Band und Magazin hängen am Panel, nicht am Inhalt
	_drawer = null
	_free_own(_band)
	_band = null
	_info_name = null  # die Info-Zeilen hingen am Band
	_info_soul = null
	_info_body = null
	_prune_series()
	var u := unit()
	_free_own(_content)
	_content = null  # queue_free wirkt erst am Bildende - sonst hängt hier ein Zombie
	_console = null
	_action_button = null

	# Die Schürze steht IMMER: Konsolen-Band und Magazin gehören zur Bank, nicht zu
	# einem Ablauf - gesperrt wird nur, was gerade niemand anfassen darf.
	_build_series_band(u)
	_build_drawer(u)

	# Der Träger deckt das GANZE Fenster: seine Kinder liegen damit in
	# Fenster-Koordinaten, genau so, wie street_rect & Co. sie melden (die Ränder
	# stecken schon in street_rect - ein zweites Mal abgesetzt drifteten gemeldete
	# und gestellte Plätze um einen Rand auseinander).
	_content = Control.new()
	_content.name = "Street"
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_build_street(u)
	_ensure_sum_net(u)  # zuletzt: das Netz liegt über allem

## Das SUMMEN-NETZ wird nie neu gebaut, nur neu ausgelegt - sonst risse jeder
## Neuaufbau des Fensters seinen laufenden Zähl-Takt ab.
func _ensure_sum_net(u: float) -> void:
	if _net == null or not is_instance_valid(_net):
		_net = PressNetView.new()
		add_child(_net)
	_net.cell = net_cell(u)
	move_child(_net, get_child_count() - 1)
	if not burning():
		_refresh_preview_net()
	_sync_empty_net()
	_sync_sum_net_park()

## Sein Platz: die Mitte des Parkplatzes im Diff-Schirm.
func _sync_sum_net_park() -> void:
	if _net == null or not is_instance_valid(_net):
		return
	if _net_host == null or not is_instance_valid(_net_host):
		return
	var host := _net_host.get_global_rect()
	if host.size.x <= 0.0:
		return
	_net.position = host.get_center() - _net.size * 0.5 - get_global_rect().position

## Hängt ein eigenes Kind aus und gibt es frei; queue_free wirkt erst am
## Bildende, ein Neuaufbau träfe sonst auf seinen eigenen Vorgänger.
func _free_own(node: Node) -> void:
	if node != null and is_instance_valid(node):
		remove_child(node)
		node.queue_free()

# --- DIE STRASSE: Schacht-Reihe, Ergebnis-Spalte ---------------------------------

## Der Innenraum des Fensters in Fenster-Koordinaten - die Straße liegt darin.
func street_rect() -> Rect2:
	var u := unit()
	return Rect2(Vector2(u * CONTENT_MARGIN_X, u * CONTENT_MARGIN_Y),
		Vector2(maxf(size.x - u * CONTENT_MARGIN_X * 2.0, 1.0),
			maxf(size.y - u * CONTENT_MARGIN_Y * 2.0, 1.0)))

## Die ERGEBNIS-SPALTE rechts: Ergebnis-Podest über dem Soll-Schirm, volle Höhe
## der Straße.
func result_column_rect() -> Rect2:
	var u := unit()
	var street := street_rect()
	var width := u * DIFF_WIDTH_UNITS
	return Rect2(Vector2(street.end.x - width, street.position.y),
		Vector2(width, street.size.y))

## Ihr SPIEGELBILD links: die ZIEL-SPALTE - Ziel-Podest über dem Ist-Schirm. Sie
## macht den Streifen vom Ausgabefach unabhängig (2026-09-04).
func bench_column_rect() -> Rect2:
	var u := unit()
	var street := street_rect()
	return Rect2(street.position, Vector2(u * DIFF_WIDTH_UNITS, street.size.y))

## Das BAND - die ZEILE 2 der Straße (KORREKTUR-WELLE J): es liegt am Fuß der
## Straße und trägt links den Tooltip-Schirm, rechts das Soll-Netz. EINE Zeile,
## also EIN Rechteck - beide bekommen daraus ihre Höhe.
func band_row_rect() -> Rect2:
	var u := unit()
	var street := street_rect()
	var height := minf(u * DIFF_HEIGHT_UNITS, street.size.y)
	return Rect2(Vector2(street.position.x, street.end.y - height),
		Vector2(street.size.x, height))

## Der SOLL-SCHIRM: die rechte Hälfte des Bandes - unter dem Ergebnis-Podest, auf
## derselben Zeile wie der Tooltip links.
func diff_screen_rect() -> Rect2:
	var column := result_column_rect()
	var band := band_row_rect()
	return Rect2(Vector2(column.position.x, band.position.y),
		Vector2(column.size.x, band.size.y))

## Der IST-SCHIRM: die linke Hälfte des Bandes, unter dem Ziel-Podest.
func ist_screen_rect() -> Rect2:
	var column := bench_column_rect()
	var band := band_row_rect()
	return Rect2(Vector2(column.position.x, band.position.y),
		Vector2(column.size.x, band.size.y))

## Das ERGEBNIS-PODEST: über dem Soll-Schirm, um die Fuge abgesetzt - dorthin
## wechselt der Zielwürfel am Ende der Serie.
func result_podium_rect() -> Rect2:
	return _podium_over(result_column_rect(), diff_screen_rect())

## Das ZIEL-PODEST: dasselbe eine Stockwerk über dem Ist-Schirm.
func target_podium_rect() -> Rect2:
	return _podium_over(bench_column_rect(), ist_screen_rect())

## EINE Podest-Rechnung für beide Spalten: über dem Netz-Schirm, um die Fuge
## abgesetzt, unter dem Kopfraum der Straße.
func _podium_over(column: Rect2, screen: Rect2) -> Rect2:
	var u := unit()
	var bottom := screen.position.y - u * STAGE_NET_GAP
	var top := maxf(column.position.y + u * STAGE_HEAD_ROOM, bottom - u * STAGE_HEIGHT)
	return Rect2(Vector2(column.position.x, top),
		Vector2(column.size.x, maxf(bottom - top, 1.0)))

## Der Platz der SCHACHT-REIHE: die Straße ZWISCHEN den beiden Podest-Spalten.
func row_field_rect() -> Rect2:
	var u := unit()
	var street := street_rect()
	var left := bench_column_rect().end.x + u * STREET_GAP
	var right := result_column_rect().position.x - u * STREET_GAP
	return Rect2(Vector2(left, street.position.y),
		Vector2(maxf(right - left, u * 10.0), street.size.y))

func _build_street(u: float) -> void:
	_build_bench_column(u)
	_build_shaft_row(u)
	_build_info_screen(u)  # Zeile 2 mittig: der Tooltip unter der Reihe
	_build_result_column(u)

# --- Die ERGEBNIS-SPALTE: Ergebnis-Podest über dem SOLL-SCHIRM -------------------

func _build_result_column(u: float) -> void:
	_stage_host = _podium_host("ResultStage", result_podium_rect())
	_build_diff_screen(u)

## Die ZIEL-SPALTE links: Ziel-Podest über dem IST-SCHIRM - dasselbe Gerüst wie
## rechts, nur zeigt ihr Netz den Würfel, WIE ER IST.
func _build_bench_column(u: float) -> void:
	_target_stage_host = _podium_host("TargetStage", target_podium_rect())
	_build_ist_screen(u)

## Der leere Platz eines Podests: das Fenster MELDET ihn, gestellt wird der Körper
## von scene_root.
func _podium_host(host_name: String, podium: Rect2) -> Control:
	var stage := Control.new()
	stage.name = host_name
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.position = podium.position
	stage.size = podium.size
	_content.add_child(stage)
	return stage

## Der IST-SCHIRM: das Spiegelbild des Soll-Schirms, auf blankem Filz. Er trägt das
## Netz des GEWÄHLTEN Zielwürfels; ohne Ziel steht dort dasselbe leere Kreuz wie
## rechts - beide Spalten stehen IMMER.
func _build_ist_screen(u: float) -> void:
	var rect := ist_screen_rect()
	var screen := Panel.new()
	screen.name = "IstScreen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # blanker Filz
	screen.position = rect.position
	screen.size = rect.size
	_content.add_child(screen)
	_ist_screen = screen
	var cell := net_cell(u)
	var span := DieNetView.net_size(cell)
	var host := Control.new()
	host.name = "IstNet"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.position = Vector2((rect.size.x - span.x) * 0.5, u * DIFF_PAD)
	host.size = span
	screen.add_child(host)
	_ist_net_host = host
	var die := target_die()
	host.add_child(DieNetView.build(die, -1, cell) if die != null \
		else _empty_net_cross(cell))

## Der SOLL-SCHIRM: das UI-SPIEGELBILD des linken Netzes. Ohne eigenen Hintergrund
## (blanker Filz), er trägt NUR das Ergebnis-Netz - der physische Ergebnis-Würfel
## steht über ihm auf dem Podest, das Netz DIREKT darunter, gleich groß wie links.
func _build_diff_screen(u: float) -> void:
	var rect := diff_screen_rect()
	var screen := Panel.new()
	screen.name = "DiffScreen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # blanker Filz
	screen.position = rect.position
	screen.size = rect.size
	_content.add_child(screen)
	_diff_screen = screen
	var pad := u * DIFF_PAD
	# Der PARKPLATZ des Netzes: ein leerer Platz in Netzgröße, OBEN unter dem Podest
	# (der Würfel schwebt darüber). Das Netz fährt, dieser Platz nie.
	var cell := net_cell(u)
	var span := DieNetView.net_size(cell)
	var host := Control.new()
	host.name = "TargetNet"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.position = Vector2((rect.size.x - span.x) * 0.5, pad)
	host.size = span
	screen.add_child(host)
	_net_host = host
	# Das SOLL-NETZ steht IMMER (KORREKTUR-WELLE J): ohne Ziel und ohne Karten malt
	# PressNetView nichts, dann steht das leere Kreuz an seiner Stelle. Es hängt
	# NEBEN dem Parkplatz, nicht darin - der bleibt ein leerer Platz.
	_empty_net = _empty_net_cross(cell)
	_empty_net.position = host.position
	screen.add_child(_empty_net)
	_sync_empty_net()

## Das LEERE Kreuz: sechs dunkle Zellen an den Netz-Plätzen, sonst nichts - der
## Platzhalter des Soll-Netzes.
func _empty_net_cross(cell: float) -> Control:
	var cross := Control.new()
	cross.name = "EmptyNet"
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.size = DieNetView.net_size(cell)
	for face in 6:
		var chip := Panel.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.position = DieNetView.cell_position(face, cell)
		chip.size = Vector2.ONE * cell
		var box := StyleBoxFlat.new()
		box.bg_color = PressNetView.EMPTY_CELL
		box.border_color = PressNetView.EMPTY_RIM
		box.set_border_width_all(maxi(1, int(cell * 0.08)))
		box.set_corner_radius_all(maxi(2, int(cell * 0.16)))
		chip.add_theme_stylebox_override("panel", box)
		cross.add_child(chip)
	return cross

## Er steht genau dann, wenn das echte Netz nichts malt (kein Ziel gewählt).
func _sync_empty_net() -> void:
	if _empty_net == null or not is_instance_valid(_empty_net):
		return
	_empty_net.visible = preview_target() == null

## Das EINE Zellmaß beider Netze: seit die Spalten im selben Fenster liegen, rechnet
## es das Fenster selbst - aus der ENGEREN der beiden, so daß Ist und Soll GLEICH
## GROSS stehen (der Melde-Weg von aussen ist damit fort).
func net_cell(u: float) -> float:
	var ist := ist_screen_rect()
	var diff := diff_screen_rect()
	var pad := u * DIFF_PAD
	return DieNetView.cell_for(Vector2(
		maxf(minf(ist.size.x, diff.size.x) - pad * 2.0, 1.0),
		maxf(minf(ist.size.y, diff.size.y) * DIFF_NET_SHARE, 1.0)))

# --- Die Würfel des Vorrats und die Zielwahl ---------------------------------------

## Die Würfel des Vorrats (ohne Lauf leer) - daraus liest die Zielwahl ihren Index.
func pool_defs() -> Array[DieDefinition]:
	if run == null:
		return [] as Array[DieDefinition]
	return run.owned_pool

## Der gewählte Zielwürfel (null = keiner).
func target_die() -> DieDefinition:
	var defs := pool_defs()
	if _target_index < 0 or _target_index >= defs.size():
		return null
	return defs[_target_index]

## Der zweite Würfel der Doppelmatrize. DEAKTIVIERT diese Welle (das Podest trägt
## nur EIN Ziel): apply_series bekommt immer null, die Zweitprojektion der
## Matrix-Karte ist inert - eine Folge-Welle löst sie.
func second_die() -> DieDefinition:
	return null

func target_index() -> int:
	return _target_index

func second_index() -> int:
	return _second_index

## Steckt eine Doppelmatrize in der Reihe? DEAKTIVIERT diese Welle - sie verlangt
## keinen zweiten Würfel mehr (siehe second_die), also mahnt der Serien-Schirm
## auch keinen an und der Griff steht ohne ihn bereit.
func needs_second() -> bool:
	return false

## Die ZIELWAHL per Pool-Klick: scene_root meldet den angetippten physischen
## Würfel. Derselbe wählt ab, ein anderer wechselt (die Bühnen-Fahrt räumt und
## holt neu). null oder ein Würfel, den der Pool nicht kennt, wählt ab.
func set_target_die(die: DieDefinition) -> void:
	if editing_locked or burning():
		return
	var index := pool_defs().find(die) if die != null else -1
	if index < 0 or index == _target_index:
		clear_target()
		return
	_target_index = index
	_announce_target()

## Wählt ab (kein Ziel mehr) - der Podest-Würfel fährt in seinen Pool-Sitz zurück.
func clear_target() -> void:
	if _target_index < 0 and _second_index < 0:
		return
	_target_index = -1
	_second_index = -1
	_announce_target()

## Wählt den Zielwürfel programmatisch (Tests, Debug) - am Tisch tippt der Spieler
## einen physischen Pool-Würfel an.
func choose_target(index: int) -> void:
	var defs := pool_defs()
	set_target_die(defs[index] if index >= 0 and index < defs.size() else null)

func _announce_target() -> void:
	_drop_result()  # ein anderes Ziel hat kein Ergebnis
	refresh()
	target_chosen.emit(target_die())

## Der Zielwürfel, den das Summen-Netz zeigt: während der Zeremonie der Stand VOR
## dem Griff (nur so kann das Netz von 0 hochticken), danach der ERGEBNIS-Stand
## (auch der Stand davor - die grünen Deltas leben vom Vergleich), sonst der echte.
func preview_target() -> DieDefinition:
	if burning():
		return _burn_die
	if showing_result():
		return _result_die
	return target_die()

## STEHT gerade das ERGEBNIS der letzten Buchung im Soll-Schirm? Es bleibt, bis ein
## anderes Ziel gewählt oder abgewählt wird - und eine neu gesteckte Karte übernimmt
## ihn sofort wieder als Vorschau.
func showing_result() -> bool:
	return not burning() and _result_die != null and _series.is_empty()

## Das Ergebnis verfällt: eine neue Zielwahl (oder die Abwahl) räumt es fort.
func _drop_result() -> void:
	_result_die = null
	_result_projection = {}

## DIE LIVE-VORSCHAU: was die gesteckte Serie auf dem Zielwürfel ergäbe. Sie ist
## buchstäblich dieselbe Rechnung, die der Griff bucht ({} = keine).
## Während der Zeremonie zählt sie nur die Karten, die die Welle schon erfaßt hat.
func preview() -> Dictionary:
	if burning():
		return SeriesResolver.resolve(_burn_nets_so_far(), _burn_die, _burn_terms)
	if showing_result():
		return _result_projection
	if run == null or target_die() == null or _series.is_empty():
		return {}
	return run.resolve_series(_series, target_die())

## Die Auflösung der GANZEN Serie - auch während der Fahrt, in der preview() nur die
## schon erfaßten Karten zählt: das stehende Ergebnis merkt sich die volle Buchung.
func _full_projection() -> Dictionary:
	if not burning():
		return preview()  # showing_result liefert dort die ganze Buchung
	var nets: Array = []
	for card in _burning:
		if String(card.get("catalyst", "")) == "":
			nets.append(card.get("net", []))
	return SeriesResolver.resolve(nets, _burn_die, _burn_terms)

## Die Seiten, die die überfahrene Karte beiträgt (leer = kein Hover). Sie liest die
## gesteckten Karten - steht das Ergebnis, ist die Reihe leer und nichts leuchtet.
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

## Display-Pixel der ERGEBNIS-PODEST-Mitte (Vector2(-1,-1) = die Spalte steht
## gerade nicht) - dorthin wechselt der fertige Würfel.
func result_net_center() -> Vector2:
	if _stage_host == null or not is_instance_valid(_stage_host):
		return Vector2(-1, -1)
	return _stage_host.get_global_rect().get_center()

func result_projector_y() -> float:
	if _stage_host != null and is_instance_valid(_stage_host):
		return _stage_host.get_global_rect().get_center().y
	return get_global_rect().get_center().y

## Display-Pixel der ZIEL-PODEST-Mitte ((-1,-1) = die Spalte steht gerade nicht) -
## dorthin fährt der angetippte Vorrats-Würfel.
func target_net_center() -> Vector2:
	if _target_stage_host == null or not is_instance_valid(_target_stage_host):
		return Vector2(-1, -1)
	return _target_stage_host.get_global_rect().get_center()

func target_projector_y() -> float:
	if _target_stage_host != null and is_instance_valid(_target_stage_host):
		return _target_stage_host.get_global_rect().get_center().y
	return get_global_rect().get_center().y

## Display-Pixel des IST-NETZES ((-1,-1) = es steht gerade nicht) - der GEBURTSORT
## der Schablone.
func ist_net_center() -> Vector2:
	if _ist_net_host == null or not is_instance_valid(_ist_net_host):
		return Vector2(-1, -1)
	return _ist_net_host.get_global_rect().get_center()

## Das IST-NETZ dunkelt kurz nach - es hat seine Schablone eben abgegeben.
func dim_ist_net(time: float) -> void:
	if _ist_screen == null or not is_instance_valid(_ist_screen):
		return
	_ist_screen.modulate = Color.WHITE  # Endzustand zuerst
	var dim := create_tween()
	dim.tween_property(_ist_screen, "modulate",
		Color(BIRTH_DIM, BIRTH_DIM, BIRTH_DIM), maxf(time * 0.3, 0.01))
	dim.tween_property(_ist_screen, "modulate", Color.WHITE, maxf(time * 0.7, 0.01))

## Display-Pixel des PARKPLATZES des Summen-Netzes im Soll-Schirm ((-1,-1) = er
## steht gerade nicht). Der Schlitten fährt, dieser Platz nie.
func sum_net_center() -> Vector2:
	if _net_host == null or not is_instance_valid(_net_host):
		return Vector2(-1, -1)
	return _net_host.get_global_rect().get_center()

## Steht die Bank gerade so da, dass ein Würfel darüber schweben darf? Sie steht
## IMMER - die Straße ist Möbel, kein Ablauf. (Die KAMERA fragt hier nicht mit.)
func bench_open() -> bool:
	return true

## Das Konsolen-Band: es liegt GANZ unter dem Fenster, eine Naht unter seiner
## Kante - und dieselbe Naht trennt es vom Magazin.
func console_band_rect() -> Rect2:
	var u := unit()
	return Rect2(Vector2(0.0, size.y + u * CONSOLE_SHELF_GAP),
		Vector2(size.x, band_size(u).y))

## Maße des Bandes: die volle Fensterbreite, feste Höhe.
func band_size(u: float) -> Vector2:
	return Vector2(maxf(size.x, u * 100.0), u * BAND_HEIGHT_UNITS)

## Fenster PLUS Schürze in Display-Pixeln: alles, was zur Werkbank gehört - und
## damit die EINE Weiterleitungs-Region. Sie streckt sich nach UNTEN bis zur
## echten Magazin-Unterkante (die seit 2026-09-04 unter die Schürzenlinie reichen
## darf): ragte die Grube darüber hinaus, fiele jeder Chip-Tap dort durch (der
## Welle-H-Bug, zweimal geheilt).
func bench_rect() -> Rect2:
	var rect := get_global_rect()
	rect.size.y = maxf(rect.size.y, maxf(apron_bottom_y(), shelf_rect().end.y))
	return rect

## Das Seitenverhältnis (Breite/Höhe) der Werkbank - GELÖST, nicht gesetzt. Die
## Grundseite ist die STRASSE, und sie trägt DREI Spalten über EINEM Band: aussen
## Kopfraum, Podest, Fuge (beide Podest-Spalten gleich hoch); in der Mitte die
## Höhenreserve der Schacht-Reihe und ihre Fuge - die HÖHERE gibt das Maß. Es löst
## nur noch die HÖHE gegen die Maßeinheit u; die BREITE kommt seit der Welle L aus
## der Reihe selbst (bench_width_for) und ist mindestens diese 100 u.
static func bench_aspect() -> float:
	var column := STAGE_HEAD_ROOM + STAGE_HEIGHT + STAGE_NET_GAP + DIFF_HEIGHT_UNITS
	var row := MOUTH_HEIGHT_UNITS + CONSOLE_PAD_Y * 2.0 + ROW_BAND_GAP \
		+ DIFF_HEIGHT_UNITS
	return 100.0 / (CONTENT_MARGIN_Y * 2.0 + maxf(column, row))

## Die Maßeinheit u dieses Fensters: die vorgegebene, sonst die u-Konvention
## (Fensterbreite/100). Alles Gesetzte im Fenster rechnet in ihr.
func unit() -> float:
	if unit_px > 0.0:
		return unit_px
	return maxf(size.x, 200.0) / 100.0

## Wie tief die Schürze unter der Fensterkante hängt, in Einheiten u: Naht, ganzes
## Konsolen-Band, Naht, Magazin-Streifen - eine reine Konstante, kein Weltmaß.
## scene_root darf sie über apron_bottom auf ein größeres Maß strecken.
func apron_units() -> float:
	return apron_span_units()

## Dieselbe Kette, statisch: scene_root löst daraus die Fensterhöhe, so dass
## Fenster PLUS Schürze in die Pool-Höhe passen (die Magazin-Unterkante trifft
## dann die Pool-Unterkante).
static func apron_span_units() -> float:
	return CONSOLE_SHELF_GAP * 2.0 + BAND_HEIGHT_UNITS + SHELF_STRIP_UNITS

## Unterkante der Schürze in Fenster-Koordinaten (siehe apron_bottom).
func apron_bottom_y() -> float:
	if apron_bottom > size.y:
		return apron_bottom
	return size.y + unit() * apron_units()

# --- Die SCHACHT-REIHE -------------------------------------------------------------

## Wie viele Schächte die Reihe trägt: die Serienlänge des Laufs, mindestens so
## viele, wie gerade stecken (eine geschrumpfte Leiter wirft keine Karte fort).
func slot_count() -> int:
	var slots := run.series_slots() if run != null else FALLBACK_SLOTS
	return maxi(slots, _slot_cards().size())

## Die LANGSEITE einer Kassette in Fenster-Pixeln, in der EINEN Größe, die sie
## überall hat. Sie ist die Bezugsgröße der ganzen Reihe (Welle L).
func card_span_px() -> float:
	return shelf_cell_px().x * PackDrawerView.CASSETTE_SCALE

## Breite EINES Schacht-Mundes: die Kartenbreite plus Luft. Nicht mehr aus dem
## verfügbaren Platz gelöst - die Karte schrumpft nie, die REIHE wächst, und mit
## ihr der ganze Streifen (siehe bench_width_for).
func mouth_width(_u: float) -> float:
	return card_span_px() * MOUTH_ROOM

## Die Mundhöhe folgt dem Kartenformat, bleibt aber in der Höhenreserve der Reihe:
## die Karte SCHWEBT über ihrem Loch, ein knapper Mund liegt hinter ihr.
func mouth_size(u: float) -> Vector2:
	var wide := mouth_width(u)
	return Vector2(wide, minf(wide * MOUTH_ASPECT, u * MOUTH_HEIGHT_UNITS))

## Die TEILUNG der Reihe: Kartenbreite plus Fuge. Hat der TISCH den Streifen
## gekappt (er ist endlich), schließt sich die FUGE, bis die Reihe wieder in ihr
## Feld paßt - die KARTE behält ihre Größe, notfalls rücken die Münder zusammen.
func mouth_step(u: float) -> float:
	var wide := mouth_width(u)
	var columns := float(slot_count())
	if columns < 2.0:
		return wide + u * MOUTH_GAP
	var room := row_field_rect().size.x - u * CONSOLE_PAD_X * 2.0
	return clampf((room - wide) / (columns - 1.0), wide * MOUTH_TIGHT,
		wide + u * MOUTH_GAP)

## Maße des Blechs: die Münder mit ihrer Teilung, plus Rand.
func console_size(u: float) -> Vector2:
	var columns := float(slot_count())
	return Vector2(mouth_width(u) + (columns - 1.0) * mouth_step(u)
		+ u * CONSOLE_PAD_X * 2.0,
		mouth_size(u).y + u * CONSOLE_PAD_Y * 2.0)

## Die Breite des KONSOLEN-BLECHS für slots Münder - eine reine Rechnung, damit
## scene_root den Streifen stellen kann, bevor das Fenster steht.
static func row_span(slots: int, u: float, mouth: float) -> float:
	var columns := float(maxi(slots, 1))
	return columns * mouth + (columns - 1.0) * u * MOUTH_GAP + u * CONSOLE_PAD_X * 2.0

## Wie BREIT das Fenster sein muß, damit slots Kassetten in ihrer einen Größe
## nebeneinander in die Reihe passen: die Reihe plus alles, was links und rechts
## von ihr in u steht (Ränder plus ZWEIMAL Fuge und Podest-Spalte - wird die zweite
## vergessen, läuft die Reihe über ihr Feld hinaus). Die u-Konvention (100 u) bleibt
## der Boden - schmaler wird der Streifen nie.
static func bench_width_for(slots: int, u: float, card_px: float) -> float:
	var row := row_span(slots, u, card_px * MOUTH_ROOM)
	return maxf(u * 100.0, row + u * (CONTENT_MARGIN_X * 2.0
		+ (STREET_GAP + DIFF_WIDTH_UNITS) * 2.0))

## Die Reihe als flache Leiste, eingelassen in ihr Konsolen-Blech. Ein belegter
## Schacht trägt seine echte Kassette (scene_root stellt sie); ein Klick nimmt sie
## zurück ins Magazin, ein ZUG sortiert die Reihe um.
## Der Platz des KONSOLEN-BLECHS in Fenster-Koordinaten: mittig im Reihen-Feld und
## OBEN (Zeile 1). Eine reine Funktion - der Tooltip darunter fragt sie ab und
## bekommt daraus GENAU seine Kanten.
func console_rect(u: float) -> Rect2:
	var field := row_field_rect()
	var span := console_size(u)
	return Rect2(Vector2(field.position.x + (field.size.x - span.x) * 0.5,
		field.position.y), span)

func _build_shaft_row(u: float) -> void:
	var plate := console_rect(u)
	var span := plate.size
	var console := Panel.new()
	console.name = "SeriesConsole"
	console.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# OBEN im Feld, nicht mittig: die Reihe liest auf DERSELBEN Zeile wie das Podest
	# rechts, und der Tooltip darunter behält seinen eigenen Platz.
	console.position = plate.position
	console.size = span
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
	_content.add_child(console)
	console.add_child(_series_rail(u))

	var cards := _slot_cards()
	var slots := slot_count()
	_portals.resize(slots)
	var mouth := mouth_size(u)
	var step := mouth_step(u)
	var left := u * CONSOLE_PAD_X
	for i in slots:
		var card: Dictionary = cards[i] if i < cards.size() else {}
		var seat := _shaft_mouth(i, u, card)
		seat.position = Vector2(left + float(i) * step, u * CONSOLE_PAD_Y)
		seat.size = mouth
		console.add_child(seat)

## Die SCHIENE über der Reihe: der Weg des Schlittens (und, ab Welle C, der
## Schablone), als Strich im oberen Rand des Blechs. Sie liegt IN CONSOLE_PAD_Y -
## die Reihe rückt für sie nicht.
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

## EIN SCHACHT-MUND: ein LOCH im Blech, in dem die echte Kassette steht. Der KNOPF
## spannt ihn und fängt allein Klick und Zeiger - gezeichnet wird von seinen
## Kindern, der Körper gehört scene_root.
func _shaft_mouth(index: int, u: float, card: Dictionary) -> Button:
	var slot := Button.new()
	slot.name = "SeriesSlot"
	slot.focus_mode = Control.FOCUS_NONE
	slot.disabled = true
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		slot.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	slot.add_child(_slot_pocket(u))
	var portal := PressPortalView.new()
	portal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(portal)
	portal.setup(String(card.get("sort", "")), _slot_tint(card))
	if index < _portals.size():
		_portals[index] = portal
	var mouth := Panel.new()
	mouth.name = "Slit"
	mouth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouth.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouth.add_theme_stylebox_override("panel", _mouth_box(_slot_tint(card), u))
	slot.add_child(mouth)

	_arm_slot(slot, index, card)
	_slot_buttons.append(slot)
	_slit_panels.append(mouth)
	_card_panels.append(mouth)
	return slot

## Die Vertiefung, in der ein Mund liegt.
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

## Ein Klick auf den belegten Schacht nimmt seine Karte zurück ins Magazin, ein ZUG
## legt sie an eine andere Stelle der Reihe - dieselbe Trennung wie im Vorrat:
## gezogen sortiert um, getippt handelt.
func _arm_slot(slot: Button, index: int, card: Dictionary) -> void:
	if card.is_empty() or burning():
		return
	slot.disabled = editing_locked
	slot.tooltip_text = "%s\n%s" % [String(card.get("name", "")), String(card.get("body", ""))]
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.pressed.connect(clear_press_slot.bind(index))
	slot.gui_input.connect(_on_slot_input.bind(index))

## Maße der Reihe, die außen gefragt werden (Tests, Anker-Rechnungen).
func card_size(u: float) -> Vector2:
	return mouth_size(u)

func socket_size(u: float) -> Vector2:
	return mouth_size(u)

func slit_size(u: float) -> Vector2:
	return mouth_size(u)

## Die Farbe eines Schachts: leer der stumpfe Rand, belegt AMBER für Operatoren und
## sonst die Sortenfarbe - eine Quelle für Saum und Glühen.
func _slot_tint(card: Dictionary) -> Color:
	if card.is_empty():
		return SOCKET_RIM
	if String(card.get("operator", "")) != "":
		return OPERATOR_TINT
	return PackDrawerView.COLORS.get(String(card.get("sort", "")), SOCKET_LIVE_RIM)

func _mouth_box(rim: Color, u: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = SOCKET_BG
	box.border_color = rim
	box.set_border_width_all(maxi(1, int(u * 0.18)))
	box.set_corner_radius_all(int(u * POCKET_RADIUS))
	return box

## Die Sorten der belegten Schächte, in Reihenfolge - scene_root legt daran seine
## Zellen ab.
func press_slot_sorts() -> Array[String]:
	var sorts: Array[String] = []
	for card in _slot_cards():
		sorts.append(String(card.get("sort", "")))
	return sorts

## Die uids derselben Reihe - scene_root übernimmt daran die Magazin-Körper in die
## Schächte und gibt sie beim Auswerfen an ihre Plätze zurück.
func press_slot_uids() -> Array[int]:
	var uids: Array[int] = []
	for card in _slot_cards():
		uids.append(int(card.get("uid", 0)))
	return uids

## Display-Pixel der SCHACHT-MÜNDER (leere eingeschlossen) - dort steht die Zelle
## eines belegten Schachts.
func press_slot_anchors() -> Array[Vector2]:
	var anchors: Array[Vector2] = []
	for slit in _slit_panels:
		if is_instance_valid(slit):
			anchors.append(slit.get_global_rect().get_center())
	return anchors

## Display-Pixel der KARTEN-FLÄCHEN derselben Reihe (leere eingeschlossen) - sie
## sind die Stützpunkte der Schiene. Die Karte liegt geneigt über ihrem Mund, also
## ist es heute derselbe Punkt; Welle C hängt ihre Schablone daran.
func press_display_anchors() -> Array[Vector2]:
	var anchors: Array[Vector2] = []
	for field in _card_panels:
		if is_instance_valid(field):
			anchors.append(field.get_global_rect().get_center())
	return anchors

## Das Magazin ist zu: unterschrieben oder die Zeremonie läuft.
func shelf_locked() -> bool:
	return editing_locked or burning()

## Legt GENAU diese Karte in den nächsten freien Serien-Schacht. false = keine
## solche Karte, kein Platz frei oder das Magazin ist zu.
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

## Nimmt eine Karte wieder aus ihrem Schacht - sie liegt danach wieder auf ihrem
## Magazin-Platz. Gemeldet wird VOR dem Neuaufbau: die Zelle dieses Platzes muss
## sich ausklinken, bevor die Sockel neu abgezählt werden.
func clear_press_slot(index: int) -> void:
	if index < 0 or index >= _series.size() or editing_locked or burning():
		return
	var uid := _series[index]
	_series.remove_at(index)
	pack_unslotted.emit(index, uid)
	refresh()

## UMSORTIEREN in der Reihe: die Karte wird an from herausgenommen und bei to
## eingesetzt, alles dazwischen rückt eine Stelle - dieselbe move-statt-swap-
## Semantik wie reorder_pool. Die Reihenfolge IST die Rechenreihenfolge; die
## KÖRPER fahren um (scene_root, an den gemeldeten Ankern).
func move_slot(from_index: int, to_index: int) -> void:
	if editing_locked or burning():
		return
	if from_index < 0 or from_index >= _series.size():
		return
	if to_index < 0 or to_index == from_index:
		return
	var uid := _series[from_index]
	_series.remove_at(from_index)
	_series.insert(mini(to_index, _series.size()), uid)
	refresh()

## Drücken merkt sich den Schacht, Loslassen über einem ANDEREN legt die Karte dort
## ein. Losgelassen über demselben bleibt es ein Klick - dafür feuert der Knopf
## ohnehin sein pressed, und die beiden Gesten können nie beide zünden.
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

## Der Schacht unter der globalen Position (-1 = keiner) - das Loslassen landet auf
## dem Schacht unter dem Zeiger, nicht auf dem, auf dem gedrückt wurde.
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

## Die Anzeigedaten EINER Kassette - EINE Quelle für Schacht, Schirm und Zeremonie.
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

## Der EINE Handlungs-Sitz im Band, MITTIG unter der Schacht-Reihe. Sein Rechteck
## ist in JEDEM Zustand dasselbe - der Sitz ist ein fester Platz, die Aufschrift
## wechselt.
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
	var middle := row_field_rect().get_center().x
	seat.anchor_top = 0.5
	seat.anchor_bottom = 0.5
	seat.offset_left = middle - span.x * 0.5
	seat.offset_right = middle + span.x * 0.5
	seat.offset_top = -span.y * 0.5
	seat.offset_bottom = span.y * 0.5

## Die AUFSCHRIFT des Griffs: gesteckte Karten und Serienlänge - der Zähler wohnt
## seit dem Tod des Serien-Schirms hier.
func grip_label() -> String:
	return "Griff %d/%d" % [_series.size(), slot_count()]

## Der Knopf auf dem Sitz. Zwei Zustände: der GRIFF und, solange die Serie sich
## entlädt, das Überspringen.
func _seat_button(u: float) -> Button:
	if burning():
		_action_button = _seat_fit(_action_button_new("Fertig", GOLD, u,
			skip_ceremony), u)
		return _action_button
	_action_button = _seat_fit(_action_button_new(grip_label(), GOLD, u, pull_lever), u)
	_action_button.disabled = not can_pull()
	_action_button.visible = not _series.is_empty()
	return _action_button

## Darf jetzt gegriffen werden? Drei Bremsen: die eine Pressung der Sitzung, ein
## gewählter Zielwürfel und mindestens eine Karte, die überhaupt prägt.
func can_pull() -> bool:
	if run == null or editing_locked or burning():
		return false
	if target_die() == null or stamping_card_count() <= 0:
		return false
	if needs_second() and second_die() == null:
		return false
	return run.press_allowed()

## Zwingt einen Knopf auf das Sitzmaß: clip_text nimmt der Aufschrift das Recht,
## das Rechteck zu verbreitern.
func _seat_fit(button: Button, u: float) -> Button:
	button.clip_text = true
	button.custom_minimum_size = action_size(u)
	return button

## Maße des Sitzes: EIN Rechteck für beide Aufschriften.
func action_size(u: float) -> Vector2:
	return Vector2(u * ACTION_WIDTH, u * ACTION_HEIGHT)

## Das KONSOLEN-BAND unter der Fensterkante: es trägt nur noch den Handlungs-Sitz,
## mittig unter der Schacht-Reihe. Ohne Hintergrund - es ist ein Platz, kein Möbel.
func _build_series_band(u: float) -> void:
	var band := Control.new()
	band.name = "SeriesBand"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)  # direktes Kind: das Band liegt auf der Fensterkante
	_band = band
	var rect := console_band_rect()
	band.position = rect.position
	band.size = rect.size
	_build_action_seat(band, u)

## Der Platz des TOOLTIP-SCHIRMS in Fenster-Koordinaten: die MITTE des Bandes,
## GENAU auf den Kanten der Schacht-Reihe darüber.
func info_screen_rect(u: float) -> Rect2:
	var console := console_rect(u)
	var band := band_row_rect()
	return Rect2(Vector2(console.position.x, band.position.y),
		Vector2(console.size.x, band.size.y))

## Der TOOLTIP-SCHIRM: eine kleine Fassung mit drei Zeilen - Name, Seele (im
## Essenz-Glühen) und Wirkung (umbrechend). Gefüllt wird er von scene_root (set_info),
## hier steht nur die leere Fassung.
func _build_info_screen(u: float) -> void:
	var rect := info_screen_rect(u)
	var screen := Panel.new()
	screen.name = "InfoScreen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override("panel", TableScreen.window_style())
	screen.position = rect.position
	screen.size = rect.size
	_content.add_child(screen)
	var pad := u * INFO_MARGIN
	var inner := maxf(rect.size.x - pad * 2.0, 1.0)
	var name_h := u * INFO_NAME_UNITS
	var soul_h := u * INFO_SOUL_UNITS
	var top := pad
	_info_name = _info_line(screen, "InfoName", Vector2(pad, top), Vector2(inner, name_h),
		name_h * INFO_NAME_FONT, CasinoStyle.CREAM, false)
	top += name_h + u * INFO_GAP
	_info_soul = _info_line(screen, "InfoSoul", Vector2(pad, top), Vector2(inner, soul_h),
		soul_h * INFO_SOUL_FONT, CasinoStyle.CREAM, false)
	top += soul_h + u * INFO_GAP
	var body_h := maxf(rect.size.y - top - pad, u * 3.0)
	_info_body_span = Vector2(inner, body_h)
	_info_unit = u
	_info_body = _info_line(screen, "InfoBody", Vector2(pad, top), _info_body_span,
		u * float(INFO_BODY_STEPS[0]), MUTED_COLOR, true)
	_info_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_info_soul_tint = Color.WHITE
	_fit_info_body()

## Eine Zeile des Info-Schirms - Grad, Umbruch und clip_text VOR dem Maß, sonst
## klemmt die Mindestgröße die Zeile hoch.
func _info_line(host: Control, line_name: String, at: Vector2, span: Vector2,
		font_size: float, tint: Color, wrap: bool) -> Label:
	var label := Label.new()
	label.name = line_name
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.add_theme_color_override("font_color", tint)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(label)
	label.position = at
	label.size = span
	return label

## Der EINE Schreiber des Info-Schirms (scene_root, je Bild): Name, Seele im
## Essenz-Ton, Wirkung. Nur der WECHSEL schreibt (Text ODER Seelen-Ton).
func set_info(die_name: String, soul: String, soul_tint: Color, body: String) -> void:
	if _info_body == null or not is_instance_valid(_info_body):
		return
	if _info_name.text == die_name and _info_soul.text == soul \
			and _info_body.text == body and _info_soul_tint == soul_tint:
		return
	_info_soul_tint = soul_tint
	_info_name.text = die_name
	_info_soul.text = soul
	_info_soul.add_theme_color_override("font_color", soul_tint)
	_info_body.text = body
	_fit_info_body()

## Der Grad des Wirkungstextes: die größte Stufe, die umgebrochen noch in den
## Restblock paßt (die Leiter des Ladens, hier im Fenster). Gerufen beim Aufbau
## und bei jedem Textwechsel - der Block steht fest, der Text nicht.
func _fit_info_body() -> void:
	var font := ThemeDB.fallback_font
	if font == null or _info_body == null or not is_instance_valid(_info_body) \
			or _info_body_span.x <= 0.0:
		return
	var lead := _info_body.get_theme_constant("line_spacing")
	var px := maxi(8, int(_info_unit * float(INFO_BODY_STEPS[INFO_BODY_STEPS.size() - 1])))
	for step: float in INFO_BODY_STEPS:
		var wanted := maxi(8, int(_info_unit * step))
		if text_block_height(font, _info_body.text, _info_body_span.x, wanted, lead) \
				<= _info_body_span.y:
			px = wanted
			break
	_info_body.add_theme_font_size_override("font_size", px)

## DER GRIFF: EINE atomare Buchung in GameRun, dann die Zeremonie. Gemeldet wird
## press_started VOR dem Buchen (die Dekompression der Zellen braucht sie noch in
## ihren Schächten); series_applied kommt am ENDE der Zeremonie - gebucht ist da
## längst, es ist nur noch das Licht.
func pull_lever() -> void:
	if not can_pull():
		return
	var cards := _slot_cards()
	var before := target_die().instantiate()
	var terms := GameRun.catalyst_terms(slotted_packs())
	var anchor := hand_anchor_px()
	press_started.emit()
	# Immer OHNE zweiten Würfel: die Doppelmatrize ist diese Welle deaktiviert.
	var result := run.apply_series(_series.duplicate(), target_die(), null)
	if result.is_empty():
		refresh()  # der Griff war verbraucht: die Karten bleiben in ihren Schächten
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
	_refresh_preview_net(STENCIL_BIRTH_TIME)
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
	return STENCIL_BIRTH_TIME + STENCIL_TO_RAIL_TIME + beats + STENCIL_LEAVE_TIME \
		+ STENCIL_FOLD_TIME

## Der Takt EINER Karte: die RAMPE macht die späteren schneller, ein Operator
## bekommt seinen Sondermoment obendrauf.
func card_beat(index: int) -> float:
	var count := maxi(_burning.size(), 1)
	var share := 0.0 if count <= 1 else float(index) / float(count - 1)
	var beat := STENCIL_STEP_TIME * lerpf(1.0, STENCIL_STEP_RAMP, share)
	if index >= 0 and index < _burning.size() \
			and String(_burning[index].get("operator", "")) != "":
		beat += STENCIL_OPERATOR_EXTRA
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

## DIE SCHABLONEN-FAHRT: die Schablone löst sich aus dem Ist-Netz links, fährt die
## Schiene über der Reihe ab und hält an jeder Karte - die flammt auf, ihre Zellen
## dunkeln ab und die aufgelaufene Summe tickt auf der Schablone hoch, ein Operator
## schlägt perkussiv zu. Nach der letzten Karte fährt sie zum Zielwürfel und faltet
## sich in ihn; am Ende meldet das Fenster den Griff, und scene_root räumt.
## GEFAHREN wird sie von scene_root - hier steht nur der TAKT.
func _play_series_ceremony(generation: int) -> void:
	var launched := run
	stencil_launched.emit(STENCIL_BIRTH_TIME)
	if not await _scan_wait(STENCIL_BIRTH_TIME, generation, launched):
		return
	var cards := press_display_anchors()
	var rail := _rail_seat_y()
	var entry := Vector2(cards[0].x, rail) if not cards.is_empty() else die_seat()
	entry.x -= mouth_size(unit()).x * 0.8  # der Reihenanfang
	stencil_moved.emit(entry, STENCIL_TO_RAIL_TIME)
	if not await _scan_wait(STENCIL_TO_RAIL_TIME, generation, launched):
		return
	for i in _burning.size():
		var beat := card_beat(i)
		var travel := beat * STENCIL_MOVE_SHARE
		var seat := Vector2(cards[i].x, rail) if i < cards.size() else entry
		stencil_moved.emit(seat, travel)
		if not await _scan_wait(travel, generation, launched):
			return
		_read_card(i, beat - travel)
		if not await _scan_wait(beat - travel, generation, launched):
			return
	# DAS EINSETZEN: hinüber zum ERGEBNIS-Podest, dann die Faltung in den Würfel.
	# Der Würfel wechselt PARALLEL dazu die Seite - er soll dort stehen, wenn die
	# Schablone ihn erreicht.
	die_handover.emit(handover_time())
	stencil_landed.emit(STENCIL_LEAVE_TIME)
	if not await _scan_wait(STENCIL_LEAVE_TIME, generation, launched):
		return
	stencil_folded.emit(STENCIL_FOLD_TIME)
	if not await _scan_wait(STENCIL_FOLD_TIME, generation, launched):
		return
	_end_ceremony()

## Ein Takt der Fahrt. false = die Zeremonie gehört nicht mehr uns (übersprungen,
## Laufwechsel, Fenster fort) - der Aufrufer steigt dann sofort aus, und der EINE
## Aufräum-Pfad hat längst alles gerichtet.
func _scan_wait(time: float, generation: int, launched: GameRun) -> bool:
	if generation != _burn_gen or run != launched or not is_inside_tree():
		return false
	await get_tree().create_timer(maxf(time, 0.0)).timeout
	return generation == _burn_gen and run == launched and is_inside_tree() and burning()

## Die Schablone steht über Karte i: der Schacht flammt auf, das Summen-Netz
## übernimmt ihre Zellen (tickend) - und gemeldet wird, WELCHE Zellen die Karte
## hergibt und wie der Stand danach aussieht.
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
	var after := preview()
	_refresh_preview_net(maxf(tick, 0.01))
	stencil_read.emit(index, _moved_faces(before, after, card.get("net", [])),
		after.get("bonus", []), operator, maxf(tick, 0.01))

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

## Die Höhe der Schiene: die Mitte des Konsolen-Blechs - genau die Zeile, auf der
## die Karten-Flächen liegen, also fährt die Schablone über sie hinweg.
func _rail_seat_y() -> float:
	if _console != null and is_instance_valid(_console) \
			and _console.get_global_rect().size.y > 0.0:
		return _console.get_global_rect().get_center().y
	return row_field_rect().get_center().y + get_global_rect().position.y

## Der LANDEPLATZ der Schablone: das ERGEBNIS-Podest rechts - dorthin wechselt der
## Würfel während der letzten Etappe, und dort faltet sie sich in ihn.
func die_seat() -> Vector2:
	var middle := result_net_center()
	if middle.x < 0.0:
		return get_global_rect().get_center()
	return Vector2(middle.x, result_projector_y())

## Wieviel Zeit die ÜBERGABE hat: die letzte Etappe plus die Faltung. Länger darf
## sie nicht dauern - sonst faltet sich die Schablone in ein leeres Podest.
func handover_time() -> float:
	return STENCIL_LEAVE_TIME + STENCIL_FOLD_TIME

## Klick auf den Sitz: die Fahrt springt ans Ende. Der Stand ist längst gebucht -
## übersprungen wird nur Licht.
func skip_ceremony() -> void:
	if not burning():
		return
	_burn_step = _burning.size()
	_end_ceremony()

## Der EINE Aufräum-Pfad der Zeremonie: die Ziffern stehen auf ihrem Ziel, der
## Ist-Schirm zeigt den GEBUCHTEN Würfel, der Soll-Schirm sein ERGEBNIS (grüne
## Deltas, die stehen bleiben), die Reihe ist leer, das Netz steht auf seinem
## Parkplatz - und ERST DANN wird der Griff gemeldet (scene_root tötet daraufhin die
## Schablone, senkt die verbrauchten Karten ab und beendet eine noch laufende
## Übergabe hart). Egal, wo die Fahrt abbrach.
func _end_ceremony() -> void:
	if not burning():
		return
	var result := _burn_result
	var anchor := _burn_anchor
	# Das ERGEBNIS bleibt stehen: Stand VOR dem Griff und die ganze Projektion - noch
	# aus der laufenden Zeremonie geholt, sie ist die Quelle. Das Netz zeigt daraus
	# die grünen Deltas.
	_result_die = _burn_die
	_result_projection = _full_projection()
	_burn_gen += 1
	_burning = []
	_burn_step = -1
	_burn_die = null
	_burn_terms = {}
	_burn_result = {}
	if _net != null and is_instance_valid(_net):
		_net.settle_ticks()
	refresh()
	_sync_sum_net_park()
	series_applied.emit(result, anchor)

## Eine Serie gehört dem laufenden Spiel: beim Laufwechsel verfällt sie samt jeder
## Zeremonie, die noch liefe.
func _drop_series() -> void:
	_burn_gen += 1
	_drop_result()  # das Ergebnis gehörte dem alten Lauf
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
	if _net != null and is_instance_valid(_net):
		_net.reset_ticks()  # der Stand des alten Laufs tickt nirgends hin

## Nur das Netz neu, ohne die ganze Seite: die Fahrt tickt je Karte, und ein
## voller Neuaufbau nähme den Schächten ihr laufendes Glühen.
## tick > 0 = die Ziffern LAUFEN zu ihrem neuen Wert, statt zu springen.
func _refresh_preview_net(tick: float = 0.0) -> void:
	if _net == null or not is_instance_valid(_net):
		return
	_net.def = preview_target()
	_net.projection = preview()
	_net.highlight = _highlight_faces()
	_net.tick_time = tick
	_net.build()
	_sync_empty_net()

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

## Der Streifen des Magazins: AUSSERHALB des Fensters, über die volle Fensterbreite.
## Ganze Pixel, damit die Platz-Rechnung nicht driftet.
func shelf_strip_size() -> Vector2:
	var u := unit()
	return Vector2(floorf(maxf(size.x, u * 20.0)),
		maxf(apron_bottom_y() - shelf_top(), shelf_min_height()))

## Die MINDESTTIEFE des Magazins: seit die Kassette dort FLACH LIEGT (2026-09-04),
## ist es ihr eigener Fußabdruck plus Rangluft und die gemalte Fassung. Reicht die
## Pool-Höhe dafür nicht, wächst der Streifen nach UNTEN in den freien Filz - die
## Karte schrumpft nie, die Fassung paßt sich an (dieselbe Regel wie bei der
## Schacht-Reihe, die nach rechts wächst).
func shelf_min_height() -> float:
	var card := shelf_cell_px().y * PackDrawerView.CASSETTE_SCALE * PackDrawerView.RANK_SPAN
	return maxf(card + PackDrawerView.rim_inset(shelf_unit()) * 2.0,
		unit() * SHELF_MIN_HEIGHT)

## Oberkante des Magazins: eine Naht unter dem Konsolen-Band. Der Abstand zur
## Konsole ist gesetzt, die HÖHE folgt daraus.
func shelf_top() -> float:
	return console_band_rect().end.y + unit() * CONSOLE_SHELF_GAP

## Der Platz des Magazins: unter dem Konsolen-Band, über die volle Fensterbreite -
## Unterkante = Pool-Unterkante (apron_bottom).
func shelf_rect() -> Rect2:
	var strip := shelf_strip_size()
	return Rect2(Vector2(size.x - strip.x, shelf_top()), strip)

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
	return unit()

## Das Zellmaß, an dem sich das Magazin misst (ohne gemeldetes das Rückfallmaß).
func shelf_cell_px() -> Vector2:
	if data_cell_px.x > 0.0 and data_cell_px.y > 0.0:
		return data_cell_px
	return PackDrawerView.fallback_cell(unit())

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

## Je Paket {uid, pack, withheld} in Magazin-Ordnung (= run.owned_packs). Was in
## einem Serien-Schacht steckt, fehlt ganz; was noch als Licht fliegt, hält seinen
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

## Eine Kassette wurde angetippt: sie wandert in den nächsten freien Serien-Schacht.
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

## Das HOVER-HIGHLIGHT je Bild: die überfahrene KARTE (Schacht) hebt ihre
## Beitrags-Zellen im Summen-Netz hervor (die Kopplung Karte <-> Netz-Zellen bleibt,
## die Diff-Zeilen sind fort). GEFRAGT statt gemeldet - der Zeiger liegt auf dem
## Tisch, kein mouse_entered erreicht das Fenster.
func sync_hover_at(pixel: Vector2) -> void:
	_set_hover_slot(slot_at(pixel))

## Nur der WECHSEL baut das Netz neu - sync_hover_at läuft je Bild.
func _set_hover_slot(index: int) -> void:
	var wanted := index if index < _slot_cards().size() else -1
	if wanted == _hover_slot:
		return
	_hover_slot = wanted
	_refresh_preview_net()

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
	var u := unit()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.6))
	return box
