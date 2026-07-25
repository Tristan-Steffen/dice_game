extends GutTest
## Energie-Ikosaeder (DiceShell): Facetten-Geometrie, Kollisionsplatten,
## Taumel-Würfel-Aufnahme, Facetten-Blitz und das Auskipp-Signal.

func _shell() -> DiceShell:
	var shell := DiceShell.new()
	add_child_autofree(shell)
	return shell

func test_huelle_hat_20_facetten_und_platten() -> void:
	var shell := _shell()
	var faces := 0
	for child in shell.shell_root.get_children():
		if child is MeshInstance3D:
			faces += 1
	assert_eq(faces, 20, "20 Dreiecks-Facetten")
	assert_eq(shell.shell_body.get_child_count(), 20, "20 Kollisionsplatten")
	assert_eq(shell.shell_body.collision_layer, DiceShell.GHOST_LAYER, "Platten auf dem privaten Layer")

func test_facetten_normalen_zeigen_nach_aussen() -> void:
	var shell := _shell()
	for i in shell.face_normals.size():
		var idx: Array = DiceShell.FACES[i]
		var centroid := (DiceShell.VERTS[idx[0]] + DiceShell.VERTS[idx[1]] + DiceShell.VERTS[idx[2]]) / 3.0
		assert_gt(shell.face_normals[i].dot(centroid.normalized()), 0.5, "Normale %d nach außen" % i)

func test_capture_die_baut_taumel_wuerfel_auf_privatem_layer() -> void:
	var shell := _shell()
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	shell.capture_die(def, shell.mouth_position())
	assert_true(shell.has_ghosts(), "Taumel-Würfel aufgenommen")
	var body: RigidBody3D = shell.ghosts[0].get_node("RigidBody3D")
	assert_false(body.freeze, "Taumel-Würfel ist ein aktiver Physik-Körper")
	assert_eq(body.collision_layer, DiceShell.GHOST_LAYER, "Layer privat")
	assert_eq(body.collision_mask, DiceShell.GHOST_LAYER, "Maske privat")
	assert_true(body.contact_monitor, "Aufprall-Meldungen für den Facetten-Blitz")
	shell.clear_ghosts()
	assert_false(shell.has_ghosts(), "clear_ghosts räumt ab")

func test_flash_face_setzt_impact_und_klingt_ab() -> void:
	var shell := _shell()
	shell.flash_face(3, 1.0)
	var material: ShaderMaterial = shell.face_materials[3]
	assert_eq(float(material.get_shader_parameter("impact")), 1.0, "Blitz auf voller Stärke")
	await wait_seconds(DiceShell.FLASH_DECAY + 0.1)
	assert_lt(float(material.get_shader_parameter("impact")), 0.05, "Blitz klingt ab")

func test_play_release_feuert_poured_out_und_rematerialisiert() -> void:
	var shell := _shell()
	var fired := []
	shell.poured_out.connect(func() -> void: fired.append(true))
	shell.play_release()
	await wait_seconds(DiceShell.RELEASE_BURST_TIME + 0.15)
	assert_eq(fired.size(), 1, "poured_out feuert genau einmal im Berst-Moment")
	await wait_seconds(DiceShell.RELEASE_RETURN_TIME + 0.15)
	var material: ShaderMaterial = shell.face_materials[0]
	assert_lt(float(material.get_shader_parameter("dissolve")), 0.05, "Hülle rematerialisiert")
	assert_false(shell.releasing, "Auskippen abgeschlossen")
	await wait_seconds(0.1)
	assert_eq(shell.state, DiceShell.State.HOME, "Hülle wieder am Heimat-Platz")

func test_play_shuffle_reist_zur_grube_und_ruettelt() -> void:
	var shell := _shell()
	shell.play_shuffle()
	await wait_seconds(DiceShell.TRAVEL_TIME + 0.1)
	assert_eq(shell.state, DiceShell.State.SHAKE, "nach der Reise wird gerüttelt")
	var pit_target := Vector3(DicePit.PIT_CENTER.x, DiceShell.SHAKE_HEIGHT,
		DicePit.PIT_CENTER.z + DiceShell.SHAKE_OFFSET_Z)
	# Toleranz = maximaler Schlagausschlag: die Hülle schüttelt ab der Ankunft.
	var reach := DiceShell.SHAKE_STROKE.length() + DiceShell.SHAKE_ARC.length() + 0.1
	assert_lt(shell.mouth_position().distance_to(pit_target), reach, "Rüttel-Anker rechts über der Grube")
	await wait_seconds(DiceShell.SHUFFLE_MIN_TIME + 0.1)
	assert_eq(shell.state, DiceShell.State.POISED, "ungepackt kippt der Timer aus")

func test_drag_to_klemmt_auf_den_grubeninnenraum() -> void:
	var shell := _shell()
	shell.drag_to(Vector3(50.0, 0.0, -50.0))  # weit außerhalb der Grube
	assert_true(shell.has_drag_point, "Zieh-Ziel gesetzt")
	var world := shell.to_global(shell.drag_point)
	assert_lte(absf(world.x - DicePit.PIT_CENTER.x), DicePit.PIT_HALF_X - DiceShell.SHAKE_MARGIN + 0.01)
	assert_lte(absf(world.z - DicePit.PIT_CENTER.z), DicePit.PIT_HALF_Z - DiceShell.SHAKE_MARGIN + 0.01)
	assert_almost_eq(world.y, DiceShell.SHAKE_HEIGHT, 0.01, "Zieh-Ziel liegt auf der Rüttel-Ebene")
	shell.set_grabbed(true)
	shell.set_grabbed(false)
	assert_false(shell.has_drag_point, "Loslassen verwirft das Zieh-Ziel")

