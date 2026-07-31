class_name MaterialEffects
## Reine Wirkung der Materialien (siehe DieMaterial). Ein Material sitzt auf
## EINER Seite und wirkt nur, wenn die Seite oben liegt UND zur Kombination
## gehört. Materialien wirken NUR über die genommene Kombination - verworfene
## und gefumbelte Würfel lösen nichts aus. Zwei Aufrufpunkte: Wertungs-Boni
## (base_bonus/mult_bonus, auch in Vorschau/Farkle-Vergleich) und Nehmen-Effekte
## (apply_take_effects, einmal beim echten Nehmen).
## values/materials sind parallele Arrays je Wurf-Slot.
##
## SÄTTIGUNG: jedes Material steht auf Stufe I-III (DieDefinition.levels). Die
## Stufe ist nie nur eine größere Zahl - mal skaliert sie (Bernstein, Gold,
## Knochen), mal verwandelt sie (Rubin und Glas kriten).

## Gold zahlt je Träger beim Nehmen; Goldschmied hebt den Satz.
const GOLD_PAYOUT := 3
const GOLD_PAYOUT_BOOSTED := 6
const GOLD_PAYOUT_2 := 7          # Stufe II und III

## Rubin: fester Mult je Träger (Rubinschleifer addiert die Augenzahl).
const RUBY_MULT := 4
const RUBY_MULT_2 := 10
const RUBY_CRIT := 2              # Stufe III kritet, statt zu addieren

## Bernstein-Grundwert; Bernsteinzimmer legt seinen Aufschlag auf JEDE Stufe.
const AMBER_BASE := 20
const AMBER_BASE_2 := 50
const AMBER_ROOM_SURPLUS := 30
const AMBER_EYE_FACTOR := 5       # Stufe III: nur noch Augensumme, dafür ×5

## Knochen wächst ab Stufe II prozentual (mind. +3), Glas schrumpft ab Stufe II
## um mind. 5 bzw. 20 % - beides je Auslösung am schon veränderten Wert.
const BONE_GROWTH_MIN := 3
const BONE_GROWTH_PERCENT := 10
const BONE_GROWTH_PERCENT_3 := 20
const GLASS_SHRINK_MIN := 5
const GLASS_SHRINK_PERCENT := 20

## Glasbläserlunge: Glas schrumpft weiter, aber nie unter diesen Wert.
const GLASSBLOWER_LUNG_FLOOR := 6

## Bericht der Nehmen-Effekte für die UI.
class TakeReport:
	extends RefCounted

	var money: int = 0
	var charge: int = 0  # Energie aus Funkenflug-Rissen (je Zug einmal je Seite)
	var grown: Array[int] = []  # Slots, deren Seite gewachsen ist (Knochen/Helium)
	var shrunk: Array[int] = []  # Slots, deren Seite geschrumpft ist (Glas)

## Aktivierungen des Würfels in Slot i: die Essenz stellt den EINZIGEN Faktor
## (EssenceEffects.activation_factor), alles andere addiert - Retrigger-Charms
## auf value (Hasenpfote & Co.), die Echo-Kammer auf echo_slot, und extra aus der
## Zählreihenfolge (Sauerstoff/Sonnenwind, die nur der Aufrufer kennt).
## Jede Aktivierung zählt Augen und Effekte erneut.
static func activation_count(i: int, charm_ids: Array[String], value: int = 0, echo_slot: int = -1, essence_ids: Array[String] = [], is_stress: bool = false, extra: int = 0) -> int:
	var count := EssenceEffects.activation_factor_of(essence_ids, charm_ids, is_stress)
	count += CharmEffects.retrigger_count(value, charm_ids)
	if i == echo_slot:
		count += CharmEffects.echo_retriggers(charm_ids)
	return maxi(1, count + extra)

## Basis-Bonus EINER Auslösung des Slots i - nur der Träger, ohne Augen.
static func base_bonus_once(i: int, materials: Array[String], charm_ids: Array[String], level: int = 1, eye_sum: int = 0) -> int:
	return base_once_for(materials[i] if i < materials.size() else "", charm_ids, level, eye_sum)

