extends GutTest
## Die PINS der Module (Welle D): der EINE Körper eines Moduls - eigenes Modell je Modul,
## Hüllmaß, eigene Silhouette und die Zustands-Schreiber.

func _pin(part: ComboPart) -> ComboPartBody:
	var body := ComboPartBody.new()
	add_child_autofree(body)
	body.setup(part)
	return body

func _body(part_id: String) -> ComboPartBody:
	return _pin(ComboPart.make(part_id))

## Box eines Netzes im Raum des Körpers, samt aller Eltern dazwischen.
func _box_in_body(body: Node3D, mesh: MeshInstance3D) -> AABB:
	var xform := body.global_transform.affine_inverse() * mesh.global_transform
	return xform * mesh.get_aabb()

func test_every_module_has_its_own_pin_and_the_empty_place_its_own_model() -> void:
	assert_eq(ComboPartBody.pin_path(null), ComboPartBody.PIN_EMPTY)
	assert_true(ResourceLoader.exists(ComboPartBody.PIN_EMPTY))
	for part in ComboPart.all():
		assert_eq(ComboPartBody.pin_path(part), ComboPartBody.PIN_MODEL % part.id, "%s: eigener Pin" % part.id)
		var pin := _pin(part)
		for node_name in ["Model", "Korpus", "Licht"]:
			assert_not_null(pin.find_child(node_name, true, false), "%s: %s" % [part.id, node_name])
		for gone in ["Platte", "PlattenLicht", "Punkte"]:
			assert_null(pin.find_child(gone, true, false), "%s: kein %s - der Pin ist der Körper" % [part.id, gone])

func test_the_plate_models_are_gone() -> void:
	assert_false(ResourceLoader.exists("res://assets/models/hardware/part_module.glb"))
	for part in ComboPart.all():
		assert_false(ResourceLoader.exists("res://assets/models/hardware/part_%s.glb" % part.id), part.id)

func test_every_pin_stays_within_its_hull_around_its_center() -> void:
	var parts: Array = ComboPart.all()
	parts.append(null)
	var hull := ComboPartBody.HULL
	for part in parts:
		var pin := _pin(part)
		for mesh in pin.find_children("*", "MeshInstance3D", true, false):
			var box := _box_in_body(pin, mesh)
			var id := "%s %s" % [part.id if part != null else "leer", mesh.name]
			assert_gte(box.position.z, -hull.x * 0.5 - 0.15, id + ": der Hals steckt höchstens ein Stück im Chip")
			assert_lte(box.end.z, hull.x * 0.5 + 0.006, id + ": längs")
			assert_lte(absf(box.position.x), hull.y * 0.5 + 0.006, id + ": quer")
			assert_lte(absf(box.end.x), hull.y * 0.5 + 0.006, id + ": quer")
			assert_gte(box.position.y, -0.005, id + ": auf dem Tisch")
			assert_lte(box.end.y, hull.z + 0.006, id + ": Höhe")

func test_every_module_fills_its_pin() -> void:
	for part in ComboPart.all():
		var pin := _pin(part)
		var light := _box_in_body(pin, pin.find_child("Licht", true, false) as MeshInstance3D)
		var all := light
		for mesh in pin.find_children("*", "MeshInstance3D", true, false):
			all = all.merge(_box_in_body(pin, mesh))
		assert_gt(all.size.z, ComboPartBody.HULL.x * 0.78, "%s: lang" % part.id)
		assert_gt(all.size.x, ComboPartBody.HULL.y * 0.45, "%s: breit genug" % part.id)
		assert_gt(light.size.x * light.size.z, 0.04, "%s: ein großes Licht-Merkmal" % part.id)

func test_no_two_pins_share_an_outline() -> void:
	var seen := {}
	for part in ComboPart.all():
		var pin := _pin(part)
		var key := ""
		for name in ["Korpus", "Licht"]:
			var box := _box_in_body(pin, pin.find_child(name, true, false) as MeshInstance3D)
			key += "%.2f|%.2f|%.2f|%.2f;" % [box.position.x, box.end.x, box.position.z, box.end.z]
		assert_false(seen.has(key), "%s gleicht %s" % [part.id, seen.get(key, "")])
		seen[key] = part.id

func test_the_light_carries_the_phase_and_the_body_is_baked() -> void:
	var pin := _body(ComboPart.PARALLEL_CIRCUIT)
	var light := (pin.find_child("Licht", true, false) as MeshInstance3D).material_override as StandardMaterial3D
	assert_eq(light.emission, ComboPart.parallel_circuit().tint())
	var korpus := (pin.find_child("Korpus", true, false) as MeshInstance3D).material_override as StandardMaterial3D
	assert_true(korpus.vertex_color_use_as_albedo, "das Licht ist eingemalt")

