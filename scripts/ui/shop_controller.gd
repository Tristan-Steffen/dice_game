class_name ShopController
extends Control
## Der Shop zwischen den Runden - ein Neon-Panel auf der Hub-Fläche des
## Tisch-Displays, bedient über die Maus-Weiterleitung. Bildschirm ist nur noch
## Kopf, CHARM-ZEILE und Fuß: Lizenzen sind digitale Ware. Alles Körperliche -
## versiegelte Pakete, offene Würfel, der Sonderposten - liegt in der VITRINE
## darunter, einer echten Bucht im Tisch. Die zeichnet dieser Laden nie selbst;
## er MELDET ihr Rechteck (vitrine_rect_px) und ihren Inhalt (vitrine_stock,
## vitrine_annotation) nach oben, aufgestellt wird sie von scene_root.
## "Umblättern" auf eine NEUE Seite würfelt frische Angebote aus und kostet eine
## steigende Gebühr; bereits gesehene Seiten bleiben stehen (MenuSpread) und sind
## gratis erreichbar. Zustands-Mutation läuft ausschließlich über GameRun-Methoden;
## auf closed reagiert scene_root. Alle Maße: Einheit u = Breite/100 (wie HubView).

signal closed
## Paket gekauft: scene_root schickt es als Licht die Hub-Werkstatt-Ader entlang
## (Startpunkt = Kaufknopf-Mitte in Display-Pixeln). Die Lieferung meldet die
## PAKET-uid - der Komet landet auf genau ihrem Magazin-Platz.
signal pack_purchased(from_px: Vector2, uid: int)
## Das Kleingedruckte hat den Kaufpreis zurückgegeben - gebucht ist er längst,
## scene_root schickt ihn nur noch als Licht in die Truhe.
signal pack_refunded(from_px: Vector2, amount: int)
## Ein Schlüsselwort im Tooltip wurde geklickt - scene_root schlägt das Lexikon auf.
signal lexikon_requested(entry_id: String)
## Die Auslage der Bucht hat sich geändert (Seite gezeigt, gekauft) - scene_root
## stellt die Körper nach. Der Laden fasst nie einen an.
signal vitrine_changed

## Warengattungen der Bucht: der Laden nennt sie, die Bucht trägt sie durch und
## meldet sie beim Griff zurück - so bleibt der Kaufweg EIN Paar (Gattung, Index).
const KIND_ENGRAVING_PACK := "engraving_pack"
const KIND_DIE := "die"
const KIND_SPECIAL := "special"

## Die drei ANKUNFTS-GRADE der Bucht: ROLLEN heißt Zufall (die Seite ist frisch
## gewürfelt), STEIGEN heißt Abruf (dieselbe Ware kehrt zurück), LIEGENBLEIBEN
## heißt, dass gar nichts geschehen ist - das sichtbar gemachte Versprechen der
## Sortiment-Sperre. Der Laden ENTSCHEIDET nur; gefahren wird in der Bucht.
const GRADE_STAND := "stand"
const GRADE_RISE := "rise"
const GRADE_ROLL_IN := "roll_in"

## Was auf der Beschriftung statt des Preises steht, wenn das Lager zu ist.
const FULL_TAG := "MAGAZIN VOLL"

const CHARM_PRICE := 15

## Der Laden ist ELASTISCH: Anzahl der Plätze je Rubrik liefert GameRun (SHOP_*_SLOTS),
## die Kartengröße skaliert gegenläufig - wenige, große Angebote am Anfang, viele
## kleine später. Drei Rubriken/Segmente: Lager (Pakete) links, Charm-Regal +
## Chip-Schale (Einzelstücke) rechts.

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
## Schalen-Rabatt: ein einzeln in der Schale liegender Würfel kostet weniger als
## derselbe Würfel im Angebotsregal - er kommt ohne Auswahl und ohne Paket.
const SINGLE_DIE_DISCOUNT := 0.8

## Mindesthöhe der Vitrinen-Fläche in Einheiten - sie nimmt sonst die ganze
## Resthöhe unter der Charm-Zeile (grob die halbe Fensterhöhe). Der Boden sorgt
## nur dafür, dass auch ein Probe-Fenster eine Bucht meldet.
const VITRINE_MIN_HEIGHT := 24.0

## Preis eines Schalen-Würfels aus dem ungerabatteten Angebotspreis.
static func single_die_price(offer_price: int) -> int:
	return maxi(1, roundi(float(offer_price) * SINGLE_DIE_DISCOUNT))
const FLIP_DURATION := 0.25
## Beide Zonen blättern DIESELBE Doppelseite: die Charm-Zeile wartet, bis die alte
## Ware unter dem Glas versunken ist, sonst stünden neue Karten über alter Ware.
## Spiegelt VitrineView.SWAP_TIME (ui/ greift nicht in table/ - ein Test hält die
## beiden Zahlen gleich).
const FLIP_DELAY := 0.32

