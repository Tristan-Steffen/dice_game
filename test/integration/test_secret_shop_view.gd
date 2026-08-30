extends GutTest
## Integrationstest des Schwarzmarkt-Fensters (SecretShopView an einem ECHTEN
## GameRun). Aufgeteilt wie der Laden: Kopfstreifen und der feste KARTEN-SITZ mit
## genau EINER Charm-Karte bleiben Bildschirm, die Ware meldet das Fenster nur als
## Buchten-Rechteck plus Inhalt - aufgestellt wird sie von scene_root. Das Fenster
## misst wie am Tisch (flache Glas-Tasche unter den Automaten). Unten steht der
## vergitterte Zustand.

var view: SecretShopView
var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()
	run.hub_level = GameRun.HUB_MAX_LEVEL  # volle Börse (25) - reicht für jeden Kauf
	run.unlock_secret_shop()  # Schwarzmarkt freigeschaltet
	run.charge = run.charge_cap()
	view = SecretShopView.new()
	add_child_autofree(view)
	view.size = Vector2(786, 437)  # gemessene Tasche seit dem TOPF-Rückbau der Automaten
	view.run = run
	view.set_locked(false)
	view.refresh()

## Die eine Karte am Sitz (null = der legendäre Topf war erschöpft).
func _card() -> Button:
	var seat := view.card_slot_index()
	return null if seat < 0 else view.offer_buttons[seat]

func _live_buttons() -> Array[Button]:
	var live: Array[Button] = []
	for button in view.offer_buttons:
		if button != null:
			live.append(button)
	return live

## Alle Label unter einem Knoten (rekursiv) - für die Kartenaufschrift.
func _find_labels(node: Node) -> Array[Label]:
	var out: Array[Label] = []
	if node is Label:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_labels(child))
	return out

# --- Der Karten-Sitz ------------------------------------------------------------

func test_exactly_one_card_sits_on_the_seat() -> void:
	await wait_frames(2)
	assert_eq(view.offer_buttons.size(), run.secret_stock.size(),
		"die Plätze bleiben index-treu, auch wo kein Knopf steht")
	assert_eq(_live_buttons().size(), 1, "genau EINE Karte - der Rest liegt in der Bucht")
	assert_eq(view.card_slot_index(), 0, "und sie sitzt auf dem legendären Platz")
	assert_gt(_card().get_global_rect().size.x, 0.0, "die Karte hat Fläche")

func test_the_seat_carries_the_legendary_charm() -> void:
	await wait_frames(2)
	assert_eq(run.secret_stock[view.card_slot_index()][GameRun.OFFER_KIND],
		GameRun.KIND_CHARM, "Lizenzen sind digitale Ware und bleiben Bildschirm")

## Die Tasche ist flach: der Inhalt muss IN das Fenster passen, sonst schneidet
## der Rahmen ihn ab.
func test_content_fits_the_flat_window() -> void:
	await wait_frames(2)
	var window: Rect2 = view.get_global_rect()
	assert_lt(_card().get_global_rect().end.y, window.end.y + 1.0,
		"die Karte ragt unten nicht heraus")
	assert_lt(view.reroll_button.get_global_rect().end.y, window.end.y + 1.0,
		"der Misch-Knopf steht im Fenster")
	assert_lt(view.reroll_button.get_global_rect().end.x, window.end.x + 1.0,
		"und er wird nicht aus dem Kopfstreifen geschoben")

func test_wallet_shows_charge_and_cap() -> void:
	await wait_frames(2)
	assert_eq(view.wallet_label.text, "⚡ %d/%d" % [run.charge, run.charge_cap()])

