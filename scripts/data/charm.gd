class_name Charm
extends Resource
## Datensatz für einen Charm: eine eigenständige Sammelkategorie neben den
## geplanten Jokern (siehe Obsidian-Konzept "08 Joker"), aber mit demselben
## Aufbau - Anzeige-Infos hier, die eigentliche Wirkung zentral über die id
## aufgelöst (siehe scripts/charm_effects.gd). Anders als Joker (die ganze
## Kombinationen/Runden beeinflussen sollen) sitzen Charms näher am einzelnen
## Würfel - kleine, thematische Glücksbringer wie eine Hasenpfote oder eine
## Packung Glückszigaretten.
##
## Ein neuer Charm braucht genau zwei Stellen: eine Fabrikmethode hier (plus
## einen Eintrag in all()) und die zugehörige Wirkung in CharmEffects, jeweils
## über dieselbe id verdrahtet. Die id ist NICHT als roher String verstreut,
## sondern einmal als Konstante definiert (siehe unten) und überall darüber
## referenziert - so wird ein Tippfehler zum Compilerfehler statt zu einem
## stillen Wirkungslosigkeits-Bug (die id würde sonst in keinem match greifen).

# --- Charm-ids (Single Source of Truth; in charm.gd + charm_effects.gd genutzt) ---
const RABBITS_FOOT := "rabbits_foot"
const LUCKY_CIGARETTES := "lucky_cigarettes"
const FOUR_LEAF_CLOVER := "four_leaf_clover"
const GOLDEN_SCARAB := "golden_scarab"
const FOX_TAIL := "fox_tail"
const PENCIL_STUB := "pencil_stub"
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
const LUCKY_KNOT := "lucky_knot"
const COLLECTORS_AMULET := "collectors_amulet"

# --- Effektkatalog-Charms (siehe Obsidian "12 Charms - Effektkatalog") ---
# Wurf & Neuwurf
const PENDULUM := "pendulum"
const ALL_OR_NOTHING := "all_or_nothing"
const ANCHOR := "anchor"
const STRAGGLER := "straggler"
# Augen & Werte
const ECHO_CHAMBER := "echo_chamber"
const TWIN_RING := "twin_ring"
const DOUBLE_SIX := "double_six"
const CULT_OF_ONE := "cult_of_one"
const STREET_SWEEPER := "street_sweeper"
const EQUALIZER := "equalizer"
const SMALL_FRY := "small_fry"
# Kombinationen & Wertung
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
const SMALL_CHANGE := "small_change"
const EMERGENCY_FUND := "emergency_fund"
const CASH_DISCOUNT := "cash_discount"
const HIGH_FLYER := "high_flyer"
# Materialien (Seiten)
const GOLDSMITH := "goldsmith"
const AMBER_ROOM := "amber_room"
const RUBY_GRINDER := "ruby_grinder"
const BONE_GLUE := "bone_glue"
const GLASSBLOWER_LUNG := "glassblower_lung"
const MERCURY_VAPOR := "mercury_vapor"
const DISPLAY_CASE := "display_case"
const JEWELRY_BOX := "jewelry_box"
const ALLOY := "alloy"
# Kanten
const FRAME_GILDER := "frame_gilder"
const MAGNET_RING := "magnet_ring"
const EDGE_GLEAM := "edge_gleam"
# Gerichte & Menü-Stufen
const REGULAR_GUEST := "regular_guest"
const GOURMET := "gourmet"
const MIDNIGHT_SNACK := "midnight_snack"
const RESTAURANT_CRITIC := "restaurant_critic"
const HOUSE_RECIPE := "house_recipe"
# Coupons & Packs
const LARGE_FORMAT := "large_format"
const BARGAIN_HUNTER := "bargain_hunter"
const DOUBLE_PERFORATION := "double_perforation"
const ENGRAVING_PEN := "engraving_pen"
const STAMP_MACHINE := "stamp_machine"
const FINE_PRINT := "fine_print"
# Pool & Trays
const RECYCLING := "recycling"
const FRESH_GOODS := "fresh_goods"
const SEDIMENT := "sediment"
const EXTENSION_TABLE := "extension_table"
# Shop & Angebote
const SEAL_OF_QUALITY := "seal_of_quality"
const BULK_DISCOUNT := "bulk_discount"
const HOUSE_BRAND := "house_brand"
# Meta & Totem-Reihe
const PARROT_TOTEM := "parrot_totem"
const ECHO_TOTEM := "echo_totem"
const HERMIT_CRAB := "hermit_crab"

