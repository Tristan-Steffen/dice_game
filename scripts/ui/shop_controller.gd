class_name ShopController
extends Control
## Der Shop zwischen den Runden - ein Neon-Panel auf der Hub-Fläche des
## Tisch-Displays, bedient über die Maus-Weiterleitung. Links das Lager mit den
## versiegelten Paketen (Würfel/Zahlen/Materialien/Kanten) - geöffnet werden sie
## erst in der Werkstatt -, rechts Charms und Übertaktungen. "Umblättern"
## auf eine NEUE Seite würfelt frische Angebote aus und kostet eine steigende
## Gebühr; bereits gesehene Seiten bleiben stehen (MenuSpread) und sind gratis
## erreichbar. Zustands-Mutation läuft ausschließlich über GameRun-Methoden; auf
## closed reagiert scene_root. Alle Maße: Einheit u = Breite/100 (wie HubView).

signal closed
## Paket gekauft: scene_root schickt es als Licht die Hub-Werkstatt-Ader entlang
## (Startpunkt = Kaufknopf-Mitte in Display-Pixeln).
signal pack_purchased(from_px: Vector2, pack_type: String)

const CHARM_PRICE := 15

## Der Laden ist ELASTISCH: Anzahl der Plätze je Rubrik liefert GameRun (SHOP_*_SLOTS),
## die Kartengröße skaliert gegenläufig - wenige, große Angebote am Anfang, viele
## kleine später. Drei Rubriken/Segmente: Lager (Pakete) links, Charm-Regal +
## Chip-Schale (Übertaktungen) rechts.

## Gebühr fürs Aufschlagen einer NEUEN Doppelseite: $2, dann $3, $4 ...
## Je Besuch zurückgesetzt.
const FLIP_FEE_BASE := 2

## Farben im Display-Stil (80s Neon).
const NEON_CYAN := Color("#8be9fd")
const NEON_MAGENTA := Color("#ff79c6")
const NEON_GOLD := Color("#ffd319")
const NEON_GREEN := Color("#50fa7b")
const NEON_TEXT := Color(1.35, 1.35, 1.3)
const NEON_MUTED := Color(0.75, 0.78, 0.9)
const CARD_BG := Color("#241f4a99")

const FLIP_DURATION := 0.25

## Eine aufgeschlagene Doppelseite: bleibt für den ganzen Besuch bestehen -
## Zurückblättern zeigt exakt diese Seite wieder.
class MenuSpread:
	extends RefCounted

	## Versiegelte Pakete: Würfel-Pakete (Vitrine) und Gravur-Pakete (Regal).
	var dice_packs: Array[Pack] = []
	var dice_pack_bought: Array[bool] = []
	var engraving_packs: Array[Pack] = []
	var engraving_pack_bought: Array[bool] = []
	var charm_options: Array[Charm] = []
	var charm_bought: Array[bool] = []
	var overclock_offers: Array[String] = []  # Kombinations-Keys zum Übertakten
	var overclock_bought: Array[bool] = []

## Der laufende Spiellauf (setzt scene_root). Der Shop hört auf money_changed,
## damit sich die Kaufbarkeit auch bei Geldzugängen von außen aktualisiert.
var run: GameRun:
	set(value):
		if run != null and run.money_changed.is_connected(_on_run_money_changed):
			run.money_changed.disconnect(_on_run_money_changed)
		run = value
		if run != null:
			run.money_changed.connect(_on_run_money_changed)

## Breiteneinheit (size.x / 100), in _build_layout gesetzt.
var u := 8.0

## Gerüst-Referenzen (je open() frisch gebaut).
var money_label: Label
var content_root: VBoxContainer  # trägt Charm-Bereich + Angebots-Bereich
var page_label: Label
var done_button: Button
var page_back_button: Button
var page_next_button: Button
## Blättern-Hinweis (Hub-Stufe 1) + Hub-Aufstieg-Knopf im Shop-Fuß.
var flip_hint_label: Label
var hub_upgrade_button: Button

## Hover-Dropdown (Charm-/Engraving-Beschreibung), wie die Gravur-Station.
var shop_tooltip: PanelContainer
var shop_tooltip_title: Label
var shop_tooltip_body: Label

var spreads: Array[MenuSpread] = []
var current_spread_index: int = 0

# Spiegel der AKTUELLEN Doppelseite - Kauf-Handler und Tests arbeiten dagegen.
var dice_packs: Array[Pack] = []
var dice_pack_bought: Array[bool] = []
var dice_pack_buttons: Array[Button] = []
var charm_options: Array[Charm] = []
var charm_buttons: Array[Button] = []
var charm_bought: Array[bool] = []
var engraving_packs: Array[Pack] = []
var engraving_pack_bought: Array[bool] = []
var engraving_pack_buttons: Array[Button] = []
var overclock_offers: Array[String] = []
var overclock_bought: Array[bool] = []
var overclock_buttons: Array[Button] = []

var flip_tween: Tween

## Nach einem Hub-Aufstieg mitten im Shop: ab diesem Index je Rubrik flackern die
## NEUEN Karten wie eine zündende Neonröhre auf (-1 = kein Flackern).
var _flicker_charm_from: int = -1
var _flicker_dice_from: int = -1
var _flicker_chip_from: int = -1

## Einmalige Meldung, die beim nächsten Öffnen oben erscheint (Nebenwetten-
## Ergebnis der geräumten Runde); von scene_root vor open() gesetzt.
var pending_bet_notice: String = ""

