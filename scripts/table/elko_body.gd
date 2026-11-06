class_name ElkoBody
## Ein loser liegender Radial-Elko: der Körper eines Energie-Preises am Wett-Tresen
## und eines geworfenen Energie-Einsatzes. Die Dose glüht, Ring und Beine sind Zierrat.

## Teilung, wenn mehrere Elkos beieinander liegen.
const CELL_PITCH := 1.0           # entlang +Z
const ROW_PITCH := 0.64           # entlang +X

const CAN_DIAMETER := 0.42
const CAN_LENGTH := 0.66
const LEG_REACH := 0.24
const LEG_DROP := 0.09
const LEG_RADIUS := 0.026
const LEG_SPREAD := 0.14
## Der Ring ist die breiteste Stelle: er liegt auf, die Dose schwebt einen Hauch.
const CRIMP_DIAMETER := 0.47
const CRIMP_HEIGHT := 0.055
## Bündig kämpften Ring- und Dosendeckel um die Tiefe.
const CRIMP_PROUD := 0.006

const LIT_COLOR := Color(1.0, 0.48, 0.06)
const CRIMP_ALBEDO := Color(0.03, 0.04, 0.055)
const LEG_ALBEDO := Color(0.34, 0.37, 0.44)
const LEG_EMISSION := Color(0.10, 0.11, 0.14)

## Ursprung = Rasterpunkt auf der Standfläche, Dosenachse entlang +Z.
static func build() -> MeshInstance3D:
	var cell := MeshInstance3D.new()
	cell.name = "Elko"
	cell.mesh = _cylinder(CAN_DIAMETER * 0.5, CAN_LENGTH, 12)
	cell.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	cell.position = Vector3(0.0, CRIMP_DIAMETER * 0.5, -LEG_REACH * 0.5)
	cell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = LIT_COLOR
	cell.material_override = lit
	var crimp_material := StandardMaterial3D.new()
	crimp_material.albedo_color = CRIMP_ALBEDO
	crimp_material.metallic = 0.6
	crimp_material.roughness = 0.45
	var crimp := MeshInstance3D.new()
	crimp.name = "Crimp"
	crimp.mesh = _cylinder(CRIMP_DIAMETER * 0.5, CRIMP_HEIGHT, 12)
	crimp.material_override = crimp_material
	crimp.position = Vector3(0.0, CAN_LENGTH * 0.5 - CRIMP_HEIGHT * 0.5 + CRIMP_PROUD, 0.0)
	crimp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(crimp)
	var leg_material := StandardMaterial3D.new()
	leg_material.albedo_color = LEG_ALBEDO
	leg_material.metallic = 0.9
	leg_material.roughness = 0.28
	leg_material.emission_enabled = true
	leg_material.emission = LEG_EMISSION
	var leg_mesh := _cylinder(LEG_RADIUS, sqrt(LEG_REACH * LEG_REACH + LEG_DROP * LEG_DROP), 6)
	var tilt := atan2(LEG_DROP, LEG_REACH)
	for side in 2:
		var leg := MeshInstance3D.new()
		leg.name = "Leg%d" % side
		leg.mesh = leg_mesh
		leg.material_override = leg_material
		leg.position = Vector3((float(side) * 2.0 - 1.0) * LEG_SPREAD * 0.5,
			CAN_LENGTH * 0.5 + LEG_REACH * 0.5, CRIMP_DIAMETER * 0.5 - LEG_DROP * 0.5)
		leg.rotation = Vector3(tilt, 0.0, 0.0)
		leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cell.add_child(leg)
	return cell

## Fußabdruck (Breite × Länge samt Beinen).
static func footprint() -> Vector2:
	return Vector2(CRIMP_DIAMETER, CAN_LENGTH + LEG_REACH)

static func height() -> float:
	return CRIMP_DIAMETER

static func _cylinder(radius: float, length: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = segments
	mesh.rings = 0
	return mesh
