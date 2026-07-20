class_name SlotBankView
extends Panel
## Tisch-Fenster links vom Hub (unter der Ablage): die drei Fumble-Automaten.
## Symbol-Wand - jeder Automat zeigt 3×5 Symbole; alle drei ergeben eine 5×9-Wand.
## Gewinne entstehen durch REIHEN (3+ gleiche waagerecht nebeneinander, über
## Automaten-Grenzen hinweg); drei Fumbles nebeneinander löschen den Topf. Auszahlen
## löst alle Reihen auf. Mutiert den Zustand nur über GameRun (spin_slot/
## redeem_slots); die Animation lebt hier.

## Ein Automat ist ausgelaufen (machine, hat er gebustet) - scene_root spielt
## Ton/Licht. cashed_out nach der Auszahlung (Zahl der Reihen).
signal spun_out(machine: int, fumbled: bool)
signal cashed_out(multiplier: int)

const TITLE_COLOR := Color("#ff6b5c")   # Fumble-Rot als Signatur
const TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (Glow)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GREEN := Color("#50fa7b")
const RED := Color("#ff5555")
const GOLD := Color("#ffd319")
const CYAN := Color("#8be9fd")
const ENGRAVING_GLOW := Color("#c77dff")
const BAR_BG := Color("#100e20")
## Tier-Akzente der drei Automaten: Kupfer, Silber, Gold.
const TIER_COLORS := [Color("#e08a4a"), Color("#c9d2e6"), Color("#ffd35e")]
const READY_GLYPH := "·"

## Walzenfahrt: Symbolstreifen läuft von oben durchs Fenster, bremst über die
## letzten Zellen ab und rastet mit Überschwung ein. Die drei Spalten je Automat
## landen versetzt (COL_STAGGER) von links nach rechts.
const SPIN_CELLS := 16
const SPIN_BRAKE_CELLS := 5
const SPIN_FAST_TIME := 0.35
const SPIN_BRAKE_TIME := 0.7
const SETTLE_OVERSHOOT := 0.15
const SETTLE_TIME := 0.15
const COL_STAGGER := 0.18
const REEL_SYMBOLS := ["$", "◈", "✦", "⬢"]

var run: GameRun

var _content: VBoxContainer
## Neon-Linien über den Walzen, die jede aktive Kombination verbinden (auf self,
## damit sie spaltenübergreifend über die Automaten-Lücken hinweg zeichnen).
var _run_overlay: RunOverlay
## Auszahlungs-Jubel am Sitzungsende: Gravur-Icons und Münzen ploppen auf.
var _reveal: Control
## Je Automat MACHINE_COLS Spalten-Panels (geklammert, für die Streifen-Animation).
var _reel_cols: Array = [[], [], []]
## Je Automat MACHINE_COLS Spalten à ROWS Symbol-Labels (Ruhe-Anzeige).
var _face_labels: Array = [[], [], []]
## Je Automat der gelandete Block (Array MACHINE_COLS Spalten à ROWS Kinds),
## leer = noch nicht gedreht.
var _landed: Array = []
var _spinning := false
var _spinning_index := -1
var _just_landed := -1  # nach dem Neuaufbau angestupste Walze

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Knöpfe fangen selbst
	clip_contents = true
	add_theme_stylebox_override("panel", TableScreen.window_style())
	_reset_landed()

func _reset_landed() -> void:
	_landed.clear()
	for i in SlotMachine.MACHINE_COUNT:
		_landed.append([])

## scene_root nach Zustandswechseln (Hub-Aufstieg, Panel-Anzeige).
func refresh() -> void:
	_build()

# --- Aufbau --------------------------------------------------------------------

