class_name DataCellView
extends Node3D
## Die Datenzelle: ein versiegeltes Aufwertungs-Paket als physische Kassette auf
## dem Tisch. Dunkles Gehäuse mit Fensterausschnitt, dahinter ein Kern in der
## Sortenfarbe, davor eine Glasscheibe und darauf ihr PRÄGENETZ, an der Unterkante
## goldene Kontaktfinnen. Rein per Code gebaut wie DieBuilder und CapacitorBankView
## - kein .tscn, kein GLB.
## Die FLÄCHE trägt seit 2026-09-02 das Netz (StampNetOven), die SORTE den Rahmen
## und die GRÖSSE dessen Stärke; die drei Kern-Riegel und die Größen-Streifen der
## Vorderseite sind damit gestorben. ROLL und YAW folgen der LAGE (Welle O/P):
## LIEGEND ist sie quer (Läden, Wetten, Wurf), STEHEND kappe-oben und HOCHKANT -
## die Fläche nach Bild-links, so steht sie im Magazin und im Serien-Schacht.
## Drei Regeln des Tisches gelten auch hier: nur EMISSION, keine eigenen Lichter
## (die Bodenkacheln vertragen 16); im Ruhezustand bleibt das Leuchten UNTER der
## Bloom-Schwelle, der Ausbruch (flare) gibt den Kopfraum aus; und die Sortenfarbe
## kommt aus der einen Quelle PackDrawerView.COLORS.
## Bewusst NICHT gespiegelt - dieselbe Regel wie beim Phantomwürfel: sie LIEGT auf
## dem Glas, ihr Spiegelbild fällt also neben sie und schmiert nur den Stapel und
## seine Marke zu (gemessen: ein zweites ×n neben dem echten).
## Der Aufbau ist bewusst schichtweise: das GEHÄUSE bleibt undurchsichtig, allein
## die Scheibe ist alphagemischt und der Kern DAHINTER wieder deckend - der
## Compatibility-Renderer sortiert Durchsichtiges in Durchsichtigem schlecht.

## Zulage über die Würfelkante hinaus: auf Bankdistanz las die Kassette als Karte
## zu klein, Siegel und Kern verschwammen. Ein Drittel mehr ist die Größe, bei der
## beides steht - Möbel neben den Würfeln, immer noch kein Klotz.
const SIZE_FACTOR := 1.35
## Standhöhe, aus der Würfelkante abgeleitet: alles andere hängt an ihr.
const HEIGHT := DieBuilder.HALF_EXTENT * 2.0 * DiceTrayView.DIE_SCALE * SIZE_FACTOR
## Streichholzschachtel-Verhältnis 2 : 3 : 0,28 (Breite : Höhe : Tiefe). Die Zelle
## ist als Einzelstück dünner, als sie sein müsste - gebaut wird sie für den
## STAPEL: fünf davon sollen als flacher Haufen lesen, nicht als Turm.
const UNIT := HEIGHT / 3.0
const WIDTH := UNIT * 2.0
const DEPTH := UNIT * 0.28
## Die STANDHÖHE: stehend ist die Kassette ungedreht und kappe-oben (Welle O), ihr
## aufrechtes Maß ist also ihre HÖHE. Jede senkrechte Rechnung mißt daran - das
## Einsinken, der Aufstieg, der Griff und die Tiefe jeder Grube.
const STAND_HEIGHT := HEIGHT
## Die Vierteldrehung der STEHENDEN Karte (Welle P): hochkant, Fläche nach
## Bild-links. Liegend bleibt sie 0 - die Läden lesen ihre Fläche von oben.
const STAND_YAW := -PI * 0.5

## Rahmenbreiten des Gehäuses. Sie sind so SCHMAL wie möglich (Spieler-Entscheid
## 2026-09-04): der Ausschnitt IST fast die ganze Karte, damit das Prägenetz darin
## ohne Rand liegt. Bemessen an der stärksten Blende (der des Kolossalen), deren
## Außenkante damit gerade auf der Kartenkante landet; der Fuß bleibt der breiteste
## Balken - er trägt die Kontaktfinnen und gibt der Zelle ihren Stand.
const SIDE_BAR := WIDTH * 0.0668
const TOP_BAR := HEIGHT * 0.075
const FOOT_BAR := HEIGHT * 0.135
## Rückwand: der Ausschnitt ist ein Loch im Rahmen, sie schließt ihn nach hinten.
const BACK_DEPTH := DEPTH * 0.42

## Kontaktfinnen an der Unterkante. Sie stehen vorn UND hinten ein Stück vor -
## echte Steckkontakte sitzen nicht auf einer Seite.
const FIN_COUNT := 5
const FIN_WIDTH := WIDTH * 0.105
const FIN_SPREAD := WIDTH * 0.74
const FIN_DEPTH := DEPTH * 1.10

## Sichtbarer Stapel und sein Achsabstand; darüber zählt allein die Marke. Der
## Stapel wächst entlang der DICKE - liegend ist das der Chip-Turm nach oben,
## stehend die Reihe nach vorn. Der seitliche Versatz ist der Unterschied
## zwischen einem Stapel und einer Zelle: ohne ihn deckt die vorderste Kassette
## alle anderen exakt zu.
const STACK_CAP := 5
const STACK_PITCH := DEPTH * 1.18
const STACK_STAGGER := WIDTH * 0.055

## Ruhelicht des Kerns. Multipliziert mit der Sortenfarbe (hellster Kanal ~1)
## bleibt es unter Rune.IDLE_CEILING - dieselbe Ruheregel wie bei den Runen.
const REST_ENERGY := 0.88
## Der Ausbruch SOLL blühen: Lesen/Einschieben ist der Moment, für den der
## Kopfraum freigehalten wird.
const FLARE_ENERGY := 3.2
const FLARE_TIME := 0.55
## Gedimmt (später die Signatur-Sperre): der Kern verglimmt, der KÖRPER bleibt.
const DIM_ENERGY := 0.16

## Die KAPPE auf der Kopfkante: eine massive Platte in der Sortenfarbe, breiter
## als die Kassette dick ist. Sie ist die ganze Auskunft der stehenden Zelle -
## im Magazin blickt die Kamera von oben in die Grube und sieht NUR sie, also
## trägt sie Farbe, Sortenzeichen und (als Bündel) ihre Stückzahl. Ihre Oberkante
## liegt exakt auf HEIGHT/2: die Zelle bleibt genau so hoch, wie sie war, und die
## Einsink-Rechnung (sunk_drop) stimmt weiter.
const CAP_H := HEIGHT * 0.055
const CAP_WIDTH := WIDTH * 1.02
const CAP_DEPTH := DEPTH * 2.9
## Sie steht eine Spur ÜBER dem Gehäuse: läge ihre Deckfläche auf HEIGHT/2, wäre
## sie deckungsgleich mit den Kopfflächen von Rahmen und Kragen, und von oben
## zerschnitte deren Tiefenkampf die Kappe mit dunklen Nähten.
const CAP_PROUD := DEPTH * 0.16
## Ruhelicht der Kappe: satte Fläche, aber unter Rune.IDLE_CEILING.
const CAP_REST_ENERGY := 0.80
const CAP_DIM_ENERGY := 0.14
## Zeichen und Zahl liegen FLACH auf der Kappe - dunkel auf der Sortenfarbe.
const CAP_INK := Color(0.055, 0.05, 0.09)
const CAP_GLYPH_SHARE := 0.78
const CAP_BADGE_FONT := 64
const CAP_BADGE_HEIGHT := DEPTH * 1.9

## Der Leuchtstreifen unter der Kappe: ein Lichtsaum an ihrer Brüstung. Er bleibt
## in JEDER Richtung KLEINER als die Kappe - ragte er darunter hervor, läse die
## Kopfkante von oben als zweite, tiefer liegende Platte, und die Kassette sähe
## aus wie ein Doppeldecker.
const EDGE_STRIP_H := HEIGHT * 0.030
const EDGE_STRIP_WIDTH := WIDTH * 0.94
const EDGE_STRIP_DEPTH := CAP_DEPTH * 0.90
## Ruhelicht der Kante im Regal - wie der Kern unter Rune.IDLE_CEILING.
const EDGE_REST_ENERGY := 0.62
## Eingesteckt ist der Sliver die ganze Anzeige - hell, aber NICHT weiß: über
## etwa 1,5 kippen alle drei Kanäle ins Clipping und die Sortenfarbe geht verloren
## (dieselbe Grenze wie bei den Zellen der Kondensatorbank).
const EDGE_LIVE_ENERGY := 1.35
const EDGE_DIM_ENERGY := 0.12
## Anteil, mit dem die Kante einen Kern-Ausbruch mitreißt.
const EDGE_FLARE_SHARE := 0.75

