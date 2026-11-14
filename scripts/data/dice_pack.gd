class_name DicePack
extends Resource
## Ein WÜRFEL-PAKET des Ladens: Sorte, AUGEN (2..6 = die Grund-Würfelzahl) und GÜTE,
## unabhängig gewürfelt. Die Güte ist GLÜCK fürs Paket; beim Öffnen laufen zwei Glücks-Ketten
## (Würfelzahl, Wahlen), jede mit einer Untergrenze aus dem Paket. Den Inhalt würfelt core/ (DiceOffer.roll_pack_die).

const SORT_NORMAL := "normal"
const SORT_SOUL := "soul"
const SORT_MATERIAL := "material"
const SORT_RUNE := "rune"
const SORTS := [SORT_NORMAL, SORT_SOUL, SORT_MATERIAL, SORT_RUNE]

const SORT_NAMES := {
	SORT_NORMAL: "Würfel-Paket",
	SORT_SOUL: "Seelen-Paket",
	SORT_MATERIAL: "Material-Würfelpaket",
	SORT_RUNE: "Runen-Würfelpaket",
}

## size IST die Augenzahl der Würfelseite und die Grund-Würfelzahl (2..6) - keine CardPack-Größe.
const SIZES := [2, 3, 4, 5, 6]

# --- Die GÜTE ----------------------------------------------------------------------

const QUALITY_STANDARD := 0
const QUALITY_FINE := 1
const QUALITY_ROYAL := 2
const QUALITIES := [QUALITY_STANDARD, QUALITY_FINE, QUALITY_ROYAL]
const QUALITY_NAMES := ["Standard", "Edel", "Royal"]
## Glück, das die Güte beim Öffnen auf effective_luck legt (nie auf shop_tier).
const QUALITY_LUCK := [0, 6, 12]
const QUALITY_PRICE_FACTORS := [1.0, 1.7, 2.8]
## Laden: Grund-Gewichte Standard/Edel/Royal; je Stufe über 1 wandern +3 Edel, +2 Royal.
const SHOP_QUALITY_WEIGHTS := [65, 27, 8]
const SHOP_QUALITY_SHIFT := [-5, 3, 2]

# --- Die WÜRFELZAHL ------------------------------------------------------------------

## Verplombt senkt die Grundzahl nie darunter (eine Wahl braucht zwei Würfel).
const MIN_COUNT := 2
## Nie mehr als sechs Würfel - auch die Zugabe-Kette füllt höchstens bis hierher auf.
const MAX_COUNT := 6
const MAX_EXTRA_DICE := 5
## Zugabe-Kette: 20 % + 1,5 Punkte je Glück (Deckel 65 %), jeder weitere × 0,6.
const EXTRA_DIE_CHANCE := 0.20
const EXTRA_DIE_LUCK_STEP := 0.015
const EXTRA_DIE_CAP := 0.65
const EXTRA_DIE_DECAY := 0.6

# --- Die WAHLEN ------------------------------------------------------------------------

## Index = Augen - MIN_COUNT.
const BASE_PICKS := [1, 1, 1, 2, 2]
## Wahl-Kette: 20 % + 1 Punkt je Glück (Deckel 60 %), jede weitere mit der halben Chance.
const EXTRA_PICK_CHANCE := 0.20
const EXTRA_PICK_LUCK_STEP := 0.01
const EXTRA_PICK_CAP := 0.60
const EXTRA_PICK_DECAY := 0.5

## Die PREISE der Güte Standard je Augenzahl 2..6.
const PRICES := {
	SORT_NORMAL: [10, 14, 20, 26, 32],
	SORT_SOUL: [20, 27, 38, 50, 60],
	SORT_MATERIAL: [15, 21, 30, 38, 46],
	SORT_RUNE: [15, 21, 30, 38, 46],
}

## Auslage-Gewichte der Sorte und der Augenzahl 2..6.
const SHOP_SORT_WEIGHTS := {SORT_NORMAL: 50, SORT_MATERIAL: 20, SORT_SOUL: 15, SORT_RUNE: 15}
const SHOP_SIZE_WEIGHTS := [20, 35, 25, 13, 7]

## Material-Paket: so viele Material-Seiten mindestens.
const MATERIAL_MIN_FACES := 2

@export var sort: String = SORT_NORMAL
@export var size: int = 3
@export var quality: int = QUALITY_STANDARD

## Im LAGER: die Identität (GameRun._store_pack stempelt sie) und ob es ein Wett-Gewinn war.
var store_uid: int = 0
var from_bet: bool = false

static func make(pack_sort: String, pack_size: int, pack_quality: int = QUALITY_STANDARD) -> DicePack:
	var dice_pack := DicePack.new()
	dice_pack.sort = pack_sort if SORTS.has(pack_sort) else SORT_NORMAL
	dice_pack.size = clampi(pack_size, MIN_COUNT, MAX_COUNT)
	dice_pack.quality = clampi(pack_quality, QUALITY_STANDARD, QUALITY_ROYAL)
	return dice_pack

static func price_of(pack_sort: String, pack_size: int,
		pack_quality: int = QUALITY_STANDARD) -> int:
	var row: Array = PRICES.get(pack_sort, PRICES[SORT_NORMAL])
	var base := float(row[clampi(pack_size - MIN_COUNT, 0, row.size() - 1)])
	return roundi(base * quality_price_factor(pack_quality))

