extends GutTest
## Die BAUTEILE der Gleichung: Wanne, Marke, Abtastring - und daß nur der Wechsel baut.

const CELL := 60.0

var dress: DieViewDress

func before_each() -> void:
	dress = DieViewDress.new()
	add_child_autofree(dress)

func _world(p: Vector2) -> Vector3:
	return Vector3(-p.y * 0.03, 0.0, p.x * 0.03)

func _spec(seated: bool) -> Dictionary:
	var net := Rect2(1000, 600, 300, 230)
	var chips: Array[Rect2] = []
	for face in 6:
		chips.append(Rect2(Vector2(1410, 600) + DieNetView.cell_position(face, CELL),
			Vector2.ONE * CELL))
	var seats: Array[Rect2] = []
	var tints: Array[Color] = []
	for i in 6:
		seats.append(Rect2(760 + i * 15, 610, 10, 44))
		tints.append(Color(0, 1, 0, 1) if i == 0 else Color(0, 0, 0, 0))
	var entries: Array = []
	var feeds: Array = []
	for lane in 4:
		entries.append(PackedVector2Array([Vector2(1380, 700 + lane * 8), Vector2(1400, 700 + lane * 8)]))
		feeds.append(PackedVector2Array([Vector2(1130 + lane * 8, 920), Vector2(1130 + lane * 8, 830)]))
	return {"up": Rect2(1000, 920, 300, 230), "chips": chips, "seats": seats, "tints": tints,
		"mouth": Rect2(1000, 380, 300, 210), "net": net,
		"preview": Rect2(400, 380, 300, 230),
		"entries": entries, "feeds": feeds, "pitch": 8.0,
		"bus_tints": [Color(0, 1, 0, 1), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)],
		"signs": [Rect2(1000, 850, 300, 60)],
		"stamp": Rect2(1500, 450, 100, 60), "cell": CELL, "seated": seated,
		"ring_on": seated, "ring": Vector3(-14.0, 1.5, 34.0), "edge": 1.4}

func test_the_tray_hangs_under_the_chamber_as_wide_as_the_net() -> void:
	var tray := DieViewDress.tray_rect(Rect2(1000, 380, 300, 210), Rect2(1000, 600, 300, 230))
	assert_eq(tray, Rect2(1000, 590, 300, 240))

func test_only_a_change_rebuilds() -> void:
	dress.seat(_spec(false), _world, null)
	var parts := dress.get_node("Teile")
	assert_gt(dress.part_count(), 12, "Schilder, Kragen, Wanne, Koppler stehen")
	dress.seat(_spec(false), _world, null)
	assert_same(dress.get_node("Teile"), parts, "gleiche Meldung baut nicht neu")
	dress.seat(_spec(true), _world, null)
	assert_ne(dress.get_node("Teile"), parts, "der Wechsel baut")

func test_the_ring_stands_only_around_a_seated_die() -> void:
	dress.seat(_spec(false), _world, null)
	assert_null(dress.get_node_or_null("Podestteile/Abtastring"))
	dress.seat(_spec(true), _world, null)
	var ring := dress.get_node_or_null("Podestteile/Abtastring") as Node3D
	assert_not_null(ring)
	assert_almost_eq(ring.position.y, 1.5, 0.001, "auf Würfelhöhe")

func test_the_up_mark_sits_on_its_cell_in_the_tray() -> void:
	dress.seat(_spec(true), _world, null)
	var mark := dress.get_node("Podestteile/ObenMarke") as Node3D
	assert_false(mark.visible, "ohne Meldung keine Marke")
	dress.mark_up(3)
	assert_true(mark.visible)
	assert_almost_eq(mark.position.y, 0.0, 0.001, "ORIGINAL liegt auf dem Tisch")
	assert_null(dress.get_node_or_null("Podestteile/Wannenboden"), "keine Wanne mehr")
	var first := mark.position
	dress.mark_up(0)
	assert_ne(mark.position, first, "sie wandert mit der Seite")
	dress.seat(_spec(false), _world, null)
	dress.seat(_spec(true), _world, null)
	assert_true((dress.get_node("Podestteile/ObenMarke") as Node3D).visible, "ein Neubau behält sie")
	dress.mark_up(-1)
	assert_false((dress.get_node("Podestteile/ObenMarke") as Node3D).visible)

func test_the_guard_closes_once_the_press_is_spent() -> void:
	var spec := _spec(true)
	dress.seat(spec, _world, null)
	var guard := dress.get_node("Schalter")
	assert_false(dress.cover_closed(), "frei: die Klappe steht offen")
	assert_lt((dress.get_node("Schalter/Klappe") as Node3D).rotation.z, -1.0)
	spec["spent"] = true
	dress.seat(spec, _world, null)
	assert_true(dress.cover_closed())
	assert_same(dress.get_node("Schalter"), guard, "der Schalter überlebt den Neubau der Teile")

## UPGRADES ist ein Chip mit Fenstern und bleibt stehen; ERGEBNIS ist gestorben.
func test_upgrades_is_a_chip_and_result_is_gone() -> void:
	dress.seat(_spec(false), _world, null)
	assert_not_null(dress.get_node_or_null("Teile/UpgradesChip/Gehaeuse"))
	assert_not_null(dress.get_node_or_null("Teile/UpgradesChip/Beine"))
	assert_null(dress.get_node_or_null("Teile/ErgebnisChip"), "kein ERGEBNIS-Chip mehr")
	assert_null(dress.get_node_or_null("Zonenteile"), "UPGRADES fährt nicht mit der Zone")