## Die GRÖSSEN-Marke auf der Kappe (Pack.TIER_*): je Stufe ein heller Streifen
## rechts neben dem Sortenzeichen - Groß einer, Kolossal zwei. Sie liegen FLACH
## auf dem Deckel, denn von den Tischwinkeln sieht man von einer stehenden
## Kassette nichts als ihn. Geometrie der Kassette selbst bleibt unberührt: das
## eine Kassettenmaß trägt Schlitz und Grube, eine dickere Karte spränge beides.
const TIER_STRIPE_W := CAP_WIDTH * 0.045
const TIER_STRIPE_H := CAP_H * 0.55
const TIER_STRIPE_DEPTH := CAP_DEPTH * 0.66
## Abstand der Streifen zueinander und vom Zeichen weg (nach rechts, wo bis zur
## Bündelzahl frei ist).
const TIER_STRIPE_PITCH := CAP_WIDTH * 0.085
const TIER_STRIPE_X := -CAP_WIDTH * 0.06
## Sie stehen eine Spur über der Kappe - koplanar zerschnitte der Tiefenkampf sie.
const TIER_STRIPE_PROUD := DEPTH * 0.05
## Ihr Licht: heller als die Kappe, aber unter der Grenze, ab der die drei Kanäle
## zu Weiß zusammenlaufen und aus zwei Streifen einer wird.
const TIER_STRIPE_ENERGY := 1.45
## Das Kolossale trägt zusätzlich einen GOLDENEN Kragen - der Rahmen um die Karte,
## nicht die Blende davor: von oben ist er der Umriss, den man ohne Zoom liest.
const TIER_COLLAR_GOLD := 0.62

## Sichtbarer Anteil der Höhe, wenn die Zelle im Leseschlitz steckt: gerade so
## viel, dass Kopfkante und Blende lesen, und so wenig, dass sie IM Tisch steckt.
const SUNK_SHOW := 0.18
## Ganz geschluckt (Dekompression): eine Spur unter dem Glas, sonst flimmerte die
## Kopffläche gegen die Scheibe.
const SUNK_GONE := -0.06
## Der Stand im MAGAZIN: die Grube ist ein echtes Loch, die Zelle steht darin bis
## zur Kappe. Eine Spur UNTER der Tischkante - nichts ruht über dem Rand, und der
## Kragen der Grube deckt die Schnittkante darüber.
const PIT_SHOW := -0.03
## Die Ankunft: die Kassette steigt auf ihren Platz. Etwas länger als das
## Absinken - Ankommen darf sich setzen.
const RISE_TIME := 0.35

## Das Herausziehen unterm Zeiger (wie eine Akte aus der Schublade): Anteil der
## Höhe, um den die Kassette steigt, und die Zeit dafür. Nur so ist ein Griff in
## der Grube überhaupt zu sehen - ein gemalter Schein läge unter dem Loch.
const HOVER_LIFT := 0.42
const HOVER_TIME := 0.16
## Derselbe Hub als Stellschraube der Zelle: ein Wirt darf ihn kappen, wenn über
## seiner Auslage kein Platz dafür ist. Im Magazin bleibt es beim vollen Maß.
var hover_lift := HOVER_LIFT
## Wohin die ×n-Marke der LIEGENDEN Zelle gehört. Normal steht sie neben der
## Karte; in einer Auslage wird sie von oben gelesen und steht dicht bei ihren
## Nachbarn - neben ihr läge die Marke im fremden Platz, also liegt sie AUF ihr.
var badge_on_face := false
## Aufgehellt, aber deutlich unter dem Lese-Ausbruch: Greifen ist kein Lesen.
const HOVER_ENERGY := 1.75

## Auftauchen und Abtreten wie ein schwebender Würfel (FloatingDie): der Körper
## wächst an Ort und Stelle aus dem Nichts und schrumpft wieder hinein. Skaliert
## wird der KNOTEN - der Ursprung liegt auf dem Glas, die Zelle sinkt also in die
## Fläche, statt in der Luft zu schrumpfen.
const MATERIALIZE_FROM := 0.12
const MATERIALIZE_TIME := 0.26
const DEMATERIALIZE_TIME := 0.16

## Gehäuse: dunkles Polymer mit Metallanteil. Bei reinem Schwarz bleibt von der
## Kassette auf dem Filz nur eine Silhouette übrig - der Anstrich muss hell genug
## sein, dass das Spill-Licht der Werkbank eine Kante zeichnet.
const SHELL_ALBEDO := Color(0.105, 0.10, 0.152)
const SHELL_EMISSION := Color(0.10, 0.11, 0.20)
const SHELL_EMISSION_ENERGY := 0.30
## Chassis: gebürstetes Hellmetall. Es zeichnet zweierlei - die Blende um das
## Fenster (aus einem Loch wird eine eingelassene Scheibe) und einen schmalen
## Kragen rings um den Körper. Der Kragen ist das, was die Kassette auf dunklem
## Filz vom Scherenschnitt unterscheidet: das Gehäuse darf schwarz bleiben, WEIL
## eine helle Kante seine Silhouette zeichnet. Bewusst farbneutral - die
## Sortenfarbe gehört dem Kern allein.
const BEZEL_LIP := WIDTH * 0.035
const BEZEL_RISE := DEPTH * 0.16
const CHASSIS_RIM := WIDTH * 0.022
const CHASSIS_ALBEDO := Color(0.34, 0.35, 0.42)
const CHASSIS_EMISSION := Color(0.52, 0.58, 0.78)
const CHASSIS_EMISSION_ENERGY := 0.30
## Scheibe: dunkles Rauchglas, damit der Kern DURCH sie leuchtet statt neben ihr.
## Bewusst fast neutral getönt: ein blaustichiges Glas zog den goldenen Kern der
## Runen ins Olive - die Scheibe soll dämpfen, nicht umfärben.
const GLASS_ALBEDO := Color(0.16, 0.16, 0.19, 0.24)
const GLASS_EMISSION_ENERGY := 0.09
## Kontaktgold - dieselbe Marken-Goldquelle wie die ×n-Marke im Regal.
const FIN_EMISSION_ENERGY := 0.30

## Anteil der Sortenfarbe im Albedo des Kerns: er ist ein Leuchtkörper, seine
## Farbe soll aus der Emission kommen, nicht aus dem Anstrich.
const CORE_ALBEDO_SHARE := 0.22
## Der Kern ist die Hinterleuchtung des Netzes und liegt darum als EINE Platte
## GENAU HINTER ihm - was von ihm zu sehen ist, sind die Fugen des Kreuzes und
## sein Saum. Über das ganze Fenster gelegt fraß sein Leuchten das Netz.
const CORE_NET_MARGIN := 1.10

## ×n-Marke über dem Stapel (Gold wie die Regal-Marke).
const BADGE_FONT := 64
const BADGE_HEIGHT := HEIGHT * 0.26
const BADGE_GAP := HEIGHT * 0.16

## Kantenlänge der gebackenen Siegel-Textur. Das Zeichen liegt auf einer Fläche,
## die kleiner ist als eine Netzkachel - mehr Pixel wären Vorrat für nichts.
const GLYPH_TEXTURE_SIZE := 128

## Das PRÄGENETZ auf der Fläche: es füllt den Ausschnitt GANZ aus - zwischen ihm
## und der Kartenkante steht nur noch die Blende (Spieler-Entscheid 2026-09-04:
## die Schrift war zu klein). Es liegt VOR der Scheibe - dahinter fräße das
## Rauchglas seine Ziffern.
const NET_WIDTH_SHARE := 1.0
const NET_PROUD := 0.004
## Beim versiegelten Stück rückt es hoch: darunter liegt das Siegelband.
const NET_SEALED_LIFT := 0.16

## Der RAHMEN trägt die Sorte: die Blende mischt so viel Sortenfarbe ins Chassis.
const FRAME_TINT_SHARE := 0.62
## ... und die GRÖSSE trägt seine Stärke und sein Glühen - je Stufe über Standard
## breiter und heller. Die Blendenhöhe (BEZEL_RISE) bleibt fest: an ihr misst die
## Liegehöhe der Kassette in jeder Auslage.
const TIER_LIP_GAIN := 0.45
const TIER_GLOW_GAIN := 0.55

var sort: String = Engraving.CATEGORY_NUMBER
## Paketgröße (Pack.TIER_*): sie zeichnet die Streifen auf der Kappe und die
## Stärke des Rahmens.
var tier: int = Pack.TIER_NORMAL
var tint: Color = PackDrawerView.GOLD
## Das Prägenetz, das die Fläche zeigt (Pack.stamp_net). Leer = leeres Kreuz in
## der Sortenfarbe - so steht eine Kassette da, die ihr Paket noch nicht kennt.
var stamp_net: Array = []

