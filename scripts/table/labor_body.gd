class_name LaborBody
extends Node3D
## Der Körper des LABORS (Spieler-Wahl „R3 · Sektoren“, im Spielmaß build_r4 aus
## tools/blender_labor_variants.py): eine ovale MESSING-Schale mit dunklem Feldgrund, mittig
## die runde KAMMER mit Messing-Kragen und hellem Leuchtboden samt Punktraster, je Flanke drei
## RUNDENFELDER (Gold = Wurf, Violett = vergangene Runde, aus = gedimmtes Violett), darüber
## die GLASHAUBE, solange der Auftrag läuft; rechts Namens-Schild, START-Taste und Status-
## Fenster, je mit leuchtendem Stich zur Schale. Ursprung = Stationsmitte auf dem Tisch,
## lokal +X = Bild-oben, +Z = Bild-rechts. Heller als der Schwarzmarkt, alles Eigenlicht
## unter der Bloom-Schwelle.

const DISH_TOP := 0.5
const GROUND_TOP := 0.52
const FLOOR_TOP := 0.53
const FIELD_TOP := 0.535
const COLLAR_TOP := 0.62
const COLLAR_WIDTH := 0.32
## Gemessen: der höchste Einsatz (ein Würfel des Seelen-Transfers) reicht 1,99 über den Kragen.
const HOOD_HEIGHT := 2.0
## Die Haube verjüngt sich nach oben: ihr Deckelring liegt so von der Tischkamera aus über der
## Kammer statt über den linken Rundenfeldern.
const HOOD_TAPER := 0.8
const HOOD_LIFT := 2.6
const HOOD_TIME := 0.45
const HOOD_ALPHA := 0.13
const RIM_HEIGHT := 0.025
const DOT_PITCH := 0.5
const FIELD_STAGGER := 0.12
const FIELD_FADE := 0.3
const KEY_LIFT := 0.05
## Der Trage-Bogen eines Einsatzes in die Kammer.
const FLY_TIME := 0.55
const FLY_PEAK := 3.0
## Das Aufleuchten beim ersten Erscheinen.
const APPEAR_TIME := 0.5
## Die Karten der Presse liegen als Treppe: je Karte so weit Bild-rechts und Bild-unten.
const STAIR_STEP := Vector2(0.4, -0.44)
## Abstand der zwei Würfel des Seelen-Transfers von der Kammermitte.
const SOUL_SPREAD := 2.3
const MODULE_PAD := Vector3(2.7, 0.2, 3.4)

## Violett der Energie und Gold des Wurfs, knapp unter der Bloom-Schwelle (0,95).
const VIOLET := Color(CasinoStyle.ENERGY.r / CasinoStyle.ENERGY.b * 0.92,
	CasinoStyle.ENERGY.g / CasinoStyle.ENERGY.b * 0.92, 0.92)
const GOLD_LIT := Color(CasinoStyle.GOLD.r * 0.92, CasinoStyle.GOLD.g * 0.92, CasinoStyle.GOLD.b * 0.92)
## Ein Feld ohne Licht liest noch als Feld.
const FIELD_DIM := Color(VIOLET.r * 0.3, VIOLET.g * 0.3, VIOLET.b * 0.3)
const BRASS := Color(0.84, 0.62, 0.24)
const GROUND := Color(0.035, 0.03, 0.048)
const FLOOR_READY := Color(0.5, 0.45, 0.74)
const FLOOR_LIT := Color(0.68, 0.61, 0.9)
const DOT := Color(0.92, 0.9, 0.95)
const SOUL := Color(0.25, 0.85, 0.95)
const GREEN := Color(0.31, 0.92, 0.48)
const AMBER := Color(0.95, 0.66, 0.24)
const LABEL := Color(0.93, 0.92, 0.98)
const LABEL_DIM := Color(0.42, 0.4, 0.5)
const GLASS := Color(0.012, 0.012, 0.02)
const LACQUER := Color(0.05, 0.05, 0.06)
const EPOXY := Color(0.08, 0.085, 0.095)
const BRIGHT_STEEL := Color(0.78, 0.8, 0.85)
const TRACK := Color(0.04, 0.09, 0.06)
const SILK := Color(0.6, 0.64, 0.62)
const HOOD_TINT := Color(0.62, 0.68, 0.88)

