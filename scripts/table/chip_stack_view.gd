class_name ChipStackView
extends Node3D
## Zeigt den Geldstand als Neon-Pokerchips auf dem Tisch. Der Betrag wird
## gierig gestückelt (erst 5er, Rest 1er); jede Stückelung stapelt sich in
## Spalten (max. COLUMN_CAP), von Bildschirm-links nach rechts (= Welt +Z),
## in Z zentriert. set_money() baut bei jeder Geldänderung neu auf.

## Stückelungen (Wert -> Neon-Farbe), absteigend für die gierige Zerlegung.
const DENOMINATIONS := [
	{"value": 5, "color": Color("fe5f55")},  # Neon-Rot
	{"value": 1, "color": Color("2f9ff0")},  # Neon-Blau
]

const CHIP_RADIUS := 0.9
const CHIP_HEIGHT := 0.28
const COLUMN_CAP := 8
const COLUMN_SPACING := CHIP_RADIUS * 2.3
const RIM_INNER := CHIP_RADIUS * 0.82
const RIM_OUTER := CHIP_RADIUS * 1.0
const RIM_EMISSION := 3.4

var _chip_nodes: Array[Node3D] = []

## Geteilte Meshes/Materialien je Stückelung.
var _body_mesh: CylinderMesh
var _rim_mesh: TorusMesh
var _body_materials: Dictionary = {}  # value -> StandardMaterial3D
var _rim_materials: Dictionary = {}

## Baut den Chip-Turm neu; nicht-positive Beträge lassen den Tisch leer.
func set_money(amount: int) -> void:
	_ensure_resources()
	for node in _chip_nodes:
		node.queue_free()
	_chip_nodes.clear()
	if amount <= 0:
		return

	var columns: Array = []  # {value, count} je Spalte, 5er zuerst
	var rest := amount
	for denom in DENOMINATIONS:
		var value: int = denom["value"]
		var count := rest / value
		rest -= count * value
		_append_columns(columns, value, count)

	var n := columns.size()
	for i in n:
		var z := (float(i) - float(n - 1) * 0.5) * COLUMN_SPACING
		_build_column(columns[i]["value"], columns[i]["count"], z)

func _append_columns(columns: Array, value: int, count: int) -> void:
	while count > 0:
		var height := mini(count, COLUMN_CAP)
		columns.append({"value": value, "count": height})
		count -= height

func _build_column(value: int, count: int, z: float) -> void:
	for j in count:
		var chip := _build_chip(value)
		chip.position = Vector3(0.0, CHIP_HEIGHT * (float(j) + 0.5), z)
		add_child(chip)
		_chip_nodes.append(chip)

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

## Ein Neon-Pokerchip: dunkler Körper, leuchtender Randring, Wert als Leuchtziffer.
func _build_chip(value: int) -> Node3D:
	var chip := Node3D.new()

	var body := MeshInstance3D.new()
	body.mesh = _body_mesh
	body.material_override = _body_materials[value]
	chip.add_child(body)

	var rim := MeshInstance3D.new()
	rim.mesh = _rim_mesh
	rim.material_override = _rim_materials[value]
	chip.add_child(rim)

	var label := Label3D.new()
	label.text = str(value)
	label.font_size = 120
	label.pixel_size = 0.006
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # flach auf die Oberseite
	label.position.y = CHIP_HEIGHT * 0.5 + 0.02
	label.modulate = denomination_color(value)
	label.outline_modulate = Color(0.02, 0.02, 0.04, 1.0)
	label.outline_size = 28
	label.no_depth_test = false
	chip.add_child(label)

	return chip

## Neon-Farbe einer Stückelung, Weiß als Rückfall.
static func denomination_color(value: int) -> Color:
	for denom in DENOMINATIONS:
		if denom["value"] == value:
			return denom["color"]
	return Color.WHITE

func _ensure_resources() -> void:
	if _body_mesh != null:
		return
	_body_mesh = CylinderMesh.new()
	_body_mesh.top_radius = CHIP_RADIUS
	_body_mesh.bottom_radius = CHIP_RADIUS
	_body_mesh.height = CHIP_HEIGHT
	_body_mesh.radial_segments = 28

	_rim_mesh = TorusMesh.new()
	_rim_mesh.inner_radius = RIM_INNER
	_rim_mesh.outer_radius = RIM_OUTER
	_rim_mesh.rings = 24
	_rim_mesh.ring_segments = 10

	for denom in DENOMINATIONS:
		var value: int = denom["value"]
		var color: Color = denom["color"]

		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.07, 0.08, 0.11)
		body_mat.metallic = 0.2
		body_mat.roughness = 0.5
		body_mat.emission_enabled = true
		body_mat.emission = color
		body_mat.emission_energy_multiplier = 0.25  # schwaches Körper-Leuchten
		_body_materials[value] = body_mat

		var rim_mat := StandardMaterial3D.new()
		rim_mat.albedo_color = color
		rim_mat.emission_enabled = true
		rim_mat.emission = color
		rim_mat.emission_energy_multiplier = RIM_EMISSION
		_rim_materials[value] = rim_mat
