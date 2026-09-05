class_name TowerView
extends Node3D
## DER TURM der Werkstatt (Welle X, 2026-09-05): ein gerades Gestell aus sechs
## ETAGEN auf dem Filz. Etage 0 ist die UNTERSTE und wirkt zuerst - die Reihenfolge
## IST die Höhe, und das DURCHLICHT steigt darum von unten. In jeder Etage LIEGT
## eine Karte flach, ihre Kontakte nach Bild-RECHTS in der KONTAKTLEISTE; links ist
## der Turm offen, dort fährt die Karte unter dem Zeiger heraus.
##
## Die Maße kommen von außen (scene_root rechnet die gemeldeten Rechtecke in Welt).
## seat() ist idempotent - Endzustand zuerst, es gibt keinen Tween außer dem Licht.

## Eine ETAGE ist eine Kartendicke plus ihr Boden - so steht jede Karte frei.
const CARD_THICKNESS := DataCellView.DEPTH * PackDrawerView.CASSETTE_SCALE
const FLOOR_PLATE := 0.06
const FLOOR_PITCH := CARD_THICKNESS + FLOOR_PLATE
## Die KAMMER am Fuß: der Sockel, aus dem das Licht steigt. Ihre Oberseite IST der
## Boden der untersten Etage.
const CHAMBER_HEIGHT := FLOOR_PITCH * 0.7
## Die Karte liegt eine Spur über dem Etagenboden (koplanar stritten sie im
## Tiefenpuffer).
const FLOOR_PROUD := 0.006

## Das Blech des Gestells und die goldene KONTAKTLEISTE (der Finnen-Ton).
const FRAME_ALBEDO := Color(0.22, 0.212, 0.285)
const FRAME_EMISSION := Color(0.46, 0.48, 0.66)
const FRAME_EMISSION_ENERGY := 0.42
const BAR_ALBEDO := Color(0.26, 0.22, 0.13)
const BAR_EMISSION := Color(0.92, 0.74, 0.34)
const BAR_EMISSION_ENERGY := 0.55
## Der MUND einer Etage in der Leiste: die Kontaktzunge, in die der Kartenfuß rastet.
const MOUTH_EMISSION_ENERGY := 1.1
const MOUTH_FLASH_ENERGY := 3.6
const MOUTH_FLASH_TIME := 0.3
## Tiefe der KONTAKTLEISTE als Anteil des Fußabdrucks längs (Welt-Z): sie steht IM
## gemeldeten Rechteck, am Bild-rechten Rand - der Rest gehört der Karte. Das
## Fenster schneidet seinen Turm-Platz an derselben Zahl.
const BAR_SHARE := 0.07
## Ein Etagenboden ist kein Blech, sondern ZWEI SCHIENEN an den Längskanten: nur so
## sieht man von oben durch den Turm hindurch und das DURCHLICHT in ihm.
const RAIL_SHARE := 0.13

## Wie weit eine NICHT eingerastete Karte nach Bild-links herausgezogen liegt -
## Anteil ihrer LÄNGE -, dazu der BUCHRÜCKEN-Versatz je Etage (unten am weitesten
## heraus) und der HOVER, der sie ganz herauszieht. Die EINE Quelle: der Körper
## fährt danach, das Fenster schneidet seine Auswurf-Bahn danach.
const UNLATCHED_PULL := 0.25
const PEEK_SHARE := 0.045
const HOVER_SLIDE := 0.75

## Der Ruhe-Versatz der Karte von Etage index, als Anteil ihrer Länge. count ist
## die ETAGENZAHL des Turms, nie die Zahl der gesteckten Karten - sonst rückten
## alle gemeinsam heraus, sobald eine dazukommt.
static func pull_share(index: int, count: int) -> float:
	return UNLATCHED_PULL + PEEK_SHARE * float(maxi(count - 1 - index, 0))

## Und wie weit die unterste unter dem Zeiger insgesamt herausfährt - so breit ist
## die AUSWURF-BAHN links des Turms.
static func eject_share(count: int) -> float:
	return pull_share(0, count) + HOVER_SLIDE

