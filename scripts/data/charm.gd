class_name Charm
extends Resource
## Datensatz eines Charms: nur Anzeige-Infos, die Wirkung löst CharmEffects
## über die id auf. Ein neuer Charm braucht eine Fabrikmethode hier (plus
## all()-Eintrag) und die Wirkung in CharmEffects - verdrahtet über dieselbe
## id-Konstante, damit ein Tippfehler Compilerfehler statt stiller No-op ist.

# --- Charm-ids (Single Source of Truth) ---
const RABBITS_FOOT := "rabbits_foot"
const LUCKY_CIGARETTES := "lucky_cigarettes"
const FOUR_LEAF_CLOVER := "four_leaf_clover"
const FOX_TAIL := "fox_tail"
const PENCIL_STUB := "pencil_stub"
const TOP_HAT := "top_hat"
const SILVER_DOLLAR := "silver_dollar"
const EIGHT_KNOT := "eight_knot"
const HORSESHOE := "horseshoe"
const LADYBUG := "ladybug"
const PEARL_NECKLACE := "pearl_necklace"
const MAGIC_CARD := "magic_card"
const RAINBOW_TROUT := "rainbow_trout"
const OLD_PENNY := "old_penny"
const PIGGY_BANK := "piggy_bank"
const CRYSTAL_BALL := "crystal_ball"
const CHIMNEY_SWEEP := "chimney_sweep"
const CON_ARTIST_CUFF := "con_artist_cuff"
const COLLECTORS_AMULET := "collectors_amulet"

# Effektkatalog-Charms (Obsidian "12 Charms - Effektkatalog"):
# Wurf & Neuwurf
const PENDULUM := "pendulum"
const ALL_OR_NOTHING := "all_or_nothing"
const ANCHOR := "anchor"
# Augen & Werte
const ECHO_CHAMBER := "echo_chamber"
const TWIN_RING := "twin_ring"
const CULT_OF_ONE := "cult_of_one"
const STREET_SWEEPER := "street_sweeper"
const EQUALIZER := "equalizer"
const EQUAL_GRIND := "equal_grind"
const SMALL_FRY := "small_fry"
const BEHERIT := "beherit"
const HIGH_STACKER := "high_stacker"
const PRIME_TIME := "prime_time"
const FRONT_RUNNER := "front_runner"
const QUADRATURE := "quadrature"
const SIX_PACK := "six_pack"
const PROTECTION_MONEY := "protection_money"
const WATERFALL := "waterfall"
# Kombinationen & Wertung
const HOUSE_JOKER := "house_joker"
const FREE_DRINK := "free_drink"
const SPOTLIGHT := "spotlight"
const FULL_COUNTER := "full_counter"
const MOMENTUM := "momentum"
const AFTER_WORK_BEER := "after_work_beer"
const BROADBAND := "broadband"
const EVEN_COMPANY := "even_company"
const ODD_PATH := "odd_path"
const SNAKE_EYES := "snake_eyes"
const DOUBLE_BOTTOM := "double_bottom"
# Farkle
const BROKEN_MIRROR := "broken_mirror"
const GRANDFATHER_CLOCK := "grandfather_clock"
const SHARD_COURT := "shard_court"
const GALLOWS_HUMOR := "gallows_humor"
const PHOENIX_FEATHER := "phoenix_feather"
const PATCHWORK_RUG := "patchwork_rug"
# Geld
const GOLD_RUSH := "gold_rush"
const RAG_COLLECTOR := "rag_collector"
const INTEREST_PENNY := "interest_penny"
const STREET_MUSICIAN := "street_musician"
const EMERGENCY_FUND := "emergency_fund"
const CASH_DISCOUNT := "cash_discount"
const HIGH_FLYER := "high_flyer"
# Materialien (Seiten)
const MIDAS_GLOVE := "midas_glove"
const GOLD_VEIN := "gold_vein"
const GOLDSMITH := "goldsmith"
const AMBER_ROOM := "amber_room"
const BLOOD_DIAMOND := "blood_diamond"
const BONE_GLUE := "bone_glue"
const BONE_MARROW := "bone_marrow"
const GLASSBLOWER_LUNG := "glassblower_lung"
const MERCURY_VAPOR := "mercury_vapor"
const DISPLAY_CASE := "display_case"
const JEWELRY_BOX := "jewelry_box"
const RECTIFIER := "rectifier"
# Coupons & Packs
const BARGAIN_HUNTER := "bargain_hunter"
const STAMP_MACHINE := "stamp_machine"
const FINE_PRINT := "fine_print"
# Pool & Trays
const RECYCLING := "recycling"
const SEDIMENT := "sediment"
# Shop & Angebote
const SEAL_OF_QUALITY := "seal_of_quality"
const BULK_DISCOUNT := "bulk_discount"
# Verträge mit dem Haus
const AD_DRUM := "ad_drum"
const SHYSTER := "shyster"
# Meta & Totem-Reihe
const PARROT_TOTEM := "parrot_totem"
const ECHO_TOTEM := "echo_totem"
const HERMIT_CRAB := "hermit_crab"
# Energie & Serie
const SUPERCONDUCTOR := "superconductor"
const DYNAMO := "dynamo"
const STANDBY_LIGHT := "standby_light"
const SOLDERING_IRON := "soldering_iron"
# Runen & Werkbank
const BURIN := "burin"
const LUMINOUS_PAINT := "luminous_paint"
const KILN := "kiln"
const CLAMP := "clamp"
const ENCORE := "encore"
# Automat, Nebenwette & Hinterzimmer
const ODDS_SHEET := "odds_sheet"
const FREE_SPIN := "free_spin"
const FENCED_GOODS := "fenced_goods"
const JACKPOT_BELL := "jackpot_bell"
const DEPOSIT_SHELF := "deposit_shelf"
const TIP_JAR := "tip_jar"
const CONSOLATION_PRIZE := "consolation_prize"
# Auslösungen & Zählreihenfolge
const FACTORY_FINISH := "factory_finish"
const BOTTLE_RACK := "bottle_rack"
const PRESSURE_GAUGE := "pressure_gauge"
const EMPTY_PLINTH := "empty_plinth"
const ODOMETER := "odometer"
const TAIL_LIGHT := "tail_light"
const STROBE := "strobe"
const METRONOME := "metronome"
# Erkennung, Hand-Spanne & Vorrat
const GAP_TOOTH := "gap_tooth"
const DROP_HEIGHT := "drop_height"
const INVENTORY := "inventory"
# Ladung (Welle 2): die Sicherung heisst SAFETY_FUSE, weil FUSE schon die
# Zündschnur des Knallgases ist - zwei Dinge, zwei ids.
const VOLTMETER := "voltmeter"
const SAFETY_FUSE := "safety_fuse"
const HEAT_SINK := "heat_sink"
const ARC_FLASH := "arc_flash"
const GROUNDING := "grounding"
const CONTINUOUS_DUTY := "continuous_duty"
const TRANSFORMER := "transformer"
const EMBER_CORE := "ember_core"
const SPARK_PLUG := "spark_plug"
# Fumbles als Laufzähler
const UNLUCKY_BIRD := "unlucky_bird"
const FUMBLE_PENSION := "fumble_pension"
const GALLOWS_REPRIEVE := "gallows_reprieve"
const BLACK_CAT := "black_cat"
# Essenz-Charms: je einer für jede Essenz ab "selten" - siehe ESSENCE_REQUIREMENT.
const AMALGAM := "amalgam"
const LEAD_APRON := "lead_apron"
const STORM_GLASS := "storm_glass"
const LIGHTNING_ROD := "lightning_rod"
const DARKROOM := "darkroom"
const PRESSURE_VESSEL := "pressure_vessel"
const AQUA_FORTIS := "aqua_fortis"
const CONTRAST_AGENT := "contrast_agent"
const CENSER := "censer"
const SOLAR_SAIL := "solar_sail"
const STORM_FRONT := "storm_front"
const BELL_JAR := "bell_jar"
const GLAZE_BRUSH := "glaze_brush"
const FLUORESCENT_TUBE := "fluorescent_tube"
const POLARIZER := "polarizer"
const ALKAHEST := "alkahest"
const MAGNETIC_TRAP := "magnetic_trap"
const CAMOUFLAGE := "camouflage"
const FUSE := "fuse"
const CUTTING_TORCH := "cutting_torch"
const MODERATOR := "moderator"
const METEORITE := "meteorite"
const MYCELIUM := "mycelium"
const HIGHLIGHTER := "highlighter"
const ASH_CLOUD := "ash_cloud"
const ICE_MIRROR := "ice_mirror"
const POLAR_DAY := "polar_day"
const MAGNETAR := "magnetar"
const RADIO_TELESCOPE := "radio_telescope"

