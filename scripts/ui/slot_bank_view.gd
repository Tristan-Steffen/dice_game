class_name SlotBankView
extends Panel
## Tisch-Fenster links vom Hub (unter der Ablage): die drei Fumble-Automaten.
## Push-your-luck - drehen sammelt Gewinne im Topf, ein „Fumble" löscht ihn und
## beendet die Sitzung; Auszahlen nimmt alles ×Trefferzahl. Mutiert den Zustand
## nur über GameRun (spin_slot/redeem_slots); die Animation lebt hier.

## Ein Automat ist ausgelaufen (machine, war es ein Fumble) - scene_root spielt
## Ton/Licht. cashed_out nach der Auszahlung (Multiplikator).
signal spun_out(machine: int, fumbled: bool)
signal cashed_out(multiplier: int)

const TITLE_COLOR := Color("#ff6b5c")   # Fumble-Rot als Signatur
const TEXT_COLOR := Color(1.35, 1.35, 1.3)  # überhelles Weiß (Glow)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GREEN := Color("#50fa7b")
const RED := Color("#ff5555")
const GOLD := Color("#ffd319")
const CYAN := Color("#8be9fd")
const SIGIL_GLOW := Color("#c77dff")
const BAR_BG := Color("#100e20")
## Tier-Akzente der drei Automaten: Kupfer, Silber, Gold.
const TIER_COLORS := [Color("#e08a4a"), Color("#c9d2e6"), Color("#ffd35e")]
const READY_GLYPH := "◎"

## Walzen-Auslauf: viele schnelle Symbolwechsel, deren Abstand wächst (Bremsen).
const SPIN_TIME := 0.85
const SPIN_START_DELAY := 0.035
const SPIN_DELAY_GROWTH := 1.14
const REEL_SYMBOLS := ["$", "◈", "✦", "⬢", "✖"]

var run: GameRun

var _content: VBoxContainer
var _reels: Array[Label] = []
## Zuletzt gelandeter Preis je Automat (null = noch nicht gedreht); nur für die
## Ruhe-Anzeige der Walze. Der Topf selbst kommt aus run.slot_bank.pending.
var _landed: Array[SlotPrize] = []
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
		_landed.append(null)

## scene_root nach Zustandswechseln (Hub-Aufstieg, Panel-Anzeige).
func refresh() -> void:
	_build()

# --- Aufbau --------------------------------------------------------------------

func _build() -> void:
	var u := maxf(size.x, 200.0) / 100.0
	if _content != null and is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_reels.clear()
	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = u * 3.0
	_content.offset_right = -u * 3.0
	_content.offset_top = u * 2.2
	_content.offset_bottom = -u * 2.2
	_content.add_theme_constant_override("separation", int(u * 1.8))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_content.add_child(_label("FUMBLE-AUTOMATEN", u * 5.0, TITLE_COLOR))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 1.6))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in SlotMachine.MACHINE_COUNT:
		row.add_child(_machine_column(i, u))
	_content.add_child(row)

	_content.add_child(_pot_tray(u))

	# Frisch gelandete Walze anstupsen (Pop/Blitz), nachdem sie im Baum steht.
	if _just_landed >= 0 and _just_landed < _reels.size():
		var idx := _just_landed
		var prize: SlotPrize = _landed[idx]
		_just_landed = -1
		_pop_reel(idx, prize)

## Eine Automaten-Spalte: Name, Walzenfenster, Dreh-Knopf.
func _machine_column(i: int, u: float) -> Control:
	var unlocked := run != null and i < run.slots_unlocked()
	var spinning := _spinning and i == _spinning_index
	var landed: SlotPrize = _landed[i]
	var tier: Color = TIER_COLORS[i]

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(u * 0.8))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var roman: String = ["I", "II", "III"][i]
	var head := _label("Automat %s · %s" % [roman, SlotMachine.MACHINE_NAMES[i]], u * 2.6,
		tier if unlocked else MUTED_COLOR)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)

	col.add_child(_reel_window(i, u, tier, unlocked, spinning, landed))
	col.add_child(_spin_button(i, u, tier, unlocked, spinning, landed))
	return col

