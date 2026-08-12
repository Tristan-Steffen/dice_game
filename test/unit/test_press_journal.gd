extends GutTest
## Tests des nassen Gusses: bis zur Unterschrift bleibt jede Setzung der Presse
## vorläufig. Das Journal merkt sich jede berührte Seite, das Herausnehmen
## schreibt sie exakt zurück, ein späteres Stück versperrt die Schicht darunter -
## und bezahlt wird ausschließlich beim Fertig.

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng

## Ein Generator, dessen ERSTER Wurf unter threshold liegt - so fällt die Zwinge
## deterministisch, ohne dass der Test einen Seed rät.
func _rng_below(threshold: float) -> RandomNumberGenerator:
	for candidate in 500:
		var probe := RandomNumberGenerator.new()
		probe.seed = candidate
		if probe.randf() < threshold:
			return _rng(candidate)
	return _rng(0)

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _piece(entry: Dictionary) -> void:
	run.press_pieces.append(entry)

func _notch(applications: int = 1, stufe: int = 1) -> void:
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.NOTCH, "stufe": stufe,
		"applications": applications})

## Alle sieben Seiten-Arrays eines Würfels als eine Momentaufnahme.
func _arrays(die: DieDefinition) -> Array:
	return [die.faces.duplicate(), die.materials.duplicate(), die.levels.duplicate(),
		die.runes.duplicate(), die.second_runes.duplicate(), die.third_runes.duplicate(),
		die.pointers.duplicate()]

func _outsider() -> DieDefinition:
	for die in run.owned_pool:
		if not run.is_clamped(die):
			return die
	return null

# --- Das Journal schreibt mit ---------------------------------------------------

func test_every_application_writes_one_entry() -> void:
	_notch()
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([0]), _rng(1)))
	assert_eq(run.press_journal.size(), 1, "je Setzung ein Eintrag")
	var entry: Dictionary = run.press_journal[0]
	assert_eq(String(entry["piece"]["id"]), Engraving.NOTCH)
	assert_eq(entry["die"], run.clamped_dice[0], "und der Würfel, auf dem sie sitzt")

func test_the_entry_holds_only_the_faces_it_touched() -> void:
	_notch()
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([2]), _rng(2)))
	var faces: Array = run.press_journal[0]["faces"]
	assert_eq(faces.size(), 1, "die Kerbe fasst genau eine Seite an")
	assert_eq(int(faces[0]["face"]), 2)

func test_a_whole_die_piece_records_every_face() -> void:
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.POLISH, "stufe": 1,
		"applications": 1})
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([]), _rng(3)))
	assert_eq(run.press_journal[0]["faces"].size(), 6, "die Politur hebt alle sechs")

func test_a_failed_application_writes_nothing() -> void:
	_notch()
	assert_false(run.apply_press_number(0, _outsider(), _d([0]), _rng(4)))
	assert_true(run.press_journal.is_empty(), "was nicht sitzt, steht auch nicht im Journal")

# --- Herausnehmen stellt Seite für Seite wieder her -----------------------------

func test_unseating_restores_every_face_array_byte_for_byte() -> void:
	# Ein reich beschriebener Würfel: Werte, Material samt Dotierung, drei Runen
	# (Vakuum unter der Glasglocke) und eine Leiterbahn.
	run.owned_charms.append(Charm.bell_jar())
	var die: DieDefinition = run.clamped_dice[0]
	die.essence_id = Essence.VACUUM
	die.faces = _d([3, 1, 4, 6, 2, 5])
	die.set_face_material(2, DieMaterial.GOLD)
	die.dope(2)
	die.set_face_material(3, DieMaterial.BONE)
	die.set_rune(2, Rune.AFTERGLOW, 0, 1)
	die.set_rune(2, Rune.CAST, 1, 1)
	die.set_rune(2, Rune.SPARK_FLIGHT, 2, 1)
	die.pointers[2] = 1
	var before := _arrays(die)

	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": DieMaterial.RUBY, "applications": 1})
	assert_true(run.apply_press_material(0, die, 2, _rng(5)))
	assert_ne(_arrays(die), before, "die Setzung hat wirklich etwas verändert")

	assert_true(run.unseat_press_piece(0))
	assert_eq(_arrays(die), before, "Seite für Seite exakt wie davor")

