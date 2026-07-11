class_name DieFaceDisplay
extends Node3D
## Sitzt unter RigidBody3D eines Würfels und hält die 6 Gesichter (eines pro
## physischer Seite, siehe DiceController.AXIS_DIRECTIONS). Jedes Gesicht besteht
## aus einem weißen Körper-Quad (quads) und einem darüberliegenden Label3D
## (labels), das die Augenzahl als Ziffer(n) zeigt. Die Ziffern werden zur
## Laufzeit gesetzt statt aus 6 festen Punkt-Texturen - so lässt sich jeder Wert
## anzeigen (auch dreistellige "Augen"), ohne für jede Zahl eine eigene Textur zu
## brauchen. quads/labels werden von DieBuilder befüllt, bevor der Würfel in den
## Baum eingehängt wird.
##
## set_tint färbt den Würfelkörper (Grundfarbe Weiß, künftig Spezialwürfel-Farben
## oder Halten-Gold); die Ziffer bleibt dunkel und dadurch auf jedem Körper
## lesbar. Künftige Symbole statt Ziffern hängen sich hier am Label3D bzw. einem
## zusätzlichen Sprite3D an.

## Grundfarbe des Würfelkörpers - set_tint(Color.WHITE) ergibt genau diese Farbe.
const BODY_COLOR := Color(1, 1, 1)
## Farbe der Augenzahl-Ziffer (dunkel, damit sie auf hellem/getöntem Körper lesbar bleibt).
const NUMBER_COLOR := Color(0.08, 0.08, 0.1)
## Neutrale Farbe des Kanten-Körpers ohne Kanten-Material (siehe DieBuilder:
## Box-Mesh hinter den Gesichts-Quads) - etwas dunkler als die Gesichter, damit
## der Würfel plastisch wirkt. Mit Kanten-Material übernimmt dessen Tint.
const EDGE_COLOR := Color(0.8, 0.8, 0.83)
## Eigenleuchten der Würfel (Emission als Anteil der jeweiligen Körperfarbe):
## Seiten und Kanten leuchten in ihrer eigenen Farbe - im abgedunkelten
## Casino-Licht (siehe scene_root.tscn: Environment/TableLight) sind die
## Würfel damit selbst die hellsten Punkte auf dem Tisch und blühen über den
## Szenen-Glow sichtbar auf.
const GLOW_STRENGTH := 0.75
## Emission von MATERIAL-Seiten/-Kanten (Gold, Quecksilber, ...): bewusst
## überhell (> 1.0), damit veredelte Flächen deutlich stärker strahlen als der
## weiße Grundkörper.
const MATERIAL_GLOW_STRENGTH := 1.6

## Echtes Licht des Würfels auf seine Umgebung (OmniLight3D im Würfelzentrum,
## siehe DieBuilder) - nur für die Spielwürfel aktiv (set_light_enabled; die
## 30+ Tray-Würfel würden das Per-Objekt-Lichtlimit des Compatibility-Renderers
## sprengen). Ohne Material ein schwacher warmweißer Schein; trägt der Würfel
## Materialien (Seiten oder Kanten), leuchtet er DEUTLICH stärker in deren Farbe.
const LIGHT_BASE_COLOR := Color(1.0, 0.95, 0.85)
const LIGHT_BASE_ENERGY := 0.55
const LIGHT_MATERIAL_ENERGY := 2.6
const LIGHT_RANGE := 6.5

## Interne Auflösung der Ziffern-Glyphen (Font-Atlas-Pixel) - je höher, desto
## schärfer bei starkem Heranzoomen, unabhängig von der Weltgröße (die steuert
## pixel_size, siehe fit_label).
const LABEL_FONT_SIZE := 160
## Basis-Umrechnung Font-Pixel -> Weltmeinheiten (Höhe einer einstelligen Ziffer).
## Wird von fit_label bei mehrstelligen Zahlen weiter verkleinert.
const LABEL_PIXEL_SIZE := 0.0085
## Nutzbare Kantenlänge fürs Ziffernfeld in Weltmeinheiten (< DieBuilder.FACE_SIZE),
## damit auch mehrstellige Zahlen mit etwas Rand aufs Gesicht passen.
const LABEL_FIT_EXTENT := 1.5

var quads: Dictionary = {}   # Achse (String, siehe AXIS_DIRECTIONS) -> MeshInstance3D (Körper-Quad)
var labels: Dictionary = {}  # Achse (String) -> Label3D (Augenzahl)
## Gemeinsames Material ALLER Kanten-Teile (12 Balken + Füll-Box, von DieBuilder
## gesetzt) - eine Farbzuweisung färbt den ganzen Rahmen.
var edge_material_res: StandardMaterial3D = null
## Umgebungslicht des Würfels (von DieBuilder gesetzt, standardmäßig aus -
## siehe set_light_enabled/LIGHT_BASE_ENERGY).
var die_light: OmniLight3D = null
var light_allowed: bool = false

