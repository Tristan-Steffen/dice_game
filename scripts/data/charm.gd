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
const GOLDEN_SCARAB := "golden_scarab"
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
const SMALL_FRY := "small_fry"
const BEHERIT := "beherit"
const HIGH_STACKER := "high_stacker"
const PRIME_TIME := "prime_time"
const FRONT_RUNNER := "front_runner"
# Kombinationen & Wertung
const HOUSE_JOKER := "house_joker"
const FREE_DRINK := "free_drink"
const SPOTLIGHT := "spotlight"
const FULL_COUNTER := "full_counter"
const LIGHTHOUSE := "lighthouse"
const MOMENTUM := "momentum"
const AFTER_WORK_BEER := "after_work_beer"
const BLACKJACK := "blackjack"
const ROUND_NUMBER := "round_number"
const BROADBAND := "broadband"
const EVEN_COMPANY := "even_company"
const ODD_PATH := "odd_path"
const SNAKE_EYES := "snake_eyes"
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
const RUBY_GRINDER := "ruby_grinder"
const BLOOD_DIAMOND := "blood_diamond"
const BONE_GLUE := "bone_glue"
const BONE_MARROW := "bone_marrow"
const GLASSBLOWER_LUNG := "glassblower_lung"
const MERCURY_VAPOR := "mercury_vapor"
const DISPLAY_CASE := "display_case"
const JEWELRY_BOX := "jewelry_box"
# Coupons & Packs
const BARGAIN_HUNTER := "bargain_hunter"
const ENGRAVING_PEN := "engraving_pen"
const STAMP_MACHINE := "stamp_machine"
const FINE_PRINT := "fine_print"
# Pool & Trays
const RECYCLING := "recycling"
const FRESH_GOODS := "fresh_goods"
const SEDIMENT := "sediment"
# Shop & Angebote
const SEAL_OF_QUALITY := "seal_of_quality"
const BULK_DISCOUNT := "bulk_discount"
# Meta & Totem-Reihe
const PARROT_TOTEM := "parrot_totem"
const ECHO_TOTEM := "echo_totem"
const HERMIT_CRAB := "hermit_crab"
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
const SWAMP_LANTERN := "swamp_lantern"
const IGNITION_COIL := "ignition_coil"
const BELL_JAR := "bell_jar"
const SOLAR_ECLIPSE := "solar_eclipse"
const GLAZE_BRUSH := "glaze_brush"
const FLUORESCENT_TUBE := "fluorescent_tube"
const POLARIZER := "polarizer"
const ALKAHEST := "alkahest"
const MAGNETIC_TRAP := "magnetic_trap"

## Essenz, die ein Charm verstärkt (Charm-id -> Essence-id). Sie ist zugleich
## seine ANGEBOTS-BEDINGUNG: ein solcher Charm liegt nur im Laden (Auslage,
## Schwarzmarkt, Automat), wenn diese Seele wirklich im Pool steckt - sonst wäre
## er eine tote Karte, und zwanzig tote Karten verdünnen den Topf.
## Der Quecksilberdampf-Charm steht bewusst NICHT hier: er gehört keiner
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
	SWAMP_LANTERN: Essence.WILL_O_WISP,
	IGNITION_COIL: Essence.PLASMA,
	BELL_JAR: Essence.VACUUM,
	SOLAR_ECLIPSE: Essence.CORONA,
	GLAZE_BRUSH: Essence.VARNISH,
	FLUORESCENT_TUBE: Essence.PHOSPHORESCENCE,
	POLARIZER: Essence.AURORA,
	ALKAHEST: Essence.QUINTESSENCE,
	MAGNETIC_TRAP: Essence.ANTIMATTER,
}

## Essenz, die dieser Charm voraussetzt ("" = keine).
static func essence_requirement(charm_id: String) -> String:
	return String(ESSENCE_REQUIREMENT.get(charm_id, ""))

