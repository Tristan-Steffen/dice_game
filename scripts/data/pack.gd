class_name Pack
extends Resource
## Ein versiegeltes Paket: der Shop verkauft nur noch Pakete, geöffnet werden sie
## später in der Werkstatt. Der Inhalt wird ERST beim Öffnen ausgewürfelt - der
## Kauf entscheidet nur die Sorte. ids sind Konstanten, damit Tippfehler
## Compilerfehler sind.
##
## Ein Gravur-Paket ist GENAU EIN Phantomwürfel (PhantomPress): seine sechs
## Seiten tragen die sechs Icons seiner Sorte, und benachbarte Leser mit demselben
## Icon heben einander. Mehrere Pakete auf einmal zu öffnen ist die einzige
## Schiene, auf der Beute stärker wird.

## Paketsorten. Die drei Gravur-Sorten bilden auf Engraving-Kategorien ab
## (siehe engraving_category), Würfel-Pakete auf eine DiceOffer-Vorlage.
const TYPE_NUMBER := "number"
const TYPE_MATERIAL := "material"
const TYPE_DICE := "dice"
## Runen-Paket: liegt seit dem Werkstatt-Umbau auch im Regal, nicht mehr nur im
## Automaten.
const TYPE_DICE_MOD := "dice_mod"

## Ein Gravur-Paket = ein Phantomwürfel. Die Zahl steht als Konstante, damit
## niemand sie an einer Fabrik wieder aufbläht.
const ENGRAVING_PACK_COUNT := 1

## Preise je 1er-Paket - Runen sind die teuerste Sorte, sechs Zahlen-Pakete sind
## der Lauf auf den Sechserpasch.
const NUMBER_PRICE := 5
const MATERIAL_PRICE := 6
const DICE_MOD_PRICE := 7

## Auslage-Gewichte der Gravur-Pakete (relativ).
const SHELF_WEIGHTS := {
	TYPE_NUMBER: 6,
	TYPE_MATERIAL: 3,
	TYPE_DICE_MOD: 2,
}

const TYPE_NAMES := {
	TYPE_NUMBER: "Zahlen-Paket",
	TYPE_MATERIAL: "Material-Paket",
	TYPE_DICE: "Würfel-Paket",
	TYPE_DICE_MOD: "Runen-Paket",
}

@export var type: String = TYPE_NUMBER
@export var display_name: String = ""
@export var description: String = ""
@export var count: int = 1
@export var price: int = 0
## Identität im Lager: GameRun stempelt sie beim Einlagern (_stash_pack). 0 = noch
## nie eingelagert. An ihr hängen Magazin-Platz, Liefer-Vormerkung und Körper.
@export var pack_uid: int = 0
## Nur bei TYPE_DICE: style_id der DiceOffer-Vorlage (bestimmt die Würfelart).
@export var template_id: String = ""
## Alle Auswahl-Würfel dieses Pakets tragen garantiert eine Seele - so kommt das
## Würfel-Paket der Hub-Belohnung heraus. Der Unikat-Ausschluss gilt weiter.
@export var essence_guaranteed: bool = false
## Genau DIESER Würfel liegt im Paket (Schwarzmarkt): nichts wird nachgewürfelt -
## die Seele, die der Spieler im Regal gesehen hat, ist die, die er auspackt.
@export var fixed_die: DieDefinition = null
## Genau DIESE Gravur liegt im Paket (Abguss, Schmuckkästchen, Schwarzmarkt-
## Sonderposten). Ihr Phantomwürfel landet FEST auf diesem Icon und lässt sich
## nicht nachwürfeln - er spielt in der Hand trotzdem mit. Spiegel von fixed_die.
@export var fixed_engraving: Engraving = null

static func _make(pack_type: String, amount: int, cost: int, desc: String) -> Pack:
	var pack := Pack.new()
	pack.type = pack_type
	pack.display_name = TYPE_NAMES.get(pack_type, pack_type)
	pack.count = amount
	pack.price = cost
	pack.description = desc
	return pack

static func number_pack() -> Pack:
	return _make(TYPE_NUMBER, ENGRAVING_PACK_COUNT, NUMBER_PRICE,
		"Ein Phantomwurf auf die sechs Zahlen-Gravuren, versiegelt.")

static func material_pack() -> Pack:
	return _make(TYPE_MATERIAL, ENGRAVING_PACK_COUNT, MATERIAL_PRICE,
		"Ein Phantomwurf auf die sechs Materialien, versiegelt.")