var _built := false
var _writes := 0
var _key := ""
var _state := {}
var _dish := Rect2()
var _chamber_center := Vector2.ZERO
var _parts := {}
var _mat := {}
var _field_mats: Array[StandardMaterial3D] = []
var _field_states: Array[String] = []
var _field_tween: Tween
var _floor_mat: StandardMaterial3D
var _collar_mat: ShaderMaterial
var _collar_hover_mat: ShaderMaterial
var _collar: MeshInstance3D
var _hood: Node3D
var _hood_mat: StandardMaterial3D
var _hood_rim_mat: ShaderMaterial
var _hood_share := 0.0
var _hood_want := false
var _hood_tween: Tween
var _fly_tweens: Array[Tween] = []
## Bis wann ein Einsatz noch fliegt (ms); solange legt der Schreiber die Kammer nicht neu.
var _flying_until := 0
var _appear_tween: Tween
var _marks: Node3D
var _marks_station := ""
var _items_host: Node3D
var _items: Array[Node3D] = []
var _item_kinds: Array[String] = []
var _items_key := ""
var _name_label: Label3D
var _key_cap: Node3D
var _key_rim_mat: StandardMaterial3D
var _start_label: Label3D
var _price_label: Label3D
var _price_glass: MeshInstance3D
var _bolt: MeshInstance3D
var _status_label: Label3D
var _trace_mats := {}
var _hovered := ""

## parts: je Teil ein Rechteck in der Ebene (x = Bild-rechts, y = Bild-unten, Welt-Einheiten,
## um die Stationsmitte) - die Schlüssel von LaborView.PARTS.
func setup(parts: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_field_mats.clear()
	_field_states.clear()
	_items.clear()
	_item_kinds.clear()
	_items_key = ""
	_marks_station = ""
	_key = ""
	_parts = {}
	for key: String in parts:
		var r: Rect2 = parts[key]
		# Intern: Mitte und Größe, y Bild-OBEN.
		_parts[key] = Rect2(Vector2(r.get_center().x, -r.get_center().y), r.size)
	_dish = _parts["dish"]
	_chamber_center = (_parts["chamber"] as Rect2).position
	_build_materials()
	_build_dish()
	_build_chamber()
	_build_hood()
	_build_name(_parts["name"])
	_build_key(_parts["start"])
	_build_status(_parts["status"])
	_build_traces()
	_build_print()
	_built = true
	_place_hood()
	if not _state.is_empty():
		var state := _state
		_state = {}
		seat(state, true)

## Ebene (rechts, oben) -> lokal (x = Bild-oben, z = Bild-rechts).
static func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.y, y, p.x)

# --- Der EINE Schreiber -----------------------------------------------------------------

## state: LaborView.body_state(). hard = ungesehen: ohne Fahrt und ohne Aufleuchten.
func seat(state: Dictionary, hard := false) -> void:
	if not _built:
		_state = state.duplicate()
		return
	var key := str(state)
	if key == _key:
		if hard:
			settle_hard()
		return
	_key = key
	_writes += 1
	_state = state.duplicate()
	_write_marks(String(state.get("station", "seele")))
	_write_fields(state.get("fields", []), hard)
	_write_labels(state)
	_floor_mat.albedo_color = FLOOR_READY if String(state.get("phase", "")) == LaborView.PHASE_READY else FLOOR_LIT
	_hood_want = bool(state.get("hood", false))
	if hard:
		settle_hard()
	else:
		_ride_hood()
	if not flying():
		_lay_items()

## Der harte Weg: Haube am Ziel, Felder ohne Aufleuchten.
func settle_hard() -> void:
	if _hood_tween != null and _hood_tween.is_valid():
		_hood_tween.kill()
	_hood_tween = null
	_hood_share = 1.0 if _hood_want else 0.0
	_place_hood()
	if _field_tween != null and _field_tween.is_valid():
		_field_tween.kill()
	_field_tween = null
	for i in _field_mats.size():
		_field_mats[i].albedo_color = _field_color(_field_states[i])
	_kill_flights()
	_lay_items()
	if _appear_tween != null and _appear_tween.is_valid():
		_appear_tween.kill()
		_set_appear(1.0)
	_appear_tween = null

## Das erste Erscheinen: das Labor wächst aus dem Tisch, der Kammerboden leuchtet auf.
func appear() -> void:
	if _appear_tween != null and _appear_tween.is_valid():
		_appear_tween.kill()
	_set_appear(0.0)
	_appear_tween = create_tween()
	_appear_tween.tween_method(_set_appear, 0.0, 1.0, APPEAR_TIME) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_appear(share: float) -> void:
	scale = Vector3(1.0, maxf(share, 0.02), 1.0)
	if _floor_mat != null:
		var rest := FLOOR_READY if String(_state.get("phase", "")) == LaborView.PHASE_READY else FLOOR_LIT
		_floor_mat.albedo_color = rest.lerp(Color(1.0, 1.0, 1.0), (1.0 - share) * 0.6)

func appearing() -> bool:
	return _appear_tween != null and _appear_tween.is_valid()

func riding() -> bool:
	return (_hood_tween != null and _hood_tween.is_valid()) \
		or (_field_tween != null and _field_tween.is_valid())

func writes() -> int:
	return _writes

# --- Haube ------------------------------------------------------------------------------

