class_name MaterialEffects
## Reine Wirkung der Materialien (siehe DieMaterial). Ein Material sitzt auf
## EINER Seite und wirkt nur, wenn die Seite oben liegt UND zur Kombination
## gehört. Materialien wirken NUR über die genommene Kombination - verworfene
## und gefumbelte Würfel lösen nichts aus. Zwei Aufrufpunkte: Wertungs-Boni
## (base_bonus/mult_bonus, auch in Vorschau/Farkle-Vergleich) und Nehmen-Effekte
## (apply_take_effects, einmal beim echten Nehmen).
## values/materials sind parallele Arrays je Wurf-Slot.
##
## DOTIERUNG: jedes Material steht normal oder dotiert (DieDefinition.levels).
## Dotiert ist nie nur eine größere Zahl - mal skaliert es (Bernstein, Gold,
## Knochen), mal verwandelt es (Rubin und Glas kriten).

## Gold zahlt je Träger beim Nehmen; der Goldschmied legt auf beide Zustände drauf.
const GOLD_PAYOUT := 3
const GOLDSMITH_BONUS := 3
const GOLD_PAYOUT_DOPED := 7

## Rubin: fester Mult je Träger (Blutdiamant addiert die Augenzahl).
const RUBY_MULT := 4
const RUBY_CRIT := 2              # dotiert kritet, statt zu addieren

## Bernstein-Grundwert; das Bernsteinzimmer legt +30 je Bernstein-Auslösung
## drauf, dotiert wie undotiert.
const AMBER_BASE := 20
const AMBER_ROOM_SURPLUS := 30
const AMBER_EYE_FACTOR := 5       # dotiert: nur noch Augensumme, dafür ×5

## Knochen wächst normal flach und dotiert prozentual (mind. +10); Glas schrumpft
## flach und halbiert sich dotiert - beides je Auslösung am schon veränderten Wert.
const BONE_GROWTH := 2
const BONE_GROWTH_MIN_DOPED := 10
const BONE_GROWTH_PERCENT_DOPED := 20
const GLASS_SHRINK := 1
const GLASS_SHRINK_PERCENT_DOPED := 50

## Glas zählt normal höchstens eine 6; dotiert addiert es gar nicht mehr, sondern
## kritet mit der halben Augenzahl.
const GLASS_EYE_CAP := 6
const GLASS_CRIT_DIVISOR := 2.0

## Glasbläserpfeife: Glas schrumpft weiter, aber nie unter diesen Wert.
const GLASSBLOWER_LUNG_FLOOR := 6

## Kupfer speist je Zündung Energie; dotiert das Doppelte. Was über den Speicher
## hinausläuft, zahlt bar (GameRun.book_copper_charge) - dieselbe Überlauf-
## Grammatik wie die Stufen-Auszahlung.
const COPPER_CHARGE := 1
const COPPER_CHARGE_DOPED := 2
const COPPER_OVERFLOW_MONEY := 2

## Bericht der Nehmen-Effekte für die UI.
class TakeReport:
	extends RefCounted

	var money: int = 0
	## Geld, das EINZELNE Zündungen erzeugt haben (Goldseiten, Seelen-Geld). Es
	## steckt NICHT in money: die Zähl-Zeremonie zahlt es im Moment der Zündung,
	## der Zug meldet es nur noch als Summe (siehe plan_activation_money).
	var activation_money: int = 0
	var charge: int = 0  # Energie aus Funkenflug-Runenn (je Zug einmal je Seite)
	## Energie aus Kupfer-Seiten - JE ZÜNDUNG, darum getrennt von charge: nur sie
	## läuft bei vollem Speicher in Geld über (GameRun.book_copper_charge).
	var copper_charge: int = 0
	## Slots, deren Kupfer gezündet hat - je Eintrag eine Zündung.
	var copper: Array[int] = []
	var grown: Array[int] = []  # Slots, deren Seite gewachsen ist (Knochen/Helium)
	var shrunk: Array[int] = []  # Slots, deren Seite geschrumpft ist (Glas)
	## Slots, die Streulicht kassiert haben - die Zeremonie lässt genau die
	## aufleuchten, denn nur sie haben fürs Danebenliegen bezahlt.
	var stray: Array[int] = []
	## Slots, an denen ein Einbrand wirklich einen Verlust VERHINDERT hat. Der
	## einzige Moment, in dem dieser Schutz überhaupt sichtbar wird.
	var blocked: Array[int] = []
	## Slots, aus denen ein Funke gesprungen ist - je Eintrag ein ⚡ der Salve.
	var sparks: Array[int] = []
	## Slots, deren Radon-Seele in diesem Zug eine Seite angefressen hat.
	var decayed: Array[int] = []
	## Materiallose Würfel dieser Hand - der Neonmarker schreibt sie als Runden-
	## zähler fort (GameRun bucht, der Bericht meldet nur).
	var bare_dice: int = 0
	## Die Hintergrundstrahlung hat auch Ablage-Würfel wachsen lassen. Sie haben
	## keinen Grubenslot, also kann nur eine Flagge davon erzählen.
	var discard_grown: bool = false

	## Das GESAMTE Geld des Zuges - die Zeremonie zahlt activation_money je
	## Zündung, der Zug bucht money am Ende. Für Bilanzen und Tests.
	func total_money() -> int:
		return money + activation_money

## WÜRFEL-Achse des Slots i: wie oft der ganze Würfel antritt. Der Essenz-Faktor
## ist der einzige Faktor, alles andere addiert - die Echo-Kammer auf echo_slot,
## extra aus der Zählreihenfolge (Sauerstoff/Sonnenwind, die nur der Aufrufer
## kennt). scored_count = Zahl der gewerteten Würfel, für das Sechserpack.
## tail_slot = Schluss der Zählreihenfolge (Rücklicht), Gegenstück zu echo_slot.
## is_first_hand = erste genommene Hand der Runde, in_combination = dieser Slot
## gehört zur KOMBINATION (nicht bloß zur gewerteten Menge) - beides für die
## Zauberkarte, die nur die Kombinationswürfel meint.
static func die_trigger_count(i: int, charm_ids: Array[String], echo_slot: int = -1, essence_ids: Array[String] = [], is_stress: bool = false, extra: int = 0, scored_count: int = 0, tail_slot: int = -1, is_first_hand: bool = false, in_combination: bool = false) -> int:
	# Sternschnuppe: gedeckelt auf genau EINEN Antritt. Der Deckel sitzt in BEIDEN
	# Achsen-Funktionen, damit Wertung, Nehmen, Leiterbahn-Wurf und die Gold-
	# Vorabzählung dieselbe Zahl sehen.
	if EssenceEffects.caps_triggers_of(essence_ids, charm_ids):
		return 1
	var count := EssenceEffects.activation_factor_of(essence_ids, charm_ids, is_stress)
	if i == echo_slot:
		count += CharmEffects.echo_retriggers(charm_ids)
	if i == tail_slot:
		count += CharmEffects.tail_retriggers(charm_ids)
	count += CharmEffects.full_hand_retriggers(charm_ids, scored_count)
	count += CharmEffects.first_hand_retriggers(charm_ids, is_first_hand, in_combination)
	return maxi(1, count + extra)

