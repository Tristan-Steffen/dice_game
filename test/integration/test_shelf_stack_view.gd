extends GutTest
## Das SORTEN-MAGAZIN: VIER REIHEN untereinander in EINER flachen Grube, eine je
## Sorte, alle gleich hoch. Jede Reihe rollt für sich; die Karten sind Kinder des
## Faches ihrer Reihe und reisen mit. Keine Karte ragt je über die Tischkante, und was
## ganz außerhalb des Fensters liegt, ist weggesteckt.

## Die Grube in Welt: x quer (Bild-hoch, VIER Reihen), y längs (Bild-breit).
const SPAN := Vector2(9.6, 12.0)
const SCALE := PackDrawerView.CASSETTE_SCALE
## Die Invariante der Wurzel: nichts liegt höher als das im Tisch.
const RIM_LIMIT := -0.11
const ROWS := PackDrawerView.ROWS

var stack: ShelfStackView

func before_each() -> void:
	stack = ShelfStackView.new()
	add_child_autofree(stack)
	stack.setup(Vector3.ZERO, SPAN, SCALE)

func _row_node(row: int) -> Node3D:
	return stack.get_node("Reihe%d" % (row + 1)) as Node3D

func _cell(row: int, z: float) -> DataCellView:
	var cell := DataCellView.new()
	add_child_autofree(cell)
	cell.setup(String(Pack.SHELF_ORDER[row]))
	cell.global_position = Vector3(stack.slot_x(row), stack.card_seat(row), z)
	stack.host_card(cell, row)
	return cell

# --- Reihen und Höhe -----------------------------------------------------------------

func test_vier_reihen_eine_je_sorte() -> void:
	assert_eq(stack.row_count(), Pack.SHELF_ORDER.size())
	for row in ROWS:
		assert_not_null(_row_node(row), "Reihe %d steht" % (row + 1))
		assert_ne(stack.fach(row), stack.fach((row + 1) % ROWS), "jede hat ihr eigenes Fach")

## Alle Reihen liegen auf DERSELBEN Höhe - in die Tiefe wird nichts mehr gestapelt.
func test_alle_reihen_liegen_gleich_hoch() -> void:
	for row in ROWS:
		assert_almost_eq(_row_node(row).position.y, -ShelfStackView.read_drop(SCALE), 0.0001)
		assert_almost_eq(stack.card_seat(row), stack.card_seat(0), 0.0001)

## Reihe 1 liegt Bild-oben (Welt +X), die nächste darunter.
func test_die_reihen_laufen_von_oben_nach_unten() -> void:
	for row in range(1, ROWS):
		assert_lt(stack.lane_x(row), stack.lane_x(row - 1), "Reihe %d unter %d" % [row + 1, row])

## Eine Lage: die Grube braucht nur noch Platte und Karte.
func test_das_magazin_ist_flach() -> void:
	assert_almost_eq(ShelfStackView.stack_depth(SCALE),
		ShelfStackView.read_drop(SCALE) + ShelfStackView.PLATE, 0.0001)
	assert_lt(ShelfStackView.stack_depth(SCALE), 1.0, "unter einer Welteinheit tief")

