class_name WorkshopView
extends Panel
## Die WERKSTATT rechts vom Pool (V1, docs/plan_werkstatt_walze.md). Sie hat KEINEN
## Schirm-Hintergrund - ihre Teile liegen auf dem Filz. Die WALZEN-SPALTE beginnt
## rechts der Schale an der Pool-Oberkante und liest von oben nach unten:
##   VORHER | sechs SCHEIBEN im Graben | NACHHER,
## rechts daneben das MAGAZIN mit dem INFO-SCHIRM darüber, darunter die KAMMER (das
## eine Podest) und PRÄGEN. Die Kette rechnet drum_layout; scene_root meldet sie.
##  - DIE WALZE ist ein Körper (DrumView); das Fenster MALT sie nicht, seine
##    unsichtbaren Scheiben-Knöpfe tragen Klick, Zug und Zeiger.
##  - VORHER zeigt den Zielwürfel, wie er IST (ohne Ziel das leere Kreuz). NACHHER
##    ist der PressNetView: mit Ziel die Live-Vorschau bzw. das Ergebnis mit den
##    grünen Deltas, ohne Ziel die SUMME DER SERIE, beim Verdichten die Karte, die
##    herauskäme. Alle Netze teilen die Zelle des PRÄGENETZES (card_net_cell).
##
## Die Scheiben SIND die Rechnung: getippt geht eine Kassette auf die nächste freie
## Scheibe, gezogen sortiert sie um (Scheibe 1 wirkt zuerst), geklickt kommt sie
## zurück ins Magazin.
##
## Zustands-Mutation läuft ausschließlich über GameRun (resolve_series als
## Vorschau, apply_series als Prägen); die Vorschau ist buchstäblich dieselbe
## Rechnung wie die Buchung.

## Der Zielwürfel wurde gewählt, gewechselt oder abgewählt (null = keiner) -
## scene_root holt ihn per Hebebühne aus dem Pool auf das Podest und fährt ihn
## denselben Weg zurück.
signal target_chosen(die: DieDefinition)
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
## Die belegten Scheiben VERRIEGELN von oben nach unten; keine Karte bewegt sich.
signal slices_locked(time: float)
## Der Strom hat Scheibe index durchlaufen: welche Zellen sie hergibt, der Stand
## danach, die Glyphe, mit der sie zuschlägt ("" = still); time ist der Takt bis
## zur nächsten Scheibe (nach der letzten: bis NACHHER).
signal stream_passed(index: int, faces: Array, values: Array, glyph: String,
	time: float)
## Am NACHHER-Netz zerfällt das Licht-Netz in seine LICHTFUNKEN - sie schlagen
## GLEICHZEITIG in den Würfel (bzw. den Rohling) in der KAMMER.
signal stream_struck(time: float)
## Ein ZUG rollt die Magazin-Reihe row: so weit (Display-px, schon in den Grenzen)
## steht sie gerade gegen ihren Roll-Stand versetzt.
signal shelf_scrolling(row: int, offset_px: float)
## Losgelassen: der Roll-Stand ist schon gebucht, der Körper fährt von from_px auf
## to_px (beides gegen den ALTEN Stand) und rastet dort ein.
signal shelf_scroll_snapped(row: int, from_px: float, to_px: float)

const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")
## Operator-Karten stehen amber ab - die eine Farbtrennung der Serie (Wert-Karten
## behalten ihre Sortenfarbe). Die Quelle ist das Netz, nicht dieses Fenster.
const OPERATOR_TINT := PressNetView.OPERATOR_TINT
## Wem eine Netz-Zelle gehört, wenn kein Name dahintersteht (Info-Schirm-Titel).
const SUM_OWNER := "Summe der Serie"
const BEFORE_OWNER := "Vorher"
const AFTER_OWNER := "Nachher"

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
## Der VERSATZ des Podest-Ankers gegen den Platz, an dem der Würfel LIEST, in
## Display-Pixeln: er schwebt CLAMP_HOVER über dem Glas und projiziert vom Bildmittelpunkt
## weg - an der Kammer (unten links der Station) nach unten und links, also rückt der
## Anker hinauf und nach rechts. Gemessen 2026-11-18 als Mittel aus Weit- und Nahsicht.
const BENCH_TILT_TRIM := -26.7
const BENCH_TILT_TRIM_X := 16.4

## Seitenverhältnis der KASSETTE selbst (Höhe / Breite, 2 : 3) - daraus folgt der
## LIEGENDE Fußabdruck aus dem gemeldeten stehenden.
const CARD_ASPECT := PackDrawerView.CARD_ASPECT
## Die NUMMERN der Scheiben links am Graben: Breite, Fuge und Grad in u.
const SLICE_NUMBER_UNITS := 4.0
const SLICE_NUMBER_GAP := 0.6
const SLICE_NUMBER_FONT := 4.0

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