## Alles Gebaute hängt unter _body: die Zelle steht mit ihrem URSPRUNG auf dem
## Glas, und _body trägt die Verschiebung, die aus Stehen Liegen macht.
var _body: Node3D
var _cells: Array[Node3D] = []
var _badge: Label3D
## Die Stückzahl auf der Kappe - die Marke der STEHENDEN Zelle. Die goldene
## Schwebemarke oben bleibt der liegenden Lage; aus der Grube ragte sie heraus.
var _cap_badge: Label3D
## LIEGEND ist die Grundlage: die Tischkameras blicken fast senkrecht nach unten,
## und stehend fällt die Kassette dort zu einem schwarzen Strich zusammen.
var _lying := true
## Mischwert der Lage (0 = liegend, 1 = stehend). Nur damit lässt sich das
## Aufrichten zeigen, statt es zu schalten; beide Enden sind exakt die Posen.
var _pose_blend := 0.0
## Sichtbarer Anteil der Höhe über dem Glas (1 = ganz oben, SUNK_SHOW = gesteckt).
var _show_share := 1.0
var _count := 1
var _dimmed := false
## Anzeige-Maßstab des KÖRPERS: eine Kassette in bloßer Würfelgröße läge in der
## Grube wie in ihrem Leser verloren. Magazin UND Schlitz stehen auf demselben
## Maß (PackDrawerView.CASSETTE_SCALE) - eine Karte behält ihre Größe ihr ganzes
## Leben lang. Der Ursprung bleibt dabei auf dem Glas, skaliert wird darunter.
var _body_scale := 1.0
## Steckt sie in einem Leseschlitz? Dann brennt die Kopfkante.
var _socketed := false
## Der Zeiger liegt auf ihr: sie steigt aus der Grube und leuchtet auf.
var _hovered := false
var _hover_share := 0.0
var _hover_tween: Tween
var _flare_tween: Tween
var _scale_tween: Tween
var _glide_tween: Tween
## Die drei Stücke des Trage-Bogens (arc_to): Start, Ziel und die Höhe des Scheitels
## über der Sehne.
var _arc_from := Vector3.ZERO
var _arc_to := Vector3.ZERO
var _arc_hump := 0.0
var _pose_tween: Tween
var _body_scale_tween: Tween

## Geteilte Materialien des ganzen Stapels: Dimmen und Flare treffen so jede
## Kopie zugleich, ohne dass ein Aufrufer sie einzeln kennt.
var _shell_material: StandardMaterial3D
var _bezel_material: StandardMaterial3D
var _glass_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _edge_material: StandardMaterial3D
var _fin_material: StandardMaterial3D
## Die Netz-Fläche und ihr EIGENER Ofen (nur für den abgedunkelten Zustand bzw.
## als Rückfall, wenn der geteilte gerade fehlt).
var _net_material: StandardMaterial3D
var _net_oven: SubViewport
var _drained: Array[bool] = []
var _cap_material: StandardMaterial3D
## Das gebackene Sortenzeichen auf der Kappe, dunkel getönt: dort muss es Tinte
## sein, kein Leuchten. Die Fläche trägt es nicht mehr - dort liegt das Netz.
var _cap_glyph_material: StandardMaterial3D
var _band_material: StandardMaterial3D
## Die hellen Größen-Streifen und der (beim Kolossalen goldene) Kragen.
var _tier_material: StandardMaterial3D
var _collar_material: StandardMaterial3D

## Das Siegelzeichen einer Sorte wird EINMAL gebacken und von allen Kassetten
## geteilt. Ein eigener SubViewport je Zelle kostete gemessene ~11,5 ms - das war
## der Ruck beim Bestücken einer Bucht und beim Aufbau des Magazins, und die
## Zeichnung hängt an nichts als der Sorte.
static var _glyph_ovens: Dictionary = {}
static var _glyph_holder: Node = null

func _init() -> void:
	name = "DataCell"

## Einziger Eingang: baut die Zelle einer Sorte (Pack.SHELF_ORDER) in ihrer
## Paketgröße (Pack.TIER_*) mit dem Prägenetz ihres Pakets - die Größe zeichnet
## Kappe und Rahmenstärke, nie den Körper.
func setup(cell_sort: String, cell_tier: int = 0, net: Array = []) -> void:
	sort = cell_sort
	tier = maxi(cell_tier, 0)
	stamp_net = net.duplicate() if not net.is_empty() else StampNet.empty_net()
	tint = PackDrawerView.COLORS.get(sort, PackDrawerView.GOLD)
	_build_materials()
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_badge = _build_badge()
	_body.add_child(_badge)
	_cap_badge = _build_cap_badge()
	_body.add_child(_cap_badge)
	_apply_pose()
	set_count(_count)

## Der Sonderbestand ist versiegelt: Band quer über das Fenster, kein Kern.
func sealed() -> bool:
	return sort == Pack.SHELF_SPECIAL

# --- Das PRÄGENETZ auf der Fläche -------------------------------------------------

## Der Ton dieser Karte: die Regal-Farbe ihrer Sorte - eine OPERATOR-Karte aber
## amber, die eine Farbtrennung der Serie. Rahmen, Netz-Zellen und leeres Kreuz
## lesen ihn.
func net_accent() -> Color:
	return PressNetView.OPERATOR_TINT if has_operator() else tint

## Trägt das Netz einen Operator? Dann rechnet die Karte, statt zu prägen.
func has_operator() -> bool:
	for face in StampNet.FACES:
		if StampNet.kind_of(StampNet.cell_at(stamp_net, face)) == StampNet.KIND_OPERATOR:
			return true
	return false

## Maß der Netz-Fläche: quer in die Fensterbreite gesetzt, längs nach dem
## Seitenverhältnis der Backung - so bleibt das Kreuz unverzerrt. Die SCHABLONE
## der Serien-Zeremonie mißt sich an derselben Rechnung, darum steht sie statisch.
static func net_span(cell_scale: float) -> Vector2:
	var span := StampNetOven.span()
	var width := opening_size().x * NET_WIDTH_SHARE * cell_scale
	return Vector2(width, width * span.y / maxf(span.x, 1.0))

## Das Netz DIESER Karte: sie liegt überall QUER und trägt darum die hochkante
## Backung, und die füllt den Rahmen fast ganz - also wird sie an der Fensterhöhe
## gedeckelt. Ein VERSIEGELTES Stück rückt sein Netz über das Band, ihm bleibt
## entsprechend weniger Platz.
func net_size() -> Vector2:
	var span := net_span(1.0)
	var room := opening_size().y * NET_WIDTH_SHARE
	if sealed():
		room -= opening_size().y * NET_SEALED_LIFT * 2.0
	if span.y > room and span.y > 0.0:
		span *= room / span.y
	return span

## Die Netz-Fläche (und ihre Hinterleuchtung) auf das aktuelle Maß bringen - nach
## einem Wechsel der Orientierung. Neu gebaute Kopien nehmen es aus net_size()
## ohnehin schon mit.
func _apply_net_layout() -> void:
	var span := net_size()
	var mid := opening_center_y() \
		+ (opening_size().y * NET_SEALED_LIFT if sealed() else 0.0)
	for cell: Node3D in _cells:
		var plate := cell.get_node_or_null("StampNet") as MeshInstance3D
		if plate != null and plate.mesh is QuadMesh:
			(plate.mesh as QuadMesh).size = span
			plate.position = Vector3(0.0, mid, DEPTH * 0.5 + NET_PROUD)
		var core := cell.get_node_or_null("Core") as MeshInstance3D
		if core != null and core.mesh is BoxMesh:
			(core.mesh as BoxMesh).size = Vector3(span.x * CORE_NET_MARGIN,
				span.y * CORE_NET_MARGIN, DEPTH * 0.30)
			core.position = Vector3(0.0, mid, DEPTH * 0.02)

## Welche Zelle ihres PRÄGENETZES der Zeiger trifft (-1 = keine, auch neben der
## Netz-Fläche). Geschnitten wird im WELTRAUM gegen die Ebene der Netz-Platte, nicht
## in Display-Pixeln: so antwortet die Karte in JEDER Lage - flach in der
## Magazin-Grube, geneigt im Schacht, liegend in einer Auslage -, und niemand muß
## ihre Projektion nachrechnen.
func net_face_at(camera: Camera3D, screen_pos: Vector2) -> int:
	if camera == null or not visible or _cells.is_empty():
		return -1
	var plate := _cells[0].get_node_or_null("StampNet") as MeshInstance3D
	if plate == null or not plate.visible or not (plate.mesh is QuadMesh):
		return -1
	var span := (plate.mesh as QuadMesh).size
	if span.x <= 0.0 or span.y <= 0.0:
		return -1
	var world := plate.global_transform
	var hit = Plane(world.basis.z.normalized(), world.origin).intersects_ray(
		camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))
	if hit == null:
		return -1
	var local := world.affine_inverse() * (hit as Vector3)
	# Das Quad mißt von seiner MITTE und sein y zeigt nach oben, die Backung von
	# oben links - beides hier geradegerückt.
	return PressNetView.upright_face_at(Vector2(local.x / span.x + 0.5,
		0.5 - local.y / span.y))

## Rahmenstärke dieser Größe - die eine Größen-Marke der Fläche.
func bezel_lip() -> float:
	return BEZEL_LIP * (1.0 + TIER_LIP_GAIN * float(mini(tier, Pack.TIER_KOLOSSAL)))

## Die genannten Seiten sind AUFGENOMMEN (Schablonen-Fahrt) und dunkeln ab. Der
## Endzustand steht zuerst: die Textur wird neu gebacken, nicht animiert.
## Idempotent - dieselbe Maske schreibt nichts.
func set_net_drained(faces: Array) -> void:
	var mask := _drain_mask(faces)
	if mask == _drained:
		return
	_drained = mask
	_apply_net_texture()

func clear_net_drained() -> void:
	set_net_drained([])

func net_drained() -> Array:
	return _drained.duplicate()

