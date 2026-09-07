class_name ChargingColumnView
extends Node3D
## Die LADESÄULE - die Reparatur-Station als KÖRPER, rechts neben dem Podest der
## Werkstatt-Zeile (sie ersetzt am 2026-09-07 die 2D-Bucht RepairBayView).
## Ihr Kunde ist der ZIELWÜRFEL auf dem Podest; sie zeigt ihn nie selbst (ein
## Würfel wird nie zweimal gezeigt), sondern nur seinen ZUSTAND und die drei
## Handlungen:
##  - DREI ELKO-DOSEN übereinander (die Bauform der Kondensatorbank, nicht
##    nachgeschnitzt): je Ladung eine leuchtet im Ladungston, durchgebrannt tragen
##    alle den Glut-Saum, ohne Kunden sind alle aus.
##  - ZWEI KIPPHEBEL: oben nach OBEN = Aufladen, unten nach UNTEN = Ableiten.
##  - Am Fuß der SICHERUNGSSOCKEL: durchgebrannt steht die geschwärzte Sicherung
##    heraus, die Reparatur drückt sie hinein.
## Je Bedienelement ein SCHILD mit seinem Preis. Sie bucht NICHTS und meldet nur
## (scene_root hängt die Signale an GameRun); jede Kipp-Fahrt schreibt den
## Endzustand zuerst und fährt dann den Weg dorthin.
## Kein mark_reflective - sie steht auf blankem Filz.

## Der Spieler legt einen Hebel um bzw. drückt die Sicherung - sie MELDET nur den
## Kunden, gebucht wird in GameRun (scene_root hängt die Signale an).
signal repair_requested(die: DieDefinition)
signal drain_requested(die: DieDefinition)
signal charge_requested(die: DieDefinition)

## Eigene Pick-Ebene: die Klickzonen liegen auf 8, der Vorrat auf 16, die Hülle auf
## 32, der Kombi-Deckel auf 128.
const PICK_LAYER := 256

const PART_NONE := ""
const PART_CHARGE := "charge"
const PART_DRAIN := "drain"
const PART_FUSE := "fuse"

# --- Maße (Welt) -------------------------------------------------------------------
## Die Säule LEHNT sich dem Blick entgegen: die Station schaut 15° neben der
## Senkrechten auf den Tisch (CameraRig.ZOOM_FORWARD), also projiziert eine
## WELTHÖHE nur mit tan 15° = 0,27 in die Fläche - drei senkrecht gestapelte Dosen
## fielen in EINEN Fleck zusammen (gemessen: 6 Display-px Abstand bei 17,6 px
## Dosenbreite). Um LEAN gekippt trägt dieselbe Teilung 24 px, und die Konsole
## zeigt dem Spieler ihre Fläche.
const LEAN := 1.05

const BASE_HALF := Vector2(0.55, 0.95)
const BASE_HEIGHT := 0.22
## x = halbe Dicke der Konsole, z = ihre halbe Breite.
const MAST_HALF := Vector2(0.22, 0.62)
## Länge der Konsole ENTLANG ihrer geneigten Achse.
const MAST_LENGTH := 4.10

## Die Plätze auf der Konsole, gemessen von ihrem Fuß nach oben.
## Gemessen: unter 0,8 verschwindet der Sicherungssockel im Bild HINTER dem Sockel
## der Säule - eine Welthöhe projiziert an dieser Station nur mit 0,27.
const FUSE_AT := 0.80
const DRAIN_AT := 1.50
const CELL_AT := 2.15
const CELL_PITCH := 0.65
const CHARGE_AT := 3.92

## Ein Kipphebel: Sockel, Griffstange, Knauf.
const SOCKET_SIZE := Vector3(0.18, 0.34, 0.34)
const ARM_LENGTH := 0.52
const ARM_RADIUS := 0.05
const KNOB_RADIUS := 0.13
## Ruhe waagerecht, geschaltet um diesen Winkel gekippt (der obere hinauf, der
## untere hinab).
const LEVER_TILT := 0.62
const LEVER_TIME := 0.13
const LEVER_HOLD := 0.35

