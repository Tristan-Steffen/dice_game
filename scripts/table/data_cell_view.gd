class_name DataCellView
extends Node3D
## Die Datenzelle: eine Werkstatt-Karte als physischer DATENTRÄGER auf dem Tisch. Jede
## SORTE ist ihr eigener Träger (Welle 3, 2026-11-18): Zahlen die LOCHKARTE, Material die
## KASSETTE, Runen die TONTAFEL, der Sonderbestand das SERVICE-MODUL - die Hüllen sind
## Blender-Modelle (tools/blender_data_media_export.py), das PRÄGENETZ backt StampNetOven
## auf eine Platte darüber. Alle vier füllen denselben Umriß, das Netz liegt auf jedem an
## derselben Stelle (EINE Größe je Ding); nur die Dicken unterscheiden sich.
## Die SORTE sagt die FARBE, die GRÖSSE ihre INTENSITÄT - Sättigung UND Glühen aus EINER
## Quelle (tier_tint/tier_energy), gelesen an den leuchtenden Teilen der Hülle.
## Drei Regeln des Tisches gelten auch hier: nur EMISSION, keine eigenen Lichter; im
## Ruhezustand bleibt das Leuchten UNTER der Bloom-Schwelle, der Ausbruch (flare) gibt den
## Kopfraum aus; und die Sortenfarbe kommt aus der einen Quelle PackDrawerView.COLORS.
## Bewusst NICHT gespiegelt: ihr Spiegelbild fiele neben sie und schmierte Stapel und Marke zu.

## Zulage über die Würfelkante hinaus: auf Bankdistanz las die Karte sonst zu klein.
const SIZE_FACTOR := 1.35
## Standhöhe aus der Würfelkante VOR der Würfel-Vergrößerung (0,6) - die Karte wuchs nicht mit.
const HEIGHT := DieBuilder.HALF_EXTENT * 2.0 * 0.6 * SIZE_FACTOR
## Verhältnis 2 : 3 : 0,28 (Breite : Höhe : Dicke) - der Umriß JEDES Trägers.
const UNIT := HEIGHT / 3.0
const WIDTH := UNIT * 2.0
const DEPTH := UNIT * 0.28
## Das AUFRECHTE Maß ist ihre HÖHE: jede senkrechte Rechnung mißt daran.
const STAND_HEIGHT := HEIGHT
## Die GRIFF-Zelle: Reihe und Magazin behalten ihre Teilung, der Zeiger findet sie.
const GRIP_DEPTH := DEPTH * 2.9

## Der Raum des NETZES auf der Fläche (die Ränder des alten Rahmens): seitlich schmal,
## am Fuß breiter als am Kopf - das Netz sitzt darum eine Spur zum Kopf hin.
const SIDE_BAR := WIDTH * 0.0668
const TOP_BAR := HEIGHT * 0.075
const FOOT_BAR := HEIGHT * 0.135
## So hoch reicht eine liegende Karte höchstens über ihre Auflage (der dickste Träger
## samt Netz-Platte) - daran messen Auslagen, Gruben und der Aufstieg.
const TOP_CLEAR := DEPTH * 0.16

## Die vier TRÄGER, in der Reihenfolge von Pack.SHELF_ORDER.
const CARRIER_PUNCH := 0
const CARRIER_CASSETTE := 1
const CARRIER_CLAY := 2
const CARRIER_MODULE := 3
const CARRIER_SCENES := [
	"res://assets/models/hardware/data_punch_card.glb",
	"res://assets/models/hardware/data_cassette.glb",
	"res://assets/models/hardware/data_clay_tablet.glb",
	"res://assets/models/hardware/data_service_module.glb",
]
## Höhe der Oberseite je Träger (Roh-Maß, gemessen am Export) - darauf liegt das Netz.
const CARRIER_TOPS := [0.04, 0.126, 0.128, 0.034]
## Der Körper je Träger: Albedo, Rauheit, Eigenlicht (Anteil Sortenfarbe, Energie).
const CARRIER_BODY := [Color(0.6, 0.56, 0.48), Color(0.16, 0.16, 0.18),
	Color(0.5, 0.38, 0.25), Color(0.06, 0.06, 0.07)]
