extends GutTest
## Tier-2-Tests des PLATZIERUNGS-Schritts: keine losen Aufwertungen. Die gepresste
## Beute LIEGT als Haufen nackter Chips im freien Band unter der Netzzeile - der
## geführte Chip trägt den goldenen Rahmen, seine legalen Ziele leuchten IN den
## Netzen der Aufspannung, und erst das FERTIG macht den Guss hart. Bis dahin ist
## jede Setzung nass und kommt in die Ablage zurück. Konsole und Buchten stehen
## dabei unverrückt weiter - der Schritt hat keine eigene Seite.

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	view.size = Vector2(900, 600)
	add_child_autofree(view)
	view.run = run

## Legt ein Beutestück in die Ablage (so, wie die Pressung es täte) und liefert
## seine Nummer - sie ist der Griff, an dem Chip und Führung hängen.
func _piece(id: String, extra: Dictionary = {}) -> int:
	run.press_piece_serial += 1
	var piece := {"sort": Engraving.CATEGORY_NUMBER, "id": id, "stufe": 1,
		"applications": 1, "piece_uid": run.press_piece_serial}
	for key: String in extra:
		piece[key] = extra[key]
	run.press_pieces.append(piece)
	run.press_changed.emit()
	return run.press_piece_serial

## Der erste aufgespannte Würfel - er trägt die Netze, in denen gesetzt wird.
func _clamped() -> DieDefinition:
	return run.clamped_dice[0]

## Ein Pool-Würfel AUSSERHALB der Aufspannung.
func _loose() -> DieDefinition:
	for die in run.owned_pool:
		if not run.is_clamped(die):
			return die
	return null

## Das ausliegende Arbeits-Netz dieses Würfels (null = liegt nicht aus).
func _net_of(die: DieDefinition) -> PressNetView:
	for net in view._clamp_nets:
		if is_instance_valid(net) and net.def == die:
			return net
	return null

## Der Chip eines Stücks in der Ablage (null = liegt nicht).
func _chip(uid: int) -> Button:
	return view._ablage_chips.get(uid)

func _glow_box(uid: int) -> StyleBoxFlat:
	return _chip(uid).get_node("ChipGlow").get_theme_stylebox("panel")

## Der goldene Rahmen ist die ganze Auswahl - ein liegender Chip hat gar keinen.
func _held_frame(uid: int) -> bool:
	var box := _glow_box(uid)
	return box.border_width_top > 0 and box.border_color == WorkshopView.GOLD

func _seat() -> Control:
	return view.get_node("PressBand/ActionSeat")

# --- Die Beute liegt auf dem Glas -------------------------------------------------

func test_the_pressed_loot_lies_in_the_ablage() -> void:
	var uid := _piece(Engraving.NOTCH, {"applications": 3})
	await wait_frames(2)
	assert_true(view.placing(), "der Schritt steht")
	assert_eq(int(view.press_piece_counts().get(Engraving.NOTCH, 0)), 3, "drei offene Anwendungen")
	assert_not_null(_chip(uid), "das Stück liegt als Chip da")
	assert_true(view.ablage_rect().has_point(view.ablage_spot(uid)), "im Streifen der Ablage")
	assert_true(view.bench_rect().has_point(view.piece_anchor_px(uid)),
		"das Licht startet an seinem Chip")

func test_without_loot_the_pile_stands_empty() -> void:
	assert_false(view.placing())
	assert_true(view.press_piece_counts().is_empty())
	assert_null(view._ablage_host, "die Grundseite trägt keinen Haufen")

func test_the_hand_always_holds_a_piece() -> void:
	# Es braucht keine zweite Geste: das erste Stück liegt sofort geführt.
	var uid := _piece(Engraving.NOTCH)
	assert_eq(view.held_uid(), uid)
	assert_eq(view.held_piece_id(), Engraving.NOTCH)

