extends Node3D
## Spielablauf-Koordinator: Rundenziele, Shop, Würfel-Pool und UI-Verdrahtung.
## Wertung: KniffelScoring · Würfelphysik: DiceController · Pool-Anzeige:
## DicePoolView · Look: PageStyle.
##
## Würfel-Pool statt Hände-/Reroll-Zähler: die Sammlung besteht aus fest 30
## Würfeln (anfangs alle "normal"; ein Shop-Kauf ersetzt einen zufälligen
## bestehenden Eintrag durch den neuen Spezialwürfel, der Pool bleibt also
## immer 30 groß). Zu Rundenbeginn wird der Pool gemischt und komplett sichtbar
## im DicePoolView aufgestellt. Die als Nächstes gezogenen Würfel (6 beim
## Rundenstart, oder so viele wie gerade nicht gehalten werden) sind dort
## farblich markiert; beim tatsächlichen Wurf verschwinden sie aus dem Pool.
## Die Runde endet, sobald der Pool keine volle Hand mehr hergibt.
##
## Farkle (wie im gleichnamigen Spiel): Ein Neu-Würfeln, das NICHT mehr Punkte
## bringt als der Stand davor (gleich viele oder weniger), "farklet" – die
## aktuelle Hand wird ohne Punkte verworfen und die nächste Hand aus dem
## Rest-Pool gezogen. Der erste Wurf einer Hand kann nie farkeln.

@export var throw_force: float = 16.0
@export var spin_strength: float = 14.0
@export var rest_linear_threshold: float = 0.15
@export var rest_angular_threshold: float = 0.15
@export var rest_time_required: float = 0.2

const POOL_SIZE := 30
const HAND_SIZE := 6
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

@onready var legend_content_label: Label = $UI/LegendPanel/Margin/LegendContentLabel

@onready var dice_pool_view: DicePoolView = $DicePoolView

var dice: DiceController

var is_rolling: bool = false
var has_rolled_current_hand: bool = false
var hand_total: int = 0

var game_state: GameState = GameState.PLAYING
var round_number: int = 1
var round_goal: int = BASE_GOAL

var owned_pool: Array[String] = []  # persistente Sammlung, immer genau POOL_SIZE Einträge
var round_pool_kinds: Array[String] = []  # feste Zieh-Reihenfolge der laufenden Runde (POOL_SIZE Einträge)
var next_draw_index: int = 0  # wie viele davon schon gezogen wurden
var active_kinds: Array[String] = []  # aktuell den 6 Würfel-Slots zugewiesene Arten

var last_throw_was_reroll: bool = false  # war der zuletzt gestartete Wurf ein Neu-Würfeln?
var pre_reroll_values: Array[int] = []  # Würfelwerte VOR dem Neu-Würfeln (für Farkle-Vergleich)
var hand_note: String = ""  # transiente Meldung (z.B. Farkle) für die Pause zwischen Händen

func _ready() -> void:
	var roots: Array[Node3D] = [$Dice1, $Dice2, $Dice3, $Dice4, $Dice5, $Dice6]
	var bodies: Array[RigidBody3D] = [
		$Dice1/RigidBody3D,
		$Dice2/RigidBody3D,
		$Dice3/RigidBody3D,
		$Dice4/RigidBody3D,
		$Dice5/RigidBody3D,
		$Dice6/RigidBody3D,
	]
	var meshes: Array[MeshInstance3D] = [
		$Dice1/RigidBody3D/Die,
		$Dice2/RigidBody3D/Die,
		$Dice3/RigidBody3D/Die,
		$Dice4/RigidBody3D/Die,
		$Dice5/RigidBody3D/Die,
		$Dice6/RigidBody3D/Die,
	]
	dice = DiceController.new(roots, bodies, meshes)

	shop_button_6.pressed.connect(_on_shop_choice.bind("fixed_6"))
	shop_button_5.pressed.connect(_on_shop_choice.bind("fixed_5"))
	shop_button_4.pressed.connect(_on_shop_choice.bind("fixed_4"))
	debug_win_round_button.pressed.connect(_on_debug_win_round_pressed)

	_populate_legend()
	_reset_game()

## Baut den Text der Legende einmalig aus KniffelScoring.CATEGORIES auf –
## von der prestigeträchtigsten zur schwächsten Hand (siehe HAND_PRIORITY),
## damit die Anzeige immer zur tatsächlichen Wertungslogik passt.
func _populate_legend() -> void:
	var lines: Array[String] = ["Kombinationen (Basis × Mult):"]
	for key in KniffelScoring.HAND_PRIORITY:
		var label: String = KniffelScoring.label_for(key)
		var mult: int = KniffelScoring.mult_for(key)
		lines.append("%s  ×%d" % [label, mult])
	legend_content_label.text = "\n".join(lines)

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
		_update_pool_queue_highlight()

func _can_toggle_hold() -> bool:
	return game_state == GameState.PLAYING and not is_rolling and has_rolled_current_hand and _remaining_in_pool() > 0

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

func _remaining_in_pool() -> int:
	return round_pool_kinds.size() - next_draw_index