func net_texture() -> Texture2D:
	return _net_material.albedo_texture if _net_material != null else null

static func _drain_mask(faces: Array) -> Array[bool]:
	var mask: Array[bool] = []
	for face in StampNet.FACES:
		mask.append(face < faces.size() and bool(faces[face]))
	if not mask.has(true):
		mask.clear()  # nichts aufgenommen heißt: der geteilte Ruhestand
	return mask

## Der EINE Schreiber der Netz-Fläche: die Ruhe-Backung ist geteilt (das Netz steht
## ab der Erzeugung fest), die abgedunkelte gehört dieser Kassette.
func _apply_net_texture() -> void:
	if _net_material == null:
		return
	if _drained.is_empty():
		var shared := StampNetOven.texture(stamp_net, net_accent())
		if shared != null:
			_drop_net_oven()
			_net_material.albedo_texture = shared
			return
	_drop_net_oven()
	_net_oven = StampNetOven.bake(stamp_net, net_accent(), _drained)
	add_child(_net_oven)
	_net_material.albedo_texture = _net_oven.get_texture()

func _drop_net_oven() -> void:
	if _net_oven == null:
		return
	if is_instance_valid(_net_oven):
		remove_child(_net_oven)
		_net_oven.queue_free()
	_net_oven = null

## Wie viele Kassetten der Stapel zeigt; darüber zählt nur noch die Marke.
func set_count(n: int) -> void:
	_count = maxi(n, 0)
	if _body == null:
		return  # vor setup nur gemerkt - gebaut wird beim Aufbau
	var shown := mini(_count, STACK_CAP)
	while _cells.size() > shown:
		var spare: Node3D = _cells.pop_back()
		_body.remove_child(spare)
		spare.queue_free()
	while _cells.size() < shown:
		var cell := _build_cell()
		var step := float(_cells.size())
		cell.position = Vector3(step * STACK_STAGGER, 0.0, step * STACK_PITCH)
		_body.add_child(cell)
		_cells.append(cell)
	_apply_cap_yaw(lerpf(0.0, STAND_YAW, _pose_blend))  # frische Kappen mitdrehen
	_place_badge()

func count() -> int:
	return _count

func stack_size() -> int:
	return _cells.size()

## Wie viele Kassetten wirklich zu sehen sind: STEHEND ist ein Bündel EINE Karte
## mit ihrer Zahl auf der Kappe - eine Reihe in die Tiefe läse sich in der Grube
## als Fächer aus Slivern, nicht als Stapel.
func shown_cells() -> int:
	var shown := 0
	for cell in _cells:
		if cell.visible:
			shown += 1
	return shown

func badge_text() -> String:
	return _badge.text if _badge != null else ""

func cap_badge_text() -> String:
	return _cap_badge.text if _cap_badge != null and _cap_badge.visible else ""

## Gedimmt heißt: der Kern verglimmt. Der Körper bleibt stehen - eine gesperrte
## Zelle ist da, sie ist nur nicht anfassbar.
func set_dimmed(on: bool) -> void:
	_dimmed = on
	_kill_flare()
	_set_glow(rest_energy())

func dimmed() -> bool:
	return _dimmed

## Der Zeiger liegt auf ihr: sie zieht sich ein Stück aus der Grube und leuchtet
## auf, wie eine Akte, die man aus der Schublade hebt. Idempotent - der Abgleich
## darf sie je Bild rufen; ein laufendes Gleiten stört sie nicht, der Hub sitzt im
## Körper, nicht im Platz.
func set_hovered(on: bool) -> void:
	if _hovered == on:
		return
	_hovered = on
	_kill_flare()
	_set_glow(rest_energy())
	_kill(_hover_tween)
	_hover_tween = create_tween()
	var lift := _hover_tween.tween_method(_set_hover_share, _hover_share,
		1.0 if on else 0.0, HOVER_TIME)
	lift.set_trans(Tween.TRANS_SINE)
	lift.set_ease(Tween.EASE_OUT)

func hovered() -> bool:
	return _hovered

func hover_share() -> float:
	return _hover_share

func _set_hover_share(value: float) -> void:
	_hover_share = clampf(value, 0.0, 1.0)
	_apply_pose()

## Der Lese-Moment: der Kern schießt über die Ruhegrenze und klingt zurück.
func flare() -> void:
	_kill_flare()
	_set_glow(FLARE_ENERGY)
	_flare_tween = create_tween()
	_flare_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_flare_tween.tween_method(_set_glow, FLARE_ENERGY, rest_energy(), FLARE_TIME)

## Legt die Zelle flach aufs Glas (Grundlage) oder stellt sie hin. Stehend ist sie
## die Steck-Lage: auf dem Regal liegt sie.
func lay_flat(on: bool) -> void:
	_tween_pose(0.0 if on else 1.0, 0.0)

func lying() -> bool:
	return _lying

## Das Aufrichten vor dem Einstecken (Zeit 0 = hart). Der Ursprung bleibt dabei
## auf dem Glas - gekippt wird der Körper, nicht der Platz.
func raise_upright(time: float) -> void:
	_tween_pose(1.0, time)

## Und zurück in die Liegelage, wenn sie heimfährt.
func lay_over(time: float) -> void:
	_tween_pose(0.0, time)

## Die LAGE frei setzen (0 = liegend, 1 = stehend); dazwischen mischen Kippung,
## Roll und Yaw gemeinsam.
func set_pose(blend: float, time := 0.0) -> void:
	_tween_pose(clampf(blend, 0.0, 1.0), time)

func pose() -> float:
	return _pose_blend

## Das Einstecken: die Zelle fährt SENKRECHT in den Tisch, bis nur noch `show` der
## Höhe über dem Glas steht. Gemessen wird vom jetzigen Stand aus - die Tischfläche
## liegt nicht zwingend auf y = 0.
func plunge(show: float, time: float) -> void:
	var next := clampf(show, SUNK_GONE, 1.0)
	_kill(_glide_tween)
	var target := global_position
	target.y += drop_for(_show_share) - drop_for(next)
	_show_share = next
	_place_badge()
	if time <= 0.0:
		global_position = target
		return
	_glide_tween = create_tween()
	var dive := _glide_tween.tween_property(self, "global_position", target, time)
	dive.set_trans(Tween.TRANS_CUBIC)
	dive.set_ease(Tween.EASE_IN_OUT)

## Anzeige-Maßstab des Körpers (Zeit 0 = hart). Er verschiebt nichts an ihrem
## Platz: der Ursprung liegt auf dem Glas.
func set_body_scale(value: float, time := 0.0) -> void:
	var wanted := maxf(value, 0.01)
	_kill(_body_scale_tween)
	if time <= 0.0 or is_equal_approx(_body_scale, wanted):
		_apply_body_scale(wanted)
		return
	_body_scale_tween = create_tween()
	var grow := _body_scale_tween.tween_method(_apply_body_scale, _body_scale, wanted, time)
	grow.set_trans(Tween.TRANS_SINE)
	grow.set_ease(Tween.EASE_IN_OUT)

func body_scale() -> float:
	return _body_scale

## Der Anzeige-Maßstab verändert die STANDHÖHE, also auch, wie tief die Zelle
## unter ihrem Glaspunkt hängt: die Differenz wird sofort ausgeglichen, sonst
## stünde eine große Kassette aus der Grube heraus.
func _apply_body_scale(value: float) -> void:
	var before := drop_for(_show_share)
	_body_scale = value
	global_position.y += before - drop_for(_show_share)
	_apply_pose()
	_place_badge()

## Hart auf ihren Steckplatz (Glaspunkt): stehend, tief im Tisch, Kopfkante hell.
## Für den idempotenten Schreiber - die Richtigkeit hängt an keinem Tween. Der
## Leseschlitz ist auf das EINE Kassettenmaß geschnitten, also steht sie auch
## darin in genau diesem.
func seat_hard(at: Vector3) -> void:
	_kill(_glide_tween)
	_kill(_pose_tween)
	set_body_scale(PackDrawerView.CASSETTE_SCALE)
	_lying = false
	_show_share = SUNK_SHOW  # vor der Lage: sie entscheidet über die Marke
	_set_pose_blend(1.0)
	set_socketed(true)
	global_position = at - Vector3.UP * drop_for(SUNK_SHOW)

## GRUBE (Magazin): hart auf ihren Magazin-Platz - sie STEHT dort im Loch, Kappe
## eine Spur unter der Tischkante, nicht gesteckt. Das Gegenstück zu seat_hard -
## der eine idempotente Schreiber des Fachs; der Anzeige-Maßstab bleibt, den setzt
## das Fach. Genannt wird ihr GLASPUNKT, nicht ihre Einsinktiefe.
func stand_in_pit(glass_at: Vector3) -> void:
	_kill(_glide_tween)
	_kill(_pose_tween)
	_lying = false
	badge_on_face = false  # stehend trägt die KAPPE die Zahl
	_show_share = PIT_SHOW  # vor der Lage: sie entscheidet über die Marke
	_set_pose_blend(1.0)
	set_socketed(false)
	global_position = glass_at - Vector3.UP * drop_for(PIT_SHOW)