## Ordner der Charm-Modelle (siehe CharmRowView, das sie auf dem Tisch zeigt).
## Konvention: Dateiname = Charm-id (rabbits_foot.glb, horseshoe.glb, ...) -
## ein neuer Charm braucht keine Modell-Registrierung, nur die richtig benannte
## Datei. Fehlt sie (aktuell OLD_PENNY; lucky_knot.glb ist eine goldene Hand
## als Ersatzmodell), bleibt model_path leer und CharmRowView zeigt das
## Platzhalter-Modell (siehe MODEL_FALLBACK).
const MODEL_DIR := "res://assets/models/"

# --- Raritäten (siehe Obsidian "12 Charms - Effektkatalog": Abschnitt
# "Raritäten") - bemessen an der Stärke des Charms. Die Rarität steuert, wie
# oft ein Charm im Shop auftaucht (siehe rarity_weight/pick_weighted und
# ShopController._build_spread) und färbt seinen Hologramm-Lichtkegel auf dem
# Tisch (siehe rarity_color/CharmRowView).
const RARITY_COMMON := "common"        # ⚪ Gewöhnlich
const RARITY_UNCOMMON := "uncommon"    # 🟢 Ungewöhnlich
const RARITY_RARE := "rare"            # 🔵 Selten
const RARITY_LEGENDARY := "legendary"  # 🟣 Legendär

## Rarität je Charm-id - 1:1 die Katalog-Tabellen aus dem Obsidian (Vorlage).
## Jeder Charm in all() MUSS hier stehen (per Test abgesichert, siehe
## test_charm_catalog) - _make schlägt die Rarität nach, Standard COMMON.
## Ausziehtisch (EXTENSION_TABLE) hat im Katalog (noch) keine Rarität und ist
## hier als Ungewöhnlich eingeordnet (dauerhafter Solid-Nutzen).
const RARITIES := {
	# Wurf & Neuwurf
	PENDULUM: RARITY_UNCOMMON,
	ALL_OR_NOTHING: RARITY_UNCOMMON,
	ANCHOR: RARITY_RARE,
	STRAGGLER: RARITY_COMMON,
	# Augen & Werte
	RABBITS_FOOT: RARITY_COMMON,
	LUCKY_CIGARETTES: RARITY_COMMON,
	FOUR_LEAF_CLOVER: RARITY_COMMON,
	GOLDEN_SCARAB: RARITY_COMMON,
	FOX_TAIL: RARITY_COMMON,
	PENCIL_STUB: RARITY_COMMON,
	ECHO_CHAMBER: RARITY_UNCOMMON,
	TWIN_RING: RARITY_UNCOMMON,
	DOUBLE_SIX: RARITY_RARE,
	CULT_OF_ONE: RARITY_RARE,
	STREET_SWEEPER: RARITY_UNCOMMON,
	EQUALIZER: RARITY_COMMON,
	SMALL_FRY: RARITY_COMMON,
	# Kombinationen & Wertung
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
	SMALL_CHANGE: RARITY_COMMON,
	EMERGENCY_FUND: RARITY_COMMON,
	CASH_DISCOUNT: RARITY_UNCOMMON,
	HIGH_FLYER: RARITY_UNCOMMON,
	# Materialien (Seiten)
	GOLDSMITH: RARITY_UNCOMMON,
	AMBER_ROOM: RARITY_UNCOMMON,
	RUBY_GRINDER: RARITY_UNCOMMON,
	BONE_GLUE: RARITY_UNCOMMON,
	GLASSBLOWER_LUNG: RARITY_COMMON,
	MERCURY_VAPOR: RARITY_LEGENDARY,
	DISPLAY_CASE: RARITY_RARE,
	JEWELRY_BOX: RARITY_RARE,
	ALLOY: RARITY_RARE,
	# Kanten
	FRAME_GILDER: RARITY_UNCOMMON,
	MAGNET_RING: RARITY_UNCOMMON,
	EDGE_GLEAM: RARITY_UNCOMMON,
	# Gerichte & Menü-Stufen
	REGULAR_GUEST: RARITY_RARE,
	GOURMET: RARITY_UNCOMMON,
	MIDNIGHT_SNACK: RARITY_RARE,
	RESTAURANT_CRITIC: RARITY_LEGENDARY,
	HOUSE_RECIPE: RARITY_RARE,
	# Coupons & Packs
	LARGE_FORMAT: RARITY_RARE,
	BARGAIN_HUNTER: RARITY_COMMON,
	DOUBLE_PERFORATION: RARITY_UNCOMMON,
	ENGRAVING_PEN: RARITY_RARE,
	STAMP_MACHINE: RARITY_RARE,
	FINE_PRINT: RARITY_UNCOMMON,
	# Pool & Trays
	LUCKY_KNOT: RARITY_UNCOMMON,
	RECYCLING: RARITY_UNCOMMON,
	FRESH_GOODS: RARITY_COMMON,
	SEDIMENT: RARITY_UNCOMMON,
	EXTENSION_TABLE: RARITY_UNCOMMON,
	# Shop & Angebote
	CON_ARTIST_CUFF: RARITY_COMMON,
	SEAL_OF_QUALITY: RARITY_UNCOMMON,
	BULK_DISCOUNT: RARITY_COMMON,
	HOUSE_BRAND: RARITY_LEGENDARY,
	# Meta & Totem-Reihe
	COLLECTORS_AMULET: RARITY_UNCOMMON,
	PARROT_TOTEM: RARITY_LEGENDARY,
	ECHO_TOTEM: RARITY_LEGENDARY,
	HERMIT_CRAB: RARITY_COMMON,
}

