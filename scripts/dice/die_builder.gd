class_name DieBuilder
extends RefCounted
## Baut einen kompletten Würfel (RigidBody3D + Kollision + 6 Gesichts-Quads +
## Kanten-Rahmen) rein per Code - keine .tscn. Genutzt für Spiel- und
## Tray-Würfel; Werte/Tönungen setzt der Aufrufer über DieFaceDisplay.

const HALF_EXTENT := 1.0
const FACE_SIZE := 1.9
const FACE_MARGIN := 0.02
## Balken-Querschnitt der Kanten: ragt EDGE_THICKNESS/2 über die Oberfläche
## hinaus, also vor die Gesichts-Quads - die Kanten treten als Rahmen hervor.
const EDGE_THICKNESS := 0.16

## Gleiche PhysicsMaterial-Charakteristik liegt auch auf den Grubenwänden,
## damit beide Seiten eines Aufpralls Energie zurückgeben.
const BOUNCE := 0.25
const FRICTION := 0.4

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
	# Neon setzt DieFaceDisplay (neutral bzw. Kanten-Material-Tint). Der Körper
	# ist dunkles poliertes Glas, die Kanten tragen das Licht (Tron-Prinzip).
	var edge_material := StandardMaterial3D.new()
	edge_material.albedo_color = DieFaceDisplay.BODY_COLOR
	edge_material.albedo_texture = DieMaterial.die_texture_for("")
	edge_material.emission_texture = edge_material.albedo_texture
	# MULTIPLY statt (Standard) ADD - sonst ADDIERT die helle Textur Vollweiß.
	edge_material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	edge_material.roughness = 0.25
	edge_material.metallic = 0.35
	edge_material.emission_enabled = true
	edge_material.emission = DieFaceDisplay.EDGE_NEON * DieFaceDisplay.EDGE_GLOW
	faces.edge_material_res = edge_material

	# Umgebungslicht des Würfels - standardmäßig aus, nur die Spielwürfel
	# schalten es frei (DieFaceDisplay.set_light_enabled). Eng + hart abfallend,
	# damit eine sichtbare Licht-Lache unter dem Würfel liegt (Erdung).
	var die_light := OmniLight3D.new()
	die_light.name = "DieLight"
	die_light.omni_range = DieFaceDisplay.LIGHT_RANGE
	die_light.omni_attenuation = 2.0
	die_light.light_color = DieFaceDisplay.LIGHT_BASE_COLOR
	die_light.light_energy = DieFaceDisplay.LIGHT_BASE_ENERGY
	die_light.shadow_enabled = false
	die_light.visible = false
	faces.add_child(die_light)
	faces.die_light = die_light

	_build_glow_pool(faces)

	# Fresnel-Hülle knapp über dem Körper: additiver Schimmer, der mit flacherem
	# Blickwinkel zunimmt - das Licht scheint aus dem Glasvolumen zu kommen.
	var shell := MeshInstance3D.new()
	shell.name = "FresnelShell"
	var shell_mesh := BoxMesh.new()
	shell_mesh.size = Vector3.ONE * (HALF_EXTENT * 2.0 + EDGE_THICKNESS)
	shell.mesh = shell_mesh
	var shell_material := ShaderMaterial.new()
	shell_material.shader = load("res://assets/shaders/die_fresnel.gdshader")
	shell.material_override = shell_material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	faces.add_child(shell)
	faces.shell_material = shell_material

	var edges_root := Node3D.new()
	edges_root.name = "Edges"
	faces.add_child(edges_root)

	var fill := MeshInstance3D.new()
	fill.name = "Fill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3.ONE * HALF_EXTENT * 2.0
	fill.mesh = fill_mesh
	fill.material_override = edge_material
	edges_root.add_child(fill)

	# Je Kante ein Balken: jedes Paar senkrechter Achsrichtungen (a, b) ist
	# genau eine Kante (Mitte (a+b)·HALF_EXTENT, lang entlang der dritten
	# Achse). Balken gleicher Richtung teilen ihr BoxMesh.
	var beam_meshes := {}
	var directions: Array = DiceController.AXIS_DIRECTIONS.values()
	for i in directions.size():
		for j in range(i + 1, directions.size()):
			var a: Vector3 = directions[i]
			var b: Vector3 = directions[j]
			if not is_zero_approx(a.dot(b)):
				continue  # (anti)parallel = keine gemeinsame Kante
			var long_axis: Vector3 = a.cross(b).abs()
			if not beam_meshes.has(long_axis):
				var mesh := BoxMesh.new()
				mesh.size = Vector3.ONE * EDGE_THICKNESS + long_axis * HALF_EXTENT * 2.0
				beam_meshes[long_axis] = mesh
			var beam := MeshInstance3D.new()
			beam.mesh = beam_meshes[long_axis]
			beam.position = (a + b) * HALF_EXTENT
			beam.material_override = edge_material
			edges_root.add_child(beam)

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
		mat.roughness = 0.2
		mat.emission_enabled = true
		mat.emission = DieFaceDisplay.EDGE_NEON * DieFaceDisplay.FACE_GLOW
		quad.set_surface_override_material(0, mat)

		faces.add_child(quad)
		faces.quads[axis] = quad

		var label := _build_label(default_value)
		quad.add_child(label)
		faces.labels[axis] = label
		DieFaceDisplay.fit_label(label)

	return root

## Additive Licht-Lache am Boden unter dem Würfel (Neon-Kontaktschatten).
## top_level: folgt NICHT der Würfeldrehung - DieFaceDisplay._process setzt
## Position/Verblassen je Frame. Farbe/Sichtbarkeit steuert _refresh_die_light.
static func _build_glow_pool(faces: DieFaceDisplay) -> void:
	var pool := MeshInstance3D.new()
	pool.name = "GlowPool"
	pool.top_level = true
	pool.visible = false
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pool_mesh := QuadMesh.new()
	pool_mesh.size = Vector2.ONE * HALF_EXTENT * 4.4
	pool_mesh.orientation = PlaneMesh.FACE_Y
	pool.mesh = pool_mesh

	# Radialer Verlauf (Mitte voll, Rand transparent) als weiche Lache.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var falloff := GradientTexture2D.new()
	falloff.gradient = gradient
	falloff.fill = GradientTexture2D.FILL_RADIAL
	falloff.fill_from = Vector2(0.5, 0.5)
	falloff.fill_to = Vector2(0.5, 0.0)
	falloff.width = 128
	falloff.height = 128

	var pool_material := StandardMaterial3D.new()
	pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pool_material.albedo_texture = falloff
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
	label.position = Vector3(0, 0, 0.01)
	return label

## Quad-Orientierung: z (Normale) nach außen, y (Ziffern-"oben") entlang up;
## up muss senkrecht auf direction stehen.
static func _face_basis(direction: Vector3, up: Vector3) -> Basis:
	var z_axis := direction.normalized()
	var x_axis := up.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)
