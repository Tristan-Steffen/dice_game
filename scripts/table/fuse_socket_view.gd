class_name FuseSocketView
extends Node3D
## Die SICHERUNGS-FASSUNG - die Reparatur-Station als FLACHE KLAPPE auf dem Filz,
## rechts neben dem Podest der Werkstatt-Zeile (sie ersetzt am 2026-09-10 die
## schräge Ladesäule ChargingColumnView; Aufladen und Ableiten sind mit ihr
## gestorben, es gibt nur noch die EINE Handlung: die Sicherung eindrücken).
## Ihr Kunde ist der ZIELWÜRFEL auf dem Podest; sie zeigt ihn nie selbst (ein
## Würfel wird nie zweimal gezeigt), sondern nur seine SICHERUNG: heil liegt sie
## bündig in ihrer Rinne zwischen zwei Klemmen, durchgebrannt ist sie aus der
## Klemme GESPRUNGEN (verrußt, Glut-Saum, die Rinne glüht) - und der Druck auf sie
## ist die Reparatur. Rechts daneben, in derselben Zeile, das Preisschild.
## Sie bucht NICHTS und meldet nur (scene_root hängt das Signal an GameRun); die
## Sitz-Fahrt schreibt den Endzustand zuerst. Kein mark_reflective - Filz.

## Der Spieler drückt die Sicherung - gemeldet wird der Kunde, gebucht in GameRun.
signal repair_requested(die: DieDefinition)

## Eigene Pick-Ebene: die Klickzonen liegen auf 8, der Vorrat auf 16, die Hülle auf
## 32, der Kombi-Deckel auf 128 (dieselbe wie die Knopfleiste des Regalstapels -
## die TEILE heißen verschieden, und wer fragt, prüft den Namen).
const PICK_LAYER := 256

const PART_NONE := ""
const PART_FUSE := "fuse"

# --- Maße (Welt) -------------------------------------------------------------------
## Halbmaße der Klappe: x = Bildschirm-Höhe, y = Welt-z = Bildschirm-Breite. Eine
## ZEILE: links die Sicherung in ihrer Rinne, rechts das Preisschild.
const HALF := Vector2(0.60, 1.85)
const PLATE_HEIGHT := 0.10
const PLATE_LIFT := 0.02

## Die RINNE (Welt-z-Mitte) und ihre Halbmaße: ein echtes LOCH in der Platte - die
## Platte ist ein Rahmen aus vier Stücken um sie herum, ihr Boden liegt tiefer.
const CHANNEL_AT := -0.66
const CHANNEL_HALF := Vector2(0.29, 0.95)
const CHANNEL_DEPTH := 0.06

## Die Sicherung LIEGT quer (Achse Welt-Z, im Bild waagerecht) zwischen zwei KLEMMEN.
const FUSE_RADIUS := 0.18
const FUSE_LENGTH := 1.30
const FUSE_CAP := 0.14
const CLAMP_SIZE := Vector3(0.52, 0.26, 0.18)

## Durchgebrannt SPRINGT sie aus der Klemme: hinauf um y und nach Bildschirm-OBEN
## um x - eine Welthöhe allein projiziert an der 15°-Station nur mit 0,27 in die
## Fläche, der Versatz in der Fläche macht den Sprung dort lesbar.
const POP := Vector2(0.20, 0.25)
const SEAT_TIME := 0.28

## Griff: die Sicherung hebt sich eine Spur und glüht auf (Geste des Raster-Umschalters).
const HOVER_LIFT := 0.10
const HOVER_TIME := 0.13
const HOVER_GAIN := 2.1

## Das Preisschild: EINE Zeile flach auf der Platte, rechts der Rinne, in
## Tisch-Leserichtung. Der Schriftgrad hängt an der längsten Aufschrift ($15).
const PRICE_AT := 1.12
const PRICE_SPAN := 0.82
const PRICE_FONT := 64
const PRICE_CHARS := 3.4

## Das KABEL zum Podest-Puck: es LIEGT auf dem Filz, in drei Segmenten mit einem
## Bauch nach Bildschirm-unten (ein schlaffes Kabel, kein gespannter Draht).
const CABLE_RADIUS := 0.05
const CABLE_LIFT := 0.05
const CABLE_SAG := 0.55

