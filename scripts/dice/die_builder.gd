class_name DieBuilder
extends RefCounted
## Baut einen kompletten Würfel (RigidBody3D + Kollision + 6 Gesichts-Quads +
## Kanten-Rahmen) rein per Code - keine .tscn. Genutzt für Spiel- und
## Tray-Würfel; Werte/Tönungen setzt der Aufrufer über DieFaceDisplay.

const HALF_EXTENT := 1.0
const FACE_MARGIN := 0.02
## Balken-Querschnitt der Kanten: ragt EDGE_THICKNESS/2 über die Oberfläche
## hinaus, also vor die Gesichts-Quads - die Kanten treten als Rahmen hervor.
## Sie sind die Hauptlichtquelle des Würfels (siehe DieFaceDisplay.EDGE_GLOW),
## darum bewusst breit: das Essenzglühen soll aus der Übersichtskamera
## lesbar sein. FACE_SIZE folgt daraus - die Quads enden genau dort, wo die
## Balken beginnen.
const EDGE_THICKNESS := 0.26
const FACE_SIZE := HALF_EXTENT * 2.0 - EDGE_THICKNESS
## Eck-Kappen der Kanten: dicker als die Balken, damit die
## Silhouette selbst auf Distanz "beschlagene Ecken" zeigt.
const CAP_SIZE := 0.46
## Dunkle Fassung: Breite des Dichtungsrings und seine Tiefe. Die Tiefe liegt
## bewusst zwischen Quad (0) und Rahmen (0.006) - groß genug gegen Z-Fighting,
## klein genug, dass Rahmen und Risslinien darüber liegen.
const GASKET_WIDTH := 0.10
const GASKET_DEPTH := 0.004
## Fast schwarz, eine Spur unter der Körperfarbe - sie soll dichten, nicht malen.
const GASKET_COLOR := Color(0.02, 0.02, 0.035)

## Gleiche PhysicsMaterial-Charakteristik liegt auch auf den Grubenwänden,
## damit beide Seiten eines Aufpralls Energie zurückgeben.
const POOL_SHADER := preload("res://assets/shaders/die_glow_pool.gdshader")
const RIFT_SHADER := preload("res://assets/shaders/die_rift.gdshader")

const BOUNCE := 0.25
const FRICTION := 0.4

## Die 12 Kantenbalken als [Mitte, Größe]-Paare - eine Quelle für Mesh und Test.
## Wie ein geschweißter Rahmen: die senkrechten PFOSTEN laufen durch, die
## waagerechten RIEGEL stoßen an sie an. Ließe man alle drei bis in die Ecke
## laufen, lägen dort je zwei Außenflächen deckungsgleich aufeinander und
## flimmerten im Tiefenpuffer. Die Silhouette bleibt gleich: der durchlaufende
## Pfosten stellt die drei Eckflächen selbst.
static func beam_boxes() -> Array:
	var boxes := []
	var directions: Array = DiceController.AXIS_DIRECTIONS.values()
	for i in directions.size():
		for j in range(i + 1, directions.size()):
			var a: Vector3 = directions[i]
			var b: Vector3 = directions[j]
			if not is_zero_approx(a.dot(b)):
				continue  # (anti)parallel = keine gemeinsame Kante
			var long_axis: Vector3 = a.cross(b).abs()
			var reach := HALF_EXTENT * 2.0
			if long_axis != Vector3.UP:
				reach -= EDGE_THICKNESS * 2.0  # Riegel enden an den Pfosten
			boxes.append([(a + b) * HALF_EXTENT,
				Vector3.ONE * EDGE_THICKNESS + long_axis * reach])
	return boxes

## Der ganze Kantenrahmen in EINEM Mesh, einmal für alle Würfel: die Vertizes
## liegen schon an ihrem Balken, der Fluss-Shader liest die Kante aus der
## Position - dasselbe Prinzip wie bei den Eck-Kappen.
static var _frame_mesh: ArrayMesh = null

static func edge_frame_mesh() -> ArrayMesh:
	if _frame_mesh != null:
		return _frame_mesh
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for box in beam_boxes():
		var mesh := BoxMesh.new()
		mesh.size = box[1]
		builder.append_from(mesh, 0, Transform3D(Basis(), box[0]))
	_frame_mesh = builder.commit()
	return _frame_mesh

## Alle 8 Eck-Kappen in EINEM Mesh, einmal für alle Würfel: die Vertizes liegen
## schon an ihrer Ecke, also genügt dem Shader sign(VERTEX) zur Unterscheidung.
static var _cap_mesh: ArrayMesh = null

