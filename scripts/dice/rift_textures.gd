class_name RiftTextures
## Backt EIN Rissbild je Muster - FARBLOS. Die Tönung ist ein Shader-Uniform, kein
## Pixel: vorher entstand je Kombination aus Rissen und Essenz eine eigene Textur
## (bis zu ~30), und jeder Vakuum-Würfel buk sich seine eigene schwarze Kopie.
## Jetzt gibt es vier Texturen im ganzen Spiel, für immer.
##
## Kanäle (RGBA8, Datentextur - NICHT source_color, sonst zerrt die sRGB-Kurve
## Bogenlänge und Abstand krumm):
##   R  Kern - der scharfe Faden, die Verjüngung steckt schon in seiner Breite
##   G  Bogenlänge s entlang des verketteten Pfads (0..1); trägt jede Wanderung
##   B  Abstand zur Mittellinie, auf FIELD normiert (0 = Kern, 1 = Feldrand)
##   A  Deckung als Antialias-Hülle am Feldrand
##
## B ist der Grund, warum ein Ausbruch auf Übersichts-Distanz überhaupt liest: der
## Shader weitet nur das angenommene B-Band, und die LEUCHTENDE FLÄCHE wächst um
## das 2,5- bis 3,5-fache, ohne dass irgendetwas neu erzeugt wird.

## Kantenlänge der Textur - reiner Qualitätsregler, gemessen am Bake-Preis:
## 256 kostet 337 ms, 192 kostet 192 ms, 128 kostet 82 ms (alle vier Muster
## zusammen, einmalig beim Start). 128 wäre der billigste Rückfall, drückt die
## 0.45er Gabel aber auf 0.9 px halbe Breite und damit unter die Sichtbarkeit -
## und die Gabel IST das Kintsugi-Merkmal. 192 hält sie bei 1.35 px.
const SIZE := 192
## Kernbreite als Anteil der SEITE bei Gewicht 1.0 (volle Breite, vor Verjüngung).
## Als Anteil und nicht in Pixeln, damit SIZE ein reiner Qualitätsregler bleibt:
## eine andere Auflösung darf den Riss nicht dicker oder dünner machen.
const STROKE := 0.031
## Reichweite des Abstandsfelds als Anteil der Seite. Bewusst so gewählt, dass das
## Ruhe-Band (halo_width 0.35) genau den gebackenen Hof trifft und das Ausbruch-
## Band (0.35 × 2.8) fast das ganze Feld - beide Zahlen aus dem Entwurf passen
## damit ohne Nachstellen.
const FIELD := 0.16
## Anteil der Linie, über den ein freies Ende auf Haarstrich ausläuft. Eine Naht
## hört nicht auf, sie verliert sich - in Licht gelesen: eine immer feinere Spalte.
const TAPER_SPAN := 0.15

static var _cache := {}  # pattern_id -> ImageTexture

## Maske eines Musters ("" oder unbekannt -> null). Gecacht je MUSTER, also nie
## mehr als vier Einträge.
static func for_pattern(pattern_id: String) -> ImageTexture:
	if pattern_id == "":
		return null
	if _cache.has(pattern_id):
		return _cache[pattern_id]
	var texture := _bake(pattern_id)
	if texture != null:
		_cache[pattern_id] = texture
	return texture

## Maske zum Rift - die bequeme Form für die Anzeige.
static func for_rift(rift_id: String) -> ImageTexture:
	var rift := Rift.by_id(rift_id)
	return for_pattern(rift.pattern) if rift != null else null

## Alle vier auf einmal backen. Der Aufrufer wählt den Moment (hinter dem
## Titelbild sind 40 ms unsichtbar), damit der erste gerissene Würfel nicht mitten
## im Spiel für den Bake bezahlt.
static func warm() -> void:
	for pattern in Rift.all_patterns():
		for_pattern(pattern)

static func cache_size() -> int:
	return _cache.size()

