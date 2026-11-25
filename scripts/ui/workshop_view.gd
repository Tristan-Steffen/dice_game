class_name WorkshopView
extends Panel
## Die WERKSTATT unter dem Pool (Layout E, docs/plan_werkstatt_layout_e.md). Sie hat
## KEINEN Schirm-Hintergrund - ihre Teile liegen auf dem Filz. Rechts am Pool die VORSCHAU
## (die Die-View des überfahrenen Würfels), daneben PRÄGEN, darunter der INFO-SCHIRM. Unter
## dem Pool die liegende WALZE (Scheibe 1 links), an ihrem Ende UPGRADES, darüber das
## "+"-Feld (der UMSCHALTER) und das PODEST (Platte über der Kammer, darunter seine
## Die-View ORIGINAL/ERGEBNIS); darunter das MAGAZIN. Die Kette rechnet drum_layout.
##  - DIE WALZE ist ein Körper (DrumView); das Fenster MALT sie nicht, seine
##    unsichtbaren Scheiben-Knöpfe tragen Klick, Zug und Zeiger.
##  - Die Netze der Gleichung sind gleich groß und teilen die Zelle der Die-View
##    (podium_cell).
##
## Die Scheiben SIND die Rechnung: getippt geht eine Kassette auf die nächste freie
## Scheibe, gezogen sortiert sie um (Scheibe 1 wirkt zuerst), geklickt kommt sie
## zurück ins Magazin.
##
## Zustands-Mutation läuft ausschließlich über GameRun (resolve_series als
## Vorschau, apply_series als Prägen); die Vorschau ist buchstäblich dieselbe
## Rechnung wie die Buchung.

## Ein Würfel wurde gewählt, gewechselt oder abgewählt (null = keiner) - scene_root
## fliegt ihn aus dem Pool aufs PODEST bzw. zurück.
signal die_chosen(die: DieDefinition)
## Das ZIEL der Serie hat gewechselt (null = keins) - reine Logik, der Würfel bleibt stehen.
signal target_changed(die: DieDefinition)
## Das PRÄGEN ist durch: gebucht hat GameRun schon beim Auslösen, hier ist die
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
## Das Prägen beginnt: die Reihe gehört ab jetzt der Zeremonie. Gemeldet wird VOR
## dem Buchen, solange die Sockel noch stehen.
signal press_started
## DIE ÜBERTRAGUNG, im Takt gemeldet - GEFAHREN wird sie von scene_root, das Fenster
## nennt nur Plätze in Display-Pixeln und Zeiten (ui/ faßt nie Körper an).
## Der VOR-TAKT: der Boden unter dem Podest senkt sich, der Würfel sinkt in die Kammer.
signal chamber_opening(time: float)
## Der NACH-TAKT: der Würfel steigt, der Boden schließt.
signal chamber_closing(time: float)
## Die belegten Scheiben VERRIEGELN von links nach rechts; keine Karte bewegt sich.
signal slices_locked(time: float)
## Der Strom hat Scheibe index durchlaufen: welche Zellen sie hergibt, der Stand
## danach, die Glyphe, mit der sie zuschlägt ("" = still); time ist der Takt bis
## zur nächsten Scheibe (nach der letzten: bis ans Ende der Walze).
signal stream_passed(index: int, faces: Array, values: Array, glyph: String,
	time: float)
## Am Ende der Walze geht der Strom in die Kabel der Kammer und schlägt in den Würfel
## (beim Verdichten als Funke in den Rohling auf dem Podest).
signal stream_struck(time: float)
## Ein ZUG rollt die Magazin-Spalte column: so weit (Display-px, schon in den Grenzen)
## steht sie gerade gegen ihren Roll-Stand versetzt.
signal shelf_scrolling(column: int, offset_px: float)
## Losgelassen: der Roll-Stand ist schon gebucht, der Körper fährt von from_px auf
## to_px (beides gegen den ALTEN Stand) und rastet dort ein.
signal shelf_scroll_snapped(column: int, from_px: float, to_px: float)
## Der UMSCHALTER der Die-View hat gewechselt (true = ERGEBNIS).
signal result_toggled(on: bool)

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")
## Operator-Karten stehen amber ab - die eine Farbtrennung der Serie (Wert-Karten
## behalten ihre Sortenfarbe). Die Quelle ist das Netz, nicht dieses Fenster.
const OPERATOR_TINT := PressNetView.OPERATOR_TINT
## Wem eine Netz-Zelle gehört, wenn kein Name dahintersteht (Info-Schirm-Titel).
const SUM_OWNER := "Summe der Serie"
const ORIGINAL_OWNER := "Original"
const RESULT_OWNER := "Ergebnis"
const PREVIEW_OWNER := "Vorschau"

## Die Bühne des schwebenden Zielwürfels ist ein WELTMASS: ihre Spanne ist die
## Würfelfläche mal diesem Faktor (Würfel plus seine Stasis-Station, die durch die
## Parallaxe ein Stück unter ihm auf der Fläche steht). Der u-Rückfall gilt nur
## kopflos.
const STAGE_FACES := 2.4
const STAGE_HEIGHT := 9.3
## Die MASSEINHEIT u folgt seit der WELLE X der WÜRFELFLÄCHE: im Streifen ist fast
## alles ein Weltmaß (Netze, Karten, Walze), also mißt auch die u-Kette daran statt
## an einem Höhen-Budget. So viele u ist eine Würfelfläche breit.
const U_PER_FACE := 11.0

## Die Fuge zwischen zwei Teilen der Kette.
const STREET_GAP := 1.8
## So weit (Display-px) liest der schwebende Würfel ÜBER seinem Anker (der Grubenmitte),
## gemessen an der Werkstatt-Weitsicht (Layout C, 2026-11-20: 12,3 | -54,3 px) - daran
## mißt der obere Rand der Platte.
const PODIUM_TILT_TRIM := 54.3
## Die halbe Reichweite des schwebenden Würfels in Würfelflächen (er liest größer als
## seine Fläche auf dem Glas).
const PODIUM_HEAD_FACES := 1.0
## Die KAMMER unter dem Podest: ein Quadrat von so vielen Würfelflächen.
const CHAMBER_FACES := 3.3

## Seitenverhältnis der KASSETTE selbst (Höhe / Breite, 2 : 3) - daraus folgt der
## LIEGENDE Fußabdruck aus dem gemeldeten stehenden.
const CARD_ASPECT := PackDrawerView.CARD_ASPECT
## Die NUMMERN der Scheiben über dem Graben: Höhe, Fuge und Grad in u.
const SLICE_NUMBER_UNITS := 4.0
const SLICE_NUMBER_GAP := 0.6
const SLICE_NUMBER_FONT := 4.0
## Gesperrte Scheiben: Nummer und unbezahlbarer Preis gedämpft, bezahlbar in Energie-Farbe.
const LOCKED_COLOR := Color(0.45, 0.47, 0.58)
const ENERGY_COLOR := CasinoStyle.ENERGY
## Die Leiterbahnen: Abdunklung, dunkler Grund.
const TRACE_DARKEN := 0.1
const TRACE_CLEAR := Color(0.02, 0.07, 0.05)
const TRACE_BED := Color(0.03, 0.03, 0.06, 0.9)
## Die zwei BUSSE (Graben -> UPGRADES, UPGRADES -> Podest) tragen EINE Spur je Sorte
## (Pack.SHELF_ORDER) - farblos, solange ihre Sorte nicht steckt.
const TRACE_LANES := 4
const TRACE_IDLE := Color(0.34, 0.36, 0.46)
## Spurabstand und Breite der Busse (u).
const FEED_PITCH := 2.0
const FEED_WIDTH := 0.55
## Der SPEICHER (UPGRADES): Gehäuse, Zellen-Grund, Anschluß-Stifte (u).
const STORAGE_CAN := Color(0.03, 0.035, 0.05)
const STORAGE_PAD := Color(0.78, 0.6, 0.24)
const STORAGE_BUS := Color(0.3, 0.8, 0.9)
## Rest-Rand der Platine rechts neben dem Netz (px) - links läuft der Eingang.
const STORAGE_EDGE := 7.5

## Der EINE Handlungs-Sitz am RECHTEN Ende der Zeile, neben dem Podest: er trägt
## "Prägen n/m" (gesteckt / Serienlänge) bzw. "Fertig". EIN Maß für beide - der Sitz
## steht fest, nur seine Aufschrift wechselt, und die Grundseite fließt nie um.
## Bemessen an der breitesten Aufschrift ("Verdichten 6/6") plus Rand.
const ACTION_WIDTH := 21.0
const ACTION_HEIGHT := 4.0
const ACTION_SPAN_SHARE := 0.5
const ACTION_FONT_SHARE := 0.5
const ACTION_TEXT_PAD := 1.0
const ACTION_WIDEST := "Verdichten 6/6"
## Der Sitz nach der Prägung der Runde: eine rote Anzeige statt des Knopfs.
const SPENT_TEXT := "GEPRÄGT"
const SPENT_COLOR := Color(1.25, 0.42, 0.38)

## DIE ÜBERTRAGUNG - die Zeremonie des Prägens. Der Boden unter dem Podest öffnet die
## Kammer, die Scheiben verriegeln, ein Strom läuft von Scheibe 1 bis ans Ende der Walze
## und geht in die Kabel der Kammer; danach steigt der Würfel, der Boden schließt.
## Klick überspringt jederzeit.
## VOR- und NACH-TAKT: die Fahrt des Bodens (beim Verdichten bleibt er zu).
const CHAMBER_OPEN_TIME := 0.3
const CHAMBER_CLOSE_TIME := 0.3
## Das geparkte ERGEBNIS-Netz ENTLEERT sich sofort auf die nackten Augenzahlen (die
## Vorschau tritt ab, die Rechnung beginnt bei 0) - parallel zum Verriegeln.
const DRAIN_TIME := 0.3
## Das VERRIEGELN: je Scheibe diese Zeit, von links nach rechts gestaffelt.
const LOCK_TIME := 0.22
const LOCK_STAGGER := 0.04
## Der Takt EINER Scheibe IST die Laufzeit des Stroms, mit RAMPE: die letzte läuft
## in diesem Anteil der ersten. Ein Operator bekommt seinen Sondermoment obendrauf.
const STREAM_STEP := 0.3
const STREAM_RAMP := 0.6
const STREAM_OPERATOR_EXTRA := 0.25
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
			run.energy_changed.disconnect(_on_energy_changed)
		_pending_arrivals.clear()  # Lieferungen des alten Laufs verfallen
		_queued_pops.clear()
		_drop_series()  # eine Serie des alten Laufs schuldet nichts mehr
		_shelf_scroll.fill(0)  # ein neuer Lauf beginnt auf dem ersten Platz
		hover_die = null
		result_shown = true
		run = value
		if run != null:
			run.packs_changed.connect(refresh)
			run.pool_changed.connect(refresh)  # die Gleichung zeigt den Pool
			run.press_changed.connect(refresh)  # eine Buchung räumt die Reihe
			run.energy_changed.connect(_on_energy_changed)
		refresh()

var _content: Control
## Das ERGEBNIS-Netz mit Ziel. Es überlebt jeden Neuaufbau (es ist kein Kind des
## Inhalts): sein ZÄHL-Takt darf nicht daran zerbrechen, daß eine Kassette
## umsortiert wird - nur so tickt es beim Prägen von der Vorschau herunter.
var _net: PressNetView
## Sein PARKPLATZ in der Die-View des Podests: ein leerer Platz in Netzgröße, auf den es
## je Bild zurückgesetzt wird.
var _net_host: Control
## Der Platz auf dem PODEST, seine Die-View und das Netz darin (schlicht oder die Karte,
## die das Verdichten ergäbe).
var _podium_stage_host: Control
var _podium_view_host: Control
var _podium_net: PressNetView
var _card_view: Control
var _card_net: Array = []
## Die VORSCHAU rechts am Pool: ihr Netz-Platz, das Netz darin (null = leeres Kreuz) und
## was sie zeigt - nur der Wechsel baut neu.
var _preview_host: Control
var _preview_net: PressNetView
var _preview_key := ""
## Was die Die-View gerade zeigt (die_view_mode) - nur der Wechsel baut neu.
var _die_view_key := ""
## Haben die Funken schon eingeschlagen? Ab da zeigt ORIGINAL den gebuchten Stand.
var _burn_struck := false
## DER UMSCHALTER: true = die Die-View zeigt das ERGEBNIS, false = das ORIGINAL. Überlebt
## Neuaufbau und Wahl; der Laufwechsel setzt ihn zurück.
var result_shown := true:
	set(value):
		if result_shown == value:
			return
		result_shown = value
		_view_source_changed()
		_fill_preview()
		result_toggled.emit(value)
## Der VORRATS-Würfel unter dem Zeiger (bzw. angeheftet oder als Neuzugang wartend), null =
## keiner - scene_root meldet ihn je Bild. Die VORSCHAU zeigt IHN.
var hover_die: DieDefinition = null:
	set(value):
		if hover_die == value:
			return
		hover_die = value
		_fill_preview()
## Die SCHEIBEN-Knöpfe: je Scheibe einer, der Klick, Zug und Zeiger fängt - die
## WALZE darunter ist ein Körper (DrumView) und trägt nichts davon.
var _slot_buttons: Array[Button] = []
## Die nächste GESPERRTE Scheibe: ihr Kauf-Knopf und ihre Preis-Nummer.
var _unlock_button: Button
var _unlock_label: Label
## Das Magazin der Bank (null = gerade nicht gebaut).
var _drawer: PackDrawerView
## Die WALZEN-KETTE in Display-Pixeln (drum_layout), gemeldet von scene_root - das
## Fenster steht auf ihrer Ecke (leer = noch nichts gemeldet).
var drum_frame: Dictionary = {}:
	set(value):
		if drum_frame == value:
			return
		drum_frame = value
		refresh()
## Nur BLÄTTERN (Karten-Öffnung, gemeldet von scene_root): Rollen und Griff leben,
## Stecken, Rohling-Legen und Aufräumen schweigen.
var browse_only := false
## Der ROLL-STAND je Magazin-Spalte (eine je Sorte) in ganzen Plätzen - ANZEIGE, kein
## Spielstand: darum wohnt er hier und nicht in GameRun.
var _shelf_scroll: Array[int] = [0, 0, 0, 0]
## Spalte und letzter gemeldeter Versatz des laufenden Zugs.
var _drag_column := 0
var _last_drag_px := 0.0
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
## Die Maßeinheit u des Fensters (0 = die u-Konvention, Fensterbreite/100);
## scene_root gibt sie aus der Würfelfläche vor (unit_for).
var unit_px := 0.0:
	set(value):
		if is_equal_approx(unit_px, value):
			return
		unit_px = value
		refresh()
## Die FLÄCHE eines echten Würfels in Display-Pixeln (0 = noch nicht gemeldet): an
## ihr mißt die Podest-Bühne. Die Netz-Zelle hängt seit der Welle 29 an der KARTE.
var die_face_px := 0.0:
	set(value):
		if is_equal_approx(die_face_px, value):
			return
		die_face_px = value
		refresh()

## DIE SERIE: die uids der gesteckten Karten in STECKREIHENFOLGE - sie SIND die
## Rechnung. uids, nicht Indizes: das Magazin darf darunter umsortiert werden.
var _series: Array[int] = []
## Die SCHEIBE jeder Karte der Serie, parallel und aufsteigend: eine entnommene Karte läßt
## ihre Scheibe leer, niemand rückt nach.
var _series_slots: Array[int] = []
## Platz des GEWÄHLTEN Würfels im Pool (er steht auf dem Podest) - Ziel der Serie ist er
## erst, sobald eine Karte steckt (target_die).
var _chosen_index := -1
## Der ROHLING auf dem Podest (0 = keiner) - das Ziel des VERDICHTENS. Er und der
## Würfel schließen einander als Ziel aus: liegt er dort, wartet der Würfel im Pool.
var _target_pack := 0
## Das zuletzt gemeldete Ziel - nur der WECHSEL meldet target_changed.
var _announced_target: DieDefinition
## Die Karte unter dem Zeiger (-1 = keine): ihre Beitrags-Zellen leuchten im
## ERGEBNIS-Netz auf.
var _hover_slot := -1
## Die MAGAZIN-Kassette unter dem Zeiger (0 = keine) - dieselbe Frage, andere
## Auslage; der Schacht schlägt sie.
var _hover_pack_uid := 0
## Der Slot, auf dem ein Zug begonnen hat (-1 = keiner).
var _drag_from := -1

