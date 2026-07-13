class_name DieDefinition
extends Resource
## Datensatz für einen einzelnen Würfel: welche Augenzahl auf welcher der 6
## physischen Seiten liegt (Index = physische Seite, siehe
## DiceController.AXIS_FACE_INDEX), plus Stil für Einfärbung/Anzeige. Spätere
## Modifikatoren (Gold-Würfel, Glas-Würfel, ...) hängen sich hier als
## zusätzliche @export-Liste an.
##
## Resources werden von Godot per Referenz geteilt - wer einen Würfel neu in
## den Besitz übernimmt (Kauf im Shop, Belohnung, ...), MUSS instantiate()
## aufrufen, sonst verändert ein späteres Würfel-Upgrade versehentlich jeden
## Würfel, der dieselbe Definition teilt.

@export var faces: Array[int] = [1, 2, 3, 4, 5, 6]
## Seiten-Material je physischer Seite (DieMaterial-id, "" = keins) - parallel
## zu faces. Angebracht über Material-Coupons in der Gravur-Station (siehe
## DieInspectorView); die Wirkung löst MaterialEffects beim Werten/Nehmen auf.
@export var materials: Array[String] = ["", "", "", "", "", ""]
## Kanten-Material des GANZEN Würfels (DieMaterial-id, "" = keins): der
## durchgehende Rahmen zwischen den Seiten (siehe DieFaceDisplay). Wirkt wie
## das Seiten-Material, aber egal welche Seite oben liegt - und stapelt mit
## einem gleichen Seiten-Material (siehe MaterialEffects, z.B. Quecksilber-
## Kanten + Quecksilber-Seite = vierfach). Angebracht über Kanten-Coupons
## (siehe Coupon.KIND_EDGE) in der Gravur-Station.
@export var edge_material: String = ""
@export var style_id: String = "normal"
@export var display_name: String = "Normal"

## Liefert eine unabhängige Kopie, sicher zum Verändern (siehe Klassen-Kommentar).
func instantiate() -> DieDefinition:
	var copy: DieDefinition = duplicate()
	copy.faces = faces.duplicate()
	copy.materials = materials.duplicate()
	return copy

static func standard() -> DieDefinition:
	return DieDefinition.new()

## Baut einen Würfel, dessen 6 Seiten alle denselben Wert zeigen (z.B. der
## Shop-Würfel "immer 6").
static func fixed(value: int, name: String) -> DieDefinition:
	var def := DieDefinition.new()
	def.faces = [value, value, value, value, value, value]
	def.style_id = "fixed_%d" % value
	def.display_name = name
	return def
