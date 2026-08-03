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
const TYPE_DICE := "dice"
const TYPE_MIXED := "mixed"
## Nur Automaten-Gewinn: liegt nie im Regal, darum ohne SHELF_WEIGHTS-Eintrag.
const TYPE_DICE_MOD := "dice_mod"

## Inhaltsmenge und Preis je Gravur-Sorte - die Sorte STEUERT die Häufigkeit:
## viele Zahlen, mäßig Materialien.
const NUMBER_COUNT := 4
const MATERIAL_COUNT := 3
const MIXED_COUNT := 4
const DICE_MOD_COUNT := 2

const NUMBER_PRICE := 12
const MATERIAL_PRICE := 14
const MIXED_PRICE := 15

## Auslage-Gewichte der Gravur-Pakete (relativ).
const SHELF_WEIGHTS := {
	TYPE_NUMBER: 6,
	TYPE_MATERIAL: 3,
	TYPE_MIXED: 2,
}

## Kategorie-Gewichte JE STÜCK eines gemischten Pakets - dieselbe Häufigkeits-
## Idee wie die Auslage: viele Zahlen, mäßig Material, selten eine Würfel-Gravur.
const MIXED_CATEGORY_WEIGHTS := {
	Engraving.CATEGORY_NUMBER: 6,
	Engraving.CATEGORY_MATERIAL: 3,
	Engraving.CATEGORY_DICE: 1,
}

const TYPE_NAMES := {
	TYPE_NUMBER: "Zahlen-Paket",
	TYPE_MATERIAL: "Material-Paket",
	TYPE_DICE: "Würfel-Paket",
	TYPE_MIXED: "Gemischtes Paket",
	TYPE_DICE_MOD: "Würfel-Gravur-Paket",
}

@export var type: String = TYPE_NUMBER
@export var display_name: String = ""
@export var description: String = ""
@export var count: int = 1
@export var price: int = 0
## Nur bei TYPE_DICE: style_id der DiceOffer-Vorlage (bestimmt die Würfelart).
@export var template_id: String = ""
## Alle Auswahl-Würfel dieses Pakets tragen garantiert eine Seele - so kommt das
## Würfel-Paket der Hub-Belohnung heraus. Der Unikat-Ausschluss gilt weiter.
@export var essence_guaranteed: bool = false
## Eigene Mindest-Seltenheit des Inhalts; der Automat prägt seine Maschinen-Stufe
## hier hinein. Beim Öffnen gilt die HÖHERE von Paket und Hub.
@export var rarity_floor: int = Engraving.Rarity.COMMON
## Genau DIESER Würfel liegt im Paket (Schwarzmarkt): nichts wird nachgewürfelt -
## die Seele, die der Spieler im Regal gesehen hat, ist die, die er auspackt.
@export var fixed_die: DieDefinition = null

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

## Würfel-Gravur-Paket: reiner Automaten-Gewinn, darum Preis 0.
static func dice_mod_pack() -> Pack:
	return _make(TYPE_DICE_MOD, DICE_MOD_COUNT, 0,
		"%d Würfel-Gravuren, versiegelt." % DICE_MOD_COUNT)

static func mixed_pack() -> Pack:
	return _make(TYPE_MIXED, MIXED_COUNT, MIXED_PRICE,
		"%d Gravuren quer durch alle Sorten, versiegelt." % MIXED_COUNT)

## Würfel-Paket zu einer DiceOffer-Vorlage: die Sorte ist bekannt, die Augen
## nicht. Veredelungen kosten hier keinen Aufschlag - das ist der Blindkauf-Bonus.
## Mehrfach-Pakete decken ALLE Würfel auf und geben genau EINEN mit: gekauft
## wird die Auswahl, nicht die Menge. Je zusätzlich aufgedecktem Würfel kostet
## das Paket darum etwas mehr - "der beste aus dreien" ist mehr wert als "einer
## auf gut Glück", auch wenn am Ende nur ein Würfel im Pool landet.
const DICE_PACK_PICK_SURCHARGE := 4

static func dice_pack(template: Dictionary) -> Pack:
	var count := int(template["count"])
	var price := int(template["price"]) + (count - 1) * DICE_PACK_PICK_SURCHARGE
	var text := "%s, ungeöffnet." % template["name"] if count == 1 \
		else "%d× %s aufgedeckt, einer darf mit." % [count, template["name"]]
	var pack := _make(TYPE_DICE, count, price, text)
	pack.display_name = template["name"]
	pack.template_id = template["style_id"]
	return pack

