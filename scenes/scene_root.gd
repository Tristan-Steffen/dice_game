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

const DECK_SHIFT_DURATION := 0.45  # Aufrück-Animation der Deck-Würfel nach einem Wurf, siehe _animate_deck_shift

const REORDER_DRAG_THRESHOLD := 6.0  # Pixel, ab wann ein Klick auf einen Warteschlangen-Würfel als Zieh-Geste zählt
const REORDER_LIFT_HEIGHT := 0.8  # Wie weit der gezogene Würfel über das Tray angehoben wird
const REORDER_DROP_RADIUS := 140.0  # Pixel-Toleranz beim Loslassen, siehe _nearest_queue_slot

const CUP_FLY_DURATION := 0.4  # wie lange die gezogenen Würfel zum Becher fliegen, siehe _play_cup_roll
const CUP_SHAKE_COUNT := 3  # wie oft der Becher vor dem Ausschütten wackelt, siehe DiceCup.play_shake

enum GameState { PLAYING, SHOP, GAME_OVER }

@onready var throw_button: Button = $UI/ThrowButton
@onready var take_button: Button = $UI/TakeButton
@onready var reset_button: Button = $UI/ResetButton
@onready var debug_win_round_button: Button = $UI/DebugWinRoundButton
@onready var round_label: Label = $UI/RoundLabel
@onready var hand_label: Label = $UI/HandLabel

@onready var shop_panel: Panel = $UI/ShopPanel
@onready var shop_dice_picker: RotatableDieView = $UI/ShopPanel/VBoxContainer/DicePicker

@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/VBoxContainer/GameOverLabel

@onready var die_inspector: DieInspectorView = $UI/DieInspectorView

@onready var legend_toggle_button: Button = $UI/LegendToggleButton
@onready var legend_panel: Panel = $UI/LegendPanel
@onready var legend_content_label: Label = $UI/LegendPanel/Margin/LegendContentLabel

@onready var pool_tray_view: DiceTrayView = $PoolTrayView
@onready var discard_tray_view: DiceTrayView = $DiscardTrayView
@onready var queue_tray_view: DiceTrayView = $QueueTrayView
@onready var dice_cup: DiceCup = $DiceCup

@onready var camera_rig: CameraRig = $Camera3D
@onready var pit_click_zone: StaticBody3D = $DiceTray/PitClickZone

var dice: DiceController

var is_rolling: bool = false
var is_cup_animating: bool = false  # true während Würfel in den Becher fliegen/er schüttelt, siehe _play_cup_roll
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

var deck_shift_ghosts: Array[Node3D] = []  # temporäre Würfel der Aufrück-Animation, siehe _animate_deck_shift
var deck_shift_tween: Tween

## Fake-Würfel, die nach dem Hineinfliegen sichtbar im Becher "liegen" (in
## $DiceCup/MeshRoot eingehängt, siehe _play_cup_roll - dadurch wackeln sie
## beim Schütteln automatisch mit, ganz ohne echte Physik). Verschwinden
## wieder im Moment des Auskippens (DiceCup.poured_out), sobald die echten
## Wurf-Würfel übernehmen - siehe _on_throw_button_pressed.
var cup_interior_ghosts: Array[Node3D] = []

var queue_window_size: int = 0  # wie viele Slots im Warteschlangen-Tray gerade belegt sind, siehe _refresh_deck_trays

## Umsortieren im Warteschlangen-Tray per Ziehen - siehe _try_start_queue_reorder/_handle_reorder_input.
var reorder_drag_index: int = -1  # Slot-Index im QueueTrayView, der gerade gezogen wird, oder -1
var reorder_drag_start_pos: Vector2
var reorder_is_dragging: bool = false
var reorder_ghost: Node3D

