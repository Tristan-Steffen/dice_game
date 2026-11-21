class_name WorkshopView
extends Panel
## Die WERKSTATT unter dem Pool (Layout C, docs/plan_werkstatt_layout_c.md). Sie hat
## KEINEN Schirm-Hintergrund - ihre Teile liegen auf dem Filz. Rechts am Pool steht die
## GLEICHUNG in einer Zeile: UPGRADES + PODEST (Platte über der Kammer, darunter seine
## Die-View = ORIGINAL) = ERGEBNIS, über UPGRADES die Raster-Taste, über ERGEBNIS PRÄGEN.
## Unter dem Pool liest Zeile 1 die liegende WALZE (Scheibe 1 links), an ihrem Ende der
## INFO-SCHIRM; Zeile 2 das MAGAZIN über die volle Breite. Die Kette rechnet drum_layout;
## scene_root meldet sie.
##  - DIE WALZE ist ein Körper (DrumView); das Fenster MALT sie nicht, seine
##    unsichtbaren Scheiben-Knöpfe tragen Klick, Zug und Zeiger.
##  - Die drei Netze der Gleichung sind gleich groß und teilen die Zelle der Die-View
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
## Die Überschriften der Gleichung (ORIGINAL trägt keine - darüber steht die Platte).
const UPGRADES_HEAD := "UPGRADES"
const RESULT_HEAD := "ERGEBNIS"

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
## Die Leiterbahnen: Breite (u), Rand ihres Spur-Bands, Abdunklung, dunkler Grund.
const TRACE_WIDTH := 0.6
const TRACE_BAND_MARGIN := 0.15
const TRACE_DARKEN := 0.25
const TRACE_BED := Color(0.03, 0.03, 0.06, 0.9)

## Der EINE Handlungs-Sitz am RECHTEN Ende der Zeile, neben dem Podest: er trägt
## "Prägen n/m" (gesteckt / Serienlänge) bzw. "Fertig". EIN Maß für beide - der Sitz
## steht fest, nur seine Aufschrift wechselt, und die Grundseite fließt nie um.
## Bemessen an der breitesten Aufschrift ("Prägen 6/6") plus Rand.
const ACTION_WIDTH := 21.0
const ACTION_HEIGHT := 4.0
const ACTION_SPAN_SHARE := 0.5
const ACTION_FONT_SHARE := 0.5
const ACTION_TEXT_PAD := 1.0
const ACTION_WIDEST := "Verdichten 6/6"

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
		_pending_arrivals.clear()  # Lieferungen des alten Laufs verfallen
		_queued_pops.clear()
		_drop_series()  # eine Serie des alten Laufs schuldet nichts mehr
		_shelf_scroll.fill(0)  # ein neuer Lauf beginnt auf dem ersten Platz
		run = value
		if run != null:
			run.packs_changed.connect(refresh)
			run.pool_changed.connect(refresh)  # die Gleichung zeigt den Pool
			run.press_changed.connect(refresh)  # eine Buchung räumt die Reihe
		refresh()

