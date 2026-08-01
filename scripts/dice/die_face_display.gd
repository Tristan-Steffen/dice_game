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
## Vorläufiger Wert (Verwandlungs-Charm in der Grube, Gravur-Vorschau an der
## Werkbank): grüne Ziffer = eine Zahl, die NICHT in der Def steht. Eine Quelle
## für beide Orte, damit "grün heißt vorläufig" überall dasselbe Grün ist.
const PREVIEW_NUMBER_COLOR := Color(0.5, 1.0, 0.6)
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

## Leiterbahn auf dem Würfel (PCB-Grammatik des Tisches): EIN durchgehendes
## Band je Zeiger - Pad auf der Quellseite, über den Kantenbalken hinweg, bis
## zur Pfeilspitze auf der Zielseite. Überall gleich breit: die gequerte Kante
## darf keine dickere Stelle sein, sonst zerfällt das Kabel in Einzelteile.
## Kräftiger als das UI-Cyan #8be9fd (Netz/Siegel): auf den fast weißen
## Kantenbalken ginge das blasse Cyan unter - dieselbe Regel wie DIE_SATURATION.
const POINTER_COLOR := Color("#00d9ff")
## Kamm der Chevrons: ÜBER der Bloom-Schwelle (0.95), aber unter dem Boden der
## Material-Kanten - die veredelte Kante bleibt die hellste Lampe des Würfels.
const POINTER_GLOW := 1.08
## Rille zwischen den Chevrons: deutlich UNTER der Schwelle. Der Kontrast nach
## unten IST die Lesbarkeit der Strömung - liegt schon der Grund am Klemmwert,
## säuft die Bewegung in Weiß ab.
const POINTER_TROUGH := 0.3
const TRACE_WIDTH := 0.18
## Führung in der Ebene, die Quell- und Zielrichtung aufspannen; Anteile der
## Halbkante (DieBuilder.HALF_EXTENT = 1). FACE_RIDE liegt über der Ziffer
## (Quad 1.02 + Label 0.01), BEAM_RIDE über dem Kantenbalken (1.13), WALL_B am
## Rand des Seiten-Quads (0.87). Die Werte sind bewusst hier und nicht aus
## DieBuilder importiert - das ergäbe eine zirkuläre class_name-Referenz.
const FACE_RIDE := 1.035
const BEAM_RIDE := 1.17
const WALL_B := 0.86
const FILLET := 0.05
const FILLET_STEPS := 5
## Bahn-Ende auf der Seite: das Band greift nur ein FÜNFTEL der Seitenfläche
## hinter den Quad-Rand (WALL_B − FACE_SIZE/5 ≈ 0.51) - kein Pfeil, keine
## lange Zunge bis zur Ziffer. Die Richtung trägt allein die Strömung im
## Shader (Chevron-Wellen zur Zielseite, siehe die_pointer_trace.gdshader).
const TRACE_START := 0.51

## Interne Glyphen-Auflösung (Font-Atlas-Pixel) - Weltgröße steuert pixel_size.
const LABEL_FONT_SIZE := 160
## Basis-Umrechnung Font-Pixel -> Welteinheiten (Höhe einer einstelligen Ziffer).
const LABEL_PIXEL_SIZE := 0.0085
## Nutzbare Kantenlänge des Ziffernfelds (< DieBuilder.FACE_SIZE).
const LABEL_FIT_EXTENT := 1.5
## Dunkler Saum der Ziffer in Font-Pixeln (12.5 % von LABEL_FONT_SIZE): das
## Trennband gegen auslaufenden Riss-Bloom. Mehr macht die Zahl fett, weniger
## trennt bei voller Naht-Breite nicht mehr.
const LABEL_OUTLINE_SIZE := 20

