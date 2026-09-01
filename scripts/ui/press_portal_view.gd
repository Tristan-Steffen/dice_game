class_name PressPortalView
extends Control
## Das GLÜHEN eines Serien-Slots. Ruhig, solange nichts steckt; beim GRIFF läuft
## die Serie kartenweise durch, und jede gesteckte Karte flammt an ihrer Stelle auf
## (charge). Eine OPERATOR-Karte schlägt statt dessen perkussiv zu und schreibt
## ihre Glyphe hinein (punch) - dieselbe Trennung, die auch die Rechnung macht:
## Addition leuchtet, Operator schlägt.
##
## Reine Anzeige: gerechnet und gebucht hat GameRun längst. Läuft nichts, läuft
## auch kein _process - ein stehender Slot kostet nichts.

## Dauer des Aufflammens einer Wert-Karte und des Operator-Schlags. scene_root
## bzw. das Fenster staffeln daran.
const CHARGE_TIME := 0.34
const PUNCH_TIME := 0.42
## Der Ring des Schlags fährt bis hierhin nach außen, die Glyphe steht so groß.
const PUNCH_RING := 1.15
const PUNCH_MARK_SHARE := 0.52
const PUNCH_PEAK := 1.75

var sort := ""
## Amber, sobald ein Operator im Slot steckt - Wert-Karten bleiben in ihrer Sorte.
var accent := CasinoStyle.CHARGE

## 0 = ruhig, 1 = Aufflammen, 2 = Operator-Schlag.
var _state := 0
var _time := 0.0
var _delay := 0.0
## Die Glyphe, die der Schlag schreibt ("" = keiner läuft).
var _glyph := ""
var _mark: Label

func _init() -> void:
	name = "SlotGlow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(false)

## Belegt den Slot mit der Farbe seiner Karte ("" = dunkel).
func setup(pack_sort: String, tint: Color = CasinoStyle.CHARGE) -> void:
	sort = pack_sort
	accent = tint

## Die Welle erreicht diese Karte: sie flammt auf. delay staffelt die Reihe.
func charge(delay: float = 0.0) -> void:
	_state = 1
	_time = 0.0
	_delay = maxf(delay, 0.0)
	set_process(true)
	queue_redraw()

## Der OPERATOR schlägt zu: ein Ring fährt heraus, seine Glyphe steht darin.
func punch(glyph: String, delay: float = 0.0) -> void:
	_glyph = glyph
	_state = 2
	_time = 0.0
	_delay = maxf(delay, 0.0)
	_sync_mark()
	set_process(true)
	queue_redraw()

## Läuft gerade ein Aufflammen oder ein Schlag?
func running() -> bool:
	return _state != 0

func _process(delta: float) -> void:
	if _delay > 0.0:
		_delay = maxf(_delay - delta, 0.0)
		return
	_time += delta
	if _state == 1 and _time >= CHARGE_TIME:
		_state = 0
		set_process(false)
	elif _state == 2:
		_sync_mark()
		if _time >= PUNCH_TIME:
			_state = 0
			_glyph = ""
			_sync_mark()
			set_process(false)
	queue_redraw()

## Die Glyphe im Slot: sie schlägt auf und verglimmt.
func _sync_mark() -> void:
	if _glyph == "":
		if _mark != null and is_instance_valid(_mark):
			_mark.visible = false
		return
	var side := minf(size.x, size.y)
	if _mark == null or not is_instance_valid(_mark):
		_mark = Label.new()
		_mark.name = "OperatorMark"
		_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_mark)
	_mark.visible = true
	_mark.text = _glyph
	CasinoStyle.style_score_label(_mark,
		maxi(8, int(side * PUNCH_MARK_SHARE)), CasinoStyle.CREAM)
	var progress := clampf(_time / PUNCH_TIME, 0.0, 1.0)
	var peak := 1.0 + (PUNCH_PEAK - 1.0) * (1.0 - progress)
	_mark.modulate = Color(minf(accent.r * peak + 0.45, PUNCH_PEAK),
		minf(accent.g * peak + 0.45, PUNCH_PEAK),
		minf(accent.b * peak + 0.45, PUNCH_PEAK), 1.0 - progress * progress)

func _draw() -> void:
	if _state == 0 or _delay > 0.0:
		return
	var middle := size * 0.5
	var reach := minf(size.x, size.y) * 0.5
	if _state == 2:
		# Ein Ring fährt von innen nach außen - der Schlag ist eine Welle, kein Schein.
		var beat := clampf(_time / PUNCH_TIME, 0.0, 1.0)
		draw_arc(middle, maxf(reach * (0.45 + PUNCH_RING * 0.55) * beat, 1.0), 0.0, TAU, 32,
			Color(accent.r, accent.g, accent.b, (1.0 - beat) * 0.8),
			maxf(reach * 0.06, 1.0), true)
		return
	# Das Aufflammen: ein Kern geht auf und erlischt wieder.
	var swell := clampf(_time / CHARGE_TIME, 0.0, 1.0)
	var fade := 1.0 - swell
	draw_circle(middle, reach * (0.2 + 0.8 * swell),
		Color(accent.r, accent.g, accent.b, fade * fade * 0.55))
