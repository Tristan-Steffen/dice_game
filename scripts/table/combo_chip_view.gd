class_name ComboChipView
extends Node3D
## Eine Kombination als physischer 3D-Chip auf dem Filz (chip_wide.glb aus
## tools/blender_combo_hardware.py, in X und Z gleich skaliert) über seiner Zelle, die nur
## noch als Anker dient (ComboCellView.socket_mode). Zwei Zustände: KOMPAKT (Regel) trägt
## Anzeige, Frontband, links drei Pins und rechts eine ENDKAPPE mit drei Kacheln und den drei
## MODUL-PINS; AUSGEFAHREN steht zwischen Anzeige und Endkappe die Sockelzone mit drei
## Sockeln, je einer eigenen Leitung zu SEINEM Pin. Der Chip-Raum ist der ausgefahrene: kompakt
## rückt alles links der Sockelzone um compact_shift() nach rechts, das Gehäuse schiebt sich
## zusammen (die Mitte des Netzes staucht, Pins und Ecken bleiben in Form).

const CHIP_SCENE := "res://assets/models/chip_wide.glb"

## Modell-Maße (mm-Einheiten des glb): X-Länge inkl. Pins, Z-Tiefe inkl.
## Display-Band (ragt vorn über), Gehäuse und Deckelhöhe.
const MODEL_LENGTH := 90.1
const MODEL_Z_MIN := -10.0
const MODEL_Z_MAX := 11.0
const BODY_LENGTH := 83.7  # Gehäuse ohne Pins (X)
const BODY_WIDTH := 20.0   # Gehäuse (Z)
const BODY_TOP := 9.0      # Deckelhöhe im Modell (STANDOFF + BODY_H)
## Zwischen ±STRETCH_EDGE (Modell-X) liegt nur Gehäuse-Mitte: dort staucht das Zusammenschieben.
const STRETCH_EDGE := 23.85

## Anteil der Zelle, aus dem sich der Maßstab des Chips rechnet (Zelle × FIT / Modell-Länge).
const FIT_LENGTH := 0.95
const FIT_DEPTH := 0.86
## Welt je Modell-Einheit am echten Tisch (TableScreen.CELL_SIZE bei 37,5 Display-px je Welt):
## daran rechnet pin_offsets_px die Welt-Maße der Sockelzone in Pixel.
const NOMINAL_SX := 0.142181

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

## Hervorhebung der gewürfelten Hand: Gehäuse samt Endkappe, linke Pins und Frontband gehen
## ins Gold; Modul-Pins, Kacheln, Sockel, Leitungen und Module behalten ihre Farben.
const HIGHLIGHT_COLOR := Color(1.0, 0.81, 0.07)
const HIGHLIGHT_BODY_ENERGY := 0.5
const HIGHLIGHT_PIN_ENERGY := 0.7
const HIGHLIGHT_BAND_ENERGY := 1.2
## Das Deckelglas bleibt Textgrund: KEIN Gold, nur ein Hauch mehr Licht. Mit
## Gold darauf (und dem Bloom des goldenen Gehäuses) verschwand die Schrift.
const HIGHLIGHT_SCREEN_ENERGY := 0.12

## Thermal Throttling (Stresstest): der Chip ist abgeschaltet - das Band glimmt nur noch als
## rote Warnleuchte, das Display zeigt "AUS", Modul-Pins, Kacheln und Leitungen sind dunkel.
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

