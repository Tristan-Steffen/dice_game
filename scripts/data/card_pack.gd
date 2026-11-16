class_name CardPack
extends Resource
## Ein KARTEN-PAKET des Ladens: Sorte, KARTENZAHL (3er/4er/5er = SIZE_SMALL..SIZE_LARGE)
## und GÜTE (dieselbe wie bei Würfel-Paketen). Geöffnet zeigt es OPTIONEN (je eine Karte),
## von denen der Spieler eine Zahl WAHLEN nimmt; die Güte entscheidet die Kartengrößen.
## Die Wahl-Tabelle hier teilen sich Karten- und Modul-Pakete (Modul: alle vier Größen).

const SORT_NUMBER := "number"
const SORT_MATERIAL := "material"
const SORT_RUNE := "rune"
const SORT_MIXED := "mixed"
const SORTS := [SORT_NUMBER, SORT_MATERIAL, SORT_RUNE, SORT_MIXED]

const SORT_NAMES := {
	SORT_NUMBER: "Zahlen-Paket",
	SORT_MATERIAL: "Material-Paket",
	SORT_RUNE: "Runen-Paket",
	SORT_MIXED: "Misch-Paket",
}

## Regal-Paketsorte -> Pack-Typ seiner Karten.
const SORT_TYPES := {
	SORT_NUMBER: Pack.TYPE_NUMBER,
	SORT_MATERIAL: Pack.TYPE_MATERIAL,
	SORT_RUNE: Pack.TYPE_DICE_MOD,
}

const SIZE_SMALL := 0
const SIZE_NORMAL := 1
const SIZE_LARGE := 2
const SIZE_HUGE := 3
const SIZES := [SIZE_SMALL, SIZE_NORMAL, SIZE_LARGE, SIZE_HUGE]

## Karten-Pakete kennen nur die ersten drei Größen: 3er, 4er, 5er.
const CARD_SIZES := [SIZE_SMALL, SIZE_NORMAL, SIZE_LARGE]

## Paketgröße allein (Auskunft) und als Adjektiv vor dem Namen (Modul-Pakete).
const SIZE_LABELS := ["Klein", "Normal", "Groß", "Riesig"]
const SIZE_ADJECTIVES := ["Kleines", "", "Großes", "Riesiges"]

# --- Die WAHL-Tabelle (Karten- und Würfel-Pakete) ---------------------------------

const OPTION_COUNTS := [3, 4, 5, 5]
const BASE_PICKS := [1, 1, 2, 2]
## Glückswurf: so oft gibt es eine Wahl mehr.
const LUCKY_CHANCES := [0.20, 0.30, 0.25, 0.15]
## Hauptgewinn: alle Optionen nehmen (nur Riesig).
const JACKPOT_CHANCES := [0.0, 0.0, 0.0, 0.03]
const LUCK_STEP := 0.01
const LUCKY_CAP := 0.60
const JACKPOT_LUCK_STEP := 0.0025
const JACKPOT_CAP := 0.10
## Kein Paket zeigt weniger Optionen (Verplombt).
const MIN_OPTIONS := 2
## Der Preis zahlt die AUSWAHL mit: erwartete Wahlen × Optionswert × diese Prämie.
const CHOICE_PREMIUM := 1.15

## Kartengrößen (Standard/Groß/Kolossal) je GÜTE.
const QUALITY_TIER_WEIGHTS := [[0.70, 0.25, 0.05], [0.45, 0.40, 0.15], [0.20, 0.45, 0.35]]
## Großauftrag: jede Güte würfelt eine Stufe besser.
const BULK_QUALITY_TIER_WEIGHTS := [[0.45, 0.40, 0.15], [0.20, 0.45, 0.35],
	[0.10, 0.40, 0.50]]
## Garantie unter den Optionen je Güte: so groß ist mindestens eine Karte (-1 = keine).
const QUALITY_GUARANTEE := [-1, Pack.TIER_GROSS, Pack.TIER_KOLOSSAL]
## Hauptgewinn (alle nehmen) je Güte - nur Royal.
const QUALITY_JACKPOT := [0.0, 0.0, 0.03]
## Der Preis zahlt die WAHL mit: je Option über drei ein Stück Prämie mehr.
const OPTION_PREMIUM_STEP := 0.05

## Auslage-Gewichte: Zahlen/Material/Runen wie Pack.SHELF_WEIGHTS (×3), Misch ~25 %.
const SHOP_SORT_WEIGHTS := {SORT_NUMBER: 18, SORT_MATERIAL: 9, SORT_RUNE: 6, SORT_MIXED: 11}
## Die Größen-Gewichte der Modul-Pakete (vier Größen) und der Karten-Pakete (3er/4er/5er).
const SHOP_SIZE_WEIGHTS := [30, 40, 22, 8]
const CARD_SHOP_SIZE_WEIGHTS := [35, 42, 23]
## Misch: so oft eine Sonder-Karte statt einer Regal-Karte.
const MIXED_SPECIAL_CHANCE := 0.15
## Sonder-Karte im Misch-Paket: so oft ein Multiplikator statt eines Sonderpostens.
const SPECIAL_MULTIPLIER_SHARE := 1.0 / 6.0
## So oft wird eine doppelte Karte neu gewürfelt, bevor sie bleibt.
const DUPLICATE_RETRIES := 8

