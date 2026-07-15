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
const EDGE_MATERIAL_CHANCE := 0.2
const FACE_MATERIAL_SURCHARGE := 2
const EDGE_MATERIAL_SURCHARGE := 5

var display_name: String = ""
var dice: Array[DieDefinition] = []
var price: int = 0

func size() -> int:
	return dice.size()

## Würfelt count verschiedene Angebote aus. Gütesiegel erzwingt mindestens
## eine Veredelung; Mengenrabatt garantiert ein 3er-Bündel in der Auslage.
static func roll_offers(count: int, charm_ids: Array[String] = []) -> Array[DiceOffer]:
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
	var offers: Array[DiceOffer] = []
	for i in window:
		offers.append(_from_template(templates[i], charm_ids))
	return offers

## Ein Angebot bündelt immer nur EINEN Würfeltyp: ein Würfel wird ausgewürfelt
## und count-mal als unabhängige Kopie ins Bündel gelegt.
static func _from_template(t: Dictionary, charm_ids: Array[String] = []) -> DiceOffer:
	var offer := DiceOffer.new()
	offer.display_name = t["name"]
	offer.dice = []
	var base := _make_die(t)
	var surcharge := _roll_refinements(base)
	# Gütesiegel: ging der Würfel leer aus, garantiert eine Material-Seite.
	if CharmEffects.forces_refinement(charm_ids) and base.edge_material == "" and base.materials.count("") == base.materials.size():
		base.materials[randi() % base.materials.size()] = DieMaterial.all().pick_random().id
		surcharge += FACE_MATERIAL_SURCHARGE
	offer.price = int(t["price"]) + surcharge * int(t["count"])
	for i in int(t["count"]):
		offer.dice.append(base.instantiate())
	return offer

## Würfelt Veredelungen aus (1-2 Material-Seiten, evtl. Kanten-Material);
## liefert den Aufpreis je Würfel.
static func _roll_refinements(def: DieDefinition) -> int:
	var surcharge := 0
	if randf() < FACE_MATERIAL_CHANCE:
		var face_count := 2 if randf() < SECOND_FACE_CHANCE else 1
		var face_indices := range(6)
		face_indices.shuffle()
		for i in face_count:
			def.materials[face_indices[i]] = DieMaterial.all().pick_random().id
			surcharge += FACE_MATERIAL_SURCHARGE
	if randf() < EDGE_MATERIAL_CHANCE:
		def.edge_material = DieMaterial.all().pick_random().id
		surcharge += EDGE_MATERIAL_SURCHARGE
	return surcharge

## Einzelner Würfel gemäß Vorlage: Seiten aus values, oder bei pasch=true
## 3..4 gleiche hohe Seiten plus Rest zufällig.
static func _make_die(t: Dictionary) -> DieDefinition:
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
