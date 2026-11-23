class_name TableBankView
extends Node3D
## Die BANK des Hauses im freien Band der Wanne (Spieler-Wahl 2026-11-23 „Banktablett“): ein in
## Messing gefaßtes Tablett mit dem Bestand als ECHTE Körper - jedes Paket, jeder Würfel, jedes
## Modul, dazu Disketten und Chips. Reine Auslage: ohne Kollision, ohne Klickzone.
## Ebene (x, z): x = Bild-oben, z = Bild-rechts.

const GOLD := Color(0.86, 0.64, 0.24)
const VELVET := Color(0.035, 0.018, 0.045)
const LACQUER := Color(0.02, 0.02, 0.028)

const SCREEN_GLASS := Color(0.012, 0.014, 0.03)
const IDLE_TITLE := "BIBLIOTHEK"
const IDLE_TEXT := "Zeig auf einen Würfel oder ein Modul - hier steht, was es kann."
const PLAIN_TITLE := "Schlichter Würfel"
const PLAIN_TEXT := "Ohne Seele. Sechs Seiten, eins bis sechs."
const HOVER_LIFT := 0.45
const PICK_PAD := 0.12

const RIM := 0.5
const RIM_HEIGHT := 0.6
const BED_Y := 0.07
## Luft des Tabletts im Band (x, z).
const INSET := Vector2(0.6, 1.0)
## Je Fach unten ein Band für sein Schild.
const LABEL_BAND := 1.4
const SIDE_AIR := 0.3
const ROW_GAP := 0.6
## Reihen von Bild-oben nach Bild-unten: Tiefe samt Schild-Band und die Fächer mit ihrem Anteil
## an der Breite (von Bild-links). "head" bleibt oben frei: die Paket-Türme ragen im Bild
## über ihre Reihe und deckten sonst das Schild darüber.
## Das Fach des BIBLIOTHEKS-SCHIRMS: ohne Schild, zwischen Würfeln und Modulen.
const SCREEN := "SCHIRM"
const ROWS := [
	{"depth": 7.4, "cells": [["CHARMS", 1.0]]},
	{"depth": 15.2, "head": 2.4, "cells": [["PAKETE", 1.0]]},
	{"depth": 9.4, "cells": [["WÜRFEL", 1.0]]},
	{"depth": 6.6, "bare": true, "cells": [[SCREEN, 1.0]]},
	{"depth": 10.4, "cells": [["CHIPS", 0.58], ["MODULE", 0.42]]},
]

const PACK_COLUMNS := 4
const PACK_THICKNESS := CardPackView.CASSETTE_THICKNESS * PackDrawerView.CASSETTE_SCALE
const DICE_ACROSS := 11
const DIE_HALF := DieBuilder.HALF_EXTENT * DiceTrayView.DIE_SCALE
const MODULES_ACROSS := 4
const DISK_RACKS := 3
const DISKS_PER_RACK := 5
const DISK_TILT := 1.1
const DISK_PITCH := 0.4
## Chips je Rolle, von den 1ern (links) zu den 10.000ern.
const ROLL_COUNTS := [30, 27, 24, 20, 16, 11, 6]

var _items: Array[Dictionary] = []
var _shown := -1
var _title: Label3D
var _meta: Label3D
var _text: Label3D

static var _materials := {}
static var _looks := {}

## So tief, wie die Reihen samt Fuge brauchen, mittig im Band.
static func tray_rect(band: Rect2) -> Rect2:
	var depth := ROWS.size() * ROW_GAP
	for row: Dictionary in ROWS:
		depth += float(row["depth"])
	depth = minf(depth, band.size.x - INSET.x * 2.0)
	return Rect2(band.get_center().x - depth * 0.5, band.position.y + INSET.y, depth,
		band.size.y - INSET.y * 2.0)