static func dice_mod_pack() -> Pack:
	return _make(TYPE_DICE_MOD, ENGRAVING_PACK_COUNT, DICE_MOD_PRICE,
		"Ein Phantomwurf auf die sechs Runen, versiegelt.")

## Fester Goldpreis eines Sonderposten-Einzelstücks im normalen Regal - er hängt
## weder an der Sorte noch an der Lizenz. Bündel gibt es nur im Hinterzimmer.
const SPECIAL_PRICE := 30

## Fixinhalt-Paket: der Phantomwürfel liegt fest auf diesem Icon. amount > 1 legt
## mehrere Kopien in DIESELBE Karte - ein Bündel ist eine Datenkarte, kein Stapel.
## Preis 0 ist der Regelfall: so etwas wird gefunden oder abgegossen; nur der
## Handel setzt einen.
static func fixed_engraving_pack(engraving: Engraving, amount := ENGRAVING_PACK_COUNT,
		cost := 0) -> Pack:
	if engraving == null:
		return number_pack()
	var many := maxi(amount, 1)
	var text := "%s, versiegelt." % engraving.display_name if many == 1 		else "%d× %s auf EINER Karte, versiegelt." % [many, engraving.display_name]
	var pack := _make(pack_type_for_category(engraving.category), many, cost, text)
	pack.display_name = engraving.display_name
	pack.fixed_engraving = engraving
	return pack

## Sonderposten fürs normale Regal: welcher, entscheidet der Wurf - dass überhaupt
## einer ausliegt, entscheidet GameRun.shop_special_chance.
static func roll_special_pack() -> Pack:
	var special := Engraving.by_id(String(Engraving.SPECIAL_IDS.pick_random()))
	if special == null:
		return roll_engraving_pack()
	return fixed_engraving_pack(special, ENGRAVING_PACK_COUNT, SPECIAL_PRICE)

## Paketsorte einer Gravur-Kategorie (Umkehrung von engraving_category).
static func pack_type_for_category(category: String) -> String:
	match category:
		Engraving.CATEGORY_MATERIAL:
			return TYPE_MATERIAL
		Engraving.CATEGORY_DICE:
			return TYPE_DICE_MOD
	return TYPE_NUMBER

## Würfel-Paket zu einer DiceOffer-Vorlage: die Sorte ist bekannt, die Augen
## nicht. Material-Seiten kosten hier keinen Aufschlag - das ist der Blindkauf-Bonus.
## Mehrfach-Pakete decken ALLE Würfel auf und geben genau EINEN mit: gekauft
## wird die Auswahl, nicht die Menge. Je zusätzlich aufgedecktem Würfel kostet
## das Paket darum etwas mehr - "der beste aus dreien" ist mehr wert als "einer
## auf gut Glück", auch wenn am Ende nur ein Würfel im Pool landet.
const DICE_PACK_PICK_SURCHARGE := 4

static func dice_pack(template: Dictionary) -> Pack:
	var count := int(template["count"])
	var price := int(template["price"]) + (count - 1) * DICE_PACK_PICK_SURCHARGE
	var text := "%s, ungeöffnet." % template["name"] if count == 1 else "%d× %s aufgedeckt, einer darf mit." % [count, template["name"]]
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
	return [number_pack(), material_pack(), dice_mod_pack()]

## Frisches Gravur-Paket zur Sorte - damit Tabellen (Hub-Belohnung) mit Typ-ids
## arbeiten können statt mit Fabrik-Referenzen.
static func by_type(pack_type: String) -> Pack:
	match pack_type:
		TYPE_MATERIAL:
			return material_pack()
		TYPE_DICE_MOD:
			return dice_mod_pack()
	return number_pack()

# --- Magazin-Taxonomie: welcher Sorte ein Paket im Lager zugehört -----------------
# Wohnt in data/, weil auch GameRun (tidy_packs) danach sortiert; die Farben dazu
# hält die UI (PackDrawerView.COLORS spiegelt die Schlüssel, Rune.tint-Regel).

## Pseudo-Sorten der Sonderposten (Engraving.SPECIAL_IDS) und der Würfel-Pakete:
## beide tragen keine Gravur-Kategorie, brauchen aber ihren Platz im Magazin.
const SHELF_SPECIAL := "special"
const SHELF_DICE_PACK := "dice_pack"

## Kanonische Sorten-Reihenfolge - EINE Quelle für Magazin, tidy und Siegel.
const SHELF_ORDER := [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL,
	Engraving.CATEGORY_DICE, SHELF_DICE_PACK, SHELF_SPECIAL]

