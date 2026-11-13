class_name DiceOffer
extends RefCounted
## Ein Würfel-Angebot im Shop: 1..3 frisch ausgewürfelte Würfel für EINEN
## Preis. Grundregel: je mehr Würfel ein Bündel hat, desto schwächer sind sie
## einzeln - Menge gegen Qualität. Anzeige baut der ShopController.

## Vorlagen: count = Bündelgröße; values = erlaubte Augenzahlen je Seite;
## pasch=true erzeugt gehäufte hohe Seiten. price gilt je WÜRFEL (der Laden
## verkauft nur noch Einzelwürfel; Seite 41). style_id (≠ "normal") schützt
## gekaufte Würfel vor Verdrängung im Pool.
const TEMPLATES := [
	{"name": "Kraftwürfel", "style_id": "power", "count": 1, "price": 11, "values": [3, 4, 5, 6]},
	{"name": "Paschwürfel", "style_id": "pasch", "count": 1, "price": 12, "pasch": true},
	{"name": "Gerade Würfel", "style_id": "even", "count": 2, "price": 9, "values": [2, 4, 6]},
	{"name": "Ungerade Würfel", "style_id": "odd", "count": 2, "price": 7, "values": [1, 3, 5]},
	{"name": "Niedrige Serie", "style_id": "low", "count": 3, "price": 4, "values": [1, 2]},
	{"name": "Kleinserie", "style_id": "small", "count": 3, "price": 5, "values": [1, 2, 3]},
]

## Größte Augenzahl, die eine Vorlage von sich aus hergibt.
const MAX_TEMPLATE_FACE := 6
## Wachstum des Augen-Rahmens je Fortschrittsstufe: bis Stufe 10 verachtfacht er
## sich, aus einer 6 wird also eine ~48. Stufe 1 lässt den Würfel EXAKT so, wie er
## immer war - die besseren Würfel SIND der Fortschritt, deshalb bleibt der Preis,
## wo er ist. Für die Erkennung ändert sich nichts: die
## Kombinationsziffer ist seit jeher Wert % 10, eine 50 paart also als 0.
const TIER_FACE_GROWTH := 7.0 / 9.0
## Streuung um den Rahmen, damit nicht jeder Würfel dieselben runden Zahlen trägt.
const FACE_JITTER := 0.12

## Rahmen-Faktor der Augenzahlen auf dieser Fortschrittsstufe (Stufe 1 = 1.0).
static func tier_face_factor(tier: int) -> float:
	return 1.0 + TIER_FACE_GROWTH * float(clampi(tier, 1, GameRun.TIER_MAX) - 1)

## Größte Augenzahl, die auf dieser Stufe überhaupt fallen kann - die Obergrenze
## der Kurve, nicht ihr Regelfall. Kein Aufrufer im Spiel: sie ist das Orakel, an
## dem die Testreihe die echten Würfe misst, ohne die Formel nachzubauen.
static func max_face_for(tier: int) -> int:
	return maxi(MAX_TEMPLATE_FACE,
		int(round(float(MAX_TEMPLATE_FACE) * tier_face_factor(tier) * (1.0 + FACE_JITTER))))

# Material-Chancen; jede belegte Seite schlägt je Würfel auf den Preis auf.
const FACE_MATERIAL_CHANCE := 0.35
const SECOND_FACE_CHANCE := 0.35
const FACE_MATERIAL_SURCHARGE := 3

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

## Aufpreis je Würfel; ein Legendäres kostet mehr als jeder Würfel selbst.
const ESSENCE_SURCHARGE := {
	Essence.Rarity.COMMON: 4,
	Essence.Rarity.RARE: 8,
	Essence.Rarity.EPIC: 12,
	Essence.Rarity.LEGENDARY: 20,
}

var display_name: String = ""
var dice: Array[DieDefinition] = []
var price: int = 0

func size() -> int:
	return dice.size()

