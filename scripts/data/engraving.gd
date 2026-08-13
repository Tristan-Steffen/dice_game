class_name Engraving
extends Resource
## Ein Gravur: die einzige Aufwertungs-Art im Spiel. Nur Anzeige-Infos; die
## Wirkung löst EtchingEffects/MaterialEffects/GameRun über die id auf. ids sind
## Konstanten, damit Tippfehler Compilerfehler sind. Gravuren kommen in drei
## Kategorien: Zahl (verändert Augen), Material (belegt eine Seite), Würfel
## (verdrahtet den ganzen Würfel). Kombinationen wertet die Systemkonsole auf.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

# categories: ZAHL verändert Augen (EtchingEffects), MATERIAL belegt eine Seite
# (id = Material-id), WÜRFEL wirkt auf den ganzen Würfel (bislang nur die
# Pointer - die Kanten sind als Ausbau-Slot gestrichen).
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

# --- Zahl-Gravur-ids (Single Source of Truth) ---
const NOTCH := "notch"
const OVERPRESSURE := "overpressure"
const POLISH := "polish"
const CHISEL := "chisel"
const GRINDSTONE := "grindstone"
const GROWTH := "growth"

## Dieselben ids in FESTER Reihenfolge: sie sind die sechs Seiten des Zahlen-
## Phantomwürfels (PhantomPress.ICONS liest hier).
const NUMBER_IDS := [NOTCH, OVERPRESSURE, POLISH, CHISEL, GRINDSTONE, GROWTH]

## Konvention: Textur-Dateiname = Gravur-id (chisel.jpg, ...).
const TEXTURE_DIR := "res://assets/textures/engravings/"

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: String = CATEGORY_NUMBER
@export var rarity: Rarity = Rarity.COMMON
@export var texture_path: String = ""

static func _make(engraving_id: String, name: String, desc: String, rarity: Rarity, category := CATEGORY_NUMBER) -> Engraving:
	var engraving := Engraving.new()
	engraving.id = engraving_id
	engraving.display_name = name
	engraving.description = desc
	engraving.rarity = rarity
	engraving.category = category
	engraving.texture_path = TEXTURE_DIR + engraving_id + ".jpg"
	return engraving

# --- Zahl-Gravuren: sechs Verben mit echter Leiter (siehe EtchingEffects). Die
# Beschreibung nennt die Stufe 1; die Reihe in der Presse klettert die Leiter hoch.

static func notch() -> Engraving:
	return _make(NOTCH, "Kerbe", "+1 auf eine gewählte Seite.", Rarity.COMMON)

static func overpressure() -> Engraving:
	return _make(OVERPRESSURE, "Überdruck", "+2 auf die höchste Seite.", Rarity.UNCOMMON)

static func polish() -> Engraving:
	return _make(POLISH, "Politur", "+1 auf alle Seiten.", Rarity.UNCOMMON)

static func chisel() -> Engraving:
	return _make(CHISEL, "Meißel", "Kopiere eine gewählte Seite auf eine andere.", Rarity.EPIC)

static func grindstone() -> Engraving:
	return _make(GRINDSTONE, "Schleifstein", "Verschiebe 2 Augen von einer Seite auf eine andere.", Rarity.COMMON)

static func growth() -> Engraving:
	return _make(GROWTH, "Aufholen", "+2 auf die niedrigste Seite.", Rarity.UNCOMMON)

## Was ein Beutestück auf SEINER Stufe tut ("" = diese Gravur hat keine Leiter,
## dann gilt ihre description). Die Zahlen kommen aus den Leitern in
## EtchingEffects - eine zweite Tabelle liefe davon weg. Bei Runen zählt die
## Reihe Anwendungen statt Stärke; Materialien skalieren gar nicht.
static func stufe_text(engraving_id: String, stufe: int) -> String:
	if is_rune_id(engraving_id):
		# Zuerst die WIRKUNG - eine Rune, die nur ihre Setzungen zählt, sagt nicht,
		# was sie tut. Die Menge zählt Anwendungen statt Stärke und ist ungedeckelt.
		var rune := Rune.by_id(rune_id_of(engraving_id))
		var effect := rune.description if rune != null else ""
		var runs := maxi(stufe, 1)
		if runs <= 1:
			return effect
		return "%s\nSetzt die Rune %d× - eine Seite je Setzung." % [effect, runs]
	var step := clampi(stufe, 1, EtchingEffects.MAX_STUFE)
	match engraving_id:
		NOTCH:
			return "Stufe %d: +%d auf eine gewählte Seite." \
				% [step, EtchingEffects.step_of(EtchingEffects.NOTCH_LADDER, step)]
		OVERPRESSURE:
			return "Stufe %d: +%d auf die höchste Seite." \
				% [step, EtchingEffects.step_of(EtchingEffects.OVERPRESSURE_LADDER, step)]
		POLISH:
			return "Stufe %d: +%d auf alle Seiten." \
				% [step, EtchingEffects.step_of(EtchingEffects.POLISH_LADDER, step)]
		GROWTH:
			return "Stufe %d: +%d auf die niedrigste Seite." \
				% [step, EtchingEffects.step_of(EtchingEffects.GROWTH_LADDER, step)]
		GRINDSTONE:
			return "Stufe %d: %s" % [step, _grindstone_line(step)]
		CHISEL:
			return "Stufe %d: %s" % [step, _chisel_line(step)]
	return ""

static func _grindstone_line(stufe: int) -> String:
	var moved := EtchingEffects.step_of(EtchingEffects.GRINDSTONE_LADDER, stufe)
	if moved == EtchingEffects.GRINDSTONE_ALL:
		return "verschiebt ALLE Augen über 1 von einer Seite auf eine andere."
	return "verschiebt %d Augen von einer Seite auf eine andere." % moved

static func _chisel_line(stufe: int) -> String:
	var targets := EtchingEffects.chisel_target_count(stufe)
	var line := "kopiert eine gewählte Seite auf eine andere."
	if targets >= 5:
		line = "kopiert eine gewählte Seite auf alle fünf anderen."
	elif targets > 1:
		line = "kopiert eine gewählte Seite auf %d andere." % targets
	if stufe >= EtchingEffects.CHISEL_RUNE_STUFE:
		return line + " Material und Rune wandern mit."
	if stufe >= EtchingEffects.CHISEL_MATERIAL_STUFE:
		return line + " Das Material wandert mit."
	return line

## Runen-Seltenheit: Streulicht ist Alltagsware, der Einbrand eine Stufe
## darüber, die übrigen vier sind die begehrten Zeichen - Abguss und Kehrseite
## sind beide stark, keines davon ist Alltagsware.
const RUNE_RARITY := {
	Rune.STRAY_LIGHT: Rarity.COMMON,
	Rune.BURN_IN: Rarity.UNCOMMON,
	Rune.AFTERGLOW: Rarity.RARE,
	Rune.SPARK_FLIGHT: Rarity.RARE,
	Rune.CAST: Rarity.RARE,
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
	var result: Array[Engraving] = [
		notch(), overpressure(), polish(), chisel(), grindstone(), growth(),
		pointer_engraving(), doping(),
	]
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
