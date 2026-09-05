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
static func texture(net: Array, accent: Color) -> Texture2D:
	var key := signature(net, accent, [])
	var known: SubViewport = _ovens.get(key)
	if known != null and is_instance_valid(known):
		return known.get_texture()
	var host := _shared_holder()
	if host == null:
		return null
	var oven := bake(net, accent, [])
	host.add_child(oven)
	_ovens[key] = oven
	return oven.get_texture()

## Ein EIGENER Ofen - der Aufrufer hängt ihn ein und gibt ihn frei. Für den
## abgedunkelten Zustand und als Rückfall, wenn der geteilte gerade fehlt.
static func bake(net: Array, accent: Color, drained: Array = []) -> SubViewport:
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
	oven.add_child(drawing)
	return oven

## Der Schlüssel einer Backung: ihr Inhalt, ihr Ton und ihre Abdunkelung. Eine
## Orientierung steht nicht mehr darin - es gibt nur noch die eine.
static func signature(net: Array, accent: Color, drained: Array) -> String:
	var parts: Array[String] = [accent.to_html(false)]
	for face in StampNet.FACES:
		var cell := StampNet.cell_at(net, face)
		var mark := "-" if not StampNet.is_filled(cell) else "%s:%s:%s" % [
			StampNet.kind_of(cell), String(cell.get("id", "")),
			str(cell.get("value", cell.get("to", 0)))]
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
