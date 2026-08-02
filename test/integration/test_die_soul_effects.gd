extends GutTest
## Animationsstufen der Seele nach Rarität: der Kantenrahmen ist das
## Röhrensystem, in dem das flüssige Licht der Seele zirkuliert, und die
## Rarität ist seine Erregung - still (häufig), Strömung (selten), Schübe
## (episch), Sieden + Seelenfunken als übertretende Tropfen (legendär).
## Signale sitzen auf ECHTER GEOMETRIE (die additive Fresnel-Hülle las sich
## als abgelöste Seite - gestrichen), und die Bewegung ankert um die
## kalibrierte Rahmenhelligkeit (die_edge_flow). Das Urteil über das Aussehen
## fällt der Playtest, hier steht die Staffelung.

func _display() -> DieFaceDisplay:
	var die: Node3D = autofree(DieBuilder.build())
	return die.get_node("RigidBody3D/Faces")

func _def(essence_id := "") -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [1, 2, 3, 4, 5, 6]
	def.faces = faces
	def.essence_id = essence_id
	return def

func _flow(display: DieFaceDisplay) -> float:
	return display.beam_material.get_shader_parameter("flow_style")

# --- Die Treppe: je Rarität eine Erregung -------------------------------------

func test_the_flow_style_climbs_with_the_rarity() -> void:
	var expected := {
		"": 0.0, Essence.NEON: 0.0,           # seelenlos/häufig: still
		Essence.ST_ELMOS_FIRE: 1.0,           # selten: Strömung
		Essence.SOLAR_WIND: 2.0,              # episch: Schübe
		Essence.QUINTESSENCE: 3.0,            # legendär: Sieden
	}
	for id: String in expected:
		var display := _display()
		display.apply_definition(_def(id))
		assert_eq(_flow(display), expected[id], "Erregung von '%s'" % id)

func test_only_a_legendary_soul_boils_over_into_motes() -> void:
	for id: String in ["", Essence.NEON, Essence.ST_ELMOS_FIRE, Essence.SOLAR_WIND]:
		var display := _display()
		display.apply_definition(_def(id))
		assert_null(display.soul_motes, "'%s' tritt nicht über" % id)
	var legendary := _display()
	legendary.apply_definition(_def(Essence.QUINTESSENCE))
	assert_not_null(legendary.soul_motes, "legendär kocht über")

func test_the_flow_carries_the_void_floor_for_a_near_black_soul() -> void:
	# Vakuum glüht fast schwarz - Ballungen in Fast-Schwarz wären unsichtbar,
	# also trägt der Fluss den Void-Ton; die STATISCHE Röhre bleibt dunkel.
	var display := _display()
	display.apply_definition(_def(Essence.VACUUM))
	var flow: Vector3 = display.beam_material.get_shader_parameter("flow_color")
	assert_gte(Color(flow.x, flow.y, flow.z).get_luminance(),
		DieFaceDisplay.SOUL_MOTION_MIN_LUMA, "der Void-Boden trägt die Bewegung")
	assert_lt(DieFaceDisplay.intense(display.edge_base).get_luminance(),
		DieFaceDisplay.SOUL_MOTION_MIN_LUMA, "die statische Identität bleibt dunkel")

# --- Rahmen-Farbe und Stations-Auswahl ----------------------------------------

func test_beams_and_caps_carry_the_colour_of_the_frame() -> void:
	# Balken wie Kappen zeigen exakt die Emission, die der Füllkörper trägt -
	# der Rahmen ist EINE Lampe, auf drei Materialien verteilt.
	for id: String in ["", Essence.SOLAR_WIND]:
		var display := _display()
		display.apply_definition(_def(id))
		var edge := display.edge_material_res.emission
		for material: ShaderMaterial in [display.beam_material, display.cap_material]:
			var lamp: Vector3 = material.get_shader_parameter("lamp_color")
			assert_almost_eq(lamp.x, edge.r, 0.001, "dieselbe Farbe wie der Rahmen ('%s')" % id)
			assert_almost_eq(lamp.y, edge.g, 0.001)