## Öffnet den Shop frisch auf der ersten Doppelseite (Gebühr startet neu);
## baut das Gerüst passend zur aktuellen Größe.
func open() -> void:
	_build_layout()
	spreads = [_build_spread()]
	current_spread_index = 0
	_show_spread()
	visible = true

# --- Gerüst (Neon-Panel) -----------------------------------------------------

## Kopfzeile (Titel + Geld), Inhalts-Bereich (Charms oben, Angebote unten),
## Fußbereich (Blättern + Fertig). Der Neon-Rahmen kommt vom Hub darunter.
func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	u = maxf(size.x, 640.0) / 100.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inhalt darf nie über den Hub-Rahmen hinausragen (die Maus-Weiterleitung
	# endet an der Hub-Fläche).
	clip_contents = true

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(u * 3.0))
	margin.add_theme_constant_override("margin_right", int(u * 3.0))
	margin.add_theme_constant_override("margin_top", int(u * 2.0))
	margin.add_theme_constant_override("margin_bottom", int(u * 2.0))
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", int(u * 1.2))
	margin.add_child(root)

	# Kopfzeile: überhelle Farben blühen im HDR-Display (use_hdr_2d).
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", int(u * 2.0))
	root.add_child(header)
	var title := _label("S H O P", u * 4.5, Color(1.5, 0.72, 1.2))
	header.add_child(title)
	var title_rail := _rail(NEON_MAGENTA)
	title_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title_rail)
	money_label = _label("$0", u * 4.0, Color(1.5, 1.24, 0.15))
	header.add_child(money_label)

	# Nebenwetten-Ergebnis der letzten Runde (einmalig, dann verbraucht).
	if pending_bet_notice != "":
		var notice := _label(pending_bet_notice, u * 2.3, NEON_GREEN)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(notice)
		pending_bet_notice = ""

	# Inhalts-Bereich: die zwei Zonen (Charms / Angebote) baut _rebuild_content je Seite.
	content_root = VBoxContainer.new()
	content_root.name = "Content"
	content_root.add_theme_constant_override("separation", int(u * 1.6))
	content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content_root)

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", int(u * 1.5))
	root.add_child(footer)
	page_back_button = _neon_button("‹", NEON_CYAN, u * 3.2, Vector2(u * 7.0, u * 5.0))
	page_back_button.pressed.connect(_on_page_back_pressed)
	footer.add_child(page_back_button)
	page_label = _label("Seite 1", u * 2.8, NEON_MUTED)
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(page_label)
	page_next_button = _neon_button("›", NEON_CYAN, u * 3.2, Vector2(u * 12.0, u * 5.0))
	page_next_button.pressed.connect(_on_page_next_pressed)
	footer.add_child(page_next_button)
	# Hinweis, solange Blättern gesperrt ist (Hub-Stufe 1).
	flip_hint_label = _label("Blättern ab Hub-Stufe 2", u * 2.4, NEON_MUTED)
	flip_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(flip_hint_label)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_spacer)
	# Hub-Aufstieg direkt im Shop (der Hub-Rahmen ist von der Shop-Seite verdeckt).
	hub_upgrade_button = _neon_button("⬆ Hub", NEON_GOLD, u * 2.8, Vector2(u * 20.0, u * 5.0))
	hub_upgrade_button.pressed.connect(_on_hub_upgrade_pressed)
	footer.add_child(hub_upgrade_button)
	done_button = _neon_button("Fertig", NEON_GOLD, u * 3.0, Vector2(u * 18.0, u * 5.0))
	done_button.pressed.connect(_on_done_pressed)
	footer.add_child(done_button)
	_refresh_hub_footer()

	_build_shop_tooltip()  # zuletzt: liegt als Overlay über allem

# --- Blättern ------------------------------------------------------------------

## Gebühr für die nächste NEUE Doppelseite; Wechselgeld-Charm UND ein hoher
## Hub-Ausbau (Penthouse) senken sie.
func _next_flip_fee() -> int:
	var base := CharmEffects.flip_fee(FLIP_FEE_BASE + spreads.size() - 1, run.charm_ids())
	return maxi(0, roundi(base * run.shop_flip_fee_factor()))

## True, wenn Vorblättern eine neue Doppelseite auswürfeln würde.
func _next_flip_is_new() -> bool:
	return current_spread_index == spreads.size() - 1

func _on_page_next_pressed() -> void:
	if not run.shop_flipping_unlocked():
		return  # Blättern erst ab Hub-Stufe 2
	if _next_flip_is_new():
		var fee := _next_flip_fee()
		if run.money < fee:
			return  # Knopf ist bei zu wenig Geld ohnehin deaktiviert
		run.add_money(-fee)
		spreads.append(_build_spread())
	current_spread_index += 1
	_show_spread()
	_play_flip_animation()

## Hub-Aufstieg im Shop gedrückt: Ausbau über GameRun buchen (No-op wenn nicht
## bezahlbar/max). Die Zeremonie + refresh_after_hub_upgrade folgen aus dem
## hub_level_changed-Signal (scene_root).
func _on_hub_upgrade_pressed() -> void:
	if run != null:
		run.upgrade_hub()

## Fuß-Zeile an die Hub-Stufe anpassen: Blättern-Knöpfe vs. Hinweis, Aufstieg-Knopf.
func _refresh_hub_footer() -> void:
	if run == null or page_back_button == null:
		return
	var can_flip := run.shop_flipping_unlocked()
	page_back_button.visible = can_flip
	page_next_button.visible = can_flip
	page_label.visible = can_flip
	flip_hint_label.visible = not can_flip
	if run.hub_level >= GameRun.HUB_MAX_LEVEL:
		hub_upgrade_button.visible = false
	else:
		hub_upgrade_button.visible = true
		hub_upgrade_button.text = "⬆ %s ($%d)" % [run.hub_next_level_name(), run.hub_upgrade_price()]
		hub_upgrade_button.disabled = not run.can_upgrade_hub()

