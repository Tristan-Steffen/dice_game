class_name MagazinTrayDress
## Die GERÄTE der vier Magazin-Trays: jeder Tray sieht aus wie das Gerät seines
## Datenträgers - Zahl die KARTENZUFUHR (gebürstetes Metall, Führungsschienen,
## Transport-Löcher, Leuchttisch-Boden), Material das KASSETTEN-DECK (mattschwarz,
## Wickeldorne, Tonkopf-Brücke), Rune das STEINBETT (Sandstein-Wulst, Keil-Kerben,
## Lehmboden), Sonder der EINSCHUB (Backplane, Leiterbahnen, Pads, Kontaktleiste).
## Reine Bauregeln: ShelfStackView ruft sie, Maße kommen in Welt. Alles ist dunkler und
## ruhiger als die Karten, Emission bleibt unter der Bloom-Schwelle.

const ZAHL := 0
const MATERIAL := 1
const RUNE := 2
const SONDER := 3

## Die Fassung auf dem Filz: so hoch, so weit greift sie über die Lochkante (sie deckt
## die Schnittkante wie ein Kragen) und so tief reicht ihre Lippe darunter.
const FRAME_H := 0.028
const OVERHANG := 0.05
const LIP_DROP := 0.05
## Die LICHTLEISTE im unteren Band: Anteil der Bandhöhe, Höhe über dem Filz, Licht.
const BAR_SHARE := 0.7
const BAR_INSET := 0.13
const BAR_H := 0.036
const BAR_ENERGY := 0.3
const BAR_HIGHLIGHT_ENERGY := 1.1
const BAR_FONT := 64
const BAR_TEXT_SHARE := 0.62
const BAR_TEXT_LIFT := 0.003
## Die Rollschiene: Rinne und Schieber, Anteile der Schienenbreite.
const RAIL_GROOVE_SHARE := 0.42
const RAIL_THUMB_SHARE := 0.66
## Der Schieber ist ein Knopf: nie kürzer als das (Welt), mit Griffrillen.
const RAIL_THUMB_MIN := 0.34
## Die Dioden des Lochrasters: ohne Karte glimmen sie, mit ihr scheinen sie durch die Löcher.
const LAMP_OFF := Color(0.1, 0.32, 0.18)
const LAMP_DARK := 0.6
const LAMP_LIT := 2.0
const RAIL_THUMB_ENERGY := 0.95
const RAIL_THUMB_DIM := 0.32

## Je Gerät: Fassung, Grubeninneres (Platte, Lippen), Muldenboden, Wand und Saum der Grube.
const FRAME_ALBEDO: Array[Color] = [Color(0.03, 0.036, 0.042), Color(0.13, 0.13, 0.15),
	Color(0.4, 0.28, 0.17), Color(0.14, 0.14, 0.18)]
const FRAME_GLOW: Array[Color] = [Color(0.04, 0.05, 0.056), Color(0.09, 0.09, 0.105),
	Color(0.24, 0.165, 0.1), Color(0.1, 0.1, 0.13)]
const FRAME_METALLIC: Array[float] = [0.2, 0.2, 0.0, 0.1]
const FRAME_ROUGHNESS: Array[float] = [0.3, 0.5, 0.8, 0.7]
const INSIDE_ALBEDO: Array[Color] = [Color(0.03, 0.035, 0.04), Color(0.1, 0.1, 0.115),
	Color(0.36, 0.25, 0.15), Color(0.12, 0.12, 0.15)]
const INSIDE_GLOW: Array[Color] = [Color(0.055, 0.065, 0.075), Color(0.08, 0.08, 0.092),
	Color(0.36, 0.25, 0.15), Color(0.1, 0.1, 0.125)]
const INSIDE_ENERGY: Array[float] = [1.0, 1.0, 0.55, 1.0]
## Das Lochraster der Kartenzufuhr liegt auf schwarzem Glas.
const FLOOR_ALBEDO: Array[Color] = [Color(0.012, 0.016, 0.02), Color(0.05, 0.05, 0.06),
	Color(0.12, 0.08, 0.05), Color(0.36, 0.3, 0.62)]
const FLOOR_GLOW: Array[Color] = [Color(0.02, 0.028, 0.03), Color(0.045, 0.045, 0.054),
	Color(0.12, 0.08, 0.05), Color(0.36, 0.3, 0.62)]
const FLOOR_ENERGY: Array[float] = [1.0, 1.0, 0.62, 0.55]
const WALL_ALBEDO: Array[Color] = [Color(0.02, 0.024, 0.028), Color(0.03, 0.03, 0.036),
	Color(0.16, 0.11, 0.07), Color(0.04, 0.04, 0.055)]
const GLOW_COLOR: Array[Color] = [Color(0.42, 0.62, 0.5), Color(0.55, 0.32, 0.46),
	Color(0.62, 0.52, 0.26), Color(0.45, 0.4, 0.62)]

## Die Akzente: Kartenzufuhr-Schiene, Kassetten-Nabe, Stein-Einlage, Gold der Kontakte.
const STEEL := Color(0.62, 0.65, 0.68)
const HUB_WHITE := Color(0.82, 0.8, 0.78)
const CHROME := Color(0.7, 0.72, 0.76)
const GOLD := Color(0.86, 0.66, 0.28)
const TRACE := Color(0.13, 0.22, 0.18)
const NOTCH := Color(0.17, 0.12, 0.08)

static var _materials := {}

