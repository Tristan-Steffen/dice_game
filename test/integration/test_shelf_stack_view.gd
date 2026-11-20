extends GutTest
## Das SORTEN-MAGAZIN: VIER TRAYS nebeneinander, je Sorte einer in eigener Grube, alle
## gleich hoch. Jeder rollt für sich senkrecht (Welt-X); die Karten sind Kinder des Faches
## ihres Trays und reisen mit. Keine Karte ragt je über die Tischkante, was das Fenster
## verlassen hat, ist weggesteckt, und jeder Tray trägt das Gerät seines Datenträgers.

## Die Grube in Welt: x quer (Bild-hoch, ZWEI Reihen), y längs (Bild-breit, VIER Spalten
## zu je zwei Karten nebeneinander).
const SPAN := Vector2(8.6, 50.0)
const SCALE := PackDrawerView.CASSETTE_SCALE
## Die Invariante der Wurzel: nichts liegt höher als das im Tisch.
const RIM_LIMIT := -0.11
const COLUMNS := PackDrawerView.COLUMNS

var stack: ShelfStackView

func before_each() -> void:
	stack = ShelfStackView.new()
	add_child_autofree(stack)
	stack.setup(Vector3.ZERO, SPAN, SCALE)

## Leere Plätze für so viele Karten (zwei Reihen = vier Plätze).
func _empties(count: int) -> Array[Color]:
	var tints: Array[Color] = []
	for i in count:
		tints.append(ShelfStackView.BAY_EMPTY)
	return tints

func _column_node(column: int) -> Node3D:
	return stack.get_node("Spalte%d" % (column + 1)) as Node3D

func _cell(column: int, x: float) -> DataCellView:
	var cell := DataCellView.new()
	add_child_autofree(cell)
	cell.setup(String(Pack.SHELF_ORDER[column]))
	cell.global_position = Vector3(x, stack.card_seat(column), stack.slot_z(column))
	stack.host_card(cell, column)
	return cell

# --- Spalten und Höhe ----------------------------------------------------------------

func test_vier_spalten_eine_je_sorte() -> void:
	assert_eq(stack.column_count(), Pack.SHELF_ORDER.size())
	for column in COLUMNS:
		assert_not_null(_column_node(column), "Spalte %d steht" % (column + 1))
		assert_ne(stack.fach(column), stack.fach((column + 1) % COLUMNS),
			"jede hat ihr eigenes Fach")

func test_alle_spalten_liegen_gleich_hoch() -> void:
	for column in COLUMNS:
		assert_almost_eq(_column_node(column).position.y, -ShelfStackView.read_drop(SCALE),
			0.0001)
		assert_almost_eq(stack.card_seat(column), stack.card_seat(0), 0.0001)

## Spalte 1 liegt Bild-links (Welt -Z), die nächste rechts daneben.
func test_die_spalten_laufen_von_links_nach_rechts() -> void:
	for column in range(1, COLUMNS):
		assert_gt(stack.lane_z(column), stack.lane_z(column - 1))

func test_das_magazin_ist_flach() -> void:
	assert_almost_eq(ShelfStackView.stack_depth(SCALE),
		ShelfStackView.read_drop(SCALE) + ShelfStackView.PLATE, 0.0001)
	assert_lt(ShelfStackView.stack_depth(SCALE), 1.0, "unter einer Welteinheit tief")

## GEMELDET liegen die Trays auf den genannten Mitten; ihre Platte ist genau ihre Grube.
func test_die_platte_ist_die_grube() -> void:
	var lanes: Array[Vector2] = [Vector2(-9.9, 5.7), Vector2(-3.3, 5.7),
		Vector2(3.3, 5.7), Vector2(9.9, 5.7)]
	stack.setup(Vector3.ZERO, Vector2(SPAN.x, 25.5), SCALE, lanes)
	assert_almost_eq(stack.lane_width(1), 5.7, 0.0001, "die gemeldete Breite")
	for column in COLUMNS:
		assert_almost_eq(stack.plate_bounds(column).x, lanes[column].x - 2.85, 0.0001)
		assert_almost_eq(stack.plate_bounds(column).y, lanes[column].x + 2.85, 0.0001)
	var plate := stack.get_node("Spalte2/Platte") as MeshInstance3D
	assert_almost_eq((plate.mesh as BoxMesh).size.z, 5.7, 0.0001)
	assert_almost_eq(plate.position.z, -3.3, 0.0001)

