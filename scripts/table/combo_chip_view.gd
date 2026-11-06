class_name ComboChipView
extends Node3D
## Eine Kombination als physischer 3D-Chip auf dem Display-Glas: das Modell
## (assets/models/chip.glb) steht über seiner Zelle, die nur noch als Sockel
## zeichnet (ComboCellView.socket_mode). Der Gehäusedeckel TRÄGT das Chip-
## Display: Name, Basispunkte und ×Mult stehen als Label3D flach auf einem
## Glasfeld - die Fläche, die die Kamera am besten sieht. Der Chip leuchtet in
## EINEM Betriebston; die Drossel zeigt rechts in der Namenszeile "AUS". Rechts
## in der Wertzeile sitzen die STECKPLÄTZE: drei Buchsen, eingeformt in den Deckel
## (chip_socketed.glb aus tools/blender_combo_hardware.py), gesteckt je ein Modul.

const CHIP_SCENE := "res://assets/models/chip_socketed.glb"

## Modell-Maße (mm-Einheiten des glb): X-Länge inkl. Pins, Z-Tiefe inkl.
## Display-Band (ragt vorn über), Gehäuse und Deckelhöhe.
const MODEL_LENGTH := 42.4
const MODEL_Z_MIN := -10.0
const MODEL_Z_MAX := 11.0
const BODY_LENGTH := 36.0  # Gehäuse ohne Pins (X)
const BODY_WIDTH := 20.0   # Gehäuse (Z)
const BODY_TOP := 9.0      # Deckelhöhe im Modell (STANDOFF + BODY_H)

## Anteil der Zelle, den der Chip füllt: rundum ein GLEICHER Neonrand der Zelle
## bleibt frei - der Chip sitzt in einem leuchtenden Sockelbett, statt seine
## Zelle randlos zu überdecken (dann liest der Rahmen als Versatz).
const FIT_LENGTH := 0.86
const FIT_DEPTH := 0.86

## Materialien: gl_compatibility hat keine Reflexionen und der Raum ist fast
## schwarz (ambient_light_energy 0.11). Voll metallische Pins hätten nichts zu
## spiegeln, und rein physikalische Werte (dunkles Epoxid ~5% Albedo) blieben
## schwarz. Daher: hohe Albedo, ein Eigenleucht-Boden je Fläche, und die
## Materialkörnung als Rauheits-Textur (triplanar - die Pins haben keine UVs).
const PIN_ALBEDO := Color(0.86, 0.88, 0.94)
const PIN_METALLIC := 0.45
const PIN_ROUGHNESS := 0.55  # Multiplikator auf die Körnung -> gebürstetes Zinn
const PIN_EMISSION := 0.22
## Epoxid: heller Graphit-Violett-Ton statt Fast-Schwarz, damit das Fensterlicht
## überhaupt etwas zurückwirft; der Leucht-Boden hält ihn aus dem Schwarz.
const EPOXY_ALBEDO := Color(0.28, 0.26, 0.35)
const EPOXY_ROUGHNESS := 0.72
const EPOXY_EMISSION := 0.11
## Körnung: grob fürs Epoxid (Spritzguss-Narbung), fein für gebürstetes Metall.
const GRAIN_FREQ_EPOXY := 0.055
const GRAIN_FREQ_PINS := 0.22
const GRAIN_SCALE := 0.55  # Weltmaß einer Texturkachel (triplanar)

## Chip-Display: Glasfeld auf dem Deckel, Ränder in Modelleinheiten. Vorn ein
## breiterer Rand - dort lehnt das 45°-Frontband an der Deckelkante und würde
## sonst durch das Glas stechen (gestrichelte Kante).
const SCREEN_INSET_X := 2.4
const SCREEN_INSET_BACK := 2.0
const SCREEN_INSET_FRONT := 3.6
const SCREEN_GLASS := Color(0.04, 0.045, 0.075)
## Backlight des Glases: bewusst niedrig UND gedeckelt - das Feld ist
## Hintergrund für Text, kein Leuchtkörper.
const SCREEN_EMISSION_SHARE := 0.10
const SCREEN_EMISSION_MAX := 0.3

## Textzeilen auf dem Deckel, in Modelleinheiten ab Deckelmitte. Zeilen-Y ist
## im flachen Anker Richtung Gehäuse-RÜCKSEITE positiv.
const NAME_LINE_Y := 3.6
const SCORE_LINE_Y := -3.4
const NAME_HEIGHT := 4.6   # Zeilenhöhe (Modelleinheiten)
const SCORE_HEIGHT := 5.4
const STATE_HEIGHT := 3.8
const TEXT_MARGIN := 3.4   # Abstand zur Gehäusekante (> SCREEN_INSET_X)
const TEXT_GAP := 1.4      # Luft zwischen Punkten und ×Mult

## Textfarben wie in der 2D-Zelle (ComboCellView).
const NAME_COLOR := Color("#ff79c6")
const POINTS_COLOR := Color("#00ffff")
const MULT_COLOR := Color("#ffd319")
## Große Atlas-Schrift, klein skaliert = scharfe Kanten.
const FONT_SIZE := 96

