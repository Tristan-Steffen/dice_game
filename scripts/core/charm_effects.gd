class_name CharmEffects
## Reine Effekt-Logik der Charms, id-dispatcht (ids: Konstanten in Charm).
## Nach Wirkungsort gruppiert; mehrere/duplizierte Charms stapeln sich.
## Ein neuer Charm braucht nur hier + eine Fabrikmethode in charm.gd.
##
## Trigger-Reihenfolge der Wertung (fix, KEINE Ausnahmen). Zwei Charm-Klassen:
##   - WÜRFELGEBUNDEN (die_charm_*-Hooks): der Effekt hängt an einem konkreten
##     Würfel (Mehrfachstecker je Kombi-Würfel, Hochstapler am höchsten,
##     Quadratur am niedrigsten gewerteten). Sie feuern MIT ihrem Würfel in der
##     Würfelphase - und je Aktivierung erneut (Quecksilber, Hasenpfote & Co.,
##     Echo-Kammer).
##   - STATISCH (charm_*-Hooks): der Effekt hängt an Hand/Zustand, nicht an
##     einem einzelnen Würfel. Sie feuern NACH allen Würfeln, strikt in
##     Besitz-Reihenfolge - Boni und Krits (Einserkult, Beherit & Co.) wirken an
##     ihrer Position.
## Ablauf: 1. Würfel in Reihen-Ordnung (DiceScoring.trigger_order); je
## Aktivierung Augen -> Material -> würfelgebundene Charms (additiv, dann
## Krits). 2. Statische Charms in Besitz-Reihenfolge. 3. Basis × Mult - danach
## kommt nichts mehr. Die Reihen-Ordnung ist wertungsrelevant (Echo-Kammer,
## Wasserfall, Stroboskop, Miasma) - Vorschau, Wertung und Anzeige nutzen
## deshalb dieselbe kanonische Ordnung.

## Roter Knopf: +Mult je Voll-Neuwurf (auch für die Tisch-Anzeige genutzt).
const ALL_OR_NOTHING_MULT := 15

## Flache Dauer-Boni ohne Bedingung (Hausjoker, Freigetränk).
const HOUSE_JOKER_MULT := 4
const FREE_DRINK_BASE := 50

## Volle Hand: so viele Würfel muss eine Kombination nutzen (Midashandschuh,
## Sechserpack).
const FULL_HAND_DICE := 6

## Quadratur: ab so vielen gewerteten Würfeln legt sie los.
const QUADRATURE_MIN_DICE := 4

## Beherit: unter so vielen gewerteten Würfeln bleibt das Siegel stumm - ein
## blankes Paar ruft nichts. Gezählt wird die GEWERTETE Menge, Vollzähler und
## Krypton also mit.
const BEHERIT_MIN_DICE := 3

## Equalizer: Basispunkt-Boden je beteiligtem Würfel.
const EQUALIZER_FLOOR := 10

## Kleinvieh: was eine beteiligte 1 oder 2 einbringt. BEIDE Anteile sind
## würfelgebunden (die_charm_base_at/die_charm_mult_at) - sie entspringen dem
## Charm, nicht dem Auge, und fliegen darum auch vom Dock-Pad.
const SMALL_FRY_BASE := 5
const SMALL_FRY_MULT := 2

static func is_small_fry_value(value: int) -> bool:
	return value == 1 or value == 2

## Charm-Plätze im Dock - spiegelt GameRun.CHARM_CAPACITY (core greift nicht in
## den Laufzustand; ein Test hält die beiden Zahlen gleich).
const CHARM_SLOTS := 6

## Leerer Sockel: Mult je freiem Charm-Platz.
const EMPTY_PLINTH_MULT := 3

## Leuchtfarbe: Mult je Rune auf einem gewerteten Würfel.
const LUMINOUS_PAINT_MULT := 2

## Vitrine: Mult je oben liegender Material-Seite - veredelt zählt sie mehr,
## statt zusätzlich. Schwungrad: je Hand in Folge.
const DISPLAY_CASE_MULT := 2
const DISPLAY_CASE_DOPED_MULT := 6
const MOMENTUM_MULT := 2

## Schutzfolie: Basispunkte je gewertetem Würfel ohne Material, Rune und Essenz.
const FACTORY_FINISH_BASE := 15

## Metronom: Basispunkte je Paar von Würfeln, die beide genau EINMAL zünden.
const METRONOME_BASE := 6

## Bodensatz: Mult je spät gezogenem Würfel. Stroboskop: Mult je Auslösung,
## die dieser Würfel schon hinter sich hat.
const SEDIMENT_MULT := 4
const STROBE_MULT := 2

## Standby-Licht: Mult je gelagerter Energie. Kilometerzähler: je gespielter
## Runde. Flaschenregal: je Essenz-Würfel in der Ablage.
const STANDBY_LIGHT_MULT := 1
const ODOMETER_MULT := 1
const BOTTLE_RACK_MULT := 4