func test_ohne_meldung_gleiche_streifen() -> void:
	assert_almost_eq(stack.lane_width(), SPAN.y / float(COLUMNS), 0.0001)
	assert_almost_eq(stack.rail_width(), stack.lane_width() * PackDrawerView.RAIL_SHARE,
		0.0001, "und die Schiene nimmt den Anteil, den auch das Fenster freihält")
	assert_almost_eq(stack.slot_z(0) + stack.slot_width(0) * 0.5,
		stack.rail_z(0) - stack.rail_width(0) * 0.5, 0.0001, "die Plätze enden an der Schiene")

# --- Die Invariante: nichts über der Tischkante ------------------------------------

func test_keine_karte_ragt_ueber_die_tischkante() -> void:
	for column in COLUMNS:
		assert_lte(stack.card_top(column), RIM_LIMIT)
		assert_gt(stack.card_top(column), RIM_LIMIT - DataCellView.lying_over(SCALE))

func test_die_karte_liegt_auf_der_trittflaeche() -> void:
	assert_almost_eq(stack.card_seat(0), stack.tray_top(0) + ShelfStackView.PROUD, 0.0001)
	assert_almost_eq(stack.card_top(0) - stack.card_seat(0),
		DataCellView.lying_over(SCALE), 0.0001)

func test_der_griff_zieht_die_karte_ueber_die_kante() -> void:
	var lift := ShelfStackView.hover_lift(SCALE) * DataCellView.STAND_HEIGHT * SCALE
	assert_gt(stack.card_top(0) + lift, 0.0, "gegriffen steht sie über dem Glas")

# --- Die Karten sind Kinder ihres Faches -------------------------------------------

func test_sie_meldet_ob_eine_karte_schon_liegt() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	var at := Vector3(2.0, stack.card_seat(0), stack.slot_z(0))
	assert_false(stack.seated(cell, 0, at), "noch gehört sie nicht dazu")
	cell.global_position = at
	stack.host_card(cell, 0)
	assert_eq(cell.get_parent().name, "Fach")
	assert_almost_eq(cell.position.y, ShelfStackView.PROUD, 0.0001)
	assert_true(stack.seated(cell, 0, at))
	assert_false(stack.seated(cell, 2, at), "und nur in IHRER Spalte")
	assert_false(stack.seated(cell, 0, at + Vector3(1.0, 0.0, 0.0)))

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

# --- WEGGESTECKT: was das Fenster verlassen hat ------------------------------------

func test_eine_karte_ausserhalb_des_fensters_ist_weggesteckt() -> void:
	var half := DataCellView.WIDTH * SCALE * 0.5
	var inside := _cell(0, 0.0)
	var above := _cell(0, SPAN.x * 0.5 + half * 2.5)
	var below := _cell(0, -SPAN.x * 0.5 - half * 2.5)
	var touching := _cell(0, SPAN.x * 0.5 + stack.top_pocket_depth() - half + 0.01)
	var clear := _cell(0, SPAN.x * 0.5 - half - 0.01)
	assert_false(inside.tucked(), "im Fenster liegt sie offen")
	assert_true(above.tucked(), "oben ganz draußen ist sie weggesteckt")
	assert_true(below.tucked(), "unten ebenso")
	assert_true(touching.tucked(), "mit der Kante über der Tasche ist sie fort")
	assert_false(clear.tucked(), "ganz im Fenster liegt sie offen")
	assert_true(inside.visible and above.visible, "visible gehört dem Sitz-Schreiber")

func test_ein_zug_steckt_weg_und_holt_herein() -> void:
	var cell := _cell(1, 0.0)
	stack.drag_scroll(1, SPAN.x)
	assert_true(cell.tucked(), "hinausgezogen verschwindet sie")
	stack.drag_scroll(1, 0.0)
	assert_false(cell.tucked(), "und kommt zurück")

