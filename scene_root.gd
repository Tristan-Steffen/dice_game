extends Node3D

@export var throw_force: float = 12.0
@export var spin_strength: float = 10.0
@export var rest_linear_threshold: float = 0.05
@export var rest_angular_threshold: float = 0.05
@export var rest_time_required: float = 0.5

const DICE_COUNT := 5
const MAX_ROLLS := 3
const BASE_GOAL := 150
const GOAL_INCREMENT := 50

# Lokale Achsen des Würfelmodells (feste Richtungen in RigidBody3D-Lokalraum).
const AXIS_DIRECTIONS := {
	"OBEN": Vector3.UP,
	"UNTEN": Vector3.DOWN,
	"RECHTS": Vector3.RIGHT,
	"LINKS": Vector3.LEFT,
	"VORNE": Vector3(0, 0, 1),
	"HINTEN": Vector3(0, 0, -1),
}

# Kalibrierung: welche Augenzahl liegt physisch auf welcher Achse.
const AXIS_VALUES := {
	"OBEN": 4,
	"UNTEN": 3,
	"RECHTS": 5,
	"LINKS": 2,
	"VORNE": 1,
	"HINTEN": 6,
}

const CATEGORIES := [
	{"key": "ones", "label": "Einser"},
	{"key": "twos", "label": "Zweier"},
	{"key": "threes", "label": "Dreier"},
	{"key": "fours", "label": "Vierer"},
	{"key": "fives", "label": "Fünfer"},
	{"key": "sixes", "label": "Sechser"},
	{"key": "three_kind", "label": "Dreierpasch"},
	{"key": "four_kind", "label": "Viererpasch"},
	{"key": "full_house", "label": "Full House"},
	{"key": "small_straight", "label": "Kleine Straße"},
	{"key": "large_straight", "label": "Große Straße"},
	{"key": "yahtzee", "label": "Kniffel"},
	{"key": "chance", "label": "Chance"},
]
const UPPER_KEYS := ["ones", "twos", "threes", "fours", "fives", "sixes"]
const UPPER_BONUS_THRESHOLD := 63
const UPPER_BONUS_VALUE := 35

enum GameState { PLAYING, SHOP, SELECT_DICE, GAME_OVER }

@onready var dice_roots: Array[Node3D] = [$Dice1, $Dice2, $Dice3, $Dice4, $Dice5]
@onready var dice_bodies: Array[RigidBody3D] = [
	$Dice1/RigidBody3D,
	$Dice2/RigidBody3D,
	$Dice3/RigidBody3D,
	$Dice4/RigidBody3D,
	$Dice5/RigidBody3D,
]
@onready var dice_meshes: Array[MeshInstance3D] = [
	$Dice1/RigidBody3D/Die,
	$Dice2/RigidBody3D/Die,
	$Dice3/RigidBody3D/Die,
	$Dice4/RigidBody3D/Die,
	$Dice5/RigidBody3D/Die,
]

@onready var throw_button: Button = $UI/ThrowButton
@onready var reset_button: Button = $UI/ResetButton
@onready var debug_win_round_button: Button = $UI/DebugWinRoundButton
@onready var round_label: Label = $UI/RoundLabel
@onready var rolls_label: Label = $UI/RollsLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var scorecard: VBoxContainer = $UI/ScoreCard

@onready var shop_panel: Panel = $UI/ShopPanel
@onready var shop_button_6: Button = $UI/ShopPanel/VBoxContainer/Button6
@onready var shop_button_5: Button = $UI/ShopPanel/VBoxContainer/Button5
@onready var shop_button_4: Button = $UI/ShopPanel/VBoxContainer/Button4

@onready var dice_select_panel: Panel = $UI/DiceSelectPanel
@onready var dice_toggle_list: VBoxContainer = $UI/DiceSelectPanel/VBoxContainer/DiceToggleList
@onready var start_round_button: Button = $UI/DiceSelectPanel/VBoxContainer/StartRoundButton

@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/VBoxContainer/GameOverLabel

var hold_highlight_material: StandardMaterial3D
var kind_tint_materials: Dictionary = {}

