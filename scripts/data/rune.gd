class_name Rune
extends Resource
## Eine Rune: ein in die Würfelschale geätztes Zeichen. Jeder Würfel ist um einen
## Funken rohen Lichts gegossen - denselben Stoff, den das Casino als Energie
## abfüllt. Die Gravur schneidet das Zeichen so tief in die Schale, dass es den
## Funken anzapft: das Kernlicht sammelt sich in der Rille und tritt entlang der
## Figur aus. Die TÖNUNG ist die Wirkung - ein Kern, sechs Farben, sechs Effekte.
##
## Nur Anzeige-Infos; die Wirkung löst RuneEffects über die id auf. Max. 1 Rune
## je Seite - Ausnahme ist der Vakuum-Würfel (siehe DieDefinition.second_runes).
## Zeitliche Signatur: die Essenz glüht DAUERND, eine Rune schimmert in Ruhe nur
## schwach und flammt im Moment ihres Feuerns auf.

# --- Zeichen (die Figur IST die Erkennungsmarke) - je Rune eines ---
const GLYPH_AFTERGLOW := "glyph_afterglow"
const GLYPH_STRAY_LIGHT := "glyph_stray_light"
const GLYPH_BURN_IN := "glyph_burn_in"
const GLYPH_SPARK_FLIGHT := "glyph_spark_flight"
const GLYPH_CAST := "glyph_cast"
const GLYPH_REVERSE := "glyph_reverse"

# --- Runen-ids (Single Source of Truth) ---
const AFTERGLOW := "afterglow"        # Nachglühen: +1 Auslösung
const STRAY_LIGHT := "stray_light"    # Streulicht: +$1 je ungewertetem Zugende
const BURN_IN := "burn_in"            # Einbrand: Seitenwert eingebrannt
const SPARK_FLIGHT := "spark_flight"  # Funkenflug: +1 ⚡ beim Werten
const CAST := "cast"                  # Abguss: Material-Gravur in den Vorrat
const REVERSE := "reverse"            # Kehrseite: Gegenseite löst mit aus

const NONE := ""

@export var id: String = ""
@export var display_name: String = ""
## Kurzwirkung für Karten und Hover-Zeilen ("+1 Auslösung").
@export var short: String = ""
@export var description: String = ""
## Klasse aus der Design-Seite: Wertung, Ökonomie oder Schutz - reine Flavor-
## Einordnung für die Anzeige, die Wirkung hängt an der id.
@export var kind: String = ""
## Tönung des Zeichens - die TÖNUNG IST die Wirkung. Funkenflug trägt das
## Charge-Cyan der Energie, denselben Wert wie CasinoStyle.CHARGE, hier
## gespiegelt: data/ darf nie aus ui/ importieren.
@export var tint: Color = Color.WHITE
## Zeichen dieser Rune (Schluessel in glyph_lines).
@export var glyph: String = GLYPH_AFTERGLOW

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
	rune.glyph = glyph_id
	return rune

static func afterglow() -> Rune:
	var rune := _make(AFTERGLOW, "Nachglühen", "+1 Auslösung",
		"Wird diese Seite gewertet, glüht sie einmal nach: der Würfel löst einmal zusätzlich aus.",
		"Wertung", Color(0.88, 0.9, 0.95), GLYPH_AFTERGLOW)
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
		"Ökonomie", Color(1.0, 0.82, 0.45), GLYPH_STRAY_LIGHT)
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
		"Schutz", Color(1.0, 0.5, 0.15), GLYPH_BURN_IN)
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
		"Wertung", Color(0.55, 1.9, 2.1), GLYPH_SPARK_FLIGHT)
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

static func cast() -> Rune:
	var rune := _make(CAST, "Abguss", "Material-Gravur je Zug",
		"Wird diese Seite gewertet, nimmt die Rune einen Abguss ihres Materials: eine Kopie dieser Material-Gravur wandert in die Werkstatt. Einmal je Runde und Würfel.",
		"Ökonomie", Color(0.72, 0.86, 0.62), GLYPH_CAST)
	rune.motion = MOTION_SCATTER
	rune.core = Color(0.90, 1.0, 0.82)
	rune.idle_low = 0.22
	rune.idle_high = 0.64
	rune.idle_period = 3.6
	rune.flare_peak = 2.4
	rune.core_share = 0.45
	rune.halo_flare = 2.5
	return rune

static func reverse() -> Rune:
	var rune := _make(REVERSE, "Kehrseite", "Gegenseite löst mit aus",
		"Wird diese Seite gewertet, löst die gegenüberliegende Seite zusätzlich einmal voll mit aus.",
		"Wertung", Color(0.82, 0.62, 1.0), GLYPH_REVERSE)
	rune.motion = MOTION_ECHO
	rune.core = Color(0.96, 0.90, 1.0)
	rune.idle_low = 0.24
	rune.idle_high = 0.66
	rune.idle_period = 4.6
	rune.flare_peak = 3.0
	rune.core_share = 0.60
	rune.halo_flare = 3.0
	return rune

