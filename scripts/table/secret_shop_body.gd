class_name SecretShopBody
extends Node3D
## Der Körper des SCHWARZMARKTS (2026-11-26, Spieler-Wahl „C · Schubfächer“ aus
## tools/blender_secret_shop_variants.py build_c; Runde 2: massive Fächer, Neuwurf je Fach,
## Haut „A · Graphit“ aus drei Entwürfen, Spieler-Wahl): hinten das GEHÄUSE mit Zierleiste, Namens-Schildern und dem
## INFO-DISPLAY auf dem Dach, davor drei SCHUBFÄCHER aus EINEM Stück mit Leuchtboden, vorn je
## die NASE mit Griff, Preis, Kauf-Leiste und Neuwurf-Taste; rechts auf halber Höhe die Kontaktleiste der
## Hub-Ader. Ursprung = Stationsmitte auf dem Tisch, lokal +X = Bild-oben, +Z = Bild-rechts.
## Eingefahren reicht ein Fach hinten über das Gehäuse hinaus: was hinter der Rückwand läge,
## schneidet der Shader ab (clip_plane), die Ware ist dann schon verborgen.

const BAYS := 3
const HOUSING_HEIGHT := 1.95
const FLOOR_TOP := 0.12
const RIM_HEIGHT := 0.5
const RIM := 0.25
const NOSE_HEIGHT := 0.7
const PLATE_HEIGHT := 0.08
const KEY_HEIGHT := 0.12
const OPEN_TIME := 0.42
const CLOSE_TIME := 0.42
const HOVER_LIFT := 0.3
const DOT_PITCH := 0.42
const BOLT := 0.55
const SCREW := 0.09

const SKIN_SHADER := preload("res://assets/shaders/secret_shop_skin.gdshader")

const RED := Color(0.95, 0.22, 0.28)
const LABEL := Color(0.92, 0.9, 1.0)
const LABEL_DIM := Color(0.45, 0.43, 0.52)
const GLASS := Color(0.01, 0.008, 0.02)
const GOLD := Color(0.72, 0.52, 0.18)

## Die Haut „A · Graphit“ (Spieler-Wahl 2026-11-26 aus Graphit, Nachtviolett, Perlmutt).
## body/top/front: Gehäuse und Nasen, bevel: Glanzgrat der Kanten, seam: Fugen, vent: Schlitze,
## metal: Griff, Rahmen, Schienen, screw: Schrauben, trim/trim_dim: Leuchtkanten,
## floor/dot: Fachboden und Raster (hell = bezahlbar), wall: Fachwände.
const LOOK := {
	"body": Color(0.2, 0.2, 0.225), "top": Color(0.25, 0.25, 0.28), "front": Color(0.16, 0.16, 0.185),
	"brush": 1.0, "gloss": 0.15,
	"bevel": Color(0.72, 0.75, 0.82), "seam": Color(0.05, 0.05, 0.06), "vent": Color(0.04, 0.04, 0.05),
	"metal": Color(0.56, 0.58, 0.63), "screw": Color(0.66, 0.68, 0.74),
	"trim": Color(0.62, 0.3, 0.95), "trim_dim": Color(0.2, 0.1, 0.3),
	"floor": Color(0.15, 0.07, 0.24), "floor_dim": Color(0.08, 0.04, 0.12),
	"dot": Color(0.6, 0.38, 0.9), "dot_dim": Color(0.28, 0.17, 0.4),
	"wall": Color(0.34, 0.35, 0.39), "mouth": Color(0.03, 0.03, 0.04),
}

## Je Fach: Wurzel (fest, trägt die Schienen), der SCHUB als ein Stück, Hub der Ware.
var _drawers: Array[Node3D] = []
var _slides: Array[Node3D] = []
var _lifts: Array[Node3D] = []
var _names: Array[Label3D] = []
var _prices: Array[Label3D] = []
var _bolts: Array[MeshInstance3D] = []
var _bars: Array[MeshInstance3D] = []
var _floor_mats: Array[ShaderMaterial] = []
var _dot_mats: Array[ShaderMaterial] = []
var _key_prices: Array[Label3D] = []
var _key_rims: Array[MultiMeshInstance3D] = []
var _key_arrows: Array[MeshInstance3D] = []
var _key_bolts: Array[MeshInstance3D] = []
var _clip_mats: Array[ShaderMaterial] = []
var _info_quad: MeshInstance3D
var _info_viewport: SubViewport
var _info_rect := Rect2()
var _mat := {}
var _look := {}

## Der Stand je Fach: 0 = eingefahren, 1 = ausgefahren.
var _share: Array[float] = [0.0, 0.0, 0.0]
var _want_key: Array[String] = ["", "", ""]
var _want_open: Array[bool] = [false, false, false]
var _ware: Array[Node3D] = [null, null, null]
var _ware_key: Array[String] = ["", "", ""]
var _ware_kind: Array[String] = ["", "", ""]
var _want_ware: Array = [null, null, null]
var _tweens: Array = [null, null, null]
var _hovered := -1
var _writes := 0
var _travel := 9.2
var _seat_x := 0.0
var _housing_back := 4.6
var _built := false

func _ready() -> void:
	set_notify_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_sync_clip()