## DIE ÜBERTRAGUNG - die Zeremonie des Prägens. Die Scheiben verriegeln, ein Strom
## läuft von Scheibe 1 nach unten bis NACHHER und nimmt ihre Zellen auf, dort
## zerfällt er in Funken, die in den Würfel in der KAMMER schlagen. Der Würfel
## bleibt in der Kammer. Klick überspringt jederzeit.
## Das geparkte NACHHER-Netz ENTLEERT sich sofort auf die nackten Augenzahlen (die
## Vorschau tritt ab, die Rechnung beginnt bei 0) - parallel zum Verriegeln.
const DRAIN_TIME := 0.3
## Das VERRIEGELN: je Scheibe diese Zeit, von oben nach unten gestaffelt.
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
		_shelf_scroll.fill(0)  # ein neuer Lauf beginnt in der ersten Spalte
		run = value
		if run != null:
			run.packs_changed.connect(refresh)
			run.pool_changed.connect(refresh)  # VORHER und NACHHER zeigen den Pool
			run.press_changed.connect(refresh)  # eine Buchung räumt die Reihe
		refresh()

var _content: Control
## Das NACHHER-Netz mit Ziel. Es überlebt jeden Neuaufbau (es ist kein Kind des
## Inhalts): sein ZÄHL-Takt darf nicht daran zerbrechen, daß eine Kassette
## umsortiert wird - nur so tickt es beim Prägen von der Vorschau herunter.
var _net: PressNetView
## Sein PARKPLATZ im NACHHER-Schirm: ein leerer Platz in Netzgröße, auf den es je
## Bild zurückgesetzt wird.
var _net_host: Control
## Der Platz des Podests in der KAMMER, auf den der Vorrats-Würfel fährt.
var _target_stage_host: Control
## VORHER: der Platz und das Netz darin (PressNetView ohne Vorschau oder leeres Kreuz).
var _before_host: Control
var _before_net: PressNetView
## Haben die Funken schon eingeschlagen? Ab da zeigt VORHER den gebuchten Stand.
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
## Der ROLL-STAND je Magazin-Reihe (eine je Sorte) in ganzen Spalten - ANZEIGE, kein
## Spielstand: darum wohnt er hier und nicht in GameRun.
var _shelf_scroll: Array[int] = [0, 0, 0, 0]
## Reihe und letzter gemeldeter Versatz des laufenden Zugs.
var _drag_row := 0
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
## Platz des Zielwürfels im Pool.
var _target_index := -1
## Der ROHLING auf dem Podest (0 = keiner) - das Ziel des VERDICHTENS. Er und der
## Zielwürfel schließen sich aus: das Podest trägt EIN Ziel, und welche Art dort
## liegt, entscheidet, was der Knopf tut.
var _target_pack := 0
## Die Karte unter dem Zeiger (-1 = keine): ihre Beitrags-Zellen leuchten im
## NACHHER-Netz auf.
var _hover_slot := -1
## Die MAGAZIN-Kassette unter dem Zeiger (0 = keine) - dieselbe Frage, andere
## Auslage; der Schacht schlägt sie.
var _hover_pack_uid := 0
## Der Slot, auf dem ein Zug begonnen hat (-1 = keiner).
var _drag_from := -1

## DIE LAUFENDE ZEREMONIE. _burning trägt die Kartendaten des Prägens (die Karten
## selbst sind da längst verbraucht), _burn_step, wie viele davon die Welle schon
## erfaßt hat, und _burn_die den Zielwürfel, wie er VOR dem Prägen aussah - nur so
## kann das NACHHER-Netz von 0 hochticken.
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
## NACHHER ohne Würfel-Ziel (null = steht gerade nicht): sein Netz-Platz und das darin
## hängende Netz - die SUMME DER SERIE bzw. die Karte, die das Verdichten ergäbe.
var _sum_host: Control
var _sum_net_view: Control
## Was es gerade zeigt - Signatur (nur der WECHSEL baut neu), Quelle
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
	set_process(true)  # das NACHHER-Netz hält seinen Platz
	refresh()

## Das NACHHER-Netz PARKT auf seinem Platz - es folgt damit jedem Neuaufbau des
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
	_target_stage_host = null
	_net_host = null
	_before_host = null  # VORHER hing am Inhalt
	_before_net = null
	# Ein Neuaufbau mitten im Zug läßt ihn einrasten, statt ihn hängen zu lassen.
	if shelf_dragging():
		_on_scroll_released.call_deferred(_drag_row, _last_drag_px)
	_free_own(_drawer)  # das Magazin hängt am Panel, nicht am Inhalt
	_drawer = null
	_sum_host = null  # NACHHER ohne Würfel hing am Inhalt
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

## Das NACHHER-Netz wird nie neu gebaut, nur neu ausgelegt - sonst risse jeder
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

## Sein Platz: die Mitte des Parkplatzes im NACHHER-Schirm.
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

# --- DIE WALZEN-SPALTE: VORHER | sechs Scheiben im Graben | NACHHER; rechts das
# --- Magazin, darunter Kammer und Prägen (docs/plan_werkstatt_walze.md). -----------

## Die Kette in FENSTER-Koordinaten: die gemeldete Display-Kette (drum_frame) gegen
## ihre eigene Ecke versetzt - das Fenster steht auf genau dieser Ecke. Ohne Meldung
## (kopflos, Tests) rechnet es die Kette selbst ab dem Ursprung.
func drum() -> Dictionary:
	var frame := drum_frame
	if frame.is_empty():
		var face := die_face_px if die_face_px > 0.0 else unit() * U_PER_FACE
		frame = drum_layout(Rect2(), Rect2(), lie_span_px(), face, unit())
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

## Die SCHEIBE index in Fenster-Koordinaten - Scheibe 1 (index 0) OBEN. Sie trägt Klick,
## Zug und Zeiger; der Körper darunter (DrumView) trägt nichts davon.
func slice_rect(index: int) -> Rect2:
	var slices: Array = drum()["slices"]
	return slices[clampi(index, 0, slices.size() - 1)]

