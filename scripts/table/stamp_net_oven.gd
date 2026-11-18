class_name StampNetOven
extends RefCounted
## Der OFEN des Prägenetzes: er backt das Netz einer Kassette in eine Textur für
## ihre FLÄCHE. Gezeichnet wird mit dem EINEN 2D-Zeichner (PressNetView.stamp_net)
## in einen kleinen SubViewport - nicht-HDR, transparent_bg, disable_3d, die
## Technik der Glas-Ansicht in klein. Ein Netz steht ab der Erzeugung fest, also
## wird EINMAL gebacken und nie je Bild.
##
## Geteilt wird nach INHALT, nicht nach pack_uid: zwei gleiche Netze sind dasselbe
## Bild, und die uid sagt darüber nichts. Der ABGEDUNKELTE Zustand (die
## Serien-Zeremonie) gehört dagegen seiner Kassette - sie backt ihn selbst und gibt
## ihn wieder frei, sonst wüchse der geteilte Ofen mit jeder Zeremonie.

## Zellkante der Backung in Pixeln. Aus der Werkstatt-Weitsicht liegt die ganze
## Karte in wenigen Dutzend Bildschirmpixeln - mehr wäre Vorrat für nichts, weniger
## fräße die "+n" der Zellen.
const CELL := 34.0
## Die Kleider der Träger (dress).
const PUNCH_CELL := Color(0.02, 0.02, 0.026)
const PUNCH_MAX := 6
const TILE_SHEEN := 0.22
const GLAZE := Color(0.03, 0.034, 0.05)
const GLAZE_BARE := Color(0.13, 0.1, 0.075)
const CLAY_RIM := Color(0.09, 0.07, 0.05)
const GLAZE_SHEEN := 0.12
const HOLO_FILL := 0.12
const HOLO_BARE_RIM := 0.45

static var _ovens: Dictionary = {}
static var _holder: Node = null

## Kantenmaß der Backung - Quad und Textur teilen dieses Seitenverhältnis.
## Es gibt seit der Welle L nur noch EINE Backung: das Kreuz liegt hochkant im
## Rahmen (3 Zellen breit x 4 hoch), denn die Kassette ist an JEDEM Ort QUER
## gerollt und dreht es im Bild wieder auf. So füllt es die Karte fast ganz.
static func span() -> Vector2:
	var wanted := DieNetView.net_size(CELL)
	return Vector2(wanted.y, wanted.x)

static func size_px() -> Vector2i:
	var wanted := span()
	return Vector2i(maxi(int(ceilf(wanted.x)), 1), maxi(int(ceilf(wanted.y)), 1))

## Die geteilte Backung des RUHE-Zustands (null = der Baum nimmt gerade nichts auf;
## dann backt die Kassette selbst).
static func texture(net: Array, accent: Color, carrier := -1) -> Texture2D:
	var key := signature(net, accent, [], carrier)
	var known: SubViewport = _ovens.get(key)
	if known != null and is_instance_valid(known):
		return known.get_texture()
	var host := _shared_holder()
	if host == null:
		return null
	var oven := bake(net, accent, [], carrier)
	host.add_child(oven)
	_ovens[key] = oven
	return oven.get_texture()

## Ein EIGENER Ofen - der Aufrufer hängt ihn ein und gibt ihn frei. Für den
## abgedunkelten Zustand und als Rückfall, wenn der geteilte gerade fehlt.
static func bake(net: Array, accent: Color, drained: Array = [], carrier := -1) -> SubViewport:
	var oven := SubViewport.new()
	oven.name = "StampNetOven"
	oven.size = size_px()
	oven.transparent_bg = true
	oven.use_hdr_2d = false
	oven.disable_3d = true
	oven.render_target_update_mode = SubViewport.UPDATE_ONCE
	var drawing := PressNetView.stamp_net_upright(net, CELL, accent, drained)
	# Ohne Inhalt bleibt das leere Kreuz - aber in der Sortenfarbe: eine Kassette,
	# die ihr Paket noch nicht kennt (Wett-Gewinn), stünde sonst als schwarzes
	# Gitter da.
	if StampNet.is_blank(net):
		drawing.modulate = accent
	dress(drawing, net, accent, carrier)
	oven.add_child(drawing)
	return oven

