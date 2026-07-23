class_name CharmEffects
## Reine Effekt-Logik der Charms, id-dispatcht (ids: Konstanten in Charm).
## Nach Wirkungsort gruppiert; mehrere/duplizierte Charms stapeln sich.
## Ein neuer Charm braucht nur hier + eine Fabrikmethode in charm.gd.
##
## Trigger-Reihenfolge der Wertung (fix, KEINE Ausnahmen):
##   1. Würfel links nach rechts (Slot-Reihenfolge). Charms, die einen einzelnen
##      beteiligten Würfel betreffen, feuern MIT ihrem Würfel (die_charm_*_at).
##   2. Charms strikt in Besitz-Reihenfolge: additive Boni UND Faktoren
##      (charm_*_at-Hooks) wirken an ihrer Position - Faktoren sammeln sich
##      nie am Ende, die Dock-Reihenfolge ist damit spielrelevant. KRITS
##      (charm_crit_at) sind Faktoren auf den aktuellen Mult.
##   3. Nach Basis × Mult: Gesamtzahl-Effekte (charm_total_*_at), ebenfalls
##      in Besitz-Reihenfolge.

## Alles-oder-nichts: +Mult je Voll-Neuwurf (auch für die Tisch-Anzeige genutzt).
const ALL_OR_NOTHING_MULT := 5

## Schlüssel des ctx-Dictionaries (Wurf-/Runden-Zustand der Effektkatalog-Charms).
## const, damit ein Tippfehler beim Setzen (scene_root) ODER Lesen ein Compile-
## Fehler ist - nicht der stille Null-Rückfall von ctx.get(). Werte je Schlüssel:
##   REROLLED      int   - diese Hand neu geworfene Würfel (Pendel)
##   TAKEN_DICE    int   - diese Runde bereits genommene Würfel (Pendel)
##   FULL_REROLLS  int   - Neuwürfe ALLER 6 seit dem letzten Nehmen (Alles-oder-nichts)
##   STREAK        int   - genommene Hände in Folge ohne Farkle (Momentum)
##   POOL_EMPTY    bool  - kein Würfel mehr im Nachziehstapel (Feierabendbier)
##   AFTER_FARKLE  bool  - erste Hand nach einem Farkle (Galgenhumor)
##   FARKLE_STACKS int   - Farkles des gesamten Runs (Zerbrochener Spiegel)
##   LAST_SETTLED  int   - Slot des zuletzt zur Ruhe gekommenen Würfels (Nachzügler)
##   LATE_SLOTS    Array - Slots aus den letzten 6 des Stapels (Bodensatz)
const CTX_REROLLED := "rerolled"
const CTX_TAKEN_DICE := "taken_dice"
const CTX_FULL_REROLLS := "full_rerolls"
const CTX_STREAK := "streak"
const CTX_POOL_EMPTY := "pool_empty"
const CTX_AFTER_FARKLE := "after_farkle"
const CTX_FARKLE_STACKS := "farkle_stacks"
const CTX_LAST_SETTLED := "last_settled"
const CTX_LATE_SLOTS := "late_slots"

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
	# Gleichmacher zuletzt (unabhängig von der Besitz-Reihenfolge): min. 6.
	if charm_ids.has(Charm.EQUALIZER):
		value = maxi(value, 6)
	return value

# --- Würfelphase: Pro-Würfel-Charms (feuern MIT ihrem beteiligten Würfel) -----

## Basispunkt-Beitrag der Besitz-Position j am beteiligten Würfel slot.
static func die_charm_base_at(j: int, slot: int, key: String, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, edge_materials: Array[String] = []) -> int:
	match charm_ids[j]:
		Charm.BROADBAND:
			return 5
		Charm.STREET_SWEEPER:
			if key == DiceScoring.SMALL_STRAIGHT or key == DiceScoring.LARGE_STRAIGHT:
				return 6
		Charm.EDGE_GLEAM:
			if slot < edge_materials.size() and edge_materials[slot] != "":
				return _edge_count(edge_materials)
		Charm.STRAGGLER:
			if slot == int(ctx.get(CTX_LAST_SETTLED, -1)):
				return eye_value(values[slot], charm_ids)
	return 0