## Die Charms, die dem Spieler überhaupt angeboten werden dürfen: alles ohne
## Essenz-Bedingung plus die, deren Seele er besitzt. EINE Quelle für Auslage,
## Schwarzmarkt und Automat.
static func offerable(pool: Array[Charm], owned_essence_ids: Array[String]) -> Array[Charm]:
	var out: Array[Charm] = []
	for charm in pool:
		var needed := essence_requirement(charm.id)
		if needed == "" or owned_essence_ids.has(needed):
			out.append(charm)
	return out

## Konvention: Modell-Dateiname = Charm-id (rabbits_foot.glb, ...). Fehlt die
## Datei, bleibt model_path leer und CharmRowView zeigt den Platzhalter.
const MODEL_DIR := "res://assets/models/"

# Raritäten: steuern Shop-Häufigkeit (rarity_weight/pick_weighted) und die
# Lichtkegel-Farbe auf dem Tisch (rarity_color/CharmRowView).
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
	GOLDEN_SCARAB: RARITY_COMMON,
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
	SMALL_FRY: RARITY_COMMON,
	BEHERIT: RARITY_UNCOMMON,
	HIGH_STACKER: RARITY_UNCOMMON,
	PRIME_TIME: RARITY_RARE,
	FRONT_RUNNER: RARITY_COMMON,
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
	LIGHTHOUSE: RARITY_COMMON,
	MOMENTUM: RARITY_RARE,
	AFTER_WORK_BEER: RARITY_RARE,
	BLACKJACK: RARITY_COMMON,
	ROUND_NUMBER: RARITY_COMMON,
	BROADBAND: RARITY_COMMON,
	EVEN_COMPANY: RARITY_UNCOMMON,
	ODD_PATH: RARITY_UNCOMMON,
	SNAKE_EYES: RARITY_COMMON,
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
	RUBY_GRINDER: RARITY_UNCOMMON,
	BLOOD_DIAMOND: RARITY_UNCOMMON,
	BONE_GLUE: RARITY_UNCOMMON,
	BONE_MARROW: RARITY_UNCOMMON,
	GLASSBLOWER_LUNG: RARITY_COMMON,
	MERCURY_VAPOR: RARITY_LEGENDARY,
	DISPLAY_CASE: RARITY_RARE,
	JEWELRY_BOX: RARITY_RARE,
	# Coupons & Packs
	BARGAIN_HUNTER: RARITY_COMMON,
	ENGRAVING_PEN: RARITY_RARE,
	STAMP_MACHINE: RARITY_RARE,
	FINE_PRINT: RARITY_UNCOMMON,
	# Pool & Trays
	RECYCLING: RARITY_UNCOMMON,
	FRESH_GOODS: RARITY_COMMON,
	SEDIMENT: RARITY_UNCOMMON,
	# Shop & Angebote
	CON_ARTIST_CUFF: RARITY_COMMON,
	SEAL_OF_QUALITY: RARITY_UNCOMMON,
	BULK_DISCOUNT: RARITY_COMMON,
	# Meta & Totem-Reihe
	COLLECTORS_AMULET: RARITY_UNCOMMON,
	PARROT_TOTEM: RARITY_LEGENDARY,
	ECHO_TOTEM: RARITY_LEGENDARY,
	HERMIT_CRAB: RARITY_COMMON,
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
	SWAMP_LANTERN: RARITY_RARE,
	IGNITION_COIL: RARITY_RARE,
	BELL_JAR: RARITY_RARE,
	SOLAR_ECLIPSE: RARITY_RARE,
	GLAZE_BRUSH: RARITY_RARE,
	FLUORESCENT_TUBE: RARITY_LEGENDARY,
	POLARIZER: RARITY_LEGENDARY,
	ALKAHEST: RARITY_LEGENDARY,
	MAGNETIC_TRAP: RARITY_LEGENDARY,
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
	return _make(RABBITS_FOOT, "Hasenpfote", "Jede gewürfelte 6 löst ein weiteres Mal aus.")

