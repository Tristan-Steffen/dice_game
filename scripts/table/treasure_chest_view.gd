class_name TreasureChestView
extends Control
## Der Schatz-Screen: ein licht-goldenes "offene Truhe"-Fenster, AUF dem der
## physische Chip-Turm steht (die echten Chips sind das Gold in der Truhe).
## Rein zeichnend; bei Geldzuwachs glänzt die Truhe kurz auf (glint). Alle Maße
## leiten sich aus der eigenen Größe ab.

const GOLD := Color("#ffd36a")
const FILL := Color(0.17, 0.12, 0.03, 0.86)      # warmer Truhen-Innenraum

## Zwei Münzschlitze vorne unter dem Turm: links wird gezahlt (Chips sinken
## hinein), rechts kommt herein / kommt Wechselgeld heraus.
const PAY_SLOT_FRAC := Vector2(0.32, 0.80)
const RECEIVE_SLOT_FRAC := Vector2(0.68, 0.80)
## Richtungs-Farben der Schlitze: Einwurf warm (Chips verlassen den Spieler),
## Ausgabe neon-grün (Chips kommen zum Spieler).
const PAY_ACCENT := Color(1.0, 0.55, 0.35)
const RECEIVE_ACCENT := Color(0.32, 0.94, 0.58)

var _glint := 0.0  # 0..1 Aufglänzen bei Zuwachs
var _glint_tween: Tween
var _pay_flash := 0.0      # 0..1 Aufleuchten des Auszahlungs-Schlitzes
var _pay_color := GOLD
var _pay_tween: Tween
var _rec_flash := 0.0      # 0..1 Aufleuchten des Einzahlungs-Schlitzes
var _rec_color := GOLD
var _rec_tween: Tween

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

## Aufleuchten des Auszahlungs-Schlitzes in Chip-Farbe (ein Chip sinkt hinein).
func flash_pay_slot(color: Color) -> void:
	_pay_color = color
	if _pay_tween != null:
		_pay_tween.kill()
	_pay_tween = create_tween()
	_pay_tween.tween_method(func(v: float) -> void:
		_pay_flash = v
		queue_redraw(), 1.0, 0.0, 0.45).set_trans(Tween.TRANS_SINE)

## Aufleuchten des Einzahlungs-Schlitzes (ein Chip / Wechselgeld tritt heraus).
func flash_receive_slot(color: Color) -> void:
	_rec_color = color
	if _rec_tween != null:
		_rec_tween.kill()
	_rec_tween = create_tween()
	_rec_tween.tween_method(func(v: float) -> void:
		_rec_flash = v
		queue_redraw(), 1.0, 0.0, 0.45).set_trans(Tween.TRANS_SINE)

## Schlitz-Mitten in eigenen Pixeln (Prägungs-/Absorptionspunkte).
func pay_slot_center() -> Vector2:
	return Vector2(size.x * PAY_SLOT_FRAC.x, size.y * PAY_SLOT_FRAC.y)

func receive_slot_center() -> Vector2:
	return Vector2(size.x * RECEIVE_SLOT_FRAC.x, size.y * RECEIVE_SLOT_FRAC.y)

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

	# Zwei Münzschlitze: links EINWURF (Chips sinken hinein, warme Akzente,
	# Pfeile zeigen in den Schlitz), rechts AUSGABE (Chips treten heraus,
	# grüne Akzente, Pfeile zeigen heraus).
	_draw_slot(u, pay_slot_center(), PAY_ACCENT, "EINWURF", true, _pay_color, _pay_flash)
	_draw_slot(u, receive_slot_center(), RECEIVE_ACCENT, "AUSGABE", false, _rec_color, _rec_flash)

## Ein Münzschlitz als Beschlag: dunkle Metall-Blende mit goldenem Saum, darin
## der eigentliche Schlitz mit unterer Lichtkante in der Richtungs-Farbe,
## Richtungs-Pfeile (hinein/heraus) und Gravur-Schriftzug. Bei Aktivität
## leuchtet alles in der Chip-Farbe auf (samt Halo).
func _draw_slot(u: float, c: Vector2, accent: Color, caption: String,
		inward: bool, flash_color: Color, flash: float) -> void:
	var w := u * 13.0
	var h := u * 6.2
	var bezel := Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
	var live := accent.lerp(flash_color.lerp(Color(2.4, 2.0, 1.1), 0.35), flash)

	# Farbiger Halo bei Aktivität (unter der Blende gezeichnet).
	if flash > 0.01:
		var halo := StyleBoxFlat.new()
		halo.bg_color = Color(flash_color.r, flash_color.g, flash_color.b, flash * 0.30)
		halo.set_corner_radius_all(int(u * 3.0))
		draw_style_box(halo, bezel.grow(u * (1.2 + flash * 2.6)))

	# Metall-Blende mit Doppelrand (außen Gold, innen dunkle Fuge).
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.10, 0.085, 0.13, 0.96)
	plate.border_color = GOLD.lerp(live, 0.35 + flash * 0.65)
	plate.set_border_width_all(maxi(2, int(u * 0.35)))
	plate.set_corner_radius_all(int(u * 1.4))
	draw_style_box(plate, bezel)
	var groove := StyleBoxFlat.new()
	groove.draw_center = false
	groove.border_color = Color(0.0, 0.0, 0.02, 0.8)
	groove.set_border_width_all(maxi(1, int(u * 0.18)))
	groove.set_corner_radius_all(int(u * 1.1))
	draw_style_box(groove, bezel.grow(-u * 0.5))

	# Der Schlitz selbst: tiefschwarz, unten eine Lichtkante in Richtungs-Farbe.
	var sw := u * 8.6
	var sh := u * 1.7
	var sy := c.y - u * 0.9
	var slit := Rect2(c.x - sw * 0.5, sy - sh * 0.5, sw, sh)
	var mouth := StyleBoxFlat.new()
	mouth.bg_color = Color(0.015, 0.015, 0.035)
	mouth.set_corner_radius_all(int(sh * 0.5))
	draw_style_box(mouth, slit)
	draw_rect(Rect2(slit.position.x + u * 0.8, slit.end.y - u * 0.35,
		sw - u * 1.6, u * 0.3), Color(live.r, live.g, live.b, 0.75 + flash * 0.25))

	# Richtungs-Pfeile neben dem Schlitz: hinein (▼) bzw. heraus (▲).
	var ay := sy
	var aw := u * 1.1
	var ah := u * 0.9 * (1.0 if inward else -1.0)
	for side: float in [-1.0, 1.0]:
		var ax := c.x + side * (sw * 0.5 + u * 1.6)
		draw_colored_polygon(PackedVector2Array([
			Vector2(ax - aw, ay - ah * 0.5), Vector2(ax + aw, ay - ah * 0.5),
			Vector2(ax, ay + ah * 0.5)]), live)

	# Gravur-Schriftzug unter dem Schlitz.
	var font := ThemeDB.fallback_font
	var fsize := maxi(8, int(u * 2.1))
	var tw := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize).x
	draw_string(font, Vector2(c.x - tw * 0.5, c.y + u * 2.2), caption,
		HORIZONTAL_ALIGNMENT_CENTER, -1, fsize,
		Color(live.r, live.g, live.b, 0.85))

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