## Der GRABEN der Walze in Display-Pixeln: ein Dauer-Loch.
func drum_pit_rect() -> Rect2:
	return _global(drum()["pit"])

## Sein Eckenradius - derselbe, den die Magazin-Grube trägt.
func drum_pit_radius() -> float:
	return shelf_pit_radius()

## Die Kante des Scheiben-Vierkants in Display-Pixeln.
func drum_side() -> float:
	return drum_side_px(lie_span_px())

## Die Teilung der Scheiben in Display-Pixeln.
func drum_pitch() -> float:
	var slices: Array = drum()["slices"]
	if slices.size() < 2:
		return lie_span_px().y
	return (slices[1] as Rect2).position.y - (slices[0] as Rect2).position.y

## VORHER über Scheibe 1: der Zielwürfel, wie er IST.
func before_net_rect() -> Rect2:
	return drum()["before"]

## NACHHER unter Scheibe 6: Vorschau bzw. Ergebnis, ohne Ziel die Summe der Serie.
func after_net_rect() -> Rect2:
	return drum()["after"]

## Der INFO-SCHIRM über dem Magazin, in Display-Pixeln.
func info_rect_px() -> Rect2:
	return _global(drum()["info"])

## Die Spanne der PODEST-Bühne: ein WELTMASS (die Würfelfläche mal STAGE_FACES),
## kopflos der alte u-Rückfall.
func stage_px() -> float:
	if die_face_px > 0.0:
		return die_face_px * STAGE_FACES
	return unit() * STAGE_HEIGHT

## Der ANKER des Podests: die Mitte der KAMMER, um den Neigungs-Versatz verschoben -
## dort steht der Puck, und der schwebende Würfel liest über der Kammermitte.
func target_podium_rect() -> Rect2:
	var stage := Vector2.ONE * stage_px()
	var at := chamber_rect().get_center() + Vector2(BENCH_TILT_TRIM_X, BENCH_TILT_TRIM)
	return Rect2(at - stage * 0.5, stage)

## Die KAMMER unter dem Magazin (Fenster-Koordinaten): das EINE Podest - eine flache
## Grube, über der der Zielwürfel schwebt bzw. in der der Rohling liegt.
func chamber_rect() -> Rect2:
	return drum()["chamber"]

## Die Kammer in Display-Pixeln.
func chamber_rect_px() -> Rect2:
	return _global(chamber_rect())

## Kammer samt Präge-Sitz in Display-Pixeln.
func chamber_area_px() -> Rect2:
	return _global(chamber_rect().merge(stamp_seat_rect()))

## Was die Werkstatt in Display-Pixeln bedient: die Walzen-Spalte samt Nummern, das
## Magazin und die Kammer mit dem Präge-Sitz - der leere Filz dazwischen nicht.
func hit_rects() -> Array[Rect2]:
	var layout := drum()
	var column: Rect2 = (layout["before"] as Rect2).merge(layout["pit"]).merge(layout["after"])
	column = column.grow_individual(unit() * (SLICE_NUMBER_UNITS + SLICE_NUMBER_GAP),
		0.0, 0.0, 0.0)
	return [_global(column), shelf_rect_global(), chamber_area_px()] as Array[Rect2]

## Der PRÄGE-SITZ rechts neben der Kammer.
func stamp_seat_rect() -> Rect2:
	return drum()["stamp"]

func _build_street(u: float) -> void:
	_target_stage_host = _podium_host("TargetStage", target_podium_rect())
	_build_before_screen(u)
	_build_after_screen(u)
	_build_slices(u)
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

## Ein Netz-Schirm (VORHER, NACHHER) mit einem leeren Platz in Netzgröße, mittig.
func _net_screen(screen_name: String, rect: Rect2, cell: float) -> Control:
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

## VORHER: der Zielwürfel schlicht - während des Prägens der Stand davor, bis die
## Funken einschlagen.
func _build_before_screen(u: float) -> void:
	_before_host = _net_screen("BeforeScreen", before_net_rect(), net_cell(u))
	_fill_before()

## Der Würfel, den VORHER zeigt (null = keiner, dann das leere Kreuz).
func before_die() -> DieDefinition:
	if burning() and not _burn_struck:
		return _burn_die
	return target_die()

func _fill_before() -> void:
	if _before_host == null or not is_instance_valid(_before_host):
		return
	for child in _before_host.get_children():
		_before_host.remove_child(child)
		child.queue_free()
	_before_net = null
	var cell := net_cell(unit())
	var die := before_die()
	if die == null:
		_before_host.add_child(_empty_net_cross(cell))
		return
	_before_net = PressNetView.new()
	_before_net.cell = cell
	_before_net.def = die
	_before_net.build()
	_before_host.add_child(_before_net)

## NACHHER: der Parkplatz des Netzes mit Ziel und daneben die Summe der Serie, die
## steht, solange kein Würfel das Ziel ist.
func _build_after_screen(u: float) -> void:
	var host := _net_screen("AfterScreen", after_net_rect(), net_cell(u))
	# Der PARKPLATZ des Netzes bleibt ein leerer Platz - die Summe hängt daneben.
	var park := Control.new()
	park.name = "Park"
	park.mouse_filter = Control.MOUSE_FILTER_IGNORE
	park.position = host.position
	park.size = host.size
	host.get_parent().add_child(park)
	_net_host = park
	_sum_host = host
	_sum_signature = ""
	_refresh_sum_net()

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

