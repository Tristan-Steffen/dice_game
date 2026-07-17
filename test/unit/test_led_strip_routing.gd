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
