class_name DiceScoring
## Reine Wertungslogik (Balatro-artig): Punkte = Basiswert × Multiplikator.
## Basiswert = feste Kategorie-Punkte + beteiligte Würfelaugen. Verwandlungs-
## Charms (CharmEffects.transform_values) ändern die Augen VOR der Erkennung -
## eine verwandelte 1 IST eine 6, auch für die Kategorie. Alle anderen Charms,
## Materialien und Menü-Stufen verändern nur die Wertung.

# Kategorie-Keys als Konstanten: ein Tippfehler wird Compilerfehler statt
# einer still nie zutreffenden Kategorie.
const ONE_KIND := "one_kind"
const TWO_KIND := "two_kind"
const TWO_PAIR := "two_pair"
const THREE_KIND := "three_kind"
const SMALL_STRAIGHT := "small_straight"
const FOUR_KIND := "four_kind"
const FULL_HOUSE := "full_house"
const THREE_PAIRS := "three_pairs"
const DOUBLE_THREE_KIND := "double_three_kind"
const FOUR_KIND_AND_PAIR := "four_kind_and_pair"
const LARGE_STRAIGHT := "large_straight"
const FIVE_KIND := "five_kind"
const SIX_KIND := "six_kind"

const CATEGORIES := [
	{"key": ONE_KIND, "label": "Höchste Zahl", "mult": 1, "points": 5},
	{"key": TWO_KIND, "label": "Paar", "mult": 2, "points": 10},
	{"key": TWO_PAIR, "label": "Zwei Paare", "mult": 3, "points": 15},
	{"key": THREE_KIND, "label": "Dreierpasch", "mult": 3, "points": 18},
	{"key": SMALL_STRAIGHT, "label": "Kleine Straße", "mult": 4, "points": 22},
	{"key": FOUR_KIND, "label": "Viererpasch", "mult": 4, "points": 25},
	{"key": FULL_HOUSE, "label": "Full House", "mult": 4, "points": 28},
	{"key": THREE_PAIRS, "label": "Drei Zweierpäsche", "mult": 5, "points": 32},
	{"key": DOUBLE_THREE_KIND, "label": "Doppelter Dreierpasch", "mult": 5, "points": 36},
	{"key": FOUR_KIND_AND_PAIR, "label": "Viererpasch mit Paar", "mult": 6, "points": 40},
	{"key": LARGE_STRAIGHT, "label": "Große Straße", "mult": 8, "points": 45},
	{"key": FIVE_KIND, "label": "5 of a Kind", "mult": 10, "points": 50},
	{"key": SIX_KIND, "label": "Sechserpasch", "mult": 15, "points": 60},
]

# Prestigeträchtigste zuerst: best_hand() nimmt den ERSTEN Treffer dieser Liste,
# ohne Punktvergleich. So stehen spezifischere Häuser (3+3, 4+2) vor Full
# House/Zwei Paare, die sie sonst mit abdecken würden.
const HAND_PRIORITY := [
	SIX_KIND, FIVE_KIND, LARGE_STRAIGHT, FOUR_KIND_AND_PAIR, DOUBLE_THREE_KIND,
	THREE_PAIRS, FOUR_KIND, FULL_HOUSE, SMALL_STRAIGHT, THREE_KIND, TWO_PAIR, TWO_KIND, ONE_KIND,
]

## Drossel (ctx-Schlüssel): Array der gedrosselten Kategorien - sie werten 0,
## best_hand fällt auf die nächstbeste zutreffende zurück. Mehrzahl, weil Boss-
## Konditionen (Allrounder, Standardprotokoll) die Liste wachsen lassen.
const CTX_THROTTLED := "throttled"

## Ob eine Kategorie in diesem Wurf gedrosselt ist.
static func is_throttled(key: String, ctx: Dictionary) -> bool:
	var throttled: Array = ctx.get(CTX_THROTTLED, [])
	return throttled.has(key)

## Paritäts-Filter (ctx-Schlüssel): die Boss-Konditionen Schieflage/Gleichgewicht
## lassen nur ungerade bzw. gerade Augen an einer Kombination teilnehmen. Der
## Filter greift VOR der Erkennung - ausgeschlossene Würfel bilden keine Gruppe,
## keine Straße und keine "Höchste Zahl", ein Wurf ohne legale Würfel farkelt.
const CTX_PARITY := "parity"
const PARITY_ANY := 0
const PARITY_ODD := 1
const PARITY_EVEN := 2