@export var sort: String = SORT_NUMBER
@export var size: int = SIZE_NORMAL
@export var quality: int = DicePack.QUALITY_STANDARD

## Im LAGER: die Identität (GameRun._store_pack stempelt sie) und ob es ein Wett-Gewinn war.
var store_uid: int = 0
var from_bet: bool = false

static func make(pack_sort: String, pack_size: int,
		pack_quality: int = DicePack.QUALITY_STANDARD) -> CardPack:
	var card_pack := CardPack.new()
	card_pack.sort = pack_sort if SORTS.has(pack_sort) else SORT_NUMBER
	card_pack.size = clampi(pack_size, 0, max_size(card_pack.sort))
	card_pack.quality = _quality(pack_quality)
	return card_pack

## Die größte Größe eines Karten-Pakets (5er).
static func max_size(_pack_sort: String = SORT_NUMBER) -> int:
	return CARD_SIZES.size() - 1

static func _quality(pack_quality: int) -> int:
	return clampi(pack_quality, DicePack.QUALITY_STANDARD, DicePack.QUALITY_ROYAL)

## Was EINE Option im Mittel wert ist: Kartengrößen der Güte über den Regalpreis der Sorte.
static func option_value(pack_sort: String, pack_quality: int) -> float:
	var weights: Array = QUALITY_TIER_WEIGHTS[_quality(pack_quality)]
	var base := 0.0
	if SORT_TYPES.has(pack_sort):
		base = float(Pack.type_price(String(SORT_TYPES[pack_sort])))
	else:
		var total := 0.0
		for pack_type: String in Pack.SHELF_WEIGHTS:
			base += float(Pack.SHELF_WEIGHTS[pack_type]) * float(Pack.type_price(pack_type))
			total += float(Pack.SHELF_WEIGHTS[pack_type])
		base /= total
	var value := 0.0
	for tier in weights.size():
		value += float(weights[tier]) * base * Pack.tier_price_factor(tier)
	return value

## Der EINE Preis (vor Rabatten): erwartete Wahlen × Optionswert × Prämie der Optionen.
static func price_of(pack_sort: String, pack_size: int,
		pack_quality: int = DicePack.QUALITY_STANDARD) -> int:
	var at := clampi(pack_size, 0, max_size())
	var premium := CHOICE_PREMIUM + OPTION_PREMIUM_STEP * float(option_count(at) - OPTION_COUNTS[0])
	var picks := expected_picks(at, quality_jackpot(pack_quality))
	return maxi(roundi(picks * option_value(pack_sort, pack_quality) * premium), 1)

var price: int:
	get:
		return price_of(sort, size, quality)

static func quality_jackpot(pack_quality: int) -> float:
	return float(QUALITY_JACKPOT[_quality(pack_quality)])

## Das Glück, das die Güte beim Öffnen auf effective_luck legt - dieselbe Zahl wie beim Würfel-Paket.
static func quality_luck(pack_quality: int) -> int:
	return DicePack.quality_luck(pack_quality)

func guaranteed_tier() -> int:
	return int(QUALITY_GUARANTEE[_quality(quality)])

static func sort_name(pack_sort: String) -> String:
	return String(SORT_NAMES.get(pack_sort, SORT_NAMES[SORT_NUMBER]))

static func size_label(pack_size: int) -> String:
	return String(SIZE_LABELS[clampi(pack_size, 0, SIZE_LABELS.size() - 1)])

## "4er Zahlen-Paket · Edel"; Standard bleibt unmarkiert.
var display_name: String:
	get:
		var base := "%der %s" % [option_count(size), sort_name(sort)]
		return base if quality == DicePack.QUALITY_STANDARD \
			else "%s · %s" % [base, DicePack.quality_name(quality)]

## Modul-Pakete: "Großes Modul-Paket".
static func sized_name(base: String, pack_size: int) -> String:
	var adjective := String(SIZE_ADJECTIVES[clampi(pack_size, 0, SIZE_ADJECTIVES.size() - 1)])
	return base if adjective == "" else "%s %s" % [adjective, base]

