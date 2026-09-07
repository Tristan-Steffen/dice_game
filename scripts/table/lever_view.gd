class_name LeverView
extends Node3D
## Der KIPPHEBEL als eigener Baustein (2026-09-07 aus ChargingColumnView
## herausgelöst - die Säule baut ihre beiden Hebel seither hiermit): Fassung,
## Achse, Stange, Knauf. Die Ruhelage ist WAAGERECHT, ein Wurf kippt um TILT und
## fällt von selbst zurück; der Endzustand steht vor der Fahrt.
##
## EINSEITIG (die Ladesäule) sitzt EIN Knauf vor der Achse, und ein Pick-Körper
## deckt ihn. ZWEISEITIG (der Paternoster) sitzt je einer beidseits, und jede
## Seite trägt ihren EIGENEN Pick-Körper - nur so weiß der Strahl, in welche
## Richtung gekippt wird; senkrecht gestapelte Zonen fielen an der 15°-Kamera in
## einen Fleck zusammen.
##
## Er bucht NICHTS und rechnet nichts nach: `armed` wird ihm gemeldet, `press`
## meldet `page_requested(+1/-1)` zurück. Ein blinder Hebel steht grau und schaltet
## seine Kollision ab, fängt den Strahl also gar nicht erst.

## Der Spieler hat gekippt: +1 = nach OBEN, -1 = nach UNTEN.
signal page_requested(delta: int)

## Dieselbe Pick-Ebene wie die Ladesäule - die TEILE heißen verschieden, und wer
## fragt, prüft den Namen (part_of).
const PICK_LAYER := 256

const PART_NONE := ""

## Ein Kipphebel: Fassung, Griffstange, Knauf.
const SOCKET_SIZE := Vector3(0.18, 0.34, 0.34)
const ARM_LENGTH := 0.52
const ARM_RADIUS := 0.05
const KNOB_RADIUS := 0.13
## Ruhe waagerecht, geworfen um diesen Winkel gekippt.
const TILT := 0.62
const TIME := 0.13
const HOLD := 0.35

## Der Griff hebt den Hebel eine Spur aus seiner Fläche (lokal -X).
const NUDGE := 0.09
const NUDGE_TIME := 0.13
const HOVER_GAIN := 2.1

const METAL_ALBEDO := Color(0.34, 0.37, 0.44)
const DEAD_ALBEDO := Color(0.06, 0.058, 0.086)
const LIVE_TINT := CasinoStyle.GOLD_INTENSE
const DEAD_TINT := CasinoStyle.MUTED
const LIVE_ENERGY := 0.85
const DEAD_ENERGY := 0.12
## Die FASSUNG ist Blech wie der Mast, an dem der Hebel sitzt - sie lebt nicht mit.
const SOCKET_ALBEDO := Color(0.085, 0.082, 0.118)
const SOCKET_EMISSION := Color(0.18, 0.20, 0.32)
const SOCKET_ENERGY := 0.35

## Das SCHILD am Hebel (nur wer eines bestellt, bekommt eines): eine flache Platte
## an seiner Bildschirm-rechten Flanke mit EINER Zeile darauf, in Tisch-Leserichtung.
## Die Ladesäule behält ihre eigenen Preisschilder - die hängen am Körper, nicht am
## Hebel, und teilen EINEN Schriftgrad über alle drei Bedienelemente.
const SIGN_SPAN := Vector2(0.7, 2.4)
const SIGN_HEIGHT := 0.05
const SIGN_FONT := 64
## Die längste Aufschrift ("Etage 5/5") - an ihr hängt der Schriftgrad.
const SIGN_CHARS := 9.5
## Das Blech ist DUNKEL wie jedes Schild des Tisches, die Schrift trägt es - ein
## volles Gold läse lauter als der Hebel selbst.
const SIGN_ENERGY := 0.30
const SIGN_FLASH_ENERGY := 3.6
const SIGN_FLASH_TIME := 0.45

## Auf welcher Seite der Achse der Knauf sitzt, der beim Kipp nach OBEN steigt:
## einseitig ist es der einzige (vor der Achse, lokal -X), zweiseitig der hintere.
var _up_side := -1.0
var _two_way := false
var _part_up := PART_NONE
var _part_down := PART_NONE

var _rig: Node3D
var _pivot: Node3D
var _material: StandardMaterial3D
var _bodies: Array[StaticBody3D] = []
var _sign: Label3D
var _sign_material: StandardMaterial3D
var _armed := false
var _hovered := PART_NONE
var _throw: Tween
var _flash: Tween

func _init(lever_name := "Lever") -> void:
	name = lever_name

## Welches Teil gehört zu diesem Kollisions-Körper ("" = keines)?
static func part_of(collider: Object) -> String:
	var body := collider as Node
	if body == null or not body.has_meta("part"):
		return PART_NONE
	return str(body.get_meta("part"))