## EIN Betriebston für jeden Chip. Er liegt über der
## Bloom-Schwelle (glow_hdr_threshold 0.95), damit ein Chip "in Betrieb"
## leuchtet und nicht wie ein Fleck aussieht.
const BAND_COLOR := Color("#3f9bb5")
const BAND_ENERGY := 0.8

## Hervorhebung der gewürfelten Hand: der GANZE Chip geht ins Gold - Gehäuse,
## Pins, Frontband und Deckelglas zusammen (Ton wie das alte 2D-Highlight,
## scene_root.PAYOUT_LABEL_GLOW_COLOR). Nur Band und Glas anzuheben reichte
## nicht: bei dreizehn Chips war die zählende Kombination nicht zu erkennen.
const HIGHLIGHT_COLOR := Color(1.0, 0.81, 0.07)
const HIGHLIGHT_BODY_ENERGY := 0.5
const HIGHLIGHT_PIN_ENERGY := 0.7
const HIGHLIGHT_BAND_ENERGY := 1.2
## Das Deckelglas bleibt Textgrund: KEIN Gold, nur ein Hauch mehr Licht. Mit
## Gold darauf (und dem Bloom des goldenen Gehäuses) verschwand die Schrift.
const HIGHLIGHT_SCREEN_ENERGY := 0.12

## Thermal Throttling (Stresstest): der Chip ist abgeschaltet - das Band glimmt
## nur noch als rote Warnleuchte, das Display zeigt "AUS".
const THROTTLE_COLOR := Color("#ff5555")
const THROTTLE_ENERGY := 0.45

## Rampenlicht (Charm): der Chip atmet golden und übertönt den Betriebston -
## seit die Zelle nichts mehr zeichnet, trägt der Chip diese Anzeige selbst.
const SPOTLIGHT_COLOR := Color("#ffd319")
const SPOTLIGHT_SPEED := 2.4
const SPOTLIGHT_BASE := 2.0
const SPOTLIGHT_SWING := 1.6

## Anteil der Betriebs-Energie, mit dem das Frontband glüht (Lichtleiste vorn).
const BAND_EMISSION_SHARE := 0.7
## Wie weit das Frontband unter die Deckelfläche rutscht (Modelleinheiten).
const BAND_SEAT_DROP := 0.5

## Die eingeformten BUCHSEN: Mitten in Modelleinheiten (X entlang des Chips,
## Z nach vorn), gespiegelt in tools/blender_combo_hardware.py - dort sind die
## Löcher geschnitten. Eine Platine liegt quer dazu, die Reihe bleibt frei.
const MOLDED_X: Array[float] = [4.5, 8.85, 13.2]
const MOLDED_Z := 2.6
## Luft zwischen Wertung und erster Buchse (Modelleinheiten X).
const SOCKET_TEXT_GAP := 0.8
## Ein Pick-Körper je Platz plus einer über dem Deckel (slot -1 = der Chip
## selbst): EIN Treffer-Pfad für Hover, Einbau und Umstecken.
const SOCKET_PICK_LAYER := 128
const SOCKET_FLOOR := Color(0.012, 0.012, 0.022)
const SOCKET_RIM_COLOR := Color(0.32, 0.36, 0.48)
const SOCKET_RIM_ENERGY := 0.35
const SOCKET_HOVER_COLOR := Color(1.0, 0.81, 0.07)
const SOCKET_HOVER_ENERGY := 1.6
## Der EINBAU: freie Plätze atmen in diesem Ton, tauschbare belegte schwächer.
const SOCKET_BECKON_COLOR := Color(0.3, 1.0, 0.75)
const SOCKET_BECKON_BASE := 0.9
const SOCKET_BECKON_SWING := 0.8
const SOCKET_BECKON_SPEED := 4.0
const SOCKET_SWAP_SHARE := 0.4
const PLUG_RISE := 1.4   # Steckhub beim Einbau, in Platz-Kanten
const PLUG_TIME := 0.22

## Hervorhebung der gewürfelten Hand (0..1): hebt Glas und Band an.
var glow := 0.0
## Die Kombination dieses Chips (scene_root setzt sie; reist an den Pick-Körpern).
var combo_key := ""

var _sx := 1.0
var _sz := 1.0
var _screen_material: StandardMaterial3D
var _display_material: StandardMaterial3D
var _epoxy_material: StandardMaterial3D
var _pins_material: StandardMaterial3D
var _name_label: Label3D
var _points_label: Label3D
var _mult_label: Label3D
var _state_label: Label3D
var _points := 0
var _mult := 1
var _spotlit := false
var _spotlight_phase := 0.0
var _throttled := false
var _socket_root: Node3D
var _sockets: Array[Dictionary] = []  # je Platz {node, rim, body, part, dimmed}
var _socket_signature := ""
var _socket_frame := ""
var _z_shift := 0.0
var _hover_slot := -1
var _lifted_slot := -1
var _beckon_free := false
var _beckon_occupied := false
var _beckon_phase := 0.0
var _chip_pick: StaticBody3D

