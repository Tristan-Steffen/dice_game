extends SceneTree
## ATTRAPPE des neuen Wett-Layouts im echten Spiel: drei feste Zonen je Plot (Preis, Aufgabe als
## Messwerk im Gatter, Gewinn als Körper unter Glas). Nur Bild, keine Logik. Aufruf:
##   Godot --path . --resolution 1280x720 --position 4000,2400 --quit-after 2400 \
##     --script tools/godot_bet_mock_probe.gd
## Bilder: E:/Generated Images/Fumble/wetten_mock_spiel_2026-11-24/

const OUT := "E:/Generated Images/Fumble/wetten_mock_spiel_2026-11-24/"
const VIEWS := ["station", "nah", "uebersicht"]

const AMBER := Color("#ffb347")
const CYAN := Color("#8be9fd")
const GREEN := Color("#50fa7b")
const GOLD := Color("#ffd319")
const WHITE := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.55, 0.6, 0.7)
const DARK := Color(0.015, 0.018, 0.024)
const STEEL := Color(0.34, 0.37, 0.42)

## Plot in Welt: a = Bild-rechts (Welt +Z), b = Bild-oben (Welt +X).
const GATE_L := 3.45
const GATE_H := 3.9
const BAY := Vector2(5.35, 3.7)

var game: Node
var cam: Camera3D
var started := false
var step := 0
var wait := 0
var mock: Node3D
var center := Vector3.ZERO

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://scenes/scene_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	cam = Camera3D.new()
	cam.near = 0.5
	cam.far = 2000.0
	root.add_child(cam)

func _flat() -> Basis:
	return Basis(Vector3.UP, -PI / 2.0) * Basis(Vector3.RIGHT, -PI / 2.0)