## Essenz, die ein Charm verstärkt (Charm-id -> Essence-id). Sie ist zugleich
## seine ANGEBOTS-BEDINGUNG: ein solcher Charm liegt nur im Laden (Auslage,
## Schwarzmarkt, Automat), wenn diese Seele wirklich im Pool steckt - sonst wäre
## er eine tote Karte, und zwanzig tote Karten verdünnen den Topf.
## Die Quecksilberlampe steht bewusst NICHT hier: sie gehört keiner
## einzelnen Essenz, sondern jedem Auslösungs-Faktor.
const ESSENCE_REQUIREMENT := {
	AMALGAM: Essence.MERCURY_VAPOR,
	LEAD_APRON: Essence.RADON,
	STORM_GLASS: Essence.ST_ELMOS_FIRE,
	LIGHTNING_ROD: Essence.BALL_LIGHTNING,
	DARKROOM: Essence.PHOTON_GAS,
	PRESSURE_VESSEL: Essence.RADIATION_PRESSURE,
	AQUA_FORTIS: Essence.CYANIDE,
	CONTRAST_AGENT: Essence.XRAY,
	CENSER: Essence.MIASMA,
	SOLAR_SAIL: Essence.SOLAR_WIND,
	STORM_FRONT: Essence.OZONE,
	BELL_JAR: Essence.VACUUM,
	GLAZE_BRUSH: Essence.VARNISH,
	FLUORESCENT_TUBE: Essence.PHOSPHORESCENCE,
	POLARIZER: Essence.AURORA,
	ALKAHEST: Essence.QUINTESSENCE,
	MAGNETIC_TRAP: Essence.ANTIMATTER,
	FUSE: Essence.DETONATING_GAS,
	MODERATOR: Essence.CHERENKOV,
	METEORITE: Essence.SHOOTING_STAR,
	MYCELIUM: Essence.FOXFIRE,
	HIGHLIGHTER: Essence.BLACK_LIGHT,
	ASH_CLOUD: Essence.VOLCANIC_LIGHTNING,
	ICE_MIRROR: Essence.LIGHT_PILLAR,
	POLAR_DAY: Essence.MIDNIGHT_SUN,
	MAGNETAR: Essence.GAMMA_BURST,
	RADIO_TELESCOPE: Essence.BACKGROUND_RADIATION,
	# Ab hier auch HÄUFIGE Seelen: die Tabelle ist die Angebots-Regel, die
	# Pflicht "je Seele ab selten genau ein Charm" bleibt davon unberührt.
	CAMOUFLAGE: Essence.KRYPTON,
	CUTTING_TORCH: Essence.ACETYLENE,
	SPARK_PLUG: Essence.SPARK_GAP,
}

## Zweite Angebots-Bedingung neben der Seele: das SPIELZEUG muss auf dem Tisch
## stehen. Ein Charm, der den Schwarzmarkt drückt, ist ohne Hinterzimmer genauso
## tot wie ein Essenz-Charm ohne Würfel (GameRun.charm_offer_features liefert den
## Stand).
const FEATURE_SECRET_SHOP := "secret_shop"
const FEATURE_SLOT_MACHINE := "slot_machine"
const FEATURE_REQUIREMENT := {
	FENCED_GOODS: FEATURE_SECRET_SHOP,
	FREE_SPIN: FEATURE_SLOT_MACHINE,
}

## Essenz, die dieser Charm voraussetzt ("" = keine).
static func essence_requirement(charm_id: String) -> String:
	return String(ESSENCE_REQUIREMENT.get(charm_id, ""))

## Tisch-Einrichtung, die dieser Charm voraussetzt ("" = keine).
static func feature_requirement(charm_id: String) -> String:
	return String(FEATURE_REQUIREMENT.get(charm_id, ""))

## Die Charms, die dem Spieler überhaupt angeboten werden dürfen: alles ohne
## Essenz-Bedingung plus die, deren Seele er besitzt. EINE Quelle für Auslage,
## Schwarzmarkt und Automat. features fehlt oder schweigt = erlaubt (der Aufrufer
## ohne Laufzustand darf nichts verlieren).
static func offerable(pool: Array[Charm], owned_essence_ids: Array[String],
		features: Dictionary = {}) -> Array[Charm]:
	var out: Array[Charm] = []
	for charm in pool:
		var needed := essence_requirement(charm.id)
		if needed != "" and not owned_essence_ids.has(needed):
			continue
		var feature := feature_requirement(charm.id)
		if feature != "" and not bool(features.get(feature, true)):
			continue
		out.append(charm)
	return out

## Konvention: Modell-Dateiname = Charm-id (rabbits_foot.glb, ...). Fehlt die
## Datei, bleibt model_path leer und CharmRowView zeigt den Platzhalter.
const MODEL_DIR := "res://assets/models/"

# Raritäten: steuern Shop-Häufigkeit (rarity_weight/pick_weighted) und das
# Kantenlicht der Tisch-Vitrine (rarity_color/CharmRowView).
const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"
const RARITY_LEGENDARY := "legendary"

