extends GutTest
## Tier-2-Tests der Augen-Pips im Tisch-Display: der Pip baut Kopf und Schleier,
## räumt sie bei Ankunft wieder ab und meldet seinen Aufschlagpunkt - der
## Grubenboden weicht dem, was in seiner Spalte steht (Netz-Karte, Erklärleiste),
## dieselbe Klemmung, die die Zuwachs-Zahlen von der Karte fernhält.

var screen: TableScreen

const PIT := Rect2(Vector2(200, 300), Vector2(900, 400))

func before_each() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	screen = TableScreen.new()
	world.add_child(screen)
	screen.place_pit_window(PIT, 20.0)

## Nur die Pip-Knoten zählen - das Fenster und seine Wellen stehen immer da.
func _pip_nodes() -> int:
	var count := 0
	for child in screen.get_children():
		if child is TextureRect:
			count += 1
	return count

## Der Kopf ist der quadratische der beiden Knoten, der Schleier der lange.
func _pip_head() -> TextureRect:
	for child in screen.get_children():
		if child is TextureRect and is_equal_approx(child.size.x, child.size.y):
			return child
	return null

# --- Der Pip selbst ---------------------------------------------------------

func test_a_pip_puts_head_and_trail_on_the_screen() -> void:
	screen.spawn_eye_pip(Vector2(400, 320), Vector2(400, 600), 1, TableScreen.EYE_PIP_COLOR)
	assert_eq(_pip_nodes(), 2, "Kopf und Bewegungsschleier")

## Die Stückelung MUSS am Durchmesser ablesbar sein - ohne EXPAND_IGNORE_SIZE
## zieht die Punkt-Textur ihre eigene Auflösung als Mindestgröße ein und der
## Einser wird so groß wie der Fünfer.
func test_a_five_flies_bigger_than_a_one() -> void:
	screen.spawn_eye_pip(Vector2(400, 320), Vector2(400, 600), 1, TableScreen.EYE_PIP_COLOR)
	assert_almost_eq(_pip_head().size.x, TableScreen.EYE_PIP_UNIT, 0.5, "der Einser bleibt klein")
	for child in screen.get_children():
		if child is TextureRect:
			child.free()
	screen.spawn_eye_pip(Vector2(400, 320), Vector2(400, 600), 5, TableScreen.EYE_PIP_COLOR)
	assert_almost_eq(_pip_head().size.x, TableScreen.EYE_PIP_FIVE, 0.5, "der Fünfer trägt mehr")
	assert_gt(TableScreen.EYE_PIP_FIVE, TableScreen.EYE_PIP_UNIT)

func test_the_pip_clears_itself_and_reports_its_arrival() -> void:
	var arrived := []
	screen.spawn_eye_pip(Vector2(400, 320), Vector2(400, 600), 1, TableScreen.EYE_PIP_COLOR,
		func() -> void: arrived.append(true))
	# Flugzeit plus Streuung; danach ist der Pip abgeräumt.
	await wait_seconds(TableScreen.EYE_PIP_TIME + TableScreen.EYE_PIP_TIME_JITTER + 0.3)
	assert_eq(arrived.size(), 1, "die Ankunft meldet sich genau einmal")
	assert_eq(_pip_nodes(), 0, "und lässt nichts stehen")

func test_the_pip_starts_at_its_source() -> void:
	var from_px := Vector2(400, 320)
	screen.spawn_eye_pip(from_px, Vector2(400, 600), 1, TableScreen.EYE_PIP_COLOR)
	var head := _pip_head()
	assert_not_null(head)
	assert_almost_eq(head.position.x + head.size.x / 2.0, from_px.x, 1.0)
	assert_almost_eq(head.position.y + head.size.y / 2.0, from_px.y, 1.0)

# --- Aufschlaghöhe ----------------------------------------------------------

func test_the_floor_is_the_pit_wall_when_nothing_stands_in_the_way() -> void:
	var expected := PIT.position.y + PIT.size.y - TableScreen.EYE_PIP_FLOOR_INSET
	assert_almost_eq(screen.pit_floor_y(PIT.position.x + 50.0), expected, 0.5)

func test_the_net_card_raises_the_floor_in_its_own_column() -> void:
	var card := Rect2(Vector2(500, 560), Vector2(200, 100))
	screen.place_pit_info_bar(card)
	screen.pit_info_bar.visible = true
	var on_card := screen.pit_floor_y(600.0)
	assert_almost_eq(on_card, card.position.y - TableScreen.EYE_PIP_FLOOR_GAP, 0.5,
		"über der Karte endet der Fall")
	var beside := screen.pit_floor_y(300.0)
	assert_gt(beside, on_card, "daneben faellt der Pip bis auf die Grubenwand")

func test_a_hidden_card_is_no_obstacle() -> void:
	screen.place_pit_info_bar(Rect2(Vector2(500, 560), Vector2(200, 100)))
	screen.pit_info_bar.visible = false
	var expected := PIT.position.y + PIT.size.y - TableScreen.EYE_PIP_FLOOR_INSET
	assert_almost_eq(screen.pit_floor_y(600.0), expected, 0.5)

func test_the_ceiling_sits_under_the_upper_pit_wall() -> void:
	assert_almost_eq(screen.pit_ceiling_y(), PIT.position.y + TableScreen.EYE_PIP_CEILING_INSET, 0.5)
	assert_lt(screen.pit_ceiling_y(), screen.pit_floor_y(600.0), "die Decke liegt über dem Boden")

# --- Aufschlag-Welle --------------------------------------------------------

func test_a_landing_may_carry_its_own_splash_colour() -> void:
	# Die Welle des Pips trägt seine Farbe, nicht die der Punktart.
	screen.pit_impulse(Vector2(600, 650), "base", TableScreen.EYE_PIP_LOSS_COLOR)
	var colors: PackedColorArray = screen.pit_waves.material.get_shader_parameter("impulse_color")
	assert_true(colors.has(TableScreen.EYE_PIP_LOSS_COLOR), "die Pip-Farbe steht im Puls")

func test_without_a_colour_the_kind_still_decides() -> void:
	screen.pit_impulse(Vector2(600, 650), "mult")
	var colors: PackedColorArray = screen.pit_waves.material.get_shader_parameter("impulse_color")
	assert_true(colors.has(TableScreen.TRAIL_MULT_COLOR), "der alte Weg bleibt unberührt")
