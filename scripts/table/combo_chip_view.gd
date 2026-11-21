class_name ComboChipView
extends Node3D
## Eine Kombination als physischer 3D-Chip auf dem Filz: der BREITE Chip (chip_wide.glb aus
## tools/blender_combo_hardware.py, in X und Z gleich skaliert) über seiner Zelle, die nur
## noch als Anker dient (ComboCellView.socket_mode). Der Deckel trägt LINKS die Anzeige
## (Name, Basispunkte, ×Mult, gedimmt der Grundwert) und RECHTS drei SOCKEL in Plattengröße,
## durch die EINE Signalleitung läuft. Ohne Modul liegt über den Sockeln eine ABDECKUNG mit
## dem Würfelbild der Kombination.

const CHIP_SCENE := "res://assets/models/chip_wide.glb"

## Modell-Maße (mm-Einheiten des glb): X-Länge inkl. Pins, Z-Tiefe inkl.
## Display-Band (ragt vorn über), Gehäuse und Deckelhöhe.
const MODEL_LENGTH := 90.1
const MODEL_Z_MIN := -10.0
const MODEL_Z_MAX := 11.0
const BODY_LENGTH := 83.7  # Gehäuse ohne Pins (X)
const BODY_WIDTH := 20.0   # Gehäuse (Z)
const BODY_TOP := 9.0      # Deckelhöhe im Modell (STANDOFF + BODY_H)

## Anteil der Zelle, den der Chip füllt: rundum ein GLEICHER Neonrand der Zelle
## bleibt frei - der Chip sitzt in einem leuchtenden Sockelbett, statt seine
## Zelle randlos zu überdecken (dann liest der Rahmen als Versatz).
## Längs füllt er sie fast ganz: so stehen die Spalten eng (Spieler-Wunsch 2026-11-21).
const FIT_LENGTH := 0.95
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
## Glasfeld über dem Deckel (Welt): mit 0,001 rang es aus der Übersicht im Tiefenpuffer
## mit dem Deckel, und unter dem Gold-Glühen las das als flimmernde Streifen.
const SCREEN_LIFT := 0.03
const LABEL_LIFT := 0.01
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
## Der GRUNDWERT neben der Wertung: klein und gedimmt, nur wenn die Module ihn verschieben.
const BASE_SHARE := 0.5
const BASE_COLOR := Color(0.62, 0.62, 0.72, 0.75)

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

## Hervorhebung der gewürfelten Hand: Gehäuse, Pins, Frontband und Leitung gehen ins Gold;
## Sockel, Platten und Module behalten ihre Farben.
const HIGHLIGHT_COLOR := Color(1.0, 0.81, 0.07)
const HIGHLIGHT_BODY_ENERGY := 0.5
const HIGHLIGHT_PIN_ENERGY := 0.7
const HIGHLIGHT_BAND_ENERGY := 1.2
const HIGHLIGHT_LINE_ENERGY := 1.4
## Das Deckelglas bleibt Textgrund: KEIN Gold, nur ein Hauch mehr Licht. Mit
## Gold darauf (und dem Bloom des goldenen Gehäuses) verschwand die Schrift.
const HIGHLIGHT_SCREEN_ENERGY := 0.12

## Thermal Throttling (Stresstest): der Chip ist abgeschaltet - das Band glimmt
## nur noch als rote Warnleuchte, das Display zeigt "AUS", die Leitung ist aus.
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

## Die SOCKEL (Welt): Teilung längs des Chips, Abstand des letzten zur rechten Gehäusekante,
## Luft zwischen Anzeige und erstem Sockel.
const SOCKET_PITCH := 1.95
const SOCKET_EDGE := 0.34
const DISPLAY_GAP := 0.5
## Kontaktfeld: 5 längs × 7 quer Gold-Pads ohne die vier Ecken.
const PAD_COUNT := Vector2i(7, 5)
const PAD_PITCH := 0.24
const PAD_SIZE := 0.1
const PAD_TOP := 0.016
## Ein Pick-Körper je Platz plus einer über dem Deckel (slot -1 = der Chip
## selbst): EIN Treffer-Pfad für Hover, Einbau und Umstecken.
const SOCKET_PICK_LAYER := 128
const SOCKET_RIM_COLOR := Color(0.32, 0.36, 0.48)
const SOCKET_RIM_ENERGY := 0.25
const SOCKET_HOVER_COLOR := Color(1.0, 0.81, 0.07)
const SOCKET_HOVER_ENERGY := 1.6
## Der EINBAU: freie Plätze atmen in diesem Ton, tauschbare belegte schwächer.
const SOCKET_BECKON_COLOR := Color(0.3, 1.0, 0.75)
const SOCKET_BECKON_BASE := 0.9
const SOCKET_BECKON_SWING := 0.8
const SOCKET_BECKON_SPEED := 4.0
const SOCKET_SWAP_SHARE := 0.4
const PLUG_RISE := 0.8   # Steckhub beim Einbau, in Plattenkanten
const PLUG_TIME := 0.22