## Nach einem Hub-Aufstieg mitten im Shop: aktuelle Doppelseite an die neue Stufe
## anpassen (mehr Plätze/Blättern werden sofort sichtbar) und Fuß-Zeile neu.
func refresh_after_hub_upgrade() -> void:
	if not visible or run == null:
		return
	# Aktuelle Seite neu auswürfeln, damit die zusätzlichen Plätze erscheinen; die
	# alten Platzzahlen merken, damit nur die NEUEN Karten aufflackern.
	if not spreads.is_empty():
		var old := spreads[current_spread_index]
		_flicker_charm_from = old.charm_options.size()
		_flicker_dice_from = old.dice_packs.size()
		_flicker_chip_from = old.engraving_packs.size()
		spreads[current_spread_index] = _build_spread()
	_refresh_hub_footer()
	_show_spread()

## Zurückblättern ist immer gratis.
func _on_page_back_pressed() -> void:
	if current_spread_index == 0:
		return
	current_spread_index -= 1
	_show_spread()
	_play_flip_animation()

## Rein kosmetische Einblendung - der Spielzustand ist schon gewechselt, die
## Animation gate nichts (schnelles Klicken ersetzt sie einfach).
func _play_flip_animation() -> void:
	if flip_tween != null and flip_tween.is_valid():
		flip_tween.kill()
	content_root.modulate = Color(1, 1, 1, 0)
	flip_tween = create_tween()
	flip_tween.tween_property(content_root, "modulate:a", 1.0, FLIP_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# --- Doppelseiten bauen --------------------------------------------------------

## Frische Doppelseite: Charms oben, unten versiegelte Würfel- und Gravur-Pakete
## plus die Übertaktungs-Chips.
func _build_spread() -> MenuSpread:
	var spread := MenuSpread.new()
	spread.dice_packs = _roll_dice_packs(run.shop_dice_slots())
	spread.dice_pack_bought.resize(spread.dice_packs.size())
	spread.dice_pack_bought.fill(false)

	# Besitz-Prüfung über die ROHEN ids (Totems lösen sich in charm_ids() zu
	# ihren Nachbarn auf und würden sonst doppelt angeboten).
	var owned_ids: Array[String] = run.owned_charm_ids()
	var available: Array[Charm] = []
	for charm in Charm.all():
		if not owned_ids.has(charm.id):
			available.append(charm)
	var charm_slots := run.shop_charm_slots()
	var rarity_tier := run.shop_rarity_tier()
	# Raritäts-Schub: der erste Platz zieht garantiert einen Charm ab der zur Stufe
	# passenden Mindest-Rarität (Tier 1 ungewöhnlich, 2 selten, 3 legendär) - fällt
	# auf die nächst-niedrigere Schwelle zurück, falls keiner verfügbar ist.
	if rarity_tier >= 1 and charm_slots > 0:
		var premium := _charms_at_least(available, rarity_tier)
		if not premium.is_empty():
			var top := Charm.pick_weighted(premium)
			spread.charm_options.append(top)
			available.erase(top)
	# Restliche Plätze gewichtet nach Rarität ziehen, ohne Zurücklegen.
	while spread.charm_options.size() < charm_slots and not available.is_empty():
		var pick := Charm.pick_weighted(available)
		spread.charm_options.append(pick)
		available.erase(pick)
	spread.charm_bought.resize(spread.charm_options.size())
	spread.charm_bought.fill(false)

	# Gravur-Pakete: die Sorte entscheidet die Häufigkeit (viele Zahlen, wenige
	# Kanten), die Mindest-Seltenheit im Inhalt zieht GameRun beim Öffnen.
	for i in run.shop_pack_slots():
		spread.engraving_packs.append(Pack.roll_engraving_pack(run.hub_level))
	spread.engraving_pack_bought.resize(spread.engraving_packs.size())
	spread.engraving_pack_bought.fill(false)

	# Übertaktungen: verschiedene Kombinationen, je Angebot einmal kaufbar.
	var keys := DiceScoring.HAND_PRIORITY.duplicate()
	keys.shuffle()
	for i in run.shop_overclock_slots():
		spread.overclock_offers.append(keys[i])
	spread.overclock_bought.resize(spread.overclock_offers.size())
	spread.overclock_bought.fill(false)
	return spread

## Würfel-Pakete der Auslage: je Platz eine andere Vorlage (Mengenrabatt sorgt
## für ein 3er-Bündel), Inhalt bleibt bis zum Öffnen verborgen.
func _roll_dice_packs(count: int) -> Array[Pack]:
	var packs: Array[Pack] = []
	for template in DiceOffer.pick_templates(count, run.charm_ids()):
		packs.append(Pack.dice_pack(template))
	return packs

## Charms mit mindestens der zur Raritäts-Stufe passenden Seltenheit; fällt bei
## leerem Ergebnis schrittweise auf die nächst-niedrigere Schwelle zurück (nie
## unter "ungewöhnlich").
func _charms_at_least(pool: Array[Charm], tier: int) -> Array[Charm]:
	var min_rank := clampi(tier, 1, 3)
	while min_rank >= 1:
		var out: Array[Charm] = []
		for charm in pool:
			if _charm_rank(charm) >= min_rank:
				out.append(charm)
		if not out.is_empty():
			return out
		min_rank -= 1
	return []

func _charm_rank(charm: Charm) -> int:
	match charm.rarity:
		Charm.RARITY_LEGENDARY: return 3
		Charm.RARITY_RARE: return 2
		Charm.RARITY_UNCOMMON: return 1
		_: return 0

## Zeigt die aktuelle Doppelseite: Spiegel-Variablen umhängen, Spalten neu
## bebauen, Navigation und Kaufbarkeit aktualisieren.
func _show_spread() -> void:
	var spread := spreads[current_spread_index]
	dice_packs = spread.dice_packs
	dice_pack_bought = spread.dice_pack_bought
	charm_options = spread.charm_options
	charm_bought = spread.charm_bought
	engraving_packs = spread.engraving_packs
	engraving_pack_bought = spread.engraving_pack_bought
	overclock_offers = spread.overclock_offers
	overclock_bought = spread.overclock_bought

	_rebuild_content(spread)
	page_label.text = "Seite %d" % (current_spread_index + 1)
	_refresh_afford_state()

## Gibt den Inhalt frei - auch beim Schließen wichtig, damit die
## 3D-Vorschau-Viewports nicht im Hintergrund weiterrendern.
func _clear_pages() -> void:
	if content_root != null:
		for child in content_root.get_children():
			child.queue_free()
	dice_pack_buttons.clear()
	charm_buttons.clear()
	engraving_pack_buttons.clear()
	overclock_buttons.clear()

## Baut die drei Segmente: links das Lager (flache Paket-Reihen), rechts das
## Charm-Regal über der Chip-Schale (Übertaktungen). Alle Rubriken FÜLLEN ihre
## Fläche - bei wenigen Plätzen werden Reihen und Karten groß.
func _rebuild_content(spread: MenuSpread) -> void:
	for child in content_root.get_children():
		child.queue_free()
	dice_pack_buttons.clear()
	charm_buttons.clear()
	engraving_pack_buttons.clear()
	overclock_buttons.clear()

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", int(u * 1.6))
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(main_row)

	# Segment 1: Lager - alle versiegelten Pakete (Würfel oben, Gravuren darunter)
	# als flache Regal-Reihen links. Geöffnet werden sie später in der Werkstatt.
	var vitrine := _make_zone(main_row, NEON_CYAN, "LAGER", "versiegelt", true, 0.40)
	var pack_col := VBoxContainer.new()
	pack_col.add_theme_constant_override("separation", int(u * 1.2))
	pack_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pack_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitrine.add_child(pack_col)
	var pm := _pack_metrics(spread.dice_packs.size() + spread.engraving_packs.size())
	for i in spread.dice_packs.size():
		var dcard := _build_pack_card(spread.dice_packs[i], i, true, pm)
		pack_col.add_child(dcard)
		_maybe_flicker(dcard, i, _flicker_dice_from)
	for i in spread.engraving_packs.size():
		var ecard := _build_pack_card(spread.engraving_packs[i], i, false, pm)
		pack_col.add_child(ecard)
		_maybe_flicker(ecard, i, _flicker_chip_from)

	# Rechte Spalte: Charm-Regal (natürliche Höhe) über der Chip-Schale (füllt Rest).
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", int(u * 1.4))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.60
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_row.add_child(right)

	# Segment 2: Charm-Regal - eine Reihe dehnbarer Karten (nur Symbol; Rest im
	# Hover). Teilt sich die Resthöhe mit der Chip-Schale, statt sie ihr zu lassen.
	var charm_zone := _make_zone(right, NEON_MAGENTA, "CHARM-REGAL", "je $%d" % _charm_price(), true)
	charm_zone.get_parent().size_flags_stretch_ratio = 0.45
	var charm_row := HBoxContainer.new()
	charm_row.add_theme_constant_override("separation", int(u * 1.4))
	charm_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	charm_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charm_zone.add_child(_v_spacer())
	charm_zone.add_child(charm_row)
	charm_zone.add_child(_v_spacer())
	var cm := _charm_metrics(spread.charm_options.size())
	var podest_index := 0 if run.shop_rarity_tier() >= 1 else -1
	for i in spread.charm_options.size():
		var podest := i == podest_index
		var ccard := _build_charm_card(spread.charm_options[i], i, cm.x, int(cm.y), podest)
		charm_row.add_child(ccard)
		_maybe_flicker(ccard, i, _flicker_charm_from)

	# Segment 3: Chip-Schale - runde Casino-Chips (Übertaktungen), als Tablett
	# umbrechend und in der Schale zentriert. Füllt die restliche Höhe rechts.
	var chip_zone := _make_zone(right, NEON_GOLD, "CHIP-SCHALE", "", true)
	chip_zone.get_parent().size_flags_stretch_ratio = 0.55
	chip_zone.add_child(_v_spacer())
	var tray := HFlowContainer.new()
	tray.add_theme_constant_override("h_separation", int(u * 1.2))
	tray.add_theme_constant_override("v_separation", int(u * 1.2))
	tray.alignment = FlowContainer.ALIGNMENT_CENTER
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_zone.add_child(tray)
	var dia := _chip_dia(spread.overclock_offers.size())
	for i in spread.overclock_offers.size():
		var ocard := _build_overclock_chip(spread.overclock_offers[i], i, dia)
		tray.add_child(ocard)
		_maybe_flicker(ocard, i, _flicker_chip_from)
	chip_zone.add_child(_v_spacer())

	# Das Flackern gilt nur für DIESEN Aufbau (direkt nach einem Aufstieg).
	_flicker_charm_from = -1
	_flicker_dice_from = -1
	_flicker_chip_from = -1

## Signaturfarbe der aktuellen Hub-Stufe (wie der Hub-Rahmen); der Laden trägt sie
## dezent auf seinen Segment-Säumen, damit er zur Hub-Stufe passt.
func _tier_color() -> Color:
	if run == null:
		return Color.WHITE
	var last := HubView.HUB_TIER_COLORS.size() - 1
	return HubView.HUB_TIER_COLORS[clampi(run.hub_level - 1, 0, last)]

## Akzentfarbe leicht zur Stufenfarbe ziehen (Zusammenhalt ohne die Rubrik-Farbe
## zu verfälschen).
func _tinted(accent: Color) -> Color:
	return accent.lerp(_tier_color(), 0.15)

## Senkrechter Dehn-Platzhalter (zentriert die Chip-Schale in ihrer Fläche).
func _v_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

## Neonröhren-Zündung einer frisch freigeschalteten Karte (ab index >= from).
func _maybe_flicker(card: Control, index: int, from: int) -> void:
	if from < 0 or index < from:
		return
	card.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_interval(0.05 * (index - from))
	tw.tween_property(card, "modulate:a", 0.9, 0.04)
	tw.tween_property(card, "modulate:a", 0.15, 0.05)
	tw.tween_property(card, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)

# --- Elastische Maße (Karten wachsen, wenn es wenige Plätze gibt) ---------------

## Charm-Karte: (Mindesthöhe, Modell-Kantenlänge) je nach Anzahl der Charms.
func _charm_metrics(count: int) -> Vector2:
	if count <= 2:
		return Vector2(u * 21.0, u * 11.0)
	if count == 3:
		return Vector2(u * 16.5, u * 9.0)
	if count == 4:
		return Vector2(u * 13.5, u * 7.5)
	return Vector2(u * 12.0, u * 5.6)

## Lager-Reihe: (Reihenhöhe, Siegelkante) je Gesamtzahl der Pakete - wenige,
## große Siegel am Anfang, kompakte Reihen im Vollausbau (bis zu 3 + 4 Pakete).
func _pack_metrics(count: int) -> Vector2:
	if count <= 2:
		return Vector2(u * 12.0, u * 7.5)
	if count <= 5:
		return Vector2(u * 9.5, u * 6.0)
	return Vector2(u * 7.4, u * 4.8)

## Chip-Durchmesser je nach Anzahl der Übertaktungs-Chips.
func _chip_dia(count: int) -> float:
	if count <= 4:
		return u * 12.0
	if count <= 7:
		return u * 9.5
	return u * 7.8

## Glas-Zone: dunkles Rauchglas-Panel mit Akzent-Saum (dezent stufengetönt) und
## weichem Außen-Glow, darin die Kopfzeile. Wird an parent gehängt; liefert die
## Inhalts-Spalte. h_stretch > 0 setzt das waagerechte Dehnverhältnis (Segment-Split).
func _make_zone(parent: Container, accent: Color, heading: String, right_hint: String,
		v_expand := false, h_stretch := 0.0) -> VBoxContainer:
	var seam := _tinted(accent)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#14112eb0")
	box.border_color = Color(seam.r, seam.g, seam.b, 0.32)
	box.set_border_width_all(maxi(1, int(u * 0.16)))
	box.set_corner_radius_all(int(u * 1.5))
	box.set_content_margin_all(int(u * 1.6))
	box.shadow_color = Color(seam.r, seam.g, seam.b, 0.14)
	box.shadow_size = int(u * 1.1)
	panel.add_theme_stylebox_override("panel", box)
	if v_expand:
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if h_stretch > 0.0:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = h_stretch
	parent.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(u * 1.2))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	column.add_child(_heading_row(heading, seam, right_hint))
	return column