func _ride_hood() -> void:
	var goal := 1.0 if _hood_want else 0.0
	if is_equal_approx(_hood_share, goal):
		return
	if _hood_tween != null and _hood_tween.is_valid():
		_hood_tween.kill()
	_hood_tween = create_tween()
	_hood_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if _hood_want else Tween.EASE_IN)
	_hood_tween.tween_method(func(value: float) -> void:
		_hood_share = value
		_place_hood(), _hood_share, goal, HOOD_TIME * absf(goal - _hood_share))
	_hood_tween.finished.connect(func() -> void: _hood_tween = null)

## Die Lage der Haube aus ihrem Anteil: 1 = gesenkt auf dem Kragen, 0 = gehoben und fort.
func _place_hood() -> void:
	if _hood == null:
		return
	_hood.position.y = HOOD_LIFT * (1.0 - _hood_share)
	_hood.visible = _hood_share > 0.001
	_hood_mat.albedo_color.a = HOOD_ALPHA * _hood_share

func hood_share() -> float:
	return _hood_share

func hood_shown() -> bool:
	return _hood != null and _hood.visible

# --- Felder -----------------------------------------------------------------------------

func _field_color(state: String) -> Color:
	match state:
		LaborView.FIELD_ROLL:
			return GOLD_LIT
		LaborView.FIELD_ROUND:
			return VIOLET
	return FIELD_DIM

## Endzustand zuerst; neu entflammte Felder leuchten danach nacheinander auf.
func _write_fields(fields: Array, hard: bool) -> void:
	if _field_tween != null and _field_tween.is_valid():
		_field_tween.kill()
	_field_tween = null
	var fresh: Array[int] = []
	for i in _field_mats.size():
		var want := String(fields[i]) if i < fields.size() else LaborView.FIELD_OFF
		if want != LaborView.FIELD_OFF and want != _field_states[i]:
			fresh.append(i)
		_field_states[i] = want
		_field_mats[i].albedo_color = _field_color(want)
	if hard or fresh.is_empty():
		return
	_field_tween = create_tween().set_parallel(true)
	for k in fresh.size():
		var i := fresh[k]
		_field_mats[i].albedo_color = FIELD_DIM
		_field_tween.tween_property(_field_mats[i], "albedo_color", _field_color(_field_states[i]),
			FIELD_FADE).set_delay(float(k) * FIELD_STAGGER)

func field_state(i: int) -> String:
	return _field_states[i]

func field_color(i: int) -> Color:
	return _field_mats[i].albedo_color

# --- Schrift ----------------------------------------------------------------------------

func _write_labels(state: Dictionary) -> void:
	_name_label.text = String(state.get("name", ""))
	_name_label.font_size = _fit(_name_label, float(_name_label.get_meta(&"room")))
	var phase := String(state.get("phase", LaborView.PHASE_READY))
	var lit := bool(state.get("start_lit", false))
	var ready := phase == LaborView.PHASE_READY
	var affordable := bool(state.get("affordable", true))
	_start_label.text = String(state.get("start_text", "START"))
	var start_at: Vector3 = _start_label.get_meta(&"left") if ready else _start_label.get_meta(&"mid")
	_start_label.position = start_at
	_start_label.modulate = LABEL if ready and affordable else (GREEN if phase == LaborView.PHASE_DONE
		else LABEL_DIM)
	_price_label.visible = ready
	_price_glass.visible = ready
	var price_text := String(state.get("price_text", ""))
	_price_label.text = price_text
	_price_label.font_size = _fit(_price_label, float(_price_label.get_meta(&"room")))
	var energy := VIOLET if affordable else VIOLET.darkened(0.6)
	_price_label.modulate = energy
	_bolt.visible = ready and price_text != "FREI" and price_text != ""
	(_bolt.material_override as StandardMaterial3D).albedo_color = energy
	_key_rim_mat.albedo_color = VIOLET if lit else (GREEN if phase == LaborView.PHASE_DONE
		else FIELD_DIM)
	_status_label.text = String(state.get("status", ""))
	_status_label.font_size = _fit(_status_label, float(_status_label.get_meta(&"room")))
	match String(state.get("status_kind", "")):
		LaborView.STATUS_DONE:
			_status_label.modulate = GREEN
		LaborView.STATUS_BLOCKED:
			_status_label.modulate = AMBER
		LaborView.STATUS_STAGING:
			_status_label.modulate = GOLD_LIT
		_:
			_status_label.modulate = VIOLET
	_trace_light("StichName", true)
	_trace_light("StichStart", lit)
	_trace_light("StichStatus", phase != LaborView.PHASE_READY)

func _trace_light(part: String, on: bool) -> void:
	var material: StandardMaterial3D = _trace_mats.get(part)
	if material != null:
		material.albedo_color = VIOLET if on else FIELD_DIM

## Eine Zeile so groß wie die Breite (Welt) erlaubt, höchstens die gebaute Größe.
static func _fit(label: Label3D, width: float) -> int:
	return CharmDiskView.fit_line(label.text, width / label.pixel_size, StationParts.FONT_SIZE, 16)

func name_shown() -> String:
	return _name_label.text

func start_shown() -> String:
	return _start_label.text