## Ein Fixinhalt-Paket mit Sonderposten gehört zum Sonderbestand. Würfel-Pakete
## haben ihre eigene Sorte, alles andere zählt zu seiner Gravur-Sorte.
static func pack_belongs(pack: Pack, shelf: String) -> bool:
	if pack == null:
		return false
	if pack.is_dice_pack():
		return shelf == SHELF_DICE_PACK
	var fixed := pack.fixed_engraving
	if fixed != null and Engraving.is_special_id(fixed.id):
		return shelf == SHELF_SPECIAL
	return pack.engraving_category() == shelf

## Die Magazin-Sorte dieses Pakets ("" = keine).
static func shelf_of(pack: Pack) -> String:
	for shelf: String in SHELF_ORDER:
		if pack_belongs(pack, shelf):
			return shelf
	return ""

## Die Umkehrung: der Pakettyp, dessen Siegel diese Sorte zeichnet ("" = der
## Sonderbestand, dessen Zeichen der Eckrahmen ist). EINE Zuordnung, in beide
## Richtungen gelesen - eine zweite Tabelle liefe auseinander.
static func pack_type_of_shelf(shelf: String) -> String:
	for pack_type: String in [TYPE_DICE, TYPE_NUMBER, TYPE_MATERIAL, TYPE_DICE_MOD]:
		if shelf_for_pack_type(pack_type) == shelf:
			return pack_type
	return ""

## Sorte, in der ein Paket dieses Typs landet (Lieferweg des Ladens - dort ist
## nur der Typ bekannt, nie ein Fixinhalt).
static func shelf_for_pack_type(pack_type: String) -> String:
	match pack_type:
		TYPE_DICE:
			return SHELF_DICE_PACK
		TYPE_MATERIAL:
			return Engraving.CATEGORY_MATERIAL
		TYPE_DICE_MOD:
			return Engraving.CATEGORY_DICE
	return Engraving.CATEGORY_NUMBER

## Name einer Magazin-Sorte: die Paketsorte, die dort wohnt - der Sonderbestand
## trägt keine und nennt sich selbst.
const SHELF_NAME_SPECIAL := "Sonderbestand"

static func shelf_name(shelf: String) -> String:
	if shelf == SHELF_SPECIAL:
		return SHELF_NAME_SPECIAL
	return String(TYPE_NAMES.get(pack_type_of_shelf(shelf), shelf))

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

## Sorte für die Presse: die Gravur-Kategorie, auf deren Ikonensatz der
## Phantomwürfel dieses Pakets fällt ("" bei Würfel-Paketen).
func press_sort() -> String:
	return engraving_category()

## Inhalt eines Würfel-Pakets: count EIGENSTÄNDIG ausgewürfelte Würfel derselben
## Art. Sie müssen sich unterscheiden - der Spieler deckt alle auf und nimmt
## GENAU EINEN mit (siehe WorkshopView.Phase.CHOOSE_DIE); wären es Kopien, wäre
## die Wahl eine Attrappe. Material-Seiten kosten hier nichts extra - dafür ist es
## ein Blindkauf.
func roll_dice(charm_ids: Array[String] = [], owned_essences: Array[String] = [], hub_level: int = 1) -> Array[DieDefinition]:
	var dice: Array[DieDefinition] = []
	if not is_dice_pack():
		return dice
	# Fest eingelegter Würfel (Schwarzmarkt): keine Material-Seiten, kein Seelen-Wurf.
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
		# Gütesiegel: ging der Würfel leer aus, garantiert eine Material-Seite -
		# und mindestens eine ist veredelt. Aufpreis gibt es hier keinen.
		if CharmEffects.forces_refinement(charm_ids):
			if die.materials.count("") == die.materials.size():
				die.set_face_material(randi() % die.materials.size(), DieMaterial.all().pick_random().id)
			if not DiceOffer.has_doped_side(die):
				for f in die.materials.size():
					if die.dope(f):
						break
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

## Zufällige Gravur-Paketsorte für einen Auslage-Platz. Bewusst OHNE Hub-Stufe:
## die Sorte entscheiden allein die Regal-Gewichte - stark wird Beute an der
## Presse (Ausbeute, Seltenheits-Gewichte), nicht an der Lizenz.
static func roll_engraving_pack() -> Pack:
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
			return by_type(pool[i])
	return number_pack()
