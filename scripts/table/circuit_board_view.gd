class_name CircuitBoardView
extends Control
## Platinen-Ebene des Kombinationen-Fensters: Leiterbahn-Stummel von jedem
## Chip-Pin in den Zwischenraum, Vias (Lötaugen) an den Enden, senkrechte
## Bus-Linien durch fluchtende Vias BIS AN BEIDE Fensterränder (Randkontakte -
## dort speist der Kauf-Lichtlauf ein, siehe paths_to_cell) und ein paar
## Streu-Lötaugen als Textur. Einmal in setup berechnet (deterministisch).

const TRACE_COLOR := Color(0.545, 0.914, 0.992, 0.20)
const VIA_COLOR := Color(0.545, 0.914, 0.992, 0.45)
const VIA_HOLE := Color("#14112e")
const DOT_COLOR := Color(0.545, 0.914, 0.992, 0.16)
const SCATTER_SEED := 1337
const SCATTER_COUNT := 10

var _seg_from := PackedVector2Array()
var _seg_to := PackedVector2Array()
var _vias := PackedVector2Array()
var _pads := PackedVector2Array()  # Randkontakte an Ober-/Unterkante
var _dots := PackedVector2Array()
var _cell_rects: Array[Rect2] = []
var _stub_len := 9.0
var _trace_width := 2.0
var _via_radius := 4.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Berechnet Bahnen/Vias aus den Zell-Rechtecken (board-lokal); stub_len =
## halber Spaltenabstand, damit sich die Vias benachbarter Chips treffen.
func setup(cell_rects: Array[Rect2], stub_len: float) -> void:
	_seg_from.clear()
	_seg_to.clear()
	_vias.clear()
	_pads.clear()
	_dots.clear()
	_cell_rects = cell_rects
	_stub_len = stub_len
	_trace_width = maxf(2.0, stub_len * 0.24)
	_via_radius = maxf(3.0, stub_len * 0.42)

	# Stummel je Pin, Via am Ende (Pin-Höhen aus ComboCellView.PIN_FRACTIONS).
	var via_ys := {}  # gerundetes x -> Array[float] (fluchtende Via-Höhen)
	for rect in cell_rects:
		for f: float in ComboCellView.PIN_FRACTIONS:
			var y := rect.position.y + rect.size.y * f
			_add_stub(Vector2(rect.position.x, y), Vector2(rect.position.x - stub_len, y), via_ys)
			_add_stub(Vector2(rect.end.x, y), Vector2(rect.end.x + stub_len, y), via_ys)

	# Bus-Linien: fluchtende Vias verbinden und bis an BEIDE Fensterränder
	# durchziehen; die Enden bekommen Randkontakte.
	for key in via_ys:
		var x := float(key)
		_seg_from.append(Vector2(x, 0.0))
		_seg_to.append(Vector2(x, size.y))
		_pads.append(Vector2(x, 0.0))
		_pads.append(Vector2(x, size.y))

	# Streu-Lötaugen zwischen den Chips (deterministisch, nie AUF einem Chip).
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED
	var placed := 0
	for attempt in SCATTER_COUNT * 4:
		if placed >= SCATTER_COUNT:
			break
		var p := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y))
		var free := true
		for rect in cell_rects:
			if rect.grow(stub_len * 0.6).has_point(p):
				free = false
				break
		if free:
			_dots.append(p)
			placed += 1
	queue_redraw()

func _add_stub(from: Vector2, to: Vector2, via_ys: Dictionary) -> void:
	_seg_from.append(from)
	_seg_to.append(to)
	_vias.append(to)
	var key := roundi(to.x)
	if not via_ys.has(key):
		via_ys[key] = []
	via_ys[key].append(to.y)

## Vier Licht-Pfade vom Fensterrand zum Chip index: über die linke und rechte
## Bus-Linie, je von oben UND unten. Alle vier mit derselben Laufzeit gestartet
## treffen sie gleichzeitig ein (Ziel: Gehäusekante auf mittlerer Pin-Höhe).
func paths_to_cell(index: int) -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	if index < 0 or index >= _cell_rects.size():
		return paths
	var rect := _cell_rects[index]
	var y := rect.position.y + rect.size.y * 0.5
	var xl := rect.position.x - _stub_len
	var xr := rect.end.x + _stub_len
	paths.append(PackedVector2Array([Vector2(xl, 0.0), Vector2(xl, y), Vector2(rect.position.x, y)]))
	paths.append(PackedVector2Array([Vector2(xl, size.y), Vector2(xl, y), Vector2(rect.position.x, y)]))
	paths.append(PackedVector2Array([Vector2(xr, 0.0), Vector2(xr, y), Vector2(rect.end.x, y)]))
	paths.append(PackedVector2Array([Vector2(xr, size.y), Vector2(xr, y), Vector2(rect.end.x, y)]))
	return paths

func _draw() -> void:
	for i in _seg_from.size():
		draw_line(_seg_from[i], _seg_to[i], TRACE_COLOR, _trace_width)
	# Vias als Lötaugen: Ring mit dunklem Bohrloch.
	for via in _vias:
		draw_circle(via, _via_radius, VIA_COLOR)
		draw_circle(via, _via_radius * 0.45, VIA_HOLE)
	# Randkontakte: kleine Pads, wo die Busse den Fensterrand treffen.
	for pad in _pads:
		var top := pad.y <= 0.0
		draw_rect(Rect2(pad.x - _via_radius, 0.0 if top else size.y - _via_radius * 1.5,
			_via_radius * 2.0, _via_radius * 1.5), VIA_COLOR)
	for dot in _dots:
		draw_circle(dot, _via_radius * 0.7, DOT_COLOR)