## Was das Paket von außen sagt: Inhalt, Wahlen, Garantie und Glück - nie die Karten.
static func info_body(card_pack: CardPack) -> String:
	if card_pack == null:
		return ""
	var line := choice_line(card_pack.size)
	match card_pack.guaranteed_tier():
		Pack.TIER_GROSS:
			line += " Mindestens eine Große."
		Pack.TIER_KOLOSSAL:
			line += " Mindestens eine Kolossale."
	var luck := quality_luck(card_pack.quality)
	if luck > 0:
		line += " +%d Glück." % luck
	return "%s\n%s" % [_content_line(card_pack.sort), line]

static func _content_line(pack_sort: String) -> String:
	match pack_sort:
		SORT_MATERIAL:
			return "Nur Material-Karten."
		SORT_RUNE:
			return "Nur Runen-Karten."
		SORT_MIXED:
			return "Karten aller Sorten gemischt."
	return "Zahlen-Karten, manchmal ein Multiplikator."

# --- Die WAHL ----------------------------------------------------------------------

static func option_count(pack_size: int) -> int:
	return int(OPTION_COUNTS[clampi(pack_size, 0, OPTION_COUNTS.size() - 1)])

static func base_picks(pack_size: int) -> int:
	return int(BASE_PICKS[clampi(pack_size, 0, BASE_PICKS.size() - 1)])

## "1 von 3 - mit Glück mehr." (die Auskunft jedes Pakets).
static func choice_line(pack_size: int) -> String:
	return "%d von %d - mit Glück mehr." % [base_picks(pack_size), option_count(pack_size)]

## Glückswurf-Chance: +1 Punkt je Glück, gedeckelt; factor = Glücksgriff.
static func lucky_chance(pack_size: int, luck: int, factor := 1.0) -> float:
	var base := float(LUCKY_CHANCES[clampi(pack_size, 0, LUCKY_CHANCES.size() - 1)])
	return minf((base + LUCK_STEP * float(maxi(luck, 0))) * factor, LUCKY_CAP)

## Hauptgewinn-Chance: nur wo die Tabelle einen kennt; base_chance >= 0 ersetzt sie (Güte).
static func jackpot_chance(pack_size: int, luck: int, factor := 1.0,
		base_chance := -1.0) -> float:
	var base := base_chance if base_chance >= 0.0 \
		else float(JACKPOT_CHANCES[clampi(pack_size, 0, JACKPOT_CHANCES.size() - 1)])
	if base <= 0.0:
		return 0.0
	return minf((base + JACKPOT_LUCK_STEP * float(maxi(luck, 0))) * factor, JACKPOT_CAP)

## Würfelt die Wahlen: {"picks": n, "jackpot": bool} - der Hauptgewinn heißt "alle".
static func roll_picks(pack_size: int, luck: int, factor := 1.0,
		rng: RandomNumberGenerator = null, jackpot_base := -1.0) -> Dictionary:
	if _unit(rng) < jackpot_chance(pack_size, luck, factor, jackpot_base):
		return {"picks": option_count(pack_size), "jackpot": true}
	var picks := base_picks(pack_size)
	if _unit(rng) < lucky_chance(pack_size, luck, factor):
		picks += 1
	return {"picks": picks, "jackpot": false}

## Erwartete Wahlen ohne Glück - daran hängt der Preis.
static func expected_picks(pack_size: int, jackpot_base := -1.0) -> float:
	var options := float(option_count(pack_size))
	var jackpot := jackpot_chance(pack_size, 0, 1.0, jackpot_base)
	var plain := float(base_picks(pack_size)) + lucky_chance(pack_size, 0)
	return jackpot * options + (1.0 - jackpot) * plain

## Die Zahl der Optionen nach den Zu- und Abschlägen: nie unter den Wahlen und nie
## unter MIN_OPTIONS.
static func options_after(pack_size: int, delta: int, picks: int) -> int:
	return maxi(option_count(pack_size) + delta, maxi(picks, MIN_OPTIONS))

# --- Die Auslage ------------------------------------------------------------------

## Ein Paket für einen Laden-Platz: Sorte, Kartenzahl und Güte nach den Auslage-Gewichten;
## quality_weights leer = die Güte-Gewichte der Stufe 1 (dieselben wie bei Würfel-Paketen).
static func roll_shop(rng: RandomNumberGenerator = null, quality_weights: Array = []) -> CardPack:
	var pack_sort := String(_pick_key(SHOP_SORT_WEIGHTS, rng))
	var pack_size := _pick_index(CARD_SHOP_SIZE_WEIGHTS, rng)
	var weights := quality_weights if not quality_weights.is_empty() \
		else DicePack.SHOP_QUALITY_WEIGHTS
	return make(pack_sort, pack_size, _pick_index(weights, rng))

# --- Der Inhalt -------------------------------------------------------------------

