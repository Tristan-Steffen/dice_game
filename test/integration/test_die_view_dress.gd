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
		chips.append(Rect2(Vector2(600, 600) + DieNetView.cell_position(face, CELL),
			Vector2.ONE * CELL))
	var seats: Array[Rect2] = []
	var tints: Array[Color] = []
	for i in 6:
		seats.append(Rect2(760 + i * 20, 610, 14, 44))
		tints.append(Color(0, 1, 0, 1) if i == 0 else Color(0, 0, 0, 0))
	return {"up": Rect2(590, 600, 300, 230), "chips": chips, "seats": seats, "tints": tints,
		"mouth": Rect2(1000, 380, 300, 210), "net": net, "result": Rect2(1400, 600, 300, 230),
		"signs": [Rect2(900, 600, 90, 230), Rect2(1310, 600, 80, 230)],
		"stamp": Rect2(1500, 450, 100, 60), "cell": CELL, "live": seated, "seated": seated,
		"ring_on": seated, "ring": Vector3(-14.0, 1.5, 34.0), "edge": 1.4}

func test_the_tray_hangs_under_the_chamber_as_wide_as_the_net() -> void:
	var tray := DieViewDress.tray_rect(Rect2(1000, 380, 300, 210), Rect2(1000, 600, 300, 230))
	assert_eq(tray, Rect2(1000, 590, 300, 240))

func test_only_a_change_rebuilds() -> void:
	dress.seat(_spec(false), _world, null)
	var parts := dress.get_node("Teile")
	assert_gt(dress.part_count(), 20, "Schilder, Kragen, Wanne, Koppler stehen")
	dress.seat(_spec(false), _world, null)
	assert_same(dress.get_node("Teile"), parts, "gleiche Meldung baut nicht neu")
	dress.seat(_spec(true), _world, null)
	assert_ne(dress.get_node("Teile"), parts, "der Wechsel baut")

func test_the_ring_stands_only_around_a_seated_die() -> void:
	dress.seat(_spec(false), _world, null)
	assert_null(dress.get_node_or_null("Teile/Abtastring"))
	dress.seat(_spec(true), _world, null)
	var ring := dress.get_node_or_null("Teile/Abtastring") as Node3D
	assert_not_null(ring)
	assert_almost_eq(ring.position.y, 1.5, 0.001, "auf Würfelhöhe")

func test_the_up_mark_sits_on_its_cell_in_the_tray() -> void:
	dress.seat(_spec(true), _world, null)
	var mark := dress.get_node("Teile/ObenMarke") as Node3D
	assert_false(mark.visible, "ohne Meldung keine Marke")
	dress.mark_up(3)
	assert_true(mark.visible)
	assert_almost_eq(mark.position.y, -DieViewDress.TRAY_DROP, 0.001, "auf dem Wannenboden")
	var first := mark.position
	dress.mark_up(0)
	assert_ne(mark.position, first, "sie wandert mit der Seite")
	dress.seat(_spec(false), _world, null)
	dress.seat(_spec(true), _world, null)
	assert_true((dress.get_node("Teile/ObenMarke") as Node3D).visible, "ein Neubau behält sie")
	dress.mark_up(-1)
	assert_false((dress.get_node("Teile/ObenMarke") as Node3D).visible)