## parts: je Teil ein Rechteck in der Ebene (x = Bild-rechts, y = Bild-unten, Welt-Einheiten,
## um die Stationsmitte) - die Schlüssel von SecretShopView.PARTS.
func setup(parts: Dictionary) -> void:
	for child in get_children():
		if child == _info_viewport:
			continue
		remove_child(child)
		child.queue_free()
	for list: Array in [_drawers, _slides, _lifts, _names, _prices, _bolts, _bars, _floor_mats,
			_dot_mats, _key_prices, _key_rims, _key_arrows, _key_bolts, _clip_mats]:
		list.clear()
	_ware = [null, null, null]
	_ware_key = ["", "", ""]
	_ware_kind = ["", "", ""]
	_want_key = ["", "", ""]
	_want_open = [false, false, false]
	_share = [0.0, 0.0, 0.0]
	_look = LOOK
	var housing: Rect2 = parts["housing"]
	_housing_back = -housing.position.y
	var bay0: Rect2 = parts["bay0"]
	_travel = bay0.size.y
	_seat_x = -bay0.get_center().y
	_build_materials()
	var bays: Array[Rect2] = []
	for i in BAYS:
		bays.append(parts["bay%d" % i])
	_build_housing(housing, parts["info"], bays)
	for i in BAYS:
		_build_name_plate(i, parts["label%d" % i])
		_build_drawer(i, parts["bay%d" % i], parts["nose%d" % i], parts["reroll%d" % i])
	_build_foot(parts["contacts"])
	_built = true
	_sync_clip()
	if _info_viewport != null:
		_info_quad_material().albedo_texture = _info_viewport.get_texture()
	for i in BAYS:
		_tweens[i] = null
		_place(i)

## Ebene (rechts, unten) -> lokal (x = Bild-oben, z = Bild-rechts).
static func _at(p: Vector2, y: float) -> Vector3:
	return Vector3(-p.y, y, p.x)

# --- Der EINE Schreiber -----------------------------------------------------------------

## bays: je Fach {key, kind, item, name, price, state, open, reroll = {price, afford}}
## (SecretShopView.bay_state samt Schlüssel und reroll_state). hard = ungesehen: ohne Fahrt.
func seat(bays: Array, hard := false) -> void:
	if not _built:
		return
	for i in BAYS:
		var bay: Dictionary = bays[i] if i < bays.size() else {}
		var open := bool(bay.get("open", false))
		var key := String(bay.get("key", "")) if open else ""
		_write_labels(i, bay)
		_write_reroll(i, bay.get("reroll", {}))
		if key != _want_key[i] or open != _want_open[i]:
			_writes += 1
			_want_key[i] = key
			_want_open[i] = open
			_want_ware[i] = bay
			if hard:
				_settle_bay(i)
			else:
				_advance(i)
		elif hard and _riding(i):
			_settle_bay(i)

## Der harte Weg: jedes Fach steht auf seinem Endzustand.
func settle_hard() -> void:
	for i in BAYS:
		_settle_bay(i)

func _settle_bay(i: int) -> void:
	_kill(i)
	if _ware_key[i] != _want_key[i]:
		_swap_ware(i)
	_share[i] = 1.0 if _want_open[i] else 0.0
	_place(i)

func _riding(i: int) -> bool:
	var tween: Tween = _tweens[i]
	return tween != null and tween.is_valid()

func riding() -> bool:
	for i in BAYS:
		if _riding(i):
			return true
	return false

## Der nächste Schritt eines Fachs: erst mit der alten Ware einfahren, drinnen tauschen,
## dann mit der neuen ausfahren. Ein laufender Schritt endet erst, dann wird neu gefragt.
func _advance(i: int) -> void:
	if _riding(i):
		return
	if _ware_key[i] != _want_key[i]:
		if _share[i] > 0.0:
			_ride(i, 0.0, CLOSE_TIME * _share[i])
			return
		_swap_ware(i)
	var goal := 1.0 if _want_open[i] else 0.0
	if not is_equal_approx(_share[i], goal):
		_ride(i, goal, (OPEN_TIME if goal > 0.5 else CLOSE_TIME) * absf(goal - _share[i]))

func _ride(i: int, goal: float, time: float) -> void:
	var tween := create_tween()
	_tweens[i] = tween
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(value: float) -> void:
		_share[i] = value
		_place(i), _share[i], goal, maxf(time, 0.01))
	tween.finished.connect(func() -> void:
		_tweens[i] = null
		_advance(i))

func _kill(i: int) -> void:
	var tween: Tween = _tweens[i]
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens[i] = null

## Fahrzeit eines Fachs von ganz offen bis ganz zu.
static func close_time() -> float:
	return CLOSE_TIME

# --- Ware ---------------------------------------------------------------------------------

## Tauscht die Ware im (eingefahrenen) Fach gegen die gewollte.
func _swap_ware(i: int) -> void:
	if _ware[i] != null and is_instance_valid(_ware[i]):
		_ware[i].get_parent().remove_child(_ware[i])
		_ware[i].queue_free()
	_ware[i] = null
	_ware_key[i] = _want_key[i]
	_ware_kind[i] = ""
	if _want_key[i] == "":
		return
	var bay: Dictionary = _want_ware[i]
	var kind := String(bay.get("kind", ""))
	var body := spawn_ware(kind, bay.get("item"), _lifts[i])
	if body == null:
		return
	_ware[i] = body
	_ware_kind[i] = kind
	_lay_ware(i)

