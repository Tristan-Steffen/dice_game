class_name DeckGlassView
extends Control
## Die GLAS-ANSICHT: das Netz-Raster des ganzen Vorrats, wie es auf dem
## geschlossenen Gruben-Glas liegt. Sie ist ein DAUER-MODUS des Vorrats, den der
## RASTER-UMSCHALTER am Grubenrand umlegt - und derselbe Weg, den der Tipp auf einen
## Neuzugang im Ausgabefach fährt: der Vorrat versinkt darunter, das Glas fährt zu.
## Sitz i = Zelle i: das Raster liest in POOL-SPALTEN, also steht jede Kachel dort,
## wo ihr Würfel schwebt - die räumliche Entsprechung ist der Sinn.
## Bedienung wie am Pool-Tray: TIPPEN wählt (Tausch-Ziel, solange ein Neuzugang
## wartet, sonst das Werkstatt-Ziel), ZIEHEN legt um.
## Das Fenster malt nur - gebucht wird draußen (scene_root -> GameRun).

## Eine Kachel wurde getippt: dieser POOL-Platz ist gewählt.
signal cell_pressed(index: int)
## Kachel auf Kachel gezogen: der Vorrat wird umgelegt.
signal cells_reordered(from_index: int, to_index: int)

## Einheit = Fensterbreite / UNIT_DIV, wie in jedem anderen Fenster.
const UNIT_DIV := 100.0
## Rand ringsum und die Kopfzeile darüber (in u). Eine Zeile genügt - was zu tun
## ist, sagt der Satz, und das Raster sagt den Rest.
const MARGIN_UNITS := 3.0
const HEAD_UNITS := 6.0
const HEAD_FONT_UNITS := 3.4
const HEAD_GAP_UNITS := 1.6

## Die HINWEIS-ZEILE am UNTEREN Rand (Spieler-Wunsch 2026-09-11): sie nennt, was der
## Zeiger berührt - die Seele des Würfels unter ihm oder die Wirkung seiner
## Netz-Zelle. Ihr Band ist RESERVIERT, auch wenn sie schweigt: sonst spränge das
## Raster bei jedem Überfahren. Dafür sitzt das Raster ein Stück höher.
const FOOT_UNITS := 5.6
const FOOT_FONT_UNITS := 3.0
const FOOT_GAP_UNITS := 1.4
## Ihr Grund ist DECKEND, der Schirm ringsum nicht: Text braucht einen ruhigen
## Grund, sonst schienen die versenkten Würfel mitten durch die Zeile. Er ist eine
## FREISTEHENDE Tafel (Spieler-Wunsch 2026-09-11): ringsum um den Fensterrand
## eingerückt - er berührt weder Wand noch Boden - und an ALLEN vier Ecken gerundet.
const FOOT_RADIUS_UNITS := 1.6
## Luft zwischen Tafelrand und Schrift, damit die Zeile nicht an der Rundung klebt.
const FOOT_PAD_UNITS := 2.0

var _back: Panel
var _foot_back: Panel
var _head: Label
var _foot: Label
var _host: Control
var _grid: DiceGridView
var _columns := 6
var _unit := 0.0
var _defs: Array[DieDefinition] = []
## Der INHALT des zuletzt gefüllten Rasters (siehe pool_signature).
var _signature: Array = []
var _title := ""
## Der GESÄUMTE Sitz (-1 = keiner): das aktuelle Ziel der Werkstatt.
var _target := -1
## Was die Hinweis-Zeile gerade sagt ("" = sie schweigt).
var _hint := ""

func _init() -> void:
	name = "DeckGlassWindow"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP  # modal: unter dem Glas liegt nichts
	_build()
	resized.connect(_relayout)

## Der HINTERGRUND ist der NORMALE Schirm - Farbe, Rahmen, Radius und seine halb
## durchsichtige Füllung (Spieler-Wunsch 2026-09-11): der Vorrat darunter darf
## durchschimmern, er soll nur nicht mehr die Kacheln stören. Deckend ist allein
## der Grund der Hinweis-Zeile (foot_style).
static func background_style() -> StyleBoxFlat:
	return TableScreen.window_style()

## Der Grund der HINWEIS-ZEILE: dieselbe Schirmfarbe, aber EINMAL über den
## Anzeige-Grund gemischt und fest gesetzt - so liegt der Text auf ruhigem Grund,
## während der Schirm ringsum durchscheinend bleibt.
static func foot_style(radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = TableScreen.BACKGROUND_COLOR.blend(TableScreen.FRAME_BG)
	style.set_corner_radius_all(maxi(radius, 0))
	return style

func _build() -> void:
	_back = Panel.new()
	_back.name = "Schirm"
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.add_theme_stylebox_override("panel", background_style())
	add_child(_back)

	_head = Label.new()
	_head.name = "Frage"
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_head.clip_text = true
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_theme_color_override("font_color", CasinoStyle.GOLD_INTENSE)
	add_child(_head)

	_foot_back = Panel.new()
	_foot_back.name = "HinweisGrund"
	_foot_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foot_back.add_theme_stylebox_override("panel", foot_style(FOOT_RADIUS_UNITS))
	add_child(_foot_back)

	_foot = Label.new()
	_foot.name = "Hinweis"
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_foot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_foot.clip_text = true
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foot.add_theme_color_override("font_color", DiceGridView.MUTED_COLOR)
	add_child(_foot)

	_host = Control.new()
	_host.name = "RasterHost"
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)

	_grid = DiceGridView.new()
	_grid.name = "DeckGrid"
	_grid.reorder_enabled = true
	_grid.slot_pressed.connect(func(index: int) -> void: cell_pressed.emit(index))
	_grid.slots_reordered.connect(func(from_index: int, to_index: int) -> void:
		cells_reordered.emit(from_index, to_index))
	_host.add_child(_grid)

