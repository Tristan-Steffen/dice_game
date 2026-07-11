class_name CharmEffects
## Reine Effekt-Logik der Charms (siehe Charm) - keine Nodes, nur Rechnen,
## analog zu DiceScoring. Jeder Charm wirkt über seine id (Charm.id) und wird
## hier zentral aufgelöst; die ids kommen als Konstanten aus Charm (z.B.
## Charm.RABBITS_FOOT), damit ein Tippfehler ein Compilerfehler ist statt eines
## stillen No-ops. Ein neuer Charm braucht nur hier + als neue Fabrikmethode in
## charm.gd einen Eintrag.
##
## Die Effekte sind nach Wirkungsort in Gruppen sortiert: Augenwert (einzelner
## Würfel), Wertung (Multiplikator/Bonus/Verdopplung ganzer Hände), Geld,
## Farkle-Milderung und Pool/Shop. Jede öffentliche Funktion nimmt die Liste
## der besessenen Charm-ids und summiert/kombiniert die passenden Beiträge -
## mehrere Charms stapeln sich also. Diese Gruppierung ist bewusst am AUFRUFER
## orientiert (DiceScoring fragt z.B. nur einmal mult_bonus() und bekommt die
## Summe); der Preis ist, dass die Wirkung EINES Charms über mehrere Funktionen
## verteilt liegt (siehe charm.gd für Metadaten desselben Charms).

# --- Augenwert (einzelner Würfel) -------------------------------------------

## Augenwert, den face_value (ein tatsächlich gewürfelter Wert) nach allen
## aktiven Charms zur Punktsumme beiträgt (siehe DiceScoring._sum und die
## Pasch-Zweige von score_category) - wirkt NICHT auf die Kategorie-Erkennung
## (Paare, Straßen, ...), die bleibt am tatsächlich gewürfelten Wert; nur wie
## stark er zählt, ändert sich. Mehrere Charms wirken nacheinander, ihre
## Effekte stapeln sich also.
static func eye_value(face_value: int, charm_ids: Array[String]) -> int:
	var value := face_value
	for charm_id in charm_ids:
		value = _apply_eye_value(charm_id, face_value, value)
	# Gleichmacher zuletzt (unabhängig von der Besitz-Reihenfolge): kein Würfel
	# zählt unter 3 Augen.
	if charm_ids.has(Charm.EQUALIZER):
		value = maxi(value, 3)
	return value

static func _apply_eye_value(charm_id: String, face_value: int, value: int) -> int:
	match charm_id:
		Charm.RABBITS_FOOT:
			return value + face_value if face_value == 6 else value
		Charm.FOUR_LEAF_CLOVER:
			return value + face_value if face_value == 4 else value
		Charm.GOLDEN_SCARAB:
			return value + face_value if face_value == 5 else value
		Charm.LUCKY_CIGARETTES:
			return 6 if face_value == 1 else value
		Charm.FOX_TAIL:
			return 4 if face_value == 3 else value
		Charm.PENCIL_STUB:
			return 3 if face_value == 2 else value
		Charm.SMALL_FRY:
			return value + 2 if face_value == 1 or face_value == 2 else value
		_:
			return value

# --- Wertung (ganze Hand) ----------------------------------------------------

## Zusätzlicher Kombi-Multiplikator für die Kategorie key (siehe
## DiceScoring.score_category) - z.B. Hufeisen: Full House +1.
static func mult_bonus(key: String, charm_ids: Array[String]) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		match charm_id:
			Charm.HORSESHOE:
				if key == DiceScoring.FULL_HOUSE:
					bonus += 1
			Charm.LADYBUG:
				if key == DiceScoring.TWO_KIND or key == DiceScoring.TWO_PAIR:
					bonus += 1
			Charm.PEARL_NECKLACE:
				if key == DiceScoring.FOUR_KIND_AND_PAIR or key == DiceScoring.THREE_PAIRS or key == DiceScoring.DOUBLE_THREE_KIND:
					bonus += 2
	return bonus

## Feste Bonuspunkte, die NACH dem Multiplikator auf die Hand addiert werden
## (siehe DiceScoring.score_category) - z.B. Regenbogenforelle: +10 auf Straßen,
## Sammler-Amulett: +1 je anderem besessenen Charm.
static func flat_bonus(key: String, charm_ids: Array[String]) -> int:
	var bonus := 0
	var other_charms := maxi(0, charm_ids.size() - 1)
	for charm_id in charm_ids:
		match charm_id:
			Charm.RAINBOW_TROUT:
				if key == DiceScoring.SMALL_STRAIGHT or key == DiceScoring.LARGE_STRAIGHT:
					bonus += 10
			Charm.COLLECTORS_AMULET:
				bonus += other_charms
	return bonus

