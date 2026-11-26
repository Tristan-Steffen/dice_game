class_name LaborView
extends Control
## Das LABOR unter dem Schwarzmarkt (Spieler-Wahl „R3 · Sektoren“, im Spielmaß build_r4 aus
## tools/blender_labor_variants.py): links die ovale Messing-Schale mit der runden KAMMER und
## je Flanke drei RUNDENFELDERN, rechts Namens-Schild, START-Taste und Status-Fenster. Das
## Fenster malt nichts - es MELDET die Teile in Stations-Einheiten und den Zustand als reine
## Daten für den Körper (LaborBody); unsichtbare Knöpfe über Kammer und START tragen den Klick.
## Es kennt GameRun nicht: der Zustand kommt als Dictionary (set_state).

signal chamber_pressed
signal start_pressed

## Der Grundriß in Stations-Einheiten (= Welt bei unit() = Pixel je Welt).
const UNITS := Vector2(28.0, 10.6)
const DISH_CENTER := Vector2(-5.4, 0.0)
const DISH_SIZE := Vector2(16.4, 10.2)
## Der dunkle Feldgrund liegt um diesen Saum innerhalb der Messing-Schale.
const DISH_RIM := 0.25
const CHAMBER_RADIUS := 4.63
## Rundenfelder: halber Winkel je Flanke (Grad), Innen- und Außenradius, Fuge (Grad).
const FIELD_HALF := 38.0
const FIELD_INNER := 5.4
const FIELD_OUTER := 7.6
const FIELD_GAP := 1.5
## So weit bleibt ein Feld vom Rand des Feldgrunds weg (sonst ragt es aus dem Oval).
const FIELD_CLEAR := 0.3
const FIELDS := 6
const ROUNDS := 6

const STATIONS := ["seele", "charm", "modul", "karten"]
const NAMES := {"seele": "SEELEN-TRANSFER", "charm": "CHARM-KOPIERER", "modul": "MODUL-KOPIERER",
	"karten": "KARTEN-PRESSE"}
const BLURBS := {
	"seele": "Überträgt die Seele eines Würfels auf einen zweiten.",
	"charm": "Kopiert einen Charm - die Kopie braucht einen freien Projektor.",
	"modul": "Kopiert ein gestecktes Modul - die Kopie wartet auf den Einbau.",
	"karten": "Presst 1 bis 6 Karten neu - jede kommt mit mehr Glück gewürfelt zurück.",
}

const PHASE_READY := "bereit"
const PHASE_RUNNING := "laeuft"
const PHASE_DONE := "fertig"

const FIELD_OFF := "aus"
const FIELD_ROLL := "wurf"
const FIELD_ROUND := "runde"

## Status-Arten: sagen dem Körper die Farbe der Zeile.
const STATUS_READY := "bereit"
const STATUS_STAGING := "einsatz"
const STATUS_RUNNING := "laeuft"
const STATUS_DONE := "fertig"
const STATUS_BLOCKED := "gesperrt"

## Die Teile als (Mitte x, Mitte y, Breite, Höhe) in Stations-Einheiten, y Bild-OBEN; die
## Felder als Hüllrechteck ihres Sektors (field_outline gibt die echte Form).
static var PARTS: Dictionary = _build_parts()

var chamber_button: Button
var start_button: Button
var _state := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(refresh)

# --- Geometrie (reine Regeln) -----------------------------------------------------------

static func _build_parts() -> Dictionary:
	var parts := {
		"dish": Rect2(DISH_CENTER, DISH_SIZE),
		"chamber": Rect2(DISH_CENTER, Vector2.ONE * CHAMBER_RADIUS * 2.0),
		"name": Rect2(8.9, 3.2, 8.0, 1.3),
		"start": Rect2(8.9, 0.0, 6.4, 2.0),
		"status": Rect2(8.9, -3.2, 5.0, 1.9),
	}
	for i in FIELDS:
		var outline := field_outline(i)
		var lo := outline[0]
		var hi := outline[0]
		for p in outline:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		parts["field%d" % i] = Rect2((lo + hi) * 0.5, hi - lo)
	return parts

## Winkel (Grad, 0 = Bild-rechts, gegen den Uhrzeigersinn) eines Feldes: 0-2 rechte Flanke
## von oben, 3-5 linke Flanke von unten - im Uhrzeigersinn ab rechts oben.
static func field_angles(i: int) -> Vector2:
	var step := FIELD_HALF * 2.0 / 3.0
	var base := 0.0 if i < 3 else 180.0
	var j := i % 3
	return Vector2(base + FIELD_HALF - float(j) * step - FIELD_GAP,
		base + FIELD_HALF - float(j + 1) * step + FIELD_GAP)