var quads: Dictionary = {}   # Achse -> MeshInstance3D (Körper-Quad)
var labels: Dictionary = {}  # Achse -> Label3D (Augenzahl)
var frames: Dictionary = {}  # Achse -> MeshInstance3D (Material-Leuchtrahmen)
var rift_overlays: Dictionary = {}  # Achse -> MeshInstance3D (Riss-Auflage)
## Zweite Auflage NUR für Vakuum-Würfel (zwei Brüche je Seite), faul gebaut.
var rift_overlays_second: Dictionary = {}
## Eck-Kappen der Kanten (Silhouetten-Signal); nur mit Essenz sichtbar.
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
## Spanne, über die das Polarlicht seinen Farbton wandern lässt (Grün -> Violett).
const AURORA_HUE_SPAN := 0.22

## Zweiter Bruch des Vakuum-Würfels: knapp vor dem ersten, hinter der Ziffer.
const SECOND_RIFT_DEPTH := 0.0085
## Verbreiterung der Ziffern-Sperrzone je zusätzlicher Stelle (§2.4): eine
## zweistellige Zahl beansprucht ~0.375 statt 0.26 halbe Breite.
const GLYPH_DIGIT_WIDEN := 0.115

## Lebendiges Licht: das Kanten-Neon atmet langsam - Material-Würfel stärker.
var _pulse_phase := randf() * TAU
var _has_material := false

## Material-Grundfarbe je Achse (Weiß = kein Material); body_tint
## multipliziert darüber, damit Material-Seiten unter jeder Tönung sichtbar bleiben.
var face_base: Dictionary = {}
var edge_base: Color = EDGE_COLOR
var body_tint: Color = Color.WHITE
## Material-id je Achse ("" = ohne) - Schlüssel ins Shading-Profil.
var face_ids: Dictionary = {}
## Materialstufe je Achse (1..3). Die Stufe färbt NUR - satter statt heller,
## damit sie neben dem Essenzglühen als eigenes Signal lesbar bleibt.
var face_levels: Dictionary = {}
## Essenz des Würfels ("" = keine): sie allein färbt die Kanten.
var essence_id: String = ""

## Je Zeiger EIN Band (Kind des Displays, nicht eines Quads - es spannt über
## zwei Seiten). Alle teilen ein Material: der Lichtlauf des Würfels ist EIN
## Takt, und ein Zeiger kennt seine Stellung in der Kette ohnehin nicht (die
## obere Seite bestimmt erst die Physik).
var pointer_traces: Array[MeshInstance3D] = []
var pointer_material: ShaderMaterial = null

## Stellt alle 6 Seiten gemäß def ein (Werte, Material-Farben, Texturen).
func apply_definition(def: DieDefinition) -> void:
	for axis in DiceController.AXIS_FACE_INDEX:
		var face_index: int = DiceController.AXIS_FACE_INDEX[axis]
		var value: int = def.faces[face_index] if face_index < def.faces.size() else 1
		_set_face_value(axis, value)
		var material_id: String = def.materials[face_index] if face_index < def.materials.size() else ""
		face_ids[axis] = material_id
		var level := def.material_level(face_index)
		face_levels[axis] = level
		# Lache, Fresnel-Hülle und _neon_mix erben die Sättigung von hier.
		face_base[axis] = DieMaterial.tint_for(material_id, level)
		# Ziffern bleiben neutral-weiß, egal welches Material - Materialfarben
		# machten die Zahl schwer lesbar (die Identität tragen Fläche/Rahmen/Kanten).
		labels[axis].modulate = NUMBER_COLOR
		var quad_material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
		_set_textures(quad_material, material_id)
	essence_id = def.essence_id if Essence.is_valid_id(def.essence_id) else ""
	edge_base = Essence.glow_for(essence_id) if essence_id != "" else EDGE_COLOR
	if edge_material_res != null:
		_set_textures(edge_material_res, "")
	_refresh_rift_overlays(def)
	_rebuild_pointer_traces(def)
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
	material.uv1_offset = Vector3.ZERO

func _set_face_value(axis: String, value: int) -> void:
	var label: Label3D = labels[axis]
	label.text = str(value)
	DieFaceDisplay.fit_label(label)
	_sync_glyph_guard(axis)

