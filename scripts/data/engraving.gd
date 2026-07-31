class_name Engraving
extends Resource
## Ein Gravur: die einzige Aufwertungs-Art im Spiel. Nur Anzeige-Infos; die
## Wirkung löst EtchingEffects/MaterialEffects/GameRun über die id auf. ids sind
## Konstanten, damit Tippfehler Compilerfehler sind. Gravuren kommen in drei
## Kategorien: Zahl (verändert Augen), Material (belegt eine Seite), Würfel
## (verdrahtet den ganzen Würfel). Kombinationen wertet die Systemkonsole auf.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

# categories: ZAHL verändert Augen (EtchingEffects), MATERIAL belegt eine Seite
# (id = Material-id), WÜRFEL wirkt auf den ganzen Würfel (bislang nur die
# Leiterbahn - die Kanten sind als Ausbau-Slot gestrichen).
const CATEGORY_NUMBER := "number"
const CATEGORY_MATERIAL := "material"
const CATEGORY_DICE := "dice"

# --- Würfel-Gravur ohne Material: die Leiterbahn (Zeiger-Mechanik) ---
const POINTER := "pointer"

# --- Bruchmuster: Schablonen, die eine Seite kontrolliert aufreißen. Die
# Gravur-id IST die Rift-id, wie bei den Material-Gravuren.
const BREAK_PREFIX := "break_"

# --- Material-Gravur ohne eigenes Material: die Dotierung (+1 Sättigungsstufe) ---
const DOPING := "doping"

## Sonderposten: einmalige Spezial-Gravuren. Sie behalten ihre Kategorie (und
## damit Paket/Ziehung), liegen aber NICHT in deren Schublade, sondern im
## Sonderbestand rechts der Werkbank - künftige Einmal-Effekte kommen dazu.
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

## Konvention: Textur-Dateiname = Gravur-id (chisel.jpg, ...).
const TEXTURE_DIR := "res://assets/textures/engravings/"