## Der Bake selbst. Kein Abstandsfeld über die ganze Fläche: das wären 256² × ~40
## Segmente ≈ 2,6 Mio. Distanzen in GDScript. Stattdessen läuft jedes Segment nur
## über seinen EIGENEN Kasten (Segment plus Feldreichweite) - dieselbe Größenordnung
## Arbeit wie das alte Punkt-Stempeln, aber mit exakten Abständen statt Treppen.
static func _bake(pattern_id: String) -> ImageTexture:
	var lines := Rift.crack_lines(pattern_id)
	if lines.is_empty():
		return null
	var weights := Rift.crack_weights(pattern_id)
	var peak := _taper_peak(pattern_id)
	var taper_start := _tapers_at_start(pattern_id)

	var lengths := PackedFloat32Array()
	var total := 0.0
	var longest := 0.0
	for line in lines:
		var length := 0.0
		for i in range(line.size() - 1):
			length += line[i].distance_to(line[i + 1]) * float(SIZE)
		lengths.append(length)
		total += length
		longest = maxf(longest, length)
	# Der Sternbruch misst die Bogenlänge JE STRAHL ab dem Einschlag, nicht über
	# die Kette: seine Glut soll auf allen fünf Strahlen bei s = 0 am heißesten
	# sein. Alle anderen Muster verketten, damit jede Linie ihre eigene Phase erbt.
	var radial_arc := pattern_id == Rift.PATTERN_STAR
	var arc_span := maxf(longest if radial_arc else total, 0.001)

	var field := FIELD * float(SIZE)
	var pixels := SIZE * SIZE
	var data := PackedByteArray()
	data.resize(pixels * 4)
	var nearest := PackedFloat32Array()
	nearest.resize(pixels)
	nearest.fill(INF)
	# B muss außerhalb jedes Felds auf 1 stehen (= unendlich weit weg). Bliebe es
	# auf 0, läse der Shader die ganze leere Seite als "auf der Mittellinie".
	for i in pixels:
		data[i * 4 + 2] = 255

	var before := 0.0
	for line_index in lines.size():
		var line: PackedVector2Array = lines[line_index]
		var line_length: float = lengths[line_index]
		var weight: float = weights[line_index] if line_index < weights.size() else 1.0
		var walked := 0.0
		for i in range(line.size() - 1):
			var from := line[i] * float(SIZE)
			var to := line[i + 1] * float(SIZE)
			var span := to - from
			var span_length := span.length()
			if span_length < 0.001:
				continue
			var min_x := maxi(0, int(floorf(minf(from.x, to.x) - field)))
			var max_x := mini(SIZE - 1, int(ceilf(maxf(from.x, to.x) + field)))
			var min_y := maxi(0, int(floorf(minf(from.y, to.y) - field)))
			var max_y := mini(SIZE - 1, int(ceilf(maxf(from.y, to.y) + field)))
			# Die innere Schleife läuft über ~500k Pixel und rechnet darum in
			# QUADRATEN und in Skalaren: keine Vector2-Zwischenobjekte, eine
			# Wurzel erst, wenn das Pixel wirklich angenommen ist.
			var span_sq := span_length * span_length
			var field_sq := field * field
			for y in range(min_y, max_y + 1):
				var offset_y := float(y) + 0.5 - from.y
				var row := y * SIZE
				for x in range(min_x, max_x + 1):
					var offset_x := float(x) + 0.5 - from.x
					var t := clampf((offset_x * span.x + offset_y * span.y) / span_sq, 0.0, 1.0)
					var gap_x := offset_x - span.x * t
					var gap_y := offset_y - span.y * t
					var gap_sq := gap_x * gap_x + gap_y * gap_y
					if gap_sq >= field_sq:
						continue
					var index := row + x
					# Die NÄCHSTE Mittellinie gewinnt. Ohne diese Regel überschreiben
					# sich am Einschlag des Sterns die Strahlen gegenseitig ihre
					# Bogenwerte, und die Glutwelle zeigt dort eine Naht.
					if gap_sq >= nearest[index]:
						continue
					nearest[index] = gap_sq
					var distance := sqrt(gap_sq)
					var run := walked + t * span_length
					var along := run / maxf(line_length, 0.001)
					var arc := (run if radial_arc else before + run) / arc_span
					var half := _half_width(along, weight, peak, taper_start)
					var radial := clampf(distance / field, 0.0, 1.0)
					var core := 1.0 - smoothstep(half * 0.55, half * 1.25, distance)
					var cover := 1.0 - smoothstep(0.86, 1.0, radial)
					data[index * 4] = int(core * 255.0)
					data[index * 4 + 1] = int(clampf(arc, 0.0, 1.0) * 255.0)
					data[index * 4 + 2] = int(radial * 255.0)
					data[index * 4 + 3] = int(cover * 255.0)
			walked += span_length
		before += line_length

	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, data)
	# Ohne Mipmaps flimmert ein 1-px-Riss im 30-Würfel-Tray. Dass dabei auch der
	# G-Kanal gemittelt wird, ist entlang einer Linie harmlos und an Kreuzungen
	# Unsinn - vertretbar, weil auf Tray-Distanz nichts animiert.
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

## Halbe Kernbreite an der Stelle along (0..1 auf DIESER Linie). Lack füllt den
## Spalt: breit, wo die Scherben auseinandergingen, und zum Ende hin auf null.
static func _half_width(along: float, weight: float, peak: float, taper_start: bool) -> float:
	var span := maxf(maxf(peak, 1.0 - peak), 0.001)
	var offset := (along - peak) / span
	var bump := 1.0 - 0.75 * offset * offset          # 1 am Bauch, 0.25 an den Enden
	var ends := smoothstep(0.0, TAPER_SPAN, 1.0 - along)
	if taper_start:
		ends = minf(ends, smoothstep(0.0, TAPER_SPAN, along))
	return 0.5 * STROKE * float(SIZE) * weight * (0.45 + 0.55 * bump) * (0.22 + 0.78 * ends)

## Stelle der größten Breite auf einer Linie.
static func _taper_peak(pattern_id: String) -> float:
	match pattern_id:
		Rift.PATTERN_STAR:
			return 0.0        # der Einschlag IST die breiteste Stelle
		Rift.PATTERN_BOLT:
			return 0.55
		Rift.PATTERN_HAIRLINES:
			return 0.42
	return 0.45

## Läuft auch der ANFANG einer Linie auf Haarstrich aus? Beim Sternbruch nicht -
## dort sitzt der Einschlag, und ein verjüngter Einschlag wäre kein Einschlag.
static func _tapers_at_start(pattern_id: String) -> bool:
	return pattern_id != Rift.PATTERN_STAR