## Zonen-Kopf: Akzent-Raute, gesperrter Titel, auslaufende Lichtschiene,
## optional ein rechter Hinweis (z.B. der Charm-Preis).
func _heading_row(text: String, accent: Color, right_hint: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 1.2))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label("◆", u * 2.2, accent))
	row.add_child(_label(_spaced(text), u * 2.6, Color(accent.r * 1.3, accent.g * 1.3, accent.b * 1.3)))
	var rail := _rail(accent)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rail)
	if right_hint != "":
		row.add_child(_label(right_hint, u * 2.2, NEON_GOLD))
	return row

## Gesperrte Schrift ("CHARMS" -> "C H A R M S") - Premium-Look der Zonen-Titel.
func _spaced(text: String) -> String:
	var chars := PackedStringArray()
	for i in text.length():
		chars.append(text[i])
	return " ".join(chars)

## Dünne Lichtschiene, die nach rechts ausläuft (Neon-Zierlinie).
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

## Weicher radialer Lichtfleck (liegt hinter Charm-Modellen).
func _glow_disc(tint: Color, side: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(tint.r, tint.g, tint.b, 0.38), Color(tint.r, tint.g, tint.b, 0.14), Color(tint.r, tint.g, tint.b, 0.0)])
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

## Charm-Karte: nur das Symbol + Preis; Name und Wirkung zeigt der Hover-Dropdown.
## Rahmen und Lichtfleck tragen die Charm-Rarität (weiß/grün/blau/violett). card_h
## und thumb_px kommen elastisch aus _charm_metrics; podest = garantierter
## Premium-Charm (Rarität freigeschaltet): größer, stärkerer Lichtfleck, dickerer Saum.
func _build_charm_card(charm: Charm, index: int, card_h: float, thumb_px: int, podest := false) -> Control:
	var owned := charm_bought[index] or run.owned_charm_ids().has(charm.id)
	var tint := charm.rarity_color()
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.custom_minimum_size = Vector2(0, card_h * (1.12 if podest else 1.0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if podest:
		card.size_flags_stretch_ratio = 1.4  # das Podest bekommt mehr Breite
	var seam_alpha := 0.9 if podest else 0.65
	card.add_theme_stylebox_override("normal", _charm_card_box(Color("#1d1840cc"), tint, seam_alpha, 0.32 if podest else 0.22))
	card.add_theme_stylebox_override("hover", _charm_card_box(Color("#2a2158dd"), NEON_GOLD, 0.9, 0.3))
	card.add_theme_stylebox_override("pressed", _charm_card_box(Color("#352a68"), NEON_GOLD, 1.0, 0.3))
	card.add_theme_stylebox_override("disabled", _charm_card_box(Color("#16133466"), tint, 0.18, 0.0))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.mouse_entered.connect(_show_shop_tooltip.bind(card, charm.display_name, charm.description))
	card.mouse_exited.connect(_hide_shop_tooltip)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(u * 0.3))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	# Lichtfleck hinter dem Modell (CenterContainer stapelt beide mittig).
	var glow := tint if not owned else Color(tint.r, tint.g, tint.b, 0.3)
	var disc_side := thumb_px * (1.5 if podest else 1.27)
	var stage := CenterContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow_disc(glow, disc_side))
	stage.add_child(CharmThumb.new(charm, thumb_px))
	column.add_child(stage)

	column.add_child(_label("gekauft" if owned else "$%d" % _charm_price(),
		u * 2.0, NEON_MUTED if owned else Color(1.4, 1.16, 0.14), HORIZONTAL_ALIGNMENT_CENTER))

	if owned:
		card.disabled = true
	else:
		card.pressed.connect(_on_charm_clicked.bind(index))
	charm_buttons.append(card)
	return card

