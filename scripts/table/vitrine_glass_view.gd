class_name VitrineGlassView
extends Node3D
## Die SCHEIBE über einer Vitrine: eine durchsichtige Platte knapp über der
## Tischfläche, auf der die Beschriftung der Ware steht. Sie ist ein DISPLAY, kein
## Loch - alles, was das Spiel sagt, sagt es auf einer Anzeige, nie als freier
## 3D-Text im Raum.
## Sie hat ZWEI Lagen. Unten das GLAS (vitrine_glass.gdshader): es zeigt denselben
## Ausschnitt der Haupt-Display-Textur, den das Mesh darunter zeigte, und fährt ihn
## per Vorhang von deckend auf einen zarten Grundton - dieser Verlauf IST der
## Übergang, das Loch im Haupt-Mesh ist binär. Darüber die BESCHRIFTUNG aus einem
## eigenen kleinen SubViewport mit durchsichtigem Grund: wo sie nichts malt, bleibt
## Glas und der Blick fällt in die Bucht.
## Beide Meshes sind bewusst dieselbe Form wie die Anzeigefläche (PlaneMesh in XZ),
## damit die Abbildung Welt -> Textur identisch läuft: der Beschriftungs-Viewport
## ist ein AUSSCHNITT des Display-Pixelrasters, in seinen eigenen lokalen Pixeln
## gemessen.
## Kein mark_reflective - über einem Loch spiegelt nichts (Grubenregel).

## Ein Schlüsselwort auf der Beschriftung wurde geklickt.
signal lexikon_requested(entry_id: String)

## Über dem Display-Glas (Y = 0): genug gegen Z-Fighting, zu wenig für Parallaxe.
const LIFT := 0.06
## Die Glaslage liegt darunter - die Beschriftung steht AUF dem Glas, nicht darin.
const GLASS_LIFT := LIFT * 0.6

## Anzeigeton der Scheibe - derselbe Pool, mit dem das Display-Glas leuchtet
## (screen_glass.emission_energy), sonst läse die Schrift dunkler als der Tisch.
const ENERGY := 1.2

## Rest-Deckkraft der ganz offenen Scheibe: das "hier liegt Glas"-Signal. Bei 0,10
## las die Bucht als offenes Loch - dort lag sichtbar GAR NICHTS. Gerade schwach
## genug, dass Ware und Beschriftung darunter klar lesbar bleiben.
const GLASS_BASE := 0.18

## Kleinste Textur, damit ein Probe-Fenster ohne gemeldetes Rechteck nichts sprengt.
const MIN_TEXTURE := 8

var viewport: SubViewport
## Wirt der Beschriftung. Er misst in LOKALEN Buchten-Pixeln, also im selben
## Raster wie das Display darunter.
var annotation: Control
## Die eine Karte darin - EIN Stück, EINE Beschriftung.
var card: VitrineAnnotationView
var mesh: MeshInstance3D
## Die untere Lage: die Kopie des Displays, die zum Glas verblasst.
var glass: MeshInstance3D

var _material: StandardMaterial3D
var _glass_material: ShaderMaterial
var _open := 0.0

func _init(glass_name := "VitrineGlass") -> void:
	name = glass_name
	visible = false

## Spannt die Scheibe über die Bucht: Mitte auf dem Glas, halbe Ausdehnung in
## Welt-X/Welt-Z, Texturmaß in Display-Pixeln. Idempotent.
func setup(at: Vector3, half_extents: Vector2, texture_px: Vector2i) -> void:
	if viewport == null or not is_instance_valid(viewport):
		_build()
	var wanted := Vector2i(maxi(texture_px.x, MIN_TEXTURE), maxi(texture_px.y, MIN_TEXTURE))
	if viewport.size != wanted:
		viewport.size = wanted
		annotation.size = Vector2(wanted)
		_material.albedo_texture = viewport.get_texture()
	# Die Scheibe ist eine Vierteldrehung gegen die Anzeigefläche gestellt (siehe
	# _build): ihre size.x läuft danach in Welt-Z, also in Display-X.
	var span := Vector2(maxf(half_extents.y, 0.01), maxf(half_extents.x, 0.01)) * 2.0
	(mesh.mesh as PlaneMesh).size = span
	(glass.mesh as PlaneMesh).size = span
	global_position = Vector3(at.x, at.y + LIFT, at.z)

## Woher die untere Lage ihr Bild nimmt: die HAUPT-Display-Textur und der
## Ausschnitt der Bucht darin. In Display-Pixeln gemeldet, hier in UV gerechnet -
## geraten würde am Supersampling scheitern.
func set_display_field(texture: Texture2D, screen_px: Vector2, rect_px: Rect2) -> void:
	if _glass_material == null or screen_px.x <= 0.0 or screen_px.y <= 0.0:
		return
	_glass_material.set_shader_parameter("display_texture", texture)
	_glass_material.set_shader_parameter("field", Vector4(
		rect_px.position.x / screen_px.x, rect_px.position.y / screen_px.y,
		rect_px.size.x / screen_px.x, rect_px.size.y / screen_px.y))

