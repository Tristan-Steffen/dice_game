extends GutTest
## Der Ofen des Prägenetzes (StampNetOven): er backt das Netz einer Kassette in
## EINE Textur. Geprüft wird, was den Cache trägt - der Schlüssel hängt am INHALT,
## nicht an der Karte, und die Abdunkelung ist ein eigener Schlüssel.

func _net(amount := 2) -> Array:
	var net := StampNet.empty_net()
	net[1] = StampNet.value_cell(amount)
	net[4] = StampNet.material_cell(DieMaterial.all()[0].id)
	return net

func test_der_schluessel_haengt_am_inhalt_nicht_an_der_karte() -> void:
	var accent := Color("#8be9fd")
	assert_eq(StampNetOven.signature(_net(), accent, []),
		StampNetOven.signature(_net(), accent, []),
		"zwei gleiche Netze sind dasselbe Bild")
	assert_ne(StampNetOven.signature(_net(), accent, []),
		StampNetOven.signature(_net(5), accent, []),
		"ein anderer Wert backt neu")
	assert_ne(StampNetOven.signature(_net(), accent, []),
		StampNetOven.signature(_net(), Color("#ffb347"), []),
		"und ein anderer Ton auch")

func test_die_abdunkelung_ist_ein_eigener_schluessel() -> void:
	var accent := Color("#8be9fd")
	var drained: Array[bool] = [false, true, false, false, false, false]
	assert_ne(StampNetOven.signature(_net(), accent, drained),
		StampNetOven.signature(_net(), accent, []),
		"aufgenommen ist ein anderes Bild")
	assert_ne(StampNetOven.signature(_net(), accent, drained),
		StampNetOven.signature(_net(), accent,
			[false, false, false, false, true, false]),
		"und welche Zelle, steht im Schlüssel")

func test_das_leere_netz_hat_seinen_eigenen_schluessel() -> void:
	var accent := Color("#8be9fd")
	assert_ne(StampNetOven.signature(StampNet.empty_net(), accent, []),
		StampNetOven.signature(_net(), accent, []))

func test_die_backung_ist_klein_und_traegt_das_kreuz_unverzerrt() -> void:
	var span := StampNetOven.span()
	var pixels := StampNetOven.size_px()
	assert_almost_eq(span.x, DieNetView.net_size(StampNetOven.CELL).y, 0.001)
	assert_gte(float(pixels.x), span.x, "aufgerundet, nie beschnitten")
	assert_gte(float(pixels.y), span.y)
	assert_lte(pixels.x, 256, "ein Mini-Netz, kein Plakat")

func test_der_ofen_backt_das_netz_in_seiner_groesse() -> void:
	var oven := StampNetOven.bake(_net(), Color("#8be9fd"))
	autofree(oven)
	assert_eq(oven.size, StampNetOven.size_px())
	assert_true(oven.transparent_bg, "die Zellen tragen echtes Alpha")
	assert_false(oven.use_hdr_2d)
	assert_true(oven.disable_3d)
	assert_eq(oven.get_child_count(), 1, "das Netz, sonst nichts")

# --- WELLE L: es gibt nur noch EINE Backung -------------------------------------

func test_die_eine_backung_stellt_das_kreuz_hochkant() -> void:
	var flat := DieNetView.net_size(StampNetOven.CELL)
	var span := StampNetOven.span()
	assert_almost_eq(span.x, flat.y, 0.001, "3 Zellen breit statt 4")
	assert_almost_eq(span.y, flat.x, 0.001, "und 4 hoch statt 3")
	assert_gt(span.y, span.x, "die Backung liegt hochkant - die Karte dreht sie auf")
	assert_eq(StampNetOven.size_px(), Vector2i(int(ceilf(span.x)),
		int(ceilf(span.y))), "die Textur folgt ihr")

func test_der_ofen_kennt_keine_zweite_orientierung_mehr() -> void:
	# Die UNGEDREHTE Backung ist gestorben: Magazin, Laden-Vitrine, Schwarzmarkt,
	# Wett-Gewinn und Schacht bestellen alle dieselbe.
	var oven := StampNetOven.bake(_net(), Color("#8be9fd"))
	autofree(oven)
	assert_eq(oven.size, StampNetOven.size_px())
	assert_gt(oven.size.y, oven.size.x, "hochkant, und zwar immer")

func test_ein_leeres_netz_wird_in_seinem_ton_gebacken() -> void:
	# Eine Kassette ohne Paket (Wett-Gewinn) stünde sonst als schwarzes Gitter da.
	var accent := Color("#ff6688")
	var oven := StampNetOven.bake(StampNet.empty_net(), accent)
	autofree(oven)
	var drawing: Control = oven.get_child(0)
	assert_eq(drawing.modulate, accent)
	var filled := StampNetOven.bake(_net(), accent)
	autofree(filled)
	assert_eq((filled.get_child(0) as Control).modulate, Color.WHITE,
		"ein gefülltes Netz spricht für sich")