## Eine aufgeschlagene Doppelseite: bleibt für den ganzen Besuch bestehen -
## Zurückblättern zeigt exakt diese Seite wieder.
class MenuSpread:
	extends RefCounted

	## Versiegelte Gravur-Pakete des Regals. Würfel-Pakete gibt es nicht mehr - ein
	## Würfel liegt offen in der Schale.
	var engraving_packs: Array[Pack] = []
	var engraving_pack_bought: Array[bool] = []
	var charm_options: Array[Charm] = []
	var charm_bought: Array[bool] = []
	## Einzelstücke der Schale: OFFENE Würfel, alles vor dem Kauf sichtbar - der
	## EINZIGE Weg des Ladens an einen Würfel (run.shop_dice_slots() Plätze). Sie
	## gehören zur gerollten Auslage: die Sortiment-Sperre friert sie mit ein,
	## Gekauftes bleibt gekauft.
	var single_dice: Array[DieDefinition] = []
	var single_dice_prices: Array[int] = []
	var single_dice_bought: Array[bool] = []
	## Sonderposten der Schale: das versiegelte Paket, das der Kauf ausliefert.
	var single_specials: Array[Pack] = []
	var single_special_bought: Array[bool] = []
	## Hat diese Seite schon einmal körperlich in der Bucht gelegen? Genau daran
	## hängt der Ankunfts-Grad: was noch nie da war, wird gewürfelt, nicht abgerufen.
	var presented := false

## Der laufende Spiellauf (setzt scene_root). Der Shop hört auf money_changed,
## damit sich die Kaufbarkeit auch bei Geldzugängen von außen aktualisiert.
var run: GameRun:
	set(value):
		if run != null and run.money_changed.is_connected(_on_run_money_changed):
			run.money_changed.disconnect(_on_run_money_changed)
		if run != null and run.charms_changed.is_connected(_on_run_charms_changed):
			run.charms_changed.disconnect(_on_run_charms_changed)
		run = value
		# Ein frischer Lauf bekommt einen frischen Laden - auch ohne Sperre.
		sortiment_locked = false
		spreads = []
		_standing_spread = null
		_vitrine_grade = GRADE_STAND
		if run != null:
			run.money_changed.connect(_on_run_money_changed)
			run.charms_changed.connect(_on_run_charms_changed)

## Breiteneinheit (size.x / 100), in _build_layout gesetzt.
var u := 8.0

## Gerüst-Referenzen (je open() frisch gebaut).
var money_label: Label
var content_root: VBoxContainer  # trägt die Charm-Zeile (der Rest liegt in der Bucht)
## Die VITRINE: hier malt der Laden NICHTS. Unter diesem Rechteck schneidet das
## Glas sein Loch und die echte Bucht steht darunter - der Laden meldet es nur
## nach oben (apron_bottom-Muster), gebaut wird die Grube von scene_root.
var vitrine_slot: Control
var page_label: Label
var done_button: Button
var page_back_button: Button
var page_next_button: Button
## Blättern-Hinweis (Hub-Stufe 1) + Hub-Aufstieg-Knopf im Shop-Fuß.
var flip_hint_label: Label
var hub_upgrade_button: Button
## Umschalter der Sortiment-Sperre (Shop-Fuß).
var lock_button: Button

## Hover-Dropdown der CHARM-Karten - die einzige Ware, die Bildschirm bleibt.
## Alles Körperliche erklärt sich auf der Scheibe (VitrineAnnotationView).
var shop_tooltip: PanelContainer
var shop_tooltip_title: Label
## RichTextLabel statt Label: die Schlüsselwörter im Text sind Lexikon-Verweise.
var shop_tooltip_body: RichTextLabel
## Der Zeiger liegt auf dem Tooltip selbst - die Schonfrist lässt ihn stehen.
var _tooltip_hovered := false
## Entwertet laufende Ausblende-Fristen (jede Änderung macht ältere Timer taub).
var _tooltip_hide_token := 0
## Schonfrist beim Verlassen des Ankers: genug, um die Lücke zum Tooltip zu queren.
const TOOLTIP_HIDE_GRACE := 0.25

var spreads: Array[MenuSpread] = []
var current_spread_index: int = 0

## Die Seite, die gerade körperlich in der Bucht liegt, und der Grad, in dem die
## zuletzt gezeigte Seite dorthin kommt. Beides ist reine Anzeige-Buchführung -
## an der Ökonomie ändert der Grad nichts.
var _standing_spread: MenuSpread = null
var _vitrine_grade := GRADE_STAND

## Sortiment-Sperre: solange sie steht, würfelt open() NICHTS neu - der nächste
## Besuch findet dieselben Doppelseiten samt ihrer Kauf-Marken. Sie überlebt
## Runden, nicht den Lauf (siehe run-Setter).
var sortiment_locked: bool = false

## Ein Dock-Wechsel hat einen Neuaufbau der Auslage angemeldet - verhindert
## mehrere Neuaufbauten im selben Frame.
var _charm_rebuild_queued: bool = false

# Spiegel der AKTUELLEN Doppelseite - Kauf-Handler und Tests arbeiten dagegen.
# Knopf-Listen führt nur noch das Charm-Regal: alles andere LIEGT in der Bucht.
var charm_options: Array[Charm] = []
var charm_buttons: Array[Button] = []
var charm_bought: Array[bool] = []
var engraving_packs: Array[Pack] = []
var engraving_pack_bought: Array[bool] = []
var single_dice: Array[DieDefinition] = []
var single_dice_prices: Array[int] = []
var single_dice_bought: Array[bool] = []
var single_specials: Array[Pack] = []
var single_special_bought: Array[bool] = []

var flip_tween: Tween

## Nach einem Hub-Aufstieg mitten im Shop: ab diesem Index flackern die NEUEN
## Charm-Karten wie eine zündende Neonröhre auf (-1 = kein Flackern). Die Ware in
## der Bucht flackert nicht - sie ROLLT an (Grad-Regel der Bucht).
var _flicker_charm_from: int = -1