func test_buying_a_charm_through_the_card_books_it() -> void:
	await wait_frames(2)
	var seat := view.card_slot_index()
	var charm: Charm = run.secret_stock[seat][GameRun.OFFER_ITEM]
	var price: int = run.secret_stock[seat][GameRun.OFFER_PRICE]
	var before := run.charge
	_card().pressed.emit()
	assert_eq(run.charge, before - price, "in Ladung bezahlt")
	assert_true(run.owned_charm_ids().has(charm.id), "Charm im Dock")
	assert_true(bool(run.secret_stock[seat][GameRun.OFFER_SOLD]))

func test_reroll_button_swaps_the_whole_stock() -> void:
	await wait_frames(2)
	var before: Resource = run.secret_stock[0][GameRun.OFFER_ITEM]
	var cost := run.secret_reroll_cost()
	var charge_before := run.charge
	view.reroll_button.pressed.emit()
	await wait_frames(2)
	assert_eq(run.charge, charge_before - cost)
	assert_eq(run.secret_rerolls, 1)
	var after: Resource = run.secret_stock[0][GameRun.OFFER_ITEM]
	assert_ne(after, before, "frisch gewürfelte Auslage")
	assert_eq(_live_buttons().size(), 1, "der Sitz trägt wieder genau eine Karte")
	assert_string_contains(view.reroll_button.text, "⚡%d" % run.secret_reroll_cost(),
		"der Knopf trägt den Preis des nächsten Wurfs")

func test_reroll_is_disabled_without_charge() -> void:
	run.charge = 0
	await wait_frames(2)
	assert_true(view.reroll_button.disabled)
	for button in _live_buttons():
		assert_true(button.disabled, "ohne Ladung ist nichts kaufbar")

## Das Fenster kennt keinen Schließen-Knopf mehr - zurück geht es per Rechtsklick
## über die Kamera, wie bei jedem anderen Tisch-Fenster.
func test_window_has_no_close_button() -> void:
	await wait_frames(2)
	assert_false("close_button" in view, "Schließen macht die Kamera, nicht das Fenster")

# --- Die Bucht: gemeldete Geometrie, nie gezeichneter Inhalt --------------------

func test_the_market_reports_a_vitrine_rect() -> void:
	await wait_frames(2)
	var bay: Rect2 = view.vitrine_rect_px()
	assert_gt(bay.size.x, 0.0, "die Bucht hat eine Breite")
	assert_gt(bay.size.y, 0.0, "und eine Höhe")
	assert_true(view.get_global_rect().encloses(bay), "sie liegt ganz im Fenster")
	assert_gt(bay.position.x, view.card_seat.get_global_rect().end.x - 1.0,
		"und rechts neben dem Karten-Sitz")

func test_the_vitrine_hole_sits_inside_its_frame() -> void:
	await wait_frames(2)
	var bay: Rect2 = view.vitrine_rect_px()
	var hole: Rect2 = view.vitrine_pit_rect()
	assert_true(bay.encloses(hole), "das Loch liegt im Rahmen")
	assert_almost_eq(hole.position.x - bay.position.x,
		PackDrawerView.rim_inset(view.u), 0.51, "links um die Fassung eingerückt")
	assert_almost_eq(bay.end.y - hole.end.y,
		PackDrawerView.rim_inset(view.u), 0.51, "unten ebenso")

## Die Beschriftung misst in der EINHEIT DES FENSTERS - die Tasche ist die
## kleinste des Tisches, und die Buchtbreite allein schriebe dort Matsch.
func test_the_annotation_uses_the_window_unit() -> void:
	await wait_frames(2)
	assert_almost_eq(view.vitrine_unit(), view.u, 0.0001)
	assert_gt(view.vitrine_unit(), view.vitrine_rect_px().size.x / 100.0,
		"größer als eine an der Bucht hängende Einheit")