## Die ENDKAPPE (Welt): rechts am Gehäuse, je Pin-Reihe eine Kachel mit einem Lichtstrich.
const CAP := 0.72
const TILE := Vector2(0.52, 0.5)  # längs, quer
const TILE_LIGHT := Vector2(0.08, 0.4)
const TILE_COLOR := Color(0.09, 0.09, 0.12)
const TILE_DIM := Color(0.2, 0.21, 0.26)
const TILE_ENERGY := 1.6
## Pin-Reihen als Anteile der Gehäusetiefe (ComboCellView.PIN_FRACTIONS), Sockel 0 = oben im Bild.
const PIN_FRACTIONS := [0.28, 0.5, 0.72]
## Die SOCKEL (Welt): Teilung längs des Chips, Fuge zur Endkappe, Luft zur Anzeige; die
## kompakte Anzeige endet DISPLAY_CAP_GAP vor der Endkappe.
const SOCKET_PITCH := 1.85
const SOCKET_GAP := 0.2
const DISPLAY_GAP := 0.4
const DISPLAY_CAP_GAP := 0.15
## Kontaktfeld: 5 längs × 7 quer Gold-Pads ohne die vier Ecken.
const PAD_COUNT := Vector2i(7, 5)
const PAD_PITCH := 0.24
const PAD_SIZE := 0.1
const PAD_TOP := 0.016
## Ein Pick-Körper je Sockel und je Pin plus einer über dem Deckel (slot -1 = der Chip
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

## Je Sockel EINE Leitung zu seinem Pin, flach auf dem Deckel (unter den Platten durch).
const LINE_Y := 0.02
const LINE_H := 0.006
const LINE_WIDTH := 0.09
const LINE_EMPTY_WIDTH := 0.05
const LINE_ENERGY := 1.2
const LINE_DIP := 0.3  # Länge des Knicks von der Sockelmitte auf die Pin-Reihe

## Das AUSFAHREN: erst schiebt sich das Gehäuse auseinander, dann steigen die Sockel aus dem
## Deckel (eingefahren in umgekehrter Folge). SOCKET_SINK = so tief liegen sie eingefahren.
const EXTEND_TIME := 0.45
const BODY_SHARE := 0.6
const SOCKET_SINK := 0.8

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
## Je Platz {node, rim, body, part, dimmed, pick, pin, empty_pin, holder, tile, line, flash}.
var _sockets: Array[Dictionary] = []
var _socket_signature := ""
var _part_context: Dictionary = {}
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
var _chip_pick_shape: CollisionShape3D
var _glass: MeshInstance3D
var _board: Node3D
## Gehäuse, linke Pins und Band als Rohdaten zum Zusammenschieben: je Netz {mesh, surfaces}.
var _stretch_meshes: Array[Dictionary] = []
## _extended ist der ENDZUSTAND, _ext der gezeigte Stand (0 = kompakt, 1 = ausgefahren).
var _extended := false
var _ext := 0.0
var _ext_tween: Tween
## Zellmitten beider Zustände (Welt, im Raum des Elternknotens) - der Chip steht an der seines Stands.
var _cell_compact := Vector3.ZERO
var _cell_wide := Vector3.ZERO
var _cells_known := false

## Pin-Positionen der Chips in Screen-Pixeln, relativ zur ZELLMITTE - einzige
## Quelle für alles, was an die Pins andockt (TableScreen verlegt daran die
## LED-Adern). tip_dx = Abstand der Pin-Spitzen links/rechts, rows = die drei
## Pin-Höhen (+y = Richtung Frontband, also Bildschirm-unten). cell_size ist IMMER die
## ausgefahrene Zelle (sie gibt den Maßstab); der Chip steht in jeder Zelle mittig über
## seinen Pin-Spitzen (links glb-Pin, rechts der Modul-Pin).
static func pin_offsets_px(cell_size: Vector2, extended := true) -> Dictionary:
	var per_unit := cell_size.y * FIT_DEPTH / (MODEL_Z_MAX - MODEL_Z_MIN)
	# Modell-Z 0 liegt nicht in der Mitte der Bounding-Box (das Band ragt vorn über).
	var center_z := (MODEL_Z_MIN + MODEL_Z_MAX) / 2.0
	var rows: Array[float] = []
	for f: float in PIN_FRACTIONS:
		rows.append(((f - 0.5) * BODY_WIDTH - center_z) * per_unit)
	return {"tip_dx": tip_span_px(cell_size, extended) / 2.0, "rows": rows}

## Pixel je Welt-Einheit am Tisch, aus dem Maßstab der Zelle.
static func px_per_world(cell_size: Vector2) -> float:
	return cell_size.x * FIT_LENGTH / MODEL_LENGTH / NOMINAL_SX

