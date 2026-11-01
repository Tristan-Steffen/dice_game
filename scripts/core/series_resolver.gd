class_name SeriesResolver
extends RefCounted
## Die SERIENSCHALTUNG: mehrere Prägenetze (StampNet) werden in der gesteckten
## Reihenfolge gegen EINEN Zielwürfel ausgewertet und ergeben EINE Projektion.
## Rein und rng-frei - dieselbe Serie liefert immer dasselbe Ergebnis, und darum
## ist die Live-Vorschau der Werkbank buchstäblich dieselbe Rechnung wie die
## Buchung.
##
## Gelesen wird strikt LINKS NACH RECHTS, je Seite und je Kanal:
##  - Zahl:     Wert-Zellen addieren; ein OPERATOR und eine FAKTOR-Zelle rechnen
##              auf der bis dahin aufgelaufenen SUMME (nie auf dem Seitenwert des
##              Würfels).
##  - Material: Schichtung - die spätere Karte übermalt die frühere; ZWEIMAL
##              dasselbe Material auf dieselbe Seite projiziert VEREDELT.
##  - Rune:     die spätere gewinnt; ein Duplikat weicht in einen freien Slot aus.
##  - Veredelung: eigene Zelle; auf illegalen Zielen verpufft sie.
##  - Pointer: KOPIERT den Serien-Stand seiner Seite (nie die Grundaugen) auf die
##             Nachbarseite, überdeckend; alle Pointer einer Karte lesen den Stand
##             VOR der Karte und schreiben NACH ihren übrigen Zellen.
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
const FIZZLE_EMPTY := "empty"        # Pointer, dessen Ursprungsseite noch nichts trägt
const FIZZLE_CROWDED := "crowded"    # Verdichtung: eine spätere Karte nahm den Platz
const FIZZLE_OPERATOR := "operator"  # Verdichtung: Operator oder Pointer lässt sich nicht pressen

## Eine Zelle in ihre KANÄLE zerlegt. Eine gewöhnliche bleibt sie selbst; eine
## VERDICHTETE fällt in ihre Teile, in Rechenreihenfolge - erst der Faktor, dann der
## Summand. Damit laufen beide durch DIESELBEN Kanalregeln, und "Summe × factor +
## value" ist keine zweite Rechnung, sondern die vorhandene.
static func _expand(cell: Dictionary) -> Array[Dictionary]:
	if StampNet.kind_of(cell) != StampNet.KIND_COMPOUND:
		return [cell] as Array[Dictionary]
	var parts: Array[Dictionary] = []
	var factor := int(cell.get("factor", 1))
	if factor > 1:
		parts.append(StampNet.factor_cell(factor))
	var value := int(cell.get("value", 0))
	if value != 0:
		parts.append(StampNet.value_cell(value))
	var material := String(cell.get("id", ""))
	if material != "":
		parts.append(StampNet.material_cell(material))
	if bool(cell.get("dope", false)):
		parts.append(StampNet.dope_cell())
	var rune := String(cell.get("rune", ""))
	if rune != "":
		parts.append(StampNet.rune_cell(rune))
	return parts

