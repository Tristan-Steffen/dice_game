extends GutTest
## Die Vitrine als GRUBE: ihre Maße sind gerechnet, nicht getippt. Geprüft wird
## nur die reine Mathematik - Tiefe, Fassung und der gemeinsame Körper mit dem
## Magazin. Wer wo liegt, entscheidet erst die Bucht selbst.

func test_die_verkaufsbucht_misst_ihre_ware_und_steht_doppelt_so_tief() -> void:
	# content_depth misst die höchste LIEGENDE Ware (ein Würfel mit seiner
	# Silhouette) plus die Luft unter der Scheibe - eine stehende Kassette kommt
	# darin nicht vor. Die Grube selbst steht doppelt so tief: der Zuschlag ist der
	# KASTEN, in den geworfen wird.
	var half_die := DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE
	assert_almost_eq(VitrineView.content_depth(),
		VitrineView.DIE_SCALE * VitrineView.CONTENT_DROP + VitrineView.FLOOR_CLEAR
		+ half_die * (1.0 + VitrineView.SILHOUETTE) - PackPitView.WALL_SINK, 0.0001)
	assert_almost_eq(VitrineView.pit_depth(),
		VitrineView.content_depth() * VitrineView.DEPTH_FACTOR, 0.0001)
	assert_gt(VitrineView.DEPTH_FACTOR, 1.0, "tiefer als ihre Ware, nicht flacher")

func test_das_magazin_behaelt_seine_tiefe() -> void:
	# Es rechnet weiter mit einer STEHENDEN Kassette samt Luft - die Verdopplung
	# der Buchten geht es nichts an, die beiden Gruben messen sich getrennt.
	var scene_root: Script = load("res://scripts/scene_root.gd")
	var room: float = scene_root.get_script_constant_map()["PACK_PIT_DEPTH_ROOM"]
	var magazin := DataCellView.HEIGHT * PackDrawerView.CASSETTE_SCALE * room
	assert_gt(magazin, DataCellView.HEIGHT * PackDrawerView.CASSETTE_SCALE,
		"eine stehende Kassette plus Luft")
	assert_gt(VitrineView.pit_depth(), VitrineView.content_depth(),
		"und die Bucht misst sich an ihrer eigenen Regel")

func test_das_loch_liegt_in_der_fassung() -> void:
	# pit_rect_in ist die eine Rechnung, die Magazin UND Bucht teilen.
	var strip := Rect2(120.0, 40.0, 800.0, 400.0)
	var unit := 10.0
	var hole := PackDrawerView.pit_rect_in(strip, unit)
	var inset := PackDrawerView.rim_inset(unit)
	assert_true(strip.encloses(hole), "das Loch bleibt im Streifen")
	assert_almost_eq(hole.position.x - strip.position.x, inset, 0.0001)
	assert_almost_eq(strip.end.y - hole.end.y, inset, 0.0001)
	assert_almost_eq(hole.size.x, strip.size.x - inset * 2.0, 0.0001)

func test_die_grube_traegt_ihre_trimmung_selbst() -> void:
	# Ein zweiter Grubenkörper darf sich unterscheiden, ohne ein zweiter Körper zu
	# sein: die Vorgaben SIND das Magazin.
	var magazin := PackPitView.new()
	assert_eq(magazin.wall, PackPitView.WALL, "Vorgabe = Magazin")
	assert_eq(magazin.glow_color, PackPitView.GLOW_COLOR)
	assert_eq(magazin.name, "PackPit")
	magazin.free()
	var bucht := PackPitView.new("VitrinePit")
	assert_eq(bucht.name, "VitrinePit", "jede Grube trägt ihren eigenen Namen")
	bucht.free()
	assert_ne(VitrineView.GLOW, PackPitView.GLOW_COLOR,
		"die Auslage glimmt wärmer als das Archiv")

func test_die_scheibe_liegt_ueber_dem_glas_und_leuchtet_wie_das_display() -> void:
	assert_gt(VitrineGlassView.LIFT, 0.0, "über dem Display-Glas, nie darin")
	assert_lt(VitrineGlassView.LIFT, 0.2, "aber zu wenig für sichtbare Parallaxe")
	assert_almost_eq(VitrineGlassView.ENERGY, 1.2, 0.0001,
		"derselbe Anzeigeton wie screen_glass.emission_energy")

