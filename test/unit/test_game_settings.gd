extends GutTest
## Tests der dauerhaften Spieleinstellungen (GameSettings): Vorgaben, Ablage in
## einer ConfigFile und Klemmen kaputter Werte. apply() bleibt hier außen vor -
## es fasst Audio-Bus und Fenstermodus an, das gehört nicht in einen Test.

const TEST_PATH := "user://test_game_settings.cfg"

func after_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)

func test_defaults_are_audible_and_windowed() -> void:
	var settings := GameSettings.new()
	assert_gt(settings.master_volume, 0.0, "frisch installiert hört man etwas")
	assert_false(settings.fullscreen)

func test_missing_file_yields_the_defaults() -> void:
	var settings := GameSettings.load_saved(TEST_PATH)
	assert_eq(settings.master_volume, GameSettings.new().master_volume)
	assert_false(settings.fullscreen)

func test_saved_values_come_back() -> void:
	var settings := GameSettings.new()
	settings.master_volume = 0.35
	settings.fullscreen = true
	settings.save(TEST_PATH)
	var loaded := GameSettings.load_saved(TEST_PATH)
	assert_almost_eq(loaded.master_volume, 0.35, 0.0001)
	assert_true(loaded.fullscreen)

func test_a_broken_volume_gets_clamped() -> void:
	var config := ConfigFile.new()
	config.set_value(GameSettings.SECTION, "master_volume", 4.2)
	config.save(TEST_PATH)
	assert_eq(GameSettings.load_saved(TEST_PATH).master_volume, 1.0)
