class_name CameraRig
extends Camera3D
## Spielkamera: feste Übersicht mit begrenztem Maus-Rundschauen plus
## Zoom-Ziele (Grube/Trays/Kombis/Charms/Hub). Linksklick auf eine Zone
## zoomt heran, Rechtsklick zurück; auch im Zoom bleibt leichtes Rundschauen.

enum Mode { OVERVIEW, PIT, POOL, DISCARD, COMBOS, CHARMS, HUB }

signal mode_changed(new_mode: Mode)

const TILT_MAX_UP_DEGREES := 5.0
const TILT_MAX_DOWN_DEGREES := 5.0
const TILT_MAX_YAW_DEGREES := 5.0
# Im Zoom bewusst kleine Winkel, damit das Ziel im Blick bleibt.
const ZOOM_TILT_MAX_PITCH_DEGREES := 5.0
const ZOOM_TILT_MAX_YAW_DEGREES := 16.0
const TILT_SMOOTHING := 6.0
const ZOOM_DURATION := 0.6

## Nach dem Freigeben einer Tilt-Sperre: erst TILT_RESUME_HOLD stehen bleiben,
## dann über TILT_RESUME_EASE sanft wieder einblenden - kein harter Sprung.
const TILT_RESUME_HOLD := 0.5
const TILT_RESUME_EASE := 0.5

## EINE Zoom-Distanz für alle Ziele: zusammen mit ZOOM_BASIS steht die Kamera
## bei jedem Zoom in derselben Höhe und im selben Winkel, nur das Ziel wandert.
const ZOOM_DISTANCE := 20.0

## Zoom-Blickpunkte - nur Rückfallwerte: scene_root überschreibt sie aus den
## echten Weltpositionen (configure_*_target), damit Editor-Verschiebungen den
## Zoom automatisch mitnehmen.
var pool_target := Vector3(-23.75, 0.4, 12)
var discard_target := Vector3(-26, 0.4, -12)
var combos_target := Vector3(-8, 0, 0)
var pit_target := Vector3.ZERO
var charms_target := Vector3(24, 0, 0)
var hub_target := Vector3(-24, 0, 0)

## Feste, steile Draufsicht für ALLE Zoom-Ziele, unabhängig von der flacheren
## Übersichts-Kamera (Basis-Achsen als Spalten!).
const ZOOM_BASIS := Basis(
	Vector3(-4.371139e-08, 0.0, 1.0),
	Vector3(0.9659258, 0.25881907, 4.222196e-08),
	Vector3(-0.25881907, 0.9659258, -1.1313341e-08)
)
const ZOOM_FORWARD := Vector3(0.25881907, -0.9659258, 1.1313341e-08)  # = -ZOOM_BASIS.z

var base_basis: Basis
var base_origin: Vector3

# Ruhelage des aktuellen Modus, um die das Rundschauen pendelt.
var anchor_basis: Basis
var anchor_origin: Vector3

var mode: Mode = Mode.OVERVIEW
var is_animating: bool = false
## Solange gesetzt, hält die Kamera ihre Ausrichtung (z.B. während der Spieler
## die Würfel-Projektion dreht), damit die Geste nicht zugleich den Blick schwenkt.
var tilt_locked: bool = false
var tilt_offset := Vector2.ZERO  # geglättete Blickabweichung (Grad: x=Pitch, y=Yaw)
## Nachlauf nach dem Entsperren: Zeit seit Freigabe (< 0 = kein Nachlauf).
var _tilt_resume_time := -1.0
var _frozen_offset := Vector2.ZERO
## Zuletzt TATSÄCHLICH angewandte Abweichung - beim erneuten Sperren muss von
## hier eingefroren werden, nicht vom vorgelaufenen tilt_offset (sonst Sprung).
var _applied_offset := Vector2.ZERO

var active_tween: Tween

func _ready() -> void:
	base_basis = global_transform.basis
	base_origin = global_transform.origin
	anchor_basis = base_basis
	anchor_origin = base_origin

func _process(delta: float) -> void:
	if is_animating or tilt_locked:
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
		# ny > 0 = Maus unten -> Blick Richtung Tisch (eigener Winkelbereich).
		pitch_max = TILT_MAX_DOWN_DEGREES if ny > 0.0 else TILT_MAX_UP_DEGREES
		yaw_max = TILT_MAX_YAW_DEGREES
	else:
		pitch_max = ZOOM_TILT_MAX_PITCH_DEGREES
		yaw_max = ZOOM_TILT_MAX_YAW_DEGREES
	var target_tilt := Vector2(-ny * pitch_max, -nx * yaw_max)
	tilt_offset = tilt_offset.lerp(target_tilt, clamp(delta * TILT_SMOOTHING, 0.0, 1.0))

	# Im Nachlauf vom eingefrorenen Blick sanft auf das lebende Rundschauen
	# blenden: halten (gain 0), dann weich einblenden (gain 0->1).
	var applied := tilt_offset
	if _tilt_resume_time >= 0.0:
		_tilt_resume_time += delta
		var gain: float
		if _tilt_resume_time <= TILT_RESUME_HOLD:
			gain = 0.0
		elif _tilt_resume_time >= TILT_RESUME_HOLD + TILT_RESUME_EASE:
			gain = 1.0
			_tilt_resume_time = -1.0
		else:
			gain = smoothstep(0.0, 1.0, (_tilt_resume_time - TILT_RESUME_HOLD) / TILT_RESUME_EASE)
		applied = _frozen_offset.lerp(tilt_offset, gain)

	_applied_offset = applied
	var yaw := Basis(anchor_basis.y, deg_to_rad(applied.y))
	var pitch := Basis(anchor_basis.x, deg_to_rad(applied.x))
	global_transform = Transform3D(yaw * pitch * anchor_basis, anchor_origin)

## Sperrt/entsperrt das Maus-Rundschauen; das Entsperren startet den Nachlauf.
func set_tilt_locked(locked: bool) -> void:
	if locked:
		tilt_locked = true
		_tilt_resume_time = -1.0
	elif tilt_locked:
		tilt_locked = false
		_frozen_offset = _applied_offset
		_tilt_resume_time = 0.0

## Hebt eine Sperre SOFORT und ohne Nachlauf auf (Sicherheitsnetz beim
## Schließen der Gravur-Station).
func release_tilt_immediately() -> void:
	tilt_locked = false
	_tilt_resume_time = -1.0

## Tray-Blickpunkte aus den echten Weltpositionen (Editor bleibt die Quelle).
func configure_tray_targets(pool: Vector3, discard: Vector3) -> void:
	pool_target = pool
	discard_target = discard

func configure_combos_target(target: Vector3) -> void:
	combos_target = target

func configure_pit_target(target: Vector3) -> void:
	pit_target = target

func configure_charms_target(target: Vector3) -> void:
	charms_target = target

func configure_hub_target(target: Vector3) -> void:
	hub_target = target

## Fährt zum Zoom-Ziel; No-Op, wenn schon dort.
func zoom_to(target_mode: Mode) -> void:
	if mode == target_mode:
		return
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

## Zurück zur Übersicht; No-Op, falls bereits dort.
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
