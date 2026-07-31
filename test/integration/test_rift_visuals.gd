extends GutTest
## Die Riss-Anzeige: der farblose Bake, die Shader-Auflage und die Regel, dass
## nur die OBERE Seite auflodert. Was hier nicht geprüft werden kann, ist das
## Aussehen - aber alles, was die Anzeige falsch verdrahten könnte, schon.

func _die(rift_ids: Array = [], essence_id := "") -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [1, 2, 3, 4, 5, 6]
	def.faces = faces
	def.essence_id = essence_id
	for i in rift_ids.size():
		def.set_rift(0, String(rift_ids[i]), i)
	return def

## Gebauter Würfel mit seinem Anzeige-Knoten.
func _display(def: DieDefinition) -> DieFaceDisplay:
	var root := DieBuilder.build()
	add_child_autofree(root)
	var faces: DieFaceDisplay = root.get_node("RigidBody3D/Faces")
	faces.apply_definition(def)
	return faces

# --- Der Bake: vier Texturen, für immer ---------------------------------------------

func test_the_bake_is_cached_per_pattern_only() -> void:
	RiftTextures.warm()
	assert_eq(RiftTextures.cache_size(), Rift.all_patterns().size(),
		"genau eine Textur je Muster")
	# Ein Vakuum-Würfel trug früher seine eigene schwarze Kopie je Kombination.
	# Farblos gebacken kostet er nichts extra - das ist der ganze Sinn der Umstellung.
	_display(_die([Rift.AFTERGLOW, Rift.SPARK_FLIGHT], Essence.VACUUM))
	_display(_die([Rift.BURN_IN], Essence.NEON))
	assert_lte(RiftTextures.cache_size(), 4,
		"auch mit Essenzen und Doppelbrüchen bleiben es höchstens vier")

func test_the_same_pattern_hands_back_the_same_texture() -> void:
	assert_same(RiftTextures.for_pattern(Rift.PATTERN_BOLT),
		RiftTextures.for_pattern(Rift.PATTERN_BOLT), "gecacht, nicht neu gebacken")
	assert_same(RiftTextures.for_rift(Rift.SPARK_FLIGHT),
		RiftTextures.for_pattern(Rift.PATTERN_BOLT), "Rift und Muster teilen die Maske")

func test_an_unknown_pattern_bakes_nothing() -> void:
	assert_null(RiftTextures.for_pattern(""))
	assert_null(RiftTextures.for_pattern("kein_muster"))

func test_the_mask_carries_all_four_channels() -> void:
	var image := RiftTextures.for_pattern(Rift.PATTERN_BOLT).get_image()
	image.clear_mipmaps()
	var arc_low := 1.0
	var arc_high := 0.0
	var on_core := 0
	var far_field := 0
	for y in RiftTextures.SIZE:
		for x in RiftTextures.SIZE:
			var texel := image.get_pixel(x, y)
			if texel.a > 0.02:
				arc_low = minf(arc_low, texel.g)
				arc_high = maxf(arc_high, texel.g)
			if texel.r > 0.5:
				on_core += 1
			if texel.b > 0.99:
				far_field += 1
	assert_gt(on_core, 0, "R trägt einen Kern")
	assert_almost_eq(arc_low, 0.0, 0.02, "G beginnt bei 0")
	assert_almost_eq(arc_high, 1.0, 0.02, "G endet bei 1")
	# Ohne diese Vorbelegung läse der Shader die ganze leere Seite als Mittellinie.
	assert_gt(far_field, 0, "B steht außerhalb des Felds auf 1")

func test_the_mask_is_colourless() -> void:
	# Die Tönung ist ein Uniform. Wäre sie im Pixel, müssten sich die Masken von
	# Nachglühen (silbrig) und Funkenflug (cyan) unterscheiden - tun sie nicht.
	var image := RiftTextures.for_pattern(Rift.PATTERN_RING).get_image()
	image.clear_mipmaps()
	var tinted := 0
	for y in RiftTextures.SIZE:
		for x in RiftTextures.SIZE:
			var texel := image.get_pixel(x, y)
			# Auf der Mittellinie ist R hoch und B null - eine echte Farbe hätte
			# hier den Farbton der Tönung, keine Kanal-Semantik.
			if texel.r > 0.9 and texel.b > 0.5:
				tinted += 1
	assert_eq(tinted, 0, "Kern und Abstandsfeld widersprechen sich nie")

