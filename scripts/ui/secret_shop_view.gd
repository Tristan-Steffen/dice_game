class_name SecretShopView
extends Panel
## Der Schwarzmarkt: eigenes Tisch-Fenster UNTER den Fumble-Automaten. Es steht
## von Anfang an da, aber VERGITTERT - erst die Lizenzstufe hebt das Gitter
## (set_locked); solange bleibt die Bucht zu, denn die Auslage wird erst beim
## Freischalten gewürfelt.
## Danach: bezahlt wird ausschließlich in Energie (⚡) - drei Plätze, jeder EINMAL
## kaufbar, "Neu mischen" tauscht alle drei zum immer gleichen Preis.
## Aufgeteilt ist das Fenster wie der Laden: Kopfstreifen und der feste
## KARTEN-SITZ (genau EINE Charm-Karte - Lizenzen sind digitale Ware) bleiben
## Bildschirm, die WARE liegt körperlich in der Bucht daneben. Die zeichnet dieses
## Fenster nie selbst; es meldet nur ihr Rechteck und ihren Inhalt, aufgestellt
## wird sie von scene_root. Das löst nebenbei das Auflösungs-Problem der kleinen
## Tasche: ein echter Würfel unter Glas rendert in Bildschirmauflösung.
## Die AUSKUNFT spricht die Laden-Grammatik (nichts schwebt über der Ware):
## die Charm-Karte tauscht beim Hover ihr Modell gegen den vollen Wirkungstext,
## unter jedem Bucht-Stück STEHT sein Schild (Seelen-Zeile beim Würfel, ⚡-Preis
## bei allem - set_bay_plates, die Plätze meldet scene_root), und der INFO-FUSS
## am Fensterboden trägt beim Hover Name und Wirkung des Stücks an IMMER
## derselben Stelle (show_bay_annotation; seine Schlüsselwörter sind Klickziele).
## Zustands-Mutation läuft ausschließlich über GameRun (buy_secret_offer/
## reroll_secret_stock); die Anzeige folgt secret_stock_changed und
## energy_changed. Geschlossen wird wie bei jedem Fenster per Rechtsklick.

## Energie ist für den Laden geflossen (Kauf oder Neuwurf) - scene_root schickt sie
## als Kometen über die Hinterzimmer-Ader. Erst gebucht, dann gemeldet.
signal energy_spent(amount: int)
## Versiegelte Ware ist gekauft (Bündel-Karten oder Katalysator): sie liegt schon
## als Pakete im Magazin, scene_root fährt sie nur noch dorthin - je Karte eine.
signal goods_purchased(uids: Array[int])
## Ein Seelenwürfel ist gekauft: er liegt schon im Ausgabefach, scene_root fährt
## ihn nur noch dorthin. Kein Paket - ein Würfel wird nie versiegelt.
signal die_purchased(def: DieDefinition)
## Die Auslage der Bucht hat sich geändert (Wurf, Kauf, Freischaltung).
signal vitrine_changed
## Ein Schlüsselwort auf dem Info-Fuß wurde geklickt - scene_root schlägt das
## Lexikon auf.
signal lexikon_requested(entry_id: String)

## Hinterzimmer-Palette: dunkler als der Laden, Akzent ist das Violett der
## legendären Rarität.
const VIOLET := Color(0.75, 0.35, 1.0)
const ENERGY_COLOR := CasinoStyle.ENERGY
const NEON_TEXT := Color(1.35, 1.35, 1.3)
const NEON_MUTED := Color(0.72, 0.74, 0.86)
const BACKROOM_BG := Color("#0b0918e6")
const CARD_BG := Color("#150f2acc")

## Breite des Karten-Sitzes in Einheiten. Er steht FEST - ob eine Karte darin
## liegt oder der legendäre Topf erschöpft ist, ändert die Aufteilung nie.
const CARD_SEAT_WIDTH := 28.0

## Bauhöhe des Inhalts in Einheiten. Seit der Schwarzmarkt in den vom
## TOPF-Rückbau freigegebenen Filz gewachsen ist (~786×437 px), bindet weiter
## die BREITE (54 liegt knapp unter dem Fenster-Seitenverhältnis 1,8) - die
## Einheit ist Schriftgröße in Textur-Pixeln, größer trägt das Fenster nicht.
const CONTENT_UNITS := 54.0

## Der INFO-FUSS: das feste Band am Fensterboden, in dem die Auskunft des
## berührten Bucht-Stücks steht - Laden-Grammatik, nichts schwebt über der Ware.
## Unsichtbar, solange nichts berührt ist (kein Rahmen, keine Leerlauf-Zeile).
const FOOT_UNITS := 12.0
const FOOT_TITLE_FONT := 2.5
## Der Fuß VERWEILT nach dem Verlassen des Stücks und fadet dann aus - so kann der
## Zeiger vom Würfel auf das Netz wandern (dessen Zellen-Hover). Wer den Fuß in
## dieser Zeit erreicht, hält ihn (foot_hover bricht den Fade ab).
const FOOT_LINGER_TIME := 0.5
const FOOT_FADE_TIME := 0.3
## Grad-Leiter des Fuß-Textes: der erste Schritt, in dem der Text umgebrochen in
## den Fuß passt (gemessen über wrapped_height, am NACKTEN Text - BBCode ist
## keine Type).
const FOOT_BODY_STEPS := [2.2, 1.9, 1.65, 1.4]

## Die STEHENDEN Schilder der Bucht: Abstand unter dem Stück-Anker und Grade.
## Gehängt wird die PREISZEILE, nicht der Kopf des Schildes (Spieler-Entscheid
## 2026-09-04): so steht der Preis bei Würfel wie Kassette auf DERSELBEN Höhe, und
## er steht tief genug, dass die liegende Karte ihn nicht mehr verdeckt (gemessen:
## halbe Kartentiefe 44,3 px = 5,6 u).
const PLATE_PRICE_DROP_UNITS := 7.4
const PLATE_SOUL_FONT := 2.2
const PLATE_PRICE_FONT := 2.6