## SEITEN-Achse: wie oft die obere Seite je Würfel-Trigger zündet. Rein additiv -
## Retrigger-Charms auf value (Hasenpfote & Co.), extra für das Nachglühen
## (RuneEffects.extra_activations). value ist der VERWANDELTE Wert.
static func face_trigger_count(value: int, charm_ids: Array[String], extra: int = 0, essence_ids: Array[String] = []) -> int:
	if EssenceEffects.caps_triggers_of(essence_ids, charm_ids):
		return 1
	return maxi(1, 1 + CharmEffects.retrigger_count(value, charm_ids) + extra)

## Zündungen der oberen Seite insgesamt: die beiden Achsen MULTIPLIZIEREN sich.
## Eine Quelle für Wertung, Schrittliste und Nehmen-Effekte.
static func total_trigger_count(i: int, charm_ids: Array[String], value: int = 0, echo_slot: int = -1, essence_ids: Array[String] = [], is_stress: bool = false, die_extra: int = 0, face_extra: int = 0, scored_count: int = 0, tail_slot: int = -1, is_first_hand: bool = false, in_combination: bool = false) -> int:
	return die_trigger_count(i, charm_ids, echo_slot, essence_ids, is_stress, die_extra, scored_count, tail_slot, is_first_hand, in_combination) \
		* face_trigger_count(value, charm_ids, face_extra, essence_ids)

## Härteofen: die AUSZAHLUNG einer dotierten Seite läuft zweimal - Basis, Mult,
## Geld und Wachstum. Die KOSTEN bleiben einfach (das Glas frisst sich weiter im
## alten Tempo): ein Charm darf einen Würfel nie schlechter machen. Der Krit wird
## darum auch nicht quadriert, sondern zweimal geschlagen - je Kopie ein Schlag.
static func payoff_repeats(level: int, charm_ids: Array[String]) -> int:
	return 2 if level >= DieMaterial.MAX_LEVEL and charm_ids.has(Charm.KILN) else 1

## Basis-Bonus EINER Auslösung des Slots i - nur der Träger, ohne Augen.
static func base_bonus_once(i: int, materials: Array[String], charm_ids: Array[String], level: int = 1, eye_sum: int = 0) -> int:
	return base_once_for(materials[i] if i < materials.size() else "", charm_ids, level, eye_sum)

## Wie base_bonus_once, aber direkt über die Material-id - so feuern auch
## Leiterbahn-Glieder (fremde Seite) über dieselbe Tabelle.
## eye_sum: Augensumme des Würfels - Bernstein zahlt sie immer, dotiert fünffach
## und ohne festen Zuschlag.
static func base_once_for(face_material: String, charm_ids: Array[String], level: int = 1, eye_sum: int = 0) -> int:
	if face_material != DieMaterial.AMBER:
		return 0
	var room := AMBER_ROOM_SURPLUS if charm_ids.has(Charm.AMBER_ROOM) else 0
	var eyes := eye_sum * (AMBER_EYE_FACTOR if level >= DieMaterial.MAX_LEVEL else 1)
	return (_amber_flat(level) + room + eyes) * payoff_repeats(level, charm_ids)

## Mult-Bonus EINER Auslösung des Slots i: Rubin fest (der Blutdiamant legt die
## Augenzahl drauf); Glas + rohe Augenzahl der oberen Seite.
static func mult_bonus_once(i: int, values: Array[int], materials: Array[String], charm_ids: Array[String], level: int = 1) -> int:
	return mult_once_for(materials[i] if i < materials.size() else "", values[i], charm_ids, level)

## Wie mult_bonus_once über die Material-id; value ist die feuernde Augenzahl
## (beim Leiterbahn-Glied die der Zielseite). Was kritet, addiert hier NICHT
## (dotierter Rubin, dotiertes Glas) - siehe mult_crit_once_for; nur der Blood
## Diamond bleibt beim Rubin additiv, damit der Krit nicht exponentiell wird.
static func mult_once_for(face_material: String, value: int, charm_ids: Array[String], level: int = 1) -> int:
	# Der Blutdiamant legt die Augenzahl EINMAL drauf, nie je Exemplar.
	var eye_stacks := int(charm_ids.has(Charm.BLOOD_DIAMOND))
	var repeats := payoff_repeats(level, charm_ids)
	if face_material == DieMaterial.RUBY:
		return (_ruby_mult(level) + value * eye_stacks) * repeats
	if face_material == DieMaterial.GLASS:
		return _glass_mult(value, level) * repeats
	return 0

## Material-Krit EINER Auslösung: eine Seite trägt genau ein Material - also
## höchstens ein Faktor. 1 = kein Krit. Beide Kriter warten auf die Dotierung;
## unter ×1 drückt keiner, ein Krit macht eine Hand nie schlechter.
static func mult_crit_once_for(face_material: String, value: int, _charm_ids: Array[String], level: int) -> float:
	if level < DieMaterial.MAX_LEVEL:
		return 1.0
	match face_material:
		DieMaterial.RUBY:
			return float(RUBY_CRIT)
		DieMaterial.GLASS:
			return maxf(1.0, float(value) / GLASS_CRIT_DIVISOR)
	return 1.0

## Material-Infos eines Slots (Form wie DiceScoring.CTX_MATERIAL_LEVELS).
static func level_of(levels: Dictionary, slot: int) -> Dictionary:
	return levels.get(slot, {})

## Zustand aus einem solchen Eintrag - ohne Eintrag gilt normal.
static func level_in(info: Dictionary) -> int:
	return int(info.get("level", 1))

