class_name FloorVeinView
extends Node3D
## Boden-Ader: das 3D-Gegenstück der LED-Leisten. LedStripView lebt AUF dem
## Glas (2D im SubViewport) und endet an der Glaskante - alles dahinter liegt auf
## dem endlosen Filzboden und braucht echte Geometrie. Die Ader ist ein dünnes
## Leuchtband knapp über Y=0, in Segmente zerlegt: so kann sie beim Entdecken
## fortschreitend hinter dem Kometen aufleuchten und danach schwach weiterbrennen.

## Knapp über der Tischebene - der Filzboden liegt bei TableGround.SURFACE_Y.
const VEIN_Y := 0.03
const VEIN_WIDTH := 0.24
const SEGMENT_LENGTH := 0.8        # Zielkantenlänge eines Segments
const IDLE_ENERGY := 0.75          # Dauerbrand nach der Entdeckung
const LIVE_ENERGY := 3.2           # frisch gezündetes Segment
## Nachglühen: so viele Segmente hinter dem Kometen bleiben noch überhell.
const TAIL_SEGMENTS := 3.0

const COMET_RADIUS := 0.26

var color := CasinoStyle.CHARGE

var _segments: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _points: PackedVector3Array = PackedVector3Array()
var _comet: MeshInstance3D
var _progress := 0.0
var _tween: Tween

## Verlegt die Ader zwischen zwei Weltpunkten (y wird ignoriert). Muss vor jedem
## set_progress/play stehen; ein erneuter Aufruf baut sie neu.
func lay(from: Vector3, to: Vector3) -> void:
	_clear()
	var a := Vector3(from.x, VEIN_Y, from.z)
	var b := Vector3(to.x, VEIN_Y, to.z)
	var span := a.distance_to(b)
	if span < 0.01:
		return
	var count := maxi(2, int(round(span / SEGMENT_LENGTH)))
	_points = PackedVector3Array([a, b])
	var step := (b - a) / float(count)
	var yaw := atan2(step.x, step.z)
	for i in count:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(color.r, color.g, color.b, 0.0)
		var mesh := BoxMesh.new()
		# Leichte Überlappung, damit zwischen den Segmenten keine Lücke blitzt.
		mesh.size = Vector3(VEIN_WIDTH, 0.02, step.length() * 1.04)
		var seg := MeshInstance3D.new()
		seg.name = "Segment%d" % i
		seg.mesh = mesh
		seg.material_override = material
		seg.position = a + step * (float(i) + 0.5)
		seg.rotation.y = yaw
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(seg)
		_segments.append(seg)
		_materials.append(material)

	var comet_material := StandardMaterial3D.new()
	comet_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	comet_material.albedo_color = Color(color.r * 1.4, color.g * 1.4, color.b * 1.4)
	var comet_mesh := SphereMesh.new()
	comet_mesh.radius = COMET_RADIUS
	comet_mesh.height = COMET_RADIUS * 2.0
	_comet = MeshInstance3D.new()
	_comet.name = "Comet"
	_comet.mesh = comet_mesh
	_comet.material_override = comet_material
	_comet.visible = false
	_comet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_comet)
	_apply(0.0, false)

## Idempotenter Ruhezustand: an = schwacher Dauerbrand, aus = unsichtbar.
func set_lit(lit: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _comet != null:
		_comet.visible = false
	_progress = 1.0 if lit else 0.0
	_apply(_progress, false)

## Entdeckungs-Lauf: der Komet fährt die Ader ab, hinter ihm zünden die Segmente
## und klingen auf den Dauerbrand ab. Liefert die Dauer.
func play(duration: float) -> float:
	if _segments.is_empty():
		return 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_comet.visible = true
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void: _apply(t, true), 0.0, 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void:
		_comet.visible = false
		_apply(1.0, false))
	return duration

## Zeichnet den Stand: alle Segmente bis progress brennen, die dicht hinter dem
## Kopf zusätzlich überhell (running = laufende Zeremonie).
func _apply(progress: float, running: bool) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	var head := _progress * float(_materials.size())
	for i in _materials.size():
		var lit := float(i) < head
		var energy := IDLE_ENERGY if lit else 0.0
		if running and lit:
			var behind := head - float(i)
			energy = maxf(IDLE_ENERGY,
				LIVE_ENERGY * clampf(1.0 - behind / TAIL_SEGMENTS, 0.0, 1.0))
		# UNSHADED wertet emission nicht aus - die Helligkeit steckt in der
		# albedo_color; über 1.0 blüht sie im HDR auf.
		_materials[i].albedo_color = Color(
			color.r * energy, color.g * energy, color.b * energy, 0.92)
		_segments[i].visible = energy > 0.0
	if _comet != null and _comet.visible and _points.size() == 2:
		_comet.position = _points[0].lerp(_points[1], _progress)

func _clear() -> void:
	for seg in _segments:
		seg.queue_free()
	_segments.clear()
	_materials.clear()
	if _comet != null:
		_comet.queue_free()
		_comet = null
