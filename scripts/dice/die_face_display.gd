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
## DIE Auswahl-Farbe der Gravur-Station - identisch an allen Auswahl-Stellen
## (schwebendes Werkstück, Seiten-Chips im Netz). Bewusst dunkles Violett: ein
## helleres bloomt im Tisch-Glow nach Weiß aus.
const SELECT_NUMBER_COLOR := Color(0.66, 0.22, 1.0)
## Mindest-Dot (Seitennormale · Richtung zur Kamera), ab dem eine Seite als
## zugewandt und damit anklickbar gilt (siehe pick_face).
const FACE_FRONT_MIN_DOT := 0.15
## Sentinel "kein Kanten-Material" (Vergleichswert, siehe edge_base).
const EDGE_COLOR := Color(0.8, 0.8, 0.83)
## Neutrale Linienfarbe der Kanten: Weiß. Kahle Kanten leuchten bewusst
## UNTER der Bloom-Schwelle (EDGE_GLOW) - dadurch bleiben sie weiße Linien
## statt eines farbigen Klumpens und treten hinter jede Material-Kante
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
## Oberfläche. Liegt bewusst ÜBER EDGE_GLOW: eine Material-Kante muss die
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
## unshaded): in einer Reihe aus sechs leuchtenden Würfeln addierten sich die
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

## Animationsstufen der Seele nach Rarität - der Kantenrahmen ist das
## Röhrensystem, in dem das flüssige Licht der Seele zirkuliert, und die
## Rarität ist seine Erregung: still (häufig), Strömung (selten), Schübe
## (episch), Sieden + Seelenfunken als übertretende Tropfen (legendär).
## Zwei Lehren binden jede Änderung: Signale sitzen auf ECHTER GEOMETRIE
## (die additive Fresnel-Hülle flimmerte deckungsgleich oder stand abgehoben
## in der Luft - gestrichen), und Bewegung braucht Dunkelheit, die ihr gehört,
## verankert um die kalibrierte Rahmenhelligkeit (siehe die_edge_flow).
## Bewegungsfarbe unter dieser Leuchtdichte -> Void-Ton: additive Bewegung in
## Fast-Schwarz (Vakuum) wäre unsichtbar; die STATISCHE Identität bleibt dunkel.
const SOUL_MOTION_MIN_LUMA := 0.12
const VOID_MOTION_COLOR := Color(0.38, 0.33, 0.5)
## Seelenfunken: wenige Motten je Würfel - legendäre Seelen sind Unikate,
## mehr als 3 Systeme gibt es also nie.
const MOTE_COUNT := 10
const MOTE_LIFETIME := 2.4
const MOTE_GLOW := 1.5
## Stützpunkte je Kante, aus denen die Funken treten (12 Kanten × 6).
const MOTE_EDGE_SAMPLES := 6

## --- Die LADUNG am Körper ------------------------------------------------------
## NIE das Energie-Cyan: ein Würfel mit Blitzen darf nicht aussehen, als präge er
## ⚡. Weißviolett; der Überschlag blitzt BLAUER (Spieler-Wunsch 2026-09-07).
const CHARGE_COLOR := Color(0.86, 0.66, 1.35)
const CHARGE_ARC_COLOR := Color(0.55, 0.65, 1.45)
## Durchgebrannt ist ASCHE (Spieler-Wahl 2026-09-07): hellgrauer Körper, helle
## flache Kante, dunkle Ziffer, dazu eine Aschen-Auflage je Seite UNTER der Ziffer
## (die_burn.gdshader; der Wert bleibt lesbar, der Würfel zählt für die Hand).
const BURNED_BODY := Color(0.42, 0.41, 0.4)
const BURNED_EDGE := Color(0.5, 0.48, 0.46)
const BURNED_NUMBER := Color(0.2, 0.19, 0.19)
const BURN_SHADER := preload("res://assets/shaders/die_burn.gdshader")
const BURN_LIFT := 0.0092  # über der Runen-Auflage (0,008), unter der Ziffer (0,01)
var burn_parts: Array[MeshInstance3D] = []
## Ab dieser Stufe springen Blitze über die Seiten.
const CHARGE_SPARK_LEVEL := 2
## Ab dieser Stufe zünden die Eck-Lampen und Blitze schlagen aus den Kanten nach außen.
const CHARGE_ARC_LEVEL := 3
## Der Blitz beim Aufladen/Entladen/Reparieren.
const CHARGE_FLASH_TIME := 0.35
const CHARGE_FLASH_GAIN := 2.2
## Überschlag: FAHNEN, die aus den KANTEN nach AUSSEN schlagen (die_arcs.gdshader) -
## EIN kamerazugewandtes Quad um den Würfel, wie die Hitze. Die Kante selbst bleibt
## auch hier ungefärbt (Spieler-Wunsch 2026-09-07); nur die Eck-Lampen zünden.
const ARC_SHADER := preload("res://assets/shaders/die_arcs.gdshader")
const ARC_QUAD := Vector2(4.5, 4.5)
## Wie kräftig die Ladung die Boden-Lache einfärbt und hebt.
const CHARGE_POOL_MIX := 0.65
const CHARGE_POOL_GAIN := 1.25