## Slots, die unter dem Paritäts-Filter überhaupt werten dürfen. Krypton
## übersieht der Filter - Essenzen sperren keine Kategorien, aber sie können
## einen Würfel aus einer WÜRFEL-Sperre herausnehmen.
static func legal_indices(dice: Array[int], ctx: Dictionary) -> Array[int]:
	var legal: Array[int] = []
	var parity := int(ctx.get(CTX_PARITY, PARITY_ANY))
	var essences := essence_sets_in(ctx)
	for i in dice.size():
		if parity == PARITY_ANY or (absi(dice[i]) % 2 == 1) == (parity == PARITY_ODD) \
				or EssenceEffects.ignores_dice_filters_of(EssenceEffects.set_at(essences, i)):
			legal.append(i)
	return legal

## Die legalen Würfel als eigene Liste - qualifies/participating rechnen darauf
## und der Aufrufer bildet die Indizes über legal_indices zurück.
static func _legal_dice(dice: Array[int], legal: Array[int]) -> Array[int]:
	var sub: Array[int] = []
	for i in legal:
		sub.append(dice[i])
	return sub

## Leiterbahn-Ketten (ctx-Schlüssel): Dictionary Slot -> Glieder-Liste, je Glied
## {"face": int, "value": int (rohe Augen), "material": String, "level": int}.
## Der Aufrufer löst die Kette EINMAL auf (scene_root kennt Defs + obere Seiten) -
## so sehen Vorschau, Nehmen und Farkle-Vergleich dieselben Glieder.
const CTX_POINTER_LINKS := "pointer_links"

## Glieder des Slots aus dem ctx ([] = keine Kette).
static func pointer_links_for(ctx: Dictionary, slot: int) -> Array:
	var links: Dictionary = ctx.get(CTX_POINTER_LINKS, {})
	return links.get(slot, [])

## Material-Stufen (ctx-Schlüssel): Dictionary Slot -> {"level": int (Sättigung
## des Materials der OBEREN Seite), "eye_sum": int}. Wie die Leiterbahn-Ketten
## löst der Aufrufer das EINMAL auf.
const CTX_MATERIAL_LEVELS := "material_levels"

## Stufen-Infos des Slots aus dem ctx ({} = Stufe I, siehe MaterialEffects.level_in).
static func level_info_for(ctx: Dictionary, slot: int) -> Dictionary:
	var levels: Dictionary = ctx.get(CTX_MATERIAL_LEVELS, {})
	return levels.get(slot, {})

## Essenzen (ctx-Schlüssel): Dictionary Slot -> Essenz-id ("" = keine). Wie die
## Leiterbahn-Ketten löst der Aufrufer das EINMAL auf, damit Vorschau, Nehmen
## und Farkle-Vergleich dieselben Würfel beseelt sehen.
const CTX_ESSENCES := "essences"

## Bedingte Essenz-Krits (ctx-Schlüssel): Dictionary Slot -> bool. Xenon (erstes
## Werten der Runde noch frei) und Kugelblitz (die getroffene Seite liegt oben)
## sind Rundenzustand - den kennt nur GameRun, also kommt er fertig im ctx an.
const CTX_ESSENCE_ARMED := "essence_armed"

## Wirksame Essenz-Mengen (ctx-Schluessel): Slot -> Array der Essenz-ids, die an
## diesem Wuerfel WIRKEN. Normal genau die eigene; die Quintessenz borgt sich die
## der anderen liegenden Wuerfel dazu (siehe EssenceEffects.effective_sets).
const CTX_ESSENCE_SET := "essence_sets"

## Stresstest-Flagge (ctx-Schlüssel): das Elmsfeuer glüht dort vierfach.
const CTX_STRESS := "stress_round"

## Rifts (ctx-Schlüssel): Dictionary Slot -> Liste der Rift-ids auf der OBEN
## liegenden Seite. Wie die Leiterbahn-Ketten löst der Aufrufer das EINMAL auf;
## das Nachglühen ändert Auslösungen, also braucht auch der Farkle-Vergleich die
## alten Risse.
const CTX_RIFTS := "rifts"

static func rifts_in(ctx: Dictionary) -> Dictionary:
	return ctx.get(CTX_RIFTS, {})

static func rifts_for(ctx: Dictionary, slot: int) -> Array[String]:
	return RiftEffects.rifts_at(rifts_in(ctx), slot)

static func essences_in(ctx: Dictionary) -> Dictionary:
	return ctx.get(CTX_ESSENCES, {})

## Wirksame Essenz-MENGEN je Slot (die Quintessenz borgt sich fremde Seelen).
## Fehlt der Schluessel, wird er aus CTX_ESSENCES abgeleitet - so bleiben
## Aufrufer gueltig, die nur die eigenen Essenzen mitgeben.
static func essence_sets_in(ctx: Dictionary) -> Dictionary:
	if ctx.has(CTX_ESSENCE_SET):
		return ctx[CTX_ESSENCE_SET]
	return EssenceEffects.effective_sets(essences_in(ctx))

