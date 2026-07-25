class_name GameSettings
extends RefCounted
## Dauerhafte Spieleinstellungen (Lautstärke, Vollbild) samt Ablage in
## user://settings.cfg. Die Bedienoberfläche dazu wohnt im Titel-HUD (TitleView).

const PATH := "user://settings.cfg"
const SECTION := "allgemein"

var master_volume := 0.8  # linear 0..1
var fullscreen := false

## Lädt die Einstellungen; ohne Datei kommen die Vorgaben zurück.
static func load_saved(path := PATH) -> GameSettings:
	var settings := GameSettings.new()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return settings
	var volume: float = config.get_value(SECTION, "master_volume", settings.master_volume)
	settings.master_volume = clampf(volume, 0.0, 1.0)
	settings.fullscreen = bool(config.get_value(SECTION, "fullscreen", settings.fullscreen))
	return settings

func save(path := PATH) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.save(path)

## Schreibt die Werte in die Engine. Lautstärke 0 wird stummgeschaltet -
## linear_to_db(0) wäre -inf.
func apply() -> void:
	AudioServer.set_bus_mute(0, master_volume <= 0.0)
	if master_volume > 0.0:
		AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	if fullscreen:
		mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(mode)
