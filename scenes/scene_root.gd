extends Node3D
## Spielablauf-Koordinator: Rundenziele, Shop, Würfel-Pool und UI-Verdrahtung.
## Wertung: DiceScoring · Würfelphysik: DiceController · Pool-/Warteschlangen-/
## Ablage-Anzeige: DiceTrayView (drei Instanzen) · Look: PageStyle.
##
## Würfel-Pool statt Hände-/Reroll-Zähler: die Sammlung besteht aus fest 30
## Würfeln (anfangs alle "normal"; ein Shop-Kauf ersetzt einen zufälligen
## bestehenden Eintrag durch den neuen Spezialwürfel, der Pool bleibt also
## immer 30 groß). Zu Rundenbeginn wird der Pool gemischt; die noch nicht
## gezogenen 30 Würfel verteilen sich sichtbar auf zwei Trays, die zusammen
## eine Einheit bilden (siehe _refresh_deck_trays): die kleine Warteschlange
## (immer die als Nächstes gezogenen, max. 6 Würfel - beim Wurf werden genau
## diese tatsächlich verbraucht) und dahinter das größere Pool-Tray mit dem
## Rest. Beim tatsächlichen Wurf verschwinden die gezogenen Würfel aus der
## Warteschlange, alles rückt nach (die Lücke entsteht hinten, nicht
## mittendrin) und die Würfel wandern - sobald sie nicht mehr im Spiel sind
## (Neu-Würfeln ersetzt sie, oder die ganze Hand wird genommen/verworfen) -
## ins Ablage-Tray. Die Runde endet, sobald der Pool keine volle Hand mehr
## hergibt.
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

## Position, an die das Warteschlangen-Tray andockt, solange die Kamera auf
## die Grube fokussiert ist: knapp vor deren Südrand, mittig - am unteren
## Bildschirmrand der gezoomten Grubenansicht, da Welt-X = Bildschirm-oben
## und Welt-Z = Bildschirm-rechts gilt (siehe CameraRig.ZOOM_BASIS). Empirisch
## getroffen (siehe scenes/dice_tray.tscn für die Kollisions-Maße der Grube;
## das sichtbare Tischmodell ist größer als diese Kollisionsboxen). Danach
## zieht sich das Tray wieder an seinen Normalplatz neben dem Pool-Tray zurück
## (siehe _update_queue_tray_dock).
const QUEUE_TRAY_PIT_POSITION := Vector3(-13.0, 0.0, 0.0)
const QUEUE_TRAY_MOVE_DURATION := 0.6

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
@onready var shop_dice_picker: RotatableDieView = $UI/ShopPanel/VBoxContainer/DicePicker

@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/VBoxContainer/GameOverLabel

@onready var die_inspector: DieInspectorView = $UI/DieInspectorView

@onready var legend_content_label: Label = $UI/LegendPanel/Margin/LegendContentLabel

@onready var pool_tray_view: DiceTrayView = $PoolTrayView
@onready var discard_tray_view: DiceTrayView = $DiscardTrayView
@onready var queue_tray_view: DiceTrayView = $QueueTrayView

@onready var camera_rig: CameraRig = $Camera3D
@onready var pit_click_zone: StaticBody3D = $DiceTray/PitClickZone

var dice: DiceController

var is_rolling: bool = false
var has_rolled_current_hand: bool = false
var hand_total: int = 0

var game_state: GameState = GameState.PLAYING
var round_number: int = 1
var round_goal: int = BASE_GOAL

var shop_defs: Array[DieDefinition] = []  # aktuell im Shop angebotene Würfel-Kandidaten (Reihenfolge = shop_dice_picker)
var owned_pool: Array[DieDefinition] = []  # persistente Sammlung, immer genau POOL_SIZE Einträge
var round_pool_kinds: Array[DieDefinition] = []  # feste Zieh-Reihenfolge der laufenden Runde (POOL_SIZE Einträge)
var next_draw_index: int = 0  # wie viele davon schon gezogen wurden
var active_kinds: Array[DieDefinition] = []  # aktuell den 6 Würfel-Slots zugewiesene Würfel

var last_throw_was_reroll: bool = false  # war der zuletzt gestartete Wurf ein Neu-Würfeln?
var pre_reroll_values: Array[int] = []  # Würfelwerte VOR dem Neu-Würfeln (für Farkle-Vergleich)
var hand_note: String = ""  # transiente Meldung (z.B. Farkle) für die Pause zwischen Händen

var gameplay_ui_state_visible: bool = true  # true während PLAYING, false während Shop/GameOver
var is_pit_focused: bool = false  # true, solange die Kamera auf die Würfelgrube gezoomt ist