## Profil des Vakuum-Würfels: keine eigene id, sondern die Umkehrung, die JEDEN
## Rune eines solchen Würfels überschreibt - Licht fällt hinein statt heraus.
## Der violette Saum ist nicht Zierrat: eine schwarze Naht auf schwarzer Seite
## existiert ohne ihn schlicht nicht.
static func vacuum_profile() -> Rune:
	var rune := _make(NONE, "Vakuum", "", "", "", Color(0.02, 0.02, 0.04), GLYPH_AFTERGLOW)
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
	return [afterglow(), stray_light(), burn_in(), spark_flight(), cast(), reverse()]

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
## der UNFREIESTE Platz der Seite. Maß: einstellige 3D-Schwärze (0.19, 0.31) plus
## 0.07 Bloom-Saum je Achse.
const DIGIT_KEEPOUT := Vector2(0.26, 0.38)

## Ankerzellen in Seiten-Koordinaten (min.xy, max.xy), eine je Runen-Platz. Ein
## Zeichen ist kompakt - anders als ein Riss hält es sich nicht von selbst von
## der Ziffer frei, also tut es die ZELLE: jede liegt ganz außerhalb von
## DIGIT_KEEPOUT (test_rune_geometry wacht darüber). Die Plätze nehmen
## gegenüberliegende Schultern, damit zwei Zeichen einer Vakuum-Seite sich nie
## in die Quere kommen; der dritte Platz (Glasglocke) bekommt die untere rechte.
## Die Zellen sind so GROSS wie die Sperrzone es zulässt - eine kleinere wäre auf
## Grubendistanz nicht mehr zu erkennen, eine größere liefe in die Ziffer.
const ANCHOR_CELLS: Array[Vector4] = [
	Vector4(0.01, 0.72, 0.27, 0.98),  # unten links
	Vector4(0.73, 0.02, 0.99, 0.28),  # oben rechts (punktsymmetrisch)
	Vector4(0.73, 0.72, 0.99, 0.98),  # unten rechts
]

## Ankerzelle eines Platzes - außerhalb der Liste fällt sie auf den ersten Platz
## zurück, damit ein unbekannter Platz nichts an eine falsche Stelle zeichnet.
static func anchor_cell(slot: int) -> Vector4:
	return ANCHOR_CELLS[slot] if slot >= 0 and slot < ANCHOR_CELLS.size() else ANCHOR_CELLS[0]

## Ein Punkt aus ZELLEN-Koordinaten (0..1) in Seiten-Koordinaten.
static func cell_to_face(point: Vector2, slot: int) -> Vector2:
	var cell := anchor_cell(slot)
	return Vector2(cell.x + point.x * (cell.z - cell.x), cell.y + point.y * (cell.w - cell.y))

## Ellipsen-Wert eines Punktes: >= 1 heißt "außerhalb der Sperrzone". Eine Quelle
## für die Geometrie-Prüfung im Test und den Shader-Wächter.
static func digit_clearance(point: Vector2, half := DIGIT_KEEPOUT) -> float:
	var dx := (point.x - 0.5) / half.x
	var dy := (point.y - 0.5) / half.y
	return dx * dx + dy * dy

## Rand, den jedes Zeichen in seiner Zelle frei lässt - er trägt den Hof
## (RuneTextures.FIELD), damit der Ausbruch nicht an der Zellkante abgeschnitten
## wird. Alle Figuren leben deshalb in [MARGIN, 1 - MARGIN]².
const GLYPH_MARGIN := 0.20

