extends GutTest
## Integrationstest der Werkzeug-zuerst-Gravur am echten View (Nodes gebaut):
## Aufnehmen, Ziel-Klicks, Anwenden in Quelle→Ziel-Richtung und Verbrauch;
## Abbruch verbraucht nichts; das Bord ist ohne Vorwahl bedienbar.

var view: DieInspectorView
## Die Zahlen-Schublade als Werkzeug-Bord der Station.
var drawer: SupplyDrawerView

func before_each() -> void:
	view = DieInspectorView.new()
	view.size = Vector2(1400, 1470)
	add_child_autofree(view)
	drawer = SupplyDrawerView.new()
	drawer.category = Engraving.CATEGORY_NUMBER
	add_child_autofree(drawer)
	view.set_drawers([drawer] as Array[SupplyDrawerView])
	view.run = GameRun.new_run()
	drawer.run = view.run
	view.run.grant_engraving(Engraving.chisel())
	view.show_die(_die())

func _die() -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [5, 1, 2, 3, 4, 6]
	def.faces = faces
	return def

## Der Werkzeug-Platz liegt in der Vorrats-Schublade seiner Kategorie.
func _slot_for(engraving_id: String) -> Button:
	for entry in drawer.slots:
		if entry["id"] == engraving_id:
			return entry["button"]
	return null

func test_locked_editing_refuses_pickup() -> void:
	# Während der Runde: der Würfel bleibt einsehbar, aber keine Gravur lässt sich
	# aufnehmen, und das Bord ist gesperrt.
	view.set_editing_locked(true)
	view._on_engraving_pressed(Engraving.CHISEL)
	assert_eq(view.held_id, "", "gesperrt: kein Werkzeug lässt sich aufnehmen")
	assert_true(_slot_for(Engraving.CHISEL).disabled, "der besessene Platz ist gesperrt")

func test_unlocking_restores_the_usable_board() -> void:
	view.set_editing_locked(true)
	view.set_editing_locked(false)
	assert_false(_slot_for(Engraving.CHISEL).disabled, "entsperrt ist der Platz wieder nutzbar")
	view._on_engraving_pressed(Engraving.CHISEL)
	assert_eq(view.held_id, Engraving.CHISEL, "und die Gravur lässt sich wieder aufnehmen")

func test_pick_up_then_two_clicks_applies_and_consumes() -> void:
	view._on_engraving_pressed(Engraving.CHISEL)
	assert_eq(view.held_id, Engraving.CHISEL, "aufgenommen")
	view._on_chip_clicked(5, 0)  # Quelle (Wert 5)
	assert_eq(view.first_face, 0, "erster Klick ist die Quelle")
	view._on_chip_clicked(1, 1)  # Ziel
	assert_eq(view.current_def.faces[1], 5, "das Ziel erhält den Quellwert")
	assert_eq(view.held_id, "", "letztes Exemplar verbraucht -> Werkzeug abgelegt")
	assert_eq(view.run.owned_engravings.size(), 0, "Meißel verbraucht")

func test_tool_stays_held_while_copies_remain() -> void:
	# Zwei Kerben: nach der ersten Anwendung bleibt die Kerbe in der Hand
	# (direkt weitergravieren), nach der zweiten ist sie abgelegt.
	view.run.grant_engraving(Engraving.notch())
	view.run.grant_engraving(Engraving.notch())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.NOTCH)
	view._on_chip_clicked(1, 1)
	assert_eq(view.current_def.faces[1], 2, "erste Kerbe angewandt")
	assert_eq(view.held_id, Engraving.NOTCH, "noch ein Exemplar -> bleibt in der Hand")
	assert_eq(view.mode, DieInspectorView.Mode.TARGETING)
	view._on_chip_clicked(2, 2)
	assert_eq(view.current_def.faces[2], 3, "zweite Kerbe angewandt")
	assert_eq(view.held_id, "", "letztes Exemplar verbraucht -> abgelegt")

func test_pair_tool_restarts_at_step_one_when_kept() -> void:
	# Meißel ×2: nach dem ersten Paar beginnt der nächste Durchgang wieder bei
	# der Quellseite (first_face zurückgesetzt).
	view.run.grant_engraving(Engraving.chisel())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.CHISEL)
	view._on_chip_clicked(5, 0)
	view._on_chip_clicked(1, 1)
	assert_eq(view.held_id, Engraving.CHISEL, "zweites Exemplar -> bleibt in der Hand")
	assert_eq(view.first_face, -1, "das Paar beginnt von vorn")

