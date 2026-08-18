class_name PhantomPress
extends RefCounted
## Die Presse: jedes eingelegte Gravur-Paket löst EINMAL sicher aus - und würfelt
## danach weiter. Jeder Treffer löst noch einmal aus, Kette an Kette, gedeckelt vom
## MULTICAST-Limit. Die Kette ist reines Glück und für jedes Paket dieselbe; die
## GRÖSSE sagt nur, wie viele Stücke EINE Auslösung auswirft. Jedes
## Stück würfelt sein Icon EINZELN aus dem Ikonensatz seiner Sorte; Doppelte sind
## kein Fehler, sondern der Normalfall. Reine Logik, kein Node, rng injizierbar.
##
## Es gibt keine Güte und keine Nachbarschaft mehr: ein Stück ist ein Stück, flach
## auf Stufe 1 mit einer Anwendung. Die MENGE ist der ganze Ertrag - höhere Stufen
## sind kein Presseneffekt mehr.

## Die sechs Seiten je Sorte, in FESTER Reihenfolge - der Seitenindex ist das
## Icon. Sorte = Engraving-Kategorie; die ids sind Gravur-ids, auch bei den
## Runen (Engraving.RUNE_PREFIX), damit jedes Beutestück dieselbe Sprache spricht.
const ICONS := {
	Engraving.CATEGORY_NUMBER: Engraving.NUMBER_IDS,
	Engraving.CATEGORY_MATERIAL: [DieMaterial.RUBY, DieMaterial.AMBER, DieMaterial.GOLD,
		DieMaterial.BONE, DieMaterial.GLASS, DieMaterial.COPPER],
	Engraving.CATEGORY_DICE: [Engraving.RUNE_PREFIX + Rune.AFTERGLOW,
		Engraving.RUNE_PREFIX + Rune.STRAY_LIGHT, Engraving.RUNE_PREFIX + Rune.BURN_IN,
		Engraving.RUNE_PREFIX + Rune.SPARK_FLIGHT, Engraving.RUNE_PREFIX + Rune.CAST,
		Engraving.RUNE_PREFIX + Rune.REVERSE],
}

## Sechs Leser, sechs Plätze in der Konsole: der Batch endet strukturell hier.
const BATCH_CAP := 6
const FACE_COUNT := 6

## DER MULTICAST. Ein Paket löst immer einmal aus; danach entscheidet je ein Wurf,
## ob es noch einmal auslöst. Eine Decke muss sein - ohne sie hinge die Beute an
## einer unendlichen Kette. Die Chance ist für jedes Paket dieselbe, die
## Kettenlänge also reines Glück; die GRÖSSE des Pakets bleibt außen vor.
##
## Chance und Decke sind KEINE festen Zahlen mehr: sie wachsen mit dem Ausbau des
## Casinos, und Verträge wie Nebenwetten verschieben sie. Hier stehen nur die
## Daten und die reine Rechnung - die eine Auflösung sind GameRun.multicast_chance
## und GameRun.multicast_cap, und die reicht jeder Aufrufer als Parameter herein.

## Die Meilensteine der Lizenz - dieselben Stufen wie die Kondensator-Reihen
## (1 / 3 / 5 / 7 / 10). Zwischen zwei Sprossen bewegt sich nichts.
const MULTICAST_LADDER := [
	{"hub": 1, "chance": 0.5, "cap": 3},
	{"hub": 3, "chance": 0.56, "cap": 4},
	{"hub": 5, "chance": 0.62, "cap": 5},
	{"hub": 7, "chance": 0.69, "cap": 6},
	{"hub": 10, "chance": 0.75, "cap": 7},
]

## Die unterste Sprosse als Vorgabe jeder Rechnung ohne Lauf (Vorschau, Test).
const MULTICAST_CHANCE := 0.5
const MULTICAST_CAP := 3

