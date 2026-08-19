class_name PackPitView
extends Node3D
## Die GRUBE des Tisches: eine echte Vertiefung, in der Ware STEHT - unter dem
## Magazin der Werkbank wie unter der Vitrine des Ladens (VitrineView). Das Loch
## selbst schneidet der Shader (screen_glass.pit_rect/vitrine_rects verwirft die
## Anzeige, table_ground den Filzboden dahinter) - dieser Körper ist, was man durch
## das Loch sieht: vier nach innen blickende Wände, ein Boden und ein Kragen, der
## die harte Schnittkante deckt.
## Maße und Trimmung stehen dem Aufrufer offen; die Vorgaben SIND das Magazin.
## Rein per Code gebaut wie DataCellView und CapacitorBankView - kein .tscn.
## Drei Tischregeln gelten auch hier: nur EMISSION (die Bodenkacheln vertragen
## 16 Lichter), das Ruhelicht bleibt unter Rune.IDLE_CEILING, und gespiegelt wird
## sie NICHT - ein Loch hat kein Spiegelbild.
## Die Sorte gehört den Kassetten, nie der Grube. Ihre Auskleidung
## (pit_lining.gdshader) kennt dafür zwei Handschriften: das ARCHIV (Vorgabe) ist
## Samtboden und dunkles Metall mit einer Neon-Fuge in ihrem glow_color, die
## VERKAUFS-BUCHT (bay_look) tiefdunkler Lack mit schmalen Goldfugen, einem
## warmen Schimmer und einer dezenten Birnenlinie. Ein Archiv wirbt nicht - und
## eine Auslage schreit nicht, sie fasst.

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

## Die VERKAUFS-BUCHT (bay_look) trägt dieselbe Auskleidung in der zweiten
## Handschrift: dunkler Lack mit Goldfugen statt Archiv-Samt. Sie steht auf
## schmaleren Paneelen - erst viele Felder nebeneinander lesen als Fassung, vier
## breite Platten nicht - und ihr Grundton ist eine Spur WÄRMER als das Archiv:
## grau-blau ausgelegt las sich die Bucht als Leere, bunt ausgelegt als Jahrmarkt.
const BAY_PANEL_SHARE := 0.10
const BAY_WALL_ALBEDO := Color(0.064, 0.055, 0.056)
const BAY_FLOOR_ALBEDO := Color(0.054, 0.046, 0.047)
const BAY_WALL_FIELD_ENERGY := 2.6
const BAY_FLOOR_FIELD_ENERGY := 2.9
## Deckel der Emission: darüber laufen die drei Kanäle zu Weiß zusammen und aus
## der Farbe wird eine helle Fläche. Die Bucht steht tiefer als das Archiv - sie
## spricht nur in Gold, und Gold wird schnell zu Sahne.
const EMISSION_CAP := 1.45
const BAY_EMISSION_CAP := 1.15

const RIM_ALBEDO := Color(0.20, 0.195, 0.245)
const RIM_EMISSION := Color(0.42, 0.44, 0.58)
const RIM_EMISSION_ENERGY := 0.95

## Die KLAPPEN der Anrollbahnen (nur eine Bucht bestellt sie): jede sitzt bündig
## in IHRER Wand, kippt um ihre UNTERKANTE nach innen ab und liegt dann als flache
## Rampe in der Grube. Geschlossen bleibt sie durch ihre Fuge und den Lichtsaum
## darin ablesbar - eine unsichtbare Klappe wäre keine.
## Die vier Wände als Nummern; jede trägt ihre eigene Gierung, mit der dieselbe
## Rechnung sie in die Waagerechte dreht (wall_yaw). Ohne diese eine Drehung
## stünde der Klappenbau viermal im Code.
const WALL_Z_MINUS := 0
const WALL_Z_PLUS := 1
const WALL_X_MINUS := 2
const WALL_X_PLUS := 3
const WALLS := [WALL_X_PLUS, WALL_X_MINUS, WALL_Z_PLUS, WALL_Z_MINUS]
const WALL_NAMES := ["WallZMinus", "WallZPlus", "WallXMinus", "WallXPlus"]

const HATCH_ANGLE := deg_to_rad(97.0)
const HATCH_KERF := 0.035          # Spalt zwischen Klappenblatt und Rahmen
const HATCH_SEAM := 0.028          # Stärke der Leuchtfuge
const HATCH_SEAM_ENERGY := 1.15
const HATCH_PROUD := 0.008         # die Fuge steht eine Spur vor der Wandfläche
const HATCH_ALBEDO := Color(0.085, 0.080, 0.115)
## Das Blatt bleibt dunkel: es ist ein geschlossenes Tor, kein Leuchtfeld - die
## Fuge ringsum sagt schon, dass dort eine Klappe sitzt.
const HATCH_EMISSION_ENERGY := 0.32

