class_name EssenceEffects
## Reine Wirkung der Essenzen (siehe Essence), über die id aufgelöst - nie ein
## stiller Zweig in scene_root oder DiceScoring. Eine Essenz gehört dem GANZEN
## Würfel und wirkt, sobald er wertet; sie ist Charakter, nie Seiten-Payload
## (das ist Material-Land): Auslösung, Reihenfolge, Physik, Ökonomie.
##
## AUSLÖSE-MATHE (Invariante): genau ZWEI Achsen, die sich multiplizieren -
## Würfel-Trigger (Essenz-Faktor, Echo-Kammer, Sauerstoff/Sonnenwind) × Seiten-
## Trigger (Nachglühen, Hasenpfote & Co.). INNERHALB einer Achse addiert alles.
## Mehr Achsen gibt es nicht, darum kann nichts explodieren.

## Radon strahlt auf jeden anderen Würfel der Kombination; die Bleischürze hebt
## den Satz und nimmt dem Würfel gleichzeitig den Zerfall.
const RADON_EYE_BONUS := 2
const RADON_EYE_BONUS_SHIELDED := 3

## Neon zahlt je gezähltem Würfel der Kombination (sich selbst eingeschlossen),
## Natriumdampf je ANDEREM, Zyanidgas je eigener Gold-Seite - das Scheidewasser
## legt seinen kleineren Satz auf die Gold-Seiten der MITWÜRFEL.
const NEON_MONEY_PER_DIE := 2
const SODIUM_MONEY_PER_DIE := 1
const CYANIDE_PER_GOLD := 2
const AQUA_FORTIS_PER_GOLD := 1

## Grubengas: Basispunkte, die JEDER Krit dieser Hand sofort zündet.
const FIREDAMP_BASE := 20

## Halogen legt seinen Mult additiv auf jede Auslösung.
const HALOGEN_MULT := 5

## Photonengas sammelt Licht: Augen je Auslösung, die vor ihm zählte.
const PHOTON_EYE_PER_TRIGGER := 5

## Helium hebt die obere Seite je Auslösung.
const HELIUM_GROWTH := 3

## Strahlungsdruck bläht ALLE Seiten je Auslösung auf - der Druckkessel tauscht
## den festen Schritt gegen einen prozentualen (mindestens +1).
const PRESSURE_GROWTH := 2
const PRESSURE_GROWTH_PERCENT := 10

## Amalgam: zusätzliche ANTRITTE des Quecksilberdampf-Würfels selbst.
const AMALGAM_EXTRA := 2

## Xenon/Kugelblitz kriten fest; Elmsfeuer verdoppelt seinen Faktor im Sturm.
const XENON_CRIT := 1.5
const BALL_CRIT := 2.0
const STORM_FACTOR := 4

## Sonnensegel: Auslösungen je VERSCHIEDENER Essenz vor dem Sonnenwind (ohne den
## Charm zählt er jeden Essenz-Würfel einfach).
const SOLAR_SAIL_PER_ESSENCE := 2

## Acetylen brennt an der Kombinationsstufe; der Schneidbrenner legt Mult auf
## dieselbe Stufe. Stufe 0 = frische Kombination, also beide Male nichts.
const ACETYLENE_PER_LEVEL := 10
const CUTTING_TORCH_PER_LEVEL := 3

## Schwarzlicht zahlt je gewertetem Würfel ohne Material.
const BLACK_LIGHT_PER_DIE := 3

## Lichtsäule: zusätzliche Antritte, die JEDER andere gewertete Würfel gleicher
## Augenzahl bekommt - der Eisspiegel verdoppelt den Satz.
const LIGHT_PILLAR_ACTIVATIONS := 1
const LIGHT_PILLAR_ACTIVATIONS_MIRRORED := 2

## Mitternachtssonne: Antritte je schon genommener Hand dieser Runde; der
## Polartag zählt jede doppelt.
const MIDNIGHT_SUN_ACTIVATIONS := 1
const MIDNIGHT_SUN_ACTIVATIONS_POLAR := 2

## Tscherenkow-Licht: Krit ×(1 + Energie ÷ 5); der Steuerstab halbiert den Teiler
## noch einmal mehr als zur Hälfte.
const CHERENKOV_DIVISOR := 5.0
const CHERENKOV_DIVISOR_MODERATED := 2.0

## Sternschnuppe und Gammablitz kriten an ihrer ERSTEN Wertung der Runde; der
## Magnetar löst den Gammablitz von dieser Bedingung.
const SHOOTING_STAR_CRIT := 4.0
const GAMMA_BURST_CRIT := 10.0