func price_shown() -> String:
	return _price_label.text if _price_label.visible else ""

func status_shown() -> String:
	return _status_label.text

func status_color() -> Color:
	return _status_label.modulate

func start_lit() -> bool:
	return _key_rim_mat.albedo_color == VIOLET

# --- Zeiger -----------------------------------------------------------------------------

## Das Teil unter dem Zeiger ("chamber", "start", ... oder ""): Kragen bzw. Taste heben sich ab.
func set_hovered(part: String) -> void:
	if part == _hovered:
		return
	_hovered = part
	if _collar != null:
		_collar.material_override = _collar_hover_mat if part == "chamber" else _collar_mat
	if _key_cap != null:
		_key_cap.position.y = KEY_LIFT if part == "start" else 0.0

func hovered() -> String:
	return _hovered

# --- Einsatz ----------------------------------------------------------------------------

## items: je Einsatz {kind, item} wie ein Schwarzmarkt-Fach (GameRun.KIND_*; eine Karte als Pack),
## gebaut in echter Größe über SecretShopBody.spawn_ware, der Charm als nackte Diskette.
func set_items(items: Array) -> void:
	var key := ""
	for entry in items:
		var data: Dictionary = entry
		var item: Variant = data.get("item")
		key += "%s:%d|" % [String(data.get("kind", "")), (item as Object).get_instance_id() if item is Object else 0]
	if key == _items_key:
		return
	_items_key = key
	_kill_flights()
	for body in _items:
		if is_instance_valid(body):
			body.get_parent().remove_child(body)
			body.queue_free()
	_items.clear()
	_item_kinds.clear()
	if _items_host == null:
		return
	for entry in items:
		var data: Dictionary = entry
		var kind := String(data.get("kind", ""))
		var body: Node3D
		if kind == GameRun.KIND_CHARM:
			var disk := CharmDiskView.new(data.get("item") as Charm)
			disk.name = "Diskette"
			_items_host.add_child(disk)
			body = disk
		else:
			body = SecretShopBody.spawn_ware(kind, data.get("item"), _items_host)
		if body == null:
			continue
		_items.append(body)
		_item_kinds.append(kind)
	_lay_items()

func items() -> Array[Node3D]:
	return _items

## Die Lage jedes Einsatzes in der Kammer (Endzustand, ohne Fahrt).
func _lay_items() -> void:
	if _items_host == null:
		return
	var station := String(_state.get("station", "seele"))
	var cards := 0
	for body in _items:
		if body is DataCellView:
			cards += 1
	var rises := _stair_rises()
	var card := 0
	for i in _items.size():
		var body := _items[i]
		var at := _slot_offset(i, station, _items.size())
		var y := VitrineView.FLOOR_CLEAR
		if body is DataCellView:
			at = _stair_offset(card, cards)
			y += float(rises[card])
			card += 1
		elif _item_kinds[i] == GameRun.KIND_DIE:
			y += DieBuilder.HALF_EXTENT * DiceTrayView.DIE_SCALE
		elif _item_kinds[i] == GameRun.KIND_PART and station == "modul":
			y += MODULE_PAD.y
		body.position = _v(at, y)
		if body is DataCellView:
			var cell := body as DataCellView
			cell.set_body_scale(PackDrawerView.CASSETTE_SCALE)
			if cell.is_inside_tree():
				cell.lie_on_glass(cell.global_position)

## Platz i in der Kammer (Ebene um die Kammermitte, rechts/oben).
static func _slot_offset(i: int, station: String, count: int) -> Vector2:
	if station == "seele" or count == 2:
		return Vector2(SOUL_SPREAD * (-1.0 if i == 0 else 1.0), 0.0) if count > 1 else Vector2.ZERO
	if count <= 1:
		return Vector2.ZERO
	return Vector2((float(i) - float(count - 1) * 0.5) * SOUL_SPREAD, 0.0)

static func _stair_offset(i: int, count: int) -> Vector2:
	return STAIR_STEP * (float(i) - float(maxi(count, 1) - 1) * 0.5)

## Die Höhe jeder Karte der Treppe: jede liegt auf der Oberseite der vorigen; reicht der
## Raum unter der Haube nicht, rücken alle gleichmäßig zusammen.
func _stair_rises() -> Array:
	var tops: Array = []
	for body in _items:
		if body is DataCellView:
			var carrier := (body as DataCellView).carrier()
			tops.append((float(DataCellView.CARRIER_TOPS[carrier]) + 0.02) * PackDrawerView.CASSETTE_SCALE)
	var rises: Array = []
	var total := 0.0
	for k in tops.size():
		rises.append(total)
		total += float(tops[k])
	var room := HOOD_HEIGHT - 0.3
	if total > room and tops.size() > 1:
		var last := float(tops[tops.size() - 1])
		var scale := maxf(room - last, 0.0) / maxf(total - last, 0.001)
		for k in rises.size():
			rises[k] = float(rises[k]) * scale
	return rises

