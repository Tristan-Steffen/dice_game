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

# --- Der TRAGE-BOGEN ---------------------------------------------------------------
## Was der SPIELER bewegt, fliegt ÜBER dem Tisch: der Zielwürfel reist vom Pool-Sitz
## aufs Podest in einem flachen Bogen - und kommt dabei nie unter die Fläche.

func test_the_carry_arc_lands_exactly_on_its_target() -> void:
	stage.land_at(TARGET, 0.0)
	var goal := Vector3(-2.0, 1.2, 5.0)
	var flight := stage.carry_to(goal, 0.2, 1.2)
	assert_not_null(flight, "der Bogen ist eine Fahrt")
	await wait_for_signal(flight.finished, 5.0)
	assert_almost_eq(stage.die.global_position, goal, Vector3.ONE * 0.001,
		"am Ende steht er auf dem Ziel")
	assert_almost_eq(stage.emitter.global_position,
		goal - Vector3.UP * stage.hover_height, Vector3.ONE * 0.001,
		"und sein Feld ist mitgereist")

func test_the_carry_arc_never_dips_below_the_table() -> void:
	stage.land_at(TARGET, 0.0)
	var goal := Vector3(-2.0, 1.2, 5.0)
	var low := minf(TARGET.y, goal.y)
	stage.carry_to(goal, 0.4, 1.2)
	for i in 12:
		await wait_frames(2)
		assert_gte(stage.die.global_position.y, low - 0.001,
			"unter die Sehne - und damit unter den Tisch - kommt er nie")

func test_a_carry_without_time_stands_hard_on_its_target() -> void:
	stage.land_at(TARGET, 0.0)
	var goal := Vector3(1.0, 1.2, 1.0)
	assert_null(stage.carry_to(goal, 0.0, 1.2), "ohne Zeit gibt es keine Fahrt")
	assert_almost_eq(stage.die.global_position, goal, Vector3.ONE * 0.001,
		"er steht sofort da")

## show_faces malt einen HYBRID der Aufdeckung, OHNE def anzufassen: def bleibt die
## geteilte Instanz, an der ein Steady-State-Schreiber seinen Körper wiedererkennt.
func test_show_faces_paints_without_touching_the_definition() -> void:
	var held := stage.def
	var other := DieDefinition.new()
	var faces: Array[int] = [6, 6, 6, 6, 6, 6]
	other.faces = faces
	stage.show_faces(other)
	assert_same(stage.def, held, "def bleibt die geteilte Instanz")
	assert_eq(stage.def.faces[0], 1, "und ihr Inhalt auch")
	var label: Label3D = stage.faces.labels["VORNE"]
	assert_eq(label.text, "6", "gemalt ist trotzdem der gezeigte Stand")
	stage.apply_definition(held)
	assert_eq((stage.faces.labels["VORNE"] as Label3D).text, "1",
		"und apply_definition holt den echten zurück")
