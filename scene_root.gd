extends Node3D

@export var throw_force: float = 12.0
@export var spin_strength: float = 10.0
@export var rest_linear_threshold: float = 0.05
@export var rest_angular_threshold: float = 0.05
@export var rest_time_required: float = 0.5

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
# Falls die angezeigte Zahl nicht zur sichtbaren Seite passt: hier die
# Achse (siehe Debug-Anzeige im Spiel) auf die richtige Zahl setzen.
const AXIS_VALUES := {
	"OBEN": 4,
	"UNTEN": 3,
	"RECHTS": 5,
	"LINKS": 2,
	"VORNE": 1,
	"HINTEN": 6,
}

@onready var dice: RigidBody3D = $Dice/RigidBody3D
@onready var throw_button: Button = $UI/ThrowButton
@onready var roll_label: Label = $UI/RollLabel
@onready var score_label: Label = $UI/ScoreLabel
@onready var debug_label: Label = $UI/DebugLabel

var start_transform: Transform3D
var is_rolling: bool = false
var rest_timer: float = 0.0
var total_score: int = 0
var roll_count: int = 0

func _ready() -> void:
	start_transform = dice.global_transform
	roll_label.text = "Letzter Wurf: -"
	_refresh_score_label()

func _physics_process(delta: float) -> void:
	if not is_rolling:
		return

	if dice.linear_velocity.length() < rest_linear_threshold and dice.angular_velocity.length() < rest_angular_threshold:
		rest_timer += delta
		if rest_timer >= rest_time_required:
			_on_die_settled()
	else:
		rest_timer = 0.0

func _on_throw_button_pressed() -> void:
	if is_rolling:
		return

	is_rolling = true
	rest_timer = 0.0
	throw_button.disabled = true

	dice.global_transform = start_transform
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.sleeping = false

	var throw_direction := (Vector3.ZERO - start_transform.origin).normalized()
	dice.apply_central_impulse(throw_direction * throw_force + Vector3.DOWN * 2.0)
	dice.apply_torque_impulse(Vector3(
		randf_range(-spin_strength, spin_strength),
		randf_range(-spin_strength, spin_strength),
		randf_range(-spin_strength, spin_strength)
	))

func _on_reset_button_pressed() -> void:
	total_score = 0
	roll_count = 0
	roll_label.text = "Letzter Wurf: -"
	_refresh_score_label()

func _on_die_settled() -> void:
	is_rolling = false
	throw_button.disabled = false

	var axis := _get_top_axis()
	var value: int = AXIS_VALUES[axis]
	roll_count += 1
	total_score += value
	roll_label.text = "Letzter Wurf: %d" % value
	debug_label.text = "Debug – erkannte Achse: %s" % axis
	_refresh_score_label()

func _get_top_axis() -> String:
	var basis := dice.global_transform.basis
	var best_axis := "OBEN"
	var best_dot := -INF
	for axis in AXIS_DIRECTIONS.keys():
		var world_dir: Vector3 = basis * AXIS_DIRECTIONS[axis]
		var d := world_dir.dot(Vector3.UP)
		if d > best_dot:
			best_dot = d
			best_axis = axis
	return best_axis

func _refresh_score_label() -> void:
	score_label.text = "Gesamt: %d (Würfe: %d)" % [total_score, roll_count]