func test_beide_shader_kennen_dieselben_zwei_buchten() -> void:
	var glass: String = load("res://assets/shaders/screen_glass.gdshader").code
	var ground: String = load("res://assets/shaders/table_ground.gdshader").code
	assert_string_contains(glass, "vitrine_rects", "das Glas schneidet die Löcher")
	assert_string_contains(glass, "vitrine_open", "und fährt ihren Vorhang")
	assert_string_contains(ground, "vitrine_open", "der Boden blendet mit ihnen aus")
	assert_string_contains(glass, "MAX_VITRINES = 2")
	assert_string_contains(ground, "MAX_VITRINES = 2")

# --- Die Auskleidung der Gruben ------------------------------------------------

func test_alle_gruben_teilen_EINE_auskleidung() -> void:
	# Samtboden und Metallpaneele hängen an der einen Grubenklasse - Magazin,
	# Laden und Hinterzimmer erben sie, ohne dass eine davon etwas eigenes baut.
	var lining: String = load("res://assets/shaders/pit_lining.gdshader").code
	assert_string_contains(lining, "velvet", "eine Rolle für Boden, eine für Wand")
	assert_string_contains(lining, "seam_color", "die Neon-Fuge trägt die Grubenfarbe")
	assert_string_contains(lining, "uniform float bay",
		"und EINE Handschrift-Umschaltung: Archiv oder Verkaufs-Bucht")
	assert_lt(PackPitView.FLOOR_ALBEDO.b, PackPitView.WALL_ALBEDO.b,
		"der Boden bleibt dunkler als die Wand")
	# Dunkel bleiben ist die Bedingung: was hier blühte, nähme der Ware die Show.
	for energy: float in [PackPitView.WALL_FIELD_ENERGY, PackPitView.FLOOR_FIELD_ENERGY]:
		assert_lt(PackPitView.WALL_ALBEDO.b * energy, Rune.IDLE_CEILING,
			"die Auskleidung bleibt unter der Ruhe-Schwelle")
	assert_lt(PackPitView.SEAM_ENERGY, 1.0, "die Fuge ist ein Saum, kein Scheinwerfer")

func test_nur_die_verkaufsbuchten_tragen_den_automaten_look() -> void:
	# Das Magazin ist ein ARCHIV - es wirbt nicht. Die Handschrift wird bestellt.
	var magazin := PackPitView.new()
	assert_false(magazin.bay_look, "Vorgabe = Archiv (Samt und Metall)")
	magazin.free()
	var bay := VitrineView.new()
	add_child_autofree(bay)
	bay.setup(Vector3.ZERO, Vector2(9.0, 13.0))
	assert_true(bay.pit.bay_look, "die Bucht bestellt das Automaten-Gehäuse")
	assert_lt(PackPitView.BAY_PANEL_SHARE, PackPitView.PANEL_SHARE,
		"viele schmale Felder lesen als Automatenwand, vier breite Platten nicht")

func test_die_bucht_spricht_nur_in_gold_und_bleibt_gedeckelt() -> void:
	# Die Auslage ist die FASSUNG, nicht der Stein: EINE warme Familie, keine
	# Automatenfarben. Und die Kondensatorbank-Lehre gilt weiter - über der Kappe
	# laufen die drei Kanäle zusammen und aus Gold wird Sahne.
	var lining: String = load("res://assets/shaders/pit_lining.gdshader").code
	for tone: String in ["GOLD", "AMBER"]:
		assert_string_contains(lining, tone, "die Palette der Bucht steht im Shader")
	for gone: String in ["CHERRY", "ACID", "MAGENTA", "TEAL"]:
		assert_false(lining.contains(gone), "die Buntheit ist fort: %s" % gone)
	assert_string_contains(lining, "emission_cap", "und ihre Emission ist gedeckelt")
	assert_lt(PackPitView.BAY_EMISSION_CAP, PackPitView.EMISSION_CAP,
		"die Bucht steht leiser als das Archiv")
	assert_gt(PackPitView.BAY_EMISSION_CAP, 1.0, "aber sie darf blühen")
	# Der Lichtsaum der Bucht ist Amber und bleibt trotzdem unter der Ruhe-Schwelle.
	assert_lt(VitrineView.GLOW.r * VitrineView.GLOW_ENERGY, Rune.IDLE_CEILING)