## Fuchsfeuer: Augen je zwei Würfeln in der Ablage (Pilzgeflecht legt zusätzlich
## die Augensumme der Ablage drauf).
const FOXFIRE_PER_PAIR := 10

## Hintergrundstrahlung: dauerhaftes Wachstum JEDER Seite JEDES liegenden
## Würfels, je Wertung.
const BACKGROUND_GROWTH := 1

## Glasfaser: wie oft ein gezündetes Pointer-Glied seine Zielseite feuert -
## die Rückkopplung legt eine dritte Zündung drauf.
const LINK_FIRES_DEFAULT := 1
const OPTICAL_FIBER_FIRES := 2
const OPTICAL_FIBER_FIRES_FEEDBACK := 3

## Faktor der WÜRFEL-Achse - die einzige Stelle, an der auf ihr ein Faktor
## entsteht. Quecksilberdampf (Charm) legt +1 auf jeden Faktor, der überhaupt
## einer ist: das verbannte Material lebt als Verstärker weiter.
static func activation_factor(essence_id: String, charm_ids: Array[String] = [], is_stress: bool = false) -> int:
	var factor := 1
	match essence_id:
		Essence.ARGON:
			factor = 2
		Essence.MERCURY_VAPOR:
			factor = 3
		Essence.ST_ELMOS_FIRE:
			# Das Sturmglas hält den Sturm über der ganzen Runde - nur für DIESEN
			# Würfel, nie global (Klauseln und Konditionen kippten sonst mit).
			factor = STORM_FACTOR if (is_stress or charm_ids.has(Charm.STORM_GLASS)) else 2
	if factor >= 2 and charm_ids.has(Charm.MERCURY_VAPOR):
		factor += 1
	return factor

## ADDITIVE Würfel-Trigger aus der Zählreihenfolge: Sauerstoff facht den NÄCHSTEN
## an, das Amalgam macht den Quecksilberdampf zur zweiten solchen Quelle, der
## Sonnenwind reitet auf jedem Essenz-Würfel, der vor ihm gezählt wurde (mit
## Sonnensegel: +2 je VERSCHIEDENER Seele statt +1 je Würfel), und die Tarnkappe
## gibt jedem Krypton-Würfel einen Antritt dazu.
## Das Manometer facht den Würfel an, wenn er der EINZIGE beseelte der Hand ist;
## die Lichtsäule facht jeden anderen gewerteten Würfel gleicher Augenzahl an
## (dafür braucht sie values - die GEZEIGTEN Werte, auf denen auch die Reihe sortiert).
## order ist die kanonische Reihe (DiceScoring.trigger_order), nie eine physische.
## hands_taken sind die schon genommenen Hände DIESER Runde (Mitternachtssonne).
static func extra_activations(slot: int, order: Array[int], sets: Dictionary, charm_ids: Array[String] = [], values: Array[int] = [], hands_taken: int = 0) -> int:
	var index := order.find(slot)
	if index < 0:
		return 0
	var extra := 0
	extra += _light_pillar_activations(slot, order, sets, charm_ids, values)
	extra += _midnight_sun_activations(slot, sets, charm_ids, hands_taken)
	if index > 0:
		var before := set_at(sets, order[index - 1])
		if before.has(Essence.OXYGEN):
			extra += 1
	# Amalgam: der Quecksilberdampf-Würfel selbst tritt zweimal mehr an
	# (Würfel-Achse, additiv - der Faktor 3 der Seele bleibt unberührt).
	if charm_ids.has(Charm.AMALGAM) and set_at(sets, slot).has(Essence.MERCURY_VAPOR):
		extra += AMALGAM_EXTRA
	# Tarnkappe: der verborgene Würfel tritt einmal mehr an.
	if charm_ids.has(Charm.CAMOUFLAGE) and set_at(sets, slot).has(Essence.KRYPTON):
		extra += 1
	if set_at(sets, slot).has(Essence.SOLAR_WIND):
		if charm_ids.has(Charm.SOLAR_SAIL):
			var seen: Array[String] = []
			for k in index:
				for essence_id in set_at(sets, order[k]):
					if not seen.has(essence_id):
						seen.append(essence_id)
			extra += SOLAR_SAIL_PER_ESSENCE * seen.size()
		else:
			for k in index:
				if not set_at(sets, order[k]).is_empty():
					extra += 1
	return extra