## Pin-Positionen der Chips in Screen-Pixeln, relativ zur ZELLMITTE - einzige
## Quelle für alles, was an die Pins andockt (TableScreen verlegt daran die
## LED-Adern). tip_dx = Abstand der Pin-Spitzen links/rechts, rows = die drei
## Pin-Höhen (+y = Richtung Frontband, also Bildschirm-unten).
## Modell-X liegt auf der Zellbreite, Modell-Z auf der Zellhöhe; MODEL_LENGTH ist
## die Pin-zu-Pin-Länge, die Spitzen sitzen also genau auf der halben Chipbreite.
static func pin_offsets_px(cell_size: Vector2) -> Dictionary:
	var per_unit := cell_size.y * FIT_DEPTH / (MODEL_Z_MAX - MODEL_Z_MIN)
	# Modell-Z 0 liegt nicht in der Mitte der Bounding-Box (das Band ragt vorn über).
	var center_z := (MODEL_Z_MIN + MODEL_Z_MAX) / 2.0
	var rows: Array[float] = []
	for f: float in [0.28, 0.5, 0.72]:  # Pin-Höhen des Modells (ComboCellView.PIN_FRACTIONS)
		rows.append(((f - 0.5) * BODY_WIDTH - center_z) * per_unit)
	return {"tip_dx": cell_size.x * FIT_LENGTH / 2.0, "rows": rows}

## Skaliert das Modell in die Zellfläche (Weltmaße) und hängt Materialien und
## Labels an. length = Zellbreite (Modell-X), depth = Zellhöhe (Modell-Z).
func setup(length_world: float, depth_world: float) -> void:
	_sx = length_world * FIT_LENGTH / MODEL_LENGTH
	_sz = depth_world * FIT_DEPTH / (MODEL_Z_MAX - MODEL_Z_MIN)
	var inst := (load(CHIP_SCENE) as PackedScene).instantiate() as Node3D
	inst.scale = Vector3(_sx, _sz, _sz)
	# Modellmitte (das Band ragt vorn über) auf die Zellmitte rücken.
	var z_shift := -(MODEL_Z_MAX + MODEL_Z_MIN) / 2.0 * _sz
	_z_shift = z_shift
	inst.position.z = z_shift
	add_child(inst)

	# Das Frontband lehnt im Export GENAU auf Deckelhöhe an - seine obere Kante
	# liegt dann fast koplanar zum Deckel und flimmert als gestrichelte Linie.
	# Ein Hauch tiefer setzen, dann liegt es sauber unter der Deckelfläche.
	_nudge(inst, "Display", -BAND_SEAT_DROP)

	# Frontband = Lichtleiste in der Hitzefarbe (trägt keinen Text mehr).
	_display_material = StandardMaterial3D.new()
	_display_material.albedo_color = SCREEN_GLASS
	_display_material.roughness = 0.2
	_display_material.emission_enabled = true
	_override(inst, "Display", _display_material)

	# Gehäuse und Pins bringt das glb mit - im dunklen Raum tragen die Werte aus
	# Blender aber nicht, also hier überschreiben (siehe PIN_*/EPOXY_*).
	_epoxy_material = StandardMaterial3D.new()
	_epoxy_material.albedo_color = EPOXY_ALBEDO
	_epoxy_material.roughness = EPOXY_ROUGHNESS
	_epoxy_material.roughness_texture = _grain_texture(GRAIN_FREQ_EPOXY)
	_epoxy_material.emission_enabled = true
	_triplanar(_epoxy_material)
	_override(inst, "Body", _epoxy_material)

	_pins_material = StandardMaterial3D.new()
	_pins_material.albedo_color = PIN_ALBEDO
	_pins_material.metallic = PIN_METALLIC
	_pins_material.roughness = PIN_ROUGHNESS
	_pins_material.roughness_texture = _grain_texture(GRAIN_FREQ_PINS)
	_pins_material.emission_enabled = true
	_triplanar(_pins_material)
	_override(inst, "Pins", _pins_material)

	_build_screen(z_shift)
	_build_chip_pick(z_shift)
	_apply_materials()