func test_hinausgerollte_mulden_verschwinden() -> void:
	stack.top_pocket_limit_x = SPAN.x * 0.5 + 0.3  # oben liegt der Graben der Walze
	stack.set_bay_tints(0, _empties(4), true)
	var bays := stack.get_node("Spalte1/Mulden1") as Node3D
	assert_true((bays.get_node("Mulde0") as Node3D).visible, "im Fenster stehen sie")
	assert_false((bays.get_node("VorratOben/Vorrat0") as Node3D).visible,
		"der obere Vorrat ruht unsichtbar")
	stack.drag_scroll(0, -SPAN.x * 0.5 + 0.1)
	assert_true((bays.get_node("VorratOben/Vorrat0") as Node3D).visible,
		"hereingezogen erscheint er")
	stack.drag_scroll(0, SPAN.x)
	assert_false((bays.get_node("Mulde0") as Node3D).visible, "hinausgerollt ist das Stück fort")
	stack.settle_scroll_hard()
	assert_true((bays.get_node("Mulde0") as Node3D).visible)

func test_wer_das_fach_verlaesst_ist_nie_weggesteckt() -> void:
	var cell := _cell(0, SPAN.x * 2.0)
	assert_true(cell.tucked())
	ShelfStackView.rehost(cell, self)
	assert_false(cell.tucked(), "auf dem Weg zur Walze ist sie sichtbar")

# --- Die FASSUNG und die LICHTLEISTE -------------------------------------------------

## Jeder Tray trägt seine Fassung auf dem Filz, und sie bleibt niedrig.
func test_jeder_tray_hat_seine_niedrige_fassung() -> void:
	for column in COLUMNS:
		var frame := stack.get_node("Fassung%d" % (column + 1)) as Node3D
		assert_not_null(frame, "Tray %d trägt seine Fassung" % (column + 1))
		assert_almost_eq(frame.position.z, stack.lane_z(column), 0.0001)
		for node in frame.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var box := mesh.global_transform * mesh.get_aabb()
			assert_lte(box.end.y, PackPitView.RIM_H + 0.001, "%s bleibt niedrig" % mesh.name)

## Die vier Geräte unterscheiden sich in Fassung, Innerem und Boden.
func test_die_vier_geraete_sind_verschieden() -> void:
	for a in COLUMNS:
		for b in range(a + 1, COLUMNS):
			assert_ne(MagazinTrayDress.frame_material(a).albedo_color,
				MagazinTrayDress.frame_material(b).albedo_color, "Fassung %d/%d" % [a, b])
			assert_ne(MagazinTrayDress.floor_material(a).albedo_color,
				MagazinTrayDress.floor_material(b).albedo_color, "Boden %d/%d" % [a, b])
	assert_not_null(stack.get_node_or_null("Fassung1/SchieneOben"), "Kartenzufuhr: Schienen")
	assert_not_null(stack.get_node_or_null("Fassung1/Transportloch0"))
	assert_not_null(stack.get_node_or_null("Fassung2/Wickeldorn0"), "Deck: Wickeldorne")
	assert_not_null(stack.get_node_or_null("Fassung2/Tonkopf"))
	assert_not_null(stack.get_node_or_null("Fassung3/WulstX0"), "Steinbett: Wulst")
	assert_not_null(stack.get_node_or_null("Fassung3/Kerbe0_0"))
	assert_not_null(stack.get_node_or_null("Fassung4/Kontakt0"), "Einschub: Kontaktleiste")
	assert_not_null(stack.get_node_or_null("Fassung4/Bolzen0"))
	# Der Leuchttisch der Kartenzufuhr ist der hellste Boden.
	var light := MagazinTrayDress.floor_material(0)
	for column in range(1, COLUMNS):
		var other := MagazinTrayDress.floor_material(column)
		assert_gt(light.emission.get_luminance() * light.emission_energy_multiplier,
			other.emission.get_luminance() * other.emission_energy_multiplier)

## Die Lichtleiste liegt UNTEN vor dem Loch, nennt Name und Zähler und leuchtet hervorgehoben.
func test_die_lichtleiste_nennt_sorte_und_zaehler() -> void:
	for column in COLUMNS:
		var bar := stack.get_node("Fassung%d/Lichtleiste" % (column + 1)) as MeshInstance3D
		var bb := bar.global_transform * bar.get_aabb()
		assert_lt(bb.end.x, -SPAN.x * 0.5, "unter dem Loch, nicht darin")
	stack.set_bar(1, "Material 5")
	var label := stack.get_node("Fassung2/Aufschrift") as Label3D
	assert_eq(label.text, "Material 5")
	assert_eq(stack.bar_text(1), "Material 5")
	var rest := stack.bar_energy(1)
	stack.set_highlight(1)
	assert_eq(stack.highlighted(), 1)
	assert_gt(stack.bar_energy(1), rest, "hervorgehoben leuchtet sie heller")
	assert_almost_eq(stack.bar_energy(0), rest, 0.0001, "die anderen nicht")
	stack.set_highlight(-1)
	assert_almost_eq(stack.bar_energy(1), rest, 0.0001)