## Die KAMMER glimmt, bevor sie zündet, und die LICHT-EBENE ist ein additives Quad
## in Kartengröße.
const CHAMBER_EMISSION := Color(0.55, 0.91, 0.99)
const CHAMBER_EMISSION_ENERGY := 0.5
## GEMESSEN am dunklen Filz: darüber überstrahlt die Ebene das Licht-Netz auf ihr.
const LIGHT_ALPHA := 0.30
const LIGHT_ENERGY := 1.25

var _frame_material: StandardMaterial3D
var _bar_material: StandardMaterial3D
var _chamber_material: StandardMaterial3D
var _light_material: StandardMaterial3D

var _count := 0
var _span := Vector2.ONE
var _seat := Vector3.ZERO
var _chamber: Node3D
var _floors: Array[Node3D] = []
var _mouths: Array[MeshInstance3D] = []
var _mouth_flashes: Array[Tween] = []
## Der LICHT-Halter: die Ebene hängt daran, und mit ihr reitet das Licht-Netz.
var _light: Node3D
var _light_plane: MeshInstance3D
var _light_ride: Tween

func _init() -> void:
	name = "Tower"

## Höhe des Etagenbodens index über dem Glas (0 = unten).
static func floor_top(index: int) -> float:
	return CHAMBER_HEIGHT + FLOOR_PITCH * float(maxi(index, 0))

## ... und die Höhe, auf der die KARTE dieser Etage LIEGT.
static func floor_seat(index: int) -> float:
	return floor_top(index) + FLOOR_PROUD

## Die Höhe des ganzen Turms bei count Etagen.
static func tower_height(count: int) -> float:
	return floor_top(maxi(count, 1) - 1) + CARD_THICKNESS

## Der TURM HART setzen: at = Glaspunkt seiner Mitte, span = Weltmaß seines
## Fußabdrucks (x quer, y längs = Welt-Z), count = Etagen. Idempotent.
func seat(at: Vector3, span: Vector2, count: int) -> void:
	_ensure_materials()
	_seat = at
	_span = Vector2(maxf(span.x, 0.01), maxf(span.y, 0.01))
	_count = maxi(count, 1)
	for old in _floors + ([_chamber] if _chamber != null else []):
		if is_instance_valid(old):
			remove_child(old)
			old.queue_free()
	_floors.clear()
	_mouths.clear()
	_mouth_flashes.clear()
	_build_chamber()
	for i in _count:
		_floors.append(_build_floor(i))
	_ensure_light()
	_light.global_position = Vector3(_seat.x, _seat.y + chamber_top(), _seat.z)

func floor_count() -> int:
	return _count

## Tiefe der Kontaktleiste in Welt - so weit weicht der Kartenplatz nach Bild-links.
func bar_depth() -> float:
	return _span.y * BAR_SHARE

## Der Weltpunkt, auf dem die Karte der Etage index LIEGT (ZERO = keine solche).
## Sie liegt vor der Leiste, nicht in ihr.
func floor_point(index: int) -> Vector3:
	if index < 0 or index >= _count:
		return Vector3.ZERO
	return _seat + Vector3(0.0, floor_seat(index), -bar_depth() * 0.5)

## Die Oberkante der KAMMER - dort zündet das Licht.
func chamber_top() -> float:
	return CHAMBER_HEIGHT

## Der Weltpunkt des Turmkopfs (Oberkante der obersten Etage).
func top_point() -> Vector3:
	return _seat + Vector3.UP * tower_height(_count)

## Der Fußabdruck in Welt, wie er gesetzt wurde.
func span() -> Vector2:
	return _span

# --- DAS DURCHLICHT ------------------------------------------------------------

## Das Licht ZÜNDET in der Kammer, im Ton der Serie.
func light_on(accent: Color) -> void:
	_ensure_light()
	if _light_material != null:
		_light_material.albedo_color = Color(accent.r * LIGHT_ENERGY,
			accent.g * LIGHT_ENERGY, accent.b * LIGHT_ENERGY, LIGHT_ALPHA)
	_light.visible = true
	light_hard(_seat.y + chamber_top())