## Körnungs-Textur (Rauheits-Kanal): Simplex-Rauschen, kachelbar.
func _grain_texture(frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	return tex

## Triplanar-Projektion: die Pins haben gar keine UVs, das Gehäuse nur die von
## den Bool-Schnitten zerrissenen - projizieren statt mappen.
func _triplanar(material: StandardMaterial3D) -> void:
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE / GRAIN_SCALE

## Chip-Display: Glasfeld flach auf dem Deckel, darüber die Textzeilen. Die
## Labels hängen an einem eigenen Anker (NICHT im in X gestreckten Modell) -
## sonst zöge dessen Skalierung die Schrift breit.
func _build_screen(z_shift: float) -> void:
	var top := BODY_TOP * _sz
	# Glasfeld sitzt wegen des breiteren Frontrands etwas nach hinten versetzt.
	var back_shift := -(SCREEN_INSET_FRONT - SCREEN_INSET_BACK) / 2.0 * _sz
	var plane := PlaneMesh.new()
	plane.size = Vector2((BODY_LENGTH - SCREEN_INSET_X * 2.0) * _sx,
		(BODY_WIDTH - SCREEN_INSET_BACK - SCREEN_INSET_FRONT) * _sz)
	var glass := MeshInstance3D.new()
	glass.name = "ChipScreen"
	glass.mesh = _holed_glass(plane.size, z_shift + back_shift)
	glass.position = Vector3(0.0, top + 0.001, z_shift + back_shift)
	_screen_material = StandardMaterial3D.new()
	_screen_material.albedo_color = SCREEN_GLASS
	_screen_material.roughness = 0.15
	_screen_material.emission_enabled = true
	_screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = _screen_material
	add_child(glass)

	var board := Node3D.new()
	board.name = "ScreenLabels"
	board.position = Vector3(0.0, top + 0.002, z_shift + back_shift)
	# Label-+Z zeigt nach oben; Label-+Y läuft Richtung Gehäuse-Rückseite.
	board.rotation.x = -PI / 2.0
	add_child(board)
	# Die Buchsen im Chip-Raum, ihr Mund auf der Deckelhöhe.
	_socket_root = Node3D.new()
	_socket_root.name = "Sockets"
	_socket_root.position = Vector3(0.0, top, 0.0)
	add_child(_socket_root)
	_name_label = _make_label(board, NAME_COLOR)
	_points_label = _make_label(board, POINTS_COLOR)
	_mult_label = _make_label(board, MULT_COLOR)
	_state_label = _make_label(board, THROTTLE_COLOR)

## Das Glasfeld mit Aussparungen über den Buchsen: ein Raster aus Rechtecken, die
## Felder über einem Mund (samt Lippe) fallen weg.
func _holed_glass(size: Vector2, center_z: float) -> ArrayMesh:
	var hole := ComboPartBody.OUTER + 0.024
	var holes: Array[Rect2] = []
	for i in MOLDED_X.size():
		var spot := Vector2(MOLDED_X[i] * _sx, MOLDED_Z * _sz + _z_shift - center_z)
		holes.append(Rect2(spot - Vector2.ONE * hole * 0.5, Vector2.ONE * hole))
	var xs: Array[float] = [-size.x * 0.5, size.x * 0.5]
	var zs: Array[float] = [-size.y * 0.5, size.y * 0.5]
	for rect in holes:
		for x in [rect.position.x, rect.end.x]:
			if absf(x) < size.x * 0.5:
				xs.append(x)
		for z in [rect.position.y, rect.end.y]:
			if absf(z) < size.y * 0.5:
				zs.append(z)
	xs.sort()
	zs.sort()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			var cell := Rect2(Vector2(xs[i], zs[j]), Vector2(xs[i + 1] - xs[i], zs[j + 1] - zs[j]))
			if cell.size.x <= 0.0001 or cell.size.y <= 0.0001:
				continue
			if holes.any(func(r: Rect2) -> bool: return r.has_point(cell.get_center())):
				continue
			var a := Vector3(cell.position.x, 0.0, cell.position.y)
			var b := Vector3(cell.end.x, 0.0, cell.position.y)
			var c := Vector3(cell.end.x, 0.0, cell.end.y)
			var d := Vector3(cell.position.x, 0.0, cell.end.y)
			for v in [a, b, c, a, c, d]:
				tool.add_vertex(v)
	return tool.commit()

func _make_label(board: Node3D, color: Color) -> Label3D:
	var label := Label3D.new()
	label.font_size = FONT_SIZE
	label.modulate = color
	label.outline_size = 8
	# Mipmaps gegen Flimmern aus der Übersichts-Distanz.
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	board.add_child(label)
	return label

## Übernimmt Name/Wertung der 2D-Zelle - die bleibt die einzige Quelle.
func sync_cell(cell: ComboCellView) -> void:
	if cell.combo_name == _name_label.text and cell.points == _points \
			and cell.mult == _mult:
		return
	_name_label.text = cell.combo_name
	_points = cell.points
	_mult = cell.mult
	_layout_labels()
	_apply_materials()

## Zeilenlayout auf dem Deckel: Name über die ganze Breite, darunter Punkte
## und ×Mult, rechtsbündig die Drossel-Marke. Der Name schrumpft, wenn er zu
## breit wird; die Zahlen behalten ihre Größe.
func _layout_labels() -> void:
	var half := (BODY_LENGTH / 2.0 - TEXT_MARGIN) * _sx
	var gap := TEXT_GAP * _sx

	_state_label.text = "AUS" if _throttled else ""
	_state_label.pixel_size = STATE_HEIGHT * _sz / float(FONT_SIZE)
	_points_label.text = str(_points)
	_mult_label.text = "×%d" % _mult
	_points_label.pixel_size = SCORE_HEIGHT * _sz / float(FONT_SIZE)
	_mult_label.pixel_size = _points_label.pixel_size

	var points_w := _text_width(_points_label)
	var mult_w := _text_width(_mult_label)
	# Die Wertung endet vor der ersten Buchse - sonst schrumpft sie.
	var zone_left := (MOLDED_X[0] - SOCKET_TEXT_GAP) * _sx - ComboPartBody.OUTER * 0.5
	var score_avail := minf(zone_left, half) + half - gap
	if points_w + gap + mult_w > score_avail and points_w + mult_w > 0.0:
		var shrink := maxf(score_avail - gap, 0.01) / (points_w + mult_w)
		_points_label.pixel_size *= shrink
		_mult_label.pixel_size *= shrink
		points_w *= shrink
		mult_w *= shrink
	_points_label.position = Vector3(-half + points_w / 2.0, SCORE_LINE_Y * _sz, 0.0)
	_mult_label.position = Vector3(-half + points_w + gap + mult_w / 2.0, SCORE_LINE_Y * _sz, 0.0)
	# AUS steht rechts in der Namenszeile - die Wertzeile gehört den Steckplätzen.
	var state_w := _text_width(_state_label)
	_state_label.position = Vector3(half - state_w / 2.0, NAME_LINE_Y * _sz, 0.0)

	# Name über die volle Deckelbreite, nur bei Überlänge kleiner.
	var name_ps := NAME_HEIGHT * _sz / float(FONT_SIZE)
	_name_label.pixel_size = name_ps
	var name_w := _text_width(_name_label)
	var avail := 2.0 * half - (state_w + gap if state_w > 0.0 else 0.0)
	# Eine Platine, die in die Namenszeile ragt, begrenzt den Namen.
	avail = minf(avail, _riser_name_limit() - gap + half)
	if name_w > avail:
		_name_label.pixel_size = name_ps * avail / name_w
		name_w = avail
	_name_label.position = Vector3(-half + name_w / 2.0, NAME_LINE_Y * _sz, 0.0)

## Linkeste Kante (Chip-X) einer Platine, die in die Namenszeile reicht (INF = keine).
func _riser_name_limit() -> float:
	var back_shift := -(SCREEN_INSET_FRONT - SCREEN_INSET_BACK) / 2.0 * _sz
	var name_front := _z_shift + back_shift - NAME_LINE_Y * _sz + NAME_HEIGHT * _sz * 0.5
	var limit := INF
	for entry in _sockets:
		var body: ComboPartBody = entry["body"]
		if body == null or not is_instance_valid(body) or not ComboPartBody.is_riser(body.part):
			continue
		var min_x := INF
		var min_z := INF
		for corner in ComboPartBody.riser_corners():
			var at := to_local(body.global_transform * corner)
			min_x = minf(min_x, at.x)
			min_z = minf(min_z, at.z)
		if min_z < name_front:
			limit = minf(limit, min_x)
	return limit

func _text_width(label: Label3D) -> float:
	if label.text.is_empty():
		return 0.0
	return ThemeDB.fallback_font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * label.pixel_size

## Hervorhebung der aktiven Kombination (scene_root tweent den Wert).
func set_glow(value: float) -> void:
	glow = value
	_apply_materials()

## Stresstest-Drossel an/aus: der Chip wertet diese Runde nicht.
func set_throttled(on: bool) -> void:
	if _throttled == on:
		return
	_throttled = on
	_layout_labels()
	_apply_materials()

## Rampenlicht an/aus: läuft nur, solange der Chip im Licht steht.
func set_spotlight(on: bool) -> void:
	if _spotlit == on:
		return
	_spotlit = on
	_spotlight_phase = 0.0
	_sync_process()
	_apply_materials()

func _process(delta: float) -> void:
	if _spotlit:
		_spotlight_phase += delta * SPOTLIGHT_SPEED
		_apply_materials()
	if _beckon_free or _beckon_occupied:
		_beckon_phase += delta * SOCKET_BECKON_SPEED
		_apply_socket_rims()

func _sync_process() -> void:
	set_process(_spotlit or _beckon_free or _beckon_occupied)

## Licht angekommen: kurzes Aufglühen, dann zurück in den Ruheton.
func play_arrival_flash() -> void:
	var tween := create_tween()
	tween.tween_method(set_glow, 1.5, 0.0, 1.2)

func _apply_materials() -> void:
	var color := BAND_COLOR
	var energy := BAND_ENERGY
	if _spotlit:
		color = SPOTLIGHT_COLOR
		energy = SPOTLIGHT_BASE + SPOTLIGHT_SWING * (0.5 + 0.5 * sin(_spotlight_phase))
	if _throttled:  # Drossel schlägt alles - der Chip ist aus
		color = THROTTLE_COLOR
		energy = THROTTLE_ENERGY
	# Hervorhebung zieht jede Fläche ins Gold; glow darf über 1 gehen
	# (Kauf-Blitz), der Farbanteil bleibt aber gedeckelt.
	var lit := clampf(glow, 0.0, 1.0)
	var tint := color.lerp(HIGHLIGHT_COLOR, lit)
	if _screen_material != null:
		_screen_material.emission = color  # bewusst OHNE Gold-Anteil
		_screen_material.emission_energy_multiplier = \
			minf(energy * SCREEN_EMISSION_SHARE, SCREEN_EMISSION_MAX) + HIGHLIGHT_SCREEN_ENERGY * glow
	if _display_material != null:
		_display_material.emission = tint
		_display_material.emission_energy_multiplier = \
			energy * BAND_EMISSION_SHARE + HIGHLIGHT_BAND_ENERGY * glow
	if _epoxy_material != null:
		_epoxy_material.emission = EPOXY_ALBEDO.lerp(HIGHLIGHT_COLOR, lit)
		_epoxy_material.emission_energy_multiplier = EPOXY_EMISSION + HIGHLIGHT_BODY_ENERGY * glow
	if _pins_material != null:
		_pins_material.emission = PIN_ALBEDO.lerp(HIGHLIGHT_COLOR, lit)
		_pins_material.emission_energy_multiplier = PIN_EMISSION + HIGHLIGHT_PIN_ENERGY * glow

## Verschiebt eine Modellfläche in der Höhe (Modelleinheiten, unskaliert).
func _nudge(inst: Node3D, node_name: String, dy: float) -> void:
	var mesh := inst.find_child(node_name, true, false) as MeshInstance3D
	if mesh != null:
		mesh.position.y += dy

func _override(inst: Node3D, node_name: String, material: StandardMaterial3D) -> void:
	var mesh := inst.find_child(node_name, true, false) as MeshInstance3D
	if mesh != null:
		mesh.material_override = material

# --- Die STECKPLÄTZE -----------------------------------------------------------

## Der EINE Schreiber der Belegung: parts = je Platz ComboPart oder null (Länge =
## Zahl der Plätze), dimmed = je Platz stillgelegt (Hitzestau). Gleiche Belegung
## baut nichts neu; ändern sich die Platinen, wird der Baum neu gesteckt.
func set_sockets(parts: Array, dimmed: Array = []) -> void:
	var signature := ""
	var frame := "%d" % parts.size()
	for slot in parts.size():
		var part: ComboPart = parts[slot]
		var off := slot < dimmed.size() and bool(dimmed[slot])
		signature += "%s:%d:%d;" % [part.id if part != null else "-",
			part.get_instance_id() if part != null else 0, int(off)]
		if ComboPartBody.is_riser(part):
			frame += ";%d@%d" % [part.get_instance_id(), slot]
	if signature == _socket_signature and _sockets.size() == parts.size():
		return
	_socket_signature = signature
	if _socket_root == null:
		return
	if frame != _socket_frame or _sockets.size() != parts.size():
		_socket_frame = frame
		_build_sockets(parts)
	for slot in parts.size():
		_seat_part(slot, parts[slot], slot < dimmed.size() and bool(dimmed[slot]))
	_apply_socket_rims()

func socket_count() -> int:
	return _sockets.size()

func socket_part(slot: int) -> ComboPart:
	if slot < 0 or slot >= _sockets.size():
		return null
	return _sockets[slot]["part"]

func socket_dimmed(slot: int) -> bool:
	if slot < 0 or slot >= _sockets.size():
		return false
	return bool(_sockets[slot]["dimmed"])

## Der Platz, der diesen trägt (-1 = der Chip selbst).
func socket_carrier(slot: int) -> int:
	if slot < 0 or slot >= _sockets.size():
		return -1
	return int(_sockets[slot]["carrier"])

## Weltmitte des MUNDES eines Platzes (Ziel des Geistes und des Hinweises).
func socket_world(slot: int) -> Vector3:
	if slot < 0 or slot >= _sockets.size():
		return global_position
	return (_sockets[slot]["node"] as Node3D).global_position

## Kantenlänge eines Moduls in Welt - überall dieselbe.
func socket_side() -> float:
	return ComboPartBody.SIDE

## Der Zeiger liegt auf diesem Platz (-1 = keinem): sein Mund geht ins Gold.
func set_socket_hover(slot: int) -> void:
	if slot == _hover_slot:
		return
	_hover_slot = slot
	_apply_socket_rims()

## Der EINBAU ruft: freie Plätze atmen, tauschbare belegte schwächer mit.
func set_socket_beckon(free_on: bool, occupied_on: bool) -> void:
	if free_on == _beckon_free and occupied_on == _beckon_occupied:
		return
	_beckon_free = free_on
	_beckon_occupied = occupied_on
	_sync_process()
	_apply_socket_rims()

func socket_beckons(slot: int) -> bool:
	if slot < 0 or slot >= _sockets.size():
		return false
	return _beckon_free if _sockets[slot]["part"] == null else _beckon_occupied

## Umstecken: das gezogene Teil ist in der Hand, sein Platz zeigt leer (eine
## Platine nimmt ihre Fracht mit).
func set_socket_lifted(slot: int) -> void:
	if slot == _lifted_slot:
		return
	_lifted_slot = slot
	for i in _sockets.size():
		var body: ComboPartBody = _sockets[i]["body"]
		if body != null and is_instance_valid(body):
			body.visible = i != _lifted_slot

func socket_lifted() -> int:
	return _lifted_slot

## Der Einbau: das Teil steckt schon (Endzustand), es fährt nur von oben in seine Buchse.
func play_plug(slot: int) -> void:
	if slot < 0 or slot >= _sockets.size():
		return
	var body: ComboPartBody = _sockets[slot]["body"]
	if body == null or not is_instance_valid(body):
		return
	body.position = _part_rest() + Vector3.UP * ComboPartBody.SIDE * PLUG_RISE
	var tween := body.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "position", _part_rest(), PLUG_TIME)

