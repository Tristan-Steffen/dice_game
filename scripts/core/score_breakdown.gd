class_name ScoreBreakdown
## Zerlegt die Wertung einer Hand in eine geordnete Schrittliste für die
## Zähl-Animation. Die Schritte spiegeln exakt die Formel und TRIGGER-
## REIHENFOLGE von DiceScoring.score_category: Würfel in Reihen-Ordnung
## (trigger_order), je Aktivierung Augen -> Material -> würfelgebundene
## Charms (additiv, dann Krits); danach statische Charms strikt in Besitz-
## Reihenfolge, nach dem Verschmelzen die Gesamtzahl-Effekte. Jeder Schritt
## trägt Zwischenstände, damit die Anzeige nie von der Rechnung abweicht.

## Baut die Schrittliste - Parameter wie DiceScoring.score_category.
## Ergebnis: key, participating, eye_slots, combo, die_steps, charm_steps,
## base, mult, merge_total, post_steps, total (== score_category).
## Jeder Würfel-Schritt spielt seine "activations" nacheinander (auch bei nur
## einer): Würfel-Puls -> Charm-Anteil -> Krit-Schlag, mit After-Ständen je
## Teilschritt - so ist das Mehrfach-Auslösen als Kette sichtbar.
static func build(key: String, dice: Array[int], charm_ids: Array[String] = [], is_first_hand: bool = false, materials: Array[String] = [], edge_materials: Array[String] = [], combo_levels: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	# Verwandlung zuerst - wie in DiceScoring; raw bleibt für die Charm-Zuordnung.
	var raw := dice
	dice = CharmEffects.transform_values(dice, charm_ids)
	var participating := DiceScoring.participating_indices(key, dice, [], ctx)
	# Normal zählen nur beteiligte Würfel Augen; mit Vollzähler ALLE liegenden.
	# Reihen-Ordnung = die aufgereihte Reihe (wertungsrelevant wegen Beherit).
	var scored := CharmEffects.scored_indices(participating, dice.size(), charm_ids)
	# Wie in DiceScoring._base_and_mult: der Vollzähler zieht keine paritäts-
	# gesperrten Würfel herein, sonst zeigt die Animation einen Würfel, den die
	# Wertung übersprungen hat.
	var legal := DiceScoring.legal_indices(dice, ctx)
	if legal.size() < dice.size():
		var allowed: Array[int] = []
		for i in scored:
			if legal.has(i):
				allowed.append(i)
		scored = allowed
	var eye_slots := DiceScoring.trigger_order(scored, dice)
	var has_die_bonus := not materials.is_empty() or not edge_materials.is_empty() or not charm_ids.is_empty()

	# 1. Kombination: feste Punkte + Kategorie-Mult (inkl. Menü-Stufen).
	var base := DiceScoring.points_for(key, combo_levels)
	var mult := DiceScoring.mult_for(key, combo_levels)
	var combo := {"base_add": base, "mult_add": mult}

	# 2. Würfel-Schritte in Reihen-Ordnung. Je Aktivierung: Augen + Material,
	# dann die würfelgebundenen Charms (additiv, dann Krits) - exakt die
	# Reihenfolge von DiceScoring._base_and_mult.
	var die_steps: Array[Dictionary] = []
	# Echo-Kammer: aus der GANZEN Wertung bestimmt, nicht aus dem Einzel-Slot unten.
	var echo_slot := CharmEffects.first_participating(dice, eye_slots)
	for i in eye_slots:
		var info := DiceScoring.upgrade_info_for(ctx, i)
		var upgraded := bool(info.get("upgraded", false))
		var eye_sum := int(info.get("eye_sum", 0))
		var face_material: String = materials[i] if i < materials.size() else ""
		var eye := CharmEffects.eye_value(dice[i], charm_ids)
		var count := 1
		var once_base := 0
		var once_mult := 0
		# Material-Krit (dotierter Rubin/Glas): zählt in crit_x mit, bekommt aber
		# keinen Charm-Index - er kommt vom Würfel, nicht von einem Dock-Pad.
		var mat_crit := 1
		if has_die_bonus:
			count = MaterialEffects.activation_count(i, materials, edge_materials, charm_ids, dice[i], echo_slot, upgraded, int(info.get("mercury_faces", 0)))
			once_base = MaterialEffects.base_bonus_once(i, materials, edge_materials, charm_ids, upgraded, eye_sum)
			once_mult = MaterialEffects.mult_bonus_once(i, dice, materials, edge_materials, charm_ids, upgraded)
			mat_crit = MaterialEffects.mult_crit_once_for(face_material, dice[i], charm_ids, upgraded)
		# Würfelgebundene Charms dieses Slots, Beitrag EINER Auslösung.
		var charm_base_once := 0
		var charm_mult_once := 0
		var die_charm_indices: Array[int] = []
		var crit_once := mat_crit
		var crit_charm_indices: Array[int] = []
		for j in charm_ids.size():
			var cb := CharmEffects.die_charm_base_at(j, i, key, dice, charm_ids, ctx, edge_materials, eye_slots)
			var cm := CharmEffects.die_charm_mult_at(j, i, dice, charm_ids, ctx) \
				+ CharmEffects.die_charm_target_mult_at(j, i, dice, charm_ids, participating)
			if cb != 0 or cm != 0:
				charm_base_once += cb
				charm_mult_once += cm
				die_charm_indices.append(j)
		for j in charm_ids.size():
			var cx := CharmEffects.die_charm_crit_at(j, i, dice, charm_ids, participating)
			if cx != 1:
				crit_once *= cx
				crit_charm_indices.append(j)
		var activations: Array[Dictionary] = []
		for _a in count:
			base += eye + once_base
			mult += once_mult
			var entry := {
				"base_add": eye + once_base, "mult_add": once_mult,
				"base_after": base, "mult_after": mult,
				"charm_base_add": charm_base_once, "charm_mult_add": charm_mult_once,
			}
			base += charm_base_once
			mult += charm_mult_once
			entry["charm_base_after"] = base
			entry["charm_mult_after"] = mult
			entry["crit_x"] = crit_once
			entry["crit_from_die"] = mat_crit != 1
			mult *= crit_once
			entry["mult_after_crit"] = mult
			activations.append(entry)
		# Leiterbahn-Glieder: nach allen Aktivierungen, je Glied EINMAL wie eine
		# Aktivierung mit getauschter Seite - exakt DiceScoring._base_and_mult.
		var edge_here: String = edge_materials[i] if i < edge_materials.size() else ""
		var links: Array[Dictionary] = []
		for link in DiceScoring.pointer_links_for(ctx, i):
			var link_value := CharmEffects.transform_value(int(link["value"]), charm_ids)
			var link_material := String(link["material"])
			var link_upgraded := bool(link.get("upgraded", false))
			var link_eye := CharmEffects.eye_value(link_value, charm_ids)
			var link_base_once := 0
			var link_mult_once := 0
			var link_mat_crit := 1
			if has_die_bonus:
				link_base_once = MaterialEffects.base_once_for(link_material, edge_here, charm_ids, link_upgraded, eye_sum)
				link_mult_once = MaterialEffects.mult_once_for(link_material, edge_here, link_value, charm_ids, link_upgraded)
				link_mat_crit = MaterialEffects.mult_crit_once_for(link_material, link_value, charm_ids, link_upgraded)
			var link_charm_base := 0
			var link_charm_mult := 0
			var link_charm_indices: Array[int] = []
			var link_crit := link_mat_crit
			var link_crit_indices: Array[int] = []
			if has_die_bonus:
				for j in charm_ids.size():
					var lb := CharmEffects.die_charm_base_at(j, i, key, dice, charm_ids, ctx, edge_materials, eye_slots)
					var lm := CharmEffects.die_charm_mult_at(j, i, dice, charm_ids, ctx, link_value) \
						+ CharmEffects.die_charm_target_mult_at(j, i, dice, charm_ids, participating, link_value)
					if lb != 0 or lm != 0:
						link_charm_base += lb
						link_charm_mult += lm
						link_charm_indices.append(j)
				for j in charm_ids.size():
					var lx := CharmEffects.die_charm_crit_at(j, i, dice, charm_ids, participating, link_value)
					if lx != 1:
						link_crit *= lx
						link_crit_indices.append(j)
			base += link_eye + link_base_once
			mult += link_mult_once
			var link_entry := {
				"face": int(link["face"]), "material": link_material,
				"base_add": link_eye + link_base_once, "mult_add": link_mult_once,
				"base_after": base, "mult_after": mult,
				"charm_base_add": link_charm_base, "charm_mult_add": link_charm_mult,
				"die_charm_indices": link_charm_indices,
				"crit_charm_indices": link_crit_indices,
			}
			base += link_charm_base
			mult += link_charm_mult
			link_entry["charm_base_after"] = base
			link_entry["charm_mult_after"] = mult
			link_entry["crit_x"] = link_crit
			link_entry["crit_from_die"] = link_mat_crit != 1
			mult *= link_crit
			link_entry["mult_after_crit"] = mult
			links.append(link_entry)
		die_steps.append({
			"slot": i,
			"eye_add": eye,
			"mat_base_add": once_base,
			"mat_mult_add": once_mult,
			"charm_base_add": charm_base_once,
			"charm_mult_add": charm_mult_once,
			"crit_x": crit_once,
			"die_charm_indices": die_charm_indices,
			"crit_charm_indices": crit_charm_indices,
			"base_after": base,
			"mult_after": mult,
			"eye_charm_indices": _eye_charm_indices(raw[i], charm_ids),
			"activations": activations,
			"links": links,
		})

	# 3. Statische Charm-Schritte strikt in Besitz-Reihenfolge: additive Boni
	# UND Faktoren der Position j wirken an ihrer Position - nie gesammelt am Ende.
	var charm_steps: Array[Dictionary] = []
	for j in charm_ids.size():
		var base_add := CharmEffects.charm_base_bonus_at(j, key, dice, participating, charm_ids, ctx)
		var mult_add := CharmEffects.mult_bonus_at(j, key, charm_ids) \
			+ CharmEffects.charm_mult_bonus_at(j, key, dice, materials, charm_ids, ctx, participating)
		var base_x := CharmEffects.charm_base_factor_at(j, dice, charm_ids, ctx)
		# Krit: eigener Hook, wirkt im Schritt als Teil des Mult-Faktors;
		# crit_x bleibt separat sichtbar, damit die UI Krits inszenieren kann.
		var crit_x := CharmEffects.charm_crit_at(j, dice, charm_ids, ctx, participating)
		var mult_x := CharmEffects.charm_mult_factor_at(j, dice, charm_ids, ctx) * crit_x
		# Rampenlicht wertet nicht, braucht aber seinen Schritt: es hebt die
		# Kombination an SEINER Dock-Position, nicht nach dem Zählen.
		var spotlight := CharmEffects.spotlight_fires_at(j, key, charm_ids, ctx)
		if base_add == 0 and mult_add == 0 and base_x == 1 and mult_x == 1 and not spotlight:
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
			"spotlight": spotlight,
		}
		# Hand-Charms mit Würfel-Bezug (Schlangenaugen, Zwillingsring) fächern
		# ihren Beitrag in Einzel-Pulse auf, damit die Animation je Würfel einen
		# Meteor schickt - aber nur, wenn die Pulse-Summe den Beitrag exakt
		# trifft (sonst Rückfall auf einen Meteor, nie falsche Zahlen).
		var pulses := _per_die_pulses(charm_ids[j], key, dice, participating)
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
## (Zwillingsring) - würfelgebundene Charms feuern in den Würfel-Schritten. Leer
## für alle anderen; der Aufrufer prüft zusätzlich, dass die Pulse-Summe passt.
static func _per_die_pulses(charm_id: String, key: String, dice: Array[int], participating: Array[int]) -> Array[Dictionary]:
	var pulses: Array[Dictionary] = []
	match charm_id:
		Charm.SNAKE_EYES:
			if key == DiceScoring.TWO_KIND and CharmEffects._participating_are_ones(dice, participating):
				for i in dice.size():
					if not participating.has(i):
						pulses.append({"slot": i, "base": 0, "mult": dice[i]})
		Charm.TWIN_RING:
			for slot in CharmEffects.twin_pair_slots(dice):
				pulses.append({"slot": slot, "base": 0, "mult": dice[slot]})
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