var _content: Control
## Das ERGEBNIS-Netz mit Ziel. Es überlebt jeden Neuaufbau (es ist kein Kind des
## Inhalts): sein ZÄHL-Takt darf nicht daran zerbrechen, daß eine Kassette
## umsortiert wird - nur so tickt es beim Prägen von der Vorschau herunter.
var _net: PressNetView
## Sein PARKPLATZ im ERGEBNIS-Schirm: ein leerer Platz in Netzgröße, auf den es je
## Bild zurückgesetzt wird.
var _net_host: Control
## Der Platz auf dem PODEST, seine Die-View und das Netz darin.
var _podium_stage_host: Control
var _podium_view_host: Control
var _podium_net: PressNetView
## ORIGINAL: der Platz und das Netz darin (PressNetView ohne Vorschau oder leeres Kreuz).
## Haben die Funken schon eingeschlagen? Ab da zeigt ORIGINAL den gebuchten Stand.
var _burn_struck := false
## Die SCHEIBEN-Knöpfe: je Scheibe einer, der Klick, Zug und Zeiger fängt - die
## WALZE darunter ist ein Körper (DrumView) und trägt nichts davon.
var _slot_buttons: Array[Button] = []
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
## ERGEBNIS ohne Würfel-Ziel: die Karte, die das Verdichten ergäbe, sonst das leere Kreuz.
var _result_host: Control
var _result_view: Control
## Was beide gerade zeigen - Signatur (nur der WECHSEL baut neu), Quelle und Inhalt,
## damit die Zell-Frage sie beantworten kann.
var _sum_signature := ""
var _sum_mode := ""
var _sum_projection: Dictionary = {}
var _result_mode := ""
var _result_source_net: Array = []
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
	_podium_stage_host = null
	_podium_view_host = null  # die Die-View des Podests hing am Inhalt
	_podium_net = null
	_net_host = null
	# Ein Neuaufbau mitten im Zug läßt ihn einrasten, statt ihn hängen zu lassen.
	if shelf_dragging():
		_on_scroll_released.call_deferred(_drag_column, _last_drag_px)
	_free_own(_drawer)  # das Magazin hängt am Panel, nicht am Inhalt
	_drawer = null
	_sum_host = null  # UPGRADES und ERGEBNIS hingen am Inhalt
	_sum_net_view = null
	_result_host = null
	_result_view = null
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
	if not burning():
		_refresh_preview_net()
	_sync_sum_net_park()

## Sein Platz: die Mitte des Parkplatzes im ERGEBNIS-Schirm.
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

## UPGRADES: die Summe der Serie, links neben dem Podest.
func upgrades_net_rect() -> Rect2:
	return drum()["upgrades"]

## ERGEBNIS: Vorschau bzw. Ergebnis, beim Verdichten die Karte, die herauskäme.
func result_net_rect() -> Rect2:
	return drum()["result"]

## Der INFO-SCHIRM am Ende der Walze, in Display-Pixeln.
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

## Der Präge-Sitz in Display-Pixeln.
func stamp_seat_px() -> Rect2:
	return _global(stamp_seat_rect())

## Die GLEICHUNGS-ZEILE rechts am Pool in Display-Pixeln: Raster-Feld, UPGRADES, Podest,
## ERGEBNIS und Präge-Sitz.
func equation_area_px() -> Rect2:
	return _global(drum()["equation"])

## Das freie Feld über UPGRADES, in dem die RASTER-Taste mittig steht (Display-Pixel).
func raster_area_px() -> Rect2:
	return _global(drum()["raster"])

## Was die Werkstatt in Display-Pixeln bedient: die Walze samt Nummern, der Info-Schirm,
## die vier Trays des Magazins, die Netze der Gleichung samt Überschriften, das Podest
## und der Präge-Sitz - der Filz dazwischen nicht, und die Raster-Taste ist ein eigener
## Körper.
func hit_rects() -> Array[Rect2]:
	var layout := drum()
	var pit: Rect2 = layout["pit"]
	var drum_row := pit.grow_individual(0.0, unit() * (SLICE_NUMBER_UNITS + SLICE_NUMBER_GAP),
		0.0, 0.0)
	var nets := (layout["upgrades"] as Rect2).merge(layout["result"]) \
		.grow_individual(0.0, unit() * EQ_HEAD_UNITS, 0.0, 0.0)
	var rects: Array[Rect2] = [_global(drum_row), info_rect_px(), _global(nets),
		podium_rect_px(), stamp_seat_px()]
	rects.append_array(shelf_tray_rects())
	return rects

## Der PRÄGE-SITZ über ERGEBNIS, rechts neben der Platte.
func stamp_seat_rect() -> Rect2:
	return drum()["stamp"]

## Steht gerade eine PAKET-ÖFFNUNG? Dann sind "=", ERGEBNIS und PRÄGEN fort (scene_root
## meldet es; die Öffnungs-Fläche liegt dort).
var opening_shown := false:
	set(value):
		if opening_shown == value:
			return
		opening_shown = value
		_sync_result_side()

