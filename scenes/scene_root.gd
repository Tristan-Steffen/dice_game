extends Node3D
## Spielablauf-Koordinator: Rundenziele, Shop, Würfel-Pool und UI-Verdrahtung.
## Wertung: KniffelScoring · Würfelphysik: DiceController · Look: PageStyle.
##
## Würfel-Pool statt Hände-/Reroll-Zähler: die Sammlung besteht aus fest 30
## Würfeln (anfangs alle "normal"; ein Shop-Kauf ersetzt einen zufälligen
## bestehenden Eintrag durch den neuen Spezialwürfel, der Pool bleibt also
## immer 30 groß). Zu Rundenbeginn wird der Pool gemischt; jede neue Hand
## zieht 5 Würfel daraus. Wer beim Rerollen einen Würfel aussortiert, bekommt
## dafür einen frischen aus dem Pool - der aussortierte kommt nicht zurück.
## Die Runde endet, sobald der Pool keine volle Hand mehr hergibt.

@export var throw_force: float = 12.0
@export var spin_strength: float = 10.0
@export var rest_linear_threshold: float = 0.05
@export var rest_angular_threshold: float = 0.05
@export var rest_time_required: float = 0.5

const POOL_SIZE := 30
const HAND_SIZE := 5
const BASE_GOAL := 150
const GOAL_INCREMENT := 50

enum GameState { PLAYING, SHOP, GAME_OVER }

@onready var throw_button: Button = $UI/ThrowButton
@onready var take_button: Button = $UI/TakeButton
@onready var reset_button: Button = $UI/ResetButton
@onready var debug_win_round_button: Button = $UI/DebugWinRoundButton
@onready var round_label: Label = $UI/RoundLabel
@onready var pool_label: Label = $UI/PoolLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var hand_label: Label = $UI/HandLabel

@onready var shop_panel: Panel = $UI/ShopPanel
@onready var shop_button_6: Button = $UI/ShopPanel/VBoxContainer/Button6
@onready var shop_button_5: Button = $UI/ShopPanel/VBoxContainer/Button5
@onready var shop_button_4: Button = $UI/ShopPanel/VBoxContainer/Button4

@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/VBoxContainer/GameOverLabel

var dice: DiceController

var is_rolling: bool = false
var has_rolled_current_hand: bool = false
var hand_total: int = 0

var game_state: GameState = GameState.PLAYING
var round_number: int = 1
var round_goal: int = BASE_GOAL

var owned_pool: Array[String] = []  # persistente Sammlung, immer genau POOL_SIZE Einträge
var round_pool: Array[String] = []  # gemischter Rest-Pool der laufenden Runde
var active_kinds: Array[String] = []  # aktuell den 5 Würfel-Slots zugewiesene Arten

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
	return game_state == GameState.PLAYING and not is_rolling and has_rolled_current_hand and not round_pool.is_empty()

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
	if has_rolled_current_hand:
		if round_pool.is_empty():
			return
		# Reroll: nicht gehaltene Würfel aussortieren, Ersatz aus dem Pool ziehen.
		for i in dice.count():
			if not dice.held[i] and not round_pool.is_empty():
				active_kinds[i] = round_pool.pop_back()
		dice.set_slot_kinds(active_kinds)

	is_rolling = true
	throw_button.disabled = true
	take_button.disabled = true
	dice.throw_unheld(throw_force, spin_strength)
	_refresh_ui()

func _on_roll_finished() -> void:
	is_rolling = false
	has_rolled_current_hand = true
	take_button.disabled = false
	throw_button.disabled = round_pool.is_empty()
	_refresh_ui()

func _on_take_button_pressed() -> void:
	if game_state != GameState.PLAYING or not has_rolled_current_hand or is_rolling:
		return

	var hand := KniffelScoring.best_hand(dice.values)
	hand_total += hand["score"]

	if round_pool.size() < HAND_SIZE:
		_on_round_complete()
	else:
		_start_new_hand()

func _on_reset_button_pressed() -> void:
	_reset_game()

func _reset_game() -> void:
	is_rolling = false
	game_state = GameState.PLAYING
	owned_pool.clear()
	for i in POOL_SIZE:
		owned_pool.append("normal")
	round_number = 1
	round_goal = BASE_GOAL
	shop_panel.visible = false
	game_over_panel.visible = false
	_set_gameplay_ui_visible(true)
	_start_new_round()

func _start_new_round() -> void:
	round_pool = owned_pool.duplicate()
	round_pool.shuffle()
	hand_total = 0
	_start_new_hand()

func _start_new_hand() -> void:
	has_rolled_current_hand = false
	active_kinds = _draw_from_pool(HAND_SIZE)
	dice.set_slot_kinds(active_kinds)
	dice.reset()
	throw_button.disabled = false
	take_button.disabled = true
	_refresh_ui()

func _draw_from_pool(n: int) -> Array[String]:
	var drawn: Array[String] = []
	for i in n:
		if round_pool.is_empty():
			break
		drawn.append(round_pool.pop_back())
	return drawn

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
	_replace_pool_entry(kind)
	round_number += 1
	round_goal += GOAL_INCREMENT
	shop_panel.visible = false
	game_state = GameState.PLAYING
	_set_gameplay_ui_visible(true)
	_start_new_round()

## Ersetzt einen zufälligen Pool-Eintrag durch den neu gekauften Würfel
## (bevorzugt einen "normalen", damit bereits gekaufte Spezialwürfel nicht
## versehentlich wieder verdrängt werden). Der Pool bleibt immer POOL_SIZE groß.
func _replace_pool_entry(kind: String) -> void:
	var normal_indices: Array[int] = []
	for i in owned_pool.size():
		if owned_pool[i] == "normal":
			normal_indices.append(i)

	var target_index: int
	if not normal_indices.is_empty():
		target_index = normal_indices[randi() % normal_indices.size()]
	else:
		target_index = randi() % owned_pool.size()
	owned_pool[target_index] = kind

func _show_game_over(total: int) -> void:
	game_over_label.text = "Ziel verfehlt: %d / %d Punkte.\nSpiel vorbei – klicke 'Neues Spiel' zum Neustart." % [total, round_goal]
	_set_gameplay_ui_visible(false)
	game_over_panel.visible = true

func _refresh_ui() -> void:
	round_label.text = "Runde %d · Ziel: %d Punkte · Bisher: %d" % [round_number, round_goal, hand_total]
	pool_label.text = "Würfel im Pool: %d" % round_pool.size()

	if not has_rolled_current_hand:
		hand_label.text = "Würfle, um deine Hand zu sehen"
		throw_button.text = "Würfeln"
	else:
		var hand := KniffelScoring.best_hand(dice.values)
		var value_strings: Array[String] = []
		for v in dice.values:
			value_strings.append(str(v))
		hand_label.text = "%s  →  %s ×%d  =  %d Punkte" % [" ".join(value_strings), hand["label"], hand["mult"], hand["score"]]
		throw_button.text = "Neu würfeln"
