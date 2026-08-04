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
	var charge: int = 0  # Energie aus Funkenflug-Runenn (je Zug einmal je Seite)
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

## WÜRFEL-Achse des Slots i: wie oft der ganze Würfel antritt. Der Essenz-Faktor
## ist der einzige Faktor, alles andere addiert - die Echo-Kammer auf echo_slot,
## extra aus der Zählreihenfolge (Sauerstoff/Sonnenwind, die nur der Aufrufer
## kennt). scored_count = Zahl der gewerteten Würfel, für das Sechserpack.
static func die_trigger_count(i: int, charm_ids: Array[String], echo_slot: int = -1, essence_ids: Array[String] = [], is_stress: bool = false, extra: int = 0, scored_count: int = 0) -> int:
	var count := EssenceEffects.activation_factor_of(essence_ids, charm_ids, is_stress)
	if i == echo_slot:
		count += CharmEffects.echo_retriggers(charm_ids)
	count += CharmEffects.full_hand_retriggers(charm_ids, scored_count)
	return maxi(1, count + extra)

## SEITEN-Achse: wie oft die obere Seite je Würfel-Trigger zündet. Rein additiv -
## Retrigger-Charms auf value (Hasenpfote & Co.), extra für das Nachglühen
## (RuneEffects.extra_activations). value ist der VERWANDELTE Wert.
static func face_trigger_count(value: int, charm_ids: Array[String], extra: int = 0) -> int:
	return maxi(1, 1 + CharmEffects.retrigger_count(value, charm_ids) + extra)

## Zündungen der oberen Seite insgesamt: die beiden Achsen MULTIPLIZIEREN sich.
## Eine Quelle für Wertung, Schrittliste und Nehmen-Effekte.
static func total_trigger_count(i: int, charm_ids: Array[String], value: int = 0, echo_slot: int = -1, essence_ids: Array[String] = [], is_stress: bool = false, die_extra: int = 0, face_extra: int = 0, scored_count: int = 0) -> int:
	return die_trigger_count(i, charm_ids, echo_slot, essence_ids, is_stress, die_extra, scored_count) \
		* face_trigger_count(value, charm_ids, face_extra)

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
static func mult_crit_once_for(face_material: String, value: int, _charm_ids: Array[String], level: int) -> float:
	match face_material:
		DieMaterial.RUBY:
			return float(RUBY_CRIT) if level >= DieMaterial.MAX_LEVEL else 1.0
		DieMaterial.GLASS:
			return maxf(1.0, float(value)) if level >= 2 else 1.0
	return 1.0

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
## Einbrand (Rune dieser Seite) schützen vor jedem Verlust, ihr Glas schrumpft
## also nicht.
static func mutate_value_once(value: int, face_material: String,
		charm_ids: Array[String], level: int = 1, essence_ids: Array[String] = [],
		rune_ids: Array[String] = []) -> int:
	var result := value
	if face_material == DieMaterial.BONE:
		result = grow_bone_value(result, level, bone_growth_step(charm_ids), bone_trigger_count(charm_ids))
	if face_material == DieMaterial.GLASS and not _value_protected(essence_ids, rune_ids):
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
		result = grow_bone_value(result, level, bone_growth_step(charm_ids), bone_trigger_count(charm_ids))
	if face_material == DieMaterial.GLASS and not EssenceEffects.protects_face_value_of(essence_ids):
		result = shrink_value(result, _glass_step(result, level), glass_floor_for(charm_ids))
	return result