## Die Sortenfarbe eines Trays.
static func tint(column: int) -> Color:
	return PackDrawerView.COLORS.get(Pack.SHELF_ORDER[clampi(column, 0, 3)], PackDrawerView.GOLD)

static func _key(kind: String, column: int) -> String:
	return "%s%d" % [kind, column]

## Die Fassung auf dem Filz (beleuchtet von den Tischlichtern, ein Hauch Eigenlicht).
static func frame_material(column: int) -> StandardMaterial3D:
	var key := _key("frame", column)
	if not _materials.has(key):
		var c := clampi(column, 0, 3)
		_materials[key] = TableProps.metal(FRAME_ALBEDO[c], FRAME_GLOW[c], 1.0,
			FRAME_METALLIC[c], FRAME_ROUGHNESS[c])
	return _materials[key]

## Das Grubeninnere: Platte, Lippen, Rippen - in die Grube fällt kein Licht.
static func inside_material(column: int) -> StandardMaterial3D:
	var key := _key("inside", column)
	if not _materials.has(key):
		var c := clampi(column, 0, 3)
		_materials[key] = TableProps.metal(INSIDE_ALBEDO[c], INSIDE_GLOW[c], INSIDE_ENERGY[c],
			FRAME_METALLIC[c] * 0.6, FRAME_ROUGHNESS[c])
	return _materials[key]

## Der Muldenboden.
static func floor_material(column: int) -> StandardMaterial3D:
	var key := _key("floor", column)
	if not _materials.has(key):
		var c := clampi(column, 0, 3)
		var material := TableProps.metal(FLOOR_ALBEDO[c], FLOOR_GLOW[c], FLOOR_ENERGY[c],
			0.0, 1.0)
		_materials[key] = material
	return _materials[key]

## Das Licht der DIODEN eines Platzes der Kartenzufuhr: ohne Karte glimmen sie, mit ihr
## leuchten sie in ihrer Farbe durch die Löcher. Je Platz ein eigenes.
static func lamp_material(column := ZAHL) -> StandardMaterial3D:
	return TableProps.metal(lamp_off(column), lamp_off(column), LAMP_DARK, 0.0, 1.0)

## Die Ruhefarbe des Platz-Lichts: die Dioden grün, der Bandweg des Decks gedämpftes Pink.
static func lamp_off(column: int) -> Color:
	return LAMP_OFF if column == ZAHL else tint(column) * 0.45

static func write_lamp(material: StandardMaterial3D, tint_color: Color, lit: bool,
		column := ZAHL) -> void:
	var off := lamp_off(column)
	material.albedo_color = tint_color * 0.5 if lit else off
	material.emission = tint_color if lit else off
	material.emission_energy_multiplier = LAMP_LIT if lit else LAMP_DARK

## Der Stahl der Führungsschienen des Schiebers.
static func rail_steel() -> StandardMaterial3D:
	return _flat("rail_steel", STEEL, 0.14, 0.85, 0.25)

## Die Griffrillen des Schiebers.
static func grip_material() -> StandardMaterial3D:
	return _flat("rail_grip", Color(0.03, 0.03, 0.035), 0.2, 0.2, 0.7)

## Die Wand und der Lichtsaum der Grube (PackPitView).
static func wall_color(column: int) -> Color:
	return WALL_ALBEDO[clampi(column, 0, 3)]

static func glow_color(column: int) -> Color:
	return GLOW_COLOR[clampi(column, 0, 3)]

static func _flat(kind: String, color: Color, energy: float, metallic := 0.3,
		roughness := 0.5) -> StandardMaterial3D:
	if not _materials.has(kind):
		_materials[kind] = TableProps.metal(color, color, energy, metallic, roughness)
	return _materials[kind]

## Die Rinne der Rollschiene, je Gerät eine Spur dunkler als sein Inneres.
static func groove_material(column: int) -> StandardMaterial3D:
	var key := _key("groove", column)
	if not _materials.has(key):
		var c := clampi(column, 0, 3)
		_materials[key] = TableProps.metal(INSIDE_ALBEDO[c] * 0.35, INSIDE_GLOW[c] * 0.3,
			INSIDE_ENERGY[c], 0.0, 0.9)
	return _materials[key]

## Der SCHIEBER der Rollschiene: Sortenfarbe; ein eigenes Material je Tray (er dimmt).
static func thumb_material(column: int) -> StandardMaterial3D:
	var color := tint(column)
	var material := TableProps.metal(color * 0.4, color, RAIL_THUMB_ENERGY, 0.0, 0.5)
	return material

# --- Die FASSUNG ----------------------------------------------------------------

## Baut die Fassung eines Trays unter host (Mitte = Lochmitte auf dem Glas, +X Bild-oben,
## +Z Bild-rechts): hole = Lochmaß (x längs, y quer), margins = (Seite, oben, unten).
## Gibt die Lichtleiste zurück: {"bar": MeshInstance3D, "label": Label3D}.
static func build_frame(host: Node3D, column: int, hole: Vector2, margins: Vector3) -> Dictionary:
	var c := clampi(column, 0, 3)
	var material := frame_material(c)
	var inner := Rect2(-hole * 0.5 + Vector2.ONE * OVERHANG, hole - Vector2.ONE * OVERHANG * 2.0)
	var outer := Rect2(Vector2(-hole.x * 0.5 - margins.z, -hole.y * 0.5 - margins.x),
		Vector2(hole.x + margins.y + margins.z, hole.y + margins.x * 2.0))
	var rounding := 0.0
	if c == MATERIAL or c == RUNE:
		rounding = minf(margins.x, margins.y) + OVERHANG
	_ring(host, inner, outer, rounding, material)
	match c:
		ZAHL:
			_dress_feeder(host, hole, margins)
		MATERIAL:
			_dress_deck(host, hole, margins)
		RUNE:
			_dress_bed(host, hole, margins, outer)
		SONDER:
			_dress_slot(host, hole, margins, outer)
	return _build_bar(host, c, hole, margins)