## GEMELDET liegen die Reihen auf den genannten Mitten; ihre Platten kacheln die Grube,
## die Grenzen liegen mitten in den Rändern.
func test_die_platten_kacheln_die_grube() -> void:
	var lanes: Array[Vector2] = [Vector2(3.4, 2.0), Vector2(1.1, 2.0),
		Vector2(-1.2, 2.0), Vector2(-3.5, 2.0)]
	stack.setup(Vector3.ZERO, SPAN, SCALE, lanes)
	assert_almost_eq(stack.lane_depth(1), 2.0, 0.0001, "die gemeldete Tiefe")
	assert_almost_eq(stack.plate_bounds(0).y, SPAN.x * 0.5, 0.0001, "oben die Grubenkante")
	assert_almost_eq(stack.plate_bounds(ROWS - 1).x, -SPAN.x * 0.5, 0.0001, "unten ebenso")
	for row in range(1, ROWS):
		assert_almost_eq(stack.plate_bounds(row).y, stack.plate_bounds(row - 1).x, 0.0001,
			"Reihe %d schließt an" % (row + 1))
	assert_almost_eq(stack.plate_bounds(1).y, ((1.1 + 1.0) + (3.4 - 1.0)) * 0.5, 0.0001,
		"mitten im Rand")
	var plate := stack.get_node("Reihe2/Platte") as MeshInstance3D
	assert_almost_eq((plate.mesh as BoxMesh).size.x, stack.plate_span(1), 0.0001)
	assert_almost_eq(plate.position.x, stack.plate_center(1), 0.0001)

func test_ohne_meldung_gleiche_streifen() -> void:
	assert_almost_eq(stack.lane_depth(), SPAN.x / float(ROWS), 0.0001, "der kopflose Rückfall")
	assert_almost_eq(stack.band_depth(), stack.lane_depth() * PackDrawerView.BAND_SHARE,
		0.0001, "und die Blende nimmt den Anteil, den auch das Fenster freihält")

# --- Die Invariante: nichts über der Tischkante ------------------------------------

func test_keine_karte_ragt_ueber_die_tischkante() -> void:
	for row in ROWS:
		assert_lte(stack.card_top(row), RIM_LIMIT, "Reihe %d bleibt unter der Kante" % (row + 1))
		assert_gt(stack.card_top(row), RIM_LIMIT - DataCellView.lying_over(SCALE),
			"und knapp darunter")

func test_die_karte_liegt_auf_der_trittflaeche() -> void:
	assert_almost_eq(stack.card_seat(0), stack.tray_top(0) + ShelfStackView.PROUD,
		0.0001, "eine Spur über der Platte, nicht koplanar")
	assert_almost_eq(stack.card_top(0) - stack.card_seat(0),
		DataCellView.lying_over(SCALE), 0.0001, "und ihre Dicke steht darüber")

func test_der_griff_zieht_die_karte_ueber_die_kante() -> void:
	var lift := ShelfStackView.hover_lift(SCALE) * DataCellView.STAND_HEIGHT * SCALE
	assert_gt(stack.card_top(0) + lift, 0.0, "gegriffen steht sie über dem Glas")

# --- Die Karten sind Kinder ihres Faches -------------------------------------------

func test_sie_meldet_ob_eine_karte_schon_liegt() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	var at := Vector3(0.0, stack.card_seat(0), 2.0)
	assert_false(stack.seated(cell, 0, at), "noch gehört sie nicht dazu")
	cell.global_position = at
	stack.host_card(cell, 0)
	assert_eq(cell.get_parent().name, "Fach")
	assert_almost_eq(cell.position.y, ShelfStackView.PROUD, 0.0001,
		"lokal liegt sie IMMER auf der Trittfläche")
	assert_true(stack.seated(cell, 0, at))
	assert_false(stack.seated(cell, 2, at), "und nur in IHRER Reihe")
	assert_false(stack.seated(cell, 0, at + Vector3(0.0, 0.0, 1.0)),
		"ein anderer Platz ist ein anderer Platz")

func test_der_umzug_behaelt_den_weltplatz() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	cell.global_position = Vector3(1.0, -2.0, 3.0)
	stack.host_card(cell, 3)
	var host := Node3D.new()
	add_child_autofree(host)
	var at := cell.global_position
	ShelfStackView.rehost(cell, host)
	assert_eq(cell.get_parent(), host)
	assert_almost_eq(cell.global_position.x, at.x, 0.0001)
	assert_almost_eq(cell.global_position.z, at.z, 0.0001)

# --- WEGGESTECKT: was ganz außerhalb des Fensters liegt -----------------------------

