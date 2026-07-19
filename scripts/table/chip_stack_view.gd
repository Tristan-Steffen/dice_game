class_name ChipStackView
extends Node3D
## Zeigt den Geldstand als Keramik-Pokerchips auf dem Tisch. Gestückelt wird
## per "Color-Up" (chip_counts): jede Stückelung behält ihre Chips bis zur
## Kappe, erst der Überschuss wandert in exakten Gruppen nach oben - große
## Stapel bleiben so lange erhalten (Masse = Reichtum), statt früh zu wenigen
## hohen Chips zu verschmelzen. Die Türme (max. COLUMN_CAP Chips) stehen als
## Rack in Reihen entlang der Truhen-Längsachse, nach Stückelung gruppiert.
## set_money() baut bei jeder Geldänderung neu auf. Nur der oberste Chip einer
## Spalte trägt die Wertziffer; ein aus dem Index abgeleiteter Versatz lässt
## die Türme handgesetzt statt maschinell wirken.

## Stückelungen (absteigend; pulse_colors zerlegt gierig, die Anzeige über
## chip_counts): Neon-Farbe (Geld-Lichtpulse/Ziffer) + satter Keramik-Körper +
## Akzentring + Rand-Punkt-Farbe. Werte folgen der Casino-Konvention:
## $1 blau, $5 rot, $25 grün, $100 schwarz-gold.
const DENOMINATIONS := [
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
const COLUMN_CAP := 12
const COLUMN_SPACING := CHIP_RADIUS * 2.3         # Turmabstand in der Reihe
const ROW_SPACING := CHIP_RADIUS * 2.15           # Abstand zwischen Reihen
const ROW_LEN := 4                                # Türme je Reihe (Truhenbreite)
const JITTER_XZ := CHIP_RADIUS * 0.05             # winziger Stapelversatz
const COLUMN_JITTER := CHIP_RADIUS * 0.06         # dezenter Versatz ganzer Türme

## Color-Up-Kappen: erst über der Kappe wandert Überschuss eine Stufe hoch
## (immer in exakten Gruppen: 5×$5 → $25, 4×$25 → $100). $100 ist offen -
## der Endgame-Turm darf ewig wachsen.
const FIVES_CAP := 24                             # 2 volle Türme Rot
const QUARTERS_CAP := 12                          # 1 voller Turm Grün

var _chip_nodes: Array[Node3D] = []

## Geteilte Ressourcen.
var _chip_mesh: CylinderMesh
var _materials: Dictionary = {}   # value -> ShaderMaterial

## Baut den Chip-Turm neu; nicht-positive Beträge lassen den Tisch leer.
func set_money(amount: int) -> void:
	_ensure_resources()
	for node in _chip_nodes:
		node.queue_free()
	_chip_nodes.clear()
	if amount <= 0:
		return

	var counts := chip_counts(amount)
	var columns: Array = []  # {value, count} je Spalte, höchster Wert zuerst
	for denom in DENOMINATIONS:
		var value: int = denom["value"]
		_append_columns(columns, value, int(counts[value]))

	var offsets := _rack_offsets(columns.size())
	for i in columns.size():
		_build_column(i, columns[i]["value"], columns[i]["count"], offsets[i])

## Color-Up-Zerlegung eines Betrags in Chips je Stückelung (value -> Anzahl):
## $1 nur als Rest unter $5, $5/$25 bis zur Kappe, Überschuss in exakten
## Gruppen eine Stufe hoch. Die Kappen halten die Zerlegung stabil: kleine
## Geldänderungen nehmen nur Chips vom Rand statt alles umzuschichten.
static func chip_counts(amount: int) -> Dictionary:
	var ones := maxi(0, amount) % 5
	var fives := (maxi(0, amount) - ones) / 5
	var quarters := 0
	while fives > FIVES_CAP:
		fives -= 5
		quarters += 1
	var hundreds := 0
	while quarters > QUARTERS_CAP:
		quarters -= 4
		hundreds += 1
	return {1: ones, 5: fives, 25: quarters, 100: hundreds}

func _append_columns(columns: Array, value: int, count: int) -> void:
	while count > 0:
		var height := mini(count, COLUMN_CAP)
		columns.append({"value": value, "count": height})
		count -= height

func _build_column(col_i: int, value: int, count: int, at: Vector2) -> void:
	for j in count:
		var top := j == count - 1
		var chip := _build_chip(value, top)
		var dx := _jitter(col_i * 31 + j, 1) * JITTER_XZ
		var dz := _jitter(col_i * 31 + j, 2) * JITTER_XZ
		chip.position = Vector3(at.x + dx, CHIP_HEIGHT * (float(j) + 0.5), at.y + dz)
		chip.rotation.y = _jitter(col_i * 31 + j, 3) * TAU
		add_child(chip)
		_chip_nodes.append(chip)

## Rack-Anordnung für n Türme: Reihen entlang der Truhen-Längsachse (Welt-Z,
## Bildschirm links-rechts), je Reihe bis ROW_LEN Türme, weitere Reihen entlang
## Welt-X; Reihe wie Gesamtblock zentriert. Da die Türme nach Stückelung
## sortiert ankommen (hohe Werte zuerst), entstehen zusammenhängende
## Farbblöcke wie bei einer aufgeräumten Casino-Bank.
static func _rack_offsets(n: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []  # (x, z) je Turm
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

## Kurzer elastischer Pop des Turms (Einschlag des Geld-Lichts).
func pulse() -> void:
	scale = Vector3.ONE * 1.18
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.35)

## Zerlegt einen Betrag in die Chip-Farben seiner Stückelung: 8 -> [Rot, 3×Blau].
## Grundlage der Kauf-Lichtpulse (ein Puls je Chip).
static func pulse_colors(amount: int) -> Array[Color]:
	var colors: Array[Color] = []
	var rest := amount
	for denom in DENOMINATIONS:
		var value: int = denom["value"]
		while rest >= value:
			rest -= value
			colors.append(denom["color"])
	return colors

## Ein Keramik-Pokerchip (geteiltes Mesh + Shader-Material je Wert). Nur der
## oberste Chip einer Spalte trägt die flache Wertziffer.
func _build_chip(value: int, top: bool) -> Node3D:
	var chip := Node3D.new()

	var body := MeshInstance3D.new()
	body.mesh = _chip_mesh
	body.material_override = _materials[value]
	chip.add_child(body)

	if top:
		var label := Label3D.new()
		label.text = str(value)
		label.font_size = 96
		# Dreistellige Werte (100) schmaler skalieren, damit sie aufs Inlay passen.
		label.pixel_size = 0.006 if value < 100 else 0.0044
		# Flach auf der Oberseite und stets aufrecht ausgerichtet (der Keramik-
		# Körper darunter darf zufällig gedreht sein, die Ziffer bleibt lesbar).
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

## Deterministischer Pseudo-Zufall (-0.5..0.5) aus zwei Indizes: gleicher Turm
## bleibt bei jedem Neuaufbau gleich versetzt (kein Flimmern bei Geldänderung).
static func _jitter(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453, 1.0) - 0.5

func _ensure_resources() -> void:
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
