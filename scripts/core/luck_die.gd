class_name LuckDie
extends RefCounted
## Der GLÜCKSWÜRFEL: sechs Seiten mit 1..CAP Augen. Je Schwelle des Glücks (1, 3, 6, 10 …)
## fällt ein Zusatz-Auge auf eine zufällige Seite unter dem Deckel; sinkt das Glück, geht das
## ZULETZT gewonnene wieder. Sein Wurf beim Öffnen eines Pakets IST die Zahl der Wahlen.

const FACES := 6
const BASE := 1
const CAP := 6
const MAX_EXTRA := FACES * (CAP - BASE)

var faces: Array[int] = [BASE, BASE, BASE, BASE, BASE, BASE]
## Die Seiten der Zusatz-Augen in Gewinn-Reihenfolge - der Stapel der Rücknahme.
var gained: Array[int] = []

## Glück, ab dem das k-te Zusatz-Auge liegt (Dreieckszahlen).
static func threshold(k: int) -> int:
	return k * (k + 1) / 2

## Wie viele Zusatz-Augen dieses Glück trägt: das größte k mit threshold(k) ≤ luck.
static func pips_for(luck: int) -> int:
	var k := 0
	while k < MAX_EXTRA and threshold(k + 1) <= luck:
		k += 1
	return k

## Das Glück des nächsten Auges (-1 = alle Seiten voll).
static func next_threshold(luck: int) -> int:
	var k := pips_for(luck)
	return -1 if k >= MAX_EXTRA else threshold(k + 1)

## Gleicht die Augen an das Glück an. Je Änderung {face, delta, value_after}, in der
## Reihenfolge, in der sie gebucht wurden.
func sync(luck: int, rng: RandomNumberGenerator = null) -> Array:
	var changes: Array = []
	var want := pips_for(luck)
	while gained.size() > want:
		var face: int = gained.pop_back()
		faces[face] -= 1
		changes.append({"face": face, "delta": -1, "value_after": faces[face]})
	while gained.size() < want:
		var open: Array[int] = []
		for i in FACES:
			if faces[i] < CAP:
				open.append(i)
		if open.is_empty():
			break
		var face := open[_index(open.size(), rng)]
		faces[face] += 1
		gained.append(face)
		changes.append({"face": face, "delta": 1, "value_after": faces[face]})
	return changes

## Der Wurf: eine Seite (Index), gleichverteilt.
func roll(rng: RandomNumberGenerator = null) -> int:
	return _index(FACES, rng)

func value(face: int) -> int:
	return faces[clampi(face, 0, FACES - 1)]

func total_pips() -> int:
	var sum := 0
	for v in faces:
		sum += v
	return sum

func to_dict() -> Dictionary:
	return {"faces": faces.duplicate(), "gained": gained.duplicate()}

## Liest einen gespeicherten Würfel; was nicht paßt, fällt auf den Grundwürfel zurück.
static func from_dict(data: Dictionary) -> LuckDie:
	var die := LuckDie.new()
	var stored: Array = data.get("faces", [])
	var stack: Array = data.get("gained", [])
	if stored.size() != FACES:
		return die
	var counted: Array[int] = [BASE, BASE, BASE, BASE, BASE, BASE]
	for face in stack:
		var i := int(face)
		if i < 0 or i >= FACES:
			return LuckDie.new()
		counted[i] += 1
	for i in FACES:
		if int(stored[i]) != counted[i] or counted[i] > CAP:
			return LuckDie.new()
	die.faces = counted
	for face in stack:
		die.gained.append(int(face))
	return die

static func _index(count: int, rng: RandomNumberGenerator) -> int:
	if count <= 1:
		return 0
	return rng.randi_range(0, count - 1) if rng != null else randi_range(0, count - 1)