## "=", ERGEBNIS samt Überschrift und PRÄGEN stehen nur, solange keine Öffnung ihren Platz
## braucht - ausgeblendet nehmen sie auch keinen Klick.
func _sync_result_side() -> void:
	if _content == null or not is_instance_valid(_content):
		return
	for node_name in ["EqualsSign", "ResultScreen", "ResultScreenHead", "ActionSeat"]:
		var node := _content.get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.visible = not opening_shown
	if _net != null and is_instance_valid(_net):
		_net.visible = not opening_shown

func _build_street(u: float) -> void:
	_build_traces(u)  # zuerst: die Bahnen liegen unter allem
	_build_podium(u)
	_build_equation(u)
	_build_slices(u)
	_build_action_seat(u)
	_sync_result_side()

## DIE LEITERBAHNEN: von jeder belegten Scheibe eine matte Bahn in der Farbe ihrer Karte
## zum UPGRADES-Netz - gemalt auf den Filz zwischen Walze und Gleichung.
func _build_traces(u: float) -> void:
	var layout := drum()
	var paths := trace_paths(layout["slices"], layout["upgrades"], layout["trace_band"])
	var cards := _slot_cards()
	var layer := TraceLayer.new()
	layer.name = "Traces"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.width = maxf(u * TRACE_WIDTH, 1.5)
	for i in mini(cards.size(), paths.size()):
		var card: Dictionary = cards[i]
		layer.paths.append(paths[i])
		layer.tints.append(PackDrawerView.tint_of(String(card.get("sort", "")),
			String(card.get("catalyst", "")), card.get("net", []), bool(card.get("blank", false))))
	_content.add_child(layer)

## Je Scheibe ein Linienzug: senkrecht aus der Nummern-Zeile, mit 45°-Knick auf ihre Spur,
## quer zum Netz, mit 45°-Knick hinauf in seine Unterkante. Wer weiter weg startet, fährt
## die höhere Spur - so kreuzt keine Bahn eine andere.
static func trace_paths(slices: Array, upgrades: Rect2, band: Rect2) -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	var count := slices.size()
	if count == 0 or band.size.y <= 0.0:
		return paths
	var starts: Array[float] = []
	var ends: Array[float] = []
	for i in count:
		starts.append((slices[i] as Rect2).get_center().x)
		var share := 0.5 if count == 1 else float(i) / float(count - 1)
		ends.append(upgrades.position.x + upgrades.size.x * (0.2 + 0.6 * share))
	var margin := band.size.y * TRACE_BAND_MARGIN
	var pitch := (band.size.y - margin * 2.0) / float(maxi(count - 1, 1))
	var right_rank := 0
	var ranks: Array[int] = []
	ranks.resize(count)
	for i in count:
		if starts[i] <= ends[i]:
			ranks[i] = right_rank
			right_rank += 1
	var left_rank := 0
	for i in range(count - 1, -1, -1):
		if starts[i] > ends[i]:
			ranks[i] = left_rank
			left_rank += 1
	for i in count:
		var lane := band.position.y + margin + pitch * float(ranks[i])
		var way := signf(ends[i] - starts[i])
		var bend := minf(pitch, absf(ends[i] - starts[i]) * 0.5)
		paths.append(PackedVector2Array([
			Vector2(starts[i], band.end.y), Vector2(starts[i], lane + bend),
			Vector2(starts[i] + way * bend, lane), Vector2(ends[i] - way * bend, lane),
			Vector2(ends[i], lane - bend), Vector2(ends[i], upgrades.end.y)]))
	return paths

## Die gemalten Bahnen: dunkler Grund, matte Farbe, an beiden Enden ein Lötauge.
class TraceLayer extends Control:
	var paths: Array[PackedVector2Array] = []
	var tints: Array[Color] = []
	var width := 2.0

	func _draw() -> void:
		for i in paths.size():
			var tint := tints[i].darkened(TRACE_DARKEN)
			tint.a = 1.0
			draw_polyline(paths[i], TRACE_BED, width * 2.4, true)
			draw_polyline(paths[i], tint, width, true)
			for point: Vector2 in [paths[i][0], paths[i][paths[i].size() - 1]]:
				draw_circle(point, width * 2.2, TRACE_BED)
				draw_circle(point, width * 1.7, tint)
				draw_circle(point, width * 0.7, TRACE_BED)

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

