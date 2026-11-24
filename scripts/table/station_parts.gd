class_name StationParts
## Bausteine der Platinen-Stationen (Energie, Glück, Chips): Stahl mit festem Schlüssellicht
## (ChipFrameView), Eigenlicht unbeleuchtet unter der Bloom-Schwelle, viele Quader als EIN
## MultiMesh und flache Schrift in der Disketten-Schrift. Der Tisch beleuchtet nichts.

## Liegend: Schrift läuft Bild-rechts (+Z), Oberkante Bild-oben (+X), Blick nach oben.
const FLAT := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
const FONT_SIZE := 64

static func steel(color := ChipFrameView.STEEL, brush := 0.4, glow := 0.0) -> ShaderMaterial:
	return ChipFrameView._skin(color, brush, glow)

## Unbeleuchtetes Eigenlicht (Farbe = was man sieht).
static func lit(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

static func box(host: Node3D, part: String, size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	return TableProps.box(host, part, size, at, material)

## Stehender Zylinder (Achse Y).
static func cyl(host: Node3D, part: String, radius: float, height: float, at: Vector3,
		material: Material, segments := 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
	return node

## Ein flacher Ring (Torus-artig aus einem Rohr), liegend.
static func ring(host: Node3D, part: String, radius: float, width: float, at: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - width * 0.5, 0.001)
	mesh.outer_radius = radius + width * 0.5
	mesh.rings = 32
	mesh.ring_segments = 6
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.scale = Vector3(1.0, 0.25, 1.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
	return node

static func cube(size: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), at)

## Viele Quader als EIN MultiMesh (null, wenn es keine gibt).
static func swarm(host: Node3D, part: String, boxes: Array[Transform3D],
		material: Material) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = boxes.size()
	for i in boxes.size():
		multi.set_instance_transform(i, boxes[i])
	var node := MultiMeshInstance3D.new()
	node.name = part
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
	return node

## Die vier Stege eines rechteckigen Rahmens (x = Bild-oben, z = Bild-rechts).
static func frame_boxes(center: Vector2, outer: Vector2, inner: Vector2, y: float,
		height: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var band_x := (outer.x - inner.x) * 0.5
	var band_z := (outer.y - inner.y) * 0.5
	for side in [-1.0, 1.0]:
		out.append(cube(Vector3(band_x, height, outer.y),
			Vector3(center.x + side * (inner.x + band_x) * 0.5, y, center.y)))
		out.append(cube(Vector3(inner.x, height, band_z),
			Vector3(center.x, y, center.y + side * (inner.y + band_z) * 0.5)))
	return out

## Flache Schrift, height = Zeilenhöhe in Welt.
static func label(host: Node3D, part: String, text: String, at: Vector3, height: float,
		color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var node := Label3D.new()
	node.name = part
	node.text = text
	node.font = CharmDiskView.disk_font()
	node.font_size = FONT_SIZE
	node.pixel_size = height / float(FONT_SIZE)
	node.outline_size = 0
	node.modulate = color
	node.shaded = false
	node.double_sided = false
	node.horizontal_alignment = align
	node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	node.transform = Transform3D(FLAT, at)
	host.add_child(node)
	return node
