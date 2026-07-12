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
## Unter jedem Platz liegt dauerhaft ein "Untersetzer" (flache Scheibe als
## Podest): leere Plätze glimmen dezent grau, besetzte leuchten weiß (über den
## Glow-Schwellwert der WorldEnvironment hinaus, siehe scene_root.tscn).

const SPOT_ANGLES_DEG: Array[float] = [-62.5, -37.5, -12.5, 12.5, 37.5, 62.5]
const SPOT_RADIUS := 26.0  # Abstand vom Grubenzentrum, entlang des hinteren Tischrands
const SPOT_Y := -2.675  # Höhe der Tischoberfläche
const MODEL_SCALE := 4.0  # Grundskalierung des Charm-Modells auf Tischgröße
const MODEL_FALLBACK := "res://assets/models/rabbits_foot.glb"  # Platzhalter für Charms ohne eigenes Modell (siehe Charm.model_path)

## Untersetzer-Scheiben: Maße passend zur Platzhalter-Karte (4 x 5.6 Welt-
## einheiten Grundfläche bei MODEL_SCALE 4), die Scheibe ragt rundum etwas
## darüber hinaus. Die Charms stehen auf der Scheibe (siehe _spot_transform).
const COASTER_RADIUS := 3.6
const COASTER_HEIGHT := 0.3
const COASTER_ALBEDO := Color(0.16, 0.16, 0.18)  # dunkle Scheibe, das Leuchten kommt aus der Emission
## Leer: dezentes Grau unterhalb des Glow-Schwellwerts (glimmt nur leicht).
## Besetzt: überhelles Weiß, das sichtbar bloomt.
const COASTER_EMISSION_EMPTY := Color(0.45, 0.45, 0.5)
const COASTER_EMISSION_EMPTY_ENERGY := 0.6
const COASTER_EMISSION_OCCUPIED := Color(1.0, 1.0, 1.0)
const COASTER_EMISSION_OCCUPIED_ENERGY := 1.8

## Anzahl fester Plätze - zugleich die Obergrenze besitzbarer Charms.
const SPOT_COUNT := 6

## Bildschirm-Toleranz der Hover-Erkennung um die projizierte Charm-Mitte
## (siehe charm_at_screen_pos) - in der Grubenansicht liegen die Charms am
## oberen Bildrand und recht klein, daher großzügig gewählt.
const PICK_RADIUS_PX := 70.0

var charm_nodes: Array[Node3D] = []  # aktuell platzierte Modelle, eins je Charm
var current_charms: Array[Charm] = []  # parallel zu charm_nodes (für Tooltips)
var coaster_materials: Array[StandardMaterial3D] = []  # ein Material je Platz (Index = Platz), für das Umschalten grau/weiß

func _ready() -> void:
	_ensure_coasters()

## Baut die Charm-Modelle neu auf: je Charm ein Modell auf dem nächsten festen
## Platz, in der Reihenfolge von charms (Index 0 = erster Platz). Freie Plätze
## bleiben leer (ihr Untersetzer glimmt grau). Mehr Charms als Plätze werden
## abgeschnitten (die Shop-Obergrenze sollte das ohnehin verhindern, siehe
## ShopController).
func set_charms(charms: Array[Charm]) -> void:
	_ensure_coasters()
	for node in charm_nodes:
		node.queue_free()
	charm_nodes.clear()
	current_charms = []
	var count := mini(charms.size(), SPOT_COUNT)
	for i in count:
		var model := _load_model(charms[i])
		add_child(model)
		model.transform = _spot_transform(i)
		charm_nodes.append(model)
		current_charms.append(charms[i])
	for i in SPOT_COUNT:
		_set_coaster_occupied(i, i < count)

## Erzeugt die Untersetzer-Scheiben einmalig (ein fester Untersetzer je Platz,
## unabhängig davon, ob dort ein Charm steht). Anfangs alle "leer" (grau).
func _ensure_coasters() -> void:
	if not coaster_materials.is_empty():
		return
	for i in SPOT_COUNT:
		var mesh_instance := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		disk.top_radius = COASTER_RADIUS
		disk.bottom_radius = COASTER_RADIUS
		disk.height = COASTER_HEIGHT
		mesh_instance.mesh = disk
		var material := StandardMaterial3D.new()
		material.albedo_color = COASTER_ALBEDO
		material.roughness = 0.35
		material.metallic = 0.2
		material.emission_enabled = true
		mesh_instance.material_override = material
		add_child(mesh_instance)
		var spot := _spot_position(i)
		mesh_instance.position = Vector3(spot.x, SPOT_Y + COASTER_HEIGHT * 0.5, spot.z)
		coaster_materials.append(material)
		_set_coaster_occupied(i, false)

## Schaltet das Leuchten eines Untersetzers um: weiß (besetzt) oder dezent grau (leer).
func _set_coaster_occupied(i: int, occupied: bool) -> void:
	var material := coaster_materials[i]
	material.emission = COASTER_EMISSION_OCCUPIED if occupied else COASTER_EMISSION_EMPTY
	material.emission_energy_multiplier = COASTER_EMISSION_OCCUPIED_ENERGY if occupied else COASTER_EMISSION_EMPTY_ENERGY

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

## Globale Position des festen Platzes i (Charm-Standpunkt auf dem Untersetzer) -
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
	if path == "" or not ResourceLoader.exists(path):
		return placeholder_model(charm.id)
	return (load(path) as PackedScene).instantiate()

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
## (siehe SPOT_*), y = Tischoberfläche. Der Untersetzer sitzt direkt hier,
## der Charm um COASTER_HEIGHT erhöht obendrauf (siehe _spot_transform).
func _spot_position(i: int) -> Vector3:
	var angle := deg_to_rad(SPOT_ANGLES_DEG[i])
	return Vector3(cos(angle) * SPOT_RADIUS, SPOT_Y, sin(angle) * SPOT_RADIUS)

## Transform des festen Platzes i (lokal zu diesem Knoten): Position auf dem
## Untersetzer des Platzes, flach liegend und zur Mitte (Ursprung) gedreht.
func _spot_transform(i: int) -> Transform3D:
	var pos := _spot_position(i) + Vector3(0.0, COASTER_HEIGHT, 0.0)
	var to_center := Vector3(-pos.x, 0.0, -pos.z).normalized()
	var basis := Basis.looking_at(to_center, Vector3.UP).scaled(Vector3.ONE * MODEL_SCALE)
	return Transform3D(basis, pos)
