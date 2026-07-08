class_name DiceCup
extends Node3D
## Würfelbecher: rein visuelles Requisit aus Godot-Primitiven (Kegelstumpf-
## Rumpf + Rand, siehe scenes/dice_cup.tscn - kein importiertes Modell). Bietet
## nur die becher-eigenen Animationen (Schütteln, Kippen zum Ausschütten) und
## seine Mündungsposition an; welche Würfel wann hinein-/herausfliegen,
## orchestriert scene_root.gd (siehe _play_cup_roll/_on_throw_button_pressed).
##
## Rotiert wird nur $MeshRoot, nicht der Node selbst - so bleibt die eigene
## Position/Transform (und damit mouth_position()) während der Animationen
## stabil, auch während der Becher optisch kippt oder wackelt.

const MOUTH_LOCAL_HEIGHT := 2.0  # etwas unterhalb des oberen Rands, siehe dice_cup.tscn

## Eigene Kollisions-Ebene fürs Anklicken des Bechers (siehe ClickZone in
## dice_cup.tscn) - scene_root.gd nutzt sie, um einen Klick auf den Becher wie
## den Würfeln-/Neu-würfeln-Button zu behandeln (siehe _try_cup_click).
const CLICK_LAYER := 32

const SHAKE_ANGLE_DEGREES := 9.0
const SHAKE_STEP_DURATION := 0.11

const POUR_ANGLE_DEGREES := 62.0  # Richtung -Z gekippt = Mündung zeigt zur Grube, siehe scene_root.gd
const POUR_OUT_DURATION := 0.22
const POUR_HOLD_DURATION := 0.12
const POUR_RETURN_DURATION := 0.4

@onready var mesh_root: Node3D = $MeshRoot

var base_rotation: Vector3
var active_tween: Tween

func _ready() -> void:
	base_rotation = mesh_root.rotation

## Weltposition knapp über der Becheröffnung - Flugziel für hineinfliegende
## Würfel (siehe scene_root.gd: _play_cup_roll).
func mouth_position() -> Vector3:
	return global_transform * Vector3(0, MOUTH_LOCAL_HEIGHT, 0)

## Rüttelt den Becher count-mal hin und her und kehrt danach zur Ausgangslage
## zurück. Gibt den Tween zurück, damit der Aufrufer per `await ...finished`
## darauf warten kann.
func play_shake(count: int) -> Tween:
	_kill_active_tween()
	mesh_root.rotation = base_rotation
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in count:
		active_tween.tween_property(mesh_root, "rotation:z", base_rotation.z + deg_to_rad(SHAKE_ANGLE_DEGREES), SHAKE_STEP_DURATION)
		active_tween.tween_property(mesh_root, "rotation:z", base_rotation.z - deg_to_rad(SHAKE_ANGLE_DEGREES), SHAKE_STEP_DURATION)
	active_tween.tween_property(mesh_root, "rotation:z", base_rotation.z, SHAKE_STEP_DURATION * 0.5)
	return active_tween

## Kippt den Becher zur Grube hin (Mündung Richtung Tischmitte, siehe
## POUR_ANGLE_DEGREES) und wieder zurück - fürs Ausschütten. Bewusst nicht
## blockierend gedacht: der eigentliche Würfel-Wurf startet, sobald der Becher
## zu kippen beginnt (siehe scene_root.gd: _on_throw_button_pressed).
func play_pour() -> void:
	_kill_active_tween()
	mesh_root.rotation = base_rotation
	active_tween = create_tween()
	active_tween.tween_property(mesh_root, "rotation:x", base_rotation.x - deg_to_rad(POUR_ANGLE_DEGREES), POUR_OUT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.tween_interval(POUR_HOLD_DURATION)
	active_tween.tween_property(mesh_root, "rotation:x", base_rotation.x, POUR_RETURN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _kill_active_tween() -> void:
	if active_tween:
		active_tween.kill()
		active_tween = null