## DIE LAUFENDE ZEREMONIE. _burning trägt die Kartendaten des Prägens (die Karten
## selbst sind da längst verbraucht), _burn_step, wie viele davon die Welle schon
## erfaßt hat, und _burn_die den Zielwürfel, wie er VOR dem Prägen aussah - nur so
## kann das ERGEBNIS-Netz von 0 hochticken.
var _burning: Array[Dictionary] = []
var _burn_step := -1
var _burn_gen := 0
var _burn_die: DieDefinition
## Der Rohling, in den die laufende Zeremonie verdichtet (0 = sie prägt).
var _burn_blank := 0
var _burn_terms: Dictionary = {}
var _burn_result: Dictionary = {}
var _burn_anchor := Vector2.ZERO

## DAS ERGEBNIS DER LETZTEN BUCHUNG - es bleibt im Netz STEHEN, bis ein
## anderes Ziel gewählt oder abgewählt wird (siehe showing_result). _result_die ist
## der Stand VOR dem Prägen: erst der Vergleich mit der Projektion macht die grünen
## Deltas.
var _result_die: DieDefinition
var _result_projection: Dictionary = {}

## Der Knopf des Handlungs-Sitzes.
var _action_button: Button
## UPGRADES (null = steht gerade nicht): sein Netz-Platz und das darin hängende Netz -
## die SUMME DER SERIE, ohne Karte das leere Kreuz.
var _sum_host: Control
var _sum_net_view: Control
## Was es gerade zeigt - Signatur (nur der WECHSEL baut neu), Quelle und Inhalt, damit
## die Zell-Frage es beantworten kann.
var _sum_signature := ""
var _sum_mode := ""
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
	set_process(true)  # das ERGEBNIS-Netz hält seinen Platz
	refresh()

## Das ERGEBNIS-Netz PARKT auf seinem Platz - es folgt damit jedem Neuaufbau des
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
	var target := target_die()
	if target != _announced_target:
		_announced_target = target
		target_changed.emit(target)
	die_stages_changed.emit()

func _refresh_content() -> void:
	if not is_inside_tree():
		return
	_slot_buttons.clear()
	_unlock_button = null
	_unlock_label = null
	_podium_stage_host = null
	_podium_view_host = null  # die Die-View des Podests hing am Inhalt
	_podium_net = null
	_card_view = null
	_die_view_key = ""
	_net_host = null
	_preview_host = null  # die Vorschau hing am Inhalt
	_preview_net = null
	_preview_key = ""
	# Ein Neuaufbau mitten im Zug läßt ihn einrasten, statt ihn hängen zu lassen.
	if shelf_dragging():
		_on_scroll_released.call_deferred(_drag_column, _last_drag_px)
	_free_own(_drawer)  # das Magazin hängt am Panel, nicht am Inhalt
	_drawer = null
	_sum_host = null  # UPGRADES hing am Inhalt
	_sum_net_view = null
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
	# Fenster-Koordinaten, genau so, wie drum() sie meldet.
	_content = Control.new()
	_content.name = "Street"
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_build_street(u)
	_ensure_sum_net(u)  # zuletzt: das Netz liegt über allem

## Das ERGEBNIS-Netz wird nie neu gebaut, nur neu ausgelegt - sonst risse jeder
## Neuaufbau des Fensters seinen laufenden Zähl-Takt ab.
func _ensure_sum_net(u: float) -> void:
	if _net == null or not is_instance_valid(_net):
		_net = PressNetView.new()
		add_child(_net)
	_net.cell = net_cell(u)
	move_child(_net, get_child_count() - 1)
	_view_source_changed()
	_sync_sum_net_park()

## Sein Platz: die Mitte des Parkplatzes in der Die-View.
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

# --- DIE WERKSTATT UNTER DEM POOL (Layout A, docs/plan_werkstatt_walze.md): Zeile 1 die
# --- liegende WALZE samt Prägen, Zeile 2 das MAGAZIN und rechts davon der
# --- INFO-SCHIRM über der GLEICHUNG. ------------------------------------------------

## Die Kette in FENSTER-Koordinaten: die gemeldete Display-Kette (drum_frame) gegen
## ihre eigene Ecke versetzt - das Fenster steht auf genau dieser Ecke. Ohne Meldung
## (kopflos, Tests) rechnet es die Kette selbst ab dem Ursprung.
func drum() -> Dictionary:
	var frame := drum_frame
	if frame.is_empty():
		var face := die_face_px if die_face_px > 0.0 else unit() * U_PER_FACE
		frame = drum_layout(Rect2(), lie_span_px(), face, unit())
	var origin: Vector2 = (frame["bounds"] as Rect2).position
	var local := {}
	for key: String in frame:
		var value: Variant = frame[key]
		if value is Rect2:
			local[key] = Rect2((value as Rect2).position - origin, (value as Rect2).size)
		elif value is Array:
			var rects: Array[Rect2] = []
			for rect: Rect2 in value:
				rects.append(Rect2(rect.position - origin, rect.size))
			local[key] = rects
	return local

## Ein Fenster-Rechteck in Display-Pixeln.
func _global(rect: Rect2) -> Rect2:
	return Rect2(get_global_rect().position + rect.position, rect.size)

## Die SCHEIBE index in Fenster-Koordinaten - Scheibe 1 (index 0) LINKS. Sie trägt Klick,
## Zug und Zeiger; der Körper darunter (DrumView) trägt nichts davon.
func slice_rect(index: int) -> Rect2:
	var slices: Array = drum()["slices"]
	return slices[clampi(index, 0, slices.size() - 1)]

## Der GRABEN der Walze in Display-Pixeln: ein Dauer-Loch.
func drum_pit_rect() -> Rect2:
	return _global(drum()["pit"])

## Sein Eckenradius: der eines gemalten Rahmens, um dessen Breite verkleinert.
func drum_pit_radius() -> float:
	var unit := shelf_unit()
	return maxf(unit * PackDrawerView.RADIUS - PackDrawerView.rim_inset(unit), 0.0)

## Die Kante des Scheiben-Vierkants in Display-Pixeln (an der KURZEN Kartenseite).
func drum_side() -> float:
	return drum_side_px(lie_span_px())

## Die Teilung der Scheiben längs der Achse in Display-Pixeln.
func drum_pitch() -> float:
	var slices: Array = drum()["slices"]
	if slices.size() < 2:
		return lie_span_px().x
	return (slices[1] as Rect2).position.x - (slices[0] as Rect2).position.x

## ORIGINAL in der Gleichung: die Die-View des Podests.
func original_net_rect() -> Rect2:
	return drum()["podium_net"]

## UPGRADES: die Summe der Serie, am rechten Ende der Walze unter dem Podest.
func upgrades_net_rect() -> Rect2:
	return drum()["upgrades"]

## Die VORSCHAU rechts am Pool (Fenster-Koordinaten).
func preview_net_rect() -> Rect2:
	return drum()["preview"]

## Die Vorschau in Display-Pixeln.
func preview_rect_px() -> Rect2:
	return _global(preview_net_rect())

## Der INFO-SCHIRM unter Vorschau und Prägen, in Display-Pixeln.
func info_rect_px() -> Rect2:
	return _global(drum()["info"])

## Die Spanne der PODEST-Bühne: ein WELTMASS (die Würfelfläche mal STAGE_FACES),
## kopflos der alte u-Rückfall.
func stage_px() -> float:
	if die_face_px > 0.0:
		return die_face_px * STAGE_FACES
	return unit() * STAGE_HEIGHT

## Der ANKER des PODESTS: die Mitte der KAMMER unter der Platte - dort steht der Puck.
func podium_stage_rect() -> Rect2:
	var stage := Vector2.ONE * stage_px()
	var at := chamber_rect().get_center()
	return Rect2(at - stage * 0.5, stage)

## Der ganze PODEST-Platz (Platte samt Die-View) in Display-Pixeln.
func podium_rect_px() -> Rect2:
	return _global(drum()["podium"])

## Die PLATTE des Podests in Display-Pixeln: sie umschließt die Kammer ganz.
func podium_plate_px() -> Rect2:
	return _global(drum()["podium_stage"])

## Die DIE-VIEW unter dem Podest (Fenster-Koordinaten) - zugleich ORIGINAL.
func podium_net_rect() -> Rect2:
	return drum()["podium_net"]

## Display-Pixel des Podest-Ankers ((-1,-1) = er steht gerade nicht).
func podium_stage_center() -> Vector2:
	if _podium_stage_host == null or not is_instance_valid(_podium_stage_host):
		return Vector2(-1, -1)
	return _podium_stage_host.get_global_rect().get_center()

## Die KAMMER unter der Podest-Platte (Fenster-Koordinaten): in Ruhe geschlossen, beim
## Prägen sinkt der Würfel hinein.
func chamber_rect() -> Rect2:
	return drum()["chamber"]

## Die Kammer in Display-Pixeln.
func chamber_rect_px() -> Rect2:
	return _global(chamber_rect())

## Die WANNE von ORIGINAL in Display-Pixeln: unter der Kammer, so breit wie die Die-View.
func net_tray_px() -> Rect2:
	var mouth := chamber_rect_px()
	var net := _global(podium_net_rect())
	return Rect2(Vector2(net.position.x, mouth.end.y),
		Vector2(net.size.x, net.end.y - mouth.end.y))

## Das Zeichen-Feld "+" (der Umschalter) in Display-Pixeln.
func sign_rects_px() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for field: Rect2 in drum()["signs"]:
		out.append(_global(field))
	return out

## Der Präge-Sitz in Display-Pixeln.
func stamp_seat_px() -> Rect2:
	return _global(stamp_seat_rect())

## Die GLEICHUNG in Display-Pixeln: Vorschau, Prägen, Info-Schirm und die Podest-Spalte
## (Podest, Umschalter, UPGRADES).
func equation_area_px() -> Rect2:
	return _global(drum()["equation"])

## Was die Werkstatt in Display-Pixeln bedient: die Walze samt Nummern, Vorschau,
## UPGRADES samt Umschalter, die vier Trays des Magazins und - solange keine Öffnung ihren
## Platz hat - Info-Schirm, Podest und Präge-Sitz.
func hit_rects() -> Array[Rect2]:
	var layout := drum()
	var pit: Rect2 = layout["pit"]
	var drum_row := pit.grow_individual(0.0, unit() * (SLICE_NUMBER_UNITS + SLICE_NUMBER_GAP),
		0.0, 0.0)
	var rects: Array[Rect2] = [_global(drum_row), preview_rect_px(),
		_global((layout["upgrades"] as Rect2).merge((layout["signs"] as Array)[0]))]
	if not opening_shown:
		rects.append_array([info_rect_px(), podium_rect_px(), stamp_seat_px()])
	rects.append_array(shelf_tray_rects())
	return rects

## Der PRÄGE-SITZ rechts neben der Vorschau, mittig zu ihr.
func stamp_seat_rect() -> Rect2:
	return drum()["stamp"]

## Steht gerade eine PAKET-ÖFFNUNG? Dann sind Podest und Prägen fort (scene_root meldet es;
## die Öffnungs-Zone liegt an ihrer Stelle) - Vorschau, UPGRADES und Umschalter bleiben.
var opening_shown := false:
	set(value):
		if opening_shown == value:
			return
		opening_shown = value
		_sync_equation_shown()

## Die Knoten der Gleichung in der Zone (die Die-View des Podests samt Ergebnis-Netz folgt
## _sync_net_shown).
const EQUATION_NODES: Array[String] = ["PodiumPlate", "ActionSeat"]

## Podest und Prägen stehen nur, solange keine Öffnung ihren Platz braucht - ausgeblendet
## nehmen sie auch keinen Klick.
func _sync_equation_shown() -> void:
	if _content == null or not is_instance_valid(_content):
		return
	for node_name in EQUATION_NODES:
		var node := _content.get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.visible = not opening_shown
	_sync_net_shown()

func _build_street(u: float) -> void:
	_build_traces(u)  # zuerst: die Bahnen liegen unter allem
	_build_podium(u)
	_build_preview(u)
	_build_equation(u)
	_build_toggle()
	_build_slices(u)
	_build_action_seat(u)
	_sync_equation_shown()

## Der UMSCHALTER: ein unsichtbarer Knopf auf dem "+"-Feld - den Koppler stellt scene_root.
func _build_toggle() -> void:
	var signs: Array = drum()["signs"]
	if signs.is_empty():
		return
	var field: Rect2 = signs[0]
	var button := Button.new()
	button.name = "ResultToggle"
	button.focus_mode = Control.FOCUS_NONE
	button.position = field.position
	button.size = field.size
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(toggle_result)
	_content.add_child(button)

## Wechselt die Die-View zwischen ORIGINAL und ERGEBNIS.
func toggle_result() -> void:
	result_shown = not result_shown

## DIE BUSSE stehen IMMER: vier Spuren (eine je Sorte) von der rechten Grabenwand in die
## linke Kante von UPGRADES, und vier von seiner Oberkante durch das "+"-Feld in die
## Unterkante der Die-View des Podests. Leer sind sie farblos, eine Spur leuchtet, sobald
## ihre Sorte steckt.
func _build_traces(u: float) -> void:
	var layout := drum()
	var lanes := _slice_lanes()
	var layer := TraceLayer.new()
	layer.name = "Traces"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := maxf(u * FEED_WIDTH, 1.5)
	var pitch := u * FEED_PITCH
	var entries := entry_paths(layout["pit"], layout["upgrades"], TRACE_LANES, pitch)
	var feeds := feed_paths(layout["upgrades"], layout["podium_net"], TRACE_LANES, pitch)
	for paths: Array[PackedVector2Array] in [entries, feeds]:
		for lane in paths.size():
			layer.add_trace(paths[lane], lane_tint(lane), lanes.has(lane), width, 0)
	layer.ribbon = pitch
	_content.add_child(layer)

## Die BUSSE in Display-Pixeln für die Körper (DieViewDress): Spuren und Teilung.
func bus_paths_px() -> Dictionary:
	var layout := drum()
	var pitch := unit() * FEED_PITCH
	var shift := get_global_rect().position
	var out := {"pitch": pitch, "entries": [], "feeds": []}
	for key: String in ["entries", "feeds"]:
		var paths := entry_paths(layout["pit"], layout["upgrades"], TRACE_LANES, pitch) \
			if key == "entries" else feed_paths(layout["upgrades"], layout["podium_net"],
				TRACE_LANES, pitch)
		for path in paths:
			var moved := PackedVector2Array()
			for point in path:
				moved.append(point + shift)
			(out[key] as Array).append(moved)
	return out

## Je Spur ihre Farbe, sobald ihre Sorte auf der Walze steckt (Alpha 0 = dunkel).
func bus_tints() -> Array[Color]:
	var lanes := _slice_lanes()
	var out: Array[Color] = []
	for lane in TRACE_LANES:
		out.append(lane_tint(lane) if lanes.has(lane) else Color(0.0, 0.0, 0.0, 0.0))
	return out

## Die Sortenfarbe einer Spur (Pack.SHELF_ORDER).
static func lane_tint(lane: int) -> Color:
	var shelf := String(Pack.SHELF_ORDER[clampi(lane, 0, Pack.SHELF_ORDER.size() - 1)])
	return PackDrawerView.COLORS.get(shelf, GOLD)

## Je Scheibe die Farbe ihrer Karte (Alpha 0 = leer).
func _slice_tints() -> Array[Color]:
	var tints: Array[Color] = []
	tints.resize(DRUM_SLICES)
	tints.fill(Color(0.0, 0.0, 0.0, 0.0))
	for card in _slot_cards():
		var slot := int(card.get("slot", -1))
		if slot >= 0 and slot < tints.size():
			tints[slot] = PackDrawerView.tint_of(String(card.get("sort", "")),
				String(card.get("catalyst", "")), card.get("net", []),
				bool(card.get("blank", false)))
	return tints