# --- Die MULDEN -------------------------------------------------------------------------

## Je Reihe ein Stück, darin ACROSS Mulden nebeneinander; Platz i ist Reihe i / ACROSS,
## Querplatz i % ACROSS.
func test_je_platz_eine_mulde_mit_saum_in_der_sortenfarbe() -> void:
	var tints: Array[Color] = [PackDrawerView.COLORS[Engraving.CATEGORY_DICE],
		ShelfStackView.BAY_EMPTY, ShelfStackView.BAY_EMPTY,
		PackDrawerView.COLORS[Engraving.CATEGORY_DICE]]
	stack.set_bay_tints(2, tints)
	assert_eq(stack.bay_count(2), 4)
	assert_eq(stack.bay_tint(2, 0), tints[0])
	assert_eq(stack.bay_tint(2, 1), ShelfStackView.BAY_EMPTY, "leer ist stumpf")
	var bays := stack.get_node("Spalte3/Mulden3")
	assert_gt((bays.get_node("Mulde0") as Node3D).position.x,
		(bays.get_node("Mulde1") as Node3D).position.x, "Reihe 0 liegt oben")
	assert_null(bays.get_node_or_null("Mulde2"), "vier Plätze sind zwei Reihen")
	for part in ["Saum", "Boden", "Buchse"]:
		assert_not_null(bays.get_node_or_null("Mulde0/Platz0/" + part))
		assert_not_null(bays.get_node_or_null("Mulde0/Platz1/" + part))
	assert_gt((bays.get_node("Mulde0/Platz1") as Node3D).position.z,
		(bays.get_node("Mulde0/Platz0") as Node3D).position.z, "Querplatz 1 rechts daneben")
	var lit := (bays.get_node("Mulde0/Platz0/Saum") as MeshInstance3D).material_override \
		as StandardMaterial3D
	var dull := (bays.get_node("Mulde0/Platz1/Saum") as MeshInstance3D).material_override \
		as StandardMaterial3D
	var corner := (bays.get_node("Mulde1/Platz1/Saum") as MeshInstance3D).material_override \
		as StandardMaterial3D
	assert_eq(lit.emission, tints[0])
	assert_eq(corner.emission, tints[3], "Platz 3: zweite Reihe, rechts")
	assert_gt(lit.emission_energy_multiplier, dull.emission_energy_multiplier)

func test_die_mulde_ist_eine_vertiefung_und_die_karte_buendig() -> void:
	stack.set_bay_tints(0, _empties(4))
	var top := ShelfStackView.PROUD + DataCellView.DEPTH * SCALE
	assert_almost_eq(stack.deck_height(), top, 0.0001)
	var bays := stack.get_node("Spalte1/Mulden1") as Node3D
	for part in ["Mulde0/Lippe0", "Mulde1/RippeO"]:
		var box := bays.get_node(part) as MeshInstance3D
		assert_almost_eq(box.position.y + (box.mesh as BoxMesh).size.y * 0.5, top, 0.0001, part)
	var bed := stack.get_node("Spalte1/Rollschiene/Bett0") as MeshInstance3D
	assert_almost_eq(bed.position.y + (bed.mesh as BoxMesh).size.y * 0.5, top, 0.0001,
		"das Schienenbett ist bündig mit dem Deck")
	var bay := stack.bay_size(2)
	assert_gt(bay.x, DataCellView.WIDTH * SCALE, "längs der Spalte weiter als die Karte breit")
	assert_gt(bay.y, DataCellView.HEIGHT * SCALE, "quer weiter als die Karte lang")
	assert_lt(bay.y * float(ShelfStackView.ACROSS), stack.slot_width(0),
		"und zwei passen mit Lippe nebeneinander")
	assert_lt(bay.x, SPAN.x * 0.5, "und zwei passen mit Lippe untereinander")

