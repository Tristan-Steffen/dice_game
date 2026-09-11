extends GutTest
## Der INFO-SCHIRM der Werkstatt (WorkshopInfoView, 2026-09-11): die gemeldete
## Höhe, der idempotente Schreiber, die Einpassung der Wirkung und die vier reinen
## Text-Quellen. Kopflos - scene_root kommt hier nicht vor.

var view: WorkshopInfoView

func before_each() -> void:
	view = WorkshopInfoView.new()
	view.unit_px = 4.0
	view.size = Vector2(900, WorkshopInfoView.height_for(4.0))
	add_child_autofree(view)

## Die HÖHE ist eine reine Funktion der Einheit - scene_root tippt keine Zahl.
func test_the_height_grows_linearly_with_the_unit() -> void:
	var one := WorkshopInfoView.height_for(1.0)
	assert_gt(one, 0.0, "sie ist nie null")
	assert_almost_eq(WorkshopInfoView.height_for(4.0), one * 4.0, 0.001,
		"doppelte Einheit, doppelte Höhe")
	var grades := WorkshopInfoView.TITLE_UNITS + WorkshopInfoView.SUB_UNITS \
		+ float(WorkshopInfoView.BODY_STEPS[0]) * float(WorkshopInfoView.BODY_LINES)
	assert_almost_eq(one, WorkshopInfoView.MARGIN_Y * 2.0
		+ WorkshopInfoView.LINE_GAP * 2.0 + WorkshopInfoView.LINE_BOX * grades, 0.001,
		"beide Ränder, drei Zeilen (die Wirkung zweizeilig) und die zwei Fugen")

## Nur der WECHSEL schreibt: derselbe Text baut die Labels nicht neu.
func test_set_info_is_idempotent() -> void:
	await wait_frames(2)
	view.set_info("Würfel", "Neon", Color.RED, "Zahlt Geld.")
	var title_id := view.get_node("Titel").get_instance_id()
	var body_id := view.get_node("Wirkung").get_instance_id()
	assert_eq(view.title_text(), "Würfel")
	assert_eq(view.sub_text(), "Neon")
	assert_eq(view.body_text(), "Zahlt Geld.")
	view.set_info("Würfel", "Neon", Color.RED, "Zahlt Geld.")
	assert_eq(view.get_node("Titel").get_instance_id(), title_id,
		"dieselbe Auskunft baut nichts neu")
	assert_eq(view.get_node("Wirkung").get_instance_id(), body_id)
	view.set_info("Würfel", "Neon", Color.RED, "Zahlt anders.")
	assert_eq(view.body_text(), "Zahlt anders.", "der Wechsel schreibt")

## Die WIRKUNG paßt sich ein: ein langer Text fällt auf eine kleinere Stufe der
## Leiter und steht dann in höchstens zwei Zeilen.
func test_a_long_body_falls_to_a_smaller_grade() -> void:
	await wait_frames(2)
	view.set_info("Kurz", "", Color.WHITE, "Kurz.")
	var big := view.body_font_size()
	# Genau so lang, daß der größte Grad nicht mehr reicht - gemessen, nicht geraten.
	var font := ThemeDB.fallback_font
	var inner := view.size.x - view.unit() * WorkshopInfoView.MARGIN_X * 2.0
	var long_text := ""
	while WorkshopView.text_block_lines(font, long_text, inner, big) \
			<= WorkshopInfoView.BODY_LINES:
		long_text += "Eine lange Wirkungszeile ohne Ende. "
	view.set_info("Lang", "", Color.WHITE, long_text)
	var small := view.body_font_size()
	assert_lt(small, big, "der lange Text steht kleiner")
	assert_lte(WorkshopView.text_block_lines(font, long_text, inner, small),
		WorkshopInfoView.BODY_LINES, "und bricht in höchstens zwei Zeilen")

