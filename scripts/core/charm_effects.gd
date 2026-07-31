class_name CharmEffects
## Reine Effekt-Logik der Charms, id-dispatcht (ids: Konstanten in Charm).
## Nach Wirkungsort gruppiert; mehrere/duplizierte Charms stapeln sich.
## Ein neuer Charm braucht nur hier + eine Fabrikmethode in charm.gd.
##
## Trigger-Reihenfolge der Wertung (fix, KEINE Ausnahmen). Zwei Charm-Klassen:
##   - WÜRFELGEBUNDEN (die_charm_*-Hooks): der Effekt hängt an einem konkreten
##     Würfel (Breitband je Kombi-Würfel, Leuchtturm/Hochstapler am höchsten,
##     Beherit am niedrigsten gewerteten). Sie feuern MIT ihrem Würfel in der
##     Würfelphase - und je Aktivierung erneut (Quecksilber, Hasenpfote & Co.,
##     Echo-Kammer).
##   - STATISCH (charm_*-Hooks): der Effekt hängt an Hand/Zustand, nicht an
##     einem einzelnen Würfel. Sie feuern NACH allen Würfeln, strikt in
##     Besitz-Reihenfolge - Boni und Faktoren wirken an ihrer Position.
## Ablauf: 1. Würfel in Reihen-Ordnung (DiceScoring.trigger_order); je
## Aktivierung Augen -> Material -> würfelgebundene Charms (additiv, dann
## Krits). 2. Statische Charms in Besitz-Reihenfolge. 3. Nach Basis × Mult:
## Gesamtzahl-Effekte (charm_total_*_at). Weil Krits am Würfel hängen können,
## ist die Reihen-Ordnung wertungsrelevant - Vorschau, Wertung und Anzeige
## nutzen deshalb dieselbe kanonische Ordnung.

## Alles-oder-nichts: +Mult je Voll-Neuwurf (auch für die Tisch-Anzeige genutzt).
const ALL_OR_NOTHING_MULT := 5

## Flache Dauer-Boni ohne Bedingung (Hausjoker, Gratis Getränk).
const HOUSE_JOKER_MULT := 4
const FREE_DRINK_BASE := 50

## Volle Hand: so viele Würfel muss eine Kombination nutzen (Midashandschuh).
const FULL_HAND_DICE := 6

## Gleichmacher: Basispunkt-Boden je beteiligtem Würfel.
const EQUALIZER_FLOOR := 10

## Pendel: akkumulierter Mult (scene_root: +2 je Neuwurf-Würfel, -1 je genommenem,
## nie unter 0) - überlebt Runden. Eigene Funktion, weil der Tisch-Chip denselben
## Wert zeigen muss, den die Wertung rechnet.
static func pendulum_mult(ctx: Dictionary) -> int:
	return maxi(0, int(ctx.get(CTX_PENDULUM, 0)))

## Schlüssel des ctx-Dictionaries (Wurf-/Runden-Zustand der Effektkatalog-Charms).
## const, damit ein Tippfehler beim Setzen (scene_root) ODER Lesen ein Compile-
## Fehler ist - nicht der stille Null-Rückfall von ctx.get(). Werte je Schlüssel:
##   PENDULUM      int   - akkumulierter Pendel-Mult (überlebt Runden)
##   FULL_REROLLS  int   - Neuwürfe ALLER 6 seit dem letzten Nehmen (Alles-oder-nichts)
##   STREAK        int   - genommene Hände in Folge ohne Farkle (Momentum)
##   POOL_EMPTY    bool  - kein Würfel mehr im Nachziehstapel (Feierabendbier)
##   AFTER_FARKLE  bool  - erste Hand nach einem Farkle (Galgenhumor)
##   FARKLE_STACKS int   - Farkles des gesamten Runs (Zerbrochener Spiegel)
##   LATE_SLOTS    Array - Slots aus den letzten 6 des Stapels (Bodensatz)
##   SPOTLIGHT     String- hervorgehobene Kombination der Runde (Rampenlicht),
##                         "" sobald sie kassiert ist
const CTX_PENDULUM := "pendulum_acc"
const CTX_FULL_REROLLS := "full_rerolls"
const CTX_STREAK := "streak"
const CTX_POOL_EMPTY := "pool_empty"
const CTX_AFTER_FARKLE := "after_farkle"
const CTX_FARKLE_STACKS := "farkle_stacks"
const CTX_LATE_SLOTS := "late_slots"
const CTX_SPOTLIGHT := "spotlight_combo"

