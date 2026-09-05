class_name ComboChipView
extends Node3D
## Eine Kombination als physischer 3D-Chip auf dem Display-Glas: das Modell
## (assets/models/chip.glb) steht über seiner Zelle, die nur noch als Sockel
## zeichnet (ComboCellView.socket_mode). Der Gehäusedeckel TRÄGT das Chip-
## Display: Name, Basispunkte, ×Mult und die Übertaktungs-Stufe stehen als
## Label3D flach auf einem Glasfeld - die Fläche, die die Kamera am besten
## sieht. Der Chip leuchtet in EINEM Betriebston; die Stufe zeigt das LVL-Feld,
## nicht die Farbe. Auch das Übertakten steht ganz auf diesem Deckel: der
## Zeigerkontakt schaltet die Wertzeile grün auf die Werte nach dem Kauf und
## blendet links der Stufe den ⚡-Preis ein.

const CHIP_SCENE := "res://assets/models/chip.glb"

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
const LEVEL_HEIGHT := 3.8
const TEXT_MARGIN := 3.4   # Abstand zur Gehäusekante (> SCREEN_INSET_X)
const TEXT_GAP := 1.4      # Luft zwischen Punkten, ×Mult und Stufe

## Textfarben wie in der 2D-Zelle (ComboCellView); die Stufe erbt die Rahmen-
## logik der Zelle: ab GOLD_LEVEL golden, sonst cyan.
const NAME_COLOR := Color("#ff79c6")
const POINTS_COLOR := Color("#00ffff")
const MULT_COLOR := Color("#ffd319")
const LEVEL_COLOR := Color("#8be9fd")
const LEVEL_COLOR_GOLD := Color("#ffd319")
## Große Atlas-Schrift, klein skaliert = scharfe Kanten.
const FONT_SIZE := 96

## EIN Betriebston für jeden Chip, unabhängig von der Stufe. Er liegt über der
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
## nur noch als rote Warnleuchte, das Display zeigt "AUS" statt der Stufe.
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

## Übertakten: ALLES dazu steht auf dem Deckel selbst - kein Schild daneben und
## kein Hover-Fenster. Der Zeigerkontakt schaltet die Wertzeile auf die Werte
## NACH dem Kauf (grün: "steht noch nicht so da", dasselbe Grün wie am Würfel)
## und blendet links der Stufe den ⚡-Preis ein. Getroffen wird über einen
## eigenen Pick-Körper über dem ganzen Chip.
const UPGRADE_PICK_LAYER := 128
const PREVIEW_COLOR := DieFaceDisplay.PREVIEW_NUMBER_COLOR
const COST_COLOR := CasinoStyle.ENERGY    # bezahlbar - dieselbe ⚡-Signalfarbe
const COST_DIM := Color(0.42, 0.5, 0.56)  # zu wenig Energie
## Eine gebankte Gratis-Stufe (GameRun.free_overclocks) ERSETZT den Preis, sie rechnet ihn
## nicht auf null: "kostet nichts" und "wird nicht bezahlt" sind zwei Zustände.
const FREE_TEXT := "GRATIS"
const FREE_COLOR := LEVEL_COLOR_GOLD

## Hervorhebung der gewürfelten Hand (0..1): hebt Glas und Band an.
var glow := 0.0

var _sx := 1.0
var _sz := 1.0
var _screen_material: StandardMaterial3D
var _display_material: StandardMaterial3D
var _epoxy_material: StandardMaterial3D
var _pins_material: StandardMaterial3D
var _name_label: Label3D
var _points_label: Label3D
var _mult_label: Label3D
var _level_label: Label3D
var _cost_label: Label3D
var _points := 0
var _mult := 1
var _level := -1
var _spotlit := false
var _spotlight_phase := 0.0
var _throttled := false
var _pick_body: StaticBody3D
## Angebot der nächsten Stufe (nur beim Zeigerkontakt sichtbar).
var _cost := 0
var _cost_affordable := false
## Eine gebankte Gratis-Stufe liegt bereit (GameRun.free_overclocks).
var _free := false
var _next_points := 0
var _next_mult := 0
var _hover := false

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
	inst.position.z = z_shift
	add_child(inst)

	# Das Die-Fenster und der gedruckte Pin-1-Punkt entfallen: der Deckel ist
	# jetzt Display-Fläche, beide lägen mitten darin.
	_hide(inst, "Die")
	_hide(inst, "PinOneDot")

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
	_build_upgrade_pick(z_shift)
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
	glass.mesh = plane
	glass.position = Vector3(0.0, top + 0.001, z_shift + back_shift)
	_screen_material = StandardMaterial3D.new()
	_screen_material.albedo_color = SCREEN_GLASS
	_screen_material.roughness = 0.15
	_screen_material.emission_enabled = true
	glass.material_override = _screen_material
	add_child(glass)

	var board := Node3D.new()
	board.name = "ScreenLabels"
	board.position = Vector3(0.0, top + 0.002, z_shift + back_shift)
	# Label-+Z zeigt nach oben; Label-+Y läuft Richtung Gehäuse-Rückseite.
	board.rotation.x = -PI / 2.0
	add_child(board)
	_name_label = _make_label(board, NAME_COLOR)
	_points_label = _make_label(board, POINTS_COLOR)
	_mult_label = _make_label(board, MULT_COLOR)
	_level_label = _make_label(board, LEVEL_COLOR)
	_cost_label = _make_label(board, COST_COLOR)