var _wall_material: ShaderMaterial
var _floor_material: ShaderMaterial
var _rim_material: StandardMaterial3D
var _glow_material: StandardMaterial3D
var _hatch_material: StandardMaterial3D
var _seam_material: StandardMaterial3D

var _hatch_pivots: Array[Node3D] = []
var _hatch_open := PackedFloat32Array()

## Zuletzt gestellte Maße - der Abgleich stellt idempotent nach.
var center := Vector3.ZERO
var half := Vector2.ZERO
var depth := 0.0

## Trimmung der Grube - VOR dem ersten setup zu setzen (die Materialien entstehen
## dort). Die Vorgaben sind das Magazin; eine zweite Grube stellt nur um, was sie
## unterscheidet, statt einen eigenen Körper zu bauen.
var wall := WALL
var floor_plate := FLOOR
var glow_color := GLOW_COLOR
var glow_energy := GLOW_ENERGY
## Die Handschrift der Auskleidung: false = Archiv (Samt und Metall, das Magazin),
## true = Verkaufs-Bucht im Automaten-Look. Nur die Auskleidung ändert sich, kein
## Maß - Wände, Boden, Kragen und Klappe bleiben dieselbe Grube.
var bay_look := false

## Die Klappen, je Eintrag {wall, offset}: offset ist ihre Mitte auf der Wand, in
## lokalen Maßen LÄNGS der Wandrichtung. Leere Liste = keine Klappe (Magazin).
## Breite, Höhe und Schwelle teilen sich alle - durch jede kommt dasselbe.
var hatches: Array[Dictionary] = []
var hatch_width := 0.0
var hatch_height := 0.0
var hatch_sill := 0.0

func _init(pit_name := "PackPit") -> void:
	name = pit_name

## Einziger Eingang: Mitte auf dem Glas, halbe Ausdehnung in Welt-X/Welt-Z und
## die Tiefe unter dem Glas. Baut die Grube neu - sie steht selten um.
func setup(at: Vector3, half_extents: Vector2, pit_depth: float) -> void:
	center = at
	half = Vector2(maxf(half_extents.x, 0.01), maxf(half_extents.y, 0.01))
	depth = maxf(pit_depth, 0.05)
	global_position = center
	_hatch_pivots.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if _wall_material == null:
		_build_materials()
	_tune_lining()
	_build_body()
	var standing := _hatch_open
	_hatch_open = PackedFloat32Array()
	_hatch_open.resize(_hatch_pivots.size())
	for i in _hatch_pivots.size():
		set_hatch_open(i, standing[i] if i < standing.size() else 0.0)

## Die Welt-XZ-Grenzen des Lochs (der Bodenshader blendet genau sie aus).
func bounds_min() -> Vector2:
	return Vector2(center.x - half.x, center.z - half.y)

func bounds_max() -> Vector2:
	return Vector2(center.x + half.x, center.z + half.y)

## Wie viele Klappen wirklich gebaut wurden.
func hatch_count() -> int:
	return _hatch_pivots.size()

## Die Gierung, mit der eine Wand in die Rechnung gedreht wird: danach zeigt
## lokal +Z ins Innere der Grube und lokal +X längs der Wand.
static func wall_yaw(wall_id: int) -> float:
	match wall_id:
		WALL_Z_PLUS: return PI
		WALL_X_MINUS: return PI * 0.5
		WALL_X_PLUS: return -PI * 0.5
		_: return 0.0

## Die Innenrichtung einer Wand (waagerechter Einheitsvektor): dorthin kippt ihre
## Klappe, dorthin läuft der Wurf.
static func wall_inward(wall_id: int) -> Vector3:
	return Basis(Vector3.UP, wall_yaw(wall_id)) * Vector3.BACK

## Ihre Längsrichtung.
static func wall_axis(wall_id: int) -> Vector3:
	return Basis(Vector3.UP, wall_yaw(wall_id)) * Vector3.RIGHT

## Wo eine Klappe angeschlagen ist (Weltpunkt der Unterkante ihrer Innenfläche).
func hatch_hinge(index: int) -> Vector3:
	var spec := _hatch_at(index)
	var wall_id: int = spec.get("wall", WALL_Z_MINUS)
	return center + wall_axis(wall_id) * float(spec.get("offset", 0.0)) \
		- wall_inward(wall_id) * _wall_reach(wall_id) + Vector3.UP * hatch_sill

