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

## EIN BODEN für die ganze L-Fläche (Welle Z): die BUCHT baut keinen, das MAGAZIN
## einen, der über den eigenen Grundriß hinaus bis an ihre Rückwand reicht - eine
## Platte, ein Material, EINE Höhe.
func test_the_bay_builds_no_floor_at_all() -> void:
	pit.build_floor = false
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH, PackPitView.WALL_X_MINUS)
	assert_null(_mesh("Floor"), "die Bucht hat kein Boden-Kind")
	for wall_name: String in ["WallXPlus", "WallZPlus", "WallZMinus"]:
		assert_not_null(_mesh(wall_name), "ihre Wände stehen weiter")

func test_a_reported_floor_area_covers_the_neighbour_too() -> void:
	# Die Nachbargrube liegt jenseits der eigenen +X-Wand; die gemeldete Fläche
	# umschließt beide Grundrisse.
	var mine := Rect2(Vector2(3.0 - HALF.x, -2.0 - HALF.y), HALF * 2.0)
	var bay := Rect2(Vector2(3.0 + HALF.x, -2.0), Vector2(4.0, 1.0))
	pit.floor_area = mine.merge(bay)
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH)
	var plate := _mesh("Floor")
	var span: Vector3 = (plate.mesh as BoxMesh).size
	var lo := Vector2(plate.global_position.x - span.x * 0.5,
		plate.global_position.z - span.z * 0.5)
	var hi := Vector2(plate.global_position.x + span.x * 0.5,
		plate.global_position.z + span.z * 0.5)
	assert_true(Rect2(lo, hi - lo).encloses(bay),
		"der EINE Boden deckt auch die Nachbargrube")
	assert_true(Rect2(lo, hi - lo).encloses(mine), "und den eigenen Grundriß")
	# EINE Höhe: die Oberkante liegt auf der Grubentiefe, ohne Absatz.
	assert_almost_eq(plate.position.y + PackPitView.FLOOR * 0.5,
		-PackPitView.WALL_SINK - DEPTH, 0.001, "keine abgesenkte zweite Platte")
	assert_null(pit.get("floor_sink"), "das Absenken ist gestorben")

## Der Samt-Schimmer mißt sich an der GANZEN Platte - sonst stünde an der Naht
## zwischen den beiden Löchern eine Helligkeitskante.
func test_the_velvet_field_spans_the_whole_plate() -> void:
	var area := Rect2(Vector2(-9.0, -6.0), Vector2(30.0, 9.0))
	pit.floor_area = area
	pit.setup(Vector3(3.0, 0.0, -2.0), HALF, DEPTH)
	var lining: ShaderMaterial = _mesh("Floor").material_override
	assert_eq(Vector2(lining.get_shader_parameter("field_center")),
		area.get_center(), "das Feld steht auf der Mitte der ganzen Fläche")
	assert_eq(Vector2(lining.get_shader_parameter("field_half")), area.size * 0.5)

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