## Manometer: liegt GENAU EIN beseelter Würfel in der gewerteten Reihe, wirkt
## seine SEELE mehrfach - je Exemplar einmal mehr. Nicht der Würfel tritt öfter
## an (das wäre ein zweiter Faktor auf der Würfel-Achse), sondern die Essenz
## wirkt zweimal.
## Wiederholt wird: der Essenz-Krit (je Wiederholung ein EIGENER Schlag, nie im
## Quadrat), das Essenz-Geld je Zündung, das Seiten-Wachstum (Helium,
## Strahlungsdruck) und die deterministischen Glieder (Röntgenlicht, Korona).
## NICHT wiederholt: Linsen (Wasserstoff), die Augen-Umkehr der Antimaterie,
## Kryptons "zählt immer mit", der Schutz (Stickstoff), der Faktor der
## Würfel-Achse und alles, was einem Charm oder einem Material gehört.
static func essence_repeat_count(slot: int, order: Array[int], sets: Dictionary, charm_ids: Array[String] = []) -> int:
	var copies := charm_ids.count(Charm.PRESSURE_GAUGE)
	if copies == 0 or set_at(sets, slot).is_empty():
		return 1
	for other in order:
		if other != slot and not set_at(sets, other).is_empty():
			return 1
	return 1 + copies

## Lichtsäule: jeder ANDERE gewertete Würfel mit derselben Augenzahl tritt öfter
## an - der Eisspiegel verdoppelt den Satz. Die Säule selbst geht leer aus.
static func _light_pillar_activations(slot: int, order: Array[int], sets: Dictionary, charm_ids: Array[String], values: Array[int]) -> int:
	if slot >= values.size():
		return 0
	var rate := LIGHT_PILLAR_ACTIVATIONS_MIRRORED if charm_ids.has(Charm.ICE_MIRROR) else LIGHT_PILLAR_ACTIVATIONS
	var extra := 0
	for other in order:
		if other == slot or other >= values.size() or values[other] != values[slot]:
			continue
		if set_at(sets, other).has(Essence.LIGHT_PILLAR):
			extra += rate
	return extra

## Mitternachtssonne: sie geht nicht unter - je schon genommener Hand dieser
## Runde tritt sie einmal mehr an, mit Polartag zweimal.
static func _midnight_sun_activations(slot: int, sets: Dictionary, charm_ids: Array[String], hands_taken: int) -> int:
	if not set_at(sets, slot).has(Essence.MIDNIGHT_SUN):
		return 0
	var rate := MIDNIGHT_SUN_ACTIVATIONS_POLAR if charm_ids.has(Charm.POLAR_DAY) else MIDNIGHT_SUN_ACTIVATIONS
	return rate * maxi(0, hands_taken)

## Wie oft ein GEZÜNDETES Pointer-Glied seine Zielseite feuert: die Glasfaser
## verstärkt das Licht im Glas (Rückkopplung dreifach), die Zündspule tut
## dasselbe am Plasma. Das MAXIMUM, nie das Produkt - zwei Verstärker sind kein
## Faktor übereinander.
static func link_fire_count(essence_ids: Array[String], charm_ids: Array[String] = []) -> int:
	var shots := LINK_FIRES_DEFAULT
	if essence_ids.has(Essence.OPTICAL_FIBER):
		shots = maxi(shots, OPTICAL_FIBER_FIRES_FEEDBACK if charm_ids.has(Charm.FEEDBACK) else OPTICAL_FIBER_FIRES)
	if essence_ids.has(Essence.PLASMA) and charm_ids.has(Charm.IGNITION_COIL):
		shots = maxi(shots, OPTICAL_FIBER_FIRES)
	return shots

## Fuchsfeuer: +10 Augen je ZWEI Würfeln in der Ablage, je Auslösung. Das
## Pilzgeflecht legt zusätzlich die Summe der oben liegenden Ablage-Seiten drauf.
static func discard_eye_bonus(essence_id: String, discard_values: Array[int], charm_ids: Array[String] = []) -> int:
	if essence_id != Essence.FOXFIRE:
		return 0
	var bonus := (discard_values.size() / 2) * FOXFIRE_PER_PAIR
	if charm_ids.has(Charm.MYCELIUM):
		for value in discard_values:
			bonus += value
	return bonus

static func discard_eye_bonus_of(essence_ids: Array[String], discard_values: Array[int], charm_ids: Array[String] = []) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += discard_eye_bonus(essence_id, discard_values, charm_ids)
	return total

## Hintergrundstrahlung: wird sie gewertet, wachsen ALLE Seiten ALLER liegenden
## Würfel dauerhaft. Nehmen-Effekt wie das Miasma - die Wertung bleibt unberührt.
static func grows_all_dice(essence_id: String) -> bool:
	return essence_id == Essence.BACKGROUND_RADIATION

static func grows_all_dice_of(essence_ids: Array[String]) -> bool:
	for essence_id in essence_ids:
		if grows_all_dice(essence_id):
			return true
	return false