## Die Licht-Ebene STEIGT auf eine Welt-Höhe. Endzustand zuerst: bei time <= 0 steht
## sie sofort dort.
func light_to(height: float, time: float) -> void:
	_ensure_light()
	if time <= 0.0:
		light_hard(height)
		return
	_kill(_light_ride)
	_light_ride = create_tween()
	_light_ride.tween_property(_light, "global_position",
		Vector3(_seat.x, height, _seat.z), time)
	_light_ride.tween_callback(func() -> void: light_hard(height))

func light_hard(height: float) -> void:
	_ensure_light()
	_kill(_light_ride)
	_light.global_position = Vector3(_seat.x, height, _seat.z)

func light_height() -> float:
	return _light.global_position.y if _light != null and is_instance_valid(_light) \
		else 0.0

func lighting() -> bool:
	return _light != null and is_instance_valid(_light) and _light.visible

## Der EINE Aufräum-Pfad des Lichts: Fahrt aus, Ebene fort.
func light_off() -> void:
	_kill(_light_ride)
	if _light != null and is_instance_valid(_light):
		_light.visible = false
		_light.global_position = Vector3(_seat.x, _seat.y + chamber_top(), _seat.z)

## Ein Reiter auf der Licht-Ebene (das LICHT-NETZ): er hängt daran und fährt mit.
func attach_to_light(rider: Node3D) -> void:
	_ensure_light()
	if rider.get_parent() == _light:
		return
	if rider.get_parent() != null:
		rider.get_parent().remove_child(rider)
	_light.add_child(rider)

## Der MUND-BLITZ beim Einrasten der Karte von Etage index.
func latch_flash(index: int) -> void:
	if index < 0 or index >= _mouths.size():
		return
	var mouth := _mouths[index]
	if not is_instance_valid(mouth):
		return
	var material := mouth.material_override as StandardMaterial3D
	if material == null:
		return
	_kill(_mouth_flashes[index])
	material.emission_energy_multiplier = MOUTH_FLASH_ENERGY
	var flash := create_tween()
	_mouth_flashes[index] = flash
	flash.tween_method(func(value: float) -> void:
		material.emission_energy_multiplier = value,
		MOUTH_FLASH_ENERGY, MOUTH_EMISSION_ENERGY, MOUTH_FLASH_TIME)

# --- Aufbau ---------------------------------------------------------------------

func _build_chamber() -> void:
	var host := Node3D.new()
	host.name = "Chamber"
	add_child(host)
	_chamber = host
	var base := MeshInstance3D.new()
	base.name = "Base"
	var box := BoxMesh.new()
	box.size = Vector3(_span.x, CHAMBER_HEIGHT, _span.y)
	base.mesh = box
	base.material_override = _frame_material
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	base.position = Vector3(_seat.x, _seat.y + CHAMBER_HEIGHT * 0.5, _seat.z)
	host.add_child(base)
	# Der SCHACHT: ein glimmendes Feld in der Kammer-Oberseite, aus dem das Licht steigt.
	var vent := MeshInstance3D.new()
	vent.name = "Vent"
	var quad := QuadMesh.new()
	quad.size = Vector2(_span.x * 0.7, _span.y * 0.7)
	vent.mesh = quad
	vent.material_override = _chamber_material
	vent.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	vent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vent.position = Vector3(_seat.x, _seat.y + CHAMBER_HEIGHT + FLOOR_PROUD, _seat.z)
	host.add_child(vent)
	# Die KONTAKTLEISTE: die Rückwand am Bild-rechten Rand (Welt +Z), in die der
	# Kartenfuß rastet - links bleibt der Turm offen.
	var bar := MeshInstance3D.new()
	bar.name = "ContactBar"
	var wall := BoxMesh.new()
	var depth := bar_depth()
	wall.size = Vector3(_span.x, tower_height(_count), depth)
	bar.mesh = wall
	bar.material_override = _bar_material
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.position = Vector3(_seat.x, _seat.y + tower_height(_count) * 0.5,
		_seat.z + _span.y * 0.5 - depth * 0.5)
	host.add_child(bar)

