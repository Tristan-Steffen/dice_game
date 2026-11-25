class_name ComboPartEffects
## Wirkung der Module in den Steckplätzen der Kombinations-Chips - rein und
## statisch, über die ComboPart-id verteilt. combo_parts ist Key -> Array
## (ComboPart oder null je Steckplatz); stillgelegte Teile kommen als null an.

## Spalten des Kombinations-Clusters - Spiegel von TableScreen.CLUSTER_COLUMNS
## (core/ greift nicht in table/), ein Test hält beide gleich.
const CLUSTER_COLUMNS := 3

const RESISTOR_POINTS := 20
const CAPACITOR_MULT := 3
const COIL_POINTS := 8
const COIL_MULT := 2
const COUNTER_BASE_MULT := 1
const SOLDER_JOINT_MULT := 1
const SERIES_RESISTOR_POINTS := 4
const AMPLIFIER_TUBE_CRIT := 1.5
const HIGH_VOLTAGE_TUBE_CRIT := 3.0
const COIN_VALIDATOR_MONEY := 2
const RELAY_RETRIGGERS := 1
const OUTPUT_STAGE_RETRIGGERS := 1
const PARALLEL_RETRIGGERS := 1
const SERIES_TERMINAL_POINTS := 5
const SERIES_TERMINAL_MULT := 2
const STARTER_MULT := 6
## Zehntel, sonst summieren sich Rundungsfehler in die Anzeige.
const RESONATOR_START_TENTHS := 11
const POWER_PICKUP_ENERGY := 1
## Was Brücke und Parallelschaltung je Zündung aus dem Speicher ziehen.
const CIRCUIT_ENERGY := 1
const AFTERBURNER_CRIT := 2.0

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

## Der Chip RECHTS im Cluster: dieselbe Reihe, eine Spalte weiter.
static func right_of(key: String) -> String:
	var index := DiceScoring.HAND_PRIORITY.find(key)
	var next := index + 1
	if index < 0 or next >= DiceScoring.HAND_PRIORITY.size() or next % CLUSTER_COLUMNS == 0:
		return ""
	return DiceScoring.HAND_PRIORITY[next]

## Der Chip DARUNTER, wie er im Bild steht: die unvollständige letzte Reihe liegt mittig.
static func below_of(key: String) -> String:
	var index := DiceScoring.HAND_PRIORITY.find(key)
	if index < 0:
		return ""
	var row := index / CLUSTER_COLUMNS
	for other in range(index + 1, DiceScoring.HAND_PRIORITY.size()):
		if other / CLUSTER_COLUMNS == row + 1 and _cluster_column(other) == _cluster_column(index):
			return DiceScoring.HAND_PRIORITY[other]
	return ""

static func _cluster_column(index: int) -> int:
	var count := DiceScoring.HAND_PRIORITY.size()
	var full := count / CLUSTER_COLUMNS * CLUSTER_COLUMNS
	if index < full:
		return index % CLUSTER_COLUMNS
	return (CLUSTER_COLUMNS - (count - full)) / 2 + index - full

## Die Kombinationen, die eine Wertung zündet: sie selbst, dann was ihre Brücken
## erreichen. Jede höchstens einmal; eine gedrosselte Kombination leitet nicht.
## Jede Brücke, die zündet, kostet CIRCUIT_ENERGY; ohne Rest bleibt sie dunkel
## (energy < 0 = unbegrenzt, nur für reine Rechnungen ohne Lauf).
static func chain_keys(combo_parts: Dictionary, key: String, throttled: Array = [], energy: int = -1) -> Array[String]:
	var keys: Array[String] = [key]
	var budget := energy
	var next := 0
	while next < keys.size():
		for part in chip(combo_parts, keys[next]):
			if part == null:
				continue
			var target := ""
			if part.id == ComboPart.CROSS_BRIDGE:
				target = right_of(keys[next])
			elif part.id == ComboPart.DOWN_BRIDGE:
				target = below_of(keys[next])
			if target == "" or keys.has(target) or throttled.has(target):
				continue
			if budget >= 0:
				if budget < CIRCUIT_ENERGY:
					continue
				budget -= CIRCUIT_ENERGY
			keys.append(target)
		next += 1
	return keys

## Kopplung: jedes andere Modul ihres Chips zählt je Kopplung einmal mehr.
static func weight(sockets: Array, part: ComboPart) -> int:
	if part == null:
		return 1
	if part.id == ComboPart.COUPLING:
		return 1 + part.weight_bonus
	return 1 + count_of(sockets, ComboPart.COUPLING) + part.weight_bonus

## Die Wirk-Liste eines Chips: jedes Modul so oft, wie es zählt (Kopplung).
static func weighted(sockets: Array) -> Array:
	var out: Array = []
	for part in sockets:
		for _n in weight(sockets, part):
			out.append(part)
	return out