const CARRIER_ROUGHNESS := [0.85, 0.42, 0.95, 0.6]
## Die Kassette ist eine schwarze Schale mit einem Hauch Sortenfarbe, der Ton heller Lehm.
const CARRIER_TINT_SHARE := [0.0, 0.08, 0.0, 0.0]
const CARRIER_BODY_GLOW := [0.7, 1.0, 0.6, 1.0]
## Das Modell liegt in Blender mit der Länge auf X (Kopf -X), der Breite auf Y; diese
## Drehung legt es in den Rahmen der Karte (Breite x, Länge y, Kopf +y, Fläche +z).
const CARRIER_BASIS := Basis(Vector3(0.0, -1.0, 0.0), Vector3(0.0, 0.0, 1.0),
	Vector3(-1.0, 0.0, 0.0))
static var _carrier_scenes := {}
static var _neutrals := {}

## Die BUCHSE in der Mulde (das Möbel des Magazins), im WELT-Maß der Karte bei
## CASSETTE_SCALE gebaut. Ursprung = Mitte des Mundes, der Körper reicht SOCKET_DEPTH nach +Z.
const SOCKET_SCENE := "res://assets/models/hardware/card_socket.glb"
const SOCKET_DEPTH := 0.15
static var _socket_scene: PackedScene

## Sichtbarer Stapel und sein Achsabstand; darüber zählt allein die Marke. Der seitliche
## Versatz unterscheidet einen Stapel von einer Zelle.
const STACK_CAP := 5
const STACK_PITCH := DEPTH * 1.18
const STACK_STAGGER := WIDTH * 0.055

## Ruhelicht des Kerns, unter Rune.IDLE_CEILING - dieselbe Ruheregel wie bei den Runen.
const REST_ENERGY := 0.88
## Der Ausbruch SOLL blühen: Lesen ist der Moment, für den der Kopfraum frei bleibt.
const FLARE_ENERGY := 3.2
const FLARE_TIME := 0.55
## Gedimmt: der Kern verglimmt, der KÖRPER bleibt.
const DIM_ENERGY := 0.16

## Der SAUM der Hülle (Randlinien, Spulenringe, Teiler): im Regal ruhig, gesteckt hell,
## aber nie weiß - über etwa 1,5 kippen alle Kanäle ins Clipping.
const EDGE_REST_ENERGY := 0.62
const EDGE_LIVE_ENERGY := 1.35
const EDGE_DIM_ENERGY := 0.12
## Anteil, mit dem der Saum einen Kern-Ausbruch mitreißt.
const EDGE_FLARE_SHARE := 0.75
## Der stille Druck (das Raster der Lochkarte).
const PRINT_ENERGY := 0.8

## Die GRÖSSE ist die INTENSITÄT der Sortenfarbe: entsättigt wird zum Grau gleicher
## Helligkeit, nie zu Weiß.
const TIER_SATURATION := [0.55, 0.8, 1.0]
## Der Glüh-Faktor DÄMPFT nur - das Kolossale bekommt die authored Energien ganz.
const TIER_ENERGY := [0.70, 0.85, 1.0]

## Die Ankunft: die Karte steigt auf ihren Platz.
const RISE_TIME := 0.35

## Das Herausziehen unterm Zeiger: Anteil der Höhe und die Zeit dafür.
const HOVER_LIFT := 0.42
const HOVER_TIME := 0.16
## Der Spielraum, den eine gehoverte Karte den Zeiger noch hält (holds_pointer).
const HOVER_HOLD_SLACK := 0.3
## Derselbe Hub als Stellschraube: der Wirt setzt ihn.
var hover_lift := HOVER_LIFT
var hover_time := HOVER_TIME
## In einer Auslage liegt die ×n-Marke AUF der Karte statt über dem Stapel.
var badge_on_face := false
## Aufgehellt, aber deutlich unter dem Lese-Ausbruch: Greifen ist kein Lesen.
const HOVER_ENERGY := 1.75

## Auftauchen und Abtreten wie ein schwebender Würfel.
const MATERIALIZE_FROM := 0.12
const MATERIALIZE_TIME := 0.26
const DEMATERIALIZE_TIME := 0.16

## Anteil der Sortenfarbe im Albedo der Leuchtteile: ihre Farbe kommt aus der Emission.
const CORE_ALBEDO_SHARE := 0.22

