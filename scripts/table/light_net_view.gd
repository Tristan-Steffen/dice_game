class_name LightNetView
extends Node3D
## DAS LICHT-NETZ des DURCHLICHTS (Welle X, 2026-09-05): ein reines HOLOGRAMM, das
## auf der steigenden Licht-Ebene des Turms REITET. Je durchlaufener Etage nimmt es
## deren Zellen auf; oben angekommen zerfällt es in seine LICHTFUNKEN.
##
## Es ist derselbe Ofen wie eh und je (der EINE 2D-Zeichner
## PressNetView.stamp_net_upright in einem eigenen SubViewport), aber es hat KEINEN
## Körper und kein Glas mehr: nur ein additives Quad. Und eine NULL-Zelle ist
## UNSICHTBAR statt dunkel - was leuchtet, wird benutzt.
##
## Reine Anzeige: gerechnet hat SeriesResolver, gebucht GameRun - längst.

## Stufen des Zähl-Takts. Die Ziffern LAUFEN, aber jede Stufe ist eine Backung -
## vier lesen als Zählen und kosten vier Bilder, nicht dreißig.
const TICK_STEPS := 4
## Der perkussive Schlag eines Operators: so weit schwillt er an, so lange klingt
## es ab. Eine WERT-Karte bekommt denselben Schlag, nur kleiner.
const PUNCH_PEAK := 1.34
const STRIKE_PEAK := 1.12
const PUNCH_TIME := 0.34
## Die Glyphe des Schlags: Anteil der Netzfläche, den sie einnimmt, und Standzeit.
const GLYPH_SHARE := 0.52
const GLYPH_TIME := 0.42
const GLYPH_TEXTURE := 128
## Das Hologramm steht eine Spur ÜBER der Licht-Ebene, sonst stritten sie im
## Tiefenpuffer.
const NET_PROUD := DataCellView.NET_PROUD * 3.0
## Es ist LICHT: additiv, mit weißem Kern über der Sortenfarbe.
const NET_ALPHA := 0.95
const NET_ENERGY := 1.3

## Der Ton des Netzes (leere Zellen bleiben unsichtbar).
var accent := PressNetView.VALUE_TINT
var accent_energy := 1.0

var _body: Node3D
var _net: MeshInstance3D
var _net_material: StandardMaterial3D
var _oven: SubViewport
## Die Glyphe des Operator-Schlags - erst beim ersten Schlag gebaut.
var _glyph: MeshInstance3D
var _glyph_material: StandardMaterial3D
var _glyph_oven: SubViewport
var _glyph_label: Label

## Was auf ihm STEHT, woher der Takt lief und wohin (Bonus je Seite).
var _values: Array[int] = []
var _from: Array[int] = []
var _goal: Array[int] = []
var _scale := 1.0
var _glyph_fade := 0.0
var _tick: Tween
var _beat: Tween

func _init() -> void:
	name = "LightNet"

## Maß des Hologramms: die Netzfläche EINER Karte - es liest sich von oben wie das
## Prägenetz auf der liegenden Karte.
static func net_quad_size() -> Vector2:
	return DataCellView.net_span(PackDrawerView.CASSETTE_SCALE)

## Einziger Eingang: Ton und Glüh-Faktor der Serie (Sorte und höchste Größe).
func setup(body_tint: Color, energy: float) -> void:
	accent = body_tint
	accent_energy = maxf(energy, 0.01)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_build_net()
	_values = _zeros()
	_from = _zeros()
	_goal = _zeros()
	_apply_body()
	_bake()

## Der aufgelaufene Stand, wie er auf ihm STEHT.
func values() -> Array[int]:
	return _values.duplicate()

## Welche Seiten überhaupt LEUCHTEN - je eine wird beim Einschlag zum Funken.
func lit_faces() -> Array[int]:
	var faces: Array[int] = []
	for face in StampNet.FACES:
		if _values[face] != 0:
			faces.append(face)
	return faces

# --- Der ZÄHL-TAKT und die SCHLÄGE --------------------------------------------------

