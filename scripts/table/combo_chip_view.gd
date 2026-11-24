class_name ComboChipView
extends Node3D
## Eine Kombination als physischer 3D-Chip auf dem Filz (chip_wide.glb aus
## tools/blender_combo_hardware.py, in X und Z gleich skaliert, die Gehäuse-Mitte auf
## BODY_DISPLAY gestaucht) über seiner Zelle, die nur noch als Anker dient
## (ComboCellView.socket_mode). Links die Anzeige, das Frontband und drei glb-Pins; das rechte
## Viertel sind drei FÄCHER zwischen Holmen und Stegen: in jedem steckt sein Modul
## (ComboPartBody) oder das Blindfach - beide mit Beinchen bis auf den Tisch. Ein Rahmen um
## jedes Fach trägt Hover, Einbau-Ruf und Wertungs-Blitz, ein Lichtstrich an der Naht die Art.

const CHIP_SCENE := "res://assets/models/chip_wide.glb"

## Modell-Maße (mm-Einheiten des glb): X-Länge inkl. Pins, Z-Tiefe inkl.
## Display-Band (ragt vorn über), Gehäuse und Deckelhöhe.
const MODEL_LENGTH := 90.1
const MODEL_Z_MIN := -10.0
const MODEL_Z_MAX := 11.0
const BODY_LENGTH := 83.7  # Gehäuse ohne Pins (X)
const BODY_WIDTH := 20.0   # Gehäuse (Z)
const BODY_TOP := 9.0      # Deckelhöhe im Modell (STANDOFF + BODY_H)
## Der ANZEIGE-Teil des Gehäuses nach dem Stauchen (Modell-X): zwischen ±STRETCH_EDGE liegt
## nur Gehäuse-Mitte, dort staucht es, Ecken und linke Pins bleiben in Form.
const BODY_DISPLAY := 38.8
## Die FÄCHER (Welt): rechts an der Naht, so tief wie der Block eines Moduls plus Luft.
const BAY_AIR := 0.012
const BAY := ComboPartBody.BLOCK + BAY_AIR
const BAY_BOTTOM := 0.03
const WEB_AIR := 0.02
const STRETCH_EDGE := 23.85

## Anteil der Zellhöhe, aus dem sich der Maßstab des Chips rechnet (Zelle × FIT / Modell-Tiefe).
const FIT_DEPTH := 0.86
## Welt je Modell-Einheit am echten Tisch (TableScreen.CELL_SIZE bei 37,5 Display-px je Welt):
## daran rechnet pin_offsets_px die Welt-Maße der Plätze in Pixel.
const NOMINAL_SCALE := 0.142181

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

## Hervorhebung der gewürfelten Hand: Gehäuse samt Holmen und Blindfächern, linke Pins und
## Frontband gehen ins Gold; Module, Lichtstriche und Rahmen behalten ihre Farben.
const HIGHLIGHT_COLOR := Color(1.0, 0.81, 0.07)
const HIGHLIGHT_BODY_ENERGY := 0.5
const HIGHLIGHT_PIN_ENERGY := 0.7
const HIGHLIGHT_BAND_ENERGY := 1.2
## Das Deckelglas bleibt Textgrund: KEIN Gold, nur ein Hauch mehr Licht. Mit
## Gold darauf (und dem Bloom des goldenen Gehäuses) verschwand die Schrift.
const HIGHLIGHT_SCREEN_ENERGY := 0.12

## Thermal Throttling (Stresstest): der Chip ist abgeschaltet - das Band glimmt nur noch als
## rote Warnleuchte, das Display zeigt "AUS", Module und Lichtstriche sind dunkel.
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

## Der Lichtstrich an der Naht, je Fach einer (längs, quer; Welt), so weit vor der Naht.
const TILE_LIGHT := Vector2(0.07, 0.5)
const SEAM_LIGHT_BACK := 0.15
const TILE_DIM := Color(0.2, 0.21, 0.26)
const TILE_ENERGY := 1.6
## Linke glb-Pins als Anteile der Gehäusetiefe (ComboCellView.PIN_FRACTIONS).
const PIN_FRACTIONS := [0.28, 0.5, 0.72]
## Die drei PLÄTZE rechts, so weit auseinander, wie die Gehäusetiefe hergibt (Platz 0 = oben).
const SLOT_FRACTIONS := [0.175, 0.5, 0.825]
## Der Rahmen um ein Fach (Welt): Breite und Höhe des Stahlrands auf dem Deckel.
const FRAME_RIM := 0.04
const FRAME_H := 0.02
## Ein Pick-Körper je Platz plus einer über dem Deckel (slot -1 = der Chip selbst): EIN
## Treffer-Pfad für Hover, Einbau und Umstecken.
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
const PLUG_RISE := 0.5   # Steckhub beim Einbau, in Pin-Längen
const PLUG_TIME := 0.22

