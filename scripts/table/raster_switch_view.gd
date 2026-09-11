class_name RasterSwitchView
extends Node3D
## Der RASTER-UMSCHALTER: eine flache Taste auf dem Filz RECHTS neben dem
## Vorrats-Loch, UNTER der Die-View-Säule des Ausgabefachs (Spieler-Wunsch
## 2026-09-11; bis dahin lag sie über der Grube). Sie legt zwischen den beiden
## Ansichten des Vorrats um - KÖRPER (die schwebenden Würfel, wie eh und je) und
## RASTER (die Glas-Ansicht, das Netz-Raster auf dem geschlossenen Gruben-Glas).
## Ihre Aufschrift nennt, was der Druck LIEFERT, nicht was gerade steht - darum
## steht "RASTER" auf ihr, solange die Körper stehen, und "KÖRPER", solange das
## Raster liegt. Ist gerade nicht umzulegen (Runde gezurrt), bleibt sie stehen und
## wird BLIND: der Knopf verschwindet nicht, er antwortet nur nicht.
## Kein mark_reflective - ein Körper AUF dem Glas spiegelt sich als grauer Schmier
## daneben (dieselbe Regel wie Ausgabefach und Datenzellen).

## Halbmaße der Taste (Welt): x = Bildschirm-Höhe, y = Welt-z = Bildschirm-Breite.
## Sie paßt UNTER die Die-View-Säule (gemessen 4,37 Welt breit) und läßt an beiden
## Seiten Luft; die Aufschrift wächst mit (siehe _write_face), bleibt also lesbar.
const HALF := Vector2(0.92, 2.04)
## Fuge zum Anker über ihr.
const GAP := 0.45

const PLATE_HEIGHT := 0.10
const PLATE_LIFT := 0.02
## Die Tastenfläche liegt als eigene Platte auf dem Sockel - ihr Rand ist der Saum.
const KEY_INSET := 0.28
const KEY_HEIGHT := 0.16

const PLATE_ALBEDO := Color(0.075, 0.072, 0.108)
const PLATE_EMISSION := Color(0.20, 0.22, 0.34)
const PLATE_ENERGY := 0.55
const KEY_ALBEDO := Color(0.17, 0.165, 0.215)

## Aufschrift und Tastenglühen: das Raster holt man in GOLD, blind ist es grau.
const LIVE_TINT := CasinoStyle.GOLD_INTENSE
const DEAD_TINT := CasinoStyle.MUTED
const FONT_SIZE := 64
const LABEL_LIFT := 0.02

## Greifen: die Magazin-Geste - sie hebt sich und schwillt eine Spur an.
const HOVER_LIFT := 0.22
const HOVER_SWELL := 1.06
const HOVER_TIME := 0.14

## Was der Druck liefert - die EINE Textquelle der Aufschrift.
const TEXT_TO_GRID := "RASTER"
const TEXT_TO_BODIES := "KÖRPER"

var center := Vector3.ZERO
var half := Vector2.ZERO

var _key: MeshInstance3D
var _label: Label3D
var _open := false
var _live := true
var _hovered := false
var _hover_tween: Tween

func _init(switch_name := "RasterSwitch") -> void:
	name = switch_name

## Ihr Platz (reine Funktion): eine Fuge UNTER dem Anker, mittig auf ihm. Der Anker
## ist die Unterkante der Die-View-Säule rechts des Vorrats - scene_root reicht ihn
## als Weltpunkt herein, denn die Säule meldet sich in Display-Pixeln.
static func spot_under(anchor: Vector3, half_extents := HALF) -> Vector3:
	return Vector3(anchor.x - GAP - half_extents.x, 0.0, anchor.z)

## Aufschrift zu einem Zustand (rein, damit sie prüfbar ist).
static func caption_for(grid_open: bool) -> String:
	return TEXT_TO_BODIES if grid_open else TEXT_TO_GRID

## Stellt die Taste (idempotent - dieselben Maße bauen nichts neu).
func setup(at: Vector3, half_extents := HALF) -> void:
	var wanted := Vector2(maxf(half_extents.x, 0.01), maxf(half_extents.y, 0.01))
	var same := _key != null and is_instance_valid(_key) \
		and center.is_equal_approx(at) and half.is_equal_approx(wanted)
	center = at
	half = wanted
	if same:
		return
	_build()

