class_name EssenceEffects
## Reine Wirkung der Essenzen (siehe Essence), über die id aufgelöst - nie ein
## stiller Zweig in scene_root oder DiceScoring. Eine Essenz gehört dem GANZEN
## Würfel und wirkt, sobald er wertet; sie ist Charakter, nie Seiten-Payload
## (das ist Material-Land): Auslösung, Reihenfolge, Physik, Ökonomie.
##
## AKTIVIERUNGS-MATHE (Invariante): die Essenz ist die EINZIGE multiplikative
## Quelle je Würfel. Alles andere - Retrigger-Charms, Echo-Kammer, Sauerstoff,
## Sonnenwind - addiert. Damit kann kein Faktor × Faktor mehr explodieren.

## Radon strahlt auf jeden anderen Würfel der Kombination.
const RADON_EYE_BONUS := 2

## Neon zahlt fest, Natriumdampf je Mitwürfel.
const NEON_MONEY := 2
const SODIUM_MONEY_PER_DIE := 1

## Grubengas: Basispunkte, sobald in der Hand ein Krit gezündet hat.
const FIREDAMP_BASE := 20

## Xenon/Kugelblitz kriten fest; Elmsfeuer verdoppelt seinen Faktor im Sturm.
const FLASH_CRIT := 2
const STORM_FACTOR := 4

## Multiplikative Auslösungen des Würfels - die EINZIGE Stelle, an der ein
## Faktor entsteht. Quecksilberdampf (Charm) legt +1 auf jeden Faktor, der
## überhaupt einer ist: das verbannte Material lebt als Verstärker weiter.
static func activation_factor(essence_id: String, charm_ids: Array[String] = [], is_stress: bool = false) -> int:
	var factor := 1
	match essence_id:
		Essence.ARGON:
			factor = 2
		Essence.MERCURY_VAPOR:
			factor = 3
		Essence.ST_ELMOS_FIRE:
			factor = STORM_FACTOR if is_stress else 2
	if factor >= 2 and charm_ids.has(Charm.MERCURY_VAPOR):
		factor += 1
	return factor

## ADDITIVE Auslösungen aus der Zählreihenfolge: Sauerstoff facht den NÄCHSTEN
## an, Sonnenwind reitet auf jedem Essenz-Würfel, der vor ihm gezählt wurde.
## order ist die kanonische Reihe (DiceScoring.trigger_order), nie eine physische.
static func extra_activations(slot: int, order: Array[int], sets: Dictionary) -> int:
	var index := order.find(slot)
	if index < 0:
		return 0
	var extra := 0
	if index > 0 and set_at(sets, order[index - 1]).has(Essence.OXYGEN):
		extra += 1
	if set_at(sets, slot).has(Essence.SOLAR_WIND):
		for k in index:
			if not set_at(sets, order[k]).is_empty():
				extra += 1
	return extra

## Augen-Beitrag EINER Auslösung, nachdem die Charms ihren Augenwert gebildet
## haben. Wasserstoff verdoppelt, Miasma behält nur die aufgerundete Hälfte (die
## andere wird Geld), Antimaterie zählt NEGATIV - ihre Basis klemmt der Aufrufer.
static func eye_value(essence_id: String, eyes: int) -> int:
	match essence_id:
		Essence.HYDROGEN:
			return eyes * 2
		Essence.MIASMA:
			return ceili(float(eyes) / 2.0)
		Essence.ANTIMATTER:
			return -eyes
	return eyes

## Radon strahlt: +2 Augen auf JEDEN anderen gewerteten Würfel, je Auslösung.
static func foreign_eye_bonus(slot: int, scored: Array[int], sets: Dictionary) -> int:
	var bonus := 0
	for other in scored:
		if other != slot and set_at(sets, other).has(Essence.RADON):
			bonus += RADON_EYE_BONUS
	return bonus

## Essenz-Krit EINER Auslösung (Material-Krit-Substufe, VOR den Charm-Krits).
## crits_before: Krits, die in dieser Hand schon zündeten (Ozon); armed: die
## bedingte Auslösung ist scharf (Xenon noch frei, Kugelblitz-Seite oben).
static func crit_once_for(essence_id: String, value: int, crits_before: int = 0, armed: bool = false) -> int:
	match essence_id:
		Essence.XENON, Essence.BALL_LIGHTNING:
			return FLASH_CRIT if armed else 1
		Essence.OZONE:
			return maxi(1, 1 + crits_before)
		Essence.ANTIMATTER:
			return maxi(1, value)
	return 1

## Trägt die Essenz überhaupt einen bedingten Krit? (Xenon/Kugelblitz - nur für
## sie fragt der Aufrufer den Rundenzustand ab.)
static func has_armed_crit(essence_id: String) -> bool:
	return essence_id == Essence.XENON or essence_id == Essence.BALL_LIGHTNING