## Zeichen-Reihenfolge der alphagemischten Flächen (der Compatibility-Renderer sortiert
## nach render_priority, nicht nach Tiefe). Die Hüllen sind deckend; es bleiben Netz und
## Marke - und die Paket-Hülle (CardPackView) mit ihrer Folie.
const PRIORITY_BODY := -2
const PRIORITY_CORE := -1
const PRIORITY_PANE := 0
const PRIORITY_FRAME := 1
const PRIORITY_NET := 2
const PRIORITY_BADGE_OUTLINE := 3
const PRIORITY_BADGE := 4
## Abstand der Prioritäten je STAPEL-EBENE - sonst zeichnete das Netz einer tiefen Karte
## über die Reihe darüber hinweg.
const LAYER_SPAN := 10

## ×n-Marke über dem Stapel (Gold wie die Regal-Marke).
const BADGE_FONT := 64
const BADGE_HEIGHT := HEIGHT * 0.26
const BADGE_GAP := HEIGHT * 0.16

## Das PRÄGENETZ füllt den Netz-Raum ganz; es liegt NET_PROUD über der Oberseite.
const NET_WIDTH_SHARE := 1.0
const NET_PROUD := 0.004

var sort: String = Engraving.CATEGORY_NUMBER
## Paketgröße (Pack.TIER_*): sie sagt die INTENSITÄT der Sortenfarbe.
var tier: int = Pack.TIER_NORMAL
var tint: Color = PackDrawerView.GOLD
## Das Prägenetz, das die Fläche zeigt (Pack.stamp_net). Leer = leeres Kreuz.
var stamp_net: Array = []

## Alles Gebaute hängt unter _body: der Ursprung liegt auf dem Glas, _body trägt Lage und Hub.
var _body: Node3D
var _cells: Array[Node3D] = []
var _badge: Label3D
var _carrier := CARRIER_PUNCH
var _layer_bias := 0
var _count := 1
var _dimmed := false
## Anzeige-Maßstab des KÖRPERS (PackDrawerView.CASSETTE_SCALE): eine Karte behält ihre
## Größe ihr ganzes Leben lang; der Ursprung bleibt auf dem Glas.
var _body_scale := 1.0
## Liegt sie auf ihrem LESER (Walze, Kammer)? Dann brennt der Saum.
var _socketed := false
var _hovered := false
var _hover_share := 0.0
var _hover_tween: Tween
var _flare_tween: Tween
var _scale_tween: Tween
var _glide_tween: Tween
## Die drei Stücke des Trage-Bogens (arc_to): Start, Ziel, Scheitelhöhe über der Sehne.
var _arc_from := Vector3.ZERO
var _arc_to := Vector3.ZERO
var _arc_hump := 0.0
var _body_scale_tween: Tween

## Geteilte Materialien des ganzen Stapels: Dimmen und Flare treffen jede Kopie zugleich.
var _shell_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _edge_material: StandardMaterial3D
var _print_material: StandardMaterial3D
## Die Netz-Fläche und ihr EIGENER Ofen (nur abgedunkelt bzw. als Rückfall).
var _net_material: StandardMaterial3D
var _net_oven: SubViewport
var _drained: Array[bool] = []

func _init() -> void:
	name = "DataCell"

## Einziger Eingang: baut die Zelle einer Sorte (Pack.SHELF_ORDER) in ihrer Paketgröße mit
## dem Prägenetz ihres Pakets. gilded = die Reparatur-Karte (Gold), blank = der Rohling.
func setup(cell_sort: String, cell_tier: int = 0, net: Array = [],
		gilded := false, blank := false) -> void:
	sort = cell_sort
	_carrier = carrier_of(sort)
	# Reparatur-Karte und ROHLING sind GRÖSSENLOS: volle Stufe, ihr Ton IST ihr Zeichen.
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

## Der Träger einer Sorte: ihr Rang in Pack.SHELF_ORDER; ohne Sorte der Sonderbestand.
static func carrier_of(cell_sort: String) -> int:
	var rank := Pack.SHELF_ORDER.find(cell_sort)
	return rank if rank >= 0 else CARRIER_MODULE

func carrier() -> int:
	return _carrier

# --- Das PRÄGENETZ auf der Fläche -------------------------------------------------