func test_the_stock_maps_every_slot_to_its_body() -> void:
	await wait_frames(2)
	var stock: Dictionary = view.vitrine_stock()
	var packs: Array = stock[ShopController.KIND_ENGRAVING_PACK]
	var dice: Array = stock[ShopController.KIND_DIE]
	assert_eq(packs.size(), run.secret_stock.size(), "je Auslage-Platz ein Regalplatz")
	assert_eq(dice.size(), run.secret_stock.size(), "und ein Schalenplatz")
	for i in run.secret_stock.size():
		var kind := String(run.secret_stock[i][GameRun.OFFER_KIND])
		if kind == GameRun.KIND_CHARM:
			assert_null(packs[i], "die Karte liegt nicht in der Bucht")
			assert_null(dice[i], "die Karte liegt nicht in der Bucht")
		elif kind == GameRun.KIND_DIE:
			assert_null(packs[i], "ein Würfel steht nicht versiegelt")
			assert_not_null(dice[i], "er liegt offen in der Schale")
		else:
			assert_not_null(packs[i], "Sonderbestand steht als versiegelte Kassette")
			assert_eq(Pack.shelf_of(packs[i]), Pack.SHELF_SPECIAL)
			assert_null(dice[i])

func test_a_bought_slot_stays_as_an_empty_place() -> void:
	await wait_frames(2)
	view.buy_offer(1)
	await wait_frames(2)
	assert_eq(run.owned_packs.size(), 1, "Ware versiegelt im Magazin")
	var stock: Dictionary = view.vitrine_stock()
	assert_eq(stock[ShopController.KIND_ENGRAVING_PACK].size(), run.secret_stock.size(),
		"der Platz verschwindet nicht, er wird leer")
	assert_null(stock[ShopController.KIND_ENGRAVING_PACK][1])
	assert_null(stock[ShopController.KIND_DIE][1])

func test_row_kinds_survive_a_sale() -> void:
	# Die Sorten-Meldung je Platz überlebt den Verkauf: daran hält die Reihe ihre
	# Plätze, damit ein Kauf die übrige Ware nicht verrückt.
	await wait_frames(2)
	var before: Array = view.vitrine_stock()[VitrineView.STOCK_ROW_KINDS]
	assert_eq(before.size(), run.secret_stock.size(), "je Platz eine Sorte")
	assert_eq(String(before[view.card_slot_index()]), "", "der Karten-Sitz meldet keine")
	view.buy_offer(1)
	await wait_frames(2)
	var after: Array = view.vitrine_stock()[VitrineView.STOCK_ROW_KINDS]
	assert_eq(after, before, "der Verkauf ändert keine Sorte - die Lücke behält ihren Ort")
	assert_ne(String(after[1]), "", "auch der verkaufte Platz nennt seine Sorte")

func test_a_purchase_reports_the_pack_it_booked() -> void:
	await wait_frames(2)
	var seen: Array[int] = []
	view.goods_purchased.connect(func(uid: int) -> void: seen.append(uid))
	view.buy_offer(1)
	assert_eq(seen.size(), 1, "genau eine Meldung")
	assert_eq(seen[0], run.owned_packs.back().pack_uid, "und sie meint dieses Paket")

func test_a_charm_purchase_reports_no_goods() -> void:
	await wait_frames(2)
	var seen: Array[int] = []
	view.goods_purchased.connect(func(uid: int) -> void: seen.append(uid))
	_card().pressed.emit()
	assert_eq(seen.size(), 0, "eine Lizenz fährt nicht ins Magazin")

# --- Die Beschriftung auf der Scheibe -------------------------------------------

func test_the_annotation_prices_in_charge() -> void:
	await wait_frames(2)
	var data: Dictionary = view.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 1)
	assert_true(bool(data["charge"]), "das Hinterzimmer zahlt in Energie")
	assert_eq(int(data["price"]), run.secret_offer_price(run.secret_stock[1]))
	assert_eq(int(data["money"]), run.charge, "kaufbar heißt hier: die Börse deckt es")
	assert_ne(String(data["title"]), "", "ein Stück ohne Namen wäre keins")

