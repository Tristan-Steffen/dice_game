class_name TableGround
extends Node3D
## "Endloser" Filzboden: die Tischplatte hat keinen Rand mehr, der Pokertisch-
## Filz läuft nach allen Seiten weiter und verliert sich im Lichtabfall des
## dunklen Raums. GEKACHELT statt einer Riesenfläche: alle Spill-Lichter
## träfen sonst EIN Mesh und rissen max_lights_per_object (16). Die Mittel-
## kachel deckt exakt den alten Tisch-Fußabdruck - dort bleibt die Lichtlast
## wie bisher, die Randkacheln sehen fast keine Lichter.

const SHADER := preload("res://assets/shaders/table_ground.gdshader")

## Knapp unter der Screen-Oberfläche (Y=0): kein Z-Fighting, und die Stufe
## verschwindet unter der Chrom-Zarge des Screens.
const SURFACE_Y := -0.05

const CENTER_HALF := Vector2(60.0, 80.0)   # (x, z): halber alter Tisch-Fußabdruck
const OUTER_HALF := Vector2(300.0, 340.0)  # weit hinter jedem Kamera-Frustum

## Ein Material für alle Kacheln: Welt-UVs im Shader machen das Muster nahtlos.
var felt_material: ShaderMaterial

## 3x3-Gitter (x-Min, z-Min, Breite, Tiefe) aus Mittel- und Außengrenzen.
static func tile_rects() -> Array[Rect2]:
	var xs: Array[float] = [-OUTER_HALF.x, -CENTER_HALF.x, CENTER_HALF.x, OUTER_HALF.x]
	var zs: Array[float] = [-OUTER_HALF.y, -CENTER_HALF.y, CENTER_HALF.y, OUTER_HALF.y]
	var rects: Array[Rect2] = []
	for i in 3:
		for j in 3:
			rects.append(Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j]))
	return rects

func _ready() -> void:
	felt_material = ShaderMaterial.new()
	felt_material.shader = SHADER
	for rect in tile_rects():
		var mesh := PlaneMesh.new()
		mesh.size = rect.size
		var tile := MeshInstance3D.new()
		tile.name = "Tile_%d_%d" % [roundi(rect.position.x), roundi(rect.position.y)]
		tile.mesh = mesh
		tile.material_override = felt_material
		tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tile.position = Vector3(rect.get_center().x, SURFACE_Y, rect.get_center().y)
		add_child(tile)