## Die SIGNALLEITUNG: halbe Deckeltiefe, von der Anzeige durch alle Sockel bis zum rechten Pin.
## Über einem leeren Kontaktfeld liegt sie dünn obenauf, unter einer Platte läuft sie durch.
const LINE_Y := 0.02
const LINE_H := 0.006
const LINE_COLOR := Color(0.25, 0.85, 1.0)
const LINE_ENERGY_SHARE := 0.45
## Breiten (Welt) der Blockmodelle, auf den echten Chip hochgerechnet.
const LINE_WIDTH_SCALE := 2.5
## Stil je Familie (tools/blender_combo_module_variants.py OUT_LINE): Breite, Adern, Licht.
const LINE_STYLES := {
	"gleich": Vector3(0.03, 1.0, 1.4), "dick": Vector3(0.06, 1.0, 2.2),
	"hell": Vector3(0.045, 1.0, 3.2), "doppelt": Vector3(0.03, 2.0, 2.4),
	"stark": Vector3(0.085, 1.0, 3.4),
}
const LINE_STYLE_OF := {
	ComboPart.RESISTOR: "dick", ComboPart.COIL: "dick", ComboPart.SERIES_RESISTOR: "dick",
	ComboPart.SERIES_TERMINAL: "dick", ComboPart.SHUNT: "dick", ComboPart.COUPLING: "dick",
	ComboPart.CAPACITOR: "hell", ComboPart.SOLDER_JOINT: "hell", ComboPart.THERMISTOR: "hell",
	ComboPart.COUNTER: "hell", ComboPart.ERROR_MEMORY: "hell", ComboPart.STARTER: "hell",
	ComboPart.RELAY: "doppelt", ComboPart.OUTPUT_STAGE: "doppelt",
	ComboPart.PARALLEL_CIRCUIT: "doppelt",
	ComboPart.AMPLIFIER_TUBE: "stark", ComboPart.HIGH_VOLTAGE_TUBE: "stark",
	ComboPart.MAGNETRON: "stark", ComboPart.RESONATOR: "stark", ComboPart.AFTERBURNER: "stark",
}
const LINE_PULSE_TIME := 0.35
const LINE_PULSE_ENERGY := 3.0

## Die ABDECKUNG leerer Chips: Gehäuseton, darauf das Würfelbild der Kombination.
const COVER_LIFT := 0.06
const COVER_THICK := 0.05
const COVER_MARGIN := 0.06
const COVER_TIME := 0.24
const COVER_DIE := 0.62
const COVER_DIE_GAP := 0.16
const COVER_DIE_FACE := Color(0.46, 0.44, 0.55)
const COVER_PIP := Color(0.05, 0.05, 0.08)

## Hervorhebung der gewürfelten Hand (0..1): hebt Glas und Band an.
var glow := 0.0
## Die Kombination dieses Chips (scene_root setzt sie VOR setup; reist an den Pick-Körpern).
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
var _base_label: Label3D
var _points := 0
var _mult := 1
var _base := Vector2i(-1, -1)
var _spotlit := false
var _spotlight_phase := 0.0
var _throttled := false
var _socket_root: Node3D
var _sockets: Array[Dictionary] = []  # je Platz {node, rim, body, part, dimmed, carrier, tier, pick}
var _socket_signature := ""
var _part_context: Dictionary = {}
var _socket_frame := ""
var _z_shift := 0.0
var _half := 0.0
var _socket_z := 0.0
var _display_right := 0.0
var _hover_slot := -1
var _lifted_slot := -1
var _beckon_free := false
var _beckon_occupied := false
var _beckon_phase := 0.0
var _chip_pick: StaticBody3D
var _line_segments: Array[Dictionary] = []  # je Abschnitt {node, strips, material, style}
var _line_pulse := -1.0
var _line_tween: Tween
var _cover: Node3D
var _cover_open := false
var _cover_called := false
var _cover_tween: Tween

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