## Einmalige Meldung, die beim nächsten Öffnen oben erscheint (Nebenwetten-
## Ergebnis der geräumten Runde); von scene_root vor open() gesetzt.
var pending_bet_notice: String = ""

## Öffnet den Shop frisch auf der ersten Doppelseite (Gebühr startet neu);
## baut das Gerüst passend zur aktuellen Größe. Ist das Sortiment gesperrt,
## bleiben die bestehenden Seiten samt Kauf-Marken stehen.
func open() -> void:
	_build_layout()
	if not sortiment_locked or spreads.is_empty():
		spreads = [_build_spread()]
		current_spread_index = 0
	_relayout_and_show()

## Wieder-Eintritt über den Hub-Knopf: dieselbe Auslage, NICHTS wird neu gewürfelt.
## Gekaufte Ware bleibt weg, die Seite bleibt stehen - der Laden ist derselbe, der
## Spieler geht nur noch einmal hinein. Ohne Auslage (Laden nie offen gewesen)
## rollt er wie beim ersten Öffnen.
func reopen() -> void:
	_build_layout()
	if spreads.is_empty():
		spreads = [_build_spread()]
		current_spread_index = 0
	_relayout_and_show()

## Die stehende Auslage zeigen - der gemeinsame Schluss von open() und reopen().
func _relayout_and_show() -> void:
	current_spread_index = clampi(current_spread_index, 0, spreads.size() - 1)
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
	# Sortiment-Sperre: steht in der Kopfzeile neben dem Geld - im Fuß hätte sie
	# die Blätter-/Aufstiegs-Knöpfe auf hohen Hub-Stufen aus dem Panel geschoben.
	lock_button = _neon_button("", NEON_CYAN, u * 2.4, Vector2(u * 22.0, u * 4.6))
	lock_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock_button.pressed.connect(_on_lock_pressed)
	header.add_child(lock_button)
	money_label = _label("$0", u * 4.0, Color(1.5, 1.24, 0.15))
	header.add_child(money_label)

	# Nebenwetten-Ergebnis der letzten Runde (einmalig, dann verbraucht).
	if pending_bet_notice != "":
		var notice := _label(pending_bet_notice, u * 2.3, NEON_GREEN)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(notice)
		pending_bet_notice = ""

	# Bildschirm-Zone: nur noch die Charm-Zeile, in ihrer natürlichen Höhe -
	# Lizenzen sind digitale Ware. Alles Körperliche liegt in der Bucht darunter.
	content_root = VBoxContainer.new()
	content_root.name = "Content"
	content_root.add_theme_constant_override("separation", int(u * 1.6))
	content_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(content_root)

	# Die Bucht bekommt die ganze Resthöhe: sie ist die Auslage, nicht ein Fach
	# darin. Gemalt wird allein die FASSUNG - die Mitte ist ein echtes Loch.
	vitrine_slot = Control.new()
	vitrine_slot.name = "Vitrine"
	vitrine_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitrine_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vitrine_slot.custom_minimum_size = Vector2(0.0, u * VITRINE_MIN_HEIGHT)
	vitrine_slot.add_child(_vitrine_frame())
	root.add_child(vitrine_slot)

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
	_refresh_lock_button()

	_build_shop_tooltip()  # zuletzt: liegt als Overlay über allem

# --- Die Vitrine (gemeldete Geometrie, kein Inhalt) ----------------------------

## Das Buchten-Rechteck in globalen Display-Pixeln (leeres Rect = keine Bucht,
## etwa solange die Seite noch nicht ausgelegt ist).
func vitrine_rect_px() -> Rect2:
	if vitrine_slot == null or not is_instance_valid(vitrine_slot):
		return Rect2()
	return vitrine_slot.get_global_rect()

## Das LOCH darin: der Streifen ohne seine gemalte Fassung - dieselbe Rechnung wie
## am Magazin, damit beide Vertiefungen gleich im Glas sitzen.
func vitrine_pit_rect() -> Rect2:
	var strip := vitrine_rect_px()
	if strip.size.x <= 0.0 or strip.size.y <= 0.0:
		return Rect2()
	return PackDrawerView.pit_rect_in(strip, u)

## Die FASSUNG der Bucht: Rahmen ohne Füllung, Schatten oben, Licht unten. Ihre
## Mitte wird nicht gemalt - dort ist ein echtes Loch, und ein gemalter Grund läge
## hinter nichts. Rezeptur und Maße kommen aus der Magazin-Grube.
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

# --- Die Auslage der Bucht (gemeldet, nie gezeichnet) --------------------------

## Der Ankunfts-Grad der zuletzt gezeigten Seite. scene_root liest ihn und fährt
## ihn EINMAL - jeder weitere Abgleich stellt hart nach.
func vitrine_grade() -> String:
	return _vitrine_grade

## Der Grad aus zwei Fakten, und aus mehr nicht: lag diese Seite schon einmal in
## der Bucht, und liegt sie dort gerade noch? Rollen heißt Zufall, Steigen heißt
## Abruf. Rein und prüfbar - der Entscheid ist die halbe Zeremonie.
static func grade_for(seen_before: bool, standing: bool) -> String:
	if not seen_before:
		return GRADE_ROLL_IN
	return GRADE_STAND if standing else GRADE_RISE