## Die Sicherung im Sockel: heil bündig, durchgebrannt um FUSE_POP heraus.
const FUSE_SOCKET := Vector3(0.22, 0.36, 0.62)
const FUSE_RADIUS := 0.12
const FUSE_LENGTH := 0.40
const FUSE_CAP := 0.08
const FUSE_POP := 0.34
const FUSE_SEAT_TIME := 0.28

## Preisschilder: eine FLACHE Platte an der Bildschirm-rechten Flanke (+Z) neben
## ihrem Bedienelement - flach, weil die Station von oben schaut.
const PLATE_SPAN := Vector2(0.40, 0.72)
const PLATE_HEIGHT := 0.05
const PLATE_FONT := 64
## Die längste Aufschrift des Katalogs ($15) - an ihr hängt der EINE Schriftgrad.
const PLATE_CHARS := 3.4

## Das KABEL zum Podest-Puck: es LIEGT auf dem Filz, in drei Segmenten mit einem
## seitlichen Bauch (ein schlaffes Kabel, kein gespannter Draht).
const CABLE_RADIUS := 0.05
const CABLE_LIFT := 0.05
const CABLE_SAG := 0.55

const MAST_ALBEDO := Color(0.085, 0.082, 0.118)
const MAST_EMISSION := Color(0.18, 0.20, 0.32)
const MAST_ENERGY := 0.5
const BASE_ALBEDO := Color(0.06, 0.058, 0.086)
const METAL_ALBEDO := Color(0.34, 0.37, 0.44)
const CABLE_ALBEDO := Color(0.09, 0.09, 0.12)

## Die Dose trägt die LADUNGS-Farbe, nie das Energie-Cyan (EINE Quelle: der Würfel).
const CELL_ON := DieFaceDisplay.CHARGE_COLOR
const CELL_ON_ENERGY := 1.0
const CELL_BURNED := DieNetView.ChargeLamps.EMBER
const CELL_BURNED_ENERGY := 0.9

const LIVE_TINT := CasinoStyle.GOLD_INTENSE
const DEAD_TINT := CasinoStyle.MUTED
const LIVE_ENERGY := 0.85
const DEAD_ENERGY := 0.12
const HOVER_GAIN := 2.1
## Der Griff hebt das Bedienelement eine Spur nach vorn (Bildschirm-unten).
const HOVER_NUDGE := 0.09
const HOVER_TIME := 0.13

const PULSE_GAIN := 2.6
const PULSE_TIME := 0.35

var center := Vector3.ZERO

var _customer: DieDefinition
var _signature := "-"
var _charge_live := false
var _drain_live := false
var _repair_live := false
var _hovered := PART_NONE

var _cells: Array[MeshInstance3D] = []
var _cell_materials: Array[StandardMaterial3D] = []
var _levers := {}          # Teil -> {pivot, arm, knob, material, body}
var _fuse: Node3D
var _fuse_material: StandardMaterial3D
## Steht die Sicherung heraus? Der Wechsel heraus->hinein IST die Reparatur-Fahrt.
var _fuse_out := false
var _fuse_body: StaticBody3D
var _plates := {}          # Teil -> Label3D
var _cable: Node3D
## Die geneigte KONSOLE - jedes Bedienelement hängt in ihrem System.
var _face: Node3D
var _built := false
var _lever_tweens := {}
var _fuse_tween: Tween
var _pulse_tween: Tween

func _init(column_name := "ChargingColumn") -> void:
	name = column_name

## Welches Bedienelement gehört zu diesem Kollisions-Körper ("" = keines)?
static func part_of(collider: Object) -> String:
	var body := collider as Node
	if body == null or not body.has_meta("part"):
		return PART_NONE
	return str(body.get_meta("part"))

## Gesamthöhe der Säule - der Kopfraum, den die Kamera zulegen muß.
static func column_height() -> float:
	return BASE_HEIGHT + MAST_LENGTH * cos(LEAN)

## Ein Platz auf der geneigten Konsole, im Körper-System: reach = wie weit vor
## ihrer Fläche, at = wie weit ihre Achse hinauf.
static func face_point(at: float, reach := 0.0) -> Vector3:
	var out := MAST_HALF.x + reach
	return Vector3(-out * cos(LEAN) + at * sin(LEAN),
		BASE_HEIGHT + out * sin(LEAN) + at * cos(LEAN), 0.0)