## Verliert diese Seite überhaupt Wert? Stickstoff schützt den ganzen Würfel,
## der Einbrand nur seine eigene Seite.
static func _value_protected(essence_ids: Array[String], rune_ids: Array[String]) -> bool:
	return EssenceEffects.protects_face_value_of(essence_ids) or RuneEffects.protects_face_value(rune_ids)

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
## Nur ADDITIV und nur auf dem LIEGENDEN Wert - ein Material-Krit (Rubin III,
## Glas ab II) und der Wertwandel zwischen den Aktivierungen (Knochen/Glas)
## lassen sich als Summe nicht ausdrücken; maßgeblich ist
## DiceScoring._base_and_mult.
static func mult_bonus(values: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String] = [], echo_slot: int = -1, levels: Dictionary = {}) -> int:
	var bonus := 0
	for i in participating:
		var level := level_in(level_of(levels, i))
		var effect_count := total_trigger_count(i, charm_ids, values[i], echo_slot, [], false, 0, 0, participating.size())
		bonus += mult_bonus_once(i, values, materials, charm_ids, level) * effect_count
	return bonus

## Nehmen-Effekte: mutiert die faces der Pool-Würfel direkt (dauerhaft).
## Gold zahlt seinen Stufensatz (Goldschmied hebt ihn); Knochen wächst
## (Knochenleim: +1 Aufschlag, Knochenmark lässt jede Knochen-Auslösung ein Mal
## mehr feuern - je Exemplar erneut); Glas schrumpft, nie unter das Floor
## (Glasbläserlunge hebt es auf 6); Essenz-Geld (Neon, Natriumdampf, Miasma) und
## Helium-Wachstum reiten in derselben Schleife. Alles je Effekt-Aktivierung.
## essences/order: Slot -> Essenz-id und die kanonische Zählreihenfolge - beide
## Achsen MÜSSEN dieselben sein wie in der Wertung (Argon & Co.).
## pointer_fires: der EINMAL ausgewürfelte Leiterbahn-Wurf (DiceScoring.
## CTX_POINTER_FIRES, Slot -> je Würfel-Trigger die gezündeten Glieder) - hier
## wird nie neu gewürfelt, sonst zahlte der Zug andere Glieder als er zählte.
## lying: ALLE Slots mit einem Würfel auf dem Tisch - nur so kann das Streulicht
## die ungewerteten Übriggebliebenen sehen. Runen liest diese Seite direkt aus
## den Defs (wie die Material-Stufen), nicht aus dem ctx.
static func apply_take_effects(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String] = [], echo_slot: int = -1, essences: Dictionary = {}, order: Array[int] = [], is_stress: bool = false, lying: Array[int] = [], pointer_fires: Dictionary = {}) -> TakeReport:
	var gold_boost := charm_ids.has(Charm.GOLDSMITH)
	# Goldader legt auf JEDEN Gold-Träger denselben Zuschlag.
	var vein := CharmEffects.gold_vein_bonus(materials, participating, charm_ids)
	var plain_gold := (GOLD_PAYOUT_BOOSTED if gold_boost else GOLD_PAYOUT) + vein
	# Charm- und Goldader-Aufschlag liegt über JEDEM Stufensatz.
	var gold_surplus := plain_gold - GOLD_PAYOUT
	# Gold III: +$1 je Gold-Seiten-Auslösung dieser Nahme - der Zähler steht VOR
	# der ersten Buchung fest.
	var gold_triggers := _gold_face_triggers(defs, face_indices, materials, participating, charm_ids, echo_slot, essences, order, is_stress, pointer_fires)
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
		var rune_ids := defs[i].runes_on(face)
		# Funkenflug speist EINEN Funken je Zug, nie je Zündung.
		var spark := RuneEffects.charge_for_take(rune_ids)
		report.charge += spark
		for _s in spark:
			report.sparks.append(i)
		# Retrigger prüft den VERWANDELTEN Wert - wie in der Wertung.
		var shown := CharmEffects.shown_by_charms(defs[i].faces[face], charm_ids)
		# Die beiden Achsen, exakt wie DiceScoring sie zählt.
		var die_triggers := die_trigger_count(i, charm_ids, echo_slot, essence_ids, is_stress,
			EssenceEffects.extra_activations(i, order, essences, charm_ids), participating.size())
		var face_triggers := face_trigger_count(shown, charm_ids, RuneEffects.extra_activations(rune_ids))
		var effect_count := die_triggers * face_triggers
		var fires: Array = pointer_fires.get(i, [])

		if face_material == DieMaterial.GOLD:
			report.money += _gold_payout(level, gold_surplus, gold_triggers) * effect_count
		report.money += EssenceEffects.money_of(essence_ids, defs[i].faces[face], participating.size()) * effect_count
		# Zyanidgas laugt die eigene Schale aus: je ZUG einmal, nie je Auslösung.
		# Das Scheidewasser greift dazu die Gold-Seiten der Mitwürfel an.
		report.money += EssenceEffects.gold_face_money_of(essence_ids, defs[i].materials, charm_ids,
			_foreign_gold_faces(defs, participating, i))

		# Der Einbrand hat wirklich etwas abgewehrt - nur dann lohnt die Geste.
		if face_material == DieMaterial.GLASS and RuneEffects.protects_face_value(rune_ids):
			report.blocked.append(i)

		# Knochen/Glas/Helium laufen Zündung für Zündung: der prozentuale Satz
		# rechnet sich am schon veränderten Wert neu. Verschachtelt wie in der
		# Wertung - je Würfel-Trigger erst die Seiten-Zündungen, dann die für
		# genau diesen Trigger gewürfelten Leiterbahn-Glieder.
		var before: int = defs[i].faces[face]
		var swelled := false
		for t in die_triggers:
			for _f in face_triggers:
				defs[i].faces[face] = mutate_value_once(defs[i].faces[face], face_material, charm_ids, level, essence_ids, rune_ids)
				# Strahlungsdruck bläht die GANZE Schale: die obere Seite ist über
				# mutate_value_once schon gewachsen, die übrigen fünf folgen je
				# Zündung - jede auf IHREM Wert, der Druckkessel rechnet prozentual.
				swelled = _swell_other_faces(defs[i], face, essence_ids, charm_ids) or swelled
			for fire in (fires[t] if t < fires.size() else []):
				_fire_link(defs[i], int(fire["face"]), charm_ids, essence_ids, gold_surplus, gold_triggers, report, i)
		if defs[i].faces[face] > before:
			report.grown.append(i)
		elif defs[i].faces[face] < before:
			report.shrunk.append(i)
		elif swelled:
			report.grown.append(i)

		# Essenz-Glieder (Röntgenlicht, Korona): deterministisch und EINMAL nach
		# allen Würfel-Triggern - anders als die gewürfelte Leiterbahn.
		for link_face in EssenceEffects.essence_link_faces(defs[i], face, essence_ids, charm_ids):
			_fire_link(defs[i], link_face, charm_ids, essence_ids, gold_surplus, gold_triggers, report, i)

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

	_spread_miasma(defs, face_indices, participating, essences, charm_ids, report)

	if charm_ids.has(Charm.RECTIFIER):
		_rectify_faces(defs, face_indices, participating, essences, report)

	# Streulicht: das Gegen-Ereignis zum Gold. Was am Zugende UNGEWERTET auf dem
	# Tisch liegt und seine Runen-Seite zeigt, streut sein Licht ins Filz.
	for i in lying:
		if participating.has(i) or i >= defs.size() or i >= face_indices.size():
			continue
		var idle_face: int = face_indices[i]
		if idle_face < 0:
			continue
		var stray := RuneEffects.stray_money(defs[i].runes_on(idle_face))
		if stray > 0:
			report.money += stray
			report.stray.append(i)
	return report

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
	if face < 0 or face >= def.faces.size() or _value_protected(essence_ids, def.runes_on(face)):
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

