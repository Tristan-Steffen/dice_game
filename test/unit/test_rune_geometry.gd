extends GutTest
## Der Dauerwächter der Runenzeichen. Seit den GRUNDFORMEN (2026-10-24) ist jede
## Figur EINE geschlossene, zur Hochachse symmetrische Grundform um die Seitenmitte;
## sie weicht der Ziffer nicht mehr aus, sondern läuft hinter ihr durch. Was hier
## geprüft wird, ist darum die FORM selbst - billig zu prüfen und teuer zu übersehen,
## denn eine schiefe oder offene Figur fällt headless sonst niemandem auf.

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

func test_every_glyph_is_one_closed_figure() -> void:
	# Geschlossen heißt: die Bogenlänge läuft im Kreis, und keine Bewegung zeigt
	# ein freies Ende. Mehr als eine Linie wäre ein zweites Zeichen.
	for glyph in Rune.all_glyphs():
		var lines := Rune.glyph_lines(glyph)
		assert_eq(lines.size(), 1, "%s ist EINE Figur" % glyph)
		var line: PackedVector2Array = lines[0]
		assert_gt(line.size(), 3, "%s hat eine Figur, keinen Strich" % glyph)
		assert_lt(line[0].distance_to(line[line.size() - 1]), SAME_POINT,
			"%s schließt sich" % glyph)

func test_every_glyph_is_symmetric_about_the_upright_axis() -> void:
	# Eine Grundform liest auf Grubendistanz als SILHOUETTE - eine schiefe Figur
	# läse dort als Fleck.
	for glyph in Rune.all_glyphs():
		var line: PackedVector2Array = Rune.glyph_lines(glyph)[0]
		for point in line:
			var mirrored := Vector2(1.0 - point.x, point.y)
			var nearest := INF
			for other in line:
				nearest = minf(nearest, other.distance_to(mirrored))
			assert_lt(nearest, SAME_POINT,
				"%s: %v hat kein Gegenstück an der Hochachse" % [glyph, point])

func test_every_glyph_reaches_the_authored_radius() -> void:
	# EINE Größe je Ding: eine Grundform, die kleiner ausfällt als ihre Nachbarin,
	# liest als zweite Größe statt als zweites Zeichen. Nach OBEN hält der Seitenrand
	# (test_every_glyph_stays_inside_the_face) - die Ecken eines Quadrats reichen
	# weiter als sein Radius, und das sollen sie.
	for glyph in Rune.all_glyphs():
		var reach := 0.0
		for point in Rune.glyph_lines(glyph)[0]:
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
			for point in Rune.glyph_lines(glyph)[0]:
				var seat := Rune.place(point, slot)
				assert_between(seat.x, Rune.GLYPH_MARGIN - EPS, 1.0 - Rune.GLYPH_MARGIN + EPS,
					"%s auf Platz %d verlässt den Seitenrand (x)" % [glyph, slot])
				assert_between(seat.y, Rune.GLYPH_MARGIN - EPS, 1.0 - Rune.GLYPH_MARGIN + EPS,
					"%s auf Platz %d verlässt den Seitenrand (y)" % [glyph, slot])

func test_every_polyline_carries_a_weight() -> void:
	for glyph in Rune.all_glyphs():
		assert_eq(Rune.glyph_weights(glyph).size(), Rune.glyph_lines(glyph).size(),
			"%s: je Linie genau ein Gewicht" % glyph)

func test_every_glyph_is_a_single_full_stroke() -> void:
	# Ein Beistrich wäre ein zweites Zeichen - die Grundform trägt genau einen.
	for glyph in Rune.all_glyphs():
		var weights := Rune.glyph_weights(glyph)
		assert_eq(weights.size(), 1, "%s: EIN Strich" % glyph)
		assert_almost_eq(weights[0], 1.0, 0.001, "%s: in voller Stärke" % glyph)

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