func _build() -> void:
	var u := maxf(size.x, 200.0) / 100.0
	if _content != null and is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_reel_cols = [[], [], []]
	_face_labels = [[], [], []]
	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = u * 3.0
	_content.offset_right = -u * 3.0
	_content.offset_top = u * 2.2
	_content.offset_bottom = -u * 2.2
	_content.add_theme_constant_override("separation", int(u * 1.6))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_content.add_child(_label("FUMBLE-AUTOMATEN", u * 5.0, TITLE_COLOR))

	# Zellen von Gewinn-Reihen leuchten, Fumble-Reihen (2+) drohen rot.
	var run_set := {}
	var fumble_set := {}
	if run != null:
		for descriptor in run.slot_bank.runs():
			for cell in descriptor["cells"]:
				run_set["%d_%d" % [cell[0], cell[1]]] = true
		for cell in run.slot_bank.fumble_run_cells(2):
			fumble_set["%d_%d" % [cell[0], cell[1]]] = true

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 1.6))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in SlotMachine.MACHINE_COUNT:
		row.add_child(_machine_column(i, u, run_set, fumble_set))
	_content.add_child(row)

	_content.add_child(_pot_tray(u))

	# Linien-Overlay als oberste Ebene neu aufsetzen (über den Symbolen).
	if _run_overlay != null and is_instance_valid(_run_overlay):
		_run_overlay.queue_free()
	_run_overlay = RunOverlay.new()
	_run_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_run_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_run_overlay)

	# Frisch gelandete Walze anstupsen (Pop/Blitz), nachdem sie im Baum steht.
	if _just_landed >= 0 and _just_landed < _landed.size():
		var idx := _just_landed
		var block: Array = _landed[idx]
		_just_landed = -1
		_pop_reel(idx, block)

	_update_overlay()

## Zeichnet je aktive Kombination eine Neon-Linie durch ihre Zellen. Läuft nach
## einem Layout-Frame (Label-Positionen stehen erst dann fest); während des Drehens
## und bei Bust bleibt das Overlay leer.
func _update_overlay() -> void:
	# Warten, bis das Layout STEHT: verschachtelte Container setzen erst Größen, dann
	# Positionen über mehrere Frames - erst wenn eine Referenzzelle zwei Frames lang
	# dieselbe Mitte hat, sind die Positionen verlässlich.
	var last := Vector2(-9999, -9999)
	for _i in 12:
		await get_tree().process_frame
		if not is_instance_valid(_run_overlay):
			return
		var probe := _label_for_cell(0, 0)
		if probe == null or not is_instance_valid(probe):
			continue
		var here := probe.get_global_rect().get_center()
		if here == last and here.y > 0.0:
			break
		last = here
	if not is_instance_valid(_run_overlay):
		return
	var lines: Array = []
	if run != null and not _spinning and not run.slot_bank.busted:
		var u := maxf(size.x, 200.0) / 100.0
		for descriptor in run.slot_bank.runs():
			var pts := PackedVector2Array()
			for cell in descriptor["cells"]:
				var lbl := _label_for_cell(int(cell[0]), int(cell[1]))
				if lbl == null or not is_instance_valid(lbl):
					continue
				pts.append(lbl.get_global_rect().get_center() - _run_overlay.global_position)
			if pts.size() >= 2:
				var c := _kind_color(int(descriptor["kind"]))
				lines.append({"points": pts, "color": c, "width": maxf(2.0, u * 1.1)})
	_run_overlay.lines = lines
	_run_overlay.queue_redraw()

## Ruhe-Label einer Wand-Zelle [col,row] (oder null, wenn nicht vorhanden).
func _label_for_cell(col: int, row: int) -> Label:
	var machine := col / SlotMachine.MACHINE_COLS
	var lc := col % SlotMachine.MACHINE_COLS
	if machine >= _face_labels.size() or lc >= _face_labels[machine].size():
		return null
	var labels: Array = _face_labels[machine][lc]
	if row >= labels.size():
		return null
	return labels[row]

## Eine Automaten-Spalte: Name, Walzenfenster (MACHINE_COLS×ROWS Symbole), Dreh-Knopf.
func _machine_column(i: int, u: float, run_set: Dictionary, fumble_set: Dictionary) -> Control:
	var unlocked := run != null and i < run.slots_unlocked()
	var spinning := _spinning and i == _spinning_index
	var block: Array = _landed[i]
	var tier: Color = TIER_COLORS[i]

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(u * 0.8))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var roman: String = ["I", "II", "III"][i]
	var head := _label("Automat %s · %s" % [roman, SlotMachine.MACHINE_NAMES[i]], u * 2.4,
		tier if unlocked else MUTED_COLOR)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)

	col.add_child(_reel_window(i, u, tier, unlocked, spinning, block, run_set, fumble_set))
	col.add_child(_spin_button(i, u, tier, unlocked, spinning, block))
	return col