## Alle Steckplätze einer Kette hintereinander, der gewertete Chip zuerst, jedes
## Modul so oft, wie es zählt. Was die Brücken übrig ließen, speist die
## Parallelschaltungen der Reihe nach; eine ohne Energie fällt als null aus.
static func merged_chip(combo_parts: Dictionary, keys: Array[String], energy: int = -1) -> Array:
	var budget := energy - bridge_cost(keys) if energy >= 0 else -1
	var merged: Array = []
	for key in keys:
		for part in weighted(chip(combo_parts, key)):
			if part != null and part.id == ComboPart.PARALLEL_CIRCUIT and budget >= 0:
				if budget < CIRCUIT_ENERGY:
					merged.append(null)
					continue
				budget -= CIRCUIT_ENERGY
			merged.append(part)
	return merged

## Parallel zu merged_chip: wem gehört welcher Platz ({key, slot}).
static func merged_sockets(combo_parts: Dictionary, keys: Array[String]) -> Array[Dictionary]:
	var sockets: Array[Dictionary] = []
	for key in keys:
		var own := chip(combo_parts, key)
		for slot in own.size():
			for _n in weight(own, own[slot]):
				sockets.append({"key": key, "slot": slot})
	return sockets

## Energie, die die Brücken einer Kette gezogen haben.
static func bridge_cost(keys: Array[String]) -> int:
	return CIRCUIT_ENERGY * maxi(0, keys.size() - 1)

## Energie, die eine Kette samt ihren gespeisten Parallelschaltungen zieht.
static func circuit_cost(merged: Array, keys: Array[String]) -> int:
	return bridge_cost(keys) + CIRCUIT_ENERGY * count_of(merged, ComboPart.PARALLEL_CIRCUIT)

## Gesteckte Module der ganzen Kette, jedes einmal (Acetylen, Schneidbrenner).
static func chain_part_count(combo_parts: Dictionary, keys: Array[String]) -> int:
	var count := 0
	for key in keys:
		count += part_count(chip(combo_parts, key))
	return count

## Kombinationen, deren Kette einen Nebenschluss trägt.
static func shunted_keys(combo_parts: Dictionary, throttled: Array = [], energy: int = -1) -> Array[String]:
	var keys: Array[String] = []
	for key: String in DiceScoring.HAND_PRIORITY:
		if has_part(merged_chip(combo_parts, chain_keys(combo_parts, key, throttled, energy)), ComboPart.SHUNT):
			keys.append(key)
	return keys

static func has_part(sockets: Array, part_id: String) -> bool:
	return count_of(sockets, part_id) > 0

static func count_of(sockets: Array, part_id: String) -> int:
	var count := 0
	for part in sockets:
		if part != null and part.id == part_id:
			count += 1
	return count

## Punkte (x) und Mult (y) eines Kombi-Teils, einmal gezählt. sockets = sein
## eigener Chip (Reihenklemme), first_hand = erste Hand der Runde (Anlasser).
static func combo_values(part: ComboPart, sockets: Array = [], first_hand: bool = false) -> Vector2i:
	match part.id:
		ComboPart.SERIES_TERMINAL:
			var count := part_count(sockets)
			return Vector2i(SERIES_TERMINAL_POINTS * count, SERIES_TERMINAL_MULT * count)
		ComboPart.STARTER:
			return Vector2i(0, STARTER_MULT if first_hand else 0)
		ComboPart.RESISTOR:
			return Vector2i(RESISTOR_POINTS, 0)
		ComboPart.CAPACITOR:
			return Vector2i(0, CAPACITOR_MULT)
		ComboPart.COIL:
			return Vector2i(COIL_POINTS, COIL_MULT)
		ComboPart.COUNTER:
			return Vector2i(0, COUNTER_BASE_MULT + maxi(0, part.counter))
	return Vector2i.ZERO

## Kombi-Schritte der Kombination in Steckplatz-Reihenfolge, je Zählung eines Teils
## einer (die Kopplung wiederholt): {slot, id, points, mult}. Teile ohne Beitrag fehlen.
static func combo_steps(combo_parts: Dictionary, key: String, first_hand: bool = false) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var sockets := chip(combo_parts, key)
	for slot in sockets.size():
		var part: ComboPart = sockets[slot]
		if part == null or part.phase != ComboPart.PHASE_COMBO:
			continue
		var values := combo_values(part, sockets, first_hand)
		if values == Vector2i.ZERO:
			continue
		for _n in weight(sockets, part):
			steps.append({"key": key, "slot": slot, "id": part.id, "points": values.x, "mult": values.y,
				"copied": "", "activated": false})
	return steps