## Von Pin-Spitze zu Pin-Spitze (Display-px): linker glb-Pin, Gehäuse, Modul-Pin.
static func tip_span_px(cell_size: Vector2, extended := true) -> float:
	var per_model := cell_size.x * FIT_LENGTH / MODEL_LENGTH
	var span := (BODY_LENGTH + (MODEL_LENGTH - BODY_LENGTH) * 0.5) * per_model \
		+ ComboPartBody.PIN_HULL.x * px_per_world(cell_size)
	return span if extended else span - compact_shift() * px_per_world(cell_size)

## Breite der kompakten Zelle (Display-px): die ausgefahrene ohne die Sockelzone.
static func compact_cell_width(cell_size: Vector2) -> float:
	return cell_size.x - compact_shift() * px_per_world(cell_size)

## Wie weit das Gehäuse beim Einfahren zusammengeht (Welt): Sockelzone samt Fugen.
static func compact_shift() -> float:
	return SOCKET_GAP + ComboPartBody.SOCKET_OUTER.y + 2.0 * SOCKET_PITCH + DISPLAY_GAP - DISPLAY_CAP_GAP

## Skaliert das Modell in die Zellfläche (Weltmaße) und hängt Materialien, Labels,
## Endkappe, Sockel und Pins an. length = AUSGEFAHRENE Zellbreite (Modell-X), depth = Zellhöhe.
## Der Chip beginnt KOMPAKT.
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

	_prepare_stretch(inst)
	_build_screen(z_shift)
	_build_chip_pick(z_shift)
	_build_sockets()
	_apply_materials()
	_apply_socket_rims()
	_write_extension(0.0)

## Mitte des Sockels i (Chip-X, Welt), gezählt von links.
func socket_x(index: int) -> float:
	return _half - CAP - SOCKET_GAP - ComboPartBody.SOCKET_OUTER.y * 0.5 \
		- float(GameRun.SOCKETS_PER_COMBO - 1 - index) * SOCKET_PITCH

## Rechte Kante der Anzeige im ausgefahrenen Chip-Raum (Welt) - bis dorthin reichen Glas und Schrift.
func display_right() -> float:
	return _display_right

## Chip-Z einer Pin-Reihe (0 = oben im Bild).
func row_z(index: int) -> float:
	return _z_shift + (float(PIN_FRACTIONS[clampi(index, 0, 2)]) - 0.5) * BODY_WIDTH * _sz

## Wo der Pin eines Platzes ansetzt: an der rechten Gehäusekante, auf dem Tisch.
func pin_anchor(index: int) -> Vector3:
	return Vector3(_half, 0.0, row_z(index))

## Mitte der Kachel eines Platzes auf der Endkappe (Chip-Raum).
func tile_center(index: int) -> Vector3:
	return Vector3(_half - CAP * 0.5, BODY_TOP * _sz, row_z(index))

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

# --- Das ZUSAMMENSCHIEBEN ----------------------------------------------------------------

## Merkt sich Gehäuse, Pins und Band als Rohdaten; die rechten glb-Pins fallen weg - dort
## stehen die Pins der Sockel.
func _prepare_stretch(inst: Node3D) -> void:
	for node_name in ["Body", "Pins", "Display"]:
		var mesh_node := inst.find_child(node_name, true, false) as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var surfaces: Array = []
		for s in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(s)
			if node_name == "Pins":
				arrays = _left_half(arrays)
			surfaces.append({"arrays": arrays, "material": mesh_node.mesh.surface_get_material(s)})
		var fresh := ArrayMesh.new()
		mesh_node.mesh = fresh
		_stretch_meshes.append({"mesh": fresh, "surfaces": surfaces})

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

## Modell-X nach dem Zusammenschieben um shift (Modell-Einheiten): links voll, rechts gar
## nicht, dazwischen linear - die Mitte des Gehäuses staucht.
static func stretched_x(x: float, shift: float) -> float:
	var weight := clampf((STRETCH_EDGE - x) / (2.0 * STRETCH_EDGE), 0.0, 1.0)
	return x + shift * weight