## Je Scheibe die Spur ihrer Karten-Sorte (-1 = leer).
func _slice_lanes() -> Array[int]:
	var lanes: Array[int] = []
	lanes.resize(DRUM_SLICES)
	lanes.fill(-1)
	for card in _slot_cards():
		var slot := int(card.get("slot", -1))
		if slot >= 0 and slot < lanes.size():
			var rank := Pack.SHELF_ORDER.find(String(card.get("sort", "")))
			lanes[slot] = rank if rank >= 0 else TRACE_LANES - 1
	return lanes

## Die Höhe einer Eingangs-Spur: mittig zu UPGRADES, Spur 0 oben.
static func entry_y(upgrades: Rect2, pitch: float, lane: int, lanes: int) -> float:
	return upgrades.get_center().y + (float(lane) - float(lanes - 1) * 0.5) * pitch

## Der EINGANGS-BUS: waagerecht von der rechten Grabenwand in die linke Kante von UPGRADES.
static func entry_paths(pit: Rect2, upgrades: Rect2, lanes: int,
		pitch: float) -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	if upgrades.position.x <= pit.end.x:
		return paths
	for lane in lanes:
		var y := entry_y(upgrades, pitch, lane, lanes)
		paths.append(PackedVector2Array([Vector2(pit.end.x, y), Vector2(upgrades.position.x, y)]))
	return paths

## Der AUSGANGS-BUS: senkrecht aus der Oberkante von UPGRADES durch das "+"-Feld in die
## Unterkante der Die-View des Podests.
static func feed_paths(upgrades: Rect2, view: Rect2, lanes: int,
		pitch: float) -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	if view.end.y >= upgrades.position.y:
		return paths
	for lane in lanes:
		var x := feed_x(upgrades, pitch, lane, lanes)
		paths.append(PackedVector2Array([Vector2(x, upgrades.position.y), Vector2(x, view.end.y)]))
	return paths

## Der Abgang einer Bus-Spur an der Oberkante von UPGRADES: mittig, Spur 0 links.
static func feed_x(upgrades: Rect2, pitch: float, lane: int, lanes := TRACE_LANES) -> float:
	return upgrades.get_center().x + (float(lane) - float(lanes - 1) * 0.5) * pitch

## Die gemalten Bahnen im Stil der Licht-Adern: Kupferzug unter Lötstopplack mit hellem
## Grat, 45°-Ecken, Gold-Pads an beiden Enden; belegt trägt der Grat die Kartenfarbe.
class TraceLayer extends Control:
	var paths: Array[PackedVector2Array] = []
	var tints: Array[Color] = []
	var lit: Array[bool] = []
	var widths: Array[float] = []
	## Der Punkt mit dem Lötauge - das Ende am Speicher trägt keines.
	var eyes: Array[int] = []
	## Das Bündel einer Bahn (Scheibe; der Ausgangs-Bus hat ein eigenes).
	var bundles: Array[int] = []
	## Der größte Spur-Abstand innerhalb eines Bündels.
	var ribbon := 4.0
	## ENTWURF: 0 heute, 1 Kupfer, 2 Bus-Band, 3 Datenstrom.
	static var style := 0
	var _flow := 0.0

	func add_trace(path: PackedVector2Array, tint: Color, on: bool, width: float,
			eye: int, bundle := -1) -> void:
		paths.append(path)
		tints.append(tint)
		lit.append(on)
		widths.append(width)
		eyes.append(eye)
		bundles.append(bundle)

	func _process(delta: float) -> void:
		if style == 3 and lit.has(true):
			_flow += delta
			queue_redraw()

	func _lit_tint(i: int) -> Color:
		var tint := tints[i].darkened(TRACE_DARKEN)
		tint.a = 1.0
		return tint

	func _draw() -> void:
		match style:
			1:
				_draw_copper()
				return
			2:
				_draw_ribbon()
				return
			3:
				_draw_stream()
				return
		var lines: Array[PackedVector2Array] = []
		for i in paths.size():
			lines.append(PcbDeckView.track_line(paths[i], 0.0, widths[i] * 0.5))
			draw_polyline(lines[i], TRACE_CLEAR, widths[i] + 2.4, true)
		# Erst alle matten, dann die leuchtenden - ihr Schein liegt über den Nachbarn.
		for pass_lit: bool in [false, true]:
			for i in paths.size():
				if lit[i] != pass_lit:
					continue
				var line := lines[i]
				if pass_lit:
					var tint := _lit_tint(i)
					draw_polyline(line, Color(tint, 0.2), widths[i] * 3.0, true)
					draw_polyline(line, tint.darkened(0.55), widths[i], true)
					draw_polyline(line, tint, widths[i] * 0.4, true)
				else:
					draw_polyline(line, LedStripView.TRACE, widths[i], true)
					draw_polyline(line, LedStripView.CROWN, widths[i] * 0.32, true)
				var last := line.size() - 1
				for ends: Array in [[line[0], line[1]], [line[last], line[last - 1]]]:
					var at: Vector2 = ends[0]
					var dir := ((ends[1] as Vector2) - at).normalized()
					var reach := minf(widths[i] * 3.0, at.distance_to(ends[1]))
					draw_line(at, at + dir * reach, LedStripView.PAD, widths[i] + 1.6)

	## KUPFER: Kupfer unter grünem Lötstopplack, belegt glänzt die Bahn in der Sortenfarbe;
	## jeder Fuß ist eine Durchkontaktierung (Ring mit Bohrung).
	func _draw_copper() -> void:
		var mask := Color(0.05, 0.16, 0.1, 0.95)
		var copper := Color(0.62, 0.42, 0.2)
		for i in paths.size():
			draw_polyline(paths[i], mask, widths[i] * 2.4, true)
		for pass_lit: bool in [false, true]:
			for i in paths.size():
				if lit[i] != pass_lit:
					continue
				var w := widths[i] * 1.4
				if pass_lit:
					var tint := _lit_tint(i)
					draw_polyline(paths[i], Color(tint, 0.25), w * 3.0, true)
					draw_polyline(paths[i], tint, w, true)
					draw_polyline(paths[i], tint.lightened(0.45), w * 0.35, true)
				else:
					draw_polyline(paths[i], copper.darkened(0.35), w, true)
					draw_polyline(paths[i], copper.darkened(0.1), w * 0.3, true)
				var via := paths[i][eyes[i]]
				draw_circle(via, w * 1.55, mask)
				draw_circle(via, w * 1.25, Color(0.82, 0.68, 0.38))
				draw_circle(via, w * 0.6, Color(0.02, 0.03, 0.03))

	## BUS-BAND: jedes Bündel liegt als EIN Band mit Massering auf dem Deck, die Spuren
	## darin; am Fuß steht der Bus-Name im Bestückungsdruck.
	func _draw_ribbon() -> void:
		var rim := Color(0.55, 0.62, 0.76)
		var fill := Color(0.09, 0.14, 0.19)
		var span := ribbon * 1.5
		for i in paths.size():
			draw_polyline(paths[i], rim, span + widths[i] * 2.4, true)
		for i in paths.size():
			draw_polyline(paths[i], fill, span, true)
		for pass_lit: bool in [false, true]:
			for i in paths.size():
				if lit[i] != pass_lit:
					continue
				var w := widths[i] * 0.75
				if pass_lit:
					var tint := _lit_tint(i)
					draw_polyline(paths[i], Color(tint, 0.3), w * 2.6, true)
					draw_polyline(paths[i], tint, w, true)
				else:
					draw_polyline(paths[i], TRACE_IDLE.darkened(0.25), w, true)
		var font := ThemeDB.fallback_font
		var size := int(maxf(ribbon * 2.2, 8.0))
		var seen := {}
		for i in paths.size():
			var bundle := bundles[i]
			if bundle < 0 or bundle >= DRUM_SLICES or seen.has(bundle):
				continue
			seen[bundle] = true
			var foot := paths[i][0]
			var text := "BUS%d D0-3" % (bundle + 1)
			draw_string(font, foot + Vector2(ribbon * 3.6 + widths[i] * 3.0, -size * 2.4),
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.75, 0.78, 0.85, 0.7))

	## DATENSTROM: feine Spuren, am Fuß ein Abschluß-Widerstandsnetz je Bündel; über die
	## belegte Spur laufen Datenpakete zum Speicher.
	func _draw_stream() -> void:
		var idle := Color(0.16, 0.34, 0.36)
		for i in paths.size():
			draw_polyline(paths[i], TRACE_BED, widths[i] * 1.8, true)
		for i in paths.size():
			var w := widths[i] * 0.7
			draw_polyline(paths[i], _lit_tint(i).darkened(0.45) if lit[i] else idle, w, true)
		for i in paths.size():
			if not lit[i]:
				continue
			_draw_packets(paths[i], widths[i], _lit_tint(i))
		var packs := {}
		for i in paths.size():
			var bundle := bundles[i]
			if bundle < 0 or bundle >= DRUM_SLICES:
				continue
			var foot := paths[i][0]
			var box: Rect2 = packs.get(bundle, Rect2(foot, Vector2.ZERO))
			packs[bundle] = box.expand(foot)
		for bundle: int in packs:
			var box: Rect2 = packs[bundle]
			var body := Rect2(box.position.x - ribbon * 0.8, box.position.y - ribbon * 7.0,
				box.size.x + ribbon * 1.6, ribbon * 3.6)
			for i in paths.size():
				if bundles[i] != bundle:
					continue
				var pad := Vector2(ribbon * 0.55, ribbon * 0.8)
				var x := paths[i][0].x - pad.x * 0.5
				var pad_tint := _lit_tint(i) if lit[i] else Color(0.8, 0.7, 0.45)
				draw_rect(Rect2(x, body.position.y - pad.y * 0.6, pad.x, pad.y), pad_tint)
				draw_rect(Rect2(x, body.end.y - pad.y * 0.4, pad.x, pad.y), pad_tint)
			draw_rect(body, Color(0.06, 0.06, 0.08))
			draw_rect(body, Color(0.45, 0.47, 0.55), false, 1.0)
			draw_circle(body.position + Vector2(ribbon * 0.6, ribbon * 0.6), ribbon * 0.25,
				Color(0.5, 0.5, 0.55))

	func _draw_packets(path: PackedVector2Array, width: float, tint: Color) -> void:
		var length := 0.0
		for k in range(1, path.size()):
			length += path[k - 1].distance_to(path[k])
		var gap := maxf(width * 14.0, 18.0)
		var dash := gap * 0.35
		var offset := fmod(_flow * gap * 1.6, gap)
		var at := offset
		while at < length:
			_draw_piece(path, at, minf(at + dash, length), width * 1.1, tint.lightened(0.35))
			at += gap

	func _draw_piece(path: PackedVector2Array, from: float, to: float, width: float,
			tint: Color) -> void:
		var walked := 0.0
		for k in range(1, path.size()):
			var a := path[k - 1]
			var b := path[k]
			var seg := a.distance_to(b)
			if seg <= 0.0:
				continue
			var lo := maxf(from - walked, 0.0)
			var hi := minf(to - walked, seg)
			if hi > lo:
				draw_line(a.lerp(b, lo / seg), a.lerp(b, hi / seg), tint, width, true)
			walked += seg
			if walked >= to:
				return

## DER SPEICHER hinter dem UPGRADES-Netz ist eine PLATINE: links kommt der Eingangs-Bus
## aus der Walze an eine Sammelschiene, die den FLÄCHEN-BUS in beiden Fugen des Kreuzes
## speist; an ihm hängen die sechs Energiezellen und jede Netz-Zelle, rechts hinauf geht
## er an die vier Abgänge oben in der Mitte. Kein Zug kreuzt. Die Zellen selbst sind
## Körper (StorageBankView) - hier liegt nur ihr Halter.
class StorageBody extends Control:
	## So viele Zellen liegen je Reihe in den freien Kreuz-Ecken rechts.
	const ROW_CELLS := 3
	var cell := 10.0
	var net_origin := Vector2.ZERO
	var slice_tints: Array[Color] = []
	var slice_lanes: Array[int] = []
	## Die Höhen der vier Eingänge links und die vier Abgänge oben (lokal).
	var entries: Array[float] = []
	var feeds: Array[float] = []

	## Kein Rahmen, kein Grund: der Speicher liegt auf dem Deck des Tisches.
	static func housing() -> StyleBox:
		return StyleBoxEmpty.new()

	## Der Netz-Platz im Schirm: nach rechts gerückt - links läuft der Eingang.
	static func net_origin_in(size: Vector2, span: Vector2) -> Vector2:
		var pad := ((size - span) * 0.5).max(Vector2.ZERO)
		return Vector2(maxf(pad.x * 2.0 - STORAGE_EDGE, pad.x), pad.y)

	## Der Halter der Energiezelle einer Scheibe: oben liegen 1-2-3, unten 4-5-6.
	static func cell_rect(origin: Vector2, cell_px: float, slice: int) -> Rect2:
		var step := cell_px * (1.0 + DieNetView.GAP_FACTOR)
		var block := cell_px * (2.0 + DieNetView.GAP_FACTOR)
		var room := block / float(ROW_CELLS)
		var top := slice < ROW_CELLS
		var place := slice % ROW_CELLS
		var can := Vector2(room * 0.6, cell_px * 0.74)
		return Rect2(origin + Vector2(step * 2.0 + room * (float(place) + 0.5) - can.x * 0.5,
			(0.0 if top else step * 2.0) + (cell_px - can.y) * 0.5), can)

	func stored() -> int:
		var count := 0
		for tint in slice_tints:
			if tint.a > 0.0:
				count += 1
		return count

	func _line() -> float:
		return maxf(cell * 0.028, 1.5)

	func _slice_color(slice: int) -> Color:
		var tint: Color = slice_tints[slice] if slice < slice_tints.size() else Color(0, 0, 0, 0)
		return Color(tint.darkened(TRACE_DARKEN), 1.0) if tint.a > 0.0 else TRACE_IDLE

	func _draw() -> void:
		var bus := STORAGE_BUS if stored() > 0 else TRACE_IDLE
		_draw_bus(bus)
		_draw_pins(bus.darkened(0.35))
		for slice in slice_tints.size():
			_draw_holder(slice)

	## Eingang, Sammelschiene, FLÄCHEN-BUS in beiden Fugen, rechts hinauf zu den Abgängen.
	func _draw_bus(bus: Color) -> void:
		var line := _line()
		var step := cell * (1.0 + DieNetView.GAP_FACTOR)
		var gap := cell * DieNetView.GAP_FACTOR
		var left := line * 2.0
		var right := size.x - 3.0 - line
		var top := line * 2.0
		var rows: Array[float] = []
		for row in 2:
			rows.append(net_origin.y + cell + gap * 0.5 + step * float(row))
		for y in rows:
			draw_line(Vector2(left, y), Vector2(right, y), bus, line)
		var low := rows[0]
		var high := rows[1]
		for y in entries:
			low = minf(low, y)
			high = maxf(high, y)
		draw_line(Vector2(left, low), Vector2(left, high), bus, line)
		for lane in entries.size():
			var on := slice_lanes.has(lane)
			draw_line(Vector2(0.0, entries[lane]), Vector2(left, entries[lane]),
				Color(WorkshopView.lane_tint(lane), 1.0) if on else TRACE_IDLE, line)
		draw_line(Vector2(right, rows[1]), Vector2(right, top), bus, line)
		if feeds.is_empty():
			return
		draw_line(Vector2(feeds[0], top), Vector2(right, top), bus, line)
		for lane in feeds.size():
			var on := slice_lanes.has(lane)
			draw_line(Vector2(feeds[lane], top), Vector2(feeds[lane], 0.0),
				Color(WorkshopView.lane_tint(lane), 1.0) if on else TRACE_IDLE, line)
		# Jede Zelle speist den Bus ihrer Reihe.
		for slice in slice_tints.size():
			var seat := cell_rect(net_origin, cell, slice)
			var x := seat.get_center().x
			var y := rows[1] if slice >= ROW_CELLS else rows[0]
			draw_line(Vector2(x, seat.end.y if slice < ROW_CELLS else seat.position.y), Vector2(x, y),
				_slice_color(slice), line)

	## Die Beinchen der sechs Netz-Zellen: in den Fugen reichen sie an den Bus.
	func _draw_pins(bus: Color) -> void:
		var reach := cell * DieNetView.GAP_FACTOR * 0.5
		var width := maxf(cell * 0.03, 1.0)
		for face in 6:
			var box := Rect2(net_origin + DieNetView.cell_position(face, cell), Vector2.ONE * cell)
			for k in 5:
				var t := (float(k) + 0.5) / 5.0
				var x := box.position.x + box.size.x * t
				var y := box.position.y + box.size.y * t
				draw_line(Vector2(x, box.position.y), Vector2(x, box.position.y - reach), bus, width)
				draw_line(Vector2(x, box.end.y), Vector2(x, box.end.y + reach), bus, width)
				draw_line(Vector2(box.position.x, y), Vector2(box.position.x - reach, y), TRACE_IDLE,
					width)
				draw_line(Vector2(box.end.x, y), Vector2(box.end.x + reach, y), TRACE_IDLE, width)

	## Der Halter einer Zelle: dunkle Platte, an beiden Enden ein Kontakt.
	func _draw_holder(slice: int) -> void:
		var seat := cell_rect(net_origin, cell, slice)
		var tint: Color = slice_tints[slice] if slice < slice_tints.size() else Color(0, 0, 0, 0)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(maxi(2, int(seat.size.x * 0.2)))
		if tint.a > 0.0:
			box.bg_color = Color(tint, 0.16)
			draw_style_box(box, seat.grow(seat.size.x * 0.22))
		box.bg_color = STORAGE_CAN
		draw_style_box(box, seat.grow(_line()))
		var pad := Vector2(seat.size.x * 0.5, _line() * 1.4)
		for y: float in [seat.position.y - pad.y * 0.5, seat.end.y - pad.y * 0.5]:
			draw_rect(Rect2(Vector2(seat.get_center().x - pad.x * 0.5, y), pad), STORAGE_PAD)

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