func test_keine_wand_endet_auf_der_glasebene() -> void:
	# Exakt auf dem Glas kämpften Wandkanten und Anzeige im Tiefenpuffer und
	# flimmerten als Grubenkontur durch die Hub-Startseite.
	assert_gt(PackPitView.WALL_SINK, 0.0, "die Wände enden UNTER der Anzeige")
	assert_lte(PackPitView.WALL_SINK, PackPitView.RIM_SINK + PackPitView.RIM_H,
		"aber nicht tiefer, als der Kragen sie deckt")

# --- Scheibe und Übergang ------------------------------------------------------

func test_das_loch_ist_binaer_die_scheibe_traegt_den_uebergang() -> void:
	var glass: String = load("res://assets/shaders/screen_glass.gdshader").code
	assert_false(glass.contains("vitrine_grain"), "der Rausch-Dissolve ist tot")
	assert_false(glass.contains("vitrine_dissolved"), "und sein Helfer mit ihm")
	assert_string_contains(glass, "vitrine_hole", "das Loch ist auf oder zu")
	var pane: String = load("res://assets/shaders/vitrine_glass.gdshader").code
	assert_string_contains(pane, "display_texture",
		"Lage 1 zeigt denselben Ausschnitt wie das Mesh darunter")
	assert_string_contains(pane, "base_alpha", "und verblasst auf einen Glas-Grundton")

func test_die_offene_scheibe_bleibt_sichtbar_und_dennoch_lesbar() -> void:
	# Bei 0,10 las die Bucht als offenes Loch - dort lag sichtbar GAR NICHTS.
	assert_gte(VitrineGlassView.GLASS_BASE, 0.16,
		"ganz offen muss ablesbar bleiben, DASS Glas darüber liegt")
	assert_lte(VitrineGlassView.GLASS_BASE, 0.22, "aber die Ware bleibt klar lesbar")
	var pane: String = load("res://assets/shaders/vitrine_glass.gdshader").code
	assert_string_contains(pane, "frame_light", "die Fassung trägt einen hellen Strich")
	assert_string_contains(pane, "glint", "und über der hinteren Kante Glanzpunkte")
	assert_string_contains(pane, "drift_speed", "der Schimmer wandert, sehr langsam")
	assert_lt(VitrineGlassView.GLASS_LIFT, VitrineGlassView.LIFT,
		"die Beschriftung steht AUF dem Glas, nicht darin")
	assert_gt(VitrineGlassView.GLASS_LIFT, 0.0, "und das Glas über der Anzeige")

func test_liegende_ware_bleibt_mit_ihrer_SILHOUETTE_unter_dem_glas() -> void:
	# Nicht der Würfelquader entscheidet: Eckkappen und Kantenbalken stehen über
	# ihm, und genau die stachen vorher durch die Anzeige.
	var bay := VitrineView.new()
	bay.center = Vector3.ZERO
	bay.half = Vector2(10.0, 20.0)
	var half_die := DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE
	assert_lt(bay.lie_y(half_die) + half_die * VitrineView.SILHOUETTE, 0.0,
		"auch die Silhouette hängt unter dem Glas")
	bay.free()

# --- Die Plätze der Ware (reine Mathematik, keine Körper) ----------------------

func test_eine_reihe_steht_mittig_und_in_fester_teilung() -> void:
	var spots := VitrineView.row_spots(3, 100.0, 10.0)
	assert_eq(spots.size(), 3)
	assert_almost_eq(spots[0] + spots[2], 0.0, 0.0001, "mittig um die Feldmitte")
	assert_almost_eq(spots[1], 0.0, 0.0001)
	assert_almost_eq(spots[1] - spots[0], 10.0, 0.0001, "feste Teilung, solange sie passt")

