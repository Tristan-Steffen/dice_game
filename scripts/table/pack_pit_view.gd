class_name PackPitView
extends Node3D
## Die GRUBE des MAGAZINS: eine echte Vertiefung in der Schürze der Werkbank, in
## der die Kassetten versenkt STEHEN. Das Loch selbst schneidet der Shader
## (screen_glass.pit_rect verwirft die Anzeige, table_ground den Filzboden
## dahinter) - dieser Körper ist, was man durch das Loch sieht: vier nach innen
## blickende Wände, ein Boden und ein Kragen, der die harte Schnittkante deckt.
## Rein per Code gebaut wie DataCellView und CapacitorBankView - kein .tscn.
## Das Magazin ist ihr EINZIGER Kunde: die Verkaufs-Auslagen stehen flächig auf
## dem Tisch, es gibt keine zweite Grube und keine Tore in dieser hier.
## Drei Tischregeln gelten auch hier: nur EMISSION (die Bodenkacheln vertragen
## 16 Lichter), das Ruhelicht bleibt unter Rune.IDLE_CEILING, und gespiegelt wird
## sie NICHT - ein Loch hat kein Spiegelbild.
## Die Sorte gehört den Kassetten, nie der Grube: ihre Auskleidung
## (pit_lining.gdshader) ist ARCHIV - Samtboden, dunkles Metall, eine Neon-Fuge.

## Wandstärke und Bodenplatte in Weltmaß (die Grube ist so tief wie eine stehende
## Kassette, das setzt der Aufrufer).
const WALL := 0.10
const FLOOR := 0.08

## Der Kragen: eine schmale Platte DIREKT UNTER dem Glas, die die Schnittkante
## des Lochs von innen deckt. Unter dem Glas, nicht darüber - ein aufgesetzter
## Wulst verdeckte bei 15° die vorderste Kassettenreihe.
const RIM_IN := 0.16
const RIM_OUT := 0.34
const RIM_H := 0.05
## Er hängt eine Spur TIEFER als das Glas: läge seine Deckfläche darauf, kämpften
## die beiden im Tiefenpuffer und legten einen hellen Rahmen rings um die Grube.
const RIM_SINK := 0.03
## Aus demselben Grund enden auch die WÄNDE unter der Glasebene: ihre Deckflächen
## lagen exakt darauf und flimmerten als Grubenkontur durch die Anzeige. Der Kragen
## deckt sie ohnehin - er greift weiter über die Kante, als die Wand dick ist.
const WALL_SINK := RIM_SINK

## Lichtsaum knapp unter dem Kragen: ohne ihn verschluckt der dunkle Raum die
## Wände, und die Grube läse sich als schwarzes Rechteck statt als Vertiefung.
## In die Grube fällt KEIN Szenenlicht - sie ist ein Loch im Tisch. Alles, was
## ihre Wände zeichnet, ist ihre eigene Emission; entsprechend hoch stehen die
## Energien, ihr Produkt mit der Farbe bleibt trotzdem unter Rune.IDLE_CEILING.
const GLOW_H := 0.06
const GLOW_DROP := 0.10
const GLOW_COLOR := Color(0.44, 0.48, 0.66)
const GLOW_ENERGY := 1.4

const WALL_ALBEDO := Color(0.062, 0.058, 0.086)
const FLOOR_ALBEDO := Color(0.046, 0.042, 0.066)
## Grundhelligkeit der Auskleidung. Sie liegt bewusst knapp unter dem Filz
## ringsum: eine Grube ist dunkler als der Tisch, aber kein Loch ins Nichts.
## Ihr Produkt mit der Farbe bleibt weit unter Rune.IDLE_CEILING - was hier
## blühte, nähme der Ware die Show.
const WALL_FIELD_ENERGY := 2.1
const FLOOR_FIELD_ENERGY := 2.4
const SEAM_ENERGY := 0.55
## Paneelbreite als Anteil der LÄNGSTEN Grubenkante: an der kurzen gemessen
## bekäme eine flache, breite Grube (das Magazin) ein dichtes Streifenmuster auf
## ihrer langen Wand statt weniger ruhiger Platten.
const PANEL_SHARE := 0.22
const PANEL_MIN := 0.9
## Deckel der Emission: darüber laufen die drei Kanäle zu Weiß zusammen und aus
## der Farbe wird eine helle Fläche.
const EMISSION_CAP := 1.45

const RIM_ALBEDO := Color(0.20, 0.195, 0.245)
const RIM_EMISSION := Color(0.42, 0.44, 0.58)
const RIM_EMISSION_ENERGY := 0.95