## Schranken der ZUSAMMENGESETZTEN Chance (GameRun klemmt dort hinein). Ein
## Multicast, der immer zündet, wäre keine Chance mehr - dieselbe Begründung wie
## bei der Pointer-Decke.
const MULTICAST_CHANCE_MAX := 0.9
const MULTICAST_CHANCE_MIN := 0.05

## Der Einmal-Schub, den die Nebenwette Kettenreaktion auf EINE Pressung legt. Er
## steht hier bei den übrigen Multicast-Zahlen, damit Wettknopf und GameRun-Abfrage
## dieselbe Quelle lesen (und core/ sich nicht im Kreis referenziert).
const BOOST_CHANCE := 0.25
const BOOST_CAP := 2

## Was EINE Auslösung auswirft - das ist die ganze Bedeutung der Paketgröße
## (Pack.TIER_*, Index = Größe). Die Größe multipliziert also den Ertrag je Schlag,
## nie die Länge der Kette.
## Erwartete Stücke = Grundwurf × erwartete Auslösungen; das Verhältnis 1 : 3 : 5
## steht damit fest, wie weit die Kette auch reicht.
const BASE_PIECES := [1, 3, 5]

## Restwert eines Stücks, das keinen legalen Platz mehr findet. Kein Stück
## verschwindet wortlos - aber bei zwei bis zehn Stücken je Paket wäre mehr als
## eine Münze eine Gelddruckmaschine.
const FIZZLE_MONEY := 1