## FLÄCHE (Läden): hart stehend AUF der Tischfläche, mit voller Höhe über dem
## Glas, nicht gesteckt - so steht eine Kassette dort, wo es kein Loch gibt.
## Heute LIEGT jede Ware in einer Auslage; die stehende Lage hält der Aufstieg
## offen (rise_through_glass ohne lying_pose), einen Wirt hat sie gerade nicht.
func stand_on_glass(at: Vector3) -> void:
	_kill(_glide_tween)
	_kill(_pose_tween)
	_lying = false
	_show_share = 1.0  # vor der Lage: sie entscheidet über die Marke
	_set_pose_blend(1.0)
	set_socketed(false)
	global_position = at

## FLÄCHE (Läden): hart auf ihren Platz in einer VERKAUFS-Auslage - sie LIEGT dort
## auf der Tischfläche, die große Fläche nach oben. Im Archiv steht die Kassette,
## in der Auslage liegt sie, und was der Aufrufer nennt, ist beide Male ihr Platz.
func lie_on_glass(at: Vector3) -> void:
	_kill(_glide_tween)
	_kill(_pose_tween)
	_lying = true
	_show_share = 1.0  # liegend steckt sie in nichts - die Marke bleibt sichtbar
	_set_pose_blend(0.0)
	set_socketed(false)
	global_position = at

## Wie weit eine LIEGENDE Kassette unter ihren Ursprung reicht: die Kontaktfinnen
## stehen hinten eine Spur über die Karte hinaus. Wer sie auf einen Boden legt,
## hebt sie um genau dieses Maß an.
static func lying_under(cell_scale: float) -> float:
	return maxf(FIN_DEPTH - DEPTH, 0.0) * 0.5 * cell_scale

## Und wie hoch sie über ihm steht. Ihr höchster Punkt ist die KAPPE, nicht die
## Blende: quer gerollt kragt sie zu beiden Seiten der Karte aus, und liegend zeigt
## diese Auskragung nach OBEN. Daran mißt jede Auslage, in der sie LIEGT - die
## Magazin-Grube rechnet seit der Welle O wieder stehend (STAND_HEIGHT).
static func lying_over(cell_scale: float) -> float:
	return (DEPTH * 0.5 + maxf(DEPTH * 0.5 + BEZEL_RISE, CAP_DEPTH * 0.5)) * cell_scale

## GRUBE (Magazin): die Ankunft im Loch - die Kassette steigt aus dem Grubenboden
## auf ihre versenkte Standhöhe. Der ENDZUSTAND steht zuerst (stand_in_pit,
## byteweise derselbe) - gefahren wird nur der Weg dorthin, damit ein übersprungener
## oder abgeräumter Tween nichts schuldig bleibt. from_below ist die Grubentiefe:
## so tief startet sie, dass sie unter dem Boden liegt.
func rise_into_pit(glass_at: Vector3, from_below: float, delay := 0.0,
		time := RISE_TIME) -> void:
	stand_in_pit(glass_at)
	_start_rise(from_below, delay, time)

## FLÄCHE (Läden): die Kassette steigt DURCH die Tischfläche auf ihren Platz -
## unten testet das opake Display sie weg, dann wächst sie heraus. Der ENDZUSTAND
## steht zuerst (stand_on_glass bzw. lie_on_glass, byteweise derselbe) - gefahren
## wird nur der Weg dorthin, damit ein übersprungener oder abgeräumter Tween nichts
## schuldig bleibt. from_below < 0 heißt: ihr eigenes Körpermaß (rise_depth).
func rise_through_glass(at: Vector3, delay := 0.0, time := RISE_TIME,
		lying_pose := false, from_below := -1.0) -> void:
	if lying_pose:
		lie_on_glass(at)
	else:
		stand_on_glass(at)
	_start_rise(from_below if from_below >= 0.0 else rise_depth(), delay, time)

## Der Weg NACH dem Endzustand: von so tief unten herauf auf die Stelle, an der die
## Zelle schon steht. Beide Ankünfte teilen ihn - nur die Starttiefe unterscheidet
## sie (Grubenboden bzw. eigenes Körpermaß).
func _start_rise(from_below: float, delay: float, time: float) -> void:
	_kill(_scale_tween)
	visible = true
	scale = Vector3.ONE
	if time <= 0.0 or from_below <= 0.0:
		return
	var target := global_position
	global_position = target - Vector3.UP * from_below
	_glide_tween = create_tween()
	if delay > 0.0:
		_glide_tween.tween_interval(delay)
	var rise := _glide_tween.tween_property(self, "global_position", target, time)
	rise.set_trans(Tween.TRANS_CUBIC)
	rise.set_ease(Tween.EASE_OUT)
	# Erst oben lodert sie: ein Ausbruch unter der Fläche sähe niemand.
	_glide_tween.tween_callback(flare)

## Wie tief eine Zelle AUF der Fläche startet, bis nichts mehr von ihr über dem
## Glas steht - ihr eigenes Körpermaß in der jeweiligen Lage. In der Grube nennt
## der Aufrufer stattdessen deren Tiefe.
func rise_depth() -> float:
	if _lying:
		return lying_over(_body_scale)
	return STAND_HEIGHT * _body_scale

## Wie tief die Zelle unter ihrem Glaspunkt hängt, wenn `show` von ihr übersteht.
## Statisch auf dem Grundmaß (Schlitz und Einschub stehen auf 1) ...
static func sunk_drop(show: float) -> float:
	return STAND_HEIGHT * (1.0 - show)

## ... und als Instanz MIT dem Anzeige-Maßstab: eine gewachsene Kassette hängt
## tiefer, sonst ragte ihre Kappe über den Grubenrand.
func drop_for(show: float) -> float:
	return STAND_HEIGHT * _body_scale * (1.0 - show)

## Ihr GLASPUNKT (der Platz, auf dem sie steht) - der Abgleich vergleicht damit,
## nicht mit der eingesunkenen Position.
func glass_position() -> Vector3:
	return global_position + Vector3.UP * drop_for(_show_share)

## Sichtbarer Höhenanteil (1 = ganz über dem Glas).
func show_share() -> float:
	return _show_share

func sunk() -> bool:
	return _show_share < 1.0

## Fährt gerade etwas an ihr? Der Schreiber lässt eine laufende Geste in Ruhe.
func busy() -> bool:
	return gliding() or (_pose_tween != null and _pose_tween.is_valid())

## Im Leseschlitz brennt die Kopfkante - sie ist dort die einzige Anzeige.
func set_socketed(on: bool) -> void:
	_socketed = on
	_sync_edge(glow_energy())

func socketed() -> bool:
	return _socketed

## Ruhelicht der Kopfkante in ihrem jetzigen Zustand.
func edge_rest_energy() -> float:
	if _dimmed:
		return EDGE_DIM_ENERGY
	return EDGE_LIVE_ENERGY if _socketed else EDGE_REST_ENERGY

func edge_energy() -> float:
	return _edge_material.emission_energy_multiplier if _edge_material != null else 0.0

func _tween_pose(target: float, time: float) -> void:
	_kill(_pose_tween)
	_lying = target < 0.5
	if time <= 0.0:
		_set_pose_blend(target)
		return
	_pose_tween = create_tween()
	var turn := _pose_tween.tween_method(_set_pose_blend, _pose_blend, target, time)
	turn.set_trans(Tween.TRANS_SINE)
	turn.set_ease(Tween.EASE_IN_OUT)

func _set_pose_blend(value: float) -> void:
	_pose_blend = clampf(value, 0.0, 1.0)
	_apply_pose()
	_place_badge()

## Aus dem Nichts an ihren Platz - dieselbe Geste wie beim schwebenden Würfel.
## delay: das Kleinwerden geschieht SOFORT, nur das Wachsen wartet, damit eine
## ganze Regal-Zeile gestaffelt aufgeht, ohne vorher in voller Größe dazustehen.
func materialize(delay: float = 0.0) -> void:
	_kill(_scale_tween)
	visible = true
	scale = Vector3.ONE * MATERIALIZE_FROM
	_scale_tween = create_tween()
	if delay > 0.0:
		_scale_tween.tween_interval(delay)
	var grow := _scale_tween.tween_property(self, "scale", Vector3.ONE, MATERIALIZE_TIME)
	grow.set_trans(Tween.TRANS_BACK)
	grow.set_ease(Tween.EASE_OUT)

## Abtreten, ohne freigegeben zu werden: derselbe Körper steht später wieder auf.
func dematerialize() -> void:
	if not visible:
		return
	_kill(_scale_tween)
	_scale_tween = create_tween()
	var shrink := _scale_tween.tween_property(self, "scale",
		Vector3.ONE * MATERIALIZE_FROM, DEMATERIALIZE_TIME)
	shrink.set_trans(Tween.TRANS_QUAD)
	shrink.set_ease(Tween.EASE_IN)
	_scale_tween.tween_callback(_hide_body)