var start_transforms: Array[Transform3D] = []
var held: Array[bool] = [false, false, false, false, false]
var die_values: Array[int] = [0, 0, 0, 0, 0]
var settled: Array[bool] = [true, true, true, true, true]
var rest_timers: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var is_rolling: bool = false
var rolls_left: int = MAX_ROLLS

var category_used: Dictionary = {}
var category_scores: Dictionary = {}
var category_buttons: Dictionary = {}
var bonus_label: Label
var total_label: Label

var game_state: GameState = GameState.PLAYING
var owned_dice: Array[String] = []
var active_slot_kinds: Array[String] = []
var round_number: int = 1
var round_goal: int = BASE_GOAL
var dice_select_selected: Array[bool] = []
var dice_toggle_buttons: Array[Button] = []

func _ready() -> void:
	hold_highlight_material = StandardMaterial3D.new()
	hold_highlight_material.albedo_color = Color(1.0, 0.85, 0.2)
	hold_highlight_material.emission_enabled = true
	hold_highlight_material.emission = Color(1.0, 0.75, 0.1)
	hold_highlight_material.emission_energy_multiplier = 0.6

	kind_tint_materials["fixed_6"] = _make_tint_material(Color(0.55, 0.15, 0.75))
	kind_tint_materials["fixed_5"] = _make_tint_material(Color(0.15, 0.35, 0.85))
	kind_tint_materials["fixed_4"] = _make_tint_material(Color(0.15, 0.65, 0.3))

	for i in DICE_COUNT:
		start_transforms.append(dice_bodies[i].global_transform)
		dice_roots[i].visible = false

	shop_button_6.pressed.connect(_on_shop_choice.bind("fixed_6"))
	shop_button_5.pressed.connect(_on_shop_choice.bind("fixed_5"))
	shop_button_4.pressed.connect(_on_shop_choice.bind("fixed_4"))
	start_round_button.pressed.connect(_on_start_round_pressed)
	debug_win_round_button.pressed.connect(_on_debug_win_round_pressed)

	_build_scorecard()
	_reset_game()

func _make_tint_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.4
	return mat

func _physics_process(delta: float) -> void:
	if not is_rolling:
		return

	var all_settled := true
	for i in DICE_COUNT:
		if settled[i]:
			continue
		var body := dice_bodies[i]
		if body.linear_velocity.length() < rest_linear_threshold and body.angular_velocity.length() < rest_angular_threshold:
			rest_timers[i] += delta
			if rest_timers[i] >= rest_time_required:
				settled[i] = true
				die_values[i] = _value_for_slot(i, body)
		else:
			rest_timers[i] = 0.0
		if not settled[i]:
			all_settled = false

	if all_settled:
		_on_roll_finished()

func _value_for_slot(index: int, body: RigidBody3D) -> int:
	match active_slot_kinds[index]:
		"fixed_6":
			return 6
		"fixed_5":
			return 5
		"fixed_4":
			return 4
		_:
			return AXIS_VALUES[_get_top_axis(body)]

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if not _can_toggle_hold():
		return

	var index := _pick_die_index(event.position)
	if index != -1:
		_set_held(index, not held[index])

func _can_toggle_hold() -> bool:
	return game_state == GameState.PLAYING and not is_rolling and rolls_left > 0 and rolls_left < MAX_ROLLS

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

	return dice_bodies.find(result.collider)

func _set_held(index: int, is_held: bool) -> void:
	held[index] = is_held
	dice_meshes[index].set_surface_override_material(1, hold_highlight_material if is_held else null)

func _on_throw_button_pressed() -> void:
	if game_state != GameState.PLAYING or is_rolling or rolls_left <= 0:
		return

	is_rolling = true
	throw_button.disabled = true

	for i in DICE_COUNT:
		if held[i]:
			settled[i] = true
			continue

		dice_roots[i].visible = true
		settled[i] = false
		rest_timers[i] = 0.0

		var body := dice_bodies[i]
		var start_transform: Transform3D = start_transforms[i]
		body.global_transform = start_transform
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false

		var throw_direction := (Vector3.ZERO - start_transform.origin).normalized()
		body.apply_central_impulse(throw_direction * throw_force + Vector3.DOWN * 2.0)
		body.apply_torque_impulse(Vector3(
			randf_range(-spin_strength, spin_strength),
			randf_range(-spin_strength, spin_strength),
			randf_range(-spin_strength, spin_strength)
		))

	rolls_left -= 1
	_refresh_ui()

