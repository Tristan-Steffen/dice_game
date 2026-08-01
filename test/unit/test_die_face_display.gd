extends GutTest
## Tier-1-Tests der Würfel-Anzeige (DieFaceDisplay) auf einem echten
## DieBuilder-Würfel: Seitenwerte, Material-Tints von Seiten und Kanten-Rahmen,
## Eigenleuchten (Material-Flächen überhell) und das Umgebungslicht des Würfels
## (Farbe/Stärke folgen den Materialien).

## Bloom-Schwelle der Szene (WorldEnvironment.glow_hdr_threshold in
## scene_root.tscn) - darüber blüht eine Farbe auf, darunter bleibt sie Linie.
const BLOOM_THRESHOLD := 0.95

func _peak(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b))

func _display() -> DieFaceDisplay:
	var die: Node3D = autofree(DieBuilder.build())
	return die.get_node("RigidBody3D/Faces")

func _axis_for(face_index: int) -> String:
	for axis in DiceController.AXIS_FACE_INDEX:
		if DiceController.AXIS_FACE_INDEX[axis] == face_index:
			return axis
	return ""

func _face_material(display: DieFaceDisplay, face_index: int) -> StandardMaterial3D:
	return display.quads[_axis_for(face_index)].get_surface_override_material(0)

# --- Seitenwerte & Grundfarben ------------------------------------------------

func test_apply_definition_sets_face_values():
	var display := _display()
	display.apply_definition(DieDefinition.fixed(9, "Neun"))
	for axis in display.labels:
		assert_eq(display.labels[axis].text, "9")

func test_plain_die_uses_neutral_edge_neon():
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	assert_eq(display.edge_base, DieFaceDisplay.EDGE_COLOR)
	# Körper überall dunkles Glas; das Neon liegt in der Emission der Kanten.
	assert_eq(display.edge_material_res.albedo_color, DieFaceDisplay.BODY_COLOR * Color.WHITE)
	assert_eq(display.edge_material_res.emission,
		DieFaceDisplay.intense(DieFaceDisplay.EDGE_NEON) * DieFaceDisplay.EDGE_GLOW * Color.WHITE)

func test_the_essence_tints_the_frame():
	var def := DieDefinition.standard()
	def.essence_id = Essence.NEON
	var display := _display()
	display.apply_definition(def)
	assert_eq(display.edge_base, Essence.glow_for(Essence.NEON), "die Kanten glühen in Essenzfarbe")

func test_set_edge_tint_highlights_and_set_tint_restores():
	# Rahmen-Auswahl in der Gravur-Station: set_edge_tint übersteuert ihn,
	# set_tint stellt danach den normalen Rahmen wieder her.
	var def := DieDefinition.standard()
	def.essence_id = Essence.NEON
	var display := _display()
	display.apply_definition(def)
	display.set_edge_tint(RotatableDieView.SELECT_FACE_COLOR)
	assert_eq(display.edge_material_res.albedo_color, RotatableDieView.SELECT_FACE_COLOR)
	# Unschattiert, damit der Rahmen die FLACHE Auswahl-Farbe zeigt (wie die 2D-Chips
	# und die Ziffern) - nicht beleuchtet+leuchtend nach Pink klemmend.
	assert_eq(display.edge_material_res.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED,
		"der hervorgehobene Rahmen wird unschattiert gezeigt")
	display.set_tint(Color.WHITE)
	# Die Kanten tragen kein Material mehr - der Körper bleibt dunkles Glas, das
	# Licht liegt allein in der Emission der Essenz.
	assert_eq(display.edge_material_res.albedo_color, DieFaceDisplay.BODY_COLOR * Color.WHITE,
		"der Glaskörper des Rahmens kehrt zurück")
	assert_almost_eq(display.edge_material_res.emission.r,
		DieFaceDisplay.intense(Essence.glow_for(Essence.NEON)).r * DieFaceDisplay.MATERIAL_EDGE_GLOW_FLOOR, 0.001,
		"das Essenzglühen kehrt zurück")
	assert_eq(display.edge_material_res.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL,
		"set_tint nimmt die unschattierte Auswahl wieder zurück")