## Die Zelle wandert an einen anderen Platz (Regal -> Schlitz und zurück). Das Ziel
## ist immer ein GLASPUNKT; wie tief sie darunter hängt, weiß sie selbst. Zeit 0
## setzt sie hart: die Richtigkeit hängt an keinem Tween.
func glide_to(glass_target: Vector3, time: float) -> void:
	_kill(_glide_tween)
	var target := glass_target - Vector3.UP * drop_for(_show_share)
	if time <= 0.0:
		global_position = target
		return
	_glide_tween = create_tween()
	var move := _glide_tween.tween_property(self, "global_position", target, time)
	move.set_trans(Tween.TRANS_SINE)
	move.set_ease(Tween.EASE_IN_OUT)

func gliding() -> bool:
	return _glide_tween != null and _glide_tween.is_valid()

## DER TRAGE-BOGEN: was der SPIELER bewegt, fliegt ÜBER dem Tisch. Die Kassette
## reist als KÖRPER von ihrem Stand auf einen anderen GLASPUNKT - ganz über dem
## Glas, ohne Drehung und ohne Lagewechsel (beide Enden stehen). XZ läuft gerade,
## Y als Parabel mit dem Scheitel `peak` über dem höheren Ende; unter die Sehne
## kommt sie nie, also nie unter das Glas.
func arc_to(glass_target: Vector3, time: float, peak: float) -> void:
	_kill(_glide_tween)
	_arc_from = glass_position()  # der Bogen startet auf ihrem GLASPUNKT, nicht im Loch
	_show_share = 1.0  # der ganze Körper steht über dem Glas
	_place_badge()
	_arc_to = glass_target
	global_position = _arc_from  # sie hebt sich sofort aufs Glas, dann fliegt sie
	var chord := (_arc_from.y + glass_target.y) * 0.5
	_arc_hump = maxf(maxf(_arc_from.y, glass_target.y) + maxf(peak, 0.0) - chord, 0.0)
	if time <= 0.0:
		global_position = glass_target
		return
	_glide_tween = create_tween()
	var fly := _glide_tween.tween_method(_set_arc_share, 0.0, 1.0, time)
	fly.set_trans(Tween.TRANS_CUBIC)
	fly.set_ease(Tween.EASE_IN_OUT)

func _set_arc_share(share: float) -> void:
	var seat := _arc_from.lerp(_arc_to, share)
	seat.y += 4.0 * _arc_hump * share * (1.0 - share)
	global_position = seat

## Ruhelicht dieser Zelle (gedimmt, überfahren oder normal) - Zielwert jedes
## Flare-Ausklangs.
func rest_energy() -> float:
	if _dimmed:
		return DIM_ENERGY
	return HOVER_ENERGY if _hovered else REST_ENERGY

## Ruhelicht der Kappe. Sie ist eine satte Fläche, kein Punkt: sie bleibt auch
## beim Greifen deutlich unter dem Kern, sonst frisst ihr Blühen ihr Zeichen.
func cap_rest_energy() -> float:
	if _dimmed:
		return CAP_DIM_ENERGY
	return CAP_REST_ENERGY * (1.45 if _hovered else 1.0)

## Der leuchtende Teil: Kern, beim Sonderbestand das Siegelband.
func glow_material() -> StandardMaterial3D:
	return _band_material if sealed() else _core_material

func glow_color() -> Color:
	var material := glow_material()
	return material.emission if material != null else Color.BLACK

func glow_energy() -> float:
	var material := glow_material()
	return material.emission_energy_multiplier if material != null else 0.0

func has_core() -> bool:
	return _core_material != null

func has_band() -> bool:
	return _band_material != null

# --- Aufbau ---------------------------------------------------------------------

## Höhe der Fenstermitte über der Gehäusemitte: der Fußbalken ist breiter als der
## Kopfbalken, also sitzt der Ausschnitt höher als die Mitte.
static func opening_center_y() -> float:
	return (FOOT_BAR - TOP_BAR) * 0.5

## Deckfläche der Kappe über der Gehäusemitte - die höchste Fläche der Kassette.
static func cap_top_y() -> float:
	return HEIGHT * 0.5 + CAP_PROUD

## Ihre KRONE: die Kappe samt allem, was eine Spur darauf steht (Zeichen und
## Größen-Streifen). Wer misst, wie viel Luft eine stehende Zelle nach oben hat,
## misst hiergegen, nicht gegen die Kappe.
static func crown_y() -> float:
	return cap_top_y() + TIER_STRIPE_PROUD

static func opening_size() -> Vector2:
	return Vector2(WIDTH - SIDE_BAR * 2.0, HEIGHT - TOP_BAR - FOOT_BAR)

func _apply_pose() -> void:
	if _body == null:
		return
	# Stehend hebt der Ursprung auf halbe Höhe, liegend auf halbe Tiefe: beides
	# setzt die Zelle auf das Glas, nicht hinein. Dazwischen wird schlicht
	# gemischt - die Enden bleiben exakt die beiden Posen.
	var angle := lerpf(-PI * 0.5, 0.0, _pose_blend)
	var upright := STAND_HEIGHT * 0.5
	var lift := lerpf(DEPTH * 0.5, upright, _pose_blend) * _body_scale
	# Der Griff hebt den KÖRPER, nicht den Platz: er überlebt jedes Gleiten und
	# jeden Neuaufbau des Fachs. Er gilt in BEIDEN Lagen - im Archiv zieht man die
	# stehende Akte heraus, in der Bucht hebt man die liegende Ware an; wie weit,
	# sagt hover_lift, und das setzt der Wirt.
	lift += STAND_HEIGHT * hover_lift * _hover_share * _body_scale
	# Der ROLL sitzt VOR der Kippung (in der Karten-Ebene): er dreht das Blatt in
	# sich, nicht seine Neigung zur Kamera. Er FOLGT der Lage - liegend quer
	# (Läden, Wetten, Wurf), stehend ungedreht und damit kappe-oben.
	var roll := lerpf(PI * 0.5, 0.0, _pose_blend)
	# Der YAW um die Hochachse folgt der Lage: STEHEND ist die Karte HOCHKANT -
	# ihre Fläche zeigt nach Bild-links, von oben ist sie ein schmaler, tiefer
	# Balken, und die Reihe steht Fläche an Fläche wie eine Kartei.
	var yaw := lerpf(0.0, STAND_YAW, _pose_blend)
	_body.transform = Transform3D(
		Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, angle)
			.scaled(Vector3.ONE * _body_scale) * Basis(Vector3.BACK, roll),
		Vector3(0.0, lift, 0.0))
	_apply_cap_yaw(yaw)