## Ein Netz-Schirm der Gleichung mit einem leeren Platz in Netzgröße, mittig, und seiner
## Überschrift darüber.
func _net_screen(screen_name: String, rect: Rect2, cell: float, heading: String) -> Control:
	if heading != "":
		_net_heading(screen_name, rect, heading)
	var screen := Panel.new()
	screen.name = screen_name
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override("panel", TableScreen.window_style())
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

## Die Überschrift über einem Schirm.
func _net_heading(screen_name: String, rect: Rect2, heading: String) -> void:
	var u := unit()
	var head := Label.new()
	head.name = "%sHead" % screen_name
	head.text = heading
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.position = Vector2(rect.position.x, rect.position.y - u * EQ_HEAD_UNITS)
	head.size = Vector2(rect.size.x, u * EQ_HEAD_UNITS)
	head.add_theme_font_size_override("font_size", maxi(8, int(u * EQ_HEAD_FONT)))
	head.add_theme_color_override("font_color", MUTED_COLOR)
	_content.add_child(head)

## DAS PODEST: oben die Platte über der Kammer (der Puck gehört scene_root), unten seine
## DIE-VIEW = ORIGINAL - der Würfel, der dort steht, schlicht; ohne ihn das leere Kreuz.
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
	_podium_view_host = _net_screen("PodiumScreen", layout["podium_net"], podium_cell(), "")
	_fill_podium()

## ORIGINAL: während der Zeremonie der Stand davor - erst der Einschlag deckt den gebuchten
## auf -, sonst der Würfel auf dem Podest.
func _fill_podium() -> void:
	if _podium_view_host == null or not is_instance_valid(_podium_view_host):
		return
	for child in _podium_view_host.get_children():
		_podium_view_host.remove_child(child)
		child.queue_free()
	_podium_net = null
	var cell := podium_cell()
	var die := before_die() if before_die() != null else seated_die()
	if die == null:
		_podium_view_host.add_child(_empty_net_cross(cell))
		return
	_podium_net = PressNetView.new()
	_podium_net.cell = cell
	_podium_net.def = die
	_podium_net.build()
	_podium_view_host.add_child(_podium_net)

## Die Zelle der Die-View: die Fläche eines echten Würfels - aus der gemeldeten Kette
## gelesen, denn reicht die Pool-Höhe nicht, schrumpft sie dort.
func podium_cell() -> float:
	var net: Rect2 = drum()["podium_net"]
	var cell := (net.size.y - unit() * PODIUM_NET_PAD * 2.0) / DieNetView.net_size(1.0).y
	if cell > 0.0:
		return cell
	return (die_face_px if die_face_px > 0.0 else unit() * U_PER_FACE) * PODIUM_FACE_GAIN

## Ein gemaltes Zeichen der Gleichung ("+" bzw. "=") mittig in seinem Feld.
func _equation_sign(sign_name: String, rect: Rect2, glyph: String) -> void:
	var sign := Label.new()
	sign.name = sign_name
	sign.text = glyph
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sign.position = rect.position
	sign.size = rect.size
	sign.add_theme_font_size_override("font_size", maxi(10, int(unit() * EQ_SIGN_FONT)))
	sign.add_theme_color_override("font_color", TEXT_COLOR)
	_content.add_child(sign)

## DIE GLEICHUNG: UPGRADES + ORIGINAL (die Die-View des Podests) = ERGEBNIS.
func _build_equation(u: float) -> void:
	var cell := net_cell(u)
	var layout := drum()
	_sum_host = _net_screen("UpgradesScreen", layout["upgrades"], cell, UPGRADES_HEAD)
	var signs: Array = layout["signs"]
	_equation_sign("PlusSign", signs[0], "+")
	_equation_sign("EqualsSign", signs[1], "=")
	var host := _net_screen("ResultScreen", layout["result"], cell, RESULT_HEAD)
	# Der PARKPLATZ des Netzes bleibt ein leerer Platz - die Ergebnis-Karte hängt daneben.
	var park := Control.new()
	park.name = "Park"
	park.mouse_filter = Control.MOUSE_FILTER_IGNORE
	park.position = host.position
	park.size = host.size
	host.get_parent().add_child(park)
	_net_host = park
	_result_host = host
	_sum_signature = ""
	_refresh_sum_net()

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

