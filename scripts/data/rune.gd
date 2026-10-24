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
## Zeitliche Signatur: die Essenz glüht DAUERND und gleichmäßig, eine Rune ATMET in
## Ruhe und flammt im Moment ihres Feuerns um ein Vielfaches auf.

# --- Zeichen (die Figur IST die Erkennungsmarke) - je Rune eines ---
const GLYPH_AFTERGLOW := "glyph_afterglow"
const GLYPH_STRAY_LIGHT := "glyph_stray_light"
const GLYPH_BURN_IN := "glyph_burn_in"
const GLYPH_SPARK_FLIGHT := "glyph_spark_flight"
const GLYPH_REVERSE := "glyph_reverse"

# --- Runen-ids (Single Source of Truth) ---
const AFTERGLOW := "afterglow"        # Nachglühen: +1 Auslösung
const STRAY_LIGHT := "stray_light"    # Streulicht: +$1 je ungewertetem Zugende
const BURN_IN := "burn_in"            # Einbrand: Seitenwert eingebrannt
const SPARK_FLIGHT := "spark_flight"  # Funkenflug: +1 ⚡ beim Werten
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
## Energy-Cyan der Energie, denselben Wert wie CasinoStyle.ENERGY, hier
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

## Die BLOOM-SCHWELLE des Renderers. Data-Cells und Gruben-Licht messen ihr
## Ruhelicht daran - der Wert ist gemeinsames Gut, keine Runen-Zahl.
const IDLE_CEILING := 0.95

## DIE RUHE-REGEL, gekippt am 2026-09-11 (Spieler: "viel zu schwach, es sollte von
## der Distanz einfach zu erkennen sein"): eine Rune DARF in Ruhe blühen. Bis dahin
## galt das Gegenteil - der Preis war eine Naht, die auf Grubendistanz gar nicht
## existierte. Was sie jetzt bändigt, ist kein Deckel, sondern der ABSTAND: der
## Ausbruch überstrahlt die Ruhespitze um FLARE_RATIO, sonst liest das Feuern nicht
## mehr als Ereignis. Unter IDLE_GLOW bleibt keine Naht.
const IDLE_GLOW := 0.90
const FLARE_RATIO := 2.2

## Bewegungsart im Shader.
@export var motion: int = MOTION_ECHO
## Kernfarbe im heißen Faden (die Naht selbst trägt tint).
@export var core: Color = Color.WHITE
## Ruhe-Schimmern: Grundwert und Spitze. Beide liegen ÜBER der Bloom-Schwelle -
## bei ECHO und SPARK trägt idle_low fast die ganze Naht, also entscheidet ER, ob
## die Rune auf Distanz liest.
@export var idle_low: float = 1.20
@export var idle_high: float = 2.40
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
@export var halo_width: float = 0.70
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
		"Wertung", Color(1.0, 1.0, 1.0), GLYPH_AFTERGLOW)
	rune.motion = MOTION_ECHO
	rune.core = Color(1.0, 1.0, 1.0)
	# Die farblose der sechs: sie liest über Helligkeit, nicht über den Ton.
	rune.idle_low = 1.30
	rune.idle_high = 2.50
	rune.idle_period = 4.2
	rune.flare_peak = 6.0
	rune.core_share = 0.55
	rune.halo_width = 0.70
	rune.halo_flare = 3.0
	return rune

static func stray_light() -> Rune:
	var rune := _make(STRAY_LIGHT, "Streulicht", "+$1 ungewertet",
		"Liegt der Würfel am Zugende ungewertet auf dem Tisch und zeigt diese Seite: +$1. Er streut sein Licht ungenutzt aufs Filz.",
		"Ökonomie", Color(1.0, 0.74, 0.26), GLYPH_STRAY_LIGHT)
	rune.motion = MOTION_SCATTER
	rune.core = Color(1.0, 0.92, 0.66)
	rune.idle_low = 1.20
	rune.idle_high = 2.40
	rune.idle_period = 3.1
	rune.flare_peak = 5.4
	rune.core_share = 0.35
	rune.halo_width = 0.78
	rune.halo_flare = 2.5
	# Das Licht fällt vom Würfel aufs Filz - die Fiktion der Wirkung.
	rune.halo_bias = Vector2(0.0, 1.0)
	return rune

static func burn_in() -> Rune:
	var rune := _make(BURN_IN, "Einbrand", "Seite eingebrannt",
		"Der Wert dieser Seite ist eingebrannt: er kann nicht schrumpfen, und ihr Material lässt sich nicht übermalen.",
		"Schutz", Color(1.0, 0.38, 0.08), GLYPH_BURN_IN)
	rune.motion = MOTION_EMBER
	rune.core = Color(1.0, 0.84, 0.55)
	# Höchster Ruhe-Boden der sechs: Einbrand ist ein Zustand, kein Ereignis.
	rune.idle_low = 1.45
	rune.idle_high = 2.60
	rune.idle_period = 2.4
	rune.flare_peak = 6.0
	rune.core_share = 0.25
	rune.halo_width = 0.80
	rune.halo_flare = 2.6
	return rune