## Skaliert das Modell in die Zellfläche (Weltmaße) und hängt Materialien, Labels,
## Sockel-Leiste, Leitung und Abdeckung an. length = Zellbreite (Modell-X), depth = Zellhöhe.
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
	_half = BODY_LENGTH * _sx * 0.5
	_socket_z = z_shift - (SCREEN_INSET_FRONT - SCREEN_INSET_BACK) / 2.0 * _sz
	_display_right = socket_x(0) - ComboPartBody.SOCKET_OUTER.y * 0.5 - DISPLAY_GAP

	# Das Frontband lehnt im Export GENAU auf Deckelhöhe an - seine obere Kante
	# liegt dann fast koplanar zum Deckel und flimmert als gestrichelte Linie.
	_nudge(inst, "Display", -BAND_SEAT_DROP)

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
	_build_line()
	_build_cover()
	_build_chip_pick(z_shift)
	_apply_materials()
	_sync_cover(true)

## Mitte des Sockels i (Chip-X, Welt), gezählt von links.
func socket_x(index: int) -> float:
	return _half - SOCKET_EDGE - ComboPartBody.SOCKET_OUTER.y * 0.5 \
		- float(GameRun.SOCKETS_PER_COMBO - 1 - index) * SOCKET_PITCH

## Rechte Kante der Anzeige (Chip-X, Welt) - bis dorthin reichen Glas und Schrift.
func display_right() -> float:
	return _display_right

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

## Chip-Display: Glasfeld flach auf dem LINKEN Teil des Deckels, darüber die Textzeilen.
## Die Labels hängen an einem eigenen Anker, nicht im Modell.
func _build_screen(z_shift: float) -> void:
	var top := BODY_TOP * _sz
	var back_shift := -(SCREEN_INSET_FRONT - SCREEN_INSET_BACK) / 2.0 * _sz
	var left := -_half + SCREEN_INSET_X * _sx
	var plane := PlaneMesh.new()
	plane.size = Vector2(maxf(_display_right - left, 0.01),
		(BODY_WIDTH - SCREEN_INSET_BACK - SCREEN_INSET_FRONT) * _sz)
	var glass := MeshInstance3D.new()
	glass.name = "ChipScreen"
	glass.mesh = plane
	glass.position = Vector3((left + _display_right) * 0.5, top + SCREEN_LIFT, z_shift + back_shift)
	_screen_material = StandardMaterial3D.new()
	_screen_material.albedo_color = SCREEN_GLASS
	_screen_material.roughness = 0.15
	_screen_material.emission_enabled = true
	_screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = _screen_material
	add_child(glass)

	var board := Node3D.new()
	board.name = "ScreenLabels"
	board.position = Vector3(0.0, top + SCREEN_LIFT + LABEL_LIFT, z_shift + back_shift)
	# Label-+Z zeigt nach oben; Label-+Y läuft Richtung Gehäuse-Rückseite.
	board.rotation.x = -PI / 2.0
	add_child(board)
	# Die Sockel im Chip-Raum, ihr Grund auf der Deckelhöhe.
	_socket_root = Node3D.new()
	_socket_root.name = "Sockets"
	_socket_root.position = Vector3(0.0, top, 0.0)
	add_child(_socket_root)
	_name_label = _make_label(board, NAME_COLOR)
	_points_label = _make_label(board, POINTS_COLOR)
	_mult_label = _make_label(board, MULT_COLOR)
	_state_label = _make_label(board, THROTTLE_COLOR)
	_base_label = _make_label(board, BASE_COLOR)
	_base_label.name = "BaseLabel"

func _make_label(board: Node3D, color: Color) -> Label3D:
	var label := Label3D.new()
	label.font_size = FONT_SIZE
	label.modulate = color
	label.outline_size = 8
	# Mipmaps gegen Flimmern aus der Übersichts-Distanz.
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	board.add_child(label)
	return label

## Übernimmt Name/Wertung/Grundwert der 2D-Zelle - die bleibt die einzige Quelle.
func sync_cell(cell: ComboCellView) -> void:
	var base := Vector2i(cell.base_points, cell.base_mult)
	if cell.combo_name == _name_label.text and cell.points == _points \
			and cell.mult == _mult and base == _base:
		return
	_name_label.text = cell.combo_name
	_points = cell.points
	_mult = cell.mult
	_base = base
	_layout_labels()
	_apply_materials()