## Die sechs Icons einer Sorte ([] bei unbekannter Sorte).
static func icons_for(sort: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(ICONS.get(sort, []))
	return out

## Gravur-id, die auf Seite face einer Sorte liegt ("" außerhalb).
static func icon_of(sort: String, face: int) -> String:
	var icons := icons_for(sort)
	if face < 0 or face >= icons.size():
		return ""
	return icons[face]

## Seitenindex eines Icons in seiner Sorte (-1 = liegt auf keinem Ikonensatz -
## so wie der Pointer, den es nur als Fixinhalt gibt).
static func face_of(sort: String, engraving_id: String) -> int:
	return icons_for(sort).find(engraving_id)

## Sorte, auf deren Ikonensatz diese Gravur liegt ("" = auf keinem).
static func sort_of(engraving_id: String) -> String:
	for sort: String in ICONS:
		if icons_for(sort).has(engraving_id):
			return sort
	return ""

## Ziehgewichte eines Ikonensatzes: ein Icon fällt nach der SELTENHEIT seiner
## Gravur, nicht flach - häufige Verben liegen ständig in der Ablage, der Meißel
## fast nie. Engraving.RARITY_WEIGHTS ist die eine Quelle.
static func weights_for(sort: String) -> Array[float]:
	var out: Array[float] = []
	for id in icons_for(sort):
		out.append(Engraving.weight_of(id))
	return out

## Gewichteter Griff in einen Ikonensatz (-1 = der Satz ist leer).
static func _pick_face(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight in weights:
		total += weight
	if total <= 0.0:
		return -1
	var roll := _roll(rng) * total
	var sum := 0.0
	for i in weights.size():
		sum += weights[i]
		if roll < sum:
			return i
	return weights.size() - 1

static func _roll(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()

## Stücke je Auslösung einer Paketgröße (außerhalb der Tabelle: die Norm). bonus
## ist der Zuschlag der eingelegten Katalysatoren (Doppelmatrize) - er kommt von
## außen herein, die Presse selbst bleibt rein.
static func base_for(tier: int, bonus: int = 0) -> int:
	var base := int(BASE_PIECES[0])
	if tier >= 0 and tier < BASE_PIECES.size():
		base = int(BASE_PIECES[tier])
	return maxi(base + bonus, 0)

## Die Sprosse der Leiter, auf der diese Lizenzstufe steht.
static func _rung(hub_level: int) -> Dictionary:
	var rung: Dictionary = MULTICAST_LADDER[0]
	for step: Dictionary in MULTICAST_LADDER:
		if hub_level >= int(step["hub"]):
			rung = step
	return rung

## Grund-Chance bzw. Grund-Decke der Lizenzstufe, vor Klauseln und Wett-Schub.
static func base_chance(hub_level: int) -> float:
	return float(_rung(hub_level)["chance"])

static func base_cap(hub_level: int) -> int:
	return int(_rung(hub_level)["cap"])

## Höchste Decke der Leiter - die Schranke jeder Anzeige und jedes Tests, der
## einen schlimmsten Fall braucht (Klauseln legen darüber hinaus noch nach).
static func max_cap() -> int:
	return int(MULTICAST_LADDER[MULTICAST_LADDER.size() - 1]["cap"])

## Erwartete Auslösungen - die geometrische Reihe bis zur Decke, für jede Größe
## dieselbe. Sie steht hier, damit Preistabelle und Test dieselbe Zahl lesen.
static func expected_triggers(chance := MULTICAST_CHANCE, cap := MULTICAST_CAP) -> float:
	var sum := 0.0
	var run := 1.0
	for i in maxi(cap, 1):
		sum += run
		run *= chance
	return sum

## Erwartete Stücke einer Größe: ihr Grundwurf mal der Kette. Die Kette ist für
## alle Größen dieselbe, das Verhältnis 1 : 3 : 5 also chancen-unabhängig.
static func expected_pieces(tier: int, chance := MULTICAST_CHANCE,
		cap := MULTICAST_CAP) -> float:
	return float(base_for(tier)) * expected_triggers(chance, cap)

## Wie oft ein Paket auslöst: eins ist sicher, jedes weitere kostet einen Treffer -
## bis zum ersten Fehlwurf oder bis zur Decke. Ohne Ansehen der Größe.
static func roll_multicast(rng: RandomNumberGenerator = null,
		chance := MULTICAST_CHANCE, cap := MULTICAST_CAP) -> int:
	var triggers := 1
	while triggers < maxi(cap, 1) and _roll(rng) < chance:
		triggers += 1
	return triggers

## Ein Beutestück - immer flach: Stufe 1, eine Anwendung.
static func piece(sort: String, engraving_id: String) -> Dictionary:
	return {"sort": sort, "id": engraving_id, "stufe": 1, "applications": 1}

## Die Ausbeute EINES Pakets, nach AUSLÖSUNGEN gegliedert: erst die Kette, dann je
## Auslösung so viele Stücke, wie die Größe hergibt - jedes mit eigenem Icon-Wurf.
## Die Zeremonie fliegt eine Gruppe nach der anderen, darum ist die Gliederung das
## Ergebnis und die flache Liste nur ihre Lesart.
static func payout_groups(sort: String, tier: int = 0,
		rng: RandomNumberGenerator = null, chance := MULTICAST_CHANCE,
		cap := MULTICAST_CAP, base_bonus: int = 0) -> Array:
	var base := base_for(tier, base_bonus)
	var groups: Array = []
	for i in roll_multicast(rng, chance, cap):
		var group := payout_of(sort, base, rng)
		if not group.is_empty():  # unbekannte Sorte: gar keine Auslösung, kein Leerschlag
			groups.append(group)
	return groups

## Dieselbe Ausbeute flach - zwei gleiche Icons in einem Paket sind erlaubt, sie
## sind zwei Stücke.
static func payout(sort: String, tier: int = 0,
		rng: RandomNumberGenerator = null, chance := MULTICAST_CHANCE,
		cap := MULTICAST_CAP, base_bonus: int = 0) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	for group in payout_groups(sort, tier, rng, chance, cap, base_bonus):
		pieces.append_array(group)
	return pieces

## Dieselbe Ausbeute bei VORGEGEBENER Menge (Fixinhalt, Test).
static func payout_of(sort: String, count: int,
		rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	var weights := weights_for(sort)  # einmal je Paket, nicht je Stück
	for i in maxi(count, 0):
		var id := icon_of(sort, _pick_face(weights, rng))
		if id == "":
			continue
		pieces.append(piece(sort, id))
	return pieces

