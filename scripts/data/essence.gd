class_name Essence
extends Resource
## Die Seele eines Würfels: ein Leuchtgas, beim Guss in der Schale versiegelt.
## Sie ist ANGEBOREN - kein Auftragen, kein Entfernen, kein Tauschen. Die einzige
## Quelle ist der Kauf eines Würfels, der sie schon trägt (DiceOffer/Pack/Slot).
## Nur Anzeige-Infos; die Wirkung löst EssenceEffects über die id auf. ids sind
## Konstanten, damit Tippfehler Compilerfehler sind.
##
## Häufige Essenzen sind HANDELSGASE (Flaschenware), seltene sind PHÄNOMENE -
## Licht, das sich eigentlich nicht abfüllen lässt; dass es trotzdem jemand
## getan hat, ist der Grund für Rarität und Schwarzmarkt.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

# --- Handelsgase (häufig) ---
const HELIUM := "helium"
const NEON := "neon"
const ARGON := "argon"
const KRYPTON := "krypton"
const XENON := "xenon"
const NITROGEN := "nitrogen"
const OXYGEN := "oxygen"
const HYDROGEN := "hydrogen"
const SODIUM_VAPOR := "sodium_vapor"
const FIREDAMP := "firedamp"
const CARBON_DIOXIDE := "carbon_dioxide"
const HALOGEN := "halogen"
const ACETYLENE := "acetylene"
const ARC_LAMP := "arc_lamp"

static func carbon_dioxide() -> Essence:
	return _make(CARBON_DIOXIDE, "Kohlendioxid",
		"Fumble verpuffen, wenn dieser Würfel an ihnen beteiligt ist.",
		"Fumble mit ihm verpuffen", Rarity.COMMON, Color(0.9, 0.92, 0.94))

static func halogen() -> Essence:
	return _make(HALOGEN, "Halogen",
		"+5 Mult.",
		"+5 Mult je Auslösung", Rarity.COMMON, Color(1.0, 0.96, 0.88))

# --- Phänomene (selten bis legendär) ---
const MERCURY_VAPOR := "mercury_vapor_essence"
const RADON := "radon"
const MIASMA := "miasma"
const ST_ELMOS_FIRE := "st_elmos_fire"
const BALL_LIGHTNING := "ball_lightning"
const SOLAR_WIND := "solar_wind"
const PHOTON_GAS := "photon_gas"
const OZONE := "ozone"
const PLASMA := "plasma"
const VACUUM := "vacuum"
const QUINTESSENCE := "quintessence"
const AURORA := "aurora"
const ANTIMATTER := "antimatter"
const RADIATION_PRESSURE := "radiation_pressure"
const CYANIDE := "cyanide"
const XRAY := "xray"
const VARNISH := "varnish"
const PHOSPHORESCENCE := "phosphorescence"
## Das einzige Handelsgas unter den Phänomenen - abfüllbar, nur nicht ungefährlich.
const DETONATING_GAS := "detonating_gas"
const CHERENKOV := "cherenkov"
const SHOOTING_STAR := "shooting_star"
const FOXFIRE := "foxfire"
const BLACK_LIGHT := "black_light"
const VOLCANIC_LIGHTNING := "volcanic_lightning"
const OPTICAL_FIBER := "optical_fiber"
const LIGHT_PILLAR := "light_pillar"
const MIDNIGHT_SUN := "midnight_sun"
const GAMMA_BURST := "gamma_burst"
const BACKGROUND_RADIATION := "background_radiation"
const SPARK_GAP := "spark_gap"

const NONE := ""

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## Kurzwirkung für Karten und Hover-Zeilen ("löst 2× aus").
@export var short: String = ""
@export var rarity: Rarity = Rarity.COMMON
## Kantenglühen des Würfels - essenzlose Würfel glühen nicht.
@export var glow: Color = Color.WHITE
## Nur im Schwarzmarkt zu haben (nie im normalen Shop, nie in Paketen).
@export var secret: bool = false
## Unikat: höchstens ein Exemplar im Pool, danach nicht mehr im Angebot.
@export var unique: bool = false

