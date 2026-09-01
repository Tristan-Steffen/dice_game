class_name SeriesScannerView
extends Control
## Der SCHLITTEN der DURCHLICHT-FAHRT - und der EINE Summen-Träger der Werkbank.
##
## GEPARKT steht er in der ZIEL-SÄULE und trägt dort die Live-Vorschau: die Säule
## IST sein Parkplatz, es gibt keine zweite Netz-Anzeige im Fenster. Beim Griff
## fährt er hinunter auf die Schiene über der Serien-Reihe, geht dort durch jede
## stehende Karte HINDURCH (die Zellen ticken hoch, ein Operator schlägt zu),
## kehrt zum Zielwürfel zurück und faltet sein Netz über ihm zusammen.
##
## Reine Anzeige: gerechnet hat SeriesResolver, gebucht GameRun - längst.

const FRAME_TINT := PressNetView.VALUE_TINT
const OPERATOR_TINT := PressNetView.OPERATOR_TINT
## Die Scheibe hinter dem Netz: sie trägt die Zellen, bleibt aber durchscheinend -
## sonst verschluckte der Schlitten die Karte, durch die er gerade fährt (die
## Ziffern selbst sitzen auf ihren deckenden Zellplatten, nicht auf der Scheibe).
const PANE_BG := Color("#0a0918a6")
## Rahmenluft rings um das Netz, als Anteil einer Zellkante.
const PANE_PAD := 0.18
## Abklingzeiten von Glühen, Zell-Einschlag und Operator-Schlag.
const GLOW_TIME := 0.36
const STRIKE_TIME := 0.44
const PUNCH_TIME := 0.44
## Der Ring des Schlags fährt bis hierhin nach außen, die Glyphe steht so groß.
const PUNCH_RING := 1.2
const PUNCH_MARK_SHARE := 0.42
const PUNCH_PEAK := 1.7

## Das Summen-Netz, das er trägt (sein Display).
var net: PressNetView
var accent := FRAME_TINT

var _riding := false
var _glow := 0.0
var _strike := 0.0
var _strike_faces: Array[int] = []
var _punch := 0.0
var _punch_glyph := ""
var _mark: Label
var _fold := 0.0
var _ride: Tween
var _fold_tween: Tween

func _init() -> void:
	name = "SeriesScanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	net = PressNetView.new()
	add_child(net)
	set_process(false)

## Legt den Schlitten auf ein Zellmaß aus. Das Netz sitzt mittig in der Scheibe,
## also ist die Scheibenmitte zugleich die Netzmitte - daran fährt er.
func lay(cell: float) -> void:
	net.cell = cell
	var pad := cell * PANE_PAD
	net.position = Vector2.ONE * pad
	custom_minimum_size = DieNetView.net_size(cell) + Vector2.ONE * pad * 2.0
	size = custom_minimum_size
	pivot_offset = size * 0.5  # er schrumpft auf der Schiene um seine Mitte
	queue_redraw()

## Fährt er gerade (oder steht er auf der Schiene)? Dann gehört sein Platz der
## Zeremonie, und niemand sonst schreibt ihn.
func riding() -> bool:
	return _riding

## HART auf einen Platz - jede laufende Fahrt stirbt dabei.
func seat_at(net_center: Vector2, at_scale: float = 1.0) -> void:
	_kill(_ride)
	_riding = false
	scale = Vector2.ONE * at_scale
	position = net_center - size * 0.5

