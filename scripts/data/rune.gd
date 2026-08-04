class_name Rune
extends Resource
## Ein Rune: ein kontrollierter Bruch der Würfelschale. Jeder Würfel ist um einen
## Funken rohen Lichts gegossen - denselben Stoff, den das Casino als Energie
## abfüllt. Die Gravur reißt eine Seite entlang eines Musters auf und versiegelt
## sie sofort mit getönter Glasur: Glasur lässt Licht durch, Gas nicht, also
## bleibt die Essenz drin und der Würfel gilt weiter als nie geöffnet.
## Die TÖNUNG ist die Wirkung - ein Kern, vier Farben, vier Effekte.
##
## Nur Anzeige-Infos; die Wirkung löst RuneEffects über die id auf. Max. 1 Rune
## je Seite - Ausnahme ist der Vakuum-Würfel (siehe DieDefinition.second_runes).
## Zeitliche Signatur: die Essenz glüht DAUERND, eine Rune schimmert in Ruhe nur
## schwach und flammt im Moment seines Feuerns auf.

# --- Runenzeichen (das Muster IST die Erkennungsmarke) ---
const GLYPH_RING := "ring"
const GLYPH_HAIRLINES := "hairlines"
const GLYPH_STAR := "star"
const GLYPH_BOLT := "bolt"

# --- Runen-ids (Single Source of Truth) ---
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
## Farbe der Glasur im Rune. Funkenflug trägt das Charge-Cyan der Energie -
## derselbe Wert wie CasinoStyle.CHARGE, hier gespiegelt, weil data/ nie aus
## ui/ importieren darf (die Ordner SIND die Abhängigkeitsregel).
@export var tint: Color = Color.WHITE
@export var pattern: String = GLYPH_RING

# --- Bewegungsarten (Schlüssel in die_rune.gdshader) ---
const MOTION_ECHO := 0      # Nachglühen: eine Bande wandert, der Blitz wiederholt sich
const MOTION_SCATTER := 1   # Streulicht: kein Lauf, nur Glitzern an Ort und Stelle
const MOTION_EMBER := 2     # Einbrand: Glut kriecht die Strahlen hoch und zurück
const MOTION_SPARK := 3     # Funkenflug: ein Kopf läuft die Bahn und verlässt sie
const MOTION_INTAKE := 4    # Vakuum: die Naht saugt sich zu, statt zu strahlen

## DIE RUHE-REGEL: kein Ruhe-Schimmern darf die Bloom-Schwelle erreichen. Das ist
## es, was sechs beschriftete Würfel in der Grube mechanisch davon abhält, eine Disco
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

static func _make(rune_id: String, name: String, short_text: String, desc: String,
		kind_text: String, tint_color: Color, glyph_id: String) -> Rune:
	var rune := Rune.new()
	rune.id = rune_id
	rune.display_name = name
	rune.short = short_text
	rune.description = desc
	rune.kind = kind_text
	rune.tint = tint_color
	rune.pattern = glyph_id
	return rune

static func afterglow() -> Rune:
	var rune := _make(AFTERGLOW, "Nachglühen", "+1 Auslösung",
		"Wird diese Seite gewertet, glüht sie einmal nach: der Würfel löst einmal zusätzlich aus.",
		"Wertung", Color(0.88, 0.9, 0.95), GLYPH_RING)
	rune.motion = MOTION_ECHO
	rune.core = Color(1.0, 1.0, 1.0)
	rune.idle_low = 0.22
	rune.idle_high = 0.62
	rune.idle_period = 4.2
	rune.flare_peak = 3.0
	rune.core_share = 0.55
	rune.halo_flare = 3.0
	return rune

static func stray_light() -> Rune:
	var rune := _make(STRAY_LIGHT, "Streulicht", "+$1 ungewertet",
		"Liegt der Würfel am Zugende ungewertet auf dem Tisch und zeigt diese Seite: +$1. Er streut sein Licht ungenutzt aufs Filz.",
		"Ökonomie", Color(1.0, 0.82, 0.45), GLYPH_HAIRLINES)
	rune.motion = MOTION_SCATTER
	rune.core = Color(1.0, 0.93, 0.72)
	rune.idle_low = 0.20
	rune.idle_high = 0.70
	rune.idle_period = 3.1
	rune.flare_peak = 2.2
	rune.core_share = 0.35
	rune.halo_flare = 2.5
	# Das Licht fällt vom Würfel aufs Filz - die Fiktion der Wirkung.
	rune.halo_bias = Vector2(0.0, 1.0)
	return rune

