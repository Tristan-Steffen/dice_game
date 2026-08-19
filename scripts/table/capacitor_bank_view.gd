class_name CapacitorBankView
extends Node3D
## Die Kondensator-Bank: der physische ⚡-Speicher im freien Chip-Platz. Ein
## FESTES 5×5-Raster - alle 25 Zellen stehen von Anfang an da, denn der Ausbau
## soll als "eine Reihe erwacht" lesbar sein, nicht als wachsendes Bauteil.
## Jede Zelle IST ein liegender Radial-Elko: dunkle Dose, Crimpring an der
## Fußseite, zwei Drahtbeine, die schräg auf die Grundplatte auslaufen - die
## Platte liest sich damit als Platine. LIEGEND, weil vom Tisch fast senkrecht
## geschaut wird (Übersicht ~20°, Stationen 15°): ein stehender Elko zeigte nur
## seinen runden Deckel.
## Drei Zellzustände - dunkel (Reihe noch gesperrt), schwach cyan glimmend
## (Deckel erreicht, leer) und heiß bernsteinfarben pulsierend (eine Ladung liegt
## darin) - und sie sitzen alle auf der DOSE; Ring und Beine bleiben in jedem
## Zustand statisch. Der Deckel wächst nur in 5er-Schritten (GameRun.CHARGE_ROW),
## also schaltet immer eine ganze Reihe um.
## Nur EMISSION/unshaded-Albedo, keine OmniLights: die Bodenkacheln vertragen nur
## 16 Lichter (siehe TableGround).

## Der Chip-Platz ist flach (~3.16:1), aber scene_root lässt die Bank in den
## freien Filz DARUNTER wachsen (CAPACITOR_SLOT_TALL ≈ 2×), sodass der Zielplatz
## ~1.58:1 wird - kein flacher Streifen mehr, sondern ein voller Block. Die
## Dosenachse liegt entlang +Z (liest sich als Füllstand), Reihen stapeln nach
## +X. Der Fußabdruck ist auf das gewachsene Platz-Verhältnis getrimmt
## (max_width/max_length ≈ 186/294), damit BEIDE Achsen zugleich fast ganz
## gefüllt sind.
const GRID_COLS := 5
const GRID_ROWS := 5              # COLS × ROWS = 25 = Maximaldeckel (GameRun)
const CELL_PITCH := 1.0           # Achsabstand der Spalten (entlang +Z)
const ROW_PITCH := 0.64           # Reihenabstand (entlang +X)

## Bauteilmaße. Dose + Beine belegen 0.9 des Spaltenrasters; die Dose selbst ist
## ~1.5× so lang wie dick, sonst liest sie sich nicht als Elko.
const CAN_DIAMETER := 0.42
const CAN_LENGTH := 0.66
const LEG_REACH := 0.24           # Z-Auslauf der Beine (Dose + Beine = 0.9)
const LEG_DROP := 0.09            # Höhenverlust bis auf die Platte
const LEG_RADIUS := 0.026
const LEG_SPREAD := 0.14          # Abstand der beiden Beine zueinander
## Der Crimpring ist die BREITESTE Stelle - er liegt auf, die Dose schwebt einen
## Hauch. Etwas größer als die Dose, damit die gerollte Bördelkante in jedem
## Zustand als eigene Kante liest. Er sitzt BÜNDIG auf der Beinstirn: rückte er
## nach innen, bliebe ein Dosenzipfel dahinter stehen - und aus der Übersicht
## zerfiele jede geladene Zelle in zwei Leuchtflecken statt in einen.
const CRIMP_DIAMETER := 0.47
const CRIMP_HEIGHT := 0.055
## Einen Hauch über die Dosenstirn hinaus: bündig kämpften Ring- und Dosendeckel
## um die Tiefe und zerfaserten den Ring aus der Nähe in ein Flimmermuster.
const CRIMP_PROUD := 0.006
const RAIL_HEIGHT := 0.1
const RAIL_MARGIN := 0.1          # Überstand der Grundplatte entlang Z
const RAIL_MARGIN_X := 0.04       # Überstand entlang X (knapper: schmale Achse)
## Die Fuge zwischen den Reihen ist der TEURE Wert: auf dem Schirm ist eine Reihe
## nur wenige Pixel hoch, eine zu knappe Fuge lässt die Reihen zu Bändern
## verschmelzen. ROW_PITCH − CRIMP_DIAMETER hält sie offen.

## Geladene Zelle: heißer Bernstein - BEWUSST eine andere Farbe als das Börsen-
## Cyan (CasinoStyle.CHARGE), damit ein gespeicherter Punkt sich krass vom leeren
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
## Ring dunkler als jede Dose, Beine heller: verzinnter Draht auf dunkler Platine.
const CRIMP_ALBEDO := Color(0.03, 0.04, 0.055)
const LEG_ALBEDO := Color(0.34, 0.37, 0.44)
const LEG_EMISSION := Color(0.10, 0.11, 0.14)

## Pulsieren der geladenen Zelle: je Zelle eigene Phase, damit die Bank atmet
## statt im Block zu blinken. Obergrenze bewusst knapp - der Bernstein soll
## bloomen, aber nicht ins Weiße kippen.
const FLICKER_FLOOR := 0.8
const FLICKER_BAND := 0.3