func test_eine_volle_reihe_rueckt_zusammen_statt_ueberzulaufen() -> void:
	var span := 30.0
	var spots := VitrineView.row_spots(6, span, 10.0)
	assert_eq(spots.size(), 6)
	assert_lte(spots[5] - spots[0], span, "die Reihe bleibt im Feld")
	assert_lt(spots[1] - spots[0], 10.0, "sie rückt zusammen")

func test_eine_leere_reihe_hat_keine_plaetze() -> void:
	assert_eq(VitrineView.row_spots(0, 100.0, 10.0).size(), 0)
	assert_eq(VitrineView.row_spots(3, 0.0, 10.0).size(), 0)

func test_gattung_und_index_sind_zusammen_der_platz() -> void:
	assert_eq(VitrineView.slot_key(ShopController.KIND_DIE, 2), "die:2")
	assert_ne(VitrineView.slot_key(ShopController.KIND_DIE, 2),
		VitrineView.slot_key(ShopController.KIND_SPECIAL, 2),
		"gleicher Index, andere Gattung - anderer Platz")

# --- Die drei Ankunfts-Grade (reiner Entscheid) --------------------------------

func test_rollen_heisst_zufall_steigen_heisst_abruf() -> void:
	assert_eq(ShopController.grade_for(false, false), ShopController.GRADE_ROLL_IN,
		"eine Seite, die noch nie dalag, wurde gewürfelt")
	assert_eq(ShopController.grade_for(true, false), ShopController.GRADE_RISE,
		"bekannte Ware kehrt zurück - sie wird abgerufen")
	assert_eq(ShopController.grade_for(true, true), ShopController.GRADE_STAND,
		"was schon in der Bucht steht, bleibt liegen")
	assert_eq(ShopController.grade_for(false, true), ShopController.GRADE_ROLL_IN,
		"ein frischer Wurf rollt, egal was vorher dalag")

func test_der_lautere_grad_gewinnt() -> void:
	# Sammeln sich Meldungen an, bis wirklich gestellt wird, darf die leiseste die
	# lauteste nicht verschlucken.
	assert_eq(ShopController.louder_grade(
		ShopController.GRADE_STAND, ShopController.GRADE_ROLL_IN),
		ShopController.GRADE_ROLL_IN)
	assert_eq(ShopController.louder_grade(
		ShopController.GRADE_ROLL_IN, ShopController.GRADE_RISE),
		ShopController.GRADE_ROLL_IN)
	assert_eq(ShopController.louder_grade(
		ShopController.GRADE_RISE, ShopController.GRADE_STAND),
		ShopController.GRADE_RISE)

func test_nur_die_offenen_wuerfel_kollern() -> void:
	# Eine versiegelte Kassette wird abgerufen statt geworfen.
	for kind: String in [ShopController.KIND_ENGRAVING_PACK,
			ShopController.KIND_SPECIAL]:
		assert_eq(VitrineView.item_grade(kind, ShopController.GRADE_ROLL_IN),
			ShopController.GRADE_RISE, "%s steigt, es rollt nicht" % kind)
	assert_eq(VitrineView.item_grade(ShopController.KIND_DIE, ShopController.GRADE_ROLL_IN),
		ShopController.GRADE_ROLL_IN, "der offene Würfel kollert")
	# Steigen und Liegenbleiben gelten für alles gleich.
	for kind: String in [ShopController.KIND_DIE, ShopController.KIND_SPECIAL]:
		assert_eq(VitrineView.item_grade(kind, ShopController.GRADE_STAND),
			ShopController.GRADE_STAND)
		assert_eq(VitrineView.item_grade(kind, ShopController.GRADE_RISE),
			ShopController.GRADE_RISE)

func test_der_umschlag_bleibt_im_budget() -> void:
	# Stöbern darf nicht zäh werden: sinken plus die MECHANISCHE Ankunft (Kassetten
	# steigen) bleibt unter 1,2 s - das ist der Blätter-Umschlag.
	var swap := VitrineView.swap_time(30)
	assert_lte(swap, VitrineView.SWAP_TIME + 0.0001, "die Staffelung ist gedeckelt")
	assert_almost_eq(VitrineView.swap_time(1), VitrineView.SWAP_SINK, 0.0001,
		"ein einzelnes Stück wartet auf niemanden")
	assert_eq(VitrineView.swap_time(0), 0.0, "eine leere Bucht sinkt nicht")
	var rise := VitrineView.entry_time(30, ShopController.GRADE_RISE)
	assert_lte(swap + rise, 1.2, "der mechanische Umschlag bleibt unter 1,2 s")
	assert_eq(VitrineView.entry_time(30, ShopController.GRADE_STAND), 0.0,
		"Liegenbleiben kostet keine Zeit")

