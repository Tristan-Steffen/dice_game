class_name ComboPartEffects
## Wirkung der Module in den Steckplätzen der Kombinations-Chips - rein und
## statisch, über die ComboPart-id verteilt. combo_parts ist Key -> Array
## (ComboPart oder null je Steckplatz); stillgelegte Teile kommen als null an.

## Spalten des Kombinations-Clusters - Spiegel von TableScreen.CLUSTER_COLUMNS
## (core/ greift nicht in table/), ein Test hält beide gleich.
const CLUSTER_COLUMNS := 3

const RESISTOR_POINTS := 15
const CAPACITOR_MULT := 3
const COIL_POINTS := 8
const COIL_MULT := 1
const COUNTER_BASE_MULT := 1
const SOLDER_JOINT_MULT := 1
const SERIES_RESISTOR_POINTS := 4
const THERMISTOR_MULT_PER_CHARGE := 2
const AMPLIFIER_TUBE_CRIT := 1.5
const HIGH_VOLTAGE_TUBE_CRIT := 2.0
const COIN_VALIDATOR_MONEY := 2
const RELAY_RETRIGGERS := 1
const OUTPUT_STAGE_RETRIGGERS := 1

## Die Steckplätze einer Kombination ([] = keine Belegung).
static func chip(combo_parts: Dictionary, key: String) -> Array:
	var sockets = combo_parts.get(key, [])
	return sockets if sockets is Array else []

## Gesteckte Teile eines Chips (Acetylen, Schneidbrenner, Hitzewarnung).
static func part_count(sockets: Array) -> int:
	var count := 0
	for part in sockets:
		if part != null:
			count += 1
	return count

## Der Chip LINKS im Cluster: dieselbe Reihe, eine Spalte davor (Reihenfolge =
## HAND_PRIORITY in CLUSTER_COLUMNS Spalten). Die erste Spalte hat keinen.
static func left_of(key: String) -> String:
	var index := DiceScoring.HAND_PRIORITY.find(key)
	if index <= 0 or index % CLUSTER_COLUMNS == 0:
		return ""
	return DiceScoring.HAND_PRIORITY[index - 1]

## Punkte (x) und Mult (y) eines Kombi-Teils (Kopplung ausgenommen).
static func combo_values(part: ComboPart) -> Vector2i:
	match part.id:
		ComboPart.RESISTOR:
			return Vector2i(RESISTOR_POINTS, 0)
		ComboPart.CAPACITOR:
			return Vector2i(0, CAPACITOR_MULT)
		ComboPart.COIL:
			return Vector2i(COIL_POINTS, COIL_MULT)
		ComboPart.COUNTER:
			return Vector2i(0, COUNTER_BASE_MULT + maxi(0, part.counter))
	return Vector2i.ZERO

## Das stärkste Kombi-Teil eines Chips: mehr Mult zuerst, dann mehr Punkte, dann
## der frühere Steckplatz. Kopplungen sind ausgenommen - keine Ketten.
static func strongest_combo_part(sockets: Array) -> ComboPart:
	var best: ComboPart = null
	var best_values := Vector2i.ZERO
	for part in sockets:
		if part == null or part.phase != ComboPart.PHASE_COMBO or part.id == ComboPart.COUPLING:
			continue
		var values := combo_values(part)
		if best == null or values.y > best_values.y \
				or (values.y == best_values.y and values.x > best_values.x):
			best = part
			best_values = values
	return best

## Kombi-Schritte der Kombination in Steckplatz-Reihenfolge, je Teil einer:
## {slot, id, points, mult, copied}. Teile ohne Beitrag fehlen.
static func combo_steps(combo_parts: Dictionary, key: String) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var sockets := chip(combo_parts, key)
	for slot in sockets.size():
		var part: ComboPart = sockets[slot]
		if part == null or part.phase != ComboPart.PHASE_COMBO:
			continue
		var source := part
		var copied := ""
		if part.id == ComboPart.COUPLING:
			source = strongest_combo_part(chip(combo_parts, left_of(key)))
			if source == null:
				continue
			copied = source.id
		var values := combo_values(source)
		if values == Vector2i.ZERO:
			continue
		steps.append({"slot": slot, "id": part.id, "points": values.x, "mult": values.y, "copied": copied})
	return steps

## Was der Chip sicher bringt: Grundwert plus die festen Kombi-Teile (Punkte, Mult).
static func display_values(combo_parts: Dictionary, key: String) -> Vector2i:
	var points := DiceScoring.points_for(key)
	var mult := DiceScoring.mult_for(key)
	for step in combo_steps(combo_parts, key):
		points += int(step["points"])
		mult += int(step["mult"])
	return Vector2i(points, mult)

## Kopf (x) und Schluss (y) der KOMBINATION in der Zählreihe (-1 = keine).
static func combo_ends(order: Array[int], combination: Array[int]) -> Vector2i:
	var walk: Array[int] = []
	for i in order:
		if combination.has(i) and not walk.has(i):
			walk.append(i)
	for i in combination:
		if not walk.has(i):
			walk.append(i)
	if walk.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(walk[0], walk[walk.size() - 1])

