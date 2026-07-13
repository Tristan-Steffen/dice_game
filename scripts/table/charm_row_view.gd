class_name CharmRowView
extends Node3D
## Zeigt die besessenen Charms als physische 3D-Modelle auf dem Tisch (siehe
## Charm). Sechs feste Plätze auf einem symmetrischen Kreisbogen entlang des
## hinteren Tischrands (hohes +X = Bildschirm-oben in der Grubenansicht, siehe
## scene_root.gd: QUEUE_TRAY_PIT_POSITION), damit die Charms beim Würfeln immer
## sichtbar am oberen Bildrand liegen. Die Plätze sind gleichmäßig um 25°
## versetzt und spiegelsymmetrisch zur X-Achse (Z=0); die Reihenfolge der Plätze
## = Reihenfolge der übergebenen Charms (Index 0 = erster Platz). Jeder Charm
## liegt flach, zur Grubenmitte (Ursprung des Elternknotens) gedreht.
##
## set_charms() baut die Modelle bei jeder Änderung neu auf. Zusätzlich löst
## der Knoten den Hover für die Charm-Tooltips der Grubenansicht auf
## (charm_at_screen_pos, siehe scene_root._update_charm_tooltip).
##
## Es gibt kein physisches Podest mehr: Der Charm ist eine Lichtprojektion, die
## direkt aus der Tischfläche aufsteigt (siehe Hologramm-Look unten).

const SPOT_ANGLES_DEG: Array[float] = [-62.5, -37.5, -12.5, 12.5, 37.5, 62.5]
const SPOT_RADIUS := 26.0  # Abstand vom Grubenzentrum - liegt auf dem Filz des ScreenTable
const SPOT_Y := -3.4  # Höhe der Tischoberfläche (Filz-Oberkante des ScreenTable, siehe room.tscn)
const MODEL_SCALE := 4.0  # Grundskalierung des Charm-Modells auf Tischgröße
const MODEL_FALLBACK := "res://assets/models/rabbits_foot.glb"  # Platzhalter für Charms ohne eigenes Modell (siehe Charm.model_path)

## Anzahl fester Plätze - zugleich die Obergrenze besitzbarer Charms.
const SPOT_COUNT := 6

## Hologramm-Look: Der Charm wird als projizierte Lichtgestalt gezeigt (Star-
## Wars-Stil) - das Modell selbst bekommt den Hologramm-Shader übergestülpt, und
## aus der Tischfläche steigt für JEDEN Charm derselbe Lichtzylinder auf (siehe
## assets/shaders/charm_hologram.gdshader + hologram_beam.gdshader).
const HOLOGRAM_SHADER := preload("res://assets/shaders/charm_hologram.gdshader")
const BEAM_SHADER := preload("res://assets/shaders/hologram_beam.gdshader")
const BEAM_RADIUS := 3.6  # Lichtzylinder-Radius (Emitter-Fußabdruck auf dem Tisch)
const BEAM_HEIGHT := 9.0  # Höhe des Lichtkegels über der Tischfläche

## Bildschirm-Toleranz der Hover-Erkennung um die projizierte Charm-Mitte
## (siehe charm_at_screen_pos) - in der Grubenansicht liegen die Charms am
## oberen Bildrand und recht klein, daher großzügig gewählt.
const PICK_RADIUS_PX := 70.0

var charm_nodes: Array[Node3D] = []  # aktuell platzierte Modelle, eins je Charm
var current_charms: Array[Charm] = []  # parallel zu charm_nodes (für Tooltips)
var beam_nodes: Array[MeshInstance3D] = []  # Lichtzylinder je besetztem Platz (parallel zu charm_nodes)

## Gemeinsame Hologramm-Ressourcen (einmal gebaut, von allen Charms geteilt -
## sie animieren über TIME ohnehin gleich). Siehe _ensure_holo_resources.
var _holo_material: ShaderMaterial
var _beam_material: ShaderMaterial
var _beam_mesh: CylinderMesh

## Baut die Charm-Modelle neu auf: je Charm ein Modell auf dem nächsten festen
## Platz, in der Reihenfolge von charms (Index 0 = erster Platz). Mehr Charms als
## Plätze werden abgeschnitten (die Shop-Obergrenze sollte das ohnehin
## verhindern, siehe ShopController). Freie Plätze bleiben komplett leer.
func set_charms(charms: Array[Charm]) -> void:
	_ensure_holo_resources()
	for node in charm_nodes:
		node.queue_free()
	charm_nodes.clear()
	for beam in beam_nodes:
		beam.queue_free()
	beam_nodes.clear()
	current_charms = []
	var count := mini(charms.size(), SPOT_COUNT)
	for i in count:
		var model := _load_model(charms[i])
		add_child(model)
		model.transform = _spot_transform(i)
		charm_nodes.append(model)
		current_charms.append(charms[i])
		_add_beam(i)

## Baut die geteilten Hologramm-Ressourcen einmalig: das Shader-Material für die
## Charm-Modelle und Material + Mesh des Lichtzylinders (dessen Höhengrenzen an
## der Tischfläche beginnen, damit der Kegel aus dem Tisch aufsteigt).
func _ensure_holo_resources() -> void:
	if _holo_material != null:
		return
	_holo_material = ShaderMaterial.new()
	_holo_material.shader = HOLOGRAM_SHADER
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = BEAM_SHADER
	_beam_material.set_shader_parameter("bottom_y", SPOT_Y)
	_beam_material.set_shader_parameter("top_y", SPOT_Y + BEAM_HEIGHT)
	_beam_mesh = CylinderMesh.new()
	_beam_mesh.top_radius = BEAM_RADIUS
	_beam_mesh.bottom_radius = BEAM_RADIUS
	_beam_mesh.height = BEAM_HEIGHT
	_beam_mesh.radial_segments = 24