## Kappen-Zeichen und Bündelzahl liegen flach auf der Kappe und drehen mit dem Yaw
## mit - sie werden um ihn GEGEN-gedreht, damit sie von oben aufrecht lesen.
func _apply_cap_yaw(yaw: float) -> void:
	var back := Basis(Vector3.UP, -yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
	if _cap_badge != null:
		_cap_badge.basis = back
	for cell in _cells:
		var glyph := cell.get_node_or_null("CapGlyph") as MeshInstance3D
		if glyph != null:
			glyph.basis = back

func _build_materials() -> void:
	_shell_material = StandardMaterial3D.new()
	_shell_material.albedo_color = SHELL_ALBEDO
	_shell_material.metallic = 0.55
	_shell_material.roughness = 0.34
	_shell_material.emission_enabled = true
	_shell_material.emission = SHELL_EMISSION
	_shell_material.emission_energy_multiplier = SHELL_EMISSION_ENERGY

	# Der Rahmen IST die Sortenmarke der Fläche, seit das Netz auf ihr liegt: er
	# trägt ihre Farbe, und je Paketgröße glüht er stärker.
	var frame := net_accent()
	_bezel_material = StandardMaterial3D.new()
	_bezel_material.albedo_color = CHASSIS_ALBEDO.lerp(frame, FRAME_TINT_SHARE)
	_bezel_material.metallic = 0.45
	_bezel_material.roughness = 0.32
	_bezel_material.emission_enabled = true
	_bezel_material.emission = CHASSIS_EMISSION.lerp(frame, FRAME_TINT_SHARE)
	_bezel_material.emission_energy_multiplier = (CHASSIS_EMISSION_ENERGY
		* (1.0 + TIER_GLOW_GAIN * float(mini(tier, Pack.TIER_KOLOSSAL))))

	_glass_material = StandardMaterial3D.new()
	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.albedo_color = GLASS_ALBEDO
	_glass_material.metallic = 0.15
	_glass_material.metallic_specular = 0.9
	_glass_material.roughness = 0.06
	_glass_material.emission_enabled = true
	_glass_material.emission = _scaled(tint, 1.0)
	_glass_material.emission_energy_multiplier = GLASS_EMISSION_ENERGY
	_glass_material.cull_mode = BaseMaterial3D.CULL_BACK

	_fin_material = StandardMaterial3D.new()
	_fin_material.albedo_color = _scaled(PackDrawerView.GOLD, 0.85)
	_fin_material.metallic = 1.0
	_fin_material.roughness = 0.24
	_fin_material.emission_enabled = true
	_fin_material.emission = _scaled(PackDrawerView.GOLD, 1.0)
	_fin_material.emission_energy_multiplier = FIN_EMISSION_ENERGY

	_net_material = StandardMaterial3D.new()
	_net_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Vor der Scheibe gezeichnet: zwei alphagemischte Flächen sortiert der
	# Compatibility-Renderer sonst nach Laune.
	_net_material.render_priority = 2
	_apply_net_texture()

	_cap_material = _lit_material(tint)
	_cap_material.albedo_color = _scaled(tint, 0.55)  # satte Fläche, nicht nur Licht
	_cap_material.emission_energy_multiplier = CAP_REST_ENERGY

	_cap_glyph_material = StandardMaterial3D.new()
	_cap_glyph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cap_glyph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cap_glyph_material.albedo_texture = _sort_glyph()
	_cap_glyph_material.albedo_color = CAP_INK  # gebackenes Zeichen, dunkel getönt
	_cap_glyph_material.render_priority = 3

	_edge_material = _lit_material(tint)
	_edge_material.emission_energy_multiplier = EDGE_REST_ENERGY

	if tier > Pack.TIER_NORMAL:
		_tier_material = _lit_material(tint.lerp(Color.WHITE, 0.55))
		_tier_material.emission_energy_multiplier = TIER_STRIPE_ENERGY
	# Der Kragen ist beim Kolossalen golden getönt - EIGENES Material, sonst zöge
	# die Tönung die Blende vor der Scheibe mit.
	_collar_material = _bezel_material
	if tier >= Pack.TIER_KOLOSSAL:
		_collar_material = StandardMaterial3D.new()
		_collar_material.albedo_color = CHASSIS_ALBEDO.lerp(PackDrawerView.GOLD,
			TIER_COLLAR_GOLD)
		_collar_material.metallic = 0.85
		_collar_material.roughness = 0.28
		_collar_material.emission_enabled = true
		_collar_material.emission = _scaled(PackDrawerView.GOLD, 1.0)
		# Bewusst kaum heller als der normale Kragen: von oben sieht man von ihm nur
		# schmale Kanten, und die blühten bei starkem Licht zu diagonalen Schlieren
		# über die Nachbarzellen auf. Die Farbe trägt, nicht die Energie.
		_collar_material.emission_energy_multiplier = CHASSIS_EMISSION_ENERGY * 1.2

	if sealed():
		_band_material = _lit_material(tint)
	else:
		_core_material = _lit_material(tint)

func _lit_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _scaled(color, CORE_ALBEDO_SHARE)
	material.metallic = 0.0
	material.roughness = 0.62
	material.emission_enabled = true
	material.emission = _scaled(color, 1.0)
	material.emission_energy_multiplier = REST_ENERGY
	return material

## Farbe mal Faktor OHNE ihr Alpha anzufassen - ein halbdurchsichtiger Anstrich
## auf einem deckenden Material ist eine stille Falle.
static func _scaled(color: Color, factor: float) -> Color:
	return Color(color.r * factor, color.g * factor, color.b * factor, 1.0)

## Eine Kassette des Stapels. Alle Kopien teilen Meshes und Materialien.
func _build_cell() -> Node3D:
	var cell := Node3D.new()
	cell.name = "Cell%d" % _cells.size()
	var opening := opening_size()
	var mid := opening_center_y()

	# Die Rückwand schließt nur den AUSSCHNITT und sitzt eine Spur vor der
	# Gehäuserückseite: über die volle Fläche lägen ihre Rückflächen deckungs-
	# gleich auf denen der Balken und flimmerten im Tiefenpuffer.
	_add_box(cell, "Back", Vector3(opening.x * 1.02, opening.y * 1.02, BACK_DEPTH),
		Vector3(0.0, mid, -(DEPTH - BACK_DEPTH) * 0.5 + DEPTH * 0.03), _shell_material)
	# Der Kragen ist ein RING um den Körper, kein Block: als Vollkörper schluckte
	# er den Kern, der in derselben Tiefe sitzt.
	var collar := DEPTH * 0.40
	var collar_x := (WIDTH + CHASSIS_RIM) * 0.5
	var collar_y := (HEIGHT + CHASSIS_RIM) * 0.5
	_add_box(cell, "CollarLeft", Vector3(CHASSIS_RIM, HEIGHT + CHASSIS_RIM * 2.0, collar),
		Vector3(-collar_x, 0.0, 0.0), _collar_material)
	_add_box(cell, "CollarRight", Vector3(CHASSIS_RIM, HEIGHT + CHASSIS_RIM * 2.0, collar),
		Vector3(collar_x, 0.0, 0.0), _collar_material)
	_add_box(cell, "CollarTop", Vector3(WIDTH, CHASSIS_RIM, collar),
		Vector3(0.0, collar_y, 0.0), _collar_material)
	_add_box(cell, "CollarFoot", Vector3(WIDTH, CHASSIS_RIM, collar),
		Vector3(0.0, -collar_y, 0.0), _collar_material)
	var side_x := (WIDTH - SIDE_BAR) * 0.5
	_add_box(cell, "BarLeft", Vector3(SIDE_BAR, HEIGHT, DEPTH),
		Vector3(-side_x, 0.0, 0.0), _shell_material)
	_add_box(cell, "BarRight", Vector3(SIDE_BAR, HEIGHT, DEPTH),
		Vector3(side_x, 0.0, 0.0), _shell_material)
	_add_box(cell, "BarTop", Vector3(opening.x, TOP_BAR, DEPTH),
		Vector3(0.0, (HEIGHT - TOP_BAR) * 0.5, 0.0), _shell_material)
	_add_box(cell, "BarFoot", Vector3(opening.x, FOOT_BAR, DEPTH),
		Vector3(0.0, -(HEIGHT - FOOT_BAR) * 0.5, 0.0), _shell_material)

	# Der KERN ist die Hinterleuchtung des Netzes: eine Platte in der Sortenfarbe,
	# die durch die Fugen des Kreuzes scheint. Die drei Riegel von früher lägen
	# unter dem Netz und stritten mit ihm.
	if _core_material != null:
		var lit := net_size() * CORE_NET_MARGIN
		_add_box(cell, "Core", Vector3(lit.x, lit.y, DEPTH * 0.30),
			Vector3(0.0, mid + (opening.y * NET_SEALED_LIFT if sealed() else 0.0),
				DEPTH * 0.02), _core_material)

	# Die Blende steht vor der Gehäusefläche, die Scheibe liegt in ihrem Ring.
	var lip := bezel_lip()
	var lip_x := opening.x * 0.5 + lip * 0.5
	var lip_y := opening.y * 0.5 + lip * 0.5
	var lip_z := DEPTH * 0.5 + BEZEL_RISE * 0.5
	_add_box(cell, "BezelLeft", Vector3(lip, opening.y + lip * 2.0, BEZEL_RISE),
		Vector3(-lip_x, mid, lip_z), _bezel_material)
	_add_box(cell, "BezelRight", Vector3(lip, opening.y + lip * 2.0, BEZEL_RISE),
		Vector3(lip_x, mid, lip_z), _bezel_material)
	_add_box(cell, "BezelTop", Vector3(opening.x, lip, BEZEL_RISE),
		Vector3(0.0, mid + lip_y, lip_z), _bezel_material)
	_add_box(cell, "BezelFoot", Vector3(opening.x, lip, BEZEL_RISE),
		Vector3(0.0, mid - lip_y, lip_z), _bezel_material)

	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var pane := QuadMesh.new()
	pane.size = Vector2(opening.x * 1.02, opening.y * 1.02)
	glass.mesh = pane
	glass.material_override = _glass_material
	glass.position = Vector3(0.0, mid, DEPTH * 0.40)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(glass)

	# Das PRÄGENETZ: die ganze Auskunft der Fläche, quer in die Fensterbreite
	# gesetzt. Beim versiegelten Stück rückt es hoch - darunter liegt das Band.
	var net_plate := MeshInstance3D.new()
	net_plate.name = "StampNet"
	var quad := QuadMesh.new()
	quad.size = net_size()
	net_plate.mesh = quad
	net_plate.material_override = _net_material
	net_plate.position = Vector3(0.0,
		mid + (opening.y * NET_SEALED_LIFT if sealed() else 0.0),
		DEPTH * 0.5 + NET_PROUD)
	net_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(net_plate)

	if _band_material != null:
		_add_box(cell, "Seal", Vector3(WIDTH * 1.04, HEIGHT * 0.16, DEPTH * 1.12),
			Vector3(0.0, mid - opening.y * 0.30, 0.0), _band_material)

	# Die KAPPE: massive Sortenfarbe auf der Kopfkante, ihre Oberfläche exakt auf
	# HEIGHT/2 - so bleibt die Standhöhe die alte und die Einsink-Rechnung stimmt.
	var cap_top := cap_top_y()
	_add_box(cell, "Cap", Vector3(CAP_WIDTH, CAP_H, CAP_DEPTH),
		Vector3(0.0, cap_top - CAP_H * 0.5, 0.0), _cap_material)
	# Das Sortenzeichen liegt FLACH auf der Kappe, links; rechts bleibt Platz für
	# die Bündelzahl. -90° um X dreht die Quad-Fläche nach oben, ihr Oben zeigt
	# dann nach lokal -Z = Bildschirm-oben (die Zelle steht um -90° um Y gedreht).
	var cap_side := CAP_DEPTH * CAP_GLYPH_SHARE
	var cap_glyph := MeshInstance3D.new()
	cap_glyph.name = "CapGlyph"
	var cap_plate := QuadMesh.new()
	cap_plate.size = Vector2(cap_side, cap_side)
	cap_glyph.mesh = cap_plate
	cap_glyph.material_override = _cap_glyph_material
	cap_glyph.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	cap_glyph.position = Vector3(-(CAP_WIDTH * 0.5 - cap_side * 0.62),
		cap_top + 0.002, 0.0)
	cap_glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(cap_glyph)

	# Die GRÖSSEN-Streifen: rechts neben dem Zeichen, einer je Stufe über Standard.
	if _tier_material != null:
		for i in mini(tier, Pack.TIER_KOLOSSAL):
			_add_box(cell, "TierStripe%d" % i,
				Vector3(TIER_STRIPE_W, TIER_STRIPE_H, TIER_STRIPE_DEPTH),
				Vector3(TIER_STRIPE_X + float(i) * TIER_STRIPE_PITCH,
					cap_top + TIER_STRIPE_PROUD - TIER_STRIPE_H * 0.5, 0.0),
				_tier_material)

	# Der Lichtsaum unter der Kappe - steckt die Zelle, steht mit ihr nur er über
	# dem Glas; er ragt eine Spur weiter und zeichnet ihre Brüstung nach.
	_add_box(cell, "EdgeStrip",
		Vector3(EDGE_STRIP_WIDTH, EDGE_STRIP_H, EDGE_STRIP_DEPTH),
		Vector3(0.0, cap_top - CAP_H - EDGE_STRIP_H * 0.5, 0.0),
		_edge_material)

	var fin_y := -(HEIGHT * 0.5) + FOOT_BAR * 0.34
	for i in FIN_COUNT:
		var t := 0.0 if FIN_COUNT < 2 else float(i) / float(FIN_COUNT - 1) - 0.5
		_add_box(cell, "Fin%d" % i, Vector3(FIN_WIDTH, FOOT_BAR * 0.44, FIN_DEPTH),
			Vector3(t * FIN_SPREAD, fin_y, 0.0), _fin_material)

	return cell

func _add_box(host: Node3D, box_name: String, box_size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(instance)

func _build_badge() -> Label3D:
	var badge := Label3D.new()
	badge.name = "CountBadge"
	badge.font_size = BADGE_FONT
	badge.pixel_size = BADGE_HEIGHT / float(BADGE_FONT)
	badge.modulate = PackDrawerView.GOLD
	badge.outline_size = 10
	badge.outline_modulate = CasinoStyle.INK
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.text = ""
	return badge

## Die Bündelzahl auf der Kappe: flach liegend, dunkel auf der Sortenfarbe, am
## rechten Ende - links steht das Sortenzeichen.
func _build_cap_badge() -> Label3D:
	var badge := Label3D.new()
	badge.name = "CapBadge"
	badge.font_size = CAP_BADGE_FONT
	badge.pixel_size = CAP_BADGE_HEIGHT / float(CAP_BADGE_FONT)
	badge.modulate = CAP_INK
	badge.outline_size = 0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	badge.position = Vector3(CAP_WIDTH * 0.28, cap_top_y() + 0.004, 0.0)
	badge.text = ""
	badge.visible = false
	return badge

## Die Marke sitzt über der OBERSTEN Kassette und in DEREN Ebene: einen halben
## Stapel weiter vorn gesetzt läuft ihr die Perspektive davon und legt sie mitten
## auf die Kassette statt darüber.
func _place_badge() -> void:
	if _badge == null:
		return
	_sync_stack()
	var standing := _pose_blend >= 0.5
	if _cap_badge != null:
		# STEHEND liegt die Zahl flach auf der Kappe: aus der Grube ragte eine
		# schwebende Marke heraus, und ein Bündel steht dort als EINE Karte.
		_cap_badge.text = "×%d" % _count if _count > 1 else ""
		_cap_badge.visible = _count > 1 and standing
	_badge.text = "×%d" % _count if _count > 1 else ""
	# Eine steckende Zelle zeigt keine Schwebemarke: sie ist einzeln, und die Zahl
	# stünde als einziges Stück Schrift aus dem Tisch heraus. Die LIEGENDE Karte im
	# Magazin trägt ihre Zahl dagegen auf sich - die ragt nirgends heraus.
	_badge.visible = _count > 1 and not standing and (badge_on_face or not sunk())
	var top := maxf(float(shown_cells()) - 1.0, 0.0)
	if _pose_blend < 0.5:
		if badge_on_face:
			# In der Auslage wird die Karte von oben gelesen: neben ihr läge die
			# Marke im Nachbarplatz, also liegt sie flach auf ihrer Fußhälfte -
			# unter dem Sortenzeichen, das mittig auf der Fläche sitzt.
			_badge.position = Vector3(0.0, -HEIGHT * 0.30,
				top * STACK_PITCH + DEPTH * 1.5)
			return
		# Liegend ist der Stapel ein Turm - die Marke sitzt auf seiner Spitze.
		_badge.position = Vector3(top * STACK_STAGGER, HEIGHT * 0.5 + BADGE_GAP,
			top * STACK_PITCH + DEPTH)
		return
	# Stehend wächst der Stapel in die TIEFE, und von schräg oben projizieren
	# seine hinteren Deckel höher als seine vorderen. Die Marke muss deshalb um
	# die ganze Stapeltiefe steigen, sonst legt sie sich auf den Deckel.
	_badge.position = Vector3(top * STACK_STAGGER * 0.5,
		HEIGHT * 0.5 + BADGE_GAP + top * STACK_PITCH, top * STACK_PITCH * 0.5)

## Ein Bündel ist EINE Karte, sobald es STEHT (die Zahl auf seiner Kappe) oder
## VERSENKT liegt (die Zahl auf seiner Fläche): ein Turm aus fünf Karten ragte aus
## dem Loch. Nur AUF der Fläche liegt der Stapel wirklich da.
func _sync_stack() -> void:
	var single := _pose_blend >= 0.5 or sunk()
	for i in _cells.size():
		_cells[i].visible = not single or i == 0

## Backt das Siegelzeichen der Sorte EINMAL in eine Textur - dieselbe Zeichnung
## wie im Regal (PackIconRenderer), nie ein zweites Zeichen. Der Ofen bleibt für
## alle Kassetten dieser Sorte stehen: seine Anlage ist das Teure daran.
## null = gerade kein geteilter Ofen zu haben; dann backt die Zelle selbst.
static func glyph_texture(cell_sort: String) -> Texture2D:
	var known: SubViewport = _glyph_ovens.get(cell_sort)
	if known != null and is_instance_valid(known):
		return known.get_texture()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	if _glyph_holder == null or not is_instance_valid(_glyph_holder):
		var holder := Node.new()
		holder.name = "DataCellGlyphOvens"
		tree.root.add_child(holder)
		if not holder.is_inside_tree():
			holder.free()  # der Baum nimmt gerade nichts auf
			return null
		_glyph_holder = holder
	var oven := _new_glyph_oven(cell_sort)
	_glyph_holder.add_child(oven)
	_glyph_ovens[cell_sort] = oven
	return oven.get_texture()

static func _new_glyph_oven(cell_sort: String) -> SubViewport:
	var oven := SubViewport.new()
	oven.name = "GlyphOven"
	oven.size = Vector2i(GLYPH_TEXTURE_SIZE, GLYPH_TEXTURE_SIZE)
	oven.transparent_bg = true
	oven.render_target_update_mode = SubViewport.UPDATE_ONCE
	var icon := PackIconRenderer.for_type(Pack.pack_type_of_shelf(cell_sort))
	icon.size = Vector2(GLYPH_TEXTURE_SIZE, GLYPH_TEXTURE_SIZE)
	oven.add_child(icon)
	return oven

## Das geteilte Zeichen - notfalls backt diese Zelle es eben selbst.
func _sort_glyph() -> Texture2D:
	var shared := glyph_texture(sort)
	if shared != null:
		return shared
	var oven := _new_glyph_oven(sort)
	add_child(oven)
	return oven.get_texture()

func _set_glow(energy: float) -> void:
	var material := glow_material()
	if material != null:
		material.emission_energy_multiplier = energy
	_sync_edge(energy)
	_sync_cap(energy)

## Die Kappe steht wie die Kopfkante auf ihrem EIGENEN Zustand und reißt beim
## Lesen nur mit.
func _sync_cap(core_energy: float) -> void:
	if _cap_material == null:
		return
	var over := maxf(core_energy - rest_energy(), 0.0)
	_cap_material.emission_energy_multiplier = (cap_rest_energy()
		+ over * EDGE_FLARE_SHARE)

## Die Kopfkante steht auf ihrem eigenen Zustand und reißt bei einem Kern-Ausbruch
## nur mit - anders bliebe der gesteckte Sliver beim Lesen stumm.
func _sync_edge(core_energy: float) -> void:
	if _edge_material == null:
		return
	var over := maxf(core_energy - rest_energy(), 0.0)
	_edge_material.emission_energy_multiplier = (edge_rest_energy()
		+ over * EDGE_FLARE_SHARE)

func _hide_body() -> void:
	visible = false

func _kill_flare() -> void:
	_kill(_flare_tween)

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