## Walzenfenster (geklammertes Panel mit zentraler Symbol-Walze).
func _reel_window(i: int, u: float, tier: Color, unlocked: bool, spinning: bool, landed: SlotPrize) -> Control:
	var window := Panel.new()
	window.custom_minimum_size = Vector2(0, u * 8.0)  # Untergrenze; EXPAND_FILL füllt den Rest
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

	var reel := Label.new()
	reel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Symbolgröße folgt der Fensterhöhe (die Walzen sind breit-flach), nicht der Breite.
	var sy := maxf(size.y, 200.0) / 100.0
	reel.add_theme_font_size_override("font_size", maxi(12, int(sy * 14.0)))
	reel.clip_text = true
	reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if spinning:
		reel.text = REEL_SYMBOLS[randi() % REEL_SYMBOLS.size()]
		reel.modulate = TEXT_COLOR
	elif landed != null:
		reel.text = landed.symbol()
		reel.modulate = _prize_color(landed)
	else:
		reel.text = READY_GLYPH
		reel.modulate = Color(tier.r, tier.g, tier.b, 0.9 if unlocked else 0.28)
	window.add_child(reel)
	_reels.append(reel)
	return window

func _spin_button(i: int, u: float, tier: Color, unlocked: bool, spinning: bool, landed: SlotPrize) -> Button:
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
	elif landed != null:
		button.text = landed.label if landed.kind != SlotPrize.Kind.FUMBLE else "Fumble"
		button.disabled = true
		accent = _prize_color(landed)
	else:
		button.text = "Drehen  $%d" % run.slot_spin_price(i)
		var can := not _spinning and run != null and run.can_spin_slot(i)
		button.disabled = not can
		if can:
			button.pressed.connect(_on_spin_pressed.bind(i))
	_style_button(button, accent)
	return button

## Topf-Ablage: aufgelaufene Gewinne, Multiplikator-Plakette und der große
## Auszahlen-/Neustart-Knopf.
func _pot_tray(u: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(u * 0.8))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var busted := run != null and run.slot_bank.busted
	var pending: Array = run.slot_bank.pending if run != null else []
	var mult := run.slot_bank.multiplier() if run != null else 1

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("TOPF", u * 3.0, MUTED_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if mult >= 2 and not busted:
		var badge := _label("×%d" % mult, u * 4.4, Color(GOLD.r * 1.6, GOLD.g * 1.6, GOLD.b * 1.2))
		header.add_child(badge)
	box.add_child(header)

	if busted:
		box.add_child(_label("Fumble – der Topf ist verloren.", u * 3.0, RED))
	elif pending.is_empty():
		box.add_child(_label("leer – dreh einen Automaten.", u * 2.8, MUTED_COLOR))
	else:
		var wins := HFlowContainer.new()
		wins.add_theme_constant_override("h_separation", int(u * 1.2))
		wins.add_theme_constant_override("v_separation", int(u * 0.6))
		wins.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for prize: SlotPrize in pending:
			wins.add_child(_win_chip(prize, u))
		box.add_child(wins)

	box.add_child(_cash_out_button(u, busted, pending.size()))
	box.add_child(_label("35% Fumble löscht den Topf. 2 Treffer ×2, 3 ×3.", u * 2.3, MUTED_COLOR))
	return box

## Ein eingesammelter Gewinn als kleiner Chip (Symbol + Kurztext).
func _win_chip(prize: SlotPrize, u: float) -> Control:
	var color := _prize_color(prize)
	var chip := Label.new()
	chip.text = "%s %s" % [prize.symbol(), prize.label]
	chip.add_theme_font_size_override("font_size", maxi(8, int(u * 2.6)))
	chip.add_theme_color_override("font_color", TEXT_COLOR)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := StyleBoxFlat.new()
	pad.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.85)
	pad.border_color = color
	pad.set_border_width_all(maxi(1, int(u * 0.18)))
	pad.set_corner_radius_all(int(u * 1.2))
	pad.set_content_margin_all(int(u * 0.7))
	chip.add_theme_stylebox_override("normal", pad)
	return chip

