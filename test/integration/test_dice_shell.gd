extends GutTest
## Der Würfel-Wirbel (DiceShell): völlig unsichtbar - nur der Schwarm selbst
## zeichnet -, jeder Taumel-Würfel auf seiner eigenen Bahn, der Griff nur am
## vollen Schwarm und das Auskipp-Signal mit den Berst-Ständen.

func _shell() -> DiceShell:
	var shell := DiceShell.new()
	add_child_autofree(shell)
	return shell

func test_der_wirbel_ist_voellig_unsichtbar() -> void:
	# Der Spieler mischt "in der Luft": kein Facetten-Mesh, kein Projektor,
	# keine Platten, kein Lichtring - nur der Schwarm selbst zeichnet.
	var shell := _shell()
	var meshes: Array[String] = []
	for child in shell.get_children():
		if child is MeshInstance3D:
			meshes.append(String(child.name))
	for child in shell.shell_root.get_children():
		if child is MeshInstance3D:
			meshes.append(String(child.name))
	assert_eq(meshes, [] as Array[String], "nichts am Wirbel zeichnet")
	assert_null(shell.get_node_or_null("ProjectorPuck"), "kein Projektor-Fuß")
	assert_null(shell.shell_root.get_node_or_null("Plates"), "keine Platten mehr")
	assert_null(shell.shell_root.get_node_or_null("OrbitRing"), "kein Ring mehr")

func test_heimat_platz_ist_der_ruettel_anker_ueber_der_grube() -> void:
	# Ohne Sockel wartet die unsichtbare Hülle dort, wo gemischt wird - die
	# gezogenen Würfel sammeln sich direkt über der Grube.
	var shell := _shell()
	assert_lt(shell.shell_root.position.distance_to(shell._pit_anchor()), 0.001,
		"Heimat = Rüttel-Anker")

func test_capture_die_baut_taumel_wuerfel_auf_privatem_layer() -> void:
	var shell := _shell()
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	shell.capture_die(def, shell.mouth_position())
	assert_true(shell.has_ghosts(), "Taumel-Würfel aufgenommen")
	var body: RigidBody3D = shell.ghosts[0].get_node("RigidBody3D")
	assert_false(body.freeze, "Taumel-Würfel ist ein aktiver Physik-Körper")
	assert_eq(body.collision_layer, 0, "kollisionsfrei - Rempler wären Rauschen")
	assert_eq(body.collision_mask, 0, "und nichts in der Grube geht den Wirbel an")
	assert_eq(body.gravity_scale, 0.0, "die Bahn trägt - keine Schwerkraft im Wirbel")
	shell.clear_ghosts()
	assert_false(shell.has_ghosts(), "clear_ghosts räumt ab")

func test_die_choreographie_ist_deterministisch() -> void:
	# Kein Würfel würfelt beim Mischen: zwei getrennte Wirbel bauen für dieselben
	# Plätze exakt dieselben Bahnen, denselben Drall und dieselbe Bahnebene.
	var a := _shell()
	var b := _shell()
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	for i in 3:
		a.capture_die(def, a.mouth_position())
		b.capture_die(def, b.mouth_position())
	for i in 3:
		assert_eq(a._orbits[i], b._orbits[i], "Bahn %d ist Choreographie" % i)
		var body_a: RigidBody3D = a.ghosts[i].get_node("RigidBody3D")
		var body_b: RigidBody3D = b.ghosts[i].get_node("RigidBody3D")
		assert_lt(body_a.angular_velocity.distance_to(body_b.angular_velocity),
			0.0001, "Drall %d ist fest, kein Zufall" % i)
	assert_eq(a.shell_root.basis, Basis.IDENTITY,
		"jeder Schwarm beginnt auf derselben Bahnebene")

func test_der_griff_lebt_nur_am_vollen_schwarm() -> void:
	# Sichtbar heißt bedienbar: ohne taumelnde Würfel ist nichts zu sehen, also
	# auch nichts zu packen - geworfen wird am Würfeln-Knopf.
	var shell := _shell()
	assert_eq(shell._click_zone.collision_layer, 0, "leer: Griff tot")
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	shell.capture_die(def, shell.mouth_position())
	assert_eq(shell._click_zone.collision_layer, DiceShell.CLICK_LAYER,
		"mit Würfeln: Griff scharf")
	shell.clear_ghosts()
	assert_eq(shell._click_zone.collision_layer, 0, "abgeräumt: Griff wieder tot")