func _write_body(shift_world: float) -> void:
	var shift := shift_world / _sx
	for entry in _stretch_meshes:
		var mesh: ArrayMesh = entry["mesh"]
		mesh.clear_surfaces()
		for surface: Dictionary in entry["surfaces"]:
			var arrays: Array = (surface["arrays"] as Array).duplicate()
			var verts: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
			for i in verts.size():
				verts[i].x = stretched_x(verts[i].x, shift)
			arrays[Mesh.ARRAY_VERTEX] = verts
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if surface["material"] != null:
				mesh.surface_set_material(mesh.get_surface_count() - 1, surface["material"])

# --- Das AUSFAHREN -----------------------------------------------------------------------

## So weit (Welt) steht gerade alles links der Sockelzone nach rechts gerückt.
func shift_now() -> float:
	return compact_shift() * (1.0 - clampf(_ext / BODY_SHARE, 0.0, 1.0))

## Wo der Chip-Ursprung relativ zur Zellmitte steht (Chip-X, Welt): die Zelle zentriert die
## Pin-Spitzen, und kompakt fehlt links die Sockelzone.
func origin_offset(extended: bool) -> float:
	var left_pin := (MODEL_LENGTH - BODY_LENGTH) * 0.5 * _sx
	var shift := 0.0 if extended else compact_shift()
	return -(ComboPartBody.PIN_HULL.x - left_pin + shift) * 0.5

## Die Zellmitten beider Zustände (Welt) - scene_root meldet sie.
func set_cells(compact_center: Vector3, wide_center: Vector3) -> void:
	_cell_compact = compact_center
	_cell_wide = wide_center
	_cells_known = true
	_write_extension(_ext)

