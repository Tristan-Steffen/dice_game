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

static func carbon_dioxide() -> Essence:
	return _make(CARBON_DIOXIDE, "Kohlendioxid", "Löschgas",
		"1× je Runde verpufft ein Fumble, an dem dieser Würfel beteiligt ist, folgenlos.",
		"1× je Runde: Fumble verpufft", Rarity.COMMON, Color(0.9, 0.92, 0.94))

static func halogen() -> Essence:
	return _make(HALOGEN, "Halogen", "Werkstattlampe",
		"Dieser Würfel darf auch nach dem Rundenstart graviert werden - die Bench-Sperre greift bei ihm nicht.",
		"immer gravierbar", Rarity.COMMON, Color(1.0, 0.96, 0.88))

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
const WILL_O_WISP := "will_o_wisp"
const VACUUM := "vacuum"
const QUINTESSENCE := "quintessence"
const AURORA := "aurora"
const ANTIMATTER := "antimatter"

const NONE := ""

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## Kurzwirkung für Karten und Hover-Zeilen ("löst 2× aus").
@export var short: String = ""
## Der Beiname aus der Lore ("Doppelt belegt") - er trägt den Charakter.
@export var epithet: String = ""
@export var rarity: Rarity = Rarity.COMMON
## Kantenglühen des Würfels - essenzlose Würfel glühen nicht.
@export var glow: Color = Color.WHITE
## Nur im Schwarzmarkt zu haben (nie im normalen Shop, nie in Paketen).
@export var secret: bool = false
## Unikat: höchstens ein Exemplar im Pool, danach nicht mehr im Angebot.
@export var unique: bool = false

static func _make(essence_id: String, name: String, epithet_text: String, desc: String,
		short_text: String, rarity_value: Rarity, glow_color: Color) -> Essence:
	var essence := Essence.new()
	essence.id = essence_id
	essence.display_name = name
	essence.epithet = epithet_text
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
	return _make(HELIUM, "Helium", "Schwebt",
		"Liegt dieser Würfel in einer genommenen Kombination, wächst seine obere Seite dauerhaft +1.",
		"obere Seite wächst +1", Rarity.COMMON, Color(1.0, 0.72, 0.55))

static func neon() -> Essence:
	return _make(NEON, "Neon", "Reklame",
		"+$2, wenn dieser Würfel in der genommenen Kombination liegt.",
		"+$2 beim Werten", Rarity.COMMON, Color(1.0, 0.35, 0.15))

static func argon() -> Essence:
	return _make(ARGON, "Argon", "Doppelt belegt",
		"Der Würfel löst 2× aus: Augen und Effekte zählen zweimal.",
		"löst 2× aus", Rarity.COMMON, Color(0.62, 0.6, 0.95))

static func krypton() -> Essence:
	return _make(KRYPTON, "Krypton", "Verborgen",
		"Klauseln, die Würfel aussperren (Schieflage, Gleichgewicht), übersehen diesen Würfel.",
		"ignoriert Würfel-Sperren", Rarity.COMMON, Color(0.55, 0.95, 0.7))

static func xenon() -> Essence:
	return _make(XENON, "Xenon", "Fotoblitz",
		"Sein erstes Werten je Runde kritet ×2.",
		"1× je Runde: Krit ×2", Rarity.COMMON, Color(0.8, 0.9, 1.0))

static func nitrogen() -> Essence:
	return _make(NITROGEN, "Stickstoff", "Schutzatmosphäre",
		"Seine Seiten verlieren nie an Wert: Glas schrumpft nicht, Zerfall greift nicht.",
		"Seiten verlieren nie Wert", Rarity.COMMON, Color(0.88, 0.93, 0.98))

static func oxygen() -> Essence:
	return _make(OXYGEN, "Sauerstoff", "Facht an",
		"Der nächste Würfel der Zählreihenfolge löst +1× aus.",
		"nächster Würfel +1 Auslösung", Rarity.COMMON, Color(0.45, 0.75, 1.0))

static func hydrogen() -> Essence:
	return _make(HYDROGEN, "Wasserstoff", "Knallgas",
		"Seine Augen zählen doppelt - würfelt er eine 1, fumbelt die Hand.",
		"Augen ×2, bei einer 1 Fumble", Rarity.COMMON, Color(1.0, 0.45, 0.6))

static func sodium_vapor() -> Essence:
	return _make(SODIUM_VAPOR, "Natriumdampf", "Laternenschein",
		"+$1 je anderem Würfel der genommenen Kombination.",
		"+$1 je Mitwürfel", Rarity.COMMON, Color(1.0, 0.65, 0.25))

static func firedamp() -> Essence:
	return _make(FIREDAMP, "Grubengas", "Schlagwetter",
		"Zündet in seiner Hand ein Krit, gibt er +20 Basispunkte.",
		"+20 Basis nach einem Krit", Rarity.COMMON, Color(0.5, 0.65, 0.8))

# --- Phänomene --------------------------------------------------------------------

static func mercury_vapor() -> Essence:
	return _secret(_make(MERCURY_VAPOR, "Quecksilberdampf", "Reinform",
		"Der Würfel löst 3× aus - das verbannte Material, zurück als Dampf im Hinterzimmer.",
		"löst 3× aus", Rarity.RARE, Color(0.35, 0.7, 1.0)))

static func radon() -> Essence:
	return _secret(_make(RADON, "Radon", "Strahlt",
		"+2 Augen auf jeden anderen Würfel der Kombination. Zerfall: je Abrechnung verliert eine zufällige eigene Seite 1 Auge.",
		"+2 Augen auf Mitwürfel", Rarity.RARE, Color(0.5, 1.0, 0.3)))

