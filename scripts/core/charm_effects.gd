class_name CharmEffects
## Reine Effekt-Logik der Charms, id-dispatcht (ids: Konstanten in Charm).
## Nach Wirkungsort gruppiert; jede Funktion summiert die Beiträge aller
## übergebenen ids - mehrere/duplizierte Charms stapeln sich.
## Ein neuer Charm braucht nur hier + eine Fabrikmethode in charm.gd.

# --- Drei getrennte Mechaniken am einzelnen Würfel ---------------------------
# 1. transform_value:  der Würfel ZEIGT einen anderen Wert - wirkt auf
#    Kombinations-Erkennung UND Punkte (läuft VOR DiceScoring).
# 2. retrigger_count:  der Würfel löst zusätzlich aus wie Quecksilber -
#    Augen und Material-Effekte feuern erneut (zählt MaterialEffects).
# 3. eye_value:        reine Basispunkt-Anpassung, erkennungsblind.

## Feste Kettenreihenfolge 1->6, 2->3, 3->4: eine verwandelte 2 wird von
## Fuchsschwanz weiter zur 4 gehoben, und weil jedes Ergebnis außerhalb der
## Auslösewerte landet, ist die Kette idempotent - Mehrfachanwendung im
## Pipeline-Stapel (best_hand -> score_category) bleibt gefahrlos.
static func transform_value(face_value: int, charm_ids: Array[String]) -> int:
	var value := face_value
	if value == 1 and charm_ids.has(Charm.LUCKY_CIGARETTES):
		value = 6
	if value == 2 and charm_ids.has(Charm.PENCIL_STUB):
		value = 3
	if value == 3 and charm_ids.has(Charm.FOX_TAIL):
		value = 4
	return value

static func transform_values(values: Array[int], charm_ids: Array[String]) -> Array[int]:
	if charm_ids.is_empty():
		return values
	var result: Array[int] = []
	for value in values:
		result.append(transform_value(value, charm_ids))
	return result

## Zusätzliche Auslösungen eines Würfels (je Vorkommen +1) - Hasenpfote 6,
## Kleeblatt 4, Skarabäus 5. Gezählt wird der VERWANDELTE Wert: eine 1, die
## per Glückszigaretten 6 zeigt, IST eine 6.
static func retrigger_count(value: int, charm_ids: Array[String]) -> int:
	var extra := 0
	for charm_id in charm_ids:
		match charm_id:
			Charm.RABBITS_FOOT:
				if value == 6:
					extra += 1
			Charm.FOUR_LEAF_CLOVER:
				if value == 4:
					extra += 1
			Charm.GOLDEN_SCARAB:
				if value == 5:
					extra += 1
	return extra

## Basispunkt-Beitrag eines Werts - wirkt NIE auf die Kategorie-Erkennung.
static func eye_value(face_value: int, charm_ids: Array[String]) -> int:
	var value := face_value
	for charm_id in charm_ids:
		if charm_id == Charm.SMALL_FRY and (face_value == 1 or face_value == 2):
			value += 6
	# Gleichmacher zuletzt (unabhängig von der Besitz-Reihenfolge): min. 5.
	if charm_ids.has(Charm.EQUALIZER):
		value = maxi(value, 5)
	return value

# --- Wertung (ganze Hand) ----------------------------------------------------

## Zusätzlicher Kombi-Multiplikator für die Kategorie key.
static func mult_bonus(key: String, charm_ids: Array[String]) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		match charm_id:
			Charm.HORSESHOE:
				if key == DiceScoring.FULL_HOUSE:
					bonus += 12
			Charm.LADYBUG:
				if key == DiceScoring.TWO_KIND:
					bonus += 4
			Charm.PEARL_NECKLACE:
				if key == DiceScoring.THREE_KIND:
					bonus += 8
	return bonus

## Feste Bonuspunkte NACH dem Multiplikator.
static func flat_bonus(key: String, charm_ids: Array[String]) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		match charm_id:
			Charm.RAINBOW_TROUT:
				if key == DiceScoring.SMALL_STRAIGHT or key == DiceScoring.LARGE_STRAIGHT:
					bonus += 10
	return bonus

