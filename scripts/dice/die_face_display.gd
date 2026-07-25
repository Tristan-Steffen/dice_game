class_name DieFaceDisplay
extends Node3D
## Hält die 6 Gesichter eines Würfels (Körper-Quad + Label3D-Ziffer je Seite)
## plus Kanten-Rahmen und Würfel-Licht. Ziffern werden zur Laufzeit gesetzt,
## damit jeder Wert darstellbar ist. quads/labels befüllt DieBuilder.

## Tron-Prinzip: dunkle Masse, konzentriertes Licht. Der Körper ist dunkles
## Glas (Albedo überall gleich), NUR Kanten-Linien und Ziffern leuchten -
## breite Flächen glimmen kaum. Material-Seiten brechen die Regel bewusst:
## sie sind Einlagen aus echtem Material (helle Albedo + eigene Physik aus
## DieMaterial.surface_color/metallic/roughness/glow/alpha statt nur Neon-Tint).
const BODY_COLOR := Color(0.05, 0.05, 0.08)
## Ziffern als sanftes Neonlicht (knapp überhell -> weicher Bloom, nicht grell).
const NUMBER_COLOR := Color(1.15, 1.14, 1.0)
## Sentinel "kein Kanten-Material" (Vergleichswert, siehe edge_base).
const EDGE_COLOR := Color(0.8, 0.8, 0.83)
## Neutrale Neon-Linienfarbe der Kanten: gesättigtes Mint. Blasse Töne
## bleiben bei dieser Emission nur weiße Klumpen, und der Grünstich hält
## die kahle Kante vom Cyan des Glas-Materials getrennt.
const EDGE_NEON := Color(0.42, 0.95, 0.66)
## Emissions-Stärken. Die KANTEN sind die Lichtquelle des Würfels: sie
## brennen weit über Weiß, die breiten Flächen glimmen nur. So liest man
## das Kanten-Material noch aus der Übersichtskamera.
const FACE_GLOW := 0.09
const EDGE_GLOW := 1.5
## Distanz-Signale: der Seiten-Rahmen leuchtet voll in Materialfarbe, und
## Material-Kanten glühen mindestens so stark - dünne Linien ohne Emission
## sind aus der Übersichtskamera unsichtbar. Ausnahme: glow == 0 (Knochen)
## bleibt bewusst tot-dunkel, seine Identität.
const FRAME_GLOW := 1.4
## Kanten-Material leuchtet IMMER kräftig, auch wenn das Profil selbst kaum
## glüht (Gold 0.26, Quecksilber 0.22) - die Kante ist die Lampe, nicht die
## Oberfläche. Liegt bewusst ÜBER EDGE_GLOW: eine veredelte Kante muss die
## kahle überstrahlen, sonst kehrt sich die Rangfolge um. Ausnahme bleibt
## glow == 0 (Knochen).
const MATERIAL_EDGE_GLOW_FLOOR := 2.0
## Am Würfel tragen die Farben kräftiger als in der UI: Sättigung und
## Helligkeit werden angehoben, bevor sie in Emission, Licht und Schimmer
## gehen. DieMaterial.tint bleibt unangetastet - es ist die UI-Quelle
## (Würfelnetz, Shop, Hinweise) und soll dort ruhig bleiben.
const DIE_SATURATION := 1.2
const DIE_VALUE := 1.12

## Neutrale Oberflächen-Physik (Material-Seiten bringen ihre eigene mit).
const FACE_ROUGHNESS := 0.2
const EDGE_ROUGHNESS := 0.25
const EDGE_METALLIC := 0.35