## Ladung und Ruß des gezeigten Würfels (aus der Def) plus der TRANSIENTE
## Zeremonie-Stand (-1 = keiner) - apply_definition löscht ihn.
var _charge_level := 0
var _burned := false
## Das GLIMMEN der Stufe 1 ist HITZE, die AUS dem Würfel kommt: EIN kamerazugewandtes
## Feld vor dem Würfel (die_heat.gdshader), dessen Schlieren rundum vom Körper weg
## strömen (in jede Richtung gleich) und mit dem Abstand verlöschen; wo es nichts
## tut, ist es durchsichtig
## (Spieler-Wahl 2026-09-06 "Ausdünstung, etwas weniger Wabern").
const HEAT_SHADER := preload("res://assets/shaders/die_heat.gdshader")
## Die GLUT ist eine ZWEITE, ADDITIVE Lage zuoberst - der Grund steht im Kopf beider Shader.
const HEAT_GLOW_SHADER := preload("res://assets/shaders/die_heat_glow.gdshader")
const HEAT_QUAD := Vector2(7.0, 7.0)  # weit genug, dass das Feld vor dem Rand verlischt
const HEAT_RED := Vector3(0.95, 0.24, 0.08)
const HEAT_REACH := 1.9
const HEAT_INSIDE := 0.25
## MODELL-Länge (Würfel-Halbmaß = 1), keine Bildbreite: der Shader rechnet sie
## über die Ableitung um, damit das Flimmern aus der Ferne mitschrumpft.
const HEAT_STRENGTH := 0.012
const HEAT_GLOW := 0.26
## Wellenzahl und Auslauf-Tempo der Hitze. Das Tempo ist bewusst niedrig -
## schnellere Fronten lasen als Pulsieren statt als Hitze.
const HEAT_WAVE_FREQ := 4.4
const HEAT_WAVE_SPEED := 0.15
var heat_parts: Array[MeshInstance3D] = []
## Der KRIECHSTROM der Stufe 2 sind PLASMA-FÄDEN, die über die Seiten springen
## (die_bolts.gdshader): EIN Quad je Seite knapp über der Fläche, bis in die
## Mitte der Kantenröhren reichend - die Fäden kommen aus den Kanten. Die Kante
## selbst bleibt unverändert.
const BOLT_SHADER := preload("res://assets/shaders/die_bolts.gdshader")
const BOLT_SPAN := DieBuilder.HALF_EXTENT * 2.0
const BOLT_LIFT := 0.03  # über Ziffer (0,01) und Runen-Auflage
## Der Überschlag schlägt öfter und heißer.
const BOLT_ARC_RATE := 1.7
const BOLT_ARC_GAIN := 1.3
var bolt_parts: Array[MeshInstance3D] = []
## Der Zufall der Blitze und Bruchlinien dieses Würfels (die Seiten zählen hoch).
var _bolt_seed := randf() * 100.0
var _charge_override := -1
var _burned_override := false
var _charge_flash := 0.0
var _charge_flash_tween: Tween
## Die Außen-Blitze des Überschlags (nur Stufe 3, lazy wie die Hitze).
var charge_arcs: MeshInstance3D = null

## Pointer auf dem Würfel (PCB-Grammatik des Tisches): EIN durchgehendes
## Band je Zeiger - Pad auf der Quellseite, über den Kantenbalken hinweg, bis
## zur Pfeilspitze auf der Zielseite. Überall gleich breit: die gequerte Kante
## darf keine dickere Stelle sein, sonst zerfällt das Kabel in Einzelteile.
## Kräftiger als das UI-Cyan #8be9fd (Netz/Siegel): auf den fast weißen
## Kantenbalken ginge das blasse Cyan unter - dieselbe Regel wie DIE_SATURATION.
const POINTER_COLOR := Color("#00d9ff")
## Kamm der Chevrons: ÜBER der Bloom-Schwelle (0.95), aber unter dem Boden der
## Material-Kanten - die Material-Kante bleibt die hellste Lampe des Würfels.
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
## Trennband gegen auslaufendie Runen-Bloom. Mehr macht die Zahl fett, weniger
## trennt bei voller Naht-Breite nicht mehr.
const LABEL_OUTLINE_SIZE := 20

