class_name RoundLog
extends RefCounted
## Chronik der laufenden Runde: je Wurf, Zug und Fumble ein Eintrag mit dem
## Tisch-Zustand des Moments. Der Zug trägt zusätzlich seine Schrittliste - EIN
## Schritt je Auslösung, in der Reihenfolge der Zähl-Zeremonie. Jeder Schritt
## trägt seine After-Stände selbst, damit der Cursor auch rückwärts springen
## kann, ohne die Rechnung nachzuspielen.

const ENTRY_THROW := "throw"
const ENTRY_TAKE := "take"
const ENTRY_FARKLE := "farkle"
## Ein Ladungs-Ereignis: Aufladen, Durchbrennen, Entladen, Reparatur-Bucht.
const ENTRY_CHARGE := "charge"

const STEP_POSE := "pose"  # der Eintrag selbst, ohne Wertung (Wurf, Fumble)
const STEP_COMBO := "combo"
const STEP_COMBO_FACTOR := "combo_factor"  # eine Doppelter-Boden-Kopie
const STEP_FIRING := "firing"
const STEP_CRIT := "crit"
const STEP_LINK := "link"
const STEP_DET_LINK := "det_link"
const STEP_CHARM := "charm"
const STEP_CHARM_PULSE := "charm_pulse"
const STEP_MERGE := "merge"
const STEP_POST := "post"
const STEP_RESULT := "result"

const NO_TOTAL := -1  # Schritt rührt den Gesamt-Orb nicht an

var entries: Array[Dictionary] = []

## Namens-Nachschlag der Charms, einmal je Prozess gebaut.
static var _charm_names: Dictionary = {}

func clear() -> void:
	entries.clear()

func add_entry(entry: Dictionary) -> void:
	entries.append(entry)

func is_empty() -> bool:
	return entries.is_empty()

func entry_at(index: int) -> Dictionary:
	if index < 0 or index >= entries.size():
		return {}
	return entries[index]

## Schritte eines Eintrags: Schritt 0 ist immer die Pose, danach die Wertung.
func step_count(entry_index: int) -> int:
	var entry := entry_at(entry_index)
	if entry.is_empty():
		return 0
	var steps: Array = entry.get("steps", [])
	return 1 + steps.size()

func total_steps() -> int:
	var sum := 0
	for i in entries.size():
		sum += step_count(i)
	return sum

## Ein Schritt vor oder zurück, über Eintragsgrenzen hinweg; klemmt an beiden
## Enden des Logs. Cursor = Vector2i(Eintrag, Schritt).
func advance(cursor: Vector2i, delta: int) -> Vector2i:
	if entries.is_empty():
		return cursor
	var entry := clampi(cursor.x, 0, entries.size() - 1)
	var step := cursor.y + delta
	while step < 0:
		if entry == 0:
			return Vector2i(0, 0)
		entry -= 1
		step += step_count(entry)
	while step >= step_count(entry):
		if entry == entries.size() - 1:
			return Vector2i(entry, step_count(entry) - 1)
		step -= step_count(entry)
		entry += 1
	return Vector2i(entry, step)

