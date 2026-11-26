extends GutTest
## Das Fenster des LABORS (LaborView): Teile im Grundriß, Felder je Zustand, Status-Zeile,
## Knöpfe und Hinweise - alles ohne GameRun.

var view: LaborView

func before_each() -> void:
	view = LaborView.new()
	add_child_autofree(view)
	view.size = LaborView.UNITS * 37.5

func _state(phase: String, die_value := 0, rounds_left := 0, extra := {}) -> Dictionary:
	var state := {"open": true, "station": "karten", "phase": phase, "die_value": die_value,
		"rounds_left": rounds_left, "price": 2, "affordable": true, "collectable": phase == "fertig"}
	state.merge(extra, true)
	return state

func test_every_part_lies_inside_the_footprint() -> void:
	var half := LaborView.UNITS * 0.5
	for key: String in LaborView.PARTS:
		var part: Rect2 = LaborView.PARTS[key]
		assert_lte(absf(part.position.x) + part.size.x * 0.5, half.x + 0.001, "%s quer im Grundriß" % key)
		assert_lte(absf(part.position.y) + part.size.y * 0.5, half.y + 0.001, "%s längs im Grundriß" % key)
	for key: String in ["dish", "chamber", "name", "start", "status"]:
		assert_true(LaborView.PARTS.has(key), key)
	for i in LaborView.FIELDS:
		assert_true(LaborView.PARTS.has("field%d" % i))

func test_part_rect_scales_with_the_unit() -> void:
	assert_almost_eq(view.unit(), 37.5, 0.001)
	var rect := view.part_rect("start")
	assert_almost_eq(rect.size.x, 6.4 * 37.5, 0.01)
	assert_almost_eq(rect.get_center().x, view.size.x * 0.5 + 8.9 * 37.5, 0.01)

## Die Felder liegen im Feldgrund, berühren die Kammer nicht und stehen je Flanke zu dritt.
func test_fields_stay_inside_the_dish_and_off_the_chamber() -> void:
	for i in LaborView.FIELDS:
		for p in LaborView.field_outline(i):
			var d := p - LaborView.DISH_CENTER
			assert_gt(d.length(), LaborView.CHAMBER_RADIUS, "Feld %d berührt die Kammer nicht" % i)
			assert_lte(d.length(), LaborView.ground_reach(rad_to_deg(d.angle())) + 0.001,
				"Feld %d bleibt im Feldgrund" % i)
		var mid := LaborView.field_angles(i)
		var right := cos(deg_to_rad((mid.x + mid.y) * 0.5)) > 0.0
		assert_eq(right, i < 3, "Feld %d auf seiner Flanke" % i)
	assert_gt(LaborView.field_angles(0).x, LaborView.field_angles(2).y, "rechts von oben nach unten")
	assert_lt(LaborView.field_angles(3).y, LaborView.field_angles(3).x)

func test_fields_per_state() -> void:
	assert_eq(LaborView.fields_for("bereit", 0, 0), _fields(["aus", "aus", "aus", "aus", "aus", "aus"]),
		"ohne Auftrag ist alles aus")
	assert_eq(LaborView.fields_for("laeuft", 2, 3), _fields(["wurf", "wurf", "runde", "aus", "aus", "aus"]),
		"Wurf 2: vier Runden, eine vergangen")
	assert_eq(LaborView.fields_for("laeuft", 4, 2), _fields(["wurf", "wurf", "wurf", "wurf", "aus", "aus"]))
	assert_eq(LaborView.fields_for("fertig", 3, 0), _fields(["wurf", "wurf", "wurf", "runde", "runde", "runde"]))
	assert_eq(LaborView.fields_for("fertig", 6, 0), _fields(["wurf", "wurf", "wurf", "wurf", "wurf", "wurf"]),
		"eine 6 ist sofort fertig: alles gold")

