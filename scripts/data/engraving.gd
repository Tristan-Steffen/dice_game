class_name Engraving
extends Resource
## Ein Gravur: die einzige Aufwertungs-Art im Spiel. Nur Anzeige-Infos; die
## Wirkung löst EtchingEffects/MaterialEffects/GameRun über die id auf. ids sind
## Konstanten, damit Tippfehler Compilerfehler sind. Gravuren kommen in drei
## Kategorien: Zahl (verändert Augen), Material (belegt eine Seite), Würfel
## (verdrahtet den ganzen Würfel). Kombinationen wertet die Systemkonsole auf.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

# categories: ZAHL hebt Augen (nur noch als nackte Netz-Zelle, ohne Archetyp),
# MATERIAL belegt eine Seite (id = Material-id), WÜRFEL wirkt auf den ganzen
# Würfel (Pointer, Runen - die Kanten sind als Ausbau-Slot gestrichen).
const CATEGORY_NUMBER := "number"
const CATEGORY_MATERIAL := "material"
const CATEGORY_DICE := "dice"

# --- Würfel-Gravur ohne Material: der Pointer (Zeiger-Mechanik) ---
const POINTER := "pointer"

# --- Material-Gravur ohne eigenes Material: die Veredelung ---
const DOPING := "doping"

# --- Runen: Schablonen, die ein Zeichen in eine Seite ätzen. Die Gravur-id IST
# die Runen-id, wie bei den Material-Gravuren.
const RUNE_PREFIX := "rune_"

## Sonderposten: Spezial-Gravuren, die auf keinem Ikonensatz liegen. Sie behalten
## ihre Kategorie (und damit Paketsorte), liegen aber NICHT im normalen Regal,
## sondern im Sonderbestand: gekauft im Hinterzimmer, versiegelt als Fixinhalt,
## gepresst wie alles andere.
const SPECIAL_IDS := [POINTER, DOPING]

static func is_special_id(engraving_id: String) -> bool:
	return SPECIAL_IDS.has(engraving_id)

## Die drei käuflichen/ziehbaren Kategorien.
const CATEGORIES := [CATEGORY_NUMBER, CATEGORY_MATERIAL, CATEGORY_DICE]

## Es gibt KEINE Zahl-Gravuren mehr: Kerbe, Überdruck, Politur, Meißel,
## Schleifstein und Aufholen sind mit der Serienschaltung gestorben - eine
## Zahl-Zelle im Prägenetz ist ein nackter Bonus, kein Verb mit Leiter. Die
## Kategorie bleibt als Regal- und Paketsorte bestehen.

## Konvention: Textur-Dateiname = Gravur-id (gold.jpg, ...).
const TEXTURE_DIR := "res://assets/textures/engravings/"

## Seltenheit -> Akzentfarbe (das Charm.RARITY_COLORS-Muster; Erbe des
## gestorbenen Lichtsaum-Siegels).
const RARITY_COLORS := {
	Rarity.COMMON: Color(0.78, 0.81, 0.88, 0.55),
	Rarity.UNCOMMON: Color("#8be9fd"),
	Rarity.RARE: Color("#ffd319"),
	Rarity.EPIC: Color("#bd93f9"),
	Rarity.LEGENDARY: Color("#ff79c6"),
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: String = CATEGORY_NUMBER
@export var rarity: Rarity = Rarity.COMMON
@export var texture_path: String = ""

func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS[Rarity.COMMON])

static func _make(engraving_id: String, name: String, desc: String, rarity: Rarity, category := CATEGORY_NUMBER) -> Engraving:
	var engraving := Engraving.new()
	engraving.id = engraving_id
	engraving.display_name = name
	engraving.description = desc
	engraving.rarity = rarity
	engraving.category = category
	engraving.texture_path = TEXTURE_DIR + engraving_id + ".jpg"
	return engraving


## Runen-Seltenheit: Streulicht ist Alltagsware, der Einbrand eine Stufe
## darüber, die übrigen drei sind die begehrten Zeichen - keines davon ist
## Alltagsware.
const RUNE_RARITY := {
	Rune.STRAY_LIGHT: Rarity.COMMON,
	Rune.BURN_IN: Rarity.UNCOMMON,
	Rune.AFTERGLOW: Rarity.RARE,
	Rune.SPARK_FLIGHT: Rarity.RARE,
	Rune.REVERSE: Rarity.RARE,
}

## Rune: ätzt EIN Zeichen in eine Seite, das ihren Kernlicht-Funken anzapft.
## Name und Beschreibung kommen direkt von der Rune.
static func rune_engraving(rune: Rune, rarity: Rarity) -> Engraving:
	return _make(RUNE_PREFIX + rune.id, "Rune: %s" % rune.display_name,
		rune.description, rarity, CATEGORY_DICE)