## Würfelt count verschiedene Angebote aus. Gütesiegel erzwingt mindestens
## eine Material-Seite, und eine davon veredelt.
## soul = die Seelen-Regel des Ladens ({"chance", "boost"}, GameRun.shop_soul_rule).
static func roll_offers(count: int, charm_ids: Array[String] = [], owned_essences: Array[String] = [], tier: int = 1,
		soul: Dictionary = {}) -> Array[DiceOffer]:
	var offers: Array[DiceOffer] = []
	for t in pick_templates(count):
		offers.append(_from_template(t, charm_ids, owned_essences, tier, soul))
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
static func _from_template(t: Dictionary, charm_ids: Array[String] = [], owned_essences: Array[String] = [], tier: int = 1,
		soul: Dictionary = {}) -> DiceOffer:
	var offer := DiceOffer.new()
	offer.display_name = t["name"]
	offer.dice = []
	var base := make_die(t, tier)
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
	base.essence_id = roll_essence(owned_essences, int(t["count"]) == 1, false,
		float(soul.get("chance", ESSENCE_CHANCE)), float(soul.get("boost", 1.0)))
	surcharge += essence_surcharge(base.essence_id)
	offer.price = int(t["price"]) + surcharge
	for i in int(t["count"]):
		offer.dice.append(base.instantiate())
	return offer

## EIN Prämien-Würfel (Stresstest): frisch gewürfelt, mit dem
## Gütesiegel wie jedes Angebot veredelt und mit GARANTIERTER Seele - die
## Unikat-/Geheim-Ausschlüsse und der Nicht-Unikat-Rückfall stehen in roll_essence.
## Preis kennt er keinen: er wird gewonnen, nie verkauft.
static func roll_reward_die(charm_ids: Array[String] = [],
		owned_essences: Array[String] = [], tier: int = 1) -> DieDefinition:
	var templates := pick_templates(1)
	if templates.is_empty():
		return null
	var die := make_die(templates[0], tier)
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
static func make_die(t: Dictionary, tier: int = 1) -> DieDefinition:
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
	var factor := tier_face_factor(tier)
	if factor > 1.0:
		for i in faces.size():
			faces[i] = _scaled_face(faces[i], factor)
	def.faces = faces
	def.style_id = t["style_id"]
	def.display_name = t["name"]
	return def

## Eine Seite auf den Stufen-Rahmen heben. Der Faktor gibt den Rahmen, die Streuung
## bricht die runden Zahlen auf; kleiner als vorher wird eine Seite nie.
static func _scaled_face(value: int, factor: float) -> int:
	var grown := float(value) * factor
	return maxi(value, int(round(grown + randf_range(-FACE_JITTER, FACE_JITTER) * grown)))

## Würfelt die Essenz eines Angebots-Würfels aus ("" = essenzlos). Schwarzmarkt-
## Essenzen liegen NIE im normalen Handel; Unikate nur einzeln und nur, solange
## der Spieler keins besitzt (dieselbe Ausschluss-Regel wie bei den Charms).
## guaranteed überspringt den Chancen-Wurf (Prämien-Würfel tragen immer eine
## Seele). Die Unikat-Sperre gilt weiter - läuft der Topf dadurch
## leer, rückt ein NICHT-Unikat nach, statt den Würfel seelenlos zu lassen.
## chance/boost: die Seelen-Regel des Ladens (Seelenmarkt, Seelenlos); boost hebt das
## Gewicht jeder Seele über "häufig".
static func roll_essence(owned_essences: Array[String] = [], allow_unique: bool = true,
		guaranteed: bool = false, chance: float = ESSENCE_CHANCE, boost: float = 1.0) -> String:
	if not guaranteed and randf() >= chance:
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
	var total := 0.0
	for candidate in pool:
		total += _essence_weight(candidate, boost)
	var pick := randf() * total
	for candidate in pool:
		pick -= _essence_weight(candidate, boost)
		if pick < 0.0:
			return candidate.id
	return pool[pool.size() - 1].id

static func _essence_weight(essence: Essence, boost: float) -> float:
	var weight := float(ESSENCE_RARITY_WEIGHTS.get(essence.rarity, 1))
	return weight * boost if essence.rarity != Essence.Rarity.COMMON else weight

# --- WÜRFEL-PAKETE -----------------------------------------------------------------

## Seelen-Chance eines Paket-Würfels: 15 % + 3 Punkte je Glück, Deckel 75 %.
const PACK_SOUL_CHANCE := 0.15
const PACK_SOUL_LUCK_STEP := 0.03
const PACK_SOUL_CAP := 0.75

static func pack_soul_chance(luck: int) -> float:
	return minf(PACK_SOUL_CHANCE + PACK_SOUL_LUCK_STEP * float(maxi(luck, 0)), PACK_SOUL_CAP)

