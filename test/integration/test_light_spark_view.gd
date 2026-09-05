extends GutTest
## EIN LICHTFUNKE des DURCHLICHTS: oben am Turm zerfällt das Licht-Netz in bis zu
## sechs davon, und sie schlagen ALLE ZUGLEICH in die Seitenmitten des Würfels ein.
## Reine Anzeige - ein additives Billboard, das einen flachen Bogen fliegt.

var spark: LightSparkView

func before_each() -> void:
	spark = LightSparkView.new()
	add_child_autofree(spark)
	spark.setup(PressNetView.VALUE_TINT)

## Er ist LICHT: additiv, ohne Tiefentest, ein Billboard mit weichem Kern.
func test_a_spark_is_additive_billboard_light() -> void:
	var quad: MeshInstance3D = spark.get_node("Core")
	var material: StandardMaterial3D = quad.material_override
	assert_eq(material.blend_mode, BaseMaterial3D.BLEND_MODE_ADD)
	assert_eq(material.billboard_mode, BaseMaterial3D.BILLBOARD_ENABLED)
	assert_true(material.no_depth_test, "er liest über jeder Karte")
	assert_not_null(material.albedo_texture, "und trägt seinen weichen Kern")
	assert_almost_eq((quad.mesh as QuadMesh).size.x, LightSparkView.spark_size(),
		0.001)

## Alle Funken teilen EINE Textur - sechs Funken sind dasselbe Licht.
func test_all_sparks_share_one_core_texture() -> void:
	var second := LightSparkView.new()
	add_child_autofree(second)
	second.setup(PressNetView.VALUE_TINT)
	var a: StandardMaterial3D = (spark.get_node("Core") as MeshInstance3D).material_override
	var b: StandardMaterial3D = (second.get_node("Core") as MeshInstance3D).material_override
	assert_eq(a.albedo_texture, b.albedo_texture)

## Zeit 0 setzt ihn HART ans Ziel - Endzustand zuerst.
func test_a_flight_without_time_lands_hard() -> void:
	spark.seat_at(Vector3(0.0, 3.0, 0.0))
	spark.fly_to(Vector3(2.0, 1.0, 1.0), 0.0, 1.0)
	assert_almost_eq(spark.global_position.distance_to(Vector3(2.0, 1.0, 1.0)),
		0.0, 0.001)

## Der FLUG ist ein flacher Bogen: er landet exakt und kommt nie unter die Sehne.
func test_the_flight_arcs_over_the_chord_and_lands_exactly() -> void:
	spark.seat_at(Vector3(0.0, 3.0, 0.0))
	spark.fly_to(Vector3(0.0, 3.0, 4.0), 0.3, 1.0)
	assert_true(spark.flying())
	await wait_frames(4)
	assert_gt(spark.global_position.y, 3.0, "der Bogen steht über der Sehne")
	await wait_seconds(0.4)
	assert_almost_eq(spark.global_position.distance_to(Vector3(0.0, 3.0, 4.0)),
		0.0, 0.01, "und er landet exakt")

## Auch bergab bleibt er über der Sehne - unter sie kommt er nie.
func test_a_falling_flight_never_dips_below_the_chord() -> void:
	spark.seat_at(Vector3(0.0, 4.0, 0.0))
	spark.fly_to(Vector3(0.0, 1.0, 2.0), 0.3, 0.5)
	for i in 8:
		await wait_frames(1)
		var share := spark.global_position.z / 2.0
		assert_gte(spark.global_position.y, lerpf(4.0, 1.0, share) - 0.01,
			"nie unter der Sehne")
		if not spark.flying():
			break

## Ein Abbruch MITTEN im Flug schuldet nichts: settle stellt ihn auf sein Ziel.
func test_settle_stands_on_the_target() -> void:
	spark.seat_at(Vector3(0.0, 3.0, 0.0))
	spark.fly_to(Vector3(1.0, 2.0, 3.0), 2.0, 1.0)
	await wait_frames(3)
	spark.settle()
	assert_false(spark.flying())
	assert_almost_eq(spark.global_position.distance_to(Vector3(1.0, 2.0, 3.0)),
		0.0, 0.001)
