extends GutTest
## Tier-2-Tests der Grube (PackPitView): der Körper, den man durch das Loch im
## Display sieht.

const HALF := Vector2(9.0, 1.6)
const DEPTH := 1.4

var pit: PackPitView

func before_each() -> void:
	pit = PackPitView.new()
	add_child_autofree(pit)
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH)

func _mesh(box_name: String) -> MeshInstance3D:
	return pit.get_node_or_null(box_name) as MeshInstance3D

func test_the_bounds_are_the_hole_the_ground_shader_blanks() -> void:
	assert_eq(pit.bounds_min(), Vector2(3.0 - HALF.x, -2.0 - HALF.y))
	assert_eq(pit.bounds_max(), Vector2(3.0 + HALF.x, -2.0 + HALF.y))

func test_a_rebuild_writes_the_same_body() -> void:
	var before := pit.get_child_count()
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH)
	assert_eq(pit.get_child_count(), before, "idempotent: dieselben Maße, derselbe Körper")

func test_every_wall_is_one_bar_without_an_opening() -> void:
	for wall_name: String in PackPitView.WALL_NAMES:
		assert_not_null(_mesh(wall_name), "%s steht als EIN Balken" % wall_name)
	for child in pit.get_children():
		assert_false(String(child.name).begins_with("Hatch"),
			"das Magazin bestellt keine Klappen")

func test_the_four_walls_and_the_floor_close_the_box() -> void:
	assert_not_null(_mesh("Floor"), "der Boden liegt unter allem")
	var floor_mesh := _mesh("Floor")
	assert_lt(floor_mesh.position.y, -DEPTH, "und zwar unter der ganzen Tiefe")

## Die Vertiefung der Öffnungs-Fläche baut keinen eigenen Boden: ihr Bild trägt EIN
## Boden-Quad auf derselben Höhe - zwei Flächen dort flimmerten.
func test_an_unfloored_pit_builds_no_floor() -> void:
	pit.floored = false
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH)
	await wait_frames(1)
	assert_null(_mesh("Floor"), "kein eigener Boden")
	for wall_name: String in PackPitView.WALL_NAMES:
		assert_not_null(_mesh(wall_name), "die Wände bleiben")

## Der Samt-Schimmer mißt sich an der eigenen Platte.
func test_the_velvet_field_spans_the_plate() -> void:
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH)
	var lining: ShaderMaterial = _mesh("Floor").material_override
	var centre := Vector2(lining.get_shader_parameter("field_center"))
	assert_almost_eq(centre.x, 3.0, 0.001, "das Feld steht auf der Grubenmitte")
	assert_almost_eq(centre.y, -2.0, 0.001)
	var half := Vector2(lining.get_shader_parameter("field_half"))
	assert_almost_eq(half.x, HALF.x, 0.001)
	assert_almost_eq(half.y, HALF.y, 0.001)

func test_rim_and_walls_end_UNDER_the_glass() -> void:
	# Lägen ihre Deckflächen auf der Glasebene, kämpften sie im Tiefenpuffer und
	# legten einen hellen Rahmen rings um die Grube.
	assert_gt(PackPitView.RIM_SINK, 0.0)
	assert_almost_eq(PackPitView.WALL_SINK, PackPitView.RIM_SINK, 0.0001)
	for rim_name: String in ["RimXPlus", "RimXMinus", "RimZPlus", "RimZMinus"]:
		var rim := _mesh(rim_name)
		assert_not_null(rim, "%s deckt die Schnittkante" % rim_name)
		assert_lt(rim.position.y + PackPitView.RIM_H * 0.5, 0.0,
			"%s hängt unter dem Glas" % rim_name)

func test_the_lining_measures_itself_at_the_pit() -> void:
	var wall := _mesh("WallZMinus")
	var lining: ShaderMaterial = wall.material_override
	assert_almost_eq(float(lining.get_shader_parameter("pit_depth")), DEPTH, 0.0001)
	assert_almost_eq(float(lining.get_shader_parameter("velvet")), 0.0, 0.0001,
		"die Wand ist Metall")
	# Paneelbreite an der LÄNGSTEN Kante: an der kurzen gemessen bekäme die flache,
	# breite Magazin-Grube ein dichtes Streifenmuster.
	assert_almost_eq(float(lining.get_shader_parameter("panel_width")),
		maxf(HALF.x, HALF.y) * 2.0 * PackPitView.PANEL_SHARE, 0.0001)
	var floor_lining: ShaderMaterial = _mesh("Floor").material_override
	assert_almost_eq(float(floor_lining.get_shader_parameter("velvet")), 1.0, 0.0001,
		"der Boden ist Samt")

func test_nothing_in_the_pit_blooms_at_rest() -> void:
	assert_lt(PackPitView.GLOW_ENERGY * PackPitView.GLOW_COLOR.r, Rune.IDLE_CEILING)
	assert_lt(PackPitView.GLOW_ENERGY * PackPitView.GLOW_COLOR.g, Rune.IDLE_CEILING)
	assert_lt(PackPitView.GLOW_ENERGY * PackPitView.GLOW_COLOR.b, Rune.IDLE_CEILING)

func test_the_pit_casts_no_shadow_and_is_never_mirrored() -> void:
	# Ein Loch hat kein Spiegelbild, und in der Grube steht kein Szenenlicht.
	for child in pit.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_eq(mesh.layers & ScreenReflection.LAYER, 0,
			"%s spiegelt nicht" % mesh.name)

## Eine Grube OHNE Kragen (die Vertiefung unter der Tischsektion): dort deckt die
## buendige Platte die Schnittkante selbst, und ein Kragen staende ihr im Weg -
## dieselbe Grammatik wie die Schacht-Gruben ("die Schnittkante steht NACKT").
func test_a_rimless_pit_wears_no_collar() -> void:
	pit.rimmed = false
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH * 0.5)
	for bar in ["RimXPlus", "RimXMinus", "RimZPlus", "RimZMinus"]:
		assert_null(_mesh(bar), "%s steht nicht mehr" % bar)
	for wall_name: String in PackPitView.WALL_NAMES:
		assert_not_null(_mesh(wall_name), "%s aber schon" % wall_name)
	assert_not_null(_mesh("Floor"), "und ihr Boden auch")
	assert_not_null(_mesh("GlowZPlus"), "der Lichtsaum bleibt - er liegt IN der Grube")

