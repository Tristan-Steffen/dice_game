extends SceneTree
## Sichtprobe des GRUNDRISSES (Welle 7 Teil A): zwölf Etagen mit verschiedenen Seeds als
## einzelne Bilder und als Kontaktbogen 4 × 3, dazu eine Etage groß mit einem Standraum mitten
## im Gebäude. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 600 \
##     --script tools/godot_floor_plan_probe.gd
## Bilder: E:/Generated Images/Fumble/etagen_grundriss_2026-11-27/

const OUT := "E:/Generated Images/Fumble/etagen_grundriss_2026-11-27/"
const SEEDS := [11, 23, 37, 41, 58, 64, 79, 83, 97, 105, 118, 131]
const SMALL := Vector2i(960, 680)
const BIG := Vector2i(1800, 1260)
const SHEET_CELL := Vector2i(640, 453)

var frames := 0
var ports: Array[SubViewport] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var bosses: Array[String] = []
	bosses.assign(DealClause.ids_for(DealClause.Tier.BOSS, DealClause.Kind.MALUS).slice(0, 3))
	for i in SEEDS.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = SEEDS[i]
		var plan := FloorPlan.roll(rng, Callable(), 0.3, bosses, i % 6)
		plan.scout(rng, Callable())
		_add_port(plan, SMALL)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var big := FloorPlan.roll(rng, Callable(), 0.3, bosses, 2)
	_walk_to_middle(big, rng)
	_add_port(big, BIG)

## Ein paar Züge, bis der Standraum nahe der Gebäudemitte liegt.
func _walk_to_middle(plan: FloorPlan, rng: RandomNumberGenerator) -> void:
	var middle := Vector2(FloorPlan.GRID) * 0.5
	for step in 4:
		plan.scout(rng, Callable())
		var best: Dictionary = {}
		var best_dist := 1e9
		for move in plan.reachable_moves():
			if move["room"] == plan.office:
				continue
			var rect: Rect2i = plan.rooms[move["room"]]["rect"]
			var dist := (Vector2(rect.position) + Vector2(rect.size) * 0.5).distance_to(middle) + step * rng.randf()
			if dist < best_dist and not plan.rooms[move["room"]]["visited"]:
				best_dist = dist
				best = move
		if best.is_empty():
			break
		plan.apply_move(best)
	plan.scout(rng, Callable())

func _add_port(plan: FloorPlan, port_size: Vector2i) -> void:
	var port := SubViewport.new()
	port.size = port_size
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	var view := FloorPlanView.new()
	view.size = Vector2(port_size)
	port.add_child(view)
	view.show_state(plan.view_state())
	ports.append(port)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 8:
		return false
	var sheet := Image.create(SHEET_CELL.x * 4, SHEET_CELL.y * 3, false, Image.FORMAT_RGBA8)
	for i in SEEDS.size():
		var image := ports[i].get_texture().get_image()
		image.save_png(OUT + "etage_%02d_seed%d.png" % [i + 1, SEEDS[i]])
		image.resize(SHEET_CELL.x, SHEET_CELL.y, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SHEET_CELL), Vector2i(i % 4, i / 4) * SHEET_CELL)
	sheet.save_png(OUT + "kontaktbogen.png")
	ports[SEEDS.size()].get_texture().get_image().save_png(OUT + "etage_gross_standort.png")
	print("FLOOR PLAN PROBE: ", SEEDS.size() + 1, " Bilder nach ", OUT)
	return true