## Der neue Stand: die Ziffern LAUFEN dorthin, statt zu springen. Endzustand
## zuerst - das Ziel steht, bevor der Takt losläuft.
func tick_to(values_after: Array, time: float) -> void:
	_kill(_tick)
	_from = _values.duplicate()
	_goal = _read(values_after)
	if time <= 0.0 or _from == _goal:
		settle_ticks()
		return
	_tick = create_tween()
	_tick.tween_method(_apply_tick, 0.0, 1.0, time)
	_tick.finished.connect(settle_ticks)

## Die Ziffern stehen auf ihrem Ziel, wo der Takt auch stand.
func settle_ticks() -> void:
	_kill(_tick)
	if _values == _goal:
		return
	_values = _goal.duplicate()
	_bake()

## Eine WERT-Karte geht auf: ein kurzer Schlag, kein Zeichen.
func strike() -> void:
	_hit(STRIKE_PEAK, "")

## Der OPERATOR schlägt perkussiv zu: das Netz schwillt an und seine Glyphe blitzt
## darauf auf.
func punch(glyph: String) -> void:
	_hit(PUNCH_PEAK, glyph)

func _hit(peak: float, glyph: String) -> void:
	_show_glyph(glyph)
	_kill(_beat)
	_set_scale(1.0)  # Endzustand zuerst: der Schlag klingt auf die Ruhe zurück
	_beat = create_tween()
	_beat.set_parallel(true)
	_beat.tween_method(_set_scale, peak, 1.0, PUNCH_TIME) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if glyph != "":
		_beat.tween_method(_set_glyph_fade, 1.0, 0.0, GLYPH_TIME)

## Der EINE Aufräum-Pfad: jede Fahrt stirbt, die Ziffern stehen auf ihrem Ziel,
## Maßstab und Glyphe sind zurückgesetzt.
func settle() -> void:
	_kill(_beat)
	settle_ticks()
	_set_scale(1.0)
	_set_glyph_fade(0.0)

# --- Innereien ---------------------------------------------------------------------

func _apply_tick(share: float) -> void:
	# In Stufen, nicht je Bild: jede Stufe ist eine Backung.
	var step := ceilf(clampf(share, 0.0, 1.0) * float(TICK_STEPS)) / float(TICK_STEPS)
	var next: Array[int] = []
	for face in StampNet.FACES:
		next.append(int(roundf(lerpf(float(_from[face]), float(_goal[face]), step))))
	if next == _values:
		return
	_values = next
	_bake()

## Das Netz, das es zeigt: je Seite ihr aufgelaufener Bonus als Wert-Zelle, eine
## Null bleibt leer - und LEER heißt hier UNSICHTBAR, nicht dunkel.
static func net_for(values_now: Array) -> Array:
	var net := StampNet.empty_net()
	for face in StampNet.FACES:
		var amount := int(values_now[face]) if face < values_now.size() else 0
		if amount != 0:
			net[face] = StampNet.value_cell(amount)
	return net

func _bake() -> void:
	if _net_material == null:
		return
	if _oven == null or not is_instance_valid(_oven):
		_oven = SubViewport.new()
		_oven.name = "LightNetOven"
		_oven.size = StampNetOven.size_px()
		_oven.transparent_bg = true
		_oven.use_hdr_2d = false
		_oven.disable_3d = true
		add_child(_oven)
	for child in _oven.get_children():
		_oven.remove_child(child)  # queue_free wirkt erst am Bildende
		child.queue_free()
	_oven.add_child(_drawing())
	_oven.render_target_update_mode = SubViewport.UPDATE_ONCE
	_net_material.albedo_texture = _oven.get_texture()

## Die Zeichnung EINER Backung - und der ganze Unterschied zur Karte: die LEEREN
## Zellen und ihr Kreuz sind FORT. Nur was benutzt wird, leuchtet.
func _drawing() -> Control:
	var drawing := PressNetView.stamp_net_upright(net_for(_values),
		StampNetOven.CELL, accent)
	_hide_blank_cells(drawing)
	return drawing

## Jede Zelle ohne Wert wird unsichtbar geschaltet - der EINE Unterschied zum
## Karten-Netz, und er wird an der QUELLE gemacht, nicht per Shader.
func _hide_blank_cells(drawing: Control) -> void:
	var cross := drawing.get_node_or_null("StampNet") as Control
	if cross == null:
		return
	var chips := cross.get_children()
	for face in StampNet.FACES:
		if face >= chips.size():
			break
		var chip := chips[face] as Control
		if chip != null:
			chip.visible = _values[face] != 0

