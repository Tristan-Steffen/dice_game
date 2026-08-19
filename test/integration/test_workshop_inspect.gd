extends GutTest
## Das Dossier: ein getippter Tray-Würfel kommt auf die Bank und wird ANGESEHEN -
## links seine Bühne (dort schwebt sein echter Körper, den stellt scene_root auf),
## darunter sein Netz mit Namen und Augensumme, rechts der Pool, aus dem der
## nächste gewählt wird. Reine Auskunft: kein Werkzeug, kein Umlegen.

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	view.size = Vector2(roundf(540.0 * WorkshopView.dossier_aspect()), 540)
	add_child_autofree(view)
	view.run = run

func _open(index := 3) -> DieDefinition:
	var die := run.owned_pool[index]
	assert_true(view.open_inspect(die), "das Dossier geht auf")
	return die

# --- Die Seite ------------------------------------------------------------------

func test_the_page_shows_the_die_its_net_and_its_numbers() -> void:
	var die := _open()
	await wait_frames(2)
	assert_true(view.inspecting())
	assert_eq(view.inspected_die(), die, "und zwar GENAU diese Instanz")
	assert_not_null(view._content.get_node("InspectBody/InspectSide/InspectStage"),
		"die Bühne des schwebenden Würfels")
	assert_not_null(view._content.get_node("InspectBody/InspectSide/InspectNet"),
		"sein Würfelnetz darunter")
	var texts: Array[String] = []
	for child in view._content.get_node("InspectBody/InspectSide").get_children():
		if child is Label:
			texts.append((child as Label).text)
	assert_true(texts.has(die.display_name), "sein Name steht darunter")
	assert_true(texts.has("Augensumme %d" % DiceRowView.eye_total(die)), "und seine Augensumme")

func test_the_stage_center_is_reported_for_the_real_die() -> void:
	_open()
	await wait_frames(2)
	var center := view.inspect_stage_center()
	assert_gt(center.x, 0.0, "die Bühne meldet ihren Platz")
	assert_true(view.get_global_rect().has_point(center), "und er liegt im Fenster")

func test_the_die_is_the_pool_instance_never_a_copy() -> void:
	var die := _open(7)
	assert_true(view.inspected_die() == run.owned_pool[7], "dieselbe Instanz")

func test_the_grid_stands_right_of_the_die_and_carries_the_drag() -> void:
	# Getippt wechselt das Dossier, GEZOGEN legt der Vorrat um - dieselbe Teilung
	# wie im Pool-Tray, und seit der Paket-Platzierung die zweite Stelle dafür.
	_open()
	await wait_frames(2)
	assert_not_null(view._pool_grid, "das Raster steht")
	assert_true(view._pool_grid.reorder_enabled, "und trägt die Zieh-Geste")
	assert_eq(view._pool_grid.tiles.size(), run.owned_pool.size(), "der GANZE Besitz")
	var side: Control = view._content.get_node("InspectBody/InspectSide")
	assert_gt(view._pool_grid.get_global_rect().position.x, side.get_global_rect().position.x,
		"das Raster steht rechts vom Würfel")

func test_the_grid_fills_its_region_flush() -> void:
	# Die Fensterbreite ist GENAU auf diese Seite gelöst: 6x5 Kacheln spannen den
	# rechten Bereich, oben, unten und rechts bleibt kein totes Band.
	_open()
	await wait_frames(2)
	var host: Control = view._content.get_node("InspectBody/PoolHost")
	_assert_grid_fills(host, "die gelöste Breite")

func test_the_solved_aspect_is_what_makes_it_close() -> void:
	# Die Gleichung ist ein reines Verhältnis - sie darf nicht an der Höhe hängen.
	var narrow := WorkshopView.dossier_aspect()
	assert_gt(narrow, 1.0, "die Bank ist breiter als hoch")
	view.size = Vector2(roundf(400.0 * narrow), 400)
	_open()
	await wait_frames(2)
	_assert_grid_fills(view._content.get_node("InspectBody/PoolHost"), "andere Höhe")

## Restluft im Prozent-Bereich: der Kasten rundet jede Fuge auf GANZE Pixel ab,
## ein totes Band wäre etwas anderes (vorher stand oben und unten je ein Siebtel).
func _assert_grid_fills(host: Control, what: String) -> void:
	var grid := view._pool_grid.get_global_rect()
	var region := host.get_global_rect()
	assert_lt(region.size.x - grid.size.x, region.size.x * 0.02,
		"%s: das Raster füllt die Breite" % what)
	assert_lt(region.size.y - grid.size.y, region.size.y * 0.02,
		"%s: und die Höhe" % what)
	assert_almost_eq(grid.get_center().x, region.get_center().x, 4.0)
	assert_almost_eq(grid.get_center().y, region.get_center().y, 4.0)