## Geld EINER Auslösung: Neon fest, Natriumdampf je Mitwürfel, Miasma die
## abgerundete Hälfte seiner Augen. Gebucht wird über GameRun.add_money.
static func money_for(essence_id: String, value: int, combo_size: int) -> int:
	match essence_id:
		Essence.NEON:
			return NEON_MONEY
		Essence.SODIUM_VAPOR:
			return maxi(0, combo_size - 1) * SODIUM_MONEY_PER_DIE
		Essence.MIASMA:
			return int(floor(float(value) / 2.0))
	return 0

## Grubengas: +20 Basispunkte, sobald in dieser Hand ein Krit gezündet hat -
## spät ausgewertet, nach den statischen Charm-Krits.
static func firedamp_bonus(scored: Array[int], sets: Dictionary, crits: int) -> int:
	if crits <= 0:
		return 0
	var bonus := 0
	for slot in scored:
		if set_at(sets, slot).has(Essence.FIREDAMP):
			bonus += FIREDAMP_BASE
	return bonus

## Stickstoff: die Seiten dieses Würfels verlieren nie an Wert (Glas schrumpft
## nicht, Zerfall greift nicht).
static func protects_face_value(essence_id: String) -> bool:
	return essence_id == Essence.NITROGEN

## Helium: die obere Seite wächst je Auslösung dauerhaft.
static func face_growth(essence_id: String) -> int:
	return 1 if essence_id == Essence.HELIUM else 0

## Krypton: Klauseln, die Würfel AUSSPERREN (Parität), übersehen ihn. Kategorie-
## Drosseln bleiben davon unberührt - die sperren keine Würfel, sondern Hände.
static func ignores_dice_filters(essence_id: String) -> bool:
	return essence_id == Essence.KRYPTON

## Plasma: der Lichtbogen hängt zwei Glieder an die Leiterbahn-Kette und lässt
## sie dabei im Kreis springen.
const PLASMA_EXTRA_LINKS := 2

static func extra_pointer_links(essence_id: String) -> int:
	return PLASMA_EXTRA_LINKS if essence_id == Essence.PLASMA else 0

## Polarlicht: seine Augenzahl gilt der KOMBINATIONSSUCHE als Joker. Die Augen
## selbst bleiben die aufgedruckten - der Joker verschiebt nur, WELCHE Kategorie
## zutrifft, nie wie viel sie zahlt.
static func is_wild(essence_id: String) -> bool:
	return essence_id == Essence.AURORA

## Photonengas zählt immer zuerst - der einzige Eingriff in die Zählreihenfolge.
static func counts_first(essence_id: String) -> bool:
	return essence_id == Essence.PHOTON_GAS

## Wasserstoff: eine ROH gewürfelte 1 lässt die Hand fumbeln (der physische
## Wert, nicht der verwandelte - Knallgas kennt keine Linse).
static func forces_farkle(raw_values: Array[int], sets: Dictionary) -> bool:
	for slot in sets:
		var index := int(slot)
		if not set_at(sets, index).has(Essence.HYDROGEN):
			continue
		if index < raw_values.size() and raw_values[index] == 1:
			return true
	return false

## Löschgas: dieser Würfel kann einen Fumble schlucken - einmal je Runde, und
## nur wenn er am Wurf beteiligt war. Der Rundenzustand liegt bei GameRun.
static func smothers_farkle(essence_id: String) -> bool:
	return essence_id == Essence.CARBON_DIOXIDE

## Halogen: die Werkstattlampe brennt weiter - dieser Würfel bleibt auch nach
## der Unterschrift gravierbar, während der Rest der Werkbank gesperrt ist.
static func ignores_bench_lock(essence_id: String) -> bool:
	return essence_id == Essence.HALOGEN

## Irrlicht: der klassische Falschspieler-Move - einmal je Runde darf dieser
## Würfel nach dem Liegen auf eine Nachbarseite kippen.
static func can_tip(essence_id: String) -> bool:
	return essence_id == Essence.WILL_O_WISP

## Zerfällt die Essenz eigene Seiten? (Radon, je Abrechnung.)
static func decays(essence_id: String) -> bool:
	return essence_id == Essence.RADON

## Radon-Zerfall EINES Würfels: eine zufällige Seite verliert ein Auge, sobald
## der Würfel in der genommenen Kombination liegt. Der Zerfall reitet damit auf
## dem AUSLÖSER, nicht auf der Abrechnung - ein Radon-Würfel, der nie gespielt
## wird, zerfällt auch nicht.
## Kandidaten sind nur Seiten, die wirklich verlieren KÖNNEN - sonst würfelt sich
## die Strafe an Boden- und Einbrand-Seiten zufällig selbst weg.
## true, wenn eine Seite geschrumpft ist.
static func decay_die(die: DieDefinition) -> bool:
	if die == null or not decays(die.essence_id):
		return false
	var candidates: Array[int] = []
	for face in die.faces.size():
		if die.faces[face] <= EtchingEffects.MIN_FACE_VALUE:
			continue
		if RiftEffects.protects_face_value(die.rifts_on(face)):
			continue
		candidates.append(face)
	if candidates.is_empty():
		return false
	die.faces[candidates[randi() % candidates.size()]] -= 1
	return true

