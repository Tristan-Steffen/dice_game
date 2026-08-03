class_name ScoreBreakdown
## Zerlegt die Wertung einer Hand in eine geordnete Schrittliste für die
## Zähl-Animation. Die Schritte spiegeln exakt die Formel und TRIGGER-
## REIHENFOLGE von DiceScoring.score_category: Würfel in Reihen-Ordnung
## (trigger_order), je Zündung Augen -> Material -> würfelgebundene
## Charms (additiv, dann Krits); danach statische Charms strikt in Besitz-
## Reihenfolge, nach dem Verschmelzen die Gesamtzahl-Effekte. Jeder Schritt
## trägt Zwischenstände, damit die Anzeige nie von der Rechnung abweicht.

## Baut die Schrittliste - Parameter wie DiceScoring.score_category.
## Ergebnis: key, participating, eye_slots, combo, die_steps, charm_steps,
## base, mult, merge_total, post_steps, total (== score_category).
## Jeder Würfel-Schritt spielt seine "die_triggers" nacheinander (auch bei nur
## einem): je Gruppe erst die "firings" der Seiten-Achse, dann die "links" der
## für diesen Trigger gezündeten Leiterbahn; die deterministischen
## "essence_links" folgen ganz zuletzt. Ein Puls ist Würfel-Puls -> Charm-Anteil
## -> Krit-Schläge, mit After-Ständen je Teilschritt; "crit_steps" listet JEDEN
## Krit einzeln (Material, Essenz, dann je Charm-Position), damit zwei Kopien auch
## zweimal einschlagen - "crit_x" bleibt ihr Produkt. Je Zündung trägt der
## Eintrag "value" (die gezählte Augenzahl) und "value_after" (der physische
## Wert danach) - daraus schaltet die Grubenanimation die Ziffer um.
static func build(key: String, dice: Array[int], charm_ids: Array[String] = [], is_first_hand: bool = false, materials: Array[String] = [], combo_levels: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	# Verwandlung zuerst - wie in DiceScoring; raw bleibt für die Charm-Zuordnung.
	var raw := dice
	dice = DiceScoring.shown_values(dice, charm_ids, ctx)
	# Derselbe Vorspann wie in DiceScoring._base_and_mult - eine Quelle, sonst
	# zeigt die Animation einen Würfel, den die Wertung übersprungen hat.
	var shape := DiceScoring.hand_shape(key, raw, charm_ids, ctx)
	var participating: Array[int] = shape["participating"]
	var scored: Array[int] = shape["scored"]
	var essences := DiceScoring.essence_sets_in(ctx)
	var rifts := DiceScoring.rifts_in(ctx)
	var is_stress := bool(ctx.get(DiceScoring.CTX_STRESS, false))
	# Reihen-Ordnung = die aufgereihte Reihe (wertungsrelevant wegen Beherit).
	var eye_slots: Array[int] = shape["order"]
	var has_die_bonus := not materials.is_empty() or not charm_ids.is_empty() \
		or not essences.is_empty() or not rifts.is_empty()
	# Krits dieser Hand, laufend gezählt - wie in DiceScoring._base_and_mult
	# (Ozon wächst mit ihnen, Grubengas bucht an jedem sofort). Beide Zähler
	# starten beim Rundenstand, wenn Gewitterfront bzw. Dunkelkammer stehen.
	var crit_offset := EssenceEffects.round_crit_offset(charm_ids, int(ctx.get(DiceScoring.CTX_ROUND_CRITS, 0)))
	var trigger_offset := EssenceEffects.round_trigger_offset(charm_ids, int(ctx.get(DiceScoring.CTX_ROUND_TRIGGERS, 0)))
	var crits := crit_offset
	var firedamp := EssenceEffects.firedamp_step(scored, essences)
	# Laufender Auslösungszähler der Hand (Glieder zählen mit) - Photonengas.
	var triggers := trigger_offset
	var ball_bonus := EssenceEffects.ball_crit_bonus(scored, essences, charm_ids)
	var wild := DiceScoring.wild_slot(ctx) if charm_ids.has(Charm.POLARIZER) else -1
	var wild_eyes := DiceScoring.wild_value(key, dice, ctx) if wild >= 0 else 0

	# 1. Kombination: feste Punkte + Kategorie-Mult (inkl. Menü-Stufen), beides
	# vom Doppelten Boden verdoppelt - wie in DiceScoring._base_and_mult.
	var combo_factor := CharmEffects.combo_factor(charm_ids)
	var base := DiceScoring.points_for(key, combo_levels) * combo_factor
	var combo_mult := DiceScoring.mult_for(key, combo_levels) * combo_factor
	var mult := float(combo_mult)
	var combo := {"base_add": base, "mult_add": combo_mult}
	# Wasserfall: die zuletzt AUSLÖSENDE Augenzahl, über die ganze Hand fortgeschrieben.
	var cascade_last := CharmEffects.CASCADE_UNSET

	# 2. Würfel-Schritte in Reihen-Ordnung. Je Aktivierung: Augen + Material,
	# dann die würfelgebundenen Charms (additiv, dann Krits) - exakt die
	# Reihenfolge von DiceScoring._base_and_mult.
	var die_steps: Array[Dictionary] = []
	# Echo-Kammer: aus der GANZEN Wertung bestimmt, nicht aus dem Einzel-Slot unten.
	var echo_slot: int = shape["echo_slot"]
	for i in eye_slots:
		var info := DiceScoring.level_info_for(ctx, i)
		var level := MaterialEffects.level_in(info)
		var eye_sum := int(info.get("eye_sum", 0))
		var face_material: String = materials[i] if i < materials.size() else ""
		var essence_ids := EssenceEffects.set_at(essences, i)
		var rift_ids := RiftEffects.rifts_at(rifts, i)
		# Phosphoreszenz kippt ihren Speicher als eigenen Basis-Eintrag aus - mit
		# Leuchtstoffröhre dazu den gespeicherten Mult.
		var phosphor := DiceScoring.phosphor_store_for(ctx, i)
		var phosphor_mult := DiceScoring.phosphor_mult_for(ctx, i)
		base += phosphor
		mult += phosphor_mult
		# Stand NACH der Auszahlung: gespeichert wird nur, was der Würfel in DIESEM
		# Zug selbst erarbeitet - der Speicher zahlt sich nie selbst nach.
		var base_before_die := base
		# Der Mult-Speicher zählt AUSSCHLIESSLICH, was dieser Würfel additiv
		# beisteuert (Material, Essenz, würfelgebundene Charms - auch an seinen
		# Gliedern). Ein Krit vervielfacht den laufenden Mult der ganzen Hand und
		# gehört darum NICHT dazu, sonst speicherte der Würfel fremde Arbeit.
		var mult_earned := 0.0
		# Die beiden Achsen wie in DiceScoring: der Würfel tritt die_count-mal an,
		# je Antritt zündet die obere Seite face_count-mal.
		var die_count := 1
		var face_count := 1
		var once_base := 0
		if has_die_bonus:
			die_count = MaterialEffects.die_trigger_count(i, charm_ids, echo_slot, essence_ids, is_stress,
				EssenceEffects.extra_activations(i, eye_slots, essences, charm_ids), eye_slots.size())
			face_count = MaterialEffects.face_trigger_count(dice[i], charm_ids, RiftEffects.extra_activations(rift_ids))
			once_base = MaterialEffects.base_bonus_once(i, materials, charm_ids, level, eye_sum)
		# Würfelgebundene Charms dieses Slots: Betrag JE Zündung, weil der laufende
		# Wert ihn trägt. Die Kopfzeile des Schritts nennt die erste Zündung.
		var charm_base_once := 0
		var charm_mult_once := 0
		var die_charm_indices: Array[int] = []
		var crit_charm_indices: Array[int] = []
		# LAUFENDER Wert wie in DiceScoring._base_and_mult: Knochen/Glas wandeln den
		# PHYSISCHEN Wert (raw) ZWISCHEN den Zündungen, die Verwandlung liegt als
		# Linse darüber. Augen, Mult-Material und Material-Krit rechnen je Zündung
		# neu, alles andere bleibt. Die Kopfzeile trägt die ERSTE Zündung.
		var running: int = raw[i] if i < raw.size() else dice[i]
		var eye := EssenceEffects.eye_value_of(essence_ids, CharmEffects.eye_value(dice[i], charm_ids), charm_ids)
		var once_mult := 0
		var step_crit := 1.0
		var first_firing := true
		# Gruppen der WÜRFEL-Achse: je Trigger seine Seiten-Zündungen und die für
		# ihn gewürfelte Leiterbahn. Ein Durchgang mehr - der letzte trägt nur die
		# deterministischen Essenz-Glieder (Röntgenlicht, Korona).
		var groups: Array[Dictionary] = []
		var essence_links: Array[Dictionary] = []
		for t in die_count + 1:
			var firings: Array[Dictionary] = []
			for _f in (face_count if t < die_count else 0):
				var shown := DiceScoring.shown_value(running, charm_ids, essence_ids)
				var eye_now := EssenceEffects.eye_value_of(essence_ids, CharmEffects.eye_value(shown, charm_ids), charm_ids) \
					+ EssenceEffects.foreign_eye_bonus(i, scored, essences, charm_ids) \
					+ EssenceEffects.trigger_eye_bonus_of(essence_ids, triggers)
				triggers += 1
				var mult_now := 0
				# Material-Krit (Rubin III, Glas ab II): zählt in crit_x mit, bekommt aber
				# keinen Charm-Index - er kommt vom Würfel, nicht von einem Dock-Pad.
				var mat_crit_now := 1.0
				if has_die_bonus:
					mult_now = MaterialEffects.mult_once_for(face_material, shown, charm_ids, level) \
						+ EssenceEffects.mult_bonus_of(essence_ids)
					mat_crit_now = MaterialEffects.mult_crit_once_for(face_material, shown, charm_ids, level)
				# Der Betrag der würfelgebundenen Charms folgt dem laufenden Wert;
				# gezielt wird weiter über die liegenden.
				var charm_base_now := 0
				var charm_mult_now := 0
				var charm_indices_now: Array[int] = []
				for j in charm_ids.size():
					var cb := CharmEffects.die_charm_base_at(j, i, key, dice, charm_ids, ctx, eye_slots, shown)
					var cm := CharmEffects.die_charm_mult_at(j, i, dice, charm_ids, ctx, shown)
					cm += CharmEffects.die_charm_target_mult_at(j, i, dice, charm_ids, participating, shown)
					if cb != 0 or cm != 0:
						charm_base_now += cb
						charm_mult_now += cm
						charm_indices_now.append(j)
				# Wasserfall hängt an der ganzen Hand, nicht am Würfel - sein Anteil
				# reist trotzdem im Charm-Anteil dieser Zündung, damit sein Pad blitzt.
				var cascade_add := CharmEffects.cascade_mult(shown, cascade_last, charm_ids)
				if cascade_add > 0:
					charm_mult_now += cascade_add
					cascade_last = shown
					_merge_indices(charm_indices_now, CharmEffects.charm_indices_of(Charm.WATERFALL, charm_ids))
				if first_firing:
					eye = eye_now
					once_mult = mult_now
					charm_base_once = charm_base_now
					charm_mult_once = charm_mult_now
					die_charm_indices = charm_indices_now
				base += eye_now + once_base
				mult += float(mult_now)
				mult_earned += float(mult_now) + float(charm_mult_now)
				var entry := {
					"value": shown,
					"base_add": eye_now + once_base, "mult_add": mult_now,
					"base_after": base, "mult_after": mult,
					"charm_base_add": charm_base_now, "charm_mult_add": charm_mult_now,
					"die_charm_indices": charm_indices_now,
				}
				base += charm_base_now
				mult += float(charm_mult_now)
				entry["charm_base_after"] = base
				entry["charm_mult_after"] = mult
				# JEDER Krit ein eigener Schlag - Material, Essenz, dann jede Charm-
				# Position einzeln. Zwei Beherit-Kopien schlagen zweimal, nie einmal
				# mit ihrem Produkt. Grubengas zündet MIT dem Krit, an dessen Stelle.
				var crit_steps: Array[Dictionary] = []
				var crit_once := 1.0
				var firedamp_add := 0
				if not is_equal_approx(mat_crit_now, 1.0):
					crits += 1
					base += firedamp
					firedamp_add += firedamp
					mult *= mat_crit_now
					crit_once *= mat_crit_now
					crit_steps.append(_crit_step(mat_crit_now, -1, firedamp, base, mult))
				# Essenz-Krit in derselben Substufe; Ozon liest die Krits VOR sich.
				var essence_crit := EssenceEffects.crit_of(essence_ids, shown, crits, ball_bonus,
					wild_eyes if i == wild else 0)
				if not is_equal_approx(essence_crit, 1.0):
					crits += 1
					base += firedamp
					firedamp_add += firedamp
					mult *= essence_crit
					crit_once *= essence_crit
					crit_steps.append(_crit_step(essence_crit, -1, firedamp, base, mult))
				var crit_indices_now: Array[int] = []
				for j in charm_ids.size():
					var cx := CharmEffects.die_charm_crit_at(j, i, dice, charm_ids, participating, shown)
					if is_equal_approx(cx, 1.0):
						continue
					crits += 1
					base += firedamp
					firedamp_add += firedamp
					mult *= cx
					crit_once *= cx
					crit_indices_now.append(j)
					crit_steps.append(_crit_step(cx, j, firedamp, base, mult))
				if first_firing:
					step_crit = crit_once
					crit_charm_indices = crit_indices_now
					first_firing = false
				entry["crit_steps"] = crit_steps
				entry["crit_charm_indices"] = crit_indices_now
				entry["crit_x"] = crit_once
				entry["crit_from_die"] = not is_equal_approx(mat_crit_now, 1.0)
				entry["firedamp_add"] = firedamp_add
				entry["base_after_crit"] = base
				entry["mult_after_crit"] = mult
				if has_die_bonus:
					running = MaterialEffects.mutate_value_once(running, face_material, charm_ids, level, essence_ids, rift_ids)
				# Physischer Wert NACH dieser Zündung: die Zahl auf dem Würfel wandert
				# mit (dauerhafte Änderung, also normal gefärbt - kein Vorschau-Grün).
				entry["value_after"] = running
				firings.append(entry)
			# Glieder feuern EINMAL wie eine Zündung mit getauschter Seite - exakt
			# DiceScoring._base_and_mult.
			var links: Array[Dictionary] = []
			for link in (DiceScoring.pointer_fires_at(ctx, i, t) if t < die_count else DiceScoring.essence_links_for(ctx, i)):
				var link_value := CharmEffects.transform_value(int(link["value"]), charm_ids)
				var link_material := String(link["material"])
				var link_level := int(link.get("level", 1))
				var link_eye := CharmEffects.eye_value(link_value, charm_ids)
				triggers += 1
				var link_base_once := 0
				var link_mult_once := 0
				var link_mat_crit := 1.0
				if has_die_bonus:
					link_base_once = MaterialEffects.base_once_for(link_material, charm_ids, link_level, eye_sum)
					link_mult_once = MaterialEffects.mult_once_for(link_material, link_value, charm_ids, link_level)
					link_mat_crit = MaterialEffects.mult_crit_once_for(link_material, link_value, charm_ids, link_level)
				var link_charm_base := 0
				var link_charm_mult := 0
				var link_charm_indices: Array[int] = []
				if has_die_bonus:
					for j in charm_ids.size():
						var lb := CharmEffects.die_charm_base_at(j, i, key, dice, charm_ids, ctx, eye_slots, link_value)
						var lm := CharmEffects.die_charm_mult_at(j, i, dice, charm_ids, ctx, link_value)
						lm += CharmEffects.die_charm_target_mult_at(j, i, dice, charm_ids, participating, link_value)
						if lb != 0 or lm != 0:
							link_charm_base += lb
							link_charm_mult += lm
							link_charm_indices.append(j)
				var link_cascade := CharmEffects.cascade_mult(link_value, cascade_last, charm_ids)
				if link_cascade > 0:
					link_charm_mult += link_cascade
					cascade_last = link_value
					_merge_indices(link_charm_indices, CharmEffects.charm_indices_of(Charm.WATERFALL, charm_ids))
				base += link_eye + link_base_once
				mult += float(link_mult_once)
				mult_earned += float(link_mult_once) + float(link_charm_mult)
				var link_entry := {
					"face": int(link["face"]), "material": link_material,
					"base_add": link_eye + link_base_once, "mult_add": link_mult_once,
					"base_after": base, "mult_after": mult,
					"charm_base_add": link_charm_base, "charm_mult_add": link_charm_mult,
					"die_charm_indices": link_charm_indices,
				}
				base += link_charm_base
				mult += float(link_charm_mult)
				link_entry["charm_base_after"] = base
				link_entry["charm_mult_after"] = mult
				# Krits einzeln wie bei einer Zündung: erst das Material des Glieds,
				# dann jede Charm-Position für sich. Essenz-Krits gehören der oberen
				# Seite und fehlen hier.
				var link_crit_steps: Array[Dictionary] = []
				var link_crit := 1.0
				var link_firedamp := 0
				if not is_equal_approx(link_mat_crit, 1.0):
					crits += 1
					base += firedamp
					link_firedamp += firedamp
					mult *= link_mat_crit
					link_crit *= link_mat_crit
					link_crit_steps.append(_crit_step(link_mat_crit, -1, firedamp, base, mult))
				var link_crit_indices: Array[int] = []
				if has_die_bonus:
					for j in charm_ids.size():
						var lx := CharmEffects.die_charm_crit_at(j, i, dice, charm_ids, participating, link_value)
						if is_equal_approx(lx, 1.0):
							continue
						crits += 1
						base += firedamp
						link_firedamp += firedamp
						mult *= lx
						link_crit *= lx
						link_crit_indices.append(j)
						link_crit_steps.append(_crit_step(lx, j, firedamp, base, mult))
				link_entry["crit_steps"] = link_crit_steps
				link_entry["crit_charm_indices"] = link_crit_indices
				link_entry["crit_x"] = link_crit
				link_entry["crit_from_die"] = not is_equal_approx(link_mat_crit, 1.0)
				link_entry["firedamp_add"] = link_firedamp
				link_entry["base_after_crit"] = base
				link_entry["mult_after_crit"] = mult
				links.append(link_entry)
			if t < die_count:
				groups.append({"firings": firings, "links": links})
			else:
				essence_links = links
		die_steps.append({
			"slot": i,
			"phosphor_add": phosphor,
			"phosphor_mult_add": phosphor_mult,
			"base_contribution": base - base_before_die,
			"mult_contribution": mult_earned,
			"eye_add": eye,
			"mat_base_add": once_base,
			"mat_mult_add": once_mult,
			"charm_base_add": charm_base_once,
			"charm_mult_add": charm_mult_once,
			"crit_x": step_crit,
			"die_charm_indices": die_charm_indices,
			"crit_charm_indices": crit_charm_indices,
			"base_after": base,
			"mult_after": mult,
			"eye_charm_indices": _eye_charm_indices(raw[i], charm_ids),
			"die_triggers": groups,
			"essence_links": essence_links,
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
		var firedamp_add := 0
		if not is_equal_approx(crit_x, 1.0):
			crits += 1
			firedamp_add = firedamp
		var mult_x := float(CharmEffects.charm_mult_factor_at(j, dice, charm_ids, ctx)) * crit_x
		# Rampenlicht wertet nicht, braucht aber seinen Schritt: es hebt die
		# Kombination an SEINER Dock-Position, nicht nach dem Zählen.
		var spotlight := CharmEffects.spotlight_fires_at(j, key, charm_ids, ctx)
		if base_add == 0 and mult_add == 0 and base_x == 1 and is_equal_approx(mult_x, 1.0) and not spotlight:
			continue
		var base_before := base
		var mult_before := mult
		# Reihenfolge wie in DiceScoring: erst der Basis-Faktor, DANN der
		# Grubengas-Zuschlag des Krits - sonst vervielfachte ihn der eigene Charm.
		base = (base + base_add) * base_x + firedamp_add
		mult = (mult + mult_add) * mult_x
		var step_indices: Array[int] = [j]
		var step := {
			"charm_indices": step_indices,
			"base_add": base_add, "mult_add": mult_add,
			"base_x": base_x, "mult_x": mult_x, "crit_x": crit_x,
			"firedamp_add": firedamp_add,
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
			if sum_base == base_add and sum_mult == mult_add and base_x == 1 and is_equal_approx(mult_x, 1.0):
				var acc_base := base_before
				var acc_mult := mult_before
				for p in pulses:
					acc_base += int(p["base"])
					acc_mult += float(p["mult"])
					p["base_after"] = acc_base
					p["mult_after"] = acc_mult
				step["pulses"] = pulses
		charm_steps.append(step)

	# 4. Verschmelzen: base × mult, die EINZIGE Rundung der Rechnung (aufgerundet).
	# Antimaterie kann die Basis negativ machen - geklemmt wie in DiceScoring.
	base = maxi(0, base)
	mult = maxf(1.0, mult)
	var total := ceili(float(base) * mult)
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
	var expected := DiceScoring.score_category(key, raw, charm_ids, is_first_hand, materials, combo_levels, ctx)
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
		# Was diese Hand an Auslösungen und Krits gebracht hat (ohne den Vorlauf der
		# Runde): GameRun schreibt beides fort, Dunkelkammer und Gewitterfront lesen
		# es in der nächsten Hand als Startstand.
		"triggers": triggers - trigger_offset,
		"crits": crits - crit_offset,
	}

## Nimmt Besitz-Positionen in eine bestehende Liste auf und hält sie dock-sortiert.
static func _merge_indices(into: Array[int], extra: Array[int]) -> void:
	for j in extra:
		if not into.has(j):
			into.append(j)
	into.sort()

## Ein einzelner Krit-Schlag einer Zündung. charm_index < 0 = der Schlag kommt vom
## Würfel selbst (Material, Essenz) und hat kein Dock-Pad, aus dem er fliegen könnte.
static func _crit_step(crit_x: float, charm_index: int, firedamp_add: int, base_after: int, mult_after: float) -> Dictionary:
	var indices: Array[int] = []
	if charm_index >= 0:
		indices.append(charm_index)
	return {
		"crit_x": crit_x,
		"charm_indices": indices,
		"from_die": charm_index < 0,
		"firedamp_add": firedamp_add,
		"base_after": base_after,
		"mult_after": mult_after,
	}

## EINE Formatregel für jede gedruckte Mult-Zahl, seit Krits Bruchzahlen sein
## dürfen: höchstens zwei Nachkommastellen, nachlaufende Nullen und das ".0"
## fallen weg ("2", "1.5", "2.25").
static func format_number(value: float) -> String:
	var text := "%.2f" % value
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text

static func format_mult(value: float) -> String:
	return "×%s" % format_number(value)

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
	return CharmEffects.eye_value(CharmEffects.shown_by_charms(value, charm_ids), charm_ids)
