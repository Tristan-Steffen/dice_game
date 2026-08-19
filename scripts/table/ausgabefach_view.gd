class_name AusgabefachView
extends Node3D
## Das AUSGABEFACH: eine offene Schale rechts neben dem Werkstatt-Fenster, in der
## die bezahlten, noch nicht eingesetzten Würfel LIEGEN (GameRun.pending_dice).
## Sie steht an der Werkbank, nicht im Laden - der Hub kauft, die Werkstatt nutzt.
## Kein Loch und kein Panel: ein echtes flaches Tablett mit niedrigem Rand auf der
## Glasfläche. Sein Rechteck misst scene_root am Fensterrand und schiebt es herein
## (setup); die Schale rechnet ihre Plätze allein daraus.
## Der Körper hängt an der WÜRFEL-INSTANZ, nicht am Platz: fällt einer heraus,
## GLEITEN die übrigen weiter, statt fremde Meshes zu erben.
## Kein mark_reflective: ein Körper AUF dem Glas spiegelt sich als grauer Schmier
## daneben (dieselbe Regel wie die Datenzellen).

## Feldmaß EINES Platzes (Weltmaß, an der Würfelkante gemessen): so viel Luft,
## dass zwei Nachbarn sich nicht berühren.
const CELL := DiceTrayView.DIE_SCALE * 2.6
## Die Würfel liegen in TRAY-Größe - dasselbe Maß wie überall sonst am Tisch.
const DIE_SCALE := DiceTrayView.DIE_SCALE

## Der Rand der Schale: niedrig genug, dass der Blick bei 15° hineinfällt.
const RIM := 0.30
const RIM_HEIGHT := 0.34
const FLOOR_HEIGHT := 0.06
## Sie steht AUF dem Glas - die Bodenplatte hebt sich eine Spur ab, sonst kämpfte
## sie mit der Anzeige im Tiefenpuffer.
const FLOOR_LIFT := 0.02

const FLOOR_ALBEDO := Color(0.075, 0.072, 0.108)
const FLOOR_EMISSION := Color(0.20, 0.22, 0.34)
const FLOOR_ENERGY := 0.55
const RIM_ALBEDO := Color(0.19, 0.185, 0.235)
const RIM_EMISSION := Color(0.42, 0.46, 0.62)
const RIM_ENERGY := 0.85

## Greifen: der Würfel hebt sich und wird eine Spur größer - die Magazin-Geste.
## Hier liegt keine Scheibe darüber, also hebt er voll (anders als in der Vitrine).
const HOVER_LIFT := DIE_SCALE * 0.5
const HOVER_SWELL := 1.1
const HOVER_TIME := 0.14

## Ankunft aus dem Förderwerk: der Würfel steigt durch den Fachboden herein.
const ARRIVE_TIME := 0.35
## Eingelöst: er sinkt durch denselben Boden wieder weg.
const LEAVE_TIME := 0.28
## Rückt einer nach, GLEITET er auf seinen neuen Platz.
const SHIFT_TIME := 0.22

## Greifradius eines Würfels in der Glasebene (Vielfaches seiner halben Kante).
const PICK_FACTOR := 1.2

var floor_plate: MeshInstance3D

## Zuletzt gestellte Maße - der Abgleich stellt idempotent nach.
var center := Vector3.ZERO
var half := Vector2.ZERO

## Je liegendem Würfel ein Datensatz: {index, key, def, spot (Welt), node, radius}.
var items: Array[Dictionary] = []

## Die zuletzt gestellte Reihe (GameRun.pending_dice in ihrer Ordnung).
var _dice: Array[DieDefinition] = []
var _bodies: Dictionary = {}
var _move_tweens: Dictionary = {}
var _hover_tweens: Dictionary = {}
var _hovered := 0
## Würfel, die noch unterwegs sind: ihr Platz steht, ihr Körper wartet auf das
## Förderwerk (Instanz-Id -> true).
var _arriving: Dictionary = {}

## Der Schlüssel eines Körpers: die WÜRFEL-Instanz. Ein Platz ist nur eine Reihe.
static func body_key(def: Object) -> int:
	return def.get_instance_id() if def != null else 0

