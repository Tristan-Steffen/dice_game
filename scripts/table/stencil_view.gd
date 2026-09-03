class_name StencilView
extends Node3D
## Die SCHABLONE der SERIEN-ZEREMONIE: ein Plättchen, das das Prägenetz der
## AUFGELAUFENEN Summe trägt und über der Schacht-Reihe von links nach rechts
## fährt. Sie wird im Ist-Schirm geboren (leer = dunkel), nimmt an jeder Karte
## deren Zellen auf (die Ziffern TICKEN, sie springen nie) und faltet sich zuletzt
## in den Zielwürfel.
##
## Sie liegt in derselben geneigten Lage wie die Schacht-Kassetten (SOCKET_POSE) -
## aufrecht wäre ihr Netz an der 15°-Kamera fast kantig. Gezeichnet wird mit dem
## EINEN 2D-Zeichner (PressNetView.stamp_net) in einen eigenen SubViewport: der
## geteilte Ofen backt Ruhezustände, ein laufender Zähler gehört keinem Cache.
##
## Reine Anzeige: gerechnet hat SeriesResolver, gebucht GameRun - längst.

## Stufen des Zähl-Takts. Die Ziffern LAUFEN, aber jede Stufe ist eine Backung -
## vier lesen als Zählen und kosten vier Bilder, nicht dreißig.
const TICK_STEPS := 4
## Die SCHEIBE hinter dem Netz: sie gibt der Schablone ihren Umriß. Ohne sie stünde
## ein dunkles Kreuz über einer dunklen Karte und beide läsen als eines - sie ist
## ein GERÄT, das über die Reihe fährt, keine zweite Karte. Rand als Anteil einer
## Zellkante, Füllung durchscheinend (die Karte darunter bleibt sichtbar).
const PANE_PAD := 0.22
const PANE_BG := Color("#0a0918cc")
## Die GEBURT: sie wächst aus dem Nichts an ihrem Geburtsort.
const BIRTH_SCALE := 0.15
## Der perkussive Schlag eines Operators: so weit schwillt sie an, so lange klingt
## es ab. Eine WERT-Karte bekommt denselben Schlag, nur kleiner.
const PUNCH_PEAK := 1.34
const STRIKE_PEAK := 1.12
const PUNCH_TIME := 0.34
## Die Glyphe des Schlags: Anteil der Fläche, den sie einnimmt, und ihre Standzeit.
const GLYPH_SHARE := 0.52
const GLYPH_TIME := 0.42
const GLYPH_TEXTURE := 128
## Die FALTUNG: darauf schrumpft sie, während sie in den Würfel fährt.
const FOLD_SCALE := 0.12

## Der Ton ihres Netzes (leere Zellen bleiben dunkel).
var accent := PressNetView.VALUE_TINT

## Der geneigte Körper und seine Fläche.
var _body: Node3D
var _plate: MeshInstance3D
var _material: StandardMaterial3D
var _oven: SubViewport
## Die Glyphe des Operator-Schlags - erst beim ersten Schlag gebaut.
var _glyph: MeshInstance3D
var _glyph_material: StandardMaterial3D
var _glyph_oven: SubViewport
var _glyph_label: Label

## Was auf ihr STEHT, woher der Takt lief und wohin (Bonus je Seite).
var _values: Array[int] = []
var _from: Array[int] = []
var _goal: Array[int] = []
var _pose := 0.0
var _scale := 1.0
var _fade := 1.0
var _glyph_fade := 0.0
var _span := Vector2.ONE
var _ride: Tween
var _tick: Tween
var _beat: Tween

func _init() -> void:
	name = "SeriesStencil"

## Kantenmaß der Backung: das Netz plus der Rand seiner Scheibe.
static func pane_size() -> Vector2:
	return StampNetOven.span() + Vector2.ONE * StampNetOven.CELL * PANE_PAD * 2.0

