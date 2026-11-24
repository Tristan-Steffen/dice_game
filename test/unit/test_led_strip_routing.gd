extends GutTest
## Tier-1-Tests der LED-Leiten-Führung (LedStripView.link_edges): reine Geometrie
## der Stützpunkte, richtungsagnostisch (Korridor über/unter der Quelle), plus die
## Invarianz des Bequem-Wrappers link_from_hub_top.

func _strip() -> LedStripView:
	return LedStripView.new()

func test_link_edges_builds_four_waypoints_upward():
	# Quelle unter Ziel: Austritt oben, Korridor darüber, Eintritt an Ziel-Unterkante.
	var strip := _strip()
	strip.link_edges(1000.0, 200.0, 800.0, 500.0, 900.0, 10.0)
	assert_eq(strip.strip_path, PackedVector2Array([
		Vector2(200, 1000), Vector2(200, 900), Vector2(500, 900), Vector2(500, 800)]))
	strip.free()

func test_link_edges_builds_four_waypoints_downward():
	# Quelle über Ziel (Charm-Dock -> Score): Austritt unten, Korridor darunter.
	var strip := _strip()
	strip.link_edges(200.0, 300.0, 400.0, 600.0, 300.0, 10.0)
	assert_eq(strip.strip_path, PackedVector2Array([
		Vector2(300, 200), Vector2(300, 300), Vector2(600, 300), Vector2(600, 400)]))
	strip.free()

func test_link_edges_resets_branch():
	var strip := _strip()
	strip.branch_path = PackedVector2Array([Vector2(1, 1), Vector2(2, 2)])
	strip.link_edges(1000.0, 200.0, 800.0, 500.0, 900.0, 10.0)
	assert_eq(strip.branch_path.size(), 0, "neue Führung löscht den Abzweig")
	strip.free()

func test_link_from_hub_top_matches_edges():
	# Wrapper = Hub-Oberkante -> Ziel-Unterkante, Eintritt mittig.
	var strip := _strip()
	var hub := Rect2(Vector2(100, 1000), Vector2(400, 200))       # Oberkante y=1000
	var target := Rect2(Vector2(300, 400), Vector2(200, 300))     # Unterkante y=700, Mitte x=400
	strip.link_from_hub_top(hub, target, 12.0, 250.0, 850.0)
	assert_eq(strip.strip_path, PackedVector2Array([
		Vector2(250, 1000), Vector2(250, 850), Vector2(400, 850), Vector2(400, 700)]))
	strip.free()

func test_every_incoming_track_sends_a_shoot_into_every_rail_track() -> void:
	var pitch := PcbDeckView.PITCH
	var knot := {"at": Vector2(100, 200), "dir": Vector2(0, -1), "reach": 60.0, "branch": 3, "rail": 3}
	var lines := LedStripView.knot_lines(knot)
	var rail_ys := [200.0 - pitch, 200.0, 200.0 + pitch]
	var shoots: Array = []
	for line: PackedVector2Array in lines:
		if line.size() > 2:
			shoots.append(line)
	# Außen je ein Trieb je Schienenzug, die Mitte nach beiden Seiten.
	assert_eq(shoots.size(), 3 + 2 * 3 + 3, "zwölf Triebe")
	for x: float in [100.0 - pitch, 100.0, 100.0 + pitch]:
		for y: float in rail_ys:
			var hit := false
			for shoot: PackedVector2Array in shoots:
				var start := shoot[0]
				var tail := shoot[shoot.size() - 1]
				if absf(start.x - x) < 0.01 and absf(tail.y - y) < 0.01:
					hit = true
			assert_true(hit, "Zug bei x %.1f trifft den Schienenzug bei y %.1f" % [x, y])

func test_a_knot_is_mirror_symmetric_about_its_axis() -> void:
	var knot := {"at": Vector2(100, 200), "dir": Vector2(0, 1), "reach": 50.0, "branch": 2, "rail": 2}
	var ends: Array[Vector2] = []
	for line: PackedVector2Array in LedStripView.knot_lines(knot):
		ends.append(line[line.size() - 1])
	for at in ends:
		var mirrored := Vector2(200.0 - at.x, at.y)
		var found := false
		for other in ends:
			if other.distance_to(mirrored) < 0.01:
				found = true
		assert_true(found, "Spiegelbild von %s" % at)
