class_name CardRecessView
extends Node3D

## Die VERTIEFUNG eines Kassetten-Platzes im Laden (Spieler-Wunsch 2026-10-29):
## dieselbe Mulde wie im Magazin - Saum, Boden, ausgekleidete Wände und die BUCHSE am
## Bild-rechten Ende -, nur in die Tischfläche gesenkt statt in ein Tablett. Die
## liegende Karte ist darin bündig mit der Anzeige. Das LOCH darüber schneidet
## scene_root; dieser Körper meldet nur seine Öffnung.

## Wandstärke der Hülle um die Mulde - sie liegt unter der opaken Anzeige, man sieht
## nur ihre Innenseite.
const HULL := 0.06

var _scale := 1.0
var _bay := Vector2.ZERO
var _seam: StandardMaterial3D
var _floor: ShaderMaterial
var _built := false

func _init() -> void:
	name = "Kassettenmulde"

## Die Lippe, die zwischen zwei Nachbar-Mulden mindestens stehen bleibt.
const LIP_MIN := ShelfStackView.LIP_MIN

## Der EINE Schreiber: Glaspunkt der Platzmitte und Kartenmaßstab; pitch (> 0) ist
## die Teilung der Reihe - die Mulde wird nie länger, als daß ein Steg bleibt. Gebaut
## wird nur, wenn sich das Maß ändert; der Ort wird immer nachgezogen.
func seat(glass_point: Vector3, cell_scale: float, pitch := 0.0) -> void:
	var bay := ShelfStackView.bay_size_for(cell_scale)
	if pitch > 0.0:
		bay.y = minf(bay.y, maxf(pitch - LIP_MIN, DataCellView.HEIGHT * cell_scale))
	if not _built or not is_equal_approx(cell_scale, _scale) or not bay.is_equal_approx(_bay):
		_build(cell_scale, bay)
	global_position = glass_point - Vector3.UP * depth()
	# Das Samt-Licht mißt in Welt an der Öffnung, der Flor bleibt an der Mulde.
	PackPitView.tune_lining(_floor, 1.0, ShelfStackView.BAY_FLOOR_ALBEDO,
		ShelfStackView.BAY_FLOOR_ENERGY,
		Rect2(Vector2(glass_point.x, glass_point.z) - _bay * 0.5, _bay), glass_point.y,
		depth(), PackPitView.GLOW_COLOR, null)
	_floor.set_shader_parameter("pattern_local", 1.0)

## Wie tief die Mulde unter die Fläche reicht: genau Muldenboden plus Kartendicke.
func depth() -> float:
	return ShelfStackView.deck_height_for(_scale)

## Die halbe Öffnung in Welt (X quer, Z längs) - das Loch in der Anzeige.
func opening_half() -> Vector2:
	return _bay * 0.5

## Der Glaspunkt, auf dem die Karte LIEGT: ihre Oberkante schließt mit der Fläche ab.
func card_point(glass_point: Vector3) -> Vector3:
	return glass_point - Vector3.UP * DataCellView.DEPTH * _scale

## Der Saum trägt die Sortenfarbe der Karte, leer den kühlen Leerton des Magazins.
func set_tint(tint: Color) -> void:
	if _seam == null:
		return
	_seam.albedo_color = tint
	_seam.emission = tint
	_seam.emission_energy_multiplier = ShelfStackView.SEAM_EMPTY_ENERGY \
		if tint == ShelfStackView.BAY_EMPTY else ShelfStackView.SEAM_FILLED_ENERGY

func _build(cell_scale: float, bay: Vector2) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_scale = cell_scale
	_bay = bay
	_built = true
	var deep := depth()
	var hull := TableProps.metal(ShelfStackView.PLATE_ALBEDO, ShelfStackView.PLATE_EMISSION,
		ShelfStackView.PLATE_ENERGY, 0.35, 0.55)
	# Die Hülle: Boden und vier Wände knapp außerhalb der Öffnung - unter der Anzeige.
	TableProps.box(self, "Huelle", Vector3(_bay.x + HULL * 2.0, HULL, _bay.y + HULL * 2.0),
		Vector3(0.0, -HULL * 0.5, 0.0), hull)
	for side in [-1.0, 1.0]:
		var tag := "A" if side < 0.0 else "B"
		TableProps.box(self, "HuelleL" + tag, Vector3(HULL, deep, _bay.y + HULL * 2.0),
			Vector3(side * (_bay.x + HULL) * 0.5, deep * 0.5, 0.0), hull)
		TableProps.box(self, "HuelleQ" + tag, Vector3(_bay.x, deep, HULL),
			Vector3(0.0, deep * 0.5, side * (_bay.y + HULL) * 0.5), hull)
	_seam = StandardMaterial3D.new()
	_seam.metallic = 0.2
	_seam.roughness = 0.5
	_seam.emission_enabled = true
	set_tint(ShelfStackView.BAY_EMPTY)
	_floor = ShaderMaterial.new()
	_floor.shader = load("res://assets/shaders/pit_lining.gdshader")
	ShelfStackView.build_bay(self, _bay, _seam, cell_scale,
		ShelfStackView.bay_wall_material(cell_scale), _floor)