## Hervorhebung der gewürfelten Hand (0..1): hebt Glas und Band an.
var glow := 0.0
## Die Kombination dieses Chips (scene_root setzt sie VOR setup; reist an den Pick-Körpern).
var combo_key := ""

var _s := 1.0
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
## Je Platz {part, dimmed, pin, empty_pin, holder, frame, tile, flash}.
var _sockets: Array[Dictionary] = []
var _socket_signature := ""
var _part_context: Dictionary = {}
var _z_shift := 0.0
var _half := 0.0
var _display_right := 0.0
var _seam := 0.0
var _hover_slot := -1
var _lifted_slot := -1
var _beckon_free := false
var _beckon_occupied := false
var _beckon_phase := 0.0

## Pin-Positionen der Chips in Screen-Pixeln, relativ zur ZELLMITTE - einzige
## Quelle für alles, was an die Pins andockt (TableScreen verlegt daran die
## LED-Adern). tip_dx = Abstand der Pin-Spitzen links/rechts, rows = die drei
## linken Pin-Höhen (+y = Richtung Frontband, also Bildschirm-unten). Der Chip steht in
## seiner Zelle mittig über seinen Pin-Spitzen (links glb-Pin, rechts der Modul-Pin).
static func pin_offsets_px(cell_size: Vector2) -> Dictionary:
	var per_unit := cell_size.y * FIT_DEPTH / (MODEL_Z_MAX - MODEL_Z_MIN)
	# Modell-Z 0 liegt nicht in der Mitte der Bounding-Box (das Band ragt vorn über).
	var center_z := (MODEL_Z_MIN + MODEL_Z_MAX) / 2.0
	var rows: Array[float] = []
	for f: float in PIN_FRACTIONS:
		rows.append(((f - 0.5) * BODY_WIDTH - center_z) * per_unit)
	var bays: Array[float] = []
	for f: float in SLOT_FRACTIONS:
		bays.append(((f - 0.5) * BODY_WIDTH - center_z) * per_unit)
	return {"tip_dx": tip_span_px(cell_size) / 2.0, "rows": rows, "bays": bays}

## Pixel je Welt-Einheit am Tisch, aus dem Maßstab der Zelle.
static func px_per_world(cell_size: Vector2) -> float:
	return cell_size.y * FIT_DEPTH / (MODEL_Z_MAX - MODEL_Z_MIN) / NOMINAL_SCALE

## Von Pin-Spitze zu Pin-Spitze (Display-px): linker glb-Pin, Anzeige-Teil, Fach samt Beinchen.
static func tip_span_px(cell_size: Vector2) -> float:
	var per_unit := cell_size.y * FIT_DEPTH / (MODEL_Z_MAX - MODEL_Z_MIN)
	return (BODY_DISPLAY + (MODEL_LENGTH - BODY_LENGTH) * 0.5) * per_unit \
		+ (BAY_AIR + ComboPartBody.HULL.x) * px_per_world(cell_size)

## Skaliert das Modell auf die Zelltiefe (Weltmaß, X und Z gleich) und hängt Materialien,
## Labels und Fächer an.
func setup(depth_world: float) -> void:
	_s = depth_world * FIT_DEPTH / (MODEL_Z_MAX - MODEL_Z_MIN)
	var inst := (load(CHIP_SCENE) as PackedScene).instantiate() as Node3D
	inst.scale = Vector3(_s, _s, _s)
	# Modellmitte (das Band ragt vorn über) auf die Zellmitte, die gestauchte Mitte aufs Gehäuse.
	_z_shift = -(MODEL_Z_MAX + MODEL_Z_MIN) / 2.0 * _s
	inst.position = Vector3(-(BODY_LENGTH - BODY_DISPLAY) * 0.5 * _s - BAY * 0.5, 0.0, _z_shift)
	add_child(inst)
	_half = (BODY_DISPLAY * _s + BAY) * 0.5
	_seam = _half - BAY
	_display_right = _seam - SCREEN_INSET_X * _s

	# Das Frontband lehnt im Export GENAU auf Deckelhöhe an - seine obere Kante
	# liegt dann fast koplanar zum Deckel und flimmert als gestrichelte Linie.
	_nudge(inst, "Display", -BAND_SEAT_DROP)

	_display_material = StandardMaterial3D.new()
	_display_material.albedo_color = SCREEN_GLASS
	_display_material.roughness = 0.2
	_display_material.metallic_specular = 0.0  # kein Lichtfleck des Spill-Lichts
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

	_compact(inst)
	_build_screen()
	_build_chip_pick()
	_build_slots()
	_apply_materials()
	_apply_slot_lights()