## Kartenrahmen im Raritäts-Tint: Saum + weicher Außen-Glow (StyleBox-Schatten).
func _charm_card_box(fill: Color, border: Color, border_alpha: float, glow_alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color(border.r, border.g, border.b, border_alpha)
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(int(u * 1.2))
	box.set_content_margin_all(int(u * 0.7))
	if glow_alpha > 0.0:
		box.shadow_color = Color(border.r, border.g, border.b, glow_alpha)
		box.shadow_size = int(u * 0.9)
	return box

## Übertaktungs-Chip: goldene Scheibe mit ⚡; hebt die Stufe EINER Kombination
## (Preis steigt mit ihrer Stufe). Aktuelle/nächste Werte im Hover-Dropdown.
func _build_overclock_chip(combo_key: String, index: int, dia: float) -> Control:
	var level := run.combo_level(combo_key)
	var price := run.overclock_price(combo_key)
	var face := _label("⚡", dia * 0.42, NEON_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.custom_minimum_size = Vector2(dia * 0.56, dia * 0.56)
	var next_levels: Dictionary = run.combo_levels.duplicate()
	next_levels[combo_key] = level + 1
	var title := "Übertaktung – %s (Stufe %d → %d)" % [DiceScoring.label_for(combo_key), level, level + 1]
	var body := "Jetzt: %d Punkte × %d. Nach dem Kauf: %d Punkte × %d." % [
		DiceScoring.points_for(combo_key, run.combo_levels), DiceScoring.mult_for(combo_key, run.combo_levels),
		DiceScoring.points_for(combo_key, next_levels), DiceScoring.mult_for(combo_key, next_levels)]
	var bought := overclock_bought[index]
	var chip := _chip_button(dia, NEON_GOLD, face, price, bought, title, body)
	if bought:
		chip.disabled = true
	else:
		chip.pressed.connect(_on_overclock_buy_pressed.bind(index))
	overclock_buttons.append(chip)
	return chip

## Runder Casino-Chip als Kauf-Knopf: Rauchglas-Scheibe mit Saum in seam, darin das
## Gesicht (face) und der Preis. Gekaufte Chips zeigen ✓ und sind gedimmt.
func _chip_button(dia: float, seam: Color, face: Control, price: int, bought: bool,
		title: String, body: String) -> Button:
	var radius := int(dia * 0.5)
	var chip := Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.custom_minimum_size = Vector2(dia, dia)
	chip.add_theme_stylebox_override("normal", _chip_box(Color("#1b1738e6"), seam, 0.75, radius))
	chip.add_theme_stylebox_override("hover", _chip_box(Color("#2a2358f0"), NEON_GOLD, 0.95, radius))
	chip.add_theme_stylebox_override("pressed", _chip_box(Color("#352a68"), NEON_GOLD, 1.0, radius))
	chip.add_theme_stylebox_override("disabled", _chip_box(Color("#16133455"), seam, 0.28, radius))
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chip.mouse_entered.connect(_show_shop_tooltip.bind(chip, title, body))
	chip.mouse_exited.connect(_hide_shop_tooltip)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(column)

	if bought:
		face.modulate = Color(1, 1, 1, 0.35)
	var stage := CenterContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(face)
	column.add_child(stage)

	column.add_child(_label("✓" if bought else "$%d" % price, dia * 0.17,
		NEON_MUTED if bought else Color(1.4, 1.16, 0.14), HORIZONTAL_ALIGNMENT_CENTER))
	return chip

## Runde Chip-Scheibe (Saum + weicher Glow); radius = halber Durchmesser.
func _chip_box(bg: Color, border: Color, border_alpha: float, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = Color(border.r, border.g, border.b, border_alpha)
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(int(u * 0.5))
	box.shadow_color = Color(border.r, border.g, border.b, 0.12)
	box.shadow_size = int(u * 0.5)
	return box

## Regal-Reihe eines VERSIEGELTEN Pakets: Siegel links, Sorte und Menge daneben,
## Preis rechts - nie der Inhalt selbst. Flache Reihen statt Hochkant-Karten:
## das Lager wächst mit der Hub-Stufe auf bis zu 7 Pakete, und nur Reihen halten
## den Fuß (Fertig) im Panel. Details zeigt der Hover-Dropdown.
func _build_pack_card(pack: Pack, index: int, is_dice: bool, metrics: Vector2) -> PanelContainer:
	var accent: Color = PackIconRenderer.COLORS.get(pack.type, NEON_CYAN)
	var bought: bool = dice_pack_bought[index] if is_dice else engraving_pack_bought[index]

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, metrics.x)
	var box := StyleBoxFlat.new()
	box.bg_color = CARD_BG
	box.border_color = Color(accent.r, accent.g, accent.b, 0.24 if bought else 0.5)
	box.set_border_width_all(maxi(1, int(u * 0.16)))
	box.set_corner_radius_all(int(u * 1.2))
	box.set_content_margin_all(int(u * 0.8))
	box.shadow_color = Color(accent.r, accent.g, accent.b, 0.12)
	box.shadow_size = int(u * 0.7)
	card.add_theme_stylebox_override("panel", box)
	card.mouse_entered.connect(_show_shop_tooltip.bind(card, pack.display_name, pack.description))
	card.mouse_exited.connect(_hide_shop_tooltip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 1.0))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var seal := PackIconRenderer.for_type(pack.type)
	seal.custom_minimum_size = Vector2.ONE * metrics.y
	seal.modulate = Color(1, 1, 1, 0.4 if bought else 1.0)
	var seal_stage := CenterContainer.new()
	seal_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_stage.add_child(seal)
	row.add_child(seal_stage)

	var text_col := VBoxContainer.new()
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", int(u * 0.2))
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)
	text_col.add_child(_label(pack.display_name, u * 1.9, NEON_TEXT))
	text_col.add_child(_label(_pack_count_text(pack), u * 1.6, NEON_MUTED))

	var price := _pack_price(pack)
	var buy := _neon_button("Im Lager" if bought else "$%d" % price, accent, u * 2.0, Vector2(u * 9.0, u * 4.2))
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if bought:
		buy.disabled = true
	else:
		buy.pressed.connect(_on_pack_buy_pressed.bind(index, is_dice))
	row.add_child(buy)
	if is_dice:
		dice_pack_buttons.append(buy)
	else:
		engraving_pack_buttons.append(buy)
	return card

