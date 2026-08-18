class_name PressPortalView
extends Control
## Das Anzeigefeld EINES Lesers: dunkel, solange nichts steckt, mit dem Siegel
## seiner Sorte, sobald ein Paket gebucht ist - und in der Pressung ein PORTAL.
## Ein paar Lichtpunkte kreisen darin nach innen, werden schneller, und aus der
## Entladung fahren die Meteore der Beute heraus (die fliegen in scene_root).
##
## Reine Anzeige: gewürfelt und gebucht hat GameRun längst. Läuft nichts, läuft
## auch kein _process - ein stehendes Feld kostet nichts.

## Dauer des Wirbels und des Blitzes danach; scene_root staffelt daran.
const SWIRL_TIME := 0.55
const DISCHARGE_TIME := 0.22
## Der MULTICAST-Schlag zwischen zwei Auslösungen: der Leser reißt noch einmal auf
## und schreibt, die wievielte es ist. Die erste Auslösung zeigt ihn nie - ×1 ist
## kein Ereignis.
const MULTICAST_TIME := 0.42
## Ring und Zahl wachsen mit der Auslösung. Der Kopfwert bleibt unter der Grenze,
## ab der die drei Kanäle zu Weiß zusammenlaufen und die Zahl in ihrem eigenen
## Leuchten verschwindet.
const MULTICAST_RING := 1.15
const MULTICAST_MARK_SHARE := 0.52
const MULTICAST_PEAK := 1.75
## Kreisende Punkte je Portal (nach Platz gestreut) und ihre Größe.
const DOTS_MIN := 3
const DOTS_MAX := 5
const DOT_SHARE := 0.085
## Startradius des Wirbels als Anteil der halben Kante, und seine Umläufe.
const START_RADIUS := 0.40
const TURNS := 2.2
## Rand des Siegels im Feld - es soll darin sitzen, nicht bis an die Kante laufen.
const GLYPH_INSET := 0.13

var sort := ""

## Die EINSPEISUNG eines Katalysators: er gibt seine Ladung an den Griff ab und
## bleibt danach dunkel - dieser Leser wirft nichts aus, also wirbelt er auch
## nicht. Ein einziges Aufblitzen, und das ist die ganze Ansage.
const INJECT_TIME := 0.45

## 0 = ruhig, 1 = Wirbel, 2 = Entladung, 3 = Multicast-Schlag, 4 = Einspeisung.
var _state := 0
var _time := 0.0
var _delay := 0.0
var _dots := DOTS_MIN
var _glyph: Control
## Die wievielte Auslösung der Schlag ansagt (0 = keiner läuft).
var _multicast := 0
var _mark: Label

func _init() -> void:
	name = "PressPortal"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(false)

## Belegt das Portal mit dem Siegel seiner Sorte ("" = dunkel). side ist die
## Kantenlänge des Feldes - gemessen wird sie erst nach dem Layout, das Siegel
## braucht seinen Rand aber schon jetzt.
func setup(pack_sort: String, seed_index: int = 0, side: float = 0.0) -> void:
	sort = pack_sort
	_dots = DOTS_MIN + absi(seed_index) % (DOTS_MAX - DOTS_MIN + 1)
	if sort == "":
		return
	var icon := PackIconRenderer.for_type(Pack.pack_type_of_shelf(sort))
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := maxf(side, size.y) * GLYPH_INSET
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	add_child(icon)
	_glyph = icon

## Der Wirbel: das Siegel geht unter, die Punkte ziehen nach innen. delay
## staffelt die sechs Leser gegeneinander.
func swirl(delay: float = 0.0) -> void:
	_state = 1
	_time = 0.0
	_delay = maxf(delay, 0.0)
	if _glyph != null and is_instance_valid(_glyph):
		_glyph.visible = false
	set_process(true)
	queue_redraw()

## Die Einspeisung: das Siegel geht unter, ein Blitz fährt heraus, dann bleibt das
## Feld dunkel. Kein Wirbel, kein Meteor - ein Katalysator wirft nichts aus.
func inject(delay: float = 0.0) -> void:
	_state = 4
	_time = 0.0
	_delay = maxf(delay, 0.0)
	if _glyph != null and is_instance_valid(_glyph):
		_glyph.visible = false
	set_process(true)
	queue_redraw()

## Der MULTICAST-Schlag: das Portal reißt noch einmal auf und schreibt die Nummer
## der Auslösung hinein. Erst danach fährt ihr Meteor heraus.
func multicast(trigger: int) -> void:
	_multicast = maxi(trigger, 2)
	_state = 3
	_time = 0.0
	_delay = 0.0
	_sync_mark()
	set_process(true)
	queue_redraw()

## Läuft gerade ein Wirbel, sein Blitz oder ein Multicast-Schlag?
func running() -> bool:
	return _state != 0

