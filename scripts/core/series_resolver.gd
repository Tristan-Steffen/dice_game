class_name SeriesResolver
extends RefCounted
## Die SERIENSCHALTUNG: mehrere Prägenetze (StampNet) werden in der gesteckten
## Reihenfolge gegen EINEN Zielwürfel ausgewertet und ergeben EINE Projektion.
## Rein und rng-frei - dieselbe Serie liefert immer dasselbe Ergebnis, und darum
## ist die Live-Vorschau der Werkbank buchstäblich dieselbe Rechnung wie die
## Buchung.
##
## Gelesen wird strikt LINKS NACH RECHTS, je Seite und je Kanal:
##  - Zahl:     Wert-Zellen addieren; ein OPERATOR rechnet auf der bis dahin
##              aufgelaufenen SUMME (nie auf dem Seitenwert des Würfels).
##  - Material: Schichtung - die spätere Karte übermalt die frühere; ZWEIMAL
##              dasselbe Material auf dieselbe Seite projiziert VEREDELT.
##  - Rune:     die spätere gewinnt; ein Duplikat weicht in einen freien Slot aus.
##  - Veredelung/Pointer: eigene Zellen; auf illegalen Zielen verpuffen sie.
## Operatoren wirken NUR im Zahl-Kanal.

const FACES := 6

## Der Einmal-Schub der Nebenwette Kettenreaktion auf die NÄCHSTE Serie. Er steht
## hier bei der Serien-Rechnung, damit Wettknopf und GameRun-Abfrage dieselbe
## Quelle lesen (und core/ sich nicht im Kreis referenziert).
const BOOST_SLOTS := 1

## Gründe, aus denen eine Zelle verpufft - die Vorschau nennt sie beim Namen.
const FIZZLE_NAKED := "naked"        # Veredelung auf einer Seite ohne Material
const FIZZLE_DOPED := "doped"        # Veredelung auf einer schon veredelten Seite
const FIZZLE_BURNED := "burned"      # Einbrand sperrt das Übermalen
const FIZZLE_POINTER := "pointer"    # Pointer auf keine Nachbarseite

## Leere Projektion - auch der Rückgabewert jeder Serie ohne Karten.
static func blank(die: DieDefinition = null) -> Dictionary:
	var bonus: Array[int] = []
	var materials: Array[String] = []
	var doped: Array[bool] = []
	var pointers: Array[int] = []
	var runes: Array = []
	for i in FACES:
		bonus.append(0)
		materials.append("")
		doped.append(false)
		pointers.append(-1)
		runes.append([] as Array[String])
	return {"bonus": bonus, "materials": materials, "doped": doped,
		"runes": runes, "pointers": pointers, "fizzled": [] as Array[Dictionary],
		"faces_after": faces_after(die, bonus)}

