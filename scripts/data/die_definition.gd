class_name DieDefinition
extends Resource
## Datensatz eines Würfels: Augenzahl je physischer Seite (Index = Seite,
## siehe DiceController.AXIS_FACE_INDEX) plus Stil und Materialien.
## Resources werden per Referenz geteilt - wer einen Würfel übernimmt, MUSS
## instantiate() aufrufen, sonst mutiert ein Upgrade jeden geteilten Würfel.

@export var faces: Array[int] = [1, 2, 3, 4, 5, 6]
## Seiten-Material je physischer Seite (DieMaterial-id, "" = keins), parallel zu faces.
@export var materials: Array[String] = ["", "", "", "", "", ""]
## Essenz des GANZEN Würfels ("" = keine). ANGEBOREN: beim Guss versiegelt, es
## gibt keinen Auftragsweg - nur Würfelfabriken und Angebote schreiben sie.
@export var essence_id: String = ""
## Leiterbahn je Seite: Ziel-Seitenindex (nur Nachbarn) oder -1. Sie zündet nur
## auf Chance (DiceScoring.POINTER_CHANCE), Sprung für Sprung.
@export var pointers: Array[int] = [-1, -1, -1, -1, -1, -1]
## Sättigung je Seite: Stufe des Materials DIESER Seite (0 = keins, sonst 1-3).
## Die Stufe wohnt in der Glasur, nicht in der Seite - ein neues Material fängt
## wieder bei I an (set_face_material ist der einzige Schreibweg).
@export var levels: Array[int] = [0, 0, 0, 0, 0, 0]
## Rune je Seite (Runen-id, "" = keiner), parallel zu faces. Runen wohnen in der
## STRUKTUR der Schale, nicht in der Glasur: ein neues Material übermalt die
## Stufe, die Rune nie (set_face_material fasst sie darum nicht an).
@export var runes: Array[String] = ["", "", "", "", "", ""]
## Zweite Rune je Seite - NUR Vakuum-Würfel dürfen ihn tragen: ohne Innendruck
## trägt die Schale eine zweite Rune. Bewusst ein PARALLELES Array statt einer
## Liste je Seite, damit jede Schleife über Runen dieselbe flache Form sieht wie
## über Materialien und Stufen.
@export var second_runes: Array[String] = ["", "", "", "", "", ""]
## Dritte Rune je Seite - ebenfalls nur am Vakuum, und nur unter der Glasglocke
## (Charm) überhaupt zu setzen. Was sitzt, wirkt weiter: der Charm entscheidet
## über das ÄTZEN, nicht über die Rune.
@export var third_runes: Array[String] = ["", "", "", "", "", ""]
@export var style_id: String = "normal"
@export var display_name: String = "Normal"

## Übernimmt den Inhalt von other, OHNE die Instanz zu tauschen: Rundendeck und
## Trays halten dieselbe Referenz wie der Pool und zeigen den neuen Würfel damit
## sofort (ein Tausch ließe sie auf dem alten sitzen).
func become(other: DieDefinition) -> void:
	if other == null:
		return
	faces = other.faces.duplicate()
	materials = other.materials.duplicate()
	pointers = other.pointers.duplicate()
	levels = other.levels.duplicate()
	runes = other.runes.duplicate()
	second_runes = other.second_runes.duplicate()
	third_runes = other.third_runes.duplicate()
	essence_id = other.essence_id
	style_id = other.style_id
	display_name = other.display_name

## Unabhängige Kopie, sicher zum Verändern.
func instantiate() -> DieDefinition:
	var copy: DieDefinition = duplicate()
	copy.faces = faces.duplicate()
	copy.materials = materials.duplicate()
	copy.pointers = pointers.duplicate()
	copy.levels = levels.duplicate()
	copy.runes = runes.duplicate()
	copy.second_runes = second_runes.duplicate()
	copy.third_runes = third_runes.duplicate()
	return copy

## Belegt eine Seite mit einem Material. EINZIGER Schreibweg: die Stufe hängt am
## Material-Exemplar, nicht an der Seite - ein neues Material startet bei I.
## Die Runen bleiben UNBERÜHRT: Stufen wohnen in der Glasur, Runen in der
## Struktur der Schale - Übermalen löscht nie eine Rune.
func set_face_material(face: int, material_id: String) -> void:
	if face < 0 or face >= materials.size():
		return
	materials[face] = material_id
	if face < levels.size():
		levels[face] = 0 if material_id == "" else 1

