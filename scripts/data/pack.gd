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
const TYPE_MIXED := "mixed"

## Inhaltsmenge und Preis je Gravur-Sorte - die Sorte STEUERT die Häufigkeit:
## viele Zahlen, mäßig Materialien, sehr selten Kanten.
const NUMBER_COUNT := 4
const MATERIAL_COUNT := 3
const EDGE_COUNT := 1
const MIXED_COUNT := 4

const NUMBER_PRICE := 12
const MATERIAL_PRICE := 14
const EDGE_PRICE := 18
const MIXED_PRICE := 15

## Kanten-Pakete liegen erst ab dieser Hub-Stufe im Laden.
const EDGE_HUB_LEVEL := 5

## Auslage-Gewichte der Gravur-Pakete (relativ, ohne Kanten unter EDGE_HUB_LEVEL).
const SHELF_WEIGHTS := {
	TYPE_NUMBER: 6,
	TYPE_MATERIAL: 3,
	TYPE_EDGE: 1,
	TYPE_MIXED: 2,
}

## Kategorie-Gewichte JE STÜCK eines gemischten Pakets - dieselbe Häufigkeits-
## Idee wie die Auslage: viele Zahlen, mäßig Material, selten eine Kante. Der
## seltene Kanten-Treffer vor EDGE_HUB_LEVEL ist gewollt - der Reiz des Blindkaufs.
const MIXED_CATEGORY_WEIGHTS := {
	Engraving.CATEGORY_NUMBER: 6,
	Engraving.CATEGORY_MATERIAL: 3,
	Engraving.CATEGORY_DICE: 1,
}

const TYPE_NAMES := {
	TYPE_NUMBER: "Zahlen-Paket",
	TYPE_MATERIAL: "Material-Paket",
	TYPE_EDGE: "Kanten-Paket",
	TYPE_DICE: "Würfel-Paket",
	TYPE_MIXED: "Gemischtes Paket",
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

static func mixed_pack() -> Pack:
	return _make(TYPE_MIXED, MIXED_COUNT, MIXED_PRICE,
		"%d Gravuren quer durch alle Sorten, versiegelt." % MIXED_COUNT)

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
	return [number_pack(), material_pack(), edge_pack(), mixed_pack()]

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
	if type == TYPE_MIXED:
		# Jedes Stück würfelt seine Kategorie einzeln (Doppelte erlaubt - der
		# Bestand stapelt ohnehin als ×Anzahl).
		var out: Array[Engraving] = []
		for i in count:
			out.append_array(Engraving.roll_in_category(_mixed_category(), 1, floor))
		return out
	var category := engraving_category()
	if category == "":
		return [] as Array[Engraving]
	return Engraving.roll_in_category(category, count, floor)

## Gewichtete Kategorie EINES Stücks aus einem gemischten Paket.
func _mixed_category() -> String:
	var total := 0
	for weight in MIXED_CATEGORY_WEIGHTS.values():
		total += weight
	var pick := randi() % total
	for category: String in MIXED_CATEGORY_WEIGHTS:
		pick -= MIXED_CATEGORY_WEIGHTS[category]
		if pick < 0:
			return category
	return Engraving.CATEGORY_NUMBER

## Inhalt eines Würfel-Pakets: count unabhängige Kopien EINER frisch
## ausgewürfelten Würfelart. Veredelungen kosten hier nichts extra - der
## Blindkauf zahlt sich hier aus.
func roll_dice(charm_ids: Array[String] = []) -> Array[DieDefinition]:
	var dice: Array[DieDefinition] = []
	if not is_dice_pack():
		return dice
	var template := _template()
	if template.is_empty():
		return dice
	var base := DiceOffer.make_die(template)
	DiceOffer.roll_refinements(base)
	# Gütesiegel: ging der Würfel leer aus, garantiert eine Material-Seite.
	if CharmEffects.forces_refinement(charm_ids) and base.edge_material == "" \
			and base.materials.count("") == base.materials.size():
		base.set_face_material(randi() % base.materials.size(), DieMaterial.all().pick_random().id)
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
		TYPE_MIXED:
			return mixed_pack()
	return number_pack()
