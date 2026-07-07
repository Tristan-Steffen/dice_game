class_name DieFaceDisplay
extends Node3D
## Sitzt unter RigidBody3D eines Würfels und hält die 6 Gesichts-Quads (eine
## pro physischer Seite, siehe DiceController.AXIS_DIRECTIONS). Jede Seite
## zeigt direkt eines der 6 SVG-Icons (dice-six-faces-*.svg, Rand+Punkte
## bereits enthalten) - kein Textur-Atlas nötig, jede Datei ist schon genau
## eine Seite. quads wird von DieBuilder befüllt, bevor der Würfel in den
## Baum eingehängt wird.

const FACE_TEXTURES := {
	1: preload("res://assets/textures/dice-six-faces-one.svg"),
	2: preload("res://assets/textures/dice-six-faces-two.svg"),
	3: preload("res://assets/textures/dice-six-faces-three.svg"),
	4: preload("res://assets/textures/dice-six-faces-four.svg"),
	5: preload("res://assets/textures/dice-six-faces-five.svg"),
	6: preload("res://assets/textures/dice-six-faces-six.svg"),
}

var quads: Dictionary = {}  # Achse (String, siehe AXIS_DIRECTIONS) -> MeshInstance3D

## Stellt alle 6 Seiten gemäß def.faces ein (Index über
## DiceController.AXIS_FACE_INDEX, siehe dort für die Achsen-Zuordnung).
func apply_definition(def: DieDefinition) -> void:
	for axis in DiceController.AXIS_FACE_INDEX:
		var face_index: int = DiceController.AXIS_FACE_INDEX[axis]
		var value: int = def.faces[face_index] if face_index < def.faces.size() else 1
		_set_quad_value(quads[axis], value)

func _set_quad_value(quad: MeshInstance3D, value: int) -> void:
	var material: StandardMaterial3D = quad.get_surface_override_material(0)
	material.albedo_texture = FACE_TEXTURES[clampi(value, 1, 6)]

## Färbt die weißen Rand-/Punktflächen aller 6 Seiten ein (Stil-Tint oder
## Halten-Hervorhebung) - Color.WHITE = keine Einfärbung (Normalzustand).
func set_tint(color: Color) -> void:
	for axis in quads:
		var material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
		material.albedo_color = color
