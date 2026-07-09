class_name EtchingEffects
## Reine Seiten-Transformationen der Ätzungs-Coupons (siehe Coupon) - analog zu
## CharmEffects: keine Nodes, nur Rechnen. Jede Funktion verändert die faces
## eines DieDefinition IN PLACE; die Aufrufer übergeben eindeutige Pool-Würfel
## (jeder owned_pool-Eintrag ist eine eigene DieDefinition-Instanz, siehe
## scene_root.gd), sodass die Mutation keinen anderen Würfel trifft.
##
## Face-Parameter sind Seiten-Indizes 0..5 (physische Seiten, siehe
## DieDefinition.faces). Die eigentliche Ziel-Auswahl (welcher Würfel, welche
## Seite) übernimmt später die Anwendungs-UI; hier steht nur die Wirkung selbst,
## damit sie deterministisch testbar bleibt.

const MIN_FACE_VALUE := 1  # Würfelseiten fallen nie unter 1 (nach oben offen via Überzahl-Gravur)
const MAX_ENGRAVING_VALUE := 6  # Feingravur wählt frei aus 1..6

## Meißel: kopiert den Wert der Quellseite auf die Zielseite desselben Würfels.
static func chisel(die: DieDefinition, source_face: int, dest_face: int) -> void:
	die.faces[dest_face] = die.faces[source_face]

## Transplantat: tauscht je eine Seite zwischen zwei verschiedenen Würfeln.
static func transplant(die_a: DieDefinition, face_a: int, die_b: DieDefinition, face_b: int) -> void:
	var tmp := die_a.faces[face_a]
	die_a.faces[face_a] = die_b.faces[face_b]
	die_b.faces[face_b] = tmp

## Schleifstein: −1 auf minus_face, +1 auf plus_face desselben Würfels - die
## Augensumme des Würfels bleibt gleich. Nur zulässig, solange die verringerte
## Seite nicht unter MIN_FACE_VALUE fällt (siehe can_grindstone_minus).
static func grindstone(die: DieDefinition, minus_face: int, plus_face: int) -> void:
	die.faces[minus_face] -= 1
	die.faces[plus_face] += 1

## Ob minus_face als "−1"-Ziel taugt (bliebe ≥ MIN_FACE_VALUE).
static func can_grindstone_minus(die: DieDefinition, minus_face: int) -> bool:
	return die.faces[minus_face] > MIN_FACE_VALUE

## Feingravur: setzt eine Seite auf einen frei gewählten Wert (1..6).
static func fine_engraving(die: DieDefinition, face: int, value: int) -> void:
	die.faces[face] = value

## Ob value ein zulässiger Feingravur-Wert ist (1..6).
static func is_valid_engraving_value(value: int) -> bool:
	return value >= MIN_FACE_VALUE and value <= MAX_ENGRAVING_VALUE

## Überzahl-Gravur: +1 auf eine Seite, ausdrücklich OHNE Obergrenze (darf über 6
## hinausgehen, siehe Überzahlen-Konzept).
static func overcount_engraving(die: DieDefinition, face: int) -> void:
	die.faces[face] += 1