var quads: Dictionary = {}   # Achse -> MeshInstance3D (Körper-Quad)
var labels: Dictionary = {}  # Achse -> Label3D (Augenzahl)
var frames: Dictionary = {}  # Achse -> MeshInstance3D (Material-Leuchtrahmen)
## Achse -> Node3D (dunkle Fassung): die Dichtung gegen das Kantenbloom. Sie
## kommt und geht mit dem Rahmen - ohne Einlage gibt es nichts abzudichten.
var gaskets: Dictionary = {}
var rune_overlays: Dictionary = {}  # Achse -> MeshInstance3D (Runen-Auflage)
## Zweite und dritte Auflage NUR für Vakuum-Würfel (bis zu drei Zeichen je
## Seite, die dritte erst unter der Glasglocke), beide faul gebaut.
var rune_overlays_second: Dictionary = {}
var rune_overlays_third: Dictionary = {}
## Eck-Kappen der Kanten (Silhouetten-Signal); nur mit Essenz sichtbar. EIN
## Mesh mit eigenem Lampen-Material.
var corner_caps: MeshInstance3D = null
var cap_material: ShaderMaterial = null
## Die 12 Kantenbalken als EIN Mesh mit dem Fluss-Shader; befüllt DieBuilder.
var beam_material: ShaderMaterial = null
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
## Spanne, über die das Polarlicht seinen Farbton wandern lässt (Grün -> Violett).
const AURORA_HUE_SPAN := 0.22

## Tiefenstufe je weiterem Runen-Platz: knapp vor dem vorigen, hinter der Ziffer.
const SECOND_RUNE_DEPTH := 0.0085
## Verbreiterung der Ziffern-Sperrzone je zusätzlicher Stelle (§2.4): eine
## zweistellige Zahl beansprucht ~0.375 statt 0.26 halbe Breite.
const DIGIT_GUARD_WIDEN := 0.115

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
## Material-Zustand je Achse (1 normal, 2 veredelt). Er färbt NUR - satter statt
## heller, damit er neben dem Essenzglühen als eigenes Signal lesbar bleibt.
var face_levels: Dictionary = {}
## Essenz des Würfels ("" = keine): sie allein färbt die Kanten.
var essence_id: String = ""
## Rarität der Essenz (-1 = seelenlos) - entscheidet die Animationsstufen.
var essence_rarity: int = -1
## Seelenfunken (nur legendär, faul gebaut wie das zweite Runen-Overlay).
var soul_motes: CPUParticles3D = null
## Gemeinsames Punktbild aller Funken - einmal für alle Würfel.
static var _mote_tex: GradientTexture2D = null

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
		# Die Lache erbt die Sättigung von hier.
		face_base[axis] = DieMaterial.tint_for(material_id, level)
		# Ziffern bleiben neutral-weiß, egal welches Material - Materialfarben
		# machten die Zahl schwer lesbar (die Identität tragen Fläche/Rahmen/Kanten).
		labels[axis].modulate = NUMBER_COLOR
		var quad_material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
		_set_textures(quad_material, material_id)
	# Die LADUNG kommt aus der Def - jeder Ort des Würfels bekommt sie damit über
	# den EINEN Refresh-Pfad; der Zeremonie-Stand tritt hier ab.
	_charge_level = clampi(def.charge, 0, DieDefinition.CHARGE_MAX)
	_burned = def.burned_out
	_charge_override = -1
	_burned_override = false
	# Ein Zugriff statt is_valid_id + glow_for; die Rarität entscheidet die
	# Animationsstufen der Seele.
	var essence := Essence.by_id(def.essence_id)
	essence_id = def.essence_id if essence != null else ""
	essence_rarity = essence.rarity if essence != null else -1
	edge_base = essence.glow if essence != null else EDGE_COLOR
	if edge_material_res != null:
		_set_textures(edge_material_res, "")
	_refresh_rune_overlays(def)
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
	_sync_digit_guard(axis)

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
		# Ab dem Kriechstrom brennen die Eck-Lampen auch ohne Seele; Ruß löscht sie.
		corner_caps.visible = not shown_burned() \
			and (essence_id != "" or shown_charge() >= CHARGE_ARC_LEVEL)
	_has_material = edge_base != EDGE_COLOR
	for axis in face_base:
		if face_base[axis] != Color.WHITE:
			_has_material = true
	_refresh_soul_motion()
	_refresh_pool()
	_refresh_charge()

## Würfel-Farbe: kräftiger als der UI-Tint (siehe DIE_SATURATION). Wird auf
## alles gelegt, was Licht trägt - Emission, Würfellicht, Fresnel-Schimmer.
static func intense(color: Color) -> Color:
	var c := color
	c.s = clampf(c.s * DIE_SATURATION, 0.0, 1.0)
	c.v = clampf(c.v * DIE_VALUE, 0.0, 1.0)
	return c

## Emission des Kantenrahmens (Balken, Kappen): mit Seele ihr Glühen über dem
## Material-Boden, kahl das neutrale Neon unter der Bloom-Schwelle - dieselben
## zwei Fälle wie _apply_essence_edge/_apply_profile für den Füllkörper.
func _frame_glow_color() -> Color:
	var lamp := intense(edge_base) * MATERIAL_EDGE_GLOW_FLOOR * body_tint \
		if essence_id != "" else intense(EDGE_NEON) * EDGE_GLOW * body_tint
	return _charged_lamp(lamp)

## Bewegungsfarbe der Seele (Fluss-Ballungen, Seelenfunken): die Glow-Farbe,
## unter dem Luma-Boden der kalte Void-Ton.
func _soul_motion_color() -> Color:
	var color := intense(edge_base)
	return color if color.get_luminance() >= SOUL_MOTION_MIN_LUMA else VOID_MOTION_COLOR