## Schreibt die Ziffer EINER Seite abweichend von der Def (Anzeige-
## Überschreibung: Verwandlungs-Charm, Wertwandel während des Zählens).
## apply_definition stellt den Def-Wert wieder her.
func set_face_value_at(face_index: int, value: int) -> void:
	for axis in labels:
		if DiceController.AXIS_FACE_INDEX[axis] == face_index:
			_set_face_value(axis, value)
			return

## Färbt den Körper aller 6 Seiten (Color.WHITE = Normalzustand); Ziffern bleiben dunkel.
func set_tint(color: Color) -> void:
	body_tint = color
	_refresh_face_colors()

func _refresh_face_colors() -> void:
	for axis in quads:
		var profile := DieMaterial.by_id(face_ids.get(axis, ""))
		var level: int = face_levels.get(axis, 1)
		var material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
		_apply_profile(material, profile, false, level)
		_refresh_frame(axis, profile, level)
	_apply_essence_edge()
	if corner_caps != null:
		corner_caps.visible = essence_id != ""
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

## Abstrahl-Stärke nach der Rangfolge kahl < Seiten-Material < Essenz: das Gas
## glüht dauernd, und zwar heller als jede Einlage.
func _shell_strength() -> float:
	if essence_id != "":
		return SHELL_STRENGTH_EDGE
	return SHELL_STRENGTH_MATERIAL if _has_material else SHELL_STRENGTH

## Kantenglühen der Essenz: die Kanten sind kein Ausbau-Slot mehr, sondern die
## Bühne, auf der die Seele leuchtet - essenzlose Würfel behalten das neutrale
## Neon. set_edge_tint schaltet für die Auswahl auf unschattiert, darum hier zurück.
func _apply_essence_edge() -> void:
	if edge_material_res == null:
		return
	edge_material_res.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_apply_profile(edge_material_res, null, true)
	if essence_id == "":
		return
	edge_material_res.emission = intense(edge_base) * MATERIAL_EDGE_GLOW_FLOOR * body_tint

## Misch-Neonfarbe des Würfels: neutral Cyan, sonst Essenz + Material-Tints gemittelt.
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
func _apply_profile(material: StandardMaterial3D, profile: DieMaterial, is_edge: bool,
		level := 1) -> void:
	if profile == null:
		material.albedo_color = BODY_COLOR * body_tint
		material.emission = intense(EDGE_NEON) * (EDGE_GLOW if is_edge else FACE_GLOW) * body_tint
		material.metallic = EDGE_METALLIC if is_edge else 0.0
		material.roughness = EDGE_ROUGHNESS if is_edge else FACE_ROUGHNESS
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		return
	var albedo := DieMaterial.saturated(profile.surface_color, level) * body_tint
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
	material.emission = intense(DieMaterial.saturated(profile.tint, level)) * glow * body_tint
	material.metallic = profile.metallic
	material.roughness = profile.roughness

## Risse der Seiten: sichtbar nur, wo ein Rift sitzt. In Ruhe schimmern sie
## schwach - erst im Moment ihres Feuerns flammen sie auf (flare_rifts). Genau
## diese zeitliche Signatur trennt sie vom DAUERND glühenden Essenz-Rand.
## Der Vakuum-Würfel trägt zwei Brüche je Seite; der zweite bekommt seine eigene
## Auflage, erst bei Bedarf gebaut und GESPIEGELT - so nehmen die beiden Brüche
## entgegengesetzte Ränder, statt sich im selben zu verheddern.
func _refresh_rift_overlays(def: DieDefinition) -> void:
	for axis in rift_overlays:
		var face_index: int = DiceController.AXIS_FACE_INDEX[axis]
		var on_face := def.rifts_on(face_index)
		_apply_rift_overlay(rift_overlays[axis], on_face, 0, def, false)
		var second: MeshInstance3D = rift_overlays_second.get(axis)
		if on_face.size() > 1:
			if second == null:
				second = DieBuilder.build_rift_overlay(SECOND_RIFT_DEPTH)
				quads[axis].add_child(second)
				rift_overlays_second[axis] = second
			_apply_rift_overlay(second, on_face, 1, def, true)
		elif second != null:
			second.visible = false
		_sync_glyph_guard(axis)

