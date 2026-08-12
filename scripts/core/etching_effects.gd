class_name EtchingEffects
## Seiten-Transformationen der sechs Zahl-Gravuren: jede Funktion verändert die
## faces EINES DieDefinition in place. face-Parameter sind Seiten-Indizes 0..5.
##
## Jede Gravur trägt eine LEITER. Die Presse wirft nur noch Stufe 1 aus; die
## höheren Sprossen warten auf ihre nächste Quelle. Alle Zahlen stehen hier -
## eine Quelle für Anwendung, Text und Vorschau.

const MIN_FACE_VALUE := 1  # Seiten fallen nie unter 1; nach oben offen (Überzahlen)
## Die Leiter hat sechs Sprossen; höhere Stufen gibt es nicht.
const MAX_STUFE := 6

const NOTCH_LADDER := [1, 2, 3, 5, 8, 12]
const OVERPRESSURE_LADDER := [2, 4, 6, 10, 15, 20]
const POLISH_LADDER := [1, 2, 3, 4, 6, 10]
const GROWTH_LADDER := [2, 4, 6, 10, 15, 20]
## Meißel: so viele Zielseiten trägt die Stufe - ab 4 sind es alle fünf anderen
## (die alte legendäre Blaupause).
const CHISEL_TARGETS := [1, 2, 3, 5, 5, 5]
## Ab dieser Stufe wandert das Material der Quellseite mit, ab jener die Rune.
const CHISEL_MATERIAL_STUFE := 5
const CHISEL_RUNE_STUFE := 6
## Schleifstein: so viele Augen wandern; ALL = alles, was über der 1 liegt.
const GRINDSTONE_ALL := -1
const GRINDSTONE_LADDER := [2, 4, 8, 15, 30, GRINDSTONE_ALL]

## Sprosse einer Leiter zur Stufe (außerhalb 1..6 wird geklemmt).
static func step_of(ladder: Array, stufe: int) -> int:
	return int(ladder[clampi(stufe, 1, MAX_STUFE) - 1])

## Höchste Seite; bei Gleichstand die KLEINSTE Seitenzahl - dieselbe Bruchregel
## wie bei den Ein-Würfel-Charms (CharmEffects.target_die).
static func highest_face(die: DieDefinition) -> int:
	var best := 0
	for i in range(1, die.faces.size()):
		if die.faces[i] > die.faces[best]:
			best = i
	return best

static func lowest_face(die: DieDefinition) -> int:
	var best := 0
	for i in range(1, die.faces.size()):
		if die.faces[i] < die.faces[best]:
			best = i
	return best

## Kerbe: hebt EINE gewählte Seite.
static func notch(die: DieDefinition, face: int, stufe: int = 1) -> void:
	if face < 0 or face >= die.faces.size():
		return
	die.faces[face] += step_of(NOTCH_LADDER, stufe)

## Überdruck: hebt automatisch die höchste Seite - weniger Kontrolle, mehr Augen,
## und die bewusste Überzahlen-Rampe.
static func overpressure(die: DieDefinition, stufe: int = 1) -> void:
	die.faces[highest_face(die)] += step_of(OVERPRESSURE_LADDER, stufe)

## Aufholen: der Spiegel des Überdrucks - hebt die niedrigste Seite.
static func growth(die: DieDefinition, stufe: int = 1) -> void:
	die.faces[lowest_face(die)] += step_of(GROWTH_LADDER, stufe)

## Politur: hebt alle sechs Seiten.
static func polish(die: DieDefinition, stufe: int = 1) -> void:
	var step := step_of(POLISH_LADDER, stufe)
	for i in die.faces.size():
		die.faces[i] += step

## Zielseiten, die der Meißel dieser Stufe verlangt.
static func chisel_target_count(stufe: int) -> int:
	return int(CHISEL_TARGETS[clampi(stufe, 1, MAX_STUFE) - 1])

## Meißel: kopiert den Wert der Quellseite auf die Zielseiten. Ab Stufe 5 wandert
## auch ihr MATERIAL mit (samt Dotierung), ab Stufe 6 ihre RUNE. Kopiert wird nur,
## was die Quelle wirklich trägt - der Meißel nimmt nie etwas weg. Ein Einbrand
## auf dem Ziel sperrt das Übermalen des Materials, den Wert nie.
static func chisel(die: DieDefinition, source_face: int, targets: Array[int], stufe: int = 1) -> void:
	if source_face < 0 or source_face >= die.faces.size():
		return
	var value: int = die.faces[source_face]
	var source_material: String = die.materials[source_face]
	var source_doped := die.material_level(source_face) >= DieMaterial.MAX_LEVEL
	var source_rune: String = die.runes[source_face]
	for target in targets:
		if target < 0 or target >= die.faces.size() or target == source_face:
			continue
		die.faces[target] = value
		if stufe >= CHISEL_MATERIAL_STUFE and source_material != "" \
				and not RuneEffects.protects_face_value(die.runes_on(target)):
			die.set_face_material(target, source_material)
			if source_doped:
				die.dope(target)
		if stufe >= CHISEL_RUNE_STUFE and source_rune != "":
			die.set_rune(target, source_rune)

## Schleifstein: verschiebt Augen von einer Seite auf eine andere - die
## Augensumme bleibt gleich. Die Quellseite fällt nie unter 1, verschoben wird
## also nur, was sie WIRKLICH abgeben kann. Liefert die gewanderten Augen.
static func grindstone(die: DieDefinition, minus_face: int, plus_face: int, stufe: int = 1) -> int:
	if minus_face < 0 or minus_face >= die.faces.size():
		return 0
	if plus_face < 0 or plus_face >= die.faces.size() or plus_face == minus_face:
		return 0
	var available: int = die.faces[minus_face] - MIN_FACE_VALUE
	if available <= 0:
		return 0
	var want := step_of(GRINDSTONE_LADDER, stufe)
	var moved := available if want == GRINDSTONE_ALL else mini(want, available)
	die.faces[minus_face] -= moved
	die.faces[plus_face] += moved
	return moved

static func can_grindstone_minus(die: DieDefinition, minus_face: int) -> bool:
	return die.faces[minus_face] > MIN_FACE_VALUE