func test_the_held_chip_wears_the_gold_frame() -> void:
	var first := _piece(Engraving.NOTCH)
	var second := _piece(Engraving.CHISEL)
	await wait_frames(2)
	assert_true(_held_frame(first), "der geführte Chip ist gerahmt")
	assert_false(_held_frame(second), "der andere liegt einfach da")

func test_a_lying_chip_draws_nothing_of_its_own() -> void:
	# Chip-Schalen-Regel: der Knopf zeichnet in KEINEM Zustand.
	var uid := _piece(Engraving.NOTCH)
	await wait_frames(2)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_true(_chip(uid).get_theme_stylebox(state) is StyleBoxEmpty,
			"%s zeichnet nichts" % state)

func test_holding_switches_the_guided_piece() -> void:
	_piece(Engraving.NOTCH)
	var second := _piece(Engraving.CHISEL)
	view.hold_piece(second)
	assert_eq(view.held_uid(), second)
	assert_eq(view.held_piece_id(), Engraving.CHISEL)
	assert_eq(view._first_face, -1, "und beginnt sein Paar von vorn")

func test_a_chip_click_takes_its_piece_into_the_hand() -> void:
	_piece(Engraving.NOTCH)
	var second := _piece(Engraving.CHISEL)
	await wait_frames(2)
	_chip(second).pressed.emit()
	assert_eq(view.held_uid(), second, "der Chip ist verdrahtet")
	assert_eq(view.held_piece_id(), Engraving.CHISEL)

func test_a_piece_that_is_not_there_holds_nothing() -> void:
	var uid := _piece(Engraving.NOTCH)
	view.hold_piece(4242)
	assert_eq(view.held_uid(), uid, "die Führung bleibt, wo sie war")

## Zwei Stücke dürfen dieselbe Gravur sein - die id taugt nicht als Griff.
func test_two_pieces_with_the_same_icon_stay_two_pieces() -> void:
	var first := _piece(Engraving.NOTCH)
	var second := _piece(Engraving.NOTCH, {"stufe": 6})
	await wait_frames(2)
	assert_eq(view.held_uid(), first)
	assert_eq(view._held_stufe(), 1, "der erste wirkt auf seiner Stufe")
	view.hold_piece(second)
	assert_eq(view._held_stufe(), 6, "der zweite auf seiner")
	var die := _clamped()
	var before: int = die.faces[0]
	view._on_net_face_pressed(0, die)
	assert_eq(die.faces[0], before + EtchingEffects.NOTCH_LADDER[5], "gesetzt wurde Stufe 6")
	assert_eq(run.press_pieces.size(), 1, "und nur EIN Stück ist verbraucht")
	await wait_frames(2)
	assert_not_null(_chip(first), "der erste liegt weiter da")
	assert_null(_chip(second))

func test_a_spent_chip_vanishes_and_the_next_takes_over() -> void:
	_piece(Engraving.NOTCH)
	var second := _piece(Engraving.CHISEL)
	view._on_net_face_pressed(0, _clamped())
	await wait_frames(2)
	assert_eq(run.press_pieces.size(), 1, "das gesetzte Stück ist fort")
	assert_eq(view.held_uid(), second, "und die Führung rückt zum nächsten")
	assert_true(_held_frame(second))

# --- Die Bank: nur die Aufspannung nimmt an ---------------------------------------

func test_the_clamped_dice_are_the_bench() -> void:
	_piece(Engraving.NOTCH)
	assert_eq(view._clamp_nets.size(), run.clamped_dice.size(), "je Zwinge ein Arbeits-Netz")
	assert_true(run.press_target_allowed(_clamped()))
	assert_false(run.press_target_allowed(_loose()), "nur die Zwingen sind editierbar")

func test_a_die_outside_the_clamps_takes_nothing() -> void:
	_piece(Engraving.NOTCH)
	var loose := _loose()
	var before: int = loose.faces[0]
	view._on_net_face_pressed(0, loose)
	assert_eq(loose.faces[0], before, "ein fremder Würfel nimmt nichts an")
	assert_eq(run.press_pieces.size(), 1, "und das Stück bleibt liegen")