static func corner_cap_mesh() -> ArrayMesh:
	if _cap_mesh != null:
		return _cap_mesh
	var box := BoxMesh.new()
	box.size = Vector3.ONE * CAP_SIZE
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				builder.append_from(box, 0,
					Transform3D(Basis(), Vector3(sx, sy, sz) * HALF_EXTENT))
	_cap_mesh = builder.commit()
	return _cap_mesh

## Baut einen Würfel; der Aufrufer hängt den Wurzelknoten ein und positioniert ihn.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Dice"

	var body := RigidBody3D.new()
	body.name = "RigidBody3D"
	body.collision_layer = 2
	body.collision_mask = 3
	body.gravity_scale = 3.5
	body.linear_damp = 0.2
	body.angular_damp = 0.2
	body.continuous_cd = true  # kein Tunneln durch dünne Grubenwände bei hohem throw_force
	var material := PhysicsMaterial.new()
	material.bounce = BOUNCE
	material.friction = FRICTION
	body.physics_material_override = material
	root.add_child(body)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * HALF_EXTENT * 2.0
	collision.shape = shape
	body.add_child(collision)

	var faces := Node3D.new()
	faces.name = "Faces"
	faces.set_script(load("res://scripts/dice/die_face_display.gd"))
	body.add_child(faces)

	# Kanten-Körper: 12 Balken plus Füll-Box, alle mit EINEM Material - dessen
	# Neon setzt DieFaceDisplay (neutral bzw. Essenzglühen). Der Körper
	# ist dunkles poliertes Glas, die Kanten tragen das Licht (Tron-Prinzip).
	var edge_res := StandardMaterial3D.new()
	edge_res.albedo_color = DieFaceDisplay.BODY_COLOR
	edge_res.albedo_texture = DieMaterial.die_texture_for("")
	edge_res.emission_texture = edge_res.albedo_texture
	# MULTIPLY statt (Standard) ADD - sonst ADDIERT die helle Textur Vollweiß.
	edge_res.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	edge_res.roughness = DieFaceDisplay.EDGE_ROUGHNESS
	edge_res.metallic = DieFaceDisplay.EDGE_METALLIC
	edge_res.emission_enabled = true
	edge_res.emission = DieFaceDisplay.EDGE_NEON * DieFaceDisplay.EDGE_GLOW
	faces.edge_material_res = edge_res


	_build_glow_pool(faces)

	# KEINE Fresnel-Hülle mehr. Sie war eine additive Box knapp über dem Körper
	# und trug den Schimmer samt Kometenlicht - aber eine Leuchtfolie über einer
	# Fläche hat nur die Wahl zwischen zwei Fehlern: deckungsgleich flimmert ihr
	# Tiefentest, abgehoben steht ihr Rand sichtbar in der Luft und liest sich
	# als abgelöste Seite. Das Licht des Würfels sitzt jetzt allein dort, wo es
	# Geometrie gibt: Kanten, Eck-Lampen, Ziffern, Lache.
	var edges_root := Node3D.new()
	edges_root.name = "Edges"
	faces.add_child(edges_root)

	var fill := MeshInstance3D.new()
	fill.name = "Fill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3.ONE * HALF_EXTENT * 2.0
	fill.mesh = fill_mesh
	fill.material_override = edge_res
	edges_root.add_child(fill)

	# Die 12 Kantenbalken: EIN Mesh mit dem Fluss-Shader statt 12 Knoten am
	# geteilten Material. Welcher Balken, steckt in der Geometrie (zwei Achsen
	# am Anschlag), also braucht der Shader weder 12 Materialien noch eine
	# Instanz-Uniform - und das flüssige Licht der Seele kann längs der Kante
	# laufen, was ein StandardMaterial nie konnte. Elf Draw-Calls gespart.
	var beams := MeshInstance3D.new()
	beams.name = "Beams"
	beams.mesh = edge_frame_mesh()
	var beam_material := ShaderMaterial.new()
	beam_material.shader = load("res://assets/shaders/die_edge_flow.gdshader")
	# Dieselbe Oberfläche wie bisher; Konstanten bleiben in DieFaceDisplay.
	beam_material.set_shader_parameter("surface_tex", DieMaterial.die_texture_for(""))
	beam_material.set_shader_parameter("metallic_amount", DieFaceDisplay.EDGE_METALLIC)
	beam_material.set_shader_parameter("roughness_amount", DieFaceDisplay.EDGE_ROUGHNESS)
	beams.material_override = beam_material
	edges_root.add_child(beams)
	faces.beam_material = beam_material

	# Eck-Kappen (nur mit Essenz sichtbar): 8 Würfelchen auf den Ecken, sie
	# tragen die Silhouetten-Änderung. EIN Mesh statt acht Knoten, damit der
	# Lampen-Shader die Ecke aus sign(VERTEX) lesen kann - und ein Draw-Call.
	var caps := MeshInstance3D.new()
	caps.name = "CornerCaps"
	caps.visible = false
	caps.mesh = corner_cap_mesh()
	var cap_material := ShaderMaterial.new()
	cap_material.shader = load("res://assets/shaders/die_corner_lamp.gdshader")
	# Dieselbe Oberfläche wie der Rahmen - die Kappen sind sein Fortsatz, nur
	# ihre Emission tanzt. Konstanten bleiben in DieFaceDisplay, eine Quelle.
	cap_material.set_shader_parameter("surface_tex", DieMaterial.die_texture_for(""))
	cap_material.set_shader_parameter("metallic_amount", DieFaceDisplay.EDGE_METALLIC)
	cap_material.set_shader_parameter("roughness_amount", DieFaceDisplay.EDGE_ROUGHNESS)
	caps.material_override = cap_material
	caps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edges_root.add_child(caps)
	faces.corner_caps = caps
	faces.cap_material = cap_material

	for axis: String in DiceController.AXIS_DIRECTIONS:
		var direction: Vector3 = DiceController.AXIS_DIRECTIONS[axis]
		var quad := MeshInstance3D.new()
		quad.name = "Face%s" % axis.capitalize()

		var quad_mesh := QuadMesh.new()
		quad_mesh.size = Vector2.ONE * FACE_SIZE
		quad.mesh = quad_mesh

		quad.position = direction * (HALF_EXTENT + FACE_MARGIN)
		quad.basis = _face_basis(direction, DiceController.FACE_TEXT_UP[axis])

		var default_value: int = DiceController.AXIS_FACE_INDEX[axis] + 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = DieFaceDisplay.BODY_COLOR
		mat.albedo_texture = DieMaterial.die_texture_for("")
		mat.emission_texture = mat.albedo_texture
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mat.roughness = DieFaceDisplay.FACE_ROUGHNESS
		mat.emission_enabled = true
		mat.emission = DieFaceDisplay.EDGE_NEON * DieFaceDisplay.FACE_GLOW
		quad.set_surface_override_material(0, mat)

		faces.add_child(quad)
		faces.quads[axis] = quad

		var gasket := _build_face_gasket()
		quad.add_child(gasket)
		faces.gaskets[axis] = gasket

		var frame := _build_face_frame()
		quad.add_child(frame)
		faces.frames[axis] = frame

		var crack := build_rift_overlay()
		quad.add_child(crack)
		faces.rift_overlays[axis] = crack

		var label := _build_label(default_value)
		quad.add_child(label)
		faces.labels[axis] = label
		DieFaceDisplay.fit_label(label)

	return root