## Wie weit ein Strahl aus der Schalenmitte im Feldgrund reicht (Stadion-Form).
static func ground_reach(angle_deg: float) -> float:
	var straight := (DISH_SIZE.x - DISH_SIZE.y) * 0.5
	var radius := DISH_SIZE.y * 0.5 - DISH_RIM
	var dx := absf(cos(deg_to_rad(angle_deg)))
	var dy := absf(sin(deg_to_rad(angle_deg)))
	if dy > 0.0001 and radius / dy * dx <= straight:
		return radius / dy
	return straight * dx + sqrt(maxf(straight * straight * dx * dx - straight * straight + radius * radius, 0.0))

## Der Umriß eines Feldes in Stations-Einheiten (rechts, oben): innen der Bogen, außen der
## Bogen, wo nötig an den Feldgrund geklemmt.
static func field_outline(i: int, steps := 14) -> PackedVector2Array:
	var angles := field_angles(i)
	var out := PackedVector2Array()
	for k in steps + 1:
		var a := lerpf(angles.x, angles.y, float(k) / float(steps))
		out.append(DISH_CENTER + Vector2.from_angle(deg_to_rad(a)) * FIELD_INNER)
	for k in range(steps, -1, -1):
		var a := lerpf(angles.x, angles.y, float(k) / float(steps))
		var outer := minf(FIELD_OUTER, ground_reach(a) - FIELD_CLEAR)
		out.append(DISH_CENTER + Vector2.from_angle(deg_to_rad(a)) * outer)
	return out

## Pixel je Stations-Einheit (die knappere Achse gewinnt).
func unit() -> float:
	return minf(size.x / UNITS.x, size.y / UNITS.y)

## Ein Teil in eigenen Pixeln.
func part_rect(key: String) -> Rect2:
	var part: Rect2 = PARTS[key]
	var k := unit()
	var mid := size * 0.5 + Vector2(part.position.x, -part.position.y) * k
	return Rect2(mid - part.size * k * 0.5, part.size * k)

func layout() -> Dictionary:
	var out := {}
	for key: String in PARTS:
		out[key] = part_rect(key)
	return out

## Ein eigenes Pixel in Stations-Einheiten (rechts, oben).
func units_at(local_px: Vector2) -> Vector2:
	var k := maxf(unit(), 0.0001)
	var d := (local_px - size * 0.5) / k
	return Vector2(d.x, -d.y)

## Das Teil unter einem eigenen Pixel ("" = keins); Kammer und Felder nach ihrer echten Form.
func part_at(local_px: Vector2) -> String:
	for key: String in ["start", "name", "status"]:
		if part_rect(key).has_point(local_px):
			return key
	var p := units_at(local_px)
	if p.distance_to(DISH_CENTER) <= CHAMBER_RADIUS:
		return "chamber"
	for i in FIELDS:
		if Geometry2D.is_point_in_polygon(p, field_outline(i)):
			return "field%d" % i
	if part_rect("dish").has_point(local_px) and _in_dish(p):
		return "dish"
	return ""

static func _in_dish(p: Vector2) -> bool:
	var straight := (DISH_SIZE.x - DISH_SIZE.y) * 0.5
	var d := p - DISH_CENTER
	var nearest := Vector2(clampf(d.x, -straight, straight), 0.0)
	return d.distance_to(nearest) <= DISH_SIZE.y * 0.5

# --- Zustand (reine Daten) --------------------------------------------------------------

## state: open, station, phase, die_value, rounds_left, price, affordable, collectable,
## dazu die Tisch-Schlüssel staged, staged_max, staged_ready, blocked_text.
func set_state(state: Dictionary) -> void:
	_state = state.duplicate()
	refresh()

func state() -> Dictionary:
	return _state

func refresh() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_build_buttons()
	var data := body_state()
	chamber_button.disabled = not bool(data["open"])
	start_button.disabled = not bool(data["start_lit"])

## Die Felder je Zustand: die ersten die_value gold (Wurf), dann so viele violett, wie
## Runden schon vergangen sind, der Rest aus. Ohne Auftrag ist alles aus.
static func fields_for(phase: String, die_value: int, rounds_left: int) -> Array[String]:
	var out: Array[String] = []
	var roll := 0
	var passed := 0
	if phase != PHASE_READY and die_value > 0:
		roll = clampi(die_value, 0, ROUNDS)
		passed = clampi((ROUNDS - roll) - maxi(rounds_left, 0), 0, ROUNDS - roll)
	for i in FIELDS:
		out.append(FIELD_ROLL if i < roll else (FIELD_ROUND if i < roll + passed else FIELD_OFF))
	return out