static func grade_rank(grade: String) -> int:
	match grade:
		GRADE_ROLL_IN: return 2
		GRADE_RISE: return 1
	return 0

## Der lautere von zwei Graden gewinnt: sammeln sich Meldungen an, bis die Bucht
## wirklich stellt, darf die leiseste die lauteste nicht verschlucken.
static func louder_grade(a: String, b: String) -> String:
	return a if grade_rank(a) >= grade_rank(b) else b

## Was körperlich in der Bucht liegt: je Rubrik ein Platz je Index, null für
## Verkauftes. Ausverkauft ist SICHTBAR - der Platz bleibt leer, und die
## bought-Marken halten die Lücken index-treu, damit ein Griff immer denselben
## Kaufweg meint.
func vitrine_stock() -> Dictionary:
	var engravings: Array = []
	var dice: Array = []
	var specials: Array = []
	for i in engraving_packs.size():
		engravings.append(null if engraving_pack_bought[i] else engraving_packs[i])
	for i in single_dice.size():
		dice.append(null if single_dice_bought[i] else single_dice[i])
	for i in single_specials.size():
		specials.append(null if single_special_bought[i] else single_specials[i])
	return {
		KIND_ENGRAVING_PACK: engravings,
		KIND_DIE: dice,
		KIND_SPECIAL: specials,
	}

## Die Beschriftung EINES Stücks: Titel, Wirkung (Lexikon-Verweise setzt die
## Karte selbst), Preis und beim Würfel sein volles Netz. Der Preis steht NUR
## hier - in der Bucht hängt kein Schild. {} = kein solches Stück.
func vitrine_annotation(kind: String, index: int) -> Dictionary:
	if run == null or index < 0:
		return {}
	match kind:
		KIND_ENGRAVING_PACK:
			if index >= engraving_packs.size():
				return {}
			return _pack_annotation(engraving_packs[index])
		KIND_SPECIAL:
			if index >= single_specials.size():
				return {}
			return _special_annotation(single_specials[index])
		KIND_DIE:
			if index >= single_dice.size():
				return {}
			return _die_annotation(single_dice[index], single_dice_prices[index], "")
	return {}

func _pack_annotation(pack: Pack) -> Dictionary:
	# Die Mengenzeile steht nur da, wo die Multicast-Zeile sie nicht ohnehin nennt
	# (Würfel- und Fixinhalt-Pakete) - zweimal dieselbe Zahl liest sich als Fehler.
	var body := _pack_tooltip_body(pack)
	if not Pack.tierable(pack):
		body = "%s\n%s" % [_pack_count_text(pack), body]
	return {
		"title": pack.display_name,
		"body": body,
		"price": _pack_price(pack),
		"money": run.money,
		"blocked": FULL_TAG if run.packs_full() else "",
	}

## Der Sonderbestand führt zwei Familien: die Gravur-Sonderposten (sie LIEGEN
## offen in der Schale) und die Katalysator-Kassetten (sie stehen versiegelt im
## Regal). Der Katalysator nennt seinen Paketnamen, die Gravur ihren eigenen.
func _special_annotation(pack: Pack) -> Dictionary:
	var out := _pack_annotation(pack)
	if not pack.is_catalyst() and pack.fixed_engraving != null:
		out["title"] = pack.fixed_engraving.display_name
		out["body"] = pack.fixed_engraving.description
	return out

func _die_annotation(def: DieDefinition, price: int, tail: String) -> Dictionary:
	var essence := Essence.by_id(def.essence_id)
	var title := def.display_name if essence == null \
		else "%s – %s" % [def.display_name, essence.display_name]
	var body := "Augensumme %d." % DiceRowView.eye_total(def)
	if essence != null:
		body += "\n%s: %s" % [essence.display_name, essence.description]
	else:
		body += "\nOhne Essenz."
	return {
		"title": title,
		"body": body + tail,
		"price": price,
		"money": run.money,
		"net": def,
		"blocked": "",
	}

# --- Kauf-Eingänge der Bucht (scene_root meldet den Griff hierher) -------------

func buy_engraving_pack(index: int) -> void:
	_on_pack_buy_pressed(index)

func buy_single_die(index: int) -> void:
	_on_single_die_pressed(index)

func buy_single_special(index: int) -> void:
	_on_single_special_pressed(index)

# --- Blättern ------------------------------------------------------------------

## Gebühr für die nächste NEUE Doppelseite; Wechselgeld-Charm UND ein hoher
## Hub-Ausbau (Penthouse) senken sie.
func _next_flip_fee() -> int:
	var base := maxi(1, FLIP_FEE_BASE + spreads.size() - 1)
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
		spreads[current_spread_index] = _build_spread()
	_refresh_hub_footer()
	_show_spread()

# --- Sortiment-Sperre ----------------------------------------------------------

func _on_lock_pressed() -> void:
	sortiment_locked = not sortiment_locked
	_refresh_lock_button()

## Der Knopf trägt die AKTION, nicht den Zustand - den zeigt seine Saumfarbe
## (Gold = gesperrt).
func _refresh_lock_button() -> void:
	if lock_button == null or not is_instance_valid(lock_button):
		return
	var accent := NEON_GOLD if sortiment_locked else NEON_CYAN
	lock_button.text = "🔒 Sperre lösen" if sortiment_locked else "🔓 Sortiment sperren"
	lock_button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	lock_button.add_theme_stylebox_override("focus", _button_box(Color("#221e46cc"), accent))
	lock_button.add_theme_stylebox_override("disabled",
		_button_box(Color("#1a183666"), Color(accent.r, accent.g, accent.b, 0.25)))