## Der Ton dieser Karte: die Regal-Farbe ihrer Sorte - eine OPERATOR-Karte aber amber.
func net_accent() -> Color:
	return PressNetView.OPERATOR_TINT if has_operator() else tint

## Die SORTE sagt die Farbe, die GRÖSSE ihre Sättigung - die EINE Farbquelle jeder
## getönten Fläche.
func tier_tint() -> Color:
	return tier_shade(net_accent(), tier)

## Dieselbe Leiter für jeden, der die Karte NICHT ist (Mulden, Blenden).
static func tier_shade(base: Color, cell_tier: int) -> Color:
	var grey := base.get_luminance()
	var share: float = TIER_SATURATION[clampi(cell_tier, 0, TIER_SATURATION.size() - 1)]
	return Color(grey, grey, grey, base.a).lerp(base, share)

func tier_energy() -> float:
	return TIER_ENERGY[clampi(tier, 0, TIER_ENERGY.size() - 1)]

func has_operator() -> bool:
	for face in StampNet.FACES:
		if StampNet.kind_of(StampNet.cell_at(stamp_net, face)) == StampNet.KIND_OPERATOR:
			return true
	return false

## Maß der Netz-Fläche: quer in die Breite des Netz-Raums, längs nach dem Seitenverhältnis
## der Backung.
static func net_span(cell_scale: float) -> Vector2:
	var span := StampNetOven.span()
	var width := opening_size().x * NET_WIDTH_SHARE * cell_scale
	return Vector2(width, width * span.y / maxf(span.x, 1.0))

## Das Netz DIESER Karte, an der Höhe des Netz-Raums gedeckelt.
func net_size() -> Vector2:
	var span := net_span(1.0)
	var room := opening_size().y * NET_WIDTH_SHARE
	if span.y > room and span.y > 0.0:
		span *= room / span.y
	return span

## Welche Zelle ihres PRÄGENETZES der Zeiger trifft (-1 = keine). Geschnitten wird im
## WELTRAUM gegen die Ebene der Netz-Platte - so antwortet die Karte in JEDER Lage.
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
	# Das Quad mißt von seiner MITTE und sein y zeigt nach oben, die Backung von oben links.
	return PressNetView.upright_face_at(Vector2(local.x / span.x + 0.5,
		0.5 - local.y / span.y))

## Hält die GEHOVERTE Karte den Zeiger noch? Ihr Netz plus slack je Seite.
func holds_pointer(camera: Camera3D, screen_pos: Vector2, slack := HOVER_HOLD_SLACK) -> bool:
	if camera == null or not is_visible_in_tree() or tucked() or _cells.is_empty():
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

## Die genannten Seiten sind AUFGENOMMEN und dunkeln ab - neu gebacken, nicht animiert.
## Idempotent.
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

## Der EINE Schreiber der Netz-Fläche: die Ruhe-Backung ist geteilt (je Inhalt UND Träger),
## die abgedunkelte gehört dieser Karte.
func _apply_net_texture() -> void:
	if _net_material == null:
		return
	if _drained.is_empty():
		var shared := StampNetOven.texture(stamp_net, tier_tint(), _carrier)
		if shared != null:
			_drop_net_oven()
			_net_material.albedo_texture = shared
			return
	_drop_net_oven()
	_net_oven = StampNetOven.bake(stamp_net, tier_tint(), _drained, _carrier)
	add_child(_net_oven)
	_net_material.albedo_texture = _net_oven.get_texture()

func _drop_net_oven() -> void:
	if _net_oven == null:
		return
	if is_instance_valid(_net_oven):
		remove_child(_net_oven)
		_net_oven.queue_free()
	_net_oven = null

## Wie viele Karten der Stapel zeigt; darüber zählt nur noch die Marke.
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

## Gedimmt verglimmt der Kern; der Körper bleibt stehen.
func set_dimmed(on: bool) -> void:
	_dimmed = on
	_kill_flare()
	_set_glow(rest_energy())

func dimmed() -> bool:
	return _dimmed