## Wohin ihr Wurf läuft.
func hatch_inward(index: int) -> Vector3:
	return wall_inward(int(_hatch_at(index).get("wall", WALL_Z_MINUS)))

## Der Vorhang EINER Klappe: 0 = bündig zu, 1 = ganz abgekippt.
func set_hatch_open(index: int, value: float) -> void:
	if index < 0 or index >= _hatch_pivots.size():
		return
	if _hatch_open.size() < _hatch_pivots.size():
		_hatch_open.resize(_hatch_pivots.size())
	_hatch_open[index] = clampf(value, 0.0, 1.0)
	var pivot := _hatch_pivots[index]
	if pivot != null and is_instance_valid(pivot):
		pivot.rotation.x = HATCH_ANGLE * _hatch_open[index]

func hatch_open_amount(index: int) -> float:
	if index < 0 or index >= _hatch_open.size():
		return 0.0
	return _hatch_open[index]

## Alle Klappen hart zu - ein Laufwechsel duldet keine offene Wand.
func close_all_hatches() -> void:
	for i in _hatch_pivots.size():
		set_hatch_open(i, 0.0)

func _hatch_at(index: int) -> Dictionary:
	if index < 0 or index >= hatches.size():
		return {}
	return hatches[index]

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
	_hatch_material = _metal(HATCH_ALBEDO, glow_color, HATCH_EMISSION_ENERGY)
	_seam_material = _metal(glow_color * 0.3, glow_color, HATCH_SEAM_ENERGY)

## Die Auskleidung misst sich an der Grube, in der sie steckt - Paneelbreite und
## Tiefenverlauf sind gerechnet, nicht getippt.
func _tune_lining() -> void:
	var share := BAY_PANEL_SHARE if bay_look else PANEL_SHARE
	var panel := maxf(maxf(half.x, half.y) * 2.0 * share, PANEL_MIN)
	for pair: Array in [[_wall_material, 0.0], [_floor_material, 1.0]]:
		var material: ShaderMaterial = pair[0]
		material.set_shader_parameter("velvet", pair[1])
		material.set_shader_parameter("bay", 1.0 if bay_look else 0.0)
		material.set_shader_parameter("seam_color", glow_color)
		material.set_shader_parameter("seam_energy", SEAM_ENERGY)
		material.set_shader_parameter("panel_width", panel)
		material.set_shader_parameter("pit_depth", depth)
		material.set_shader_parameter("glass_y", center.y)
		material.set_shader_parameter("field_center", Vector2(center.x, center.z))
		material.set_shader_parameter("field_half", half)
		material.set_shader_parameter("emission_cap",
			BAY_EMISSION_CAP if bay_look else EMISSION_CAP)
	_wall_material.set_shader_parameter("base_color",
		BAY_WALL_ALBEDO if bay_look else WALL_ALBEDO)
	_wall_material.set_shader_parameter("field_energy",
		BAY_WALL_FIELD_ENERGY if bay_look else WALL_FIELD_ENERGY)
	_floor_material.set_shader_parameter("base_color",
		BAY_FLOOR_ALBEDO if bay_look else FLOOR_ALBEDO)
	_floor_material.set_shader_parameter("field_energy",
		BAY_FLOOR_FIELD_ENERGY if bay_look else FLOOR_FIELD_ENERGY)

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

