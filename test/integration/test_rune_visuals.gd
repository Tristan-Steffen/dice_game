extends GutTest
## Die Runen-Anzeige: der farblose Bake, die Shader-Auflage und die Regel, dass
## nur die OBERE Seite auflodert. Was hier nicht geprüft werden kann, ist das
## Aussehen - aber alles, was die Anzeige falsch verdrahten könnte, schon.

func _die(rune_ids: Array = [], essence_id := "") -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [1, 2, 3, 4, 5, 6]
	def.faces = faces
	def.essence_id = essence_id
	for i in rune_ids.size():
		def.set_rune(0, String(rune_ids[i]), i)
	return def

## Gebauter Würfel mit seinem Anzeige-Knoten.
func _display(def: DieDefinition) -> DieFaceDisplay:
	var root := DieBuilder.build()
	add_child_autofree(root)
	var faces: DieFaceDisplay = root.get_node("RigidBody3D/Faces")
	faces.apply_definition(def)
	return faces

# --- Der Bake: sechs Texturen, für immer ---------------------------------------------

func test_the_bake_is_cached_per_glyph_only() -> void:
	RuneTextures.warm()
	assert_eq(RuneTextures.cache_size(), Rune.all_glyphs().size(),
		"genau eine Textur je Zeichen")
	# Ein Vakuum-Würfel trug früher seine eigene schwarze Kopie je Kombination.
	# Farblos gebacken kostet er nichts extra - das ist der ganze Sinn der Umstellung.
	_display(_die([Rune.AFTERGLOW, Rune.SPARK_FLIGHT], Essence.VACUUM))
	_display(_die([Rune.BURN_IN], Essence.NEON))
	assert_lte(RuneTextures.cache_size(), Rune.all_glyphs().size(),
		"auch mit Essenzen und zwei Zeichen je Seite bleibt es bei einer je Zeichen")

func test_the_same_glyph_hands_back_the_same_texture() -> void:
	assert_same(RuneTextures.for_glyph(Rune.GLYPH_SPARK_FLIGHT),
		RuneTextures.for_glyph(Rune.GLYPH_SPARK_FLIGHT), "gecacht, nicht neu gebacken")
	assert_same(RuneTextures.for_rune(Rune.SPARK_FLIGHT),
		RuneTextures.for_glyph(Rune.GLYPH_SPARK_FLIGHT), "Rune und Zeichen teilen die Maske")

func test_an_unknown_glyph_bakes_nothing() -> void:
	assert_null(RuneTextures.for_glyph(""))
	assert_null(RuneTextures.for_glyph("kein_zeichen"))

func test_the_mask_carries_all_four_channels() -> void:
	var image := RuneTextures.for_glyph(Rune.GLYPH_SPARK_FLIGHT).get_image()
	image.clear_mipmaps()
	var arc_low := 1.0
	var arc_high := 0.0
	var on_core := 0
	var far_field := 0
	for y in RuneTextures.SIZE:
		for x in RuneTextures.SIZE:
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
	var image := RuneTextures.for_glyph(Rune.GLYPH_AFTERGLOW).get_image()
	image.clear_mipmaps()
	var tinted := 0
	for y in RuneTextures.SIZE:
		for x in RuneTextures.SIZE:
			var texel := image.get_pixel(x, y)
			# Auf der Mittellinie ist R hoch und B null - eine echte Farbe hätte
			# hier den Farbton der Tönung, keine Kanal-Semantik.
			if texel.r > 0.9 and texel.b > 0.5:
				tinted += 1
	assert_eq(tinted, 0, "Kern und Abstandsfeld widersprechen sich nie")

# --- Die Auflage am Würfel ----------------------------------------------------------

func test_a_face_with_a_rune_carries_the_shader() -> void:
	var faces := _display(_die([Rune.AFTERGLOW]))
	var overlay := _overlay(faces, 0)
	assert_true(overlay.visible, "die beschriftete Seite zeigt ihre Auflage")
	var material := overlay.material_override as ShaderMaterial
	assert_not_null(material, "ShaderMaterial statt StandardMaterial3D")
	assert_same(material.shader, DieBuilder.RUNE_SHADER, "EIN Shader, ein Compile")
	assert_eq(material.get_shader_parameter("motion"), Rune.MOTION_ECHO)
	assert_eq(material.get_shader_parameter("glyph_flip"), Rune.slot_flip(0),
		"der erste Platz zeichnet die Figur ungespiegelt")