## Würfel-Achse: Relais auf dem Kopf, Endstufe auf dem Schluss der Kombination.
## Ein Einzelwürfel ist beides und bekommt beides.
static func die_retriggers(sockets: Array, i: int, head: int, tail: int) -> int:
	var extra := 0
	for part in sockets:
		if part == null:
			continue
		if part.id == ComboPart.RELAY and i == head and head >= 0:
			extra += RELAY_RETRIGGERS
		elif part.id == ComboPart.OUTPUT_STAGE and i == tail and tail >= 0:
			extra += OUTPUT_STAGE_RETRIGGERS
	return extra

## Punkte je Zündung eines Kombinationswürfels (Vorwiderstand).
static func firing_base(sockets: Array, in_combination: bool) -> int:
	if not in_combination:
		return 0
	var base := 0
	for part in sockets:
		if part != null and part.id == ComboPart.SERIES_RESISTOR:
			base += SERIES_RESISTOR_POINTS
	return base

## Mult je Zündung eines Kombinationswürfels (Lötpunkt, Thermistor mit seinem
## LEBENDEN Ladungsstand).
static func firing_mult(sockets: Array, in_combination: bool, charge: int) -> int:
	if not in_combination:
		return 0
	var mult := 0
	for part in sockets:
		if part == null:
			continue
		if part.id == ComboPart.SOLDER_JOINT:
			mult += SOLDER_JOINT_MULT
		elif part.id == ComboPart.THERMISTOR:
			mult += THERMISTOR_MULT_PER_CHARGE * maxi(0, charge)
	return mult

## Steckplätze, die an dieser Zündung etwas beitragen - der Blitz am Chip.
static func firing_slots(sockets: Array, in_combination: bool, charge: int) -> Array[int]:
	var slots: Array[int] = []
	if not in_combination:
		return slots
	for slot in sockets.size():
		var part: ComboPart = sockets[slot]
		if part == null:
			continue
		if part.id == ComboPart.SERIES_RESISTOR or part.id == ComboPart.SOLDER_JOINT \
				or (part.id == ComboPart.THERMISTOR and charge > 0):
			slots.append(slot)
	return slots

## Krit-Schritte nach allen Würfeln, je Teil einer: {slot, id, crit_x}.
static func crit_steps(sockets: Array) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for slot in sockets.size():
		var part: ComboPart = sockets[slot]
		if part == null:
			continue
		match part.id:
			ComboPart.AMPLIFIER_TUBE:
				steps.append({"slot": slot, "id": part.id, "crit_x": AMPLIFIER_TUBE_CRIT})
			ComboPart.HIGH_VOLTAGE_TUBE:
				steps.append({"slot": slot, "id": part.id, "crit_x": HIGH_VOLTAGE_TUBE_CRIT})
	return steps

## Geld je Wertung der Kombination (Münzprüfer).
static func scoring_money(sockets: Array) -> int:
	var money := 0
	for part in sockets:
		if part != null and part.id == ComboPart.COIN_VALIDATOR:
			money += COIN_VALIDATOR_MONEY
	return money

## Zusätzliche Steckplätze eines Chips: jede Erweiterungsplatine gibt zwei.
static func extra_sockets(sockets: Array) -> int:
	var extra := 0
	for part in sockets:
		if part != null and part.id == ComboPart.EXPANSION_BOARD:
			extra += 2
	return extra

## Wer einen Platz TRÄGT: CHIP_SOCKET (-1) für die drei Grundplätze, sonst der Platz
## der Platine, auf der er sitzt; UNREACHABLE (-2), wenn ihn keine erreichbare
## Platine trägt. Die Zusatzpaare gehen der Reihe nach an die Platinen, in der
## Reihenfolge, in der man sie vom Chip aus erreicht (kleinster Platz zuerst).
const CHIP_SOCKET := -1
const UNREACHABLE := -2

static func socket_parents(sockets: Array, base: int) -> Array[int]:
	var parents: Array[int] = []
	for slot in sockets.size():
		parents.append(CHIP_SOCKET if slot < base else UNREACHABLE)
	var open: Array[int] = []
	for slot in mini(base, sockets.size()):
		open.append(slot)
	var next := base
	while not open.is_empty():
		open.sort()
		var slot: int = open.pop_front()
		var part = sockets[slot]
		if part == null or part.id != ComboPart.EXPANSION_BOARD:
			continue
		for child in [next, next + 1]:
			if child < sockets.size():
				parents[child] = slot
				open.append(child)
		next += 2
	return parents

## Trägt der Chip irgendein Teil, das in der Würfelphase wirkt?
static func has_die_parts(sockets: Array) -> bool:
	for part in sockets:
		if part != null and part.phase == ComboPart.PHASE_DIE:
			return true
	return false
