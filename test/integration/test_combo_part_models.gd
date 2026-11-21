extends GutTest
## Die Bauteile der Module (Welle B): eigenes Modell je Modul, Hüllmaß, Höhen-Leiter,
## die Zustands-Schreiber und die Punktreihe; dazu die PINS der Welle C.

func _body(part_id: String) -> ComboPartBody:
	var body := ComboPartBody.new()
	add_child_autofree(body)
	body.setup(ComboPart.make(part_id))
	return body

## Box eines Netzes im Raum des Modells (Model-Knoten), samt aller Eltern dazwischen.
func _box_in_model(model: Node3D, mesh: MeshInstance3D) -> AABB:
	var xform := model.global_transform.affine_inverse() * mesh.global_transform
	return xform * mesh.get_aabb()

func _modules() -> Array[ComboPart]:
	var out: Array[ComboPart] = []
	out.assign(ComboPart.all())
	return out

func test_every_module_has_its_own_model_with_body_and_light() -> void:
	for part in ComboPart.all():
		assert_eq(ComboPartBody.model_path(part), ComboPartBody.OWN_MODEL % part.id, "%s: eigenes glb" % part.id)
		var body := _body(part.id)
		for node_name in ["Platte", "Model", "Korpus", "Licht"]:
			assert_not_null(body.find_child(node_name, true, false), "%s: %s" % [part.id, node_name])
		for gone in ["Gehaeuse", "Plattform", "Stecker"]:
			assert_null(body.find_child(gone, true, false), "%s: kein %s mehr - die Platte trägt" % [part.id, gone])

func test_a_part_without_its_own_model_keeps_the_basic_housing() -> void:
	var unknown := ComboPart.new()
	unknown.id = "ohne_modell"
	assert_eq(ComboPartBody.model_path(unknown), ComboPartBody.MODULE_SCENE)

func test_every_module_stands_on_the_plate_within_its_hull_and_height() -> void:
	for part in _modules():
		var body := _body(part.id)
		var model := body.find_child("Model", false, false) as Node3D
		assert_eq(model.scale, Vector3.ONE, "%s: unskaliert" % part.id)
		var rise: float = ComboPartBody.RISE[part.rarity]
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.get_parent().name == "Kopie":
				continue
			var box := _box_in_model(model, mesh)
			var id := "%s %s" % [part.id, mesh.name]
			assert_lte(absf(box.position.z), ComboPartBody.HULL.y * 0.5 + 0.006, id + ": längs")
			assert_lte(absf(box.end.z), ComboPartBody.HULL.y * 0.5 + 0.006, id + ": längs")
			assert_lte(absf(box.position.x), ComboPartBody.HULL.x * 0.5 + 0.006, id + ": quer")
			assert_lte(absf(box.end.x), ComboPartBody.HULL.x * 0.5 + 0.006, id + ": quer")
			assert_gte(box.position.y, -0.005, id + ": auf der Platte")
			assert_lte(box.end.y, rise + 0.006, id + ": Höhe nach Seltenheit")
		# Und nichts reicht über die Platte hinaus.
		assert_lte(ComboPartBody.MODEL_SHIFT + ComboPartBody.HULL.x * 0.5, ComboPartBody.PLATE.x * 0.5, part.id)

func test_the_height_ladder_grows_with_rarity() -> void:
	var tops := {}
	for part in _modules():
		var body := _body(part.id)
		var model := body.find_child("Model", false, false) as Node3D
		var top := 0.0
		for name in ["Korpus", "Licht"]:
			top = maxf(top, _box_in_model(model, body.find_child(name, true, false) as MeshInstance3D).end.y)
		tops[part.rarity] = maxf(float(tops.get(part.rarity, 0.0)), top)
		assert_gt(top, float(ComboPartBody.RISE[part.rarity]) * 0.6, "%s nutzt seine Höhe" % part.id)
	assert_lt(tops[ComboPart.RARITY_COMMON], tops[ComboPart.RARITY_RARE])
	assert_lt(tops[ComboPart.RARITY_RARE], tops[ComboPart.RARITY_EPIC])
	assert_lt(tops[ComboPart.RARITY_EPIC], tops[ComboPart.RARITY_LEGENDARY])