## Der EINE Eingang: Endzustand zuerst (Pick-Körper stehen sofort), dann fährt der Körper
## (time 0 = hart).
func set_extended(on: bool, time := EXTEND_TIME) -> void:
	var goal := 1.0 if on else 0.0
	var running := _ext_tween != null and _ext_tween.is_valid()
	if on == _extended and (running or is_equal_approx(_ext, goal)):
		return
	_extended = on
	_sync_picks()
	if running:
		_ext_tween.kill()
	if time <= 0.0 or not is_inside_tree():
		_write_extension(goal)
		return
	_ext_tween = create_tween()
	_ext_tween.tween_method(_write_extension, _ext, goal, time * absf(goal - _ext)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

## Der harte Weg: der Körper steht sofort, wo der Zustand ihn will.
func settle_extension_hard() -> void:
	if _ext_tween != null and _ext_tween.is_valid():
		_ext_tween.kill()
	_write_extension(1.0 if _extended else 0.0)

func extended() -> bool:
	return _extended

## Der gezeigte Stand (0 = kompakt, 1 = ausgefahren).
func extension() -> float:
	return _ext

func extension_running() -> bool:
	return _ext_tween != null and _ext_tween.is_valid()

## Der EINE Schreiber des gezeigten Stands: Gehäuse, Anzeige, Ursprung, Sockelzone.
func _write_extension(value: float) -> void:
	_ext = clampf(value, 0.0, 1.0)
	var shift := shift_now()
	_write_body(shift)
	if _glass != null:
		_glass.position.x = _glass_center() + shift
		_board.position.x = shift
	if _chip_pick_shape != null:
		var box := _chip_pick_shape.shape as BoxShape3D
		box.size.x = maxf(BODY_LENGTH * _sx - shift, 0.1)
		_chip_pick_shape.position.x = shift * 0.5
	if _socket_root != null:
		var rise := clampf((_ext - BODY_SHARE) / (1.0 - BODY_SHARE), 0.0, 1.0)
		_socket_root.position.y = BODY_TOP * _sz - SOCKET_SINK * (1.0 - rise)
		_socket_root.visible = rise > 0.0
	if _cells_known:
		var body_share := clampf(_ext / BODY_SHARE, 0.0, 1.0)
		# Chip-X liegt auf Welt +Z (der Chip liegt um -90° gedreht).
		position = _origin_at(false).lerp(_origin_at(true), body_share)

func _origin_at(extended: bool) -> Vector3:
	var cell := _cell_wide if extended else _cell_compact
	return cell + basis.x * origin_offset(extended)

## Endzustand zuerst: Sockel nehmen den Zeiger nur ausgefahren, Pins immer.
func _sync_picks() -> void:
	for entry in _sockets:
		var shape: CollisionShape3D = entry.get("pick")
		if shape != null and is_instance_valid(shape):
			shape.disabled = not _extended

# --- Die ANZEIGE -------------------------------------------------------------------------

func _glass_center() -> float:
	return (-_half + SCREEN_INSET_X * _sx + _display_right) * 0.5

## Chip-Display: Glasfeld flach auf dem LINKEN Teil des Deckels, darüber die Textzeilen.
## Die Labels hängen an einem eigenen Anker, nicht im Modell.
func _build_screen(z_shift: float) -> void:
	var top := BODY_TOP * _sz
	var back_shift := -(SCREEN_INSET_FRONT - SCREEN_INSET_BACK) / 2.0 * _sz
	var left := -_half + SCREEN_INSET_X * _sx
	var plane := PlaneMesh.new()
	plane.size = Vector2(maxf(_display_right - left, 0.01),
		(BODY_WIDTH - SCREEN_INSET_BACK - SCREEN_INSET_FRONT) * _sz)
	_glass = MeshInstance3D.new()
	_glass.name = "ChipScreen"
	_glass.mesh = plane
	_glass.position = Vector3(_glass_center(), top + SCREEN_LIFT, z_shift + back_shift)
	_screen_material = StandardMaterial3D.new()
	_screen_material.albedo_color = SCREEN_GLASS
	_screen_material.roughness = 0.15
	_screen_material.emission_enabled = true
	_screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass.material_override = _screen_material
	add_child(_glass)

	_board = Node3D.new()
	_board.name = "ScreenLabels"
	_board.position = Vector3(0.0, top + SCREEN_LIFT + LABEL_LIFT, z_shift + back_shift)
	# Label-+Z zeigt nach oben; Label-+Y läuft Richtung Gehäuse-Rückseite.
	_board.rotation.x = -PI / 2.0
	add_child(_board)
	_name_label = _make_label(_board, NAME_COLOR)
	_points_label = _make_label(_board, POINTS_COLOR)
	_mult_label = _make_label(_board, MULT_COLOR)
	_state_label = _make_label(_board, THROTTLE_COLOR)
	_base_label = _make_label(_board, BASE_COLOR)
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
	if name_w > avail and name_w > 0.0:
		_name_label.pixel_size = name_ps * maxf(avail, 0.01) / name_w
		name_w = maxf(avail, 0.01)
	_name_label.position = Vector3(left + name_w / 2.0, NAME_LINE_Y * _sz, 0.0)

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
	_apply_socket_rims()

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

# --- Die STECKPLÄTZE ---------------------------------------------------------------------

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
	_apply_socket_rims()
	_apply_part_states()

## Was der Lauf den Modulen dieses Chips meldet: {first_hand, copy} (scene_root).
func set_part_context(context: Dictionary) -> void:
	_part_context = context
	_apply_part_states()

## Je Modul EIN Aufruf seines Zustands-Schreibers - am großen Modul UND an seinem Pin.
func _apply_part_states() -> void:
	var parts: Array = []
	for entry in _sockets:
		parts.append(entry["part"])
	var state := _part_context.duplicate()
	state["dice"] = DiceScoring.EXAMPLE_DICE.get(combo_key, []).size()
	state["chip_parts"] = ComboPartEffects.part_count(parts)
	for entry in _sockets:
		for key in ["body", "pin"]:
			var body: ComboPartBody = entry[key]
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

## Weltmitte des Sockelgrunds eines Platzes im AUSGEFAHRENEN Stand (Ziel des Geistes und des
## Hinweises) - auch während der Chip noch fährt.
func socket_world(slot: int) -> Vector3:
	if slot < 0 or slot >= _sockets.size():
		return global_position
	var local := (_sockets[slot]["node"] as Node3D).position + Vector3(0.0, BODY_TOP * _sz, 0.0)
	var xform := global_transform
	if _cells_known:
		var parent := get_parent() as Node3D
		var parent_xform := parent.global_transform if parent != null else Transform3D.IDENTITY
		xform = Transform3D(global_basis, parent_xform * _origin_at(true))
	return xform * local

## Weltpunkt des Pins eines Platzes (seine Mitte auf dem Tisch).
func pin_world(slot: int) -> Vector3:
	if slot < 0 or slot >= _sockets.size():
		return global_position
	return to_global(pin_anchor(slot) + Vector3(ComboPartBody.PIN_HULL.x * 0.5, 0.0, 0.0))

## Der Modul-Pin eines Platzes (null = keiner, dort steht der leere Stahlpin).
func pin_body(slot: int) -> ComboPartBody:
	if slot < 0 or slot >= _sockets.size():
		return null
	return _sockets[slot]["pin"]

## Kantenlänge eines Moduls in Welt - überall dieselbe.
func socket_side() -> float:
	return ComboPartBody.SIDE

## Der Zeiger liegt auf diesem Platz (-1 = keinem): Rand und Kachel gehen ins Gold.
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

## Umstecken: das gezogene Teil ist in der Hand, sein Platz zeigt leer - auch sein Pin.
func set_socket_lifted(slot: int) -> void:
	if slot == _lifted_slot:
		return
	_lifted_slot = slot
	for i in _sockets.size():
		_show_slot(i)
	_apply_socket_rims()

func socket_lifted() -> int:
	return _lifted_slot

## Der Einbau: das Teil steckt schon (Endzustand), es fährt nur von oben auf seinen Sockel.
func play_plug(slot: int) -> void:
	if slot < 0 or slot >= _sockets.size():
		return
	var pin: ComboPartBody = _sockets[slot]["pin"]
	if pin != null and is_instance_valid(pin):
		pin.flash(1.0)
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

## Ein Teil feuert in der Wertung: sein Pin blitzt, Kachel und Leitung mit, und ausgefahren
## auch Körper und Sockelrand. strength > 1 ist der Krit-Schlag. Ein leerer Platz blitzt nur
## an Rand und Kachel. die = Platz des auslösenden Würfels in der Reihe (Punktreihe), -1 = keiner.
func flash_socket(slot: int, strength := 1.0, die := -1) -> void:
	if slot < 0 or slot >= _sockets.size():
		return
	for key in ["body", "pin"]:
		var body: ComboPartBody = _sockets[slot][key]
		if body != null and is_instance_valid(body):
			body.flash(strength)
			body.flash_die(die, strength)
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

## Licht der Kachel eines Platzes.
func tile_energy(slot: int) -> float:
	if slot < 0 or slot >= _sockets.size():
		return 0.0
	return (_sockets[slot]["tile"] as StandardMaterial3D).emission_energy_multiplier

func tile_color(slot: int) -> Color:
	if slot < 0 or slot >= _sockets.size():
		return Color.BLACK
	return (_sockets[slot]["tile"] as StandardMaterial3D).emission

## Licht der Leitung eines Platzes.
func line_energy(slot: int) -> float:
	if slot < 0 or slot >= _sockets.size():
		return 0.0
	return (_sockets[slot]["line"] as StandardMaterial3D).emission_energy_multiplier

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
	_chip_pick_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BODY_LENGTH * _sx, BODY_TOP * _sz, BODY_WIDTH * _sz)
	_chip_pick_shape.shape = box
	_chip_pick_shape.position = Vector3(0.0, BODY_TOP * _sz * 0.5, z_shift)
	_chip_pick.add_child(_chip_pick_shape)
	add_child(_chip_pick)