func test_das_anrollen_traegt_laenger_und_hat_seinen_eigenen_deckel() -> void:
	# Seit es echte Physik ist, braucht der Wurf mehr Zeit als ein Aufsteigen - aber
	# nie mehr als sein Budget, Staffelung und Aufreihen eingerechnet.
	var roll := VitrineView.entry_time(30, ShopController.GRADE_ROLL_IN)
	assert_gt(roll, VitrineView.entry_time(30, ShopController.GRADE_RISE),
		"das Anrollen ist bewusst die teuerste Bewegung")
	assert_lte(roll, VitrineView.ROLL_BUDGET + 0.0001, "und bleibt in seinem Deckel")
	assert_lte(VitrineView.ROLL_BUDGET, 2.0, "der Deckel selbst steht bei 2 s")
	assert_almost_eq(VitrineView.ROLL_BUDGET,
		VitrineView.ROLL_SPREAD_MAX + VitrineView.ROLL_DEADLINE + VitrineView.ROLL_LINEUP,
		0.0001, "Staffelung, Frist und Aufreihen - mehr steckt nicht darin")

func test_die_wuerfel_treten_gestaffelt_und_gedeckelt_ein() -> void:
	assert_eq(VitrineView.roll_delay(0), 0.0, "der erste wartet auf niemanden")
	assert_almost_eq(VitrineView.roll_delay(1), VitrineView.ROLL_STAGGER, 0.0001)
	assert_lte(VitrineView.roll_delay(6), VitrineView.ROLL_SPREAD_MAX + 0.0001,
		"eine volle Schale sprengt die Staffelung nicht")
	assert_eq(VitrineView.roll_delay(-3), 0.0, "unter null gibt es keine Reihenfolge")

func test_der_fernste_wuerfel_wird_zuerst_geworfen() -> void:
	# Er hat die freie Bahn und kommt am weitesten; die späteren bleiben davor
	# liegen. Sonst zieht das Aufreihen den letzten quer durch alle anderen.
	var entries: Array[Dictionary] = [
		{"kind": ShopController.KIND_DIE, "index": 0, "value": DieDefinition.standard()},
		{"kind": ShopController.KIND_DIE, "index": 1, "value": null},
		{"kind": ShopController.KIND_DIE, "index": 2, "value": DieDefinition.standard()},
		{"kind": ShopController.KIND_SPECIAL, "index": 0, "value": Pack.roll_engraving_pack()},
	]
	var order := VitrineView.roll_order(entries)
	assert_eq(int(order[2]), 0, "der hintere Platz (grösstes z) wirft zuerst")
	assert_eq(int(order[0]), 1, "der vordere danach")
	assert_false(order.has(1), "ein verkaufter Platz wirft nicht")
	assert_false(order.has(3), "und der Sonderposten-Chip kollert nie")

func test_die_sperre_steht_zwischen_schale_und_regal() -> void:
	# Kein anrollender Würfel pflügt in die liegende Ware - und die Bahn davor
	# bleibt breit genug, um überhaupt eine zu sein.
	var bay := VitrineView.new()
	bay.center = Vector3.ZERO
	bay.half = Vector2(9.0, 13.0)
	var bands: Vector2 = bay._band_depths()
	var barrier := bay.roll_barrier_x()
	assert_gte(barrier, bands.y + VitrineView.bowl_reach() - 0.0001,
		"sie steht hinter dem letzten Stück der Schale")
	assert_lte(barrier, bands.x - VitrineView.shelf_reach() + 0.0001,
		"und vor dem ersten der liegenden Kassetten")
	var edge := DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE * 2.0
	assert_gte(barrier - (bay.center.x - bay.half.x), edge,
		"und lässt der Bahn mehr Platz, als ein Würfel breit ist")
	bay.free()