## Leucht-Rahmen einer Material-Seite (unsichtbar ohne Material): dünne Linie
## in Materialfarbe knapp vor dem Quad - das Distanz-Signal, welche Seite
## Material trägt, wenn Facetten/Relief längst nicht mehr lesbar sind.
static func _build_face_frame() -> MeshInstance3D:
	var frame := MeshInstance3D.new()
	frame.name = "MaterialFrame"
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * FACE_SIZE
	frame.mesh = mesh
	frame.position = Vector3(0, 0, 0.006)  # vor dem Quad, hinter der Ziffer (0.01)
	frame.visible = false
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = DieMaterial.face_frame_texture()
	material.albedo_color = DieFaceDisplay.BODY_COLOR
	material.emission_enabled = true
	material.emission_texture = material.albedo_texture
	material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	frame.material_override = material
	return frame

## Dunkle Fassung einer Material-Seite: ein schmaler, fast schwarzer Ring am
## Flächenrand, zwischen Leuchtrahmen und Kantenbalken. Er ist die optische
## Dichtung gegen das Kantenbloom - dasselbe Prinzip wie der dunkle Saum um die
## Ziffer: Bloom blutet im Bildschirmraum, und nur eine dunkle Trennzone hält
## ihn von der Einlage fern. Vier dünne Balken statt eines Rings, weil sich so
## zwei Meshes teilen lassen und die Ecken stoßfrei aneinanderliegen.
## Liegt VOR dem Quad, aber HINTER Rahmen und Riss-Auflage - eine Risslinie, die
## bis an den Flächenrand läuft, bleibt darüber sichtbar.
# Alle Fassungen sind identisch - Material und beide Meshes werden geteilt
# (dasselbe Muster wie der _trace_mesh_cache), statt je Seite neu zu entstehen.
static var _gasket_material: StandardMaterial3D
static var _gasket_long: QuadMesh
static var _gasket_short: QuadMesh