func test_the_plate_hints_the_rarity_and_the_light_the_phase() -> void:
	var body := _body(ComboPart.PARALLEL_CIRCUIT)
	var plate := (body.find_child("Platte", true, false) as MeshInstance3D).material_override as StandardMaterial3D
	var light := (body.find_child("Licht", true, false) as MeshInstance3D).material_override as StandardMaterial3D
	assert_eq(plate, ComboPartBody.plate_material(ComboPart.RARITY_LEGENDARY), "geteilt je Seltenheit")
	assert_eq(light.emission, ComboPart.parallel_circuit().tint())
	var korpus := (body.find_child("Korpus", true, false) as MeshInstance3D).material_override as StandardMaterial3D
	assert_true(korpus.vertex_color_use_as_albedo, "das Licht ist eingemalt")

func test_the_rarities_stay_apart_on_the_plate() -> void:
	var legendary := ComboPartBody.plate_material(ComboPart.RARITY_LEGENDARY).albedo_color
	var rare := ComboPartBody.plate_material(ComboPart.RARITY_RARE).albedo_color
	assert_gt(legendary.r, rare.r)
	assert_gt(rare.b, legendary.b)

func test_no_two_modules_share_an_outline_from_above() -> void:
	var seen := {}
	for part in _modules():
		var body := _body(part.id)
		var model := body.find_child("Model", false, false) as Node3D
		var box := _box_in_model(model, body.find_child("Korpus", true, false) as MeshInstance3D)
		var key := "%.2f|%.2f|%.2f|%.2f" % [box.position.x, box.end.x, box.position.z, box.end.z]
		assert_false(seen.has(key), "%s hat den Umriß von %s" % [part.id, seen.get(key, "")])
		seen[key] = part.id

func test_a_module_on_a_turned_chip_reads_upright() -> void:
	var chip := ComboChipView.new()
	add_child_autofree(chip)
	chip.rotation.y = -PI / 2.0
	chip.combo_key = DiceScoring.TWO_KIND
	chip.setup(10.0, 4.0)
	chip.set_sockets([ComboPart.cross_bridge(), null, null])
	var body := chip._sockets[0]["body"] as ComboPartBody
	assert_almost_eq(body.global_basis.z.z, 1.0, 0.001, "der Pfeil zeigt im Bild nach rechts")

# --- Zustand am Körper -----------------------------------------------------------------------

func test_the_counter_shows_its_value_as_digits() -> void:
	var body := _body(ComboPart.COUNTER)
	body.part.counter = 6
	body.set_state({})
	assert_eq(body.digits_text(), "007", "+1 Mult und sechs Wertungen")

func test_the_error_memory_lights_one_lamp_per_fumble() -> void:
	var body := _body(ComboPart.ERROR_MEMORY)
	body.set_state({})
	assert_eq(body.lit_state_parts(), 0)
	body.part.counter = 2
	body.set_state({})
	assert_eq(body.lit_state_parts(), 2)
	body.part.counter = 9
	body.set_state({})
	assert_eq(body.lit_state_parts(), ComboPartBody.ERROR_LAMPS, "mehr Lampen gibt es nicht")

func test_the_resonator_fills_its_ring_with_growth() -> void:
	var body := _body(ComboPart.RESONATOR)
	body.part.counter = 3
	body.set_state({})
	assert_eq(body.lit_state_parts(), 3)

func test_the_series_terminal_lights_one_clamp_per_module() -> void:
	var body := _body(ComboPart.SERIES_TERMINAL)
	body.set_state({"chip_parts": 2})
	assert_eq(body.lit_state_parts(), 2)

func test_the_series_terminal_counts_the_modules_of_its_chip() -> void:
	var chip := ComboChipView.new()
	add_child_autofree(chip)
	chip.combo_key = DiceScoring.TWO_KIND
	chip.setup(10.0, 4.0)
	chip.set_sockets([ComboPart.series_terminal(), ComboPart.capacitor(), ComboPart.resistor()])
	var body := chip._sockets[0]["body"] as ComboPartBody
	assert_eq(body.lit_state_parts(), 3)

func test_the_starter_glows_only_before_the_first_hand() -> void:
	var body := _body(ComboPart.STARTER)
	body.set_state({"first_hand": true})
	var on := body.light_energy()
	body.set_state({"first_hand": false})
	assert_gt(on, body.light_energy(), "danach dunkel")
	assert_almost_eq(body.light_energy(), ComboPartBody.DIM_ENERGY, 0.0001)

func test_the_afterburner_shows_its_flame_only_when_armed() -> void:
	var body := _body(ComboPart.AFTERBURNER)
	body.set_state({})
	assert_false(body.flame_shown())
	body.part.counter = 1
	body.set_state({})
	assert_true(body.flame_shown(), "scharf")