func test_kein_wuerfel_ragt_mehr_ueber_die_anzeigeflaeche() -> void:
	# Der Deckel-Kompromiss der flachen Bucht ist gestorben: der Kasten ist tiefer
	# als die FLÄCHENDIAGONALE eines Würfels, also bleibt der ganze Wurf DARIN.
	var bay := VitrineView.new()
	bay.center = Vector3.ZERO
	bay.half = Vector2(9.0, 13.0)
	var edge := DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE * 2.0
	assert_lt(bay.roll_lid_y(), bay.center.y, "der Deckel liegt UNTER dem Glas")
	assert_gte(bay.roll_lid_y() - bay.floor_y(), edge * sqrt(3.0),
		"und lässt trotzdem eine ganze Umdrehung zu")
	# Auch bündig unter dem Deckel bleibt der Würfel SAMT Lichtlache unter der
	# Anzeigefläche - der Deckel misst sich an der Silhouette, nicht am Quader.
	assert_lte(bay.roll_lid_y()
		+ edge * 0.5 * (VitrineView.SILHOUETTE - 1.0), bay.center.y,
		"und mit ihm die Silhouette")
	bay.free()

func test_die_rollphysik_sieht_nur_sich_selbst() -> void:
	# Eigene Schicht: weder die Spielwürfel (2) noch die Klickzonen der Trays und
	# Chips dürfen je einen Buchten-Würfel treffen.
	assert_ne(VitrineView.ROLL_LAYER, 2, "nicht die Schicht der Spielwürfel")
	for used: int in [1, 2, 8, DiceTrayView.SLOT_PICK_LAYER, DiceShell.CLICK_LAYER,
			DiceShell.GHOST_LAYER, ComboChipView.UPGRADE_PICK_LAYER]:
		assert_ne(VitrineView.ROLL_LAYER, used,
			"Schicht %d ist schon vergeben" % used)

func test_die_gluehplatte_des_chips_bleibt_ueber_dem_grubenboden() -> void:
	# Sie hängt unter dem Zeichen, das Zeichen liegt auf lie_y(0) - fiele die Luft
	# zum Boden darunter, schnitte die Platte in die Bodenplatte.
	assert_gt(VitrineView.FLOOR_CLEAR, VitrineView.CHIP_GLOW_DROP,
		"die Luft über dem Boden trägt die Glühplatte")

func test_die_charm_zeile_blaettert_mit_der_ware() -> void:
	# ui/ greift nicht in table/ - also spiegelt der Laden die Zahl, und dieser
	# Test hält die beiden gleich.
	assert_almost_eq(ShopController.FLIP_DELAY, VitrineView.SWAP_TIME, 0.0001,
		"die neuen Karten erscheinen, wenn auch die neue Ware kommt")

func test_liegende_ware_ruht_auf_dem_grubenboden() -> void:
	# Die alte Regel war "Oberkante bündig unter der Scheibe" - da schwebte alles.
	# Jetzt liegt die Ware AUF dem Boden, und dicke Stücke stehen eben höher.
	var bay := VitrineView.new()
	bay.center = Vector3.ZERO
	bay.half = Vector2(10.0, 20.0)
	var thick := DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE
	assert_almost_eq(bay.lie_y(thick) - thick, bay.lie_y(0.0), 0.0001,
		"dickere Ware steht genau um ihre halbe Höhe höher")
	assert_almost_eq(bay.lie_y(0.0) - bay.floor_y(), VitrineView.FLOOR_CLEAR, 0.0001,
		"eine Haaresbreite über dem Boden, sonst flimmert die Unterseite")
	assert_lt(bay.lie_y(thick) + thick * VitrineView.SILHOUETTE, 0.0,
		"und alles bleibt unter dem Glas")
	bay.free()

