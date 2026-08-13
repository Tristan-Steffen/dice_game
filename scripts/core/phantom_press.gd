class_name PhantomPress
extends RefCounted
## Die Presse: jedes eingelegte Gravur-Paket wirft eine MENGE Stücke aus - 1, 3
## oder 5 zu 60 / 30 / 10 % -, und jedes Stück würfelt sein Icon einzeln aus dem
## Ikonensatz seiner Sorte. Doppelte sind kein Fehler, sondern der Normalfall.
## Reine Logik, kein Node, rng injizierbar.
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

## Die Ausbeute EINES Pakets samt ihren Gewichten - eine Quelle für Wurf und Test.
## Der Erwartungswert liegt bei zwei Stücken je Paket, der Jackpot bei fünf.
const YIELDS := [1, 3, 5]
const YIELD_WEIGHTS := [0.6, 0.3, 0.1]

## Restwert eines Stücks, das keinen legalen Platz mehr findet. Kein Stück
## verschwindet wortlos - aber bei zwei Stücken je Paket wäre mehr als eine Münze
## eine Gelddruckmaschine.
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

## Wie viele Stücke dieses Paket auswirft: der gewichtete Griff in YIELDS.
static func roll_yield(rng: RandomNumberGenerator = null) -> int:
	var roll := _roll(rng)
	var sum := 0.0
	for i in YIELDS.size():
		sum += float(YIELD_WEIGHTS[i])
		if roll < sum:
			return int(YIELDS[i])
	return int(YIELDS[YIELDS.size() - 1])

## Ein Beutestück - immer flach: Stufe 1, eine Anwendung.
static func piece(sort: String, engraving_id: String) -> Dictionary:
	return {"sort": sort, "id": engraving_id, "stufe": 1, "applications": 1}

## Die Ausbeute EINES Pakets: erst die Menge, dann je Stück sein eigenes Icon.
## Zwei gleiche Icons in einem Paket sind erlaubt - sie sind zwei Stücke.
static func payout(sort: String, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	return payout_of(sort, roll_yield(rng), rng)

## Dieselbe Ausbeute bei VORGEGEBENER Menge (Test, Füllhorn-Zugabe).
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

## Sorte der Füllhorn-Zugabe: die Mehrheits-Sorte der Pressung, bei Gleichstand
## die des ersten Pakets.
static func majority_sort(sorts: Array[String]) -> String:
	if sorts.is_empty():
		return Engraving.CATEGORY_NUMBER
	var counts := {}
	for sort in sorts:
		counts[sort] = int(counts.get(sort, 0)) + 1
	var best: String = sorts[0]
	for sort in sorts:
		if int(counts[sort]) > int(counts[best]):
			best = sort
	return best
