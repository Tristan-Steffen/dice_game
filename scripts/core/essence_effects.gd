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

## Neon zahlt fest, Natriumdampf je Mitwürfel, Zyanidgas je eigener Gold-Seite.
const NEON_MONEY := 3
const SODIUM_MONEY_PER_DIE := 1
const CYANIDE_PER_GOLD := 3

## Grubengas: Basispunkte, die JEDER Krit dieser Hand sofort zündet.
const FIREDAMP_BASE := 20

## Halogen legt seinen Mult additiv auf jede Auslösung.
const HALOGEN_MULT := 5

## Photonengas sammelt Licht: Augen je Auslösung, die vor ihm zählte.
const PHOTON_EYE_PER_TRIGGER := 5

## Strahlungsdruck bläht ALLE Seiten je Auslösung auf.
const PRESSURE_GROWTH := 2

## Xenon/Kugelblitz kriten fest; Elmsfeuer verdoppelt seinen Faktor im Sturm.
const XENON_CRIT := 1.5
const BALL_CRIT := 2.0
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
## haben. Antimaterie zählt NEGATIV - ihre Basis klemmt der Aufrufer. Der
## Wasserstoff sitzt NICHT hier: er ist eine Linse auf dem gezeigten WERT
## (lens_value), sonst verdoppelte er zweimal.
static func eye_value(essence_id: String, eyes: int) -> int:
	match essence_id:
		Essence.ANTIMATTER:
			return -eyes
	return eyes

## Linse auf den GEZEIGTEN Wert, direkt nach der Charm-Verwandlungskette: der
## Wasserstoff verdoppelt. Der verdoppelte Wert ist der, den auch die Erkennung
## sieht (Überzahl-Regel: eine 6 zeigt 12 und bildet Kombinationen als 2).
static func lens_value(essence_id: String, value: int) -> int:
	match essence_id:
		Essence.HYDROGEN:
			return value * 2
	return value

## Additiver Mult EINER Auslösung: das Halogen leuchtet die Hand aus.
static func mult_bonus_once(essence_id: String) -> int:
	return HALOGEN_MULT if essence_id == Essence.HALOGEN else 0

## Photonengas: +5 Augen je Auslösung, die in dieser Hand VOR dieser zählte.
static func trigger_eye_bonus(essence_id: String, triggers_before: int) -> int:
	if essence_id != Essence.PHOTON_GAS:
		return 0
	return PHOTON_EYE_PER_TRIGGER * maxi(0, triggers_before)

## Radon strahlt: +2 Augen auf JEDEN anderen gewerteten Würfel, je Auslösung.
static func foreign_eye_bonus(slot: int, scored: Array[int], sets: Dictionary) -> int:
	var bonus := 0
	for other in scored:
		if other != slot and set_at(sets, other).has(Essence.RADON):
			bonus += RADON_EYE_BONUS
	return bonus

## Essenz-Krit EINER Auslösung (Material-Krit-Substufe, VOR den Charm-Krits).
## crits_before: Krits, die in dieser Hand schon zündeten (Ozon).
static func crit_once_for(essence_id: String, value: int, crits_before: int = 0) -> float:
	match essence_id:
		Essence.XENON:
			return XENON_CRIT
		Essence.BALL_LIGHTNING:
			return BALL_CRIT
		Essence.OZONE:
			return maxf(1.0, 1.0 + float(crits_before))
		Essence.ANTIMATTER:
			return maxf(1.0, float(value))
	return 1.0

## Geld EINER Auslösung: Neon fest, Natriumdampf je Mitwürfel. Gebucht wird über
## GameRun.add_money. (Zyanidgas zahlt je ZUG, nicht je Auslösung - siehe
## gold_face_money_of.)
static func money_for(essence_id: String, _value: int, combo_size: int) -> int:
	match essence_id:
		Essence.NEON:
			return NEON_MONEY
		Essence.SODIUM_VAPOR:
			return maxi(0, combo_size - 1) * SODIUM_MONEY_PER_DIE
	return 0

## Basis-Zuschlag, den EIN Krit dieser Hand sofort zündet: +20 je gewertetem
## Grubengas-Würfel. Der Aufrufer bucht ihn an genau der Stelle, an der der Krit
## fiel - so steht er auch im ScoreBreakdown dort.
static func firedamp_step(scored: Array[int], sets: Dictionary) -> int:
	var bonus := 0
	for slot in scored:
		if set_at(sets, slot).has(Essence.FIREDAMP):
			bonus += FIREDAMP_BASE
	return bonus

