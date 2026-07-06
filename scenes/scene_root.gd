extends Node3D
## Spielablauf-Koordinator: Rundenziele, Shop, Würfelauswahl und UI-Verdrahtung.
## Wertung: KniffelScoring · Würfelphysik: DiceController · Look: PageStyle.
##
## Balatro-artiger Ablauf: pro Runde gibt es 3 Hände zum Nehmen und 5 Rerolls,
## die sich alle Hände einer Runde teilen. Jede Hand beginnt mit einem
## kostenlosen ersten Wurf; jeder weitere Wurf innerhalb der Hand kostet einen
## der gemeinsamen Rerolls. "Nehmen" verbucht die aktuell beste Hand
## (automatisch ermittelt) und schließt die Hand ab.

@export var throw_force: float = 12.0
@export var spin_strength: float = 10.0
@export var rest_linear_threshold: float = 0.05
@export var rest_angular_threshold: float = 0.05
@export var rest_time_required: float = 0.5

const MAX_HANDS := 3
const MAX_REROLLS := 5
const BASE_GOAL := 150
const GOAL_INCREMENT := 50

enum GameState { PLAYING, SHOP, SELECT_DICE, GAME_OVER }

@onready var throw_button: Button = $UI/ThrowButton
@onready var take_button: Button = $UI/TakeButton
@onready var reset_button: Button = $UI/ResetButton
@onready var debug_win_round_button: Button = $UI/DebugWinRoundButton
@onready var round_label: Label = $UI/RoundLabel
@onready var hands_label: Label = $UI/HandsLabel
@onready var rerolls_label: Label = $UI/RerollsLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var hand_label: Label = $UI/HandLabel

@onready var shop_panel: Panel = $UI/ShopPanel
@onready var shop_button_6: Button = $UI/ShopPanel/VBoxContainer/Button6
@onready var shop_button_5: Button = $UI/ShopPanel/VBoxContainer/Button5
@onready var shop_button_4: Button = $UI/ShopPanel/VBoxContainer/Button4

@onready var dice_select_panel: Panel = $UI/DiceSelectPanel
@onready var dice_toggle_list: VBoxContainer = $UI/DiceSelectPanel/VBoxContainer/DiceToggleList
@onready var start_round_button: Button = $UI/DiceSelectPanel/VBoxContainer/StartRoundButton

@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/VBoxContainer/GameOverLabel

var dice: DiceController

var is_rolling: bool = false
var has_rolled_current_hand: bool = false
var hands_left: int = MAX_HANDS
var rerolls_left: int = MAX_REROLLS
var hand_total: int = 0

var game_state: GameState = GameState.PLAYING
var owned_dice: Array[String] = []
var round_number: int = 1
var round_goal: int = BASE_GOAL
var dice_select_selected: Array[bool] = []
var dice_toggle_buttons: Array[Button] = []

func _ready() -> void:
	var roots: Array[Node3D] = [$Dice1, $Dice2, $Dice3, $Dice4, $Dice5]
	var bodies: Array[RigidBody3D] = [
		$Dice1/RigidBody3D,
		$Dice2/RigidBody3D,
		$Dice3/RigidBody3D,
		$Dice4/RigidBody3D,
		$Dice5/RigidBody3D,
	]
	var meshes: Array[MeshInstance3D] = [
		$Dice1/RigidBody3D/Die,
		$Dice2/RigidBody3D/Die,
		$Dice3/RigidBody3D/Die,
		$Dice4/RigidBody3D/Die,
		$Dice5/RigidBody3D/Die,
	]
	dice = DiceController.new(roots, bodies, meshes)

	shop_button_6.pressed.connect(_on_shop_choice.bind("fixed_6"))
	shop_button_5.pressed.connect(_on_shop_choice.bind("fixed_5"))
	shop_button_4.pressed.connect(_on_shop_choice.bind("fixed_4"))
	start_round_button.pressed.connect(_on_start_round_pressed)
	debug_win_round_button.pressed.connect(_on_debug_win_round_pressed)

	_reset_game()

func _physics_process(delta: float) -> void:
	if not is_rolling:
		return
	if dice.physics_step(delta, rest_linear_threshold, rest_angular_threshold, rest_time_required):
		_on_roll_finished()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if not _can_toggle_hold():
		return

	var index := _pick_die_index(event.position)
	if index != -1:
		dice.set_held(index, not dice.held[index])

func _can_toggle_hold() -> bool:
	return game_state == GameState.PLAYING and not is_rolling and has_rolled_current_hand and rerolls_left > 0

func _pick_die_index(screen_pos: Vector2) -> int:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return -1

	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return -1

	return dice.index_of_body(result.collider)

func _on_throw_button_pressed() -> void:
	if game_state != GameState.PLAYING or is_rolling:
		return
	if has_rolled_current_hand and rerolls_left <= 0:
		return

	if has_rolled_current_hand:
		rerolls_left -= 1

	is_rolling = true
	throw_button.disabled = true
	take_button.disabled = true
	dice.throw_unheld(throw_force, spin_strength)
	_refresh_ui()

func _on_roll_finished() -> void:
	is_rolling = false
	has_rolled_current_hand = true
	take_button.disabled = false
	throw_button.disabled = rerolls_left <= 0
	_refresh_ui()

