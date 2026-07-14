class_name CameraRig
extends Camera3D
## Spielkamera: feste Übersichtsposition mit leicht begrenztem Rundschauen
## per Maus (nur Blickrichtung, keine Bewegung über die Karte hinweg), plus
## drei Zoom-Ziele (Würfelgrube, Pool-Tray, Ablage-Tray). Ein Linksklick auf
## eines dieser Ziele fährt die Kamera näher heran; ein Rechtsklick springt
## zur Übersicht zurück. Auch im Zoom bleibt ein leichtes Rundschauen möglich -
## mit deutlich kleinerem Winkelbereich, damit das Ziel im Blick bleibt.

enum Mode { OVERVIEW, PIT, POOL, DISCARD, COMBOS, CHARMS, HUB }

## Wird ausgelöst, sobald sich der Modus ändert (zoom_to/zoom_out) - dient
## z.B. dazu, die Spiel-UI nur einzublenden, wenn die Grube fokussiert ist.
signal mode_changed(new_mode: Mode)

const TILT_MAX_UP_DEGREES := 5.0  # Freiheit nach oben (von der Übersicht aus)
const TILT_MAX_DOWN_DEGREES := 5.0  # Freiheit nach unten, Richtung Tisch/Grube
const TILT_MAX_YAW_DEGREES := 5.0
# Leichtes Rundschauen im Zoom: bewusst kleine Winkel, damit die Kamera nah
# an der eingerichteten Ziel-Ausrichtung bleibt.
const ZOOM_TILT_MAX_PITCH_DEGREES := 5.0
const ZOOM_TILT_MAX_YAW_DEGREES := 16.0
const TILT_SMOOTHING := 6.0
const ZOOM_DURATION := 0.6

## EINE gemeinsame Zoom-Distanz für ALLE Ziele - zusammen mit der gemeinsamen
## ZOOM_BASIS steht die Kamera damit bei jedem Zoom in derselben Höhe und im
## selben Winkel über ihrem Ziel (nur der Zielpunkt wandert). Breite Ziele wie
## die Charm-Reihe zeigen dann ihre Mitte; der Rest lässt sich per leichtem
## Rundschauen (ZOOM_TILT_MAX_*) einsehen.
const ZOOM_DISTANCE := 20.0

## Zoom-Blickpunkte. Nur Rückfall-Standardwerte: scene_root überschreibt sie in
## _ready aus den echten Weltpositionen (siehe configure_*_target), damit ein
## Verschieben im Editor den Zoom automatisch mitnimmt, ohne die Koordinaten
## doppelt zu pflegen. ALLE Zoom-Ziele nutzen dieselbe Ausrichtung ZOOM_BASIS
## (Ablage-Winkel) - nur Ziel + Distanz unterscheiden sich.
var pool_target := Vector3(-23.75, 0.4, 12)  # Mittelpunkt zwischen PoolTrayView und QueueTrayView
var discard_target := Vector3(-26, 0.4, -12)  # DiscardTrayView
var combos_target := Vector3(-8, 0, 0)  # Kombi-Cluster auf dem Tisch-Display
var pit_target := Vector3.ZERO  # Grubenmitte (DicePit.PIT_CENTER)
var charms_target := Vector3(24, 0, 0)  # Mitte der Charm-Reihe
var hub_target := Vector3(-24, 0, 0)  # Hub-Fläche unter der Grube (siehe HubView)

## Feste, steile Draufsicht für ALLE Zoom-Ziele (Grube/Trays/Kombis/Charms) -
## unabhängig von der frei im Editor einstellbaren (flacheren) Übersichts-Kamera,
## damit alles beim Heranzoomen aus derselben Vogelperspektive gezeigt wird (der
## Blickwinkel der Ablage). Entspricht der ursprünglichen Übersichts-Ausrichtung
## (Basis-Achsen als Spalten, nicht als Zeilen der Transform3D-Zahlenliste!).
const ZOOM_BASIS := Basis(
	Vector3(-4.371139e-08, 0.0, 1.0),
	Vector3(0.9659258, 0.25881907, 4.222196e-08),
	Vector3(-0.25881907, 0.9659258, -1.1313341e-08)
)
const ZOOM_FORWARD := Vector3(0.25881907, -0.9659258, 1.1313341e-08)  # = -ZOOM_BASIS.z

var base_basis: Basis
var base_origin: Vector3

# Ruhelage des aktuellen Modus, um die herum das Rundschauen pendelt: in der
# Übersicht base_basis/base_origin, im Zoom die jeweilige Ziel-Ausrichtung.
var anchor_basis: Basis
var anchor_origin: Vector3