func test_a_full_magazine_shows_on_the_annotation() -> void:
	await wait_frames(2)
	run.set_pack_capacity(1)
	run.owned_packs.append(Pack.number_pack())  # Magazin voll
	var data: Dictionary = view.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 1)
	assert_eq(String(data["blocked"]), ShopController.FULL_TAG,
		"volles Magazin steht statt des Preises")

func test_an_essence_die_carries_its_net_and_its_soul() -> void:
	var die := DiceOffer.make_die(DiceOffer.TEMPLATES[0])
	die.essence_id = Essence.RADON
	run.secret_stock[2] = {
		GameRun.OFFER_KIND: GameRun.KIND_DIE, GameRun.OFFER_ITEM: die,
		GameRun.OFFER_PRICE: 6, GameRun.OFFER_COUNT: 1, GameRun.OFFER_SOLD: false,
	}
	view.refresh()
	await wait_frames(2)
	var data: Dictionary = view.vitrine_annotation(ShopController.KIND_DIE, 2)
	assert_eq(data["net"], die, "der Würfel zeigt sein volles Netz")
	assert_string_contains(String(data["title"]), Essence.by_id(Essence.RADON).display_name)

func test_a_sold_slot_has_nothing_to_say() -> void:
	await wait_frames(2)
	view.buy_offer(1)
	assert_true(view.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 1).is_empty(),
		"ein leerer Platz beschriftet sich nicht")

# --- Der Charm-Hover schreibt in den festen Fuß (Laden-Grammatik) ---------------

func test_the_charm_card_keeps_its_model_and_names_itself() -> void:
	await wait_frames(2)
	var charm: Charm = run.secret_stock[view.card_slot_index()][GameRun.OFFER_ITEM]
	# Kein schwebendes Dropdown, kein Bild⇄Text-Tausch mehr - die Karte trägt nur
	# noch Name/Modell/Preis, die Wirkung steht im Fuß.
	assert_false("detail_card" in view, "kein schwebendes Dropdown mehr")
	assert_false("_charm_effect" in view, "kein Text-Tausch auf der Karte")
	assert_false(view.has_method("_set_charm_hover"))
	var names := 0
	for label in _find_labels(_card()):
		if label.text == charm.display_name:
			names += 1
	assert_gt(names, 0, "der Name steht auf der Karte")

func test_hovering_the_charm_fills_the_foot() -> void:
	await wait_frames(2)
	var charm: Charm = run.secret_stock[view.card_slot_index()][GameRun.OFFER_ITEM]
	var rect: Rect2 = _card().get_global_rect()
	view.hover_charm(true)
	assert_eq(view.foot_title.text, charm.display_name, "der Name steht im Fuß")
	assert_true(view.foot_body.visible, "und die volle Wirkung")
	assert_true(_card().get_global_rect().is_equal_approx(rect), "die Karte bewegt sich nicht")
	# Der Bucht-Fluss räumt den Fuß NICHT, solange die Karte gehovert wird.
	view.hide_bay_annotation()
	assert_true(view.foot_title.visible, "die Karte hält den Fuß gegen den Bucht-Fluss")
	view.hover_charm(false)
	view.hide_bay_annotation(true)
	assert_false(view.foot_title.visible, "losgelassen räumt der harte Weg sofort")

func test_the_charm_seat_rect_is_reported_for_the_hover_check() -> void:
	await wait_frames(2)
	assert_true(view.charm_seat_rect_px().is_equal_approx(_card().get_global_rect()),
		"scene_root fragt dieses Rechteck ab")

# --- Der INFO-FUSS: die Auskunft steht, sie schwebt nicht -----------------------