static func row_gap(tray: Rect2) -> float:
	var used := 0.0
	for row: Dictionary in ROWS:
		used += float(row["depth"])
	return (tray.size.x - used) / float(ROWS.size())

## Die Nutzfläche je Fach (ohne Schild-Band), Name -> Rect2.
static func section_rects(tray: Rect2) -> Dictionary:
	var gap := row_gap(tray)
	var out := {}
	var top := tray.end.x - gap * 0.5
	for row: Dictionary in ROWS:
		var depth: float = row["depth"]
		var z := tray.position.y
		for cell: Array in row["cells"]:
			var width := tray.size.y * float(cell[1])
			var band := 0.0 if row.get("bare", false) else LABEL_BAND
			out[cell[0]] = Rect2(top - depth + band, z + SIDE_AIR,
				depth - band - SIDE_AIR - float(row.get("head", 0.0)), width - SIDE_AIR * 2.0)
			z += width
		top -= depth + gap
	return out

## Die Pakete des Ladens in ihrer Grundstufe (Spieler-Wunsch 2026-11-23: ohne Edel und Royal):
## je Stapel eine Sorte, darin alle Größen.
static func pack_stacks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sort: String in [CardPack.SORT_NUMBER, CardPack.SORT_MATERIAL, CardPack.SORT_RUNE,
			CardPack.SORT_SPECIAL]:
		out.append({"kind": "card", "sort": sort, "level": DicePack.QUALITY_STANDARD, "sizes": CardPack.SIZES})
	for sort: String in [DicePack.SORT_NORMAL, DicePack.SORT_SOUL, DicePack.SORT_MATERIAL,
			DicePack.SORT_RUNE]:
		out.append({"kind": "dice", "sort": sort, "level": DicePack.QUALITY_STANDARD, "sizes": DicePack.SIZES})
	out.append({"kind": "module", "sort": "", "level": ModulePack.GRADE_COMMON, "sizes": CardPack.SIZES})
	return out

## Ein schlichter Würfel und einer je Seele.
static func dice_stock() -> Array[DieDefinition]:
	var out: Array[DieDefinition] = [DieDefinition.standard()]
	for essence in Essence.all():
		var def := DieDefinition.standard()
		def.essence_id = essence.id
		out.append(def)
	return out

func _ready() -> void:
	var tray := tray_rect(TableBodyView.free_band())
	_build_tray(tray)
	# Die geteilten Öfen der Körper hängen an der Wurzel - die baut beim Laden noch.
	_build_screen(section_rects(tray)[SCREEN])
	_build_stock.call_deferred(section_rects(tray))

func _build_stock(rects: Dictionary) -> void:
	_build_disks(rects["CHARMS"])
	_build_packs(rects["PAKETE"])
	_build_dice(rects["WÜRFEL"])
	_build_modules(rects["MODULE"])
	_build_chips(rects["CHIPS"])

# --- Tablett ---------------------------------------------------------------------------

## Der Grundriß des Tabletts samt Rahmen (Welt x, z) - Kamera-Rahmen und Klickzone.
static func frame_rect() -> Rect2:
	return tray_rect(TableBodyView.free_band()).grow(RIM)

## Was die Station rahmt (Welt x, z): Würfel, Schirm und die Reihe mit den Modulen.
static func library_rect() -> Rect2:
	var tray := tray_rect(TableBodyView.free_band())
	var rects := section_rects(tray)
	var foot := (rects["MODULE"] as Rect2).position.x - LABEL_BAND
	return Rect2(foot, tray.position.y, (rects["WÜRFEL"] as Rect2).end.x - foot, tray.size.y)