static func lucky_cigarettes() -> Charm:
	return _make(LUCKY_CIGARETTES, "Glückszigaretten", "Jede gewürfelte 1 zählt als 6 - auch für Kombinationen.")

static func four_leaf_clover() -> Charm:
	return _make(FOUR_LEAF_CLOVER, "Vierblättriges Kleeblatt", "Jede gewürfelte 4 löst ihren Würfel ein zweites Mal aus.")

static func golden_scarab() -> Charm:
	return _make(GOLDEN_SCARAB, "Goldener Skarabäus", "Jede gewürfelte 5 löst ein weiteres Mal aus.")

static func fox_tail() -> Charm:
	return _make(FOX_TAIL, "Fuchsschwanz", "Jede gewürfelte 3 zählt als 4 - auch für Kombinationen.")

static func pencil_stub() -> Charm:
	return _make(PENCIL_STUB, "Croupier-Bleistift", "Jede gewürfelte 2 zählt als 3 - auch für Kombinationen.")

static func top_hat() -> Charm:
	return _make(TOP_HAT, "Zylinderhut", "Jede gewürfelte 4 zählt als 5 - auch für Kombinationen.")

static func silver_dollar() -> Charm:
	return _make(SILVER_DOLLAR, "Silberdollar", "Jede gewürfelte 5 zählt als 6 - auch für Kombinationen.")

## Gravuren treiben Seiten über die 6 - der Knoten zieht beide Nachbarn zur 8.
static func eight_knot() -> Charm:
	return _make(EIGHT_KNOT, "Achterknoten", "Jede gewürfelte 7 und 9 zählt als 8 - auch für Kombinationen.")

# --- Wertungs-Charms ---

static func horseshoe() -> Charm:
	return _make(HORSESHOE, "Hufeisen", "Full House erhält +12 Mult.")

static func ladybug() -> Charm:
	return _make(LADYBUG, "Marienkäfer", "Paar erhält +4 Mult.")

static func pearl_necklace() -> Charm:
	return _make(PEARL_NECKLACE, "Perlenkette", "Dreierpasch erhält +8 Mult.")

static func magic_card() -> Charm:
	return _make(MAGIC_CARD, "Zauberkarte", "Die erste genommene Hand jeder Runde zählt doppelt.")

static func rainbow_trout() -> Charm:
	return _make(RAINBOW_TROUT, "Regenbogenforelle", "Kleine und Große Straße geben +10 Mult.")

# --- Geld-Charms ---

static func old_penny() -> Charm:
	return _make(OLD_PENNY, "Glücksgroschen", "+$3 am Rundenende - nach jeder Auszahlung $1 mehr.")

static func piggy_bank() -> Charm:
	return _make(PIGGY_BANK, "Sparschwein", "Übrige Würfel zahlen 2$ statt 1$.")

static func crystal_ball() -> Charm:
	return _make(CRYSTAL_BALL, "Kristallkugel", "+7$ für jeden überlebten Farkle.")

# --- Farkle-Charms ---

static func chimney_sweep() -> Charm:
	return _make(CHIMNEY_SWEEP, "Schornsteinfeger", "Der erste Farkle jeder Runde wird verziehen.")

# --- Pool-/Shop-Charms ---

static func con_artist_cuff() -> Charm:
	return _make(CON_ARTIST_CUFF, "Trickdieb-Manschette", "Würfel im Shop kosten 33% weniger.")

# --- Meta-Charm ---

static func collectors_amulet() -> Charm:
	return _make(COLLECTORS_AMULET, "Sammler-Amulett", "Jeder andere Charm gibt +2 Mult auf jede gewertete Hand.")

# === Effektkatalog-Charms ====================================================

# --- Wurf & Neuwurf ---

