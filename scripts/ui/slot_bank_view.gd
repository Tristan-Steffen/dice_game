class_name SlotBankView
extends Panel
## Tisch-Fenster links vom Hub (unter der Ablage): die drei Fumble-Automaten.
## Symbol-Wand - jeder Automat zeigt 3×4 Symbole; alle drei ergeben eine 4×9-Wand.
## Gewinne entstehen durch REIHEN (3+ gleiche waagerecht nebeneinander, über
## Automaten-Grenzen hinweg); drei Fumbles nebeneinander löschen den Topf. Auszahlen
## löst alle Reihen auf. Mutiert den Zustand nur über GameRun (spin_slot/
## redeem_slots); die Animation lebt hier.
##
## Die AUSZAHLUNG ist der PERLENZUG: je Gewinn-Reihe zündet ein Funke am
## Reihenanfang und läuft die Neon-Linie ab; jede passierte Zelle erlischt und
## schickt eine PERLE die Linie entlang zur Sammelstelle am Reihenende. Dort steht
## dann der TOKEN, der den Gewinn NENNT, und mit seinem Abtritt fliegt das Licht -
## gebucht wird beim Abflug, je Preis (prize_dispatched).

## Ein Automat ist ausgelaufen (machine, hat er gebustet) - scene_root spielt
## Ton/Licht. cashed_out beim Auszahlen (Zahl der Reihen); die Preise reisen danach
## EINZELN über prize_dispatched, je Reihe am Ende ihres Perlenzugs.
signal spun_out(machine: int, fumbled: bool)
signal cashed_out(runs: int)
## Ein Gewinn verläßt das Fenster (Startpunkt in Display-Pixeln); scene_root fliegt
## ihn an sein Ziel. Erst hier wird er gebucht.
signal prize_dispatched(prize: SlotPrize, from_px: Vector2)
## Einsatz ist bezahlt: scene_root schickt die Energie als Licht zum Automaten.
## Die Walze wartet auf ihre Ankunft (coin_travel_time).
signal spin_paid(machine: int)

const TITLE_COLOR := Color("#ff6b5c")   # Fumble-Rot als Signatur
const TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (Glow)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GREEN := Color("#50fa7b")
const RED := Color("#ff5555")
const GOLD := Color("#ffd319")
const CYAN := Color("#8be9fd")
## Der Würfel trägt Silber: Cyan gehört seit dem ⚡-Symbol der Energie.
const DIE_COLOR := Color("#dfe6f5")
const BAR_BG := Color("#100e20")
## Tier-Akzente der drei Automaten: Kupfer, Silber, Gold.
const TIER_COLORS := [Color("#e08a4a"), Color("#c9d2e6"), Color("#ffd35e")]
const READY_GLYPH := "·"

## Der Rand, in dem der Inhalt steht - EINE Quelle für Aufbau und Plattform.
const CONTENT_MARGIN_UNITS := 3.0
const CONTENT_TOP_UNITS := 2.2

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
const REEL_SYMBOLS := ["◉", "◆", "▣", "⚡", "★"]

## Der Takt des PERLENZUGS: Funkenlauf je Zelle, Perlen-Flug zur Sammelstelle,
## Token-Auftritt, -Halt und -Abtritt, Luft zwischen zwei Reihen.
const FUSE_CELL_TIME := 0.05
const BEAD_TIME := 0.12
const TOKEN_POP := 0.09
const TOKEN_HOLD := 0.28
const TOKEN_DEPART := 0.08
const RUN_GAP := 0.06

var run: GameRun

## Laufzeit der Münze (Münzfenster -> Hub -> Automat); setzt scene_root nach dem
## Platzieren. 0 = sofort drehen (Tests, Fenster-UI-Rückfall ohne Adern).
var coin_travel_time := 0.0