## Zurückblättern ist immer gratis.
func _on_page_back_pressed() -> void:
	if current_spread_index == 0:
		return
	current_spread_index -= 1
	_show_spread()
	_play_flip_animation()

## Rein kosmetische Einblendung - der Spielzustand ist schon gewechselt, die
## Animation gate nichts (schnelles Klicken ersetzt sie einfach). Sie wartet den
## Warenumschlag darunter ab: die Karten der neuen Seite erscheinen, wenn auch die
## neue Ware kommt.
func _play_flip_animation() -> void:
	if flip_tween != null and flip_tween.is_valid():
		flip_tween.kill()
	content_root.modulate = Color(1, 1, 1, 0)
	flip_tween = create_tween()
	flip_tween.tween_interval(FLIP_DELAY)
	flip_tween.tween_property(content_root, "modulate:a", 1.0, FLIP_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# --- Doppelseiten bauen --------------------------------------------------------

## Frische Doppelseite: Charms oben, unten die versiegelten Gravur-Pakete des
## Regals plus die offenen Einzelwürfel der Schale.
func _build_spread() -> MenuSpread:
	var spread := MenuSpread.new()
	# Besitz SPERRT: was im Dock steht, liegt nicht noch einmal aus - wie im
	# Schwarzmarkt. Nur innerhalb EINER Doppelseite kommt jeder Archetyp ohnehin
	# höchstens einmal vor (ohne Zurücklegen, erase unten).
	# Essenz-Charms liegen nur aus, wenn ihre Seele wirklich im Pool steckt -
	# ohne den Würfel wären sie tote Karten und verdünnten den Topf.
	var owned := run.owned_charm_ids()
	var available := _without_owned(
		Charm.offerable(Charm.all(), run.owned_essence_ids(), run.charm_offer_features()), owned)
	var charm_slots := run.shop_charm_slots()
	var rarity_tier := run.shop_rarity_tier()
	# Raritäts-Schub: der erste Platz zieht garantiert einen Charm ab der zur Stufe
	# passenden Mindest-Rarität (Tier 1 ungewöhnlich, 2 selten, 3 legendär) - fällt
	# auf die nächst-niedrigere Schwelle zurück, falls keiner verfügbar ist.
	if rarity_tier >= 1 and charm_slots > 0:
		var premium := _charms_at_least(available, rarity_tier)
		if not premium.is_empty():
			var top := Charm.pick_weighted(premium, owned)
			spread.charm_options.append(top)
			available.erase(top)
	# Restliche Plätze gewichtet nach Rarität und Besitz ziehen, ohne Zurücklegen.
	while spread.charm_options.size() < charm_slots and not available.is_empty():
		var pick := Charm.pick_weighted(available, owned)
		spread.charm_options.append(pick)
		available.erase(pick)
	spread.charm_bought.resize(spread.charm_options.size())
	spread.charm_bought.fill(false)

	# Gravur-Pakete: die Sorte entscheidet die Häufigkeit (viele Zahlen, wenige
	# Kanten), die Mindest-Seltenheit im Inhalt zieht GameRun beim Öffnen.
	# Die GRÖSSE würfelt jeder Platz einzeln (60/30/10) - der Laden ist der EINE
	# Weg zu Groß und Kolossal, jede Prämie prägt Standard.
	for i in run.shop_pack_slots():
		spread.engraving_packs.append(Pack.roll_engraving_pack(Pack.roll_tier()))
	spread.engraving_pack_bought.resize(spread.engraving_packs.size())
	spread.engraving_pack_bought.fill(false)

	# Die Einzelwürfel der Schale - der EINZIGE Würfelweg des Ladens. Sie werden
	# HIER ausgewürfelt und vollständig gezeigt: kein Blindkauf, das ist ihr ganzer
	# Zweck. Wie viele, sagt die Lizenz (shop_dice_slots).
	var owned_souls := run.owned_essence_ids()
	for i in run.shop_dice_slots():
		var offers := DiceOffer.roll_offers(1, run.charm_ids(), owned_souls, run.hub_level)
		if offers.is_empty() or offers[0].dice.is_empty():
			continue
		var die: DieDefinition = offers[0].dice[0]
		spread.single_dice.append(die)
		# Die Würfel-Rabatte (Trickdieb, Mengenrabatt) liegen jetzt hier: seit die
		# Würfel-Pakete tot sind, ist die Schale der einzige Würfelkauf.
		spread.single_dice_prices.append(
			single_die_price(CharmEffects.die_price(offers[0].price, run.charm_ids())))
		# Ein frisch gerolltes Unikat darf nicht zweimal in derselben Auslage liegen.
		if die.essence_id != "" and not owned_souls.has(die.essence_id):
			owned_souls.append(die.essence_id)
	spread.single_dice_bought.resize(spread.single_dice.size())
	spread.single_dice_bought.fill(false)

	# Sonderposten ab der achten Lizenz: er LIEGT in der Schale, nicht als Karte
	# im Regal. Anders als ein Paket ist er kein Blindkauf - man sieht, welcher
	# der beiden da liegt, und genau dafür ist die Schale da.
	if randf() < run.shop_special_chance():
		spread.single_specials.append(Pack.roll_special_pack())
	spread.single_special_bought.resize(spread.single_specials.size())
	spread.single_special_bought.fill(false)

	return spread

## Ohne die schon besessenen Archetypen. Ein LEERES Ergebnis fällt auf den vollen
## Topf zurück - ein leerer Platz wäre schlimmer als eine Dublette (dieselbe
## Erschöpfungs-Regel wie im Schwarzmarkt).
func _without_owned(pool: Array[Charm], owned: Array[String]) -> Array[Charm]:
	var out: Array[Charm] = []
	for charm in pool:
		if not owned.has(charm.id):
			out.append(charm)
	return out if not out.is_empty() else pool

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
	_vitrine_grade = grade_for(spread.presented, spread == _standing_spread)
	spread.presented = true
	_standing_spread = spread
	charm_options = spread.charm_options
	charm_bought = spread.charm_bought
	engraving_packs = spread.engraving_packs
	engraving_pack_bought = spread.engraving_pack_bought
	single_dice = spread.single_dice
	single_dice_prices = spread.single_dice_prices
	single_dice_bought = spread.single_dice_bought
	single_specials = spread.single_specials
	single_special_bought = spread.single_special_bought

	_rebuild_content(spread)
	page_label.text = "Seite %d" % (current_spread_index + 1)
	_refresh_afford_state()
	# EIN Melder für jede Änderung der Bucht: Seitenwechsel, Kauf und Tausch
	# laufen alle durch _show_spread.
	vitrine_changed.emit()

## Gibt den Inhalt frei - auch beim Schließen wichtig, damit die
## 3D-Vorschau-Viewports nicht im Hintergrund weiterrendern.
func _clear_pages() -> void:
	if content_root != null:
		for child in content_root.get_children():
			child.queue_free()
	charm_buttons.clear()

## Baut die Bildschirm-Zone der Seite: seit dem Vitrinen-Umbau ist das NUR noch
## das Charm-Regal - Pakete, Einzelstücke und das Händler-Regal liegen körperlich
## in der Bucht darunter. Die Karten füllen die Breite, die Zeile bleibt so hoch,
## wie sie sein muss; alles Weitere gehört der Vitrine.
func _rebuild_content(spread: MenuSpread) -> void:
	for child in content_root.get_children():
		child.queue_free()
	charm_buttons.clear()

	var charm_zone := _make_zone(content_root, NEON_MAGENTA, "CHARM-REGAL",
		"je $%d" % _charm_price())
	var charm_row := HBoxContainer.new()
	charm_row.add_theme_constant_override("separation", int(u * 1.4))
	charm_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	charm_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charm_zone.add_child(charm_row)
	var cm := _charm_metrics(spread.charm_options.size())
	var podest_index := 0 if run.shop_rarity_tier() >= 1 else -1
	for i in spread.charm_options.size():
		var podest := i == podest_index
		var ccard := _build_charm_card(spread.charm_options[i], i, cm.x, int(cm.y), podest)
		charm_row.add_child(ccard)
		_maybe_flicker(ccard, i, _flicker_charm_from)

	# Das Flackern gilt nur für DIESEN Aufbau (direkt nach einem Aufstieg).
	_flicker_charm_from = -1

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
	var bought := charm_bought[index]
	# Voller Dock steht wie "gekauft" da: der Platz ist zu, egal was er kostet.
	var full := run.charms_full()
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
	var detail := charm.description
	if full and not bought:
		detail += "\n\nAlle %d Charm-Plätze belegt - erst einen verkaufen." % GameRun.CHARM_CAPACITY
	card.mouse_entered.connect(_show_shop_tooltip.bind(card, charm.display_name, detail))
	card.mouse_exited.connect(_hide_shop_tooltip)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(u * 0.3))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	# Lichtfleck hinter dem Modell (CenterContainer stapelt beide mittig).
	var glow := tint if not bought else Color(tint.r, tint.g, tint.b, 0.3)
	var disc_side := thumb_px * (1.5 if podest else 1.27)
	var stage := CenterContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow_disc(glow, disc_side))
	stage.add_child(CharmThumb.new(charm, thumb_px))
	column.add_child(stage)

	var tag := "gekauft" if bought else ("voll" if full else \
		("gratis" if _charm_price() <= 0 else "$%d" % _charm_price()))
	column.add_child(_label(tag,
		u * 2.0, NEON_MUTED if bought or full else Color(1.4, 1.16, 0.14), HORIZONTAL_ALIGNMENT_CENTER))

	# Der Handler hängt an JEDER ungekauften Karte: ein voller Dock sperrt sie nur
	# als Startzustand, ein Verkauf gibt sie ohne Neuverdrahtung wieder frei
	# (_on_charm_clicked prüft charms_full ohnehin selbst).
	if not bought:
		card.pressed.connect(_on_charm_clicked.bind(index))
	if bought or full:
		card.disabled = true
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