## Fester Bernstein-Zuschlag (dotiert zahlt nur noch Augensumme).
static func _amber_flat(level: int) -> int:
	return 0 if level >= DieMaterial.MAX_LEVEL else AMBER_BASE

## Additiver Rubin-Mult (dotiert kritet stattdessen).
static func _ruby_mult(level: int) -> int:
	return 0 if level >= DieMaterial.MAX_LEVEL else RUBY_MULT

# --- Wertwandel zwischen den Aktivierungen -------------------------------------
# Knochen wächst und Glas schrumpft ZWISCHEN den Auslösungen eines Zuges: die
# zweite Aktivierung zählt schon den gewachsenen Wert. Weil apply_take_effects
# dieselbe Rechnung dauerhaft in die Def schreibt, MUSS beides über diese
# Helfer laufen - sonst zeigt die Wertung eine andere Zahl als der Würfel.

## Knochenleim legt +3 auf den Wachstumsschritt - einmalig, nicht je Exemplar.
const BONE_GLUE_SURPLUS := 3

## Wachstumsschritt einer Knochen-Seite; der Knochenleim legt seinen Aufschlag auf
## beide Zustände drauf, nie als Faktor auf sie.
static func bone_growth_step(value: int, level: int, charm_ids: Array[String]) -> int:
	return _bone_step(value, level) + (BONE_GLUE_SURPLUS if charm_ids.has(Charm.BONE_GLUE) else 0)

## Knochenmark verlängert nicht den Schritt, sondern die Zahl der Auslösungen -
## flach eine zusätzliche, egal wie viele Exemplare im Dock stehen.
static func bone_trigger_count(charm_ids: Array[String]) -> int:
	return 2 if charm_ids.has(Charm.BONE_MARROW) else 1

## Glasbläserpfeife hebt nur den Boden - geschrumpft wird weiter.
static func glass_floor_for(charm_ids: Array[String]) -> int:
	var glass_floor := EtchingEffects.MIN_FACE_VALUE
	if charm_ids.has(Charm.GLASSBLOWER_LUNG):
		glass_floor = maxi(glass_floor, GLASSBLOWER_LUNG_FLOOR)
	return glass_floor

## Wachstum über triggers Auslösungen; dotiert rechnet die Seite ihren
## Prozentschritt je Auslösung am schon gewachsenen Wert neu.
static func grow_bone_value(value: int, level: int, charm_ids: Array[String], triggers: int) -> int:
	var result := value
	for _t in triggers:
		result += bone_growth_step(result, level, charm_ids)
	return result

## Schrumpft um step, nie unter floor_value (unveränderter Wert = kein Schritt).
static func shrink_value(value: int, step: int, floor_value: int) -> int:
	var target := maxi(floor_value, value - step)
	return target if target < value else value

## Wertwandel EINER Auslösung: Knochen wächst, Glas schrumpft, Helium hebt die
## obere Seite - dieselbe Folge wie apply_take_effects. Stickstoff (Essenz) und
## Einbrand (Rune dieser Seite) schützen vor jedem Verlust, ihr Glas schrumpft
## also nicht.
static func mutate_value_once(value: int, face_material: String,
		charm_ids: Array[String], level: int = 1, essence_ids: Array[String] = [],
		rune_ids: Array[String] = []) -> int:
	var result := value
	if face_material == DieMaterial.BONE:
		# Härteofen: das Wachstum ist eine Auszahlung und läuft dotiert doppelt.
		for _r in payoff_repeats(level, charm_ids):
			result = grow_bone_value(result, level, charm_ids, bone_trigger_count(charm_ids))
	if face_material == DieMaterial.GLASS and not value_protected(essence_ids, rune_ids):
		result = shrink_value(result, _glass_step(result, level), glass_floor_for(charm_ids))
	# Das Essenz-Wachstum reitet auf dem SCHON gewandelten Wert - der Druckkessel
	# rechnet prozentual, also muss die Zahl stimmen, auf die er fällt.
	return result + EssenceEffects.face_growth_of(essence_ids, charm_ids, result)

## Wertwandel EINER Glied-Zündung: wie mutate_value_once, aber OHNE das
## Essenz-Wachstum und ohne den Einbrand-Schutz - ein Glied ist eine fremde
## Seite, kein Aufblähen der Schale. Einzige Quelle, damit der eingefrorene
## Leiterbahn-Wurf und apply_take_effects nie auseinanderlaufen.
static func mutate_link_value_once(value: int, face_material: String, charm_ids: Array[String], level: int = 1, essence_ids: Array[String] = []) -> int:
	var result := value
	if face_material == DieMaterial.BONE:
		for _r in payoff_repeats(level, charm_ids):
			result = grow_bone_value(result, level, charm_ids, bone_trigger_count(charm_ids))
	if face_material == DieMaterial.GLASS and not EssenceEffects.protects_face_value_of(essence_ids):
		result = shrink_value(result, _glass_step(result, level), glass_floor_for(charm_ids))
	return result

## Verliert diese Seite überhaupt Wert? Stickstoff schützt den ganzen Würfel,
## der Einbrand nur seine eigene Seite.
static func value_protected(essence_ids: Array[String], rune_ids: Array[String]) -> bool:
	return EssenceEffects.protects_face_value_of(essence_ids) or RuneEffects.protects_face_value(rune_ids)

## Ansteckung: was eine Miasma-Seite NACH dieser Zündung an jeden anderen
## gewerteten Würfel abgibt (0 = nichts). Gerechnet auf dem schon gewandelten
## Wert, damit Knochen/Glas zuerst greifen; Stickstoff und Einbrand wehren die
## Halbierung ab - dann bekommt auch niemand etwas.
static func miasma_spread_once(value: int, essence_ids: Array[String], rune_ids: Array[String]) -> int:
	if not EssenceEffects.redistributes_faces_of(essence_ids):
		return 0
	if value_protected(essence_ids, rune_ids):
		return 0
	return maxi(0, value / 2)

## Was die Quelle dabei selbst verliert - mit dem Weihrauchfass nichts (der Dunst
## steckt weiter an, ohne dass die Zahl je kleiner wird).
static func miasma_self_loss(amount: int, charm_ids: Array[String]) -> int:
	return 0 if charm_ids.has(Charm.CENSER) else amount