## Multiplikator auf die gesamte Hand (Zauberkarte: erste Hand der Runde ×2).
static func score_multiplier(charm_ids: Array[String], is_first_hand: bool) -> int:
	var mult := 1
	if is_first_hand:
		for charm_id in charm_ids:
			if charm_id == Charm.MAGIC_CARD:
				mult *= 2
	return mult

# --- Geld --------------------------------------------------------------------

## Glücksgroschen: +$3 beim Rundenziel, wächst um $1 je bereits erreichtem Ziel.
static func round_clear_bonus(charm_ids: Array[String], goals_reached: int = 0) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		if charm_id == Charm.OLD_PENNY:
			bonus += 3 + maxi(0, goals_reached)
	return bonus

## Sparschwein: +$1 je noch nicht gezogenem Würfel bei der Auszahlung.
static func unused_die_bonus(charm_ids: Array[String]) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		if charm_id == Charm.PIGGY_BANK:
			bonus += 1
	return bonus

## Kristallkugel: +$7 für einen überlebten Farkle.
static func farkle_survival_income(charm_ids: Array[String]) -> int:
	var income := 0
	for charm_id in charm_ids:
		if charm_id == Charm.CRYSTAL_BALL:
			income += 7
	return income

# --- Farkle-Milderung --------------------------------------------------------

## Schornsteinfeger: der erste Farkle einer Runde wird verziehen.
static func forgives_first_farkle(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.CHIMNEY_SWEEP)

# --- Pool / Shop -------------------------------------------------------------

## Glücksknoten: +1 Würfel im Rundenpool.
static func extra_round_dice(charm_ids: Array[String]) -> int:
	var extra := 0
	for charm_id in charm_ids:
		if charm_id == Charm.LUCKY_KNOT:
			extra += 1
	return extra

## Würfelpreis nach Rabatten (Trickdieb -33%, Mengenrabatt: 3er-Bündel -$5).
static func die_price(base_price: int, charm_ids: Array[String], bundle_size: int = 1) -> int:
	var price := float(base_price)
	for charm_id in charm_ids:
		match charm_id:
			Charm.CON_ARTIST_CUFF:
				price *= 0.67
			Charm.BULK_DISCOUNT:
				if bundle_size >= 3:
					price -= 5.0
	return maxi(1, int(round(price)))

# ==============================================================================
# Effektkatalog-Hooks: brauchen Wurf-/Runden-Zustand als ctx-Dictionary
# (alle Schlüssel optional):
#   "rerolled":      int   - diese Hand neu geworfene Würfel (Pendel)
#   "taken_dice":    int   - diese Runde bereits genommene Würfel (Pendel)
#   "full_rerolls":  int   - Neuwürfe ALLER 6 seit dem letzten Nehmen (Alles-oder-nichts)
#   "streak":        int   - genommene Hände in Folge ohne Farkle (Momentum)
#   "last_hand":     bool  - letzte Hand der Runde (Feierabendbier)
#   "after_farkle":  bool  - erste Hand nach einem Farkle (Galgenhumor)
#   "farkle_stacks": int   - Farkles des gesamten Runs (Zerbrochener Spiegel)
#   "last_settled":  int   - Slot des zuletzt zur Ruhe gekommenen Würfels (Nachzügler)
#   "late_slots":    Array - Slots aus den letzten 6 des Stapels (Bodensatz)
# ==============================================================================

