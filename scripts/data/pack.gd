class_name Pack
extends Resource
## Ein versiegeltes Paket: der Shop verkauft nur noch Pakete, geöffnet werden sie
## später in der Werkstatt. Der Inhalt wird ERST beim Öffnen ausgewürfelt - der
## Kauf entscheidet nur die Sorte. ids sind Konstanten, damit Tippfehler
## Compilerfehler sind.

## Paketsorten. Die drei Gravur-Sorten bilden auf Engraving-Kategorien ab
## (siehe engraving_category), Würfel-Pakete auf eine DiceOffer-Vorlage.
const TYPE_NUMBER := "number"
const TYPE_MATERIAL := "material"
const TYPE_EDGE := "edge"
const TYPE_DICE := "dice"

## Inhaltsmenge und Preis je Gravur-Sorte - die Sorte STEUERT die Häufigkeit:
## viele Zahlen, mäßig Materialien, sehr selten Kanten.
const NUMBER_COUNT := 4
const MATERIAL_COUNT := 3
const EDGE_COUNT := 1

const NUMBER_PRICE := 12
const MATERIAL_PRICE := 14
const EDGE_PRICE := 18

## Kanten-Pakete liegen erst ab dieser Hub-Stufe im Laden.
const EDGE_HUB_LEVEL := 5

## Auslage-Gewichte der Gravur-Pakete (relativ, ohne Kanten unter EDGE_HUB_LEVEL).
const SHELF_WEIGHTS := {
	TYPE_NUMBER: 6,
	TYPE_MATERIAL: 3,
	TYPE_EDGE: 1,
}

const TYPE_NAMES := {
	TYPE_NUMBER: "Zahlen-Paket",
	TYPE_MATERIAL: "Material-Paket",
	TYPE_EDGE: "Kanten-Paket",
	TYPE_DICE: "Würfel-Paket",
}

@export var type: String = TYPE_NUMBER
@export var display_name: String = ""
@export var description: String = ""
@export var count: int = 1
@export var price: int = 0
## Nur bei TYPE_DICE: style_id der DiceOffer-Vorlage (bestimmt die Würfelart).
@export var template_id: String = ""

static func _make(pack_type: String, amount: int, cost: int, desc: String) -> Pack:
	var pack := Pack.new()
	pack.type = pack_type
	pack.display_name = TYPE_NAMES.get(pack_type, pack_type)
	pack.count = amount
	pack.price = cost
	pack.description = desc
	return pack

static func number_pack() -> Pack:
	return _make(TYPE_NUMBER, NUMBER_COUNT, NUMBER_PRICE,
		"%d Zahlen-Gravuren, versiegelt." % NUMBER_COUNT)

static func material_pack() -> Pack:
	return _make(TYPE_MATERIAL, MATERIAL_COUNT, MATERIAL_PRICE,
		"%d Material-Gravuren, versiegelt." % MATERIAL_COUNT)

static func edge_pack() -> Pack:
	return _make(TYPE_EDGE, EDGE_COUNT, EDGE_PRICE, "Eine Kanten-Gravur, versiegelt.")

## Würfel-Paket zu einer DiceOffer-Vorlage: die Sorte ist bekannt, die Augen
## nicht. Veredelungen kosten hier keinen Aufschlag - das ist der Blindkauf-Bonus.
static func dice_pack(template: Dictionary) -> Pack:
	var pack := _make(TYPE_DICE, int(template["count"]), int(template["price"]),
		"%d× %s, ungeöffnet." % [int(template["count"]), template["name"]])
	pack.display_name = template["name"]
	pack.template_id = template["style_id"]
	return pack

## Kanonische Auslage der Gravur-Pakete.
static func all_engraving_packs() -> Array[Pack]:
	return [number_pack(), material_pack(), edge_pack()]

## Engraving-Kategorie hinter einer Gravur-Paketsorte ("" bei Würfel-Paketen).
func engraving_category() -> String:
	match type:
		TYPE_NUMBER:
			return Engraving.CATEGORY_NUMBER
		TYPE_MATERIAL:
			return Engraving.CATEGORY_MATERIAL
		TYPE_EDGE:
			return Engraving.CATEGORY_DICE
	return ""

func is_dice_pack() -> bool:
	return type == TYPE_DICE

## Inhalt eines Gravur-Pakets (leer bei Würfel-Paketen).
func roll_engravings(floor: Engraving.Rarity = Engraving.Rarity.COMMON) -> Array[Engraving]:
	var category := engraving_category()
	if category == "":
		return [] as Array[Engraving]
	return Engraving.roll_in_category(category, count, floor)

## Inhalt eines Würfel-Pakets: count unabhängige Kopien EINER frisch
## ausgewürfelten Würfelart. Veredelungen kosten hier nichts extra - der
## Blindkauf zahlt sich hier aus.
func roll_dice() -> Array[DieDefinition]:
	var dice: Array[DieDefinition] = []
	if not is_dice_pack():
		return dice
	var template := _template()
	if template.is_empty():
		return dice
	var base := DiceOffer.make_die(template)
	DiceOffer.roll_refinements(base)
	for i in count:
		dice.append(base.instantiate())
	return dice

func _template() -> Dictionary:
	for t in DiceOffer.TEMPLATES:
		if t["style_id"] == template_id:
			return t
	return {}

## Zufällige Gravur-Paketsorte für einen Auslage-Platz; Kanten erst ab EDGE_HUB_LEVEL.
static func roll_engraving_pack(hub_level: int) -> Pack:
	var pool: Array[String] = []
	var weights: Array[int] = []
	for pack_type: String in SHELF_WEIGHTS:
		if pack_type == TYPE_EDGE and hub_level < EDGE_HUB_LEVEL:
			continue
		pool.append(pack_type)
		weights.append(SHELF_WEIGHTS[pack_type])
	var total := 0
	for w in weights:
		total += w
	var pick := randi() % total
	for i in pool.size():
		pick -= weights[i]
		if pick < 0:
			return _by_type(pool[i])
	return number_pack()

static func _by_type(pack_type: String) -> Pack:
	match pack_type:
		TYPE_MATERIAL:
			return material_pack()
		TYPE_EDGE:
			return edge_pack()
	return number_pack()