## Dieselbe Ansteckung auf die LAUFENDEN Werte einer Hand (Wertung und
## Schrittliste; apply_take_effects läuft die gleiche Rechnung auf den Defs).
## Liefert den verteilten Betrag.
static func spread_miasma_once(running: Array[int], slot: int, scored: Array[int],
		essence_ids: Array[String], rune_ids: Array[String], charm_ids: Array[String]) -> int:
	if slot < 0 or slot >= running.size():
		return 0
	var amount := miasma_spread_once(running[slot], essence_ids, rune_ids)
	if amount <= 0:
		return 0
	running[slot] -= miasma_self_loss(amount, charm_ids)
	for other in scored:
		if other != slot and other >= 0 and other < running.size():
			running[other] += amount
	return amount

## Endwert der oberen Seite nach activations Auslösungen - genau der Wert, den
## apply_take_effects in die Def schreibt (per Test abgesichert).
static func value_after_activations(value: int, activations: int, face_material: String,
		charm_ids: Array[String], level: int = 1, essence_ids: Array[String] = [],
		rune_ids: Array[String] = []) -> int:
	var result := value
	for _a in maxi(0, activations):
		result = mutate_value_once(result, face_material, charm_ids, level, essence_ids, rune_ids)
	return result

## Basis-Boni der beteiligten Träger über ALLE Aktivierungen (Vorschau/Tests);
## jede Extra-Aktivierung zählt die Augen erneut. Rechnet mit dem LIEGENDEN
## Wert - den Wertwandel zwischen den Aktivierungen (Knochen/Glas) kennt nur
## DiceScoring._base_and_mult.
static func base_bonus(values: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String], echo_slot: int = -1, levels: Dictionary = {}) -> int:
	var bonus := 0
	for i in participating:
		var info := level_of(levels, i)
		var activations := total_trigger_count(i, charm_ids, values[i], echo_slot, [], false, 0, 0, participating.size())
		bonus += base_bonus_once(i, materials, charm_ids, level_in(info), int(info.get("eye_sum", 0))) * activations
		if activations > 1:
			bonus += CharmEffects.eye_value(values[i], charm_ids) * (activations - 1)
	return bonus

## Mult-Boni der beteiligten Träger über ALLE Aktivierungen (Vorschau/Tests).
## Nur ADDITIV und nur auf dem LIEGENDEN Wert - ein Material-Krit (dotierter
## Rubin, dotiertes Glas) und der Wertwandel zwischen den Aktivierungen
## (Knochen/Glas) lassen sich als Summe nicht ausdrücken; maßgeblich ist
## DiceScoring._base_and_mult.
static func mult_bonus(values: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String] = [], echo_slot: int = -1, levels: Dictionary = {}) -> int:
	var bonus := 0
	for i in participating:
		var level := level_in(level_of(levels, i))
		var effect_count := total_trigger_count(i, charm_ids, values[i], echo_slot, [], false, 0, 0, participating.size())
		bonus += mult_bonus_once(i, values, materials, charm_ids, level) * effect_count
	return bonus