func test_eine_karte_ausserhalb_des_fensters_ist_weggesteckt() -> void:
	var inside := _cell(0, 0.0)
	var length := DataCellView.HEIGHT * SCALE
	var outside := _cell(0, -SPAN.y * 0.5 - length)
	# Die frühere der beiden Grenzen: Mitte an der Wand oder Kante am Ende der Tasche.
	var limit := maxf(-SPAN.y * 0.5, -SPAN.y * 0.5 - stack.left_pocket_depth() + length * 0.5)
	var touching := _cell(0, limit - 0.01)
	var clear := _cell(0, limit + 0.01)
	var right := _cell(0, SPAN.y * 0.5)
	assert_false(inside.tucked(), "im Fenster liegt sie offen")
	assert_true(outside.tucked(), "ganz links draußen ist sie weggesteckt")
	assert_true(touching.tucked(), "links verschwindet sie, sobald ihre Kante über die Tasche reicht")
	assert_false(clear.tucked(), "eine Spur davor liegt sie offen")
	assert_false(right.tucked(), "rechts halb über der Wand ist sie noch zu sehen")
	assert_true(inside.visible and outside.visible, "visible gehört dem Sitz-Schreiber")

func test_ein_zug_steckt_weg_und_holt_herein() -> void:
	var cell := _cell(1, 0.0)
	stack.drag_scroll(1, -SPAN.y)
	assert_true(cell.tucked(), "hinausgezogen verschwindet sie")
	stack.drag_scroll(1, 0.0)
	assert_false(cell.tucked(), "und kommt zurück")

## Die Mulden-Stücke folgen derselben Regel: hinausgerollt links verschwinden sie, sobald
## ihre Kante über die Tasche reicht - sonst stünden sie im Graben der Walze.
func test_hinausgerollte_mulden_verschwinden() -> void:
	stack.set_bay_tints(0, [ShelfStackView.BAY_EMPTY, ShelfStackView.BAY_EMPTY], true)
	var bays := stack.get_node("Reihe1/Mulden1") as Node3D
	assert_true((bays.get_node("Mulde0") as Node3D).visible, "im Fenster stehen sie")
	assert_false((bays.get_node("VorratLinks/Vorrat0") as Node3D).visible,
		"der linke Vorrat ruht unsichtbar")
	stack.drag_scroll(0, SPAN.y * 0.5 - 0.1)
	assert_true((bays.get_node("VorratLinks/Vorrat0") as Node3D).visible,
		"hereingezogen erscheint er")
	stack.drag_scroll(0, -stack.left_pocket_depth() - 0.05)
	assert_false((bays.get_node("Mulde0") as Node3D).visible,
		"mit der Kante über der Tasche ist das Stück fort")
	stack.settle_scroll_hard()
	assert_true((bays.get_node("Mulde0") as Node3D).visible)

func test_wer_das_fach_verlaesst_ist_nie_weggesteckt() -> void:
	var cell := _cell(0, SPAN.y * 2.0)
	assert_true(cell.tucked())
	ShelfStackView.rehost(cell, self)
	assert_false(cell.tucked(), "auf dem Weg zur Walze ist sie sichtbar")

# --- Die BLENDE -----------------------------------------------------------------------

## Jede Reihe trägt links das KÜRZEL ihrer Sorte, in ihrer Sortenfarbe.
func test_die_blende_nennt_die_sorte_in_ihrer_farbe() -> void:
	for row in ROWS:
		var label := stack.get_node("Reihe%d/Blende%d/Kuerzel" % [row + 1, row + 1]) as Label3D
		assert_eq(label.text, Pack.shelf_short(String(Pack.SHELF_ORDER[row])))
		assert_eq(label.modulate, ShelfStackView.row_tint(row))
		assert_lt(label.position.z, 0.0, "links in der Reihe")
		var band := label.get_parent() as Node3D
		assert_almost_eq(band.position.x, stack.lane_x(row) + stack.lane_depth(row) * 0.5
			- stack.band_depth(row) * 0.5, 0.0001, "am oberen Rand ihrer Lane")