## Wo ein gestecktes Teil ruht: seine Platte über Kontaktfeld und Leitung.
func _part_rest() -> Vector3:
	return Vector3.UP * ComboPartBody.SOCKET_SEAT

## Die drei Plätze: je ein Sockel in der Sockelzone samt Leitung zur Endkappe, eine Kachel auf
## der Endkappe und ein Pin an der rechten Kante. Einmal gebaut; set_sockets belegt.
func _build_sockets() -> void:
	_socket_root = Node3D.new()
	_socket_root.name = "Sockets"
	_socket_root.position = Vector3(0.0, BODY_TOP * _sz, 0.0)
	add_child(_socket_root)
	var cap := Node3D.new()
	cap.name = "Endkappe"
	add_child(cap)
	for slot in GameRun.SOCKETS_PER_COMBO:
		var node := Node3D.new()
		node.name = "Socket_%d" % slot
		node.position = Vector3(socket_x(slot), 0.0, _socket_z)
		_socket_root.add_child(node)
		_upright(node)
		var rim := _build_socket_shell(node)
		var pick := _build_socket_pick(node, slot,
			Vector3(ComboPartBody.SOCKET_OUTER.x, 0.3, ComboPartBody.SOCKET_OUTER.y), Vector3.UP * 0.03)
		var line := _build_line(slot)
		var tile := _build_tile(cap, slot)
		var holder := Node3D.new()
		holder.name = "Pin_%d" % slot
		holder.position = pin_anchor(slot)
		cap.add_child(holder)
		_upright(holder)
		var empty_pin := ComboPartBody.new()
		empty_pin.name = "LeererPin"
		holder.add_child(empty_pin)
		empty_pin.setup(null, true)
		var hull := ComboPartBody.PIN_HULL
		_build_socket_pick(holder, slot, Vector3(hull.y, hull.z, hull.x),
			Vector3(0.0, hull.z * 0.5, hull.x * 0.5))
		_sockets.append({"node": node, "rim": rim, "body": null, "part": null, "dimmed": false,
			"pick": pick, "pin": null, "empty_pin": empty_pin, "holder": holder, "tile": tile,
			"line": line})
	_sync_picks()
	_layout_labels()

