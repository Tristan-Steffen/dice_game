class_name ShelfSelectorView
extends Node3D
## Die KNOPFLEISTE des REGALSTAPELS (2026-09-10; sie ersetzt den Paternoster-Hebel,
## der mit dem Kreislauf gestorben ist): eine senkrechte Reihe flacher Tasten auf dem
## Filz RECHTS neben der Magazin-Grube - oben ▲, darunter 1 … 5, unten ▼.
## Taste n wählt Tablett n, ▲ das darüber (die kleinere Nummer), ▼ das darunter;
## an den Enden ist die Pfeiltaste blind, es gibt keinen Umlauf.
## Sie bucht und setzt NICHTS - sie MELDET (tray_requested); den Stapel fährt und
## das Fenster schreibt scene_root. Kein mark_reflective: sie liegt auf Filz.
## Die Grammatik ist die des Raster-Umschalters und der Sicherungs-Fassung: dunkler
## Sockel, Tastenfläche darauf, flache Aufschrift in Tisch-Leserichtung, blind heißt
## grau und ohne Kollision.

## Der Spieler will dieses Tablett sehen (0-basiert).
signal tray_requested(tray: int)

## Dieselbe Pick-Ebene wie die Sicherungs-Fassung - die TEILE heißen verschieden,
## und wer fragt, prüft den Namen (tray_of_part/direction_of).
const PICK_LAYER := 256

const PART_NONE := ""
const PART_UP := "up"
const PART_DOWN := "down"

const TRAYS := PackDrawerView.TRAYS
## Sieben Felder: die zwei Pfeile und je Tablett eine Zahl.
const FIELDS := TRAYS + 2

## Breite der Leiste (Welt-z = Bildschirm-Breite) und die Fuge zwischen zwei Feldern.
const KEY_WIDTH := 1.30
const KEY_GAP := 0.10
## Ein Feld wird nie flacher als das - sonst verschwände die Aufschrift.
const KEY_MIN := 0.45

const PLATE_HEIGHT := 0.10
const PLATE_LIFT := 0.02
const KEY_INSET := 0.14
const KEY_HEIGHT := 0.16

const PLATE_ALBEDO := Color(0.075, 0.072, 0.108)
const PLATE_EMISSION := Color(0.20, 0.22, 0.34)
const PLATE_ENERGY := 0.55
const KEY_ALBEDO := Color(0.17, 0.165, 0.215)

## Die GEWÄHLTE Taste leuchtet Gold, die übrigen stehen dunkel, blinde grau.
const LIVE_TINT := CasinoStyle.GOLD_INTENSE
const REST_TINT := Color(0.42, 0.46, 0.62)
const DEAD_TINT := CasinoStyle.MUTED
const SELECTED_ENERGY := 0.95
const REST_ENERGY := 0.30
const DEAD_ENERGY := 0.12
const HOVER_GAIN := 2.1

const FONT_SIZE := 64
const LABEL_LIFT := 0.02
const TEXT_UP := "▲"
const TEXT_DOWN := "▼"

## Der Griff: die Taste hebt sich eine Spur (die Geste des Raster-Umschalters).
const HOVER_LIFT := 0.10
const HOVER_TIME := 0.13

## Eine Lieferung auf ein verdecktes Tablett endet an SEINER Taste - sie blitzt auf.
const FLASH_ENERGY := 3.6
const FLASH_TIME := 0.45

var center := Vector3.ZERO
var height := 0.0

var _keys: Array[Node3D] = []
var _materials: Array[StandardMaterial3D] = []
var _labels: Array[Label3D] = []
var _bodies: Array[StaticBody3D] = []
var _parts: Array[String] = []
var _selected := 0
var _live := true
var _hovered := PART_NONE
var _built := false
## Je Feld ein eigener Griff-Tween: ein geteilter riss den Nachbarn mitten im Hub ab.
var _hover_tweens: Array[Tween] = []
var _flash: Tween

func _init(selector_name := "ShelfSelector") -> void:
	name = selector_name

## Welches Teil gehört zu diesem Kollisions-Körper ("" = keines)?
static func part_of(collider: Object) -> String:
	var body := collider as Node
	if body == null or not body.has_meta("part"):
		return PART_NONE
	return str(body.get_meta("part"))

## Die Aufschrift eines Feldes (rein, damit sie prüfbar ist).
static func part_key(tray: int) -> String:
	return "key%d" % tray

## Das Tablett hinter einem Teil (-1 = kein Zahlenfeld).
static func tray_of_part(part: String) -> int:
	if not part.begins_with("key"):
		return -1
	var rest := part.substr(3)
	if not rest.is_valid_int():
		return -1
	var tray := rest.to_int()
	return tray if tray >= 0 and tray < TRAYS else -1

## Die Richtung eines Pfeils: ▲ wählt die KLEINERE Nummer, ▼ die größere.
static func direction_of(part: String) -> int:
	if part == PART_UP:
		return -1
	if part == PART_DOWN:
		return 1
	return 0