const PLATE_ALBEDO := Color(0.075, 0.072, 0.108)
const PLATE_EMISSION := Color(0.20, 0.22, 0.34)
const PLATE_ENERGY := 0.55
const CHANNEL_ALBEDO := Color(0.035, 0.033, 0.055)
const CHANNEL_ENERGY := 0.25
const METAL_ALBEDO := LeverView.METAL_ALBEDO
const CABLE_ALBEDO := Color(0.09, 0.09, 0.12)

## Die heile Sicherung: Glas mit einem ruhigen Gold-Faden. Durchgebrannt Ruß und
## Glut (die Töne des Würfel-Durchbrenners, nie das Energie-Cyan).
const FUSE_ALBEDO := Color(0.42, 0.46, 0.55)
const FUSE_BURNED_ALBEDO := DieFaceDisplay.BURNED_BODY * 0.4
const LIVE_TINT := CasinoStyle.GOLD_INTENSE
const DEAD_TINT := CasinoStyle.MUTED
const EMBER := DieNetView.ChargeLamps.EMBER
const INTACT_ENERGY := 0.35
const DEAD_ENERGY := 0.12
## Durchgebrannt und bezahlbar glüht sie voll; unbezahlbar nur noch als Glut.
const LIVE_ENERGY := 0.95
const BLOCKED_ENERGY := 0.4
const CHANNEL_HOT_ENERGY := 0.9

const PULSE_GAIN := 2.6
const PULSE_TIME := 0.35

var center := Vector3.ZERO

var _customer: DieDefinition
var _signature := "-"
var _repair_live := false
var _hovered := PART_NONE

## Der HALTER trägt den Griff-Hub, die SICHERUNG darin den Sprung - zwei Fahrten,
## die sich nie in die Quere kommen.
var _holder: Node3D
var _fuse: Node3D
var _fuse_material: StandardMaterial3D
var _channel_material: StandardMaterial3D
## Steht die Sicherung heraus? Der Wechsel heraus->hinein IST die Reparatur-Fahrt.
var _fuse_out := false
var _fuse_body: StaticBody3D
var _price: Label3D
var _cable: Node3D
var _built := false
var _seat_tween: Tween
var _hover_tween: Tween
var _pulse_tween: Tween
var _pulse_rest := 1.0

func _init(socket_name := "FuseSocket") -> void:
	name = socket_name

## Welches Bedienelement gehört zu diesem Kollisions-Körper ("" = keines)?
static func part_of(collider: Object) -> String:
	var body := collider as Node
	if body == null or not body.has_meta("part"):
		return PART_NONE
	return str(body.get_meta("part"))

## Wie hoch die Klappe im äußersten Fall baut (gesprungene, gegriffene Sicherung) -
## der Kopfraum, den die Kamera zulegen muß.
static func height() -> float:
	return _fuse_rest_y() + FUSE_RADIUS + POP.y + HOVER_LIFT

## Die Oberkante der Platte.
static func plate_top() -> float:
	return PLATE_LIFT + PLATE_HEIGHT

## Die Achse der heil liegenden Sicherung: sie liegt IN der Rinne.
static func _fuse_rest_y() -> float:
	return plate_top() - CHANNEL_DEPTH + FUSE_RADIUS

## Stellt die Klappe (idempotent - derselbe Platz baut nichts neu).
func setup(at: Vector3) -> void:
	var same := _built and center.is_equal_approx(at)
	center = at
	if same:
		return
	_build()

# --- Meldungen ---------------------------------------------------------------------

## Das Weltrechteck der Klappe in XZ.
func bounds_min() -> Vector2:
	return Vector2(center.x - HALF.x, center.z - HALF.y)

func bounds_max() -> Vector2:
	return Vector2(center.x + HALF.x, center.z + HALF.y)

## Die Sicherung selbst - dort schlägt das Licht ein.
func fuse_point() -> Vector3:
	return center + Vector3(0.0, _fuse_rest_y(), CHANNEL_AT)

## Die Bildschirm-linke Kante, an der das Kabel zum Podest ansetzt.
func cable_root() -> Vector3:
	return center + Vector3(0.0, CABLE_LIFT, -HALF.y)

# --- Zustand -----------------------------------------------------------------------

## Der Kunde und sein Stand. Nur der WECHSEL schreibt die Sicherung um.
func set_customer(die: DieDefinition) -> void:
	_customer = die
	_apply_state()

## Darf jetzt repariert werden (RepairRules)? Was nicht darf, glüht nur und klickt nicht.
func set_live(repair: bool) -> void:
	if _repair_live == repair:
		return
	_repair_live = repair
	_write_live()