var _content: VBoxContainer
## Neon-Linien über den Walzen, die jede aktive Kombination verbinden (auf self,
## damit sie spaltenübergreifend über die Automaten-Lücken hinweg zeichnen).
var _run_overlay: RunOverlay
## Je Automat MACHINE_COLS Spalten-Panels (geklammert, für die Streifen-Animation).
var _reel_cols: Array = [[], [], []]
## Je Automat der Dreh-Knopf (oder null) - für die Bezahlbarkeits-Aktualisierung.
var _spin_buttons: Array = [null, null, null]
## Je Automat MACHINE_COLS Spalten à ROWS Symbol-Labels (Ruhe-Anzeige).
var _face_labels: Array = [[], [], []]
## Je Automat der gelandete Block (Array MACHINE_COLS Spalten à ROWS Kinds),
## leer = noch nicht gedreht.
var _landed: Array = []
var _spinning := false
var _spinning_index := -1
var _just_landed := -1  # nach dem Neuaufbau angestupste Walze
## Tweens der Walzenfahrt - die Symbolstreifen, die ein Neuaufbau (_build)
## mitsamt ihren Spalten freigibt.
var _spin_tweens: Array[Tween] = []
## Läuft der Perlenzug? Sperrt Dreh, Auszahlen und den Idle-Neuaufbau.
var _paying := false
var _payout_gen := 0
## Preise der laufenden Auszahlung, je Eintrag {prize, run, from_px, gone}. Der Lauf
## hängt mit dran: ein Neustart mitten in der Auszahlung darf die Ware nicht dem
## NEUEN Lauf gutschreiben.
var _pending: Array[Dictionary] = []
## Tweens und Geister (Token) des Perlenzugs - der Abbruch räumt beide.
var _payout_tweens: Array[Tween] = []
var _payout_ghosts: Array = []
var locked := true
var _lock_overlay: Panel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Knöpfe fangen selbst
	clip_contents = true
	add_theme_stylebox_override("panel", TableScreen.window_style())
	_reset_landed()

func _reset_landed() -> void:
	_landed.clear()
	for i in SlotMachine.MACHINE_COUNT:
		_landed.append([])

## scene_root nach Zustandswechseln (Hub-Aufstieg, Panel-Anzeige). Eine laufende
## Auszahlung wird vorher hart zu Ende gebracht - sonst verlöre ein Neuaufbau Gewinne.
func refresh() -> void:
	finish_payout_now()
	_build()

## Aufbau nur, wenn keine Dreh-/Auszahlungs-Animation läuft - für den WECHSEL auf
## den Automaten, damit die Knopf-Bezahlbarkeit dem aktuellen Energiestand folgt.
## Das Idle-Gate schützt eine laufende Walze bzw. einen laufenden Perlenzug.
func refresh_if_idle() -> void:
	if _spinning or _paying:
		return
	_build()

# --- Aufbau --------------------------------------------------------------------

func _build() -> void:
	var u := _unit()
	_kill_spin_tweens()  # die alten Streifen gehen gleich weg, ihre Tweens dürfen nicht nachlaufen
	if _content != null and is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_reel_cols = [[], [], []]
	_spin_buttons = [null, null, null]
	_face_labels = [[], [], []]
	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = u * CONTENT_MARGIN_UNITS
	_content.offset_right = -u * CONTENT_MARGIN_UNITS
	_content.offset_top = u * CONTENT_TOP_UNITS
	_content.offset_bottom = -u * CONTENT_TOP_UNITS
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

	_build_lock_overlay()
	_update_overlay()