func test_the_die_column_stands_vertically_centered() -> void:
	_open()
	await wait_frames(2)
	var side: Control = view._content.get_node("InspectBody/InspectSide")
	var top: Control = side.get_node("InspectSlackTop")
	var bottom: Control = side.get_node("InspectSlackBottom")
	assert_gt(top.size.y, 0.0, "über dem Würfel bleibt Luft")
	assert_almost_eq(top.size.y, bottom.size.y, 2.0, "und unten genau dieselbe")

func test_the_die_stands_over_its_net_not_on_it() -> void:
	_open()
	await wait_frames(2)
	var side: Control = view._content.get_node("InspectBody/InspectSide")
	var stage: Control = side.get_node("InspectStage")
	var net: Control = side.get_node("InspectNet")
	var u := view.size.x / 100.0
	var air := net.get_global_rect().position.y - stage.get_global_rect().end.y
	assert_almost_eq(air, u * WorkshopView.INSPECT_NET_GAP, 2.0,
		"die gemessene Luft IST die Konstante")
	assert_gt(air, u * WorkshopView.INSPECT_LINE_GAP * 1.9,
		"mehr als der doppelte Zeilenabstand")

func test_the_shown_die_is_highlighted_in_the_grid() -> void:
	_open(5)
	await wait_frames(2)
	assert_eq(view._highlighted_slots(), [5] as Array[int])

func test_clicking_a_tile_switches_the_shown_die() -> void:
	_open(3)
	await wait_frames(2)
	view.inspect_slot(11)
	await wait_frames(2)
	assert_eq(view.inspected_die(), run.owned_pool[11], "das Dossier wechselt")
	assert_eq(view._highlighted_slots(), [11] as Array[int], "die Hervorhebung wandert mit")
	assert_true(view.inspecting(), "und die Seite bleibt stehen")

func test_the_net_cells_explain_themselves_on_the_hover_card() -> void:
	var die := _open()
	die.set_face_material(0, DieMaterial.GOLD)
	view.refresh()
	await wait_frames(2)
	var net: Control = view._content.get_node("InspectBody/InspectSide/InspectNet")
	var cell := view.size.x / 100.0 * WorkshopView.CHOICE_CELL
	var pixel := net.get_global_rect().position + DieNetView.cell_position(0, cell) \
		+ Vector2.ONE * cell * 0.5
	assert_eq(view.net_hint_at(pixel), DieNetView.hint_for(die, 0),
		"dieselbe Quelle wie jedes andere Netz")

# --- Wann sie aufgeht, und wie sie wieder zugeht ---------------------------------

func test_the_page_opens_only_from_the_base_page() -> void:
	run.stash_die(DieDefinition.fixed(6, "Sechser"), 0)
	assert_true(view.open_exchange(0), "der Tausch-Wähler nimmt die Bank")
	assert_false(view.open_inspect(run.owned_pool[0]), "daneben geht kein Dossier auf")
	view.close_exchange()
	assert_true(view.open_inspect(run.owned_pool[0]), "danach schon")

func test_a_die_outside_the_pool_has_no_dossier() -> void:
	assert_false(view.open_inspect(DieDefinition.standard()), "Fremdwürfel: nichts")
	assert_false(view.open_inspect(null))

func test_right_click_steps_back_to_the_base_page() -> void:
	_open()
	await wait_frames(2)
	assert_true(view.go_back(), "der Schritt zurück gehört dem Ablauf, nicht der Kamera")
	await wait_frames(2)
	assert_false(view.inspecting())
	assert_null(view.inspected_die())
	assert_eq(view._clamp_nets.size(), run.clamped_dice.size(), "die Aufspannung steht wieder")

func test_the_clamps_leave_with_the_window() -> void:
	assert_true(view.clamps_on_bench(), "auf der Grundseite stehen sie")
	_open()
	await wait_frames(2)
	assert_false(view.clamps_on_bench(),
		"im Dossier nicht - sonst hinge eine Zwinge über der Seite, die sie zeigt")
	assert_eq(view._clamp_nets.size(), 0)

