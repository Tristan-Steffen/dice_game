extends GutTest
## Das GERÜST der Kammer: der Rahmenwürfel um den Würfelplatz, die acht Streben an die
## Würfelecken, welche Spuren eine Serie leuchten läßt - und daß der harte Weg keine
## Strebe stehen läßt.

const HALF_EDGE := 0.85
const DEPTH := 3.5
const DROP := 1.75
const HALF := Vector2(3.2, 4.0)

var rig: ChamberRigView

func before_each() -> void:
	rig = ChamberRigView.new()
	add_child_autofree(rig)
	rig.setup(Vector3.ZERO, HALF, DEPTH, DROP, HALF_EDGE)

func _projection(bonus_face := -1, material_face := -1, rune_face := -1) -> Dictionary:
	var out := SeriesResolver.blank()
	if bonus_face >= 0:
		out["bonus"][bonus_face] = 3
	if material_face >= 0:
		out["materials"][material_face] = "gold"
	if rune_face >= 0:
		out["runes"][rune_face] = ["afterglow"]
	return out

func _dock(plan: Array[Dictionary], basis := Basis.IDENTITY) -> void:
	rig.dock(rig.die_center(), basis, plan, 0.0)

func test_the_plan_names_every_changed_face_and_channel() -> void:
	var plan := ChamberRigView.cable_plan(_projection(2, 2, 2))
	assert_eq(plan.size(), 3)
	for entry in plan:
		assert_eq(int(entry["face"]), 2)
	assert_eq(ChamberRigView.plan_channels(plan), [0, 1, 2] as Array[int])

func test_the_sonderbestand_has_its_own_lane() -> void:
	var doped := SeriesResolver.blank()
	doped["doped"][1] = true
	assert_eq(ChamberRigView.plan_channels(ChamberRigView.cable_plan(doped)), [3] as Array[int])
	var copied := SeriesResolver.blank()
	copied["copies"] = [{"from": 0, "to": 4}]
	var plan := ChamberRigView.cable_plan(copied)
	assert_eq(int(plan[0]["face"]), 4, "das Ziel der Kopie")
	assert_eq(String(plan[0]["channel"]), ChamberRigView.CH_SPECIAL)

func test_the_frame_has_the_proportions_of_the_die() -> void:
	var reach := ChamberRigView.die_reach(HALF_EDGE)
	assert_gt(reach, HALF_EDGE, "der Kantenrahmen zählt mit")
	assert_almost_eq(rig.frame_half(), reach * ChamberRigView.FRAME_SCALE, 0.001)
	assert_eq(rig.die_center(), Vector3(0.0, -DROP, 0.0), "um den Würfelplatz")

func test_the_frame_fits_into_the_chamber() -> void:
	var r := rig.frame_half() + ChamberRigView.JOINT * 0.5
	assert_lt(rig.die_center().y + r, 0.0, "unter dem Tisch")
	assert_gt(rig.die_center().y - r, -DEPTH, "über dem Boden")
	assert_lt(r, HALF.x, "zwischen den Wänden")
	assert_lt(r, HALF.y)

func test_the_same_measures_build_nothing_new() -> void:
	var frame := rig.get_node("Geruest")
	rig.setup(Vector3.ZERO, HALF, DEPTH, DROP, HALF_EDGE)
	assert_eq(rig.get_node("Geruest"), frame)

func test_eight_struts_run_from_the_frame_corners_to_the_die_corners() -> void:
	_dock(ChamberRigView.cable_plan(_projection(0)))
	assert_true(rig.docked())
	assert_eq(rig.arm_count(), 8, "alle acht Ecken, was auch immer die Serie ändert")
	var reach := ChamberRigView.die_reach(HALF_EDGE)
	for i in rig.arm_count():
		var ends := rig.arm_ends(i)
		var outer: Vector3 = ends[0] - rig.die_center()
		var inner: Vector3 = ends[1] - rig.die_center()
		for axis in 3:
			assert_almost_eq(absf(outer[axis]), rig.frame_half(), 0.001, "eine Ecke des Rahmenwürfels")
			assert_almost_eq(absf(inner[axis]), reach, 0.001, "eine Ecke des Würfels")
			assert_eq(signf(outer[axis]), signf(inner[axis]), "dieselbe Ecke - die Strebe läuft schräg")

func test_a_turned_die_is_gripped_at_its_own_corners() -> void:
	var basis := Basis(Vector3.UP, PI * 0.5)
	_dock(ChamberRigView.cable_plan(_projection(0)), basis)
	var seen := {}
	for i in rig.arm_count():
		var ends := rig.arm_ends(i)
		assert_eq(ChamberRigView.station_of(ends[1] - rig.die_center()),
			ChamberRigView.station_of(ends[0] - rig.die_center()), "die nächste Gerüst-Ecke")
		seen[ChamberRigView.station_of(ends[0] - rig.die_center())] = true
	assert_eq(seen.size(), 8, "jede Gerüst-Ecke genau einmal")

func test_only_the_lanes_of_the_series_light_up() -> void:
	_dock(ChamberRigView.cable_plan(_projection(0, -1, 3)))
	assert_eq(rig.active_channels(), [0, 2] as Array[int])
	for rank in ChamberRigView.CHANNELS.size():
		assert_almost_eq(rig.lane_glow(rank), ChamberRigView.REST_GLOW, 0.001, "vor dem Strom ruhen alle")
	rig.pulse(0.01)
	await wait_seconds(0.1)
	assert_almost_eq(rig.lane_glow(0), ChamberRigView.PULSE_GLOW, 0.01)
	assert_almost_eq(rig.lane_glow(2), ChamberRigView.PULSE_GLOW, 0.01)
	assert_almost_eq(rig.lane_glow(1), ChamberRigView.REST_GLOW, 0.001, "eine fremde Spur bleibt ruhig")

func test_the_hard_path_leaves_no_strut() -> void:
	_dock(ChamberRigView.cable_plan(_projection(0)))
	rig.pulse(0.5)
	rig.settle_hard()
	assert_false(rig.docked())
	assert_eq(rig.arm_count(), 0)
	assert_true(rig.active_channels().is_empty())
	assert_almost_eq(rig.lane_glow(0), ChamberRigView.REST_GLOW, 0.001)
	assert_almost_eq(rig.ring_glow(), ChamberRigView.RING_REST, 0.001)

func test_the_machine_floor_carries_a_light_ring_under_the_die() -> void:
	var ring := rig.get_node("Geruest/Lichtring") as MeshInstance3D
	assert_almost_eq(ring.position.x, rig.die_center().x, 0.001)
	assert_almost_eq(ring.position.z, rig.die_center().z, 0.001)
	assert_almost_eq(ring.position.y, -DEPTH, 0.1, "auf dem Boden")

func test_release_retracts_and_clears() -> void:
	_dock(ChamberRigView.cable_plan(_projection(0)))
	rig.release(0.05)
	assert_false(rig.docked(), "Endzustand zuerst")
	await wait_seconds(0.2)
	assert_eq(rig.arm_count(), 0)
