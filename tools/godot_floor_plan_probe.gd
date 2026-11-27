extends SceneTree
## Sichtprobe des GRUNDRISSES (Welle 7 Teil B) ohne Spiel: die Nahsicht im Maß des
## Grubenbodens (985 × 484 Display-px, gerendert mit 1,45 Bildschirm-px je Display-px wie im
## engen Gruben-Rahmen) am Etagen-Beginn, mitten in der Etage samt Zeiger, ganz herausgezoomt,
## und die Hub-Startseite mit dem Streifen (Etage 3, zwei geschaffte darunter). Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 600 \
##     --script tools/godot_floor_plan_probe.gd
## Bilder: E:/Generated Images/Fumble/etagen_grundriss_spiel_2026-11-27/

const OUT := "E:/Generated Images/Fumble/etagen_grundriss_spiel_2026-11-27/"
const PIT := Vector2i(985, 484)
## Bildschirm-px je Display-px im engen Rahmen der Gruben-Station (gemessen Welle 6).
const SCREEN_SCALE := 1.45
const HUB := Vector2i(1068, 1125)

var frames := 0
var ports: Array[SubViewport] = []
var names: Array[String] = []
var views: Array[FloorPlanView] = []
var hub: HubView

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	seed(20261127)
	var start := GameRun.new_run()
	_detail(start.floor_view_state(), "1_nahsicht_aufzug", false)
	var mid := _walked_run()
	var mid_view := _detail(mid.floor_view_state(), "2_nahsicht_mitte", true)
	var whole := _detail(mid.floor_view_state(), "3_nahsicht_ganz", false)
	whole.set_meta("whole", true)
	var tower := GameRun.new_run()
	for i in 2:
		_walk_floor(tower)
	_walk_some(tower, 3)
	_hub(tower)
	mid_view.set_meta("hover", true)

## Ein Lauf mitten in seiner Etage: Schlüsselkarte geholt, mindestens eine Brandschutztür
## durchquert, Rundenschnitt vorhanden, ein Zug fällig.
func _walked_run() -> GameRun:
	for attempt in 30:
		var run := GameRun.new_run()
		run.round_scores.assign([260, 330, 410])
		var crossed := false
		for step in 8:
			var plan := run.floor_plan
			if plan.key_taken and crossed:
				break
			var goal := plan.key_room if not plan.key_taken else ""
			var best: Dictionary = {}
			for move in run.walkable_moves():
				if move["room"] == plan.office:
					continue
				if goal != "" and plan.shortest_moves(String(move["room"]), goal, false) \
						< (999 if best.is_empty() else plan.shortest_moves(String(best["room"]), goal, false)):
					best = move
				elif goal == "" and String(move["fire_door"]) != "":
					best = move
			if best.is_empty():
				best = run.walkable_moves()[0]
			crossed = crossed or String(best["fire_door"]) != ""
			run.move_to(best)
			run.round_points = 300 + step * 60
			run.advance_round()
		if run.floor_plan.key_taken and crossed:
			return run
	return GameRun.new_run()

func _walk_some(run: GameRun, count: int) -> void:
	for i in count:
		var moves := run.walkable_moves()
		var pick: Dictionary = moves[0]
		for move in moves:
			if move["room"] != run.floor_plan.office:
				pick = move
		run.move_to(pick)
		run.round_points = 400 + i * 50
		run.advance_round()

## Läuft eine Etage über die Schlüsselkarte ins Büro und fährt mit dem Aufzug hoch.
func _walk_floor(run: GameRun) -> void:
	for guard in 40:
		var plan := run.floor_plan
		var goal := plan.office if plan.key_taken else plan.key_room
		var best: Dictionary = {}
		var best_steps := 999
		for move in run.walkable_moves():
			var steps := plan.shortest_moves(String(move["room"]), goal, plan.key_taken)
			if steps >= 0 and steps < best_steps:
				best_steps = steps
				best = move
		run.move_to(best)
		run.round_points = 300 + guard * 40
		var boss := run.is_boss_round()
		if boss:
			run.settle_block_deals()
		run.advance_round()
		if boss:
			return

func _port(port_size: Vector2i, logical: Vector2i) -> SubViewport:
	var port := SubViewport.new()
	port.size = port_size
	port.size_2d_override = logical
	port.size_2d_override_stretch = true
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	return port

func _detail(state: Dictionary, file: String, _hover: bool) -> FloorPlanView:
	var port := _port(Vector2i(Vector2(PIT) * SCREEN_SCALE), PIT)
	var view := FloorPlanView.new()
	view.mode = FloorPlanView.Mode.DETAIL
	view.size = Vector2(PIT)
	port.add_child(view)
	view.open(state)
	ports.append(port)
	names.append(file)
	views.append(view)
	return view

func _hub(run: GameRun) -> void:
	var port := _port(HUB, HUB)
	hub = HubView.new()
	hub.size = Vector2(HUB)
	port.add_child(hub)
	hub.layout()
	hub.set_floor_state(run.floor_view_state())
	hub.set_floor_moves_enabled(true)
	ports.append(port)
	names.append("5_hub_streifen")
	views.append(null)

func _report(view: FloorPlanView, file: String) -> void:
	print("%s: Zelle %.1f px (ganz %.1f), u %.2f, Text voll %s" % [file, view.zoom_cell(), view.whole_cell(),
		view.unit(), view.full_text()])
	for role in ["name", "bonus_name", "bonus_text", "move"]:
		var px := view.label_px(role)
		print("  %s %d Display-px = %.1f Bildschirm-px" % [role, px, px * SCREEN_SCALE])
	print("  Kopf %d, Auskunft %d/%d, Tür %d Display-px" % [int(view.unit() * FloorPlanView.HEAD_FONT),
		int(view.unit() * FloorPlanView.INFO_TITLE_FONT), int(view.unit() * FloorPlanView.INFO_BODY.x),
		int(view.unit() * FloorPlanView.DOOR_FONT.x)])

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		for view in views:
			if view == null:
				continue
			if view.has_meta("whole"):
				view.zoom_at(view.map_rect().get_center(), -50.0)
			if view.has_meta("hover"):
				var move: Dictionary = view.walkable_moves()[0]
				for option in view.walkable_moves():
					if view.map_rect().has_point(view.geometry().room_rect(String(option["room"])).get_center()):
						move = option
				var rect := view.geometry().room_rect(String(move["room"]))
				view.hover_at(rect.position + rect.size * Vector2(0.5, 0.6))
	if frames < 10:
		return false
	for i in ports.size():
		ports[i].get_texture().get_image().save_png(OUT + names[i] + ".png")
		if views[i] != null:
			_report(views[i], names[i])
	if hub != null:
		print("HUB Streifen ", hub.floor_plan.size, " Info: ", hub.info_text().replace("\n", " | "))
	print("FLOOR PLAN PROBE: ", ports.size(), " Bilder nach ", OUT)
	return true
