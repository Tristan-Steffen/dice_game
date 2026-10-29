class_name DataCellView
extends Node3D
## Die Datenzelle: ein versiegeltes Aufwertungs-Paket als physische Kassette auf
## dem Tisch. Dunkles Gehäuse mit Fensterausschnitt, dahinter ein Kern in der
## Sortenfarbe, davor eine Glasscheibe und darauf ihr PRÄGENETZ, an der Unterkante
## goldene Kontaktfinnen. Rein per Code gebaut wie DieBuilder und CapacitorBankView
## - kein .tscn, kein GLB.
## Die FLÄCHE trägt seit 2026-09-02 das Netz (StampNetOven). Die KAPPE ist am
## 2026-09-04 gestorben: die SORTE sagt die FARBE, die GRÖSSE ihre INTENSITÄT -
## Sättigung UND Glühen aus EINER Quelle (tier_tint/tier_energy); die
## Rahmenstärke bleibt der stille zweite Kanal. Sie LIEGT überall (Läden, Wetten,
## Wurf, Magazin, Turm), quer gerollt - die stehende Pose ist mit der Kartei
## (2026-09-07) gestorben und seit dem 2026-09-13 gestrichen.
## Drei Regeln des Tisches gelten auch hier: nur EMISSION, keine eigenen Lichter
## (die Bodenkacheln vertragen 16); im Ruhezustand bleibt das Leuchten UNTER der
## Bloom-Schwelle, der Ausbruch (flare) gibt den Kopfraum aus; und die Sortenfarbe
## kommt aus der einen Quelle PackDrawerView.COLORS.
## Bewusst NICHT gespiegelt - dieselbe Regel wie beim Phantomwürfel: sie LIEGT auf
## dem Glas, ihr Spiegelbild fällt also neben sie und schmiert nur den Stapel und
## seine Marke zu (gemessen: ein zweites ×n neben dem echten).
## Seit 2026-09-04 ist die Karte aus GETÖNTEM GLAS: Gehäuse und Kern sind
## alphagemischt, das Netz-Quad beidseitig - von hinten liest dieselbe eine Backung
## durch den Körper hindurch, gespiegelt. Weil der Compatibility-Renderer
## Durchsichtiges nach render_priority statt nach Tiefe sortiert, steht die
## Reihenfolge als Kette fest (PRIORITY_*).

## Zulage über die Würfelkante hinaus: auf Bankdistanz las die Kassette als Karte
## zu klein, Netz und Kern verschwammen. Ein Drittel mehr ist die Größe, bei der
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
## Das AUFRECHTE Maß der Kassette ist ihre HÖHE. Jede senkrechte Rechnung mißt
## daran - der Aufstieg, der Griff und die Tiefe jeder Grube.
const STAND_HEIGHT := HEIGHT
## Die Karte ist dünn; die GRIFF-Zelle behält ihre Tiefe, damit Reihe und Magazin
## ihre Teilung behalten und der Zeiger sie findet. KEIN Körperteil - nur ein Maß.
const GRIP_DEPTH := DEPTH * 2.9

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

## Der STECKER am Fuß (Spieler-Entscheid 2026-10-27, Modell aus
## tools/blender_hardware.py): Gehäuse in der Fußkante, acht Goldstifte nach außen.
## Ursprung des Modells = Mitte der Fußkante, gebaut im ROH-Maß dieser Karte.
const CONNECTOR_SCENE := "res://assets/models/hardware/card_connector.glb"
## Sein Kragen steht auf beiden Flächen ein Stück vor - daran mißt die Liegehöhe.
const CONNECTOR_DEPTH := DEPTH * 1.12
## So weit ragen die Stifte über die Fußkante hinaus (roh, samt Spitze).
const PIN_LENGTH := 0.042
static var _connector_scene: PackedScene
## Die BUCHSE, sein Gegenstück in Mulde und Turm - im WELT-Maß der Karte bei
## CASSETTE_SCALE gebaut. Ursprung = Mitte des Mundes auf Stifthöhe, der Körper
## reicht SOCKET_DEPTH nach +Z (weg von der Karte).
const SOCKET_SCENE := "res://assets/models/hardware/card_socket.glb"
const SOCKET_DEPTH := 0.15
static var _socket_scene: PackedScene

## Sichtbarer Stapel und sein Achsabstand; darüber zählt allein die Marke. Der
## Stapel wächst entlang der DICKE, liegend also als Chip-Turm nach oben. Der
## seitliche Versatz ist der Unterschied zwischen einem Stapel und einer Zelle:
## ohne ihn deckt die vorderste Kassette alle anderen exakt zu.
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

