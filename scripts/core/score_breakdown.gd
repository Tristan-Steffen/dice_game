class_name ScoreBreakdown
## Zerlegt die Wertung einer Hand in eine GEORDNETE Schrittliste für die
## Zähl-Animation beim Nehmen (siehe scene_root._play_take_animation) - reine
## Rechenlogik ohne Nodes, analog zu DiceScoring. Die Schritte spiegeln exakt
## die Formel von DiceScoring.score_category wider; jeder Schritt trägt die
## Zwischenstände ("base_after"/"mult_after"), damit die Anzeige nie von der
## echten Rechnung abweichen kann. Reihenfolge = Bühnenreihenfolge:
##   1. combo:       feste Kategorie-Punkte + Kategorie-Multiplikator
##   2. die_steps:   je zählendem Würfel Augenwert, dann Material-Boni
##   3. charm_steps: additive Charm-Boni (je Besitz-Position), dann die
##                   Faktoren (Einserkult auf Basis+Mult, Krit auf den Mult)
##   4. merge:       base × mult (geklemmter Mult, siehe _total_mult)
##   5. post_steps:  Effekte NACH dem Verschmelzen (Regenbogenforelle,
##                   Zauberkarte, Feierabendbier)
##
## Charm-Zuordnung läuft über PRÄFIX-MARGINALE: Beitrag der Besitz-Position j =
## f(ids[0..j]) − f(ids[0..j−1]). Die Teleskopsumme ergibt IMMER exakt den
## Gesamtwert - auch bei nichtlinear verschränkten Charms (Einsiedlerkrebs,
## Sammler-Amulett) bleibt die Summe korrekt, nur die Zuordnung ist dann
## näherungsweise. "charm_indices" sind Positionen in GameRun.charm_ids() =
## Besitz-Reihenfolge = Tisch-Plätze (siehe CharmRowView) - Totem-Kopien
## blinken so beim Totem selbst auf, dessen Platz den Effekt beisteuert.