## Nehmen-Effekte: mutiert die faces der Pool-Würfel direkt (dauerhaft).
## Gold zahlt seinen Satz (Goldschmied legt drauf); Knochen wächst
## (Knochenleim: +3 Aufschlag, Knochenmark lässt jede Knochen-Auslösung ein Mal
## mehr feuern); Glas schrumpft, nie unter das Floor
## (Glasbläserpfeife hebt es auf 6); Essenz-Geld (Neon, Natriumdampf) und
## Helium-Wachstum reiten in derselben Schleife. Alles je Effekt-Aktivierung.
## essences/order: Slot -> Essenz-id und die kanonische Zählreihenfolge - beide
## Achsen MÜSSEN dieselben sein wie in der Wertung (Argon & Co.). Gelaufen wird
## in genau dieser REIHENFOLGE (_take_order), weil die Ansteckung (Miasma) quer
## über die Würfel wirkt: wer später zählt, findet den Zuwachs schon vor.
## pointer_fires: der EINMAL ausgewürfelte Leiterbahn-Wurf (DiceScoring.
## CTX_POINTER_FIRES, Slot -> je Würfel-Trigger die gezündeten Glieder) - hier
## wird nie neu gewürfelt, sonst zahlte der Zug andere Glieder als er zählte.
## lying: ALLE Slots mit einem Würfel auf dem Tisch - nur so kann das Streulicht
## die ungewerteten Übriggebliebenen sehen. Runen liest diese Seite direkt aus
## den Defs (wie die Dotierung), nicht aus dem ctx.
## hands_taken/round_bare_dice: Rundenstand VOR dieser Hand (Mitternachtssonne,
## Neonmarker). discard_defs: die Ablage - nur das Radioteleskop greift hinein.
## participating sind die GEWERTETEN Slots (Vollzähler/Krypton weiten sie);
## combination ist die engere Menge der Kombinationswürfel - leer heißt "beide
## gleich", was ohne diese beiden Erweiterungen immer stimmt. Nur die Zauberkarte
## fragt nach ihr.
static func apply_take_effects(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String] = [], echo_slot: int = -1, essences: Dictionary = {}, order: Array[int] = [], is_stress: bool = false, lying: Array[int] = [], pointer_fires: Dictionary = {}, hands_taken: int = 0, round_bare_dice: int = 0, discard_defs: Array[DieDefinition] = [], combination: Array[int] = []) -> TakeReport:
	var combo_slots := participating if combination.is_empty() else combination
	# Die GEZEIGTEN Werte und der Schluss der Reihe: beide Achsen müssen exakt so
	# gezählt werden wie in der Wertung (Lichtsäule liest Gleichzahlen, das
	# Rücklicht das Schlusslicht), sonst driften Simulation und Def auseinander.
	var shown_values := _shown_values(defs, face_indices, charm_ids, essences)
	# Die Seiten-Achse liest den VERWANDELTEN Seitenwert - eingefroren vor jeder
	# Mutation, sonst zählte ein vom Miasma gewachsener Würfel andere Retrigger
	# als die Wertung.
	var charm_values := _charm_values(defs, face_indices, charm_ids)
	var tail_slot: int = int(order[order.size() - 1]) if not order.is_empty() else -1
	var is_first_hand := hands_taken == 0
	# Schwarzlicht zahlt je gewertetem Würfel ohne Material - einmal je Zug.
	var bare_dice := 0
	for k in participating:
		if k >= materials.size() or materials[k] == "":
			bare_dice += 1
	var report := TakeReport.new()
	report.bare_dice = bare_dice
	# Zündungs-Geld (Goldseiten, Seelen-Geld) zahlt die Zeremonie im Moment JEDER
	# Zündung - hier steht es nur noch als Summe, damit nichts doppelt bucht.
	report.activation_money = activation_money_total(plan_activation_money(defs, face_indices,
		materials, participating, charm_ids, echo_slot, essences, order, is_stress,
		pointer_fires, hands_taken, combination))
	for i in _take_order(order, participating):
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0:
			continue
		var face_material: String = materials[i] if i < materials.size() else ""
		var essence_ids := EssenceEffects.set_at(essences, i)
		var level := face_level(defs[i], face)
		var rune_ids := defs[i].runes_on(face)
		# Funkenflug speist EINEN Funken je Zug, nie je Zündung.
		var spark := RuneEffects.charge_for_take(rune_ids, charm_ids)
		report.charge += spark
		for _s in spark:
			report.sparks.append(i)
		# Retrigger prüft den VERWANDELTEN Wert - wie in der Wertung.
		var shown: int = charm_values[i] if i < charm_values.size() else 0
		# Die beiden Achsen, exakt wie DiceScoring sie zählt.
		var die_triggers := die_trigger_count(i, charm_ids, echo_slot, essence_ids, is_stress,
			EssenceEffects.extra_activations(i, order, essences, charm_ids, shown_values, hands_taken),
			participating.size(), tail_slot, is_first_hand, combo_slots.has(i))
		var face_triggers := face_trigger_count(shown, charm_ids, RuneEffects.extra_activations(rune_ids, charm_ids), essence_ids)
		var fires: Array = pointer_fires.get(i, [])

		# Zyanidgas laugt die eigene Schale aus: je ZUG einmal, nie je Auslösung.
		# Das Scheidewasser greift dazu die Gold-Seiten der Mitwürfel an.
		report.money += EssenceEffects.gold_face_money_of(essence_ids, defs[i].materials, charm_ids,
			_foreign_gold_faces(defs, participating, i))
		report.money += EssenceEffects.bare_die_money_of(essence_ids, bare_dice, charm_ids,
			round_bare_dice + bare_dice)

		# Der Einbrand hat wirklich etwas abgewehrt - nur dann lohnt die Geste.
		if face_material == DieMaterial.GLASS and RuneEffects.protects_face_value(rune_ids):
			report.blocked.append(i)

		# Knochen/Glas/Helium laufen Zündung für Zündung: der prozentuale Satz
		# rechnet sich am schon veränderten Wert neu. Verschachtelt wie in der
		# Wertung - je Würfel-Trigger erst die Seiten-Zündungen, dann die für
		# genau diesen Trigger gewürfelten Leiterbahn-Glieder.
		var before: int = defs[i].faces[face]
		var swelled := false
		var copper_once := copper_charge_once_for(face_material, level, charm_ids)
		for t in die_triggers:
			for _f in face_triggers:
				if copper_once > 0:
					report.copper_charge += copper_once
					report.copper.append(i)
				defs[i].faces[face] = mutate_value_once(defs[i].faces[face], face_material, charm_ids, level, essence_ids, rune_ids)
				# Strahlungsdruck bläht die GANZE Schale: die obere Seite ist über
				# mutate_value_once schon gewachsen, die übrigen fünf folgen je
				# Zündung - jede auf IHREM Wert, der Druckkessel rechnet prozentual.
				swelled = _swell_other_faces(defs[i], face, essence_ids, charm_ids) or swelled
				# Ansteckung an genau dieser Stelle - dieselbe wie in der Wertung.
				_infect_from(defs, face_indices, participating, i, face, essence_ids, rune_ids, charm_ids, report)
			for fire in (fires[t] if t < fires.size() else []):
				_fire_link(defs[i], int(fire["face"]), charm_ids, essence_ids, report, i)
		if defs[i].faces[face] > before:
			report.grown.append(i)
		elif defs[i].faces[face] < before:
			report.shrunk.append(i)
		elif swelled:
			report.grown.append(i)

		# Deterministische Glieder (Röntgenlicht, Korona, Kehrseite): EINMAL nach
		# allen Würfel-Triggern - anders als die gewürfelte Leiterbahn. Der Stichel
		# lässt die Kehrseite zweimal zünden (det_link_fire_count).
		for link_face in EssenceEffects.link_faces(defs[i], face, essence_ids,
				defs[i].runes_on(face), charm_ids):
			for _s in EssenceEffects.det_link_fire_count(face, link_face, rune_ids, charm_ids):
				_fire_link(defs[i], link_face, charm_ids, essence_ids, report, i)

		# Kontrastmittel: das Röntgenlicht belichtet die Achse durch - obere Seite
		# halbiert, Gegenseite verdreifacht, beides dauerhaft.
		_apply_contrast_agent(defs[i], face, essence_ids, charm_ids, report, i)

		# Radon zerfällt beim AUSLÖSEN, nicht bei der Abrechnung - aber erst NACH
		# allen Schreibvorgängen des Zuges: Knochen/Glas müssen exakt auf dem
		# value_after der Simulation landen (Drift-Doktrin), DANN frisst die
		# Strahlung. Einmal je Zug, nie je Auslösung; die laufende Kombination
		# bleibt unberührt, ihre Werte sind längst im ctx festgehalten.
		if EssenceEffects.decay_die(defs[i], charm_ids):
			report.decayed.append(i)

	if charm_ids.has(Charm.RECTIFIER):
		_rectify_faces(defs, face_indices, participating, essences, report)

	_spread_background_radiation(defs, participating, essences, charm_ids, lying, discard_defs, report)

	# Streulicht: das Gegen-Ereignis zum Gold. Was am Zugende UNGEWERTET auf dem
	# Tisch liegt und seine Runen-Seite zeigt, streut sein Licht ins Filz.
	for i in lying:
		if participating.has(i) or i >= defs.size() or i >= face_indices.size():
			continue
		var idle_face: int = face_indices[i]
		if idle_face < 0:
			continue
		var stray := RuneEffects.stray_money(defs[i].runes_on(idle_face), charm_ids)
		if stray > 0:
			report.money += stray
			report.stray.append(i)
	return report