## Die Sorte der Option unter dem Zeiger: ihre Reihe leuchtet heller, nur sie.
func test_die_hervorhebung_trifft_genau_eine_reihe() -> void:
	stack.set_highlight(2)
	assert_eq(stack.highlighted(), 2)
	for row in ROWS:
		var glow := stack.get_node("Reihe%d/Blende%d/Hervorhebung" % [row + 1, row + 1]) as Node3D
		assert_eq(glow.visible, row == 2, "Reihe %d" % (row + 1))
	var label := stack.get_node("Reihe3/Blende3/Kuerzel") as Label3D
	assert_gt(label.modulate.get_luminance(), ShelfStackView.row_tint(2).get_luminance())
	stack.set_highlight(-1)
	assert_eq(stack.highlighted(), -1)
	assert_eq(label.modulate, ShelfStackView.row_tint(2))

# --- Die MULDEN -------------------------------------------------------------------------

func test_je_platz_eine_mulde_mit_saum_in_der_sortenfarbe() -> void:
	var tints: Array[Color] = [PackDrawerView.COLORS[Engraving.CATEGORY_DICE],
		ShelfStackView.BAY_EMPTY]
	stack.set_bay_tints(2, tints)
	assert_eq(stack.bay_count(2), 2)
	assert_eq(stack.bay_tint(2, 0), tints[0])
	assert_eq(stack.bay_tint(2, 1), ShelfStackView.BAY_EMPTY, "leer ist stumpf")
	var bays := stack.get_node("Reihe3/Mulden3")
	var count := 0
	for child in bays.get_children():
		if String(child.name).begins_with("Mulde"):
			count += 1
			for part in ["Saum", "Boden", "Buchse"]:
				assert_not_null(child.get_node_or_null(part), "%s trägt %s" % [child.name, part])
	assert_eq(count, 2, "je Platz eine Mulde in IHRER Reihe")
	var lit := (bays.get_node("Mulde0/Saum") as MeshInstance3D).material_override \
		as StandardMaterial3D
	var dull := (bays.get_node("Mulde1/Saum") as MeshInstance3D).material_override \
		as StandardMaterial3D
	assert_eq(lit.emission, tints[0], "der Saum trägt die Sorte")
	assert_gt(lit.emission_energy_multiplier, dull.emission_energy_multiplier)

## Die Mulde ist eine VERTIEFUNG: Lippen, Rippen und Deck reichen genau bis
## Kartenoberkante, die Buchse endet im Deck.
func test_die_mulde_ist_eine_vertiefung_und_die_karte_buendig() -> void:
	stack.set_bay_tints(0, [ShelfStackView.BAY_EMPTY, ShelfStackView.BAY_EMPTY])
	assert_lt(ShelfStackView.FLOOR_RISE, ShelfStackView.BAY_FLOOR)
	var top := ShelfStackView.PROUD + DataCellView.DEPTH * SCALE
	assert_almost_eq(stack.deck_height(), top, 0.0001, "das Deck ist Kartenoberkante")
	var bays := stack.get_node("Reihe1/Mulden1") as Node3D
	for part in ["Mulde0/Lippe0", "Mulde1/RippeL"]:
		var box := bays.get_node(part) as MeshInstance3D
		assert_almost_eq(box.position.y + (box.mesh as BoxMesh).size.y * 0.5, top, 0.0001,
			"%s reicht bis an die Oberfläche" % part)
	assert_not_null(bays.get_node_or_null("Mulde0/Deck"), "Blende und Ränder liegen auf Kartenhöhe")
	var socket := bays.get_node("Mulde0/Buchse") as Node3D
	var socket_top := socket.position.y + socket.scale.y \
		* (DataCellView.DEPTH * SCALE * 0.5 + ShelfStackView.SOCKET_LIP)
	assert_almost_eq(socket_top, top, 0.0001, "die Buchse endet bündig im Deck")
	for wall in ["WandLA", "WandLB", "WandQA", "WandQB"]:
		var lining := bays.get_node_or_null("Mulde0/%s" % wall) as MeshInstance3D
		assert_not_null(lining, "die Mulde trägt %s" % wall)
		var shader := (lining.material_override as ShaderMaterial).shader
		assert_eq(shader.resource_path, "res://assets/shaders/bay_wall.gdshader")
		assert_lt(lining.position.y + (lining.mesh as BoxMesh).size.y * 0.5, top)
	var bay := stack.bay_size(2)
	assert_gt(bay.x, 0.0, "quer bleibt eine Mulde")
	assert_gt(bay.y, DataCellView.HEIGHT * SCALE, "längs weiter als die Karte")
	assert_lt(bay.y, SPAN.y * 0.5, "und zwei passen mit Lippe nebeneinander")