## Wie weit die Konsole über ihren Sockel nach Bildschirm-OBEN hinauslehnt.
static func lean_reach() -> float:
	return MAST_HALF.x * cos(LEAN) + MAST_LENGTH * sin(LEAN)

## Der Versatz zwischen Fußabdruck-Mitte und Konsolen-Fuß: die Konsole lehnt nach
## Bildschirm-OBEN, also sitzt ihr Fuß vor der Mitte.
static func foot_shift() -> float:
	return (-BASE_HALF.x + lean_reach()) * 0.5

## Stellt die Säule (idempotent - derselbe Platz baut nichts neu).
func setup(at: Vector3) -> void:
	var same := _built and center.is_equal_approx(at)
	center = at
	if same:
		return
	_build()

# --- Meldungen ---------------------------------------------------------------------

## Das Weltrechteck des Fußabdrucks in XZ - die Konsole lehnt nach Bildschirm-oben
## über ihren Sockel hinaus, also mißt es an BEIDEN.
func bounds_min() -> Vector2:
	return Vector2(_origin().x - BASE_HALF.x, center.z - _side_reach())

func bounds_max() -> Vector2:
	return Vector2(_origin().x + lean_reach(), center.z + _side_reach())

## Die SPITZE der Konsole (auf ihrer Achse) - dort schlägt der Komet aus der
## Kondensatorbank ein.
func head_point() -> Vector3:
	return _origin() + face_point(MAST_LENGTH, -MAST_HALF.x)

## Der Fuß, an dem das Kabel zum Podest ansetzt.
func cable_root() -> Vector3:
	return _origin() + Vector3(-BASE_HALF.x * 0.5, CABLE_LIFT, 0.0)

## Der Konsolen-Fuß: center ist die Mitte des FUSSABDRUCKS, nicht der Sockel.
func _origin() -> Vector3:
	return center - Vector3(foot_shift(), 0.0, 0.0)

func _side_reach() -> float:
	return maxf(BASE_HALF.y, MAST_HALF.y + PLATE_SPAN.y)

# --- Zustand -----------------------------------------------------------------------

## Der Kunde und sein Stand. Nur der WECHSEL schreibt die Dosen und die Sicherung um.
func set_customer(die: DieDefinition) -> void:
	_customer = die
	_apply_state()

## Was gerade wirken kann (RepairRules) - was nicht, steht grau und klickt nicht.
func set_live(charge: bool, drain: bool, repair: bool) -> void:
	if _charge_live == charge and _drain_live == drain and _repair_live == repair:
		return
	_charge_live = charge
	_drain_live = drain
	_repair_live = repair
	_write_live()

func charge_live() -> bool:
	return _charge_live

func drain_live() -> bool:
	return _drain_live

func repair_live() -> bool:
	return _repair_live

func live_for(part: String) -> bool:
	match part:
		PART_CHARGE:
			return _charge_live
		PART_DRAIN:
			return _drain_live
		PART_FUSE:
			return _repair_live
	return false

## Der Zeiger liegt auf einem Bedienelement (PART_NONE = auf keinem). Ein totes
## Element antwortet nicht.
func set_hovered(part: String) -> void:
	if not live_for(part):
		part = PART_NONE
	if _hovered == part:
		return
	_hovered = part
	_write_live()

func hovered() -> String:
	return _hovered

## Wie viele Dosen gerade brennen - die Anzeige, an der geprüft wird.
func lit_cells() -> int:
	if _customer == null or _customer.burned_out:
		return 0
	return clampi(_customer.charge, 0, _cells.size())

func burned() -> bool:
	return _customer != null and _customer.burned_out

func customer() -> DieDefinition:
	return _customer

## Steht die Sicherung heraus? (Die Anzeige des Durchbrenners.)
func fuse_popped() -> bool:
	if _fuse == null or not is_instance_valid(_fuse):
		return false
	return is_equal_approx(_fuse.position.x, _fuse_seat(true))

## Ist das Bedienelement scharf, fängt es also den Strahl?
func pick_armed(part: String) -> bool:
	if part == PART_FUSE:
		return _fuse_body != null and is_instance_valid(_fuse_body) \
			and _fuse_body.collision_layer == PICK_LAYER
	var lever: Dictionary = _levers.get(part, {})
	if lever.is_empty():
		return false
	var body: StaticBody3D = lever["body"]
	return body != null and is_instance_valid(body) and body.collision_layer == PICK_LAYER