## Wo Einsatz i liegt (Welt, auf dem Kammerboden).
func seat_point(i: int) -> Vector3:
	var station := String(_state.get("station", "seele"))
	var count := maxi(_items.size(), 2 if station == "seele" else 1)
	var at := _slot_offset(i, station, count)
	if station == "karten":
		at = _stair_offset(i, maxi(_items.size(), i + 1))
	return to_global(_v(_chamber_center + at, FLOOR_TOP))

## Einsatz i fliegt im Trage-Bogen von from (Welt) auf seinen Platz in der Kammer. Der
## Platz steht schon (Endzustand zuerst); settle_hard legt ihn hart dorthin.
func fly_in(i: int, from: Vector3, time := FLY_TIME, peak := FLY_PEAK) -> void:
	if i < 0 or i >= _items.size() or not _items[i].is_inside_tree():
		return
	var body := _items[i]
	var end := body.global_position
	_flying_until = maxi(_flying_until, Time.get_ticks_msec() + int(time * 1000.0) + 50)
	if body is DataCellView:
		(body as DataCellView).lie_on_glass(from)
		(body as DataCellView).arc_to(end, time, peak)
		return
	body.global_position = from
	var hump := maxf(from.y, end.y) + peak - (from.y + end.y) * 0.5
	var tween := create_tween()
	tween.tween_method(func(share: float) -> void:
		if is_instance_valid(body):
			var at := from.lerp(end, share)
			at.y += 4.0 * hump * share * (1.0 - share)
			body.global_position = at, 0.0, 1.0, time) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fly_tweens.append(tween)

## Fliegt noch ein Einsatz in die Kammer?
func flying() -> bool:
	return Time.get_ticks_msec() < _flying_until

func _kill_flights() -> void:
	_flying_until = 0
	for tween in _fly_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_fly_tweens.clear()

## Wo der Glückswürfel würfelt: mittig auf der gesenkten Haube.
func lid_point() -> Vector3:
	return to_global(_v(_chamber_center, COLLAR_TOP + HOOD_HEIGHT + RIM_HEIGHT))

func start_point() -> Vector3:
	var key: Rect2 = _parts.get("start", Rect2())
	return to_global(_v(key.position, 0.5))

# --- Bau --------------------------------------------------------------------------------

func _build_materials() -> void:
	_mat = {
		"brass": StationParts.steel(BRASS, 0.3, 0.06),
		"brass_hover": StationParts.steel(BRASS, 0.3, 0.3),
		"steel": StationParts.steel(ChipFrameView.STEEL, 0.4, 0.1),
		"bright": StationParts.steel(BRIGHT_STEEL, 0.6, 0.05),
		"lacquer": StationParts.steel(LACQUER, 0.1, 0.0),
		"epoxy": StationParts.steel(EPOXY, 0.2, 0.0),
		"ground": StationParts.lit(GROUND),
		"glass": StationParts.lit(GLASS),
		"track": StationParts.lit(TRACK),
		"silk": StationParts.lit(SILK),
		"dot": StationParts.lit(DOT),
		"soul": StationParts.lit(SOUL),
	}

func _build_dish() -> void:
	var c := _dish.position
	var straight := (_dish.size.x - _dish.size.y) * 0.5
	var outline := _stadium(c, straight, _dish.size.y * 0.5)
	_mesh(self, "Schale", _prism(outline, 0.0, DISH_TOP), _mat["brass"])
	var ground := _stadium(c, straight, _dish.size.y * 0.5 - LaborView.DISH_RIM)
	_mesh(self, "Feldgrund", _prism(ground, DISH_TOP, GROUND_TOP), _mat["ground"])
	var offset := c - LaborView.DISH_CENTER
	for i in LaborView.FIELDS:
		var material := StationParts.lit(FIELD_DIM)
		_field_mats.append(material)
		_field_states.append(LaborView.FIELD_OFF)
		var outline_i := LaborView.field_outline(i)
		for k in outline_i.size():
			outline_i[k] += offset
		_mesh(self, "Runde%d" % i, _cap(outline_i, FIELD_TOP), material)

func _build_chamber() -> void:
	var c := _chamber_center
	var radius := (_parts["chamber"] as Rect2).size.x * 0.5
	_floor_mat = StationParts.lit(FLOOR_READY)
	_mesh(self, "Leuchtboden", _cap(_circle(c, radius, 72), FLOOR_TOP), _floor_mat)
	var dots: Array[Transform3D] = []
	var reach := int(radius / DOT_PITCH)
	for a in range(-reach, reach + 1):
		for b in range(-reach, reach + 1):
			var p := Vector2(a, b) * DOT_PITCH
			if p.length() < radius - 0.3:
				dots.append(StationParts.cube(Vector3(0.08, 0.004, 0.08), _v(c + p, FLOOR_TOP + 0.002)))
	StationParts.swarm(self, "Raster", dots, _mat["dot"])
	_collar_mat = _mat["brass"]
	_collar_hover_mat = _mat["brass_hover"]
	_collar = _mesh(self, "Kragen", _ring(c, radius, radius + COLLAR_WIDTH, DISH_TOP, COLLAR_TOP, 72), _collar_mat)
	_marks = Node3D.new()
	_marks.name = "Markierung"
	add_child(_marks)
	_items_host = Node3D.new()
	_items_host.name = "Einsatz"
	_items_host.position = _v(c, FLOOR_TOP)
	add_child(_items_host)