## Kauf eines Sonderpostens aus der Schale: er geht VERSIEGELT ins Lager wie jedes
## Paket - offen wartet keine Aufwertung. Derselbe Kaufweg wie die Regal-Pakete,
## samt Kleingedrucktem und Lieferkomet.
func _on_single_special_pressed(index: int) -> void:
	if single_special_bought[index]:
		return
	var pack: Pack = single_specials[index]
	var price := _pack_price(pack)
	# Volles Magazin sperrt den Kauf wie eine knappe Börse (purchase_pack prüft
	# ebenso, aber ein stiller Fehlkauf dürfte hier nie als gekauft gelten).
	if run.money < price or run.packs_full():
		return
	var from_px := _buy_origin_px()
	var refunded := run.purchase_pack(pack, price)
	single_special_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	pack_purchased.emit(from_px, pack.pack_uid)
	if refunded > 0:
		pack_refunded.emit(from_px, refunded)
	_show_spread()

## Kauf eines offenen Würfels: bezahlt, aber NICHT eingesetzt. Er wandert ins
## Regal des Händlers, bis der Spieler selbst sagt, welcher Pool-Platz weichen
## soll - der Automat wählte sonst blind, und eine Seele ist nicht wiederbeschaffbar.
func _on_single_die_pressed(index: int) -> void:
	if single_dice_bought[index] or run.money < single_dice_prices[index]:
		return
	run.stash_die(single_dice[index], single_dice_prices[index])
	single_dice_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	_show_spread()