## Wie oft eine Rarität im Shop auftaucht, relativ zueinander (siehe
## pick_weighted): Gewöhnlich am häufigsten, Legendär selten.
const RARITY_WEIGHTS := {
	RARITY_COMMON: 1.0,
	RARITY_UNCOMMON: 0.55,
	RARITY_RARE: 0.25,
	RARITY_LEGENDARY: 0.1,
}

## Signalfarbe je Rarität (klassisches Schema): Weiß / Grün / Blau / Violett -
## färbt u.a. den Hologramm-Lichtkegel auf dem Tisch (siehe CharmRowView).
const RARITY_COLORS := {
	RARITY_COMMON: Color(0.85, 0.9, 1.0),
	RARITY_UNCOMMON: Color(0.3, 1.0, 0.5),
	RARITY_RARE: Color(0.25, 0.55, 1.0),
	RARITY_LEGENDARY: Color(0.75, 0.35, 1.0),
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## Rarität (siehe RARITY_*-Konstanten) - aus RARITIES nachgeschlagen (in _make).
@export var rarity: String = RARITY_COMMON
## Pfad zum 3D-Modell dieses Charms (auf dem Tisch, siehe CharmRowView). Wird in
## _make per Konvention aus der id abgeleitet; Charms ohne Modelldatei bleiben
## leer und zeigen das Platzhalter-Modell.
@export var model_path: String = ""

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

## Shop-Gewicht dieses Charms (siehe RARITY_WEIGHTS).
func rarity_weight() -> float:
	return RARITY_WEIGHTS.get(rarity, 1.0)

## Signalfarbe dieser Rarität (siehe RARITY_COLORS).
func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS[RARITY_COMMON])

## Zieht einen Charm gewichtet nach Rarität aus candidates (Gewöhnliche
## erscheinen am häufigsten, Legendäre selten - siehe RARITY_WEIGHTS).
## Grundlage der Shop-Angebote (siehe ShopController._build_spread); candidates
## darf nicht leer sein.
static func pick_weighted(candidates: Array[Charm]) -> Charm:
	var total := 0.0
	for charm in candidates:
		total += charm.rarity_weight()
	var roll := randf() * total
	for charm in candidates:
		roll -= charm.rarity_weight()
		if roll <= 0.0:
			return charm
	return candidates.back()

# --- Augenwert-Charms: verändern, wie stark ein einzelner Würfelwert zur
# Augensumme zählt (siehe CharmEffects.eye_value), ohne je die Kategorie zu
# ändern. ---

## Verdoppelt den Augenwert jeder gewürfelten 6.
static func rabbits_foot() -> Charm:
	return _make(RABBITS_FOOT, "Hasenpfote", "Jede gewürfelte 6 zählt doppelt für die Augensumme.")

## Lässt jede gewürfelte 1 als 6 zählen.
static func lucky_cigarettes() -> Charm:
	return _make(LUCKY_CIGARETTES, "Glückszigaretten", "Jede gewürfelte 1 zählt als 6 für die Augensumme.")

## Verdoppelt den Augenwert jeder gewürfelten 4.
static func four_leaf_clover() -> Charm:
	return _make(FOUR_LEAF_CLOVER, "Vierblättriges Kleeblatt", "Jede gewürfelte 4 zählt doppelt für die Augensumme.")

## Verdoppelt den Augenwert jeder gewürfelten 5.
static func golden_scarab() -> Charm:
	return _make(GOLDEN_SCARAB, "Goldener Skarabäus", "Jede gewürfelte 5 zählt doppelt für die Augensumme.")

## Lässt jede gewürfelte 3 als 4 zählen.
static func fox_tail() -> Charm:
	return _make(FOX_TAIL, "Fuchsschwanz", "Jede gewürfelte 3 zählt als 4 für die Augensumme.")

## Lässt jede gewürfelte 2 als 3 zählen.
static func pencil_stub() -> Charm:
	return _make(PENCIL_STUB, "Croupier-Bleistift", "Jede gewürfelte 2 zählt als 3 für die Augensumme.")

# --- Wertungs-Charms: verändern Multiplikator, Bonuspunkte oder verdoppeln
# ganze Hände (siehe CharmEffects.mult_bonus/flat_bonus/score_multiplier). ---