## Die Markierung der Station auf dem Kammerboden: Seelen-Sitze mit Pfeil, Modul-Sockel.
func _write_marks(station: String) -> void:
	if station == _marks_station or _marks == null:
		return
	_marks_station = station
	for child in _marks.get_children():
		_marks.remove_child(child)
		child.queue_free()
	var c := _chamber_center
	var y := FLOOR_TOP + 0.004
	match station:
		"seele":
			var rings: Array[Transform3D] = []
			for side in [-1.0, 1.0]:
				var at := c + Vector2(side * SOUL_SPREAD, 0.0)
				rings.append_array(StationParts.frame_boxes(Vector2(at.y, at.x), Vector2(2.6, 2.6),
					Vector2(2.3, 2.3), y, 0.008))
			# Pfeil von der Quelle (links) zum Ziel (rechts): Schaft und zwei Spitzen-Stege.
			var arrows: Array[Transform3D] = [StationParts.cube(Vector3(0.14, 0.008, 1.6), _v(c, y))]
			for side in [-1.0, 1.0]:
				var tip := Basis(Vector3.UP, deg_to_rad(-40.0) * side) * Basis.from_scale(Vector3(0.14, 0.008, 0.6))
				arrows.append(Transform3D(tip, _v(c + Vector2(0.58, side * 0.19), y)))
			StationParts.swarm(_marks, "SeelenSitze", rings, _mat["soul"])
			StationParts.swarm(_marks, "SeelenPfeil", arrows, _mat["soul"])
		"modul":
			StationParts.box(_marks, "ModulSockel", MODULE_PAD, _v(c, FLOOR_TOP + MODULE_PAD.y * 0.5), _mat["epoxy"])
			var legs: Array[Transform3D] = []
			for side in [-1.0, 1.0]:
				for j in 6:
					legs.append(StationParts.cube(Vector3(0.3, 0.08, 0.2),
						_v(c + Vector2(-1.4 + float(j) * 0.56, side * (MODULE_PAD.x * 0.5 + 0.1)), FLOOR_TOP + 0.04)))
			StationParts.swarm(_marks, "SockelBeine", legs, _mat["steel"])

func _build_hood() -> void:
	var c := _chamber_center
	var radius := (_parts["chamber"] as Rect2).size.x * 0.5 + COLLAR_WIDTH * 0.5
	_hood = Node3D.new()
	_hood.name = "Haube"
	add_child(_hood)
	var glass := CylinderMesh.new()
	glass.top_radius = radius - HOOD_TAPER
	glass.bottom_radius = radius
	glass.height = HOOD_HEIGHT
	glass.radial_segments = 72
	glass.rings = 1
	glass.cap_bottom = false
	_hood_mat = StandardMaterial3D.new()
	_hood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hood_mat.albedo_color = Color(HOOD_TINT, HOOD_ALPHA)
	_hood_mat.cull_mode = BaseMaterial3D.CULL_BACK
	var bell := MeshInstance3D.new()
	bell.name = "Glas"
	bell.mesh = glass
	bell.material_override = _hood_mat
	bell.position = _v(c, COLLAR_TOP + HOOD_HEIGHT * 0.5)
	bell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hood.add_child(bell)
	# Gewöhnlicher Stahl: der helle Stahl stand auf dem Glasrand über der Bloom-Schwelle.
	_hood_rim_mat = _mat["steel"]
	var top := radius - HOOD_TAPER
	_mesh(_hood, "Rand", _ring(c, top - 0.05, top + 0.02, COLLAR_TOP + HOOD_HEIGHT,
		COLLAR_TOP + HOOD_HEIGHT + RIM_HEIGHT, 72), _hood_rim_mat)
	_mesh(_hood, "Fuss", _ring(c, radius - 0.04, radius + 0.04, COLLAR_TOP, COLLAR_TOP + 0.03, 72), _hood_rim_mat)

func _build_name(rect: Rect2) -> void:
	var c := rect.position
	StationParts.box(self, "NameRahmen", Vector3(rect.size.y, 0.16, rect.size.x), _v(c, 0.08), _mat["steel"])
	StationParts.box(self, "NameGlas", Vector3(rect.size.y - 0.3, 0.02, rect.size.x - 0.3), _v(c, 0.17), _mat["glass"])
	_name_label = StationParts.label(self, "Name", "", _v(c, 0.185), 0.6, LABEL)
	_name_label.set_meta(&"room", rect.size.x - 0.7)