## Erdungskabel: Mult je Pointer-Wurf, der danebengegangen ist.
const GROUND_WIRE_MULT := 5

## Inventur: Basispunkte je Material-Seite im GANZEN Würfelpool (ctx-Zahl).
const INVENTORY_BASE_PER_MATERIAL := 2

## Zahnlücke: eine Straße darf EIN Loch tragen (length Ziffern in length+1
## Ringpositionen). Der einzige Charm, der in die Erkennung greift.
static func straight_gap_allowed(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.GAP_TOOTH)

## Fallhöhe: Spanne der gewerteten Hand - höchster minus niedrigster GEZEIGTER
## Wert. Unter zwei gewerteten Würfeln gibt es keine.
static func scored_spread(values: Array[int], scored: Array[int]) -> int:
	if scored.size() < 2:
		return 0
	var high := -1
	var low := -1
	for slot in scored:
		if slot < 0 or slot >= values.size():
			continue
		var v := values[slot]
		if high < 0 or v > high:
			high = v
		if low < 0 or v < low:
			low = v
	return maxi(0, high - low)

## Pendel: akkumulierter Mult (scene_root: +2 je Neuwurf-Würfel, -1 je genommenem,
## nie unter 0) - überlebt Runden. Eigene Funktion, weil der Tisch-Chip denselben
## Wert zeigen muss, den die Wertung rechnet.
static func pendulum_mult(ctx: Dictionary) -> int:
	return maxi(0, int(ctx.get(CTX_PENDULUM, 0)))

## Schlüssel des ctx-Dictionaries (Wurf-/Runden-Zustand der Effektkatalog-Charms).
## const, damit ein Tippfehler beim Setzen (scene_root) ODER Lesen ein Compile-
## Fehler ist - nicht der stille Null-Rückfall von ctx.get(). Werte je Schlüssel:
##   PENDULUM      int   - akkumulierter Pendel-Mult (überlebt Runden)
##   FULL_REROLLS  int   - Neuwürfe ALLER 6 seit dem letzten Nehmen (Roter Knopf)
##   STREAK        int   - genommene Hände in Folge ohne Farkle (Schwungrad)
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

## Schutzgeld: Aufschlag auf JEDE gezeigte Augenzahl (je Vorkommen erneut). +10
## lässt die Kombinationsziffer (%10) unberührt - der Aufschlag zahlt, ohne die
## Erkennung zu verschieben.
const PROTECTION_OFFSET := 10

## Was eine Seite durch die CHARMS zeigt: erst die Verwandlungskette, dann der
## Schutzgeld-Aufschlag. Eigener Schritt hinter der Kette, weil er NICHT
## idempotent ist - er darf je Seite genau einmal laufen (die Essenz-Linse legt
## DiceScoring.shown_value darüber).
static func shown_by_charms(face_value: int, charm_ids: Array[String]) -> int:
	var offset := PROTECTION_OFFSET * charm_ids.count(Charm.PROTECTION_MONEY)
	return transform_value(face_value, charm_ids) + offset

static func shown_by_charms_all(values: Array[int], charm_ids: Array[String]) -> Array[int]:
	if charm_ids.is_empty():
		return values
	var result: Array[int] = []
	for value in values:
		result.append(shown_by_charms(value, charm_ids))
	return result

## Zusätzliche Auslösungen eines Würfels (je Vorkommen +1) - Hasenpfote 6,
## Kleeblatt 4. Gezählt wird der VERWANDELTE Wert: eine 1, die
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
	return extra

## Basispunkt-Beitrag eines Werts - wirkt NIE auf die Kategorie-Erkennung.
static func eye_value(face_value: int, charm_ids: Array[String]) -> int:
	# Equalizer: Boden von 10 auf der reinen Augenzahl.
	if charm_ids.has(Charm.EQUALIZER):
		return maxi(face_value, EQUALIZER_FLOOR)
	return face_value

# --- Würfelphase: würfelgebundene Charms (feuern MIT ihrem Würfel, je
# Auslösung EINMAL - die Aktivierungs-Schleife liegt beim Aufrufer) -----------

## Basispunkt-Beitrag der Besitz-Position j am beteiligten Würfel slot.
## order: die gewerteten Slots in ZÄHLREIHENFOLGE - die Quadratur misst an ihr.
## value_override > 0: die feuernde Augenzahl dieser Zündung (laufender Wert oder
## Pointer-Glied); Ziel- und Mengenbezüge bleiben an den liegenden Werten.
## materials: die Material-id der OBEN liegenden Seite je Slot - die Schutzfolie
## ist der einzige Charm hier, der nach ihr fragt.
static func die_charm_base_at(j: int, slot: int, key: String, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, order: Array[int] = [], value_override: int = 0, materials: Array[String] = []) -> int:
	match charm_ids[j]:
		Charm.BROADBAND:
			return 5
		Charm.FACTORY_FINISH:
			if _is_bare_die(slot, materials, ctx):
				return FACTORY_FINISH_BASE
		Charm.STREET_SWEEPER:
			if key == DiceScoring.SMALL_STRAIGHT or key == DiceScoring.LARGE_STRAIGHT:
				return 15
		Charm.QUADRATURE:
			# Erst ab einer breiten Hand, und dort nur am niedrigsten Würfel.
			if order.size() >= QUADRATURE_MIN_DICE and slot == target_die(values, order, false):
				var value := value_override if value_override > 0 else values[slot]
				return value * value
		Charm.SMALL_FRY:
			var small := value_override if value_override > 0 else (values[slot] if slot < values.size() else 0)
			if is_small_fry_value(small):
				return SMALL_FRY_BASE
	return 0

