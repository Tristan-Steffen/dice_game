extends GutTest
## Die BANK im freien Band der Wanne: ein Tablett mit dem Bestand des Hauses.

func test_die_faecher_passen_ins_tablett() -> void:
	var band := TableBodyView.free_band()
	var tray := TableBankView.tray_rect(band)
	assert_true(band.encloses(tray), "das Tablett liegt im freien Band")
	assert_gte(TableBankView.row_gap(tray), 0.0, "die Reihen passen in die Tiefe des Tabletts")
	var rects := TableBankView.section_rects(tray)
	var names := rects.keys()
	for i in names.size():
		var rect: Rect2 = rects[names[i]]
		assert_true(tray.encloses(rect), "%s liegt im Tablett" % names[i])
		assert_gt(rect.size.x, 0.0)
		for j in range(i + 1, names.size()):
			assert_false(rect.intersects(rects[names[j]]), "%s und %s überdecken sich nicht" % [names[i], names[j]])

func test_jedes_paket_des_ladens_liegt_in_einem_stapel() -> void:
	var stacks := TableBankView.pack_stacks()
	var seen := {}
	var packs := 0
	for stack in stacks:
		var key := "%s|%s|%s" % [stack["kind"], stack["sort"], stack["level"]]
		assert_false(seen.has(key), "kein Stapel doppelt: %s" % key)
		seen[key] = true
		packs += (stack["sizes"] as Array).size()
	assert_eq(stacks.size(), 4 + 4 + 1, "Karten- und Würfel-Pakete je Sorte, ein Modul-Paket - nur die Grundstufe")
	assert_eq(packs, 45, "jede Größe 2er bis 6er")
	for stack in stacks:
		assert_eq(stack["level"], 0, "weder Edel noch Royal")

func test_ein_wuerfel_je_seele_und_ein_schlichter() -> void:
	var dice := TableBankView.dice_stock()
	assert_eq(dice.size(), Essence.all().size() + 1)
	var seen := {}
	for def in dice:
		assert_false(seen.has(def.essence_id), "keine Seele doppelt")
		seen[def.essence_id] = true
	assert_true(seen.has(""), "der schlichte Würfel")

func test_die_bank_stellt_ihren_bestand() -> void:
	var bank := TableBankView.new()
	add_child_autofree(bank)
	await wait_process_frames(6)
	var counts := {"Wuerfel": 0, "Modul": 0, "Rolle": 0, "Diskette": 0, "Paket": 0}
	for child in bank.get_children():
		for prefix: String in counts:
			if String(child.name).begins_with(prefix) and child.name != &"Pakete":
				counts[prefix] += 1
	assert_eq(counts["Wuerfel"], TableBankView.dice_stock().size())
	assert_eq(counts["Modul"], ComboPart.all().size(), "jedes Modul")
	assert_eq(counts["Rolle"], ChipTrayView.VALUES.size(), "je Stückelung eine Rolle")
	assert_eq(counts["Diskette"], TableBankView.DISK_RACKS * TableBankView.DISKS_PER_RACK)
	assert_eq(counts["Paket"], 0, "die Hüllen sind in EINEM Netz je Material aufgegangen")
	assert_not_null(bank.get_node_or_null("Pakete"))
	for title: String in ["CHARMS", "PAKETE", "WÜRFEL", "CHIPS", "MODULE"]:
		assert_not_null(bank.get_node_or_null("Schild_%s" % title), title)

func test_der_schirm_nennt_was_der_zeiger_trifft() -> void:
	var bank := TableBankView.new()
	add_child_autofree(bank)
	await wait_process_frames(6)
	assert_eq(bank.item_count(), TableBankView.dice_stock().size() + ComboPart.all().size())
	assert_eq(bank.shown_item(), -1)
	assert_string_contains(bank.screen_text(), TableBankView.IDLE_TITLE)
	for index: int in [0, 3, bank.item_count() - 1]:
		var above := bank.item_ray(index) + Vector3.UP * 30.0
		assert_eq(bank.item_at(above, Vector3.DOWN), index, "senkrecht über %s" % bank.item_title(index))
		bank.show_item(index)
		assert_eq(bank.shown_item(), index)
		assert_string_contains(bank.screen_text(), bank.item_title(index))
	var last := ComboPart.all()[-1]
	assert_string_contains(bank.screen_text(), last.description, false)
	var frame := TableBankView.frame_rect()
	assert_eq(bank.item_at(Vector3(frame.end.x + 5.0, 30.0, frame.end.y + 5.0), Vector3.DOWN), -1, "neben dem Tablett liegt nichts")
	bank.show_item(-1)
	assert_string_contains(bank.screen_text(), TableBankView.IDLE_TEXT)

func test_ein_wuerfel_spricht_ueber_die_wuerfel_karte() -> void:
	var bank := TableBankView.new()
	add_child_autofree(bank)
	await wait_process_frames(6)
	assert_false(bank.card_shown(), "in Ruhe stehen die Zeilen")
	bank.show_item(1)
	assert_true(bank.card_shown(), "ein Würfel zeigt die Karte der Werkstatt")
	assert_ne(bank.card().shown_key(), "")
	assert_true(bank.card().soul_only, "die Seiten sind schlicht - nur das Seelen-Fach spricht")
	assert_not_null(bank.card().find_child("Seele", true, false))
	assert_null(bank.card().find_child("Seiten", true, false))
	bank.show_item(bank.item_count() - 1)
	assert_false(bank.card_shown(), "ein Modul spricht in Zeilen")
	bank.show_item(-1)
	assert_false(bank.card_shown())

func test_die_wuerfel_reihen_haben_luft() -> void:
	var rects := TableBankView.section_rects(TableBankView.tray_rect(TableBodyView.free_band()))
	var rect: Rect2 = rects["WÜRFEL"]
	var count := TableBankView.dice_stock().size()
	var rows := ceili(float(count) / TableBankView.DICE_ACROSS)
	assert_gt(rect.size.x / rows, TableBankView.DIE_HALF * 2.0 * 1.4, "zwischen den Reihen liegt Luft")

func test_die_kamera_kennt_die_station_bank() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	assert_true(rig.is_station(CameraRig.Mode.BANK))
	rig.configure_bank_target(Vector3(-7.0, 0.0, -60.0), Vector2(12.0, 26.0))
	assert_eq(rig.station_target(CameraRig.Mode.BANK), Vector3(-7.0, 0.0, -60.0))
	assert_eq(CameraRig.Mode.TITLE, 12, "die alten Stationen behalten ihre Nummern")