## Das EINE Zellmaß der Gleichung: die drei Netze sind gleich groß, also teilen UPGRADES
## und ERGEBNIS die Zelle der Die-View.
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

## Sechs Scheiben, Scheibe 1 links - der Deckel der Serie.
const DRUM_SLICES := 6
## Luft der Karte in ihrer Scheibe, Anteil ihres Maßes (quer und längs).
const DRUM_AIR := 0.06
## Luft QUER zur Achse: sie ist die Wand neben der Karte, also die Tiefe der Mulde.
const DRUM_SIDE_AIR := 0.12
## Fuge zwischen Pool und Gleichung und zwischen Walze und Magazin, in u.
const DRUM_SHELF_GAP := 4.0
## Rand der PLATTE um die Kammer, in u je Seite (oben kommt der Kopf des Würfels dazu).
const PODIUM_RIM := 2.0
## Rand der Podest-Die-View um ihr Netz, in u je Seite.
const PODIUM_NET_PAD := 2.0
## Ein schwebender Würfel steht näher an der Kamera und liest größer als sein Maß auf
## dem Glas - gemessen an der Werkstatt-Station (Pool-Teilung 60 gegen 51 Bildschirm-px).
## Reicht die Pool-Höhe nicht, schrumpft dieser Faktor, nie die Kammer.
const PODIUM_FACE_GAIN := 1.17
## Die Gleichung: Breite der Zeichen-Felder, Überschrift, Grade (u).
const EQ_SIGN_UNITS := 7.0
const EQ_HEAD_UNITS := 4.5
const EQ_HEAD_FONT := 3.2
const EQ_SIGN_FONT := 8.0

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
## Rechts am Pool (oben bündig, eine Fuge daneben) die GLEICHUNG: UPGRADES + PODEST =
## ERGEBNIS, die Netze gleich groß und unten bündig, darüber das Raster-Feld bzw. PRÄGEN.
## Unter dem Pool (eine Naht pool_seam darunter, linksbündig): die Nummern, der Graben mit
## den sechs Scheiben, eine Naht rechts daneben der Info-Schirm in Grabenhöhe; eine Fuge
## tiefer das Magazin aus vier Trays (columns = ihre Gruben, trays = samt Fassung), rechts
## bündig mit dem Info-Schirm.
## bounds ist das Fenster: Walze, Info-Schirm und Magazin - die Gleichung liegt außerhalb.
static func drum_layout(pool: Rect2, card: Vector2, die_face: float,
		u: float, _info_h := 0.0, pool_seam := -1.0) -> Dictionary:
	var seam := u * STREET_GAP
	var gap := u * DRUM_SHELF_GAP
	var below := pool_seam if pool_seam >= 0.0 else seam
	var numbers := u * (SLICE_NUMBER_UNITS + SLICE_NUMBER_GAP)
	# Auf Kante gedreht braucht der Vierkant seine Diagonale.
	var high := drum_side_px(card) * sqrt(2.0) + seam
	var pitch := slice_length_px(card) + seam
	var pit := Rect2(Vector2(pool.position.x, pool.end.y + below + numbers),
		Vector2(pitch * float(DRUM_SLICES), high))
	var slices: Array[Rect2] = []
	for i in DRUM_SLICES:
		slices.append(Rect2(Vector2(pit.position.x + seam * 0.5 + pitch * float(i),
			pit.position.y), Vector2(slice_length_px(card), high)))
	var shelf := Rect2(Vector2(pool.position.x, pit.end.y + gap),
		PackDrawerView.shelf_for(card))
	var field := PackDrawerView.field_in(shelf)
	# Je SORTE ein Tray: seine Grube (columns) und samt Fassung (trays), EINE Quelle.
	var columns: Array[Rect2] = []
	var trays: Array[Rect2] = []
	for lane in PackDrawerView.column_rects(field.size):
		var hole := Rect2(field.position + lane.position, lane.size)
		columns.append(hole)
		trays.append(PackDrawerView.tray_of(hole))
	var info_left := pit.end.x + seam
	var info := Rect2(Vector2(info_left, pit.position.y),
		Vector2(maxf(shelf.end.x - info_left, 1.0), pit.size.y))
	var top := Rect2(Vector2(pit.position.x, pit.position.y - numbers), Vector2(pit.size.x,
		numbers))
	var bounds := top.merge(pit).merge(shelf).merge(info)
	# DIE GLEICHUNG rechts am Pool: das Podest in der Mitte, seine Die-View ist ORIGINAL.
	var plate_size := podium_plate_size(die_face, u)
	var gain := podium_gain(pool.size.y, die_face, u)
	var net_span := podium_net_size(card, die_face, u, gain)
	# Die Platte ist so breit wie die Die-View darunter (Spieler-Wunsch 2026-11-20).
	plate_size.x = maxf(plate_size.x, net_span.x)
	var sign_w := u * EQ_SIGN_UNITS
	var head_h := u * EQ_HEAD_UNITS
	var upgrades_x := pool.end.x + gap
	var podium := Rect2(Vector2(upgrades_x + net_span.x + sign_w, pool.position.y),
		Vector2(maxf(net_span.x, plate_size.x), plate_size.y + seam + net_span.y))
	var podium_stage := Rect2(Vector2(podium.get_center().x - plate_size.x * 0.5,
		pool.position.y), plate_size)
	# Die KAMMER ist so groß wie die Platte (Spieler-Wunsch 2026-11-20); ihre Mitte ist
	# der Anker des Würfels.
	var chamber := podium_stage
	var podium_net := Rect2(Vector2(podium.get_center().x - net_span.x * 0.5,
		podium_stage.end.y + seam), net_span)
	var row_y := podium_net.position.y
	var upgrades := Rect2(Vector2(upgrades_x, row_y), net_span)
	var plus := Rect2(Vector2(upgrades.end.x, row_y), Vector2(sign_w, net_span.y))
	var equals := Rect2(Vector2(podium.end.x, row_y), Vector2(sign_w, net_span.y))
	var result := Rect2(Vector2(equals.end.x, row_y), net_span)
	# Raster-Taste und PRÄGEN stehen auf halber Plattenhöhe über ihren Netzen, im Filz
	# zwischen Pool-Oberkante und Überschrift.
	var mid_y := podium_stage.get_center().y
	var reach := maxf(minf(mid_y - pool.position.y, row_y - head_h - mid_y), 1.0)
	var raster := Rect2(Vector2(upgrades.position.x, mid_y - reach), Vector2(net_span.x,
		reach * 2.0))
	var stamp_area := Rect2(Vector2(result.position.x, mid_y - reach), raster.size)
	var stage := die_face * STAGE_FACES
	var action := Vector2(u * ACTION_WIDTH, maxf(stage * ACTION_SPAN_SHARE, u * ACTION_HEIGHT))
	var stamp := Rect2(stamp_area.get_center() - action * 0.5, action)
	# Das Spur-Band der Leiterbahnen: der Filz zwischen Pool bzw. Netzen und den Nummern.
	var band_top := maxf(pool.end.y, upgrades.end.y)
	var trace_band := Rect2(Vector2(pit.position.x, band_top),
		Vector2(pit.size.x, maxf(top.position.y - band_top, 0.0)))
	var equation := Rect2(Vector2(upgrades.position.x, pool.position.y),
		Vector2(result.end.x - upgrades.position.x, podium.size.y))
	return {"pit": pit, "slices": slices, "chamber": chamber, "stamp": stamp,
		"shelf": shelf, "columns": columns, "trays": trays, "info": info,
		"original": podium_net,
		"upgrades": upgrades, "result": result, "signs": [plus, equals] as Array[Rect2],
		"equation": equation, "raster": raster, "podium": podium, "trace_band": trace_band,
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
	var cards := _slot_cards()
	if _hover_slot < 0 or _hover_slot >= cards.size():
		return [] as Array[int]
	var faces: Array[int] = []
	var net: Array = cards[_hover_slot].get("net", [])
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

## Wie viele Scheiben die Serie belegt: die Serienlänge des Laufs, mindestens so viele,
## wie gerade stecken - höchstens die Scheiben der Walze.
func slot_count() -> int:
	var slots := run.series_slots() if run != null else FALLBACK_SLOTS
	return mini(maxi(slots, _slot_cards().size()), DRUM_SLICES)

## Der Fußabdruck der LIEGENDEN Kassette in Fenster-Pixeln, in der EINEN Größe, die
## sie überall hat: Langseite waagerecht, Breite nach unten. Gemeldet wird nur die
## STEHENDE Zelle, die Langseite folgt aus dem Seitenverhältnis der Karte.
func lie_span_px() -> Vector2:
	return PackDrawerView.lie_cell(shelf_cell_px())

## DIE SCHEIBEN BAUEN: je Scheibe ein unsichtbarer Knopf über dem Graben (dort ist
## die Anzeige ohnehin fortgeschnitten), darüber ihre Nummer.
func _build_slices(u: float) -> void:
	var cards := _slot_cards()
	for i in slot_count():
		var card: Dictionary = cards[i] if i < cards.size() else {}
		var rect := slice_rect(i)
		var seat := _slice_button(i, card)
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
			TEXT_COLOR if i < cards.size() else MUTED_COLOR)
		_content.add_child(number)

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
## Zeremonie sind es die des Prägens - die Karten selbst sind da längst verbraucht.
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
	var kept: Array[int] = []
	for uid in _series:
		if run != null and run.pack_by_uid(uid) != null:
			kept.append(uid)
	_series = kept
	var pool := pool_defs().size()
	if _chosen_index >= pool:
		_chosen_index = -1
	# Der Ziel-Rohling steckt NIE in der Reihe - sonst wäre er sein eigenes Futter.
	if _target_pack > 0:
		_series.erase(_target_pack)
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
	_action_button = _seat_fit(_action_button_new(stamp_label(), GOLD, u, pull_lever), u)
	_action_button.disabled = not can_pull()
	return _action_button

