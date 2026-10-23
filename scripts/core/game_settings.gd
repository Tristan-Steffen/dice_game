class_name GameSettings
extends RefCounted
## Dauerhafte Spieleinstellungen (Lautstärken, Vollbild) samt Ablage in
## user://settings.cfg. Die Bedienoberfläche dazu wohnt im Titel-HUD (TitleView).

const PATH := "user://settings.cfg"
const SECTION := "allgemein"

## Die Bus-Namen aus default_bus_layout.tres, soweit ein Regler sie anfasst.
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

var master_volume := 0.8  # linear 0..1
var music_volume := 0.6
var sfx_volume := 0.9
var fullscreen := false

## Lädt die Einstellungen; ohne Datei kommen die Vorgaben zurück.
static func load_saved(path := PATH) -> GameSettings:
	var settings := GameSettings.new()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return settings
	settings.master_volume = _read_volume(config, "master_volume", settings.master_volume)
	settings.music_volume = _read_volume(config, "music_volume", settings.music_volume)
	settings.sfx_volume = _read_volume(config, "sfx_volume", settings.sfx_volume)
	settings.fullscreen = bool(config.get_value(SECTION, "fullscreen", settings.fullscreen))
	return settings

static func _read_volume(config: ConfigFile, key: String, fallback: float) -> float:
	return clampf(float(config.get_value(SECTION, key, fallback)), 0.0, 1.0)

func save(path := PATH) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.save(path)

## Schreibt die Werte in die Engine. Lautstärke 0 wird stummgeschaltet -
## linear_to_db(0) wäre -inf.
func apply() -> void:
	_set_bus(0, master_volume)
	_set_bus(AudioServer.get_bus_index(BUS_MUSIC), music_volume)
	_set_bus(AudioServer.get_bus_index(BUS_SFX), sfx_volume)
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	if fullscreen:
		mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(mode)

## Ein fehlender Bus (-1) wird still übergangen: ohne Layout-Datei bleibt die
## Engine beim Master, und das Spiel ist trotzdem hörbar.
func _set_bus(bus: int, linear: float) -> void:
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, linear <= 0.0)
	if linear > 0.0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(linear))
