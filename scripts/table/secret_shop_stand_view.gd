class_name SecretShopStandView
extends Node3D
## Der Schwarzmarkt-Stand: ein kleiner Kiosk draußen im Dunkeln, JENSEITS der
## Glaskante auf dem endlosen Filzboden. Vor der Entdeckung steht er unbeleuchtet
## da - nur eine winzige Standby-Lampe verrät, dass dort etwas ist. Nach der
## Entdeckung trägt er violettes Neon, ein Dachschild und EINE Lichtpfütze
## (genau ein OmniLight - mehr verträgt der gekachelte Boden nicht).
## Die Übersicht schaut fast senkrecht von oben, darum liegt das Schild flach
## auf dem Dach: das ist die Fläche, die die Kamera sieht.

## Grundmaße des Kiosks (Welt-Einheiten). Bewusst KLEIN: zwischen Glaskante und
## Bildunterkante der Übersicht liegen nur wenige Welteinheiten dunkler Boden -
## ein größerer Kiosk fiele aus dem Rahmen (siehe scene_root.SECRET_STAND_Z).
## Der Tresen ist WEITER als das Dach: von fast senkrecht oben verdeckt ein
## überstehendes Dach den ganzen Rest, und der Stand wäre nur eine Platte. So
## liegen zwei Rechtecke ineinander - das liest sich als Bauwerk.
## BREIT längs der Tischkante, FLACH in die Tiefe und niedrig: die Bodentasche,
## die der Übersichts-Rahmen freilässt, ist nur ~3 Einheiten tief, aber ~9 lang
## (ausgemessen, siehe scene_root.SECRET_STAND_Z). Höhe kostet doppelt - sie
## projiziert zur Bildunterkante hin.
const COUNTER_SIZE := Vector3(1.4, 0.50, 3.0)
const ROOF_SIZE := Vector3(1.0, 0.08, 2.2)
const ROOF_Y := 0.95
const POST_SIZE := Vector3(0.09, ROOF_Y, 0.09)
const TRIM_THICKNESS := 0.06

## Violett der legendären Rarität - die Signaturfarbe des Schwarzmarkts.
const VIOLET := Color(0.75, 0.35, 1.0)
const BODY_ALBEDO := Color(0.055, 0.045, 0.075)
## Damit die Silhouette schon vor der Entdeckung im Lichtabfall registriert.
const BODY_EMISSION := Color(0.10, 0.09, 0.16)
const STANDBY_COLOR := Color(1.0, 0.72, 0.35)

const LIGHT_RANGE := 6.0
const LIGHT_ENERGY := 2.0

var _lit := false
var _trims: Array[MeshInstance3D] = []
var _sign: MeshInstance3D
var _standby: MeshInstance3D
var _pool_light: OmniLight3D
var _trim_material: StandardMaterial3D
var _sign_glow: MeshInstance3D
var _flicker_tween: Tween

func _ready() -> void:
	_build()
	_apply_lit(0.0)

# --- Zustand ------------------------------------------------------------------

## Idempotenter Zustand (scene_root ruft das bei jedem Sync): an = entdeckt.
func set_lit(lit: bool) -> void:
	if _flicker_tween != null and _flicker_tween.is_valid():
		_flicker_tween.kill()
	_lit = lit
	_apply_lit(1.0 if lit else 0.0)

func is_lit() -> bool:
	return _lit

