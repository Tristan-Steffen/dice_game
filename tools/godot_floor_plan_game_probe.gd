extends SceneTree
## Sichtprobe des GRUNDRISSES im echten Spiel (Welle 7 Teil C): Runde 1 an der Gruben-Station
## (Nahsicht im engen Rahmen, Maßstab und Schriftgrade), die Hub-Startseite auf Etage 3 (Streifen,
## Zellgröße) und die Laden-Seite „Etage“ samt „Zurück zum Laden“. Aufruf:
##   Godot --path . --fixed-fps 60 --resolution 1280x720 --position 4000,2400 --quit-after 1500 \
##     --script tools/godot_floor_plan_game_probe.gd
## Bilder: E:/Generated Images/Fumble/etagen_grundriss_feinschliff_2026-11-27/

const OUT := "E:/Generated Images/Fumble/etagen_grundriss_feinschliff_2026-11-27/"

var game: Node
var frame := 0
var start := -1

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game

func _rig() -> CameraRig:
	return game.get("camera_rig")

func _screen() -> TableScreen:
	return game.get("table_screen")

func _shot(file: String) -> void:
	root.get_texture().get_image().save_png(OUT + file + ".png")
	print("SHOT ", file)

## Bildschirm-px je Display-px über einem Display-Rechteck (waagerecht gemessen).
func _scale(rect: Rect2) -> float:
	var camera := root.get_viewport().get_camera_3d()
	var a := camera.unproject_position(_screen().pixel_to_world(rect.position))
	var b := camera.unproject_position(_screen().pixel_to_world(rect.position + Vector2(rect.size.x, 0.0)))
	# Das Projekt streckt 1280 × 900 aufs Fenster: in echte Fensterpixel umrechnen.
	return absf(b.x - a.x) * root.get_final_transform().get_scale().x / rect.size.x

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

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.call("_on_title_new_game")
	if start < 0:
		if frame > 120 and not _rig().is_animating:
			start = frame
		return frame > 1450
	var t := frame - start
	var run: GameRun = game.get("run")
	var detail: FloorPlanView = game.get("floor_detail")
	match t:
		10:
			_rig().zoom_to(CameraRig.Mode.PIT)
		200:
			var scale := _scale(Rect2(detail.position, detail.size))
			print("NAHSICHT offen %s, Größe %s, Zelle %.1f, MASSSTAB %.3f Bildschirm-px je Display-px" % [detail.visible,
				detail.size, detail.zoom_cell(), scale])
			for role in ["name", "bonus_name", "bonus_text", "price"]:
				var px := detail.label_px(role)
				print("  %s %d Display-px = %.1f Bildschirm-px" % [role, px, px * scale])
			print("  Kopf %d, Auskunft %d/%d Display-px" % [int(detail.unit() * FloorPlanView.HEAD_FONT),
				int(detail.unit() * FloorPlanView.INFO_TITLE_FONT), int(detail.unit() * FloorPlanView.INFO_BODY.x)])
			_shot("4_spiel_grube_runde1")
		210:
			detail.move_chosen.emit(detail.walkable_moves()[0])
		260:
			# Zwei Etagen im Zeitraffer, dann drei Züge auf Etage 3.
			for i in 2:
				_walk_floor(run)
			for i in 3:
				var moves := run.walkable_moves()
				var pick: Dictionary = moves[0]
				for move in moves:
					if move["room"] != run.floor_plan.office:
						pick = move
				run.move_to(pick)
				run.round_points = 400 + i * 50
				run.advance_round()
			game.call("_refresh_hub_info")
			_rig().zoom_to(CameraRig.Mode.HUB)
		480:
			var hub: HubView = _screen().hub
			var strip := hub.floor_plan
			var rect := Rect2(strip.get_global_rect().position, strip.size)
			var scale := _scale(Rect2(hub.position, hub.size))
			print("HUB Etage %d, Streifen %s Display-px, Zelle der laufenden Etage %.1f Display-px = %.1f Bildschirm-px (%.3f je Display-px)"
				% [run.floor_index + 1, rect.size, strip.geometry().cell, strip.geometry().cell * scale, scale])
			_shot("5_hub_startseite_etage3")
			game.set("shop_reopen_allowed", true)
			game.call("_on_shop_reopen_requested")
		640:
			var shop: ShopController = game.get("charm_shop")
			print("LADEN offen %s" % shop.visible)
			shop.floor_button.pressed.emit()
		760:
			var page: FloorMapPage = game.get("floor_page")
			var hub_rect := Rect2(_screen().hub.position, _screen().hub.size)
			var map_rect := Rect2(page.map_view.get_global_rect().position, page.map_view.size)
			var inside := hub_rect.grow(1.0).encloses(map_rect)
			print("%s  Laden-Seite Etage: sichtbar %s, Plan %s im Hub %s, Grundriß steht %s" % [
				"PASS" if page.visible and inside and page.map_view.geometry() != null else "FAIL", page.visible,
				map_rect, inside, page.map_view.geometry() != null])
			_shot("6_laden_seite_etage")
			page.back_button.pressed.emit()
		900:
			var page: FloorMapPage = game.get("floor_page")
			var shop: ShopController = game.get("charm_shop")
			print("%s  Zurück zum Laden: Etagen-Seite %s, Laden %s" % ["PASS" if not page.visible and shop.visible
				else "FAIL", page.visible, shop.visible])
			return true
	return false