## Geld, das EINZELNE Zündungen erzeugen - Gold-Seiten und Seelen-Geld. Es zahlt
## im Moment seiner Zündung, nicht am Zugende, also braucht die Zeremonie es in
## genau der Verschachtelung, die auch apply_take_effects läuft (Würfel-Trigger ->
## Seiten-Zündungen -> Glieder dieses Triggers, zuletzt die Essenz-Glieder).
## Parameter wie apply_take_effects. Ergebnis je Slot:
##   {"groups": [{"firings": [int], "links": [int]}], "det_links": [int], "total": int}
## EINE Quelle: der Zug meldet die Summe als activation_money und bucht sie nicht.
static func plan_activation_money(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String] = [], echo_slot: int = -1, essences: Dictionary = {}, order: Array[int] = [], is_stress: bool = false, pointer_fires: Dictionary = {}, hands_taken: int = 0, combination: Array[int] = []) -> Dictionary:
	var combo_slots := participating if combination.is_empty() else combination
	# Goldschmied und Goldader legen auf JEDEN Gold-Träger denselben Zuschlag -
	# additiv über jedem Satz, nie als Faktor auf ihn.
	var gold_surplus := (GOLDSMITH_BONUS if charm_ids.has(Charm.GOLDSMITH) else 0) \
		+ CharmEffects.gold_vein_bonus(materials, participating, charm_ids)
	var shown_values := _shown_values(defs, face_indices, charm_ids, essences)
	var tail_slot: int = int(order[order.size() - 1]) if not order.is_empty() else -1
	# Dotiertes Gold: +$1 je Gold-Seiten-Auslösung dieser Nahme - der Zähler steht
	# VOR der ersten Buchung fest.
	var gold_triggers := _gold_face_triggers(defs, face_indices, materials, participating, charm_ids, echo_slot, essences, order, is_stress, pointer_fires, shown_values, tail_slot, hands_taken, combo_slots)
	var plan := {}
	for i in participating:
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0:
			continue
		var face_material: String = materials[i] if i < materials.size() else ""
		var essence_ids := EssenceEffects.set_at(essences, i)
		var rune_ids := defs[i].runes_on(face)
		var shown := CharmEffects.shown_by_charms(defs[i].faces[face], charm_ids)
		var die_triggers := die_trigger_count(i, charm_ids, echo_slot, essence_ids, is_stress,
			EssenceEffects.extra_activations(i, order, essences, charm_ids, shown_values, hands_taken),
			participating.size(), tail_slot, hands_taken == 0, combo_slots.has(i))
		var face_triggers := face_trigger_count(shown, charm_ids, RuneEffects.extra_activations(rune_ids, charm_ids), essence_ids)
		# Je Zündung derselbe Betrag: Gold hängt am ZUSTAND der Seite, das Seelen-
		# Geld an ihrem Wert bei Zugbeginn - beides wandert innerhalb des Zuges nicht.
		var per_firing := gold_money_once_for(face_material, face_level(defs[i], face), gold_surplus, gold_triggers, charm_ids) \
			+ EssenceEffects.money_of(essence_ids, defs[i].faces[face], participating.size())
		var fires: Array = pointer_fires.get(i, [])
		var groups: Array[Dictionary] = []
		var total := 0
		for t in die_triggers:
			var firings: Array[int] = []
			for _f in face_triggers:
				firings.append(per_firing)
				total += per_firing
			var links: Array[int] = []
			for fire in (fires[t] if t < fires.size() else []):
				var fired := _link_money(defs[i], int(fire["face"]), charm_ids, gold_surplus, gold_triggers)
				links.append(fired)
				total += fired
			groups.append({"firings": firings, "links": links})
		var det_links: Array[int] = []
		for link_face in EssenceEffects.link_faces(defs[i], face, essence_ids, rune_ids, charm_ids):
			for _s in EssenceEffects.det_link_fire_count(face, link_face, rune_ids, charm_ids):
				var det := _link_money(defs[i], link_face, charm_ids, gold_surplus, gold_triggers)
				det_links.append(det)
				total += det
		plan[i] = {"groups": groups, "det_links": det_links, "total": total}
	return plan

## Summe eines Zündungs-Plans - was der Zug NICHT mehr bucht.
static func activation_money_total(plan: Dictionary) -> int:
	var total := 0
	for slot in plan:
		total += int(plan[slot]["total"])
	return total

## Geld EINER Zündung einer Seite: nur Gold zahlt je Zündung, der Härteofen
## zweimal. EINE Quelle für Plan und Zeremonie.
static func gold_money_once_for(face_material: String, level: int, surplus: int, triggers: int, charm_ids: Array[String]) -> int:
	if face_material != DieMaterial.GOLD:
		return 0
	return _gold_payout(level, surplus, triggers) * payoff_repeats(level, charm_ids)

## Energie EINER Zündung einer Seite: nur Kupfer speist, der Härteofen zweimal.
## EINE Quelle für obere Seite und Glied.
static func copper_charge_once_for(face_material: String, level: int, charm_ids: Array[String]) -> int:
	if face_material != DieMaterial.COPPER:
		return 0
	var amount := COPPER_CHARGE_DOPED if level >= DieMaterial.MAX_LEVEL else COPPER_CHARGE
	return amount * payoff_repeats(level, charm_ids)

## Gold EINER Glied-Zündung - das Glied trägt seine eigene Seite, also auch deren
## Zustand (nie den der oberen).
static func _link_money(def: DieDefinition, link_face: int, charm_ids: Array[String], surplus: int, triggers: int) -> int:
	if def == null or link_face < 0 or link_face >= def.faces.size():
		return 0
	var link_material: String = def.materials[link_face] if link_face < def.materials.size() else ""
	return gold_money_once_for(link_material, face_level(def, link_face), surplus, triggers, charm_ids)

## Die übrigen fünf Seiten unter Strahlungsdruck - jede wächst auf IHREM eigenen
## Wert (der Druckkessel rechnet prozentual). true, wenn wirklich etwas gewachsen ist.
static func _swell_other_faces(def: DieDefinition, up_face: int, essence_ids: Array[String], charm_ids: Array[String]) -> bool:
	var swelled := false
	for other_face in def.faces.size():
		if other_face == up_face:
			continue
		var growth := EssenceEffects.all_faces_growth_of(essence_ids, charm_ids, def.faces[other_face])
		if growth > 0:
			def.faces[other_face] += growth
			swelled = true
	return swelled