## Lippen und Schiene decken die ganze Grube - links bis an die Wand, rechts die Schiene.
func test_lippen_und_schiene_decken_die_grube() -> void:
	stack.set_bay_tints(1, _empties(4))
	var bays := stack.get_node("Spalte2/Mulden2") as Node3D
	var segment := bays.get_node("Mulde0") as Node3D
	var lo := INF
	var hi := -INF
	for child in segment.get_children():
		if not String(child.name).begins_with("Lippe"):
			continue
		var box := child as MeshInstance3D
		var half := (box.mesh as BoxMesh).size.z * 0.5
		lo = minf(lo, bays.position.z + box.position.z - half)
		hi = maxf(hi, bays.position.z + box.position.z + half)
	var bounds := stack.plate_bounds(1)
	assert_almost_eq(lo, bounds.x, 0.001, "links bis an die Grubenwand")
	assert_almost_eq(hi, stack.rail_z(1) - stack.rail_width(1) * 0.5, 0.001, "rechts bis zur Schiene")
	var rail := stack.get_node("Spalte2/Rollschiene") as Node3D
	assert_almost_eq(rail.position.z + stack.rail_width(1) * 0.5, bounds.y, 0.001,
		"die Schiene schließt an der rechten Wand")

func test_umfaerben_baut_nichts_neu_umzaehlen_schon() -> void:
	stack.set_bay_tints(1, _empties(4))
	var before := stack.get_node("Spalte2/Mulden2")
	var gold := _empties(4)
	gold[0] = PackDrawerView.GOLD
	stack.set_bay_tints(1, gold)
	assert_eq(stack.get_node("Spalte2/Mulden2"), before)
	stack.set_bay_tints(1, _empties(6))
	assert_eq(stack.bay_count(1), 6)
	assert_ne(stack.get_node("Spalte2/Mulden2"), before)

func test_die_buchse_sitzt_am_kartenfuss() -> void:
	stack.set_bay_tints(0, [ShelfStackView.BAY_EMPTY])
	var socket := stack.get_node("Spalte1/Mulden1/Mulde0/Platz0/Buchse") as Node3D
	assert_not_null(socket)
	assert_almost_eq(socket.position.z, DataCellView.HEIGHT * SCALE * 0.5, 0.0001)

# --- Die WANDTASCHEN --------------------------------------------------------------------

func test_die_wandtaschen_liegen_hinter_den_waenden_oben_und_unten() -> void:
	for column in COLUMNS:
		var path := "Wandtaschen/Spalte%d/" % (column + 1)
		var top := stack.get_node(path + "WandtascheOben/Rueckwand") as MeshInstance3D
		assert_gt(top.global_position.x, SPAN.x * 0.5, "oben hinter der Grubenwand")
		assert_almost_eq(top.global_position.z, stack.lane_z(column), 0.0001, "je Tray eine")
		var bottom := stack.get_node(path + "WandtascheUnten/Rueckwand") as MeshInstance3D
		assert_lt(bottom.global_position.x, -SPAN.x * 0.5, "unten ebenso")
		assert_null(stack.get_node_or_null(path + "WandtascheOben/Vorderwand"))
		var flank := stack.get_node(path + "WandtascheOben/Flanke1") as MeshInstance3D
		var bb := flank.global_transform * flank.get_aabb()
		assert_lte(bb.end.z, stack.lane_z(column) + stack.lane_width(column) * 0.5
			+ ShelfStackView.POCKET_WALL + 0.001, "so breit wie die eigene Grube")

func test_die_wandtaschen_enden_an_den_gemeldeten_grenzen() -> void:
	var limit := SPAN.x * 0.5 + 0.5
	stack.top_pocket_limit_x = limit
	var decke := stack.get_node("Wandtaschen/Spalte1/WandtascheOben/Decke") as MeshInstance3D
	var bb := decke.global_transform * decke.get_aabb()
	assert_lte(maxf(bb.position.x, bb.end.x), limit + 0.001, "oben vor dem Graben")
	var low := -SPAN.x * 0.5 - 1.0
	stack.bottom_pocket_limit_x = low
	var unten := stack.get_node("Wandtaschen/Spalte1/WandtascheUnten/Decke") as MeshInstance3D
	var ub := unten.global_transform * unten.get_aabb()
	assert_gte(minf(ub.position.x, ub.end.x), low - 0.001, "unten am Displayrand")