func test_unseating_returns_the_piece_to_the_stock() -> void:
	_notch(1, 4)
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([0]), _rng(6)))
	assert_true(run.press_pieces.is_empty())
	assert_true(run.unseat_press_piece(0))
	assert_eq(run.press_pieces.size(), 1, "das Stück liegt wieder bereit")
	assert_eq(int(run.press_pieces[0]["stufe"]), 4, "mit seiner Stufe")
	assert_eq(int(run.press_pieces[0]["applications"]), 1)
	assert_true(run.press_journal.is_empty())

## Der Leser-Stempel überlebt den Umweg durchs Journal: ein herausgenommenes Stück
## kehrt in SEIN Anzeigefeld zurück, nicht in irgendeins.
func test_the_reader_stamp_survives_the_journal() -> void:
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.NOTCH, "slot": 4,
		"stufe": 1, "applications": 1})
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([0]), _rng(6)))
	assert_eq(int(run.press_journal[0]["piece"]["slot"]), 4, "der Eintrag nimmt ihn mit")
	assert_true(run.unseat_press_piece(0))
	assert_eq(int(run.press_pieces[0]["slot"]), 4, "und gibt ihn unverändert zurück")

func test_a_reseated_piece_may_go_somewhere_else() -> void:
	_notch()
	var die: DieDefinition = run.clamped_dice[0]
	var before: Array[int] = die.faces.duplicate()
	assert_true(run.apply_press_number(0, die, _d([0]), _rng(7)))
	assert_true(run.unseat_press_piece(0))
	assert_true(run.apply_press_number(0, die, _d([4]), _rng(7)))
	assert_eq(die.faces[0], before[0], "die erste Seite steht wie vorher")
	assert_gt(die.faces[4], before[4], "die Kerbe sitzt jetzt woanders")

func test_unseating_reports_both_changes() -> void:
	_notch()
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([0]), _rng(8)))
	watch_signals(run)
	assert_true(run.unseat_press_piece(0))
	assert_signal_emitted(run, "pool_changed")
	assert_signal_emitted(run, "press_changed")

func test_a_pointer_is_unseated_too() -> void:
	_piece({"sort": Engraving.CATEGORY_DICE, "id": Engraving.POINTER, "applications": 1})
	var die: DieDefinition = run.clamped_dice[0]
	die.pointers[0] = 2
	assert_true(run.apply_press_pointer(0, die, 0, 1, _rng(9)))
	assert_eq(die.pointer_target(0), 1)
	assert_true(run.unseat_press_piece(0))
	assert_eq(die.pointer_target(0), 2, "die alte Verdrahtung steht wieder")

func test_an_overpainted_material_comes_back_with_its_doping() -> void:
	# Dotiert kommt eine Seite nicht mehr aus der Presse (Gütesiegel, Meißel) - das
	# Zurückschreiben muss sie trotzdem exakt wiederherstellen.
	var die: DieDefinition = run.clamped_dice[0]
	die.set_face_material(1, DieMaterial.AMBER)
	assert_true(die.dope(1))
	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": DieMaterial.GOLD, "applications": 1})
	assert_true(run.apply_press_material(0, die, 1, _rng(10)))
	assert_eq(die.materials[1], DieMaterial.GOLD)
	assert_lt(die.material_level(1), DieMaterial.MAX_LEVEL, "frische Farbe liegt undotiert")
	assert_true(run.unseat_press_piece(0))
	assert_eq(die.materials[1], DieMaterial.AMBER)
	assert_eq(die.material_level(1), DieMaterial.MAX_LEVEL, "und wieder dotiert")

# --- Die Schicht-Regel ----------------------------------------------------------

func test_a_later_piece_on_the_same_face_sets_the_one_below() -> void:
	_notch(2)
	var die: DieDefinition = run.clamped_dice[0]
	assert_true(run.apply_press_number(0, die, _d([0]), _rng(11)))
	assert_true(run.apply_press_number(0, die, _d([0]), _rng(11)))
	assert_eq(run.press_journal.size(), 2)
	assert_false(run.press_piece_reseatable(0), "darunter ist zu")
	assert_true(run.press_piece_reseatable(1), "der jüngste geht immer")