## Die KOPFKANTE: der Lichtsaum sitzt seit dem Kappen-Tod (2026-09-04) ganz oben
## auf der Karte und ist von oben ihre einzige massive Fläche - er trägt Sorte und
## Intensität mit. Er mißt den KÖRPER, nicht mehr eine auskragende Platte, und
## steht eine Spur über dem Gehäuse: koplanar zerschnitte der Tiefenkampf von
## Balken und Kragen ihn mit dunklen Nähten.
const EDGE_STRIP_H := HEIGHT * 0.030
const EDGE_STRIP_WIDTH := WIDTH * 0.94
const EDGE_STRIP_DEPTH := DEPTH * 1.2
## Gemessen: er muß ÜBER dem Kragen stehen (CHASSIS_RIM), sonst zerschneidet dessen
## Kopfbalken ihn von oben in zwei helle Streifen mit dunkler Naht.
const EDGE_STRIP_PROUD := DEPTH * 0.22
## Ruhelicht der Kante im Regal - wie der Kern unter Rune.IDLE_CEILING.
const EDGE_REST_ENERGY := 0.62
## Eingesteckt ist der Sliver die ganze Anzeige - hell, aber NICHT weiß: über
## etwa 1,5 kippen alle drei Kanäle ins Clipping und die Sortenfarbe geht verloren
## (dieselbe Grenze wie bei den Zellen der Kondensatorbank).
const EDGE_LIVE_ENERGY := 1.35
const EDGE_DIM_ENERGY := 0.12
## Anteil, mit dem die Kante einen Kern-Ausbruch mitreißt.
const EDGE_FLARE_SHARE := 0.75

## Die GRÖSSE ist die INTENSITÄT der Sortenfarbe (Pack.TIER_*, Spieler-Entscheid
## 2026-09-04): Standard blaß und schwach, Kolossal voll gesättigt und hell.
## Entsättigt wird zum GRAU gleicher Helligkeit, nie zu Weiß - sonst wüsche
## Standard auf dem dunklen Filz aus.
const TIER_SATURATION := [0.55, 0.8, 1.0]
## Der Glüh-Faktor DÄMPFT nur: die authored Energien sind bereits an der
## Bloom-Schwelle (Rune.IDLE_CEILING) und am Weiß-Clipping bemessen, also bekommt
## das Kolossale sie ganz und die kleineren Größen einen Anteil davon.
const TIER_ENERGY := [0.70, 0.85, 1.0]

## Die Ankunft: die Kassette steigt auf ihren Platz. Etwas länger als das
## Absinken - Ankommen darf sich setzen.
const RISE_TIME := 0.35

## Das Herausziehen unterm Zeiger (wie eine Akte aus der Schublade): Anteil der
## Höhe, um den die Kassette steigt, und die Zeit dafür. Nur so ist ein Griff in
## der Grube überhaupt zu sehen - ein gemalter Schein läge unter dem Loch.
const HOVER_LIFT := 0.42
const HOVER_TIME := 0.16
## Der Spielraum, den eine gehoverte Karte den Zeiger noch hält (holds_pointer).
const HOVER_HOLD_SLACK := 0.3
## Derselbe Hub als Stellschraube der Zelle: der Wirt setzt ihn (die Läden lassen
## HOVER_LIFT stehen, der Regalstapel rechnet seinen eigenen).
var hover_lift := HOVER_LIFT
## Der ZWEITE Hover-Kanal (Welle X): die LIEGENDE Karte fährt längs ihrer eigenen
## Achse nach Bild-LINKS heraus, statt zu steigen - so zieht der Turm sie unter dem
## Zeiger aus ihrer Etage. Anteil der Kartenlänge; die Auslagen lassen ihn auf 0
## und heben weiter. EIN Tween für beide Kanäle (_hover_share).
var hover_slide := 0.0
## Wohin die ×n-Marke gehört. Normal schwebt sie über dem Stapel; in einer Auslage
## steht die Karte dicht bei ihren Nachbarn - neben ihr läge die Marke im fremden
## Platz, also liegt sie AUF ihr.
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

## Gehäuse: GETÖNTES GLAS in der Sortenfarbe (Spieler-Entscheid 2026-09-04). Der
## Körper ist durchscheinend, also liest das Prägenetz auch von HINTEN - durch ihn
## hindurch, gespiegelt, physikalisch ehrlich; einen zweiten Druck gibt es nicht.
const GLASS_BODY_ALPHA := 0.32
const GLASS_BODY_EMISSION := 0.34
## Rahmen, Kragen und Kopfkante sind seit dem 2026-09-07 ebenfalls halb
## durchsichtig (Spieler-Entscheid): die ganze Karte ist Glas, nur das NETZ (die
## "die-view") bleibt deckend.
const GLASS_FRAME_ALPHA := 0.5
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

## Anteil der Sortenfarbe im Albedo des Kerns: er ist ein Leuchtkörper, seine
## Farbe soll aus der Emission kommen, nicht aus dem Anstrich.
const CORE_ALBEDO_SHARE := 0.22
## Der Kern ist die Hinterleuchtung des Netzes und liegt darum als EINE Platte
## GENAU HINTER ihm - was von ihm zu sehen ist, sind die Fugen des Kreuzes und
## sein Saum. Über das ganze Fenster gelegt fraß sein Leuchten das Netz.
const CORE_NET_MARGIN := 1.10
## Und er ist DURCHSCHEINEND, seit der Körper Glas ist: deckend blockte er den
## Blick von hinten aufs Netz.
const CORE_ALPHA := 0.45

