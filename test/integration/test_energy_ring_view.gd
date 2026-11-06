extends GutTest
## Der Energie-Ring ist reine Anzeige: je Segment eine Energie, bis zum Limit.

func _ring() -> EnergyRingView:
	var ring := EnergyRingView.new()
	add_child_autofree(ring)
	return ring

func test_every_segment_of_the_limit_stands_from_the_start() -> void:
	var ring := _ring()
	ring.set_energy(0, 5)
	assert_eq(EnergyRingView.SEGMENTS, 50)
	assert_not_null(ring.segment(49))
	assert_eq(ring.segment(0).mesh, ring.segment(24).mesh, "außen ein Mesh")
	assert_ne(ring.segment(24).mesh, ring.segment(25).mesh, "innen ein engeres")

func test_three_states_locked_awake_stored() -> void:
	var ring := _ring()
	ring.set_energy(3, 10)
	var awake: Material = ring.segment(5).material_override
	var locked: Material = ring.segment(49).material_override
	assert_ne(awake, locked)
	for i in 3:
		assert_ne(ring.segment(i).material_override, awake, "Segment %d ist geladen" % i)
		assert_ne(ring.segment(i).material_override, locked)
	for i in range(3, 10):
		assert_eq(ring.segment(i).material_override, awake, "Segment %d glimmt leer" % i)
	for i in range(10, 50):
		assert_eq(ring.segment(i).material_override, locked, "Segment %d schläft" % i)

func test_the_core_names_stock_and_cap() -> void:
	var ring := _ring()
	ring.set_energy(12, 25)
	assert_eq(ring.number_text(), "12")
	assert_eq(ring.cap_text(), "/ 25")

func test_values_are_clamped_to_cap_and_limit() -> void:
	var ring := _ring()
	ring.set_energy(99, 5)
	assert_eq(ring.energy_count(), 5)
	ring.set_energy(-4, 5)
	assert_eq(ring.energy_count(), 0)
	ring.set_energy(0, 99)
	assert_eq(ring.cap_count(), 50)

func test_the_second_ring_wakes_past_twenty_five() -> void:
	var ring := _ring()
	ring.set_energy(0, 25)
	var locked: Material = ring.segment(25).material_override
	ring.set_energy(30, 50)
	assert_ne(ring.segment(25).material_override, locked)
	assert_eq(ring.energy_count(), 30)

func test_a_rising_cap_sweeps_and_a_first_set_does_not() -> void:
	var ring := _ring()
	ring.set_energy(0, 5)
	assert_false(ring.sweeping(), "der Laufstart ist kein Ausbau")
	ring.set_energy(0, 10)
	assert_true(ring.sweeping())
	await wait_seconds(EnergyRingView.SWEEP_TIME * 1.5)
	assert_false(ring.sweeping(), "der Lauf endet von selbst")

func test_pulse_returns_to_the_rest_scale() -> void:
	var ring := _ring()
	ring.scale = Vector3.ONE * 2.0
	ring.pulse()
	await wait_seconds(0.5)
	assert_almost_eq(ring.scale.x, 2.0, 0.001)

func test_groups_leave_a_wider_gap_than_segments() -> void:
	var inside := EnergyRingView.segment_angle_deg(1) - EnergyRingView.segment_angle_deg(0)
	var across := EnergyRingView.segment_angle_deg(5) - EnergyRingView.segment_angle_deg(4)
	assert_gt(across, inside, "Fünfergruppen bleiben zählbar")
	assert_almost_eq(EnergyRingView.segment_angle_deg(5) - EnergyRingView.segment_angle_deg(0),
		72.0, 0.001)

func test_no_light_and_no_shadow() -> void:
	var ring := _ring()
	ring.set_energy(4, 25)
	for child in ring.get_children():
		assert_false(child is Light3D)
		if child is MeshInstance3D:
			assert_eq((child as MeshInstance3D).cast_shadow,
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

func test_the_loose_elko_keeps_its_form() -> void:
	var elko := ElkoBody.build()
	add_child_autofree(elko)
	assert_eq(elko.get_child_count(), 3, "Ring plus zwei Beine")
	assert_gt(ElkoBody.CRIMP_DIAMETER, ElkoBody.CAN_DIAMETER)
	assert_eq(ElkoBody.height(), ElkoBody.CRIMP_DIAMETER)