## Der Körper einer Ware - wie überall, in seiner EINEN Größe.
static func spawn_ware(kind: String, item: Variant, host: Node) -> Node3D:
	match kind:
		GameRun.KIND_CHARM:
			# Wie im Laden: die Diskette steckt im tragbaren Projektor, der ihr Hologramm zeigt.
			var projector := CharmProjectorView.new()
			projector.name = "Diskettenprojektor"
			host.add_child(projector)
			var disk := CharmDiskView.new(item as Charm)
			disk.name = "Diskette"
			projector.add_child(disk)
			disk.position = CharmProjectorView.disk_offset()
			projector.set_charm(item as Charm)
			return projector
		GameRun.KIND_DIE:
			var die := FloatingDie.build_ghost(item as DieDefinition)
			host.add_child(die)
			var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
			faces.set_pool_enabled(false)
			return die
		GameRun.KIND_PART:
			var part := ComboPartBody.new()
			part.name = "Modul"
			host.add_child(part)
			part.setup(item as ComboPart)
			return part
		GameRun.KIND_PROJECTOR:
			var reader := CharmReaderView.new()
			reader.name = "Projektor"
			host.add_child(reader)
			reader.set_charm(null)
			return reader
		GameRun.KIND_POWERBANK:
			var bank := _powerbank_body()
			host.add_child(bank)
			return bank
	if item is Pack:
		var pack := item as Pack
		var cell := DataCellView.new()
		cell.name = "Karte"
		host.add_child(cell)
		cell.setup(Pack.shelf_of(pack), pack.tier, pack.stamp_net, pack.from_blank())
		cell.rotation.y = -PI / 2.0
		cell.badge_on_face = true
		cell.set_count(maxi(pack.count, 1))
		return cell
	return null

## Die Powerbank: ein silberner Einschub wie die Batterien des Racks, flach liegend.
static func _powerbank_body() -> Node3D:
	var root := Node3D.new()
	root.name = "Powerbank"
	StationParts.box(root, "Rumpf", Vector3(1.6, 0.36, 5.4), Vector3(0, 0.18, 0),
		StationParts.steel(ChipFrameView.STEEL, 0.6))
	StationParts.box(root, "Leiste", Vector3(0.62, 0.02, 4.2), Vector3(0, 0.37, 0),
		StationParts.lit(GLASS))
	var windows: Array[Transform3D] = []
	for k in GameRun.ENERGY_ROW:
		windows.append(StationParts.cube(Vector3(0.38, 0.012, 0.6),
			Vector3(0, 0.385, (float(k) - float(GameRun.ENERGY_ROW - 1) * 0.5) * 0.78)))
	StationParts.swarm(root, "Fenster", windows, StationParts.lit(CasinoStyle.ENERGY))
	StationParts.cyl(root, "Lampe", 0.12, 0.03, Vector3(0, 0.38, 2.45), StationParts.lit(Color(0.1, 0.9, 0.4)), 16)
	return root

## Halbe Tiefe (Bild-oben/-unten) einer Ware - daran mißt, wann sie im Gehäuse verschwindet.
static func ware_reach(kind: String) -> float:
	match kind:
		GameRun.KIND_CHARM:
			return CharmProjectorView.assembly_reach()
		GameRun.KIND_DIE:
			return VitrineView.bowl_reach()
		GameRun.KIND_PART:
			return ComboPartBody.HULL.x * 0.5
		GameRun.KIND_PROJECTOR:
			return CharmReaderView.local_bounds().size.x * 0.5
		GameRun.KIND_POWERBANK:
			return 0.8
	return VitrineView.shelf_reach()

## Ob eine Ware höher ist, als das Gehäuse sie verbergen kann (dann zeigt sie sich nur ganz draußen).
static func ware_too_tall(kind: String) -> bool:
	return kind == GameRun.KIND_PROJECTOR

func _lay_ware(i: int) -> void:
	var body := _ware[i]
	if body == null:
		return
	var base := FLOOR_TOP + VitrineView.FLOOR_CLEAR
	match _ware_kind[i]:
		GameRun.KIND_DIE:
			body.position = Vector3(0, base + DieBuilder.HALF_EXTENT * DiceTrayView.DIE_SCALE, 0)
		GameRun.KIND_PROJECTOR:
			var mid := CharmReaderView.local_bounds().get_center()
			body.position = Vector3(-mid.x, base, -mid.z)
		GameRun.KIND_CHARM:
			body.position = Vector3(CharmProjectorView.origin_for(Vector3.ZERO).x, base, 0)
		_:
			body.position = Vector3(0, base, 0)
	if body is DataCellView:
		var cell := body as DataCellView
		cell.set_body_scale(PackDrawerView.CASSETTE_SCALE)
		cell.lie_on_glass(cell.global_position)

## Der Anteil, ab dem die Ware sichtbar ist: nur was höher ist als das Gehäuse, zeigt sich erst ganz draußen.
func ware_shown_share(kind: String) -> float:
	return 0.999 if ware_too_tall(kind) else 0.0

## Mitte der Ware längs der Fahrt: sie fährt mit ihrem Fach.
func ware_center(_kind: String, share: float) -> float:
	return _seat_x + _travel * (1.0 - share)

## Ob die Ware bei diesem Anteil zu sehen ist: unter dem Dach ist sie fort (ein Würfel schon
## beim ersten Stück, er zeichnet durch das Dach), hinter der Rückwand nie.
func ware_shown(kind: String, share: float) -> bool:
	if share < ware_shown_share(kind):
		return false
	var at := ware_center(kind, share)
	var reach := ware_reach(kind)
	if at + reach > _housing_back + 0.001:
		return false
	var edge := at + reach if kind == GameRun.KIND_DIE else at - reach
	return edge <= housing_front()

# --- Stellen ------------------------------------------------------------------------------

## Schreibt die Lage eines Fachs aus seinem Anteil (Endzustand jeder Fahrt ist ein Anteil).
func _place(i: int) -> void:
	if i >= _drawers.size():
		return
	_slides[i].position.x = _travel * (1.0 - _share[i])
	_lifts[i].position.y = HOVER_LIFT if i == _hovered and _share[i] >= 0.999 else 0.0
	if _ware[i] != null and is_instance_valid(_ware[i]):
		_ware[i].visible = ware_shown(_ware_kind[i], _share[i])
		var projector := _ware[i] as CharmProjectorView
		if projector != null:
			# Das Hologramm ist höher als das Gehäuse: es steht nur bei ganz offenem Fach.
			projector.set_projecting(_share[i] >= 0.999)
			projector.set_hovered(i == _hovered)

