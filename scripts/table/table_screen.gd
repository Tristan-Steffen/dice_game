class_name TableScreen
extends SubViewport
## Der Tisch-Bildschirm: rendert eine 2D-Oberfläche (Kinder dieses SubViewports)
## in eine ViewportTexture und legt sie als leuchtendes Display-Material auf
## das "Screen"-Mesh des Tischs (Tisch.glb, siehe attach_to). Die gesamte
## Spielfläche innerhalb der LED-Rinne ist damit ein Bildschirm - die Würfel
## liegen buchstäblich AUF der Anzeige.
##
## Koordaten-Versprechen (siehe world_to_pixel): Pixel (0,0) ist die obere
## linke Bildschirmecke aus Sicht der Grubenkamera - u wächst entlang Welt+Z,
## v entlang Welt-X ("Bildschirm-oben" = +X, wie überall am Tisch). Die
## Weltgrenzen werden beim attach_to aus der globalen AABB des Screen-Meshs
## abgeleitet, nicht hart codiert - der Tisch darf also weiter umziehen.
##
## Inhalt: die Kombinationsliste als kompakte Legende im gedämpften Neon-Look
## (siehe ComboCellView) - kleine Zellen, dicht gebündelt direkt UNTERHALB der
## Grube (Bildschirm-unten = Welt -X), sortiert nach Wertigkeit. scene_root
## holt sich die Zellen über combo_cells und steuert Aufleuchten/Menü-Stufen
## (siehe _collect_combo_labels/_tween_combo_label - unverändert gegenüber der
## alten 3D-Tischliste).

const RESOLUTION := Vector2i(1560, 1060)  # Seitenverhältnis der Screen-Fläche (31.2 x 21.2)
const BACKGROUND_COLOR := Color(0.015, 0.025, 0.05)
const EMISSION_ENERGY := 1.2  # lässt die Anzeige im dunklen Raum als Display leuchten

## Kombinations-Cluster unter der Grube: kleine Zellen (~1/4 der Ablage-Tray-
## Fläche) in 3 Spalten, Reihenfolge = DiceScoring.HAND_PRIORITY (stärkste
## zuerst), unvollständige letzte Zeile mittig. Grube endet bei ca. Pixel 625.
const CELL_SIZE := Vector2(140, 44)
const CELL_GAP := Vector2(8, 6)
const CLUSTER_COLUMNS := 3
const CLUSTER_TOP := 648.0
const CLUSTER_CENTER_X := 780.0

## DiceScoring-Key -> ComboCellView (siehe scene_root._collect_combo_labels).
var combo_cells: Dictionary = {}

## Weltgrenzen der Screen-Fläche (aus attach_to); Mapping siehe world_to_pixel.
var _z_min := 0.0
var _z_span := 1.0
var _x_max := 0.0
var _x_span := 1.0

func _ready() -> void:
	size = RESOLUTION
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	use_hdr_2d = true  # Überhell-Farben (Glow-Highlights der Zellen) dürfen blühen
	_build_content()

## Legt die ViewportTexture als Material auf das Screen-Mesh und leitet die
## Weltgrenzen aus dessen globaler AABB ab (alle 8 Ecken transformieren -
## robust gegen künftige Tisch-Verschiebungen/Drehungen um Y).
func attach_to(screen_mesh: MeshInstance3D) -> void:
	var aabb := screen_mesh.get_aabb()
	var to_world := screen_mesh.global_transform
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for i in 8:
		var corner := to_world * (aabb.position + Vector3(
			aabb.size.x * float(i & 1),
			aabb.size.y * float((i >> 1) & 1),
			aabb.size.z * float((i >> 2) & 1)))
		min_x = minf(min_x, corner.x)
		max_x = maxf(max_x, corner.x)
		min_z = minf(min_z, corner.z)
		max_z = maxf(max_z, corner.z)
	_z_min = min_z
	_z_span = max_z - min_z
	_x_max = max_x
	_x_span = max_x - min_x

	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = get_texture()
	material.emission_enabled = true
	material.emission_texture = get_texture()
	material.emission_energy_multiplier = EMISSION_ENERGY
	material.roughness = 0.4
	screen_mesh.material_override = material

## Weltposition -> Pixel auf dem Screen (für Anzeigen unter den Würfeln:
## Punktzahlen, Aufprall-Effekte, Markierungen). y der Weltposition ist egal.
func world_to_pixel(world: Vector3) -> Vector2:
	var u := (world.z - _z_min) / _z_span
	var v := (_x_max - world.x) / _x_span
	return Vector2(u * float(size.x), v * float(size.y))

## Baut den Bildschirm-Inhalt: dunkler Grund, dezenter Schriftzug in der Mitte
## (liegt unter der Grube) und die Kombinationsliste als Zellen-Bänder.
func _build_content() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var label := Label.new()
	label.name = "Wordmark"
	label.text = "FUMBLE"
	label.add_theme_font_size_override("font_size", 150)
	label.modulate = Color(0.3, 0.9, 1.0, 0.18)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)

	var total := DiceScoring.HAND_PRIORITY.size()
	for i in total:
		var row := i / CLUSTER_COLUMNS
		var column := i % CLUSTER_COLUMNS
		var cells_in_row: int = mini(CLUSTER_COLUMNS, total - row * CLUSTER_COLUMNS)
		var row_width := float(cells_in_row) * CELL_SIZE.x + float(cells_in_row - 1) * CELL_GAP.x
		var at := Vector2(
			CLUSTER_CENTER_X - row_width / 2.0 + float(column) * (CELL_SIZE.x + CELL_GAP.x),
			CLUSTER_TOP + float(row) * (CELL_SIZE.y + CELL_GAP.y))
		_add_combo_cell(DiceScoring.HAND_PRIORITY[i], at)

func _add_combo_cell(key: String, at: Vector2) -> void:
	var cell := ComboCellView.new()
	cell.name = "Combo_%s" % key
	cell.position = at
	cell.size = CELL_SIZE
	add_child(cell)
	cell.setup(DiceScoring.label_for(key), DiceScoring.EXAMPLE_DICE[key], DiceScoring.mult_for(key))
	combo_cells[key] = cell