## Zeichnet je aktive Kombination eine Neon-Linie durch ihre Zellen. Läuft nach
## einem Layout-Frame (Label-Positionen stehen erst dann fest); während des Drehens
## und bei Bust bleibt das Overlay leer.
func _update_overlay() -> void:
	if _paying:
		return  # die Linien gehören gerade der Zeremonie
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
	if not is_instance_valid(_run_overlay) or _paying:
		return
	var lines: Array = []
	if run != null and not _spinning and not run.slot_bank.busted:
		var u := _unit()
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
	elif run != null and not run.slots_enabled():
		button.text = "Strom aus"  # Stromsperre: kein Preis, der Automat ist tot
		button.disabled = true
		accent = MUTED_COLOR
	else:
		button.text = "gratis" if run.slot_spin_charge(i) <= 0 else "Drehen  %d⚡" % run.slot_spin_charge(i)
		var can := not _spinning and run != null and run.can_spin_slot(i)
		button.disabled = not can
		if can:
			button.pressed.connect(_on_spin_pressed.bind(i))
	_style_button(button, accent)
	if i >= 0 and i < _spin_buttons.size():
		_spin_buttons[i] = button
	return button

## Topf-Ablage: die aufgelaufenen Gewinn-Reihen und der große Auszahlen-/Neustart-Knopf.
## Der Fuß unter den Walzen: der Auszahlen-Knopf, die Legende und die Regel. Die
## TOPF-Anzeige (Kopf, Reihenzahl, Chips) ist fort - der Topf liegt körperlich in
## seiner Grube, sein Abbild im Fenster war doppelt.
func _pot_tray(u: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(u * 0.7))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var busted := run != null and run.slot_bank.busted
	var runs: Array = run.slot_bank.runs() if run != null else []

	box.add_child(_cash_out_button(u, busted, runs.size()))
	box.add_child(_legend_row(u))
	box.add_child(_label("3+ gleiche nebeneinander = Gewinn. 3 Fumble nebeneinander = Topf weg.",
		u * 2.0, MUTED_COLOR))
	return box

## Legende: was jedes Wand-Symbol bedeutet. Glyphen/Farben kommen aus SlotPrize/
## _kind_color, damit sie nie von der Wand abweichen.
func _legend_row(u: float) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", int(u * 1.6))
	flow.add_theme_constant_override("v_separation", int(u * 0.3))
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var names := {
		SlotPrize.Kind.ENGRAVING: "Zahlen", SlotPrize.Kind.MATERIAL: "Material",
		SlotPrize.Kind.DICE_ENGRAVING: "Runen", SlotPrize.Kind.CHARGE: "Energie",
		SlotPrize.Kind.WILD: "Joker", SlotPrize.Kind.FUMBLE: "Fumble"}
	for kind in [SlotPrize.Kind.ENGRAVING, SlotPrize.Kind.MATERIAL, SlotPrize.Kind.DICE_ENGRAVING,
			SlotPrize.Kind.CHARGE, SlotPrize.Kind.WILD, SlotPrize.Kind.FUMBLE]:
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

## Die EINE Einheit des Fensters.
func _unit() -> float:
	return maxf(size.x, 200.0) / 100.0

# --- Aktionen ------------------------------------------------------------------

## Einwurf und Dreh: die Energie geht sofort weg (ihr Licht macht sich auf den
## Weg), die Walze läuft erst an, wenn sie angekommen ist - der Einwurf IST der
## Startschuss, nicht bloß Beiwerk.
func _on_spin_pressed(machine: int) -> void:
	if _spinning or _paying or run == null or not run.can_spin_slot(machine):
		return
	_spinning = true
	_spinning_index = machine
	# Der Preis VOR dem Dreh: ein Gratisdreh (Freispiel-Charm, Freispiel-Klausel)
	# kostet keine Energie, also fährt auch kein Einsatz-Licht.
	var price := run.slot_spin_charge(machine)
	var block := run.spin_slot(machine)
	if block.is_empty():
		_spinning = false
		_spinning_index = -1
		return
	if price > 0:
		spin_paid.emit(machine)
	_build()  # sperrt alle Knöpfe während des Drehens; Walzen bleiben
	if coin_travel_time > 0.0:
		await get_tree().create_timer(coin_travel_time).timeout
		if not is_instance_valid(self) or _spinning_index != machine:
			return  # Fenster weg oder Sitzung inzwischen zurückgesetzt
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
	_spin_tweens.clear()
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
		_spin_tweens.append(tween)
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
		_spin_tweens.append(blur)
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
	# Erst JETZT das Ergebnis auf die Wand schreiben: Topf und Bust erscheinen mit
	# der Landung, nicht schon beim Einwurf.
	if run != null:
		run.commit_slot(machine, block)
	_landed[machine] = block
	_spinning = false
	_spinning_index = -1
	_just_landed = machine
	spun_out.emit(machine, run != null and run.slot_bank.busted)
	_build()

