extends SceneTree
## Sichtprobe des Platinen-Decks samt ROM-Karte der Kombinationen.
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 3600 \
##     --script tools/godot_pcb_deck_probe.gd
## Bilder: E:/Generated Images/Fumble/platinen_deck_spiel/

const OUT := "E:/Generated Images/Fumble/platinen_deck_spiel/"
const MODES := [CameraRig.Mode.COMBOS, CameraRig.Mode.PIT, CameraRig.Mode.OVERVIEW]
const MODE_NAMES := ["kombis", "grube", "uebersicht"]

var game: Node
var started := false
var step := -1
var wait := 0
var top: Camera3D
var tag := ""

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# FUMBLE_TAG benennt die Bilder.
	tag = OS.get_environment("FUMBLE_TAG")
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	top = Camera3D.new()
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.near = 0.5
	top.far = 400.0
	root.add_child(top)

## Je Station ein Bild, zuletzt die Karte von oben - ruhig und mit Kometen im Flug.
func _process(_delta: float) -> bool:
	var ms := Time.get_ticks_msec()
	if not started:
		if ms > 2500:
			started = true
			game.call("_on_title_new_game")
		return false
	if ms < 13000:
		return false
	var screen: TableScreen = game.get("table_screen")
	wait += 1
	if step < 0:
		step = 0
		wait = 0
		game.call("_zoom_to_mode", MODES[0])
		return false
	if step < MODES.size():
		if wait < 110:
			return false
		root.get_texture().get_image().save_png(OUT + "karte_%s.png" % MODE_NAMES[step])
		step += 1
		wait = 0
		if step < MODES.size():
			game.call("_zoom_to_mode", MODES[step])
		return false
	if wait == 1:
		var rect := screen.cluster_rect.grow(90.0)
		var at := screen.pixel_to_world(rect.get_center())
		top.size = rect.size.x / screen.pixels_per_world() * 0.62
		top.look_at_from_position(at + Vector3(0, 60, 0), at, Vector3(1, 0, 0))
		top.current = true
	if wait == 14:
		root.get_texture().get_image().save_png(OUT + "karte_draufsicht%s.png" % tag)
		screen.call("_pulse_wiring_to_chip", DiceScoring.HAND_PRIORITY[4], TableScreen.LINK_PULSE_COLOR)
		screen.score_comet(screen.cluster_rect.get_center(), "combos", "base")
	if wait == 19:
		root.get_texture().get_image().save_png(OUT + "karte_draufsicht_komet.png")
		return true
	return false
