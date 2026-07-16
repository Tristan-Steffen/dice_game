class_name EtchingEffects
## Seiten-Transformationen der Zahl-Sigille: jede Funktion verändert die
## faces EINES DieDefinition in place. face-Parameter sind Seiten-Indizes 0..5;
## welche Seite gemeint ist, wählt die Anwendungs-UI (DieInspectorView).

const MIN_FACE_VALUE := 1  # Seiten fallen nie unter 1; nach oben offen (Überzahlen)
## Höchster frei wählbarer Feingravur-Wert - nur die Wertauswahl braucht ein
## endliches Ende, +1-Ätzungen dürfen bewusst über 6 hinaus.
const FINE_ENGRAVING_MAX := 12

## Meißel: kopiert den Wert der Quellseite auf die Zielseite.
static func chisel(die: DieDefinition, source_face: int, dest_face: int) -> void:
	die.faces[dest_face] = die.faces[source_face]

## Transplantat: hebt die Seite auf den aktuell höchsten Wert des Würfels.
static func transplant(die: DieDefinition, face: int) -> void:
	die.faces[face] = die.faces.max()

static func can_transplant(die: DieDefinition, face: int) -> bool:
	return die.faces[face] < die.faces.max()

## Schleifstein: −1/+1 auf zwei Seiten - die Augensumme bleibt gleich.
static func grindstone(die: DieDefinition, minus_face: int, plus_face: int) -> void:
	die.faces[minus_face] -= 1
	die.faces[plus_face] += 1

static func can_grindstone_minus(die: DieDefinition, minus_face: int) -> bool:
	return die.faces[minus_face] > MIN_FACE_VALUE

## Feingravur: setzt eine Seite auf einen Wert (1..FINE_ENGRAVING_MAX).
static func fine_engraving(die: DieDefinition, face: int, value: int) -> void:
	die.faces[face] = value

static func is_valid_engraving_value(value: int) -> bool:
	return value >= MIN_FACE_VALUE and value <= FINE_ENGRAVING_MAX

## Überzahl-Gravur: +1 auf eine Seite, ohne Obergrenze.
static func overcount_engraving(die: DieDefinition, face: int) -> void:
	die.faces[face] += 1

## Feile: −1 auf eine Seite (min. 1) - billigster Weg, Werte anzugleichen.
static func file_down(die: DieDefinition, face: int) -> void:
	die.faces[face] -= 1

static func can_file_down(die: DieDefinition, face: int) -> bool:
	return die.faces[face] > MIN_FACE_VALUE

## Doppelkerbe: +1 auf zwei verschiedene Seiten, ohne Obergrenze.
static func double_notch(die: DieDefinition, face_a: int, face_b: int) -> void:
	die.faces[face_a] += 1
	die.faces[face_b] += 1

## Mittelung: setzt zwei Seiten auf ihren aufgerundeten Mittelwert.
static func averaging(die: DieDefinition, face_a: int, face_b: int) -> void:
	var mean := int(ceil((die.faces[face_a] + die.faces[face_b]) / 2.0))
	die.faces[face_a] = mean
	die.faces[face_b] = mean

## Anschluss: Zielseite = Quellseitenwert + 1 (Straßen-Bauer), ohne Obergrenze.
static func connect_up(die: DieDefinition, source_face: int, target_face: int) -> void:
	die.faces[target_face] = die.faces[source_face] + 1

## Spiegelung: invertiert alle Seiten über Wert → (Min + Max) − Wert.
static func mirror_die(die: DieDefinition) -> void:
	var lo: int = die.faces.min()
	var hi: int = die.faces.max()
	for i in die.faces.size():
		die.faces[i] = (lo + hi) - die.faces[i]

## Abdruck: prägt den Wert der Seite auf die zwei niedrigsten anderen Seiten.
static func imprint(die: DieDefinition, source_face: int) -> void:
	var value: int = die.faces[source_face]
	for target in _two_lowest_other_faces(die, source_face):
		die.faces[target] = value

static func _two_lowest_other_faces(die: DieDefinition, exclude: int) -> Array[int]:
	var order: Array[int] = []
	for i in die.faces.size():
		if i != exclude:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return die.faces[a] < die.faces[b])
	return order.slice(0, 2)

## Begradigung: +1 auf alle ungeraden Seiten (1–6 → 2,2,4,4,6,6), ohne Obergrenze.
static func straighten(die: DieDefinition) -> void:
	for i in die.faces.size():
		if die.faces[i] % 2 == 1:
			die.faces[i] += 1

## Blaupause: alle sechs Seiten bekommen den Wert der gewählten Seite.
static func blueprint(die: DieDefinition, face: int) -> void:
	var value: int = die.faces[face]
	for i in die.faces.size():
		die.faces[i] = value