## Deck und Mulden lassen KEINE Lücke zwischen den Reihen: Platte und Deck jeder Reihe
## decken ihre Kachel ganz.
func test_das_deck_deckt_die_kachel_der_reihe() -> void:
	stack.set_bay_tints(1, [ShelfStackView.BAY_EMPTY, ShelfStackView.BAY_EMPTY])
	var bays := stack.get_node("Reihe2/Mulden2") as Node3D
	var segment := bays.get_node("Mulde0") as Node3D
	var lo := INF
	var hi := -INF
	for child in segment.get_children():
		if child.name != &"Deck" and not String(child.name).begins_with("Lippe"):
			continue
		var box := child as MeshInstance3D
		var half := (box.mesh as BoxMesh).size.x * 0.5
		lo = minf(lo, bays.position.x + box.position.x - half)
		hi = maxf(hi, bays.position.x + box.position.x + half)
	var bounds := stack.plate_bounds(1)
	assert_almost_eq(lo, bounds.x, 0.001, "unten bis an die Kachelgrenze")
	assert_almost_eq(hi, bounds.y, 0.001, "oben ebenso")

func test_der_muldenboden_traegt_die_auskleidung_der_grube() -> void:
	stack.set_bay_tints(0, [ShelfStackView.BAY_EMPTY, ShelfStackView.BAY_EMPTY])
	var ground_node := stack.get_node("Reihe1/Mulden1/Mulde0/Boden") as MeshInstance3D
	var ground := ground_node.material_override as ShaderMaterial
	assert_not_null(ground, "der Muldenboden ist ausgekleidet")
	assert_almost_eq(float(ground.get_shader_parameter("velvet")), 1.0, 0.001)
	var tone: Color = ground.get_shader_parameter("base_color")
	assert_gt(tone.v, PackPitView.FLOOR_ALBEDO.v, "heller als der Grubenboden")
	assert_lt(tone.v, ShelfStackView.POCKET_FLOOR_ALBEDO.v, "aber dunkler als die Tasche")
	assert_eq(ground.get_shader_parameter("field_center"), stack._pit_field().get_center(),
		"das Samt-Feld ist die GANZE Grube")

func test_umfaerben_baut_nichts_neu_umzaehlen_schon() -> void:
	stack.set_bay_tints(1, [ShelfStackView.BAY_EMPTY, ShelfStackView.BAY_EMPTY])
	var before := stack.get_node("Reihe2/Mulden2")
	stack.set_bay_tints(1, [PackDrawerView.GOLD, ShelfStackView.BAY_EMPTY])
	assert_eq(stack.get_node("Reihe2/Mulden2"), before, "derselbe Knoten")
	stack.set_bay_tints(1, [PackDrawerView.GOLD, ShelfStackView.BAY_EMPTY, PackDrawerView.GOLD])
	assert_eq(stack.bay_count(1), 3)
	assert_ne(stack.get_node("Reihe2/Mulden2"), before, "drei Plätze sind ein neuer Bau")