# --- Legale Zellen führen -----------------------------------------------------------

func test_only_the_legal_cells_are_armed() -> void:
	var die := _clamped()
	die.set_face_material(0, DieMaterial.GOLD)
	_piece(DieMaterial.GOLD, {"sort": Engraving.CATEGORY_MATERIAL})
	await wait_frames(2)
	var net := _net_of(die)
	assert_not_null(net, "der Würfel liegt aus")
	assert_true(net._chips[0].disabled, "dieselbe Farbe noch einmal ist kein Ziel")
	assert_false(net._chips[1].disabled, "jede andere Seite lässt sich streichen")

func test_an_illegal_cell_click_changes_nothing() -> void:
	var die := _clamped()
	die.set_face_material(0, DieMaterial.GOLD)
	_piece(DieMaterial.GOLD, {"sort": Engraving.CATEGORY_MATERIAL})
	view._on_net_face_pressed(0, die)
	assert_eq(run.press_pieces.size(), 1, "das Stück liegt weiter in der Ablage")
	assert_true(run.press_journal.is_empty(), "und nichts wurde gesetzt")

func test_a_cell_click_through_the_net_books_the_piece() -> void:
	_piece(Engraving.NOTCH, {"stufe": 3})
	var die := _clamped()
	var before: int = die.faces[0]
	await wait_frames(2)
	_net_of(die).face_pressed.emit(0)
	assert_eq(die.faces[0], before + EtchingEffects.NOTCH_LADDER[2], "Stufe 3 der Kerbe")
	assert_true(run.press_pieces.is_empty(), "das Stück ist verbraucht")

func test_a_placement_reports_its_die_and_where_the_light_starts() -> void:
	# Der Startpunkt reist MIT: gebucht ist da längst, das Fenster also schon neu
	# gebaut - und der Chip des Stücks ist dann fort.
	var uid := _piece(Engraving.NOTCH)
	var die := _clamped()
	await wait_frames(2)
	var spot := view.ablage_spot_px(uid)
	var hits: Array = []
	view.piece_placed.connect(func(target: DieDefinition, id: String, from_px: Vector2) -> void:
		hits.append([target, id, from_px]))
	view._on_net_face_pressed(0, die)
	assert_eq(hits.size(), 1, "scene_root lässt den Projektor dieses Würfels aufblitzen")
	assert_same(hits[0][0], die)
	assert_eq(String(hits[0][1]), Engraving.NOTCH)
	assert_almost_eq(hits[0][2], spot, Vector2.ONE * 0.5, "und zwar von seinem Chip")
	assert_ne(hits[0][2], view.get_global_rect().get_center(), "nicht aus der Fenstermitte")

# --- Gerichtete Paare: Quelle -> Ziel ---------------------------------------------

func test_the_chisel_reads_the_first_click_as_its_source() -> void:
	_piece(Engraving.CHISEL)
	var die := _clamped()
	var source: int = die.faces[0]
	view._on_net_face_pressed(0, die)
	assert_eq(view._first_face, 0, "erster Klick ist die Quelle")
	assert_same(view._first_die, die)
	assert_eq(run.press_pieces.size(), 1, "noch ist nichts verbraucht")
	view._on_net_face_pressed(1, die)
	assert_eq(die.faces[1], source, "das Ziel erhält den Quellwert")
	assert_true(run.press_pieces.is_empty())

func test_clicking_the_source_again_takes_it_back() -> void:
	_piece(Engraving.CHISEL)
	var die := _clamped()
	view._on_net_face_pressed(2, die)
	view._on_net_face_pressed(2, die)
	assert_eq(view._first_face, -1, "die Quelle ist zurückgenommen")
	assert_eq(run.press_pieces.size(), 1, "und nichts verbraucht")