## Der Zeiger liegt auf ihr: sie zieht sich ein Stück heraus und leuchtet auf.
## Idempotent; der Hub sitzt im Körper, nicht im Platz.
func set_hovered(on: bool) -> void:
	if _hovered == on:
		return
	_hovered = on
	_kill_flare()
	_set_glow(rest_energy())
	_kill(_hover_tween)
	_hover_tween = create_tween()
	var lift := _hover_tween.tween_method(_set_hover_share, _hover_share,
		1.0 if on else 0.0, hover_time)
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

## Anzeige-Maßstab des Körpers (Zeit 0 = hart); der Ursprung liegt auf dem Glas.
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

func _apply_body_scale(value: float) -> void:
	_body_scale = value
	_apply_pose()
	_place_badge()

## Der EINE harte Schreiber ihres Platzes: sie LIEGT auf dem genannten GLASPUNKT.
func lie_on_glass(at: Vector3) -> void:
	_kill(_glide_tween)
	_apply_pose()
	_place_badge()
	set_socketed(false)
	global_position = at

## Wie hoch sie über ihrer Auflage liegt - daran mißt jede Auslage.
static func lying_over(cell_scale: float) -> float:
	return (DEPTH + TOP_CLEAR) * cell_scale

## Die Karte steigt DURCH die Fläche auf ihren Platz. Der ENDZUSTAND steht zuerst
## (lie_on_glass), gefahren wird nur der Weg dorthin. from_below < 0 = ihr Körpermaß.
func rise_through_glass(at: Vector3, delay := 0.0, time := RISE_TIME,
		from_below := -1.0) -> void:
	lie_on_glass(at)
	_start_rise(from_below if from_below >= 0.0 else rise_depth(), delay, time)

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

## Wie tief eine Karte AUF der Fläche startet, bis nichts mehr von ihr über dem Glas steht.
func rise_depth() -> float:
	return lying_over(_body_scale)

## Ihr GLASPUNKT: ihr Ursprung selbst.
func glass_position() -> Vector3:
	return global_position

func busy() -> bool:
	return gliding()

## Auf ihrem LESER brennt der Saum.
func set_socketed(on: bool) -> void:
	_socketed = on
	_sync_edge(glow_energy())

func socketed() -> bool:
	return _socketed

## Ruhelicht des Saums in ihrem jetzigen Zustand - mit der Intensität ihrer Größe.
func edge_rest_energy() -> float:
	if _dimmed:
		return EDGE_DIM_ENERGY
	return (EDGE_LIVE_ENERGY if _socketed else EDGE_REST_ENERGY) * tier_energy()

func edge_energy() -> float:
	return _edge_material.emission_energy_multiplier if _edge_material != null else 0.0

## Wo die Netz-Platte im Rahmen der Karte liegt (Mitte bei 0, Grundfläche bei -DEPTH/2).
static func net_z(carrier_index: int) -> float:
	return -DEPTH * 0.5 + float(CARRIER_TOPS[clampi(carrier_index, 0, 3)]) + NET_PROUD

## Aus dem Nichts an ihren Platz - delay: nur das Wachsen wartet.
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

## Die Karte wandert auf einen anderen GLASPUNKT. Zeit 0 setzt sie hart.
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

## DER TRAGE-BOGEN: was der SPIELER bewegt, fliegt ÜBER dem Tisch - XZ gerade, Y als
## Parabel mit dem Scheitel `peak` über dem höheren Ende; unter die Sehne kommt sie nie.
func arc_to(glass_target: Vector3, time: float, peak: float) -> void:
	_kill(_glide_tween)
	_arc_from = glass_position()
	_place_badge()
	_arc_to = glass_target
	global_position = _arc_from
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

## Der größte HUB, mit dem der Bogen sein Versprechen hält: bei SCHRÄGER Sehne liegt der
## Scheitel zur hohen Seite hin. Aus y(s) = a + (b-a)s + 4h·s(1-s) gelöst: die größte
## Wurzel von 16h² + 8h(d-2k) + d² = 0 (k = Ziel über a).
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

## Ruhelicht dieser Zelle - Zielwert jedes Flare-Ausklangs.
func rest_energy() -> float:
	if _dimmed:
		return DIM_ENERGY
	# Greifen und Sperren sind ZUSTÄNDE, keine Größen - nur die Ruhe trägt die Stufe.
	return HOVER_ENERGY if _hovered else REST_ENERGY * tier_energy()

## Der leuchtende Teil: der Kern der Hülle.
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