static func pendulum() -> Charm:
	return _make(PENDULUM, "Pendel", "+2 Mult je neu geworfenem Würfel, −1 je genommenem Würfel (nie unter 0). Der Mult bleibt über Runden erhalten.")

static func all_or_nothing() -> Charm:
	return _make(ALL_OR_NOTHING, "Alles-oder-nichts", "Wirfst du alle 6 Würfel neu, bekommt die nächste genommene Hand +5 Mult - stapelt, wird beim Nehmen zurückgesetzt.")

static func anchor() -> Charm:
	return _make(ANCHOR, "Anker", "Der erste Neuwurf jeder Hand kann nicht farkeln.")

# --- Augen & Werte ---

static func echo_chamber() -> Charm:
	return _make(ECHO_CHAMBER, "Echo-Kammer", "Der zuerst gewertete Würfel löst ein zweites Mal aus - Augen und Material.")

static func twin_ring() -> Charm:
	return _make(TWIN_RING, "Zwillingsring", "Jedes Paar im Wurf erhöht den Mult um die höchste Augenzahl des Paars.")

static func cult_of_one() -> Charm:
	return _make(CULT_OF_ONE, "Einserkult", "Jede gewürfelte 1 verdoppelt Basiswert UND Multiplikator der Hand.")

static func street_sweeper() -> Charm:
	return _make(STREET_SWEEPER, "Straßenkehrer", "In Straßen gibt jeder Würfel +6 Basispunkte.")

static func equalizer() -> Charm:
	return _make(EQUALIZER, "Gleichmacher", "Jeder beteiligte Würfel gibt mindestens 10 Basispunkte.")

static func small_fry() -> Charm:
	return _make(SMALL_FRY, "Kleinvieh", "Jede beteiligte 1 und 2 gibt +10 Basispunkte.")

static func beherit() -> Charm:
	return _make(BEHERIT, "Beherit", "Krit in Höhe der NIEDRIGSTEN gewerteten Augenzahl - eine gewertete 1 lässt ihn ausfallen.")

static func high_stacker() -> Charm:
	return _make(HIGH_STACKER, "Hochstapler", "+Mult in Höhe der höchsten gewerteten Augenzahl.")

static func prime_time() -> Charm:
	return _make(PRIME_TIME, "Prime Time", "Jeder gewertete Würfel mit Primzahl-Augen (2, 3, 5, 7, ...) gibt seine Augenzahl als Mult.")

static func front_runner() -> Charm:
	return _make(FRONT_RUNNER, "Vorreiter", "Der zuerst gewertete Würfel gibt zusätzlich die Augensumme ALLER gewerteten Würfel als Basispunkte.")

# --- Kombinationen & Wertung ---

static func house_joker() -> Charm:
	return _make(HOUSE_JOKER, "Hausjoker", "+4 Mult auf jede gewertete Hand.")

static func free_drink() -> Charm:
	return _make(FREE_DRINK, "Gratis Getränk", "+50 Basispunkte auf jede gewertete Hand.")

static func spotlight() -> Charm:
	return _make(SPOTLIGHT, "Rampenlicht", "Jede Runde stellt das Casino eine Kombination ins Rampenlicht (ihr Chip pulst golden). Wertest du sie in dieser Runde, steigt sie dauerhaft eine Stufe.")

static func full_counter() -> Charm:
	return _make(FULL_COUNTER, "Vollzähler", "ALLE liegenden Würfel werden gewertet: auch außerhalb der Kombination lösen sie Augen, Material und Würfel-Charms aus.")

static func lighthouse() -> Charm:
	return _make(LIGHTHOUSE, "Leuchtturm", "+Mult in Höhe des höchsten gewerteten Würfels.")

static func momentum() -> Charm:
	return _make(MOMENTUM, "Momentum", "+1 Mult je genommener Hand in Folge ohne Farkle (ein Farkle setzt zurück).")