func test_die_platten_sind_undurchsichtig_und_ohne_rand() -> void:
	var top := (stack.get_node("Reihe1/Platte") as MeshInstance3D) \
		.material_override as StandardMaterial3D
	var deep := (stack.get_node("Reihe4/Platte") as MeshInstance3D) \
		.material_override as StandardMaterial3D
	assert_not_null(top)
	assert_eq(top.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "undurchsichtig")
	assert_eq(deep, top, "alle teilen das eine Material")

func test_die_buchse_sitzt_am_kartenfuss() -> void:
	stack.set_bay_tints(0, [ShelfStackView.BAY_EMPTY])
	var socket := stack.get_node("Reihe1/Mulden1/Mulde0/Buchse") as Node3D
	assert_not_null(socket)
	assert_almost_eq(socket.position.z, DataCellView.HEIGHT * SCALE * 0.5, 0.0001,
		"der Mund ist der Kartenfuß")
	assert_almost_eq(socket.position.y,
		ShelfStackView.PROUD + DataCellView.DEPTH * SCALE * 0.5, 0.0001, "auf Stifthöhe")
	assert_lte(socket.position.z + DataCellView.SOCKET_DEPTH,
		stack.bay_size(1).y * 0.5 + 0.0001, "und sie bleibt in ihrer Mulde")

# --- Die WANDTASCHEN --------------------------------------------------------------------

func test_die_wandtaschen_liegen_hinter_beiden_grubenwaenden() -> void:
	var right := stack.get_node("Wandtaschen/Wandtasche/Rueckwand") as MeshInstance3D
	assert_gt(right.global_position.z, SPAN.y * 0.5, "rechts hinter der Grubenwand")
	var floor_plate := stack.get_node("Wandtaschen/Wandtasche/Boden") as MeshInstance3D
	assert_lt(floor_plate.position.y, -ShelfStackView.stack_depth(SCALE),
		"ihr Boden liegt unter der Platte")
	assert_null(stack.get_node_or_null("Wandtaschen/Wandtasche/Vorderwand"),
		"zur Grube hin ist sie offen")
	var left := stack.get_node("Wandtaschen/WandtascheLinks/Rueckwand") as MeshInstance3D
	assert_lt(left.global_position.z, -SPAN.y * 0.5, "links ebenso")

## Die LINKE endet vor dem Graben der Walze, die RECHTE am Displayrand.
func test_die_wandtaschen_enden_an_den_gemeldeten_grenzen() -> void:
	var limit := -SPAN.y * 0.5 - 1.0
	assert_lt((stack.get_node("Wandtaschen/WandtascheLinks/Rueckwand") as Node3D)
		.global_position.z, limit, "ohne Grenze reicht sie weiter")
	stack.left_pocket_limit_z = limit
	var decke := stack.get_node("Wandtaschen/WandtascheLinks/Decke") as MeshInstance3D
	var bb := decke.global_transform * decke.get_aabb()
	assert_gte(minf(bb.position.z, bb.end.z), limit - 0.001, "mit Grenze endet sie davor")
	var right_limit := SPAN.y * 0.5 + 1.0
	stack.pocket_limit_z = right_limit
	var right := stack.get_node("Wandtaschen/Wandtasche/Decke") as MeshInstance3D
	var rb := right.global_transform * right.get_aabb()
	assert_lte(maxf(rb.position.z, rb.end.z), right_limit + 0.001, "rechts ebenso")

func test_die_wandtasche_traegt_die_auskleidung_der_grube() -> void:
	var skin := PlaceholderTexture2D.new()
	stack.wall_skin = skin
	for side in ["Wandtasche", "WandtascheLinks"]:
		var ground := (stack.get_node("Wandtaschen/%s/Boden" % side) as MeshInstance3D) \
			.material_override as ShaderMaterial
		assert_almost_eq(float(ground.get_shader_parameter("velvet")), 1.0, 0.001)
		assert_null(ground.get_shader_parameter("wall_tex"), "%s: Samt ohne Haut" % side)
		var flank := (stack.get_node("Wandtaschen/%s/Flanke0" % side) as MeshInstance3D) \
			.material_override as ShaderMaterial
		assert_eq(flank.get_shader_parameter("base_color"), PackPitView.WALL_ALBEDO)
		assert_eq(flank.get_shader_parameter("wall_tex"), skin)

