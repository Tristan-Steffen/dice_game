class_name StasisEmitter
extends Node3D
## Die Stasis-Station unter einem schwebenden Würfel: Dial-Puck (flache
## Leuchtscheibe) + Iris (Dunkelglas-Port) + Kraftfeld-Säule bis zur Würfel-
## Unterseite. Die Station steht IMMER auf der Tischfläche - nur der Würfel
## schwebt, die Säule trägt ihn. Genutzt von den Trays (je Slot eine) und vom
## Werkstück der Gravur-Station.

const PUCK_SHADER := preload("res://assets/shaders/stasis_puck.gdshader")
const BEAM_SHADER := preload("res://assets/shaders/stasis_beam.gdshader")
const LENS_SHADER := preload("res://assets/shaders/stasis_lens.gdshader")

const PUCK_RADIUS := 0.62
const PUCK_Y := 0.04
## Projektionskegel: schmale Blende unten, öffnet sich nach oben zum Würfel.
const BEAM_BOTTOM_RADIUS := 0.28
const BEAM_TOP_RADIUS := 0.6
## Emitter-Iris (flacher Dunkelglas-Port) - Halbbreite der Scheibe.
const LENS_RADIUS := 0.34
## Last-Puls: der Emitter leuchtet heller, je tiefer der Würfel im Wippen sinkt.
const LOAD_AMOUNT := 0.5
## Einrast-Ripple beim Ablegen (impact 0->1).
const RIPPLE_TIME := 0.5

var puck: MeshInstance3D
var lens: MeshInstance3D
var beam: MeshInstance3D
var puck_material: ShaderMaterial
var lens_material: ShaderMaterial
var beam_material: ShaderMaterial
var _ripple_tween: Tween

var tint := Color(0.15, 0.35, 0.75)

## Baut die Station für einen Würfel, dessen MITTE carry_height über der
## Standfläche schwebt; die_scale ist seine Weltgröße (der Griff-Ring sitzt an
## seiner Unterseite).
func build(carry_height: float, die_scale: float, emitter_tint: Color) -> void:
	tint = emitter_tint
	_build_puck()
	_build_lens()
	_build_beam(carry_height, die_scale)

func _build_puck() -> void:
	puck_material = ShaderMaterial.new()
	puck_material.shader = PUCK_SHADER
	puck_material.set_shader_parameter("tint", tint)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * PUCK_RADIUS * 2.0
	mesh.material = puck_material
	puck = MeshInstance3D.new()
	puck.name = "Puck"
	puck.mesh = mesh
	puck.position = Vector3(0, PUCK_Y, 0)
	add_child(puck)

## Der Dunkelglas-Port, aus dem der Strahl austritt - knapp über dem Puck-Dial.
func _build_lens() -> void:
	lens_material = ShaderMaterial.new()
	lens_material.shader = LENS_SHADER
	lens_material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * LENS_RADIUS * 2.0
	mesh.material = lens_material
	lens = MeshInstance3D.new()
	lens.name = "Lens"
	lens.mesh = mesh
	lens.position = Vector3(0, PUCK_Y + 0.01, 0)
	add_child(lens)

func _build_beam(carry_height: float, die_scale: float) -> void:
	var die_bottom := carry_height - die_scale * DieBuilder.HALF_EXTENT
	beam_material = ShaderMaterial.new()
	beam_material.shader = BEAM_SHADER
	beam_material.set_shader_parameter("beam_height", carry_height)
	beam_material.set_shader_parameter("grip_h", clampf(die_bottom / carry_height, 0.0, 1.0))
	beam_material.set_shader_parameter("beam_color", Vector3(tint.r, tint.g, tint.b))
	var mesh := CylinderMesh.new()
	mesh.top_radius = BEAM_TOP_RADIUS
	mesh.bottom_radius = BEAM_BOTTOM_RADIUS
	mesh.height = carry_height
	mesh.radial_segments = 16
	beam = MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = mesh
	beam.material_override = beam_material
	beam.position = Vector3(0, carry_height * 0.5, 0)
	add_child(beam)

func set_tint(emitter_tint: Color) -> void:
	tint = emitter_tint
	if puck_material == null:
		return
	puck_material.set_shader_parameter("tint", tint)
	lens_material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	beam_material.set_shader_parameter("beam_color", Vector3(tint.r, tint.g, tint.b))

## Trägt die Säule gerade einen Würfel? 0 = Leerlauf-Stummel, 1 = volle Trage-Höhe.
func set_engaged(value: float) -> void:
	if beam_material != null:
		beam_material.set_shader_parameter("engaged", value)

## Last des Feldes (siehe load_for): Säule und Iris pulsen gemeinsam.
func set_load(value: float) -> void:
	if beam_material == null:
		return
	beam_material.set_shader_parameter("load", value)
	lens_material.set_shader_parameter("pulse", value)

## Last aus der Wipp-Phase des Würfels: sinkt er (bob < 0), arbeitet das Feld
## sichtbar härter. Diese Rückkopplung macht Emitter und Würfel zu EINER Maschine.
static func load_for(bob: float) -> float:
	return 1.0 - LOAD_AMOUNT * bob

## Einrast-Ripple (impact läuft 0->1 nach außen).
func ripple() -> void:
	if puck_material == null:
		return
	if _ripple_tween != null and _ripple_tween.is_valid():
		_ripple_tween.kill()
	puck_material.set_shader_parameter("impact", 0.0)
	_ripple_tween = create_tween()
	_ripple_tween.tween_method(
		func(v: float) -> void: puck_material.set_shader_parameter("impact", v),
		0.0, 1.0, RIPPLE_TIME)