var run: GameRun:
	set(value):
		if run != null:
			if run.secret_stock_changed.is_connected(_on_run_changed):
				run.secret_stock_changed.disconnect(_on_run_changed)
			if run.energy_changed.is_connected(_on_energy_changed):
				run.energy_changed.disconnect(_on_energy_changed)
			if run.charms_changed.is_connected(_on_run_changed):
				run.charms_changed.disconnect(_on_run_changed)
		run = value
		if run != null:
			run.secret_stock_changed.connect(_on_run_changed)
			run.energy_changed.connect(_on_energy_changed)
			run.charms_changed.connect(_on_run_changed)  # der Charm-Platz sperrt am vollen Dock
		_seen_rolls = -1  # frischer Lauf: die erste Auslage rollt wieder an
		refresh()

## Einheit aus BEIDEN Achsen (in refresh gesetzt).
var u := 4.0

## Vergittert: Schatten-Plätze unter einem dunklen Schleier mit der Bedingung.
var locked := true

var wallet_label: Label
## Der feste Sitz der EINEN Karte (Bildschirm) und daneben das Feld der Bucht.
var card_seat: Control
var vitrine_slot: Control
var reroll_button: Button
## Index-treu zur Auslage: je Platz ein Knopf oder null - was körperlich in der
## Bucht liegt, hat auf dem Bildschirm keinen (die Lücken halten die Indizes).
var offer_buttons: Array[Button] = []
var lock_overlay: Panel
## Auf dem Schleier steht, was das Gitter hebt - kein Knopf, nichts zu kaufen.
var lock_notice: Label

## Ob der Zeiger auf der Charm-Karte liegt (gemeldet je Bild von scene_root):
## dann trägt der INFO-FUSS ihren Text, wie bei der Bucht-Ware. Die Karte selbst
## behält ihr Modell - nichts schwebt, alles steht im festen Fuß.
var _charm_hovered := false

## Der INFO-FUSS und die stehenden Bucht-Schilder.
var info_foot: Control
var foot_net: CenterContainer
var foot_title: Label
var foot_body: RichTextLabel
var _foot_key := ""
## Das Netz im Fuß ist HOVERBAR: gemerkt werden sein Würfel, sein Zellmaß, sein
## Körper (das Rechteck sitzt mittig im Container) und die zuletzt gezeigte Zelle -
## nur der WECHSEL schreibt.
var _foot_net_def: DieDefinition = null
var _foot_net_body: Control = null
var _foot_net_cell_px := 0.0
var _foot_face := -1
## Der nackte Beschreibungstext, auf den die Zelle zurückfällt.
var _foot_body_naked := ""
## Der laufende Verweil-/Fade-Tween des Fußes (null = er steht oder ist leer).
var _foot_fade_tween: Tween = null
var _plate_layer: Control
var _plate_signature := ""

var _built := false
## Zuletzt gesehener Wurf-Stand (-1 = vergittert/noch keiner). Ein WURF rollt die
## Ware an, ein Kauf lässt sie liegen - mehr entscheidet den Grad nicht.
var _seen_rolls := -1
var _vitrine_grade := ShopController.GRADE_STAND
## Was körperlich in der Bucht liegt, je Auslage-Platz (null = kein solches Stück).
var _bay_packs: Array = []
var _bay_dice: Array = []
## Die Bucht-Sorte je Platz, UNABHÄNGIG vom Verkauf ("" = Karten-Sitz): daran
## rechnet die Reihe ihre Plätze, damit ein Kauf die übrige Ware nicht verrückt.
var _bay_kinds: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Knöpfe fangen selbst
	clip_contents = true
	add_theme_stylebox_override("panel", _window_box())

## Fensterrahmen in Hinterzimmer-Farben: Form und Radius wie jedes Tisch-Fenster,
## nur Füllung dunkler und Saum violett.
func _window_box() -> StyleBoxFlat:
	var box := TableScreen.window_style()
	box.bg_color = BACKROOM_BG
	box.border_color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.75)
	return box

## scene_root/TableScreen nach Platzierung und Zustandswechseln: Gerüst in der
## aktuellen Fenstergröße, dann die Auslage.
func refresh() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_build_layout()
	_refresh_offers()
	_apply_lock_state()

## Gitter-Zustand von scene_root (einziger Schreiber): locked = die Lizenzstufe
## reicht noch nicht.
func set_locked(is_locked: bool) -> void:
	var was_locked := locked
	locked = is_locked
	if not _built:
		return
	if was_locked != locked:
		_refresh_offers()  # Schatten <-> echte Ware ist ein Neuaufbau
	_apply_lock_state()

## Schleier, Knopf und Dimmung des Sitzes am Gitter-Zustand ausrichten.
func _apply_lock_state() -> void:
	if not _built:
		return
	lock_overlay.visible = locked
	reroll_button.visible = not locked
	card_seat.modulate = Color(1, 1, 1, 0.35) if locked else Color.WHITE

# --- Gerüst -------------------------------------------------------------------

