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

## 0 = ruhig, 1 = Wirbel, 2 = Entladung.
var _state := 0
var _time := 0.0
var _delay := 0.0
var _dots := DOTS_MIN
var _glyph: Control

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
	var icon := PackIconRenderer.for_type(PackShelfView.pack_type_of(sort))
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

## Läuft gerade ein Wirbel oder sein Blitz?
func running() -> bool:
	return _state != 0

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
	queue_redraw()

func _draw() -> void:
	if _state == 0 or _delay > 0.0:
		return
	var tint: Color = PackShelfView.COLORS.get(sort, CasinoStyle.CHARGE)
	var middle := size * 0.5
	var reach := minf(size.x, size.y) * 0.5
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
