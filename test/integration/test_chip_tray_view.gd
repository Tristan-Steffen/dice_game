extends GutTest
## Das Chip-Tray als Körper: die Fassung steht genau im Rechteck des Wett-Tresens,
## jeder Chip liegt unter der Fläche und links der Sperre, die Zeremonie endet auf
## der Belegung - und ein harter Abbruch mitten in jedem Schritt auch.

## Gemessen 1280 × 720: der Wett-Tresen in Display-Pixeln und in Welt.
const SIDE := Vector2(388.4, 570.0)
const WORLD_PER_PX := 10.36 / 388.4

func _tray() -> ChipTrayView:
	var fassung := TreasureChestView.new()
	fassung.size = SIDE
	var pit := fassung.pit_rect()
	fassung.free()
	var tray := ChipTrayView.new()
	add_child_autofree(tray)
	# Bild-x ist Welt +Z, Bild-y Welt -X.
	tray.setup(Vector3(3.0, 0.0, 5.0),
		Vector2(pit.size.y, pit.size.x) * WORLD_PER_PX * 0.5)
	return tray

func _run_out(tray: ChipTrayView, frames: int) -> void:
	for i in frames:
		for r in ChipTrayView.VALUES.size():
			tray.land(r)
		tray.step(1.0 / 60.0)

func _shown(counts: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for r in counts.size():
		out.append(mini(counts[r], ChipTrayView.shown_cap(r)))
	return out

func test_the_tray_has_the_exact_rectangle_of_the_bet_counter() -> void:
	var side := Rect2(Vector2(812.0, 140.0), SIDE)
	var rect := TreasureChestView.placed_beside(side, 6.4)
	assert_eq(rect.size, side.size, "gleich breit und gleich hoch")
	assert_eq(rect.position.y, side.position.y, "dieselbe Oberkante")
	assert_almost_eq(rect.position.x, side.end.x + 6.4, 0.0001, "eine Fuge rechts daneben")

func test_a_full_groove_fits_left_of_the_entry() -> void:
	var tray := _tray()
	assert_gte(tray.slot_s(ChipTrayView.TOP_SHOWN - 1), ChipTrayView.ENTRY_S - 0.001,
		"der letzte gezeigte Chip steht nicht hinter dem Einlauf")
	var half := tray.half_extents()
	assert_gte(half.x * 2.0 / 7.0, ChipStackView.CHIP_RADIUS * 2.0 + 0.1,
		"eine Rinne ist breiter als ein Chip samt Steg")

func test_no_chip_rises_over_the_surface_and_all_lie_left_of_the_gate() -> void:
	var tray := _tray()
	var money := 3687 + 140_000
	tray.seat_hard(ChipTrayView.belegung(money))
	assert_eq(tray.body_counts(), _shown(ChipTrayView.belegung(money)))
	var right := tray.global_position.z + tray.half_extents().y
	var left := tray.global_position.z - tray.half_extents().y
	for chip: Node3D in tray.get_node("Chips").get_children():
		# Hochkant: der Rand steht oben, die Dicke liegt längs der Rinne.
		var top := chip.global_position.y + ChipStackView.CHIP_RADIUS * cos(ChipTrayView.TILT) \
			+ ChipStackView.CHIP_HEIGHT * 0.5 * sin(ChipTrayView.TILT)
		var reach := ChipStackView.CHIP_HEIGHT * 0.5 * cos(ChipTrayView.TILT) \
			+ ChipStackView.CHIP_RADIUS * sin(ChipTrayView.TILT)
		assert_lt(top, 0.0, "%s ragt nicht über die Fläche" % chip.name)
		assert_lt(chip.global_position.z + reach, right,
			"%s liegt links der Sperre" % chip.name)
		assert_gt(chip.global_position.z - reach, left,
			"%s liegt rechts der linken Wand" % chip.name)

func test_a_ceremony_ends_on_the_belegung() -> void:
	var tray := _tray()
	tray.seat_hard(ChipTrayView.belegung(99))
	var entered := [0]
	var left := [0]
	tray.chip_entered.connect(func(_r: int) -> void: entered[0] += 1)
	tray.chip_left.connect(func(_r: int, _paid: bool) -> void: left[0] += 1)
	for pair in [[99, 100], [100, 3687], [3687, 1], [1, 10_000], [10_000, 9990]]:
		var steps := ChipTrayView.transition(ChipTrayView.belegung(pair[0]),
			ChipTrayView.belegung(pair[1]))
		tray.play(steps)
		_run_out(tray, 1200)
		assert_false(tray.busy(), "%d -> %d kommt zur Ruhe" % pair)
		assert_eq(tray.body_counts(), _shown(ChipTrayView.belegung(pair[1])),
			"%d -> %d liegt auf der Belegung" % pair)
	assert_gt(entered[0], 0, "Chips sind eingelaufen")
	assert_gt(left[0], 0, "Chips sind in den Tisch gegangen")

func test_a_hard_abort_in_every_step_stands_on_the_belegung() -> void:
	var tray := _tray()
	for frames in [1, 3, 8, 15, 30, 60, 120]:
		tray.seat_hard(ChipTrayView.belegung(99))
		tray.play(ChipTrayView.transition(ChipTrayView.belegung(99), ChipTrayView.belegung(100)))
		tray.play(ChipTrayView.transition(ChipTrayView.belegung(100), ChipTrayView.belegung(10_000)))
		tray.play(ChipTrayView.transition(ChipTrayView.belegung(10_000), ChipTrayView.belegung(9990)))
		_run_out(tray, frames)
		tray.settle_hard()
		assert_false(tray.busy(), "nach %d Bildern: nichts fährt mehr" % frames)
		assert_eq(tray.target_counts(), ChipTrayView.belegung(9990))
		assert_eq(tray.body_counts(), _shown(ChipTrayView.belegung(9990)),
			"nach %d Bildern: jeder Chip auf seinem Platz" % frames)

func test_payment_reports_each_paid_chip() -> void:
	var tray := _tray()
	tray.seat_hard(ChipTrayView.belegung(30))
	var paid := []
	tray.chip_left.connect(func(r: int, was_paid: bool) -> void:
		if was_paid:
			paid.append(ChipTrayView.VALUES[r]))
	tray.play(ChipTrayView.transition(ChipTrayView.belegung(30), ChipTrayView.belegung(0)))
	_run_out(tray, 600)
	var sum := 0
	for value: int in paid:
		sum += value
	assert_eq(sum, 30, "was als gezahlt meldet, ist genau der Preis")