## Das EINE Zellmaß der Netze (Welle 29): die Zelle des PRÄGENETZES auf der Karte -
## Summen-, Ziel- und Licht-Netz lesen damit wie die Karte selbst (VORHER und
## NACHHER sind Kartenzellen).
func net_cell(_u: float) -> float:
	return card_net_cell(shelf_cell_px())

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

# --- DIE WALZE (V1, docs/plan_werkstatt_walze.md): die reine Layout-Kette ----------

## Sechs Scheiben, Scheibe 1 oben - der Deckel der Serie.
const DRUM_SLICES := 6
## Luft der Karte im Scheiben-Vierkant, Anteil der Kartenlänge.
const DRUM_AIR := 0.06
## Fuge zwischen Graben und Magazin, in u.
const DRUM_SHELF_GAP := 4.0

## Die Kante des Scheiben-Vierkants: die Kartenlänge plus Luft.
static func drum_side_px(card: Vector2) -> float:
	return card.x * (1.0 + DRUM_AIR)

## Die ganze Kette in Display-px aus Pool-Reihe, Schale, liegender Karte, Würfelfläche
## und u. Die Spalte beginnt rechts der Schale an der Pool-OBERKANTE; das Magazin löst
## sich von Scheibe 1, wenn der Info-Schirm (info_h) darüber mehr Platz braucht.
static func drum_layout(pool: Rect2, fach: Rect2, card: Vector2, die_face: float,
		u: float, info_h := 0.0) -> Dictionary:
	var seam := u * STREET_GAP
	# Auf Kante gedreht braucht der Vierkant seine Diagonale.
	var width := drum_side_px(card) * sqrt(2.0) + seam
	var left := maxf(pool.end.x, fach.end.x) + seam
	var net_x := left + (width - card.x) * 0.5
	var before := Rect2(Vector2(net_x, pool.position.y), card)
	var pitch := card.y + seam
	var pit := Rect2(Vector2(left, before.end.y + seam * 0.5),
		Vector2(width, pitch * float(DRUM_SLICES)))
	var slices: Array[Rect2] = []
	for i in DRUM_SLICES:
		slices.append(Rect2(Vector2(left, pit.position.y + seam * 0.5 + pitch * float(i)),
			Vector2(width, card.y)))
	var after := Rect2(Vector2(net_x, pit.end.y + seam * 0.5), card)
	var rim := PackDrawerView.rim_inset(u)
	var field := PackDrawerView.field_for(card)
	var shelf_pos := Vector2(pit.end.x + u * DRUM_SHELF_GAP,
		maxf(slices[0].position.y, pool.position.y + info_h + seam))
	var shelf := Rect2(shelf_pos, field + Vector2.ONE * rim * 2.0)
	# Je SORTE eine Reihe: die Lane ihrer Karten in Display-Pixeln (EINE Quelle).
	var rows: Array[Rect2] = []
	for lane in PackDrawerView.row_rects(field):
		rows.append(Rect2(shelf_pos + Vector2.ONE * rim + lane.position, lane.size))
	var info := Rect2(Vector2(shelf_pos.x, pool.position.y),
		Vector2(shelf.size.x, maxf(shelf_pos.y - seam - pool.position.y, 1.0)))
	var stage := die_face * STAGE_FACES
	# Quadratisch und so groß, dass auch der liegende ROHLING mit Luft hineinpaßt.
	var side := maxf(stage, drum_side_px(card))
	var chamber := Rect2(Vector2(shelf_pos.x, shelf.end.y + seam), Vector2(side, side))
	var action := Vector2(u * ACTION_WIDTH, maxf(stage * ACTION_SPAN_SHARE, u * ACTION_HEIGHT))
	var stamp := Rect2(Vector2(chamber.end.x + seam, chamber.get_center().y - action.y * 0.5),
		action)
	var bounds := before.merge(after).merge(pit).merge(shelf).merge(info).merge(chamber) \
		.merge(stamp)
	return {"before": before, "pit": pit, "slices": slices, "after": after,
		"shelf": shelf, "rows": rows, "info": info, "chamber": chamber, "stamp": stamp,
		"bounds": bounds}

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

func target_index() -> int:
	return _target_index

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
	_target_pack = 0  # das Podest trägt EIN Ziel
	_target_index = index
	_announce_target()

## Der gewählte ROHLING (null = keiner). Gefüllt ist er keiner mehr, also fällt die
## Wahl von selbst, sobald das Verdichten gebucht hat.
func target_pack() -> Pack:
	if run == null or _target_pack == 0:
		return null
	var pack := run.pack_by_uid(_target_pack)
	return pack if pack != null and pack.is_blank_card() else null

## VERDICHTET das Podest gerade, statt zu prägen? Die Art des Ziels entscheidet - und
## während der Zeremonie die Art, mit der sie aufbrach (der Rohling ist dann längst
## gefüllt und wäre keiner mehr).
func compressing() -> bool:
	if burning():
		return _burn_blank != 0
	return target_pack() != null

## Die ZIELWAHL eines Rohlings: derselbe wählt ab, ein anderer wechselt. Sie räumt den
## Zielwürfel mit fort - das Podest trägt EIN Ziel.
func set_target_pack(pack: Pack) -> void:
	if editing_locked or burning():
		return
	if pack == null or not pack.is_blank_card() or pack.pack_uid == _target_pack:
		clear_target()
		return
	_target_index = -1
	_target_pack = pack.pack_uid
	_announce_target()

