class_name SigilRenderer
extends Control
## Zeichnet ein Upgrade als Lichtgravur-Siegel: dunkle Rauchglas-Kachel,
## Seltenheits-Lichtsaum, Monoline-Sigil mit Glow. Vollständig prozedural
## (_draw), damit Board-Thumb und Reveal-Größe aus einer Quelle kommen.
## ignite (0..1) lässt die Gravur wie eine Zündschnur entlanglaufen.

const TILE_BG := Color("#0c1018")
const TILE_HIGHLIGHT := Color(1, 1, 1, 0.045)
const ETCH_COLOR := Color("#8be9fd")
const GOLD := Color("#ffd319")
## Seltenheit -> Farbe des Lichtsaums.
const SEAM_COLORS := {
	Coupon.Rarity.COMMON: Color(0.78, 0.81, 0.88, 0.55),
	Coupon.Rarity.UNCOMMON: Color("#8be9fd"),
	Coupon.Rarity.RARE: Color("#ffd319"),
}
## Unbeleuchtete Gravur-Rille (nicht besessen / noch nicht gezündet).
const CHANNEL_COLOR := Color(0.32, 0.36, 0.46, 0.4)
const RARE_PULSE_PERIOD := 2.0

const KIND_MONEY := "money"  # Sonderfall: Wert-Plakette statt Kachel

var coupon_id: String = ""
var kind: String = Coupon.KIND_ETCHING
var rarity: int = Coupon.Rarity.COMMON
var accent: Color = ETCH_COLOR  # Sigil-Farbe (Material-Tint bei Material/Kanten)
var owned: bool = true
var ignite: float = 1.0:
	set(value):
		ignite = clampf(value, 0.0, 1.0)
		queue_redraw()

var _pulse_time := 0.0

static func for_coupon(coupon: Coupon) -> SigilRenderer:
	var sigil := SigilRenderer.new()
	sigil.coupon_id = coupon.id
	sigil.kind = coupon.kind
	sigil.rarity = coupon.rarity
	if coupon.kind == Coupon.KIND_MATERIAL or coupon.kind == Coupon.KIND_EDGE:
		sigil.accent = DieMaterial.tint_for(coupon.material_id())
	return sigil

static func for_money() -> SigilRenderer:
	var sigil := SigilRenderer.new()
	sigil.kind = KIND_MONEY
	sigil.rarity = Coupon.Rarity.COMMON
	sigil.accent = GOLD
	return sigil

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(rarity == Coupon.Rarity.RARE and owned)

func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()

# --- Zeichnen ---------------------------------------------------------------------

func _draw() -> void:
	if kind == KIND_MONEY:
		_draw_plaque()
		return
	_draw_tile()
	_draw_seam()
	_draw_sigil()

## Kachel: Rauchglas mit leichtem Licht von oben (gestufter Pseudo-Verlauf,
## damit keine harte Kante entsteht).
func _draw_tile() -> void:
	var radius := _corner_radius()
	draw_style_box(_box(TILE_BG, radius), Rect2(Vector2.ZERO, size))
	for i in 4:
		var band := _box(Color(1, 1, 1, TILE_HIGHLIGHT.a * (1.0 - i * 0.22)), radius)
		draw_style_box(band, Rect2(Vector2.ZERO, Vector2(size.x, size.y * (0.2 + i * 0.12))))

## Lichtsaum: trägt die Seltenheit; seltene Siegel atmen langsam.
func _draw_seam() -> void:
	if not owned:
		return
	var color: Color = SEAM_COLORS[rarity]
	if rarity == Coupon.Rarity.RARE:
		var breath := 0.75 + 0.25 * sin(_pulse_time * TAU / RARE_PULSE_PERIOD)
		color.a *= breath
	var width := maxf(1.0, size.x * 0.022)
	var radius := _corner_radius()
	# Weicher Außen-Glow + scharfer Saum.
	draw_style_box(_border_box(Color(color.r, color.g, color.b, color.a * 0.22), width * 3.0, radius), Rect2(Vector2.ZERO, size))
	draw_style_box(_border_box(color, width, radius), Rect2(Vector2.ZERO, size))