func _on_roll_finished() -> void:
	is_rolling = false
	throw_button.disabled = rolls_left <= 0
	_refresh_ui()

func _on_reset_button_pressed() -> void:
	_reset_game()

func _reset_game() -> void:
	is_rolling = false
	game_state = GameState.PLAYING
	owned_dice = ["normal", "normal", "normal", "normal", "normal"]
	active_slot_kinds = owned_dice.duplicate()
	round_number = 1
	round_goal = BASE_GOAL
	shop_panel.visible = false
	dice_select_panel.visible = false
	game_over_panel.visible = false
	_set_gameplay_ui_visible(true)
	_apply_slot_kind_tints()
	_start_new_round_line()

func _start_new_turn() -> void:
	rolls_left = MAX_ROLLS
	_reset_dice()
	throw_button.disabled = false
	_refresh_ui()

func _start_new_round_line() -> void:
	for cat in CATEGORIES:
		category_used[cat["key"]] = false
		category_scores[cat["key"]] = 0
	rolls_left = MAX_ROLLS
	_reset_dice()
	throw_button.disabled = false
	_refresh_ui()

func _reset_dice() -> void:
	for i in DICE_COUNT:
		held[i] = false
		die_values[i] = 0
		settled[i] = true
		rest_timers[i] = 0.0
		dice_roots[i].visible = false
		dice_meshes[i].set_surface_override_material(1, null)

func _apply_slot_kind_tints() -> void:
	for i in DICE_COUNT:
		var kind: String = active_slot_kinds[i]
		dice_meshes[i].set_surface_override_material(0, kind_tint_materials.get(kind))

func _get_top_axis(body: RigidBody3D) -> String:
	var basis := body.global_transform.basis
	var best_axis := "OBEN"
	var best_dot := -INF
	for axis in AXIS_DIRECTIONS.keys():
		var world_dir: Vector3 = basis * AXIS_DIRECTIONS[axis]
		var d := world_dir.dot(Vector3.UP)
		if d > best_dot:
			best_dot = d
			best_axis = axis
	return best_axis