func test_packen_haelt_das_ruetteln_loslassen_kippt_aus() -> void:
	var shell := _shell()
	shell.state = DiceShell.State.SHAKE
	shell.shuffle_time_left = 0.2
	shell.set_grabbed(true)
	await wait_seconds(0.4)  # länger als der Rest-Timer
	assert_eq(shell.state, DiceShell.State.SHAKE, "gepackt läuft der Timer nicht ab")
	shell.set_grabbed(false)
	await wait_frames(3)
	assert_eq(shell.state, DiceShell.State.POISED, "Loslassen kippt sofort aus")

func test_spin_impulse_dreht_die_huelle() -> void:
	var shell := _shell()
	shell.spin_impulse(Vector2(40, 0), null)
	assert_gt(shell.angular_velocity.length(), 0.0, "Impuls dreht die Hülle")

func test_reset_to_post_holt_die_huelle_heim() -> void:
	var shell := _shell()
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	shell.capture_die(def, shell.mouth_position())
	shell.state = DiceShell.State.SHAKE
	shell.grabbed = true
	shell.reset_to_post()
	assert_false(shell.has_ghosts(), "Taumel-Würfel abgeräumt")
	assert_false(shell.grabbed, "Griff gelöst")
	assert_eq(shell.state, DiceShell.State.RETURN, "Hülle kehrt heim")

func test_ziehen_hebt_und_senkt_die_huelle() -> void:
	# Der Zieh-Rückstand ist die Federkraft: reißt der Spieler, sackt die Hülle
	# unter die Rüttel-Ebene; bleibt er stehen, wirft die Feder sie darüber.
	var shell := _shell()
	shell.state = DiceShell.State.SHAKE
	shell.shake_pos = shell._pit_anchor()
	shell.set_grabbed(true)
	shell.drag_to(Vector3(DicePit.PIT_CENTER.x, 0.0, DicePit.PIT_CENTER.z + 8.0))
	await wait_frames(3)
	assert_lt(shell.lift, -0.05, "Reißen lässt die Hülle durchsacken")
	var sagged: float = shell.lift
	shell.drag_to(shell.to_global(shell.shake_pos))  # Hand steht still
	await wait_seconds(0.25)
	assert_gt(shell.lift, sagged, "die Feder holt sie zurück und darüber hinaus")
	assert_lte(absf(shell.lift), DiceShell.LIFT_MAX + 0.01, "Federweg bleibt begrenzt")

func test_ziehen_kippt_die_huelle_quer_zur_zugrichtung() -> void:
	var shell := _shell()
	shell.state = DiceShell.State.SHAKE
	shell.shake_pos = shell._pit_anchor()
	shell.set_grabbed(true)
	shell.drag_to(Vector3(DicePit.PIT_CENTER.x, 0.0, DicePit.PIT_CENTER.z + 9.0))
	await wait_frames(12)
	# Zug nach +Z -> Kippachse waagerecht quer dazu, nicht die reine Hochachse.
	var axis: Vector3 = shell.angular_velocity.normalized()
	assert_gt(absf(axis.x), absf(axis.y), "Hülle kippt, statt nur zu kreiseln")

func test_ruck_treibt_die_taumel_wuerfel_an() -> void:
	# Jede Schlagumkehr wirft den Schwarm hoch und gibt ihm Drall - deshalb wird
	# hier wirklich hin und her gezogen, nicht nur einmal gerissen.
	var shell := _shell()
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	shell.state = DiceShell.State.SHAKE
	shell.shake_pos = shell._pit_anchor()
	shell.capture_die(def, shell.mouth_position())
	var body: RigidBody3D = shell.ghosts[0].get_node("RigidBody3D")
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	shell.set_grabbed(true)
	for stroke in 4:
		var side := 6.0 if stroke % 2 == 0 else -6.0
		shell.drag_to(Vector3(DicePit.PIT_CENTER.x, 0.0, DicePit.PIT_CENTER.z + side))
		await wait_seconds(0.2)
	assert_gt(body.angular_velocity.length(), 0.0, "der Schwarm bekommt Drall ab")

func test_platten_federn_haerter_als_grubenwaende() -> void:
	var shell := _shell()
	var material: PhysicsMaterial = shell.shell_body.physics_material_override
	assert_not_null(material, "Platten haben ein Physikmaterial")
	assert_gt(material.bounce, DieBuilder.BOUNCE, "Hülle federt härter als die Grube")
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	shell.capture_die(def, shell.mouth_position())
	var body: RigidBody3D = shell.ghosts[0].get_node("RigidBody3D")
	assert_gt(body.physics_material_override.bounce, DieBuilder.BOUNCE,
		"auch der Taumel-Würfel selbst federt - beide Seiten geben Energie zurück")

func test_kaefig_wirft_zurueck_statt_zu_schlucken() -> void:
	# In den Ikosaeder-Ecken fängt der Käfig den Würfel vor der Platte ab - dort
	# muss er federn, sonst frisst er genau die Sprünge weg.
	var shell := _shell()
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	shell.capture_die(def, shell.mouth_position())
	var body: RigidBody3D = shell.ghosts[0].get_node("RigidBody3D")
	var out := Vector3.RIGHT
	body.global_position = shell.mouth_position() + out * (DiceShell.NET_RADIUS + 0.3)
	body.linear_velocity = out * 10.0
	await wait_frames(2)
	assert_lt(body.linear_velocity.dot(out), 0.0, "Käfig kehrt die Auswärtsbewegung um")
	assert_lte(body.global_position.distance_to(shell.mouth_position()),
		DiceShell.NET_RADIUS + 0.5, "Würfel bleibt in der Hülle")