## Rechte Kante der Anzeige (Chip-X, Welt) - bis dorthin reichen Glas und Schrift.
func display_right() -> float:
	return _display_right

## Chip-X der Naht zwischen Anzeige-Teil und Fächern.
func seam_x() -> float:
	return _seam

## Halbe Gehäuselänge samt Fächern (Welt).
func half_length() -> float:
	return _half

## Chip-Z eines Platzes (0 = oben im Bild).
func row_z(index: int) -> float:
	return _z_shift + (float(SLOT_FRACTIONS[clampi(index, 0, 2)]) - 0.5) * BODY_WIDTH * _s

## Wo das Modul eines Fachs ansetzt: an der Naht, auf dem Tisch.
func pin_anchor(index: int) -> Vector3:
	return Vector3(_seam + BAY_AIR, 0.0, row_z(index))

## Mitte des Lichtstrichs eines Fachs: vor der Naht auf dem Deckel (Chip-Raum).
func tile_center(index: int) -> Vector3:
	return Vector3(_seam - SEAM_LIGHT_BACK, BODY_TOP * _s, row_z(index))

## Wo der Chip-Ursprung relativ zur Zellmitte steht (Chip-X, Welt): die Zelle zentriert die
## Pin-Spitzen.
func origin_offset() -> float:
	var left_pin := (MODEL_LENGTH - BODY_LENGTH) * 0.5 * _s
	return -(ComboPartBody.HULL.x - ComboPartBody.BLOCK - left_pin) * 0.5

## Stellt den Chip auf seine Zellmitte (Welt, im Raum des Elternknotens).
func set_cell(center: Vector3) -> void:
	# Chip-X liegt auf Welt +Z (der Chip liegt um -90° gedreht).
	position = center + basis.x * origin_offset()

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

# --- Das STAUCHEN ------------------------------------------------------------------------

## Gehäuse, Pins und Band einmal gestaucht; die rechten glb-Pins fallen weg - dort stehen
## die Plätze.
func _compact(inst: Node3D) -> void:
	var shift := BODY_LENGTH - BODY_DISPLAY
	for node_name in ["Body", "Pins", "Display"]:
		var mesh_node := inst.find_child(node_name, true, false) as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var fresh := ArrayMesh.new()
		for s in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(s)
			var material := mesh_node.mesh.surface_get_material(s)
			if node_name == "Pins":
				arrays = _left_half(arrays)
			var verts: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
			for i in verts.size():
				verts[i].x = stretched_x(verts[i].x, shift)
			arrays[Mesh.ARRAY_VERTEX] = verts
			fresh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if material != null:
				fresh.surface_set_material(fresh.get_surface_count() - 1, material)
		mesh_node.mesh = fresh

