class_name ChipStackView
extends Node3D
## Zeigt den Geldstand (siehe GameRun.money) als physische Neon-Pokerchips auf
## dem Tisch - echte 3D-Objekte wie die Würfel, zwischen Würfel-Pool und Becher
## (siehe scene_root.tscn: ChipStack zwischen PoolTrayView und DiceCup).
##
## Der Betrag wird gierig in Stückelungen zerlegt (siehe DENOMINATIONS): erst so
## viele 5er wie möglich, der Rest als 1er. Jede Stückelung stapelt sich in
## Spalten (Chips liegen flach übereinander); überläuft eine Spalte COLUMN_CAP,
## beginnt rechts daneben eine neue. Die 5er-Spalten stehen links, die 1er rechts.
## Die ganze Anordnung ist um den lokalen Ursprung in X zentriert, damit sie
## mittig zwischen Pool und Becher sitzt.
##
## set_money() baut den Turm bei jeder Geldänderung neu auf (siehe
## scene_root._on_money_changed).

## Stückelungen (Wert -> Neon-Farbe), absteigend für die gierige Zerlegung.
## Vorerst nur 1 und 5 (siehe Aufgabenstellung).
const DENOMINATIONS := [
	{"value": 5, "color": Color("fe5f55")},  # Neon-Rot (CasinoStyle.RED)
	{"value": 1, "color": Color("2f9ff0")},  # Neon-Blau (CasinoStyle.BLUE)
]

const CHIP_RADIUS := 0.9  # Chip-Radius (etwas breiter als ein Würfel)
const CHIP_HEIGHT := 0.28  # Chip-Dicke (flach, Pokerchip)
const COLUMN_CAP := 8  # max. Chips je Spalte, dann beginnt eine neue Spalte rechts
const COLUMN_SPACING := CHIP_RADIUS * 2.3  # X-Abstand benachbarter Spalten
const RIM_INNER := CHIP_RADIUS * 0.82  # innerer Radius des leuchtenden Randrings
const RIM_OUTER := CHIP_RADIUS * 1.0   # äußerer Radius des Randrings
const RIM_EMISSION := 3.4  # Emissions-Energie des Neon-Rands (Glow/Bloom)

## Die gebauten Chip-Knoten (für sauberes Neu-Aufbauen).
var _chip_nodes: Array[Node3D] = []

## Geteilte Meshes/Materialien je Stückelung (nach Wert), damit nicht jeder Chip
## eigene Ressourcen anlegt.
var _body_mesh: CylinderMesh
var _rim_mesh: TorusMesh
var _body_materials: Dictionary = {}  # value -> StandardMaterial3D (Körper)
var _rim_materials: Dictionary = {}   # value -> StandardMaterial3D (Neon-Rand)

## Baut den Chip-Turm für amount neu auf. Nicht-positive Beträge lassen den Tisch
## leer (kein Chip).
func set_money(amount: int) -> void:
	_ensure_resources()
	for node in _chip_nodes:
		node.queue_free()
	_chip_nodes.clear()
	if amount <= 0:
		return

	# Gierige Zerlegung in Spalten: {value, count} je Spalte, 5er zuerst.
	var columns: Array = []
	var rest := amount
	for denom in DENOMINATIONS:
		var value: int = denom["value"]
		var count := rest / value
		rest -= count * value
		_append_columns(columns, value, count)

	# Spalten in X zentrieren.
	var n := columns.size()
	for i in n:
		var x := (float(i) - float(n - 1) * 0.5) * COLUMN_SPACING
		_build_column(columns[i]["value"], columns[i]["count"], x)

## Zerlegt count Chips eines Werts in Spalten von höchstens COLUMN_CAP und hängt
## sie an columns an (jede Spalte {value, count}).
func _append_columns(columns: Array, value: int, count: int) -> void:
	while count > 0:
		var height := mini(count, COLUMN_CAP)
		columns.append({"value": value, "count": height})
		count -= height

## Stapelt count Chips des Werts value an lokaler X-Position x (flach übereinander,
## Unterkante auf der Tischfläche y=0).
func _build_column(value: int, count: int, x: float) -> void:
	for j in count:
		var chip := _build_chip(value)
		chip.position = Vector3(x, CHIP_HEIGHT * (float(j) + 0.5), 0.0)
		add_child(chip)
		_chip_nodes.append(chip)

## Ein einzelner Neon-Pokerchip: dunkler Körper-Zylinder, leuchtender Randring in
## der Stückelungsfarbe und der Wert als flach aufliegende Leuchtziffer.
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
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # flach auf die Oberseite, Ziffer nach oben
	label.position.y = CHIP_HEIGHT * 0.5 + 0.02
	label.modulate = DENOMINATIONS_color(value)
	label.outline_modulate = Color(0.02, 0.02, 0.04, 1.0)
	label.outline_size = 28
	label.no_depth_test = false
	chip.add_child(label)

	return chip

## Neon-Farbe einer Stückelung (siehe DENOMINATIONS), Weiß als Rückfall.
static func DENOMINATIONS_color(value: int) -> Color:
	for denom in DENOMINATIONS:
		if denom["value"] == value:
			return denom["color"]
	return Color.WHITE

## Baut die geteilten Meshes und Materialien einmalig auf.
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
		body_mat.albedo_color = Color(0.07, 0.08, 0.11)  # fast schwarzer Körper
		body_mat.metallic = 0.2
		body_mat.roughness = 0.5
		body_mat.emission_enabled = true
		body_mat.emission = color
		body_mat.emission_energy_multiplier = 0.25  # nur schwaches Eigenleuchten des Körpers
		_body_materials[value] = body_mat

		var rim_mat := StandardMaterial3D.new()
		rim_mat.albedo_color = color
		rim_mat.emission_enabled = true
		rim_mat.emission = color
		rim_mat.emission_energy_multiplier = RIM_EMISSION  # kräftiger Neon-Rand (Glow)
		_rim_materials[value] = rim_mat
