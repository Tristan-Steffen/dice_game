class_name PitScoreView
extends Control
## Wertungs-Zahl als ladender ENERGIE-ORB: die Zahl sitzt in einem dunklen
## Glaskern, das Leuchten wächst als Halo drumherum mit dem Wert (asymptotisch,
## damit auch riesige Werte im Rahmen bleiben). Jeder Punkt-Zufluss lässt den
## Orb kurz aufploppen (Squash-Stretch). Basis (Cyan) und Mult (Gold) sind zwei
## Instanzen; eine dritte trägt die verschmolzene Gesamtzahl (überhell).

const BASE_COLOR := Color("#00ffff")
const MULT_COLOR := Color("#ffd319")
const TOTAL_COLOR := Color(2.1, 1.7, 0.15)  # überhelles Gold der Gesamtzahl

## Radien als Anteil der Control-Höhe: fester dunkler Kern (trägt die Zahl),
## Leuchtradius wächst von R_MIN (Wert 0) auf R_MAX (gesättigt).
const CORE_FRAC := 0.17
const R_MIN_FRAC := 0.21
const R_MAX_FRAC := 0.42
const HALO_FRAC := 1.28     # Halo reicht bis R * HALO_FRAC hinaus
const HALO_LAYERS := 9
const NUMBER_FRAC := 0.23   # Schriftgröße als Anteil der Höhe

## Wachstumskonstante: 1 - exp(-value/K). Basis-Werte laufen groß, Mult klein -
## darum je Instanz gesetzt (siehe TableScreen).
var growth_k := 220.0

var value := 0
var color := BASE_COLOR  # je Instanz gesetzt
var is_total := false     # Gesamt-Orb: kräftigeres Halo
var overbright := false   # Ziel geknackt: weiß-heißer Kern-Blitz

## Geglätteter Leuchtradius (Pixel) plus Squash-Stretch fürs Aufploppen.
var _glow_radius := 0.0
var _pop := 1.0
var _breath := 0.0
var _radius_tween: Tween
var _pop_tween: Tween

func _ready() -> void:
	_glow_radius = _target_glow_radius()
	set_process(true)

## Sanftes Atmen im Leerlauf, damit der Orb lebt.
func _process(delta: float) -> void:
	_breath += delta
	queue_redraw()

func set_value(p_value: int) -> void:
	var changed := p_value != value
	value = p_value
	_animate_radius()
	if changed:
		_do_pop()
	queue_redraw()

## Setzt Wert OHNE Pop/Tween (stille Daueranzeige, z.B. Reset auf 0).
func set_value_silent(p_value: int) -> void:
	value = p_value
	_glow_radius = _target_glow_radius()
	queue_redraw()

## Ploppt ohne Wertänderung (Ankunft ohne Zuwachs, z.B. Kombi-Puls).
func pop() -> void:
	_do_pop()

func set_overbright(on: bool) -> void:
	if overbright == on:
		return
	overbright = on
	queue_redraw()

## Squash-Stretch-Puls: kurz über 1 hinaus, dann elastisch zurück - so fühlt
## sich auch ein winziger Radius-Zuwachs satt an.
func _do_pop() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop = 1.28
	_pop_tween = create_tween()
	_pop_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(self, "_pop", 1.0, 0.45)

func _animate_radius() -> void:
	if _radius_tween != null and _radius_tween.is_valid():
		_radius_tween.kill()
	_radius_tween = create_tween()
	_radius_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_radius_tween.tween_property(self, "_glow_radius", _target_glow_radius(), 0.35)

## Ziel-Leuchtradius (Pixel) für den aktuellen Wert - asymptotisch gedeckelt.
func _target_glow_radius() -> float:
	var h := size.y
	var t := 1.0 - exp(-float(value) / maxf(1.0, growth_k))
	return h * (R_MIN_FRAC + (R_MAX_FRAC - R_MIN_FRAC) * t)

func _draw() -> void:
	var h := size.y
	var c := size / 2.0
	var breath := 1.0 + 0.03 * sin(_breath * 1.7)

	# Zahl zuerst messen: der dunkle Kern wächst mit, damit lange Zahlen (1500,
	# 4200) IMMER auf dunklem Glas sitzen und nicht ins Leuchten auslaufen.
	var font := ThemeDB.fallback_font
	var value_font := int(h * NUMBER_FRAC)
	var text := str(value)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, value_font)
	var core_r: float = maxf(h * CORE_FRAC, text_size.x * 0.5 + h * 0.07)
	var r: float = maxf(_glow_radius * _pop * breath, core_r * 1.04)

	# Halo: von außen (schwach) nach innen (kräftig) geschichtet -> weicher Verlauf.
	# Überheiß (Ziel geknackt) blendet den Glanz Richtung Weiß.
	var glow := color
	if overbright:
		glow = glow.lerp(Color(2.4, 2.3, 1.9), 0.5)
	var peak := 0.5 if is_total else 0.38
	for i in HALO_LAYERS:
		var f := float(i) / float(HALO_LAYERS - 1)  # 0 außen .. 1 innen
		var ring_r: float = lerp(r * HALO_FRAC, core_r, f)
		var a: float = peak * f * f
		draw_circle(c, ring_r, Color(glow.r, glow.g, glow.b, a))

	# Dunkler Glaskern trägt die Zahl lesbar.
	draw_circle(c, core_r, Color(0.02, 0.02, 0.05, 0.94))
	# Heller Kern-Rand (Kondensator-Rand) + optionaler Ziel-Blitz.
	var rim := Color(glow.r, glow.g, glow.b, 0.9)
	if overbright:
		rim = Color(2.6, 2.6, 2.3, 1.0)
	draw_arc(c, core_r, 0.0, TAU, 56, rim, maxf(2.0, h * 0.014), true)

	# Zahl mittig im Kern.
	var number_color := Color(2.4, 2.4, 2.2) if overbright else Color(1.5, 1.5, 1.5)
	draw_string(font, c + Vector2(-text_size.x / 2.0, text_size.y * 0.32), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, value_font, number_color)

## Lokaler Zielpunkt der Licht-Trails: die Mitte (= der Orb-Kern).
func value_anchor() -> Vector2:
	return size / 2.0
