class_name DiceOffer
extends RefCounted
## Ein Würfel-Angebot im Shop: 1..3 frisch ausgewürfelte Würfel für EINEN
## Preis. Grundregel: je mehr Würfel ein Bündel hat, desto schwächer sind sie
## einzeln - Menge gegen Qualität. Anzeige baut der ShopController.

## Vorlagen: count = Bündelgröße; values = erlaubte Augenzahlen je Seite;
## pasch=true erzeugt gehäufte hohe Seiten. style_id (≠ "normal") schützt
## gekaufte Würfel vor Verdrängung im Pool.
const TEMPLATES := [
	{"name": "Kraftwürfel", "style_id": "power", "count": 1, "price": 15, "values": [3, 4, 5, 6]},
	{"name": "Paschwürfel", "style_id": "pasch", "count": 1, "price": 16, "pasch": true},
	{"name": "Gerade Würfel", "style_id": "even", "count": 2, "price": 20, "values": [2, 4, 6]},
	{"name": "Ungerade Würfel", "style_id": "odd", "count": 2, "price": 15, "values": [1, 3, 5]},
	{"name": "Niedrige Serie", "style_id": "low", "count": 3, "price": 15, "values": [1, 2]},
	{"name": "Kleinserie", "style_id": "small", "count": 3, "price": 18, "values": [1, 2, 3]},
]

# Veredelungs-Chancen; jede Veredelung schlägt je Würfel auf den Preis auf.
const FACE_MATERIAL_CHANCE := 0.35
const SECOND_FACE_CHANCE := 0.35
const FACE_MATERIAL_SURCHARGE := 2

## Essenz-Rollen: gut jeder dritte Angebots-Würfel trägt eine Seele. Damit ist
## der Würfelkauf kein Stat-Kauf mehr, sondern ein Persönlichkeitskauf.
const ESSENCE_CHANCE := 0.4

## Gewichte innerhalb der Träger - Handelsgase sind Flaschenware, Phänomene die
## Ausnahme.
const ESSENCE_RARITY_WEIGHTS := {
	Essence.Rarity.COMMON: 70,
	Essence.Rarity.RARE: 20,
	Essence.Rarity.EPIC: 8,
	Essence.Rarity.LEGENDARY: 2,
}

## Aufpreis je Würfel. Bezugsgröße sind die Vorlagenpreise (15-20): ein häufiges
## Gas bleibt in der ersten Runde bezahlbar, ein Legendäres kostet mehr als der
## Würfel selbst.
const ESSENCE_SURCHARGE := {
	Essence.Rarity.COMMON: 6,
	Essence.Rarity.RARE: 14,
	Essence.Rarity.EPIC: 24,
	Essence.Rarity.LEGENDARY: 40,
}

var display_name: String = ""
var dice: Array[DieDefinition] = []
var price: int = 0

func size() -> int:
	return dice.size()

## Würfelt count verschiedene Angebote aus. Gütesiegel erzwingt mindestens
## eine Veredelung; Mengenrabatt garantiert ein 3er-Bündel in der Auslage.
static func roll_offers(count: int, charm_ids: Array[String] = [], owned_essences: Array[String] = []) -> Array[DiceOffer]:
	var offers: Array[DiceOffer] = []
	for t in pick_templates(count, charm_ids):
		offers.append(_from_template(t, charm_ids, owned_essences))
	return offers

## Zieht count verschiedene Vorlagen (auch die Paket-Auslage nutzt das).
## Mengenrabatt garantiert eine 3er-Vorlage im Fenster.
static func pick_templates(count: int, charm_ids: Array[String] = []) -> Array[Dictionary]:
	var templates := TEMPLATES.duplicate()
	templates.shuffle()
	var window := mini(count, templates.size())
	if charm_ids.has(Charm.BULK_DISCOUNT) and window > 0:
		var has_bundle := false
		for i in window:
			if int(templates[i]["count"]) >= 3:
				has_bundle = true
				break
		if not has_bundle:
			for j in range(window, templates.size()):
				if int(templates[j]["count"]) >= 3:
					var bundle: Dictionary = templates[j]
					templates[j] = templates[window - 1]
					templates[window - 1] = bundle
					break
	var picked: Array[Dictionary] = []
	for i in window:
		picked.append(templates[i])
	return picked