## Rarität je Charm-id; jeder Charm in all() MUSS hier stehen (per Test
## abgesichert). _make schlägt nach, Standard COMMON.
const RARITIES := {
	# Wurf & Neuwurf
	PENDULUM: RARITY_UNCOMMON,
	ALL_OR_NOTHING: RARITY_UNCOMMON,
	ANCHOR: RARITY_RARE,
	# Augen & Werte
	RABBITS_FOOT: RARITY_COMMON,
	LUCKY_CIGARETTES: RARITY_COMMON,
	FOUR_LEAF_CLOVER: RARITY_COMMON,
	FOX_TAIL: RARITY_COMMON,
	PENCIL_STUB: RARITY_COMMON,
	TOP_HAT: RARITY_COMMON,
	SILVER_DOLLAR: RARITY_COMMON,
	EIGHT_KNOT: RARITY_COMMON,
	ECHO_CHAMBER: RARITY_UNCOMMON,
	TWIN_RING: RARITY_UNCOMMON,
	CULT_OF_ONE: RARITY_RARE,
	STREET_SWEEPER: RARITY_UNCOMMON,
	EQUALIZER: RARITY_COMMON,
	EQUAL_GRIND: RARITY_RARE,
	SMALL_FRY: RARITY_COMMON,
	BEHERIT: RARITY_UNCOMMON,
	HIGH_STACKER: RARITY_UNCOMMON,
	PRIME_TIME: RARITY_RARE,
	FRONT_RUNNER: RARITY_COMMON,
	QUADRATURE: RARITY_UNCOMMON,
	SIX_PACK: RARITY_RARE,
	PROTECTION_MONEY: RARITY_UNCOMMON,
	WATERFALL: RARITY_UNCOMMON,
	# Kombinationen & Wertung
	HOUSE_JOKER: RARITY_COMMON,
	FREE_DRINK: RARITY_COMMON,
	SPOTLIGHT: RARITY_RARE,
	HORSESHOE: RARITY_COMMON,
	RAINBOW_TROUT: RARITY_COMMON,
	PEARL_NECKLACE: RARITY_COMMON,
	LADYBUG: RARITY_COMMON,
	MAGIC_CARD: RARITY_RARE,
	FULL_COUNTER: RARITY_RARE,
	MOMENTUM: RARITY_RARE,
	AFTER_WORK_BEER: RARITY_RARE,
	BROADBAND: RARITY_COMMON,
	EVEN_COMPANY: RARITY_UNCOMMON,
	ODD_PATH: RARITY_UNCOMMON,
	SNAKE_EYES: RARITY_COMMON,
	DOUBLE_BOTTOM: RARITY_RARE,
	# Farkle
	CHIMNEY_SWEEP: RARITY_RARE,
	BROKEN_MIRROR: RARITY_LEGENDARY,
	GRANDFATHER_CLOCK: RARITY_RARE,
	SHARD_COURT: RARITY_COMMON,
	GALLOWS_HUMOR: RARITY_COMMON,
	PHOENIX_FEATHER: RARITY_LEGENDARY,
	PATCHWORK_RUG: RARITY_UNCOMMON,
	# Geld
	OLD_PENNY: RARITY_COMMON,
	PIGGY_BANK: RARITY_UNCOMMON,
	CRYSTAL_BALL: RARITY_COMMON,
	GOLD_RUSH: RARITY_RARE,
	RAG_COLLECTOR: RARITY_UNCOMMON,
	INTEREST_PENNY: RARITY_UNCOMMON,
	STREET_MUSICIAN: RARITY_COMMON,
	EMERGENCY_FUND: RARITY_COMMON,
	CASH_DISCOUNT: RARITY_UNCOMMON,
	HIGH_FLYER: RARITY_UNCOMMON,
	# Materialien (Seiten)
	MIDAS_GLOVE: RARITY_RARE,
	GOLD_VEIN: RARITY_RARE,
	GOLDSMITH: RARITY_UNCOMMON,
	AMBER_ROOM: RARITY_UNCOMMON,
	BLOOD_DIAMOND: RARITY_UNCOMMON,
	BONE_GLUE: RARITY_UNCOMMON,
	BONE_MARROW: RARITY_UNCOMMON,
	GLASSBLOWER_LUNG: RARITY_COMMON,
	MERCURY_VAPOR: RARITY_LEGENDARY,
	DISPLAY_CASE: RARITY_RARE,
	JEWELRY_BOX: RARITY_RARE,
	RECTIFIER: RARITY_RARE,
	# Coupons & Packs
	BARGAIN_HUNTER: RARITY_COMMON,
	STAMP_MACHINE: RARITY_RARE,
	FINE_PRINT: RARITY_UNCOMMON,
	# Pool & Trays
	RECYCLING: RARITY_UNCOMMON,
	SEDIMENT: RARITY_UNCOMMON,
	# Shop & Angebote
	CON_ARTIST_CUFF: RARITY_COMMON,
	SEAL_OF_QUALITY: RARITY_UNCOMMON,
	BULK_DISCOUNT: RARITY_COMMON,
	# Verträge mit dem Haus
	AD_DRUM: RARITY_UNCOMMON,
	SHYSTER: RARITY_RARE,
	# Meta & Totem-Reihe
	COLLECTORS_AMULET: RARITY_UNCOMMON,
	PARROT_TOTEM: RARITY_LEGENDARY,
	ECHO_TOTEM: RARITY_LEGENDARY,
	HERMIT_CRAB: RARITY_COMMON,
	# Energie & Serie
	SUPERCONDUCTOR: RARITY_RARE,
	DYNAMO: RARITY_UNCOMMON,
	STANDBY_LIGHT: RARITY_RARE,
	SOLDERING_IRON: RARITY_RARE,
	# Runen & Werkbank
	BURIN: RARITY_RARE,
	LUMINOUS_PAINT: RARITY_COMMON,
	KILN: RARITY_LEGENDARY,
	CLAMP: RARITY_UNCOMMON,
	ENCORE: RARITY_UNCOMMON,
	# Automat, Nebenwette & Hinterzimmer
	ODDS_SHEET: RARITY_UNCOMMON,
	FREE_SPIN: RARITY_COMMON,
	FENCED_GOODS: RARITY_UNCOMMON,
	JACKPOT_BELL: RARITY_UNCOMMON,
	DEPOSIT_SHELF: RARITY_COMMON,
	TIP_JAR: RARITY_COMMON,
	CONSOLATION_PRIZE: RARITY_COMMON,
	# Auslösungen & Zählreihenfolge
	FACTORY_FINISH: RARITY_COMMON,
	BOTTLE_RACK: RARITY_UNCOMMON,
	PRESSURE_GAUGE: RARITY_COMMON,
	EMPTY_PLINTH: RARITY_COMMON,
	ODOMETER: RARITY_RARE,
	TAIL_LIGHT: RARITY_UNCOMMON,
	STROBE: RARITY_UNCOMMON,
	METRONOME: RARITY_COMMON,
	GAP_TOOTH: RARITY_RARE,
	DROP_HEIGHT: RARITY_UNCOMMON,
	INVENTORY: RARITY_RARE,
	# Ladung
	VOLTMETER: RARITY_UNCOMMON,
	SAFETY_FUSE: RARITY_UNCOMMON,
	HEAT_SINK: RARITY_RARE,
	ARC_FLASH: RARITY_RARE,
	GROUNDING: RARITY_UNCOMMON,
	CONTINUOUS_DUTY: RARITY_RARE,
	TRANSFORMER: RARITY_LEGENDARY,
	EMBER_CORE: RARITY_RARE,
	SPARK_PLUG: RARITY_RARE,
	# Fumbles
	UNLUCKY_BIRD: RARITY_UNCOMMON,
	FUMBLE_PENSION: RARITY_COMMON,
	GALLOWS_REPRIEVE: RARITY_RARE,
	BLACK_CAT: RARITY_UNCOMMON,
	# Essenz-Charms: die Rarität misst die STÄRKE mit der Seele, nicht die Nische -
	# die Nische regelt schon die Angebots-Kopplung (ESSENCE_REQUIREMENT).
	AMALGAM: RARITY_RARE,
	LEAD_APRON: RARITY_RARE,
	STORM_GLASS: RARITY_RARE,
	LIGHTNING_ROD: RARITY_RARE,
	DARKROOM: RARITY_RARE,
	PRESSURE_VESSEL: RARITY_UNCOMMON,
	AQUA_FORTIS: RARITY_RARE,
	CONTRAST_AGENT: RARITY_UNCOMMON,
	CENSER: RARITY_RARE,
	SOLAR_SAIL: RARITY_RARE,
	STORM_FRONT: RARITY_RARE,
	BELL_JAR: RARITY_RARE,
	GLAZE_BRUSH: RARITY_RARE,
	FLUORESCENT_TUBE: RARITY_LEGENDARY,
	POLARIZER: RARITY_LEGENDARY,
	ALKAHEST: RARITY_LEGENDARY,
	MAGNETIC_TRAP: RARITY_LEGENDARY,
	CAMOUFLAGE: RARITY_UNCOMMON,
	FUSE: RARITY_RARE,
	CUTTING_TORCH: RARITY_RARE,
	MODERATOR: RARITY_RARE,
	METEORITE: RARITY_RARE,
	MYCELIUM: RARITY_RARE,
	HIGHLIGHTER: RARITY_RARE,
	ASH_CLOUD: RARITY_RARE,
	ICE_MIRROR: RARITY_RARE,
	POLAR_DAY: RARITY_RARE,
	# Legendäre Seelen tragen legendäre Charms (wie Polarfilter/Alkahest).
	MAGNETAR: RARITY_LEGENDARY,
	RADIO_TELESCOPE: RARITY_LEGENDARY,
}