## Wählt ab (kein Ziel mehr) - der Podest-Würfel fährt in seinen Pool-Sitz zurück.
func clear_target() -> void:
	if _target_index < 0 and _target_pack == 0:
		return
	skip_ceremony()  # mitten in der Übertragung: erst ihr harter Weg, dann die Abwahl
	_target_index = -1
	_target_pack = 0
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

## Der Zielwürfel, den NACHHER zeigt: während der Zeremonie der Stand VOR
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

## Display-Pixel des ROHLING-PLATZES: die Mitte der KAMMER ((-1,-1) = sie steht gerade
## nicht). Die Karte LIEGT flach, darum ohne den Neigungs-Versatz des Würfels.
func blank_seat_center() -> Vector2:
	if _target_stage_host == null or not is_instance_valid(_target_stage_host):
		return Vector2(-1, -1)
	return chamber_rect_px().get_center()

## Der ROHLING, der gerade in der Kammer LIEGT - während der Zeremonie der, in den sie
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
## die Anzeige ohnehin fortgeschnitten), links daneben ihre Nummer.
func _build_slices(u: float) -> void:
	var cards := _slot_cards()
	for i in slot_count():
		var card: Dictionary = cards[i] if i < cards.size() else {}
		var rect := slice_rect(i)
		var seat := _slice_button(i, card)
		seat.position = rect.position
		seat.size = rect.size
		_content.add_child(seat)
	var pit: Rect2 = drum()["pit"]
	for i in DRUM_SLICES:
		var rect := slice_rect(i)
		var number := Label.new()
		number.name = "SliceNumber%d" % (i + 1)
		number.text = str(i + 1)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var width := u * SLICE_NUMBER_UNITS
		number.position = Vector2(pit.position.x - width - u * SLICE_NUMBER_GAP,
			rect.position.y)
		number.size = Vector2(width, rect.size.y)
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

## Steckt die Reparatur-Karte in der Reihe? Dann nimmt das Prägen auch einen
## durchgebrannten Würfel an.
func series_repairs() -> bool:
	for pack in slotted_packs():
		if pack.is_repair():
			return true
	return false

## Steckt eine Kühl- oder Reparatur-Karte darin? Dann wirkt das Prägen auch ohne
## Netz-Karte.
func series_tends() -> bool:
	for pack in slotted_packs():
		if pack.tends_die():
			return true
	return false

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
## (Spieler-Wunsch 2026-10-25) und darunter eine, die prägt, kühlt oder repariert; ein
## durchgebrannter Würfel nur mit der Reparatur-Karte.
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
	var repairs := series_repairs()
	if target_die().burned_out and not repairs:
		return false
	return stamping_card_count() > 0 or series_tends()

## Zwingt einen Knopf auf das Sitzmaß: clip_text nimmt der Aufschrift das Recht,
## das Rechteck zu verbreitern.
func _seat_fit(button: Button, u: float) -> Button:
	button.clip_text = true
	button.custom_minimum_size = action_size(u)
	button.add_theme_font_size_override("font_size", action_font_size(u))
	return button

## Maße des Sitzes: EIN Rechteck für beide Aufschriften - der Platz, den die Kette
## neben der Kammer rechnet.
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
	if target_die() == null and not compressing():
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
	if target_die().burned_out and not series_repairs():
		return "Durchgebrannt - die %s fehlt." % Pack.catalyst_name(Pack.CATALYST_REPAIR)
	if stamping_card_count() <= 0 and not series_tends():
		return "Nur Katalysatoren - eine Netz-Karte fehlt."
	return ""

# --- NACHHER ohne Würfel-Ziel: die SUMME DER SERIE --------------------------------

## Was NACHHER ohne Würfel zeigt - EIN Entscheider: mit Würfel-Ziel nichts (dort steht
## das Vorschau-Netz), beim Verdichten die Karte, die herauskäme, sonst die SUMME der
## gesteckten Netze (zielunabhängig), und ohne Netz das leere Kreuz.
func _sum_view_source() -> Dictionary:
	if preview_target() != null:
		return {"mode": "die"}
	var nets := _sum_nets()
	if nets.is_empty():
		return {"mode": "empty"}
	# Verdichten ist eine ANDERE Rechnung als Prägen (Faktoren addieren).
	if compressing():
		return {"mode": "card", "net": SeriesResolver.compress(nets)["net"]}
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
	if run == null:
		return GameRun.catalyst_terms(slotted_packs())
	return run.series_terms(slotted_packs())

## Die Signatur der Quelle - nur ihr WECHSEL baut das Netz neu.
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
	if _sum_net_view != null and is_instance_valid(_sum_net_view):
		_sum_host.remove_child(_sum_net_view)
		_sum_net_view.queue_free()
	_sum_net_view = null
	var source := _sum_view_source()
	_sum_mode = String(source.get("mode", "empty"))
	_sum_source_net = source.get("net", [])
	_sum_projection = source.get("projection", {})
	_sum_cell = net_cell(unit())
	match _sum_mode:
		"die":
			return
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
	# Kammer-Würfel soll die ALTEN Augen behalten, bis die Funken einschlagen.
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
## ihn auf den Kammer-Würfel zurück, bis die Funken einschlagen - sonst zeigte die
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