func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	offer_buttons.clear()
	_charm_hovered = false
	# Der alte Fuß wird gleich frei - sein Fade darf kein totes Ziel treiben.
	if _foot_fade_tween != null and _foot_fade_tween.is_valid():
		_foot_fade_tween.kill()
	_foot_fade_tween = null
	_foot_key = ""
	_foot_body_naked = ""
	_foot_net_def = null
	_foot_net_body = null
	_foot_face = -1
	_plate_signature = ""
	u = minf(size.x / 100.0, size.y / CONTENT_UNITS)
	_built = true

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(u * 3.0))
	margin.add_theme_constant_override("margin_right", int(u * 3.0))
	margin.add_theme_constant_override("margin_top", int(u * 2.4))
	margin.add_theme_constant_override("margin_bottom", int(u * 2.4))
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", int(u * 1.4))
	margin.add_child(root)

	# Kopfstreifen: Titel, Börse und der Neuwurf. Der alte Fuß ist weg - seine
	# Höhe gehört jetzt der Bucht, und der Misch-Knopf steht ohnehin zum Titel.
	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", int(u * 1.2))
	root.add_child(header)
	header.add_child(_label("SCHWARZMARKT", u * 4.2, Color(1.35, 0.7, 1.7)))
	var rail := _rail(VIOLET)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(rail)
	wallet_label = _label("⚡ 0/0", u * 4.2, ENERGY_COLOR)
	wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(wallet_label)
	reroll_button = _neon_button("Neu mischen", VIOLET, u * 2.6, Vector2(u * 24.0, u * 6.2))
	reroll_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reroll_button.pressed.connect(_on_reroll_pressed)
	header.add_child(reroll_button)

	# Darunter die zwei Zonen: links der Karten-Sitz (Bildschirm), rechts die Bucht.
	var body := HBoxContainer.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", int(u * 1.8))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	card_seat = Control.new()
	card_seat.name = "CardSeat"
	card_seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_seat.custom_minimum_size = Vector2(u * CARD_SEAT_WIDTH, 0.0)
	body.add_child(card_seat)

	# Die Bucht bekommt den Rest der Zeile. Gemalt wird allein die FASSUNG - die
	# Mitte ist frei, denn dort steht die Ware auf der Fläche.
	vitrine_slot = Control.new()
	vitrine_slot.name = "Vitrine"
	vitrine_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitrine_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitrine_slot.add_child(_vitrine_frame())
	body.add_child(vitrine_slot)

	_build_info_foot(root)
	# Die stehenden Schilder liegen als eigene Schicht ÜBER der Bucht (absolut
	# gestellt, außerhalb des Layouts) - der Schleier des Gitters deckt sie mit.
	_plate_layer = Control.new()
	_plate_layer.name = "BayPlates"
	_plate_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate_layer)
	_build_lock_overlay()  # und ganz oben das Gitter

# --- Die Bucht (gemeldete Geometrie, nie gezeichneter Inhalt) ------------------

## Das Buchten-Rechteck in globalen Display-Pixeln (leeres Rect = noch keins).
func vitrine_rect_px() -> Rect2:
	if vitrine_slot == null or not is_instance_valid(vitrine_slot):
		return Rect2()
	return vitrine_slot.get_global_rect()

## Das FELD darin: der Streifen ohne seine gemalte Fassung - dieselbe Rechnung wie
## am Magazin und in der Laden-Bucht.
func vitrine_pit_rect() -> Rect2:
	var strip := vitrine_rect_px()
	if strip.size.x <= 0.0 or strip.size.y <= 0.0:
		return Rect2()
	return PackDrawerView.pit_rect_in(strip, u)

## Maßeinheit der Bucht-Beschriftung. Bewusst DIE DES FENSTERS: die Tasche ist
## die kleinste des Tisches, und eine an der Buchtbreite hängende Einheit
## schriebe dort kleiner als das Fenster selbst.
func vitrine_unit() -> float:
	return u

## Die FASSUNG der Bucht - Rahmen ohne Füllung, Rezeptur aus der Magazin-Fassung.
func _vitrine_frame() -> Panel:
	var well := Panel.new()
	well.name = "VitrineWell"
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var radius := int(u * PackDrawerView.RADIUS)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = PackDrawerView.RIM_BASE
	box.set_border_width_all(maxi(2, int(u * PackDrawerView.RIM_WIDTH)))
	box.set_corner_radius_all(radius)
	well.add_theme_stylebox_override("panel", box)
	var edge := maxi(2, int(u * PackDrawerView.EDGE))
	well.add_child(PackDrawerView.edge_band("VitrineShade",
		PackDrawerView.WELL_SHADOW, edge, radius, true))
	well.add_child(PackDrawerView.edge_band("VitrineSheen",
		PackDrawerView.WELL_SHEEN, edge, radius, false))
	return well

# --- Der INFO-FUSS -------------------------------------------------------------

## Das feste Band am Fensterboden: links Name und Wirkung, RECHTS (nur beim Würfel)
## das Netz - dort, wo der Würfel selbst liegt. Unsichtbar, solange nichts berührt ist.
func _build_info_foot(root: Container) -> void:
	var foot := HBoxContainer.new()
	foot.name = "InfoFoot"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override("separation", int(u * 1.8))
	foot.custom_minimum_size = Vector2(0.0, u * FOOT_UNITS)
	root.add_child(foot)
	info_foot = foot

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", int(u * 0.4))
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(column)

	foot_net = CenterContainer.new()
	foot_net.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot_net.visible = false
	foot.add_child(foot_net)

	foot_title = _label("", u * FOOT_TITLE_FONT, CasinoStyle.GOLD)
	foot_title.clip_text = true
	foot_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot_title.visible = false
	column.add_child(foot_title)

	foot_body = RichTextLabel.new()
	foot_body.bbcode_enabled = true
	foot_body.fit_content = true
	foot_body.scroll_active = false
	# STOP, nicht PASS: die Schlüsselwörter sind Klickziele.
	foot_body.mouse_filter = Control.MOUSE_FILTER_STOP
	foot_body.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	foot_body.meta_clicked.connect(func(meta: Variant) -> void:
		lexikon_requested.emit(String(meta)))
	foot_body.visible = false
	column.add_child(foot_body)