## Full House bekommt +12 Multiplikator.
static func horseshoe() -> Charm:
	return _make(HORSESHOE, "Hufeisen", "Full House erhält +12 Mult.")

## Paar bekommt +4 Multiplikator.
static func ladybug() -> Charm:
	return _make(LADYBUG, "Marienkäfer", "Paar erhält +4 Mult.")

## Dreierpasch bekommt +8 Multiplikator.
static func pearl_necklace() -> Charm:
	return _make(PEARL_NECKLACE, "Perlenkette", "Dreierpasch erhält +8 Mult.")

## Die erste in einer Runde genommene Hand zählt doppelt.
static func magic_card() -> Charm:
	return _make(MAGIC_CARD, "Zauberkarte", "Die erste genommene Hand jeder Runde zählt doppelt.")

## Kleine und Große Straße geben je +10 Bonuspunkte.
static func rainbow_trout() -> Charm:
	return _make(RAINBOW_TROUT, "Regenbogenforelle", "Kleine und Große Straße geben +10 Punkte extra.")

# --- Geld-Charms: verändern die Auszahlung (siehe CharmEffects money-Hooks). ---

## +3$ extra je erreichtem Rundenziel, wächst um $1 je erreichtem Ziel.
static func old_penny() -> Charm:
	return _make(OLD_PENNY, "Glücksgroschen", "+3$ extra für jedes erreichte Rundenziel - steigt um $1 je erreichtem Rundenziel.")

## Übrige Würfel zahlen 2$ statt 1$.
static func piggy_bank() -> Charm:
	return _make(PIGGY_BANK, "Sparschwein", "Übrige Würfel zahlen 2$ statt 1$.")

## +7$ für jeden Farkle, den man überlebt (ohne die Runde zu verlieren).
static func crystal_ball() -> Charm:
	return _make(CRYSTAL_BALL, "Kristallkugel", "+7$ für jeden überlebten Farkle.")

# --- Farkle-Charms: mildern die Farkle-Strafe (siehe CharmEffects farkle-Hooks). ---

## Der erste Farkle jeder Runde wird verziehen (Hand läuft weiter).
static func chimney_sweep() -> Charm:
	return _make(CHIMNEY_SWEEP, "Schornsteinfeger", "Der erste Farkle jeder Runde wird verziehen.")

# --- Pool-/Shop-Charms: verändern Ziehreihenfolge, Poolgröße oder Preise
# (siehe CharmEffects pool-/shop-Hooks). ---

## Würfel im Shop kosten 33% weniger.
static func con_artist_cuff() -> Charm:
	return _make(CON_ARTIST_CUFF, "Trickdieb-Manschette", "Würfel im Shop kosten 33% weniger.")

## Jede Runde hat einen zusätzlichen Würfel im Pool.
static func lucky_knot() -> Charm:
	return _make(LUCKY_KNOT, "Glücksknoten", "Jede Runde hat einen zusätzlichen Würfel im Pool.")

# --- Meta-Charm: bezieht sich auf die anderen besessenen Charms. ---

## Jeder andere besessene Charm gibt +2 Mult auf jede gewertete Hand.
static func collectors_amulet() -> Charm:
	return _make(COLLECTORS_AMULET, "Sammler-Amulett", "Jeder andere Charm gibt +2 Mult auf jede gewertete Hand.")

# === Effektkatalog-Charms (siehe Obsidian "12 Charms - Effektkatalog") ==========
# Die Wirkungen liegen wie immer in CharmEffects (bzw. den dort genannten
# Hooks in MaterialEffects/GameRun/scene_root/Shop) - hier nur Metadaten.

# --- Wurf & Neuwurf ---

## +2 Mult je neu geworfenem Würfel dieser Hand, −1 Mult je genommenem Würfel
## (der gespeicherte Stand fällt nie unter 0).
static func pendulum() -> Charm:
	return _make(PENDULUM, "Pendel", "+2 Mult je neu geworfenem Würfel dieser Hand, −1 Mult je bereits genommenem Würfel dieser Runde (nie unter 0).")

## Alle 6 Würfel neu geworfen: +5 Mult auf die nächste genommene Hand (stapelt).
static func all_or_nothing() -> Charm:
	return _make(ALL_OR_NOTHING, "Alles-oder-nichts", "Wirfst du alle 6 Würfel neu, bekommt die nächste genommene Hand +5 Mult - stapelt, wird beim Nehmen zurückgesetzt.")

## Der erste Neuwurf jeder Hand kann nicht farkeln.
static func anchor() -> Charm:
	return _make(ANCHOR, "Anker", "Der erste Neuwurf jeder Hand kann nicht farkeln.")