## Nur die Dreiecke links der Mitte (die linken Pins).
static func _left_half(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	else:
		for i in verts.size():
			indices.append(i)
	# Neu nummeriert: auch die Ecken der rechten Pins fallen weg (sonst zählten sie im Hüllquader).
	var remap := {}
	var kept := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		if verts[indices[t]].x < 0.0 and verts[indices[t + 1]].x < 0.0 and verts[indices[t + 2]].x < 0.0:
			for k in 3:
				var old := indices[t + k]
				if not remap.has(old):
					remap[old] = remap.size()
				kept.append(remap[old])
	var order: Array = remap.keys()
	var out := arrays.duplicate()
	for channel in out.size():
		var data = out[channel]
		if channel == Mesh.ARRAY_INDEX or data == null:
			continue
		var per := int(data.size() / verts.size()) if verts.size() > 0 else 1
		var fresh = data.duplicate()
		fresh.resize(order.size() * per)
		for n in order.size():
			for c in per:
				fresh[n * per + c] = data[int(order[n]) * per + c]
		out[channel] = fresh
	out[Mesh.ARRAY_INDEX] = kept
	return out

## Modell-X nach dem Stauchen um shift (Modell-Einheiten): links voll, rechts gar
## nicht, dazwischen linear - die Mitte des Gehäuses staucht.
static func stretched_x(x: float, shift: float) -> float:
	var weight := clampf((STRETCH_EDGE - x) / (2.0 * STRETCH_EDGE), 0.0, 1.0)
	return x + shift * weight

# --- Die ANZEIGE -------------------------------------------------------------------------

## Chip-Display: Glasfeld flach auf dem LINKEN Teil des Deckels, darüber die Textzeilen.
## Die Labels hängen an einem eigenen Anker, nicht im Modell.
func _build_screen() -> void:
	var top := BODY_TOP * _s
	var back_shift := -(SCREEN_INSET_FRONT - SCREEN_INSET_BACK) / 2.0 * _s
	var left := -_half + SCREEN_INSET_X * _s
	var plane := PlaneMesh.new()
	plane.size = Vector2(maxf(_display_right - left, 0.01),
		(BODY_WIDTH - SCREEN_INSET_BACK - SCREEN_INSET_FRONT) * _s)
	var glass := MeshInstance3D.new()
	glass.name = "ChipScreen"
	glass.mesh = plane
	glass.position = Vector3((left + _display_right) * 0.5, top + SCREEN_LIFT, _z_shift + back_shift)
	_screen_material = StandardMaterial3D.new()
	_screen_material.albedo_color = SCREEN_GLASS
	_screen_material.roughness = 0.15
	_screen_material.metallic_specular = 0.0  # kein Lichtfleck des Spill-Lichts
	_screen_material.emission_enabled = true
	_screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = _screen_material
	add_child(glass)

	var board := Node3D.new()
	board.name = "ScreenLabels"
	board.position = Vector3(0.0, top + SCREEN_LIFT + LABEL_LIFT, _z_shift + back_shift)
	# Label-+Z zeigt nach oben; Label-+Y läuft Richtung Gehäuse-Rückseite.
	board.rotation.x = -PI / 2.0
	add_child(board)
	_name_label = _make_label(board, NAME_COLOR)
	_points_label = _make_label(board, POINTS_COLOR)
	_mult_label = _make_label(board, MULT_COLOR)
	_state_label = _make_label(board, THROTTLE_COLOR)
	_layout_labels()

func _make_label(board: Node3D, color: Color) -> Label3D:
	var label := Label3D.new()
	label.font_size = FONT_SIZE
	label.modulate = color
	label.outline_size = 8
	# Mipmaps gegen Flimmern aus der Übersichts-Distanz.
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	board.add_child(label)
	return label

## Übernimmt Name und Wertung der 2D-Zelle - die bleibt die einzige Quelle.
func sync_cell(cell: ComboCellView) -> void:
	if cell.combo_name == _name_label.text and cell.points == _points and cell.mult == _mult:
		return
	_name_label.text = cell.combo_name
	_points = cell.points
	_mult = cell.mult
	_layout_labels()
	_apply_materials()

## Zeilenlayout in der Anzeige: Name oben, darunter Punkte und ×Mult, rechts in der
## Namenszeile die Drossel-Marke. Was nicht paßt, schrumpft.
func _layout_labels() -> void:
	var left := -_half + TEXT_MARGIN * _s
	var right := _display_right - (TEXT_MARGIN - SCREEN_INSET_X) * _s
	var avail_w := maxf(right - left, 0.01)
	var gap := TEXT_GAP * _s

	_state_label.text = "AUS" if _throttled else ""
	_state_label.pixel_size = STATE_HEIGHT * _s / float(FONT_SIZE)
	_points_label.text = str(_points)
	_mult_label.text = "×%d" % _mult
	_points_label.pixel_size = SCORE_HEIGHT * _s / float(FONT_SIZE)
	_mult_label.pixel_size = _points_label.pixel_size

	var points_w := _text_width(_points_label)
	var mult_w := _text_width(_mult_label)
	var needed := points_w + mult_w
	if needed + gap > avail_w and needed > 0.0:
		var shrink := maxf(avail_w - gap, 0.01) / needed
		for label in [_points_label, _mult_label]:
			(label as Label3D).pixel_size *= shrink
		points_w *= shrink
		mult_w *= shrink
	var score_y := SCORE_LINE_Y * _s
	_points_label.position = Vector3(left + points_w / 2.0, score_y, 0.0)
	_mult_label.position = Vector3(left + points_w + gap + mult_w / 2.0, score_y, 0.0)
	var state_w := _text_width(_state_label)
	_state_label.position = Vector3(right - state_w / 2.0, NAME_LINE_Y * _s, 0.0)

	# Name über die volle Anzeige, nur bei Überlänge kleiner.
	var name_ps := NAME_HEIGHT * _s / float(FONT_SIZE)
	_name_label.pixel_size = name_ps
	var name_w := _text_width(_name_label)
	var avail := avail_w - (state_w + gap if state_w > 0.0 else 0.0)
	if name_w > avail and name_w > 0.0:
		_name_label.pixel_size = name_ps * maxf(avail, 0.01) / name_w
		name_w = maxf(avail, 0.01)
	_name_label.position = Vector3(left + name_w / 2.0, NAME_LINE_Y * _s, 0.0)

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
	for slot in _sockets.size():
		_dim_slot(slot)
	_apply_slot_lights()

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
		_apply_slot_lights()

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
	# Hervorhebung zieht Gehäuse, linke Pins und Band ins Gold; glow darf über 1 gehen
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

# --- Die PLÄTZE ----------------------------------------------------------------------------

## Der EINE Schreiber der Belegung: parts = je Platz ComboPart oder null (drei Plätze),
## dimmed = je Platz stillgelegt (Hitzestau). Gleiche Belegung baut nichts neu.
func set_sockets(parts: Array, dimmed: Array = []) -> void:
	var signature := ""
	for slot in parts.size():
		var part: ComboPart = parts[slot]
		var off := slot < dimmed.size() and bool(dimmed[slot])
		signature += "%s:%d:%d;" % [part.id if part != null else "-",
			part.get_instance_id() if part != null else 0, int(off)]
	if signature == _socket_signature:
		return
	_socket_signature = signature
	for slot in _sockets.size():
		_seat_part(slot, parts[slot] if slot < parts.size() else null,
			slot < dimmed.size() and bool(dimmed[slot]))
	_apply_slot_lights()
	_apply_part_states()

## Was der Lauf den Modulen dieses Chips meldet: {first_hand, copy} (scene_root).
func set_part_context(context: Dictionary) -> void:
	_part_context = context
	_apply_part_states()

## Je Modul EIN Aufruf seines Zustands-Schreibers.
func _apply_part_states() -> void:
	var parts: Array = []
	for entry in _sockets:
		parts.append(entry["part"])
	var state := _part_context.duplicate()
	state["dice"] = DiceScoring.EXAMPLE_DICE.get(combo_key, []).size()
	state["chip_parts"] = ComboPartEffects.part_count(parts)
	for entry in _sockets:
		var pin: ComboPartBody = entry["pin"]
		if pin != null and is_instance_valid(pin):
			pin.set_state(state)

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

## Weltpunkt eines Platzes: die Mitte seines Pins auf dem Tisch (Ziel von Geist und Hinweis).
func pin_world(slot: int) -> Vector3:
	if slot < 0 or slot >= _sockets.size():
		return global_position
	return to_global(pin_anchor(slot) + Vector3(ComboPartBody.HULL.x * 0.5, 0.0, 0.0))

## Der Modul-Pin eines Platzes (null = keiner, dort steht der leere Platz).
func pin_body(slot: int) -> ComboPartBody:
	if slot < 0 or slot >= _sockets.size():
		return null
	return _sockets[slot]["pin"]

## Der Zeiger liegt auf diesem Platz (-1 = keinem): Rahmen und Lichtstrich gehen ins Gold.
func set_socket_hover(slot: int) -> void:
	if slot == _hover_slot:
		return
	_hover_slot = slot
	_apply_slot_lights()

## Der EINBAU ruft: freie Plätze atmen, tauschbare belegte schwächer mit.
func set_socket_beckon(free_on: bool, occupied_on: bool) -> void:
	if free_on == _beckon_free and occupied_on == _beckon_occupied:
		return
	_beckon_free = free_on
	_beckon_occupied = occupied_on
	_sync_process()
	_apply_slot_lights()

func socket_beckons(slot: int) -> bool:
	if slot < 0 or slot >= _sockets.size():
		return false
	return _beckon_free if _sockets[slot]["part"] == null else _beckon_occupied

## Umstecken: das gezogene Teil ist in der Hand, sein Platz zeigt leer.
func set_socket_lifted(slot: int) -> void:
	if slot == _lifted_slot:
		return
	_lifted_slot = slot
	for i in _sockets.size():
		_show_slot(i)
	_apply_slot_lights()

func socket_lifted() -> int:
	return _lifted_slot

## Der Einbau: das Teil steckt schon (Endzustand), sein Pin fährt nur von oben auf den Platz.
func play_plug(slot: int) -> void:
	if slot < 0 or slot >= _sockets.size():
		return
	var pin: ComboPartBody = _sockets[slot]["pin"]
	if pin == null or not is_instance_valid(pin):
		return
	pin.flash(1.0)
	pin.position = Vector3.UP * ComboPartBody.SIDE * PLUG_RISE
	var tween := pin.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pin, "position", Vector3.ZERO, PLUG_TIME)