func test_set_face_number_tint_colors_only_that_digit_and_leaves_the_body():
	# Seiten-Auswahl in der Gravur-Station: nur die ZIFFER der gewählten Seite
	# leuchtet (set_face_number_tint), der Würfelkörper bleibt neutral.
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	display.set_face_number_tint(2, RotatableDieView.SELECT_FACE_COLOR)
	assert_eq(display.labels[_axis_for(2)].modulate, RotatableDieView.SELECT_FACE_COLOR,
		"die gewählte Ziffer leuchtet in der Auswahlfarbe")
	assert_eq(display.labels[_axis_for(3)].modulate, DieFaceDisplay.NUMBER_COLOR,
		"andere Ziffern behalten ihr Neutral-Neon")
	assert_eq(_face_material(display, 2).albedo_color, DieFaceDisplay.BODY_COLOR,
		"der Körper der gewählten Seite bleibt neutral")

func test_reset_number_tints_restores_all_digits():
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	display.set_face_number_tint(2, RotatableDieView.SELECT_FACE_COLOR)
	display.reset_number_tints()
	assert_eq(display.labels[_axis_for(2)].modulate, DieFaceDisplay.NUMBER_COLOR)

# --- Shading-Profile (Einlagen aus echtem Material) ------------------------------

func test_amber_face_glows_from_within_brighter_than_plain_faces():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.AMBER
	var display := _display()
	display.apply_definition(def)
	var amber := DieMaterial.amber()
	var amber_emission: Color = _face_material(display, 0).emission
	var plain_emission: Color = _face_material(display, 1).emission
	assert_almost_eq(amber_emission.r, DieFaceDisplay.intense(amber.tint).r * amber.glow, 0.001,
		"Material-Seite glüht in Tint × Profil-glow")
	assert_gt(amber_emission.r, plain_emission.r, "Bernstein heller als neutrale Seite")
	assert_almost_eq(plain_emission.r,
		DieFaceDisplay.intense(DieFaceDisplay.EDGE_NEON).r * DieFaceDisplay.FACE_GLOW, 0.001,
		"neutrale Seite glimmt nur schwach (dunkles Glas)")

func test_gold_face_is_reflective_metal_not_neon():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.GOLD
	var display := _display()
	display.apply_definition(def)
	var material := _face_material(display, 0)
	var gold := DieMaterial.gold()
	assert_almost_eq(material.metallic, DieMaterial.gold().metallic, 0.001, "Gold ist Metall")
	assert_eq(material.albedo_color, gold.surface_color * Color.WHITE,
		"helle Metall-Albedo statt dunklem Glas")
	assert_lt(material.emission.r, DieFaceDisplay.EDGE_NEON.r * DieFaceDisplay.EDGE_GLOW,
		"Gold glüht kaum - es spiegelt")

func test_bone_face_is_matte_and_dead():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.BONE
	var display := _display()
	display.apply_definition(def)
	var material := _face_material(display, 0)
	assert_eq(material.emission, Color(0, 0, 0, 0), "Knochen leuchtet gar nicht")
	assert_almost_eq(material.roughness, DieMaterial.bone().roughness, 0.001, "stumpf-matt")

func test_glass_face_is_transparent():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.GLASS
	var display := _display()
	display.apply_definition(def)
	var material := _face_material(display, 0)
	assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_almost_eq(material.albedo_color.a, DieMaterial.glass().alpha, 0.001,
		"das Würfelinnere scheint durch die Glas-Seite")
	assert_eq(_face_material(display, 1).transparency, BaseMaterial3D.TRANSPARENCY_DISABLED,
		"neutrale Seiten bleiben deckend")

func test_ruby_face_gets_its_facet_normal_map():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.RUBY
	var display := _display()
	display.apply_definition(def)
	assert_true(_face_material(display, 0).normal_enabled, "Rubin-Facetten fangen Licht")
	assert_false(_face_material(display, 1).normal_enabled, "neutrale Seiten bleiben flach")

func test_glass_edges_stay_opaque():
	# Der Füllkörper hinter dem Rahmen IST die Würfelmasse - Alpha würde ihn aushöhlen.
	var def := DieDefinition.standard()
	def.essence_id = Essence.XENON
	var display := _display()
	display.apply_definition(def)
	assert_eq(display.edge_material_res.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)