func repair_live() -> bool:
	return _repair_live

func live_for(part: String) -> bool:
	return part == PART_FUSE and _repair_live

## Der Zeiger liegt auf der Sicherung (PART_NONE = nicht). Tot antwortet sie nicht.
func set_hovered(part: String) -> void:
	if not live_for(part):
		part = PART_NONE
	if _hovered == part:
		return
	_hovered = part
	_write_live()

func hovered() -> String:
	return _hovered

func burned() -> bool:
	return _customer != null and _customer.burned_out

func customer() -> DieDefinition:
	return _customer

## Ist die Sicherung aus der Klemme gesprungen? (Die Anzeige des Durchbrenners.)
func fuse_popped() -> bool:
	if _fuse == null or not is_instance_valid(_fuse):
		return false
	return _fuse.position.is_equal_approx(_fuse_seat(true))

## Ist die Sicherung scharf, fängt sie also den Strahl?
func pick_armed(part: String) -> bool:
	return part == PART_FUSE and _fuse_body != null and is_instance_valid(_fuse_body) \
		and _fuse_body.collision_layer == PICK_LAYER

## Die Aufschrift des Preisschildes (leer = keines).
func plate_text(part: String) -> String:
	if part != PART_FUSE or _price == null or not is_instance_valid(_price):
		return ""
	return _price.text

## Der Preis am Körper - EINE Quelle (RepairRules liest GameRun).
func set_prices(run: GameRun) -> void:
	if _price == null or not is_instance_valid(_price):
		return
	var text := RepairRules.repair_price_text(run)
	if _price.text == text:
		return
	_price.text = text
	_price.pixel_size = PRICE_SPAN / (PRICE_CHARS * float(PRICE_FONT) * 0.62)

# --- Die Zeremonien ------------------------------------------------------------------
# Endzustand zuerst: die Ruhelage steht, der Tween ist nur die Anzeige.

## Der Druck auf die Sicherung (true = sie hat gemeldet). Tot meldet sie nichts.
func press(part: String) -> bool:
	if not live_for(part) or _customer == null:
		return false
	repair_requested.emit(_customer)
	return true

## Die Sicherung fährt zurück in ihre Klemme (die Reparatur). Endzustand zuerst.
func seat_fuse() -> void:
	if _fuse == null or not is_instance_valid(_fuse):
		return
	if _seat_tween != null and _seat_tween.is_valid():
		_seat_tween.kill()
	var seat := _fuse_seat(false)
	_fuse.position = seat
	_seat_tween = create_tween()
	_seat_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_seat_tween.tween_method(_set_fuse_position, _fuse_seat(true), seat, SEAT_TIME)

func _set_fuse_position(at: Vector3) -> void:
	if _fuse != null and is_instance_valid(_fuse):
		_fuse.position = at

## Die Ankunft quittieren: die Sicherung pulst kurz auf.
func pulse() -> void:
	if _fuse_material == null:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_rest = _fuse_material.emission_energy_multiplier
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(_apply_pulse, PULSE_GAIN, 1.0, PULSE_TIME)

func _apply_pulse(gain: float) -> void:
	if _fuse_material != null:
		_fuse_material.emission_energy_multiplier = _pulse_rest * gain

# --- Aufbau ---------------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_holder = null
	_fuse = null
	_fuse_body = null
	_price = null
	_cable = null
	_hovered = PART_NONE
	_signature = "-"
	global_position = center
	_build_plate()
	_build_channel()
	_build_fuse()
	_build_price()
	_built = true
	_apply_state()
	_write_live()

## Die PLATTE: ein Rahmen aus vier Stücken um das Loch der Rinne - ein Quader hätte
## die Vertiefung verschluckt.
func _build_plate() -> void:
	var material := _metal(PLATE_ALBEDO, PLATE_EMISSION, PLATE_ENERGY)
	var y := PLATE_LIFT + PLATE_HEIGHT * 0.5
	var left := CHANNEL_AT - CHANNEL_HALF.y   # Welt-z der Rinnenkanten
	var right := CHANNEL_AT + CHANNEL_HALF.y
	_box("PlatteLinks", Vector3(HALF.x * 2.0, PLATE_HEIGHT, left + HALF.y),
		Vector3(0.0, y, (left - HALF.y) * 0.5), material, self)
	_box("PlatteRechts", Vector3(HALF.x * 2.0, PLATE_HEIGHT, HALF.y - right),
		Vector3(0.0, y, (right + HALF.y) * 0.5), material, self)
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		_box("PlatteRand%d" % side,
			Vector3(HALF.x - CHANNEL_HALF.x, PLATE_HEIGHT, CHANNEL_HALF.y * 2.0),
			Vector3(dir * (CHANNEL_HALF.x + HALF.x) * 0.5, y, CHANNEL_AT), material, self)