func _apply_rift_overlay(overlay: MeshInstance3D, on_face: Array[String], index: int,
		def: DieDefinition, mirrored: bool) -> void:
	overlay.visible = index < on_face.size()
	if not overlay.visible:
		return
	var rift_id: String = on_face[index]
	var rift := Rift.by_id(rift_id)
	# Die Essenz schlägt den Rift: auf einem Vakuum-Würfel saugt jeder Bruch.
	var profile := Rift.profile_for(rift_id, def.essence_id)
	if rift == null or profile == null:
		overlay.visible = false
		return
	var material: ShaderMaterial = overlay.material_override
	material.set_shader_parameter("crack_map", RiftTextures.for_pattern(rift.pattern))
	var seam := profile.normalized_seam()
	material.set_shader_parameter("seam_color", Vector3(seam.r, seam.g, seam.b))
	material.set_shader_parameter("core_color",
		Vector3(profile.core.r, profile.core.g, profile.core.b))
	material.set_shader_parameter("motion", profile.motion)
	material.set_shader_parameter("idle_low", profile.idle_low)
	material.set_shader_parameter("idle_high", profile.idle_high)
	material.set_shader_parameter("idle_speed", 1.0 / maxf(profile.idle_period, 0.01))
	material.set_shader_parameter("flare_peak", profile.flare_peak)
	material.set_shader_parameter("core_share", profile.core_share)
	material.set_shader_parameter("halo_width", profile.halo_width)
	material.set_shader_parameter("halo_flare", profile.halo_flare)
	material.set_shader_parameter("halo_bias", profile.halo_bias)
	# Je Würfel eine eigene Phase - 30 Tray-Würfel atmen nie im Gleichschritt.
	material.set_shader_parameter("phase", _pulse_phase)
	material.set_shader_parameter("mirror", mirrored)
	material.set_shader_parameter("flare", 0.0)
	material.set_shader_parameter("block_flare", false)

## Ziffern-Wächter (§2.4): eine zweistellige Zahl ist breiter, also wird die
## SPERRZONE breiter - nie die Figur. Knochen lässt Werte wachsen, und ein Riss,
## der sich beim Wachsen neu zeichnet, liest als Fehler.
func _sync_glyph_guard(axis: String) -> void:
	var label: Label3D = labels.get(axis)
	if label == null:
		return
	var digits := maxi(1, label.text.length())
	var half := Vector2(Rift.GLYPH_KEEPOUT.x + GLYPH_DIGIT_WIDEN * float(digits - 1),
		Rift.GLYPH_KEEPOUT.y)
	for store in [rift_overlays, rift_overlays_second]:
		var overlay: MeshInstance3D = store.get(axis)
		if overlay == null or not overlay.visible:
			continue
		(overlay.material_override as ShaderMaterial).set_shader_parameter("glyph_half", half)

## Lässt die Risse EINER Seite auflodern (0 = Ruhe, 1 = voller Ausbruch) -
## scene_root ruft das im Aktivierungs-Puls der Zählanimation. face_index < 0
## meint alle Seiten (Vorschau/Test); im Spiel feuert immer nur die OBERE, denn
## dort sitzt der Riss, der gewertet wird.
func flare_rifts(strength: float, face_index := -1, block := false) -> void:
	for axis in rift_overlays:
		if face_index >= 0 and DiceController.AXIS_FACE_INDEX[axis] != face_index:
			continue
		for store in [rift_overlays, rift_overlays_second]:
			var overlay: MeshInstance3D = store.get(axis)
			if overlay == null or not overlay.visible:
				continue
			var material: ShaderMaterial = overlay.material_override
			material.set_shader_parameter("flare", strength)
			material.set_shader_parameter("block_flare", block)