## Zusätzliche Basispunkte VOR dem Multiplikator.
static func charm_base_bonus(key: String, values: Array[int], participating: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, materials: Array[String] = [], edge_materials: Array[String] = []) -> int:
	var bonus := 0
	var edge_count := 0
	for material_id in edge_materials:
		if material_id != "":
			edge_count += 1
	var roll_sum := 0  # rohe Augensumme des Wurfs (Blackjack)
	for value in values:
		roll_sum += value
	var hand_sum := 0  # rohe Augensumme der beteiligten Würfel (Runde Sache)
	for i in participating:
		if i < values.size():
			hand_sum += values[i]
	for charm_id in charm_ids:
		match charm_id:
			Charm.ECHO_CHAMBER:
				if not values.is_empty():
					bonus += eye_value(values.max(), charm_ids)
			Charm.STREET_SWEEPER:
				if key == DiceScoring.SMALL_STRAIGHT or key == DiceScoring.LARGE_STRAIGHT:
					bonus += 6 * participating.size()
			Charm.FULL_COUNTER:
				for i in values.size():
					if not participating.has(i):
						bonus += eye_value(values[i], charm_ids)
			Charm.BROADBAND:
				bonus += 5 * participating.size()
			Charm.STRAGGLER:
				var last: int = ctx.get("last_settled", -1)
				if last >= 0 and last < values.size() and participating.has(last):
					bonus += eye_value(values[last], charm_ids)
			Charm.SEDIMENT:
				var late: Array = ctx.get("late_slots", [])
				for i in participating:
					if late.has(i):
						bonus += 5
			Charm.EDGE_GLEAM:
				for i in participating:
					if i < edge_materials.size() and edge_materials[i] != "":
						bonus += edge_count
			Charm.BLACKJACK:
				if roll_sum == 21:
					bonus += 50
			Charm.ROUND_NUMBER:
				if hand_sum > 0 and hand_sum % 10 == 0:
					bonus += 100
	return bonus

static func _distinct(values: Array[int]) -> Array[int]:
	var seen: Array[int] = []
	for value in values:
		if not seen.has(value):
			seen.append(value)
	return seen

## Zusätzlicher Kombi-Multiplikator der Effektkatalog-Charms (Pendel kann nie
## negativ beitragen).
static func charm_mult_bonus(key: String, values: Array[int], materials: Array[String], charm_ids: Array[String], ctx: Dictionary = {}, _combo_levels: Dictionary = {}, participating: Array[int] = []) -> int:
	var bonus := 0
	var other_charms := maxi(0, charm_ids.size() - 1)
	for charm_id in charm_ids:
		match charm_id:
			Charm.PENDULUM:
				bonus += maxi(0, 2 * int(ctx.get("rerolled", 0)) - int(ctx.get("taken_dice", 0)))
			Charm.ALL_OR_NOTHING:
				bonus += 5 * int(ctx.get("full_rerolls", 0))
			Charm.MOMENTUM:
				bonus += int(ctx.get("streak", 0))
			Charm.BROKEN_MIRROR:
				bonus += int(ctx.get("farkle_stacks", 0))
			Charm.EVEN_COMPANY:
				if not values.is_empty() and values.all(func(v: int) -> bool: return v % 2 == 0):
					bonus += 6
			Charm.ODD_PATH:
				if not values.is_empty() and values.all(func(v: int) -> bool: return v % 2 == 1):
					bonus += 5
			Charm.HERMIT_CRAB:
				if charm_ids.size() <= 2:
					bonus += 6
			Charm.DISPLAY_CASE:
				for material_id in materials:
					if material_id != "":
						bonus += 1
			Charm.LIGHTHOUSE:
				# Höchste Zahl: Mult in Höhe der höchsten Augenzahl.
				if key == DiceScoring.ONE_KIND and not values.is_empty():
					bonus += values.max()
			Charm.TWIN_RING:
				# Jedes exakte Paar im Wurf: Mult += Augenzahl.
				for value in _distinct(values):
					if values.count(value) == 2:
						bonus += value
			Charm.DOUBLE_SIX:
				# Jede 6 nach der zweiten in der Kombination: +1 Mult.
				var sixes := 0
				for i in participating:
					if i < values.size() and values[i] == 6:
						sixes += 1
				bonus += maxi(0, sixes - 2)
			Charm.SNAKE_EYES:
				# Genau ein 1er-Paar genommen: Mult += Augensumme der Unbeteiligten.
				if key == DiceScoring.TWO_KIND and _participating_are_ones(values, participating):
					for i in values.size():
						if not participating.has(i):
							bonus += values[i]
			Charm.COLLECTORS_AMULET:
				bonus += 2 * other_charms
	return bonus

