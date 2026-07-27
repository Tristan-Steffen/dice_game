class_name DieDefinition
extends Resource
## Datensatz eines Würfels: Augenzahl je physischer Seite (Index = Seite,
## siehe DiceController.AXIS_FACE_INDEX) plus Stil und Materialien.
## Resources werden per Referenz geteilt - wer einen Würfel übernimmt, MUSS
## instantiate() aufrufen, sonst mutiert ein Upgrade jeden geteilten Würfel.

@export var faces: Array[int] = [1, 2, 3, 4, 5, 6]
## Seiten-Material je physischer Seite (DieMaterial-id, "" = keins), parallel zu faces.
@export var materials: Array[String] = ["", "", "", "", "", ""]
## Kanten-Material des GANZEN Würfels ("" = keins) - wirkt egal, welche Seite
## oben liegt, und stapelt mit einem gleichen Seiten-Material.
@export var edge_material: String = ""
## Leiterbahn je Seite: Ziel-Seitenindex (nur Nachbarn) oder -1. Die Kette ab
## der oben liegenden Seite feuert nach dem Würfelschritt je Glied EINMAL mit.
@export var pointers: Array[int] = [-1, -1, -1, -1, -1, -1]
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
	edge_material = other.edge_material
	style_id = other.style_id
	display_name = other.display_name

## Unabhängige Kopie, sicher zum Verändern.
func instantiate() -> DieDefinition:
	var copy: DieDefinition = duplicate()
	copy.faces = faces.duplicate()
	copy.materials = materials.duplicate()
	copy.pointers = pointers.duplicate()
	return copy

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

## Leiterbahn-Kette ab up_face: gefeuerte Seiten in Reihenfolge (ohne up_face).
## Jede Seite höchstens einmal - ein Zyklus endet einfach.
func pointer_chain(up_face: int) -> Array[int]:
	var chain: Array[int] = []
	if up_face < 0 or up_face >= pointers.size():
		return chain
	var visited: Array[int] = [up_face]
	var current := up_face
	while true:
		var next: int = pointers[current] if current < pointers.size() else -1
		if next < 0 or next >= 6 or visited.has(next):
			break
		chain.append(next)
		visited.append(next)
		current = next
	return chain

static func standard() -> DieDefinition:
	return DieDefinition.new()

## Würfel, dessen 6 Seiten alle denselben Wert zeigen.
static func fixed(value: int, name: String) -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = [value, value, value, value, value, value]
	def.style_id = "fixed_%d" % value
	def.display_name = name
	return def
