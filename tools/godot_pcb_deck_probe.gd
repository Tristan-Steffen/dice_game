extends SceneTree
## Sichtprobe des Platinen-Decks: geroutetes Deck, Adern als Bündel, Datenfluss der Kometen.
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 3600 \
##     --script tools/godot_pcb_deck_probe.gd
## Bilder: E:/Generated Images/Fumble/platinen_deck_spiel/

const OUT := "E:/Generated Images/Fumble/platinen_deck_spiel/"
const MODES := [CameraRig.Mode.OVERVIEW, CameraRig.Mode.PIT, CameraRig.Mode.COMBOS,
	CameraRig.Mode.HUB, CameraRig.Mode.WORKSHOP]
const MODE_NAMES := ["uebersicht", "grube", "kombis", "hub", "werkstatt"]

var game: Node
var started := false
var step := -1
var wait := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game

func _fire() -> void:
	var screen: TableScreen = game.get("table_screen")
	screen.money_comet(true, TableScreen.SIDE_MONEY_COLOR)
	screen.bank_comet(Color(0.4, 1.0, 0.7))
	screen.call("_pulse_wiring_to_chip", DiceScoring.HAND_PRIORITY[4], TableScreen.LINK_PULSE_COLOR)
	screen.score_comet(screen.pit_window.position + screen.pit_window.size * 0.5, "pit", "base")

## Je Station: Ruhebild, dann Kometen feuern und zwei Bilder im Flug.
func _process(_delta: float) -> bool:
	var ms := Time.get_ticks_msec()
	if not started:
		if ms > 2500:
			started = true
			game.call("_on_title_new_game")
		return false
	if ms < 12000:
		return false
	wait += 1
	if step < 0:
		print("Bündel: ", (game.get("table_screen") as TableScreen).deck_view().bundle_count())
		step = 0
		wait = 0
		game.call("_zoom_to_mode", MODES[0])
		return false
	var mode := step / 3
	var shot := step % 3
	var due: int = [110, 4, 5][shot]
	if wait < due:
		return false
	root.get_texture().get_image().save_png(OUT + "%s_%d.png" % [MODE_NAMES[mode], shot])
	if shot == 0:
		_fire()
	step += 1
	wait = 0
	if step >= MODES.size() * 3:
		return true
	if step % 3 == 0:
		game.call("_zoom_to_mode", MODES[step / 3])
	return false