## Wie base_bonus_once, aber direkt über die Material-id - so feuern auch
## Leiterbahn-Glieder (fremde Seite) über dieselbe Tabelle.
## eye_sum: Augensumme des Würfels - Bernstein zahlt sie auf JEDER Stufe, auf
## Stufe III fünffach und ohne festen Zuschlag.
static func base_once_for(face_material: String, charm_ids: Array[String], level: int = 1, eye_sum: int = 0) -> int:
	if face_material != DieMaterial.AMBER:
		return 0
	var room := AMBER_ROOM_SURPLUS if charm_ids.has(Charm.AMBER_ROOM) else 0
	return _amber_flat(level) + room \
		+ eye_sum * (AMBER_EYE_FACTOR if level >= DieMaterial.MAX_LEVEL else 1)

## Mult-Bonus EINER Auslösung des Slots i: Rubin fest (Rubinschleifer/Blood
## Diamond legen die Augenzahl drauf); Glas + rohe Augenzahl der oberen Seite.
static func mult_bonus_once(i: int, values: Array[int], materials: Array[String], charm_ids: Array[String], level: int = 1) -> int:
	return mult_once_for(materials[i] if i < materials.size() else "", values[i], charm_ids, level)

## Wie mult_bonus_once über die Material-id; value ist die feuernde Augenzahl
## (beim Leiterbahn-Glied die der Zielseite). Was kritet, addiert hier NICHT
## (Rubin III, Glas II) - siehe mult_crit_once_for; nur Schleifer/Blood Diamond
## bleiben beim Rubin auf jeder Stufe additiv, damit der Krit nicht exponentiell wird.
static func mult_once_for(face_material: String, value: int, charm_ids: Array[String], level: int = 1) -> int:
	# Rubinschleifer legt die Augenzahl EINMAL drauf, der Blood Diamond je Exemplar.
	var eye_stacks := int(charm_ids.has(Charm.RUBY_GRINDER)) + charm_ids.count(Charm.BLOOD_DIAMOND)
	if face_material == DieMaterial.RUBY:
		return _ruby_mult(level) + value * eye_stacks
	# Stufe II tauscht das Additive gegen den Krit, Stufe III hat beides.
	if face_material == DieMaterial.GLASS and level != 2:
		return value
	return 0

## Material-Krit EINER Auslösung: eine Seite trägt genau ein Material - also
## höchstens ein Faktor. 1 = kein Krit. Rubin kritet erst auf der letzten Stufe,
## Glas schon ab der zweiten.
static func mult_crit_once_for(face_material: String, value: int, _charm_ids: Array[String], level: int) -> int:
	match face_material:
		DieMaterial.RUBY:
			return RUBY_CRIT if level >= DieMaterial.MAX_LEVEL else 1
		DieMaterial.GLASS:
			return maxi(1, value) if level >= 2 else 1
	return 1

## Stufen-Infos eines Slots (Form wie DiceScoring.CTX_MATERIAL_LEVELS).
static func level_of(levels: Dictionary, slot: int) -> Dictionary:
	return levels.get(slot, {})

## Stufe aus einem solchen Eintrag - ohne Eintrag gilt Stufe I.
static func level_in(info: Dictionary) -> int:
	return int(info.get("level", 1))

## Fester Bernstein-Zuschlag der Stufe (Stufe III zahlt nur noch Augensumme).
static func _amber_flat(level: int) -> int:
	if level >= DieMaterial.MAX_LEVEL:
		return 0
	return AMBER_BASE_2 if level == 2 else AMBER_BASE

## Additiver Rubin-Mult der Stufe (Stufe III kritet stattdessen).
static func _ruby_mult(level: int) -> int:
	if level >= DieMaterial.MAX_LEVEL:
		return 0
	return RUBY_MULT_2 if level == 2 else RUBY_MULT

# --- Wertwandel zwischen den Aktivierungen -------------------------------------
# Knochen wächst und Glas schrumpft ZWISCHEN den Auslösungen eines Zuges: die
# zweite Aktivierung zählt schon den gewachsenen Wert. Weil apply_take_effects
# dieselbe Rechnung dauerhaft in die Def schreibt, MUSS beides über diese
# Helfer laufen - sonst zeigt die Wertung eine andere Zahl als der Würfel.

## Knochenleim hebt den Wachstumsschritt einmalig auf 2.
static func bone_growth_step(charm_ids: Array[String]) -> int:
	return 2 if charm_ids.has(Charm.BONE_GLUE) else 1

## Knochenmark verlängert nicht den Schritt, sondern die Zahl der Auslösungen.
static func bone_trigger_count(charm_ids: Array[String]) -> int:
	return 1 + charm_ids.count(Charm.BONE_MARROW)