## Der zuletzt zur Ruhe gekommene Würfel zählt ein zweites Mal.
static func straggler() -> Charm:
	return _make(STRAGGLER, "Nachzügler", "Der zuletzt zur Ruhe gekommene Würfel zählt seinen Augenwert ein zweites Mal, wenn er beteiligt ist.")

# --- Augen & Werte ---

## Der höchste Würfel des Wurfs zählt ein zweites Mal.
static func echo_chamber() -> Charm:
	return _make(ECHO_CHAMBER, "Echo-Kammer", "Der höchste Würfel des Wurfs zählt ein zweites Mal.")

## Jedes exakte Paar im Wurf erhöht den Mult um seine Augenzahl.
static func twin_ring() -> Charm:
	return _make(TWIN_RING, "Zwillingsring", "Jedes Paar im Wurf erhöht den Mult um die Augenzahl des Paars.")

## Jede 6 nach der zweiten in der Kombination: +1 Mult.
static func double_six() -> Charm:
	return _make(DOUBLE_SIX, "Doppelte Sechs", "Jede 6 nach der zweiten 6 in der genommenen Kombination erhöht den Mult um 1.")

## Jede gewürfelte 1 verdoppelt Basiswert UND Multiplikator.
static func cult_of_one() -> Charm:
	return _make(CULT_OF_ONE, "Einserkult", "Jede gewürfelte 1 verdoppelt Basiswert UND Multiplikator der Hand.")

## In Straßen zählt jeder Würfel +6 Augen.
static func street_sweeper() -> Charm:
	return _make(STREET_SWEEPER, "Straßenkehrer", "In Straßen zählt jeder Würfel +6 Augen.")

## Alle Würfel zählen mindestens 5 Augen.
static func equalizer() -> Charm:
	return _make(EQUALIZER, "Gleichmacher", "Der Augenwert jedes Würfels beträgt mindestens 5.")

## 1er und 2er zählen je +2 Augen.
static func small_fry() -> Charm:
	return _make(SMALL_FRY, "Kleinvieh", "Jede 1 und jede 2 zählt +2 Augen.")

# --- Kombinationen & Wertung ---

## ALLE liegenden Würfel zählen zum Basiswert.
static func full_counter() -> Charm:
	return _make(FULL_COUNTER, "Vollzähler", "ALLE liegenden Würfel zählen zum Basiswert - auch außerhalb der Kombination.")

## Höchste Zahl: Mult wächst um die höchste Augenzahl der Hand.
static func lighthouse() -> Charm:
	return _make(LIGHTHOUSE, "Leuchtturm", "Höchste Zahl erhält Mult in Höhe der höchsten Augenzahl der Hand.")

## +1 Mult je genommener Hand in Folge ohne Farkle.
static func momentum() -> Charm:
	return _make(MOMENTUM, "Momentum", "+1 Mult je genommener Hand in Folge ohne Farkle (ein Farkle setzt zurück).")

## Die letzte Hand jeder Runde zählt doppelt.
static func after_work_beer() -> Charm:
	return _make(AFTER_WORK_BEER, "Feierabendbier", "Die letzte Hand jeder Runde zählt doppelt.")

## Augensumme des Wurfs genau 21: +50 Bonus-Augen.
static func blackjack() -> Charm:
	return _make(BLACKJACK, "Blackjack", "Ist die Augensumme des Wurfs genau 21: +50 Bonus-Augen.")

## Augensumme der Hand endet auf 0: +100 Bonus-Augen.
static func round_number() -> Charm:
	return _make(ROUND_NUMBER, "Runde Sache", "Endet die Augensumme der genommenen Kombination auf 0: +100 Bonus-Augen.")

## +5 Basispunkte je Würfel in der Kombination.
static func broadband() -> Charm:
	return _make(BROADBAND, "Breitband", "+5 Basispunkte je Würfel in der Kombination.")

## Nur gerade Werte im Wurf: +6 Mult.
static func even_company() -> Charm:
	return _make(EVEN_COMPANY, "Gerade Gesellschaft", "Liegen nur gerade Augenzahlen: +6 Mult.")

## Nur ungerade Werte im Wurf: +5 Mult.
static func odd_path() -> Charm:
	return _make(ODD_PATH, "Schiefe Bahn", "Liegen nur ungerade Augenzahlen: +5 Mult.")

## Genau ein 1er-Paar genommen: Mult += Augensumme der Unbeteiligten.
static func snake_eyes() -> Charm:
	return _make(SNAKE_EYES, "Snake Eyes", "Ist die Kombination genau ein Paar 1er: Mult += Augensumme aller unbeteiligten Würfel.")

# --- Farkle ---

## Jeder Farkle erhöht den Multiplikator aller Hände dauerhaft um +1.
static func broken_mirror() -> Charm:
	return _make(BROKEN_MIRROR, "Zerbrochener Spiegel", "Jeder Farkle erhöht den Multiplikator aller Hände dauerhaft um +1.")