## Das Fach unter dem Zeiger hebt seine Ware leicht (-1 = keins).
func set_hovered(index: int) -> void:
	if index == _hovered:
		return
	var old := _hovered
	_hovered = index
	if old >= 0 and old < _drawers.size():
		_place(old)
	if index >= 0 and index < _drawers.size():
		_place(index)

## Gibt die Ware eines Fachs frei (Trage-Ware fliegt): sie hängt danach am Eltern-Knoten.
func release_ware(i: int) -> Node3D:
	if i < 0 or i >= BAYS or _ware[i] == null or not is_instance_valid(_ware[i]):
		return null
	var body := _ware[i]
	var projector := body as CharmProjectorView
	if projector != null:
		return _release_disk(projector)
	var at := body.global_transform
	body.get_parent().remove_child(body)
	get_parent().add_child(body)
	body.global_transform = at
	body.visible = true
	_ware[i] = null
	_ware_key[i] = ""
	_ware_kind[i] = ""
	return body

## Gekauft verläßt nur die Diskette den Projektor (sie gleitet erst aus dem Schlitz); der
## dunkle Projektor fährt mit dem leeren Fach ein.
func _release_disk(projector: CharmProjectorView) -> CharmDiskView:
	var disk := projector.get_node_or_null("Diskette") as CharmDiskView
	if disk == null:
		return null
	var at := disk.global_transform
	projector.remove_child(disk)
	get_parent().add_child(disk)
	disk.global_transform = at
	disk.visible = true
	disk.set_meta(&"pull_out", projector.mouth_global_transform())
	projector.set_charm(null)
	return disk

## Die Vorderkante des Gehäuses über Fach i (lokal) - dort startet das Licht der Lieferung.
func front_point(i: int) -> Vector3:
	if i < 0 or i >= _drawers.size():
		return Vector3.ZERO
	return to_global(Vector3(housing_front(), 0.0, _drawers[i].position.z))

# --- Fragen -------------------------------------------------------------------------------

func share(i: int) -> float:
	return _share[i]

func ware(i: int) -> Node3D:
	return _ware[i]

func ware_key(i: int) -> String:
	return _ware_key[i]

func writes() -> int:
	return _writes

func name_shown(i: int) -> String:
	return _names[i].text

func price_shown(i: int) -> String:
	return _prices[i].text

func bar_color(i: int) -> Color:
	return (_bars[i].material_override as StandardMaterial3D).albedo_color

func reroll_price_shown(i: int) -> String:
	return _key_prices[i].text

func reroll_lit(i: int) -> bool:
	return (_key_rims[i].material_override as StandardMaterial3D).albedo_color == Color(_look["trim"])

## Der Schub eines Fachs (ein Stück) - für Proben und Tests.
func slide(i: int) -> Node3D:
	return _slides[i]

## Der SICHTBARE Fußabdruck eines Fachs in lokalen Koordinaten (x Bild-oben, z Bild-rechts):
## was hinter der Rückwand läge, schneidet der Shader ab.
func drawer_footprint(i: int) -> AABB:
	var box := AABB()
	var first := true
	for child in _slides[i].find_children("*", "GeometryInstance3D", true, false):
		var mesh := child as GeometryInstance3D
		if not mesh.is_visible_in_tree() or mesh is Label3D:
			continue
		var local := global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		if clips(mesh):
			if local.position.x >= _housing_back:
				continue
			local.size.x = minf(_housing_back - local.position.x, local.size.x)
		box = local if first else box.merge(local)
		first = false
	return box

## Ob ein Teil an der Rückwand geschnitten wird (seine Haut trägt die Clip-Ebene).
func clips(mesh: GeometryInstance3D) -> bool:
	var material := mesh.material_override as ShaderMaterial
	return material != null and material.shader == SKIN_SHADER \
		and bool(material.get_shader_parameter("clip_on"))

## Die Rückwand des Gehäuses in Welt: Normale (Bild-oben) und Abstand.
func clip_plane() -> Plane:
	if not is_inside_tree():
		return Plane(Vector3.RIGHT, _housing_back)
	var normal := global_basis.x.normalized()
	return Plane(normal, normal.dot(to_global(Vector3(_housing_back, 0.0, 0.0))))

func housing_back() -> float:
	return _housing_back

func housing_front() -> float:
	return _seat_x + _travel * 0.5

# --- INFO-DISPLAY -------------------------------------------------------------------------

## Hängt den Inhalt des INFO-DISPLAYS in einen eigenen SubViewport und legt ihn aufs Dach.
func mount_info(content: Control) -> void:
	if _info_viewport == null:
		_info_viewport = SubViewport.new()
		_info_viewport.name = "InfoViewport"
		_info_viewport.disable_3d = true
		_info_viewport.transparent_bg = false
		_info_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_info_viewport)
	_info_viewport.size = Vector2i(content.size)
	_info_viewport.add_child(content)
	if _info_quad != null:
		_info_quad_material().albedo_texture = _info_viewport.get_texture()

## Das Pixel des INFO-DISPLAYS unter einem Strahl ((-1, -1) = daneben).
func info_pixel(origin: Vector3, direction: Vector3) -> Vector2:
	if _info_viewport == null or _info_quad == null or not is_visible_in_tree() \
			or _info_rect.size.x <= 0.0:
		return Vector2(-1, -1)
	var hit: Variant = Plane(Vector3.UP, _info_quad.global_position.y).intersects_ray(
		origin, direction)
	if hit == null:
		return Vector2(-1, -1)
	var local := to_local(hit as Vector3)
	var uv := (Vector2(local.z, -local.x) - _info_rect.position) / _info_rect.size
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return Vector2(-1, -1)
	return uv * Vector2(_info_viewport.size)

