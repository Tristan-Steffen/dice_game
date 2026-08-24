class_name BetPrizeView
extends Node3D
## Der Körper eines Nebenwetten-GEWINNS, der keine Kassette ist:
## ein Chip-Stapel (Geld), ein Stück Kondensator-Bank (Energie), eine geprägte
## MARKE (Chipstufe, Press-Schub) oder die ZÄHLPLATTE einer Steuerwette, auf die
## je Buchung ein Chip nachspringt. Rein per Code gebaut wie alles auf dem Tisch -
## kein .tscn, kein Panel darunter.
## Er ist reine ANZEIGE: keine Buchung hängt an ihm, er zeigt nur, was auf dem
## Tresen liegt.
## Er liegt in ECHTER Größe da - Chips in Schatz-Stückelung, Elkos im Bank-Maß,
## Marke und Platte wie gebaut - und darf dabei über seinen Stellplatz hinausragen.
## Nichts schrumpft mehr auf einen Platz; der SCHACHT mißt an ihm, nicht er am Loch.
## Drei Tischregeln: er steht FLOOR_CLEAR über der Fläche (sonst kämpfen Unterseite
## und Anzeige im Tiefenpuffer), er spiegelt nicht (ein Körper AUF dem Glas spiegelte
## als grauer Schleier neben sich) und er trägt nur Emission - die Bodenkacheln
## vertragen 16 Lichter.

const KIND_NONE := ""
const KIND_CHIPS := "chips"
const KIND_CHARGE := "charge"
const KIND_TOKEN := "token"
const KIND_TALLY := "tally"

## Luft zwischen Unterseite und Anzeige - dasselbe Maß wie in einer Bucht.
const FLOOR_CLEAR := VitrineView.FLOOR_CLEAR

## Der Energie-Preis ist ein Stück Bank: höchstens so viele Spalten, dann wächst
## das Raster in die Tiefe. Mehr als ELKO_CAP Dosen zeigt keiner - die Zahl steht
## auf dem Knopf, der Körper sagt nur, WAS es ist.
const ELKO_COLS := 4
const ELKO_CAP := 16

## Die geprägte MARKE: eine flache runde Platte mit vertiefter Aufschrift.
const TOKEN_RADIUS := DataCellView.WIDTH * 0.5
const TOKEN_HEIGHT := DataCellView.DEPTH * 1.6
const TOKEN_RIM := TOKEN_RADIUS * 0.18
const TOKEN_FONT := 64
const TOKEN_INK := Color(0.05, 0.045, 0.08)

## Die ZÄHLPLATTE: dunkles Blech mit leuchtender Kante, auf dem die Steuer-Chips
## auflaufen. Sie liegt leer da, solange nichts gebucht ist - das IST die Aussage.
const PLATE_SIZE := Vector2(DataCellView.WIDTH * 1.15, DataCellView.WIDTH * 1.15)
const PLATE_HEIGHT := DataCellView.DEPTH * 0.9
const PLATE_RIM := DataCellView.WIDTH * 0.06
const PLATE_ALBEDO := Color(0.075, 0.072, 0.105)
## Anteil der Plattenbreite, den EIN Zähl-Chip einnimmt.
const TALLY_CHIP_SHARE := 0.30

const RIM_ENERGY := 1.25
const TOKEN_ENERGY := 1.05

## Griff: der Körper hebt sich ein Stück und leuchtet auf - die Magazin-Geste.
const HOVER_LIFT := DataCellView.HOVER_LIFT * 0.5
const HOVER_TIME := 0.16
const HOVER_ENERGY := 1.7

const MATERIALIZE_FROM := 0.12
const MATERIALIZE_TIME := 0.26
const FLARE_ENERGY := 2.6
const FLARE_TIME := 0.45

var kind: String = KIND_NONE

## Alles Sichtbare hängt hier drunter: der Halter trägt die Bodenfreiheit und den
## Griff-Hub, ohne den Ursprung zu verschieben - die Hebebühne fährt den URSPRUNG,
## und der muss der Stellplatz bleiben.
var _body: Node3D
var _chips: ChipStackView
## Was zuletzt gebaut wurde, in echten Weltmaßen: x = Welt-X, y = Welt-Z.
var _natural := Vector2.ONE
var _natural_height := 1.0
var _hovered := false
var _hover_tween: Tween
var _flare_tween: Tween
var _scale_tween: Tween
## Alle Leuchtmaterialien dieses Körpers - Griff und Ausbruch fassen sie zusammen.
var _lit: Array[StandardMaterial3D] = []
var _lit_rest: Array[float] = []