# --- Das ROLLEN, je Reihe für sich ------------------------------------------------------

func test_ein_zug_fuehrt_nur_das_fach_seiner_reihe() -> void:
	var cell := _cell(0, 0.0)
	var other := _cell(1, 0.0)
	var before := cell.global_position.z
	stack.drag_scroll(0, -0.8)
	assert_true(stack.riding(), "solange der Zug läuft, hält der Sitz-Schreiber still")
	assert_almost_eq(stack.scroll_offset(0), -0.8, 0.0001)
	assert_almost_eq(cell.global_position.z, before - 0.8, 0.0001, "die Karte reist mit")
	assert_almost_eq(stack.scroll_offset(1), 0.0, 0.0001, "die Nachbarreihe steht")
	assert_almost_eq(other.global_position.z, 0.0, 0.0001)

func test_das_einrasten_uebernimmt_den_versatz_in_die_karten() -> void:
	var cell := _cell(2, 0.0)
	var before := cell.global_position.z
	var done: Array[int] = []
	stack.drag_scroll(2, -0.5)
	stack.snap_scroll(2, -0.5, -1.0, func() -> void: done.append(1))
	await wait_seconds(ShelfStackView.SNAP_TIME + 0.1)
	assert_eq(done.size(), 1, "das Einrasten meldet sich")
	assert_almost_eq(stack.scroll_offset(2), 0.0, 0.0001, "das Fach steht wieder auf 0")
	assert_almost_eq(cell.global_position.z, before - 1.0, 0.0001,
		"und die Karte liegt eine Spalte weiter")
	assert_false(stack.riding())

## Ein Zug an einer ANDEREN Reihe beendet ein laufendes Einrasten hart - es schuldet nichts.
func test_ein_neuer_zug_beendet_das_einrasten_der_anderen_reihe() -> void:
	var cell := _cell(0, 0.0)
	var done: Array[int] = []
	stack.snap_scroll(0, -0.5, -2.0, func() -> void: done.append(1))
	stack.drag_scroll(3, -0.2)
	assert_almost_eq(stack.scroll_offset(0), 0.0, 0.0001)
	assert_almost_eq(cell.global_position.z, -2.0, 0.0001, "sie steht auf dem Ziel")
	await wait_seconds(ShelfStackView.SNAP_TIME_MAX + 0.1)
	assert_almost_eq(cell.global_position.z, -2.0, 0.0001, "und kein Tween fährt sie weiter")

func test_der_harte_weg_nimmt_jeden_zug_zurueck() -> void:
	stack.drag_scroll(0, -0.4)
	stack.settle_scroll_hard()
	assert_false(stack.riding())
	assert_almost_eq(stack.scroll_offset(0), 0.0, 0.0001)

## Das GLIMMEN steht je Reihe an der Wand, hinter der noch Karten liegen.
func test_das_glimmen_steht_je_reihe() -> void:
	stack.set_overflow(1, false, true)
	assert_eq(stack.overflow(1), Vector2i(0, 1))
	assert_eq(stack.overflow(0), Vector2i.ZERO)
	var left := stack.get_node("Reihe2/GlimmenLinks") as MeshInstance3D
	var right := stack.get_node("Reihe2/GlimmenRechts") as MeshInstance3D
	assert_false(left.visible)
	assert_true(right.visible, "rechts liegen noch Karten")
	assert_gt(right.position.z, 0.0, "an der rechten Wand")
	assert_almost_eq(right.position.x, stack.slot_x(1), 0.0001, "auf der Höhe ihrer Reihe")
	assert_false((stack.get_node("Reihe1/GlimmenRechts") as Node3D).visible,
		"die anderen Reihen glimmen nicht")
	stack.set_overflow(1, true, false)
	assert_true(left.visible)
	assert_lt(left.position.z, 0.0)