static func _participating_are_ones(values: Array[int], participating: Array[int]) -> bool:
	if participating.size() != 2:
		return false
	for i in participating:
		if i >= values.size() or values[i] != 1:
			return false
	return true

## Krit-Pool: additive Beiträge, die den fertigen Mult als Faktor (1 + Summe)
## multiplizieren. Galgenhumor +3 nach Farkle.
static func crit_bonus(key: String, charm_ids: Array[String], ctx: Dictionary = {}, combo_levels: Dictionary = {}) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		match charm_id:
			Charm.GALLOWS_HUMOR:
				if ctx.get("after_farkle", false):
					bonus += 3
	return bonus

## Faktor auf den Basiswert (Einserkult: ×2 je gewürfelter 1, je Vorkommen).
static func base_factor(values: Array[int], charm_ids: Array[String]) -> int:
	var factor := 1
	for charm_id in charm_ids:
		if charm_id == Charm.CULT_OF_ONE:
			factor *= 1 << values.count(1)
	return factor

## Faktor auf den Multiplikator - gleiche Regel wie base_factor.
static func mult_factor(values: Array[int], charm_ids: Array[String]) -> int:
	return base_factor(values, charm_ids)

## Faktor auf die gesamte Hand - Feierabendbier (letzte Hand ×2).
static func hand_factor(_key: String, charm_ids: Array[String], ctx: Dictionary = {}) -> float:
	var factor := 1.0
	for charm_id in charm_ids:
		match charm_id:
			Charm.AFTER_WORK_BEER:
				if ctx.get("last_hand", false):
					factor *= 2.0
	return factor

# --- Geld: Effektkatalog -------------------------------------------------------

## Straßenmusiker: $1 je beteiligtem Würfel beim Nehmen.
static func take_income(charm_ids: Array[String], participating_count: int = 1) -> int:
	var income := 0
	for charm_id in charm_ids:
		if charm_id == Charm.STREET_MUSICIAN:
			income += participating_count
	return income

## Goldrausch: Kombination aus ALLEN liegenden Würfeln lässt das Geld um 50% wachsen.
static func gold_rush_applies(charm_ids: Array[String], participating_count: int, dice_count: int = 6) -> bool:
	return charm_ids.has(Charm.GOLD_RUSH) and dice_count > 0 and participating_count >= dice_count

## Lumpensammler: $4 je abgelegtem Würfel mit der Glückszahl oben (je Vorkommen).
static func rag_collector_income(values: Array[int], lucky_value: int, charm_ids: Array[String]) -> int:
	if lucky_value < 1:
		return 0
	var income := 0
	for charm_id in charm_ids:
		if charm_id == Charm.RAG_COLLECTOR:
			income += 4 * values.count(lucky_value)
	return income

## Scherbengericht: $2 je verworfenem Würfel eines Farkles (je Vorkommen).
static func farkle_shard_income(dice_count: int, charm_ids: Array[String]) -> int:
	var income := 0
	for charm_id in charm_ids:
		if charm_id == Charm.SHARD_COURT:
			income += 2 * dice_count
	return income

