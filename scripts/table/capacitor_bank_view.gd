class_name CapacitorBankView
extends Node3D
## Die Kondensator-Bank: der physische ⚡-Speicher neben dem Chip-Rack in der
## Geld-Ecke. Eine Reihe einzelner Zellen in einer Schiene - Zellenzahl = Deckel
## (ein Hub-Ausbau verlängert die Bank sichtbar), leuchtende Zellen = Bestand.
## Ladung kommt einzeln herein, also muss der Stand ABZÄHLBAR sein; von der
## Übersicht wird fast senkrecht von oben geschaut, darum liegt die Bank flach
## in der XZ-Ebene statt als Turm. Nur EMISSION, keine OmniLights: die Boden-
## kacheln vertragen nur 16 Lichter (siehe TableGround).

## Zellen laufen entlang +Z (auf dem Schirm waagerecht - ein Füllstand liest sich
## von links nach rechts), Reihen stapeln nach +X. Die Zellen sind bewusst GROSS:
## aus der Übersichts-Distanz muss man sie zählen können, sonst ist es nur ein
## Streifen. Ab ROW_CAP bricht die Bank in eine zweite Reihe um, statt aus der
## Schatz-Ecke zu wachsen.
const ROW_CAP := 8
const CELL_PITCH := 1.0           # Achsabstand der Zellen (entlang +Z)
const ROW_PITCH := 0.95           # Reihenabstand (entlang +X)
const CELL_SIZE := Vector3(0.64, 0.34, 0.78)
const RAIL_HEIGHT := 0.12
const RAIL_MARGIN := 0.26         # Überstand der Schiene an beiden Enden

## Geladene Zelle: überhelles Cyan (bloomt im HDR). Leere Zelle bleibt dunkles
## Glas mit einem Hauch Saum - so bleibt der Deckel ablesbar.
const CELL_LIT := CasinoStyle.CHARGE
const CELL_EMPTY_ALBEDO := Color(0.06, 0.09, 0.13)
## Leere Zellen glimmen schwach mit: der DECKEL soll ablesbar sein, nicht nur
## der Bestand - sonst sähe eine leere Bank aus wie gar keine Bank.
const CELL_EMPTY_EMISSION := Color(0.14, 0.34, 0.40)
const CELL_EMPTY_ENERGY := 1.1
const RAIL_ALBEDO := Color(0.09, 0.10, 0.14)

var _charge := 0
var _cap := 0
var _cells: Array[MeshInstance3D] = []
var _rail: MeshInstance3D
var _cell_mesh: BoxMesh
var _lit_material: StandardMaterial3D
var _empty_material: StandardMaterial3D
var _pulse_tween: Tween

## Einziger Eingang: scene_root spiegelt GameRun.charge/charge_cap hierher.
## Ändert sich der Deckel, wird die Bank neu gebaut (sie wird sichtbar länger).
func set_charge(charge: int, cap: int) -> void:
	var safe_cap := maxi(cap, 0)
	if safe_cap != _cap:
		_cap = safe_cap
		_build()
	_charge = clampi(charge, 0, _cap)
	_apply_fill()

## Kurzer elastischer Pop - eine Ladung ist eben eingetroffen (wie ChipStackView).
func pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	scale = Vector3.ONE * 1.16
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector3.ONE, 0.35)

func charge_count() -> int:
	return _charge

func cap_count() -> int:
	return _cap

## Reihenzahl und längste Reihe für den aktuellen Deckel (ausgewogen aufgeteilt).
func _row_layout() -> Array[int]:
	var rows: Array[int] = []
	if _cap <= 0:
		return rows
	var count := int(ceil(float(_cap) / float(ROW_CAP)))
	var base := _cap / count
	var extra := _cap % count
	for r in count:
		rows.append(base + (1 if r < extra else 0))
	return rows

## Längste je mögliche Bank (volle erste Reihe). Der Aufrufer skaliert danach,
## damit ein wachsender Deckel den Platz nicht sprengt.
static func max_length() -> float:
	return float(ROW_CAP) * CELL_PITCH + RAIL_MARGIN * 2.0

## Weltlänge der Bank (entlang Z) - der Aufrufer richtet Nachbarn danach aus.
func bank_length() -> float:
	var rows := _row_layout()
	var longest := 0
	for n in rows:
		longest = maxi(longest, n)
	return float(maxi(longest, 1)) * CELL_PITCH + RAIL_MARGIN * 2.0

func _build() -> void:
	for cell in _cells:
		cell.queue_free()
	_cells.clear()
	if _rail != null:
		_rail.queue_free()
		_rail = null
	_ensure_resources()
	if _cap <= 0:
		return

	var rows := _row_layout()
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(float(rows.size()) * ROW_PITCH, RAIL_HEIGHT, bank_length())
	var rail_material := StandardMaterial3D.new()
	rail_material.albedo_color = RAIL_ALBEDO
	rail_material.metallic = 0.7
	rail_material.roughness = 0.35
	_rail = MeshInstance3D.new()
	_rail.name = "Rail"
	_rail.mesh = rail_mesh
	_rail.material_override = rail_material
	_rail.position = Vector3(0.0, RAIL_HEIGHT * 0.5, 0.0)
	_rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rail)

	# Zellen je Reihe mittig über der Schiene aufreihen; gefüllt wird von -Z nach
	# +Z, Reihe für Reihe (Index = Füllreihenfolge).
	var row_first := -(float(rows.size() - 1) * 0.5) * ROW_PITCH
	var index := 0
	for r in rows.size():
		var in_row: int = rows[r]
		var first := -(float(in_row - 1) * 0.5) * CELL_PITCH
		for k in in_row:
			var cell := MeshInstance3D.new()
			cell.name = "Cell%d" % index
			cell.mesh = _cell_mesh
			cell.position = Vector3(row_first + float(r) * ROW_PITCH,
				RAIL_HEIGHT + CELL_SIZE.y * 0.5, first + float(k) * CELL_PITCH)
			cell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(cell)
			_cells.append(cell)
			index += 1

func _apply_fill() -> void:
	for i in _cells.size():
		_cells[i].material_override = _lit_material if i < _charge else _empty_material

func _ensure_resources() -> void:
	if _cell_mesh != null:
		return
	_cell_mesh = BoxMesh.new()
	_cell_mesh.size = CELL_SIZE
	# Unbeschattet: die Zellen sind Leuchtmittel, keine beleuchteten Körper -
	# so bleibt der Stand aus jeder Distanz gleich hell ablesbar.
	_lit_material = StandardMaterial3D.new()
	_lit_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lit_material.albedo_color = CELL_LIT
	_empty_material = StandardMaterial3D.new()
	_empty_material.albedo_color = CELL_EMPTY_ALBEDO
	_empty_material.metallic = 0.4
	_empty_material.roughness = 0.25
	_empty_material.emission_enabled = true
	_empty_material.emission = CELL_EMPTY_EMISSION
	_empty_material.emission_energy_multiplier = CELL_EMPTY_ENERGY
