class_name LiftShaftView
extends Node3D
## Der SCHACHT einer Hebebühne: die Maschine, mit der eine Auslage auffährt. Ein
## Loch im Tisch (das schneidet der Shader - TableScreen führt die Liste), darunter
## vier Wände, ein Kragen über der Schnittkante und ein Lichtsaum darunter; der
## BODEN ist die bewegliche PLATTFORM. Rein per Code gebaut wie PackPitView -
## kein .tscn.
## Die RÜCKWAND ist nur ein Sturz: unter ihr steht das Öffnungsband offen, durch
## das die Ware von hinten hereinschiebt. "Hinten" ist Welt-+X (Bildschirm-oben),
## also genau die Innenfläche, auf die die 15°-Kamera blickt. Dahinter liegt der
## HOHLRAUM, in dem die Ware wartet - eine dunkle Rückwand und eine durchgehende
## Sohle schließen ihn, sonst sähe man durch den offenen Schacht auf den Raumboden.
## Die Plattform ist im BÜNDIGEN Stand einen Frame lang die Anzeige selbst: ihre
## Deckfläche trägt deshalb den Ton des Fensters, in dem der Schacht steht
## (deck_color), unbeleuchtet, damit kein Szenenlicht sie verrät.
## Drei Tischregeln wie in der Grube: nur EMISSION (die Bodenkacheln vertragen
## 16 Lichter), das Ruhelicht bleibt gedämpft, und gespiegelt wird nichts - ein
## Loch hat kein Spiegelbild.

## Wandstärke und Dicke der Plattformplatte.
const WALL := 0.10
const DECK := 0.09

## Die Zeiten der Maschine: Senken, Einschub und Hub sind LINEAR - eine Maschine
## beschleunigt nicht weich -, und am Ende rastet die Bühne mit einem kurzen
## Setz-Dip ein. Der Zonen-Versatz gehört dem Wirt, diese Zahlen der Maschine.
const SINK_TIME := 0.4
const PUSH_TIME := 0.35
const LIFT_TIME := 0.45
## Der Dip ist ein festes Körpermaß, kein Anteil der Fahrt: eine kurze Bahn setzte
## sonst unsichtbar ein, und der Tisch blickt fast senkrecht darauf.
const DIP := DataCellView.HEIGHT * 0.075
const DIP_TIME := 0.08

## Der Kragen über der Schnittkante - dieselbe Rechnung wie in der Grube, nur
## schmaler: ein Schacht ist ein Auftritt, kein Möbel.
const RIM_IN := 0.12
const RIM_OUT := 0.26
const RIM_H := 0.04
const RIM_SINK := 0.025
const WALL_SINK := RIM_SINK

## Der Lichtsaum knapp unter dem Kragen: ohne ihn verschluckt der dunkle Raum die
## Wände und der Schacht läse sich als schwarzes Rechteck statt als Vertiefung.
const GLOW_H := 0.05
const GLOW_DROP := 0.08
const GLOW_COLOR := Color(0.42, 0.86, 0.99)
const GLOW_ENERGY := 1.5

const WALL_ALBEDO := Color(0.070, 0.066, 0.098)
const WALL_EMISSION := Color(0.20, 0.23, 0.34)
const WALL_EMISSION_ENERGY := 0.95
## Der Hohlraum hinter dem Öffnungsband ist die dunkelste Fläche der Maschine -
## dort wartet die Ware, und dort soll das Auge nichts finden.
const CAVITY_ALBEDO := Color(0.028, 0.026, 0.042)
const CAVITY_EMISSION := Color(0.10, 0.12, 0.20)
const CAVITY_EMISSION_ENERGY := 0.45

const RIM_ALBEDO := Color(0.20, 0.195, 0.245)
const RIM_EMISSION := Color(0.42, 0.44, 0.58)
const RIM_EMISSION_ENERGY := 0.95

## Die Deckfläche der Plattform: bündig steht sie an der Stelle der Anzeige, und
## der Wechsel Platte -> Display beim Schließen darf nicht springen. Der Ton gehört
## deshalb dem FENSTER, in dem der Schacht steht - jedes meldet seinen eigenen
## (ShopController.BAY_GROUND, SecretShopView.BAY_GROUND), GEMESSEN am echten
## Tisch und nicht aus FRAME_BG gerechnet: über dem Fenstergrund liegen noch die
## Gründe der Seite selbst. Der Vorgabewert ist der der Ladenseite.
const DECK_TOP := Color(0.149, 0.141, 0.277)
## Vor dem ersten setup zu setzen bzw. jederzeit - setup schreibt ihn nach.
var deck_color := DECK_TOP
## Ihre Flanken sind Maschine, nicht Anzeige.
const DECK_SIDE := Color(0.16, 0.17, 0.24)
const DECK_EMISSION := Color(0.30, 0.34, 0.48)
const DECK_EMISSION_ENERGY := 0.55