## Zeigt der Chip einen anderen Wert als den Grundwert, steht dieser gedimmt daneben.
func shows_base() -> bool:
	return _base.x >= 0 and _base != Vector2i(_points, _mult)

## Zeilenlayout in der Anzeige: Name oben, darunter Punkte, ×Mult und gedimmt der
## Grundwert, rechts in der Namenszeile die Drossel-Marke. Was nicht paßt, schrumpft.
func _layout_labels() -> void:
	var left := -_half + TEXT_MARGIN * _sx
	var right := _display_right - (TEXT_MARGIN - SCREEN_INSET_X) * _sx
	var avail_w := maxf(right - left, 0.01)
	var gap := TEXT_GAP * _sx

	_state_label.text = "AUS" if _throttled else ""
	_state_label.pixel_size = STATE_HEIGHT * _sz / float(FONT_SIZE)
	_points_label.text = str(_points)
	_mult_label.text = "×%d" % _mult
	_base_label.text = "%d ×%d" % [_base.x, _base.y] if shows_base() else ""
	_points_label.pixel_size = SCORE_HEIGHT * _sz / float(FONT_SIZE)
	_mult_label.pixel_size = _points_label.pixel_size
	_base_label.pixel_size = _points_label.pixel_size * BASE_SHARE

	var points_w := _text_width(_points_label)
	var mult_w := _text_width(_mult_label)
	var base_w := _text_width(_base_label)
	var gaps := gap + (gap if base_w > 0.0 else 0.0)
	var needed := points_w + mult_w + base_w
	if needed + gaps > avail_w and needed > 0.0:
		var shrink := maxf(avail_w - gaps, 0.01) / needed
		for label in [_points_label, _mult_label, _base_label]:
			(label as Label3D).pixel_size *= shrink
		points_w *= shrink
		mult_w *= shrink
		base_w *= shrink
	var score_y := SCORE_LINE_Y * _sz
	_points_label.position = Vector3(left + points_w / 2.0, score_y, 0.0)
	_mult_label.position = Vector3(left + points_w + gap + mult_w / 2.0, score_y, 0.0)
	# Der Grundwert sitzt unten bündig mit der Wertung.
	var drop := (_points_label.pixel_size - _base_label.pixel_size) * float(FONT_SIZE) * 0.3
	_base_label.position = Vector3(left + points_w + gap + mult_w + gap + base_w / 2.0,
		score_y - drop, 0.0)
	var state_w := _text_width(_state_label)
	_state_label.position = Vector3(right - state_w / 2.0, NAME_LINE_Y * _sz, 0.0)

	# Name über die volle Anzeige, nur bei Überlänge kleiner.
	var name_ps := NAME_HEIGHT * _sz / float(FONT_SIZE)
	_name_label.pixel_size = name_ps
	var name_w := _text_width(_name_label)
	var avail := avail_w - (state_w + gap if state_w > 0.0 else 0.0)
	# Eine Platine, die in die Namenszeile ragt, begrenzt den Namen.
	avail = minf(avail, _riser_name_limit() - gap - left)
	if name_w > avail and name_w > 0.0:
		_name_label.pixel_size = name_ps * maxf(avail, 0.01) / name_w
		name_w = maxf(avail, 0.01)
	_name_label.position = Vector3(left + name_w / 2.0, NAME_LINE_Y * _sz, 0.0)

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

const ACTIVATION_TIME := 0.6

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

func throttled() -> bool:
	return _throttled

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
	# Hervorhebung zieht Gehäuse, Pins, Band und Leitung ins Gold; glow darf über 1 gehen
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
	_apply_line()

## Verschiebt eine Modellfläche in der Höhe (Modelleinheiten, unskaliert).
func _nudge(inst: Node3D, node_name: String, dy: float) -> void:
	var mesh := inst.find_child(node_name, true, false) as MeshInstance3D
	if mesh != null:
		mesh.position.y += dy

func _override(inst: Node3D, node_name: String, material: StandardMaterial3D) -> void:
	var mesh := inst.find_child(node_name, true, false) as MeshInstance3D
	if mesh != null:
		mesh.material_override = material

# --- Die SIGNALLEITUNG -------------------------------------------------------------

