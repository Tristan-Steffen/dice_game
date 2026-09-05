class_name WorkshopView
extends Panel
## Der STATIONS-STREIFEN UNTER dem Pool. Er hat KEINEN Schirm-Hintergrund - seine
## Teile liegen auf dem Filz - und ist seit der WELLE X (2026-09-05) EINE BREITE,
## FLACHE ZEILE. Von links nach rechts:
##   PODEST (der Zielwürfel) | ZIEL-NETZ | SUMMEN-NETZ samt CAPTION |
##   ETAGEN-LEISTE | TURM | GRIFF-Knopf,   darunter das MAGAZIN über die volle Breite.
##  - DER TURM ist ein Körper (TowerView): sechs ETAGEN übereinander, Etage 1 UNTEN.
##    Das Fenster MALT ihn nicht - es meldet nur sein Rechteck und hält die
##    ETAGEN-LEISTE, sechs Felder, die Klick, Zug und Zeiger tragen (der Turm selbst
##    trägt keinen Klick). Die Körper gehören scene_root, das Podest ebenso.
##  - Das EINE NETZ ist der PressNetView: ohne Serie zeigt er den Zielwürfel
##    schlicht, mit gesteckten Karten die Live-Vorschau und nach dem Griff das
##    Ergebnis mit den grünen Deltas; ohne Ziel steht dort das leere Kreuz. Eine
##    Netz-ZELLE ist so groß wie die FLÄCHE eines echten Würfels (scene_root meldet
##    sie als die_face_px), und der Summen-Schirm teilt dieses Maß.
##
## Unter der Fensterkante liegt die SCHÜRZE: eine Naht, dann das MAGAZIN. Seine
## Tiefe ist EIN Rang der stehenden Kassette - ein Weltmaß.
##
## Die ETAGEN-LEISTE IST die Rechnung: getippt geht eine Kassette auf die nächste
## freie Etage, gezogen sortiert sie um (Reihenfolge = Höhe: was höher liegt, wirkt
## später), geklickt kommt sie zurück ins Magazin.
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
## DAS DURCHLICHT, im Takt gemeldet - GEFAHREN wird das von scene_root, das Fenster
## nennt nur Plätze in Display-Pixeln und Zeiten (ui/ faßt nie Körper an).
## Alle Karten fahren nach rechts und RASTEN EIN (Ripple von unten nach oben).
signal cards_latched(time: float)
## Der Zielwürfel fliegt vom Podest ÜBER den Turm - derselbe Körper, ein Trage-Bogen.
signal die_raised(time: float)
## Das Licht hat Etage index durchlaufen: welche Zellen sie hergibt, der Stand
## danach, ihr Operator; time ist der Takt bis zur nächsten Etage.
signal light_passed(index: int, faces: Array, values: Array, operator: String,
	time: float)
## Oben angekommen zerfällt das Licht-Netz in seine LICHTFUNKEN - sie lösen sich
## GLEICHZEITIG und schlagen in die Seiten des Würfels ein.
signal light_struck(time: float)
## Und der Würfel fliegt denselben Bogen zurück aufs Podest.
signal die_returned(time: float)

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")
## Operator-Karten stehen amber ab - die eine Farbtrennung der Serie (Wert-Karten
## behalten ihre Sortenfarbe). Die Quelle ist das Netz, nicht dieses Fenster.
const OPERATOR_TINT := PressNetView.OPERATOR_TINT

## Die Bühne des schwebenden Zielwürfels ist ein WELTMASS: ihre Spanne ist die
## Würfelfläche mal diesem Faktor (Würfel plus seine Stasis-Station, die durch die
## Parallaxe ein Stück unter ihm auf der Fläche steht). Der u-Rückfall gilt nur
## kopflos.
const STAGE_FACES := 2.4
const STAGE_HEIGHT := 9.3
## Zellgröße des Summen-Netzes: die Kachel, in der ein Würfel gezeigt wird, wenn
## man ÜBER ihn entscheidet.
const CHOICE_CELL := DieNetView.TRAY_TILE
## Die MASSEINHEIT u folgt seit der WELLE X der WÜRFELFLÄCHE: im Streifen ist fast
## alles ein Weltmaß (Netze, Karten, Turm), also mißt auch die u-Kette daran statt
## an einem Höhen-Budget. So viele u ist eine Würfelfläche breit.
const U_PER_FACE := 11.0

## --- DIE SPALTEN: Summen-Netz, Leiste, Turm, Ziel-Netz, Podest, Griff -------------
## MINDEST-Breite einer Netz-Spalte in u; die ECHTE Breite ist das Netz plus seinen
## beiden Rändern - die Zelle ist eine Würfelfläche und damit ein Weltmaß.
const DIFF_WIDTH_UNITS := 18.0
## Die Fuge zwischen zwei Spalten.
const STREET_GAP := 1.8
## MINDEST-Höhe einer Netz-Spalte in u; die ECHTE Höhe ist das Netz plus Rändern.
const DIFF_HEIGHT_UNITS := 24.0
## Der VERSATZ des Podest-Ankers gegen die Zeilenmitte, in DISPLAY-Pixeln: der
## Würfel schwebt CLAMP_HOVER über dem Glas und projiziert an der geneigten Station
## darum nach oben. Der Anker rückt um genau diesen Betrag tiefer, damit der Körper
## MITTIG auf der Zeilenhöhe LIEST. GEMESSEN an der Werkstatt-Weitsicht (18,76 px);
## die Nahsicht steht steiler (8,75 px) und weicht bewußt ab.
const BENCH_TILT_TRIM := 18.8

## Ränder und Zeilenabstand des Fensterinhalts (Einheiten u).
const CONTENT_MARGIN_X := 2.4
const CONTENT_MARGIN_Y := 1.4
const CONTENT_GAP := 1.0

## --- Der EINE NETZ-SCHIRM unter dem Podest ---------------------------------------
## Er trägt NUR sein Netz (der physische Würfel steht über ihm auf dem Podest), auf
## BLANKEM Filz - ohne eigenen Hintergrund und ohne Aufschlüsselungs-Zeilen.
const DIFF_PAD := 0.9
## Anteil des Schirms, den ein Netz höchstens nimmt - nur noch der kopflose
## Rückfall, solange keine Würfelfläche gemeldet ist.
const DIFF_NET_SHARE := 0.92

## --- DER TURM und die ETAGEN-LEISTE ----------------------------------------------
## Seitenverhältnis der KASSETTE selbst (Höhe / Breite, 2 : 3) - daraus folgt der
## LIEGENDE Fußabdruck aus dem gemeldeten stehenden.
const CARD_ASPECT := 1.5
## Luft um die liegende Karte im Turm - der Fußabdruck ist sie plus diesem Anteil,
## und darin steckt noch die KONTAKTLEISTE (TowerView.BAR_SHARE, EINE Quelle).
const TOWER_ROOM := 1.10
## Die ETAGEN-LEISTE links neben dem Turm: Breite eines Feldes und die Fuge dazwischen.
const STRIP_WIDTH := 11.0
const STRIP_GAP := 0.5
## Der Saum eines Etagen-Feldes: stumpf, solange es leer ist, sonst die Sortenfarbe.
const SOCKET_RIM := Color("#3b356acc")
const SOCKET_LIVE_RIM := Color("#8be9fdcc")
## Das leere Feld und der Grad seiner Nummer (Anteil der Feldhöhe).
const FIELD_EMPTY := Color("#141227cc")
const FIELD_NUMBER_SHARE := 0.52
## Luft rings um die TURM-BUCHT (in u): das Loch deckt Turm UND Auswurf-Bahn, damit
## keine Karte je über die Tischkante steigt.
const PIT_ROOM := 2.0

