class_name ChipStackView
extends Node3D
## Ein gestapelter Chip-Haufen als Körper: der Gewinn-Stapel einer Wette und die
## Wurf-Körper. Die Börse des Spielers ist das CHIP-TRAY (ChipTrayView); hier
## wohnen nur noch die Stückelungen (EINE Farbquelle), der Chip-Körper und die
## Rack-Rechnung der Stapel.

## Stückelungen (absteigend): Neon-Farbe (Licht/Ziffer) + Keramik-Körper +
## Akzentring + Rand-Punkt-Farbe.
const DENOMINATIONS := [
	{
		"value": 10000,
		"color": Color("e8eef8"),                 # Platin (Puls/Ziffer)
		"body": Color(0.50, 0.52, 0.58),          # Perlmutt-Grau
		"accent": Color(0.86, 0.92, 1.0),
		"spot": Color(0.96, 0.90, 0.98),          # Perlmutt-Punkte
	},
	{
		"value": 2500,
		"color": Color("ff9a2e"),                 # Neon-Orange
		"body": Color(0.42, 0.16, 0.02),          # gebranntes Orange
		"accent": Color(1.0, 0.62, 0.22),
	},
	{
		"value": 500,
		"color": Color("b56cff"),                 # Neon-Violett
		"body": Color(0.20, 0.06, 0.34),          # tiefes Violett
		"accent": Color(0.74, 0.46, 1.0),
	},
	{
		"value": 100,
		"color": Color("ffcf40"),                 # Gold (Puls/Ziffer)
		"body": Color(0.06, 0.05, 0.08),          # tiefes Anthrazit
		"accent": Color(1.0, 0.80, 0.30),
		"spot": Color(0.86, 0.72, 0.38),          # goldene Rand-Punkte
	},
	{
		"value": 25,
		"color": Color("3ef08a"),                 # Neon-Grün
		"body": Color(0.03, 0.22, 0.11),          # tiefes Tannengrün
		"accent": Color(0.34, 0.95, 0.58),
	},
	{
		"value": 5,
		"color": Color("fe5f55"),                 # Neon-Rot
		"body": Color(0.40, 0.05, 0.09),          # tiefes Burgunder
		"accent": Color(1.0, 0.37, 0.33),
	},
	{
		"value": 1,
		"color": Color("2f9ff0"),                 # Neon-Blau
		"body": Color(0.05, 0.11, 0.32),          # tiefes Kobalt
		"accent": Color(0.24, 0.66, 0.98),
	},
]

const SPOT_COLOR := Color(0.82, 0.79, 0.70)       # gedämpfte Creme-Rand-Punkte (Standard)

const CHIP_RADIUS := 0.9
const CHIP_HEIGHT := 0.28
const COLUMN_CAP := 8
const COLUMN_SPACING := CHIP_RADIUS * 2.3         # Turmabstand in der Reihe
const ROW_SPACING := CHIP_RADIUS * 2.15           # Abstand zwischen Reihen
const ROW_LEN := 6                                # Türme je Reihe
const JITTER_XZ := CHIP_RADIUS * 0.09             # Stapelversatz (handgesetzt-Look)
const COLUMN_JITTER := CHIP_RADIUS * 0.06         # dezenter Versatz ganzer Türme

## Stückelungs-Werte, absteigend.
const VALUES := [10000, 2500, 500, 100, 25, 5, 1]

## Bodenschwere Zerlegung: 100er und 25er werden je Buchung gedeckelt, der Rest fällt
## in kleinere Chips (mehr Stapel, mehr Haptik).
const GAIN_CAPS := {100: 2, 25: 2}

## Der gezeigte Bestand {value: count}.
var _counts := {}
var _chip_nodes: Array[Node3D] = []
var _top_y := CHIP_HEIGHT
var _towers: Array = []                            # zuletzt gebaute Türme {value, count, at}

## Geteilte Ressourcen aller Chips des Spiels.
static var _chip_mesh: CylinderMesh
static var _materials: Dictionary = {}   # value -> ShaderMaterial

