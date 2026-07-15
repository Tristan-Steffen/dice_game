class_name DieFaceDisplay
extends Node3D
## Hält die 6 Gesichter eines Würfels (Körper-Quad + Label3D-Ziffer je Seite)
## plus Kanten-Rahmen und Würfel-Licht. Ziffern werden zur Laufzeit gesetzt,
## damit jeder Wert darstellbar ist. quads/labels befüllt DieBuilder.

const BODY_COLOR := Color(1, 1, 1)
## Ziffernfarbe: dunkel, damit sie auf hellem/getöntem Körper lesbar bleibt.
const NUMBER_COLOR := Color(0.08, 0.08, 0.1)
## Neutrale Kantenfarbe ohne Kanten-Material - etwas dunkler als die Gesichter.
const EDGE_COLOR := Color(0.8, 0.8, 0.83)
## Eigenleuchten (Emission als Anteil der Körperfarbe): macht die Würfel im
## abgedunkelten Casino-Licht zu den hellsten Punkten (Szenen-Glow).
const GLOW_STRENGTH := 0.95
## Material-Flächen strahlen überhell (> 1.0), deutlich stärker als der Grundkörper.
const MATERIAL_GLOW_STRENGTH := 1.6

## Echtes Umgebungslicht des Würfels - nur für die Spielwürfel aktiv, die
## 30+ Tray-Würfel würden das Per-Objekt-Lichtlimit des Renderers sprengen.
const LIGHT_BASE_COLOR := Color(1.0, 0.95, 0.85)
const LIGHT_BASE_ENERGY := 0.9
const LIGHT_MATERIAL_ENERGY := 3.2
const LIGHT_RANGE := 7.5

## Interne Glyphen-Auflösung (Font-Atlas-Pixel) - Weltgröße steuert pixel_size.
const LABEL_FONT_SIZE := 160
## Basis-Umrechnung Font-Pixel -> Welteinheiten (Höhe einer einstelligen Ziffer).
const LABEL_PIXEL_SIZE := 0.0085
## Nutzbare Kantenlänge des Ziffernfelds (< DieBuilder.FACE_SIZE).
const LABEL_FIT_EXTENT := 1.5

var quads: Dictionary = {}   # Achse -> MeshInstance3D (Körper-Quad)
var labels: Dictionary = {}  # Achse -> Label3D (Augenzahl)
## Gemeinsames Material ALLER Kanten-Teile - eine Zuweisung färbt den Rahmen.
var edge_material_res: StandardMaterial3D = null
var die_light: OmniLight3D = null
var light_allowed: bool = false

## Material-Grundfarbe je Achse (Weiß = kein Material); body_tint
## multipliziert darüber, damit Material-Seiten unter jeder Tönung sichtbar bleiben.
var face_base: Dictionary = {}
var edge_base: Color = EDGE_COLOR
var body_tint: Color = Color.WHITE

## Stellt alle 6 Seiten gemäß def ein (Werte, Material-Farben, Texturen).
func apply_definition(def: DieDefinition) -> void:
	for axis in DiceController.AXIS_FACE_INDEX:
		var face_index: int = DiceController.AXIS_FACE_INDEX[axis]
		var value: int = def.faces[face_index] if face_index < def.faces.size() else 1
		_set_face_value(axis, value)
		var material_id: String = def.materials[face_index] if face_index < def.materials.size() else ""
		face_base[axis] = DieMaterial.tint_for(material_id)
		var quad_material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
		quad_material.albedo_texture = DieMaterial.die_texture_for(material_id)
	edge_base = DieMaterial.tint_for(def.edge_material) if DieMaterial.is_valid_id(def.edge_material) else EDGE_COLOR
	if edge_material_res != null:
		edge_material_res.albedo_texture = DieMaterial.die_texture_for(def.edge_material)
	_refresh_face_colors()

func _set_face_value(axis: String, value: int) -> void:
	var label: Label3D = labels[axis]
	label.text = str(value)
	DieFaceDisplay.fit_label(label)