## Gold-Seiten aller ANDEREN gewerteten Würfel (Scheidewasser zählt sie).
static func _foreign_gold_faces(defs: Array[DieDefinition], participating: Array[int], slot: int) -> int:
	var count := 0
	for other in participating:
		if other == slot or other >= defs.size() or defs[other] == null:
			continue
		count += defs[other].materials.count(DieMaterial.GOLD)
	return count

## Kontrastmittel: beim Werten eines Röntgenlicht-Würfels halbiert sich seine
## obere Seite dauerhaft, seine Gegenseite verdreifacht sich. Einmal je Zug, nie
## je Auslösung; Stickstoff und Einbrand wehren die Halbierung ab - dann bleibt
## auch die Gegenseite, wie sie ist (wie bei der Ansteckung: kein Verlust, kein Gewinn).
static func _apply_contrast_agent(def: DieDefinition, face: int, essence_ids: Array[String],
		charm_ids: Array[String], report: TakeReport, slot: int) -> void:
	if def == null or not charm_ids.has(Charm.CONTRAST_AGENT) or not essence_ids.has(Essence.XRAY):
		return
	if face < 0 or face >= def.faces.size() or value_protected(essence_ids, def.runes_on(face)):
		return
	var loss: int = def.faces[face] / 2
	if loss <= 0:
		return
	def.faces[face] -= loss
	if not report.shrunk.has(slot):
		report.shrunk.append(slot)
	var opposite := DieDefinition.opposite_face(face)
	if opposite >= 0 and opposite < def.faces.size():
		def.faces[opposite] *= 3
		if not report.grown.has(slot):
			report.grown.append(slot)

## Ansteckung EINER Zündung auf die Defs: die obere Seite des Miasma-Würfels gibt
## die abgerundete Hälfte ihrer Augen ab, und GENAU dieser Betrag wächst sofort
## auf jeder anderen gewerteten Seite der Hand - noch bevor sie zählt. Dieselbe
## Stelle und dieselbe Rechnung wie DiceScoring._base_and_mult, damit Simulation
## und Def nicht driften; die Empfänger meldet sie selbst als gewachsen, weil ihr
## eigener Vorher/Nachher-Vergleich längst gelaufen sein kann.
static func _infect_from(defs: Array[DieDefinition], face_indices: Array[int], participating: Array[int],
		slot: int, face: int, essence_ids: Array[String], rune_ids: Array[String],
		charm_ids: Array[String], report: TakeReport) -> void:
	var amount := miasma_spread_once(defs[slot].faces[face], essence_ids, rune_ids)
	if amount <= 0:
		return
	defs[slot].faces[face] -= miasma_self_loss(amount, charm_ids)
	for other in participating:
		if other == slot or other >= defs.size() or other >= face_indices.size() or defs[other] == null:
			continue
		var other_face: int = face_indices[other]
		if other_face < 0 or other_face >= defs[other].faces.size():
			continue
		defs[other].faces[other_face] += amount
		if not report.grown.has(other):
			report.grown.append(other)

## Hintergrundstrahlung: wird sie gewertet, wachsen ALLE Seiten ALLER liegenden
## Würfel dauerhaft - sie selbst eingeschlossen. Wachstum, also nie vom Einbrand
## geblockt (der wehrt nur Verluste ab). Das Radioteleskop erreicht auch die
## Ablage; deren Würfel haben keinen Grubenslot, darum meldet sie eine Flagge.
static func _spread_background_radiation(defs: Array[DieDefinition], participating: Array[int],
		essences: Dictionary, charm_ids: Array[String], lying: Array[int],
		discard_defs: Array[DieDefinition], report: TakeReport) -> void:
	var growth := 0
	for i in participating:
		if EssenceEffects.grows_all_dice_of(EssenceEffects.set_at(essences, i)):
			growth += EssenceEffects.BACKGROUND_GROWTH
	if growth <= 0:
		return
	var touched: Array[int] = participating.duplicate()
	for i in lying:
		if not touched.has(i):
			touched.append(i)
	for slot in touched:
		if slot < 0 or slot >= defs.size() or defs[slot] == null:
			continue
		for face in defs[slot].faces.size():
			defs[slot].faces[face] += growth
		if not report.grown.has(slot):
			report.grown.append(slot)
	if not charm_ids.has(Charm.RADIO_TELESCOPE):
		return
	for die in discard_defs:
		if die == null:
			continue
		for face in die.faces.size():
			die.faces[face] += growth
		report.discard_grown = true

## Gleichrichter: die oberen Seiten aller gewerteten Würfel gehen dauerhaft auf
## ihren aufgerundeten Mittelwert. LETZTER Wertwandel des Zuges - nach Knochen,
## Glas, Kontrastmittel, Zerfall und Miasma, damit er die Endwerte mittelt.
## Geschützte Seiten (Stickstoff, Einbrand) dürfen nicht SCHRUMPFEN, zählen aber
## in den Mittelwert; Wachsen ist ihnen erlaubt.
static func _rectify_faces(defs: Array[DieDefinition], face_indices: Array[int], participating: Array[int], essences: Dictionary, report: TakeReport) -> void:
	var sum := 0
	var count := 0
	for i in participating:
		if i >= defs.size() or i >= face_indices.size() or defs[i] == null:
			continue
		var face: int = face_indices[i]
		if face < 0 or face >= defs[i].faces.size():
			continue
		sum += defs[i].faces[face]
		count += 1
	if count == 0:
		return
	var mean := ceili(float(sum) / float(count))
	for i in participating:
		if i >= defs.size() or i >= face_indices.size() or defs[i] == null:
			continue
		var face: int = face_indices[i]
		if face < 0 or face >= defs[i].faces.size():
			continue
		var current: int = defs[i].faces[face]
		if mean == current:
			continue
		if mean < current and value_protected(EssenceEffects.set_at(essences, i), defs[i].runes_on(face)):
			continue
		defs[i].faces[face] = mean
		if mean > current:
			if not report.grown.has(i):
				report.grown.append(i)
		elif not report.shrunk.has(i):
			report.shrunk.append(i)