## Zeichen-Reihenfolge der alphagemischten Flächen. Der Compatibility-Renderer
## sortiert sie nach render_priority, nicht nach Tiefe - ohne diese Kette
## verschwindet das Netz hinter dem Körper-Glas.
const PRIORITY_BODY := -2
const PRIORITY_CORE := -1
## Rahmen, Kragen und Kopfkante: durchsichtig, aber VOR Körper/Kern/Scheibe und
## HINTER dem Netz - so liest das deckende Netz zuletzt und klar.
const PRIORITY_FRAME := 1
const PRIORITY_NET := 2
## Die Marke liegt VOR dem Netz - ihr Umriß eine Stufe darunter, sonst schluckt ihn
## die Backung.
const PRIORITY_BADGE_OUTLINE := 3
const PRIORITY_BADGE := 4
## Die Scheibe lag bisher stillschweigend auf 0 - sie braucht die Zahl jetzt, weil
## der EBENEN-VERSATZ auf jede Priorität rechnet.
const PRIORITY_PANE := 0
## Wie weit die Prioritäten je STAPEL-EBENE auseinanderliegen: eine Karte belegt
## PRIORITY_BODY (−2) bis PRIORITY_BADGE (4) und die Tablett-Platte darunter (−3),
## also acht Stufen - zehn geben Luft. Ohne den Versatz zeichnete das Netz einer
## TIEFEN Karte (höchste Priorität) über das Glas der Reihe DARÜBER hinweg.
const LAYER_SPAN := 10

## ×n-Marke über dem Stapel (Gold wie die Regal-Marke).
const BADGE_FONT := 64
const BADGE_HEIGHT := HEIGHT * 0.26
const BADGE_GAP := HEIGHT * 0.16

## Das PRÄGENETZ auf der Fläche: es füllt den Ausschnitt GANZ aus - zwischen ihm
## und der Kartenkante steht nur noch die Blende (Spieler-Entscheid 2026-09-04:
## die Schrift war zu klein). Es liegt VOR der Scheibe - dahinter fräße das
## Rauchglas seine Ziffern.
const NET_WIDTH_SHARE := 1.0
const NET_PROUD := 0.004

## Der RAHMEN trägt die Sorte: die Blende mischt so viel Sortenfarbe ins Chassis.
const FRAME_TINT_SHARE := 0.62
## ... und die GRÖSSE trägt seine Stärke: der stille zweite Lesart-Kanal neben der
## Intensität. Die Blendenhöhe (BEZEL_RISE) bleibt fest: an ihr misst die
## Liegehöhe der Kassette in jeder Auslage.
const TIER_LIP_GAIN := 0.45

var sort: String = Engraving.CATEGORY_NUMBER
## Paketgröße (Pack.TIER_*): sie sagt die INTENSITÄT der Sortenfarbe und die
## Stärke des Rahmens.
var tier: int = Pack.TIER_NORMAL
var tint: Color = PackDrawerView.GOLD
## Das Prägenetz, das die Fläche zeigt (Pack.stamp_net). Leer = leeres Kreuz in
## der Sortenfarbe - so steht eine Kassette da, die ihr Paket noch nicht kennt.
var stamp_net: Array = []

## Alles Gebaute hängt unter _body: die Zelle liegt mit ihrem URSPRUNG auf dem
## Glas, und _body trägt Kippung, Roll und Hub der Liegelage.
var _body: Node3D
var _cells: Array[Node3D] = []
var _badge: Label3D
## Der Prioritäts-Versatz dieser Karte: 0 = oberste Ebene, je tiefer desto negativer.
var _layer_bias := 0
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
var _body_scale_tween: Tween

## Geteilte Materialien des ganzen Stapels: Dimmen und Flare treffen so jede
## Kopie zugleich, ohne dass ein Aufrufer sie einzeln kennt.
var _shell_material: StandardMaterial3D
var _bezel_material: StandardMaterial3D
var _glass_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _edge_material: StandardMaterial3D
## Die Netz-Fläche und ihr EIGENER Ofen (nur für den abgedunkelten Zustand bzw.
## als Rückfall, wenn der geteilte gerade fehlt).
var _net_material: StandardMaterial3D
var _net_oven: SubViewport
var _drained: Array[bool] = []

func _init() -> void:
	name = "DataCell"

## Einziger Eingang: baut die Zelle einer Sorte (Pack.SHELF_ORDER) in ihrer
## Paketgröße (Pack.TIER_*) mit dem Prägenetz ihres Pakets - die Größe zeichnet
## Intensität und Rahmenstärke, nie den Körper. gilded = die Reparatur-Karte:
## Gold statt Sortenfarbe, in voller Stärke.
func setup(cell_sort: String, cell_tier: int = 0, net: Array = [],
		gilded := false, blank := false) -> void:
	sort = cell_sort
	# Reparatur-Karte und ROHLING sind GRÖSSENLOS: volle Stufe, damit die
	# Größen-Entsättigung ihren Ton nicht zu Grau wäscht - er IST ihr Erkennungszeichen.
	tier = Pack.TIER_KOLOSSAL if gilded or blank else maxi(cell_tier, 0)
	stamp_net = net.duplicate() if not net.is_empty() else StampNet.empty_net()
	tint = PackDrawerView.REPAIR_TINT if gilded \
		else PackDrawerView.tint_of(sort, "", stamp_net, blank)
	_build_materials()
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_badge = _build_badge()
	_body.add_child(_badge)
	_apply_pose()
	set_count(_count)

# --- Das PRÄGENETZ auf der Fläche -------------------------------------------------