static func essence_for(ctx: Dictionary, slot: int) -> String:
	return EssenceEffects.essence_at(essences_in(ctx), slot)

## Anzeige-Beispiele der Kombinationsliste; per Test gegen die echte Wertung
## geprüft (best_hand(Beispiel) muss genau seine Kategorie liefern).
const EXAMPLE_DICE := {
	ONE_KIND: [6],
	TWO_KIND: [6, 6],
	TWO_PAIR: [6, 6, 5, 5],
	THREE_KIND: [6, 6, 6],
	SMALL_STRAIGHT: [1, 2, 3, 4, 5],
	FOUR_KIND: [6, 6, 6, 6],
	FULL_HOUSE: [6, 6, 6, 1, 1],
	THREE_PAIRS: [6, 6, 5, 5, 4, 4],
	DOUBLE_THREE_KIND: [6, 6, 6, 5, 5, 5],
	FOUR_KIND_AND_PAIR: [6, 6, 6, 6, 1, 1],
	LARGE_STRAIGHT: [1, 2, 3, 4, 5, 6],
	FIVE_KIND: [6, 6, 6, 6, 6],
	SIX_KIND: [6, 6, 6, 6, 6, 6],
}

static func label_for(key: String) -> String:
	for cat in CATEGORIES:
		if cat["key"] == key:
			return cat["label"]
	return key

## Jede Menü-Stufe addiert den Basis-Multiplikator erneut (×2 -> ×4 -> ×6, ...).
static func mult_for(key: String, combo_levels: Dictionary = {}) -> int:
	for cat in CATEGORIES:
		if cat["key"] == key:
			return cat["mult"] * (1 + int(combo_levels.get(key, 0)))
	return 1

## Feste Basispunkte ("Chips") - skalieren mit Menü-Stufen wie mult_for.
static func points_for(key: String, combo_levels: Dictionary = {}) -> int:
	for cat in CATEGORIES:
		if cat["key"] == key:
			return cat["points"] * (1 + int(combo_levels.get(key, 0)))
	return 0

## Der Joker-Slot (Polarlicht) oder -1. Legendär und damit Unikat: es kann NIE
## mehr als einen geben, darum genügt EIN Index statt einer Liste.
static func wild_slot(ctx: Dictionary) -> int:
	var essences := essences_in(ctx)
	for slot in essences:
		if EssenceEffects.is_wild(EssenceEffects.essence_at(essences, int(slot))):
			return int(slot)
	return -1

## Position des Jokers INNERHALB der gefilterten Liste (-1, wenn er gar nicht
## mitspielt - der Paritätsfilter urteilt über seine AUFGEDRUCKTE Zahl, Sperren
## sind Kryptons Revier, nicht seines).
static func _wild_index_in(legal: Array[int], ctx: Dictionary) -> int:
	var slot := wild_slot(ctx)
	return legal.find(slot) if slot >= 0 else -1

## Trifft die Kategorie zu? Mit Joker wird jede Belegung durchprobiert - die
## Ersetzung passiert NUR hier in der Erkennung, nach dem legalen Filter.
static func qualifies(key: String, dice: Array[int], ctx: Dictionary = {}) -> bool:
	var legal := legal_indices(dice, ctx)
	var sub := dice if legal.size() == dice.size() else _legal_dice(dice, legal)
	var wild := _wild_index_in(legal, ctx)
	if wild < 0:
		return _qualifies_plain(key, sub)
	for value in range(6, 0, -1):
		var variant := sub.duplicate()
		variant[wild] = value
		if _qualifies_plain(key, variant):
			return true
	return false

static func _qualifies_plain(key: String, dice: Array[int]) -> bool:
	match key:
		SIX_KIND:
			return _has_count_at_least(dice, 6)
		FIVE_KIND:
			return _has_count_at_least(dice, 5)
		LARGE_STRAIGHT:
			return _has_straight_of_length(dice, 6)
		FOUR_KIND_AND_PAIR:
			return _has_count_and_other_count(dice, 4, 2)
		DOUBLE_THREE_KIND:
			return _has_two_groups_with_at_least(dice, 3)
		THREE_PAIRS:
			return _count_groups_with_at_least(dice, 2) >= 3
		FOUR_KIND:
			return _has_count_at_least(dice, 4)
		FULL_HOUSE:
			return _has_count_and_other_count(dice, 3, 2)
		SMALL_STRAIGHT:
			return _has_straight_of_length(dice, 5)
		THREE_KIND:
			return _has_count_at_least(dice, 3)
		TWO_PAIR:
			return _count_groups_with_at_least(dice, 2) >= 2
		TWO_KIND:
			return _has_count_at_least(dice, 2)
		ONE_KIND:
			return not dice.is_empty()  # ohne legalen Würfel zählt auch die Rückfall-Kategorie nicht
	return false