## Zerlegt einen (bereits auf echte Slots geremappten) Breakdown in die lineare
## Schrittliste. Reihenfolge exakt wie _play_take_animation: Kombination, je
## Würfel-Schritt die Gruppen der Würfel-Achse (Zündungen mit ihren Krits, dann
## die Glieder), zuletzt die Essenz-Glieder; danach die statischen Charms, das
## Verschmelzen, die Nach-Schritte und das gebuchte Ergebnis.
static func flatten(breakdown: Dictionary, charm_ids: Array[String] = []) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if breakdown.is_empty():
		return steps
	var overrides: Dictionary = {}

	var combo: Dictionary = breakdown.get("combo", {})
	var combo_base := int(combo.get("base_add", 0))
	var combo_mult := float(combo.get("mult_add", 0))
	steps.append(_step(STEP_COMBO, "%s · +%d Punkte · +%s Mult" % [
			DiceScoring.label_for(String(breakdown.get("key", ""))), combo_base,
			ScoreBreakdown.format_number(combo_mult)],
		combo_base, combo_mult, overrides))

	# Der Dreifache Boden steht als eigener Schritt direkt hinter der Kombination -
	# im Rückblick wie in der Zeremonie, sonst springt die Zahl unerklärt.
	for factor_step: Dictionary in breakdown.get("combo_factor_steps", []):
		var factor := _step(STEP_COMBO_FACTOR,
			"%s · Kombination ×3" % charm_name(Charm.DOUBLE_BOTTOM),
			int(factor_step.get("base_after", 0)), float(factor_step.get("mult_after", 0.0)),
			overrides)
		factor["charm_indices"] = _int_list(factor_step.get("charm_indices", []))
		steps.append(factor)

	for die_step: Dictionary in breakdown.get("die_steps", []):
		var slot := int(die_step.get("slot", -1))
		for group: Dictionary in die_step.get("die_triggers", []):
			for firing: Dictionary in group.get("firings", []):
				_append_firing(steps, firing, slot, charm_ids, overrides)
			for link: Dictionary in group.get("links", []):
				_append_link(steps, link, slot, charm_ids, overrides, STEP_LINK)
		for link: Dictionary in die_step.get("det_links", []):
			_append_link(steps, link, slot, charm_ids, overrides, STEP_DET_LINK)

	for charm_step: Dictionary in breakdown.get("charm_steps", []):
		_append_charm(steps, charm_step, charm_ids, overrides)

	var merge_total := int(breakdown.get("merge_total", 0))
	var final_base := int(breakdown.get("base", 0))
	var final_mult := float(breakdown.get("mult", 1.0))
	var merge := _step(STEP_MERGE, "Verschmelzen: %d × %s = %d" % [
			final_base, ScoreBreakdown.format_number(final_mult), merge_total],
		final_base, final_mult, overrides)
	merge["total_after"] = merge_total
	steps.append(merge)

	for post: Dictionary in breakdown.get("post_steps", []):
		var total_after := int(post.get("total_after", 0))
		var post_step := _step(STEP_POST, "%s · %s → %d" % [
				_charm_label(post.get("charm_indices", []), charm_ids),
				ScoreBreakdown.format_mult(float(post.get("total_x", 1.0))), total_after],
			final_base, final_mult, overrides)
		post_step["total_after"] = total_after
		post_step["charm_indices"] = _int_list(post.get("charm_indices", []))
		steps.append(post_step)

	var total := int(breakdown.get("total", 0))
	var result := _step(STEP_RESULT, "Ergebnis: %d Punkte" % total, final_base, final_mult, overrides)
	result["total_after"] = total
	steps.append(result)
	return steps

## Eine Zündung: Augen + Material + Charm-Anteil in EINEM Schritt, jeder Krit
## danach als eigener Schlag. Der physische Wert danach wandert in die Ziffern.
static func _append_firing(steps: Array[Dictionary], firing: Dictionary, slot: int,
		charm_ids: Array[String], overrides: Dictionary) -> void:
	var value := int(firing.get("value", 0))
	var parts: Array[String] = ["Würfel %d" % value]
	_add_amounts(parts, int(firing.get("base_add", 0)), float(firing.get("mult_add", 0)))
	var charm_base := int(firing.get("charm_base_add", 0))
	var charm_mult := int(firing.get("charm_mult_add", 0))
	if charm_base != 0 or charm_mult != 0:
		var charm_part: Array[String] = [_charm_label(firing.get("die_charm_indices", []), charm_ids)]
		_add_amounts(charm_part, charm_base, float(charm_mult))
		parts.append(" ".join(charm_part))
	if firing.has("value_after"):
		overrides[slot] = int(firing["value_after"])
	var step := _step(STEP_FIRING, " · ".join(parts),
		int(firing.get("charm_base_after", firing.get("base_after", 0))),
		float(firing.get("charm_mult_after", firing.get("mult_after", 1.0))), overrides)
	step["slot"] = slot
	step["flash_slot"] = slot
	step["value"] = value
	step["charm_indices"] = _int_list(firing.get("die_charm_indices", []))
	steps.append(step)
	_append_crits(steps, firing, slot, charm_ids, overrides)