func _add_score_row(parent: VBoxContainer, label_text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(140, 0)
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = "0"
	row.add_child(value_label)

	parent.add_child(row)
	return value_label

func _add_category_row(parent: VBoxContainer, key: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(140, 0)
	row.add_child(name_label)

	var score_button := Button.new()
	score_button.custom_minimum_size = Vector2(60, 0)
	score_button.disabled = true
	score_button.text = "-"
	score_button.pressed.connect(_on_category_pressed.bind(key))
	row.add_child(score_button)

	parent.add_child(row)
	category_buttons[key] = score_button
	category_used[key] = false
	category_scores[key] = 0

func _build_scorecard() -> void:
	for cat in CATEGORIES:
		_add_category_row(scorecard, cat["key"], cat["label"])

	bonus_label = _add_score_row(scorecard, "Bonus (63+)")
	total_label = _add_score_row(scorecard, "Gesamt")

func _on_category_pressed(key: String) -> void:
	if game_state != GameState.PLAYING or category_used[key] or is_rolling or rolls_left >= MAX_ROLLS:
		return
	category_scores[key] = _score_category(key, die_values)
	category_used[key] = true
	_refresh_ui()

	if _all_categories_used():
		_on_round_line_complete()
	else:
		_start_new_turn()

func _all_categories_used() -> bool:
	for cat in CATEGORIES:
		if not category_used[cat["key"]]:
			return false
	return true

func _on_round_line_complete() -> void:
	throw_button.disabled = true
	var total := _calculate_total()
	if total >= round_goal:
		game_state = GameState.SHOP
		_show_shop()
	else:
		game_state = GameState.GAME_OVER
		_show_game_over(total)

func _on_debug_win_round_pressed() -> void:
	if game_state != GameState.PLAYING:
		return
	is_rolling = false
	throw_button.disabled = true
	game_state = GameState.SHOP
	_show_shop()

func _set_gameplay_ui_visible(is_visible: bool) -> void:
	hint_label.visible = is_visible
	scorecard.visible = is_visible

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
	active_slot_kinds = chosen

	dice_select_panel.visible = false
	game_state = GameState.PLAYING
	_set_gameplay_ui_visible(true)
	_apply_slot_kind_tints()
	_start_new_round_line()

func _show_game_over(total: int) -> void:
	game_over_label.text = "Ziel verfehlt: %d / %d Punkte.\nSpiel vorbei – klicke 'Neues Spiel' zum Neustart." % [total, round_goal]
	_set_gameplay_ui_visible(false)
	game_over_panel.visible = true

func _calculate_bonus() -> int:
	var upper_sum := 0
	for key in UPPER_KEYS:
		if category_used[key]:
			upper_sum += category_scores[key]
	return UPPER_BONUS_VALUE if upper_sum >= UPPER_BONUS_THRESHOLD else 0

func _calculate_total() -> int:
	var total := _calculate_bonus()
	for cat in CATEGORIES:
		if category_used[cat["key"]]:
			total += category_scores[cat["key"]]
	return total

func _refresh_ui() -> void:
	round_label.text = "Runde %d · Ziel: %d Punkte" % [round_number, round_goal]

	if game_state == GameState.PLAYING:
		rolls_label.text = "Würfe übrig: %d" % rolls_left
	else:
		rolls_label.text = ""

	var can_select := game_state == GameState.PLAYING and not is_rolling and rolls_left < MAX_ROLLS
	for cat in CATEGORIES:
		var key: String = cat["key"]
		var button: Button = category_buttons[key]
		if category_used[key]:
			button.text = str(category_scores[key])
			button.disabled = true
		elif can_select:
			button.text = str(_score_category(key, die_values))
			button.disabled = false
		else:
			button.text = "-"
			button.disabled = true

	bonus_label.text = str(_calculate_bonus())
	total_label.text = str(_calculate_total())

func _score_category(key: String, dice: Array[int]) -> int:
	match key:
		"ones":
			return _count(dice, 1) * 1
		"twos":
			return _count(dice, 2) * 2
		"threes":
			return _count(dice, 3) * 3
		"fours":
			return _count(dice, 4) * 4
		"fives":
			return _count(dice, 5) * 5
		"sixes":
			return _count(dice, 6) * 6
		"three_kind":
			return _sum(dice) if _has_count_at_least(dice, 3) else 0
		"four_kind":
			return _sum(dice) if _has_count_at_least(dice, 4) else 0
		"full_house":
			return 25 if _is_full_house(dice) else 0
		"small_straight":
			return 30 if _has_small_straight(dice) else 0
		"large_straight":
			return 40 if _has_large_straight(dice) else 0
		"yahtzee":
			return 50 if _has_count_at_least(dice, 5) else 0
		"chance":
			return _sum(dice)
	return 0

func _counts(dice: Array[int]) -> Dictionary:
	var result := {}
	for value in dice:
		result[value] = result.get(value, 0) + 1
	return result

func _count(dice: Array[int], value: int) -> int:
	return _counts(dice).get(value, 0)

func _sum(dice: Array[int]) -> int:
	var total := 0
	for value in dice:
		total += value
	return total

func _has_count_at_least(dice: Array[int], n: int) -> bool:
	for count in _counts(dice).values():
		if count >= n:
			return true
	return false

func _is_full_house(dice: Array[int]) -> bool:
	var counts: Array = _counts(dice).values()
	counts.sort()
	return counts == [2, 3]

func _has_small_straight(dice: Array[int]) -> bool:
	var unique := {}
	for value in dice:
		unique[value] = true
	var runs := [[1, 2, 3, 4], [2, 3, 4, 5], [3, 4, 5, 6]]
	for run in runs:
		var has_all := true
		for value in run:
			if not unique.has(value):
				has_all = false
				break
		if has_all:
			return true
	return false

func _has_large_straight(dice: Array[int]) -> bool:
	var unique := {}
	for value in dice:
		unique[value] = true
	if unique.size() != 5:
		return false
	return not unique.has(1) or not unique.has(6)