## Netz-Zellenmaß des Fußes: drei Kreuz-Zeilen müssen in das Band passen.
func _foot_net_cell() -> float:
	return (u * FOOT_UNITS - u * 1.0) / 3.0

## Die Auskunft des berührten Stücks in den Fuß schreiben. data kommt von
## vitrine_annotation; der Anker wird bewusst ignoriert - der Fuß STEHT, nichts
## schwebt über der Ware. Je Bild gerufen, gebaut nur beim Wechsel.
func show_bay_annotation(data: Dictionary, _anchor: Vector2) -> void:
	if not _built or info_foot == null or not is_instance_valid(info_foot):
		return
	_kill_foot_fade()  # ein neuer Hover hält den Fuß - auch mitten im Ausblenden
	var naked := String(data.get("body", ""))
	var key := "%s|%s" % [String(data.get("title", "")), naked]
	if key == _foot_key:
		_restore_foot_body()  # der Netz-Hover hat den Body vielleicht getauscht
		return
	_foot_key = key
	_foot_body_naked = naked
	_foot_face = -1
	foot_title.text = String(data.get("title", ""))
	foot_title.visible = foot_title.text != ""
	for child in foot_net.get_children():
		foot_net.remove_child(child)
		child.queue_free()
	_foot_net_body = null
	var net_def: DieDefinition = data.get("net")
	_foot_net_def = net_def
	foot_net.visible = net_def != null
	var cell := _foot_net_cell()
	_foot_net_cell_px = cell
	if net_def != null:
		_foot_net_body = DieNetView.build(net_def, -1, cell)
		foot_net.add_child(_foot_net_body)
	# Grad des Wirkungstexts: der erste Leiter-Schritt, der umgebrochen unter den
	# Titel passt - gemessen am nackten Text (BBCode ist keine Type).
	var body_width := size.x - u * 6.0 - (cell * 4.0 + u * 1.8 if net_def != null else 0.0)
	var font := ThemeDB.fallback_font
	var title_h := u * FOOT_TITLE_FONT * 1.4
	if font != null:
		title_h = font.get_height(maxi(8, int(u * FOOT_TITLE_FONT)))
	var room := u * FOOT_UNITS - title_h - u * 0.4
	var grade := maxi(8, int(u * float(FOOT_BODY_STEPS[FOOT_BODY_STEPS.size() - 1])))
	if font != null:
		for step in FOOT_BODY_STEPS:
			var px := maxi(8, int(u * float(step)))
			if ShopController.wrapped_height(font, naked, body_width, px, 0) <= room:
				grade = px
				break
	CasinoStyle.style_rich_body(foot_body, grade)
	foot_body.text = Lexikon.linkify(naked)
	foot_body.visible = naked != ""

## Der Fuß räumt NICHT sofort: er verweilt FOOT_LINGER_TIME und fadet dann in
## FOOT_FADE_TIME aus - der Zeiger darf unterwegs sein (Stück → Netz-Zellen).
## Je Bild gerufen, gestartet nur beim ÜBERGANG (ein laufender Tween bleibt).
## immediate ist der harte Weg (Vorhangfall, Laufwechsel): sofort leer.
func hide_bay_annotation(immediate := false) -> void:
	if not _built or info_foot == null or not is_instance_valid(info_foot):
		return
	if immediate:
		_kill_foot_fade()
		_clear_foot()
		return
	if _charm_hovered:
		return  # die Karte hält den Fuß - der Bucht-Fluss räumt ihn nicht
	if not (foot_title.visible or foot_body.visible or foot_net.visible):
		return  # schon leer
	if _foot_fade_tween != null and _foot_fade_tween.is_valid():
		return  # die Verweilzeit läuft schon
	_foot_fade_tween = create_tween()
	_foot_fade_tween.tween_interval(FOOT_LINGER_TIME)
	_foot_fade_tween.tween_property(info_foot, "modulate:a", 0.0, FOOT_FADE_TIME)
	_foot_fade_tween.tween_callback(_clear_foot)

## Der Fade ist abgebrochen: der Fuß steht wieder voll da.
func _kill_foot_fade() -> void:
	if _foot_fade_tween != null and _foot_fade_tween.is_valid():
		_foot_fade_tween.kill()
	_foot_fade_tween = null
	if info_foot != null and is_instance_valid(info_foot):
		info_foot.modulate.a = 1.0

## Endzustand des Ausblendens - und der eine harte Leer-Schreiber.
func _clear_foot() -> void:
	_foot_fade_tween = null
	_foot_key = ""
	_foot_body_naked = ""
	_foot_net_def = null
	_foot_net_body = null
	_foot_face = -1
	foot_title.visible = false
	foot_body.visible = false
	foot_net.visible = false
	if info_foot != null and is_instance_valid(info_foot):
		info_foot.modulate.a = 1.0

## Der Zeiger steht auf dem Fuß (globaler Display-Pixel): liegt er auf einer
## NETZ-ZELLE, trägt der Body deren Materialzeile - dieselbe EINE Quelle wie überall
## (DieNetView.hint_for). Sonst steht die Beschreibung wieder. Je Bild gerufen,
## geschrieben nur beim Zellen-WECHSEL.
func foot_hover(px: Vector2) -> void:
	if not _built or foot_body == null or not is_instance_valid(foot_body):
		return
	_kill_foot_fade()  # der Zeiger STEHT auf dem Fuß - er bleibt
	var face := -1
	if _foot_net_def != null and _foot_net_body != null \
			and is_instance_valid(_foot_net_body) and foot_net.visible:
		var rect := _foot_net_body.get_global_rect()
		if rect.has_point(px):
			face = DieNetView.face_at(px - rect.position, _foot_net_cell_px)
	if face == _foot_face:
		return
	_foot_face = face
	_write_foot_body()