func test_a_pair_never_reaches_across_two_dice() -> void:
	# Ein Meißel schöpft nicht aus einem fremden Körper.
	_piece(Engraving.CHISEL)
	if run.clamped_dice.size() < 2:
		return
	var first := run.clamped_dice[0]
	var second := run.clamped_dice[1]
	view._on_net_face_pressed(0, first)
	view._on_net_face_pressed(1, second)
	assert_same(view._first_die, second, "der zweite Klick beginnt am neuen Würfel neu")
	assert_eq(view._first_face, 1)
	assert_eq(run.press_pieces.size(), 1, "gesetzt wurde nichts")

func test_the_pointer_only_wires_a_neighbour() -> void:
	_piece(Engraving.POINTER, {"sort": Engraving.CATEGORY_DICE})
	var die := _clamped()
	view._on_net_face_pressed(0, die)
	view._on_net_face_pressed(5, die)  # Gegenseite: kein gültiges Ziel
	assert_eq(die.pointers[0], -1, "die Gegenseite wird verweigert")
	assert_eq(view._first_face, 0, "der erste Klick bleibt stehen")
	view._on_net_face_pressed(1, die)
	assert_eq(die.pointers[0], 1, "die Leiterbahn liegt")
	assert_true(run.press_pieces.is_empty())

func test_the_grindstone_moves_one_eye_from_a_to_b() -> void:
	_piece(Engraving.GRINDSTONE)
	var die := _clamped()
	var source := -1
	for face in 6:
		if die.faces[face] > EtchingEffects.MIN_FACE_VALUE:
			source = face
			break
	assert_gt(source, -1, "ein Würfel hat immer eine schleifbare Seite")
	var target := (source + 1) % 6
	var before_source: int = die.faces[source]
	var before_target: int = die.faces[target]
	view._on_net_face_pressed(source, die)
	view._on_net_face_pressed(target, die)
	assert_lt(die.faces[source], before_source, "die Quelle gibt ab")
	assert_gt(die.faces[target], before_target, "das Ziel nimmt auf")

# --- Ganz-Würfel-Werkzeuge: ein Klick genügt ----------------------------------------

func test_a_whole_die_piece_needs_one_click_only() -> void:
	_piece(Engraving.POLISH, {"stufe": 2})
	var die := _clamped()
	var before: Array[int] = die.faces.duplicate()
	view._on_net_face_pressed(2, die)
	for i in 6:
		assert_eq(die.faces[i], before[i] + EtchingEffects.POLISH_LADDER[1], "Seite %d" % i)
	assert_true(run.press_pieces.is_empty())

# --- Material und Runen ---------------------------------------------------------------

func test_a_material_piece_lands_undoped_and_pays_nothing() -> void:
	_piece(DieMaterial.GOLD, {"sort": Engraving.CATEGORY_MATERIAL})
	var die := _clamped()
	var money := run.money
	view._on_net_face_pressed(1, die)
	assert_eq(die.materials[1], DieMaterial.GOLD)
	assert_lt(die.material_level(1), DieMaterial.MAX_LEVEL,
		"aus der Presse kommt Material undotiert")
	assert_eq(run.money, money, "beim Setzen fließt nichts")
	view.apply_placements()
	assert_eq(run.money, money, "und beim Fertig auch nicht - es hat gesessen")

func test_a_rune_piece_places_its_applications_one_by_one() -> void:
	_piece(Engraving.RUNE_PREFIX + Rune.AFTERGLOW,
		{"sort": Engraving.CATEGORY_DICE, "applications": 3})
	var die := _clamped()
	view._on_net_face_pressed(0, die)
	assert_eq(int(run.press_pieces[0]["applications"]), 2, "eine Setzung ist weg")
	view._on_net_face_pressed(1, die)
	view._on_net_face_pressed(2, die)
	assert_eq(die.runes_on(0), [Rune.AFTERGLOW] as Array[String])
	assert_eq(die.runes_on(1), [Rune.AFTERGLOW] as Array[String])
	assert_eq(die.runes_on(2), [Rune.AFTERGLOW] as Array[String])
	assert_true(view.press_piece_counts().is_empty(), "nach der dritten Setzung ist die Hand leer")
	assert_true(view.placing(), "der Schritt steht trotzdem - erst das Fertig macht ihn hart")