## Die NAHT der Schürze: Fensterkante zu Magazin.
const CONSOLE_SHELF_GAP := 2.1

## --- Der SUMMEN-SCHIRM (WELLE O, seit der WELLE Z die ERSTE Spalte) --------------
## Er steht ganz links in der Zeile, vor der ETAGEN-LEISTE. Er trägt die
## REINE Summe aller gesteckten Prägenetze, zielunabhängig - und beim Hover statt
## dessen das Prägenetz DER überfahrenen Karte (Stufe vor Magazin). Ohne beides
## steht dort dasselbe leere Kreuz wie unten. Darunter läuft EINE Zeile (die
## CAPTION), die scene_root schreibt. Ränder/Grade in u.
const INFO_MARGIN := 1.2
## Die CAPTION unter dem Netz: Kartenname beim Karten-Hover, Zell-Klartext beim
## Zell-Hover, sonst leer. EINE Zeile, geklippt.
const CAPTION_UNITS := 3.0
const CAPTION_GAP := 0.4
## Ihr Grad PASST SICH EIN: der Schirm ist so breit wie die Schacht-Reihe, also mal
## schmal (zwei Schächte) und mal sehr breit (acht). Genommen wird die größte Stufe,
## die noch in die Restbreite paßt.
const CAPTION_STEPS := [2.6, 2.2, 1.9, 1.6, 1.4, 1.2, 1.0]
## Absolute Mindesthöhe des Magazin-Streifens (Einheiten u) - der Boden unter dem
## gemessenen Kartenmaß (siehe shelf_min_height).
const SHELF_MIN_HEIGHT := 6.0

## Der EINE Handlungs-Sitz am RECHTEN Ende der Zeile, neben dem Podest: er trägt
## "Griff n/m" (gesteckt / Serienlänge) bzw. "Fertig". EIN Maß für beide - der Sitz
## steht fest, nur seine Aufschrift wechselt, und die Grundseite fließt nie um.
## Bemessen an der breitesten Aufschrift ("Griff 8/8") plus Rand.
const ACTION_WIDTH := 15.0
const ACTION_HEIGHT := 4.0

## DAS DURCHLICHT - die Zeremonie des Griffs (Welle X, 2026-09-05). Alle Karten
## rasten ein, der Zielwürfel fliegt über den Turm, ein Licht steigt aus der Kammer
## durch alle Etagen und nimmt dabei ihre Zellen auf, und oben schlagen seine
## Funken GLEICHZEITIG in den Würfel ein. Klick überspringt jederzeit.
## Das geparkte Summen-Netz ENTLEERT sich sofort auf die nackten Augenzahlen (die
## Vorschau tritt ab, die Rechnung beginnt bei 0) - parallel zum Einrasten.
const DRAIN_TIME := 0.3
## Das EINRASTEN: je Karte diese Zeit, von unten nach oben gestaffelt.
const LATCH_TIME := 0.22
const LATCH_STAGGER := 0.04
## Der Trage-Bogen des Zielwürfels aufs Dach des Turms und zurück.
const RAISE_TIME := 0.45
const RETURN_TIME := 0.45
## Der Takt EINER Etage IST die Steigzeit des Lichts, mit RAMPE: die letzte steigt
## in diesem Anteil der ersten. Ein Operator bekommt seinen Sondermoment obendrauf.
const LIGHT_STEP := 0.3
const LIGHT_RAMP := 0.6
const LIGHT_OPERATOR_EXTRA := 0.25
## Der EINSCHLAG: die Funken fliegen, dann halten Blitz und Puls kurz.
const STRIKE_TIME := 0.35
const STRIKE_HOLD := 0.25

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
			run.press_changed.connect(refresh)  # eine Buchung räumt die Reihe
		refresh()

var _content: Control
## Das EINE Summen-Netz des Fensters. Es überlebt jeden Neuaufbau (es ist kein Kind
## des Inhalts): sein ZÄHL-Takt darf nicht daran zerbrechen, daß eine Kassette
## umsortiert wird - nur so tickt es beim Griff von der Vorschau herunter.
var _net: PressNetView
## Sein PARKPLATZ im Netz-Schirm: ein leerer Platz in Netzgröße, auf den es je
## Bild zurückgesetzt wird. Der Platz ist die gemeldete Netzmitte.
var _net_host: Control
## Der PLATZHALTER daneben: das leere Kreuz, das steht, solange kein Ziel gewählt
## ist - das Netz ist NIE versteckt.
var _empty_net: Control
## Das leere PODEST am Fuß der Treppe, auf das der Vorrats-Würfel fährt.
var _target_stage_host: Control
## Der NETZ-SCHIRM daneben (der Kasten, in dem Netz und Kreuz sitzen).
var _ist_screen: Panel
## Die ETAGEN-FELDER: je Etage ein Knopf, der Klick, Zug und Zeiger fängt - der
## TURM daneben ist ein Körper (TowerView) und trägt nichts davon.
var _slot_buttons: Array[Button] = []
var _portals: Array[PressPortalView] = []
## Das Magazin der Bank (null = gerade nicht gebaut).
var _drawer: PackDrawerView
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
## Die Maßeinheit u des Fensters (0 = die u-Konvention, Fensterbreite/100). Der
## STREIFEN kann breiter sein, als seine 100 u ausmachen: die Treppe hält die FESTE
## Kartengröße, das Fenster folgt ihr. Dann gibt scene_root die Einheit aus der
## HÖHE vor (dasselbe apron_bottom-Muster), sonst zerrisse die Treppe die
## senkrechte Rechnung (unit_for).
var unit_px := 0.0:
	set(value):
		if is_equal_approx(unit_px, value):
			return
		unit_px = value
		refresh()
## Die FLÄCHE eines echten Würfels in Display-Pixeln (0 = noch nicht gemeldet, dann
## trägt der kopflose Fit). Sie IST das Zellmaß der Netze: eine Zelle zeigt eine
## Würfelseite in ihrer wahren Größe. scene_root mißt sie an derselben Projektion
## wie die Kartenmaße.
var die_face_px := 0.0:
	set(value):
		if is_equal_approx(die_face_px, value):
			return
		die_face_px = value
		refresh()
## Wie weit der Würfel ÜBER dem Turm sich im Bild nach RECHTS über den Turm-Grundriß
## hinauslehnt: so viel Luft bleibt rechts von ihm frei, sonst deckte er das ZIEL-NETZ
## zu. scene_root mißt es an der Projektion.
var tower_lean := 0.0:
	set(value):
		if is_equal_approx(tower_lean, value):
			return
		tower_lean = value
		refresh()
## Dasselbe für den PODEST-Würfel: er steht am rechten Zeilenende und lehnt sich
## darum am weitesten hinaus - ohne diese Luft deckte er den GRIFF-Knopf zu.
var die_lean := 0.0:
	set(value):
		if is_equal_approx(die_lean, value):
			return
		die_lean = value
		refresh()