## Eine Etappe der Fahrt: Platz und Größe zugleich.
func ride_to(net_center: Vector2, at_scale: float, time: float) -> void:
	_kill(_ride)
	_riding = true
	var target := net_center - size * 0.5
	if time <= 0.0:
		scale = Vector2.ONE * at_scale
		position = target
		return
	_ride = create_tween()
	_ride.set_parallel(true)
	_ride.tween_property(self, "position", target, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ride.tween_property(self, "scale", Vector2.ONE * at_scale, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Der Rahmen glüht auf (Aufbruch, Ankunft, Entladung).
func flare(strength: float = 1.0) -> void:
	_glow = maxf(_glow, clampf(strength, 0.0, 1.0))
	set_process(true)
	queue_redraw()

## Eine WERT-Karte wird durchfahren: ihre Zellen schlagen im Netz ein, und aus der
## Karte darunter zieht je eine kurze Leuchtspur herauf.
func strike(faces: Array[int]) -> void:
	_strike_faces = faces.duplicate()
	_strike = 1.0
	flare(0.85)

## Der OPERATOR schlägt perkussiv zu: ein Ring fährt heraus, seine Glyphe steht
## darin, und die Zellen, die er bewegt hat, schlagen mit ein.
func punch(glyph: String, faces: Array[int]) -> void:
	_punch_glyph = glyph
	_punch = 1.0
	strike(faces)
	_sync_mark()

## Die FALTUNG des Finales: das Netz klappt sich über dem Würfel zusammen.
func fold(time: float) -> void:
	_kill(_fold_tween)
	_fold_tween = create_tween()
	_fold_tween.tween_method(_apply_fold, 0.0, 1.0, maxf(time, 0.01)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _apply_fold(value: float) -> void:
	_fold = value
	net.fold(value)
	queue_redraw()

## Der EINE Aufräum-Pfad: jede Fahrt stirbt, die Faltung geht auf, die Ziffern
## stehen auf ihrem Ziel. Ein abgebrochener Tween schuldet danach nichts.
func settle() -> void:
	_kill(_ride)
	_kill(_fold_tween)
	_riding = false
	_fold = 0.0
	_glow = 0.0
	_strike = 0.0
	_punch = 0.0
	_punch_glyph = ""
	_strike_faces.clear()
	scale = Vector2.ONE
	net.fold(0.0)
	net.settle_ticks()
	_sync_mark()
	set_process(false)
	queue_redraw()

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

func _process(delta: float) -> void:
	_glow = maxf(_glow - delta / GLOW_TIME, 0.0)
	_strike = maxf(_strike - delta / STRIKE_TIME, 0.0)
	_punch = maxf(_punch - delta / PUNCH_TIME, 0.0)
	if _punch <= 0.0:
		_punch_glyph = ""
	_sync_mark()
	queue_redraw()
	if _glow <= 0.0 and _strike <= 0.0 and _punch <= 0.0:
		_strike_faces.clear()
		set_process(false)

## Die Glyphe des Schlags: sie schlägt groß auf und verglimmt.
func _sync_mark() -> void:
	if _punch_glyph == "":
		if _mark != null and is_instance_valid(_mark):
			_mark.visible = false
		return
	if _mark == null or not is_instance_valid(_mark):
		_mark = Label.new()
		_mark.name = "OperatorMark"
		_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_mark)
	_mark.visible = true
	_mark.text = _punch_glyph
	CasinoStyle.style_score_label(_mark,
		maxi(8, int(minf(size.x, size.y) * PUNCH_MARK_SHARE)), CasinoStyle.CREAM)
	var peak := 1.0 + (PUNCH_PEAK - 1.0) * _punch
	_mark.modulate = Color(minf(OPERATOR_TINT.r * peak, PUNCH_PEAK),
		minf(OPERATOR_TINT.g * peak, PUNCH_PEAK),
		minf(OPERATOR_TINT.b * peak, PUNCH_PEAK), _punch)

func _draw() -> void:
	if net == null or not is_instance_valid(net) or net.cell <= 0.0:
		return
	var cell := net.cell
	var pane := Rect2(Vector2.ZERO, size)
	draw_rect(pane, Color(PANE_BG.r, PANE_BG.g, PANE_BG.b, PANE_BG.a * (1.0 - _fold)), true)
	var lit := 0.4 + _glow * 0.6
	var rim := Color(accent.r, accent.g, accent.b, lit * (1.0 - _fold))
	draw_rect(pane, rim, false, maxf(cell * 0.06, 1.0))
	# Ecken-Winkel: der Schlitten liest als GERÄT, nicht als zweites Fenster.
	var arm := minf(size.x, size.y) * 0.16
	var thick := maxf(cell * 0.11, 1.5)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var here := Vector2(corner.x * size.x, corner.y * size.y)
		var into := Vector2(1.0 - corner.x * 2.0, 1.0 - corner.y * 2.0)
		draw_line(here, here + Vector2(into.x * arm, 0.0), rim, thick, true)
		draw_line(here, here + Vector2(0.0, into.y * arm), rim, thick, true)
	_draw_strikes(cell)
	if _punch > 0.0:
		var middle := size * 0.5
		var reach := minf(size.x, size.y) * 0.5
		var beat := 1.0 - _punch
		draw_arc(middle, maxf(reach * (0.4 + PUNCH_RING * 0.6) * beat, 1.0), 0.0, TAU, 40,
			Color(OPERATOR_TINT.r, OPERATOR_TINT.g, OPERATOR_TINT.b, _punch * 0.8),
			maxf(reach * 0.05, 1.0), true)

## Der Einschlag auf den getroffenen Zellen samt der Spur, die von der Karte unter
## dem Schlitten heraufzieht.
func _draw_strikes(cell: float) -> void:
	if _strike <= 0.0:
		return
	var beat := 1.0 - _strike
	var glow := Color(accent.r, accent.g, accent.b, _strike * 0.75)
	for face in _strike_faces:
		var home := net.position + DieNetView.cell_position(face, cell)
		var middle := home + Vector2.ONE * cell * 0.5
		draw_rect(Rect2(home, Vector2.ONE * cell).grow(cell * 0.3 * beat), glow, false,
			maxf(cell * 0.09, 1.0))
		draw_line(Vector2(middle.x, size.y), middle,
			Color(accent.r, accent.g, accent.b, _strike * 0.4), maxf(cell * 0.06, 1.0), true)