## Die RINNE: ihr Boden liegt um CHANNEL_DEPTH unter der Platte und glüht beim
## Durchbrenner; an jedem Ende eine KLEMME.
func _build_channel() -> void:
	_channel_material = _metal(CHANNEL_ALBEDO, PLATE_EMISSION, CHANNEL_ENERGY)
	_channel_material.metallic = 0.2
	_channel_material.roughness = 0.7
	var floor_height := PLATE_HEIGHT - CHANNEL_DEPTH
	_box("Rinne", Vector3(CHANNEL_HALF.x * 2.0, floor_height, CHANNEL_HALF.y * 2.0),
		Vector3(0.0, PLATE_LIFT + floor_height * 0.5, CHANNEL_AT),
		_channel_material, self)
	for side in 2:
		_box("Klemme%d" % side, CLAMP_SIZE,
			Vector3(0.0, plate_top() + CLAMP_SIZE.y * 0.5 - CHANNEL_DEPTH,
				CHANNEL_AT + (float(side) * 2.0 - 1.0) * (FUSE_LENGTH * 0.5 - FUSE_CAP * 0.5)),
			_metal(METAL_ALBEDO, PLATE_EMISSION, 0.45), self)

## Die SICHERUNG in ihrem Halter: ein Glaszylinder mit zwei Metallkappen, quer in
## der Rinne. Der Halter fährt den Griff, die Sicherung den Sprung.
func _build_fuse() -> void:
	_holder = Node3D.new()
	_holder.name = "Halter"
	_holder.position = Vector3(0.0, 0.0, CHANNEL_AT)
	add_child(_holder)
	var fuse := Node3D.new()
	fuse.name = "Sicherung"
	_holder.add_child(fuse)
	_fuse = fuse
	_fuse_material = _metal(FUSE_ALBEDO, LIVE_TINT, INTACT_ENERGY)
	_fuse_material.metallic = 0.3
	_fuse_material.roughness = 0.25
	var glass := _cylinder("Glas", FUSE_RADIUS, FUSE_LENGTH - FUSE_CAP * 2.0,
		_fuse_material, fuse)
	glass.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	for side in 2:
		var cap := _cylinder("Kappe%d" % side, FUSE_RADIUS * 1.08, FUSE_CAP,
			_metal(METAL_ALBEDO, PLATE_EMISSION, 0.2), fuse)
		cap.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		cap.position = Vector3(0.0, 0.0,
			(float(side) * 2.0 - 1.0) * (FUSE_LENGTH - FUSE_CAP) * 0.5)
	fuse.position = _fuse_seat(false)
	# Der Pick-Körper deckt Rinne UND Sprung - die gesprungene Sicherung liegt versetzt.
	_fuse_body = _pick_body(PART_FUSE, _holder,
		Vector3(CHANNEL_HALF.x * 2.0 + POP.x, FUSE_RADIUS * 2.0 + POP.y + HOVER_LIFT,
			FUSE_LENGTH + FUSE_CAP),
		Vector3(POP.x * 0.5, _fuse_rest_y() + POP.y * 0.5, 0.0))

## Wo die Sicherung liegt: in der Klemme oder daraus gesprungen.
func _fuse_seat(popped: bool) -> Vector3:
	var seat := Vector3(0.0, _fuse_rest_y(), 0.0)
	return seat + Vector3(POP.x, POP.y, 0.0) if popped else seat

## Das Preisschild: flach auf der Platte, rechts der Rinne, in Tisch-Leserichtung.
func _build_price() -> void:
	var label := Label3D.new()
	label.name = "Preis"
	label.font_size = PRICE_FONT
	label.transform.basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	label.position = Vector3(0.0, plate_top() + 0.02, PRICE_AT)
	label.outline_size = 14
	label.outline_modulate = Color(0.03, 0.03, 0.05)
	add_child(label)
	_price = label