## Leere Projektion - auch der Rückgabewert jeder Serie ohne Karten.
static func blank(die: DieDefinition = null) -> Dictionary:
	var bonus: Array[int] = []
	var factors: Array[int] = []
	var materials: Array[String] = []
	var doped: Array[bool] = []
	var runes: Array = []
	for i in FACES:
		bonus.append(0)
		factors.append(1)
		materials.append("")
		doped.append(false)
		runes.append([] as Array[String])
	# factors: das Produkt der Faktor-Zellen je Seite - nur Anzeige, gerechnet ist es
	# längst im Bonus. copies: je gelungener Pointer-Kopie {card, from, to}.
	return {"bonus": bonus, "factors": factors, "materials": materials, "doped": doped,
		"runes": runes, "copies": [] as Array[Dictionary],
		"fizzled": [] as Array[Dictionary], "faces_after": faces_after(die, bonus)}

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
## Zulagen: {"propellant": int, "pointer_add": bool}.
static func resolve(nets: Array, die: DieDefinition,
		terms: Dictionary = {}) -> Dictionary:
	var out := blank(die)
	var bonus: Array[int] = out["bonus"]
	var runes: Array = out["runes"]
	var slots := die.rune_slots() if die != null else 1
	# Laufende Sicht auf die Seiten: sie mischt den Würfel mit dem, was frühere
	# Karten derselben Serie schon aufgetragen haben.
	var rune_slots_state := _rune_state(die, slots)
	var pointer_add := bool(terms.get("pointer_add", false))
	for card in nets.size():
		var net: Array = nets[card]
		var before := _snapshot(out, rune_slots_state)
		var pointers: Array[Dictionary] = []
		for face in FACES:
			for cell in _expand(StampNet.cell_at(net, face)):
				if StampNet.kind_of(cell) == StampNet.KIND_POINTER:
					pointers.append({"face": face, "to": int(cell.get("to", -1))})
				else:
					_apply_cell(out, rune_slots_state, die, slots, card, face, cell)
		for pointer in pointers:
			_copy_face(out, rune_slots_state, before, die, slots, card,
				int(pointer["face"]), int(pointer["to"]), pointer_add)
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

## Eine Zelle durch ihre Kanalregel - gemeinsam für gesteckte und kopierte Zellen.
static func _apply_cell(out: Dictionary, rune_slots_state: Array, die: DieDefinition,
		slots: int, card: int, face: int, cell: Dictionary) -> void:
	var bonus: Array[int] = out["bonus"]
	var factors: Array[int] = out["factors"]
	var materials: Array[String] = out["materials"]
	var doped: Array[bool] = out["doped"]
	var fizzled: Array[Dictionary] = out["fizzled"]
	match StampNet.kind_of(cell):
		StampNet.KIND_VALUE:
			bonus[face] += int(cell.get("value", 0))
		StampNet.KIND_FACTOR:
			bonus[face] *= int(cell.get("value", 1))
			factors[face] *= int(cell.get("value", 1))
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

## Der Stand am Kartenanfang - aus ihm lesen alle Pointer dieser Karte.
static func _snapshot(out: Dictionary, rune_slots_state: Array) -> Dictionary:
	var runes: Array = []
	for row: Array[String] in rune_slots_state:
		runes.append(row.duplicate())
	return {"bonus": (out["bonus"] as Array[int]).duplicate(),
		"factors": (out["factors"] as Array[int]).duplicate(),
		"materials": (out["materials"] as Array[String]).duplicate(),
		"doped": (out["doped"] as Array[bool]).duplicate(), "runes": runes}

## DIE KOPIE: der Serien-Stand von from_face (aus dem Schnappschuss) läuft als
## synthetische Zellen auf to_face - ein leerer Kanal überschreibt nichts.
static func _copy_face(out: Dictionary, rune_slots_state: Array, before: Dictionary,
		die: DieDefinition, slots: int, card: int, from_face: int, to_face: int,
		pointer_add: bool) -> void:
	var fizzled: Array[Dictionary] = out["fizzled"]
	if not DieDefinition.adjacent_faces(from_face).has(to_face):
		fizzled.append(_fizzle(card, from_face, FIZZLE_POINTER))
		return
	var value := int(before["bonus"][from_face])
	var material := String(before["materials"][from_face])
	var dope := bool(before["doped"][from_face])
	var runes := _rune_changes(die, before["runes"], from_face, slots)
	if value == 0 and material == "" and not dope and runes.is_empty():
		fizzled.append(_fizzle(card, from_face, FIZZLE_EMPTY))
		return
	if value != 0:
		var bonus: Array[int] = out["bonus"]
		var factors: Array[int] = out["factors"]
		if pointer_add:
			bonus[to_face] += value  # Lötkolben: die Zahl wird dazugelötet
		else:
			bonus[to_face] = value
			factors[to_face] = int(before["factors"][from_face])
	var doped: Array[bool] = out["doped"]
	if material != "":
		_apply_cell(out, rune_slots_state, die, slots, card, to_face,
			StampNet.material_cell(material))
	# Hat schon dasselbe Material veredelt, braucht die Kopie keine zweite Veredelung.
	if dope and not (material != "" and doped[to_face]):
		_apply_cell(out, rune_slots_state, die, slots, card, to_face, StampNet.dope_cell())
	for rune in runes:
		if rune != "":
			_place_rune(rune_slots_state, to_face, rune, slots)
	var copies: Array[Dictionary] = out["copies"]
	copies.append({"card": card, "from": from_face, "to": to_face})