## EINE Wand: ohne Klappe ein Balken, mit Klappen die Stücke zwischen ihren
## Öffnungen plus je Öffnung Kopfstück, Blatt, Fuge und dunkle Rückwand. Gerechnet
## wird in der GEDREHTEN Wandrichtung (wall_axis/wall_inward), damit dieselbe
## Rechnung alle vier Wände baut.
func _build_wall(wall_id: int, top: float) -> void:
	var wall_name: String = WALL_NAMES[wall_id]
	var run := _wall_run(wall_id)
	var mid := top - depth * 0.5
	var openings := _wall_hatches(wall_id)
	if openings.is_empty():
		_wall_box(wall_name, wall_id, 0.0, mid, run, depth, wall, wall * 0.5,
			_wall_material)
		return
	var y0 := hatch_sill
	var y1 := hatch_sill + hatch_height
	# Die Stücke ZWISCHEN den Öffnungen (und vor der ersten, hinter der letzten).
	var cut := -run * 0.5
	for i in openings.size() + 1:
		var next := run * 0.5 if i == openings.size() \
			else float(openings[i]["offset"]) - hatch_width * 0.5
		if next - cut > 0.001:
			_wall_box("%sPart%d" % [wall_name, i], wall_id, (cut + next) * 0.5, mid,
				next - cut, depth, wall, wall * 0.5, _wall_material)
		if i < openings.size():
			cut = float(openings[i]["offset"]) + hatch_width * 0.5
	for i in openings.size():
		var offset := float(openings[i]["offset"])
		if top - y1 > 0.001:
			_wall_box("%sHead%d" % [wall_name, i], wall_id, offset, (top + y1) * 0.5,
				hatch_width, top - y1, wall, wall * 0.5, _wall_material)
		var sill_drop := y0 - (top - depth)
		if sill_drop > 0.001:
			_wall_box("%sSill%d" % [wall_name, i], wall_id, offset, y0 - sill_drop * 0.5,
				hatch_width, sill_drop, wall, wall * 0.5, _wall_material)
		# Dunkle Rückwand: durch die offene Klappe blickt man sonst auf den Filz
		# hinter der Bucht statt in einen Schacht. Sie wächst nur nach UNTEN über die
		# Öffnung hinaus - oben stünde sie über der Glasebene.
		_wall_box("HatchBack%d" % _hatch_pivots.size(), wall_id, offset,
			(y0 + y1) * 0.5 - wall * 0.25, hatch_width + wall, hatch_height + wall * 0.5,
			wall * 0.6, wall * 1.5, _floor_material)
		_build_hatch(wall_id, offset, y0, y1)

## Die Klappen EINER Wand, nach ihrem Versatz sortiert - der Wandbau läuft an
## ihnen entlang und braucht sie in der Reihe.
func _wall_hatches(wall_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if hatch_width <= 0.001 or hatch_height <= 0.001:
		return out
	for spec in hatches:
		if int(spec.get("wall", WALL_Z_MINUS)) == wall_id:
			out.append(spec)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["offset"]) < float(b["offset"]))
	return out

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

## Das Klappenblatt hängt an einem Drehpunkt auf der UNTERKANTE der Öffnung, auf
## der Innenfläche der Wand: von dort kippt es nach innen ab und liegt als Rampe.
## Der Drehpunkt trägt die Gierung SEINER Wand, das Kippen läuft danach auf seiner
## lokalen X-Achse - eine Klappe, vier mögliche Wände, eine Rechnung.
func _build_hatch(wall_id: int, offset: float, y0: float, y1: float) -> void:
	var index := _hatch_pivots.size()
	var pivot := Node3D.new()
	pivot.name = "HatchHinge%d" % index
	pivot.position = wall_axis(wall_id) * offset \
		- wall_inward(wall_id) * _wall_reach(wall_id) + Vector3.UP * y0
	pivot.rotation = Vector3(0.0, wall_yaw(wall_id), 0.0)
	add_child(pivot)
	_hatch_pivots.append(pivot)
	var leaf := MeshInstance3D.new()
	leaf.name = "HatchLeaf"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(hatch_width - HATCH_KERF * 2.0, 0.02),
		maxf(hatch_height - HATCH_KERF * 2.0, 0.02), wall * 0.7)
	leaf.mesh = mesh
	leaf.material_override = _hatch_material
	leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.position = Vector3(0.0, mesh.size.y * 0.5 + HATCH_KERF, -wall * 0.5)
	pivot.add_child(leaf)

	# Die Fuge bleibt STEHEN, auch wenn das Blatt abkippt - sie ist der Rahmen,
	# an dem die Klappe geschlossen überhaupt ablesbar ist.
	var w := hatch_width
	var h := hatch_height
	_wall_box("HatchSeamTop%d" % index, wall_id, offset, y1,
		w + HATCH_SEAM * 2.0, HATCH_SEAM, HATCH_SEAM, -HATCH_PROUD, _seam_material)
	_wall_box("HatchSeamBottom%d" % index, wall_id, offset, y0,
		w + HATCH_SEAM * 2.0, HATCH_SEAM, HATCH_SEAM, -HATCH_PROUD, _seam_material)
	_wall_box("HatchSeamLeft%d" % index, wall_id, offset - w * 0.5, y0 + h * 0.5,
		HATCH_SEAM, h, HATCH_SEAM, -HATCH_PROUD, _seam_material)
	_wall_box("HatchSeamRight%d" % index, wall_id, offset + w * 0.5, y0 + h * 0.5,
		HATCH_SEAM, h, HATCH_SEAM, -HATCH_PROUD, _seam_material)

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