# --- Kein Einzelverkauf: die Reste zahlt erst das Fertig ---------------------------------

func test_no_chip_carries_a_way_to_sell_a_single_piece() -> void:
	var uid := _piece(Engraving.NOTCH)
	await wait_frames(2)
	for child in _chip(uid).get_children():
		assert_false(child is Button, "an einem Stück hängt kein eigener Knopf")
	assert_eq(run.money, 0, "und angefasst wird das Geld erst beim Fertig")

func test_the_finish_cashes_the_rest_of_the_hand() -> void:
	_piece(Engraving.NOTCH)
	_piece(Engraving.CHISEL)
	var money := run.money
	view.apply_placements()
	assert_eq(run.money, money + 2 * PhantomPress.FIZZLE_MONEY, "Restwert statt Stille")
	assert_true(run.press_pieces.is_empty())
	assert_false(view.placing(), "und der Schritt ist zu")

func test_the_finish_reports_its_payout_for_the_ceremony() -> void:
	_piece(Engraving.NOTCH)
	await wait_frames(2)
	var seen: Array = []
	view.press_cashed_out.connect(func(amount: int, from_px: Vector2) -> void:
		seen.append([amount, from_px]))
	view.apply_placements()
	assert_eq(seen.size(), 1, "eine Meldung, ein Moment")
	assert_eq(int(seen[0][0]), PhantomPress.FIZZLE_MONEY)
	assert_true(view.bench_rect().has_point(seen[0][1]),
		"die Zahl steigt über der Konsole auf, nicht irgendwo")

func test_a_locked_bench_neither_places_nor_finishes() -> void:
	_piece(Engraving.NOTCH)
	var die := _clamped()
	var before: Array[int] = die.faces.duplicate()
	var money := run.money
	view.editing_locked = true
	view._on_net_face_pressed(0, die)
	view.apply_placements()
	assert_eq(die.faces, before, "während der Runde bleibt die Bank zu")
	assert_eq(run.money, money)
	assert_eq(run.press_pieces.size(), 1, "das Stück wartet auf das nächste Zeitfenster")

# --- Der Schritt hat keine eigene Seite ---------------------------------------------------

func test_the_base_furniture_stands_through_the_whole_placement() -> void:
	# Der Haufen liegt IM Fenster, also bleiben Konsole, Schlitze und Regal stehen.
	_piece(Engraving.NOTCH)
	await wait_frames(2)
	assert_eq(view._press_slot_buttons.size(), PhantomPress.BATCH_CAP, "die sechs Leser stehen")
	assert_not_null(view._shelf, "und das Regal ebenso")
	assert_not_null(view._band, "und das Konsolen-Band der Schürze")
	assert_eq(view._clamp_nets.size(), run.clamped_dice.size(), "die Netzzeile trägt die Ziele")

## Nachpressen ist erlaubt: eine liegende Ablage sperrt das Regal NICHT mehr.
func test_the_bays_stay_open_while_the_loot_lies() -> void:
	run.grant_pack(Pack.number_pack())
	_piece(Engraving.NOTCH)
	await wait_frames(2)
	assert_false(view.shelf_locked(), "der Haufen sperrt nichts")
	assert_true(view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER))

func test_the_seat_carries_the_finish() -> void:
	_piece(Engraving.NOTCH)
	await wait_frames(2)
	assert_null(view._press_button, "ohne eingelegtes Paket steht kein Pressen im Sitz")
	assert_not_null(view._apply_button)
	assert_eq(view._apply_button.text, "Fertig")
	assert_eq(view._apply_button.get_global_rect(), _seat().get_global_rect(),
		"das Fertig füllt den EINEN Sitz")
	assert_gt(_seat().get_global_rect().position.x,
		view.get_node("PressBand/PressConsole").get_global_rect().end.x,
		"der rechts vom Blech steht")

