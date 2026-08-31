extends GutTest
## Der schwebende Würfel (FloatingDie): der ECHTE Würfel im Stasis-Feld, wie er
## am Werkstück der Gravur-Station und an den Paket-Würfeln über der Werkbank
## steht. Er wippt über seiner Station, und gezeigt wird direkt auf ihn.

const HOVER := DiceTrayView.FLOAT_HEIGHT
const TARGET := Vector3(4, HOVER, -3)

var stage: FloatingDie
var camera: Camera3D

func before_each() -> void:
	stage = FloatingDie.new()
	add_child_autofree(stage)
	stage.setup(_die(), Color(1, 0.7, 0.2), Vector3(0, HOVER, 10))
	camera = Camera3D.new()
	add_child_autofree(camera)

func _die() -> DieDefinition:
	var def := DieDefinition.new()
	var faces: Array[int] = [1, 2, 3, 4, 5, 6]
	def.faces = faces
	return def

## Kamera frontal auf den gelandeten Würfel.
func _look_at_stage() -> void:
	camera.global_position = TARGET + Vector3(0, 0, 8)
	camera.look_at(TARGET, Vector3.UP)

func test_the_station_stands_on_the_surface_under_the_die() -> void:
	stage.land_at(TARGET, 0.0)
	assert_almost_eq(stage.die.global_position, TARGET, Vector3.ONE * 0.001)
	assert_almost_eq(stage.emitter.global_position, Vector3(TARGET.x, 0.0, TARGET.z),
		Vector3.ONE * 0.001, "die Station steht senkrecht darunter auf der Fläche")
	assert_eq(float(stage.emitter.beam_material.get_shader_parameter("engaged")), 1.0,
		"gelandet trägt das Feld")

func test_the_die_bobs_around_its_resting_height() -> void:
	stage.land_at(TARGET, 0.0)
	stage._process(0.4)
	var lifted := stage.die.global_position.y
	assert_ne(lifted, TARGET.y, "der Würfel wippt")
	assert_lt(absf(lifted - TARGET.y), DiceTrayView.BOB_AMPLITUDE + 0.001,
		"und zwar nur um die Wipp-Weite")
	assert_eq(stage.rest_y, TARGET.y, "die Ruhelage bleibt der Landepunkt")

func test_the_field_works_harder_while_the_die_sinks() -> void:
	stage.land_at(TARGET, 0.0)
	stage._process(PI * 1.5 / DiceTrayView.BOB_SPEED)  # Wipp-Phase unten
	assert_lt(stage.die.global_position.y, TARGET.y, "der Würfel steht unten")
	assert_gt(float(stage.emitter.beam_material.get_shader_parameter("load")), 1.0,
		"und die Station arbeitet härter")

func test_the_pointer_hits_the_die_but_not_beside_it() -> void:
	stage.land_at(TARGET, 0.0)
	_look_at_stage()
	await wait_frames(2)
	var center := camera.unproject_position(stage.center())
	assert_gt(stage.screen_half(camera), 0.0, "der Würfel steht im Bild")
	assert_true(stage.under(camera, center))
	assert_false(stage.under(camera, center + Vector2(stage.pick_radius(camera) * 2.0, 0)))

func test_the_pick_names_face_frame_or_nothing() -> void:
	stage.land_at(TARGET, 0.0)
	_look_at_stage()
	await wait_frames(2)
	var center := camera.unproject_position(stage.center())
	assert_gte(stage.pick(camera, center), 0, "in der Seitenmitte liegt eine Seite")
	var corner := camera.unproject_position(
		stage.faces.global_transform * (Vector3(1, 0, 1) * DieBuilder.HALF_EXTENT))
	assert_eq(stage.pick(camera, corner), FloatingDie.PICK_FRAME, "an der Kante der Rahmen")
	assert_eq(stage.pick(camera, center + Vector2(4000, 0)), FloatingDie.PICK_NONE)

## Abtreten: ein Paket nimmt das Fenster, die Zwinge macht Platz. Sie wird NICHT
## freigegeben - derselbe Körper steht später wieder auf -, ist aber für jedes
## Zeigen taub, solange sie unsichtbar ist.
func test_a_die_that_stepped_aside_is_under_no_pointer() -> void:
	stage.land_at(TARGET, 0.0)
	_look_at_stage()
	await wait_frames(2)
	var center := camera.unproject_position(stage.center())
	assert_true(stage.under(camera, center), "sichtbar liegt er unter dem Zeiger")
	stage.dematerialize()
	stage.visible = false  # das Ende des Schrumpfens, ohne auf den Tween zu warten
	assert_false(stage.under(camera, center), "abgetreten trifft ihn nichts mehr")
	assert_true(is_instance_valid(stage.die), "und freigegeben wurde er nicht")

func test_materializing_brings_the_same_body_back() -> void:
	stage.land_at(TARGET, 0.0)
	stage.dematerialize()
	stage.visible = false
	var body := stage.die
	stage.materialize()
	assert_true(stage.visible, "er steht wieder da")
	assert_same(stage.die, body, "und zwar als derselbe Körper")