## Zeigt einen Betrag als bodenschweren Stapel (split_gain).
func show_amount(amount: int) -> void:
	_counts = {}
	for value in split_gain(amount):
		_counts[value] = int(_counts.get(value, 0)) + 1
	_build_pile(_counts)

## Der Wert des gezeigten Stapels.
func shown_total() -> int:
	var total := 0
	for value in _counts:
		total += int(value) * int(_counts[value])
	return total

## Die Spalten, die ein Bestand im Rack belegt - {value, count} je Turm, höchster
## Wert zuerst. Rein statisch, damit der Wett-Tresen den Fußabdruck messen kann,
## bevor der Stapel gebaut ist.
static func pile_columns(counts: Dictionary) -> Array:
	var columns: Array = []
	for value in VALUES:
		var count := int(counts.get(value, 0))
		while count > 0:
			var height := mini(count, COLUMN_CAP)
			columns.append({"value": value, "count": height})
			count -= height
	return columns

## Wie viele TÜRME ein Betrag im Rack belegt — daran mißt der Fußabdruck.
static func pile_tower_count(amount: int) -> int:
	var counts := {}
	for value in split_gain(maxi(amount, 0)):
		counts[value] = int(counts.get(value, 0)) + 1
	return pile_columns(counts).size()

## Wie hoch das i-te GEWORFENE Stück über seiner Landefläche aufsetzt: genau auf dem
## schon liegenden Stapel, ein Chip je Schritt.
static func stack_lift(index: int) -> float:
	return CHIP_HEIGHT * float(maxi(index, 0))

## Der Fußabdruck eines Betrags im Rack (x = Welt-X, y = Welt-Z), ohne ihn zu bauen.
static func pile_span(amount: int) -> Vector2:
	var offsets := _rack_offsets(pile_tower_count(amount))
	var reach := Vector2(CHIP_RADIUS, CHIP_RADIUS)
	for at in offsets:
		reach.x = maxf(reach.x, absf(at.x) + CHIP_RADIUS)
		reach.y = maxf(reach.y, absf(at.y) + CHIP_RADIUS)
	return reach * 2.0

func _build_pile(counts: Dictionary) -> void:
	for node in _chip_nodes:
		node.queue_free()
	_chip_nodes.clear()
	var columns := pile_columns(counts)
	var offsets := _rack_offsets(columns.size())
	var tallest := 0
	_towers = []
	for i in columns.size():
		tallest = maxi(tallest, int(columns[i]["count"]))
		_build_column(i, columns[i]["value"], columns[i]["count"], offsets[i])
		_towers.append({"value": columns[i]["value"], "count": columns[i]["count"], "at": offsets[i]})
	_top_y = float(tallest) * CHIP_HEIGHT + CHIP_HEIGHT * 0.5

## Zuletzt gebaute Türme: {value, count, at: Vector2 (lokales XZ)} je Turm.
func towers() -> Array:
	return _towers

func top_y() -> float:
	return _top_y

## Ein frei beweglicher Turm (Wurf-Körper), ungeparkt - der Aufrufer hängt ihn ein.
static func ghost_tower(value: int, count: int) -> Node3D:
	var ghost := Node3D.new()
	for j in count:
		var chip := make_chip(value, j == count - 1)
		chip.position = Vector3(0.0, CHIP_HEIGHT * (float(j) + 0.5), 0.0)
		chip.rotation.y = _jitter(j, 7) * TAU
		ghost.add_child(chip)
	return ghost

# --- Stückelungs-Mathematik (rein statisch, testbar) ------------------------

## Bodenschwere Zerlegung eines Zuwachses (GAIN_CAPS). Höchste zuerst.
static func split_gain(amount: int) -> Array[int]:
	var values: Array[int] = []
	var rest := maxi(0, amount)
	for value in VALUES:
		var cap: int = int(GAIN_CAPS.get(value, 0))
		var count := 0
		while rest >= value:
			rest -= value
			values.append(value)
			count += 1
			if cap > 0 and count >= cap:
				break
	return values

## Gierige Zerlegung: möglichst wenige Chips, höchste zuerst.
static func split_greedy(amount: int) -> Array[int]:
	var values: Array[int] = []
	var rest := maxi(0, amount)
	for value in VALUES:
		while rest >= value:
			rest -= value
			values.append(value)
	return values