func _draw_sigil() -> void:
	match kind:
		Coupon.KIND_MATERIAL:
			_draw_material_core()
		Coupon.KIND_EDGE:
			_draw_edge_frame()
		_:
			_draw_strokes(_strokes_for(coupon_id))

## Ätzungs-Sigil: Monoline-Pfade, mit ignite als Zündschnur entlang der Gesamtlänge.
func _draw_strokes(strokes: Array) -> void:
	var total := 0.0
	for stroke: PackedVector2Array in strokes:
		total += _stroke_length(stroke)
	var budget := total * ignite
	for stroke: PackedVector2Array in strokes:
		var length := _stroke_length(stroke)
		if not owned:
			_draw_stroke(stroke, CHANNEL_COLOR, false)
		elif budget >= length:
			_draw_stroke(stroke, accent, true)
		else:
			# Rest liegt als dunkle Rille da; der gezündete Teil leuchtet.
			_draw_stroke(stroke, CHANNEL_COLOR, false)
			if budget > 0.0:
				_draw_stroke(_partial(stroke, budget), accent, true)
		budget = maxf(0.0, budget - length)

## Ein Pfad in 3 Pässen: breiter Schein, enger Schein, Kernlinie.
func _draw_stroke(points: PackedVector2Array, color: Color, glow: bool) -> void:
	if points.size() < 2:
		return
	var px := _scaled(points)
	var w := _stroke_width()
	if glow:
		draw_polyline(px, Color(color.r, color.g, color.b, 0.08), w * 5.0, true)
		draw_polyline(px, Color(color.r, color.g, color.b, 0.22), w * 2.4, true)
	draw_polyline(px, color, w, true)

## Material: Ring + gefüllter Lichtkern im Material-Tint. Die Kernform
## unterscheidet die Materialien zusätzlich zur Farbe (Farben liegen z.T. nah
## beieinander). coupon_id ist hier die Material-id.
func _draw_material_core() -> void:
	var ring_color := accent if owned else CHANNEL_COLOR
	# Ring deutlich vom Kern abgesetzt, sonst verschmilzt beides zum Klecks.
	_draw_stroke(_circle_points(Vector2(0.5, 0.5), 0.33), ring_color, owned)
	var lit := Color(accent.r, accent.g, accent.b, ignite) if owned \
		else Color(CHANNEL_COLOR.r, CHANNEL_COLOR.g, CHANNEL_COLOR.b, 0.25)
	var mid := Vector2(0.5, 0.5)
	match coupon_id:
		DieMaterial.RUBY:  # Edelstein: spitzer Diamant
			_fill_poly(_diamond(mid, 0.17), lit)
		DieMaterial.AMBER:  # Kristall: Sechseck
			_fill_poly(_ngon(mid, 0.15, 6), lit)
		DieMaterial.BONE:  # Fläche: gefülltes Quadrat
			_fill_poly(_square_poly(mid, 0.125), lit)
		DieMaterial.MERCURY:  # Tropfen: zwei Kugeln
			_fill_circle(Vector2(0.41, 0.5), 0.078, lit)
			_fill_circle(Vector2(0.59, 0.5), 0.078, lit)
		DieMaterial.GLASS:  # klar: hohler Diamant
			var frame := _close(_diamond(mid, 0.16))
			if owned:
				_draw_strokes([frame])
			else:
				_draw_stroke(frame, CHANNEL_COLOR, false)
		_:  # Gold u.a.: Münz-Kreis
			_fill_circle(mid, 0.115, lit)

## Kanten: leuchtender Innen-Rahmen, Mitte bleibt leer.
func _draw_edge_frame() -> void:
	var inset := 0.20
	var frame := PackedVector2Array([
		Vector2(inset, inset), Vector2(1.0 - inset, inset),
		Vector2(1.0 - inset, 1.0 - inset), Vector2(inset, 1.0 - inset),
		Vector2(inset, inset),
	])
	if owned:
		_draw_strokes([frame])
	else:
		_draw_stroke(frame, CHANNEL_COLOR, false)