## Hat das laufende Prägen repariert? Dann blitzt der Würfel beim Einschlag golden.
func burn_repaired() -> bool:
	return bool(_burn_result.get("repaired", false))

## Wie lange das VERRIEGELN dauert: eine Scheibe plus die Staffel über die übrigen.
func lock_time() -> float:
	return LOCK_TIME + LOCK_STAGGER * float(maxi(_burning.size(), 1) - 1)

## Wie lange die ÜBERTRAGUNG dauert - scene_root staffelt daran nichts, aber ein Test
## darf sie abwarten.
func ceremony_time() -> float:
	var beats := 0.0
	for i in _burning.size():
		beats += card_beat(i)
	return lock_time() + beats + STRIKE_TIME + STRIKE_HOLD

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
## NACHHER-Netz kartenweise hoch.
func _burn_nets_so_far() -> Array:
	var nets: Array = []
	for i in mini(maxi(_burn_step, 0), _burning.size()):
		if String(_burning[i].get("catalyst", "")) != "":
			continue  # ein Katalysator prägt nicht, er legt Terme bei
		nets.append(_burning[i].get("net", []))
	return nets

## DIE ÜBERTRAGUNG: die Scheiben verriegeln, der Strom läuft Scheibe um Scheibe nach
## unten (jede Karte flammt auf, ihre Zellen dunkeln ab, die Summe tickt hoch, ein
## Operator schlägt perkussiv zu), am NACHHER-Netz zerfällt er in Funken, die in die
## KAMMER schlagen - in den Würfel bzw. beim Verdichten in den Rohling. Am Ende
## meldet das Fenster das Prägen, und scene_root räumt. Hier steht nur der TAKT.
func _play_series_ceremony(generation: int) -> void:
	var launched := run
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
	# Mit dem Einschlag springt VORHER auf den gebuchten Stand - zusammen mit dem Würfel.
	_burn_struck = true
	_fill_before()
	if not await _scan_wait(STRIKE_HOLD, generation, launched):
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

## Der Strom hat Karte i erreicht: sie flammt auf, das NACHHER-Netz
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
	_target_index = -1
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

## Display-Pixel der Mitte von NACHHER - dort endet der Strom, dort starten die Funken.
func after_net_center_px() -> Vector2:
	return _global(after_net_rect()).get_center()

## Die Mitte der Zelle einer Seite im NACHHER-Netz, in Display-Pixeln - dort startet
## ihr Funke.
func after_cell_center_px(face: int) -> Vector2:
	var rect := after_net_rect()
	var cell := net_cell(unit())
	var span := DieNetView.net_size(cell)
	var corner := rect.position + ((rect.size - span) * 0.5).max(Vector2.ZERO)
	var at := corner + DieNetView.cell_position(face, cell)
	return _global(Rect2(at, Vector2.ONE * cell)).get_center()

# --- Das Magazin (versiegelte Ware) ---------------------------------------------

## Das Magazin: EINE eingelassene Grube rechts der Walze, je Sorte eine Reihe, je
## Paket seine eigene Kassette. Es ist die einzige Auslage versiegelter Ware.
func _build_drawer(u: float) -> void:
	_drawer = PackDrawerView.new()
	_drawer.pack_pressed.connect(_on_pack_pressed)
	_drawer.tidy_requested.connect(_on_tidy_requested)
	_drawer.scroll_dragged.connect(_on_scroll_dragged)
	_drawer.scroll_released.connect(_on_scroll_released)
	add_child(_drawer)  # direktes Kind: das Fach reicht über die Fensterkante hinaus
	var rect := shelf_rect()
	_drawer.position = rect.position
	_drawer.size = rect.size
	_drawer.build(drawer_entries(), u, shelf_locked(), data_cell_px, rect.size,
		_shelf_scroll)
	if not _queued_pops.is_empty():
		_flush_queued_pops.call_deferred()  # der Pluster braucht das fertige Layout

## Der Platz des Magazins in Fenster-Koordinaten: das Sorten-Rechteck der Kette,
## rechts der Walze unter dem Info-Schirm.
func shelf_rect() -> Rect2:
	return drum()["shelf"]

## Derselbe Platz in Display-Pixeln.
func shelf_rect_global() -> Rect2:
	return _global(shelf_rect())

## Das LOCH des Magazins in Display-Pixeln: der Streifen abzüglich seiner gemalten
## Fassung. scene_root schneidet danach das Glas und stellt die Grube darunter.
func shelf_pit_rect() -> Rect2:
	return PackDrawerView.pit_rect_in(shelf_rect_global(), shelf_unit())

## Die Lane der Magazin-Reihe row in Display-Pixeln.
func shelf_row_rect(row: int) -> Rect2:
	var rows: Array = drum()["rows"]
	return _global(rows[clampi(row, 0, rows.size() - 1)])

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