## Kombi-Schritte der ganzen Kette: jede mitgezündete Kombination bringt ihren
## Grundwert als eigenen Schritt (slot -1), dahinter ihre Kombi-Teile.
static func chain_steps(combo_parts: Dictionary, keys: Array[String], first_hand: bool = false) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for index in keys.size():
		if index > 0:
			steps.append({"key": keys[index], "slot": -1, "id": "", "copied": "", "activated": true,
				"points": DiceScoring.points_for(keys[index]), "mult": DiceScoring.mult_for(keys[index])})
		steps.append_array(combo_steps(combo_parts, keys[index], first_hand))
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
static func die_retriggers(sockets: Array, i: int, head: int, tail: int, in_combination: bool = false) -> int:
	var extra := 0
	var overtime := 0  # Überstunden: einmal je Würfel, egal wie viele Module es tragen
	for part in sockets:
		if part == null:
			continue
		overtime = maxi(overtime, part.overtime)
		if part.id == ComboPart.RELAY and i == head and head >= 0:
			extra += RELAY_RETRIGGERS
		elif part.id == ComboPart.OUTPUT_STAGE and i == tail and tail >= 0:
			extra += OUTPUT_STAGE_RETRIGGERS
		elif part.id == ComboPart.PARALLEL_CIRCUIT and in_combination:
			extra += PARALLEL_RETRIGGERS
	return extra + overtime

## Punkte je Zündung eines Kombinationswürfels (Vorwiderstand).
static func firing_base(sockets: Array, in_combination: bool) -> int:
	if not in_combination:
		return 0
	var base := 0
	for part in sockets:
		if part != null and part.id == ComboPart.SERIES_RESISTOR:
			base += SERIES_RESISTOR_POINTS
	return base

## Mult je Zündung eines Kombinationswürfels (Lötpunkt).
static func firing_mult(sockets: Array, in_combination: bool) -> int:
	if not in_combination:
		return 0
	var mult := 0
	for part in sockets:
		if part == null:
			continue
		if part.id == ComboPart.SOLDER_JOINT:
			mult += SOLDER_JOINT_MULT
	return mult

## Steckplätze, die an dieser Zündung etwas beitragen - der Blitz am Chip.
static func firing_slots(sockets: Array, in_combination: bool) -> Array[int]:
	var slots: Array[int] = []
	if not in_combination:
		return slots
	for slot in sockets.size():
		var part: ComboPart = sockets[slot]
		if part == null:
			continue
		if part.id == ComboPart.SERIES_RESISTOR or part.id == ComboPart.SOLDER_JOINT:
			slots.append(slot)
	return slots

## Krit-Schritte nach allen Würfeln, je Zählung eines Teils einer: {slot, id, crit_x}.
static func crit_steps(sockets: Array) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for slot in sockets.size():
		var part: ComboPart = sockets[slot]
		if part == null:
			continue
		var crit := 1.0
		match part.id:
			ComboPart.AMPLIFIER_TUBE:
				crit = AMPLIFIER_TUBE_CRIT
			ComboPart.HIGH_VOLTAGE_TUBE:
				crit = HIGH_VOLTAGE_TUBE_CRIT
			ComboPart.RESONATOR:
				crit = resonator_crit(part)
			ComboPart.AFTERBURNER:
				if part.counter > 0:
					crit = AFTERBURNER_CRIT
		if is_equal_approx(crit, 1.0):
			continue
		for _n in weight(sockets, part):
			steps.append({"slot": slot, "id": part.id, "crit_x": crit})
	return steps

## Der Schwingkreis wächst mit seinem Zähler; er reist beim Umstecken mit.
static func resonator_crit(part: ComboPart) -> float:
	return float(RESONATOR_START_TENTHS + maxi(0, part.counter)) / 10.0

## Krit-Schritte der ganzen Kette, jeder mit seinem Chip.
static func chain_crit_steps(combo_parts: Dictionary, keys: Array[String]) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for key in keys:
		for step in crit_steps(chip(combo_parts, key)):
			step["key"] = key
			steps.append(step)
	return steps

## Geld je Wertung der Kombination (Münzprüfer), sockets = ein Chip.
static func scoring_money(sockets: Array) -> int:
	return COIN_VALIDATOR_MONEY * count_of(weighted(sockets), ComboPart.COIN_VALIDATOR)

## Energie je Wertung (Stromabnehmer), sockets = die Wirk-Liste (merged_chip).
static func scoring_energy(sockets: Array) -> int:
	return POWER_PICKUP_ENERGY * count_of(sockets, ComboPart.POWER_PICKUP)

## Trägt der Chip irgendein Teil, das in der Würfelphase wirkt?
static func has_die_parts(sockets: Array) -> bool:
	for part in sockets:
		if part != null and (part.phase == ComboPart.PHASE_DIE or part.overtime > 0):
			return true
	return false