## Ein Teil feuert in der Wertung: sein Körper blitzt, sein Mund mit.
## strength > 1 ist der Krit-Schlag. Leerer oder fremder Platz = nichts.
func flash_socket(slot: int, strength := 1.0) -> void:
	if slot < 0 or slot >= _sockets.size():
		return
	var body: ComboPartBody = _sockets[slot]["body"]
	if body != null and is_instance_valid(body):
		body.flash(strength)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		if slot < _sockets.size():
			_sockets[slot]["flash"] = v
			_apply_socket_rims(),
		strength, 0.0, ComboPartBody.FLASH_TIME * maxf(strength, 1.0))

func socket_flash(slot: int) -> float:
	if slot < 0 or slot >= _sockets.size():
		return 0.0
	return float(_sockets[slot].get("flash", 0.0))

## Wer getroffen ist: {key, slot} aus dem Pick-Körper ({} = kein Chip-Körper).
static func pick_of(collider: Object) -> Dictionary:
	if collider == null or not collider.has_meta("combo_key"):
		return {}
	return {"key": String(collider.get_meta("combo_key")),
		"slot": int(collider.get_meta("socket_slot", -1))}

func _build_chip_pick(z_shift: float) -> void:
	_chip_pick = StaticBody3D.new()
	_chip_pick.name = "ChipPick"
	_chip_pick.collision_layer = SOCKET_PICK_LAYER
	_chip_pick.collision_mask = 0
	_chip_pick.set_meta("combo_key", combo_key)
	_chip_pick.set_meta("socket_slot", -1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BODY_LENGTH * _sx, BODY_TOP * _sz, BODY_WIDTH * _sz)
	shape.shape = box
	shape.position = Vector3(0.0, BODY_TOP * _sz * 0.5, z_shift)
	_chip_pick.add_child(shape)
	add_child(_chip_pick)