## Schutzfolie-Prüfung: der Würfel zeigt eine nackte Seite (kein Material, keine
## Rune) und trägt keine eigene Seele. Gemessen wird an der OBEREN Seite - mehr
## kennt die Wertung von einem Würfel nicht.
static func _is_bare_die(slot: int, materials: Array[String], ctx: Dictionary) -> bool:
	if slot < materials.size() and materials[slot] != "":
		return false
	if not DiceScoring.runes_for(ctx, slot).is_empty():
		return false
	return EssenceEffects.essence_at(DiceScoring.essences_in(ctx), slot) == ""

## Mult-Beitrag der Besitz-Position j am beteiligten Würfel slot (Bodensatz:
## +4 je spät gezogenem Würfel; Prime Time: Augenzahl, wenn sie prim ist).
## value_override > 0: feuernde Augenzahl eines Pointer-Glieds - der Effekt
## rechnet mit ihr, Slot-Bezüge (Bodensatz) bleiben beim Würfel.
static func die_charm_mult_at(j: int, slot: int, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, value_override: int = 0) -> int:
	match charm_ids[j]:
		Charm.SEDIMENT:
			var late: Array = ctx.get(CTX_LATE_SLOTS, [])
			if late.has(slot):
				return SEDIMENT_MULT
		Charm.PRIME_TIME:
			# Knochen lässt Seiten über 6 wachsen - darum echt prüfen, nicht 2/3/5.
			var value := value_override if value_override > 0 else (values[slot] if slot < values.size() else 0)
			if is_prime(value):
				return value
		Charm.SMALL_FRY:
			var small := value_override if value_override > 0 else (values[slot] if slot < values.size() else 0)
			if is_small_fry_value(small):
				return SMALL_FRY_MULT
		Charm.EQUAL_GRIND:
			# Sechs gleiche Seiten: Bedingung und Betrag stehen seit Handbeginn im
			# ctx, nie am laufenden Wert - ein Knochen darf sie nicht kippen.
			return DiceScoring.equal_faces_for(ctx, slot)
	return 0

## Ziel-Mult der Besitz-Position j am Würfel slot: der Hochstapler meint den
## höchsten Würfel der GEWERTETEN Menge - Vollzähler und Krypton also mit, nicht
## nur die Kombination. Das Ziel bestimmt IMMER die oben liegende Augenzahl -
## value_override ändert nur den Betrag.
static func die_charm_target_mult_at(j: int, slot: int, values: Array[int], charm_ids: Array[String], scored: Array[int] = [], value_override: int = 0) -> int:
	match charm_ids[j]:
		Charm.HIGH_STACKER:
			if slot == target_die(values, scored, true):
				return value_override if value_override > 0 else values[slot]
	return 0

## Krit der Besitz-Position j am Würfel slot: multipliziert den AKTUELLEN Mult -
## mit seinem Würfel, je Auslösung. Ziel immer über die oben liegenden Werte;
## value_override nur für den Betrag. Derzeit hängt hier kein Charm; der Hook
## bleibt als Platz für den nächsten würfelgebundenen Krit stehen.
static func die_charm_crit_at(_j: int, _slot: int, _values: Array[int], _charm_ids: Array[String], _participating: Array[int] = [], _value_override: int = 0) -> float:
	return 1.0

## Primzahl-Test für Augenzahlen (Seiten können durch Knochen beliebig wachsen).
## Gemerkt, weil dieselben Zahlen in Vorschau, Wertung und Schrittliste hundertfach
## wiederkehren - milliardengroße Seiten kosten sonst je Zündung eine Wurzelsuche.
static var _prime_cache := {}

static func is_prime(value: int) -> bool:
	if value < 2:
		return false
	if value < 4:
		return true
	if value % 2 == 0 or value % 3 == 0:
		return false
	if _prime_cache.has(value):
		return _prime_cache[value]
	# 6k±1: nach 2 und 3 kann kein Teiler woanders liegen, das dritteln die Schritte.
	var prime := true
	var d := 5
	while d * d <= value:
		if value % d == 0 or value % (d + 2) == 0:
			prime = false
			break
		d += 6
	_prime_cache[value] = prime
	return prime