## Der RING um das Loch: vier Streifen, auf Wunsch mit runden Außenecken; die Lippe
## greift unter das Glas und deckt die Schnittkante.
static func _ring(host: Node3D, inner: Rect2, outer: Rect2, rounding: float,
		material: Material) -> void:
	var y := (FRAME_H - LIP_DROP) * 0.5
	var high := FRAME_H + LIP_DROP
	var r := clampf(rounding, 0.0, minf(outer.end.x - inner.end.x, inner.position.y - outer.position.y))
	# Oben und unten über die volle Breite (ohne die runden Ecken), links und rechts dazwischen.
	TableProps.box(host, "FassungOben", Vector3(outer.end.x - inner.end.x, high,
		outer.size.y - r * 2.0), Vector3((inner.end.x + outer.end.x) * 0.5, y,
		outer.get_center().y), material)
	var low_r := clampf(rounding, 0.0, inner.position.x - outer.position.x)
	TableProps.box(host, "FassungUnten", Vector3(inner.position.x - outer.position.x, high,
		outer.size.y - low_r * 2.0), Vector3((outer.position.x + inner.position.x) * 0.5, y,
		outer.get_center().y), material)
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		var width := inner.position.y - outer.position.y
		TableProps.box(host, "FassungSeite%d" % side, Vector3(inner.size.x, high, width),
			Vector3(inner.get_center().x, y, dir * (outer.size.y * 0.5 - width * 0.5)), material)
		# Die Ecken: ein Füllstück bis zur Rundung, darauf ein Zylinder - er steht eine Spur
		# tiefer, sonst stritten zwei gleich hohe Deckflächen im Tiefenpuffer.
		for end in 2:
			var radius := r if end == 1 else low_r
			if radius <= 0.001:
				continue
			var x_edge := outer.end.x if end == 1 else outer.position.x
			var x_inner := inner.end.x if end == 1 else inner.position.x
			var sx := 1.0 if end == 1 else -1.0
			var z_edge := dir * outer.size.y * 0.5
			var fill := absf(x_edge - x_inner) - radius
			if fill > 0.001:
				TableProps.box(host, "Eckfuell%d%d" % [side, end], Vector3(fill, high, radius),
					Vector3(x_inner + sx * fill * 0.5, y, z_edge - dir * radius * 0.5), material)
			var corner := MeshInstance3D.new()
			corner.name = "Ecke%d%d" % [side, end]
			var cyl := CylinderMesh.new()
			cyl.top_radius = radius
			cyl.bottom_radius = radius
			cyl.height = high - 0.002
			cyl.radial_segments = 20
			corner.mesh = cyl
			corner.material_override = material
			corner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			corner.position = Vector3(x_edge - sx * radius, y - 0.001, z_edge - dir * radius)
			host.add_child(corner)