## Der Vorhang: dieselbe Zahl, die das Loch aufschlägt, fährt die Scheibe von
## deckend auf Glas. Bei zu ist sie GANZ weg - über opakem Display zeichnete sie
## dasselbe Bild ein zweites Mal.
func set_open(value: float) -> void:
	_open = clampf(value, 0.0, 1.0)
	visible = _open > 0.0  # dieselbe Schwelle wie Loch, Filz und Buchtenkörper
	if _material != null:
		_material.albedo_color = Color(ENERGY, ENERGY, ENERGY, _open)
	if _glass_material != null:
		_glass_material.set_shader_parameter("open", _open)

func open_amount() -> float:
	return _open

## Das Feld der Scheibe in ihren eigenen (Buchten-lokalen) Pixeln.
func field_px() -> Vector2:
	return Vector2(viewport.size) if viewport != null and is_instance_valid(viewport) \
		else Vector2.ZERO

## Beschriftung eines Stücks zeigen: anchor in Buchten-lokalen Pixeln.
func show_annotation(data: Dictionary, unit: float, anchor: Vector2) -> void:
	if card == null or not is_instance_valid(card):
		return
	card.show_item(data, unit)
	card.place_over(anchor, field_px())

func hide_annotation() -> void:
	if card != null and is_instance_valid(card):
		card.hide_card()

func annotation_visible() -> bool:
	return card != null and is_instance_valid(card) and card.visible

## Ob der Buchten-lokale Pixel auf der stehenden Karte liegt. Der Zeiger muss vom
## Stück auf seine Beschriftung wandern dürfen (die Schlüsselwörter sind
## Klickziele) - täte er es nicht, verschwände die Karte unter ihm.
func card_has_point(local: Vector2) -> bool:
	if not annotation_visible():
		return false
	return Rect2(card.position, card.size).has_point(local)

## Ob unter dem Buchten-lokalen Pixel ein Klickziel der Beschriftung liegt (ein
## Lexikon-Verweis gewinnt vor dem physischen Griff).
func interactive_at(local: Vector2) -> bool:
	if annotation == null or not is_instance_valid(annotation) or _open <= 0.0:
		return false
	return TableScreen.interactive_under(annotation, local)

## Reicht ein Mausereignis in Buchten-lokalen Pixeln an die Beschriftung weiter.
func push_pixel_input(event: InputEventMouse, local: Vector2) -> void:
	if viewport == null or not is_instance_valid(viewport):
		return
	var forwarded := event.duplicate() as InputEventMouse
	forwarded.position = local
	forwarded.global_position = local
	viewport.push_input(forwarded)

func _build() -> void:
	viewport = SubViewport.new()
	viewport.name = "AnnotationViewport"
	# Durchsichtiger Grund: gemalt wird nur die Beschriftung, alles andere ist Glas.
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.use_hdr_2d = true  # überhelle Neon-Farben dürfen blühen wie im Display
	viewport.size = Vector2i(MIN_TEXTURE, MIN_TEXTURE)
	add_child(viewport)

	annotation = Control.new()
	annotation.name = "Annotation"
	annotation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(annotation)

	card = VitrineAnnotationView.new()
	card.lexikon_requested.connect(func(entry_id: String) -> void:
		lexikon_requested.emit(entry_id))
	annotation.add_child(card)

	_glass_material = ShaderMaterial.new()
	_glass_material.shader = load("res://assets/shaders/vitrine_glass.gdshader")
	_glass_material.set_shader_parameter("energy", ENERGY)
	_glass_material.set_shader_parameter("base_alpha", GLASS_BASE)
	_glass_material.set_shader_parameter("open", _open)

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_texture = viewport.get_texture()
	_material.albedo_color = Color(ENERGY, ENERGY, ENERGY, _open)

	# Eine Vierteldrehung: erst damit liest die Beschriftung wie das Display
	# darunter (dessen Textur-x läuft in Welt-Z, die eines nackten PlaneMesh in
	# Welt-X). Gemessen, nicht hergeleitet - die Anzeigefläche bringt ihre eigene
	# Drehung aus dem Tisch-GLB mit. Die Glaslage steht genauso, sonst käme die
	# Display-Kopie seitenverkehrt an.
	glass = _plane("GlassPane", _glass_material, -LIFT + GLASS_LIFT)
	mesh = _plane("Glass", _material, 0.0)

func _plane(plane_name: String, material: Material, drop: float) -> MeshInstance3D:
	var plane := MeshInstance3D.new()
	plane.name = plane_name
	plane.mesh = PlaneMesh.new()
	plane.material_override = material
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.rotation.y = -PI / 2.0
	plane.position.y = drop
	add_child(plane)
	return plane
