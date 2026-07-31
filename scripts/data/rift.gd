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

# --- Bewegungsarten (Schlüssel in die_rift.gdshader) ---
const MOTION_ECHO := 0      # Nachglühen: eine Bande wandert, der Blitz wiederholt sich
const MOTION_SCATTER := 1   # Streulicht: kein Lauf, nur Glitzern an Ort und Stelle
const MOTION_EMBER := 2     # Einbrand: Glut kriecht die Strahlen hoch und zurück
const MOTION_SPARK := 3     # Funkenflug: ein Kopf läuft die Bahn und verlässt sie
const MOTION_INTAKE := 4    # Vakuum: die Naht saugt sich zu, statt zu strahlen

## DIE RUHE-REGEL: kein Ruhe-Schimmern darf die Bloom-Schwelle erreichen. Das ist
## es, was sechs gerissene Würfel in der Grube mechanisch davon abhält, eine Disco
## zu werden - nicht Geschmack, nicht Tuning. Ruhelicht gibt es, Ruhe-Bloom nicht.
const IDLE_CEILING := 0.95

## Bewegungsart im Shader.
@export var motion: int = MOTION_ECHO
## Kernfarbe im heißen Faden (die Naht selbst trägt tint).
@export var core: Color = Color.WHITE
## Ruhe-Schimmern: Grundwert und Spitze. idle_high MUSS unter IDLE_CEILING bleiben.
@export var idle_low: float = 0.22
@export var idle_high: float = 0.62
## Sekunden für einen vollen Ruhe-Durchlauf.
@export var idle_period: float = 4.2
## Spitzenwert im Ausbruch. Weit über 1: der Ausbruch SOLL bloomen.
@export var flare_peak: float = 3.0
## Anteil des harten Kerns an der Naht; der Rest ist weicher Hof. Das ist unser
## Gegenstück zur Pulverkörnung des Kintsugi-Goldes - matt oder glänzend.
@export var core_share: float = 0.55
## Angenommenes Hof-Band in Ruhe und sein Faktor im Ausbruch. Der Ausbruch liest
## auf Übersichts-Distanz über BREITE, nicht über Helligkeit: eine Naht ist dort
## ~1 px, und Helligkeit allein bleibt ein Subpixel-Punkt.
@export var halo_width: float = 0.35
@export var halo_flare: float = 2.8
## Gerichtetes Ausbluten des Hofs in UV (Streulicht: nach unten aufs Filz).
@export var halo_bias: Vector2 = Vector2.ZERO

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
	var rift := _make(AFTERGLOW, "Nachglühen", "+1 Auslösung",
		"Wird diese Seite gewertet, glüht sie einmal nach: der Würfel löst einmal zusätzlich aus.",
		"Wertung", Color(0.88, 0.9, 0.95), PATTERN_RING)
	rift.motion = MOTION_ECHO
	rift.core = Color(1.0, 1.0, 1.0)
	rift.idle_low = 0.22
	rift.idle_high = 0.62
	rift.idle_period = 4.2
	rift.flare_peak = 3.0
	rift.core_share = 0.55
	rift.halo_flare = 3.0
	return rift

static func stray_light() -> Rift:
	var rift := _make(STRAY_LIGHT, "Streulicht", "+$1 ungewertet",
		"Liegt der Würfel am Zugende ungewertet auf dem Tisch und zeigt diese Seite: +$1. Er streut sein Licht ungenutzt aufs Filz.",
		"Ökonomie", Color(1.0, 0.82, 0.45), PATTERN_HAIRLINES)
	rift.motion = MOTION_SCATTER
	rift.core = Color(1.0, 0.93, 0.72)
	rift.idle_low = 0.20
	rift.idle_high = 0.70
	rift.idle_period = 3.1
	rift.flare_peak = 2.2
	rift.core_share = 0.35
	rift.halo_flare = 2.5
	# Das Licht fällt vom Würfel aufs Filz - die Fiktion der Wirkung.
	rift.halo_bias = Vector2(0.0, 1.0)
	return rift

static func burn_in() -> Rift:
	var rift := _make(BURN_IN, "Einbrand", "Seite eingebrannt",
		"Der Wert dieser Seite ist eingebrannt: er kann nicht schrumpfen, und ihr Material lässt sich nicht übermalen.",
		"Schutz", Color(1.0, 0.5, 0.15), PATTERN_STAR)
	rift.motion = MOTION_EMBER
	rift.core = Color(1.0, 0.86, 0.62)
	# Höchster Ruhe-Boden der vier: Einbrand ist ein Zustand, kein Ereignis.
	rift.idle_low = 0.30
	rift.idle_high = 0.66
	rift.idle_period = 2.4
	rift.flare_peak = 2.8
	rift.core_share = 0.25
	rift.halo_flare = 2.6
	return rift