static func _make(essence_id: String, name: String, desc: String,
		short_text: String, rarity_value: Rarity, glow_color: Color) -> Essence:
	var essence := Essence.new()
	essence.id = essence_id
	essence.display_name = name
	essence.description = desc
	essence.short = short_text
	essence.rarity = rarity_value
	essence.glow = glow_color
	essence.unique = rarity_value == Rarity.LEGENDARY
	return essence

static func _secret(essence: Essence) -> Essence:
	essence.secret = true
	return essence

# --- Handelsgase ------------------------------------------------------------------

static func helium() -> Essence:
	return _make(HELIUM, "Helium",
		"Seine obere Seite wächst dauerhaft um +3.",
		"obere Seite wächst +3", Rarity.COMMON, Color(1.0, 0.72, 0.55))

static func neon() -> Essence:
	return _make(NEON, "Neon",
		"+$2 je gezähltem Würfel der Hand.",
		"+$2 je gezähltem Würfel", Rarity.COMMON, Color(1.0, 0.35, 0.15))

static func argon() -> Essence:
	return _make(ARGON, "Argon",
		"Der Würfel löst 2× aus.",
		"löst 2× aus", Rarity.COMMON, Color(0.62, 0.6, 0.95))

static func krypton() -> Essence:
	return _make(KRYPTON, "Krypton",
		"Zählt immer mit - auch außerhalb der Kombination.",
		"zählt immer mit", Rarity.COMMON, Color(0.55, 0.95, 0.7))

static func xenon() -> Essence:
	return _make(XENON, "Xenon",
		"Jede seiner Auslösungen kritet ×1,5.",
		"kritet ×1,5", Rarity.COMMON, Color(0.8, 0.9, 1.0))

static func nitrogen() -> Essence:
	return _make(NITROGEN, "Stickstoff",
		"Seine Seiten verlieren nie an Wert.",
		"Seiten verlieren nie Wert", Rarity.COMMON, Color(0.88, 0.93, 0.98))

static func oxygen() -> Essence:
	return _make(OXYGEN, "Sauerstoff",
		"Der nächste Würfel löst +1× aus.",
		"nächster Würfel +1 Auslösung", Rarity.COMMON, Color(0.45, 0.75, 1.0))

static func hydrogen() -> Essence:
	return _make(HYDROGEN, "Wasserstoff",
		"Sein gezeigter Wert verdoppelt sich.",
		"gezeigter Wert ×2", Rarity.COMMON, Color(1.0, 0.45, 0.6))

static func sodium_vapor() -> Essence:
	return _make(SODIUM_VAPOR, "Natriumdampf",
		"+$1 je anderem Würfel der Hand.",
		"+$1 je Mitwürfel", Rarity.COMMON, Color(1.0, 0.65, 0.25))

static func firedamp() -> Essence:
	return _make(FIREDAMP, "Grubengas",
		"+20 Basispunkte je bisherigem Krit der Hand.",
		"+20 Basis je Krit davor", Rarity.COMMON, Color(0.5, 0.65, 0.8))

static func acetylene() -> Essence:
	return _make(ACETYLENE, "Acetylen",
		"+10 Basispunkte je Stufe der genommenen Kombination.",
		"+10 Basis je Kombinationsstufe", Rarity.COMMON, Color(0.85, 0.92, 1.0))

## Warmes Weiss statt Ladungs-Violett: die Lampe brennt ruhig, sie glüht nicht.
static func arc_lamp() -> Essence:
	return _make(ARC_LAMP, "Bogenlampe",
		"Kann nicht durchbrennen: auf Überschlag bleibt sie stehen.",
		"brennt nie durch", Rarity.COMMON, Color(1.0, 0.95, 0.85))

# --- Phänomene --------------------------------------------------------------------

static func mercury_vapor() -> Essence:
	return _secret(_make(MERCURY_VAPOR, "Quecksilberdampf",
		"Der Würfel löst 3× aus.",
		"löst 3× aus", Rarity.RARE, Color(0.35, 0.7, 1.0)))