func test_the_station_selection_covers_beams_and_caps() -> void:
	# set_edge_tint färbt den GANZEN Rahmen flach - Balken und Kappen hängen an
	# eigenen Shadern und dürfen nicht in Seelenfarbe weiterglühen.
	var display := _display()
	display.apply_definition(_def(Essence.SOLAR_WIND))
	display.set_edge_tint(DieFaceDisplay.SELECT_NUMBER_COLOR)
	for material: ShaderMaterial in [display.beam_material, display.cap_material]:
		var tint: Vector4 = material.get_shader_parameter("flat_tint")
		assert_gt(tint.w, 0.0, "Auswahl-Modus aktiv")
		assert_almost_eq(tint.x, DieFaceDisplay.SELECT_NUMBER_COLOR.r, 0.001)
	display.set_tint(Color.WHITE)
	for material: ShaderMaterial in [display.beam_material, display.cap_material]:
		assert_eq((material.get_shader_parameter("flat_tint") as Vector4).w, 0.0,
			"set_tint stellt den Rahmen wieder her")

# --- Legendär: Seelenfunken ---------------------------------------------------

func test_a_legendary_soul_lights_the_motes() -> void:
	var display := _display()
	display.apply_definition(_def(Essence.QUINTESSENCE))
	assert_not_null(display.soul_motes, "Funken steigen auf")
	assert_eq(display.soul_motes.amount, DieFaceDisplay.MOTE_COUNT)
	assert_eq(display.soul_motes.cast_shadow,
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Funken werfen nichts")
	assert_false(display.soul_motes.local_coords, "sie ziehen dem Wurf nach")

func test_the_motes_leave_the_edge_frame_not_the_die_centre() -> void:
	# Der Rahmen trägt das Seelenglühen; die Würfelmitte ist dunkles Glas.
	var display := _display()
	display.apply_definition(_def(Essence.QUINTESSENCE))
	assert_eq(display.soul_motes.emission_shape, CPUParticles3D.EMISSION_SHAPE_POINTS)
	var points := display.soul_motes.emission_points
	assert_eq(points.size(), 12 * DieFaceDisplay.MOTE_EDGE_SAMPLES, "12 Kanten abgetastet")
	for point: Vector3 in points:
		# Auf einer Würfelkante liegen GENAU zwei Achsen am Anschlag, die dritte
		# läuft - ein Punkt aus dem Inneren verletzt das.
		var pinned := 0
		for axis in 3:
			if is_equal_approx(absf(point[axis]), 1.0):
				pinned += 1
		assert_gte(pinned, 2, "%s liegt auf einer Kante" % point)

func test_the_motes_inherit_the_mirror_bit_of_their_siblings() -> void:
	var display := _display()
	display.apply_definition(_def(Essence.QUINTESSENCE))
	var sibling: VisualInstance3D = display.quads.values()[0]
	assert_eq(display.soul_motes.layers, sibling.layers, "Spiegel-Bit geerbt")

func test_a_downgraded_die_loses_its_motes_and_its_flow() -> void:
	# become: derselbe Anzeige-Knoten bekommt einen anderen Würfel.
	var display := _display()
	display.apply_definition(_def(Essence.QUINTESSENCE))
	assert_not_null(display.soul_motes)
	display.apply_definition(_def(Essence.NEON))
	assert_null(display.soul_motes, "häufig lässt nichts zurück")
	assert_eq(_flow(display), 0.0, "und die Röhre steht still")

# --- Takt ---------------------------------------------------------------------

func test_flow_and_lamps_run_on_the_dies_own_phase() -> void:
	# 30 Tray-Würfel fließen nie im Gleichschritt.
	var display := _display()
	display.apply_definition(_def(Essence.SOLAR_WIND))
	for material: ShaderMaterial in [display.beam_material, display.cap_material]:
		assert_eq(material.get_shader_parameter("phase"), display._pulse_phase)

func test_the_floor_pool_carries_no_rarity_signal() -> void:
	# Die Lache ist der Grube vorbehalten (test_die_face_display) - eine ganze
	# Stufe dort abzulegen hieße, sie in Schale, Becher und Inspektor zu verlieren.
	var display := _display()
	display.apply_definition(_def(Essence.SOLAR_WIND))
	for owned: String in ["ray_color", "flow_style", "gas"]:
		assert_null(display.pool_material.get_shader_parameter(owned),
			"die Lache kennt %s nicht" % owned)
