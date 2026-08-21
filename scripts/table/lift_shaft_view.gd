class_name LiftShaftView
extends Node3D
## Der SCHACHT einer Hebebühne: die Maschine, mit der eine Auslage auffährt. Ein
## Loch im Tisch (das schneidet der Shader - TableScreen führt die Liste), darunter
## vier Wände und ein Lichtsaum knapp unter der Kante; der BODEN ist die bewegliche
## PLATTFORM. Rein per Code gebaut wie PackPitView - kein .tscn.
## Die Schnittkante steht NACKT: es gibt keinen Kragen und keine Fuge auf der
## Fläche. Was den Schacht lesbar macht, liegt IN ihm (der Lichtsaum), nicht auf
## der Anzeige darüber.
## Der Schacht ist SYMMETRISCH: Rück- und Vorderwand sind beide nur ein Sturz, unter
## dem ein Öffnungsband offen steht. Hinten (Welt-+X, Bildschirm-oben) ist der
## EINGANG - dort schiebt die Ware herein; vorn (Welt-−X, zum Betrachter) ist der
## AUSGANG - dort schiebt sie hinaus. Hinter jedem Band liegt ein HOHLRAUM, in dem
## die Ware wartet bzw. verschwindet; jeder ist mit Wand, Flanken und Decke
## geschlossen, und eine durchgehende Sohle spannt über beide, sonst sähe man durch
## den offenen Schacht auf den Raumboden.
## Die Plattform IST im bündigen Stand die Anzeige: ihre Deckhaut zeigt per Shader
## das ECHTE Bild des Displays an ihrer Stelle (TableScreen.display_skin), also ist
## der bündige Stand pixelidentisch - und beim Senken trägt die Platte ihr Stück
## Anzeige sichtbar mit hinunter (der Mahjong-Deckel).
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

## Wie weit die Wände unter die Schnittkante rücken - so sieht man ihre Oberkante
## nie über der Fläche stehen.
const WALL_SINK := 0.025

## Der Lichtsaum knapp unter der nackten Kante: ohne ihn verschluckt der dunkle
## Raum die Wände und der Schacht läse sich als schwarzes Rechteck statt als
## Vertiefung. Er liegt IM Schacht, er umrandet die Fläche nicht.
const GLOW_H := 0.05
const GLOW_DROP := 0.08
## Wie weit er von der Wand nach innen greift.
const GLOW_IN := 0.06
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

## Die HAUT der Deckfläche: das echte Bild der Anzeige an ihrer Stelle. GEMELDET
## von draußen (TableScreen.display_skin) - ein Schacht greift nicht in die Szene.
## Ohne Haut (Probe, Test ohne Tisch) ist die Platte schlicht Maschine.
var deck_skin: Material = null:
	set(value):
		deck_skin = value
		_apply_deck_skin()
## Ihre Flanken sind Maschine, nicht Anzeige.
const DECK_SIDE := Color(0.16, 0.17, 0.24)
const DECK_EMISSION := Color(0.30, 0.34, 0.48)
const DECK_EMISSION_ENERGY := 0.55

## Die Höhe der Öffnungsbänder als Anteil der Schachttiefe: hoch genug für das
## höchste Stück (die Tiefe ist dessen Maß mal VitrineView.SHAFT_ROOM, also muß
## dieser Anteil über 1/SHAFT_ROOM liegen - ein Test hält das fest), niedrig genug,
## dass beidseits ein Sturz stehen bleibt.
const MOUTH_SHARE := 0.72
## Wie weit ein Hohlraum hinter sein Band reicht - dort wartet die Ware bzw. dorthin
## verschwindet sie. Sie wartet an seinem ENDE, denn durch das Öffnungsband blickt
## man ein Stück weit hinein: näher gestellt sähe man die Ware im Schacht liegen,
## bevor sie einfährt.
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

## Der TAUSCH ist derselbe Zyklus: der Einschub trägt nur zwei Fuhren statt einer -
## die alte hinaus, die neue herein, EIN Band-Schritt.
static func swap_cycle_time() -> float:
	return SINK_TIME + PUSH_TIME + LIFT_TIME + DIP_TIME