var _charge := 0
var _cap := 0
var _cells: Array[MeshInstance3D] = []
var _can_mesh: CylinderMesh
var _crimp_mesh: CylinderMesh
var _leg_mesh: CylinderMesh
var _empty_material: StandardMaterial3D
var _locked_material: StandardMaterial3D
var _crimp_material: StandardMaterial3D
var _leg_material: StandardMaterial3D
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
	# Der Crimpring liegt auf, also hängt die Dosenachse an SEINEM Radius.
	var axis_y := RAIL_HEIGHT + CRIMP_DIAMETER * 0.5
	for r in GRID_ROWS:
		for k in GRID_COLS:
			var cell := MeshInstance3D.new()
			cell.name = "Cell%d" % (r * GRID_COLS + k)
			cell.mesh = _can_mesh
			# Die Dose LIEGT: die Wurzel kippt um 90°. Danach zeigt im Zellframe
			# +Y die Dosenachse (Welt +Z, Beinseite) und +Z nach UNTEN.
			cell.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			# Dose + Beine mittig auf dem Rasterpunkt, also sitzt die Dose um
			# einen halben Beinauslauf davor.
			cell.position = Vector3(row_first + float(r) * ROW_PITCH, axis_y,
				col_first + float(k) * CELL_PITCH - LEG_REACH * 0.5)
			cell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_cell_parts(cell)
			add_child(cell)
			_cells.append(cell)

## Ring und Beine hängen an der Zelle, teilen sich aber Mesh und Material über
## alle 25 Zellen - der Zustand sitzt allein auf der Dose (der Zellwurzel).
func _add_cell_parts(cell: MeshInstance3D) -> void:
	var crimp := MeshInstance3D.new()
	crimp.name = "Crimp"
	crimp.mesh = _crimp_mesh
	crimp.material_override = _crimp_material
	crimp.position = Vector3(0.0, CAN_LENGTH * 0.5 - CRIMP_HEIGHT * 0.5 + CRIMP_PROUD, 0.0)
	crimp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(crimp)
	# Beide Beine treten an DERSELBEN Stirn aus (alle 25 gleich gerichtet) und
	# neigen sich so weit, dass ihre Spitzen genau die Platte treffen.
	var tilt := atan2(LEG_DROP, LEG_REACH)
	for side in 2:
		var leg := MeshInstance3D.new()
		leg.name = "Leg%d" % side
		leg.mesh = _leg_mesh
		leg.material_override = _leg_material
		leg.position = Vector3((float(side) * 2.0 - 1.0) * LEG_SPREAD * 0.5,
			CAN_LENGTH * 0.5 + LEG_REACH * 0.5, CRIMP_DIAMETER * 0.5 - LEG_DROP * 0.5)
		leg.rotation = Vector3(tilt, 0.0, 0.0)
		leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cell.add_child(leg)

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

## Die geladene Zelle glüht bernsteinfarben und atmet dabei - zwei gegeneinander
## laufende Sinüsse, je Zelle eigene Phase (aus dem Index).
func _process(delta: float) -> void:
	_time += delta
	for i in _lit_materials:
		var jitter := 0.5 + 0.5 * sin(_time * 2.6 + i * 2.39) * sin(_time * 1.7 + i * 5.7)
		var material: StandardMaterial3D = _lit_materials[i]
		material.albedo_color = CELL_STORM * (FLICKER_FLOOR + FLICKER_BAND * jitter)

func _ensure_resources() -> void:
	if _can_mesh != null:
		return
	# Wenige Segmente: 25 Zellen à 4 Körper, und bei Rasterhöhe von wenigen
	# Pixeln sieht niemand die Facetten.
	_can_mesh = CylinderMesh.new()
	_can_mesh.top_radius = CAN_DIAMETER * 0.5
	_can_mesh.bottom_radius = CAN_DIAMETER * 0.5
	_can_mesh.height = CAN_LENGTH
	_can_mesh.radial_segments = 12
	_can_mesh.rings = 0
	_crimp_mesh = CylinderMesh.new()
	_crimp_mesh.top_radius = CRIMP_DIAMETER * 0.5
	_crimp_mesh.bottom_radius = CRIMP_DIAMETER * 0.5
	_crimp_mesh.height = CRIMP_HEIGHT
	_crimp_mesh.radial_segments = 12
	_crimp_mesh.rings = 0
	_leg_mesh = CylinderMesh.new()
	_leg_mesh.top_radius = LEG_RADIUS
	_leg_mesh.bottom_radius = LEG_RADIUS
	_leg_mesh.height = sqrt(LEG_REACH * LEG_REACH + LEG_DROP * LEG_DROP)
	_leg_mesh.radial_segments = 6
	_leg_mesh.rings = 0
	# Erwacht und gesperrt bleiben BESCHATTET, damit die Rundung der Dose unter
	# den Szenenlichtern liest; nur die geladene Dose ist unshaded.
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
	_crimp_material = StandardMaterial3D.new()
	_crimp_material.albedo_color = CRIMP_ALBEDO
	_crimp_material.metallic = 0.6
	_crimp_material.roughness = 0.45
	_leg_material = StandardMaterial3D.new()
	_leg_material.albedo_color = LEG_ALBEDO
	_leg_material.metallic = 0.9
	_leg_material.roughness = 0.28
	_leg_material.emission_enabled = true
	_leg_material.emission = LEG_EMISSION