## Das KABEL zum Podest: drei Segmente auf dem Filz mit Bauch nach Bildschirm-unten.
func set_cable_to(target: Vector3) -> void:
	if _cable != null and is_instance_valid(_cable):
		remove_child(_cable)
		_cable.queue_free()
	_cable = null
	if target == Vector3.ZERO:
		return
	var host := Node3D.new()
	host.name = "Kabel"
	add_child(host)
	_cable = host
	var from := cable_root() - center
	var to := Vector3(target.x, CABLE_LIFT, target.z) - center
	var material := _metal(CABLE_ALBEDO, PLATE_EMISSION, 0.22)
	var points: Array[Vector3] = []
	for i in 4:
		var t := float(i) / 3.0
		var point := from.lerp(to, t)
		point.x -= sin(t * PI) * CABLE_SAG
		points.append(point)
	for i in 3:
		var a := points[i]
		var b := points[i + 1]
		var span := b - a
		if span.length() < 0.01:
			continue
		var segment := _cylinder("Ader%d" % i, CABLE_RADIUS, span.length(),
			material, host)
		segment.position = (a + b) * 0.5
		segment.quaternion = Quaternion(Vector3.UP, span.normalized())

# --- Anzeige --------------------------------------------------------------------------

## Der EINE Schreiber der Kunden-Anzeige: Sicherung und Rinne. Idempotent per
## Signatur - nur der Wechsel schreibt um.
func _apply_state() -> void:
	if not _built:
		return
	var signature := "-" if _customer == null else ("burned" if _customer.burned_out else "ok")
	if signature == _signature:
		return
	_signature = signature
	var is_burned := burned()
	if _fuse != null and is_instance_valid(_fuse):
		if _fuse_out and not is_burned:
			seat_fuse()  # die REPARATUR: die Sicherung fährt zurück in die Klemme
		else:
			if _seat_tween != null and _seat_tween.is_valid():
				_seat_tween.kill()
			_fuse.position = _fuse_seat(is_burned)
		_fuse_out = is_burned
	if _fuse_material != null:
		_fuse_material.albedo_color = FUSE_BURNED_ALBEDO if is_burned else FUSE_ALBEDO
		_fuse_material.emission = EMBER if is_burned else LIVE_TINT
	if _channel_material != null:
		_channel_material.emission = EMBER if is_burned else PLATE_EMISSION
		_channel_material.emission_energy_multiplier = \
			CHANNEL_HOT_ENERGY if is_burned else CHANNEL_ENERGY
	_write_live()  # Glut und Griff lesen denselben Stand

## Der EINE Schreiber der Bedienbarkeit: nur die gesprungene, bezahlbare Sicherung
## glüht voll und fängt den Strahl.
func _write_live() -> void:
	if not _built:
		return
	if _fuse_material != null:
		if _repair_live:
			_fuse_material.emission_energy_multiplier = \
				LIVE_ENERGY * (HOVER_GAIN if _hovered == PART_FUSE else 1.0)
		elif burned():
			_fuse_material.emission_energy_multiplier = BLOCKED_ENERGY
		elif _customer != null:
			_fuse_material.emission_energy_multiplier = INTACT_ENERGY
		else:
			_fuse_material.emission = DEAD_TINT
			_fuse_material.emission_energy_multiplier = DEAD_ENERGY
	if _fuse_body != null and is_instance_valid(_fuse_body):
		_fuse_body.collision_layer = PICK_LAYER if _repair_live else 0
	_lift(_hovered == PART_FUSE)

## Der Griff: der Halter hebt sich eine Spur. Nur der Wechsel fährt.
func _lift(on: bool) -> void:
	if _holder == null or not is_instance_valid(_holder):
		return
	var wanted := HOVER_LIFT if on else 0.0
	if is_equal_approx(_holder.position.y, wanted):
		return
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_holder, "position:y", wanted, HOVER_TIME)

# --- Bausteine -------------------------------------------------------------------------

func _pick_body(part: String, host: Node3D, box_size: Vector3,
		at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Griff_%s" % part
	body.collision_layer = PICK_LAYER
	body.collision_mask = 0
	body.position = at
	body.set_meta("part", part)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	host.add_child(body)
	return body

func _metal(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.55
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _box(box_name: String, box_size: Vector3, at: Vector3, material: Material,
		host: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(instance)
	return instance

func _cylinder(cylinder_name: String, radius: float, length: float,
		material: Material, host: Node3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = maxf(length, 0.01)
	mesh.radial_segments = 12
	mesh.rings = 0
	var instance := MeshInstance3D.new()
	instance.name = cylinder_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(instance)
	return instance
