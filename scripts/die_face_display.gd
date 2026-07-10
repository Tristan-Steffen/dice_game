class_name DieFaceDisplay
extends Node3D
## Sitzt unter RigidBody3D eines Würfels und hält die 6 Gesichter (eines pro
## physischer Seite, siehe DiceController.AXIS_DIRECTIONS). Jedes Gesicht besteht
## aus einem weißen Körper-Quad (quads) und einem darüberliegenden Label3D
## (labels), das die Augenzahl als Ziffer(n) zeigt. Die Ziffern werden zur
## Laufzeit gesetzt statt aus 6 festen Punkt-Texturen - so lässt sich jeder Wert
## anzeigen (auch dreistellige "Augen"), ohne für jede Zahl eine eigene Textur zu
## brauchen. quads/labels werden von DieBuilder befüllt, bevor der Würfel in den
## Baum eingehängt wird.
##
## set_tint färbt den Würfelkörper (Grundfarbe Weiß, künftig Spezialwürfel-Farben
## oder Halten-Gold); die Ziffer bleibt dunkel und dadurch auf jedem Körper
## lesbar. Künftige Symbole statt Ziffern hängen sich hier am Label3D bzw. einem
## zusätzlichen Sprite3D an.

## Grundfarbe des Würfelkörpers - set_tint(Color.WHITE) ergibt genau diese Farbe.
const BODY_COLOR := Color(1, 1, 1)
## Farbe der Augenzahl-Ziffer (dunkel, damit sie auf hellem/getöntem Körper lesbar bleibt).
const NUMBER_COLOR := Color(0.08, 0.08, 0.1)

## Interne Auflösung der Ziffern-Glyphen (Font-Atlas-Pixel) - je höher, desto
## schärfer bei starkem Heranzoomen, unabhängig von der Weltgröße (die steuert
## pixel_size, siehe fit_label).
const LABEL_FONT_SIZE := 160
## Basis-Umrechnung Font-Pixel -> Weltmeinheiten (Höhe einer einstelligen Ziffer).
## Wird von fit_label bei mehrstelligen Zahlen weiter verkleinert.
const LABEL_PIXEL_SIZE := 0.0085
## Nutzbare Kantenlänge fürs Ziffernfeld in Weltmeinheiten (< DieBuilder.FACE_SIZE),
## damit auch mehrstellige Zahlen mit etwas Rand aufs Gesicht passen.
const LABEL_FIT_EXTENT := 1.5

var quads: Dictionary = {}   # Achse (String, siehe AXIS_DIRECTIONS) -> MeshInstance3D (Körper-Quad)
var labels: Dictionary = {}  # Achse (String) -> Label3D (Augenzahl)

## Stellt alle 6 Seiten gemäß def.faces ein (Index über
## DiceController.AXIS_FACE_INDEX, siehe dort für die Achsen-Zuordnung).
func apply_definition(def: DieDefinition) -> void:
	for axis in DiceController.AXIS_FACE_INDEX:
		var face_index: int = DiceController.AXIS_FACE_INDEX[axis]
		var value: int = def.faces[face_index] if face_index < def.faces.size() else 1
		_set_face_value(axis, value)

func _set_face_value(axis: String, value: int) -> void:
	var label: Label3D = labels[axis]
	label.text = str(value)
	DieFaceDisplay.fit_label(label)

## Färbt den Körper aller 6 Seiten ein (Spezialwürfel-Tint oder Halten-Gold) -
## Color.WHITE = weiße Grundfarbe (Normalzustand). Die Ziffern bleiben dunkel.
func set_tint(color: Color) -> void:
	for axis in quads:
		var material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
		material.albedo_color = BODY_COLOR * color

## Färbt den Körper genau einer Seite (face_index 0..5, siehe
## DiceController.AXIS_FACE_INDEX) - für die Auswahl-Hervorhebung in der
## Gravur-Station (siehe DieInspectorView). set_tint setzt danach wieder alle
## Seiten gemeinsam.
func set_face_tint(face_index: int, color: Color) -> void:
	for axis in quads:
		if DiceController.AXIS_FACE_INDEX[axis] == face_index:
			var material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
			material.albedo_color = BODY_COLOR * color
			return

## Skaliert die Ziffern-Weltgröße (pixel_size) so, dass label.text in ein Feld
## von LABEL_FIT_EXTENT passt: einstellige Werte nutzen LABEL_PIXEL_SIZE voll,
## mehrstellige werden proportional verkleinert. Wird bei jeder Wertänderung
## aufgerufen, damit z.B. "128" genauso aufs Gesicht passt wie "6".
static func fit_label(label: Label3D) -> void:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var size_px: Vector2 = font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, label.font_size)
	var world_extent: float = maxf(size_px.x, size_px.y) * LABEL_PIXEL_SIZE
	var shrink: float = maxf(1.0, world_extent / LABEL_FIT_EXTENT)
	label.pixel_size = LABEL_PIXEL_SIZE / shrink
