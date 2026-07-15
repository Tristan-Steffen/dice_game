class_name Coupon
extends Resource
## Ein verbrauchbarer Coupon (kommt über Coupon-Bögen aus dem Shop). Nur
## Anzeige-Infos; die Wirkung löst EtchingEffects/MaterialEffects/GameRun über
## die id auf. ids sind Konstanten, damit Tippfehler Compilerfehler sind.

enum Rarity { COMMON, UNCOMMON, RARE }

# kinds: Ätzungen verändern Augen (EtchingEffects), Materialien belegen eine
# Seite (id = Material-id), Kanten-Materialien den ganzen Würfel
# (id = EDGE_PREFIX + Material-id), Menü-Gerichte werten eine Kombination auf
# (id = MEAL_PREFIX + Kategorie-Key).
const KIND_ETCHING := "etching"
const KIND_MATERIAL := "material"
const KIND_EDGE := "edge"
const KIND_MEAL := "meal"

const EDGE_PREFIX := "edge_"
const MEAL_PREFIX := "meal_"

# --- Coupon-ids (Single Source of Truth) ---
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

## Konvention: Textur-Dateiname = Coupon-id (chisel.jpg, ...).
const TEXTURE_DIR := "res://assets/textures/engravings/"

## Fläche (Breite × Höhe in Rasterzellen) je Coupon - die Fläche IST die
## Rarität: bestimmt Platzbedarf auf dem Bogen und das Textur-Seitenverhältnis.
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
	# Material-Coupons (id = Material-id)
	DieMaterial.GOLD: Vector2i(1, 1),
	DieMaterial.AMBER: Vector2i(2, 1),
	DieMaterial.GLASS: Vector2i(1, 2),
	DieMaterial.BONE: Vector2i(2, 2),
	DieMaterial.RUBY: Vector2i(2, 2),
	DieMaterial.MERCURY: Vector2i(3, 2),
	# Kanten-Coupons - stärker als die Seiten-Variante, darum größere Flächen
	EDGE_PREFIX + DieMaterial.GOLD: Vector2i(2, 2),
	EDGE_PREFIX + DieMaterial.AMBER: Vector2i(2, 2),
	EDGE_PREFIX + DieMaterial.GLASS: Vector2i(2, 2),
	EDGE_PREFIX + DieMaterial.BONE: Vector2i(3, 2),
	EDGE_PREFIX + DieMaterial.RUBY: Vector2i(3, 2),
	EDGE_PREFIX + DieMaterial.MERCURY: Vector2i(3, 3),
	# Menü-Coupons - je stärker die Kombination, desto größer das Gericht
	MEAL_PREFIX + DiceScoring.ONE_KIND: Vector2i(1, 1),
	MEAL_PREFIX + DiceScoring.TWO_KIND: Vector2i(1, 1),
	MEAL_PREFIX + DiceScoring.TWO_PAIR: Vector2i(2, 1),
	MEAL_PREFIX + DiceScoring.THREE_KIND: Vector2i(2, 1),
	MEAL_PREFIX + DiceScoring.SMALL_STRAIGHT: Vector2i(2, 2),
	MEAL_PREFIX + DiceScoring.FOUR_KIND: Vector2i(2, 2),
	MEAL_PREFIX + DiceScoring.FULL_HOUSE: Vector2i(2, 2),
	MEAL_PREFIX + DiceScoring.THREE_PAIRS: Vector2i(2, 2),
	MEAL_PREFIX + DiceScoring.DOUBLE_THREE_KIND: Vector2i(3, 2),
	MEAL_PREFIX + DiceScoring.FOUR_KIND_AND_PAIR: Vector2i(3, 2),
	MEAL_PREFIX + DiceScoring.LARGE_STRAIGHT: Vector2i(3, 2),
	MEAL_PREFIX + DiceScoring.FIVE_KIND: Vector2i(3, 3),
	MEAL_PREFIX + DiceScoring.SIX_KIND: Vector2i(3, 3),
}

## Gericht je Kombination - Anzeigename des Menü-Coupons.
const MEAL_NAMES := {
	DiceScoring.ONE_KIND: "Tagessuppe",
	DiceScoring.TWO_KIND: "Zwei Spiegeleier",
	DiceScoring.TWO_PAIR: "Doppelter Espresso",
	DiceScoring.THREE_KIND: "Drei im Weggla",
	DiceScoring.SMALL_STRAIGHT: "Kleine Street-Food-Platte",
	DiceScoring.FOUR_KIND: "Vier-Käse-Pizza",
	DiceScoring.FULL_HOUSE: "Full-House-Burger",
	DiceScoring.THREE_PAIRS: "Tapas-Trio",
	DiceScoring.DOUBLE_THREE_KIND: "Doppeltes Tagesmenü",
	DiceScoring.FOUR_KIND_AND_PAIR: "Vier-Käse-Pizza mit Beilage",
	DiceScoring.LARGE_STRAIGHT: "Große Street-Food-Platte",
	DiceScoring.FIVE_KIND: "Fünf-Gänge-Menü",
	DiceScoring.SIX_KIND: "Spezialität des Hauses",
}

