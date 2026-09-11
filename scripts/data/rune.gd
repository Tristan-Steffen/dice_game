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

## Sperrzone der Ziffer: halbe Achsen einer mittigen Ellipse in normierten
## Seiten-Koordinaten. Die Ziffer frisst 86 % der Seitenhöhe, also ist die Mitte
## der UNFREIESTE Platz der Seite. Maß: einstellige 3D-Schwärze (0.19, 0.31) plus
## 0.07 Bloom-Saum je Achse.
const DIGIT_KEEPOUT := Vector2(0.26, 0.38)

## Ellipsen-Wert eines Punktes: >= 1 heißt "außerhalb der Sperrzone". Eine Quelle
## für die Geometrie-Prüfung im Test und den Shader-Wächter.
static func digit_clearance(point: Vector2, half := DIGIT_KEEPOUT) -> float:
	var dx := (point.x - 0.5) / half.x
	var dy := (point.y - 0.5) / half.y
	return dx * dx + dy * dy

## Wie ein zweiter/dritter Rune derselben Seite seinen Platz findet: dieselbe
## Figur, gespiegelt. Die Sperr-Ellipse ist punkt- UND achsensymmetrisch, also
## hält JEDE dieser Spiegelungen den Abstand zur Ziffer exakt ein - anders als
## eine Verschiebung.
const SLOT_FLIPS: Array[Vector2] = [
	Vector2(1.0, 1.0),    # Platz 0: die Figur, wie sie gezeichnet ist
	Vector2(-1.0, -1.0),  # Platz 1: punktgespiegelt
	Vector2(-1.0, 1.0),   # Platz 2: an der Hochachse gespiegelt
]

## Spiegelung eines Platzes - ein unbekannter Platz fällt auf den ersten zurück.
static func slot_flip(slot: int) -> Vector2:
	return SLOT_FLIPS[slot] if slot >= 0 and slot < SLOT_FLIPS.size() else SLOT_FLIPS[0]

## Ein Figur-Punkt an seinem Platz. EINE Funktion für Seite UND Netz: der Kasten
## ist beide Male die volle Fläche.
static func place(point: Vector2, slot: int) -> Vector2:
	var flip := slot_flip(slot)
	return Vector2(point.x if flip.x > 0.0 else 1.0 - point.x,
		point.y if flip.y > 0.0 else 1.0 - point.y)

## Rand, den jedes Zeichen auf der SEITE frei lässt - er trägt den Hof
## (RuneTextures.FIELD), damit der Ausbruch nicht am Seitenrand abgeschnitten
## wird. Alle Figuren leben deshalb in [MARGIN, 1 - MARGIN]².
const GLYPH_MARGIN := 0.06

