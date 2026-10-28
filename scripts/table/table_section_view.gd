class_name TableSectionView
extends Node3D
## DIE TISCHSEKTION unter dem ZIEL-NETZ der Werkstatt (Spieler-Wunsch 2026-10-26).
## Bündig IST sie die Anzeige: ihre Deckhaut ist dieselbe wie die jeder
## Hebebühnen-Plattform (TableScreen.display_skin, gerechnet aus der WELTPOSITION),
## der bündige Stand ist also pixelgleich mit dem Glas ringsum.
##
## Beim VERDICHTEN weicht sie dem Rohling - wie eine Ware im Laden in den Tisch
## fährt: erst SINKT sie GANZ unter die Schnittkante, dann FÄHRT sie nach
## Bild-rechts (Welt +Z) in ihre TASCHE unter dem Nachbar-Abschnitt. Was bleibt,
## ist die VERTIEFUNG, in die sich der Rohling legt.
##
## Gefahren wird hier nichts von selbst: scene_root schreibt ihren Stand je Bild
## (place), wie jeden anderen Körper - dip = wie weit gesunken, slide = wie weit
## gefahren, beide 0..1. Den TAKT (wann gesunken, wann gefahren wird) besitzt das
## Fenster, die GEOMETRIE diese Datei.

## Die Dicke der Platte, und wie weit ihre OBERKANTE beim Sinken unter die
## Schnittkante fährt: sie muß ganz unter dem Glas stehen, bevor sie seitlich fährt.
const DECK := 0.10
const SINK := DECK + 0.06
## Die Platte fährt ihre ganze Länge plus Luft - erst dann steht die Vertiefung frei.
const CLEAR := 0.3

## Die Sektion ist seit dem 2026-10-27 eine GLAS-SCHEIBE (Spieler-Wunsch): durch sie
## sieht man auf den TURM darunter, und nur die DIE-VIEW bleibt, wie sie war - die
## trägt ihre eigene Haut mit echtem Per-Pixel-Alpha (TableScreen.net_glass_skin).
## Die Werte sind die des GRUBEN-SCHIRMS (LiftShaftView.COVER_*, EINE Quelle): fast
## durchsichtig, nur ein Saum Emission, und KEIN Tiefen-Schreiben - sonst verdeckte
## die Scheibe, was unter ihr steht.
const GLASS_TINT := LiftShaftView.GLOW_COLOR
const GLASS_ALPHA := LiftShaftView.COVER_ALPHA
const GLASS_ENERGY := LiftShaftView.COVER_EMISSION_ENERGY

## Die TASCHE bleibt MASCHINE - sie liegt unter dem undurchsichtigen Nachbar-
## Abschnitt, dort schaut niemand hinein.
const SIDE_ALBEDO := LiftShaftView.DECK_SIDE
const SIDE_EMISSION := LiftShaftView.DECK_EMISSION
const SIDE_ENERGY := LiftShaftView.DECK_EMISSION_ENERGY

## Die TASCHE, in die sie fährt: ihre Wandstärke und die Luft über und unter der
## Platte. Ohne sie führe die Sektion in ein schwarzes Nichts unter dem Filz.
const POCKET_WALL := 0.06
const POCKET_AIR := 0.05

## Die gemeldete Deckhaut (null = die Platte bleibt Maschine wie ihre Flanken).
var deck_skin: Material = null:
	set(value):
		deck_skin = value
		_apply_skin()

var _seat := Vector3.ZERO
var _span := Vector2.ZERO
var _reach := 0.0
var _plate: Node3D
var _top: MeshInstance3D
var _pocket: Node3D
var _side_material: StandardMaterial3D
var _glass_material: StandardMaterial3D

func _init() -> void:
	name = "TableSection"

## Einziger Eingang: Mitte der Sektion auf dem Glas und ihre Spanne in Welt-X/Welt-Z.
## Idempotent - dieselben Maße bauen nichts neu.
func seat(at: Vector3, span: Vector2) -> void:
	var wanted := Vector2(maxf(span.x, 0.01), maxf(span.y, 0.01))
	if _plate != null and is_instance_valid(_plate) \
			and _seat.is_equal_approx(at) and _span.is_equal_approx(wanted):
		return
	_seat = at
	_span = wanted
	_reach = _span.y + CLEAR
	global_position = at
	_build()