## Der Ton dieser Karte: die Regal-Farbe ihrer Sorte - eine OPERATOR-Karte aber
## amber, die eine Farbtrennung der Serie. Rahmen, Netz-Zellen und leeres Kreuz
## lesen ihn.
func net_accent() -> Color:
	return PressNetView.OPERATOR_TINT if has_operator() else tint

## Die SORTE sagt die Farbe, die GRÖSSE ihre Sättigung: der Ton dieser Karte,
## nach Stufe zum Grau GLEICHER Helligkeit hin entsättigt. Die EINE Farbquelle
## jeder getönten Fläche - Körper, Kern, Kopfkante, Rahmen und Netz-Backung.
func tier_tint() -> Color:
	return tier_shade(net_accent(), tier)

## Dieselbe Leiter für jeden, der die Karte NICHT ist (die Sorten-Ticks der
## Tablett-Blende, die Felder der Etagen-Leiste): EINE Rechnung, ein Bild.
static func tier_shade(base: Color, cell_tier: int) -> Color:
	var grey := base.get_luminance()
	var share: float = TIER_SATURATION[clampi(cell_tier, 0, TIER_SATURATION.size() - 1)]
	return Color(grey, grey, grey, base.a).lerp(base, share)

## ... und ihr Glühen. Der Faktor dämpft nur - die authored Energien stehen schon
## an der Bloom-Schwelle, also bekommt das Kolossale sie ganz.
func tier_energy() -> float:
	return TIER_ENERGY[clampi(tier, 0, TIER_ENERGY.size() - 1)]

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
## gedeckelt. Der Sonderbestand trägt es GENAU SO groß wie jede andere Sorte
## (Spieler-Entscheid 2026-09-11 - sein Siegelband ist gestorben).
func net_size() -> Vector2:
	var span := net_span(1.0)
	var room := opening_size().y * NET_WIDTH_SHARE
	if span.y > room and span.y > 0.0:
		span *= room / span.y
	return span

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

## Hält die GEHOVERTE Karte den Zeiger noch? Ihr Netz plus slack je Seite (Anteil
## der Netzspanne): wer beim Lesen der Zellen knapp über den Rand rutscht, verliert
## die Karte nicht gleich (Spieler-Wunsch 2026-10-29). Gemessen an der Lage, in der
## sie GERADE liegt - auch angehoben oder ausgezogen.
func holds_pointer(camera: Camera3D, screen_pos: Vector2, slack := HOVER_HOLD_SLACK) -> bool:
	if camera == null or not is_visible_in_tree() or _cells.is_empty():
		return false
	var plate := _cells[0].get_node_or_null("StampNet") as MeshInstance3D
	if plate == null or not (plate.mesh is QuadMesh):
		return false
	var span := (plate.mesh as QuadMesh).size
	if span.x <= 0.0 or span.y <= 0.0:
		return false
	var world := plate.global_transform
	var hit = Plane(world.basis.z.normalized(), world.origin).intersects_ray(
		camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))
	if hit == null:
		return false
	var local := world.affine_inverse() * (hit as Vector3)
	return absf(local.x / span.x) <= 0.5 + slack and absf(local.y / span.y) <= 0.5 + slack

## Rahmenstärke dieser Größe - die eine Größen-Marke der Fläche.
func bezel_lip() -> float:
	return BEZEL_LIP * (1.0 + TIER_LIP_GAIN * float(mini(tier, Pack.TIER_KOLOSSAL)))

## Die genannten Seiten sind AUFGENOMMEN (sie gehen im Block auf) und dunkeln ab. Der
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
		var shared := StampNetOven.texture(stamp_net, tier_tint())
		if shared != null:
			_drop_net_oven()
			_net_material.albedo_texture = shared
			return
	_drop_net_oven()
	_net_oven = StampNetOven.bake(stamp_net, tier_tint(), _drained)
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
	_place_badge()

func count() -> int:
	return _count

func stack_size() -> int:
	return _cells.size()

func badge_text() -> String:
	return _badge.text if _badge != null and _badge.visible else ""

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

## Der Ursprung bleibt auf dem Glas - skaliert wird nur der Körper darüber.
func _apply_body_scale(value: float) -> void:
	_body_scale = value
	_apply_pose()
	_place_badge()

## Der EINE harte Schreiber ihres Platzes: sie LIEGT auf dem genannten GLASPUNKT,
## die große Fläche nach oben - in jeder Auslage, im Tablett, in der Etage.
func lie_on_glass(at: Vector3) -> void:
	_kill(_glide_tween)
	_apply_pose()
	_place_badge()
	set_socketed(false)
	global_position = at

## Wie weit eine LIEGENDE Kassette unter ihren Ursprung reicht: der Stecker steht
## hinten eine Spur über die Karte hinaus. Wer sie auf einen Boden legt, hebt sie um
## genau dieses Maß an.
static func lying_under(cell_scale: float) -> float:
	return maxf(CONNECTOR_DEPTH - DEPTH, 0.0) * 0.5 * cell_scale