# --- Drei getrennte Mechaniken am einzelnen Würfel ---------------------------
# 1. transform_value:  der Würfel ZEIGT einen anderen Wert - wirkt auf
#    Kombinations-Erkennung UND Punkte (läuft VOR DiceScoring).
# 2. retrigger_count:  der Würfel löst zusätzlich aus wie Quecksilber -
#    Augen und Material-Effekte feuern erneut (zählt MaterialEffects).
# 3. eye_value:        reine Basispunkt-Anpassung, erkennungsblind.

## Feste Kettenreihenfolge 1->6, 2->3, 3->4, 4->5, 5->6, 7/9->8: aufsteigend,
## damit die Kette weiterläuft - eine 2 steigt mit allen vier Kettencharms bis
## zur 6. Jedes Ergebnis (6 oder 8) liegt außerhalb der Auslösewerte, die Kette
## bleibt also idempotent - Mehrfachanwendung im Pipeline-Stapel (best_hand ->
## score_category) ist gefahrlos.
static func transform_value(face_value: int, charm_ids: Array[String]) -> int:
	var value := face_value
	if value == 1 and charm_ids.has(Charm.LUCKY_CIGARETTES):
		value = 6
	if value == 2 and charm_ids.has(Charm.PENCIL_STUB):
		value = 3
	if value == 3 and charm_ids.has(Charm.FOX_TAIL):
		value = 4
	if value == 4 and charm_ids.has(Charm.TOP_HAT):
		value = 5
	if value == 5 and charm_ids.has(Charm.SILVER_DOLLAR):
		value = 6
	# Achterknoten: der einzige Verwandler, der von OBEN kommt - gravierte Seiten
	# über 6 rutschen zur 8, was auch die Kombinationsziffer (%10) verschiebt.
	if (value == 7 or value == 9) and charm_ids.has(Charm.EIGHT_KNOT):
		value = 8
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
			value += 10
	# Gleichmacher zuletzt (unabhängig von der Besitz-Reihenfolge): min. 10.
	if charm_ids.has(Charm.EQUALIZER):
		value = maxi(value, EQUALIZER_FLOOR)
	return value

# --- Würfelphase: würfelgebundene Charms (feuern MIT ihrem Würfel, je
# Auslösung EINMAL - die Aktivierungs-Schleife liegt beim Aufrufer) -----------

## Basispunkt-Beitrag der Besitz-Position j am beteiligten Würfel slot.
## scored: alle gewerteten Slots - nur der Vorreiter braucht sie.
static func die_charm_base_at(j: int, slot: int, key: String, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, scored: Array[int] = []) -> int:
	match charm_ids[j]:
		Charm.BROADBAND:
			return 5
		Charm.STREET_SWEEPER:
			if key == DiceScoring.SMALL_STRAIGHT or key == DiceScoring.LARGE_STRAIGHT:
				return 6
		Charm.FRONT_RUNNER:
			# Nur am vordersten gewerteten Würfel, dort die ganze Augensumme.
			if slot == first_participating(values, scored):
				return _participating_sum(values, scored)
	return 0

