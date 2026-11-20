extends GutTest
## Die KABEL der Kammer: welche Seiten und Kanäle wie viele Kabel bekommen, wo sie
## klemmen, und daß der harte Weg keines stehen läßt.

const HALF_EDGE := 0.85
const DIE_AT := Vector3(0.0, -1.7, 0.0)

var rig: ChamberRigView

func before_each() -> void:
	rig = ChamberRigView.new()
	add_child_autofree(rig)
	rig.setup(Vector3.ZERO, Vector2(2.7, 2.7), 3.4)

func _projection(bonus_face := -1, material_face := -1, rune_face := -1) -> Dictionary:
	var out := SeriesResolver.blank()
	if bonus_face >= 0:
		out["bonus"][bonus_face] = 3
	if material_face >= 0:
		out["materials"][material_face] = "gold"
	if rune_face >= 0:
		out["runes"][rune_face] = ["afterglow"]
	return out

func test_one_face_gets_four_cables() -> void:
	var plan := ChamberRigView.cable_plan(_projection(3))
	assert_eq(plan.size(), 1, "eine Seite, ein Kanal")
	assert_eq(ChamberRigView.plan_cable_count(plan), 4, "vier Ecken, vier Kabel")

func test_every_upgrade_type_brings_its_own_four_cables() -> void:
	var plan := ChamberRigView.cable_plan(_projection(3, 3, 3))
	assert_eq(ChamberRigView.plan_cable_count(plan), 12, "Zahl, Material und Rune je vier")
	var channels: Array[String] = []
	for entry in plan:
		channels.append(String(entry["channel"]))
	assert_eq(channels, ChamberRigView.CHANNELS.slice(0, 3), "in dieser Reihenfolge")
	assert_ne(ChamberRigView.channel_tint(ChamberRigView.CH_NUMBER),
		ChamberRigView.channel_tint(ChamberRigView.CH_MATERIAL), "jeder in seiner Farbe")
	assert_ne(ChamberRigView.channel_tint(ChamberRigView.CH_MATERIAL),
		ChamberRigView.channel_tint(ChamberRigView.CH_RUNE))

func test_the_sonderbestand_brings_its_own_cables() -> void:
	var doped := _projection()
	doped["doped"][2] = true
	var plan := ChamberRigView.cable_plan(doped)
	assert_eq(plan.size(), 1)
	assert_eq(String(plan[0]["channel"]), ChamberRigView.CH_SPECIAL, "die Veredelung")
	var copied := _projection()
	copied["copies"].append({"card": 0, "from": 1, "to": 4})
	plan = ChamberRigView.cable_plan(copied)
	assert_eq(int(plan[0]["face"]), 4, "die Pointer-Kopie faßt ihre Zielseite")
	assert_eq(String(plan[0]["channel"]), ChamberRigView.CH_SPECIAL)
	var full := _projection(3, 3, 3)
	full["doped"][3] = true
	assert_eq(ChamberRigView.plan_cable_count(ChamberRigView.cable_plan(full)), 16,
		"vier Sorten, vier Kabel je Ecke")
	var tints := {}
	for channel in ChamberRigView.CHANNELS:
		tints[ChamberRigView.channel_tint(channel)] = true
	assert_eq(tints.size(), 4, "jede Sorte in ihrer Farbe")

func test_a_series_that_only_tends_clamps_all_eight_corners() -> void:
	assert_eq(ChamberRigView.cable_plan(_projection()).size(), 0, "ohne Pflege nichts")
	var plan := ChamberRigView.cable_plan(_projection(), true)
	assert_eq(ChamberRigView.plan_cable_count(plan), 8, "Kühlen und Reparatur fassen alle Ecken")

func test_the_corners_of_a_face_lie_on_that_face() -> void:
	for face in StampNet.FACES:
		var dir := ChamberRigView.face_direction(face)
		var corners := ChamberRigView.face_corners(face)
		assert_eq(corners.size(), 4, "vier Ecken je Seite")
		for corner in corners:
			assert_almost_eq(corner.dot(dir), 1.0, 0.001, "alle auf der Seite")