## Die LICHTLEISTE im unteren Band: ein leuchtender Streifen in Sortenfarbe, darauf die
## Aufschrift (ShelfStackView schreibt Text und Hervorhebung).
static func _build_bar(host: Node3D, column: int, hole: Vector2, margins: Vector3) -> Dictionary:
	var color := tint(column)
	var band := margins.z
	var high := band * BAR_SHARE
	var wide := hole.y - OVERHANG * 2.0
	# Zwischen Lochkante und Leiste bleibt ein Streifen für Schiene, Kontakte, Einlage.
	var x := -hole.x * 0.5 - BAR_INSET - high * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = color * 0.18
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = BAR_ENERGY
	material.roughness = 0.4
	var bar := TableProps.box(host, "Lichtleiste", Vector3(high, BAR_H, wide),
		Vector3(x, BAR_H * 0.5, 0.0), material)
	var label := Label3D.new()
	label.name = "Aufschrift"
	label.font_size = BAR_FONT
	# Flach auf der Leiste, die Schrift läuft Bild-rechts (Welt +Z).
	label.transform.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	label.pixel_size = high * BAR_TEXT_SHARE / (float(BAR_FONT) * 0.72)
	label.position = Vector3(x, BAR_H + BAR_TEXT_LIFT, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.outline_size = 14
	label.outline_modulate = Color(0.02, 0.02, 0.03)
	label.modulate = color.lerp(Color.WHITE, 0.7)
	label.shaded = false
	host.add_child(label)
	return {"bar": bar, "label": label, "material": material}

## Die Lochpositionen der Karte im Roh-Maß ihres Exports: 14 Spalten längs, 10 Zeilen quer.
const PUNCH_COLUMNS := 14
const PUNCH_ROWS := 10
const PUNCH_SPAN := Vector2(0.86, 1.46)
const PUNCH_FIRST := Vector2(0.42, -0.72)
const DOT_SIZE := Vector3(0.044, 0.006, 0.028)
const HAIRLINE := 0.022
const DIGIT_HIGH := 0.13

static var _dot_meshes := {}

## Wo die Lochposition (Spalte, Zeile) in der Mulde liegt: (X, Z) um die Kartenmitte.
static func punch_spot(column: int, row: int, k: float) -> Vector2:
	return Vector2(PUNCH_FIRST.x - float(row) * PUNCH_SPAN.x / float(PUNCH_ROWS - 1),
		PUNCH_FIRST.y + float(column) * PUNCH_SPAN.y / float(PUNCH_COLUMNS - 1)) * k

## Das LOCHRASTER einer Mulde: je Lochposition der Karte eine Diode auf dem schwarzen Glas
## (Knoten "Lochraster", EIN geteiltes MultiMesh, das Licht kommt je Platz).
static func build_dots(node: Node3D, floor_top: float, k: float, light: Material) -> void:
	if not _dot_meshes.has(k):
		var mesh := BoxMesh.new()
		mesh.size = DOT_SIZE * Vector3(k, 1.0, k)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = PUNCH_COLUMNS * PUNCH_ROWS
		for column in PUNCH_COLUMNS:
			for row in PUNCH_ROWS:
				var spot := punch_spot(column, row, k)
				multi.set_instance_transform(column * PUNCH_ROWS + row,
					Transform3D(Basis.IDENTITY, Vector3(spot.x, 0.0, spot.y)))
		_dot_meshes[k] = multi
	var dots := MultiMeshInstance3D.new()
	dots.name = "Lochraster"
	dots.multimesh = _dot_meshes[k]
	dots.material_override = light
	dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dots.position.y = floor_top + 0.004 + DOT_SIZE.y * 0.5
	node.add_child(dots)

## Kartenzufuhr: schwarzes Glas, eine grüne Haarlinie rings um das Loch und links die
## Zeilen-Ziffern 0-9 jeder Reihe.
static func _dress_feeder(host: Node3D, hole: Vector2, margins: Vector3) -> void:
	var line := _flat("feeder_hairline", tint(ZAHL), 0.7, 0.0, 0.5)
	var out := OVERHANG + 0.07
	var half := hole * 0.5 + Vector2.ONE * out
	var y := FRAME_H + 0.003
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		TableProps.box(host, "HaarlinieX%d" % side, Vector3(HAIRLINE, 0.006, half.y * 2.0),
			Vector3(dir * half.x, y, 0.0), line)
		TableProps.box(host, "HaarlinieZ%d" % side, Vector3(half.x * 2.0 - HAIRLINE, 0.006,
			HAIRLINE), Vector3(0.0, y, dir * half.y), line)
	var k := PackDrawerView.CASSETTE_SCALE
	var rows := PackDrawerView.PLACES
	var pitch := hole.x / float(rows)
	var z := -hole.y * 0.5 - margins.x * 0.5 + OVERHANG * 0.5 - 0.04
	for row in rows:
		var mid := hole.x * 0.5 - pitch * (float(row) + 0.5)
		for digit in PUNCH_ROWS:
			var label := Label3D.new()
			label.name = "Ziffer%d_%d" % [row, digit]
			label.text = str(digit)
			label.font_size = 48
			label.transform.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
			label.pixel_size = DIGIT_HIGH / 34.0
			label.position = Vector3(mid + punch_spot(0, digit, k).x, FRAME_H + 0.004, z)
			label.modulate = tint(ZAHL).lerp(Color.WHITE, 0.4)
			label.shaded = false
			host.add_child(label)

## Kassetten-Deck: zwei Wickeldorne mit Zähnen am oberen Rand, dazwischen die Tonkopf-Brücke.
static func _dress_deck(host: Node3D, hole: Vector2, margins: Vector3) -> void:
	var white := _flat("deck_hub", HUB_WHITE, 0.08, 0.0, 0.6)
	var dark := _flat("deck_core", Color(0.015, 0.015, 0.02), 0.3, 0.0, 0.9)
	var chrome := _flat("deck_chrome", CHROME, 0.1, 0.9, 0.2)
	var x := hole.x * 0.5 + (margins.y - OVERHANG) * 0.5
	var radius := (margins.y + OVERHANG) * 0.68
	var spread := hole.y * 0.2
	for side in 2:
		var z := (float(side) * 2.0 - 1.0) * spread
		var hub := _disc(host, "Wickeldorn%d" % side, radius, 0.012, white)
		hub.position = Vector3(x, FRAME_H + 0.006, z)
		var core := _disc(host, "Nabe%d" % side, radius * 0.45, 0.014, dark)
		core.position = Vector3(x, FRAME_H + 0.008, z)
		for tooth in 6:
			var angle := TAU * float(tooth) / 6.0
			var at := Vector3(cos(angle), 0.0, sin(angle)) * radius * 0.42
			var cog := TableProps.box(host, "Zahn%d_%d" % [side, tooth],
				Vector3(radius * 0.16, 0.016, radius * 0.16),
				Vector3(x + at.x, FRAME_H + 0.009, z + at.z), white)
			if cog != null:
				cog.rotation.y = -angle
	TableProps.box(host, "Tonkopf", Vector3(radius * 0.9, 0.01, spread * 2.0 - radius * 2.6),
		Vector3(x, FRAME_H + 0.005, 0.0), chrome)

## Steinbett: eine weich gerundete Wulst rings um das Loch, Keil-Kerben auf ihrem
## Grat und eine feine gelbe Einlage am oberen Rand.
static func _dress_bed(host: Node3D, hole: Vector2, margins: Vector3, outer: Rect2) -> void:
	var stone := frame_material(RUNE)
	var radius := minf(margins.x, margins.y) * 0.45
	var squash := 0.32
	var base := FRAME_H * 0.5
	var crest := base + radius * squash
	var inner := hole * 0.5 + Vector2.ONE * (radius - OVERHANG)
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		_bead(host, "WulstX%d" % side, Vector3(dir * inner.x, base, 0.0),
			inner.y * 2.0, radius, squash, true, stone)
		_bead(host, "WulstZ%d" % side, Vector3(0.0, base, dir * inner.y),
			inner.x * 2.0, radius, squash, false, stone)
	var notch := _flat("bed_notch", NOTCH, 0.15, 0.0, 1.0)
	var pitch := 0.55
	var count := maxi(int(outer.size.y / pitch) - 1, 1)
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		for i in count:
			var wedge := MeshInstance3D.new()
			wedge.name = "Kerbe%d_%d" % [side, i]
			var prism := PrismMesh.new()
			prism.size = Vector3(radius * 0.8, radius * 0.9, 0.004)
			wedge.mesh = prism
			wedge.material_override = notch
			# Liegend auf dem Grat, die Spitze zeigt ins Loch.
			wedge.transform.basis = Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.FORWARD,
				PI * 0.5 * (1.0 - dir))
			wedge.position = Vector3(dir * inner.x, crest + 0.002,
				(float(i) - float(count - 1) * 0.5) * pitch)
			host.add_child(wedge)
	var inlay := _flat("bed_inlay", tint(RUNE), 0.75, 0.0, 0.5)
	TableProps.box(host, "Einlage", Vector3(0.016, 0.004, hole.y),
		Vector3(hole.x * 0.5 + radius * 2.0 - OVERHANG + 0.03, FRAME_H + 0.002, 0.0), inlay)