func test_the_foot_is_a_fixed_seat_for_every_annotation() -> void:
	await wait_frames(2)
	var foot: Rect2 = view.info_foot.get_global_rect()
	assert_gt(foot.size.y, 0.0, "der Fuß reserviert sein Band")
	assert_false(view.bay_annotation_has_point(foot.get_center()),
		"leer fängt er keinen Zeiger")
	var data: Dictionary = view.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 1)
	view.show_bay_annotation(data, Vector2(9999, 9999))  # der Anker ist egal
	assert_eq(view.foot_title.text, String(data["title"]), "der Fuß trägt den Namen")
	assert_true(view.foot_body.visible, "und die Wirkung")
	assert_true(view.info_foot.get_global_rect().is_equal_approx(foot),
		"an IMMER derselben Stelle - nichts schwebt")
	assert_true(view.bay_annotation_has_point(foot.get_center()),
		"gefüllt hält er den Zeiger (die Schlüsselwörter sind Klickziele)")
	view.hide_bay_annotation(true)
	assert_false(view.foot_title.visible)
	assert_false(view.bay_annotation_has_point(foot.get_center()))

# --- Die Verweilzeit des Fußes --------------------------------------------------

func test_the_foot_lingers_and_fades_after_the_pointer_leaves() -> void:
	await wait_frames(2)
	view.show_bay_annotation(view.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 1),
		Vector2.ZERO)
	view.hide_bay_annotation()
	assert_true(view.foot_title.visible, "der Fuß verweilt statt sofort zu räumen")
	view.hide_bay_annotation()  # der Bucht-Fluss ruft je Bild - der Tween läuft weiter
	await wait_seconds(SecretShopView.FOOT_LINGER_TIME * 0.5)
	assert_true(view.foot_title.visible, "mitten in der Verweilzeit steht er noch")
	await wait_seconds(SecretShopView.FOOT_LINGER_TIME + SecretShopView.FOOT_FADE_TIME)
	assert_false(view.foot_title.visible, "nach Verweilzeit plus Fade ist er leer")
	assert_almost_eq(view.info_foot.modulate.a, 1.0, 0.001,
		"und die Deckkraft steht wieder auf voll")

func test_reaching_the_foot_during_the_linger_keeps_it() -> void:
	await wait_frames(2)
	view.show_bay_annotation(view.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 1),
		Vector2.ZERO)
	var body_before: String = view.foot_body.text
	view.hide_bay_annotation()
	await wait_seconds(SecretShopView.FOOT_LINGER_TIME * 0.5)
	view.foot_hover(view.info_foot.get_global_rect().get_center())  # der Zeiger ist da
	assert_almost_eq(view.info_foot.modulate.a, 1.0, 0.001, "der Fade ist abgebrochen")
	await wait_seconds(SecretShopView.FOOT_LINGER_TIME + SecretShopView.FOOT_FADE_TIME)
	assert_true(view.foot_title.visible, "der gehaltene Fuß bleibt stehen")
	assert_eq(view.foot_body.text, body_before, "und trägt weiter seine Auskunft")

func test_a_new_hover_during_the_fade_replaces_the_foot_at_full_strength() -> void:
	await wait_frames(2)
	view.show_bay_annotation(view.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 1),
		Vector2.ZERO)
	view.hide_bay_annotation()
	await wait_seconds(SecretShopView.FOOT_LINGER_TIME + SecretShopView.FOOT_FADE_TIME * 0.5)
	view.show_bay_annotation(view.vitrine_annotation(ShopController.KIND_ENGRAVING_PACK, 1),
		Vector2.ZERO)
	assert_true(view.foot_title.visible, "der neue Hover hält den Fuß")
	assert_almost_eq(view.info_foot.modulate.a, 1.0, 0.001, "in voller Deckkraft")

func test_the_foot_lies_under_the_bay_inside_the_window() -> void:
	await wait_frames(2)
	var foot: Rect2 = view.info_foot.get_global_rect()
	assert_true(view.get_global_rect().encloses(foot), "der Fuß liegt ganz im Fenster")
	assert_gt(foot.position.y, view.vitrine_rect_px().end.y - 1.0,
		"und unter der Bucht - nie über der Ware")