## Echtes Umgebungslicht des Würfels - nur für die Spielwürfel aktiv, die
## 30+ Tray-Würfel würden das Per-Objekt-Lichtlimit des Renderers sprengen.
## Eng und hart abfallend: eine sichtbare Licht-Lache UNTER dem Würfel erdet
## ihn (die Neon-Version eines Kontaktschattens).
## Im dunklen Raum sind die Würfel echte Lampen: kräftiger und weiter als es
## die alte, hell beleuchtete Szene vertragen hätte.
## Ein Kanten-Material bestimmt die Lichtfarbe ALLEIN und brennt am
## hellsten: das Licht im Raum verrät die Kante, nicht die Seiten.
const LIGHT_BASE_COLOR := Color(0.82, 0.86, 0.72)
const LIGHT_BASE_ENERGY := 2.0
const LIGHT_MATERIAL_ENERGY := 3.0
const LIGHT_EDGE_ENERGY := 4.2
const LIGHT_RANGE := 7.0

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
var frames: Dictionary = {}  # Achse -> MeshInstance3D (Material-Leuchtrahmen)
## Eck-Kappen der Kanten (Silhouetten-Signal); nur mit Kanten-Material sichtbar.
var corner_caps: Node3D = null
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
## Material-id je Achse ("" = ohne) bzw. der Kanten - Schlüssel ins Shading-Profil.
var face_ids: Dictionary = {}
var edge_id: String = ""
## Fließende Oberflächen (Quecksilber): [StandardMaterial3D, Drift/s].
var _flow_mats: Array = []
var _flow_time := 0.0

## Stellt alle 6 Seiten gemäß def ein (Werte, Material-Farben, Texturen).
func apply_definition(def: DieDefinition) -> void:
	_flow_mats.clear()
	for axis in DiceController.AXIS_FACE_INDEX:
		var face_index: int = DiceController.AXIS_FACE_INDEX[axis]
		var value: int = def.faces[face_index] if face_index < def.faces.size() else 1
		_set_face_value(axis, value)
		var material_id: String = def.materials[face_index] if face_index < def.materials.size() else ""
		face_ids[axis] = material_id
		face_base[axis] = DieMaterial.tint_for(material_id)
		# Ziffern bleiben neutral-weiß, egal welches Material - Materialfarben
		# machten die Zahl schwer lesbar (die Identität tragen Fläche/Rahmen/Kanten).
		labels[axis].modulate = NUMBER_COLOR
		var quad_material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
		_set_textures(quad_material, material_id)
	edge_id = def.edge_material if DieMaterial.is_valid_id(def.edge_material) else ""
	edge_base = DieMaterial.tint_for(edge_id) if edge_id != "" else EDGE_COLOR
	if edge_material_res != null:
		_set_textures(edge_material_res, def.edge_material)
	_refresh_face_colors()

## Muster + Relief einer Oberfläche; Emission teilt die Albedo-Textur, damit
## das Muster auch im Glühen sichtbar bleibt (Albedo ist ohne Material dunkel).
func _set_textures(material: StandardMaterial3D, material_id: String) -> void:
	var texture := DieMaterial.die_texture_for(material_id)
	material.albedo_texture = texture
	material.emission_texture = texture
	var normal := DieMaterial.die_normal_for(material_id)
	material.normal_enabled = normal != null
	material.normal_texture = normal
	var profile := DieMaterial.by_id(material_id)
	if profile != null and profile.flow_speed > 0.0:
		_flow_mats.append([material, profile.flow_speed])
	else:
		material.uv1_offset = Vector3.ZERO

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
		var profile := DieMaterial.by_id(face_ids.get(axis, ""))
		var material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
		_apply_profile(material, profile, false)
		_refresh_frame(axis, profile)
	if edge_material_res != null:
		# set_edge_tint schaltet für die Auswahl auf unschattiert - hier zurück.
		edge_material_res.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_apply_profile(edge_material_res, DieMaterial.by_id(edge_id), true)
	if corner_caps != null:
		corner_caps.visible = edge_id != ""
	_has_material = edge_base != EDGE_COLOR
	for axis in face_base:
		if face_base[axis] != Color.WHITE:
			_has_material = true
	if shell_material != null:
		var mix := intense(_neon_mix()) * body_tint
		shell_material.set_shader_parameter("glow_color", Vector3(mix.r, mix.g, mix.b))
		shell_material.set_shader_parameter("strength",
			SHELL_STRENGTH_MATERIAL if _has_material else SHELL_STRENGTH)
	_refresh_die_light()

## Würfel-Farbe: kräftiger als der UI-Tint (siehe DIE_SATURATION). Wird auf
## alles gelegt, was Licht trägt - Emission, Würfellicht, Fresnel-Schimmer.
static func intense(color: Color) -> Color:
	var c := color
	c.s = clampf(c.s * DIE_SATURATION, 0.0, 1.0)
	c.v = clampf(c.v * DIE_VALUE, 0.0, 1.0)
	return c

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