## Darf jetzt geprägt werden? Ein gewählter Zielwürfel, mindestens EINE Karte
## (Spieler-Wunsch 2026-10-25) und darunter eine, die prägt.
## Prägen selbst ist unbegrenzt (Spieler-Entscheid 2026-09-05).
func can_pull() -> bool:
	if run == null or editing_locked or burning():
		return false
	if _series.is_empty():
		return false
	if compressing():
		return not run.compressible_series(_series, _target_pack).has("blocker")
	if target_die() == null:
		return false
	return stamping_card_count() > 0

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
	return ""

# --- UPGRADES und ERGEBNIS ohne Würfel-Ziel ------------------------------------------

## Was UPGRADES zeigt: die SUMME der gesteckten Netze (zielunabhängig), ohne Netz das
## leere Kreuz.
func _sum_view_source() -> Dictionary:
	var nets := _sum_nets()
	if nets.is_empty():
		return {"mode": "empty"}
	return {"mode": "sum", "projection": SeriesResolver.resolve(nets, null, _sum_terms())}

## Was ERGEBNIS ohne Würfel-Ziel zeigt - EIN Entscheider: mit Würfel-Ziel nichts (dort
## steht das Vorschau-Netz), beim Verdichten die Karte, die herauskäme, sonst das leere
## Kreuz.
func _result_view_source() -> Dictionary:
	if preview_target() != null:
		return {"mode": "die"}
	var nets := _sum_nets()
	# Verdichten ist eine ANDERE Rechnung als Prägen (Faktoren addieren).
	if compressing() and not nets.is_empty():
		return {"mode": "card", "net": SeriesResolver.compress(nets)["net"]}
	return {"mode": "empty"}

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