## DIE SERIE: die uids der gesteckten Karten in STECKREIHENFOLGE - sie SIND die
## Rechnung. uids, nicht Indizes: das Magazin darf darunter umsortiert werden.
var _series: Array[int] = []
## Plätze im Pool: der Zielwürfel und (nur mit Doppelmatrize) der zweite.
var _target_index := -1
var _second_index := -1
## Die Karte unter dem Zeiger (-1 = keine): ihre Beitrags-Zellen leuchten im
## Netz auf, und der Summen-Schirm zeigt IHR Prägenetz.
var _hover_slot := -1
## Die MAGAZIN-Kassette unter dem Zeiger (0 = keine) - dieselbe Frage, andere
## Auslage; der Schacht schlägt sie.
var _hover_pack_uid := 0
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

## DAS ERGEBNIS DER LETZTEN BUCHUNG - es bleibt im Netz STEHEN, bis ein
## anderes Ziel gewählt oder abgewählt wird (siehe showing_result). _result_die ist
## der Stand VOR dem Griff: erst der Vergleich mit der Projektion macht die grünen
## Deltas.
var _result_die: DieDefinition
var _result_projection: Dictionary = {}

## Das Blech der Schacht-Reihe (null = steht gerade nicht).
## Der Knopf des Handlungs-Sitzes.
var _action_button: Button
## Der SUMMEN-SCHIRM (null = steht gerade nicht): sein Netz-Platz, das darin
## hängende Netz und die Caption darunter.
var _sum_host: Control
var _sum_net_view: Control
var _caption: Label
## Die Restbreite der Caption und die Einheit, in der ihre Leiter mißt.
var _caption_span := Vector2.ZERO
var _caption_unit := 0.0
## Was das Summen-Netz gerade zeigt - Signatur (nur der WECHSEL baut neu), Quelle
## ("card"/"sum"/"empty") und ihr Inhalt, damit die Zell-Frage sie beantworten kann.
var _sum_signature := ""
var _sum_mode := ""
var _sum_source_net: Array = []
var _sum_projection: Dictionary = {}
var _sum_cell := 0.0

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
	_portals.clear()
	_target_stage_host = null
	_ist_screen = null
	_net_host = null
	_empty_net = null
	_free_own(_drawer)  # das Magazin hängt am Panel, nicht am Inhalt
	_drawer = null
	_sum_host = null  # der Summen-Schirm hing am Inhalt
	_sum_net_view = null
	_caption = null
	_sum_signature = ""  # ein Neuaufbau baut das Netz frisch
	_prune_series()
	var u := unit()
	_free_own(_content)
	_content = null  # queue_free wirkt erst am Bildende - sonst hängt hier ein Zombie
	_action_button = null

	# Die Schürze steht IMMER: das Magazin gehört zur Bank, nicht zu einem Ablauf -
	# gesperrt wird nur, was gerade niemand anfassen darf.
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

# --- DIE ZEILE (Welle Z): Summen-Netz | Leiste + Bahn + Turm | Ziel-Netz | Podest |
# --- Griff. Die GRUBE liegt links, der WÜRFEL rechts. -----------------------------

## Der Innenraum des Fensters in Fenster-Koordinaten - alles liegt darin.
func street_rect() -> Rect2:
	var u := unit()
	return Rect2(Vector2(u * CONTENT_MARGIN_X, u * CONTENT_MARGIN_Y),
		Vector2(maxf(size.x - u * CONTENT_MARGIN_X * 2.0, 1.0),
			maxf(size.y - u * CONTENT_MARGIN_Y * 2.0, 1.0)))

## Die ZEILE selbst - der Streifen ist EINE Zeile, also IST sie die Straße.
func row_rect() -> Rect2:
	return street_rect()

## Was eine Netz-Spalte über ihr Netz hinaus braucht, in u.
static func band_units() -> float:
	return DIFF_PAD * 2.0

## Die Spanne der PODEST-Bühne: ein WELTMASS (die Würfelfläche mal STAGE_FACES),
## kopflos der alte u-Rückfall.
func stage_px() -> float:
	if die_face_px > 0.0:
		return die_face_px * STAGE_FACES
	return unit() * STAGE_HEIGHT

## Das PODEST: rechts des ZIEL-NETZES, mittig - der Anker rückt um BENCH_TILT_TRIM
## tiefer, weil der schwebende Körper an der geneigten Station nach oben projiziert.
func target_podium_rect() -> Rect2:
	var span := stage_px()
	var row := row_rect()
	return Rect2(Vector2(ist_screen_rect().end.x + unit() * STREET_GAP,
		row.get_center().y + BENCH_TILT_TRIM - span * 0.5), Vector2(span, span))

## Die Breite einer NETZ-Spalte: das Netz plus seinen beiden Rändern; die u-Zahl ist
## nur der Boden. Gemessen wird am GRÖSSEREN der beiden Ränder - sonst kappte der
## Summen-Schirm (INFO_MARGIN) sein Netz auf eine andere Zelle als das Ziel-Netz.
func net_column_width(u: float) -> float:
	return maxf(net_span(u).x + u * maxf(DIFF_PAD, INFO_MARGIN) * 2.0,
		u * DIFF_WIDTH_UNITS)

## Der NETZ-SCHIRM des Ziels: rechts des TURMS - hinter der Luft, die die LEHNE des
## Würfels über ihm braucht -, mittig in der Zeile.
func ist_screen_rect() -> Rect2:
	var u := unit()
	var row := row_rect()
	var height := net_span(u).y + u * band_units()
	return Rect2(Vector2(tower_rect().end.x + u * STREET_GAP + tower_lean,
		row.get_center().y - height * 0.5), Vector2(net_column_width(u), height))

## Der TURM: rechts der ETAGEN-LEISTE, mittig in der Zeile. Sein Fußabdruck ist die
## liegende Karte plus Luft, und darin steckt die KONTAKTLEISTE (TowerView.BAR_SHARE).
func tower_span_px() -> Vector2:
	var lie := lie_span_px() * TOWER_ROOM
	return Vector2(lie.x / maxf(1.0 - TowerView.BAR_SHARE, 0.1), lie.y)

func tower_rect() -> Rect2:
	var u := unit()
	var row := row_rect()
	var span := tower_span_px()
	var left := strip_rect().end.x + u * STREET_GAP + eject_lane_px()
	return Rect2(Vector2(left, row.get_center().y - span.y * 0.5), span)

## Die AUSWURF-BAHN links des Turms: blanker Filz, in den die überfahrene Karte
## herausfährt - so liest ihr Netz frei, ohne Leiste oder Netz zu verdecken. Ihr
## Maß ist der volle Zug der untersten Karte (TowerView, die EINE Quelle).
func eject_lane_px() -> float:
	return lie_span_px().x * TowerView.eject_share(step_count())

## Die ETAGEN-LEISTE: die Klick-Spalte des Turms. Sie nimmt die GANZE Zeilenhöhe -
## sechs Felder auf dem Turm-Fußabdruck lesen als Splitter.
func strip_rect() -> Rect2:
	var u := unit()
	var row := row_rect()
	return Rect2(Vector2(sum_screen_rect(u).end.x + u * STREET_GAP, row.position.y),
		Vector2(u * STRIP_WIDTH, row.size.y))

