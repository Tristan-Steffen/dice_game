class_name DicePack
extends Resource
## Ein WÜRFEL-PAKET des Ladens: dieselbe Hülle, dieselben vier Größen und dieselbe
## Wahl-Tabelle wie ein Karten-Paket (CardPack), nur liegen Würfel als Optionen
## darin. Gewürfelt wird der Inhalt in core/ (DiceOffer.roll_pack_die).

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

## Die PREISE, festgeschrieben (test_dice_pack prüft die Formel).
const PRICES := {
	SORT_POWER: [19, 21, 36, 35],
	SORT_SERIES: [12, 13, 22, 22],
	SORT_SOUL: [27, 29, 50, 50],
	SORT_MATERIAL: [21, 22, 38, 38],
	SORT_MIXED: [14, 15, 27, 26],
}

## Auslage-Gewichte der Sorte; die Größe würfelt wie bei den Karten-Paketen.
const SHOP_SORT_WEIGHTS := {SORT_POWER: 6, SORT_SERIES: 6, SORT_SOUL: 3, SORT_MATERIAL: 4,
	SORT_MIXED: 7}

## Material-Paket: so viele Material-Seiten mindestens.
const MATERIAL_MIN_FACES := 2

@export var sort: String = SORT_MIXED
@export var size: int = CardPack.SIZE_NORMAL

static func make(pack_sort: String, pack_size: int) -> DicePack:
	var dice_pack := DicePack.new()
	dice_pack.sort = pack_sort if SORTS.has(pack_sort) else SORT_MIXED
	dice_pack.size = clampi(pack_size, 0, CardPack.SIZE_HUGE)
	return dice_pack

static func price_of(pack_sort: String, pack_size: int) -> int:
	var row: Array = PRICES.get(pack_sort, PRICES[SORT_MIXED])
	return int(row[clampi(pack_size, 0, row.size() - 1)])

var price: int:
	get:
		return price_of(sort, size)

static func sort_name(pack_sort: String) -> String:
	return String(SORT_NAMES.get(pack_sort, SORT_NAMES[SORT_MIXED]))

var display_name: String:
	get:
		return CardPack.sized_name(sort_name(sort), size)

## Die Vorlagen-Kennungen dieser Sorte (leer = alle).
static func styles_of(pack_sort: String) -> Array:
	return SORT_STYLES.get(pack_sort, [])

## Was das Paket von außen sagt - nie die Würfel.
static func info_body(dice_pack: DicePack) -> String:
	if dice_pack == null:
		return ""
	return "%s\n%s" % [_content_line(dice_pack.sort), CardPack.choice_line(dice_pack.size)]

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

static func roll_shop(rng: RandomNumberGenerator = null) -> DicePack:
	var pack_sort := String(CardPack._pick_key(SHOP_SORT_WEIGHTS, rng))
	return make(pack_sort, CardPack._pick_index(CardPack.SHOP_SIZE_WEIGHTS, rng))