## Wo ein gestecktes Teil ruht: sein Gehäuse sitzt WELL tief in der Buchse.
func _part_rest() -> Vector3:
	return Vector3.DOWN * ComboPartBody.WELL

## Die eingeformten Buchsen im Chip-Raum (Mitte des Mundes auf der Deckelhöhe 0).
func _molded_spot(index: int) -> Vector3:
	return Vector3(MOLDED_X[index] * _sx, 0.0, MOLDED_Z * _sz + _z_shift)

## Den Baum neu stecken: die drei Grundplätze stehen eingeformt im Deckel, jede
## Platine trägt ihr Paar oben (ComboPartEffects.socket_parents ordnet die
## Zusatzplätze zu). Eine Platine auf einer Platine liegt quer zu ihrer Trägerin.
func _build_sockets(parts: Array) -> void:
	for entry in _sockets:
		var node := entry["node"] as Node3D
		if is_instance_valid(node) and node.get_parent() == _socket_root:
			_socket_root.remove_child(node)
			node.queue_free()
	_sockets.clear()
	_hover_slot = -1
	_lifted_slot = -1
	var parents := ComboPartEffects.socket_parents(parts, GameRun.SOCKETS_PER_COMBO)
	var tops: Dictionary = {}  # Platinen-Platz -> Zahl der schon vergebenen Buchsen
	for slot in parts.size():
		var carrier := parents[slot]
		var host: Node3D = _socket_root
		var spot := _molded_spot(mini(slot, MOLDED_X.size() - 1))
		var tier := 0
		if carrier >= 0 and carrier < _sockets.size() and _sockets[carrier]["body"] != null:
			host = _sockets[carrier]["body"]
			var used: int = tops.get(carrier, 0)
			tops[carrier] = used + 1
			spot = ComboPartBody.riser_sockets()[mini(used, 1)]
			tier = int(_sockets[carrier]["tier"]) + 1
		elif carrier != ComboPartEffects.CHIP_SOCKET:
			spot += Vector3.UP * ComboPartBody.RISER_TOP  # Rückfall: nie erreichbar
		var node := Node3D.new()
		node.name = "Socket_%d" % slot
		node.position = spot
		host.add_child(node)
		var mouth := _build_socket_shell(node)
		_build_socket_pick(node, slot, Vector3(ComboPartBody.MOUTH, 0.3, ComboPartBody.MOUTH),
			Vector3.UP * 0.03)
		var entry := {"node": node, "rim": mouth, "body": null, "part": null,
			"dimmed": false, "carrier": carrier, "tier": tier}
		_sockets.append(entry)
		var part: ComboPart = parts[slot]
		if ComboPartBody.is_riser(part):
			_spawn_body(slot, part)
	if _chip_pick != null:
		_chip_pick.set_meta("combo_key", combo_key)
	_layout_labels()

