extends GutTest
## Der Dauerwächter der Runenzeichen. Seit den GERITZTEN RUNEN (2026-11-19) ist jede
## Figur aus wenigen geraden Strichen geschnitten und läuft hinter der Ziffer durch.
## Geprüft wird die FORM selbst: Rand, Größe, Strichzahl und dass keine zwei
## Zeichen dieselbe Silhouette tragen.

## float32-Toleranz der PackedVector2Array-Speicherung.
const EPS := 0.0001
## Abstand, unter dem zwei Figur-Punkte als derselbe gelten (Sinus-Rundung).
const SAME_POINT := 0.001

func test_every_glyph_stays_inside_the_face() -> void:
	# Der Rand trägt den Hof (RuneTextures.FIELD): läuft die Figur bis an die
	# Seitenkante, schneidet der Shader ihren Ausbruch als Rechteck ab.
	for glyph in Rune.all_glyphs():
		var lines := Rune.glyph_lines(glyph)
		assert_false(lines.is_empty(), "%s hat überhaupt eine Figur" % glyph)
		for line_index in lines.size():
			var line: PackedVector2Array = lines[line_index]
			for point in line:
				# EPS: PackedVector2Array speichert float32, ein glattes 0.94 landet
				# knapp daneben.
				assert_between(point.x, Rune.GLYPH_MARGIN - EPS, 1.0 - Rune.GLYPH_MARGIN + EPS,
					"%s Linie %d: x verlässt den Seitenrand" % [glyph, line_index])
				assert_between(point.y, Rune.GLYPH_MARGIN - EPS, 1.0 - Rune.GLYPH_MARGIN + EPS,
					"%s Linie %d: y verlässt den Seitenrand" % [glyph, line_index])

func test_the_halo_field_fits_inside_the_margin() -> void:
	assert_lte(RuneTextures.FIELD, Rune.GLYPH_MARGIN,
		"sonst schneidet der Seitenrand den Hof ab")

func test_every_glyph_is_carved_from_straight_strokes() -> void:
	# Eine Rune ist geritzt: gerade Striche, keine Bögen. Ein Bogen wäre hier ein
	# Linienzug aus vielen kurzen Stücken.
	for glyph in Rune.all_glyphs():
		var strokes := 0
		for line: PackedVector2Array in Rune.glyph_lines(glyph):
			assert_gt(line.size(), 1, "%s: jede Linie ist ein Strich" % glyph)
			for i in range(line.size() - 1):
				strokes += 1
				assert_gt(line[i].distance_to(line[i + 1]), 0.15,
					"%s: kein Strich ist ein Bogenstück" % glyph)
		assert_between(strokes, 3, 6, "%s: wenige, klare Striche" % glyph)

func test_no_two_glyphs_share_a_silhouette() -> void:
	# Auf einer Material-Seite kann die Farbe der Rune der der Fläche gleichen -
	# dann trennt allein die Form. Verglichen wird ein grobes Raster der Striche.
	var prints := {}
	for glyph in Rune.all_glyphs():
		prints[glyph] = _footprint(glyph)
	var glyphs := Rune.all_glyphs()
	for a in glyphs.size():
		for b in range(a + 1, glyphs.size()):
			var only_one := 0
			var either := 0
			for cell in prints[glyphs[a]].keys() + prints[glyphs[b]].keys():
				var in_a: bool = prints[glyphs[a]].has(cell)
				var in_b: bool = prints[glyphs[b]].has(cell)
				if in_a != in_b:
					only_one += 1
				either += 1
			assert_gt(float(only_one) / float(either), 0.3,
				"%s und %s decken fast dieselben Zellen" % [glyphs[a], glyphs[b]])

## Zellen eines 8×8-Rasters, durch die ein Strich der Figur läuft.
func _footprint(glyph: String) -> Dictionary:
	var cells := {}
	for line: PackedVector2Array in Rune.glyph_lines(glyph):
		for i in range(line.size() - 1):
			for step in 41:
				var point := line[i].lerp(line[i + 1], float(step) / 40.0)
				cells[Vector2i(int(point.x * 8.0), int(point.y * 8.0))] = true
	return cells

func test_every_glyph_reaches_the_authored_radius() -> void:
	# EINE Größe je Ding: eine Figur, die kleiner ausfällt als ihre Nachbarin,
	# liest als zweite Größe statt als zweites Zeichen.
	for glyph in Rune.all_glyphs():
		var reach := 0.0
		for line: PackedVector2Array in Rune.glyph_lines(glyph):
			for point in line:
				reach = maxf(reach, point.distance_to(Rune.CENTER))
		assert_gte(reach, Rune.GLYPH_RADIUS - 0.001,
			"%s bleibt hinter dem authored Radius zurück" % glyph)