static func miasma() -> Essence:
	return _secret(_make(MIASMA, "Miasma", "Fauler Handel",
		"Die Hälfte seiner Augen wird zu Geld: er zählt nur die aufgerundete Hälfte, die andere zahlt $1 je Auge.",
		"halbe Augen werden Geld", Rarity.EPIC, Color(0.4, 0.55, 0.35)))

static func st_elmos_fire() -> Essence:
	return _make(ST_ELMOS_FIRE, "Elmsfeuer", "Sturmzeichen",
		"Der Würfel löst 2× aus, im Stresstest 4× - er glüht am hellsten im Sturm.",
		"löst 2× aus, im Stresstest 4×", Rarity.RARE, Color(0.4, 0.6, 1.0))

static func ball_lightning() -> Essence:
	return _make(BALL_LIGHTNING, "Kugelblitz", "Einschlag",
		"Je Runde trifft es eine zufällige eigene Seite: wertet sie, kritet sie ×2.",
		"eine Seite je Runde kritet ×2", Rarity.RARE, Color(1.0, 1.0, 0.9))

static func solar_wind() -> Essence:
	return _make(SOLAR_WIND, "Sonnenwind", "Rückenwind",
		"+1 Auslösung je Essenz-Würfel, der in dieser Hand vor ihm gezählt wurde.",
		"+1 Auslösung je Essenz vor ihm", Rarity.EPIC, Color(1.0, 0.85, 0.45))

static func photon_gas() -> Essence:
	return _make(PHOTON_GAS, "Photonengas", "Lichtgeschwindigkeit",
		"Er zählt immer zuerst - das Werkzeug, um Krit-Reihenfolgen zu bauen.",
		"zählt zuerst", Rarity.RARE, Color(1.0, 1.0, 1.0))

static func ozone() -> Essence:
	return _make(OZONE, "Ozon", "Gewitterluft",
		"Sein Krit wächst mit jedem Krit, der in dieser Hand vor ihm zündete.",
		"Krit ×(1 + Krits davor)", Rarity.EPIC, Color(0.78, 0.65, 0.95))

static func will_o_wisp() -> Essence:
	return _make(WILL_O_WISP, "Irrlicht", "Kippen",
		"1× je Runde darf dieser Würfel nach dem Liegen auf eine Nachbarseite gekippt werden.",
		"1× je Runde kippbar", Rarity.EPIC, Color(0.62, 0.82, 1.0))

static func plasma() -> Essence:
	return _make(PLASMA, "Plasma", "Lichtbogen",
		"Seine Leiterbahn-Ketten laufen zwei Glieder weiter - und dürfen dabei im Kreis springen.",
		"Ketten +2 Glieder", Rarity.EPIC, Color(0.78, 0.72, 1.0))

## Quintessenz: der fünfte Stoff - sie borgt sich die Seelen aller anderen
## liegenden Würfel. Legendär und damit Unikat, also gibt es nie den Fall
## "Quintessenz kopiert Quintessenz".
static func quintessence() -> Essence:
	return _make(QUINTESSENCE, "Quintessenz", "Der fünfte Stoff",
		"Die Essenzen aller anderen liegenden Würfel wirken auch auf ihn - mit ihren guten wie schlechten Seiten.",
		"borgt jede fremde Seele", Rarity.LEGENDARY, Color(0.85, 0.9, 1.0))

## Polarlicht: der einzige Joker des Spiels - Legendär und damit Unikat, worauf
## sich die Erkennung verlässt (es kann NIE zwei Joker geben).
static func aurora() -> Essence:
	return _make(AURORA, "Polarlicht", "Schillert",
		"Seine Augenzahl gilt der Kombinationssuche als Joker - sie wird zur besten passenden Zahl. Gezählt werden weiter die aufgedruckten Augen.",
		"Joker für die Kombination", Rarity.LEGENDARY, Color(0.45, 1.0, 0.65))

## Vakuum: die einzige Essenz OHNE eigene Wirkung - ihr Wert liegt in der Schale.
## Ohne Innendruck trägt jede Seite zwei Rifts, und die sind schwarz: das Vakuum
## saugt das Kernlicht nach innen, statt es zu entlassen.
static func vacuum() -> Essence:
	return _make(VACUUM, "Vakuum", "Leere",
		"Keine eigene Wirkung - dafür trägt jede Seite bis zu zwei Rifts, und sie brechen schwarz auf.",
		"zwei Rifts je Seite", Rarity.EPIC, Color(0.06, 0.05, 0.09))

static func antimatter() -> Essence:
	return _secret(_make(ANTIMATTER, "Antimaterie", "Auslöschung",
		"Seine Augen zählen NEGATIV in die Basispunkte - dafür kritet er mit seiner Augenzahl.",
		"Augen negativ, Krit ×Augen", Rarity.LEGENDARY, Color(0.45, 0.2, 0.6)))

## Kanonische Registrierung aller Essenzen.
static func all() -> Array[Essence]:
	return [
		helium(), neon(), argon(), krypton(), xenon(), nitrogen(), oxygen(),
		hydrogen(), sodium_vapor(), firedamp(), carbon_dioxide(), halogen(),
		mercury_vapor(), radon(), miasma(), st_elmos_fire(), ball_lightning(),
		solar_wind(), photon_gas(), ozone(), will_o_wisp(), plasma(), vacuum(), aurora(), quintessence(), antimatter(),
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

## Kurz-Erklärzeile fürs Hover-Feld ("" ohne Essenz): «Name» – «Beiname»: Wirkung.
static func hint(essence_id: String) -> String:
	var essence := by_id(essence_id)
	if essence == null:
		return ""
	return "%s – %s: %s" % [essence.display_name, essence.epithet, essence.short]

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