func _info_quad_material() -> StandardMaterial3D:
	return _info_quad.material_override as StandardMaterial3D

# --- Haut ---------------------------------------------------------------------------------

## Eine Haut des Entwurfs; clip = sie schneidet sich an der Rückwand ab.
func _skin(color: Color, clip := false, flat := false, brush := -1.0, gloss := -1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SKIN_SHADER
	material.set_shader_parameter("base", color)
	material.set_shader_parameter("brush", float(_look["brush"]) if brush < 0.0 else brush)
	material.set_shader_parameter("gloss", float(_look["gloss"]) if gloss < 0.0 else gloss)
	material.set_shader_parameter("flat_lit", flat)
	material.set_shader_parameter("clip_on", clip)
	if clip:
		_clip_mats.append(material)
	return material

func _sync_clip() -> void:
	if _clip_mats.is_empty():
		return
	var plane := clip_plane()
	var value := Vector4(plane.normal.x, plane.normal.y, plane.normal.z, plane.d)
	for material in _clip_mats:
		material.set_shader_parameter("clip_plane", value)

func _build_materials() -> void:
	var look := _look
	_mat = {
		"body": _skin(look["body"]),
		"top": _skin(look["top"]),
		"front": _skin(look["front"]),
		"metal": _skin(look["metal"], false, false, 0.5, 0.5),
		"screw": _skin(look["screw"], false, false, 0.0, 0.8),
		"gold": StationParts.steel(GOLD, 0.1, 0.05),
		"bevel": StationParts.lit(look["bevel"]),
		"seam": StationParts.lit(look["seam"]),
		"vent": StationParts.lit(look["vent"]),
		"mouth": StationParts.lit(look["mouth"]),
		"trim": StationParts.lit(look["trim"]),
		"glass": StationParts.lit(GLASS),
		# Der Schub: alles, was eingefahren hinter die Rückwand reicht, schneidet sich ab.
		"wall_clip": _skin(look["wall"], true),
		"metal_clip": _skin(look["metal"], true, false, 0.5, 0.5),
		"bevel_clip": _skin(look["bevel"], true, true),
		"seam_clip": _skin(look["seam"], true, true),
		"trim_clip": _skin(look["trim"], true, true),
		"screw_clip": _skin(look["screw"], true, false, 0.0, 0.8),
	}

# --- Bau ----------------------------------------------------------------------------------

func _build_housing(rect: Rect2, info: Rect2, bays: Array[Rect2]) -> void:
	var c := rect.get_center()
	StationParts.box(self, "Gehaeuse", Vector3(rect.size.y, HOUSING_HEIGHT, rect.size.x),
		_at(c, HOUSING_HEIGHT * 0.5), _mat["body"])
	StationParts.box(self, "Dach", Vector3(rect.size.y - 0.3, 0.02, rect.size.x - 0.3),
		_at(c, HOUSING_HEIGHT + 0.01), _mat["top"])
	# Glanzgrat rings um die Dachkante.
	StationParts.swarm(self, "Glanzgrat", StationParts.frame_boxes(Vector2(-c.y, c.x),
		Vector2(rect.size.y - 0.04, rect.size.x - 0.04), Vector2(rect.size.y - 0.14, rect.size.x - 0.14),
		HOUSING_HEIGHT + 0.012, 0.024), _mat["bevel"])
	StationParts.box(self, "Zierleiste", Vector3(0.1, 0.03, rect.size.x - 0.7),
		_at(Vector2(c.x, rect.end.y - 0.12), HOUSING_HEIGHT + 0.02), _mat["trim"])
	# Die Front: dunkle Mäuler über den Fächern, dazwischen Paneelfugen, darüber Lüftung.
	var front_x := -rect.end.y
	StationParts.box(self, "Front", Vector3(0.04, HOUSING_HEIGHT - 0.06, rect.size.x - 0.06),
		Vector3(front_x - 0.02, HOUSING_HEIGHT * 0.5, c.x), _mat["front"])
	var vents: Array[Transform3D] = []
	var seams: Array[Transform3D] = []
	for bay in bays:
		StationParts.box(self, "Maul", Vector3(0.05, 0.9, bay.size.x + 0.08),
			Vector3(front_x - 0.035, 0.45, bay.get_center().x), _mat["mouth"])
		var across := int((bay.size.x - 1.6) / 0.32)
		for k in across:
			var z := bay.get_center().x + (float(k) - float(across - 1) * 0.5) * 0.32
			vents.append(StationParts.cube(Vector3(0.03, 0.42, 0.12), Vector3(front_x - 0.045, 1.4, z)))
	for k in range(1, bays.size()):
		var z := (bays[k - 1].end.x + bays[k].position.x) * 0.5
		seams.append(StationParts.cube(Vector3(0.03, HOUSING_HEIGHT - 0.2, 0.05), Vector3(front_x - 0.045, HOUSING_HEIGHT * 0.5, z)))
	StationParts.swarm(self, "Lueftung", vents, _mat["vent"])
	StationParts.swarm(self, "Fugen", seams, _mat["seam"])
	StationParts.box(self, "FrontGrat", Vector3(0.03, 0.03, rect.size.x - 0.1),
		Vector3(front_x - 0.03, HOUSING_HEIGHT - 0.03, c.x), _mat["bevel"])
	# Schrauben an den Dachecken und auf der Front zwischen den Lüftungsfeldern.
	var screws: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			screws.append(_at(Vector2(c.x + sx * (rect.size.x * 0.5 - 0.3), c.y + sz * (rect.size.y * 0.5 - 0.25)),
				HOUSING_HEIGHT + 0.02))
	for k in range(1, bays.size()):
		var z := (bays[k - 1].end.x + bays[k].position.x) * 0.5
		for fy in [0.35, 1.6]:
			_screw_front(Vector3(front_x - 0.04, fy, z))
	for at in screws:
		StationParts.cyl(self, "Schraube", SCREW, 0.03, at, _mat["screw"], 12)
	_info_rect = info
	var ic := info.get_center()
	StationParts.swarm(self, "InfoRahmen", StationParts.frame_boxes(Vector2(-ic.y, ic.x),
		Vector2(info.size.y + 0.16, info.size.x + 0.16), Vector2(info.size.y, info.size.x),
		HOUSING_HEIGHT + 0.03, 0.04), _mat["metal"])
	var quad := PlaneMesh.new()
	quad.size = Vector2(info.size.x, info.size.y)
	_info_quad = MeshInstance3D.new()
	_info_quad.name = "InfoDisplay"
	_info_quad.mesh = quad
	# PlaneMesh liegt in XZ mit Breite längs X: so gedreht läuft u Bild-rechts, v Bild-unten.
	_info_quad.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), _at(ic, HOUSING_HEIGHT + 0.025))
	var screen := StandardMaterial3D.new()
	screen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.albedo_color = Color(0.92, 0.92, 0.92)
	screen.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_info_quad.material_override = screen
	_info_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_info_quad)