## Wasserfall: der Mult-Beitrag DIESER Zündung. Er löst nur aus, wenn noch keine
## Augenzahl ausgelöst hat (last = CASCADE_UNSET) oder die gezählte STRIKT
## niedriger ist als die letzte auslösende - der Aufrufer schreibt last fort.
## Zustand über die ganze Hand, darum kein die_charm_*-Hook: die sind zustandslos.
const CASCADE_UNSET := -1

static func cascade_mult(value: int, last: int, charm_ids: Array[String]) -> int:
	var copies := charm_ids.count(Charm.WATERFALL)
	if copies == 0 or value <= 0:
		return 0
	if last != CASCADE_UNSET and value >= last:
		return 0
	return value * copies

## Dreifacher Boden: die BASISPUNKTE der Kombination zählen dreifach (je
## Vorkommen erneut) - ihr Mult bleibt unberührt, ebenso Augen, Materialien und
## Charms. points_for/mult_for selbst auch: Chips und Übertaktungspreise drucken
## weiter die reine Stufe.
static func combo_factor(charm_ids: Array[String]) -> int:
	var factor := 1
	for i in charm_ids.count(Charm.DOUBLE_BOTTOM):
		factor *= 3
	return factor

## Besitz-Positionen eines Charms (für Schritte, die kein die_charm_*-Hook sind).
static func charm_indices_of(charm_id: String, charm_ids: Array[String]) -> Array[int]:
	var out: Array[int] = []
	for j in charm_ids.size():
		if charm_ids[j] == charm_id:
			out.append(j)
	return out

## Summe aller Pro-Würfel-Basisbeiträge für slot (über alle Besitz-Positionen).
static func die_charm_base(slot: int, key: String, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, order: Array[int] = [], materials: Array[String] = []) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += die_charm_base_at(j, slot, key, values, charm_ids, ctx, order, 0, materials)
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
				return 8
		Charm.LADYBUG:
			if key == DiceScoring.TWO_KIND:
				return 4
		Charm.PEARL_NECKLACE:
			if key == DiceScoring.THREE_KIND:
				return 6
		Charm.RAINBOW_TROUT:
			if key == DiceScoring.SMALL_STRAIGHT or key == DiceScoring.LARGE_STRAIGHT:
				return 8
	return 0

static func mult_bonus(key: String, charm_ids: Array[String]) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += mult_bonus_at(j, key, charm_ids)
	return bonus

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

## Würfelpreis nach Rabatten (Trickdieb -33%, Mengenrabatt -$5 je Bündel, egal
## wie groß).
static func die_price(base_price: int, charm_ids: Array[String]) -> int:
	var price := float(base_price)
	for charm_id in charm_ids:
		match charm_id:
			Charm.CON_ARTIST_CUFF:
				price *= 0.67
			Charm.BULK_DISCOUNT:
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
static func charm_base_bonus_at(j: int, _key: String, values: Array[int], _participating: Array[int], charm_ids: Array[String], ctx: Dictionary = {}) -> int:
	match charm_ids[j]:
		Charm.FREE_DRINK:
			return FREE_DRINK_BASE
		Charm.INVENTORY:
			# Der Pool ist Laufzustand - er reitet als fertige Zahl im ctx herein.
			return INVENTORY_BASE_PER_MATERIAL * maxi(0, int(ctx.get(DiceScoring.CTX_POOL_MATERIALS, 0)))
		Charm.FRONT_RUNNER:
			# Die ganze Grube, nicht nur die Kombination - values sind alle liegenden.
			var total := 0
			for v in values:
				total += v
			return total
	return 0

static func charm_base_bonus(key: String, values: Array[int], participating: Array[int], charm_ids: Array[String], ctx: Dictionary = {}) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += charm_base_bonus_at(j, key, values, participating, charm_ids, ctx)
	return bonus

## Slots der exakten Paare eines Wurfs (Zwillingsring): gruppiert wird nach der
## KOMBINATIONSZIFFER wie bei der Hand-Erkennung (11 und 31 sind ein Paar), je
## Gruppe mit genau zwei Würfeln steht hier der NIEDRIGERE Slot - bei
## Gleichstand der kleinere. Einzige Quelle für die Zahl der Paare.
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
		slots.append(group[0] if values[group[0]] <= values[group[1]] else group[1])
	return slots