# --- Distanz-Signale (Ziffernfarbe, Leucht-Rahmen, Kanten-Floor, Eck-Kappen) ------

func test_material_face_digit_stays_neutral_white():
	# Ziffern bleiben unabhängig vom Material neutral-weiß - Materialfarben
	# machten die Zahl schwer lesbar. Identität tragen Fläche/Rahmen/Kanten.
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.RUBY
	var display := _display()
	display.apply_definition(def)
	assert_eq(display.labels[_axis_for(0)].modulate, DieFaceDisplay.NUMBER_COLOR,
		"Material-Ziffer bleibt weiß")
	assert_eq(display.labels[_axis_for(1)].modulate, DieFaceDisplay.NUMBER_COLOR,
		"neutrale Ziffern ebenso")

func test_reset_number_tints_restores_neutral_white():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.RUBY
	var display := _display()
	display.apply_definition(def)
	display.set_face_number_tint(0, RotatableDieView.SELECT_FACE_COLOR)
	display.reset_number_tints()
	assert_eq(display.labels[_axis_for(0)].modulate, DieFaceDisplay.NUMBER_COLOR,
		"nach der Auswahl kehrt das Neutral-Weiß zurück")

func test_material_face_shows_a_glowing_frame_plain_faces_none():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.RUBY
	var display := _display()
	display.apply_definition(def)
	var frame: MeshInstance3D = display.frames[_axis_for(0)]
	assert_true(frame.visible, "Material-Seite trägt den Leucht-Rahmen")
	var frame_material: StandardMaterial3D = frame.material_override
	assert_almost_eq(frame_material.emission.r,
		DieFaceDisplay.intense(DieMaterial.ruby().tint).r * DieFaceDisplay.FRAME_GLOW, 0.001,
		"Rahmen leuchtet voll in Materialfarbe")
	assert_false(display.frames[_axis_for(1)].visible, "neutrale Seiten bleiben rahmenlos")

func test_bone_frame_stays_dark():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.BONE
	var display := _display()
	display.apply_definition(def)
	var frame: MeshInstance3D = display.frames[_axis_for(0)]
	assert_true(frame.visible, "auch Knochen bekommt den Rahmen (als dunkle Linie)")
	assert_eq((frame.material_override as StandardMaterial3D).emission, Color(0, 0, 0, 0),
		"aber er leuchtet nie - Knochen-Identität")

func test_material_edges_glow_at_least_the_distance_floor():
	var def := DieDefinition.standard()
	def.essence_id = Essence.NEON
	var display := _display()
	display.apply_definition(def)
	var gold := DieMaterial.gold()
	assert_almost_eq(display.edge_material_res.emission.r,
		DieFaceDisplay.intense(gold.tint).r * DieFaceDisplay.MATERIAL_EDGE_GLOW_FLOOR, 0.001,
		"Gold-Kanten glühen mindestens auf Floor-Stärke (dünne Linien brauchen Emission)")

func test_essence_less_edges_keep_the_neutral_neon():
	# Ohne Seele glüht der Würfel nicht in einer Essenzfarbe, sondern im
	# neutralen Kanten-Neon.
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	assert_eq(display.edge_base, DieFaceDisplay.EDGE_COLOR, "kein Essenzglühen")

func test_corner_caps_only_with_an_essence():
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	assert_false(display.corner_caps.visible, "ohne Essenz keine Kappen")
	var def := DieDefinition.standard()
	def.essence_id = Essence.NEON
	display.apply_definition(def)
	assert_true(display.corner_caps.visible, "Kanten-Material beschlägt die Ecken")
	assert_eq(display.corner_caps.get_child_count(), 8)

# --- Boden-Lache ---------------------------------------------------------------

func test_every_die_pools_by_default():
	# Jeder Würfel wirft seinen Schein auf den Tisch - Grube, Tray, Werkstatt.
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	assert_true(display.glow_pool.visible, "die Lache läuft von Haus aus mit")