## Baut den Hebel (idempotent - dieselben Teile bauen nichts neu). Ohne part_down
## ist er EINSEITIG: ein Knauf vor der Achse, ein Pick-Körper.
func setup(part_up: String, part_down := PART_NONE) -> void:
	if _part_up == part_up and _part_down == part_down and _rig != null:
		return
	_part_up = part_up
	_part_down = part_down
	_two_way = part_down != PART_NONE
	_up_side = 1.0 if _two_way else -1.0
	_build()

## Die Richtung eines Teils (0 = keines von beiden).
func direction_of(part: String) -> int:
	if part != PART_NONE and part == _part_up:
		return 1
	if part != PART_NONE and part == _part_down:
		return -1
	return 0

## Scharf heißt bedienbar: grau schaltet auch die Kollision ab.
func set_armed(on: bool) -> void:
	if _armed == on:
		return
	_armed = on
	if not on:
		_hovered = PART_NONE
	_write_live()

func armed() -> bool:
	return _armed

## Der Zeiger liegt auf einem Teil (PART_NONE = auf keinem). Ein blinder Hebel
## antwortet nicht.
func set_hovered(part: String) -> void:
	if not _armed or direction_of(part) == 0:
		part = PART_NONE
	if _hovered == part:
		return
	_hovered = part
	_write_live()

func hovered() -> String:
	return _hovered

## Der Druck auf ein Teil (true = er hat gemeldet). Blind meldet er nichts und
## rührt sich nicht.
func press(part: String) -> bool:
	var delta := direction_of(part)
	if not _armed or delta == 0:
		return false
	flip(delta > 0)
	page_requested.emit(delta)
	return true

## Der Wurf: der Hebel schlägt um und fällt in die Ruhelage zurück. ENDZUSTAND
## ZUERST - die Ruhelage steht, bevor die Fahrt beginnt, und ohne Baum (kopflos)
## bleibt es bei ihr.
func flip(up: bool) -> void:
	if _pivot == null or not is_instance_valid(_pivot):
		return
	if _throw != null and _throw.is_valid():
		_throw.kill()
	_pivot.rotation.z = 0.0
	if not is_inside_tree():
		return
	var tilt := TILT * _up_side * (1.0 if up else -1.0)
	_throw = create_tween()
	_throw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_throw.tween_property(_pivot, "rotation:z", tilt, TIME)
	_throw.tween_interval(HOLD)
	_throw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_throw.tween_property(_pivot, "rotation:z", 0.0, TIME * 1.6)

## Der Kippwinkel gerade (0 = Ruhelage).
func tilt() -> float:
	return _pivot.rotation.z if _pivot != null and is_instance_valid(_pivot) else 0.0

## Fängt dieses Teil den Strahl?
func pick_armed(part: String) -> bool:
	for body in _bodies:
		if is_instance_valid(body) and str(body.get_meta("part", "")) == part:
			return body.collision_layer == PICK_LAYER
	return false

# --- Das SCHILD ------------------------------------------------------------------

## Bestellt (und schreibt) die Aufschrift. Wer keine bestellt, bekommt kein Schild.
func set_sign(text: String) -> void:
	if _sign == null or not is_instance_valid(_sign):
		_build_sign()
	if _sign.text == text:
		return
	_sign.text = text
	_sign.pixel_size = SIGN_SPAN.y / (SIGN_CHARS * float(SIGN_FONT) * 0.62)

func sign_text() -> String:
	return _sign.text if _sign != null and is_instance_valid(_sign) else ""

## Wo sein Schild steht (ohne Schild: der Hebel selbst) - dorthin endet das Licht
## einer Lieferung, die niemand sieht.
func sign_point() -> Vector3:
	var host := get_node_or_null("Schild") as Node3D
	return host.global_position if host != null else global_position

## Das Schild blitzt auf - so quittiert es eine Lieferung, die auf einer PARKENDEN
## Etage gelandet ist (eine Maschine, die keiner sieht, hat nicht gespielt).
func flash_sign() -> void:
	if _sign_material == null:
		return
	if _flash != null and _flash.is_valid():
		_flash.kill()
	_sign_material.emission_energy_multiplier = SIGN_FLASH_ENERGY
	if not is_inside_tree():
		_sign_material.emission_energy_multiplier = SIGN_ENERGY
		return
	_flash = create_tween()
	_flash.tween_method(func(value: float) -> void:
		_sign_material.emission_energy_multiplier = value,
		SIGN_FLASH_ENERGY, SIGN_ENERGY, SIGN_FLASH_TIME)