static func burn_in() -> Rune:
	var rune := _make(BURN_IN, "Einbrand", "Seite eingebrannt",
		"Der Wert dieser Seite ist eingebrannt: er kann nicht schrumpfen, und ihr Material lässt sich nicht übermalen.",
		"Schutz", Color(1.0, 0.5, 0.15), GLYPH_STAR)
	rune.motion = MOTION_EMBER
	rune.core = Color(1.0, 0.86, 0.62)
	# Höchster Ruhe-Boden der vier: Einbrand ist ein Zustand, kein Ereignis.
	rune.idle_low = 0.30
	rune.idle_high = 0.66
	rune.idle_period = 2.4
	rune.flare_peak = 2.8
	rune.core_share = 0.25
	rune.halo_flare = 2.6
	return rune

static func spark_flight() -> Rune:
	var rune := _make(SPARK_FLIGHT, "Funkenflug", "+1 ⚡ beim Werten",
		"Wird diese Seite gewertet, springt ein Funke über: +1 Energie, einmal je Zug.",
		"Wertung", Color(0.55, 1.9, 2.1), GLYPH_BOLT)
	rune.motion = MOTION_SPARK
	rune.core = Color(0.80, 1.0, 1.0)
	# Der Körper liegt fast dunkel - bei Funkenflug ist nicht die Naht die
	# Erkennungsmarke, sondern der laufende Punkt.
	rune.idle_low = 0.15
	rune.idle_high = 0.88
	rune.idle_period = 2.6
	# Der hellste der vier, mit Absicht: Cyan-Bloom IST die Energie-Sprache des
	# Tisches, und dieser Ausbruch muss quer über den Tisch als dasselbe Licht lesen.
	rune.flare_peak = 4.0
	rune.core_share = 0.80
	rune.halo_flare = 3.5
	return rune

## Profil des Vakuum-Würfels: keine eigene id, sondern die Umkehrung, die JEDEN
## Rune eines solchen Würfels überschreibt - Licht fällt hinein statt heraus.
## Der violette Saum ist nicht Zierrat: eine schwarze Naht auf schwarzer Seite
## existiert ohne ihn schlicht nicht.
static func vacuum_profile() -> Rune:
	var rune := _make(NONE, "Vakuum", "", "", "", Color(0.02, 0.02, 0.04), GLYPH_RING)
	rune.motion = MOTION_INTAKE
	rune.core = Color(0.55, 0.35, 0.85)
	rune.idle_low = 0.75
	rune.idle_high = 0.95
	rune.idle_period = 5.0
	rune.flare_peak = 1.10
	rune.core_share = 0.90
	rune.halo_flare = 1.0
	return rune

## Naht-Farbe für den Shader: derselbe Farbton wie tint, aber auf max == 1
## normiert. So heißt "energy" in jedem Profil dasselbe (die hellste Komponente),
## und die Ruhe-Regel ist über alle vier Tönungen hinweg vergleichbar. Funkenflug
## trägt HDR-Cyan (CasinoStyle.CHARGE) - erst die Normierung macht es messbar.
func normalized_seam() -> Color:
	var peak := maxf(tint.r, maxf(tint.g, tint.b))
	if peak <= 0.0:
		return Color(1, 1, 1)
	return Color(tint.r / peak, tint.g / peak, tint.b / peak)

## Anzeige-Profil einer Seite: die Essenz schlägt die Rune, weil der Vakuum-
## Würfel jeden Bruch schwarz macht (RuneEffects.glyph_color folgt derselben Regel).
static func profile_for(rune_id: String, essence_id: String) -> Rune:
	if essence_id == Essence.VACUUM:
		return vacuum_profile()
	return by_id(rune_id)

## Kanonische Registrierung aller Runen.
static func all() -> Array[Rune]:
	return [afterglow(), stray_light(), burn_in(), spark_flight()]

static func by_id(rune_id: String) -> Rune:
	for rune in all():
		if rune.id == rune_id:
			return rune
	return null

static func is_valid_id(rune_id: String) -> bool:
	return by_id(rune_id) != null

## Tönung zur id - Schwarz ohne Rune. Der Vakuum-Würfel überschreibt das später
## ohnehin: seine Runen sind schwarz, er saugt das Kernlicht nach innen.
static func tint_for(rune_id: String) -> Color:
	var rune := by_id(rune_id)
	return rune.tint if rune != null else Color.BLACK

