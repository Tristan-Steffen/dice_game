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
## über dieselbe id verdrahtet.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## Pfad zum 3D-Modell dieses Charms (auf dem Tisch, siehe scene_root.gd:
## _refresh_charm_models). Solange ein Charm noch kein eigenes Modell hat, zeigt
## scene_root ersatzweise das Platzhalter-Modell (MODELL_FALLBACK) - jeder Charm
## bekommt hier später seinen eigenen Pfad, sonst ändert sich am Code nichts.
@export var model_path: String = ""

static func _make(charm_id: String, name: String, desc: String) -> Charm:
	var charm := Charm.new()
	charm.id = charm_id
	charm.display_name = name
	charm.description = desc
	return charm

# --- Augenwert-Charms: verändern, wie stark ein einzelner Würfelwert zur
# Augensumme zählt (siehe CharmEffects.eye_value), ohne je die Kategorie zu
# ändern. ---

## Verdoppelt den Augenwert jeder gewürfelten 6.
static func rabbits_foot() -> Charm:
	var charm := _make("rabbits_foot", "Hasenpfote", "Jede gewürfelte 6 zählt doppelt für die Augensumme.")
	charm.model_path = "res://assets/models/lucky+charm+3d+model.glb"
	return charm

## Lässt jede gewürfelte 1 als 6 zählen.
static func lucky_cigarettes() -> Charm:
	return _make("lucky_cigarettes", "Glückszigaretten", "Jede gewürfelte 1 zählt als 6 für die Augensumme.")

## Verdoppelt den Augenwert jeder gewürfelten 4.
static func four_leaf_clover() -> Charm:
	return _make("four_leaf_clover", "Vierblättriges Kleeblatt", "Jede gewürfelte 4 zählt doppelt für die Augensumme.")

## Verdoppelt den Augenwert jeder gewürfelten 5.
static func golden_scarab() -> Charm:
	return _make("golden_scarab", "Goldener Skarabäus", "Jede gewürfelte 5 zählt doppelt für die Augensumme.")

## Lässt jede gewürfelte 3 als 4 zählen.
static func fox_tail() -> Charm:
	return _make("fox_tail", "Fuchsschwanz", "Jede gewürfelte 3 zählt als 4 für die Augensumme.")

## Lässt jede gewürfelte 2 als 3 zählen.
static func pencil_stub() -> Charm:
	return _make("pencil_stub", "Croupier-Bleistift", "Jede gewürfelte 2 zählt als 3 für die Augensumme.")

# --- Wertungs-Charms: verändern Multiplikator, Bonuspunkte oder verdoppeln
# ganze Hände (siehe CharmEffects.mult_bonus/flat_bonus/score_multiplier). ---

## Full House bekommt +1 Multiplikator.
static func horseshoe() -> Charm:
	return _make("horseshoe", "Hufeisen", "Full House erhält +1 Multiplikator.")

## Paar und Zwei Paare bekommen +1 Multiplikator.
static func ladybug() -> Charm:
	return _make("ladybug", "Marienkäfer", "Paar und Zwei Paare erhalten +1 Multiplikator.")

## Die großen Sechs-Würfel-Kombinationen bekommen +2 Multiplikator.
static func pearl_necklace() -> Charm:
	return _make("pearl_necklace", "Perlenkette", "Vierer+Paar, Drei Päsche und Doppel-Dreier erhalten +2 Multiplikator.")

## Die erste in einer Runde genommene Hand zählt doppelt.
static func magic_card() -> Charm:
	return _make("magic_card", "Zauberkarte", "Die erste genommene Hand jeder Runde zählt doppelt.")

## Kleine und Große Straße geben je +10 Bonuspunkte.
static func rainbow_trout() -> Charm:
	return _make("rainbow_trout", "Regenbogenforelle", "Kleine und Große Straße geben +10 Punkte extra.")

# --- Geld-Charms: verändern die Auszahlung (siehe CharmEffects money-Hooks). ---

## +2$ extra für jedes erreichte Rundenziel.
static func old_penny() -> Charm:
	return _make("old_penny", "Glücksgroschen", "+2$ extra für jedes erreichte Rundenziel.")

## Übrige Würfel zahlen 2$ statt 1$.
static func piggy_bank() -> Charm:
	return _make("piggy_bank", "Sparschwein", "Übrige Würfel zahlen 2$ statt 1$.")

## +1$ für jeden Farkle, den man überlebt (ohne die Runde zu verlieren).
static func crystal_ball() -> Charm:
	return _make("crystal_ball", "Kristallkugel", "+1$ für jeden überlebten Farkle.")

# --- Farkle-Charms: mildern die Farkle-Strafe (siehe CharmEffects farkle-Hooks). ---

## Der erste Farkle jeder Runde wird verziehen (Hand läuft weiter).
static func chimney_sweep() -> Charm:
	return _make("chimney_sweep", "Schornsteinfeger", "Der erste Farkle jeder Runde wird verziehen.")

## Bei einem Farkle bleibt die Hälfte der Punkte erhalten statt null.
static func backwards_mirror() -> Charm:
	return _make("backwards_mirror", "Umgedrehter Spiegel", "Bei einem Farkle bleibt die Hälfte der Punkte erhalten.")

# --- Pool-/Shop-Charms: verändern Ziehreihenfolge, Poolgröße oder Preise
# (siehe CharmEffects pool-/shop-Hooks). ---

## Spezialwürfel werden pro Runde zuerst gezogen.
static func dowsing_rod() -> Charm:
	return _make("dowsing_rod", "Wünschelrute", "Spezialwürfel werden pro Runde zuerst gezogen.")

## Würfel im Shop kosten 20% weniger.
static func con_artist_cuff() -> Charm:
	return _make("con_artist_cuff", "Trickdieb-Manschette", "Würfel im Shop kosten 20% weniger.")

## Jede Runde hat einen zusätzlichen Würfel im Pool.
static func lucky_knot() -> Charm:
	return _make("lucky_knot", "Glücksknoten", "Jede Runde hat einen zusätzlichen Würfel im Pool.")

# --- Meta-Charm: bezieht sich auf die anderen besessenen Charms. ---

## Jeder andere besessene Charm gibt +1 Punkt auf jede gewertete Hand.
static func collectors_amulet() -> Charm:
	return _make("collectors_amulet", "Sammler-Amulett", "Jeder andere Charm gibt +1 Punkt auf jede gewertete Hand.")

## Alle existierenden Charm-Archetypen, unabhängig davon, ob sie gerade
## besessen werden - Grundlage für die Shop-Angebotsauswahl (siehe
## scene_root.gd: _populate_shop_charm_options).
static func all() -> Array[Charm]:
	return [
		rabbits_foot(), lucky_cigarettes(), four_leaf_clover(), golden_scarab(), fox_tail(), pencil_stub(),
		horseshoe(), ladybug(), pearl_necklace(), magic_card(), rainbow_trout(),
		old_penny(), piggy_bank(), crystal_ball(),
		chimney_sweep(), backwards_mirror(),
		dowsing_rod(), con_artist_cuff(), lucky_knot(),
		collectors_amulet(),
	]