## Einschub: Abstandsbolzen in den Ecken und eine goldene Kontaktleiste am unteren Rand.
static func _dress_slot(host: Node3D, hole: Vector2, margins: Vector3, outer: Rect2) -> void:
	var gold := _flat("slot_gold", GOLD, 0.35, 0.9, 0.3)
	var bolt := minf(margins.x, margins.y) * 0.32
	for corner in 4:
		var x := outer.end.x - margins.y * 0.5 if corner < 2 else outer.position.x + margins.x * 0.5
		var z := (outer.size.y * 0.5 - margins.x * 0.5) * (1.0 if corner % 2 == 0 else -1.0)
		var disc := _disc(host, "Bolzen%d" % corner, bolt, 0.016, gold)
		disc.position = Vector3(x, FRAME_H + 0.008, z)
	var pitch := 0.16
	var count := maxi(int((hole.y - 0.4) / pitch), 1)
	var x0 := -hole.x * 0.5 - OVERHANG - 0.03
	for i in count:
		TableProps.box(host, "Kontakt%d" % i, Vector3(0.07, 0.006, 0.07),
			Vector3(x0, FRAME_H + 0.003, (float(i) - float(count - 1) * 0.5) * pitch), gold)

static func _disc(host: Node3D, disc_name: String, radius: float, high: float,
		material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = disc_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = high
	cyl.radial_segments = 20
	node.mesh = cyl
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
	return node

## Ein liegender, flach gedrückter Rundstab (die Wulst) längs Z (along_z) oder X.
static func _bead(host: Node3D, bead_name: String, at: Vector3, length: float, radius: float,
		squash: float, along_z: bool, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = bead_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 16
	node.mesh = cyl
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var turn := Basis(Vector3.RIGHT, PI * 0.5) if along_z else Basis(Vector3.FORWARD, PI * 0.5)
	node.transform = Transform3D(Basis.from_scale(Vector3(1.0, squash, 1.0)) * turn, at)
	host.add_child(node)

# --- Die ACHSEN des Umlaufs -------------------------------------------------------

## Die blanke Welle: heller als die Führungsschienen, sie liest im dunklen Schacht.
static func axle_steel() -> StandardMaterial3D:
	return _flat("axle_steel", STEEL, 0.55, 0.85, 0.25)

## Kettenräder im Inneren des Geräts, eine Spur heller - in den Schacht fällt kein Licht.
static func axle_material(column: int) -> StandardMaterial3D:
	var key := _key("axle", column)
	if not _materials.has(key):
		var c := clampi(column, 0, 3)
		_materials[key] = TableProps.metal(INSIDE_ALBEDO[c] * 1.4 + Color(0.04, 0.04, 0.045),
			INSIDE_GLOW[c] * 1.6, INSIDE_ENERGY[c], 0.5, 0.35)
	return _materials[key]

## Eine ACHSE quer über den Tray: die Welle längs Z und Kettenräder an den genannten z, alle
## an EINEM Knoten "Rad", der um Z dreht. Gibt ihn zurück.
static func build_axle(host: Node3D, column: int, length: float, shaft_r: float,
		wheel_r: float, wheel_w: float, wheels: PackedFloat32Array, teeth: int) -> Node3D:
	var turn := Node3D.new()
	turn.name = "Rad"
	host.add_child(turn)
	var shaft := _disc(turn, "Welle", shaft_r, length, axle_steel())
	shaft.rotation.x = PI * 0.5
	var metal := axle_material(column)
	var tooth := Vector3(wheel_r * 0.3, wheel_r * 0.28, wheel_w)
	for i in wheels.size():
		var disc := _disc(turn, "Kettenrad%d" % i, wheel_r * 0.86, wheel_w, metal)
		disc.rotation.x = PI * 0.5
		disc.position.z = wheels[i]
		for k in teeth:
			var a := TAU * float(k) / float(teeth)
			var box := TableProps.box(turn, "Zahn%d_%d" % [i, k], tooth,
				Vector3(cos(a) * wheel_r * 0.88, sin(a) * wheel_r * 0.88, wheels[i]), metal)
			if box != null:
				box.rotation.z = a
	return turn

# --- Die MULDEN -----------------------------------------------------------------

## Was ein Gerät in eine leere Mulde legt (unter der Karte, nie über ihr): seine Halterung. bay = (Welt-X, Welt-Z), y = 0 ist der
## Muldenboden.
static func dress_bay(node: Node3D, column: int, bay: Vector2, floor_top: float,
		under_card: float, cell_scale := 0.0, light: Material = null) -> void:
	var high := minf(0.02, under_card - floor_top - 0.006)
	if high <= 0.002:
		return
	if cell_scale > 0.0:
		build_holder(node, column, bay, floor_top, under_card, cell_scale, light)

# --- Die HALTERUNG ---------------------------------------------------------------

## Maße der Träger im Roh-Maß ihres Exports (tools/blender_data_media_export.py):
## Nabe längs/quer und ihr Radius, Capstan-Loch längs/quer, Eckschnitt der Lochkarte,
## Eckradius der Tafel, Kontaktleiste des Moduls (Mitte längs, Teilung).
const CARD_HALF := Vector2(0.54, 0.81)
const HUB := Vector3(0.52, 0.3216, 0.135)
const CAPSTAN := Vector2(0.47, -0.4)
## Der Radius eines Spulentellers der Studiospule (Roh-Maß).
const REEL := 0.23
## Der Korb der Tafeln: Kette, Schuß, Teilung des Geflechts, Stärke des Rands, das Etikett.
const BASKET_WARP := Color(0.62, 0.47, 0.27)
const BASKET_WEFT := Color(0.5, 0.36, 0.2)
const WEAVE_PITCH := 0.4
const BASKET_RIM := 0.055
const CLAY_TAG := Color(0.62, 0.36, 0.22)
## Die ESD-Matte der Module: Rasterlinie, Lagewinkel, Teilung des Rasters (längs, quer).
const ESD_GRID := Color(0.56, 0.5, 0.86)
const ESD_MARK := Color(0.92, 0.9, 1.0)
const ESD_PITCH := Vector2(0.52, 0.6)
const PUNCH_CUT := 0.156
const CLAY_ROUND := 0.15
const CONTACT := Vector2(0.7635, 0.085)
## So viel Luft bleibt zwischen Karte und einem Anschlag daneben.
const HOLD_GAP := 0.014
const HOLD_WALL := 0.024

## Was die Karte in ihrer Mulde HÄLT, je Datenträger ein eigener Mechanismus (Knoten
## "Halterung"): Lochkarte - Auflageschienen, Eckwinkel und der Schräganschlag ihrer
## gekappten Ecke; Kassette - zwei gezahnte Wickeldorne auf großen Spulentellern, Capstan-Stifte
## und der Bandweg als Lichtlinie; Tafel - ein geflochtener Korb mit Rand und Ton-Etikett; Modul - die ESD-Matte mit Raster,
## Lagewinkeln und Erdungsknopf. Lokal +X = Karten-quer zum
## Fenster hin, +Z = Kartenfuß; seat ist die Unterseite der Karte. rib_parts: Lampe und
## Etikett auf der Rippe daneben (die Walze hat keine).
static func build_holder(node: Node3D, column: int, bay: Vector2, floor_top: float,
		seat: float, k: float, light: Material = null, rib_parts := true) -> Node3D:
	var c := clampi(column, 0, 3)
	var hold := Node3D.new()
	hold.name = "Halterung"
	node.add_child(hold)
	var half := CARD_HALF * k
	var thick: float = DataCellView.CARRIER_TOPS[c] * k
	var rest := seat - floor_top
	# Der Platz neben der Karte bis zur Wandauskleidung.
	var room := Vector2(bay.x * 0.5 - half.x, bay.y * 0.5 - half.y) \
		- Vector2.ONE * (HOLD_WALL + HOLD_GAP)
	var stop := Vector2(clampf(room.x, 0.02, 0.07), clampf(room.y, 0.02, 0.09))
	match c:
		ZAHL:
			_hold_punch(hold, half, thick, floor_top, rest, stop, k)
		MATERIAL:
			_hold_cassette(hold, thick, floor_top, rest, k, light)
			if light != null and rib_parts:
				# Die Aufnahme-Lampe auf der Rippe unter dem Platz meldet die Kassette.
				TableProps.box(node, "Aufnahme", Vector3(0.05, 0.006, 0.1 * k),
					Vector3(-bay.x * 0.5 - 0.035, seat + DataCellView.DEPTH * k + 0.003,
						-bay.y * 0.4), light)
		RUNE:
			_hold_clay(hold, bay, floor_top, rest, thick)
			if not rib_parts:
				return hold
			# Das Ton-Etikett auf der Rippe unter dem Platz; sein Zeichen leuchtet belegt.
			var deck := seat + DataCellView.DEPTH * k
			var tag_x := -bay.x * 0.5 - 0.038
			TableProps.box(node, "Etikett", Vector3(0.07, 0.02, 0.22 * k),
				Vector3(tag_x, deck + 0.01, 0.0), _flat("hold_clay_tag", CLAY_TAG, 0.5, 0.0, 0.95))
			if light != null:
				TableProps.box(node, "Aufnahme", Vector3(0.045, 0.006, 0.11 * k),
					Vector3(tag_x, deck + 0.023, 0.0), light)
		SONDER:
			_hold_module(hold, bay, half, floor_top)
			if light != null and rib_parts:
				TableProps.box(node, "Aufnahme", Vector3(0.05, 0.006, 0.28 * k),
					Vector3(-bay.x * 0.5 - 0.038, seat + DataCellView.DEPTH * k + 0.003, 0.0), light)
	return hold

static func _hold_punch(hold: Node3D, half: Vector2, thick: float, floor_top: float,
		rest: float, stop: Vector2, k: float) -> void:
	var steel := _flat("hold_punch_glass", Color(0.05, 0.06, 0.068), 1.0, 0.2, 0.3)
	var key := _flat("hold_punch_key", tint(ZAHL), 0.7, 0.0, 0.5)
	var rail := 0.03 * k
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		TableProps.box(hold, "Auflage%d" % side, Vector3(rail, rest, half.y * 1.84),
			Vector3(dir * (half.x - rail * 0.5), floor_top + rest * 0.5, 0.0), steel)
	var high := rest + thick
	var arm := 0.1 * k
	for corner in 4:
		var sx := 1.0 if corner < 2 else -1.0
		var sz := 1.0 if corner % 2 == 0 else -1.0
		if sx > 0.0 and sz < 0.0:
			continue
		var edge := Vector3(sx * (half.x + HOLD_GAP), floor_top + high * 0.5,
			sz * (half.y + HOLD_GAP))
		TableProps.box(hold, "WinkelX%d" % corner, Vector3(stop.x, high, arm + stop.y),
			edge + Vector3(sx * stop.x * 0.5, 0.0, -sz * (arm - stop.y) * 0.5), steel)
		TableProps.box(hold, "WinkelZ%d" % corner, Vector3(arm, high, stop.y),
			edge + Vector3(-sx * arm * 0.5, 0.0, sz * stop.y * 0.5), steel)
	# Der SCHRÄGANSCHLAG füllt die gekappte Ecke: nur richtig herum liegt die Karte. Er bleibt
	# im Umriß der Karte und unter ihrer Oberkante - an der Wand hat er nichts verloren.
	var leg := PUNCH_CUT * k - HOLD_GAP * sqrt(2.0)
	var corner := Vector2(half.x, -half.y)
	_wedge(hold, "Schraeganschlag", [corner, corner + Vector2(-leg, 0.0),
		corner + Vector2(0.0, leg)], floor_top, floor_top + rest + thick, key)

## Ein dreieckiges Prisma: points in (X, Z), von y0 bis y1.
static func _wedge(host: Node3D, wedge_name: String, points: Array, y0: float, y1: float,
		material: Material) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Array[Vector3] = []
	var low: Array[Vector3] = []
	for point: Vector2 in points:
		top.append(Vector3(point.x, y1, point.y))
		low.append(Vector3(point.x, y0, point.y))
	for face: Array in [[top[0], top[1], top[2]], [top[0], top[2], top[1]]]:
		for vertex: Vector3 in face:
			tool.add_vertex(vertex)
	for i in 3:
		var n := (i + 1) % 3
		for vertex: Vector3 in [top[i], low[i], low[n], top[i], low[n], top[n],
				top[i], low[n], low[i], top[i], top[n], low[n]]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.name = wedge_name
	node.mesh = tool.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
	return node

## Die STUDIOSPULE (Spieler-Wahl 2026-11-22): große Aluminium-Teller mit drei Ausschnitten um
## die Dorne, der Bandweg läuft als Lichtlinie über die beiden Umlenkrollen.
static func _hold_cassette(hold: Node3D, thick: float, floor_top: float, rest: float,
		k: float, light: Material = null) -> void:
	var white := _flat("hold_hub", HUB_WHITE, 0.5, 0.0, 0.6)
	var alu := _flat("hold_reel", Color(0.6, 0.61, 0.63), 0.4, 0.6, 0.25)
	var cut := _flat("hold_reel_cut", Color(0.02, 0.02, 0.025), 0.8, 0.0, 0.8)
	var core := _flat("hold_deck_ring", tint(MATERIAL) * 0.6, 0.8, 0.0, 0.6)
	var path: Material = light if light != null else core
	var radius := HUB.z * k
	var high := rest + thick * 0.72
	for side in 2:
		var at := Vector3(HUB.y * k, floor_top, (float(side) * 2.0 - 1.0) * HUB.x * k)
		var reel := _disc(hold, "Spulenteller%d" % side, REEL * k, 0.02, alu)
		reel.position = at + Vector3(0.0, 0.01, 0.0)
		for i in 3:
			var a := TAU * float(i) / 3.0 + 0.5
			var hole := _disc(hold, "Ausschnitt%d_%d" % [side, i], REEL * k * 0.27, 0.004, cut)
			hole.position = at + Vector3(cos(a), 0.0, sin(a)) * REEL * k * 0.6 \
				+ Vector3(0.0, 0.022, 0.0)
		var plate := _disc(hold, "Teller%d" % side, radius * 0.6, rest, core)
		plate.position = at + Vector3(0.0, rest * 0.5, 0.0)
		var spindle := _disc(hold, "Wickeldorn%d" % side, radius * 0.27, high, white)
		spindle.position = at + Vector3(0.0, high * 0.5, 0.0)
		for tooth in 6:
			var angle := TAU * float(tooth) / 6.0
			var fin := TableProps.box(hold, "Zahn%d_%d" % [side, tooth],
				Vector3(radius * 0.26, high - rest - 0.01, radius * 0.13),
				at + Vector3(cos(angle), 0.0, sin(angle)) * radius * 0.37
					+ Vector3(0.0, rest + (high - rest - 0.01) * 0.5, 0.0), white)
			if fin != null:
				fin.rotation.y = -angle
		var dir := float(side) * 2.0 - 1.0
		var pin := _disc(hold, "Capstan%d" % side, 0.03 * k, rest + thick * 0.5, alu)
		pin.position = Vector3(CAPSTAN.y * k, floor_top + (rest + thick * 0.5) * 0.5,
			dir * CAPSTAN.x * k)
		var run := TableProps.box(hold, "Bandweg%d" % side, Vector3(0.625 * k, 0.008, 0.01 * k),
			Vector3(-0.0625 * k, floor_top + 0.006, dir * 0.647 * k), path)
		if run != null:
			run.rotation.y = dir * 0.33
	TableProps.box(hold, "BandwegKopf", Vector3(0.01 * k, 0.008, CAPSTAN.x * 2.0 * k),
		Vector3((CAPSTAN.y - 0.044) * k, floor_top + 0.006, 0.0), path)

## Der KORB (Spieler-Wahl 2026-11-22): ein geflochtener Boden aus Kette und Schuß in zwei
## Tönen, darüber der Korbrand rings um die Tafel.
static func _hold_clay(hold: Node3D, bay: Vector2, floor_top: float, rest: float,
		thick: float) -> void:
	var warp := _flat("hold_basket_warp", BASKET_WARP, 0.4, 0.0, 0.9)
	var weft := _flat("hold_basket_weft", BASKET_WEFT, 0.4, 0.0, 0.9)
	var strand := minf(0.02, rest * 0.4)
	var inner := bay - Vector2.ONE * 0.2
	var across := maxi(int(inner.x / WEAVE_PITCH), 1)
	for i in across:
		TableProps.box(hold, "Kette%d" % i, Vector3(WEAVE_PITCH * 0.72, strand, inner.y),
			Vector3((float(i) - float(across - 1) * 0.5) * WEAVE_PITCH,
				floor_top + 0.002 + strand, 0.0), warp)
	var along := maxi(int(inner.y / WEAVE_PITCH), 1)
	for i in along:
		# Der Schuß läuft abwechselnd über und unter der Kette.
		var over := 1.6 if i % 2 == 0 else 0.4
		TableProps.box(hold, "Schuss%d" % i, Vector3(inner.x, strand, WEAVE_PITCH * 0.7),
			Vector3(0.0, floor_top + 0.002 + strand * over,
				(float(i) - float(along - 1) * 0.5) * WEAVE_PITCH), weft)
	var rim_y := rest + thick * 0.62
	var half := bay * 0.5 - Vector2.ONE * 0.02
	for side in 2:
		var dir := float(side) * 2.0 - 1.0
		TableProps.box(hold, "RandX%d" % side, Vector3(BASKET_RIM, BASKET_RIM, half.y * 2.0),
			Vector3(dir * (half.x - BASKET_RIM * 0.5), floor_top + rim_y, 0.0), warp)
		TableProps.box(hold, "RandZ%d" % side, Vector3(half.x * 2.0 - BASKET_RIM * 2.0, BASKET_RIM,
			BASKET_RIM), Vector3(0.0, floor_top + rim_y, dir * (half.y - BASKET_RIM * 0.5)), warp)

## Die ESD-MATTE (Spieler-Wahl 2026-11-22): der Muldenboden ist die lila Antistatik-Matte,
## darauf ein grobes Raster, Lagewinkel an den Ecken der Platine und der Erdungsknopf.
static func _hold_module(hold: Node3D, bay: Vector2, half: Vector2, floor_top: float) -> void:
	var grid := _flat("hold_esd_grid", ESD_GRID, 0.7, 0.0, 1.0)
	var mark := _flat("hold_esd_mark", ESD_MARK, 0.8, 0.0, 1.0)
	var y := floor_top + 0.004
	var inner := bay - Vector2.ONE * 0.2
	var across := int(inner.x * 0.5 / ESD_PITCH.x)
	for i in range(-across, across + 1):
		TableProps.box(hold, "RasterZ%d" % (i + across), Vector3(0.022, 0.004, inner.y),
			Vector3(float(i) * ESD_PITCH.x, y, 0.0), grid)
	var along := int(inner.y * 0.5 / ESD_PITCH.y)
	for i in range(-along, along + 1):
		TableProps.box(hold, "RasterX%d" % (i + along), Vector3(inner.x, 0.004, 0.022),
			Vector3(0.0, y, float(i) * ESD_PITCH.y), grid)
	for corner in 4:
		var sx := 1.0 if corner < 2 else -1.0
		var sz := 1.0 if corner % 2 == 0 else -1.0
		TableProps.box(hold, "LagewinkelZ%d" % corner, Vector3(0.5, 0.006, 0.05),
			Vector3(sx * (half.x - 0.2), y + 0.004, sz * half.y), mark)
		TableProps.box(hold, "LagewinkelX%d" % corner, Vector3(0.05, 0.006, 0.5),
			Vector3(sx * (half.x + 0.02), y + 0.004, sz * (half.y - 0.25)), mark)
	var at := Vector3(-half.x + 0.3, 0.0, -half.y + 0.3)
	var snap := _disc(hold, "Erdungsknopf", 0.13, 0.03, _flat("hold_chrome", CHROME, 0.5, 0.8, 0.25))
	snap.position = at + Vector3(0.0, floor_top + 0.015, 0.0)
	var eye := _disc(hold, "Erdungsauge", 0.06, 0.034, _flat("hold_esd_eye", Color(0.05, 0.05, 0.06),
		0.5, 0.0, 0.8))
	eye.position = at + Vector3(0.0, floor_top + 0.017, 0.0)