# --- Der Platz: ineinander statt gespiegelt ---------------------------------------

func test_the_first_slot_leaves_the_figure_alone() -> void:
	var probe := Vector2(0.5, 0.06)
	assert_lt(Rune.place(probe, 0).distance_to(probe), SAME_POINT,
		"Platz 0 IST die gezeichnete Figur")
	assert_almost_eq(Rune.slot_scale(0), 1.0, 0.001)

func test_each_further_slot_nests_inside_the_one_before() -> void:
	for slot in range(1, Rune.SLOT_SCALES.size()):
		assert_lt(Rune.slot_scale(slot), Rune.slot_scale(slot - 1),
			"Platz %d liegt INNERHALB seines Vorgängers" % slot)

func test_the_slots_never_coincide() -> void:
	# DAS ist der Grund, warum gestaffelt und nicht gespiegelt wird: eine
	# symmetrische Grundform ist ihr eigenes Spiegelbild.
	var probe := Vector2(0.5, 0.06)
	for a in Rune.SLOT_SCALES.size():
		for b in range(a + 1, Rune.SLOT_SCALES.size()):
			assert_gt(Rune.place(probe, a).distance_to(Rune.place(probe, b)), 0.05,
				"Plätze %d und %d lägen deckungsgleich" % [a, b])

func test_a_placed_glyph_stays_inside_the_face() -> void:
	for slot in Rune.SLOT_SCALES.size():
		for glyph in Rune.all_glyphs():
			for line: PackedVector2Array in Rune.glyph_lines(glyph):
				for point in line:
					var seat := Rune.place(point, slot)
					assert_between(seat.x, Rune.GLYPH_MARGIN - EPS, 1.0 - Rune.GLYPH_MARGIN + EPS,
						"%s auf Platz %d verlässt den Seitenrand (x)" % [glyph, slot])
					assert_between(seat.y, Rune.GLYPH_MARGIN - EPS, 1.0 - Rune.GLYPH_MARGIN + EPS,
						"%s auf Platz %d verlässt den Seitenrand (y)" % [glyph, slot])

func test_every_polyline_carries_a_weight() -> void:
	for glyph in Rune.all_glyphs():
		assert_eq(Rune.glyph_weights(glyph).size(), Rune.glyph_lines(glyph).size(),
			"%s: je Linie genau ein Gewicht" % glyph)

func test_every_stroke_is_carved_equally_deep() -> void:
	for glyph in Rune.all_glyphs():
		for weight in Rune.glyph_weights(glyph):
			assert_almost_eq(weight, 1.0, 0.001, "%s: jeder Strich in voller Stärke" % glyph)

func test_every_rune_owns_exactly_one_glyph() -> void:
	# Je Wirkung eine erkennbare Idee - zwei Runen mit derselben Figur wären
	# am Würfel nicht auseinanderzuhalten.
	var seen := {}
	for rune in Rune.all():
		assert_false(seen.has(rune.glyph), "%s teilt sein Zeichen" % rune.id)
		seen[rune.glyph] = true
		assert_true(Rune.all_glyphs().has(rune.glyph), "%s: Zeichen ist registriert" % rune.id)
	assert_eq(seen.size(), Rune.all_glyphs().size(), "kein Zeichen ohne Rune")

# --- Der Kasten der Figur: ihr Weg auf die KARTE -----------------------------------
# Auf dem Würfel läuft die Figur um eine Ziffer herum, also gehört ihr die Mitte
# nicht. In einer Prägenetz-Zelle steht keine Ziffer - dort zieht sie sich auf ihren
# eigenen Kasten, sonst verschenkte sie den leeren Kranz.

func test_every_glyph_reports_a_box_that_holds_all_of_it() -> void:
	for glyph in Rune.all_glyphs():
		var box := Rune.glyph_bounds(glyph)
		assert_gt(box.size.x, 0.0, "%s: der Kasten hat eine Breite" % glyph)
		assert_gt(box.size.y, 0.0, "%s: der Kasten hat eine Höhe" % glyph)
		for line: PackedVector2Array in Rune.glyph_lines(glyph):
			for point in line:
				assert_between(point.x, box.position.x - EPS, box.end.x + EPS,
					"%s: der Kasten hält jeden Punkt (x)" % glyph)
				assert_between(point.y, box.position.y - EPS, box.end.y + EPS,
					"%s: der Kasten hält jeden Punkt (y)" % glyph)

