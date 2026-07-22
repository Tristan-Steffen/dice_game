extends GutTest
## Wurfstreuung und Flugbahn - die reinen Statics ohne Szenenbaum.

func test_spread_gives_one_target_per_die() -> void:
	assert_eq(DiceController._spread_targets(6).size(), 6)
	assert_eq(DiceController._spread_targets(1).size(), 1)

func test_spread_targets_never_overlap() -> void:
	# Kern der Stapel-Vorbeugung: zwei Ziele duerfen sich nie beruehren.
	var min_gap := DiceController.DIE_HALF_DIAGONAL * 2.0
	for _attempt in 200:
		for count in range(1, 7):
			var targets := DiceController._spread_targets(count)
			for a in count:
				for b in range(a + 1, count):
					assert_gt(absf(targets[a].z - targets[b].z), min_gap,
						"Bahnen %d/%d bei %d Wuerfeln zu nah" % [a, b, count])

func test_spread_stays_inside_the_pit() -> void:
	for _attempt in 100:
		for target in DiceController._spread_targets(6):
			assert_lt(absf(target.z), DicePit.PIT_HALF_Z - 1.0)
			assert_lt(absf(target.x), DicePit.PIT_HALF_X - 1.0)

func test_face_index_matches_the_axis_calibration() -> void:
	# Jede Achsrichtung liefert genau ihren kalibrierten Face-Index zurück -
	# Grundlage des Seiten-Hovers in der Grube.
	for axis in DiceController.AXIS_DIRECTIONS:
		var dir: Vector3 = DiceController.AXIS_DIRECTIONS[axis]
		assert_eq(DiceController.face_index_for_local_dir(dir),
			DiceController.AXIS_FACE_INDEX[axis], "Achse %s" % axis)

func test_face_index_snaps_a_tilted_normal_to_the_nearest_face() -> void:
	# Ein leicht verkippter Normal (Treffer nahe einer Kante) rundet auf die
	# dominante Achse - hier OBEN.
	var tilted := (Vector3.UP + Vector3.RIGHT * 0.3).normalized()
	assert_eq(DiceController.face_index_for_local_dir(tilted),
		DiceController.AXIS_FACE_INDEX["OBEN"])

func test_later_dice_fly_longer_so_they_land_apart() -> void:
	# Gleiche Bahn, groessere Flugzeit -> flacherer, langsamerer Wurf.
	var from := Vector3(0.0, 17.0, 0.0)
	var to := Vector3(0.0, 0.0, 5.0)
	var early := DiceController._throw_velocity(from, to, 34.3, 999.0, 0.6)
	var late := DiceController._throw_velocity(from, to, 34.3, 999.0, 0.8)
	assert_lt(late.z, early.z)

func test_throw_velocity_hits_the_target_after_its_flight_time() -> void:
	var from := Vector3(2.0, 17.0, -3.0)
	var to := Vector3(-1.0, 0.0, 6.0)
	var g := 34.3
	var t := 0.75
	var v := DiceController._throw_velocity(from, to, g, 999.0, t)
	var landed := Vector3(
		from.x + v.x * t, from.y + v.y * t - 0.5 * g * t * t, from.z + v.z * t)
	assert_almost_eq(landed.x, to.x, 0.001)
	assert_almost_eq(landed.y, to.y, 0.001)
	assert_almost_eq(landed.z, to.z, 0.001)