## Farkle verdoppelt die aktuellen Rundenpunkte.
static func grandfather_clock() -> Charm:
	return _make(GRANDFATHER_CLOCK, "Standuhr", "Bei einem Farkle verdoppeln sich die aktuellen Rundenpunkte (die Hand ist trotzdem verloren).")

## Farkle zahlt $2 je verworfenem Würfel.
static func shard_court() -> Charm:
	return _make(SHARD_COURT, "Scherbengericht", "Ein Farkle zahlt $2 je verworfenem Würfel.")

## Erste Hand nach einem Farkle: +3 Krit.
static func gallows_humor() -> Charm:
	return _make(GALLOWS_HUMOR, "Galgenhumor", "Die erste genommene Hand nach einem Farkle bekommt +3 Krit.")

## Bei jedem Farkle kehren die geworfenen Würfel in den Nachziehstapel zurück.
static func phoenix_feather() -> Charm:
	return _make(PHOENIX_FEATHER, "Phönixfeder", "Bei jedem Farkle kehrt die ganze Hand ans Ende des Nachziehstapels zurück statt in die Ablage.")

## Farkle behält die Höchste-Zahl-Wertung des Wurfs.
static func patchwork_rug() -> Charm:
	return _make(PATCHWORK_RUG, "Flickenteppich", "Bei einem Farkle bleibt die Wertung des Würfels mit der höchsten Augenzahl erhalten.")

# --- Geld ---

## Kombination aus allen liegenden Würfeln: Geld wächst um 50% (max. $50).
static func gold_rush() -> Charm:
	return _make(GOLD_RUSH, "Goldrausch", "Nutzt eine genommene Kombination alle liegenden Würfel, wächst dein Geld um 50% (max. $50).")

## Würfelt jede Runde eine Glückszahl; jeder abgelegte Würfel mit ihr zahlt $4.
static func rag_collector() -> Charm:
	return _make(RAG_COLLECTOR, "Lumpensammler", "Würfelt jede Runde eine Glückszahl (1-6): jeder abgelegte Würfel mit diesem Wert oben zahlt $4.")

## Rundenende: +$1 je volle $10 Besitz (max. $50).
static func interest_penny() -> Charm:
	return _make(INTEREST_PENNY, "Zinsgroschen", "Am Rundenende +$1 je volle $10 Besitz (max. $50).")

## Jede genommene Hand zahlt $1 je beteiligtem Würfel.
static func street_musician() -> Charm:
	return _make(STREET_MUSICIAN, "Straßenmusiker", "Jede genommene Hand zahlt $1 pro beteiligtem Würfel.")

## Blätter-Gebühren kosten $2 weniger.
static func small_change() -> Charm:
	return _make(SMALL_CHANGE, "Wechselgeld", "Blätter-Gebühren im Shop kosten $2 weniger (min. $1).")

## Rundenende unter $25: auf $25 aufgefüllt.
static func emergency_fund() -> Charm:
	return _make(EMERGENCY_FUND, "Notgroschen", "Fällst du am Rundenende unter $25, wird auf $25 aufgefüllt.")

## Charms kosten $5 weniger.
static func cash_discount() -> Charm:
	return _make(CASH_DISCOUNT, "Skonto", "Charms kosten $5 weniger.")

## Je 25 Rundenpunkte über dem Rundenziel: +$1 (max. $50).
static func high_flyer() -> Charm:
	return _make(HIGH_FLYER, "Überflieger", "Je 25 Rundenpunkte über dem Rundenziel: +$1 (max. $50).")

# --- Materialien (Seiten) ---

## Gold-Seiten zahlen $2 statt $1.
static func goldsmith() -> Charm:
	return _make(GOLDSMITH, "Goldschmied", "Gold-Seiten zahlen $2 statt $1.")

## Bernstein gibt +50 statt +20 Bonus-Augen.
static func amber_room() -> Charm:
	return _make(AMBER_ROOM, "Bernsteinzimmer", "Bernstein gibt +50 statt +20 Bonus-Augen.")

## Rubin gibt +10 statt +4 Mult.
static func ruby_grinder() -> Charm:
	return _make(RUBY_GRINDER, "Rubinschleifer", "Rubin gibt +10 statt +4 Mult.")

## Knochen wächst +2 statt +1.
static func bone_glue() -> Charm:
	return _make(BONE_GLUE, "Knochenleim", "Knochen wächst +2 statt +1.")

## Glas schrumpft nie unter 3.
static func glassblower_lung() -> Charm:
	return _make(GLASSBLOWER_LUNG, "Glasbläserlunge", "Glas schrumpft nie unter 3.")

## Quecksilber aktiviert dreifach statt doppelt.
static func mercury_vapor() -> Charm:
	return _make(MERCURY_VAPOR, "Quecksilberdampf", "Quecksilber aktiviert den Würfel dreifach statt doppelt.")