## Wertet eine Kategorie in FESTER Trigger-Reihenfolge (keine Ausnahmen):
## Würfel in Reihen-Ordnung (trigger_order; je Aktivierung Augen, Material,
## würfelgebundene Charms - Knochen/Glas wandeln den Wert zwischen den
## Aktivierungen; danach die Leiterbahn-Kette je Glied einmal), dann
## statische Charms strikt in Besitz-Reihenfolge (Boni UND Faktoren an ihrer
## Position), nach Basis × Mult die Gesamtzahl-Effekte - ebenfalls in Besitz-
## Reihenfolge. materials: DieMaterial-id je Slot ("" = keins).
## ctx: Wurf-/Runden-Zustand.
static func score_category(key: String, dice: Array[int], charm_ids: Array[String] = [], is_first_hand: bool = false, materials: Array[String] = [], combo_levels: Dictionary = {}, ctx: Dictionary = {}) -> int:
	# raw = die PHYSISCHEN Seitenwerte; nur auf ihnen läuft der Wertwandel
	# (Knochen/Glas/Helium), damit die Wertung genau dort landet, wo die Def landet.
	var raw := dice
	dice = CharmEffects.transform_values(dice, charm_ids)
	if is_throttled(key, ctx) or not qualifies(key, dice, ctx):
		return 0
	var pair := _base_and_mult(key, dice, raw, charm_ids, materials, combo_levels, ctx)
	var score: int = pair[0] * maxi(1, pair[1])
	for j in charm_ids.size():
		score *= CharmEffects.charm_total_factor_at(j, charm_ids, is_first_hand)
	return score

## Kompletter Kombi-Multiplikator - die Mult-Seite derselben Rechnung; min. 1.
## Eine Quelle für Rechnung UND Anzeige.
static func _total_mult(key: String, dice: Array[int], charm_ids: Array[String], materials: Array[String], combo_levels: Dictionary, ctx: Dictionary) -> int:
	var raw := dice
	dice = CharmEffects.transform_values(dice, charm_ids)
	return maxi(1, _base_and_mult(key, dice, raw, charm_ids, materials, combo_levels, ctx)[1])

## Zählreihenfolge der Würfelphase: die Reihe, wie sie beim Nehmen aufgereiht
## liegt - Wert absteigend, bei Gleichstand kleinster Slot zuerst. Deterministisch
## aus den Werten, damit Vorschau, Wertung und Grubenanimation identisch laufen
## (die Ordnung ist wertungsrelevant, sobald ein Krit am Würfel hängt - Beherit).
## Photonengas ist der EINZIGE Eingriff: seine Würfel bilden einen eigenen Block
## ganz vorn, in sich nach derselben Regel sortiert. Der Schlüssel bleibt damit
## kanonisch aus Werten + ctx berechnet, nie aus physischen Positionen.
static func trigger_order(scored: Array[int], dice: Array[int], essences: Dictionary = {}) -> Array[int]:
	var order := scored.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool:
		var a_first := EssenceEffects.counts_first_of(EssenceEffects.set_at(essences, a))
		var b_first := EssenceEffects.counts_first_of(EssenceEffects.set_at(essences, b))
		if a_first != b_first:
			return a_first
		return dice[a] > dice[b] or (dice[a] == dice[b] and a < b))
	return order

