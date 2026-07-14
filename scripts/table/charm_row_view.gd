class_name CharmRowView
extends Node3D
## Zeigt die besessenen Charms als physische 3D-Modelle auf dem Tisch (siehe
## Charm). Sechs feste Plätze in einer geraden Reihe entlang des hinteren
## Tischrands (fester Abstand LINE_X in +X = Bildschirm-oben in der Grubenansicht,
## siehe scene_root.gd: QUEUE_TRAY_PIT_POSITION), gleichmäßig in Z verteilt und
## spiegelsymmetrisch zur X-Achse (Z=0). Die Reihenfolge der Plätze = Reihenfolge
## der übergebenen Charms (Index 0 = erster Platz, ganz links = niedrigstes Z).
##
## set_charms() baut die Modelle bei jeder Änderung neu auf. Zusätzlich löst
## der Knoten den Hover für die Charm-Tooltips der Grubenansicht auf
## (charm_at_screen_pos, siehe scene_root._update_charm_tooltip).
##
## Es gibt kein physisches Podest mehr: Der Charm ist eine Lichtprojektion, die
## direkt aus der Tischfläche aufsteigt (siehe Hologramm-Look unten).

const LINE_X := 31.0  # fester Abstand der Reihe vom Grubenzentrum (hinterer Tischrand, +X)
const LINE_SPACING := 9.0  # Z-Abstand zwischen benachbarten Charms in der Reihe
const SPOT_Y := 0.0  # Höhe der Tischoberfläche (Filz-Oberkante des ScreenTable, siehe room.tscn)
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

## Placement-Pivots (eins je Charm): DIESE trägt Platz-Transform und wird beim
## Umsortier-Drag bewegt (siehe scene_root). Das eigentliche Modell hängt darin
## und dreht sich langsam (siehe _process) - so kollidiert die Dauerrotation
## nie mit Drag/Gleiten, die nur den Pivot anfassen.
var charm_nodes: Array[Node3D] = []
var charm_models: Array[Node3D] = []  # das rotierende Modell je Pivot (parallel zu charm_nodes)
var current_charms: Array[Charm] = []  # parallel zu charm_nodes (für Tooltips)
var beam_nodes: Array[MeshInstance3D] = []  # Lichtzylinder je besetztem Platz (parallel zu charm_nodes)
var charm_materials: Array = []  # je Charm die Hologramm-ShaderMaterials aller Flächen (für flash_charm)

## Drehgeschwindigkeit der Hologramme (rad/s) - langsamer Plattenteller-Spin.
const ROTATION_SPEED := 0.5

## Geteilte Ressourcen des Lichtzylinders: EIN Material je Rarität (der Kegel
## schimmert in der Raritätsfarbe des Charms, siehe Charm.rarity_color - Weiß/
## Grün/Blau/Violett), von allen Charms derselben Rarität geteilt (er animiert
## über TIME ohnehin gleich). Der Hologramm-Shader wird dagegen je Fläche
## instanziiert (Originalfarbe erhalten, siehe _apply_hologram).
var _beam_materials: Dictionary = {}  # Rarität -> ShaderMaterial
var _beam_mesh: CylinderMesh

## Wie stark die Raritätsfarbe in den Kegel mischt: dezent Richtung Grundton
## des Beams, damit der Kegel weiter als Lichtprojektion liest und die Farbe
## nur "anschimmert" (siehe _beam_material_for).
const BEAM_RARITY_MIX := 0.65

## Baut die Charm-Modelle neu auf: je Charm ein Modell auf dem nächsten festen
## Platz, in der Reihenfolge von charms (Index 0 = erster Platz). Mehr Charms als
## Plätze werden abgeschnitten (die Shop-Obergrenze sollte das ohnehin
## verhindern, siehe ShopController). Freie Plätze bleiben komplett leer.
func set_charms(charms: Array[Charm]) -> void:
	_ensure_holo_resources()
	for node in charm_nodes:
		node.queue_free()
	charm_nodes.clear()
	charm_models.clear()
	for beam in beam_nodes:
		beam.queue_free()
	beam_nodes.clear()
	current_charms = []
	charm_materials.clear()
	var count := mini(charms.size(), SPOT_COUNT)
	for i in count:
		# Pivot am Platz, Modell darin (dreht sich, ohne Drag/Gleiten zu stören).
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.transform = _spot_transform(i)
		var model := _load_model(charms[i])
		pivot.add_child(model)
		var materials: Array[ShaderMaterial] = []
		_apply_hologram(model, materials)
		charm_nodes.append(pivot)
		charm_models.append(model)
		current_charms.append(charms[i])
		charm_materials.append(materials)
		_add_beam(i)

## Langsame Dauerrotation der Hologramme um die Hochachse (nur die Modelle, nicht
## die Pivots - siehe charm_models). Der Lichtzylinder steht still.
func _process(delta: float) -> void:
	for model in charm_models:
		model.rotate_object_local(Vector3.UP, ROTATION_SPEED * delta)