## Die BUCHSE (part_socket.glb): Wanne und Kontakte stumm, der MUND trägt die Zustände.
func _build_socket_shell(node: Node3D) -> StandardMaterial3D:
	var shell := ComboPartBody._scene(ComboPartBody.SOCKET_SCENE).instantiate() as Node3D
	shell.name = "Buchse"
	node.add_child(shell)
	var well := shell.find_child("Wanne", true, false) as MeshInstance3D
	if well != null:
		var dark := StandardMaterial3D.new()
		dark.albedo_color = SOCKET_FLOOR
		dark.roughness = 0.8
		well.material_override = dark
	var contacts := shell.find_child("Kontakte", true, false) as MeshInstance3D
	if contacts != null:
		var gold := StandardMaterial3D.new()
		gold.albedo_color = ComboPartBody.GOLD_ALBEDO
		gold.metallic = 0.7
		gold.roughness = 0.35
		gold.emission_enabled = true
		gold.emission = ComboPartBody.GOLD_ALBEDO
		gold.emission_energy_multiplier = ComboPartBody.GOLD_EMISSION
		contacts.material_override = gold
	var mouth := StandardMaterial3D.new()
	mouth.albedo_color = SOCKET_RIM_COLOR.darkened(0.5)
	mouth.emission_enabled = true
	var lip := shell.find_child("Mund", true, false) as MeshInstance3D
	if lip != null:
		lip.material_override = mouth
	return mouth