func _fields(list: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(list)
	return out

func test_status_line_per_state() -> void:
	assert_eq(LaborView.status_text(_state("bereit")), "BEREIT")
	assert_eq(LaborView.status_text(_state("bereit", 0, 0, {"staged": 2, "staged_max": 6})), "EINSATZ 2/6")
	assert_eq(LaborView.status_text(_state("laeuft", 2, 3)), "NOCH 3")
	assert_eq(LaborView.status_text(_state("fertig", 5)), "FERTIG")
	assert_eq(LaborView.status_text(_state("fertig", 5, 0, {"blocked_text": "PROJEKTOR FREI MACHEN"})),
		"PROJEKTOR FREI MACHEN", "eine Sperre gewinnt")

func test_body_state_carries_names_price_and_start() -> void:
	view.set_state(_state("bereit", 0, 0, {"station": "charm", "price": 0}))
	var data := view.body_state()
	assert_eq(data["name"], "CHARM-KOPIERER")
	assert_eq(data["price_text"], "FREI", "der erste Auftrag ist frei")
	assert_true(data["start_lit"])
	assert_false(data["hood"])
	view.set_state(_state("bereit", 0, 0, {"affordable": false}))
	assert_false(view.body_state()["start_lit"], "ohne Energie leuchtet START nicht")
	view.set_state(_state("bereit", 0, 0, {"staged": 0, "staged_max": 6}))
	assert_false(view.body_state()["start_lit"], "ohne Einsatz leuchtet START nicht")
	view.set_state(_state("laeuft", 1, 5))
	data = view.body_state()
	assert_true(data["hood"], "die Haube nur im Lauf")
	assert_eq(data["start_text"], "LÄUFT")
	assert_false(data["start_lit"])
	view.set_state(_state("fertig", 6))
	assert_eq(view.body_state()["start_text"], "FERTIG")
	for station: String in LaborView.STATIONS:
		assert_ne(LaborView.station_name(station), "", station)

func test_start_lights_only_when_the_table_reports_a_ready_stake() -> void:
	view.set_state(_state("bereit", 0, 0, {"station": "seele", "staged": 1, "staged_max": 2,
		"staged_ready": false}))
	assert_false(view.body_state()["start_lit"], "eine Seele allein reicht nicht")
	view.set_state(_state("bereit", 0, 0, {"station": "seele", "staged": 2, "staged_max": 2,
		"staged_ready": true}))
	assert_true(view.body_state()["start_lit"])
	view.set_state(_state("bereit", 0, 0, {"staged": 2, "staged_max": 6, "staged_ready": true,
		"affordable": false}))
	assert_false(view.body_state()["start_lit"], "ohne Energie bleibt es dunkel")
	view.set_state(_state("laeuft", 1, 5, {"staged_ready": true}))
	assert_false(view.body_state()["start_lit"], "nur bereit")

func test_buttons_lie_over_chamber_and_start_and_emit() -> void:
	view.set_state(_state("bereit"))
	assert_eq(view.chamber_button.position, view.part_rect("chamber").position)
	assert_eq(view.start_button.size, view.part_rect("start").size)
	var hits: Array[String] = []
	view.chamber_pressed.connect(func() -> void: hits.append("chamber"))
	view.start_pressed.connect(func() -> void: hits.append("start"))
	view.chamber_button.pressed.emit()
	view.start_button.pressed.emit()
	assert_eq(hits, _fields(["chamber", "start"]))
	view.set_state(_state("laeuft", 2, 3))
	assert_true(view.start_button.disabled, "im Lauf startet nichts")
	view.set_state(_state("bereit", 0, 0, {"open": false}))
	assert_true(view.chamber_button.disabled, "geschlossen nimmt die Kammer nichts")

func test_hints_name_each_part() -> void:
	view.set_state(_state("laeuft", 2, 3))
	var chamber := view.part_rect("chamber").get_center()
	assert_eq(view.part_at(chamber), "chamber")
	assert_string_contains(view.hint_at(chamber), "noch 3 Runden")
	assert_string_contains(view.hint_at(view.part_rect("name").get_center()), "KARTEN-PRESSE")
	assert_string_contains(view.hint_at(view.part_rect("status").get_center()), "NOCH 3")
	var field := LaborView.field_outline(1)
	var mid := (field[7] + field[field.size() - 8]) * 0.5
	var px := view.size * 0.5 + Vector2(mid.x, -mid.y) * view.unit()
	assert_eq(view.part_at(px), "field1")
	assert_string_contains(view.hint_at(px), "Gold")
	assert_eq(view.hint_at(Vector2(2, 2)), "", "neben allem schweigt er")
	view.set_state(_state("bereit", 0, 0, {"price": 3}))
	assert_string_contains(view.hint_at(view.part_rect("start").get_center()), "3 Energie")
