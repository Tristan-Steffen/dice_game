class_name CapacitorBankView
extends Node3D
## Die Kondensator-Bank: der physische ⚡-Speicher im freien Chip-Platz. Ein
## FESTES 5×5-Raster - alle 25 Zellen stehen von Anfang an da, denn der Ausbau
## soll als "eine Reihe erwacht" lesbar sein, nicht als wachsendes Bauteil.
## Drei Zellzustände: dunkel (Reihe noch gesperrt), schwach cyan glimmend (Deckel
## erreicht, leer) und heiß golden pulsierend (eine Ladung liegt darin). Der
## Deckel wächst nur in 5er-Schritten (GameRun.CHARGE_ROW), also schaltet immer
## eine ganze Reihe um.
## Von der Übersicht wird fast senkrecht geschaut, darum liegt das Raster flach
## in der XZ-Ebene. Nur EMISSION/unshaded-Albedo, keine OmniLights: die Boden-
## kacheln vertragen nur 16 Lichter (siehe TableGround).

## Der Chip-Platz ist flach (~3.16:1), aber scene_root lässt die Bank in den
## freien Filz DARUNTER wachsen (CAPACITOR_SLOT_TALL ≈ 2×), sodass der Zielplatz
## ~1.58:1 wird - kein flacher Streifen mehr, sondern ein voller Block. Immer
## noch breite, flache RIEGEL: Spalten entlang +Z (liest sich als Füllstand),
## Reihen stapeln nach +X. Der Fußabdruck ist auf das gewachsene Platz-Verhältnis
## getrimmt (max_width/max_length ≈ 186/294), damit BEIDE Achsen zugleich fast
## ganz gefüllt sind. Ränder und Zellabstände bleiben knapp: das Raster füllt.
const GRID_COLS := 5
const GRID_ROWS := 5              # COLS × ROWS = 25 = Maximaldeckel (GameRun)
const CELL_PITCH := 1.0           # Achsabstand der Spalten (entlang +Z)
const ROW_PITCH := 0.64           # Reihenabstand (entlang +X)
## Die Fuge zwischen den Reihen ist der TEURE Wert: auf dem Schirm ist eine Reihe
## nur wenige Pixel hoch, eine zu knappe Fuge lässt die Reihen zu Bändern
## verschmelzen. Darum bleibt sie relativ zur kurzen Achse großzügiger.
const CELL_SIZE := Vector3(0.52, 0.22, 0.93)
const RAIL_HEIGHT := 0.1
const RAIL_MARGIN := 0.1          # Überstand der Grundplatte entlang Z
const RAIL_MARGIN_X := 0.04       # Überstand entlang X (knapper: schmale Achse)

## Geladene Zelle: heißes Gold - BEWUSST eine andere Farbe als das Börsen-Cyan
## (CasinoStyle.CHARGE), damit ein gespeicherter Punkt sich krass vom leeren
## (cyan glimmenden) Platz abhebt. Leere Zelle glimmt schwach cyan mit - der
## DECKEL soll ablesbar sein, nicht nur der Bestand. Gesperrte Zelle bleibt
## totes Glas: das Bauteil ist da, aber stromlos.
## Knapp über 1 im Rot, damit es blüht, aber NICHT ins flache Gelb clippt -
## sonst verschmelzen benachbarte geladene Zellen zu einem einzigen Balken und
## der Bestand ist nicht mehr abzählbar.
const CELL_STORM := Color(1.0, 0.48, 0.06)
const CELL_EMPTY_ALBEDO := Color(0.06, 0.09, 0.13)
const CELL_EMPTY_EMISSION := Color(0.16, 0.40, 0.46)
const CELL_EMPTY_ENERGY := 1.6
## Gesperrt bleibt klar AUS, aber als Bauteil sichtbar: ein Hauch Saum hebt die
## Zelle von der Platte ab - sonst ist der ganze ungenutzte Teil nur ein Loch.
const CELL_LOCKED_ALBEDO := Color(0.05, 0.06, 0.08)
const CELL_LOCKED_EMISSION := Color(0.03, 0.05, 0.06)
const RAIL_ALBEDO := Color(0.09, 0.10, 0.14)

## Pulsieren der geladenen Zelle: je Zelle eigene Phase, damit die Bank atmet
## statt im Block zu blinken. Obergrenze bewusst knapp - das Gold soll bloomen,
## aber nicht ins Weiße kippen.
const FLICKER_FLOOR := 0.8
const FLICKER_BAND := 0.3

var _charge := 0
var _cap := 0
var _cells: Array[MeshInstance3D] = []
var _cell_mesh: BoxMesh
var _empty_material: StandardMaterial3D
var _locked_material: StandardMaterial3D
## Je geladener Zelle eine EIGENE Material-Instanz (Index -> Material): nur so
## pulst jede in ihrem eigenen Takt statt als synchroner Block.
var _lit_materials := {}
var _time := 0.0
var _pulse_tween: Tween
## Ruhe-Skalierung (setzt der Aufrufer): pulse muss HIERHIN zurückkehren - ein
## Tween auf Vector3.ONE ließe die Bank nach dem ersten Treffer dauerhaft über
## ihren Platz hinauswachsen.
var _rest_scale := Vector3.ONE