## Hält Kantenfluss, Eck-Kappen und Seelenfunken mit dem Würfelzustand synchron.
## Sitzt in _refresh_face_colors, damit jede apply_definition (become!) und
## jeder body_tint-Wechsel neu ausspielt - das hebt auch flat_tint der
## Stations-Auswahl wieder auf (set_tint stellt den Rahmen wieder her).
func _refresh_soul_motion() -> void:
	# Balken wie Kappen tragen Farbe UND Körper des Rahmens - body_tint
	# (Gold-Blitz) muss beide erreichen wie bei _apply_profile.
	var lamp := _frame_glow_color()
	var body := BODY_COLOR * body_tint
	if beam_material != null:
		beam_material.set_shader_parameter("lamp_color", Vector3(lamp.r, lamp.g, lamp.b))
		beam_material.set_shader_parameter("body_color", Vector3(body.r, body.g, body.b))
		beam_material.set_shader_parameter("phase", _pulse_phase)
		beam_material.set_shader_parameter("breath_amount",
			PULSE_AMOUNT_MATERIAL if _has_material else PULSE_AMOUNT)
		beam_material.set_shader_parameter("flat_tint", Vector4.ZERO)
		# Erregung der Flüssigkeit nach Rarität; die Ballungen tragen den
		# Void-Boden, damit auch eine fast schwarze Seele (Vakuum) fließt.
		var style := 0.0
		var flow := Color.BLACK
		if essence_rarity >= Essence.Rarity.RARE:
			style = float(essence_rarity - Essence.Rarity.RARE + 1)
			flow = _soul_motion_color() * body_tint
		beam_material.set_shader_parameter("flow_style", style)
		beam_material.set_shader_parameter("flow_color", Vector3(flow.r, flow.g, flow.b))
	if cap_material != null:
		cap_material.set_shader_parameter("lamp_color", Vector3(lamp.r, lamp.g, lamp.b))
		cap_material.set_shader_parameter("body_color", Vector3(body.r, body.g, body.b))
		cap_material.set_shader_parameter("phase", _pulse_phase)
		cap_material.set_shader_parameter("flat_tint", Vector4.ZERO)
	if essence_rarity < Essence.Rarity.LEGENDARY:
		if soul_motes != null:
			soul_motes.queue_free()
			soul_motes = null
		return
	if soul_motes == null:
		soul_motes = _build_soul_motes()
		add_child(soul_motes)
	var mote := _soul_motion_color() * body_tint * MOTE_GLOW
	mote.a = 1.0
	soul_motes.color = mote

## Das einzige Partikelsystem des Spiels, CPU statt GPU - winzige Stückzahl,
## gl_compatibility bleibt außen vor. Welt-Koordinaten: die Funken ziehen dem
## geworfenen Würfel als Schweif nach.
func _build_soul_motes() -> CPUParticles3D:
	var motes := CPUParticles3D.new()
	motes.name = "SoulMotes"
	motes.amount = MOTE_COUNT
	motes.lifetime = MOTE_LIFETIME
	# Beim ersten Blick hängen die Funken schon in der Luft.
	motes.preprocess = MOTE_LIFETIME
	motes.local_coords = false
	# Die Funken lösen sich aus dem KANTENRAHMEN - dort sitzt das Seelenglühen,
	# die Würfelmitte ist dunkles Glas.
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	motes.emission_points = _edge_emission_points()
	motes.direction = Vector3.UP
	motes.spread = 60.0
	motes.gravity = Vector3(0.0, 0.55, 0.0)  # Auftrieb statt Fall
	motes.initial_velocity_min = 0.1
	motes.initial_velocity_max = 0.35
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.0
	# Ein- und Ausblenden über die Lebenszeit.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	motes.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.16
	motes.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _mote_texture()
	motes.material_override = material
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Spät gebaut - das Spiegel-Bit der beim Aufbau markierten Geschwister erben.
	if not quads.is_empty():
		motes.layers = (quads.values()[0] as VisualInstance3D).layers
	return motes

## Stützpunkte auf den 12 Kanten (Halbkante 1, siehe FACE_RIDE): je Achse vier
## Kanten, die Achse selbst ist deren Laufrichtung.
static func _edge_emission_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for long_axis in 3:
		var a := (long_axis + 1) % 3
		var b := (long_axis + 2) % 3
		for sa: float in [-1.0, 1.0]:
			for sb: float in [-1.0, 1.0]:
				for i in MOTE_EDGE_SAMPLES:
					var point := Vector3.ZERO
					point[a] = sa
					point[b] = sb
					point[long_axis] = -1.0 + 2.0 * float(i) / float(MOTE_EDGE_SAMPLES - 1)
					points.append(point)
	return points