func _on_cash_out_pressed() -> void:
	if _spinning or _paying or run == null:
		return
	# Bust ODER gedreht-ohne-Gewinn: die Wand verwerfen und neu drehbar machen.
	if run.slot_bank.busted or (run.slot_bank.hit_count() < 1 and run.slot_bank.any_spun()):
		run.slot_bank.reset_session()
		_reset_landed()
		_build()
		return
	if run.slot_bank.hit_count() < 1:
		return
	# Die Linien-Geometrie VOR dem Einlösen einfrieren - danach ist die Wand leer.
	var plans := _payout_plans()
	var result := run.redeem_slots()
	_assign_prizes(plans, result["prizes"])
	cashed_out.emit((result["runs"] as Array).size())
	_flash_win()
	_paying = true
	_payout_gen += 1
	_play_payout(plans, _payout_gen)

# --- Der PERLENZUG (die Auszahlung) ----------------------------------------------

## Friert je Gewinn-Reihe die Zeremonie-Daten ein, BEVOR redeem_slots die Wand
## leert: Linienpunkte (lokal), Zell-Labels, Farbe, Glyphe und die Token-Aufschrift.
## Die Aufschrift ist der Gewinn-Teil des Reihen-Labels - EINE Textquelle
## (SlotMachine._run_label), hier wird nichts zweitformuliert.
func _payout_plans() -> Array:
	var plans: Array = []
	var u := _unit()
	for descriptor in run.slot_bank.runs():
		var labels: Array = []
		var points := PackedVector2Array()
		for cell in descriptor["cells"]:
			var lbl := _label_for_cell(int(cell[0]), int(cell[1]))
			if lbl == null or not is_instance_valid(lbl):
				continue
			labels.append(lbl)
			points.append(lbl.get_global_rect().get_center() - global_position)
		var kind := int(descriptor["kind"])
		plans.append({
			"kind": kind, "labels": labels, "points": points,
			"color": _kind_color(kind), "glyph": SlotPrize.symbol_for(kind),
			"caption": String(descriptor["label"]).get_slice("→", 1).strip_edges(),
			"spec_count": (descriptor["specs"] as Array).size(),
			"width": maxf(2.0, u * 1.1), "entries": [],
		})
	return plans

## Ordnet die eingelösten Preise ihren Reihen zu (redeem_slots münzt sie in
## Reihen-Reihenfolge, je Spec einen) und meldet sie als ausstehend an - samt dem
## Lauf, der sie gewonnen hat, und ihrem Abflug-Pixel (der Sammelstelle).
func _assign_prizes(plans: Array, prizes: Array) -> void:
	var index := 0
	for plan: Dictionary in plans:
		var pts: PackedVector2Array = plan["points"]
		var from_px := position + (pts[pts.size() - 1] if pts.size() > 0 else size * 0.5)
		var entries: Array = []
		for i in int(plan["spec_count"]):
			if index >= prizes.size():
				break
			var entry := {"prize": prizes[index], "run": run, "from_px": from_px, "gone": false}
			index += 1
			entries.append(entry)
			_pending.append(entry)
		plan["entries"] = entries