## Höhe der Netz-Mitte über der Kartenmitte: der Fuß-Rand ist breiter als der Kopf-Rand.
static func opening_center_y() -> float:
	return (FOOT_BAR - TOP_BAR) * 0.5

## Der Netz-Raum auf der Fläche.
static func opening_size() -> Vector2:
	return Vector2(WIDTH - SIDE_BAR * 2.0, HEIGHT - TOP_BAR - FOOT_BAR)

func _apply_pose() -> void:
	if _body == null:
		return
	# Liegend hebt der Ursprung auf halbe Dicke: die Karte liegt AUF dem Glas.
	var lift := DEPTH * 0.5 * _body_scale
	# Der Griff hebt den KÖRPER, nicht den Platz; wie weit, sagt hover_lift.
	lift += STAND_HEIGHT * hover_lift * _hover_share * _body_scale
	_body.transform = Transform3D(_lying_basis(), Vector3(0.0, lift, 0.0))

## Die LIEGE-Drehung samt Maßstab: der ROLL legt sie QUER, die Kippung flach.
func _lying_basis() -> Basis:
	return Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * _body_scale) \
		* Basis(Vector3.BACK, PI * 0.5)

## WEGGESTECKT (eine hinausgerollte Magazin-Karte): der Körper verschwindet, der Knoten
## bleibt sichtbar - `visible` gehört dem Sitz-Schreiber, dies dem Magazin.
func set_tucked(on: bool) -> void:
	if _body != null:
		_body.visible = not on

func tucked() -> bool:
	return _body != null and not _body.visible

## Die STAPEL-EBENE (0 = oberste): je tiefer, desto weiter rutschen die Prioritäten nach unten.
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
	var c := clampi(_carrier, 0, 3)
	var base: Color = CARRIER_BODY[c]
	base = base.lerp(Color(shade.r * 0.3, shade.g * 0.3, shade.b * 0.3), CARRIER_TINT_SHARE[c])
	_shell_material = StandardMaterial3D.new()
	_shell_material.albedo_color = base
	_shell_material.roughness = CARRIER_ROUGHNESS[c]
	_shell_material.metallic_specular = 0.6
	# Eigenlicht: der Tisch ist dunkel, ein unbeleuchteter Körper läse sonst als Loch.
	_shell_material.emission_enabled = true
	_shell_material.emission = base
	_shell_material.emission_energy_multiplier = CARRIER_BODY_GLOW[c]
	_shell_material.render_priority = _prio(PRIORITY_BODY)

	_core_material = _lit_material(shade)
	_core_material.render_priority = _prio(PRIORITY_CORE)

	_edge_material = _lit_material(shade)
	_edge_material.emission_energy_multiplier = EDGE_REST_ENERGY * gain
	_edge_material.render_priority = _prio(PRIORITY_FRAME)

	_print_material = _lit_material(shade)
	_print_material.emission_energy_multiplier = PRINT_ENERGY * gain

	_net_material = StandardMaterial3D.new()
	_net_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_net_material.render_priority = _prio(PRIORITY_NET)
	_net_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_apply_net_texture()

func _lit_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _scaled(color, CORE_ALBEDO_SHARE)
	material.metallic = 0.0
	material.roughness = 0.62
	material.emission_enabled = true
	material.emission = _scaled(color, 1.0)
	material.emission_energy_multiplier = REST_ENERGY * tier_energy()
	return material

## Farbe mal Faktor OHNE ihr Alpha anzufassen.
static func _scaled(color: Color, factor: float) -> Color:
	return Color(color.r * factor, color.g * factor, color.b * factor, 1.0)

## Eine Karte des Stapels: ihre HÜLLE und das Netz darauf. Alle Kopien teilen Meshes und Materialien.
func _build_cell() -> Node3D:
	var cell := Node3D.new()
	cell.name = "Cell%d" % _cells.size()
	var hull := carrier_model(_carrier)
	if hull != null:
		hull.name = "Huelle"
		hull.transform = Transform3D(CARRIER_BASIS, Vector3(0.0, 0.0, -DEPTH * 0.5))
		cell.add_child(hull)
		_dress_hull(hull)
	else:
		# Ohne Import ein schlichter Block im Umriß und in der Dicke des Trägers.
		var thick: float = CARRIER_TOPS[clampi(_carrier, 0, 3)]
		TableProps.box(cell, "Huelle", Vector3(WIDTH, HEIGHT, thick),
			Vector3(0.0, 0.0, -DEPTH * 0.5 + thick * 0.5), _shell_material)
	var net_plate := MeshInstance3D.new()
	net_plate.name = "StampNet"
	var quad := QuadMesh.new()
	quad.size = net_size()
	net_plate.mesh = quad
	net_plate.material_override = _net_material
	net_plate.position = Vector3(0.0, opening_center_y(), net_z(_carrier))
	net_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(net_plate)
	return cell