## Multiplikator auf die GESAMTE Hand (nach mult/flat), nur unter bestimmten
## Bedingungen - z.B. Zauberkarte: erste genommene Hand der Runde ×2. Liefert
## sonst 1.
static func score_multiplier(charm_ids: Array[String], is_first_hand: bool) -> int:
	var mult := 1
	if is_first_hand:
		for charm_id in charm_ids:
			if charm_id == Charm.MAGIC_CARD:
				mult *= 2
	return mult

# --- Geld --------------------------------------------------------------------

## Fester Extra-Betrag beim Erreichen des Rundenziels (siehe
## scene_root.gd: _on_round_complete) - z.B. Glücksgroschen +2$.
static func round_clear_bonus(charm_ids: Array[String]) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		if charm_id == Charm.OLD_PENNY:
			bonus += 2
	return bonus

## Extra-Auszahlung je noch nicht gezogenem Würfel, zusätzlich zum Basiswert
## (siehe scene_root.gd: MONEY_PER_UNUSED_DIE) - z.B. Sparschwein +1$/Würfel.
static func unused_die_bonus(charm_ids: Array[String]) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		if charm_id == Charm.PIGGY_BANK:
			bonus += 1
	return bonus

## Sofort-Einkommen für einen überlebten Farkle (Runde geht weiter, siehe
## scene_root.gd: _on_farkle) - z.B. Kristallkugel +1$.
static func farkle_survival_income(charm_ids: Array[String]) -> int:
	var income := 0
	for charm_id in charm_ids:
		if charm_id == Charm.CRYSTAL_BALL:
			income += 1
	return income

# --- Farkle-Milderung --------------------------------------------------------

## True, wenn der erste Farkle einer Runde verziehen werden soll (Hand läuft
## weiter statt verworfen zu werden) - Schornsteinfeger, siehe
## scene_root.gd: _on_farkle.
static func forgives_first_farkle(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.CHIMNEY_SWEEP)

## Anteil der Punkte, der bei einem (nicht verziehenen) Farkle erhalten bleibt
## statt null - Umgedrehter Spiegel: 0.5, sonst 0.0. Bei mehreren solchen
## Charms zählt der stärkste.
static func farkle_kept_fraction(charm_ids: Array[String]) -> float:
	var fraction := 0.0
	for charm_id in charm_ids:
		if charm_id == Charm.BACKWARDS_MIRROR:
			fraction = maxf(fraction, 0.5)
	return fraction

# --- Pool / Shop -------------------------------------------------------------

## Zusätzliche Würfel, die dem Rundenpool beigemischt werden (siehe
## scene_root.gd: _start_new_round) - Glücksknoten: +1.
static func extra_round_dice(charm_ids: Array[String]) -> int:
	var extra := 0
	for charm_id in charm_ids:
		if charm_id == Charm.LUCKY_KNOT:
			extra += 1
	return extra

## True, wenn Spezialwürfel (nicht "normal") im Rundenpool nach vorne sortiert
## werden, damit sie zuerst gezogen werden - Wünschelrute, siehe
## scene_root.gd: _start_new_round.
static func draws_specials_first(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.DOWSING_ROD)

## Effektiver Würfelpreis im Shop nach Rabatt-Charms (siehe ShopController) -
## Trickdieb-Manschette: -20%; Mengenrabatt: 3er-Bündel $5 günstiger.
static func die_price(base_price: int, charm_ids: Array[String], bundle_size: int = 1) -> int:
	var price := float(base_price)
	for charm_id in charm_ids:
		match charm_id:
			Charm.CON_ARTIST_CUFF:
				price *= 0.8
			Charm.BULK_DISCOUNT:
				if bundle_size >= 3:
					price -= 5.0
	return maxi(1, int(round(price)))

