class_name Rift
extends Resource
## Ein Rift: ein kontrollierter Bruch der Würfelschale. Jeder Würfel ist um einen
## Funken rohen Lichts gegossen - denselben Stoff, den das Casino als Energie
## abfüllt. Die Gravur reißt eine Seite entlang eines Musters auf und versiegelt
## sie sofort mit getönter Glasur: Glasur lässt Licht durch, Gas nicht, also
## bleibt die Essenz drin und der Würfel gilt weiter als nie geöffnet.
## Die TÖNUNG ist die Wirkung - ein Kern, vier Farben, vier Effekte.
##
## Nur Anzeige-Infos; die Wirkung löst RiftEffects über die id auf. Max. 1 Rift
## je Seite - Ausnahme ist der Vakuum-Würfel (siehe DieDefinition.second_rifts).
## Zeitliche Signatur: die Essenz glüht DAUERND, ein Rift schimmert in Ruhe nur
## schwach und flammt im Moment seines Feuerns auf.

# --- Rissbilder (das Muster IST die Erkennungsmarke) ---
const PATTERN_RING := "ring"
const PATTERN_HAIRLINES := "hairlines"
const PATTERN_STAR := "star"
const PATTERN_BOLT := "bolt"

# --- Rift-ids (Single Source of Truth) ---
const AFTERGLOW := "afterglow"        # Nachglühen: +1 Auslösung
const STRAY_LIGHT := "stray_light"    # Streulicht: +$1 je ungewertetem Zugende
const BURN_IN := "burn_in"            # Einbrand: Seitenwert eingebrannt
const SPARK_FLIGHT := "spark_flight"  # Funkenflug: +1 ⚡ beim Werten

const NONE := ""

@export var id: String = ""
@export var display_name: String = ""
## Kurzwirkung für Karten und Hover-Zeilen ("+1 Auslösung").
@export var short: String = ""
@export var description: String = ""
## Klasse aus der Design-Seite: Wertung, Ökonomie oder Schutz - reine Flavor-
## Einordnung für die Anzeige, die Wirkung hängt an der id.
@export var kind: String = ""
## Farbe der Glasur im Riss. Funkenflug trägt das Charge-Cyan der Energie -
## derselbe Wert wie CasinoStyle.CHARGE, hier gespiegelt, weil data/ nie aus
## ui/ importieren darf (die Ordner SIND die Abhängigkeitsregel).
@export var tint: Color = Color.WHITE
@export var pattern: String = PATTERN_RING

static func _make(rift_id: String, name: String, short_text: String, desc: String,
		kind_text: String, tint_color: Color, pattern_id: String) -> Rift:
	var rift := Rift.new()
	rift.id = rift_id
	rift.display_name = name
	rift.short = short_text
	rift.description = desc
	rift.kind = kind_text
	rift.tint = tint_color
	rift.pattern = pattern_id
	return rift

static func afterglow() -> Rift:
	return _make(AFTERGLOW, "Nachglühen", "+1 Auslösung",
		"Wird diese Seite gewertet, glüht sie einmal nach: der Würfel löst einmal zusätzlich aus.",
		"Wertung", Color(0.88, 0.9, 0.95), PATTERN_RING)

static func stray_light() -> Rift:
	return _make(STRAY_LIGHT, "Streulicht", "+$1 ungewertet",
		"Liegt der Würfel am Zugende ungewertet auf dem Tisch und zeigt diese Seite: +$1. Er streut sein Licht ungenutzt aufs Filz.",
		"Ökonomie", Color(1.0, 0.82, 0.45), PATTERN_HAIRLINES)

static func burn_in() -> Rift:
	return _make(BURN_IN, "Einbrand", "Seite eingebrannt",
		"Der Wert dieser Seite ist eingebrannt: er kann nicht schrumpfen, und ihr Material lässt sich nicht übermalen.",
		"Schutz", Color(1.0, 0.5, 0.15), PATTERN_STAR)

static func spark_flight() -> Rift:
	return _make(SPARK_FLIGHT, "Funkenflug", "+1 ⚡ beim Werten",
		"Wird diese Seite gewertet, springt ein Funke über: +1 Energie, einmal je Zug.",
		"Wertung", Color(0.55, 1.9, 2.1), PATTERN_BOLT)

## Kanonische Registrierung aller Rifts.
static func all() -> Array[Rift]:
	return [afterglow(), stray_light(), burn_in(), spark_flight()]

static func by_id(rift_id: String) -> Rift:
	for rift in all():
		if rift.id == rift_id:
			return rift
	return null

static func is_valid_id(rift_id: String) -> bool:
	return by_id(rift_id) != null

## Tönung zur id - Schwarz ohne Rift. Der Vakuum-Würfel überschreibt das später
## ohnehin: seine Risse sind schwarz, er saugt das Kernlicht nach innen.
static func tint_for(rift_id: String) -> Color:
	var rift := by_id(rift_id)
	return rift.tint if rift != null else Color.BLACK

## Kurz-Erklärzeile fürs Hover-Feld ("" ohne Rift): «Name» (Klasse): Wirkung.
static func hint(rift_id: String) -> String:
	var rift := by_id(rift_id)
	if rift == null:
		return ""
	return "%s (%s): %s" % [rift.display_name, rift.kind, rift.short]

## Rissbild als normierte Polylinien (0..1 in der Zelle). EINE Quelle für das
## Würfelnetz und die 3D-Auflage - sonst zeigt der Tisch ein anderes Muster als
## die Werkbank. Bewusst wenige, lange Striche: bei ~17 px Zellbreite muss die
## Figur als Geometrie lesen, nicht als Textur.
static func crack_lines(pattern_id: String) -> Array[PackedVector2Array]:
	match pattern_id:
		PATTERN_RING:
			# Ringriss: ein offener Kreis, an einer Stelle aufgesprungen.
			var ring := PackedVector2Array()
			for step in 11:
				var angle := TAU * (0.08 + 0.84 * float(step) / 10.0)
				ring.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.3)
			return [ring]
		PATTERN_HAIRLINES:
			# Haarrisse: drei feine, versetzte Striche.
			return [
				PackedVector2Array([Vector2(0.22, 0.3), Vector2(0.45, 0.72)]),
				PackedVector2Array([Vector2(0.5, 0.2), Vector2(0.62, 0.6)]),
				PackedVector2Array([Vector2(0.6, 0.5), Vector2(0.82, 0.78)]),
			]
		PATTERN_STAR:
			# Sternbruch: vier Strahlen aus einem Einschlagpunkt.
			var star: Array[PackedVector2Array] = []
			for step in 4:
				var angle := TAU * float(step) / 4.0 + 0.4
				star.append(PackedVector2Array([
					Vector2(0.5, 0.5),
					Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.34]))
			return star
		PATTERN_BOLT:
			# Zickzack: ein Blitz von oben nach unten.
			return [PackedVector2Array([
				Vector2(0.62, 0.16), Vector2(0.4, 0.45),
				Vector2(0.58, 0.5), Vector2(0.36, 0.84)])]
	return []

## Rissbild eines Rifts (leer bei unbekannter id).
static func lines_for(rift_id: String) -> Array[PackedVector2Array]:
	var rift := by_id(rift_id)
	return crack_lines(rift.pattern) if rift != null else [] as Array[PackedVector2Array]
