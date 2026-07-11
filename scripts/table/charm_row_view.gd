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

const SPOT_ANGLES_DEG: Array[float] = [-62.5, -37.5, -12.5, 12.5, 37.5, 62.5]
const SPOT_RADIUS := 26.0  # Abstand vom Grubenzentrum, entlang des hinteren Tischrands
const SPOT_Y := -2.675  # Höhe der Tischoberfläche
const MODEL_SCALE := 4.0  # Grundskalierung des Charm-Modells auf Tischgröße
const MODEL_FALLBACK := "res://assets/models/rabbits_foot.glb"  # Platzhalter für Charms ohne eigenes Modell (siehe Charm.model_path)

## Anzahl fester Plätze - zugleich die Obergrenze besitzbarer Charms.
const SPOT_COUNT := 6

## Bildschirm-Toleranz der Hover-Erkennung um die projizierte Charm-Mitte
## (siehe charm_at_screen_pos) - in der Grubenansicht liegen die Charms am
## oberen Bildrand und recht klein, daher großzügig gewählt.
const PICK_RADIUS_PX := 70.0

var charm_nodes: Array[Node3D] = []  # aktuell platzierte Modelle, eins je Charm
var current_charms: Array[Charm] = []  # parallel zu charm_nodes (für Tooltips)

## Baut die Charm-Modelle neu auf: je Charm ein Modell auf dem nächsten festen
## Platz, in der Reihenfolge von charms (Index 0 = erster Platz). Freie Plätze
## bleiben leer. Mehr Charms als Plätze werden abgeschnitten (die Shop-Obergrenze
## sollte das ohnehin verhindern, siehe ShopController).
func set_charms(charms: Array[Charm]) -> void:
	for node in charm_nodes:
		node.queue_free()
	charm_nodes.clear()
	current_charms = []
	for i in mini(charms.size(), SPOT_COUNT):
		var model := _load_model(charms[i])
		add_child(model)
		model.transform = _spot_transform(i)
		charm_nodes.append(model)
		current_charms.append(charms[i])

## Der Charm, dessen Modell auf dem Bildschirm am nächsten an screen_pos liegt
## (innerhalb PICK_RADIUS_PX), oder null. Reine Projektions-Nähe statt
## Physik-Raycast - die GLB-Modelle bringen keine (verlässlichen) Kollider mit.
## Grundlage der Hover-Tooltips in der Grubenansicht (siehe scene_root).
func charm_at_screen_pos(camera: Camera3D, screen_pos: Vector2) -> Charm:
	var best: Charm = null
	var best_dist := PICK_RADIUS_PX
	for i in charm_nodes.size():
		var world_pos := charm_nodes[i].global_position
		if camera.is_position_behind(world_pos):
			continue
		var dist := camera.unproject_position(world_pos).distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best = current_charms[i]
	return best

## Instanziert das 3D-Modell eines Charms (Charm.model_path), oder ersatzweise
## eine Platzhalter-Karte (siehe placeholder_model), solange der Charm noch
## kein eigenes Modell hat.
func _load_model(charm: Charm) -> Node3D:
	var path := charm.model_path
	if path == "" or not ResourceLoader.exists(path):
		return placeholder_model(charm.id)
	return (load(path) as PackedScene).instantiate()

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
	# Stabile, kräftige Farbe aus der id (Hash -> Farbton).
	var hue := float(abs(charm_id.hash()) % 360) / 360.0
	material.albedo_color = Color.from_hsv(hue, 0.55, 0.85)
	material.roughness = 0.4
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	return root

## Transform des festen Platzes i (lokal zu diesem Knoten): Position auf dem
## symmetrischen Kreisbogen (siehe SPOT_*), flach liegend und zur Mitte
## (Ursprung) gedreht.
func _spot_transform(i: int) -> Transform3D:
	var angle := deg_to_rad(SPOT_ANGLES_DEG[i])
	var pos := Vector3(cos(angle) * SPOT_RADIUS, SPOT_Y, sin(angle) * SPOT_RADIUS)
	var to_center := Vector3(-pos.x, 0.0, -pos.z).normalized()
	var basis := Basis.looking_at(to_center, Vector3.UP).scaled(Vector3.ONE * MODEL_SCALE)
	return Transform3D(basis, pos)