func test_plain_die_pools_in_the_bare_edge_tone():
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	assert_true(display.glow_pool.visible)
	var pool: Color = display._pool_color
	assert_almost_eq(pool.a,
		DieFaceDisplay.POOL_ALPHA_PER_STRENGTH * DieFaceDisplay.POOL_BASE_STRENGTH, 0.001)
	var expected := DieFaceDisplay.intense(DieFaceDisplay.POOL_BASE_COLOR)
	assert_almost_eq(pool.g, expected.g, 0.001,
		"die kahle Lache trägt genau den Ton, den die Kanten zeigen")

func test_material_die_pools_stronger_in_material_color():
	var def := DieDefinition.standard()
	def.essence_id = Essence.NEON
	var display := _display()
	display.apply_definition(def)
	assert_almost_eq(display._pool_color.a,
		DieFaceDisplay.POOL_ALPHA_PER_STRENGTH * DieFaceDisplay.POOL_EDGE_STRENGTH, 0.001)
	var gold_tint := DieFaceDisplay.intense(DieMaterial.tint_for(DieMaterial.GOLD))
	assert_almost_eq(display._pool_color.r, gold_tint.r, 0.001)
	assert_almost_eq(display._pool_color.b, gold_tint.b, 0.001)

func test_the_essence_alone_decides_the_pool_color():
	# Die Essenz IST die Quelle: sie wirft den Schein allein, die Seitenfarbe
	# mischt sich nicht ein.
	var def := DieDefinition.standard()
	def.essence_id = Essence.NEON
	def.materials[0] = DieMaterial.RUBY
	var display := _display()
	display.apply_definition(def)
	var expected := DieFaceDisplay.intense(Essence.glow_for(Essence.NEON))
	assert_almost_eq(display._pool_color.r, expected.r, 0.001)
	assert_almost_eq(display._pool_color.g, expected.g, 0.001)
	assert_almost_eq(display._pool_color.b, expected.b, 0.001)

func test_faces_alone_still_tint_the_pool():
	var def := DieDefinition.standard()
	def.materials[0] = DieMaterial.RUBY
	var display := _display()
	display.apply_definition(def)
	assert_almost_eq(display._pool_color.a,
		DieFaceDisplay.POOL_ALPHA_PER_STRENGTH * DieFaceDisplay.POOL_MATERIAL_STRENGTH, 0.001,
		"ohne Kanten-Material bleibt es beim schwächeren Seiten-Schein")
	var expected := DieFaceDisplay.intense(DieMaterial.tint_for(DieMaterial.RUBY))
	assert_almost_eq(display._pool_color.b, expected.b, 0.001)

func test_body_tint_colors_the_pool():
	var def := DieDefinition.standard()
	def.essence_id = Essence.NEON
	var display := _display()
	display.apply_definition(def)
	display.set_tint(Color(0.5, 0.5, 0.5))
	var expected := DieFaceDisplay.intense(DieMaterial.tint_for(DieMaterial.GOLD)) * Color(0.5, 0.5, 0.5)
	assert_almost_eq(display._pool_color.r, expected.r, 0.001)

func test_pool_can_be_switched_off_where_no_table_lies_below():
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	display.set_pool_enabled(false)
	assert_false(display.glow_pool.visible)

func test_a_die_looks_the_same_wherever_it_lies():
	# Kernregel: das Aussehen eines Würfels hängt NICHT daran, ob er in der Grube
	# liegt. Es gibt kein Würfellicht mehr - Grube, Tray und Werkstatt zeigen
	# dieselbe Emission. Nur die Lache am Boden ist der Grube vorbehalten.
	var def := DieDefinition.standard()
	def.essence_id = Essence.NEON
	var in_pit := _display()
	in_pit.apply_definition(def)
	var on_tray := _display()
	on_tray.apply_definition(def)
	assert_eq(in_pit.edge_material_res.emission, on_tray.edge_material_res.emission,
		"gleiche Kanten-Emission in Grube und Tray")
	assert_eq(_face_material(in_pit, 0).emission, _face_material(on_tray, 0).emission,
		"gleiche Flächen-Emission")
	assert_eq(in_pit.edge_material_res.albedo_color, on_tray.edge_material_res.albedo_color,
		"gleiche Albedo")

