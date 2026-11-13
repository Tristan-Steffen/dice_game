class_name ModulePack
extends Resource
## Ein MODUL-PAKET des Ladens: ein silberner ESD-Beutel, von außen nur Größe und
## SELTENHEITS-STUFE (die Farbe des Streifens unter der Siegelnaht). Geöffnet zeigt es
## Laden-Module als OPTIONEN; Optionen und Wahlen folgen der Tabelle von CardPack.

const GRADE_COMMON := 0
const GRADE_RARE := 1
const GRADE_EPIC := 2
const GRADE_LEGENDARY := 3
const GRADES := [GRADE_COMMON, GRADE_RARE, GRADE_EPIC, GRADE_LEGENDARY]
## Die Stufe trägt den Namen und die Farbe der Modul-Seltenheit gleichen Rangs.
const GRADE_RARITIES := [ComboPart.RARITY_COMMON, ComboPart.RARITY_RARE,
	ComboPart.RARITY_EPIC, ComboPart.RARITY_LEGENDARY]
const GRADE_NAMES := ["Gewöhnlich", "Selten", "Episch", "Legendär"]

## Je Stufe die Gewichte der Modul-Seltenheiten (gewöhnlich, selten, episch, legendär).
const GRADE_WEIGHTS := [[1.0, 0.45, 0.2, 0.08], [0.6, 0.8, 0.35, 0.15],
	[0.3, 0.7, 0.8, 0.3], [0.15, 0.5, 1.0, 0.6]]
## Die Stufe hebt den Preis wie die Güte das Würfel-Paket.
const GRADE_PRICE_FACTORS := [1.0, 1.4, 1.9, 2.6]
## Grundpreis je Größe (Gewöhnlich): erwartete Wahlen × Modulwert × CardPack.CHOICE_PREMIUM.
const PRICES := [11, 12, 21, 21]
## Der mittlere Laden-Modulpreis, an dem PRICES hängt (test_module_pack prüft die Formel).
const OPTION_VALUE := 8.0

## Laden: Gewichte der Stufen; je Fortschrittsstufe über 1 wandern sie nach oben.
const SHOP_GRADE_WEIGHTS := [70, 22, 7, 1]
const SHOP_GRADE_SHIFT := [-5, 2, 2, 1]
const SHOP_SIZE_WEIGHTS := CardPack.SHOP_SIZE_WEIGHTS

@export var size: int = CardPack.SIZE_NORMAL
@export var grade: int = GRADE_COMMON

## Im LAGER: Identität, Herkunft und Platz (GameRun._store_pack stempelt sie).
var store_uid: int = 0
var from_bet: bool = false
var store_slot: int = 0

static func make(pack_size: int, pack_grade: int) -> ModulePack:
	var module_pack := ModulePack.new()
	module_pack.size = clampi(pack_size, 0, CardPack.SIZES.size() - 1)
	module_pack.grade = clampi(pack_grade, GRADE_COMMON, GRADE_LEGENDARY)
	return module_pack

static func price_of(pack_size: int, pack_grade: int) -> int:
	var base := float(PRICES[clampi(pack_size, 0, PRICES.size() - 1)])
	return roundi(base * float(GRADE_PRICE_FACTORS[clampi(pack_grade, 0, GRADES.size() - 1)]))

var price: int:
	get:
		return price_of(size, grade)

static func grade_name(pack_grade: int) -> String:
	return String(GRADE_NAMES[clampi(pack_grade, 0, GRADE_NAMES.size() - 1)])

static func grade_rarity(pack_grade: int) -> String:
	return String(GRADE_RARITIES[clampi(pack_grade, 0, GRADE_RARITIES.size() - 1)])

## Die Farbe der Stufe - dieselbe wie die der Modul-Seltenheit.
static func grade_tint(pack_grade: int) -> Color:
	return ComboPart.RARITY_COLORS[grade_rarity(pack_grade)]

## "Großes Modul-Paket · Selten" (Gewöhnlich unmarkiert).
var display_name: String:
	get:
		var base := CardPack.sized_name("Modul-Paket", size)
		return base if grade == GRADE_COMMON else "%s · %s" % [base, grade_name(grade)]

## Was der Beutel von außen sagt: Optionen, Wahlen und Stufe - nie die Module.
static func info_body(module_pack: ModulePack) -> String:
	if module_pack == null:
		return ""
	return "Module für die Steckplätze.\n%s · %s" % [CardPack.choice_line(module_pack.size),
		grade_name(module_pack.grade)]

## Der Preis zahlt die Auswahl mit - dieselbe Formel wie bei den Karten-Paketen.
static func formula_price(pack_size: int) -> float:
	return CardPack.expected_picks(pack_size) * OPTION_VALUE * CardPack.CHOICE_PREMIUM

# --- Die Auslage ------------------------------------------------------------------

static func shop_grade_weights(tier: int) -> Array:
	var steps := maxi(tier - 1, 0)
	var out: Array = []
	for i in SHOP_GRADE_WEIGHTS.size():
		out.append(maxi(int(SHOP_GRADE_WEIGHTS[i]) + int(SHOP_GRADE_SHIFT[i]) * steps, 0))
	return out

## grade_weights leer = die Gewichte der Stufe 1.
static func roll_shop(rng: RandomNumberGenerator = null, grade_weights: Array = []) -> ModulePack:
	var weights := grade_weights if not grade_weights.is_empty() else SHOP_GRADE_WEIGHTS
	return make(CardPack._pick_index(SHOP_SIZE_WEIGHTS, rng), CardPack._pick_index(weights, rng))

# --- Der Inhalt -------------------------------------------------------------------

## Das Gewicht eines Moduls in einem Paket dieser Stufe.
static func weight_of(part: ComboPart, pack_grade: int) -> float:
	var row: Array = GRADE_WEIGHTS[clampi(pack_grade, 0, GRADE_WEIGHTS.size() - 1)]
	var rank := GRADE_RARITIES.find(part.rarity)
	return float(row[clampi(rank, 0, row.size() - 1)])

## Würfelt count OPTIONEN aus den Laden-Modulen, ohne Dublette (gehen die Teile aus,
## darf eines doppelt liegen - ein leerer Platz wäre schlimmer). Jede Option ist eine
## EIGENE Instanz.
static func roll_contents(module_pack: ModulePack, count := -1,
		rng: RandomNumberGenerator = null) -> Array[ComboPart]:
	var out: Array[ComboPart] = []
	if module_pack == null:
		return out
	if count < 0:
		count = CardPack.option_count(module_pack.size)
	var pool := ComboPart.pool(false)
	var left := pool.duplicate()
	for i in count:
		if left.is_empty():
			left = pool.duplicate()
		var pick := _pick(left, module_pack.grade, rng)
		left.erase(pick)
		out.append(pick.instantiate())
	return out

static func _pick(candidates: Array[ComboPart], pack_grade: int,
		rng: RandomNumberGenerator) -> ComboPart:
	var total := 0.0
	for part in candidates:
		total += weight_of(part, pack_grade)
	var roll := CardPack._unit(rng) * total
	for part in candidates:
		roll -= weight_of(part, pack_grade)
		if roll < 0.0:
			return part
	return candidates[candidates.size() - 1]