# --- Aufbau ------------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_bodies.clear()
	_sign = null
	_sign_material = null
	_hovered = PART_NONE
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_material = _metal(METAL_ALBEDO, LIVE_TINT, LIVE_ENERGY)
	_box("Fassung", SOCKET_SIZE, Vector3(-SOCKET_SIZE.x * 0.5, 0.0, 0.0),
		_metal(SOCKET_ALBEDO, SOCKET_EMISSION, SOCKET_ENERGY), _rig)
	_pivot = Node3D.new()
	_pivot.name = "Achse"
	_pivot.position = Vector3(-SOCKET_SIZE.x, 0.0, 0.0)
	_rig.add_child(_pivot)
	# Die Stange liegt entlang der lokalen X-Achse; eine Drehung um Z kippt ihre
	# Enden also hinauf und hinab.
	var sides := PackedFloat32Array([1.0, -1.0]) if _two_way \
		else PackedFloat32Array([-1.0])
	var span := ARM_LENGTH * (2.0 if _two_way else 1.0)
	var arm := _cylinder("Stange", ARM_RADIUS, span, _material, _pivot)
	arm.rotation = Vector3(0.0, 0.0, PI * 0.5)
	arm.position = Vector3(0.0 if _two_way else -ARM_LENGTH * 0.5, 0.0, 0.0)
	for side in sides:
		var knob := MeshInstance3D.new()
		knob.name = "Knauf%s" % ("A" if side > 0.0 else "B")
		var sphere := SphereMesh.new()
		sphere.radius = KNOB_RADIUS
		sphere.height = KNOB_RADIUS * 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		knob.mesh = sphere
		knob.material_override = _material
		knob.position = Vector3(side * ARM_LENGTH, 0.0, 0.0)
		knob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pivot.add_child(knob)
		_bodies.append(_pick_body(_part_up if side == _up_side else _part_down, side))
	_write_live()

## Je Seite ein Pick-Körper über ihrer Hälfte der Stange - zweiseitig liegen die
## beiden in der TISCHEBENE nebeneinander, also trennt der Strahl sie auch an der
## flach schauenden Station.
func _pick_body(part: String, side: float) -> StaticBody3D:
	var reach := ARM_LENGTH + KNOB_RADIUS
	var body := StaticBody3D.new()
	body.name = "Griff_%s" % part
	body.collision_layer = PICK_LAYER
	body.collision_mask = 0
	body.position = Vector3(-SOCKET_SIZE.x + side * reach * 0.5, 0.0, 0.0)
	body.set_meta("part", part)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(reach, SOCKET_SIZE.y, SOCKET_SIZE.z)
	shape.shape = box
	body.add_child(shape)
	_rig.add_child(body)
	return body

## Das Schild: eine flache Platte an der Bildschirm-rechten Flanke (+Z), die Zeile
## flach in Tisch-Leserichtung - der Hebel steht auf dem Filz, geschaut wird von oben.
func _build_sign() -> void:
	var host := Node3D.new()
	host.name = "Schild"
	host.position = Vector3(-ARM_LENGTH * 0.5, 0.0, SOCKET_SIZE.z * 0.5 + SIGN_SPAN.y * 0.5)
	add_child(host)
	_sign_material = _metal(DEAD_ALBEDO, SOCKET_EMISSION, SIGN_ENERGY)
	_box("Blech", Vector3(SIGN_SPAN.x, SIGN_HEIGHT, SIGN_SPAN.y), Vector3.ZERO,
		_sign_material, host)
	var label := Label3D.new()
	label.name = "Aufschrift"
	label.font_size = SIGN_FONT
	label.transform.basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	label.position = Vector3(0.0, SIGN_HEIGHT * 0.5 + 0.02, 0.0)
	label.outline_size = 14
	label.outline_modulate = Color(0.03, 0.03, 0.05)
	host.add_child(label)
	_sign = label

## Der EINE Schreiber der Bedienbarkeit: grau heißt tot, und tot klickt nicht.
func _write_live() -> void:
	if _material == null:
		return
	_material.albedo_color = METAL_ALBEDO if _armed else DEAD_ALBEDO
	_material.emission = LIVE_TINT if _armed else DEAD_TINT
	_material.emission_energy_multiplier = \
		LIVE_ENERGY * (HOVER_GAIN if _hovered != PART_NONE else 1.0) if _armed \
		else DEAD_ENERGY
	for body in _bodies:
		if is_instance_valid(body):
			body.collision_layer = PICK_LAYER if _armed else 0
	_nudge(_hovered != PART_NONE)

## Der Griff: der Hebel rückt eine Spur aus seiner Fläche. Nur der Wechsel fährt.
func _nudge(on: bool) -> void:
	if _rig == null or not is_instance_valid(_rig):
		return
	var wanted := -NUDGE if on else 0.0
	if is_equal_approx(_rig.position.x, wanted):
		return
	if not is_inside_tree():
		_rig.position.x = wanted
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rig, "position:x", wanted, NUDGE_TIME)

# --- Bausteine ---------------------------------------------------------------------

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