## Wie weit oben in der Kette dieser Schlag steht (0 bei ×2 ... 1 bei der höchsten
## Decke der Leiter). Gemessen am Maximum, nicht am Limit dieser Lizenzstufe: die
## Rampe soll über den ganzen Lauf dieselbe Sprache sprechen.
func _ramp() -> float:
	var span := float(maxi(PhantomPress.max_cap() - 2, 1))
	return clampf(float(_multicast - 2) / span, 0.0, 1.0)

func _process(delta: float) -> void:
	if _delay > 0.0:
		_delay = maxf(_delay - delta, 0.0)
		return
	_time += delta
	if _state == 1 and _time >= SWIRL_TIME:
		_state = 2
		_time = 0.0
	elif _state == 2 and _time >= DISCHARGE_TIME:
		_state = 0
		set_process(false)
	elif _state == 3:
		_sync_mark()
		if _time >= MULTICAST_TIME:
			_state = 0
			_multicast = 0
			_sync_mark()
			set_process(false)
	elif _state == 4 and _time >= INJECT_TIME:
		_state = 0
		set_process(false)
	queue_redraw()

## Die Zahl im Portal: sie schlägt auf, wächst mit der Auslösung und verglimmt.
func _sync_mark() -> void:
	if _multicast < 2:
		if _mark != null and is_instance_valid(_mark):
			_mark.visible = false
		return
	var side := minf(size.x, size.y)
	if _mark == null or not is_instance_valid(_mark):
		_mark = Label.new()
		_mark.name = "MulticastMark"
		_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_mark)
	var ramp := _ramp()
	_mark.visible = true
	_mark.text = "×%d" % _multicast
	CasinoStyle.style_score_label(_mark,
		maxi(8, int(side * MULTICAST_MARK_SHARE * (0.82 + 0.30 * ramp))), CasinoStyle.CREAM)
	var progress := clampf(_time / MULTICAST_TIME, 0.0, 1.0)
	var tint: Color = PackDrawerView.COLORS.get(sort, CasinoStyle.CHARGE)
	var peak := 1.0 + (MULTICAST_PEAK - 1.0) * ramp * (1.0 - progress)
	_mark.modulate = Color(minf(tint.r * peak + 0.45, MULTICAST_PEAK),
		minf(tint.g * peak + 0.45, MULTICAST_PEAK),
		minf(tint.b * peak + 0.45, MULTICAST_PEAK), 1.0 - progress * progress)

func _draw() -> void:
	if _state == 0 or _delay > 0.0:
		return
	var tint: Color = PackDrawerView.COLORS.get(sort, CasinoStyle.CHARGE)
	var middle := size * 0.5
	var reach := minf(size.x, size.y) * 0.5
	if _state == 4:
		# Die Einspeisung: ein kurzer Kern, der aufreißt und sofort wieder erlischt.
		var beat := clampf(_time / INJECT_TIME, 0.0, 1.0)
		var fade := 1.0 - beat
		draw_circle(middle, reach * (0.18 + 0.62 * beat),
			Color(tint.r, tint.g, tint.b, fade * fade * 0.7))
		draw_arc(middle, maxf(reach * (0.25 + 0.70 * beat), 1.0), 0.0, TAU, 28,
			Color(tint.r, tint.g, tint.b, fade * 0.9), maxf(reach * 0.08, 1.0), true)
		return
	if _state == 3:
		# Ein Ring fährt von innen nach außen - je höher die Auslösung, desto weiter.
		var beat := clampf(_time / MULTICAST_TIME, 0.0, 1.0)
		var span := reach * (0.45 + MULTICAST_RING * 0.55 * _ramp()) * beat
		draw_arc(middle, maxf(span, 1.0), 0.0, TAU, 32,
			Color(tint.r, tint.g, tint.b, (1.0 - beat) * 0.8),
			maxf(reach * 0.06, 1.0), true)
		return
	if _state == 2:
		var fade := 1.0 - clampf(_time / DISCHARGE_TIME, 0.0, 1.0)
		draw_circle(middle, reach * (0.25 + 0.75 * (1.0 - fade)),
			Color(tint.r, tint.g, tint.b, fade * 0.55))
		return
	var progress := clampf(_time / SWIRL_TIME, 0.0, 1.0)
	var pull := pow(progress, 1.6)  # er zieht zum Schluss an
	var radius := reach * START_RADIUS * (1.0 - pull)
	var dot := reach * DOT_SHARE * (1.0 + progress * 0.5)
	for i in _dots:
		var angle := TAU * float(i) / float(_dots) + TAU * TURNS * pull
		var at := middle + Vector2(cos(angle), sin(angle)) * radius
		draw_circle(at, dot, Color(tint.r, tint.g, tint.b, 0.35 + 0.6 * progress))