func test_a_later_piece_on_another_face_blocks_nothing() -> void:
	_notch(2)
	var die: DieDefinition = run.clamped_dice[0]
	assert_true(run.apply_press_number(0, die, _d([0]), _rng(12)))
	assert_true(run.apply_press_number(0, die, _d([3]), _rng(12)))
	assert_true(run.press_piece_reseatable(0), "andere Seite, andere Schicht")
	assert_true(run.press_piece_reseatable(1))

func test_a_later_piece_on_another_die_blocks_nothing() -> void:
	_notch(2)
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([0]), _rng(13)))
	assert_true(run.apply_press_number(0, run.clamped_dice[1], _d([0]), _rng(13)))
	assert_true(run.press_piece_reseatable(0), "die Seite gehört einem anderen Würfel")

func test_removing_the_top_layer_frees_the_one_below() -> void:
	_notch(2)
	var die: DieDefinition = run.clamped_dice[0]
	var before: int = die.faces[0]
	assert_true(run.apply_press_number(0, die, _d([0]), _rng(14)))
	assert_true(run.apply_press_number(0, die, _d([0]), _rng(14)))
	assert_true(run.unseat_press_piece(1))
	assert_true(run.press_piece_reseatable(0), "jetzt liegt nichts mehr darüber")
	assert_true(run.unseat_press_piece(0))
	assert_eq(die.faces[0], before, "und die Seite steht wieder blank")

func test_a_blocked_piece_refuses_to_come_out() -> void:
	_notch(2)
	var die: DieDefinition = run.clamped_dice[0]
	assert_true(run.apply_press_number(0, die, _d([0]), _rng(15)))
	assert_true(run.apply_press_number(0, die, _d([0]), _rng(15)))
	var faces: Array[int] = die.faces.duplicate()
	assert_false(run.unseat_press_piece(0))
	assert_eq(die.faces, faces, "und rührt den Würfel nicht an")
	assert_eq(run.press_journal.size(), 2)

## Die Netzzelle ist der ganze UI-Eingang: sie fragt press_face_marks nach der
## jüngsten Setzung, die sie berührt hat, und gibt genau die heraus.
func test_the_cell_marks_tell_wet_from_set_apart() -> void:
	# Die Politur fasst alle sechs Seiten an, die Kerbe danach nur eine - damit
	# liegt die Politur unter ihr und ist gesetzt, die Kerbe steht nass da.
	_piece({"sort": Engraving.CATEGORY_NUMBER, "id": Engraving.POLISH, "stufe": 1,
		"applications": 1})
	_notch(1)
	var die: DieDefinition = run.clamped_dice[0]
	assert_true(run.apply_press_number(0, die, _d([]), _rng(16)))
	assert_true(run.apply_press_number(0, die, _d([3]), _rng(16)))
	var marks := run.press_face_marks(die)
	assert_false(bool(marks[0]["wet"]), "die überbaute Politur steht")
	assert_eq(String(marks[0]["id"]), Engraving.POLISH)
	assert_true(bool(marks[3]["wet"]), "die jüngste Setzung ist noch herausnehmbar")
	assert_eq(String(marks[3]["id"]), Engraving.NOTCH)

func test_an_untouched_face_carries_no_mark() -> void:
	_notch(1)
	var die: DieDefinition = run.clamped_dice[0]
	assert_true(run.apply_press_number(0, die, _d([0]), _rng(17)))
	assert_eq(run.press_mark_at(die, 0), 0, "die berührte Seite kennt ihren Eintrag")
	assert_eq(run.press_mark_at(die, 3), -1, "die unberührte keinen")

# --- Geld fällt beim Fertig, und nur als Restwert der Hand -------------------------

func test_a_placed_piece_never_pays_a_cent() -> void:
	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": DieMaterial.RUBY, "applications": 1})
	var die: DieDefinition = run.clamped_dice[0]
	assert_true(run.apply_press_material(0, die, 1, _rng(18)))
	assert_eq(run.money, 0, "Setzen zahlt nichts")
	assert_true(run.unseat_press_piece(0))
	assert_eq(run.money, 0, "Herausnehmen erst recht nicht")
	assert_true(run.apply_press_material(0, die, 2, _rng(18)))
	assert_true(run.apply_press_placements())
	assert_eq(run.money, 0, "und ein gesetztes Stück ist kein Restwert")

