extends GutTest
## Der Dauerwächter der Runenzeichen. Zwei Regeln, die jedes künftige Muster
## einhalten muss: es hält die Ziffer frei, und es trägt zu jeder Linie ein
## Gewicht. Beides ist billig zu prüfen und teuer zu übersehen - eine Figur, die
## durch die Ziffer läuft, macht den Würfel unlesbar, und das fällt headless
## sonst niemandem auf.

## Stützstellen JE SEGMENT. Nur die Eckpunkte zu prüfen reicht nicht: zwei freie
## Endpunkte können die Sperr-Ellipse trotzdem als Sehne durchschneiden.
const SAMPLES := 32

func test_no_crack_segment_cuts_the_glyph_keepout() -> void:
	for pattern in Rune.all_glyphs():
		var lines := Rune.glyph_lines(pattern)
		assert_false(lines.is_empty(), "%s hat überhaupt eine Figur" % pattern)
		for line_index in lines.size():
			var line: PackedVector2Array = lines[line_index]
			for i in range(line.size() - 1):
				var worst := _worst_clearance(line[i], line[i + 1])
				assert_gt(worst, 1.0,
					"%s Linie %d Segment %d schneidet die Ziffern-Sperrzone (%.3f)"
						% [pattern, line_index, i, worst])

## Schlechtester Ellipsen-Wert entlang eines Segments (kleinster = engster).
func _worst_clearance(from: Vector2, to: Vector2) -> float:
	var worst := INF
	for step in SAMPLES + 1:
		var point := from.lerp(to, float(step) / float(SAMPLES))
		worst = minf(worst, Rune.digit_clearance(point))
	return worst

func test_every_polyline_carries_a_weight() -> void:
	for pattern in Rune.all_glyphs():
		assert_eq(Rune.glyph_weights(pattern).size(), Rune.glyph_lines(pattern).size(),
			"%s: je Linie genau ein Gewicht" % pattern)

func test_branch_weights_stay_below_the_trunk() -> void:
	# Eine Gabel ist dünner und kürzer als ihr Stamm - das ist das Kintsugi-Merkmal.
	for pattern in Rune.all_glyphs():
		var weights := Rune.glyph_weights(pattern)
		var heaviest := 0.0
		for weight in weights:
			assert_between(weight, 0.3, 1.0, "%s: Gewichte bleiben im Rahmen" % pattern)
			heaviest = maxf(heaviest, weight)
		assert_almost_eq(heaviest, 1.0, 0.001, "%s: mindestens ein Hauptbruch" % pattern)

func test_every_line_runs_to_a_border() -> void:
	# Rand zu Rand ist die Regel: was in der Fläche anfängt UND aufhört, ist ein
	# Kratzer. Ausgenommen sind Linien, die an einer anderen Linie ansetzen
	# (Ausläufer, Gabeln) - die erben deren Rand.
	for pattern in Rune.all_glyphs():
		var lines := Rune.glyph_lines(pattern)
		for line_index in lines.size():
			var line: PackedVector2Array = lines[line_index]
			var touches := _at_border(line[0]) or _at_border(line[line.size() - 1])
			if not touches:
				touches = _joins_another(lines, line_index)
			assert_true(touches,
				"%s Linie %d hängt frei in der Fläche" % [pattern, line_index])

func _at_border(point: Vector2) -> bool:
	return point.x <= 0.06 or point.x >= 0.94 or point.y <= 0.06 or point.y >= 0.94

func _joins_another(lines: Array[PackedVector2Array], line_index: int) -> bool:
	var line: PackedVector2Array = lines[line_index]
	for other_index in lines.size():
		if other_index == line_index:
			continue
		for point in lines[other_index]:
			if point.distance_to(line[0]) < 0.01 or point.distance_to(line[line.size() - 1]) < 0.01:
				return true
	return false

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