## Basis und Mult einer Hand in der festen Trigger-Reihenfolge (dice bereits
## verwandelt, raw = die physischen Seitenwerte). [base, mult] - mult ungeklemmt.
static func _base_and_mult(key: String, dice: Array[int], raw: Array[int], charm_ids: Array[String], materials: Array[String], combo_levels: Dictionary, ctx: Dictionary) -> Array[int]:
	var participating := participating_indices(key, dice, [], ctx)
	# Vollzähler weitet die gewertete Menge auf ALLE liegenden Würfel; sonst zählen
	# nur die beteiligten. Kombi-Charms (Blackjack & Co.) bleiben auf participating.
	var scored := CharmEffects.scored_indices(participating, dice.size(), charm_ids)
	# Auch der Vollzähler zieht keine paritätsgesperrten Würfel herein.
	var legal := legal_indices(dice, ctx)
	if legal.size() < dice.size():
		var allowed: Array[int] = []
		for i in scored:
			if legal.has(i):
				allowed.append(i)
		scored = allowed
	var echo_slot := CharmEffects.first_participating(dice, scored)
	var base := points_for(key, combo_levels)
	var mult := mult_for(key, combo_levels)
	var essences := essence_sets_in(ctx)
	var rifts := rifts_in(ctx)
	var armed: Dictionary = ctx.get(CTX_ESSENCE_ARMED, {})
	var is_stress := bool(ctx.get(CTX_STRESS, false))
	# Krits dieser Hand, laufend gezählt: Ozon wächst mit ihnen, Grubengas fragt
	# am Ende nur, ob überhaupt einer zündete.
	var crits := 0
	# Auch ohne Materialien können Charms und Essenzen Aktivierungen stapeln.
	var has_die_bonus := not materials.is_empty() or not charm_ids.is_empty() \
		or not essences.is_empty() or not rifts.is_empty()
	var order := trigger_order(scored, dice, essences)
	# Würfelphase in Reihen-Ordnung; je Aktivierung: Augen -> Material ->
	# würfelgebundene Charms (additiv, dann Krits) - siehe CharmEffects-Kopf.
	for i in order:
		var info := level_info_for(ctx, i)
		var level := MaterialEffects.level_in(info)
		var eye_sum := int(info.get("eye_sum", 0))
		var face_material: String = materials[i] if i < materials.size() else ""
		var essence_ids := EssenceEffects.set_at(essences, i)
		var rift_ids := RiftEffects.rifts_at(rifts, i)
		var is_armed := bool(armed.get(i, false))
		var activations := 1
		if has_die_bonus:
			# Nachglühen addiert wie Echo und Sauerstoff - die Essenz bleibt der
			# einzige Faktor.
			activations = MaterialEffects.activation_count(i, charm_ids, dice[i], echo_slot, essence_ids, is_stress,
				EssenceEffects.extra_activations(i, order, essences) + RiftEffects.extra_activations(rift_ids))
		# LAUFENDER Wert: Knochen/Glas wandeln die obere Seite ZWISCHEN den
		# Aktivierungen, die zweite zählt also den gewachsenen Wert. Gewandelt wird
		# der PHYSISCHE Wert (raw), die Verwandlung liegt als Linse darüber - sonst
		# endete die Simulation woanders als apply_take_effects. Nur Augen und
		# die Material-Rechnung DIESES Würfels folgen ihm - Trigger-Ordnung,
		# Erkennung und alle Charm-Hooks bleiben an den liegenden Werten.
		var running: int = raw[i] if i < raw.size() else dice[i]
		for _a in activations:
			var shown := CharmEffects.transform_value(running, charm_ids)
			# Augen erst durch die Charm-Linse, dann durch die Essenz (Wasserstoff
			# verdoppelt, Miasma halbiert, Antimaterie kehrt um). Radons +2 auf
			# FREMDE Würfel kommt danach und wird nie mitverdoppelt.
			base += EssenceEffects.eye_value_of(essence_ids, CharmEffects.eye_value(shown, charm_ids)) \
				+ EssenceEffects.foreign_eye_bonus(i, scored, essences)
			if not has_die_bonus:
				continue
			base += MaterialEffects.base_bonus_once(i, materials, charm_ids, level, eye_sum)
			mult += MaterialEffects.mult_once_for(face_material, shown, charm_ids, level)
			for j in charm_ids.size():
				base += CharmEffects.die_charm_base_at(j, i, key, dice, charm_ids, ctx, scored)
				mult += CharmEffects.die_charm_mult_at(j, i, dice, charm_ids, ctx) \
					+ CharmEffects.die_charm_target_mult_at(j, i, dice, charm_ids, participating)
			# Material-Krit (Rubin III, Glas ab II), dann der Essenz-Krit - beide
			# in der Würfel-Substufe, VOR den Charm-Krits (Beherit). Ozon liest
			# crits VOR seinem eigenen Schlag, zählt sich also nie selbst mit.
			var mat_crit := MaterialEffects.mult_crit_once_for(face_material, shown, charm_ids, level)
			if mat_crit != 1:
				crits += 1
			mult *= mat_crit
			var ess_crit := EssenceEffects.crit_of(essence_ids, shown, crits, is_armed)
			if ess_crit != 1:
				crits += 1
			mult *= ess_crit
			for j in charm_ids.size():
				var die_crit := CharmEffects.die_charm_crit_at(j, i, dice, charm_ids, participating)
				if die_crit != 1:
					crits += 1
				mult *= die_crit
			running = MaterialEffects.mutate_value_once(running, face_material, charm_ids, level, essence_ids, rift_ids)
		# Leiterbahn: NACH allen Aktivierungen feuert die Kette je Glied EINMAL
		# wie eine Aktivierung mit getauschter Seite (nie retriggert) - noch an
		# der Position dieses Würfels, weil Krits die Reihenfolge werten. Glieder
		# behalten ihren gespeicherten Wert (eine Kette meint fremde Seiten).
		# RIFTS feuern hier NICHT: ein Riss gehört der oben liegenden Seite, und
		# ein Glied ist per Definition eine andere Seite.
		for link in pointer_links_for(ctx, i):
			var link_value := CharmEffects.transform_value(int(link["value"]), charm_ids)
			var link_material := String(link["material"])
			var link_level := int(link.get("level", 1))
			base += CharmEffects.eye_value(link_value, charm_ids)
			if not has_die_bonus:
				continue
			base += MaterialEffects.base_once_for(link_material, charm_ids, link_level, eye_sum)
			mult += MaterialEffects.mult_once_for(link_material, link_value, charm_ids, link_level)
			for j in charm_ids.size():
				base += CharmEffects.die_charm_base_at(j, i, key, dice, charm_ids, ctx, scored)
				mult += CharmEffects.die_charm_mult_at(j, i, dice, charm_ids, ctx, link_value) \
					+ CharmEffects.die_charm_target_mult_at(j, i, dice, charm_ids, participating, link_value)
			var link_crit := MaterialEffects.mult_crit_once_for(link_material, link_value, charm_ids, link_level)
			if link_crit != 1:
				crits += 1
			mult *= link_crit
			for j in charm_ids.size():
				var link_die_crit := CharmEffects.die_charm_crit_at(j, i, dice, charm_ids, participating, link_value)
				if link_die_crit != 1:
					crits += 1
				mult *= link_die_crit
	for j in charm_ids.size():
		base += CharmEffects.charm_base_bonus_at(j, key, dice, participating, charm_ids, ctx)
		mult += CharmEffects.mult_bonus_at(j, key, charm_ids) \
			+ CharmEffects.charm_mult_bonus_at(j, key, dice, materials, charm_ids, ctx, participating)
		base *= CharmEffects.charm_base_factor_at(j, dice, charm_ids, ctx)
		mult *= CharmEffects.charm_mult_factor_at(j, dice, charm_ids, ctx)
		var static_crit := CharmEffects.charm_crit_at(j, dice, charm_ids, ctx, participating)
		if static_crit != 1:
			crits += 1
		mult *= static_crit
	# Grubengas wertet SPÄT: erst nach den statischen Krits steht fest, ob in
	# dieser Hand überhaupt einer zündete.
	base += EssenceEffects.firedamp_bonus(scored, essences, crits)
	# Antimaterie zählt negativ - die Basis darf trotzdem nie unter null fallen.
	return [maxi(0, base), mult]

