class_name DieFaceDisplay
extends Node3D
## Hält die 6 Gesichter eines Würfels (Körper-Quad + Label3D-Ziffer je Seite)
## plus Kanten-Rahmen und Boden-Lache. Ziffern werden zur Laufzeit gesetzt,
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
## Neutrale Linienfarbe der Kanten: Weiß. Kahle Kanten leuchten bewusst
## UNTER der Bloom-Schwelle (EDGE_GLOW) - dadurch bleiben sie weiße Linien
## statt eines farbigen Klumpens und treten hinter jede veredelte Kante
## zurück.
const EDGE_NEON := Color(0.95, 0.96, 0.98)
## Emissions-Stärken. Die KANTEN sind die Lichtquelle des Würfels, die
## breiten Flächen glimmen nur. Kahle Kanten bleiben unter der
## Bloom-Schwelle (glow_hdr_threshold 0.95) - der blanke Würfel soll gar
## nicht strahlen; erst ein Material hebt ihn darüber. Das Weittragende ist
## ohnehin das Würfellicht, nicht die Emission.
const FACE_GLOW := 0.06
const EDGE_GLOW := 0.7
## Distanz-Signale: der Seiten-Rahmen leuchtet voll in Materialfarbe, und
## Material-Kanten glühen mindestens so stark - dünne Linien ohne Emission
## sind aus der Übersichtskamera unsichtbar. Ausnahme: glow == 0 (Knochen)
## bleibt bewusst tot-dunkel, seine Identität.
const FRAME_GLOW := 0.95
## Kanten-Material leuchtet IMMER kräftig, auch wenn das Profil selbst kaum
## glüht (Gold 0.26, Quecksilber 0.22) - die Kante ist die Lampe, nicht die
## Oberfläche. Liegt bewusst ÜBER EDGE_GLOW: eine veredelte Kante muss die
## kahle überstrahlen, sonst kehrt sich die Rangfolge um. Ausnahme bleibt
## glow == 0 (Knochen).
const MATERIAL_EDGE_GLOW_FLOOR := 1.15
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

## Der Würfel wirft KEIN echtes Licht mehr. Ein OmniStrahler beleuchtete in
## dieser Szene nur die anderen Würfel (Grubenboden, Wände und Screens sind
## unshaded): in einer Reihe aus sechs veredelten Würfeln addierten sich die
## Strahler, bis die mittleren weiß auswuschen. Er zwang außerdem die
## Ungleichheit, denn 30+ Tray-Würfel hätten das Per-Objekt-Lichtlimit
## gesprengt - ein Würfel sah in der Grube anders aus als im Tray. Ohne ihn
## ist das Aussehen eines Würfels überall dasselbe: reine Emission.
## Was bleibt, ist die Lache auf dem Grubenboden - eine Bodenerscheinung,
## kein Licht am Würfel.
## Ein Kanten-Material bestimmt ihre Farbe ALLEIN und leuchtet am stärksten:
## der Schein auf dem Tisch verrät die Kante, nicht die Seiten. Ohne
## Material trägt er den Ton, den die kahlen Kanten zeigen.
const POOL_BASE_COLOR := EDGE_NEON
const POOL_BASE_STRENGTH := 0.4
const POOL_MATERIAL_STRENGTH := 0.7
const POOL_EDGE_STRENGTH := 0.9

## Additive Lache am Boden: folgt dem Würfel und verblasst mit seiner
## Flughöhe - die Erdung des Würfels auf dem Tisch.
const POOL_Y := 0.03          # knapp über der Tischfläche
const POOL_REST_Y := 1.0      # Körpermitte in Ruhelage (= DieBuilder.HALF_EXTENT)
## Verblassen mit der Flughöhe: soll den GEWORFENEN Würfel in der Luft
## ausblenden, nicht den Tray-Würfel, der dauerhaft ein Stück über der
## Tischfläche schwebt - darum flach.
const POOL_FADE_PER_UNIT := 0.1
## Kantenlänge der Lache in Würfel-Halbbreiten - sie ist das Weitreichende
## am Würfellicht. Darf großzügig sein: set_pool_clip klemmt sie auf den
## Grubeninnenraum, sie kann also nicht auf Filz und Screens auslaufen.
const POOL_SPAN := 26.0
## Bewusst niedrig: die Lachen sind additiv und JEDER Würfel wirft eine -
## im Vorrats-Tray stehen 30 Stück dicht an dicht. Einzeln kräftig hieße
## dort ein weißes Feld.
const POOL_ALPHA_PER_STRENGTH := 0.09

## Atem des Kanten-Neons (statisches Leuchten wirkt aufgemalt, atmendes bestromt).
const PULSE_SPEED := 1.4       # rad/s ~ ruhiger Atem
const PULSE_AMOUNT := 0.08
const PULSE_AMOUNT_MATERIAL := 0.16