static func spark_flight() -> Rune:
	var rune := _make(SPARK_FLIGHT, "Funkenflug", "+1 ⚡ beim Werten",
		"Wird diese Seite gewertet, springt ein Funke über: +1 Energie, einmal je Zug.",
		"Wertung", Color(0.55, 1.9, 2.1), GLYPH_SPARK_FLIGHT)
	rune.motion = MOTION_SPARK
	rune.core = Color(0.80, 1.0, 1.0)
	# Die Naht glüht mit, seit die Rune auf Distanz lesen muss - der laufende Punkt
	# bleibt trotzdem die Erkennungsmarke, er hebt sich um die volle Spanne ab.
	rune.idle_low = 1.15
	rune.idle_high = 2.70
	rune.idle_period = 2.6
	# Der hellste der vier, mit Absicht: Cyan-Bloom IST die Energie-Sprache des
	# Tisches, und dieser Ausbruch muss quer über den Tisch als dasselbe Licht lesen.
	rune.flare_peak = 7.0
	rune.core_share = 0.80
	rune.halo_width = 0.68
	rune.halo_flare = 3.5
	return rune

static func reverse() -> Rune:
	var rune := _make(REVERSE, "Kehrseite", "Gegenseite löst mit aus",
		"Wird diese Seite gewertet, löst die gegenüberliegende Seite zusätzlich einmal voll mit aus.",
		"Wertung", Color(0.66, 0.36, 1.0), GLYPH_REVERSE)
	rune.motion = MOTION_ECHO
	rune.core = Color(0.92, 0.82, 1.0)
	rune.idle_low = 1.30
	rune.idle_high = 2.50
	rune.idle_period = 4.6
	rune.flare_peak = 6.0
	rune.core_share = 0.60
	rune.halo_width = 0.72
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
## trägt HDR-Cyan (CasinoStyle.ENERGY) - erst die Normierung macht es messbar.
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
	return [afterglow(), stray_light(), burn_in(), spark_flight(), reverse()]

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

## Wie ein zweiter/dritter Rune derselben Seite seinen Platz findet: dieselbe
## Figur, INEINANDER. Eine Grundform gespiegelt wäre sie selbst - der Platz
## staffelt darum die GRÖSSE statt der Lage. Mehr als eine trägt nur das Vakuum.
## Weiter nach innen geht es nicht: die Ziffer deckt die Mitte, und was ganz hinter
## ihr liegt, ist kein Zeichen mehr - der dritte Platz zeigt darum nur noch, was
## links und rechts der Zahl vorbeiläuft.
const SLOT_SCALES: Array[float] = [1.0, 0.72, 0.48]

## Maßstab eines Platzes - ein unbekannter Platz fällt auf den ersten zurück.
static func slot_scale(slot: int) -> float:
	return SLOT_SCALES[slot] if slot >= 0 and slot < SLOT_SCALES.size() else SLOT_SCALES[0]

## Ein Figur-Punkt an seinem Platz. EINE Funktion für Seite UND Netz: der Kasten
## ist beide Male die volle Fläche, und der Platz schrumpft um ihre Mitte.
static func place(point: Vector2, slot: int) -> Vector2:
	return CENTER + (point - CENTER) * slot_scale(slot)

## Rand, den jedes Zeichen auf der SEITE frei lässt - er trägt den Hof
## (RuneTextures.FIELD), damit der Ausbruch nicht am Seitenrand abgeschnitten
## wird. Alle Figuren leben deshalb in [MARGIN, 1 - MARGIN]².
const GLYPH_MARGIN := 0.06

## Mitte der Seite - jede Grundform liegt um sie.
const CENTER := Vector2(0.5, 0.5)