func _on_take_button_pressed() -> void:
	if game_state != GameState.PLAYING or not has_rolled_current_hand or is_rolling:
		return

	var hand := KniffelScoring.best_hand(dice.values)
	hand_total += hand["score"]
	hands_left -= 1

	if hands_left <= 0:
		_on_round_complete()
	else:
		_start_new_hand()

func _on_reset_button_pressed() -> void:
	_reset_game()

func _reset_game() -> void:
	is_rolling = false
	game_state = GameState.PLAYING
	owned_dice = ["normal", "normal", "normal", "normal", "normal"]
	dice.set_slot_kinds(owned_dice)
	round_number = 1
	round_goal = BASE_GOAL
	shop_panel.visible = false
	dice_select_panel.visible = false
	game_over_panel.visible = false
	_set_gameplay_ui_visible(true)
	_start_new_round()

func _start_new_round() -> void:
	hands_left = MAX_HANDS
	rerolls_left = MAX_REROLLS
	hand_total = 0
	_start_new_hand()

func _start_new_hand() -> void:
	has_rolled_current_hand = false
	dice.reset()
	throw_button.disabled = false
	take_button.disabled = true
	_refresh_ui()

func _on_round_complete() -> void:
	throw_button.disabled = true
	take_button.disabled = true
	if hand_total >= round_goal:
		game_state = GameState.SHOP
		_show_shop()
	else:
		game_state = GameState.GAME_OVER
		_show_game_over(hand_total)

func _on_debug_win_round_pressed() -> void:
	if game_state != GameState.PLAYING:
		return
	is_rolling = false
	hand_total = round_goal
	throw_button.disabled = true
	take_button.disabled = true
	game_state = GameState.SHOP
	_show_shop()

func _set_gameplay_ui_visible(is_visible: bool) -> void:
	hint_label.visible = is_visible
	hand_label.visible = is_visible

func _show_shop() -> void:
	_set_gameplay_ui_visible(false)
	shop_panel.visible = true

func _on_shop_choice(kind: String) -> void:
	if game_state != GameState.SHOP:
		return
	owned_dice.append(kind)
	round_number += 1
	round_goal += GOAL_INCREMENT
	shop_panel.visible = false
	game_state = GameState.SELECT_DICE
	_show_dice_select()

func _show_dice_select() -> void:
	for child in dice_toggle_list.get_children():
		child.queue_free()
	dice_toggle_buttons.clear()
	dice_select_selected.clear()

	for i in owned_dice.size():
		dice_select_selected.append(i < 5)

	for i in owned_dice.size():
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_pressed = dice_select_selected[i]
		btn.text = _dice_kind_label(owned_dice[i])
		btn.toggled.connect(_on_dice_toggle.bind(i))
		dice_toggle_list.add_child(btn)
		dice_toggle_buttons.append(btn)

	dice_select_panel.visible = true
	_refresh_dice_select_ui()

func _dice_kind_label(kind: String) -> String:
	match kind:
		"fixed_6":
			return "Würfel (immer 6)"
		"fixed_5":
			return "Würfel (immer 5)"
		"fixed_4":
			return "Würfel (immer 4)"
		_:
			return "Normaler Würfel"

func _on_dice_toggle(is_pressed: bool, index: int) -> void:
	var selected_count := 0
	for v in dice_select_selected:
		if v:
			selected_count += 1

	if is_pressed:
		if selected_count >= 5:
			dice_toggle_buttons[index].button_pressed = false
			return
		dice_select_selected[index] = true
	else:
		dice_select_selected[index] = false

	_refresh_dice_select_ui()

func _refresh_dice_select_ui() -> void:
	var selected_count := 0
	for v in dice_select_selected:
		if v:
			selected_count += 1
	start_round_button.disabled = selected_count != 5

func _on_start_round_pressed() -> void:
	var chosen: Array[String] = []
	for i in owned_dice.size():
		if dice_select_selected[i]:
			chosen.append(owned_dice[i])
	dice.set_slot_kinds(chosen)

	dice_select_panel.visible = false
	game_state = GameState.PLAYING
	_set_gameplay_ui_visible(true)
	_start_new_round()

func _show_game_over(total: int) -> void:
	game_over_label.text = "Ziel verfehlt: %d / %d Punkte.\nSpiel vorbei – klicke 'Neues Spiel' zum Neustart." % [total, round_goal]
	_set_gameplay_ui_visible(false)
	game_over_panel.visible = true

func _refresh_ui() -> void:
	round_label.text = "Runde %d · Ziel: %d Punkte · Bisher: %d" % [round_number, round_goal, hand_total]
	hands_label.text = "Hände übrig: %d" % hands_left
	rerolls_label.text = "Rerolls übrig: %d" % rerolls_left

	if not has_rolled_current_hand:
		hand_label.text = "Würfle, um deine Hand zu sehen"
		throw_button.text = "Würfeln"
	else:
		var hand := KniffelScoring.best_hand(dice.values)
		var value_strings: Array[String] = []
		for v in dice.values:
			value_strings.append(str(v))
		hand_label.text = "%s  →  %s ×%d  =  %d Punkte" % [" ".join(value_strings), hand["label"], hand["mult"], hand["score"]]
		throw_button.text = "Neu würfeln (%d)" % rerolls_left