## Steckt ein Paket, gewinnt das Pressen den Sitz - nachpressen ist der Zug, und
## das Rechteck bleibt dasselbe.
func test_a_slotted_pack_takes_the_seat_back_from_the_finish() -> void:
	run.grant_pack(Pack.number_pack())
	_piece(Engraving.NOTCH)
	await wait_frames(2)
	var rect := view._apply_button.get_global_rect()
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	await wait_frames(2)
	assert_null(view._apply_button)
	assert_not_null(view._press_button)
	assert_eq(view._press_button.get_global_rect(), rect, "derselbe Sitz")

func test_the_finish_ends_the_step_even_with_a_full_hand() -> void:
	# Nichts bleibt zurück: was nicht sitzt, ist Geld geworden.
	_piece(Engraving.NOTCH)
	view.apply_placements()
	await wait_frames(2)
	assert_false(view.placing())
	assert_eq(view._press_slot_buttons.size(), PhantomPress.BATCH_CAP, "die Grundseite steht wieder")
	assert_null(view._apply_button, "und das Fertig ist fort")
	assert_null(view._ablage_host, "der Haufen ist fort")

# --- Fertig: erst hier wird der Guss hart -----------------------------------------------

func test_the_step_stands_with_an_empty_hand_until_it_is_finished() -> void:
	_piece(Engraving.NOTCH)
	view._on_net_face_pressed(0, _clamped())
	await wait_frames(2)
	assert_true(view.press_piece_counts().is_empty(), "die Hand ist leer")
	assert_true(view.placing(), "der Schritt bleibt trotzdem stehen")
	assert_eq(view.held_uid(), 0, "und kein Stück ist mehr geführt")
	assert_not_null(view._apply_button, "Fertig steht bereit")
	assert_false(view._apply_button.disabled)
	view._apply_button.pressed.emit()
	await wait_frames(2)
	assert_false(view.placing(), "danach gehört die Bank wieder der Grundseite")
	assert_true(run.press_journal.is_empty(), "der Guss ist hart")
	assert_eq(view._press_slot_buttons.size(), PhantomPress.BATCH_CAP)

## Der Knopf ist der einzige Abschluss - also steht er auch mit voller Hand offen.
func test_fertig_stands_open_while_pieces_are_still_lying() -> void:
	_piece(Engraving.NOTCH)
	_piece(Engraving.CHISEL)
	view._on_net_face_pressed(0, _clamped())  # die Kerbe sitzt, der Meißel liegt noch
	await wait_frames(2)
	assert_not_null(view._apply_button)
	assert_false(view._apply_button.disabled)
	view.apply_placements()
	assert_true(run.press_journal.is_empty(), "der Guss ist hart")
	assert_eq(run.money, PhantomPress.FIZZLE_MONEY, "und der Meißel wurde zu Geld")

func test_a_locked_bench_never_applies() -> void:
	_piece(Engraving.NOTCH)
	view._on_net_face_pressed(0, _clamped())
	view.editing_locked = true
	await wait_frames(2)
	assert_true(view._apply_button.disabled)
	view.apply_placements()
	assert_eq(run.press_journal.size(), 1, "der Guss bleibt nass")

func test_a_lapse_from_outside_ends_the_step_the_same_way() -> void:
	# Die Unterschrift der Runde nimmt alles mit - die Bank braucht dafür keinen
	# eigenen Weg, press_changed baut sie zurück auf die Grundseite.
	_piece(Engraving.NOTCH)
	var die := _clamped()
	var before: Array[int] = die.faces.duplicate()
	view._on_net_face_pressed(0, die)
	run.lapse_press()
	await wait_frames(2)
	assert_false(view.placing())
	assert_eq(die.faces, before, "und die Setzung ist zurückgenommen")
	assert_eq(run.money, 0)

