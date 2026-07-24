class_name ScoreBreakdown
## Zerlegt die Wertung einer Hand in eine geordnete Schrittliste für die
## Zähl-Animation. Die Schritte spiegeln exakt die Formel und TRIGGER-
## REIHENFOLGE von DiceScoring.score_category: Würfel links nach rechts
## (Augen, Material, Pro-Würfel-Charms MIT ihrem Würfel), dann Charms strikt
## in Besitz-Reihenfolge (Boni und Faktoren an ihrer Position), nach dem
## Verschmelzen die Gesamtzahl-Effekte. Jeder Schritt trägt Zwischenstände
## (base_after/mult_after), damit die Anzeige nie von der Rechnung abweicht.

## Baut die Schrittliste - Parameter wie DiceScoring.score_category.
## Ergebnis: key, participating, eye_slots, combo, die_steps, charm_steps,
## base, mult, merge_total, post_steps, total (== score_category).
static func build(key: String, dice: Array[int], charm_ids: Array[String] = [], is_first_hand: bool = false, materials: Array[String] = [], edge_materials: Array[String] = [], combo_levels: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	# Verwandlung zuerst - wie in DiceScoring; raw bleibt für die Charm-Zuordnung.
	var raw := dice
	dice = CharmEffects.transform_values(dice, charm_ids)
	var participating := DiceScoring.participating_indices(key, dice)
	# Normal zählen nur beteiligte Würfel Augen; mit Vollzähler ALLE liegenden
	# (dann leuchten und triggern auch die Unbeteiligten).
	var eye_slots := CharmEffects.scored_indices(participating, dice.size(), charm_ids).duplicate()
	var has_materials := not materials.is_empty() or not edge_materials.is_empty()
	# Retrigger-Charms zählen auch ohne Materialien über den base_bonus-Pfad.
	var has_die_bonus := has_materials or not charm_ids.is_empty()

	# 1. Kombination: feste Punkte + Kategorie-Mult (inkl. Menü-Stufen).
	var base := DiceScoring.points_for(key, combo_levels)
	var mult := DiceScoring.mult_for(key, combo_levels)
	var combo := {"base_add": base, "mult_add": mult}

	# 2. Würfel-Schritte links nach rechts: Augenwert, Material-Boni, dann die
	# Pro-Würfel-Charms genau dieses Würfels - sie feuern MIT ihrem Würfel.
	var die_steps: Array[Dictionary] = []
	# Echo-Kammer: aus der GANZEN Wertung bestimmt, nicht aus dem Einzel-Slot unten.
	var echo_slot := CharmEffects.first_participating(dice, eye_slots)
	for i in eye_slots:
		var eye := CharmEffects.eye_value(dice[i], charm_ids)
		base += eye
		var base_after_eye := base
		var mult_after_eye := mult
		var mat_base := 0
		var mat_mult := 0
		if has_die_bonus:
			var only: Array[int] = [i]
			mat_base = MaterialEffects.base_bonus(dice, materials, only, charm_ids, edge_materials, echo_slot)
			mat_mult = MaterialEffects.mult_bonus(dice, materials, only, edge_materials, charm_ids, echo_slot)
		base += mat_base
		mult += mat_mult
		var base_after_mat := base
		var mult_after_mat := mult
		# Retrigger sichtbar machen: löst der Würfel mehrfach aus (Quecksilber,
		# Retrigger-Charms, Echo-Kammer), zerlegt die Animation Augen + Material
		# in eine Auslösung je Aktivierung - alle gleich, Summe = Aggregat oben.
		var activations: Array[Dictionary] = []
		if has_die_bonus:
			var count := MaterialEffects.activation_count(i, materials, edge_materials, charm_ids, dice[i], echo_slot)
			if count > 1:
				var amber_per := (mat_base - eye * (count - 1)) / count
				var per_base := eye + amber_per
				var per_mult := mat_mult / count
				var acc_base := base_after_eye - eye
				var acc_mult := mult_after_eye
				for _a in count:
					acc_base += per_base
					acc_mult += per_mult
					activations.append({
						"base_add": per_base, "mult_add": per_mult,
						"base_after": acc_base, "mult_after": acc_mult,
					})
		var charm_base := 0
		var charm_mult := 0
		var die_charm_indices: Array[int] = []
		for j in charm_ids.size():
			var cb := CharmEffects.die_charm_base_at(j, i, key, dice, charm_ids, ctx, edge_materials)
			var cm := CharmEffects.die_charm_mult_at(j, i, charm_ids, ctx)
			if cb != 0 or cm != 0:
				charm_base += cb
				charm_mult += cm
				die_charm_indices.append(j)
		base += charm_base
		mult += charm_mult
		die_steps.append({
			"slot": i,
			"eye_add": eye,
			"base_after_eye": base_after_eye,
			"mult_after_eye": mult_after_eye,
			"mat_base_add": mat_base,
			"mat_mult_add": mat_mult,
			"base_after_mat": base_after_mat,
			"mult_after_mat": mult_after_mat,
			"charm_base_add": charm_base,
			"charm_mult_add": charm_mult,
			"die_charm_indices": die_charm_indices,
			"base_after": base,
			"mult_after": mult,
			"eye_charm_indices": _eye_charm_indices(raw[i], charm_ids),
			"activations": activations,
		})

	# 3. Charm-Schritte strikt in Besitz-Reihenfolge: additive Boni UND Faktoren
	# der Position j wirken an ihrer Position - nie gesammelt am Ende.
	var charm_steps: Array[Dictionary] = []
	for j in charm_ids.size():
		var base_add := CharmEffects.charm_base_bonus_at(j, key, dice, participating, charm_ids, ctx)
		var mult_add := CharmEffects.mult_bonus_at(j, key, charm_ids) \
			+ CharmEffects.charm_mult_bonus_at(j, key, dice, materials, charm_ids, ctx, participating)
		var base_x := CharmEffects.charm_base_factor_at(j, dice, charm_ids, ctx)
		# Krit: eigener Hook, wirkt im Schritt als Teil des Mult-Faktors;
		# crit_x bleibt separat sichtbar, damit die UI Krits inszenieren kann.
		var crit_x := CharmEffects.charm_crit_at(j, dice, charm_ids, ctx)
		var mult_x := CharmEffects.charm_mult_factor_at(j, dice, charm_ids, ctx) * crit_x
		if base_add == 0 and mult_add == 0 and base_x == 1 and mult_x == 1:
			continue
		var base_before := base
		var mult_before := mult
		base = (base + base_add) * base_x
		mult = (mult + mult_add) * mult_x
		var step_indices: Array[int] = [j]
		var step := {
			"charm_indices": step_indices,
			"base_add": base_add, "mult_add": mult_add,
			"base_x": base_x, "mult_x": mult_x, "crit_x": crit_x,
			"base_after": base, "mult_after": mult,
		}
		# Hand-Charms mit Würfel-Bezug (Vollzähler & Co.) fächern ihren Beitrag
		# in Einzel-Pulse auf, damit die Animation je Würfel einen Meteor
		# schickt - aber nur, wenn die Pulse-Summe den Beitrag exakt trifft
		# (sonst Rückfall auf einen Meteor, nie falsche Zahlen).
		var pulses := _per_die_pulses(charm_ids[j], key, dice, participating, charm_ids, ctx)
		if not pulses.is_empty():
			var sum_base := 0
			var sum_mult := 0
			for p in pulses:
				sum_base += int(p["base"])
				sum_mult += int(p["mult"])
			if sum_base == base_add and sum_mult == mult_add and base_x == 1 and mult_x == 1:
				var acc_base := base_before
				var acc_mult := mult_before
				for p in pulses:
					acc_base += int(p["base"])
					acc_mult += int(p["mult"])
					p["base_after"] = acc_base
					p["mult_after"] = acc_mult
				step["pulses"] = pulses
		charm_steps.append(step)

	# 4. Verschmelzen: base × mult (Klemme wie DiceScoring._total_mult).
	mult = maxi(1, mult)
	var total := base * mult
	var merge_total := total

	# 5. Nach-Schritte auf die fertige Punktzahl - ebenfalls Besitz-Reihenfolge.
	var post_steps: Array[Dictionary] = []
	for j in charm_ids.size():
		var total_x := CharmEffects.charm_total_factor_at(j, charm_ids, is_first_hand)
		if total_x == 1:
			continue
		total *= total_x
		var post_indices: Array[int] = [j]
		post_steps.append({
			"charm_indices": post_indices,
			"total_add": 0, "total_x": float(total_x), "total_after": total,
		})

	# Sicherheitsnetz: die echte Wertung gewinnt, falls die Schrittliste je
	# hinter einer DiceScoring-Änderung zurückbleibt.
	var expected := DiceScoring.score_category(key, dice, charm_ids, is_first_hand, materials, edge_materials, combo_levels, ctx)
	if total != expected:
		push_warning("ScoreBreakdown weicht von DiceScoring ab (%d statt %d) - Schrittliste veraltet?" % [total, expected])
		total = expected

	return {
		"key": key,
		"participating": participating,
		"eye_slots": eye_slots,
		"combo": combo,
		"die_steps": die_steps,
		"charm_steps": charm_steps,
		"base": base,
		"mult": mult,
		"merge_total": merge_total,
		"post_steps": post_steps,
		"total": total,
	}

## Zerlegt den Beitrag eines Hand-Charms MIT Würfel-Bezug in Einzel-Pulse
## {slot, base, mult} für die Meteor-je-Würfel-Animation. Betrifft nur Charms,
## deren Bezugswürfel NICHT beteiligt sind (Schlangenaugen) oder paarweise zählen
## (Zwillingsring) - echte Pro-Würfel-Charms feuern in den Würfel-Schritten. Leer
## für alle anderen; der Aufrufer prüft zusätzlich, dass die Pulse-Summe passt.
static func _per_die_pulses(charm_id: String, key: String, dice: Array[int], participating: Array[int], charm_ids: Array[String], _ctx: Dictionary) -> Array[Dictionary]:
	var pulses: Array[Dictionary] = []
	match charm_id:
		Charm.SNAKE_EYES:
			if key == DiceScoring.TWO_KIND and CharmEffects._participating_are_ones(dice, participating):
				for i in dice.size():
					if not participating.has(i):
						pulses.append({"slot": i, "base": 0, "mult": dice[i]})
		Charm.TWIN_RING:
			for value in CharmEffects._distinct(dice):
				if dice.count(value) == 2:
					pulses.append({"slot": dice.find(value), "base": 0, "mult": value})
	return pulses

## Besitz-Positionen, die den Augen-Beitrag dieses ROHEN Werts verändern
## (Leave-one-out über Verwandlung + Basispunkt-Anpassung).
static func _eye_charm_indices(value: int, charm_ids: Array[String]) -> Array[int]:
	var full := _eye_contribution(value, charm_ids)
	var result: Array[int] = []
	if full == value:
		return result
	for j in charm_ids.size():
		var without: Array[String] = []
		for k in charm_ids.size():
			if k != j:
				without.append(charm_ids[k])
		if _eye_contribution(value, without) != full:
			result.append(j)
	return result

static func _eye_contribution(value: int, charm_ids: Array[String]) -> int:
	return CharmEffects.eye_value(CharmEffects.transform_value(value, charm_ids), charm_ids)
