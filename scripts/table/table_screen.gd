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

## Überabtastung: Das Display bespielt eine große Tischfläche; beim Heranzoomen
## wird die Textur stark vergrößert. Eine höher aufgelöste Zeichenfläche (Basis
## 1560x1060 mal SUPERSAMPLE) gibt Text und Linien deutlich mehr Texel, ohne die
## Welt-Abbildung zu ändern (die rechnet in Anteilen pixel/size). Alle Layout-
## Maße wachsen mit demselben Faktor mit, ComboCellView skaliert ohnehin relativ.
const SUPERSAMPLE := 3
const RESOLUTION := Vector2i(1560, 1060) * SUPERSAMPLE
const BACKGROUND_COLOR := Color(0.015, 0.025, 0.05)
const EMISSION_ENERGY := 1.2  # lässt die Anzeige im dunklen Raum als Display leuchten

## Kombinations-Cluster unter der Grube: kleine Zellen in 3 Spalten, Reihenfolge
## = DiceScoring.HAND_PRIORITY (stärkste zuerst), unvollständige letzte Zeile
## mittig. CENTER_X bewusst links der Bildmitte (780) - der Block sitzt um etwa
## eine Blockbreite nach links versetzt unter der Grube.
const CELL_SIZE := Vector2(98, 31) * SUPERSAMPLE
const CELL_GAP := Vector2(6, 4) * SUPERSAMPLE
const CLUSTER_COLUMNS := 3
const CLUSTER_TOP := 648.0 * SUPERSAMPLE
const CLUSTER_CENTER_X := 400.0 * SUPERSAMPLE

## Neon-Rahmen um den ganzen Cluster (Padding rund um die äußersten Zellen).
const CLUSTER_PADDING := 13.0 * SUPERSAMPLE
const FRAME_COLOR := Color(0.4, 0.78, 0.88)
const FRAME_BG := Color(0.04, 0.09, 0.14, 0.55)

## DiceScoring-Key -> ComboCellView (siehe scene_root._collect_combo_labels).
var combo_cells: Dictionary = {}

## Bildschirm-Rechteck des Kombi-Clusters inkl. Rahmen (nach _build_content) -
## Grundlage für Kamera-Zoomziel und Klickzone (siehe scene_root, cluster_*).
var cluster_rect := Rect2()

## Weltgrenzen der Screen-Fläche (aus attach_to); Mapping siehe world_to_pixel.
var _z_min := 0.0
var _z_span := 1.0
var _x_max := 0.0
var _x_span := 1.0
var _surface_y := 0.0  # Welthöhe der Screen-Oberfläche (für pixel_to_world)

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
		_surface_y = corner.y  # flache Fläche -> alle Ecken (fast) gleiche Höhe
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

## Pixel auf dem Screen -> Weltposition auf der Tischfläche (Umkehr von
## world_to_pixel; y = Screen-Oberfläche). Für Kamera-Zoomziel und Klickzone
## des Kombi-Clusters (siehe scene_root).
func pixel_to_world(pixel: Vector2) -> Vector3:
	var u := pixel.x / float(size.x)
	var v := pixel.y / float(size.y)
	return Vector3(_x_max - v * _x_span, _surface_y, _z_min + u * _z_span)

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
	label.add_theme_font_size_override("font_size", 150 * SUPERSAMPLE)
	label.modulate = Color(0.3, 0.9, 1.0, 0.18)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)

	# Zellpositionen vorab berechnen, um die Cluster-Ausdehnung zu kennen (der
	# Neon-Rahmen muss VOR den Zellen hinter sie gelegt werden).
	var total := DiceScoring.HAND_PRIORITY.size()
	var positions: Array[Vector2] = []
	var bounds := Rect2()
	for i in total:
		var row := i / CLUSTER_COLUMNS
		var column := i % CLUSTER_COLUMNS
		var cells_in_row: int = mini(CLUSTER_COLUMNS, total - row * CLUSTER_COLUMNS)
		var row_width := float(cells_in_row) * CELL_SIZE.x + float(cells_in_row - 1) * CELL_GAP.x
		var at := Vector2(
			CLUSTER_CENTER_X - row_width / 2.0 + float(column) * (CELL_SIZE.x + CELL_GAP.x),
			CLUSTER_TOP + float(row) * (CELL_SIZE.y + CELL_GAP.y))
		positions.append(at)
		var cell_rect := Rect2(at, CELL_SIZE)
		bounds = cell_rect if i == 0 else bounds.merge(cell_rect)

	cluster_rect = bounds.grow(CLUSTER_PADDING)
	_add_cluster_frame(cluster_rect)
	for i in total:
		_add_combo_cell(DiceScoring.HAND_PRIORITY[i], positions[i])

## Neon-Rahmen mit dezent abgesetztem Hintergrund um den ganzen Cluster.
func _add_cluster_frame(rect: Rect2) -> void:
	var frame := Panel.new()
	frame.name = "ClusterFrame"
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_BG
	style.border_color = FRAME_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)

func _add_combo_cell(key: String, at: Vector2) -> void:
	var cell := ComboCellView.new()
	cell.name = "Combo_%s" % key
	cell.position = at
	cell.size = CELL_SIZE
	add_child(cell)
	cell.setup(DiceScoring.label_for(key), DiceScoring.EXAMPLE_DICE[key], DiceScoring.mult_for(key))
	combo_cells[key] = cell