## Augen-Beitrag EINER Auslösung, nachdem die Charms ihren Augenwert gebildet
## haben. Antimaterie zählt NEGATIV - ihre Basis klemmt der Aufrufer. Der
## Wasserstoff sitzt NICHT hier: er ist eine Linse auf dem gezeigten WERT
## (lens_value), sonst verdoppelte er zweimal.
## Die Magnetfalle hält die Antimaterie im Feld: ihre Augen zählen wieder normal,
## der Krit bleibt.
static func eye_value(essence_id: String, eyes: int, charm_ids: Array[String] = []) -> int:
	match essence_id:
		Essence.ANTIMATTER:
			return eyes if charm_ids.has(Charm.MAGNETIC_TRAP) else -eyes
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

## Acetylen: Basispunkte je Stufe der genommenen Kombination, je Auslösung. Der
## Schneidbrenner legt Mult auf dieselbe Stufe - beide hängen an derselben Zahl.
static func combo_level_base(essence_id: String, combo_level: int) -> int:
	if essence_id != Essence.ACETYLENE:
		return 0
	return ACETYLENE_PER_LEVEL * maxi(0, combo_level)

static func combo_level_mult(essence_id: String, combo_level: int, charm_ids: Array[String] = []) -> int:
	if essence_id != Essence.ACETYLENE or not charm_ids.has(Charm.CUTTING_TORCH):
		return 0
	return CUTTING_TORCH_PER_LEVEL * maxi(0, combo_level)

## Vorlauf der Hand-Zähler: normal fängt jede Hand bei null an, die Dunkelkammer
## (Auslösungen, Photonengas) und die Gewitterfront (Krits, Ozon) schleppen mit,
## was die bisherigen Hände DIESER Runde angesammelt haben. Der Aufrufer legt den
## Wert als Startstand in seinen Zähler - dann bleiben beide Leser unverändert.
static func round_trigger_offset(charm_ids: Array[String], round_triggers: int) -> int:
	return maxi(0, round_triggers) if charm_ids.has(Charm.DARKROOM) else 0

static func round_crit_offset(charm_ids: Array[String], round_crits: int) -> int:
	return maxi(0, round_crits) if charm_ids.has(Charm.STORM_FRONT) else 0

## Radon strahlt: bei JEDER seiner Zündungen wachsen die oberen Seiten aller
## ANDEREN gewerteten Würfel DAUERHAFT um +2 Augen - unter der Bleischürze um +3.
## Die Augen wandern also wirklich (Miasma-Grammatik ins Positive); ein Gewinn
## wird nie geblockt, Stickstoff und Einbrand wehren nur Verluste ab.
static func radon_eye_gift(essence_ids: Array[String], charm_ids: Array[String] = []) -> int:
	if not essence_ids.has(Essence.RADON):
		return 0
	return RADON_EYE_BONUS_SHIELDED if charm_ids.has(Charm.LEAD_APRON) else RADON_EYE_BONUS

## Wie viel der Blitzableiter auf den Kugelblitz-Krit legt: 1 je gewertetem
## Kugelblitz-Würfel (ohne den Charm nichts). Einmal je Hand bestimmt, wie der
## Grubengas-Schritt - der Krit darf sich nicht mitten in der Hand ändern.
static func ball_crit_bonus(scored: Array[int], sets: Dictionary, charm_ids: Array[String]) -> int:
	if not charm_ids.has(Charm.LIGHTNING_ROD):
		return 0
	var count := 0
	for slot in scored:
		if set_at(sets, slot).has(Essence.BALL_LIGHTNING):
			count += 1
	return count