## Runen-id hinter einer Runen-Gravur ("" bei allen anderen Gravuren).
static func rune_id_of(engraving_id: String) -> String:
	if not engraving_id.begins_with(RUNE_PREFIX):
		return ""
	var rune_id := engraving_id.trim_prefix(RUNE_PREFIX)
	return rune_id if Rune.is_valid_id(rune_id) else ""

static func is_rune_id(engraving_id: String) -> bool:
	return rune_id_of(engraving_id) != ""

## Pointer: die Würfel-Gravur, die Seiten miteinander verdrahtet.
static func pointer_engraving() -> Engraving:
	return _make(POINTER, "Pointer", "Ätze einen Pointer von einer Seite über eine Kante: Die Zielseite löst mit 50 % Chance einmal voll mit aus (Augen, Material, Charms) - und von dort geht es weiter.", Rarity.EPIC, CATEGORY_DICE)

## Veredelung: die einzige Material-Gravur, die selbst kein Material belegt - sie
## sättigt eins, das schon auf der Seite liegt.
static func doping() -> Engraving:
	return _make(DOPING, "Veredelung", "Veredelt das Material einer gewählten Seite: es wirkt fortan in seiner starken Form. Nackte und schon veredelte Seiten sind kein Ziel.", Rarity.EPIC, CATEGORY_MATERIAL)

# --- Material-Gravuren: Name/Beschreibung kommen direkt vom DieMaterial ---

static func material_engraving(material: DieMaterial, rarity: Rarity) -> Engraving:
	return _make(material.id, material.display_name, material.description, rarity, CATEGORY_MATERIAL)

const MATERIAL_RARITY := {
	DieMaterial.GOLD: Rarity.COMMON,
	DieMaterial.AMBER: Rarity.COMMON,
	DieMaterial.GLASS: Rarity.UNCOMMON,
	DieMaterial.BONE: Rarity.UNCOMMON,
	DieMaterial.RUBY: Rarity.UNCOMMON,
	DieMaterial.COPPER: Rarity.UNCOMMON,
}

## Kanonische Registrierung aller Gravur-Archetypen; die Material-Gravuren
## kommen aus DieMaterial.all().
static func all() -> Array[Engraving]:
	var result: Array[Engraving] = [pointer_engraving(), doping()]
	for material in DieMaterial.all():
		result.append(material_engraving(material, MATERIAL_RARITY.get(material.id, Rarity.UNCOMMON)))
	for rune in Rune.all():
		result.append(rune_engraving(rune, RUNE_RARITY.get(rune.id, Rarity.RARE)))
	return result

## Archetyp zur id (null bei unbekannter id).
static func by_id(engraving_id: String) -> Engraving:
	for engraving in all():
		if engraving.id == engraving_id:
			return engraving
	return null

## DieMaterial-id hinter dieser Gravur ("" bei Zahl-Gravuren und Sonderposten).
## Spezial-Gravuren belegen nie ein Material - sie behalten nur die Kategorie.
func material_id() -> String:
	if is_special_id(id):
		return ""
	return id if category == CATEGORY_MATERIAL else ""

## Ziehgewicht je Seltenheit - EINE Quelle für jeden Wurf, der eine Gravur zieht.
## Dieselbe Halbierungs-Kurve wie bei den Charms (Charm.RARITY_WEIGHTS), um EPIC
## nach unten fortgesetzt: häufig fällt oft, episch fast nie.
const RARITY_WEIGHTS := {
	Rarity.COMMON: 1.0,
	Rarity.UNCOMMON: 0.55,
	Rarity.RARE: 0.25,
	Rarity.EPIC: 0.12,
	Rarity.LEGENDARY: 0.05,
}

static func rarity_weight(value: Rarity) -> float:
	return float(RARITY_WEIGHTS.get(value, 1.0))

## Ziehgewicht einer Gravur an ihrer id (unbekannt = häufig).
static func weight_of(engraving_id: String) -> float:
	var archetype := by_id(engraving_id)
	return rarity_weight(archetype.rarity) if archetype != null else 1.0

static func rarity_name(value: Rarity) -> String:
	match value:
		Rarity.COMMON:
			return "häufig"
		Rarity.UNCOMMON:
			return "ungewöhnlich"
		Rarity.RARE:
			return "selten"
		Rarity.EPIC:
			return "episch"
		Rarity.LEGENDARY:
			return "legendär"
	return "?"