func _init(prize_name := "BetPrize") -> void:
	name = prize_name

# --- Der Fußabdruck, ohne zu bauen ----------------------------------------------
# Sitz und Loch werden gemessen, bevor der Körper existiert - also gibt es EINE
# Rechnung, und der gebaute Körper meldet genau sie.

## Wie viele Elko-Dosen ein Energie-Preis wirklich zeigt (die Zahl steht auf dem
## Knopf, der Körper sagt nur, WAS es ist).
static func charge_cells(count: int) -> int:
	return clampi(count, 1, ELKO_CAP)

## Die Rasterform des Elko-Feldes: x = Spalten, y = Reihen.
static func charge_grid(count: int) -> Vector2i:
	var shown := charge_cells(count)
	var cols := mini(shown, ELKO_COLS)
	@warning_ignore("integer_division")
	var rows := (shown + cols - 1) / cols
	return Vector2i(cols, rows)

## Der Fußabdruck EINER Bauform in Welt-Maßen (x = Welt-X, y = Welt-Z), ohne sie zu
## bauen. amount ist der Betrag (chips) bzw. die Stückzahl (charge).
static func span_for(build_kind: String, amount: int = 0) -> Vector2:
	match build_kind:
		KIND_CHIPS:
			return ChipStackView.pile_span(amount)
		KIND_CHARGE:
			var grid := charge_grid(amount)
			var cell := CapacitorBankView.loose_cell_size()
			return Vector2(float(grid.y - 1) * CapacitorBankView.ROW_PITCH + cell.x,
				float(grid.x - 1) * CapacitorBankView.CELL_PITCH + cell.y)
		KIND_TOKEN:
			return Vector2(TOKEN_RADIUS * 2.0, TOKEN_RADIUS * 2.0)
		KIND_TALLY:
			return PLATE_SIZE
	return Vector2.ZERO

# --- Die vier Bauformen ---------------------------------------------------------

## Geld: echte Stückelungen, dieselbe Börsen-Grammatik wie der Schatz. Kein Akzent -
## ein Chip trägt die Farbe seiner Stückelung, nicht die seiner Wette.
func setup_chips(amount: int) -> void:
	_reset(KIND_CHIPS)
	_chips = ChipStackView.new()
	_chips.name = "Chips"
	_body.add_child(_chips)
	_chips.seed_wallet(maxi(amount, 0))
	_natural = span_for(KIND_CHIPS, amount)
	_natural_height = _chips_height()

## Energie: ein Stück der Kondensator-Bank - dieselben Elkos, nur ohne Platine, und
## darum ebenfalls ohne eigenen Akzent.
func setup_charge(count: int) -> void:
	_reset(KIND_CHARGE)
	var shown := charge_cells(count)
	var grid := charge_grid(count)
	var cols := grid.x
	var rows := grid.y
	var pitch_z := CapacitorBankView.CELL_PITCH
	var pitch_x := CapacitorBankView.ROW_PITCH
	for i in shown:
		@warning_ignore("integer_division")
		var row := i / cols
		var col := i % cols
		var cell := CapacitorBankView.build_loose_cell(true)
		cell.position += Vector3(
			(float(row) - float(rows - 1) * 0.5) * pitch_x, 0.0,
			(float(col) - float(cols - 1) * 0.5) * pitch_z)
		_body.add_child(cell)
	_natural = span_for(KIND_CHARGE, count)
	_natural_height = CapacitorBankView.loose_cell_height()