## Und wie hoch sie über ihm liegt. Seit dem Kappen-Tod ist ihr höchster Punkt die
## BLENDE - liegende Ware sitzt entsprechend flacher. Daran mißt jede Auslage.
static func lying_over(cell_scale: float) -> float:
	return (DEPTH * 0.5 + DEPTH * 0.5 + BEZEL_RISE) * cell_scale

## Die Kassette steigt DURCH die Fläche auf ihren Platz - unten testet das opake
## Display sie weg, dann wächst sie heraus. Der ENDZUSTAND steht zuerst
## (lie_on_glass, byteweise derselbe) - gefahren wird nur der Weg dorthin, damit
## ein übersprungener oder abgeräumter Tween nichts schuldig bleibt. from_below < 0
## heißt: ihr eigenes Körpermaß (rise_depth).
func rise_through_glass(at: Vector3, delay := 0.0, time := RISE_TIME,
		from_below := -1.0) -> void:
	lie_on_glass(at)
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
## Glas steht - ihr eigenes liegendes Körpermaß. In der Grube nennt der Aufrufer
## stattdessen deren Tiefe.
func rise_depth() -> float:
	return lying_over(_body_scale)

## Ihr GLASPUNKT (der Platz, auf dem sie liegt): seit dem Ende des Einsinkens ihr
## Ursprung selbst - der Abgleich vergleicht damit.
func glass_position() -> Vector3:
	return global_position

## Fährt gerade etwas an ihr? Der Schreiber lässt eine laufende Geste in Ruhe.
func busy() -> bool:
	return gliding()

## Im Leseschlitz brennt die Kopfkante - sie ist dort die einzige Anzeige.
func set_socketed(on: bool) -> void:
	_socketed = on
	_sync_edge(glow_energy())

func socketed() -> bool:
	return _socketed

## Ruhelicht der Kopfkante in ihrem jetzigen Zustand - mit der Intensität ihrer
## Größe, wie jede getönte Fläche der Karte.
func edge_rest_energy() -> float:
	if _dimmed:
		return EDGE_DIM_ENERGY
	return (EDGE_LIVE_ENERGY if _socketed else EDGE_REST_ENERGY) * tier_energy()

func edge_energy() -> float:
	return _edge_material.emission_energy_multiplier if _edge_material != null else 0.0

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

## Die Zelle wandert auf einen anderen GLASPUNKT. Zeit 0 setzt sie hart: die
## Richtigkeit hängt an keinem Tween.
func glide_to(glass_target: Vector3, time: float) -> void:
	_kill(_glide_tween)
	if time <= 0.0:
		global_position = glass_target
		return
	_glide_tween = create_tween()
	var move := _glide_tween.tween_property(self, "global_position", glass_target, time)
	move.set_trans(Tween.TRANS_SINE)
	move.set_ease(Tween.EASE_IN_OUT)

func gliding() -> bool:
	return _glide_tween != null and _glide_tween.is_valid()

## DER TRAGE-BOGEN: was der SPIELER bewegt, fliegt ÜBER dem Tisch. Die Kassette
## reist als KÖRPER von ihrem Stand auf einen anderen GLASPUNKT - ganz über dem
## Glas, ohne Drehung und ohne Lagewechsel (beide Enden liegen). XZ läuft gerade,
## Y als Parabel mit dem Scheitel `peak` über dem höheren Ende; unter die Sehne
## kommt sie nie, also nie unter das Glas.
func arc_to(glass_target: Vector3, time: float, peak: float) -> void:
	_kill(_glide_tween)
	_arc_from = glass_position()
	_place_badge()
	_arc_to = glass_target
	global_position = _arc_from  # sie hebt sich sofort aufs Glas, dann fliegt sie
	var chord := (_arc_from.y + glass_target.y) * 0.5
	var high := maxf(_arc_from.y, glass_target.y) + maxf(peak, 0.0)
	_arc_hump = minf(maxf(high - chord, 0.0),
		arc_hump_cap(_arc_from.y, glass_target.y, maxf(peak, 0.0)))
	if time <= 0.0:
		global_position = glass_target
		return
	_glide_tween = create_tween()
	var fly := _glide_tween.tween_method(_set_arc_share, 0.0, 1.0, time)
	fly.set_trans(Tween.TRANS_CUBIC)
	fly.set_ease(Tween.EASE_IN_OUT)

## Der größte HUB, mit dem der Bogen sein Versprechen hält: sein höchster Punkt
## liegt `peak` über dem höheren Ende. Bei SCHRÄGER Sehne liegt der Scheitel der
## Summe (Sehne + Parabel) nicht in der Mitte, sondern zur hohen Seite hin - ein
## voller Hub schöbe ihn also ÜBER das höhere Ende hinaus (gemessen: 0,47 Welt bei
## einer Fahrt vom Magazin in die unterste Turm-Etage, also 0,31 über den Tisch).
## Gelöst aus y(s) = a + (b-a)s + 4h·s(1-s): der Scheitel steht auf
## a + (d+4h)²/(16h), und die größte Wurzel von 16h² + 8h(d-2k) + d² = 0 (k = Ziel
## über a) ist der gesuchte Deckel.
static func arc_hump_cap(from_y: float, to_y: float, peak: float) -> float:
	var d := to_y - from_y
	var k := maxf(from_y, to_y) + maxf(peak, 0.0) - from_y
	if k <= 0.0:
		return absf(d) * 0.25
	return maxf((2.0 * k - d + 2.0 * sqrt(k * (k - d))) * 0.25, 0.0)

