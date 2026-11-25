extends SceneTree
## Sichtprobe Layout E, Welle 2: Werkstatt weit (Umschalter AN, AUS, Zeiger über einem
## Vorrats-Würfel), nah, eine Würfel- und eine Karten-Öffnung samt dem Zustand danach;
## dazu alle Maße. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 5000 \
##     --script tools/godot_layout_e_probe.gd
## Bilder: E:/Generated Images/Fumble/werkstatt_layout_e/groessere_wuerfel/

const OUT := "E:/Generated Images/Fumble/werkstatt_layout_e/groessere_wuerfel/"
const VIEWS := ["weit_an", "weit_aus", "weit_vorschau", "nah", "wuerfel_oeffnung",
	"nach_wuerfel", "karten_oeffnung", "nach_karten", "nach_weit"]
const WAITS: Array[int] = [150, 60, 60, 120, 120, 700, 300, 700, 300, 150]

var game: Node
var started := false
var step := 0
var wait := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game

func _fill(workshop: WorkshopView) -> void:
	var run: GameRun = game.get("run")
	for kind: String in [Pack.TYPE_NUMBER, Pack.TYPE_MATERIAL]:
		var got := run.grant_pack(Pack.tiered(Pack.by_type(kind), Pack.TIER_NORMAL, null))
		if got != null:
			workshop.call("_on_pack_pressed", got.pack_uid)
	for kind: String in [Pack.TYPE_NUMBER, Pack.TYPE_MATERIAL, Pack.TYPE_NUMBER]:
		run.grant_pack(Pack.tiered(Pack.by_type(kind), Pack.TIER_NORMAL, null))
	workshop.choose_index(0)

## Die Schrifthöhe eines Grads (em) in Bildschirm-px, an einem Weltpunkt.
func _screen_em(at: Vector3, em_world: float) -> float:
	var game_cam := root.get_viewport().get_camera_3d()
	return game_cam.unproject_position(at).distance_to(
		game_cam.unproject_position(at + Vector3(em_world, 0.0, 0.0)))

func _info_fonts(label: String) -> void:
	var screen: TableScreen = game.get("table_screen")
	var info: WorkshopInfoView = screen.workshop_info_window
	var ppw := screen.pixels_per_world()
	var at := screen.pixel_to_world(info.get_global_rect().get_center())
	print("MASS %s info titel %d body %d geste %d display-px -> %.1f / %.1f / %.1f bildschirm-px (%s | %s)" % [
		label, info.title_font_size(), info.body_font_size(), info.action_font_size(),
		_screen_em(at, info.title_font_size() / ppw), _screen_em(at, info.body_font_size() / ppw),
		_screen_em(at, info.action_font_size() / ppw), info.title_text(),
		info.body_text().replace("\n", " / ")])

## Die Schilder des Körpers in Bildschirm-px (em).
func _plate_fonts(label: String) -> void:
	var dress: DieViewDress = game.get("die_view_dress")
	if dress == null:
		return
	var out := []
	for path: String in ["Teile/VorschauSchild", "Podestteile/Schild", "Teile/Koppler/Stellung1"]:
		var plate := dress.get_node_or_null(path) as Label3D
		if plate != null:
			out.append("%s %.1f" % [plate.text, _screen_em(plate.global_position,
				plate.pixel_size * plate.font_size)])
	print("MASS %s schilder %s" % [label, ", ".join(out)])

func _hover_pool(seat: int) -> void:
	var pool_view: Node = game.get("pool_tray_view")
	var p: Vector3 = pool_view.call("slot_global_position", seat)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_viewport().get_camera_3d().unproject_position(p)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	root.warp_mouse(motion.position)

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
	if wait < WAITS[step]:
		return false
	wait = 0
	if step > 0:
		root.get_texture().get_image().save_png(OUT + "%d_%s.png" % [step, VIEWS[step - 1]])
	if step >= VIEWS.size():
		return true
	var screen: TableScreen = game.get("table_screen")
	var workshop: WorkshopView = screen.workshop_window
	var run: GameRun = game.get("run")
	var rig := game.get("camera_rig") as CameraRig
	var pcv: PackChoiceView = game.get("pack_choice_view")
	match step:
		0:
			_fill(workshop)
			game.call("_zoom_to_mode", CameraRig.Mode.WORKSHOP)
			print("MASS pool %s" % game.get("_pool_row_px"))
			print("MASS vorschau %s praegen %s schale %s" % [workshop.preview_rect_px(),
				workshop.stamp_seat_px(), game.call("_fach_spot_px")])
			print("MASS info %s" % workshop.info_rect_px())
			print("MASS podest %s platte %s dieview %s" % [workshop.podium_rect_px(),
				workshop.podium_plate_px(), workshop._global(workshop.podium_net_rect())])
			print("MASS plus %s upgrades %s" % [workshop.sign_rects_px()[0],
				workshop._global(workshop.upgrades_net_rect())])
			print("MASS graben %s magazin %s gruben %s" % [workshop.drum_pit_rect(),
				workshop.shelf_rect_global(), workshop.shelf_pit_rect()])
			print("MASS hub-unterkante %.1f" % (screen.hub.position.y + screen.hub.size.y))
			print("MASS zone %s gleichung %s" % [game.call("_opening_area_rect"),
				workshop.equation_area_px()])
			print("MASS netz-zelle %.1f" % workshop.podium_cell())
		1:
			_hover_pool(2)
			_plate_fonts("weit")
			_info_fonts("ruhe")
			workshop.toggle_result()
		2:
			workshop.toggle_result()
			_hover_pool(2)
		3:
			_info_fonts("hover")
			print("MASS vorschau-wuerfel %s" % workshop.preview_die())
			rig.zoom_workshop_close()
		4:
			_plate_fonts("nah")
			_info_fonts("nah")
			game.call("_zoom_to_mode", CameraRig.Mode.WORKSHOP)
			run.purchase_dice_pack(DicePack.roll_shop(), 0)
		5:
			var count: int = pcv.choice.option_count() if pcv.choice != null else 3
			print("MASS oeffnung zone %s rahmen %s info sichtbar %s" % [
				game.call("_opening_area_rect"), game.call("_dice_opening_frame_px"),
				screen.workshop_info_window.visible])
			print("MASS kachel %s netz %s zelle %.1f wurfplatz %s" % [pcv.slot_rect(0, count),
				pcv.net_rect(0, count), pcv.net_cell(count), game.call("_luck_die_roll_px")])
			print("MASS kammer-loch %s wanne-loch %s" % [
				screen.pit_rect(TableScreen.PIT_CHAMBER), screen.pit_rect(TableScreen.PIT_NET_TRAY)])
			pcv.confirmed.emit([])
		6:
			print("MASS danach kammer-loch %s" % screen.pit_rect(TableScreen.PIT_CHAMBER))
			run.purchase_card_pack(CardPack.roll_shop(), 0)
		7:
			print("MASS karten rahmen %s" % game.call("_card_opening_frame_px"))
			pcv.confirmed.emit([])
		8:
			rig.zoom_to(CameraRig.Mode.OVERVIEW)
			game.call("_zoom_to_mode", CameraRig.Mode.WORKSHOP)
			_hover_pool(4)
	step += 1
	return false
