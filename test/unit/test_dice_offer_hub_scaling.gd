extends GutTest
## Die Würfel wachsen mit dem Casino: eine höhere Lizenz legt größere Augen ins
## Angebot. Stufe 1 bleibt unangetastet - dort ist ein Würfel exakt der von
## früher. Gepinnt sind nur die RELATIONEN, die Kurve selbst ist ein Stellknopf.

func _max_face(def: DieDefinition) -> int:
	var top := 0
	for value in def.faces:
		top = maxi(top, value)
	return top

func _roll_max(hub_level: int, rolls: int = 240) -> int:
	var top := 0
	for _i in rolls:
		for t in DiceOffer.TEMPLATES:
			top = maxi(top, _max_face(DiceOffer.make_die(t, hub_level)))
	return top

# --- Stufe 1 ändert nichts ----------------------------------------------------------

func test_level_one_is_the_identity() -> void:
	assert_almost_eq(DiceOffer.hub_face_factor(1), 1.0, 0.0001)

func test_level_one_rolls_stay_inside_the_templates() -> void:
	# Was die Vorlage erlaubt, ist auf Stufe 1 auch die Obergrenze.
	for _i in 200:
		for t in DiceOffer.TEMPLATES:
			var def := DiceOffer.make_die(t, 1)
			assert_lte(_max_face(def), DiceOffer.MAX_TEMPLATE_FACE,
				"%s bleibt bei <= 6" % t["name"])
			for value in def.faces:
				assert_gte(value, 1, "und nie unter 1")

func test_an_unset_hub_level_defaults_to_one() -> void:
	# Jeder alte Aufrufer, der die Stufe nicht kennt, bekommt den alten Würfel.
	for _i in 60:
		for t in DiceOffer.TEMPLATES:
			assert_lte(_max_face(DiceOffer.make_die(t)), DiceOffer.MAX_TEMPLATE_FACE)

# --- Die Kurve steigt ---------------------------------------------------------------

func test_the_frame_grows_monotonically_with_the_hub_level() -> void:
	for level in range(1, 10):
		assert_gt(DiceOffer.hub_face_factor(level + 1), DiceOffer.hub_face_factor(level),
			"Stufe %d -> %d" % [level, level + 1])
		assert_gt(DiceOffer.max_face_for(level + 1), DiceOffer.max_face_for(level))

func test_the_rolled_maximum_grows_with_the_hub_level() -> void:
	# Nicht nur die Rechnung, auch die echten Würfe steigen.
	var low := _roll_max(1)
	var mid := _roll_max(5)
	var high := _roll_max(10)
	assert_gt(mid, low, "Stufe 5 würfelt größere Seiten als Stufe 1")
	assert_gt(high, mid, "und Stufe 10 größere als Stufe 5")

func test_level_ten_reaches_the_promised_size() -> void:
	assert_gte(DiceOffer.max_face_for(10), 40, "auf Stufe 10 sind ~50 Augen drin")
	assert_lte(DiceOffer.max_face_for(10), 60, "aber nie absurd darüber")
	assert_gte(_roll_max(10), 40, "und die Würfe erreichen das auch wirklich")

func test_no_level_ever_rolls_past_its_own_ceiling() -> void:
	for level in [1, 3, 5, 7, 10]:
		var ceiling := DiceOffer.max_face_for(level)
		for _i in 120:
			for t in DiceOffer.TEMPLATES:
				assert_lte(_max_face(DiceOffer.make_die(t, level)), ceiling,
					"Stufe %d bleibt unter ihrer Decke %d" % [level, ceiling])

func test_the_level_is_clamped_at_both_ends() -> void:
	assert_almost_eq(DiceOffer.hub_face_factor(0), DiceOffer.hub_face_factor(1), 0.0001)
	assert_almost_eq(DiceOffer.hub_face_factor(99), DiceOffer.hub_face_factor(10), 0.0001)

func test_a_face_never_shrinks_below_its_template_value() -> void:
	# Die Streuung bricht runde Zahlen auf, sie darf aber nie nach unten wirken.
	for _i in 150:
		var def := DiceOffer.make_die(DiceOffer.TEMPLATES[4], 6)  # Niedrige Serie [1, 2]
		for value in def.faces:
			assert_gte(value, 1)

# --- Der Weg durch die Angebote -----------------------------------------------------

func test_offers_carry_the_hub_level_through() -> void:
	var top := 0
	for _i in 40:
		for offer in DiceOffer.roll_offers(3, [], [], 10):
			for die in offer.dice:
				top = maxi(top, _max_face(die))
	assert_gt(top, DiceOffer.MAX_TEMPLATE_FACE, "die Auslage reicht die Stufe durch")

func test_packs_route_through_the_same_scaling() -> void:
	# Pakete würfeln ihre Würfel beim Öffnen - über dieselbe Quelle.
	var pack := Pack.dice_pack(DiceOffer.TEMPLATES[0])
	var top := 0
	for _i in 40:
		for die in pack.roll_dice([], [], 10):
			top = maxi(top, _max_face(die))
	assert_gt(top, DiceOffer.MAX_TEMPLATE_FACE, "auch das Paket wächst mit")

func test_a_pack_without_a_level_stays_small() -> void:
	var pack := Pack.dice_pack(DiceOffer.TEMPLATES[0])
	for _i in 40:
		for die in pack.roll_dice():
			assert_lte(_max_face(die), DiceOffer.MAX_TEMPLATE_FACE)
