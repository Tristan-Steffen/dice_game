extends GutTest
## Der Tischkörper: die Craps-Wanne um den Inhalt der Anzeige.

func test_der_inhalt_hat_ringsum_luft() -> void:
	var inner := TableBodyView.inner_rect()
	var content := TableBodyView.CONTENT
	assert_true(inner.encloses(content), "der Inhalt liegt in der Wanne")
	assert_almost_eq(content.position.x - inner.position.x, TableBodyView.MARGIN, 0.001)
	assert_almost_eq(inner.end.x - content.end.x, TableBodyView.BACK_MARGIN, 0.001, "hinten die Port-Wand")
	assert_almost_eq(inner.end.y - content.end.y, TableBodyView.MARGIN, 0.001, "rechts")
	assert_gt(content.position.y - inner.position.y, TableBodyView.MARGIN, "links bleibt das Band")

func test_die_wurfgrube_ist_die_waagerechte_mitte() -> void:
	var inner := TableBodyView.inner_rect()
	assert_almost_eq(inner.get_center().y, TableBodyView.PIT_Z, 0.001)

func test_die_anzeige_endet_im_wandkoerper() -> void:
	# Die Wand steht auf ungenutzter Anzeige; hinten wird sie im Wandkörper abgeschnitten.
	var display := TableBodyView.DISPLAY
	var cut := TableBodyView.display_cut_x()
	assert_gt(cut, TableBodyView.inner_rect().end.x, "der Schnitt liegt hinter der Wand")
	var shown := Rect2(display.position, Vector2(cut - display.position.x, display.size.y))
	assert_true(TableBodyView.inner_rect().grow(TableBodyView.WALL_REACH).encloses(shown))

func test_die_rueckwand_steht_an_den_usb_ports() -> void:
	var row := CharmRowView.new()
	add_child_autofree(row)
	var face := row.ports[0].global_position.x + CharmRowView.PORT_PROUD
	# Die Reihe steht im Spiel bei x = -11,652 (scene_root rückt sie an die Wertung).
	assert_almost_eq(face - 11.652, TableBodyView.inner_rect().end.x, 0.05)
	assert_almost_eq(row.ports[0].global_position.y, CharmReaderView.PORT.y, 0.001, "an der Wand, nicht im Tisch")
	assert_eq(CharmRowView.RAIL_HEIGHT, TableBodyView.FOOT_HEIGHT)

func test_der_umriss_ist_geschlossen_und_liegt_im_rechteck() -> void:
	var outline := TableBodyView.inner_outline()
	var inner := TableBodyView.inner_rect().grow(0.001)
	assert_gt(outline.size(), 40)
	for p in outline:
		assert_true(inner.has_point(p), "Punkt %s im Innenrechteck" % p)
	for i in outline.size():
		assert_gt(outline[i].distance_to(outline[(i + 1) % outline.size()]), 0.01, "kein doppelter Punkt")

func test_die_normalen_zeigen_nach_aussen() -> void:
	var outline := TableBodyView.inner_outline()
	var normals := TableBodyView.outline_normals(outline)
	var center := TableBodyView.inner_center()
	for i in outline.size():
		assert_gt(normals[i].dot(outline[i] - center), 0.0)

func test_das_technik_fenster_bleibt_im_freien_band() -> void:
	var band := TableBodyView.free_band()
	assert_gt(band.size.y, 20.0, "das Band ist breit genug für das Fenster")
	assert_lt(band.end.y, TableBodyView.CONTENT.position.y, "links vom Inhalt")
	assert_gt(band.position.y, TableBodyView.inner_rect().position.y, "vor der Wand")

func test_der_koerper_baut_seine_teile() -> void:
	var body := TableBodyView.new()
	add_child_autofree(body)
	for part: String in ["Teppich", "Deck", "Layoutlinie", "Pyramidenwand", "Lichtlippe", "Reling",
			"Zarge", "Stange", "Bein", "Fensterrahmen", "Platine"]:
		assert_not_null(body.get_node_or_null(part), part)
	# Über der Tischebene steht nichts im Inneren der Wanne außer Linie und Fenster.
	var deck := body.get_node("Deck") as MeshInstance3D
	assert_lt(deck.get_aabb().end.y, 0.05)

func test_room_stellt_den_tischkoerper() -> void:
	var room := (load("res://scenes/room.tscn") as PackedScene).instantiate()
	add_child_autofree(room)
	assert_true(room.get_node_or_null("TableBody") is TableBodyView)