static func _build_face_gasket() -> Node3D:
	var gasket := Node3D.new()
	gasket.name = "MaterialGasket"
	gasket.position = Vector3(0, 0, GASKET_DEPTH)
	gasket.visible = false
	if _gasket_material == null:
		_gasket_material = StandardMaterial3D.new()
		_gasket_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_gasket_material.albedo_color = GASKET_COLOR  # kein Leuchten: eine Dichtung strahlt nicht
		_gasket_long = QuadMesh.new()
		_gasket_long.size = Vector2(FACE_SIZE, GASKET_WIDTH)
		_gasket_short = QuadMesh.new()
		_gasket_short.size = Vector2(GASKET_WIDTH, FACE_SIZE - GASKET_WIDTH * 2.0)
	var material := _gasket_material
	var span := FACE_SIZE - GASKET_WIDTH
	var long_mesh := _gasket_long
	var short_mesh := _gasket_short
	for side in [-1.0, 1.0]:
		var bar := MeshInstance3D.new()
		bar.mesh = long_mesh
		bar.position = Vector3(0, side * span * 0.5, 0)
		bar.material_override = material
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gasket.add_child(bar)
		var post := MeshInstance3D.new()
		post.mesh = short_mesh
		post.position = Vector3(side * span * 0.5, 0, 0)
		post.material_override = material
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gasket.add_child(post)
	return gasket

## Riss-Auflage einer gebrochenen Seite (unsichtbar ohne Rift): das farblose
## Rissbild unter die_rift.gdshader - das Kernlicht bricht aus der Schale. Ein
## eigenes Light je Riss verbietet das 16-Light-Budget des gekachelten Bodens,
## also trägt die Helligkeit allein die ALBEDO des Shaders.
## Die Shader-RESSOURCE ist preloaded, also gibt es genau EINEN Compile, auch
## wenn jede Seite ihr eigenes ShaderMaterial trägt (wie vorher ihr eigenes
## StandardMaterial3D - an der Zahl der Materialien ändert sich nichts).
static func build_rift_overlay(depth := 0.008) -> MeshInstance3D:
	var crack := MeshInstance3D.new()
	crack.name = "RiftCracks"
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * FACE_SIZE
	crack.mesh = mesh
	crack.position = Vector3(0, 0, depth)  # vor dem Rahmen, hinter der Ziffer
	crack.visible = false
	crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = RIFT_SHADER
	crack.material_override = material
	return crack

## Additive Licht-Lache am Boden unter dem Würfel (Neon-Kontaktschatten).
## top_level: folgt NICHT der Würfeldrehung - DieFaceDisplay._process setzt
## Position/Verblassen je Frame. Farbe/Sichtbarkeit steuert _refresh_pool.
static func _build_glow_pool(faces: DieFaceDisplay) -> void:
	var pool := MeshInstance3D.new()
	pool.name = "GlowPool"
	pool.top_level = true
	pool.visible = false
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pool_mesh := QuadMesh.new()
	pool_mesh.size = Vector2.ONE * HALF_EXTENT * DieFaceDisplay.POOL_SPAN
	pool_mesh.orientation = PlaneMesh.FACE_Y
	pool.mesh = pool_mesh

	# Abfall und Grubenmaske rechnet der Shader - eine Verlaufstextur würde bei
	# dieser Größe selbst stufen (siehe die_glow_pool.gdshader).
	var pool_material := ShaderMaterial.new()
	pool_material.shader = POOL_SHADER
	pool.material_override = pool_material

	faces.add_child(pool)
	faces.glow_pool = pool
	faces.pool_material = pool_material

## Ziffern-Label eines Gesichts: minimal vor dem Quad (+Z), erbt dessen
## nach außen gerichtete Orientierung.
static func _build_label(value: int) -> Label3D:
	var label := Label3D.new()
	label.name = "Value"
	label.text = str(value)
	label.font_size = DieFaceDisplay.LABEL_FONT_SIZE
	label.pixel_size = DieFaceDisplay.LABEL_PIXEL_SIZE
	label.modulate = DieFaceDisplay.NUMBER_COLOR
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS  # schreibt Tiefe: korrektes Sortieren bei vielen Würfeln
	# Dunkler Saum um die Ziffer: Bloom blutet im Bildschirmraum, also wäscht eine
	# auflodernde Naht die Zahl auch dann aus, wenn sie sie gar nicht berührt. Weil
	# der Prepass auch für den Saum Tiefe schreibt, VERDECKT der Ring den Riss
	# dahinter - ein Trennband, das Bloom nicht überqueren kann.
	label.outline_size = DieFaceDisplay.LABEL_OUTLINE_SIZE
	label.outline_modulate = DieFaceDisplay.BODY_COLOR
	label.position = Vector3(0, 0, 0.01)
	return label

## Quad-Orientierung: z (Normale) nach außen, y (Ziffern-"oben") entlang up;
## up muss senkrecht auf direction stehen.
static func _face_basis(direction: Vector3, up: Vector3) -> Basis:
	var z_axis := direction.normalized()
	var x_axis := up.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)
