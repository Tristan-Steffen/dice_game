class_name ScreenReflection
extends SubViewport
## Planare Spiegelung der Würfel auf dem Tisch-Display: der Compatibility-
## Renderer kann keine Screen-Space-Reflections, deshalb rendert eine an der
## Bildschirmfläche GESPIEGELTE Kamera die Würfel in diesen SubViewport (geteilte
## Welt, durchsichtiger Grund). Das Display-Glas (assets/shaders/screen_glass.gdshader,
## siehe TableScreen.attach_to) mischt die Textur per SCREEN_UV über die Anzeige -
## jeder Würfel bekommt so ein echtes, unter ihm verankertes Spiegelbild.
##
## Es spiegeln nur Objekte auf dem Render-Layer LAYER (siehe mark_reflective) -
## scene_root markiert die Spielwürfel in der Grube. Trays/Becher/Raum bleiben
## draußen: sie stehen teils NEBEN der Glasfläche, ihre Spiegelbilder würden
## dort falsch wirken, und der zweite Renderdurchlauf bleibt so billig.
##
## Die Spiegel-Kamera folgt jeden Frame der Hauptkamera (auch durch alle
## Zoom-Fahrten des CameraRig): Position und Achsen an der Ebene y=plane_height
## gespiegelt. Eine ECHTE Spiegelbasis wäre linkshändig (Determinante -1) und
## für Kameras ungültig - deshalb ist die X-Achse zusätzlich negiert und der
## Shader dreht das seitenverkehrte Bild per (1 - SCREEN_UV.x) zurück.

## Render-Layer 11: alles, was sich im Display spiegeln soll.
const LAYER := 1 << 10
## Halbe Auflösung reicht: die lineare Vergrößerung weichzeichnet das
## Spiegelbild leicht - passend zum satinierten Display-Glas (roughness > 0).
const RESOLUTION_SCALE := 0.5

## Die Spielkamera, der die Spiegel-Kamera folgt (setzt scene_root).
var main_camera: Camera3D
## Welthöhe der Glasfläche = Spiegelebene (setzt TableScreen.attach_to).
var plane_height := 0.0
var mirror_camera: Camera3D

func _ready() -> void:
	own_world_3d = false  # spiegelt die ECHTE Szene (Welt des Elternviewports)
	transparent_bg = true  # nur die Würfel, der Rest bleibt Anzeige
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mirror_camera = Camera3D.new()
	mirror_camera.name = "MirrorCamera"
	mirror_camera.cull_mask = LAYER
	add_child(mirror_camera)
	mirror_camera.current = true

func _process(_delta: float) -> void:
	if main_camera == null:
		return
	# Auflösung folgt dem Fenster (skaliert), sonst verzerrt die Projektion.
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
	# Achsen an der waagerechten Ebene spiegeln; -X macht die Basis wieder
	# rechtshändig (Bild seitenverkehrt, siehe Shader).
	var basis := Basis(
		-_mirrored(t.basis.x),
		_mirrored(t.basis.y),
		_mirrored(t.basis.z))
	mirror_camera.global_transform = Transform3D(basis, origin)

## Spiegelt einen Richtungsvektor an einer waagerechten Ebene.
func _mirrored(v: Vector3) -> Vector3:
	return Vector3(v.x, -v.y, v.z)

## Markiert alle Sichtbestandteile eines (Würfel-)Knotens als spiegelnd -
## zusätzlich zum normalen Layer 1, die Hauptkamera sieht sie unverändert.
static func mark_reflective(root: Node) -> void:
	if root is VisualInstance3D:
		root.layers |= LAYER
	for visual in root.find_children("*", "VisualInstance3D", true, false):
		visual.layers |= LAYER
