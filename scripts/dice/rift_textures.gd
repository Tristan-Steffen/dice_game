class_name RiftTextures
## Zeichnet die Rissbilder EINER Seite in eine Textur - dieselben Polylinien, die
## das Würfelnetz malt (Rift.crack_lines), damit Tisch und Werkbank nie ein
## anderes Muster zeigen. Gecacht je Kombination aus Rissen und Essenz: 30 Würfel
## × 6 Seiten dürfen nicht 180 Bilder erzeugen.

const SIZE := 128
## Strichstärke in Pixeln - dick genug, dass die Figur aus der Übersichtskamera
## noch als Riss liest, dünn genug für "Bruch" statt "Bemalung".
const STROKE := 5

static var _cache := {}  # Schlüssel -> ImageTexture

## Textur für die Risse EINER Seite ("" wenn keine). rift_ids kommt aus
## DieDefinition.rifts_on, essence_id färbt den Vakuum-Sonderfall schwarz.
static func for_face(rift_ids: Array[String], essence_id: String) -> ImageTexture:
	if rift_ids.is_empty():
		return null
	var key := "%s|%s" % ["+".join(rift_ids), essence_id]
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for rift_id in rift_ids:
		var color := RiftEffects.crack_color(rift_id, essence_id)
		for line in Rift.lines_for(rift_id):
			_stroke(image, line, color)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

## Ein Linienzug in die Bilddaten: Segment für Segment, mit runden Enden - ein
## Riss hat keine Ecken, er läuft aus.
static func _stroke(image: Image, line: PackedVector2Array, color: Color) -> void:
	for i in range(line.size() - 1):
		var from := line[i] * float(SIZE)
		var to := line[i + 1] * float(SIZE)
		var steps := maxi(1, int(from.distance_to(to)))
		for step in steps + 1:
			var point := from.lerp(to, float(step) / float(steps))
			_dot(image, point, color)

static func _dot(image: Image, center: Vector2, color: Color) -> void:
	var radius := float(STROKE) * 0.5
	var min_x := maxi(0, int(center.x - radius))
	var max_x := mini(SIZE - 1, int(center.x + radius))
	var min_y := maxi(0, int(center.y - radius))
	var max_y := mini(SIZE - 1, int(center.y + radius))
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, color)