## Die Signatur der Quellen - nur ihr WECHSEL baut die Netze neu.
func _sum_view_signature() -> String:
	return "%s:%s:%d:%d:%s" % [str(preview_target() != null), str(_series), _burn_step,
		_burning.size(), str(compressing())]

func _refresh_sum_net() -> void:
	if _sum_host == null or not is_instance_valid(_sum_host):
		return
	var signature := _sum_view_signature()
	if signature == _sum_signature:
		return
	_sum_signature = signature
	_sum_cell = net_cell(unit())
	for view: Control in [_sum_net_view, _result_view]:
		if view != null and is_instance_valid(view):
			view.get_parent().remove_child(view)
			view.queue_free()
	_sum_net_view = null
	_result_view = null
	var source := _sum_view_source()
	_sum_mode = String(source.get("mode", "empty"))
	_sum_projection = source.get("projection", {})
	_sum_net_view = PressNetView.sum_net(_sum_projection, _sum_cell) if _sum_mode == "sum" \
		else _empty_net_cross(_sum_cell)
	_sum_host.add_child(_sum_net_view)
	var result := _result_view_source()
	_result_mode = String(result.get("mode", "empty"))
	_result_source_net = result.get("net", [])
	if _result_mode == "die" or _result_host == null or not is_instance_valid(_result_host):
		return
	_result_view = PressNetView.stamp_net(_result_source_net, _sum_cell) \
		if _result_mode == "card" else _empty_net_cross(_sum_cell)
	_result_host.add_child(_result_view)