## Punkte auf einer Ellipse um center, Winkel in Grad, 0 = OBEN, im Uhrzeigersinn.
## steps ist die Zahl der SEGMENTE, also steps + 1 Punkte.
static func _arc(center: Vector2, radius: Vector2, from_deg: float, to_deg: float,
		steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var phi := deg_to_rad(lerpf(from_deg, to_deg, float(i) / float(steps)))
		points.append(center + Vector2(radius.x * sin(phi), -radius.y * cos(phi)))
	return points

## Das Zeichen als normierte Polylinien in SEITEN-Koordinaten (0..1 über die ganze
## Seite), x nach rechts, y nach UNTEN. DER KRANZ: jede Figur liegt im Ring
## zwischen Ziffern-Sperrzone und Seitenrand, nicht mehr in einer Eckzelle. EINE
## Quelle für Würfelnetz und 3D-Auflage, sonst zeigt der Tisch ein anderes Zeichen
## als die Werkbank; wohin ein zweiter Rune derselben Seite kommt, sagt SLOT_FLIPS.
##
## Jede Figur ist ein ZEICHEN, kein Schaden: je Wirkung eine erkennbare Idee. Die
## Figur ist NIE eine Funktion des Seitenwerts - Knochen lässt Werte wachsen, und
## eine Rune, die sich dabei neu zeichnet, liest als Fehler.
static func glyph_lines(glyph_id: String) -> Array[PackedVector2Array]:
	match glyph_id:
		GLYPH_AFTERGLOW:
			# Umlauf-Pfeil: ein Dreiviertelkreis, der in einer Pfeilspitze endet -
			# die Seite läuft noch einmal um.
			return [
				_arc(Vector2(0.5, 0.5), Vector2(0.42, 0.42), 0.0, 250.0, 18),
				PackedVector2Array([Vector2(0.093, 0.728), Vector2(0.105, 0.644),
					Vector2(0.168, 0.701)]),
			]
		GLYPH_SPARK_FLIGHT:
			# Blitzbahn: der Zickzack klettert rechts hoch und schießt oben hinaus.
			return [
				PackedVector2Array([Vector2(0.80, 0.90), Vector2(0.77, 0.71),
					Vector2(0.88, 0.57), Vector2(0.79, 0.42), Vector2(0.90, 0.27)]),
				PackedVector2Array([Vector2(0.90, 0.27), Vector2(0.94, 0.09)]),
			]
		GLYPH_STRAY_LIGHT:
			# Lichtsaum: sechs Tropfen an der Unterkante. Unter der Ziffer bleibt
			# eine Lücke - dort ist im Kranz kein Platz, und das Licht sickert
			# ohnehin seitlich weg.
			return [
				PackedVector2Array([Vector2(0.10, 0.834), Vector2(0.10, 0.924)]),
				PackedVector2Array([Vector2(0.22, 0.834), Vector2(0.22, 0.924)]),
				PackedVector2Array([Vector2(0.34, 0.834), Vector2(0.34, 0.924)]),
				PackedVector2Array([Vector2(0.66, 0.834), Vector2(0.66, 0.924)]),
				PackedVector2Array([Vector2(0.78, 0.834), Vector2(0.78, 0.924)]),
				PackedVector2Array([Vector2(0.90, 0.834), Vector2(0.90, 0.924)]),
			]
		GLYPH_BURN_IN:
			# Brandklammern: vier L-Winkel in den Ecken - was eingebrannt ist, ist
			# festgeklammert und hat keinen Ausgang.
			return [
				PackedVector2Array([Vector2(0.10, 0.30), Vector2(0.10, 0.10), Vector2(0.30, 0.10)]),
				PackedVector2Array([Vector2(0.70, 0.10), Vector2(0.90, 0.10), Vector2(0.90, 0.30)]),
				PackedVector2Array([Vector2(0.90, 0.70), Vector2(0.90, 0.90), Vector2(0.70, 0.90)]),
				PackedVector2Array([Vector2(0.30, 0.90), Vector2(0.10, 0.90), Vector2(0.10, 0.70)]),
			]
		GLYPH_REVERSE:
			# Gegen-Pfeile: oben nach rechts, unten nach links. Punktsymmetrisch -
			# die Seite gedreht zeigt dasselbe Zeichen.
			return [
				PackedVector2Array([Vector2(0.20, 0.095), Vector2(0.80, 0.095)]),
				PackedVector2Array([Vector2(0.735, 0.065), Vector2(0.80, 0.095),
					Vector2(0.735, 0.125)]),
				PackedVector2Array([Vector2(0.80, 0.905), Vector2(0.20, 0.905)]),
				PackedVector2Array([Vector2(0.265, 0.875), Vector2(0.20, 0.905),
					Vector2(0.265, 0.935)]),
			]
	return []

## Strichstärke je Polylinie - 1.0 für den Hauptstrich, weniger für einen
## Beistrich. Ein geätztes Zeichen hat konstante Tiefe; die Stärke unterscheidet
## nur, was Figur und was Beiwerk ist.
static func glyph_weights(glyph_id: String) -> PackedFloat32Array:
	match glyph_id:
		GLYPH_AFTERGLOW:
			return PackedFloat32Array([1.0, 0.8])
		GLYPH_SPARK_FLIGHT:
			return PackedFloat32Array([1.0, 0.55])
		GLYPH_STRAY_LIGHT:
			return PackedFloat32Array([1.0, 0.8, 1.0, 1.0, 0.8, 1.0])
		GLYPH_BURN_IN:
			return PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
		GLYPH_REVERSE:
			return PackedFloat32Array([1.0, 0.85, 1.0, 0.85])
	return PackedFloat32Array()

## Der Kasten, in dem eine Figur WIRKLICH liegt (Seiten-Koordinaten, leer =
## unbekanntes Zeichen). Auf dem WÜRFEL und im Würfelnetz zählt er nicht - dort
## läuft die Figur um eine Ziffer herum, und die Mitte gehört ihr. Auf der KARTE
## gibt es keine Ziffer: dort zieht der Kasten sich auf die ganze Kachel, sonst
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