static func spark_flight() -> Rift:
	var rift := _make(SPARK_FLIGHT, "Funkenflug", "+1 ⚡ beim Werten",
		"Wird diese Seite gewertet, springt ein Funke über: +1 Energie, einmal je Zug.",
		"Wertung", Color(0.55, 1.9, 2.1), PATTERN_BOLT)
	rift.motion = MOTION_SPARK
	rift.core = Color(0.80, 1.0, 1.0)
	# Der Körper liegt fast dunkel - bei Funkenflug ist nicht die Naht die
	# Erkennungsmarke, sondern der laufende Punkt.
	rift.idle_low = 0.15
	rift.idle_high = 0.88
	rift.idle_period = 2.6
	# Der hellste der vier, mit Absicht: Cyan-Bloom IST die Energie-Sprache des
	# Tisches, und dieser Ausbruch muss quer über den Tisch als dasselbe Licht lesen.
	rift.flare_peak = 4.0
	rift.core_share = 0.80
	rift.halo_flare = 3.5
	return rift

## Profil des Vakuum-Würfels: keine eigene id, sondern die Umkehrung, die JEDEN
## Riss eines solchen Würfels überschreibt - Licht fällt hinein statt heraus.
## Der violette Saum ist nicht Zierrat: eine schwarze Naht auf schwarzer Seite
## existiert ohne ihn schlicht nicht.
static func vacuum_profile() -> Rift:
	var rift := _make(NONE, "Vakuum", "", "", "", Color(0.02, 0.02, 0.04), PATTERN_RING)
	rift.motion = MOTION_INTAKE
	rift.core = Color(0.55, 0.35, 0.85)
	rift.idle_low = 0.75
	rift.idle_high = 0.95
	rift.idle_period = 5.0
	rift.flare_peak = 1.10
	rift.core_share = 0.90
	rift.halo_flare = 1.0
	return rift

## Naht-Farbe für den Shader: derselbe Farbton wie tint, aber auf max == 1
## normiert. So heißt "energy" in jedem Profil dasselbe (die hellste Komponente),
## und die Ruhe-Regel ist über alle vier Tönungen hinweg vergleichbar. Funkenflug
## trägt HDR-Cyan (CasinoStyle.CHARGE) - erst die Normierung macht es messbar.
func normalized_seam() -> Color:
	var peak := maxf(tint.r, maxf(tint.g, tint.b))
	if peak <= 0.0:
		return Color(1, 1, 1)
	return Color(tint.r / peak, tint.g / peak, tint.b / peak)

## Anzeige-Profil einer Seite: die Essenz schlägt den Rift, weil der Vakuum-
## Würfel jeden Bruch schwarz macht (RiftEffects.crack_color folgt derselben Regel).
static func profile_for(rift_id: String, essence_id: String) -> Rift:
	if essence_id == Essence.VACUUM:
		return vacuum_profile()
	return by_id(rift_id)

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

## Sperrzone der Ziffer: halbe Achsen einer mittigen Ellipse in normierten
## Seiten-Koordinaten. Die Ziffer frisst 86 % der Seitenhöhe, also ist die Mitte
## der UNFREIESTE Platz der Seite - jeder Riss läuft außen herum. Maß: einstellige
## 3D-Schwärze (0.19, 0.31) plus 0.07 Bloom-Saum je Achse.
const GLYPH_KEEPOUT := Vector2(0.26, 0.38)

## Ellipsen-Wert eines Punktes: >= 1 heißt "außerhalb der Sperrzone". Eine Quelle
## für die Geometrie-Prüfung im Test und den Shader-Wächter.
static func glyph_clearance(point: Vector2, half := GLYPH_KEEPOUT) -> float:
	var dx := (point.x - 0.5) / half.x
	var dy := (point.y - 0.5) / half.y
	return dx * dx + dy * dy