func _build_key(rect: Rect2) -> void:
	var c := rect.position
	StationParts.box(self, "StartSockel", Vector3(rect.size.y, 0.3, rect.size.x), _v(c, 0.15), _mat["steel"])
	_key_cap = Node3D.new()
	_key_cap.name = "StartKappe"
	add_child(_key_cap)
	var cap := Vector2(rect.size.x - 0.5, rect.size.y - 0.5)
	StationParts.box(_key_cap, "Kappe", Vector3(cap.y, 0.2, cap.x), _v(c, 0.4), _mat["lacquer"])
	_key_rim_mat = StationParts.lit(FIELD_DIM)
	StationParts.swarm(_key_cap, "KappenRahmen", StationParts.frame_boxes(Vector2(c.y, c.x),
		Vector2(cap.y, cap.x), Vector2(cap.y - 0.12, cap.x - 0.12), 0.505, 0.01), _key_rim_mat)
	var top := 0.51
	_start_label = StationParts.label(_key_cap, "StartText", "START", _v(c + Vector2(-1.3, 0.0), top), 0.62, LABEL)
	_start_label.set_meta(&"left", _v(c + Vector2(-1.3, 0.0), top))
	_start_label.set_meta(&"mid", _v(c, top))
	var price_at := c + Vector2(1.15, 0.0)
	_price_glass = StationParts.box(_key_cap, "PreisGlas", Vector3(0.95, 0.02, 1.7), _v(price_at, top), _mat["glass"])
	_price_label = StationParts.label(_key_cap, "Preis", "", _v(price_at, top + 0.012), 0.66, VIOLET)
	_price_label.set_meta(&"room", 1.55)
	_bolt = _bolt_mesh(_key_cap, "Blitz", c + Vector2(2.35, 0.0), top + 0.01, 0.95)

func _build_status(rect: Rect2) -> void:
	var c := rect.position
	StationParts.box(self, "StatusChip", Vector3(rect.size.y, 0.3, rect.size.x), _v(c, 0.15), _mat["bright"])
	StationParts.box(self, "StatusGlas", Vector3(rect.size.y - 0.4, 0.02, rect.size.x - 0.4), _v(c, 0.31), _mat["glass"])
	_status_label = StationParts.label(self, "Status", "", _v(c, 0.325), 0.75, VIOLET)
	_status_label.set_meta(&"room", rect.size.x - 0.7)

## Je Chip zwei Bahnen mit Lichtkern bis an die Kante der Schale.
func _build_traces() -> void:
	for pair in [["StichName", "name"], ["StichStart", "start"], ["StichStatus", "status"]]:
		var rect: Rect2 = _parts[String(pair[1])]
		var y := rect.position.y
		var from := rect.position.x - rect.size.x * 0.5
		var to := _dish_edge_at(y) - 0.1
		if from <= to:
			continue
		var core := StationParts.lit(FIELD_DIM)
		_trace_mats[String(pair[0])] = core
		var tracks: Array[Transform3D] = []
		var lights: Array[Transform3D] = []
		for d in [-0.21, 0.21]:
			var mid := Vector2((from + to) * 0.5, y + d)
			tracks.append(StationParts.cube(Vector3(0.2, 0.004, from - to), _v(mid, 0.002)))
			lights.append(StationParts.cube(Vector3(0.08, 0.004, from - to), _v(mid, 0.006)))
		StationParts.swarm(self, String(pair[0]), tracks, _mat["track"])
		StationParts.swarm(self, String(pair[0]) + "Licht", lights, core)

## Die rechte Kante der Schale auf Höhe y (Ebene).
func _dish_edge_at(y: float) -> float:
	var straight := (_dish.size.x - _dish.size.y) * 0.5
	var radius := _dish.size.y * 0.5
	var dy := absf(y - _dish.position.y)
	if dy >= radius:
		return _dish.position.x
	return _dish.position.x + straight + sqrt(radius * radius - dy * dy)

## Druck „LABOR“ über dem Namens-Schild und Bestückungs-Winkel an den Ecken des Grundrisses.
func _build_print() -> void:
	var name_rect: Rect2 = _parts["name"]
	var mark_at := name_rect.position + Vector2(0.0, name_rect.size.y * 0.5 + 0.55)
	StationParts.label(self, "Druck", "LABOR", _v(mark_at, 0.004), 0.5, SILK)
	var half := LaborView.UNITS * 0.5
	var k := 0.9
	var corners: Array[Transform3D] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := Vector2(sx * (half.x - 0.035), sy * (half.y - 0.035))
			corners.append(StationParts.cube(Vector3(0.07, 0.004, k), _v(corner - Vector2(sx * k * 0.5, 0.0), 0.003)))
			corners.append(StationParts.cube(Vector3(k, 0.004, 0.07), _v(corner - Vector2(0.0, sy * k * 0.5), 0.003)))
	StationParts.swarm(self, "Ecken", corners, _mat["silk"])

