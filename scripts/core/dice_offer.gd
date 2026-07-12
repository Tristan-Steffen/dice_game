class_name DiceOffer
extends RefCounted
## Ein Würfel-Angebot im Shop: 1..3 zufällig erzeugte Würfel, die zusammen für
## EINEN Preis gekauft werden (siehe GameRun.purchase_dice). Reine Daten +
## Erzeugung, keine Nodes (analog zu CouponSheet) - die Anzeige baut der
## ShopController.
##
## Grundregel: je mehr Würfel ein Angebot bündelt, desto schwächer sind sie
## einzeln (engere/niedrigere Wertebereiche) - Menge gegen Qualität. Die Werte
## werden bei jedem Shop-Besuch frisch ausgewürfelt (keine festen Vorlagen mehr).

## Angebots-Vorlagen: je {name, style_id, count, price, values|pasch}. count =
## Anzahl Würfel im Bündel; values = erlaubte Augenzahlen je Seite (zufällig
## gezogen). pasch=true erzeugt stattdessen einen Würfel mit mehreren gleichen
## hohen Seiten (garantierter Pasch). style_id (≠ "normal") schützt gekaufte
## Würfel vor Verdrängung (siehe GameRun) - eingefärbt wird danach NICHT mehr
## (Shop-Würfel sehen wie normale Würfel aus; besonders machen sie Seitenwerte
## und Veredelungen, siehe _roll_refinements).
const TEMPLATES := [
	# 1 Würfel - stark (hohe bzw. gehäufte Werte).
	{"name": "Kraftwürfel", "style_id": "power", "count": 1, "price": 15, "values": [3, 4, 5, 6]},
	{"name": "Paschwürfel", "style_id": "pasch", "count": 1, "price": 16, "pasch": true},
	# 2 Würfel - mittel (nur gerade bzw. nur ungerade Augen).
	{"name": "Gerade Würfel", "style_id": "even", "count": 2, "price": 20, "values": [2, 4, 6]},
	{"name": "Ungerade Würfel", "style_id": "odd", "count": 2, "price": 15, "values": [1, 3, 5]},
	# 3 Würfel - schwach (niedrige Augen), dafür viel Poolfüllung.
	{"name": "Niedrige Serie", "style_id": "low", "count": 3, "price": 15, "values": [1, 2]},
	{"name": "Kleinserie", "style_id": "small", "count": 3, "price": 18, "values": [1, 2, 3]},
]

# --- Veredelungs-Chancen je Angebot (siehe _roll_refinements): manchmal trägt
# der Angebots-Würfel schon Material-Seiten und/oder ein Kanten-Material -
# jede Veredelung schlägt je Würfel des Bündels auf den Preis auf. ---
const FACE_MATERIAL_CHANCE := 0.35   # Chance auf mindestens eine Material-Seite
const SECOND_FACE_CHANCE := 0.35     # Chance auf eine zweite, wenn die erste kam
const EDGE_MATERIAL_CHANCE := 0.2    # Chance auf ein Kanten-Material
const FACE_MATERIAL_SURCHARGE := 2   # Aufpreis je Material-Seite und Würfel
const EDGE_MATERIAL_SURCHARGE := 5   # Aufpreis je Kanten-Material und Würfel

var display_name: String = ""
var dice: Array[DieDefinition] = []  # 1..3 frisch erzeugte Würfel des Angebots
var price: int = 0

## Anzahl Würfel im Bündel.
func size() -> int:
	return dice.size()

## Würfelt count verschiedene Angebote aus (verschiedene Vorlagen, jeweils frisch
## erzeugte Würfel). Grundlage der Shop-Auslage (siehe ShopController).
## charm_ids (optional): das Gütesiegel erzwingt mindestens eine Veredelung;
## der Mengenrabatt lässt 3er-Bündel öfter auftreten (mindestens ein Bündel
## je Auslage).
static func roll_offers(count: int, charm_ids: Array[String] = []) -> Array[DiceOffer]:
	var templates := TEMPLATES.duplicate()
	templates.shuffle()
	var window := mini(count, templates.size())
	# Mengenrabatt (siehe CharmEffects.die_price): garantiert ein 3er-Bündel in
	# der Auslage - fehlt eines im Fenster, tauscht das letzte Angebot dagegen.
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

## Ein Angebot bündelt immer NUR EINEN Würfeltyp: es wird ein Würfel ausgewürfelt
## (inklusive eventueller Veredelungen, siehe _roll_refinements) und count-mal
## als unabhängige Kopie ins Bündel gelegt (gleiche Seiten/Materialien, nur die
## Anzahl variiert je Vorlage). Veredelungen verteuern das Bündel je Würfel.
static func _from_template(t: Dictionary, charm_ids: Array[String] = []) -> DiceOffer:
	var offer := DiceOffer.new()
	offer.display_name = t["name"]
	offer.dice = []
	var base := _make_die(t)
	var surcharge := _roll_refinements(base)
	# Gütesiegel (siehe CharmEffects.forces_refinement): ging der Würfel leer
	# aus, bekommt er garantiert eine Material-Seite (inkl. Aufpreis).
	if CharmEffects.forces_refinement(charm_ids) and base.edge_material == "" and base.materials.count("") == base.materials.size():
		base.materials[randi() % base.materials.size()] = DieMaterial.all().pick_random().id
		surcharge += FACE_MATERIAL_SURCHARGE
	offer.price = int(t["price"]) + surcharge * int(t["count"])
	for i in int(t["count"]):
		offer.dice.append(base.instantiate())
	return offer

## Würfelt die Veredelungen eines Angebots-Würfels aus: mit FACE_MATERIAL_CHANCE
## bekommen 1-2 zufällige Seiten ein zufälliges Material, mit
## EDGE_MATERIAL_CHANCE zusätzlich die Kanten (siehe DieMaterial). Liefert den
## Aufpreis JE WÜRFEL, den die Veredelungen wert sind (siehe _from_template).
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

## Erzeugt einen einzelnen Würfel gemäß Vorlage: entweder aus dem erlaubten
## Wertebereich (values) frei gezogene Seiten oder - bei pasch=true - 3..4 gleiche
## hohe Seiten plus Rest zufällig.
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