## Ein Pointer- oder Essenz-Glied: wie eine Zündung mit getauschter Seite.
static func _append_link(steps: Array[Dictionary], link: Dictionary, slot: int,
		charm_ids: Array[String], overrides: Dictionary, kind: String) -> void:
	var face := int(link.get("face", 0))
	var head := "Glied → Seite %d" % (face + 1) if kind == STEP_DET_LINK \
		else "Pointer → Seite %d" % (face + 1)
	var parts: Array[String] = [head]
	_add_amounts(parts, int(link.get("base_add", 0)), float(link.get("mult_add", 0)))
	var step := _step(kind, " · ".join(parts),
		int(link.get("charm_base_after", link.get("base_after", 0))),
		float(link.get("charm_mult_after", link.get("mult_after", 1.0))), overrides)
	step["slot"] = slot
	step["flash_slot"] = slot
	step["face"] = face
	step["net"] = {"slot": slot, "face": face}
	step["charm_indices"] = _int_list(link.get("die_charm_indices", []))
	steps.append(step)
	_append_crits(steps, link, slot, charm_ids, overrides)

## JEDER Krit ein eigener Schritt - zwei Kopien schlagen zweimal ein.
static func _append_crits(steps: Array[Dictionary], entry: Dictionary, slot: int,
		charm_ids: Array[String], overrides: Dictionary) -> void:
	for crit: Dictionary in entry.get("crit_steps", []):
		var crit_x := float(crit.get("crit_x", 1.0))
		var from_die := bool(crit.get("from_die", false))
		var head := "Würfel-Krit" if from_die else _charm_label(crit.get("charm_indices", []), charm_ids)
		var label := "%s %s" % [head, ScoreBreakdown.format_mult(crit_x)]
		var firedamp := int(crit.get("firedamp_add", 0))
		if firedamp != 0:
			label += " · +%d Punkte" % firedamp
		var step := _step(STEP_CRIT, label, int(crit.get("base_after", 0)),
			float(crit.get("mult_after", 1.0)), overrides)
		step["slot"] = slot
		step["flash_slot"] = slot
		step["crit_x"] = crit_x
		step["from_die"] = from_die
		step["charm_indices"] = _int_list(crit.get("charm_indices", []))
		steps.append(step)

## Ein statischer Charm-Schritt; Pro-Würfel-Charms fächern in ihre Einzel-Pulse auf.
static func _append_charm(steps: Array[Dictionary], charm_step: Dictionary,
		charm_ids: Array[String], overrides: Dictionary) -> void:
	var charm_text := _charm_label(charm_step.get("charm_indices", []), charm_ids)
	var indices := _int_list(charm_step.get("charm_indices", []))
	var pulses: Array = charm_step.get("pulses", [])
	if not pulses.is_empty():
		for pulse: Dictionary in pulses:
			var pulse_parts: Array[String] = [charm_text]
			_add_amounts(pulse_parts, int(pulse.get("base", 0)), float(pulse.get("mult", 0)))
			var pulse_step := _step(STEP_CHARM_PULSE, " · ".join(pulse_parts),
				int(pulse.get("base_after", 0)), float(pulse.get("mult_after", 1.0)), overrides)
			pulse_step["slot"] = int(pulse.get("slot", -1))
			pulse_step["flash_slot"] = int(pulse.get("slot", -1))
			pulse_step["charm_indices"] = indices.duplicate()
			steps.append(pulse_step)
		return
	var parts: Array[String] = [charm_text]
	_add_amounts(parts, int(charm_step.get("base_add", 0)), float(charm_step.get("mult_add", 0)))
	var base_x := int(charm_step.get("base_x", 1))
	if base_x != 1:
		parts.append("Basis %s" % ScoreBreakdown.format_mult(float(base_x)))
	var mult_x := float(charm_step.get("mult_x", 1.0))
	if not is_equal_approx(mult_x, 1.0):
		parts.append("Mult %s" % ScoreBreakdown.format_mult(mult_x))
	if bool(charm_step.get("spotlight", false)):
		parts.append("Rampenlicht")
	var crit_x := float(charm_step.get("crit_x", 1.0))
	var kind := STEP_CRIT if not is_equal_approx(crit_x, 1.0) else STEP_CHARM
	var step := _step(kind, " · ".join(parts), int(charm_step.get("base_after", 0)),
		float(charm_step.get("mult_after", 1.0)), overrides)
	step["crit_x"] = crit_x
	step["charm_indices"] = indices
	step["spotlight"] = bool(charm_step.get("spotlight", false))
	steps.append(step)