## Die Aufschrift eines Preisschildes (leer = keines).
func plate_text(part: String) -> String:
	var label: Label3D = _plates.get(part)
	return label.text if label != null and is_instance_valid(label) else ""

## Die Preise am Körper - EINE Quelle (RepairRules liest GameRun).
func set_prices(run: GameRun) -> void:
	_write_plate(PART_CHARGE, RepairRules.charge_price_text())
	_write_plate(PART_DRAIN, RepairRules.drain_price_text())
	_write_plate(PART_FUSE, RepairRules.repair_price_text(run))

# --- Die Zeremonien ------------------------------------------------------------------
# Endzustand zuerst: die Ruhelage steht, der Tween ist nur die Anzeige.

## Der Druck auf ein Bedienelement (true = es hat gemeldet). Ein totes Element
## meldet nichts, kippt nicht und sagt nichts - es steht einfach grau.
func press(part: String) -> bool:
	if not live_for(part) or _customer == null:
		return false
	match part:
		PART_CHARGE:
			charge_requested.emit(_customer)
		PART_DRAIN:
			drain_requested.emit(_customer)
		PART_FUSE:
			repair_requested.emit(_customer)
		_:
			return false
	return true

## Der Hebel schlägt um und fällt zurück. Ein toter Hebel rührt sich nicht.
func throw_lever(part: String) -> void:
	var lever: Dictionary = _levers.get(part, {})
	if lever.is_empty():
		return
	var pivot: Node3D = lever["pivot"]
	if pivot == null or not is_instance_valid(pivot):
		return
	var old: Tween = _lever_tweens.get(part)
	if old != null and old.is_valid():
		old.kill()
	pivot.rotation.z = 0.0  # der Endzustand steht, bevor die Fahrt beginnt
	var tilt: float = LEVER_TILT * (-1.0 if part == PART_CHARGE else 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pivot, "rotation:z", tilt, LEVER_TIME)
	tween.tween_interval(LEVER_HOLD)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pivot, "rotation:z", 0.0, LEVER_TIME * 1.6)
	_lever_tweens[part] = tween

## Die Sicherung fährt in ihren Sockel (die Reparatur). Endzustand zuerst.
func seat_fuse() -> void:
	if _fuse == null or not is_instance_valid(_fuse):
		return
	if _fuse_tween != null and _fuse_tween.is_valid():
		_fuse_tween.kill()
	var seat := _fuse_seat(false)
	_fuse.position.x = seat
	_fuse_tween = create_tween()
	_fuse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fuse_tween.tween_method(_set_fuse_x, _fuse_seat(true), seat, FUSE_SEAT_TIME)

func _set_fuse_x(at: float) -> void:
	if _fuse != null and is_instance_valid(_fuse):
		_fuse.position.x = at

## Die Ankunft quittieren: die Säule pulst kurz auf.
func pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(_apply_pulse, PULSE_GAIN, 1.0, PULSE_TIME)

func _apply_pulse(gain: float) -> void:
	for i in _cell_materials.size():
		if i < lit_cells():
			_cell_materials[i].emission_energy_multiplier = CELL_ON_ENERGY * gain

# --- Aufbau ---------------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_cells.clear()
	_cell_materials.clear()
	_levers.clear()
	_plates.clear()
	_lever_tweens.clear()
	_fuse = null
	_fuse_body = null
	_cable = null
	_hovered = PART_NONE
	_signature = "-"
	_face = null
	global_position = _origin()
	_box("Sockel", Vector3(BASE_HALF.x * 2.0, BASE_HEIGHT, BASE_HALF.y * 2.0),
		Vector3(0.0, BASE_HEIGHT * 0.5, 0.0), _metal(BASE_ALBEDO, MAST_EMISSION, 0.3), self)
	# Die KONSOLE: alles Bedienbare hängt in ihrem geneigten System, dessen +Y die
	# Achse hinauf und dessen -X die Fläche zum Betrachter ist.
	_face = Node3D.new()
	_face.name = "Konsole"
	_face.position = Vector3(0.0, BASE_HEIGHT, 0.0)
	_face.rotation = Vector3(0.0, 0.0, -LEAN)
	add_child(_face)
	_box("Mast", Vector3(MAST_HALF.x * 2.0, MAST_LENGTH, MAST_HALF.y * 2.0),
		Vector3(0.0, MAST_LENGTH * 0.5, 0.0),
		_metal(MAST_ALBEDO, MAST_EMISSION, MAST_ENERGY), _face)
	_build_cells()
	_build_lever(PART_CHARGE, CHARGE_AT)
	_build_lever(PART_DRAIN, DRAIN_AT)
	_build_fuse()
	_built = true
	_apply_state()
	_write_live()