## Kombi-Multiplikator der Position j (Effektkatalog; Pendel kann nie negativ
## beitragen). Pro-Würfel-Charms liegen in die_charm_mult_at.
## scored: die GEWERTETEN Slots (Vollzähler/Krypton weiten sie über participating
## hinaus) - nur die Leuchtfarbe fragt danach.
static func charm_mult_bonus_at(j: int, _key: String, values: Array[int], materials: Array[String], charm_ids: Array[String], ctx: Dictionary = {}, _participating: Array[int] = [], scored: Array[int] = []) -> int:
	match charm_ids[j]:
		Charm.HOUSE_JOKER:
			return HOUSE_JOKER_MULT
		Charm.EMPTY_PLINTH:
			return EMPTY_PLINTH_MULT * maxi(0, CHARM_SLOTS - charm_ids.size())
		Charm.LUMINOUS_PAINT:
			var runes := 0
			for slot in scored:
				runes += DiceScoring.runes_for(ctx, slot).size()
			return LUMINOUS_PAINT_MULT * runes
		Charm.STANDBY_LIGHT:
			return STANDBY_LIGHT_MULT * maxi(0, int(ctx.get(DiceScoring.CTX_CHARGE, 0)))
		Charm.ODOMETER:
			return ODOMETER_MULT * maxi(0, int(ctx.get(DiceScoring.CTX_ROUND, 0)))
		Charm.BOTTLE_RACK:
			return BOTTLE_RACK_MULT * maxi(0, int(ctx.get(DiceScoring.CTX_DISCARD_SOULS, 0)))
		Charm.GROUND_WIRE:
			# Ein Fehlwurf entlädt sich - die Vorschau kennt die Zündungen nicht
			# und sieht darum nichts.
			return GROUND_WIRE_MULT * DiceScoring.pointer_misses_in(ctx)
		Charm.PENDULUM:
			return pendulum_mult(ctx)
		Charm.ALL_OR_NOTHING:
			return ALL_OR_NOTHING_MULT * int(ctx.get(CTX_FULL_REROLLS, 0))
		Charm.MOMENTUM:
			return MOMENTUM_MULT * int(ctx.get(CTX_STREAK, 0))
		Charm.BROKEN_MIRROR:
			return int(ctx.get(CTX_FARKLE_STACKS, 0))
		Charm.EVEN_COMPANY:
			if not values.is_empty() and values.all(func(v: int) -> bool: return v % 2 == 0):
				return 8
		Charm.ODD_PATH:
			if not values.is_empty() and values.all(func(v: int) -> bool: return v % 2 == 1):
				return 8
		Charm.HERMIT_CRAB:
			if charm_ids.size() <= 2:
				return 6
		Charm.DISPLAY_CASE:
			var display := 0
			for i in materials.size():
				if materials[i] == "":
					continue
				var lvl := MaterialEffects.level_in(DiceScoring.level_info_for(ctx, i))
				display += DISPLAY_CASE_DOPED_MULT if lvl >= DieMaterial.MAX_LEVEL else DISPLAY_CASE_MULT
			return display
		Charm.COLLECTORS_AMULET:
			return 2 * maxi(0, charm_ids.size() - 1)
		Charm.DROP_HEIGHT:
			return scored_spread(values, scored)
	return 0

static func charm_mult_bonus(key: String, values: Array[int], materials: Array[String], charm_ids: Array[String], ctx: Dictionary = {}, participating: Array[int] = [], scored: Array[int] = []) -> int:
	var bonus := 0
	for j in charm_ids.size():
		bonus += charm_mult_bonus_at(j, key, values, materials, charm_ids, ctx, participating, scored)
	return bonus

static func _participating_are_ones(values: Array[int], participating: Array[int]) -> bool:
	if participating.size() != 2:
		return false
	for i in participating:
		if i >= values.size() or values[i] != 1:
			return false
	return true

## Echo-Kammer: zusätzliche ANTRITTE des zuerst gewerteten Würfels - das ist der
## KOPF der Zählreihenfolge (Würfel-Achse, additiv), Augen UND Material-Effekte
## feuern erneut. Den Slot bekommt MaterialEffects.die_trigger_count über echo_slot.
static func echo_retriggers(charm_ids: Array[String]) -> int:
	return charm_ids.count(Charm.ECHO_CHAMBER)

## Rücklicht: zusätzliche ANTRITTE des zuletzt gewerteten Würfels - das SCHLUSS-
## LICHT der Zählreihenfolge, das Gegenstück zur Echo-Kammer. Bei einer Hand aus
## einem Würfel ist er Kopf UND Schluss und bekommt beide Zugaben.
static func tail_retriggers(charm_ids: Array[String]) -> int:
	return charm_ids.count(Charm.TAIL_LIGHT)

## Metronom: Basispunkte eines Würfels, der genau EINMAL zündet - je Einmal-
## Zünder VOR ihm in der Zählreihenfolge, der Takt baut sich also auf. singles
## sind genau diese Slots in eben dieser Reihenfolge (DiceScoring.
## single_trigger_slots), weil ein zustandsloser die_charm_*-Hook die
## Auslösungen der Mitwürfel nicht kennen kann.
static func metronome_base(slot: int, singles: Array[int], charm_ids: Array[String]) -> int:
	var copies := charm_ids.count(Charm.METRONOME)
	if copies == 0:
		return 0
	var pos := singles.find(slot)
	if pos <= 0:
		return 0
	return METRONOME_BASE * copies * pos