var queue_tray_home_position: Vector3  # Normalplatz neben dem Pool-Tray, siehe _ready
var queue_tray_tween: Tween

## Startpositionen der 6 Spielwürfel, bevor sie zum ersten Mal geworfen
## werden (nur die Position zählt - throw_unheld() berechnet die Wurfrichtung
## daraus, die Rotation ist irrelevant, da die Würfel bis zum ersten Wurf
## unsichtbar sind).
const DICE_START_POSITIONS: Array[Vector3] = [
	Vector3(-8.5, 13.695267, -5.5573406),
	Vector3(-5.1, 13.695267, -5.5573406),
	Vector3(-1.7, 13.695267, -5.5573406),
	Vector3(1.7, 13.695267, -5.5573406),
	Vector3(5.1, 13.695267, -5.5573406),
	Vector3(8.5, 13.695267, -5.5573406),
]

func _ready() -> void:
	var roots: Array[Node3D] = []
	var bodies: Array[RigidBody3D] = []
	var face_displays: Array[DieFaceDisplay] = []
	for i in DICE_START_POSITIONS.size():
		var die := DieBuilder.build()
		$Dice.add_child(die)
		die.position = DICE_START_POSITIONS[i]
		roots.append(die)
		bodies.append(die.get_node("RigidBody3D"))
		face_displays.append(die.get_node("RigidBody3D/Faces"))
	dice = DiceController.new(roots, bodies, face_displays)

	queue_tray_home_position = queue_tray_view.position

	shop_defs = [
		DieDefinition.fixed(6, "Immer 6"),
		DieDefinition.fixed(5, "Immer 5"),
		DieDefinition.fixed(4, "Immer 4"),
	]
	shop_dice_picker.set_dice(shop_defs)
	shop_dice_picker.die_clicked.connect(_on_shop_die_clicked)
	debug_win_round_button.pressed.connect(_on_debug_win_round_pressed)
	camera_rig.mode_changed.connect(_on_camera_mode_changed)

	_populate_legend()
	_reset_game()

## Baut den Text der Legende einmalig aus DiceScoring.CATEGORIES auf –
## von der prestigeträchtigsten zur schwächsten Hand (siehe HAND_PRIORITY),
## damit die Anzeige immer zur tatsächlichen Wertungslogik passt.
func _populate_legend() -> void:
	var lines: Array[String] = ["Kombinationen (Basis × Mult):"]
	for key in DiceScoring.HAND_PRIORITY:
		var label: String = DiceScoring.label_for(key)
		var mult: int = DiceScoring.mult_for(key)
		lines.append("%s  ×%d" % [label, mult])
	legend_content_label.text = "\n".join(lines)

func _physics_process(delta: float) -> void:
	if not is_rolling:
		return
	if dice.physics_step(delta, rest_linear_threshold, rest_angular_threshold, rest_time_required):
		_on_roll_finished()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		camera_rig.zoom_out()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if _can_toggle_hold():
		var index := _pick_die_index(event.position)
		if index != -1:
			dice.set_held(index, not dice.held[index])
			_refresh_deck_trays()
			return

	if not is_rolling and _try_tray_die_click(event.position):
		return

	_try_zoom_click(event.position)

## Klick auf einen einzelnen (sichtbaren) Würfel in den GERADE FOKUSSIERTEN
## Tray(s) (Layer 16, siehe DiceTrayView.SLOT_PICK_LAYER) - öffnet die freie
## 3D-Vorschau (DieInspectorView) für genau diesen Würfel. Erst wenn die
## Kamera bereits auf das jeweilige Tray gezoomt ist (camera_rig.mode), lässt
## sich so ein Würfel darin anklicken - ein Klick davor löst stattdessen ganz
## normal den Zoom aus (siehe _try_zoom_click). Ohne diese Gate wäre ein
## Würfel theoretisch schon aus der Übersicht per Raycast treffbar, auch
## wenn er auf dem Bildschirm winzig ist.
## Pool- und Warteschlangen-Tray gelten als eine Einheit (siehe POOL_TARGET/
## _refresh_deck_trays): beide werden gemeinsam nach dem angeklickten Würfel
## durchsucht.
func _try_tray_die_click(screen_pos: Vector2) -> bool:
	var candidate_trays: Array[DiceTrayView] = []
	match camera_rig.mode:
		CameraRig.Mode.POOL:
			candidate_trays = [pool_tray_view, queue_tray_view]
		CameraRig.Mode.DISCARD:
			candidate_trays = [discard_tray_view]
		_:
			return false

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false

	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 16
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false

	for target_tray in candidate_trays:
		var index: int = target_tray.find_slot_index(result.collider)
		if index != -1:
			die_inspector.show_die(target_tray.slot_defs[index])
			return true
	return false

