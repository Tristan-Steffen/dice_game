class_name DiceOffer
extends RefCounted
## Ein Würfel-Angebot im Shop: 1..3 frisch ausgewürfelte Würfel für EINEN
## Preis. Grundregel: je mehr Würfel ein Bündel hat, desto schwächer sind sie
## einzeln - Menge gegen Qualität. Anzeige baut der ShopController.

## Vorlagen: count = Bündelgröße; values = erlaubte Augenzahlen je Seite;
## pasch=true erzeugt gehäufte hohe Seiten. style_id (≠ "normal") schützt
## gekaufte Würfel vor Verdrängung im Pool.
const TEMPLATES := [
	{"name": "Kraftwürfel", "style_id": "power", "count": 1, "price": 22, "values": [3, 4, 5, 6]},
	{"name": "Paschwürfel", "style_id": "pasch", "count": 1, "price": 24, "pasch": true},
	{"name": "Gerade Würfel", "style_id": "even", "count": 2, "price": 30, "values": [2, 4, 6]},
	{"name": "Ungerade Würfel", "style_id": "odd", "count": 2, "price": 22, "values": [1, 3, 5]},
	{"name": "Niedrige Serie", "style_id": "low", "count": 3, "price": 22, "values": [1, 2]},
	{"name": "Kleinserie", "style_id": "small", "count": 3, "price": 27, "values": [1, 2, 3]},
]

## Größte Augenzahl, die eine Vorlage von sich aus hergibt.
const MAX_TEMPLATE_FACE := 6
## Wachstum des Augen-Rahmens je Hub-Stufe: bis Stufe 10 verachtfacht er sich,
## aus einer 6 wird also eine ~48. Stufe 1 lässt den Würfel EXAKT so, wie er
## immer war - die besseren Würfel SIND die Belohnung für den Ausbau, deshalb
## bleibt der Preis, wo er ist. Für die Erkennung ändert sich nichts: die
## Kombinationsziffer ist seit jeher Wert % 10, eine 50 paart also als 0.
const HUB_FACE_GROWTH := 7.0 / 9.0
## Streuung um den Rahmen, damit nicht jeder Würfel dieselben runden Zahlen trägt.
const FACE_JITTER := 0.12

## Rahmen-Faktor der Augenzahlen auf dieser Hub-Stufe (Stufe 1 = 1.0).
static func hub_face_factor(hub_level: int) -> float:
	return 1.0 + HUB_FACE_GROWTH * float(clampi(hub_level, 1, 10) - 1)

## Größte Augenzahl, die auf dieser Stufe überhaupt fallen kann - die Obergrenze
## der Kurve, nicht ihr Regelfall. Kein Aufrufer im Spiel: sie ist das Orakel, an
## dem die Testreihe die echten Würfe misst, ohne die Formel nachzubauen.
static func max_face_for(hub_level: int) -> int:
	return maxi(MAX_TEMPLATE_FACE,
		int(round(float(MAX_TEMPLATE_FACE) * hub_face_factor(hub_level) * (1.0 + FACE_JITTER))))

# Material-Chancen; jede belegte Seite schlägt je Würfel auf den Preis auf.
const FACE_MATERIAL_CHANCE := 0.35
const SECOND_FACE_CHANCE := 0.35
const FACE_MATERIAL_SURCHARGE := 2

## Essenz-Rollen: die MEISTEN Angebots-Würfel tragen eine Seele. Damit ist der
## Würfelkauf kein Stat-Kauf mehr, sondern ein Persönlichkeitskauf - ein
## seelenloser Würfel ist die Ausnahme, nicht die Regel.
const ESSENCE_CHANCE := 0.75

## Gewichte innerhalb der Träger - Handelsgase sind Flaschenware, Phänomene die
## Ausnahme.
const ESSENCE_RARITY_WEIGHTS := {
	Essence.Rarity.COMMON: 70,
	Essence.Rarity.RARE: 20,
	Essence.Rarity.EPIC: 8,
	Essence.Rarity.LEGENDARY: 2,
}

## Aufpreis je Würfel. Bezugsgröße sind die Vorlagenpreise (22-30): ein häufiges
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
## eine Material-Seite, und eine davon veredelt.
static func roll_offers(count: int, charm_ids: Array[String] = [], owned_essences: Array[String] = [], hub_level: int = 1) -> Array[DiceOffer]:
	var offers: Array[DiceOffer] = []
	for t in pick_templates(count):
		offers.append(_from_template(t, charm_ids, owned_essences, hub_level))
	return offers

## Zieht count verschiedene Vorlagen (auch die Paket-Auslage nutzt das).
static func pick_templates(count: int) -> Array[Dictionary]:
	var templates := TEMPLATES.duplicate()
	templates.shuffle()
	var picked: Array[Dictionary] = []
	for i in mini(count, templates.size()):
		picked.append(templates[i])
	return picked