func test_edges_outshine_the_faces_by_far() -> void:
	# Kernregel der Würfel-Beleuchtung: das Licht kommt aus den Kanten, die
	# breiten Flächen glimmen nur - sonst verschwimmt die Kanten-Identität.
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	# Hellster Kanal, nicht Rot - Kanten und Flächen sind nicht rein rot.
	var e: Color = display.edge_material_res.emission
	var f: Color = _face_material(display, 0).emission
	assert_gt(_peak(e), _peak(f) * 8.0, "Kanten sind die Lichtquelle, nicht die Flächen")

func test_bare_dice_stay_below_the_bloom_threshold() -> void:
	# Der blanke Würfel soll NICHT strahlen: seine weißen Kanten bleiben unter
	# der Bloom-Schwelle der Szene (glow_hdr_threshold 0.95), erst ein Material
	# hebt ihn darüber. Sonst leuchtet der Grundwürfel wie ein veredelter.
	var display := _display()
	display.apply_definition(DieDefinition.standard())
	assert_lt(_peak(display.edge_material_res.emission), BLOOM_THRESHOLD,
		"kahle Kanten glühen nicht über")
	var def := DieDefinition.standard()
	def.essence_id = Essence.NEON
	display.apply_definition(def)
	assert_gt(_peak(display.edge_material_res.emission), BLOOM_THRESHOLD,
		"eine veredelte Kante glüht sehr wohl")

func test_intense_saturates_without_leaving_the_hue():
	var tint := DieMaterial.tint_for(DieMaterial.RUBY)
	var hot := DieFaceDisplay.intense(tint)
	assert_gt(hot.s, tint.s, "kräftiger gesättigt als der UI-Tint")
	assert_almost_eq(hot.h, tint.h, 0.001, "der Farbton bleibt derselbe")
	assert_eq(DieMaterial.tint_for(DieMaterial.RUBY), tint, "die UI-Quelle bleibt unberührt")

func test_material_edges_outshine_bare_ones() -> void:
	# Rangfolge: eine veredelte Kante muss die kahle überstrahlen, sonst wirkt
	# der blanke Würfel aufgeladener als der mit Material.
	assert_gt(DieFaceDisplay.MATERIAL_EDGE_GLOW_FLOOR, DieFaceDisplay.EDGE_GLOW,
		"Material-Kanten brennen heller als kahle")

func test_bare_light_matches_the_bare_edges() -> void:
	# Das Licht muss dieselbe Quelle haben, die man sieht: kahle Kanten leuchten
	# mintgrün, also ist auch ihr Schein mintgrün und kein warmes Weiß.
	assert_eq(DieFaceDisplay.POOL_BASE_COLOR, DieFaceDisplay.EDGE_NEON)

func test_pool_reaches_far_and_stays_calm() -> void:
	# Der Charakter des Würfelscheins: weit und ruhig. Er kommt aus der Lache,
	# nicht aus einem Strahler - ein weiter OmniLight-Verlauf bandet in
	# gl_compatibility in sichtbare Ringe.
	assert_gt(DieFaceDisplay.POOL_SPAN * 0.5, DicePit.PIT_HALF_X,
		"der Schein trägt über die halbe Grubenbreite hinaus")
	assert_lt(DieFaceDisplay.POOL_ALPHA_PER_STRENGTH * DieFaceDisplay.POOL_EDGE_STRENGTH, 0.35,
		"dabei bleibt er gedämpft - sechs Würfel dürfen sich addieren, ohne auszuwaschen")

func _shell_strength(display: DieFaceDisplay) -> float:
	return float(display.shell_material.get_shader_parameter("strength"))

func _shell_color(display: DieFaceDisplay) -> Vector3:
	return display.shell_material.get_shader_parameter("glow_color")

func test_the_essence_alone_decides_the_radiated_color():
	var def := DieDefinition.standard()
	def.essence_id = Essence.NEON
	def.materials[0] = DieMaterial.RUBY
	var display := _display()
	display.apply_definition(def)
	var gold := DieFaceDisplay.intense(DieMaterial.tint_for(DieMaterial.GOLD))
	var color := _shell_color(display)
	assert_almost_eq(color.x, gold.r, 0.001, "die Kante gibt die Abstrahlfarbe allein vor")
	assert_almost_eq(color.z, gold.b, 0.001)