## Entdeckungs-Moment: der Stand geht an. Kurzes, ZURÜCKHALTENDES Neon-Zünden
## (zwei Anläufe, dann steht es) - premium, nicht die kaputte Leuchtreklame.
## Liefert die Dauer.
func flicker_on() -> float:
	if _flicker_tween != null and _flicker_tween.is_valid():
		_flicker_tween.kill()
	_lit = true
	_flicker_tween = create_tween()
	# Anlauf: kurz an, fast aus, dann sauber hochziehen.
	_flicker_tween.tween_method(_apply_lit, 0.0, 0.75, 0.09)
	_flicker_tween.tween_method(_apply_lit, 0.75, 0.12, 0.07)
	_flicker_tween.tween_method(_apply_lit, 0.12, 0.9, 0.11)
	_flicker_tween.tween_method(_apply_lit, 0.9, 0.45, 0.06)
	_flicker_tween.tween_method(_apply_lit, 0.45, 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return 0.83

## Blendet Neon, Schild und Lichtpfütze gemeinsam auf t (0..1). Die Neon-Teile
## sind UNSHADED - dort trägt allein die albedo_color die Helligkeit (emission
## wertet ein unbeschattetes Material nicht aus), darum wird sie hochskaliert.
func _apply_lit(t: float) -> void:
	var amount := clampf(t, 0.0, 1.0)
	if _trim_material != null:
		# Deckel bewusst niedrig: höher gezogen klippt Grün mit und das Neon
		# kippt nach Weiß - die Signaturfarbe muss violett BLEIBEN.
		var gain := 0.25 + amount * 1.35
		_trim_material.albedo_color = Color(VIOLET.r * gain, VIOLET.g * gain, VIOLET.b * gain)
	for trim in _trims:
		trim.visible = amount > 0.02
	if _sign != null:
		_sign.visible = amount > 0.02
		var sign_gain := 0.3 + amount * 1.6
		_sign.material_override.albedo_color = Color(
			VIOLET.r * sign_gain, VIOLET.g * sign_gain, VIOLET.b * sign_gain)
	if _sign_glow != null:
		_sign_glow.visible = amount > 0.02
		var glow := _sign_glow.material_override as StandardMaterial3D
		if glow != null:
			glow.albedo_color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.20 * amount)
	if _pool_light != null:
		_pool_light.visible = amount > 0.02
		_pool_light.light_energy = LIGHT_ENERGY * amount
	# Die Standby-Lampe ist das Gegenstück: sie brennt nur, solange alles aus ist.
	if _standby != null:
		_standby.visible = amount <= 0.02

# --- Aufbau -------------------------------------------------------------------

func _build() -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = BODY_ALBEDO
	body.metallic = 0.55
	body.roughness = 0.4
	body.emission_enabled = true
	body.emission = BODY_EMISSION
	body.emission_energy_multiplier = 0.5

	_add_box("Counter", COUNTER_SIZE, Vector3(0.0, COUNTER_SIZE.y * 0.5, 0.0), body)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_box("Post%d%d" % [int(sx), int(sz)], POST_SIZE,
				Vector3(sx * ROOF_SIZE.x * 0.5, ROOF_Y * 0.5, sz * ROOF_SIZE.z * 0.5), body)
	_add_box("Roof", ROOF_SIZE, Vector3(0.0, ROOF_Y + ROOF_SIZE.y * 0.5, 0.0), body)

	_trim_material = StandardMaterial3D.new()
	_trim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trim_material.albedo_color = VIOLET
	# Der Hauptsaum liegt OBEN auf der Tresenkante: von fast senkrecht oben ist
	# dieses violette Rechteck das eigentliche "geöffnet"-Signal.
	_add_rim(COUNTER_SIZE.x, COUNTER_SIZE.z, COUNTER_SIZE.y + TRIM_THICKNESS * 0.5, "Counter")
	# Zweiter, kleinerer Saum auf der Dachkante - die Staffelung gibt Tiefe.
	_add_rim(ROOF_SIZE.x, ROOF_SIZE.z,
		ROOF_Y + ROOF_SIZE.y + TRIM_THICKNESS * 0.5, "Roof")

	# Dachschild: die Kamera blickt fast senkrecht, also liegt der Blitz FLACH auf
	# dem Dach - eine aufrechte Tafel wäre von oben nur eine Kante. Eigene
	# Geometrie statt Label3D: das ⚡-Zeichen kommt aus der Emoji-Schrift und käme
	# als goldener Aufkleber, nicht als violettes Neon.
	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.albedo_color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.20)
	var glow_mesh := PlaneMesh.new()
	glow_mesh.size = Vector2(ROOF_SIZE.x * 0.86, ROOF_SIZE.z * 0.86)
	_sign_glow = MeshInstance3D.new()
	_sign_glow.name = "SignGlow"
	_sign_glow.mesh = glow_mesh
	_sign_glow.material_override = glow_material
	_sign_glow.position = Vector3(0.0, ROOF_Y + ROOF_SIZE.y + 0.03, 0.0)
	_sign_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sign_glow)
	_build_bolt()

	# Standby: ein einziger winziger Punkt am Tresen - das "geschlossen"-Lämpchen.
	var standby_material := StandardMaterial3D.new()
	standby_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	standby_material.albedo_color = STANDBY_COLOR
	var standby_mesh := SphereMesh.new()
	standby_mesh.radius = 0.07
	standby_mesh.height = 0.14
	_standby = MeshInstance3D.new()
	_standby.name = "StandbyLamp"
	_standby.mesh = standby_mesh
	_standby.material_override = standby_material
	# Vor dem Dach, damit das Lämpchen von oben nicht darunter verschwindet.
	_standby.position = Vector3(COUNTER_SIZE.x * 0.36, COUNTER_SIZE.y + 0.13, 0.0)
	_standby.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_standby)

	# GENAU ein Licht: die Pfütze unter dem Stand (der Bodenshader nimmt Spill-
	# Lichter an). Mehr würde das 16-Lichter-Budget der Bodenkacheln angreifen.
	_pool_light = OmniLight3D.new()
	_pool_light.name = "PoolLight"
	_pool_light.light_color = VIOLET
	_pool_light.light_energy = LIGHT_ENERGY
	_pool_light.omni_range = LIGHT_RANGE
	_pool_light.shadow_enabled = false
	_pool_light.position = Vector3(0.0, 1.2, 0.0)
	add_child(_pool_light)