## Der Platz EINER Etage in der Leiste - Etage 0 UNTEN, denn das Licht steigt.
func floor_field_rect(index: int) -> Rect2:
	var u := unit()
	var strip := strip_rect()
	var count := maxi(step_count(), 1)
	var gap := u * STRIP_GAP
	var height := maxf((strip.size.y - gap * float(count - 1)) / float(count), 1.0)
	return Rect2(Vector2(strip.position.x,
		strip.position.y + float(count - 1 - index) * (height + gap)),
		Vector2(strip.size.x, height))

## Der GRIFF-SITZ: das rechte Ende der Zeile, hinter der Luft, die die LEHNE des
## Podest-Würfels braucht.
func grip_seat_rect() -> Rect2:
	var u := unit()
	var span := action_size(u)
	return Rect2(Vector2(target_podium_rect().end.x + u * STREET_GAP + die_lean,
		row_rect().get_center().y - span.y * 0.5), span)

func _build_street(u: float) -> void:
	_target_stage_host = _podium_host("TargetStage", target_podium_rect())
	_build_ist_screen(u)
	_build_info_screen(u)  # der Summen-Schirm neben dem Ziel-Netz
	_build_floor_strip(u)
	_build_action_seat(u)

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

## Der EINE NETZ-SCHIRM, auf blankem Filz und ohne eigenen Hintergrund: er trägt
## den PARKPLATZ des Netzes (die Live-Vorschau bzw. das Ergebnis) und daneben das
## leere Kreuz, solange kein Ziel gewählt ist. Der physische Würfel steht RECHTS
## daneben auf dem Podest.
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
	# Der PARKPLATZ des Netzes: ein leerer Platz in Netzgröße. Das Netz fährt, dieser
	# Platz nie.
	var host := Control.new()
	host.name = "TargetNet"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.position = Vector2((rect.size.x - span.x) * 0.5, u * DIFF_PAD)
	host.size = span
	screen.add_child(host)
	_net_host = host
	# Es steht IMMER: ohne Ziel und ohne Karten malt PressNetView nichts, dann steht
	# das leere Kreuz an seiner Stelle. Es hängt NEBEN dem Parkplatz, nicht darin -
	# der bleibt ein leerer Platz.
	_empty_net = _empty_net_cross(cell)
	_empty_net.position = host.position
	screen.add_child(_empty_net)
	_sync_empty_net()

## Das LEERE Kreuz: sechs dunkle Zellen an den Netz-Plätzen, sonst nichts - der
## Platzhalter des EINEN Netzes.
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

## Das EINE Zellmaß der Netze: die FLÄCHE eines echten Würfels, sobald scene_root
## sie gemeldet hat - eine Netz-Zelle zeigt eine Würfelseite in ihrer wahren Größe
## (WELLE S). Ohne Meldung (kopfloser Aufbau, Tests) bleibt der alte Fit, und der
## mißt an den KONSTANTEN der Spalte, nicht an ihrem Rechteck: sonst hinge die
## Zelle an einer Höhe, die selbst aus ihr folgt.
func net_cell(u: float) -> float:
	if die_face_px > 0.0:
		return die_face_px
	return DieNetView.cell_for(Vector2(
		maxf(u * (DIFF_WIDTH_UNITS - DIFF_PAD * 2.0), 1.0),
		maxf(u * DIFF_HEIGHT_UNITS * DIFF_NET_SHARE, 1.0)))

## Die Maße des Netzes in dieser Zelle - Spaltenbreite und Bandhöhe folgen ihm.
func net_span(u: float) -> Vector2:
	return DieNetView.net_size(net_cell(u))

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

## STEHT gerade das ERGEBNIS der letzten Buchung im Netz? Es bleibt, bis ein
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

## Display-Pixel der PODEST-Mitte ((-1,-1) = die Spalte steht gerade nicht) -
## dorthin fährt der angetippte Vorrats-Würfel.
func target_net_center() -> Vector2:
	if _target_stage_host == null or not is_instance_valid(_target_stage_host):
		return Vector2(-1, -1)
	return _target_stage_host.get_global_rect().get_center()

func target_projector_y() -> float:
	if _target_stage_host != null and is_instance_valid(_target_stage_host):
		return _target_stage_host.get_global_rect().get_center().y
	return get_global_rect().get_center().y

## Display-Pixel des EINEN NETZES ((-1,-1) = es steht gerade nicht) - der Parkplatz
## des Netzes.
func ist_net_center() -> Vector2:
	if _net_host == null or not is_instance_valid(_net_host):
		return Vector2(-1, -1)
	return _net_host.get_global_rect().get_center()

## Steht die Bank gerade so da, dass ein Würfel darüber schweben darf? Sie steht
## IMMER - die Straße ist Möbel, kein Ablauf. (Die KAMERA fragt hier nicht mit.)
func bench_open() -> bool:
	return true

## Fenster PLUS Schürze in Display-Pixeln: alles, was zur Werkbank gehört - und
## damit die EINE Weiterleitungs-Region. Sie streckt sich nach UNTEN bis zur
## echten Magazin-Unterkante: ragte die Grube darüber hinaus, fiele jeder Chip-Tap
## dort durch (der Welle-H-Bug, zweimal geheilt).
func bench_rect() -> Rect2:
	var rect := get_global_rect()
	rect.size.y = maxf(rect.size.y, maxf(apron_bottom_y(), shelf_rect().end.y))
	return rect

## Die HÖHEN-KETTE der Seite in u - alles, was NICHT an einem Weltmaß hängt: die
## beiden Ränder und die Fassung des Netzes. Netze, Turm, Bühne und Magazin sind
## WELTMASSE und stehen daneben.
static func height_units() -> float:
	return CONTENT_MARGIN_Y * 2.0

## Die MASSEINHEIT u folgt der WÜRFELFLÄCHE (WELLE X): im Streifen ist fast alles
## ein Weltmaß, also darf u nicht mehr aus einem Höhen-Budget fallen - der Streifen
## ist so groß, wie sein Inhalt ist, und die Kamera kommt dafür näher.
static func unit_for(die_face: float) -> float:
	return maxf(die_face / U_PER_FACE, 0.5)

## Die FENSTERHÖHE: die höchste der drei Spalten plus die beiden Ränder. Der SUMMEN-
## Schirm trägt sein Netz plus Caption, der Turm seinen Fußabdruck, die Bühne ihre
## Spanne - jede ist ein Weltmaß, die Ränder sind die u-Kette.
static func bench_height_for(u: float, net_px: float, tower_px: float,
		stage_px_now: float) -> float:
	var nets := net_px + u * (INFO_MARGIN * 2.0 + CAPTION_UNITS + CAPTION_GAP)
	return maxf(maxf(nets, tower_px), stage_px_now) + u * height_units()

## Die Maßeinheit u dieses Fensters: die vorgegebene, sonst die u-Konvention
## (Fensterbreite/100). Alles Gesetzte im Fenster rechnet in ihr.
func unit() -> float:
	if unit_px > 0.0:
		return unit_px
	return maxf(size.x, 200.0) / 100.0