func test_the_coupling_shows_what_it_copies_as_a_pale_image() -> void:
	var body := _body(ComboPart.COUPLING)
	body.set_state({})
	var at := body.find_child("Abbild", true, false) as Node3D
	assert_not_null(at)
	assert_eq(at.get_child_count(), 0, "kopiert nichts: leer")
	body.set_state({"copy": ComboPart.capacitor()})
	assert_eq(body.copy_id(), ComboPart.CAPACITOR)
	var ghost := at.find_child("Kopie", true, false) as Node3D
	assert_not_null(ghost, "das Abbild steht")
	var mesh := ghost.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_lt((mesh.material_override as StandardMaterial3D).albedo_color.a, 0.5, "blaß")
	body.set_state({"copy": null})
	await wait_frames(1)
	assert_eq(at.get_child_count(), 0, "wieder leer")

# --- Punktreihe ------------------------------------------------------------------------------

func _lit_dots(body: ComboPartBody) -> Array[int]:
	var out: Array[int] = []
	for i in body.dot_count():
		if body.dot_lit(i):
			out.append(i)
	return out

func test_the_die_modules_show_one_dot_per_die_of_the_combination() -> void:
	var relay := _body(ComboPart.RELAY)
	relay.set_state({"dice": 5})
	assert_eq(relay.dot_count(), 5)
	assert_eq(_lit_dots(relay), [0] as Array[int], "das Relais meint den ersten")
	var stage := _body(ComboPart.OUTPUT_STAGE)
	stage.set_state({"dice": 4})
	assert_eq(_lit_dots(stage), [3] as Array[int], "die Endstufe den letzten")
	for id in [ComboPart.SERIES_RESISTOR, ComboPart.SOLDER_JOINT, ComboPart.PARALLEL_CIRCUIT]:
		var body := _body(id)
		body.set_state({"dice": 3})
		assert_eq(_lit_dots(body), [0, 1, 2] as Array[int], "%s: alle" % id)
	var shunt := _body(ComboPart.SHUNT)
	shunt.set_state({"dice": 2})
	assert_eq(shunt.dot_count(), ComboPartBody.DOT_MAX, "der Nebenschluss zeigt auch die übrigen")
	assert_eq(_lit_dots(shunt), [2, 3, 4, 5] as Array[int], "und meint die außerhalb")
	var plain := _body(ComboPart.CAPACITOR)
	plain.set_state({"dice": 5})
	assert_eq(plain.dot_count(), 0, "kein Würfel-Modul, keine Reihe")

func test_the_dots_lie_on_the_plate_below_the_part() -> void:
	var body := _body(ComboPart.SOLDER_JOINT)
	body.set_state({"dice": 6})
	var row := body.find_child("Punkte", false, false) as Node3D
	assert_not_null(row)
	for dot in row.get_children():
		var at := (dot as Node3D).position
		assert_lt(at.x + ComboPartBody.DOT_RADIUS, ComboPartBody.MODEL_SHIFT - ComboPartBody.HULL.x * 0.5,
			"unter dem Bauteil")
		assert_gt(at.x - ComboPartBody.DOT_RADIUS, -ComboPartBody.PLATE.x * 0.5 + ComboPartBody.PLATE_LIGHT_INSET,
			"über der Lichtleiste")
		assert_lt(absf(at.z) + ComboPartBody.DOT_RADIUS, ComboPartBody.PLATE.z * 0.5, "auf der Platte")

func test_the_firing_die_flashes_its_dot() -> void:
	var chip := ComboChipView.new()
	add_child_autofree(chip)
	chip.combo_key = DiceScoring.THREE_KIND
	chip.setup(10.0, 4.0)
	chip.set_sockets([ComboPart.solder_joint(), null, null])
	var body := chip._sockets[0]["body"] as ComboPartBody
	assert_eq(body.dot_count(), 3, "der Chip meldet seine Würfel")
	var rest := body.dot_energy(1)
	chip.flash_socket(0, 1.0, 1)
	await wait_frames(1)
	assert_gt(body.dot_energy(1), rest + 1.0, "der Punkt des Würfels blitzt")
	assert_lt(body.dot_energy(0), body.dot_energy(1), "die anderen nicht")

# --- Die PINS (Welle C) ----------------------------------------------------------------------

func _pin(part: ComboPart) -> ComboPartBody:
	var body := ComboPartBody.new()
	add_child_autofree(body)
	body.setup(part, true)
	return body