## Spielt die Reihen NACHEINANDER ab. Jeder await ist mit der Generation geguardet;
## der Abbruch (finish_payout_now) bucht, was noch aussteht - kein Gewinn hängt je
## an der Animation.
func _play_payout(plans: Array, gen: int) -> void:
	# Die eingefrorenen Linien gehören jetzt der Zeremonie (die Wand ist schon leer).
	if is_instance_valid(_run_overlay):
		var lines: Array = []
		for plan: Dictionary in plans:
			var pts: PackedVector2Array = plan["points"]
			lines.append({"points": pts.duplicate() if pts.size() >= 2 else PackedVector2Array(),
				"color": plan["color"], "width": plan["width"]})
		_run_overlay.lines = lines
		_run_overlay.queue_redraw()
	for i in plans.size():
		if gen != _payout_gen or not is_instance_valid(self):
			return
		await _burn_run(plans[i], i, gen)
		if gen != _payout_gen or not is_instance_valid(self):
			return
		await get_tree().create_timer(RUN_GAP).timeout
	if gen != _payout_gen or not is_instance_valid(self):
		return
	_paying = false
	_pending.clear()
	_reset_landed()
	_build()

## EINE Reihe: der Funke läuft die Linie ab (die Perlen schickt _burn_step), dann
## steht der Token an der Sammelstelle und nennt den Gewinn.
func _burn_run(plan: Dictionary, line_index: int, gen: int) -> void:
	var points: PackedVector2Array = plan["points"]
	if points.size() >= 2:
		var burnt := {}
		var fuse_time := FUSE_CELL_TIME * (points.size() - 1)
		var fuse := create_tween()
		_payout_tweens.append(fuse)
		fuse.tween_method(_burn_step.bind(plan, line_index, burnt), 0.0, 1.0, fuse_time)
		# Erst wenn Funke UND letzte Perle angekommen sind, tritt der Token auf.
		await get_tree().create_timer(fuse_time + BEAD_TIME).timeout
		if gen != _payout_gen or not is_instance_valid(self):
			return
	elif points.size() == 1:
		_consume_cell(plan, 0, points[0])
	_clear_line(line_index)
	await _present_token(plan, gen)

## Ein Bild des Funkenlaufs: die Linie hinter dem Funken ist fort, jede passierte
## Zelle erlischt und schickt ihre Perle.
func _burn_step(progress: float, plan: Dictionary, line_index: int, burnt: Dictionary) -> void:
	if not is_instance_valid(self) or not is_instance_valid(_run_overlay):
		return
	var points: PackedVector2Array = plan["points"]
	var last := points.size() - 1
	if last < 1:
		return
	var head := progress * last
	for i in points.size():
		if float(i) <= head + 0.001 and not burnt.has(i):
			burnt[i] = true
			_consume_cell(plan, i, points[last])
	var seg := mini(int(floor(head)), last - 1)
	var spark := points[seg].lerp(points[seg + 1], head - float(seg))
	var trimmed := PackedVector2Array([spark])
	for i in range(seg + 1, points.size()):
		trimmed.append(points[i])
	if line_index < _run_overlay.lines.size():
		_run_overlay.lines[line_index]["points"] = trimmed if trimmed.size() >= 2 			else PackedVector2Array()
		_run_overlay.queue_redraw()