func _build_tray(tray: Rect2) -> void:
	var mid := tray.get_center()
	_box("Bett", Vector3(tray.size.x, 0.06, tray.size.y), Vector3(mid.x, BED_Y - 0.03, mid.y), _mat(VELVET, 0.1))
	for s: float in [-1.0, 1.0]:
		_box("RahmenZ", Vector3(tray.size.x + RIM * 2.0, RIM_HEIGHT, RIM),
			Vector3(mid.x, RIM_HEIGHT * 0.5, mid.y + s * (tray.size.y + RIM) * 0.5), _mat(GOLD, 0.8))
		_box("RahmenX", Vector3(RIM, RIM_HEIGHT, tray.size.y),
			Vector3(mid.x + s * (tray.size.x + RIM) * 0.5, RIM_HEIGHT * 0.5, mid.y), _mat(GOLD, 0.8))
	var rects := section_rects(tray)
	var gap := row_gap(tray)
	for name: String in rects:
		var rect: Rect2 = rects[name]
		var band := 0.0 if name == SCREEN else LABEL_BAND
		if band > 0.0:
			_label(name, Vector3(rect.position.x - band * 0.5, BED_Y + 0.02, rect.get_center().y), 0.9)
		var foot := rect.position.x - band - gap * 0.5
		if foot > tray.position.x + 0.5:
			_box("Steg", Vector3(0.22, 0.34, rect.size.y + SIDE_AIR * 2.0),
				Vector3(foot, 0.17, rect.get_center().y), _mat(GOLD, 0.8))
		var side := rect.position.y - SIDE_AIR
		if side > tray.position.y + 0.5:
			_box("Steg", Vector3(rect.size.x + LABEL_BAND + SIDE_AIR, 0.34, 0.22),
				Vector3(rect.end.x - (rect.size.x + LABEL_BAND) * 0.5, 0.17, side), _mat(GOLD, 0.8))

# --- Bestand ---------------------------------------------------------------------------

## Leere Disketten, fast aufrecht in der Kartei; sie steht am Fuß des Fachs, weil sie hoch ragt.
func _build_disks(rect: Rect2) -> void:
	var lean := Basis(Vector3(0, 0, 1), DISK_TILT)
	var half := CharmDiskView.SIZE.x * 0.5
	var reach := CharmDiskView.SIZE.x * cos(DISK_TILT) + (DISKS_PER_RACK - 1) * DISK_PITCH
	var start := rect.position.x + 0.4
	for rack in DISK_RACKS:
		var z := rect.position.y + rect.size.y * (rack + 0.5) / DISK_RACKS
		_box("Karteifuss", Vector3(reach + 0.6, 0.3, CharmDiskView.SIZE.z + 0.5),
			Vector3(start + reach * 0.5, BED_Y + 0.15, z), _mat(LACQUER, 0.9))
		for i in DISKS_PER_RACK:
			var disk := CharmDiskView.new()
			disk.name = "Diskette%d_%d" % [rack, i]
			add_child(disk)
			disk.basis = lean
			disk.position = Vector3(start + i * DISK_PITCH, BED_Y + 0.3, z) + lean.x * half

func _build_packs(rect: Rect2) -> void:
	var stacks := pack_stacks()
	var hulls: Array[Node3D] = []
	var covered: Array[bool] = []
	@warning_ignore("integer_division")
	var rows := (stacks.size() + PACK_COLUMNS - 1) / PACK_COLUMNS
	for i in stacks.size():
		var stack := stacks[i]
		@warning_ignore("integer_division")
		var row := i / PACK_COLUMNS
		var x := rect.end.x - rect.size.x * (row + 0.5) / rows
		var z := rect.position.y + rect.size.y * (i % PACK_COLUMNS + 0.5) / PACK_COLUMNS
		var y := BED_Y
		var sizes: Array = stack["sizes"]
		for k in sizes.size():
			var hull := CardPackView.new()
			hull.name = "Paket%d_%d" % [i, k]
			add_child(hull)
			if stack["kind"] == "module":
				hull.setup_module_bag(sizes[k], stack["level"])
			else:
				hull.setup_pack(stack["sort"], sizes[k], stack["kind"] == "dice", stack["level"])
			hull.rotation.y = -PI / 2.0
			hull.badge_on_face = true
			hull.set_body_scale(PackDrawerView.CASSETTE_SCALE)
			hull.position = Vector3(x, y, z)
			hull.set_process(false)
			hulls.append(hull)
			covered.append(k < sizes.size() - 1)
			y += _hull_height(stack, k)
	# Die Hüllen bauen Teile verzögert (Netz-Öfen, Karten): erst danach steht ihr Bild.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		_bake(hulls, covered)