## Vier Abschnitte: Anzeige -> Sockel 0 -> 1 -> 2 -> rechte Gehäusekante.
func _build_line() -> void:
	var line := Node3D.new()
	line.name = "Leitung"
	line.position = Vector3(0.0, BODY_TOP * _sz + LINE_Y, _socket_z)
	add_child(line)
	var stops: Array[float] = [_display_right]
	for i in GameRun.SOCKETS_PER_COMBO:
		stops.append(socket_x(i))
	stops.append(_half)
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for k in stops.size() - 1:
		var segment := Node3D.new()
		segment.name = "Abschnitt%d" % k
		segment.position.x = (stops[k] + stops[k + 1]) * 0.5
		line.add_child(segment)
		var material := StandardMaterial3D.new()
		material.emission_enabled = true
		var strips: Array[MeshInstance3D] = []
		for s in 2:
			var strip := MeshInstance3D.new()
			strip.mesh = unit
			strip.material_override = material
			segment.add_child(strip)
			strips.append(strip)
		_line_segments.append({"node": segment, "strips": strips, "material": material,
			"length": stops[k + 1] - stops[k], "style": LINE_STYLES["gleich"]})

## Der Stil hinter jedem Sockel: das Maximum aller bisher besetzten (nur Grundplätze des Chips).
func _line_styles() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var style: Vector3 = LINE_STYLES["gleich"]
	out.append(style)
	for slot in GameRun.SOCKETS_PER_COMBO:
		var part: ComboPart = socket_part(slot)
		if part != null:
			var own: Vector3 = LINE_STYLES[LINE_STYLE_OF.get(part.id, "gleich")]
			style = Vector3(maxf(style.x, own.x), maxf(style.y, own.y), maxf(style.z, own.z))
		out.append(style)
	return out

## Stil eines Leitungs-Abschnitts (0 = Anzeige bis Sockel 0): Breite, Adern, Licht.
func line_style(segment: int) -> Vector3:
	if segment < 0 or segment >= _line_segments.size():
		return Vector3.ZERO
	return _line_segments[segment]["style"]

func line_energy(segment: int) -> float:
	if segment < 0 or segment >= _line_segments.size():
		return 0.0
	return (_line_segments[segment]["material"] as StandardMaterial3D).emission_energy_multiplier

func _apply_line() -> void:
	if _line_segments.is_empty():
		return
	var styles := _line_styles()
	var lit := clampf(glow, 0.0, 1.0)
	var count := float(_line_segments.size())
	for k in _line_segments.size():
		var entry := _line_segments[k]
		var style: Vector3 = styles[mini(k, styles.size() - 1)]
		entry["style"] = style
		var width := style.x * LINE_WIDTH_SCALE
		var strips: Array[MeshInstance3D] = entry["strips"]
		var doubled := style.y > 1.5
		for s in strips.size():
			var strip := strips[s]
			strip.visible = s == 0 or doubled
			strip.scale = Vector3(float(entry["length"]), LINE_H, width)
			strip.position.z = (width * (float(s) - 0.5) * 2.0) if doubled else 0.0
		var material: StandardMaterial3D = entry["material"]
		var pulse := 0.0
		if _line_pulse >= 0.0:
			pulse = maxf(0.0, 1.0 - absf(_line_pulse * count - (float(k) + 0.5)))
		material.albedo_color = LINE_COLOR.darkened(0.4).lerp(HIGHLIGHT_COLOR, lit)
		material.emission = LINE_COLOR.lerp(HIGHLIGHT_COLOR, lit)
		material.emission_energy_multiplier = style.z * LINE_ENERGY_SHARE \
			+ HIGHLIGHT_LINE_ENERGY * glow + LINE_PULSE_ENERGY * pulse
		if _throttled:
			material.albedo_color = Color(0.05, 0.05, 0.07)
			material.emission_energy_multiplier = 0.0

## Ein Modul feuert: ein Lichtpuls läuft die Leitung von links nach rechts.
func pulse_line() -> void:
	if _line_tween != null and _line_tween.is_valid():
		_line_tween.kill()
	_line_tween = create_tween()
	_line_tween.tween_method(func(t: float) -> void:
		_line_pulse = t
		_apply_line(), 0.0, 1.0 + 1.0 / maxf(float(_line_segments.size()), 1.0), LINE_PULSE_TIME)
	_line_tween.tween_callback(func() -> void:
		_line_pulse = -1.0
		_apply_line())

func line_pulsing() -> bool:
	return _line_pulse >= 0.0

# --- Die ABDECKUNG -----------------------------------------------------------------