## Weicher Lichtpunkt statt Quad-Kante, einmal für alle Würfel.
static func _mote_texture() -> GradientTexture2D:
	if _mote_tex == null:
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 1.0])
		ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		_mote_tex = GradientTexture2D.new()
		_mote_tex.gradient = ramp
		_mote_tex.fill = GradientTexture2D.FILL_RADIAL
		_mote_tex.fill_from = Vector2(0.5, 0.5)
		_mote_tex.fill_to = Vector2(0.5, 0.0)
		_mote_tex.width = 32
		_mote_tex.height = 32
	return _mote_tex

## Kantenglühen der Essenz: die Kanten sind kein Ausbau-Slot mehr, sondern die
## Bühne, auf der die Seele leuchtet - essenzlose Würfel behalten das neutrale
## Neon. set_edge_tint schaltet für die Auswahl auf unschattiert, darum hier zurück.
func _apply_essence_edge() -> void:
	if edge_material_res == null:
		return
	edge_material_res.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_apply_profile(edge_material_res, null, true)
	# EINE Quelle für Balken, Kappen und Füllkörper - die Ladung färbt sie mit.
	edge_material_res.emission = _frame_glow_color()

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

## Runen der Seiten: sichtbar nur, wo eine Rune sitzt. In Ruhe schimmern sie
## schwach - erst im Moment ihres Feuerns flammen sie auf (flare_runes). Genau
## diese zeitliche Signatur trennt sie vom DAUERND glühenden Essenz-Rand.
## Der Vakuum-Würfel trägt bis zu drei Zeichen je Seite; jedes weitere bekommt
## seine eigene Auflage, erst bei Bedarf gebaut, und seine eigene Spiegelung.
func _refresh_rune_overlays(def: DieDefinition) -> void:
	for axis in rune_overlays:
		var face_index: int = DiceController.AXIS_FACE_INDEX[axis]
		var on_face := def.runes_on(face_index)
		_apply_rune_overlay(rune_overlays[axis], on_face, 0, def)
		for slot in range(1, Rune.SLOT_FLIPS.size()):
			var extra: MeshInstance3D = _extra_overlays(slot).get(axis)
			if on_face.size() > slot:
				if extra == null:
					extra = DieBuilder.build_rune_overlay(SECOND_RUNE_DEPTH * float(slot))
					quads[axis].add_child(extra)
					_extra_overlays(slot)[axis] = extra
				_apply_rune_overlay(extra, on_face, slot, def)
			elif extra != null:
				extra.visible = false
		_sync_digit_guard(axis)

## Auflagen-Ablage eines Runen-Platzes > 0 (faul gebaut, nur am Vakuum belegt).
func _extra_overlays(slot: int) -> Dictionary:
	return rune_overlays_second if slot == 1 else rune_overlays_third

func _apply_rune_overlay(overlay: MeshInstance3D, on_face: Array[String], index: int,
		def: DieDefinition) -> void:
	overlay.visible = index < on_face.size()
	if not overlay.visible:
		return
	var rune_id: String = on_face[index]
	var rune := Rune.by_id(rune_id)
	# Die Essenz schlägt die Rune: auf einem Vakuum-Würfel saugt jede Rune.
	var profile := Rune.profile_for(rune_id, def.essence_id)
	if rune == null or profile == null:
		overlay.visible = false
		return
	var material: ShaderMaterial = overlay.material_override
	material.set_shader_parameter("glyph_map", RuneTextures.for_glyph(rune.glyph))
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
	# Der Platz ist eine Spiegelung derselben Maske - der KRANZ füllt die Seite.
	material.set_shader_parameter("glyph_flip", Rune.slot_flip(index))
	material.set_shader_parameter("flare", 0.0)
	material.set_shader_parameter("block_flare", false)

## Ziffern-Wächter (§2.4): eine zweistellige Zahl ist breiter, also wird die
## SPERRZONE breiter - nie die Figur. Knochen lässt Werte wachsen, und eine Rune,
## der sich beim Wachsen neu zeichnet, liest als Fehler.
func _sync_digit_guard(axis: String) -> void:
	var label: Label3D = labels.get(axis)
	if label == null:
		return
	var digits := maxi(1, label.text.length())
	var half := Vector2(Rune.DIGIT_KEEPOUT.x + DIGIT_GUARD_WIDEN * float(digits - 1),
		Rune.DIGIT_KEEPOUT.y)
	for store in [rune_overlays, rune_overlays_second, rune_overlays_third]:
		var overlay: MeshInstance3D = store.get(axis)
		if overlay == null or not overlay.visible:
			continue
		(overlay.material_override as ShaderMaterial).set_shader_parameter("digit_half", half)

## Lässt die Runen EINER Seite auflodern (0 = Ruhe, 1 = voller Ausbruch) -
## scene_root ruft das im Aktivierungs-Puls der Zählanimation. face_index < 0
## meint alle Seiten (Vorschau/Test); im Spiel feuert immer nur die OBERE, denn
## dort sitzt die Rune, die gewertet wird.
func flare_runes(strength: float, face_index := -1, block := false) -> void:
	for axis in rune_overlays:
		if face_index >= 0 and DiceController.AXIS_FACE_INDEX[axis] != face_index:
			continue
		for store in [rune_overlays, rune_overlays_second, rune_overlays_third]:
			var overlay: MeshInstance3D = store.get(axis)
			if overlay == null or not overlay.visible:
				continue
			var material: ShaderMaterial = overlay.material_override
			material.set_shader_parameter("flare", strength)
			material.set_shader_parameter("block_flare", block)