## Seltenheit je Menü-Coupon: folgt der Stärke der Kombination.
const MEAL_RARITY := {
	DiceScoring.ONE_KIND: Rarity.COMMON,
	DiceScoring.TWO_KIND: Rarity.COMMON,
	DiceScoring.TWO_PAIR: Rarity.COMMON,
	DiceScoring.THREE_KIND: Rarity.COMMON,
	DiceScoring.SMALL_STRAIGHT: Rarity.UNCOMMON,
	DiceScoring.FOUR_KIND: Rarity.UNCOMMON,
	DiceScoring.FULL_HOUSE: Rarity.UNCOMMON,
	DiceScoring.THREE_PAIRS: Rarity.UNCOMMON,
	DiceScoring.DOUBLE_THREE_KIND: Rarity.RARE,
	DiceScoring.FOUR_KIND_AND_PAIR: Rarity.RARE,
	DiceScoring.LARGE_STRAIGHT: Rarity.RARE,
	DiceScoring.FIVE_KIND: Rarity.RARE,
	DiceScoring.SIX_KIND: Rarity.RARE,
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: String = KIND_ETCHING
@export var rarity: Rarity = Rarity.COMMON
@export var width: int = 1  # Fläche in Rasterzellen (siehe FOOTPRINT)
@export var height: int = 1
@export var texture_path: String = ""

static func _make(coupon_id: String, name: String, desc: String, rarity: Rarity, kind := KIND_ETCHING) -> Coupon:
	var coupon := Coupon.new()
	coupon.id = coupon_id
	coupon.display_name = name
	coupon.description = desc
	coupon.rarity = rarity
	coupon.kind = kind
	var size: Vector2i = FOOTPRINT.get(coupon_id, Vector2i.ONE)
	coupon.width = size.x
	coupon.height = size.y
	coupon.texture_path = TEXTURE_DIR + coupon_id + ".jpg"
	return coupon

# --- Ätzungen: verändern die Seiten EINES Würfels (siehe EtchingEffects) ---

static func chisel() -> Coupon:
	return _make(CHISEL, "Meißel", "Kopiere eine Seite eines Würfels auf eine andere Seite desselben Würfels.", Rarity.COMMON)

static func transplant() -> Coupon:
	return _make(TRANSPLANT, "Transplantat", "Hebe eine Seite auf den aktuell höchsten Wert des Würfels.", Rarity.COMMON)

static func grindstone() -> Coupon:
	return _make(GRINDSTONE, "Schleifstein", "−1 auf eine Seite, +1 auf eine andere Seite desselben Würfels.", Rarity.COMMON)

static func fine_engraving() -> Coupon:
	return _make(FINE_ENGRAVING, "Feingravur", "Setze eine Seite auf einen frei gewählten Wert 1–12.", Rarity.UNCOMMON)

static func overcount_engraving() -> Coupon:
	return _make(OVERCOUNT_ENGRAVING, "Überzahl-Gravur", "+1 auf eine Seite, darf über 6 hinausgehen.", Rarity.RARE)

static func file_down() -> Coupon:
	return _make(FILE_DOWN, "Feile", "−1 auf eine Seite (min. 1).", Rarity.COMMON)

static func double_notch() -> Coupon:
	return _make(DOUBLE_NOTCH, "Doppelkerbe", "+1 auf zwei verschiedene Seiten desselben Würfels (darf über 6 hinaus).", Rarity.COMMON)

static func averaging() -> Coupon:
	return _make(AVERAGING, "Mittelung", "Zwei Seiten eines Würfels werden auf ihren aufgerundeten Mittelwert gesetzt.", Rarity.UNCOMMON)

static func connect_up() -> Coupon:
	return _make(CONNECT_UP, "Anschluss", "Setze eine Seite auf den Wert einer anderen Seite desselben Würfels +1 (darf über 6 hinaus).", Rarity.UNCOMMON)

static func mirror() -> Coupon:
	return _make(MIRROR, "Spiegelung", "Invertiere alle Seiten eines Würfels ((Min+Max) − Wert).", Rarity.UNCOMMON)

static func imprint() -> Coupon:
	return _make(IMPRINT, "Abdruck", "Präge den Wert einer Seite auf die beiden niedrigsten anderen Seiten desselben Würfels.", Rarity.UNCOMMON)

static func straighten() -> Coupon:
	return _make(STRAIGHTEN, "Begradigung", "+1 auf alle ungeraden Seiten eines Würfels (darf über 6 hinaus).", Rarity.UNCOMMON)

static func blueprint() -> Coupon:
	return _make(BLUEPRINT, "Blaupause", "Setze alle Seiten des Würfels auf den Wert einer gewählten Seite.", Rarity.RARE)

# --- Materialien: Name/Beschreibung kommen direkt vom DieMaterial ---

static func material_coupon(material: DieMaterial, rarity: Rarity) -> Coupon:
	return _make(material.id, material.display_name, material.description, rarity, KIND_MATERIAL)

## Kanten-Coupon: veredelt den GANZEN Würfel statt einer Seite.
static func edge_coupon(material: DieMaterial, rarity: Rarity) -> Coupon:
	return _make(EDGE_PREFIX + material.id, "%s-Kanten" % material.display_name, material.edge_description, rarity, KIND_EDGE)

## Menü-Coupon: wird er vom Bogen gelöst, ist das Gericht sofort gegessen und
## wertet die Kombination dauerhaft auf - er landet nie im Inventar.
static func meal_coupon(combo_key: String) -> Coupon:
	var description := "Wertet %s dauerhaft auf: +%d auf den Multiplikator." % [
		DiceScoring.label_for(combo_key), DiceScoring.mult_for(combo_key)]
	return _make(MEAL_PREFIX + combo_key, MEAL_NAMES.get(combo_key, combo_key),
		description, MEAL_RARITY.get(combo_key, Rarity.UNCOMMON), KIND_MEAL)

const MATERIAL_RARITY := {
	DieMaterial.GOLD: Rarity.COMMON,
	DieMaterial.AMBER: Rarity.COMMON,
	DieMaterial.GLASS: Rarity.UNCOMMON,
	DieMaterial.BONE: Rarity.UNCOMMON,
	DieMaterial.RUBY: Rarity.UNCOMMON,
	DieMaterial.MERCURY: Rarity.RARE,
}

## Kanten-Coupons: eine Stufe über der Seiten-Variante.
const EDGE_RARITY := {
	DieMaterial.GOLD: Rarity.UNCOMMON,
	DieMaterial.AMBER: Rarity.UNCOMMON,
	DieMaterial.GLASS: Rarity.RARE,
	DieMaterial.BONE: Rarity.RARE,
	DieMaterial.RUBY: Rarity.RARE,
	DieMaterial.MERCURY: Rarity.RARE,
}

## Kanonische Registrierung aller Coupon-Archetypen; Material-/Kanten-Coupons
## kommen aus DieMaterial.all(), Menü-Coupons aus DiceScoring.CATEGORIES.
static func all() -> Array[Coupon]:
	var result: Array[Coupon] = [
		chisel(), transplant(), grindstone(), fine_engraving(), overcount_engraving(),
		file_down(), double_notch(), averaging(), connect_up(), mirror(), imprint(), straighten(), blueprint(),
	]
	for material in DieMaterial.all():
		result.append(material_coupon(material, MATERIAL_RARITY.get(material.id, Rarity.UNCOMMON)))
	for material in DieMaterial.all():
		result.append(edge_coupon(material, EDGE_RARITY.get(material.id, Rarity.RARE)))
	for cat in DiceScoring.CATEGORIES:
		result.append(meal_coupon(cat["key"]))
	return result

static func is_edge_id(coupon_id: String) -> bool:
	return coupon_id.begins_with(EDGE_PREFIX) and DieMaterial.is_valid_id(coupon_id.trim_prefix(EDGE_PREFIX))

## DieMaterial-id hinter diesem Coupon ("" bei Ätzungen/Gerichten).
func material_id() -> String:
	match kind:
		KIND_MATERIAL:
			return id
		KIND_EDGE:
			return id.trim_prefix(EDGE_PREFIX)
	return ""

## Kategorie-Key hinter einem Menü-Coupon ("" bei allen anderen kinds).
func meal_combo_key() -> String:
	return id.trim_prefix(MEAL_PREFIX) if kind == KIND_MEAL else ""

static func rarity_name(value: Rarity) -> String:
	match value:
		Rarity.COMMON:
			return "häufig"
		Rarity.UNCOMMON:
			return "ungewöhnlich"
		Rarity.RARE:
			return "selten"
	return "?"

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