## Essenz-Krit EINER Auslösung (Material-Krit-Substufe, VOR den Charm-Krits).
## crits_before: Krits, die in dieser Hand schon zündeten (Ozon).
## ball_bonus: Zuschlag des Blitzableiters auf den Kugelblitz.
## wild_value: die Zahl, zu der sich das Polarlicht macht - nur der Polarfilter
## setzt sie, sonst 0 (= kein Krit).
## charge: gelagerte Energie (Tscherenkow, Steuerstab halbiert den Teiler).
## first_scoring: erste Wertung dieses Würfels in der Runde (Sternschnuppe,
## Gammablitz - der Magnetar löst den Blitz davon).
## fumbles: Fumbles, mit denen der Vulkanblitz kritet (Runde + Aschewolke).
## first_firing: die ERSTE Zündung dieser Nahme (Würfel-Trigger 0, Seiten-Zündung
## 0) - nur die Sternschnuppe fragt danach, ihr Strich fällt genau einmal.
static func crit_once_for(essence_id: String, value: int, crits_before: int = 0,
		ball_bonus: int = 0, wild_value: int = 0, charm_ids: Array[String] = [],
		charge: int = 0, first_scoring: bool = false, fumbles: int = 0,
		first_firing: bool = true) -> float:
	match essence_id:
		Essence.XENON:
			return XENON_CRIT
		Essence.BALL_LIGHTNING:
			return BALL_CRIT + float(maxi(0, ball_bonus))
		Essence.OZONE:
			return maxf(1.0, 1.0 + float(crits_before))
		Essence.ANTIMATTER:
			return maxf(1.0, float(value))
		Essence.AURORA:
			return maxf(1.0, float(wild_value))
		Essence.CHERENKOV:
			var divisor := CHERENKOV_DIVISOR_MODERATED if charm_ids.has(Charm.MODERATOR) else CHERENKOV_DIVISOR
			return maxf(1.0, 1.0 + float(maxi(0, charge)) / divisor)
		Essence.SHOOTING_STAR:
			# Ein Strich am Himmel: der Würfel löst normal aus, der Krit fällt aber
			# genau EINMAL - beim ersten Zünden der ersten Wertung der Runde. Der
			# Meteorit lässt ihn bei JEDER Wertung eintreten, nie öfter als einmal.
			if not first_firing:
				return 1.0
			return SHOOTING_STAR_CRIT if (first_scoring or charm_ids.has(Charm.METEORITE)) else 1.0
		Essence.GAMMA_BURST:
			return GAMMA_BURST_CRIT if (first_scoring or charm_ids.has(Charm.MAGNETAR)) else 1.0
		Essence.VOLCANIC_LIGHTNING:
			return maxf(1.0, 1.0 + float(maxi(0, fumbles)))
	return 1.0

## Geld EINER Auslösung: Neon je gezähltem Würfel, Natriumdampf je Mitwürfel.
## Gebucht wird über GameRun.add_money. (Zyanidgas zahlt je ZUG statt je
## Auslösung - siehe gold_face_money_of; es reitet auf der ERSTEN Zündung.)
static func money_for(essence_id: String, _value: int, combo_size: int) -> int:
	match essence_id:
		Essence.NEON:
			return maxi(0, combo_size) * NEON_MONEY_PER_DIE
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

## Wachstum EINER Seite je Auslösung: Helium hebt die obere, Strahlungsdruck
## bläht den ganzen Würfel. value ist der Wert DIESER Seite - der Druckkessel
## rechnet prozentual, also braucht das Wachstum die Zahl, auf die es fällt.
static func face_growth(essence_id: String, charm_ids: Array[String] = [], value: int = 0) -> int:
	match essence_id:
		Essence.HELIUM:
			return HELIUM_GROWTH
		Essence.RADIATION_PRESSURE:
			if charm_ids.has(Charm.PRESSURE_VESSEL):
				return maxi(1, ceili(float(maxi(0, value)) * PRESSURE_GROWTH_PERCENT / 100.0))
			return PRESSURE_GROWTH
	return 0

## Wachstum, das ALLE Seiten trifft (Strahlungsdruck) - die obere folgt schon
## über face_growth, die übrigen schreibt der Zug.
static func all_faces_growth(essence_id: String, charm_ids: Array[String] = [], value: int = 0) -> int:
	if essence_id == Essence.RADIATION_PRESSURE:
		return face_growth(essence_id, charm_ids, value)
	return 0

## Firnis: seine Materialseiten zählen in der WERTUNG als veredelt - nie in der
## Def, die Nehmen-Effekte rechnen weiter mit dem echten Zustand.
static func level_boost(essence_id: String) -> int:
	return 1 if essence_id == Essence.VARNISH else 0

## Zustand, mit dem die WERTUNG rechnet. Eine nackte Seite bleibt nackt (der
## Firnis legt auf Glasur, nicht auf Schale), veredelt bleibt veredelt.
static func boosted_level(level: int, essence_ids: Array[String]) -> int:
	var boost := level_boost_of(essence_ids)
	if level <= 0 or boost <= 0:
		return level
	return mini(DieMaterial.MAX_LEVEL, level + boost)

## Krypton zählt IMMER mit: er tritt an, auch wenn er nicht zur Kombination
## gehört (Augen, Material, würfelgebundene Charms). Die ERKENNUNG bleibt davon
## unberührt - participating und die Kombi-Charms sehen ihn nicht, genau wie beim
## Vollzähler.
static func always_scored(essence_ids: Array[String]) -> bool:
	return essence_ids.has(Essence.KRYPTON)

static func always_scored_of(sets: Dictionary, slot: int) -> bool:
	return always_scored(set_at(sets, slot))

## Knallgas: die Kettenreaktion in der Ablage. Jeder ungezogene Würfel zahlt am
## Rundenende zusätzlich - je Knallgas-Würfel, der VOR ihm im Stapel liegt.
## Die Zündschnur hebt den Satz von $1 auf $3 (je Vorkommen +$2).
const DETONATING_GAS_BONUS := 1
const FUSE_STEP := 2