## Walzenfenster: geklammertes Panel mit MACHINE_COLS Spalten à ROWS Symbolen.
func _reel_window(i: int, u: float, tier: Color, unlocked: bool, spinning: bool,
		block: Array, run_set: Dictionary, fumble_set: Dictionary) -> Control:
	var window := Panel.new()
	window.custom_minimum_size = Vector2(0, u * 13.0)  # Untergrenze; EXPAND_FILL füllt den Rest
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = BAR_BG if unlocked else Color(0.06, 0.05, 0.11, 0.9)
	box.border_color = Color(tier.r, tier.g, tier.b, 0.9 if unlocked else 0.3)
	box.set_border_width_all(maxi(2, int(u * 0.4)))
	box.set_corner_radius_all(int(u * 1.4))
	window.add_theme_stylebox_override("panel", box)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", int(u * 0.5))
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var has_block := not block.is_empty() and not spinning
	var cols: Array = []
	var col_labels: Array = []
	for lc in SlotMachine.MACHINE_COLS:
		var slot := Panel.new()
		slot.clip_contents = true
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel", _slot_bg())
		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.add_theme_constant_override("separation", 0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var labels: Array = []
		for r in SlotMachine.ROWS:
			var cell := _symbol_cell(u)
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if has_block:
				var kind: int = block[lc][r]
				cell.text = SlotPrize.symbol_for(kind)
				cell.modulate = _cell_color(kind, i * SlotMachine.MACHINE_COLS + lc, r, run_set, fumble_set)
			else:
				cell.text = READY_GLYPH
				cell.modulate = Color(tier.r, tier.g, tier.b, 0.55 if unlocked else 0.22)
			vb.add_child(cell)
			labels.append(cell)
		slot.add_child(vb)
		hbox.add_child(slot)
		cols.append(slot)
		col_labels.append(labels)
	window.add_child(hbox)
	window.add_child(_window_shade())
	_reel_cols[i] = cols
	_face_labels[i] = col_labels
	return window

## Farbe einer gelandeten Zelle: Reihe leuchtet in Symbolfarbe, Fumble-Reihe droht
## rot, alles andere ist gedämpft (kein Gewinn).
func _cell_color(kind: int, col: int, row: int, run_set: Dictionary, fumble_set: Dictionary) -> Color:
	var key := "%d_%d" % [col, row]
	if kind == SlotPrize.Kind.FUMBLE:
		return Color(2.0, 0.35, 0.35) if fumble_set.has(key) else Color(RED.r * 0.6, RED.g * 0.45, RED.b * 0.45)
	if run_set.has(key):
		var c := _kind_color(kind)
		return Color(c.r * 1.4, c.g * 1.4, c.b * 1.4)
	var base := _kind_color(kind)
	return Color(base.r * 0.5, base.g * 0.5, base.b * 0.5)

func _slot_bg() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.025, 0.07, 0.5)
	box.set_corner_radius_all(4)
	return box

## Ein Symbol-Label (zentriert). Schrift folgt der Fensterhöhe; neun Spalten sind
## schmal, darum kleiner als bei den alten großen Faces.
func _symbol_cell(_u: float) -> Label:
	var cell := Label.new()
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.clip_text = true
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sy := maxf(size.y, 200.0) / 100.0
	cell.add_theme_font_size_override("font_size", maxi(9, int(sy * 6.0)))
	return cell