func test_re_clicking_the_held_slot_puts_the_tool_down() -> void:
	view._on_engraving_pressed(Engraving.CHISEL)
	view._on_engraving_pressed(Engraving.CHISEL)
	assert_eq(view.held_id, "", "erneuter Klick legt ab")

func test_cancel_mid_pair_consumes_nothing() -> void:
	view._on_engraving_pressed(Engraving.CHISEL)
	view._on_chip_clicked(5, 0)
	view.cancel_pending()
	assert_eq(view.held_id, "", "abgelegt")
	assert_eq(view.current_def.faces, [5, 1, 2, 3, 4, 6] as Array[int], "nichts verändert")
	assert_eq(view.run.owned_engravings.size(), 1, "Meißel nicht verbraucht")

func test_whole_die_tool_applies_on_a_single_face_click() -> void:
	view.run.grant_engraving(Engraving.polish())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.POLISH)
	view._on_chip_clicked(2, 2)  # ein Klick auf irgendeine Seite genügt
	assert_eq(view.current_def.faces, [6, 2, 3, 4, 5, 7] as Array[int], "alle Seiten +1")
	assert_eq(view.held_id, "", "Werkzeug abgelegt")

func test_board_slot_is_enabled_without_a_face_selection() -> void:
	# Werkzeug-zuerst: die besessene Gravur ist anklickbar, ohne dass vorher eine
	# Seite gewählt wurde.
	assert_false(_slot_for(Engraving.CHISEL).disabled, "Meißel-Slot ist bedienbar")

func test_face_order_stays_frozen_while_editing() -> void:
	# Beim Öffnen nach Wert sortiert: [5,1,2,3,4,6] -> Indizes [1,2,3,4,0,5].
	assert_eq(view.face_order, [1, 2, 3, 4, 0, 5] as Array[int])
	view.run.grant_engraving(Engraving.notch())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.NOTCH)
	view._on_chip_clicked(1, 1)  # die 1 wird zur 2
	assert_eq(view.current_def.faces[1], 2)
	assert_eq(view.face_order, [1, 2, 3, 4, 0, 5] as Array[int],
		"beim Gravieren springen die Chips nicht um")

func test_face_order_resorts_for_a_newly_shown_die() -> void:
	var def := DieDefinition.new()
	var faces: Array[int] = [6, 5, 4, 3, 2, 1]
	def.faces = faces
	view.show_die(def)
	assert_eq(view.face_order, [5, 4, 3, 2, 1, 0] as Array[int],
		"neues Ziel -> wieder aufsteigend nach Wert")

func test_has_pending_action_tracks_the_held_tool() -> void:
	assert_false(view.has_pending_action(), "anfangs nichts in der Hand")
	view._on_engraving_pressed(Engraving.CHISEL)
	assert_true(view.has_pending_action(), "Werkzeug aufgenommen")
	view.cancel_pending()
	assert_false(view.has_pending_action(), "abgelegt")

func test_the_pointer_applies_source_to_adjacent_target() -> void:
	view.run.grant_engraving(Engraving.pointer_engraving())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.POINTER)
	assert_eq(view.held_id, Engraving.POINTER, "aufgenommen")
	view._on_chip_clicked(5, 0)  # Startseite
	assert_eq(view.first_face, 0, "erster Klick ist die Startseite")
	view._on_chip_clicked(6, 5)  # Gegenseite von 0: kein gültiges Ziel
	assert_eq(view.current_def.pointers[0], -1, "die Gegenseite wird verweigert")
	assert_eq(view.first_face, 0, "der erste Klick bleibt stehen")
	view._on_chip_clicked(1, 1)  # Nachbar
	assert_eq(view.current_def.pointers[0], 1, "Leiterbahn gelegt")
	assert_eq(view.held_id, "", "letztes Exemplar verbraucht -> abgelegt")

func test_a_new_pointer_overwrites_the_faces_old_one() -> void:
	view.current_def.pointers[0] = 1
	view.run.grant_engraving(Engraving.pointer_engraving())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.POINTER)
	view._on_chip_clicked(5, 0)
	view._on_chip_clicked(3, 3)
	assert_eq(view.current_def.pointers[0], 3, "je Seite höchstens eine Bahn - überschrieben")