## Mengenzeile der Regal-Reihe: nur WIE VIEL - die Sorte sagt das Siegel,
## den Rest der Hover-Dropdown. Bei einem Gravur-Paket steht die Menge nicht fest:
## es zählt der Grundwurf seiner Größe, so oft die Kette hält.
func _pack_count_text(pack: Pack) -> String:
	if Pack.tierable(pack):
		return "%s je Auslösung" % Pack.pieces_word(PhantomPress.base_for(pack.tier))
	return Pack.pieces_word(pack.count)

## Die Hover-Auskunft eines Pakets: seine Beschreibung, und bei Gravur-Paketen die
## Multicast-Zeile darunter - die Größe muss vor dem Kauf lesbar sein.
## Chance und Decke reicht der LAUF herein - der Laden zeigt, was die Presse jetzt
## kann, samt Lizenzstufe, Klausel und vorgemerktem Wett-Schub.
func _pack_tooltip_body(pack: Pack) -> String:
	if not Pack.tierable(pack):
		return pack.description
	if run == null:
		return "%s\n%s" % [pack.description, Pack.multicast_line(pack.tier)]
	return "%s\n%s" % [pack.description,
		Pack.multicast_line(pack.tier, run.multicast_chance(), run.multicast_cap())]

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
	# STOP statt IGNORE: der Tooltip ist anfahrbar, seine Schlüsselwörter klickbar.
	shop_tooltip.mouse_filter = Control.MOUSE_FILTER_STOP
	CasinoStyle.style_panel(shop_tooltip)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", int(u * 0.4))
	shop_tooltip.add_child(box)
	shop_tooltip_title = Label.new()
	shop_tooltip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(shop_tooltip_title, int(u * 2.6), CasinoStyle.GOLD)
	box.add_child(shop_tooltip_title)
	shop_tooltip_body = RichTextLabel.new()
	shop_tooltip_body.bbcode_enabled = true
	shop_tooltip_body.fit_content = true
	shop_tooltip_body.scroll_active = false
	# STOP, nicht PASS: der Tooltip liegt in keinem Knopf, es gibt nichts weiterzureichen.
	shop_tooltip_body.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_tooltip_body.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	shop_tooltip_body.custom_minimum_size = Vector2(u * 28.0, 0)
	shop_tooltip_body.add_theme_font_size_override("normal_font_size", int(u * 1.9))
	shop_tooltip_body.add_theme_color_override("default_color", CasinoStyle.CREAM)
	shop_tooltip_body.add_theme_color_override("font_outline_color", CasinoStyle.INK)
	shop_tooltip_body.add_theme_constant_override("outline_size", 2)
	shop_tooltip_body.meta_clicked.connect(_on_tooltip_meta)
	box.add_child(shop_tooltip_body)
	# Der Zeiger darf vom Anker auf den Tooltip wandern: solange er auf Panel
	# oder Text liegt, hält _tooltip_hovered die Ausblende-Frist auf. Beide
	# Knoten melden, denn der STOP-Text nimmt dem Panel den Hover weg.
	for node: Control in [shop_tooltip, shop_tooltip_body]:
		node.mouse_entered.connect(func() -> void: _tooltip_hovered = true)
		node.mouse_exited.connect(func() -> void:
			_tooltip_hovered = false
			_hide_shop_tooltip())
	add_child(shop_tooltip)

## Preiszeile und ihre Farbe - reine Funktionen, damit die Entscheidung
## "bezahlbar oder nicht" prüfbar ist und nur an EINER Stelle fällt.
static func price_text(price: int) -> String:
	return "$%d" % price

static func price_tint(price: int, money: int) -> Color:
	return NEON_GOLD if money >= price else CasinoStyle.RED

## Zeigt den Dropdown unter (oder notfalls über) der überfahrenen Charm-Karte,
## immer im Panel eingeklemmt (clip_contents schneidet Überstände ab). Preis und
## Würfelnetz führt er nicht mehr - die stehen auf der Scheibe über der Bucht.
func _show_shop_tooltip(anchor: Control, title: String, body: String) -> void:
	if shop_tooltip == null:
		return
	_tooltip_hide_token += 1  # eine laufende Ausblende-Frist gilt nicht mehr
	shop_tooltip_title.text = title
	# EIN Engpass für beide Hover-Quellen des Bildschirms: hier werden die
	# Schlüsselwörter zu Lexikon-Verweisen.
	shop_tooltip_body.text = Lexikon.linkify(body)
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