## Die geprägte MARKE für die Einzelstücke, die weder Ware noch Geld sind
## (Chipstufe, Press-Schub): eine flache Platte mit ihrer Aufschrift.
func setup_token(text: String, accent: Color) -> void:
	_reset(KIND_TOKEN)
	var plate := _cylinder("Marke", TOKEN_RADIUS, TOKEN_HEIGHT,
		_lit_material(accent, TOKEN_ENERGY))
	plate.position.y = TOKEN_HEIGHT * 0.5
	_body.add_child(plate)
	# Die vertiefte Fläche: ein dunkler Spiegel im Ring, damit die Marke geprägt
	# und nicht bemalt aussieht.
	var face := _cylinder("Feld", TOKEN_RADIUS - TOKEN_RIM, TOKEN_HEIGHT * 0.55,
		_dark_material(accent))
	face.position.y = TOKEN_HEIGHT * 0.75
	_body.add_child(face)
	var label := Label3D.new()
	label.name = "Aufschrift"
	label.text = text
	label.font_size = TOKEN_FONT
	# Die Aufschrift füllt die vertiefte Fläche: geschätzte Textbreite in Schrift-
	# pixeln auf ihre Weltbreite gerechnet.
	label.pixel_size = (TOKEN_RADIUS * 1.5) \
		/ maxf(float(text.length()) * float(TOKEN_FONT) * 0.6, 1.0)
	# Flach auf der Marke und in TISCH-Leserichtung: der Text läuft entlang Welt +Z
	# (Bildschirm rechts), seine Oberkante zeigt nach Welt +X (Bildschirm oben).
	label.transform.basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	# Über der vertieften Fläche, sonst steckt die Aufschrift in ihr.
	label.position.y = TOKEN_HEIGHT * 1.12
	label.modulate = Color(accent.r * 1.4 + 0.25, accent.g * 1.4 + 0.25, accent.b * 1.4 + 0.25)
	label.outline_modulate = TOKEN_INK
	label.outline_size = 12
	_body.add_child(label)
	_natural = span_for(KIND_TOKEN)
	_natural_height = TOKEN_HEIGHT * 1.1

## Die ZÄHLPLATTE einer Steuerwette: leer, bis die erste Hand gebucht ist.
func setup_tally(accent: Color = CasinoStyle.GOLD_INTENSE) -> void:
	_reset(KIND_TALLY)
	var plate := _box("Platte", Vector3(PLATE_SIZE.x, PLATE_HEIGHT, PLATE_SIZE.y),
		Vector3(0.0, PLATE_HEIGHT * 0.5, 0.0), _plate_material())
	_body.add_child(plate)
	var rim := _lit_material(accent, RIM_ENERGY)
	var rim_y := PLATE_HEIGHT * 1.05
	for side: float in [-1.0, 1.0]:
		_body.add_child(_box("RandX", Vector3(PLATE_SIZE.x, PLATE_HEIGHT * 0.5, PLATE_RIM),
			Vector3(0.0, rim_y, side * (PLATE_SIZE.y - PLATE_RIM) * 0.5), rim))
		_body.add_child(_box("RandZ", Vector3(PLATE_RIM, PLATE_HEIGHT * 0.5, PLATE_SIZE.y),
			Vector3(side * (PLATE_SIZE.x - PLATE_RIM) * 0.5, rim_y, 0.0), rim))
	# Die Chips sind Zählmarken auf einer Platte, keine Börse: ein Chip mißt einen
	# festen Anteil der Platte, sonst läge EINER quer über ihr. Der Maßstab sitzt auf
	# einem HALTER - ChipStackView.pulse() fährt auf Vector3.ONE zurück und risse ihn
	# sonst bei jeder Buchung fort.
	var holder := Node3D.new()
	holder.name = "Zaehlmarken"
	holder.position.y = PLATE_HEIGHT
	holder.scale = Vector3.ONE * (PLATE_SIZE.x * TALLY_CHIP_SHARE
		/ (ChipStackView.CHIP_RADIUS * 2.0))
	_body.add_child(holder)
	_chips = ChipStackView.new()
	_chips.name = "Chips"
	holder.add_child(_chips)
	_natural = span_for(KIND_TALLY)
	_natural_height = PLATE_HEIGHT * 2.0

## Eine Steuer-Buchung ist eingetroffen: der gezahlte Betrag läuft in echten
## Stückelungen auf der Platte auf. Reine ANZEIGE - gebucht hat GameRun längst.
func add_tally(amount: int) -> void:
	if kind != KIND_TALLY or _chips == null or not is_instance_valid(_chips) \
			or amount <= 0:
		return
	_chips.add_chips(ChipStackView.split_gain(amount))
	_chips.show_wallet()
	_chips.pulse()

## Was auf der Zählplatte liegt (Anzeige-Summe, nie eine Buchung).
func tally_total() -> int:
	if _chips == null or not is_instance_valid(_chips):
		return 0
	return _chips.wallet_total()

# --- Platz und echte Größe ------------------------------------------------------