## Mult-Beitrag der Besitz-Position j am beteiligten Würfel slot (Bodensatz:
## +3 je spät gezogenem Würfel).
static func die_charm_mult_at(j: int, slot: int, charm_ids: Array[String], ctx: Dictionary = {}) -> int:
	match charm_ids[j]:
		Charm.SEDIMENT:
			var late: Array = ctx.get(CTX_LATE_SLOTS, [])
			if late.has(slot):
				return 3
	return 0

## Summe aller Pro-Würfel-Basisbeiträge für slot (über alle Besitz-Positionen).
static func die_charm_base(slot: int, key: String, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, edge_materials: Array[String] = []) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += die_charm_base_at(j, slot, key, values, charm_ids, ctx, edge_materials)
	return bonus

## Summe aller Pro-Würfel-Multbeiträge für slot.
static func die_charm_mult(slot: int, charm_ids: Array[String], ctx: Dictionary = {}) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += die_charm_mult_at(j, slot, charm_ids, ctx)
	return bonus

static func _edge_count(edge_materials: Array[String]) -> int:
	var count := 0
	for material_id in edge_materials:
		if material_id != "":
			count += 1
	return count

# --- Charm-Phase (ganze Hand, strikt in Besitz-Reihenfolge) -------------------

## Kombi-Multiplikator der Position j für die Kategorie key.
static func mult_bonus_at(j: int, key: String, charm_ids: Array[String]) -> int:
	match charm_ids[j]:
		Charm.HORSESHOE:
			if key == DiceScoring.FULL_HOUSE:
				return 12
		Charm.LADYBUG:
			if key == DiceScoring.TWO_KIND:
				return 4
		Charm.PEARL_NECKLACE:
			if key == DiceScoring.THREE_KIND:
				return 8
	return 0

static func mult_bonus(key: String, charm_ids: Array[String]) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += mult_bonus_at(j, key, charm_ids)
	return bonus

# --- Nach-Phase (auf die fertige Punktzahl, Besitz-Reihenfolge) ---------------

## Feste Bonuspunkte NACH dem Verschmelzen (Regenbogenforelle: Straßen +10).
static func charm_total_add_at(j: int, key: String, charm_ids: Array[String]) -> int:
	match charm_ids[j]:
		Charm.RAINBOW_TROUT:
			if key == DiceScoring.SMALL_STRAIGHT or key == DiceScoring.LARGE_STRAIGHT:
				return 10
	return 0

## Faktor auf die Gesamtzahl (Zauberkarte: erste Hand der Runde ×2).
static func charm_total_factor_at(j: int, charm_ids: Array[String], is_first_hand: bool) -> int:
	match charm_ids[j]:
		Charm.MAGIC_CARD:
			if is_first_hand:
				return 2
	return 1

# --- Geld --------------------------------------------------------------------

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
# Effektkatalog-Hooks: brauchen Wurf-/Runden-Zustand als ctx-Dictionary (alle
# Schlüssel optional, Konstanten siehe CTX_* oben).
# ==============================================================================

## Zusätzliche Basispunkte der Position j VOR dem Multiplikator (Hand-Ebene;
## Pro-Würfel-Charms liegen in die_charm_base_at). Der Charm sieht die GANZE
## Liste als Kontext - der Vollzähler rechnet Augen mit allen Augen-Charms.
static func charm_base_bonus_at(j: int, key: String, values: Array[int], participating: Array[int], charm_ids: Array[String], _ctx: Dictionary = {}) -> int:
	match charm_ids[j]:
		Charm.FULL_COUNTER:
			var bonus := 0
			for i in values.size():
				if not participating.has(i):
					bonus += eye_value(values[i], charm_ids)
			return bonus
		Charm.BLACKJACK:
			if _participating_sum(values, participating) == 21:
				return 50
		Charm.ROUND_NUMBER:
			var hand_sum := _participating_sum(values, participating)
			if hand_sum > 0 and hand_sum % 10 == 0:
				return 100
	return 0

static func charm_base_bonus(key: String, values: Array[int], participating: Array[int], charm_ids: Array[String], ctx: Dictionary = {}) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += charm_base_bonus_at(j, key, values, participating, charm_ids, ctx)
	return bonus

## Augensumme NUR der gezählten (beteiligten) Würfel - Blackjack und Runde
## Sache ignorieren mitgenommene, aber unbeteiligte Würfel.
static func _participating_sum(values: Array[int], participating: Array[int]) -> int:
	var total := 0
	for i in participating:
		if i < values.size():
			total += values[i]
	return total