func test_der_grubenboden_ist_das_bett_der_ganzen_auslage() -> void:
	var bay := VitrineView.new()
	bay.center = Vector3.ZERO
	bay.half = Vector2(10.0, 20.0)
	assert_almost_eq(bay.floor_y(),
		-PackPitView.WALL_SINK - VitrineView.pit_depth(), 0.0001,
		"die Oberfläche des Bodens, wie PackPitView sie baut")
	# Auch die Kassette liegt darauf - nur um das gehoben, was ihre Finnen unter
	# ihren Ursprung ragen lassen.
	assert_almost_eq(bay.cell_y(),
		bay.lie_y(0.0) + DataCellView.lying_under(PackDrawerView.CASSETTE_SCALE),
		0.0001)
	assert_gt(DataCellView.lying_over(PackDrawerView.CASSETTE_SCALE), 0.0)
	bay.free()

func test_die_anrollbahn_beginnt_auf_dem_boden() -> void:
	# Die Schwelle der Klappe IST der Grubenboden: kein Absatz zwischen Bahn und
	# Roll- bzw. Liegefläche.
	var bay := VitrineView.new()
	add_child_autofree(bay)
	bay.setup(Vector3.ZERO, Vector2(10.0, 20.0))
	var edge := DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE * 2.0
	assert_almost_eq(bay.pit.hatch_sill, bay.floor_y(), 0.0001)
	assert_almost_eq(bay.pit.hatch_height, edge * VitrineView.HATCH_HEIGHT_FACTOR,
		0.0001, "und ihr Kopf misst den taumelnden Würfel, nicht die Wand")
	assert_lte(bay.pit.hatch_sill + bay.pit.hatch_height,
		-PackPitView.WALL_SINK - VitrineView.HATCH_CLEARANCE + 0.0001,
		"sie bleibt unter dem Kragen")

func test_die_tore_saeumen_nur_die_wuerfel_zone() -> void:
	# Kein Eintritt durch das Regal: die Seitenwände tragen Tore nur VOR der
	# Sperre, die vordere Wand über ihre ganze Länge, die hintere gar keines.
	var bay := VitrineView.new()
	add_child_autofree(bay)
	bay.setup(Vector3.ZERO, Vector2(10.0, 20.0))
	assert_between(bay.pit.hatch_count(), VitrineView.MIN_HATCHES,
		VitrineView.MAX_HATCHES, "bis zu acht Tore, nie weniger als zwei")
	var barrier := bay.roll_barrier_x()
	var front := bay.center.x - bay.half.x
	for i in bay.pit.hatch_count():
		var wall: int = bay.pit.hatches[i]["wall"]
		assert_ne(wall, PackPitView.WALL_X_PLUS, "die Regalwand bleibt ganz")
		var hinge: Vector3 = bay.pit.hatch_hinge(i)
		assert_almost_eq(hinge.y, bay.floor_y(), 0.0001, "jede Schwelle ist der Boden")
		if wall == PackPitView.WALL_X_MINUS:
			continue
		assert_between(hinge.x, front - 0.0001, barrier + 0.0001,
			"ein Seitentor liegt vor der Sperre")

func test_die_verteilung_misst_die_waende_und_deckelt_sich() -> void:
	# Reine Rechnung: was passt, wird verteilt - und die Bucht als GANZE hält ihren
	# Deckel ein.
	var pitch := 4.0
	var wide: Vector2i = VitrineView.hatch_share(100.0, 100.0, pitch)
	assert_eq(wide.x * 2 + wide.y, VitrineView.MAX_HATCHES,
		"eine große Bucht schöpft den Deckel aus")
	assert_gt(wide.x, 0, "und die Seitenwände kommen zuerst")
	var tiny: Vector2i = VitrineView.hatch_share(0.0, 0.0, pitch)
	assert_gte(tiny.x * 2 + tiny.y, VitrineView.MIN_HATCHES,
		"und unter zwei fällt keine Bucht")

func test_die_eintritte_werden_ohne_zuruecklegen_gezogen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var drawn: PackedInt32Array = VitrineView.draw_entries(6, 8, rng)
	assert_eq(drawn.size(), 6)
	var seen := {}
	for gate in drawn:
		assert_false(seen.has(gate), "kein Tor wird zweimal gezogen, solange welche da sind")
		seen[gate] = true
	# Ist der Topf leer, wird er neu gefüllt - niemand bleibt ohne Eintritt.
	var refilled: PackedInt32Array = VitrineView.draw_entries(5, 2, rng)
	assert_eq(refilled.size(), 5)
	for gate in refilled:
		assert_between(gate, 0, 1)