## Kennt die Leiste dieses Teil überhaupt? (Auf ihrer Pick-Ebene liegt auch die
## Sicherungs-Fassung - darum entscheidet der NAME, nicht der Treffer.)
static func knows(part: String) -> bool:
	return tray_of_part(part) >= 0 or direction_of(part) != 0

## Stellt die Leiste (idempotent - derselbe Platz baut nichts neu). at = ihre Mitte
## auf dem Glas, room = die verfügbare Welt-Tiefe entlang X (die Grubentiefe).
func setup(at: Vector3, room: float) -> void:
	var wanted := maxf(room, KEY_MIN * float(FIELDS))
	if _built and center.is_equal_approx(at) and is_equal_approx(height, wanted):
		return
	center = at
	height = wanted
	_build()

## Die halbe Breite - scene_root setzt die Leiste damit hinter die Fuge.
static func half_width() -> float:
	return KEY_WIDTH * 0.5

## Das Weltrechteck der Leiste in XZ.
func bounds_min() -> Vector2:
	return Vector2(center.x - height * 0.5, center.z - KEY_WIDTH * 0.5)

func bounds_max() -> Vector2:
	return Vector2(center.x + height * 0.5, center.z + KEY_WIDTH * 0.5)

## Die Höhe EINES Feldes (Welt-X): sieben Felder und sechs Fugen teilen die Tiefe.
func field_span() -> float:
	return maxf((height - KEY_GAP * float(FIELDS - 1)) / float(FIELDS), KEY_MIN)

## Der Weltpunkt einer Taste - dorthin fliegt eine Lieferung auf ein verdecktes
## Tablett.
func key_point(tray: int) -> Vector3:
	var index := _index_of_tray(clampi(tray, 0, TRAYS - 1))
	if index < 0 or index >= _keys.size() or not is_instance_valid(_keys[index]):
		return global_position
	return _keys[index].global_position

# --- Der Zustand -----------------------------------------------------------------

func selected() -> int:
	return _selected

## Welches Tablett gerade gewählt ist - Gold auf seiner Taste, Rest dunkel.
func set_selected(tray: int) -> void:
	var wanted := clampi(tray, 0, TRAYS - 1)
	if _selected == wanted:
		return
	_selected = wanted
	_write_live()

## Darf jetzt gewählt werden? Blind bleibt die Leiste stehen und wird nur grau.
func set_live(on: bool) -> void:
	if _live == on:
		return
	_live = on
	if not on:
		_hovered = PART_NONE
	_write_live()

func live() -> bool:
	return _live

## Lebt DIESES Teil? Die Pfeile sind an den Enden blind - es gibt keinen Umlauf.
func live_for(part: String) -> bool:
	if not _live:
		return false
	if tray_of_part(part) >= 0:
		return true
	var dir := direction_of(part)
	if dir == 0:
		return false
	return _selected + dir >= 0 and _selected + dir < TRAYS

## Der Zeiger liegt auf einem Teil (PART_NONE = auf keinem). Blind antwortet es nicht.
func set_hovered(part: String) -> void:
	if not live_for(part):
		part = PART_NONE
	if _hovered == part:
		return
	_hovered = part
	_write_live()

func hovered() -> String:
	return _hovered

## Fängt dieses Teil den Strahl?
func pick_armed(part: String) -> bool:
	for i in _bodies.size():
		if _parts[i] == part and is_instance_valid(_bodies[i]):
			return _bodies[i].collision_layer == PICK_LAYER
	return false

## Die Aufschrift eines Teils ("" = keines).
func label_of(part: String) -> String:
	for i in _parts.size():
		if _parts[i] == part and is_instance_valid(_labels[i]):
			return _labels[i].text
	return ""

## Der Druck (true = sie hat gemeldet). Blind meldet sie nichts.
func press(part: String) -> bool:
	if not live_for(part):
		return false
	var tray := tray_of_part(part)
	if tray < 0:
		tray = clampi(_selected + direction_of(part), 0, TRAYS - 1)
	tray_requested.emit(tray)
	return true

## Die Taste blitzt auf - so quittiert sie eine Lieferung auf ein verdecktes
## Tablett (eine Maschine, die keiner sieht, hat nicht gespielt).
func flash_key(tray: int) -> void:
	var index := _index_of_tray(clampi(tray, 0, TRAYS - 1))
	if index < 0 or index >= _materials.size() or _materials[index] == null:
		return
	if _flash != null and _flash.is_valid():
		_flash.kill()
	var material := _materials[index]
	var rest := _energy_of(index)
	material.emission_energy_multiplier = FLASH_ENERGY
	if not is_inside_tree():
		material.emission_energy_multiplier = rest
		return
	_flash = create_tween()
	_flash.tween_method(func(value: float) -> void:
		material.emission_energy_multiplier = value, FLASH_ENERGY, rest, FLASH_TIME)