## Vertikale Schatten-Blende oben/unten - lässt die flachen Streifen wie gewölbte
## Trommeln wirken. Liegt immer als oberstes Kind im Walzenfenster.
func _window_shade() -> TextureRect:
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.22, 0.78, 1.0])
	grad.colors = PackedColorArray([
		Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0),
		Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	shade.texture = tex
	return shade

func _spin_button(i: int, u: float, tier: Color, unlocked: bool, spinning: bool,
		block: Array) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, u * 6.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", maxi(8, int(u * 2.5)))
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var accent := tier
	if not unlocked:
		button.text = "ab %s" % GameRun.HUB_LEVEL_NAMES[GameRun.HUB_SLOT_LEVELS[i] - 1]
		button.disabled = true
		accent = MUTED_COLOR
	elif spinning:
		button.text = "dreht…"
		button.disabled = true
	elif not block.is_empty():
		button.text = "gedreht"
		button.disabled = true
	else:
		button.text = "Drehen  $%d" % run.slot_spin_price(i)
		var can := not _spinning and run != null and run.can_spin_slot(i)
		button.disabled = not can
		if can:
			button.pressed.connect(_on_spin_pressed.bind(i))
	_style_button(button, accent)
	return button

## Topf-Ablage: die aufgelaufenen Gewinn-Reihen und der große Auszahlen-/Neustart-Knopf.
func _pot_tray(u: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(u * 0.7))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var busted := run != null and run.slot_bank.busted
	var runs: Array = run.slot_bank.runs() if run != null else []

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("TOPF", u * 3.0, MUTED_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if runs.size() > 0 and not busted:
		header.add_child(_label("%d Reihe%s" % [runs.size(), "" if runs.size() == 1 else "n"],
			u * 2.8, GOLD))
	box.add_child(header)

	if busted:
		box.add_child(_label("Fumble – der Topf ist verloren.", u * 3.0, RED))
	elif runs.is_empty():
		box.add_child(_label("keine Reihe – noch nichts im Topf.", u * 2.8, MUTED_COLOR))
	else:
		box.add_child(_pot_summary_chips(u))

	box.add_child(_cash_out_button(u, busted, runs.size()))
	box.add_child(_legend_row(u))
	box.add_child(_label("3+ gleiche nebeneinander = Gewinn. 3 Fumble nebeneinander = Topf weg.",
		u * 2.0, MUTED_COLOR))
	return box

## Aufsummierte Gesamtausschüttung des Topfs als wenige Chips (Geld, Gravuren,
## Charms, Würfel) statt jeder einzelnen Reihe.
func _pot_summary_chips(u: float) -> Control:
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", int(u * 1.2))
	chips.add_theme_constant_override("v_separation", int(u * 0.6))
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var summary: Dictionary = run.slot_bank.pot_summary()
	if int(summary["money"]) > 0:
		chips.add_child(_summary_chip(GOLD, "$%d" % int(summary["money"]), u))
	var sig := int(summary["engravings"])
	if sig > 0:
		chips.add_child(_summary_chip(ENGRAVING_GLOW, "%s %d Gravur%s"
			% [SlotPrize.symbol_for(SlotPrize.Kind.ENGRAVING), sig, "" if sig == 1 else "en"], u))
	var charms: Array = summary["charms"]
	if not charms.is_empty():
		chips.add_child(_summary_chip(GREEN, "%s %s"
			% [SlotPrize.symbol_for(SlotPrize.Kind.CHARM), _charm_chip_text(charms)], u))
	var dice := int(summary["dice"])
	if dice > 0:
		chips.add_child(_summary_chip(CYAN, "%s %d Würfel"
			% [SlotPrize.symbol_for(SlotPrize.Kind.DIE), dice], u))
	return chips

## Ein zusammengefasster Gewinn-Chip (Symbol-Farbe + Text).
func _summary_chip(color: Color, text: String, u: float) -> Control:
	var chip := Label.new()
	chip.text = text
	chip.add_theme_font_size_override("font_size", maxi(9, int(u * 2.8)))
	chip.add_theme_color_override("font_color", TEXT_COLOR)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := StyleBoxFlat.new()
	pad.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.9)
	pad.border_color = color
	pad.set_border_width_all(maxi(1, int(u * 0.2)))
	pad.set_corner_radius_all(int(u * 1.2))
	pad.set_content_margin_all(int(u * 0.7))
	chip.add_theme_stylebox_override("normal", pad)
	return chip

func _charm_chip_text(charms: Array) -> String:
	if charms.size() == 1:
		return "%s Charm" % _rarity_adjective(String(charms[0]))
	return "%d Charms" % charms.size()

func _rarity_adjective(rarity: String) -> String:
	match rarity:
		Charm.RARITY_COMMON: return "gewöhnlicher"
		Charm.RARITY_UNCOMMON: return "ungewöhnlicher"
		Charm.RARITY_RARE: return "seltener"
		Charm.RARITY_LEGENDARY: return "legendärer"
	return ""

## Legende: was jedes Wand-Symbol bedeutet. Glyphen/Farben kommen aus SlotPrize/
## _kind_color, damit sie nie von der Wand abweichen.
func _legend_row(u: float) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", int(u * 1.6))
	flow.add_theme_constant_override("v_separation", int(u * 0.3))
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var names := {
		SlotPrize.Kind.MONEY: "Geld", SlotPrize.Kind.ENGRAVING: "Gravur",
		SlotPrize.Kind.CHARM: "Charm", SlotPrize.Kind.DIE: "Würfel",
		SlotPrize.Kind.FUMBLE: "Fumble"}
	for kind in [SlotPrize.Kind.MONEY, SlotPrize.Kind.ENGRAVING, SlotPrize.Kind.CHARM,
			SlotPrize.Kind.DIE, SlotPrize.Kind.FUMBLE]:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", int(u * 0.4))
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(_label(SlotPrize.symbol_for(kind), u * 2.4, _kind_color(kind)))
		var word := _label(names[kind], u * 2.0, MUTED_COLOR)
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		entry.add_child(word)
		flow.add_child(entry)
	return flow

func _cash_out_button(u: float, busted: bool, hits: int) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, u * 6.4)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", maxi(9, int(u * 3.0)))
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var spun_out := run != null and run.slot_bank.any_spun()
	if busted:
		button.text = "Neue Sitzung"
		button.disabled = _spinning
		if not _spinning:
			button.pressed.connect(_on_cash_out_pressed)
		_style_button(button, CYAN)
	elif hits >= 1:
		button.text = "Auszahlen  (%d)" % hits
		button.disabled = _spinning
		if not _spinning:
			button.pressed.connect(_on_cash_out_pressed)
		_style_button(button, GOLD)
	elif spun_out:
		# Gedreht, aber keine Reihe: Wand verwerfen, damit die Automaten wieder
		# drehbar werden (sonst säße der Spieler fest - kein Gewinn, kein Bust).
		button.text = "Neu drehen"
		button.disabled = _spinning
		if not _spinning:
			button.pressed.connect(_on_cash_out_pressed)
		_style_button(button, CYAN)
	else:
		button.text = "Auszahlen"
		button.disabled = true
		_style_button(button, MUTED_COLOR)
	return button