## Stresstest-Prämie: EIN versiegelter Würfel der Vorlage, garantiert beseelt.
## Preis 0 - dieses Paket wird gewonnen, nie verkauft.
static func stress_die(template: Dictionary) -> Pack:
	var pack := _make(TYPE_DICE, 1, 0, "%s, ungeöffnet - beseelt." % template["name"])
	pack.display_name = template["name"]
	pack.template_id = template["style_id"]
	pack.essence_guaranteed = true
	return pack

## Schwarzmarkt-Würfel: EIN fest eingelegter Würfel, versiegelt. Preis 0 - der
## Laden hat ihn schon in ⚡ kassiert.
static func secret_die(die: DieDefinition) -> Pack:
	var pack := _make(TYPE_DICE, 1, 0, "%s, versiegelt - Schwarzmarktware." % die.display_name)
	pack.display_name = die.display_name
	pack.template_id = die.style_id
	pack.fixed_die = die
	return pack

## Kanonische Auslage der Gravur-Pakete.
static func all_engraving_packs() -> Array[Pack]:
	return [number_pack(), material_pack(), mixed_pack()]

## Frisches Gravur-Paket zur Sorte - damit Tabellen (Hub-Belohnung) mit Typ-ids
## arbeiten können statt mit Fabrik-Referenzen.
static func by_type(pack_type: String) -> Pack:
	match pack_type:
		TYPE_MATERIAL:
			return material_pack()
		TYPE_MIXED:
			return mixed_pack()
		TYPE_DICE_MOD:
			return dice_mod_pack()
	return number_pack()

## Engraving-Kategorie hinter einer Gravur-Paketsorte ("" bei Würfel-Paketen).
func engraving_category() -> String:
	match type:
		TYPE_NUMBER:
			return Engraving.CATEGORY_NUMBER
		TYPE_MATERIAL:
			return Engraving.CATEGORY_MATERIAL
		TYPE_DICE_MOD:
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

## Inhalt eines Würfel-Pakets: count EIGENSTÄNDIG ausgewürfelte Würfel derselben
## Art. Sie müssen sich unterscheiden - der Spieler deckt alle auf und nimmt
## GENAU EINEN mit (siehe WorkshopView.Phase.CHOOSE_DIE); wären es Kopien, wäre
## die Wahl eine Attrappe. Veredelungen kosten hier nichts extra - dafür ist es
## ein Blindkauf.
func roll_dice(charm_ids: Array[String] = [], owned_essences: Array[String] = [], hub_level: int = 1) -> Array[DieDefinition]:
	var dice: Array[DieDefinition] = []
	if not is_dice_pack():
		return dice
	# Fest eingelegter Würfel (Schwarzmarkt): keine Veredelung, kein Seelen-Wurf.
	if fixed_die != null:
		dice.append(fixed_die.instantiate())
		return dice
	var template := _template()
	if template.is_empty():
		return dice
	# Unikate dürfen nur EINMAL im Paket liegen: schon gerollte Seelen wandern in
	# die Sperrliste, damit nicht zwei Legendäre nebeneinander aufgedeckt werden.
	var taken := owned_essences.duplicate()
	for i in count:
		var die := DiceOffer.make_die(template, hub_level)
		DiceOffer.roll_refinements(die)
		# Gütesiegel: ging der Würfel leer aus, garantiert eine Material-Seite.
		if CharmEffects.forces_refinement(charm_ids) and die.materials.count("") == die.materials.size():
			die.set_face_material(randi() % die.materials.size(), DieMaterial.all().pick_random().id)
		die.essence_id = DiceOffer.roll_essence(taken, true, essence_guaranteed)
		if die.essence_id != "" and not taken.has(die.essence_id):
			taken.append(die.essence_id)
		dice.append(die)
	return dice

func _template() -> Dictionary:
	for t in DiceOffer.TEMPLATES:
		if t["style_id"] == template_id:
			return t
	return {}

## Zufällige Gravur-Paketsorte für einen Auslage-Platz.
static func roll_engraving_pack(hub_level: int) -> Pack:
	var pool: Array[String] = []
	var weights: Array[int] = []
	for pack_type: String in SHELF_WEIGHTS:
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
		TYPE_MIXED:
			return mixed_pack()
	return number_pack()
