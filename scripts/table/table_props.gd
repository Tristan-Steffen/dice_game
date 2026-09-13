class_name TableProps
## Gemeinsame Bausteine der code-gebauten Tisch-Requisiten: der Metall-Werkstoff
## und der Quader-Block, die jede Auslage, Klappe und Grube sonst für sich baute -
## dazu die zwei Rechnungen, die jede Auslage teilt (Reihen-Plätze, nächster Platz).

## Emissives Metall ohne eigenes Licht - die Tischregel: nur Emission.
static func metal(albedo: Color, emission: Color, energy: float,
		metallic := 0.5, roughness := 0.44) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

## Ein schattenloser Quader unter host (null, wenn eine Kante nichts mißt).
static func box(host: Node3D, box_name: String, box_size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	if box_size.x <= 0.001 or box_size.y <= 0.001 or box_size.z <= 0.001:
		return null
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(instance)
	return instance

## Plätze EINER Reihe: count Punkte, mittig über span verteilt, feste Teilung,
## solange sie passt - sonst rückt die Reihe zusammen. Reine Funktion.
static func row_spots(count: int, span: float, pitch: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if count <= 0 or span <= 0.0:
		return out
	var step := minf(maxf(pitch, 0.01), span / float(count))
	var first := -step * float(count - 1) * 0.5
	for i in count:
		out.append(first + step * float(i))
	return out

## Das Stück über diesem WELT-Punkt der Tischebene ({} = keins): je Eintrag
## {spot: Vector3, radius: float, ...}, gemessen in der XZ-Ebene.
static func nearest_item(items: Array, world: Vector3) -> Dictionary:
	var best := {}
	var best_distance := INF
	for item in items:
		var spot: Vector3 = item["spot"]
		var radius: float = item["radius"]
		var distance := Vector2(world.x - spot.x, world.z - spot.z).length()
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best = item
	return best
