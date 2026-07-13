class_name CameraRig
extends Camera3D
## Spielkamera: feste Übersichtsposition mit leicht begrenztem Rundschauen
## per Maus (nur Blickrichtung, keine Bewegung über die Karte hinweg), plus
## drei Zoom-Ziele (Würfelgrube, Pool-Tray, Ablage-Tray). Ein Linksklick auf
## eines dieser Ziele fährt die Kamera näher heran; ein Rechtsklick springt
## zur Übersicht zurück. Während eines Zooms ist das Rundschauen gesperrt -
## die Kamera bleibt exakt auf das jeweilige Ziel ausgerichtet.

enum Mode { OVERVIEW, PIT, POOL, DISCARD }

## Wird ausgelöst, sobald sich der Modus ändert (zoom_to/zoom_out) - dient
## z.B. dazu, die Spiel-UI nur einzublenden, wenn die Grube fokussiert ist.
signal mode_changed(new_mode: Mode)

const TILT_MAX_UP_DEGREES := 10.0  # Freiheit nach oben (von der Übersicht aus)
const TILT_MAX_DOWN_DEGREES := 30.0  # Freiheit nach unten, Richtung Tisch/Grube
const TILT_MAX_YAW_DEGREES := 30.0
const TILT_SMOOTHING := 6.0
const ZOOM_DURATION := 0.6

const TRAY_ZOOM_DISTANCE := 15.0
const POOL_ZOOM_DISTANCE := 16.5  # Pool- + Warteschlangen-Tray zusammen sind breiter als ein einzelnes Tray

const POOL_TARGET := Vector3(-23.75, -3, 12)  # Mittelpunkt zwischen PoolTrayView und QueueTrayView, siehe scene_root.tscn
const DISCARD_TARGET := Vector3(-26, -3, -12)

## Grubenzoom als exakte Referenz-Kamera: Position + Ausrichtung wurden im
## Editor eingerichtet (eine testweise platzierte Camera3D) und hier
## eingefroren, statt wie bei Pool/Ablage aus Ziel+Distanz+ZOOM_BASIS
## abgeleitet zu werden. Ergibt einen flacheren, weiter zurückgesetzten Blick
## auf die Grube. Beim Aktualisieren einfach die neue Test-Kamera speichern und
## ihre Transform3D-Zahlen hier übertragen (Basis-Achsen als Spalten der
## Transform3D-Liste, siehe ZOOM_BASIS).
const PIT_ZOOM_ORIGIN := Vector3(-17.284252, 21.13977, 0)
const PIT_ZOOM_BASIS := Basis(
	Vector3(-3.344888e-08, 2.8139967e-08, 1),
	Vector3(0.79413176, 0.6077457, 9.4608765e-09),
	Vector3(-0.6077457, 0.79413176, -4.2675254e-08)
)

## Feste, steile Draufsicht für die Zoom-Ziele (Grube/Trays) - unabhängig von
## der frei im Editor einstellbaren (jetzt flacheren) Übersichts-Kamera, damit
## Grube und Trays beim Heranzoomen immer aus derselben Vogelperspektive
## gezeigt werden. Entspricht der ursprünglichen Übersichts-Ausrichtung
## (Basis-Achsen als Spalten, nicht als Zeilen der Transform3D-Zahlenliste!).
const ZOOM_BASIS := Basis(
	Vector3(-4.371139e-08, 0.0, 1.0),
	Vector3(0.9659258, 0.25881907, 4.222196e-08),
	Vector3(-0.25881907, 0.9659258, -1.1313341e-08)
)
const ZOOM_FORWARD := Vector3(0.25881907, -0.9659258, 1.1313341e-08)  # = -ZOOM_BASIS.z

var base_basis: Basis
var base_origin: Vector3

var mode: Mode = Mode.OVERVIEW
var is_animating: bool = false
var tilt_offset := Vector2.ZERO  # aktuelle geglättete Blickabweichung (Grad: x=Pitch, y=Yaw)

var active_tween: Tween

func _ready() -> void:
	base_basis = global_transform.basis
	base_origin = global_transform.origin

func _process(delta: float) -> void:
	if mode != Mode.OVERVIEW or is_animating:
		return

	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	var mouse := get_viewport().get_mouse_position()
	var nx: float = clamp((mouse.x / vp_size.x) * 2.0 - 1.0, -1.0, 1.0)
	var ny: float = clamp((mouse.y / vp_size.y) * 2.0 - 1.0, -1.0, 1.0)

	# ny > 0 heißt Maus in der unteren Bildhälfte -> Blick nach unten Richtung
	# Tisch; dafür steht ein größerer Winkelbereich zur Verfügung als nach oben.
	var pitch_max: float = TILT_MAX_DOWN_DEGREES if ny > 0.0 else TILT_MAX_UP_DEGREES
	var target_tilt := Vector2(-ny * pitch_max, -nx * TILT_MAX_YAW_DEGREES)
	tilt_offset = tilt_offset.lerp(target_tilt, clamp(delta * TILT_SMOOTHING, 0.0, 1.0))

	var yaw := Basis(base_basis.y, deg_to_rad(tilt_offset.y))
	var pitch := Basis(base_basis.x, deg_to_rad(tilt_offset.x))
	global_transform = Transform3D(yaw * pitch * base_basis, base_origin)

## Fährt die Kamera zum angegebenen Zoom-Ziel. Erneuter Aufruf mit demselben
## Modus tut nichts (schon dort).
func zoom_to(target_mode: Mode) -> void:
	if mode == target_mode:
		return
	# Die Grube nutzt eine fest eingerichtete Referenz-Kamera (PIT_ZOOM_*), die
	# Trays werden weiterhin aus Ziel+Distanz entlang ZOOM_FORWARD mit der
	# gemeinsamen ZOOM_BASIS abgeleitet.
	var target_origin: Vector3
	var target_basis := ZOOM_BASIS
	match target_mode:
		Mode.PIT:
			target_origin = PIT_ZOOM_ORIGIN
			target_basis = PIT_ZOOM_BASIS
		Mode.POOL:
			target_origin = POOL_TARGET - ZOOM_FORWARD * POOL_ZOOM_DISTANCE
		Mode.DISCARD:
			target_origin = DISCARD_TARGET - ZOOM_FORWARD * TRAY_ZOOM_DISTANCE
		_:
			return
	mode = target_mode
	mode_changed.emit(mode)
	_animate_to(target_origin, target_basis)

## Springt zurück zur Übersicht (No-Op, falls bereits dort).
func zoom_out() -> void:
	if mode == Mode.OVERVIEW:
		return
	mode = Mode.OVERVIEW
	mode_changed.emit(mode)
	tilt_offset = Vector2.ZERO
	_animate_to(base_origin, base_basis)

func _animate_to(target_origin: Vector3, target_basis: Basis) -> void:
	if active_tween:
		active_tween.kill()
	is_animating = true

	var from_basis := global_transform.basis
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_tween.set_parallel(true)
	active_tween.tween_property(self, "global_position", target_origin, ZOOM_DURATION)
	active_tween.tween_method(_apply_basis_slerp.bind(from_basis, target_basis), 0.0, 1.0, ZOOM_DURATION)
	active_tween.chain().tween_callback(func() -> void: is_animating = false)

func _apply_basis_slerp(t: float, from_basis: Basis, to_basis: Basis) -> void:
	global_transform.basis = from_basis.slerp(to_basis, t)