## Drei Dosen der Kondensatorbank auf der Fläche der Konsole, übereinander entlang
## ihrer Achse. Die Bauform kommt aus der Bank, nicht aus dieser Datei.
func _build_cells() -> void:
	for i in DieDefinition.CHARGE_MAX:
		var holder := Node3D.new()
		holder.name = "Dose%d" % (i + 1)
		# Eine Vierteldrehung: der lose Elko steht sonst auf seiner Standfläche, hier
		# liegt er auf der Konsolen-FLÄCHE.
		holder.rotation = Vector3(0.0, 0.0, PI * 0.5)
		holder.position = Vector3(-MAST_HALF.x, CELL_AT + float(i) * CELL_PITCH, 0.08)
		_face.add_child(holder)
		var cell := CapacitorBankView.build_loose_cell(false)
		holder.add_child(cell)
		var material := StandardMaterial3D.new()
		material.metallic = 0.4
		material.roughness = 0.25
		material.emission_enabled = true
		cell.material_override = material
		_cells.append(cell)
		_cell_materials.append(material)

func _build_lever(part: String, at_y: float) -> void:
	var host := Node3D.new()
	host.name = "Hebel_%s" % part
	host.position = Vector3(-MAST_HALF.x, at_y, 0.0)
	_face.add_child(host)
	var material := _metal(METAL_ALBEDO, LIVE_TINT, LIVE_ENERGY)
	_box("Fassung", SOCKET_SIZE, Vector3(-SOCKET_SIZE.x * 0.5, 0.0, 0.0),
		_metal(MAST_ALBEDO, MAST_EMISSION, 0.35), host)
	var pivot := Node3D.new()
	pivot.name = "Achse"
	pivot.position = Vector3(-SOCKET_SIZE.x, 0.0, 0.0)
	host.add_child(pivot)
	# Die Stange zeigt aus der Konsolenfläche heraus, also kippt eine Drehung um Z
	# ihre Spitze die Achse hinauf (negativ) bzw. hinab (positiv).
	var arm := _cylinder("Stange", ARM_RADIUS, ARM_LENGTH, material, pivot)
	arm.rotation = Vector3(0.0, 0.0, PI * 0.5)
	arm.position = Vector3(-ARM_LENGTH * 0.5, 0.0, 0.0)
	var knob := MeshInstance3D.new()
	knob.name = "Knauf"
	var sphere := SphereMesh.new()
	sphere.radius = KNOB_RADIUS
	sphere.height = KNOB_RADIUS * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	knob.mesh = sphere
	knob.material_override = material
	knob.position = Vector3(-ARM_LENGTH, 0.0, 0.0)
	knob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(knob)
	var body := _pick_body(part, host,
		Vector3(ARM_LENGTH + KNOB_RADIUS, SOCKET_SIZE.y, SOCKET_SIZE.z),
		Vector3(-(ARM_LENGTH + KNOB_RADIUS) * 0.5, 0.0, 0.0))
	_levers[part] = {"host": host, "pivot": pivot, "material": material, "body": body}
	_build_plate(part, at_y)