func test_fitting_a_glyph_to_its_box_fills_the_card_cell() -> void:
	# Der Kasten wird auf 0..1 gezogen - erst das macht die Figur auf der Karte groß.
	for glyph in Rune.all_glyphs():
		var box := Rune.glyph_bounds(glyph)
		var low := Rune.fit_to_bounds(box.position, box)
		var high := Rune.fit_to_bounds(box.end, box)
		assert_almost_eq(low.x, 0.0, 0.001, "%s: linke Kante auf 0" % glyph)
		assert_almost_eq(low.y, 0.0, 0.001, "%s: obere Kante auf 0" % glyph)
		assert_almost_eq(high.x, 1.0, 0.001, "%s: rechte Kante auf 1" % glyph)
		assert_almost_eq(high.y, 1.0, 0.001, "%s: untere Kante auf 1" % glyph)

func test_a_flat_box_leaves_the_point_alone() -> void:
	# Keine Division durch null: ein Kasten ohne Höhe lässt die Figur, wo sie ist.
	var flat := Rect2(0.2, 0.5, 0.6, 0.0)
	assert_eq(Rune.fit_to_bounds(Vector2(0.4, 0.5), flat), Vector2(0.4, 0.5))

# --- Die Ruhe-Regel (Schritt 13 der Umsetzungsliste) --------------------------------

func test_every_idle_profile_blooms_at_rest() -> void:
	# Seit dem 2026-09-11 die Zusage: eine Rune, die man auf Grubendistanz nicht
	# sieht, ist keine. Gemessen am BODEN - bei ECHO und SPARK liegt fast die ganze
	# Naht dort, die Spitze wandert nur als Bande darüber.
	for rune in Rune.all():
		assert_gt(rune.idle_low, Rune.IDLE_GLOW,
			"%s glimmt unter der Lesbarkeitsschwelle" % rune.display_name)
		assert_gt(rune.idle_low, Rune.IDLE_CEILING,
			"%s blüht in Ruhe nicht" % rune.display_name)
		assert_lt(rune.idle_low, rune.idle_high, "%s: Boden unter Spitze" % rune.display_name)

func test_every_flare_outshines_its_own_idle() -> void:
	# Der Deckel ist weg, also trägt der ABSTAND die Regel: ein Ausbruch, der die
	# Ruhe nicht um ein Vielfaches überstrahlt, liest nicht mehr als Ereignis.
	for rune in Rune.all():
		assert_gte(rune.flare_peak, rune.idle_high * Rune.FLARE_RATIO,
			"%s: der Ausbruch verschwindet in der eigenen Ruhe" % rune.display_name)
		assert_gt(rune.halo_flare, 1.0,
			"%s: der Ausbruch liest über Breite, nicht über Helligkeit" % rune.display_name)

func test_the_seam_color_is_normalized() -> void:
	# "energy" heißt in jedem Profil dasselbe: die hellste Komponente.
	for rune in Rune.all():
		var seam := rune.normalized_seam()
		assert_almost_eq(maxf(seam.r, maxf(seam.g, seam.b)), 1.0, 0.001,
			"%s: Naht-Farbe auf max == 1 normiert" % rune.display_name)

func test_spark_flight_normalizes_to_the_energy_cyan() -> void:
	# Funkenflug trägt HDR-Cyan; die Normierung darf den Farbton nicht verdrehen,
	# sonst liest der Funke nicht mehr als dieselbe Energie wie der Kondensator.
	var seam := Rune.by_id(Rune.SPARK_FLIGHT).normalized_seam()
	assert_almost_eq(seam.r, 0.26, 0.01)
	assert_almost_eq(seam.g, 0.90, 0.01)
	assert_almost_eq(seam.b, 1.00, 0.01)

func test_the_vacuum_profile_overrides_every_rune() -> void:
	for rune in Rune.all():
		var profile := Rune.profile_for(rune.id, Essence.VACUUM)
		assert_eq(profile.motion, Rune.MOTION_INTAKE,
			"auf einem Vakuum-Würfel saugt jede Rune, egal welcher")
	assert_eq(Rune.profile_for(Rune.AFTERGLOW, Essence.NEON).motion, Rune.MOTION_ECHO,
		"ohne Vakuum bleibt das eigene Profil")