static func after_work_beer() -> Charm:
	return _make(AFTER_WORK_BEER, "Feierabendbier", "Liegt kein Würfel mehr im Nachziehstapel: ein Krit: ×4.")

static func blackjack() -> Charm:
	return _make(BLACKJACK, "Blackjack", "Ergeben die gewerteten Würfel zusammen genau 21 Augen: +50 Basispunkte.")

static func round_number() -> Charm:
	return _make(ROUND_NUMBER, "Runde Sache", "Endet die Augensumme der genommenen Kombination auf 0: +100 Basispunkte.")

static func broadband() -> Charm:
	return _make(BROADBAND, "Breitband", "+5 Basispunkte je Würfel in der Kombination.")

static func even_company() -> Charm:
	return _make(EVEN_COMPANY, "Gerade Gesellschaft", "Liegen nur gerade Augenzahlen: +6 Mult.")

static func odd_path() -> Charm:
	return _make(ODD_PATH, "Schiefe Bahn", "Liegen nur ungerade Augenzahlen: +5 Mult.")

static func snake_eyes() -> Charm:
	return _make(SNAKE_EYES, "Snake Eyes", "Ist die Kombination genau ein Paar 1er: Mult += Augensumme aller unbeteiligten Würfel.")

# --- Farkle ---

static func broken_mirror() -> Charm:
	return _make(BROKEN_MIRROR, "Zerbrochener Spiegel", "Jeder Farkle erhöht den Multiplikator aller Hände dauerhaft um +1.")

static func grandfather_clock() -> Charm:
	return _make(GRANDFATHER_CLOCK, "Standuhr", "Bei einem Farkle verdoppeln sich die aktuellen Rundenpunkte (die Hand ist trotzdem verloren).")

static func shard_court() -> Charm:
	return _make(SHARD_COURT, "Scherbengericht", "Ein Farkle zahlt $2 je verworfenem Würfel.")

static func gallows_humor() -> Charm:
	return _make(GALLOWS_HUMOR, "Galgenhumor", "Die erste genommene Hand nach einem Fumble bekommt einen Krit: ×4.")

static func phoenix_feather() -> Charm:
	return _make(PHOENIX_FEATHER, "Phönixfeder", "Beim ersten Fumble jeder Runde kehrt die ganze Hand ans Ende des Nachziehstapels zurück statt in die Ablage.")

static func patchwork_rug() -> Charm:
	return _make(PATCHWORK_RUG, "Flickenteppich", "Bei einem Fumble bleibt der Würfel mit der höchsten Augenzahl gehalten liegen.")

# --- Geld ---

static func gold_rush() -> Charm:
	return _make(GOLD_RUSH, "Goldrausch", "Nutzt die ERSTE genommene Hand der Runde alle liegenden Würfel, wächst dein Geld um 20% (max. $50).")

static func rag_collector() -> Charm:
	return _make(RAG_COLLECTOR, "Lumpensammler", rag_collector_description(0))

## Beschreibung mit der aktuell gewürfelten Glückszahl; 0 = noch keine (Shop).
static func rag_collector_description(value: int) -> String:
	var base := "Würfelt jede Runde eine Glückszahl (1-6): jeder abgelegte Würfel mit diesem Wert oben zahlt $4."
	if value >= 1 and value <= 6:
		return "%s\nGlückszahl diese Runde: %d." % [base, value]
	return base

static func interest_penny() -> Charm:
	return _make(INTEREST_PENNY, "Zinsgroschen", "Am Rundenende +$1 je volle $10 Besitz (max. $20).")

static func street_musician() -> Charm:
	return _make(STREET_MUSICIAN, "Straßenmusiker", "Jede genommene Hand zahlt $1 pro beteiligtem Würfel.")

static func emergency_fund() -> Charm:
	return _make(EMERGENCY_FUND, "Notgroschen", "Fällst du am Rundenende unter $25, wird auf $25 aufgefüllt.")

