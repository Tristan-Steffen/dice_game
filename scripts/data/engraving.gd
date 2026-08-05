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
# Leiterbahn - die Kanten sind als Ausbau-Slot gestrichen).
const CATEGORY_NUMBER := "number"
const CATEGORY_MATERIAL := "material"
const CATEGORY_DICE := "dice"

# --- Würfel-Gravur ohne Material: die Leiterbahn (Zeiger-Mechanik) ---
const POINTER := "pointer"

# --- Runen: Schablonen, die ein Zeichen in eine Seite ätzen. Die Gravur-id IST
# die Runen-id, wie bei den Material-Gravuren.
const RUNE_PREFIX := "rune_"

# --- Material-Gravur ohne eigenes Material: die Dotierung ---
const DOPING := "doping"

## Sonderposten: einmalige Spezial-Gravuren. Sie behalten ihre Kategorie (und
## damit Paket/Ziehung), liegen aber NICHT in deren Schublade, sondern im
## Sonderbestand, der letzten Schublade der Reihe - künftige Einmal-Effekte
## kommen dazu.
const SPECIAL_IDS := [POINTER, DOPING]

static func is_special_id(engraving_id: String) -> bool:
	return SPECIAL_IDS.has(engraving_id)

## Die drei käuflichen/ziehbaren Kategorien.
const CATEGORIES := [CATEGORY_NUMBER, CATEGORY_MATERIAL, CATEGORY_DICE]

## Deutscher Anzeigename je Kategorie.
const CATEGORY_NAMES := {
	CATEGORY_NUMBER: "Zahlen",
	CATEGORY_MATERIAL: "Materialien",
	CATEGORY_DICE: "Würfel",
}

# --- Zahl-Gravur-ids (Single Source of Truth) ---
const CHISEL := "chisel"
const GRINDSTONE := "grindstone"
const NOTCH := "notch"
const FILE_DOWN := "file_down"
const AVERAGING := "averaging"
const STRAIGHTEN := "straighten"
const POLISH := "polish"
const SANDPAPER := "sandpaper"
const PUNCH := "punch"
const BLUEPRINT := "blueprint"

## Dieselben ids als Liste - die Zwinge fragt danach, ohne dafür ein Engraving
## bauen zu müssen.
const NUMBER_IDS := [CHISEL, GRINDSTONE, NOTCH, FILE_DOWN, AVERAGING, STRAIGHTEN,
	POLISH, SANDPAPER, PUNCH, BLUEPRINT]

static func is_number_id(engraving_id: String) -> bool:
	return NUMBER_IDS.has(engraving_id)

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

# --- Zahl-Gravuren: verändern die Seiten EINES Würfels (siehe EtchingEffects) ---

static func chisel() -> Engraving:
	return _make(CHISEL, "Meißel", "Kopiere eine Seite eines Würfels auf eine andere Seite desselben Würfels.", Rarity.EPIC)

static func grindstone() -> Engraving:
	return _make(GRINDSTONE, "Schleifstein", "−1 auf eine Seite, +1 auf eine andere Seite desselben Würfels.", Rarity.COMMON)

static func notch() -> Engraving:
	return _make(NOTCH, "Kerbe", "+1 auf eine Seite.", Rarity.COMMON)

static func file_down() -> Engraving:
	return _make(FILE_DOWN, "Feile", "−1 auf eine Seite (min. 1).", Rarity.COMMON)

static func averaging() -> Engraving:
	return _make(AVERAGING, "Mittelung", "Zwei Seiten eines Würfels werden auf ihren aufgerundeten Mittelwert gesetzt.", Rarity.UNCOMMON)

static func straighten() -> Engraving:
	return _make(STRAIGHTEN, "Begradigung", "+1 auf alle ungeraden Seiten eines Würfels.", Rarity.UNCOMMON)

static func polish() -> Engraving:
	return _make(POLISH, "Politur", "+1 auf alle Seiten eines Würfels.", Rarity.UNCOMMON)

static func sandpaper() -> Engraving:
	return _make(SANDPAPER, "Schmirgel", "−1 auf alle Seiten eines Würfels (min. 1).", Rarity.UNCOMMON)

static func punch() -> Engraving:
	return _make(PUNCH, "Stanze", "+5 auf eine Seite.", Rarity.RARE)

static func blueprint() -> Engraving:
	return _make(BLUEPRINT, "Blaupause", "Setze alle Seiten des Würfels auf den Wert einer gewählten Seite.", Rarity.LEGENDARY)

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

## Leiterbahn: die Würfel-Gravur, die Seiten miteinander verdrahtet.
static func pointer_engraving() -> Engraving:
	return _make(POINTER, "Leiterbahn", "Ätze eine Leiterbahn von einer Seite über eine Kante: Die Zielseite löst mit 50 % Chance einmal voll mit aus (Augen, Material, Charms) - und von dort geht es weiter.", Rarity.EPIC, CATEGORY_DICE)

## Dotierung: die einzige Material-Gravur, die selbst kein Material belegt -
## sie dotiert das vorhandene Material EINER Seite.
static func doping() -> Engraving:
	return _make(DOPING, "Dotierung", "Dotiert das Material einer Seite.", Rarity.EPIC, CATEGORY_MATERIAL)