static func _hull_height(stack: Dictionary, k: int) -> float:
	if stack["kind"] == "module":
		return float(CardPackView.BAG_THICKNESS[k]) * PackDrawerView.CASSETTE_SCALE
	return PACK_THICKNESS

func _build_dice(rect: Rect2) -> void:
	var defs := dice_stock()
	@warning_ignore("integer_division")
	var rows := (defs.size() + DICE_ACROSS - 1) / DICE_ACROSS
	for i in defs.size():
		@warning_ignore("integer_division")
		var row := i / DICE_ACROSS
		var die := FloatingDie.build_ghost(defs[i])
		die.name = "Wuerfel%d" % i
		add_child(die)
		(die.get_node("RigidBody3D/Faces") as DieFaceDisplay).set_pool_enabled(false)
		die.position = Vector3(rect.end.x - rect.size.x * (row + 0.5) / rows, BED_Y + DIE_HALF,
			rect.position.y + rect.size.y * (i % DICE_ACROSS + 0.5) / DICE_ACROSS)
		var soul := Essence.by_id(defs[i].essence_id) if defs[i].essence_id != "" else null
		_items.append({"node": die, "rest": die.position, "half": Vector2(DIE_HALF, DIE_HALF),
			"top": BED_Y + DIE_HALF * 2.0, "kind": "Würfel",
			"title": soul.display_name if soul != null else PLAIN_TITLE,
			"text": soul.description if soul != null else PLAIN_TEXT,
			"meta": Essence.rarity_name(soul.rarity) if soul != null else "",
			"tint": _readable(soul.glow) if soul != null else Color.WHITE})

func _build_modules(rect: Rect2) -> void:
	var parts := ComboPart.all()
	@warning_ignore("integer_division")
	var rows := (parts.size() + MODULES_ACROSS - 1) / MODULES_ACROSS
	for i in parts.size():
		@warning_ignore("integer_division")
		var row := i / MODULES_ACROSS
		var pin := ComboPartBody.new()
		pin.name = "Modul%d" % i
		add_child(pin)
		pin.setup(parts[i])
		pin.position = Vector3(rect.end.x - rect.size.x * (row + 0.5) / rows, BED_Y,
			rect.position.y + rect.size.y * (i % MODULES_ACROSS + 0.5) / MODULES_ACROSS)
		_items.append({"node": pin, "rest": pin.position,
			"half": Vector2(ComboPartBody.HULL.y, ComboPartBody.HULL.x) * 0.5,
			"top": BED_Y + ComboPartBody.HULL.z, "kind": "Modul", "title": parts[i].display_name,
			"text": parts[i].description, "meta": parts[i].rarity_name(),
			"tint": parts[i].rarity_color()})