## Färbt den Körper aller 6 Seiten (Color.WHITE = Normalzustand); Ziffern bleiben dunkel.
func set_tint(color: Color) -> void:
	body_tint = color
	_refresh_face_colors()

func _refresh_face_colors() -> void:
	for axis in quads:
		var material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
		var base: Color = face_base.get(axis, Color.WHITE)
		var glow := MATERIAL_GLOW_STRENGTH if base != Color.WHITE else GLOW_STRENGTH
		_set_body_color(material, BODY_COLOR * base * body_tint, glow)
	if edge_material_res != null:
		# set_edge_tint schaltet für die Auswahl auf unschattiert - hier zurück.
		edge_material_res.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		var edge_glow := MATERIAL_GLOW_STRENGTH if edge_base != EDGE_COLOR else GLOW_STRENGTH
		_set_body_color(edge_material_res, edge_base * body_tint, edge_glow)
	_refresh_die_light()

## Körperfarbe + passendes Eigenleuchten in einem - jede Fläche glimmt in
## genau der Farbe, die sie gerade trägt.
static func _set_body_color(material: StandardMaterial3D, color: Color, glow: float = GLOW_STRENGTH) -> void:
	material.albedo_color = color
	material.emission = color * glow

## Schaltet das Umgebungslicht frei (nur Spielwürfel).
func set_light_enabled(on: bool) -> void:
	light_allowed = on
	_refresh_die_light()

## Licht aus dem Zustand: Material-Tints mischen sich zur Lichtfarbe und
## leuchten stark; ohne Material bleibt ein schwacher warmweißer Schein.
func _refresh_die_light() -> void:
	if die_light == null:
		return
	die_light.visible = light_allowed
	if not light_allowed:
		return
	var tints: Array[Color] = []
	if edge_base != EDGE_COLOR:
		tints.append(edge_base)
	for axis in face_base:
		if face_base[axis] != Color.WHITE:
			tints.append(face_base[axis])
	if tints.is_empty():
		die_light.light_color = LIGHT_BASE_COLOR * body_tint
		die_light.light_energy = LIGHT_BASE_ENERGY
		return
	var mixed := Color(0, 0, 0)
	for tint in tints:
		mixed += tint
	mixed /= float(tints.size())
	die_light.light_color = mixed * body_tint
	die_light.light_energy = LIGHT_MATERIAL_ENERGY

## Färbt den Kanten-Rahmen absolut (Kanten-Auswahl der Gravur-Station).
## Unschattiert, damit exakt die flache Auswahl-Farbe erscheint - beleuchtet
## klemmt derselbe Wert je nach Licht unterschiedlich weg. set_tint stellt
## danach die normale Rahmenfarbe wieder her.
func set_edge_tint(color: Color) -> void:
	if edge_material_res != null:
		edge_material_res.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		edge_material_res.albedo_color = BODY_COLOR * color

## Färbt NUR die Ziffer einer Seite (Auswahl-Hervorhebung); der Körper bleibt
## neutral. Gegenstück: reset_number_tints.
func set_face_number_tint(face_index: int, color: Color) -> void:
	for axis in labels:
		if DiceController.AXIS_FACE_INDEX[axis] == face_index:
			(labels[axis] as Label3D).modulate = color
			return

func reset_number_tints() -> void:
	for axis in labels:
		(labels[axis] as Label3D).modulate = NUMBER_COLOR

## Skaliert pixel_size so, dass label.text in LABEL_FIT_EXTENT passt -
## mehrstellige Werte werden proportional verkleinert.
static func fit_label(label: Label3D) -> void:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var size_px: Vector2 = font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, label.font_size)
	var world_extent: float = maxf(size_px.x, size_px.y) * LABEL_PIXEL_SIZE
	var shrink: float = maxf(1.0, world_extent / LABEL_FIT_EXTENT)
	label.pixel_size = LABEL_PIXEL_SIZE / shrink
