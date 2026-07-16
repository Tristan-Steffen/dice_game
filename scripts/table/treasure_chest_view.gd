class_name TreasureChestView
extends Control
## Der Schatz-Screen: ein licht-goldenes "offene Truhe"-Fenster, AUF dem der
## physische Chip-Turm steht (die echten Chips sind das Gold in der Truhe).
## Rein zeichnend; bei Geldzuwachs glänzt die Truhe kurz auf (glint). Alle Maße
## leiten sich aus der eigenen Größe ab.

const GOLD := Color("#ffd36a")
const FILL := Color(0.17, 0.12, 0.03, 0.86)      # warmer Truhen-Innenraum

var _glint := 0.0  # 0..1 Aufglänzen bei Zuwachs
var _glint_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)

## Aufglänzen der Truhe (Einschlag des Geld-Lichts).
func glint() -> void:
	if _glint_tween != null:
		_glint_tween.kill()
	_glint_tween = create_tween()
	_glint_tween.tween_method(func(v: float) -> void:
		_glint = v
		queue_redraw(), 1.0, 0.0, 0.6).set_trans(Tween.TRANS_SINE)

func _draw() -> void:
	var u := maxf(size.x, 200.0) / 100.0
	var radius := int(u * 3.0)
	var accent := GOLD.lerp(Color(2.2, 1.8, 0.9), _glint)  # im Glanz überhell

	# Truhen-Korpus: warme Füllung, goldener Saum (glänzt im Zuwachs).
	var body := StyleBoxFlat.new()
	body.bg_color = FILL
	body.border_color = accent
	body.set_border_width_all(maxi(2, int(u * 0.4)))
	body.set_corner_radius_all(radius)
	draw_style_box(body, Rect2(Vector2.ZERO, size))

	# Eck-Beschläge (goldene Winkel) für den Truhen-Look.
	_draw_corner_fittings(u, accent)

## Kleine goldene Winkel in den vier Ecken (Truhen-Beschläge).
func _draw_corner_fittings(u: float, accent: Color) -> void:
	var m := u * 2.4       # Abstand von der Ecke
	var arm := u * 5.0     # Schenkellänge
	var w := u * 0.9       # Beschlag-Breite
	for corner in [Vector2(m, m), Vector2(size.x - m, m),
			Vector2(m, size.y - m), Vector2(size.x - m, size.y - m)]:
		var sx := 1.0 if corner.x < size.x * 0.5 else -1.0
		var sy := 1.0 if corner.y < size.y * 0.5 else -1.0
		draw_rect(Rect2(corner.x if sx > 0 else corner.x - arm, corner.y - w * 0.5, arm, w), accent)
		draw_rect(Rect2(corner.x - w * 0.5, corner.y if sy > 0 else corner.y - arm, w, arm), accent)