# ==============================================================================
# Effektkatalog-Hooks (siehe Obsidian "12 Charms - Effektkatalog"). Viele der
# neuen Charms brauchen Wurf-/Runden-Zustand, den weder key noch values
# hergeben - der Aufrufer (scene_root) reicht ihn als ctx-Dictionary in die
# Wertung (siehe DiceScoring.score_category). Alle ctx-Schlüssel sind optional:
#   "rerolled":      int   - diese Hand neu geworfene Würfel (Pendel)
#   "taken_dice":    int   - diese Runde bereits genommene Würfel (Pendel)
#   "full_reroll":   bool  - letzter Wurf war ein Neuwurf ALLER 6 (Alles-oder-nichts)
#   "streak":        int   - genommene Hände in Folge ohne Farkle (Momentum)
#   "last_hand":     bool  - dies ist die letzte Hand der Runde (Feierabendbier)
#   "prev_key":      String- Kategorie der zuletzt genommenen Hand (Serientäter)
#   "after_farkle":  bool  - erste Hand nach einem Farkle (Galgenhumor)
#   "farkle_stacks": int   - Farkles des gesamten Runs (Zerbrochener Spiegel)
#   "last_settled":  int   - Slot des zuletzt zur Ruhe gekommenen Würfels (Nachzügler)
#   "late_slots":    Array - Slots, die aus den letzten 6 des Stapels gezogen wurden (Bodensatz)
# Additive Effekte stapeln je VORKOMMEN der id (wichtig für die Totems, die
# Nachbar-ids duplizieren, siehe GameRun.charm_ids).
# ==============================================================================

# --- Wertung: zusätzlicher Basiswert ------------------------------------------

## Zusätzliche Basispunkte der Effektkatalog-Charms, VOR dem Multiplikator
## (siehe DiceScoring.score_category). participating = Positionen der
## Kombination (siehe DiceScoring.participating_indices).
static func charm_base_bonus(key: String, values: Array[int], participating: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, materials: Array[String] = [], edge_materials: Array[String] = []) -> int:
	var bonus := 0
	var edge_count := 0
	for material_id in edge_materials:
		if material_id != "":
			edge_count += 1
	for charm_id in charm_ids:
		match charm_id:
			Charm.ECHO_CHAMBER:
				if not values.is_empty():
					bonus += eye_value(values.max(), charm_ids)
			Charm.TWIN_RING:
				for value in _distinct(values):
					if values.count(value) == 2:
						bonus += 2 * eye_value(value, charm_ids)
			Charm.DOUBLE_SIX:
				bonus += (values.count(6) / 2) * eye_value(6, charm_ids)
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
	return bonus

static func _distinct(values: Array[int]) -> Array[int]:
	var seen: Array[int] = []
	for value in values:
		if not seen.has(value):
			seen.append(value)
	return seen

# --- Wertung: zusätzlicher Multiplikator ---------------------------------------

## Zusätzlicher Kombi-Multiplikator der Effektkatalog-Charms (siehe
## DiceScoring.score_category; kann durch das Pendel auch NEGATIV beitragen -
## der Aufrufer klemmt den Gesamt-Mult auf min. 1).
static func charm_mult_bonus(key: String, values: Array[int], materials: Array[String], charm_ids: Array[String], ctx: Dictionary = {}, combo_levels: Dictionary = {}) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		match charm_id:
			Charm.PENDULUM:
				bonus += 2 * int(ctx.get("rerolled", 0)) - int(ctx.get("taken_dice", 0))
			Charm.ALL_OR_NOTHING:
				if ctx.get("full_reroll", false):
					bonus += 5
			Charm.MOMENTUM:
				bonus += int(ctx.get("streak", 0))
			Charm.GALLOWS_HUMOR:
				if ctx.get("after_farkle", false):
					bonus += 3
			Charm.BROKEN_MIRROR:
				bonus += int(ctx.get("farkle_stacks", 0))
			Charm.EVEN_COMPANY:
				if not values.is_empty() and values.all(func(v: int) -> bool: return v % 2 == 0):
					bonus += 3
			Charm.ODD_PATH:
				if not values.is_empty() and values.all(func(v: int) -> bool: return v % 2 == 1):
					bonus += 3
			Charm.HERMIT_CRAB:
				if charm_ids.size() <= 2:
					bonus += 4
			Charm.DISPLAY_CASE:
				for material_id in materials:
					if material_id != "":
						bonus += 1
			Charm.LIGHTHOUSE:
				if key == DiceScoring.ONE_KIND:
					bonus += 2  # Basis-Mult 1 -> 3
			Charm.RESTAURANT_CRITIC:
				bonus += 2 * int(combo_levels.get(key, 0))
	return bonus

