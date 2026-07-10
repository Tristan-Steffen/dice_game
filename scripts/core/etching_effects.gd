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

## Feile: −1 auf eine Seite (min. 1, siehe can_file_down). Klingt nach Abwertung,
## ist aber der billigste Weg, Werte anzugleichen (Paare!).
static func file_down(die: DieDefinition, face: int) -> void:
	die.faces[face] -= 1

## Ob face als Feile-Ziel taugt (bliebe ≥ MIN_FACE_VALUE).
static func can_file_down(die: DieDefinition, face: int) -> bool:
	return die.faces[face] > MIN_FACE_VALUE

## Doppelkerbe: +1 auf zwei verschiedene Seiten desselben Würfels (je max. 6,
## siehe can_notch). Roh-Addition - die Deckelung prüft der Aufrufer je Seite.
static func double_notch(die: DieDefinition, face_a: int, face_b: int) -> void:
	die.faces[face_a] += 1
	die.faces[face_b] += 1

## Ob face ein zulässiges Kerben-Ziel ist (bliebe ≤ MAX_ENGRAVING_VALUE; über 6
## geht ausschließlich die Überzahl-Gravur).
static func can_notch(die: DieDefinition, face: int) -> bool:
	return die.faces[face] < MAX_ENGRAVING_VALUE

## Mittelung: setzt zwei Seiten desselben Würfels auf ihren aufgerundeten
## Mittelwert (z.B. 1 und 6 → 4 und 4) - tauscht die beste Seite gegen Pasch-Material.
static func averaging(die: DieDefinition, face_a: int, face_b: int) -> void:
	var mean := int(ceil((die.faces[face_a] + die.faces[face_b]) / 2.0))
	die.faces[face_a] = mean
	die.faces[face_b] = mean

## Anschluss: setzt eine Seite eines ANDEREN Würfels auf (Quellwert + 1) - der
## Straßen-Bauer. Nur zulässig, solange der Quellwert < 6 bleibt (über 6 geht nur
## die Überzahl-Gravur, siehe can_connect_up).
static func connect_up(source_die: DieDefinition, source_face: int, target_die: DieDefinition, target_face: int) -> void:
	target_die.faces[target_face] = source_die.faces[source_face] + 1

## Ob source_face als Anschluss-Quelle taugt (Ergebnis Quellwert+1 bliebe ≤ 6).
static func can_connect_up(source_die: DieDefinition, source_face: int) -> bool:
	return source_die.faces[source_face] < MAX_ENGRAVING_VALUE

## Spiegelung: invertiert alle Seiten eines Würfels über Wert → (Min + Max) − Wert
## (Min/Max aus den aktuellen Seiten - gleiche Formel wie die Inversion). Standard
## 1–6 → 6,5,4,3,2,1.
static func mirror_die(die: DieDefinition) -> void:
	var lo: int = die.faces.min()
	var hi: int = die.faces.max()
	for i in die.faces.size():
		die.faces[i] = (lo + hi) - die.faces[i]

## Abdruck: kopiert eine Seite auf eine Seite eines ANDEREN Würfels (Meißel über
## Würfelgrenzen - der eigentliche Pasch-Motor, da gleiche Werte auf verschiedenen
## Würfeln liegen).
static func imprint(source_die: DieDefinition, source_face: int, target_die: DieDefinition, target_face: int) -> void:
	target_die.faces[target_face] = source_die.faces[source_face]

## Begradigung: +1 auf alle ungeraden Seiten eines Würfels, aber nur solange sie
## unter 6 bleiben (über 6 nur via Überzahl) - der Paar-Former. Standard 1–6 →
## 2,2,4,4,6,6.
static func straighten(die: DieDefinition) -> void:
	for i in die.faces.size():
		if die.faces[i] % 2 == 1 and die.faces[i] < MAX_ENGRAVING_VALUE:
			die.faces[i] += 1

## Blaupause: kopiert den kompletten Seitensatz (nur Werte) eines Würfels auf
## einen anderen. Das Ziel bekommt eine eigene faces-Kopie (unabhängig von der Quelle).
static func blueprint(source_die: DieDefinition, target_die: DieDefinition) -> void:
	target_die.faces = source_die.faces.duplicate()