# --- Aktionen ------------------------------------------------------------------

func _on_spin_pressed(machine: int) -> void:
	if _spinning or run == null or not run.can_spin_slot(machine):
		return
	_spinning = true
	_spinning_index = machine
	var block := run.spin_slot(machine)
	if block.is_empty():
		_spinning = false
		_spinning_index = -1
		return
	_build()  # sperrt alle Knöpfe während des Drehens; Walzen bleiben
	_spin_reel(machine, block)

## Echte Walzenfahrt: die MACHINE_COLS Spalten laufen versetzt (links zuerst) und
## rasten mit Überschwung ein. Der Landungs-Callback hängt an der letzten Spalte.
func _spin_reel(machine: int, block: Array) -> void:
	if machine >= _reel_cols.size() or _reel_cols[machine].size() < SlotMachine.MACHINE_COLS:
		_on_reel_landed(machine, block)
		return
	# EXPAND_FILL: Spaltenhöhe steht erst nach einem Layout-Frame fest.
	await get_tree().process_frame
	var cols: Array = _reel_cols[machine]
	for slot in cols:
		if not is_instance_valid(slot) or slot.size.y <= 0.0:
			_on_reel_landed(machine, block)
			return
	for lc in SlotMachine.MACHINE_COLS:
		var slot: Panel = cols[lc]
		var ch := slot.size.y / float(SlotMachine.ROWS)
		var strip := _build_col_strip(machine, block[lc], slot, ch)
		var start := -(SPIN_CELLS - SlotMachine.ROWS) * ch
		strip.position.y = start
		for lbl in _face_labels[machine][lc]:
			if is_instance_valid(lbl):
				lbl.visible = false
		var slide := func(y: float) -> void:
			if is_instance_valid(strip):
				strip.position.y = y
		var delay := lc * COL_STAGGER
		var tween := create_tween()
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_method(slide, start, -SPIN_BRAKE_CELLS * ch, SPIN_FAST_TIME)
		tween.tween_method(slide, -SPIN_BRAKE_CELLS * ch, ch * SETTLE_OVERSHOOT, SPIN_BRAKE_TIME) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_method(slide, ch * SETTLE_OVERSHOOT, 0.0, SETTLE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if lc == SlotMachine.MACHINE_COLS - 1:
			tween.tween_callback(func() -> void: _on_reel_landed(machine, block))
		# Leichte "Unschärfe" bei voller Fahrt, klart beim Bremsen wieder auf.
		strip.modulate.a = 0.65
		var clear := func(a: float) -> void:
			if is_instance_valid(strip):
				strip.modulate.a = a
		var blur := create_tween()
		if delay > 0.0:
			blur.tween_interval(delay)
		blur.tween_method(clear, 0.65, 1.0, SPIN_FAST_TIME + SPIN_BRAKE_TIME * 0.5)

## Symbolstreifen einer Spalte: oben die ROWS gelandeten Symbole, dazwischen
## Zufall, unten Ruhe-Glyphen für einen nahtlosen Start.
func _build_col_strip(machine: int, col_block: Array, slot: Panel, ch: float) -> Control:
	var strip := VBoxContainer.new()
	strip.add_theme_constant_override("separation", 0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(strip)
	strip.position = Vector2.ZERO
	strip.size = Vector2(slot.size.x, SPIN_CELLS * ch)
	var sy := maxf(size.y, 200.0) / 100.0
	var font := maxi(9, int(sy * 6.0))
	for j in SPIN_CELLS:
		var cell := Label.new()
		cell.custom_minimum_size = Vector2(0, ch)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_theme_font_size_override("font_size", font)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if j < SlotMachine.ROWS:
			var kind: int = col_block[j]
			cell.text = SlotPrize.symbol_for(kind)
			cell.modulate = _kind_color(kind) if kind != SlotPrize.Kind.FUMBLE else RED
		elif j >= SPIN_CELLS - SlotMachine.ROWS:
			cell.text = READY_GLYPH
			cell.modulate = TEXT_COLOR
		else:
			cell.text = REEL_SYMBOLS[randi() % REEL_SYMBOLS.size()]
			cell.modulate = TEXT_COLOR
		strip.add_child(cell)
	return strip

func _on_reel_landed(machine: int, block: Array) -> void:
	_landed[machine] = block
	_spinning = false
	_spinning_index = -1
	_just_landed = machine
	spun_out.emit(machine, run != null and run.slot_bank.busted)
	_build()

func _on_cash_out_pressed() -> void:
	if _spinning or run == null:
		return
	# Bust ODER gedreht-ohne-Gewinn: die Wand verwerfen und neu drehbar machen.
	if run.slot_bank.busted or (run.slot_bank.hit_count() < 1 and run.slot_bank.any_spun()):
		run.slot_bank.reset_session()
		_reset_landed()
		_build()
		return
	if run.slot_bank.hit_count() < 1:
		return
	var result := run.redeem_slots()
	_reset_landed()
	cashed_out.emit(int(result["runs"].size()))
	_build()
	_flash_win()
	_play_payout_reveal(result["prizes"])

# --- Animation ------------------------------------------------------------------

## Landungs-Effekt: jede Zelle pocht kurz auf; Fumble-Zellen blitzen rot.
func _pop_reel(machine: int, block: Array) -> void:
	if block.is_empty() or machine >= _face_labels.size():
		return
	var col_labels: Array = _face_labels[machine]
	for lc in col_labels.size():
		var labels: Array = col_labels[lc]
		for r in labels.size():
			var lbl: Label = labels[r]
			if not is_instance_valid(lbl):
				continue
			lbl.pivot_offset = lbl.size / 2.0
			lbl.scale = Vector2.ONE * 1.35
			var pop := create_tween()
			pop.tween_property(lbl, "scale", Vector2.ONE, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if lc < block.size() and r < block[lc].size() and block[lc][r] == SlotPrize.Kind.FUMBLE:
				var flash := create_tween()
				flash.tween_property(lbl, "modulate", Color(2.2, 0.35, 0.35), 0.08)
				flash.tween_property(lbl, "modulate", lbl.modulate, 0.3)

## Gewinn-Auszahlung: der ganze Rahmen blitzt golden auf.
func _flash_win() -> void:
	var glow := create_tween()
	glow.tween_property(self, "modulate", Color(1.5, 1.35, 0.7), 0.12)
	glow.tween_property(self, "modulate", Color.WHITE, 0.4)

# --- Auszahlungs-Jubel -----------------------------------------------------------

const RARITY_COLORS := {
	Engraving.Rarity.COMMON: Color("#8be9fd"),
	Engraving.Rarity.UNCOMMON: Color("#50fa7b"),
	Engraving.Rarity.RARE: Color("#ffd319"),
}

## Zeigt am Sitzungsende, WAS und WIE VIEL gewonnen wurde: Münzen für Geld, je ein
## Icon je Gravur-Art (mit Anzahl), dazu Charm/Würfel. Die Token ploppen gestaffelt
## auf, halten kurz und blenden aus.
func _play_payout_reveal(prizes: Array) -> void:
	var money := 0
	var engraving_counts := {}   # id -> {engraving, count}
	var engraving_order: Array = []
	var charms: Array = []
	var dice := 0
	for prize: SlotPrize in prizes:
		match prize.kind:
			SlotPrize.Kind.MONEY:
				money += prize.money
			SlotPrize.Kind.ENGRAVING:
				for s: Engraving in prize.engravings:
					if not engraving_counts.has(s.id):
						engraving_counts[s.id] = {"engraving": s, "count": 0}
						engraving_order.append(s.id)
					engraving_counts[s.id]["count"] += 1
			SlotPrize.Kind.CHARM:
				if prize.charm != null:
					charms.append(prize.charm)
			SlotPrize.Kind.DIE:
				dice += 1
	if money <= 0 and engraving_order.is_empty() and charms.is_empty() and dice == 0:
		return

	var u := maxf(size.x, 200.0) / 100.0
	if _reveal != null and is_instance_valid(_reveal):
		_reveal.queue_free()
	_reveal = Control.new()
	_reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reveal)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.06, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.add_child(center)

	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", int(u * 1.6))
	flow.add_theme_constant_override("v_separation", int(u * 1.2))
	flow.custom_minimum_size = Vector2(size.x * 0.86, 0)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(flow)

	var tokens: Array = []
	if money > 0:
		tokens.append(_coin_token(money, u))
	for id in engraving_order:
		tokens.append(_engraving_token(engraving_counts[id]["engraving"], int(engraving_counts[id]["count"]), u))
	for charm in charms:
		tokens.append(_glyph_token("✦", GREEN, charm.display_name, u))
	if dice > 0:
		tokens.append(_glyph_token("⬢", CYAN, "%d Würfel" % dice, u))
	for token in tokens:
		token.scale = Vector2.ZERO  # unsichtbar bis zum Pop (kein Aufblitzen)
		flow.add_child(token)

	_animate_reveal(tokens)

## Pop-in gestaffelt (Pivot erst nach dem Layout), halten, ausblenden, freigeben.
func _animate_reveal(tokens: Array) -> void:
	await get_tree().process_frame
	if not is_instance_valid(_reveal):
		return
	var last := 0.0
	for i in tokens.size():
		var token: Control = tokens[i]
		if not is_instance_valid(token):
			continue
		token.pivot_offset = token.size / 2.0
		var pop := create_tween()
		pop.tween_interval(i * 0.09)
		pop.tween_property(token, "scale", Vector2.ONE, 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		last = i * 0.09
	var fade := create_tween()
	fade.tween_interval(last + 1.7)
	fade.tween_property(_reveal, "modulate:a", 0.0, 0.5)
	fade.tween_callback(func() -> void:
		if is_instance_valid(_reveal):
			_reveal.queue_free())

## Münz-Token: gezeichneter Münzstapel + „+$N".
func _coin_token(money: int, u: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(u * 0.6))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := CoinStack.new()
	stack.custom_minimum_size = Vector2(u * 12.0, u * 10.0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stack)
	var label := _label("+$%d" % money, u * 3.0, Color(GOLD.r * 1.5, GOLD.g * 1.4, GOLD.b * 0.9))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return box

## Gravur-Token: Icon (Textur oder Ersatz-Kachel) mit Raritäts-Rahmen, Anzahl-
## Plakette und Name.
func _engraving_token(engraving: Engraving, count: int, u: float) -> Control:
	var color: Color = RARITY_COLORS.get(engraving.rarity, MUTED_COLOR)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(u * 0.5))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(u * 11.5, u * 11.5)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fbox := StyleBoxFlat.new()
	fbox.bg_color = Color(color.r * 0.16, color.g * 0.16, color.b * 0.16, 0.95)
	fbox.border_color = color
	fbox.set_border_width_all(maxi(2, int(u * 0.5)))
	fbox.set_corner_radius_all(int(u * 1.6))
	frame.add_theme_stylebox_override("panel", fbox)

	var icon := _engraving_icon_node(engraving, u)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = u * 1.2
	icon.offset_top = u * 1.2
	icon.offset_right = -u * 1.2
	icon.offset_bottom = -u * 1.2
	frame.add_child(icon)

	if count > 1:
		var badge := _label("×%d" % count, u * 3.4, TEXT_COLOR)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		badge.offset_right = -u * 0.8
		badge.offset_bottom = -u * 0.4
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.05, 0.03, 0.12, 0.85)
		badge.add_theme_stylebox_override("normal", bg)
		frame.add_child(badge)
	box.add_child(frame)

	var name := _label(engraving.display_name, u * 1.9, Color(color.r * 1.2, color.g * 1.2, color.b * 1.2))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.custom_minimum_size = Vector2(u * 11.5, 0)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name)
	return box