## Je Paket {uid, pack, withheld, row, cell} in Magazin-Ordnung (= run.owned_packs).
## Was auf einer Scheibe liegt, fehlt ganz - seine Reihe schließt sich derweil; was
## noch als Licht fliegt, hält seinen Platz und bleibt bis zur Landung verdeckt.
## Die REIHE ist die Sorte, der PLATZ der Rang darin (das SORTEN-MODELL des Laufs).
func drawer_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if run == null:
		return entries
	var fill: Dictionary = {}
	for pack in run.owned_packs:
		if _series.has(pack.pack_uid):
			continue
		var row := Pack.shelf_rank(pack)
		var cell_index := int(fill.get(row, 0))
		fill[row] = cell_index + 1
		# Der ROHLING in der Kammer hat im Fach KEINEN Körper - sein Platz bleibt
		# stehen, wie der Pool-Sitz des Zielwürfels: ein Ding wird nie zweimal gezeigt.
		entries.append({"uid": pack.pack_uid, "pack": pack,
			"withheld": _pending_arrivals.has(pack.pack_uid)
				or pack.pack_uid == _target_pack
				or pack.pack_uid == _burn_blank,
			"row": row, "cell": cell_index})
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
	# Gefragt wird, ob das Fach den Platz KENNT - weit nach links gerollt ist ein
	# Platz legitim NEGATIV (Bug 2026-10-26).
	if _drawer != null and is_instance_valid(_drawer) and _drawer.knows_pack(uid):
		return _drawer.pack_seat_px(uid)
	var pit := shelf_pit_rect()
	if pit.size.x > 0.0 and pit.size.y > 0.0:
		return PackDrawerView.anchor_in(pit, shelf_window_column_of(uid),
			shelf_cell_px(), shelf_row_of(uid))
	return shelf_rect_global().get_center()  # ohne Grube bleibt nur die Mitte

## Wohin das Liefer-Licht einer Kassette fliegt: auf ihren Platz, wenn er im Fenster
## liegt - sonst an den Rand ihrer Reihe auf der Seite, auf der er liegt.
func pack_anchor_px(uid: int) -> Vector2:
	if _drawer != null and is_instance_valid(_drawer) and _drawer.knows_pack(uid):
		return _drawer.pack_anchor_px(uid)
	return _anchor_for(shelf_row_of(uid), shelf_window_column_of(uid))

## Der Anker einer Spalte (im Fenster gezählt) einer Reihe - die EINE Regel für
## gelandete wie für noch nicht eingelagerte Karten.
func _anchor_for(row: int, column: int) -> Vector2:
	var pit := shelf_pit_rect()
	var at := PackDrawerView.anchor_in(pit, clampi(column, 0, shelf_columns() - 1),
		shelf_cell_px(), row)
	if column < 0:
		return Vector2(pit.position.x, at.y)
	if column >= shelf_columns():
		return Vector2(pit.end.x, at.y)
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

## Die REIHE (= Sorte), in der diese Kassette liegt.
func shelf_row_of(uid: int) -> int:
	if _drawer != null and is_instance_valid(_drawer):
		var line := _drawer.row_of_pack(uid)
		if line >= 0:
			return line
	var entry := _entry_of(uid)
	if entry.is_empty():
		var pack := run.pack_by_uid(uid) if run != null else null
		return Pack.shelf_rank(pack) if pack != null else 0
	return int(entry["row"])

## Ihr PLATZ in der Reihe (Rang unter den Karten derselben Sorte im Fach).
func shelf_cell_of(uid: int) -> int:
	return int(_entry_of(uid).get("cell", 0))

## Ihre SPALTE im Fenster - der Roll-Stand ihrer Reihe ist schon abgezogen.
func shelf_window_column_of(uid: int) -> int:
	if _drawer != null and is_instance_valid(_drawer) and _drawer.row_of_pack(uid) >= 0:
		return _drawer.column_of_pack(uid)
	return shelf_cell_of(uid) - shelf_scroll_of(shelf_row_of(uid))

## Liegt sie im FENSTER ihrer Reihe (nicht hinausgerollt)?
func shelf_in_window(uid: int) -> bool:
	var column := shelf_window_column_of(uid)
	return column >= 0 and column < shelf_columns()

## Wie viele Spalten das Fenster einer Reihe zeigt.
func shelf_columns() -> int:
	return PackDrawerView.columns_for(shelf_pit_rect().size, shelf_cell_px())

## Die Breite EINER Spalte in Display-Pixeln - der Schritt, um den eine Reihe rollt.
func shelf_slot_px() -> float:
	return PackDrawerView.slot_size(shelf_pit_rect().size, shelf_cell_px()).x

## Wie viele Karten im Fach einer Reihe liegen (ohne die gesteckten).
func shelf_row_count(row: int) -> int:
	var count := 0
	for entry in drawer_entries():
		if int(entry.get("row", -1)) == row:
			count += 1
	return count

## Der ROLL-STAND einer Reihe in Spalten.
func shelf_scroll_of(row: int) -> int:
	if row < 0 or row >= _shelf_scroll.size():
		return 0
	return _shelf_scroll[row]

## Setzt den Roll-Stand, in den Grenzen 0 .. max(0, Karten - Fenster).
func set_shelf_scroll(row: int, columns: int) -> void:
	if row < 0 or row >= _shelf_scroll.size():
		return
	var wanted := PackDrawerView.clamp_scroll(columns, shelf_row_count(row),
		shelf_columns())
	if _shelf_scroll[row] == wanted:
		return
	_shelf_scroll[row] = wanted
	refresh()

## Der Laufwechsel: jede Reihe steht wieder auf ihrer ersten Spalte.
func reset_shelf_scroll() -> void:
	for row in _shelf_scroll.size():
		_shelf_scroll[row] = 0
	refresh()