## Die Die-Views tragen keine Schilder mehr (Spieler-Wunsch 2026-11-25).
func test_the_views_carry_no_plates() -> void:
	dress.seat(_spec(false), _world, null)
	assert_null(dress.get_node_or_null("Podestteile/Schild"))
	assert_null(dress.get_node_or_null("Teile/VorschauSchild"))
	for node in dress.find_children("*", "Label3D", true, false):
		assert_false((node as Label3D).text in ["UPGRADES", "ORIGINAL", "ERGEBNIS", "VORSCHAU"],
			"kein Schild %s" % (node as Label3D).text)

## Der Umschalter kennt zwei Zustände: AN leuchtet er, AUS ist er grau; unter dem Zeiger
## hebt er sich.
func test_the_coupler_lights_up_when_on() -> void:
	dress.seat(_spec(false), _world, null)
	dress.set_coupler(true, false)
	var lit := dress.coupler_light().get_luminance()
	dress.set_coupler(false, false)
	assert_gt(lit, dress.coupler_light().get_luminance() + 0.3, "AN leuchtet, AUS ist grau")
	assert_false(dress.coupler_lifted())
	dress.set_coupler(false, true)
	assert_true(dress.coupler_lifted(), "unter dem Zeiger hebt er sich")
	dress.seat(_spec(true), _world, null)
	assert_true(dress.coupler_lifted(), "ein Neubau behält den Zustand")
	assert_false(dress.coupler_on())

## Der Umschalter ist ein Chip mittig im "+"-Feld und trägt nur das "+".
func test_the_coupler_is_a_plus_chip() -> void:
	dress.seat(_spec(false), _world, null)
	var case := dress.get_node("Teile/Koppler/Gehaeuse") as MeshInstance3D
	var center := _world(Rect2(1000, 850, 300, 60).get_center())
	assert_almost_eq(case.position.z, center.z, 0.001)
	assert_lt((case.mesh as BoxMesh).size.z, 300.0 * 0.03 * 0.6, "ein Chip, kein Balken")
	var labels := dress.get_node("Teile/Koppler").find_children("*", "Label3D", true, false)
	assert_eq(labels.size(), 1)
	assert_eq((labels[0] as Label3D).text, "+")

## Die VORSCHAU ist ein Chip; sie bleibt bei einer Öffnung stehen.
func test_the_preview_is_a_chip() -> void:
	dress.seat(_spec(false), _world, null)
	assert_not_null(dress.get_node_or_null("Teile/VorschauChip/Gehaeuse"))
	dress.set_zone_shown(false)
	assert_true((dress.get_node("Teile") as Node3D).visible, "die Vorschau bleibt")

## Die Busse sind Körper; eine Spur leuchtet in ihrer Sortenfarbe. Das letzte Stück des
## Ausgangs-Busses fährt mit dem Podest.
func test_the_buses_are_bodies() -> void:
	dress.seat(_spec(false), _world, null)
	assert_not_null(dress.get_node_or_null("Teile/EingangsBus"))
	assert_not_null(dress.get_node_or_null("Teile/AusgangsBus"))
	assert_not_null(dress.get_node_or_null("Podestteile/AusgangsBusOben"))
	var lit := false
	for child in dress.get_node("Teile/EingangsBus").get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and mesh.material_override is StandardMaterial3D 				and (mesh.material_override as StandardMaterial3D).albedo_color == Color(0, 1, 0, 1):
			lit = true
	assert_true(lit, "die gesteckte Sorte leuchtet")

## Während einer Paket-Öffnung fahren Podest und der Schalter des Prägens mit der Zone.
func test_the_podium_leaves_for_an_opening() -> void:
	dress.seat(_spec(true), _world, null)
	assert_eq(dress.zone_bodies().size(), 2, "Podest und Schalter")
	dress.set_zone_shown(false)
	for body in dress.zone_bodies():
		assert_false(body.visible)
	assert_true((dress.get_node("Teile") as Node3D).visible, "Vorschau, UPGRADES, Umschalter bleiben")
	dress.seat(_spec(false), _world, null)
	assert_false((dress.get_node("Schalter") as Node3D).visible, "ein Neubau bleibt fort")
	assert_false((dress.get_node("Podestteile") as Node3D).visible)
	dress.set_zone_shown(true)
	assert_true((dress.get_node("Schalter") as Node3D).visible)
	assert_true((dress.get_node("Podestteile") as Node3D).visible)

func test_a_cut_plate_leaves_its_windows_open() -> void:
	var rect := Rect2(0, 0, 100, 60)
	var holes: Array[Rect2] = [Rect2(10, 10, 20, 20), Rect2(50, 10, 20, 20), Rect2(30, 35, 20, 20)]
	var area := 0.0
	for piece in DieViewDress.cut_plate(rect, holes):
		area += piece.get_area()
		for hole in holes:
			assert_false(piece.intersects(hole), "kein Stück deckt ein Fenster")
	assert_almost_eq(area, 100.0 * 60.0 - 3.0 * 400.0, 0.01)