func _build_floor(index: int) -> Node3D:
	var host := Node3D.new()
	host.name = "Floor%d" % (index + 1)
	add_child(host)
	# Die unterste Etage steht auf der Kammer, jede weitere auf ZWEI SCHIENEN an den
	# Längskanten - dazwischen ist der Turm offen, und das Licht steigt sichtbar
	# hindurch.
	if index > 0:
		var rail_width := _span.x * RAIL_SHARE
		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			rail.name = "Rail%s" % ("A" if side < 0.0 else "B")
			var box := BoxMesh.new()
			box.size = Vector3(rail_width, FLOOR_PLATE, _span.y)
			rail.mesh = box
			rail.material_override = _frame_material
			rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rail.position = Vector3(
				_seat.x + side * (_span.x - rail_width) * 0.5,
				_seat.y + floor_top(index) - FLOOR_PLATE * 0.5, _seat.z)
			host.add_child(rail)
	var mouth := MeshInstance3D.new()
	mouth.name = "Mouth"
	var tongue := BoxMesh.new()
	var depth := bar_depth()
	tongue.size = Vector3(_span.x * 0.6, CARD_THICKNESS * 0.55, depth * 0.6)
	mouth.mesh = tongue
	var material := StandardMaterial3D.new()
	material.albedo_color = BAR_ALBEDO
	material.metallic = 0.6
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = BAR_EMISSION
	material.emission_energy_multiplier = MOUTH_EMISSION_ENERGY
	mouth.material_override = material
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mouth.position = Vector3(_seat.x,
		_seat.y + floor_seat(index) + CARD_THICKNESS * 0.5,
		_seat.z + _span.y * 0.5 - depth * 1.2)
	host.add_child(mouth)
	_mouths.append(mouth)
	_mouth_flashes.append(null)
	return host

func _ensure_light() -> void:
	if _light != null and is_instance_valid(_light):
		return
	_light = Node3D.new()
	_light.name = "Light"
	_light.visible = false
	add_child(_light)
	_light_material = StandardMaterial3D.new()
	_light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_light_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_light_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# LICHT liest IMMER: die noch nicht gelesenen Karten liegen über der Ebene und
	# verdeckten sie sonst von oben.
	_light_material.no_depth_test = true
	_light_material.render_priority = DataCellView.PRIORITY_NET
	_light_material.albedo_color = Color(CHAMBER_EMISSION.r * LIGHT_ENERGY,
		CHAMBER_EMISSION.g * LIGHT_ENERGY, CHAMBER_EMISSION.b * LIGHT_ENERGY,
		LIGHT_ALPHA)
	_light_plane = MeshInstance3D.new()
	_light_plane.name = "Plane"
	var quad := QuadMesh.new()
	quad.size = _span
	_light_plane.mesh = quad
	_light_plane.material_override = _light_material
	_light_plane.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_light_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light.add_child(_light_plane)

func _ensure_materials() -> void:
	if _frame_material != null:
		return
	_frame_material = StandardMaterial3D.new()
	_frame_material.albedo_color = FRAME_ALBEDO
	_frame_material.metallic = 0.35
	_frame_material.roughness = 0.55
	_frame_material.emission_enabled = true
	_frame_material.emission = FRAME_EMISSION
	_frame_material.emission_energy_multiplier = FRAME_EMISSION_ENERGY
	_bar_material = StandardMaterial3D.new()
	_bar_material.albedo_color = BAR_ALBEDO
	_bar_material.metallic = 0.6
	_bar_material.roughness = 0.35
	_bar_material.emission_enabled = true
	_bar_material.emission = BAR_EMISSION
	_bar_material.emission_energy_multiplier = BAR_EMISSION_ENERGY
	_chamber_material = StandardMaterial3D.new()
	_chamber_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_chamber_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_chamber_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_chamber_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_chamber_material.albedo_color = Color(
		CHAMBER_EMISSION.r * CHAMBER_EMISSION_ENERGY,
		CHAMBER_EMISSION.g * CHAMBER_EMISSION_ENERGY,
		CHAMBER_EMISSION.b * CHAMBER_EMISSION_ENERGY, 0.4)

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
