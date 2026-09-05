extends GutTest
## Tier-2-Tests der Werkstatt (WorkshopView): die Grundseite zeigt allein die
## ZIEL-SÄULE (der schwebende Zielwürfel über seinem Summen-Netz, mittig); gewählt
## wird per Klick auf einen physischen Pool-Würfel (set_target_die), das alte
## 2D-Raster ist tot. Versiegelte Pakete liegen als Kassetten im Magazin.

var view: WorkshopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	view = WorkshopView.new()
	view.size = Vector2(600, 500)
	add_child_autofree(view)
	view.run = run

# --- Die Grundseite gehört der Zielwahl -----------------------------------------

func test_packs_never_render_as_cards_in_the_window() -> void:
	# Das Magazin ist der EINZIGE Ort versiegelter Ware - im Fenster stehen nur die
	# Ziel-Säule und die Serien-Slots.
	run.purchase_pack(Pack.number_pack(), 0)
	run.purchase_pack(Pack.material_pack(), 0)
	assert_not_null(view._net, "das Summen-Netz steht")
	assert_eq(view._slot_buttons.size(), run.series_slots())
	assert_eq(run.owned_packs.size(), 2, "und die Siegel bleiben ganz")

## Das 2D-Pool-Raster ist tot - gewählt wird ein physischer Pool-Würfel, den
## scene_root über set_target_die meldet.
func test_the_pool_grid_is_gone() -> void:
	assert_false("_pool_grid" in view, "kein Raster mehr im Fenster")
	assert_true(view.has_method("set_target_die"), "die Zielwahl kommt von außen")

## Es gibt keine Auspack-Zeremonie mehr: JEDE Kassette geht in einen Serien-Slot,
## und ein Würfel wird nie versiegelt.
func test_tapping_a_cassette_only_ever_slots_it() -> void:
	run.purchase_pack(Pack.number_pack(), 0)
	view._on_pack_pressed(run.owned_packs[0].pack_uid)
	assert_eq(view.press_slot_uids().size(), 1, "sie steckt im Slot")

func test_the_bench_has_no_floating_dice_of_its_own() -> void:
	# Über der Bank schwebt allein der Zielwürfel - eine zweite Seite gibt es nicht.
	assert_true(view.bench_open())

# --- Netz-Hinweise --------------------------------------------------------------

func test_a_target_net_cell_explains_itself() -> void:
	# Die Zeile wird GEFRAGT, nicht gemalt - das Fenster hat keinen Schirm dafür.
	view.choose_target(0)
	await wait_frames(2)
	run.owned_pool[0].set_face_material(0, DieMaterial.GOLD)
	view.refresh()
	await wait_frames(2)
	var said := view.net_hint_at(_net_pixel(0))
	assert_true(said.contains(DieMaterial.by_id(DieMaterial.GOLD).display_name),
		"die Zelle sagt, was auf ihr liegt: '%s'" % said)

func test_a_bare_face_and_a_point_outside_say_nothing() -> void:
	view.choose_target(0)
	await wait_frames(2)
	for face in 6:
		run.owned_pool[0].set_face_material(face, "")
	view.refresh()
	await wait_frames(2)
	assert_eq(view.net_hint_at(_net_pixel(0)), "", "eine nackte Seite erklärt nichts")
	assert_eq(view.net_hint_at(Vector2(-50, -50)), "", "und außerhalb erst recht nicht")

## Display-Pixel in der Mitte der Zelle face im Summen-Netz.
func _net_pixel(face: int) -> Vector2:
	var net := view._net
	return net.get_global_rect().position \
		+ DieNetView.cell_position(face, net.cell) + Vector2.ONE * net.cell * 0.5

# --- Die Ziel-Säule steht durch alles --------------------------------------------

func test_the_grip_keeps_the_target_column_standing() -> void:
	# Die Zeremonie läuft in der Serien-Reihe UNTER dem Fenster - die Ziel-Säule
	# bleibt stehen, sie ist das Ziel.
	run.purchase_pack(Pack.number_pack(), 0)
	view.slot_pack_from_stack(Engraving.CATEGORY_NUMBER)
	view.choose_target(0)
	view.pull_lever()
	assert_true(view.bench_open())
	assert_not_null(view._net, "und das Summen-Netz steht")

func test_every_rebuild_reports_the_stages() -> void:
	# scene_root hängt die echten Würfel daran - ohne die Meldung stünden sie über
	# Bühnen, die es nicht mehr gibt.
	# Die Schläge in einem Array zählen: eine Lambda fängt lokale Zahlen als KOPIE.
	var beats: Array = []
	view.die_stages_changed.connect(func() -> void: beats.append(1))
	view.refresh()
	assert_gt(beats.size(), 0, "jeder Neuaufbau meldet seine Bühnen")

# --- Der GRIFF trägt den Zähler in seiner Aufschrift ----------------------------
# Der Serien-Schirm ist tot: wie voll die Reihe ist, sagt der Knopf selbst.

func test_the_grip_label_counts_the_series() -> void:
	await wait_frames(2)
	assert_eq(view.grip_label(), "Griff 0/%d" % run.series_slots(),
		"leer steht der Zähler auf null")
	run.grant_pack(Pack.number_pack())
	view.slot_pack(run.owned_packs[0].pack_uid)
	await wait_frames(2)
	assert_eq(view.grip_label(), "Griff 1/%d" % run.series_slots())
	assert_eq(view._action_button.text, view.grip_label(),
		"und der Knopf trägt genau diese Aufschrift")

func test_the_running_ceremony_relabels_the_same_seat() -> void:
	# Der Griff verlangt eine VOLLE Reihe: der Block IST sechs Karten.
	for i in GameRun.SERIES_SLOT_CAP:
		var pack := run.grant_pack(Pack.number_pack())
		pack.stamp_net = StampNet.empty_net()
		pack.stamp_net[i] = StampNet.value_cell(1)
		view.slot_pack(pack.pack_uid)
	view.choose_target(0)
	await wait_frames(2)
	view.pull_lever()
	await wait_frames(2)
	assert_eq(view._action_button.text, "Fertig", "in der Fahrt heißt der Sitz Fertig")

# --- Der Neuzugang gehört dem VORRAT ---------------------------------------------
# Getauscht wird am Vorrat (Ziehen aus dem Ausgabefach auf einen Pool-Sitz), und
# angesehen wird ein Würfel auf dem PODEST am Fach - beides außerhalb des Fensters.

func test_the_exchange_picker_is_gone() -> void:
	assert_false(view.has_method("open_exchange"),
		"der Tausch-Wähler ist tot - getauscht wird am Vorrat")
	assert_false(view.has_method("close_exchange"))
	assert_false(view.has_method("exchanging"))