## Ein Netz-Schirm der Gleichung mit einem leeren Platz in Netzgröße, mittig. Name und
## Fassung sind Körper (DieViewDress).
func _net_screen(screen_name: String, rect: Rect2, cell: float, style: StyleBox) -> Control:
	var screen := Panel.new()
	screen.name = screen_name
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override("panel", style)
	screen.position = rect.position
	screen.size = rect.size
	_content.add_child(screen)
	var span := DieNetView.net_size(cell)
	var host := Control.new()
	host.name = "Net"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.position = ((rect.size - span) * 0.5).max(Vector2.ZERO)
	host.size = span
	screen.add_child(host)
	return host

## DAS PODEST: oben die Platte über der Kammer (der Puck gehört scene_root), unten seine
## DIE-VIEW - je nach Umschalter ORIGINAL oder ERGEBNIS des gewählten Würfels.
func _build_podium(_u: float) -> void:
	var layout := drum()
	var plate_rect: Rect2 = layout["podium_stage"]
	var plate := Panel.new()
	plate.name = "PodiumPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", TableScreen.window_style())
	plate.position = plate_rect.position
	plate.size = plate_rect.size
	_content.add_child(plate)
	_podium_stage_host = _podium_host("PodiumStage", podium_stage_rect())
	_podium_view_host = _net_screen("PodiumScreen", layout["podium_net"], podium_cell(),
		StyleBoxEmpty.new())
	# Der PARKPLATZ des ERGEBNIS-Netzes liegt auf demselben Platz und bleibt leer.
	var park := Control.new()
	park.name = "Park"
	park.mouse_filter = Control.MOUSE_FILTER_IGNORE
	park.position = _podium_view_host.position
	park.size = _podium_view_host.size
	_podium_view_host.get_parent().add_child(park)
	_net_host = park
	_fill_podium()

## DIE VORSCHAU rechts am Pool: ihr Netz-Platz; gefüllt wird er von _fill_preview.
func _build_preview(_u: float) -> void:
	_preview_host = _net_screen("PreviewScreen", drum()["preview"], podium_cell(),
		StyleBoxEmpty.new())
	_preview_key = ""
	_fill_preview()

## Was die Vorschau über ihrem Würfel rechnet: bei Umschalter AN die gesteckte Serie auf
## DIESEM Würfel - dieselbe Rechnung wie preview(), gebucht wird nichts. Während der
## Zeremonie und beim Verdichten schlicht ({}).
func preview_projection() -> Dictionary:
	if hover_die == null or run == null or not result_shown or burning() or compressing() \
			or _series.is_empty():
		return {}
	return run.resolve_series(_series, hover_die)

## Die Vorschau neu: nur der WECHSEL von Würfel, Inhalt oder Rechnung baut.
func _fill_preview() -> void:
	if _preview_host == null or not is_instance_valid(_preview_host):
		return
	var die := hover_die
	var projection := preview_projection()
	var key := "%d|%s|%s" % [die.get_instance_id() if die != null else 0,
		str(DeckGlassView.pool_signature([die] as Array[DieDefinition])) if die != null else "",
		str(projection)]
	if key == _preview_key:
		return
	_preview_key = key
	for child in _preview_host.get_children():
		_preview_host.remove_child(child)
		child.queue_free()
	_preview_net = null
	var cell := podium_cell()
	if die == null:
		_preview_host.add_child(_empty_net_cross(cell))
		return
	_preview_net = PressNetView.new()
	_preview_net.cell = cell
	_preview_net.def = die
	_preview_net.projection = projection
	_preview_net.build()
	_preview_host.add_child(_preview_net)

## Der Würfel, den die VORSCHAU zeigt (null = leeres Kreuz).
func preview_die() -> DieDefinition:
	if _preview_net == null or not is_instance_valid(_preview_net):
		return null
	return _preview_net.def

## Der Würfel, den die Die-View des Podests zeigt (null = keiner): während des Prägens bis
## zum EINSCHLAG der Stand davor, sonst der auf dem Podest.
func shown_die() -> DieDefinition:
	return before_die() if before_die() != null else seated_die()

## Was die Die-View zeigt: "result" (das geparkte ERGEBNIS-Netz), "card" (die Karte, die
## das Verdichten ergäbe), "plain" (ein Würfel schlicht) oder "empty" (das leere Kreuz).
## Gibt es nichts zu rechnen, zeigen beide Stellungen dasselbe.
func die_view_mode() -> String:
	if result_shown:
		if preview_target() != null:
			return "result"
		if compressing() and not _sum_nets().is_empty():
			return "card"
	return "plain" if shown_die() != null else "empty"

## Das Schild der Die-View: "ERGEBNIS", wo gerechnet wird, sonst "ORIGINAL".
func die_view_label() -> String:
	return "ERGEBNIS" if die_view_mode() in ["result", "card"] else "ORIGINAL"

## Zeigt die Die-View gerade das geparkte ERGEBNIS-Netz?
func _net_in_view() -> bool:
	return die_view_mode() == "result"

## Der Umschalter hat gewechselt: außerhalb der Zeremonie baut das Netz neu, in ihr nur die
## schlichte Die-View - der Zähl-Takt des Netzes reißt nie ab.
func _view_source_changed() -> void:
	if burning():
		_fill_podium()
	else:
		_refresh_preview_net()

## Die Die-View neu: nur der WECHSEL von Art und Würfel baut, die Sichtbarkeit des
## ERGEBNIS-Netzes folgt immer.
func _fill_podium() -> void:
	if _podium_view_host == null or not is_instance_valid(_podium_view_host):
		return
	var mode := die_view_mode()
	var die := shown_die()
	var key := "%s|%d|%s" % [mode, die.get_instance_id() if die != null else 0,
		str(DeckGlassView.pool_signature([die] as Array[DieDefinition])) if die != null else ""]
	if mode == "card":
		key += "|" + str(_sum_nets())
	if key != _die_view_key:
		_die_view_key = key
		for child in _podium_view_host.get_children():
			_podium_view_host.remove_child(child)
			child.queue_free()
		_podium_net = null
		_card_view = null
		_card_net = []
		var cell := podium_cell()
		match mode:
			"card":
				_card_net = SeriesResolver.compress(_sum_nets())["net"]
				_card_view = PressNetView.stamp_net(_card_net, cell)
				_podium_view_host.add_child(_card_view)
			"plain":
				_podium_net = PressNetView.new()
				_podium_net.cell = cell
				_podium_net.def = die
				_podium_net.build()
				_podium_view_host.add_child(_podium_net)
			"empty":
				_podium_view_host.add_child(_empty_net_cross(cell))
	_sync_net_shown()

## Sichtbar ist genau EINES: das geparkte ERGEBNIS-Netz oder die Die-View darunter - und
## während einer Öffnung keines von beiden.
func _sync_net_shown() -> void:
	var net := _net_in_view()
	if _podium_view_host != null and is_instance_valid(_podium_view_host):
		_podium_view_host.visible = not net and not opening_shown
	if _net != null and is_instance_valid(_net):
		_net.visible = net and not opening_shown

## Die Zelle der Die-View: die Fläche eines echten Würfels - aus der gemeldeten Kette
## gelesen, denn reicht die Pool-Höhe nicht, schrumpft sie dort.
func podium_cell() -> float:
	var net: Rect2 = drum()["podium_net"]
	var cell := (net.size.y - unit() * PODIUM_NET_PAD * 2.0) / DieNetView.net_size(1.0).y
	if cell > 0.0:
		return cell
	return (die_face_px if die_face_px > 0.0 else unit() * U_PER_FACE) * PODIUM_FACE_GAIN

## DIE GLEICHUNG: die Die-View des Podests + UPGRADES (die Summe der Serie).
func _build_equation(u: float) -> void:
	var cell := net_cell(u)
	var layout := drum()
	_sum_host = _net_screen("UpgradesScreen", layout["upgrades"], cell,
		TableScreen.window_style())
	_build_storage(u, cell, layout["upgrades"])
	_sum_signature = ""
	_refresh_sum_net()

## Die Halter der sechs Energiezellen in Display-Pixeln (je Scheibe) - die Körper stellt
## scene_root darauf. Leer, solange die Gleichung nicht steht.
func storage_cells_px() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _sum_host == null or not is_instance_valid(_sum_host):
		return out
	var rect := upgrades_net_rect()
	for slice in DRUM_SLICES:
		var seat := StorageBody.cell_rect(_sum_host.position, net_cell(unit()), slice)
		out.append(_global(Rect2(rect.position + seat.position, seat.size)))
	return out

## Die sechs Netz-Zellen des Speichers in Display-Pixeln (leer, solange die Gleichung nicht
## steht) - scene_root stellt die Chip-Rahmen darum.
func storage_chips_px() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _sum_host == null or not is_instance_valid(_sum_host):
		return out
	var cell := net_cell(unit())
	var origin := upgrades_net_rect().position + _sum_host.position
	for face in 6:
		out.append(_global(Rect2(origin + DieNetView.cell_position(face, cell),
			Vector2.ONE * cell)))
	return out

## Je Scheibe die Farbe ihrer Karte (Alpha 0 = leer).
func storage_tints() -> Array[Color]:
	return _slice_tints()

## UPGRADES ist ein SPEICHER: sein Gehäuse liegt unter dem Summen-Netz.
func _build_storage(u: float, cell: float, rect: Rect2) -> void:
	var screen := _sum_host.get_parent() as Panel
	screen.add_theme_stylebox_override("panel", StorageBody.housing())
	var body := StorageBody.new()
	body.name = "Storage"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size = rect.size
	body.cell = cell
	_sum_host.position = StorageBody.net_origin_in(rect.size, _sum_host.size)
	body.net_origin = _sum_host.position
	body.slice_tints = _slice_tints()
	body.slice_lanes = _slice_lanes()
	for lane in TRACE_LANES:
		body.entries.append(entry_y(rect, u * FEED_PITCH, lane, TRACE_LANES) - rect.position.y)
		body.feeds.append(feed_x(rect, u * FEED_PITCH, lane) - rect.position.x)
	screen.add_child(body)
	screen.move_child(body, 0)

## Der Würfel, den ORIGINAL zeigt (null = keiner, dann das leere Kreuz).
func before_die() -> DieDefinition:
	if burning() and not _burn_struck:
		return _burn_die
	if showing_result():
		return chosen_die()  # neben dem stehenden Ergebnis der gebuchte Stand
	return target_die()

## Das LEERE Kreuz: sechs dunkle Zellen an den Netz-Plätzen, sonst nichts.
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

## Das EINE Zellmaß der Gleichung: UPGRADES teilt die Zelle der Die-View.
func net_cell(_u: float) -> float:
	return podium_cell()

## Die Netz-Zelle einer Karte in Display-Pixeln, aus der gemeldeten STEHENDEN Zelle:
## das Netz füllt die Öffnung quer, und quer liegen drei Zellen samt zwei Fugen.
static func card_net_cell(cell: Vector2) -> float:
	var width := cell.y * PackDrawerView.CASSETTE_SCALE
	var share := DataCellView.opening_size().x * DataCellView.NET_WIDTH_SHARE \
		/ DataCellView.WIDTH
	return maxf(width * share / DieNetView.net_size(1.0).y, 1.0)

## Die Maße des Netzes in dieser Zelle - Spaltenbreite und Bandhöhe folgen ihm.
func net_span(u: float) -> Vector2:
	return DieNetView.net_size(net_cell(u))

# --- Die reine Layout-Kette --------------------------------------------------------

## Sechs Scheiben, Scheibe 1 links - der Deckel der Serie (GameRun.SERIES_SLOT_CAP).
const DRUM_SLICES := 6
## Luft der Karte in ihrer Scheibe, Anteil ihres Maßes (quer und längs).
const DRUM_AIR := 0.06
## Luft QUER zur Achse: sie ist die Wand neben der Karte, also die Tiefe der Mulde.
const DRUM_SIDE_AIR := 0.12
## Fuge zwischen Pool und Vorschau, vor dem Podest und zwischen Walze und Magazin, in u.
const DRUM_SHELF_GAP := 4.0
## Rand der PLATTE um die Kammer, in u je Seite (oben kommt der Kopf des Würfels dazu).
const PODIUM_RIM := 2.0
## Rand der Podest-Die-View um ihr Netz, in u je Seite.
const PODIUM_NET_PAD := 2.0
## Ein schwebender Würfel steht näher an der Kamera und liest größer als sein Maß auf
## dem Glas - gemessen an der Werkstatt-Station (Pool-Teilung 60 gegen 51 Bildschirm-px).
## Reicht die Pool-Höhe nicht, schrumpft dieser Faktor, nie die Kammer.
const PODIUM_FACE_GAIN := 1.17
## Die Höhe des "+"-Feldes (des Umschalters) zwischen ORIGINAL und UPGRADES, in u.
const EQ_SIGN_UNITS := 12.0
## Die Strecke des Eingangs-Busses zwischen Graben und UPGRADES, in u - lang genug, daß
## er aus der Weitsicht liest.
const ENTRY_BUS_UNITS := 8.0

## Die Kante des Scheiben-Vierkants: die KURZE Kartenseite plus Luft.
static func drum_side_px(card: Vector2) -> float:
	return card.y * (1.0 + DRUM_SIDE_AIR)

## Wie lang eine Scheibe längs der Achse ist: die lange Kartenseite plus Luft.
static func slice_length_px(card: Vector2) -> float:
	return card.x * (1.0 + DRUM_AIR)

## Die Kante der KAMMER unter dem Podest: ein Weltmaß, kopflos der u-Rückfall.
static func chamber_side_px(die_face: float, u: float) -> float:
	return (die_face if die_face > 0.0 else u * U_PER_FACE) * CHAMBER_FACES

## Wie weit der Anker (die Grubenmitte) unter der Oberkante der Platte liegt: oben so viel
## Rand, daß der schwebende Würfel ganz auf der Platte liest.
static func podium_anchor_drop(die_face: float, u: float) -> float:
	var face := die_face if die_face > 0.0 else u * U_PER_FACE
	var half := chamber_side_px(die_face, u) * 0.5
	return maxf(half, PODIUM_TILT_TRIM + face * PODIUM_HEAD_FACES) + u * PODIUM_RIM