## Einziger Eingang: Maß des NETZES (die Scheibe wächst um ihren Rand darüber
## hinaus), die LAGE (0 liegend ... 1 stehend - die Schacht-Lage der Kassetten) und
## der Ton ihres Netzes.
func setup(net_span: Vector2, pose: float, tint: Color) -> void:
	accent = tint
	var pane := pane_size()
	var net := StampNetOven.span()
	_span = Vector2(maxf(net_span.x, 0.01) * pane.x / maxf(net.x, 1.0),
		maxf(net_span.y, 0.01) * pane.y / maxf(net.y, 1.0))
	_pose = clampf(pose, 0.0, 1.0)
	# Dieselbe Vierteldrehung wie eine Kassette: erst damit steht das Kreuz
	# aufrecht im Bild (Bildschirm-oben = Welt+X).
	rotation.y = -PI / 2.0
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.render_priority = 3
	_plate = MeshInstance3D.new()
	_plate.name = "Stencil"
	var quad := QuadMesh.new()
	quad.size = _span
	_plate.mesh = quad
	_plate.material_override = _material
	_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_plate)
	_values = _zeros()
	_from = _zeros()
	_goal = _zeros()
	_apply_body()
	_bake()

## Der aufgelaufene Stand, wie er auf ihr STEHT.
func values() -> Array[int]:
	return _values.duplicate()

# --- Die FAHRT ---------------------------------------------------------------------

## HART auf einen Platz - jede laufende Fahrt stirbt dabei.
func seat_at(at: Vector3) -> void:
	_kill(_ride)
	global_position = at

