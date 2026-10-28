extends GutTest
## DIE VERDICHTUNG an GameRun: der ROHLING aus dem Schwarzmarkt nimmt das
## zusammengepresste Netz mehrerer gewöhnlicher Karten auf, das Futter wird
## verbraucht. Die Rechnung selbst steht in test_series_resolver; hier steht die
## BUCHUNG - was sie annimmt, was sie verweigert und was danach im Magazin liegt.

var run: GameRun

func before_each() -> void:
	run = GameRun.new_run()

func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng

## Eine Kassette mit GENAU diesem Netz - ein gewürfeltes taugt für keinen Test.
func _card(cells: Dictionary) -> Pack:
	var pack := Pack.number_pack()
	pack.stamp_net = StampNet.empty_net()
	for face: int in cells:
		pack.stamp_net[face] = cells[face]
	return run.grant_pack(pack)

func _blank() -> Pack:
	return run.grant_pack(Pack.blank_card())

func _uids(packs: Array) -> Array[int]:
	var uids: Array[int] = []
	for pack: Pack in packs:
		uids.append(pack.pack_uid)
	return uids

# --- Der ROHLING ------------------------------------------------------------------

func test_ein_frischer_rohling_ist_leer_und_groessenlos() -> void:
	var blank := Pack.blank_card()
	assert_eq(blank.display_name, Pack.BLANK_NAME)
	assert_eq(blank.blank_id, Pack.BLANK)
	assert_true(blank.is_blank_card(), "leer ist er das Ziel des Verdichtens")
	assert_false(blank.is_compressed())
	assert_false(Pack.tierable(blank), "er traegt keine Groesse")
	assert_false(blank.is_catalyst(), "und ist kein Katalysator")
	assert_false(blank.is_multiplier())

func test_ein_rohling_liegt_im_sonderbestand_auch_gefuellt() -> void:
	var blank := Pack.blank_card()
	assert_eq(Pack.shelf_of(blank), Pack.SHELF_SPECIAL, "leer im Sonderbestand")
	blank.stamp_net[0] = StampNet.compound_cell(4, 9)
	assert_eq(Pack.shelf_of(blank), Pack.SHELF_SPECIAL,
		"und gefuellt auch: ihr Inhalt stammt aus mehreren Sorten")
	assert_true(blank.is_compressed())
	assert_false(blank.is_blank_card(), "gefuellt ist er kein Ziel mehr")

# --- Die BUCHUNG ------------------------------------------------------------------

## Der Fall des Spielers: x4, +5 und +4 werden EINE Karte mit 4x+9.
func test_verdichten_schreibt_das_netz_in_den_rohling() -> void:
	var blank := _blank()
	var fuel := [_card({0: StampNet.factor_cell(4)}), _card({0: StampNet.value_cell(5)}),
		_card({0: StampNet.value_cell(4)})]
	var out := run.compress_series(_uids(fuel), blank.pack_uid, _rng(1))
	assert_false(out.is_empty(), "sie bucht")
	assert_eq(int(out["cards"]), 3, "drei Karten gingen hinein")
	assert_eq(int(out["uid"]), blank.pack_uid, "und der Rohling kam heraus")
	var cell: Dictionary = StampNet.cell_at(blank.stamp_net, 0)
	assert_eq(StampNet.compound_glyph(cell), "4x+9", "so steht es nun auf ihm")
	assert_true(blank.is_compressed(), "er ist jetzt eine verdichtete Karte")

## Das Futter wird verbraucht, der Rohling bleibt - er IST die neue Karte.
func test_verdichten_verbraucht_das_futter_und_behaelt_den_rohling() -> void:
	var blank := _blank()
	var fuel := [_card({0: StampNet.value_cell(3)}), _card({1: StampNet.value_cell(2)})]
	run.compress_series(_uids(fuel), blank.pack_uid, _rng(1))
	assert_null(run.pack_by_uid(fuel[0].pack_uid), "das Futter ist fort")
	assert_null(run.pack_by_uid(fuel[1].pack_uid))
	assert_not_null(run.pack_by_uid(blank.pack_uid), "der Rohling liegt noch da")
	assert_eq(run.owned_packs.size(), 1, "aus drei Karten wurde eine")

func test_verdichten_meldet_den_bestand() -> void:
	var blank := _blank()
	var fuel := [_card({0: StampNet.value_cell(3)})]
	var seen := []
	run.packs_changed.connect(func() -> void: seen.append(true))
	run.compress_series(_uids(fuel), blank.pack_uid, _rng(1))
	assert_eq(seen.size(), 1, "EINE Bestandsmeldung")

