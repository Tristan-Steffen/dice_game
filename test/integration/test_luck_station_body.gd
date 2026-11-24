extends GutTest
## Der Körper der GLÜCKS-STATION: der Schreiber schreibt nur den Wechsel, leuchtende Teile
## zählen genau den Stand, in Ruhe ragt nichts über REST_TOP, und der Hebel folgt dem Würfel.

const STATE := {"luck": 25, "prev": 21, "next": 28, "expected": 2.0, "free_bonus": 0, "keeps": 0}

func _body() -> LuckStationBody:
	var view := LuckStationView.new()
	view.size = Vector2(233.0, 570.0)
	var ppw := 37.5
	var center := view.size * 0.5
	var local := func(px: Rect2) -> Rect2:
		return Rect2((px.position - center) / ppw, px.size / ppw)
	var parts := {}
	for key: String in LuckStationView.PARTS:
		parts[key] = local.call(view.part_rect(key))
	var cells: Array[Rect2] = []
	for face in 6:
		cells.append(local.call(view.cell_rect(face)))
	parts["cells"] = cells
	view.free()
	var body := LuckStationBody.new()
	add_child_autofree(body)
	body.setup(parts)
	return body

func test_the_writer_is_idempotent() -> void:
	var body := _body()
	body.set_state([3, 1, 2, 2, 1, 3], 3, STATE)
	var writes := body.writes()
	body.set_state([3, 1, 2, 2, 1, 3], 3, STATE)
	assert_eq(body.writes(), writes, "derselbe Stand schreibt nicht")
	body.set_state([3, 1, 2, 2, 1, 4], 3, STATE)
	assert_eq(body.writes(), writes + 1, "der Wechsel schreibt")

func test_lit_parts_count_the_state() -> void:
	var body := _body()
	body.set_state([3, 1, 2, 2, 1, 3], 3, STATE)
	assert_eq(body.lit_pip_count(), 12, "je Auge eine Leuchte")
	assert_true(body.rim_lit(3), "die letzte Seite ist gold gesäumt")
	for face in [0, 1, 2, 4, 5]:
		assert_false(body.rim_lit(face))
	assert_eq(body.expected_shown(), "Ø 2,0")
	assert_almost_eq(body.bar_share(), 4.0 / 7.0, 0.001, "der Balken steht zwischen 21 und 28 bei 25")
	assert_eq(body.gauge_number_shown(), "GLÜCK 25 / 28")
	assert_eq(body.gauge_shown(), "BEI 28 KOMMT EIN AUGE DAZU")
	assert_eq(body.bonus_shown(), "", "ohne Bonus steht nichts da")
	body.set_state([6, 6, 6, 6, 6, 6], -1, {"luck": 470, "prev": 465, "next": -1, "free_bonus": 1, "keeps": 0})
	assert_eq(body.lit_pip_count(), 36)
	assert_almost_eq(body.bar_share(), 1.0, 0.001, "alle Seiten voll: der Balken steht ganz")
	assert_eq(body.gauge_shown(), "ALLE SEITEN VOLL")
	assert_eq(body.bonus_shown(), "+1 WAHL BEIM NÄCHSTEN PAKET")
	body.set_state([1, 1, 1, 1, 1, 1], -1, {"luck": 0, "prev": 0, "next": 1, "free_bonus": 1, "keeps": 2})
	assert_eq(body.lit_pip_count(), 6)
	assert_almost_eq(body.bar_share(), 0.0, 0.001)
	assert_eq(body.bonus_shown(), "NOCH 2 MODULE EINBAUEN", "offene Einbauten gehen der Freien Hand vor")

func test_nothing_rises_above_the_rest_height() -> void:
	var body := _body()
	body.set_state([6, 6, 6, 6, 6, 6], 0, {"luck": 470, "prev": 465, "next": -1, "free_bonus": 1, "keeps": 3})
	var inverse := body.global_transform.affine_inverse()
	for node in body.find_children("*", "GeometryInstance3D", true, false):
		var shape := node as GeometryInstance3D
		if shape is Label3D or not shape.is_visible_in_tree():
			continue
		var box := (inverse * shape.global_transform) * shape.get_aabb()
		assert_lte(box.end.y, LuckStationBody.REST_TOP + 0.001, "%s bleibt flach" % shape.name)

func test_the_lever_follows_home_and_away() -> void:
	var body := _body()
	assert_false(body.lever_open())
	assert_almost_eq(body.lever_angle(), 0.0, 0.0001)
	body.set_lever_open(true)
	assert_true(body.lever_open(), "Endzustand zuerst")
	await wait_seconds(LuckStationBody.LEVER_TIME + 0.15)
	assert_almost_eq(body.lever_angle(), LuckStationBody.LEVER_OPEN, 0.001, "er steht auf")
	body.set_lever_open(false)
	body.settle_hard()
	assert_almost_eq(body.lever_angle(), 0.0, 0.0001, "der harte Weg legt ihn an die Flanke")