## Stroboskop: Mult DIESER Zündung - die erste bleibt leer, jede weitere zahlt
## +2 je Zündung davor. firing_index ist nullbasiert über beide Achsen des Würfels.
static func strobe_mult(firing_index: int, charm_ids: Array[String]) -> int:
	var copies := charm_ids.count(Charm.STROBE)
	if copies == 0 or firing_index <= 0:
		return 0
	return STROBE_MULT * copies * firing_index

## Sechserpack: zusätzliche Antritte JEDES Würfels, sobald die Hand die volle
## Sechs nutzt (Würfel-Achse, additiv wie die Echo-Kammer). scored_count ist die
## Zahl der gewerteten Würfel - beim Vollzähler also alle liegenden.
static func full_hand_retriggers(charm_ids: Array[String], scored_count: int) -> int:
	if scored_count < FULL_HAND_DICE:
		return 0
	return charm_ids.count(Charm.SIX_PACK)

## Zauberkarte: zusätzliche Antritte jedes Würfels DER KOMBINATION in der ERSTEN
## genommenen Hand einer Runde (Würfel-Achse, additiv - dieselbe Grammatik wie
## das Sechserpack). Beide Bedingungen wohnen HIER, damit kein Aufrufer die Regel
## halb nachbaut: ein Würfel, den nur der Vollzähler oder Krypton mitwertet,
## gehört nicht zur Kombination und bekommt nichts.
static func first_hand_retriggers(charm_ids: Array[String], is_first_hand: bool, in_combination: bool) -> int:
	if not is_first_hand or not in_combination:
		return 0
	return charm_ids.count(Charm.MAGIC_CARD)

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
## meinen (Hochstapler höchste, Beherit niedrigste, Flickenteppich
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

## KRIT der Position j: multipliziert den AKTUELLEN Mult (Mult 10, Krit ×3
## -> 30) - wie jeder Faktor an der Besitz-Position, spätere Mult-Boni
## bleiben unberührt. 1 = kein Krit. Nur STATISCHE Krits (Einserkult je
## gewürfelter 1, Galgenhumor nach Farkle, Feierabendbier bei leerem
## Nachziehstapel, Snake Eyes auf ein 1er-Paar, Zwillingsring auf die Paare des
## Wurfs, Beherit auf die niedrigste gewertete Augenzahl) - sie feuern EINMAL je
## Hand an ihrer Dock-Position.
## scored: die GEWERTETEN Slots (Vollzähler/Krypton weiten sie über participating
## hinaus) - nur das Beherit fragt nach ihrer Zahl.
static func charm_crit_at(j: int, values: Array[int], charm_ids: Array[String], ctx: Dictionary = {}, participating: Array[int] = [], key: String = "", scored: Array[int] = []) -> float:
	match charm_ids[j]:
		Charm.CULT_OF_ONE:
			return float(1 << values.count(1))
		Charm.BEHERIT:
			# Erst ab drei gewerteten Würfeln; Ziel bleibt der niedrigste Würfel der
			# Kombination, Gleichstand an den kleinsten Slot.
			if scored.size() < BEHERIT_MIN_DICE:
				return 1.0
			var low := target_die(values, participating, false)
			if low >= 0:
				return maxf(1.0, 1.0 + float(values[low]))
		Charm.GALLOWS_HUMOR:
			if ctx.get(CTX_AFTER_FARKLE, false):
				return 4.0
		Charm.AFTER_WORK_BEER:
			if ctx.get(CTX_POOL_EMPTY, false):
				return 5.0
		Charm.TWIN_RING:
			# Krit ×(1 + Zahl der exakten Paare im Wurf); ohne Paar kein Krit.
			var pairs := twin_pair_slots(values).size()
			return 1.0 + float(pairs) if pairs > 0 else 1.0
		Charm.SNAKE_EYES:
			# Genau ein 1er-Paar genommen: Krit ×Augensumme der Unbeteiligten.
			# Nie unter ×1 - eine Summe von 0 oder 1 darf den Mult nicht fressen.
			if key == DiceScoring.TWO_KIND and _participating_are_ones(values, participating):
				var eyes := 0
				for i in values.size():
					if not participating.has(i):
						eyes += values[i]
				return maxf(1.0, float(eyes))
	return 1.0

# --- Geld: Effektkatalog -------------------------------------------------------

## Goldader: Zuschlag DIESER Gold-Zündung - $1 je Gold-Seite, die in dieser Nahme
## schon VOR ihr aktiviert hat (je Charm-Vorkommen). Damit ist sie reihenfolge-
## abhängig: drei Gold-Würfel zu je einer Zündung zahlen $0, $1, $2. Gezählt wird
## die einzelne ZÜNDUNG, also auch jede Wiederholung und jedes gezündete Glied
## mit Gold-Zielseite; den laufenden Zähler führt MaterialEffects.
static func gold_vein_rate(prior_gold_firings: int, charm_ids: Array[String]) -> int:
	return charm_ids.count(Charm.GOLD_VEIN) * maxi(0, prior_gold_firings)