func test_every_module_has_its_own_pin_and_the_empty_socket_a_steel_pin() -> void:
	assert_eq(ComboPartBody.pin_path(null), ComboPartBody.PIN_EMPTY)
	assert_true(ResourceLoader.exists(ComboPartBody.PIN_EMPTY))
	for part in ComboPart.all():
		assert_eq(ComboPartBody.pin_path(part), ComboPartBody.PIN_MODEL % part.id, "%s: eigener Pin" % part.id)
		var pin := _pin(part)
		for node_name in ["Model", "Korpus", "Licht"]:
			assert_not_null(pin.find_child(node_name, true, false), "%s: %s" % [part.id, node_name])
		assert_null(pin.find_child("Platte", true, false), "%s: ein Pin steht ohne Platte" % part.id)

func test_every_pin_stays_within_its_hull() -> void:
	var parts: Array = ComboPart.all()
	parts.append(null)
	var hull := ComboPartBody.PIN_HULL
	for part in parts:
		var pin := _pin(part)
		var model := pin.find_child("Model", false, false) as Node3D
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			var box := _box_in_model(model, mesh)
			var id := "%s %s" % [part.id if part != null else "leer", mesh.name]
			assert_gte(box.position.z, -0.15, id + ": beginnt an der Gehäusekante")
			assert_lte(box.end.z, hull.x + 0.006, id + ": längs")
			assert_lte(absf(box.position.x), hull.y * 0.5 + 0.006, id + ": quer")
			assert_lte(absf(box.end.x), hull.y * 0.5 + 0.006, id + ": quer")
			assert_gte(box.position.y, -0.005, id + ": auf dem Tisch")
			assert_lte(box.end.y, hull.z + 0.006, id + ": Höhe")

func test_no_two_pins_share_outline_and_sign() -> void:
	var seen := {}
	for part in ComboPart.all():
		var pin := _pin(part)
		var model := pin.find_child("Model", false, false) as Node3D
		var key := ""
		for name in ["Korpus", "Licht"]:
			var mesh := pin.find_child(name, true, false) as MeshInstance3D
			var box := _box_in_model(model, mesh)
			var verts := 0
			for s in mesh.mesh.get_surface_count():
				verts += (mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			key += "%.2f|%.2f|%.2f|%.2f|%d;" % [box.position.x, box.end.x, box.position.z, box.end.z, verts]
		assert_false(seen.has(key), "%s gleicht %s" % [part.id, seen.get(key, "")])
		seen[key] = part.id

func test_the_counter_pin_carries_the_digits_smaller() -> void:
	var counter := ComboPart.counter_part()
	counter.counter = 6
	var pin := _pin(counter)
	pin.set_state({})
	assert_eq(pin.digits_text(), "007", "dieselben Ziffern wie am Modul")
	var label := pin.find_child("Ziffer", true, false) as Label3D
	assert_lt(label.pixel_size, ComboPartBody.DIGIT_PIXEL, "kleiner am Pin")

func test_the_pin_shows_the_state_where_it_fits() -> void:
	var memory := ComboPart.error_memory()
	memory.counter = 2
	var pin := _pin(memory)
	pin.set_state({})
	assert_eq(pin.lit_state_parts(), 2, "Fehlerspeicher: je Fumble eine Lampe")
	var terminal := _pin(ComboPart.series_terminal())
	terminal.set_state({"chip_parts": 3})
	assert_eq(terminal.lit_state_parts(), 3, "Reihenklemme: höchstens drei Schrauben")
	var burner := ComboPart.afterburner()
	var flame := _pin(burner)
	flame.set_state({})
	assert_false(flame.flame_shown())
	burner.counter = 1
	flame.set_state({})
	assert_true(flame.flame_shown(), "Nachbrenner: Flamme nur scharf")
	var resonator := ComboPart.resonator()
	resonator.counter = 3
	var ring := _pin(resonator)
	ring.set_state({})
	assert_eq(ring.lit_state_parts(), 3, "Schwingkreis: je Wachstum eine Windung")
	var starter := _pin(ComboPart.starter())
	starter.set_state({"first_hand": true})
	var on := starter.light_energy()
	starter.set_state({"first_hand": false})
	assert_lt(starter.light_energy(), on, "Anlasser: nur vor der ersten Hand hell")
	assert_eq(starter.dot_count(), 0, "die Punktreihe bleibt am Modul")