## Leucht-Rahmen der Seite: sichtbar nur mit Material, Linie in Materialfarbe.
func _refresh_frame(axis: String, profile: DieMaterial, level := 1) -> void:
	var gasket: Node3D = gaskets.get(axis)
	if gasket != null:
		gasket.visible = profile != null
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
		# zu stehen - das einzige Glühen, das seine Farbe ändert. Balken und
		# Kappen hängen an eigenen Shadern, also wandert der Push mit (nur
		# dieser eine Würfel zahlt die Frame-Kosten, Aurora ist Unikat).
		if essence_id == Essence.AURORA:
			var shifted := edge_base
			shifted.h = fmod(edge_base.h + _pulse_phase / TAU * AURORA_HUE_SPAN, 1.0)
			var lamp := intense(shifted) * MATERIAL_EDGE_GLOW_FLOOR * body_tint
			edge_material_res.emission = lamp
			for material: ShaderMaterial in [beam_material, cap_material]:
				if material != null:
					material.set_shader_parameter("lamp_color", Vector3(lamp.r, lamp.g, lamp.b))
	# Die Pointer-Strömung braucht hier nichts: sie läuft über TIME im
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
	# GLIMMEN: die Lache wärmt mit - sie ist die Erdung des geladenen Würfels.
	var level := shown_charge()
	if level > 0 and not shown_burned():
		var mix := CHARGE_POOL_MIX * float(level) / float(DieDefinition.CHARGE_MAX)
		color = color.lerp(CHARGE_COLOR, mix)
		strength *= 1.0 + (CHARGE_POOL_GAIN - 1.0) * float(level) / float(DieDefinition.CHARGE_MAX)
	_pool_color = Color(color.r, color.g, color.b, POOL_ALPHA_PER_STRENGTH * strength)

# --- Die LADUNG am Körper ------------------------------------------------------
# Vier Zustände auf EINEM Weg: Glimmen (warmer Atem in Kante und Lache),
# Kriechstrom (Funken laufen die Kanten entlang, Eck-Lampen an), Überschlag
# (dazu Teilchen und der orange Kern) und Ruß (flach, dunkel, kein Licht).
# Alles Licht sitzt an Kanten, Ecken, Ziffern, Lache und in den Teilchen - über
# den Flächen liegt bewusst KEINE Hülle.

## Die gezeigte Stufe: der Zeremonie-Stand schlägt den Def-Stand.
func shown_charge() -> int:
	if shown_burned():
		return 0
	return _charge_override if _charge_override >= 0 else _charge_level

## Zeigt der Würfel Ruß? Ebenfalls Zeremonie vor Def.
func shown_burned() -> bool:
	if _charge_override >= 0:
		return _burned_override
	return _burned

## Der TRANSIENTE Stand der Wertungs-Zeremonie (wie die Wert-Overrides): der Körper
## folgt der laufenden Aufschlüsselung, apply_definition holt ihn zurück.
func set_charge_override(level: int, burned: bool) -> void:
	_charge_override = clampi(level, 0, DieDefinition.CHARGE_MAX)
	_burned_override = burned
	_refresh_face_colors()

func clear_charge_override() -> void:
	if _charge_override < 0:
		return
	_charge_override = -1
	_burned_override = false
	_refresh_face_colors()

## Kurzer Blitz in Ladungsfarbe (Aufladen, Entladen, Reparatur) - wie flare_runes
## eine reine Anzeige, die von selbst zurückfällt.
func flash_charge(strength := 1.0) -> void:
	if _charge_flash_tween != null and _charge_flash_tween.is_valid():
		_charge_flash_tween.kill()
	_charge_flash = clampf(strength, 0.0, 1.0)
	_refresh_face_colors()
	_charge_flash_tween = create_tween()
	_charge_flash_tween.tween_method(func(v: float) -> void:
		_charge_flash = v
		_refresh_face_colors(), _charge_flash, 0.0, CHARGE_FLASH_TIME)

## Der Rahmen-Ton mit dem Blitz. KEINE Stufe färbt die Kante (Spieler-Wunsch
## 2026-09-06/07): die Ladung lebt in Hitze, Blitzen und Eck-Lampen.
func _charged_lamp(lamp: Color) -> Color:
	if _charge_flash <= 0.0:
		return lamp
	return lamp.lerp(CHARGE_COLOR * CHARGE_FLASH_GAIN, _charge_flash)

