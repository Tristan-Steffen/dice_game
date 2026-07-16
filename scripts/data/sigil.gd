class_name Sigil
extends Resource
## Ein Sigill: die einzige Aufwertungs-Art im Spiel. Nur Anzeige-Infos; die
## Wirkung löst EtchingEffects/MaterialEffects/GameRun über die id auf. ids sind
## Konstanten, damit Tippfehler Compilerfehler sind. Sigille kommen in drei
## Kategorien: Zahl (verändert Augen), Material (belegt eine Seite), Würfel
## (veredelt die Kanten). Kombinationen wertet die Systemkonsole auf (Übertakten).

enum Rarity { COMMON, UNCOMMON, RARE }

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

# --- Zahl-Sigill-ids (Single Source of Truth) ---
const CHISEL := "chisel"
const TRANSPLANT := "transplant"
const GRINDSTONE := "grindstone"
const FINE_ENGRAVING := "fine_engraving"
const OVERCOUNT_ENGRAVING := "overcount_engraving"
const FILE_DOWN := "file_down"
const DOUBLE_NOTCH := "double_notch"
const AVERAGING := "averaging"
const CONNECT_UP := "connect_up"
const MIRROR := "mirror"
const IMPRINT := "imprint"
const STRAIGHTEN := "straighten"
const BLUEPRINT := "blueprint"

## Konvention: Textur-Dateiname = Sigill-id (chisel.jpg, ...).
const TEXTURE_DIR := "res://assets/textures/engravings/"