## Plätze EINER Reihe: count Punkte, mittig über span verteilt, feste Teilung,
## solange sie passt - sonst rückt die Reihe zusammen. Reine Funktion.
static func row_spots(count: int, span: float, pitch: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if count <= 0 or span <= 0.0:
		return out
	var step := minf(maxf(pitch, 0.01), span / float(count))
	var first := -step * float(count - 1) * 0.5
	for i in count:
		out.append(first + step * float(i))
	return out

## Wie viele Felder eine Strecke fasst (mindestens eines).
static func fits(span: float) -> int:
	return maxi(int(floorf(span / CELL)), 1)

## Das Raster einer Bestückung: Spalten quer, Zeilen tief. Die Schale bleibt
## gleich groß - reicht der Platz nicht, rücken die Reihen zusammen.
## inner.x = quer (Bildschirm-Breite), inner.y = tief (Bildschirm-Höhe).
static func grid_for(inner: Vector2, count: int) -> Vector2i:
	var columns := fits(inner.x)
	if count <= 0:
		return Vector2i(columns, 0)
	return Vector2i(columns, int(ceil(float(count) / float(columns))))

func _init(fach_name := "Ausgabefach") -> void:
	name = fach_name

## Stellt die Schale auf das gemessene Rechteck: Mitte auf dem Glas, halbe
## Ausdehnung in Welt-X/Welt-Z. Idempotent - dieselben Maße bauen nichts neu.
func setup(at: Vector3, half_extents: Vector2) -> void:
	var wanted := Vector2(maxf(half_extents.x, 0.01), maxf(half_extents.y, 0.01))
	var same := floor_plate != null and is_instance_valid(floor_plate) \
		and center.is_equal_approx(at) and half.is_equal_approx(wanted)
	center = at
	half = wanted
	if same:
		return
	_build_shell()
	_layout()

## Die INNENFLÄCHE der Schale: x = quer (Welt-Z, Bildschirm-Breite),
## y = tief (Welt-X, Bildschirm-Höhe).
func inner() -> Vector2:
	return Vector2(maxf(half.y * 2.0 - RIM * 2.0, 0.01),
		maxf(half.x * 2.0 - RIM * 2.0, 0.01))

## Das Weltrechteck der Schale in XZ - scene_root vergleicht Pixel damit.
func bounds_min() -> Vector2:
	return Vector2(center.x - half.x, center.z - half.y)

func bounds_max() -> Vector2:
	return Vector2(center.x + half.x, center.z + half.y)

## Wie viele Würfel ohne Zusammenrücken hineinpassen (gemessen, nicht getippt).
func capacity() -> int:
	var span := inner()
	return fits(span.x) * fits(span.y)

## Die Reihe stellen: je Würfel-Instanz ein Körper, in der Ordnung, in der sie
## hinterlegt wurden. EIN idempotenter Schreiber - was schon liegt, bleibt
## derselbe Körper und GLEITET nur auf seinen neuen Platz.
func present(dice: Array) -> void:
	# Erst sammeln, dann übernehmen: der Aufrufer darf uns unsere EIGENE Reihe
	# zurückreichen (der idempotente Abgleich tut genau das).
	var next: Array[DieDefinition] = []
	var keys: Dictionary = {}
	for def: DieDefinition in dice:
		if def != null:
			next.append(def)
			keys[body_key(def)] = true
	_dice = next
	# Was nicht mehr hinterlegt ist, ist auch nicht mehr unterwegs.
	for key: int in _arriving.keys():
		if not keys.has(key):
			_arriving.erase(key)
	_layout()

## Ein Würfel ist unterwegs (das Licht fährt noch): sein Platz steht schon, sein
## Körper erscheint erst mit deliver. Liegt er schon, wird er STILL eingezogen -
## eine Prämie bucht, bevor ihre Zeremonie losfährt, und ihr Würfel darf nicht
## zweimal ankommen.
func expect_arrival(def: DieDefinition) -> void:
	if def == null:
		return
	var key := body_key(def)
	if _arriving.has(key):
		return
	_arriving[key] = true
	if not _bodies.has(key):
		return
	_kill(_move_tweens.get(key))
	_move_tweens.erase(key)
	_kill(_hover_tweens.get(key))
	_hover_tweens.erase(key)
	if _hovered == key:
		_hovered = 0
	_free_body(_bodies[key])
	_bodies.erase(key)
	_layout()

## Er ist da: der Körper steigt durch den Fachboden auf seinen Platz.
## false = dieser Würfel war gar nicht unterwegs (dann steht er längst).
func deliver(def: DieDefinition) -> bool:
	var key := body_key(def)
	if not _arriving.has(key):
		return false
	_arriving.erase(key)
	_layout(key)
	return true

func awaiting(def: DieDefinition) -> bool:
	return _arriving.has(body_key(def))

## Der Würfel unter diesem WELT-Punkt der Glasebene ({} = keiner). Gefragt, nicht
## gemeldet - der Zeiger liegt auf dem Tisch (die Magazin-Grammatik).
func item_at(world: Vector3) -> Dictionary:
	var best := {}
	var best_distance := INF
	for item in items:
		var spot: Vector3 = item["spot"]
		var radius: float = item["radius"]
		var distance := Vector2(world.x - spot.x, world.z - spot.z).length()
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best = item
	return best

## Der Zeiger liegt auf einem Würfel (0 = keiner): er hebt sich und schwillt an.
## Nur der WECHSEL wird gefahren.
func set_hovered(key: int) -> void:
	if key == _hovered:
		return
	_apply_hover(_hovered, false)
	_hovered = key
	_apply_hover(_hovered, true)

func hovered_key() -> int:
	return _hovered

## Die Würfel-Definition auf Platz index (null = keiner).
func die_at(index: int) -> DieDefinition:
	if index < 0 or index >= _dice.size():
		return null
	return _dice[index]

## Alles Fahrende liegt sofort hart auf seinem Platz - ein Laufwechsel oder eine
## neue Auslage mitten im Auftritt darf nichts schuldig lassen.
func settle() -> void:
	for key: int in _move_tweens.keys():
		_kill(_move_tweens[key])
		var body: Node3D = _bodies.get(key)
		if body != null and is_instance_valid(body):
			body.global_position = _rest_position(key)
	_move_tweens.clear()

## Laufwechsel: die Schale ist leer, ihr Körper bleibt stehen.
func clear() -> void:
	settle()
	for key: int in _bodies.keys():
		_free_body(_bodies[key])
	_bodies.clear()
	_move_tweens.clear()
	_hover_tweens.clear()
	_arriving.clear()
	_dice.clear()
	items.clear()
	_hovered = 0

# --- Aufbau ---------------------------------------------------------------------

## Bodenplatte plus vier niedrige Randleisten - eine offene Schale, kein Kasten.
func _build_shell() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_bodies.clear()
	_move_tweens.clear()
	_hover_tweens.clear()
	_hovered = 0
	var floor_material := _metal(FLOOR_ALBEDO, FLOOR_EMISSION, FLOOR_ENERGY)
	var rim_material := _metal(RIM_ALBEDO, RIM_EMISSION, RIM_ENERGY)
	global_position = center
	floor_plate = _box("Floor", Vector3(half.x * 2.0, FLOOR_HEIGHT, half.y * 2.0),
		Vector3(0.0, FLOOR_LIFT + FLOOR_HEIGHT * 0.5, 0.0), floor_material)
	var rim_y := FLOOR_LIFT + RIM_HEIGHT * 0.5
	_box("RimXPlus", Vector3(RIM, RIM_HEIGHT, half.y * 2.0),
		Vector3(half.x - RIM * 0.5, rim_y, 0.0), rim_material)
	_box("RimXMinus", Vector3(RIM, RIM_HEIGHT, half.y * 2.0),
		Vector3(-half.x + RIM * 0.5, rim_y, 0.0), rim_material)
	_box("RimZPlus", Vector3(half.x * 2.0 - RIM * 2.0, RIM_HEIGHT, RIM),
		Vector3(0.0, rim_y, half.y - RIM * 0.5), rim_material)
	_box("RimZMinus", Vector3(half.x * 2.0 - RIM * 2.0, RIM_HEIGHT, RIM),
		Vector3(0.0, rim_y, -half.y + RIM * 0.5), rim_material)

## Der eine Schreiber: Plätze rechnen, Körper nachstellen, Eingelöstes versenken.
## arriving = die Instanz, die gerade STEIGT (0 = keine).
func _layout(arriving := 0) -> void:
	settle()
	items.clear()
	if half.x <= 0.0 or half.y <= 0.0 or floor_plate == null:
		return
	var span := inner()
	var grid := grid_for(span, _dice.size())
	var lanes := row_spots(grid.x, span.x, CELL)
	var ranks := row_spots(maxi(grid.y, 1), span.y, CELL)
	var wanted: Dictionary = {}
	var lift := DieBuilder.HALF_EXTENT * DIE_SCALE
	var rest_y := center.y + FLOOR_LIFT + FLOOR_HEIGHT + lift
	for i in _dice.size():
		var def: DieDefinition = _dice[i]
		var key := body_key(def)
		# Die Reihen lesen wie ein Buch: HINTEN ist Welt-+X (Bildschirm-oben).
		var spot := Vector3(center.x - ranks[i / grid.x], rest_y,
			center.z + lanes[i % grid.x])
		if _arriving.has(key):
			continue  # sein Platz steht, sein Körper wartet auf das Förderwerk
		wanted[key] = true
		var body: Node3D = _bodies.get(key)
		var fresh := body == null or not is_instance_valid(body)
		if fresh:
			body = _spawn_die(def)
			_bodies[key] = body
		items.append({"index": i, "key": key, "def": def, "spot": spot, "node": body,
			"radius": lift * 2.0 * PICK_FACTOR})
		if not fresh:
			_glide(key, body, spot)
		elif key == arriving:
			_arrive(key, body, spot)
		else:
			body.global_position = _rest_position(key, spot)
	for key: int in _bodies.keys():
		if not wanted.has(key):
			_leave(_bodies[key])
			_bodies.erase(key)
			_move_tweens.erase(key)
			_hover_tweens.erase(key)
			if _hovered == key:
				_hovered = 0

## Ein Würfel in der Schale hat keinen Tisch unter sich: seine Boden-Lache läge
## als Lichtfleck auf dem Fachboden statt unter ihm.
func _spawn_die(def: DieDefinition) -> Node3D:
	var die := FloatingDie.build_ghost(def)
	var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	faces.set_pool_enabled(false)
	add_child(die)
	return die

## Wo ein Würfel wirklich ruht: auf seinem Platz, gegriffen um seinen Hub höher.
func _rest_position(key: int, spot := Vector3.INF) -> Vector3:
	var at := spot if spot != Vector3.INF else _spot_for_key(key)
	return at + Vector3.UP * (HOVER_LIFT if key == _hovered else 0.0)

func _spot_for_key(key: int) -> Vector3:
	for item in items:
		if int(item["key"]) == key:
			return item["spot"]
	return global_position

## Ankunft: er steigt durch den Fachboden auf seinen Platz. settle legt ihn hart
## dorthin - die Richtigkeit hängt an keinem Tween.
func _arrive(key: int, body: Node3D, spot: Vector3) -> void:
	var target := _rest_position(key, spot)
	body.global_position = target - Vector3.UP * (RIM_HEIGHT + DIE_SCALE * 2.0)
	var tween := create_tween()
	tween.tween_property(body, "global_position", target, ARRIVE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tweens[key] = tween

## Rückt einer nach, gleitet er - es ist derselbe Würfel, nur sein Platz ist neu.
func _glide(key: int, body: Node3D, spot: Vector3) -> void:
	var target := _rest_position(key, spot)
	if body.global_position.is_equal_approx(target):
		return
	var tween := create_tween()
	tween.tween_property(body, "global_position", target, SHIFT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_move_tweens[key] = tween

## Eingelöst: er sinkt durch den Fachboden weg.
func _leave(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	var tween := create_tween()
	tween.tween_property(body, "global_position",
		body.global_position - Vector3.UP * (RIM_HEIGHT + DIE_SCALE * 2.0), LEAVE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(_free_body.bind(body))

func _apply_hover(key: int, on: bool) -> void:
	if key == 0:
		return
	var body: Node3D = _bodies.get(key)
	if body == null or not is_instance_valid(body):
		return
	_kill(_hover_tweens.get(key))
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "global_position",
		_spot_for_key(key) + Vector3.UP * (HOVER_LIFT if on else 0.0), HOVER_TIME)
	tween.tween_property(body, "scale",
		Vector3.ONE * DIE_SCALE * (HOVER_SWELL if on else 1.0), HOVER_TIME)
	_hover_tweens[key] = tween

func _kill(tween: Variant) -> void:
	var running := tween as Tween
	if running != null and running.is_valid():
		running.kill()

func _free_body(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.get_parent() == self:
		remove_child(body)
	body.queue_free()

func _metal(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.5
	material.roughness = 0.44
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _box(box_name: String, box_size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
