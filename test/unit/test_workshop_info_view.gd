extends GutTest
## Der INFO-SCHIRM der Werkstatt (WorkshopInfoView, Layout E): ein Block - Kopf, Wirkung,
## Geste -, der idempotente Schreiber, die Einpassung auf die gemessene Block-Größe und die
## reinen Text-Quellen. Kopflos - scene_root kommt hier nicht vor.

## Der gemessene Block bei 1280 × 720 (u = 5,042).
const U := 5.042
const BLOCK := Vector2(675.0, 250.6)

var view: WorkshopInfoView

func before_each() -> void:
	view = WorkshopInfoView.new()
	view.unit_px = U
	view.size = BLOCK
	add_child_autofree(view)

## Kopf oben, Geste am Fuß, die Wirkung dazwischen - alles im Block.
func test_head_body_and_action_stack_in_the_block() -> void:
	var bounds := Rect2(Vector2.ZERO, view.size)
	for rect: Rect2 in [view.head_rect(), view.band_rect(), view.action_rect()]:
		assert_true(bounds.encloses(rect), "im Block")
	assert_gt(view.band_rect().position.y, view.head_rect().end.y, "Wirkung unter dem Kopf")
	assert_gt(view.action_rect().position.y, view.band_rect().end.y, "Geste am Fuß")
	assert_gt(view.band_rect().size.y, view.head_rect().size.y * 2.0, "die Wirkung hat Platz")

## Nur der WECHSEL schreibt: derselbe Text baut die Labels nicht neu.
func test_set_info_is_idempotent() -> void:
	await wait_frames(2)
	view.set_info("Würfel", "Neon", Color.RED, "Zahlt Geld.", "Klick: wählen")
	var title_id := view.get_node("Titel").get_instance_id()
	assert_eq(view.title_text(), "Würfel")
	assert_eq(view.sub_text(), "Neon")
	assert_eq(view.body_text(), "Zahlt Geld.")
	assert_eq(view.action_text(), "Klick: wählen")
	view.set_info("Würfel", "Neon", Color.RED, "Zahlt Geld.", "Klick: wählen")
	assert_eq(view.get_node("Titel").get_instance_id(), title_id,
		"dieselbe Auskunft baut nichts neu")
	view.set_info("Würfel", "Neon", Color.RED, "Zahlt anders.")
	assert_eq(view.body_text(), "Zahlt anders.", "der Wechsel schreibt")
	assert_eq(view.action_text(), "", "ohne Geste bleibt die rechte Spalte leer")

## Bei der GEMESSENEN Block-Größe wird nichts abgeschnitten: jedes Label paßt samt
## Zeilenabstand in seine Kiste, auch die längste Wirkung und die längste Geste.
func test_nothing_is_cut_at_the_measured_block() -> void:
	await wait_frames(2)
	var long_body := "Verdichten: die Karten der Reihe werden zu EINER. Zahlen und Multiplikatoren addieren sich, Material und Rune liegen danach auf derselben Seite."
	view.set_info("Großes Zahlen-Paket", "Groß  ·  Zahlen", Color.WHITE, long_body,
		"Klick: zurück ins Magazin · Zug: umsortieren")
	await wait_frames(1)
	var font := ThemeDB.fallback_font
	for label in view.labels():
		var px := label.get_theme_font_size("font_size")
		var lead := label.get_theme_constant("line_spacing")
		assert_lte(ShopController.wrapped_height(font, label.text, label.size.x, px, lead),
			label.size.y + 0.5, "%s paßt in seine Kiste" % label.name)
		assert_gte(px, 8)
	assert_gte(view.body_font_size(), 18, "die lange Wirkung bleibt lesbar groß")
	var title: Label = view.get_node("Titel")
	assert_eq(title.get_visible_line_count(), title.get_line_count(), "der Titel steht ganz")

## Ein kurzer Text steht im vollen Grad, ein langer bricht kleiner in mehrere Zeilen.
func test_a_long_body_falls_to_a_smaller_grade() -> void:
	await wait_frames(2)
	view.set_info("Kurz", "", Color.WHITE, "Kurz.")
	var big := view.body_font_size()
	assert_eq(big, int(U * WorkshopInfoView.BODY_UNITS), "kurz steht im vollen Grad")
	view.set_info("Lang", "", Color.WHITE, "Eine lange Wirkungszeile ohne Ende. ".repeat(12))
	assert_lt(view.body_font_size(), big, "der lange Text steht kleiner")

## Titel und Unterzeile stehen nebeneinander: die Unterzeile beginnt hinter dem Titel.
func test_the_sub_line_follows_the_title() -> void:
	await wait_frames(2)
	view.set_info("Würfel", "Vorrat", Color.WHITE, "")
	var title: Label = view.get_node("Titel")
	var sub: Label = view.get_node("Unterzeile")
	assert_gte(sub.position.x, title.position.x + title.size.x, "rechts vom Titel")
	assert_lte(sub.position.x + sub.size.x, view.head_rect().end.x + 0.5, "im Kopf")

