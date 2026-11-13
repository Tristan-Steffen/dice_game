extends GutTest
## Das PAKET-LAGER: drei Gruben NEBENEINANDER (Karten, Würfel, Module) zu je sechs
## sichtbaren Plätzen (2 × 3, volle Paketbreite); ab dem siebten Paket einer Art liegt eine
## zweite LAGE darauf. Die Breite folgt dem Inhalt, die Höhe ist die des Chip-Trays.

const ITEM := Vector2(202.2, 134.8)
## Die Höhe von Wett-Tresen und Chip-Tray (gemessen 2026-11-13).
const TRAY_HEIGHT := 570.0

func _store() -> PackStoreView:
	var store := PackStoreView.new()
	add_child_autofree(store)
	store.item_px = ITEM
	store.size = Vector2(store.preferred_size().x, TRAY_HEIGHT)
	store.visible = true
	return store

func test_six_places_per_pit_fit_without_overlap() -> void:
	var store := _store()
	var bounds := Rect2(Vector2.ZERO, store.size)
	var taken: Array[Rect2] = []
	for lane in PackStoreView.LANES:
		var pit := store.lane_pit_rect(lane)
		assert_true(bounds.encloses(pit), "die Grube liegt in der Fassung")
		for place in PackStoreView.PLACES:
			var slot := Rect2(store.slot_center(lane, place) - ITEM * 0.5, ITEM)
			assert_true(pit.encloses(slot), "Platz %d liegt ganz in seiner Grube" % place)
			for other in taken:
				assert_false(other.intersects(slot.grow(-0.5)), "Plätze überlappen nicht")
			taken.append(slot)
	assert_eq(taken.size(), 18)
	assert_eq(PackStoreView.LANES, GameRun.STORE_LANES, "eine Grube je Lager-Reihe")
	assert_eq(PackStoreView.ROWS, 3, "drei Reihen")
	assert_eq(PackStoreView.PLACES * PackStoreView.LAYERS, GameRun.STORE_CAPACITY,
		"sechs Plätze in zwei Lagen tragen genau die Kapazität einer Art")
	assert_eq(GameRun.STORE_CAPACITY, 12)
	assert_eq(PackStoreView.PLACES, GameRun.STORE_PLACES)

func test_the_upper_layer_lies_over_the_lower() -> void:
	var store := _store()
	for place in PackStoreView.PLACES:
		assert_eq(store.slot_center(GameRun.LANE_MODULES, place + PackStoreView.PLACES),
			store.slot_center(GameRun.LANE_MODULES, place),
			"Platz %d liegt über Platz %d" % [place + 6, place])

func test_the_pits_stand_side_by_side_two_packs_wide() -> void:
	var store := _store()
	var cards := store.lane_pit_rect(GameRun.LANE_CARDS)
	var dice := store.lane_pit_rect(GameRun.LANE_DICE)
	var modules := store.lane_pit_rect(GameRun.LANE_MODULES)
	assert_lt(cards.end.x, dice.position.x, "Karten links, Würfel daneben")
	assert_lt(dice.end.x, modules.position.x, "die Module rechts davon")
	assert_eq(cards.position.y, modules.position.y, "auf derselben Höhe")
	assert_almost_eq(modules.size.x, ITEM.x * 2.0 + store.gap_px() + store.edge_px() * 2.0, 0.01,
		"je Grube zwei Pakete samt Rand")
	assert_gt(store.edge_px(), store.gap_px(), "der Rand quetscht nicht")
	for lane in PackStoreView.LANES:
		assert_false(store.lane_head_rect(lane).intersects(store.lane_pit_rect(lane)))

func test_the_width_follows_the_content_and_the_height_the_tray() -> void:
	var store := _store()
	assert_almost_eq(store.size.x, store.pit_width() * 3.0 + store.frame_px() * 6.0, 0.01)
	assert_almost_eq(store.lane_pit_rect(GameRun.LANE_MODULES).end.x,
		store.size.x - store.frame_px(), 0.01, "die dritte Grube endet am Rahmen")
	assert_lte(store.min_height(), TRAY_HEIGHT, "Kopf und drei Reihen passen in die Tray-Höhe")
	assert_almost_eq(store.lane_pit_rect(GameRun.LANE_CARDS).end.y,
		TRAY_HEIGHT - store.frame_px(), 0.01, "die Grube nimmt die volle Höhe")

func test_slot_at_finds_the_visible_place_under_a_pixel() -> void:
	var store := _store()
	assert_eq(store.slot_at(store.slot_center(GameRun.LANE_DICE, 5)),
		{"lane": GameRun.LANE_DICE, "index": 5})
	assert_eq(store.slot_at(store.slot_center(GameRun.LANE_CARDS, 8)),
		{"lane": GameRun.LANE_CARDS, "index": 2}, "die obere Lage meldet ihren sichtbaren Platz")
	assert_eq(store.slot_at(store.slot_center(GameRun.LANE_MODULES, 0)),
		{"lane": GameRun.LANE_MODULES, "index": 0})
	assert_eq(store.slot_at(Vector2(-10, -10)), {}, "neben den Plätzen ist keiner")

func test_the_head_names_count_and_lock() -> void:
	var store := _store()
	store.set_state([3, 12, 1], true)
	assert_eq(PackStoreView.head_text(GameRun.LANE_CARDS, 3, false), "KARTEN-PAKETE  3/12")
	assert_eq(PackStoreView.head_text(GameRun.LANE_MODULES, 1, false), "MODUL-PAKETE  1/12")
	assert_true(PackStoreView.head_text(GameRun.LANE_DICE, 12, true).contains("nach der Runde"),
		"gesperrt sagt der Kopf warum")
	assert_true(store.locked)
	assert_eq(store.counts, [3, 12, 1] as Array[int])