## Liegende Rollen wie im Rack eines Dealers: je Stückelung eine Rinne, die 1er links.
func _build_chips(rect: Rect2) -> void:
	var values := ChipTrayView.VALUES
	var pitch := rect.size.y / values.size()
	var step := ChipStackView.CHIP_HEIGHT + 0.02
	var stand := Basis(Vector3(0, 0, 1), PI * 0.5)
	for rank in values.size():
		var z := rect.position.y + pitch * (rank + 0.5)
		var sample := ChipStackView.make_chip(values[rank], false)
		var body := sample.get_child(0) as MeshInstance3D
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = body.mesh
		multi.instance_count = mini(ROLL_COUNTS[rank], int(rect.size.x / step))
		for k in multi.instance_count:
			multi.set_instance_transform(k, Transform3D(stand,
				Vector3(rect.position.x + (k + 0.5) * step, BED_Y + ChipStackView.CHIP_RADIUS, z)))
		var roll := MultiMeshInstance3D.new()
		roll.name = "Rolle%d" % rank
		roll.multimesh = multi
		roll.material_override = body.material_override
		roll.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(roll)
		sample.free()
		if rank > 0:
			_box("Rinnensteg", Vector3(rect.size.x, 0.5, 0.12),
				Vector3(rect.get_center().x, BED_Y + 0.25, z - pitch * 0.5), _mat(GOLD, 0.8))

# --- Bibliothek ------------------------------------------------------------------------

## Der Schirm zwischen Würfeln und Modulen: er nennt, was der Zeiger trifft. Ein Label3D
## richtet an seinem Ursprung aus - links beginnt die Zeile dort, rechts endet sie dort.
func _build_screen(rect: Rect2) -> void:
	var mid := rect.get_center()
	var size := Vector2(rect.size.x - 0.5, rect.size.y - 0.4)
	_box("SchirmRahmen", Vector3(size.x + 0.3, 0.3, size.y + 0.3), Vector3(mid.x, BED_Y + 0.15, mid.y), _mat(GOLD, 0.8))
	_box("Schirm", Vector3(size.x, 0.34, size.y), Vector3(mid.x, BED_Y + 0.17, mid.y), _mat(SCREEN_GLASS, 0.15))
	var y := BED_Y + 0.36
	var width := size.y - 1.2
	_title = _screen_line("SchirmTitel", Vector3(mid.x + size.x * 0.5 - 1.0, y, mid.y - width * 0.5), 1.0, width)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_meta = _screen_line("SchirmArt", Vector3(mid.x + size.x * 0.5 - 1.0, y, mid.y + width * 0.5), 0.62, width)
	_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text = _screen_line("SchirmText", Vector3(mid.x - 0.75, y, mid.y - width * 0.5), 0.72, width)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	show_item(-1)

func _screen_line(part: String, pos: Vector3, height: float, width: float) -> Label3D:
	var node := Label3D.new()
	node.name = part
	node.font_size = 96
	node.pixel_size = height / 68.0
	node.width = width / node.pixel_size
	node.outline_size = 0
	add_child(node)
	node.position = pos
	node.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	return node

static func _readable(color: Color) -> Color:
	return color.lightened(0.5) if color.get_luminance() < 0.35 else color

func item_count() -> int:
	return _items.size()

func item_title(index: int) -> String:
	return String(_items[index]["title"])

func item_ray(index: int) -> Vector3:
	return to_global((_items[index]["rest"] as Vector3) * Vector3(1, 0, 1) + Vector3.UP * float(_items[index]["top"]))

func shown_item() -> int:
	return _shown

func screen_text() -> String:
	return "%s\n%s\n%s" % [_title.text, _meta.text, _text.text]

## Welcher Würfel oder welches Modul liegt unter dem Strahl? -1 = keiner.
func item_at(origin: Vector3, dir: Vector3) -> int:
	if absf(dir.y) < 0.0001:
		return -1
	var local_origin := to_local(origin)
	var local_dir := global_transform.basis.inverse() * dir
	var best := -1
	var nearest := INF
	for i in _items.size():
		var item := _items[i]
		var t := (float(item["top"]) - local_origin.y) / local_dir.y
		if t <= 0.0 or t >= nearest:
			continue
		var hit := local_origin + local_dir * t
		var rest: Vector3 = item["rest"]
		var half: Vector2 = item["half"]
		if absf(hit.x - rest.x) <= half.x + PICK_PAD and absf(hit.z - rest.z) <= half.y + PICK_PAD:
			best = i
			nearest = t
	return best