## Baut die geteilten Ressourcen des Lichtzylinders einmalig (Mesh); die
## Rarität-Materialien entstehen bei Bedarf (siehe _beam_material_for). Die
## Höhengrenzen beginnen an der Tischfläche, damit der Kegel aus dem Tisch
## aufsteigt.
func _ensure_holo_resources() -> void:
	if _beam_mesh != null:
		return
	_beam_mesh = CylinderMesh.new()
	_beam_mesh.top_radius = BEAM_RADIUS
	_beam_mesh.bottom_radius = BEAM_RADIUS
	_beam_mesh.height = BEAM_HEIGHT
	_beam_mesh.radial_segments = 24

## Das (geteilte) Kegel-Material für eine Rarität: der Standard-Blauton des
## Beam-Shaders, dezent Richtung Raritätsfarbe gemischt (Weiß/Grün/Blau/Violett,
## siehe Charm.RARITY_COLORS) - einmal je Rarität gebaut, dann wiederverwendet.
func _beam_material_for(rarity: String) -> ShaderMaterial:
	if _beam_materials.has(rarity):
		return _beam_materials[rarity]
	var material := ShaderMaterial.new()
	material.shader = BEAM_SHADER
	material.set_shader_parameter("bottom_y", SPOT_Y)
	material.set_shader_parameter("top_y", SPOT_Y + BEAM_HEIGHT)
	var base_color := Color(0.3, 0.68, 1.0)  # Grundton des Shaders (beam_color-Default)
	var rarity_color: Color = Charm.RARITY_COLORS.get(rarity, Charm.RARITY_COLORS[Charm.RARITY_COMMON])
	var tinted := base_color.lerp(rarity_color, BEAM_RARITY_MIX)
	material.set_shader_parameter("beam_color", Vector3(tinted.r, tinted.g, tinted.b))
	_beam_materials[rarity] = material
	return material

## Macht aus dem festen Modell die Lichtprojektion: legt je Fläche ein eigenes
## Hologramm-Shader-Material an, das die ORIGINALFARBE (Textur + albedo_color der
## Fläche) übernimmt - so bleiben die Charm-Farben erhalten, statt einfarbig zu
## werden. out_materials sammelt die erzeugten Materialien des Charms ein (für
## den flash-Parameter, siehe flash_charm).
func _apply_hologram(node: Node, out_materials: Array[ShaderMaterial]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var surface_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0
		# Originalmaterialien zuerst lesen (material_override würde sonst pro
		# Fläche gleich sein und die Flächen-Overrides überstrahlen) und den
		# Voll-Override lösen, damit die Flächen-Hologramme greifen.
		var originals: Array = []
		for s in surface_count:
			originals.append(mesh_instance.get_active_material(s))
		mesh_instance.material_override = null
		for s in surface_count:
			var material := ShaderMaterial.new()
			material.shader = HOLOGRAM_SHADER
			if originals[s] is BaseMaterial3D:
				var base := originals[s] as BaseMaterial3D
				material.set_shader_parameter("albedo_color", base.albedo_color)
				if base.albedo_texture != null:
					material.set_shader_parameter("albedo_tex", base.albedo_texture)
					material.set_shader_parameter("use_texture", true)
			mesh_instance.set_surface_override_material(s, material)
			out_materials.append(material)
	for child in node.get_children():
		_apply_hologram(child, out_materials)

## Lässt den Charm auf Platz index kurz aufblitzen (Zähl-Animation: "dieser
## Charm feuert gerade") - Helligkeits-Puls über den flash-Shader-Parameter
## plus kleiner Größen-Pop des Modells. Läuft im Hintergrund (blockiert nicht).
func flash_charm(index: int) -> void:
	if index < 0 or index >= charm_models.size():
		return
	var materials: Array = charm_materials[index]
	var set_flash := func(value: float) -> void:
		for material: ShaderMaterial in materials:
			material.set_shader_parameter("flash", value)
	var flash_tween := create_tween()
	flash_tween.tween_method(set_flash, 0.0, 1.0, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tween.tween_method(set_flash, 1.0, 0.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var model := charm_models[index]
	var scale_tween := create_tween()
	scale_tween.tween_property(model, "scale", Vector3.ONE * 1.22, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(model, "scale", Vector3.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Setzt den Lichtzylinder aus der Tischfläche des Platzes i (senkrecht, keine
## Charm-Drehung) - der Kegel schimmert in der Raritätsfarbe des Charms.
func _add_beam(i: int) -> void:
	var beam := MeshInstance3D.new()
	beam.mesh = _beam_mesh
	beam.material_override = _beam_material_for(current_charms[i].rarity)
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

## Tischposition des festen Platzes i in der geraden Reihe (fester X = LINE_X,
## Z gleichmäßig um die Mitte verteilt), y = Tischoberfläche - hier steigt das
## Hologramm auf.
func _spot_position(i: int) -> Vector3:
	var z := (float(i) - float(SPOT_COUNT - 1) * 0.5) * LINE_SPACING
	return Vector3(LINE_X, SPOT_Y, z)

## Transform des festen Platzes i (lokal zu diesem Knoten): Position auf der
## Tischfläche, flach liegend und zur Mitte (Ursprung) gedreht.
func _spot_transform(i: int) -> Transform3D:
	var pos := _spot_position(i)
	var to_center := Vector3(-pos.x, 0.0, -pos.z).normalized()
	var basis := Basis.looking_at(to_center, Vector3.UP).scaled(Vector3.ONE * MODEL_SCALE)
	return Transform3D(basis, pos)