## Geld: rechteckige Wert-Plakette, graviertes $-Zeichen.
func _draw_plaque() -> void:
	var radius := _corner_radius() * 0.7
	draw_style_box(_box(Color("#141008"), radius), Rect2(Vector2.ZERO, size))
	draw_style_box(_box(TILE_HIGHLIGHT, radius), Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.45)))
	var seam := GOLD if owned else CHANNEL_COLOR
	var width := maxf(1.0, size.y * 0.03)
	if owned:
		draw_style_box(_border_box(Color(seam.r, seam.g, seam.b, 0.22), width * 3.0, radius), Rect2(Vector2.ZERO, size))
	draw_style_box(_border_box(seam, width, radius), Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	var font_size := int(size.y * 0.52)
	var text := "$"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
	var pos := Vector2((size.x - text_size.x) * 0.5, (size.y + text_size.y * 0.62) * 0.5)
	var ink := GOLD if owned else CHANNEL_COLOR
	if owned:
		draw_circle(size * 0.5, size.y * 0.34, Color(GOLD.r, GOLD.g, GOLD.b, 0.10 * ignite))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(ink.r, ink.g, ink.b, ink.a * (0.35 + 0.65 * ignite)))

# --- Sigil-Geometrie (Einheitsraum 0..1) --------------------------------------------

## Pfade je Ätzungs-id. Wiederkehrendes Atom: kleines Quadrat = eine Würfelseite;
## + / − = die Wertänderung, Pfeil = Übertrag, "=" = frei gesetzter Wert.
func _strokes_for(id: String) -> Array:
	match id:
		Coupon.CHISEL:
			# Quelle-Quadrat, Bogenpfeil hinüber, Ziel-Quadrat.
			return [
				_square(Vector2(0.27, 0.66), 0.115),
				_arc(Vector2(0.27, 0.48), Vector2(0.5, 0.16), Vector2(0.73, 0.48)),
				_arrow_head(Vector2(0.73, 0.48), Vector2(0.085, 0.115)),
				_square(Vector2(0.73, 0.66), 0.115),
			]
		Coupon.MIRROR:
			# Achse in der Mitte, gespiegelte Quadrate links/rechts.
			return [
				_seg(Vector2(0.5, 0.18), Vector2(0.5, 0.82)),
				_square(Vector2(0.29, 0.5), 0.125),
				_square(Vector2(0.71, 0.5), 0.125),
			]
		Coupon.GRINDSTONE:
			# −1 auf eine, +1 auf eine andere Seite.
			var s: Array = [_square(Vector2(0.29, 0.5), 0.135), _square(Vector2(0.71, 0.5), 0.135)]
			s.append_array(_minus(Vector2(0.29, 0.5), 0.06))
			s.append_array(_plus(Vector2(0.71, 0.5), 0.06))
			return s
		Coupon.FILE_DOWN:
			# Eine Seite −1.
			var s: Array = [_square(Vector2(0.5, 0.5), 0.17)]
			s.append_array(_minus(Vector2(0.5, 0.5), 0.08))
			return s
		Coupon.DOUBLE_NOTCH:
			# Zwei Seiten je +1.
			var s: Array = [_square(Vector2(0.29, 0.5), 0.135), _square(Vector2(0.71, 0.5), 0.135)]
			s.append_array(_plus(Vector2(0.29, 0.5), 0.06))
			s.append_array(_plus(Vector2(0.71, 0.5), 0.06))
			return s
		Coupon.OVERCOUNT_ENGRAVING:
			# +1, dessen Stiel die obere Kante durchstößt (darf über 6).
			return [
				_square(Vector2(0.5, 0.6), 0.16),
				_seg(Vector2(0.5, 0.52), Vector2(0.5, 0.16)),
				_seg(Vector2(0.4, 0.27), Vector2(0.6, 0.27)),
			]
		Coupon.FINE_ENGRAVING:
			# Freier Zielwert: Quadrat mit "=".
			var s: Array = [_square(Vector2(0.5, 0.5), 0.18)]
			s.append_array(_equals(Vector2(0.5, 0.5), 0.08))
			return s
		Coupon.TRANSPLANT:
			# Kleine Seite -> Pfeil hoch -> große Seite (Höchstwert).
			var s: Array = [_square(Vector2(0.5, 0.73), 0.09), _square(Vector2(0.5, 0.29), 0.15)]
			s.append_array(_up_arrow(Vector2(0.5, 0.62), Vector2(0.5, 0.47)))
			return s
		Coupon.CONNECT_UP:
			# Quelle -> Ziel, +1 sitzt auf der Verbindung.
			return [
				_square(Vector2(0.27, 0.5), 0.12), _square(Vector2(0.73, 0.5), 0.12),
				_seg(Vector2(0.39, 0.5), Vector2(0.61, 0.5)),
				_seg(Vector2(0.5, 0.4), Vector2(0.5, 0.6)),
			]
		Coupon.AVERAGING:
			# Zwei Seiten treffen sich in der Mitte (Mittelwert).
			var s: Array = [_square(Vector2(0.22, 0.5), 0.11), _square(Vector2(0.78, 0.5), 0.11),
				_seg(Vector2(0.5, 0.35), Vector2(0.5, 0.65))]
			s.append_array(_arrow_to(Vector2(0.33, 0.5), Vector2(0.44, 0.5)))
			s.append_array(_arrow_to(Vector2(0.67, 0.5), Vector2(0.56, 0.5)))
			return s
		Coupon.IMPRINT:
			# Obere Seite prägt sich auf die zwei niedrigsten unten.
			var s: Array = [_square(Vector2(0.5, 0.27), 0.13),
				_square(Vector2(0.32, 0.71), 0.1), _square(Vector2(0.68, 0.71), 0.1)]
			s.append_array(_arrow_to(Vector2(0.45, 0.42), Vector2(0.36, 0.58)))
			s.append_array(_arrow_to(Vector2(0.55, 0.42), Vector2(0.64, 0.58)))
			return s
		Coupon.STRAIGHTEN:
			# Treppe aufwärts: ungerade Seiten +1.
			return [_staircase()]
		Coupon.BLUEPRINT:
			# Ganzer Würfel auf einen Wert: 3x2-Raster leuchtet.
			return _grid()
		_:
			return [_square(Vector2(0.5, 0.5), 0.16)]