## Ausblenden mit Schonfrist: der Zeiger darf vom Anker zum Tooltip wandern, um
## dort ein Schlüsselwort zu klicken - liegt er nach der Frist auf keinem von
## beiden, geht der Tooltip zu. Die Hover-Quellen rufen weiter DIESE Funktion.
func _hide_shop_tooltip() -> void:
	_tooltip_hide_token += 1
	var token := _tooltip_hide_token
	get_tree().create_timer(TOOLTIP_HIDE_GRACE).timeout.connect(func() -> void:
		if token == _tooltip_hide_token and not _tooltip_hovered:
			_hide_tooltip_now())

## Sofort zu, ohne Frist - für Stellen, an denen der Tooltip im Weg stünde
## (Tausch-Auswahl, Verweis-Klick).
func _hide_tooltip_now() -> void:
	_tooltip_hide_token += 1  # entwertet laufende Fristen
	_tooltip_hovered = false
	if shop_tooltip != null:
		shop_tooltip.visible = false

## Verweis-Klick im Tooltip: zumachen und das Lexikon anfordern.
func _on_tooltip_meta(meta: Variant) -> void:
	_hide_tooltip_now()
	lexikon_requested.emit(String(meta))

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

## Jedes Paket trägt seinen festen Sortenpreis; der Schnäppchenjäger zieht davon
## ab, danach Inflation/Skonto des Hauses.
func _pack_price(pack: Pack) -> int:
	return run.shop_price(CharmEffects.pack_price(pack.price, pack.type, run.charm_ids()))

## Der Hausgutschein schenkt den ERSTEN Charm des Blocks - danach zählt
## wieder der normale Preis samt Inflation/Skonto.
func _charm_price() -> int:
	if run.charm_is_free():
		return 0
	return run.shop_price(CharmEffects.charm_price(CHARM_PRICE, run.charm_ids()))

## Kauft ein versiegeltes Paket (je Angebot einmal); es wandert ungeöffnet ins
## Werkstatt-Lager. Danach wird die Doppelseite neu bebaut.
func _on_pack_buy_pressed(index: int) -> void:
	if index < 0 or index >= engraving_packs.size() or engraving_pack_bought[index]:
		return
	var pack: Pack = engraving_packs[index]
	var price := _pack_price(pack)
	# Volles Magazin sperrt wie eine knappe Börse - erst pressen, dann kaufen.
	if run.money < price or run.packs_full():
		return
	var from_px := _buy_origin_px()
	var refunded := run.purchase_pack(pack, price)
	engraving_pack_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	pack_purchased.emit(from_px, pack.pack_uid)
	if refunded > 0:
		pack_refunded.emit(from_px, refunded)
	_show_spread()

## Startpunkt eines Kauf-Kometen: die Ware liegt in der Bucht, also kommt er von
## dort - eine 2D-Karte gibt es nur noch für Charms.
func _buy_origin_px() -> Vector2:
	var bay := vitrine_rect_px()
	return bay.get_center() if bay.size.x > 0.0 else get_global_rect().get_center()

## Kauft den Charm (je einmal). Danach wird die ganze Doppelseite neu bebaut:
## Shop-Charms (Rabattmarke, Trickdieb-Manschette, ...) wirken schon in DIESEM Besuch -
## alle Preisschilder und Schwellen zeigen sonst alte Preise.
func _on_charm_clicked(index: int) -> void:
	var charm := charm_options[index]
	if charm_bought[index] or run.charms_full():
		return
	var was_free := run.charm_is_free()
	run.purchase_charm(charm, _charm_price())
	if was_free:
		run.consume_free_charm()
	charm_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	_show_spread()

## Deaktiviert alles Unbezahlbare und hält den Geldstand der Kopfzeile aktuell.
## Die Ware in der Bucht hat keine Knöpfe mehr - ihre Kaufbarkeit steht in der
## Preiszeile der Beschriftung (price_tint), und der Kaufweg prüft sie ohnehin.
func _refresh_afford_state() -> void:
	var money: int = run.money
	if money_label != null:
		money_label.text = "$%d" % money
	for i in charm_buttons.size():
		if not charm_bought[i]:
			charm_buttons[i].disabled = run.charms_full() or money < _charm_price()
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

## Der Dock hat sich geändert (Kauf ODER Verkauf): "voll"-Tag und Hinweistext
## stecken in der Karte, die Auslage muss also neu gebaut werden. DEFERRED, weil
## ein Kauf-Klick charms_changed synchron feuert, bevor er seine charm_bought-
## Marke setzt - sonst bekäme der Neuaufbau den alten Stand.
func _on_run_charms_changed() -> void:
	if not visible or spreads.is_empty() or _charm_rebuild_queued:
		return
	_charm_rebuild_queued = true
	_rebuild_after_charms_changed.call_deferred()

func _rebuild_after_charms_changed() -> void:
	_charm_rebuild_queued = false
	if visible and not spreads.is_empty():
		_show_spread()

func _on_done_pressed() -> void:
	close()

## Laden zu - per "Fertig" oder weil der Spieler die Runde in der Grube aufnimmt.
func close() -> void:
	_clear_pages()  # 3D-Vorschauen freigeben (kein Hintergrund-Rendern)
	visible = false
	closed.emit()