func test_an_essence_radiates_more_than_a_bare_die():
	# Rangfolge kahl < Seiten-Material < Essenz: das Gas glüht dauernd.
	var plain := _display()
	plain.apply_definition(DieDefinition.standard())
	var def := DieDefinition.standard()
	def.essence_id = Essence.NITROGEN
	var souled := _display()
	souled.apply_definition(def)
	assert_gt(_shell_strength(souled), _shell_strength(plain), "die Seele strahlt am stärksten")

func test_pool_follows_the_die_size():
	# glow_pool ist top_level und erbt keine Skalierung: ein kleiner Tray-Würfel
	# muss trotzdem eine kleine Lache werfen, sonst waschen 30 Stück im Raster
	# den Tisch aus.
	var display := _display()
	add_child_autofree(display.get_parent().get_parent())
	display.apply_definition(DieDefinition.standard())
	display.scale = Vector3.ONE * 0.5
	display._process(0.016)
	assert_almost_eq(display.glow_pool.scale.x, 0.5, 0.05,
		"halb so großer Würfel, halb so große Lache")

# --- Leiterbahnen (durchgehendes Band) ------------------------------------------

func test_a_pointer_builds_one_continuous_ribbon():
	# EIN Band je Zeiger - kein Baukasten aus Einzelteilen, die an der Kante
	# unterschiedlich dick wirken.
	var def := DieDefinition.standard()
	def.pointers[3] = 0
	var display := _display()
	display.apply_definition(def)
	assert_eq(display.pointer_traces.size(), 1)
	assert_eq(display.pointer_traces[0].get_parent(), display,
		"das Band spannt über zwei Seiten - es hängt am Würfel, nicht an einem Quad")

func test_a_chain_builds_a_ribbon_per_link():
	var def := DieDefinition.standard()
	def.pointers[3] = 0
	def.pointers[0] = 4
	var display := _display()
	display.apply_definition(def)
	assert_eq(display.pointer_traces.size(), 2)

func test_the_ribbon_keeps_one_width_everywhere():
	# Der Kern der Sache: JEDE Stützstelle ist gleich breit - kein Pad, kein
	# Pfeil, keine dickere Stelle über dem Kantenbalken. Ein Riegel.
	var samples := DieFaceDisplay.trace_samples()
	var half := DieFaceDisplay.TRACE_WIDTH * 0.5
	for i in samples.size():
		assert_almost_eq(float(samples[i][1]), half, 0.0001,
			"Stützstelle %d hält die Bandbreite" % i)
	assert_gt(samples.size(), 10, "der verrundete Weg hat genug Stützstellen")

func test_the_ribbon_never_cuts_through_the_edge_beam():
	# Der Balkenquerschnitt in der Ebene (d, t): HALF_EXTENT +/- EDGE_THICKNESS/2.
	# Die Bahn muss außen herum - sonst verschwindet sie im Balken.
	var low := DieBuilder.HALF_EXTENT - DieBuilder.EDGE_THICKNESS * 0.5
	var high := DieBuilder.HALF_EXTENT + DieBuilder.EDGE_THICKNESS * 0.5
	var over_the_beam := false
	for sample in DieFaceDisplay.trace_samples():
		var p: Vector2 = sample[0]
		assert_false(p.x > low and p.x < high and p.y > low and p.y < high,
			"Stützstelle %s liegt im Kantenbalken" % p)
		if p.x > high or p.y > high:
			over_the_beam = true
	assert_true(over_the_beam, "und sie führt wirklich über den Balken, nicht daneben")

func test_the_ribbon_reaches_only_a_fifth_into_each_face():
	# Beide Enden liegen ein Fünftel der Seitenfläche hinter dem Quad-Rand -
	# keine Zunge bis zur Ziffer, weder am Start noch am Ziel.
	var samples := DieFaceDisplay.trace_samples()
	var first: Vector2 = samples[0][0]
	var last: Vector2 = samples[samples.size() - 1][0]
	assert_almost_eq(first.y, DieFaceDisplay.TRACE_START, 0.0001, "Quellende")
	assert_almost_eq(last.x, DieFaceDisplay.TRACE_START, 0.0001, "Zielende")
	var fifth := DieBuilder.FACE_SIZE / 5.0
	assert_almost_eq(DieFaceDisplay.WALL_B - DieFaceDisplay.TRACE_START, fifth, 0.02,
		"die Reichweite ins Feld ist ein Fünftel der Seitenfläche")

