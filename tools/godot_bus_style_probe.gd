extends SceneTree
## Sichtprobe des BUSSES samt Rundbogen-Knoten im Spiel: Karte, Kreuz, Wertung, Projektor-Bus.
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 3600 \
##     --script tools/godot_bus_style_probe.gd
## Bilder: E:/Generated Images/Fumble/bus_rundbogen_2026-11-24/

const OUT := "E:/Generated Images/Fumble/bus_rundbogen_2026-11-24/"
const VIEWS := ["karte", "kreuz", "wertung", "projektor"]

var game: Node
var top: Camera3D
var started := false
var view := 0
var wait := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	top = Camera3D.new()
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.near = 0.5
	top.far = 400.0
	root.add_child(top)

func _aim(rect: Rect2) -> void:
	var screen: TableScreen = game.get("table_screen")
	var at := screen.pixel_to_world(rect.get_center())
	top.size = rect.size.x / screen.pixels_per_world() * 0.62
	top.look_at_from_position(at + Vector3(0, 60, 0), at, Vector3(1, 0, 0))
	top.current = true

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
	if wait == 1:
		var card := screen.cluster_rect
		var buses := screen.combo_bus_xs()
		var cross := Vector2(buses[buses.size() - 1], screen.combo_rail_ys().y)
		match view:
			0:
				_aim(card.grow(90.0))
			1:
				_aim(Rect2(cross - Vector2(170, 95), Vector2(340, 190)))
			2:
				_aim(Rect2(card.position.x, screen.score_rect.position.y - 520.0, card.size.x * 2.6, 900.0))
			_:
				var mid := screen.score_rect.get_center().x
				_aim(Rect2(mid - 420.0, screen.score_rect.position.y - 330.0, 840.0, 470.0))
	if wait == 30:
		root.get_texture().get_image().save_png(OUT + "%s.png" % VIEWS[view])
		wait = 0
		view += 1
		if view >= VIEWS.size():
			return true
	return false