# --- Das ROLLEN, je Spalte für sich ------------------------------------------------------

func test_ein_zug_fuehrt_nur_das_fach_seiner_spalte() -> void:
	var cell := _cell(0, 0.0)
	var other := _cell(1, 0.0)
	stack.drag_scroll(0, 0.8)
	assert_true(stack.riding())
	assert_almost_eq(stack.scroll_offset(0), 0.8, 0.0001)
	assert_almost_eq(cell.global_position.x, 0.8, 0.0001, "die Karte reist mit")
	assert_almost_eq(stack.scroll_offset(1), 0.0, 0.0001)
	assert_almost_eq(other.global_position.x, 0.0, 0.0001)

func test_das_einrasten_uebernimmt_den_versatz_in_die_karten() -> void:
	var cell := _cell(2, 0.0)
	var done: Array[int] = []
	stack.drag_scroll(2, 0.5)
	stack.snap_scroll(2, 0.5, 1.0, func() -> void: done.append(1))
	await wait_seconds(ShelfStackView.SNAP_TIME + 0.1)
	assert_eq(done.size(), 1)
	assert_almost_eq(stack.scroll_offset(2), 0.0, 0.0001, "das Fach steht wieder auf 0")
	assert_almost_eq(cell.global_position.x, 1.0, 0.0001, "die Karte liegt einen Platz weiter")
	assert_false(stack.riding())

func test_ein_neuer_zug_beendet_das_einrasten_der_anderen_spalte() -> void:
	var cell := _cell(0, 0.0)
	stack.snap_scroll(0, 0.5, 2.0, func() -> void: pass)
	stack.drag_scroll(3, 0.2)
	assert_almost_eq(cell.global_position.x, 2.0, 0.0001, "sie steht auf dem Ziel")
	await wait_seconds(ShelfStackView.SNAP_TIME_MAX + 0.1)
	assert_almost_eq(cell.global_position.x, 2.0, 0.0001)

# --- Die ROLLSCHIENE --------------------------------------------------------------------

func _thumb(column: int) -> MeshInstance3D:
	return stack.get_node("Spalte%d/Rollschiene/Schieber" % (column + 1)) as MeshInstance3D

## Der Schieber ist so lang wie sichtbare durch alle Reihen und steht, wo gerollt ist.
func test_der_schieber_zeigt_reihen_und_stand() -> void:
	stack.set_rail(0, 2, 2, 0)
	assert_eq(stack.rail_thumb(0), Vector2(0.0, 1.0), "alles sichtbar: er füllt die Schiene")
	var full := _thumb(0).scale.x
	stack.set_rail(0, 4, 2, 0)
	assert_almost_eq(_thumb(0).scale.x, full * 0.5, 0.001, "halb so lang")
	var top := _thumb(0).position.x
	stack.set_rail(0, 4, 2, 2)
	assert_eq(stack.rail_thumb(0), Vector2(0.5, 0.5))
	assert_lt(_thumb(0).position.x, top, "gerollt wandert er nach unten")
	assert_eq(stack.rail_thumb(1), Vector2(0.0, 1.0), "die anderen Trays rühren sich nicht")

## Er folgt dem Zug LIVE und federt mit dem Einrasten; danach steht er auf dem neuen Stand.
func test_der_schieber_folgt_dem_zug_und_dem_einrasten() -> void:
	stack.set_rail(2, 6, 2, 0)
	var pitch := SPAN.x / 2.0
	stack.drag_scroll(2, pitch * 0.5)
	assert_almost_eq(stack.rail_thumb(2).x, 0.5 / 6.0, 0.0001, "eine halbe Reihe gezogen")
	# Losgelassen: gebucht ist schon der neue Stand, das Einrasten fährt auf ihn zu.
	stack.set_rail(2, 6, 2, 1)
	var done: Array[int] = []
	stack.snap_scroll(2, pitch * 0.5, pitch, func() -> void: done.append(1))
	assert_almost_eq(stack.rail_thumb(2).x, 0.5 / 6.0, 0.0001, "kein Sprung beim Buchen")
	await wait_seconds(ShelfStackView.SNAP_TIME + 0.1)
	assert_eq(done.size(), 1)
	assert_almost_eq(stack.rail_thumb(2).x, 1.0 / 6.0, 0.0001, "eingerastet eine Reihe weiter")
	stack.set_rail(2, 6, 2, 1)
	assert_almost_eq(stack.rail_thumb(2).x, 1.0 / 6.0, 0.0001)