## Eine Brücke zündet diesen Chip mit: er leuchtet auf, alle seine Teile mit.
func flash_activation() -> void:
	var rest := glow
	create_tween().tween_method(set_glow, 1.0, rest, ACTIVATION_TIME)
	for slot in _sockets.size():
		flash_socket(slot)

## Ein Teil feuert in der Wertung: sein Modul blitzt, Rahmen und Lichtstrich mit. strength > 1 ist
## der Krit-Schlag. Ein leerer Platz blitzt nur an Rahmen und Lichtstrich.
func flash_socket(slot: int, strength := 1.0) -> void:
	if slot < 0 or slot >= _sockets.size():
		return
	var pin: ComboPartBody = _sockets[slot]["pin"]
	if pin != null and is_instance_valid(pin):
		pin.flash(strength)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		if slot < _sockets.size():
			_sockets[slot]["flash"] = v
			_apply_slot_lights(),
		strength, 0.0, ComboPartBody.FLASH_TIME * maxf(strength, 1.0))

func socket_flash(slot: int) -> float:
	if slot < 0 or slot >= _sockets.size():
		return 0.0
	return float(_sockets[slot].get("flash", 0.0))

## Licht des Lichtstrichs eines Fachs.
func tile_energy(slot: int) -> float:
	if slot < 0 or slot >= _sockets.size():
		return 0.0
	return (_sockets[slot]["tile"] as StandardMaterial3D).emission_energy_multiplier