const RARITY_WEIGHTS := {
	RARITY_COMMON: 1.0,
	RARITY_UNCOMMON: 0.55,
	RARITY_RARE: 0.25,
	RARITY_LEGENDARY: 0.1,
}

## Signalfarben: Weiß / Grün / Blau / Violett.
const RARITY_COLORS := {
	RARITY_COMMON: Color(0.85, 0.9, 1.0),
	RARITY_UNCOMMON: Color(0.3, 1.0, 0.5),
	RARITY_RARE: Color(0.25, 0.55, 1.0),
	RARITY_LEGENDARY: Color(0.75, 0.35, 1.0),
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: String = RARITY_COMMON
@export var model_path: String = ""  # leer = Platzhalter-Modell
## Basis-Verkaufswert; den effektiven Erlös rechnet CharmEffects.charm_sell_value.
@export var sell_value: int = 5

static func _make(charm_id: String, name: String, desc: String) -> Charm:
	var charm := Charm.new()
	charm.id = charm_id
	charm.display_name = name
	charm.description = desc
	charm.rarity = RARITIES.get(charm_id, RARITY_COMMON)
	var candidate := MODEL_DIR + charm_id + ".glb"
	if ResourceLoader.exists(candidate):
		charm.model_path = candidate
	return charm

## Besitz dämpft das Ziehgewicht: ein schon gehaltener Archetyp bleibt kaufbar,
## drängelt sich aber nicht mehr vor die ungesehenen.
const OWNED_WEIGHT_FACTOR := 0.5

func rarity_weight() -> float:
	return RARITY_WEIGHTS.get(rarity, 1.0)

func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS[RARITY_COMMON])

## Ziehgewicht dieses Archetyps: Rarität, halbiert wenn er in owned_ids steht.
func pick_weight(owned_ids: Array[String] = []) -> float:
	return rarity_weight() * (OWNED_WEIGHT_FACTOR if owned_ids.has(id) else 1.0)

## Zieht gewichtet nach Rarität und Besitz; candidates darf nicht leer sein.
static func pick_weighted(candidates: Array[Charm], owned_ids: Array[String] = []) -> Charm:
	var total := 0.0
	for charm in candidates:
		total += charm.pick_weight(owned_ids)
	var roll := randf() * total
	for charm in candidates:
		roll -= charm.pick_weight(owned_ids)
		if roll <= 0.0:
			return charm
	return candidates.back()

# --- Augenwert-Charms ---

static func rabbits_foot() -> Charm:
	return _make(RABBITS_FOOT, "Hasenpfote", "Jede 6: +1 Auslösung.")

static func lucky_cigarettes() -> Charm:
	return _make(LUCKY_CIGARETTES, "Glückszigaretten", "Jede 1 zählt als 6.")

static func four_leaf_clover() -> Charm:
	return _make(FOUR_LEAF_CLOVER, "Vierblättriges Kleeblatt", "Jede 4: +1 Auslösung.")

static func fox_tail() -> Charm:
	return _make(FOX_TAIL, "Fuchsschwanz", "Jede 3 zählt als 4.")

static func pencil_stub() -> Charm:
	return _make(PENCIL_STUB, "Croupier-Bleistift", "Jede 2 zählt als 3.")

static func top_hat() -> Charm:
	return _make(TOP_HAT, "Zylinderhut", "Jede 4 zählt als 5.")

static func silver_dollar() -> Charm:
	return _make(SILVER_DOLLAR, "Silberdollar", "Jede 5 zählt als 6.")

## Gravuren treiben Seiten über die 6 - der Knoten zieht beide Nachbarn zur 8.
static func eight_knot() -> Charm:
	return _make(EIGHT_KNOT, "Achterknoten", "Jede 7 und 9 zählt als 8.")

# --- Wertungs-Charms ---

static func horseshoe() -> Charm:
	return _make(HORSESHOE, "Hufeisen", "Full House: +8 Mult.")

static func ladybug() -> Charm:
	return _make(LADYBUG, "Marienkäfer", "Paar: +4 Mult.")

static func pearl_necklace() -> Charm:
	return _make(PEARL_NECKLACE, "Perlenkette", "Dreierpasch: +6 Mult.")

static func magic_card() -> Charm:
	return _make(MAGIC_CARD, "Zauberkarte", "Erste Hand der Runde: jeder Würfel +1 Auslösung.")

static func rainbow_trout() -> Charm:
	return _make(RAINBOW_TROUT, "Regenbogenforelle", "Straße: +8 Mult.")

# --- Geld-Charms ---