func test_the_ribbon_mesh_is_shared_between_dice():
	# 30 Tray-Würfel dürfen nicht 30 Netze bauen - je Achsenpaar genau eins.
	var a := DieFaceDisplay.trace_mesh("OBEN", "VORNE")
	var b := DieFaceDisplay.trace_mesh("OBEN", "VORNE")
	assert_eq(a, b, "dasselbe Netz")
	assert_ne(a, DieFaceDisplay.trace_mesh("OBEN", "RECHTS"), "anderes Paar, anderes Netz")

func test_the_mesh_carries_arc_length_uvs():
	# UV.y ist die Bogenlänge - daraus fährt der Shader den Lichtkopf.
	var mesh := DieFaceDisplay.trace_mesh("OBEN", "VORNE")
	var uvs: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var lowest := 1.0
	var highest := 0.0
	for uv in uvs:
		lowest = minf(lowest, uv.y)
		highest = maxf(highest, uv.y)
	assert_almost_eq(lowest, 0.0, 0.0001, "das Pad liegt bei 0")
	assert_almost_eq(highest, 1.0, 0.0001, "die Spitze bei 1")

func test_reapplying_without_pointers_clears_the_traces():
	var def := DieDefinition.standard()
	def.pointers[3] = 0
	var display := _display()
	display.apply_definition(def)
	assert_eq(display.pointer_traces.size(), 1)
	display.apply_definition(DieDefinition.standard())
	assert_eq(display.pointer_traces.size(), 0, "alte Bahnen werden abgeräumt")

func test_an_invalid_pointer_stays_silent():
	# Gegenseite ist kein Nachbar - darf nie vorkommen, zeichnet aber sicher nichts.
	var def := DieDefinition.standard()
	def.pointers[0] = 5
	var display := _display()
	display.apply_definition(def)
	assert_eq(display.pointer_traces.size(), 0)

func test_chevron_crest_blooms_and_the_groove_stays_dark():
	# Der Kontrast NACH UNTEN ist die Lesbarkeit: der Chevron-Kamm blüht (über
	# der Schwelle, unter dem Boden der Material-Kanten), die Rille dazwischen
	# bleibt klar dunkel - sonst klemmt das ganze Band auf Weiß und die
	# Strömung verschwindet.
	var def := DieDefinition.standard()
	def.pointers[3] = 0
	var display := _display()
	display.apply_definition(def)
	var color: Vector3 = display.pointer_material.get_shader_parameter("trace_color")
	var peak := maxf(color.x, maxf(color.y, color.z))
	var crest: float = display.pointer_material.get_shader_parameter("crest_energy")
	assert_gt(peak * crest, BLOOM_THRESHOLD, "der Kamm blüht")
	assert_lt(peak * crest, DieFaceDisplay.MATERIAL_EDGE_GLOW_FLOOR,
		"aber unter der veredelten Kante")
	var groove: float = display.pointer_material.get_shader_parameter("base_energy")
	assert_lt(peak * groove, BLOOM_THRESHOLD * 0.5, "die Rille bleibt deutlich dunkel")

func test_the_flow_runs_on_shader_time_with_a_per_die_phase():
	# Die Strömung treibt TIME im Shader - hier wird nur die Phase einmal
	# gesetzt, versetzt je Würfel, damit kein Tray-Raster im Gleichtakt fließt.
	var def := DieDefinition.standard()
	def.pointers[3] = 0
	var first := _display()
	var second := _display()
	first.apply_definition(def)
	second.apply_definition(def)
	assert_almost_eq(float(first.pointer_material.get_shader_parameter("phase")),
		first._pulse_phase / TAU, 0.0001, "die Phase kommt aus dem Würfel-Streuwert")
	assert_ne(float(first.pointer_material.get_shader_parameter("phase")),
		float(second.pointer_material.get_shader_parameter("phase")),
		"zwei Würfel fließen versetzt")