## +1 Mult je oben liegender Material-Seite.
static func display_case() -> Charm:
	return _make(DISPLAY_CASE, "Vitrine", "+1 Mult je oben liegender Material-Seite.")

## Rundenziel-Auszahlung: jeder übrige Würfel hat 10% Chance auf eine Material-Seite.
static func jewelry_box() -> Charm:
	return _make(JEWELRY_BOX, "Schmuckkästchen", "Bei der Auszahlung der übrigen Würfel nach dem Rundenziel: jeder übrige Würfel erhält mit 10% Chance eine zufällige Material-Seite (dauerhaft).")

## Seiten- UND Kanten-Material: beide Effekte feuern doppelt.
static func alloy() -> Charm:
	return _make(ALLOY, "Legierung", "Beteiligte Würfel mit Material-Seite oben UND Kanten-Material lösen Seiten- und Kanten-Effekte doppelt aus.")

# --- Kanten ---

## Gold-Kanten zahlen $2 je Wurf.
static func frame_gilder() -> Charm:
	return _make(FRAME_GILDER, "Rahmenvergolder", "Gold-Kanten zahlen $2 je Wurf.")

## Würfel mit Kanten-Material werden zuerst gezogen.
static func magnet_ring() -> Charm:
	return _make(MAGNET_RING, "Magnetring", "Würfel mit Kanten-Material werden je Runde zuerst gezogen.")

## Kanten-Würfel zählen +1 Auge je Kanten-Würfel im Wurf.
static func edge_gleam() -> Charm:
	return _make(EDGE_GLEAM, "Zargenglanz", "Würfel mit Kanten-Material zählen +1 Auge je Kanten-Würfel im Wurf.")

# --- Gerichte & Menü-Stufen ---

## Jedes Gericht zählt als zwei Menü-Stufen.
static func regular_guest() -> Charm:
	return _make(REGULAR_GUEST, "Stammgast", "Jedes gegessene Gericht zählt als zwei Menü-Stufen.")

## Tageskarte-Packs kosten die Hälfte.
static func gourmet() -> Charm:
	return _make(GOURMET, "Feinschmecker", "Tageskarte-Packs kosten die Hälfte.")

## Jede Runde ein zufälliges Gericht gratis.
static func midnight_snack() -> Charm:
	return _make(MIDNIGHT_SNACK, "Mitternachtssnack", "Zu Beginn jeder Runde isst du automatisch ein zufälliges Gericht gratis.")

## Aufgewertete Kombinationen: zusätzlich +2 Krit je Menü-Stufe.
static func restaurant_critic() -> Charm:
	return _make(RESTAURANT_CRITIC, "Restaurantkritiker", "Aufgewertete Kombinationen erhalten zusätzlich +2 Krit je Menü-Stufe.")

## Die meistaufgewertete Kombination steigt beim Nehmen erneut.
static func house_recipe() -> Charm:
	return _make(HOUSE_RECIPE, "Hausrezept", "Nimmst du die Kombination mit den meisten Menü-Stufen, steigt ihre Stufe erneut.")

# --- Coupons & Packs ---

## Alle Coupon-Packs sind 1×1 größer.
static func large_format() -> Charm:
	return _make(LARGE_FORMAT, "Großformat", "Alle Coupon-Packs sind 1×1 größer (2×2→3×3, 3×3→4×4, 5×5→6×6).")

## Coupon-Packs kosten $2 weniger.
static func bargain_hunter() -> Charm:
	return _make(BARGAIN_HUNTER, "Schnäppchenjäger", "Coupon-Packs kosten $2 weniger.")

## Chip-Coupons zahlen $2 statt $1.
static func double_perforation() -> Charm:
	return _make(DOUBLE_PERFORATION, "Doppelte Perforation", "Chip-Coupons zahlen $2 statt $1.")

## Einmal pro Runde wird ein Ätzungs-Coupon nicht verbraucht.
static func engraving_pen() -> Charm:
	return _make(ENGRAVING_PEN, "Gravierstift", "Einmal pro Runde wird ein Ätzungs-Coupon beim Anwenden nicht verbraucht.")

## Rundenbeginn: +3 zufällige Ätzungs-Coupons.
static func stamp_machine() -> Charm:
	return _make(STAMP_MACHINE, "Frankiermaschine", "Zu Beginn jeder Runde: +3 zufällige Ätzungs-Coupons.")

## Pack-Kauf: 20% Chance auf volle Rückerstattung.
static func fine_print() -> Charm:
	return _make(FINE_PRINT, "Kleingedrucktes", "Nach jedem Pack-Kauf: 20% Chance auf volle Rückerstattung.")

# --- Pool & Trays ---