## Der EINE Schreiber von Schirm und Griff; -1 = Ruhebild.
func show_item(index: int) -> void:
	var wanted := index if index >= 0 and index < _items.size() else -1
	if wanted == _shown and _title.text != "":
		return
	if _shown >= 0 and _shown < _items.size():
		_lift(_items[_shown], false)
	_shown = wanted
	if _shown < 0:
		_title.text = IDLE_TITLE
		_title.modulate = GOLD
		_meta.text = ""
		_text.text = IDLE_TEXT
		_text.modulate = Color(0.62, 0.64, 0.72)
		return
	var item := _items[_shown]
	_lift(item, true)
	_title.text = item["title"]
	_title.modulate = item["tint"]
	_meta.text = "%s · %s" % [item["kind"], item["meta"]] if item["meta"] != "" else String(item["kind"])
	_meta.modulate = (item["tint"] as Color).lerp(Color.WHITE, 0.4)
	_text.text = item["text"]
	_text.modulate = Color(0.9, 0.92, 0.98)

func _lift(item: Dictionary, on: bool) -> void:
	var node: Node3D = item["node"]
	if not is_instance_valid(node):
		return
	var rest: Vector3 = item["rest"]
	create_tween().tween_property(node, "position",
		rest + (Vector3.UP * HOVER_LIFT if on else Vector3.ZERO), 0.12)

## Die Pakete stehen still: ihre Netze verschmelzen je Material zu EINEM (gemessen 10 920
## Netze und +7 400 Zeichenaufrufe ohne das). Von einer überdeckten Hülle bleibt nur, was
## an ihren Rand reicht. Schrift und anderes zieht um, die Hüllen selbst sind danach fort.
func _bake(hulls: Array[Node3D], covered: Array[bool]) -> void:
	var holder := Node3D.new()
	holder.name = "Pakete"
	add_child(holder)
	var to_bank := global_transform.affine_inverse()
	var groups := {}
	for i in hulls.size():
		var visuals: Array[VisualInstance3D] = []
		var boxes: Array[AABB] = []
		var hull_box := AABB()
		for node in hulls[i].find_children("*", "VisualInstance3D", true, false):
			var visual := node as VisualInstance3D
			if not visual.is_visible_in_tree():
				continue
			var box := (to_bank * visual.global_transform) * visual.get_aabb()
			hull_box = box if visuals.is_empty() else hull_box.merge(box)
			visuals.append(visual)
			boxes.append(box)
		for j in visuals.size():
			if covered[i] and not _reaches_rim(boxes[j], hull_box):
				continue
			var mesh_node := visuals[j] as MeshInstance3D
			if mesh_node == null or mesh_node.mesh == null or not _mergeable(mesh_node.mesh):
				visuals[j].reparent(holder)
				continue
			_collect(groups, mesh_node, to_bank * mesh_node.global_transform)
		hulls[i].queue_free()
	var index := 0
	_looks.clear()
	for group: Dictionary in groups.values():
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, group["arrays"])
		var node := MeshInstance3D.new()
		node.name = "Netz%d" % index
		node.mesh = mesh
		node.material_override = group["material"]
		node.material_overlay = group["overlay"]
		node.layers = group["layers"]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(node)
		index += 1

static func _reaches_rim(box: AABB, hull: AABB) -> bool:
	const EDGE := 0.06
	return box.position.x <= hull.position.x + EDGE or box.end.x >= hull.end.x - EDGE 		or box.position.z <= hull.position.z + EDGE or box.end.z >= hull.end.z - EDGE

static func _mergeable(mesh: Mesh) -> bool:
	for s in mesh.get_surface_count():
		if not mesh is PrimitiveMesh and (mesh as ArrayMesh) != null 				and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false
	return mesh.get_surface_count() > 0

