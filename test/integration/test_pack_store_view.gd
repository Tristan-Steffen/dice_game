extends GutTest
## Das PAKET-LAGER: drei RINNEN übereinander (Karten, Würfel, Module) zu je acht Plätzen
## in EINER Lage; die Pakete stehen hochkant, von oben liest ihr Rücken. Die Breite folgt
## dem dicksten Paket, die Höhe ist die des Chip-Trays.

## Der Rücken des dicksten Pakets (Schatulle) quer zur Rinne (gemessen 2026-11-14).
const SPINE := Vector2(58.1, 134.8)
## Die Höhe von Wett-Tresen und Chip-Tray (gemessen 2026-11-13).
const TRAY_HEIGHT := 570.0
## Die Schatulle quer (CardPackView.max_case_across, gerechnet 2026-11-14 ohne Eckkappen).
const WIDEST_CASE := 134.8

func _store(spine := SPINE) -> PackStoreView:
	var store := PackStoreView.new()
	add_child_autofree(store)
	store.spine_px = spine
	store.lane_across.assign([spine.y, WIDEST_CASE, spine.y])
	store.size = Vector2(store.preferred_size().x, TRAY_HEIGHT)
	store.visible = true
	return store

func test_twelve_places_per_lane_without_layers() -> void:
	var store := _store()
	assert_eq(PackStoreView.PLACES, GameRun.STORE_CAPACITY, "ein Platz je Paket, keine Lage")
	assert_eq(PackStoreView.LANES, GameRun.STORE_LANES, "eine Rinne je Lager-Reihe")
	var bounds := Rect2(Vector2.ZERO, store.size)
	for lane in PackStoreView.LANES:
		var pit := store.lane_pit_rect(lane)
		assert_true(bounds.encloses(pit), "die Rinne liegt in der Fassung")
		var last := pit.position.x
		for index in PackStoreView.PLACES:
			var slot := store.slot_rect(lane, index)
			assert_true(pit.encloses(slot), "Platz %d liegt in seiner Rinne" % index)
			assert_gte(slot.position.x, last - 0.01, "Platz %d rechts vom vorigen" % index)
			last = slot.end.x
			var spine := Rect2(store.slot_center(lane, index) - SPINE * 0.5, SPINE)
			assert_true(slot.encloses(spine), "der dickste Rücken paßt in Platz %d" % index)
	assert_lt(store.slot_center(GameRun.LANE_CARDS, 0).x,
		store.slot_center(GameRun.LANE_CARDS, 1).x, "Platz 0 links am Tray")

func test_the_lanes_lie_one_above_the_other() -> void:
	var store := _store()
	var cards := store.lane_pit_rect(GameRun.LANE_CARDS)
	var dice := store.lane_pit_rect(GameRun.LANE_DICE)
	var modules := store.lane_pit_rect(GameRun.LANE_MODULES)
	assert_lt(cards.end.y, dice.position.y, "Karten oben, Würfel darunter")
	assert_lt(dice.end.y, modules.position.y, "die Module unten")
	assert_eq(cards.position.x, modules.position.x, "bündig untereinander")
	assert_gte(cards.size.y, SPINE.y, "die Rinne trägt die kurze Seite")
	for lane in PackStoreView.LANES:
		assert_false(store.lane_head_rect(lane).intersects(store.lane_pit_rect(lane)))
		if lane > 0:
			assert_false(store.lane_head_rect(lane).grow(-0.01).intersects(store.lane_pit_rect(lane - 1)),
				"der Kopf steht zwischen zwei Rinnen")
	assert_lte(store.min_height(), TRAY_HEIGHT, "drei Köpfe und Rinnen passen in die Tray-Höhe")
	assert_almost_eq(modules.end.y, TRAY_HEIGHT - store.frame_px(), 0.01,
		"die Rinnen nehmen die volle Höhe")

func test_the_width_follows_the_thickest_pack() -> void:
	var store := _store()
	var places := float(PackStoreView.PLACES)
	assert_almost_eq(store.size.x, (SPINE.x + store.gap_px()) * places + store.edge_px() * 2.0
		+ store.frame_px() * 2.0, 0.01, "alle Rücken samt Fuge und Rand")
	var thick := _store(Vector2(SPINE.x * 1.5, SPINE.y))
	assert_almost_eq(thick.preferred_size().x - store.preferred_size().x,
		SPINE.x * 0.5 * (1.0 + PackStoreView.GAP_SHARE) * places, 0.01, "dicker heißt breiter")
	assert_lt(store.size.x, 900.0, "deutlich schmaler als die drei Gruben (1354,6 px)")

func test_a_thin_pack_is_hit_across_the_whole_lane() -> void:
	var store := _store()
	var slot := store.slot_rect(GameRun.LANE_DICE, 4)
	var pit := store.lane_pit_rect(GameRun.LANE_DICE)
	assert_eq(slot.position.y, pit.position.y, "quer über die volle Rinne")
	assert_eq(slot.size.y, pit.size.y)
	# Ein dünner Beutel steht mittig; sein Platz ist trotzdem die ganze Teilung.
	for at: Vector2 in [slot.position + Vector2(1, 1), slot.get_center(), slot.end - Vector2(1, 1)]:
		assert_eq(store.slot_at(at), {"lane": GameRun.LANE_DICE, "index": 4})
	var last := PackStoreView.PLACES - 1
	assert_eq(store.slot_at(store.slot_center(GameRun.LANE_MODULES, last)),
		{"lane": GameRun.LANE_MODULES, "index": last})
	assert_eq(store.slot_at(store.lane_head_rect(GameRun.LANE_CARDS).get_center()), {},
		"der Kopf ist kein Platz")
	assert_eq(store.slot_at(Vector2(-10, -10)), {}, "neben den Plätzen ist keiner")

func test_the_head_names_count_and_lock() -> void:
	var store := _store()
	store.set_state([3, 12, 1], true)
	assert_eq(PackStoreView.head_text(GameRun.LANE_CARDS, 3, false), "KARTEN-PAKETE  3/8")
	assert_eq(PackStoreView.head_text(GameRun.LANE_MODULES, 1, false), "MODUL-PAKETE  1/8")
	assert_true(PackStoreView.head_text(GameRun.LANE_DICE, 12, true).contains("nach der Runde"),
		"gesperrt sagt der Kopf warum")
	assert_true(store.locked)
	assert_eq(store.counts, [3, 12, 1] as Array[int])

## Die Würfel-Rinne faßt die breiteste Schatulle quer, und doch passen alle drei in die Tray-Höhe.
func test_the_dice_lane_holds_the_widest_case() -> void:
	var store := _store()
	var dice := store.lane_pit_rect(GameRun.LANE_DICE)
	assert_gte(dice.size.y, WIDEST_CASE + store.edge_px() * 2.0, "die Schatulle paßt quer hinein")
	assert_gte(dice.size.y, store.lane_pit_rect(GameRun.LANE_CARDS).size.y, "nie niedriger als die anderen")
	assert_lte(store.min_height(), TRAY_HEIGHT)
	var case := Rect2(store.slot_center(GameRun.LANE_DICE, 0) - Vector2(SPINE.x, WIDEST_CASE) * 0.5,
		Vector2(SPINE.x, WIDEST_CASE))
	assert_true(dice.encloses(case))