func test_a_resting_pin_stays_bright_and_flashes_full() -> void:
	var pin := _body(ComboPart.CAPACITOR)
	pin.set_resting(true)
	assert_almost_eq(pin.light_energy(), ComboPartBody.WINDOW_ENERGY * ComboPartBody.REST_SHARE, 0.001)
	assert_gt(ComboPartBody.REST_SHARE, 0.6, "nicht mehr auf 40 % gedimmt")
	pin.flash(2.0)
	await wait_frames(1)
	assert_gt(pin.light_energy(), ComboPartBody.WINDOW_ENERGY)
	assert_gt(pin.scale.x, 1.0, "der Krit-Schlag poppt")

# --- Zustand am Körper -----------------------------------------------------------------------

func test_the_counter_shows_its_value_as_digits() -> void:
	var pin := _body(ComboPart.COUNTER)
	pin.part.counter = 6
	pin.set_state({})
	assert_eq(pin.digits_text(), "007", "+1 Mult und sechs Wertungen")

func test_the_error_memory_lights_one_lamp_per_fumble() -> void:
	var pin := _body(ComboPart.ERROR_MEMORY)
	pin.set_state({})
	assert_eq(pin.lit_state_parts(), 0)
	pin.part.counter = 2
	pin.set_state({})
	assert_eq(pin.lit_state_parts(), 2)
	pin.part.counter = 9
	pin.set_state({})
	assert_eq(pin.lit_state_parts(), ComboPartBody.ERROR_LAMPS, "mehr Lampen gibt es nicht")

func test_the_resonator_fills_its_windings_with_growth() -> void:
	var pin := _body(ComboPart.RESONATOR)
	pin.part.counter = 3
	pin.set_state({})
	assert_eq(pin.lit_state_parts(), 3)

func test_the_series_terminal_lights_one_screw_per_module() -> void:
	var pin := _body(ComboPart.SERIES_TERMINAL)
	pin.set_state({"chip_parts": 2})
	assert_eq(pin.lit_state_parts(), 2)
	pin.set_state({"chip_parts": 5})
	assert_eq(pin.lit_state_parts(), ComboPartBody.TERMINALS, "höchstens drei")

func test_the_series_terminal_counts_the_modules_of_its_chip() -> void:
	var chip := ComboChipView.new()
	add_child_autofree(chip)
	chip.combo_key = DiceScoring.TWO_KIND
	chip.setup(4.0)
	chip.set_sockets([ComboPart.series_terminal(), ComboPart.capacitor(), ComboPart.resistor()])
	assert_eq(chip.pin_body(0).lit_state_parts(), 3)

func test_the_starter_glows_only_before_the_first_hand() -> void:
	var pin := _body(ComboPart.STARTER)
	pin.set_state({"first_hand": true})
	var on := pin.light_energy()
	pin.set_state({"first_hand": false})
	assert_gt(on, pin.light_energy(), "danach dunkel")
	assert_almost_eq(pin.light_energy(), ComboPartBody.DIM_ENERGY, 0.0001)

func test_the_afterburner_shows_its_flame_only_when_armed() -> void:
	var pin := _body(ComboPart.AFTERBURNER)
	pin.set_state({})
	assert_false(pin.flame_shown())
	pin.part.counter = 1
	pin.set_state({})
	assert_true(pin.flame_shown(), "scharf")

func test_the_coupling_lights_its_field_in_the_copied_colour() -> void:
	var pin := _body(ComboPart.COUPLING)
	pin.set_state({})
	var field := pin.find_child("Abbild", true, false) as MeshInstance3D
	assert_not_null(field)
	var material := field.material_override as StandardMaterial3D
	assert_eq(pin.copy_id(), "", "kopiert nichts: dunkel")
	assert_almost_eq(material.emission_energy_multiplier, ComboPartBody.DIM_ENERGY, 0.0001)
	pin.set_state({"copy": ComboPart.capacitor()})
	assert_eq(pin.copy_id(), ComboPart.CAPACITOR)
	assert_eq(material.emission, ComboPart.capacitor().tint(), "das Feld leuchtet in der Farbe der Kopie")

func test_a_pin_on_a_turned_chip_points_right_in_the_picture() -> void:
	var chip := ComboChipView.new()
	add_child_autofree(chip)
	chip.rotation.y = -PI / 2.0
	chip.combo_key = DiceScoring.TWO_KIND
	chip.setup(4.0)
	chip.set_sockets([ComboPart.cross_bridge(), null, null])
	assert_almost_eq(chip.pin_body(0).global_basis.z.z, 1.0, 0.001, "der Pfeil zeigt im Bild nach rechts")