# --- Sigil-Primitive (Einheitsraum) -------------------------------------------------

func _seg(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b])

func _plus(center: Vector2, radius: float) -> Array:
	return [_seg(center + Vector2(-radius, 0), center + Vector2(radius, 0)),
		_seg(center + Vector2(0, -radius), center + Vector2(0, radius))]

func _minus(center: Vector2, radius: float) -> Array:
	return [_seg(center + Vector2(-radius, 0), center + Vector2(radius, 0))]

func _equals(center: Vector2, radius: float) -> Array:
	return [_seg(center + Vector2(-radius, -radius * 0.45), center + Vector2(radius, -radius * 0.45)),
		_seg(center + Vector2(-radius, radius * 0.45), center + Vector2(radius, radius * 0.45))]

## Linie a->b plus Pfeilspitze bei b (nach oben zeigend).
func _up_arrow(a: Vector2, b: Vector2) -> Array:
	return [_seg(a, b), PackedVector2Array([b + Vector2(-0.05, 0.055), b, b + Vector2(0.05, 0.055)])]

## Kurze Linie a->b mit Pfeilspitze bei b (beliebige Richtung).
func _arrow_to(a: Vector2, b: Vector2) -> Array:
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var back := b - dir * 0.055
	return [_seg(a, b), PackedVector2Array([back + perp * 0.045, b, back - perp * 0.045])]

## Aufsteigende Treppe (Begradigung).
func _staircase() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.18, 0.75), Vector2(0.37, 0.75), Vector2(0.37, 0.57),
		Vector2(0.57, 0.57), Vector2(0.57, 0.39), Vector2(0.77, 0.39), Vector2(0.77, 0.23),
	])