## EINE Glied-Zündung auf die Def: Knochen/Glas wandeln die GLIED-Seite in IHREM
## Zustand (nie dem der oberen). Ein Glied kann mehrfach zünden - dann wandert
## der Wert Zündung für Zündung weiter, wie der eingefrorene Wurf ihn gezählt
## hat. Das Gold des Glieds zahlt der Plan, nicht diese Buchung.
static func _fire_link(def: DieDefinition, link_face: int, charm_ids: Array[String], essence_ids: Array[String], report: TakeReport, slot: int) -> void:
	if def == null or link_face < 0 or link_face >= def.faces.size():
		return
	var link_material: String = def.materials[link_face] if link_face < def.materials.size() else ""
	var link_level := face_level(def, link_face)
	# Ein Glied ist eine Zündung wie jede andere - auch sein Kupfer speist.
	var copper_once := copper_charge_once_for(link_material, link_level, charm_ids)
	if copper_once > 0:
		report.copper_charge += copper_once
		report.copper.append(slot)
	var before: int = def.faces[link_face]
	def.faces[link_face] = mutate_link_value_once(before, link_material, charm_ids, link_level, essence_ids)
	if def.faces[link_face] > before and not report.grown.has(slot):
		report.grown.append(slot)
	elif def.faces[link_face] < before and not report.shrunk.has(slot):
		report.shrunk.append(slot)

## Reihenfolge, in der die Nehmen-Effekte über die gewerteten Slots laufen: die
## Zählreihenfolge, denn die Ansteckung wirkt quer über die Würfel. Was die Reihe
## nicht nennt (ältere Aufrufer ohne order), hängt sich slot-sortiert hinten an.
static func _take_order(order: Array[int], participating: Array[int]) -> Array[int]:
	var walk: Array[int] = []
	for i in order:
		if participating.has(i) and not walk.has(i):
			walk.append(i)
	for i in participating:
		if not walk.has(i):
			walk.append(i)
	return walk

## Zustand des Materials DIESER Seite (Guard für Defs ohne volles levels-Array).
static func face_level(def: DieDefinition, face: int) -> int:
	return def.material_level(face) if def != null else 0

## Nur die Charm-Kette, ohne Essenz-Linse: die Seiten-Achse (Retrigger) liest
## genau diesen Wert, und er muss VOR jeder Mutation eingefroren sein.
static func _charm_values(defs: Array[DieDefinition], face_indices: Array[int], charm_ids: Array[String]) -> Array[int]:
	var out: Array[int] = []
	for k in defs.size():
		var face: int = face_indices[k] if k < face_indices.size() else -1
		if defs[k] == null or face < 0 or face >= defs[k].faces.size():
			out.append(0)
			continue
		out.append(CharmEffects.shown_by_charms(defs[k].faces[face], charm_ids))
	return out

## Die GEZEIGTEN Werte aller Slots - dieselbe Linse wie DiceScoring.shown_value
## (Charm-Kette, Schutzgeld, dann die Essenz-Linse), nur ohne den Rückgriff auf
## DiceScoring: die Nehmen-Seite darf nicht auf die Wertung zeigen.
static func _shown_values(defs: Array[DieDefinition], face_indices: Array[int], charm_ids: Array[String], essences: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for k in defs.size():
		var face: int = face_indices[k] if k < face_indices.size() else -1
		if defs[k] == null or face < 0 or face >= defs[k].faces.size():
			out.append(0)
			continue
		out.append(EssenceEffects.lens_value_of(EssenceEffects.set_at(essences, k),
			CharmEffects.shown_by_charms(defs[k].faces[face], charm_ids)))
	return out

## Gold-Satz; surplus = Charm-/Goldader-Aufschlag, triggers zählt nur dotiert.
static func _gold_payout(level: int, surplus: int, triggers: int) -> int:
	if level >= DieMaterial.MAX_LEVEL:
		return GOLD_PAYOUT_DOPED + surplus + triggers
	return GOLD_PAYOUT + surplus

## Wie oft in DIESER Nahme eine Gold-Seite zündet - beide Achsen aller
## beteiligten Slots plus jede GEZÜNDETE Leiterbahn und die Essenz-Glieder, in
## jedem Zustand.
static func _gold_face_triggers(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String], echo_slot: int, essences: Dictionary, order: Array[int], is_stress: bool, pointer_fires: Dictionary, shown_values: Array[int] = [], tail_slot: int = -1, hands_taken: int = 0, combination: Array[int] = []) -> int:
	var triggers := 0
	for i in participating:
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0:
			continue
		var essence_ids := EssenceEffects.set_at(essences, i)
		if i < materials.size() and materials[i] == DieMaterial.GOLD:
			var shown := CharmEffects.shown_by_charms(defs[i].faces[face], charm_ids)
			triggers += total_trigger_count(i, charm_ids, shown, echo_slot, essence_ids, is_stress,
				EssenceEffects.extra_activations(i, order, essences, charm_ids, shown_values, hands_taken),
				RuneEffects.extra_activations(defs[i].runes_on(face), charm_ids), participating.size(), tail_slot,
					hands_taken == 0, combination.has(i))
		for group in pointer_fires.get(i, []):
			for fire in group:
				var fired: int = int(fire["face"])
				if fired < defs[i].materials.size() and defs[i].materials[fired] == DieMaterial.GOLD:
					triggers += 1
		for link_face in EssenceEffects.link_faces(defs[i], face, essence_ids,
				defs[i].runes_on(face), charm_ids):
			if link_face < defs[i].materials.size() and defs[i].materials[link_face] == DieMaterial.GOLD:
				triggers += EssenceEffects.det_link_fire_count(face, link_face,
					defs[i].runes_on(face), charm_ids)
	return triggers

## Nackter Wachstumsschritt einer Knochen-Seite: normal +2, dotiert mind. +10
## bzw. 20 % (aufgerundet).
static func _bone_step(value: int, level: int) -> int:
	if level >= DieMaterial.MAX_LEVEL:
		return maxi(BONE_GROWTH_MIN_DOPED, ceili(float(value) * BONE_GROWTH_PERCENT_DOPED / 100.0))
	return BONE_GROWTH

## Additiver Glas-Mult: normal deckelt die Augen bei 6, dotiert addiert nicht
## mehr - es kritet (mult_crit_once_for).
static func _glass_mult(value: int, level: int) -> int:
	if level >= DieMaterial.MAX_LEVEL:
		return 0
	return mini(value, GLASS_EYE_CAP)

## Schrumpfschritt einer Glas-Seite: normal −1, dotiert die halbe Augenzahl
## (aufgerundet, damit die Seite wirklich auf die Hälfte fällt).
static func _glass_step(value: int, level: int) -> int:
	if level >= DieMaterial.MAX_LEVEL:
		return maxi(1, ceili(float(value) * GLASS_SHRINK_PERCENT_DOPED / 100.0))
	return GLASS_SHRINK