func _mat(color: Color, gain := 1.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r * gain, color.g * gain, color.b * gain, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _box(parent: Node3D, a: float, b: float, wa: float, wb: float, h: float, y: float,
		material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(wb, h, wa)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = Vector3(b, y + h * 0.5, a)
	parent.add_child(node)
	return node

func _ring(parent: Node3D, a: float, b: float, wa: float, wb: float, t: float, h: float, y: float,
		material: Material) -> void:
	_box(parent, a, b + wb * 0.5 - t * 0.5, wa, t, h, y, material)
	_box(parent, a, b - wb * 0.5 + t * 0.5, wa, t, h, y, material)
	_box(parent, a - wa * 0.5 + t * 0.5, b, t, wb - 2.0 * t, h, y, material)
	_box(parent, a + wa * 0.5 - t * 0.5, b, t, wb - 2.0 * t, h, y, material)

func _poly(parent: Node3D, points: PackedVector2Array, y: float, material: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, points.size() - 1):
		for p: Vector2 in [points[0], points[i], points[i + 1]]:
			tool.add_vertex(Vector3(p.y, y, p.x))
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = material
	parent.add_child(node)

func _label(parent: Node3D, text: String, a: float, b: float, y: float, height: float, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, wrap := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = CharmDiskView.disk_font()
	label.font_size = 96
	label.pixel_size = height / (96.0 * 0.72)
	label.modulate = color
	label.outline_size = 0
	label.shaded = false
	label.double_sided = true
	label.horizontal_alignment = align
	if wrap > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.width = wrap / label.pixel_size
	label.transform = Transform3D(_flat(), Vector3(b, y, a))
	parent.add_child(label)
	return label

## Umriß je Gatter-Art, linke Kante bei a0, Nase nach Bild-rechts.
func _gate(kind: String, a0: float, inset: float) -> PackedVector2Array:
	var hh := GATE_H * 0.5 - inset
	var x0 := a0 + inset
	var x1 := a0 + GATE_L - inset
	var out := PackedVector2Array()
	match kind:
		"und":
			var r := 1.1
			out.append(Vector2(x0, -hh))
			for i in 9:
				var t := -PI / 2.0 + PI / 2.0 * float(i) / 8.0
				out.append(Vector2(x1 - r + r * cos(t), -hh + r + r * sin(t)))
			for i in 9:
				var t := PI / 2.0 * float(i) / 8.0
				out.append(Vector2(x1 - r + r * cos(t), hh - r + r * sin(t)))
			out.append(Vector2(x0, hh))
		"nicht":
			out.append_array([Vector2(x0, -hh), Vector2(x1 - 0.75, -hh), Vector2(x1 - 0.3, 0.0),
				Vector2(x1 - 0.75, hh), Vector2(x0, hh)])
		"grenze":
			out.append_array([Vector2(x0, -hh), Vector2(x1 - 0.45, -hh), Vector2(x1 - 0.45, hh),
				Vector2(x0, hh)])
		_:
			var c := 0.4
			out.append_array([Vector2(x0, -hh + c), Vector2(x0 + c, -hh), Vector2(x1 - c, -hh),
				Vector2(x1, -hh + c), Vector2(x1, hh - c), Vector2(x1 - c, hh), Vector2(x0 + c, hh),
				Vector2(x0, hh - c)])
	return out

func _plot(at: Vector3, bet: Dictionary) -> void:
	var plot := Node3D.new()
	plot.position = at
	mock.add_child(plot)
	var tone: Color = bet["tone"]
	var kind := String(bet["gate"])
	var a0 := -4.5
	# Aufgabe: Gatter als Rahmen des Messwerks
	_poly(plot, _gate(kind, a0, 0.0), 0.05, _mat(tone, 1.1))
	_poly(plot, _gate(kind, a0, 0.09), 0.06, _mat(DARK))
	if kind == "nicht":
		_ring(plot, a0 + GATE_L + 0.02, 0.0, 0.42, 0.42, 0.1, 0.02, 0.05, _mat(tone, 1.1))
	if kind == "grenze":
		_box(plot, a0 + GATE_L - 0.16, 0.0, 0.2, GATE_H, 0.02, 0.05, _mat(tone, 1.1))
	var left := a0 + 0.3
	var wide := GATE_L - (1.0 if kind in ["und", "nicht", "grenze"] else 0.6)
	var mid := left + wide * 0.5
	# Preis oben links, Art oben rechts
	var paid := bool(bet["placed"])
	_label(plot, String(bet["stake"]), left, 1.38, 0.07, 0.62, MUTED if paid else AMBER,
		HORIZONTAL_ALIGNMENT_LEFT)
	_label(plot, "GESETZT" if paid else "SETZEN", left + wide, 1.42, 0.07, 0.17,
		MUTED if paid else AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	_box(plot, mid, 0.95, wide, 0.03, 0.01, 0.06, _mat(tone, 0.6))
	# Messwert groß, Einheit, Balken, darunter klein der ganze Satz
	var value := String(bet["value"])
	var tall := minf(0.72, wide / (float(value.length()) * 0.6))
	_label(plot, value, mid, 0.3, 0.07, tall, tone if paid else WHITE)
	_label(plot, String(bet["unit"]), mid, -0.42, 0.07, 0.2, WHITE)
	_box(plot, mid, -0.82, wide, 0.14, 0.01, 0.06, _mat(STEEL, 0.5))
	var share := float(bet["share"])
	if share > 0.0:
		_box(plot, left + wide * share * 0.5, -0.82, wide * share, 0.14, 0.012, 0.06, _mat(tone, 1.2))
	_label(plot, String(bet["text"]), mid, -1.38, 0.07, 0.13, MUTED, HORIZONTAL_ALIGNMENT_CENTER, wide)
	# Gewinn: Körper in der Bucht, unter Glas bis er verdient ist
	var ba := a0 + GATE_L + 0.2 + BAY.x * 0.5
	var won := bool(bet["won"])
	_box(plot, ba, 0.0, BAY.x, BAY.y, 0.01, 0.02, _mat(DARK))
	_ring(plot, ba, 0.0, BAY.x + 0.24, BAY.y + 0.24, 0.12, 0.2, 0.0, _mat(STEEL))
	_ring(plot, ba, 0.0, BAY.x, BAY.y, 0.06, 0.02, 0.03, _mat(GOLD if won else tone, 1.2 if won else 0.7))
	var spot := at + Vector3(0.0, 0.25 if won else 0.04, ba)
	var body := game.call("_spawn_bet_body", bet["prize"], spot) as Node3D
	if body != null and not won:
		_box(plot, ba, 0.0, BAY.x, BAY.y, 0.03, 1.15, _mat(Color(0.05, 0.07, 0.1), 1.0, 0.45))

func _card_spec(type: String, tier: int, count: int) -> Dictionary:
	var pack := Pack.tiered(Pack.by_type(type), tier, null)
	return {"body": "cell", "sort": Pack.shelf_of(pack), "tier": tier, "count": count, "packs": [pack]}

func _build() -> void:
	var screen: TableScreen = game.get("table_screen")
	var window := screen.side_bet_window
	var rect := Rect2(window.position, window.size)
	window.visible = false
	mock = Node3D.new()
	mock.name = "BetMock"
	game.add_child(mock)
	center = screen.pixel_to_world(rect.get_center())
	var bets := [
		{"stake": "$6", "placed": false, "won": false, "gate": "und", "tone": AMBER, "value": "150+",
			"unit": "PUNKTE IN EINER HAND", "share": 0.0,
			"text": "Werte eine einzelne Hand mit 150+ Punkten.",
			"prize": _card_spec(Pack.TYPE_NUMBER, Pack.TIER_KOLOSSAL, 1)},
		{"stake": "$6", "placed": true, "won": false, "gate": "grenze", "tone": GREEN, "value": "4 / 9",
			"unit": "WÜRFEL GENOMMEN", "share": 0.44,
			"text": "Räume die Runde mit höchstens 9 genommenen Würfeln.",
			"prize": {"body": "chips", "amount": 15}},
		{"stake": "$6", "placed": true, "won": true, "gate": "und", "tone": GOLD, "value": "FULL HOUSE",
			"unit": "GESCHAFFT", "share": 1.0, "text": "Nimm ein Full House oder besser.",
			"prize": _card_spec(Pack.TYPE_MATERIAL, Pack.TIER_NORMAL, 2)}]
	var rows := rect.size.y / 3.0
	for i in 3:
		var px := Vector2(rect.get_center().x, rect.position.y + rows * (float(i) + 0.5))
		_plot(screen.pixel_to_world(px), bets[i])

func _process(_delta: float) -> bool:
	var ms := Time.get_ticks_msec()
	if not started:
		if ms > 2500:
			started = true
			game.call("_on_title_new_game")
		return false
	if ms < 12000:
		return false
	wait += 1
	if wait < 50:
		return false
	wait = 0
	if step > 0:
		root.get_texture().get_image().save_png(OUT + "%d_%s.png" % [step, VIEWS[step - 1]])
	if step >= VIEWS.size():
		return true
	match step:
		0:
			_build()
			var forward := Vector3(0.2588, -0.9659, 0.0)
			cam.fov = 40.0
			cam.look_at_from_position(center - forward * 26.0, center, Vector3(1, 0, 0))
			cam.current = true
		1:
			var forward := Vector3(0.2588, -0.9659, 0.0)
			var top := center + Vector3(4.9, 0.0, 0.0)
			cam.look_at_from_position(top - forward * 11.0, top, Vector3(1, 0, 0))
		2:
			(game.get("camera_rig") as Camera3D).current = true
	step += 1
	return false