## Die Höhe des Öffnungsbandes in der Rückwand als Anteil der Schachttiefe: hoch
## genug für das höchste Stück (die Tiefe ist dessen Maß mal VitrineView.SHAFT_ROOM,
## also muß dieser Anteil über 1/SHAFT_ROOM liegen - ein Test hält das fest),
## niedrig genug, dass ein Sturz stehen bleibt.
const MOUTH_SHARE := 0.72
## Wie weit der Hohlraum hinter die Rückwand reicht - dort wartet die Ware. Sie
## wartet an seinem ENDE, denn durch das Öffnungsband blickt man ein Stück weit
## hinein: näher gestellt sähe man die Ware im Schacht liegen, bevor sie einfährt.
const CAVITY_SHARE := 1.05
## Luft unter der gesenkten Plattform, damit ihre Unterseite nicht auf der Sohle
## aufsetzt und die beiden im Tiefenpuffer kämpfen.
const SOLE_CLEAR := 0.04

## Ein Schacht steht offen bzw. ist zu. GEMELDET nach draußen, weil das LOCH in der
## Anzeige den Shadern gehört und ein Körper nicht in sie greift.
signal opened(at: Vector3, half_extents: Vector2)
signal closed

## Wie lange EIN Zyklus dauert - der ehrliche Deckel jedes Auftritts.
static func cycle_time() -> float:
	return SINK_TIME + PUSH_TIME + LIFT_TIME + DIP_TIME

var _wall_material: StandardMaterial3D
var _cavity_material: StandardMaterial3D
var _rim_material: StandardMaterial3D
var _glow_material: StandardMaterial3D
var _deck_material: StandardMaterial3D
var _deck_side_material: StandardMaterial3D

## Zuletzt gestellte Maße - der Abgleich stellt idempotent nach.
var center := Vector3.ZERO
var half := Vector2.ZERO
var depth := 0.0

var _platform: Node3D
## Der EINE Tween des Zyklus - Platte und Ware fahren darin gemeinsam.
var _tween: Tween

func _init(shaft_name := "LiftShaft") -> void:
	name = shaft_name
	visible = false  # die Maschine existiert nur während eines Auftritts

## Einziger Eingang: Mitte auf dem Glas, halbe Ausdehnung in Welt-X/Welt-Z und die
## Fahrstrecke der Plattform. Idempotent - dieselben Maße bauen nicht neu.
func setup(at: Vector3, half_extents: Vector2, shaft_depth: float) -> void:
	var wanted := Vector2(maxf(half_extents.x, 0.01), maxf(half_extents.y, 0.01))
	var travel := maxf(shaft_depth, 0.05)
	if _deck_material != null:
		_deck_material.albedo_color = deck_color
	if center.is_equal_approx(at) and half.is_equal_approx(wanted) \
			and is_equal_approx(depth, travel) and _platform != null:
		return
	center = at
	half = wanted
	depth = travel
	global_position = center
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if _wall_material == null:
		_build_materials()
	_build_body()

## Wie weit ein wartendes Stück HINTER der Rückwand steht: am Ende des Hohlraums,
## außerhalb des Blickwinkels durch das Öffnungsband.
func waiting_offset() -> float:
	return half.x + depth * CAVITY_SHARE

## Wie tief die Plattform fährt - dasselbe Maß, um das die Ware unter ihrem Platz
## startet.
func drop() -> float:
	return depth

# --- Die Fahrt ------------------------------------------------------------------