# --- Dotierung: hebt EIN vorhandenes Material um eine Stufe -----------------------

## Zielwürfel mit Materialien auf den Seiten 0 (Gold) und 1 (Rubin).
func _doped_target() -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [5, 1, 2, 3, 4, 6]
	def.faces = faces
	def.set_face_material(0, DieMaterial.GOLD)
	def.set_face_material(1, DieMaterial.RUBY)
	return def

## Bestand einer einzelnen Gravur-id (before_each hat schon einen Meißel gelegt).
func _stock(engraving_id: String) -> int:
	var count := 0
	for engraving in view.run.owned_engravings:
		if engraving.id == engraving_id:
			count += 1
	return count

func _hold_doping() -> void:
	view.run.grant_engraving(Engraving.doping())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.DOPING)

func test_the_doping_lifts_a_material_face() -> void:
	view.show_die(_doped_target())
	_hold_doping()
	assert_eq(view.held_id, Engraving.DOPING, "aufgenommen")
	view._on_chip_clicked(1, 1)  # Rubin-Seite
	assert_eq(view.current_def.material_level(1), DieMaterial.MAX_LEVEL, "die Seite ist dotiert")
	assert_eq(view.held_id, "", "letztes Exemplar verbraucht -> abgelegt")
	assert_eq(_stock(Engraving.DOPING), 0, "Dotierung verbraucht")

func test_the_doping_refuses_a_face_without_material() -> void:
	view.show_die(_doped_target())
	_hold_doping()
	view._on_chip_clicked(2, 2)  # leere Seite
	assert_eq(view.current_def.material_level(2), 0, "ohne Material gibt es nichts zu dotieren")
	assert_eq(view.held_id, Engraving.DOPING, "das Werkzeug bleibt in der Hand")

func test_the_doping_refuses_an_already_doped_face() -> void:
	var def := _doped_target()
	def.levels[0] = DieMaterial.MAX_LEVEL
	view.show_die(def)
	_hold_doping()
	assert_false(view._face_eligible(0), "dotiert ist kein Ziel mehr")
	view._on_chip_clicked(5, 0)
	assert_eq(_stock(Engraving.DOPING), 1, "nichts verbraucht")

func test_the_doping_finds_no_target_on_a_bare_die() -> void:
	view.show_die(_die())  # ganz ohne Materialien
	_hold_doping()
	for i in 6:
		assert_false(view._face_eligible(i), "ohne Material gibt es nichts zu dotieren")

func test_a_new_material_resets_the_level() -> void:
	# Die Dotierung wohnt in der Glasur: ein ANDERES Material fängt wieder normal an.
	var def := _doped_target()
	def.levels[1] = DieMaterial.MAX_LEVEL
	view.show_die(def)
	view.run.grant_engraving(Engraving.material_engraving(DieMaterial.amber(), Engraving.Rarity.COMMON))
	view._sync_drawers()
	view._on_engraving_pressed(DieMaterial.AMBER)
	view._on_chip_clicked(1, 1)
	assert_eq(view.current_def.materials[1], DieMaterial.AMBER, "neues Material liegt an")
	assert_eq(view.current_def.material_level(1), 1, "die alte Dotierung ist mit weg")

## Legt count Rubin-Gravuren in den Vorrat.
func _grant_ruby(count: int) -> void:
	for _i in count:
		view.run.grant_engraving(Engraving.material_engraving(DieMaterial.ruby(), Engraving.Rarity.COMMON))
	view._sync_drawers()

func test_fresh_paint_costs_a_single_copy() -> void:
	view.show_die(_doped_target())
	_grant_ruby(1)
	view._on_engraving_pressed(DieMaterial.RUBY)
	assert_true(view._face_eligible(0), "die Gold-Seite lässt sich übermalen")
	view._on_chip_clicked(5, 0)  # Seite 0 trägt den Wert 5
	assert_eq(view.current_def.materials[0], DieMaterial.RUBY)
	assert_eq(view.current_def.material_level(0), 1, "frisch gestrichen ist undotiert")
	assert_eq(_stock(DieMaterial.RUBY), 0, "und kostet genau ein Stück")

