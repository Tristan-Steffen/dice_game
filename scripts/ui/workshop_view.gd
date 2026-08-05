class_name WorkshopView
extends Panel
## Tisch-Fenster rechts vom Hub: das Lager der gekauften, noch VERSIEGELTEN
## Pakete. Hier - und nur hier - werden sie geöffnet; der Laden verkauft nur.
## Zustands-Mutation läuft über GameRun (open_pack); die Zeremonie hängt an
## pack_activated und lebt in scene_root.

## Ein Paket wurde geöffnet (scene_root hängt Ton/Licht daran).
signal pack_activated(index: int)
## Ein Paket-Würfel hat einen Pool-Platz eingenommen.
signal die_placed(pool_index: int)
## Ein Gravur-Stück fliegt aus dem zerbrochenen Siegel - scene_root schickt es als
## Meteor in seine Schublade. from_px ist das Siegel auf dem Tisch, rarity färbt
## den Meteor.
signal engraving_dispatched(engraving_id: String, from_px: Vector2, rarity: int)
## Die Bühnen der Paket-Würfel haben sich geändert (Wahl, Einsetzen, Ende) -
## scene_root stellt die ECHTEN Würfel darüber neu auf.
signal die_stages_changed

const TITLE_COLOR := Color("#8be9fd")
const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")

## Spaltenzahl der Pool-Auswahl = Spaltenzahl der echten Trays (DiceTrayView),
## damit das Raster wie das Tray darüber liest.
const POOL_COLUMNS := 6
## Maße der Hover-Netzkarte in Einheiten - groß genug, dass Materialfarben,
## Stufen-Plaketten und der Essenz-Chip auf Werkbank-Distanz lesen.
const HOVER_CELL := 3.2
const HOVER_TITLE := 2.2
const HOVER_BODY := 1.7
## Maße der Hinweiskarte am unteren Fensterrand (Schubladen-Kachel, Netz-Zelle).
const INFO_TITLE := 2.4
const INFO_BODY := 1.9
## Feste Breite des Fließtexts: eine Karte, die mit ihrem Text wächst, springt
## bei jeder Kachel in eine andere Größe.
const INFO_WIDTH := 58.0
## Randluft der Karte zum Fensterrand.
const INFO_MARGIN := 1.4

## Höhe der Bühne eines schwebenden Paket-Würfels (Breiteneinheiten u): Platz für
## den Würfel UND seine Stasis-Station, die durch die Parallaxe ein Stück unter
## ihm auf der Fläche steht. Die BREITE gibt das Netz darunter vor - Würfel und
## Netz sind eine Spalte, und mit ihr rücken auch die drei Würfel auseinander.
const STAGE_HEIGHT := 11.0
const STAGE_GAP := 3.0
## Zellgröße des Netzes unter jedem Paket-Würfel: dieselbe Kachel wie das Netz der
## Gravur-Station - dort ist definiert, wie groß ein Würfel gezeigt wird, wenn
## man ÜBER ihn entscheidet. (Die Hover-Karte ist kleiner: sie ist nur Auskunft.)
const CHOICE_CELL := DieInspectorView.TRAY_TILE
## Aufhellung des überfahrenen Netzes - es ist der Knopf, hat aber keinen Rahmen.
const NET_HOVER := Color(1.3, 1.3, 1.3)

var run: GameRun:
	set(value):
		if run == value:
			return
		if run != null and run.packs_changed.is_connected(refresh):
			run.packs_changed.disconnect(refresh)
		_abort_unseal()  # noch VOR dem Wechsel: der Inhalt gehört dem alten Lauf
		_drop_placement()  # ebenso ein Würfel, der noch einen Platz suchte
		run = value
		if run != null:
			run.packs_changed.connect(refresh)
		_pending_deliveries = 0  # Lieferungen des alten Laufs verfallen
		refresh()

## Werkbank-Zustand: das Lager, die Entsiegelung eines Pakets, oder das Einsetzen
## seiner Würfel. Die Gravur-Station ist KEINE Phase - sie liegt als eigenes Panel
## darüber (siehe attach_station) und blendet den Lager-Inhalt aus.
## CHOOSE_DIE liegt zwischen Entsiegeln und Einsetzen: Würfel-Pakete mit mehr
## als einem Würfel decken ALLE auf, der Spieler nimmt GENAU EINEN mit.
enum Phase { STASH, UNSEAL, CHOOSE_DIE, PLACE_DICE }

var _content: VBoxContainer
## Öffnen-Knöpfe der Lagerkarten, Reihenfolge = owned_packs.
var _pack_buttons: Array[Button] = []
## Gekaufte Pakete, deren Liefer-Licht noch unterwegs ist: so viele der NEUESTEN
## Karten bleiben im Regal verborgen. Der Komet IST das Paket - es darf nicht
## schon im Lager liegen, während sein Licht noch fährt.
var _pending_deliveries := 0