## Der ganze Auftritt als EIN Tween: Loch auf und bündige LEERE Platte senken, Ware
## von hinten durch die Rückwandöffnung einschieben, Platte und Ware GEMEINSAM
## heben, Loch zu. bodies und seats sind index-parallel, und seats sind die
## FERTIGEN Plätze - der Endzustand steht längst, gefahren wird nur der Weg.
## Zwei getrennte Tweens (Platte hier, Ware dort) liefen auseinander, und die Ware
## steht auf der Platte.
func run_cycle(bodies: Array, seats: Array, delay: float) -> Tween:
	settle_hard()
	if bodies.is_empty() or bodies.size() != seats.size() or _platform == null:
		return null
	var behind := waiting_offset()
	# Wartestellung: hinter der Rückwand auf Schachttiefe - dort deckt das opake
	# Display jedes Stück, bis es hereinschiebt.
	for i in bodies.size():
		var body: Node3D = bodies[i]
		if body != null and is_instance_valid(body):
			body.global_position = (seats[i] as Vector3) + Vector3(behind, -depth, 0.0)
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_tween.tween_callback(_open)
	_tween.tween_property(_platform, "position:y", -depth, SINK_TIME) \
		.set_trans(Tween.TRANS_LINEAR)
	for i in bodies.size():
		var step := _tween if i == 0 else _tween.parallel()
		step.tween_property(bodies[i], "global_position",
			(seats[i] as Vector3) - Vector3.UP * depth, PUSH_TIME) \
			.set_trans(Tween.TRANS_LINEAR)
	_together(bodies, seats, 0.0, LIFT_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	var dip := minf(DIP, depth * 0.5)
	_together(bodies, seats, -dip, DIP_TIME * 0.5, Tween.TRANS_SINE, Tween.EASE_OUT)
	_together(bodies, seats, 0.0, DIP_TIME * 0.5, Tween.TRANS_SINE, Tween.EASE_IN)
	_tween.tween_callback(_shut)
	return _tween

## Ein Schlag der gemeinsamen Fahrt: die Platte auf offset, jedes Stück um genau
## dasselbe Maß über seinem Platz. Identische Tweens statt einer Elternschaft, die
## niemandem gehört.
func _together(bodies: Array, seats: Array, offset: float, time: float,
		trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	_tween.tween_property(_platform, "position:y", offset, time) \
		.set_trans(trans).set_ease(ease_type)
	for i in bodies.size():
		_tween.parallel().tween_property(bodies[i], "global_position",
			(seats[i] as Vector3) + Vector3.UP * offset, time) \
			.set_trans(trans).set_ease(ease_type)

## Der EINE harte Endzustand, den JEDER Abbruch schreibt: Fahrt aus, Platte bündig,
## Maschine fort, Loch zu. Ein offenes Loch ist der schlimmste denkbare Rest.
func settle_hard() -> void:
	_kill()
	_shut()

func platform_y() -> float:
	return _platform.position.y if _platform != null else 0.0

## Bündig ist die Platte von der Anzeige nicht zu unterscheiden - das Öffnen ist
## deshalb nahtlos.
func _open() -> void:
	visible = true
	_set_platform(0.0)
	opened.emit(center, half)

func _shut() -> void:
	_set_platform(0.0)
	visible = false
	closed.emit()

func _set_platform(y: float) -> void:
	if _platform != null:
		_platform.position.y = y

func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

# --- Der Körper -----------------------------------------------------------------

func _build_materials() -> void:
	_wall_material = _metal(WALL_ALBEDO, WALL_EMISSION, WALL_EMISSION_ENERGY)
	_cavity_material = _metal(CAVITY_ALBEDO, CAVITY_EMISSION, CAVITY_EMISSION_ENERGY)
	_rim_material = _metal(RIM_ALBEDO, RIM_EMISSION, RIM_EMISSION_ENERGY)
	_glow_material = _metal(GLOW_COLOR * 0.3, GLOW_COLOR, GLOW_ENERGY)
	_deck_side_material = _metal(DECK_SIDE, DECK_EMISSION, DECK_EMISSION_ENERGY)
	# Die Deckfläche steht an der Stelle der Anzeige: unbeleuchtet, damit kein
	# Szenenlicht den Unterschied malt.
	_deck_material = StandardMaterial3D.new()
	_deck_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_deck_material.albedo_color = deck_color

func _metal(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(albedo.r, albedo.g, albedo.b, 1.0)
	material.metallic = 0.45
	material.roughness = 0.5
	material.emission_enabled = true
	material.emission = Color(emission.r, emission.g, emission.b, 1.0)
	material.emission_energy_multiplier = energy
	return material

## Alles in LOKALEN Koordinaten um die Schachtmitte auf dem Glas (y = 0 ist die
## Tischfläche, +X ist hinten).
func _build_body() -> void:
	var span := Vector2(half.x * 2.0, half.y * 2.0)
	var top := -WALL_SINK
	var mouth := depth * MOUTH_SHARE
	var cavity := depth * CAVITY_SHARE
	var sole_y := top - depth - SOLE_CLEAR - DECK

	# Drei geschlossene Wände; die vierte (hinten, +X) ist nur ein Sturz über dem
	# Öffnungsband, durch das die Ware hereinschiebt.
	_box("WallFront", Vector3(WALL, depth, span.y + WALL * 2.0),
		Vector3(-half.x - WALL * 0.5, top - depth * 0.5, 0.0), _wall_material)
	_box("WallLeft", Vector3(span.x, depth, WALL),
		Vector3(0.0, top - depth * 0.5, -half.y - WALL * 0.5), _wall_material)
	_box("WallRight", Vector3(span.x, depth, WALL),
		Vector3(0.0, top - depth * 0.5, half.y + WALL * 0.5), _wall_material)
	var lintel := maxf(depth - mouth, 0.01)
	_box("BackLintel", Vector3(WALL, lintel, span.y + WALL * 2.0),
		Vector3(half.x + WALL * 0.5, top - lintel * 0.5, 0.0), _wall_material)

	# Der Hohlraum hinter dem Band: Rückwand, zwei Flanken und eine Decke, damit
	# der Blick durch das Öffnungsband nirgends ins Freie fällt.
	var cavity_mid := half.x + WALL + cavity * 0.5
	_box("CavityBack", Vector3(WALL, depth, span.y + WALL * 2.0),
		Vector3(half.x + WALL * 1.5 + cavity, top - depth * 0.5, 0.0), _cavity_material)
	_box("CavityLeft", Vector3(cavity, depth, WALL),
		Vector3(cavity_mid, top - depth * 0.5, -half.y - WALL * 0.5), _cavity_material)
	_box("CavityRight", Vector3(cavity, depth, WALL),
		Vector3(cavity_mid, top - depth * 0.5, half.y + WALL * 0.5), _cavity_material)
	_box("CavityLid", Vector3(cavity, WALL, span.y + WALL * 2.0),
		Vector3(cavity_mid, top - (depth - mouth) - WALL * 0.5, 0.0), _cavity_material)

	# Die SOHLE unter Schacht und Hohlraum: der Blick in den offenen Schacht darf
	# nie auf den Raumboden fallen (der Filz ist dort weggeblendet).
	_box("Sole", Vector3(span.x + WALL * 2.0 + cavity, DECK,
		span.y + WALL * 2.0),
		Vector3(cavity * 0.5, sole_y + DECK * 0.5, 0.0), _cavity_material)

	# Der Kragen greift RIM_IN über die Kante und deckt die harte Schnittlinie.
	var rim_y := -RIM_H * 0.5 - RIM_SINK
	var rim_bar := RIM_IN + RIM_OUT
	var rim_x := half.x - RIM_IN * 0.5 + RIM_OUT * 0.5
	var rim_z := half.y - RIM_IN * 0.5 + RIM_OUT * 0.5
	_box("RimBack", Vector3(rim_bar, RIM_H, span.y + rim_bar * 2.0),
		Vector3(rim_x, rim_y, 0.0), _rim_material)
	_box("RimFront", Vector3(rim_bar, RIM_H, span.y + rim_bar * 2.0),
		Vector3(-rim_x, rim_y, 0.0), _rim_material)
	_box("RimLeft", Vector3(span.x, RIM_H, rim_bar),
		Vector3(0.0, rim_y, -rim_z), _rim_material)
	_box("RimRight", Vector3(span.x, RIM_H, rim_bar),
		Vector3(0.0, rim_y, rim_z), _rim_material)

	var glow_y := -GLOW_DROP - GLOW_H * 0.5
	var glow_in := RIM_IN * 0.5
	_box("GlowFront", Vector3(glow_in, GLOW_H, span.y),
		Vector3(-half.x + glow_in * 0.5, glow_y, 0.0), _glow_material)
	_box("GlowLeft", Vector3(span.x, GLOW_H, glow_in),
		Vector3(0.0, glow_y, -half.y + glow_in * 0.5), _glow_material)
	_box("GlowRight", Vector3(span.x, GLOW_H, glow_in),
		Vector3(0.0, glow_y, half.y - glow_in * 0.5), _glow_material)

	_build_platform(span)

## Die Plattform: eine Platte über die volle Schachtbreite. Ihr Ursprung liegt in
## der Glasebene, ihre DECKFLÄCHE also bündig - so ist "0" der bündige Stand und
## "-depth" der gesenkte, ohne dass ein Aufrufer die Plattendicke kennen müsste.
func _build_platform(span: Vector2) -> void:
	_platform = Node3D.new()
	_platform.name = "Platform"
	add_child(_platform)
	# Die DECKHAUT ist die Oberfläche - sie allein reicht bis zur Nullebene, die
	# Platte hängt vollständig darunter. Zwei koplanare Deckflächen kämpften im
	# Tiefenpuffer und zerschnitten die Fläche in Streifen.
	var skin_h := DECK * 0.12
	var skin := BoxMesh.new()
	skin.size = Vector3(span.x, skin_h, span.y)
	var top := MeshInstance3D.new()
	top.name = "DeckTop"
	top.mesh = skin
	top.material_override = _deck_material
	top.position = Vector3(0.0, -skin_h * 0.5, 0.0)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_platform.add_child(top)
	var deck := BoxMesh.new()
	deck.size = Vector3(span.x, DECK, span.y)
	var plate := MeshInstance3D.new()
	plate.name = "Deck"
	plate.mesh = deck
	plate.material_override = _deck_side_material
	plate.position = Vector3(0.0, -skin_h - DECK * 0.5, 0.0)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_platform.add_child(plate)

func _box(box_name: String, box_size: Vector3, at: Vector3,
		material: Material) -> void:
	if box_size.x <= 0.001 or box_size.y <= 0.001 or box_size.z <= 0.001:
		return
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