## Kurz-Erklärzeile fürs Hover-Feld ("" ohne Rune): «Name» (Klasse): Wirkung.
static func hint(rune_id: String) -> String:
	var rune := by_id(rune_id)
	if rune == null:
		return ""
	return "%s (%s): %s" % [rune.display_name, rune.kind, rune.short]

## Sperrzone der Ziffer: halbe Achsen einer mittigen Ellipse in normierten
## Seiten-Koordinaten. Die Ziffer frisst 86 % der Seitenhöhe, also ist die Mitte
## der UNFREIESTE Platz der Seite - jeder Rune läuft außen herum. Maß: einstellige
## 3D-Schwärze (0.19, 0.31) plus 0.07 Bloom-Saum je Achse.
const DIGIT_KEEPOUT := Vector2(0.26, 0.38)

## Ellipsen-Wert eines Punktes: >= 1 heißt "außerhalb der Sperrzone". Eine Quelle
## für die Geometrie-Prüfung im Test und den Shader-Wächter.
static func digit_clearance(point: Vector2, half := DIGIT_KEEPOUT) -> float:
	var dx := (point.x - 0.5) / half.x
	var dy := (point.y - 0.5) / half.y
	return dx * dx + dy * dy

## Runenzeichen als normierte Polylinien (0..1 in der Zelle). EINE Quelle für das
## Würfelnetz und die 3D-Auflage - sonst zeigt der Tisch ein anderes Muster als
## die Werkbank.
##
## Zwei Regeln formen jedes Muster, und sie ziehen zum Glück in dieselbe Richtung:
## Ein echter Bruch läuft von Rand zu Rand (was in der Mitte anfängt und aufhört,
## ist ein Kratzer), und genau das hält ihn automatisch von der Ziffer frei.
## Kein Punkt und kein Segment darf DIGIT_KEEPOUT verletzen - test_rune_geometry
## wacht darüber. Die Figur ist NIE eine Funktion des Seitenwerts: Knochen lässt
## Werte wachsen, und eine Rune, der sich dabei neu zeichnet, liest als Fehler.
static func glyph_lines(glyph_id: String) -> Array[PackedVector2Array]:
	match glyph_id:
		GLYPH_RING:
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
		GLYPH_HAIRLINES:
			# Haarrisse: vier feine Striche in den Seitenrändern, bewusst ungleich
			# lang und ohne gemeinsamen Ursprung - Streuschaden, kein Ereignis.
			return [
				PackedVector2Array([Vector2(0.02, 0.30), Vector2(0.19, 0.52), Vector2(0.13, 0.78)]),
				PackedVector2Array([Vector2(0.22, 0.02), Vector2(0.16, 0.24)]),
				PackedVector2Array([Vector2(0.98, 0.38), Vector2(0.80, 0.55), Vector2(0.86, 0.82)]),
				PackedVector2Array([Vector2(0.72, 0.96), Vector2(0.79, 0.74)]),
				PackedVector2Array([Vector2(0.19, 0.52), Vector2(0.05, 0.60)]),
			]
		GLYPH_STAR:
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
		GLYPH_BOLT:
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
## Abzweigung. Ein echter Rune gabelt sich, und die Gabel ist dünner als ihr
## Stamm; das ist das billigste Kintsugi-Merkmal, das es gibt.
static func glyph_weights(glyph_id: String) -> PackedFloat32Array:
	match glyph_id:
		GLYPH_RING:
			return PackedFloat32Array([1.0, 0.85, 0.85, 0.45])
		GLYPH_HAIRLINES:
			return PackedFloat32Array([1.0, 0.80, 1.0, 0.80, 0.40])
		GLYPH_STAR:
			return PackedFloat32Array([1.0, 1.0, 1.0, 0.85, 0.50])
		GLYPH_BOLT:
			return PackedFloat32Array([1.0, 0.50])
	return PackedFloat32Array()

## Alle Musterschlüssel - der Bake und der Geometrie-Test laufen darüber.
static func all_glyphs() -> Array[String]:
	return [GLYPH_RING, GLYPH_HAIRLINES, GLYPH_STAR, GLYPH_BOLT]

## Runenzeichen eines Runen (leer bei unbekannter id).
static func lines_for(rune_id: String) -> Array[PackedVector2Array]:
	var rune := by_id(rune_id)
	return glyph_lines(rune.pattern) if rune != null else [] as Array[PackedVector2Array]
