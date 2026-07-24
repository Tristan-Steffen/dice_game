class_name Engraving
extends Resource
## Ein Gravur: die einzige Aufwertungs-Art im Spiel. Nur Anzeige-Infos; die
## Wirkung löst EtchingEffects/MaterialEffects/GameRun über die id auf. ids sind
## Konstanten, damit Tippfehler Compilerfehler sind. Gravuren kommen in drei
## Kategorien: Zahl (verändert Augen), Material (belegt eine Seite), Würfel
## (veredelt die Kanten). Kombinationen wertet die Systemkonsole auf (Übertakten).

enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

# categories: ZAHL verändert Augen (EtchingEffects), MATERIAL belegt eine Seite
# (id = Material-id), WÜRFEL die Kanten des ganzen Würfels (id = EDGE_PREFIX +
# Material-id).
const CATEGORY_NUMBER := "number"
const CATEGORY_MATERIAL := "material"
const CATEGORY_DICE := "dice"

const EDGE_PREFIX := "edge_"

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
	# Material-Gravuren (id = Material-id)
	DieMaterial.GOLD: Vector2i(1, 1),
	DieMaterial.AMBER: Vector2i(2, 1),
	DieMaterial.GLASS: Vector2i(1, 2),
	DieMaterial.BONE: Vector2i(2, 2),
	DieMaterial.RUBY: Vector2i(2, 2),
	DieMaterial.MERCURY: Vector2i(3, 2),
	# Würfel-Gravuren (Kanten) - stärker als die Seiten-Variante, größere Flächen
	EDGE_PREFIX + DieMaterial.GOLD: Vector2i(2, 2),
	EDGE_PREFIX + DieMaterial.AMBER: Vector2i(2, 2),
	EDGE_PREFIX + DieMaterial.GLASS: Vector2i(2, 2),
	EDGE_PREFIX + DieMaterial.BONE: Vector2i(3, 2),
	EDGE_PREFIX + DieMaterial.RUBY: Vector2i(3, 2),
	EDGE_PREFIX + DieMaterial.MERCURY: Vector2i(3, 3),
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

# --- Material-Gravuren: Name/Beschreibung kommen direkt vom DieMaterial ---

static func material_engraving(material: DieMaterial, rarity: Rarity) -> Engraving:
	return _make(material.id, material.display_name, material.description, rarity, CATEGORY_MATERIAL)

## Würfel-Gravur (Kanten): veredelt den GANZEN Würfel statt einer Seite.
static func edge_engraving(material: DieMaterial, rarity: Rarity) -> Engraving:
	return _make(EDGE_PREFIX + material.id, "%s-Kanten" % material.display_name, material.edge_description, rarity, CATEGORY_DICE)

const MATERIAL_RARITY := {
	DieMaterial.GOLD: Rarity.COMMON,
	DieMaterial.AMBER: Rarity.COMMON,
	DieMaterial.GLASS: Rarity.UNCOMMON,
	DieMaterial.BONE: Rarity.UNCOMMON,
	DieMaterial.RUBY: Rarity.UNCOMMON,
	DieMaterial.MERCURY: Rarity.RARE,
}

## Würfel-Gravuren (Kanten): eine Stufe über der Seiten-Variante.
const EDGE_RARITY := {
	DieMaterial.GOLD: Rarity.UNCOMMON,
	DieMaterial.AMBER: Rarity.UNCOMMON,
	DieMaterial.GLASS: Rarity.RARE,
	DieMaterial.BONE: Rarity.RARE,
	DieMaterial.RUBY: Rarity.RARE,
	DieMaterial.MERCURY: Rarity.RARE,
}

## Kanonische Registrierung aller Gravur-Archetypen; Material-/Würfel-Gravuren
## kommen aus DieMaterial.all().
static func all() -> Array[Engraving]:
	var result: Array[Engraving] = [
		chisel(), grindstone(), notch(), file_down(),
		averaging(), straighten(), polish(), sandpaper(), punch(), blueprint(),
	]
	for material in DieMaterial.all():
		result.append(material_engraving(material, MATERIAL_RARITY.get(material.id, Rarity.UNCOMMON)))
	for material in DieMaterial.all():
		result.append(edge_engraving(material, EDGE_RARITY.get(material.id, Rarity.RARE)))
	return result

static func is_edge_id(engraving_id: String) -> bool:
	return engraving_id.begins_with(EDGE_PREFIX) and DieMaterial.is_valid_id(engraving_id.trim_prefix(EDGE_PREFIX))

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

## DieMaterial-id hinter dieser Gravur ("" bei Zahl-Gravuren).
func material_id() -> String:
	match category:
		CATEGORY_MATERIAL:
			return id
		CATEGORY_DICE:
			return id.trim_prefix(EDGE_PREFIX)
	return ""

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
