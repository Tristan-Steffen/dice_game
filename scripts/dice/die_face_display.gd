class_name DieFaceDisplay
extends Node3D
## Hält die 6 Gesichter eines Würfels (Körper-Quad + Label3D-Ziffer je Seite)
## plus Kanten-Rahmen und Würfel-Licht. Ziffern werden zur Laufzeit gesetzt,
## damit jeder Wert darstellbar ist. quads/labels befüllt DieBuilder.

## Tron-Prinzip: dunkle Masse, konzentriertes Licht. Der Körper ist dunkles
## Glas (Albedo überall gleich), NUR Kanten-Linien und Ziffern leuchten -
## breite Flächen glimmen kaum. So wirken die Würfel massiv statt "Lampenschirm".
const BODY_COLOR := Color(0.05, 0.05, 0.08)
## Ziffern als Neonlicht (überhell -> Bloom), statt dunkler Tinte.
const NUMBER_COLOR := Color(1.15, 1.8, 1.95)
## Sentinel "kein Kanten-Material" (Vergleichswert, siehe edge_base).
const EDGE_COLOR := Color(0.8, 0.8, 0.83)
## Neutrale Neon-Linienfarbe der Kanten (Casino-Cyan).
const EDGE_NEON := Color(0.55, 0.91, 0.99)
## Emissions-Stärken: dünne Linien dürfen weit überhell (Bloom), Flächen nicht.
const FACE_GLOW := 0.16
const EDGE_GLOW := 2.4
const MATERIAL_FACE_GLOW := 1.5
const MATERIAL_EDGE_GLOW := 3.0

## Echtes Umgebungslicht des Würfels - nur für die Spielwürfel aktiv, die
## 30+ Tray-Würfel würden das Per-Objekt-Lichtlimit des Renderers sprengen.
## Eng und hart abfallend: eine sichtbare Licht-Lache UNTER dem Würfel erdet
## ihn (die Neon-Version eines Kontaktschattens).
const LIGHT_BASE_COLOR := Color(0.6, 0.88, 1.0)
const LIGHT_BASE_ENERGY := 1.5
const LIGHT_MATERIAL_ENERGY := 3.2
const LIGHT_RANGE := 4.5

## Zusätzliche additive Glanz-Lache am Boden: folgt dem Würfel und verblasst
## mit seiner Flughöhe - garantierte Erdung auch neben dem Omni-Licht.
const POOL_Y := 0.03          # knapp über der Tischfläche
const POOL_REST_Y := 1.0      # Körpermitte in Ruhelage (= DieBuilder.HALF_EXTENT)
const POOL_FADE_PER_UNIT := 0.22
const POOL_ALPHA_PER_ENERGY := 0.11

## Atem des Kanten-Neons (statisches Leuchten wirkt aufgemalt, atmendes bestromt).
const PULSE_SPEED := 1.4       # rad/s ~ ruhiger Atem
const PULSE_AMOUNT := 0.08
const PULSE_AMOUNT_MATERIAL := 0.16

## Fresnel-Hüllen-Stärke (Material-Würfel schimmern deutlicher).
const SHELL_STRENGTH := 0.55
const SHELL_STRENGTH_MATERIAL := 0.9

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
## Glanz-Lache (top_level-Quad am Boden) + ihr Material; befüllt DieBuilder.
var glow_pool: MeshInstance3D = null
var pool_material: StandardMaterial3D = null
var _pool_color := Color(0, 0, 0, 0)
## Fresnel-Hülle (Blickwinkel-Schimmer); befüllt DieBuilder.
var shell_material: ShaderMaterial = null
## Lebendiges Licht: das Kanten-Neon atmet langsam - Material-Würfel stärker.
var _pulse_phase := randf() * TAU
var _has_material := false

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
		var face_texture := DieMaterial.die_texture_for(material_id)
		quad_material.albedo_texture = face_texture
		quad_material.emission_texture = face_texture  # Muster zeigt sich im Glühen (Albedo ist dunkel)
	edge_base = DieMaterial.tint_for(def.edge_material) if DieMaterial.is_valid_id(def.edge_material) else EDGE_COLOR
	if edge_material_res != null:
		var edge_texture := DieMaterial.die_texture_for(def.edge_material)
		edge_material_res.albedo_texture = edge_texture
		edge_material_res.emission_texture = edge_texture
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
		var glow_color := base * MATERIAL_FACE_GLOW if base != Color.WHITE else EDGE_NEON * FACE_GLOW
		_set_surface(material, body_tint, glow_color)
	if edge_material_res != null:
		# set_edge_tint schaltet für die Auswahl auf unschattiert - hier zurück.
		edge_material_res.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		var edge_glow := edge_base * MATERIAL_EDGE_GLOW if edge_base != EDGE_COLOR else EDGE_NEON * EDGE_GLOW
		_set_surface(edge_material_res, body_tint, edge_glow)
	_has_material = edge_base != EDGE_COLOR
	for axis in face_base:
		if face_base[axis] != Color.WHITE:
			_has_material = true
	if shell_material != null:
		var mix := _neon_mix() * body_tint
		shell_material.set_shader_parameter("glow_color", Vector3(mix.r, mix.g, mix.b))
		shell_material.set_shader_parameter("strength",
			SHELL_STRENGTH_MATERIAL if _has_material else SHELL_STRENGTH)
	_refresh_die_light()