static func detonating_gas_bonus(charm_ids: Array[String] = []) -> int:
	return DETONATING_GAS_BONUS + FUSE_STEP * charm_ids.count(Charm.FUSE)

## Auszahlung je ungezogenem Würfel, in STAPEL-Reihenfolge. essence_ids ist die
## Seele je übrigem Würfel ("" = keine); der Knallgas-Würfel selbst bekommt
## nichts dazu, erst die hinter ihm.
static func leftover_die_payouts(essence_ids: Array[String], base_per_die: int, charm_ids: Array[String] = []) -> Array[int]:
	var out: Array[int] = []
	var bonus := detonating_gas_bonus(charm_ids)
	var chain := 0
	for essence_id in essence_ids:
		out.append(base_per_die + chain * bonus)
		if essence_id == Essence.DETONATING_GAS:
			chain += 1
	return out

## Plasma: der Lichtbogen hält den Pointer - er bekommt ZWEI Versuche statt
## einem. "Doppelte Chance" heißt also aggregiert (1 − (1−p)²), nie p × 2: aus
## 50 % werden 75 %, und ein Pointer erreicht damit NIE 100 %.
const PLASMA_SHOTS := 2

## Zünd-Chance der Pointer an diesem Würfel; base = DiceScoring.POINTER_CHANCE
## (die Grundchance wohnt dort, damit die Essenz nicht zurückgreifen muss).
static func pointer_chance(essence_id: String, base: float) -> float:
	if essence_id != Essence.PLASMA:
		return base
	return DiceScoring.pointer_chance_for(base, PLASMA_SHOTS)

## Nachbarseiten, die der Korona-Ring mitwertet - eine, unter der Sonnenfinsternis
## drei. Aufsteigend nach Seitenindex, damit die Auswahl deterministisch ist.
const CORONA_FACES := 1
const CORONA_FACES_ECLIPSED := 3

## Die Seiten, die als DETERMINISTISCHES Glied feuern - einmal nach allen
## Würfel-Triggern (der gewürfelte Pointer läuft getrennt davon). Sie vereinigt
## Essenz- und Runen-Glieder in EINER Liste: die Kehrseiten-Rune ist mechanisch
## dasselbe wie Röntgenlicht, nur an der Seite statt an der Seele, und ein
## zweiter Glied-Pfad daneben würde nur irgendwann auseinanderlaufen.
## Reihenfolge: erst der Korona-Ring (aufsteigend), dann die Gegenseite;
## jede Seite höchstens einmal.
static func link_faces(die: DieDefinition, up_face: int, essence_ids: Array[String],
		rune_ids: Array[String] = [], charm_ids: Array[String] = []) -> Array[int]:
	var faces: Array[int] = []
	if die == null or up_face < 0 or up_face >= 6:
		return faces
	if essence_ids.has(Essence.CORONA):
		var wanted := CORONA_FACES_ECLIPSED if charm_ids.has(Charm.SOLAR_ECLIPSE) else CORONA_FACES
		for face in DieDefinition.adjacent_faces(up_face):
			if faces.size() >= wanted:
				break
			if not faces.has(face):
				faces.append(face)
	if essence_ids.has(Essence.XRAY) or rune_ids.has(Rune.REVERSE):
		var opposite := DieDefinition.opposite_face(up_face)
		if not faces.has(opposite):
			faces.append(opposite)
	return faces

## Wie oft EIN Glied aus link_faces zündet: normal einmal, unter dem Stichel
## feuert die Kehrseite zweimal. Die Liste bleibt entdoppelt (jede Seite steht
## genau einmal darin) - nur die Zahl wächst, und Wertung wie Nehmen-Effekte
## lesen sie aus derselben Quelle.
static func det_link_fire_count(up_face: int, link_face: int, rune_ids: Array[String],
		charm_ids: Array[String]) -> int:
	if not charm_ids.has(Charm.BURIN) or not rune_ids.has(Rune.REVERSE):
		return 1
	return 2 if link_face == DieDefinition.opposite_face(up_face) else 1

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

## Miasma: NACH jeder Zündung halbiert sich seine obere Seite dauerhaft, und genau
## dieser Betrag wächst auf jeder anderen gewerteten Seite der Hand - verschachtelt
## in die Zählung, spätere Würfel zählen also schon den Zuwachs.
static func redistributes_faces(essence_id: String) -> bool:
	return essence_id == Essence.MIASMA

static func redistributes_faces_of(essence_ids: Array[String]) -> bool:
	for essence_id in essence_ids:
		if redistributes_faces(essence_id):
			return true
	return false