static func quality_price_factor(pack_quality: int) -> float:
	return float(QUALITY_PRICE_FACTORS[clampi(pack_quality, 0, QUALITY_ROYAL)])

static func quality_luck(pack_quality: int) -> int:
	return int(QUALITY_LUCK[clampi(pack_quality, 0, QUALITY_ROYAL)])

var price: int:
	get:
		return price_of(sort, size, quality)

static func sort_name(pack_sort: String) -> String:
	return String(SORT_NAMES.get(pack_sort, SORT_NAMES[SORT_NORMAL]))

static func quality_name(pack_quality: int) -> String:
	return String(QUALITY_NAMES[clampi(pack_quality, 0, QUALITY_ROYAL)])

## "4er Seelen-Paket · Edel"; Standard bleibt unmarkiert.
var display_name: String:
	get:
		var base := "%der %s" % [size, sort_name(sort)]
		return base if quality == QUALITY_STANDARD else "%s · %s" % [base, quality_name(quality)]

## Was das Paket von außen sagt: Sorte, Untergrenzen und das Glück der Güte - nie Chancen.
static func info_body(dice_pack: DicePack) -> String:
	if dice_pack == null:
		return ""
	var picks := base_picks(dice_pack.size)
	var line := "Mindestens %d Würfel · Mindestens %d %s" % [base_count(dice_pack.size), picks,
		"Wahl" if picks == 1 else "Wahlen"]
	var luck := quality_luck(dice_pack.quality)
	if luck > 0:
		line += " · +%d Glück" % luck
	return "%s\n%s" % [_content_line(dice_pack.sort), line]

static func _content_line(pack_sort: String) -> String:
	match pack_sort:
		SORT_SOUL:
			return "Jeder Würfel beseelt, eine Stufe seltener."
		SORT_MATERIAL:
			return "Je Würfel mindestens zwei Material-Seiten."
		SORT_RUNE:
			return "Je Würfel mindestens eine Rune."
	return "Würfel jeder Vorlage."

# --- Die zwei Ketten ------------------------------------------------------------------

static func base_count(pack_size: int) -> int:
	return clampi(pack_size, MIN_COUNT, MAX_COUNT)

static func base_picks(pack_size: int) -> int:
	return int(BASE_PICKS[clampi(pack_size - MIN_COUNT, 0, BASE_PICKS.size() - 1)])

## Chance auf den ERSTEN Zusatz-Würfel; factor = Glücksgriff, der Deckel bleibt.
static func extra_die_chance(luck: int, factor := 1.0) -> float:
	return minf((EXTRA_DIE_CHANCE + EXTRA_DIE_LUCK_STEP * float(maxi(luck, 0))) * factor,
		EXTRA_DIE_CAP)

## Chance auf die ERSTE Zusatz-Wahl.
static func extra_pick_chance(luck: int, factor := 1.0) -> float:
	return minf((EXTRA_PICK_CHANCE + EXTRA_PICK_LUCK_STEP * float(maxi(luck, 0))) * factor,
		EXTRA_PICK_CAP)

## Die Würfelzahl: Grundzahl (schon samt Zu-/Abschlägen) plus die Zugabe-Kette.
static func roll_count(base: int, luck: int, factor := 1.0,
		rng: RandomNumberGenerator = null) -> int:
	var count := clampi(base, MIN_COUNT, MAX_COUNT)
	var chance := extra_die_chance(luck, factor)
	var extras := 0
	while extras < MAX_EXTRA_DICE and count < MAX_COUNT and CardPack._unit(rng) < chance:
		count += 1
		extras += 1
		chance *= EXTRA_DIE_DECAY
	return count

## Die Wahlen: Grundzahl plus Wahl-Kette, HART zwischen 1 und count - 1.
static func roll_picks(base: int, luck: int, count: int, factor := 1.0,
		rng: RandomNumberGenerator = null) -> int:
	var ceiling := max_picks(count)
	var picks := clampi(base, 1, ceiling)
	var chance := extra_pick_chance(luck, factor)
	while picks < ceiling and CardPack._unit(rng) < chance:
		picks += 1
		chance *= EXTRA_PICK_DECAY
	return picks

static func max_picks(count: int) -> int:
	return maxi(count - 1, 1)

# --- Die Auslage ------------------------------------------------------------------------

## Güte-Gewichte des Ladens auf dieser Stufe.
static func shop_quality_weights(tier: int) -> Array:
	var steps := maxi(tier - 1, 0)
	var out: Array = []
	for i in SHOP_QUALITY_WEIGHTS.size():
		out.append(maxi(int(SHOP_QUALITY_WEIGHTS[i]) + int(SHOP_QUALITY_SHIFT[i]) * steps, 0))
	return out

## quality_weights leer = die Gewichte der Stufe 1.
static func roll_shop(rng: RandomNumberGenerator = null, quality_weights: Array = []) -> DicePack:
	var pack_sort := String(CardPack._pick_key(SHOP_SORT_WEIGHTS, rng))
	var pack_size := int(SIZES[CardPack._pick_index(SHOP_SIZE_WEIGHTS, rng)])
	var weights := quality_weights if not quality_weights.is_empty() else SHOP_QUALITY_WEIGHTS
	return make(pack_sort, pack_size, CardPack._pick_index(weights, rng))