func test_eine_enge_bucht_rueckt_ihre_baender_an_die_waende() -> void:
	# Liegend ist eine Kassette länger als das Regalband einer kleinen Bucht
	# (Hinterzimmer) - dann stehen beide Bänder auf Anschlag statt ineinander.
	var narrow := VitrineView.new()
	narrow.center = Vector3.ZERO
	narrow.half = Vector2(2.5, 3.8)
	var bands: Vector2 = narrow._band_depths()
	var margin := narrow.half.x * 2.0 * VitrineView.WALL_MARGIN
	assert_lte(bands.x + VitrineView.shelf_reach(), narrow.half.x - margin + 0.0001,
		"die liegende Kassette bleibt vor der hinteren Wand")
	assert_gte(bands.y - VitrineView.bowl_reach(), -narrow.half.x + margin - 0.0001,
		"und die Schale vor der vorderen")
	assert_gte(bands.x - bands.y,
		VitrineView.shelf_reach() + VitrineView.bowl_reach() - 0.0001,
		"Regal und Schale greifen nicht ineinander")
	narrow.free()
	# Eine weite Bucht (der Laden) bleibt bei ihren Anteilen.
	var wide := VitrineView.new()
	wide.center = Vector3.ZERO
	wide.half = Vector2(9.0, 13.0)
	var roomy: Vector2 = wide._band_depths()
	assert_almost_eq(roomy.x, wide._depth_at(0.0, VitrineView.SHELF_DEPTH_SHARE), 0.0001)
	assert_almost_eq(roomy.y, wide._depth_at(VitrineView.SHELF_DEPTH_SHARE, 1.0), 0.0001)
	wide.free()

# --- Die Übergabe ans Förderwerk ----------------------------------------------

func test_die_uebergabe_hebt_erst_an_und_sinkt_dann() -> void:
	# Das Förderwerk holt die Ware erst ab, wenn sie durch die Luke ist - die
	# Fahrt danach richtet sich nach genau dieser einen Zahl.
	assert_almost_eq(VitrineView.take_out_time(),
		VitrineView.LIFT_TIME + VitrineView.SINK_TIME, 0.0001)
	assert_lt(VitrineView.LIFT_TIME, VitrineView.SINK_TIME,
		"das Anheben ist die Geste, das Absinken die Fahrt")
	assert_lt(VitrineView.take_out_time(), 0.6, "Kaufen darf nicht zäh werden")

func test_ankommen_darf_sich_setzen() -> void:
	assert_gt(DataCellView.RISE_TIME, VitrineView.SINK_TIME,
		"Aufsteigen dauert länger als Absinken - die Ankunft ist die Aussage")

func test_der_griff_unter_glas_ist_gedeckelt() -> void:
	# Über der Bucht liegt sichtbares Glas: der Hub darf es nicht durchstoßen,
	# aber er darf auch nicht auf null fallen - sonst ist es kein Griff mehr.
	assert_gt(VitrineView.GLASS_CLEAR, 0.0, "auch gegriffen bleibt ein Rest Luft")
	assert_lt(VitrineView.GLASS_CLEAR, VitrineView.HOVER_LIFT,
		"der Rest ist kleiner als der Hub selbst")
	var bay := VitrineView.new()
	bay.center = Vector3.ZERO
	bay.half = Vector2(10.0, 20.0)
	var half_die := DieBuilder.HALF_EXTENT * VitrineView.DIE_SCALE
	var crown := half_die * VitrineView.SILHOUETTE
	var room := bay._hover_room(bay.lie_y(half_die) + crown,
		crown * (VitrineView.HOVER_SWELL - 1.0))
	assert_gt(room, 0.0, "der Würfel hebt sich noch")
	assert_lte(bay.lie_y(half_die) + crown * VitrineView.HOVER_SWELL + room,
		bay.center.y - VitrineView.GLASS_CLEAR + 0.0001,
		"und bleibt dabei unter der Anzeigefläche")
	bay.free()