## Zyanidgas: +$2 je Gold-Seite DIESES Würfels, einmal je Zug. Das Scheidewasser
## legt zusätzlich $1 je Gold-Seite der MITWÜRFEL drauf (foreign_gold_faces zählt
## sie - der Aufrufer kennt die Defs, die Essenz nicht).
## Gezahlt wird an der ERSTEN Zündung des Würfels (MaterialEffects.
## plan_activation_money), damit das Geld sichtbar aus ihm herauskommt.
static func gold_face_money_of(essence_ids: Array[String], materials: Array[String],
		charm_ids: Array[String] = [], foreign_gold_faces: int = 0) -> int:
	if not essence_ids.has(Essence.CYANIDE):
		return 0
	var money := materials.count(DieMaterial.GOLD) * CYANIDE_PER_GOLD
	if charm_ids.has(Charm.AQUA_FORTIS):
		money += maxi(0, foreign_gold_faces) * AQUA_FORTIS_PER_GOLD
	return money

## Schwarzlicht: +$3 je gewertetem Würfel, der kein Material zeigt - einmal je
## ZUG wie das Zyanidgas, nie je Auslösung. bare_dice zählt der Aufrufer, er
## kennt die Materialien der Hand.
## Der Neonmarker eskaliert: zusätzlich $1 je materiallosem Würfel, den die Runde
## schon gewertet hat - round_bare_dice ist dieser Stand INKLUSIVE dieser Hand.
static func bare_die_money_of(essence_ids: Array[String], bare_dice: int,
		charm_ids: Array[String] = [], round_bare_dice: int = 0) -> int:
	if not essence_ids.has(Essence.BLACK_LIGHT):
		return 0
	var money := maxi(0, bare_dice) * BLACK_LIGHT_PER_DIE
	if charm_ids.has(Charm.HIGHLIGHTER):
		money += maxi(0, round_bare_dice)
	return money

## Ethylen: zählt der Würfel in einer Runde zum ersten Mal, wirft er je
## VERSCHIEDENEM Material seiner Seiten eine Gravur ab. Die Ernte selbst bucht
## GameRun.apply_material_harvest - sie greift in den Vorrat, nicht in die Wertung.
static func harvests_materials(essence_id: String) -> bool:
	return essence_id == Essence.ETHYLENE

static func harvests_materials_of(essence_ids: Array[String]) -> bool:
	for essence_id in essence_ids:
		if harvests_materials(essence_id):
			return true
	return false

## Irrlicht: der klassische Falschspieler-Move - einmal je Runde darf dieser
## Würfel nach dem Liegen auf eine Nachbarseite kippen.
static func can_tip(essence_id: String) -> bool:
	return essence_id == Essence.WILL_O_WISP

## Zerfällt die Essenz eigene Seiten? (Radon, je Abrechnung.) Die Bleischürze
## nimmt dem Strahler genau diesen Preis ab.
static func decays(essence_id: String, charm_ids: Array[String] = []) -> bool:
	return essence_id == Essence.RADON and not charm_ids.has(Charm.LEAD_APRON)

## Radon-Zerfall EINES Würfels: eine zufällige Seite verliert ein Auge, sobald
## der Würfel in der genommenen Kombination liegt. Der Zerfall reitet damit auf
## dem AUSLÖSER, nicht auf der Abrechnung - ein Radon-Würfel, der nie gespielt
## wird, zerfällt auch nicht.
## Kandidaten sind nur Seiten, die wirklich verlieren KÖNNEN - sonst würfelt sich
## die Strafe an Boden- und Einbrand-Seiten zufällig selbst weg.
## true, wenn eine Seite geschrumpft ist.
static func decay_die(die: DieDefinition, charm_ids: Array[String] = []) -> bool:
	if die == null or not decays(die.essence_id, charm_ids):
		return false
	var candidates: Array[int] = []
	for face in die.faces.size():
		if die.faces[face] <= EtchingEffects.MIN_FACE_VALUE:
			continue
		if RuneEffects.protects_face_value(die.runes_on(face)):
			continue
		candidates.append(face)
	if candidates.is_empty():
		return false
	die.faces[candidates[randi() % candidates.size()]] -= 1
	return true

# --- Quintessenz: EINE Aggregation, nie verstreute Sonderfälle ------------------

## Nicht borgbar ist die Seele mit EIGENEM Speicher am Würfel-Exemplar (die
## Phosphoreszenz hängt an ihrem Basis-Speicher) - ein geborgter Speicher gehörte
## sonst zwei Würfeln. Dazu die Joker-Eigenschaft des Polarlichts: zwei Joker, und
## die Erkennung verlöre ihre Unikat-Annahme.
const UNCOPYABLE := [Essence.AURORA, Essence.PHOSPHORESCENCE]