## Das Weltrechteck der Taste in XZ - scene_root vergleicht Display-Pixel damit.
func bounds_min() -> Vector2:
	return Vector2(center.x - half.x, center.z - half.y)

func bounds_max() -> Vector2:
	return Vector2(center.x + half.x, center.z + half.y)

## Liegt das Raster? Die Aufschrift nennt dann den Rückweg.
func set_open(grid_open: bool) -> void:
	if _open == grid_open:
		return
	_open = grid_open
	_write_face()

## Darf jetzt umgelegt werden? Blind bleibt sie stehen, antwortet aber nicht.
func set_live(live: bool) -> void:
	if _live == live:
		return
	_live = live
	_write_face()

func live() -> bool:
	return _live

func caption() -> String:
	return _label.text if _label != null and is_instance_valid(_label) else ""

## Der Zeiger liegt auf der Taste: sie hebt sich und schwillt an. Nur der WECHSEL
## wird gefahren.
func set_hovered(on: bool) -> void:
	if _hovered == on or _key == null or not is_instance_valid(_key):
		return
	_hovered = on
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "position:y", HOVER_LIFT if on else 0.0, HOVER_TIME)
	_hover_tween.tween_property(self, "scale",
		Vector3.ONE * (HOVER_SWELL if on else 1.0), HOVER_TIME)

# --- Aufbau ---------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	global_position = center
	position.y = 0.0
	scale = Vector3.ONE
	_hovered = false
	_box("Sockel", Vector3(half.x * 2.0, PLATE_HEIGHT, half.y * 2.0),
		Vector3(0.0, PLATE_LIFT + PLATE_HEIGHT * 0.5, 0.0),
		_metal(PLATE_ALBEDO, PLATE_EMISSION, PLATE_ENERGY))
	_key = _box("Taste",
		Vector3(maxf(half.x * 2.0 - KEY_INSET * 2.0, 0.05), KEY_HEIGHT,
			maxf(half.y * 2.0 - KEY_INSET * 2.0, 0.05)),
		Vector3(0.0, PLATE_LIFT + PLATE_HEIGHT + KEY_HEIGHT * 0.5, 0.0),
		_metal(KEY_ALBEDO, LIVE_TINT, 0.7))
	_label = Label3D.new()
	_label.name = "Aufschrift"
	_label.font_size = FONT_SIZE
	# Flach auf der Taste und in TISCH-Leserichtung: der Text läuft entlang Welt +Z
	# (Bildschirm rechts), seine Oberkante zeigt nach Welt +X (Bildschirm oben).
	_label.transform.basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	_label.position = Vector3(0.0,
		PLATE_LIFT + PLATE_HEIGHT + KEY_HEIGHT + LABEL_LIFT, 0.0)
	_label.outline_size = 14
	_label.outline_modulate = Color(0.03, 0.03, 0.05)
	add_child(_label)
	_write_face()

## Der EINE Schreiber der Anzeige: Aufschrift, ihr Maß und der Ton der Taste.
func _write_face() -> void:
	if _label == null or not is_instance_valid(_label):
		return
	var text := caption_for(_open)
	_label.text = text
	# Die Aufschrift füllt die Tastenbreite: geschätzte Textbreite in Schrift-
	# pixeln auf ihre Weltbreite gerechnet.
	var span := maxf(half.y * 2.0 - KEY_INSET * 4.0, 0.1)
	_label.pixel_size = span / maxf(float(text.length()) * float(FONT_SIZE) * 0.62, 1.0)
	var tint: Color = LIVE_TINT if _live else DEAD_TINT
	_label.modulate = Color(tint.r * 1.3 + 0.2, tint.g * 1.3 + 0.2, tint.b * 1.3 + 0.2)
	if _key != null and is_instance_valid(_key):
		var material := _key.material_override as StandardMaterial3D
		if material != null:
			material.emission = tint
			material.emission_energy_multiplier = 0.7 if _live else 0.22

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