func test_play_release_feuert_poured_out_und_rematerialisiert() -> void:
	var shell := _shell()
	var fired := []
	shell.poured_out.connect(func() -> void: fired.append(true))
	shell.play_release()
	await wait_seconds(DiceShell.RELEASE_BURST_TIME + 0.15)
	assert_eq(fired.size(), 1, "poured_out feuert genau einmal im Berst-Moment")
	await wait_seconds(DiceShell.RELEASE_RETURN_TIME + 0.15)
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

func test_jeder_wuerfel_kreist_auf_seiner_eigenen_bahn() -> void:
	# Drei Würfel, drei Bahnen: gestaffelte Radien und Tempi (Goldener Schnitt),
	# und nach einer Sekunde Führung liegt jeder im Bahn-Band seines Kessels.
	var shell := _shell()
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	for i in 3:
		shell.capture_die(def, shell.mouth_position())
	assert_ne(shell._orbits[0]["radius"], shell._orbits[1]["radius"], "eigene Radien")
	assert_ne(shell._orbits[0]["speed"], shell._orbits[1]["speed"], "eigene Tempi")
	await wait_seconds(1.2)
	for i in 3:
		var body: RigidBody3D = shell.ghosts[i].get_node("RigidBody3D")
		var dist := body.global_position.distance_to(shell.mouth_position())
		assert_between(dist, DiceShell.ORBIT_RADIUS_MIN - 0.7,
			DiceShell.ORBIT_RADIUS_MAX + 0.8, "Würfel %d kreist im Bahn-Band" % i)

func test_die_bahn_holt_einen_ausreisser_zurueck() -> void:
	# Die Feder auf den Bahn-Anker ersetzt Käfig und Platten: ein weit
	# hinausgeworfener Würfel wird sichtbar zurückgeholt.
	var shell := _shell()
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	shell.capture_die(def, shell.mouth_position())
	var body: RigidBody3D = shell.ghosts[0].get_node("RigidBody3D")
	body.global_position = shell.mouth_position() + Vector3.RIGHT * 8.0
	body.linear_velocity = Vector3.RIGHT * 10.0
	var start := body.global_position.distance_to(shell.mouth_position())
	await wait_seconds(0.6)
	assert_lt(body.global_position.distance_to(shell.mouth_position()), start,
		"die Bahnführung zieht ihn zurück")

func test_release_states_liefern_die_berst_staende_samt_bewegung() -> void:
	# Die echten Wurf-Würfel ÜBERNEHMEN Ort, Lage und Bewegung des Berst-
	# Moments: nichts friert ein, die Bahnführung reißt ab und die Tangente
	# fliegt den Berst-Augenblick frei weiter.
	var shell := _shell()
	var def := DieDefinition.new()
	def.faces = [1, 2, 3, 4, 5, 6]
	for i in 2:
		shell.capture_die(def, shell.mouth_position())
	await wait_seconds(0.8)
	shell.play_release()
	var states := shell.release_states()
	assert_eq(states.size(), 2, "je Taumel-Würfel ein Berst-Stand")
	for i in 2:
		var body: RigidBody3D = shell.ghosts[i].get_node("RigidBody3D")
		assert_false(body.freeze, "kein Einfrieren - die Bewegung lebt weiter")
		var pos: Vector3 = states[i]["position"]
		var vel: Vector3 = states[i]["velocity"]
		assert_lt(pos.distance_to(body.global_position), 0.001,
			"Stand %d ist die echte Bahn-Position" % i)
		assert_lt(vel.distance_to(body.linear_velocity), 0.001,
			"Tempo %d ist das echte Bahn-Tempo" % i)
	# Bahn-Abriss: während des Berst-Moments zieht keine Feder mehr zur Bahn.
	var v0: Vector3 = states[0]["velocity"]
	await wait_seconds(DiceShell.RELEASE_BURST_TIME * 0.6)
	var body0: RigidBody3D = shell.ghosts[0].get_node("RigidBody3D")
	assert_lt(body0.linear_velocity.distance_to(v0), 0.5,
		"die Tangente fliegt unverändert weiter (keine Bahnführung mehr)")
