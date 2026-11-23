extends SceneTree
## Sichtprobe der Kombinations-Chips mit Modul-Fächern im echten Spiel. Aufruf:
##   Godot --path . --resolution 1600x900 --position 4000,2400 --quit-after 2400 \
##     --script tools/godot_combo_bay_probe.gd
## Bilder: E:/Generated Images/Fumble/kombi_faecher_spiel_2026-11-23/

const OUT := "E:/Generated Images/Fumble/kombi_faecher_spiel_2026-11-23/"
const VIEWS := ["uebersicht", "station", "nah_oben", "nah_mitte", "nah_unten", "schraeg", "gold"]

var game: Node
var cam: Camera3D
var started := false
var filled_run := 0
var filled_ms := 0
var step := 0
var wait := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	cam = Camera3D.new()
	cam.near = 0.5
	cam.far = 2000.0
	root.add_child(cam)

func _fill() -> void:
	var run := game.get("run") as GameRun
	var chips: Dictionary = game.get("combo_chips")
	var parts: Array = ComboPart.all()
	var n := 0
	var keys: Array = chips.keys()
	# Die ersten beiden Chips bleiben leer bzw. halb leer: das Blindfach soll zu sehen sein.
	for k in keys.size():
		for slot in GameRun.SOCKETS_PER_COMBO:
			if k == 0 or (k == 1 and slot != 1) or n >= parts.size():
				continue
			var part: ComboPart = parts[n]
			n += 1
			if part.id == ComboPart.COUNTER:
				part.counter = 7
			if part.id == ComboPart.AFTERBURNER:
				part.counter = 1
			if part.id in [ComboPart.ERROR_MEMORY, ComboPart.RESONATOR]:
				part.counter = 3
			run.stash_part(part)
			if not run.install_pending_part(keys[k], slot):
				print("kein Einbau: ", keys[k], " ", slot, " wartend ", run.pending_parts.size())
	for key in keys:
		game.call("_sync_combo_sockets", key)
	print("lauf ", run.get_instance_id(), " keys ", keys)
	print("eingebaut: ", n, " chip1 ", (chips[keys[1]] as ComboChipView).socket_part(1), " log ", game.get("log_open"))

func _process(_delta: float) -> bool:
	var ms := Time.get_ticks_msec()
	if not started:
		if ms > 2500:
			started = true
			game.call("_on_title_new_game")
		return false
	if ms < 9000:
		return false
	var live := game.get("run") as GameRun
	if live != null and live.get_instance_id() != filled_run:
		filled_run = live.get_instance_id()
		filled_ms = ms
		_fill()
		return false
	if ms - filled_ms < 4000:
		return false
	wait += 1
	if wait < 8:
		return false
	wait = 0
	if step > 0:
		root.get_texture().get_image().save_png(OUT + "%d_%s.png" % [step, VIEWS[step - 1]])
		var c := (game.get("combo_chips") as Dictionary).values()[4] as ComboChipView
		print("bild ", VIEWS[step - 1], " teil ", c.socket_part(0), " pin ", c.pin_body(0), " lauf ", (game.get("run") as GameRun).get_instance_id(), " dort ", (game.get("run") as GameRun).parts_of(c.combo_key), " key ", c.combo_key)
	if step >= VIEWS.size():
		return true
	var rig := game.get("camera_rig") as CameraRig
	var chips: Dictionary = game.get("combo_chips")
	var keys: Array = chips.keys()
	match step:
		0:
			rig.current = true
		1:
			rig.zoom_to(CameraRig.Mode.COMBOS)
			wait = -90
		2, 3, 4:
			var chip := chips[keys[1 + (step - 2) * 4]] as ComboChipView
			var t := chip.global_position
			cam.fov = 30.0
			cam.look_at_from_position(t + Vector3(-6.0, 26.0, 0.0), t, Vector3(1, 0, 0))
			cam.current = true
		5:
			var chip := chips[keys[4]] as ComboChipView
			var t := chip.global_position + Vector3(0, 0.6, 2.0)
			cam.fov = 30.0
			cam.look_at_from_position(t + Vector3(-9.0, 6.0, 7.0), t, Vector3.UP)
		6:
			for k in [3, 4, 5]:
				(chips[keys[k]] as ComboChipView).set_glow(1.0)
	step += 1
	return false