## Vier dünne Neon-Riegel als liegendes Rechteck (Saum einer Kante von oben).
func _add_rim(size_x: float, size_z: float, at_y: float, tag: String) -> void:
	for side in [-1.0, 1.0]:
		_trims.append(_add_box("%sRimZ%d" % [tag, int(side)],
			Vector3(size_x, TRIM_THICKNESS, TRIM_THICKNESS),
			Vector3(0.0, at_y, side * (size_z * 0.5 - TRIM_THICKNESS * 0.5)), _trim_material))
		_trims.append(_add_box("%sRimX%d" % [tag, int(side)],
			Vector3(TRIM_THICKNESS, TRIM_THICKNESS, size_z),
			Vector3(side * (size_x * 0.5 - TRIM_THICKNESS * 0.5), at_y, 0.0), _trim_material))

## Der Blitz als flaches Polygon auf dem Dach (Einheitsform, dann skaliert).
func _build_bolt() -> void:
	var outline := PackedVector2Array([
		Vector2(0.16, 0.50), Vector2(-0.34, 0.02), Vector2(-0.04, 0.02),
		Vector2(-0.20, -0.50), Vector2(0.32, -0.01), Vector2(0.02, -0.01)])
	var indices := Geometry2D.triangulate_polygon(outline)
	if indices.is_empty():
		return
	var scale_x := ROOF_SIZE.z * 0.62   # Blitz-Breite laeuft entlang Z
	var scale_z := ROOF_SIZE.x * 0.78
	var vertices := PackedVector3Array()
	for i in indices:
		var p := outline[i]
		vertices.append(Vector3(p.y * scale_z, 0.0, p.x * scale_x))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = VIOLET
	_sign = MeshInstance3D.new()
	_sign.name = "Sign"
	_sign.mesh = mesh
	_sign.material_override = material
	_sign.position = Vector3(0.0, ROOF_Y + ROOF_SIZE.y + 0.06, 0.0)
	_sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sign)

func _add_box(box_name: String, box_size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var node := MeshInstance3D.new()
	node.name = box_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node