## Über der Sockel-Leiste; ihr Gelenk sitzt an der Hinterkante, sie rollt dorthin ein.
func _build_cover() -> void:
	var outer := ComboPartBody.SOCKET_OUTER
	var x0 := socket_x(0) - outer.y * 0.5 - COVER_MARGIN
	var x1 := socket_x(GameRun.SOCKETS_PER_COMBO - 1) + outer.y * 0.5 + COVER_MARGIN
	var depth := outer.x + 2.0 * COVER_MARGIN
	_cover = Node3D.new()
	_cover.name = "Abdeckung"
	_cover.position = Vector3((x0 + x1) * 0.5, BODY_TOP * _sz + COVER_LIFT, _socket_z - depth * 0.5)
	add_child(_cover)
	var plate := MeshInstance3D.new()
	plate.name = "Deckplatte"
	plate.mesh = ComboPartBody.slab_mesh(Vector2(x1 - x0, depth) * 0.5, 0.2, COVER_THICK)
	plate.material_override = _epoxy_material
	plate.position.z = depth * 0.5
	_cover.add_child(plate)
	var dice: Array = DiceScoring.EXAMPLE_DICE.get(combo_key, [])
	if dice.is_empty():
		return
	var face_material := StandardMaterial3D.new()
	face_material.albedo_color = COVER_DIE_FACE
	face_material.roughness = 0.5
	face_material.emission_enabled = true
	face_material.emission = COVER_DIE_FACE
	face_material.emission_energy_multiplier = 0.18
	var pip_material := StandardMaterial3D.new()
	pip_material.albedo_color = COVER_PIP
	pip_material.roughness = 0.7
	var size := minf(COVER_DIE, (x1 - x0 - 0.3) / float(dice.size()) - COVER_DIE_GAP)
	var pitch := size + COVER_DIE_GAP
	var pip := CylinderMesh.new()
	pip.top_radius = size * 0.085
	pip.bottom_radius = size * 0.085
	pip.height = 0.01
	pip.radial_segments = 12
	for i in dice.size():
		var face := MeshInstance3D.new()
		face.name = "Wuerfel%d" % i
		face.mesh = ComboPartBody.slab_mesh(Vector2.ONE * size * 0.5, size * 0.16, 0.03)
		face.material_override = face_material
		face.position = Vector3((float(i) - float(dice.size() - 1) * 0.5) * pitch, COVER_THICK,
			depth * 0.5)
		_cover.add_child(face)
		for at: Vector2 in ComboCellView.PIP_LAYOUTS.get(int(dice[i]), []):
			var dot := MeshInstance3D.new()
			dot.mesh = pip
			dot.material_override = pip_material
			dot.position = Vector3((at.x - 0.5) * size, 0.03 + 0.004, (at.y - 0.5) * size)
			face.add_child(dot)

## scene_root ruft die Abdeckung auf: der Zeiger liegt an der Station auf dem Chip oder ein
## Modul wird umgesteckt.
func set_cover_called(on: bool) -> void:
	if _cover_called == on:
		return
	_cover_called = on
	_sync_cover()

## Offen, solange der Chip ein Modul trägt, ein Einbau oder Umstecken läuft oder sie gerufen ist.
func cover_wanted() -> bool:
	if _cover_called or _beckon_free or _beckon_occupied or _lifted_slot >= 0:
		return true
	for entry in _sockets:
		if entry["part"] != null:
			return true
	return false

func cover_open() -> bool:
	return _cover_open