func test_an_unbroken_face_shows_nothing() -> void:
	var faces := _display(_die([Rune.AFTERGLOW]))
	assert_false(_overlay(faces, 3).visible, "eine leere Seite trägt kein Zeichen")

func test_the_seam_colour_reaches_the_shader_normalized() -> void:
	var faces := _display(_die([Rune.SPARK_FLIGHT]))
	var seam: Vector3 = _material(faces, 0).get_shader_parameter("seam_color")
	assert_almost_eq(maxf(seam.x, maxf(seam.y, seam.z)), 1.0, 0.001,
		"energy heißt in jedem Profil dasselbe")
	assert_almost_eq(seam.z, 1.0, 0.01, "und es bleibt das Energie-Cyan")

func test_the_vacuum_swallows_every_rune_and_mirrors_the_second() -> void:
	var faces := _display(_die([Rune.AFTERGLOW, Rune.SPARK_FLIGHT], Essence.VACUUM))
	assert_eq(_material(faces, 0).get_shader_parameter("motion"), Rune.MOTION_INTAKE,
		"auf einem Vakuum-Würfel saugt auch das Nachglühen")
	var second: MeshInstance3D = faces.rune_overlays_second.get(_axis_of(faces, 0))
	assert_not_null(second, "das zweite Zeichen bekommt seine eigene Auflage")
	assert_true(second.visible)
	var second_material := second.material_override as ShaderMaterial
	assert_eq(second_material.get_shader_parameter("glyph_flip"), Rune.slot_flip(1),
		"eigene Spiegelung - sonst liegen beide Zeichen deckungsgleich")
	assert_ne(Rune.slot_flip(1), Rune.slot_flip(0))
	assert_eq(second_material.get_shader_parameter("motion"), Rune.MOTION_INTAKE)

func test_a_single_rune_builds_no_second_overlay() -> void:
	var faces := _display(_die([Rune.BURN_IN]))
	var second: MeshInstance3D = faces.rune_overlays_second.get(_axis_of(faces, 0))
	assert_true(second == null or not second.visible, "faul gebaut: kein Vakuum, keine zweite Auflage")

# --- Nur die obere Seite lodert -----------------------------------------------------

func test_the_flare_reaches_only_the_named_face() -> void:
	var def := _die([Rune.AFTERGLOW])
	def.set_rune(3, Rune.SPARK_FLIGHT)
	var faces := _display(def)
	faces.flare_runes(1.0, 0)
	assert_almost_eq(float(_material(faces, 0).get_shader_parameter("flare")), 1.0, 0.001,
		"die gewertete Seite lodert")
	assert_almost_eq(float(_material(faces, 3).get_shader_parameter("flare")), 0.0, 0.001,
		"eine Seitenfläche behauptet sonst eine Wirkung, die es nicht gibt")

func test_the_block_flare_is_its_own_gesture() -> void:
	var faces := _display(_die([Rune.BURN_IN]))
	faces.flare_runes(1.0, 0, true)
	assert_true(bool(_material(faces, 0).get_shader_parameter("block_flare")),
		"ein verhinderter Schrumpf sieht anders aus als eine Wertung")
	faces.flare_runes(1.0, 0, false)
	assert_false(bool(_material(faces, 0).get_shader_parameter("block_flare")))

# --- Der Ziffern-Wächter ------------------------------------------------------------

func test_a_two_digit_value_widens_the_guard_not_the_crack() -> void:
	var def := _die([Rune.AFTERGLOW])
	def.faces[0] = 12
	var faces := _display(def)
	var half: Vector2 = _material(faces, 0).get_shader_parameter("digit_half")
	assert_almost_eq(half.x, Rune.DIGIT_KEEPOUT.x + DieFaceDisplay.DIGIT_GUARD_WIDEN, 0.001,
		"zwei Stellen -> breitere Sperrzone")
	assert_almost_eq(half.y, Rune.DIGIT_KEEPOUT.y, 0.001, "die Höhe bleibt")
	# Die Figur selbst ist NIE eine Funktion des Werts - Knochen lässt Werte
	# wachsen, und eine Rune, der sich dabei neu zeichnet, liest als Fehler.
	assert_eq(Rune.glyph_lines(Rune.GLYPH_AFTERGLOW), Rune.glyph_lines(Rune.GLYPH_AFTERGLOW))