## Sein wirklicher Fußabdruck in Welt-Maßen (x = Welt-X, y = Welt-Z). Der Schacht
## weitet seine Spur daran, denn der Körper ragt über seinen Plot hinaus.
func natural_span() -> Vector2:
	return _natural

## Wie hoch der Körper über seinem Platz steht - der Schacht misst daran, wie tief
## er sinken muss.
func body_height() -> float:
	return FLOOR_CLEAR + _natural_height

## Hart auf seinen Platz: der Endzustand steht zuerst, gefahren wird nur der Weg
## dorthin. Genannt wird der GLASPUNKT; die Bodenfreiheit trägt der Körper selbst.
func seat_hard(at: Vector3) -> void:
	_kill(_scale_tween)
	global_position = at
	scale = Vector3.ONE
	_set_hover_share(1.0 if _hovered else 0.0)

## Sein Entstehen an Ort und Stelle - dieselbe Geste, mit der eine Kassette in einer
## Auslage auftaucht.
func materialize() -> void:
	_kill(_scale_tween)
	visible = true
	scale = Vector3.ONE * MATERIALIZE_FROM
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector3.ONE, MATERIALIZE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Griff und Licht ------------------------------------------------------------

## Der Griff sitzt am KÖRPER, nicht am Ort: er hebt sich und leuchtet auf.
func set_hovered(on: bool) -> void:
	if _hovered == on:
		return
	_hovered = on
	_kill(_hover_tween)
	_hover_tween = create_tween()
	_hover_tween.tween_method(_set_hover_share, _hover_share_now(), 1.0 if on else 0.0,
		HOVER_TIME).set_trans(Tween.TRANS_SINE)

func hovered() -> bool:
	return _hovered

## Kurzer Ausbruch (Ankunft, Einschlag) - danach steht das Ruhelicht wieder.
func flare() -> void:
	_kill(_flare_tween)
	_flare_tween = create_tween()
	_flare_tween.tween_method(_set_glow, FLARE_ENERGY, 1.0, FLARE_TIME) \
		.set_trans(Tween.TRANS_SINE)

func _hover_share_now() -> float:
	if _body == null:
		return 0.0
	return clampf(_body.position.y - FLOOR_CLEAR, 0.0, HOVER_LIFT) / maxf(HOVER_LIFT, 0.001)

func _set_hover_share(value: float) -> void:
	if _body == null:
		return
	_body.position.y = FLOOR_CLEAR + HOVER_LIFT * value
	_set_glow(1.0 + (HOVER_ENERGY - 1.0) * value)

func _set_glow(factor: float) -> void:
	for i in _lit.size():
		_lit[i].emission_energy_multiplier = _lit_rest[i] * factor

# --- Bausteine ------------------------------------------------------------------

func _reset(new_kind: String) -> void:
	kind = new_kind
	_lit.clear()
	_lit_rest.clear()
	_chips = null
	if _body != null and is_instance_valid(_body):
		remove_child(_body)
		_body.queue_free()
	_body = Node3D.new()
	_body.name = "Body"
	_body.position.y = FLOOR_CLEAR
	add_child(_body)
	_natural = Vector2.ONE
	_natural_height = 1.0
	_hovered = false

## Die Höhe des Stapels misst am wirklich gebauten Rack - der höchste Turm zählt.
func _chips_height() -> float:
	var tallest := 1
	for tower: Dictionary in _chips.towers():
		tallest = maxi(tallest, int(tower["count"]))
	return float(tallest) * ChipStackView.CHIP_HEIGHT

func _cylinder(part_name: String, radius: float, height: float,
		material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 28
	mesh.rings = 0
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func _box(part_name: String, box_size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

## Ein leuchtendes Material, das Griff und Ausbruch mitnehmen (sie fassen die
## ganze Liste an).
func _lit_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r * 0.30, color.g * 0.30, color.b * 0.30, 1.0)
	material.metallic = 0.5
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = energy
	_lit.append(material)
	_lit_rest.append(energy)
	return material

## Die vertiefte Fläche einer Marke: fast schwarz mit einem Hauch ihres Tons.
func _dark_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r * 0.10, color.g * 0.10, color.b * 0.10, 1.0)
	material.metallic = 0.7
	material.roughness = 0.28
	return material

func _plate_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = PLATE_ALBEDO
	material.metallic = 0.65
	material.roughness = 0.35
	return material

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