func test_die_mulden_rollen_mit_dem_fach() -> void:
	stack.set_bay_tints(0, [ShelfStackView.BAY_EMPTY, ShelfStackView.BAY_EMPTY])
	var bays := stack.get_node("Reihe1/Mulden1") as Node3D
	assert_null(bays.get_node_or_null("VorratLinks"),
		"auf Stand 0 endet die Reihe links an ihrer ersten Mulde")
	assert_not_null(bays.get_node_or_null("VorratRechts"))
	stack.set_bay_tints(0, [ShelfStackView.BAY_EMPTY, ShelfStackView.BAY_EMPTY], true)
	bays = stack.get_node("Reihe1/Mulden1") as Node3D
	assert_not_null(bays.get_node_or_null("VorratLinks"), "gerollt liegt auch links Vorrat")
	assert_not_null(bays.get_node_or_null("VorratRechts/Vorrat0/Unterplatte"),
		"und der Vorrat trägt seine Platte")
	stack.drag_scroll(0, -0.8)
	assert_almost_eq(bays.position.z, -0.8, 0.0001, "sie rollen mit")
	stack.settle_scroll_hard()
	assert_almost_eq(bays.position.z, 0.0, 0.0001, "eingerastet zurück auf ihrem Platz")

func test_der_vorrat_fuellt_das_fenster_bei_jedem_zug() -> void:
	var tints := [ShelfStackView.BAY_EMPTY, ShelfStackView.BAY_EMPTY]
	stack.set_bay_tints(0, tints)
	var bays := stack.get_node("Reihe1/Mulden1") as Node3D
	var block := bays.get_node("VorratRechts") as Node3D
	var pitch := SPAN.y / 2.0
	var reach := pitch * float(2 + ShelfStackView.SPARE_EXTRA)
	for z: float in [-0.5, -SPAN.y, -SPAN.y * 3.7, -SPAN.y * 10.0]:
		stack.drag_scroll(0, z)
		var start: float = z + block.position.z
		var real_end: float = z + SPAN.y * 0.5
		assert_lte(start, maxf(real_end, -SPAN.y * 0.5) + 0.001,
			"bei z = %.1f schließt der Vorrat ohne Lücke an" % z)
		assert_gte(start + reach, SPAN.y * 0.5 - 0.001,
			"und reicht bis an den rechten Fensterrand (z = %.1f)" % z)
	stack.settle_scroll_hard()
	assert_almost_eq(block.position.z, SPAN.y * 0.5, 0.0001, "eingerastet wieder am Rand")

func test_ein_weiter_rueckweg_federt_laenger() -> void:
	var pitch := SPAN.y / float(PackDrawerView.COLUMNS)
	assert_almost_eq(stack.snap_time_for(pitch), ShelfStackView.SNAP_TIME, 0.0001)
	assert_gt(stack.snap_time_for(pitch * 3.0), ShelfStackView.SNAP_TIME)
	assert_almost_eq(stack.snap_time_for(pitch * 100.0), ShelfStackView.SNAP_TIME_MAX, 0.0001)

# --- Möbel, keine Fahrt --------------------------------------------------------------

func test_dieselben_masse_bauen_nichts_neu() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	stack.host_card(cell, 0)
	stack.setup(Vector3.ZERO, SPAN, SCALE)
	assert_eq(cell.get_parent().name, "Fach", "und die Karten überleben einen Neuaufbau")
	stack.setup(Vector3.ZERO, SPAN * 1.2, SCALE)
	assert_eq(cell.get_parent().name, "Fach", "auch einen mit neuen Maßen")