func test_a_die_annotation_carries_its_net_into_the_foot() -> void:
	var die := DiceOffer.make_die(DiceOffer.TEMPLATES[0])
	die.essence_id = Essence.RADON
	run.secret_stock[2] = {
		GameRun.OFFER_KIND: GameRun.KIND_DIE, GameRun.OFFER_ITEM: die,
		GameRun.OFFER_PRICE: 6, GameRun.OFFER_COUNT: 1, GameRun.OFFER_SOLD: false,
	}
	view.refresh()
	await wait_frames(2)
	view.show_bay_annotation(view.vitrine_annotation(ShopController.KIND_DIE, 2),
		Vector2.ZERO)
	assert_true(view.foot_net.visible, "der Würfel zeigt sein Netz im Fuß")
	assert_gt(view.foot_net.get_child_count(), 0)

## Ein Würfel auf Platz 2 und sein Netz im Fuß - die Vorlage der zwei Netz-Proben.
func _die_in_foot() -> DieDefinition:
	var die := DiceOffer.make_die(DiceOffer.TEMPLATES[0])
	die.essence_id = Essence.RADON
	run.secret_stock[2] = {
		GameRun.OFFER_KIND: GameRun.KIND_DIE, GameRun.OFFER_ITEM: die,
		GameRun.OFFER_PRICE: 6, GameRun.OFFER_COUNT: 1, GameRun.OFFER_SOLD: false,
	}
	view.refresh()
	return die

func test_the_net_sits_at_the_right_end_of_the_foot() -> void:
	# Rechts, unter dem Würfel: der Text bekommt die linke Spalte.
	_die_in_foot()
	await wait_frames(2)
	view.show_bay_annotation(view.vitrine_annotation(ShopController.KIND_DIE, 2),
		Vector2.ZERO)
	await wait_frames(2)
	assert_gt(view.foot_net.get_global_rect().position.x,
		view.foot_body.get_global_rect().position.x,
		"das Netz steht rechts vom Text")

func test_hovering_a_net_cell_swaps_the_foot_body() -> void:
	var die := _die_in_foot()
	await wait_frames(2)
	var data: Dictionary = view.vitrine_annotation(ShopController.KIND_DIE, 2)
	view.show_bay_annotation(data, Vector2.ZERO)
	await wait_frames(2)
	var body := view.foot_net.get_child(0) as Control
	var cell: float = view._foot_net_cell()
	# Der Kanten-Chip (EDGE) erklärt die Seele - dieselbe EINE Quelle wie überall.
	var target := body.get_global_rect().position + Vector2(cell, cell) * 0.5
	view.foot_hover(target)
	assert_eq(view.foot_body.text, DieNetView.hint_for(die, DieNetView.EDGE),
		"die Zelle schreibt ihre eigene Zeile in den Body")
	# Zurück auf die Beschreibung, sobald keine Zelle mehr getroffen ist.
	view.foot_hover(view.foot_body.get_global_rect().get_center())
	assert_eq(view.foot_body.text, Lexikon.linkify(String(data["body"])),
		"neben dem Netz steht die Beschreibung wieder")

# --- Die stehenden Schilder der Bucht -------------------------------------------

## Schilder für Platz 1 (Kassette) und - wenn gestellt - Platz 2 als Würfel.
func _push_plates() -> void:
	var entries: Array = []
	for i in run.secret_stock.size():
		var kind := String(run.secret_stock[i][GameRun.OFFER_KIND])
		if kind == GameRun.KIND_CHARM:
			continue
		var bay_kind := ShopController.KIND_DIE if kind == GameRun.KIND_DIE \
			else ShopController.KIND_ENGRAVING_PACK
		entries.append({"kind": bay_kind, "index": i,
			"px": view.vitrine_pit_rect().get_center() + Vector2(40.0 * i, 0)})
	view.set_bay_plates(entries)