## Der Body fällt auf die Beschreibung zurück, falls der Netz-Hover ihn getauscht hat.
func _restore_foot_body() -> void:
	if _foot_face == -1:
		return
	_foot_face = -1
	_write_foot_body()

func _write_foot_body() -> void:
	var line := DieNetView.hint_for(_foot_net_def, _foot_face) if _foot_face != -1 else ""
	if line == "":
		foot_body.text = Lexikon.linkify(_foot_body_naked)
		foot_body.visible = _foot_body_naked != ""
		return
	foot_body.text = line  # plain: eine Materialzeile ist kein Lexikon-Text
	foot_body.visible = true

## Der Zeiger liegt auf der Charm-Karte (gemeldet je Bild): dann trägt der Fuß
## Name und Wirkung des Charms - dieselbe Auskunft wie bei der Bucht-Ware, an
## IMMER derselben Stelle. Beim Verlassen räumt der normale Bucht-Fluss den Fuß
## (hide/holds), damit der Wechsel Karte→Ware weich bleibt.
func hover_charm(hovered: bool) -> void:
	_charm_hovered = hovered and card_slot_index() >= 0
	if _charm_hovered:
		show_bay_annotation(charm_foot_data(), Vector2.ZERO)

## Das Rechteck des Karten-Sitzes in globalen Display-Pixeln (leer = kein Charm
## sitzt dort). scene_root fragt je Bild, ob der Zeiger darauf liegt.
func charm_seat_rect_px() -> Rect2:
	if not _built or card_seat == null or not is_instance_valid(card_seat) \
			or card_slot_index() < 0:
		return Rect2()
	return card_seat.get_global_rect()

## Die Fuß-Auskunft des Charms am Sitz: Name und volle Wirkung, dieselbe
## Grammatik wie vitrine_annotation (nur ohne Preis - der steht auf der Karte).
func charm_foot_data() -> Dictionary:
	var seat := card_slot_index()
	if run == null or seat < 0:
		return {}
	var charm: Charm = run.secret_stock[seat][GameRun.OFFER_ITEM]
	return {"title": charm.display_name, "body": charm.description}

## Ob der globale Display-Pixel auf dem GEFÜLLTEN Fuß liegt. Der Zeiger muss vom
## Stück auf seine Auskunft wandern dürfen - die Schlüsselwörter sind Klickziele -,
## sonst verschwände sie unter ihm.
func bay_annotation_has_point(px: Vector2) -> bool:
	if not _built or info_foot == null or not is_instance_valid(info_foot) \
			or not (foot_title.visible or foot_body.visible):
		return false
	return info_foot.get_global_rect().has_point(px)

# --- Die stehenden Bucht-Schilder ----------------------------------------------

## Die STEHENDEN Schilder der Bucht - die Laden-Grammatik "Hinsehen braucht
## keinen Zeiger": unterm Würfel seine Seelen-Zeile plus ⚡-Preis, unter jeder
## versiegelten Kassette ihr ⚡-Preis (versiegelt wirbt nicht mit Inhalt; Sorte
## und Größe trägt die FARBE der Karte). Volles Lager schreibt VOLL in Rot statt des
## Preises. entries = [{kind, index, px}] mit GLOBALEN Display-Pixeln - die
## Plätze meldet scene_root, das Fenster fasst nie Körper an. Je Bild gerufen,
## gebaut nur bei Änderung (Signatur).
func set_bay_plates(entries: Array) -> void:
	if not _built or _plate_layer == null or not is_instance_valid(_plate_layer):
		return
	var signature := ""
	for entry: Dictionary in entries:
		var px: Vector2 = entry["px"]
		# Der PREIS gehört in die Signatur: ein Hehlerware-Rabatt kann sich ändern,
		# ohne dass Energie oder Plätze sich rühren (Charm mit Geld gekauft).
		var index := int(entry["index"])
		var price := -1
		if run != null and index >= 0 and index < run.secret_stock.size():
			price = run.secret_offer_price(run.secret_stock[index])
		signature += "%s:%d:%d,%d:%d;" % [String(entry["kind"]), index,
			int(px.x), int(px.y), price]
	if run != null:
		signature += "|%d|%d|%s" % [run.energy, run.pack_room(), run.charms_full()]
	if signature == _plate_signature:
		return
	_plate_signature = signature
	for child in _plate_layer.get_children():
		_plate_layer.remove_child(child)
		child.queue_free()
	if run == null:
		return
	var origin := get_global_rect().position
	var field := vitrine_rect_px()
	for entry: Dictionary in entries:
		var index := int(entry["index"])
		if index < 0 or index >= run.secret_stock.size():
			continue
		var offer: Dictionary = run.secret_stock[index]
		if bool(offer[GameRun.OFFER_SOLD]):
			continue
		var plate := VBoxContainer.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_constant_override("separation", int(u * 0.1))
		if String(entry["kind"]) == ShopController.KIND_DIE:
			var die: DieDefinition = offer[GameRun.OFFER_ITEM]
			if die != null and die.essence_id != "":
				plate.add_child(_label(Essence.by_id(die.essence_id).display_name,
					u * PLATE_SOUL_FONT, ShopController.soul_tint(die.essence_id),
					HORIZONTAL_ALIGNMENT_CENTER))
		var price := run.secret_offer_price(offer)
		var blocked := _offer_blocked(offer)
		var tag := ShopController.FULL_MARK if blocked else "⚡ %d" % price
		var tint := CasinoStyle.RED if blocked or run.energy < price else ENERGY_COLOR
		var price_line := _label(tag, u * PLATE_PRICE_FONT, tint,
			HORIZONTAL_ALIGNMENT_CENTER)
		plate.add_child(price_line)
		_plate_layer.add_child(plate)
		plate.reset_size()
		# Mittig unter den Stück-Anker, in die Bucht geklemmt - und die PREISZEILE
		# hängt, nicht der Kopf: eine Seelen-Zeile darüber schöbe den Preis sonst
		# tiefer als den einer Kassette, die keine trägt.
		var local: Vector2 = (entry["px"] as Vector2) - origin
		var above := maxf(plate.size.y - price_line.size.y, 0.0)
		var pos := Vector2(local.x - plate.size.x * 0.5,
			local.y + u * PLATE_PRICE_DROP_UNITS - above)
		if field.size.x > 0.0:
			var flocal := Rect2(field.position - origin, field.size)
			pos.x = clampf(pos.x, flocal.position.x,
				maxf(flocal.position.x, flocal.end.x - plate.size.x))
			pos.y = clampf(pos.y, flocal.position.y,
				maxf(flocal.position.y, flocal.end.y - plate.size.y))
		plate.position = pos

