extends SceneTree
## Sichtprobe des LABORS (LaborBody) für sich: alle vier Stationen in den drei Zuständen
## bereit / läuft / fertig, je mit echtem Einsatz in der Kammer, dazu ein Bogen aller Bilder.
## Aufruf:
##   Godot --path . --fixed-fps 60 --resolution 1280x720 --position 4000,2400 --quit-after 900 \
##     --script tools/godot_labor_probe.gd
## Bilder: E:/Generated Images/Fumble/labor_spiel_2026-11-26/

const OUT := "E:/Generated Images/Fumble/labor_spiel_2026-11-26/"
const FORWARD := Vector3(0.2588, -0.9659, 0.0)
const STEP := 40
const PHASES := [["bereit", 0, 0], ["laeuft", 2, 3], ["fertig", 6, 0]]

var view: LaborView
var body: LaborBody
var cam: Camera3D
var run: GameRun
var frame := 0
var shots: Array[Image] = []
var jobs: Array = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	run = GameRun.new_run()
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.035, 0.03)
	env.environment.glow_enabled = true
	env.environment.glow_hdr_threshold = 0.95
	world.add_child(env)
	var deck := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	deck.mesh = plane
	deck.position.y = -0.01
	deck.material_override = StationParts.lit(Color(0.03, 0.07, 0.05))
	world.add_child(deck)
	view = LaborView.new()
	root.add_child(view)
	view.size = LaborView.UNITS * 37.5
	view.visible = false
	body = LaborBody.new()
	world.add_child(body)
	var parts := {}
	for key: String in LaborView.PARTS:
		var rect := view.part_rect(key)
		parts[key] = Rect2((rect.position - view.size * 0.5) / 37.5, rect.size / 37.5)
	body.setup(parts)
	cam = Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.look_at_from_position(-FORWARD * 25.0, Vector3.ZERO, Vector3(1, 0, 0))
	cam.current = true
	for station: String in LaborView.STATIONS:
		for phase: Array in PHASES:
			jobs.append([station, phase])

func _items(station: String) -> Array:
	match station:
		"seele":
			return [{"kind": GameRun.KIND_DIE, "item": run._secret_die_offer()[GameRun.OFFER_ITEM]},
				{"kind": GameRun.KIND_DIE, "item": run.owned_pool[0]}]
		"charm":
			return [{"kind": GameRun.KIND_CHARM, "item": run._secret_charm_offer()[GameRun.OFFER_ITEM]}]
		"modul":
			return [{"kind": GameRun.KIND_PART, "item": run._secret_part_offer()[GameRun.OFFER_ITEM]}]
	var cards: Array = []
	for k in 6:
		cards.append({"kind": GameRun.KIND_ENGRAVING, "item": run._secret_engraving_offer()[GameRun.OFFER_ITEM]})
	return cards

func _process(_delta: float) -> bool:
	frame += 1
	var index := frame / STEP
	if index >= jobs.size():
		if frame == jobs.size() * STEP + 1:
			_sheet()
		return frame > jobs.size() * STEP + 3
	var job: Array = jobs[index]
	var station := String(job[0])
	var phase: Array = job[1]
	match frame % STEP:
		1:
			var state := {"open": true, "station": station, "phase": phase[0], "die_value": phase[1],
				"rounds_left": phase[2], "price": index % 3, "affordable": true, "collectable": true}
			if phase[0] == "bereit" and station == "karten":
				state["staged"] = 6
				state["staged_max"] = 6
			view.set_state(state)
			body.seat(view.body_state(), true)
			body.set_items(_items(station) if phase[0] != "bereit" or station == "karten" else [])
			body.set_hovered("start" if phase[0] == "bereit" else "")
		35:
			var image := root.get_texture().get_image()
			var name := "%s_%s" % [station, String(phase[0])]
			image.save_png(OUT + name + ".png")
			print("SHOT ", name)
			shots.append(image)
	return false

func _sheet() -> void:
	var w := 640
	var h := 360
	var sheet := Image.create(w * 3, h * 4, false, Image.FORMAT_RGBA8)
	for k in shots.size():
		var image := shots[k].duplicate() as Image
		image.convert(Image.FORMAT_RGBA8)
		image.resize(w, h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(image, Rect2i(0, 0, w, h), Vector2i((k % 3) * w, (k / 3) * h))
	sheet.save_png(OUT + "bogen.png")
	print("SHOT bogen")