## Material-Grundfarbe je Achse (siehe DieMaterial.tint_for; Weiß = kein
## Material). set_tint multipliziert seinen Würfel-Tint (Stil/Auswahl-Gold)
## DARÜBER, damit Material-Seiten unter jeder Tönung erkennbar bleiben.
var face_base: Dictionary = {}
## Grundfarbe des Kanten-Körpers: neutral (EDGE_COLOR) ohne Kanten-Material,
## sonst der Material-Tint - wird wie face_base mit body_tint multipliziert.
var edge_base: Color = EDGE_COLOR
## Zuletzt per set_tint gesetzter Würfel-Tint - damit apply_definition die
## Seitenfarben neu aufbauen kann, ohne die Tönung zu verlieren.
var body_tint: Color = Color.WHITE

## Stellt alle 6 Seiten gemäß def.faces ein (Index über
## DiceController.AXIS_FACE_INDEX, siehe dort für die Achsen-Zuordnung) und
## übernimmt die Material-Grundfarben aus def.materials.
func apply_definition(def: DieDefinition) -> void:
	for axis in DiceController.AXIS_FACE_INDEX:
		var face_index: int = DiceController.AXIS_FACE_INDEX[axis]
		var value: int = def.faces[face_index] if face_index < def.faces.size() else 1
		_set_face_value(axis, value)
		var material_id: String = def.materials[face_index] if face_index < def.materials.size() else ""
		face_base[axis] = DieMaterial.tint_for(material_id)
	edge_base = DieMaterial.tint_for(def.edge_material) if DieMaterial.is_valid_id(def.edge_material) else EDGE_COLOR
	_refresh_face_colors()

func _set_face_value(axis: String, value: int) -> void:
	var label: Label3D = labels[axis]
	label.text = str(value)
	DieFaceDisplay.fit_label(label)

## Färbt den Körper aller 6 Seiten ein (Spezialwürfel-Tint oder Halten-Gold) -
## Color.WHITE = weiße Grundfarbe (Normalzustand). Multipliziert über die
## Material-Grundfarbe der jeweiligen Seite; die Ziffern bleiben dunkel.
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
		var edge_glow := MATERIAL_GLOW_STRENGTH if edge_base != EDGE_COLOR else GLOW_STRENGTH
		_set_body_color(edge_material_res, edge_base * body_tint, edge_glow)
	_refresh_die_light()

## Setzt Körperfarbe UND passendes Eigenleuchten (Emission = Farbe × glow) in
## einem - so glimmt jede Seite/Kante immer in genau der Farbe, die sie gerade
## trägt (Material-Tint, Stilfarbe, Auswahl-Gold, ...); Material-Flächen
## strahlen überhell (MATERIAL_GLOW_STRENGTH).
static func _set_body_color(material: StandardMaterial3D, color: Color, glow: float = GLOW_STRENGTH) -> void:
	material.albedo_color = color
	material.emission = color * glow

## Schaltet das echte Umgebungslicht dieses Würfels frei (nur Spielwürfel,
## siehe scene_root._ready) - Farbe/Stärke folgen danach automatisch den
## Materialien (siehe _refresh_die_light).
func set_light_enabled(on: bool) -> void:
	light_allowed = on
	_refresh_die_light()

## Farbe/Stärke des Würfel-Lichts aus dem aktuellen Zustand: Material-Tints
## (Kanten und/oder Seiten) mischen sich zur Lichtfarbe und leuchten stark
## (LIGHT_MATERIAL_ENERGY); ohne Material bleibt ein schwacher warmweißer
## Schein. body_tint (Stilfarbe/Halten-Gold) färbt das Licht mit.
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

## Färbt den Kanten-Rahmen direkt (absolut, ohne edge_base) - für die
## Kanten-Auswahl in der Gravur-Station (siehe DieInspectorView). set_tint
## setzt danach wieder die normale Rahmenfarbe (edge_base × body_tint).
func set_edge_tint(color: Color) -> void:
	if edge_material_res != null:
		_set_body_color(edge_material_res, BODY_COLOR * color)

## Färbt den Körper genau einer Seite (face_index 0..5, siehe
## DiceController.AXIS_FACE_INDEX) - für die Auswahl-Hervorhebung in der
## Gravur-Station (siehe DieInspectorView). set_tint setzt danach wieder alle
## Seiten gemeinsam.
func set_face_tint(face_index: int, color: Color) -> void:
	for axis in quads:
		if DiceController.AXIS_FACE_INDEX[axis] == face_index:
			var material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
			_set_body_color(material, BODY_COLOR * color)
			return

## Skaliert die Ziffern-Weltgröße (pixel_size) so, dass label.text in ein Feld
## von LABEL_FIT_EXTENT passt: einstellige Werte nutzen LABEL_PIXEL_SIZE voll,
## mehrstellige werden proportional verkleinert. Wird bei jeder Wertänderung
## aufgerufen, damit z.B. "128" genauso aufs Gesicht passt wie "6".
static func fit_label(label: Label3D) -> void:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var size_px: Vector2 = font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, label.font_size)
	var world_extent: float = maxf(size_px.x, size_px.y) * LABEL_PIXEL_SIZE
	var shrink: float = maxf(1.0, world_extent / LABEL_FIT_EXTENT)
	label.pixel_size = LABEL_PIXEL_SIZE / shrink
