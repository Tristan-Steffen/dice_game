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
	var seen := {}
	for i in EnergyRingView.SEGMENTS:
		assert_not_null(ring.segment(i), "Segment %d steht im Modell" % i)
		seen[ring.segment(i).get_instance_id()] = true
	assert_eq(seen.size(), 50, "je Energie ein eigener Körper")

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

func test_no_light_and_no_shadow() -> void:
	var ring := _ring()
	ring.set_energy(4, 25)
	assert_eq(ring.find_children("*", "Light3D", true, false).size(), 0)
	for mesh in ring.find_children("*", "MeshInstance3D", true, false):
		assert_eq((mesh as MeshInstance3D).cast_shadow,
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

func test_the_model_stands_proud_and_the_core_carries_the_number() -> void:
	var ring := _ring()
	ring.set_energy(4, 5)
	var core := ring.find_child("Core", true, false) as MeshInstance3D
	assert_not_null(core)
	assert_almost_eq(core.get_aabb().end.y, EnergyRingView.CORE_TOP, 0.001, "Skript und Modell gleich hoch")
	assert_gt(EnergyRingView.CORE_TOP, 0.3, "das Gehäuse ragt aus dem Tisch")

func test_the_loose_elko_keeps_its_form() -> void:
	var elko := ElkoBody.build()
	add_child_autofree(elko)
	assert_eq(elko.get_child_count(), 3, "Ring plus zwei Beine")
	assert_gt(ElkoBody.CRIMP_DIAMETER, ElkoBody.CAN_DIAMETER)
	assert_eq(ElkoBody.height(), ElkoBody.CRIMP_DIAMETER)