var mode: Mode = Mode.OVERVIEW
var is_animating: bool = false
var tilt_offset := Vector2.ZERO  # aktuelle geglättete Blickabweichung (Grad: x=Pitch, y=Yaw)

var active_tween: Tween

func _ready() -> void:
	base_basis = global_transform.basis
	base_origin = global_transform.origin
	anchor_basis = base_basis
	anchor_origin = base_origin

func _process(delta: float) -> void:
	if is_animating:
		return

	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	var mouse := get_viewport().get_mouse_position()
	var nx: float = clamp((mouse.x / vp_size.x) * 2.0 - 1.0, -1.0, 1.0)
	var ny: float = clamp((mouse.y / vp_size.y) * 2.0 - 1.0, -1.0, 1.0)

	var pitch_max: float
	var yaw_max: float
	if mode == Mode.OVERVIEW:
		# ny > 0 heißt Maus in der unteren Bildhälfte -> Blick nach unten Richtung
		# Tisch; dafür steht ein größerer Winkelbereich zur Verfügung als nach oben.
		pitch_max = TILT_MAX_DOWN_DEGREES if ny > 0.0 else TILT_MAX_UP_DEGREES
		yaw_max = TILT_MAX_YAW_DEGREES
	else:
		pitch_max = ZOOM_TILT_MAX_PITCH_DEGREES
		yaw_max = ZOOM_TILT_MAX_YAW_DEGREES
	var target_tilt := Vector2(-ny * pitch_max, -nx * yaw_max)
	tilt_offset = tilt_offset.lerp(target_tilt, clamp(delta * TILT_SMOOTHING, 0.0, 1.0))

	var yaw := Basis(anchor_basis.y, deg_to_rad(tilt_offset.y))
	var pitch := Basis(anchor_basis.x, deg_to_rad(tilt_offset.x))
	global_transform = Transform3D(yaw * pitch * anchor_basis, anchor_origin)

## Setzt die Zoom-Blickpunkte der beiden Trays aus deren echten Weltpositionen
## (siehe scene_root._ready). Dadurch folgt der Tray-Zoom automatisch, wenn die
## Trays im Editor verschoben werden - die Koordinaten leben nur an einer Stelle
## (im Szenenbaum), nicht zusätzlich hier als Konstanten.
func configure_tray_targets(pool: Vector3, discard: Vector3) -> void:
	pool_target = pool
	discard_target = discard

## Setzt den Zoom-Blickpunkt des Kombinations-Clusters aus seiner Weltposition
## (siehe scene_root._ready / TableScreen.pixel_to_world) - folgt so automatisch,
## wenn sich der Cluster auf dem Display verschiebt.
func configure_combos_target(target: Vector3) -> void:
	combos_target = target

## Blickpunkt der Grube (siehe scene_root._ready / DicePit.PIT_CENTER).
func configure_pit_target(target: Vector3) -> void:
	pit_target = target

## Blickpunkt der Charm-Reihe (siehe scene_root._ready / CharmRowView-Mitte).
func configure_charms_target(target: Vector3) -> void:
	charms_target = target

## Blickpunkt des Hubs (siehe scene_root._setup_hub_zoom / ScreenAnchors/Hub).
func configure_hub_target(target: Vector3) -> void:
	hub_target = target

## Fährt die Kamera zum angegebenen Zoom-Ziel. Erneuter Aufruf mit demselben
## Modus tut nichts (schon dort).
func zoom_to(target_mode: Mode) -> void:
	if mode == target_mode:
		return
	# ALLE Ziele mit derselben Ausrichtung (ZOOM_BASIS) und derselben Distanz
	# (ZOOM_DISTANCE) entlang ZOOM_FORWARD - gleiche Höhe UND gleicher Winkel
	# überall, nur der Zielpunkt unterscheidet sich.
	var target_point: Vector3
	match target_mode:
		Mode.PIT:
			target_point = pit_target
		Mode.POOL:
			target_point = pool_target
		Mode.DISCARD:
			target_point = discard_target
		Mode.COMBOS:
			target_point = combos_target
		Mode.CHARMS:
			target_point = charms_target
		Mode.HUB:
			target_point = hub_target
		_:
			return
	var target_origin := target_point - ZOOM_FORWARD * ZOOM_DISTANCE
	mode = target_mode
	mode_changed.emit(mode)
	anchor_basis = ZOOM_BASIS
	anchor_origin = target_origin
	tilt_offset = Vector2.ZERO
	_animate_to(target_origin, ZOOM_BASIS)

## Springt zurück zur Übersicht (No-Op, falls bereits dort).
func zoom_out() -> void:
	if mode == Mode.OVERVIEW:
		return
	mode = Mode.OVERVIEW
	mode_changed.emit(mode)
	anchor_basis = base_basis
	anchor_origin = base_origin
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