## Würfelt count OPTIONEN (ohne count: die Optionen der Kartenzahl) nach Sorte und Güte,
## mit Garantie und ohne doppeltes Netz. Nie Reparatur-Karte, nie Rohling.
static func roll_contents(card_pack: CardPack, multiplier_chance := 0.0, bulk := false,
		rng: RandomNumberGenerator = null, count := -1) -> Array[Pack]:
	var cards: Array[Pack] = []
	if card_pack == null:
		return cards
	if count < 0:
		count = option_count(card_pack.size)
	if count <= 0:
		return cards
	var weights: Array = (BULK_QUALITY_TIER_WEIGHTS if bulk else QUALITY_TIER_WEIGHTS)[
		_quality(card_pack.quality)]
	var tiers: Array[int] = []
	for i in count:
		tiers.append(Pack.roll_tier(rng, weights))
	var guarantee := card_pack.guaranteed_tier()
	if guarantee >= 0 and tiers.max() < guarantee:
		tiers[_roll_unit_index(count, rng)] = guarantee
	var seen := {}
	for i in count:
		cards.append(_roll_unique(card_pack.sort, tiers[i], multiplier_chance, rng, seen))
	# Die Garantie trägt nur eine Karte MIT Größe - sonst übernimmt eine Regal-Karte.
	if guarantee >= 0 and not _meets(cards, guarantee):
		cards[count - 1] = _tiered_card(_regular_type(card_pack.sort, rng), guarantee,
			multiplier_chance, rng)
	return cards

static func _meets(cards: Array[Pack], tier: int) -> bool:
	for card in cards:
		if card.tier >= tier:
			return true
	return false

static func _roll_unique(pack_sort: String, tier: int, multiplier_chance: float,
		rng: RandomNumberGenerator, seen: Dictionary) -> Pack:
	var card: Pack = null
	for attempt in DUPLICATE_RETRIES:
		card = _roll_card(pack_sort, tier, multiplier_chance, rng)
		if not seen.has(content_key(card)):
			break
	seen[content_key(card)] = true
	return card

## Der Inhalts-Schlüssel einer Karte: zwei Karten mit gleichem gelten als Dublette.
static func content_key(card: Pack) -> String:
	var fixed := card.fixed_engraving.id if card.fixed_engraving != null else ""
	return "%s|%s|%s|%s|%s" % [card.type, card.catalyst_id, card.operator_id, fixed,
		var_to_str(card.stamp_net)]

static func _roll_card(pack_sort: String, tier: int, multiplier_chance: float,
		rng: RandomNumberGenerator) -> Pack:
	if pack_sort == SORT_MIXED:
		if _unit(rng) < MIXED_SPECIAL_CHANCE:
			return _special_card(tier, rng)
		return _tiered_card(_regular_type(pack_sort, rng), tier, multiplier_chance, rng)
	return _tiered_card(String(SORT_TYPES.get(pack_sort, Pack.TYPE_NUMBER)), tier,
		multiplier_chance, rng)

## Eine Regal-Karte dieses Typs in dieser Größe (Zahlen ggf. als Multiplikator).
static func _tiered_card(pack_type: String, tier: int, multiplier_chance: float,
		rng: RandomNumberGenerator) -> Pack:
	var base: Pack
	match pack_type:
		Pack.TYPE_MATERIAL:
			base = Pack.material_pack(rng)
		Pack.TYPE_DICE_MOD:
			base = Pack.dice_mod_pack(rng)
		_:
			base = Pack.multiplier_pack(rng) if multiplier_chance > 0.0 \
				and _unit(rng) < multiplier_chance else Pack.number_pack(rng)
	return Pack.tiered(base, tier, rng)

## Sonderbestand: Sonderposten, Katalysatoren, Operatoren - oder ein Multiplikator.
static func _special_card(tier: int, rng: RandomNumberGenerator) -> Pack:
	if _unit(rng) < SPECIAL_MULTIPLIER_SHARE:
		return Pack.tiered(Pack.multiplier_pack(rng), tier, rng)
	return Pack.roll_special_pack()

## Misch: die Sorte nach Regal-Gewicht; jede andere Sorte nennt ihren eigenen Typ.
static func _regular_type(pack_sort: String, rng: RandomNumberGenerator) -> String:
	if SORT_TYPES.has(pack_sort):
		return String(SORT_TYPES[pack_sort])
	return String(_pick_key(Pack.SHELF_WEIGHTS, rng))

# --- Würfel-Helfer ------------------------------------------------------------------

static func _unit(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()

static func _roll_unit_index(count: int, rng: RandomNumberGenerator) -> int:
	return mini(int(_unit(rng) * count), count - 1)

static func _pick_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight in weights:
		total += float(weight)
	var roll := _unit(rng) * total
	for i in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			return i
	return weights.size() - 1

static func _pick_key(weights: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var keys := weights.keys()
	keys.sort()  # feste Reihenfolge - der Wurf hängt sonst an der Dictionary-Laune
	var values: Array = []
	for key in keys:
		values.append(weights[key])
	return keys[_pick_index(values, rng)]