static func old_penny() -> Charm:
	return _make(OLD_PENNY, "Glücksgroschen", "Rundenende: +$3, nach jeder Auszahlung $1 mehr.")

static func piggy_bank() -> Charm:
	return _make(PIGGY_BANK, "Sparschwein", "Übrige Würfel zahlen $1 mehr.")

static func crystal_ball() -> Charm:
	return _make(CRYSTAL_BALL, "Kristallkugel", "Überlebter Fumble: +$7.")

# --- Farkle-Charms ---

static func chimney_sweep() -> Charm:
	return _make(CHIMNEY_SWEEP, "Schornsteinfeger", "Erster Fumble der Runde wird verziehen.")

# --- Pool-/Shop-Charms ---

static func con_artist_cuff() -> Charm:
	return _make(CON_ARTIST_CUFF, "Trickdieb-Manschette", "Würfel im Laden kosten 33 % weniger.")

# --- Meta-Charm ---

static func collectors_amulet() -> Charm:
	return _make(COLLECTORS_AMULET, "Sammler-Amulett", "+2 Mult je Charm.")

# === Effektkatalog-Charms ====================================================

# --- Wurf & Neuwurf ---

static func pendulum() -> Charm:
	return _make(PENDULUM, "Pendel", "+2 Mult je neu geworfenem Würfel, −1 je genommenem (min. 0).")

static func all_or_nothing() -> Charm:
	return _make(ALL_OR_NOTHING, "Roter Knopf", "Alle 6 Würfel neu geworfen: nächste Hand +15 Mult.")

static func anchor() -> Charm:
	return _make(ANCHOR, "Anker", "Erster Neuwurf jeder Hand kann nicht fumblen.")

# --- Augen & Werte ---

static func echo_chamber() -> Charm:
	return _make(ECHO_CHAMBER, "Echo-Kammer", "Erster gewerteter Würfel: +1 Auslösung.")

static func twin_ring() -> Charm:
	return _make(TWIN_RING, "Zwillingsring", "Krit ×(1 + Paare im Wurf).")

static func cult_of_one() -> Charm:
	return _make(CULT_OF_ONE, "Einserkult", "Jede gewertete 1: Krit ×2.")

static func street_sweeper() -> Charm:
	return _make(STREET_SWEEPER, "Straßenbesen", "Straße: +15 Basispunkte je Würfel.")

static func equalizer() -> Charm:
	return _make(EQUALIZER, "Equalizer", "Jeder gewertete Würfel gibt min. 10 Basispunkte.")

static func equal_grind() -> Charm:
	return _make(EQUAL_GRIND, "Gleichschliff", "Gewerteter Würfel mit 6 gleichen Seiten: +(Augenzahl) Mult.")

static func small_fry() -> Charm:
	return _make(SMALL_FRY, "Kleinvieh", "Jede gewertete 1 und 2: +5 Basispunkte, +2 Mult.")

static func beherit() -> Charm:
	return _make(BEHERIT, "Beherit", "Ab 3 gewerteten Würfeln: Krit ×(1 + niedrigste Augenzahl).")

static func high_stacker() -> Charm:
	return _make(HIGH_STACKER, "Hochstapler", "+(höchste gewertete Augenzahl) Mult.")

static func prime_time() -> Charm:
	return _make(PRIME_TIME, "Prime Time", "Jede gewertete Primzahl (2, 3, 5, 7 …): +(Augenzahl) Mult.")

static func front_runner() -> Charm:
	return _make(FRONT_RUNNER, "Vorreiter", "+(Augensumme aller liegenden Würfel) Basispunkte.")

static func quadrature() -> Charm:
	return _make(QUADRATURE, "Quadratur", "Ab 4 gewerteten Würfeln: der niedrigste gibt +(Augenzahl²) Basispunkte.")

static func six_pack() -> Charm:
	return _make(SIX_PACK, "Sechserpack", "Hand mit allen 6 Würfeln: jeder +1 Auslösung.")

static func protection_money() -> Charm:
	return _make(PROTECTION_MONEY, "Schutzgeld", "Alle Augen +10. Je Hand $3 Gebühr.")

static func waterfall() -> Charm:
	return _make(WATERFALL, "Wasserfall", "Jede gezählte Augenzahl unter der letzten auslösenden: +(Augenzahl) Mult.")

# --- Kombinationen & Wertung ---

static func house_joker() -> Charm:
	return _make(HOUSE_JOKER, "Hausjoker", "+4 Mult.")

static func free_drink() -> Charm:
	return _make(FREE_DRINK, "Freigetränk", "+50 Basispunkte.")

static func spotlight() -> Charm:
	return _make(SPOTLIGHT, "Rampenlicht", "Je Runde eine Kombination im Rampenlicht.")

static func full_counter() -> Charm:
	return _make(FULL_COUNTER, "Vollzähler", "Alle liegenden Würfel werden gewertet.")

static func momentum() -> Charm:
	return _make(MOMENTUM, "Schwungrad", "+2 Mult je Hand in Folge ohne Fumble.")

static func after_work_beer() -> Charm:
	return _make(AFTER_WORK_BEER, "Feierabendbier", "Nachziehstapel leer: Krit ×5.")

static func broadband() -> Charm:
	return _make(BROADBAND, "Mehrfachstecker", "+5 Basispunkte je Würfel der Kombination.")

static func even_company() -> Charm:
	return _make(EVEN_COMPANY, "Wasserwaage", "Nur gerade Augenzahlen: +8 Mult.")

static func odd_path() -> Charm:
	return _make(ODD_PATH, "Schiefer Turm", "Nur ungerade Augenzahlen: +8 Mult.")

static func snake_eyes() -> Charm:
	return _make(SNAKE_EYES, "Snake Eyes", "Kombination ist ein Paar 1er: Krit ×(Augensumme der übrigen Würfel).")

static func double_bottom() -> Charm:
	return _make(DOUBLE_BOTTOM, "Dreifacher Boden", "Basispunkte der Kombination ×3.")

# --- Farkle ---

static func broken_mirror() -> Charm:
	return _make(BROKEN_MIRROR, "Zerbrochener Spiegel", "Fumble: alle Kombinationen dauerhaft +1 Mult.")

static func grandfather_clock() -> Charm:
	return _make(GRANDFATHER_CLOCK, "Standuhr", "Fumble: Rundenpunkte verdoppeln sich.")

static func shard_court() -> Charm:
	return _make(SHARD_COURT, "Scherbengericht", "Fumble: +$2 je verworfenem Würfel.")

static func gallows_humor() -> Charm:
	return _make(GALLOWS_HUMOR, "Galgenhumor", "Erste Hand nach einem Fumble: Krit ×4.")

static func phoenix_feather() -> Charm:
	return _make(PHOENIX_FEATHER, "Phönixfeder", "Erster Fumble der Runde: die Hand geht unter den Nachziehstapel statt in die Ablage.")

static func patchwork_rug() -> Charm:
	return _make(PATCHWORK_RUG, "Flickenteppich", "Fumble: der höchste Würfel bleibt liegen.")