## Gibt es links bzw. rechts hinausgerollte Karten? (x = links, y = rechts) - links
## zählt, was dort wirklich LIEGT.
func shelf_overflow(row: int) -> Vector2i:
	var scroll := shelf_scroll_of(row)
	var used := shelf_row_count(row)
	return Vector2i(1 if mini(scroll, used) > 0 else 0,
		1 if used - scroll > shelf_columns() else 0)

## Die Sortenfarben einer Reihe, ein Eintrag je SPALTE im Fenster (leer stumpf) - die
## MULDEN ihrer Platte lesen sie.
func shelf_row_tints(row: int) -> Array[Color]:
	var tints: Array[Color] = []
	var columns := shelf_columns()
	var scroll := shelf_scroll_of(row)
	var packs: Array[Pack] = []
	packs.resize(columns)
	for entry in drawer_entries():
		if int(entry.get("row", -1)) != row:
			continue
		var column := int(entry.get("cell", 0)) - scroll
		if column >= 0 and column < columns:
			packs[column] = entry.get("pack") as Pack
	for pack in packs:
		if pack == null:
			tints.append(ShelfStackView.BAY_EMPTY)
			continue
		tints.append(PackDrawerView.card_shade(Pack.shelf_of(pack), pack.tier,
			pack.catalyst_id, pack.stamp_net, pack.from_blank()))
	return tints

## Der Platz, auf dem die NÄCHSTE Lieferung DIESES Pakets landet (extra staffelt eine
## Salve): seine Reihe ist seine Sorte, gefragt beim Lauf.
func arrival_anchor_px(pack: Pack, extra: int = 0) -> Vector2:
	if run == null or pack == null:
		return shelf_rect_global().get_center()
	var row := run.next_pack_spot(pack, extra).x
	# Gesteckte Karten liegen nicht im Fach - der Platz zählt nur, was dort liegt.
	var cell_index := shelf_row_count(row) + maxi(extra, 0)
	return _anchor_for(row, cell_index - shelf_scroll_of(row))

## Eine Kassette wurde angetippt: sie wandert auf die nächste freie Scheibe - ein
## ROHLING dagegen in die KAMMER. Die Karte entscheidet, was der Tipp tut, genau wie
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

## Ein Zug rollt eine Reihe: gemeldet wird der Versatz, schon in den Grenzen - am
## Ende liegt nichts außerhalb des Roll-Bereichs.
func _on_scroll_dragged(row: int, offset_px: float) -> void:
	_drag_row = row
	_last_drag_px = offset_px
	shelf_scrolling.emit(row, _clamp_scroll_px(row, offset_px))

## Losgelassen: der Roll-Stand rastet auf die nächste ganze Spalte und wird SOFORT
## gebucht (Endzustand zuerst) - der Körper fährt den Rest des Weges.
func _on_scroll_released(row: int, offset_px: float) -> void:
	var before := shelf_scroll_of(row)
	var from := _clamp_scroll_px(row, offset_px)
	var after := PackDrawerView.snap_scroll(before, from, shelf_slot_px(),
		shelf_row_count(row), shelf_columns())
	set_shelf_scroll(row, after)
	shelf_scroll_snapped.emit(row, from, float(before - after) * shelf_slot_px())

## Der Zug-Versatz: nach links (weiter) unbegrenzt - die Reihe läuft ins Leere und
## federt beim Loslassen zurück -, nach rechts nie vor den Anfang.
func _clamp_scroll_px(row: int, offset_px: float) -> float:
	return minf(offset_px, float(shelf_scroll_of(row)) * shelf_slot_px())

## Rollt gerade ein Zug über das Magazin?
func shelf_dragging() -> bool:
	return _drawer != null and is_instance_valid(_drawer) and _drawer.dragging()

## Doppelklick auf leere Fach-Fläche: aufräumen nach Sorte, Inhalt, uid.
func _on_tidy_requested() -> void:
	if run == null or shelf_locked() or browse_only:
		return
	run.tidy_packs()

# --- Auskunft --------------------------------------------------------------------

## Das HOVER-HIGHLIGHT je Bild: die überfahrene KARTE (Schacht ODER Magazin) hebt
## ihre Beitrags-Zellen im NACHHER-Netz hervor. GEFRAGT statt gemeldet - der Zeiger liegt auf dem Tisch, kein
## mouse_entered erreicht das Fenster.
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

## WEM die getroffene Zelle gehört ("" = keine getroffen): NACHHER ohne Würfel die
## Summe der Serie, sonst VORHER bzw. NACHHER samt dem Zielwürfel. Der Info-Schirm
## setzt das in seinen Titel - geraten wird im Schreiber nichts.
func net_hint_owner_at(pixel: Vector2) -> String:
	return String(_net_hint_info(pixel).get("owner", ""))

## EIN Entscheider für beide Fragen: NACHHER (Summe, dann Vorschau) vor VORHER.
func _net_hint_info(pixel: Vector2) -> Dictionary:
	var summed := _sum_hint_at(pixel)
	if summed != "":
		return {"hint": summed, "owner": AFTER_OWNER if _sum_mode == "card" else SUM_OWNER}
	var die := target_die()
	var after := _face_hint(_net, pixel)
	if after != "":
		return {"hint": after, "owner": _owner_line(AFTER_OWNER, die)}
	var before := _face_hint(_before_net, pixel)
	if before != "":
		return {"hint": before, "owner": _owner_line(BEFORE_OWNER, die)}
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