## Ansteckung: jeder gewertete Miasma-Würfel verliert auf seiner oberen Seite
## dauerhaft die abgerundete Hälfte ihrer Augen, und GENAU dieser Betrag wächst
## auf jeder anderen gewerteten Seite der Hand. Läuft NACH allen Wertwandeln des
## Zuges, damit Knochen/Glas exakt auf dem value_after der Simulation landen.
## Stickstoff (Würfel) und Einbrand (Seite) verhindern die Halbierung - dann
## bekommt auch niemand etwas. Mit Räucherwerk steckt der Dunst weiter an, OHNE
## dass die Quelle verliert.
static func _spread_miasma(defs: Array[DieDefinition], face_indices: Array[int], participating: Array[int], essences: Dictionary, charm_ids: Array[String], report: TakeReport) -> void:
	for i in participating:
		if i >= defs.size() or i >= face_indices.size() or defs[i] == null:
			continue
		var face: int = face_indices[i]
		if face < 0 or face >= defs[i].faces.size():
			continue
		var essence_ids := EssenceEffects.set_at(essences, i)
		var infects := false
		for essence_id in essence_ids:
			if EssenceEffects.redistributes_faces(essence_id):
				infects = true
		if not infects:
			continue
		if _value_protected(essence_ids, defs[i].runes_on(face)):
			continue
		var amount: int = defs[i].faces[face] / 2
		if amount <= 0:
			continue
		if not charm_ids.has(Charm.CENSER):
			defs[i].faces[face] -= amount
			if not report.shrunk.has(i):
				report.shrunk.append(i)
		for other in participating:
			if other == i or other >= defs.size() or other >= face_indices.size() or defs[other] == null:
				continue
			var other_face: int = face_indices[other]
			if other_face < 0 or other_face >= defs[other].faces.size():
				continue
			defs[other].faces[other_face] += amount
			if not report.grown.has(other):
				report.grown.append(other)

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
		if mean < current and _value_protected(EssenceEffects.set_at(essences, i), defs[i].runes_on(face)):
			continue
		defs[i].faces[face] = mean
		if mean > current:
			if not report.grown.has(i):
				report.grown.append(i)
		elif not report.shrunk.has(i):
			report.shrunk.append(i)

