extends GutTest
## DAS LICHT-NETZ des DURCHLICHTS: ein reines HOLOGRAMM, das auf der steigenden
## Licht-Ebene des Turms reitet und je Etage deren Zellen aufnimmt. Eine NULL-Zelle
## ist UNSICHTBAR, nicht dunkel - was leuchtet, wird benutzt. Reine Anzeige.

var net: LightNetView

func before_each() -> void:
	net = LightNetView.new()
	add_child_autofree(net)
	net.setup(PressNetView.VALUE_TINT, 1.0)

## Geboren trägt es nichts - und keine einzige Zelle leuchtet.
func test_a_fresh_net_carries_nothing() -> void:
	assert_eq(net.values(), [0, 0, 0, 0, 0, 0] as Array[int])
	assert_true(net.lit_faces().is_empty(), "leer heißt UNSICHTBAR")
	assert_true(StampNet.is_blank(LightNetView.net_for(net.values())))

## Je Seite ihr aufgelaufener Bonus als Wert-Zelle; eine Null bleibt leer.
func test_the_net_carries_the_running_sum_per_face() -> void:
	var cross := LightNetView.net_for([3, 0, 0, 7, 0, 0])
	assert_eq(StampNet.kind_of(StampNet.cell_at(cross, 0)), StampNet.KIND_VALUE)
	assert_eq(int(StampNet.cell_at(cross, 0)["value"]), 3)
	assert_eq(int(StampNet.cell_at(cross, 3)["value"]), 7)
	assert_false(StampNet.is_filled(StampNet.cell_at(cross, 1)), "eine Null bleibt leer")

## NUR die benutzten Seiten leuchten: die Null-Zellen sind in der Backung
## UNSICHTBAR geschaltet, nicht bloß dunkel.
func test_only_the_used_faces_light_up() -> void:
	net.tick_to([0, 4, 0, 0, 2, 0], 0.0)
	assert_eq(net.lit_faces(), [1, 4] as Array[int], "zwei Seiten werden benutzt")
	var drawing := net._drawing()
	var cross: Control = drawing.get_node("StampNet")
	for face in StampNet.FACES:
		var chip: Control = cross.get_child(face)
		assert_eq(chip.visible, face == 1 or face == 4,
			"Zelle %d: leer heißt unsichtbar" % face)
	drawing.queue_free()

## Es ist LICHT: additiv, ohne Tiefentest - die noch ungelesenen Karten liegen
## darüber und verdeckten es sonst von oben.
func test_the_hologram_is_additive_light() -> void:
	await wait_frames(2)
	var quad: MeshInstance3D = net.get_node("Body/Hologram")
	var material: StandardMaterial3D = quad.material_override
	assert_eq(material.blend_mode, BaseMaterial3D.BLEND_MODE_ADD, "additiv")
	assert_true(material.no_depth_test, "es liest immer")
	assert_eq(material.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_not_null(material.albedo_texture, "die Backung liegt darauf")
	assert_almost_eq(quad.rotation.x, -PI * 0.5, 0.001, "und es schaut nach oben")
	assert_eq((quad.mesh as QuadMesh).size,
		DataCellView.net_span(PackDrawerView.CASSETTE_SCALE),
		"dasselbe Netzmaß wie auf der Karte")

## Es hat KEINEN Körper mehr: das Glas, der Schnitt und der Scanner sind mit der
## Lawine gestorben.
func test_the_glass_body_and_the_scanner_are_gone() -> void:
	assert_null(net.get_node_or_null("Body/Glass"), "kein Glaskörper mehr")
	assert_false(net.has_method("scan"), "kein Scanner mehr")
	assert_false(net.has_method("cut_height"))
	assert_false(net.has_method("grow_to"), "und nichts wächst mehr")
	assert_false(net.has_method("press_to"))
	assert_false(net.has_method("slide_to"))

## Die Ziffern TICKEN, sie springen nie - und stehen am Ende auf ihrem Ziel.
func test_the_digits_tick_and_settle_on_the_goal() -> void:
	net.tick_to([4, 0, 0, 0, 0, 0], 0.2)
	assert_eq(net.values()[0], 0, "im ersten Bild steht noch der alte Stand")
	await wait_seconds(0.35)
	assert_eq(net.values(), [4, 0, 0, 0, 0, 0] as Array[int],
		"ausgetickt steht das Ziel")

## Der Schlag eines Operators schreibt seine Glyphe darauf und klingt zurück.
func test_a_punch_shows_the_operator_glyph() -> void:
	net.punch(StampNet.operator_glyph(StampNet.OP_DOUBLER))
	await wait_frames(2)
	var glyph: MeshInstance3D = net.get_node("Body/LightGlyph")
	assert_true(glyph.visible, "die Glyphe blitzt auf")
	await wait_seconds(LightNetView.PUNCH_TIME + 0.1)
	assert_almost_eq(net.get_node("Body").scale.x, 1.0, 0.02,
		"der Schlag klingt auf die Ruhe zurück")
	net.settle()
	assert_false(glyph.visible, "und der Aufräum-Pfad löscht sie")

## Eine WERT-Karte bekommt denselben Schlag, nur kleiner - und ohne Zeichen.
func test_a_strike_swells_without_a_glyph() -> void:
	net.strike()
	await wait_frames(2)
	assert_null(net.get_node_or_null("Body/LightGlyph"), "kein Zeichen ohne Operator")
	await wait_seconds(LightNetView.PUNCH_TIME + 0.1)
	assert_almost_eq(net.get_node("Body").scale.x, 1.0, 0.02)

## Ein Abbruch MITTEN im Takt schuldet nichts: settle stellt den Endzustand her -
## Ziffern auf ihrem Ziel, Maßstab zurück.
func test_settle_is_the_end_state_from_anywhere() -> void:
	net.tick_to([9, 0, 0, 0, 0, 0], 2.0)
	net.punch("×2")
	await wait_frames(3)
	net.settle()
	assert_eq(net.values(), [9, 0, 0, 0, 0, 0] as Array[int])
	assert_almost_eq(net.get_node("Body").scale.x, 1.0, 0.001)