static func cash_discount() -> Charm:
	return _make(CASH_DISCOUNT, "Skonto", "Charms kosten $5 weniger.")

static func high_flyer() -> Charm:
	return _make(HIGH_FLYER, "Überflieger", "Je geräumte Überladungs-Stufe: +$5.")

# --- Materialien (Seiten) ---

static func midas_glove() -> Charm:
	return _make(MIDAS_GLOVE, "Midashandschuh", "Nutzt eine genommene Hand alle sechs Würfel, wird jede oben liegende Seite dauerhaft Gold.")

static func gold_vein() -> Charm:
	return _make(GOLD_VEIN, "Goldader", "Jeder auslösende Gold-Träger (Seite wie Kante) zahlt zusätzlich $1 je anderem Material-Träger der Kombination - $3, wenn dieser selbst Gold ist.")

static func goldsmith() -> Charm:
	return _make(GOLDSMITH, "Goldschmied", "Gold-Seiten zahlen $6 statt $3.")

static func amber_room() -> Charm:
	return _make(AMBER_ROOM, "Bernsteinzimmer", "Bernstein gibt +50 statt +20 Basispunkte.")

static func ruby_grinder() -> Charm:
	return _make(RUBY_GRINDER, "Rubinschleifer", "Rubin gibt zusätzlich zu seinen +4 Mult die Augenzahl seines Würfels als Mult.")

static func blood_diamond() -> Charm:
	return _make(BLOOD_DIAMOND, "Blood Diamond", "Jede Rubin-Auslösung gibt zusätzlich die Augenzahl ihres Würfels als Mult - je Exemplar erneut.")

static func bone_marrow() -> Charm:
	return _make(BONE_MARROW, "Knochenmark", "Jede Knochen-Auslösung feuert einmal öfter - je Exemplar erneut.")

static func bone_glue() -> Charm:
	return _make(BONE_GLUE, "Knochenleim", "Knochen wächst +2 statt +1.")

static func glassblower_lung() -> Charm:
	return _make(GLASSBLOWER_LUNG, "Glasbläserlunge", "Glas schrumpft nie unter 6.")

static func mercury_vapor() -> Charm:
	return _make(MERCURY_VAPOR, "Quecksilberdampf", "Essenzen, die den Würfel mehrfach auslösen, lösen ihn ein weiteres Mal aus.")

static func display_case() -> Charm:
	return _make(DISPLAY_CASE, "Vitrine", "+1 Mult je oben liegender Material-Seite.")

static func jewelry_box() -> Charm:
	return _make(JEWELRY_BOX, "Schmuckkästchen", "Bei der Auszahlung der übrigen Würfel nach dem Rundenziel: jeder übrige Würfel erhält mit 10% Chance eine zufällige Material-Seite (dauerhaft).")

# --- Coupons & Packs ---

static func bargain_hunter() -> Charm:
	return _make(BARGAIN_HUNTER, "Schnäppchenjäger", "Alle Pakete kosten $3 weniger.")

static func engraving_pen() -> Charm:
	return _make(ENGRAVING_PEN, "Gravierstift", "Einmal pro Runde wird ein Zahl-Gravur beim Anwenden nicht verbraucht.")

static func stamp_machine() -> Charm:
	return _make(STAMP_MACHINE, "Frankiermaschine", "Am Rundenende, +3 Gravuren.")

static func fine_print() -> Charm:
	return _make(FINE_PRINT, "Kleingedrucktes", "Nach jedem Pack-Kauf: 20% Chance auf volle Rückerstattung.")

# --- Pool & Trays ---

static func recycling() -> Charm:
	return _make(RECYCLING, "Recycling", "Einmal je Runde kehrt die erste genommene Hand ans Ende des Nachziehstapels zurück.")

static func fresh_goods() -> Charm:
	return _make(FRESH_GOODS, "Frische Ware", "Würfel mit Material liegen nach dem Mischen ganz vorn im Nachziehstapel.")