## Die Belegung als reine Daten: je Sitz seine Instanz UND was seine Kachel zeigt -
## Seiten, Materialien, Veredelung, Runen, Pointer, Seele, Stil und LADUNG. Beides
## ist nötig:
## ein Umlegen tauscht nur die Instanzen (inhaltsgleiche Würfel gibt es reichlich),
## ein Tausch schreibt per become IN die Instanz und läßt die Liste unberührt.
static func pool_signature(defs: Array[DieDefinition]) -> Array:
	var out: Array = []
	for def: DieDefinition in defs:
		if def == null:
			out.append([])
			continue
		out.append([def.get_instance_id(), def.faces, def.materials, def.levels,
			def.runes, def.second_runes, def.third_runes, def.pointers,
			def.essence_id, def.style_id, def.charge, def.burned_out])
	return out

## Der ganze Inhalt in EINEM Aufruf: die Kopfzeile, der Vorrat in Buch-Ordnung und
## der gesäumte Sitz. Idempotent - dieselbe Belegung baut das teure Raster nicht
## neu, ein gewechselter Saum stylt bloß um.
func show_pool(title: String, defs: Array[DieDefinition], columns: int,
		target_index := -1) -> void:
	var signature := pool_signature(defs)
	var fresh := columns != _columns or signature != _signature
	_title = title
	_defs = defs.duplicate()
	_signature = signature
	_columns = maxi(columns, 1)
	_target = target_index
	_head.text = title
	if fresh:
		_unit = 0.0  # das Raster wird neu gefüllt, nicht nur vermessen
	_relayout()
	_grid.set_highlight(_target)

## Die HINWEIS-ZEILE schreiben ("" = schweigen). Idempotent - der Zeiger fragt je
## Bild, gesetzt wird nur der Wechsel.
func set_hint(text: String) -> void:
	if text == _hint:
		return
	_hint = text
	if _foot != null and is_instance_valid(_foot):
		_foot.text = text

func hint() -> String:
	return _hint

## Der gesäumte Sitz (-1 = keiner).
func target_index() -> int:
	return _target

func pool_size() -> int:
	return _defs.size()

func title() -> String:
	return _title

func grid() -> DiceGridView:
	return _grid

## Kopf und Raster in ihre Bänder legen: der Kopf oben, das Raster darunter, so
## groß wie es der Rest hergibt - und mittig darin (der nackte Wirt legt nichts aus).
func _relayout() -> void:
	if _head == null or not is_instance_valid(_head) or size.x <= 0.0:
		return
	var u := size.x / UNIT_DIV
	var margin := u * MARGIN_UNITS
	_head.position = Vector2(margin, margin)
	_head.size = Vector2(maxf(size.x - margin * 2.0, 1.0), u * HEAD_UNITS)
	_head.add_theme_font_size_override("font_size", maxi(8, int(u * HEAD_FONT_UNITS)))
	var foot := u * FOOT_UNITS
	# Die deckende Tafel steht FREI: ringsum um den Rand eingerückt, oben eine halbe
	# Fuge über der Zeile. Die Schrift bekommt darin noch ihre Luft.
	var band := maxf(size.y - margin - foot - u * FOOT_GAP_UNITS * 0.5, 0.0)
	_foot_back.position = Vector2(margin, band)
	_foot_back.size = Vector2(maxf(size.x - margin * 2.0, 1.0),
		maxf(size.y - margin - band, 1.0))
	_foot_back.add_theme_stylebox_override("panel",
		foot_style(int(u * FOOT_RADIUS_UNITS)))
	var pad := u * FOOT_PAD_UNITS
	_foot.position = Vector2(margin + pad, maxf(size.y - margin - foot, 0.0))
	_foot.size = Vector2(maxf(size.x - (margin + pad) * 2.0, 1.0), foot)
	_foot.add_theme_font_size_override("font_size", maxi(8, int(u * FOOT_FONT_UNITS)))
	var top := margin + u * (HEAD_UNITS + HEAD_GAP_UNITS)
	_host.position = Vector2(margin, top)
	# Das Band der Hinweis-Zeile bleibt frei: das Raster sitzt dadurch HÖHER.
	_host.size = Vector2(maxf(size.x - margin * 2.0, 1.0),
		maxf(size.y - top - margin - foot - u * FOOT_GAP_UNITS, 1.0))
	_fit_grid()

func _fit_grid() -> void:
	if _grid == null or not is_instance_valid(_grid) or _host.size.x <= 0.0:
		return
	var rows := maxi(int(ceil(float(_defs.size()) / float(_columns))), 1)
	var unit := DiceGridView.unit_for(_columns, rows, _host.size)
	if is_equal_approx(unit, _unit) and _grid.get_child_count() > 0:
		return  # resized feuert während des Layouts mehrfach
	_unit = unit
	_grid.place(_columns, unit, true)
	_grid.fill(_defs, _target)
	_center_grid.call_deferred()

func _center_grid() -> void:
	if _grid == null or not is_instance_valid(_grid) or not is_instance_valid(_host):
		return
	var span := _grid.get_combined_minimum_size()
	_grid.size = span
	_grid.position = ((_host.size - span) * 0.5).max(Vector2.ZERO)