## Glasbläserlunge hebt nur den Boden - geschrumpft wird weiter.
static func glass_floor_for(charm_ids: Array[String]) -> int:
	var glass_floor := EtchingEffects.MIN_FACE_VALUE
	if charm_ids.has(Charm.GLASSBLOWER_LUNG):
		glass_floor = maxi(glass_floor, GLASSBLOWER_LUNG_FLOOR)
	return glass_floor

## Wachstum über triggers Auslösungen; ab Stufe II rechnet die Seite ihren
## Prozentschritt je Auslösung am schon gewachsenen Wert neu.
static func grow_bone_value(value: int, level: int, step: int, triggers: int) -> int:
	var result := value
	for _t in triggers:
		result += (_bone_step(result, level) + step - 1) if level >= 2 else step
	return result

## Schrumpft um step, nie unter floor_value (unveränderter Wert = kein Schritt).
static func shrink_value(value: int, step: int, floor_value: int) -> int:
	var target := maxi(floor_value, value - step)
	return target if target < value else value

## Wertwandel EINER Auslösung: Knochen wächst, Glas schrumpft, Helium hebt die
## obere Seite - dieselbe Folge wie apply_take_effects. Stickstoff (Essenz) und
## Einbrand (Rift dieser Seite) schützen vor jedem Verlust, ihr Glas schrumpft
## also nicht.
static func mutate_value_once(value: int, face_material: String,
		charm_ids: Array[String], level: int = 1, essence_ids: Array[String] = [],
		rift_ids: Array[String] = []) -> int:
	var result := value
	if face_material == DieMaterial.BONE:
		result = grow_bone_value(result, level, bone_growth_step(charm_ids), bone_trigger_count(charm_ids))
	if face_material == DieMaterial.GLASS and not _value_protected(essence_ids, rift_ids):
		result = shrink_value(result, _glass_step(result, level), glass_floor_for(charm_ids))
	return result + EssenceEffects.face_growth_of(essence_ids)

## Verliert diese Seite überhaupt Wert? Stickstoff schützt den ganzen Würfel,
## der Einbrand nur seine eigene Seite.
static func _value_protected(essence_ids: Array[String], rift_ids: Array[String]) -> bool:
	return EssenceEffects.protects_face_value_of(essence_ids) or RiftEffects.protects_face_value(rift_ids)

## Endwert der oberen Seite nach activations Auslösungen - genau der Wert, den
## apply_take_effects in die Def schreibt (per Test abgesichert).
static func value_after_activations(value: int, activations: int, face_material: String,
		charm_ids: Array[String], level: int = 1, essence_ids: Array[String] = [],
		rift_ids: Array[String] = []) -> int:
	var result := value
	for _a in maxi(0, activations):
		result = mutate_value_once(result, face_material, charm_ids, level, essence_ids, rift_ids)
	return result

## Basis-Boni der beteiligten Träger über ALLE Aktivierungen (Vorschau/Tests);
## jede Extra-Aktivierung zählt die Augen erneut. Rechnet mit dem LIEGENDEN
## Wert - den Wertwandel zwischen den Aktivierungen (Knochen/Glas) kennt nur
## DiceScoring._base_and_mult.
static func base_bonus(values: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String], echo_slot: int = -1, levels: Dictionary = {}) -> int:
	var bonus := 0
	for i in participating:
		var info := level_of(levels, i)
		var activations := activation_count(i, charm_ids, values[i], echo_slot)
		bonus += base_bonus_once(i, materials, charm_ids, level_in(info), int(info.get("eye_sum", 0))) * activations
		if activations > 1:
			bonus += CharmEffects.eye_value(values[i], charm_ids) * (activations - 1)
	return bonus

## Mult-Boni der beteiligten Träger über ALLE Aktivierungen (Vorschau/Tests).
## Nur ADDITIV und nur auf dem LIEGENDEN Wert - ein Material-Krit (Rubin III,
## Glas ab II) und der Wertwandel zwischen den Aktivierungen (Knochen/Glas)
## lassen sich als Summe nicht ausdrücken; maßgeblich ist
## DiceScoring._base_and_mult.
static func mult_bonus(values: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String] = [], echo_slot: int = -1, levels: Dictionary = {}) -> int:
	var bonus := 0
	for i in participating:
		var level := level_in(level_of(levels, i))
		var effect_count := activation_count(i, charm_ids, values[i], echo_slot)
		bonus += mult_bonus_once(i, values, materials, charm_ids, level) * effect_count
	return bonus

