extends GutTest
## Die SCHABLONE der Serien-Zeremonie: ein Tischkörper, der das Netz der
## AUFGELAUFENEN Summe trägt, über der Schacht-Reihe fährt und sich zuletzt in den
## Zielwürfel faltet. Reine Anzeige - gerechnet hat SeriesResolver.

var stencil: StencilView

func before_each() -> void:
	stencil = StencilView.new()
	add_child_autofree(stencil)
	stencil.setup(DataCellView.net_span(1.0), 15.0 / 90.0, PressNetView.VALUE_TINT)

## Leer heißt DUNKEL: ohne Summe trägt sie ein leeres Kreuz, keine Zellen.
func test_an_empty_stencil_draws_an_empty_net() -> void:
	assert_true(StampNet.is_blank(StencilView.net_for(stencil.values())),
		"eine geborene Schablone trägt nichts")
	assert_eq(stencil.values(), [0, 0, 0, 0, 0, 0] as Array[int])

## Je Seite ihr aufgelaufener Bonus als Wert-Zelle; eine Null bleibt leer.
func test_the_net_carries_the_running_sum_per_face() -> void:
	var net := StencilView.net_for([3, 0, 0, 7, 0, 0])
	assert_eq(StampNet.kind_of(StampNet.cell_at(net, 0)), StampNet.KIND_VALUE)
	assert_eq(int(StampNet.cell_at(net, 0)["value"]), 3)
	assert_eq(int(StampNet.cell_at(net, 3)["value"]), 7)
	assert_false(StampNet.is_filled(StampNet.cell_at(net, 1)), "eine Null bleibt leer")

## Sie backt sich selbst: die Fläche trägt ab dem Aufbau eine Textur.
func test_the_plate_carries_a_baked_texture() -> void:
	await wait_frames(2)
	var plate: MeshInstance3D = stencil.get_node("Body/Stencil")
	var material: StandardMaterial3D = plate.material_override
	assert_not_null(material.albedo_texture, "die Backung liegt auf ihrer Fläche")
	# Das NETZ mißt sich an der Karten-Fläche, die SCHEIBE wächst um ihren Saum
	# darüber hinaus - sonst läse die Schablone als zweite Karte.
	assert_almost_eq(plate.mesh.size.x,
		DataCellView.net_span(1.0).x * StencilView.pane_size().x / StampNetOven.span().x,
		0.001)
	assert_gt(plate.mesh.size.x, DataCellView.net_span(1.0).x)

## Die Ziffern TICKEN, sie springen nie - und stehen am Ende auf ihrem Ziel.
func test_the_digits_tick_and_settle_on_the_goal() -> void:
	stencil.tick_to([4, 0, 0, 0, 0, 0], 0.2)
	assert_eq(stencil.values()[0], 0, "im ersten Bild steht noch der alte Stand")
	await wait_seconds(0.35)
	assert_eq(stencil.values(), [4, 0, 0, 0, 0, 0] as Array[int],
		"ausgetickt steht das Ziel")

## Ein Abbruch schuldet nichts: settle stellt den Zielstand her, egal wo der Takt
## gerade stand.
func test_settle_lands_on_the_goal_from_anywhere() -> void:
	stencil.tick_to([9, 0, 0, 0, 0, 0], 2.0)
	stencil.settle()
	assert_eq(stencil.values(), [9, 0, 0, 0, 0, 0] as Array[int])

## Der Schlag eines Operators schreibt seine Glyphe auf sie und klingt zurück.
func test_a_punch_shows_the_operator_glyph() -> void:
	stencil.punch(StampNet.operator_glyph(StampNet.OP_DOUBLER))
	await wait_frames(2)
	var glyph: MeshInstance3D = stencil.get_node("Body/StencilGlyph")
	assert_true(glyph.visible, "die Glyphe blitzt auf")
	stencil.settle()
	assert_false(glyph.visible, "und der Aufräum-Pfad löscht sie")

## Die FAHRT ist eine Fahrt: sie fährt zum genannten Platz, hart gesetzt steht sie
## sofort dort.
func test_the_ride_reaches_its_seat() -> void:
	stencil.seat_at(Vector3(1.0, 2.0, 3.0))
	assert_eq(stencil.global_position, Vector3(1.0, 2.0, 3.0))
	stencil.ride_to(Vector3(4.0, 2.0, 3.0), 0.15)
	await wait_seconds(0.3)
	assert_almost_eq(stencil.global_position.x, 4.0, 0.01)

## Die FALTUNG schrumpft sie in den Würfel hinein und blendet sie aus.
func test_the_fold_shrinks_and_fades_her() -> void:
	stencil.fold_into(Vector3.ZERO, 0.15)
	await wait_seconds(0.3)
	var plate: MeshInstance3D = stencil.get_node("Body/Stencil")
	var material: StandardMaterial3D = plate.material_override
	assert_lt(material.albedo_color.a, 0.05, "sie ist fort")
	assert_lt(stencil.get_node("Body").scale.x, 0.3, "und in sich zusammengefallen")