## Der INHALT eines Materials als Schlüssel: jede Hülle baut ihre eigenen, gleich aussehenden.
static func _look(material: Material) -> String:
	if material == null:
		return ""
	var id := material.get_instance_id()
	if not _looks.has(id):
		var parts := PackedStringArray([material.get_class()])
		for prop: Dictionary in material.get_property_list():
			if not (int(prop["usage"]) & PROPERTY_USAGE_STORAGE):
				continue
			var value: Variant = material.get(prop["name"])
			parts.append(str(value.get_instance_id()) if value is Object else var_to_str(value))
		_looks[id] = "|".join(parts)
	return _looks[id]

## Hängt die Flächen eines Netzes, in den Raum der Bank gerechnet, an die Gruppe ihres Materials.
static func _collect(groups: Dictionary, node: MeshInstance3D, xf: Transform3D) -> void:
	var turn := xf.basis.inverse().transposed()
	var mirrored := xf.basis.determinant() < 0.0
	for s in node.mesh.get_surface_count():
		var arrays := node.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var material := node.get_active_material(s)
		var format := 0
		for kind: int in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV,
				Mesh.ARRAY_TEX_UV2]:
			if arrays[kind] != null and arrays[kind].size() > 0:
				format |= 1 << kind
		var key := [_look(material), _look(node.material_overlay), node.layers, format]
		if not groups.has(key):
			var fresh := []
			fresh.resize(Mesh.ARRAY_MAX)
			fresh[Mesh.ARRAY_VERTEX] = PackedVector3Array()
			fresh[Mesh.ARRAY_INDEX] = PackedInt32Array()
			for kind: int in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR,
					Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
				if format & (1 << kind):
					fresh[kind] = arrays[kind].duplicate()
					fresh[kind].clear()
			groups[key] = {"material": material, "overlay": node.material_overlay,
				"layers": node.layers, "arrays": fresh}
		var into: Array = groups[key]["arrays"]
		var base: int = into[Mesh.ARRAY_VERTEX].size()
		for v in verts:
			into[Mesh.ARRAY_VERTEX].append(xf * v)
		if format & (1 << Mesh.ARRAY_NORMAL):
			for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
				into[Mesh.ARRAY_NORMAL].append((turn * n).normalized())
		if format & (1 << Mesh.ARRAY_TANGENT):
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for t in range(0, tangents.size(), 4):
				var dir := (xf.basis * Vector3(tangents[t], tangents[t + 1], tangents[t + 2])).normalized()
				into[Mesh.ARRAY_TANGENT].append_array(PackedFloat32Array([dir.x, dir.y, dir.z, tangents[t + 3]]))
		for kind: int in [Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
			if format & (1 << kind):
				into[kind].append_array(arrays[kind])
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0:
			indices = arrays[Mesh.ARRAY_INDEX]
		else:
			indices.resize(verts.size())
			for k in verts.size():
				indices[k] = k
		for k in range(0, indices.size() - 2, 3):
			var b := indices[k + 2] if mirrored else indices[k + 1]
			var c := indices[k + 1] if mirrored else indices[k + 2]
			into[Mesh.ARRAY_INDEX].append_array(PackedInt32Array([base + indices[k], base + b, base + c]))

# --- Bausteine -------------------------------------------------------------------------

static func _mat(color: Color, gloss: float) -> ShaderMaterial:
	var key := "%s|%s" % [color, gloss]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = TableBodyView.SHADER
		m.set_shader_parameter("tint", color)
		m.set_shader_parameter("gloss", gloss)
		_materials[key] = m
	return _materials[key]

func _box(part: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position = pos

## Schild flach auf dem Bett, von der Spielerseite zu lesen.
func _label(text: String, pos: Vector3, height: float) -> void:
	var node := Label3D.new()
	node.name = "Schild_%s" % text
	node.text = text
	node.font_size = 96
	node.pixel_size = height / 68.0
	node.modulate = GOLD
	node.outline_size = 0
	add_child(node)
	node.position = pos
	node.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