func test_plates_stand_the_charge_price_without_a_pointer() -> void:
	await wait_frames(2)
	_push_plates()
	assert_eq(view._plate_layer.get_child_count(), 2, "je Bucht-Stück ein Schild")
	var plate: Container = view._plate_layer.get_child(0)
	var price_line: Label = plate.get_child(plate.get_child_count() - 1)
	assert_string_contains(price_line.text, "⚡", "der Preis steht in Energie da")
	assert_true(view.vitrine_rect_px().grow(1.0).encloses(plate.get_global_rect()),
		"und das Schild bleibt in der Bucht")

func test_a_die_plate_leads_with_its_soul_line() -> void:
	var die := DiceOffer.make_die(DiceOffer.TEMPLATES[0])
	die.essence_id = Essence.RADON
	run.secret_stock[2] = {
		GameRun.OFFER_KIND: GameRun.KIND_DIE, GameRun.OFFER_ITEM: die,
		GameRun.OFFER_PRICE: 6, GameRun.OFFER_COUNT: 1, GameRun.OFFER_SOLD: false,
	}
	view.refresh()
	await wait_frames(2)
	view.set_bay_plates([{"kind": ShopController.KIND_DIE, "index": 2,
		"px": view.vitrine_pit_rect().get_center()}])
	var plate: Container = view._plate_layer.get_child(0)
	assert_eq(plate.get_child_count(), 2, "Seelen-Zeile plus Preis")
	var soul: Label = plate.get_child(0)
	assert_eq(soul.text, Essence.by_id(Essence.RADON).display_name,
		"die Seelen-Zeile nennt die Essenz")

func test_a_full_magazine_marks_the_plate() -> void:
	await wait_frames(2)
	run.set_pack_capacity(1)
	run.owned_packs.append(Pack.number_pack())  # Magazin voll
	_push_plates()
	var plate: Container = view._plate_layer.get_child(0)
	var price_line: Label = plate.get_child(plate.get_child_count() - 1)
	assert_eq(price_line.text, ShopController.FULL_MARK,
		"volles Magazin steht statt des Preises")
	assert_eq(price_line.modulate, CasinoStyle.RED)

func test_plates_rebuild_only_on_change() -> void:
	await wait_frames(2)
	_push_plates()
	var first: Node = view._plate_layer.get_child(0)
	_push_plates()  # dieselbe Meldung: die Signatur hält den Umbau an
	assert_eq(view._plate_layer.get_child(0), first, "unverändert wird nichts neu gebaut")
	view.set_bay_plates([])
	assert_eq(view._plate_layer.get_child_count(), 0, "keine Meldung, kein Schild")

# --- Die Ankunfts-Grade ---------------------------------------------------------

func test_a_fresh_stock_raises_its_goods() -> void:
	# Der ERSTE Bericht einer frisch gewürfelten Auslage lässt sie aufsteigen; ein
	# zweiter Bericht derselben Ware lässt sie liegen - scene_root sammelt den
	# lauteren Grad, solange die Auslage noch abgedeckt ist.
	var barred := _barred()
	await wait_frames(2)
	var grades: Array[String] = []
	barred.vitrine_changed.connect(func() -> void: grades.append(barred.vitrine_grade()))
	assert_true(barred.run.unlock_secret_shop())
	barred.set_locked(false)
	assert_gt(grades.size(), 0, "die neue Auslage meldet sich")
	assert_eq(grades[0], ShopController.GRADE_RISE, "die erste Auslage steigt auf")
	barred.refresh()
	assert_eq(barred.vitrine_grade(), ShopController.GRADE_STAND,
		"dieselbe Ware ein zweites Mal gemeldet wurde nicht neu gewürfelt")

func test_a_purchase_leaves_the_rest_lying() -> void:
	await wait_frames(2)
	view.buy_offer(1)
	assert_eq(view.vitrine_grade(), ShopController.GRADE_STAND,
		"ein Kauf würfelt nichts - die übrige Ware bleibt liegen")