func _make_label(board: Node3D, color: Color) -> Label3D:
	var label := Label3D.new()
	label.font_size = FONT_SIZE
	label.modulate = color
	label.outline_size = 8
	# Mipmaps gegen Flimmern aus der Übersichts-Distanz.
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	board.add_child(label)
	return label

## Übernimmt Name/Wertung/Stufe der 2D-Zelle - die bleibt die einzige Quelle.
func sync_cell(cell: ComboCellView) -> void:
	if cell.combo_name == _name_label.text and cell.points == _points \
			and cell.mult == _mult and cell.level == _level:
		return
	_name_label.text = cell.combo_name
	_points = cell.points
	_mult = cell.mult
	_level = cell.level
	_layout_labels()
	_apply_materials()

## Zeilenlayout auf dem Deckel: Name über die ganze Breite, darunter Punkte,
## ×Mult und - ab Stufe 1 - die Stufenmarke "LVL n". Der Name schrumpft, wenn er
## zu breit wird; die Zahlen behalten ihre Größe. Beim Zeigerkontakt zeigt die
## Wertzeile grün die Werte NACH dem Kauf und links der Stufe steht der Preis.
func _layout_labels() -> void:
	var half := (BODY_LENGTH / 2.0 - TEXT_MARGIN) * _sx
	var gap := TEXT_GAP * _sx

	_level_label.text = "AUS" if _throttled else ("LVL %d" % _level if _level >= 1 else "")
	_level_label.modulate = THROTTLE_COLOR if _throttled \
		else (LEVEL_COLOR_GOLD if _level >= ComboCellView.GOLD_LEVEL else LEVEL_COLOR)
	_level_label.pixel_size = LEVEL_HEIGHT * _sz / float(FONT_SIZE)
	_points_label.text = str(_next_points if _hover else _points)
	_mult_label.text = "×%d" % (_next_mult if _hover else _mult)
	_points_label.modulate = PREVIEW_COLOR if _hover else POINTS_COLOR
	_mult_label.modulate = PREVIEW_COLOR if _hover else MULT_COLOR
	_points_label.pixel_size = SCORE_HEIGHT * _sz / float(FONT_SIZE)
	_mult_label.pixel_size = _points_label.pixel_size
	_cost_label.text = upgrade_cost_text(_cost, _free) if _hover else ""
	_cost_label.modulate = upgrade_cost_tint(_free, _cost_affordable)
	_cost_label.pixel_size = _level_label.pixel_size

	# Untere Zeile von links: Punkte, ×Mult; rechtsbündig Preis und Stufe.
	var points_w := _text_width(_points_label)
	var mult_w := _text_width(_mult_label)
	var level_w := _text_width(_level_label)
	var cost_w := _text_width(_cost_label)
	_points_label.position = Vector3(-half + points_w / 2.0, SCORE_LINE_Y * _sz, 0.0)
	_mult_label.position = Vector3(-half + points_w + gap + mult_w / 2.0, SCORE_LINE_Y * _sz, 0.0)
	_level_label.position = Vector3(half - level_w / 2.0, SCORE_LINE_Y * _sz, 0.0)
	# Der Preis rückt links an die Stufe; ohne Stufenmarke sitzt er an ihrem Platz.
	var cost_right := half - level_w - (gap if level_w > 0.0 else 0.0)
	_cost_label.position = Vector3(cost_right - cost_w / 2.0, SCORE_LINE_Y * _sz, 0.0)

	# Name über die volle Deckelbreite, nur bei Überlänge kleiner.
	var name_ps := NAME_HEIGHT * _sz / float(FONT_SIZE)
	_name_label.pixel_size = name_ps
	var name_w := _text_width(_name_label)
	var avail := 2.0 * half
	if name_w > avail:
		_name_label.pixel_size = name_ps * avail / name_w
		name_w = avail
	_name_label.position = Vector3(-half + name_w / 2.0, NAME_LINE_Y * _sz, 0.0)

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
	set_process(on)
	_apply_materials()