static func radon() -> Essence:
	return _secret(_make(RADON, "Radon",
		"Bei jeder Zündung wachsen die oberen Seiten aller anderen gewerteten Würfel um 2 Augen; je Abrechnung verliert eine zufällige eigene Seite 1 Auge.",
		"bestrahlt Mitwürfel dauerhaft", Rarity.RARE, Color(0.5, 1.0, 0.3)))

static func miasma() -> Essence:
	return _secret(_make(MIASMA, "Miasma",
		"Nach JEDER seiner Zündungen verliert seine obere Seite dauerhaft die Hälfte ihrer Augen - um diesen Betrag wächst jede andere gewertete Seite der Hand.",
		"halbiert sich je Zündung, die Hand wächst", Rarity.EPIC, Color(0.4, 0.55, 0.35)))

static func st_elmos_fire() -> Essence:
	return _make(ST_ELMOS_FIRE, "Elmsfeuer",
		"Der Würfel löst 2× aus, im Stresstest 4×.",
		"löst 2× aus, im Stresstest 4×", Rarity.RARE, Color(0.4, 0.6, 1.0))

static func ball_lightning() -> Essence:
	return _make(BALL_LIGHTNING, "Kugelblitz",
		"Kritet ×2.",
		"kritet ×2", Rarity.RARE, Color(1.0, 1.0, 0.9))

static func solar_wind() -> Essence:
	return _make(SOLAR_WIND, "Sonnenwind",
		"+1 Auslösung je Essenz-Würfel, der in dieser Hand vor ihm gezählt wurde.",
		"+1 Auslösung je Essenz vor ihm", Rarity.EPIC, Color(1.0, 0.85, 0.45))

static func photon_gas() -> Essence:
	return _make(PHOTON_GAS, "Photonengas",
		"+5 Augen je Auslösung, die vor ihm zählte.",
		"+5 Augen je Auslösung davor", Rarity.RARE, Color(1.0, 1.0, 1.0))

static func ozone() -> Essence:
	return _make(OZONE, "Ozon",
		"Krit in der Höhe aller bisherigen Krits dieser Hand.",
		"Krit ×(1 + Krits davor)", Rarity.EPIC, Color(0.78, 0.65, 0.95))

static func plasma() -> Essence:
	return _make(PLASMA, "Plasma",
		"Pointer bekommen zwei Zündversuche statt einem.",
		"Pointer zündet zweimal so wahrscheinlich", Rarity.EPIC, Color(0.78, 0.72, 1.0))

## Quintessenz: der fünfte Stoff - sie borgt sich die Seelen aller anderen
## liegenden Würfel. Legendär und damit Unikat, also gibt es nie den Fall
## "Quintessenz kopiert Quintessenz".
static func quintessence() -> Essence:
	return _make(QUINTESSENCE, "Quintessenz",
		"Die Essenzen aller anderen liegenden Würfel wirken auch auf ihn.",
		"borgt jede fremde Seele", Rarity.LEGENDARY, Color(0.85, 0.9, 1.0))

## Polarlicht: der einzige Joker des Spiels - Legendär und damit Unikat, worauf
## sich die Erkennung verlässt (es kann NIE zwei Joker geben).
static func aurora() -> Essence:
	return _make(AURORA, "Polarlicht",
		"Seine Augenzahl gilt der Kombinationssuche als Joker - sie wird zur besten passenden Zahl. Gezählt werden weiter die aufgedruckten Augen.",
		"Joker für die Kombination", Rarity.LEGENDARY, Color(0.45, 1.0, 0.65))

## Vakuum: die einzige Essenz OHNE eigene Wirkung - ihr Wert liegt in der Schale.
## Ohne Innendruck trägt jede Seite zwei Runen, und die sind schwarz: das Vakuum
## saugt das Kernlicht nach innen, statt es zu entlassen.
static func vacuum() -> Essence:
	return _make(VACUUM, "Vakuum",
		"Jede Seite trägt bis zu zwei Runen.",
		"zwei Runen je Seite", Rarity.EPIC, Color(0.06, 0.05, 0.09))