## Der SICHERUNGSSOCKEL am Fuß: ein Sockel mit einem Zylinder samt Metallkappen.
func _build_fuse() -> void:
	var host := Node3D.new()
	host.name = "Sicherungssockel"
	host.position = Vector3(-MAST_HALF.x, FUSE_AT, 0.0)
	_face.add_child(host)
	_box("Fassung", FUSE_SOCKET, Vector3(-FUSE_SOCKET.x * 0.5, 0.0, 0.0),
		_metal(MAST_ALBEDO, MAST_EMISSION, 0.35), host)
	var fuse := Node3D.new()
	fuse.name = "Sicherung"
	host.add_child(fuse)
	_fuse = fuse
	_fuse_material = _metal(METAL_ALBEDO, LIVE_TINT, LIVE_ENERGY)
	# Sie liegt QUER in ihrer Klemme (Achse entlang Z, also im Bild waagerecht) und
	# fährt zum Wechsel aus der Fläche heraus - end-on gesehen wäre sie ein Punkt.
	var glass := _cylinder("Glas", FUSE_RADIUS, FUSE_LENGTH, _fuse_material, fuse)
	glass.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	for side in 2:
		var cap := _cylinder("Kappe%d" % side, FUSE_RADIUS * 1.08, FUSE_CAP,
			_metal(METAL_ALBEDO, MAST_EMISSION, 0.2), fuse)
		cap.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		cap.position = Vector3(0.0, 0.0,
			(float(side) * 2.0 - 1.0) * (FUSE_LENGTH - FUSE_CAP) * 0.5)
	fuse.position.x = _fuse_seat(false)
	_fuse_body = _pick_body(PART_FUSE, host,
		Vector3(FUSE_RADIUS * 2.0 + FUSE_POP, FUSE_SOCKET.y, FUSE_LENGTH),
		Vector3(-(FUSE_RADIUS * 2.0 + FUSE_POP) * 0.5, 0.0, 0.0))
	_build_plate(PART_FUSE, FUSE_AT)

## Wo die Sicherung sitzt: bündig im Sockel oder um FUSE_POP heraus.
func _fuse_seat(popped: bool) -> float:
	return -FUSE_SOCKET.x * 0.5 - (FUSE_POP if popped else 0.0)

## Das Preisschild an der Bildschirm-rechten Flanke, FLACH in Tisch-Leserichtung -
## es hängt am KÖRPER, nicht an der geneigten Konsole, sonst läge seine Schrift
## schräg im Bild.
func _build_plate(part: String, at_y: float) -> void:
	var host := Node3D.new()
	host.name = "Schild_%s" % part
	var seat := face_point(at_y)
	host.position = Vector3(seat.x, seat.y, MAST_HALF.y + PLATE_SPAN.y * 0.5)
	add_child(host)
	_box("Blech", Vector3(PLATE_SPAN.x, PLATE_HEIGHT, PLATE_SPAN.y), Vector3.ZERO,
		_metal(BASE_ALBEDO, MAST_EMISSION, 0.3), host)
	var label := Label3D.new()
	label.name = "Preis"
	label.font_size = PLATE_FONT
	# Flach und in TISCH-Leserichtung wie die Aufschrift des Raster-Umschalters.
	label.transform.basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	label.position = Vector3(0.0, PLATE_HEIGHT * 0.5 + 0.02, 0.0)
	label.outline_size = 14
	label.outline_modulate = Color(0.03, 0.03, 0.05)
	host.add_child(label)
	_plates[part] = label

func _write_plate(part: String, text: String) -> void:
	var label: Label3D = _plates.get(part)
	if label == null or not is_instance_valid(label) or label.text == text:
		return
	label.text = text
	# EIN Grad für alle drei Schilder, an der längsten Aufschrift bemessen - sonst
	# läse "$5" doppelt so groß wie "3 ⚡".
	label.pixel_size = PLATE_SPAN.y / (PLATE_CHARS * float(PLATE_FONT) * 0.62)

## Das KABEL zum Podest: drei Segmente auf dem Filz mit seitlichem Bauch.
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
	var from := cable_root() - _origin()
	var to := Vector3(target.x, CABLE_LIFT, target.z) - _origin()
	var material := _metal(CABLE_ALBEDO, MAST_EMISSION, 0.22)
	var points: Array[Vector3] = []
	for i in 4:
		var t := float(i) / 3.0
		var point := from.lerp(to, t)
		point.x -= sin(t * PI) * CABLE_SAG  # der Bauch hängt nach Bildschirm-unten
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
		# Die Zylinderachse ist +Y - sie wird auf die Segmentrichtung gedreht.
		segment.quaternion = Quaternion(Vector3.UP, span.normalized())

# --- Anzeige --------------------------------------------------------------------------