# --- Wertung: feste Bonuspunkte -------------------------------------------------

## Feste Bonuspunkte der Effektkatalog-Charms, NACH dem Multiplikator (wie
## flat_bonus; siehe DiceScoring.score_category).
static func charm_flat_bonus(values: Array[int], participating: Array[int], charm_ids: Array[String], materials: Array[String] = [], edge_materials: Array[String] = []) -> int:
	var bonus := 0
	var sum := 0
	for value in values:
		sum += value
	for charm_id in charm_ids:
		match charm_id:
			Charm.BLACKJACK:
				if sum == 21:
					bonus += 21
			Charm.SNAKE_EYES:
				if values.count(1) == 2:
					bonus += 15
			Charm.ALLOY:
				for i in participating:
					var has_face: bool = i < materials.size() and materials[i] != ""
					var has_edge: bool = i < edge_materials.size() and edge_materials[i] != ""
					if has_face and has_edge:
						bonus += 10
	return bonus

# --- Wertung: Faktoren auf Basis/Mult/Gesamt -------------------------------------

## Faktor auf den BASISWERT (Einserkult: ×2 je gewürfelter 1, je Vorkommen).
static func base_factor(values: Array[int], charm_ids: Array[String]) -> int:
	var factor := 1
	for charm_id in charm_ids:
		if charm_id == Charm.CULT_OF_ONE:
			factor *= 1 << values.count(1)
	return factor

## Faktor auf den MULTIPLIKATOR (Einserkult: ×2 je gewürfelter 1, je Vorkommen).
static func mult_factor(values: Array[int], charm_ids: Array[String]) -> int:
	return base_factor(values, charm_ids)  # identische Regel, getrennt benannt für Lesbarkeit

## Faktor auf die GESAMTE Hand (nach mult/flat) aus den Effektkatalog-Charms -
## Feierabendbier (letzte Hand ×2) und Serientäter (Wiederholung ×1,5).
static func hand_factor(key: String, charm_ids: Array[String], ctx: Dictionary = {}) -> float:
	var factor := 1.0
	for charm_id in charm_ids:
		match charm_id:
			Charm.AFTER_WORK_BEER:
				if ctx.get("last_hand", false):
					factor *= 2.0
			Charm.SERIAL_OFFENDER:
				if str(ctx.get("prev_key", "")) == key and key != "":
					factor *= 1.5
	return factor

## Nachjustierung der fertigen Punktzahl (Runde Sache: endet sie auf 0, +20).
static func post_score_bonus(score: int, charm_ids: Array[String]) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		if charm_id == Charm.ROUND_NUMBER and score > 0 and score % 10 == 0:
			bonus += 20
	return bonus

# --- Geld: Effektkatalog ---------------------------------------------------------

## Einkommen beim Nehmen einer Hand (Straßenmusiker: $1 je Hand).
static func take_income(charm_ids: Array[String]) -> int:
	var income := 0
	for charm_id in charm_ids:
		if charm_id == Charm.STREET_MUSICIAN:
			income += 1
	return income

## True, wenn eine 6-Würfel-Kombination das Geld um 50% wachsen lässt (Goldrausch).
static func gold_rush_applies(charm_ids: Array[String], participating_count: int) -> bool:
	return charm_ids.has(Charm.GOLD_RUSH) and participating_count >= 6

## Lumpensammler: $1 je abgelegtem Würfel mit der Glückszahl oben (je Vorkommen).
static func rag_collector_income(values: Array[int], lucky_value: int, charm_ids: Array[String]) -> int:
	if lucky_value < 1:
		return 0
	var income := 0
	for charm_id in charm_ids:
		if charm_id == Charm.RAG_COLLECTOR:
			income += values.count(lucky_value)
	return income

## Scherbengericht: $1 je verworfenem Würfel eines Farkles (je Vorkommen).
static func farkle_shard_income(dice_count: int, charm_ids: Array[String]) -> int:
	var income := 0
	for charm_id in charm_ids:
		if charm_id == Charm.SHARD_COURT:
			income += dice_count
	return income

