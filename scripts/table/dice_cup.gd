class_name DiceCup
extends Node3D
## Würfelbecher: rein visuelles Requisit (siehe scenes/dice_cup.tscn). Bietet
## nur die eigenen Animationen (Schütteln, Werfen) und die Mündungsposition an;
## welche Würfel wann hinein-/herausfliegen, orchestriert scene_root.
## Bewegt wird nur $MeshRoot - der feste Stellplatz am Grubenrand bleibt.

const MOUTH_LOCAL_HEIGHT := 2.0  # etwas unterhalb des oberen Rands

## Kollisions-Ebene fürs Anklicken des Bechers (Klick = Würfeln-Button).
const CLICK_LAYER := 32

const SHAKE_ANGLE_DEGREES := 9.0
const SHAKE_STEP_DURATION := 0.11
const SHAKE_DIP := 0.6  # Becher senkt sich beim Schütteln leicht ab

## Wurfbewegung: Ausholen (zurück/hoch), Schwung Richtung Grube (lokale
## Koordinaten; die Grube liegt in -Z/+X vom Becher aus), Zurückschwingen.
const THROW_WINDUP_OFFSET := Vector3(-1.0, 0.6, 1.4)
const THROW_WINDUP_TILT_DEGREES := 20.0
const THROW_WINDUP_DURATION := 0.14

## Deutlicher Schwung samt Anheben (+Y), damit der Becher über der Silhouette
## des Grubenrands bleibt; die echten Würfel starten an der Mündung.
const THROW_SWING_OFFSET := Vector3(3.0, 6.0, -12.0)
const THROW_SWING_TILT_DEGREES := 95.0
const THROW_SWING_DURATION := 0.24

const THROW_RETURN_DURATION := 0.45

## Feuert im Tiefpunkt des Wurfschwungs - scene_root lässt genau dann die
## Fake-Würfel verschwinden und wirft die echten ab der Mündung los.
signal poured_out

@onready var mesh_root: Node3D = $MeshRoot

var base_rotation: Vector3
var active_tween: Tween

func _ready() -> void:
	base_rotation = mesh_root.rotation

## Weltposition knapp über der Öffnung - Flugziel hineinfliegender Würfel und
## Startpunkt der echten Wurf-Würfel. Nutzt mesh_root, damit die Position der
## tatsächlich bewegten, gekippten Öffnung folgt.
func mouth_position() -> Vector3:
	return mesh_root.global_transform * Vector3(0, MOUTH_LOCAL_HEIGHT, 0)

## Rüttelt count-mal und kehrt zur Ausgangslage zurück; liefert den Tween.
func play_shake(count: int) -> Tween:
	_kill_active_tween()
	mesh_root.rotation = base_rotation
	mesh_root.position = Vector3.ZERO
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Senkt sich zu Beginn leicht ab, schüttelt unten und hebt sich am Ende wieder.
	active_tween.tween_property(mesh_root, "position:y", -SHAKE_DIP, SHAKE_STEP_DURATION)
	for i in count:
		active_tween.tween_property(mesh_root, "rotation:z", base_rotation.z + deg_to_rad(SHAKE_ANGLE_DEGREES), SHAKE_STEP_DURATION)
		active_tween.tween_property(mesh_root, "rotation:z", base_rotation.z - deg_to_rad(SHAKE_ANGLE_DEGREES), SHAKE_STEP_DURATION)
	active_tween.tween_property(mesh_root, "rotation:z", base_rotation.z, SHAKE_STEP_DURATION * 0.5)
	active_tween.parallel().tween_property(mesh_root, "position:y", 0.0, SHAKE_STEP_DURATION * 0.5)
	return active_tween

## Schwingt den Becher durch den Raum Richtung Grube und zurück; poured_out
## feuert exakt am Tiefpunkt (synchronisiert den echten Würfel-Wurf).
func play_throw() -> Tween:
	_kill_active_tween()
	mesh_root.position = Vector3.ZERO
	mesh_root.rotation = base_rotation
	active_tween = create_tween()

	active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(mesh_root, "position", THROW_WINDUP_OFFSET, THROW_WINDUP_DURATION)
	active_tween.parallel().tween_property(mesh_root, "rotation:x", base_rotation.x + deg_to_rad(THROW_WINDUP_TILT_DEGREES), THROW_WINDUP_DURATION)

	active_tween.tween_property(mesh_root, "position", THROW_SWING_OFFSET, THROW_SWING_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	active_tween.parallel().tween_property(mesh_root, "rotation:x", base_rotation.x - deg_to_rad(THROW_SWING_TILT_DEGREES), THROW_SWING_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	active_tween.tween_callback(poured_out.emit)

	active_tween.tween_property(mesh_root, "position", Vector3.ZERO, THROW_RETURN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(mesh_root, "rotation", base_rotation, THROW_RETURN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return active_tween

func _kill_active_tween() -> void:
	if active_tween:
		active_tween.kill()
		active_tween = null
