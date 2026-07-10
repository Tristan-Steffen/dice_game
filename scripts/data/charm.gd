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
const BACKWARDS_MIRROR := "backwards_mirror"
const DOWSING_ROD := "dowsing_rod"
const CON_ARTIST_CUFF := "con_artist_cuff"
const LUCKY_KNOT := "lucky_knot"
const COLLECTORS_AMULET := "collectors_amulet"

## Ordner der Charm-Modelle (siehe CharmRowView, das sie auf dem Tisch zeigt).
const MODEL_DIR := "res://assets/models/"

## Modelldatei je Charm-id (Single Source of Truth für die Modell-Zuordnung,
## in _make ausgewertet). Ein Charm ohne Eintrag zeigt vorerst das
## Platzhalter-Modell (siehe CharmRowView.MODEL_FALLBACK).
const MODEL_FILE := {
	RABBITS_FOOT: "lucky+charm+3d+model.glb",
	LUCKY_CIGARETTES: "cigarette+pack+3d+model.glb",
	FOUR_LEAF_CLOVER: "Four-Leaf Clover+3d+model (1).glb",
	GOLDEN_SCARAB: "scarab+beetle+3d+model.glb",
	FOX_TAIL: "fox+charm+3d+model.glb",
	PENCIL_STUB: "pencil+3d+model.glb",
	HORSESHOE: "lucky+horseshoe+3d+model.glb",
	LADYBUG: "ladybug+charm+3d+model.glb",
	PEARL_NECKLACE: "pearl+bracelet+3d+model.glb",
	MAGIC_CARD: "playing+card+3d+model.glb",
	RAINBOW_TROUT: "colorful+fish+charm+3d+model.glb",
	PIGGY_BANK: "pink+piggy+bank+3d+model.glb",
	CRYSTAL_BALL: "fortune-telling+crystal+ball+3d+model.glb",
	CHIMNEY_SWEEP: "chimney+sweep+figurine+3d+model.glb",
	BACKWARDS_MIRROR: "ornate+mirror+3d+model.glb",
	DOWSING_ROD: "divining+rod+3d+model.glb",
	CON_ARTIST_CUFF: "trickdieb+manschette+3d-modell.glb",
	LUCKY_KNOT: "golden+hand+charm+3d+model.glb",  # Ersatzmodell (goldene Hand als Glückstalisman); OLD_PENNY hat noch kein Münzmodell
	COLLECTORS_AMULET: "goldenes+amulett+3d-modell.glb",
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## Pfad zum 3D-Modell dieses Charms (auf dem Tisch, siehe CharmRowView). Wird in
## _make aus MODEL_FILE gesetzt; Charms ohne Modell bleiben leer und zeigen das
## Platzhalter-Modell.
@export var model_path: String = ""

static func _make(charm_id: String, name: String, desc: String) -> Charm:
	var charm := Charm.new()
	charm.id = charm_id
	charm.display_name = name
	charm.description = desc
	if MODEL_FILE.has(charm_id):
		charm.model_path = MODEL_DIR + MODEL_FILE[charm_id]
	return charm

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

## Full House bekommt +1 Multiplikator.
static func horseshoe() -> Charm:
	return _make(HORSESHOE, "Hufeisen", "Full House erhält +1 Multiplikator.")

## Paar und Zwei Paare bekommen +1 Multiplikator.
static func ladybug() -> Charm:
	return _make(LADYBUG, "Marienkäfer", "Paar und Zwei Paare erhalten +1 Multiplikator.")

## Die großen Sechs-Würfel-Kombinationen bekommen +2 Multiplikator.
static func pearl_necklace() -> Charm:
	return _make(PEARL_NECKLACE, "Perlenkette", "Vierer+Paar, Drei Päsche und Doppel-Dreier erhalten +2 Multiplikator.")

## Die erste in einer Runde genommene Hand zählt doppelt.
static func magic_card() -> Charm:
	return _make(MAGIC_CARD, "Zauberkarte", "Die erste genommene Hand jeder Runde zählt doppelt.")

## Kleine und Große Straße geben je +10 Bonuspunkte.
static func rainbow_trout() -> Charm:
	return _make(RAINBOW_TROUT, "Regenbogenforelle", "Kleine und Große Straße geben +10 Punkte extra.")

# --- Geld-Charms: verändern die Auszahlung (siehe CharmEffects money-Hooks). ---

## +2$ extra für jedes erreichte Rundenziel.
static func old_penny() -> Charm:
	return _make(OLD_PENNY, "Glücksgroschen", "+2$ extra für jedes erreichte Rundenziel.")

## Übrige Würfel zahlen 2$ statt 1$.
static func piggy_bank() -> Charm:
	return _make(PIGGY_BANK, "Sparschwein", "Übrige Würfel zahlen 2$ statt 1$.")

## +1$ für jeden Farkle, den man überlebt (ohne die Runde zu verlieren).
static func crystal_ball() -> Charm:
	return _make(CRYSTAL_BALL, "Kristallkugel", "+1$ für jeden überlebten Farkle.")

# --- Farkle-Charms: mildern die Farkle-Strafe (siehe CharmEffects farkle-Hooks). ---

## Der erste Farkle jeder Runde wird verziehen (Hand läuft weiter).
static func chimney_sweep() -> Charm:
	return _make(CHIMNEY_SWEEP, "Schornsteinfeger", "Der erste Farkle jeder Runde wird verziehen.")

## Bei einem Farkle bleibt die Hälfte der Punkte erhalten statt null.
static func backwards_mirror() -> Charm:
	return _make(BACKWARDS_MIRROR, "Umgedrehter Spiegel", "Bei einem Farkle bleibt die Hälfte der Punkte erhalten.")

# --- Pool-/Shop-Charms: verändern Ziehreihenfolge, Poolgröße oder Preise
# (siehe CharmEffects pool-/shop-Hooks). ---

## Spezialwürfel werden pro Runde zuerst gezogen.
static func dowsing_rod() -> Charm:
	return _make(DOWSING_ROD, "Wünschelrute", "Spezialwürfel werden pro Runde zuerst gezogen.")

## Würfel im Shop kosten 20% weniger.
static func con_artist_cuff() -> Charm:
	return _make(CON_ARTIST_CUFF, "Trickdieb-Manschette", "Würfel im Shop kosten 20% weniger.")

## Jede Runde hat einen zusätzlichen Würfel im Pool.
static func lucky_knot() -> Charm:
	return _make(LUCKY_KNOT, "Glücksknoten", "Jede Runde hat einen zusätzlichen Würfel im Pool.")

# --- Meta-Charm: bezieht sich auf die anderen besessenen Charms. ---

## Jeder andere besessene Charm gibt +1 Punkt auf jede gewertete Hand.
static func collectors_amulet() -> Charm:
	return _make(COLLECTORS_AMULET, "Sammler-Amulett", "Jeder andere Charm gibt +1 Punkt auf jede gewertete Hand.")

## Alle existierenden Charm-Archetypen, unabhängig davon, ob sie gerade
## besessen werden - Grundlage für die Shop-Angebotsauswahl (siehe
## ShopController). Zugleich die kanonische Registrierung aller Charms: ein
## neuer Charm wird hier eingehängt.
static func all() -> Array[Charm]:
	return [
		rabbits_foot(), lucky_cigarettes(), four_leaf_clover(), golden_scarab(), fox_tail(), pencil_stub(),
		horseshoe(), ladybug(), pearl_necklace(), magic_card(), rainbow_trout(),
		old_penny(), piggy_bank(), crystal_ball(),
		chimney_sweep(), backwards_mirror(),
		dowsing_rod(), con_artist_cuff(), lucky_knot(),
		collectors_amulet(),
	]