## Der Ankunfts-Grad der zuletzt gezeigten Auslage; scene_root fährt ihn EINMAL.
func vitrine_grade() -> String:
	return _vitrine_grade

## Der Platz mit der EINEN Karte (-1 = keiner - der legendäre Topf ist erschöpft
## und eine Sonder-Gravur ist nachgerückt; dann steht deren Kassette in der Bucht
## und der Sitz bleibt leer).
func card_slot_index() -> int:
	if run == null:
		return -1
	for i in run.secret_stock.size():
		if run.secret_stock[i][GameRun.OFFER_KIND] == GameRun.KIND_CHARM:
			return i
	return -1

## Was körperlich in der Bucht liegt: je Auslage-Platz ein Eintrag, null für
## Verkauftes und für den Karten-Sitz. Die Lücken halten die Indizes treu - ein
## Griff meint immer denselben Kaufweg (buy_offer). row_kinds nennt je Platz die
## Bucht-Sorte AUCH für Verkauftes: daran rechnet die eine Reihe ihre Plätze, so
## dass ein Kauf die übrige Ware nicht verrückt - die Lücke bleibt.
func vitrine_stock() -> Dictionary:
	return {
		ShopController.KIND_ENGRAVING_PACK: _bay_packs.duplicate(),
		ShopController.KIND_DIE: _bay_dice.duplicate(),
		ShopController.KIND_SPECIAL: [],
		VitrineView.STOCK_ROW_KINDS: _bay_kinds.duplicate(),
	}

## Die Beschriftung EINES Stücks für den Info-Fuß und sein stehendes Schild. Der
## Preis ist in ⚡ ausgewiesen - in der Bucht selbst hängt kein Schild an der Ware.
func vitrine_annotation(_kind: String, index: int) -> Dictionary:
	if run == null or index < 0 or index >= run.secret_stock.size():
		return {}
	var offer := run.secret_stock[index]
	if bool(offer[GameRun.OFFER_SOLD]):
		return {}
	var data := {
		"price": run.secret_offer_price(offer),
		"money": run.energy,
		"energy": true,
		"blocked": ShopController.FULL_TAG if _offer_blocked(offer) else "",
	}
	match String(offer[GameRun.OFFER_KIND]):
		GameRun.KIND_DIE:
			var die: DieDefinition = offer[GameRun.OFFER_ITEM]
			var essence := Essence.by_id(die.essence_id)
			data["title"] = "%s-Würfel" % essence.display_name
			data["body"] = "%s\n%s" % [essence.short, essence.description]
			data["net"] = die
		GameRun.KIND_CATALYST:
			var card_pack: Pack = offer[GameRun.OFFER_ITEM]
			data["title"] = card_pack.display_name
			data["body"] = card_pack.description
		_:
			var engraving: Engraving = offer[GameRun.OFFER_ITEM]
			# Die Bündelgröße steht auf dem Stapel - hier nennt sie die Beschriftung
			# noch einmal, damit Zahl und Wirkung beieinander stehen.
			var bundle := GameRun.offer_cards(offer)
			data["title"] = engraving.display_name
			data["body"] = engraving.description if bundle == 1 \
				else "%s\n%d einzelne Karten im Bündel." % [engraving.description, bundle]
	return data

## Der Griff in der Bucht kauft: derselbe Weg wie die Karte am Sitz.
func buy_offer(index: int) -> void:
	_on_offer_pressed(index)

# --- Auslage ------------------------------------------------------------------

## Baut den Karten-Sitz neu, sortiert die Ware in die Bucht und zieht Börse und
## Misch-Preis nach. Rebuild statt Patch: ein verkaufter Platz wechselt seine
## ganze Gestalt.
func _refresh_offers() -> void:
	if not _built or run == null:
		return
	wallet_label.text = "⚡ %d/%d" % [run.energy, run.energy_cap()]
	for child in card_seat.get_children():
		card_seat.remove_child(child)
		child.queue_free()
	offer_buttons.clear()
	_charm_hovered = false
	_bay_packs.clear()
	_bay_dice.clear()
	_bay_kinds.clear()
	var thumb_px := int(u * 13.0)
	if locked:
		# Vergittert wird nichts gewürfelt: der Sitz verspricht eine Karte, die
		# Bucht bleibt dunkel - ein besserer Köder als Platzhalter-Ware.
		card_seat.add_child(_build_shadow_card(thumb_px))
		_vitrine_grade = ShopController.GRADE_STAND
		vitrine_changed.emit()
		return
	offer_buttons.resize(run.secret_stock.size())
	var seat := card_slot_index()
	if seat >= 0:
		var card := _build_charm_card(run.secret_stock[seat], seat, thumb_px,
			run.secret_offer_price(run.secret_stock[seat]))
		card_seat.add_child(card)
		offer_buttons[seat] = card
	for i in run.secret_stock.size():
		_sort_into_bay(run.secret_stock[i], i == seat)
	# Ein WURF lässt die neue Ware aufsteigen, ein Kauf lässt sie liegen.
	var rolls := run.secret_rerolls if run.secret_shop_unlocked else -1
	_vitrine_grade = ShopController.GRADE_STAND if rolls == _seen_rolls \
		else ShopController.GRADE_RISE
	_seen_rolls = rolls
	_refresh_afford_state()
	vitrine_changed.emit()

