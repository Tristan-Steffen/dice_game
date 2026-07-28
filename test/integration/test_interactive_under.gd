extends GutTest
## TableScreen.interactive_under: der gemeinsame Knopf-Finder. HubView nutzt ihn
## für "Knopf-Klick oder Zoom-Klick", die Werkbank für "Doppelklick auf freie
## Fläche öffnet die Nahsicht" - ein Knopf darunter muss ihn also verhindern.

var host: Control

func before_each() -> void:
	host = Control.new()
	host.size = Vector2(200, 100)
	add_child_autofree(host)

func _button(rect: Rect2) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	host.add_child(button)
	return button

func test_finds_a_button_and_ignores_empty_space() -> void:
	_button(Rect2(10, 10, 50, 20))
	await wait_frames(2)
	assert_true(TableScreen.interactive_under(host, Vector2(30, 20)), "auf dem Knopf")
	assert_false(TableScreen.interactive_under(host, Vector2(150, 80)), "freie Fläche daneben")

func test_ignores_hidden_and_disabled_buttons() -> void:
	var hidden := _button(Rect2(10, 10, 50, 20))
	hidden.visible = false
	var off := _button(Rect2(10, 50, 50, 20))
	off.disabled = true
	await wait_frames(2)
	assert_false(TableScreen.interactive_under(host, Vector2(30, 20)), "verborgen zählt nicht")
	assert_false(TableScreen.interactive_under(host, Vector2(30, 60)), "abgeschaltet zählt nicht")

func test_ignores_buttons_that_let_the_mouse_pass() -> void:
	var decor := _button(Rect2(10, 10, 50, 20))
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await wait_frames(2)
	assert_false(TableScreen.interactive_under(host, Vector2(30, 20)),
		"wer die Maus durchlässt, fängt auch den Doppelklick nicht")

func test_searches_the_whole_subtree() -> void:
	var box := Control.new()
	box.position = Vector2(100, 40)
	box.size = Vector2(80, 40)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(box)
	var button := Button.new()
	button.position = Vector2(10, 5)
	button.size = Vector2(40, 20)
	box.add_child(button)
	await wait_frames(2)
	assert_true(TableScreen.interactive_under(host, Vector2(120, 50)),
		"auch tief verschachtelte Knöpfe zählen (Schubladen-Kacheln, Stations-Werkzeuge)")
