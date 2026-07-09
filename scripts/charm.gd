class_name Charm
extends Resource
## Datensatz für einen Charm: eine eigenständige Sammelkategorie neben den
## geplanten Jokern (siehe Obsidian-Konzept "08 Joker"), aber mit demselben
## Aufbau - Anzeige-Infos hier, die eigentliche Wirkung zentral über die id
## aufgelöst (siehe scripts/charm_effects.gd). Anders als Joker (die ganze
## Kombinationen/Runden beeinflussen sollen) sitzen Charms näher am einzelnen
## Würfel - kleine, thematische Glücksbringer wie eine Hasenpfote oder eine
## Packung Glückszigaretten.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

static func _make(charm_id: String, name: String, desc: String) -> Charm:
	var charm := Charm.new()
	charm.id = charm_id
	charm.display_name = name
	charm.description = desc
	return charm

## Testcharm: verdoppelt den Augenwert jeder gewürfelten 6 (siehe
## CharmEffects.eye_value) - zählt also z.B. bei einem Sechserpasch nicht
## 6×6=36, sondern 12×6=72 Augen, bevor der Kombi-Multiplikator draufkommt.
static func rabbits_foot() -> Charm:
	return _make("rabbits_foot", "Hasenpfote", "Jede gewürfelte 6 zählt doppelt für die Augensumme.")

## Zweiter Testcharm: verwandelt jede gewürfelte 1 in eine 6 (siehe
## CharmEffects.eye_value) - anders als die Hasenpfote (die einen Wert
## verdoppelt) ersetzt dieser Charm den Augenwert komplett, damit
## CharmEffects auch diese Art von Effekt beweisbar unterstützt.
static func lucky_cigarettes() -> Charm:
	return _make("lucky_cigarettes", "Glückszigaretten", "Jede gewürfelte 1 zählt als 6 für die Augensumme.")

## Alle existierenden Charm-Archetypen, unabhängig davon, ob sie gerade
## besessen werden - Grundlage für die Shop-Angebotsauswahl (siehe
## scene_root.gd: _populate_shop_charm_options).
static func all() -> Array[Charm]:
	return [rabbits_foot(), lucky_cigarettes()]