func _set_arc_share(share: float) -> void:
	var seat := _arc_from.lerp(_arc_to, share)
	seat.y += 4.0 * _arc_hump * share * (1.0 - share)
	global_position = seat

## Ruhelicht dieser Zelle (gedimmt, überfahren oder normal) - Zielwert jedes
## Flare-Ausklangs.
func rest_energy() -> float:
	if _dimmed:
		return DIM_ENERGY
	# Greifen und Sperren sind ZUSTÄNDE, keine Größen - nur die Ruhe trägt die
	# Intensität der Stufe.
	return HOVER_ENERGY if _hovered else REST_ENERGY * tier_energy()

## Der leuchtende Teil: der Kern.
func glow_material() -> StandardMaterial3D:
	return _core_material

func glow_color() -> Color:
	var material := glow_material()
	return material.emission if material != null else Color.BLACK

func glow_energy() -> float:
	var material := glow_material()
	return material.emission_energy_multiplier if material != null else 0.0

func has_core() -> bool:
	return _core_material != null

# --- Aufbau ---------------------------------------------------------------------

## Höhe der Fenstermitte über der Gehäusemitte: der Fußbalken ist breiter als der
## Kopfbalken, also sitzt der Ausschnitt höher als die Mitte.
static func opening_center_y() -> float:
	return (FOOT_BAR - TOP_BAR) * 0.5

static func opening_size() -> Vector2:
	return Vector2(WIDTH - SIDE_BAR * 2.0, HEIGHT - TOP_BAR - FOOT_BAR)

func _apply_pose() -> void:
	if _body == null:
		return
	# Liegend hebt der Ursprung auf halbe Dicke: die Zelle liegt AUF dem Glas.
	var lift := DEPTH * 0.5 * _body_scale
	# Der Griff hebt den KÖRPER, nicht den Platz: er überlebt jedes Gleiten und
	# jeden Neuaufbau des Fachs; wie weit, sagt hover_lift, und das setzt der Wirt.
	lift += STAND_HEIGHT * hover_lift * _hover_share * _body_scale
	# ... und der ZWEITE Kanal zieht sie längs ihrer Achse nach Bild-links heraus.
	var slide := STAND_HEIGHT * hover_slide * _hover_share * _body_scale
	# Der ROLL sitzt VOR der Kippung (in der Karten-Ebene) und legt sie QUER; die
	# Kippung um die Bildachse legt sie dann flach auf den Rücken.
	_body.transform = Transform3D(
		Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * _body_scale)
			* Basis(Vector3.BACK, PI * 0.5),
		Vector3(-slide, lift, 0.0))

## Die STAPEL-EBENE dieser Karte (0 = oberste): je tiefer sie liegt, desto weiter
## rutschen ALLE ihre Zeichen-Prioritäten nach unten. So zeichnet eine tiefe Karte
## VOR dem Glas darüber und wird von ihm gedämpft, statt mit ihrem Netz
## durchzustanzen - der Compatibility-Renderer sortiert nach Priorität, nicht nach
## Tiefe, und ohne den Versatz gewönne das Netz jeder Karte gegen jedes Glas.
func set_layer_depth(level: int) -> void:
	var wanted := -LAYER_SPAN * maxi(level, 0)
	if wanted == _layer_bias:
		return
	_layer_bias = wanted
	_apply_layer_bias()

func _prio(base: int) -> int:
	return base + _layer_bias

## Der EINE Schreiber der Prioritäten an den schon gebauten Materialien.
func _apply_layer_bias() -> void:
	if _shell_material != null:
		_shell_material.render_priority = _prio(PRIORITY_BODY)
	if _core_material != null:
		_core_material.render_priority = _prio(PRIORITY_CORE)
	if _glass_material != null:
		_glass_material.render_priority = _prio(PRIORITY_PANE)
	if _bezel_material != null:
		_bezel_material.render_priority = _prio(PRIORITY_FRAME)
	if _edge_material != null:
		_edge_material.render_priority = _prio(PRIORITY_FRAME)
	if _net_material != null:
		_net_material.render_priority = _prio(PRIORITY_NET)
	if _badge != null and is_instance_valid(_badge):
		_badge.render_priority = _prio(PRIORITY_BADGE)
		_badge.outline_render_priority = _prio(PRIORITY_BADGE_OUTLINE)