## Stickstoff: die Seiten dieses Würfels verlieren nie an Wert (Glas schrumpft
## nicht, Zerfall greift nicht).
static func protects_face_value(essence_id: String) -> bool:
	return essence_id == Essence.NITROGEN

## Wachstum der OBEREN Seite je Auslösung: Helium hebt sie, Strahlungsdruck und
## Lawinenlicht blähen den ganzen Würfel (turn = Zug-Nummer der Runde).
static func face_growth(essence_id: String, turn_index: int = 1) -> int:
	match essence_id:
		Essence.HELIUM:
			return 1
		Essence.RADIATION_PRESSURE:
			return PRESSURE_GROWTH
		Essence.AVALANCHE:
			return maxi(1, turn_index)
	return 0

## Wachstum, das ALLE Seiten trifft (Strahlungsdruck, Lawinenlicht) - die obere
## folgt schon über face_growth, die übrigen schreibt der Zug.
static func all_faces_growth(essence_id: String, turn_index: int = 1) -> int:
	match essence_id:
		Essence.RADIATION_PRESSURE:
			return PRESSURE_GROWTH
		Essence.AVALANCHE:
			return maxi(1, turn_index)
	return 0

## Firnis: seine Materialstufen zählen in der WERTUNG eine Stufe höher - nie in
## der Def, die Nehmen-Effekte rechnen weiter mit der echten Stufe.
static func level_boost(essence_id: String) -> int:
	return 1 if essence_id == Essence.VARNISH else 0

## Stufe, mit der die WERTUNG rechnet. Eine nackte Seite bleibt nackt (der Firnis
## legt auf Glasur, nicht auf Schale), und über III geht nichts.
static func boosted_level(level: int, essence_ids: Array[String]) -> int:
	var boost := level_boost_of(essence_ids)
	if level <= 0 or boost <= 0:
		return level
	return mini(DieMaterial.MAX_LEVEL, level + boost)

## Krypton: Klauseln, die Würfel AUSSPERREN (Parität), übersehen ihn. Kategorie-
## Drosseln bleiben davon unberührt - die sperren keine Würfel, sondern Hände.
static func ignores_dice_filters(essence_id: String) -> bool:
	return essence_id == Essence.KRYPTON

## Plasma: der Lichtbogen hängt zwei Glieder an die Leiterbahn-Kette und lässt
## sie dabei im Kreis springen.
const PLASMA_EXTRA_LINKS := 2

static func extra_pointer_links(essence_id: String) -> int:
	return PLASMA_EXTRA_LINKS if essence_id == Essence.PLASMA else 0

## Alle Seiten, die an diesem Würfel als Glied feuern - die EINZIGE Quelle, damit
## Wertung, Nehmen-Effekte und Vorschau dieselbe Kette sehen. Reihenfolge: erst
## die echte Leiterbahn, dann der Korona-Ring (aufsteigend), zuletzt die
## Röntgen-Gegenseite. Jede Seite höchstens einmal; Plasma verlängert NUR die
## echte Kette.
static func link_faces(die: DieDefinition, up_face: int, essence_ids: Array[String]) -> Array[int]:
	var faces: Array[int] = []
	if die == null or up_face < 0 or up_face >= 6:
		return faces
	faces.assign(die.pointer_chain(up_face, extra_pointer_links_of(essence_ids)))
	if essence_ids.has(Essence.CORONA):
		for face in DieDefinition.adjacent_faces(up_face):
			if not faces.has(face):
				faces.append(face)
	if essence_ids.has(Essence.XRAY):
		var opposite := DieDefinition.opposite_face(up_face)
		if not faces.has(opposite):
			faces.append(opposite)
	return faces

## Polarlicht: seine Augenzahl gilt der KOMBINATIONSSUCHE als Joker. Die Augen
## selbst bleiben die aufgedruckten - der Joker verschiebt nur, WELCHE Kategorie
## zutrifft, nie wie viel sie zahlt.
static func is_wild(essence_id: String) -> bool:
	return essence_id == Essence.AURORA