## Zelle i ist verbraucht: ihr Wand-Label erlischt, und ihre Glyphen-PERLE gleitet
## zur Sammelstelle (die Zellen einer Reihe sind kollinear - die Gerade IST die
## Linie). Die letzte Zelle ist die Sammelstelle selbst und schickt nichts.
func _consume_cell(plan: Dictionary, i: int, end: Vector2) -> void:
	var labels: Array = plan["labels"]
	if i < labels.size():
		var lbl: Label = labels[i]
		if is_instance_valid(lbl):
			lbl.modulate = Color(lbl.modulate.r, lbl.modulate.g, lbl.modulate.b, 0.08)
	var points: PackedVector2Array = plan["points"]
	if i >= points.size() or points[i].distance_to(end) < 1.0:
		return
	if not is_instance_valid(_run_overlay):
		return
	var color: Color = plan["color"]
	var bead := {"pos": points[i], "radius": float(plan["width"]) * 1.7, "color": color}
	_run_overlay.beads.append(bead)
	var from: Vector2 = points[i]
	var slide := func(t: float) -> void:
		if is_instance_valid(_run_overlay):
			bead["pos"] = from.lerp(end, t)
			_run_overlay.queue_redraw()
	var drop := func() -> void:
		if is_instance_valid(_run_overlay):
			_run_overlay.beads.erase(bead)
			_run_overlay.queue_redraw()
	var glide := create_tween()
	_payout_tweens.append(glide)
	glide.tween_method(slide, 0.0, 1.0, BEAD_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	glide.tween_callback(drop)

func _clear_line(line_index: int) -> void:
	if is_instance_valid(_run_overlay) and line_index < _run_overlay.lines.size():
		_run_overlay.lines[line_index]["points"] = PackedVector2Array()
		_run_overlay.queue_redraw()

## Die Sammelstelle: der TOKEN poppt auf, NENNT den Gewinn (Glyphe + Aufschrift im
## Reihen-Akzent), hält kurz - und mit seinem Abtritt wird je Preis gebucht und
## sein Licht geschickt.
func _present_token(plan: Dictionary, gen: int) -> void:
	var points: PackedVector2Array = plan["points"]
	var at: Vector2 = points[points.size() - 1] if points.size() > 0 else size * 0.5
	var u := _unit()
	var color: Color = plan["color"]
	var token := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.95)
	box.border_color = color
	box.set_border_width_all(maxi(2, int(u * 0.35)))
	box.set_corner_radius_all(int(u * 1.2))
	box.set_content_margin_all(int(u * 1.0))
	token.add_theme_stylebox_override("panel", box)
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.add_child(_label("%s %s" % [plan["glyph"], plan["caption"]], u * 2.6, TEXT_COLOR))
	token.scale = Vector2.ZERO  # unsichtbar, bis er vermessen und gesetzt ist
	token.z_index = 6
	add_child(token)
	_payout_ghosts.append(token)
	await get_tree().process_frame  # ein Layout-Bild: erst dann kennt er sein Maß
	if gen != _payout_gen or not is_instance_valid(token) or not is_instance_valid(self):
		return
	# Mittig auf der Sammelstelle, in die Fensterränder geklemmt (das Reihenende
	# kann am Rand liegen).
	token.position = Vector2(
		clampf(at.x - token.size.x * 0.5, u, size.x - token.size.x - u),
		clampf(at.y - token.size.y * 0.5, u, size.y - token.size.y - u))
	token.pivot_offset = token.size * 0.5
	var pop := create_tween()
	_payout_tweens.append(pop)
	pop.tween_property(token, "scale", Vector2.ONE, TOKEN_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(TOKEN_POP + TOKEN_HOLD).timeout
	if gen != _payout_gen or not is_instance_valid(self):
		return
	if is_instance_valid(token):
		var out := create_tween()
		_payout_tweens.append(out)
		out.tween_property(token, "scale", Vector2.ZERO, TOKEN_DEPART).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		out.tween_callback(func() -> void:
			if is_instance_valid(token):
				_payout_ghosts.erase(token)
				token.queue_free())
	for entry: Dictionary in plan["entries"]:
		_depart_entry(entry)

## EIN Preis verläßt das Fenster: buchen (auf den Lauf, der ihn gewonnen hat),
## dann sein Licht. Idempotent - Ungeduld darf keinen Gewinn kosten.
func _depart_entry(entry: Dictionary) -> void:
	if entry.get("gone", false):
		return
	entry["gone"] = true
	var owner_run: GameRun = entry["run"]
	if owner_run != null:
		owner_run.book_slot_prize(entry["prize"])
	prize_dispatched.emit(entry["prize"], entry["from_px"])

## Bringt eine laufende Auszahlung sofort hart zu Ende (Neuaufbau, Laufwechsel,
## Ungeduld): jeder ausstehende Preis wird gebucht und verschickt, Funke, Perlen
## und Token sterben. Der EINE Aufräum-Pfad des Perlenzugs.
func finish_payout_now() -> void:
	_payout_gen += 1
	for tween in _payout_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_payout_tweens.clear()
	for ghost in _payout_ghosts:
		if ghost != null and is_instance_valid(ghost):
			ghost.queue_free()
	_payout_ghosts.clear()
	for entry in _pending:
		_depart_entry(entry)
	_pending.clear()
	if is_instance_valid(_run_overlay):
		_run_overlay.lines = []
		_run_overlay.beads.clear()
		_run_overlay.queue_redraw()
	if _paying:
		_paying = false
		_reset_landed()  # die verbrauchte Wand darf den Abbruch nicht überleben

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

func _kill_spin_tweens() -> void:
	for tween in _spin_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_spin_tweens.clear()

# --- Sperre (Fenster vor Freischaltung) ----------------------------------------

func set_locked(is_locked: bool) -> void:
	locked = is_locked
	if _lock_overlay != null and is_instance_valid(_lock_overlay):
		_lock_overlay.visible = locked
	if _content != null and is_instance_valid(_content):
		_content.modulate = Color(1, 1, 1, 0.35) if locked else Color.WHITE

func _build_lock_overlay() -> void:
	if _lock_overlay != null and is_instance_valid(_lock_overlay):
		_lock_overlay.queue_free()
	_lock_overlay = Panel.new()
	_lock_overlay.name = "LockOverlay"
	_lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lock_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.01, 0.06, 0.72)
	var u := _unit()
	box.set_corner_radius_all(int(u * 1.2))
	_lock_overlay.add_theme_stylebox_override("panel", box)
	add_child(_lock_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_overlay.add_child(center)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	var title := _label("Ab Lizenzstufe %d" % GameRun.HUB_SLOT_LEVELS[0],
		u * 4.6, TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var name_lbl := _label(GameRun.HUB_LEVEL_NAMES[GameRun.HUB_SLOT_LEVELS[0] - 1],
		u * 3.4, MUTED_COLOR)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_lbl)
	_lock_overlay.visible = locked
	if _content != null and is_instance_valid(_content):
		_content.modulate = Color(1, 1, 1, 0.35) if locked else Color.WHITE

# --- Bausteine -----------------------------------------------------------------

## Symbolfarben = Paket-/Schubladenfarben: dieselbe Ware, dieselbe Farbe -
## egal ob im Laden, in der Schublade oder auf der Walze.
func _kind_color(kind: int) -> Color:
	match kind:
		SlotPrize.Kind.ENGRAVING: return PackIconRenderer.COLORS[Pack.TYPE_NUMBER]
		SlotPrize.Kind.MATERIAL: return PackIconRenderer.COLORS[Pack.TYPE_MATERIAL]
		SlotPrize.Kind.DICE_ENGRAVING: return PackIconRenderer.DICE_ENGRAVING_COLOR
		SlotPrize.Kind.CHARGE: return CYAN
		SlotPrize.Kind.DIE: return DIE_COLOR
		SlotPrize.Kind.WILD: return GOLD
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
	## Die PERLEN des Perlenzugs: je Eintrag {pos: Vector2, radius: float,
	## color: Color} - unterwegs zur Sammelstelle ihrer Reihe.
	var beads: Array = []

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
		for bead in beads:
			var c: Color = bead["color"]
			var r: float = bead["radius"]
			var at: Vector2 = bead["pos"]
			draw_circle(at, r * 2.0, Color(c.r, c.g, c.b, 0.3))
			draw_circle(at, r, Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, 0.95))
