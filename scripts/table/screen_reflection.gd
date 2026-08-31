class_name ScreenReflection
extends SubViewport
## Planare Spiegelung der Würfel auf dem Display-Glas: der Compatibility-
## Renderer kann kein SSR, deshalb rendert eine an der Bildschirmfläche
## gespiegelte Kamera die als spiegelnd markierten Objekte (mark_reflective)
## in diesen SubViewport; screen_glass.gdshader mischt die Textur über die
## Anzeige. Eine echte Spiegelbasis wäre linkshändig (Determinante -1) und
## für Kameras ungültig - daher ist die X-Achse zusätzlich negiert und der
## Shader dreht das seitenverkehrte Bild per (1 - SCREEN_UV.x) zurück.

## Render-Layer 11: alles, was sich im Display spiegeln soll.
const LAYER := 1 << 10
## Halbe Auflösung reicht: die Vergrößerung weichzeichnet leicht - passend
## zum satinierten Glas.
const RESOLUTION_SCALE := 0.5

var main_camera: Camera3D  # setzt scene_root
var plane_height := 0.0  # Welthöhe der Glasfläche (setzt TableScreen.attach_to)
var mirror_camera: Camera3D

func _ready() -> void:
	own_world_3d = false  # spiegelt die ECHTE Szene
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mirror_camera = Camera3D.new()
	mirror_camera.name = "MirrorCamera"
	mirror_camera.cull_mask = LAYER
	add_child(mirror_camera)
	mirror_camera.current = true

## Schaltet die Spiegelung ab: im Titel-HUD geisterten die gespiegelten Würfel
## sonst über das Menü, das flach wie ein Bildschirm wirken soll - und in der
## Werkbank-Nahsicht spiegeln die Trays knapp außerhalb des Bildes herein.
func set_enabled(on: bool) -> void:
	if mirror_camera != null:
		mirror_camera.cull_mask = LAYER if on else 0

func _process(_delta: float) -> void:
	if main_camera == null:
		return
	# Auflösung folgt dem Fenster, sonst verzerrt die Projektion.
	var view_size: Vector2 = main_camera.get_viewport().get_visible_rect().size
	var target := Vector2i((view_size * RESOLUTION_SCALE).round())
	target.x = maxi(target.x, 1)
	target.y = maxi(target.y, 1)
	if size != target:
		size = target
	mirror_camera.fov = main_camera.fov
	mirror_camera.near = main_camera.near
	mirror_camera.far = main_camera.far
	mirror_camera.keep_aspect = main_camera.keep_aspect

	var t := main_camera.global_transform
	var origin := t.origin
	origin.y = 2.0 * plane_height - origin.y
	var basis := Basis(
		-_mirrored(t.basis.x),
		_mirrored(t.basis.y),
		_mirrored(t.basis.z))
	mirror_camera.global_transform = Transform3D(basis, origin)

func _mirrored(v: Vector3) -> Vector3:
	return Vector3(v.x, -v.y, v.z)

## Markiert alle Sichtbestandteile eines Knotens als spiegelnd (zusätzlich
## zum normalen Layer - die Hauptkamera sieht sie unverändert).
static func mark_reflective(root: Node) -> void:
	set_reflective(root, true)

## Schaltet die Spiegelung eines ganzen Knotens an oder aus. Ein im Tisch
## VERSENKTER Körper (der geparkte Vorrat) darf sich nicht spiegeln - sein Bild
## geisterte sonst über der Fläche.
static func set_reflective(root: Node, on: bool) -> void:
	var visuals: Array[Node] = []
	if root is VisualInstance3D:
		visuals.append(root)
	visuals.append_array(root.find_children("*", "VisualInstance3D", true, false))
	for visual: VisualInstance3D in visuals:
		if on:
			visual.layers |= LAYER
		else:
			visual.layers &= ~LAYER