## Fläche (Breite × Höhe in Rasterzellen) je Gravur - die Fläche IST die
## Rarität (bestimmt die Ziehgewichtung).
const FOOTPRINT := {
	CHISEL: Vector2i(3, 2),
	GRINDSTONE: Vector2i(2, 1),
	NOTCH: Vector2i(1, 1),
	FILE_DOWN: Vector2i(1, 1),
	AVERAGING: Vector2i(2, 2),
	STRAIGHTEN: Vector2i(2, 3),
	POLISH: Vector2i(2, 2),
	SANDPAPER: Vector2i(2, 2),
	PUNCH: Vector2i(3, 2),
	BLUEPRINT: Vector2i(3, 3),
	POINTER: Vector2i(3, 3),
	DOPING: Vector2i(3, 3),
	# Bruchmuster (Würfel-Kategorie) - die Fläche IST die Seltenheit
	BREAK_PREFIX + Rift.STRAY_LIGHT: Vector2i(1, 1),
	BREAK_PREFIX + Rift.BURN_IN: Vector2i(2, 1),
	BREAK_PREFIX + Rift.AFTERGLOW: Vector2i(2, 2),
	BREAK_PREFIX + Rift.SPARK_FLIGHT: Vector2i(2, 2),
	# Material-Gravuren (id = Material-id)
	DieMaterial.GOLD: Vector2i(1, 1),
	DieMaterial.AMBER: Vector2i(2, 1),
	DieMaterial.GLASS: Vector2i(1, 2),
	DieMaterial.BONE: Vector2i(2, 2),
	DieMaterial.RUBY: Vector2i(2, 2),
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: String = CATEGORY_NUMBER
@export var rarity: Rarity = Rarity.COMMON
@export var width: int = 1  # Fläche in Rasterzellen (siehe FOOTPRINT)
@export var height: int = 1
@export var texture_path: String = ""

static func _make(engraving_id: String, name: String, desc: String, rarity: Rarity, category := CATEGORY_NUMBER) -> Engraving:
	var engraving := Engraving.new()
	engraving.id = engraving_id
	engraving.display_name = name
	engraving.description = desc
	engraving.rarity = rarity
	engraving.category = category
	var size: Vector2i = FOOTPRINT.get(engraving_id, Vector2i.ONE)
	engraving.width = size.x
	engraving.height = size.y
	engraving.texture_path = TEXTURE_DIR + engraving_id + ".jpg"
	return engraving

# --- Zahl-Gravuren: verändern die Seiten EINES Würfels (siehe EtchingEffects) ---

static func chisel() -> Engraving:
	return _make(CHISEL, "Meißel", "Kopiere eine Seite eines Würfels auf eine andere Seite desselben Würfels.", Rarity.RARE)

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
	return _make(BLUEPRINT, "Blaupause", "Setze alle Seiten des Würfels auf den Wert einer gewählten Seite.", Rarity.EPIC)

## Bruchmuster-Seltenheit: Streulicht ist Alltagsware, der Einbrand eine Stufe
## darüber, Nachglühen und Funkenflug sind die begehrten Risse.
const RIFT_RARITY := {
	Rift.STRAY_LIGHT: Rarity.COMMON,
	Rift.BURN_IN: Rarity.UNCOMMON,
	Rift.AFTERGLOW: Rarity.RARE,
	Rift.SPARK_FLIGHT: Rarity.RARE,
}

## Bruchmuster: reißt EINE Seite entlang seines Musters auf und versiegelt sie
## mit getönter Glasur. Name und Beschreibung kommen direkt vom Rift.
static func rift_engraving(rift: Rift, rarity: Rarity) -> Engraving:
	return _make(BREAK_PREFIX + rift.id, "Bruchmuster: %s" % rift.display_name,
		rift.description, rarity, CATEGORY_DICE)

## Rift-id hinter einem Bruchmuster ("" bei allen anderen Gravuren).
static func rift_id_of(engraving_id: String) -> String:
	if not engraving_id.begins_with(BREAK_PREFIX):
		return ""
	var rift_id := engraving_id.trim_prefix(BREAK_PREFIX)
	return rift_id if Rift.is_valid_id(rift_id) else ""

static func is_rift_id(engraving_id: String) -> bool:
	return rift_id_of(engraving_id) != ""

## Leiterbahn: die Würfel-Gravur, die Seiten miteinander verdrahtet.
static func pointer_engraving() -> Engraving:
	return _make(POINTER, "Leiterbahn", "Ätze eine Leiterbahn von einer Seite über eine Kante: Nach dem Würfel löst die Zielseite einmal voll mit aus (Augen, Material, Charms).", Rarity.EPIC, CATEGORY_DICE)

## Dotierung: die einzige Material-Gravur, die selbst kein Material belegt -
## sie hebt das vorhandene Material EINER Seite um eine Sättigungsstufe.
static func doping() -> Engraving:
	return _make(DOPING, "Dotierung", "Hebe das Material einer Seite um eine Stufe (bis III): es wirkt stärker und anders.", Rarity.EPIC, CATEGORY_MATERIAL)

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
	for rift in Rift.all():
		result.append(rift_engraving(rift, RIFT_RARITY.get(rift.id, Rarity.RARE)))
	return result

## Kategorien, die sicher im Inventar landen - Shop und Ziehung zeigen nur diese.
const DRAFT_CATEGORIES := [CATEGORY_NUMBER, CATEGORY_MATERIAL, CATEGORY_DICE]

## Zieht count VERSCHIEDENE Gravur-Archetypen für die Lichtgravur-Ziehung: nur
## inventarfähige Kategorien, mindestens von Seltenheit floor, seltenheits-
## gewichtet ohne Zurücklegen. Zu kleiner Pool senkt die Untergrenze automatisch.
static func roll_draft(count: int, floor: Rarity) -> Array[Engraving]:
	var pool := _draft_pool(floor)
	while pool.size() < count and floor > Rarity.COMMON:
		floor = (floor - 1) as Rarity
		pool = _draft_pool(floor)
	return _weighted_distinct(pool, count)

## Zieht count VERSCHIEDENE Gravuren einer Kategorie (Paket-Inhalt), seltenheits-
## gewichtet ohne Zurücklegen. Ein zu kleiner Pool senkt floor automatisch.
static func roll_in_category(target_category: String, count: int, floor: Rarity = Rarity.COMMON) -> Array[Engraving]:
	var pool := _category_pool(target_category, floor)
	while pool.size() < count and floor > Rarity.COMMON:
		floor = (floor - 1) as Rarity
		pool = _category_pool(target_category, floor)
	return _weighted_distinct(pool, count)

static func _category_pool(target_category: String, floor: Rarity) -> Array[Engraving]:
	var pool: Array[Engraving] = []
	for engraving in all():
		if engraving.category == target_category and engraving.rarity >= floor:
			pool.append(engraving)
	return pool

## Seltenheits-gewichtete Auswahl von count verschiedenen Gravuren aus pool.
static func _weighted_distinct(pool: Array[Engraving], count: int) -> Array[Engraving]:
	var working := pool.duplicate()
	var chosen: Array[Engraving] = []
	for i in mini(count, working.size()):
		var total := 0
		for c in working:
			total += _rarity_weight(c.rarity)
		var pick := randi() % total
		for j in working.size():
			pick -= _rarity_weight(working[j].rarity)
			if pick < 0:
				chosen.append(working[j])
				working.remove_at(j)
				break
	return chosen

static func _draft_pool(floor: Rarity) -> Array[Engraving]:
	var pool: Array[Engraving] = []
	for engraving in all():
		if DRAFT_CATEGORIES.has(engraving.category) and engraving.rarity >= floor:
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
	return "?"

## Anzeigename der Kategorie einer Gravur.
func category_name() -> String:
	return CATEGORY_NAMES.get(category, category)

## Ziehgewicht je Seltenheit (relativ).
static func _rarity_weight(value: Rarity) -> int:
	match value:
		Rarity.COMMON:
			return 16
		Rarity.UNCOMMON:
			return 6
		Rarity.RARE:
			return 2
		Rarity.EPIC:
			return 1
	return 1