## Icon einer Gravur: Textur, falls vorhanden, sonst eine Ersatz-Kachel mit Glyphe.
func _engraving_icon_node(engraving: Engraving, u: float) -> Control:
	if engraving.texture_path != "" and ResourceLoader.exists(engraving.texture_path):
		var tex := TextureRect.new()
		tex.texture = load(engraving.texture_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tex
	var fallback := _label("◈", u * 6.2, RARITY_COLORS.get(engraving.rarity, ENGRAVING_GLOW))
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return fallback

## Einfaches Glyph-Token (Charm/Würfel): großes Symbol + Name.
func _glyph_token(glyph: String, color: Color, caption: String, u: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(u * 0.5))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(u * 11.5, u * 11.5)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fbox := StyleBoxFlat.new()
	fbox.bg_color = Color(color.r * 0.16, color.g * 0.16, color.b * 0.16, 0.95)
	fbox.border_color = color
	fbox.set_border_width_all(maxi(2, int(u * 0.5)))
	fbox.set_corner_radius_all(int(u * 1.6))
	frame.add_theme_stylebox_override("panel", fbox)
	var glyph_label := _label(glyph, u * 6.2, Color(color.r * 1.3, color.g * 1.3, color.b * 1.3))
	glyph_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(glyph_label)
	box.add_child(frame)
	var caption_label := _label(caption, u * 1.9, Color(color.r * 1.2, color.g * 1.2, color.b * 1.2))
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.custom_minimum_size = Vector2(u * 11.5, 0)
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(caption_label)
	return box

# --- Bausteine -----------------------------------------------------------------

func _kind_color(kind: int) -> Color:
	match kind:
		SlotPrize.Kind.MONEY: return GOLD
		SlotPrize.Kind.ENGRAVING: return ENGRAVING_GLOW
		SlotPrize.Kind.CHARM: return GREEN
		SlotPrize.Kind.DIE: return CYAN
	return RED  # Fumble

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color(accent.r, accent.g, accent.b, 0.55))
	button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#2c2757dd"), GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#3a2f66"), GOLD))
	button.add_theme_stylebox_override("disabled", _button_box(Color("#1a183666"), Color(accent.r, accent.g, accent.b, 0.25)))

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var u := maxf(size.x, 200.0) / 100.0
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.6))
	return box