## Der Klartext einer Zelle von UPGRADES bzw. der Ergebnis-Karte ({} = keine getroffen).
func _sum_hint_at(pixel: Vector2) -> Dictionary:
	if _sum_cell <= 0.0:
		return {}
	if _sum_mode == "sum" and _sum_net_view != null and is_instance_valid(_sum_net_view):
		var face := _face_in(_sum_net_view, pixel)
		if face >= 0:
			return {"hint": PressNetView.projection_hint(_sum_projection, face),
				"owner": SUM_OWNER}
	if _result_mode == "card" and _result_view != null and is_instance_valid(_result_view):
		var face := _face_in(_result_view, pixel)
		if face >= 0:
			return {"hint": StampNet.cell_hint(StampNet.cell_at(_result_source_net, face)),
				"owner": RESULT_OWNER}
	return {}

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
	var cards := _slot_cards()
	if _hover_slot >= 0 and _hover_slot < cards.size():
		var slotted := run.pack_by_uid(int(cards[_hover_slot].get("uid", 0)))
		if slotted != null:
			return slotted
	if _hover_pack_uid > 0:
		return run.pack_by_uid(_hover_pack_uid)
	return null

## Der NAME der überfahrenen Karte ("" = keine) - während der Zeremonie ist ihr
## Paket längst verbraucht, die Kartendaten kennen ihn trotzdem.
func hover_pack_name() -> String:
	var cards := _slot_cards()
	if _hover_slot >= 0 and _hover_slot < cards.size():
		return String(cards[_hover_slot].get("name", ""))
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
	_series.clear()
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
	stream_passed.emit(index, faces, values, glyph, time)

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
	_series.clear()
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
	_refresh_sum_net()  # ohne Würfel-Ziel steht dort die Summe

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
	var wanted := index if index < _slot_cards().size() else -1
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
## Serie, ERGEBNIS und ORIGINAL samt dem Zielwürfel. Der Info-Schirm setzt das in
## seinen Titel - geraten wird im Schreiber nichts.
func net_hint_owner_at(pixel: Vector2) -> String:
	return String(_net_hint_info(pixel).get("owner", ""))

## EIN Entscheider für beide Fragen: UPGRADES und die Ergebnis-Karte, dann das
## Ergebnis-Netz, dann ORIGINAL.
func _net_hint_info(pixel: Vector2) -> Dictionary:
	var summed := _sum_hint_at(pixel)
	if not summed.is_empty() and String(summed.get("hint", "")) != "":
		return summed
	var podium := _face_hint(_podium_net, pixel)
	if podium != "":
		return {"hint": podium, "owner": _owner_line(ORIGINAL_OWNER, _podium_net.def)}
	var after := _face_hint(_net, pixel) if not opening_shown else ""
	if after != "":
		return {"hint": after, "owner": _owner_line(RESULT_OWNER, chosen_die())}
	return {}

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
