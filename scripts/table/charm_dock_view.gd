class_name CharmDockView
extends Control
## Charm-Dock: schmales Terminal-Fenster unter der (3D-)Charm-Reihe. Je fester
## Platz EIN getrenntes Kontakt-Pad - so bleibt bei der Zählung erkennbar, aus
## welchem Charm das Licht stammt (Pads mit Lücke). Belegte Pads leuchten in der
## Raritätsfarbe, leere bleiben dunkle Sockel. Rein zeichnend; scene_root hält es
## über set_charms synchron, die Zähl-Animation ruft flash_pad + pad_center.

## Rand des Fensters um die äußersten Pads (Screen-px, SUPERSAMPLE-Raum).
const DOCK_MARGIN := 18.0 * TableScreen.SUPERSAMPLE
const SOCKET_FILL := Color(0.05, 0.05, 0.10, 0.85)     # leeres Pad = dunkler Sockel
const SOCKET_BORDER := Color(0.72, 0.76, 0.86, 0.18)   # kaum sichtbarer Saum

## Pad-Mitten als lokale Offsets (Fenster-relativ) und je Platz Rarität/Flash.
var _pad_offsets: PackedVector2Array = PackedVector2Array()
var _pad_size := Vector2.ZERO
var _occupied := 0
var _pad_colors: Array[Color] = []
var _flash: Array[float] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Spannt das Dock über die (Viewport-)Pad-Mitten auf; pad_size = Kachelgröße.
## NACH dem Platzieren rufen (die Plätze liegen fest, unabhängig vom Besitz).
func place(pad_centers_px: PackedVector2Array, pad_size: Vector2) -> void:
	if pad_centers_px.is_empty():
		return
	_pad_size = pad_size
	var r := Rect2(pad_centers_px[0] - pad_size / 2.0, pad_size)
	for c in pad_centers_px:
		r = r.merge(Rect2(c - pad_size / 2.0, pad_size))
	r = r.grow(DOCK_MARGIN)
	position = r.position
	size = r.size
	_pad_offsets = PackedVector2Array()
	for c in pad_centers_px:
		_pad_offsets.append(c - position)
	_flash.resize(_pad_offsets.size())
	_flash.fill(0.0)
	queue_redraw()

## Übernimmt Belegung + Raritätsfarben (Reihenfolge = Besitz), damit belegte Pads
## in ihrer Farbe leuchten. Überzählige Charms (> Plätze) werden abgeschnitten.
func set_charms(charms: Array[Charm]) -> void:
	_occupied = mini(charms.size(), _pad_offsets.size())
	_pad_colors.clear()
	for i in _occupied:
		_pad_colors.append(Charm.RARITY_COLORS.get(charms[i].rarity,
			Charm.RARITY_COLORS[Charm.RARITY_COMMON]))
	queue_redraw()

## Viewport-Mitte des Pads i (Quelle des Zähl-Lichts).
func pad_center(i: int) -> Vector2:
	if i < 0 or i >= _pad_offsets.size():
		return position + size / 2.0
	return position + _pad_offsets[i]

## Kurzer Helligkeits-Puls auf Pad i ("dieser Charm feuert") - synchron zum
## 3D-flash_charm.
func flash_pad(i: int) -> void:
	if i < 0 or i >= _flash.size():
		return
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_flash[i] = v
		queue_redraw(), 1.0, 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	if _pad_offsets.is_empty():
		return
	draw_style_box(TableScreen.window_style(), Rect2(Vector2.ZERO, size))
	var radius := int(_pad_size.y * 0.28)
	for i in _pad_offsets.size():
		var occupied := i < _occupied
		var accent: Color = _pad_colors[i] if occupied else SOCKET_BORDER
		var fill := SOCKET_FILL
		if occupied:
			fill = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.9)
		var flash: float = _flash[i] if i < _flash.size() else 0.0
		if flash > 0.0:
			# Im Puls überhell in Richtung Akzentfarbe (bloomt).
			fill = fill.lerp(Color(accent.r * 2.0, accent.g * 2.0, accent.b * 2.0, 1.0), flash)
			accent = accent.lerp(Color(2.2, 2.2, 2.2), flash * 0.6)
		var pad := StyleBoxFlat.new()
		pad.bg_color = fill
		pad.border_color = accent
		pad.set_border_width_all(maxi(1, int(_pad_size.y * 0.06)))
		pad.set_corner_radius_all(radius)
		draw_style_box(pad, Rect2(_pad_offsets[i] - _pad_size / 2.0, _pad_size))
