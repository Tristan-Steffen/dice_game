extends GutTest
## Der Dauerwächter der Runenzeichen. Die Platzierung trägt jetzt die Regel, die
## früher die Figur trug: ein Riss lief von Rand zu Rand und hielt sich damit von
## selbst von der Ziffer frei, ein Zeichen ist kompakt und tut das nicht. Also
## prüfen wir beides getrennt - die ZELLE meidet die Ziffer, die FIGUR bleibt in
## ihrer Zelle. Billig zu prüfen und teuer zu übersehen: eine Figur über der
## Ziffer macht den Würfel unlesbar, und das fällt headless sonst niemandem auf.

## Stützstellen JE SEGMENT. Nur die Eckpunkte zu prüfen reicht nicht: zwei freie
## Endpunkte können die Sperr-Ellipse trotzdem als Sehne durchschneiden.
const SAMPLES := 32
## float32-Toleranz der PackedVector2Array-Speicherung.
const EPS := 0.0001

func test_every_anchor_cell_clears_the_digit_keepout() -> void:
	# Geprüft wird der ganze Zellrand: die Ellipse ist konvex, also genügt es,
	# dass keine Kante sie schneidet.
	for slot in Rune.ANCHOR_CELLS.size():
		var cell := Rune.anchor_cell(slot)
		var corners := [
			Vector2(cell.x, cell.y), Vector2(cell.z, cell.y),
			Vector2(cell.z, cell.w), Vector2(cell.x, cell.w),
		]
		for i in corners.size():
			var worst := _worst_clearance(corners[i], corners[(i + 1) % corners.size()])
			assert_gt(worst, 1.0,
				"Ankerzelle %d schneidet die Ziffern-Sperrzone (%.3f)" % [slot, worst])

func test_the_anchor_cells_never_overlap() -> void:
	# Zwei Zeichen einer Vakuum-Seite müssen getrennte Schultern nehmen.
	for a in Rune.ANCHOR_CELLS.size():
		for b in range(a + 1, Rune.ANCHOR_CELLS.size()):
			var one := Rune.anchor_cell(a)
			var two := Rune.anchor_cell(b)
			var overlaps := one.x < two.z and two.x < one.z and one.y < two.w and two.y < one.w
			assert_false(overlaps, "Ankerzellen %d und %d überlappen" % [a, b])

func test_every_glyph_stays_inside_its_cell() -> void:
	# Der Rand trägt den Hof (RuneTextures.FIELD): läuft die Figur bis an die
	# Zellkante, schneidet der Shader ihren Ausbruch als Rechteck ab.
	for glyph in Rune.all_glyphs():
		var lines := Rune.glyph_lines(glyph)
		assert_false(lines.is_empty(), "%s hat überhaupt eine Figur" % glyph)
		for line_index in lines.size():
			var line: PackedVector2Array = lines[line_index]
			for point in line:
				# EPS: PackedVector2Array speichert float32, ein glattes 0.8 landet
				# knapp darüber.
				assert_between(point.x, Rune.GLYPH_MARGIN - EPS, 1.0 - Rune.GLYPH_MARGIN + EPS,
					"%s Linie %d: x verlässt den Zellrand" % [glyph, line_index])
				assert_between(point.y, Rune.GLYPH_MARGIN - EPS, 1.0 - Rune.GLYPH_MARGIN + EPS,
					"%s Linie %d: y verlässt den Zellrand" % [glyph, line_index])

func test_a_glyph_in_its_cell_never_touches_the_digit() -> void:
	# Die eigentliche Zusage, beide Regeln zusammengenommen: die FERTIG platzierte
	# Figur liegt außerhalb der Ziffern-Sperrzone, auf jedem Platz.
	for slot in Rune.ANCHOR_CELLS.size():
		for glyph in Rune.all_glyphs():
			for line in Rune.glyph_lines(glyph):
				for i in range(line.size() - 1):
					var worst := _worst_clearance(Rune.cell_to_face(line[i], slot),
						Rune.cell_to_face(line[i + 1], slot))
					assert_gt(worst, 1.0,
						"%s auf Platz %d schneidet die Ziffer (%.3f)" % [glyph, slot, worst])

## Schlechtester Ellipsen-Wert entlang eines Segments (kleinster = engster).
func _worst_clearance(from: Vector2, to: Vector2) -> float:
	var worst := INF
	for step in SAMPLES + 1:
		var point := from.lerp(to, float(step) / float(SAMPLES))
		worst = minf(worst, Rune.digit_clearance(point))
	return worst

func test_every_polyline_carries_a_weight() -> void:
	for glyph in Rune.all_glyphs():
		assert_eq(Rune.glyph_weights(glyph).size(), Rune.glyph_lines(glyph).size(),
			"%s: je Linie genau ein Gewicht" % glyph)

func test_side_strokes_stay_below_the_main_stroke() -> void:
	for glyph in Rune.all_glyphs():
		var weights := Rune.glyph_weights(glyph)
		var heaviest := 0.0
		for weight in weights:
			assert_between(weight, 0.3, 1.0, "%s: Gewichte bleiben im Rahmen" % glyph)
			heaviest = maxf(heaviest, weight)
		assert_almost_eq(heaviest, 1.0, 0.001, "%s: mindestens ein Hauptstrich" % glyph)

func test_every_rune_owns_exactly_one_glyph() -> void:
	# Je Wirkung eine erkennbare Idee - zwei Runen mit derselben Figur wären
	# am Würfel nicht auseinanderzuhalten.
	var seen := {}
	for rune in Rune.all():
		assert_false(seen.has(rune.glyph), "%s teilt sein Zeichen" % rune.id)
		seen[rune.glyph] = true
		assert_true(Rune.all_glyphs().has(rune.glyph), "%s: Zeichen ist registriert" % rune.id)
	assert_eq(seen.size(), Rune.all_glyphs().size(), "kein Zeichen ohne Rune")

# --- Die Ruhe-Regel (Schritt 13 der Umsetzungsliste) --------------------------------

func test_no_idle_profile_reaches_the_bloom_threshold() -> void:
	# Der mechanische Grund, warum sechs beschriftete Würfel keine Disco werden.
	for rune in Rune.all():
		assert_lt(rune.idle_high, Rune.IDLE_CEILING,
			"%s glüht in Ruhe bis an die Bloom-Schwelle" % rune.display_name)
		assert_lt(rune.idle_low, rune.idle_high, "%s: Boden unter Spitze" % rune.display_name)
		assert_gt(rune.idle_low, 0.0, "%s: die Naht ist nie ganz aus" % rune.display_name)

func test_every_flare_outshines_its_own_idle() -> void:
	for rune in Rune.all():
		assert_gt(rune.flare_peak, Rune.IDLE_CEILING,
			"%s: der Ausbruch SOLL bloomen" % rune.display_name)
		assert_gt(rune.halo_flare, 1.0,
			"%s: der Ausbruch liest über Breite, nicht über Helligkeit" % rune.display_name)

func test_the_seam_color_is_normalized() -> void:
	# "energy" heißt in jedem Profil dasselbe: die hellste Komponente.
	for rune in Rune.all():
		var seam := rune.normalized_seam()
		assert_almost_eq(maxf(seam.r, maxf(seam.g, seam.b)), 1.0, 0.001,
			"%s: Naht-Farbe auf max == 1 normiert" % rune.display_name)

func test_spark_flight_normalizes_to_the_charge_cyan() -> void:
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