## Trinkgeldglas: JEDER Krit der Hand zahlt seinen ×-Wert bar, aufgerundet und je
## Exemplar - ×1,5 gibt $2, ×2,25 gibt $3. Gezahlt wird je EINZELNEM Einschlag,
## nie am Produkt: zwei Härteofen-Schläge zahlen zweimal. Ein Faktor von genau ×1
## ist kein Krit (dieselbe Zählregel wie beim Ozon).
static func tip_money(crit_x: float, charm_ids: Array[String]) -> int:
	if is_equal_approx(crit_x, 1.0):
		return 0
	return ceili(crit_x) * charm_ids.count(Charm.TIP_JAR)

## Straßenmusiker: $1 je beteiligtem Würfel beim Nehmen.
static func take_income(charm_ids: Array[String], participating_count: int = 1) -> int:
	var income := 0
	for charm_id in charm_ids:
		if charm_id == Charm.STREET_MUSICIAN:
			income += participating_count
	return income

## Schutzgeld: flache $3-Gebühr der Position j, fällig an IHREM Schritt der
## Charm-Phase. Der Aufrufer klemmt bei $0 - das Haus pfändet nichts, was nicht
## da ist.
const PROTECTION_FEE := 3

static func charm_fee_at(j: int, charm_ids: Array[String]) -> int:
	return PROTECTION_FEE if charm_ids[j] == Charm.PROTECTION_MONEY else 0

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
## Kombination alle SECHS Würfel nutzt - ein Rest-Wurf aus drei Würfeln ist keine
## volle Hand, auch wenn er alles nimmt, was daliegt.
static func gold_rush_applies(charm_ids: Array[String], participating_count: int, is_first_hand: bool = true) -> bool:
	return charm_ids.has(Charm.GOLD_RUSH) and is_first_hand \
		and participating_count >= FULL_HAND_DICE

## Goldrausch-Zuwachs: 20% des aktuellen Geldes, max. $30.
static func gold_rush_income(money: int) -> int:
	return mini(maxi(0, money) / 5, 30)

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

## Jackpotglocke: Prämie, wenn die ERSTE genommene Hand der Runde das Rundenziel
## überbietet (je Vorkommen).
const JACKPOT_BELL_MONEY := 10

static func jackpot_income(charm_ids: Array[String], hand_points: int, goal: int,
		is_first_hand: bool) -> int:
	if not is_first_hand or hand_points <= goal:
		return 0
	return charm_ids.count(Charm.JACKPOT_BELL) * JACKPOT_BELL_MONEY

## Quotenblatt: gewonnene Nebenwetten zahlen 100 % mehr BARGELD (je Vorkommen,
## aufgerundet). Ladung und Ware bleiben unberührt.
const ODDS_SHEET_FACTOR := 2.0

static func side_bet_money(amount: int, charm_ids: Array[String]) -> int:
	var payout := amount
	if payout <= 0:
		return payout
	for charm_id in charm_ids:
		if charm_id == Charm.ODDS_SHEET:
			payout = ceili(float(payout) * ODDS_SHEET_FACTOR)
	return payout

# --- Energie: Effektkatalog ------------------------------------------------------

## Dynamo: Energie, die die Besitz-Position j am Ende einer GERÄUMTEN Runde
## prägt (0 = kein Dynamo). Gebucht in der Rundenende-Zeremonie, das Licht
## fliegt hinterher - wie jede andere ⚡-Quelle.
const DYNAMO_CHARGE := 1

static func round_end_charge_at(j: int, charm_ids: Array[String]) -> int:
	return DYNAMO_CHARGE if charm_ids[j] == Charm.DYNAMO else 0

## Trostpreis: jeder Fumble wirft eine Energie ab (je Vorkommen).
const CONSOLATION_CHARGE := 1

static func fumble_charge(charm_ids: Array[String]) -> int:
	return charm_ids.count(Charm.CONSOLATION_PRIZE) * CONSOLATION_CHARGE

## Supraleiter: Nachlass auf den Übertaktungs-Preis (je Vorkommen 1 ⚡); der
## Aufrufer klemmt bei 1 - gratis übertaktet niemand.
static func overclock_discount(charm_ids: Array[String]) -> int:
	return charm_ids.count(Charm.SUPERCONDUCTOR)

## Hehlerware: Nachlass auf ein Schwarzmarkt-ANGEBOT (je Vorkommen 1 ⚡). Der
## Neuwurf bleibt flach - er ist keine Ware.
static func secret_price_cut(charm_ids: Array[String]) -> int:
	return charm_ids.count(Charm.FENCED_GOODS)

## Freispiel: der erste Dreh eines Ladenbesuchs geht aufs Haus.
static func has_free_spin(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.FREE_SPIN)

## Überflieger: je geräumte Überladungs-Stufe der Runde. Stufen sind gedeckelt,
## also braucht der Satz keine Obergrenze - und der Doppellader (zwei ⚡ je Stufe)
## ändert nichts, gezählt wird der BALKEN.
const HIGH_FLYER_PER_STAGE := 5