func _process(delta: float) -> void:
	_spotlight_phase += delta * SPOTLIGHT_SPEED
	_apply_materials()

## Kauf-Licht angekommen: kurzes Aufglühen, dann zurück in den Ruheton.
func play_upgrade_flash() -> void:
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

# --- Übertakten: Trefferfläche und Angebot auf dem Deckel --------------------

## Pick-Körper über dem ganzen Chip. Er startet stumpf: erst der
## Kombinations-Zoom schaltet ihn scharf.
func _build_upgrade_pick(z_shift: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(BODY_LENGTH * _sx, BODY_TOP * _sz, BODY_WIDTH * _sz)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	_pick_body = StaticBody3D.new()
	_pick_body.name = "UpgradePick"
	_pick_body.collision_layer = 0  # erst set_upgrade_visible schaltet scharf
	_pick_body.collision_mask = 0
	_pick_body.position = Vector3(0.0, BODY_TOP * _sz / 2.0, z_shift)
	_pick_body.add_child(collider)
	add_child(_pick_body)

## Schaltet die Trefferfläche scharf (Kombinations-Zoom an/aus).
func set_upgrade_visible(on: bool) -> void:
	if _pick_body == null:
		return
	_pick_body.collision_layer = UPGRADE_PICK_LAYER if on else 0
	if not on:
		set_upgrade_hover(false)

## Was auf dem Preisplatz steht: eine gebankte Gratis-Stufe verdrängt die Zahl.
static func upgrade_cost_text(cost: int, free: bool) -> String:
	return FREE_TEXT if free else "⚡%d" % cost

## Seine Farbe - die eine Bezahlbarkeits-Auskunft des Chips. Gratis ist immer
## golden: es gibt nichts, was daran nicht reichen könnte.
static func upgrade_cost_tint(free: bool, affordable: bool) -> Color:
	if free:
		return FREE_COLOR
	return COST_COLOR if affordable else COST_DIM

## Das Angebot der nächsten Stufe: Preis, ob die Bank ihn deckt, die Werte danach
## und ob eine Gratis-Stufe gebankt liegt. Sichtbar wird davon nichts - erst der
## Zeigerkontakt zeigt es.
func set_upgrade_offer(cost: int, affordable: bool, next_points: int, next_mult: int,
		free: bool = false) -> void:
	var same_price := cost == _cost and affordable == _cost_affordable and free == _free
	if same_price and next_points == _next_points and next_mult == _next_mult:
		return
	_cost = cost
	_cost_affordable = affordable
	_free = free
	_next_points = next_points
	_next_mult = next_mult
	if _hover:
		_layout_labels()

## Zeigerkontakt: die Wertzeile springt auf die Werte nach dem Kauf, der Preis
## erscheint. Die ganze Auskunft steht auf dem Deckel - daneben liegt nichts.
func set_upgrade_hover(on: bool) -> void:
	if _hover == on:
		return
	_hover = on
	_layout_labels()

## Der Pick-Körper des Chips - scene_root ordnet ihn seiner Kombination zu.
func upgrade_pick_body() -> StaticBody3D:
	return _pick_body

## Verschiebt eine Modellfläche in der Höhe (Modelleinheiten, unskaliert).
func _nudge(inst: Node3D, node_name: String, dy: float) -> void:
	var mesh := inst.find_child(node_name, true, false) as MeshInstance3D
	if mesh != null:
		mesh.position.y += dy

func _hide(inst: Node3D, node_name: String) -> void:
	var mesh := inst.find_child(node_name, true, false) as MeshInstance3D
	if mesh != null:
		mesh.visible = false

func _override(inst: Node3D, node_name: String, material: StandardMaterial3D) -> void:
	var mesh := inst.find_child(node_name, true, false) as MeshInstance3D
	if mesh != null:
		mesh.material_override = material