func test_docked_cables_run_from_the_wall_to_the_corners() -> void:
	var plan := ChamberRigView.cable_plan(_projection(3, 3))
	rig.dock(DIE_AT, Basis.IDENTITY, HALF_EDGE, plan, 0.0)
	assert_true(rig.docked())
	assert_eq(rig.cable_count(), 8)
	var seen: Array[Vector3] = []
	for i in rig.cable_count():
		var ends := rig.cable_ends(i)
		var from: Vector3 = ends[0]
		var to: Vector3 = ends[1]
		assert_almost_eq(maxf(absf(from.x), absf(from.z)), 2.7, 0.05, "der Port sitzt an der Wand")
		assert_lt(from.y, 0.0, "unter dem Tisch")
		assert_gt(from.y, -3.4, "über dem Kammerboden")
		assert_lt(to.distance_to(DIE_AT), HALF_EDGE * 1.8, "die Klemme sitzt am Würfel")
		assert_gt(to.y, DIE_AT.y, "an der oberen Seite")
		var known := false
		for other in seen:
			known = known or to.distance_to(other) < 0.01
		if not known:
			seen.append(to)
	assert_eq(seen.size(), 4, "je Ecke der Seite EIN Stecker, den sich ihre Kabel teilen")

func test_the_hard_path_leaves_no_cable() -> void:
	rig.dock(DIE_AT, Basis.IDENTITY, HALF_EDGE, ChamberRigView.cable_plan(_projection(0)), 0.3)
	assert_eq(rig.cable_count(), 4, "angeklemmt ist der Endzustand - sofort")
	rig.pulse(0.2)
	rig.settle_hard()
	assert_false(rig.docked())
	assert_eq(rig.cable_count(), 0)

func test_release_retracts_and_clears() -> void:
	rig.dock(DIE_AT, Basis.IDENTITY, HALF_EDGE, ChamberRigView.cable_plan(_projection(0)), 0.0)
	rig.release(0.05)
	assert_false(rig.docked(), "gelöst ist sofort wahr")
	await wait_seconds(0.2)
	assert_eq(rig.cable_count(), 0, "und dann sind sie in der Wand")

func test_every_station_shows_one_socket_per_channel() -> void:
	assert_eq(rig.socket_count(), 32, "acht Stationen, je vier Buchsen")
	assert_eq(rig.plugs_home(), 32, "eingefahren steckt jeder Stecker sichtbar")
	rig.setup(Vector3.ZERO, Vector2(2.7, 2.7), 3.4)
	assert_eq(rig.socket_count(), 32, "dieselben Maße bauen nichts dazu")

func test_a_corner_draws_from_the_same_corner_of_the_pit() -> void:
	rig.dock(DIE_AT, Basis.IDENTITY, HALF_EDGE,
		ChamberRigView.cable_plan(_projection(), true), 0.0)
	assert_eq(rig.cable_count(), 8)
	for i in rig.cable_count():
		var ends := rig.cable_ends(i)
		var from: Vector3 = ends[0]
		var offset: Vector3 = ends[1] - DIE_AT
		assert_eq(signf(from.x), signf(offset.x), "dieselbe Seite längs")
		assert_eq(signf(from.z), signf(offset.z), "dieselbe Seite quer")
		assert_eq(from.y > -1.7, offset.y > 0.0, "obere Ecken oben, untere unten")
		var station := ChamberRigView.station_of(offset)
		assert_almost_eq(from, rig.socket_point(station[0], station[1], station[2], 3),
			Vector3.ONE * 0.001, "genau aus der Sonder-Buchse seiner Station")

func test_a_used_socket_gives_its_plug_and_gets_it_back() -> void:
	rig.dock(DIE_AT, Basis.IDENTITY, HALF_EDGE, ChamberRigView.cable_plan(_projection(3)), 0.0)
	assert_eq(rig.plugs_home(), 28, "vier Stecker sind ausgezogen")
	rig.settle_hard()
	assert_eq(rig.plugs_home(), 32, "und sitzen danach wieder in ihrer Buchse")

func test_each_face_corner_gets_one_harness_with_one_connector() -> void:
	rig.dock(DIE_AT, Basis.IDENTITY, HALF_EDGE, ChamberRigView.cable_plan(_projection(3, 3)), 0.0)
	assert_eq(rig.harness_count(), 4, "je Ecke der Seite EIN Strang")
	assert_eq(rig.cable_count(), 8, "zwei Sorten, also zwei Kabel je Strang")
	for i in rig.cable_count():
		var to: Vector3 = rig.cable_ends(i)[1]
		assert_almost_eq(to.y, DIE_AT.y + HALF_EDGE, 0.1, "der Stecker sitzt auf dem Rand der Seite")
		assert_gt(maxf(absf(to.x), absf(to.z)), HALF_EDGE * 0.55, "an der Ecke, nicht auf der Fläche")