## Rissbild als normierte Polylinien (0..1 in der Zelle). EINE Quelle für das
## Würfelnetz und die 3D-Auflage - sonst zeigt der Tisch ein anderes Muster als
## die Werkbank.
##
## Zwei Regeln formen jedes Muster, und sie ziehen zum Glück in dieselbe Richtung:
## Ein echter Bruch läuft von Rand zu Rand (was in der Mitte anfängt und aufhört,
## ist ein Kratzer), und genau das hält ihn automatisch von der Ziffer frei.
## Kein Punkt und kein Segment darf GLYPH_KEEPOUT verletzen - test_rift_geometry
## wacht darüber. Die Figur ist NIE eine Funktion des Seitenwerts: Knochen lässt
## Werte wachsen, und ein Riss, der sich dabei neu zeichnet, liest als Fehler.
static func crack_lines(pattern_id: String) -> Array[PackedVector2Array]:
	match pattern_id:
		PATTERN_RING:
			# Ringriss: offener Ring, oben rechts 56° aufgesprungen. Aus beiden
			# Bruchenden läuft ein Ausläufer zum Rand - der Ring schwebt nicht.
			var ring := PackedVector2Array()
			for step in 15:
				var angle := deg_to_rad(28.0 + 304.0 * float(step) / 14.0)
				ring.append(Vector2(0.5 + 0.40 * cos(angle), 0.5 + 0.44 * sin(angle)))
			return [
				ring,
				PackedVector2Array([Vector2(0.853, 0.294), Vector2(0.99, 0.20)]),
				PackedVector2Array([Vector2(0.853, 0.707), Vector2(0.99, 0.80)]),
				PackedVector2Array([Vector2(0.194, 0.783), Vector2(0.06, 0.90)]),
			]
		PATTERN_HAIRLINES:
			# Haarrisse: vier feine Striche in den Seitenrändern, bewusst ungleich
			# lang und ohne gemeinsamen Ursprung - Streuschaden, kein Ereignis.
			return [
				PackedVector2Array([Vector2(0.02, 0.30), Vector2(0.19, 0.52), Vector2(0.13, 0.78)]),
				PackedVector2Array([Vector2(0.22, 0.02), Vector2(0.16, 0.24)]),
				PackedVector2Array([Vector2(0.98, 0.38), Vector2(0.80, 0.55), Vector2(0.86, 0.82)]),
				PackedVector2Array([Vector2(0.72, 0.96), Vector2(0.79, 0.74)]),
				PackedVector2Array([Vector2(0.19, 0.52), Vector2(0.05, 0.60)]),
			]
		PATTERN_STAR:
			# Sternbruch: der Einschlag sitzt AUSSERMITTIG in der linken unteren
			# Schulter, fünf Strahlen fächern zu drei Rändern. Jeder Strahl beginnt
			# am Einschlag - daher ist dort die Bogenlänge 0 und die Glut am heißesten.
			return [
				PackedVector2Array([Vector2(0.20, 0.68), Vector2(0.02, 0.86)]),
				PackedVector2Array([Vector2(0.20, 0.68), Vector2(0.10, 0.30), Vector2(0.16, 0.04)]),
				PackedVector2Array([Vector2(0.20, 0.68), Vector2(0.34, 0.93), Vector2(0.42, 0.99)]),
				PackedVector2Array([Vector2(0.20, 0.68), Vector2(0.05, 0.52)]),
				PackedVector2Array([Vector2(0.20, 0.68), Vector2(0.26, 0.84)]),
			]
		PATTERN_BOLT:
			# Zickzack von Rand zu Rand: der Funke kommt von außen und geht wieder.
			# Die Innenschwünge liegen am engsten an der Sperrzone (1.25) - nichts
			# davon darf nach links wandern.
			return [
				PackedVector2Array([
					Vector2(0.76, 0.00), Vector2(0.89, 0.19), Vector2(0.77, 0.34),
					Vector2(0.91, 0.55), Vector2(0.75, 0.74), Vector2(0.87, 1.00)]),
				PackedVector2Array([Vector2(0.75, 0.74), Vector2(0.62, 0.92)]),
			]
	return []

## Strichgewicht je Polylinie - 1.0 für den Hauptbruch, 0.40-0.50 für eine
## Abzweigung. Ein echter Riss gabelt sich, und die Gabel ist dünner als ihr
## Stamm; das ist das billigste Kintsugi-Merkmal, das es gibt.
static func crack_weights(pattern_id: String) -> PackedFloat32Array:
	match pattern_id:
		PATTERN_RING:
			return PackedFloat32Array([1.0, 0.85, 0.85, 0.45])
		PATTERN_HAIRLINES:
			return PackedFloat32Array([1.0, 0.80, 1.0, 0.80, 0.40])
		PATTERN_STAR:
			return PackedFloat32Array([1.0, 1.0, 1.0, 0.85, 0.50])
		PATTERN_BOLT:
			return PackedFloat32Array([1.0, 0.50])
	return PackedFloat32Array()

## Alle Musterschlüssel - der Bake und der Geometrie-Test laufen darüber.
static func all_patterns() -> Array[String]:
	return [PATTERN_RING, PATTERN_HAIRLINES, PATTERN_STAR, PATTERN_BOLT]

## Rissbild eines Rifts (leer bei unbekannter id).
static func lines_for(rift_id: String) -> Array[PackedVector2Array]:
	var rift := by_id(rift_id)
	return crack_lines(rift.pattern) if rift != null else [] as Array[PackedVector2Array]
