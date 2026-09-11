extends GutTest
## Tier-2-Tests der GEMEINSAMEN GRUBE (PackPitView): der Körper, den man durch das
## Loch im Display sieht. Sie baut BEIDE Rechtecke - Magazin und Turm-Bucht -, und
## sie kennt genau EINE Öffnung: die zwischen den beiden.

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

## DIE BUCHT: die Seite zum Magazin fehlt GANZ - Wand, Kragen und Lichtsaum.
func test_an_open_side_has_no_wall_no_collar_and_no_seam() -> void:
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH, PackPitView.WALL_X_MINUS)
	assert_null(_mesh("WallXMinus"), "die Wand zum Nachbarn fehlt")
	assert_null(_mesh("RimXMinus"), "und kein Kragen liegt quer durch das Loch")
	assert_null(_mesh("GlowXMinus"), "der Lichtsaum ebenso nicht")
	for name: String in ["WallXPlus", "WallZPlus", "WallZMinus", "RimXPlus",
			"GlowXPlus"]:
		assert_not_null(_mesh(name), "%s steht weiter" % name)

## DAS MAGAZIN: dieselbe Seite bekommt einen DURCHBRUCH - aus EINEM Balken werden
## ZWEI, und die Lücke dazwischen ist genau seine Breite.
func test_a_breach_splits_the_wall_into_two_bars() -> void:
	var offset := 0.4
	var width := 1.0
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH, PackPitView.WALL_X_PLUS,
		Vector2(offset, width))
	assert_null(_mesh("WallXPlus"), "der EINE Balken ist fort")
	var left := _mesh("WallXPlusA")
	var right := _mesh("WallXPlusB")
	assert_not_null(left, "links des Durchbruchs steht einer")
	assert_not_null(right, "rechts des Durchbruchs der andere")
	var lo: float = left.position.z + (left.mesh as BoxMesh).size.z * 0.5
	var hi: float = right.position.z - (right.mesh as BoxMesh).size.z * 0.5
	assert_almost_eq(hi - lo, width, 0.001, "die Lücke IST die Breite")
	assert_almost_eq((lo + hi) * 0.5, offset, 0.001, "und sie sitzt auf dem Versatz")
	# Kragen und Lichtsaum folgen der Wand - kein Kragen quer durch die Öffnung.
	for name: String in ["RimXPlus", "GlowXPlus"]:
		assert_null(_mesh(name), "%s ist geteilt" % name)
		assert_not_null(_mesh(name + "A"))
		assert_not_null(_mesh(name + "B"))
	assert_not_null(_mesh("WallXMinus"), "die Gegenseite bleibt zu")

func test_the_four_walls_and_the_floor_close_the_box() -> void:
	assert_not_null(_mesh("Floor"), "der Boden liegt unter allem")
	var floor_mesh := _mesh("Floor")
	assert_lt(floor_mesh.position.y, -DEPTH, "und zwar unter der ganzen Tiefe")

## JEDE Grube baut ihren eigenen Boden auf ihrer eigenen Tiefe (2026-09-11: die
## Bucht ist nur halb so tief, der eine L-Boden ist damit gestorben) - auch die
## offene Bucht.
func test_the_open_bay_builds_its_own_floor() -> void:
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH * 0.5, PackPitView.WALL_X_MINUS)
	var plate := _mesh("Floor")
	assert_not_null(plate, "die Bucht hat ihren Boden")
	assert_almost_eq(plate.position.y + PackPitView.FLOOR * 0.5,
		-PackPitView.WALL_SINK - DEPTH * 0.5, 0.001, "auf ihrer eigenen Tiefe")
	assert_null(pit.get("floor_area"), "die gemeldete L-Fläche ist gestorben")
	assert_null(pit.get("build_floor"), "und der Boden-Schalter mit ihr")

## Unter dem Durchbruch steht eine SCHWELLE, wenn der Nachbar flacher ist: sie
## beginnt eine Bodenplatte unter dessen Boden und reicht bis zum eigenen, so breit
## wie der Durchbruch - und sie ist UNGETEILT, sie steht ja im Durchbruch.
func test_a_shallower_neighbour_gets_a_sill_under_the_breach() -> void:
	var offset := 0.5
	var width := 1.0
	pit.breach_floor = DEPTH * 0.5
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH, PackPitView.WALL_X_PLUS,
		Vector2(offset, width))
	var sill := _mesh("WallXPlusSchwelle")
	assert_not_null(sill, "die Schwelle steht")
	var span: Vector3 = (sill.mesh as BoxMesh).size
	assert_almost_eq(span.z, width, 0.001, "so breit wie der Durchbruch")
	assert_almost_eq(sill.position.z, offset, 0.001, "und auf seinem Versatz")
	var top := sill.position.y + span.y * 0.5
	assert_almost_eq(top, -PackPitView.WALL_SINK - DEPTH * 0.5 - PackPitView.FLOOR,
		0.001, "ihre Oberkante liegt eine Platte unter dem Nachbar-Boden")
	assert_almost_eq(sill.position.y - span.y * 0.5, -PackPitView.WALL_SINK - DEPTH,
		0.001, "und sie reicht bis zum eigenen")
	assert_almost_eq(sill.position.x, _mesh("WallXPlusA").position.x, 0.001,
		"in der Flucht der Wand")

func test_an_equally_deep_neighbour_needs_no_sill() -> void:
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH, PackPitView.WALL_X_PLUS,
		Vector2(1.5, 2.0))
	assert_null(_mesh("WallXPlusSchwelle"), "ohne breach_floor keine Schwelle")

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