## Die vier Wände als Nummern; jede trägt ihre eigene Gierung, mit der dieselbe
## Rechnung sie in die Waagerechte dreht (wall_yaw). Ohne diese eine Drehung
## stünde der Wandbau viermal im Code.
const WALL_Z_MINUS := 0
const WALL_Z_PLUS := 1
const WALL_X_MINUS := 2
const WALL_X_PLUS := 3
const WALLS := [WALL_X_PLUS, WALL_X_MINUS, WALL_Z_PLUS, WALL_Z_MINUS]
const WALL_NAMES := ["WallZMinus", "WallZPlus", "WallXMinus", "WallXPlus"]

var _wall_material: ShaderMaterial
var _floor_material: ShaderMaterial
var _rim_material: StandardMaterial3D
var _glow_material: StandardMaterial3D

## Zuletzt gestellte Maße - der Abgleich stellt idempotent nach.
var center := Vector3.ZERO
var half := Vector2.ZERO
var depth := 0.0

## Trimmung der Grube - VOR dem ersten setup zu setzen (die Materialien entstehen
## dort). Die Vorgaben SIND das Magazin.
var wall := WALL
var floor_plate := FLOOR
var glow_color := GLOW_COLOR
var glow_energy := GLOW_ENERGY

func _init(pit_name := "PackPit") -> void:
	name = pit_name

## Einziger Eingang: Mitte auf dem Glas, halbe Ausdehnung in Welt-X/Welt-Z und
## die Tiefe unter dem Glas. Baut die Grube neu - sie steht selten um.
func setup(at: Vector3, half_extents: Vector2, pit_depth: float) -> void:
	center = at
	half = Vector2(maxf(half_extents.x, 0.01), maxf(half_extents.y, 0.01))
	depth = maxf(pit_depth, 0.05)
	global_position = center
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if _wall_material == null:
		_build_materials()
	_tune_lining()
	_build_body()

## Die Welt-XZ-Grenzen des Lochs (der Bodenshader blendet genau sie aus).
func bounds_min() -> Vector2:
	return Vector2(center.x - half.x, center.z - half.y)

func bounds_max() -> Vector2:
	return Vector2(center.x + half.x, center.z + half.y)

## Die Gierung, mit der eine Wand in die Rechnung gedreht wird: danach zeigt
## lokal +Z ins Innere der Grube und lokal +X längs der Wand.
static func wall_yaw(wall_id: int) -> float:
	match wall_id:
		WALL_Z_PLUS: return PI
		WALL_X_MINUS: return PI * 0.5
		WALL_X_PLUS: return -PI * 0.5
		_: return 0.0

## Die Innenrichtung einer Wand (waagerechter Einheitsvektor).
static func wall_inward(wall_id: int) -> Vector3:
	return Basis(Vector3.UP, wall_yaw(wall_id)) * Vector3.BACK

## Ihre Längsrichtung.
static func wall_axis(wall_id: int) -> Vector3:
	return Basis(Vector3.UP, wall_yaw(wall_id)) * Vector3.RIGHT

## Abstand der Grubenmitte zur INNENFLÄCHE einer Wand.
func _wall_reach(wall_id: int) -> float:
	return half.x if wall_id == WALL_X_MINUS or wall_id == WALL_X_PLUS else half.y

## Länge des Wandbalkens längs seiner Richtung. Die X-Wände greifen um die
## Wandstärke über, damit die vier Ecken geschlossen sind.
func _wall_run(wall_id: int) -> float:
	if wall_id == WALL_X_MINUS or wall_id == WALL_X_PLUS:
		return half.y * 2.0 + wall * 2.0
	return half.x * 2.0

func _build_materials() -> void:
	var lining: Shader = load("res://assets/shaders/pit_lining.gdshader")
	_wall_material = ShaderMaterial.new()
	_wall_material.shader = lining
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = lining
	_rim_material = _metal(RIM_ALBEDO, RIM_EMISSION, RIM_EMISSION_ENERGY)
	_glow_material = _metal(glow_color * 0.3, glow_color, glow_energy)

## Die Auskleidung misst sich an der Grube, in der sie steckt - Paneelbreite und
## Tiefenverlauf sind gerechnet, nicht getippt.
func _tune_lining() -> void:
	var panel := maxf(maxf(half.x, half.y) * 2.0 * PANEL_SHARE, PANEL_MIN)
	for pair: Array in [[_wall_material, 0.0], [_floor_material, 1.0]]:
		var material: ShaderMaterial = pair[0]
		material.set_shader_parameter("velvet", pair[1])
		material.set_shader_parameter("seam_color", glow_color)
		material.set_shader_parameter("seam_energy", SEAM_ENERGY)
		material.set_shader_parameter("panel_width", panel)
		material.set_shader_parameter("pit_depth", depth)
		material.set_shader_parameter("glass_y", center.y)
		material.set_shader_parameter("field_center", Vector2(center.x, center.z))
		material.set_shader_parameter("field_half", half)
		material.set_shader_parameter("emission_cap", EMISSION_CAP)
	_wall_material.set_shader_parameter("base_color", WALL_ALBEDO)
	_wall_material.set_shader_parameter("field_energy", WALL_FIELD_ENERGY)
	_floor_material.set_shader_parameter("base_color", FLOOR_ALBEDO)
	_floor_material.set_shader_parameter("field_energy", FLOOR_FIELD_ENERGY)

