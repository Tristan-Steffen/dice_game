class_name RuneTextures
## Backt EIN Zeichen je Rune - FARBLOS, und in SEITEN-Koordinaten: die Textur
## bildet die ganze Seite ab, und dieselbe Maske trägt jeden Runen-Platz, weil der
## Shader sie nur spiegelt. Die Tönung ist ein Shader-Uniform, kein Pixel: vorher
## entstand je Kombination aus Runen und Essenz eine eigene Textur (bis zu ~30).
## Jetzt gibt es sechs Texturen im ganzen Spiel, für immer - eine je Zeichen.
##
## Kanäle (RGBA8, Datentextur - NICHT source_color, sonst zerrt die sRGB-Kurve
## Bogenlänge und Abstand krumm):
##   R  Kern - der scharfe Faden, die Strichstärke steckt schon in seiner Breite
##   G  Bogenlänge s entlang des verketteten Pfads (0..1); trägt jede Wanderung
##   B  Abstand zur Mittellinie, auf FIELD normiert (0 = Kern, 1 = Feldrand)
##   A  Deckung als Antialias-Hülle am Feldrand
##
## B ist der Grund, warum ein Ausbruch auf Übersichts-Distanz überhaupt liest: der
## Shader weitet nur das angenommene B-Band, und die LEUCHTENDE FLÄCHE wächst um
## das 2,5- bis 3,5-fache, ohne dass irgendetwas neu erzeugt wird.

## Kantenlänge der Textur - reiner Qualitätsregler, gemessen am Bake-Preis:
## alle Zeichen zusammen, einmalig beim Start. Gemessen beim KRANZ (SIZE 256):
## 12-43 ms JE ZEICHEN (der lange Umlauf-Bogen ist der teuerste), 141 ms für alle
## sechs - in derselben Größenordnung wie die alte Eckzelle bei 192 (~39 ms je
## Zeichen, 234 ms gesamt), obwohl die Fläche 1,8-mal so groß ist: das schmalere
## FIELD schrumpft jeden Segment-Kasten. Bleibt hinter dem Titelbild unsichtbar.
const SIZE := 256
## Kernbreite als Anteil der SEITENbreite bei Gewicht 1.0. Der Kranz läuft über
## die ganze Seite, also misst der Strich auch daran; 0.052 gegen die 0.036
## Seitenbreiten der alten Eckzelle - er wächst um knapp die Hälfte. Mehr geht
## nicht: die halbe Breite muss unter FIELD bleiben, sonst frisst der Kern den Hof.
const STROKE := 0.052
## Reichweite des Abstandsfelds als Anteil der Seite. Es ist zugleich der Rand,
## den Rune.GLYPH_MARGIN um jede Figur frei lässt: der Ausbruch weitet nur das
## angenommene Band INNERHALB des gebackenen Felds, also endet der Hof genau am
## Seitenrand und wird dort nie abgeschnitten.
const FIELD := 0.055
## Anteil der Linie, über den ein freies Ende schmaler wird. Ein geätzter Strich
## hat konstante Tiefe - das hier ist nur die Auslaufzone gegen einen abrupten
## Antialias-Bruch, keine Riss-Verjüngung mehr.
const TAPER_SPAN := 0.08
## Restbreite am freien Ende (Anteil der vollen Breite).
const TAPER_FLOOR := 0.82

static var _cache := {}  # glyph_id -> ImageTexture

## Maske eines Zeichens ("" oder unbekannt -> null). Gecacht je ZEICHEN, also
## nie mehr als sechs Einträge.
static func for_glyph(glyph_id: String) -> ImageTexture:
	if glyph_id == "":
		return null
	if _cache.has(glyph_id):
		return _cache[glyph_id]
	var texture := _bake(glyph_id)
	if texture != null:
		_cache[glyph_id] = texture
	return texture

## Maske zur Rune - die bequeme Form für die Anzeige.
static func for_rune(rune_id: String) -> ImageTexture:
	var rune := Rune.by_id(rune_id)
	return for_glyph(rune.glyph) if rune != null else null

## Alle sechs auf einmal backen. Der Aufrufer wählt den Moment (hinter dem
## Titelbild sind 40 ms unsichtbar), damit der erste beschriftete Würfel nicht mitten
## im Spiel für den Bake bezahlt.
static func warm() -> void:
	for glyph in Rune.all_glyphs():
		for_glyph(glyph)

static func cache_size() -> int:
	return _cache.size()

## Der Bake selbst. Kein Abstandsfeld über die ganze Fläche: das wären 256² × ~40
## Segmente ≈ 2,6 Mio. Distanzen in GDScript. Stattdessen läuft jedes Segment nur
## über seinen EIGENEN Kasten (Segment plus Feldreichweite) - dieselbe Größenordnung
## Arbeit wie das alte Punkt-Stempeln, aber mit exakten Abständen statt Treppen.
static func _bake(glyph_id: String) -> ImageTexture:
	var lines := Rune.glyph_lines(glyph_id)
	if lines.is_empty():
		return null
	var weights := Rune.glyph_weights(glyph_id)

	var lengths := PackedFloat32Array()
	var total := 0.0
	for line in lines:
		var length := 0.0
		for i in range(line.size() - 1):
			length += line[i].distance_to(line[i + 1]) * float(SIZE)
		lengths.append(length)
		total += length
	# Die Bogenlänge läuft über die ganze VERKETTETE Figur, damit jede Linie ihre
	# eigene Phase erbt und die Bewegungen die Figur entlangwandern.
	var arc_span := maxf(total, 0.001)

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
					# sich an jeder Kreuzung zwei Striche gegenseitig ihre
					# Bogenwerte, und die Bewegung zeigt dort eine Naht.
					if gap_sq >= nearest[index]:
						continue
					nearest[index] = gap_sq
					var distance := sqrt(gap_sq)
					var run := walked + t * span_length
					var along := run / maxf(line_length, 0.001)
					var arc := (before + run) / arc_span
					var half := _half_width(along, weight)
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
	# Ohne Mipmaps flimmert ein 1-px-Strich im 30-Würfel-Tray. Dass dabei auch der
	# G-Kanal gemittelt wird, ist entlang einer Linie harmlos und an Kreuzungen
	# Unsinn - vertretbar, weil auf Tray-Distanz nichts animiert.
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

## Halbe Kernbreite an der Stelle along (0..1 auf DIESER Linie). Konstant: ein
## geätzter Strich hat überall dieselbe Tiefe. Nur die freien Enden laufen ein
## Stück schmaler aus, damit der Antialias dort nicht abrupt bricht.
static func _half_width(along: float, weight: float) -> float:
	var ends := minf(smoothstep(0.0, TAPER_SPAN, along),
		smoothstep(0.0, TAPER_SPAN, 1.0 - along))
	return 0.5 * STROKE * float(SIZE) * weight * (TAPER_FLOOR + (1.0 - TAPER_FLOOR) * ends)
