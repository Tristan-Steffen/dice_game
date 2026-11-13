class_name DicePack
extends Resource
## Ein WÜRFEL-PAKET des Ladens: Sorte, Größe und GÜTE, unabhängig gewürfelt. Beim
## Öffnen laufen drei Glücks-Ketten (Würfelzahl, Güte je Würfel, Wahlen), jede mit
## einer Untergrenze aus dem Paket. Den Inhalt würfelt core/ (DiceOffer.roll_pack_die).

const SORT_POWER := "power"
const SORT_SERIES := "series"
const SORT_SOUL := "soul"
const SORT_MATERIAL := "material"
const SORT_MIXED := "mixed"
const SORTS := [SORT_POWER, SORT_SERIES, SORT_SOUL, SORT_MATERIAL, SORT_MIXED]

const SORT_NAMES := {
	SORT_POWER: "Kraft-Paket",
	SORT_SERIES: "Serien-Paket",
	SORT_SOUL: "Seelen-Paket",
	SORT_MATERIAL: "Material-Würfelpaket",
	SORT_MIXED: "Misch-Würfelpaket",
}

## Welche Würfel-Vorlagen (DiceOffer.TEMPLATES, style_id) eine Sorte zieht; leer = jede.
const SORT_STYLES := {
	SORT_POWER: ["power", "pasch"],
	SORT_SERIES: ["even", "odd", "small", "low"],
}

# --- Die GÜTE ----------------------------------------------------------------------

const QUALITY_STANDARD := 0
const QUALITY_FINE := 1
const QUALITY_ROYAL := 2
const QUALITIES := [QUALITY_STANDARD, QUALITY_FINE, QUALITY_ROYAL]
const QUALITY_NAMES := ["Standard", "Edel", "Royal"]
## Anzeige-Farben der Stufen: weiß / gold / violett.
const QUALITY_TINTS := [Color("#f2f2f2"), Color("#ffc84a"), Color("#b77bff")]
const QUALITY_PRICE_FACTORS := [1.0, 1.7, 2.8]
## Laden: Grund-Gewichte Standard/Edel/Royal; je Stufe über 1 wandern +3 Edel, +2 Royal.
const SHOP_QUALITY_WEIGHTS := [65, 27, 8]
const SHOP_QUALITY_SHIFT := [-5, 3, 2]

## Aufstieg eines Würfels über die Paket-Güte: 10 % + 1 Punkt je Glück, Deckel 50 %;
## ein zweiter Aufstieg mit der halben Chance.
const UPGRADE_CHANCE := 0.10
const UPGRADE_LUCK_STEP := 0.01
const UPGRADE_CAP := 0.50

# --- Die WÜRFELZAHL ------------------------------------------------------------------

const BASE_COUNTS := [2, 3, 4, 5]
## Verplombt senkt die Grundzahl nie darunter (eine Wahl braucht zwei Würfel).
const MIN_COUNT := 2
const MAX_COUNT := 10
const MAX_EXTRA_DICE := 5
## Zugabe-Kette: 20 % + 1,5 Punkte je Glück (Deckel 65 %), jeder weitere × 0,6.
const EXTRA_DIE_CHANCE := 0.20
const EXTRA_DIE_LUCK_STEP := 0.015
const EXTRA_DIE_CAP := 0.65
const EXTRA_DIE_DECAY := 0.6

# --- Die WAHLEN ------------------------------------------------------------------------

const BASE_PICKS := [1, 1, 2, 2]
## Wahl-Kette: 20 % + 1 Punkt je Glück (Deckel 60 %), jede weitere mit der halben Chance.
const EXTRA_PICK_CHANCE := 0.20
const EXTRA_PICK_LUCK_STEP := 0.01
const EXTRA_PICK_CAP := 0.60
const EXTRA_PICK_DECAY := 0.5

## Die PREISE der Güte Standard, festgeschrieben (test_pack_choice prüft die Formel).
const PRICES := {
	SORT_POWER: [16, 19, 35, 35],
	SORT_SERIES: [10, 12, 22, 22],
	SORT_SOUL: [23, 27, 49, 50],
	SORT_MATERIAL: [18, 21, 38, 38],
	SORT_MIXED: [12, 14, 26, 26],
}

## Auslage-Gewichte der Sorte; die Größe würfelt wie bei den Karten-Paketen.
const SHOP_SORT_WEIGHTS := {SORT_POWER: 6, SORT_SERIES: 6, SORT_SOUL: 3, SORT_MATERIAL: 4,
	SORT_MIXED: 7}

## Material-Paket: so viele Material-Seiten mindestens.
const MATERIAL_MIN_FACES := 2

@export var sort: String = SORT_MIXED
@export var size: int = CardPack.SIZE_NORMAL
@export var quality: int = QUALITY_STANDARD

static func make(pack_sort: String, pack_size: int, pack_quality: int = QUALITY_STANDARD) -> DicePack:
	var dice_pack := DicePack.new()
	dice_pack.sort = pack_sort if SORTS.has(pack_sort) else SORT_MIXED
	dice_pack.size = clampi(pack_size, 0, CardPack.SIZE_HUGE)
	dice_pack.quality = clampi(pack_quality, QUALITY_STANDARD, QUALITY_ROYAL)
	return dice_pack

static func price_of(pack_sort: String, pack_size: int,
		pack_quality: int = QUALITY_STANDARD) -> int:
	var row: Array = PRICES.get(pack_sort, PRICES[SORT_MIXED])
	var base := float(row[clampi(pack_size, 0, row.size() - 1)])
	return roundi(base * quality_price_factor(pack_quality))