## Nehmen-Effekte: mutiert die faces der Pool-Würfel direkt (dauerhaft).
## Gold zahlt seinen Stufensatz (Goldschmied hebt ihn); Knochen wächst
## (Knochenleim: +1 Aufschlag, Knochenmark lässt jede Knochen-Auslösung ein Mal
## mehr feuern - je Exemplar erneut); Glas schrumpft, nie unter das Floor
## (Glasbläserlunge hebt es auf 6); Essenz-Geld (Neon, Natriumdampf, Miasma) und
## Helium-Wachstum reiten in derselben Schleife. Alles je Effekt-Aktivierung.
## essences/order: Slot -> Essenz-id und die kanonische Zählreihenfolge - die
## Aktivierungen MÜSSEN dieselben sein wie in der Wertung (Argon & Co.).
## lying: ALLE Slots mit einem Würfel auf dem Tisch - nur so kann das Streulicht
## die ungewerteten Übriggebliebenen sehen. Rifts liest diese Seite direkt aus
## den Defs (wie die Material-Stufen), nicht aus dem ctx.
static func apply_take_effects(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String] = [], echo_slot: int = -1, essences: Dictionary = {}, order: Array[int] = [], is_stress: bool = false, lying: Array[int] = []) -> TakeReport:
	var gold_boost := charm_ids.has(Charm.GOLDSMITH)
	# Goldader legt auf JEDEN Gold-Träger denselben Zuschlag.
	var vein := CharmEffects.gold_vein_bonus(materials, participating, charm_ids)
	var plain_gold := (GOLD_PAYOUT_BOOSTED if gold_boost else GOLD_PAYOUT) + vein
	# Charm- und Goldader-Aufschlag liegt über JEDEM Stufensatz.
	var gold_surplus := plain_gold - GOLD_PAYOUT
	# Gold III: +$1 je Gold-Seiten-Auslösung dieser Nahme - der Zähler steht VOR
	# der ersten Buchung fest.
	var gold_triggers := _gold_face_triggers(defs, face_indices, materials, participating, charm_ids, echo_slot, essences, order, is_stress)
	var bone_growth := bone_growth_step(charm_ids)
	var bone_triggers := bone_trigger_count(charm_ids)
	var glass_floor := glass_floor_for(charm_ids)
	var report := TakeReport.new()
	for i in participating:
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0:
			continue
		var face_material: String = materials[i] if i < materials.size() else ""
		var essence_ids := EssenceEffects.set_at(essences, i)
		var level := face_level(defs[i], face)
		var rift_ids := defs[i].rifts_on(face)
		# Funkenflug speist EINEN Funken je Zug, nie je Auslösung.
		report.charge += RiftEffects.charge_for_take(rift_ids)
		# Retrigger prüft den VERWANDELTEN Wert - wie in der Wertung.
		var shown := CharmEffects.transform_value(defs[i].faces[face], charm_ids)
		var effect_count := activation_count(i, charm_ids, shown, echo_slot, essence_ids, is_stress,
			EssenceEffects.extra_activations(i, order, essences))

		if face_material == DieMaterial.GOLD:
			report.money += _gold_payout(level, gold_surplus, gold_triggers) * effect_count
		report.money += EssenceEffects.money_of(essence_ids, defs[i].faces[face], participating.size()) * effect_count

		# Knochen/Glas/Helium laufen Aktivierung für Aktivierung: der prozentuale
		# Satz rechnet sich am schon veränderten Wert neu.
		var before: int = defs[i].faces[face]
		for _a in effect_count:
			defs[i].faces[face] = mutate_value_once(defs[i].faces[face], face_material, charm_ids, level, essence_ids, rift_ids)
		if defs[i].faces[face] > before:
			report.grown.append(i)
		elif defs[i].faces[face] < before:
			report.shrunk.append(i)

		# Leiterbahn-Glieder: je Glied EINMAL (nie × effect_count) - die Seite des
		# Glieds, Wachsen/Schrumpfen trifft die GLIED-Seite. Die Stufe des GLIEDS
		# zählt, nicht die der oben liegenden Seite.
		for link_face in defs[i].pointer_chain(face, EssenceEffects.extra_pointer_links_of(essence_ids)):
			var link_material: String = defs[i].materials[link_face] if link_face < defs[i].materials.size() else ""
			var link_level := face_level(defs[i], link_face)
			if link_material == DieMaterial.GOLD:
				report.money += _gold_payout(link_level, gold_surplus, gold_triggers)
			var link_before: int = defs[i].faces[link_face]
			if link_material == DieMaterial.BONE:
				_grow_bone(defs[i], link_face, link_level, bone_growth, bone_triggers)
			elif link_material == DieMaterial.GLASS and not EssenceEffects.protects_face_value_of(essence_ids):
				_shrink(defs[i], link_face, _glass_step(defs[i].faces[link_face], link_level), glass_floor)
			if defs[i].faces[link_face] > link_before and not report.grown.has(i):
				report.grown.append(i)
			elif defs[i].faces[link_face] < link_before and not report.shrunk.has(i):
				report.shrunk.append(i)

	# Streulicht: das Gegen-Ereignis zum Gold. Was am Zugende UNGEWERTET auf dem
	# Tisch liegt und seine Riss-Seite zeigt, streut sein Licht ins Filz.
	for i in lying:
		if participating.has(i) or i >= defs.size() or i >= face_indices.size():
			continue
		var idle_face: int = face_indices[i]
		if idle_face < 0:
			continue
		report.money += RiftEffects.stray_money(defs[i].rifts_on(idle_face))
	return report