## Die Ziffer auf dem Inlay: ab 1.000 gekürzt („2,5K“, „10K“).
static func value_label(value: int) -> String:
	if value < 1000:
		return str(value)
	if value % 1000 == 0:
		@warning_ignore("integer_division")
		return "%dK" % (value / 1000)
	return ("%.1fK" % (float(value) / 1000.0)).replace(".", ",")

func _build_column(col_i: int, value: int, count: int, at: Vector2) -> void:
	for j in count:
		var chip := make_chip(value, j == count - 1)
		var dx := _jitter(col_i * 31 + j, 1) * JITTER_XZ
		var dz := _jitter(col_i * 31 + j, 2) * JITTER_XZ
		chip.position = Vector3(at.x + dx, CHIP_HEIGHT * (float(j) + 0.5), at.y + dz)
		chip.rotation.y = _jitter(col_i * 31 + j, 3) * TAU
		add_child(chip)
		_chip_nodes.append(chip)

## Rack-Anordnung für n Türme: Reihen entlang Welt-Z, je Reihe bis ROW_LEN Türme,
## weitere Reihen entlang Welt-X; Reihe wie Block zentriert.
static func _rack_offsets(n: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if n <= 0:
		return offsets
	@warning_ignore("integer_division")
	var rows := (n + ROW_LEN - 1) / ROW_LEN
	var i := 0
	for r in rows:
		var in_row := mini(ROW_LEN, n - i)
		var x := (float(r) - float(rows - 1) * 0.5) * ROW_SPACING
		for k in in_row:
			var z := (float(k) - float(in_row - 1) * 0.5) * COLUMN_SPACING
			offsets.append(Vector2(x, z) + Vector2(_jitter(i, 4), _jitter(i, 5)) * COLUMN_JITTER)
			i += 1
	return offsets

## Ein Keramik-Pokerchip (geteiltes Mesh + Shader-Material je Wert); labelled trägt
## die flache Wertziffer.
static func make_chip(value: int, labelled: bool) -> Node3D:
	_ensure_resources()
	var chip := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = _chip_mesh
	body.material_override = _materials.get(value, _materials[1])
	chip.add_child(body)
	if labelled:
		var text := value_label(value)
		var label := Label3D.new()
		label.text = text
		label.font_size = 96
		# Längere Ziffern schmaler, damit sie aufs Inlay passen.
		label.pixel_size = 0.006 if text.length() <= 2 else (0.0044 if text.length() == 3 else 0.0034)
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		label.position.y = CHIP_HEIGHT * 0.5 + 0.01
		label.modulate = Color(0.97, 0.95, 0.88)
		label.outline_modulate = Color(0.02, 0.02, 0.04, 0.8)
		label.outline_size = 14
		chip.add_child(label)
	return chip

## Neon-Farbe einer Stückelung, Weiß als Rückfall.
static func denomination_color(value: int) -> Color:
	for denom in DENOMINATIONS:
		if denom["value"] == value:
			return denom["color"]
	return Color.WHITE

## Deterministischer Pseudo-Zufall (-0.5..0.5) aus zwei Indizes.
static func _jitter(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453, 1.0) - 0.5

static func _ensure_resources() -> void:
	if _chip_mesh != null:
		return
	_chip_mesh = CylinderMesh.new()
	_chip_mesh.top_radius = CHIP_RADIUS
	_chip_mesh.bottom_radius = CHIP_RADIUS
	_chip_mesh.height = CHIP_HEIGHT
	_chip_mesh.radial_segments = 48
	_chip_mesh.rings = 1
	var shader := load("res://assets/shaders/chip.gdshader")
	for denom in DENOMINATIONS:
		var value: int = denom["value"]
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("body_color", denom["body"])
		mat.set_shader_parameter("spot_color", denom.get("spot", SPOT_COLOR))
		mat.set_shader_parameter("accent_color", denom["accent"])
		mat.set_shader_parameter("radius", CHIP_RADIUS)
		mat.set_shader_parameter("height", CHIP_HEIGHT)
		_materials[value] = mat