## Startpositionen der 6 Spielwürfel, bevor sie zum ersten Mal geworfen
## werden (nur die Position zählt - throw_unheld() berechnet die Wurfrichtung
## daraus, die Rotation ist irrelevant, da die Würfel bis zum ersten Wurf
## unsichtbar sind). Das ist der ursprünglich für die Grube austarierte
## Fächer aus 6 Positionen (siehe throw_unheld: Wurfrichtung = Richtung zum
## Ursprung), nur um die Y-Achse gedreht, sodass er vom Würfelbecher (siehe
## DiceCup, rechter Rand der Grube) her kommt statt von der alten,
## becherlosen Seite - der Abstand jeder Position zum Ursprung (und damit
## Wurfweite/-charakter) bleibt exakt erhalten.
const DICE_START_POSITIONS: Array[Vector3] = [
	Vector3(6.5458, 13.695267, 7.7658),
	Vector3(3.2886, 13.695267, 6.7886),
	Vector3(0.0314, 13.695267, 5.8115),
	Vector3(-3.2258, 13.695267, 4.8343),
	Vector3(-6.4830, 13.695267, 3.8572),
	Vector3(-9.7402, 13.695267, 2.8800),
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
	legend_toggle_button.pressed.connect(_on_legend_toggle_pressed)

	_populate_legend()
	_reset_game()

## Klappt die Kombinationen-Übersicht auf/zu (siehe LegendToggleButton).
func _on_legend_toggle_pressed() -> void:
	legend_panel.visible = not legend_panel.visible

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
	if reorder_drag_index != -1:
		_handle_reorder_input(event)
		return

	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		camera_rig.zoom_out()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if is_pit_focused and _try_cup_click(event.position):
		return

	if _can_toggle_hold():
		var index := _pick_die_index(event.position)
		if index != -1:
			dice.set_held(index, not dice.held[index])
			_refresh_deck_trays()
			return

	if not is_rolling and not is_cup_animating and deck_shift_ghosts.is_empty() and _try_start_queue_reorder(event.position):
		return

	if not is_rolling and not is_cup_animating and _try_tray_die_click(event.position):
		return

	_try_zoom_click(event.position)

## Klick auf einen einzelnen (sichtbaren) Würfel im GERADE FOKUSSIERTEN Tray
## (Layer 16, siehe DiceTrayView.SLOT_PICK_LAYER) - öffnet die freie 3D-
## Vorschau (DieInspectorView) für genau diesen Würfel. Erst wenn die Kamera
## bereits auf das jeweilige Tray gezoomt ist (camera_rig.mode), lässt sich so
## ein Würfel darin anklicken - ein Klick davor löst stattdessen ganz normal
## den Zoom aus (siehe _try_zoom_click). Ohne diese Gate wäre ein Würfel
## theoretisch schon aus der Übersicht per Raycast treffbar, auch wenn er auf
## dem Bildschirm winzig ist.
## Das Warteschlangen-Tray läuft NICHT mehr über diese Funktion - dort
## entscheidet _try_start_queue_reorder/_handle_reorder_input zwischen Klick
## (öffnet ebenfalls die Vorschau) und Zieh-Geste (sortiert um).
func _try_tray_die_click(screen_pos: Vector2) -> bool:
	var candidate_trays: Array[DiceTrayView] = []
	match camera_rig.mode:
		CameraRig.Mode.POOL:
			candidate_trays = [pool_tray_view]
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

## Klick auf einen Würfel im Warteschlangen-Tray (Layer 16) - startet einen
## POTENZIELLEN Umsortier-Drag (siehe reorder_drag_index/_handle_reorder_input).
## Ob daraus wirklich ein Umsortieren wird oder nur die Würfel-Vorschau wie bei
## den anderen Trays öffnet, entscheidet sich erst beim Loslassen anhand von
## REORDER_DRAG_THRESHOLD. Exklusiv fürs Warteschlangen-Tray - Pool-/Ablage-
## Tray laufen weiterhin nur über _try_tray_die_click.
func _try_start_queue_reorder(screen_pos: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = DiceTrayView.SLOT_PICK_LAYER
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var index: int = queue_tray_view.find_slot_index(result.collider)
	if index == -1:
		return false
	reorder_drag_index = index
	reorder_drag_start_pos = screen_pos
	reorder_is_dragging = false
	return true

## Verarbeitet Maus-Bewegung/-Loslassen während eines potenziellen/aktiven
## Umsortier-Drags (siehe _try_start_queue_reorder). Ein Rechtsklick bricht
## ihn ab; Bewegung über REORDER_DRAG_THRESHOLD hinaus hebt den Würfel sichtbar
## an (siehe _begin_reorder_drag) und lässt ihn der Maus folgen; Loslassen ohne
## Bewegung öffnet stattdessen die Würfel-Vorschau wie bei den anderen Trays.
func _handle_reorder_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_reorder_drag()
		return

	if event is InputEventMouseMotion:
		if not reorder_is_dragging and event.position.distance_to(reorder_drag_start_pos) > REORDER_DRAG_THRESHOLD:
			reorder_is_dragging = true
			_begin_reorder_drag()
		if reorder_is_dragging:
			_update_reorder_drag(event.position)
		return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if reorder_is_dragging:
			_finish_reorder_drag(event.position)
		else:
			die_inspector.show_die(queue_tray_view.slot_defs[reorder_drag_index])
		reorder_drag_index = -1
		reorder_is_dragging = false

## Versteckt den Original-Slot und lässt einen freien Ghost-Würfel (gleiches
## Muster wie die Ghosts der Aufrück-Animation, siehe _animate_deck_shift) an
## seiner Stelle schweben - ab jetzt folgt er der Maus (_update_reorder_drag).
func _begin_reorder_drag() -> void:
	var def: DieDefinition = queue_tray_view.slot_defs[reorder_drag_index]
	queue_tray_view.set_slot_visible(reorder_drag_index, false)
	reorder_ghost = _spawn_deck_ghost(def)
	reorder_ghost.global_position = queue_tray_view.slot_global_position(reorder_drag_index) + Vector3.UP * REORDER_LIFT_HEIGHT

## Lässt den Ghost-Würfel der Maus folgen: projiziert screen_pos auf eine
## waagerechte Ebene auf Anhebehöhe über dem Warteschlangen-Tray.
func _update_reorder_drag(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or reorder_ghost == null:
		return
	var plane := Plane(Vector3.UP, queue_tray_view.global_position.y + REORDER_LIFT_HEIGHT)
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var hit = plane.intersects_ray(from, dir)
	if hit != null:
		reorder_ghost.global_position = hit

## Loslassen nach einem Zieh-Drag: sortiert bei einem gültigen Zielslot um und
## lässt alle davon betroffenen Würfel gleiten (siehe _animate_reorder_move),
## sonst gleitet der gezogene Würfel einfach zu seinem ursprünglichen Slot
## zurück (siehe _animate_reorder_snapback).
func _finish_reorder_drag(screen_pos: Vector2) -> void:
	var target_index := _nearest_queue_slot(screen_pos)
	if target_index != -1 and target_index != reorder_drag_index:
		_animate_reorder_move(reorder_drag_index, target_index)
	else:
		_animate_reorder_snapback()

func _cancel_reorder_drag() -> void:
	_animate_reorder_snapback()
	reorder_drag_index = -1
	reorder_is_dragging = false

## Bildschirmnächster belegter Slot im Warteschlangen-Tray zu screen_pos
## (analog zu RotatableDieView._pick_die: Bildschirm-Projektion statt Physik-
## Raycast, da der gezogene Würfel selbst keine Kollision mehr hat). -1, wenn
## außerhalb von REORDER_DROP_RADIUS losgelassen wurde.
func _nearest_queue_slot(screen_pos: Vector2) -> int:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return -1
	var best_index := -1
	var best_dist := REORDER_DROP_RADIUS
	for i in queue_window_size:
		var slot_screen := camera.unproject_position(queue_tray_view.slot_global_position(i))
		var dist := slot_screen.distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best_index = i
	return best_index

## Kein gültiger Zielslot (oder auf dem eigenen Slot losgelassen): der
## gezogene Ghost-Würfel gleitet zu seinem ursprünglichen Platz zurück - statt
## einfach zu verschwinden, während der Slot sich schlagartig wieder füllt.
func _animate_reorder_snapback() -> void:
	if reorder_ghost == null:
		_refresh_deck_trays()
		return
	var ghost := reorder_ghost
	reorder_ghost = null
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ghost, "global_position", queue_tray_view.slot_global_position(reorder_drag_index), DECK_SHIFT_DURATION)
	tween.tween_callback(func() -> void:
		ghost.queue_free()
		_refresh_deck_trays()
	)

## Wie sich ein alter Slot-Index innerhalb des Warteschlangen-Fensters durch
## das Verschieben von from_index nach to_index verändert (Standard "Element
## verschieben"-Semantik, wie bei remove_at()+insert() auf einem Array).
func _queue_index_after_move(old_index: int, from_index: int, to_index: int) -> int:
	if old_index == from_index:
		return to_index
	if from_index < to_index:
		if old_index > from_index and old_index <= to_index:
			return old_index - 1
	else:
		if old_index >= to_index and old_index < from_index:
			return old_index + 1
	return old_index

## Sortiert einen Würfel innerhalb des sichtbaren Warteschlangen-Fensters um:
## entfernt ihn bei from_index und fügt ihn bei to_index wieder ein (wie eine
## Karte in der Hand verschieben - dazwischenliegende Würfel rücken nach).
## Wirkt nur innerhalb von round_pool_kinds[next_draw_index ..
## next_draw_index+queue_window_size) - der Pool-Teil des Decks ist davon nie
## betroffen, da beide Indizes aus diesem Fenster stammen (siehe
## _try_start_queue_reorder/_nearest_queue_slot). Alle zwischen from_index und
## to_index liegenden Würfel gleiten sichtbar zu ihrem neuen Slot (gleiche
## Ghost-Technik wie die Aufrück-Animation nach einem Wurf, siehe
## _animate_deck_shift) - der gezogene Würfel ist dabei schon sein eigener
## Ghost (reorder_ghost) und gleitet einfach zur Zielposition weiter, statt
## neu gespawnt zu werden.
func _animate_reorder_move(from_index: int, to_index: int) -> void:
	_cancel_deck_shift()
	var lo: int = min(from_index, to_index)
	var hi: int = max(from_index, to_index)

	var old_defs: Array[DieDefinition] = []
	for i in range(lo, hi + 1):
		old_defs.append(round_pool_kinds[next_draw_index + i])

	var abs_from := next_draw_index + from_index
	var abs_to := next_draw_index + to_index
	var moved: DieDefinition = round_pool_kinds[abs_from]
	round_pool_kinds.remove_at(abs_from)
	round_pool_kinds.insert(abs_to, moved)

	deck_shift_tween = create_tween()
	deck_shift_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	deck_shift_tween.set_parallel(true)
	for offset in old_defs.size():
		var old_index := lo + offset
		var new_index := _queue_index_after_move(old_index, from_index, to_index)
		var target_pos := queue_tray_view.slot_global_position(new_index)
		var ghost: Node3D
		if old_index == from_index:
			ghost = reorder_ghost
			reorder_ghost = null
		else:
			queue_tray_view.set_slot_visible(old_index, false)
			ghost = _spawn_deck_ghost(old_defs[offset])
			ghost.global_position = queue_tray_view.slot_global_position(old_index)
		deck_shift_ghosts.append(ghost)
		deck_shift_tween.tween_property(ghost, "global_position", target_pos, DECK_SHIFT_DURATION)
	deck_shift_tween.chain().tween_callback(_finish_deck_shift)

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

## Klick auf den Würfelbecher (eigene Kollisions-Ebene, siehe DiceCup.CLICK_LAYER)
## löst denselben Wurf wie der Würfeln-/Neu-würfeln-Button aus - nur während
## die Kamera auf die Grube fokussiert ist (dort ist der Becher auch sichtbar/
## erreichbar, siehe Aufrufer in _unhandled_input). _on_throw_button_pressed
## prüft alle Vorbedingungen selbst, ein "ungültiger" Klick auf den Becher
## verhält sich also wie ein Klick auf den (ggf. deaktivierten) Button.
func _try_cup_click(screen_pos: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = DiceCup.CLICK_LAYER
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	_on_throw_button_pressed()
	return true

func _can_toggle_hold() -> bool:
	return game_state == GameState.PLAYING and not is_rolling and not is_cup_animating and has_rolled_current_hand and _remaining_in_pool() > 0

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
	if not deck_shift_ghosts.is_empty():
		return  # Aufrück-Animation läuft noch - sie ruft am Ende selbst _refresh_deck_trays auf
	var queue_size := _current_queue_size()
	queue_window_size = min(HAND_SIZE, _remaining_in_pool())
	var queue_defs := round_pool_kinds.slice(next_draw_index, next_draw_index + queue_window_size)
	queue_tray_view.fill(queue_defs, queue_size)
	var pool_start := next_draw_index + HAND_SIZE
	pool_tray_view.fill(round_pool_kinds.slice(pool_start, round_pool_kinds.size()))

## Weltposition, an der der Deck-Eintrag deck_index angezeigt wird, wenn der
## Zieh-Cursor bei cursor steht: die ersten HAND_SIZE Einträge nach dem Cursor
## liegen im Warteschlangen-Tray, alles danach im Pool-Tray (gleiche Aufteilung
## wie _refresh_deck_trays).
func _deck_slot_position(deck_index: int, cursor: int) -> Vector3:
	var offset := deck_index - cursor
	if offset < HAND_SIZE:
		return queue_tray_view.slot_global_position(offset)
	return pool_tray_view.slot_global_position(offset - HAND_SIZE)

## Baut einen freien, nicht-kollidierenden Würfel für die diversen Gleit-
## Animationen (Aufrücken nach einem Wurf, Umsortieren im Warteschlangen-Tray)
## - zeigt def in der passenden Art-Farbe, ist aber keinem Tray-Slot zugeordnet.
func _spawn_deck_ghost(def: DieDefinition) -> Node3D:
	var ghost := DieBuilder.build()
	add_child(ghost)
	ghost.scale = Vector3.ONE * DiceTrayView.DIE_SCALE
	var body: RigidBody3D = ghost.get_node("RigidBody3D")
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	var faces: DieFaceDisplay = ghost.get_node("RigidBody3D/Faces")
	faces.apply_definition(def)
	faces.set_tint(DiceController.KIND_TINTS.get(def.style_id, Color.WHITE))
	return ghost

## Lässt die verbleibenden Deck-Würfel sichtbar aufrücken, nachdem shift Würfel
## gezogen wurden (Aufruf direkt nach den _draw_one()-Aufrufen eines Wurfs):
## beide Trays werden geleert und durch temporäre Geister-Würfel ersetzt, die
## von ihrer alten zu ihrer neuen Slot-Position gleiten - die vordersten
## Pool-Würfel wandern dabei sichtbar hinüber ins Warteschlangen-Tray. Danach
## übernimmt wieder die normale Slot-Anzeige (_refresh_deck_trays).
func _animate_deck_shift(shift: int) -> void:
	if shift <= 0:
		return
	_cancel_deck_shift()
	var old_cursor := next_draw_index - shift
	queue_tray_view.clear()
	pool_tray_view.clear()
	deck_shift_tween = create_tween()
	deck_shift_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	deck_shift_tween.set_parallel(true)
	for deck_index in range(next_draw_index, round_pool_kinds.size()):
		var ghost := _spawn_deck_ghost(round_pool_kinds[deck_index])
		ghost.global_position = _deck_slot_position(deck_index, old_cursor)
		deck_shift_ghosts.append(ghost)
		deck_shift_tween.tween_property(ghost, "global_position", _deck_slot_position(deck_index, next_draw_index), DECK_SHIFT_DURATION)
	deck_shift_tween.chain().tween_callback(_finish_deck_shift)

func _finish_deck_shift() -> void:
	_cancel_deck_shift()
	_refresh_deck_trays()

func _cancel_deck_shift() -> void:
	if deck_shift_tween:
		deck_shift_tween.kill()
		deck_shift_tween = null
	for ghost in deck_shift_ghosts:
		ghost.queue_free()
	deck_shift_ghosts.clear()

func _on_throw_button_pressed() -> void:
	if game_state != GameState.PLAYING or is_rolling or is_cup_animating:
		return
	if _remaining_in_pool() <= 0:
		return

	# Die gerade sichtbaren Warteschlangen-Würfel VOR dem Ziehen merken (Position
	# + Art) - das sind exakt die, die dieser Wurf tatsächlich zieht (siehe
	# _current_queue_size) und die gleich sichtbar in den Becher fliegen sollen.
	var used_count := _current_queue_size()
	var fly_positions: Array[Vector3] = []
	var fly_defs: Array[DieDefinition] = []
	for i in used_count:
		fly_positions.append(queue_tray_view.slot_global_position(i))
		fly_defs.append(queue_tray_view.slot_defs[i])

	# Beim Neu-Würfeln: welche Grube-Würfel gleich ausgetauscht werden (siehe
	# Ersetzungsschleife unten), VOR dem Ziehen mit Position + Art merken und
	# sofort ausblenden - sie sollen gleichzeitig mit den neuen Würfeln (siehe
	# fly_positions/fly_defs oben) sichtbar Richtung Ablage-Tray fliegen,
	# statt erst beim eigentlichen Wurf zu verschwinden (siehe _play_cup_roll).
	# simulated_remaining bildet exakt dieselbe Pool-Abnahme wie die echte
	# Ersetzungsschleife nach, damit hier genauso viele Würfel fliegen, wie
	# dort tatsächlich ersetzt werden.
	var discard_from: Array[Vector3] = []
	var discard_defs: Array[DieDefinition] = []
	var discard_to: Array[Vector3] = []
	if has_rolled_current_hand:
		var simulated_remaining := _remaining_in_pool()
		var next_free := discard_tray_view.next_free_index
		for i in dice.count():
			if dice.held[i] or simulated_remaining <= 0:
				continue
			if next_free >= discard_tray_view.slot_roots.size():
				break
			discard_from.append(dice.bodies[i].global_position)
			discard_defs.append(active_kinds[i])
			discard_to.append(discard_tray_view.slot_global_position(next_free))
			dice.roots[i].visible = false
			simulated_remaining -= 1
			next_free += 1

	is_cup_animating = true
	throw_button.disabled = true
	take_button.disabled = true

	var cursor_before_draw := next_draw_index
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
		# Würfel durch markierten Ersatz ersetzen (die Ablage passiert bereits
		# fliegend oben in discard_from/discard_defs/discard_to).
		pre_reroll_values = dice.values.duplicate()
		for i in dice.count():
			if not dice.held[i] and _remaining_in_pool() > 0:
				active_kinds[i] = _draw_one()
		dice.set_slot_defs(active_kinds)
	_animate_deck_shift(next_draw_index - cursor_before_draw)

	await _play_cup_roll(fly_positions, fly_defs, discard_from, discard_defs, discard_to)
	if game_state != GameState.PLAYING:
		is_cup_animating = false
		_clear_cup_interior_ghosts()
		return  # Spiel wurde während der Becher-Animation zurückgesetzt/beendet

	# Der Becher schwingt tatsächlich durch den Raum Richtung Grube (siehe
	# DiceCup.play_throw); poured_out feuert erst genau im Tiefpunkt dieses
	# Schwungs - erst dann verschwinden die Fake-Würfel im Becher und die
	# echten Wurf-Würfel starten an der dann aktuellen Mündungsposition
	# (siehe _throw_start_positions), damit sie nie teleportieren, sondern
	# sichtbar aus dem Becher heraus in die Grube rollen.
	dice_cup.play_throw()
	await dice_cup.poured_out
	_clear_cup_interior_ghosts()
	is_cup_animating = false
	if game_state != GameState.PLAYING:
		return  # Spiel wurde während des Wurfschwungs zurückgesetzt/beendet

	var start_positions := _throw_start_positions()
	for i in dice.count():
		dice.start_transforms[i] = Transform3D(dice.start_transforms[i].basis, start_positions[i])
	is_rolling = true
	dice.throw_unheld(throw_force, spin_strength)
	_refresh_ui()

## Startpositionen der echten Wurf-Würfel für den Moment von poured_out: ein
## enges Bündel um die aktuelle (geschwungene) Becher-Mündung, mit kleinem
## Zufalls-Versatz je Würfel für eine natürliche Streuung beim Landen -
## sodass sie sichtbar aus der Mündung kommen statt an einer festen,
## unabhängigen Stelle zu erscheinen (siehe DiceController.throw_unheld:
## Wurfrichtung/-stärke ergeben sich pro Würfel automatisch aus seiner
## Startposition relativ zum Grubenzentrum).
func _throw_start_positions() -> Array[Vector3]:
	var mouth := dice_cup.mouth_position()
	var positions: Array[Vector3] = []
	for i in dice.count():
		positions.append(mouth + Vector3(randf_range(-0.6, 0.6), randf_range(-0.2, 0.2), randf_range(-0.6, 0.6)))
	return positions

## Gibt die Fake-Würfel frei, die während des Schüttelns sichtbar im Becher
## liegen (siehe cup_interior_ghosts/_play_cup_roll) - aufgerufen im Moment
## des Auskippens, sobald die echten Wurf-Würfel übernehmen, sowie defensiv
## bei einem Reset mitten in der Animation (siehe _reset_game).
func _clear_cup_interior_ghosts() -> void:
	for ghost in cup_interior_ghosts:
		ghost.queue_free()
	cup_interior_ghosts.clear()

## Lässt die tatsächlich gezogenen Würfel (fly_defs, vorher an den
## Warteschlangen-Positionen fly_positions) sichtbar in den Würfelbecher
## fliegen, UND gleichzeitig die beim Neu-Würfeln ausgetauschten Grube-Würfel
## (discard_defs, vorher an discard_from) sichtbar Richtung Ablage-Tray
## (discard_to) - beides im selben parallelen Tween, damit es exakt
## gleichzeitig passiert. Erst wenn beide Flüge fertig sind, werden die
## Ablage-Würfel wirklich im Ablage-Tray sichtbar (siehe _discard_kind); die
## im Becher angekommenen Würfel werden stattdessen NICHT gelöscht, sondern
## in $DiceCup/MeshRoot eingehängt (siehe cup_interior_ghosts) - dadurch
## liegen sie sichtbar im Becher und wackeln beim Schütteln (siehe
## DiceCup.play_shake) automatisch mit, ganz ohne eigene Physik. Sie
## verschwinden erst im Aufrufer (_on_throw_button_pressed), sobald der
## Becher tatsächlich auskippt.
func _play_cup_roll(fly_positions: Array[Vector3], fly_defs: Array[DieDefinition], discard_from: Array[Vector3], discard_defs: Array[DieDefinition], discard_to: Array[Vector3]) -> void:
	if fly_defs.is_empty() and discard_defs.is_empty():
		return

	var fly_tween := create_tween()
	fly_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fly_tween.set_parallel(true)

	var cup_ghosts: Array[Node3D] = []
	var mouth := dice_cup.mouth_position()
	for i in fly_defs.size():
		var ghost := _spawn_deck_ghost(fly_defs[i])
		ghost.global_position = fly_positions[i]
		cup_ghosts.append(ghost)
		var target := mouth + Vector3(randf_range(-0.4, 0.4), randf_range(-0.15, 0.15), randf_range(-0.4, 0.4))
		fly_tween.tween_property(ghost, "global_position", target, CUP_FLY_DURATION)

	var discard_ghosts: Array[Node3D] = []
	for i in discard_defs.size():
		var ghost := _spawn_deck_ghost(discard_defs[i])
		ghost.global_position = discard_from[i]
		discard_ghosts.append(ghost)
		fly_tween.tween_property(ghost, "global_position", discard_to[i], CUP_FLY_DURATION)

	await fly_tween.finished
	for ghost in cup_ghosts:
		ghost.reparent(dice_cup.mesh_root, true)
		ghost.position = Vector3(randf_range(-0.7, 0.7), randf_range(0.15, 0.5), randf_range(-0.7, 0.7))
		ghost.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))
		cup_interior_ghosts.append(ghost)
	for i in discard_ghosts.size():
		discard_ghosts[i].queue_free()
		_discard_kind(discard_defs[i])

	if not fly_defs.is_empty():
		await dice_cup.play_shake(CUP_SHAKE_COUNT).finished

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
	is_cup_animating = false
	_cancel_deck_shift()
	_cancel_reorder_drag()
	_clear_cup_interior_ghosts()
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
	_cancel_deck_shift()
	_cancel_reorder_drag()
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
	hand_label.visible = show_ui
	round_label.visible = show_ui
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