## Und BEIDE Zeilen sind auch zu SEHEN: Godot zeichnet die letzte nur, wenn sie
## samt Zeilenabstand in die Kiste paßt - genau daran fiel die erste Fassung.
func test_both_body_lines_are_really_drawn() -> void:
	await wait_frames(2)
	view.set_info("Material-Paket", "Material-Paket", Color.WHITE,
		"Ein Prägenetz aus Material-Zellen, versiegelt.\n1 Zelle")
	await wait_frames(2)
	var body: Label = view.get_node("Wirkung")
	assert_eq(body.get_line_count(), 2, "zwei Zeilen stehen im Label")
	assert_eq(body.get_visible_line_count(), 2, "und beide werden gezeichnet")

## Ein WÜRFEL: Name, Seele, Wirkung - und die Ladungszeile hängt hinten dran.
func test_die_info_names_soul_and_charge() -> void:
	var die := DieDefinition.standard()
	die.display_name = "Prüfwürfel"
	var plain := WorkshopInfoView.die_info(die)
	assert_eq(String(plain["title"]), "Prüfwürfel")
	assert_eq(String(plain["sub"]), WorkshopInfoView.SOULLESS, "ohne Seele")
	assert_eq(String(plain["body"]), WorkshopInfoView.PLAIN_DIE,
		"ohne Seele und ohne Ladung bleibt nur der schlichte Satz")
	die.charge = 2
	var charged := WorkshopInfoView.die_info(die)
	assert_eq(String(charged["body"]), DieNetView.charge_hint(die),
		"die Ladungszeile kommt aus der EINEN Quelle")
	die.charge = 0
	die.burned_out = true
	assert_string_contains(String(WorkshopInfoView.die_info(die)["body"]),
		"Durchgebrannt", "und der Durchbrenner sagt es")

## Mit Seele trägt die Unterzeile ihren Namen und die Wirkung ihre Beschreibung.
func test_die_info_carries_the_essence() -> void:
	var essence := Essence.all()[0]
	var die := DieDefinition.standard()
	die.essence_id = essence.id
	var info := WorkshopInfoView.die_info(die)
	assert_eq(String(info["sub"]), essence.display_name)
	assert_string_contains(String(info["body"]), essence.description)

## Eine KASSETTE: Größe·Sorte in der Unterzeile, Beschreibung plus Netz-Zeile.
func test_pack_info_carries_description_and_net_line() -> void:
	var pack := Pack.number_pack()
	var info := WorkshopInfoView.pack_info(pack)
	assert_eq(String(info["title"]), pack.display_name)
	assert_eq(String(info["sub"]), Pack.tier_label(Pack.TIER_NORMAL),
		"die Sorte ist schon der Titel, also bleibt nur die Größe")
	assert_eq(String(info["body"]), Pack.info_body(pack),
		"die EINE Quelle, die auch der Laden druckt")
	assert_string_contains(String(info["body"]), pack.description)
	pack.tier = Pack.TIER_KOLOSSAL
	assert_string_contains(String(WorkshopInfoView.pack_info(pack)["sub"]),
		Pack.tier_label(Pack.TIER_KOLOSSAL), "eine Größe steht davor")

## Eine ZELLE gehört jemandem, und der steht im Titel.
func test_cell_info_names_its_owner() -> void:
	var info := WorkshopInfoView.cell_info("Material-Paket", "Knochen: bricht.")
	assert_eq(String(info["title"]), "Material-Paket")
	assert_eq(String(info["sub"]), WorkshopInfoView.CELL_SUB)
	assert_eq(String(info["body"]), "Knochen: bricht.")

## RUHE: ohne Ziel nennt der Schirm die Bremse, ohne Bremse die Handlung - und
## steht ein Ziel, erklärt er den Würfel.
func test_idle_info_names_the_blocker_or_the_target() -> void:
	var blocked := WorkshopInfoView.idle_info(null, "Reihe nicht voll.")
	assert_eq(String(blocked["title"]), WorkshopInfoView.IDLE_TITLE)
	assert_eq(String(blocked["body"]), "Reihe nicht voll.")
	assert_eq(String(WorkshopInfoView.idle_info(null, "")["body"]),
		WorkshopInfoView.IDLE_BODY, "ohne Bremse steht die Einladung")
	var die := DieDefinition.standard()
	die.display_name = "Zielwürfel"
	assert_eq(String(WorkshopInfoView.idle_info(die, "")["title"]), "Zielwürfel",
		"ein gewähltes Ziel erklärt sich selbst")
