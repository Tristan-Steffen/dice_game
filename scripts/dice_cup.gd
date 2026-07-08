class_name DiceCup
extends Node3D
## Würfelbecher: rein visuelles Requisit aus Godot-Primitiven (Kegelstumpf-
## Rumpf + Rand, siehe scenes/dice_cup.tscn - kein importiertes Modell). Bietet
## nur die becher-eigenen Animationen (Schütteln, Werfen) und seine
## Mündungsposition an; welche Würfel wann hinein-/herausfliegen, orchestriert
## scene_root.gd (siehe _play_cup_roll/_on_throw_button_pressed).
##
## Bewegt wird nur $MeshRoot, nicht der Node selbst - so bleibt die eigene
## Position/Transform (der feste Stellplatz am Grubenrand) unverändert, auch
## während der Becher sich beim Werfen sichtbar durch den Raum schwingt.

const MOUTH_LOCAL_HEIGHT := 2.0  # etwas unterhalb des oberen Rands, siehe dice_cup.tscn

## Eigene Kollisions-Ebene fürs Anklicken des Bechers (siehe ClickZone in
## dice_cup.tscn) - scene_root.gd nutzt sie, um einen Klick auf den Becher wie
## den Würfeln-/Neu-würfeln-Button zu behandeln (siehe _try_cup_click).
const CLICK_LAYER := 32

const SHAKE_ANGLE_DEGREES := 9.0
const SHAKE_STEP_DURATION := 0.11

## Wurfbewegung: statt nur in Ruhestellung zu kippen, schwingt der Becher
## tatsächlich durch den Raum - Ausholen (leicht zurück/hoch), Schwung
## Richtung Grube (siehe THROW_SWING_OFFSET, in lokalen Koordinaten - Welt-X
## zeigt bildschirm-aufwärts, Welt-Z bildschirm-rechts, siehe CameraRig.
## ZOOM_BASIS; die Grube liegt also in -Z/+X-Richtung vom Becher aus) und
## Zurückschwingen in die Ruheposition. poured_out feuert am Tiefpunkt des
## Schwungs, wenn die Mündung am weitesten zur Grube zeigt.
const THROW_WINDUP_OFFSET := Vector3(-1.0, 0.6, 1.4)
const THROW_WINDUP_TILT_DEGREES := 20.0
const THROW_WINDUP_DURATION := 0.14

## Schwingt den Becher wirklich deutlich Richtung Grube (nicht nur ein
## kleiner Schwenk) - die echten Wurf-Würfel starten ab jetzt exakt an der
## Mündung (siehe scene_root.gd: _throw_start_positions), sollen also flach
## und aus Becher-Nähe in die Grube rollen statt aus großer Höhe zu fallen.
## Kräftiges Anheben (+Y) hält den Becher dabei klar über der Silhouette des
## Grubenrands, der Requisiten auf Tischhöhe schon ab knapp unter Z=19
## relativ zur Becher-Ruheposition (Z=20, siehe scene_root.tscn) verdeckt.
const THROW_SWING_OFFSET := Vector3(3.0, 6.0, -12.0)
const THROW_SWING_TILT_DEGREES := 95.0
const THROW_SWING_DURATION := 0.24

const THROW_RETURN_DURATION := 0.45

## Gefeuert während play_throw(), genau im Tiefpunkt des Wurfschwungs (Becher
## am weitesten zur Grube geschwungen und gekippt) - scene_root.gd wartet
## darauf, um genau dann die Fake-Würfel im Becher verschwinden zu lassen und
## die echten Wurf-Würfel an der jetzt aktuellen Mündungsposition
## loszuwerfen (siehe _on_throw_button_pressed/mouth_position), sodass sie
## sichtbar aus dem Becher heraus in die Grube rollen statt zu teleportieren.
signal poured_out

@onready var mesh_root: Node3D = $MeshRoot

var base_rotation: Vector3
var active_tween: Tween

func _ready() -> void:
	base_rotation = mesh_root.rotation

## Weltposition knapp über der Becheröffnung - Flugziel für hineinfliegende
## Würfel (siehe scene_root.gd: _play_cup_roll) UND Startpunkt der echten
## Wurf-Würfel im Moment von poured_out (siehe scene_root.gd:
## _throw_start_positions) - die Würfel sollen nie teleportieren, sondern
## immer sichtbar aus dieser Position heraus starten. Nutzt mesh_root statt
## der eigenen Transform, damit die Position auch während der Wurf-Animation
## korrekt der tatsächlich sichtbaren (bewegten, gekippten) Öffnung folgt.
func mouth_position() -> Vector3:
	return mesh_root.global_transform * Vector3(0, MOUTH_LOCAL_HEIGHT, 0)

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

## Wirft den Becher tatsächlich durch den Raum Richtung Grube (siehe
## THROW_WINDUP_OFFSET/THROW_SWING_OFFSET) statt nur auf der Stelle zu kippen,
## und schwingt danach zurück in die Ruheposition. poured_out feuert exakt am
## Tiefpunkt des Schwungs (siehe scene_root.gd: dort synchronisiert das den
## echten Würfel-Wurf mit der sichtbaren Wurfbewegung).
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