## Ein Würfel spricht statt der Wirkung über die Würfel-Auskunft (ROWS).
func test_the_die_speaks_in_place_of_the_body() -> void:
	await wait_frames(2)
	var die := DieDefinition.standard()
	die.essence_id = Essence.all()[0].id
	view.set_info(die.display_name, "Vorrat", Color.WHITE, "")
	view.set_die(die)
	var band := view.die_band()
	assert_true(band.visible)
	assert_eq(band.layout, DieInfoBand.Layout.ROWS, "die Fassung des Schwarzmarkt-Fußes")
	assert_eq(band.mode(), "die")
	assert_false((view.get_node("Wirkung") as Control).visible, "die Wirkung schweigt")
	assert_true(view.band_rect().encloses(Rect2(band.position, band.size)))
	view.set_die(die, 0)
	assert_eq(view.die_band().mode(), "face", "eine Seite schaltet auf die drei Plätze")
	view.set_die(null)
	assert_false(view.die_band().visible)
	assert_true((view.get_node("Wirkung") as Control).visible)

## Ein Würfel OHNE Seele heißt "Normal" und läßt keine leere Fläche: die Wirkung nennt
## seine Augen.
func test_a_soulless_die_is_not_blank() -> void:
	await wait_frames(2)
	var die := DieDefinition.standard()
	die.essence_id = ""
	var info := WorkshopInfoView.die_info(die)
	assert_eq(String(info["title"]), "Normal")
	assert_eq(String(info["sub"]), "", "keine Unterzeile")
	assert_string_contains(String(info["body"]), "1 · 2 · 3 · 4 · 5 · 6")
	view.set_info(info["title"], info["sub"], info["sub_tint"], info["body"], info["action"])
	view.set_die(die)
	assert_false(view.die_band().visible, "die Würfel-Auskunft schweigt")
	assert_true((view.get_node("Wirkung") as Control).visible, "die Wirkung spricht")
	assert_ne(view.body_text(), "")
	view.set_die(die, 0)
	assert_true(view.die_band().visible, "eine Seite spricht wieder über die Auskunft")

## Der Titel eines Würfels ist der Name seiner Seele.
func test_die_info_names_the_soul() -> void:
	var die := DieDefinition.standard()
	var essence: Essence = Essence.all()[0]
	die.essence_id = essence.id
	var info := WorkshopInfoView.die_info(die, "Klick: wählen")
	assert_same(info["die"], die)
	assert_eq(String(info["title"]), essence.display_name)
	assert_eq(String(info["sub"]), "")
	assert_eq(String(info["action"]), "Klick: wählen")

## Eine KASSETTE: Größe·Sorte in der Unterzeile, Beschreibung plus Netz-Zeile.
func test_pack_info_carries_description_and_net_line() -> void:
	var pack := Pack.number_pack()
	var info := WorkshopInfoView.pack_info(pack, "Klick: auf die Walze")
	assert_eq(String(info["title"]), pack.display_name)
	assert_eq(String(info["sub"]), Pack.tier_label(Pack.TIER_NORMAL),
		"die Sorte ist schon der Titel, also bleibt nur die Größe")
	assert_eq(String(info["body"]), Pack.info_body(pack),
		"die EINE Quelle, die auch der Laden druckt")
	assert_eq(String(info["action"]), "Klick: auf die Walze")
	pack.tier = Pack.TIER_KOLOSSAL
	assert_string_contains(String(WorkshopInfoView.pack_info(pack)["sub"]),
		Pack.tier_label(Pack.TIER_KOLOSSAL), "eine Größe steht davor")

## Eine ZELLE gehört jemandem, und der steht im Titel.
func test_cell_info_names_its_owner() -> void:
	var info := WorkshopInfoView.cell_info("Vorschau · Würfel", "Knochen: bricht.")
	assert_eq(String(info["title"]), "Vorschau · Würfel")
	assert_eq(String(info["sub"]), WorkshopInfoView.CELL_SUB)
	assert_eq(String(info["body"]), "Knochen: bricht.")

## RUHE ist der NÄCHSTE SCHRITT, nie leer.
func test_idle_info_names_the_next_step() -> void:
	var cases := [
		[false, false, false, false, "", WorkshopInfoView.STEP_DIE_FIRST],
		[true, false, false, false, "", WorkshopInfoView.STEP_CARD],
		[false, true, false, false, "", WorkshopInfoView.STEP_DIE],
		[true, true, false, false, "", WorkshopInfoView.STEP_READY],
		[true, true, true, false, "", WorkshopInfoView.STEP_SPENT],
		[true, true, false, false, "Nur Katalysatoren.", "Nur Katalysatoren."],
		[false, false, false, true, "", WorkshopInfoView.PACKING_BODY],
	]
	for case: Array in cases:
		var info := WorkshopInfoView.idle_info(case[0], case[1], case[2], case[3], case[4])
		assert_eq(String(info["title"]), WorkshopInfoView.IDLE_TITLE)
		assert_eq(String(info["body"]), String(case[5]), str(case))
		assert_ne(String(info["body"]), "", "nie leer")
