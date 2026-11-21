class_name CardPack
extends Resource
## Ein KARTEN-PAKET des Ladens: Sorte, KARTENZAHL (3er/4er/5er = SIZE_SMALL..SIZE_LARGE)
## und GÜTE (dieselbe wie bei Würfel-Paketen). Geöffnet zeigt es OPTIONEN (je eine Karte),
## von denen der Spieler eine Zahl WAHLEN nimmt; die Güte entscheidet die Kartengrößen.
## Je Kartensorte EIN Paket (seit dem 2026-11-20, das Misch-Paket ist gestorben), und die
## vorderste Karte (front) liegt sichtbar darin: sie ist IMMER Option 0, genau so.
## Die Options-Tabelle hier teilen sich Karten- und Modul-Pakete (Modul: alle vier Größen);
## wie viele Wahlen es gibt, sagt der GLÜCKSWÜRFEL (GameRun.luck_die).

const SORT_NUMBER := "number"
const SORT_MATERIAL := "material"
const SORT_RUNE := "rune"
const SORT_SPECIAL := "special"
const SORTS := [SORT_NUMBER, SORT_MATERIAL, SORT_RUNE, SORT_SPECIAL]

const SORT_NAMES := {
	SORT_NUMBER: "Zahlen-Paket",
	SORT_MATERIAL: "Material-Paket",
	SORT_RUNE: "Runen-Paket",
	SORT_SPECIAL: "Sonder-Paket",
}

## Regal-Paketsorte -> Pack-Typ seiner Karten (das Sonder-Paket würfelt den Sonderbestand).
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

# --- Die OPTIONS-Tabelle (Karten- und Modul-Pakete) --------------------------------

const OPTION_COUNTS := [3, 4, 5, 5]
## Kein Paket zeigt weniger Optionen (Verplombt).
const MIN_OPTIONS := 2
## Der Preis zahlt die AUSWAHL mit: Preis-Wahlen × Optionswert × diese Prämie.
const CHOICE_PREMIUM := 1.15
## Eingefroren (2026-11-21): die erwarteten Wahlen der alten Wahl-Formel je Größe und Güte -
## daran hängen die Preise Zahl für Zahl, bis das Balancing sie neu setzt.
const PRICE_PICKS := [[1.2, 1.2, 1.254], [1.3, 1.3, 1.381], [2.25, 2.25, 2.3325]]

## Kartengrößen (Standard/Groß/Kolossal) je GÜTE.
const QUALITY_TIER_WEIGHTS := [[0.70, 0.25, 0.05], [0.45, 0.40, 0.15], [0.20, 0.45, 0.35]]
## Großauftrag: jede Güte würfelt eine Stufe besser.
const BULK_QUALITY_TIER_WEIGHTS := [[0.45, 0.40, 0.15], [0.20, 0.45, 0.35],
	[0.10, 0.40, 0.50]]
## Garantie unter den Optionen je Güte: so groß ist mindestens eine Karte (-1 = keine).
const QUALITY_GUARANTEE := [-1, Pack.TIER_GROSS, Pack.TIER_KOLOSSAL]
## Preisfaktor der Güte im Sonder-Paket (seine Karten haben keine Größe).
const SPECIAL_QUALITY_FACTORS := [1.0, 1.2, 1.45]
## Der Preis zahlt die WAHL mit: je Option über drei ein Stück Prämie mehr.
const OPTION_PREMIUM_STEP := 0.05

## Auslage-Gewichte: Zahlen/Material/Runen wie Pack.SHELF_WEIGHTS (×3), Sonder selten.
const SHOP_SORT_WEIGHTS := {SORT_NUMBER: 18, SORT_MATERIAL: 9, SORT_RUNE: 6, SORT_SPECIAL: 4}
## Die Größen-Gewichte der Modul-Pakete (vier Größen) und der Karten-Pakete (3er/4er/5er).
const SHOP_SIZE_WEIGHTS := [30, 40, 22, 8]
const CARD_SHOP_SIZE_WEIGHTS := [35, 42, 23]
## So oft wird eine doppelte Karte neu gewürfelt, bevor sie bleibt.
const DUPLICATE_RETRIES := 8

@export var sort: String = SORT_NUMBER
@export var size: int = SIZE_NORMAL
@export var quality: int = DicePack.QUALITY_STANDARD
## Die VORDERSTE Karte: sie liegt sichtbar im Paket und ist beim Öffnen Option 0.
@export var front: Pack

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
	# Sonder-Karten kennen keine Größe: die Güte zahlt dort nur ihr Glück.
	if not SORT_TYPES.has(pack_sort):
		return float(Pack.SPECIAL_PRICE) * float(SPECIAL_QUALITY_FACTORS[_quality(pack_quality)])
	var base := float(Pack.type_price(String(SORT_TYPES[pack_sort])))
	var value := 0.0
	for tier in weights.size():
		value += float(weights[tier]) * base * Pack.tier_price_factor(tier)
	return value