# --- Sättigung: die Stufe färbt, sie leuchtet nicht --------------------------------

func _leveled(face_index: int, material_id: String, level: int) -> DieDefinition:
	var def := DieDefinition.standard()
	def.set_face_material(face_index, material_id)
	for _step in range(1, level):
		def.raise_level(face_index)
	return def

func test_level_three_saturates_the_face_albedo():
	var display := _display()
	display.apply_definition(_leveled(0, DieMaterial.RUBY, 1))
	var base: Color = _face_material(display, 0).albedo_color
	display.apply_definition(_leveled(0, DieMaterial.RUBY, 3))
	var rich: Color = _face_material(display, 0).albedo_color
	assert_ne(rich, base, "Stufe III sieht anders aus als Stufe I")
	var profile := DieMaterial.by_id(DieMaterial.RUBY)
	var expected := DieMaterial.saturated(profile.surface_color, 3) * display.body_tint
	assert_almost_eq(rich.r, expected.r, 0.001)
	assert_almost_eq(rich.g, expected.g, 0.001)
	assert_almost_eq(rich.b, expected.b, 0.001)
	assert_gt(rich.s, base.s, "und zwar SATTER, nicht nur anders")

func test_level_one_leaves_the_face_exactly_where_it_was():
	# Stufe I ist der Normalfall und kündigt sich nie an.
	var display := _display()
	display.apply_definition(_leveled(0, DieMaterial.RUBY, 1))
	var expected := DieMaterial.by_id(DieMaterial.RUBY).surface_color * display.body_tint
	assert_eq(_face_material(display, 0).albedo_color, expected)

func test_the_level_steps_the_frame_glow_too():
	var display := _display()
	display.apply_definition(_leveled(0, DieMaterial.RUBY, 1))
	var base: Color = display.frames[_axis_for(0)].material_override.emission
	display.apply_definition(_leveled(0, DieMaterial.RUBY, 3))
	var rich: Color = display.frames[_axis_for(0)].material_override.emission
	assert_gt(rich.s, base.s, "der Leuchtrahmen zieht mit")

func test_no_level_lifts_a_face_over_the_bloom_threshold():
	# Das Signal der Stufe ist Farbreinheit, nie Helligkeit - dieselbe Regel wie
	# bei den Rissen, sonst wird jede Stufe-III-Seite zur Lampe.
	var display := _display()
	for material in DieMaterial.all():
		for level in [1, 2, 3]:
			display.apply_definition(_leveled(0, material.id, level))
			var lit: Color = _face_material(display, 0).emission
			var frame: Color = display.frames[_axis_for(0)].material_override.emission
			var grew := _peak(lit) - _peak(DieFaceDisplay.intense(material.tint) * material.glow)
			assert_lt(grew, 0.10,
				"%s Stufe %d leuchtet höchstens einen Hauch heller" % [material.id, level])
			assert_true(_peak(frame) < BLOOM_THRESHOLD or material.glow > 0.0,
				"%s: ohne Glühen bleibt auch der Rahmen dunkel" % material.id)

func test_bone_stays_dead_matte_at_level_three():
	var display := _display()
	display.apply_definition(_leveled(0, DieMaterial.BONE, 3))
	assert_eq(_peak(_face_material(display, 0).emission), 0.0, "Knochen glüht auf keiner Stufe")
	assert_eq(_peak(display.frames[_axis_for(0)].material_override.emission), 0.0,
		"und sein Rahmen auch nicht")
	assert_gt(_face_material(display, 0).albedo_color.s,
		DieMaterial.by_id(DieMaterial.BONE).surface_color.s,
		"seine Stufe reitet allein auf der Albedo")

func test_the_level_reaches_the_pool_through_face_base():
	var display := _display()
	display.apply_definition(_leveled(0, DieMaterial.RUBY, 3))
	assert_eq(display.face_base[_axis_for(0)], DieMaterial.tint_for(DieMaterial.RUBY, 3),
		"Lache, Hülle und Neon-Mischung erben die Sättigung von hier")