## Die PLATTE: um den Anker gespiegelt, damit er ihre Mitte ist - sie IST die Kammer.
static func podium_plate_size(die_face: float, u: float) -> Vector2:
	var side := chamber_side_px(die_face, u)
	return Vector2(side + u * PODIUM_RIM * 2.0,
		podium_anchor_drop(die_face, u) * 2.0)

## Der Zell-Faktor der Die-View: PODIUM_FACE_GAIN, außer der Podest-Platz würde höher als
## die Pool-Reihe - dann schrumpft er.
static func podium_gain(pool_high: float, die_face: float, u: float) -> float:
	if pool_high <= 0.0 or die_face <= 0.0:
		return PODIUM_FACE_GAIN
	var room := pool_high - podium_plate_size(die_face, u).y - u * STREET_GAP \
		- u * PODIUM_NET_PAD * 2.0
	var fits := room / DieNetView.net_size(1.0).y / die_face
	return clampf(fits, 0.1, PODIUM_FACE_GAIN)

## Die Die-View des Podests: ihre Zellen sind so groß wie die Flächen der echten Würfel.
static func podium_net_size(card: Vector2, die_face: float, u: float,
		gain := PODIUM_FACE_GAIN) -> Vector2:
	if die_face <= 0.0:
		return card
	return DieNetView.net_size(die_face * gain) + Vector2.ONE * u * PODIUM_NET_PAD * 2.0

## Die ganze Kette in Display-px aus Pool-Reihe, liegender Karte, Würfelfläche und u.
## Rechts am Pool (eine Fuge daneben, oben bündig) die VORSCHAU, daneben PRÄGEN mittig zu
## ihr, darunter der INFO-SCHIRM bis zur Pool-Unterkante und eine Fuge vor das Podest.
## Unter dem Pool die WALZE mit sechs Scheiben, an ihrem rechten Ende UPGRADES (senkrecht
## mittig zum Graben), genau darüber das "+"-Feld und das PODEST (Platte über seiner
## Die-View, oben bündig mit dem Pool). Eine Fuge unter dem Graben das MAGAZIN aus vier
## Trays (columns = ihre Gruben, trays = samt Fassung); ist pit_floor gesetzt, rückt es so
## tief, daß die Unterkante der Gruben dort liegt. bounds ist das Fenster: Nummern, Graben
## und Magazin - Vorschau, Info und die Podest-Spalte liegen außerhalb.
static func drum_layout(pool: Rect2, card: Vector2, die_face: float, u: float,
		pit_floor := 0.0) -> Dictionary:
	var seam := u * STREET_GAP
	var gap := u * DRUM_SHELF_GAP
	var numbers := u * (SLICE_NUMBER_UNITS + SLICE_NUMBER_GAP)
	var gain := podium_gain(pool.size.y, die_face, u)
	var net_span := podium_net_size(card, die_face, u, gain)
	var plate_size := podium_plate_size(die_face, u)
	# Die Platte ist so breit wie die Die-View darunter (Spieler-Wunsch 2026-11-20).
	plate_size.x = maxf(plate_size.x, net_span.x)
	# Auf Kante gedreht braucht der Vierkant seine Diagonale.
	var high := drum_side_px(card) * sqrt(2.0) + seam
	var pitch := slice_length_px(card) + seam
	var pit_w := pitch * float(DRUM_SLICES)
	# DIE PODEST-SPALTE am Ende der Walze: Platte, Die-View, "+"-Feld, UPGRADES.
	var col := Rect2(Vector2(pool.position.x + pit_w + u * ENTRY_BUS_UNITS, pool.position.y),
		Vector2(maxf(net_span.x, plate_size.x), 0.0))
	var mid_x := col.get_center().x
	var podium_stage := Rect2(Vector2(mid_x - plate_size.x * 0.5, pool.position.y), plate_size)
	# Die KAMMER ist so groß wie die Platte (Spieler-Wunsch 2026-11-20); ihre Mitte ist
	# der Anker des Würfels.
	var chamber := podium_stage
	var podium_net := Rect2(Vector2(mid_x - net_span.x * 0.5, podium_stage.end.y + seam),
		net_span)
	var podium := Rect2(col.position, Vector2(col.size.x, podium_net.end.y - col.position.y))
	# Das "+"-Feld beginnt unter der Pool-Reihe (dort endet die Öffnungs-Zone), UPGRADES
	# mittig zum Graben - der Graben hält Nummern-Abstand zum Pool, das Feld seine Höhe.
	var plus_y := maxf(podium_net.end.y, pool.end.y) + seam
	var up_y := maxf(plus_y + u * EQ_SIGN_UNITS + seam,
		pool.end.y + seam + numbers + high * 0.5 - net_span.y * 0.5)
	var upgrades := Rect2(Vector2(mid_x - net_span.x * 0.5, up_y), net_span)
	var plus := Rect2(Vector2(col.position.x, plus_y), Vector2(col.size.x, up_y - seam - plus_y))
	var pit := Rect2(Vector2(pool.position.x, upgrades.get_center().y - high * 0.5),
		Vector2(pit_w, high))
	var slices: Array[Rect2] = []
	for i in DRUM_SLICES:
		slices.append(Rect2(Vector2(pit.position.x + seam * 0.5 + pitch * float(i),
			pit.position.y), Vector2(slice_length_px(card), high)))
	# DAS MAGAZIN: eine Fuge unter dem Graben, wenn gemeldet so tief, daß die Gruben auf
	# pit_floor enden.
	var shelf_size := PackDrawerView.shelf_for(card)
	var field0 := PackDrawerView.field_in(Rect2(Vector2.ZERO, shelf_size))
	var pits_end := field0.end.y
	for lane in PackDrawerView.column_rects(field0.size):
		pits_end = field0.position.y + lane.end.y
	var shelf_y := pit.end.y + gap
	if pit_floor > 0.0:
		shelf_y = maxf(shelf_y, pit_floor - pits_end)
	var shelf := Rect2(Vector2(pool.position.x, shelf_y), shelf_size)
	var field := PackDrawerView.field_in(shelf)
	# Je SORTE ein Tray: seine Grube (columns) und samt Fassung (trays), EINE Quelle.
	var columns: Array[Rect2] = []
	var trays: Array[Rect2] = []
	for lane in PackDrawerView.column_rects(field.size):
		var hole := Rect2(field.position + lane.position, lane.size)
		columns.append(hole)
		trays.append(PackDrawerView.tray_of(hole))
	var top := Rect2(Vector2(pit.position.x, pit.position.y - numbers), Vector2(pit.size.x,
		numbers))
	var bounds := top.merge(pit).merge(shelf)
	# Rechts am Pool: VORSCHAU, PRÄGEN mittig zu ihr, darunter der INFO-SCHIRM.
	var preview := Rect2(Vector2(pool.end.x + gap, pool.position.y), net_span)
	var stage := die_face * STAGE_FACES
	var action := Vector2(u * ACTION_WIDTH, maxf(stage * ACTION_SPAN_SHARE, u * ACTION_HEIGHT))
	var info_top := preview.end.y + seam
	var info := Rect2(Vector2(preview.position.x, info_top),
		Vector2(maxf(podium.position.x - gap - preview.position.x, 0.0),
			maxf(pool.end.y - info_top, 0.0)))
	# PRÄGEN mittig im Feld zwischen Vorschau und Podest (über dem Info-Schirm), die Schale
	# rechts daneben; eine Fuge Luft zur Vorschau - PRÄGEN liegt schon in der Öffnungs-Zone.
	var stamp_area := Rect2(Vector2(preview.end.x + gap, preview.position.y),
		Vector2(maxf(info.end.x - preview.end.x - gap * 2.0, action.x), net_span.y))
	var stamp := Rect2(stamp_area.get_center() - action * 0.5, action)
	var equation := preview.merge(stamp_area).merge(podium).merge(plus).merge(upgrades)
	if info.size.y > 0.0:
		equation = equation.merge(info)
	return {"pit": pit, "slices": slices, "chamber": chamber, "stamp": stamp,
		"shelf": shelf, "columns": columns, "trays": trays, "info": info,
		"original": podium_net, "upgrades": upgrades, "signs": [plus] as Array[Rect2],
		"preview": preview, "equation": equation, "podium": podium,
		"podium_stage": podium_stage, "podium_net": podium_net, "bounds": bounds}

# --- Die Würfel des Vorrats und die Zielwahl ---------------------------------------

## Die Würfel des Vorrats (ohne Lauf leer) - daraus liest die Zielwahl ihren Index.
func pool_defs() -> Array[DieDefinition]:
	if run == null:
		return [] as Array[DieDefinition]
	return run.owned_pool

## Der GEWÄHLTE Würfel (null = keiner).
func chosen_die() -> DieDefinition:
	var defs := pool_defs()
	if _chosen_index < 0 or _chosen_index >= defs.size():
		return null
	return defs[_chosen_index]

func chosen_index() -> int:
	return _chosen_index

## Das ZIEL der Serie (null = keins): der gewählte Würfel, sobald eine Karte steckt
## (oder die Übertragung läuft) und kein Rohling auf dem Podest liegt. Ansehen ist
## nicht Aufwerten.
func target_die() -> DieDefinition:
	if compressing() or target_pack() != null:
		return null
	if _series.is_empty() and not burning():
		return null
	return chosen_die()

## Der gewählte Würfel, der nur ANGESEHEN wird (null = keiner): gewählt, aber kein Ziel.
func podium_die() -> DieDefinition:
	return chosen_die() if target_die() == null else null

## Der Würfel, dessen KÖRPER auf dem Podest steht (null = keiner): der gewählte, Ziel oder
## nicht - es sei denn, der ROHLING liegt dort, dann wartet er in seinem Pool-Sitz.
func seated_die() -> DieDefinition:
	return null if compressing() else chosen_die()

## Die WAHL per Pool-Klick: scene_root meldet den angetippten physischen Würfel.
## Derselbe wählt ab, ein anderer wechselt. null oder ein Würfel, den der Pool nicht
## kennt, wählt ab. Ein Rohling auf dem Podest bleibt liegen.
func choose_die(die: DieDefinition) -> void:
	if editing_locked or burning():
		return
	var index := pool_defs().find(die) if die != null else -1
	if index < 0 or index == _chosen_index:
		clear_choice()
		return
	_chosen_index = index
	_announce_target()

## Der gewählte ROHLING (null = keiner). Gefüllt ist er keiner mehr, also fällt die
## Wahl von selbst, sobald das Verdichten gebucht hat.
func target_pack() -> Pack:
	if run == null or _target_pack == 0:
		return null
	var pack := run.pack_by_uid(_target_pack)
	return pack if pack != null and pack.is_blank_card() else null

## VERDICHTET die Werkstatt gerade, statt zu prägen? Die Art des Ziels entscheidet - und
## während der Zeremonie die Art, mit der sie aufbrach (der Rohling ist dann längst
## gefüllt und wäre keiner mehr).
func compressing() -> bool:
	if burning():
		return _burn_blank != 0
	return target_pack() != null

## Die ZIELWAHL eines Rohlings: derselbe nimmt ihn zurück, ein anderer wechselt. Ein
## gewählter Würfel bleibt gewählt - er wartet in seinem Pool-Sitz.
func set_target_pack(pack: Pack) -> void:
	if editing_locked or burning():
		return
	if pack == null or not pack.is_blank_card() or pack.pack_uid == _target_pack:
		clear_blank()
		return
	_target_pack = pack.pack_uid
	_announce_target()

## Nimmt den Rohling vom Podest zurück ins Magazin.
func clear_blank() -> void:
	if _target_pack == 0:
		return
	_target_pack = 0
	_announce_target()

## Wählt den Würfel ab - er fliegt in seinen Pool-Sitz zurück, die Karten bleiben stecken.
func clear_choice() -> void:
	if _chosen_index < 0:
		return
	if target_die() != null:
		skip_ceremony()  # mitten in der Übertragung: erst ihr harter Weg, dann die Abwahl
	_chosen_index = -1
	_announce_target()

## Wählt einen Würfel programmatisch (Tests, Debug) - am Tisch tippt der Spieler einen
## physischen Pool-Würfel an.
func choose_index(index: int) -> void:
	var defs := pool_defs()
	choose_die(defs[index] if index >= 0 and index < defs.size() else null)

func _announce_target() -> void:
	_drop_result()  # eine andere Wahl hat kein Ergebnis
	refresh()
	die_chosen.emit(chosen_die())

## Der Zielwürfel, den ERGEBNIS zeigt: während der Zeremonie der Stand VOR
## dem Prägen (nur so kann das Netz von 0 hochticken), danach der ERGEBNIS-Stand
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
## buchstäblich dieselbe Rechnung, die das Prägen bucht ({} = keine).
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
	var card := slot_card(_hover_slot)
	if card.is_empty():
		return [] as Array[int]
	var faces: Array[int] = []
	var net: Array = card.get("net", [])
	for face in StampNet.FACES:
		if StampNet.is_filled(StampNet.cell_at(net, face)):
			faces.append(face)
	return faces

## Display-Pixel des Ankers, über dem das Ziel der Serie schwebt: der EINE Platz, das
## Podest über der Kammer ((-1,-1) = es steht gerade nicht).
func target_net_center() -> Vector2:
	return podium_stage_center()

## Display-Pixel des ROHLING-PLATZES: die Mitte der Podest-Platte ((-1,-1) = sie steht
## gerade nicht). Die Karte LIEGT flach, darum ohne den Neigungs-Versatz des Würfels.
func blank_seat_center() -> Vector2:
	if _podium_stage_host == null or not is_instance_valid(_podium_stage_host):
		return Vector2(-1, -1)
	return podium_plate_px().get_center()

## Der ROHLING, der gerade auf dem Podest LIEGT - während der Zeremonie der, in den sie
## verdichtet (er ist da längst gefüllt und wäre keiner mehr, liegt aber weiter dort).
func seated_blank() -> Pack:
	if run == null:
		return null
	if burning():
		return run.pack_by_uid(_burn_blank) if _burn_blank != 0 else null
	return target_pack()

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

## Alles, was zur Werkbank gehört, in Display-Pixeln - die EINE Weiterleitungs-
## Region: das Fenster samt dem Magazin, das über seine Spalte hinausreicht.
func bench_rect() -> Rect2:
	return get_global_rect().merge(shelf_rect_global())

## Die MASSEINHEIT u folgt der WÜRFELFLÄCHE (WELLE X): im Streifen ist fast alles
## ein Weltmaß, also darf u nicht mehr aus einem Höhen-Budget fallen.
static func unit_for(die_face: float) -> float:
	return maxf(die_face / U_PER_FACE, 0.5)

## Die Maßeinheit u dieses Fensters: die vorgegebene, sonst die u-Konvention
## (Fensterbreite/100). Alles Gesetzte im Fenster rechnet in ihr.
func unit() -> float:
	if unit_px > 0.0:
		return unit_px
	return maxf(size.x, 200.0) / 100.0

# --- DIE SCHEIBEN der Walze ----------------------------------------------------------

## Wie viele Scheiben die Serie belegen darf: die Serienlänge des Laufs, mindestens bis zur
## letzten belegten - höchstens die Scheiben der Walze.
func slot_count() -> int:
	var slots := run.series_slots() if run != null else FALLBACK_SLOTS
	for card in _slot_cards():
		slots = maxi(slots, int(card.get("slot", 0)) + 1)
	return mini(slots, DRUM_SLICES)

## Die Karte auf Scheibe slot ({} = leer) - während der Zeremonie die des Prägens.
func slot_card(slot: int) -> Dictionary:
	if slot < 0:
		return {}
	for card in _slot_cards():
		if int(card.get("slot", -1)) == slot:
			return card
	return {}