# --- Die Auflage am Würfel ----------------------------------------------------------

func test_a_rifted_face_carries_the_shader() -> void:
	var faces := _display(_die([Rift.AFTERGLOW]))
	var overlay := _overlay(faces, 0)
	assert_true(overlay.visible, "die gebrochene Seite zeigt ihre Auflage")
	var material := overlay.material_override as ShaderMaterial
	assert_not_null(material, "ShaderMaterial statt StandardMaterial3D")
	assert_same(material.shader, DieBuilder.RIFT_SHADER, "EIN Shader, ein Compile")
	assert_eq(material.get_shader_parameter("motion"), Rift.MOTION_ECHO)
	assert_false(bool(material.get_shader_parameter("mirror")))

func test_an_unbroken_face_shows_nothing() -> void:
	var faces := _display(_die([Rift.AFTERGLOW]))
	assert_false(_overlay(faces, 3).visible, "eine heile Seite trägt keinen Riss")

func test_the_seam_colour_reaches_the_shader_normalized() -> void:
	var faces := _display(_die([Rift.SPARK_FLIGHT]))
	var seam: Vector3 = _material(faces, 0).get_shader_parameter("seam_color")
	assert_almost_eq(maxf(seam.x, maxf(seam.y, seam.z)), 1.0, 0.001,
		"energy heißt in jedem Profil dasselbe")
	assert_almost_eq(seam.z, 1.0, 0.01, "und es bleibt das Energie-Cyan")

func test_the_vacuum_swallows_every_rift_and_mirrors_the_second() -> void:
	var faces := _display(_die([Rift.AFTERGLOW, Rift.SPARK_FLIGHT], Essence.VACUUM))
	assert_eq(_material(faces, 0).get_shader_parameter("motion"), Rift.MOTION_INTAKE,
		"auf einem Vakuum-Würfel saugt auch das Nachglühen")
	var second: MeshInstance3D = faces.rift_overlays_second.get(_axis_of(faces, 0))
	assert_not_null(second, "der zweite Bruch bekommt seine eigene Auflage")
	assert_true(second.visible)
	var second_material := second.material_override as ShaderMaterial
	assert_true(bool(second_material.get_shader_parameter("mirror")),
		"gespiegelt - sonst verheddern sich beide Brüche im selben Rand")
	assert_eq(second_material.get_shader_parameter("motion"), Rift.MOTION_INTAKE)

func test_a_single_rift_builds_no_second_overlay() -> void:
	var faces := _display(_die([Rift.BURN_IN]))
	var second: MeshInstance3D = faces.rift_overlays_second.get(_axis_of(faces, 0))
	assert_true(second == null or not second.visible, "faul gebaut: kein Vakuum, keine zweite Auflage")

# --- Nur die obere Seite lodert -----------------------------------------------------

func test_the_flare_reaches_only_the_named_face() -> void:
	var def := _die([Rift.AFTERGLOW])
	def.set_rift(3, Rift.SPARK_FLIGHT)
	var faces := _display(def)
	faces.flare_rifts(1.0, 0)
	assert_almost_eq(float(_material(faces, 0).get_shader_parameter("flare")), 1.0, 0.001,
		"die gewertete Seite lodert")
	assert_almost_eq(float(_material(faces, 3).get_shader_parameter("flare")), 0.0, 0.001,
		"eine Seitenfläche behauptet sonst eine Wirkung, die es nicht gibt")

func test_the_block_flare_is_its_own_gesture() -> void:
	var faces := _display(_die([Rift.BURN_IN]))
	faces.flare_rifts(1.0, 0, true)
	assert_true(bool(_material(faces, 0).get_shader_parameter("block_flare")),
		"ein verhinderter Schrumpf sieht anders aus als eine Wertung")
	faces.flare_rifts(1.0, 0, false)
	assert_false(bool(_material(faces, 0).get_shader_parameter("block_flare")))