static func radiation_pressure() -> Essence:
	return _make(RADIATION_PRESSURE, "Strahlungsdruck",
		"Alle seine Seiten wachsen dauerhaft +2.",
		"alle Seiten +2 je Auslösung", Rarity.RARE, Color(1.0, 0.8, 0.6))

static func cyanide() -> Essence:
	return _make(CYANIDE, "Zyanidgas",
		"+$2 je Gold-Seite, die er trägt.",
		"+$2 je eigener Gold-Seite", Rarity.RARE, Color(0.75, 0.9, 0.3))

static func xray() -> Essence:
	return _make(XRAY, "Röntgenlicht",
		"Bei jeder Aktivierung wird die Gegenseite mitgewertet.",
		"Gegenseite zählt mit", Rarity.RARE, Color(0.7, 0.95, 1.0))

static func varnish() -> Essence:
	return _make(VARNISH, "Firnis",
		"Seine Materialseiten zählen beim Werten als veredelt.",
		"Materialseiten zählen veredelt", Rarity.EPIC, Color(0.9, 0.7, 0.4))

static func phosphorescence() -> Essence:
	return _make(PHOSPHORESCENCE, "Phosphoreszenz",
		"Speichert die Basispunkte JEDER seiner Wertungen und legt den ganzen Speicher bei der nächsten obendrauf - geleert wird er nie.",
		"sammelt seine Basispunkte und zahlt sie erneut", Rarity.EPIC, Color(0.5, 1.0, 0.6))

static func detonating_gas() -> Essence:
	return _make(DETONATING_GAS, "Knallgas",
		"Bleibt er beim Rundenende ungezogen im Stapel liegen, zahlt JEDER Würfel hinter ihm +$1.",
		"+$1 je Würfel hinter ihm im Stapel", Rarity.RARE, Color(1.0, 0.62, 0.2))

static func cherenkov() -> Essence:
	return _make(CHERENKOV, "Tscherenkow-Licht",
		"Das blaue Glühen überschneller Teilchen: jede seiner Auslösungen kritet ×8 und verbrennt dafür 1 Energie.",
		"kritet ×8 für 1 Energie", Rarity.RARE, Color(0.2, 0.45, 1.0))

static func shooting_star() -> Essence:
	return _make(SHOOTING_STAR, "Sternschnuppe",
		"Einmal je Runde: ihre erste Zündung kritet ×4.",
		"einmal je Runde Krit ×4", Rarity.RARE, Color(1.0, 0.95, 0.75))

static func foxfire() -> Essence:
	return _make(FOXFIRE, "Fuchsfeuer",
		"+10 Augen je 2 Würfeln in der Ablage.",
		"+10 Augen je 2 Ablage-Würfeln", Rarity.RARE, Color(0.65, 0.85, 0.5))

static func black_light() -> Essence:
	return _make(BLACK_LIGHT, "Schwarzlicht",
		"+$3 je gewertetem Würfel, der kein Material trägt.",
		"+$3 je materiallosem Würfel", Rarity.RARE, Color(0.55, 0.3, 0.95))

static func volcanic_lightning() -> Essence:
	return _make(VOLCANIC_LIGHTNING, "Vulkanblitz",
		"Gewitter in der Aschewolke: jede seiner Auslösungen kritet ×(1 + Fumbles dieser Runde).",
		"kritet ×(1 + Fumbles der Runde)", Rarity.EPIC, Color(1.0, 0.5, 0.15))

static func optical_fiber() -> Essence:
	return _make(OPTICAL_FIBER, "Glasfaser",
		"Zündet einer seiner Pointer, feuert die Zielseite zweimal.",
		"Pointer-Ziel feuert 2×", Rarity.EPIC, Color(0.6, 1.0, 0.95))

