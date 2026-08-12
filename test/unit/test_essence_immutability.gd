extends GutTest
## Regressions-Wache für die Kernregel der Essenzen: **eine Essenz ändert sich
## NIE.** Sie wird beim Guss versiegelt; der einzige legale Schreibweg ist
## DieDefinition.become() beim VOLLSTÄNDIGEN Ersetzen eines Pool-Platzes, dazu
## die Fabriken/Angebote auf FRISCHEN Instanzen. Kein Gravur-, Charm- oder
## Nehmen-Effekt darf eine bestehende Seele umschreiben.

func _d(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

func _m(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _ids(values: Array) -> Array[String]:
	var typed: Array[String] = []
	typed.assign(values)
	return typed

func _p(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

## Lauf, dessen Pool-Würfel jeder eine andere Seele tragen - so fällt nicht nur
## Löschen auf, sondern auch Verschieben.
func _souled_run() -> GameRun:
	var run := GameRun.new_run()
	var souls := [Essence.NEON, Essence.ARGON, Essence.KRYPTON, Essence.HELIUM,
		Essence.NITROGEN, Essence.OXYGEN, Essence.HYDROGEN, Essence.FIREDAMP]
	for i in run.owned_pool.size():
		run.owned_pool[i].essence_id = souls[i % souls.size()]
	return run

func _souls_of(run: GameRun) -> Array[String]:
	var out: Array[String] = []
	for die in run.owned_pool:
		out.append(die.essence_id)
	return out

# --- Startwürfel sind seelenlos (bleibt so) ----------------------------------------

func test_start_dice_have_no_soul():
	for die in GameRun.new_run().owned_pool:
		assert_eq(die.essence_id, "", "das erste Glühen kommt aus dem Shop")

# --- Kein Datensatz-Schreibweg fasst die Essenz an ---------------------------------

func test_face_writes_never_touch_the_essence():
	var def := DieDefinition.new()
	def.essence_id = Essence.ARGON
	def.set_face_material(0, DieMaterial.RUBY)
	def.dope(0)
	def.set_face_material(0, DieMaterial.GOLD)
	def.set_rune(0, Rune.AFTERGLOW)
	def.set_rune(0, Rune.BURN_IN)
	def.pointers[0] = 2
	assert_eq(def.essence_id, Essence.ARGON, "Material, Dotierung und Rune lassen die Seele in Ruhe")

func test_etchings_never_touch_the_essence():
	var def := DieDefinition.new()
	def.essence_id = Essence.KRYPTON
	var target: Array[int] = [1]
	EtchingEffects.notch(def, 0, 6)
	EtchingEffects.overpressure(def, 6)
	EtchingEffects.growth(def, 6)
	EtchingEffects.polish(def, 6)
	EtchingEffects.chisel(def, 0, target, 6)
	EtchingEffects.grindstone(def, 0, 1, 6)
	assert_eq(def.essence_id, Essence.KRYPTON, "Ätzungen ändern Augen, nie die Seele")

func test_instantiate_keeps_the_soul_but_shares_nothing():
	var def := DieDefinition.new()
	def.essence_id = Essence.RADON
	var copy := def.instantiate()
	assert_eq(copy.essence_id, Essence.RADON, "die Kopie erbt die Seele")
	copy.set_face_material(0, DieMaterial.GOLD)
	assert_eq(def.essence_id, Essence.RADON, "und das Original behält seine")

# --- Kein Lauf-Effekt schreibt eine Seele um ---------------------------------------

func test_take_effects_never_rewrite_a_soul():
	var run := _souled_run()
	var before := _souls_of(run)
	var defs: Array[DieDefinition] = [run.owned_pool[0], run.owned_pool[1]]
	defs[0].set_face_material(0, DieMaterial.GOLD)
	defs[1].set_face_material(0, DieMaterial.BONE)
	MaterialEffects.apply_take_effects(defs, _p([0, 0]),
		_m([DieMaterial.GOLD, DieMaterial.BONE]), _p([0, 1]),
		_ids([Charm.GOLDSMITH]), -1, {0: Essence.NEON, 1: Essence.ARGON}, _p([0, 1]))
	assert_eq(_souls_of(run), before, "Nehmen-Effekte fassen die Seelen nicht an")

func test_charms_that_repaint_dice_never_rewrite_a_soul():
	var run := _souled_run()
	var before := _souls_of(run)
	# Das Schmuckkästchen füllt nur noch den Vorrat, der Midashandschuh malt Seiten -
	# an die Seelen kommt keiner der beiden.
	run.owned_charms.append(Charm.jewelry_box())
	run.apply_jewelry_box(run.owned_pool)
	run.owned_charms.append(Charm.midas_glove())
	var faces := _p([0, 0, 0, 0, 0, 0])
	run.apply_midas_glove(run.owned_pool.slice(0, 6), faces, _p([0, 1, 2, 3, 4, 5]))
	assert_eq(_souls_of(run), before, "keiner von beiden fasst eine Seele an")

func test_the_test_mode_helpers_never_rewrite_a_soul():
	var run := _souled_run()
	var before := _souls_of(run)
	run.randomize_all_materials()
	run.clear_all_materials()
	run.randomize_all_pointers()
	run.clear_all_pointers()
	assert_eq(_souls_of(run), before, "auch der Testmodus lässt die Seelen stehen")

func test_only_the_named_test_helpers_may_deal_souls():
	# Die EINZIGE Ausnahme der Regel, und sie steht im Namen: ein Debug-Werkzeug
	# darf umschreiben, damit alle Raritätsstufen auf einmal zu sehen sind.
	var run := _souled_run()
	var before := _souls_of(run)
	run.randomize_all_essences()
	assert_ne(_souls_of(run), before, "der Testmodus teilt neu aus")
	run.clear_all_essences()
	for die in run.owned_pool:
		assert_eq(die.essence_id, "", "und nimmt sie wieder weg")

func test_the_radon_decay_never_rewrites_a_soul():
	var run := _souled_run()
	run.owned_pool[0].essence_id = Essence.RADON
	var before := _souls_of(run)
	EssenceEffects.decay_die(run.owned_pool[0])
	assert_eq(_souls_of(run), before, "Zerfall frisst Augen, nicht die Seele")

func test_the_round_state_never_rewrites_a_soul():
	var run := _souled_run()
	var before := _souls_of(run)
	run.roll_essence_round_state()
	run.consume_smother(run.owned_pool[0], 0)
	run.consume_tip(run.owned_pool[1])
	assert_eq(_souls_of(run), before, "Rundenmarken hängen neben der Seele, nicht darin")

# --- Der EINE legale Schreibweg: der ganze Würfel wird ersetzt ---------------------

func test_replacing_a_pool_entry_is_the_only_way_a_soul_changes():
	var run := _souled_run()
	# Ein Platz ohne Seele - dorthin geht der Kauf (seelenlos zuerst).
	run.owned_pool[5].essence_id = ""
	var fresh := DieDefinition.standard()
	fresh.essence_id = Essence.XENON
	fresh.display_name = "Neuling"
	run._replace_pool_entry(fresh)
	assert_eq(run.owned_pool[5].essence_id, Essence.XENON, "become() trägt die neue Seele ein")
	assert_eq(run.owned_pool[5].display_name, "Neuling")

func test_place_pack_die_replaces_the_whole_die():
	var run := _souled_run()
	var fresh := DieDefinition.standard()
	fresh.essence_id = Essence.OZONE
	run.place_pack_die(fresh, 2)
	assert_eq(run.owned_pool[2].essence_id, Essence.OZONE, "der Paket-Würfel bringt seine Seele mit")

func test_a_purchase_protects_souls_until_no_soulless_slot_is_left():
	# Solange ein seelenloser Platz frei ist, wird NIE eine Seele übermalt.
	var run := _souled_run()
	run.owned_pool[7].essence_id = ""
	var before := _souls_of(run)
	var fresh := DieDefinition.standard()
	fresh.essence_id = Essence.PHOTON_GAS
	run._replace_pool_entry(fresh)
	var after := _souls_of(run)
	for i in before.size():
		if i == 7:
			assert_eq(after[i], Essence.PHOTON_GAS, "der leere Platz nimmt sie auf")
		else:
			assert_eq(after[i], before[i], "Platz %d behält seine Seele" % i)

# --- Angebote schreiben nur auf FRISCHEN Instanzen ---------------------------------

func test_offers_never_hand_out_a_pool_instance():
	var run := _souled_run()
	var offers := DiceOffer.roll_offers(3, _ids([]), run.owned_essence_ids())
	for offer in offers:
		for die in offer.dice:
			for owned in run.owned_pool:
				assert_ne(die, owned, "ein Angebot ist nie ein Pool-Würfel")

func test_a_pack_die_is_a_fresh_instance_too():
	var run := _souled_run()
	var pack := Pack.dice_pack(DiceOffer.TEMPLATES[0])
	for die in pack.roll_dice(_ids([]), run.owned_essence_ids()):
		for owned in run.owned_pool:
			assert_ne(die, owned, "auch der Paket-Würfel ist frisch")