## Das HOLOGRAMM: ein additives Quad in Netzgröße, waagerecht wie das Netz auf der
## liegenden Karte.
func _build_net() -> void:
	_net_material = StandardMaterial3D.new()
	_net_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_net_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_net_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Es liest IMMER: die noch ungelesenen Karten liegen ÜBER der Licht-Ebene und
	# verdeckten das Hologramm sonst von oben.
	_net_material.no_depth_test = true
	_net_material.render_priority = DataCellView.PRIORITY_NET
	_net_material.albedo_color = Color(NET_ENERGY * accent_energy,
		NET_ENERGY * accent_energy, NET_ENERGY * accent_energy, NET_ALPHA)
	_net = MeshInstance3D.new()
	_net.name = "Hologram"
	var quad := QuadMesh.new()
	quad.size = net_quad_size()
	_net.mesh = quad
	_net.material_override = _net_material
	_net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_net.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_net.position = Vector3(0.0, NET_PROUD, 0.0)
	_body.add_child(_net)

func _apply_body() -> void:
	if _body == null:
		return
	_body.transform = Transform3D(Basis().scaled(Vector3.ONE * _scale), Vector3.ZERO)

func _set_scale(value: float) -> void:
	_scale = maxf(value, 0.001)
	_apply_body()

## Die Glyphe verglimmt für sich - nie der gelesene Wert zurück in die Rechnung.
func _set_glyph_fade(value: float) -> void:
	_glyph_fade = clampf(value, 0.0, 1.0)
	_apply_glyph()

func _apply_glyph() -> void:
	if _glyph == null or not is_instance_valid(_glyph) or _glyph_material == null:
		return
	_glyph_material.albedo_color = Color(1.0, 1.0, 1.0, _glyph_fade)
	_glyph.visible = _glyph_fade > 0.01

func _show_glyph(text: String) -> void:
	if text == "":
		_set_glyph_fade(0.0)
		return
	if _glyph == null or not is_instance_valid(_glyph):
		_build_glyph()
	_glyph_label.text = text
	_glyph_oven.render_target_update_mode = SubViewport.UPDATE_ONCE
	_set_glyph_fade(1.0)

func _build_glyph() -> void:
	_glyph_oven = SubViewport.new()
	_glyph_oven.name = "LightGlyphOven"
	_glyph_oven.size = Vector2i(GLYPH_TEXTURE, GLYPH_TEXTURE)
	_glyph_oven.transparent_bg = true
	_glyph_oven.use_hdr_2d = false
	_glyph_oven.disable_3d = true
	add_child(_glyph_oven)
	_glyph_label = Label.new()
	_glyph_label.name = "Glyph"
	_glyph_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CasinoStyle.style_score_label(_glyph_label, int(GLYPH_TEXTURE * 0.7),
		PressNetView.OPERATOR_TINT)
	_glyph_oven.add_child(_glyph_label)
	_glyph_material = StandardMaterial3D.new()
	_glyph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glyph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glyph_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glyph_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glyph_material.no_depth_test = true
	_glyph_material.render_priority = DataCellView.PRIORITY_BADGE
	_glyph_material.albedo_texture = _glyph_oven.get_texture()
	_glyph = MeshInstance3D.new()
	_glyph.name = "LightGlyph"
	var quad := QuadMesh.new()
	var span := net_quad_size()
	var side := minf(span.x, span.y) * GLYPH_SHARE
	quad.size = Vector2(side, side)
	_glyph.mesh = quad
	_glyph.material_override = _glyph_material
	_glyph.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_glyph.position = Vector3(0.0, NET_PROUD * 2.0, 0.0)
	_glyph.visible = false
	_body.add_child(_glyph)

static func _zeros() -> Array[int]:
	var out: Array[int] = []
	for face in StampNet.FACES:
		out.append(0)
	return out

static func _read(values_now: Array) -> Array[int]:
	var out: Array[int] = []
	for face in StampNet.FACES:
		out.append(int(values_now[face]) if face < values_now.size() else 0)
	return out

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