## Kein Wuerfel wird angefasst, also heizt das Verdichten nichts - anders als das
## Praegen, das den Zielwuerfel um eine Ladung hebt.
func test_verdichten_heizt_keinen_wuerfel() -> void:
	var blank := _blank()
	var before: Array[int] = []
	for die in run.owned_pool:
		before.append(die.charge)
	run.compress_series(_uids([_card({0: StampNet.value_cell(3)})]), blank.pack_uid, _rng(1))
	for i in run.owned_pool.size():
		assert_eq(run.owned_pool[i].charge, before[i], "kein Wuerfel wird heiss")

# --- Was sie VERWEIGERT -----------------------------------------------------------

func test_ohne_rohling_verdichtet_nichts() -> void:
	var fuel := [_card({0: StampNet.value_cell(3)})]
	assert_eq(run.compress_series(_uids(fuel), 0, _rng(1)), {}, "ohne Ziel nichts")
	assert_eq(String(run.compressible_series(_uids(fuel), 0)["blocker"]), "blank")
	assert_not_null(run.pack_by_uid(fuel[0].pack_uid), "und nichts verbraucht")

## Eine SCHON verdichtete Karte ist kein Ziel mehr - sonst waere jede Karte eines.
func test_eine_gefuellte_karte_ist_kein_rohling_mehr() -> void:
	var blank := _blank()
	run.compress_series(_uids([_card({0: StampNet.value_cell(3)})]), blank.pack_uid, _rng(1))
	var again := [_card({1: StampNet.value_cell(2)})]
	assert_eq(run.compress_series(_uids(again), blank.pack_uid, _rng(1)), {},
		"ein zweites Mal nimmt er nichts auf")

func test_ohne_futter_verdichtet_nichts() -> void:
	var blank := _blank()
	assert_eq(String(run.compressible_series([] as Array[int], blank.pack_uid)["blocker"]),
		"empty")
	assert_eq(run.compress_series([] as Array[int], blank.pack_uid, _rng(1)), {})

## Ein leer gewuerfeltes Netz ist kein Futter - es traegt nichts bei.
func test_eine_karte_ohne_netz_ist_kein_futter() -> void:
	var blank := _blank()
	var empty := _card({})
	assert_eq(String(run.compressible_series(_uids([empty]), blank.pack_uid)["blocker"]),
		"empty")

## Operatoren rechnen auf der aufgelaufenen Summe und schreiben auf FREMDE Seiten -
## auf EINER Karte wuerde die Seitennummer zur versteckten Rechenreihenfolge.
func test_ein_operator_sperrt_die_verdichtung() -> void:
	var blank := _blank()
	var fuel := [_card({0: StampNet.value_cell(3)}),
		run.grant_pack(Pack.operator_pack(StampNet.OP_MIRROR))]
	assert_eq(String(run.compressible_series(_uids(fuel), blank.pack_uid)["blocker"]),
		"operator")
	assert_eq(run.compress_series(_uids(fuel), blank.pack_uid, _rng(1)), {})
	assert_true(blank.is_blank_card(), "der Rohling bleibt unberuehrt")

## Ein Katalysator wirkt auf einen WUERFEL - hier wuerde er bloss verbraucht.
func test_ein_katalysator_sperrt_die_verdichtung() -> void:
	var blank := _blank()
	var fuel := [_card({0: StampNet.value_cell(3)}),
		run.grant_pack(Pack.catalyst(Pack.CATALYST_PROPELLANT))]
	assert_eq(String(run.compressible_series(_uids(fuel), blank.pack_uid)["blocker"]),
		"catalyst")
	assert_eq(run.compress_series(_uids(fuel), blank.pack_uid, _rng(1)), {})
	assert_not_null(run.pack_by_uid(fuel[1].pack_uid), "und er bleibt liegen")

## KEINE unendliche Karte: eine schon verdichtete Karte taugt nicht als Futter einer
## zweiten Verdichtung (Spieler-Entscheid 2026-10-26) - sonst wuechse EINE Karte ohne
## Grenze weiter. Pressen auf einen WUERFEL darf sie weiterhin.
func test_eine_verdichtete_karte_ist_kein_futter() -> void:
	var first := _blank()
	assert_false(run.compress_series(_uids([_card({0: StampNet.value_cell(3)})]),
		first.pack_uid, _rng(1)).is_empty(), "die erste Verdichtung geht")
	assert_true(first.is_compressed(), "und sie ist jetzt verdichtet")
	var second := _blank()
	var fuel := [_card({1: StampNet.value_cell(4)}), first]
	assert_eq(String(run.compressible_series(_uids(fuel), second.pack_uid)["blocker"]),
		"compressed")
	assert_eq(run.compress_series(_uids(fuel), second.pack_uid, _rng(1)), {})
	assert_true(second.is_blank_card(), "der zweite Rohling bleibt leer")