## Leucht-Rahmen der Seite: sichtbar nur mit Material, Linie in Materialfarbe.
func _refresh_frame(axis: String, profile: DieMaterial, level := 1) -> void:
	var frame: MeshInstance3D = frames.get(axis)
	if frame == null:
		return
	frame.visible = profile != null
	if profile == null:
		return
	var material: StandardMaterial3D = frame.material_override
	material.albedo_color = BODY_COLOR * body_tint
	var glow := FRAME_GLOW if profile.glow > 0.0 else 0.0
	material.emission = intense(DieMaterial.saturated(profile.tint, level)) * glow * body_tint

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
		# Polarlicht WANDERT: sein Farbton kriecht durchs Grünviolett, statt still
		# zu stehen - das einzige Glühen, das seine Farbe ändert.
		if essence_id == Essence.AURORA:
			var shifted := edge_base
			shifted.h = fmod(edge_base.h + _pulse_phase / TAU * AURORA_HUE_SPAN, 1.0)
			edge_material_res.emission = intense(shifted) * MATERIAL_EDGE_GLOW_FLOOR * body_tint
	# Die Leiterbahn-Strömung braucht hier nichts: sie läuft über TIME im
	# Shader, versetzt um die einmalig gesetzte phase (siehe _pointer_material).
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

# --- Leiterbahn-Spuren --------------------------------------------------------

## Achse eines Seiten-Index (Umkehrung von DiceController.AXIS_FACE_INDEX).
static func axis_of_face(face_index: int) -> String:
	for axis in DiceController.AXIS_FACE_INDEX:
		if DiceController.AXIS_FACE_INDEX[axis] == face_index:
			return axis
	return ""

## Baut alle Leiterbahnen aus def.pointers neu. Ein Zeiger auf eine
## Nicht-Nachbarseite (sollte nie vorkommen) bleibt stumm.
func _rebuild_pointer_traces(def: DieDefinition) -> void:
	for trace in pointer_traces:
		if is_instance_valid(trace):
			trace.queue_free()
	pointer_traces.clear()
	for face in def.pointers.size():
		var target: int = def.pointers[face]
		if target < 0:
			continue
		var src_axis := axis_of_face(face)
		var tgt_axis := axis_of_face(target)
		if src_axis == "" or tgt_axis == "":
			continue
		var d: Vector3 = DiceController.AXIS_DIRECTIONS[src_axis]
		var t: Vector3 = DiceController.AXIS_DIRECTIONS[tgt_axis]
		if not is_zero_approx(d.dot(t)):
			continue
		var trace := MeshInstance3D.new()
		trace.mesh = trace_mesh(src_axis, tgt_axis)
		trace.material_override = _pointer_material()
		trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(trace)
		pointer_traces.append(trace)

## Gemeinsames Material aller Bahnen dieses Würfels. phase versetzt die
## Strömung je Würfel (aus _pulse_phase) - danach läuft alles über TIME im
## Shader, ohne einen einzigen Frame-Aufruf von hier.
func _pointer_material() -> ShaderMaterial:
	if pointer_material == null:
		pointer_material = ShaderMaterial.new()
		pointer_material.shader = load("res://assets/shaders/die_pointer_trace.gdshader")
		var color := intense(POINTER_COLOR)
		pointer_material.set_shader_parameter("trace_color",
			Vector3(color.r, color.g, color.b))
		pointer_material.set_shader_parameter("crest_energy", POINTER_GLOW)
		pointer_material.set_shader_parameter("base_energy", POINTER_TROUGH)
		pointer_material.set_shader_parameter("phase", _pulse_phase / TAU)
	return pointer_material