## Die u-KETTE der Schürze: nur noch die NAHT über dem Magazin - das Konsolen-Band
## ist mit der Welle W gestorben, und die Magazin-Tiefe ist ein Weltmaß.
static func apron_span_units() -> float:
	return CONSOLE_SHELF_GAP

## Unterkante der Schürze in Fenster-Koordinaten (siehe apron_bottom).
func apron_bottom_y() -> float:
	if apron_bottom > size.y:
		return apron_bottom
	return shelf_top() + shelf_min_height()

# --- DER TURM und die ETAGEN-LEISTE --------------------------------------------------

## Wie viele Etagen der Turm trägt: die Serienlänge des Laufs, mindestens so viele,
## wie gerade liegen (eine geschrumpfte Leiter wirft keine Karte fort).
func slot_count() -> int:
	var slots := run.series_slots() if run != null else FALLBACK_SLOTS
	return maxi(slots, _slot_cards().size())

## Dasselbe unter dem Namen des Turms.
func step_count() -> int:
	return slot_count()

## Der Fußabdruck der LIEGENDEN Kassette in Fenster-Pixeln, in der EINEN Größe, die
## sie überall hat: Langseite waagerecht, Breite nach unten. Gemeldet wird nur die
## STEHENDE Zelle, die Langseite folgt aus dem Seitenverhältnis der Karte.
func lie_span_px() -> Vector2:
	var deep := shelf_cell_px().y
	return Vector2(deep * CARD_ASPECT, deep) * PackDrawerView.CASSETTE_SCALE

## Die Etagen-Felder in Fenster-Koordinaten, Etage 0 zuerst (unten).
func floor_field_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for i in step_count():
		rects.append(floor_field_rect(i))
	return rects

## Wie BREIT das Fenster sein muß: Ränder, zwei Netz-Spalten, die Leiste, die
## Auswurf-Bahn, der Turm samt LEHNE, die Bühne samt IHRER Lehne, die Griff-Spalte
## und die fünf Fugen.
static func bench_width_for(u: float, net_px: float, tower_px: float,
		stage_px_now: float, lane_px: float = 0.0, lean_px: float = 0.0,
		die_lean_px: float = 0.0) -> float:
	var column := maxf(net_px + u * maxf(DIFF_PAD, INFO_MARGIN) * 2.0,
		u * DIFF_WIDTH_UNITS)
	return u * (CONTENT_MARGIN_X * 2.0 + STRIP_WIDTH + STREET_GAP * 5.0
		+ ACTION_WIDTH) + column * 2.0 + lane_px + tower_px + lean_px + stage_px_now \
		+ die_lean_px

## DIE ETAGEN-LEISTE BAUEN: sechs Felder, unten "1". Sie SIND die Klick-, Zug- und
## Zeiger-Ziele des Turms - er selbst ist ein Körper und trägt keinen Klick.
func _build_floor_strip(u: float) -> void:
	var cards := _slot_cards()
	var slots := step_count()
	_portals.resize(slots)
	for i in slots:
		var card: Dictionary = cards[i] if i < cards.size() else {}
		var seat := _floor_field(i, card, u)
		var rect := floor_field_rect(i)
		seat.position = rect.position
		seat.size = rect.size
		_content.add_child(seat)

## EIN ETAGEN-FELD: leer ein dunkles Feld mit seiner Nummer, belegt die Sortenfarbe
## der Karte. Der Knopf fängt Klick und Zeiger, das GLÜHEN liegt darin.
func _floor_field(index: int, card: Dictionary, u: float) -> Button:
	var slot := Button.new()
	slot.name = "SeriesFloor%d" % (index + 1)
	slot.focus_mode = Control.FOCUS_NONE
	slot.disabled = true
	var tint := _slot_tint(card)
	var rect := floor_field_rect(index)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		slot.add_theme_stylebox_override(state, _field_box(tint, card.is_empty(), u))
	var number := Label.new()
	number.name = "FloorNumber"
	number.text = str(index + 1)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	number.add_theme_font_size_override("font_size",
		maxi(8, int(rect.size.y * FIELD_NUMBER_SHARE)))
	number.add_theme_color_override("font_color",
		MUTED_COLOR if card.is_empty() else TEXT_COLOR)
	slot.add_child(number)
	var portal := PressPortalView.new()
	portal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(portal)
	portal.setup(String(card.get("sort", "")), tint)
	if index < _portals.size():
		_portals[index] = portal
	_arm_slot(slot, index, card)
	_slot_buttons.append(slot)
	return slot