## Wie weit sie nach Bild-rechts fährt - das Maß, an dem die Tasche hängt.
func reach() -> float:
	return _reach

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_side_material = TableProps.metal(SIDE_ALBEDO, SIDE_EMISSION, SIDE_ENERGY, 0.45, 0.5)
	_glass_material = _build_glass()
	_build_pocket()
	_plate = Node3D.new()
	_plate.name = "Platte"
	add_child(_plate)
	# Die DECKHAUT ist die Oberfläche und reicht allein bis zur Nullebene; die Platte
	# hängt vollständig darunter. Zwei koplanare Deckflächen stritten im Tiefenpuffer.
	var skin_h := DECK * 0.12
	var skin := BoxMesh.new()
	skin.size = Vector3(_span.x, skin_h, _span.y)
	_top = MeshInstance3D.new()
	_top.name = "DeckTop"
	_top.mesh = skin
	_top.position = Vector3(0.0, -skin_h * 0.5, 0.0)
	_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plate.add_child(_top)
	_apply_skin()
	TableProps.box(_plate, "Deck", Vector3(_span.x, DECK, _span.y),
		Vector3(0.0, -DECK * 0.5, 0.0), _glass_material)
	place(0.0, 0.0)

## Das GLAS der Sektion: fast durchsichtig, nur ein Saum Emission, kein
## Tiefen-Schreiben. render_priority hinter der Haut, damit zwei fast gleichebene
## durchsichtige Flächen nicht je Bild anders sortieren.
func _build_glass() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(GLASS_TINT.r * 0.5, GLASS_TINT.g * 0.5,
		GLASS_TINT.b * 0.5, GLASS_ALPHA)
	material.metallic = 0.0
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = Color(GLASS_TINT.r, GLASS_TINT.g, GLASS_TINT.b, 1.0)
	material.emission_energy_multiplier = GLASS_ENERGY
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = -1
	return material

## Die TASCHE unter dem Nachbar-Abschnitt: ein geschlossener Kasten, zur Vertiefung
## hin offen. Sie steht STILL - nur die Platte fährt in sie hinein.
func _build_pocket() -> void:
	var host := Node3D.new()
	host.name = "Tasche"
	add_child(host)
	_pocket = host
	var top := -SINK + POCKET_AIR
	var bottom := -SINK - DECK - POCKET_AIR
	var high := top - bottom
	var near := _span.y * 0.5
	var deep := _reach + POCKET_WALL
	var wide := _span.x + POCKET_WALL * 2.0
	var mid_z := near + deep * 0.5
	var mid_y := (top + bottom) * 0.5
	TableProps.box(host, "Decke", Vector3(wide, POCKET_WALL, deep),
		Vector3(0.0, top + POCKET_WALL * 0.5, mid_z), _side_material)
	TableProps.box(host, "Boden", Vector3(wide, POCKET_WALL, deep),
		Vector3(0.0, bottom - POCKET_WALL * 0.5, mid_z), _side_material)
	TableProps.box(host, "Rueckwand", Vector3(wide, high + POCKET_WALL * 2.0, POCKET_WALL),
		Vector3(0.0, mid_y, near + deep + POCKET_WALL * 0.5), _side_material)
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		TableProps.box(host, "Flanke%d" % side, Vector3(POCKET_WALL, high, deep),
			Vector3(dir * (_span.x + POCKET_WALL) * 0.5, mid_y, mid_z), _side_material)

func _apply_skin() -> void:
	if _top != null and is_instance_valid(_top):
		_top.material_override = deck_skin if deck_skin != null else _glass_material

## Der EINE Schreiber ihres Standes: erst sinken, dann fahren. 0/0 ist bündig.
func place(dip: float, slide: float) -> void:
	if _plate == null or not is_instance_valid(_plate):
		return
	_plate.position = Vector3(0.0, -SINK * clampf(dip, 0.0, 1.0),
		_reach * clampf(slide, 0.0, 1.0))