## Sockel und Pin liegen im Bild aufrecht wie ihr Modul: eine Vierteldrehung gegen den Chip.
func _upright(node: Node3D) -> void:
	node.rotation.y = PI * 0.5

## Die Kachel auf der Endkappe: dunkle Fläche, darauf ein Lichtstrich in der Modulfarbe.
func _build_tile(cap: Node3D, slot: int) -> StandardMaterial3D:
	var at := tile_center(slot)
	var tile := MeshInstance3D.new()
	tile.name = "Kachel_%d" % slot
	tile.mesh = ComboPartBody.slab_mesh(Vector2(TILE.x, TILE.y) * 0.5, 0.05, 0.012)
	tile.material_override = _tile_ground()
	tile.position = at
	cap.add_child(tile)
	var light := MeshInstance3D.new()
	light.name = "KachelLicht_%d" % slot
	var strip := BoxMesh.new()
	strip.size = Vector3(TILE_LIGHT.x, 0.006, TILE_LIGHT.y)
	light.mesh = strip
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.roughness = 0.4
	light.material_override = material
	light.position = at + Vector3(-TILE.x * 0.5 + 0.12, 0.015, 0.0)
	cap.add_child(light)
	return material

static var _tile_ground_cache: StandardMaterial3D

static func _tile_ground() -> StandardMaterial3D:
	if _tile_ground_cache == null:
		_tile_ground_cache = StandardMaterial3D.new()
		_tile_ground_cache.albedo_color = TILE_COLOR
		_tile_ground_cache.roughness = 0.5
		_tile_ground_cache.emission_enabled = true
		_tile_ground_cache.emission = TILE_COLOR
		_tile_ground_cache.emission_energy_multiplier = 0.4
	return _tile_ground_cache

