extends GutTest
## Tests der Würfel-Spiegelung auf dem Display-Glas (ScreenReflection): die
## Spiegel-Kamera sieht nur den Spiegel-Layer, folgt der Hauptkamera an der
## Ebene y=plane_height gespiegelt (mit negierter X-Achse, damit die Basis
## rechtshändig bleibt - der Glas-Shader dreht das Bild zurück), und
## mark_reflective hebt alle Sichtbestandteile eines Würfels auf den Layer.

var reflection: ScreenReflection
var main_camera: Camera3D

func before_each() -> void:
	main_camera = Camera3D.new()
	add_child_autofree(main_camera)
	reflection = ScreenReflection.new()
	reflection.main_camera = main_camera
	add_child_autofree(reflection)

func test_mirror_camera_only_sees_the_reflective_layer() -> void:
	assert_not_null(reflection.mirror_camera)
	assert_eq(reflection.mirror_camera.cull_mask, ScreenReflection.LAYER,
		"die Spiegelkamera darf nur markierte Würfel rendern")
	assert_true(reflection.transparent_bg, "ohne durchsichtigen Grund überdeckt die Spiegelung die Anzeige")
	assert_false(reflection.own_world_3d, "die Spiegelkamera muss die ECHTE Szene sehen")

func test_disabling_leaves_nothing_to_reflect() -> void:
	# Im Titel-HUD geistern die gespiegelten Würfel sonst über das Menü.
	reflection.set_enabled(false)
	assert_eq(reflection.mirror_camera.cull_mask, 0)
	reflection.set_enabled(true)
	assert_eq(reflection.mirror_camera.cull_mask, ScreenReflection.LAYER)

func test_mirror_camera_follows_the_main_camera_mirrored() -> void:
	reflection.plane_height = 1.0
	main_camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(3.0, 10.0, -4.0))
	reflection._process(0.0)
	var mirrored := reflection.mirror_camera.global_transform
	# Position an y=1 gespiegelt: 2*1 - 10 = -8; x/z unverändert.
	assert_almost_eq(mirrored.origin, Vector3(3.0, -8.0, -4.0), Vector3.ONE * 0.001)
	# Identitäts-Basis gespiegelt: y bleibt oben... nein - y zeigt nun nach unten,
	# x ist zusätzlich negiert (Rechtshändigkeit), z unverändert.
	assert_almost_eq(mirrored.basis.x, Vector3(-1, 0, 0), Vector3.ONE * 0.001)
	assert_almost_eq(mirrored.basis.y, Vector3(0, -1, 0), Vector3.ONE * 0.001)
	assert_almost_eq(mirrored.basis.z, Vector3(0, 0, 1), Vector3.ONE * 0.001)

func test_mirror_basis_stays_right_handed() -> void:
	# Eine linkshändige Basis (Determinante -1) wäre für Kameras ungültig -
	# auch bei geneigter Hauptkamera (der Normalfall: ZOOM_BASIS schaut steil
	# nach unten) muss die Spiegelbasis orthonormal und rechtshändig bleiben.
	reflection.plane_height = 0.16
	main_camera.global_transform = Transform3D(
		CameraRig.ZOOM_BASIS, Vector3(-24.0, 19.3, 0.0))
	reflection._process(0.0)
	var basis := reflection.mirror_camera.global_transform.basis
	assert_almost_eq(basis.determinant(), 1.0, 0.001, "rechtshändig + orthonormal")
	# Die Spiegelkamera schaut nach OBEN zur Glasfläche (Blick = -z).
	assert_gt((-basis.z).y, 0.0, "der Spiegelblick geht von unten gegen das Glas")

func test_mark_reflective_covers_a_whole_tray_with_dice() -> void:
	# Auch die Trays samt ihrer Slot-Würfel stehen auf dem Glas und spiegeln
	# sich (scene_root markiert die kompletten Tray-Knoten rekursiv).
	var tray: DiceTrayView = load("res://scenes/dice_pool_tray.tscn").instantiate()
	add_child_autofree(tray)
	ScreenReflection.mark_reflective(tray)
	var visuals := tray.find_children("*", "VisualInstance3D", true, false)
	assert_gt(visuals.size(), 0)
	for visual in visuals:
		assert_true((visual.layers & ScreenReflection.LAYER) != 0,
			"%s fehlt der Spiegel-Layer" % visual.name)

func test_mark_reflective_layers_every_visual_part_of_a_die() -> void:
	var die := DieBuilder.build()
	add_child_autofree(die)
	ScreenReflection.mark_reflective(die)
	var visuals := die.find_children("*", "VisualInstance3D", true, false)
	assert_gt(visuals.size(), 0)
	for visual in visuals:
		assert_true((visual.layers & ScreenReflection.LAYER) != 0,
			"%s fehlt der Spiegel-Layer" % visual.name)
		assert_true((visual.layers & 1) != 0,
			"%s muss für die Hauptkamera auf Layer 1 bleiben" % visual.name)