static func sediment() -> Charm:
	return _make(SEDIMENT, "Bodensatz", "Die letzten 6 Würfel des Nachziehstapels geben +3 Mult, wenn sie beteiligt sind.")

# --- Shop & Angebote ---

static func seal_of_quality() -> Charm:
	return _make(SEAL_OF_QUALITY, "Gütesiegel", "Würfel-Angebote im Shop sind immer veredelt (mind. eine Material-Seite).")

static func bulk_discount() -> Charm:
	return _make(BULK_DISCOUNT, "Mengenrabatt", "3er-Würfelbündel kosten $5 weniger und treten öfter auf.")

# --- Meta & Totem-Reihe ---

static func parrot_totem() -> Charm:
	return _make(PARROT_TOTEM, "Papagei-Totem", "Kopiert die Wirkung des Charms LINKS von ihm.")

static func echo_totem() -> Charm:
	return _make(ECHO_TOTEM, "Echo-Totem", "Kopiert die Wirkung des Charms RECHTS von ihm.")

static func hermit_crab() -> Charm:
	return _make(HERMIT_CRAB, "Einsiedlerkrebs", "Besitzt du höchstens 2 Charms, +6 Mult.")

# --- Essenz-Charms (je einer ab "selten"; Bedingung siehe ESSENCE_REQUIREMENT) ---

static func amalgam() -> Charm:
	return _make(AMALGAM, "Amalgam", "Quecksilberdampf färbt ab: der nächste Würfel der Zählreihenfolge löst +1× aus.")

static func lead_apron() -> Charm:
	return _make(LEAD_APRON, "Bleischürze", "Radon zerfällt nicht mehr, und sein Strahlenbonus steigt auf +3 Augen je Mitwürfel.")

static func storm_glass() -> Charm:
	return _make(STORM_GLASS, "Sturmglas", "Für Elmsfeuer gilt JEDE Runde als Stresstest.")

static func lightning_rod() -> Charm:
	return _make(LIGHTNING_ROD, "Blitzableiter", "Jeder Kugelblitz kritet ×2 plus 1 je gewertetem Kugelblitz-Würfel.")

static func darkroom() -> Charm:
	return _make(DARKROOM, "Dunkelkammer", "Photonengas sammelt auch die Auslösungen der bisherigen Hände dieser Runde.")

static func pressure_vessel() -> Charm:
	return _make(PRESSURE_VESSEL, "Druckkessel", "Strahlungsdruck bläht jede Seite um 20% auf statt um 2.")

static func aqua_fortis() -> Charm:
	return _make(AQUA_FORTIS, "Scheidewasser", "Zyanidgas laugt die ganze Hand aus: +$1 je Gold-Seite jedes ANDEREN gewerteten Würfels.")

static func contrast_agent() -> Charm:
	return _make(CONTRAST_AGENT, "Kontrastmittel", "Wertet ein Röntgenlicht, halbiert sich seine obere Seite dauerhaft und seine Gegenseite verdreifacht sich.")

static func censer() -> Charm:
	return _make(CENSER, "Räucherwerk", "Der Miasma-Würfel steckt die Hand weiter an, ohne selbst zu verlieren.")

static func solar_sail() -> Charm:
	return _make(SOLAR_SAIL, "Sonnensegel", "Sonnenwind löst +2× aus je VERSCHIEDENER Essenz, die in dieser Hand vor ihm zählte.")

static func storm_front() -> Charm:
	return _make(STORM_FRONT, "Gewitterfront", "Auch die Krits der bisherigen Hände dieser Runde zählen in Ozons Krit.")

static func swamp_lantern() -> Charm:
	return _make(SWAMP_LANTERN, "Sumpflaterne", "Irrlicht darf beliebig oft gekippt werden statt einmal je Runde.")