## Eine Schraube in einer senkrechten Fläche (Achse Bild-oben).
func _screw_front(at: Vector3) -> void:
	var node := StationParts.cyl(self, "FrontSchraube", SCREW, 0.03, at, _mat["screw"], 12)
	node.rotation.z = PI * 0.5

func _build_name_plate(i: int, rect: Rect2) -> void:
	var c := rect.get_center()
	StationParts.box(self, "Schild%d" % i, Vector3(rect.size.y, PLATE_HEIGHT, rect.size.x),
		_at(c, HOUSING_HEIGHT + PLATE_HEIGHT * 0.5), _mat["glass"])
	StationParts.swarm(self, "SchildRahmen%d" % i, StationParts.frame_boxes(Vector2(-c.y, c.x),
		Vector2(rect.size.y, rect.size.x), Vector2(rect.size.y - 0.12, rect.size.x - 0.12),
		HOUSING_HEIGHT + PLATE_HEIGHT + 0.01, 0.03), _mat["metal"])
	var label := StationParts.label(self, "Name%d" % i, "", _at(c, HOUSING_HEIGHT + PLATE_HEIGHT + 0.015),
		rect.size.y * 0.48, LABEL)
	label.set_meta(&"room", rect.size.x * 0.92)
	_names.append(label)

func _build_drawer(i: int, bay: Rect2, nose: Rect2, key: Rect2) -> void:
	var drawer := Node3D.new()
	drawer.name = "Fach%d" % i
	drawer.position = Vector3(0, 0, bay.get_center().x)
	add_child(drawer)
	_drawers.append(drawer)
	var back := bay.position.y
	var width := bay.size.x
	# Die Schienen auf dem Deck (fest, unter dem Fach).
	for side in [-1.0, 1.0]:
		StationParts.box(drawer, "Schiene%d" % int(side + 1.0),
			Vector3(nose.end.y - back, 0.012, 0.28),
			_at(Vector2(side * width * 0.32, (back + nose.end.y) * 0.5), 0.006), _mat["metal"])
	# Der SCHUB: Boden, Wände, Raster und Nase fahren als EIN Stück.
	var slide := Node3D.new()
	slide.name = "Schub"
	drawer.add_child(slide)
	_slides.append(slide)
	_build_tray(slide, Rect2(-width * 0.5, back, width, bay.size.y))
	_build_nose(i, slide, nose, Rect2(key.position - Vector2(bay.get_center().x, 0.0), key.size))
	var lift := Node3D.new()
	lift.name = "Hub"
	lift.position = Vector3(_seat_x, 0, 0)
	slide.add_child(lift)
	_lifts.append(lift)

## Die Schale: Leuchtboden mit Raster und Saum, Wände an drei Seiten mit Glanzgrat und
## Schrauben - alles schneidet sich an der Rückwand ab.
func _build_tray(host: Node3D, rect: Rect2) -> void:
	var c := rect.get_center()
	var floor_mat := _skin(_look["floor"], true, true)
	_floor_mats.append(floor_mat)
	StationParts.box(host, "Boden", Vector3(rect.size.y, FLOOR_TOP, rect.size.x - RIM * 2.0),
		_at(c, FLOOR_TOP * 0.5), floor_mat)
	var walls: Array[Transform3D] = []
	var grat: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var z: float = c.x + side * (rect.size.x - RIM) * 0.5
		walls.append(StationParts.cube(Vector3(rect.size.y, RIM_HEIGHT, RIM), _at(Vector2(z, c.y), RIM_HEIGHT * 0.5)))
		grat.append(StationParts.cube(Vector3(rect.size.y, 0.012, 0.04),
			_at(Vector2(z - side * (RIM * 0.5 - 0.03), c.y), RIM_HEIGHT + 0.006)))
	walls.append(StationParts.cube(Vector3(RIM, RIM_HEIGHT, rect.size.x),
		_at(Vector2(c.x, rect.position.y + RIM * 0.5), RIM_HEIGHT * 0.5)))
	StationParts.swarm(host, "Wand", walls, _mat["wall_clip"])
	StationParts.swarm(host, "WandGrat", grat, _mat["bevel_clip"])
	var dots: Array[Transform3D] = []
	var across := int(floor((rect.size.x - RIM * 2.0 - 0.3) / DOT_PITCH))
	var along := int(floor((rect.size.y - 0.3) / DOT_PITCH))
	for a in across:
		for b in along:
			var p := Vector2(c.x + (float(a) - float(across - 1) * 0.5) * DOT_PITCH,
				c.y + (float(b) - float(along - 1) * 0.5) * DOT_PITCH)
			dots.append(StationParts.cube(Vector3(0.07, 0.004, 0.07), _at(p, FLOOR_TOP + 0.002)))
	var dot_mat := _skin(_look["dot"], true, true)
	_dot_mats.append(dot_mat)
	StationParts.swarm(host, "Raster", dots, dot_mat)
	var seam: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		seam.append(StationParts.cube(Vector3(rect.size.y, 0.006, 0.08),
			_at(Vector2(c.x + side * (rect.size.x * 0.5 - RIM - 0.1), c.y), FLOOR_TOP + 0.003)))
	StationParts.swarm(host, "Saum", seam, _mat["trim_clip"])
	# Schrauben auf den Wandköpfen, in festem Abstand längs.
	var screws := 4
	for side in [-1.0, 1.0]:
		var z: float = c.x + side * (rect.size.x - RIM) * 0.5
		for k in screws:
			var y := rect.position.y + 0.6 + float(k) * (rect.size.y - 1.2) / float(screws - 1)
			StationParts.cyl(host, "WandSchraube", 0.06, 0.02, _at(Vector2(z, y), RIM_HEIGHT + 0.01),
				_mat["screw_clip"], 10)