## Die Gravur-Station als angehängtes Vollflächen-Panel (setzt scene_root).
var _station: Control
## Gesperrt, sobald die Runde unterschrieben ist - dasselbe Zeitfenster wie
## fürs Gravieren; scene_root schiebt den Stand herein.
var editing_locked: bool = false
## Netz-Karte des überfahrenen Tray-Würfels (nur bei geschlossener Station).
var _hover_card: PanelContainer
var _hover_def: DieDefinition
## Hinweiskarte am unteren Rand samt der Einheit, für die sie gebaut wurde.
var _info_card: PanelContainer
var _info_title: Label
var _info_body: Label
var _info_unit := 0.0

var _phase: Phase = Phase.STASH
## Inhalt des gerade geöffneten Pakets.
var _revealed_engravings: Array[Engraving] = []
var _revealed_dice: Array[DieDefinition] = []
## Der GANZE Würfel-Inhalt des Pakets, auch das gerade Abgewählte: ohne ihn wäre
## die Wahl unumkehrbar (siehe go_back).
var _pack_dice: Array[DieDefinition] = []
## Sorte des offenen Pakets (die Zeremonie zeigt sein Siegel).
var _open_pack_type := ""
## Die laufende Entsiegelung.
var _unseal: PackUnsealView
## Der Gravur-Inhalt ist verbucht. Bis dahin liegt er NUR hier - bricht die
## Zeremonie vorzeitig ab, muss er trotzdem in die Vorräte (siehe _stash_now).
var _stashed := false
## Der gewählte Pool-Platz (-1 = keiner). Aus einem Paket kommt IMMER genau ein
## Würfel - die Mehrfach-Auswahl ist mit dem Wahlschritt entfallen.
var _selected_slot := -1
## "Einsetzen" - leuchtet erst mit der Auswahl.
var _place_button: Button
## Leere Bühnen, über denen die ECHTEN Paket-Würfel schweben (siehe
## die_stage_centers); sie zeigen selbst nichts.
var _die_stages: Array[Control] = []
## Je Paket-Würfel: steht er schon körperlich auf der Bank? Erst wenn sein
## Zeichen aus dem Siegel an seinem Platz angekommen ist - bis dahin verrät auch
## sein Netz nichts (siehe PackUnsealView.die_revealed).
var _materialized: Array[bool] = []
## Die Netzkarten unter den Bühnen, gleiche Reihenfolge (Klickziel der Wahl).
var _die_nets: Array[Button] = []
## Würfel-Raster der Pool-Auswahl (nur beim Einsetzen) samt seinem Wirt und der
## zuletzt daraus errechneten Maßeinheit.
var _pool_grid: DiceGridView
var _pool_host: Control
var _pool_unit := 0.0
## Anzeige-Reihenfolge und Spaltenzahl des ECHTEN Pool-Trays (setzt scene_root).
## Ohne sie zeigte das Raster die Pool-Reihenfolge, der Tisch darüber aber die
## gemischte Zieh-Reihenfolge - oben links wären zwei verschiedene Würfel.
var _pool_order: Array[DieDefinition] = []
var _pool_columns := POOL_COLUMNS

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # die Knöpfe fangen selbst
	clip_contents = true
	add_theme_stylebox_override("panel", TableScreen.window_style())
	refresh()

## Hängt die Gravur-Station als Vollflächen-Panel an: ab jetzt gilt die
## Eine-Ansicht-Regel - solange sie sichtbar ist, ruht der Lager-Inhalt.
func attach_station(panel: Control) -> void:
	_station = panel
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visibility_changed.connect(refresh)
	refresh()

func _station_open() -> bool:
	return _station != null and is_instance_valid(_station) and _station.visible

## Netz-Karte des überfahrenen Tray-Würfels. Sie liegt als Overlay in der oberen
## rechten Ecke der Werkbank - dort ist Platz, solange die Station zu ist, und
## die Schubladen sitzen ohnehin AUSSERHALB dieses Fensters. Die Station hat
## Vorrang: sobald sie aufgeht, ist die Karte weg (Eine-Ansicht-Regel).
func show_hover_net(def: DieDefinition) -> void:
	if def == null or _station_open():
		clear_hover_net()
		return
	# Der Treiber ruft je Frame - dieselbe stehende Karte wird nicht neu gebaut.
	if hover_net_visible() and _hover_def == def:
		return
	_hover_def = def
	clear_hover_net()
	var u := maxf(size.x, 200.0) / 100.0
	_hover_card = PanelContainer.new()
	_hover_card.name = "HoverNet"
	_hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_panel(_hover_card)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", int(u * 0.3))
	_hover_card.add_child(column)
	var title := Label.new()
	title.text = def.display_name
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CasinoStyle.style_score_label(title, int(u * HOVER_TITLE), CasinoStyle.GOLD)
	column.add_child(title)
	var stage := CenterContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(DieNetView.build(def, -1, u * HOVER_CELL))
	column.add_child(stage)
	var total := Label.new()
	total.text = "Augensumme %d" % DiceRowView.eye_total(def)
	total.mouse_filter = Control.MOUSE_FILTER_IGNORE
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CasinoStyle.style_body_label(total, int(u * HOVER_BODY), CasinoStyle.CREAM)
	column.add_child(total)
	add_child(_hover_card)
	_hover_card.reset_size()
	_hover_card.position = Vector2(size.x - _hover_card.size.x - u, u)