## Beste Hand des Wurfs: die RANGHÖCHSTE zutreffende Kategorie (HAND_PRIORITY von
## oben nach unten, erster Treffer gewinnt). Was physisch daliegt, zählt - Punkte
## vergleichen wir bewusst NICHT mehr über Kategorien hinweg, sonst nimmt das
## Spiel bei drei Zweierpäschen ein hochgestuftes Zwei-Paare. Gedrosselte
## Kategorien werden übersprungen (die Hand rutscht zur nächsten passenden).
static func best_hand(dice: Array[int], charm_ids: Array[String] = [], is_first_hand: bool = false, materials: Array[String] = [], combo_levels: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	# Erkennung auf den verwandelten Werten, Wertung mit den ROHEN: score_category
	# verwandelt selbst und braucht die physischen Werte für den Wertwandel
	# (Knochen/Glas) - zweimal verwandelt käme dort die Linse als Seitenwert an.
	var shown := CharmEffects.transform_values(dice, charm_ids)
	var best_key := ONE_KIND
	var best_score := 0  # bleibt 0, wenn keine Kategorie durchkommt (Drossel/Parität)
	for key in HAND_PRIORITY:
		if is_throttled(key, ctx) or not qualifies(key, shown, ctx):
			continue
		best_key = key
		best_score = score_category(key, dice, charm_ids, is_first_hand, materials, combo_levels, ctx)
		break
	return {
		"key": best_key,
		"label": label_for(best_key),
		"mult": _total_mult(best_key, dice, charm_ids, materials, combo_levels, ctx),
		"score": best_score,
	}

## Positionen in dice, die zur Kategorie gehören - nur diese zählen für den
## Basiswert, und nur auf ihnen wirken Seiten-Materialien. charm_ids nur bei
## ROHEN Werten mitgeben - intern sind sie schon verwandelt.
## Immer SLOT-sortiert: Würfel triggern links nach rechts, nie in Gruppenfolge.
static func participating_indices(key: String, dice: Array[int], charm_ids: Array[String] = [], ctx: Dictionary = {}) -> Array[int]:
	dice = CharmEffects.transform_values(dice, charm_ids)
	var legal := legal_indices(dice, ctx)
	var sub := dice if legal.size() == dice.size() else _legal_dice(dice, legal)
	# Joker auf die HÖCHSTE tragende Zahl setzen - deterministisch und in einer
	# Linie mit _best_value_with_count, das ebenfalls den höchsten Wert wählt.
	var wild := _wild_index_in(legal, ctx)
	if wild >= 0:
		sub = sub.duplicate()
		for value in range(6, 0, -1):
			sub[wild] = value
			if _qualifies_plain(key, sub):
				break
	var result: Array[int] = []
	if legal.size() == dice.size():
		# assign: die Zweige von _participating_unsorted liefern untypisierte Arrays.
		result.assign(_participating_unsorted(key, sub))
	else:
		# Auf der gefilterten Liste erkennen, dann die Indizes zurückrechnen.
		for k in _participating_unsorted(key, sub):
			result.append(legal[k])
	result.sort()
	return result

static func _participating_unsorted(key: String, dice: Array[int]) -> Array[int]:
	match key:
		SIX_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 6), 6)
		FIVE_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 5), 5)
		FOUR_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 4), 4)
		THREE_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 3), 3)
		TWO_PAIR:
			var result: Array[int] = []
			for value in _values_with_count_at_least(dice, 2):
				result.append_array(_indices_for_value(dice, value, 2))
			return result
		TWO_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 2), 2)
		ONE_KIND:
			return [] if dice.is_empty() else [_index_of_highest(dice)]
		FOUR_KIND_AND_PAIR:
			var pair := _find_count_and_other_count(dice, 4, 2)
			return _indices_for_value(dice, pair[0], 4) + _indices_for_value(dice, pair[1], 2)
		FULL_HOUSE:
			var pair := _find_count_and_other_count(dice, 3, 2)
			return _indices_for_value(dice, pair[0], 3) + _indices_for_value(dice, pair[1], 2)
		DOUBLE_THREE_KIND:
			var pair := _find_two_groups_with_at_least(dice, 3)
			return _indices_for_value(dice, pair[0], 3) + _indices_for_value(dice, pair[1], 3)
		THREE_PAIRS:
			var result: Array[int] = []
			for value in _values_with_count_at_least(dice, 2):
				result.append_array(_indices_for_value(dice, value, 2))
			return result
		SMALL_STRAIGHT:
			return _indices_for_straight(dice, 5)
		LARGE_STRAIGHT:
			return _indices_for_straight(dice, 6)
	return []