static func _distinct(values: Array[int]) -> Array[int]:
	var seen: Array[int] = []
	for value in values:
		if not seen.has(value):
			seen.append(value)
	return seen

## Kombi-Multiplikator der Position j (Effektkatalog; Pendel kann nie negativ
## beitragen). Pro-Würfel-Charms liegen in die_charm_mult_at.
static func charm_mult_bonus_at(j: int, key: String, values: Array[int], materials: Array[String], charm_ids: Array[String], ctx: Dictionary = {}, participating: Array[int] = []) -> int:
	match charm_ids[j]:
		Charm.PENDULUM:
			return maxi(0, 2 * int(ctx.get(CTX_REROLLED, 0)) - int(ctx.get(CTX_TAKEN_DICE, 0)))
		Charm.ALL_OR_NOTHING:
			return ALL_OR_NOTHING_MULT * int(ctx.get(CTX_FULL_REROLLS, 0))
		Charm.MOMENTUM:
			return int(ctx.get(CTX_STREAK, 0))
		Charm.BROKEN_MIRROR:
			return int(ctx.get(CTX_FARKLE_STACKS, 0))
		Charm.EVEN_COMPANY:
			if not values.is_empty() and values.all(func(v: int) -> bool: return v % 2 == 0):
				return 6
		Charm.ODD_PATH:
			if not values.is_empty() and values.all(func(v: int) -> bool: return v % 2 == 1):
				return 5
		Charm.HERMIT_CRAB:
			if charm_ids.size() <= 2:
				return 6
		Charm.DISPLAY_CASE:
			var display := 0
			for material_id in materials:
				if material_id != "":
					display += 1
			return display
		Charm.LIGHTHOUSE:
			# Höchste Zahl: Mult in Höhe der höchsten Augenzahl.
			if key == DiceScoring.ONE_KIND and not values.is_empty():
				return values.max()
		Charm.TWIN_RING:
			# Jedes exakte Paar im Wurf: Mult += Augenzahl.
			var twins := 0
			for value in _distinct(values):
				if values.count(value) == 2:
					twins += value
			return twins
		Charm.SNAKE_EYES:
			# Genau ein 1er-Paar genommen: Mult += Augensumme der Unbeteiligten.
			if key == DiceScoring.TWO_KIND and _participating_are_ones(values, participating):
				var eyes := 0
				for i in values.size():
					if not participating.has(i):
						eyes += values[i]
				return eyes
		Charm.COLLECTORS_AMULET:
			return 2 * maxi(0, charm_ids.size() - 1)
	return 0

static func charm_mult_bonus(key: String, values: Array[int], materials: Array[String], charm_ids: Array[String], ctx: Dictionary = {}, participating: Array[int] = []) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += charm_mult_bonus_at(j, key, values, materials, charm_ids, ctx, participating)
	return bonus

static func _participating_are_ones(values: Array[int], participating: Array[int]) -> bool:
	if participating.size() != 2:
		return false
	for i in participating:
		if i >= values.size() or values[i] != 1:
			return false
	return true

## Echo-Kammer: zusätzliche Auslösungen des zuerst gewerteten Würfels - wie
## Quecksilber feuern Augen UND Material-Effekte erneut (MaterialEffects.
## activation_count bekommt den Slot über echo_slot).
static func echo_retriggers(charm_ids: Array[String]) -> int:
	return charm_ids.count(Charm.ECHO_CHAMBER)

## Vorderster gewerteter Slot oder -1 (Echo-Kammer). Nimmt den kleinsten Index,
## damit auch unsortierte Teillisten (Tests, alte Aufrufer) korrekt bleiben.
static func first_participating(values: Array[int], participating: Array[int]) -> int:
	var first := -1
	for i in participating:
		if i < values.size() and (first < 0 or i < first):
			first = i
	return first

## Faktor der Position j auf den BASISWERT: Einserkult (×2 je gewürfelter 1)
## und Feierabendbier (×2 bei leerem Nachziehstapel). Wirkt an der Besitz-
## Position - Boni SPÄTERER Charms bleiben unberührt.
static func charm_base_factor_at(j: int, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}) -> int:
	match charm_ids[j]:
		Charm.CULT_OF_ONE:
			return 1 << values.count(1)
		Charm.AFTER_WORK_BEER:
			if ctx.get(CTX_POOL_EMPTY, false):
				return 2
	return 1