## Die Nase: Griff, Preisfenster, Kauf-Leiste, Glanzgrat, Lüftung und die NEUWURF-TASTE.
func _build_nose(i: int, host: Node3D, nose: Rect2, key: Rect2) -> void:
	var nc := Vector2(0.0, nose.get_center().y)
	var width := nose.size.x - 0.05
	StationParts.box(host, "Nase", Vector3(nose.size.y, NOSE_HEIGHT, width),
		_at(nc, NOSE_HEIGHT * 0.5), _mat["body"])
	StationParts.box(host, "NaseGrat", Vector3(0.04, 0.03, width),
		_at(Vector2(0.0, nose.end.y - 0.02), NOSE_HEIGHT - 0.01), _mat["bevel"])
	StationParts.box(host, "Griff", Vector3(0.22, 0.08, 3.2),
		_at(Vector2(0.0, nose.end.y - 0.3), NOSE_HEIGHT + 0.04), _mat["metal"])
	for side in [-1.0, 1.0]:
		StationParts.box(host, "GriffFuss", Vector3(0.22, 0.06, 0.18),
			_at(Vector2(side * 1.5, nose.end.y - 0.3), NOSE_HEIGHT + 0.01), _mat["metal"])
	var bar := StationParts.box(host, "Leiste", Vector3(0.12, 0.02, nose.size.x - 0.5),
		_at(Vector2(0.0, nose.position.y + 0.18), NOSE_HEIGHT + 0.01), StationParts.lit(_look["trim"]))
	_bars.append(bar)
	var price_at := Vector2(-2.1, nc.y + 0.05)
	StationParts.box(host, "PreisGlas", Vector3(0.9, 0.04, 2.6), _at(price_at, NOSE_HEIGHT + 0.02), _mat["glass"])
	var price := StationParts.label(host, "Preis", "", _at(price_at, NOSE_HEIGHT + 0.045), 0.62, CasinoStyle.ENERGY)
	price.outline_size = 8
	price.outline_modulate = Color(CasinoStyle.ENERGY.r, CasinoStyle.ENERGY.g, CasinoStyle.ENERGY.b) * 0.5
	_prices.append(price)
	_bolts.append(_bolt(host, "Blitz", Vector2(-0.3, nc.y + 0.05), NOSE_HEIGHT + 0.03, BOLT))
	# Schrauben an den Nasen-Ecken, Lüftungsschlitze links neben dem Preis.
	for side in [-1.0, 1.0]:
		StationParts.cyl(host, "NasenSchraube", SCREW, 0.02,
			_at(Vector2(side * (width * 0.5 - 0.3), nc.y - 0.55), NOSE_HEIGHT + 0.01), _mat["screw"], 12)
	var slots: Array[Transform3D] = []
	for k in 4:
		slots.append(StationParts.cube(Vector3(0.6, 0.012, 0.08),
			_at(Vector2(-3.95 + float(k) * 0.16, nc.y + 0.05), NOSE_HEIGHT + 0.006)))
	StationParts.swarm(host, "NasenSchlitze", slots, _mat["vent"])
	_build_key(i, host, key)

## Die NEUWURF-TASTE: dunkle Glas-Taste mit Leuchtrahmen, Kreispfeil, Preis und Blitz.
func _build_key(_i: int, host: Node3D, key: Rect2) -> void:
	var kc := key.get_center()
	var top := NOSE_HEIGHT + KEY_HEIGHT
	StationParts.box(host, "Neuwurf", Vector3(key.size.y, KEY_HEIGHT, key.size.x),
		_at(kc, NOSE_HEIGHT + KEY_HEIGHT * 0.5), _mat["glass"])
	var rim := StationParts.swarm(host, "NeuwurfRahmen", StationParts.frame_boxes(Vector2(-kc.y, kc.x),
		Vector2(key.size.y, key.size.x), Vector2(key.size.y - 0.1, key.size.x - 0.1), top + 0.008, 0.016),
		StationParts.lit(_look["trim"]))
	_key_rims.append(rim)
	var arrow := _arrow(host, "Kreispfeil", Vector2(kc.x - key.size.x * 0.26, kc.y), top + 0.01, 0.27)
	_key_arrows.append(arrow)
	var price := StationParts.label(host, "NeuwurfPreis", "", _at(Vector2(kc.x + key.size.x * 0.08, kc.y), top + 0.015),
		0.62, CasinoStyle.ENERGY)
	_key_prices.append(price)
	_key_bolts.append(_bolt(host, "NeuwurfBlitz", Vector2(kc.x + key.size.x * 0.32, kc.y), top + 0.01, BOLT * 0.8))