func tile_color(slot: int) -> Color:
	if slot < 0 or slot >= _sockets.size():
		return Color.BLACK
	return (_sockets[slot]["tile"] as StandardMaterial3D).emission

## Licht des Rahmens eines Platzes.
func frame_color(slot: int) -> Color:
	if slot < 0 or slot >= _sockets.size():
		return Color.BLACK
	return (_sockets[slot]["frame"] as StandardMaterial3D).emission

## Wer getroffen ist: {key, slot} aus dem Pick-Körper ({} = kein Chip-Körper).
static func pick_of(collider: Object) -> Dictionary:
	if collider == null or not collider.has_meta("combo_key"):
		return {}
	return {"key": String(collider.get_meta("combo_key")),
		"slot": int(collider.get_meta("socket_slot", -1))}

func _build_chip_pick() -> void:
	var pick := StaticBody3D.new()
	pick.name = "ChipPick"
	pick.collision_layer = SOCKET_PICK_LAYER
	pick.collision_mask = 0
	pick.set_meta("combo_key", combo_key)
	pick.set_meta("socket_slot", -1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_half * 2.0, BODY_TOP * _s, BODY_WIDTH * _s)
	shape.shape = box
	shape.position = Vector3(0.0, BODY_TOP * _s * 0.5, _z_shift)
	pick.add_child(shape)
	add_child(pick)