func _metal(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(albedo.r, albedo.g, albedo.b, 1.0)
	material.metallic = 0.5
	material.roughness = 0.46
	material.emission_enabled = true
	material.emission = Color(emission.r, emission.g, emission.b, 1.0)
	material.emission_energy_multiplier = energy
	return material

## Wände, Boden, Kragen und Lichtsaum - alles in LOKALEN Koordinaten um die
## Grubenmitte auf dem Glas (y = 0 ist die Tischfläche).
func _build_body() -> void:
	var span := Vector2(half.x * 2.0, half.y * 2.0)
	var top := -WALL_SINK
	# Die Wände stehen AUSSERHALB der Öffnung: ihre Innenflächen liegen auf der
	# Lochkante, sind also normale Vorderseiten - ein Kasten von innen betrachtet
	# zeigt sonst nur weggekullte Rückseiten.
	for wall_id: int in WALLS:
		_build_wall(wall_id, top)
	_box("Floor", Vector3(span.x + wall * 2.0, floor_plate, span.y + wall * 2.0),
		Vector3(0.0, top - depth - floor_plate * 0.5, 0.0), _floor_material)

	# Kragen: er greift RIM_IN über die Kante in die Öffnung hinein und deckt
	# damit die harte Schnittkante des Shaders.
	var rim_y := -RIM_H * 0.5 - RIM_SINK
	var rim_x := half.x - RIM_IN * 0.5 + RIM_OUT * 0.5
	var rim_z := half.y - RIM_IN * 0.5 + RIM_OUT * 0.5
	var rim_bar := RIM_IN + RIM_OUT
	_box("RimXPlus", Vector3(rim_bar, RIM_H, span.y + rim_bar * 2.0),
		Vector3(rim_x, rim_y, 0.0), _rim_material)
	_box("RimXMinus", Vector3(rim_bar, RIM_H, span.y + rim_bar * 2.0),
		Vector3(-rim_x, rim_y, 0.0), _rim_material)
	_box("RimZPlus", Vector3(span.x, RIM_H, rim_bar),
		Vector3(0.0, rim_y, rim_z), _rim_material)
	_box("RimZMinus", Vector3(span.x, RIM_H, rim_bar),
		Vector3(0.0, rim_y, rim_z * -1.0), _rim_material)

	var glow_y := -GLOW_DROP - GLOW_H * 0.5
	var glow_in := RIM_IN * 0.5
	_box("GlowXPlus", Vector3(glow_in, GLOW_H, span.y),
		Vector3(half.x - glow_in * 0.5, glow_y, 0.0), _glow_material)
	_box("GlowXMinus", Vector3(glow_in, GLOW_H, span.y),
		Vector3(-half.x + glow_in * 0.5, glow_y, 0.0), _glow_material)
	_box("GlowZPlus", Vector3(span.x, GLOW_H, glow_in),
		Vector3(0.0, glow_y, half.y - glow_in * 0.5), _glow_material)
	_box("GlowZMinus", Vector3(span.x, GLOW_H, glow_in),
		Vector3(0.0, glow_y, -half.y + glow_in * 0.5), _glow_material)

## EINE Wand ist EIN Balken - es gibt keine Tore mehr, durch die etwas hereinkäme.
## Gerechnet wird in der GEDREHTEN Wandrichtung (wall_axis/wall_inward), damit
## dieselbe Rechnung alle vier Wände baut.
func _build_wall(wall_id: int, top: float) -> void:
	_wall_box(WALL_NAMES[wall_id], wall_id, 0.0, top - depth * 0.5,
		_wall_run(wall_id), depth, wall, wall * 0.5, _wall_material)

## Ein Kasten AUF einer Wand: along = Versatz längs der Wand, deep = Abstand
## seiner Mitte von der Innenfläche nach außen (negativ = eine Spur davor).
func _wall_box(box_name: String, wall_id: int, along: float, y: float,
		length: float, height: float, thick: float, deep: float,
		material: Material) -> void:
	if length <= 0.001 or height <= 0.001:
		return
	var inward := wall_inward(wall_id)
	var size := Vector3(length, height, thick)
	if absf(inward.x) > 0.5:
		size = Vector3(thick, height, length)
	_box(box_name, size, wall_axis(wall_id) * along
		- inward * (_wall_reach(wall_id) + deep) + Vector3.UP * y, material)

func _box(box_name: String, box_size: Vector3, at: Vector3,
		material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
