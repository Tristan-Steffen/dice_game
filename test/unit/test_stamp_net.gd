extends GutTest
## Der WURF des Prägenetzes: Dichte und Magnitude je Sorte × Größe, die Muster
## der großen Kassetten und die Sonderformen (Operator, Fixinhalt).

func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng

func _kinds(net: Array) -> Array[String]:
	var kinds: Array[String] = []
	for face in StampNet.FACES:
		var kind := StampNet.kind_of(StampNet.cell_at(net, face))
		if kind != "":
			kinds.append(kind)
	return kinds

func _values(net: Array) -> Array[int]:
	var values: Array[int] = []
	for face in StampNet.FACES:
		var cell := StampNet.cell_at(net, face)
		if StampNet.kind_of(cell) == StampNet.KIND_VALUE:
			values.append(int(cell["value"]))
	return values

# --- Form ---------------------------------------------------------------------

func test_a_net_always_has_six_cells() -> void:
	for category in Engraving.CATEGORIES:
		for tier in 3:
			var net := StampNet.roll(category, tier, _rng(tier + 1))
			assert_eq(net.size(), StampNet.FACES, "%s / %d" % [category, tier])

func test_an_empty_net_is_blank() -> void:
	assert_true(StampNet.is_blank(StampNet.empty_net()))
	assert_eq(StampNet.filled_count(StampNet.empty_net()), 0)

func test_every_cell_carries_exactly_one_kind() -> void:
	for category in Engraving.CATEGORIES:
		for seed_value in 40:
			for kind in _kinds(StampNet.roll(category, seed_value % 3, _rng(seed_value))):
				assert_true(kind in [StampNet.KIND_VALUE, StampNet.KIND_MATERIAL,
					StampNet.KIND_RUNE], "%s wirft nur seine Sorte: %s" % [category, kind])

# --- Zahlen: Dichte und Magnitude je Größe -------------------------------------

## Standard streut nie ein Muster: ein bis zwei Zellen, +1 oder +2.
func test_the_standard_number_net_stays_small() -> void:
	for seed_value in 60:
		var net := StampNet.roll(Engraving.CATEGORY_NUMBER, Pack.TIER_NORMAL,
			_rng(seed_value))
		var count := StampNet.filled_count(net)
		assert_between(count, 1, 2, "Zellen (Seed %d)" % seed_value)
		for value in _values(net):
			assert_between(value, 1, 2, "Wert (Seed %d)" % seed_value)

## Groß liegt entweder in der Streu-Spanne oder auf einem der beiden Muster
## (sechs Zellen +1, oder eine Spitze +5).
func test_the_gross_number_net_is_spread_or_pattern() -> void:
	var patterns := 0
	var spreads := 0
	for seed_value in 120:
		var net := StampNet.roll(Engraving.CATEGORY_NUMBER, Pack.TIER_GROSS,
			_rng(seed_value))
		var count := StampNet.filled_count(net)
		var values := _values(net)
		if count == 6 and values.max() == StampNet.PATTERN_ALL_VALUE:
			patterns += 1
		elif count == 1 and values[0] == StampNet.PATTERN_SPIKE_VALUE:
			patterns += 1
		else:
			spreads += 1
			assert_between(count, 3, 4, "Zellen (Seed %d)" % seed_value)
			for value in values:
				assert_between(value, 1, 3, "Wert (Seed %d)" % seed_value)
	assert_gt(patterns, 0, "die Muster fallen wirklich")
	assert_gt(spreads, 0, "und die Streuung auch")