## Was Ladung und Ruß über den fertig gefärbten Körper legen: die Hitze ab
## Stufe 1, die Blitze ab Stufe 2, die Außen-Blitze des Überschlags und - bei
## Asche - der flache helle Rahmen samt Aschen-Auflagen und dunkler Ziffer.
func _refresh_charge() -> void:
	var burned := shown_burned()
	var level := shown_charge()
	# Jede Stufe trägt alle darunter (Spieler-Entscheid 2026-09-07): die Hitze
	# bleibt unter Blitzen und Überschlag stehen.
	_sync_heat(level >= 1 and not burned)
	_sync_bolts(level >= CHARGE_SPARK_LEVEL and not burned, level)
	_sync_charge_arcs(level >= CHARGE_ARC_LEVEL and not burned)
	_sync_burn(burned)
	if not burned:
		return
	# Asche: flache helle Kanten (der set_edge_tint-Schalter), grauer Körper,
	# dunkle Ziffer, keine Lache, keine Seelen-Bewegung.
	set_edge_tint(BURNED_EDGE)
	for axis in quads:
		var material: StandardMaterial3D = quads[axis].get_surface_override_material(0)
		material.albedo_color = BURNED_BODY
		material.emission = BURNED_EDGE * FACE_GLOW
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		var frame: MeshInstance3D = frames.get(axis)
		if frame != null and frame.visible:
			(frame.material_override as StandardMaterial3D).emission = BURNED_EDGE * FACE_GLOW
		var label: Label3D = labels.get(axis)
		if label != null:
			label.modulate = BURNED_NUMBER
	if glow_pool != null:
		glow_pool.visible = false
	if soul_motes != null:
		soul_motes.queue_free()
		soul_motes = null

## Die Außen-Blitze des Überschlags kommen und gehen mit der Stufe (lazy, wie
## die Hitze); den Ton setzt _sync_bolts für die Seiten-Blitze gleich mit.
func _sync_charge_arcs(wanted: bool) -> void:
	if not wanted:
		if charge_arcs != null:
			charge_arcs.queue_free()
			charge_arcs = null
	elif charge_arcs == null:
		charge_arcs = _overlay(self, "ChargeArcs", ARC_QUAD, 0.0, ARC_SHADER, 10, {
			"quad_size": ARC_QUAD, "seed_base": _bolt_seed + 7.0, "phase": _pulse_phase,
			"halo_color": _rgb(CHARGE_ARC_COLOR)})

## Die Aschen-Auflagen kommen und gehen mit dem Ruß (lazy, wie die Hitze).
func _sync_burn(wanted: bool) -> void:
	if not wanted:
		_free_overlays(burn_parts)
	elif burn_parts.is_empty():
		_face_overlays(burn_parts, "BurnOverlay", DieBuilder.FACE_SIZE, BURN_LIFT,
			BURN_SHADER, -1)  # vor der Ziffer gezeichnet, also unter ihr

## Färbt den Kanten-Rahmen absolut (Kanten-Auswahl der Gravur-Station).
## Unschattiert, damit exakt die flache Auswahl-Farbe erscheint - beleuchtet
## klemmt derselbe Wert je nach Licht unterschiedlich weg. set_tint stellt
## danach die normale Rahmenfarbe wieder her.
func set_edge_tint(color: Color) -> void:
	if edge_material_res != null:
		edge_material_res.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		edge_material_res.albedo_color = color
		edge_material_res.emission = Color.BLACK  # flach: kein Neon über der Auswahl
	# Balken und Kappen hängen an eigenen Shadern - flat_tint ist dort derselbe
	# flache Auswahl-Modus; _refresh_soul_motion hebt ihn wieder auf.
	for material: ShaderMaterial in [beam_material, cap_material]:
		if material != null:
			material.set_shader_parameter("flat_tint", Vector4(color.r, color.g, color.b, 1.0))

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

# --- Zeigen auf den Würfel ------------------------------------------------------
# Getroffen wird über die BILDSCHIRM-Projektion der Seiten-/Kantenmitten, nicht
# über einen Physik-Strahl: die Zeremonien-Würfel tragen keine Kollisionsform,
# und eine Seite ist ohnehin erst ab einem Blickwinkel anklickbar.

## Angeklickte physische Seite: [face_index (-1 = keine), Distanz zur projizierten
## Seiten-Mitte (INF)]. Nur zugewandte Seiten zählen.
func pick_face(camera: Camera3D, screen_pos: Vector2, radius: float) -> Array:
	var best_face := -1
	var best_dist := INF
	if camera == null:
		return [best_face, best_dist]
	for axis in quads:
		var quad: MeshInstance3D = quads[axis]
		var to_cam: Vector3 = (camera.global_position - quad.global_position).normalized()
		var normal: Vector3 = quad.global_transform.basis.z.normalized()
		if normal.dot(to_cam) <= FACE_FRONT_MIN_DOT:
			continue
		var dist := camera.unproject_position(quad.global_position).distance_to(screen_pos)
		if dist < best_dist and dist < radius:
			best_dist = dist
			best_face = DiceController.AXIS_FACE_INDEX[axis]
	return [best_face, best_dist]