## Faktor der Position j auf den MULT (Einserkult; Krits haben ihren
## eigenen Hook charm_crit_at).
static func charm_mult_factor_at(j: int, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}) -> int:
	match charm_ids[j]:
		Charm.CULT_OF_ONE:
			return 1 << values.count(1)
	return 1

## KRIT der Position j: multipliziert den AKTUELLEN Mult (Mult 10, Krit ×3
## -> 30) - wie jeder Faktor an der Besitz-Position, spätere Mult-Boni
## bleiben unberührt. 1 = kein Krit. Galgenhumor: ×4 nach Farkle,
## Feierabendbier: ×2 bei leerem Nachziehstapel (zusätzlich zur Basis).
static func charm_crit_at(j: int, _values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}) -> int:
	match charm_ids[j]:
		Charm.GALLOWS_HUMOR:
			if ctx.get(CTX_AFTER_FARKLE, false):
				return 4
		Charm.AFTER_WORK_BEER:
			if ctx.get(CTX_POOL_EMPTY, false):
				return 2
	return 1

# --- Geld: Effektkatalog -------------------------------------------------------

## Straßenmusiker: $1 je beteiligtem Würfel beim Nehmen.
static func take_income(charm_ids: Array[String], participating_count: int = 1) -> int:
	var income := 0
	for charm_id in charm_ids:
		if charm_id == Charm.STREET_MUSICIAN:
			income += participating_count
	return income

## Goldrausch: NUR die erste genommene Hand der Runde zählt, und nur wenn ihre
## Kombination ALLE liegenden Würfel nutzt.
static func gold_rush_applies(charm_ids: Array[String], participating_count: int, dice_count: int = 6, is_first_hand: bool = true) -> bool:
	return charm_ids.has(Charm.GOLD_RUSH) and is_first_hand \
		and dice_count > 0 and participating_count >= dice_count

## Goldrausch-Zuwachs: 20% des aktuellen Geldes, max. $50.
static func gold_rush_income(money: int) -> int:
	return mini(maxi(0, money) / 5, 50)

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
## $10) und Überflieger ($1 je 25 Punkte über Ziel), beide max. $50, dazu der
## Glücksgroschen ($3, +$1 je vorheriger Auszahlung - NICHT je Überladungsstufe).
## Alle rechnen auf demselben money-Stand - die Besitz-Reihenfolge verschiebt
## keine Beträge. Grundlage der Auszahlungs-Zeremonie: der Spieler sieht,
## WELCHER Charm zahlt.
static func round_end_income_entries(money: int, overflow_points: int, charm_ids: Array[String], penny_payouts: int = 0) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for j in charm_ids.size():
		var amount := 0
		match charm_ids[j]:
			Charm.INTEREST_PENNY:
				amount = mini(money / 10, 50)
			Charm.HIGH_FLYER:
				amount = mini(maxi(0, overflow_points) / 25, 50)
			Charm.OLD_PENNY:
				amount = 3 + maxi(0, penny_payouts)
		if amount > 0:
			entries.append({"charm_index": j, "charm_id": charm_ids[j], "amount": amount})
	return entries

## Summe der Rundenende-Einnahmen - immer deckungsgleich mit den Einzelposten.
static func round_end_income(money: int, overflow_points: int, charm_ids: Array[String], penny_payouts: int = 0) -> int:
	var income := 0
	for entry in round_end_income_entries(money, overflow_points, charm_ids, penny_payouts):
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

## Flickenteppich: bei einem Farkle bleibt der höchste Würfel gehalten liegen,
## statt die Hand zu verlieren (siehe scene_root._keep_highest_die_and_continue).
static func farkle_keeps_high_die(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.PATCHWORK_RUG)

## Phönixfeder: geworfene Würfel kehren beim Farkle in den Stapel zurück.
static func has_phoenix(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.PHOENIX_FEATHER)

# --- Pool / Shop: Effektkatalog --------------------------------------------------

## Magnetring: Würfel mit Kanten-Material werden zuerst gezogen.
static func draws_edges_first(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.MAGNET_RING)

## Frische Ware: Würfel mit Material liegen vorn im Nachziehstapel.
static func draws_materials_first(charm_ids: Array[String]) -> bool:
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

## Gravierstift: einmal pro Runde wird ein Zahl-Gravur nicht verbraucht.
static func has_engraving_pen(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.ENGRAVING_PEN)