## Der EINE Preis (vor Rabatten): Preis-Wahlen × Optionswert × Prämie der Optionen.
static func price_of(pack_sort: String, pack_size: int,
		pack_quality: int = DicePack.QUALITY_STANDARD) -> int:
	var at := clampi(pack_size, 0, max_size())
	var premium := CHOICE_PREMIUM + OPTION_PREMIUM_STEP * float(option_count(at) - OPTION_COUNTS[0])
	var picks := float(PRICE_PICKS[at][_quality(pack_quality)])
	return maxi(roundi(picks * option_value(pack_sort, pack_quality) * premium), 1)

var price: int:
	get:
		return price_of(sort, size, quality)

## Das Glück, das die Güte beim Öffnen auf effective_luck legt - dieselbe Zahl wie beim Würfel-Paket.
static func quality_luck(pack_quality: int) -> int:
	return DicePack.quality_luck(pack_quality)

func guaranteed_tier() -> int:
	if not SORT_TYPES.has(sort):
		return -1
	return int(QUALITY_GUARANTEE[_quality(quality)])

## Die vorderste Karte; beim ersten Fragen gewürfelt (Sorte und Güte des Pakets) und dann fest.
func front_card(multiplier_chance := 0.0, bulk := false,
		rng: RandomNumberGenerator = null) -> Pack:
	if front == null:
		var weights: Array = (BULK_QUALITY_TIER_WEIGHTS if bulk else QUALITY_TIER_WEIGHTS)[
			_quality(quality)]
		front = _roll_card(sort, Pack.roll_tier(rng, weights), multiplier_chance, rng)
	return front

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
	return "%s\n%s" % [_content_line(card_pack.sort) + " Die sichtbare Karte ist dabei.", line]

static func _content_line(pack_sort: String) -> String:
	match pack_sort:
		SORT_MATERIAL:
			return "Nur Material-Karten."
		SORT_RUNE:
			return "Nur Runen-Karten."
		SORT_SPECIAL:
			return "Nur Sonder-Karten."
	return "Zahlen-Karten, manchmal ein Multiplikator."

# --- Die WAHL ----------------------------------------------------------------------

static func option_count(pack_size: int) -> int:
	return int(OPTION_COUNTS[clampi(pack_size, 0, OPTION_COUNTS.size() - 1)])

## "3 Optionen. Der Glückswürfel sagt, wie viele." (die Auskunft jedes Pakets).
static func choice_line(pack_size: int) -> String:
	return "%d Optionen. %s" % [option_count(pack_size), DIE_SAYS]

## Die Wahlen nennt kein Paket selbst - sie fallen beim Öffnen mit dem Glückswürfel.
const DIE_SAYS := "Der Glückswürfel sagt, wie viele."

## Die Zahl der Optionen nach den Zu- und Abschlägen: nie unter MIN_OPTIONS.
static func options_after(pack_size: int, delta: int) -> int:
	return maxi(option_count(pack_size) + delta, MIN_OPTIONS)

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
## mit Garantie und ohne doppeltes Netz. Option 0 ist IMMER die vorderste Karte des Pakets,
## unverändert - auch nach Neu mischen. Nie Reparatur-Karte, nie Rohling.
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
	var shown := card_pack.front_card(multiplier_chance, bulk, rng)
	var tiers: Array[int] = [shown.tier]
	for i in count - 1:
		tiers.append(Pack.roll_tier(rng, weights))
	var guarantee := card_pack.guaranteed_tier()
	if guarantee >= 0 and count > 1 and tiers.max() < guarantee:
		tiers[1 + _roll_unit_index(count - 1, rng)] = guarantee
	cards.append(shown)
	var seen := {content_key(shown): true}
	for i in range(1, count):
		cards.append(_roll_unique(card_pack.sort, tiers[i], multiplier_chance, rng, seen))
	# Die Garantie trägt nur eine Karte MIT Größe - sonst übernimmt eine Regal-Karte.
	if guarantee >= 0 and count > 1 and not _meets(cards, guarantee):
		cards[count - 1] = _tiered_card(_regular_type(card_pack.sort), guarantee,
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
	if pack_sort == SORT_SPECIAL:
		return Pack.roll_special_pack()
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

## Der Kartentyp der Garantie-Karte.
static func _regular_type(pack_sort: String) -> String:
	return String(SORT_TYPES.get(pack_sort, Pack.TYPE_NUMBER))

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
