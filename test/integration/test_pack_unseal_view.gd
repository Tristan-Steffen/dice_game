extends GutTest
## Tier-2-Tests der Entsiegelung (PackUnsealView): brechendes Siegel, die
## Vorstellungsrunde im Kreis, und der Takt, WANN welches Stück abfliegt. Was
## danach kommt, gehört den Meteoren (TableScreen) und dem Einschlag
## (SupplyDrawerView).

var view: PackUnsealView

func before_each() -> void:
	view = PackUnsealView.new()
	view.size = Vector2(600, 500)
	add_child_autofree(view)

func _engravings(rarities: Array) -> Array[Engraving]:
	var out: Array[Engraving] = []
	for rarity in rarities:
		var engraving := Engraving.chisel()
		engraving.rarity = rarity
		out.append(engraving)
	return out

func _setup(engravings: Array[Engraving], dice: Array[DieDefinition] = [] as Array[DieDefinition]) -> void:
	view.setup(Pack.TYPE_NUMBER, engravings, dice, 6.0)

func _fresh(engravings: Array[Engraving]) -> PackUnsealView:
	var other := PackUnsealView.new()
	other.size = Vector2(600, 500)
	add_child_autofree(other)
	other.setup(Pack.TYPE_NUMBER, engravings, [] as Array[DieDefinition], 6.0)
	return other

# --- Der Bruch verrät nichts ------------------------------------------------------

func test_the_crack_is_the_same_length_for_every_pack() -> void:
	# Eine Bruchzeit, die mit dem Inhalt wächst, wäre selbst ein Tell.
	var common := _fresh(_engravings([Engraving.Rarity.COMMON]))
	var rare := _fresh(_engravings([Engraving.Rarity.RARE]))
	assert_eq(common.beat_times()[0], rare.beat_times()[0],
		"das erste Stück fliegt unabhängig von seiner Seltenheit gleich früh")

func test_nothing_flies_before_the_seal_breaks() -> void:
	_setup(_engravings([Engraving.Rarity.COMMON, Engraving.Rarity.RARE]))
	var sent := [0]
	view.chip_resolved.connect(func(_id: String, _px: Vector2, _r: int) -> void: sent[0] += 1)
	view._process(PackUnsealView.CRACK_TIME * 0.5)
	assert_eq(sent[0], 0, "vor dem Bruch verlässt kein Stück das Siegel")

func test_no_sign_is_on_the_table_before_the_seal_breaks() -> void:
	# Das Zeichen IST das Stück - stünde es schon da, wäre der Inhalt verraten,
	# bevor das Paket überhaupt aufgeht.
	_setup(_engravings([Engraving.Rarity.COMMON, Engraving.Rarity.RARE]))
	view._process(PackUnsealView.CRACK_TIME * 0.5)
	for piece in view._pieces:
		assert_false((piece["node"] as Control).visible, "vor dem Bruch ist nichts zu sehen")

# --- Die Vorstellungsrunde --------------------------------------------------------

func test_the_content_stands_in_the_circle_during_the_pause() -> void:
	_setup(_engravings([Engraving.Rarity.COMMON, Engraving.Rarity.COMMON,
		Engraving.Rarity.RARE]))
	view._process(PackUnsealView.CRACK_TIME + PackUnsealView.EJECT_TRAVEL + 0.01)
	for piece in view._pieces:
		assert_true((piece["node"] as Control).visible, "nach dem Bruch zeigt sich alles")

func test_the_circle_gives_every_piece_its_own_place() -> void:
	_setup(_engravings([Engraving.Rarity.COMMON, Engraving.Rarity.COMMON,
		Engraving.Rarity.RARE]))
	var seen: Array[Vector2] = []
	for i in view._pieces.size():
		var at := view._ring_point(i)
		assert_true(Rect2(Vector2.ZERO, view.size).has_point(at), "der Platz liegt im Fenster")
		assert_false(seen.has(at), "kein Platz doppelt")
		seen.append(at)

func test_the_pieces_leave_the_circle_one_after_another() -> void:
	_setup(_engravings([Engraving.Rarity.COMMON, Engraving.Rarity.RARE]))
	var sent := [0]
	view.chip_resolved.connect(func(_id: String, _px: Vector2, _r: int) -> void: sent[0] += 1)
	view._process(view.beat_times()[0] + 0.01)
	assert_eq(sent[0], 1, "erst eines")
	# Das seltene wartet sichtbar weiter - es geht zuletzt.
	assert_true((view._pieces[view._order[1]]["node"] as Control).visible,
		"das zweite Stück steht noch im Kreis")

func test_pieces_leave_one_at_a_time() -> void:
	_setup(_engravings([Engraving.Rarity.COMMON, Engraving.Rarity.COMMON]))
	var sent := [0]
	view.chip_resolved.connect(func(_id: String, _px: Vector2, _r: int) -> void: sent[0] += 1)
	view._process(view.beat_times()[0] + 0.01)
	assert_eq(sent[0], 1, "die Stücke fliegen einzeln, nicht als Block")

# --- Takt und Reihenfolge --------------------------------------------------------

func test_pieces_leave_from_common_to_rare() -> void:
	_setup(_engravings([Engraving.Rarity.RARE, Engraving.Rarity.COMMON, Engraving.Rarity.UNCOMMON]))
	var order: Array[int] = []
	view.chip_resolved.connect(func(_id: String, _px: Vector2, rarity: int) -> void:
		order.append(rarity))
	view.finish_now()
	assert_eq(order, [
		int(Engraving.Rarity.COMMON),
		int(Engraving.Rarity.UNCOMMON),
		int(Engraving.Rarity.RARE),
	] as Array[int], "das Beste zuletzt")