## Ein Auslage-Platz wird zur körperlichen Ware: der Essenzwürfel liegt offen, der
## Sonderbestand liegt versiegelt als seine Kassette (das Bündel als Stapel mit
## seiner Zahl). Verkauft, vergeben oder Karte heißt: dieser Platz bleibt leer - die
## SORTE des Platzes bleibt trotzdem gemeldet (row_kinds), damit die Lücke ihren
## Ort behält.
func _sort_into_bay(offer: Dictionary, on_card_seat: bool) -> void:
	var pack: Pack = null
	var die: DieDefinition = null
	if on_card_seat:
		_bay_kinds.append("")
	elif offer[GameRun.OFFER_KIND] == GameRun.KIND_DIE:
		_bay_kinds.append(ShopController.KIND_DIE)
	else:
		_bay_kinds.append(ShopController.KIND_ENGRAVING_PACK)
	if not on_card_seat and not bool(offer[GameRun.OFFER_SOLD]):
		match String(offer[GameRun.OFFER_KIND]):
			GameRun.KIND_DIE:
				die = offer[GameRun.OFFER_ITEM]
			GameRun.KIND_CATALYST:
				pack = offer[GameRun.OFFER_ITEM]
			GameRun.KIND_ENGRAVING:
				pack = Pack.fixed_engraving_pack(offer[GameRun.OFFER_ITEM] as Engraving,
					GameRun.offer_cards(offer))
	_bay_packs.append(pack)
	_bay_dice.append(die)

## Kaufbarkeit der Karte und des Misch-Knopfs am Ladungsstand ausrichten. Die Ware
## in der Bucht sperrt sich nicht - ihr Schild sagt den Preis.
func _refresh_afford_state() -> void:
	if not _built or run == null:
		return
	var cost := run.secret_reroll_cost()
	reroll_button.text = "Neu mischen ⚡%d" % cost
	reroll_button.disabled = run.energy < cost
	for i in offer_buttons.size():
		if i >= run.secret_stock.size() or offer_buttons[i] == null:
			continue
		var offer := run.secret_stock[i]
		var sold: bool = offer[GameRun.OFFER_SOLD]
		offer_buttons[i].disabled = sold or _offer_blocked(offer) \
			or run.energy < run.secret_offer_price(offer)

## Ob ein Platz an einem vollen Lager hängt: der Charm am Dock, die versiegelte
## Ware am Magazin (buy_secret_offer prüft dasselbe VOR dem Zahlen). Der Würfel
## hängt an keinem - er geht ins Ausgabefach, und das hat keinen Deckel.
func _offer_blocked(offer: Dictionary) -> bool:
	if run == null:
		return false
	if offer[GameRun.OFFER_KIND] == GameRun.KIND_CHARM:
		return run.charms_full()
	if offer[GameRun.OFFER_KIND] == GameRun.KIND_DIE:
		return false
	return run.pack_room() < GameRun.offer_cards(offer)

## Die EINE Karte am Sitz: der legendäre Charm, in der Laden-Grammatik - oben der
## NAME, in der Mitte das MODELL, unten der PREIS. Die volle Wirkung zeigt der
## INFO-FUSS beim Hover (hover_charm), wie bei der Bucht-Ware - das Modell BLEIBT,
## nichts schwebt über der Karte. Lizenzen sind digitale Ware und bleiben Bildschirm.
## price kommt fertig vom Aufrufer (GameRun.secret_offer_price) - die Hehlerware
## soll auf dem Schild stehen, nicht erst an der Kasse auffallen.
func _build_charm_card(offer: Dictionary, index: int, thumb_px: int, price: int) -> Button:
	var sold: bool = offer[GameRun.OFFER_SOLD]
	var charm: Charm = offer[GameRun.OFFER_ITEM]
	var tint := charm.rarity_color()

	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_theme_stylebox_override("normal", _card_box(CARD_BG, tint, 0.7, 0.24))
	card.add_theme_stylebox_override("hover", _card_box(Color("#241a4add"), Color(1.4, 1.1, 0.2), 0.95, 0.3))
	card.add_theme_stylebox_override("pressed", _card_box(Color("#2e2160"), Color(1.4, 1.1, 0.2), 1.0, 0.3))
	card.add_theme_stylebox_override("disabled", _card_box(Color("#100c2266"), tint, 0.2, 0.0))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Der Rand liegt als eigener Container um die Spalte: die Stylebox-Ränder des
	# Knopfs greifen bei verankerten Kindern nicht.
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, int(u * 0.8))
	card.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 0.8))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(column)

	# Der NAME steht oben - eine Ware ohne Namen ist keine Ware.
	var name_px := maxi(8, int(u * 2.6))
	var name_line := _label(charm.display_name, name_px,
		NEON_MUTED if sold else NEON_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_line.clip_text = true
	name_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_line)

	# Die MITTELFLÄCHE trägt das Modell im Lichtfleck - immer, denn die Wirkung
	# steht jetzt im Fuß. Sie füllt den Rest des Sitzbandes.
	var stage := CenterContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow_disc(tint, thumb_px * 1.5))
	var face: Control = CharmThumb.new(charm, thumb_px)
	if sold:
		face.modulate = Color(1, 1, 1, 0.3)  # die Ware ist weg, der Platz bleibt
	stage.add_child(face)
	column.add_child(stage)

	# Volles Dock: der Sitz zeigt das statt seines Preises.
	var blocked := _offer_blocked(offer)
	var tag := "VERKAUFT" if sold else ("DOCK VOLL" if blocked else "⚡ %d" % price)
	column.add_child(_label(tag, u * 3.0,
		NEON_MUTED if sold or blocked else ENERGY_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	if not sold:
		card.pressed.connect(_on_offer_pressed.bind(index))
	return card

## Schatten-Sitz des vergitterten Ladens: dieselbe Kartenform, aber leer - er
## verspricht einen Platz, nicht eine bestimmte Ware.
func _build_shadow_card(thumb_px: int) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_theme_stylebox_override("panel", _card_box(Color("#100c2266"), VIOLET, 0.3, 0.0))
	var stage := CenterContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow_disc(VIOLET, thumb_px))
	stage.add_child(_label("?", u * 8.0, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.6),
		HORIZONTAL_ALIGNMENT_CENTER))
	card.add_child(stage)
	return card