## Wasserstoff: eine ROH gewürfelte 1 auf einem Knallgas-Würfel lässt die Hand
## fumbeln - unabhängig davon, was sonst dalag. Der Aufrufer prüft das, sobald
## ein echter Wurf zur Ruhe gekommen ist (Erstwurf wie Neuwurf).
static func forces_farkle(raw_values: Array[int], ctx: Dictionary) -> bool:
	return EssenceEffects.forces_farkle(raw_values, essence_sets_in(ctx))

## Farkle-Regel: sicher ist ein Neu-Würfeln nur, wenn die neue Hand im RANG
## (HAND_PRIORITY) strikt höher steht - Punkte entscheiden nie. Gleicher Rang
## farklet also auch mit mehr Augen, und ein Dreier- auf einen Viererpasch kann
## nie farkeln. Materialien und Übertaktungs-Stufen bleiben in der Signatur, weil
## sie zur Hand gehören; auf den Vergleich wirken sie nicht mehr. Die Drossel im
## ctx dagegen schon - sie entscheidet, WELCHE Kategorie best_hand liefert. ctx
## gilt für beide Seiten gleich - AUSSER die alte Seite bringt ihr eigenes old_ctx
## mit (Leiterbahn-Glieder, Stufen und Essenzen hängen an den Würfeln VOR dem
## Neuwurf, wie old_materials).
static func is_strictly_better(new_dice: Array[int], old_dice: Array[int], charm_ids: Array[String] = [], new_materials: Array[String] = [], old_materials: Array[String] = [], combo_levels: Dictionary = {}, ctx: Dictionary = {}, old_ctx: Dictionary = {}) -> bool:
	var new_hand := best_hand(new_dice, charm_ids, false, new_materials, combo_levels, ctx)
	var old_hand := best_hand(old_dice, charm_ids, false, old_materials, combo_levels, ctx if old_ctx.is_empty() else old_ctx)
	# Eine Hand, die gar nichts wertet (Drossel/Parität), ist nie ein Fortschritt.
	if int(new_hand["score"]) <= 0:
		return false
	return hand_rank(String(new_hand["key"])) < hand_rank(String(old_hand["key"]))

## Rangplatz einer Kategorie in HAND_PRIORITY (kleiner = ranghöher); unbekannte
## Keys stehen hinter allem.
static func hand_rank(key: String) -> int:
	var index := HAND_PRIORITY.find(key)
	return index if index >= 0 else HAND_PRIORITY.size()