func test_the_same_material_is_no_target_at_all() -> void:
	# Der Dubletten-Aufstieg ist weg: dieselbe Gravur auf dieselbe Seite ist kein Ziel.
	view.show_die(_doped_target())
	_grant_ruby(2)
	view._on_engraving_pressed(DieMaterial.RUBY)
	assert_false(view._face_eligible(1), "die Rubin-Seite nimmt keinen zweiten Rubin an")
	assert_true(view._face_eligible(0), "die Gold-Seite bleibt übermalbar")

func test_the_engraving_pen_does_not_refund_the_doping() -> void:
	# Der Gravierstift schont nur ÄTZUNGEN - Sonderposten nie.
	view.run.owned_charms.append(Charm.engraving_pen())
	view.show_die(_doped_target())
	_hold_doping()
	view._on_chip_clicked(1, 1)
	assert_eq(_stock(Engraving.DOPING), 0, "Dotierung wurde verbraucht")
	assert_false(view.run.gravierstift_used_this_round, "der Stift hat gar nicht ausgelöst")

func test_the_engraving_pen_still_refunds_an_etching() -> void:
	# Gegenprobe zur Regel oben: die Kerbe ist eine Ätzung und bleibt erhalten.
	view.run.owned_charms.append(Charm.engraving_pen())
	view.run.grant_engraving(Engraving.notch())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.NOTCH)
	view._on_chip_clicked(1, 1)
	assert_eq(_stock(Engraving.NOTCH), 1, "Kerbe nicht verbraucht")
	assert_true(view.run.gravierstift_used_this_round)

func test_the_face_net_marks_the_doped_face() -> void:
	# Die Station baut ihre Zellen selbst - die Plakette muss auch dort ankommen.
	var def := _doped_target()
	def.levels[1] = DieMaterial.MAX_LEVEL
	view.show_die(def)
	await wait_frames(2)
	var badges := 0
	for node in view.find_children("*", "Control", true, false):
		if node is DieNetView.LevelBadge:
			badges += 1
	assert_eq(badges, 1, "die dotierte Seite trägt ihre Plakette auch im Stations-Netz")

# --- Rune: eine Seite kontrolliert aufreißen ------------------------------

func _hold_break(rune_id: String) -> void:
	view.run.grant_engraving(Engraving.rune_engraving(Rune.by_id(rune_id), Engraving.Rarity.RARE))
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.RUNE_PREFIX + rune_id)

func test_a_break_pattern_cracks_the_clicked_face() -> void:
	view.show_die(_die())
	_hold_break(Rune.AFTERGLOW)
	assert_eq(view.held_id, Engraving.RUNE_PREFIX + Rune.AFTERGLOW, "aufgenommen")
	view._on_chip_clicked(1, 1)
	assert_eq(view.current_def.runes_on(1), [Rune.AFTERGLOW] as Array[String], "die Seite ist gebrochen")
	assert_eq(_stock(Engraving.RUNE_PREFIX + Rune.AFTERGLOW), 0, "Rune verbraucht")

func test_every_face_is_a_valid_break_target() -> void:
	view.show_die(_die())
	_hold_break(Rune.STRAY_LIGHT)
	for face in 6:
		assert_true(view._face_eligible(face), "Seite %d darf brechen" % face)

func test_a_second_break_replaces_the_first() -> void:
	var def := _die()
	def.set_rune(1, Rune.AFTERGLOW)
	view.show_die(def)
	_hold_break(Rune.BURN_IN)
	view._on_chip_clicked(1, 1)
	assert_eq(view.current_def.runes_on(1), [Rune.BURN_IN] as Array[String], "neu brechen ersetzt")

func test_a_vacuum_die_fills_its_second_slot_first() -> void:
	var def := _die()
	def.essence_id = Essence.VACUUM
	def.set_rune(1, Rune.AFTERGLOW)
	view.show_die(def)
	_hold_break(Rune.SPARK_FLIGHT)
	view._on_chip_clicked(1, 1)
	assert_eq(view.current_def.runes_on(1), [Rune.AFTERGLOW, Rune.SPARK_FLIGHT] as Array[String],
		"das Vakuum trägt beide Runen")

# --- Einbrand sperrt das Übermalen, nicht das Sättigen ---------------------------