func _ready() -> void:
	_build()
	_apply_fill()
	set_process(false)

## Einziger Eingang: scene_root spiegelt GameRun.charge/charge_cap hierher.
## Das Raster steht fest - Deckel wie Bestand sind reine Umfärbungen.
func set_charge(charge: int, cap: int) -> void:
	_cap = clampi(cap, 0, GRID_COLS * GRID_ROWS)
	_charge = clampi(charge, 0, _cap)
	if not _cells.is_empty():
		_apply_fill()

## Kurzer elastischer Pop - eine Ladung ist eben eingetroffen (wie ChipStackView).
func pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	else:
		_rest_scale = scale  # nur im Ruhezustand einfangen, nie mitten im Pop
	scale = _rest_scale * 1.16
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", _rest_scale, 0.35)

func charge_count() -> int:
	return _charge

func cap_count() -> int:
	return _cap

## Z-Länge des Rasters (lange Achse) - der Aufrufer skaliert die Bank damit in
## den Chip-Platz. Fest, denn das Raster wächst nie mehr.
static func max_length() -> float:
	return float(GRID_COLS) * CELL_PITCH + RAIL_MARGIN * 2.0

## X-Breite des Rasters (kurze Achse) - der Aufrufer prüft BEIDE Achsen, damit
## die Bank nie in die Nachbarzelle wächst.
static func max_width() -> float:
	return float(GRID_ROWS) * ROW_PITCH + RAIL_MARGIN_X * 2.0

func _build() -> void:
	_ensure_resources()
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(max_width(), RAIL_HEIGHT, max_length())
	var rail_material := StandardMaterial3D.new()
	rail_material.albedo_color = RAIL_ALBEDO
	rail_material.metallic = 0.7
	rail_material.roughness = 0.35
	var rail := MeshInstance3D.new()
	rail.name = "Rail"
	rail.mesh = rail_mesh
	rail.material_override = rail_material
	rail.position = Vector3(0.0, RAIL_HEIGHT * 0.5, 0.0)
	rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rail)

	# Alle 25 Zellen mittig über der Platte; gefüllt wird von -Z nach +Z,
	# Reihe für Reihe (Index = Füllreihenfolge = Reihe*5 + Spalte).
	var row_first := -(float(GRID_ROWS - 1) * 0.5) * ROW_PITCH
	var col_first := -(float(GRID_COLS - 1) * 0.5) * CELL_PITCH
	for r in GRID_ROWS:
		for k in GRID_COLS:
			var cell := MeshInstance3D.new()
			cell.name = "Cell%d" % (r * GRID_COLS + k)
			cell.mesh = _cell_mesh
			cell.position = Vector3(row_first + float(r) * ROW_PITCH,
				RAIL_HEIGHT + CELL_SIZE.y * 0.5, col_first + float(k) * CELL_PITCH)
			cell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(cell)
			_cells.append(cell)

func _apply_fill() -> void:
	for i in _cells.size():
		if i < _charge:
			if not _lit_materials.has(i):
				var lit := StandardMaterial3D.new()
				lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				lit.albedo_color = CELL_STORM
				_lit_materials[i] = lit
			_cells[i].material_override = _lit_materials[i]
		else:
			_lit_materials.erase(i)
			_cells[i].material_override = _empty_material if i < _cap else _locked_material
	# Puls-Takt nur, solange etwas gespeichert ist.
	set_process(not _lit_materials.is_empty())

## Die geladene Zelle glüht golden und atmet dabei - zwei gegeneinander laufende
## Sinüsse, je Zelle eigene Phase (aus dem Index).
func _process(delta: float) -> void:
	_time += delta
	for i in _lit_materials:
		var jitter := 0.5 + 0.5 * sin(_time * 2.6 + i * 2.39) * sin(_time * 1.7 + i * 5.7)
		var material: StandardMaterial3D = _lit_materials[i]
		material.albedo_color = CELL_STORM * (FLICKER_FLOOR + FLICKER_BAND * jitter)

func _ensure_resources() -> void:
	if _cell_mesh != null:
		return
	_cell_mesh = BoxMesh.new()
	_cell_mesh.size = CELL_SIZE
	_empty_material = StandardMaterial3D.new()
	_empty_material.albedo_color = CELL_EMPTY_ALBEDO
	_empty_material.metallic = 0.4
	_empty_material.roughness = 0.25
	_empty_material.emission_enabled = true
	_empty_material.emission = CELL_EMPTY_EMISSION
	_empty_material.emission_energy_multiplier = CELL_EMPTY_ENERGY
	_locked_material = StandardMaterial3D.new()
	_locked_material.albedo_color = CELL_LOCKED_ALBEDO
	_locked_material.metallic = 0.5
	_locked_material.roughness = 0.3
	_locked_material.emission_enabled = true
	_locked_material.emission = CELL_LOCKED_EMISSION