## DIE VERDICHTUNG (Spieler-Entscheide 2026-10-26): mehrere Netze werden zu EINEM
## neuen Netz aus verdichteten Zellen. Sie ist bewusst eine ANDERE Rechnung als das
## Prägen: Faktoren und Zahlen ADDIEREN (×4 + ×4 = ×8, nicht ×16), darum ist die
## Reihenfolge hier GLEICHGÜLTIG - sie entscheidet erst wieder, wo die fertige Karte
## später im Turm steckt. Verdichten ist ein Einsammeln, die Serie eine Auswertung.
##
## Material, Rune und Veredelung passen je Seite nur EINMAL - so viel trägt
## auch ein Würfel: der letzte gewinnt, die früheren verpuffen (FIZZLE_CROWDED).
## Zweimal dasselbe Material ergibt die Veredelung, genau wie beim Prägen.
## OPERATOREN und POINTER lassen sich nicht verdichten (FIZZLE_OPERATOR): sie
## schreiben auf FREMDE Seiten - auf einer Karte mit mehreren Zellen würde die
## Seitennummer zur versteckten Rechenreihenfolge.
static func compress(nets: Array) -> Dictionary:
	var fizzled: Array[Dictionary] = []
	var factors: Array[int] = []
	var values: Array[int] = []
	var materials: Array[String] = []
	var dopes: Array[bool] = []
	var runes: Array[String] = []
	for i in FACES:
		factors.append(0)
		values.append(0)
		materials.append("")
		dopes.append(false)
		runes.append("")
	for card in nets.size():
		var net: Array = nets[card]
		for face in FACES:
			for cell in _expand(StampNet.cell_at(net, face)):
				match StampNet.kind_of(cell):
					StampNet.KIND_VALUE:
						values[face] += int(cell.get("value", 0))
					StampNet.KIND_FACTOR:
						factors[face] += int(cell.get("value", 0))
					StampNet.KIND_MATERIAL:
						var id := String(cell.get("id", ""))
						if materials[face] == id:
							dopes[face] = true  # zweimal dieselbe Farbe = Veredelung
						else:
							if materials[face] != "":
								fizzled.append(_fizzle(card, face, FIZZLE_CROWDED))
							materials[face] = id
							dopes[face] = false
					StampNet.KIND_DOPE:
						if materials[face] == "":
							fizzled.append(_fizzle(card, face, FIZZLE_NAKED))
						else:
							dopes[face] = true
					StampNet.KIND_RUNE:
						var rune := String(cell.get("id", ""))
						if runes[face] != "" and runes[face] != rune:
							fizzled.append(_fizzle(card, face, FIZZLE_CROWDED))
						runes[face] = rune
					StampNet.KIND_OPERATOR, StampNet.KIND_POINTER:
						fizzled.append(_fizzle(card, face, FIZZLE_OPERATOR))
	var out := StampNet.empty_net()
	for face in FACES:
		if factors[face] == 0 and values[face] == 0 and materials[face] == "" \
				and not dopes[face] and runes[face] == "":
			continue
		out[face] = StampNet.compound_cell(factors[face], values[face],
			materials[face], dopes[face], runes[face])
	return {"net": out, "fizzled": fizzled}

## Lässt sich diese Serie überhaupt verdichten? Ein Operator oder Pointer sperrt sie.
static func compressible(nets: Array) -> bool:
	for net in nets:
		for face in FACES:
			var kind := StampNet.kind_of(StampNet.cell_at(net, face))
			if kind == StampNet.KIND_OPERATOR or kind == StampNet.KIND_POINTER:
				return false
	return true

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