# --- Geld ---

static func gold_rush() -> Charm:
	return _make(GOLD_RUSH, "Goldrausch", "Erste Hand der Runde mit allen 6 Würfeln: Geld +20 % (max. $30).")

static func rag_collector() -> Charm:
	return _make(RAG_COLLECTOR, "Lumpensammler", rag_collector_description(0))

## Beschreibung mit der aktuell gewürfelten Glückszahl; 0 = noch keine (Shop).
static func rag_collector_description(value: int) -> String:
	var base := "Je Runde eine Glückszahl (1–6). Abgelegter Würfel mit ihr oben: +$4."
	if value >= 1 and value <= 6:
		return "%s\nGlückszahl diese Runde: %d." % [base, value]
	return base

static func interest_penny() -> Charm:
	return _make(INTEREST_PENNY, "Zinsgroschen", "Rundenende: +$1 je $10 Besitz (max. $20).")

static func street_musician() -> Charm:
	return _make(STREET_MUSICIAN, "Straßenmusiker", "+$1 je gewertetem Würfel.")

static func emergency_fund() -> Charm:
	return _make(EMERGENCY_FUND, "Notgroschen", "Rundenende unter $45: auf $45 aufgefüllt.")

static func cash_discount() -> Charm:
	return _make(CASH_DISCOUNT, "Rabattmarke", "Charms kosten $5 weniger.")

static func high_flyer() -> Charm:
	return _make(HIGH_FLYER, "Überflieger", "+$5 je geräumter Überladungs-Stufe.")

# --- Materialien (Seiten) ---

static func midas_glove() -> Charm:
	return _make(MIDAS_GLOVE, "Midashandschuh", "Hand mit allen 6 Würfeln: obere Seiten werden dauerhaft Gold.")

static func gold_vein() -> Charm:
	return _make(GOLD_VEIN, "Goldader", "Gold-Seite: +$1 je davor ausgelöster Gold-Seite.")

static func goldsmith() -> Charm:
	return _make(GOLDSMITH, "Goldschmied", "Gold-Seiten zahlen $3 mehr.")

static func amber_room() -> Charm:
	return _make(AMBER_ROOM, "Bernsteinzimmer", "Bernstein: zusätzlich +30 Basispunkte.")

static func blood_diamond() -> Charm:
	return _make(BLOOD_DIAMOND, "Blutdiamant", "Rubin: zusätzlich +(Augenzahl) Mult.")

static func bone_marrow() -> Charm:
	return _make(BONE_MARROW, "Knochenmark", "Knochen-Seite: +1 Auslösung.")

static func bone_glue() -> Charm:
	return _make(BONE_GLUE, "Knochenleim", "Knochen wächst je Auslösung zusätzlich +3.")

static func glassblower_lung() -> Charm:
	return _make(GLASSBLOWER_LUNG, "Glasbläserpfeife", "Glas schrumpft nie unter 6.")

static func mercury_vapor() -> Charm:
	return _make(MERCURY_VAPOR, "Quecksilberlampe", "Essenzen mit Mehrfach-Auslösung: +1 Auslösung.")

static func display_case() -> Charm:
	return _make(DISPLAY_CASE, "Vitrine", "+2 Mult je oberer Material-Seite, veredelt +6.")

static func jewelry_box() -> Charm:
	return _make(JEWELRY_BOX, "Schmuckkästchen", "Rundenende: je übrigem Würfel 10 % Chance auf ein Material-Paket.")

static func rectifier() -> Charm:
	return _make(RECTIFIER, "Gleichrichter", "Nach jeder Hand: obere Seiten der gewerteten Würfel werden dauerhaft ihr Mittelwert (aufgerundet).")

# --- Coupons & Packs ---

static func bargain_hunter() -> Charm:
	return _make(BARGAIN_HUNTER, "Schnäppchenjäger", "Pakete kosten $3 weniger.")

static func stamp_machine() -> Charm:
	return _make(STAMP_MACHINE, "Frankiermaschine", "Rundenende: 1 zufälliges Upgrade-Paket.")

static func fine_print() -> Charm:
	return _make(FINE_PRINT, "Kleingedrucktes", "Paket-Kauf: 20 % Chance auf volle Erstattung.")

# --- Pool & Trays ---

static func recycling() -> Charm:
	return _make(RECYCLING, "Bumerang", "Erste Hand der Runde geht unter den Nachziehstapel zurück.")

static func sediment() -> Charm:
	return _make(SEDIMENT, "Bodensatz", "Letzte 6 Würfel des Nachziehstapels: +4 Mult, wenn gewertet.")

# --- Shop & Angebote ---

static func seal_of_quality() -> Charm:
	return _make(SEAL_OF_QUALITY, "Gütesiegel", "Würfel im Laden tragen immer eine veredelte Material-Seite.")

static func bulk_discount() -> Charm:
	return _make(BULK_DISCOUNT, "Mengenrabatt", "Würfelbündel kosten $5 weniger.")

# --- Verträge mit dem Haus ---

static func ad_drum() -> Charm:
	return _make(AD_DRUM, "Werbetrommel", "Werbegeschenke 3× so oft in der Vertragswahl.")

static func shyster() -> Charm:
	return _make(SHYSTER, "Winkeladvokat", "Bonus-Klauseln wirken doppelt.")

# --- Meta & Totem-Reihe ---

static func parrot_totem() -> Charm:
	return _make(PARROT_TOTEM, "Papagei-Totem", "Kopiert den Charm links.")

static func echo_totem() -> Charm:
	return _make(ECHO_TOTEM, "Echo-Totem", "Kopiert den Charm rechts.")

static func hermit_crab() -> Charm:
	return _make(HERMIT_CRAB, "Einsiedlerkrebs", "Höchstens 2 Charms: +6 Mult.")

# --- Essenz-Charms (je einer ab "selten"; Bedingung siehe ESSENCE_REQUIREMENT) ---

static func amalgam() -> Charm:
	return _make(AMALGAM, "Amalgam", "Quecksilberdampf: +2 Auslösungen.")

static func lead_apron() -> Charm:
	return _make(LEAD_APRON, "Bleischürze", "Radon: +3 statt +2 Augen je Mitwürfel.")

static func storm_glass() -> Charm:
	return _make(STORM_GLASS, "Sturmglas", "Elmsfeuer: jede Runde gilt als Boss-Runde.")

static func lightning_rod() -> Charm:
	return _make(LIGHTNING_ROD, "Blitzableiter", "Kugelblitz: Krit ×(2 + gewertete Kugelblitz-Würfel).")

static func darkroom() -> Charm:
	return _make(DARKROOM, "Dunkelkammer", "Photonengas zählt auch Auslösungen früherer Hände der Runde.")

static func pressure_vessel() -> Charm:
	return _make(PRESSURE_VESSEL, "Druckkessel", "Strahlungsdruck: +10 % je Seite statt +2.")

static func aqua_fortis() -> Charm:
	return _make(AQUA_FORTIS, "Scheidewasser", "Zyanidgas: +$1 je Gold-Seite jedes anderen gewerteten Würfels.")