## Die Fassung eines Feldes: leer bleibt es dunkel, belegt trägt es die Sortenfarbe
## in der Intensität seiner Größe (dieselbe Leiter, die die Karte selbst liest).
func _field_box(tint: Color, empty: bool, u: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = FIELD_EMPTY if empty else Color(tint.r, tint.g, tint.b, 0.45)
	box.border_color = SOCKET_RIM if empty else tint
	box.set_border_width_all(maxi(1, int(u * 0.3)))
	box.set_corner_radius_all(maxi(2, int(u * 0.8)))
	return box

## Ein Klick auf die belegte Stufe nimmt ihre Karte zurück ins Magazin, ein ZUG
## legt sie auf eine andere Stufe - dieselbe Trennung wie im Vorrat: gezogen
## sortiert um, getippt handelt.
func _arm_slot(slot: Button, index: int, card: Dictionary) -> void:
	if card.is_empty() or burning():
		return
	slot.disabled = editing_locked
	slot.tooltip_text = "%s
%s" % [String(card.get("name", "")), String(card.get("body", ""))]
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.pressed.connect(clear_press_slot.bind(index))
	slot.gui_input.connect(_on_slot_input.bind(index))

## Die Farbe einer Etage: leer der stumpfe Rand, belegt AMBER für Operatoren und
## sonst die Sortenfarbe - eine Quelle für Feld, Glühen und Saum. Die GRÖSSE sagt
## ihre Intensität, auf derselben Leiter, die die Karte selbst liest.
func _slot_tint(card: Dictionary) -> Color:
	if card.is_empty():
		return SOCKET_RIM
	var base: Color = OPERATOR_TINT if String(card.get("operator", "")) != "" \
		else PackDrawerView.COLORS.get(String(card.get("sort", "")), SOCKET_LIVE_RIM)
	var tier := clampi(int(card.get("tier", 0)), 0,
		DataCellView.TIER_SATURATION.size() - 1)
	var grey := base.get_luminance()
	return Color(grey, grey, grey, base.a).lerp(base,
		float(DataCellView.TIER_SATURATION[tier]))

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

## Display-Pixel des TURM-Platzes, je Etage einer (leere eingeschlossen): alle Karten
## liegen über DEMSELBEN Fußabdruck, nur die HÖHE unterscheidet sie - und die rechnet
## der Körper (TowerView.floor_seat).
func press_slot_anchors() -> Array[Vector2]:
	var anchors: Array[Vector2] = []
	var centre := get_global_rect().position + tower_rect().get_center()
	for i in step_count():
		anchors.append(centre)
	return anchors

## Derselbe Platz - die Karte liegt IM Turm, es ist derselbe Punkt.
func press_display_anchors() -> Array[Vector2]:
	return press_slot_anchors()

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
		"tier": pack.tier, "net": pack.stamp_net, "operator": pack.operator_id,
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

## Der EINE Handlungs-Sitz am rechten Ende der Zeile. Sein Rechteck ist in JEDEM
## Zustand dasselbe - der Sitz ist ein fester Platz, die Aufschrift wechselt.
func _build_action_seat(u: float) -> void:
	var seat := Control.new()
	seat.name = "ActionSeat"
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(seat)
	var rect := grip_seat_rect()
	var button := _seat_button(u)
	if button != null:
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		seat.add_child(button)
		# Erst im Baum messen: die Zeilenhöhe der Schrift ist der wahre Boden des
		# Sitzes - und sie ist für beide Aufschriften dieselbe.
		rect.size.y = maxf(rect.size.y, button.get_combined_minimum_size().y)
		# Danach trägt der SITZ das Maß allein: seine Größe fällt aus zwei
		# Ankerabständen heraus und weicht um ein Bit von action_size ab.
		button.custom_minimum_size = Vector2.ZERO
	seat.position = Vector2(rect.position.x,
		grip_seat_rect().get_center().y - rect.size.y * 0.5)
	seat.size = rect.size

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

## Darf jetzt gegriffen werden? Vier Bremsen: ein gewählter, nicht durchgebrannter
## Zielwürfel, eine VOLLE Reihe (der Block IST sechs Karten) und mindestens eine
## Karte, die prägt.
## Griffe selbst sind unbegrenzt (Spieler-Entscheid 2026-09-05).
func can_pull() -> bool:
	if run == null or editing_locked or burning():
		return false
	if target_die() == null:
		return false
	# Auf einen durchgebrannten Würfel prägt der Griff nicht.
	if target_die().burned_out:
		return false
	if _series.size() < GameRun.SERIES_SLOT_CAP:
		return false
	if stamping_card_count() <= 0:
		return false
	return not (needs_second() and second_die() == null)

## Zwingt einen Knopf auf das Sitzmaß: clip_text nimmt der Aufschrift das Recht,
## das Rechteck zu verbreitern.
func _seat_fit(button: Button, u: float) -> Button:
	button.clip_text = true
	button.custom_minimum_size = action_size(u)
	return button

## Maße des Sitzes: EIN Rechteck für beide Aufschriften.
func action_size(u: float) -> Vector2:
	return Vector2(u * ACTION_WIDTH, u * ACTION_HEIGHT)

## Der Platz des SUMMEN-SCHIRMS: die ERSTE Spalte der Zeile (Welle Z) - das Netz plus
## seiner Fassung und der CAPTION darunter.
func sum_screen_rect(u: float) -> Rect2:
	var row := row_rect()
	var height := net_span(u).y + u * (INFO_MARGIN * 2.0 + CAPTION_UNITS + CAPTION_GAP)
	return Rect2(Vector2(row.position.x, row.get_center().y - height * 0.5),
		Vector2(net_column_width(u), height))

## Das Zellmaß des SUMMEN-NETZES: dasselbe wie links und rechts (die drei Netze
## lesen als EINE Zeile) - nur wenn der Schirm schmaler ist als eine Podest-Spalte,
## wird auf ihn gekappt, statt über seine Kante zu laufen.
func sum_net_cell(u: float) -> float:
	var rect := sum_screen_rect(u)
	var pad := u * INFO_MARGIN
	var room := Vector2(maxf(rect.size.x - pad * 2.0, 1.0),
		maxf(rect.size.y - u * (CAPTION_UNITS + CAPTION_GAP), 1.0))
	return minf(net_cell(u), DieNetView.cell_for(room))

## Der SUMMEN-SCHIRM: eine Fassung mit dem dritten NETZ der Zeile und EINER Zeile
## darunter. Gefüllt wird die Zeile von scene_root (set_caption), das Netz vom
## Fenster selbst (_refresh_sum_net).
func _build_info_screen(u: float) -> void:
	var rect := sum_screen_rect(u)
	var screen := Panel.new()
	screen.name = "SumScreen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override("panel", TableScreen.window_style())
	screen.position = rect.position
	screen.size = rect.size
	_content.add_child(screen)
	var pad := u * INFO_MARGIN
	var inner := maxf(rect.size.x - pad * 2.0, 1.0)
	var caption_h := u * CAPTION_UNITS
	var span := DieNetView.net_size(sum_net_cell(u))
	var host := Control.new()
	host.name = "SumNet"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.position = Vector2((rect.size.x - span.x) * 0.5,
		maxf((rect.size.y - caption_h - u * CAPTION_GAP - span.y) * 0.5, 0.0))
	host.size = span
	screen.add_child(host)
	_sum_host = host
	_caption_span = Vector2(inner, caption_h)
	_caption_unit = u
	# Die Zeile steht DIREKT unter dem Netz, nicht am Schirmboden - sie gehört ihm.
	_caption = _info_line(screen, "Caption",
		Vector2(pad, minf(host.position.y + span.y + u * CAPTION_GAP,
			maxf(rect.size.y - caption_h, 0.0))), _caption_span,
		u * float(CAPTION_STEPS[0]), MUTED_COLOR, false)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sum_signature = ""
	_refresh_sum_net()

## Eine Zeile des Schirms - Grad, Umbruch und clip_text VOR dem Maß, sonst klemmt
## die Mindestgröße die Zeile hoch.
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

## Der EINE Schreiber der CAPTION (scene_root, je Bild). Nur der WECHSEL schreibt.
func set_caption(text: String) -> void:
	if _caption == null or not is_instance_valid(_caption):
		return
	if _caption.text == text:
		return
	_caption.text = text
	_fit_caption()

func caption_text() -> String:
	return _caption.text if _caption != null and is_instance_valid(_caption) else ""

## WARUM der Griff nicht zünden darf ("" = er darf). Die Bremsen stehen sonst
## stumm im Knopf: eine gesperrte Werkstatt, ein fehlendes Ziel, eine halbleere
## Reihe, eine Serie aus lauter Katalysatoren. Gefragt wird sie in der Reihenfolge,
## in der can_pull prüft - genannt wird die ERSTE geschlossene Bremse.
func grip_blocker() -> String:
	if run == null or can_pull() or burning():
		return ""
	# KURZ: die Zeile ist EINE Netz-Spalte breit, ein längerer Satz wird geklippt.
	if editing_locked:
		return "Runde gezurrt - erst im Laden wieder."
	if target_die() == null:
		return "Kein Ziel: einen Vorrats-Würfel antippen."
	if target_die().burned_out:
		return "Würfel durchgebrannt - erst reparieren."
	if _series.size() < GameRun.SERIES_SLOT_CAP:
		# Der Kurzschluß deckelt die Reihe unter sechs - dann geht der Griff nie.
		if run.series_slots() < GameRun.SERIES_SLOT_CAP:
			return "Kurzschluß: keine sechs Karten."
		return "Reihe nicht voll: sechs Karten."
	if stamping_card_count() <= 0:
		return "Nur Katalysatoren - eine Netz-Karte fehlt."
	return ""

## Der Grad der Caption: die größte Stufe, die noch in die Restbreite paßt.
func _fit_caption() -> void:
	var font := ThemeDB.fallback_font
	if font == null or _caption == null or not is_instance_valid(_caption) \
			or _caption_span.x <= 0.0:
		return
	var px := maxi(8, int(_caption_unit * float(CAPTION_STEPS[CAPTION_STEPS.size() - 1])))
	for step: float in CAPTION_STEPS:
		var wanted := maxi(8, int(_caption_unit * step))
		if font.get_string_size(_caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				wanted).x <= _caption_span.x:
			px = wanted
			break
	_caption.add_theme_font_size_override("font_size", px)

# --- Das SUMMEN-NETZ ------------------------------------------------------------

## Was der Schirm zeigt - EIN Entscheider: die überfahrene Karte (Schacht vor
## Magazin) schlägt die SUMME der gesteckten Netze, und ohne beides steht das leere
## Kreuz. Die Summe ist ZIELUNABHÄNGIG (SeriesResolver ohne Würfel).
func _sum_view_source() -> Dictionary:
	var cards := _slot_cards()
	if _hover_slot >= 0 and _hover_slot < cards.size():
		return {"mode": "card", "net": cards[_hover_slot].get("net", [])}
	if _hover_pack_uid > 0 and run != null:
		var pack := run.pack_by_uid(_hover_pack_uid)
		if pack != null:
			return {"mode": "card", "net": pack.stamp_net}
	var nets := _sum_nets()
	if nets.is_empty():
		return {"mode": "empty"}
	return {"mode": "sum",
		"projection": SeriesResolver.resolve(nets, null, _sum_terms())}

## Die Netze, die in die Summe gehen: während der Fahrt die schon erfaßten, sonst
## die gesteckten Nicht-Katalysatoren in Steckreihenfolge.
func _sum_nets() -> Array:
	if burning():
		return _burn_nets_so_far()
	var nets: Array = []
	for pack in slotted_packs():
		if pack.is_catalyst():
			continue
		nets.append(pack.stamp_net)
	return nets

func _sum_terms() -> Dictionary:
	if burning():
		return _burn_terms
	return GameRun.catalyst_terms(slotted_packs())

## Die Signatur der Quelle - nur ihr WECHSEL baut das Netz neu (gefragt je Bild).
func _sum_view_signature() -> String:
	var cards := _slot_cards()
	if _hover_slot >= 0 and _hover_slot < cards.size():
		return "card:%d" % int(cards[_hover_slot].get("uid", 0))
	if _hover_pack_uid > 0:
		return "pack:%d" % _hover_pack_uid
	return "sum:%s:%d:%d" % [str(_series), _burn_step, _burning.size()]

func _refresh_sum_net() -> void:
	if _sum_host == null or not is_instance_valid(_sum_host):
		return
	var signature := _sum_view_signature()
	if signature == _sum_signature and _sum_net_view != null \
			and is_instance_valid(_sum_net_view):
		return
	_sum_signature = signature
	if _sum_net_view != null and is_instance_valid(_sum_net_view):
		_sum_host.remove_child(_sum_net_view)
		_sum_net_view.queue_free()
	var source := _sum_view_source()
	_sum_mode = String(source.get("mode", "empty"))
	_sum_source_net = source.get("net", [])
	_sum_projection = source.get("projection", {})
	_sum_cell = sum_net_cell(unit())
	match _sum_mode:
		"card":
			_sum_net_view = PressNetView.stamp_net(_sum_source_net, _sum_cell)
		"sum":
			_sum_net_view = PressNetView.sum_net(_sum_projection, _sum_cell)
		_:
			_sum_net_view = _empty_net_cross(_sum_cell)
	_sum_host.add_child(_sum_net_view)

## Der Klartext einer Zelle des SUMMEN-Netzes ("" = keine getroffen).
func _sum_hint_at(pixel: Vector2) -> String:
	if _sum_net_view == null or not is_instance_valid(_sum_net_view) \
			or _sum_cell <= 0.0:
		return ""
	var rect := _sum_net_view.get_global_rect()
	if not rect.has_point(pixel):
		return ""
	var face := DieNetView.face_at(pixel - rect.position, _sum_cell)
	if face < 0:
		return ""
	if _sum_mode == "card":
		return StampNet.cell_hint(StampNet.cell_at(_sum_source_net, face))
	if _sum_mode == "sum":
		return PressNetView.projection_hint(_sum_projection, face)
	return ""

## Der NAME der überfahrenen Karte ("" = keine) - Schacht vor Magazin, dieselbe
## Reihenfolge wie beim Netz. scene_root schreibt ihn in die Caption.
func hover_pack_name() -> String:
	var cards := _slot_cards()
	if _hover_slot >= 0 and _hover_slot < cards.size():
		return String(cards[_hover_slot].get("name", ""))
	if _hover_pack_uid > 0 and run != null:
		var pack := run.pack_by_uid(_hover_pack_uid)
		if pack != null:
			return pack.display_name
	return ""

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
	# VOR der Buchung: ihr synchrones pool_changed fragt held_faces() schon, und der
	# Podest-Würfel soll die ALTEN Augen behalten, bis der Scanner sie aufdeckt.
	_burn_die = before
	# Immer OHNE zweiten Würfel: die Doppelmatrize ist diese Welle deaktiviert.
	var result := run.apply_series(_series.duplicate(), target_die(), null)
	if result.is_empty():
		_burn_die = null
		refresh()  # nichts gebucht: die Karten bleiben in ihren Schächten
		return
	_series.clear()
	_burning = cards
	_burn_terms = terms
	_burn_result = result
	_burn_anchor = anchor
	_burn_step = 0
	_burn_gen += 1
	refresh()
	# Das geparkte Netz ENTLEERT sich: die Vorschau tritt ab, die Rechnung beginnt
	# bei 0 - die Ziffern ticken auf die nackten Augenzahlen hinunter.
	_refresh_preview_net(DRAIN_TIME)
	_play_series_ceremony(_burn_gen)  # nicht erwartet: die Fahrt läuft für sich

## Läuft die Serie gerade durch?
func burning() -> bool:
	return _burn_step >= 0

## Der Stand des Zielwürfels VOR dem Griff (null = keine Zeremonie). scene_root malt
## ihn auf den Podest-Würfel zurück, solange der Scanner ihn noch nicht aufgedeckt
## hat - sonst zeigte die Buchung die neuen Augen sofort.
func held_faces() -> DieDefinition:
	return _burn_die

## Die Kartendaten der laufenden Zeremonie - der Block liest daraus Sorte und Größe.
func burning_cards() -> Array[Dictionary]:
	return _burning.duplicate()

## Die Projektion des laufenden Griffs (leer = keine) - der Scanner liest daraus,
## welche Seite einen Bonus bekommen hat und darum grün aufblitzt.
func burn_projection() -> Dictionary:
	return _burn_result.get("projection", {}) if not _burn_result.is_empty() else {}

## Wie lange das EINRASTEN dauert: eine Karte plus die Staffel über die Etagen.
func latch_time() -> float:
	return LATCH_TIME + LATCH_STAGGER * float(maxi(_burning.size(), 1) - 1)

## Wie lange das DURCHLICHT dauert - scene_root staffelt daran nichts, aber ein Test
## darf es abwarten.
func ceremony_time() -> float:
	var beats := 0.0
	for i in _burning.size():
		beats += card_beat(i)
	return latch_time() + RAISE_TIME + beats + STRIKE_TIME + STRIKE_HOLD + RETURN_TIME

## Der Takt EINER Etage - er IST die Steigzeit des Lichts zur nächsten: die RAMPE
## macht die späteren schneller, ein Operator bekommt seinen Sondermoment obendrauf.
func card_beat(index: int) -> float:
	var count := maxi(_burning.size(), 1)
	var share := 0.0 if count <= 1 else float(index) / float(count - 1)
	var beat := LIGHT_STEP * lerpf(1.0, LIGHT_RAMP, share)
	var card: Dictionary = _burning[index] if index >= 0 and index < _burning.size() else {}
	if String(card.get("operator", "")) != "":
		beat += LIGHT_OPERATOR_EXTRA
	return beat

## Die Netze der Karten, die die Lawine SCHON aufgenommen hat - daran tickt das
## Summen-Netz kartenweise hoch.
func _burn_nets_so_far() -> Array:
	var nets: Array = []
	for i in mini(maxi(_burn_step, 0), _burning.size()):
		if String(_burning[i].get("catalyst", "")) != "":
			continue  # ein Katalysator prägt nicht, er legt Terme bei
		nets.append(_burning[i].get("net", []))
	return nets

## DAS DURCHLICHT: alle Karten rasten ein, der Zielwürfel fliegt über den Turm, das
## Licht steigt Etage um Etage (jede flammt auf, ihre Zellen dunkeln ab, die Summe
## tickt hoch, ein Operator schlägt perkussiv zu), oben schlagen die Funken ein, und
## der Würfel fliegt zurück. Am Ende meldet das Fenster den Griff, und scene_root
## räumt. GEFAHREN wird das von scene_root - hier steht der TAKT.
func _play_series_ceremony(generation: int) -> void:
	var launched := run
	var latch := latch_time()
	cards_latched.emit(latch)
	if not await _scan_wait(latch, generation, launched):
		return
	die_raised.emit(RAISE_TIME)
	if not await _scan_wait(RAISE_TIME, generation, launched):
		return
	for i in _burning.size():
		var beat := card_beat(i)
		_read_card(i, beat, beat)
		if not await _scan_wait(beat, generation, launched):
			return
	light_struck.emit(STRIKE_TIME)
	if not await _scan_wait(STRIKE_TIME + STRIKE_HOLD, generation, launched):
		return
	die_returned.emit(RETURN_TIME)
	if not await _scan_wait(RETURN_TIME, generation, launched):
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

## Das Licht hat Karte i erreicht: ihr Etagen-Feld flammt auf, das Summen-Netz
## übernimmt ihre Zellen (tickend) - und gemeldet wird, WELCHE Zellen sie hergibt,
## wie der Stand danach aussieht und wie lange das Licht zur nächsten Etage braucht.
func _read_card(index: int, tick: float, time: float) -> void:
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
	_refresh_sum_net()  # die Summe in der Mitte tickt mit der Fahrt
	var faces := _moved_faces(before, after, card.get("net", []))
	var values: Array = after.get("bonus", [])
	light_passed.emit(index, faces, values, operator, time)

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

## Klick auf den Sitz: die Fahrt springt ans Ende. Der Stand ist längst gebucht -
## übersprungen wird nur Licht.
func skip_ceremony() -> void:
	if not burning():
		return
	_burn_step = _burning.size()
	_end_ceremony()

## Der EINE Aufräum-Pfad der Zeremonie: die Ziffern stehen auf ihrem Ziel, der
## Netz-Schirm zeigt sein ERGEBNIS (grüne
## Deltas, die stehen bleiben), die Reihe ist leer, das Netz steht auf seinem
## Parkplatz - und ERST DANN wird der Griff gemeldet (scene_root tötet daraufhin den
## Block und gibt jede noch fliegende Karte frei). Egal, wo die Zeremonie abbrach.
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
		_net.modulate = Color.WHITE  # ein abgebrochener Geburts-Dim schuldet nichts
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
	_hover_pack_uid = 0
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

## Display-Pixel des TURMS - dort liegt die Serie, und von dort geht das Licht
## des Griffs aus.
func hand_anchor_px() -> Vector2:
	var tower := tower_rect()
	if tower.size.x > 0.0:
		return get_global_rect().position + tower.get_center()
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

## Die MINDESTTIEFE des Magazins: EIN Rang der STEHENDEN Kassette - ihr
## Griff-Fußabdruck plus Rangluft und die gemalte Fassung. Sie ist ein WELTMASS und
## steht als eigener Posten in der u-Rechnung des Streifens (unit_for).
func shelf_min_height() -> float:
	var card := shelf_cell_px().y * PackDrawerView.CASSETTE_SCALE * PackDrawerView.RANK_SPAN
	return maxf(card + PackDrawerView.rim_inset(shelf_unit()) * 2.0,
		unit() * SHELF_MIN_HEIGHT)

## Oberkante des Magazins: eine NAHT unter der Fensterkante (das Konsolen-Band ist
## mit der Welle W gestorben). Die HÖHE folgt daraus.
func shelf_top() -> float:
	return size.y + unit() * CONSOLE_SHELF_GAP

## Der Platz des Magazins: unter der Fensterkante, über die volle Fensterbreite.
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

## Die TURM-BUCHT in Display-Pixeln: das zweite Loch der GEMEINSAMEN Grube. Es deckt
## den Turm samt seiner AUSWURF-BAHN und reicht nach unten BÜNDIG an die Magazin-
## Grube - beide berühren sich, in der Welt ist es EIN Raum. Die ETAGEN-LEISTE bleibt
## links davon auf dem Glas: im Loch wird kein Display gezeichnet.
func tower_pit_rect() -> Rect2:
	var room := unit() * PIT_ROOM
	var tower := tower_rect()
	# Links endet sie an der ETAGEN-LEISTE: die bleibt auf dem Glas, im Loch wird
	# kein Display gezeichnet.
	var left := maxf(tower.position.x - eject_lane_px() - room, strip_rect().end.x)
	# Oben endet sie an der Fensterkante - über ihr liegt die Naht zur Pool-Reihe.
	var top := maxf(row_rect().position.y - room, 0.0)
	var rect := Rect2(Vector2(left, top), Vector2(tower.end.x + room - left, 1.0))
	rect.position += get_global_rect().position
	rect.size.y = maxf(shelf_pit_rect().position.y - rect.position.y, 1.0)
	return rect

## Ihr Eckenradius - derselbe, den die Magazin-Grube trägt.
func tower_pit_radius() -> float:
	return shelf_pit_radius()

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

## Das HOVER-HIGHLIGHT je Bild: die überfahrene KARTE (Schacht ODER Magazin) hebt
## ihre Beitrags-Zellen im Netz hervor und zeigt ihr eigenes Prägenetz im
## Summen-Schirm. GEFRAGT statt gemeldet - der Zeiger liegt auf dem Tisch, kein
## mouse_entered erreicht das Fenster.
func sync_hover_at(pixel: Vector2) -> void:
	_hover_pack_uid = shelf_hover_uid_at(pixel)
	_set_hover_slot(slot_at(pixel))
	_refresh_sum_net()  # nur der WECHSEL der Quelle baut neu

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
	var summed := _sum_hint_at(pixel)  # der Summen-Schirm liegt vor dem Netz
	if summed != "":
		return summed
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