## Rundenende-Einnahmen EINZELN je Besitz-Position: Zinsgroschen ($1 je volle
## $10) und Überflieger ($1 je 25 Punkte über Ziel), beide max. $50. Alle
## rechnen auf demselben money-Stand - die Besitz-Reihenfolge verschiebt keine
## Beträge. Grundlage der Auszahlungs-Zeremonie: der Spieler sieht, WELCHER
## Charm zahlt.
static func round_end_income_entries(money: int, overflow_points: int, charm_ids: Array[String]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for j in charm_ids.size():
		var amount := 0
		match charm_ids[j]:
			Charm.INTEREST_PENNY:
				amount = mini(money / 10, 50)
			Charm.HIGH_FLYER:
				amount = mini(maxi(0, overflow_points) / 25, 50)
		if amount > 0:
			entries.append({"charm_index": j, "charm_id": charm_ids[j], "amount": amount})
	return entries

## Summe der Rundenende-Einnahmen - immer deckungsgleich mit den Einzelposten.
static func round_end_income(money: int, overflow_points: int, charm_ids: Array[String]) -> int:
	var income := 0
	for entry in round_end_income_entries(money, overflow_points, charm_ids):
		income += int(entry["amount"])
	return income

## Notgroschen: Mindest-Geldstand am Rundenende ($25), sonst 0.
static func money_floor(charm_ids: Array[String]) -> int:
	return 25 if charm_ids.has(Charm.EMERGENCY_FUND) else 0

# --- Farkle: Effektkatalog -----------------------------------------------------

## Anker: der erste Neuwurf jeder Hand kann nicht farkeln (reroll_index
## inklusive des aktuellen).
static func anchor_saves(charm_ids: Array[String], reroll_index: int) -> bool:
	return charm_ids.has(Charm.ANCHOR) and reroll_index == 1

## Standuhr: Farkle verdoppelt die aktuellen Rundenpunkte.
static func farkle_doubles_points(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.GRANDFATHER_CLOCK)

## Flickenteppich: Farkle behält die Höchste-Zahl-Wertung des Wurfs.
static func farkle_keeps_high_card(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.PATCHWORK_RUG)

## Phönixfeder: geworfene Würfel kehren beim Farkle in den Stapel zurück.
static func has_phoenix(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.PHOENIX_FEATHER)

# --- Pool / Shop: Effektkatalog --------------------------------------------------

## Magnetring: Würfel mit Kanten-Material werden zuerst gezogen.
static func draws_edges_first(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.MAGNET_RING)

## Frische Ware: neu gekaufte Würfel liegen vorn im Nachziehstapel.
static func draws_fresh_first(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.FRESH_GOODS)

## Recycling: die erste genommene Hand jeder Runde kehrt in den Stapel zurück.
static func recycles_first_hand(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.RECYCLING)

## Charm-Preis nach Skonto (je Vorkommen -$5, min. $1).
static func charm_price(base_price: int, charm_ids: Array[String]) -> int:
	var price := base_price
	for charm_id in charm_ids:
		if charm_id == Charm.CASH_DISCOUNT:
			price -= 5
	return maxi(1, price)

## Verkaufserlös eines Charms - Ansatzpunkt für künftige wertsteigernde Charms.
static func charm_sell_value(base_value: int, _charm_ids: Array[String]) -> int:
	return maxi(1, base_value)

## Pack-Preis: Schnäppchenjäger -$3 je Vorkommen auf JEDE Paketsorte; min. $1.
## Bei Würfel-Paketen liegt der Würfel-Rabatt (die_price) schon im base_price.
static func pack_price(base_price: int, _pack_id: String, charm_ids: Array[String]) -> int:
	var price := float(base_price)
	for charm_id in charm_ids:
		if charm_id == Charm.BARGAIN_HUNTER:
			price -= 3.0
	return maxi(1, int(round(price)))

## Kleingedrucktes: Chance auf volle Pack-Rückerstattung (20% je Vorkommen, max. 80%).
static func pack_refund_chance(charm_ids: Array[String]) -> float:
	var chance := 0.0
	for charm_id in charm_ids:
		if charm_id == Charm.FINE_PRINT:
			chance += 0.2
	return minf(chance, 0.8)

## Gütesiegel: Shop-Würfel sind immer veredelt.
static func forces_refinement(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.SEAL_OF_QUALITY)

## Chip-Coupon-Wert (Doppelte Perforation: +$1 je Vorkommen).
static func chip_coupon_value(base_value: int, charm_ids: Array[String]) -> int:
	var value := base_value
	for charm_id in charm_ids:
		if charm_id == Charm.DOUBLE_PERFORATION:
			value += 1
	return value

## Gravierstift: einmal pro Runde wird ein Zahl-Gravur nicht verbraucht.
static func has_engraving_pen(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.ENGRAVING_PEN)