## Ein Angebot bündelt immer nur EINEN Würfeltyp: ein Würfel wird ausgewürfelt
## und count-mal als unabhängige Kopie ins Bündel gelegt.
static func _from_template(t: Dictionary, charm_ids: Array[String] = [], owned_essences: Array[String] = []) -> DiceOffer:
	var offer := DiceOffer.new()
	offer.display_name = t["name"]
	offer.dice = []
	var base := make_die(t)
	var surcharge := roll_refinements(base)
	# Gütesiegel: ging der Würfel leer aus, garantiert eine Material-Seite.
	if CharmEffects.forces_refinement(charm_ids) and base.materials.count("") == base.materials.size():
		base.set_face_material(randi() % base.materials.size(), DieMaterial.all().pick_random().id)
		surcharge += FACE_MATERIAL_SURCHARGE
	# Ein Unikat nur im Einzel-Bündel: drei Kopien derselben Legende gäbe es nicht.
	base.essence_id = roll_essence(owned_essences, int(t["count"]) == 1)
	surcharge += essence_surcharge(base.essence_id)
	offer.price = int(t["price"]) + surcharge * int(t["count"])
	for i in int(t["count"]):
		offer.dice.append(base.instantiate())
	return offer

## Würfelt Veredelungen aus (1-2 Material-Seiten); liefert den Aufpreis je Würfel.
static func roll_refinements(def: DieDefinition) -> int:
	var surcharge := 0
	if randf() < FACE_MATERIAL_CHANCE:
		var face_count := 2 if randf() < SECOND_FACE_CHANCE else 1
		var face_indices := range(6)
		face_indices.shuffle()
		for i in face_count:
			def.set_face_material(face_indices[i], DieMaterial.all().pick_random().id)
			surcharge += FACE_MATERIAL_SURCHARGE
	return surcharge

## Einzelner Würfel gemäß Vorlage: Seiten aus values, oder bei pasch=true
## 3..4 gleiche hohe Seiten plus Rest zufällig.
static func make_die(t: Dictionary) -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = []
	if t.get("pasch", false):
		var pasch_value: int = [3, 4, 5, 6].pick_random()
		var repeats: int = randi_range(3, 4)
		for i in 6:
			faces.append(pasch_value if i < repeats else randi_range(1, 6))
		faces.shuffle()
	else:
		var values: Array = t["values"]
		for i in 6:
			faces.append(int(values.pick_random()))
	def.faces = faces
	def.style_id = t["style_id"]
	def.display_name = t["name"]
	return def

## Würfelt die Essenz eines Angebots-Würfels aus ("" = essenzlos). Schwarzmarkt-
## Essenzen liegen NIE im normalen Handel; Unikate nur einzeln und nur, solange
## der Spieler keins besitzt (dieselbe Ausschluss-Regel wie bei den Charms).
static func roll_essence(owned_essences: Array[String] = [], allow_unique: bool = true) -> String:
	if randf() >= ESSENCE_CHANCE:
		return ""
	var pool: Array[Essence] = []
	for essence in Essence.tradeable():
		if essence.unique and (not allow_unique or owned_essences.has(essence.id)):
			continue
		pool.append(essence)
	if pool.is_empty():
		return ""
	var total := 0
	for candidate in pool:
		total += int(ESSENCE_RARITY_WEIGHTS.get(candidate.rarity, 1))
	var pick := randi() % maxi(1, total)
	for candidate in pool:
		pick -= int(ESSENCE_RARITY_WEIGHTS.get(candidate.rarity, 1))
		if pick < 0:
			return candidate.id
	return pool[pool.size() - 1].id

## Preisaufschlag einer Essenz je Würfel (0 ohne Essenz).
static func essence_surcharge(essence_id: String) -> int:
	var essence := Essence.by_id(essence_id)
	return int(ESSENCE_SURCHARGE.get(essence.rarity, 0)) if essence != null else 0