func clear_hover_net() -> void:
	if _hover_card != null and is_instance_valid(_hover_card):
		# Erst aushängen, dann freigeben: queue_free wirkt erst am Bildende, und
		# eine neue Karte träfe sonst kurzzeitig auf ihre eigene Vorgängerin.
		remove_child(_hover_card)
		_hover_card.queue_free()
	_hover_card = null

func hover_net_visible() -> bool:
	return _hover_card != null and is_instance_valid(_hover_card)

## Die Defs sind geteilte Instanzen: ändert sich ein Pool-Würfel, während die
## Karte steht, muss sie den neuen Stand zeigen. Erst abräumen, sonst fängt die
## Gleiche-Karte-Sperre den Neubau ab.
func refresh_hover_net() -> void:
	if hover_net_visible() and _hover_def != null:
		var def := _hover_def
		clear_hover_net()
		show_hover_net(def)

## Hinweiskarte am UNTEREN Rand der Werkbank: was gerade überfahren wird -
## Schubladen-Kachel (Titel + Wirkung) oder Netz-Zelle (nur Zeile). Sie hängt
## direkt am Panel, nicht am Inhalt, und wird vor die Gravur-Station gehoben:
## die ist ein späteres Kind und läge sonst darüber.
func show_hover_info(title: String, body: String) -> void:
	if title == "" and body == "":
		clear_hover_info()
		return
	_build_info_card()
	_info_title.text = title
	_info_title.visible = title != ""
	_info_body.text = body
	_info_body.visible = body != ""
	_info_card.visible = true
	_info_card.move_to_front()
	_info_card.reset_size()
	var u := maxf(size.x, 200.0) / 100.0 * INFO_MARGIN
	_info_card.position = Vector2(
		clampf((size.x - _info_card.size.x) * 0.5, u, maxf(u, size.x - _info_card.size.x - u)),
		maxf(u, size.y - _info_card.size.y - u))

func clear_hover_info() -> void:
	if _info_card != null and is_instance_valid(_info_card):
		_info_card.visible = false

func hover_info_visible() -> bool:
	return _info_card != null and is_instance_valid(_info_card) and _info_card.visible

## Die Karte steht STEHEND (nur Text wechselt) - neu gebaut wird sie nur, wenn
## sich die Maßeinheit des Fensters geändert hat.
func _build_info_card() -> void:
	var u := maxf(size.x, 200.0) / 100.0
	if _info_card != null and is_instance_valid(_info_card) and is_equal_approx(_info_unit, u):
		return
	if _info_card != null and is_instance_valid(_info_card):
		remove_child(_info_card)
		_info_card.queue_free()
	_info_unit = u
	_info_card = PanelContainer.new()
	_info_card.name = "HoverInfo"
	_info_card.visible = false
	_info_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_panel(_info_card)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", int(u * 0.3))
	_info_card.add_child(column)
	_info_title = Label.new()
	_info_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CasinoStyle.style_score_label(_info_title, int(u * INFO_TITLE), CasinoStyle.GOLD)
	column.add_child(_info_title)
	_info_body = Label.new()
	_info_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.custom_minimum_size = Vector2(u * INFO_WIDTH, 0)
	CasinoStyle.style_body_label(_info_body, int(u * INFO_BODY), CasinoStyle.CREAM)
	column.add_child(_info_body)
	add_child(_info_card)

## Baut das Fenster neu und meldet danach, wo die Würfel-Bühnen jetzt liegen -
## die ECHTEN Würfel darüber gehören scene_root, nicht diesem Fenster.
func refresh() -> void:
	_refresh_content()
	die_stages_changed.emit()