## Das Modell eines Trägers - EINMAL je Träger geladen und geteilt (null = kein Import).
static func carrier_model(carrier_index: int) -> Node3D:
	var index := clampi(carrier_index, 0, CARRIER_SCENES.size() - 1)
	if not _carrier_scenes.has(index):
		var path: String = CARRIER_SCENES[index]
		_carrier_scenes[index] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	var scene: PackedScene = _carrier_scenes[index]
	return scene.instantiate() as Node3D if scene != null else null

## Die Materialien der Hülle nach ROLLE (dem Objektnamen im Export): getönt, was zur Karte
## gehört, geteilt, was neutral ist.
func _dress_hull(hull: Node3D) -> void:
	for node in hull.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var role := String(mesh.name).rstrip("0123456789")
		match role:
			"Koerper":
				mesh.material_override = _shell_material
			"Kern":
				mesh.material_override = _core_material
			"Saum":
				mesh.material_override = _edge_material
			"Druck":
				mesh.material_override = _print_material
			_:
				mesh.material_override = neutral_material(role)

## Die neutralen Teile (Metall, Dunkel, Glanz, Ton, Hell, Band, Kerbe, Bahn, Pad, Keramik, Schrift) - einmal gebaut, von allen geteilt.
## Metall mit wenig Metallic und etwas Eigenlicht: ohne Umgebung läse Chrom schwarz.
static func neutral_material(role: String) -> StandardMaterial3D:
	if _neutrals.has(role):
		return _neutrals[role]
	var spec: Array = {
		"Metall": [Color(0.62, 0.64, 0.7), 0.35, 0.3, 0.5],
		"Dunkel": [Color(0.012, 0.012, 0.016), 0.0, 0.6, 0.0],
		"Glanz": [Color(0.03, 0.05, 0.07), 0.2, 0.06, 0.12],
		"Ton": [Color(0.33, 0.25, 0.18), 0.0, 0.9, 0.45],
		"Hell": [Color(0.8, 0.76, 0.7), 0.0, 0.8, 0.55],
		"Band": [Color(0.3, 0.15, 0.09), 0.2, 0.4, 0.8],
		"Kerbe": [Color(0.1, 0.07, 0.045), 0.0, 0.95, 0.0],
		"Bahn": [Color(0.3, 0.21, 0.08), 0.3, 0.5, 0.9],
		"Pad": [Color(0.5, 0.36, 0.13), 0.4, 0.4, 0.9],
		"Keramik": [Color(0.2, 0.16, 0.24), 0.0, 0.5, 0.8],
		"Schrift": [Color(0.3, 0.3, 0.33), 0.0, 0.7, 0.8],
	}.get(role, [Color(0.2, 0.2, 0.24), 0.0, 0.6, 0.2])
	var material := StandardMaterial3D.new()
	material.albedo_color = spec[0]
	material.metallic = spec[1]
	material.roughness = spec[2]
	if float(spec[3]) > 0.0:
		material.emission_enabled = true
		material.emission = spec[0]
		material.emission_energy_multiplier = spec[3]
	_neutrals[role] = material
	return material

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

## Die Marke sitzt über der OBERSTEN Karte und in DEREN Ebene.
func _place_badge() -> void:
	if _badge == null:
		return
	_badge.text = "×%d" % _count if _count > 1 else ""
	_badge.visible = _count > 1
	var top := maxf(float(_cells.size()) - 1.0, 0.0)
	if badge_on_face:
		# In der Auslage liegt sie flach auf der Fußhälfte der Karte.
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

## Der Saum steht auf seinem eigenen Zustand und reißt bei einem Kern-Ausbruch nur mit.
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
