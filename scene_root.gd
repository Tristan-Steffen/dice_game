extends Node3D

@export var throw_force: float = 12.0
@export var spin_strength: float = 10.0
@export var rest_linear_threshold: float = 0.05
@export var rest_angular_threshold: float = 0.05
@export var rest_time_required: float = 0.5

const DICE_COUNT := 5
const MAX_ROLLS := 3

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
@onready var rolls_label: Label = $UI/RollsLabel
@onready var scorecard_left: VBoxContainer = $UI/ScoreCard/LeftColumn
@onready var scorecard_right: VBoxContainer = $UI/ScoreCard/RightColumn

var hold_highlight_material: StandardMaterial3D

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

func _ready() -> void:
	hold_highlight_material = StandardMaterial3D.new()
	hold_highlight_material.albedo_color = Color(1.0, 0.85, 0.2)
	hold_highlight_material.emission_enabled = true
	hold_highlight_material.emission = Color(1.0, 0.75, 0.1)
	hold_highlight_material.emission_energy_multiplier = 0.6

	for i in DICE_COUNT:
		start_transforms.append(dice_bodies[i].global_transform)
		dice_roots[i].visible = false

	_build_scorecard()
	_refresh_ui()

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
				die_values[i] = AXIS_VALUES[_get_top_axis(body)]
		else:
			rest_timers[i] = 0.0
		if not settled[i]:
			all_settled = false

	if all_settled:
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
		_set_held(index, not held[index])

func _can_toggle_hold() -> bool:
	return not is_rolling and rolls_left > 0 and rolls_left < MAX_ROLLS

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
	dice_meshes[index].set_surface_override_material(0, hold_highlight_material if is_held else null)

func _on_throw_button_pressed() -> void:
	if is_rolling or rolls_left <= 0:
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
	is_rolling = false
	rolls_left = MAX_ROLLS
	for cat in CATEGORIES:
		category_used[cat["key"]] = false
		category_scores[cat["key"]] = 0
	_reset_dice()
	throw_button.disabled = false
	_refresh_ui()

func _start_new_round() -> void:
	rolls_left = MAX_ROLLS
	_reset_dice()
	throw_button.disabled = _all_categories_used()
	_refresh_ui()

func _reset_dice() -> void:
	for i in DICE_COUNT:
		held[i] = false
		die_values[i] = 0
		settled[i] = true
		rest_timers[i] = 0.0
		dice_roots[i].visible = false
		dice_meshes[i].set_surface_override_material(0, null)

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
		var key: String = cat["key"]
		var column := scorecard_left if key in UPPER_KEYS else scorecard_right
		_add_category_row(column, key, cat["label"])

	bonus_label = _add_score_row(scorecard_left, "Bonus (63+)")
	total_label = _add_score_row(scorecard_right, "Gesamt")

func _on_category_pressed(key: String) -> void:
	if category_used[key] or is_rolling or rolls_left >= MAX_ROLLS:
		return
	category_scores[key] = _score_category(key, die_values)
	category_used[key] = true
	_refresh_ui()
	_start_new_round()

func _all_categories_used() -> bool:
	for cat in CATEGORIES:
		if not category_used[cat["key"]]:
			return false
	return true

func _refresh_ui() -> void:
	if _all_categories_used():
		rolls_label.text = "Spiel beendet!"
	else:
		rolls_label.text = "Würfe übrig: %d" % rolls_left

	var can_select := not is_rolling and rolls_left < MAX_ROLLS
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

	var upper_sum := 0
	for key in UPPER_KEYS:
		if category_used[key]:
			upper_sum += category_scores[key]
	var bonus := UPPER_BONUS_VALUE if upper_sum >= UPPER_BONUS_THRESHOLD else 0
	bonus_label.text = str(bonus)

	var total := bonus
	for cat in CATEGORIES:
		if category_used[cat["key"]]:
			total += category_scores[cat["key"]]
	total_label.text = str(total)

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