## Misch-Neonfarbe des Würfels: neutral Cyan, sonst der Schnitt aller Material-Tints.
func _neon_mix() -> Color:
	var tints: Array[Color] = []
	if edge_base != EDGE_COLOR:
		tints.append(edge_base)
	for axis in face_base:
		if face_base[axis] != Color.WHITE:
			tints.append(face_base[axis])
	if tints.is_empty():
		return EDGE_NEON
	var mixed := Color(0, 0, 0)
	for tint in tints:
		mixed += tint
	return mixed / float(tints.size())

## Dunkler Glas-Körper überall gleich; das Licht liegt allein in der Emission.
## tint moduliert beides (Auswahl-/Stil-Tints bleiben so auf dem Neon sichtbar).
static func _set_surface(material: StandardMaterial3D, tint: Color, glow_color: Color) -> void:
	material.albedo_color = BODY_COLOR * tint
	material.emission = glow_color * tint

## Schaltet Umgebungslicht + Boden-Lache frei (nur Spielwürfel).
func set_light_enabled(on: bool) -> void:
	light_allowed = on
	_refresh_die_light()

## Je Frame: Kanten-Neon atmet langsam; die Boden-Lache folgt dem Würfel und
## verblasst mit seiner Flughöhe.
func _process(delta: float) -> void:
	_pulse_phase = fmod(_pulse_phase + delta * PULSE_SPEED, TAU)
	if edge_material_res != null:
		var amount := PULSE_AMOUNT_MATERIAL if _has_material else PULSE_AMOUNT
		edge_material_res.emission_energy_multiplier = 1.0 + sin(_pulse_phase) * amount
	if glow_pool == null or not glow_pool.visible:
		return
	var center := global_position
	var height := maxf(0.0, center.y - POOL_REST_Y)
	var fade := clampf(1.0 - height * POOL_FADE_PER_UNIT, 0.0, 1.0)
	glow_pool.global_position = Vector3(center.x, POOL_Y, center.z)
	glow_pool.scale = Vector3.ONE * (1.0 + height * 0.08)
	pool_material.albedo_color = Color(_pool_color.r, _pool_color.g, _pool_color.b, _pool_color.a * fade)

## Licht aus dem Zustand: Material-Tints mischen sich zur Lichtfarbe und
## leuchten stark; ohne Material bleibt ein schwacher warmweißer Schein.
func _refresh_die_light() -> void:
	if die_light == null:
		return
	die_light.visible = light_allowed
	if glow_pool != null:
		glow_pool.visible = light_allowed
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
	else:
		var mixed := Color(0, 0, 0)
		for tint in tints:
			mixed += tint
		mixed /= float(tints.size())
		die_light.light_color = mixed * body_tint
		die_light.light_energy = LIGHT_MATERIAL_ENERGY
	# Lachen-Farbe folgt dem Licht; Stärke seiner Energie.
	var c := die_light.light_color
	_pool_color = Color(c.r, c.g, c.b, POOL_ALPHA_PER_ENERGY * die_light.light_energy)

## Färbt den Kanten-Rahmen absolut (Kanten-Auswahl der Gravur-Station).
## Unschattiert, damit exakt die flache Auswahl-Farbe erscheint - beleuchtet
## klemmt derselbe Wert je nach Licht unterschiedlich weg. set_tint stellt
## danach die normale Rahmenfarbe wieder her.
func set_edge_tint(color: Color) -> void:
	if edge_material_res != null:
		edge_material_res.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		edge_material_res.albedo_color = color
		edge_material_res.emission = Color.BLACK  # flach: kein Neon über der Auswahl

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