## Stülpt den Hologramm-Shader über jedes MeshInstance3D des Modells (ersetzt
## dessen Originaltextur) - macht aus dem festen Modell die Lichtprojektion.
func _apply_hologram(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _holo_material
	for child in node.get_children():
		_apply_hologram(child)

## Setzt den Lichtzylinder aus der Tischfläche des Platzes i (senkrecht, keine
## Charm-Drehung - für jeden Charm identisch).
func _add_beam(i: int) -> void:
	var beam := MeshInstance3D.new()
	beam.mesh = _beam_mesh
	beam.material_override = _beam_material
	var spot := _spot_position(i)
	beam.position = Vector3(spot.x, SPOT_Y + BEAM_HEIGHT * 0.5, spot.z)
	add_child(beam)
	beam_nodes.append(beam)

## Der Charm, dessen Modell auf dem Bildschirm am nächsten an screen_pos liegt
## (innerhalb PICK_RADIUS_PX), oder null. Reine Projektions-Nähe statt
## Physik-Raycast - die GLB-Modelle bringen keine (verlässlichen) Kollider mit.
## Grundlage der Hover-Tooltips in der Grubenansicht (siehe scene_root).
func charm_at_screen_pos(camera: Camera3D, screen_pos: Vector2) -> Charm:
	var index := charm_index_at_screen_pos(camera, screen_pos)
	return current_charms[index] if index != -1 else null

## Index-Variante von charm_at_screen_pos (Position in current_charms =
## Besitz-Reihenfolge), oder -1. Grundlage des Umsortier-Drags (siehe
## scene_root._try_start_charm_reorder).
func charm_index_at_screen_pos(camera: Camera3D, screen_pos: Vector2) -> int:
	var best := -1
	var best_dist := PICK_RADIUS_PX
	for i in charm_nodes.size():
		var world_pos := charm_nodes[i].global_position
		if camera.is_position_behind(world_pos):
			continue
		var dist := camera.unproject_position(world_pos).distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best

## Globale Position des festen Platzes i (Charm-Standpunkt auf der Tischfläche) -
## Drop-Ziel und Rückgleit-Anker des Umsortier-Drags (siehe scene_root).
func spot_global_position(i: int) -> Vector3:
	return to_global(_spot_transform(i).origin)

## Lässt das Charm-Modell i zu seinem festen Platz zurückgleiten - Abbruch bzw.
## ungültiges Ziel des Umsortier-Drags (siehe scene_root._cancel_charm_drag).
func glide_charm_to_spot(i: int) -> void:
	if i < 0 or i >= charm_nodes.size():
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(charm_nodes[i], "transform", _spot_transform(i), 0.3)

## Instanziert das 3D-Modell eines Charms (Charm.model_path), oder ersatzweise
## eine Platzhalter-Karte (siehe placeholder_model), solange der Charm noch
## kein eigenes Modell hat.
func _load_model(charm: Charm) -> Node3D:
	var path := charm.model_path
	var model: Node3D
	if path == "" or not ResourceLoader.exists(path):
		model = placeholder_model(charm.id)
	else:
		model = (load(path) as PackedScene).instantiate()
	_apply_hologram(model)  # nur die Tisch-Charms werden Hologramme, nicht die Shop-Vorschau
	return model

## Stabile, kräftige Farbe aus der Charm-id (Hash -> Farbton) - die Farbe der
## Platzhalter-Karte. Auch die Charm-Bibliothek nutzt sie als Farbfeld, damit
## Karte auf dem Tisch und Bibliothekseintrag zusammenfinden.
static func placeholder_color(charm_id: String) -> Color:
	var hue := float(abs(charm_id.hash()) % 360) / 360.0
	return Color.from_hsv(hue, 0.55, 0.85)

## Platzhalter für Charms ohne Modelldatei: eine flache rechteckige "Karte" in
## einer aus der id abgeleiteten Farbe (stabil je Charm, damit man sie auf dem
## Tisch auseinanderhalten kann). Auch der Shop nutzt sie für seine 3D-Vorschau
## (siehe ShopController._build_charm_thumb).
static func placeholder_model(charm_id: String) -> Node3D:
	var root := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.14, 1.4)
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = placeholder_color(charm_id)
	material.roughness = 0.4
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	return root

## Tischposition des festen Platzes i auf dem symmetrischen Kreisbogen
## (siehe SPOT_*), y = Tischoberfläche - hier steigt das Hologramm auf.
func _spot_position(i: int) -> Vector3:
	var angle := deg_to_rad(SPOT_ANGLES_DEG[i])
	return Vector3(cos(angle) * SPOT_RADIUS, SPOT_Y, sin(angle) * SPOT_RADIUS)

## Transform des festen Platzes i (lokal zu diesem Knoten): Position auf der
## Tischfläche, flach liegend und zur Mitte (Ursprung) gedreht.
func _spot_transform(i: int) -> Transform3D:
	var pos := _spot_position(i)
	var to_center := Vector3(-pos.x, 0.0, -pos.z).normalized()
	var basis := Basis.looking_at(to_center, Vector3.UP).scaled(Vector3.ONE * MODEL_SCALE)
	return Transform3D(basis, pos)