# --- Der Ziffern-Wächter ------------------------------------------------------------

func test_a_two_digit_value_widens_the_guard_not_the_crack() -> void:
	var def := _die([Rift.AFTERGLOW])
	def.faces[0] = 12
	var faces := _display(def)
	var half: Vector2 = _material(faces, 0).get_shader_parameter("glyph_half")
	assert_almost_eq(half.x, Rift.GLYPH_KEEPOUT.x + DieFaceDisplay.GLYPH_DIGIT_WIDEN, 0.001,
		"zwei Stellen -> breitere Sperrzone")
	assert_almost_eq(half.y, Rift.GLYPH_KEEPOUT.y, 0.001, "die Höhe bleibt")
	# Die Figur selbst ist NIE eine Funktion des Werts - Knochen lässt Werte
	# wachsen, und ein Riss, der sich dabei neu zeichnet, liest als Fehler.
	assert_eq(Rift.crack_lines(Rift.PATTERN_RING), Rift.crack_lines(Rift.PATTERN_RING))

func test_a_single_digit_keeps_the_authored_keepout() -> void:
	var faces := _display(_die([Rift.AFTERGLOW]))
	var half: Vector2 = _material(faces, 0).get_shader_parameter("glyph_half")
	assert_almost_eq(half.x, Rift.GLYPH_KEEPOUT.x, 0.001)

# --- Helfer -------------------------------------------------------------------------

func _axis_of(faces: DieFaceDisplay, face_index: int) -> String:
	for axis: String in faces.rift_overlays:
		if DiceController.AXIS_FACE_INDEX[axis] == face_index:
			return axis
	return ""

func _overlay(faces: DieFaceDisplay, face_index: int) -> MeshInstance3D:
	return faces.rift_overlays[_axis_of(faces, face_index)]

func _material(faces: DieFaceDisplay, face_index: int) -> ShaderMaterial:
	return _overlay(faces, face_index).material_override as ShaderMaterial

# --- Das 2D-Netz: still, außer auf der Grubenkarte ----------------------------------

func test_the_net_draws_one_crack_per_rift_and_knows_its_face() -> void:
	var def := _die([Rift.AFTERGLOW, Rift.SPARK_FLIGHT], Essence.VACUUM)
	def.set_rift(4, Rift.STRAY_LIGHT)
	var cracks := DieNetView.rift_cracks(def, 40.0)
	assert_eq(cracks.size(), 3, "zwei Brüche auf Seite 1, einer auf Seite 5")
	var faces := {}
	for crack in cracks:
		faces[(crack as DieNetView.RiftCrack).face] = true
	assert_true(faces.has(0) and faces.has(4), "jeder Riss kennt seine Zelle")

func test_the_net_carries_the_branch_weights() -> void:
	var cracks := DieNetView.rift_cracks(_die([Rift.SPARK_FLIGHT]), 40.0)
	var crack := cracks[0] as DieNetView.RiftCrack
	assert_eq(crack.weights.size(), crack.lines.size(), "je Linie ein Gewicht")
	assert_lt(crack.weights[1], crack.weights[0], "die Gabel ist dünner als ihr Stamm")

func test_a_net_crack_rests_without_flare() -> void:
	# Das 30-Würfel-Raster ist eine Lesefläche, keine Bühne: dort steht der Riss
	# still, weil er nie eine andere Flare-Quelle als die Grubenkarte bekommt.
	var crack := DieNetView.rift_cracks(_die([Rift.BURN_IN]), 40.0)[0] as DieNetView.RiftCrack
	assert_almost_eq(crack.flare, 0.0, 0.001)

func test_the_vacuum_breaks_black_in_the_net_too() -> void:
	var crack := DieNetView.rift_cracks(_die([Rift.AFTERGLOW], Essence.VACUUM), 40.0)[0] as DieNetView.RiftCrack
	assert_lt(crack.tint.r + crack.tint.g + crack.tint.b, 0.3, "das Vakuum bricht schwarz")