## Deckel des Zinsgroschens - gilt je Exemplar auf dessen eigener Grundlage.
const INTEREST_PENNY_CAP := 20

## Pfandregal: $1 je drei versiegelten Paketen im Lager, gedeckelt.
const DEPOSIT_SHELF_PER := 3
const DEPOSIT_SHELF_CAP := 15

## Rundenende-Einnahmen EINZELN je Besitz-Position: Zinsgroschen ($1 je volle
## $10, max. $20), Überflieger ($5 je geräumte Überladungs-Stufe), Glücksgroschen
## ($3, +$1 je vorheriger Auszahlung - NICHT je Überladungsstufe) und der
## Notgroschen, der auf seinen Mindeststand auffüllt.
##
## Gerechnet wird mit einem LAUFENDEN Stand: jeder Geld-Charm sieht, was die
## Charms links von ihm schon gezahlt haben. Zwei Zinsgroschen verzinsen sich
## also gegenseitig, und die Dock-Reihenfolge entscheidet über Geld genauso, wie
## sie längst über die Wertung entscheidet. Der Deckel des Zinsgroschens gilt je
## Exemplar auf dessen eigener Grundlage. Grundlage der Auszahlungs-Zeremonie:
## der Spieler sieht, WELCHER Charm zahlt.
static func round_end_income_entries(money: int, cleared_stages: int, charm_ids: Array[String], penny_payouts: int = 0, pack_stock: int = 0) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var projected := money
	for j in charm_ids.size():
		var amount := 0
		match charm_ids[j]:
			Charm.INTEREST_PENNY:
				amount = mini(projected / 10, INTEREST_PENNY_CAP)
			Charm.HIGH_FLYER:
				amount = maxi(0, cleared_stages) * HIGH_FLYER_PER_STAGE
			Charm.OLD_PENNY:
				amount = old_penny_payout(penny_payouts)
			Charm.DEPOSIT_SHELF:
				amount = mini(maxi(0, pack_stock) / DEPOSIT_SHELF_PER, DEPOSIT_SHELF_CAP)
			Charm.EMERGENCY_FUND:
				# Auf den LAUFENDEN Stand auffüllen - sonst ersetzte er, was die
				# Charms vor ihm schon gewährt haben.
				amount = maxi(0, money_floor(charm_ids) - projected)
		if amount > 0:
			entries.append({"charm_index": j, "charm_id": charm_ids[j], "amount": amount})
		projected += amount
	return entries

## Summe der Rundenende-Einnahmen - immer deckungsgleich mit den Einzelposten.
static func round_end_income(money: int, cleared_stages: int, charm_ids: Array[String], penny_payouts: int = 0, pack_stock: int = 0) -> int:
	var income := 0
	for entry in round_end_income_entries(money, cleared_stages, charm_ids, penny_payouts, pack_stock):
		income += int(entry["amount"])
	return income

## Glücksgroschen: $3, und je bereits geleisteter Auszahlung $1 mehr. Als eigene
## Funktion, weil der Dock-Chip denselben Betrag anzeigt, den die Abrechnung
## später bucht - zwei Formeln liefen sonst irgendwann auseinander.
static func old_penny_payout(penny_payouts: int) -> int:
	return 3 + maxi(0, penny_payouts)

## Notgroschen: Mindest-Geldstand am Rundenende, sonst 0.
const EMERGENCY_FUND_FLOOR := 45

static func money_floor(charm_ids: Array[String]) -> int:
	return EMERGENCY_FUND_FLOOR if charm_ids.has(Charm.EMERGENCY_FUND) else 0

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

## Frische Ware: beseelte Würfel liegen vorn im Nachziehstapel.
static func draws_essences_first(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.FRESH_GOODS)

## Bumerang: die erste genommene Hand jeder Runde kehrt in den Stapel zurück.
static func recycles_first_hand(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.RECYCLING)

## Charm-Preis nach Rabattmarke (je Vorkommen -$5, min. $1).
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

## Gütesiegel: Shop-Würfel tragen immer eine Material-Seite, eine davon veredelt.
static func forces_refinement(charm_ids: Array[String]) -> bool:
	return charm_ids.has(Charm.SEAL_OF_QUALITY)

## Zwinge: Chance, dass eine gepresste Datenzelle die Pressung ÜBERSTEHT - sie
## wirft ihre volle Beute ab und bleibt trotzdem im Regal. Je Vorkommen 25 %,
## gedeckelt wie das Kleingedruckte: eine Zelle, die nie ausbrennt, wäre kein
## Glück mehr, sondern ein zweites Testmodus-Häkchen.
const CLAMP_SURVIVE_CHANCE := 0.25
const CLAMP_SURVIVE_CAP := 0.75

static func pack_survive_chance(charm_ids: Array[String]) -> float:
	return minf(charm_ids.count(Charm.CLAMP) * CLAMP_SURVIVE_CHANCE, CLAMP_SURVIVE_CAP)

