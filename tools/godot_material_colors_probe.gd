extends SceneTree
## Sichtprobe der Materialfarben: je Material ein Würfel in Dreiviertel-Ansicht, normal und
## veredelt. Mit "-- old" rendert sie die Farben vor dem 2026-11-26; ohne die neuen und
## stapelt, wenn vorhanden, die alte Tafel darüber. Aufruf (erst old, dann neu):
##   Godot --path . --resolution 640x360 --position 4000,2400 --quit-after 1500 \
##     --script tools/godot_material_colors_probe.gd [-- old]
## Bilder: E:/Generated Images/Fumble/materialfarben_2026-11-26/

const OUT := "E:/Generated Images/Fumble/materialfarben_2026-11-26/"
const TILE := 240
const IDS := ["ruby", "amber", "gold", "bone", "glass", "copper"]
## tint, surface_color, refined_color vor dem 2026-11-26.
const OLD := {
	"ruby": [Color(0.82, 0.16, 0.26), Color(0.5, 0.07, 0.14), Color(1.0, 0.08, 0.22)],
	"amber": [Color(0.88, 0.5, 0.11), Color(0.8, 0.45, 0.14), Color(1.0, 0.56, 0.0)],
	"gold": [Color(0.92, 0.74, 0.1), Color(1.0, 0.82, 0.3), Color(1.0, 0.82, 0.0)],
	"bone": [Color(0.76, 0.69, 0.5), Color(0.82, 0.76, 0.6), Color(1.0, 0.94, 0.80)],
	"glass": [Color(0.3, 0.66, 0.78), Color(0.62, 0.8, 0.86), Color(0.22, 0.80, 1.0)],
	"copper": [Color(0.86, 0.47, 0.24), Color(0.72, 0.35, 0.17), Color(0.86, 0.28, 0.14)],
}

var game: Node
var view: SubViewport
var die: Node3D
var old := false
var sheet: Image
var step := -1
var wait := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	old = OS.get_cmdline_user_args().has("old")
	if old:
		for id: String in IDS:
			var m := DieMaterial.by_id(id)
			m.tint = OLD[id][0]
			m.surface_color = OLD[id][1]
			m.refined_color = OLD[id][2]
	sheet = Image.create(TILE * IDS.size(), TILE * 2, false, Image.FORMAT_RGBA8)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game

func _setup() -> void:
	view = SubViewport.new()
	view.size = Vector2i(TILE, TILE)
	view.world_3d = root.world_3d
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	die = DieBuilder.build()
	game.add_child(die)
	die.global_position = Vector3(0, 60, 0)
	(die.get_node("RigidBody3D") as RigidBody3D).freeze = true
	var cam := Camera3D.new()
	cam.fov = 30.0
	view.add_child(cam)
	cam.global_position = die.global_position + Vector3(4.2, 5.0, 5.4)
	cam.look_at(die.global_position, Vector3.UP)
	cam.current = true

func _apply(material_id: String, level: int) -> void:
	var def := DieDefinition.standard()
	for face in 6:
		def.set_face_material(face, material_id)
		def.levels[face] = level
	(die.get_node("RigidBody3D/Faces") as DieFaceDisplay).apply_definition(def)

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() < 4000:
		return false
	if view == null:
		_setup()
		return false
	wait += 1
	if wait < 20:
		return false
	wait = 0
	if step >= 0:
		var shot := view.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(0, 0, TILE, TILE),
			Vector2i((step / 2) * TILE, (step % 2) * TILE))
	step += 1
	if step >= IDS.size() * 2:
		_finish()
		return true
	_apply(IDS[step / 2], 1 + step % 2)
	return false

func _finish() -> void:
	sheet.save_png(OUT + ("alt.png" if old else "neu.png"))
	if old or not FileAccess.file_exists(OUT + "alt.png"):
		return
	var before := Image.load_from_file(OUT + "alt.png")
	before.convert(Image.FORMAT_RGBA8)
	var both := Image.create(sheet.get_width(), sheet.get_height() * 2 + 8, false, Image.FORMAT_RGBA8)
	both.fill(Color.WHITE)
	both.blit_rect(before, Rect2i(Vector2i.ZERO, before.get_size()), Vector2i.ZERO)
	both.blit_rect(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), Vector2i(0, before.get_height() + 8))
	both.save_png(OUT + "vergleich.png")