## Mult-Beitrag der Besitz-Position j am beteiligten Würfel slot (Bodensatz:
## +3 je spät gezogenem Würfel; Prime Time: Augenzahl, wenn sie prim ist).
## value_override > 0: feuernde Augenzahl eines Leiterbahn-Glieds - der Effekt
## rechnet mit ihr, Slot-Bezüge (Bodensatz) bleiben beim Würfel.
static func die_charm_mult_at(j: int, slot: int, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, value_override: int = 0) -> int:
	match charm_ids[j]:
		Charm.SEDIMENT:
			var late: Array = ctx.get(CTX_LATE_SLOTS, [])
			if late.has(slot):
				return 3
		Charm.PRIME_TIME:
			# Knochen lässt Seiten über 6 wachsen - darum echt prüfen, nicht 2/3/5.
			var value := value_override if value_override > 0 else (values[slot] if slot < values.size() else 0)
			if is_prime(value):
				return value
	return 0

## Ziel-Mult der Besitz-Position j am Würfel slot: Leuchtturm/Hochstapler
## meinen den HÖCHSTEN gewerteten Würfel und feuern mit ihm. Das Ziel bestimmt
## IMMER die oben liegende Augenzahl - value_override ändert nur den Betrag.
static func die_charm_target_mult_at(j: int, slot: int, values: Array[int], charm_ids: Array[String], participating: Array[int] = [], value_override: int = 0) -> int:
	match charm_ids[j]:
		Charm.LIGHTHOUSE, Charm.HIGH_STACKER:
			if slot == target_die(values, participating, true):
				return value_override if value_override > 0 else values[slot]
	return 0

## Krit der Besitz-Position j am Würfel slot: Beherit multipliziert den
## AKTUELLEN Mult mit der NIEDRIGSTEN gewerteten Augenzahl - mit seinem
## Würfel, je Auslösung (eine gewertete 1 heißt ×1 = Ausfall). Ziel wie oben
## immer über die oben liegenden Werte; value_override nur für den Betrag.
static func die_charm_crit_at(j: int, slot: int, values: Array[int], charm_ids: Array[String], participating: Array[int] = [], value_override: int = 0) -> int:
	match charm_ids[j]:
		Charm.BEHERIT:
			if slot == target_die(values, participating, false):
				return maxi(1, value_override if value_override > 0 else values[slot])
	return 1

## Primzahl-Test für Augenzahlen (Seiten können durch Knochen beliebig wachsen).
static func is_prime(value: int) -> bool:
	if value < 2:
		return false
	var d := 2
	while d * d <= value:
		if value % d == 0:
			return false
		d += 1
	return true

## Summe aller Pro-Würfel-Basisbeiträge für slot (über alle Besitz-Positionen).
static func die_charm_base(slot: int, key: String, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, scored: Array[int] = []) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += die_charm_base_at(j, slot, key, values, charm_ids, ctx, scored)
	return bonus

