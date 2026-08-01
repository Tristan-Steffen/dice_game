extends GutTest
## Die Stasis-Station (StasisEmitter): Puck, Iris und Kraftfeld-Säule unter einem
## schwebenden Würfel. Sie steht IMMER auf der Standfläche - nur der Würfel
## schwebt, die Säule trägt ihn bis zu seiner Unterseite. Genutzt von den Trays
## (je Slot eine) und vom Werkstück der Gravur-Station.

const CARRY := DiceTrayView.FLOAT_HEIGHT

func _emitter(tint := Color(0.15, 0.35, 0.75)) -> StasisEmitter:
	var emitter := StasisEmitter.new()
	add_child_autofree(emitter)
	emitter.build(CARRY, DiceTrayView.DIE_SCALE, tint)
	return emitter

func test_the_column_reaches_from_the_surface_up_to_the_die() -> void:
	var emitter := _emitter()
	var mesh: CylinderMesh = emitter.beam.mesh
	assert_almost_eq(mesh.height, CARRY, 0.001, "die Säule ist so hoch wie der Würfel schwebt")
	assert_almost_eq(emitter.beam.position.y, CARRY * 0.5, 0.001, "und steht auf der Fläche")
	assert_almost_eq(emitter.puck.position.y, StasisEmitter.PUCK_Y, 0.001)
	assert_gt(emitter.lens.position.y, emitter.puck.position.y, "die Iris liegt über dem Dial")

func test_the_grip_ring_sits_at_the_dies_underside() -> void:
	var emitter := _emitter()
	var expected := (CARRY - DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT) / CARRY
	assert_almost_eq(float(emitter.beam_material.get_shader_parameter("grip_h")), expected, 0.001,
		"der Griff-Ring greift dort, wo der Würfel aufliegt")

func test_the_load_pulse_runs_against_the_bob() -> void:
	# Sinkt der Würfel (bob < 0), arbeitet das Feld sichtbar härter - diese
	# Rückkopplung macht Emitter und Würfel zu EINER Maschine.
	assert_gt(StasisEmitter.load_for(-1.0), StasisEmitter.load_for(1.0))
	assert_almost_eq(StasisEmitter.load_for(0.0), 1.0, 0.001, "in der Ruhelage volle Last")

func test_the_tint_reaches_all_three_parts() -> void:
	var emitter := _emitter(Color(1, 0, 0))
	emitter.set_tint(Color(0, 1, 0))
	assert_eq(emitter.puck_material.get_shader_parameter("tint"), Color(0, 1, 0))
	assert_eq(emitter.lens_material.get_shader_parameter("tint"), Vector3(0, 1, 0))
	assert_eq(emitter.beam_material.get_shader_parameter("beam_color"), Vector3(0, 1, 0))

func test_an_empty_station_idles_without_carrying() -> void:
	var emitter := _emitter()
	emitter.set_engaged(0.0)
	assert_eq(float(emitter.beam_material.get_shader_parameter("engaged")), 0.0,
		"ohne Würfel bleibt die Säule ein Leerlauf-Stummel")

func test_every_tray_slot_stands_on_its_own_station() -> void:
	# Der Emitter bleibt auch unter einem LEEREN Platz stehen - er ist die
	# Vitrine, nicht die Anzeige des Inhalts.
	var tray: DiceTrayView = load("res://scenes/dice_pool_tray.tscn").instantiate()
	add_child_autofree(tray)
	await wait_frames(2)
	assert_eq(tray.slot_emitters.size(), tray.slot_roots.size(), "je Slot eine Station")
	tray.fill([DieDefinition.standard()] as Array[DieDefinition])
	assert_eq(float(tray.slot_emitters[0].beam_material.get_shader_parameter("engaged")), 1.0,
		"der belegte Platz trägt")
	assert_eq(float(tray.slot_emitters[1].beam_material.get_shader_parameter("engaged")), 0.0,
		"der leere Platz läuft leer - sichtbar bleibt er trotzdem")
	assert_true(tray.slot_emitters[1].visible)
