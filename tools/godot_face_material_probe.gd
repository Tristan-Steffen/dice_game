extends SceneTree
## Sichtprobe: jede Material-Seite (normal und veredelt), frontal von
## oben, ohne Ziffer - die Hintergründe des Material-Fachs der Seiten-Auskunft (FaceCardView).
## Nach einer Änderung an Material oder Veredelung neu backen, dann einmal --import. Aufruf:
##   Godot --path . --resolution 640x360 --position 4000,2400 --quit-after 1500 \
##     --script tools/godot_face_material_probe.gd
## Bilder: res://assets/textures/ui/face_cards/

const OUT := "res://assets/textures/ui/face_cards/"
const SIZE := 256

var game: Node
var view: SubViewport
var die: Node3D
var shots: Array = []
var step := -1
var wait := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for id: String in [DieMaterial.RUBY, DieMaterial.AMBER, DieMaterial.GOLD, DieMaterial.BONE,
			DieMaterial.GLASS, DieMaterial.COPPER]:
		shots.append([id, id, 1])
		shots.append([id + "_veredelt", id, 2])

func _setup() -> void:
	view = SubViewport.new()
	view.size = Vector2i(SIZE, SIZE)
	view.world_3d = root.world_3d
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	die = DieBuilder.build()
	game.add_child(die)
	die.global_position = Vector3(0, 60, 0)
	var body := die.get_node("RigidBody3D") as RigidBody3D
	body.freeze = true
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = DieBuilder.FACE_SIZE * 0.92
	view.add_child(cam)
	cam.global_position = die.global_position + Vector3.UP * 6.0
	cam.look_at(die.global_position, Vector3.FORWARD)
	cam.current = true

func _apply(material_id: String, level: int) -> void:
	var def := DieDefinition.standard()
	for face in 6:
		def.faces[face] = 5
		if material_id != "":
			def.set_face_material(face, material_id)
			def.levels[face] = level
	var display := die.get_node("RigidBody3D/Faces") as DieFaceDisplay
	display.apply_definition(def)
	for label in die.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false

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
		var path := ProjectSettings.globalize_path(OUT) + "%s.png" % shots[step][0]
		view.get_texture().get_image().save_png(path)
	step += 1
	if step >= shots.size():
		return true
	_apply(shots[step][1], shots[step][2])
	return false