## Summe aller Pro-Würfel-Multbeiträge für slot.
static func die_charm_mult(slot: int, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += die_charm_mult_at(j, slot, values, charm_ids, ctx)
	return bonus

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
		Charm.RAINBOW_TROUT:
			if key == DiceScoring.SMALL_STRAIGHT or key == DiceScoring.LARGE_STRAIGHT:
				return 10
	return 0

static func mult_bonus(key: String, charm_ids: Array[String]) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += mult_bonus_at(j, key, charm_ids)
	return bonus

# --- Nach-Phase (auf die fertige Punktzahl, Besitz-Reihenfolge) ---------------

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
## Pro-Würfel-Charms liegen in die_charm_base_at). Der Vollzähler ist KEIN
## base_bonus mehr - er weitet die gewertete Menge (scored_indices), damit auch
## unbeteiligte Würfel Augen, Material und Pro-Würfel-Charms auslösen.
static func charm_base_bonus_at(j: int, key: String, values: Array[int], participating: Array[int], charm_ids: Array[String], _ctx: Dictionary = {}) -> int:
	match charm_ids[j]:
		Charm.FREE_DRINK:
			return FREE_DRINK_BASE
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

## Slots der exakten Paare eines Wurfs (Zwillingsring): gruppiert wird nach der
## KOMBINATIONSZIFFER wie bei der Hand-Erkennung (11 und 31 sind ein Paar), je
## Gruppe mit genau zwei Würfeln steht hier der höherwertige Slot - bei
## Gleichstand der kleinere. Einzige Quelle für Wirkung UND Pulse.
static func twin_pair_slots(values: Array[int]) -> Array[int]:
	var slots: Array[int] = []
	var seen_digits: Array[int] = []
	for i in values.size():
		var digit := DiceScoring._digit(values[i])
		if seen_digits.has(digit):
			continue
		seen_digits.append(digit)
		var group: Array[int] = []
		for k in values.size():
			if DiceScoring._digit(values[k]) == digit:
				group.append(k)
		if group.size() != 2:
			continue
		slots.append(group[0] if values[group[0]] >= values[group[1]] else group[1])
	return slots

## Kombi-Multiplikator der Position j (Effektkatalog; Pendel kann nie negativ
## beitragen). Pro-Würfel-Charms liegen in die_charm_mult_at.
static func charm_mult_bonus_at(j: int, key: String, values: Array[int], materials: Array[String], charm_ids: Array[String], ctx: Dictionary = {}, participating: Array[int] = []) -> int:
	match charm_ids[j]:
		Charm.HOUSE_JOKER:
			return HOUSE_JOKER_MULT
		Charm.PENDULUM:
			return pendulum_mult(ctx)
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
		Charm.TWIN_RING:
			# Jedes exakte Paar im Wurf: Mult += höchste Augenzahl des Paars.
			var twins := 0
			for slot in twin_pair_slots(values):
				twins += values[slot]
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

## Gewertete Slots: normal die beteiligten, mit Vollzähler ALLE liegenden Würfel
## (0..die_count) - so lösen auch unbeteiligte Würfel Augen, Material und Pro-
## Würfel-Charms aus. Immer slot-sortiert (Trigger links nach rechts).
static func scored_indices(participating: Array[int], die_count: int, charm_ids: Array[String]) -> Array[int]:
	if not charm_ids.has(Charm.FULL_COUNTER):
		return participating
	var all: Array[int] = []
	for i in die_count:
		all.append(i)
	return all

## ALLGEMEINE REGEL für Charms, die genau EINEN Würfel nach seiner Augenzahl
## meinen (Hochstapler/Leuchtturm höchste, Beherit niedrigste, Flickenteppich
## höchste): bei Gleichstand gewinnt der ERSTE passende Würfel - der mit dem
## kleinsten Slot. Deshalb wird aufsteigend gelaufen und nur bei ECHT besserem
## Wert übernommen. -1 = kein Kandidat.
static func target_die(values: Array[int], candidates: Array[int], highest: bool) -> int:
	var best := -1
	for i in values.size():
		if not candidates.has(i):
			continue
		if best < 0 or (values[i] > values[best] if highest else values[i] < values[best]):
			best = i
	return best

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
## bleiben unberührt. 1 = kein Krit. Nur STATISCHE Krits (Galgenhumor ×4
## nach Farkle, Feierabendbier ×2 bei leerem Nachziehstapel) - Beherit ist
## würfelgebunden und lebt in die_charm_crit_at.
static func charm_crit_at(j: int, _values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, _participating: Array[int] = []) -> int:
	match charm_ids[j]:
		Charm.GALLOWS_HUMOR:
			if ctx.get(CTX_AFTER_FARKLE, false):
				return 4
		Charm.AFTER_WORK_BEER:
			if ctx.get(CTX_POOL_EMPTY, false):
				return 2
	return 1

# --- Geld: Effektkatalog -------------------------------------------------------

## Goldader: Zuschlag, den JEDER auslösende Gold-Träger zusätzlich zahlt - $1 je
## anderem Material-Träger der Kombination, $3 wenn dieser selbst Gold ist.
## Stapelt je Charm-Vorkommen.
static func gold_vein_bonus(materials: Array[String], participating: Array[int], charm_ids: Array[String]) -> int:
	var stacks := charm_ids.count(Charm.GOLD_VEIN)
	if stacks == 0:
		return 0
	var gold := 0
	var other := 0
	for i in participating:
		var carrier: String = materials[i] if i < materials.size() else ""
		if carrier == DieMaterial.GOLD:
			gold += 1
		elif carrier != "":
			other += 1
	# "andere": der auslösende Träger ist selbst Gold und zählt sich nicht mit.
	return stacks * (3 * maxi(0, gold - 1) + other)

## Straßenmusiker: $1 je beteiligtem Würfel beim Nehmen.
static func take_income(charm_ids: Array[String], participating_count: int = 1) -> int:
	var income := 0
	for charm_id in charm_ids:
		if charm_id == Charm.STREET_MUSICIAN:
			income += participating_count
	return income

## Midashandschuh: die Hand muss ALLE sechs Würfel werten - erst dann vergoldet
## sie jede oben liegende Seite (GameRun.apply_midas_glove mutiert die Würfel).
static func midas_applies(charm_ids: Array[String], participating_count: int) -> bool:
	return charm_ids.has(Charm.MIDAS_GLOVE) and participating_count >= FULL_HAND_DICE

## Rampenlicht: das Casino stellt je Runde eine Kombination ins Licht.
static func has_spotlight(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.SPOTLIGHT)

## Löst das Rampenlicht der Position j bei DIESER Hand aus? Es wertet nicht -
## es bekommt trotzdem seinen Schritt in der Zähl-Animation, damit die Stufe
## an seiner Dock-Position steigt und nicht erst nach dem Zählen.
static func spotlight_fires_at(j: int, key: String, charm_ids: Array[String], ctx: Dictionary = {}) -> bool:
	return charm_ids[j] == Charm.SPOTLIGHT and key != "" and key == String(ctx.get(CTX_SPOTLIGHT, ""))

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

## Überflieger: je geräumte Überladungs-Stufe der Runde. Stufen sind gedeckelt,
## also braucht der Satz keine Obergrenze - und der Doppellader (zwei ⚡ je Stufe)
## ändert nichts, gezählt wird der BALKEN.
const HIGH_FLYER_PER_STAGE := 5

## Rundenende-Einnahmen EINZELN je Besitz-Position: Zinsgroschen ($1 je volle
## $10, max. $50) und Überflieger ($5 je geräumte Überladungs-Stufe), dazu der
## Glücksgroschen ($3, +$1 je vorheriger Auszahlung - NICHT je Überladungsstufe).
## Alle rechnen auf demselben money-Stand - die Besitz-Reihenfolge verschiebt
## keine Beträge. Grundlage der Auszahlungs-Zeremonie: der Spieler sieht,
## WELCHER Charm zahlt.
static func round_end_income_entries(money: int, cleared_stages: int, charm_ids: Array[String], penny_payouts: int = 0) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for j in charm_ids.size():
		var amount := 0
		match charm_ids[j]:
			Charm.INTEREST_PENNY:
				amount = mini(money / 10, 50)
			Charm.HIGH_FLYER:
				amount = maxi(0, cleared_stages) * HIGH_FLYER_PER_STAGE
			Charm.OLD_PENNY:
				amount = 3 + maxi(0, penny_payouts)
		if amount > 0:
			entries.append({"charm_index": j, "charm_id": charm_ids[j], "amount": amount})
	return entries

## Summe der Rundenende-Einnahmen - immer deckungsgleich mit den Einzelposten.
static func round_end_income(money: int, cleared_stages: int, charm_ids: Array[String], penny_payouts: int = 0) -> int:
	var income := 0
	for entry in round_end_income_entries(money, cleared_stages, charm_ids, penny_payouts):
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

## Phönixfeder: geworfene Würfel kehren beim ERSTEN Farkle der Runde in den
## Stapel zurück (scene_root zählt die Runden-Nutzung über phoenix_used_this_round).
static func has_phoenix(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.PHOENIX_FEATHER)

# --- Pool / Shop: Effektkatalog --------------------------------------------------

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
