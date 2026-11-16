extends GutTest
## Tests der Platzhalter-Klangbank: jeder Platz trägt einen Stream, die Namen folgen
## kategorie_ereignis, und die Klang-Tafel findet jeden Platz im Quelltext.

const SOURCE := "res://scripts/table/sfx_bank.gd"

var bank: SfxBank

func before_all() -> void:
	bank = SfxBank.new()
	add_child(bank)

func after_all() -> void:
	bank.free()

func test_every_slot_has_a_stream() -> void:
	assert_gt(bank.names().size(), 40, "die Bank ist zu klein")
	for sfx: StringName in bank.names():
		var stream := bank.stream_of(sfx)
		assert_not_null(stream, "%s hat keinen Stream" % sfx)
		if stream is AudioStreamWAV:
			assert_gt((stream as AudioStreamWAV).data.size(), 0, "%s ist leer" % sfx)

func test_names_follow_category_event() -> void:
	var pattern := RegEx.create_from_string(SfxBank.NAME_PATTERN)
	for sfx: StringName in bank.names():
		assert_not_null(pattern.search(String(sfx)), "%s ist kein kategorie_ereignis" % sfx)

## Die Klang-Tafel liest wörtliche _load_or(&"…"-Aufrufe und EINE SFX_DIR-Konstante.
func test_every_slot_is_a_literal_load_call() -> void:
	var text := FileAccess.get_file_as_string(SOURCE)
	assert_eq(text.count("const SFX_DIR := \"res://assets/sfx/game/\""), 1)
	var found := {}
	for m in RegEx.create_from_string("_load_or\\(&\"([a-z_]+)\"").search_all(text):
		found[StringName(m.get_string(1))] = true
	for sfx: StringName in bank.names():
		assert_true(found.has(sfx), "%s steht nicht wörtlich im Quelltext" % sfx)
	assert_eq(found.size(), bank.names().size(), "Quelltext und Bank zählen verschieden")

func test_ui_slots_route_to_ui_bus() -> void:
	assert_eq(SfxBank.bus_of(&"ui_click"), SfxBank.BUS_UI)
	assert_eq(SfxBank.bus_of(&"shop_buy"), SfxBank.BUS_SFX)

func test_unknown_name_is_silent() -> void:
	bank.play(&"gibt_es_nicht")
	assert_false(bank._last_ms.has(&"gibt_es_nicht"))

func test_min_gap_swallows_repeats() -> void:
	bank._last_ms.erase(&"chip_in")
	assert_true(bank._gap_ok(&"chip_in"))
	assert_false(bank._gap_ok(&"chip_in"), "Wiederholung innerhalb der Mindestpause")
	assert_true(bank._gap_ok(&"shop_buy"))
	assert_true(bank._gap_ok(&"shop_buy"), "ohne Mindestpause klingt jede Wiederholung")

func test_silent_button_gets_no_connection() -> void:
	var loud := Button.new()
	var quiet := Button.new()
	quiet.set_meta(SfxBank.SILENT_META, true)
	add_child_autofree(loud)
	add_child_autofree(quiet)
	await wait_frames(1)
	assert_gt(loud.pressed.get_connections().size(), 0, "normaler Knopf klickt nicht")
	assert_eq(quiet.pressed.get_connections().size(), 0, "sfx_silent bekam eine Verbindung")
	assert_eq(quiet.mouse_entered.get_connections().size(), 0)