## Ein Angebot bündelt immer nur EINEN Würfeltyp: ein Würfel wird ausgewürfelt
## und count-mal als unabhängige Kopie ins Bündel gelegt.
static func _from_template(t: Dictionary, charm_ids: Array[String] = [], owned_essences: Array[String] = [], hub_level: int = 1) -> DiceOffer:
	var offer := DiceOffer.new()
	offer.display_name = t["name"]
	offer.dice = []
	var base := make_die(t, hub_level)
	var surcharge := roll_refinements(base)
	# Gütesiegel: ging der Würfel leer aus, garantiert eine Material-Seite - und
	# mindestens eine ist veredelt. Die Veredelung kostet wie das Material, das sie
	# aufwertet.
	if CharmEffects.forces_refinement(charm_ids):
		if base.materials.count("") == base.materials.size():
			base.set_face_material(randi() % base.materials.size(), DieMaterial.all().pick_random().id)
			surcharge += FACE_MATERIAL_SURCHARGE
		if not has_doped_side(base):
			for f in base.materials.size():
				if base.dope(f):
					surcharge += FACE_MATERIAL_SURCHARGE
					break
	# Ein Unikat nur im Einzel-Bündel: drei Kopien derselben Legende gäbe es nicht.
	base.essence_id = roll_essence(owned_essences, int(t["count"]) == 1)
	surcharge += essence_surcharge(base.essence_id)
	offer.price = int(t["price"]) + surcharge * int(t["count"])
	for i in int(t["count"]):
		offer.dice.append(base.instantiate())
	return offer

## EIN Prämien-Würfel (Hub-Ausbau, Stresstest): frisch gewürfelt, mit dem
## Gütesiegel wie jedes Angebot veredelt und mit GARANTIERTER Seele - die
## Unikat-/Geheim-Ausschlüsse und der Nicht-Unikat-Rückfall stehen in roll_essence.
## Preis kennt er keinen: er wird gewonnen, nie verkauft.
static func roll_reward_die(charm_ids: Array[String] = [],
		owned_essences: Array[String] = [], hub_level: int = 1) -> DieDefinition:
	var templates := pick_templates(1)
	if templates.is_empty():
		return null
	var die := make_die(templates[0], hub_level)
	roll_refinements(die)
	# Gütesiegel: ging der Würfel leer aus, garantiert eine Material-Seite - und
	# mindestens eine ist veredelt. Aufpreis gibt es hier keinen.
	if CharmEffects.forces_refinement(charm_ids):
		if die.materials.count("") == die.materials.size():
			die.set_face_material(randi() % die.materials.size(), DieMaterial.all().pick_random().id)
		if not has_doped_side(die):
			for f in die.materials.size():
				if die.dope(f):
					break
	die.essence_id = roll_essence(owned_essences, true, true)
	return die

## Trägt der Würfel schon eine veredelte Seite? (Gütesiegel, hier und im Paket.)
static func has_doped_side(def: DieDefinition) -> bool:
	for f in def.levels.size():
		if def.levels[f] >= DieMaterial.MAX_LEVEL:
			return true
	return false

## Würfelt 1-2 Material-Seiten aus; liefert den Aufpreis je Würfel.
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
static func make_die(t: Dictionary, hub_level: int = 1) -> DieDefinition:
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
	# Der Laden wächst mit dem Casino. Auf Stufe 1 greift das gar nicht - der
	# Würfel ist dort Zeichen für Zeichen der von früher.
	var factor := hub_face_factor(hub_level)
	if factor > 1.0:
		for i in faces.size():
			faces[i] = _scaled_face(faces[i], factor)
	def.faces = faces
	def.style_id = t["style_id"]
	def.display_name = t["name"]
	return def

## Eine Seite auf den Hub-Rahmen heben. Der Faktor gibt den Rahmen, die Streuung
## bricht die runden Zahlen auf; kleiner als vorher wird eine Seite nie.
static func _scaled_face(value: int, factor: float) -> int:
	var grown := float(value) * factor
	return maxi(value, int(round(grown + randf_range(-FACE_JITTER, FACE_JITTER) * grown)))

## Würfelt die Essenz eines Angebots-Würfels aus ("" = essenzlos). Schwarzmarkt-
## Essenzen liegen NIE im normalen Handel; Unikate nur einzeln und nur, solange
## der Spieler keins besitzt (dieselbe Ausschluss-Regel wie bei den Charms).
## guaranteed überspringt den Chancen-Wurf (Hub-Belohnung: alle Auswahl-Würfel
## tragen eine Seele). Die Unikat-Sperre gilt weiter - läuft der Topf dadurch
## leer, rückt ein NICHT-Unikat nach, statt den Würfel seelenlos zu lassen.
static func roll_essence(owned_essences: Array[String] = [], allow_unique: bool = true,
		guaranteed: bool = false) -> String:
	if not guaranteed and randf() >= ESSENCE_CHANCE:
		return ""
	var pool: Array[Essence] = []
	for essence in Essence.tradeable():
		if essence.unique and (not allow_unique or owned_essences.has(essence.id)):
			continue
		pool.append(essence)
	if pool.is_empty() and guaranteed:
		for essence in Essence.tradeable():
			if not essence.unique:
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