func _draw_one() -> String:
	var kind: String = round_pool_kinds[next_draw_index]
	dice_pool_view.mark_used(next_draw_index)
	next_draw_index += 1
	return kind

## Wie viele Würfel als Nächstes markiert werden sollen: vor dem ersten Wurf
## einer Hand immer HAND_SIZE, danach genau so viele wie aktuell nicht
## gehalten werden (begrenzt auf das, was der Pool noch hergibt).
func _current_queue_size() -> int:
	var wanted := HAND_SIZE
	if has_rolled_current_hand:
		wanted = 0
		for i in dice.count():
			if not dice.held[i]:
				wanted += 1
	return min(wanted, _remaining_in_pool())

func _update_pool_queue_highlight() -> void:
	var queue_size := _current_queue_size()
	var indices: Array[int] = []
	for i in queue_size:
		indices.append(next_draw_index + i)
	dice_pool_view.set_queued(indices)

func _on_throw_button_pressed() -> void:
	if game_state != GameState.PLAYING or is_rolling:
		return
	if _remaining_in_pool() <= 0:
		return

	last_throw_was_reroll = has_rolled_current_hand
	if not has_rolled_current_hand:
		# Erster Wurf der Hand: die markierten (gequeuten) Würfel jetzt wirklich ziehen.
		hand_note = ""
		active_kinds = []
		for i in HAND_SIZE:
			if _remaining_in_pool() <= 0:
				break
			active_kinds.append(_draw_one())
		dice.set_slot_kinds(active_kinds)
	else:
		# Reroll: Hand vor dem Wurf merken (für Farkle-Vergleich), nicht gehaltene
		# Würfel aussortieren, markierten Ersatz ziehen.
		pre_reroll_values = dice.values.duplicate()
		for i in dice.count():
			if not dice.held[i] and _remaining_in_pool() > 0:
				active_kinds[i] = _draw_one()
		dice.set_slot_kinds(active_kinds)

	is_rolling = true
	throw_button.disabled = true
	take_button.disabled = true
	dice.throw_unheld(throw_force, spin_strength)
	_refresh_ui()

func _on_roll_finished() -> void:
	is_rolling = false

	# Farkle-Prüfung: nur ein echtes Neu-Würfeln kann farkeln – der erste Wurf
	# einer Hand nie, und auch kein "Neu würfeln" ohne freie Würfel (alles
	# gehalten = kein Risiko). Bringt der Wurf nicht mehr Punkte als vorher
	# (gleich viele oder weniger), ist die Hand verloren.
	if last_throw_was_reroll and _any_unheld() and not KniffelScoring.is_strictly_better(dice.values, pre_reroll_values):
		_on_farkle()
		return

	has_rolled_current_hand = true
	take_button.disabled = false
	throw_button.disabled = _remaining_in_pool() <= 0
	_update_pool_queue_highlight()
	_refresh_ui()

func _any_unheld() -> bool:
	for i in dice.count():
		if not dice.held[i]:
			return true
	return false

## Farkle: die aktuelle Hand wird ohne Punkte verworfen. Die verbrauchten Würfel
## sind bereits aus dem Pool gezogen; es geht direkt mit der nächsten Hand
## weiter (bzw. die Runde endet, wenn der Pool keine volle Hand mehr hergibt).
func _on_farkle() -> void:
	hand_note = "Farkle! Keine höhere Punktzahl – die Hand wird ohne Punkte verworfen."
	if _remaining_in_pool() < HAND_SIZE:
		_on_round_complete()
	else:
		_start_new_hand()

func _on_take_button_pressed() -> void:
	if game_state != GameState.PLAYING or not has_rolled_current_hand or is_rolling:
		return

	var hand := KniffelScoring.best_hand(dice.values)
	hand_total += hand["score"]

	if _remaining_in_pool() < HAND_SIZE:
		_on_round_complete()
	else:
		_start_new_hand()

func _on_reset_button_pressed() -> void:
	_reset_game()

func _reset_game() -> void:
	is_rolling = false
	game_state = GameState.PLAYING
	hand_note = ""
	last_throw_was_reroll = false
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
	round_pool_kinds = owned_pool.duplicate()
	round_pool_kinds.shuffle()
	next_draw_index = 0
	dice_pool_view.set_layout(round_pool_kinds)
	hand_total = 0
	hand_note = ""
	_start_new_hand()

func _start_new_hand() -> void:
	has_rolled_current_hand = false
	active_kinds = []
	dice.reset()
	throw_button.disabled = false
	take_button.disabled = true
	_update_pool_queue_highlight()
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
	pool_label.text = "Würfel im Pool: %d" % _remaining_in_pool()

	if not has_rolled_current_hand:
		hand_label.text = hand_note if hand_note != "" else "Würfle, um deine Hand zu sehen"
		throw_button.text = "Würfeln"
	else:
		var hand := KniffelScoring.best_hand(dice.values)
		var value_strings: Array[String] = []
		for v in dice.values:
			value_strings.append(str(v))
		hand_label.text = "%s  →  %s ×%d  =  %d Punkte" % [" ".join(value_strings), hand["label"], hand["mult"], hand["score"]]
		throw_button.text = "Neu würfeln"