## Die uid je Scheibe der Walze (0 = leer) - daran stellt scene_root die Körper.
func slice_uids() -> Array[int]:
	var uids: Array[int] = []
	uids.resize(DRUM_SLICES)
	uids.fill(0)
	for card in _slot_cards():
		var slot := int(card.get("slot", -1))
		if slot >= 0 and slot < uids.size():
			uids[slot] = int(card.get("uid", 0))
	return uids

## Die erste freie Scheibe (-1 = keine).
func _first_free_slot() -> int:
	for slot in slot_count():
		if not _series_slots.has(slot):
			return slot
	return -1

## Der Fußabdruck der LIEGENDEN Kassette in Fenster-Pixeln, in der EINEN Größe, die
## sie überall hat: Langseite waagerecht, Breite nach unten. Gemeldet wird nur die
## STEHENDE Zelle, die Langseite folgt aus dem Seitenverhältnis der Karte.
func lie_span_px() -> Vector2:
	return PackDrawerView.lie_cell(shelf_cell_px())

## DIE SCHEIBEN BAUEN: je Scheibe ein unsichtbarer Knopf über dem Graben (dort ist
## die Anzeige ohnehin fortgeschnitten), darüber ihre Nummer.
func _build_slices(u: float) -> void:
	for i in slot_count():
		var rect := slice_rect(i)
		var seat := _slice_button(i, slot_card(i))
		seat.position = rect.position
		seat.size = rect.size
		_content.add_child(seat)
	for i in DRUM_SLICES:
		var rect := slice_rect(i)
		var number := Label.new()
		number.name = "SliceNumber%d" % (i + 1)
		number.text = str(i + 1)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var high := u * SLICE_NUMBER_UNITS
		number.position = Vector2(rect.position.x,
			rect.position.y - high - u * SLICE_NUMBER_GAP)
		number.size = Vector2(rect.size.x, high)
		number.add_theme_font_size_override("font_size", maxi(8, int(u * SLICE_NUMBER_FONT)))
		number.add_theme_color_override("font_color",
			MUTED_COLOR if slot_card(i).is_empty() else TEXT_COLOR)
		if i >= slot_count():
			_lock_number(number, i)
		_content.add_child(number)
	_build_unlock()

## GESPERRTE Scheiben: die nächste nennt ihren Preis, die übrigen stehen gedämpft.
func _lock_number(number: Label, index: int) -> void:
	if index == slot_count() and run != null and run.drum_slot_price() > 0:
		number.text = "%d ⚡" % run.drum_slot_price()
		_unlock_label = number
		_sync_unlock()
	else:
		number.add_theme_color_override("font_color", LOCKED_COLOR)

## Der Kauf-Knopf über der nächsten gesperrten Scheibe.
func _build_unlock() -> void:
	var index := slot_count()
	if run == null or index >= DRUM_SLICES or run.drum_slot_price() <= 0:
		return
	var rect := slice_rect(index)
	var button := Button.new()
	button.name = "SliceUnlock"
	button.focus_mode = Control.FOCUS_NONE
	button.position = rect.position
	button.size = rect.size
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Scheibe %d freischalten: %d Energie" % [index + 1,
		run.drum_slot_price()]
	button.pressed.connect(_on_unlock_pressed)
	_content.add_child(button)
	_unlock_button = button
	_sync_unlock()

func _on_unlock_pressed() -> void:
	if run == null or editing_locked or burning():
		return
	run.buy_drum_slot()  # bucht und meldet press_changed - das baut neu

func _on_energy_changed(_value: int) -> void:
	_sync_unlock()

## Bezahlbar und bedienbar? Knopf und Preis-Farbe folgen.
func _sync_unlock() -> void:
	if run == null:
		return
	var open := run.can_buy_drum_slot() and not editing_locked and not burning()
	if _unlock_button != null and is_instance_valid(_unlock_button):
		_unlock_button.disabled = not open
	if _unlock_label != null and is_instance_valid(_unlock_label):
		_unlock_label.add_theme_color_override("font_color",
			ENERGY_COLOR if run.can_buy_drum_slot() else LOCKED_COLOR)

## EINE Scheibe: ein flacher Knopf ohne Fassung - Klick und Zeiger, sonst nichts.
func _slice_button(index: int, card: Dictionary) -> Button:
	var slot := Button.new()
	slot.name = "SeriesSlice%d" % (index + 1)
	slot.set_meta(&"sfx_silent", true)  # die Karte klingt selbst
	slot.focus_mode = Control.FOCUS_NONE
	slot.disabled = true
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		slot.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_arm_slot(slot, index, card)
	_slot_buttons.append(slot)
	return slot

## Ein Klick auf die belegte Stufe nimmt ihre Karte zurück ins Magazin, ein ZUG
## legt sie auf eine andere Stufe - dieselbe Trennung wie im Vorrat: gezogen
## sortiert um, getippt handelt.
func _arm_slot(slot: Button, index: int, card: Dictionary) -> void:
	if card.is_empty() or burning():
		return
	slot.disabled = editing_locked
	slot.tooltip_text = "%s\n%s" % [String(card.get("name", "")), String(card.get("body", ""))]
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.pressed.connect(clear_press_slot.bind(index))
	slot.gui_input.connect(_on_slot_input.bind(index))

## Die Sorten der gesteckten Karten, in Reihenfolge.
func press_slot_sorts() -> Array[String]:
	var sorts: Array[String] = []
	for card in _slot_cards():
		sorts.append(String(card.get("sort", "")))
	return sorts

## Die uids derselben Reihe, in Rechenreihenfolge (ohne Lücken; je Scheibe: slice_uids).
func press_slot_uids() -> Array[int]:
	var uids: Array[int] = []
	for card in _slot_cards():
		uids.append(int(card.get("uid", 0)))
	return uids

## Display-Pixel der SCHEIBEN-Mitten, je belegbarer Scheibe eine (leere
## eingeschlossen) - die Höhe der Karte darauf rechnet der Körper (DrumView).
func press_slot_anchors() -> Array[Vector2]:
	var anchors: Array[Vector2] = []
	for i in slot_count():
		anchors.append(_global(slice_rect(i)).get_center())
	return anchors

## Das Magazin ist zu: unterschrieben oder die Zeremonie läuft.
func shelf_locked() -> bool:
	return editing_locked or burning()

## Legt GENAU diese Karte auf die erste freie Scheibe. false = keine solche Karte, kein
## Platz frei oder das Magazin ist zu.
func slot_pack(uid: int) -> bool:
	if run == null or shelf_locked():
		return false
	var slot := _first_free_slot()
	if slot < 0:
		return false
	var pack := run.pack_by_uid(uid)
	if pack == null:
		return false
	if _series.has(uid) or _pending_arrivals.has(uid):
		return false
	_seat_series(uid, slot)
	refresh()
	return true

## Trägt die Karte auf ihrer Scheibe ein - die Serie bleibt nach Scheiben geordnet.
func _seat_series(uid: int, slot: int) -> void:
	var at := _series_slots.bsearch(slot)
	_series.insert(at, uid)
	_series_slots.insert(at, slot)

func _clear_series() -> void:
	_series.clear()
	_series_slots.clear()

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

## Nimmt die Karte von Scheibe index zurück ins Magazin - NUR sie: ihre Scheibe bleibt
## leer, keine andere rückt nach (Spieler-Wunsch 2026-11-22). Gemeldet wird VOR dem
## Neuaufbau: die Zelle muss sich ausklinken, bevor der Abgleich läuft.
func clear_press_slot(index: int) -> void:
	var at := _series_slots.find(index)
	if at < 0 or editing_locked or burning():
		return
	var uid := _series[at]
	_series.remove_at(at)
	_series_slots.remove_at(at)
	pack_unslotted.emit(index, uid)
	refresh()

## UMSORTIEREN, from und to sind SCHEIBEN: auf eine LEERE zieht nur diese Karte um, auf
## einer BELEGTEN TAUSCHEN die beiden (Spieler-Wunsch 2026-11-22) - keine dritte Karte
## bewegt sich. Die Reihenfolge IST die Rechnung.
func move_slot(from_index: int, to_index: int) -> void:
	if editing_locked or burning():
		return
	var from_at := _series_slots.find(from_index)
	if from_at < 0 or to_index < 0 or to_index >= slot_count() or to_index == from_index:
		return
	var to_at := _series_slots.find(to_index)
	var uid := _series[from_at]
	if to_at < 0:
		_series.remove_at(from_at)
		_series_slots.remove_at(from_at)
		_seat_series(uid, to_index)
	else:
		_series[from_at] = _series[to_at]
		_series[to_at] = uid
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
## Zeremonie sind es die des Prägens - die Karten selbst sind da längst verbraucht.
func _slot_cards() -> Array[Dictionary]:
	if burning():
		return _burning
	var cards: Array[Dictionary] = []
	if run == null:
		return cards
	for i in _series.size():
		var pack := run.pack_by_uid(_series[i])
		if pack != null:
			var card := card_data(_series[i], pack)
			card["slot"] = _series_slots[i]
			cards.append(card)
	return cards

## Die Anzeigedaten EINER Kassette - EINE Quelle für Schacht, Schirm und Zeremonie.
static func card_data(uid: int, pack: Pack) -> Dictionary:
	return {"uid": uid, "name": pack.display_name, "sort": Pack.shelf_of(pack),
		"tier": pack.tier, "net": pack.stamp_net, "operator": pack.operator_id,
		"glyph": StampNet.net_glyph(pack.stamp_net),
		"catalyst": pack.catalyst_id, "line": Pack.net_line(pack),
		"blank": pack.from_blank(), "body": pack.description}

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
	for i in range(_series.size() - 1, -1, -1):
		if run == null or run.pack_by_uid(_series[i]) == null:
			_series.remove_at(i)
			_series_slots.remove_at(i)
	var pool := pool_defs().size()
	if _chosen_index >= pool:
		_chosen_index = -1
	# Der Ziel-Rohling steckt NIE in der Reihe - sonst wäre er sein eigenes Futter.
	if _target_pack > 0:
		var own := _series.find(_target_pack)
		if own >= 0:
			_series.remove_at(own)
			_series_slots.remove_at(own)
		if target_pack() == null:
			_target_pack = 0

# --- Das PRÄGEN -------------------------------------------------------------------

## Der EINE Handlungs-Sitz neben dem Podest. Sein Rechteck ist in JEDEM
## Zustand dasselbe - der Sitz ist ein fester Platz, die Aufschrift wechselt.
func _build_action_seat(u: float) -> void:
	var seat := Control.new()
	seat.name = "ActionSeat"
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(seat)
	var rect := stamp_seat_rect()
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
		stamp_seat_rect().get_center().y - rect.size.y * 0.5)
	seat.size = rect.size

## Die AUFSCHRIFT des Prägens: gesteckte Karten und Serienlänge - der Zähler wohnt
## seit dem Tod des Serien-Schirms hier.
func stamp_label() -> String:
	var verb := "Verdichten" if compressing() else "Prägen"
	return "%s %d/%d" % [verb, _series.size(), slot_count()]

## Der Knopf auf dem Sitz. Zwei Zustände: das PRÄGEN und, solange die Serie sich
## entlädt, das Überspringen. Er steht IMMER - fehlt eine Zutat, steht er grau.
func _seat_button(u: float) -> Button:
	if burning():
		_action_button = _seat_fit(_action_button_new("Fertig", GOLD, u,
			skip_ceremony), u)
		return _action_button
	if press_spent():
		_action_button = _spent_button(u)
		return _action_button
	_action_button = _seat_fit(_action_button_new(stamp_label(), GOLD, u, pull_lever), u)
	_action_button.disabled = not can_pull()
	return _action_button

## Die Prägung der Runde ist verbraucht (und keine Erdungsklemme steckt): der Sitz wird
## zur roten ANZEIGE.
func press_spent() -> bool:
	return run != null and not compressing() and not burning() \
		and not run.series_press_allowed(_series)

func _spent_button(u: float) -> Button:
	var button := _seat_fit(_action_button_new(SPENT_TEXT, SPENT_COLOR, u, func() -> void: pass), u)
	button.name = "StampSpent"
	button.disabled = true
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	button.add_theme_color_override("font_disabled_color", SPENT_COLOR)
	button.add_theme_stylebox_override("disabled",
		_button_box(Color(SPENT_COLOR.r, SPENT_COLOR.g, SPENT_COLOR.b, 0.16), SPENT_COLOR))
	return button

## Darf jetzt geprägt werden? Ein gewählter Zielwürfel, mindestens EINE Karte
## (Spieler-Wunsch 2026-10-25), darunter eine, die prägt, und die Prägung der Runde
## ist noch frei (Spieler-Entscheid 2026-11-23; die Erdungsklemme prägt trotzdem).
func can_pull() -> bool:
	if run == null or editing_locked or burning():
		return false
	if _series.is_empty():
		return false
	if compressing():
		return not run.compressible_series(_series, _target_pack).has("blocker")
	if target_die() == null:
		return false
	return stamping_card_count() > 0 and run.series_press_allowed(_series)

## Zwingt einen Knopf auf das Sitzmaß: clip_text nimmt der Aufschrift das Recht,
## das Rechteck zu verbreitern.
func _seat_fit(button: Button, u: float) -> Button:
	button.clip_text = true
	button.custom_minimum_size = action_size(u)
	button.add_theme_font_size_override("font_size", action_font_size(u))
	return button

## Maße des Sitzes: EIN Rechteck für beide Aufschriften - der Platz, den die Kette
## neben dem Graben rechnet.
func action_size(_u: float) -> Vector2:
	return stamp_seat_rect().size

## Die Schrift des Sitzes wächst mit seiner Höhe, bis die breiteste Aufschrift
## („Verdichten 6/6“) gerade noch ungeschnitten hineinpaßt.
func action_font_size(u: float) -> int:
	var seat := action_size(u)
	var size_px := maxi(8, int(seat.y * ACTION_FONT_SHARE))
	var font := get_theme_font("font", "Button")
	if font == null:
		return size_px
	var room := seat.x - u * ACTION_TEXT_PAD * 2.0
	while size_px > 8 and font.get_string_size(ACTION_WIDEST, HORIZONTAL_ALIGNMENT_LEFT,
			-1, size_px).x > room:
		size_px -= 1
	return size_px

## WARUM das Prägen nicht zünden darf ("" = es darf). Die Bremsen stehen sonst
## stumm im Knopf: eine gesperrte Werkstatt, ein fehlendes Ziel, eine leere Reihe,
## eine Serie aus lauter Katalysatoren. Gefragt wird sie in der Reihenfolge, in der
## can_pull prüft - genannt wird die ERSTE geschlossene Bremse.
func stamp_blocker() -> String:
	if run == null or can_pull() or burning():
		return ""
	if editing_locked:
		return "Runde gezurrt - erst im Laden wieder."
	# Die ART des Ziels sagt, was der Knopf überhaupt tut - darum steht sie zuerst.
	if chosen_die() == null and not compressing():
		return "Kein Ziel: einen Vorrats-Würfel antippen oder einen %s auflegen." \
			% Pack.BLANK_NAME
	if _series.is_empty():
		return "Keine Karte in der Reihe."
	if compressing():
		match String(run.compressible_series(_series, _target_pack).get("blocker", "")):
			"empty":
				return "Keine Netz-Karte in der Reihe."
			"operator":
				return "Operatoren lassen sich nicht verdichten."
			"pointer":
				return "Pointer lassen sich nicht verdichten."
			"catalyst":
				return "Katalysatoren verdichten nicht - sie wirken auf einen Würfel."
			"compressed":
				return "Ein %s verdichtet nicht in den nächsten." % Pack.BLANK_NAME
		return ""
	if stamping_card_count() <= 0:
		return "Nur Katalysatoren - eine Netz-Karte fehlt."
	if not run.series_press_allowed(_series):
		return "Schon geprägt - die nächste Prägung gibt es in der nächsten Runde."
	return ""

# --- UPGRADES ------------------------------------------------------------------------

## Was UPGRADES zeigt: die SUMME der gesteckten Netze (zielunabhängig), ohne Netz das
## leere Kreuz.
func _sum_view_source() -> Dictionary:
	var nets := _sum_nets()
	if nets.is_empty():
		return {"mode": "empty"}
	return {"mode": "sum", "projection": SeriesResolver.resolve(nets, null, _sum_terms())}

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
	if run == null:
		return GameRun.catalyst_terms(slotted_packs())
	return run.series_terms(slotted_packs())