## Und der ABGANG ebenso - nur fährt die Platte am Ende LEER herauf.
static func exit_cycle_time() -> float:
	return SINK_TIME + PUSH_TIME + LIFT_TIME + DIP_TIME

## Der KAUF ist derselbe Zyklus in klein: nur die SEKTION unter dem gekauften Stück
## fährt. Dieselben vier Schläge, also dieselbe Dauer.
static func take_cycle_time() -> float:
	return SINK_TIME + PUSH_TIME + LIFT_TIME + DIP_TIME

## Wann das gekaufte Stück AUSSER SICHT ist: nach Senken und Band-Schritt. Dort
## startet seine Lieferung - auf die leer hochfahrende Sektion wartet kein Komet.
static func take_out_time() -> float:
	return SINK_TIME + PUSH_TIME

var _wall_material: StandardMaterial3D
var _cavity_material: StandardMaterial3D
var _glow_material: StandardMaterial3D
var _deck_side_material: StandardMaterial3D
## Die Deckhaut selbst - der eine Ort, an dem die gemeldete Haut landet.
var _deck_top: MeshInstance3D

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

## Und wie weit ein abgehendes Stück VOR die Vorderwand fährt - der Spiegel davon.
## Ein Band, das einen Schritt weiterfährt: derselbe Weg für beide Fuhren.
func exit_offset() -> float:
	return waiting_offset()

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
	_lift_and_seat(bodies, seats)
	_tween.tween_callback(_shut)
	return _tween