func test_der_vorrat_fuellt_das_fenster_bei_jedem_zug() -> void:
	stack.set_bay_tints(0, _empties(4))
	var bays := stack.get_node("Spalte1/Mulden1") as Node3D
	var block := bays.get_node("VorratUnten") as Node3D
	var pitch := SPAN.x / 2.0
	var reach := pitch * float(2 + ShelfStackView.SPARE_EXTRA)
	for x: float in [0.5, SPAN.x, SPAN.x * 3.7, SPAN.x * 10.0]:
		stack.drag_scroll(0, x)
		var start: float = x + block.position.x
		var real_end: float = x - SPAN.x * 0.5
		assert_gte(start, minf(real_end, SPAN.x * 0.5) - 0.001, "bei x = %.1f ohne Lücke" % x)
		assert_lte(start - reach, -SPAN.x * 0.5 + 0.001, "und bis an den unteren Rand")
	stack.settle_scroll_hard()
	assert_almost_eq(block.position.x, -SPAN.x * 0.5, 0.0001)

func test_ein_weiter_rueckweg_federt_laenger() -> void:
	var pitch := SPAN.x / float(PackDrawerView.PLACES)
	assert_almost_eq(stack.snap_time_for(pitch), ShelfStackView.SNAP_TIME, 0.0001)
	assert_gt(stack.snap_time_for(pitch * 3.0), ShelfStackView.SNAP_TIME)
	assert_almost_eq(stack.snap_time_for(pitch * 100.0), ShelfStackView.SNAP_TIME_MAX, 0.0001)

func test_dieselben_masse_bauen_nichts_neu() -> void:
	var cell := Node3D.new()
	add_child_autofree(cell)
	stack.host_card(cell, 0)
	stack.setup(Vector3.ZERO, SPAN, SCALE)
	assert_eq(cell.get_parent().name, "Fach")
	stack.setup(Vector3.ZERO, SPAN * 1.2, SCALE)
	assert_eq(cell.get_parent().name, "Fach")

## Die Kartenzufuhr: der Boden eines Platzes leuchtet nur unter einer Karte, in ihrer Farbe.
func test_der_leuchttisch_leuchtet_nur_unter_einer_karte() -> void:
	var green := Color(0.3, 1.0, 0.5)
	var tints := _empties(4)
	tints[0] = green
	stack.set_bay_tints(0, tints)
	var lit := (stack.get_node("Spalte1/Mulden1/Mulde0/Platz0/Boden") as MeshInstance3D) \
		.material_override as StandardMaterial3D
	var dark := (stack.get_node("Spalte1/Mulden1/Mulde0/Platz1/Boden") as MeshInstance3D) \
		.material_override as StandardMaterial3D
	assert_eq(lit.emission, green)
	assert_almost_eq(lit.emission_energy_multiplier, MagazinTrayDress.LAMP_LIT, 0.001)
	assert_almost_eq(dark.emission_energy_multiplier, MagazinTrayDress.LAMP_DARK, 0.001)
	stack.set_bay_tints(1, tints)
	var deck := (stack.get_node("Spalte2/Mulden2/Mulde0/Platz0/Boden") as MeshInstance3D) \
		.material_override
	assert_eq(deck, MagazinTrayDress.floor_material(1), "die anderen Geräte haben keinen")

## Der Schieber ist ein Knopf mit Griffrillen in zwei Führungsschienen - in JEDEM Tray.
func test_jeder_tray_hat_einen_greifbaren_schieber() -> void:
	for column in COLUMNS:
		var rail := stack.get_node("Spalte%d/Rollschiene" % (column + 1))
		assert_not_null(rail.get_node_or_null("Fuehrung0"))
		assert_not_null(rail.get_node_or_null("Griff/Rille1"))
		stack.set_rail(column, 40, 2, 0)
		assert_gte(_thumb(column).scale.x, MagazinTrayDress.RAIL_THUMB_MIN - 0.001,
			"nie zu kurz zum Greifen")