## Mengenzeile der Regal-Reihe: nur WIE VIEL - die Sorte sagt das Siegel,
## den Rest der Hover-Dropdown (pack.description).
func _pack_count_text(pack: Pack) -> String:
	if pack.is_dice_pack():
		return "%d Würfel" % pack.count
	return "1 Gravur" if pack.count == 1 else "%d Gravuren" % pack.count

# --- Neon-Bausteine --------------------------------------------------------------

func _label(text: String, font_size: float, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# --- Hover-Dropdown (wie die Gravur-Station) -----------------------------------

func _build_shop_tooltip() -> void:
	shop_tooltip = PanelContainer.new()
	shop_tooltip.name = "ShopTooltip"
	shop_tooltip.visible = false
	shop_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_panel(shop_tooltip)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", int(u * 0.4))
	shop_tooltip.add_child(box)
	shop_tooltip_title = Label.new()
	shop_tooltip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(shop_tooltip_title, int(u * 2.6), CasinoStyle.GOLD)
	box.add_child(shop_tooltip_title)
	shop_tooltip_body = Label.new()
	shop_tooltip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_tooltip_body.custom_minimum_size = Vector2(u * 28.0, 0)
	CasinoStyle.style_body_label(shop_tooltip_body, int(u * 1.9), CasinoStyle.CREAM)
	box.add_child(shop_tooltip_body)
	add_child(shop_tooltip)

## Zeigt den Dropdown unter (oder notfalls über) dem überfahrenen Element,
## immer im Panel eingeklemmt (clip_contents schneidet Überstände ab).
func _show_shop_tooltip(anchor: Control, title: String, body: String) -> void:
	if shop_tooltip == null:
		return
	shop_tooltip_title.text = title
	shop_tooltip_body.text = body
	shop_tooltip.visible = true
	shop_tooltip.reset_size()
	var local := anchor.get_global_rect().position - get_global_rect().position
	var below := local.y + anchor.size.y + u * 0.6
	var above := local.y - shop_tooltip.size.y - u * 0.6
	var pos := Vector2(local.x, below)
	if below + shop_tooltip.size.y > size.y - u * 1.0 and above >= u * 1.0:
		pos.y = above  # unten kein Platz -> über das Element klappen
	pos.x = clampf(pos.x, u * 1.0, maxf(u * 1.0, size.x - shop_tooltip.size.x - u * 1.0))
	pos.y = clampf(pos.y, u * 1.0, maxf(u * 1.0, size.y - shop_tooltip.size.y - u * 1.0))
	shop_tooltip.position = pos

func _hide_shop_tooltip() -> void:
	if shop_tooltip != null:
		shop_tooltip.visible = false

## Knopf im Display-Neon-Stil: dunkler Grund, Rahmen in der Rubriken-Farbe;
## Hover/Druck wechseln auf Gold, deaktiviert dimmt ab.
func _neon_button(text: String, accent: Color, font_size: float, min_size: Vector2 = Vector2.ZERO) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	button.add_theme_color_override("font_color", NEON_TEXT)
	button.add_theme_color_override("font_hover_color", NEON_GOLD)
	button.add_theme_color_override("font_pressed_color", NEON_GOLD)
	button.add_theme_color_override("font_disabled_color", Color(NEON_MUTED.r, NEON_MUTED.g, NEON_MUTED.b, 0.45))
	button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#2c2757dd"), NEON_GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#3a2f66"), NEON_GOLD))
	button.add_theme_stylebox_override("focus", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("disabled", _button_box(Color("#1a183666"), Color(accent.r, accent.g, accent.b, 0.25)))
	return button

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.8))
	return box

