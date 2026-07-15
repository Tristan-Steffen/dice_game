extends GutTest
## Tier-2-Tests des Tisch-Displays (TableScreen): attach_to legt das Material
## mit ViewportTexture auf das Mesh und leitet die Weltgrenzen aus der
## globalen AABB ab; world_to_pixel bildet Weltpunkte auf Bildschirm-Pixel ab
## (u entlang Welt+Z, v entlang Welt-X, "Bildschirm-oben" = +X).

var screen: TableScreen
var mesh: MeshInstance3D

func before_each() -> void:
	var world := Node3D.new()
	add_child_autofree(world)

	# Nachbau der Tisch-Situation: Screen-Fläche lokal 31.2 x 21.2, Tisch um
	# 90 Grad gedreht und mit Scale 4 (lokal X -> Welt +Z, lokal Z -> Welt -X).
	mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(31.2, 0.2, 21.2)
	mesh.mesh = box
	world.add_child(mesh)
	mesh.global_transform = Transform3D(
		Basis(Vector3(0, 0, 4), Vector3(0, 4, 0), Vector3(-4, 0, 0)),
		Vector3(0, -3.8, 0))

	screen = TableScreen.new()
	world.add_child(screen)
	screen.attach_to(mesh)

func test_attach_sets_viewport_material():
	# Display-Glas als ShaderMaterial (siehe screen_glass.gdshader): die
	# UI-ViewportTexture ist die Anzeige, emission_energy lässt sie leuchten.
	var material := mesh.material_override as ShaderMaterial
	assert_not_null(material)
	assert_eq(material.get_shader_parameter("screen_texture"), screen.get_texture())
	assert_gt(float(material.get_shader_parameter("emission_energy")), 0.0,
		"ohne Emission liest sich die Anzeige nicht als Display")

func test_attach_wires_reflection_into_the_glass():
	# Mit ScreenReflection bekommt das Glas die Spiegeltextur, und die
	# Spiegelebene liegt auf der Glas-Oberfläche (Tisch bei -3.8, siehe unten).
	var reflection := ScreenReflection.new()
	add_child_autofree(reflection)
	screen.attach_to(mesh, reflection)
	var material := mesh.material_override as ShaderMaterial
	assert_eq(material.get_shader_parameter("reflection_texture"), reflection.get_texture())
	assert_almost_eq(reflection.plane_height, -3.8 + 0.2 / 2.0 * 4.0, 0.5)

func test_center_maps_to_screen_center():
	var pixel := screen.world_to_pixel(Vector3.ZERO)
	assert_almost_eq(pixel.x, float(screen.size.x) / 2.0, 0.5)
	assert_almost_eq(pixel.y, float(screen.size.y) / 2.0, 0.5)

func test_screen_up_is_world_plus_x():
	# Welt +X ist "Bildschirm-oben" (siehe scene_root PIT_TOP_ROW_X): der
	# vordere Flächenrand (+42.4) muss auf Pixelzeile 0 fallen.
	var pixel := screen.world_to_pixel(Vector3(42.4, 0, 0))
	assert_almost_eq(pixel.y, 0.0, 0.5)
	assert_almost_eq(pixel.x, float(screen.size.x) / 2.0, 0.5)

func test_u_runs_along_world_plus_z():
	var left := screen.world_to_pixel(Vector3(0, 0, -62.4))
	var right := screen.world_to_pixel(Vector3(0, 0, 62.4))
	assert_almost_eq(left.x, 0.0, 0.5)
	assert_almost_eq(right.x, float(screen.size.x), 0.5)

func test_pixel_to_world_round_trips():
	# Umkehrung von world_to_pixel: ein Pixel -> Welt -> Pixel muss dorthin
	# zurückführen (Grundlage für Kamera-Zoomziel/Klickzone des Clusters).
	for pixel: Vector2 in [Vector2(300, 200), Vector2(780, 530), Vector2(1200, 900)]:
		var world := screen.pixel_to_world(pixel)
		var back := screen.world_to_pixel(world)
		assert_almost_eq(back.x, pixel.x, 0.5)
		assert_almost_eq(back.y, pixel.y, 0.5)

func test_pixel_to_world_uses_surface_height():
	# y der zurückgegebenen Weltposition ist die Screen-Oberfläche (Tisch bei
	# -3.8, Fläche knapp darüber), nicht 0 - sonst zielt der Zoom zu tief.
	var world := screen.pixel_to_world(Vector2(780, 530))
	assert_almost_eq(world.y, -3.8 + 0.2 / 2.0 * 4.0, 0.5)

func test_cluster_rect_covers_all_cells():
	# Der Neon-Rahmen (cluster_rect) muss jede Zelle umschließen.
	assert_gt(screen.cluster_rect.size.x, 0.0)
	for key: String in screen.combo_cells:
		var cell: ComboCellView = screen.combo_cells[key]
		assert_true(screen.cluster_rect.encloses(Rect2(cell.position, cell.size)),
			"Zelle '%s' liegt außerhalb des Cluster-Rahmens" % key)