func test_a_reroll_raises_the_new_goods() -> void:
	await wait_frames(2)
	view.buy_offer(1)
	assert_eq(view.vitrine_grade(), ShopController.GRADE_STAND)
	assert_true(run.reroll_secret_stock())
	await wait_frames(2)
	assert_eq(view.vitrine_grade(), ShopController.GRADE_RISE,
		"ein Neuwurf ist ein voller Warenumschlag")

func test_the_bay_carries_no_frame_at_all() -> void:
	# Die Lichtfuge ist restlos fort: kein Umriss vor der Ware, kein Overlay, kein
	# Symbol. Der Sitz und die Bucht stehen davon unberührt.
	await wait_frames(2)
	var bay: Rect2 = view.vitrine_rect_px()
	var seat: Rect2 = view.card_seat.get_global_rect()
	for gone: String in ["set_lift_seam", "hide_lift_seam"]:
		assert_false(view.has_method(gone), "%s kündigt nichts mehr an" % gone)
	assert_null(view.get_node_or_null("LiftSeam"), "und kein Fugen-Panel steht im Fenster")
	await wait_frames(2)
	assert_true(view.vitrine_rect_px().is_equal_approx(bay), "die Bucht steht gleich")
	assert_true(view.card_seat.get_global_rect().is_equal_approx(seat),
		"und der Karten-Sitz auch")

func test_every_change_of_the_bay_is_reported() -> void:
	await wait_frames(2)
	var beats := []
	view.vitrine_changed.connect(func() -> void: beats.append(1))
	view.buy_offer(1)
	assert_gt(beats.size(), 0, "der Kauf meldet die neue Auslage")
	beats.clear()
	assert_true(run.reroll_secret_stock())
	assert_gt(beats.size(), 0, "und der Neuwurf auch")

# --- Vergittert: der Laden steht da, aber zu -----------------------------------

## Frischer Lauf: das Fenster steht, das Gitter liegt davor.
func _barred() -> SecretShopView:
	var barred_run := GameRun.new_run()
	var barred := SecretShopView.new()
	add_child_autofree(barred)
	barred.size = Vector2(786, 437)
	barred.run = barred_run
	barred.set_locked(true)
	barred.refresh()
	return barred

func test_locked_window_names_the_condition_under_the_veil() -> void:
	var barred := _barred()
	await wait_frames(2)
	assert_true(barred.lock_overlay.visible, "der Schleier liegt über der Auslage")
	assert_string_contains(barred.lock_notice.text, str(GameRun.SECRET_UNLOCK_HUB_LEVEL))
	assert_false("unlock_button" in barred, "nichts zu kaufen: der Zutritt kommt mit der Lizenz")
	assert_eq(barred.offer_buttons.size(), 0, "vergittert ist nichts kaufbar")
	assert_false(barred.reroll_button.visible, "es gibt noch nichts zu mischen")

func test_a_locked_market_keeps_its_bay_empty() -> void:
	var barred := _barred()
	await wait_frames(2)
	var stock: Dictionary = barred.vitrine_stock()
	assert_eq(stock[ShopController.KIND_ENGRAVING_PACK].size(), 0,
		"vergittert liegt keine Ware in der Bucht")
	assert_eq(stock[ShopController.KIND_DIE].size(), 0)
	assert_eq(barred.card_slot_index(), -1, "und keine Karte auf dem Sitz")

func test_unlocking_lifts_the_veil_and_lays_out_the_stock() -> void:
	var barred := _barred()
	await wait_frames(2)
	assert_true(barred.run.unlock_secret_shop())
	barred.set_locked(false)
	await wait_frames(2)
	assert_false(barred.lock_overlay.visible)
	assert_eq(barred.offer_buttons.size(), 3, "die Plätze liegen index-treu")
	assert_eq(barred.card_slot_index(), 0, "und der Sitz trägt seine Karte")
	assert_true(barred.reroll_button.visible)
	assert_eq(barred.vitrine_grade(), ShopController.GRADE_RISE,
		"die erste Auslage steigt auf")
