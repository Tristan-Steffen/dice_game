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
const LAMP_OFF := Color(0.06, 0.1, 0.075)
const LAMP_DARK := 0.25
const LAMP_LIT := 1.2
const RAIL_THUMB_ENERGY := 0.95
const RAIL_THUMB_DIM := 0.32

## Je Gerät: Fassung, Grubeninneres (Platte, Lippen), Muldenboden, Wand und Saum der Grube.
const FRAME_ALBEDO: Array[Color] = [Color(0.5, 0.52, 0.54), Color(0.035, 0.035, 0.04),
	Color(0.55, 0.44, 0.3), Color(0.025, 0.04, 0.034)]
const FRAME_GLOW: Array[Color] = [Color(0.26, 0.275, 0.29), Color(0.045, 0.045, 0.054),
	Color(0.3, 0.235, 0.155), Color(0.025, 0.045, 0.036)]
const FRAME_METALLIC: Array[float] = [0.35, 0.0, 0.0, 0.1]
const FRAME_ROUGHNESS: Array[float] = [0.34, 0.82, 0.96, 0.7]
const INSIDE_ALBEDO: Array[Color] = [Color(0.2, 0.21, 0.225), Color(0.04, 0.04, 0.046),
	Color(0.36, 0.28, 0.19), Color(0.022, 0.036, 0.03)]
const INSIDE_GLOW: Array[Color] = [Color(0.36, 0.38, 0.41), Color(0.085, 0.082, 0.1),
	Color(0.4, 0.31, 0.21), Color(0.05, 0.085, 0.068)]
const INSIDE_ENERGY: Array[float] = [0.5, 1.0, 0.55, 1.0]
## Der Leuchttisch der Kartenzufuhr: matt, grünlich-weiß - er scheint durch die Löcher.
const FLOOR_ALBEDO: Array[Color] = [Color(0.72, 0.82, 0.75), Color(0.05, 0.048, 0.058),
	Color(0.3, 0.225, 0.15), Color(0.02, 0.05, 0.036)]
const FLOOR_GLOW: Array[Color] = [Color(0.8, 0.95, 0.84), Color(0.09, 0.085, 0.11),
	Color(0.33, 0.245, 0.16), Color(0.04, 0.095, 0.07)]
const FLOOR_ENERGY: Array[float] = [0.42, 1.0, 0.62, 1.0]
const WALL_ALBEDO: Array[Color] = [Color(0.11, 0.115, 0.125), Color(0.03, 0.03, 0.036),
	Color(0.2, 0.155, 0.105), Color(0.02, 0.034, 0.028)]
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

## Der Muldenboden; bei der Kartenzufuhr der Leuchttisch.
static func floor_material(column: int) -> StandardMaterial3D:
	var key := _key("floor", column)
	if not _materials.has(key):
		var c := clampi(column, 0, 3)
		var material := TableProps.metal(FLOOR_ALBEDO[c], FLOOR_GLOW[c], FLOOR_ENERGY[c],
			0.0, 1.0)
		_materials[key] = material
	return _materials[key]

## Der LEUCHTTISCH eines Platzes der Kartenzufuhr: dunkel ohne Karte, mit ihr leuchtet er
## in ihrer Farbe durch die Löcher (wie der Sockel der Walze). Je Platz ein eigenes.
static func lamp_material() -> StandardMaterial3D:
	return TableProps.metal(LAMP_OFF, LAMP_OFF, LAMP_DARK, 0.0, 1.0)

static func write_lamp(material: StandardMaterial3D, tint: Color, lit: bool) -> void:
	material.albedo_color = tint * 0.5 if lit else LAMP_OFF
	material.emission = tint if lit else LAMP_OFF
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

## Kartenzufuhr: zwei Führungsschienen oben und unten, links die Transport-Löcher.
static func _dress_feeder(host: Node3D, hole: Vector2, margins: Vector3) -> void:
	var steel := _flat("feeder_steel", STEEL, 0.12, 0.85, 0.25)
	var span := hole.y + margins.x * 2.0 - 0.1
	var top_x := hole.x * 0.5 + (margins.y - OVERHANG) * 0.5
	var bottom_x := -hole.x * 0.5 - OVERHANG * 0.5 - 0.06
	for pair: Array in [["SchieneOben", top_x], ["SchieneUnten", bottom_x]]:
		TableProps.box(host, pair[0], Vector3(0.05, 0.016, span),
			Vector3(pair[1], FRAME_H + 0.008, 0.0), steel)
	var dark := _flat("feeder_hole", Color(0.02, 0.025, 0.022), 0.4, 0.0, 1.0)
	var lane_z := -hole.y * 0.5 - margins.x * 0.5 + OVERHANG * 0.5
	var pitch := 0.42
	var count := maxi(int((hole.x - 0.2) / pitch), 1)
	for i in count:
		var dot := MeshInstance3D.new()
		dot.name = "Transportloch%d" % i
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = 0.004
		cyl.radial_segments = 12
		dot.mesh = cyl
		dot.material_override = dark
		dot.position = Vector3((float(i) - float(count - 1) * 0.5) * pitch, FRAME_H + 0.002, lane_z)
		host.add_child(dot)

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

# --- Die MULDEN -----------------------------------------------------------------

## Was ein Gerät in eine leere Mulde legt (unter der Karte, nie über ihr): Dorn-Stummel
## im Deck, Pad-Feld und Leiterbahnen im Einschub. bay = (Welt-X, Welt-Z), y = 0 ist der
## Muldenboden.
static func dress_bay(node: Node3D, column: int, bay: Vector2, floor_top: float,
		under_card: float) -> void:
	var high := minf(0.02, under_card - floor_top - 0.006)
	if high <= 0.002:
		return
	match clampi(column, 0, 3):
		MATERIAL:
			var stub := _flat("deck_stub", Color(0.3, 0.29, 0.3), 0.18, 0.2, 0.6)
			for side in 2:
				var disc := _disc(node, "Dorn%d" % side, bay.x * 0.11, high, stub)
				disc.position = Vector3(0.0, floor_top + high * 0.5,
					(float(side) * 2.0 - 1.0) * bay.y * 0.2)
		SONDER:
			var trace := _flat("slot_trace", TRACE, 0.9, 0.0, 0.9)
			var pad := _flat("slot_pad", GOLD * 0.7, 0.25, 0.8, 0.4)
			var thin := high * 0.4
			for i in 3:
				var x := (float(i) - 1.0) * bay.x * 0.24
				TableProps.box(node, "Bahn%d" % i, Vector3(0.022, thin, bay.y * 0.62),
					Vector3(x, floor_top + thin * 0.5, -bay.y * 0.08), trace)
			for row in 3:
				for col in 2:
					TableProps.box(node, "Pad%d%d" % [row, col], Vector3(0.09, thin, 0.09),
						Vector3((float(row) - 1.0) * bay.x * 0.24, floor_top + thin * 0.5,
							bay.y * 0.3 + float(col) * 0.13), pad)