# --- Käufe ----------------------------------------------------------------------

## Würfel-Pakete tragen die Würfel-Rabatte (Trickser, Mengenrabatt);
## Gravur-Pakete haben ihren festen Sortenpreis.
func _pack_price(pack: Pack) -> int:
	if pack.is_dice_pack():
		return CharmEffects.die_price(pack.price, run.charm_ids(), pack.count)
	return pack.price

func _charm_price() -> int:
	return CharmEffects.charm_price(CHARM_PRICE, run.charm_ids())

## Kauft ein versiegeltes Paket (je Angebot einmal); es wandert ungeöffnet ins
## Werkstatt-Lager. Danach wird die Doppelseite neu bebaut.
func _on_pack_buy_pressed(index: int, is_dice: bool) -> void:
	var pack: Pack = dice_packs[index] if is_dice else engraving_packs[index]
	if (dice_pack_bought[index] if is_dice else engraving_pack_bought[index]):
		return
	var price := _pack_price(pack)
	if run.money < price:
		return
	# Startpunkt VOR dem Neuaufbau abgreifen - danach ist der Knopf weg.
	var buttons := dice_pack_buttons if is_dice else engraving_pack_buttons
	var from_px := Vector2.ZERO
	if index < buttons.size() and is_instance_valid(buttons[index]):
		from_px = buttons[index].get_global_rect().get_center()
	run.purchase_pack(pack, price)
	# Liegt im Spread - übersteht den Neuaufbau.
	if is_dice:
		dice_pack_bought[index] = true
	else:
		engraving_pack_bought[index] = true
	if from_px != Vector2.ZERO:
		pack_purchased.emit(from_px, pack.type)
	_show_spread()