## Die Vorlagen einer Paket-Sorte (leer = alle).
static func pack_templates(pack_sort: String) -> Array[Dictionary]:
	var styles := DicePack.styles_of(pack_sort)
	var out: Array[Dictionary] = []
	for t: Dictionary in TEMPLATES:
		if styles.is_empty() or styles.has(String(t["style_id"])):
			out.append(t)
	return out

## Güte eines Paket-Würfels (Standard/Edel/Royal): Material-Chance, Veredelung je
## Material-Seite, Seelen-Bonus in Punkten.
const QUALITY_MATERIAL_CHANCE := [0.35, 0.55, 0.75]
const QUALITY_DOPE_CHANCE := [0.0, 0.25, 0.5]
const QUALITY_SOUL_BONUS := [0.0, 0.20, 0.40]
## Edel: seltene Seelen doppelt so oft.
const FINE_SOUL_BOOST := 2.0

## EINE Option eines Würfel-Pakets. soul = die Seelen-Regel des Ladens (Seelenmarkt
## setzt die Chance auf 1, Seelenlos auf 0); das Seelen-Paket trägt immer eine, eine
## Seltenheit gehoben. owned_essences wächst mit: ein Unikat kommt je Paket einmal.
## quality: Edel hebt den Augen-Rahmen um eine Stufe, Royal um zwei (siehe Konstanten).
static func roll_pack_die(pack_sort: String, tier: int, charm_ids: Array[String],
		owned_essences: Array[String], soul: Dictionary, luck: int,
		quality: int = DicePack.QUALITY_STANDARD) -> DieDefinition:
	var templates := pack_templates(pack_sort)
	if templates.is_empty():
		return null
	quality = clampi(quality, DicePack.QUALITY_STANDARD, DicePack.QUALITY_ROYAL)
	var die := make_die(templates.pick_random(), tier + quality)
	_roll_quality_refinements(die, quality)
	if pack_sort == DicePack.SORT_MATERIAL:
		_force_material_faces(die, DicePack.MATERIAL_MIN_FACES)
	if quality == DicePack.QUALITY_ROYAL:
		if not has_doped_side(die):
			_force_material_faces(die, 1)
			_dope_one(die)
		if die.runes.count(Rune.NONE) == die.runes.size():
			die.set_rune(randi() % die.runes.size(), Rune.all().pick_random().id)
	if CharmEffects.forces_refinement(charm_ids):
		if die.materials.count("") == die.materials.size():
			die.set_face_material(randi() % die.materials.size(), DieMaterial.all().pick_random().id)
		if not has_doped_side(die):
			for f in die.materials.size():
				if die.dope(f):
					break
	var boost := float(soul.get("boost", 1.0))
	if quality == DicePack.QUALITY_FINE:
		boost *= FINE_SOUL_BOOST
	var lift := 1 if quality == DicePack.QUALITY_ROYAL else 0
	if pack_sort == DicePack.SORT_SOUL:
		die.essence_id = roll_essence_of_rarity(owned_essences, _lifted_rarity(1 + lift, boost))
	else:
		var chance := float(soul.get("chance", pack_soul_chance(luck)))
		# Seelenlos bleibt seelenlos - die Güte hebt nur eine Chance, die es gibt.
		if chance > 0.0:
			chance = minf(chance + float(QUALITY_SOUL_BONUS[quality]), 1.0)
		if lift > 0:
			die.essence_id = roll_essence_of_rarity(owned_essences, _lifted_rarity(lift, boost)) \
				if randf() < chance else ""
		else:
			die.essence_id = roll_essence(owned_essences, true, false, chance, boost)
	var essence := Essence.by_id(die.essence_id)
	if essence != null and essence.unique:
		owned_essences.append(die.essence_id)
	return die

## Material nach Güte: Chance je Güte, jede Material-Seite ggf. veredelt.
static func _roll_quality_refinements(die: DieDefinition, quality: int) -> void:
	if randf() < float(QUALITY_MATERIAL_CHANCE[quality]):
		var face_count := 2 if randf() < SECOND_FACE_CHANCE else 1
		var face_indices := range(6)
		face_indices.shuffle()
		for i in face_count:
			die.set_face_material(face_indices[i], DieMaterial.all().pick_random().id)
	var dope := float(QUALITY_DOPE_CHANCE[quality])
	if dope <= 0.0:
		return
	for f in die.materials.size():
		if die.materials[f] != "" and randf() < dope:
			die.dope(f)

