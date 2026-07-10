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
## Würfel vor Verdrängung und lässt die Wünschelrute sie zuerst ziehen (siehe
## GameRun/scene_root) und steuert die Einfärbung (siehe DiceController.KIND_TINTS).
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

var display_name: String = ""
var dice: Array[DieDefinition] = []  # 1..3 frisch erzeugte Würfel des Angebots
var price: int = 0

## Anzahl Würfel im Bündel.
func size() -> int:
	return dice.size()

## Würfelt count verschiedene Angebote aus (verschiedene Vorlagen, jeweils frisch
## erzeugte Würfel). Grundlage der Shop-Auslage (siehe ShopController).
static func roll_offers(count: int) -> Array[DiceOffer]:
	var templates := TEMPLATES.duplicate()
	templates.shuffle()
	var offers: Array[DiceOffer] = []
	for i in mini(count, templates.size()):
		offers.append(_from_template(templates[i]))
	return offers

static func _from_template(t: Dictionary) -> DiceOffer:
	var offer := DiceOffer.new()
	offer.display_name = t["name"]
	offer.price = t["price"]
	offer.dice = []
	for i in int(t["count"]):
		offer.dice.append(_make_die(t))
	return offer

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