func _build_materials() -> void:
	# EINE Quelle für alles Getönte: die Sortenfarbe in der Intensität ihrer Größe.
	var shade := tier_tint()
	var gain := tier_energy()
	# Der KÖRPER ist getöntes Glas - hinten steht dieselbe eine Backung, nur
	# seitenverkehrt. cull_mode BACK, sonst zählt jede Wand doppelt.
	_shell_material = StandardMaterial3D.new()
	_shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell_material.albedo_color = Color(shade.r, shade.g, shade.b, GLASS_BODY_ALPHA)
	_shell_material.metallic = 0.20
	_shell_material.metallic_specular = 0.8
	_shell_material.roughness = 0.10
	_shell_material.emission_enabled = true
	_shell_material.emission = _scaled(shade, 1.0)
	_shell_material.emission_energy_multiplier = GLASS_BODY_EMISSION * gain
	_shell_material.cull_mode = BaseMaterial3D.CULL_BACK
	_shell_material.render_priority = _prio(PRIORITY_BODY)

	# Der Rahmen IST die Sortenmarke der Fläche, seit das Netz auf ihr liegt.
	_bezel_material = StandardMaterial3D.new()
	_bezel_material.albedo_color = CHASSIS_ALBEDO.lerp(shade, FRAME_TINT_SHARE)
	_bezel_material.metallic = 0.45
	_bezel_material.roughness = 0.32
	_bezel_material.emission_enabled = true
	_bezel_material.emission = CHASSIS_EMISSION.lerp(shade, FRAME_TINT_SHARE)
	_bezel_material.emission_energy_multiplier = CHASSIS_EMISSION_ENERGY * gain
	_bezel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bezel_material.albedo_color.a = GLASS_FRAME_ALPHA
	_bezel_material.render_priority = _prio(PRIORITY_FRAME)

	_glass_material = StandardMaterial3D.new()
	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.albedo_color = GLASS_ALBEDO
	_glass_material.metallic = 0.15
	_glass_material.metallic_specular = 0.9
	_glass_material.roughness = 0.06
	_glass_material.emission_enabled = true
	_glass_material.emission = _scaled(shade, 1.0)
	_glass_material.emission_energy_multiplier = GLASS_EMISSION_ENERGY * gain
	_glass_material.cull_mode = BaseMaterial3D.CULL_BACK
	_glass_material.render_priority = _prio(PRIORITY_PANE)

	_net_material = StandardMaterial3D.new()
	_net_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Vor der Scheibe gezeichnet: zwei alphagemischte Flächen sortiert der
	# Compatibility-Renderer sonst nach Laune. Seit der Körper Glas ist, hängt die
	# ganze Kette daran (Körper < Kern < Scheibe < Netz).
	_net_material.render_priority = _prio(PRIORITY_NET)
	# Beidseitig: von hinten zeigt die Rückseite des Quads dieselbe Textur
	# gespiegelt - genau das ehrliche Bild durch getöntes Glas.
	_net_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_apply_net_texture()

	# Die KOPFKANTE ist von oben die einzige massive Fläche der Karte: sie trägt
	# Sorte und Intensität mit.
	_edge_material = _lit_material(shade)
	_edge_material.emission_energy_multiplier = EDGE_REST_ENERGY * gain
	_edge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_edge_material.albedo_color.a = GLASS_FRAME_ALPHA
	_edge_material.render_priority = _prio(PRIORITY_FRAME)

	# Die Hinterleuchtung ist selbst durchscheinend - deckend stünde sie dem
	# Blick von hinten aufs Netz im Weg.
	_core_material = _lit_material(shade)
	_core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_core_material.albedo_color.a = CORE_ALPHA
	_core_material.render_priority = _prio(PRIORITY_CORE)