## Stufe des Materials auf dieser Seite (0 = keins/außerhalb).
func material_level(face: int) -> int:
	if face < 0 or face >= levels.size():
		return 0
	return levels[face]

## Hebt die Seite um eine Stufe (Deckel DieMaterial.MAX_LEVEL); true, wenn sie
## sich bewegt hat. Eine nackte Seite lässt sich nicht sättigen.
func raise_level(face: int) -> bool:
	if face < 0 or face >= levels.size() or face >= materials.size():
		return false
	if materials[face] == "" or levels[face] >= DieMaterial.MAX_LEVEL:
		return false
	levels[face] = maxi(1, levels[face]) + 1
	return true

## Wie viele Runen diese Schale je Seite trägt: das Vakuum saugt das Kernlicht
## nach innen und hält ohne Innendruck eine zweite Rune aus - unter der
## Glasglocke unter der Glasglocke eine dritte. extra kommt vom Aufrufer, der die Charms kennt (die
## Def kennt sie nicht); ohne Vakuum bleibt es bei einer Rune.
func rune_slots(extra: int = 0) -> int:
	if essence_id != Essence.VACUUM:
		return 1
	return mini(MAX_RUNE_SLOTS, 2 + maxi(0, extra))

## Harte Grenze: mehr als drei parallele Runen-Arrays trägt keine Schale.
const MAX_RUNE_SLOTS := 3

## Die Runen EINER Seite (0-3 Einträge, leere übersprungen). Gelesen wird, was
## WIRKLICH sitzt - der Charm entscheidet nur, ob eine dritte Rune entstehen darf.
func runes_on(face: int) -> Array[String]:
	var out: Array[String] = []
	if face < 0 or face >= runes.size():
		return out
	if runes[face] != "":
		out.append(runes[face])
	if essence_id != Essence.VACUUM:
		return out
	if face < second_runes.size() and second_runes[face] != "":
		out.append(second_runes[face])
	if face < third_runes.size() and third_runes[face] != "":
		out.append(third_runes[face])
	return out

func has_rune(face: int, rune_id: String) -> bool:
	return runes_on(face).has(rune_id)

## Ätzt ein Zeichen in eine Seite. Slot 1 und 2 gehören dem Vakuum (2 nur unter der
## Glasglocke, darum extra) und werden an jedem anderen Würfel abgewiesen; ein
## besetzter Platz wird ersetzt (neu ätzen ist erlaubt). true, wenn die Rune sitzt.
func set_rune(face: int, rune_id: String, slot: int = 0, extra: int = 0) -> bool:
	if face < 0 or face >= runes.size() or slot < 0 or slot >= rune_slots(extra):
		return false
	match slot:
		2:
			third_runes[face] = rune_id
		1:
			second_runes[face] = rune_id
		_:
			runes[face] = rune_id
	return true

## Gegenseite eines Seitenindex (Kalibrierung: DiceController.AXIS_FACE_INDEX
## legt die Paare (0,5), (1,4), (2,3) fest).
static func opposite_face(face: int) -> int:
	return 5 - face

## Die 4 Nachbarseiten - alle außer der Seite selbst und ihrer Gegenseite.
static func adjacent_faces(face: int) -> Array[int]:
	var result: Array[int] = []
	for i in 6:
		if i != face and i != opposite_face(face):
			result.append(i)
	return result

## Darf eine Leiterbahn von from_face nach to_face führen? Nur zu Nachbarn.
func can_point(from_face: int, to_face: int) -> bool:
	if from_face < 0 or from_face >= 6 or to_face < 0 or to_face >= 6:
		return false
	return to_face != from_face and to_face != opposite_face(from_face)

## Ziel-Seite der Leiterbahn dieser Seite (-1 = keine). Ob sie zündet, würfelt
## DiceScoring.roll_pointer_fires aus - die Def kennt nur die Verdrahtung.
func pointer_target(face: int) -> int:
	if face < 0 or face >= pointers.size():
		return -1
	var target: int = pointers[face]
	return target if target >= 0 and target < 6 else -1

static func standard() -> DieDefinition:
	return DieDefinition.new()

## Würfel, dessen 6 Seiten alle denselben Wert zeigen.
static func fixed(value: int, name: String) -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = [value, value, value, value, value, value]
	def.style_id = "fixed_%d" % value
	def.display_name = name
	return def