## 3x2-Raster kleiner Seiten (Blaupause).
func _grid() -> Array:
	var squares: Array = []
	for y in [0.38, 0.62]:
		for x in [0.3, 0.5, 0.7]:
			squares.append(_square(Vector2(x, y), 0.078))
	return squares

func _square(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-half, -half), center + Vector2(half, -half),
		center + Vector2(half, half), center + Vector2(-half, half),
		center + Vector2(-half, -half),
	])

## Quadratische Bezier von a über Kontrollpunkt c nach b.
func _arc(a: Vector2, c: Vector2, b: Vector2, steps := 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		points.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return points

func _arrow_head(tip: Vector2, spread: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		tip + Vector2(-spread.x * 1.4, -spread.y), tip, tip + Vector2(-spread.x, spread.y * 0.4),
	])

func _circle_points(center: Vector2, radius: float, steps := 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0)])

func _square_poly(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(-half, -half), center + Vector2(half, -half),
		center + Vector2(half, half), center + Vector2(-half, half)])

## Regelmäßiges n-Eck, Spitze nach oben.
func _ngon(center: Vector2, radius: float, n: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in n:
		var angle := -PI / 2.0 + TAU * float(i) / float(n)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _close(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out

## Gefüllter Kreis-Kern mit weichem Glow-Halo.
func _fill_circle(center_u: Vector2, radius_u: float, lit: Color) -> void:
	var c := _unit_to_px(center_u)
	var r := radius_u * _content_side()
	draw_circle(c, r * 1.8, Color(lit.r, lit.g, lit.b, lit.a * 0.12))
	draw_circle(c, r * 1.3, Color(lit.r, lit.g, lit.b, lit.a * 0.25))
	draw_circle(c, r, lit)

## Gefülltes Polygon mit weichem Glow-Halo (um den Schwerpunkt skaliert).
func _fill_poly(points_u: PackedVector2Array, lit: Color) -> void:
	var center := _poly_center(points_u)
	draw_colored_polygon(_scaled(_scale_about(points_u, center, 1.7)), Color(lit.r, lit.g, lit.b, lit.a * 0.12))
	draw_colored_polygon(_scaled(_scale_about(points_u, center, 1.3)), Color(lit.r, lit.g, lit.b, lit.a * 0.25))
	draw_colored_polygon(_scaled(points_u), lit)

func _poly_center(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / float(points.size())

func _scale_about(points: PackedVector2Array, center: Vector2, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(center + (p - center) * factor)
	return out

func _unit_to_px(p: Vector2) -> Vector2:
	return _scaled(PackedVector2Array([p]))[0]

# --- Helfer -----------------------------------------------------------------------

## Einheitsraum -> Pixel: quadratischer Inhalt, mittig in der Kachel.
func _scaled(points: PackedVector2Array) -> PackedVector2Array:
	var side := _content_side()
	var origin := (size - Vector2.ONE * side) * 0.5
	var result := PackedVector2Array()
	for p in points:
		result.append(origin + p * side)
	return result

func _content_side() -> float:
	return minf(size.x, size.y)

func _stroke_width() -> float:
	return maxf(1.5, _content_side() * 0.045)

func _corner_radius() -> int:
	return maxi(3, int(_content_side() * 0.14))

func _stroke_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	return length

## Anfangsstück eines Pfads mit gegebener Länge (für die Zündschnur).
func _partial(points: PackedVector2Array, budget: float) -> PackedVector2Array:
	var result := PackedVector2Array([points[0]])
	for i in range(1, points.size()):
		var seg := points[i - 1].distance_to(points[i])
		if seg <= budget:
			result.append(points[i])
			budget -= seg
		else:
			result.append(points[i - 1].lerp(points[i], budget / maxf(seg, 0.0001)))
			break
	return result

func _box(bg: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	return box

func _border_box(border: Color, width: float, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = border
	box.set_border_width_all(maxi(1, int(width)))
	box.set_corner_radius_all(radius)
	return box
