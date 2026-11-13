class_name PitScoreView
extends Control
## Wertungs-Zahl ohne Kreis: die ZIFFERN selbst tragen den Zustand. Mit dem Wert
## wird die Farbe heißer (asymptotisch, damit riesige Werte nicht ausbrennen), ein
## Zufluss blitzt weiß-heiß auf und ploppt die Zahl (Squash-Stretch), ein weicher
## Schein folgt der Ziffernform. Basis (Cyan) und Mult (Gold) sind zwei Instanzen;
## eine dritte trägt die verschmolzene Gesamtzahl (überhell).

const BASE_COLOR := Color("#00ffff")
const MULT_COLOR := Color("#ffd319")
const TOTAL_COLOR := Color(2.1, 1.7, 0.15)  # überhelles Gold der Gesamtzahl

## Helligkeit der Ziffer: kalt bei 0, über der Bloom-Schwelle, wenn gesättigt.
const COLD_GAIN := 0.8
const HOT_GAIN := 1.9
const FLASH_COLOR := Color(2.4, 2.4, 2.2)
const FLASH_SHARE := 0.75  # so weit zieht ein Zufluss Richtung Weiß-heiß
const FLASH_TIME := 0.5
const POP_SCALE := 1.28
## Schein und Kontur als Anteil der Schriftgröße.
const GLOW_OUTLINE := 0.55
const GLOW_ALPHA := 0.32
const GLOW_LAYERS := 5
const GLOW_CAP := 0.9
const SHADOW_OUTLINE := 0.12
## Die Gesamtzahl steht auf der hellen Balken-Füllung: dicke dunkle Kontur wie die Balken-Beschriftung.
const TOTAL_SHADOW_OUTLINE := 0.3
const SHADOW_COLOR := Color(0.02, 0.02, 0.05, 0.9)
## Rückfall-Schriftgröße als Anteil der Höhe (ohne gesetztes number_px).
const NUMBER_FRAC := 0.34

## Wachstumskonstante: 1 - exp(-value/K). Basis-Werte laufen groß, Mult klein -
## darum je Instanz gesetzt (siehe TableScreen).
var growth_k := 220.0
## Schriftgröße in Pixeln (TableScreen setzt die des Zielbalkens); 0 = aus der Höhe.
var number_px := 0

## Float, seit Krits ×1,5 sein dürfen - gedruckt wird über die eine Formatregel
## (ScoreBreakdown.format_number), die Nachkommastellen nur zeigt, wenn es welche gibt.
var value := 0.0
var color := BASE_COLOR  # je Instanz gesetzt
var is_total := false     # Gesamtzahl: überhell, heizt nicht weiter auf
var overbright := false   # Ziel geknackt / Krit-Anspannung: weiß-heiß

## Geglättete Hitze (0..1), Zufluss-Blitz (0..1) und Squash-Stretch.
var _heat := 0.0
var _flash := 0.0
var _pop := 1.0
var _breath := 0.0
var _heat_tween: Tween
var _pop_tween: Tween

func _ready() -> void:
	_heat = _target_heat()
	set_process(true)

## Sanftes Atmen im Leerlauf, damit die Zahl lebt.
func _process(delta: float) -> void:
	_breath += delta
	queue_redraw()

func set_value(p_value: float) -> void:
	var changed := not is_equal_approx(p_value, value)
	value = p_value
	_animate_heat()
	if changed:
		_do_pop()
	queue_redraw()

## Setzt Wert OHNE Pop/Tween (stille Daueranzeige, z.B. Reset auf 0).
func set_value_silent(p_value: float) -> void:
	value = p_value
	_heat = _target_heat()
	queue_redraw()

## Ploppt ohne Wertänderung (Ankunft ohne Zuwachs, z.B. Kombi-Puls).
func pop() -> void:
	_do_pop()

func set_overbright(on: bool) -> void:
	if overbright == on:
		return
	overbright = on
	queue_redraw()

## Zufluss: die Zahl springt groß und weiß-heiß an und kühlt elastisch zurück.
func _do_pop() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop = POP_SCALE
	_flash = 1.0
	_pop_tween = create_tween().set_parallel()
	_pop_tween.tween_property(self, "_pop", 1.0, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(self, "_flash", 0.0, FLASH_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _animate_heat() -> void:
	if _heat_tween != null and _heat_tween.is_valid():
		_heat_tween.kill()
	_heat_tween = create_tween()
	_heat_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_heat_tween.tween_property(self, "_heat", _target_heat(), 0.35)

## Ziel-Hitze (0..1) für den aktuellen Wert - asymptotisch gedeckelt.
func _target_heat() -> float:
	return 1.0 - exp(-maxf(0.0, value) / maxf(1.0, growth_k))

## Farbe der Ziffer aus Hitze, Blitz und Überhitzung.
func number_color() -> Color:
	var breath := 1.0 + 0.04 * sin(_breath * 1.7)
	# Die Gesamtzahl ist schon überhell - sie atmet nur noch, statt weiter aufzuheizen.
	var gain := breath if is_total else lerpf(COLD_GAIN, HOT_GAIN, _heat) * breath
	var c := Color(color.r * gain, color.g * gain, color.b * gain)
	if overbright:
		c = c.lerp(FLASH_COLOR, 0.6)
	return c.lerp(FLASH_COLOR, _flash * FLASH_SHARE)

func font_px() -> int:
	return number_px if number_px > 0 else maxi(1, int(size.y * NUMBER_FRAC))

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var px := font_px()
	var text := ScoreBreakdown.format_number(value)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var c := size / 2.0
	var at := Vector2(-width * 0.5, (font.get_ascent(px) - font.get_descent(px)) * 0.5)
	draw_set_transform(c, 0.0, Vector2.ONE * _pop)
	var fill := number_color()
	# Schein: gestaffelte, durchsichtige Konturen in der Ziffernfarbe (außen schwach,
	# innen kräftiger) - er wächst mit der Hitze und dem Blitz.
	# Der Schein bleibt unter der Bloom-Schwelle: nur die Ziffer selbst blüht auf.
	var glow_a := GLOW_ALPHA * (0.35 + 0.65 * maxf(_heat, _flash))
	var glow := Color(minf(fill.r, GLOW_CAP), minf(fill.g, GLOW_CAP), minf(fill.b, GLOW_CAP))
	for i in GLOW_LAYERS:
		var f := float(i + 1) / float(GLOW_LAYERS)  # außen .. innen
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			int(px * GLOW_OUTLINE * (1.0 - f * 0.75)), Color(glow.r, glow.g, glow.b, glow_a * f * 0.45))
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
		int(px * (TOTAL_SHADOW_OUTLINE if is_total else SHADOW_OUTLINE)), SHADOW_COLOR)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fill)
	draw_set_transform(Vector2.ZERO)

## Lokaler Zielpunkt der Licht-Trails: die Mitte (= die Zahl).
func value_anchor() -> Vector2:
	return size / 2.0