static func contrast_agent() -> Charm:
	return _make(CONTRAST_AGENT, "Kontrastmittel", "Röntgenlicht gewertet: obere Seite dauerhaft ÷2, Gegenseite ×3.")

static func censer() -> Charm:
	return _make(CENSER, "Weihrauchfass", "Miasma steckt weiter an, ohne selbst zu verlieren.")

static func solar_sail() -> Charm:
	return _make(SOLAR_SAIL, "Sonnensegel", "Sonnenwind: +2 Auslösungen je verschiedener Essenz vor ihm.")

static func storm_front() -> Charm:
	return _make(STORM_FRONT, "Gewitterfront", "Ozon: Krits früherer Hände der Runde zählen mit.")

static func bell_jar() -> Charm:
	return _make(BELL_JAR, "Glasglocke", "Vakuum-Würfel: jede Seite trägt eine dritte Rune.")

static func glaze_brush() -> Charm:
	return _make(GLAZE_BRUSH, "Lasurpinsel", "Firnis trifft veredelte Seite: stattdessen ein Veredelungs-Paket.")

static func fluorescent_tube() -> Charm:
	return _make(FLUORESCENT_TUBE, "Leuchtstoffröhre", "Phosphoreszenz speichert auch ihren Mult und zahlt ihn erneut aus.")

static func polarizer() -> Charm:
	return _make(POLARIZER, "Polarfilter", "Polarlicht: Krit ×(Zahl, die es für die Kombination annimmt).")

static func alkahest() -> Charm:
	return _make(ALKAHEST, "Alkahest", "Quintessenz borgt auch Seelen aus der Ablage dieser Runde.")

static func magnetic_trap() -> Charm:
	return _make(MAGNETIC_TRAP, "Magnetfalle", "Antimaterie-Augen zählen nicht mehr negativ, ihr Krit bleibt.")

static func camouflage() -> Charm:
	return _make(CAMOUFLAGE, "Tarnkappe", "Krypton-Würfel: +1 Auslösung.")

static func fuse() -> Charm:
	return _make(FUSE, "Zündschnur", "Knallgas: +$3 statt +$1 je folgendem Würfel im Stapel.")

static func cutting_torch() -> Charm:
	return _make(CUTTING_TORCH, "Schneidbrenner", "Acetylen: zusätzlich +3 Mult je Modul der Kombination.")

static func moderator() -> Charm:
	return _make(MODERATOR, "Steuerstab", "Tscherenkow-Krits kosten keine Energie und schlagen ×(gelagerte Energie).")

static func meteorite() -> Charm:
	return _make(METEORITE, "Meteorit", "Sternschnuppe kritet bei jeder Wertung.")

static func mycelium() -> Charm:
	return _make(MYCELIUM, "Pilzgeflecht", "Fuchsfeuer: +(Summe der oberen Ablage-Seiten) Augen.")

static func highlighter() -> Charm:
	return _make(HIGHLIGHTER, "Neonmarker", "Schwarzlicht: zusätzlich +$1 je materiallosem Würfel, der diese Runde gewertet hat.")

static func ash_cloud() -> Charm:
	return _make(ASH_CLOUD, "Aschewolke", "Fumble mit Vulkanblitz: sein Krit dauerhaft +1.")

static func ice_mirror() -> Charm:
	return _make(ICE_MIRROR, "Eisspiegel", "Lichtsäule: Gleichzahlen +4 Auslösungen statt +2.")

static func polar_day() -> Charm:
	return _make(POLAR_DAY, "Polartag", "Mitternachtssonne: +2 Auslösungen je Hand statt +1.")

static func magnetar() -> Charm:
	return _make(MAGNETAR, "Magnetar", "Gammablitz: jede Auslösung Krit ×10.")

static func radio_telescope() -> Charm:
	return _make(RADIO_TELESCOPE, "Radioteleskop", "Hintergrundstrahlung lässt auch die Ablage wachsen.")

# --- Energie & Serie ---

static func superconductor() -> Charm:
	return _make(SUPERCONDUCTOR, "Supraleiter", "Module kosten 25 % weniger (min. 1).")

static func dynamo() -> Charm:
	return _make(DYNAMO, "Dynamo", "Geschaffte Runde: +1 ⚡.")

static func standby_light() -> Charm:
	return _make(STANDBY_LIGHT, "Standby-Licht", "+1 Mult je gelagerter Energie.")

static func soldering_iron() -> Charm:
	return _make(SOLDERING_IRON, "Lötkolben", "Pointer überdecken nicht mehr, sie addieren ihre Zahl.")

# --- Runen & Werkbank ---

static func burin() -> Charm:
	return _make(BURIN, "Stichel", "Runen wirken doppelt.")

static func luminous_paint() -> Charm:
	return _make(LUMINOUS_PAINT, "Leuchtfarbe", "+2 Mult je Rune auf gewerteten Würfeln.")

static func kiln() -> Charm:
	return _make(KILN, "Härteofen", "Veredelte Seiten wirken doppelt.")

## bench_clamp statt clamp: clamp() ist eine eingebaute Godot-Funktion.
static func bench_clamp() -> Charm:
	return _make(CLAMP, "Zwinge", "Upgrade-Pakete brennen mit 25 % Chance nicht aus.")

static func encore() -> Charm:
	return _make(ENCORE, "Füllhorn", "Überladungs-Stufe 5 erreicht: ein Sonderbestand gratis.")

# --- Automat, Nebenwette & Hinterzimmer ---

static func odds_sheet() -> Charm:
	return _make(ODDS_SHEET, "Quotenblatt", "Gewonnene Nebenwetten zahlen doppelt.")

static func free_spin() -> Charm:
	return _make(FREE_SPIN, "Freispiel", "Erster Automaten-Dreh der Runde gratis.")

static func fenced_goods() -> Charm:
	return _make(FENCED_GOODS, "Hehlerware", "Schwarzmarkt kostet 1 ⚡ weniger (min. 1).")

static func jackpot_bell() -> Charm:
	return _make(JACKPOT_BELL, "Jackpotglocke", "Erste Hand der Runde über dem Blind: +$10.")

static func deposit_shelf() -> Charm:
	return _make(DEPOSIT_SHELF, "Pfandregal", "Rundenende: +$1 je 3 Pakete im Magazin (max. $15).")

static func tip_jar() -> Charm:
	return _make(TIP_JAR, "Trinkgeldglas", "Jeder Krit zahlt seinen ×-Wert in $ (aufgerundet).")

static func consolation_prize() -> Charm:
	return _make(CONSOLATION_PRIZE, "Trostpreis", "Fumble: +1 ⚡.")

# --- Auslösungen & Zählreihenfolge ---

static func factory_finish() -> Charm:
	return _make(FACTORY_FINISH, "Schutzfolie", "Würfel ohne Material, Rune und Essenz: +15 Basispunkte.")

static func bottle_rack() -> Charm:
	return _make(BOTTLE_RACK, "Flaschenregal", "+4 Mult je Essenz-Würfel in der Ablage.")