## Der Zielzustand der Augenzahlen - die Vorschau zeigt ihn, die Buchung schreibt
## ihn. Ohne Würfel bleibt der Bonus für sich stehen.
static func faces_after(die: DieDefinition, bonus: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for i in FACES:
		var base := 0
		if die != null and i < die.faces.size():
			base = int(die.faces[i])
		out.append(maxi(base + bonus[i], EtchingEffects.MIN_FACE_VALUE))
	return out

## DIE AUSWERTUNG. nets ist die Serie in Steckreihenfolge (je Karte ihr
## StampNet-Array; ein Katalysator gibt ein leeres Netz ab), terms sind die
## Katalysator-Zulagen: {"propellant": int}.
static func resolve(nets: Array, die: DieDefinition,
		terms: Dictionary = {}) -> Dictionary:
	var out := blank(die)
	var bonus: Array[int] = out["bonus"]
	var materials: Array[String] = out["materials"]
	var doped: Array[bool] = out["doped"]
	var pointers: Array[int] = out["pointers"]
	var runes: Array = out["runes"]
	var fizzled: Array[Dictionary] = out["fizzled"]
	var slots := die.rune_slots() if die != null else 1
	# Laufende Sicht auf die Seiten: sie mischt den Würfel mit dem, was frühere
	# Karten derselben Serie schon aufgetragen haben.
	var rune_slots_state := _rune_state(die, slots)
	for card in nets.size():
		var net: Array = nets[card]
		for face in FACES:
			var cell := StampNet.cell_at(net, face)
			match StampNet.kind_of(cell):
				StampNet.KIND_VALUE:
					bonus[face] += int(cell.get("value", 0))
				StampNet.KIND_OPERATOR:
					_apply_operator(bonus, face, String(cell.get("id", "")))
				StampNet.KIND_MATERIAL:
					var id := String(cell.get("id", ""))
					if _burned(die, face) and _material_on(die, materials, face) != "":
						fizzled.append(_fizzle(card, face, FIZZLE_BURNED))
					elif _material_on(die, materials, face) == id:
						doped[face] = true  # zweimal dieselbe Farbe = Veredelung
						materials[face] = id
					else:
						materials[face] = id
						doped[face] = false
				StampNet.KIND_RUNE:
					_place_rune(rune_slots_state, face, String(cell.get("id", "")), slots)
				StampNet.KIND_DOPE:
					if _material_on(die, materials, face) == "":
						fizzled.append(_fizzle(card, face, FIZZLE_NAKED))
					elif _doped_on(die, materials, doped, face):
						fizzled.append(_fizzle(card, face, FIZZLE_DOPED))
					else:
						doped[face] = true
				StampNet.KIND_POINTER:
					var target := int(cell.get("to", -1))
					if die != null and not die.can_point(face, target):
						fizzled.append(_fizzle(card, face, FIZZLE_POINTER))
					else:
						pointers[face] = target
	# Treibladung: EIN Zuschlag ganz am Ende, auf jede gefüllte Zahl-Zelle des
	# fertigen Summen-Netzes - nie zwischen den Karten, sonst verdoppelte ihn ein
	# später gesteckter Verdoppler.
	var propellant := int(terms.get("propellant", 0))
	if propellant > 0:
		for face in FACES:
			if bonus[face] != 0:
				bonus[face] += propellant
	for face in FACES:
		runes[face] = _rune_changes(die, rune_slots_state, face, slots)
	out["faces_after"] = faces_after(die, bonus)
	return out

## Die Zweitprojektion der Doppelmatrize: NUR der Zahl-Kanal, halbiert und
## abgerundet. Material, Rune, Veredelung und Pointer bleiben beim ersten Würfel.
static func secondary(projection: Dictionary, die: DieDefinition) -> Dictionary:
	var out := blank(die)
	var bonus: Array[int] = out["bonus"]
	var source: Array[int] = projection.get("bonus", [])
	for face in FACES:
		if face < source.size():
			bonus[face] = int(floor(float(source[face]) / 2.0))
	out["faces_after"] = faces_after(die, bonus)
	return out

## Trägt die Projektion überhaupt etwas ein?
static func is_empty(projection: Dictionary) -> bool:
	for face in FACES:
		if int(projection["bonus"][face]) != 0:
			return false
		if String(projection["materials"][face]) != "":
			return false
		if bool(projection["doped"][face]):
			return false
		if not Array(projection["runes"][face]).is_empty():
			return false
		if int(projection["pointers"][face]) >= 0:
			return false
	return true

## --- Die Operatoren ------------------------------------------------------------

static func _apply_operator(bonus: Array[int], face: int, op_id: String) -> void:
	match op_id:
		StampNet.OP_DOUBLER:
			bonus[face] *= 2
		StampNet.OP_MIRROR:
			bonus[DieDefinition.opposite_face(face)] = bonus[face]
		StampNet.OP_COLLECTOR:
			var sum := 0
			for i in FACES:
				sum += bonus[i]
				bonus[i] = 0
			bonus[face] = sum

## --- Die Kanäle ----------------------------------------------------------------

## Material, das auf dieser Seite liegt, WENN die Serie bis hierhin gelaufen ist.
static func _material_on(die: DieDefinition, materials: Array[String], face: int) -> String:
	if materials[face] != "":
		return materials[face]
	if die != null and face < die.materials.size():
		return String(die.materials[face])
	return ""

static func _doped_on(die: DieDefinition, materials: Array[String],
		doped: Array[bool], face: int) -> bool:
	if doped[face]:
		return true
	if materials[face] != "":
		return false  # frische Farbe liegt immer unveredelt
	return die != null and die.material_level(face) >= DieMaterial.MAX_LEVEL

static func _burned(die: DieDefinition, face: int) -> bool:
	return die != null and RuneEffects.protects_face_value(die.runes_on(face))

## Ausgangsbelegung der Runen-Plätze je Seite.
static func _rune_state(die: DieDefinition, slots: int) -> Array:
	var state: Array = []
	for face in FACES:
		var row: Array[String] = []
		for slot in slots:
			var occupied := ""
			if die != null:
				match slot:
					1:
						occupied = String(die.second_runes[face])
					2:
						occupied = String(die.third_runes[face])
					_:
						occupied = String(die.runes[face])
			row.append(occupied)
		state.append(row)
	return state

## Die spätere Rune gewinnt den ersten Platz; ein DUPLIKAT weicht in den nächsten
## freien aus (Vakuum) und ersetzt sonst gar nichts.
static func _place_rune(state: Array, face: int, rune_id: String, slots: int) -> void:
	var row: Array[String] = state[face]
	if row[0] == rune_id:
		for slot in range(1, slots):
			if row[slot] == "":
				row[slot] = rune_id
				return
		return
	row[0] = rune_id

## Was die Serie an dieser Seite WIRKLICH verändert - Plätze, die schon so
## belegt waren, meldet die Projektion nicht.
static func _rune_changes(die: DieDefinition, state: Array, face: int,
		slots: int) -> Array[String]:
	var before: Array[String] = _rune_state(die, slots)[face]
	var after: Array[String] = state[face]
	var changes: Array[String] = []
	for slot in slots:
		changes.append(after[slot] if after[slot] != before[slot] else "")
	while not changes.is_empty() and changes[changes.size() - 1] == "":
		changes.remove_at(changes.size() - 1)
	return changes

static func _fizzle(card: int, face: int, reason: String) -> Dictionary:
	return {"card": card, "face": face, "reason": reason}