static func status_text(state: Dictionary) -> String:
	var blocked := String(state.get("blocked_text", ""))
	if blocked != "":
		return blocked
	match String(state.get("phase", PHASE_READY)):
		PHASE_RUNNING:
			return "NOCH %d" % maxi(int(state.get("rounds_left", 0)), 0)
		PHASE_DONE:
			return "FERTIG"
	if int(state.get("staged", 0)) > 0:
		return "EINSATZ %d/%d" % [int(state.get("staged", 0)), int(state.get("staged_max", 0))]
	return "BEREIT"

static func status_kind(state: Dictionary) -> String:
	if String(state.get("blocked_text", "")) != "":
		return STATUS_BLOCKED
	match String(state.get("phase", PHASE_READY)):
		PHASE_RUNNING:
			return STATUS_RUNNING
		PHASE_DONE:
			return STATUS_DONE
	return STATUS_STAGING if int(state.get("staged", 0)) > 0 else STATUS_READY

static func station_name(station: String) -> String:
	return String(NAMES.get(station, NAMES["seele"]))

## Was der Körper braucht, als reine Daten.
func body_state() -> Dictionary:
	var state := _state
	var phase := String(state.get("phase", PHASE_READY))
	var station := String(state.get("station", "seele"))
	var price := maxi(int(state.get("price", 0)), 0)
	var affordable := bool(state.get("affordable", true))
	var open := bool(state.get("open", false))
	var staged_max := int(state.get("staged_max", 0))
	# Mit Wahl-Angabe leuchtet START erst, wenn etwas eingelegt ist; meldet der Tisch
	# staged_ready, erst bei einem für START gültigen Einsatz.
	var staged_ok := staged_max <= 0 or int(state.get("staged", 0)) > 0
	if state.has("staged_ready"):
		staged_ok = bool(state["staged_ready"])
	var start_text := "START"
	if phase == PHASE_RUNNING:
		start_text = "LÄUFT"
	elif phase == PHASE_DONE:
		start_text = "FERTIG"
	return {
		"open": open,
		"station": station,
		"name": station_name(station),
		"phase": phase,
		"fields": fields_for(phase, int(state.get("die_value", 0)), int(state.get("rounds_left", 0))),
		"price": price,
		"price_text": "FREI" if price == 0 else str(price),
		"affordable": affordable,
		"start_text": start_text,
		"start_lit": open and phase == PHASE_READY and affordable and staged_ok,
		"status": status_text(state),
		"status_kind": status_kind(state),
		"hood": phase == PHASE_RUNNING,
		"collectable": bool(state.get("collectable", false)),
	}

# --- Hinweise ---------------------------------------------------------------------------

## Der kurze Hinweis zum Teil unter einem eigenen Pixel ("" = keins).
func hint_at(local_px: Vector2) -> String:
	var part := part_at(local_px)
	if part == "":
		return ""
	var state := _state
	var phase := String(state.get("phase", PHASE_READY))
	var station := String(state.get("station", "seele"))
	match part:
		"chamber":
			match phase:
				PHASE_RUNNING:
					return "Der Auftrag läuft - noch %d Runden." % maxi(int(state.get("rounds_left", 0)), 0)
				PHASE_DONE:
					if bool(state.get("collectable", true)):
						return "Fertig - Klick holt das Ergebnis ab."
					return "Fertig - erst einen Projektor frei machen."
			return "Kammer: Klick wählt den Einsatz."
		"start":
			match phase:
				PHASE_RUNNING:
					return "Der Auftrag läuft."
				PHASE_DONE:
					return "Fertig - hol das Ergebnis aus der Kammer."
			var price := int(state.get("price", 0))
			var cost := "frei" if price <= 0 else "%d Energie" % price
			return "START: %s - der Glückswürfel würfelt die Wartezeit (6 = sofort)." % cost
		"name":
			return "%s: %s" % [station_name(station), String(BLURBS.get(station, ""))]
		"status":
			return "Status: %s." % status_text(state)
	return "Runden: Gold ist der Wurf, Violett zählt die vergangenen Runden."

# --- Knöpfe -----------------------------------------------------------------------------

func _build_buttons() -> void:
	if chamber_button == null:
		chamber_button = _ghost_button("Kammer")
		chamber_button.pressed.connect(func() -> void: chamber_pressed.emit())
		start_button = _ghost_button("Start")
		start_button.pressed.connect(func() -> void: start_pressed.emit())
	for pair in [[chamber_button, "chamber"], [start_button, "start"]]:
		var rect := part_rect(String(pair[1]))
		(pair[0] as Button).position = rect.position
		(pair[0] as Button).size = rect.size

func _ghost_button(part: String) -> Button:
	var button := Button.new()
	button.name = part
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	add_child(button)
	return button