static func quality_price_factor(pack_quality: int) -> float:
	return float(QUALITY_PRICE_FACTORS[clampi(pack_quality, 0, QUALITY_ROYAL)])

var price: int:
	get:
		return price_of(sort, size, quality)

static func sort_name(pack_sort: String) -> String:
	return String(SORT_NAMES.get(pack_sort, SORT_NAMES[SORT_MIXED]))

static func quality_name(pack_quality: int) -> String:
	return String(QUALITY_NAMES[clampi(pack_quality, 0, QUALITY_ROYAL)])

static func quality_tint(pack_quality: int) -> Color:
	return QUALITY_TINTS[clampi(pack_quality, 0, QUALITY_ROYAL)]

## "Großes Kraft-Paket · Edel"; Standard bleibt unmarkiert.
var display_name: String:
	get:
		var base := CardPack.sized_name(sort_name(sort), size)
		return base if quality == QUALITY_STANDARD else "%s · %s" % [base, quality_name(quality)]

## Die Vorlagen-Kennungen dieser Sorte (leer = alle).
static func styles_of(pack_sort: String) -> Array:
	return SORT_STYLES.get(pack_sort, [])

## Was das Paket von außen sagt: Sorte, Untergrenzen und Güte - nie Chancen.
static func info_body(dice_pack: DicePack) -> String:
	if dice_pack == null:
		return ""
	var picks := base_picks(dice_pack.size)
	return "%s\nMindestens %d Würfel · Mindestens %d %s · %s" % [
		_content_line(dice_pack.sort), base_count(dice_pack.size), picks,
		"Wahl" if picks == 1 else "Wahlen", quality_name(dice_pack.quality)]

static func _content_line(pack_sort: String) -> String:
	match pack_sort:
		SORT_POWER:
			return "Kraft- und Paschwürfel."
		SORT_SERIES:
			return "Gerade, Ungerade und Serien."
		SORT_SOUL:
			return "Jeder Würfel beseelt, eine Stufe seltener."
		SORT_MATERIAL:
			return "Je Würfel zwei Material-Seiten."
	return "Würfel jeder Vorlage."

# --- Die drei Ketten ------------------------------------------------------------------

static func base_count(pack_size: int) -> int:
	return int(BASE_COUNTS[clampi(pack_size, 0, BASE_COUNTS.size() - 1)])

static func base_picks(pack_size: int) -> int:
	return int(BASE_PICKS[clampi(pack_size, 0, BASE_PICKS.size() - 1)])

## Chance auf den ERSTEN Zusatz-Würfel; factor = Glücksgriff, der Deckel bleibt.
static func extra_die_chance(luck: int, factor := 1.0) -> float:
	return minf((EXTRA_DIE_CHANCE + EXTRA_DIE_LUCK_STEP * float(maxi(luck, 0))) * factor,
		EXTRA_DIE_CAP)

## Chance auf die ERSTE Zusatz-Wahl.
static func extra_pick_chance(luck: int, factor := 1.0) -> float:
	return minf((EXTRA_PICK_CHANCE + EXTRA_PICK_LUCK_STEP * float(maxi(luck, 0))) * factor,
		EXTRA_PICK_CAP)

## Chance, eine Güte-Stufe aufzusteigen (der zweite Aufstieg: die Hälfte).
static func upgrade_chance(luck: int) -> float:
	return minf(UPGRADE_CHANCE + UPGRADE_LUCK_STEP * float(maxi(luck, 0)), UPGRADE_CAP)

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

## Die Güte EINES Würfels: nie unter der Paket-Güte, nie über Royal.
static func roll_quality(pack_quality: int, luck: int,
		rng: RandomNumberGenerator = null) -> int:
	var result := clampi(pack_quality, QUALITY_STANDARD, QUALITY_ROYAL)
	var chance := upgrade_chance(luck)
	for step in 2:
		if result >= QUALITY_ROYAL or CardPack._unit(rng) >= chance:
			break
		result += 1
		chance *= 0.5
	return result

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

## Erwartete Wahlen bei Glück 0 - daran hängt der Preis.
static func expected_picks(pack_size: int) -> float:
	var base := base_count(pack_size)
	var expected := 0.0
	var reach := 1.0
	var chance := extra_die_chance(0)
	for extras in MAX_EXTRA_DICE + 1:
		var stop := 1.0 if extras == MAX_EXTRA_DICE else 1.0 - chance
		expected += reach * stop * _expected_picks_for(base_picks(pack_size), base + extras)
		reach *= chance
		chance *= EXTRA_DIE_DECAY
	return expected

static func _expected_picks_for(base: int, count: int) -> float:
	var ceiling := max_picks(count)
	var picks := clampi(base, 1, ceiling)
	var expected := 0.0
	var reach := 1.0
	var chance := extra_pick_chance(0)
	while picks < ceiling:
		expected += reach * (1.0 - chance) * float(picks)
		reach *= chance
		chance *= EXTRA_PICK_DECAY
		picks += 1
	return expected + reach * float(picks)

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
	var pack_size := CardPack._pick_index(CardPack.SHOP_SIZE_WEIGHTS, rng)
	var weights := quality_weights if not quality_weights.is_empty() else SHOP_QUALITY_WEIGHTS
	return make(pack_sort, pack_size, CardPack._pick_index(weights, rng))