## Distanz zur nächsten zugewandten KANTEN-Mitte (INF = keine in radius). Jedes
## Paar senkrechter Achsrichtungen ist eine Kante; ihre "Normale" ist die
## Winkelhalbierende beider Seiten-Normalen.
func edge_distance(camera: Camera3D, screen_pos: Vector2, radius: float) -> float:
	var best_dist := INF
	if camera == null:
		return best_dist
	var directions: Array = DiceController.AXIS_DIRECTIONS.values()
	for i in directions.size():
		for j in range(i + 1, directions.size()):
			var a: Vector3 = directions[i]
			var b: Vector3 = directions[j]
			if not is_zero_approx(a.dot(b)):
				continue
			var mid_global: Vector3 = global_transform * ((a + b) * DieBuilder.HALF_EXTENT)
			var to_cam: Vector3 = (camera.global_position - mid_global).normalized()
			var normal: Vector3 = (global_transform.basis * (a + b)).normalized()
			if normal.dot(to_cam) <= FACE_FRONT_MIN_DOT:
				continue
			var dist := camera.unproject_position(mid_global).distance_to(screen_pos)
			if dist < best_dist and dist < radius:
				best_dist = dist
	return best_dist

# --- Pointer-Spuren --------------------------------------------------------

## Achse eines Seiten-Index (Umkehrung von DiceController.AXIS_FACE_INDEX).
static func axis_of_face(face_index: int) -> String:
	for axis in DiceController.AXIS_FACE_INDEX:
		if DiceController.AXIS_FACE_INDEX[axis] == face_index:
			return axis
	return ""

## Baut alle Pointer aus def.pointers neu. Ein Zeiger auf eine
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

# --- Die Auflagen der Ladung: Hitze, Blitze, Asche -----------------------------

## EIN Quad mit Shader-Material unter parent: die eine Bauweise aller Auflagen.
func _overlay(parent: Node3D, part_name: String, size: Vector2, lift: float,
		shader: Shader, priority: int, params: Dictionary) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var material := ShaderMaterial.new()
	material.shader = shader
	for key in params:
		material.set_shader_parameter(key, params[key])
	material.render_priority = priority
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = quad
	part.position = Vector3(0, 0, lift)
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

## Je Seite eine Auflage (Kind des Seiten-Quads, in dessen Ebene), mit eigenem
## Zufall je Seite und der Phase des Würfels.
func _face_overlays(store: Array[MeshInstance3D], part_name: String, span: float,
		lift: float, shader: Shader, priority: int) -> void:
	var face_index := 0
	for axis in quads:
		store.append(_overlay(quads[axis], part_name, Vector2.ONE * span, lift, shader, priority,
			{"face_seed": _bolt_seed + float(face_index), "phase": _pulse_phase}))
		face_index += 1

func _free_overlays(store: Array[MeshInstance3D]) -> void:
	for part in store:
		if is_instance_valid(part):
			part.queue_free()
	store.clear()

static func _rgb(color: Color) -> Vector3:
	return Vector3(color.r, color.g, color.b)

## Das Hitze-Feld der Stufe 1: ZWEI Lagen auf demselben Quad, die Verzerrung
## zuunterst, die Glut ADDITIV zuoberst. Warum, steht im Kopf beider Shader -
## zuletzt gezeichnet löschte die Verzerrung die Ziffern, zuerst gezeichnet
## übermalten die Nachbar-Würfel sie.
func _sync_heat(wanted: bool) -> void:
	if not wanted:
		_free_overlays(heat_parts)
	elif heat_parts.is_empty():
		var shared := {"wave_freq": HEAT_WAVE_FREQ, "wave_speed": HEAT_WAVE_SPEED,
			"quad_size": HEAT_QUAD, "reach": HEAT_REACH, "phase": _pulse_phase}
		heat_parts.append(_overlay(self, "Heat0", HEAT_QUAD, 0.0, HEAT_SHADER, -8,
			shared.merged({"inside": HEAT_INSIDE, "strength": HEAT_STRENGTH})))
		heat_parts.append(_overlay(self, "Heat1", HEAT_QUAD, 0.0, HEAT_GLOW_SHADER, 8,
			shared.merged({"tint": HEAT_RED, "tint_amount": HEAT_GLOW})))

## Die sechs Blitz-Quads der Stufen 2 und 3 (lazy, wie die Hitze), auf die Stufe
## eingestellt: der Überschlag schlägt öfter, heißer und blauer.
func _sync_bolts(wanted: bool, level: int) -> void:
	if not wanted:
		_free_overlays(bolt_parts)
		return
	if bolt_parts.is_empty():
		_face_overlays(bolt_parts, "ChargeBolts", BOLT_SPAN, BOLT_LIFT, BOLT_SHADER, 9)
	var arc := level >= CHARGE_ARC_LEVEL
	for part in bolt_parts:
		var material: ShaderMaterial = part.material_override
		material.set_shader_parameter("halo_color", _rgb(CHARGE_ARC_COLOR if arc else CHARGE_COLOR))
		material.set_shader_parameter("rate", BOLT_ARC_RATE if arc else 1.0)
		material.set_shader_parameter("gain", BOLT_ARC_GAIN if arc else 1.0)