func _refresh_content() -> void:
	if not is_inside_tree():
		return
	_die_stages.clear()  # sie hängen im alten Inhalt und fallen mit ihm weg
	_die_nets.clear()
	var u := maxf(size.x, 200.0) / 100.0
	if _content != null and is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_content = null  # queue_free wirkt erst am Bildende - sonst hängt hier ein Zombie
	_pack_buttons.clear()
	if _station_open():
		_abort_unseal()  # die Station verdeckt die Zeremonie - sie endet hier
		return  # die Station füllt das Fenster allein
	if _phase == Phase.UNSEAL:
		return  # ebenso die Entsiegelung (sie hängt als eigenes Panel darüber)
	# Ein Würfel-Paket legt seine Plätze schon WÄHREND der Entsiegelung aus: die
	# Zeichen fliegen dorthin, wo ihre Würfel gleich stehen. Verraten wird dabei
	# nichts - die Netze bleiben verdeckt, bis ihr Würfel körperlich wird.

	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = u * 3.0
	_content.offset_right = -u * 3.0
	_content.offset_top = u * 2.2
	_content.offset_bottom = -u * 2.2
	_content.add_theme_constant_override("separation", int(u * 1.6))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	# Beim Einsetzen gehört das Fenster dem Raster - der Titel bliebe nur Zierde,
	# und die Kacheln wären Briefmarken. Die Wahl ERSETZT den Werkstatt-Titel,
	# statt sich eine zweite Zeile zu nehmen: das Fenster gehört den Würfeln.
	if _phase == Phase.CHOOSE_DIE:
		_content.add_child(_label("EINEN WÜRFEL WÄHLEN", u * 5.0, GOLD))
	elif _phase != Phase.PLACE_DICE:
		_content.add_child(_label("WERKSTATT", u * 5.0, TITLE_COLOR))

	if _phase == Phase.CHOOSE_DIE:
		_build_die_choice(u)
		return
	if _phase == Phase.PLACE_DICE:
		_build_dice_placement(u)
		return

	_build_pack_shelf(u)

## Oberes Regal: die versiegelten Pakete, je eines eine Karte.
func _build_pack_shelf(u: float) -> void:
	var packs: Array[Pack] = []
	if run != null:
		packs = run.owned_packs
	var shown := maxi(packs.size() - _pending_deliveries, 0)
	# Der Hinweis nur bei WIRKLICH leerem Lager - wartet eine Lieferung, bleibt
	# das Regal leer stehen (der Hinweis würde sofort wieder verschwinden).
	if packs.is_empty():
		var hint := _label("Kein Paket im Lager – im Laden gibt es welche.", u * 2.4, MUTED_COLOR)
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_content.add_child(hint)
		return

	var shelf := HFlowContainer.new()
	shelf.add_theme_constant_override("h_separation", int(u * 1.2))
	shelf.add_theme_constant_override("v_separation", int(u * 1.2))
	shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(shelf)
	for i in shown:
		shelf.add_child(_pack_card(packs[i], i, u))

## Lagerkarte: Siegel, Sorte, Inhaltsmenge - und der Öffnen-Knopf.
func _pack_card(pack: Pack, index: int, u: float) -> Control:
	var accent: Color = PackIconRenderer.COLORS.get(pack.type, TITLE_COLOR)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(u * 22.0, u * 20.0)
	button.tooltip_text = pack.description
	_style_button(button, accent)
	button.pressed.connect(open_pack.bind(index))
	_pack_buttons.append(button)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(u * 0.5))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)

	var seal := PackIconRenderer.for_type(pack.type)
	seal.custom_minimum_size = Vector2.ONE * u * 5.6
	var seal_stage := CenterContainer.new()
	seal_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_stage.add_child(seal)
	column.add_child(seal_stage)
	var name_label := _label(pack.display_name, u * 2.4, TEXT_COLOR)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	var count_label := _label(_content_text(pack), u * 2.0, MUTED_COLOR)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(count_label)
	var open_label := _label("Öffnen", u * 2.2, GOLD)
	open_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(open_label)
	return button

func _content_text(pack: Pack) -> String:
	if pack.is_dice_pack():
		return "%d Würfel" % pack.count
	if pack.type == Pack.TYPE_MIXED:
		return "%d Gravuren, alle Sorten" % pack.count
	if pack.type == Pack.TYPE_DICE_MOD:
		return "%d Würfel-Gravuren" % pack.count
	return "%d %s" % [pack.count, Engraving.CATEGORY_NAMES[pack.engraving_category()]]

## Ein gekauftes Paket ist unterwegs: seine Karte bleibt verborgen, bis das Licht
## ankommt (scene_root ruft das VOR dem Kometen).
func expect_delivery() -> void:
	_pending_deliveries += 1
	refresh()

## Das Liefer-Licht ist angekommen: die Karte erscheint und ploppt auf.
func deliver_pack() -> void:
	if _pending_deliveries <= 0:
		return
	_pending_deliveries -= 1
	refresh()
	if not _pack_buttons.is_empty():
		_pop_card(_pack_buttons[_pack_buttons.size() - 1])