## Wirksame Essenz-Mengen je Slot: normal die eigene, für die Quintessenz die
## eigene PLUS die jedes anderen liegenden Würfels. Diese Funktion ist die
## einzige Stelle, an der kopiert wird - der ctx-Bau ruft sie, alle Effekt-Hooks
## lesen danach nur noch fertige Mengen.
## extra_borrowed: Seelen, die NICHT auf dem Tisch liegen und die Quintessenz
## trotzdem greift (Alkahest holt sie aus der Ablage) - dieselbe Unikat-Sperre.
static func effective_sets(own_by_slot: Dictionary, extra_borrowed: Array[String] = []) -> Dictionary:
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
				_borrow_into(effective, str(own_by_slot[other]))
			for borrowed in extra_borrowed:
				_borrow_into(effective, borrowed)
		if not effective.is_empty():
			sets[slot] = effective
	return sets

## Nimmt eine fremde Seele in die Menge auf - leere, unkopierbare und schon
## enthaltene fallen durch.
static func _borrow_into(effective: Array[String], borrowed: String) -> void:
	if borrowed != "" and not UNCOPYABLE.has(borrowed) and not effective.has(borrowed):
		effective.append(borrowed)

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

## Der EINZIGE Faktor der Würfel-Achse: bei geborgten Seelen das MAXIMUM, nie
## das Produkt - genau ein Faktor je Achse ist der ganze Grund, warum Quecksilber
## als Seiten-Material gehen musste.
static func activation_factor_of(essence_ids: Array[String], charm_ids: Array[String] = [], is_stress: bool = false) -> int:
	var best := 1
	for essence_id in essence_ids:
		best = maxi(best, activation_factor(essence_id, charm_ids, is_stress))
	return best

## Augen-Beitrag durch ALLE wirksamen Seelen nacheinander (Antimaterie kehrt um -
## Verkettung ist gewollt).
static func eye_value_of(essence_ids: Array[String], eyes: int, charm_ids: Array[String] = []) -> int:
	var result := eyes
	for essence_id in essence_ids:
		result = eye_value(essence_id, result, charm_ids)
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

static func combo_level_base_of(essence_ids: Array[String], combo_level: int) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += combo_level_base(essence_id, combo_level)
	return total

static func combo_level_mult_of(essence_ids: Array[String], combo_level: int, charm_ids: Array[String] = []) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += combo_level_mult(essence_id, combo_level, charm_ids)
	return total

## Veredelungs-Aufschlag der Wertung (Firnis) - das Maximum, nie die Summe.
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

static func face_growth_of(essence_ids: Array[String], charm_ids: Array[String] = [], value: int = 0) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += face_growth(essence_id, charm_ids, value)
	return total

static func all_faces_growth_of(essence_ids: Array[String], charm_ids: Array[String] = [], value: int = 0) -> int:
	var total := 0
	for essence_id in essence_ids:
		total += all_faces_growth(essence_id, charm_ids, value)
	return total

static func protects_face_value_of(essence_ids: Array[String]) -> bool:
	for essence_id in essence_ids:
		if protects_face_value(essence_id):
			return true
	return false

## Zünd-Chance ALLER wirksamen Seelen - die beste, nie das Produkt.
static func pointer_chance_of(essence_ids: Array[String], base: float) -> float:
	var best := base
	for essence_id in essence_ids:
		best = maxf(best, pointer_chance(essence_id, base))
	return best

## Krits ALLER wirksamen Seelen multipliziert - hier ist das Produkt richtig, es
## sind verschiedene Schläge (geborgtes Xenon + Kugelblitz ergibt ×3).
static func crit_of(essence_ids: Array[String], value: int, crits_before: int = 0,
		ball_bonus: int = 0, wild_value: int = 0, charm_ids: Array[String] = [],
		charge: int = 0, first_scoring: bool = false, fumbles: int = 0,
		first_firing: bool = true) -> float:
	var factor := 1.0
	for essence_id in essence_ids:
		factor *= crit_once_for(essence_id, value, crits_before, ball_bonus, wild_value,
			charm_ids, charge, first_scoring, fumbles, first_firing)
	return maxf(1.0, factor)

## Essenz-id eines Slots aus dem ctx-Dictionary ("" = keine).
## Die EIGENE Essenz eines Slots ("" = keine) - Identität, nicht Wirkung. Für
## das, was an einem Würfel WIRKT, gibt es set_at (die Quintessenz borgt sich
## fremde Seelen). Liest beide ctx-Formen.
static func essence_at(essences: Dictionary, slot: int) -> String:
	var found := set_at(essences, slot)
	return found[0] if not found.is_empty() else ""