## Ein herausgenommenes Stück liegt wieder in der Hand - beim Fertig zahlt es
## darum seinen Restwert, nicht seinen Überlauf.
func test_an_unseated_piece_is_cashed_by_the_finish() -> void:
	_notch()
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([0]), _rng(19)))
	assert_true(run.unseat_press_piece(0))
	assert_eq(run.press_cash_out_value(), PhantomPress.FIZZLE_MONEY)
	assert_true(run.apply_press_placements())
	assert_eq(run.money, PhantomPress.FIZZLE_MONEY)

## Der Restwert hängt an der Hand: eine halb gesetzte Sitzung zahlt genau für das,
## was liegen geblieben ist - und für nichts sonst.
func test_only_what_stayed_in_the_hand_is_cashed() -> void:
	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": DieMaterial.RUBY, "applications": 2})
	_notch()
	var die: DieDefinition = run.clamped_dice[0]
	assert_true(run.apply_press_material(0, die, 1, _rng(31)))
	assert_true(run.apply_press_material(0, die, 2, _rng(31)))
	assert_eq(run.press_pieces.size(), 1, "die Kerbe liegt noch")
	assert_true(run.apply_press_placements())
	assert_eq(run.money, PhantomPress.FIZZLE_MONEY, "ein Restwert je liegengebliebenem Stück")

# --- Die Zwinge: jede Anwendung ihr eigener Eintrag ---------------------------------

func test_a_doubled_piece_journals_each_application_on_its_own() -> void:
	run.owned_charms.append(Charm.bench_clamp())
	_notch()
	var die: DieDefinition = run.clamped_dice[0]
	var chance := CharmEffects.piece_double_chance(run.charm_ids())
	assert_gt(chance, 0.0, "die Zwinge würfelt überhaupt")
	assert_true(run.apply_press_number(0, die, _d([0]), _rng_below(chance)))
	assert_eq(run.press_pieces.size(), 1, "die Zwinge legt die Anwendung zurück")
	assert_true(run.apply_press_number(0, die, _d([3]), _rng(20)))
	assert_eq(run.press_journal.size(), 2, "zwei Anwendungen, zwei Einträge")
	assert_true(run.press_piece_reseatable(0), "und beide auf eigenen Seiten")
	assert_true(run.press_piece_reseatable(1))

## Beide Anwendungen tragen dieselbe Nummer: die Zwinge doppelt eine Anwendung,
## nicht das Stück.
func test_a_doubled_piece_keeps_one_identity() -> void:
	run.owned_charms.append(Charm.bench_clamp())
	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": DieMaterial.GOLD, "applications": 1})
	var die: DieDefinition = run.clamped_dice[0]
	var chance := CharmEffects.piece_double_chance(run.charm_ids())
	assert_true(run.apply_press_material(0, die, 0, _rng_below(chance)))
	assert_true(run.apply_press_material(0, die, 1, _rng(21)))
	assert_eq(run.press_journal.size(), 2, "zwei Anwendungen, zwei Einträge")
	assert_eq(int(run.press_journal[0]["piece"]["piece_uid"]),
		int(run.press_journal[1]["piece"]["piece_uid"]), "aber EIN Stück")

# --- Die Bank sind die Zwingen ------------------------------------------------------

func test_a_die_outside_the_clamps_is_no_target_at_all() -> void:
	_notch()
	var outsider := _outsider()
	var before: Array[int] = outsider.faces.duplicate()
	assert_false(run.apply_press_number(0, outsider, _d([0]), _rng(22)))
	assert_eq(outsider.faces, before, "er nimmt nichts an")
	assert_true(run.press_journal.is_empty(), "und nichts steht im Journal")

# --- Das Anwenden: der Guss erkaltet ---------------------------------------------

func test_applying_hardens_every_placement() -> void:
	_notch(2)
	var die: DieDefinition = run.clamped_dice[0]
	assert_true(run.apply_press_number(0, die, _d([0]), _rng(24)))
	assert_true(run.apply_press_number(0, die, _d([3]), _rng(24)))
	var faces: Array[int] = die.faces.duplicate()
	watch_signals(run)
	assert_true(run.apply_press_placements())
	assert_true(run.press_journal.is_empty(), "das Journal ist leer")
	assert_signal_emitted(run, "press_changed", "die Netze nehmen ihre nassen Plaketten weg")
	assert_false(run.unseat_press_piece(0), "nichts kommt mehr heraus")
	assert_true(run.press_face_marks(die).is_empty(), "und keine Zelle trägt mehr eine Plakette")
	assert_eq(die.faces, faces, "der Würfel behält, was er bekommen hat")