## Baut die Schrittliste - Parameter identisch zu DiceScoring.score_category.
## Ergebnis-Dictionary:
##   key, participating, eye_slots, combo {base_add, mult_add},
##   die_steps [{slot, eye_add, base_after_eye, mat_base_add, mat_mult_add,
##               base_after, mult_after, eye_charm_indices}],
##   charm_steps [{charm_indices, base_add, mult_add, base_x, mult_x,
##                 base_after, mult_after}],
##   base, mult (geklemmt), merge_total, post_steps [{charm_indices, total_add,
##   total_x, total_after}], total (== score_category).
static func build(key: String, dice: Array[int], charm_ids: Array[String] = [], is_first_hand: bool = false, materials: Array[String] = [], edge_materials: Array[String] = [], combo_levels: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	var participating := DiceScoring.participating_indices(key, dice)
	# Nur die beteiligten Würfel zählen ihre Augen in den Basiswert (auch die
	# Summen-Kategorien, siehe DiceScoring._base_value) - ein unbeteiligter
	# sechster Würfel bleibt in der Zähl-Animation dunkel.
	var eye_slots := participating.duplicate()
	var has_materials := not materials.is_empty() or not edge_materials.is_empty()

	# 1. Kombination: feste Punkte + Kategorie-Mult (beide inkl. Menü-Stufen).
	var base := DiceScoring.points_for(key, combo_levels)
	var mult := DiceScoring.mult_for(key, combo_levels)
	var combo := {"base_add": base, "mult_add": mult}

	# 2. Würfel-Schritte: erst der (charm-angepasste) Augenwert, dann die
	# Material-Boni GENAU dieses Würfels (base_bonus/mult_bonus mit
	# participating=[i] - die Summe über alle Würfel ergibt exakt den
	# Gesamtbonus, da beide Funktionen je beteiligtem Slot addieren).
	var die_steps: Array[Dictionary] = []
	for i in eye_slots:
		var eye := CharmEffects.eye_value(dice[i], charm_ids)
		base += eye
		var base_after_eye := base
		var mat_base := 0
		var mat_mult := 0
		if has_materials and participating.has(i):
			var only: Array[int] = [i]
			mat_base = MaterialEffects.base_bonus(dice, materials, only, charm_ids, edge_materials)
			mat_mult = MaterialEffects.mult_bonus(dice, materials, only, edge_materials, charm_ids)
		base += mat_base
		mult += mat_mult
		die_steps.append({
			"slot": i,
			"eye_add": eye,
			"base_after_eye": base_after_eye,
			"mat_base_add": mat_base,
			"mat_mult_add": mat_mult,
			"base_after": base,
			"mult_after": mult,
			"eye_charm_indices": _eye_charm_indices(dice[i], charm_ids),
		})

	# 3. Charm-Schritte: additive Boni je Besitz-Position (Präfix-Marginale),
	# danach die Faktoren in der Reihenfolge von score_category/_total_mult.
	var charm_steps: Array[Dictionary] = []
	if not charm_ids.is_empty():
		var prev_base_bonus := 0
		var prev_mult_bonus := 0
		for j in charm_ids.size():
			var prefix: Array[String] = []
			prefix.assign(charm_ids.slice(0, j + 1))
			var base_bonus := CharmEffects.charm_base_bonus(key, dice, participating, prefix, ctx, materials, edge_materials)
			var mult_bonus := CharmEffects.mult_bonus(key, prefix) \
				+ CharmEffects.charm_mult_bonus(key, dice, materials, prefix, ctx, combo_levels, participating)
			var base_add := base_bonus - prev_base_bonus
			var mult_add := mult_bonus - prev_mult_bonus
			prev_base_bonus = base_bonus
			prev_mult_bonus = mult_bonus
			if base_add == 0 and mult_add == 0:
				continue
			base += base_add
			mult += mult_add
			var step_indices: Array[int] = [j]
			charm_steps.append({
				"charm_indices": step_indices,
				"base_add": base_add, "mult_add": mult_add,
				"base_x": 1, "mult_x": 1,
				"base_after": base, "mult_after": mult,
			})
		# Einserkult: Faktor auf Basis UND Mult - NACH den additiven Charm-Boni
		# (siehe score_category: base *= base_factor erst nach charm_base_bonus).
		var factor := CharmEffects.base_factor(dice, charm_ids)
		if factor != 1:
			base *= factor
			mult *= factor
			charm_steps.append({
				"charm_indices": _indices_of(charm_ids, Charm.CULT_OF_ONE),
				"base_add": 0, "mult_add": 0,
				"base_x": factor, "mult_x": factor,
				"base_after": base, "mult_after": mult,
			})
		# Krit-Pool: multipliziert den fertigen Mult mit (1 + Summe) - ein
		# gemeinsamer Schritt, der alle beitragenden Charms aufblinken lässt.
		var crit := CharmEffects.crit_bonus(key, charm_ids, ctx, combo_levels)
		if crit > 0:
			mult *= 1 + crit
			charm_steps.append({
				"charm_indices": _crit_charm_indices(key, charm_ids, ctx, combo_levels),
				"base_add": 0, "mult_add": 0,
				"base_x": 1, "mult_x": 1 + crit,
				"base_after": base, "mult_after": mult,
			})

	# 4. Verschmelzen: base × mult (Klemme wie DiceScoring._total_mult).
	mult = maxi(1, mult)
	var total := base * mult
	var merge_total := total

	# 5. Nach-Schritte auf die fertige Punktzahl (Reihenfolge wie score_category).
	var post_steps: Array[Dictionary] = []
	var flat := CharmEffects.flat_bonus(key, charm_ids)
	if flat != 0:
		total += flat
		post_steps.append({
			"charm_indices": _indices_of(charm_ids, Charm.RAINBOW_TROUT),
			"total_add": flat, "total_x": 1.0, "total_after": total,
		})
	var score_mult := CharmEffects.score_multiplier(charm_ids, is_first_hand)
	if score_mult != 1:
		total *= score_mult
		post_steps.append({
			"charm_indices": _indices_of(charm_ids, Charm.MAGIC_CARD),
			"total_add": 0, "total_x": float(score_mult), "total_after": total,
		})
	var hand_factor := CharmEffects.hand_factor(key, charm_ids, ctx)
	if hand_factor != 1.0:
		total = int(round(total * hand_factor))
		post_steps.append({
			"charm_indices": _indices_of(charm_ids, Charm.AFTER_WORK_BEER),
			"total_add": 0, "total_x": hand_factor, "total_after": total,
		})

	# Sicherheitsnetz: Die Schritte MÜSSEN die echte Wertung ergeben (per Test
	# abgesichert, siehe test_score_breakdown). Falls eine künftige Änderung an
	# DiceScoring hier vergessen wird, gewinnt die echte Wertung - die Anzeige
	# springt dann am Ende auf den korrekten Wert, statt falsche Punkte zu zahlen.
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

## Besitz-Positionen der Charms, die den Augenwert DIESES Wurfwerts verändern
## (Hasenpfote, Glückszigaretten, ...): Position j zählt, wenn der Augenwert
## ohne sie anders ausfiele (Leave-one-out gegen den vollen Wert).
static func _eye_charm_indices(value: int, charm_ids: Array[String]) -> Array[int]:
	var full := CharmEffects.eye_value(value, charm_ids)
	var result: Array[int] = []
	if full == value:
		return result
	for j in charm_ids.size():
		var without: Array[String] = []
		for k in charm_ids.size():
			if k != j:
				without.append(charm_ids[k])
		if CharmEffects.eye_value(value, without) != full:
			result.append(j)
	return result

## Alle Besitz-Positionen mit der gegebenen Charm-id (z.B. beide Einserkulte).
static func _indices_of(charm_ids: Array[String], charm_id: String) -> Array[int]:
	var result: Array[int] = []
	for j in charm_ids.size():
		if charm_ids[j] == charm_id:
			result.append(j)
	return result

## Besitz-Positionen, die zum Krit-Pool beitragen (Präfix-Marginale über
## CharmEffects.crit_bonus - Positionen mit Beitrag 0 blinken nicht).
static func _crit_charm_indices(key: String, charm_ids: Array[String], ctx: Dictionary, combo_levels: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var prev := 0
	for j in charm_ids.size():
		var prefix: Array[String] = []
		prefix.assign(charm_ids.slice(0, j + 1))
		var value := CharmEffects.crit_bonus(key, prefix, ctx, combo_levels)
		if value != prev:
			result.append(j)
		prev = value
	return result
