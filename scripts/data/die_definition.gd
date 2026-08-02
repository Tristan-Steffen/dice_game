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
## Rift je Seite (Rift-id, "" = keiner), parallel zu faces. Rifts wohnen in der
## STRUKTUR der Schale, nicht in der Glasur: ein neues Material übermalt die
## Stufe, den Riss nie (set_face_material fasst sie darum nicht an).
@export var rifts: Array[String] = ["", "", "", "", "", ""]
## Zweiter Riss je Seite - NUR Vakuum-Würfel dürfen ihn tragen: ohne Innendruck
## trägt die Schale den zweiten Bruch. Bewusst ein PARALLELES Array statt einer
## Liste je Seite, damit jede Schleife über Rifts dieselbe flache Form sieht wie
## über Materialien und Stufen.
@export var second_rifts: Array[String] = ["", "", "", "", "", ""]
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
	rifts = other.rifts.duplicate()
	second_rifts = other.second_rifts.duplicate()
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
	copy.rifts = rifts.duplicate()
	copy.second_rifts = second_rifts.duplicate()
	return copy

## Belegt eine Seite mit einem Material. EINZIGER Schreibweg: die Stufe hängt am
## Material-Exemplar, nicht an der Seite - ein neues Material startet bei I.
## Die Rifts bleiben UNBERÜHRT: Stufen wohnen in der Glasur, Rifts in der
## Struktur der Schale - Übermalen löscht nie einen Bruch.
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

## Wie viele Risse diese Schale je Seite trägt: das Vakuum saugt das Kernlicht
## nach innen und hält ohne Innendruck einen zweiten Bruch aus.
func rift_slots() -> int:
	return 2 if essence_id == Essence.VACUUM else 1

## Die Rifts EINER Seite (0-2 Einträge, leere übersprungen).
func rifts_on(face: int) -> Array[String]:
	var out: Array[String] = []
	if face < 0 or face >= rifts.size():
		return out
	if rifts[face] != "":
		out.append(rifts[face])
	if rift_slots() > 1 and face < second_rifts.size() and second_rifts[face] != "":
		out.append(second_rifts[face])
	return out

func has_rift(face: int, rift_id: String) -> bool:
	return rifts_on(face).has(rift_id)

## Bricht eine Seite auf. slot 1 ist der Vakuum-Zweitriss und wird an jedem
## anderen Würfel abgewiesen; ein besetzter Platz wird ersetzt (neu brechen ist
## erlaubt). true, wenn der Riss sitzt.
func set_rift(face: int, rift_id: String, slot: int = 0) -> bool:
	if face < 0 or face >= rifts.size() or slot < 0 or slot >= rift_slots():
		return false
	if slot == 1:
		second_rifts[face] = rift_id
	else:
		rifts[face] = rift_id
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
