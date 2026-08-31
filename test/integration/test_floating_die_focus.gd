extends GutTest
## Die INSPEKTION am schwebenden Würfel: ein Zug dreht ihn um die BILD-Achsen,
## der Rückweg legt ihn in seine Schwebe-Ruhelage zurück. Das Fenster gibt es
## nicht - der Würfel IST die Ansicht.

var stage: FloatingDie
var camera: Camera3D

func before_each() -> void:
	camera = Camera3D.new()
	add_child_autofree(camera)
	camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 5.0))
	stage = FloatingDie.new()
	add_child_autofree(stage)
	stage.setup(DieDefinition.new(), Color.WHITE, Vector3.ZERO)
	stage.land_at(Vector3.ZERO, 0.0)

func _basis() -> Basis:
	return stage.die.global_basis.orthonormalized()

func test_die_ruhelage_ist_die_vitrinen_lage_der_tray_wuerfel() -> void:
	assert_true(_basis().is_equal_approx(FloatingDie.rest_pose()),
		"frisch gebaut liegt er schon in seiner Ruhelage")

func test_ein_zug_dreht_um_die_bild_achsen() -> void:
	var before := _basis()
	stage.spin(Vector2(120.0, 0.0), camera)
	var after := _basis()
	assert_false(after.is_equal_approx(before), "waagerecht gezogen dreht ihn")
	# Bild-Hochachse: die Kamera blickt entlang -Z, ihre y ist Welt-+Y.
	var turned := before.rotated(camera.global_basis.y.normalized(),
		120.0 * FloatingDie.SPIN_SENSITIVITY)
	assert_true(after.is_equal_approx(turned), "und zwar genau um die Bild-Hochachse")

func test_ein_zug_nach_unten_dreht_um_die_bild_querachse() -> void:
	var before := _basis()
	stage.spin(Vector2(0.0, 90.0), camera)
	var turned := before.rotated(camera.global_basis.x.normalized(),
		90.0 * FloatingDie.SPIN_SENSITIVITY)
	assert_true(_basis().is_equal_approx(turned))

func test_der_rueckweg_legt_ihn_in_die_ruhelage_und_haelt_seine_groesse() -> void:
	stage.spin(Vector2(200.0, 140.0), camera)
	assert_false(_basis().is_equal_approx(FloatingDie.rest_pose()), "er steht verdreht")
	stage.pose_to(FloatingDie.rest_pose(), 0.1)
	await wait_seconds(0.25)
	assert_true(_basis().is_equal_approx(FloatingDie.rest_pose()),
		"und liegt danach wieder wie jeder Tray-Würfel")
	assert_almost_eq(stage.die.global_basis.get_scale(),
		Vector3.ONE * DiceTrayView.DIE_SCALE, Vector3.ONE * 0.001,
		"die Skalierung steckt in der Basis - sie muß beim Setzen mit hinein")

func test_ein_zug_uebernimmt_die_laufende_rueckfahrt() -> void:
	stage.spin(Vector2(200.0, 0.0), camera)
	stage.pose_to(FloatingDie.rest_pose(), 2.0)
	await wait_frames(2)
	var caught := _basis()
	stage.spin(Vector2(30.0, 0.0), camera)
	await wait_frames(3)
	var turned := caught.rotated(camera.global_basis.y.normalized(),
		30.0 * FloatingDie.SPIN_SENSITIVITY)
	assert_true(_basis().is_equal_approx(turned),
		"der Spieler übernimmt die Lage - der Tween schreibt nicht dagegen")