## Auch ein LEERER Rohling ist kein Futter - ein Rohling verdichtet nicht in den naechsten.
func test_ein_leerer_rohling_ist_kein_futter() -> void:
	var target := _blank()
	var fuel := [_card({0: StampNet.value_cell(3)}), _blank()]
	assert_eq(String(run.compressible_series(_uids(fuel), target.pack_uid)["blocker"]),
		"compressed")

## Der Rohling wird nie sein eigenes Futter, auch wenn er in der Reihe steckte.
func test_der_rohling_verdichtet_sich_nicht_selbst() -> void:
	var blank := _blank()
	var fuel := _card({0: StampNet.value_cell(3)})
	var both: Array[int] = [blank.pack_uid, fuel.pack_uid]
	var out := run.compress_series(both, blank.pack_uid, _rng(1))
	assert_false(out.is_empty(), "sie bucht trotzdem")
	assert_not_null(run.pack_by_uid(blank.pack_uid), "und er liegt noch da")
	assert_eq(int(StampNet.cell_at(blank.stamp_net, 0)["value"]), 3)

# --- Die VORSCHAU ist dieselbe Rechnung ------------------------------------------

func test_die_vorschau_mutiert_nichts() -> void:
	var blank := _blank()
	var fuel := [_card({0: StampNet.value_cell(3)})]
	var preview := run.compressible_series(_uids(fuel), blank.pack_uid)
	assert_eq(int(StampNet.cell_at(preview["net"], 0)["value"]), 3, "sie rechnet")
	assert_true(blank.is_blank_card(), "aber schreibt nichts")
	assert_not_null(run.pack_by_uid(fuel[0].pack_uid), "und verbraucht nichts")

func test_die_vorschau_nennt_was_verpufft() -> void:
	var blank := _blank()
	var fuel := [_card({0: StampNet.material_cell(DieMaterial.RUBY)}),
		_card({0: StampNet.material_cell(DieMaterial.GOLD)})]
	var preview := run.compressible_series(_uids(fuel), blank.pack_uid)
	assert_eq(preview["fizzled"].size(), 1, "eine Seite traegt EIN Material")
	assert_eq(String(preview["fizzled"][0]["reason"]), SeriesResolver.FIZZLE_CROWDED)

# --- Der Weg durch den SCHWARZMARKT ----------------------------------------------

## Nur dort - nie im Regal, genau wie die Reparatur-Karte.
func test_der_rohling_liegt_nie_im_regal_topf() -> void:
	assert_false(Pack.SPECIAL_ROLL_WEIGHTS.has(Pack.BLANK),
		"der Sonderposten-Wurf des Ladens kennt ihn nicht")

func test_der_sonderbestands_platz_fuehrt_den_rohling() -> void:
	var seen := false
	for i in 80:
		var fresh := GameRun.new_run()
		for offer in fresh.secret_stock:
			if offer[GameRun.OFFER_KIND] != GameRun.KIND_BLANK:
				continue
			seen = true
			var pack: Pack = offer[GameRun.OFFER_ITEM]
			assert_true(pack.is_blank_card(), "als leere Kassette")
			assert_eq(int(offer[GameRun.OFFER_PRICE]),
				GameRun.secret_energy_price(Pack.BLANK_PRICE),
				"zum Hauskurs, nicht aus einer zweiten Tabelle")
	assert_true(seen, "das Hinterzimmer fuehrt ihn wirklich")

func test_die_auslage_fuehrt_den_rohling_nie_zweimal() -> void:
	for i in 80:
		var fresh := GameRun.new_run()
		var count := 0
		for offer in fresh.secret_stock:
			if offer[GameRun.OFFER_KIND] == GameRun.KIND_BLANK:
				count += 1
		assert_lte(count, 1, "zwei gleiche Plaetze lesen sich als Fehler")

func test_der_kauf_legt_den_rohling_ins_magazin() -> void:
	var fresh := GameRun.new_run()
	fresh.secret_stock[1] = fresh._secret_blank_card()
	fresh.add_energy(9)
	assert_true(fresh.buy_secret_offer(1), "er ist bezahlbar")
	assert_eq(fresh.owned_packs.size(), 1)
	assert_true(fresh.owned_packs[0].is_blank_card(), "und liegt als Rohling da")
	assert_gt(fresh.owned_packs[0].pack_uid, 0, "mit Magazin-Identitaet")