func test_a_new_best_piece_makes_the_rhythm_hitch() -> void:
	_setup(_engravings([Engraving.Rarity.COMMON, Engraving.Rarity.COMMON, Engraving.Rarity.RARE]))
	var times := view.beat_times()
	assert_almost_eq(times[1] - times[0], PackUnsealView.STAGGER, 0.001,
		"zwei Gewöhnliche im Grundtakt")
	assert_almost_eq(times[2] - times[1], PackUnsealView.STAGGER + PackUnsealView.HITCH, 0.001,
		"vor dem Seltenen stockt es")

func test_pieces_of_equal_rarity_keep_the_plain_beat() -> void:
	_setup(_engravings([Engraving.Rarity.RARE, Engraving.Rarity.RARE]))
	var times := view.beat_times()
	assert_almost_eq(times[1] - times[0], PackUnsealView.STAGGER, 0.001,
		"kein neuer Bestwert, kein Stocken")

func test_the_whole_show_stays_short() -> void:
	# Vier Stücke mit einem Seltenen am Ende - der übliche Fall eines Pakets.
	_setup(_engravings([Engraving.Rarity.COMMON, Engraving.Rarity.COMMON,
		Engraving.Rarity.COMMON, Engraving.Rarity.RARE]))
	assert_lt(view.total_time(), 2.0, "Bruch, Vorstellungsrunde und Abflug bleiben knapp")

# --- Was ein Stück meldet ---------------------------------------------------------

func test_every_piece_reports_once_from_its_place_in_the_circle() -> void:
	_setup(_engravings([Engraving.Rarity.COMMON, Engraving.Rarity.COMMON]))
	var sent: Array[Vector2] = []
	view.chip_resolved.connect(func(id: String, px: Vector2, _r: int) -> void:
		assert_eq(id, Engraving.CHISEL, "das Stück meldet seine id")
		sent.append(px))
	view.finish_now()
	assert_eq(sent.size(), 2)
	for px in sent:
		assert_true(Rect2(Vector2.ZERO, view.size).has_point(px), "der Start liegt im Fenster")
		assert_ne(px, view.size * 0.5, "der Meteor startet am Zeichen, nicht im Siegel")
	assert_ne(sent[0], sent[1], "jedes Stück startet an seinem eigenen Platz")

func test_the_rarity_rides_along_for_the_meteor_color() -> void:
	_setup(_engravings([Engraving.Rarity.UNCOMMON]))
	var seen := [-1]
	view.chip_resolved.connect(func(_id: String, _px: Vector2, rarity: int) -> void:
		seen[0] = rarity)
	view.finish_now()
	assert_eq(seen[0], int(Engraving.Rarity.UNCOMMON), "die Farbe kommt aus der Meldung")

func test_dice_pieces_report_without_an_engraving_id() -> void:
	var dice: Array[DieDefinition] = []
	dice.append(DieDefinition.standard())
	var ids: Array[String] = []
	_setup([] as Array[Engraving], dice)
	view.chip_resolved.connect(func(id: String, _px: Vector2, _r: int) -> void: ids.append(id))
	view.finish_now()
	assert_eq(ids, [""] as Array[String], "Würfel fliegen in keine Schublade")

func test_dice_get_the_same_presentation_round() -> void:
	var dice: Array[DieDefinition] = []
	dice.append(DieDefinition.standard())
	dice.append(DieDefinition.standard())
	_setup([] as Array[Engraving], dice)
	view._process(PackUnsealView.CRACK_TIME + PackUnsealView.EJECT_TRAVEL + 0.01)
	for piece in view._pieces:
		assert_true((piece["node"] as Control).visible, "auch Würfel zeigen sich erst im Kreis")

func test_dice_rarity_comes_from_the_refinement() -> void:
	var edged := DieDefinition.standard()
	edged.essence_id = Essence.NEON
	var dice: Array[DieDefinition] = []
	dice.append(edged)
	_setup([] as Array[Engraving], dice)
	assert_eq(view.tier(), int(Engraving.Rarity.RARE), "Kanten-Material ist die seltene Veredelung")

# --- Abschluss --------------------------------------------------------------------

func test_skipping_sends_everything_and_finishes() -> void:
	_setup(_engravings([Engraving.Rarity.COMMON, Engraving.Rarity.RARE]))
	var done := [false]
	view.finished.connect(func() -> void: done[0] = true)
	var sent := [0]
	view.chip_resolved.connect(func(_id: String, _px: Vector2, _r: int) -> void: sent[0] += 1)
	view.finish_now()
	assert_eq(sent[0], 2, "Ungeduld kostet kein Stück")
	assert_true(done[0], "die Zeremonie meldet sich fertig")
	assert_true(view.is_done())

func test_finishing_twice_changes_nothing() -> void:
	_setup(_engravings([Engraving.Rarity.COMMON]))
	view.finish_now()
	var extra := [0]
	view.chip_resolved.connect(func(_id: String, _px: Vector2, _r: int) -> void: extra[0] += 1)
	view.finish_now()
	assert_eq(extra[0], 0, "ein durchgelaufener Ablauf löst nichts nach")

func test_the_show_finishes_by_itself_when_time_is_up() -> void:
	_setup(_engravings([Engraving.Rarity.COMMON]))
	var done := [false]
	view.finished.connect(func() -> void: done[0] = true)
	view._process(view.beat_times()[0] + 0.01)
	assert_false(done[0], "das letzte Stück ist noch nicht der Abschluss")
	view._process(PackUnsealView.HOLD + 0.01)
	assert_true(done[0], "nach dem Nachlauf endet sie")