static func _dope_one(die: DieDefinition) -> void:
	var faces := range(die.materials.size())
	faces.shuffle()
	for f in faces:
		if die.dope(f):
			return

## Die Seltenheit einer gehobenen Seele: gewürfelt wie im Laden (boost hebt alles über
## gewöhnlich), dann um lift Stufen höher.
static func _lifted_rarity(lift: int = 1, boost: float = 1.0) -> int:
	var total := 0.0
	for key in ESSENCE_RARITY_WEIGHTS:
		total += _rarity_weight(int(key), boost)
	var pick := randf() * total
	var rarity := int(Essence.Rarity.COMMON)
	for key in ESSENCE_RARITY_WEIGHTS:
		pick -= _rarity_weight(int(key), boost)
		if pick < 0.0:
			rarity = int(key)
			break
	return mini(rarity + lift, int(Essence.Rarity.LEGENDARY))

static func _rarity_weight(rarity: int, boost: float) -> float:
	var weight := float(ESSENCE_RARITY_WEIGHTS[rarity])
	return weight * boost if rarity != int(Essence.Rarity.COMMON) else weight

## Mindestens count Seiten tragen ein Material.
static func _force_material_faces(die: DieDefinition, count: int) -> void:
	var bare: Array[int] = []
	for f in die.materials.size():
		if die.materials[f] == "":
			bare.append(f)
	bare.shuffle()
	var have := die.materials.size() - bare.size()
	while have < count and not bare.is_empty():
		die.set_face_material(bare.pop_back(), DieMaterial.all().pick_random().id)
		have += 1

## Wett-Gewinn: ab diesem Gewinnwert (in $) trägt der Würfel diese Seltenheit.
const BET_SOUL_STEPS := [[32, Essence.Rarity.LEGENDARY], [20, Essence.Rarity.EPIC],
	[12, Essence.Rarity.RARE]]

## Seltenheit der Seele eines Wett-Würfels zum Gewinnwert (-1 = höchstens gewöhnlich).
static func bet_soul_rarity(value: int) -> int:
	for step: Array in BET_SOUL_STEPS:
		if value >= int(step[0]):
			return int(step[1])
	return -1

## EIN Laden-Würfel als Wett-Gewinn: die Seele hängt am Wert. Darunter wie ein
## Laden-Wurf, aber höchstens gewöhnlich.
static func roll_bet_die(value: int, charm_ids: Array[String] = [],
		owned_essences: Array[String] = [], tier: int = 1) -> DieDefinition:
	var templates := pick_templates(1)
	if templates.is_empty():
		return null
	var die := make_die(templates[0], tier)
	roll_refinements(die)
	if CharmEffects.forces_refinement(charm_ids):
		if die.materials.count("") == die.materials.size():
			die.set_face_material(randi() % die.materials.size(), DieMaterial.all().pick_random().id)
		if not has_doped_side(die):
			for f in die.materials.size():
				if die.dope(f):
					break
	var rarity := bet_soul_rarity(value)
	if rarity < 0:
		die.essence_id = roll_essence_of_rarity(owned_essences, Essence.Rarity.COMMON) \
			if randf() < ESSENCE_CHANCE else ""
	else:
		die.essence_id = roll_essence_of_rarity(owned_essences, rarity)
	return die

## Eine handelbare Seele GENAU dieser Seltenheit; ist der Topf leer (Unikate im
## Besitz), eine Seltenheit tiefer.
static func roll_essence_of_rarity(owned_essences: Array[String], rarity: int) -> String:
	for r in range(rarity, -1, -1):
		var pool: Array[Essence] = []
		for essence in Essence.tradeable():
			if int(essence.rarity) != r:
				continue
			if essence.unique and owned_essences.has(essence.id):
				continue
			pool.append(essence)
		if not pool.is_empty():
			return pool.pick_random().id
	return ""

## Preisaufschlag einer Essenz je Würfel (0 ohne Essenz).
static func essence_surcharge(essence_id: String) -> int:
	var essence := Essence.by_id(essence_id)
	return int(ESSENCE_SURCHARGE.get(essence.rarity, 0)) if essence != null else 0