## Die Leitung eines Sockels: von seiner Mitte ein Knick auf die Höhe seines Pins, dann gerade
## bis zu seiner Kachel - flach auf dem Deckel, unter den Platten der Nachbarn durch.
func _build_line(slot: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	var start := Vector2(socket_x(slot), _socket_z)
	var bend := Vector2(socket_x(slot) + LINE_DIP, row_z(slot))
	var end := Vector2(_half - CAP + 0.05, row_z(slot))
	var line := Node3D.new()
	line.name = "Leitung_%d" % slot
	_socket_root.add_child(line)
	for pair in [[start, bend], [bend, end]]:
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(a.distance_to(b) + LINE_WIDTH, LINE_H, 1.0)
		strip.mesh = box
		strip.material_override = material
		strip.position = Vector3((a.x + b.x) * 0.5, LINE_Y, (a.y + b.y) * 0.5)
		strip.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		line.add_child(strip)
	return material

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

## Steckt ein Teil: Körper auf den Sockel, Pin in seiner Form an die Kante.
func _seat_part(slot: int, part: ComboPart, off: bool) -> void:
	var entry := _sockets[slot]
	for key in ["body", "pin"]:
		var old: ComboPartBody = entry[key]
		if old != null and (not is_instance_valid(old) or old.part != part):
			if is_instance_valid(old):
				old.get_parent().remove_child(old)
				old.queue_free()
			entry[key] = null
	if part != null and entry["body"] == null:
		var body := ComboPartBody.new()
		body.name = "Part"
		(entry["node"] as Node3D).add_child(body)
		body.setup(part)
		body.set_resting(true)
		body.position = _part_rest()
		entry["body"] = body
	if part != null and entry["pin"] == null:
		var pin := ComboPartBody.new()
		pin.name = "ModulPin"
		(entry["holder"] as Node3D).add_child(pin)
		pin.setup(part, true)
		entry["pin"] = pin
	entry["part"] = part
	entry["dimmed"] = off
	_dim_slot(slot)
	_show_slot(slot)

## Hitzestau dimmt Körper und Pin; die Drossel nimmt nur den Pins das Licht.
func _dim_slot(slot: int) -> void:
	var entry := _sockets[slot]
	var body: ComboPartBody = entry["body"]
	if body != null and is_instance_valid(body):
		body.set_dimmed(bool(entry["dimmed"]))
	var pin: ComboPartBody = entry["pin"]
	if pin != null and is_instance_valid(pin):
		pin.set_dimmed(bool(entry["dimmed"]) or _throttled)

## Was an einem Platz steht: ein gehobenes Teil zeigt leer, sonst Modul-Pin oder Stahlpin.
func _show_slot(slot: int) -> void:
	var entry := _sockets[slot]
	var lifted := slot == _lifted_slot
	var body: ComboPartBody = entry["body"]
	if body != null and is_instance_valid(body):
		body.visible = not lifted
	var pin: ComboPartBody = entry["pin"]
	var module_pin := pin != null and is_instance_valid(pin) and not lifted
	if pin != null and is_instance_valid(pin):
		pin.visible = module_pin
	(entry["empty_pin"] as Node3D).visible = not module_pin

## Rand, Kachel und Leitung je Platz: Ruhe, Hover, Einbau-Ruf, Wertungs-Blitz, Drossel.
func _apply_socket_rims() -> void:
	var pulse := 0.5 + 0.5 * sin(_beckon_phase)
	for slot in _sockets.size():
		var entry := _sockets[slot]
		var part: ComboPart = entry["part"]
		var shown: ComboPart = part if slot != _lifted_slot else null
		var material: StandardMaterial3D = entry["rim"]
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
		material.emission = color
		material.emission_energy_multiplier = energy
		# Kachel und Leitung tragen die Modulfarbe; leer bleiben sie dunkel.
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
		_glow(entry["line"], tone,
			0.0 if _throttled else (LINE_ENERGY if shown != null else 0.2) + 2.0 * lit)
		_line_width(slot, LINE_WIDTH if shown != null else LINE_EMPTY_WIDTH)

func _glow(material: StandardMaterial3D, color: Color, energy: float) -> void:
	material.albedo_color = color.darkened(0.5) if energy > 0.2 else Color(0.05, 0.05, 0.07)
	material.emission = color
	material.emission_energy_multiplier = energy

func _line_width(slot: int, width: float) -> void:
	var line := _socket_root.get_node_or_null("Leitung_%d" % slot)
	if line == null:
		return
	for strip in line.get_children():
		(strip as MeshInstance3D).scale.z = width