## Endzustand zuerst: Zustand und Pick-Körper stehen sofort, die Platte fährt nur nach.
func _sync_cover(hard := false) -> void:
	var open := cover_wanted()
	if open == _cover_open and not hard:
		return
	_cover_open = open
	for entry in _sockets:
		var shape: CollisionShape3D = entry.get("pick")
		if shape != null and is_instance_valid(shape):
			shape.disabled = not open
	if _cover == null:
		return
	if _cover_tween != null and _cover_tween.is_valid():
		_cover_tween.kill()
	var goal := 0.001 if open else 1.0
	if hard or not is_inside_tree():
		_cover.scale.z = goal
		_cover.visible = not open
		return
	_cover.visible = true
	_cover_tween = create_tween()
	_cover_tween.tween_property(_cover, "scale:z", goal, COVER_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_cover_tween.tween_callback(func() -> void: _cover.visible = not _cover_open)

## Der harte Weg: die Abdeckung steht sofort, wo der Zustand sie will.
func settle_cover_hard() -> void:
	_sync_cover(true)

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
	_apply_line()
	_sync_cover()
	_apply_part_states()

## Was der Lauf den Modulen dieses Chips meldet: {first_hand, charge, copy} (scene_root).
func set_part_context(context: Dictionary) -> void:
	_part_context = context
	_apply_part_states()

## Je Modul EIN Aufruf seines Zustands-Schreibers: Lauf plus Chip (Würfel, gesteckte Module).
func _apply_part_states() -> void:
	var parts: Array = []
	for entry in _sockets:
		parts.append(entry["part"])
	var state := _part_context.duplicate()
	state["dice"] = DiceScoring.EXAMPLE_DICE.get(combo_key, []).size()
	state["chip_parts"] = ComboPartEffects.part_count(parts)
	for entry in _sockets:
		var body: ComboPartBody = entry["body"]
		if body != null and is_instance_valid(body):
			body.set_state(state)

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

## Weltmitte des Sockelgrunds eines Platzes (Ziel des Geistes und des Hinweises).
func socket_world(slot: int) -> Vector3:
	if slot < 0 or slot >= _sockets.size():
		return global_position
	return (_sockets[slot]["node"] as Node3D).global_position

## Kantenlänge eines Moduls in Welt - überall dieselbe.
func socket_side() -> float:
	return ComboPartBody.SIDE

## Der Zeiger liegt auf diesem Platz (-1 = keinem): sein Rand geht ins Gold.
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
	_sync_cover()

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
	_sync_cover()

func socket_lifted() -> int:
	return _lifted_slot

## Der Einbau: das Teil steckt schon (Endzustand), es fährt nur von oben auf seinen Sockel.
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

## Eine Brücke zündet diesen Chip mit: er leuchtet auf, alle seine Teile mit.
func flash_activation() -> void:
	var rest := glow
	create_tween().tween_method(set_glow, 1.0, rest, ACTIVATION_TIME)
	for slot in _sockets.size():
		flash_socket(slot)

## Ein Teil feuert in der Wertung: sein Körper blitzt, sein Rand mit, und die Leitung pulst.
## strength > 1 ist der Krit-Schlag. Leerer oder fremder Platz = nur Rand bzw. nichts.
## die = Platz des auslösenden Würfels in der Reihe (Punktreihe), -1 = keiner.
func flash_socket(slot: int, strength := 1.0, die := -1) -> void:
	if slot < 0 or slot >= _sockets.size():
		return
	var body: ComboPartBody = _sockets[slot]["body"]
	if body != null and is_instance_valid(body):
		body.flash(strength)
		body.flash_die(die, strength)
		pulse_line()
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

## Wo ein gestecktes Teil ruht: seine Platte über Kontaktfeld und Leitung.
func _part_rest() -> Vector3:
	return Vector3.UP * ComboPartBody.SOCKET_SEAT

## Den Baum neu stecken: die drei Grundplätze stehen auf dem Deckel, jede Platine trägt
## ihr Paar oben (ComboPartEffects.socket_parents ordnet die Zusatzplätze zu). Jeder Sockel
## liegt im Bild aufrecht wie sein Modul; eine Platine auf einer Platine quer zu ihrer Trägerin.
func _build_sockets(parts: Array) -> void:
	for entry in _sockets:
		var node := entry["node"] as Node3D
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_sockets.clear()
	_hover_slot = -1
	_lifted_slot = -1
	var parents := ComboPartEffects.socket_parents(parts, GameRun.SOCKETS_PER_COMBO)
	var tops: Dictionary = {}  # Platinen-Platz -> Zahl der schon vergebenen Sockel
	for slot in parts.size():
		var carrier := parents[slot]
		var host: Node3D = _socket_root
		var spot := Vector3(socket_x(mini(slot, GameRun.SOCKETS_PER_COMBO - 1)), 0.0, _socket_z)
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
		_upright(node)
		var rim := _build_socket_shell(node)
		var pick := _build_socket_pick(node, slot,
			Vector3(ComboPartBody.SOCKET_OUTER.x, 0.3, ComboPartBody.SOCKET_OUTER.y),
			Vector3.UP * 0.03)
		var entry := {"node": node, "rim": rim, "body": null, "part": null,
			"dimmed": false, "carrier": carrier, "tier": tier, "pick": pick}
		_sockets.append(entry)
		var part: ComboPart = parts[slot]
		if ComboPartBody.is_riser(part):
			_spawn_body(slot, part)
	if _chip_pick != null:
		_chip_pick.set_meta("combo_key", combo_key)
	_layout_labels()
	_sync_cover(true)

## Ein Sockel liegt im Bild wie das Modul darauf: eine Vierteldrehung gegen den Chip.
func _upright(node: Node3D) -> void:
	if node.is_inside_tree():
		node.global_basis = global_basis * Basis(Vector3.UP, PI * 0.5)
	else:
		node.rotation.y = PI * 0.5

## Der SOCKEL (code-gebaut, in seinem Raum X quer, Z längs): Stahlrand, schwarzer Grund,
## goldenes Kontaktfeld. Der RAND trägt die Zustände.
func _build_socket_shell(node: Node3D) -> StandardMaterial3D:
	var half := Vector2(ComboPartBody.PLATE.x, ComboPartBody.PLATE.z) * 0.5
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.5, 0.53, 0.6)
	rim.metallic = 0.5
	rim.roughness = 0.4
	rim.emission_enabled = true
	rim.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring := MeshInstance3D.new()
	ring.name = "Rand"
	ring.mesh = _rim_mesh()
	ring.material_override = rim
	node.add_child(ring)
	var ground := MeshInstance3D.new()
	ground.name = "Boden"
	ground.mesh = ComboPartBody.slab_mesh(half, ComboPartBody.PLATE_RADIUS, 0.004)
	ground.material_override = ComboPartBody.shared_material("floor")
	node.add_child(ground)
	var pads := MeshInstance3D.new()
	pads.name = "Kontakte"
	pads.mesh = _pad_mesh()
	pads.material_override = ComboPartBody.shared_material("gold")
	node.add_child(pads)
	return rim

