class_name EtchingEffects
## Reine Seiten-Transformationen der Ätzungs-Coupons (siehe Coupon) - analog zu
## CharmEffects: keine Nodes, nur Rechnen. Jede Funktion verändert die faces
## EINES DieDefinition IN PLACE; keine Ätzung berührt zwei Würfel (die physische
## Seitenlage ist ohnehin gleichgültig - beim Wurf zählt nur der Multiset der
## sechs Werte, ein reines Umsortieren innerhalb eines Würfels wäre also wirkungslos).
##
## Face-Parameter sind Seiten-Indizes 0..5 (physische Seiten, siehe
## DieDefinition.faces). Welche Seite gemeint ist, wählt die Anwendungs-UI (siehe
## DieInspectorView); hier steht nur die Wirkung selbst, deterministisch testbar.

const MIN_FACE_VALUE := 1  # Würfelseiten fallen nie unter 1 (nach oben offen via Überzahl-Gravur)
const MAX_ENGRAVING_VALUE := 6  # Feingravur wählt frei aus 1..6

## Meißel: kopiert den Wert der Quellseite auf die Zielseite desselben Würfels.
static func chisel(die: DieDefinition, source_face: int, dest_face: int) -> void:
	die.faces[dest_face] = die.faces[source_face]

## Transplantat: hebt die gewählte Seite auf den aktuell höchsten Wert des
## Würfels (verpflanzt den stärksten Wert auf diese Seite) - schneller
## Pasch-Bauer. Sinnlos, wenn die Seite schon der Höchstwert ist (siehe can_transplant).
static func transplant(die: DieDefinition, face: int) -> void:
	die.faces[face] = die.faces.max()

## Ob face als Transplantat-Ziel taugt (liegt unter dem aktuellen Höchstwert).
static func can_transplant(die: DieDefinition, face: int) -> bool:
	return die.faces[face] < die.faces.max()

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

## Anschluss: setzt die Zielseite auf (Quellseitenwert + 1) DESSELBEN Würfels -
## der Straßen-Bauer (schließt an einen vorhandenen Wert an). Nur zulässig,
## solange der Quellwert < 6 bleibt (über 6 geht nur die Überzahl-Gravur, siehe
## can_connect_up).
static func connect_up(die: DieDefinition, source_face: int, target_face: int) -> void:
	die.faces[target_face] = die.faces[source_face] + 1

## Ob source_face als Anschluss-Quelle taugt (Ergebnis Quellwert+1 bliebe ≤ 6).
static func can_connect_up(die: DieDefinition, source_face: int) -> bool:
	return die.faces[source_face] < MAX_ENGRAVING_VALUE

## Spiegelung: invertiert alle Seiten eines Würfels über Wert → (Min + Max) − Wert
## (Min/Max aus den aktuellen Seiten - gleiche Formel wie die Inversion). Standard
## 1–6 → 6,5,4,3,2,1.
static func mirror_die(die: DieDefinition) -> void:
	var lo: int = die.faces.min()
	var hi: int = die.faces.max()
	for i in die.faces.size():
		die.faces[i] = (lo + hi) - die.faces[i]

## Abdruck: prägt den Wert der gewählten Seite auf die beiden NIEDRIGSTEN anderen
## Seiten desselben Würfels (ein doppelter Meißel Richtung Pasch - der
## Pasch-Motor). Bei Gleichstand entscheidet die Seitenreihenfolge; da nur der
## Multiset zählt, ist das Ergebnis so oder so eindeutig.
static func imprint(die: DieDefinition, source_face: int) -> void:
	var value: int = die.faces[source_face]
	for target in _two_lowest_other_faces(die, source_face):
		die.faces[target] = value

## Die (bis zu) zwei Seitenindizes mit dem niedrigsten Wert, exclude ausgenommen.
static func _two_lowest_other_faces(die: DieDefinition, exclude: int) -> Array[int]:
	var order: Array[int] = []
	for i in die.faces.size():
		if i != exclude:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return die.faces[a] < die.faces[b])
	return order.slice(0, 2)

## Begradigung: +1 auf alle ungeraden Seiten eines Würfels, aber nur solange sie
## unter 6 bleiben (über 6 nur via Überzahl) - der Paar-Former. Standard 1–6 →
## 2,2,4,4,6,6.
static func straighten(die: DieDefinition) -> void:
	for i in die.faces.size():
		if die.faces[i] % 2 == 1 and die.faces[i] < MAX_ENGRAVING_VALUE:
			die.faces[i] += 1

## Blaupause: prägt den GESAMTEN Würfel auf den Wert der gewählten Seite - alle
## sechs Seiten bekommen diesen Wert, der Würfel zeigt fortan also immer diesen
## Wert (wie ein fester Shop-Würfel). Der stärkste Pasch-Bauer, entsprechend selten.
static func blueprint(die: DieDefinition, face: int) -> void:
	var value: int = die.faces[face]
	for i in die.faces.size():
		die.faces[i] = value