## Ein flacher Kreispfeil (offener Ring mit Spitze), liegend.
func _arrow(host: Node3D, part: String, at: Vector2, y: float, radius: float) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var inner := radius * 0.62
	var steps := 18
	var start := deg_to_rad(50.0)
	var end := deg_to_rad(320.0)
	for k in steps:
		var a0 := lerpf(start, end, float(k) / float(steps))
		var a1 := lerpf(start, end, float(k + 1) / float(steps))
		var o0 := _ring_point(a0, radius)
		var o1 := _ring_point(a1, radius)
		var i0 := _ring_point(a0, inner)
		var i1 := _ring_point(a1, inner)
		verts.append_array(PackedVector3Array([o0, i0, o1, i0, i1, o1]))
	var tip_dir := Vector3(cos(end), 0.0, -sin(end))
	var mid := _ring_point(end, (radius + inner) * 0.5)
	var spread := (radius - inner) * 1.6
	var out := _ring_point(end, 1.0)
	verts.append_array(PackedVector3Array([mid + out * spread * 0.5, mid - out * spread * 0.5,
		mid + tip_dir * spread * 0.9]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.position = _at(at, y)
	var material := StationParts.lit(LABEL)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
	return node

## Punkt auf einem liegenden Kreis: 0° = Bild-rechts, gegen den Uhrzeigersinn im Bild.
static func _ring_point(angle: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)

## Ein Blitz aus drei schrägen Stegen - das Zeichen der Energie.
func _bolt(host: Node3D, part: String, at: Vector2, y: float, size: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part
	var mesh := ArrayMesh.new()
	var pts := PackedVector2Array([Vector2(0.15, -0.5), Vector2(-0.25, 0.05), Vector2(0.0, 0.05),
		Vector2(-0.15, 0.5), Vector2(0.25, -0.05), Vector2(0.0, -0.05)])
	var verts := PackedVector3Array()
	for tri in [[0, 1, 5], [1, 2, 5], [5, 2, 4], [2, 3, 4]]:
		for k: int in tri:
			verts.append(Vector3(-pts[k].y * size, 0.0, pts[k].x * size))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = mesh
	node.position = _at(at, y)
	node.material_override = StationParts.lit(CasinoStyle.ENERGY)
	(node.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
	return node

func _build_foot(contacts: Rect2) -> void:
	var cc := contacts.get_center()
	var pads: Array[Transform3D] = []
	for k in 4:
		pads.append(StationParts.cube(Vector3(0.18, 0.03, contacts.size.x),
			_at(Vector2(cc.x, contacts.position.y + 0.15 + float(k) * (contacts.size.y - 0.3) / 3.0), 0.015)))
	StationParts.swarm(self, "Kontakte", pads, _mat["gold"])

# --- Schrift und Licht --------------------------------------------------------------------

func _write_labels(i: int, bay: Dictionary) -> void:
	var state := String(bay.get("state", SecretShopView.STATE_EMPTY))
	var title := String(bay.get("name", SecretShopView.EMPTY_NAME))
	_names[i].text = title.to_upper()
	_names[i].font_size = _fit(_names[i], float(_names[i].get_meta(&"room")))
	_names[i].modulate = LABEL if state == SecretShopView.STATE_AFFORD else (RED
		if state == SecretShopView.STATE_SOLD else LABEL_DIM)
	var blocked := state == SecretShopView.STATE_BLOCKED
	var tag := SecretShopView.blocked_tag(String(bay.get("kind", ""))) if blocked else ""
	_prices[i].text = tag if blocked and tag != "" else String(bay.get("price", ""))
	_prices[i].font_size = _fit(_prices[i], 2.4)
	_prices[i].modulate = RED if blocked else (CasinoStyle.ENERGY if state == SecretShopView.STATE_AFFORD
		else CasinoStyle.ENERGY.darkened(0.6))
	_bolts[i].visible = not blocked and _prices[i].text != ""
	var bar_tint: Color = _look["trim"] if state == SecretShopView.STATE_AFFORD else (RED
		if state == SecretShopView.STATE_SOLD else _look["trim_dim"])
	(_bars[i].material_override as StandardMaterial3D).albedo_color = bar_tint
	var lit := state == SecretShopView.STATE_AFFORD
	_floor_mats[i].set_shader_parameter("base", _look["floor"] if lit else _look["floor_dim"])
	_dot_mats[i].set_shader_parameter("base", _look["dot"] if lit else _look["dot_dim"])

## Eine Zeile so groß wie die Breite (Welt) erlaubt, höchstens die gebaute Größe.
static func _fit(label: Label3D, width: float) -> int:
	return CharmDiskView.fit_line(label.text, width / label.pixel_size, StationParts.FONT_SIZE, 16)

## Die Neuwurf-Taste: hell, solange die Energie reicht, sonst gedimmt.
func _write_reroll(i: int, reroll: Dictionary) -> void:
	var afford := bool(reroll.get("afford", false))
	_key_prices[i].text = String(reroll.get("price", ""))
	_key_prices[i].modulate = CasinoStyle.ENERGY if afford else CasinoStyle.ENERGY.darkened(0.6)
	_key_bolts[i].visible = _key_prices[i].text != ""
	(_key_bolts[i].material_override as StandardMaterial3D).albedo_color = CasinoStyle.ENERGY \
		if afford else CasinoStyle.ENERGY.darkened(0.6)
	(_key_arrows[i].material_override as StandardMaterial3D).albedo_color = LABEL if afford else LABEL_DIM
	(_key_rims[i].material_override as StandardMaterial3D).albedo_color = _look["trim"] if afford \
		else _look["trim_dim"]