## Eine Etappe der Fahrt.
func ride_to(at: Vector3, time: float) -> void:
	_kill(_ride)
	if time <= 0.0:
		global_position = at
		return
	_ride = create_tween()
	_ride.tween_property(self, "global_position", at, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Die GEBURT: sie wächst am Geburtsort aus dem Nichts. Endzustand zuerst - der
## volle Stand steht, gefahren wird nur der Weg dorthin.
func emerge(time: float) -> void:
	_kill(_beat)
	_set_scale(1.0)
	_set_fade(1.0)
	if time <= 0.0:
		return
	_beat = create_tween()
	_beat.set_parallel(true)
	_beat.tween_method(_set_scale, BIRTH_SCALE, 1.0, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_beat.tween_method(_set_fade, 0.0, 1.0, maxf(time * 0.6, 0.01))

## Das EINSETZEN: sie fährt auf den Würfel und faltet sich dabei in ihn hinein.
## Was danach von ihr bleibt, räumt der Aufrufer weg - sie schuldet nichts.
func fold_into(at: Vector3, time: float) -> void:
	ride_to(at, time)
	_kill(_beat)
	if time <= 0.0:
		_set_scale(FOLD_SCALE)
		_set_fade(0.0)
		return
	_beat = create_tween()
	_beat.set_parallel(true)
	_beat.tween_method(_set_scale, 1.0, FOLD_SCALE, time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_beat.tween_method(_set_fade, 1.0, 0.0, time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

# --- Der ZÄHL-TAKT und die SCHLÄGE --------------------------------------------------

## Der neue Stand: die Ziffern LAUFEN dorthin, statt zu springen. Endzustand
## zuerst - das Ziel steht, bevor der Takt losläuft.
func tick_to(values: Array, time: float) -> void:
	_kill(_tick)
	_from = _values.duplicate()
	_goal = _read(values)
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

## Eine WERT-Karte wird aufgenommen: ein kurzer Schlag, kein Zeichen.
func strike() -> void:
	_hit(STRIKE_PEAK, "")

## Der OPERATOR schlägt perkussiv zu: die Schablone schwillt an und seine Glyphe
## blitzt auf ihr auf.
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

## Der EINE Aufräum-Pfad der Schablone: jede Fahrt stirbt, die Ziffern stehen auf
## ihrem Ziel, Maßstab und Glyphe sind zurückgesetzt.
func settle() -> void:
	_kill(_ride)
	_kill(_beat)
	settle_ticks()
	_set_scale(1.0)
	_set_fade(1.0)
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

## Das Netz, das sie zeigt: je Seite ihr aufgelaufener Bonus als Wert-Zelle, eine
## Null bleibt leer - so liest die leere Schablone als dunkles Kreuz.
static func net_for(values: Array) -> Array:
	var net := StampNet.empty_net()
	for face in StampNet.FACES:
		var amount := int(values[face]) if face < values.size() else 0
		if amount != 0:
			net[face] = StampNet.value_cell(amount)
	return net

func _bake() -> void:
	if _material == null:
		return
	var pane := pane_size()
	if _oven == null or not is_instance_valid(_oven):
		_oven = SubViewport.new()
		_oven.name = "StencilOven"
		_oven.size = Vector2i(int(ceilf(pane.x)), int(ceilf(pane.y)))
		_oven.transparent_bg = true
		_oven.use_hdr_2d = false
		_oven.disable_3d = true
		add_child(_oven)
	for child in _oven.get_children():
		_oven.remove_child(child)  # queue_free wirkt erst am Bildende
		child.queue_free()
	_oven.add_child(_drawing(pane))
	_oven.render_target_update_mode = SubViewport.UPDATE_ONCE
	_material.albedo_texture = _oven.get_texture()

## Die Zeichnung EINER Backung: die Scheibe mit ihrem Saum, darin das Netz des
## aufgelaufenen Standes.
func _drawing(pane: Vector2) -> Control:
	var host := Panel.new()
	host.name = "StencilPane"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size = pane
	var box := StyleBoxFlat.new()
	box.bg_color = PANE_BG
	box.border_color = accent
	box.set_border_width_all(maxi(1, int(StampNetOven.CELL * 0.09)))
	box.set_corner_radius_all(maxi(1, int(StampNetOven.CELL * 0.2)))
	host.add_theme_stylebox_override("panel", box)
	var net := net_for(_values)
	var drawing := PressNetView.stamp_net(net, StampNetOven.CELL, accent)
	drawing.position = Vector2.ONE * StampNetOven.CELL * PANE_PAD
	# Dieselbe Regel wie im Ofen: ein leeres Kreuz stünde sonst als schwarzes
	# Gitter da - LEER heißt dunkel, nicht unsichtbar.
	if StampNet.is_blank(net):
		drawing.modulate = accent
	host.add_child(drawing)
	return host

func _apply_body() -> void:
	if _body == null:
		return
	_body.transform = Transform3D(
		Basis(Vector3.RIGHT, lerpf(-PI * 0.5, 0.0, _pose)).scaled(Vector3.ONE * _scale),
		Vector3.ZERO)

func _set_scale(value: float) -> void:
	_scale = maxf(value, 0.001)
	_apply_body()

func _set_fade(value: float) -> void:
	_fade = clampf(value, 0.0, 1.0)
	if _material != null:
		_material.albedo_color = Color(1.0, 1.0, 1.0, _fade)
	_apply_glyph()

## Die Glyphe verglimmt für sich UND mit der Schablone - darum zwei Faktoren, nie
## der gelesene Wert zurück in die Rechnung (das dämpfte sich selbst weg).
func _set_glyph_fade(value: float) -> void:
	_glyph_fade = clampf(value, 0.0, 1.0)
	_apply_glyph()

func _apply_glyph() -> void:
	if _glyph == null or not is_instance_valid(_glyph) or _glyph_material == null:
		return
	var alpha := _glyph_fade * _fade
	_glyph_material.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	_glyph.visible = alpha > 0.01

## Die Glyphe liegt eine Spur VOR der Fläche - koplanar zerschnitte der
## Tiefenkampf sie.
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
	_glyph_oven.name = "StencilGlyphOven"
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
	_glyph_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glyph_material.render_priority = 4
	_glyph_material.albedo_texture = _glyph_oven.get_texture()
	_glyph = MeshInstance3D.new()
	_glyph.name = "StencilGlyph"
	var quad := QuadMesh.new()
	var side := minf(_span.x, _span.y) * GLYPH_SHARE
	quad.size = Vector2(side, side)
	_glyph.mesh = quad
	_glyph.material_override = _glyph_material
	_glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glyph.position = Vector3(0.0, 0.0, _span.y * 0.02)
	_glyph.visible = false
	_body.add_child(_glyph)

static func _zeros() -> Array[int]:
	var out: Array[int] = []
	for face in StampNet.FACES:
		out.append(0)
	return out

static func _read(values: Array) -> Array[int]:
	var out: Array[int] = []
	for face in StampNet.FACES:
		out.append(int(values[face]) if face < values.size() else 0)
	return out

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