static var _rim_cache: ArrayMesh
static var _pad_cache: ArrayMesh

static func _rim_mesh() -> ArrayMesh:
	if _rim_cache == null:
		var rim := ComboPartBody.SOCKET_RIM
		var h := ComboPartBody.SOCKET_RIM_H
		_rim_cache = ChipFrameView.ring_mesh(ComboPartBody.SOCKET_OUTER * 0.5,
			ComboPartBody.PLATE_RADIUS + rim,
			[Vector2(0.0, 0.0), Vector2(0.0, h), Vector2(rim, h), Vector2(rim, 0.0)])
	return _rim_cache

## Das Kontaktfeld als EIN Netz: 7 quer × 5 längs, ohne die vier Ecken.
static func _pad_mesh() -> ArrayMesh:
	if _pad_cache != null:
		return _pad_cache
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := BoxMesh.new()
	box.size = Vector3(PAD_SIZE, 0.008, PAD_SIZE)
	var arrays := box.get_mesh_arrays()
	for a in PAD_COUNT.x:
		for b in PAD_COUNT.y:
			if (a == 0 or a == PAD_COUNT.x - 1) and (b == 0 or b == PAD_COUNT.y - 1):
				continue
			var at := Vector3((float(a) - float(PAD_COUNT.x - 1) * 0.5) * PAD_PITCH,
				PAD_TOP - 0.004, (float(b) - float(PAD_COUNT.y - 1) * 0.5) * PAD_PITCH)
			tool.append_from(box, 0, Transform3D(Basis.IDENTITY, at))
	_pad_cache = tool.commit()
	return _pad_cache

func _build_socket_pick(node: Node3D, slot: int, size: Vector3, at: Vector3) -> CollisionShape3D:
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
	return shape

func _spawn_body(slot: int, part: ComboPart) -> ComboPartBody:
	var entry := _sockets[slot]
	var body := ComboPartBody.new()
	body.name = "Part"
	(entry["node"] as Node3D).add_child(body)
	body.setup(part)
	body.set_resting(true)
	body.position = _part_rest()
	# Quer liegend rückt die Platine zur Chip-Mitte hin, damit sie im Chip bleibt.
	if int(entry["tier"]) % 2 == 1:
		var toward := -1.0 if to_local((entry["node"] as Node3D).global_position).x > 0.0 else 1.0
		body.rotation.y = PI * 0.5 * toward
	body.visible = slot != _lifted_slot
	if ComboPartBody.is_riser(part):
		# Die Platine selbst bleibt greifbar: ein Pick über ihrer Platte, unter den Sockeln.
		_build_socket_pick(body, slot, ComboPartBody.RISER_BOARD,
			Vector3(0.0, ComboPartBody.RISER_TOP - ComboPartBody.RISER_BOARD.y * 0.5, 0.0))
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
		material.emission = color
		material.emission_energy_multiplier = energy