## Der EINE Schreiber der Kunden-Anzeige: Dosen und Sicherung. Idempotent per
## Signatur - nur der Wechsel schreibt um.
func _apply_state() -> void:
	if not _built:
		return
	var signature := "-" if _customer == null \
		else "%d:%d" % [_customer.charge, 1 if _customer.burned_out else 0]
	if signature == _signature:
		return
	_signature = signature
	var is_burned := burned()
	var lit := lit_cells()
	for i in _cell_materials.size():
		var material := _cell_materials[i]
		if is_burned:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			material.albedo_color = DieFaceDisplay.BURNED_BODY * 0.35
			material.emission = CELL_BURNED
			material.emission_energy_multiplier = CELL_BURNED_ENERGY
		elif i < lit:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = CELL_ON
			material.emission = CELL_ON
			material.emission_energy_multiplier = CELL_ON_ENERGY
		else:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			material.albedo_color = CapacitorBankView.CELL_EMPTY_ALBEDO
			material.emission = CapacitorBankView.CELL_EMPTY_EMISSION
			material.emission_energy_multiplier = \
				CapacitorBankView.CELL_EMPTY_ENERGY if _customer != null else 0.35
	if _fuse != null and is_instance_valid(_fuse):
		if _fuse_out and not is_burned:
			seat_fuse()  # die REPARATUR: die neue Sicherung fährt hinein
		else:
			if _fuse_tween != null and _fuse_tween.is_valid():
				_fuse_tween.kill()
			_fuse.position.x = _fuse_seat(is_burned)
		_fuse_out = is_burned
	if _fuse_material != null:
		_fuse_material.albedo_color = \
			DieFaceDisplay.BURNED_BODY * 0.4 if is_burned else METAL_ALBEDO
		_fuse_material.emission = CELL_BURNED if is_burned else LIVE_TINT
	_write_live()  # Glut und Griff lesen denselben Stand

## Der EINE Schreiber der Bedienbarkeit: grau heißt tot, und tot klickt nicht.
func _write_live() -> void:
	if not _built:
		return
	for part: String in [PART_CHARGE, PART_DRAIN]:
		var lever: Dictionary = _levers.get(part, {})
		if lever.is_empty():
			continue
		var live := live_for(part)
		var material: StandardMaterial3D = lever["material"]
		material.albedo_color = METAL_ALBEDO if live else BASE_ALBEDO
		material.emission = LIVE_TINT if live else DEAD_TINT
		if live:
			material.emission_energy_multiplier = \
				LIVE_ENERGY * (HOVER_GAIN if _hovered == part else 1.0)
		else:
			material.emission_energy_multiplier = DEAD_ENERGY
		var body: StaticBody3D = lever["body"]
		if body != null and is_instance_valid(body):
			body.collision_layer = PICK_LAYER if live else 0
		var host: Node3D = lever["host"]
		if host != null and is_instance_valid(host):
			_nudge(host, _hovered == part)
	if _fuse_material != null:
		if _repair_live:
			_fuse_material.emission_energy_multiplier = \
				LIVE_ENERGY * (HOVER_GAIN if _hovered == PART_FUSE else 1.0)
		elif burned():
			_fuse_material.emission_energy_multiplier = CELL_BURNED_ENERGY
		else:
			_fuse_material.emission_energy_multiplier = DEAD_ENERGY
	if _fuse_body != null and is_instance_valid(_fuse_body):
		_fuse_body.collision_layer = PICK_LAYER if _repair_live else 0
	if _fuse != null and is_instance_valid(_fuse):
		_nudge(_fuse.get_parent() as Node3D, _hovered == PART_FUSE)

## Der Griff: das Bedienelement rückt eine Spur nach vorn. Nur der Wechsel fährt.
func _nudge(host: Node3D, on: bool) -> void:
	if host == null or not is_instance_valid(host):
		return
	var wanted := -MAST_HALF.x - (HOVER_NUDGE if on else 0.0)
	if is_equal_approx(host.position.x, wanted):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(host, "position:x", wanted, HOVER_TIME)

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
	mesh.radial_segments = 10
	mesh.rings = 0
	var instance := MeshInstance3D.new()
	instance.name = cylinder_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(instance)
	return instance