func _lit_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _scaled(color, CORE_ALBEDO_SHARE)
	material.metallic = 0.0
	material.roughness = 0.62
	material.emission_enabled = true
	material.emission = _scaled(color, 1.0)
	material.emission_energy_multiplier = REST_ENERGY * tier_energy()
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
	TableProps.box(cell, "Back", Vector3(opening.x * 1.02, opening.y * 1.02, BACK_DEPTH),
		Vector3(0.0, mid, -(DEPTH - BACK_DEPTH) * 0.5 + DEPTH * 0.03), _shell_material)
	# Der Kragen ist ein RING um den Körper, kein Block: als Vollkörper schluckte
	# er den Kern, der in derselben Tiefe sitzt.
	var collar := DEPTH * 0.40
	var collar_x := (WIDTH + CHASSIS_RIM) * 0.5
	var collar_y := (HEIGHT + CHASSIS_RIM) * 0.5
	TableProps.box(cell, "CollarLeft", Vector3(CHASSIS_RIM, HEIGHT + CHASSIS_RIM * 2.0, collar),
		Vector3(-collar_x, 0.0, 0.0), _bezel_material)
	TableProps.box(cell, "CollarRight", Vector3(CHASSIS_RIM, HEIGHT + CHASSIS_RIM * 2.0, collar),
		Vector3(collar_x, 0.0, 0.0), _bezel_material)
	TableProps.box(cell, "CollarTop", Vector3(WIDTH, CHASSIS_RIM, collar),
		Vector3(0.0, collar_y, 0.0), _bezel_material)
	TableProps.box(cell, "CollarFoot", Vector3(WIDTH, CHASSIS_RIM, collar),
		Vector3(0.0, -collar_y, 0.0), _bezel_material)
	var side_x := (WIDTH - SIDE_BAR) * 0.5
	TableProps.box(cell, "BarLeft", Vector3(SIDE_BAR, HEIGHT, DEPTH),
		Vector3(-side_x, 0.0, 0.0), _shell_material)
	TableProps.box(cell, "BarRight", Vector3(SIDE_BAR, HEIGHT, DEPTH),
		Vector3(side_x, 0.0, 0.0), _shell_material)
	TableProps.box(cell, "BarTop", Vector3(opening.x, TOP_BAR, DEPTH),
		Vector3(0.0, (HEIGHT - TOP_BAR) * 0.5, 0.0), _shell_material)
	TableProps.box(cell, "BarFoot", Vector3(opening.x, FOOT_BAR, DEPTH),
		Vector3(0.0, -(HEIGHT - FOOT_BAR) * 0.5, 0.0), _shell_material)

	# Der KERN ist die Hinterleuchtung des Netzes: eine Platte in der Sortenfarbe,
	# die durch die Fugen des Kreuzes scheint. Die drei Riegel von früher lägen
	# unter dem Netz und stritten mit ihm.
	if _core_material != null:
		var lit := net_size() * CORE_NET_MARGIN
		TableProps.box(cell, "Core", Vector3(lit.x, lit.y, DEPTH * 0.30),
			Vector3(0.0, mid, DEPTH * 0.02), _core_material)

	# Die Blende steht vor der Gehäusefläche, die Scheibe liegt in ihrem Ring.
	var lip := bezel_lip()
	var lip_x := opening.x * 0.5 + lip * 0.5
	var lip_y := opening.y * 0.5 + lip * 0.5
	var lip_z := DEPTH * 0.5 + BEZEL_RISE * 0.5
	TableProps.box(cell, "BezelLeft", Vector3(lip, opening.y + lip * 2.0, BEZEL_RISE),
		Vector3(-lip_x, mid, lip_z), _bezel_material)
	TableProps.box(cell, "BezelRight", Vector3(lip, opening.y + lip * 2.0, BEZEL_RISE),
		Vector3(lip_x, mid, lip_z), _bezel_material)
	TableProps.box(cell, "BezelTop", Vector3(opening.x, lip, BEZEL_RISE),
		Vector3(0.0, mid + lip_y, lip_z), _bezel_material)
	TableProps.box(cell, "BezelFoot", Vector3(opening.x, lip, BEZEL_RISE),
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
	# gesetzt.
	var net_plate := MeshInstance3D.new()
	net_plate.name = "StampNet"
	var quad := QuadMesh.new()
	quad.size = net_size()
	net_plate.mesh = quad
	net_plate.material_override = _net_material
	net_plate.position = Vector3(0.0, mid, DEPTH * 0.5 + NET_PROUD)
	net_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(net_plate)

	# Der Lichtsaum SITZT auf der Kopfkante, seit die Kappe tot ist: von oben ist er
	# die einzige massive Fläche der Karte. Eine Spur proud, sonst zerschneidet ihn
	# der Tiefenkampf mit den Balken darunter.
	TableProps.box(cell, "EdgeStrip",
		Vector3(EDGE_STRIP_WIDTH, EDGE_STRIP_H, EDGE_STRIP_DEPTH),
		Vector3(0.0, HEIGHT * 0.5 + EDGE_STRIP_PROUD - EDGE_STRIP_H * 0.5, 0.0),
		_edge_material)

	var connector := _connector()
	if connector != null:
		connector.position = Vector3(0.0, -HEIGHT * 0.5, 0.0)
		cell.add_child(connector)

	return cell

## Der STECKER als Modell; ohne Datei (kaputter Import) bleibt die Karte ohne ihn.
static func _connector() -> Node3D:
	if _connector_scene == null:
		_connector_scene = load(CONNECTOR_SCENE) as PackedScene
	if _connector_scene == null:
		return null
	var node := _connector_scene.instantiate() as Node3D
	node.name = "Connector"
	return node

## Die BUCHSE als Modell (null = kein Import).
static func socket_model() -> Node3D:
	if _socket_scene == null:
		_socket_scene = load(SOCKET_SCENE) as PackedScene
	if _socket_scene == null:
		return null
	var node := _socket_scene.instantiate() as Node3D
	node.name = "Buchse"
	return node

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
	# Sie liegt VOR dem Netz: ohne diese Kette schluckt die Backung sie.
	badge.render_priority = _prio(PRIORITY_BADGE)
	badge.outline_render_priority = _prio(PRIORITY_BADGE_OUTLINE)
	badge.text = ""
	return badge

## Die Marke sitzt über der OBERSTEN Kassette und in DEREN Ebene: einen halben
## Stapel weiter vorn gesetzt läuft ihr die Perspektive davon und legt sie mitten
## auf die Kassette statt darüber.
func _place_badge() -> void:
	if _badge == null:
		return
	_badge.text = "×%d" % _count if _count > 1 else ""
	_badge.visible = _count > 1
	var top := maxf(float(_cells.size()) - 1.0, 0.0)
	if badge_on_face:
		# In der Auslage wird die Karte von oben gelesen: neben ihr läge die Marke
		# im Nachbarplatz, also liegt sie flach auf ihrer Fußhälfte.
		_badge.position = Vector3(0.0, -HEIGHT * 0.30,
			top * STACK_PITCH + DEPTH * 1.5)
		return
	# Liegend ist der Stapel ein Turm - die Marke sitzt auf seiner Spitze.
	_badge.position = Vector3(top * STACK_STAGGER, HEIGHT * 0.5 + BADGE_GAP,
		top * STACK_PITCH + DEPTH)

func _set_glow(energy: float) -> void:
	var material := glow_material()
	if material != null:
		material.emission_energy_multiplier = energy
	_sync_edge(energy)

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
