extends GutTest
## Die INFO-SÄULE unter dem Ausgabefach, seit der KORREKTUR-WELLE I KOMPAKT: über
## ihr liegt der EINE offene Neuzugang, und sie trägt darunter ALLEIN sein Würfelnetz
## - direkt unter dem Würfel. Name/Seele/Wirkung sind in den Info-Schirm der
## Werkstatt gewandert. Ohne Zeiger, ohne Rahmen, und leer heißt: gar nicht da.

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

## Der Text ist fort: die Säule trägt NUR das Netz, direkt oben (der Würfel schwebt
## über ihrer Oberkante).
func test_die_saeule_traegt_nur_das_netz() -> void:
	var die := DieDefinition.standard()
	die.essence_id = Essence.NEON
	view.set_die(die)
	await wait_frames(2)
	var column := _column()
	assert_null(column.get_node_or_null("Name"), "kein Name mehr - der steht im Info-Schirm")
	assert_null(column.get_node_or_null("Seele"), "keine Seelen-Zeile mehr")
	assert_null(column.get_node_or_null("Wirkung"), "keine Wirkungs-Zeile mehr")
	var net: Control = column.get_node("NetzFeld")
	assert_almost_eq(net.position.y, 0.0, 1.0, "das Netz steht ganz oben, direkt unterm Würfel")
	assert_lte(net.position.y + net.size.y, column.size.y + 1.0, "und bleibt in der Säule")

## Sie MELDET nichts mehr: das Zellmaß der Werkstatt-Netze rechnet der Streifen
## seit 2026-09-04 selbst, und der Parkplatz des Netzes liegt dort.
func test_die_saeule_meldet_nichts_mehr() -> void:
	assert_false(view.has_method("net_cell"), "kein Zellmaß-Melder mehr")
	assert_false(view.has_method("net_center_px"), "und kein Geburtsort")

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