## Löschgas: dieser Würfel kann einen Fumble schlucken - einmal je Runde, und
## nur wenn er am Wurf beteiligt war. Der Rundenzustand liegt bei GameRun.
## Der Preis steht in GameRun.consume_smother: die obere Seite fällt auf 1.
static func smothers_farkle(essence_id: String) -> bool:
	return essence_id == Essence.CARBON_DIOXIDE

## Miasma: seine obere Seite halbiert sich dauerhaft, der Verlust wächst auf den
## übrigen gewerteten Seiten der Hand wieder nach (Nehmen-Effekt, je Zug einmal).
static func redistributes_faces(essence_id: String) -> bool:
	return essence_id == Essence.MIASMA

## Zyanidgas: +$3 je Gold-Seite DIESES Würfels, einmal je Zug.
static func gold_face_money_of(essence_ids: Array[String], materials: Array[String]) -> int:
	if not essence_ids.has(Essence.CYANIDE):
		return 0
	return materials.count(DieMaterial.GOLD) * CYANIDE_PER_GOLD

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

## Nicht borgbar sind nur die Seelen mit EIGENEM Speicher am Würfel-Exemplar
## (Lawinenlicht hängt am Zug-Zähler seiner Seiten, die Phosphoreszenz an ihrem
## Basis-Speicher) - ein geborgter Speicher gehörte sonst zwei Würfeln. Dazu die
## Joker-Eigenschaft des Polarlichts: zwei Joker, und die Erkennung verlöre ihre
## Unikat-Annahme.
const UNCOPYABLE := [Essence.AURORA, Essence.AVALANCHE, Essence.PHOSPHORESCENCE]

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

## Augen-Beitrag durch ALLE wirksamen Seelen nacheinander (Antimaterie kehrt um -
## Verkettung ist gewollt).
static func eye_value_of(essence_ids: Array[String], eyes: int) -> int:
	var result := eyes
	for essence_id in essence_ids:
		result = eye_value(essence_id, result)
	return result

## Linse ALLER wirksamen Seelen auf den gezeigten Wert (Wasserstoff verdoppelt).
static func lens_value_of(essence_ids: Array[String], value: int) -> int:
	var result := value
	for essence_id in essence_ids:
		result = lens_value(essence_id, result)
	return result

static func mult_bonus_of(essence_ids: Array[String]) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += mult_bonus_once(essence_id)
	return total

static func trigger_eye_bonus_of(essence_ids: Array[String], triggers_before: int) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += trigger_eye_bonus(essence_id, triggers_before)
	return total

## Stufen-Aufschlag der Wertung (Firnis) - das Maximum, nie die Summe.
static func level_boost_of(essence_ids: Array[String]) -> int:
	var best := 0
	for essence_id in essence_ids:
		best = maxi(best, level_boost(essence_id))
	return best

static func money_of(essence_ids: Array[String], value: int, combo_size: int) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += money_for(essence_id, value, combo_size)
	return total

static func face_growth_of(essence_ids: Array[String], turn_index: int = 1) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += face_growth(essence_id, turn_index)
	return total

static func all_faces_growth_of(essence_ids: Array[String], turn_index: int = 1) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += all_faces_growth(essence_id, turn_index)
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

static func extra_pointer_links_of(essence_ids: Array[String]) -> int:
	var best := 0
	for essence_id in essence_ids:
		best = maxi(best, extra_pointer_links(essence_id))
	return best

## Krits ALLER wirksamen Seelen multipliziert - hier ist das Produkt richtig, es
## sind verschiedene Schläge (geborgtes Xenon + Kugelblitz ergibt ×3).
static func crit_of(essence_ids: Array[String], value: int, crits_before: int = 0) -> float:
	var factor := 1.0
	for essence_id in essence_ids:
		factor *= crit_once_for(essence_id, value, crits_before)
	return maxf(1.0, factor)

## Essenz-id eines Slots aus dem ctx-Dictionary ("" = keine).
## Die EIGENE Essenz eines Slots ("" = keine) - Identität, nicht Wirkung. Für
## das, was an einem Würfel WIRKT, gibt es set_at (die Quintessenz borgt sich
## fremde Seelen). Liest beide ctx-Formen.
static func essence_at(essences: Dictionary, slot: int) -> String:
	var found := set_at(essences, slot)
	return found[0] if not found.is_empty() else ""