## EINE Glied-Zündung auf die Def: Gold zahlt, Knochen/Glas wandeln die GLIED-
## Seite auf IHRER Stufe (nie der der oberen). Ein Glied kann mehrfach zünden -
## dann wandert der Wert Zündung für Zündung weiter, wie der eingefrorene Wurf
## ihn gezählt hat.
static func _fire_link(def: DieDefinition, link_face: int, charm_ids: Array[String], essence_ids: Array[String], gold_surplus: int, gold_triggers: int, report: TakeReport, slot: int) -> void:
	if def == null or link_face < 0 or link_face >= def.faces.size():
		return
	var link_material: String = def.materials[link_face] if link_face < def.materials.size() else ""
	var link_level := face_level(def, link_face)
	if link_material == DieMaterial.GOLD:
		report.money += _gold_payout(link_level, gold_surplus, gold_triggers)
	var before: int = def.faces[link_face]
	def.faces[link_face] = mutate_link_value_once(before, link_material, charm_ids, link_level, essence_ids)
	if def.faces[link_face] > before and not report.grown.has(slot):
		report.grown.append(slot)
	elif def.faces[link_face] < before and not report.shrunk.has(slot):
		report.shrunk.append(slot)

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

## Wie oft in DIESER Nahme eine Gold-Seite zündet - beide Achsen aller
## beteiligten Slots plus jede GEZÜNDETE Leiterbahn und die Essenz-Glieder, auf
## jeder Stufe.
static func _gold_face_triggers(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String], echo_slot: int, essences: Dictionary, order: Array[int], is_stress: bool, pointer_fires: Dictionary) -> int:
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
				EssenceEffects.extra_activations(i, order, essences, charm_ids),
				RuneEffects.extra_activations(defs[i].runes_on(face)), participating.size())
		for group in pointer_fires.get(i, []):
			for fire in group:
				var fired: int = int(fire["face"])
				if fired < defs[i].materials.size() and defs[i].materials[fired] == DieMaterial.GOLD:
					triggers += 1
		for link_face in EssenceEffects.essence_link_faces(defs[i], face, essence_ids, charm_ids):
			if link_face < defs[i].materials.size() and defs[i].materials[link_face] == DieMaterial.GOLD:
				triggers += 1
	return triggers

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