## Das Netz-Bild je TRÄGER (DataCellView.CARRIER_*): dieselbe Zeichnung, nur die Zellen
## anders gekleidet - Lochkarte mit Stanzungen je Wert, Kassette mit Material-Kacheln,
## Tontafel mit glasierten Kacheln, Holo als Leuchtlinien. -1 = die schlichte Backung.
static func dress(drawing: Control, net: Array, accent: Color, carrier: int) -> void:
	if carrier < 0 or drawing.get_child_count() == 0:
		return
	var root := drawing.get_child(0)
	for face in StampNet.FACES:
		if face >= root.get_child_count():
			return
		var chip := root.get_child(face) as Panel
		if chip == null:
			continue
		var box := chip.get_theme_stylebox("panel") as StyleBoxFlat
		if box == null:
			continue
		var entry := StampNet.cell_at(net, face)
		var kind := StampNet.kind_of(entry)
		var filled := StampNet.is_filled(entry)
		match carrier:
			DataCellView.CARRIER_PUNCH:
				box.bg_color = PUNCH_CELL
				if not filled:
					box.border_color = accent.darkened(0.45)
				if kind == StampNet.KIND_VALUE or kind == StampNet.KIND_FACTOR:
					_punch_holes(chip, int(entry.get("value", 0)), accent)
			DataCellView.CARRIER_CASSETTE:
				if kind == StampNet.KIND_MATERIAL:
					box.border_color = accent
					_sheen(chip, TILE_SHEEN)
			DataCellView.CARRIER_CLAY:
				box.bg_color = GLAZE if filled else GLAZE_BARE
				box.border_color = accent.darkened(0.35) if filled else CLAY_RIM
				if filled:
					_sheen(chip, GLAZE_SHEEN)
			DataCellView.CARRIER_HOLO:
				box.bg_color = Color(accent.r, accent.g, accent.b,
					HOLO_FILL if filled else 0.0)
				box.border_color = Color(accent.r, accent.g, accent.b,
					1.0 if filled else HOLO_BARE_RIM)

## So viele Stanzungen, wie die Zelle wert ist (höchstens PUNCH_MAX), unter dem Wert -
## das Licht der Karte scheint hindurch.
static func _punch_holes(chip: Panel, amount: int, accent: Color) -> void:
	var count := clampi(absi(amount), 0, PUNCH_MAX)
	var width := CELL * 0.075
	var pitch := CELL * 0.12
	for k in count:
		var hole := ColorRect.new()
		hole.name = "Stanzung%d" % k
		hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hole.color = accent.lightened(0.3)
		hole.size = Vector2(width, CELL * 0.13)
		hole.position = Vector2(CELL * 0.5 + (float(k) - float(count - 1) * 0.5) * pitch
			- width * 0.5, CELL * 0.76)
		chip.add_child(hole)

## Ein Glanzstreif im oberen Drittel: aus der Zelle wird eine Kachel.
static func _sheen(chip: Panel, alpha: float) -> void:
	var band := ColorRect.new()
	band.name = "Glanz"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.color = Color(1.0, 1.0, 1.0, alpha)
	band.position = Vector2(CELL * 0.16, CELL * 0.12)
	band.size = Vector2(CELL * 0.68, CELL * 0.14)
	chip.add_child(band)

## Der Schlüssel einer Backung: Träger, Inhalt, Ton und Abdunkelung - ohne den Träger
## teilten zwei verschiedene Karten EINE Textur.
static func signature(net: Array, accent: Color, drained: Array, carrier := -1) -> String:
	var parts: Array[String] = ["%d" % carrier, accent.to_html(false)]
	for face in StampNet.FACES:
		var cell := StampNet.cell_at(net, face)
		var mark := "-" if not StampNet.is_filled(cell) else "%s:%s:%s" % [
			StampNet.kind_of(cell), String(cell.get("id", "")),
			str(cell.get("value", cell.get("to", 0)))]
		# Eine VERDICHTETE Zelle trägt mehr als kind:id:value. Fehlten ihre übrigen
		# Kanäle hier, teilten zwei verschiedene Karten EINE gebackene Textur.
		if StampNet.kind_of(cell) == StampNet.KIND_COMPOUND:
			mark += ":%d:%s:%s" % [int(cell.get("factor", 1)),
				String(cell.get("rune", "")), str(cell.get("dope", false))]
		if face < drained.size() and bool(drained[face]):
			mark += "!"
		parts.append(mark)
	return "|".join(parts)

static func _shared_holder() -> Node:
	if _holder != null and is_instance_valid(_holder):
		return _holder
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var holder := Node.new()
	holder.name = "StampNetOvens"
	tree.root.add_child(holder)
	if not holder.is_inside_tree():
		holder.free()  # der Baum nimmt gerade nichts auf
		return null
	_holder = holder
	return _holder
