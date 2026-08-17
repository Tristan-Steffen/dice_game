class_name PackPitView
extends Node3D
## Die MAGAZIN-GRUBE: eine echte Vertiefung im Tisch, in der die Datenzellen
## STEHEN. Das Loch selbst schneidet der Shader (screen_glass.pit_rect verwirft
## die Anzeige, table_ground.pit_min/max den Filzboden dahinter) - dieser Körper
## ist, was man durch das Loch sieht: vier nach innen blickende Wände, ein Boden
## und ein Kragen, der die harte Schnittkante deckt.
## Rein per Code gebaut wie DataCellView und CapacitorBankView - kein .tscn.
## Drei Tischregeln gelten auch hier: nur EMISSION (die Bodenkacheln vertragen
## 16 Lichter), das Ruhelicht bleibt unter Rune.IDLE_CEILING, und gespiegelt wird
## sie NICHT - ein Loch hat kein Spiegelbild.
## Die Sorte gehört den Kassetten: die Grube ist neutrales Dunkelmetall.

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
const WALL_EMISSION := Color(0.13, 0.14, 0.22)
const WALL_EMISSION_ENERGY := 1.05
const FLOOR_ALBEDO := Color(0.036, 0.034, 0.056)
const FLOOR_EMISSION_ENERGY := 0.5
const RIM_ALBEDO := Color(0.20, 0.195, 0.245)
const RIM_EMISSION := Color(0.42, 0.44, 0.58)
const RIM_EMISSION_ENERGY := 0.95

var _wall_material: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _rim_material: StandardMaterial3D
var _glow_material: StandardMaterial3D

## Zuletzt gestellte Maße - der Abgleich stellt idempotent nach.
var center := Vector3.ZERO
var half := Vector2.ZERO
var depth := 0.0

func _init() -> void:
	name = "PackPit"

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
	_build_body()

## Die Welt-XZ-Grenzen des Lochs (der Bodenshader blendet genau sie aus).
func bounds_min() -> Vector2:
	return Vector2(center.x - half.x, center.z - half.y)

func bounds_max() -> Vector2:
	return Vector2(center.x + half.x, center.z + half.y)

func _build_materials() -> void:
	_wall_material = _metal(WALL_ALBEDO, WALL_EMISSION, WALL_EMISSION_ENERGY)
	_floor_material = _metal(FLOOR_ALBEDO, WALL_EMISSION, FLOOR_EMISSION_ENERGY)
	_rim_material = _metal(RIM_ALBEDO, RIM_EMISSION, RIM_EMISSION_ENERGY)
	_glow_material = _metal(GLOW_COLOR * 0.3, GLOW_COLOR, GLOW_ENERGY)

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
	var mid := -depth * 0.5
	# Die Wände stehen AUSSERHALB der Öffnung: ihre Innenflächen liegen auf der
	# Lochkante, sind also normale Vorderseiten - ein Kasten von innen betrachtet
	# zeigt sonst nur weggekullte Rückseiten.
	_box("WallXPlus", Vector3(WALL, depth, span.y + WALL * 2.0),
		Vector3(half.x + WALL * 0.5, mid, 0.0), _wall_material)
	_box("WallXMinus", Vector3(WALL, depth, span.y + WALL * 2.0),
		Vector3(-half.x - WALL * 0.5, mid, 0.0), _wall_material)
	_box("WallZPlus", Vector3(span.x, depth, WALL),
		Vector3(0.0, mid, half.y + WALL * 0.5), _wall_material)
	_box("WallZMinus", Vector3(span.x, depth, WALL),
		Vector3(0.0, mid, -half.y - WALL * 0.5), _wall_material)
	_box("Floor", Vector3(span.x + WALL * 2.0, FLOOR, span.y + WALL * 2.0),
		Vector3(0.0, -depth - FLOOR * 0.5, 0.0), _floor_material)

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

func _box(box_name: String, box_size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