## Rundenende-Einkommen: Zinsgroschen ($1 je volle $10), Vollversammlung
## (+$3 bei 6 belegten Charm-Plätzen), Überflieger ($1 je 25 Punkte über Ziel).
static func round_end_income(money: int, charm_count: int, overflow_points: int, charm_ids: Array[String]) -> int:
	var income := 0
	for charm_id in charm_ids:
		match charm_id:
			Charm.INTEREST_PENNY:
				income += money / 10
			Charm.FULL_ASSEMBLY:
				if charm_count >= 6:  # Anzahl der Tisch-Plätze (siehe CharmRowView.SPOT_COUNT; hier als Literal, da core keine UI importiert)
					income += 3
			Charm.HIGH_FLYER:
				income += maxi(0, overflow_points) / 25
	return income

## Notgroschen: Mindest-Geldstand am Rundenende ($5), sonst 0 (kein Minimum).
static func money_floor(charm_ids: Array[String]) -> int:
	return 5 if charm_ids.has(Charm.EMERGENCY_FUND) else 0

# --- Farkle: Effektkatalog --------------------------------------------------------

## Anker: der erste Neuwurf jeder Hand kann nicht farkeln (reroll_index = wie
## viele Neuwürfe diese Hand schon hatte, INKLUSIVE des aktuellen).
static func anchor_saves(charm_ids: Array[String], reroll_index: int) -> bool:
	return charm_ids.has(Charm.ANCHOR) and reroll_index == 1

## Standuhr: Farkle verdoppelt die aktuellen Rundenpunkte.
static func farkle_doubles_points(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.GRANDFATHER_CLOCK)

## Flickenteppich: Farkle behält die Höchste-Zahl-Wertung des Wurfs.
static func farkle_keeps_high_card(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.PATCHWORK_RUG)

## Phönixfeder: rettet einmal pro Run eine verlorene Runde (siehe scene_root).
static func has_phoenix(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.PHOENIX_FEATHER)

# --- Pool / Shop: Effektkatalog ----------------------------------------------------

## Magnetring: Würfel mit Kanten-Material werden zuerst gezogen.
static func draws_edges_first(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.MAGNET_RING)

## Frische Ware: neu gekaufte Würfel liegen vorn im Nachziehstapel.
static func draws_fresh_first(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.FRESH_GOODS)

## Recycling: die erste genommene Hand jeder Runde kehrt in den Stapel zurück.
static func recycles_first_hand(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.RECYCLING)

## Charm-Preis nach Skonto (min. $1, je Vorkommen $5 Rabatt).
static func charm_price(base_price: int, charm_ids: Array[String]) -> int:
	var price := base_price
	for charm_id in charm_ids:
		if charm_id == Charm.CASH_DISCOUNT:
			price -= 5
	return maxi(1, price)

## Blätter-Gebühr nach Wechselgeld (min. $1, je Vorkommen $1 Rabatt).
static func flip_fee(base_fee: int, charm_ids: Array[String]) -> int:
	var fee := base_fee
	for charm_id in charm_ids:
		if charm_id == Charm.SMALL_CHANGE:
			fee -= 1
	return maxi(1, fee)

## Pack-Preis nach Feinschmecker (Tageskarte halbiert) und Schnäppchenjäger
## ($2 Rabatt je Vorkommen); min. $1. pack_id siehe ShopController.PACKS.
static func pack_price(base_price: int, pack_id: String, charm_ids: Array[String]) -> int:
	var price := float(base_price)
	if pack_id == "tageskarte" and charm_ids.has(Charm.GOURMET):
		price /= 2.0
	for charm_id in charm_ids:
		if charm_id == Charm.BARGAIN_HUNTER:
			price -= 2.0
	return maxi(1, int(round(price)))

## Kleingedrucktes: Chance auf volle Rückerstattung eines Pack-Kaufs
## (20% je Vorkommen, gedeckelt bei 80%).
static func pack_refund_chance(charm_ids: Array[String]) -> float:
	var chance := 0.0
	for charm_id in charm_ids:
		if charm_id == Charm.FINE_PRINT:
			chance += 0.2
	return minf(chance, 0.8)

## Gütesiegel: Shop-Würfel sind immer veredelt (siehe DiceOffer).
static func forces_refinement(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.SEAL_OF_QUALITY)

## Chip-Coupon-Wert (Doppelte Perforation: +$1 je Vorkommen).
static func chip_coupon_value(base_value: int, charm_ids: Array[String]) -> int:
	var value := base_value
	for charm_id in charm_ids:
		if charm_id == Charm.DOUBLE_PERFORATION:
			value += 1
	return value

## Gravierstift: einmal pro Runde wird ein Ätzungs-Coupon nicht verbraucht.
static func has_engraving_pen(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.ENGRAVING_PEN)
