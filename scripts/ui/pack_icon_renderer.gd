class_name PackIconRenderer
extends Control
## Zeichnet das Siegel einer Paketsorte als Monoline-Icon mit Glow - vollständig
## prozedural (_draw), damit Laden-Karte und Lagerkarte aus einer Quelle kommen.
## Je Sorte eine eigene Silhouette:
## Bewusst OHNE Ziffern und Schrift - die Siegel sollen wie Automaten-Symbole
## lesen (siehe auch SlotMachine), und Text bräche diese Sprache.
##   Würfel   - isometrischer Würfel mit Augen
##   Zahlen   - ein großes Auge mit Doppel-Chevron: die Augenzahl steigt
##   Material - facettierter Edelstein
##   Würfel   - nur die vier Ecken eines Rahmens (er fasst den ganzen Würfel)
##   Gemischt - Auge, Stein und Ecke als Mini-Trio in ihren Sortenfarben

## Farbe der Würfel-Gravuren: im gemischten Siegel, auf den Automatenwalzen und
## auf dem Würfel-Gravur-Paket (das nur der Automat ausschüttet).
const DICE_ENGRAVING_COLOR := Color("#ffd319")

## Kanonische Sortenfarbe (Laden und Werkstatt färben ihre Karten hieraus).
const COLORS := {
	Pack.TYPE_DICE: Color("#8be9fd"),
	Pack.TYPE_NUMBER: Color("#50fa7b"),
	Pack.TYPE_MATERIAL: Color("#ff79c6"),
	Pack.TYPE_MIXED: Color("#bd93f9"),
	Pack.TYPE_DICE_MOD: DICE_ENGRAVING_COLOR,
}

var pack_type: String = Pack.TYPE_NUMBER

static func for_type(type: String) -> PackIconRenderer:
	var icon := PackIconRenderer.new()
	icon.pack_type = type
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _draw() -> void:
	match pack_type:
		Pack.TYPE_DICE:
			_draw_die(_accent())
		Pack.TYPE_NUMBER:
			_draw_rising_pip(Vector2(0.5, 0.5), 1.0, _accent())
		Pack.TYPE_MATERIAL:
			_draw_gem(Vector2(0.5, 0.5), 1.0, _accent())
		Pack.TYPE_MIXED:
			_draw_mixed()
		_:
			_draw_corners(Vector2(0.5, 0.5), 1.0, _accent())

func _accent() -> Color:
	return COLORS.get(pack_type, Color.WHITE)

## Isometrischer Würfel: Sechseck-Umriss, drei Innenkanten, ein Auge je Fläche.
func _draw_die(color: Color) -> void:
	var c := Vector2(0.5, 0.52)
	var r := 0.38
	var hex: Array[Vector2] = []
	for i in 7:
		var angle := TAU * (float(i) / 6.0) - TAU * 0.25  # Spitze nach oben
		hex.append(c + Vector2(cos(angle), sin(angle)) * r)
	_stroke(hex, color)
	# Innenkanten zur Mitte (jede zweite Ecke): sie machen das Sechseck zum Würfel.
	for i in [1, 3, 5]:
		_stroke([hex[i], c] as Array[Vector2], color)
	# Ein Auge je sichtbarer Fläche.
	for pip in [Vector2(0.5, 0.30), Vector2(0.33, 0.62), Vector2(0.67, 0.62)]:
		_dot(pip, 0.035, color)

## Ein großes AUGE, darüber ein Doppel-Chevron: die Augenzahl steigt. Ein Punkt
## heißt in diesem Spiel überall "Auge" - mehr braucht das Siegel nicht.
func _draw_rising_pip(at: Vector2, scale_f: float, color: Color) -> void:
	var o := at - Vector2(0.5, 0.5) * scale_f
	_dot(o + Vector2(0.5, 0.66) * scale_f, 0.11 * scale_f, color)
	for i in 2:
		var y := 0.40 - i * 0.16
		_stroke([o + Vector2(0.34, y) * scale_f, o + Vector2(0.5, y - 0.11) * scale_f,
			o + Vector2(0.66, y) * scale_f] as Array[Vector2], color)