func test_the_shelf_locks_while_the_dossier_stands() -> void:
	run.grant_pack(Pack.number_pack())
	assert_false(view.shelf_locked())
	_open()
	await wait_frames(2)
	assert_true(view.shelf_locked(), "niemand legt nebenher ein Paket ein")
	assert_false(view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER))

func test_the_apron_stands_through_the_dossier() -> void:
	# Die Schürze gehört der Bank, nicht einem Ablauf.
	await wait_frames(2)
	var slits: Array[Rect2] = []
	for slit in view._press_slit_panels:
		slits.append(slit.get_global_rect())
	_open()
	await wait_frames(2)
	assert_not_null(view._drawer, "die Buchten stehen")
	assert_not_null(view._band, "und das Konsolen-Band")
	for i in slits.size():
		assert_eq(view._press_slit_panels[i].get_global_rect(), slits[i],
			"Schlitz %d steht unverrückt" % i)

func test_the_dossier_touches_no_state_at_all() -> void:
	# Reine ANZEIGE: die Seite verschiebt Sitze, nicht Besitz. Weder der Vorrat
	# noch die Aufspannung darf sich beim Auf- und Zumachen bewegen.
	var pool := run.owned_pool.duplicate()
	var clamped := run.clamped_dice.duplicate()
	_open()
	await wait_frames(2)
	assert_eq(run.owned_pool, pool, "der Vorrat steht unverändert")
	assert_eq(run.clamped_dice, clamped, "und die Aufspannung auch")
	view.inspect_slot(11)
	view.close_inspect()
	await wait_frames(2)
	assert_eq(run.owned_pool, pool, "auch nach Wechsel und Schließen")
	assert_eq(run.clamped_dice, clamped)

func test_a_run_change_drops_the_dossier() -> void:
	_open()
	await wait_frames(2)
	view.run = GameRun.new_run()
	await wait_frames(2)
	assert_false(view.inspecting(), "ein Würfel des alten Laufs steht nicht weiter da")
	assert_null(view.inspected_die())

# --- Gleicher Rand ringsum ---------------------------------------------------------
## Das Raster steht in EINEM Rand: was es nach oben, unten und zu seiner Spalte
## hin frei lässt, ist derselbe Spalt wie zum rechten Fensterrand. Vorher trug die
## Seite den flacheren Zeilenrand und das Raster hing oben und unten zu dicht.

func test_the_grid_keeps_one_margin_on_every_side() -> void:
	_open()
	await wait_frames(2)
	var u := view.size.x / 100.0
	var grid := view._pool_grid.get_global_rect()
	var window := view.get_global_rect()
	var side: Control = view._content.get_node("InspectBody/InspectSide")
	var margin := u * WorkshopView.CONTENT_MARGIN_X
	assert_almost_eq(window.end.x - grid.end.x, margin, 4.0, "rechts der Fensterrand")
	assert_almost_eq(grid.position.y - window.position.y, margin, 4.0, "oben derselbe")
	assert_almost_eq(window.end.y - grid.end.y, margin, 4.0, "unten derselbe")
	assert_almost_eq(grid.position.x - side.get_global_rect().end.x, margin, 4.0,
		"und zur Würfelspalte hin derselbe")

## Eine Zahl, vier Abstände: die Fuge IST der Seitenrand. Driften die beiden, steht
## das Raster wieder schief in seinem Rahmen.
func test_the_body_gap_is_the_content_margin() -> void:
	assert_eq(WorkshopView.BODY_GAP, WorkshopView.CONTENT_MARGIN_X)

# --- Der Griff ins Tray wechselt wie der Griff ins Raster ---------------------------

func test_a_second_die_switches_the_open_dossier() -> void:
	# Derselbe Weg wie eine Raster-Kachel: das Dossier bleibt stehen und zeigt den
	# neuen Würfel - es geht nicht zu und wieder auf.
	var first := _open(3)
	await wait_frames(2)
	var second := run.owned_pool[7]
	assert_true(view.open_inspect(second), "aus dem Dossier heraus geht der nächste auf")
	await wait_frames(2)
	assert_true(view.inspecting(), "die Seite steht weiter")
	assert_eq(view.inspected_die(), second, "und zeigt den neuen Würfel")
	assert_ne(view.inspected_die(), first)

func test_tapping_the_shown_die_again_changes_nothing() -> void:
	var die := _open(3)
	await wait_frames(2)
	assert_true(view.open_inspect(die), "er steht schon da - das ist kein Fehlschlag")
	assert_eq(view.inspected_die(), die)