# --- Gitter -------------------------------------------------------------------

## Dunkler Schleier über der ganzen Tasche, in seiner Mitte die Bedingung.
## Liegt als LETZTES Kind auf allem anderen.
func _build_lock_overlay() -> void:
	lock_overlay = Panel.new()
	lock_overlay.name = "LockOverlay"
	lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # nichts darunter ist anfassbar
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.01, 0.06, 0.72)
	box.set_corner_radius_all(int(u * 1.2))
	lock_overlay.add_theme_stylebox_override("panel", box)
	add_child(lock_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_overlay.add_child(center)
	lock_notice = _label("Ab Lizenzstufe %d" % GameRun.SECRET_UNLOCK_HUB_LEVEL,
		u * 4.6, VIOLET, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(lock_notice)

# --- Käufe --------------------------------------------------------------------

func _on_offer_pressed(index: int) -> void:
	if run == null or index < 0 or index >= run.secret_stock.size():
		return
	var price := run.secret_offer_price(run.secret_stock[index])
	# Was versiegelt hinausgeht, ist ein neues Paket im Magazin, ein Würfel ein
	# neuer Platz im Ausgabefach - gemerkt wird beides VOR dem Kauf, damit die
	# Meldung genau dieses Exemplar meint.
	var stocked := run.owned_packs.size()
	var stashed := run.pending_dice.size()
	if not run.buy_secret_offer(index):  # Refresh kommt über secret_stock_changed
		return
	energy_spent.emit(price)
	if run.owned_packs.size() > stocked:
		var uids: Array[int] = []
		for i in range(stocked, run.owned_packs.size()):
			uids.append(run.owned_packs[i].pack_uid)
		goods_purchased.emit(uids)
	elif run.pending_dice.size() > stashed:
		die_purchased.emit(run.pending_dice.back())

func _on_reroll_pressed() -> void:
	if run == null:
		return
	var cost := run.secret_reroll_cost()
	if run.reroll_secret_stock():
		energy_spent.emit(cost)

func _on_run_changed() -> void:
	_refresh_offers()

## Energie allein ändert die Auslage nicht - nur wer was bezahlen kann.
func _on_energy_changed(_value: int) -> void:
	if _built and run != null:
		wallet_label.text = "⚡ %d/%d" % [run.energy, run.energy_cap()]
		_refresh_afford_state()

# --- Bausteine ----------------------------------------------------------------

func _label(text: String, font_size: float, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _card_box(fill: Color, border: Color, border_alpha: float, glow_alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color(border.r, border.g, border.b, border_alpha)
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(int(u * 1.2))
	box.set_content_margin_all(int(u * 0.8))
	if glow_alpha > 0.0:
		box.shadow_color = Color(border.r, border.g, border.b, glow_alpha)
		box.shadow_size = int(u * 1.0)
	return box

func _neon_button(text: String, accent: Color, font_size: float, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	button.add_theme_color_override("font_color", NEON_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.4, 1.1, 0.2))
	button.add_theme_color_override("font_pressed_color", Color(1.4, 1.1, 0.2))
	button.add_theme_color_override("font_disabled_color",
		Color(NEON_MUTED.r, NEON_MUTED.g, NEON_MUTED.b, 0.45))
	button.add_theme_stylebox_override("normal", _button_box(Color("#1a1236cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#251a4add"), Color(1.4, 1.1, 0.2)))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#30235e"), Color(1.4, 1.1, 0.2)))
	button.add_theme_stylebox_override("focus", _button_box(Color("#1a1236cc"), accent))
	button.add_theme_stylebox_override("disabled",
		_button_box(Color("#12102466"), Color(accent.r, accent.g, accent.b, 0.25)))
	return button

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.8))
	return box

## Dünne Lichtschiene, die nach rechts ausläuft.
func _rail(accent: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([
		Color(accent.r, accent.g, accent.b, 0.7), Color(accent.r, accent.g, accent.b, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 4
	var rail := TextureRect.new()
	rail.texture = texture
	rail.stretch_mode = TextureRect.STRETCH_SCALE
	rail.custom_minimum_size = Vector2(u * 4.0, u * 0.35)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rail

## Weicher radialer Lichtfleck hinter der Ware.
func _glow_disc(tint: Color, side: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(tint.r, tint.g, tint.b, 0.34), Color(tint.r, tint.g, tint.b, 0.12),
		Color(tint.r, tint.g, tint.b, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 96
	texture.height = 96
	var disc := TextureRect.new()
	disc.texture = texture
	disc.stretch_mode = TextureRect.STRETCH_SCALE
	disc.custom_minimum_size = Vector2(side, side)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return disc