## Das Zeichen als normierte Polylinien in ZELLEN-Koordinaten (0..1), NICHT in
## Seiten-Koordinaten: die Zeichnung wird so nicht mit ihrer Platzierung
## vermischt - wohin sie kommt, sagt ANCHOR_CELLS. EINE Quelle für Würfelnetz und
## 3D-Auflage, sonst zeigt der Tisch ein anderes Zeichen als die Werkbank.
##
## Jede Figur ist ein ZEICHEN, kein Schaden: wenige gerade Striche, geschlossen
## oder gerichtet, je Wirkung eine erkennbare Idee. Die Figur ist NIE eine
## Funktion des Seitenwerts - Knochen lässt Werte wachsen, und eine Rune, die
## sich dabei neu zeichnet, liest als Fehler.
static func glyph_lines(glyph_id: String) -> Array[PackedVector2Array]:
	match glyph_id:
		GLYPH_AFTERGLOW:
			# Doppelstrich mit versetztem Echo: dieselbe Figur zweimal, die zweite
			# kleiner und nach hinten geschoben - die Wirkung als Bild.
			return [
				PackedVector2Array([Vector2(0.28, 0.80), Vector2(0.28, 0.20), Vector2(0.55, 0.42)]),
				PackedVector2Array([Vector2(0.50, 0.80), Vector2(0.50, 0.30), Vector2(0.76, 0.50)]),
			]
		GLYPH_SPARK_FLIGHT:
			# Aufsteigender Zickzack mit Austrittsstrich: der Funke klettert und
			# verlässt das Zeichen oben rechts.
			return [
				PackedVector2Array([Vector2(0.24, 0.80), Vector2(0.46, 0.56),
					Vector2(0.30, 0.48), Vector2(0.54, 0.22)]),
				PackedVector2Array([Vector2(0.54, 0.22), Vector2(0.76, 0.30)]),
			]
		GLYPH_STRAY_LIGHT:
			# Strahlenfächer nach unten: ein Balken, unter dem das Licht wegfällt.
			return [
				PackedVector2Array([Vector2(0.24, 0.30), Vector2(0.76, 0.30)]),
				PackedVector2Array([Vector2(0.32, 0.30), Vector2(0.26, 0.78)]),
				PackedVector2Array([Vector2(0.50, 0.30), Vector2(0.50, 0.80)]),
				PackedVector2Array([Vector2(0.68, 0.30), Vector2(0.74, 0.78)]),
			]
		GLYPH_BURN_IN:
			# Geschlossener Riegel: das einzige Zeichen ohne freies Ende - was
			# eingebrannt ist, hat keinen Ausgang.
			# Der Riegel nimmt die volle Zelle: enger gezogen wachsen seine vier
			# Striche zu einem Block zusammen und der Riegel ist nicht mehr zu sehen.
			return [
				PackedVector2Array([Vector2(0.20, 0.20), Vector2(0.80, 0.20),
					Vector2(0.80, 0.80), Vector2(0.20, 0.80), Vector2(0.20, 0.20)]),
				PackedVector2Array([Vector2(0.20, 0.50), Vector2(0.80, 0.50)]),
			]
		GLYPH_CAST:
			# Schale mit Abdruckstrich: der Strich fällt von oben in die Schale -
			# ein Abguss entsteht, indem etwas hineingedrückt wird.
			return [
				PackedVector2Array([Vector2(0.24, 0.34), Vector2(0.24, 0.62),
					Vector2(0.50, 0.78), Vector2(0.76, 0.62), Vector2(0.76, 0.34)]),
				PackedVector2Array([Vector2(0.50, 0.20), Vector2(0.50, 0.56)]),
			]
		GLYPH_REVERSE:
			# Punktsymmetrisches Doppel-V: dieselbe Figur, um die Zellmitte
			# gedreht - die Kehrseite als Geometrie.
			return [
				PackedVector2Array([Vector2(0.24, 0.24), Vector2(0.50, 0.44), Vector2(0.76, 0.24)]),
				PackedVector2Array([Vector2(0.24, 0.76), Vector2(0.50, 0.56), Vector2(0.76, 0.76)]),
				PackedVector2Array([Vector2(0.50, 0.44), Vector2(0.50, 0.56)]),
			]
	return []

## Strichstärke je Polylinie - 1.0 für den Hauptstrich, weniger für einen
## Beistrich. Ein geätztes Zeichen hat konstante Tiefe; die Stärke unterscheidet
## nur, was Figur und was Beiwerk ist.
static func glyph_weights(glyph_id: String) -> PackedFloat32Array:
	match glyph_id:
		GLYPH_AFTERGLOW:
			return PackedFloat32Array([1.0, 0.62])
		GLYPH_SPARK_FLIGHT:
			return PackedFloat32Array([1.0, 0.55])
		GLYPH_STRAY_LIGHT:
			return PackedFloat32Array([1.0, 0.70, 0.85, 0.70])
		GLYPH_BURN_IN:
			return PackedFloat32Array([1.0, 0.80])
		GLYPH_CAST:
			return PackedFloat32Array([1.0, 0.75])
		GLYPH_REVERSE:
			return PackedFloat32Array([1.0, 1.0, 0.55])
	return PackedFloat32Array()

## Alle Zeichenschlüssel - der Bake und der Geometrie-Test laufen darüber.
static func all_glyphs() -> Array[String]:
	return [GLYPH_AFTERGLOW, GLYPH_STRAY_LIGHT, GLYPH_BURN_IN, GLYPH_SPARK_FLIGHT,
		GLYPH_CAST, GLYPH_REVERSE]

## Runenzeichen eines Runen (leer bei unbekannter id).
static func lines_for(rune_id: String) -> Array[PackedVector2Array]:
	var rune := by_id(rune_id)
	return glyph_lines(rune.glyph) if rune != null else [] as Array[PackedVector2Array]