## Kolossal ist dicht ODER trägt EINE Jackpot-Zelle.
func test_the_kolossal_number_net_is_dense_or_a_jackpot() -> void:
	var jackpots := 0
	for seed_value in 120:
		var net := StampNet.roll(Engraving.CATEGORY_NUMBER, Pack.TIER_KOLOSSAL,
			_rng(seed_value))
		var count := StampNet.filled_count(net)
		var values := _values(net)
		if count == 1 and values[0] >= int(StampNet.JACKPOT_RANGE[0]):
			jackpots += 1
			assert_between(values[0], int(StampNet.JACKPOT_RANGE[0]),
				int(StampNet.JACKPOT_RANGE[1]), "Jackpot (Seed %d)" % seed_value)
			continue
		assert_between(count, 5, 6, "Zellen (Seed %d)" % seed_value)
		for value in values:
			assert_between(value, 2, 5, "Wert (Seed %d)" % seed_value)
	assert_gt(jackpots, 0, "der Jackpot fällt wirklich")

## Die Größen sind eine echte Leiter: im Mittel trägt jede mehr Bonus als die
## kleinere - genau dafür zahlt die Preisleiter.
func test_the_sizes_grow_in_total_bonus() -> void:
	var sums: Array[float] = []
	for tier in 3:
		var total := 0
		for seed_value in 200:
			for value in _values(StampNet.roll(Engraving.CATEGORY_NUMBER, tier,
					_rng(seed_value + tier * 1000))):
				total += value
		sums.append(float(total) / 200.0)
	assert_gt(sums[1], sums[0], "Groß trägt mehr als Standard")
	assert_gt(sums[2], sums[1], "Kolossal mehr als Groß")

# --- Material und Runen --------------------------------------------------------

func test_the_material_density_climbs_with_the_size() -> void:
	var monoliths := 0
	for seed_value in 120:
		assert_eq(StampNet.filled_count(StampNet.roll(Engraving.CATEGORY_MATERIAL,
			Pack.TIER_NORMAL, _rng(seed_value))), 1, "Standard: eine Zelle")
		assert_between(StampNet.filled_count(StampNet.roll(Engraving.CATEGORY_MATERIAL,
			Pack.TIER_GROSS, _rng(seed_value))), 2, 3, "Groß: zwei bis drei")
		var big := StampNet.roll(Engraving.CATEGORY_MATERIAL, Pack.TIER_KOLOSSAL,
			_rng(seed_value))
		assert_between(StampNet.filled_count(big), 4, 6, "Kolossal: vier bis sechs")
		if StampNet.filled_count(big) == 6 and _one_material(big):
			monoliths += 1
	assert_gt(monoliths, 0, "der ganze Würfel in EINEM Material fällt wirklich")

func _one_material(net: Array) -> bool:
	var seen := {}
	for face in StampNet.FACES:
		seen[String(StampNet.cell_at(net, face).get("id", ""))] = true
	return seen.size() == 1

func test_the_rune_count_is_one_two_three() -> void:
	for seed_value in 40:
		for tier in 3:
			assert_eq(StampNet.filled_count(StampNet.roll(Engraving.CATEGORY_DICE,
				tier, _rng(seed_value))), tier + 1, "Größe %d" % tier)

## Rune wie Material fallen nach der SELTENHEIT ihrer Gravur - das häufige
## Streulicht muss öfter kommen als der seltene Abguss.
func test_rarity_still_steers_the_draw() -> void:
	var counts := {}
	for seed_value in 600:
		var net := StampNet.roll(Engraving.CATEGORY_DICE, Pack.TIER_NORMAL,
			_rng(seed_value))
		for face in StampNet.FACES:
			var cell := StampNet.cell_at(net, face)
			if StampNet.kind_of(cell) == StampNet.KIND_RUNE:
				var id := String(cell["id"])
				counts[id] = int(counts.get(id, 0)) + 1
	assert_gt(int(counts.get(Rune.STRAY_LIGHT, 0)), int(counts.get(Rune.CAST, 0)),
		"häufig fällt öfter als selten")

# --- Sonderformen ---------------------------------------------------------------

