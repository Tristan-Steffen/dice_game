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
	var material := mesh.material_override as StandardMaterial3D
	assert_not_null(material)
	assert_eq(material.albedo_texture, screen.get_texture())
	assert_true(material.emission_enabled, "ohne Emission liest sich die Anzeige nicht als Display")

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