## Die drei Fächer: Holme und Stege, je Fach der Lichtstrich an der Naht und der Platz mit
## Rahmen, Blindfach und Pick-Körper. Einmal gebaut; set_sockets belegt.
func _build_slots() -> void:
	var cap := Node3D.new()
	cap.name = "Faecher"
	add_child(cap)
	_build_bay_walls(cap)
	for slot in GameRun.SOCKETS_PER_COMBO:
		var tile := _build_tile(cap, slot)
		var holder := Node3D.new()
		holder.name = "Pin_%d" % slot
		holder.position = pin_anchor(slot) + Vector3(ComboPartBody.HULL.x * 0.5, 0.0, 0.0)
		cap.add_child(holder)
		# Der Platz liegt im Bild aufrecht wie sein Modul: eine Vierteldrehung gegen den Chip.
		holder.rotation.y = PI * 0.5
		var frame := _build_frame(holder)
		var empty_pin := ComboPartBody.new()
		empty_pin.name = "LeererPlatz"
		holder.add_child(empty_pin)
		empty_pin.setup(null)
		_dress_blank(empty_pin)
		var hull := ComboPartBody.HULL
		var pick := StaticBody3D.new()
		pick.collision_layer = SOCKET_PICK_LAYER
		pick.collision_mask = 0
		pick.set_meta("combo_key", combo_key)
		pick.set_meta("socket_slot", slot)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(hull.y, hull.z, hull.x)
		shape.shape = box
		shape.position = Vector3(0.0, hull.z * 0.5, 0.0)
		pick.add_child(shape)
		holder.add_child(pick)
		_sockets.append({"part": null, "dimmed": false, "pin": null, "empty_pin": empty_pin,
			"holder": holder, "frame": frame, "tile": tile})

## Zwei Holme verlängern die Langseiten des Gehäuses, zwei Stege trennen die Fächer.
func _build_bay_walls(cap: Node3D) -> void:
	var top := BODY_TOP * _s
	var depth := BODY_WIDTH * _s * 0.5
	var module := ComboPartBody.HULL.y * 0.5 + WEB_AIR * 0.5
	var bars: Array = []  # [Mitte Z, Dicke]
	for side in [0, 2]:
		var inner := row_z(side) + (module if side == 2 else -module)
		var outer := _z_shift + (depth if side == 2 else -depth)
		bars.append([(inner + outer) * 0.5, absf(outer - inner)])
	for i in 2:
		bars.append([(row_z(i) + row_z(i + 1)) * 0.5, row_z(i + 1) - row_z(i) - module * 2.0])
	for i in bars.size():
		if float(bars[i][1]) < 0.01:
			continue
		var wall := MeshInstance3D.new()
		wall.name = "Holm%d" % i if i < 2 else "Steg%d" % (i - 2)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(BAY, top - BAY_BOTTOM, float(bars[i][1]))
		wall.mesh = mesh
		wall.material_override = _epoxy_material
		wall.position = Vector3(_seam + BAY * 0.5, (top + BAY_BOTTOM) * 0.5, float(bars[i][0]))
		cap.add_child(wall)

## Das Blindfach trägt die Materialien des Chips: es geht mit ihm ins Gold.
func _dress_blank(blank: ComboPartBody) -> void:
	for pair in [["Gehaeuse", _epoxy_material], ["Bein", _pins_material], ["Glas", _screen_material]]:
		var mesh := blank.find_child(pair[0], true, false) as MeshInstance3D
		if mesh != null:
			mesh.material_override = pair[1]

## Der Rahmen eines Fachs: ein dünner Stahlrand um den Block, auf dem Deckel.
func _build_frame(holder: Node3D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.53, 0.6)
	material.metallic = 0.5
	material.roughness = 0.4
	material.emission_enabled = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring := MeshInstance3D.new()
	ring.name = "Rand"
	ring.mesh = _frame_mesh()
	ring.material_override = material
	ring.position = Vector3(0.0, BODY_TOP * _s, -(ComboPartBody.HULL.x - ComboPartBody.BLOCK) * 0.5)
	holder.add_child(ring)
	return material

static var _frame_cache: ArrayMesh

static func _frame_mesh() -> ArrayMesh:
	if _frame_cache == null:
		var half := Vector2(ComboPartBody.HULL.y, ComboPartBody.BLOCK) * 0.5 + Vector2.ONE * FRAME_RIM
		_frame_cache = ChipFrameView.ring_mesh(half, 0.1,
			[Vector2(0.0, 0.0), Vector2(0.0, FRAME_H), Vector2(FRAME_RIM, FRAME_H), Vector2(FRAME_RIM, 0.0)])
	return _frame_cache

## Der Lichtstrich eines Fachs an der Naht: die Farbe der Modulart, leer dunkel.
func _build_tile(cap: Node3D, slot: int) -> StandardMaterial3D:
	var light := MeshInstance3D.new()
	light.name = "NahtLicht_%d" % slot
	var strip := BoxMesh.new()
	strip.size = Vector3(TILE_LIGHT.x, 0.012, TILE_LIGHT.y)
	light.mesh = strip
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.roughness = 0.4
	light.material_override = material
	light.position = tile_center(slot) + Vector3(0.0, SCREEN_LIFT, 0.0)
	cap.add_child(light)
	return material