func test_burn_in_blocks_a_foreign_material() -> void:
	var def := _doped_target()  # Seite 0 Gold, Seite 1 Rubin
	def.set_rune(0, Rune.BURN_IN)
	view.show_die(def)
	view.run.grant_engraving(Engraving.material_engraving(DieMaterial.amber(), Engraving.Rarity.COMMON))
	view._sync_drawers()
	view._on_engraving_pressed(DieMaterial.AMBER)
	assert_false(view._face_eligible(0), "die eingebrannte Seite nimmt kein fremdes Material")
	assert_true(view._face_eligible(1), "die Nachbarseite bleibt frei")

func test_burn_in_still_allows_doping_the_same_material() -> void:
	var def := _doped_target()
	def.set_rune(0, Rune.BURN_IN)  # Seite 0 trägt Gold
	view.show_die(def)
	_hold_doping()
	assert_true(view._face_eligible(0), "der Einbrand sperrt nur das Übermalen")
	view._on_chip_clicked(5, 0)
	assert_eq(view.current_def.material_level(0), DieMaterial.MAX_LEVEL)
	assert_eq(view.current_def.runes_on(0), [Rune.BURN_IN] as Array[String], "der Rune überlebt")

func test_burn_in_leaves_value_engravings_alone() -> void:
	var def := _die()
	def.set_rune(0, Rune.BURN_IN)
	view.show_die(def)
	view.run.grant_engraving(Engraving.notch())
	view._sync_drawers()
	view._on_engraving_pressed(Engraving.NOTCH)
	assert_true(view._face_eligible(0), "die Kerbe ändert den Wert, nicht das Material")

# --- Dotierung an der Station -------------------------------------------------------

func _leveled_ruby_die(level: int) -> DieDefinition:
	var def := _die()
	def.set_face_material(0, DieMaterial.RUBY)
	if level >= DieMaterial.MAX_LEVEL:
		def.dope(0)
	return def

func _fill_of(face_index: int) -> Color:
	var box: StyleBoxFlat = view.face_chips[face_index].get_theme_stylebox("normal")
	return box.bg_color

func test_die_station_zeigt_die_dotierung_als_saettigung() -> void:
	view.show_die(_leveled_ruby_die(DieMaterial.MAX_LEVEL))
	await wait_frames(2)
	assert_eq(_fill_of(0), DieMaterial.tint_for(DieMaterial.RUBY, DieMaterial.MAX_LEVEL),
		"die dotierte Zelle trägt ihre Sättigung")
	view.show_die(_leveled_ruby_die(1))
	await wait_frames(2)
	assert_eq(_fill_of(0), DieMaterial.tint_for(DieMaterial.RUBY),
		"undotiert bleibt exakt die alte Farbe")

func test_die_gehaltene_dotierung_zeigt_den_zielzustand_vorab() -> void:
	# Die Zelle sagt vorab, wie satt sie nach der Dotierung wäre.
	view.show_die(_leveled_ruby_die(1))
	view.run.grant_engraving(Engraving.doping())
	await wait_frames(2)
	view.held_id = Engraving.DOPING
	view._on_face_hover(0)
	await wait_frames(2)
	assert_eq(_fill_of(0), DieMaterial.tint_for(DieMaterial.RUBY, DieMaterial.MAX_LEVEL),
		"Vorschau auf den dotierten Zustand")
	view._on_face_hover_exit()
	await wait_frames(2)
	assert_eq(_fill_of(0), DieMaterial.tint_for(DieMaterial.RUBY),
		"Zeiger weg -> zurück auf den echten Zustand")

func test_ein_fremdes_material_dotiert_nichts() -> void:
	view.show_die(_leveled_ruby_die(1))
	view.run.grant_engraving(Engraving.material_engraving(DieMaterial.by_id(DieMaterial.GOLD), Engraving.Rarity.COMMON))
	await wait_frames(2)
	view.held_id = DieMaterial.GOLD
	view._on_face_hover(0)
	await wait_frames(2)
	# Frisches Material streicht neu und beginnt undotiert - keine Sättigung.
	assert_ne(_fill_of(0), DieMaterial.tint_for(DieMaterial.RUBY, DieMaterial.MAX_LEVEL),
		"Übermalen ist kein Dotieren")