# --- Material-Gravuren: Name/Beschreibung kommen direkt vom DieMaterial ---

static func material_engraving(material: DieMaterial, rarity: Rarity) -> Engraving:
	return _make(material.id, material.display_name, material.description, rarity, CATEGORY_MATERIAL)

const MATERIAL_RARITY := {
	DieMaterial.GOLD: Rarity.COMMON,
	DieMaterial.AMBER: Rarity.COMMON,
	DieMaterial.GLASS: Rarity.UNCOMMON,
	DieMaterial.BONE: Rarity.UNCOMMON,
	DieMaterial.RUBY: Rarity.UNCOMMON,
}

## Kanonische Registrierung aller Gravur-Archetypen; die Material-Gravuren
## kommen aus DieMaterial.all().
static func all() -> Array[Engraving]:
	var result: Array[Engraving] = [
		chisel(), grindstone(), notch(), file_down(),
		averaging(), straighten(), polish(), sandpaper(), punch(), blueprint(),
		pointer_engraving(), doping(),
	]
	for material in DieMaterial.all():
		result.append(material_engraving(material, MATERIAL_RARITY.get(material.id, Rarity.UNCOMMON)))
	for rune in Rune.all():
		result.append(rune_engraving(rune, RUNE_RARITY.get(rune.id, Rarity.RARE)))
	return result

## Kategorien, die sicher im Inventar landen - Shop und Ziehung zeigen nur diese.
const DRAFT_CATEGORIES := [CATEGORY_NUMBER, CATEGORY_MATERIAL, CATEGORY_DICE]

## Zieht count VERSCHIEDENE Gravur-Archetypen für die Lichtgravur-Ziehung: nur
## inventarfähige Kategorien, seltenheitsgewichtet ohne Zurücklegen, floor
## verschiebt die Gewichte nach oben.
static func roll_draft(count: int, floor: Rarity) -> Array[Engraving]:
	return _weighted_distinct(_draft_pool(), count, floor)

## Zieht count VERSCHIEDENE Gravuren einer Kategorie (Paket-Inhalt), seltenheits-
## gewichtet ohne Zurücklegen.
static func roll_in_category(target_category: String, count: int, floor: Rarity = Rarity.COMMON) -> Array[Engraving]:
	return _weighted_distinct(_category_pool(target_category), count, floor)

static func _category_pool(target_category: String) -> Array[Engraving]:
	var pool: Array[Engraving] = []
	for engraving in all():
		if engraving.category == target_category:
			pool.append(engraving)
	return pool

## Dämpfung je Seltenheitsstufe unterhalb der Untergrenze.
const BELOW_FLOOR_DAMPING := 8.0

## Seltenheits-gewichtete Auswahl von count verschiedenen Gravuren aus pool.
## Die Untergrenze gewichtet, sie schließt nicht aus - sonst wäre ein häufiger
## Archetyp ab mittlerer Hub-Stufe überhaupt nicht mehr zu bekommen.
static func _weighted_distinct(pool: Array[Engraving], count: int, floor := Rarity.COMMON) -> Array[Engraving]:
	var working := pool.duplicate()
	var chosen: Array[Engraving] = []
	for i in mini(count, working.size()):
		var total := 0.0
		for c in working:
			total += _floored_weight(c.rarity, floor)
		var pick := randf() * total
		var hit := working.size() - 1  # randf() schließt 1.0 ein: letzter Eintrag faengt den Rand
		for j in working.size():
			pick -= _floored_weight(working[j].rarity, floor)
			if pick < 0.0:
				hit = j
				break
		chosen.append(working[hit])
		working.remove_at(hit)
	return chosen

static func _floored_weight(value: Rarity, floor: Rarity) -> float:
	var below := maxi(0, floor - value)
	return _rarity_weight(value) / pow(BELOW_FLOOR_DAMPING, below)

static func _draft_pool() -> Array[Engraving]:
	var pool: Array[Engraving] = []
	for engraving in all():
		if DRAFT_CATEGORIES.has(engraving.category):
			pool.append(engraving)
	return pool

## DieMaterial-id hinter dieser Gravur ("" bei Zahl-Gravuren und Sonderposten).
## Spezial-Gravuren belegen nie ein Material - sie behalten nur die Kategorie.
func material_id() -> String:
	if is_special_id(id):
		return ""
	return id if category == CATEGORY_MATERIAL else ""

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

## Anzeigename der Kategorie einer Gravur.
func category_name() -> String:
	return CATEGORY_NAMES.get(category, category)

## Ziehgewicht je Seltenheit (relativ). Die Leiter ist nach unten gespreizt,
## damit die legendäre Stufe bei Gewicht 1 Platz hat.
static func _rarity_weight(value: Rarity) -> int:
	match value:
		Rarity.COMMON:
			return 64
		Rarity.UNCOMMON:
			return 24
		Rarity.RARE:
			return 8
		Rarity.EPIC:
			return 4
		Rarity.LEGENDARY:
			return 1
	return 1