## Fresnel-Hüllen-Stärke: die Farbabstrahlung des Würfels. Ein Kanten-
## Material strahlt am kräftigsten, Seiten-Material schwächer, der blanke
## Würfel nur einen Hauch - dieselbe Rangfolge wie bei Kanten und Lache.
const SHELL_STRENGTH := 0.45
const SHELL_STRENGTH_MATERIAL := 1.2
const SHELL_STRENGTH_EDGE := 1.8

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
## Lache an? Standard JA - jeder Würfel wirft seinen Schein auf den Tisch,
## in der Grube wie im Tray. Aus nur dort, wo kein Tisch darunter liegt
## (Inspektor-Vorschau, Listen-Miniaturen, Taumel-Würfel in der Hülle).
var pool_allowed: bool = true
## Glanz-Lache (top_level-Quad am Boden) + ihr Material; befüllt DieBuilder.
var glow_pool: MeshInstance3D = null
var pool_material: ShaderMaterial = null
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
		# Gleiche Regel wie bei der Lache: ein Kanten-Material gibt die Farbe
		# allein vor, sonst mitteln die Seiten-Tints.
		var mix := intense(edge_base if edge_base != EDGE_COLOR else _neon_mix()) * body_tint
		shell_material.set_shader_parameter("glow_color", Vector3(mix.r, mix.g, mix.b))
		shell_material.set_shader_parameter("strength", _shell_strength())
	_refresh_pool()

## Würfel-Farbe: kräftiger als der UI-Tint (siehe DIE_SATURATION). Wird auf
## alles gelegt, was Licht trägt - Emission, Würfellicht, Fresnel-Schimmer.
static func intense(color: Color) -> Color:
	var c := color
	c.s = clampf(c.s * DIE_SATURATION, 0.0, 1.0)
	c.v = clampf(c.v * DIE_VALUE, 0.0, 1.0)
	return c

## Abstrahl-Stärke nach der Rangfolge kahl < Seiten-Material < Kanten-Material.
## Knochen strahlt nie - glow == 0 ist seine Identität.
func _shell_strength() -> float:
	var edge_profile := DieMaterial.by_id(edge_id)
	if edge_profile != null:
		return SHELL_STRENGTH_EDGE if edge_profile.glow > 0.0 else 0.0
	return SHELL_STRENGTH_MATERIAL if _has_material else SHELL_STRENGTH

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

## Grenzen des Bodens, auf den die Lache fällt (abgerundetes Rechteck in
## Weltkoordinaten). Setzt scene_root aus den Grubenmaßen - die Würfel
## selbst kennen die Grube nicht.
func set_pool_clip(center: Vector3, half_extent: Vector2, corner_radius: float) -> void:
	if pool_material == null:
		return
	pool_material.set_shader_parameter("clip_center", Vector2(center.x, center.z))
	pool_material.set_shader_parameter("clip_half", half_extent)
	pool_material.set_shader_parameter("clip_radius", corner_radius)

## Schaltet die Boden-Lache ab (siehe pool_allowed) - für Würfel ohne Tisch
## unter sich.
func set_pool_enabled(on: bool) -> void:
	pool_allowed = on
	_refresh_pool()

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
	# Ohne Baum gibt es keine Welttransformation - die Lache braucht beides.
	if glow_pool == null or not glow_pool.visible or not is_inside_tree():
		return
	var center := global_position
	# Ruhehöhe skaliert mit dem Würfel - sonst gilt ein kleiner Tray-Würfel
	# schon im Sitzen als "fliegend" und seine Lache verblasst grundlos.
	var scale_factor := _die_scale()
	var height := maxf(0.0, center.y - POOL_REST_Y * scale_factor)
	var fade := clampf(1.0 - height * POOL_FADE_PER_UNIT, 0.0, 1.0)
	glow_pool.global_position = Vector3(center.x, POOL_Y, center.z)
	# top_level erbt keine Skalierung: die Größe des Würfels muss von Hand
	# durchgereicht werden, sonst wirft ein Tray-Würfel dieselbe Riesenlache
	# wie ein Spielwürfel und 30 Stück im Raster waschen den Tisch aus.
	glow_pool.scale = Vector3.ONE * scale_factor * (1.0 + height * 0.08)
	pool_material.set_shader_parameter("tint",
		Vector4(_pool_color.r, _pool_color.g, _pool_color.b, _pool_color.a * fade))

## Weltskalierung des Würfels (Tray und Grube tragen DiceTrayView.DIE_SCALE).
func _die_scale() -> float:
	var basis_scale := global_basis.get_scale()
	return maxf(basis_scale.x, 0.01)

## Farbe und Stärke der Boden-Lache aus dem Zustand: das Kanten-Material gibt
## die Farbe allein vor, sonst mitteln die Seiten-Tints; ganz ohne Material
## bleibt der Ton der kahlen Kanten.
func _refresh_pool() -> void:
	if glow_pool == null:
		return
	glow_pool.visible = pool_allowed
	if not pool_allowed:
		return
	var color: Color
	var strength: float
	if edge_base != EDGE_COLOR:
		color = intense(edge_base)
		strength = POOL_EDGE_STRENGTH
	else:
		var tints: Array[Color] = []
		for axis in face_base:
			if face_base[axis] != Color.WHITE:
				tints.append(face_base[axis])
		if tints.is_empty():
			color = intense(POOL_BASE_COLOR)
			strength = POOL_BASE_STRENGTH
		else:
			var mixed := Color(0, 0, 0)
			for tint in tints:
				mixed += tint
			color = intense(mixed / float(tints.size()))
			strength = POOL_MATERIAL_STRENGTH
	color *= body_tint
	_pool_color = Color(color.r, color.g, color.b, POOL_ALPHA_PER_STRENGTH * strength)

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
