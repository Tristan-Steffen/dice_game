class_name CharmEffects
## Reine Effekt-Logik der Charms (siehe Charm) - keine Nodes, nur Rechnen,
## analog zu DiceScoring. Jeder Charm wirkt über seine id (Charm.id) und wird
## hier zentral per match aufgelöst, damit ein neuer Charm nur hier + als neue
## Fabrikmethode in charm.gd ergänzt werden muss.
##
## Die Effekte sind nach Wirkungsort in Gruppen sortiert: Augenwert (einzelner
## Würfel), Wertung (Multiplikator/Bonus/Verdopplung ganzer Hände), Geld,
## Farkle-Milderung und Pool/Shop. Jede öffentliche Funktion nimmt die Liste
## der besessenen Charm-ids und summiert/kombiniert die passenden Beiträge -
## mehrere Charms stapeln sich also.

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
	return value

static func _apply_eye_value(charm_id: String, face_value: int, value: int) -> int:
	match charm_id:
		"rabbits_foot":
			return value + face_value if face_value == 6 else value
		"four_leaf_clover":
			return value + face_value if face_value == 4 else value
		"golden_scarab":
			return value + face_value if face_value == 5 else value
		"lucky_cigarettes":
			return 6 if face_value == 1 else value
		"fox_tail":
			return 4 if face_value == 3 else value
		"pencil_stub":
			return 3 if face_value == 2 else value
		_:
			return value

# --- Wertung (ganze Hand) ----------------------------------------------------

## Zusätzlicher Kombi-Multiplikator für die Kategorie key (siehe
## DiceScoring.score_category) - z.B. Hufeisen: Full House +1.
static func mult_bonus(key: String, charm_ids: Array[String]) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		match charm_id:
			"horseshoe":
				if key == "full_house":
					bonus += 1
			"ladybug":
				if key == "two_kind" or key == "two_pair":
					bonus += 1
			"pearl_necklace":
				if key == "four_kind_and_pair" or key == "three_pairs" or key == "double_three_kind":
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
			"rainbow_trout":
				if key == "small_straight" or key == "large_straight":
					bonus += 10
			"collectors_amulet":
				bonus += other_charms
	return bonus

## Multiplikator auf die GESAMTE Hand (nach mult/flat), nur unter bestimmten
## Bedingungen - z.B. Zauberkarte: erste genommene Hand der Runde ×2. Liefert
## sonst 1.
static func score_multiplier(charm_ids: Array[String], is_first_hand: bool) -> int:
	var mult := 1
	if is_first_hand:
		for charm_id in charm_ids:
			if charm_id == "magic_card":
				mult *= 2
	return mult

# --- Geld --------------------------------------------------------------------

## Fester Extra-Betrag beim Erreichen des Rundenziels (siehe
## scene_root.gd: _on_round_complete) - z.B. Glücksgroschen +2$.
static func round_clear_bonus(charm_ids: Array[String]) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		if charm_id == "old_penny":
			bonus += 2
	return bonus

## Extra-Auszahlung je noch nicht gezogenem Würfel, zusätzlich zum Basiswert
## (siehe scene_root.gd: MONEY_PER_UNUSED_DIE) - z.B. Sparschwein +1$/Würfel.
static func unused_die_bonus(charm_ids: Array[String]) -> int:
	var bonus := 0
	for charm_id in charm_ids:
		if charm_id == "piggy_bank":
			bonus += 1
	return bonus

## Sofort-Einkommen für einen überlebten Farkle (Runde geht weiter, siehe
## scene_root.gd: _on_farkle) - z.B. Kristallkugel +1$.
static func farkle_survival_income(charm_ids: Array[String]) -> int:
	var income := 0
	for charm_id in charm_ids:
		if charm_id == "crystal_ball":
			income += 1
	return income

# --- Farkle-Milderung --------------------------------------------------------

## True, wenn der erste Farkle einer Runde verziehen werden soll (Hand läuft
## weiter statt verworfen zu werden) - Schornsteinfeger, siehe
## scene_root.gd: _on_farkle.
static func forgives_first_farkle(charm_ids: Array[String]) -> bool:
	return charm_ids.has("chimney_sweep")

## Anteil der Punkte, der bei einem (nicht verziehenen) Farkle erhalten bleibt
## statt null - Umgedrehter Spiegel: 0.5, sonst 0.0. Bei mehreren solchen
## Charms zählt der stärkste.
static func farkle_kept_fraction(charm_ids: Array[String]) -> float:
	var fraction := 0.0
	for charm_id in charm_ids:
		if charm_id == "backwards_mirror":
			fraction = maxf(fraction, 0.5)
	return fraction

# --- Pool / Shop -------------------------------------------------------------

## Zusätzliche Würfel, die dem Rundenpool beigemischt werden (siehe
## scene_root.gd: _start_new_round) - Glücksknoten: +1.
static func extra_round_dice(charm_ids: Array[String]) -> int:
	var extra := 0
	for charm_id in charm_ids:
		if charm_id == "lucky_knot":
			extra += 1
	return extra

## True, wenn Spezialwürfel (nicht "normal") im Rundenpool nach vorne sortiert
## werden, damit sie zuerst gezogen werden - Wünschelrute, siehe
## scene_root.gd: _start_new_round.
static func draws_specials_first(charm_ids: Array[String]) -> bool:
	return charm_ids.has("dowsing_rod")

## Effektiver Würfelpreis im Shop nach Rabatt-Charms (siehe
## scene_root.gd: _on_shop_die_clicked) - Trickdieb-Manschette: -20%.
static func die_price(base_price: int, charm_ids: Array[String]) -> int:
	var price := float(base_price)
	for charm_id in charm_ids:
		if charm_id == "con_artist_cuff":
			price *= 0.8
	return int(round(price))