## Für die Kombinationsbildung zählt nur die LETZTE Ziffer (1, 11, 21 -> 1);
## der volle Wert zählt weiterhin für die Punkte.
static func _digit(value: int) -> int:
	return value % 10

static func _counts(dice: Array[int]) -> Dictionary:
	var result := {}
	for value in dice:
		var d := _digit(value)
		result[d] = result.get(d, 0) + 1
	return result

static func _sum(dice: Array[int], charm_ids: Array[String] = []) -> int:
	var total := 0
	for value in dice:
		total += CharmEffects.eye_value(value, charm_ids)
	return total

## Kombinationsziffer einer Gruppe mit mindestens n Würfeln - die des Würfels
## mit dem höchsten echten Wert (punktträchtigste Gruppe gewinnt). -1 = keine.
static func _best_value_with_count(dice: Array[int], n: int) -> int:
	var counts := _counts(dice)
	var best_digit := -1
	var best_value := -1
	for i in dice.size():
		var d := _digit(dice[i])
		if counts.get(d, 0) >= n and dice[i] > best_value:
			best_value = dice[i]
			best_digit = d
	return best_digit

static func _has_count_at_least(dice: Array[int], n: int) -> bool:
	for count in _counts(dice).values():
		if count >= n:
			return true
	return false

static func _count_groups_with_at_least(dice: Array[int], n: int) -> int:
	var qualifying := 0
	for count in _counts(dice).values():
		if count >= n:
			qualifying += 1
	return qualifying

static func _has_two_groups_with_at_least(dice: Array[int], n: int) -> bool:
	return _count_groups_with_at_least(dice, n) >= 2

static func _has_count_and_other_count(dice: Array[int], n: int, other_n: int) -> bool:
	var counts := _counts(dice)
	for value in counts:
		if counts[value] < n:
			continue
		for other_value in counts:
			if other_value != value and counts[other_value] >= other_n:
				return true
	return false

## Straßen zählen über Kombinationsziffern: 11-12-13-14-15 gilt wie 1-2-3-4-5.
static func _has_straight_of_length(dice: Array[int], length: int) -> bool:
	var unique := {}
	for value in dice:
		unique[_digit(value)] = true
	var start := 1
	while start + length - 1 <= 6:
		var has_all := true
		for value in range(start, start + length):
			if not unique.has(value):
				has_all = false
				break
		if has_all:
			return true
		start += 1
	return false

static func _index_of_highest(dice: Array[int]) -> int:
	var best_index := 0
	var best_value := -1
	for i in dice.size():
		if dice[i] > best_value:
			best_value = dice[i]
			best_index = i
	return best_index

## Erste n Indizes mit der Kombinationsziffer digit.
static func _indices_for_value(dice: Array[int], digit: int, n: int) -> Array[int]:
	var result: Array[int] = []
	for i in dice.size():
		if _digit(dice[i]) == digit:
			result.append(i)
			if result.size() >= n:
				break
	return result

## Wie _has_count_and_other_count, liefert aber [value, other_value].
static func _find_count_and_other_count(dice: Array[int], n: int, other_n: int) -> Array[int]:
	var counts := _counts(dice)
	for value in counts:
		if counts[value] < n:
			continue
		for other_value in counts:
			if other_value != value and counts[other_value] >= other_n:
				return [value, other_value]
	return [0, 0]

## Wie _has_two_groups_with_at_least, liefert aber die beiden Werte.
static func _find_two_groups_with_at_least(dice: Array[int], n: int) -> Array[int]:
	var counts := _counts(dice)
	var found: Array[int] = []
	for value in counts:
		if counts[value] >= n:
			found.append(value)
			if found.size() >= 2:
				break
	return found

static func _values_with_count_at_least(dice: Array[int], n: int) -> Array[int]:
	var counts := _counts(dice)
	var found: Array[int] = []
	for value in counts:
		if counts[value] >= n:
			found.append(value)
	return found

## Je ein Index pro Wert der ersten passenden Straße; Duplikate bleiben außen vor.
static func _indices_for_straight(dice: Array[int], length: int) -> Array[int]:
	var first_index_of := {}
	for i in dice.size():
		var d := _digit(dice[i])
		if not first_index_of.has(d):
			first_index_of[d] = i
	var start := 1
	while start + length - 1 <= 6:
		var has_all := true
		for value in range(start, start + length):
			if not first_index_of.has(value):
				has_all = false
				break
		if has_all:
			var result: Array[int] = []
			for value in range(start, start + length):
				result.append(first_index_of[value])
			return result
		start += 1
	return []