## Geschlossener Linienzug aus steps Ecken auf einem Kreis um CENTER. turn dreht
## die Figur (Grad, 0 = erste Ecke OBEN); der letzte Punkt IST der erste.
static func _ring(radius: float, steps: int, turn := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var phi := deg_to_rad(turn) + TAU * float(i % steps) / float(steps)
		points.append(CENTER + Vector2(radius * sin(phi), -radius * cos(phi)))
	return points

## Stern mit spikes Zacken: die Ecken wechseln zwischen outer und inner.
static func _star(spikes: int, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := spikes * 2
	for i in corners + 1:
		var step := i % corners
		var radius := outer if step % 2 == 0 else inner
		var phi := TAU * float(step) / float(corners)
		points.append(CENTER + Vector2(radius * sin(phi), -radius * cos(phi)))
	return points

## Achsenparalleles Quadrat um CENTER (half = halbe Kantenlänge).
static func _box(half: float) -> PackedVector2Array:
	return PackedVector2Array([CENTER + Vector2(-half, -half), CENTER + Vector2(half, -half),
		CENTER + Vector2(half, half), CENTER + Vector2(-half, half),
		CENTER + Vector2(-half, -half)])

## Das Zeichen als normierte Polylinien in SEITEN-Koordinaten (0..1 über die ganze
## Seite), x nach rechts, y nach UNTEN. Seit den GRUNDFORMEN (2026-10-24) ist jede
## Figur EINE geschlossene, zur Hochachse symmetrische Grundform um die Seitenmitte:
## auf Grubendistanz ist eine Seite ~25 px breit, und dort liest eine SILHOUETTE,
## wo ein Linienzug zu Matsch wird. Sie läuft HINTER der Ziffer durch - die schreibt
## Tiefe und deckt mitsamt ihrem dunklen Saum, was sie überschneidet. EINE Quelle
## für Würfelnetz und 3D-Auflage; wohin ein zweiter Rune kommt, sagt SLOT_SCALES.
##
## RADIUS ist für alle derselbe (1 - GLYPH_MARGIN - Seitenmitte): eine Grundform,
## die kleiner ausfällt als ihre Nachbarin, liest als zweite Größe statt als zweites
## Zeichen. Die Figur ist NIE eine Funktion des Seitenwerts - Knochen lässt Werte
## wachsen, und eine Rune, die sich dabei neu zeichnet, liest als Fehler.
const GLYPH_RADIUS := 0.44
## Halbe Kantenlänge des QUADRATS - die eine Figur, die nicht auf dem Radius
## sitzt, sondern auf ihrer SEITE (Spieler-Entscheid 2026-10-24): auf voller Größe
## liefe sie 0,88 der Seite breit, und der Leuchtrahmen einer Material-Seite liegt
## auf 0,03 - zwei fast gleiche Linien mit 0,03 Luft dazwischen lasen als EINE.
## Hereingezogen auf 0,80 ist die Fuge mehr als doppelt so breit (0,07).
const SQUARE_HALF := 0.40

static func glyph_lines(glyph_id: String) -> Array[PackedVector2Array]:
	match glyph_id:
		GLYPH_AFTERGLOW:
			# RING: der geschlossene Umlauf - die Seite läuft noch einmal um.
			return [_ring(GLYPH_RADIUS, 48)]
		GLYPH_STRAY_LIGHT:
			# DREIECK nach UNTEN: das Licht fällt vom Würfel aufs Filz.
			return [_ring(GLYPH_RADIUS, 3, 180.0)]
		GLYPH_BURN_IN:
			# QUADRAT: eingebrannt ist festgeklammert und hat keinen Ausgang.
			return [_box(SQUARE_HALF)]
		GLYPH_SPARK_FLIGHT:
			# STERN: der übergesprungene Funke.
			return [_star(6, GLYPH_RADIUS, 0.19)]
		GLYPH_REVERSE:
			# RAUTE: das Quadrat auf die andere Seite gedreht.
			return [_ring(GLYPH_RADIUS, 4)]
	return []

## Strichstärke je Polylinie. Eine Grundform ist EIN Strich konstanter Tiefe -
## seit den GRUNDFORMEN trägt jedes Zeichen genau eine 1.0, und ein Beistrich
## wäre ein zweites Zeichen.
static func glyph_weights(glyph_id: String) -> PackedFloat32Array:
	return PackedFloat32Array([1.0]) if not glyph_lines(glyph_id).is_empty() 		else PackedFloat32Array()

## Der Kasten, in dem eine Figur WIRKLICH liegt (Seiten-Koordinaten, leer =
## unbekanntes Zeichen). Auf dem 3D-WÜRFEL zählt er nicht - dort läuft die Figur
## um eine Ziffer herum, und die Mitte gehört ihr. Auf KARTE und WÜRFELNETZ zieht
## der Kasten sich auf die ganze Kachel (das Netz seit 2026-09-11, die Ziffer
## liegt dort über der Figur), sonst
## verschenkte eine Prägenetz-Zelle den leeren Kranz (gemessen: Streulicht stand
## als 3-px-Strich am Rand einer 34-px-Zelle).
static func glyph_bounds(glyph_id: String) -> Rect2:
	if _bounds_cache.has(glyph_id):
		return _bounds_cache[glyph_id]
	var box := Rect2()
	var first := true
	for line: PackedVector2Array in glyph_lines(glyph_id):
		for point in line:
			box = Rect2(point, Vector2.ZERO) if first else box.expand(point)
			first = false
	_bounds_cache[glyph_id] = box
	return box

static var _bounds_cache: Dictionary = {}

## Ein Figur-Punkt, auf seinen eigenen Kasten normiert (0..1 je Achse) - der Weg
## auf die Karte. Ein platter Kasten wird dabei gestreckt: die Figuren, die das
## trifft, bestehen ohnehin nur aus Strichen längs dieser Achse.
static func fit_to_bounds(point: Vector2, box: Rect2) -> Vector2:
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return point
	return (point - box.position) / box.size

## Alle Zeichenschlüssel - der Bake und der Geometrie-Test laufen darüber.
static func all_glyphs() -> Array[String]:
	return [GLYPH_AFTERGLOW, GLYPH_STRAY_LIGHT, GLYPH_BURN_IN, GLYPH_SPARK_FLIGHT,
		GLYPH_REVERSE]