## Steckt ein Teil: sein Modul füllt das Fach.
func _seat_part(slot: int, part: ComboPart, off: bool) -> void:
	var entry := _sockets[slot]
	var old: ComboPartBody = entry["pin"]
	if old != null and (not is_instance_valid(old) or old.part != part):
		if is_instance_valid(old):
			old.get_parent().remove_child(old)
			old.queue_free()
		entry["pin"] = null
	if part != null and entry["pin"] == null:
		var pin := ComboPartBody.new()
		pin.name = "ModulPin"
		(entry["holder"] as Node3D).add_child(pin)
		pin.setup(part)
		pin.set_resting(true)
		entry["pin"] = pin
	entry["part"] = part
	entry["dimmed"] = off
	_dim_slot(slot)
	_show_slot(slot)

## Hitzestau und Drossel nehmen dem Pin das Licht.
func _dim_slot(slot: int) -> void:
	var entry := _sockets[slot]
	var pin: ComboPartBody = entry["pin"]
	if pin != null and is_instance_valid(pin):
		pin.set_dimmed(bool(entry["dimmed"]) or _throttled)

## Was in einem Fach steht: das Modul, sonst (auch gehoben) das Blindfach.
func _show_slot(slot: int) -> void:
	var entry := _sockets[slot]
	var pin: ComboPartBody = entry["pin"]
	var module_pin := pin != null and is_instance_valid(pin) and slot != _lifted_slot
	if pin != null and is_instance_valid(pin):
		pin.visible = module_pin
	(entry["empty_pin"] as Node3D).visible = not module_pin

## Rahmen und Lichtstrich je Fach: Ruhe, Hover, Einbau-Ruf, Wertungs-Blitz, Drossel.
func _apply_slot_lights() -> void:
	var pulse := 0.5 + 0.5 * sin(_beckon_phase)
	for slot in _sockets.size():
		var entry := _sockets[slot]
		var part: ComboPart = entry["part"]
		var shown: ComboPart = part if slot != _lifted_slot else null
		var color := SOCKET_RIM_COLOR
		var energy := SOCKET_RIM_ENERGY
		if socket_beckons(slot):
			color = SOCKET_BECKON_COLOR
			energy = SOCKET_BECKON_BASE + SOCKET_BECKON_SWING * pulse
			if part != null:
				energy *= SOCKET_SWAP_SHARE
		if slot == _hover_slot:
			color = SOCKET_HOVER_COLOR
			energy = SOCKET_HOVER_ENERGY
		var lit := float(entry.get("flash", 0.0))
		if lit > 0.0:
			color = color.lerp(part.tint() if part != null else SOCKET_HOVER_COLOR, minf(lit, 1.0))
			energy += SOCKET_HOVER_ENERGY * lit
		var frame: StandardMaterial3D = entry["frame"]
		frame.emission = color
		frame.emission_energy_multiplier = energy
		# Ein Blindfach trägt in Ruhe keinen Rahmen: er erscheint, wenn es ruft, gemeint ist oder blitzt.
		var ring := (entry["holder"] as Node3D).get_node_or_null("Rand") as Node3D
		if ring != null:
			ring.visible = shown != null or socket_beckons(slot) or slot == _hover_slot or lit > 0.0
		# Der Lichtstrich trägt die Modulfarbe; leer bleibt er dunkel.
		var tone := shown.tint() if shown != null else TILE_DIM
		var tile_energy := TILE_ENERGY if shown != null else 0.15
		if slot == _hover_slot:
			tone = SOCKET_HOVER_COLOR
			tile_energy = SOCKET_HOVER_ENERGY
		elif socket_beckons(slot):
			tone = SOCKET_BECKON_COLOR
			tile_energy = energy
		tile_energy += SOCKET_HOVER_ENERGY * lit
		var dark := _throttled or bool(entry["dimmed"])
		_glow(entry["tile"], tone, 0.1 if dark else tile_energy)

func _glow(material: StandardMaterial3D, color: Color, energy: float) -> void:
	material.albedo_color = color.darkened(0.5) if energy > 0.2 else Color(0.05, 0.05, 0.07)
	material.emission = color
	material.emission_energy_multiplier = energy