## Zeichnet die Verbindungslinien aktiver Kombinationen als Neon-Polylinien (breit-
## blass darunter, schmal-hell darüber). Reine Anzeige, fängt keine Eingaben.
class RunOverlay:
	extends Control
	## Je Eintrag {points: PackedVector2Array, color: Color, width: float}.
	var lines: Array = []

	func _draw() -> void:
		for line in lines:
			var pts: PackedVector2Array = line["points"]
			if pts.size() < 2:
				continue
			var col: Color = line["color"]
			var w: float = line["width"]
			draw_polyline(pts, Color(col.r, col.g, col.b, 0.28), w * 2.6, true)
			draw_polyline(pts, Color(col.r, col.g, col.b, 0.9), w, true)
			for p in pts:
				draw_circle(p, w * 0.9, Color(col.r, col.g, col.b, 0.85))

## Gezeichneter Münzstapel für das Auszahlungs-Token (drei überlappende Goldmünzen).
class CoinStack:
	extends Control

	const GOLD := Color("#ffd319")
	const GOLD_DARK := Color("#c8912a")

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.34
		var cx := size.x * 0.5
		for i in 3:
			var cy := size.y * 0.72 - i * r * 0.55
			draw_circle(Vector2(cx, cy + r * 0.16), r, Color(0, 0, 0, 0.35))       # Schatten
			draw_circle(Vector2(cx, cy), r, GOLD_DARK)                              # Rand
			draw_circle(Vector2(cx, cy), r * 0.82, GOLD)                            # Fläche
			draw_circle(Vector2(cx, cy), r * 0.5, Color(GOLD.r * 1.4, GOLD.g * 1.3, GOLD.b * 0.8))  # Glanz