static func pressure_gauge() -> Charm:
	return _make(PRESSURE_GAUGE, "Manometer", "Genau 1 Essenz-Würfel in der Hand: seine Essenz wirkt doppelt.")

static func empty_plinth() -> Charm:
	return _make(EMPTY_PLINTH, "Leerer Sockel", "+3 Mult je freiem Charm-Platz.")

static func odometer() -> Charm:
	return _make(ODOMETER, "Kilometerzähler", "+1 Mult je gespielter Runde.")

static func tail_light() -> Charm:
	return _make(TAIL_LIGHT, "Rücklicht", "Letzter gewerteter Würfel: +1 Auslösung.")

static func strobe() -> Charm:
	return _make(STROBE, "Stroboskop", "Jede Auslösung: +2 Mult je früherer Auslösung desselben Würfels.")

static func metronome() -> Charm:
	return _make(METRONOME, "Metronom", "Würfel mit genau 1 Auslösung: +6 Basispunkte je solchem Würfel vor ihm.")

static func zahnluecke() -> Charm:
	return _make(GAP_TOOTH, "Zahnlücke", "Straßen dürfen eine Lücke haben.")

static func drop_height() -> Charm:
	return _make(DROP_HEIGHT, "Fallhöhe", "+(höchster − niedrigster gewerteter Würfel) Mult.")

static func inventory() -> Charm:
	return _make(INVENTORY, "Inventur", "+2 Basispunkte je Material-Seite im Vorrat.")

# --- Ladung ------------------------------------------------------------------

static func voltmeter() -> Charm:
	return _make(VOLTMETER, "Spannungsmesser", "+2 Mult je Ladung der Hand.")

static func safety_fuse() -> Charm:
	return _make(SAFETY_FUSE, "Sicherung", "Erster Durchbrenner der Runde fällt stattdessen auf Ladung 0.")

static func heat_sink() -> Charm:
	return _make(HEAT_SINK, "Kühlkörper", "Ladung steigt nie über 2.")

static func arc_flash() -> Charm:
	return _make(ARC_FLASH, "Lichtbogen", "Würfel brennt beim Werten durch: +230 Basispunkte.")

static func grounding() -> Charm:
	return _make(GROUNDING, "Erdung", "Rundenende: alle Würfel −1 Ladung, auch gespielte.")

static func continuous_duty() -> Charm:
	return _make(CONTINUOUS_DUTY, "Dauerbetrieb", "Ungespielte Würfel verlieren am Rundenende keine Ladung.")

static func transformer() -> Charm:
	return _make(TRANSFORMER, "Transformator", "Gewerteter Würfel auf Ladung 3: Krit ×2.")

static func ember_core() -> Charm:
	return _make(EMBER_CORE, "Glutkern", "Erster durchgebrannter Würfel der Hand zählt für die Kombination als jede Zahl.")

static func spark_plug() -> Charm:
	return _make(SPARK_PLUG, "Zündkerze", "Funkenstrecke: Krit ×(2 + Ladung) statt ×(1 + Ladung).")

# --- Fumbles -----------------------------------------------------------------

static func unlucky_bird() -> Charm:
	return _make(UNLUCKY_BIRD, "Pechvogel", "+1 Mult je 2 Fumbles im Lauf.")

static func fumble_pension() -> Charm:
	return _make(FUMBLE_PENSION, "Fumble-Rente", "Rundenende: +$1 je 3 Fumbles im Lauf.")

static func gallows_reprieve() -> Charm:
	return _make(GALLOWS_REPRIEVE, "Galgenfrist", "Fumble: Blind dieser Runde −3 %.")

static func black_cat() -> Charm:
	return _make(BLACK_CAT, "Schwarze Katze", "Ladenpreise −2 % je Fumble im Lauf (max. −30 %).")

## Kanonische Registrierung aller Charm-Archetypen - ein neuer Charm wird
## hier eingehängt.
static func all() -> Array[Charm]:
	return [
		rabbits_foot(), lucky_cigarettes(), four_leaf_clover(), fox_tail(), pencil_stub(),
		top_hat(), silver_dollar(), eight_knot(),
		horseshoe(), ladybug(), pearl_necklace(), magic_card(), rainbow_trout(),
		old_penny(), piggy_bank(), crystal_ball(),
		chimney_sweep(),
		con_artist_cuff(),
		collectors_amulet(),
		# Effektkatalog
		pendulum(), all_or_nothing(), anchor(),
		echo_chamber(), twin_ring(), cult_of_one(), street_sweeper(), equalizer(), small_fry(),
		equal_grind(),
		beherit(), high_stacker(), prime_time(), front_runner(), quadrature(), six_pack(),
		protection_money(), waterfall(),
		house_joker(), free_drink(), spotlight(),
		full_counter(), momentum(), after_work_beer(),
		broadband(), even_company(), odd_path(), snake_eyes(), double_bottom(),
		broken_mirror(), grandfather_clock(), shard_court(), gallows_humor(), phoenix_feather(), patchwork_rug(),
		gold_rush(), rag_collector(), interest_penny(), street_musician(), emergency_fund(),
		cash_discount(), high_flyer(),
		midas_glove(), gold_vein(), goldsmith(), amber_room(),
		blood_diamond(), bone_glue(), bone_marrow(), glassblower_lung(), mercury_vapor(),
		display_case(), jewelry_box(), rectifier(),
		bargain_hunter(), stamp_machine(), fine_print(),
		recycling(), sediment(),
		seal_of_quality(), bulk_discount(),
		ad_drum(), shyster(),
		parrot_totem(), echo_totem(), hermit_crab(),
		# Essenz-Charms
		amalgam(), lead_apron(), storm_glass(), lightning_rod(), darkroom(),
		pressure_vessel(), aqua_fortis(), contrast_agent(),
		censer(), solar_sail(), storm_front(),
		bell_jar(), glaze_brush(), fluorescent_tube(),
		polarizer(), alkahest(), magnetic_trap(), camouflage(), fuse(),
		cutting_torch(), moderator(), meteorite(), mycelium(), highlighter(), ash_cloud(),
		ice_mirror(), polar_day(), magnetar(), radio_telescope(),
		# Zweite Welle
		superconductor(), dynamo(), standby_light(), soldering_iron(),
		burin(), luminous_paint(), kiln(), bench_clamp(), encore(),
		odds_sheet(), free_spin(), fenced_goods(), jackpot_bell(), deposit_shelf(),
		tip_jar(), consolation_prize(),
		factory_finish(), bottle_rack(), pressure_gauge(), empty_plinth(), odometer(),
		tail_light(), strobe(), metronome(),
		zahnluecke(), drop_height(), inventory(),
		# Ladung
		voltmeter(), safety_fuse(), heat_sink(), arc_flash(),
		grounding(), continuous_duty(), transformer(), ember_core(), spark_plug(),
		# Fumbles
		unlucky_bird(), fumble_pension(), gallows_reprieve(), black_cat(),
	]
