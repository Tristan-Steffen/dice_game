extends GutTest
## Die INFO-SÄULE unter dem Ausgabefach: über ihr liegt der EINE offene Neuzugang,
## in ihr steht von oben nach unten Name, Seelen-Zeile im eigenen Glühen, Wirkung -
## und darunter sein Würfelnetz. Ohne Zeiger, ohne Rahmen, und leer heißt: gar nicht da.

const WIDTH := 280.0

var view: FachNetView

func before_each() -> void:
	view = FachNetView.new()
	view.size = Vector2(WIDTH, FachNetView.height_for(WIDTH))
	add_child_autofree(view)
	view.visible = true

func _column() -> Control:
	return view.get_node("Saeule")

func test_der_eine_wuerfel_steht_als_saeule() -> void:
	view.set_die(DieDefinition.standard())
	await wait_frames(2)
	assert_eq(view.net_count(), 1, "genau eine Säule - offen liegt ja genau einer")
	assert_not_null(_column().get_node("NetzFeld"), "und ihr Netz steht darin")

func test_die_saeule_liest_von_oben_nach_unten() -> void:
	var die := DieDefinition.standard()
	die.essence_id = Essence.NEON
	view.set_die(die)
	await wait_frames(2)
	var column := _column()
	var name_line: Label = column.get_node("Name")
	var soul: Label = column.get_node("Seele")
	var effect: Label = column.get_node("Wirkung")
	var net: Control = column.get_node("NetzFeld")
	assert_lte(name_line.position.y + name_line.size.y, soul.position.y,
		"der Name steht über der Seele")
	assert_lte(soul.position.y + soul.size.y, effect.position.y,
		"die Seele über der Wirkung")
	assert_lte(effect.position.y + effect.size.y, net.position.y,
		"und die Erklärung über dem Netz")
	assert_lte(net.position.y + net.size.y, column.size.y + 1.0,
		"alles bleibt in der Säule")

func test_die_drei_zeilen_nennen_die_einen_quellen() -> void:
	var die := DieDefinition.standard()
	die.essence_id = Essence.NEON
	view.set_die(die)
	await wait_frames(2)
	var essence := Essence.by_id(Essence.NEON)
	var column := _column()
	assert_eq((column.get_node("Name") as Label).text, die.display_name)
	assert_eq((column.get_node("Seele") as Label).text, essence.display_name)
	assert_eq((column.get_node("Wirkung") as Label).text, essence.description,
		"die Wirkung wird nicht zweitformuliert")

func test_die_seele_steht_in_ihrem_eigenen_gluehen() -> void:
	var die := DieDefinition.standard()
	die.essence_id = Essence.NEON
	view.set_die(die)
	await wait_frames(2)
	var soul: Label = _column().get_node("Seele")
	assert_eq(soul.get_theme_color("font_color"), ShopController.soul_tint(Essence.NEON),
		"die EINE Farbquelle der Seelen-Zeile")

func test_ein_seelenloser_wuerfel_behaelt_seine_zeilen() -> void:
	view.set_die(DieDefinition.standard())
	await wait_frames(2)
	var soul: Label = _column().get_node("Seele")
	assert_eq(soul.text, "", "kein Wort, aber die Zeile bleibt stehen")
	assert_gt(soul.size.y, 0.0)
	assert_eq((_column().get_node("Wirkung") as Label).text, "")

func test_leer_heisst_gar_nicht_da() -> void:
	view.set_die(DieDefinition.standard())
	await wait_frames(2)
	view.set_die(null)
	await wait_frames(2)
	assert_eq(view.net_count(), 0, "kein Leerlauf-Rahmen")

func test_derselbe_stand_baut_nichts_neu() -> void:
	var die := DieDefinition.standard()
	view.set_die(die)
	await wait_frames(2)
	var built := _column()
	view.set_die(die)
	await wait_frames(2)
	assert_eq(_column(), built, "je Bild gefragt, gebaut nur der Wechsel")

func test_die_saeule_meldet_ihre_hoehe_selbst() -> void:
	view.set_die(DieDefinition.standard())
	await wait_frames(2)
	var net: Control = _column().get_node("NetzFeld")
	var margin := WIDTH / FachNetView.UNIT_DIV * FachNetView.MARGIN_UNITS
	assert_almost_eq(margin * 2.0 + net.position.y + net.size.y,
		FachNetView.height_for(WIDTH), 2.0,
		"die gemeldete Höhe ist genau die, die der Aufbau braucht")