## Stufe des Materials DIESER Seite (Guard für Defs ohne volles Stufen-Array).
static func face_level(def: DieDefinition, face: int) -> int:
	return def.material_level(face) if def != null else 0

## Gold-Satz einer Stufe; surplus = Charm-/Goldader-Aufschlag, triggers zählt nur
## auf Stufe III.
static func _gold_payout(level: int, surplus: int, triggers: int) -> int:
	if level >= DieMaterial.MAX_LEVEL:
		return GOLD_PAYOUT_2 + surplus + triggers
	if level == 2:
		return GOLD_PAYOUT_2 + surplus
	return GOLD_PAYOUT + surplus

## Wie oft in DIESER Nahme eine Gold-Seite auslöst - Aktivierungen aller
## beteiligten Slots plus Leiterbahn-Glieder, auf jeder Stufe.
static func _gold_face_triggers(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String], echo_slot: int, essences: Dictionary, order: Array[int], is_stress: bool) -> int:
	var triggers := 0
	for i in participating:
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0:
			continue
		if i < materials.size() and materials[i] == DieMaterial.GOLD:
			var shown := CharmEffects.transform_value(defs[i].faces[face], charm_ids)
			triggers += activation_count(i, charm_ids, shown, echo_slot, EssenceEffects.set_at(essences, i), is_stress,
				EssenceEffects.extra_activations(i, order, essences))
		for link_face in defs[i].pointer_chain(face, EssenceEffects.extra_pointer_links_of(EssenceEffects.set_at(essences, i))):
			if link_face < defs[i].materials.size() and defs[i].materials[link_face] == DieMaterial.GOLD:
				triggers += 1
	return triggers

## Lässt eine Knochen-Seite triggers-mal wachsen (Knochenmark) - über
## grow_bone_value, damit die Wertungs-Simulation nicht abweichen kann.
static func _grow_bone(def: DieDefinition, face: int, level: int, step: int, triggers: int) -> void:
	def.faces[face] = grow_bone_value(def.faces[face], level, step, triggers)

## Wachstumsschritt einer Knochen-Seite: Stufe II mind. +3 bzw. 10 %, Stufe III
## dieselbe Untergrenze bei 20 % (aufgerundet).
static func _bone_step(value: int, level: int) -> int:
	var percent := BONE_GROWTH_PERCENT_3 if level >= DieMaterial.MAX_LEVEL else BONE_GROWTH_PERCENT
	return maxi(BONE_GROWTH_MIN, ceili(float(value) * percent / 100.0))

## Schrumpfschritt einer Glas-Seite: Stufe I −1, ab Stufe II mind. 5 bzw. 20 %
## (Stufe III frisst sich im II-Tempo).
static func _glass_step(value: int, level: int) -> int:
	if level < 2:
		return 1
	return maxi(GLASS_SHRINK_MIN, ceili(float(value) * GLASS_SHRINK_PERCENT / 100.0))

## Schrumpft eine Seite um step, nie unter floor_value; true, wenn sie sich bewegt hat.
static func _shrink(def: DieDefinition, face: int, step: int,
		floor_value: int = EtchingEffects.MIN_FACE_VALUE) -> bool:
	var target := shrink_value(def.faces[face], step, floor_value)
	if target == def.faces[face]:
		return false
	def.faces[face] = target
	return true