## Ohne Material: dunkler Glas-Körper, das Licht liegt allein in der Emission.
## Mit Material: die Einlage trägt die echte Oberfläche aus dem Profil.
## body_tint moduliert beides (Auswahl-/Stil-Tints bleiben sichtbar).
func _apply_profile(material: StandardMaterial3D, profile: DieMaterial, is_edge: bool) -> void:
	if profile == null:
		material.albedo_color = BODY_COLOR * body_tint
		material.emission = intense(EDGE_NEON) * (EDGE_GLOW if is_edge else FACE_GLOW) * body_tint
		material.metallic = EDGE_METALLIC if is_edge else 0.0
		material.roughness = EDGE_ROUGHNESS if is_edge else FACE_ROUGHNESS
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		return
	var albedo := profile.surface_color * body_tint
	# Kanten bleiben deckend - der Füllkörper hinter ihnen IST die Würfelmasse.
	if not is_edge and profile.alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		albedo.a = profile.alpha
	else:
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.albedo_color = albedo
	var glow := profile.glow
	if is_edge and glow > 0.0:
		glow = maxf(glow, MATERIAL_EDGE_GLOW_FLOOR)
	material.emission = intense(profile.tint) * glow * body_tint
	material.metallic = profile.metallic
	material.roughness = profile.roughness

## Leucht-Rahmen der Seite: sichtbar nur mit Material, Linie in Materialfarbe.
func _refresh_frame(axis: String, profile: DieMaterial) -> void:
	var frame: MeshInstance3D = frames.get(axis)
	if frame == null:
		return
	frame.visible = profile != null
	if profile == null:
		return
	var material: StandardMaterial3D = frame.material_override
	material.albedo_color = BODY_COLOR * body_tint
	var glow := FRAME_GLOW if profile.glow > 0.0 else 0.0
	material.emission = intense(profile.tint) * glow * body_tint

## Schaltet Umgebungslicht + Boden-Lache frei (nur Spielwürfel).
func set_light_enabled(on: bool) -> void:
	light_allowed = on
	_refresh_die_light()

## Je Frame: Kanten-Neon atmet langsam, Quecksilber-Oberflächen fließen; die
## Boden-Lache folgt dem Würfel und verblasst mit seiner Flughöhe.
func _process(delta: float) -> void:
	_pulse_phase = fmod(_pulse_phase + delta * PULSE_SPEED, TAU)
	if edge_material_res != null:
		var amount := PULSE_AMOUNT_MATERIAL if _has_material else PULSE_AMOUNT
		edge_material_res.emission_energy_multiplier = 1.0 + sin(_pulse_phase) * amount
	_flow_time += delta
	for entry in _flow_mats:
		var material: StandardMaterial3D = entry[0]
		var speed: float = entry[1]
		# Schräge Drift + leichtes Pendeln = träges Fließen statt Förderband.
		material.uv1_offset = Vector3(
			fmod(_flow_time * speed, 1.0),
			fmod(_flow_time * speed * 0.63, 1.0) + sin(_flow_time * 0.9) * 0.03,
			0.0)
	if glow_pool == null or not glow_pool.visible:
		return
	var center := global_position
	var height := maxf(0.0, center.y - POOL_REST_Y)
	var fade := clampf(1.0 - height * POOL_FADE_PER_UNIT, 0.0, 1.0)
	glow_pool.global_position = Vector3(center.x, POOL_Y, center.z)
	glow_pool.scale = Vector3.ONE * (1.0 + height * 0.08)
	pool_material.albedo_color = Color(_pool_color.r, _pool_color.g, _pool_color.b, _pool_color.a * fade)

## Licht aus dem Zustand: das Kanten-Material gibt die Farbe allein vor,
## sonst mitteln die Seiten-Tints; ganz ohne Material bleibt ein schwacher
## warmweißer Schein.
func _refresh_die_light() -> void:
	if die_light == null:
		return
	die_light.visible = light_allowed
	if glow_pool != null:
		glow_pool.visible = light_allowed
	if not light_allowed:
		return
	# Kanten-Material schlägt alles: es ist die Lampe, also gibt es die Farbe
	# unvermischt vor. Erst ohne Kante mitteln die Seiten-Tints wie bisher.
	if edge_base != EDGE_COLOR:
		die_light.light_color = intense(edge_base) * body_tint
		die_light.light_energy = LIGHT_EDGE_ENERGY
	else:
		var tints: Array[Color] = []
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
			die_light.light_color = intense(mixed) * body_tint
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