func test_an_operator_net_carries_exactly_one_cell() -> void:
	for op_id: String in StampNet.OPERATOR_IDS:
		var net := StampNet.operator_net(op_id, _rng(3))
		assert_eq(StampNet.filled_count(net), 1)
		for face in StampNet.FACES:
			var cell := StampNet.cell_at(net, face)
			if StampNet.is_filled(cell):
				assert_eq(StampNet.kind_of(cell), StampNet.KIND_OPERATOR)
				assert_eq(String(cell["id"]), op_id)

func test_every_operator_is_named_and_priced() -> void:
	assert_eq(StampNet.OPERATOR_IDS.size(), 3, "drei Rechenzeichen, nicht mehr")
	for op_id: String in StampNet.OPERATOR_IDS:
		assert_true(StampNet.is_operator_id(op_id))
		assert_ne(StampNet.operator_name(op_id), "", op_id)
		assert_ne(StampNet.operator_effect(op_id), "", op_id)
		assert_gt(StampNet.operator_price(op_id), 0, op_id)

## Ein Fixinhalt trägt GENAU EINE Zelle - ein Bündel sind mehrere Karten, keine
## dichtere (Spieler-Entscheid 2026-09-11).
func test_a_fixed_net_has_exactly_one_cell() -> void:
	var net := StampNet.fixed_net(Engraving.doping(), _rng(9))
	assert_eq(StampNet.filled_count(net), 1)
	assert_eq(_kinds(net), [StampNet.KIND_DOPE])

func test_a_fixed_pointer_net_always_points_at_a_neighbour() -> void:
	var die := DieDefinition.new()
	for seed_value in 40:
		var net := StampNet.fixed_net(Engraving.pointer_engraving(), _rng(seed_value))
		for face in StampNet.FACES:
			var cell := StampNet.cell_at(net, face)
			if not StampNet.is_filled(cell):
				continue
			assert_true(die.can_point(face, int(cell["to"])),
				"Seite %d zeigt auf einen Nachbarn" % face)

## Die Seite der einen Zelle wird gewürfelt - über die Seeds fällt jede einmal.
func test_a_fixed_net_lands_on_every_face() -> void:
	var seen := {}
	for seed_value in 60:
		var net := StampNet.fixed_net(Engraving.doping(), _rng(seed_value))
		for face in StampNet.FACES:
			if StampNet.is_filled(StampNet.cell_at(net, face)):
				seen[face] = true
	assert_eq(seen.size(), StampNet.FACES)

# --- Was EINE Zelle tut, im Klartext (2026-09-04) ---------------------------------
# Der Zeiger auf einer Netz-Zelle soll DEREN Wirkung lesen, nicht die des ganzen
# Pakets. Die Quellen bleiben die bestehenden - hier wird nichts zweitformuliert.

func test_a_material_cell_names_its_material() -> void:
	var material: DieMaterial = DieMaterial.all()[0]
	var hint := StampNet.cell_hint(StampNet.material_cell(material.id))
	assert_eq(hint, DieMaterial.face_hint(material.id),
		"dieselbe Seiten-Zeile, die auch das Würfelnetz nennt")
	assert_true(hint.contains(material.display_name), "und sie nennt das Material")

func test_a_rune_cell_names_its_rune() -> void:
	var rune_id: String = Rune.all()[0].id
	assert_eq(StampNet.cell_hint(StampNet.rune_cell(rune_id)), Rune.hint(rune_id),
		"dieselbe Zeile, die auch der Würfel nennt")

func test_a_value_cell_and_an_operator_cell_say_what_they_do() -> void:
	assert_true(StampNet.cell_hint(StampNet.value_cell(3)).contains("+3"))
	var op := StampNet.cell_hint(StampNet.operator_cell(StampNet.OP_DOUBLER))
	assert_true(op.contains(StampNet.operator_name(StampNet.OP_DOUBLER)))
	assert_true(op.contains(StampNet.operator_effect(StampNet.OP_DOUBLER)))

func test_an_empty_cell_says_nothing() -> void:
	assert_eq(StampNet.cell_hint({}), "", "eine leere Zelle erklärt nichts")