## Die erste genommene Hand jeder Runde kehrt in den Nachziehstapel zurück.
static func recycling() -> Charm:
	return _make(RECYCLING, "Recycling", "Einmal je Runde kehrt die erste genommene Hand ans Ende des Nachziehstapels zurück.")

## Neu gekaufte Würfel liegen vorn im Nachziehstapel.
static func fresh_goods() -> Charm:
	return _make(FRESH_GOODS, "Frische Ware", "Neu gekaufte Würfel liegen ganz vorn im Nachziehstapel der nächsten Runde.")

## Die letzten 6 Würfel des Nachziehstapels zählen +5 Bonus-Augen.
static func sediment() -> Charm:
	return _make(SEDIMENT, "Bodensatz", "Die letzten 6 Würfel des Nachziehstapels zählen +5 Bonus-Augen, wenn sie beteiligt sind.")

## Rundenziel doppelt übertroffen: die Warteschlange wächst dauerhaft um +1 Platz.
static func extension_table() -> Charm:
	return _make(EXTENSION_TABLE, "Ausziehtisch", "Übertriffst du das Rundenziel um das Doppelte, wächst die Warteschlange dauerhaft um einen Platz.")

# --- Shop & Angebote ---

## Würfel-Angebote sind immer veredelt.
static func seal_of_quality() -> Charm:
	return _make(SEAL_OF_QUALITY, "Gütesiegel", "Würfel-Angebote im Shop sind immer veredelt (mind. eine Material-Seite).")

## 3er-Würfelbündel kosten $5 weniger und tauchen öfter im Shop auf.
static func bulk_discount() -> Charm:
	return _make(BULK_DISCOUNT, "Mengenrabatt", "3er-Würfelbündel kosten $5 weniger und treten öfter auf.")

## Das gemischte Coupon-Heft enthält nie Werbeflächen.
static func house_brand() -> Charm:
	return _make(HOUSE_BRAND, "Hausmarke", "Das gemischte Coupon-Heft enthält nie Werbeflächen.")

# --- Meta & Totem-Reihe ---

## Kopiert die Wirkung des Charms links von ihm.
static func parrot_totem() -> Charm:
	return _make(PARROT_TOTEM, "Papagei-Totem", "Kopiert die Wirkung des Charms LINKS von ihm.")

## Kopiert die Wirkung des Charms rechts von ihm.
static func echo_totem() -> Charm:
	return _make(ECHO_TOTEM, "Echo-Totem", "Kopiert die Wirkung des Charms RECHTS von ihm.")

## Höchstens 2 Charms besessen: +6 Mult auf alles.
static func hermit_crab() -> Charm:
	return _make(HERMIT_CRAB, "Einsiedlerkrebs", "Besitzt du höchstens 2 Charms, +6 Mult.")

## Alle existierenden Charm-Archetypen, unabhängig davon, ob sie gerade
## besessen werden - Grundlage für die Shop-Angebotsauswahl (siehe
## ShopController). Zugleich die kanonische Registrierung aller Charms: ein
## neuer Charm wird hier eingehängt.
static func all() -> Array[Charm]:
	return [
		rabbits_foot(), lucky_cigarettes(), four_leaf_clover(), golden_scarab(), fox_tail(), pencil_stub(),
		horseshoe(), ladybug(), pearl_necklace(), magic_card(), rainbow_trout(),
		old_penny(), piggy_bank(), crystal_ball(),
		chimney_sweep(),
		con_artist_cuff(), lucky_knot(),
		collectors_amulet(),
		# Effektkatalog (siehe Obsidian "12 Charms - Effektkatalog")
		pendulum(), all_or_nothing(), anchor(), straggler(),
		echo_chamber(), twin_ring(), double_six(), cult_of_one(), street_sweeper(), equalizer(), small_fry(),
		full_counter(), lighthouse(), momentum(), after_work_beer(), blackjack(),
		round_number(), broadband(), even_company(), odd_path(), snake_eyes(),
		broken_mirror(), grandfather_clock(), shard_court(), gallows_humor(), phoenix_feather(), patchwork_rug(),
		gold_rush(), rag_collector(), interest_penny(), street_musician(), small_change(), emergency_fund(),
		cash_discount(), high_flyer(),
		goldsmith(), amber_room(), ruby_grinder(), bone_glue(), glassblower_lung(), mercury_vapor(),
		display_case(), jewelry_box(), alloy(),
		frame_gilder(), magnet_ring(), edge_gleam(),
		regular_guest(), gourmet(), midnight_snack(), restaurant_critic(), house_recipe(),
		large_format(), bargain_hunter(), double_perforation(), engraving_pen(), stamp_machine(), fine_print(),
		recycling(), fresh_goods(), sediment(), extension_table(),
		seal_of_quality(), bulk_discount(), house_brand(),
		parrot_totem(), echo_totem(), hermit_crab(),
	]