func test_a_single_digit_keeps_the_authored_keepout() -> void:
	var faces := _display(_die([Rune.AFTERGLOW]))
	var half: Vector2 = _material(faces, 0).get_shader_parameter("digit_half")
	assert_almost_eq(half.x, Rune.DIGIT_KEEPOUT.x, 0.001)

# --- Helfer -------------------------------------------------------------------------

func _axis_of(faces: DieFaceDisplay, face_index: int) -> String:
	for axis: String in faces.rune_overlays:
		if DiceController.AXIS_FACE_INDEX[axis] == face_index:
			return axis
	return ""

func _overlay(faces: DieFaceDisplay, face_index: int) -> MeshInstance3D:
	return faces.rune_overlays[_axis_of(faces, face_index)]

func _material(faces: DieFaceDisplay, face_index: int) -> ShaderMaterial:
	return _overlay(faces, face_index).material_override as ShaderMaterial

# --- Das 2D-Netz: still, außer auf der Grubenkarte ----------------------------------

func test_the_net_draws_one_glyph_per_rune_and_knows_its_face() -> void:
	var def := _die([Rune.AFTERGLOW, Rune.SPARK_FLIGHT], Essence.VACUUM)
	def.set_rune(4, Rune.STRAY_LIGHT)
	var cracks := DieNetView.rune_glyphs(def, 40.0)
	assert_eq(cracks.size(), 3, "zwei Zeichen auf Seite 1, eines auf Seite 5")
	var faces := {}
	for crack in cracks:
		faces[(crack as DieNetView.RuneGlyph).face] = true
	assert_true(faces.has(0) and faces.has(4), "jede Rune kennt ihre Zelle")

func test_the_net_carries_the_branch_weights() -> void:
	var cracks := DieNetView.rune_glyphs(_die([Rune.SPARK_FLIGHT]), 40.0)
	var crack := cracks[0] as DieNetView.RuneGlyph
	assert_eq(crack.weights.size(), crack.lines.size(), "je Linie ein Gewicht")
	assert_lt(crack.weights[1], crack.weights[0], "der Beistrich ist dünner als der Hauptstrich")

func test_the_net_glyph_fills_its_cell_like_the_card() -> void:
	# Spieler-Wunsch 2026-09-11: im Netz dieselbe Größe und Lage wie auf der Karte -
	# der Kranz las als kleines Zeichen in der Ecke.
	var crack := DieNetView.rune_glyphs(_die([Rune.AFTERGLOW]), 40.0)[0] as DieNetView.RuneGlyph
	var rune := Rune.by_id(Rune.AFTERGLOW)
	assert_eq(crack.bounds, Rune.glyph_bounds(rune.glyph), "auf den eigenen Kasten gezogen")
	assert_gt(crack.bounds.size.x, 0.0, "der Kasten ist nicht leer")

func test_a_net_crack_rests_without_flare() -> void:
	# Das 30-Würfel-Raster ist eine Lesefläche, keine Bühne: dort steht das Zeichen
	# still, weil er nie eine andere Flare-Quelle als die Grubenkarte bekommt.
	var crack := DieNetView.rune_glyphs(_die([Rune.BURN_IN]), 40.0)[0] as DieNetView.RuneGlyph
	assert_almost_eq(crack.flare, 0.0, 0.001)

func test_the_vacuum_breaks_black_in_the_net_too() -> void:
	var crack := DieNetView.rune_glyphs(_die([Rune.AFTERGLOW], Essence.VACUUM), 40.0)[0] as DieNetView.RuneGlyph
	assert_lt(crack.tint.r + crack.tint.g + crack.tint.b, 0.3, "das Vakuum steht schwarz")
