extends GutTest
## TableScreen.window_takes_pixel: der EINE Entscheider hinter "sichtbar heißt
## bedienbar". scene_root fragt ihn je Fenster (Hub/Laden, Wettannahme, Automaten,
## Schwarzmarkt, Werkbank) statt nach der Kamerastation - und weil er rein ist,
## läßt sich hier prüfen, was im Headless keine Kamera hergibt: der Laden nimmt
## seine Klicks auch aus der Freikamera, die leere Fläche bleibt der Flug, und
## während einer Fahrt nimmt nichts etwas an.

var window: Panel
var button: Button

func before_each() -> void:
	window = Panel.new()
	window.position = Vector2(100, 50)
	window.size = Vector2(200, 100)
	add_child_autofree(window)
	button = Button.new()
	button.position = Vector2(10, 10)
	button.size = Vector2(60, 20)
	window.add_child(button)
	await wait_frames(2)

## Rechteck des Fensters in Display-Pixeln (wie scene_root._window_rect).
func _rect() -> Rect2:
	return Rect2(window.position, window.size)

## Ein Punkt auf dem Knopf bzw. auf freier Fensterfläche.
func _on_button() -> Vector2:
	return window.position + button.position + button.size * 0.5

func _on_empty() -> Vector2:
	return window.position + Vector2(180.0, 80.0)

func test_a_click_on_a_button_lands_from_anywhere() -> void:
	assert_true(TableScreen.window_takes_pixel(window, _rect(), _on_button(),
		true, false), "der Knopf nimmt den Klick, auch wenn die Kamera woanders steht")

func test_empty_surface_stays_the_flight_while_the_camera_is_elsewhere() -> void:
	assert_false(TableScreen.window_takes_pixel(window, _rect(), _on_empty(),
		true, false), "sonst fräße das Fenster den Flug auf seine eigene Fläche")
	assert_true(TableScreen.window_takes_pixel(window, _rect(), _on_empty(),
		true, true), "an der eigenen Station schluckt es auch das Leere")

func test_motion_goes_over_the_whole_surface() -> void:
	assert_true(TableScreen.window_takes_pixel(window, _rect(), _on_empty(),
		false, false), "Bewegung überall - sonst verlöre ein Knopf sein mouse_exited")

func test_a_running_flight_takes_nothing() -> void:
	assert_false(TableScreen.window_takes_pixel(window, _rect(), _on_button(),
		true, true, true), "halbe Übergänge klicken sich schlecht")
	assert_false(TableScreen.window_takes_pixel(window, _rect(), _on_button(),
		false, true, true), "auch die Bewegung nicht")

func test_an_invisible_window_takes_nothing() -> void:
	window.visible = false
	assert_false(TableScreen.window_takes_pixel(window, _rect(), _on_button(),
		true, true), "was nicht zu sehen ist, ist nicht zu bedienen")

func test_a_point_outside_the_rect_or_off_the_table_takes_nothing() -> void:
	assert_false(TableScreen.window_takes_pixel(window, _rect(),
		window.position - Vector2(20.0, 20.0), false, true), "neben dem Fenster")
	assert_false(TableScreen.window_takes_pixel(window, _rect(),
		Vector2(-1.0, -1.0), false, true), "der Strahl hat den Tisch verfehlt")
	assert_false(TableScreen.window_takes_pixel(null, _rect(), _on_button(),
		false, true), "kein Fenster, kein Ziel")

## Ein abgeschalteter Knopf ist kein Bedienteil: der Klick fällt durch zum Flug.
func test_a_dead_button_is_no_target() -> void:
	button.disabled = true
	assert_false(TableScreen.window_takes_pixel(window, _rect(), _on_button(),
		true, false), "gesperrt zählt nicht als Bedienteil")