## Die Signatur der Quelle - nur ihr WECHSEL baut das Netz neu.
func _sum_view_signature() -> String:
	return "%s:%d:%d" % [str(_series), _burn_step, _burning.size()]

func _refresh_sum_net() -> void:
	if _sum_host == null or not is_instance_valid(_sum_host):
		return
	var signature := _sum_view_signature()
	if signature == _sum_signature:
		return
	_sum_signature = signature
	_sum_cell = net_cell(unit())
	if _sum_net_view != null and is_instance_valid(_sum_net_view):
		_sum_net_view.get_parent().remove_child(_sum_net_view)
		_sum_net_view.queue_free()
	_sum_net_view = null
	var source := _sum_view_source()
	_sum_mode = String(source.get("mode", "empty"))
	_sum_projection = source.get("projection", {})
	_sum_net_view = PressNetView.sum_net(_sum_projection, _sum_cell) if _sum_mode == "sum" \
		else _empty_net_cross(_sum_cell)
	_sum_host.add_child(_sum_net_view)

## Der Klartext einer Zelle von UPGRADES ({} = keine getroffen).
func _sum_hint_at(pixel: Vector2) -> Dictionary:
	if _sum_cell <= 0.0 or _sum_mode != "sum":
		return {}
	if _sum_net_view != null and is_instance_valid(_sum_net_view):
		var face := _face_in(_sum_net_view, pixel)
		if face >= 0:
			return {"hint": PressNetView.projection_hint(_sum_projection, face),
				"owner": SUM_OWNER}
	return {}

## Der Klartext einer Zelle der Karte, die das Verdichten ergäbe ({} = keine getroffen).
func _card_hint_at(pixel: Vector2) -> Dictionary:
	if _card_view == null or not is_instance_valid(_card_view) or die_view_mode() != "card":
		return {}
	var face := _face_in(_card_view, pixel)
	if face < 0:
		return {}
	return {"hint": StampNet.cell_hint(StampNet.cell_at(_card_net, face)),
		"owner": _owner_line(RESULT_OWNER, null)}

## Die Seite unter dem Pixel in einem gebauten Netz (-1 = keine).
func _face_in(view: Control, pixel: Vector2) -> int:
	var rect := view.get_global_rect()
	if not rect.has_point(pixel):
		return -1
	return DieNetView.face_at(pixel - rect.position, _sum_cell)

## Die überfahrene KARTE selbst (null = keine) - Walze vor Magazin, dieselbe
## Reihenfolge wie beim Netz. Der Info-Schirm braucht das PAKET, nicht den Namen.
func hover_pack() -> Pack:
	if run == null:
		return null
	var card := slot_card(_hover_slot)
	if not card.is_empty():
		var slotted := run.pack_by_uid(int(card.get("uid", 0)))
		if slotted != null:
			return slotted
	if _hover_pack_uid > 0:
		return run.pack_by_uid(_hover_pack_uid)
	return null

## Der NAME der überfahrenen Karte ("" = keine) - während der Zeremonie ist ihr
## Paket längst verbraucht, die Kartendaten kennen ihn trotzdem.
func hover_pack_name() -> String:
	var card := slot_card(_hover_slot)
	if not card.is_empty():
		return String(card.get("name", ""))
	if _hover_pack_uid > 0 and run != null:
		var pack := run.pack_by_uid(_hover_pack_uid)
		if pack != null:
			return pack.display_name
	return ""

## DAS PRÄGEN: EINE atomare Buchung in GameRun, dann die Zeremonie. Gemeldet wird
## press_started VOR dem Buchen (die Dekompression der Zellen braucht sie noch in
## ihren Schächten); series_applied kommt am ENDE der Zeremonie - gebucht ist da
## längst, es ist nur noch das Licht.
func pull_lever() -> void:
	if not can_pull():
		return
	if compressing():
		_pull_compress()
		return
	var cards := _slot_cards()
	var before := target_die().instantiate()
	var terms := run.series_terms(slotted_packs())
	var anchor := hand_anchor_px()
	press_started.emit()
	# VOR der Buchung: ihr synchrones pool_changed fragt held_faces() schon, und der
	# Podest-Würfel soll die ALTEN Augen behalten, bis der Strom einschlägt.
	_burn_die = before
	_burn_struck = false
	var result := run.apply_series(_series.duplicate(), target_die())
	if result.is_empty():
		_burn_die = null
		refresh()  # nichts gebucht: die Karten bleiben in ihren Schächten
		return
	_clear_series()
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

## Der Stand des Zielwürfels VOR dem Prägen (null = keine Zeremonie). scene_root malt
## ihn auf den Podest-Würfel zurück, bis der Strom einschlägt - sonst zeigte die
## Buchung die neuen Augen sofort.
func held_faces() -> DieDefinition:
	return _burn_die if burning() and not _burn_struck else null

## Die Kartendaten der laufenden Zeremonie - das Licht liest daraus Sorte und Größe.
func burning_cards() -> Array[Dictionary]:
	return _burning.duplicate()

## Die Projektion des laufenden Prägens (leer = keine) - daraus liest der Einschlag,
## welche Seite einen Bonus bekommen hat und darum ihren Funken bekommt.
func burn_projection() -> Dictionary:
	return _burn_result.get("projection", {}) if not _burn_result.is_empty() else {}

## Wie lange das VERRIEGELN dauert: eine Scheibe plus die Staffel über die übrigen.
func lock_time() -> float:
	return LOCK_TIME + LOCK_STAGGER * float(maxi(_burning.size(), 1) - 1)

## Die Fahrt des Bodens vor und nach dem Strom - beim Verdichten bleibt er zu.
func chamber_open_time() -> float:
	return 0.0 if compressing() else CHAMBER_OPEN_TIME

func chamber_close_time() -> float:
	return 0.0 if compressing() else CHAMBER_CLOSE_TIME

## Wie lange die ÜBERTRAGUNG dauert - scene_root staffelt daran nichts, aber ein Test
## darf sie abwarten.
func ceremony_time() -> float:
	var beats := 0.0
	for i in _burning.size():
		beats += card_beat(i)
	var strike := STRIKE_TIME + STRIKE_HOLD
	return chamber_open_time() + lock_time() + beats + strike + chamber_close_time()

## Der Takt EINER Scheibe - er IST die Laufzeit des Stroms zur nächsten: die RAMPE
## macht die späteren schneller, ein Operator bekommt seinen Sondermoment obendrauf.
func card_beat(index: int) -> float:
	var count := maxi(_burning.size(), 1)
	var share := 0.0 if count <= 1 else float(index) / float(count - 1)
	var beat := STREAM_STEP * lerpf(1.0, STREAM_RAMP, share)
	var card: Dictionary = _burning[index] if index >= 0 and index < _burning.size() else {}
	if String(card.get("glyph", "")) != "":
		beat += STREAM_OPERATOR_EXTRA
	return beat

## Die Netze der Karten, die der Strom SCHON aufgenommen hat - daran tickt das
## ERGEBNIS-Netz kartenweise hoch.
func _burn_nets_so_far() -> Array:
	var nets: Array = []
	for i in mini(maxi(_burn_step, 0), _burning.size()):
		if String(_burning[i].get("catalyst", "")) != "":
			continue  # ein Katalysator prägt nicht, er legt Terme bei
		nets.append(_burning[i].get("net", []))
	return nets

## DIE ÜBERTRAGUNG: die Kammer öffnet sich, die Scheiben verriegeln, der Strom läuft
## Scheibe um Scheibe nach rechts (jede Karte flammt auf, ihre Zellen dunkeln ab, die
## Summe tickt hoch, ein Operator schlägt perkussiv zu) und schlägt am Ende der Walze in
## den Würfel bzw. beim Verdichten in den Rohling; dann schließt die Kammer. Am Ende
## meldet das Fenster das Prägen, und scene_root räumt. Hier steht nur der TAKT.
func _play_series_ceremony(generation: int) -> void:
	var launched := run
	var opening := chamber_open_time()
	if opening > 0.0:
		chamber_opening.emit(opening)
		if not await _scan_wait(opening, generation, launched):
			return
	var lock := lock_time()
	slices_locked.emit(lock)
	if not await _scan_wait(lock, generation, launched):
		return
	for i in _burning.size():
		var beat := card_beat(i)
		_read_card(i, beat, beat)
		if not await _scan_wait(beat, generation, launched):
			return
	stream_struck.emit(STRIKE_TIME)
	if not await _scan_wait(STRIKE_TIME, generation, launched):
		return
	# Mit dem Einschlag springt ORIGINAL auf den gebuchten Stand - zusammen mit dem Würfel.
	_burn_struck = true
	_fill_podium()
	if not await _scan_wait(STRIKE_HOLD, generation, launched):
		return
	var closing := chamber_close_time()
	if closing > 0.0:
		chamber_closing.emit(closing)
		if not await _scan_wait(closing, generation, launched):
			return
	_end_ceremony()

## DAS VERDICHTEN: EINE atomare Buchung in GameRun, dann die Zeremonie - dieselbe
## Grammatik wie das Prägen. Gebucht ist vor dem Licht, und weil kein Würfel im Spiel
## ist, braucht es keinen Augen-Schnappschuß: der Rohling war leer.
func _pull_compress() -> void:
	var cards := _slot_cards()
	var anchor := hand_anchor_px()
	var blank := _target_pack
	press_started.emit()
	var result := run.compress_series(_series.duplicate(), blank)
	if result.is_empty():
		refresh()  # nichts gebucht: die Karten bleiben in ihren Schächten
		return
	_clear_series()
	_target_pack = 0  # gefüllt ist er kein Rohling mehr - die Wahl fällt mit
	_burning = cards
	_burn_blank = blank
	_burn_terms = {}
	_burn_result = result
	_burn_anchor = anchor
	_burn_step = 0
	_burn_gen += 1
	refresh()
	_refresh_preview_net(DRAIN_TIME)
	_play_series_ceremony(_burn_gen)

## Ein Takt der Fahrt. false = die Zeremonie gehört nicht mehr uns (übersprungen,
## Laufwechsel, Fenster fort) - der Aufrufer steigt dann sofort aus, und der EINE
## Aufräum-Pfad hat längst alles gerichtet.
func _scan_wait(time: float, generation: int, launched: GameRun) -> bool:
	if generation != _burn_gen or run != launched or not is_inside_tree():
		return false
	await get_tree().create_timer(maxf(time, 0.0)).timeout
	return generation == _burn_gen and run == launched and is_inside_tree() and burning()

## Der Strom hat Karte i erreicht: sie flammt auf, das ERGEBNIS-Netz
## übernimmt ihre Zellen (tickend) - und gemeldet wird, WELCHE Zellen sie hergibt,
## wie der Stand danach aussieht und wie lange das Licht zur nächsten Scheibe braucht.
func _read_card(index: int, tick: float, time: float) -> void:
	var card: Dictionary = _burning[index]
	var glyph := String(card.get("glyph", ""))
	var before := preview()
	_burn_step = index + 1
	var after := preview()
	_refresh_preview_net(maxf(tick, 0.01))
	_refresh_sum_net()  # die Summe tickt mit der Fahrt
	var faces := _moved_faces(before, after, card.get("net", []))
	var values: Array = after.get("bonus", [])
	stream_passed.emit(int(card.get("slot", index)), faces, values, glyph, time)

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
## Parkplatz - und ERST DANN wird das Prägen gemeldet (scene_root tötet daraufhin den
## Block und gibt jede noch fliegende Karte frei). Egal, wo die Zeremonie abbrach.
func _end_ceremony() -> void:
	if not burning():
		return
	var result := _burn_result
	var anchor := _burn_anchor
	# Das ERGEBNIS bleibt stehen: Stand VOR dem Prägen und die ganze Projektion - noch
	# aus der laufenden Zeremonie geholt, sie ist die Quelle. Das Netz zeigt daraus
	# die grünen Deltas.
	_result_die = _burn_die
	_result_projection = _full_projection()
	_burn_gen += 1
	_burning = []
	_burn_step = -1
	_burn_die = null
	_burn_struck = false
	_burn_blank = 0
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
	_clear_series()
	_burning = []
	_burn_step = -1
	_burn_die = null
	_burn_blank = 0
	_burn_terms = {}
	_burn_result = {}
	_chosen_index = -1
	_target_pack = 0
	_hover_slot = -1
	_hover_pack_uid = 0
	_drag_from = -1
	_burn_struck = false
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
	_refresh_sum_net()
	_fill_podium()
	_fill_preview()

## Display-Pixel der WALZE - von dort geht das Licht aus.
func hand_anchor_px() -> Vector2:
	return drum_pit_rect().get_center()

## Wo der Strom die Walze verläßt: an der rechten Grabenwand, auf halber Höhe.
func drum_end_px() -> Vector2:
	var pit := drum_pit_rect()
	return Vector2(pit.end.x, pit.get_center().y)

# --- Das Magazin (versiegelte Ware) ---------------------------------------------

## Das Magazin: vier Trays unter der Walze, je Sorte einer, je Paket seine eigene
## Kassette. Es ist die einzige Auslage versiegelter Ware.
func _build_drawer(u: float) -> void:
	_drawer = PackDrawerView.new()
	_drawer.pack_pressed.connect(_on_pack_pressed)
	_drawer.tidy_requested.connect(_on_tidy_requested)
	_drawer.scroll_dragged.connect(_on_scroll_dragged)
	_drawer.scroll_released.connect(_on_scroll_released)
	add_child(_drawer)  # direktes Kind: das Fach liegt neben dem Inhalt
	var rect := shelf_rect()
	_drawer.position = rect.position
	_drawer.size = rect.size
	_drawer.build(drawer_entries(), u, shelf_locked(), data_cell_px, rect.size,
		_shelf_scroll)
	if not _queued_pops.is_empty():
		_flush_queued_pops.call_deferred()  # der Pluster braucht das fertige Layout

## Der Platz des Magazins in Fenster-Koordinaten: das Sorten-Rechteck der Kette.
func shelf_rect() -> Rect2:
	return drum()["shelf"]

## Derselbe Platz in Display-Pixeln.
func shelf_rect_global() -> Rect2:
	return _global(shelf_rect())

## Das FELD des Magazins in Display-Pixeln: die Vereinigung der vier Gruben (dazwischen
## liegt Filz). Wer EIN Rechteck braucht - Kamera, Öffnungs-Rahmen -, nimmt dieses.
func shelf_pit_rect() -> Rect2:
	return PackDrawerView.field_in(shelf_rect_global())

## Die GRUBE des Trays column in Display-Pixeln - dort schneidet scene_root das Loch.
func shelf_column_rect(column: int) -> Rect2:
	var columns: Array = drum()["columns"]
	return _global(columns[clampi(column, 0, columns.size() - 1)])

## Die TRAYS samt Fassung und Leisten-Band in Display-Pixeln, links zuerst.
func shelf_tray_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for tray: Rect2 in drum().get("trays", []):
		rects.append(_global(tray))
	return rects

## Eckenradius des Lochs eines Trays (je Gerät).
func shelf_pit_radius(column: int) -> float:
	return PackDrawerView.PIT_RADII[clampi(column, 0, PackDrawerView.COLUMNS - 1)]

## Die Aufschrift der LICHTLEISTE eines Trays: Name und Gesamtzahl.
func shelf_bar_text(column: int) -> String:
	return PackDrawerView.bar_text(column, shelf_column_count(column))

## Wie viele REIHEN ein Tray belegt (mindestens das Fenster) - das Maß der Rollschiene.
func shelf_rows(column: int) -> int:
	return PackDrawerView.rows_for(shelf_column_count(column))

## Die Maßeinheit, in der das Magazin rechnet.
func shelf_unit() -> float:
	return unit()

## Das Zellmaß, an dem sich das Magazin misst (ohne gemeldetes das Rückfallmaß).
func shelf_cell_px() -> Vector2:
	if data_cell_px.x > 0.0 and data_cell_px.y > 0.0:
		return data_cell_px
	return PackDrawerView.fallback_cell(unit())