## Stützstellen EINER Bahn in der Ebene (d, t): je [Vector2(Anteil d, Anteil t),
## halbe Bandbreite]. Ein kurzer Riegel über die Kante: ein Fünftel in die
## Quellseite, die Wand des Kantenbalkens hinauf, über dessen Außenseite,
## herunter und ein Fünftel in die Zielseite - immer knapp AUSSERHALB des
## Balkenquerschnitts, nie hindurch, und ÜBERALL gleich breit.
static func trace_samples() -> Array:
	var half := TRACE_WIDTH * 0.5
	# Ecken der Führung, danach verrundet - scharfe Knicke sähen wie Blech aus.
	var corners: Array[Vector2] = [
		Vector2(FACE_RIDE, TRACE_START),
		Vector2(FACE_RIDE, WALL_B),   # bis an die Balkenwand
		Vector2(BEAM_RIDE, WALL_B),   # die Wand hinauf
		Vector2(BEAM_RIDE, BEAM_RIDE),  # über die Außenecke
		Vector2(WALL_B, BEAM_RIDE),   # die andere Wand hinunter
		Vector2(WALL_B, FACE_RIDE),   # auf die Zielseite
		Vector2(TRACE_START, FACE_RIDE),
	]
	var samples: Array = []
	for point in _fillet(corners, FILLET, FILLET_STEPS):
		samples.append([point, half])
	return samples

## Verrundet die Ecken eines Polygonzugs (quadratische Bezier je Ecke).
static func _fillet(points: Array[Vector2], radius: float, steps: int) -> Array[Vector2]:
	var out: Array[Vector2] = [points[0]]
	for i in range(1, points.size() - 1):
		var p := points[i]
		var a := p + (points[i - 1] - p).normalized() * radius
		var b := p + (points[i + 1] - p).normalized() * radius
		out.append(a)
		for s in range(1, steps):
			var k := float(s) / float(steps)
			out.append(a.lerp(p, k).lerp(p.lerp(b, k), k))
		out.append(b)
	out.append(points[points.size() - 1])
	return out

# Ein Band je Achsenpaar - alle Würfel teilen sie (24 Paare, einmal gebaut).
static var _trace_mesh_cache := {}

## Band der Bahn von src_axis nach tgt_axis. UV.y ist die BOGENLÄNGE (0 = Pad,
## 1 = Spitze) - daraus fährt der Shader den Lichtkopf.
static func trace_mesh(src_axis: String, tgt_axis: String) -> ArrayMesh:
	var key := "%s>%s" % [src_axis, tgt_axis]
	if _trace_mesh_cache.has(key):
		return _trace_mesh_cache[key]
	var d: Vector3 = DiceController.AXIS_DIRECTIONS[src_axis]
	var t: Vector3 = DiceController.AXIS_DIRECTIONS[tgt_axis]
	# Der ganze Weg liegt in der Ebene (d, t) - die Bandbreite steht konstant
	# senkrecht darauf, das Band liegt also überall flach auf dem Würfel.
	var w := d.cross(t).normalized()
	var samples := trace_samples()
	var lengths: Array[float] = [0.0]
	var total := 0.0
	for i in range(1, samples.size()):
		total += (samples[i][0] as Vector2).distance_to(samples[i - 1][0])
		lengths.append(total)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(samples.size() - 1):
		var s0 := lengths[i] / total
		var s1 := lengths[i + 1] / total
		var c0: Vector2 = samples[i][0]
		var c1: Vector2 = samples[i + 1][0]
		var p0 := c0.x * d + c0.y * t
		var p1 := c1.x * d + c1.y * t
		var h0: float = samples[i][1]
		var h1: float = samples[i + 1][1]
		for corner in [[p0 - w * h0, 0.0, s0], [p0 + w * h0, 1.0, s0],
				[p1 + w * h1, 1.0, s1], [p0 - w * h0, 0.0, s0],
				[p1 + w * h1, 1.0, s1], [p1 - w * h1, 0.0, s1]]:
			st.set_uv(Vector2(corner[1], corner[2]))
			st.add_vertex(corner[0])
	var mesh: ArrayMesh = st.commit()
	_trace_mesh_cache[key] = mesh
	return mesh

## Skaliert pixel_size so, dass label.text in LABEL_FIT_EXTENT passt -
## mehrstellige Werte werden proportional verkleinert.
static func fit_label(label: Label3D) -> void:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var size_px: Vector2 = font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, label.font_size)
	var world_extent: float = maxf(size_px.x, size_px.y) * LABEL_PIXEL_SIZE
	var shrink: float = maxf(1.0, world_extent / LABEL_FIT_EXTENT)
	label.pixel_size = LABEL_PIXEL_SIZE / shrink
