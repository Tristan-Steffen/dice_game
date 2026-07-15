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
@export var style_id: String = "normal"
@export var display_name: String = "Normal"

## Unabhängige Kopie, sicher zum Verändern.
func instantiate() -> DieDefinition:
	var copy: DieDefinition = duplicate()
	copy.faces = faces.duplicate()
	copy.materials = materials.duplicate()
	return copy

static func standard() -> DieDefinition:
	return DieDefinition.new()

## Würfel, dessen 6 Seiten alle denselben Wert zeigen.
static func fixed(value: int, name: String) -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = [value, value, value, value, value, value]
	def.style_id = "fixed_%d" % value
	def.display_name = name
	return def