## Facettierter Edelstein: Krone, Gürtel und Spitze.
func _draw_gem(at: Vector2, scale_f: float, color: Color) -> void:
	var o := at - Vector2(0.5, 0.5) * scale_f
	var girdle_l := o + Vector2(0.18, 0.42) * scale_f
	var girdle_r := o + Vector2(0.82, 0.42) * scale_f
	var crown_l := o + Vector2(0.34, 0.18) * scale_f
	var crown_r := o + Vector2(0.66, 0.18) * scale_f
	var tip := o + Vector2(0.5, 0.86) * scale_f
	_stroke([girdle_l, crown_l, crown_r, girdle_r, tip, girdle_l] as Array[Vector2], color)
	_stroke([girdle_l, girdle_r] as Array[Vector2], color)
	# Kronen-Facetten zur Gürtelmitte.
	_stroke([crown_l, o + Vector2(0.5, 0.42) * scale_f, crown_r] as Array[Vector2], color)
	_stroke([o + Vector2(0.5, 0.42) * scale_f, tip] as Array[Vector2], color)

## Nur die vier Ecken eines Rahmens - wie der Kanten-Rahmen um die Seiten-Chips.
func _draw_corners(at: Vector2, scale_f: float, color: Color) -> void:
	var o := at - Vector2(0.5, 0.5) * scale_f
	var lo := 0.16 * scale_f
	var hi := 0.84 * scale_f
	var arm := 0.20 * scale_f
	_stroke([o + Vector2(lo, lo + arm), o + Vector2(lo, lo), o + Vector2(lo + arm, lo)] as Array[Vector2], color)
	_stroke([o + Vector2(hi - arm, lo), o + Vector2(hi, lo), o + Vector2(hi, lo + arm)] as Array[Vector2], color)
	_stroke([o + Vector2(hi, hi - arm), o + Vector2(hi, hi), o + Vector2(hi - arm, hi)] as Array[Vector2], color)
	_stroke([o + Vector2(lo + arm, hi), o + Vector2(lo, hi), o + Vector2(lo, hi - arm)] as Array[Vector2], color)

## Gemischt: die drei Gravur-Siegel als Mini-Trio, jedes in seiner Sortenfarbe -
## das einzige mehrfarbige Siegel, damit "alles drin" auf einen Blick lesbar ist.
func _draw_mixed() -> void:
	_draw_rising_pip(Vector2(0.27, 0.26), 0.46, COLORS[Pack.TYPE_NUMBER])
	_draw_gem(Vector2(0.75, 0.28), 0.46, COLORS[Pack.TYPE_MATERIAL])
	_draw_corners(Vector2(0.51, 0.74), 0.46, DICE_ENGRAVING_COLOR)

# --- Monoline-Bausteine (normierte 0..1-Koordinaten) -------------------------------

## Ein Pfad in 3 Pässen: breiter Schein, enger Schein, Kernlinie.
func _stroke(points: Array[Vector2], color: Color) -> void:
	if points.size() < 2:
		return
	var px := PackedVector2Array()
	for p in points:
		px.append(_scaled(p))
	var w := _stroke_width()
	draw_polyline(px, Color(color.r, color.g, color.b, 0.08), w * 5.0, true)
	draw_polyline(px, Color(color.r, color.g, color.b, 0.22), w * 2.4, true)
	draw_polyline(px, color, w, true)

func _dot(at: Vector2, radius: float, color: Color) -> void:
	var side := minf(size.x, size.y)
	draw_circle(_scaled(at), radius * side * 3.0, Color(color.r, color.g, color.b, 0.15))
	draw_circle(_scaled(at), radius * side, color)

## Normierte Koordinate -> Pixel, quadratisch mittig im Control.
func _scaled(p: Vector2) -> Vector2:
	var side := minf(size.x, size.y)
	var origin := (size - Vector2.ONE * side) * 0.5
	return origin + p * side

func _stroke_width() -> float:
	return maxf(1.5, minf(size.x, size.y) * 0.045)