static func light_pillar() -> Essence:
	return _make(LIGHT_PILLAR, "Lichtsäule",
		"Jeder andere gewertete Würfel mit gleicher Augenzahl löst +2× aus.",
		"Gleichzahlen lösen +2× aus", Rarity.EPIC, Color(0.92, 0.97, 1.0))

static func midnight_sun() -> Essence:
	return _make(MIDNIGHT_SUN, "Mitternachtssonne",
		"+1 Auslösung je bereits genommener Hand dieser Runde.",
		"+1 Auslösung je genommener Hand", Rarity.EPIC, Color(1.0, 0.8, 0.35))

## Heissweiss-violett wie die Ladung selbst - nie das Energie-Cyan.
static func spark_gap() -> Essence:
	return _make(SPARK_GAP, "Funkenstrecke",
		"Jede ihrer Auslösungen kritet ×(1 + Ladung).",
		"kritet ×(1 + Ladung)", Rarity.RARE, Color(0.88, 0.75, 1.0))

static func background_radiation() -> Essence:
	return _make(BACKGROUND_RADIATION, "Hintergrundstrahlung",
		"Wird er gewertet, wachsen alle Seiten aller liegenden Würfel dauerhaft +5.",
		"je Wertung: alle Seiten aller Würfel +5", Rarity.LEGENDARY, Color(0.75, 0.5, 0.4))

static func gamma_burst() -> Essence:
	return _secret(_make(GAMMA_BURST, "Gammablitz",
		"Seine erste Wertung jeder Runde kritet ×10.",
		"Erstwertung der Runde kritet ×10", Rarity.LEGENDARY, Color(0.9, 0.8, 1.0)))

static func antimatter() -> Essence:
	return _secret(_make(ANTIMATTER, "Antimaterie",
		"Seine Augen zählen NEGATIV in die Basispunkte - dafür kritet er mit seiner Augenzahl.",
		"Augen negativ, Krit ×Augen", Rarity.LEGENDARY, Color(0.45, 0.2, 0.6)))

## Kanonische Registrierung aller Essenzen.
static func all() -> Array[Essence]:
	return [
		helium(), neon(), argon(), krypton(), xenon(), nitrogen(), oxygen(),
		hydrogen(), sodium_vapor(), firedamp(), carbon_dioxide(), halogen(), acetylene(),
		arc_lamp(),
		mercury_vapor(), radon(), miasma(), st_elmos_fire(), ball_lightning(),
		solar_wind(), photon_gas(), ozone(), plasma(), vacuum(),
		radiation_pressure(), cyanide(), xray(), varnish(),
		phosphorescence(), detonating_gas(), aurora(), quintessence(), antimatter(),
		cherenkov(), shooting_star(), foxfire(), black_light(), volcanic_lightning(),
		optical_fiber(), light_pillar(), midnight_sun(), background_radiation(), gamma_burst(),
		spark_gap(),
	]

static func by_id(essence_id: String) -> Essence:
	for essence in all():
		if essence.id == essence_id:
			return essence
	return null

static func is_valid_id(essence_id: String) -> bool:
	return by_id(essence_id) != null

## Essenzen, die im normalen Handel liegen (der Schwarzmarkt führt den Rest).
static func tradeable() -> Array[Essence]:
	var pool: Array[Essence] = []
	for essence in all():
		if not essence.secret:
			pool.append(essence)
	return pool

## Kantenglühen zur id - Schwarz (kein Glühen) ohne Essenz.
static func glow_for(essence_id: String) -> Color:
	var essence := by_id(essence_id)
	return essence.glow if essence != null else Color.BLACK

## Kurz-Erklärzeile fürs Hover-Feld ("" ohne Essenz): «Name»: Wirkung.
static func hint(essence_id: String) -> String:
	var essence := by_id(essence_id)
	if essence == null:
		return ""
	return "%s: %s" % [essence.display_name, essence.short]

static func rarity_name(value: Rarity) -> String:
	match value:
		Rarity.COMMON:
			return "häufig"
		Rarity.RARE:
			return "selten"
		Rarity.EPIC:
			return "episch"
		Rarity.LEGENDARY:
			return "legendär"
	return "?"