## Anzeige-Maßstab der Magazin-Kassetten (scene_root skaliert die Körper darauf).
func shelf_cell_scale() -> float:
	return PackDrawerView.CASSETTE_SCALE

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

## Je Paket {uid, pack, withheld, column, cell} in Magazin-Ordnung (= run.owned_packs).
## Was auf einer Scheibe liegt, fehlt ganz - seine Spalte schließt sich derweil; was
## noch als Licht fliegt, hält seinen Platz und bleibt bis zur Landung verdeckt.
## Die SPALTE ist die Sorte, der PLATZ der Rang darin (das SORTEN-MODELL des Laufs).
func drawer_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if run == null:
		return entries
	var fill: Dictionary = {}
	for pack in run.owned_packs:
		if _series.has(pack.pack_uid):
			continue
		var column := Pack.shelf_rank(pack)
		var cell_index := int(fill.get(column, 0))
		fill[column] = cell_index + 1
		# Der ROHLING auf dem Podest hat im Fach KEINEN Körper - sein Platz bleibt
		# stehen, wie der Pool-Sitz des Zielwürfels: ein Ding wird nie zweimal gezeigt.
		entries.append({"uid": pack.pack_uid, "pack": pack,
			"withheld": _pending_arrivals.has(pack.pack_uid)
				or pack.pack_uid == _target_pack
				or pack.pack_uid == _burn_blank,
			"column": column, "cell": cell_index})
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

## Der PLATZ einer Kassette (Display-Pixel) - auch hinausgerollt, dann eben unter
## dem Filz. Steht das Fach nicht, wird er GERECHNET (dieselbe Formel).
func pack_seat_px(uid: int) -> Vector2:
	# Gefragt wird, ob das Fach den Platz KENNT - weit hinausgerollt ist ein Platz
	# legitim NEGATIV (Bug 2026-10-26).
	if _drawer != null and is_instance_valid(_drawer) and _drawer.knows_pack(uid):
		return _drawer.pack_seat_px(uid)
	var pit := shelf_pit_rect()
	if pit.size.x > 0.0 and pit.size.y > 0.0:
		return PackDrawerView.anchor_in(pit, shelf_window_place_of(uid),
			shelf_cell_px(), shelf_column_of(uid))
	return shelf_rect_global().get_center()  # ohne Grube bleibt nur die Mitte

## Wohin das Liefer-Licht einer Kassette fliegt: auf ihren Platz, wenn er im Fenster
## liegt - sonst an den Rand ihrer Spalte auf der Seite, auf der er liegt.
func pack_anchor_px(uid: int) -> Vector2:
	if _drawer != null and is_instance_valid(_drawer) and _drawer.knows_pack(uid):
		return _drawer.pack_anchor_px(uid)
	return _anchor_for(shelf_column_of(uid), shelf_window_place_of(uid))

## Der Anker eines Platzes (im Fenster gezählt, Rang ab dem obersten sichtbaren) einer
## Spalte - die EINE Regel für gelandete wie für noch nicht eingelagerte Karten. Draußen
## liegt er am Rand, auf seinem Querplatz.
func _anchor_for(column: int, place: int) -> Vector2:
	var pit := shelf_pit_rect()
	var window := shelf_window_cards()
	var across := posmod(place, PackDrawerView.ACROSS)
	var seen := across if place < 0 else (window - PackDrawerView.ACROSS + across \
		if place >= window else place)
	var at := PackDrawerView.anchor_in(pit, seen, shelf_cell_px(), column)
	if place < 0:
		return Vector2(at.x, pit.position.y)
	if place >= window:
		return Vector2(at.x, pit.end.y)
	return at

## Der Platz eines Pakets in der Magazin-Ordnung (-1 = liegt nicht im Fach). Was in
## einer Scheibe der Walze liegt, zählt nicht mit - es liegt nicht im Magazin.
func pack_index_of(uid: int) -> int:
	var index := 0
	if run == null:
		return -1
	for pack in run.owned_packs:
		if _series.has(pack.pack_uid) and pack.pack_uid != uid:
			continue
		if pack.pack_uid == uid:
			return index
		index += 1
	return -1

## Der Eintrag einer Kassette im Fach ({} = keiner).
func _entry_of(uid: int) -> Dictionary:
	for entry in drawer_entries():
		if int(entry.get("uid", 0)) == uid:
			return entry
	return {}

## Die SPALTE (= Sorte), in der diese Kassette liegt.
func shelf_column_of(uid: int) -> int:
	if _drawer != null and is_instance_valid(_drawer):
		var line := _drawer.column_of_pack(uid)
		if line >= 0:
			return line
	var entry := _entry_of(uid)
	if entry.is_empty():
		var pack := run.pack_by_uid(uid) if run != null else null
		return Pack.shelf_rank(pack) if pack != null else 0
	return int(entry["column"])

## Ihr RANG in der Spalte (unter den Karten derselben Sorte im Fach).
func shelf_cell_of(uid: int) -> int:
	return int(_entry_of(uid).get("cell", 0))

## Ihr PLATZ im Fenster (Rang ab dem obersten sichtbaren) - der Roll-Stand ihrer Spalte,
## in ganzen Reihen, ist schon abgezogen.
func shelf_window_place_of(uid: int) -> int:
	if _drawer != null and is_instance_valid(_drawer) and _drawer.column_of_pack(uid) >= 0:
		return _drawer.place_of_pack(uid)
	return shelf_cell_of(uid) - shelf_scroll_of(shelf_column_of(uid)) * PackDrawerView.ACROSS

## Liegt sie im FENSTER ihrer Spalte (nicht hinausgerollt)?
func shelf_in_window(uid: int) -> bool:
	var place := shelf_window_place_of(uid)
	return place >= 0 and place < shelf_window_cards()

## Wie viele REIHEN das Fenster einer Spalte zeigt.
func shelf_places() -> int:
	return PackDrawerView.places_for(shelf_pit_rect().size, shelf_cell_px())

## Wie viele Karten das Fenster einer Spalte zeigt: Reihen mal ACROSS.
func shelf_window_cards() -> int:
	return shelf_places() * PackDrawerView.ACROSS

## Die Höhe EINER Reihe in Display-Pixeln - der Schritt, um den eine Spalte rollt.
func shelf_slot_px() -> float:
	return PackDrawerView.slot_size(shelf_pit_rect().size, shelf_cell_px()).y

## Wie viele Karten im Fach einer Spalte liegen (ohne die gesteckten).
func shelf_column_count(column: int) -> int:
	var count := 0
	for entry in drawer_entries():
		if int(entry.get("column", -1)) == column:
			count += 1
	return count

## Der ROLL-STAND einer Spalte in REIHEN.
func shelf_scroll_of(column: int) -> int:
	if column < 0 or column >= _shelf_scroll.size():
		return 0
	return _shelf_scroll[column]

## Setzt den Roll-Stand (Reihen), in den Grenzen 0 .. bis die letzte Reihe unten steht.
func set_shelf_scroll(column: int, places: int) -> void:
	if column < 0 or column >= _shelf_scroll.size():
		return
	var wanted := PackDrawerView.clamp_scroll(places, shelf_column_count(column),
		shelf_places())
	if _shelf_scroll[column] == wanted:
		return
	_shelf_scroll[column] = wanted
	refresh()

## Der Laufwechsel: jede Spalte steht wieder auf ihrem ersten Platz.
func reset_shelf_scroll() -> void:
	for column in _shelf_scroll.size():
		_shelf_scroll[column] = 0
	refresh()

## Gibt es oben bzw. unten hinausgerollte Karten? (x = oben, y = unten) - oben zählt,
## was dort wirklich LIEGT.
func shelf_overflow(column: int) -> Vector2i:
	var scroll := shelf_scroll_of(column) * PackDrawerView.ACROSS
	var used := shelf_column_count(column)
	return Vector2i(1 if mini(scroll, used) > 0 else 0,
		1 if used - scroll > shelf_window_cards() else 0)

## Die Sortenfarben einer Spalte, ein Eintrag je RANG (Reihe mal ACROSS plus Querplatz;
## leer stumpf) - jede LAMELLE liest ihre Reihe, auch hinausgerollt.
func shelf_column_tints(column: int) -> Array[Color]:
	var tints: Array[Color] = []
	var entries := drawer_entries()
	var count := 0
	for entry in entries:
		if int(entry.get("column", -1)) == column:
			count = maxi(count, int(entry.get("cell", 0)) + 1)
	var packs: Array[Pack] = []
	packs.resize(count)
	for entry in entries:
		if int(entry.get("column", -1)) != column:
			continue
		var place := int(entry.get("cell", 0))
		if place >= 0 and place < count:
			packs[place] = entry.get("pack") as Pack
	for pack in packs:
		if pack == null:
			tints.append(ShelfStackView.BAY_EMPTY)
			continue
		tints.append(PackDrawerView.card_shade(Pack.shelf_of(pack), pack.tier,
			pack.catalyst_id, pack.stamp_net, pack.from_blank()))
	return tints

## Der Platz, auf dem die NÄCHSTE Lieferung DIESES Pakets landet (extra staffelt eine
## Salve): seine Spalte ist seine Sorte, gefragt beim Lauf.
func arrival_anchor_px(pack: Pack, extra: int = 0) -> Vector2:
	if run == null or pack == null:
		return shelf_rect_global().get_center()
	var column := run.next_pack_spot(pack, extra).x
	# Gesteckte Karten liegen nicht im Fach - der Platz zählt nur, was dort liegt.
	var cell_index := shelf_column_count(column) + maxi(extra, 0)
	return _anchor_for(column, cell_index - shelf_scroll_of(column) * PackDrawerView.ACROSS)

## Eine Kassette wurde angetippt: sie wandert auf die nächste freie Scheibe - ein
## ROHLING dagegen aufs PODEST. Die Karte entscheidet, was der Tipp tut, genau wie
## das Ziel entscheidet, was der Knopf tut: ein Rohling als Futter trüge nichts bei.
func _on_pack_pressed(uid: int) -> void:
	if browse_only:
		return
	var pack := run.pack_by_uid(uid) if run != null else null
	if pack != null and pack.is_blank_card():
		if not shelf_locked():
			set_target_pack(pack)
		return
	slot_pack(uid)

## Ein Zug rollt eine Spalte: gemeldet wird der Versatz, schon in den Grenzen - am
## Ende liegt nichts außerhalb des Roll-Bereichs.
func _on_scroll_dragged(column: int, offset_px: float) -> void:
	_drag_column = column
	_last_drag_px = offset_px
	shelf_scrolling.emit(column, _clamp_scroll_px(column, offset_px))

## Losgelassen: der Roll-Stand rastet auf die nächste ganze Reihe und wird SOFORT
## gebucht (Endzustand zuerst) - der Körper fährt den Rest des Weges.
func _on_scroll_released(column: int, offset_px: float) -> void:
	var before := shelf_scroll_of(column)
	var from := _clamp_scroll_px(column, offset_px)
	var after := PackDrawerView.snap_scroll(before, from, shelf_slot_px(),
		shelf_column_count(column), shelf_places())
	set_shelf_scroll(column, after)
	shelf_scroll_snapped.emit(column, from, float(before - after) * shelf_slot_px())

## Ein Rad-Schritt rollt eine Spalte um ganze Reihen (true = sie hat sich bewegt).
func wheel_shelf(column: int, places: int) -> bool:
	if shelf_dragging():
		return false
	var before := shelf_scroll_of(column)
	set_shelf_scroll(column, before + places)
	var after := shelf_scroll_of(column)
	if after == before:
		return false
	shelf_scroll_snapped.emit(column, 0.0, float(before - after) * shelf_slot_px())
	return true

## Der Zug-Versatz: nach oben (weiter) unbegrenzt - die Spalte läuft ins Leere und
## federt beim Loslassen zurück -, nach unten nie vor den Anfang.
func _clamp_scroll_px(column: int, offset_px: float) -> float:
	return minf(offset_px, float(shelf_scroll_of(column)) * shelf_slot_px())

## Rollt gerade ein Zug über das Magazin?
func shelf_dragging() -> bool:
	return _drawer != null and is_instance_valid(_drawer) and _drawer.dragging()

## Doppelklick auf leere Fach-Fläche: aufräumen nach Sorte, Inhalt, uid.
func _on_tidy_requested() -> void:
	if run == null or shelf_locked() or browse_only:
		return
	run.tidy_packs()

# --- Auskunft --------------------------------------------------------------------

## Das HOVER-HIGHLIGHT je Bild: die überfahrene KARTE (Scheibe ODER Magazin) hebt
## ihre Beitrags-Zellen im ERGEBNIS-Netz hervor. GEFRAGT statt gemeldet - der Zeiger
## liegt auf dem Tisch, kein mouse_entered erreicht das Fenster.
## pack_uid/slot: wer schon weiß, welche Karte gehalten wird (der Spielraum des
## Zeigers, scene_root), meldet sie mit; -1 heißt: am Pixel nachsehen.
func sync_hover_at(pixel: Vector2, pack_uid := -1, slot := -1) -> void:
	_hover_pack_uid = pack_uid if pack_uid >= 0 else shelf_hover_uid_at(pixel)
	_set_hover_slot(slot if slot >= 0 else slot_at(pixel))
	_refresh_sum_net()  # nur der WECHSEL der Quelle baut neu

## Nur der WECHSEL baut das Netz neu - sync_hover_at läuft je Bild.
func _set_hover_slot(index: int) -> void:
	var wanted := -1 if slot_card(index).is_empty() else index
	if wanted == _hover_slot:
		return
	_hover_slot = wanted
	_refresh_preview_net()

## Erklärzeile zur Netz-Zelle unter einem Display-Pixel ("" = keine). GEFRAGT statt
## gemeldet: Godot reicht die erste Bewegung über einem Knopf nicht als gui_input
## durch, und wer genau dort stehen bleibt, bekäme nie einen Text.
func net_hint_at(pixel: Vector2) -> String:
	return String(_net_hint_info(pixel).get("hint", ""))

## WEM die getroffene Zelle gehört ("" = keine getroffen): UPGRADES die Summe der
## Serie, die Vorschau ihr Würfel ("Vorschau · Name"), die Die-View des Podests samt dem
## gezeigten Würfel ("Original · Name", "Ergebnis · Name"). Der Info-Schirm setzt das in
## seinen Titel.
func net_hint_owner_at(pixel: Vector2) -> String:
	return String(_net_hint_info(pixel).get("owner", ""))

## EIN Entscheider für beide Fragen: UPGRADES, die Vorschau, dann - solange keine Öffnung
## das Podest verdeckt - die Karte des Verdichtens bzw. die Die-View.
func _net_hint_info(pixel: Vector2) -> Dictionary:
	var summed := _sum_hint_at(pixel)
	if String(summed.get("hint", "")) != "":
		return summed
	var previewed := _face_hint(_preview_net, pixel)
	if previewed != "":
		return {"hint": previewed, "owner": _owner_line(PREVIEW_OWNER, preview_die())}
	if opening_shown:
		return {}
	var card := _card_hint_at(pixel)
	if String(card.get("hint", "")) != "":
		return card
	var shown := _face_hint(_net if _net_in_view() else _podium_net, pixel)
	if shown != "":
		return {"hint": shown, "owner": _owner_line(_view_owner(), shown_die())}
	return {}

## Der Besitzer der Die-View in Worten - dasselbe wie ihr Schild.
func _view_owner() -> String:
	return RESULT_OWNER if die_view_label() == "ERGEBNIS" else ORIGINAL_OWNER

## Der Klartext der Zelle eines Netzes unter dem Pixel ("" = keine).
static func _face_hint(net: PressNetView, pixel: Vector2) -> String:
	if net == null or not is_instance_valid(net) or net.def == null:
		return ""
	var face := net.face_at_pixel(pixel)
	return net.hint_for_face(face) if face != -1 else ""

static func _owner_line(role: String, die: DieDefinition) -> String:
	return "%s · %s" % [role, die.display_name] if die != null else role

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
	return CasinoStyle.flat_box(bg, border, u * 0.2, u * 0.9, u * 0.6)
