extends SceneTree
## Sichtprobe des SCHWARZMARKTS (Runde 2: massive Fächer, Neuwurf je Fach) im echten Spiel,
## in der Haut „Graphit“: Station, Nahsicht, ein Fach mitten im Neuwurf, ein verkauftes Fach,
## Übersicht.
## Aufruf:
##   Godot --path . --fixed-fps 60 --resolution 1280x720 --position 4000,2400 --quit-after 1100 \
##     --script tools/godot_secret_shop_probe.gd
## Bilder: E:/Generated Images/Fumble/schwarzmarkt_runde2_2026-11-26/

const OUT := "E:/Generated Images/Fumble/schwarzmarkt_runde2_2026-11-26/"
const FORWARD := Vector3(0.2588, -0.9659, 0.0)
const STEP := 230

var game: Node
var cam: Camera3D
var frame := 0
var start := -1
var stations: Array[Image] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	GameRun.secret_projector_chance = 0.0
	GameRun.secret_powerbank_chance = 0.0
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	cam = Camera3D.new()
	cam.near = 0.3
	cam.far = 2000.0
	cam.fov = 40.0
	root.add_child(cam)

func _shot(name: String) -> Image:
	var image := root.get_texture().get_image()
	image.save_png(OUT + name + ".png")
	print("SHOT ", name)
	return image

func _body() -> SecretShopBody:
	return game.get("secret_body")

func _market() -> SecretShopView:
	return (game.get("table_screen") as TableScreen).secret_shop_window

func _station(distance := 30.0) -> void:
	var t := _body().global_position
	cam.look_at_from_position(t - FORWARD * distance, t, Vector3(1, 0, 0))
	cam.current = true

func _overview() -> void:
	var screen: TableScreen = game.get("table_screen")
	var t := screen.pixel_to_world(Vector2(TableScreen.RESOLUTION) * 0.5)
	cam.look_at_from_position(t - FORWARD * 118.0, t, Vector3(1, 0, 0))
	cam.current = true

func _report() -> void:
	var market := _market()
	var screen: TableScreen = game.get("table_screen")
	print("MARKET ", Rect2(market.position, market.size), " unit ", market.unit())
	for key: String in ["housing", "bay0", "nose0", "reroll0", "contacts"]:
		var r := screen.secret_part_px(key)
		print("PART ", key, " ", r, " world ", r.size / screen.pixels_per_world())
	for i in SecretShopView.BAYS:
		print("BAY ", i, " ", market.bay_state(i)["name"], " share ", _body().share(i),
			" foot ", _body().drawer_footprint(i), " back ", _body().housing_back())

## Stellt den Entwurf ein und baut den Körper neu (wie ein Laufstart: hart gestellt).
func _use_style(key: String) -> void:
	game.call("_setup_secret_body")
	game.set("_secret_hard", true)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.call("_on_title_new_game")
	if start < 0:
		var rig: CameraRig = game.get("camera_rig")
		if frame > 120 and not rig.is_animating:
			start = frame
		return frame > 1700
	var keys: Array = ["a"]
	var t := frame - start
	var index := t / STEP
	if index >= keys.size():
		return true
	var key := String(keys[index])
	var prefix := key.to_lower() + "_"
	var run: GameRun = game.get("run")
	match t % STEP:
		5:
			_use_style(key)
			run.storage_rows = 4
			run.energy = run.energy_cap()
			run.secret_stock[1] = run._secret_part_offer()
			run.secret_stock[2] = run._secret_die_offer()
			run.secret_stock_changed.emit()
			game.set("_secret_hard", true)
			_station()
		50:
			_report()
			stations.append(_shot(prefix + "1_station"))
		55:
			_station(18.0)
		75:
			_shot(prefix + "2_nah")
		80:
			_station()
			_market().reroll_offer(2)
		92:
			_shot(prefix + "3_neuwurf_unterwegs")
		140:
			_market().buy_offer(1)
			run.energy = 0
		200:
			_report()
			_shot(prefix + "4_verkauft_ohne_energie")
		205:
			_overview()
		225:
			_shot(prefix + "5_uebersicht")
	return false

func _compare() -> void:
	if stations.is_empty():
		return
	var w := 960
	var h := 540
	var sheet := Image.create(w * stations.size(), h, false, Image.FORMAT_RGBA8)
	for k in stations.size():
		var image := stations[k].duplicate() as Image
		image.convert(Image.FORMAT_RGBA8)
		image.resize(w, h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(image, Rect2i(0, 0, w, h), Vector2i(k * w, 0))
	sheet.save_png(OUT + "vergleich.png")
	print("SHOT vergleich")