func _build_socket_pick(node: Node3D, slot: int, size: Vector3, at: Vector3) -> void:
	var pick := StaticBody3D.new()
	pick.collision_layer = SOCKET_PICK_LAYER
	pick.collision_mask = 0
	pick.set_meta("combo_key", combo_key)
	pick.set_meta("socket_slot", slot)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	pick.add_child(shape)
	node.add_child(pick)

func _spawn_body(slot: int, part: ComboPart) -> ComboPartBody:
	var entry := _sockets[slot]
	var body := ComboPartBody.new()
	body.name = "Part"
	(entry["node"] as Node3D).add_child(body)
	body.setup(part)
	body.position = _part_rest()
	# Quer liegend rückt die Platine zur Chip-Mitte hin, damit sie im Chip bleibt.
	if int(entry["tier"]) % 2 == 1:
		var toward := -1.0 if to_local((entry["node"] as Node3D).global_position).x > 0.0 else 1.0
		body.rotation.y = PI * 0.5 * toward
	body.visible = slot != _lifted_slot
	if ComboPartBody.is_riser(part):
		# Die Platine selbst bleibt greifbar: ein Pick über ihrer Platte, unter den Buchsen.
		_build_socket_pick(body, slot,
			Vector3(ComboPartBody.RISER_DEPTH, ComboPartBody.RISER_THICK, ComboPartBody.RISER_WIDTH),
			Vector3(0.0, ComboPartBody.HEIGHT + ComboPartBody.RISER_THICK * 0.5,
				ComboPartBody.RISER_SHIFT))
	entry["body"] = body
	entry["part"] = part
	return body

func _seat_part(slot: int, part: ComboPart, off: bool) -> void:
	var entry := _sockets[slot]
	var body: ComboPartBody = entry["body"]
	if body != null and (not is_instance_valid(body) or body.part != part):
		if is_instance_valid(body):
			body.queue_free()
		body = null
		entry["body"] = null
	if body == null and part != null:
		body = _spawn_body(slot, part)
	if body != null:
		body.set_dimmed(off)
	entry["part"] = part
	entry["dimmed"] = off

func _apply_socket_rims() -> void:
	var pulse := 0.5 + 0.5 * sin(_beckon_phase)
	for slot in _sockets.size():
		var material: StandardMaterial3D = _sockets[slot]["rim"]
		var color := SOCKET_RIM_COLOR
		var energy := SOCKET_RIM_ENERGY
		if socket_beckons(slot):
			color = SOCKET_BECKON_COLOR
			energy = SOCKET_BECKON_BASE + SOCKET_BECKON_SWING * pulse
			if _sockets[slot]["part"] != null:
				energy *= SOCKET_SWAP_SHARE
		if slot == _hover_slot:
			color = SOCKET_HOVER_COLOR
			energy = SOCKET_HOVER_ENERGY
		var lit := float(_sockets[slot].get("flash", 0.0))
		if lit > 0.0:
			var part: ComboPart = _sockets[slot]["part"]
			color = color.lerp(part.tint() if part != null else SOCKET_HOVER_COLOR, minf(lit, 1.0))
			energy += SOCKET_HOVER_ENERGY * lit
		material.albedo_color = color.darkened(0.5)
		material.emission = color
		material.emission_energy_multiplier = energy