## Der WARENUMSCHLAG als EIN Förderband-Schritt: Loch auf, Platte und ALTE Ware
## GEMEINSAM senken, dann fährt das Band einen Schritt weiter - die alten Stücke
## gleiten vorn hinaus, WÄHREND die neuen von hinten auf ihre Plätze nachrücken,
## gleiche Richtung, gleiche Dauer -, dann heben Platte und NEUE Ware, Loch zu.
## Beide Fuhren legen genau exit_offset() zurück: ihr Abstand bleibt über die ganze
## Fahrt derselbe, sie können sich nicht einholen.
## on_swept meldet am Ende des Band-Schritts, dass die alte Ware draußen ist - dort
## gibt der Wirt ihre Körper frei.
func run_swap(old_bodies: Array, old_seats: Array, new_bodies: Array,
		new_seats: Array, delay: float, on_swept := Callable()) -> Tween:
	settle_hard()
	if _platform == null or old_bodies.size() != old_seats.size() \
			or new_bodies.size() != new_seats.size():
		return null
	if old_bodies.is_empty() and new_bodies.is_empty():
		return null
	var behind := waiting_offset()
	var ahead := exit_offset()
	# Wartestellung der NEUEN: hinter der Rückwand auf Schachttiefe - dort deckt das
	# opake Display jedes Stück, bis es hereinschiebt. Die alten stehen schon.
	for i in new_bodies.size():
		var body: Node3D = new_bodies[i]
		if body != null and is_instance_valid(body):
			body.global_position = (new_seats[i] as Vector3) + Vector3(behind, -depth, 0.0)
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_tween.tween_callback(_open)
	# Senken MIT der alten Ware: sie steht auf der Platte, sie fährt mit ihr.
	if old_bodies.is_empty():
		_tween.tween_property(_platform, "position:y", -depth, SINK_TIME) \
			.set_trans(Tween.TRANS_LINEAR)
	else:
		_together(old_bodies, old_seats, -depth, SINK_TIME,
			Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_belt_step(old_bodies, old_seats, ahead, new_bodies, new_seats)
	if on_swept.is_valid():
		_tween.tween_callback(on_swept)
	_lift_and_seat(new_bodies, new_seats)
	_tween.tween_callback(_shut)
	return _tween

## Der ABGANG: senken MIT der Ware, sie vorn hinausschieben, die Platte LEER wieder
## bündig heben und das Loch schließen. Danach ist die Auslage leer - die Platte IST
## die Fläche, also darf sie nicht unten stehen bleiben.
func run_exit(bodies: Array, seats: Array, delay: float,
		on_swept := Callable()) -> Tween:
	settle_hard()
	if bodies.is_empty() or bodies.size() != seats.size() or _platform == null:
		return null
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_tween.tween_callback(_open)
	_together(bodies, seats, -depth, SINK_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_belt_step(bodies, seats, exit_offset(), [], [])
	if on_swept.is_valid():
		_tween.tween_callback(on_swept)
	_lift_and_seat([], [])
	_tween.tween_callback(_shut)
	return _tween

## Der KAUF: derselbe Zyklus, nur fährt die SEKTION unter dem gekauften Stück. Sie
## senkt sich MIT ihm, dann fährt es durch die HINTERE Öffnung ab - die
## Gegenrichtung zum Abgang, denn Gekauftes reist zur Werkbank, es geht nicht
## zurück ins Lager -, danach hebt sich die leere Sektion bündig und das Loch ist
## zu. on_gone meldet das Ende des Band-Schritts: dort ist das Stück außer Sicht.
func run_take(bodies: Array, seats: Array, delay: float,
		on_gone := Callable()) -> Tween:
	settle_hard()
	if bodies.is_empty() or bodies.size() != seats.size() or _platform == null:
		return null
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_tween.tween_callback(_open)
	_together(bodies, seats, -depth, SINK_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	var behind := waiting_offset()
	for i in bodies.size():
		var step := _tween if i == 0 else _tween.parallel()
		step.tween_property(bodies[i], "global_position",
			(seats[i] as Vector3) + Vector3(behind, -depth, 0.0), PUSH_TIME) \
			.set_trans(Tween.TRANS_LINEAR)
	if on_gone.is_valid():
		_tween.tween_callback(on_gone)
	_lift_and_seat([], [])
	_tween.tween_callback(_shut)
	return _tween

## Der BAND-SCHRITT: auf Schachttiefe fahren alle Stücke um dasselbe Maß nach vorn -
## die abgehenden aus dem Schacht in den vorderen Hohlraum, die ankommenden aus dem
## hinteren auf ihre Plätze. EIN Takt, eine Bewegung.
func _belt_step(out_bodies: Array, out_seats: Array, ahead: float,
		in_bodies: Array, in_seats: Array) -> void:
	var first := true
	for i in out_bodies.size():
		var step := _tween if first else _tween.parallel()
		first = false
		step.tween_property(out_bodies[i], "global_position",
			(out_seats[i] as Vector3) + Vector3(-ahead, -depth, 0.0), PUSH_TIME) \
			.set_trans(Tween.TRANS_LINEAR)
	for i in in_bodies.size():
		var step := _tween if first else _tween.parallel()
		first = false
		step.tween_property(in_bodies[i], "global_position",
			(in_seats[i] as Vector3) - Vector3.UP * depth, PUSH_TIME) \
			.set_trans(Tween.TRANS_LINEAR)
	if first:
		_tween.tween_interval(PUSH_TIME)  # ein leeres Band fährt trotzdem seinen Takt

## Der Hub samt Setz-Dip - der Schluss jedes Fahrplans. Ohne Ware fährt die Platte
## allein herauf.
func _lift_and_seat(bodies: Array, seats: Array) -> void:
	_together(bodies, seats, 0.0, LIFT_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	var dip := minf(DIP, depth * 0.5)
	_together(bodies, seats, -dip, DIP_TIME * 0.5, Tween.TRANS_SINE, Tween.EASE_OUT)
	_together(bodies, seats, 0.0, DIP_TIME * 0.5, Tween.TRANS_SINE, Tween.EASE_IN)

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
	_glow_material = _metal(GLOW_COLOR * 0.3, GLOW_COLOR, GLOW_ENERGY)
	_deck_side_material = _metal(DECK_SIDE, DECK_EMISSION, DECK_EMISSION_ENERGY)

## Die gemeldete Haut auf die Deckfläche legen. Idempotent, und ohne Haut bleibt
## die Platte Maschine wie ihre Flanken.
func _apply_deck_skin() -> void:
	if _deck_top == null or not is_instance_valid(_deck_top):
		return
	_deck_top.material_override = deck_skin if deck_skin != null else _deck_side_material

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

	# Zwei geschlossene Flanken; vorn und hinten steht je ein Sturz über einem
	# Öffnungsband - hinten schiebt die Ware herein, vorn hinaus.
	_box("WallLeft", Vector3(span.x, depth, WALL),
		Vector3(0.0, top - depth * 0.5, -half.y - WALL * 0.5), _wall_material)
	_box("WallRight", Vector3(span.x, depth, WALL),
		Vector3(0.0, top - depth * 0.5, half.y + WALL * 0.5), _wall_material)
	var lintel := maxf(depth - mouth, 0.01)
	_box("BackLintel", Vector3(WALL, lintel, span.y + WALL * 2.0),
		Vector3(half.x + WALL * 0.5, top - lintel * 0.5, 0.0), _wall_material)
	_box("FrontLintel", Vector3(WALL, lintel, span.y + WALL * 2.0),
		Vector3(-half.x - WALL * 0.5, top - lintel * 0.5, 0.0), _wall_material)

	# Je Band ein Hohlraum: Stirnwand, zwei Flanken und eine Decke, damit der Blick
	# durch keines der beiden Öffnungsbänder ins Freie fällt.
	_build_cavity("Back", 1.0, span, top, mouth, cavity)
	_build_cavity("Front", -1.0, span, top, mouth, cavity)

	# Die SOHLE unter Schacht und BEIDEN Hohlräumen: der Blick in den offenen Schacht
	# darf nie auf den Raumboden fallen (der Filz ist dort weggeblendet).
	_box("Sole", Vector3(span.x + WALL * 2.0 + cavity * 2.0, DECK,
		span.y + WALL * 2.0),
		Vector3(0.0, sole_y + DECK * 0.5, 0.0), _cavity_material)

	var glow_y := -GLOW_DROP - GLOW_H * 0.5
	# Rundum, denn beide Stürze stehen hoch genug: der Saum liegt auf ihnen, nicht
	# im Öffnungsband - und er liegt IM Schacht, er umrandet die Fläche nicht.
	_box("GlowFront", Vector3(GLOW_IN, GLOW_H, span.y),
		Vector3(-half.x + GLOW_IN * 0.5, glow_y, 0.0), _glow_material)
	_box("GlowBack", Vector3(GLOW_IN, GLOW_H, span.y),
		Vector3(half.x - GLOW_IN * 0.5, glow_y, 0.0), _glow_material)
	_box("GlowLeft", Vector3(span.x, GLOW_H, GLOW_IN),
		Vector3(0.0, glow_y, -half.y + GLOW_IN * 0.5), _glow_material)
	_box("GlowRight", Vector3(span.x, GLOW_H, GLOW_IN),
		Vector3(0.0, glow_y, half.y - GLOW_IN * 0.5), _glow_material)

	_build_platform(span)

## Ein HOHLRAUM hinter einem Öffnungsband, gespiegelt über dir (+1 = hinten, der
## Eingang; -1 = vorn, der Ausgang). Stirnwand, zwei Flanken und eine Decke - durch
## das Band blickt man ein Stück weit hinein, und dort soll das Auge nichts finden.
func _build_cavity(cavity_name: String, dir: float, span: Vector2, top: float,
		mouth: float, cavity: float) -> void:
	var mid := dir * (half.x + WALL + cavity * 0.5)
	_box("Cavity%sEnd" % cavity_name, Vector3(WALL, depth, span.y + WALL * 2.0),
		Vector3(dir * (half.x + WALL * 1.5 + cavity), top - depth * 0.5, 0.0),
		_cavity_material)
	_box("Cavity%sLeft" % cavity_name, Vector3(cavity, depth, WALL),
		Vector3(mid, top - depth * 0.5, -half.y - WALL * 0.5), _cavity_material)
	_box("Cavity%sRight" % cavity_name, Vector3(cavity, depth, WALL),
		Vector3(mid, top - depth * 0.5, half.y + WALL * 0.5), _cavity_material)
	_box("Cavity%sLid" % cavity_name, Vector3(cavity, WALL, span.y + WALL * 2.0),
		Vector3(mid, top - (depth - mouth) - WALL * 0.5, 0.0), _cavity_material)

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
	_deck_top = MeshInstance3D.new()
	_deck_top.name = "DeckTop"
	_deck_top.mesh = skin
	_deck_top.position = Vector3(0.0, -skin_h * 0.5, 0.0)
	_deck_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_platform.add_child(_deck_top)
	_apply_deck_skin()
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