## Kauft den Charm (je einmal). Danach wird die ganze Doppelseite neu bebaut:
## Shop-Charms (Skonto, Wechselgeld, ...) wirken schon in DIESEM Besuch -
## alle Preisschilder und Schwellen zeigen sonst alte Preise.
func _on_charm_clicked(index: int) -> void:
	var charm := charm_options[index]
	if charm_bought[index] or run.owned_charm_ids().has(charm.id):
		return
	run.purchase_charm(charm, _charm_price())
	charm_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	_show_spread()

## Kauft die Übertaktung (je Angebot einmal); die Doppelseite wird neu bebaut,
## damit Stufen-Anzeige und Preisschild sofort den neuen Stand zeigen.
func _on_overclock_buy_pressed(index: int) -> void:
	if overclock_bought[index]:
		return
	var combo_key := overclock_offers[index]
	if not run.can_overclock(combo_key):
		return
	run.overclock_combo(combo_key)
	overclock_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	_show_spread()

## Deaktiviert alles Unbezahlbare und hält den Geldstand der Kopfzeile aktuell.
func _refresh_afford_state() -> void:
	var money: int = run.money
	if money_label != null:
		money_label.text = "$%d" % money
	for i in dice_pack_buttons.size():
		dice_pack_buttons[i].disabled = dice_pack_bought[i] or money < _pack_price(dice_packs[i])
	for i in charm_buttons.size():
		if not charm_bought[i]:
			charm_buttons[i].disabled = money < _charm_price() or run.owned_charm_ids().has(charm_options[i].id)
	for i in engraving_pack_buttons.size():
		engraving_pack_buttons[i].disabled = engraving_pack_bought[i] or money < _pack_price(engraving_packs[i])
	for i in overclock_buttons.size():
		overclock_buttons[i].disabled = overclock_bought[i] or not run.can_overclock(overclock_offers[i])
	if page_back_button != null and is_instance_valid(page_back_button):
		page_back_button.disabled = current_spread_index == 0
	if page_next_button != null and is_instance_valid(page_next_button):
		if _next_flip_is_new():
			page_next_button.text = "$%d ›" % _next_flip_fee()
			page_next_button.disabled = money < _next_flip_fee()
		else:
			page_next_button.text = "›"
			page_next_button.disabled = false
	# Hub-Aufstieg-Knopf folgt dem Geldstand.
	if hub_upgrade_button != null and is_instance_valid(hub_upgrade_button) and hub_upgrade_button.visible:
		hub_upgrade_button.disabled = not run.can_upgrade_hub()

func _on_run_money_changed(_money: int) -> void:
	if visible:
		_refresh_afford_state()

func _on_done_pressed() -> void:
	_clear_pages()  # 3D-Vorschauen freigeben (kein Hintergrund-Rendern)
	visible = false
	closed.emit()