## Ein Blitz aus drei schrägen Stegen - das Zeichen der Energie.
func _bolt_mesh(host: Node3D, part: String, at: Vector2, y: float, size: float) -> MeshInstance3D:
	var pts := PackedVector2Array([Vector2(0.15, -0.5), Vector2(-0.25, 0.05), Vector2(0.0, 0.05),
		Vector2(-0.15, 0.5), Vector2(0.25, -0.05), Vector2(0.0, -0.05)])
	var verts := PackedVector3Array()
	for tri in [[0, 1, 5], [1, 2, 5], [5, 2, 4], [2, 3, 4]]:
		for k: int in tri:
			verts.append(Vector3(-pts[k].y * size, 0.0, pts[k].x * size))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.position = _v(at, y)
	var material := StationParts.lit(VIOLET)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
	return node

# --- Netze ------------------------------------------------------------------------------

static func _circle(c: Vector2, radius: float, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in steps:
		out.append(c + Vector2.from_angle(TAU * float(k) / float(steps)) * radius)
	return out

## Ein Stadion (Rechteck mit Halbkreis-Enden) um c, gegen den Uhrzeigersinn.
static func _stadium(c: Vector2, straight: float, radius: float, steps := 32) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in steps + 1:
		out.append(c + Vector2(straight, 0.0) + Vector2.from_angle(-PI * 0.5 + PI * float(k) / float(steps)) * radius)
	for k in steps + 1:
		out.append(c - Vector2(straight, 0.0) + Vector2.from_angle(PI * 0.5 + PI * float(k) / float(steps)) * radius)
	return out

## Ein Dreieck, so gewendet, daß seine Vorderseite nach normal zeigt (Godot: im Uhrzeigersinn).
static func _tri(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3,
		c: Vector3, normal: Vector3) -> void:
	if (c - a).cross(b - a).dot(normal) < 0.0:
		var t := b
		b = c
		c = t
	verts.append_array(PackedVector3Array([a, b, c]))
	normals.append_array(PackedVector3Array([normal, normal, normal]))

static func _cap_into(verts: PackedVector3Array, normals: PackedVector3Array,
		outline: PackedVector2Array, y: float) -> void:
	var tris := Geometry2D.triangulate_polygon(outline)
	for k in range(0, tris.size(), 3):
		_tri(verts, normals, _v(outline[tris[k]], y), _v(outline[tris[k + 1]], y),
			_v(outline[tris[k + 2]], y), Vector3.UP)

static func _cap(outline: PackedVector2Array, y: float) -> Array:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	_cap_into(verts, normals, outline, y)
	return [verts, normals]

## Ein senkrechter Körper aus einem Umriß: Deckel und Wände.
static func _prism(outline: PackedVector2Array, y0: float, y1: float) -> Array:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	_cap_into(verts, normals, outline, y1)
	_walls_into(verts, normals, outline, y0, y1, 1.0)
	return [verts, normals]

## Wände längs eines Umrisses; outward = +1 zeigt nach außen, -1 nach innen.
static func _walls_into(verts: PackedVector3Array, normals: PackedVector3Array,
		outline: PackedVector2Array, y0: float, y1: float, outward: float) -> void:
	var ccw := 1.0 if _area(outline) > 0.0 else -1.0
	for k in outline.size():
		var p := outline[k]
		var q := outline[(k + 1) % outline.size()]
		var edge := q - p
		if edge.length() < 0.00001:
			continue
		var side := Vector2(edge.y, -edge.x).normalized() * ccw * outward
		var n := _v(side, 0.0)
		_tri(verts, normals, _v(p, y0), _v(q, y0), _v(q, y1), n)
		_tri(verts, normals, _v(p, y0), _v(q, y1), _v(p, y1), n)

static func _area(outline: PackedVector2Array) -> float:
	var sum := 0.0
	for k in outline.size():
		var p := outline[k]
		var q := outline[(k + 1) % outline.size()]
		sum += p.x * q.y - q.x * p.y
	return sum * 0.5

## Ein Ring: Deckel zwischen zwei Kreisen, Außen- und Innenwand.
static func _ring(c: Vector2, r0: float, r1: float, y0: float, y1: float, steps: int) -> Array:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var inner := _circle(c, r0, steps)
	var outer := _circle(c, r1, steps)
	for k in steps:
		var m := (k + 1) % steps
		_tri(verts, normals, _v(inner[k], y1), _v(outer[k], y1), _v(outer[m], y1), Vector3.UP)
		_tri(verts, normals, _v(inner[k], y1), _v(outer[m], y1), _v(inner[m], y1), Vector3.UP)
	_walls_into(verts, normals, outer, y0, y1, 1.0)
	_walls_into(verts, normals, inner, y0, y1, -1.0)
	return [verts, normals]

static func _mesh(host: Node3D, part: String, data: Array, material: Material) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data[0]
	arrays[Mesh.ARRAY_NORMAL] = data[1]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
	return node