static func ignition_coil() -> Charm:
	return _make(IGNITION_COIL, "Zündspule", "Jedes gezündete Leiterbahn-Glied eines Plasma-Würfels feuert seine Zielseite zweimal.")

static func bell_jar() -> Charm:
	return _make(BELL_JAR, "Glasglocke", "Jede Seite eines Vakuum-Würfels trägt einen dritten Riss.")

static func solar_eclipse() -> Charm:
	return _make(SOLAR_ECLIPSE, "Sonnenfinsternis", "Der Korona-Ring wertet drei Nachbarseiten mit statt einer.")

static func glaze_brush() -> Charm:
	return _make(GLAZE_BRUSH, "Lasurpinsel", "Trifft der Firnis eine Seite, die schon Stufe III trägt, wandert stattdessen eine Kopie ihres Materials in den Vorrat.")

static func fluorescent_tube() -> Charm:
	return _make(FLUORESCENT_TUBE, "Leuchtstoffröhre", "Die Phosphoreszenz speichert zusätzlich jeden Mult, den sie erarbeitet hat, und zahlt ihn erneut aus.")

static func polarizer() -> Charm:
	return _make(POLARIZER, "Polarfilter", "Das Polarlicht kritet mit der Zahl, zu der es sich für die Kombination macht.")

static func alkahest() -> Charm:
	return _make(ALKAHEST, "Alkahest", "Die Quintessenz borgt auch die Seelen der Würfel in der Ablage dieser Runde.")

static func magnetic_trap() -> Charm:
	return _make(MAGNETIC_TRAP, "Magnetfalle", "Die Augen der Antimaterie zählen nicht mehr negativ - ihr Krit bleibt.")

## Kanonische Registrierung aller Charm-Archetypen - ein neuer Charm wird
## hier eingehängt.
static func all() -> Array[Charm]:
	return [
		rabbits_foot(), lucky_cigarettes(), four_leaf_clover(), golden_scarab(), fox_tail(), pencil_stub(),
		top_hat(), silver_dollar(), eight_knot(),
		horseshoe(), ladybug(), pearl_necklace(), magic_card(), rainbow_trout(),
		old_penny(), piggy_bank(), crystal_ball(),
		chimney_sweep(),
		con_artist_cuff(),
		collectors_amulet(),
		# Effektkatalog
		pendulum(), all_or_nothing(), anchor(),
		echo_chamber(), twin_ring(), cult_of_one(), street_sweeper(), equalizer(), small_fry(),
		beherit(), high_stacker(), prime_time(), front_runner(),
		house_joker(), free_drink(), spotlight(),
		full_counter(), lighthouse(), momentum(), after_work_beer(), blackjack(),
		round_number(), broadband(), even_company(), odd_path(), snake_eyes(),
		broken_mirror(), grandfather_clock(), shard_court(), gallows_humor(), phoenix_feather(), patchwork_rug(),
		gold_rush(), rag_collector(), interest_penny(), street_musician(), emergency_fund(),
		cash_discount(), high_flyer(),
		midas_glove(), gold_vein(), goldsmith(), amber_room(),
		ruby_grinder(), blood_diamond(), bone_glue(), bone_marrow(), glassblower_lung(), mercury_vapor(),
		display_case(), jewelry_box(),
		bargain_hunter(), engraving_pen(), stamp_machine(), fine_print(),
		recycling(), fresh_goods(), sediment(),
		seal_of_quality(), bulk_discount(),
		parrot_totem(), echo_totem(), hermit_crab(),
		# Essenz-Charms
		amalgam(), lead_apron(), storm_glass(), lightning_rod(), darkroom(),
		pressure_vessel(), aqua_fortis(), contrast_agent(),
		censer(), solar_sail(), storm_front(), swamp_lantern(), ignition_coil(),
		bell_jar(), solar_eclipse(), glaze_brush(), fluorescent_tube(),
		polarizer(), alkahest(), magnetic_trap(),
	]