## Klick auf die Würfelgrube oder eines der Trays (Layer 4) -> Kamera fährt
## näher heran. Läuft unabhängig vom Halten-Klick auf Würfel (Layer 2).
func _try_zoom_click(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 8
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Object = result.collider
	if collider == pit_click_zone:
		camera_rig.zoom_to(CameraRig.Mode.PIT)
	elif collider == pool_tray_view.click_zone or collider == queue_tray_view.click_zone:
		camera_rig.zoom_to(CameraRig.Mode.POOL)
	elif collider == discard_tray_view.click_zone:
		camera_rig.zoom_to(CameraRig.Mode.DISCARD)

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

func _draw_one() -> DieDefinition:
	var def: DieDefinition = round_pool_kinds[next_draw_index]
	next_draw_index += 1
	return def

## Schickt einen einzelnen gebrauchten Würfel ins Ablage-Tray.
func _discard_kind(def: DieDefinition) -> void:
	discard_tray_view.add_die(def)

## Schickt die komplette aktuelle Hand (alle 6 Slots, egal ob gehalten) ins
## Ablage-Tray - wird aufgerufen, sobald eine Hand genommen oder verworfen wird.
func _discard_active_hand() -> void:
	for kind in active_kinds:
		_discard_kind(kind)

## Wie viele der im Warteschlangen-Tray angezeigten Würfel beim nächsten Wurf
## tatsächlich gezogen werden (siehe fill()-Aufruf in _refresh_deck_trays):
## vor dem ersten Wurf einer Hand immer HAND_SIZE, danach genau so viele wie
## aktuell nicht gehalten werden (begrenzt auf das, was der Pool noch hergibt).
func _current_queue_size() -> int:
	var wanted := HAND_SIZE
	if has_rolled_current_hand:
		wanted = 0
		for i in dice.count():
			if not dice.held[i]:
				wanted += 1
	return min(wanted, _remaining_in_pool())

## Pool-Tray und Warteschlangen-Tray zusammen zeigen genau den noch nicht
## gezogenen Teil des Pools (POOL_SIZE Würfel insgesamt): die Warteschlange
## ist ein fest reserviertes 6er-Fenster direkt am Zieh-Cursor, der Pool zeigt
## alles danach. Das Fenster selbst ändert sich nur, wenn next_draw_index
## vorrückt (siehe _draw_one) - also erst beim tatsächlichen Wurf, nicht schon
## beim Halten/Loslassen einzelner Würfel in der Grube. Stattdessen werden nur
## die ersten _current_queue_size() Würfel im Fenster hervorgehoben (siehe
## DiceTrayView.fill/highlight_count) - das sind die, die der nächste Wurf
## wirklich zieht. Beide Trays werden bei jeder Änderung komplett neu befüllt,
## nie einzeln ausgeblendet - dadurch rückt beim Ziehen immer alles kompakt
## nach, die Lücke entsteht hinten (unten rechts) statt mittendrin.
func _refresh_deck_trays() -> void:
	var queue_size := _current_queue_size()
	var window_size: int = min(HAND_SIZE, _remaining_in_pool())
	var queue_defs := round_pool_kinds.slice(next_draw_index, next_draw_index + window_size)
	queue_tray_view.fill(queue_defs, queue_size)
	var pool_start := next_draw_index + HAND_SIZE
	pool_tray_view.fill(round_pool_kinds.slice(pool_start, round_pool_kinds.size()))

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
		dice.set_slot_defs(active_kinds)
	else:
		# Reroll: Hand vor dem Wurf merken (für Farkle-Vergleich), nicht gehaltene
		# Würfel aussortieren (-> Ablage-Tray), markierten Ersatz ziehen.
		pre_reroll_values = dice.values.duplicate()
		for i in dice.count():
			if not dice.held[i] and _remaining_in_pool() > 0:
				_discard_kind(active_kinds[i])
				active_kinds[i] = _draw_one()
		dice.set_slot_defs(active_kinds)

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
	if last_throw_was_reroll and _any_unheld() and not DiceScoring.is_strictly_better(dice.values, pre_reroll_values):
		_on_farkle()
		return

	has_rolled_current_hand = true
	take_button.disabled = false
	throw_button.disabled = _remaining_in_pool() <= 0
	_refresh_deck_trays()
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
	_discard_active_hand()
	if _remaining_in_pool() < HAND_SIZE:
		_on_round_complete()
	else:
		_start_new_hand()

func _on_take_button_pressed() -> void:
	if game_state != GameState.PLAYING or not has_rolled_current_hand or is_rolling:
		return

	var hand := DiceScoring.best_hand(dice.values)
	hand_total += hand["score"]
	_discard_active_hand()

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
		owned_pool.append(DieDefinition.standard())
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
	discard_tray_view.clear()
	hand_total = 0
	hand_note = ""
	_start_new_hand()

func _start_new_hand() -> void:
	has_rolled_current_hand = false
	active_kinds = []
	dice.reset()
	throw_button.disabled = false
	take_button.disabled = true
	_refresh_deck_trays()
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

## Steuert die Sichtbarkeit der Spiel-UI (Text + Würfel-Buttons) anhand des
## Spielzustands (false während Shop/GameOver) - kombiniert mit dem
## Kamera-Fokus (siehe _on_camera_mode_changed) in _update_gameplay_ui_visibility.
func _set_gameplay_ui_visible(is_visible: bool) -> void:
	gameplay_ui_state_visible = is_visible
	_update_gameplay_ui_visibility()

func _on_camera_mode_changed(new_mode: CameraRig.Mode) -> void:
	is_pit_focused = new_mode == CameraRig.Mode.PIT
	_update_gameplay_ui_visibility()
	_update_queue_tray_dock()

## Lässt das Warteschlangen-Tray zur Grube andocken, sobald die Kamera dorthin
## zoomt (siehe QUEUE_TRAY_PIT_POSITION), und wieder zurück an seinen
## Normalplatz, sobald sie das nicht mehr tut - so ist immer sichtbar, welche
## Würfel als Nächstes geworfen werden, ohne aus der Grube heraus zoomen zu
## müssen.
func _update_queue_tray_dock() -> void:
	var target := QUEUE_TRAY_PIT_POSITION if is_pit_focused else queue_tray_home_position
	if queue_tray_tween:
		queue_tray_tween.kill()
	queue_tray_tween = create_tween()
	queue_tray_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	queue_tray_tween.tween_property(queue_tray_view, "position", target, QUEUE_TRAY_MOVE_DURATION)

## UI-Text und Würfeln/Nehmen-Buttons sind nur sichtbar, wenn die Kamera auf
## die Grube fokussiert ist UND der Spielzustand sie erlaubt (nicht während
## Shop/GameOver).
func _update_gameplay_ui_visibility() -> void:
	var show_ui := gameplay_ui_state_visible and is_pit_focused
	hint_label.visible = show_ui
	hand_label.visible = show_ui
	round_label.visible = show_ui
	pool_label.visible = show_ui
	throw_button.visible = show_ui
	take_button.visible = show_ui

func _show_shop() -> void:
	_set_gameplay_ui_visible(false)
	shop_panel.visible = true

func _on_shop_die_clicked(index: int) -> void:
	_on_shop_choice(shop_defs[index])

func _on_shop_choice(def: DieDefinition) -> void:
	if game_state != GameState.SHOP:
		return
	_replace_pool_entry(def)
	round_number += 1
	round_goal += GOAL_INCREMENT
	shop_panel.visible = false
	game_state = GameState.PLAYING
	_set_gameplay_ui_visible(true)
	_start_new_round()

## Ersetzt einen zufälligen Pool-Eintrag durch eine unabhängige Kopie des neu
## gekauften Würfels (bevorzugt einen "normalen", damit bereits gekaufte
## Spezialwürfel nicht versehentlich wieder verdrängt werden). Der Pool
## bleibt immer POOL_SIZE groß. Die Kopie (statt der geteilten Shop-Vorlage)
## stellt sicher, dass spätere Upgrades nur diesen einen Würfel verändern.
func _replace_pool_entry(def: DieDefinition) -> void:
	var normal_indices: Array[int] = []
	for i in owned_pool.size():
		if owned_pool[i].style_id == "normal":
			normal_indices.append(i)

	var target_index: int
	if not normal_indices.is_empty():
		target_index = normal_indices[randi() % normal_indices.size()]
	else:
		target_index = randi() % owned_pool.size()
	owned_pool[target_index] = def.instantiate()

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
		var hand := DiceScoring.best_hand(dice.values)
		var value_strings: Array[String] = []
		for v in dice.values:
			value_strings.append(str(v))
		hand_label.text = "%s  →  %s ×%d  =  %d Punkte" % [" ".join(value_strings), hand["label"], hand["mult"], hand["score"]]
		throw_button.text = "Neu würfeln"