## Fläche (Breite × Höhe in Rasterzellen) je Sigill - die Fläche IST die
## Rarität (bestimmt die Ziehgewichtung).
const FOOTPRINT := {
	CHISEL: Vector2i(3, 2),
	TRANSPLANT: Vector2i(2, 2),
	GRINDSTONE: Vector2i(2, 1),
	FINE_ENGRAVING: Vector2i(3, 3),
	OVERCOUNT_ENGRAVING: Vector2i(3, 3),
	FILE_DOWN: Vector2i(1, 1),
	DOUBLE_NOTCH: Vector2i(1, 2),
	AVERAGING: Vector2i(2, 2),
	CONNECT_UP: Vector2i(2, 2),
	MIRROR: Vector2i(2, 2),
	IMPRINT: Vector2i(3, 2),
	STRAIGHTEN: Vector2i(2, 3),
	BLUEPRINT: Vector2i(3, 3),
	# Material-Sigille (id = Material-id)
	DieMaterial.GOLD: Vector2i(1, 1),
	DieMaterial.AMBER: Vector2i(2, 1),
	DieMaterial.GLASS: Vector2i(1, 2),
	DieMaterial.BONE: Vector2i(2, 2),
	DieMaterial.RUBY: Vector2i(2, 2),
	DieMaterial.MERCURY: Vector2i(3, 2),
	# Würfel-Sigille (Kanten) - stärker als die Seiten-Variante, größere Flächen
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

static func _make(sigil_id: String, name: String, desc: String, rarity: Rarity, category := CATEGORY_NUMBER) -> Sigil:
	var sigil := Sigil.new()
	sigil.id = sigil_id
	sigil.display_name = name
	sigil.description = desc
	sigil.rarity = rarity
	sigil.category = category
	var size: Vector2i = FOOTPRINT.get(sigil_id, Vector2i.ONE)
	sigil.width = size.x
	sigil.height = size.y
	sigil.texture_path = TEXTURE_DIR + sigil_id + ".jpg"
	return sigil

# --- Zahl-Sigille: verändern die Seiten EINES Würfels (siehe EtchingEffects) ---

static func chisel() -> Sigil:
	return _make(CHISEL, "Meißel", "Kopiere eine Seite eines Würfels auf eine andere Seite desselben Würfels.", Rarity.COMMON)

static func transplant() -> Sigil:
	return _make(TRANSPLANT, "Transplantat", "Hebe eine Seite auf den aktuell höchsten Wert des Würfels.", Rarity.COMMON)

static func grindstone() -> Sigil:
	return _make(GRINDSTONE, "Schleifstein", "−1 auf eine Seite, +1 auf eine andere Seite desselben Würfels.", Rarity.COMMON)

static func fine_engraving() -> Sigil:
	return _make(FINE_ENGRAVING, "Feingravur", "Setze eine Seite auf einen frei gewählten Wert 1–12.", Rarity.UNCOMMON)

static func overcount_engraving() -> Sigil:
	return _make(OVERCOUNT_ENGRAVING, "Überzahl-Gravur", "+1 auf eine Seite, darf über 6 hinausgehen.", Rarity.RARE)

static func file_down() -> Sigil:
	return _make(FILE_DOWN, "Feile", "−1 auf eine Seite (min. 1).", Rarity.COMMON)

static func double_notch() -> Sigil:
	return _make(DOUBLE_NOTCH, "Doppelkerbe", "+1 auf zwei verschiedene Seiten desselben Würfels (darf über 6 hinaus).", Rarity.COMMON)

static func averaging() -> Sigil:
	return _make(AVERAGING, "Mittelung", "Zwei Seiten eines Würfels werden auf ihren aufgerundeten Mittelwert gesetzt.", Rarity.UNCOMMON)

static func connect_up() -> Sigil:
	return _make(CONNECT_UP, "Anschluss", "Setze eine Seite auf den Wert einer anderen Seite desselben Würfels +1 (darf über 6 hinaus).", Rarity.UNCOMMON)

static func mirror() -> Sigil:
	return _make(MIRROR, "Spiegelung", "Invertiere alle Seiten eines Würfels ((Min+Max) − Wert).", Rarity.UNCOMMON)

static func imprint() -> Sigil:
	return _make(IMPRINT, "Abdruck", "Präge den Wert einer Seite auf die beiden niedrigsten anderen Seiten desselben Würfels.", Rarity.UNCOMMON)

static func straighten() -> Sigil:
	return _make(STRAIGHTEN, "Begradigung", "+1 auf alle ungeraden Seiten eines Würfels (darf über 6 hinaus).", Rarity.UNCOMMON)

static func blueprint() -> Sigil:
	return _make(BLUEPRINT, "Blaupause", "Setze alle Seiten des Würfels auf den Wert einer gewählten Seite.", Rarity.RARE)

# --- Material-Sigille: Name/Beschreibung kommen direkt vom DieMaterial ---

static func material_sigil(material: DieMaterial, rarity: Rarity) -> Sigil:
	return _make(material.id, material.display_name, material.description, rarity, CATEGORY_MATERIAL)

## Würfel-Sigill (Kanten): veredelt den GANZEN Würfel statt einer Seite.
static func edge_sigil(material: DieMaterial, rarity: Rarity) -> Sigil:
	return _make(EDGE_PREFIX + material.id, "%s-Kanten" % material.display_name, material.edge_description, rarity, CATEGORY_DICE)

const MATERIAL_RARITY := {
	DieMaterial.GOLD: Rarity.COMMON,
	DieMaterial.AMBER: Rarity.COMMON,
	DieMaterial.GLASS: Rarity.UNCOMMON,
	DieMaterial.BONE: Rarity.UNCOMMON,
	DieMaterial.RUBY: Rarity.UNCOMMON,
	DieMaterial.MERCURY: Rarity.RARE,
}

## Würfel-Sigille (Kanten): eine Stufe über der Seiten-Variante.
const EDGE_RARITY := {
	DieMaterial.GOLD: Rarity.UNCOMMON,
	DieMaterial.AMBER: Rarity.UNCOMMON,
	DieMaterial.GLASS: Rarity.RARE,
	DieMaterial.BONE: Rarity.RARE,
	DieMaterial.RUBY: Rarity.RARE,
	DieMaterial.MERCURY: Rarity.RARE,
}

## Kanonische Registrierung aller Sigill-Archetypen; Material-/Würfel-Sigille
## kommen aus DieMaterial.all().
static func all() -> Array[Sigil]:
	var result: Array[Sigil] = [
		chisel(), transplant(), grindstone(), fine_engraving(), overcount_engraving(),
		file_down(), double_notch(), averaging(), connect_up(), mirror(), imprint(), straighten(), blueprint(),
	]
	for material in DieMaterial.all():
		result.append(material_sigil(material, MATERIAL_RARITY.get(material.id, Rarity.UNCOMMON)))
	for material in DieMaterial.all():
		result.append(edge_sigil(material, EDGE_RARITY.get(material.id, Rarity.RARE)))
	return result

static func is_edge_id(sigil_id: String) -> bool:
	return sigil_id.begins_with(EDGE_PREFIX) and DieMaterial.is_valid_id(sigil_id.trim_prefix(EDGE_PREFIX))

## Kategorien, die sicher im Inventar landen - Shop und Ziehung zeigen nur diese.
const DRAFT_CATEGORIES := [CATEGORY_NUMBER, CATEGORY_MATERIAL, CATEGORY_DICE]

## Zieht count VERSCHIEDENE Sigill-Archetypen für die Lichtgravur-Ziehung: nur
## inventarfähige Kategorien, mindestens von Seltenheit floor, seltenheits-
## gewichtet ohne Zurücklegen. Zu kleiner Pool senkt die Untergrenze automatisch.
static func roll_draft(count: int, floor: Rarity) -> Array[Sigil]:
	var pool := _draft_pool(floor)
	while pool.size() < count and floor > Rarity.COMMON:
		floor = (floor - 1) as Rarity
		pool = _draft_pool(floor)
	return _weighted_distinct(pool, count)

## Zieht count VERSCHIEDENE Sigille einer Kategorie (Shop-Auslage), seltenheits-
## gewichtet ohne Zurücklegen.
static func roll_in_category(target_category: String, count: int) -> Array[Sigil]:
	var pool: Array[Sigil] = []
	for sigil in all():
		if sigil.category == target_category:
			pool.append(sigil)
	return _weighted_distinct(pool, count)

## Seltenheits-gewichtete Auswahl von count verschiedenen Sigillen aus pool.
static func _weighted_distinct(pool: Array[Sigil], count: int) -> Array[Sigil]:
	var working := pool.duplicate()
	var chosen: Array[Sigil] = []
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

static func _draft_pool(floor: Rarity) -> Array[Sigil]:
	var pool: Array[Sigil] = []
	for sigil in all():
		if DRAFT_CATEGORIES.has(sigil.category) and sigil.rarity >= floor:
			pool.append(sigil)
	return pool

## DieMaterial-id hinter diesem Sigill ("" bei Zahl-Sigillen).
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
	return "?"

## Anzeigename der Kategorie eines Sigills.
func category_name() -> String:
	return CATEGORY_NAMES.get(category, category)

## Ziehgewicht je Seltenheit (relativ).
static func _rarity_weight(value: Rarity) -> int:
	match value:
		Rarity.COMMON:
			return 8
		Rarity.UNCOMMON:
			return 3
		Rarity.RARE:
			return 1
	return 1