## Ankunfts-Pluster der frisch gelieferten Karte (wie SupplyDrawerView.pop).
func _pop_card(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2.ONE * 1.18, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Zeremonie: öffnen, zeigen, verwenden --------------------------------------

## Öffnet das Paket auf Platz index. Der Inhalt entsteht ERST JETZT (GameRun),
## bleibt aber unverbucht, bis die Entsiegelung ihn zündet.
func open_pack(index: int) -> void:
	if run == null or index < 0 or index >= run.owned_packs.size():
		return
	var pack := run.owned_packs[index]
	_open_pack_type = pack.type
	# Phase VOR dem Öffnen setzen: packs_changed baut sofort neu auf.
	_phase = Phase.UNSEAL
	_stashed = false
	_selected_slot = -1
	var result := run.open_pack(index)
	_revealed_engravings.assign(result["engravings"])
	_revealed_dice.assign(result["dice"])
	_pack_dice.assign(result["dice"])
	# Die Würfel-Plätze stehen ab jetzt - die Zeichen brauchen ihr Ziel. Körperlich
	# ist noch keiner: das entscheidet die Zeremonie, Zeichen für Zeichen.
	_materialized.clear()
	_materialized.resize(_revealed_dice.size())
	_materialized.fill(false)
	if not _revealed_dice.is_empty():
		_phase = Phase.CHOOSE_DIE if _revealed_dice.size() > 1 else Phase.PLACE_DICE
	pack_activated.emit(index)
	refresh()
	_begin_unseal()

## Baut die Entsiegelung als Vollflächen-Panel über dem Lager auf.
func _begin_unseal() -> void:
	var u := maxf(size.x, 200.0) / 100.0
	_unseal = PackUnsealView.new()
	_unseal.name = "Unseal"
	add_child(_unseal)
	_unseal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_unseal.chip_resolved.connect(_on_chip_resolved)
	_unseal.die_revealed.connect(_on_die_revealed)
	_unseal.finished.connect(_on_unseal_finished)
	# Die Zeichen fragen selbst nach den Plätzen: beim Aufbau ist das Fenster
	# noch nicht ausgelegt, seine Bühnen haben also noch kein Rechteck.
	_unseal.die_target_source = die_stage_centers
	_unseal.setup(_open_pack_type, _revealed_engravings, _revealed_dice, u)

## Ein Stück fliegt heraus: beim ERSTEN wandert der ganze Gravur-Inhalt in die
## Vorräte (die Schubladen dürfen ihn ab jetzt zeigen), und das Stück fliegt los.
func _on_chip_resolved(engraving_id: String, from_px: Vector2, rarity: int) -> void:
	_stash_now()
	if engraving_id != "":
		engraving_dispatched.emit(engraving_id, position + from_px, rarity)

## Ein Würfel-Zeichen ist an seinem Platz zum Würfel geworden: sein Netz kommt
## dazu, und die Meldung holt den ECHTEN Würfel auf die Bank (scene_root).
func _on_die_revealed(index: int) -> void:
	if index < 0 or index >= _materialized.size() or _materialized[index]:
		return
	_materialized[index] = true
	var net := _net_face(index)
	if net != null:
		net.visible = true
		_die_nets[index].disabled = _phase != Phase.CHOOSE_DIE
		_pop_card(net)
	die_stages_changed.emit()

## Zeremonie durch: Gravuren sind verbucht und unterwegs, die Würfel stehen
## bereits auf ihren Plätzen (siehe _on_die_revealed) - hier fällt nur noch das
## Siegel-Panel weg.
func _on_unseal_finished() -> void:
	if _revealed_dice.is_empty():
		finish_ceremony()
		return
	_clear_unseal()
	refresh()

## Verbucht den Gravur-Inhalt genau einmal.
func _stash_now() -> void:
	if _stashed:
		return
	_stashed = true
	if run != null:
		run.stash_engravings(_revealed_engravings)

## Vorzeitiges Ende der Zeremonie (Station, Laufwechsel): buchen, abräumen,
## zurück ins Lager - OHNE refresh, weil die Aufrufer selbst gerade neu bauen.
func _abort_unseal() -> void:
	if _phase != Phase.UNSEAL and _phase != Phase.CHOOSE_DIE:
		return
	_stash_now()
	_clear_unseal()
	_phase = Phase.STASH
	_open_pack_type = ""
	_revealed_engravings.clear()
	_revealed_dice.clear()
	_pack_dice.clear()
	_materialized.clear()

## Ein Würfel, der noch einen Platz sucht, gehört dem LAUFENDEN Spiel: beim
## Laufwechsel verfällt er. (Die Gravur-Station unterbricht das Einsetzen dagegen
## nur - danach steht der Würfel wieder da.)
func _drop_placement() -> void:
	if _phase != Phase.PLACE_DICE:
		return
	_phase = Phase.STASH
	_revealed_dice.clear()
	_pack_dice.clear()
	_materialized.clear()
	_selected_slot = -1

func _clear_unseal() -> void:
	if _unseal != null and is_instance_valid(_unseal):
		remove_child(_unseal)
		_unseal.queue_free()
	_unseal = null

## Zurück ans Lager - der Inhalt ist verbucht bzw. abgelehnt.
func finish_ceremony() -> void:
	# Bricht die Zeremonie vorzeitig ab (Station, Laufwechsel), darf der Inhalt
	# nicht mit ihr verfallen.
	_stash_now()
	_clear_unseal()
	_phase = Phase.STASH
	_open_pack_type = ""
	_revealed_engravings.clear()
	_revealed_dice.clear()
	_pack_dice.clear()
	_materialized.clear()
	_selected_slot = -1
	refresh()

## Übernimmt Reihenfolge und Form des echten Pool-Trays (setzt scene_root beim
## Öffnen eines Pakets); leere Tray-Plätze kommen als null.
func set_pool_order(defs: Array[DieDefinition], columns: int) -> void:
	_pool_order = defs
	_pool_columns = maxi(columns, 1)
	_selected_slot = -1
	if _phase == Phase.PLACE_DICE:
		refresh()

## Die Würfel in Anzeige-Reihenfolge; ohne gesetztes Tray die reine Pool-Folge.
func _pool_defs() -> Array[DieDefinition]:
	if not _pool_order.is_empty():
		return _pool_order
	var pool: Array[DieDefinition] = []
	if run != null:
		pool = run.owned_pool
	return pool

## Kachel -> Pool-Platz. -1 für leere Kacheln und für Runden-Leihgaben
## (Glücksknoten), die gar nicht im Pool stehen.
func _pool_index_of(grid_index: int) -> int:
	var defs := _pool_defs()
	if run == null or grid_index < 0 or grid_index >= defs.size() or defs[grid_index] == null:
		return -1
	return run.owned_pool.find(defs[grid_index])

## Zwei Kacheln getauscht: die PLÄTZE im Vorrat wechseln, die Würfel selbst
## bleiben, was sie sind. Gesperrt, sobald die Runde unterschrieben ist - es ist
## dasselbe Zeitfenster wie fürs Gravieren.
func _on_pool_slots_reordered(from_grid: int, to_grid: int) -> void:
	if run == null or editing_locked:
		return
	var from_pool := _pool_index_of(from_grid)
	var to_pool := _pool_index_of(to_grid)
	if from_pool < 0 or to_pool < 0:
		return
	clear_hover_net()  # die Karte soll dem Ziehen nicht in die Quere kommen
	run.reorder_pool(from_pool, to_pool)

## Klick auf eine Kachel: wählt sie aus, ein zweiter Klick wieder ab. Es geht um
## GENAU EINEN Platz - der Wahlschritt lässt nur einen Würfel übrig.
func toggle_slot(grid_index: int) -> void:
	if _phase != Phase.PLACE_DICE:
		return
	if _selected_slot == grid_index:
		_selected_slot = -1
	elif _pool_index_of(grid_index) >= 0:
		_selected_slot = grid_index
	else:
		return  # leerer Platz oder Leihwürfel - nichts zu ersetzen
	_sync_selection()

## Setzt den Paket-Würfel auf den gewählten Platz.
func confirm_placement() -> void:
	if run == null or _selected_slot < 0 or _revealed_dice.is_empty():
		return
	var pool_index := _pool_index_of(_selected_slot)
	if pool_index < 0:
		return
	run.place_pack_die(_revealed_dice[0], pool_index)
	die_placed.emit(pool_index)
	finish_ceremony()

## Verwirft den ganzen Würfel-Inhalt ersatzlos.
func discard_dice() -> void:
	finish_ceremony()

## Spiegelt die Auswahl in Raster und Knopf - ohne Neuaufbau.
func _sync_selection() -> void:
	if _pool_grid != null and is_instance_valid(_pool_grid):
		_pool_grid.set_highlights(_highlighted_slots())
	if _place_button != null and is_instance_valid(_place_button):
		_place_button.disabled = _selected_slot < 0
		_style_button(_place_button, GOLD if _selected_slot >= 0 else MUTED_COLOR)

## Der gewählte Platz als Liste - das Raster nimmt nur getypte Arrays.
func _highlighted_slots() -> Array[int]:
	var chosen: Array[int] = []
	if _selected_slot >= 0:
		chosen.append(_selected_slot)
	return chosen

# --- Zeremonie-Ansichten -------------------------------------------------------

## Auswahl-Schritt der Mehrfach-Pakete: die Würfel LIEGEN auf der Bank - je einer
## über einer leeren Bühne, im Stasis-Feld wie ein Tray-Würfel. Das Fenster sagt
## nur, worum es geht; alles über einen Würfel zeigt seine Netz-Karte beim
## Überfahren, und wer ihn wirklich mustern will, holt ihn heran (scene_root).
func _build_die_choice(u: float) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(u * STAGE_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(row)
	for i in _revealed_dice.size():
		row.add_child(_die_column(i, u, true))

## Eine Würfel-Spalte: oben die leere Bühne, über der der ECHTE Würfel schwebt,
## darunter sein Netz. Das NETZ ist der Knopf - der Würfel selbst wird nur
## angesehen (Klick auf ihn holt ihn heran, siehe scene_root).
func _die_column(index: int, u: float, choosable: bool) -> Control:
	var column := VBoxContainer.new()
	column.name = "DieColumn"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(u * 0.6))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stage := Control.new()
	stage.name = "DieStage"
	# Die Bühne ist so breit wie das Netz - Würfel und Netz sind EINE Spalte.
	stage.custom_minimum_size = Vector2(
		DieNetView.net_size(u * CHOICE_CELL).x, u * STAGE_HEIGHT)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_die_stages.append(stage)
	column.add_child(stage)
	column.add_child(_die_net(index, u, choosable))
	return column

## Das Netz eines Paket-Würfels. Sein Platz steht von Anfang an - nur das Netz
## selbst bleibt verdeckt, bis sein Würfel körperlich wird: sonst stünde der
## Inhalt schon da, während das Siegel noch zittert, UND die Bühne darüber
## verrutschte in dem Moment, in dem sein Zeichen darauf zufliegt.
## Beim Wählen ist das Netz das Klickziel; beim Einsetzen nur noch Auskunft.
func _die_net(index: int, u: float, choosable: bool) -> Button:
	var button := Button.new()
	button.name = "DieNet"
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var net := DieNetView.build(_revealed_dice[index], -1, u * CHOICE_CELL)
	button.custom_minimum_size = net.custom_minimum_size
	net.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	net.visible = die_materialized(index)
	button.add_child(net)
	button.disabled = not choosable or not die_materialized(index)
	if choosable:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(choose_die.bind(index))
		# Kein Rahmen zum Hervorheben - also hebt sich der Inhalt selbst.
		button.mouse_entered.connect(func() -> void: net.modulate = NET_HOVER)
		button.mouse_exited.connect(func() -> void: net.modulate = Color.WHITE)
	_die_nets.append(button)
	return button

## Erklärzeile zur Netz-Zelle unter einem Display-Pixel ("" = keine). GEFRAGT
## statt gemeldet: Godot reicht die erste Bewegung über einem Knopf nicht als
## gui_input durch, und wer genau dort stehen bleibt, bekäme nie einen Text.
## scene_root fragt darum je Bild - dieselbe Lösung wie am Netzfeld der Grube.
func net_hint_at(pixel: Vector2) -> String:
	var u := maxf(size.x, 200.0) / 100.0
	for i in _die_nets.size():
		var button := _die_nets[i]
		if not is_instance_valid(button) or not die_materialized(i) or i >= _revealed_dice.size():
			continue
		var rect := button.get_global_rect()
		if not rect.has_point(pixel):
			continue
		return DieNetView.hint_for(_revealed_dice[i],
			DieNetView.face_at(pixel - rect.position, u * CHOICE_CELL))
	return ""

## Das Netz unter einem gerade körperlich gewordenen Würfel (null = keins).
func _net_face(index: int) -> Control:
	if index < 0 or index >= _die_nets.size() or not is_instance_valid(_die_nets[index]):
		return null
	return _die_nets[index].get_child(0) as Control

## Mitten der Würfel-Bühnen in Display-Pixeln - dort landen die echten Würfel.
func die_stage_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for stage in _die_stages:
		if is_instance_valid(stage):
			centers.append(stage.get_global_rect().get_center())
	return centers

## Der aufgedeckte Paket-Inhalt (scene_root baut daraus die schwebenden Würfel).
func revealed_dice() -> Array[DieDefinition]:
	return _revealed_dice

## Steht dieser Paket-Würfel schon körperlich auf der Bank? Vor dem Bruch keiner:
## erst wenn sein Zeichen an seinem Platz angekommen ist, wird er zum Ding.
func die_materialized(index: int) -> bool:
	return index >= 0 and index < _materialized.size() and _materialized[index]

## Der gewählte Würfel bleibt, der Rest fällt weg - danach der normale Platz-Schritt.
func choose_die(index: int) -> void:
	if _phase != Phase.CHOOSE_DIE or index < 0 or index >= _revealed_dice.size():
		return
	if index >= _materialized.size() or not _materialized[index]:
		return  # er steht noch gar nicht auf der Bank
	var kept := _revealed_dice[index]
	_revealed_dice.clear()
	_revealed_dice.append(kept)
	_materialized.clear()
	_materialized.append(true)  # der gewählte steht schon - er wandert nur
	_selected_slot = -1
	_phase = Phase.PLACE_DICE
	refresh()

## Einen Schritt zurück im Ablauf (Rechtsklick, siehe scene_root): vom Einsetzen
## zurück zur Wahl. Die Abgewählten sind nicht verfallen, sie standen nur nicht
## mehr auf der Bank - sie kommen zurück, und der Gewählte wandert zu ihnen.
## false = hier gibt es nichts zurückzugehen (Ein-Würfel-Paket, Lager, Zeremonie).
func go_back() -> bool:
	if _phase != Phase.PLACE_DICE or _pack_dice.size() < 2:
		return false
	_revealed_dice.assign(_pack_dice)
	_materialized.clear()
	_materialized.resize(_revealed_dice.size())
	_materialized.fill(true)  # sie standen alle schon einmal da
	_selected_slot = -1
	_phase = Phase.CHOOSE_DIE
	refresh()
	return true

func _build_dice_placement(u: float) -> void:
	if _revealed_dice.is_empty():
		return
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", int(u * 2.0))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(body)

	body.add_child(_placement_side(u))
	body.add_child(_placement_grid(u))
	_sync_selection()

## Linke Spalte: die Bühne des schwebenden Würfels, darunter Einsetzen und
## Verwerfen. Auch hier ist der ECHTE Würfel die Anzeige - keine Miniatur.
func _placement_side(u: float) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", int(u * 1.0))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	column.add_child(_die_column(0, u, false))

	_place_button = _action_button("Einsetzen", GOLD, u, confirm_placement)
	_place_button.custom_minimum_size = Vector2(u * 20.0, u * 5.0)
	column.add_child(_place_button)
	var discard := _action_button("Verwerfen", MUTED_COLOR, u, discard_dice)
	discard.custom_minimum_size = Vector2(u * 20.0, u * 4.4)
	column.add_child(discard)
	return column

func _placement_grid(u: float) -> Control:
	# Nackter Wirt, KEIN Container: ein Container meldete das Mindestmaß des
	# Rasters zurück, aus dem es seine Größe zieht - das Fenster wüchse mit.
	_pool_host = Control.new()
	_pool_host.name = "PoolHost"
	_pool_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pool_host.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_pool_unit = 0.0
	_pool_grid = DiceGridView.new()
	_pool_grid.name = "PoolGrid"
	# Nur die Werkbank legt um - die Tausch-Auswahl des Ladens bleibt ein
	# reines Ziel (dasselbe Raster, andere Rolle).
	_pool_grid.reorder_enabled = true
	_pool_grid.slot_pressed.connect(toggle_slot)
	_pool_grid.slots_reordered.connect(_on_pool_slots_reordered)
	_pool_host.add_child(_pool_grid)
	_pool_host.resized.connect(_fit_pool_grid)
	_fit_pool_grid()
	return _pool_host

## Größtes Kachelmaß, das die 30 Plätze in den Wirt bringt; danach mittig gesetzt
## (der nackte Wirt legt nichts aus).
func _fit_pool_grid() -> void:
	if _pool_grid == null or not is_instance_valid(_pool_grid) \
			or _pool_host == null or not is_instance_valid(_pool_host):
		return
	var pool := _pool_defs()
	var rows := maxi(int(ceil(float(pool.size()) / float(_pool_columns))), 1)
	var margin := maxf(size.x, 200.0) / 100.0 * 1.2
	var unit := margin  # Rückfall, solange der Wirt noch kein Maß hat
	if _pool_host.size.x > 0.0:
		unit = DiceGridView.unit_for(_pool_columns, rows, _pool_host.size - Vector2.ONE * margin * 2.0)
	if is_equal_approx(unit, _pool_unit) and _pool_grid.get_child_count() > 0:
		return  # resized feuert während des Layouts mehrfach
	_pool_unit = unit
	_pool_grid.place(_pool_columns, unit, true)
	_pool_grid.fill(pool)
	_pool_grid.set_highlights(_highlighted_slots())  # der Neuaufbau darf sie nicht schlucken
	_center_pool_grid.call_deferred()

func _center_pool_grid() -> void:
	if _pool_grid == null or not is_instance_valid(_pool_grid) \
			or _pool_host == null or not is_instance_valid(_pool_host):
		return
	var span := _pool_grid.get_combined_minimum_size()
	_pool_grid.size = span
	_pool_grid.position = ((_pool_host.size - span) * 0.5).max(Vector2.ZERO)

func _action_button(text: String, accent: Color, u: float, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(u * 22.0, u * 6.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", maxi(8, int(u * 2.6)))
	_style_button(button, accent)
	button.pressed.connect(handler)
	return button

# --- Bausteine -----------------------------------------------------------------

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color",
		Color(MUTED_COLOR.r, MUTED_COLOR.g, MUTED_COLOR.b, 0.45))
	button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#2c2757dd"), GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#3a2f66"), GOLD))
	button.add_theme_stylebox_override("focus", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("disabled",
		_button_box(Color("#1a183666"), Color(accent.r, accent.g, accent.b, 0.25)))

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var u := maxf(size.x, 200.0) / 100.0
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.2)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.6))
	return box