func test_the_step_survives_a_rebuild_of_the_window() -> void:
	# Er hängt allein an der offenen Beute - damit übersteht er jede Kamerafahrt,
	# den Laden und jeden Neuaufbau; die Nummern reisen in GameRun mit.
	_piece(Engraving.NOTCH)
	var second := _piece(Engraving.CHISEL)
	view.hold_piece(second)
	view.refresh()
	await wait_frames(2)
	assert_true(view.placing(), "der Schritt steht noch")
	assert_eq(view.held_uid(), second, "und führt dasselbe Stück")
	assert_eq(view.held_piece_id(), Engraving.CHISEL)
	assert_true(_held_frame(second))

func test_a_new_run_drops_the_open_hand() -> void:
	_piece(Engraving.NOTCH)
	view.run = GameRun.new_run()
	assert_false(view.placing(), "die Beute gehörte dem alten Lauf")
	assert_eq(view.held_uid(), 0)

# --- Der nasse Guss: Plaketten im Netz ----------------------------------------------

func test_a_placed_piece_shows_as_a_wet_mark_on_its_cell() -> void:
	_piece(Engraving.NOTCH)
	var die := _clamped()
	view._on_net_face_pressed(0, die)
	var marks := run.press_face_marks(die)
	assert_true(marks.has(0), "die berührte Seite trägt ihre Plakette")
	assert_true(bool(marks[0]["wet"]), "und zwar nass")

func test_unseating_a_wet_mark_returns_the_piece_to_its_own_spot() -> void:
	var uid := _piece(Engraving.NOTCH, {"stufe": 3})
	var die := _clamped()
	var before: int = die.faces[0]
	var spot := view.ablage_spot(uid)
	view._on_net_face_pressed(0, die)
	assert_true(view.press_piece_counts().is_empty(), "das Stück sitzt")
	view._on_net_mark_pressed(0, die)
	await wait_frames(2)
	assert_eq(die.faces[0], before, "die Seite steht wieder wie davor")
	assert_eq(view.ablage_spot(uid), spot, "und das Stück liegt auf SEINEM Platz zurück")
	assert_not_null(_chip(uid))
	assert_eq(view.held_uid(), uid, "das die Führung wieder übernimmt")
	assert_eq(int(view.press_piece_counts().get(Engraving.NOTCH, 0)), 1)

func test_the_mark_travels_into_the_net_that_shows_it() -> void:
	var first := _piece(Engraving.NOTCH)
	var die := _clamped()
	_piece(Engraving.CHISEL)  # ein zweites Stück hält den Schritt offen
	view.hold_piece(first)
	view._on_net_face_pressed(0, die)
	await wait_frames(2)
	var net := _net_of(die)
	assert_not_null(net)
	assert_true(net.marks.has(0), "das Netz kennt seine nasse Setzung")

func test_a_locked_bench_unseats_nothing() -> void:
	_piece(Engraving.NOTCH)
	var die := _clamped()
	view._on_net_face_pressed(0, die)
	var faces: Array[int] = die.faces.duplicate()
	view.editing_locked = true
	view._on_net_mark_pressed(0, die)
	assert_eq(die.faces, faces, "während der Runde bleibt der Guss, wo er ist")
	assert_eq(run.press_journal.size(), 1)

func test_the_hardened_journal_leaves_no_mark() -> void:
	_piece(Engraving.NOTCH)
	var die := _clamped()
	view._on_net_face_pressed(0, die)
	view.apply_placements()
	assert_true(run.press_face_marks(die).is_empty(), "nach dem Fertig nichts mehr")

# --- Der Hinweis-Schirm: der Chip nennt sein Stück -----------------------------------------

func test_a_lying_chip_explains_its_piece() -> void:
	var uid := _piece(Engraving.CHISEL)
	await wait_frames(2)
	var chisel := Engraving.chisel()
	var hint := view.chip_hint_at(view.ablage_spot_px(uid))
	assert_eq(String(hint.get("title", "")), chisel.display_name)
	assert_eq(String(hint.get("body", "")), Engraving.stufe_text(Engraving.CHISEL, 1),
		"aus der Presse kommt jedes Stück auf Stufe 1")
	assert_true(view.chip_hint_at(Vector2(-500, -500)).is_empty(), "daneben schweigt er")