func test_hardening_an_empty_journal_says_nothing() -> void:
	watch_signals(run)
	run.harden_press_journal()
	assert_signal_not_emitted(run, "press_changed")

## Nachpressen räumt NICHTS ab: die Stücke legen sich dazu, und der nasse Guss
## bleibt nass - erst das Fertig macht ihn hart.
func test_a_second_press_leaves_the_wet_cast_alone() -> void:
	_notch()
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([0]), _rng(25)))
	var wet := run.press_journal.size()
	run.grant_pack(Pack.number_pack())
	run.open_press(_d([0]), _rng(26))
	assert_eq(run.press_journal.size(), wet, "die Setzung steht weiter nass")
	assert_false(run.press_pieces.is_empty(), "und die frische Beute liegt dazu")

## Das Fertig schließt in JEDEM Stand ab: die offene Anwendung wird Geld, die
## Setzung hart. Kein Stück verfällt dabei wortlos.
func test_finishing_hardens_and_cashes_in_one_move() -> void:
	_notch(2)
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([0]), _rng(27)))
	assert_eq(run.press_pieces.size(), 1, "eine Anwendung ist noch offen")
	assert_true(run.apply_press_placements())
	assert_true(run.press_journal.is_empty(), "der Guss ist hart")
	assert_eq(run.money, PhantomPress.FIZZLE_MONEY, "und die Restanwendung wurde zu Geld")

func test_applying_nothing_at_all_is_no_windfall() -> void:
	assert_false(run.apply_press_placements(), "ohne Hand und Guss gibt es nichts abzuschließen")

# --- Der Verfall: ohne Anwenden nimmt die Runde alles mit -----------------------------

func test_the_lapse_takes_every_layer_back_byte_for_byte() -> void:
	_piece({"sort": Engraving.CATEGORY_MATERIAL, "id": DieMaterial.GOLD, "applications": 1})
	_notch(2)
	var first: DieDefinition = run.clamped_dice[0]
	var second: DieDefinition = run.clamped_dice[1]
	var before_first := _arrays(first)
	var before_second := _arrays(second)
	assert_true(run.apply_press_material(0, first, 1, _rng(28)))
	assert_true(run.apply_press_number(0, first, _d([1]), _rng(28)))  # Schicht über dem Material
	assert_true(run.apply_press_number(0, second, _d([4]), _rng(28)))
	assert_ne(_arrays(first), before_first, "die Setzungen haben wirklich gewirkt")

	run.lapse_press()
	assert_eq(_arrays(first), before_first, "Seite für Seite exakt wie davor")
	assert_eq(_arrays(second), before_second)
	assert_eq(run.money, 0, "und kein Cent ist geflossen")

func test_the_lapse_clears_both_pile_and_journal() -> void:
	_notch(2)
	assert_true(run.apply_press_number(0, run.clamped_dice[0], _d([0]), _rng(29)))
	watch_signals(run)
	run.lapse_press()
	assert_true(run.press_journal.is_empty())
	assert_true(run.press_pieces.is_empty(), "die Ablage verfällt mit")
	assert_signal_emitted(run, "press_changed")

func test_a_lapse_with_nothing_standing_says_nothing() -> void:
	watch_signals(run)
	run.lapse_press()
	assert_signal_not_emitted(run, "press_changed")
	run.lapse_press()
	assert_eq(run.money, 0)

func test_the_next_round_lets_the_whole_cast_lapse() -> void:
	_notch()
	var die: DieDefinition = run.clamped_dice[0]
	var before: Array[int] = die.faces.duplicate()
	assert_true(run.apply_press_number(0, die, _d([0]), _rng(30)))
	run.advance_round()
	assert_eq(die.faces, before, "was nicht angewendet wurde, nimmt die neue Runde mit")
	assert_true(run.press_journal.is_empty())
	assert_eq(run.money, 0)