# --- Quintessenz: EINE Aggregation, nie verstreute Sonderfälle ------------------

## Bedingte Krits gehören dem Würfel, der sie geladen hat: Xenons Blitz und der
## Einschlag des Kugelblitzes hängen an dessen Rundenzustand (CTX_ESSENCE_ARMED),
## nicht an der Essenz - kopiert werden sie darum NIE. Auch die Joker-Eigenschaft
## des Polarlichts wandert nicht mit, sonst gäbe es zwei Joker und die Erkennung
## verlöre ihre Unikat-Annahme.
const UNCOPYABLE := [Essence.XENON, Essence.BALL_LIGHTNING, Essence.AURORA]

## Wirksame Essenz-Mengen je Slot: normal die eigene, für die Quintessenz die
## eigene PLUS die jedes anderen liegenden Würfels. Diese Funktion ist die
## einzige Stelle, an der kopiert wird - der ctx-Bau ruft sie, alle Effekt-Hooks
## lesen danach nur noch fertige Mengen.
static func effective_sets(own_by_slot: Dictionary) -> Dictionary:
	var sets := {}
	for slot in own_by_slot:
		var own := str(own_by_slot[slot])
		var effective: Array[String] = []
		if own != "":
			effective.append(own)
		if own == Essence.QUINTESSENCE:
			for other in own_by_slot:
				if other == slot:
					continue
				var borrowed := str(own_by_slot[other])
				if borrowed != "" and not UNCOPYABLE.has(borrowed) and not effective.has(borrowed):
					effective.append(borrowed)
		if not effective.is_empty():
			sets[slot] = effective
	return sets

## Wirksame Menge eines Slots ([] = seelenlos). Liest BEIDE Formen: die
## Mengen-Landkarte (CTX_ESSENCE_SET) und die schlichte Slot -> id-Landkarte
## (CTX_ESSENCES) - letztere trägt die Identität des Würfels, erstere seine
## geborgten Seelen. Ein einzelner String zählt als einelementige Menge.
static func set_at(sets: Dictionary, slot: int) -> Array[String]:
	var out: Array[String] = []
	var value: Variant = sets.get(slot, [])
	if typeof(value) == TYPE_STRING:
		var single := str(value)
		if single != "":
			out.append(single)
		return out
	out.assign(value)
	return out

## Der EINZIGE Faktor eines Würfels: bei geborgten Seelen das MAXIMUM, nie das
## Produkt - die Ein-Faktor-Invariante ist der ganze Grund, warum Quecksilber
## als Seiten-Material gehen musste.
static func activation_factor_of(essence_ids: Array[String], charm_ids: Array[String] = [], is_stress: bool = false) -> int:
	var best := 1
	for essence_id in essence_ids:
		best = maxi(best, activation_factor(essence_id, charm_ids, is_stress))
	return best

## Augen-Beitrag durch ALLE wirksamen Seelen nacheinander (Wasserstoff verdoppelt,
## Miasma halbiert, Antimaterie kehrt um - Verkettung ist gewollt).
static func eye_value_of(essence_ids: Array[String], eyes: int) -> int:
	var result := eyes
	for essence_id in essence_ids:
		result = eye_value(essence_id, result)
	return result

static func money_of(essence_ids: Array[String], value: int, combo_size: int) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += money_for(essence_id, value, combo_size)
	return total

static func face_growth_of(essence_ids: Array[String]) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += face_growth(essence_id)
	return total

static func protects_face_value_of(essence_ids: Array[String]) -> bool:
	for essence_id in essence_ids:
		if protects_face_value(essence_id):
			return true
	return false

static func ignores_dice_filters_of(essence_ids: Array[String]) -> bool:
	for essence_id in essence_ids:
		if ignores_dice_filters(essence_id):
			return true
	return false

static func counts_first_of(essence_ids: Array[String]) -> bool:
	for essence_id in essence_ids:
		if counts_first(essence_id):
			return true
	return false

static func extra_pointer_links_of(essence_ids: Array[String]) -> int:
	var best := 0
	for essence_id in essence_ids:
		best = maxi(best, extra_pointer_links(essence_id))
	return best

## Krits ALLER wirksamen Seelen multipliziert - hier ist das Produkt richtig, es
## sind verschiedene Schläge (die bedingten stehen ohnehin nicht in der Menge).
static func crit_of(essence_ids: Array[String], value: int, crits_before: int = 0, armed: bool = false) -> int:
	var factor := 1
	for essence_id in essence_ids:
		factor *= crit_once_for(essence_id, value, crits_before, armed)
	return maxi(1, factor)

## Essenz-id eines Slots aus dem ctx-Dictionary ("" = keine).
## Die EIGENE Essenz eines Slots ("" = keine) - Identität, nicht Wirkung. Für
## das, was an einem Würfel WIRKT, gibt es set_at (die Quintessenz borgt sich
## fremde Seelen). Liest beide ctx-Formen.
static func essence_at(essences: Dictionary, slot: int) -> String:
	var found := set_at(essences, slot)
	return found[0] if not found.is_empty() else ""
