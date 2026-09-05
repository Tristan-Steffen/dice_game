class_name LightSparkView
extends Node3D
## EIN LICHTFUNKE des DURCHLICHTS (Welle X, 2026-09-05): oben am Turm zerfällt das
## Licht-Netz in bis zu sechs davon, und sie schlagen ALLE ZUGLEICH in die
## Seitenmitten des Zielwürfels ein.
##
## Ein additives Billboard-Quad mit weichem Kern - kein Körper, keine Kollision.
## fly_to ist ein flacher Bogen: XZ gerade, Y als Parabel ÜBER der Sehne, unter sie
## kommt er nie.

## Kantenlänge des Funkens als Vielfaches einer Würfelfläche.
const SIZE_SHARE := 0.7
const CORE_ALPHA := 0.95
const GLOW_ENERGY := 3.2
## Die Textur des weichen Kerns (ein radialer Verlauf, einmal gebacken).
const TEXTURE_PX := 64

var _quad: MeshInstance3D
var _material: StandardMaterial3D
var _fly: Tween
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _hump := 0.0

static var _core_texture: GradientTexture2D

func _init() -> void:
	name = "LightSpark"

## Kantenlänge eines Funkens in Welt.
static func spark_size() -> float:
	return DieBuilder.FACE_SIZE * DiceTrayView.DIE_SCALE * SIZE_SHARE

## Einziger Eingang: der Ton der Serie.
func setup(tint: Color) -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material.no_depth_test = true  # ein Funke liest immer, auch über einer Karte
	_material.render_priority = DataCellView.PRIORITY_BADGE
	_material.albedo_color = Color(tint.r * GLOW_ENERGY, tint.g * GLOW_ENERGY,
		tint.b * GLOW_ENERGY, CORE_ALPHA)
	_material.albedo_texture = _core()
	_quad = MeshInstance3D.new()
	_quad.name = "Core"
	var quad := QuadMesh.new()
	var side := spark_size()
	quad.size = Vector2(side, side)
	_quad.mesh = quad
	_quad.material_override = _material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_quad)

## HART auf einen Platz - jede laufende Fahrt stirbt dabei.
func seat_at(at: Vector3) -> void:
	_kill(_fly)
	global_position = at

## DER FLUG: flacher Bogen auf die Seitenmitte des Würfels. Endzustand zuerst -
## time <= 0 setzt ihn sofort ans Ziel. Liefert die Fahrt (null = keine).
func fly_to(target: Vector3, time: float, peak: float) -> Tween:
	_kill(_fly)
	_from = global_position
	_to = target
	var chord := (_from.y + target.y) * 0.5
	_hump = maxf(maxf(_from.y, target.y) + maxf(peak, 0.0) - chord, 0.0)
	if time <= 0.0:
		global_position = target
		return null
	_fly = create_tween()
	_fly.tween_method(_set_share, 0.0, 1.0, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fly.tween_callback(func() -> void: global_position = _to)
	return _fly

func flying() -> bool:
	return _fly != null and _fly.is_valid()

## Der EINE Aufräum-Pfad: die Fahrt stirbt, der Funke steht auf seinem Ziel.
func settle() -> void:
	_kill(_fly)
	if _to != Vector3.ZERO:
		global_position = _to

func _set_share(share: float) -> void:
	var seat := _from.lerp(_to, share)
	seat.y += 4.0 * _hump * share * (1.0 - share)
	global_position = seat

## Der weiche Kern: EINE geteilte Textur - sechs Funken sind dasselbe Licht.
static func _core() -> Texture2D:
	if _core_texture != null:
		return _core_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55),
		Color(1, 1, 1, 0)])
	_core_texture = GradientTexture2D.new()
	_core_texture.gradient = gradient
	_core_texture.fill = GradientTexture2D.FILL_RADIAL
	_core_texture.fill_from = Vector2(0.5, 0.5)
	_core_texture.fill_to = Vector2(1.0, 0.5)
	_core_texture.width = TEXTURE_PX
	_core_texture.height = TEXTURE_PX
	return _core_texture

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