# --- Aufbau ------------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_keys.clear()
	_materials.clear()
	_labels.clear()
	_bodies.clear()
	_parts.clear()
	_hover_tweens.clear()
	_hovered = PART_NONE
	global_position = center
	var span := field_span()
	var pitch := span + KEY_GAP
	_box("Sockel", Vector3(height, PLATE_HEIGHT, KEY_WIDTH),
		Vector3(0.0, PLATE_LIFT + PLATE_HEIGHT * 0.5, 0.0),
		_metal(PLATE_ALBEDO, PLATE_EMISSION, PLATE_ENERGY), self)
	for i in FIELDS:
		# Feld 0 steht Bild-OBEN (Welt +X): oben ▲, dann 1 … 5, unten ▼.
		var at := Vector3(height * 0.5 - span * 0.5 - pitch * float(i), 0.0, 0.0)
		_build_field(i, _part_at(i), at, span)
	_built = true
	_write_live()

## Welches Teil auf welchem Feld: oben der Pfeil hinauf, unten der hinab.
static func _part_at(index: int) -> String:
	if index == 0:
		return PART_UP
	if index == FIELDS - 1:
		return PART_DOWN
	return part_key(index - 1)

static func _text_at(index: int) -> String:
	if index == 0:
		return TEXT_UP
	if index == FIELDS - 1:
		return TEXT_DOWN
	return str(index)

func _index_of_tray(tray: int) -> int:
	return tray + 1

func _build_field(index: int, part: String, at: Vector3, span: float) -> void:
	var host := Node3D.new()
	host.name = "Feld_%s" % part
	host.position = at
	add_child(host)
	var material := _metal(KEY_ALBEDO, REST_TINT, REST_ENERGY)
	var key := _box("Taste", Vector3(maxf(span - KEY_INSET * 2.0, 0.05), KEY_HEIGHT,
		maxf(KEY_WIDTH - KEY_INSET * 2.0, 0.05)),
		Vector3(0.0, PLATE_LIFT + PLATE_HEIGHT + KEY_HEIGHT * 0.5, 0.0), material, host)
	var label := Label3D.new()
	label.name = "Aufschrift"
	label.text = _text_at(index)
	label.font_size = FONT_SIZE
	# Flach in Tisch-Leserichtung: der Text läuft entlang Welt +Z (Bildschirm rechts).
	label.transform.basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	label.position = Vector3(0.0,
		PLATE_LIFT + PLATE_HEIGHT + KEY_HEIGHT + LABEL_LIFT, 0.0)
	label.pixel_size = maxf(span * 0.55, 0.05) / float(FONT_SIZE)
	label.outline_size = 14
	label.outline_modulate = Color(0.03, 0.03, 0.05)
	host.add_child(label)
	var body := StaticBody3D.new()
	body.name = "Griff_%s" % part
	body.collision_layer = PICK_LAYER
	body.collision_mask = 0
	body.position = Vector3(0.0, PLATE_LIFT + PLATE_HEIGHT + KEY_HEIGHT * 0.5, 0.0)
	body.set_meta("part", part)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span, KEY_HEIGHT + HOVER_LIFT * 2.0, KEY_WIDTH)
	shape.shape = box
	body.add_child(shape)
	host.add_child(body)
	_keys.append(host)
	_materials.append(material)
	_labels.append(label)
	_bodies.append(body)
	_parts.append(part)
	_hover_tweens.append(null)

## Der EINE Schreiber der Anzeige: Gold auf der Wahl, dunkel auf dem Rest, grau auf
## dem Blinden - und blind fängt den Strahl gar nicht erst.
func _write_live() -> void:
	if not _built:
		return
	for i in _parts.size():
		var part := _parts[i]
		var alive := live_for(part)
		var chosen := tray_of_part(part) == _selected
		var material := _materials[i]
		material.emission = DEAD_TINT if not alive else (LIVE_TINT if chosen else REST_TINT)
		material.emission_energy_multiplier = _energy_of(i)
		if is_instance_valid(_labels[i]):
			var tint: Color = material.emission
			_labels[i].modulate = Color(tint.r * 1.3 + 0.2, tint.g * 1.3 + 0.2,
				tint.b * 1.3 + 0.2)
		if is_instance_valid(_bodies[i]):
			_bodies[i].collision_layer = PICK_LAYER if alive else 0
		_lift(i, alive and _hovered == part)

## Die Ruhe-Energie eines Feldes (der Hover verstärkt sie).
func _energy_of(index: int) -> float:
	var part := _parts[index]
	if not live_for(part):
		return DEAD_ENERGY
	var base := SELECTED_ENERGY if tray_of_part(part) == _selected else REST_ENERGY
	return base * (HOVER_GAIN if _hovered == part else 1.0)

## Der Griff: die Taste rückt eine Spur aus der Fläche. Nur der Wechsel fährt.
func _lift(index: int, on: bool) -> void:
	var host := _keys[index]
	if host == null or not is_instance_valid(host):
		return
	var wanted := HOVER_LIFT if on else 0.0
	if is_equal_approx(host.position.y, wanted):
		return
	var running: Tween = _hover_tweens[index]
	if running != null and running.is_valid():
		running.kill()
	if not is_inside_tree():
		host.position.y = wanted
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(host, "position:y", wanted, HOVER_TIME)
	_hover_tweens[index] = tween

# --- Bausteine ---------------------------------------------------------------------

func _metal(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.5
	material.roughness = 0.44
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _box(box_name: String, box_size: Vector3, at: Vector3, material: Material,
		host: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(instance)
	return instance