## Grundgerüst jedes Schritts - die Überschreibungen reisen als Momentaufnahme mit.
static func _step(kind: String, label: String, base_after: int, mult_after: float,
		overrides: Dictionary) -> Dictionary:
	var no_charms: Array[int] = []
	return {
		"kind": kind,
		"label": label,
		"base_after": base_after,
		"mult_after": mult_after,
		"total_after": NO_TOTAL,
		"overrides": overrides.duplicate(),
		"slot": -1,
		"flash_slot": -1,
		"charm_indices": no_charms,
		"net": {},
		"crit_x": 1.0,
		"from_die": false,
	}

static func _add_amounts(parts: Array[String], base_add: int, mult_add: float) -> void:
	if base_add != 0:
		parts.append("+%d Punkte" % base_add)
	if not is_zero_approx(mult_add):
		parts.append("+%s Mult" % ScoreBreakdown.format_number(mult_add))

static func _int_list(source) -> Array[int]:
	var result: Array[int] = []
	for i in source:
		result.append(int(i))
	return result

## Anzeigename der beteiligten Charms; ohne Dock-Bezug bleibt es beim Würfel.
static func _charm_label(indices, charm_ids: Array[String]) -> String:
	var names: Array[String] = []
	for i in indices:
		var j := int(i)
		if j >= 0 and j < charm_ids.size():
			var display := charm_name(charm_ids[j])
			if not names.has(display):
				names.append(display)
	if names.is_empty():
		return "Charm"
	return ", ".join(names)

static func charm_name(id: String) -> String:
	if _charm_names.is_empty():
		for charm in Charm.all():
			_charm_names[charm.id] = charm.display_name
	return String(_charm_names.get(id, id))

## Zeile eines Würfel-Eintrags in der Liste: die liegenden Augen.
static func values_label(pit: Array) -> String:
	var parts: Array[String] = []
	for slot: Dictionary in pit:
		if bool(slot.get("visible", false)):
			parts.append(str(int(slot.get("value", 0))))
	if parts.is_empty():
		return "keine Würfel"
	return " · ".join(parts)

## Ein Grubenslot für die Chronik. Die Def wird KOPIERT - sie wächst während der
## Runde weiter (Knochen, Glas), die Vergangenheit darf das nicht mitmachen.
static func pit_slot_record(def: DieDefinition, face_index: int, value: int,
		visible: bool, selected: bool) -> Dictionary:
	return {
		"def": def.instantiate() if def != null else DieDefinition.standard(),
		"face_index": face_index,
		"value": value,
		"visible": visible,
		"selected": selected,
	}

static func copy_defs(defs: Array[DieDefinition]) -> Array[DieDefinition]:
	var result: Array[DieDefinition] = []
	for def in defs:
		if def != null:
			result.append(def.instantiate())
	return result