func _cash_out_button(u: float, busted: bool, hits: int) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, u * 6.4)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", maxi(9, int(u * 3.0)))
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if busted:
		button.text = "Neue Sitzung"
		button.disabled = _spinning
		if not _spinning:
			button.pressed.connect(_on_cash_out_pressed)
		_style_button(button, CYAN)
	elif hits >= 1:
		button.text = "Auszahlen  ×%d" % (run.slot_bank.multiplier() if run != null else 1)
		button.disabled = _spinning
		if not _spinning:
			button.pressed.connect(_on_cash_out_pressed)
		_style_button(button, GOLD)
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
	var prize := run.spin_slot(machine)
	if prize == null:
		_spinning = false
		_spinning_index = -1
		return
	_build()  # sperrt alle Knöpfe während des Drehens; Walzen bleiben
	_spin_reel(machine, prize)

## Bremsende Symbol-Flimmerkette; am Ende landet der echte Preis.
func _spin_reel(machine: int, prize: SlotPrize) -> void:
	if machine >= _reels.size() or not is_instance_valid(_reels[machine]):
		_on_reel_landed(machine, prize)
		return
	var reel := _reels[machine]
	var tween := create_tween()
	var delay := SPIN_START_DELAY
	var elapsed := 0.0
	while elapsed < SPIN_TIME:
		tween.tween_callback(func() -> void:
			if is_instance_valid(reel):
				reel.text = REEL_SYMBOLS[randi() % REEL_SYMBOLS.size()])
		tween.tween_interval(delay)
		elapsed += delay
		delay *= SPIN_DELAY_GROWTH
	tween.tween_callback(func() -> void: _on_reel_landed(machine, prize))

func _on_reel_landed(machine: int, prize: SlotPrize) -> void:
	_landed[machine] = prize
	_spinning = false
	_spinning_index = -1
	_just_landed = machine
	spun_out.emit(machine, prize.kind == SlotPrize.Kind.FUMBLE)
	_build()

func _on_cash_out_pressed() -> void:
	if _spinning or run == null:
		return
	if run.slot_bank.busted:
		run.slot_bank.reset_session()
		_reset_landed()
		_build()
		return
	if run.slot_bank.hit_count() < 1:
		return
	var result := run.redeem_slots()
	_reset_landed()
	cashed_out.emit(int(result["multiplier"]))
	_build()
	_flash_win()

# --- Animation ------------------------------------------------------------------

## Landungs-Effekt: kurzer Squash-Pop; Fumble blitzt rot und rüttelt, ein Gewinn
## pocht in seiner Farbe auf.
func _pop_reel(index: int, prize: SlotPrize) -> void:
	if prize == null or index >= _reels.size() or not is_instance_valid(_reels[index]):
		return
	var reel := _reels[index]
	reel.pivot_offset = reel.size / 2.0
	reel.scale = Vector2.ONE * 1.6
	var tween := create_tween()
	tween.tween_property(reel, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if prize.kind == SlotPrize.Kind.FUMBLE:
		var start := reel.position
		var shake := create_tween()
		for i in 4:
			shake.tween_property(reel, "position:x", start.x + (6.0 if i % 2 == 0 else -6.0), 0.05)
		shake.tween_property(reel, "position:x", start.x, 0.05)

## Gewinn-Auszahlung: der ganze Rahmen blitzt golden auf.
func _flash_win() -> void:
	var glow := create_tween()
	glow.tween_property(self, "modulate", Color(1.5, 1.35, 0.7), 0.12)
	glow.tween_property(self, "modulate", Color.WHITE, 0.4)

# --- Bausteine -----------------------------------------------------------------

func _prize_color(prize: SlotPrize) -> Color:
	match prize.kind:
		SlotPrize.Kind.MONEY: return GOLD
		SlotPrize.Kind.SIGIL: return SIGIL_GLOW
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
