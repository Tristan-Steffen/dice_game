class_name ShopController
extends Control
## Der Shop zwischen den Runden - ein Neon-Panel auf der Hub-Fläche des
## Tisch-Displays, bedient über die Maus-Weiterleitung. Die Seite liest sich als
## DREI REGALE (Spieler-Entscheid 2026-10-25): CHARMS, GRAVUREN, WÜRFEL - je drei
## gleich große Plätze auf EINEM Spaltenraster, der Preis direkt unter seinem
## Stück. Darunter das AUSKUNFTS-BAND und der Fuß. Körper zeichnet dieser Laden nie
## selbst; er MELDET Rechtecke und Inhalte nach oben (vitrine_rect_px/die_seats_px/
## vitrine_stock, slit_anchors/slit_stock), aufgestellt wird alles von scene_root.
## Ohne Zeiger trägt jede Ware nur Name/Farbe und Preis; mit Zeiger spricht das
## Auskunfts-Band: Kassette (Name + Beschreibung) oder Würfel (Auskunft + Netz).
## "Umblättern" auf eine NEUE Seite würfelt frische Angebote aus und kostet eine
## steigende Gebühr; bereits gesehene Seiten bleiben stehen (MenuSpread) und sind
## gratis erreichbar. Zustands-Mutation läuft ausschließlich über GameRun-Methoden;
## auf closed reagiert scene_root. Alle Maße: Einheit u = Breite/100 (wie HubView).

signal closed
## Die einzelne SONDER-KARTE ist gekauft: scene_root schickt sie als Licht auf ihren
## Magazin-Platz (uid). Pakete melden nichts - ihre offene Auswahl steht in GameRun.
signal pack_purchased(from_px: Vector2, uid: int)
## Das Kleingedruckte hat den Kaufpreis zurückgegeben - gebucht ist er längst,
## scene_root schickt ihn nur noch als Licht ins Chip-Tray.
signal pack_refunded(from_px: Vector2, amount: int)
## Die Auslage der Bucht hat sich geändert (Seite gezeigt, gekauft) - scene_root
## stellt die Körper nach. Der Laden fasst nie einen an.
signal vitrine_changed
## Ein Modul ist gekauft (gebucht in pending_parts): scene_root schickt es als
## Licht über die Hub-Cluster-Ader zu den Chips.
signal part_purchased(from_px: Vector2)
## Ein Würfel-Paket ist gebucht - VOR dem Neuaufbau der Auslage, damit scene_root
## seine Schatulle als Körper übernehmen kann, bevor die Bucht sie abräumt.
signal dice_pack_purchased(index: int)
## Klick auf ein Schlüsselwort im Wirkungstext einer Charm-Karte.
signal lexikon_requested(entry_id: String)

## Warengattungen der Bucht: der Laden nennt sie, die Bucht trägt sie durch und
## meldet sie beim Griff zurück - so bleibt der Kaufweg EIN Paar (Gattung, Index).
const KIND_ENGRAVING_PACK := "engraving_pack"
const KIND_DIE := "die"
const KIND_SPECIAL := "special"
## Modul (als Körper im dritten Platz der Würfel-Bucht und im Schwarzmarkt).
const KIND_PART := "part"

## Die zwei ANKUNFTS-GRADE der Auslage: STEIGEN heißt, dass Ware durch die Fläche
## kommt, LIEGENBLEIBEN heißt, dass gar nichts geschehen ist - das sichtbar
## gemachte Versprechen der Sortiment-Sperre. Der Laden ENTSCHEIDET nur; gefahren
## wird in der Auslage.
const GRADE_STAND := "stand"
const GRADE_RISE := "rise"

## Was statt eines Preises steht, wenn das Lager zu ist - ein Kauf, der stumm
## scheitert, wäre schlimmer als eine Zahl weniger. Die lange Fassung trägt die
## Karte des Hinterzimmers, die kurze das schmale Preisschild einer Kassette.
const FULL_TAG := "MAGAZIN VOLL"
const FULL_MARK := "VOLL"
## Kein Steckplatz mehr frei (die wartenden mitgezählt).
const PARTS_FULL_TAG := "STECKPLÄTZE VOLL"


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

## FESTE PROPORTIONEN: Charm-Band und Fuß stehen in u, die Gravuren-Zeile mißt
## ihre liegende Karte, die Würfel-Zeile ihren Würfel. Den Rest nimmt das
## Auskunfts-Band - kein Band wächst mit Fortschrittsstufe oder Bestand.
const BAND_CHARM_UNITS := 26.0
## Der Fuß trägt die höchsten Knöpfe der Seite (gemessen: die Blätter-Pfeile mit
## ihrem Grad 3,2 u brauchen 5,9 u) - die Zahl steht bewußt darüber, sonst
## bestimmten die Knöpfe die Bandhöhe.
const BAND_FOOTER_UNITS := 6.2

## Das SPALTENRASTER der drei Regale: drei gleich breite Plätze über die volle
## Innenbreite, dieselben in jeder Zeile.
const COLUMNS := 3
const COLUMN_GAP := 2.0

## Der STELLPLATZ einer Kassette: ihr liegender Grundriß im EINEN Anzeigemaß
## (PackDrawerView.CASSETTE_SCALE) plus Stellluft. Die u-Maße sind nur ihr Boden,
## solange kein Grundriß gemeldet ist.
const SLIT_ROOM := 1.15
const SLIT_MIN_WIDTH := 5.4
const SLIT_MIN_HEIGHT := 8.0
## Höhe der Würfel-Bucht: der liegende Würfel samt Griff-Hub und Schacht.
const DIE_ROOM_UNITS := 10.0

const FLANK_MIN_WIDTH := 14.0
const FLANK_MIN_HEIGHT := 4.0
const FLANK_SEPARATION := 0.7
## Wieviel der Bandhöhe der NAME höchstens nimmt - der Rest gehört der
## Beschreibung, die als einzige umbricht.
const FLANK_NAME_SHARE := 0.38
const FLANK_NAME_STEPS := [2.4, 2.2, 2.0, 1.8, 1.6]
const FLANK_BODY_STEPS := [2.0, 1.8, 1.6, 1.45, 1.3, 1.15, 1.0]

## Mindesthöhe des AUSKUNFTS-BANDES unter den Regalen (u): es trägt die längste
## Paket-Beschreibung ungekürzt und beim Würfel-Hover dessen Netz.
const VITRINE_FOOTER_UNITS := 6.5
const FOOTER_MARGIN := 2.0
const FOOTER_STEPS := [2.0, 1.8, 1.6, 1.4, 1.25, 1.1]
## Die Zeile unter dem Würfel-Paket bzw. Modul (Auskunft): Höhe in u und Anteil der
## Spaltenbreite, den sie höchstens nimmt.
const DIE_NET_UNITS := 8.0
const DIE_NET_WIDTH_SHARE := 0.9
## Die Würfel-Paket-Auskunft schrumpft, bis sie ungeschnitten in ihren Block paßt.
const DIE_INFO_STEPS := [1.6, 1.45, 1.3, 1.15, 1.0, 0.9]

## Die PROJEKTION der Netz-Blöcke: nach einer echten Ankunft wächst jeder Block aus
## seinem Würfel heraus, und vor jedem Abräumen wird er in ihn zurück ABSORBIERT -
## dieselbe Zeit, dieselbe Staffelung, nur rückwärts. Eine zurückkehrende Seite ist
## KEINE Ankunft: dort steht der Block sofort.
const NET_GROW_TIME := 0.5
## Ein Hauch Versatz je Würfel: die Reihe projiziert sich von links nach rechts,
## statt in einem Schlag dazustehen.
const NET_GROW_STAGGER := 0.05
## Woraus er wächst - fast nichts, aber nicht null: eine Null nähme dem Block seine
## Richtung und ließe ihn aus dem Nirgendwo kommen.
const NET_GROW_FROM := 0.02
## Die Einblendung ist kürzer als das Wachsen: erst da, dann fertig gewachsen.
const NET_FADE_SHARE := 0.6
const FLIP_DURATION := 0.25
## Beide Zonen blättern DIESELBE Doppelseite: die Charm-Zeile wechselt im Augenblick
## des BAND-SCHRITTS - die alte Ware ist gesenkt und verschwunden, die neue rückt
## nach. Spiegelt VitrineView.belt_moment() (ui/ greift nicht in table/ - ein Test
## hält die beiden Zahlen gleich); der Vorlauf der Absorption kommt davor.
const FLIP_DELAY := 0.4

## Eine aufgeschlagene Doppelseite: bleibt für den ganzen Besuch bestehen -
## Zurückblättern zeigt exakt diese Seite wieder.
class MenuSpread:
	extends RefCounted

	## Die PAKETE der Reihe - Einzelkarten verkauft der Laden nicht mehr.
	var engraving_packs: Array[CardPack] = []
	var engraving_pack_bought: Array[bool] = []
	var charm_options: Array[Charm] = []
	var charm_bought: Array[bool] = []
	## Der Modul-Platz der Würfel-Bucht (SHOP_PART_SLOTS, mit der Seite gewürfelt).
	var part_options: Array[ComboPart] = []
	var part_bought: Array[bool] = []
	## Die WÜRFEL-PAKETE der Schale (run.shop_dice_slots() Plätze) - der EINZIGE Weg
	## des Ladens an einen Würfel. Die Sortiment-Sperre friert sie mit ein.
	var single_dice: Array[DicePack] = []
	var single_dice_prices: Array[int] = []
	var single_dice_bought: Array[bool] = []
	## Die einzelne SONDER-KARTE auf dem letzten Platz (höchstens eine).
	var single_specials: Array[Pack] = []
	var single_special_bought: Array[bool] = []
	## Hat diese Seite schon einmal körperlich in der Bucht gelegen? Genau daran
	## hängt der Ankunfts-Grad: was noch nie da war, wird gewürfelt, nicht abgerufen.
	var presented := false

## Der laufende Spiellauf (setzt scene_root). Der Shop hört auf money_changed und
## packs_changed, damit Kaufbarkeit und Magazin-Marke auch bei Änderungen von
## außen (Pressen, Prämien) nachziehen.
var run: GameRun:
	set(value):
		if run != null and run.money_changed.is_connected(_on_run_money_changed):
			run.money_changed.disconnect(_on_run_money_changed)
		if run != null and run.charms_changed.is_connected(_on_run_charms_changed):
			run.charms_changed.disconnect(_on_run_charms_changed)
		if run != null and run.packs_changed.is_connected(_on_run_packs_changed):
			run.packs_changed.disconnect(_on_run_packs_changed)
		if run != null and run.pending_parts_changed.is_connected(_on_run_parts_changed):
			run.pending_parts_changed.disconnect(_on_run_parts_changed)
			run.combo_parts_changed.disconnect(_on_run_parts_changed)
		run = value
		# Ein frischer Lauf bekommt einen frischen Laden - auch ohne Sperre.
		sortiment_locked = false
		spreads = []
		_standing_spread = null
		_vitrine_grade = GRADE_STAND
		_leaving = false  # der alte Laden räumt für den neuen nichts mehr ab
		_suspended = false
		if run != null:
			run.money_changed.connect(_on_run_money_changed)
			run.charms_changed.connect(_on_run_charms_changed)
			run.packs_changed.connect(_on_run_packs_changed)
			run.pending_parts_changed.connect(_on_run_parts_changed)
			run.combo_parts_changed.connect(_on_run_parts_changed)

## Breiteneinheit (size.x / 100), in _build_layout gesetzt.
var u := 8.0

## Gerüst-Referenzen (je open() frisch gebaut).
var money_label: Label
var content_root: VBoxContainer  # das CHARM-Regal (der Rest liegt körperlich auf dem Tisch)
## Das WÜRFEL-Regal: Titel, Bucht und die Zeile der Schilder darunter.
var vitrine_slot: Control
## Die BUCHT: der Streifen, auf dem die Würfel liegen - der Laden meldet ihn nur
## (apron_bottom-Muster), aufgestellt wird von scene_root.
var vitrine_field: Control
## Der Schilder-Layer: je Würfel ein Block aus Name/Preis darüber und Netz darunter.
## Reine Anzeige; die Anker kennt allein scene_root.
var vitrine_nets: Control
## Die Zeile unter der Bucht, die das Netz reserviert.
var die_labels: Control
## Die Zeile ÜBER der Bucht: Name/Seele und Preis je Würfel.
var die_head: Control
## Die Auskunftszeile im AUSKUNFTS-BAND - ohne Hover unsichtbar.
var net_footer: LexikonText
## Das AUSKUNFTS-BAND unter den Regalen: dort spricht der gegriffene Würfel
## (net_footer) ODER die gegriffene Karte (slit_info) - nie beide.
var ware_foot: Control
## Die Auskunft der Kassette (Name + Beschreibung). Absolut positioniertes Overlay
## der SEITE, kein Layout-Kind - die Bandhöhen bleiben davon unberührt.
var slit_info: Control
var slit_info_name: Label
var slit_info_body: Label
var page_label: Label
var done_button: Button
var page_back_button: Button
var page_next_button: Button
## Umschalter der Sortiment-Sperre (Kopfzeile).
var lock_button: Button

## Das GRAVUREN-Regal: drei Plätze, auf denen die Kassetten liegen; der Laden
## meldet ihre Mitten, die Zellen stellt scene_root.
var slit_row: Control
var _gravur_band: VBoxContainer
var _slit_pads: Array[Panel] = []
## Je Platz sein Preisschild direkt unter der Karte - leer, wo nichts liegt.
var _slit_prices: Array[Label] = []
## Je Platz {kind, index}.
var _slit_seats: Array[Dictionary] = []
## Eine eben gebaute Reihe hat noch KEIN Rechteck - erst das Sortieren ihres Bandes
## stellt sie hin. Wer vorher mißt, stapelt alles auf den Ursprung.
var _slit_row_fresh := true

## Fußabdruck einer LIEGENDEN Kassette in Display-Pixeln (meldet scene_root).
## Daran ist der Stellplatz geschnitten - ein Weltmaß, kein u-Maß.
var data_cell_lie_px := Vector2.ZERO:
	set(value):
		if data_cell_lie_px.is_equal_approx(value):
			return
		data_cell_lie_px = value
		if slit_row != null and is_instance_valid(slit_row):
			rebuild_slit_row()

var spreads: Array[MenuSpread] = []
var current_spread_index: int = 0

## Die Seite, die gerade körperlich in der Bucht liegt, und der Grad, in dem die
## zuletzt gezeigte Seite dorthin kommt. Beides ist reine Anzeige-Buchführung -
## an der Ökonomie ändert der Grad nichts.
var _standing_spread: MenuSpread = null
var _vitrine_grade := GRADE_STAND
## Unterschrift der stehenden Schilder-Blöcke - gleiche Unterschrift, kein Neuaufbau.
var _net_signature := ""
## Je Würfel EIN Block aus Name/Seele und Preis - er wächst aus seinem Würfel.
var _net_blocks: Array[Control] = []
## Läuft eine Projektion (Wachstum ODER Absorption)?
var _net_growing := false
## Und läuft sie RÜCKWÄRTS? Dann räumt die Absorption die Blöcke am Ende selbst ab.
var _net_absorbing := false
var _net_grow_tween: Tween
var _net_dice: Array = []  # je Block sein Würfel (DieDefinition) oder Modul (ComboPart)
## Je Block sein Preisschild - dieselbe Quelle wie der Kauf (single_dice_prices).
var _net_prices: Array[Label] = []
## Und darüber die NAMENS-Zeile: die Seele im Glühton der Essenz, sonst der Name.
var _net_souls: Array[Label] = []
## Was im Band steht - idempotenter Schreiber, er läuft je Bild.
var _net_hint := ""
## Welcher Würfel im Band erklärt wird (0 = keiner).
var _foot_die_key := 0
## Welche Kassette die Flanke gerade erklärt ("" = keine).
var _slit_info_key := ""

## Der Laden RÄUMT AB: seine Seite steht noch (die Zeremonie der Auslage spielt auf
## ihr), er ist aber tot - kein Kauf, kein Neuaufbau, kein Forwarding. Erst
## finish_close() gibt die Fläche ab.
var _leaving := false
## Der Laden ist für eine PAKET-ÖFFNUNG abgetreten: kein closed, kein Rundenfortschritt;
## zurück kommt er allein über reopen().
var _suspended := false

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
## Je Karte ihr Kartenbild - daran ist das schwebende Modell darüber gemessen.
var charm_thumbs: Array[Control] = []
## Die zwei Gesichter der Mittelfläche je Karte: im Ruhezustand steht die Bühne
## mit dem Modell, beim Hover der Wirkungstext. Immer genau eines ist sichtbar.
var charm_stages: Array[Control] = []
var charm_effects: Array[LexikonText] = []
var charm_bought: Array[bool] = []
## Der Modul-Platz: Karte, Mittelfläche (Glyphe/Text) und Preiszeile je Teil.
var part_options: Array[ComboPart] = []
var part_bought: Array[bool] = []
var engraving_packs: Array[CardPack] = []
var engraving_pack_bought: Array[bool] = []
var single_dice: Array[DicePack] = []
var single_dice_prices: Array[int] = []
var single_dice_bought: Array[bool] = []
var single_specials: Array[Pack] = []
var single_special_bought: Array[bool] = []

var flip_tween: Tween

## Einmalige Meldung, die beim nächsten Öffnen oben erscheint (Nebenwetten-
## Ergebnis der geräumten Runde); von scene_root vor open() gesetzt.
var pending_bet_notice: String = ""
## Das Wett-Ergebnis dieses Besuchs: es steht im Auskunfts-Band, solange nichts
## gegriffen ist - eine eigene Zeile schob den Fuß aus dem Fenster.
var bet_notice: String = ""

## Öffnet den Shop frisch auf der ersten Doppelseite (Gebühr startet neu);
## baut das Gerüst passend zur aktuellen Größe. Ist das Sortiment gesperrt,
## bleiben die bestehenden Seiten samt Kauf-Marken stehen.
func open() -> void:
	_leaving = false  # ein Wieder-Aufdecken bricht jeden Abgang hart ab
	_suspended = false
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
	_leaving = false  # ein Wieder-Aufdecken bricht jeden Abgang hart ab
	_suspended = false
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

## Kopfzeile (Titel, Sperre, Geld), die drei Regale, das Auskunfts-Band und der
## Fuß (Blättern, Fertig). Der Neon-Rahmen kommt vom Hub darunter.
func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	u = maxf(size.x, 640.0) / 100.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inhalt darf nie über den Hub-Rahmen hinausragen (die Maus-Weiterleitung
	# endet an der Hub-Fläche).
	clip_contents = true

	# Die Kassetten-Auskunft steht VOR dem Layout in der Kindliste: sie ist ein
	# Overlay, kein Band - und das Möbel der Seite bleibt so ihr letztes Kind.
	_build_slit_info()

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(u * PAGE_MARGIN))
	margin.add_theme_constant_override("margin_right", int(u * PAGE_MARGIN))
	margin.add_theme_constant_override("margin_top", int(u * 2.0))
	margin.add_theme_constant_override("margin_bottom", int(u * 2.0))
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", int(u * 1.2))
	margin.add_child(root)

	# Kopfzeile: links der Titel, rechts Sperre und Geld. Überhelle Farben blühen
	# im HDR-Display (use_hdr_2d).
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", int(u * 2.0))
	root.add_child(header)
	var title := CasinoStyle.label("S H O P", u * 4.5, Color(1.5, 0.72, 1.2))
	header.add_child(title)
	var title_rail := CasinoStyle.rail(NEON_MAGENTA, u)
	title_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title_rail)
	lock_button = _neon_button("", NEON_CYAN, u * 2.4, Vector2(u * 22.0, u * 4.6))
	lock_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock_button.pressed.connect(_on_lock_pressed)
	header.add_child(lock_button)
	money_label = CasinoStyle.label("$0", u * 4.0, Color(1.5, 1.24, 0.15))
	header.add_child(money_label)

	# Nebenwetten-Ergebnis der letzten Runde (einmalig, dann verbraucht).
	bet_notice = pending_bet_notice
	pending_bet_notice = ""

	# Regal 1: CHARMS - digitale Ware, je Doppelseite neu bebaut (_rebuild_content).
	content_root = VBoxContainer.new()
	content_root.name = "Content"
	content_root.add_theme_constant_override("separation", int(u * ZONE_SEPARATION))
	content_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content_root.custom_minimum_size = Vector2(0.0, u * BAND_CHARM_UNITS)
	content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(content_root)

	# Regal 2: WÜRFEL - über den Karten-Paketen, damit die Schatulle gut im Bild liegt.
	var dice_band := VBoxContainer.new()
	dice_band.name = "DiceBand"
	dice_band.add_theme_constant_override("separation", int(u * ZONE_SEPARATION))
	dice_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dice_band.add_child(_heading_row("WÜRFEL & MODULE"))
	vitrine_slot = dice_band
	var shelf := VBoxContainer.new()
	shelf.name = "DiceShelf"
	shelf.add_theme_constant_override("separation", 0)
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_net_signature = ""  # ein frischer Layer trägt nichts, was schon stünde
	# Name und Preis stehen ÜBER dem Würfel, das Netz darunter (Spieler-Wunsch 2026-10-29).
	die_head = Control.new()
	die_head.name = "DieHead"
	die_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	die_head.custom_minimum_size = Vector2(0.0, _die_head_height())
	shelf.add_child(die_head)
	vitrine_field = Control.new()
	vitrine_field.name = "VitrineField"
	vitrine_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Die Hülle eines Würfel-Pakets liegt darin wie eine Kassette: so tief wie ihr Stellplatz.
	vitrine_field.custom_minimum_size = Vector2(0.0, maxf(u * DIE_ROOM_UNITS, slit_size().y))
	vitrine_nets = Control.new()
	vitrine_nets.name = "DieNets"
	vitrine_nets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitrine_nets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vitrine_field.add_child(vitrine_nets)
	shelf.add_child(vitrine_field)
	die_labels = Control.new()
	die_labels.name = "DieLabels"
	die_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	die_labels.custom_minimum_size = Vector2(0.0, _die_label_height())
	shelf.add_child(die_labels)
	dice_band.add_child(shelf)
	root.add_child(dice_band)

	# Regal 3: GRAVUREN - die Plätze stehen UNABHÄNGIG von der Doppelseite.
	_gravur_band = VBoxContainer.new()
	_gravur_band.name = "GravurBand"
	_gravur_band.add_theme_constant_override("separation", int(u * ZONE_SEPARATION))
	_gravur_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gravur_band.add_child(_heading_row("GRAVUREN"))
	slit_row = _shelf_row("SlitRow", _slit_seat_size().y)
	_gravur_band.add_child(slit_row)
	_fill_slit_row()
	# GEMELDET, nicht geraten: erst das Sortieren des Bandes stellt die Reihe hin.
	_gravur_band.sort_children.connect(func() -> void: _slit_row_fresh = false)
	root.add_child(_gravur_band)

	# Das AUSKUNFTS-BAND nimmt die Resthöhe - die Regale stehen dicht übereinander.
	ware_foot = Control.new()
	ware_foot.name = "WareFoot"
	ware_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ware_foot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ware_foot.custom_minimum_size = Vector2(0.0, u * VITRINE_FOOTER_UNITS)
	root.add_child(ware_foot)
	_build_net_footer()

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", int(u * 1.5))
	footer.custom_minimum_size = Vector2(0.0, u * BAND_FOOTER_UNITS)
	root.add_child(footer)
	page_back_button = _neon_button("‹", NEON_CYAN, u * 3.2, Vector2(u * 7.0, u * 5.0))
	page_back_button.pressed.connect(_on_page_back_pressed)
	footer.add_child(page_back_button)
	page_label = CasinoStyle.label("Seite 1", u * 2.8, NEON_MUTED)
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(page_label)
	page_next_button = _neon_button("›", NEON_CYAN, u * 3.2, Vector2(u * 12.0, u * 5.0))
	page_next_button.pressed.connect(_on_page_next_pressed)
	footer.add_child(page_next_button)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_spacer)
	# Fertig ist die primäre Aktion der Seite - und ihr EINZIGER gefüllter Knopf.
	done_button = _neon_button("Fertig", NEON_GOLD, u * 3.0, Vector2(u * 18.0, u * 5.0))
	CasinoStyle.style_primary_button(done_button, NEON_GOLD, u)
	done_button.pressed.connect(_on_done_pressed)
	footer.add_child(done_button)
	_refresh_lock_button()

# --- Das SPALTENRASTER ----------------------------------------------------------

## Breite eines Platzes in einer Zeile der Breite width. Rein und prüfbar.
static func column_width_in(width: float, gap: float) -> float:
	return maxf((width - gap * float(COLUMNS - 1)) / float(COLUMNS), 0.0)

## Linke Kante des Platzes index in einer Zeile der Breite width.
static func column_x(width: float, gap: float, index: int) -> float:
	return float(index) * (column_width_in(width, gap) + gap)

## Die Innenbreite der Seite - so breit ist jede Regalzeile.
func _inner_width() -> float:
	return maxf(size.x - float(int(u * PAGE_MARGIN)) * 2.0, 0.0)

func column_width() -> float:
	return column_width_in(_inner_width(), u * COLUMN_GAP)

## Eine Regalzeile: drei gleich breite Plätze, an ANKERN gehängt - so stehen sie mit
## ihrem Rechteck, sobald die Zeile ihres hat, in jeder Zeile auf denselben Kanten.
func _shelf_row(row_name: String, height: float) -> Control:
	var row := Control.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0.0, height)
	var n := float(COLUMNS)
	var gap := u * COLUMN_GAP
	for i in COLUMNS:
		var cell := Control.new()
		cell.name = "Place%d" % i
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Erst rechts, dann links: ein linker Anker rechts des rechten würde geklemmt.
		cell.set_anchor_and_offset(SIDE_RIGHT, float(i + 1) / n, -gap * (n - 1.0 - float(i)) / n)
		cell.set_anchor_and_offset(SIDE_LEFT, float(i) / n, gap * float(i) / n)
		cell.set_anchor_and_offset(SIDE_TOP, 0.0, 0.0)
		cell.set_anchor_and_offset(SIDE_BOTTOM, 1.0, 0.0)
		row.add_child(cell)
	return row

## Ein Kind waagerecht MITTIG in seinen Platz hängen, oben bündig.
static func _center_in_place(child: Control, width: float, height: float) -> void:
	child.set_anchor_and_offset(SIDE_RIGHT, 0.5, width * 0.5)
	child.set_anchor_and_offset(SIDE_LEFT, 0.5, -width * 0.5)
	child.set_anchor_and_offset(SIDE_TOP, 0.0, 0.0)
	child.set_anchor_and_offset(SIDE_BOTTOM, 0.0, height)

# --- Die Kassetten-Plätze (gemeldete Geometrie, kein Inhalt) -------------------

## Die Plätze der Reihe. Der Sonderposten BELEGT den letzten, er stellt keinen dazu;
## ein verkaufter oder nie gewürfelter Platz behält seinen Stellplatz.
func slit_seats() -> Array[Dictionary]:
	var seats: Array[Dictionary] = []
	if run == null:
		return seats
	for i in run.shop_pack_slots():
		seats.append({"kind": KIND_ENGRAVING_PACK, "index": i})
	if not single_specials.is_empty() and not seats.is_empty():
		seats[seats.size() - 1] = {"kind": KIND_SPECIAL, "index": 0}
	return seats

## Der STELLPLATZ: liegender Kartengrundriß plus Stellluft, mit einem u-Boden für
## ein Fenster, dem noch niemand einen Grundriß gemeldet hat.
func slit_size() -> Vector2:
	var card := data_cell_lie_px * PackDrawerView.CASSETTE_SCALE * SLIT_ROOM
	return Vector2(maxf(u * SLIT_MIN_WIDTH, card.x), maxf(u * SLIT_MIN_HEIGHT, card.y))

## Ein ganzer Platz: Stellplatz und darunter sein Preisschild.
func _slit_seat_size() -> Vector2:
	var pad := slit_size()
	return Vector2(pad.x, pad.y + u * WARE_PRICE_GAP + _price_height())

func _price_height() -> float:
	return ThemeDB.fallback_font.get_height(maxi(8, int(u * WARE_PRICE_FONT)))

func _fill_slit_row() -> void:
	_slit_pads.clear()
	_slit_prices.clear()
	_slit_seats = slit_seats()
	var places := slit_row.get_children()
	for i in mini(_slit_seats.size(), places.size()):
		places[i].add_child(_slit_seat(i))
	_slit_row_fresh = true

## Ein neuer Kartengrundriß mitten im Besuch: die Plätze werden neu geschnitten.
func rebuild_slit_row() -> void:
	if slit_row == null or not is_instance_valid(slit_row):
		return
	for place in slit_row.get_children():
		for child in place.get_children():
			child.queue_free()
	slit_row.custom_minimum_size = Vector2(0.0, _slit_seat_size().y)
	_fill_slit_row()
	if _gravur_band != null and is_instance_valid(_gravur_band):
		_gravur_band.queue_sort()  # frische Knöpfe: erst das nächste Sortieren gilt
	_slit_info_key = ""  # die Reihe ist neu, die Flanke erklärt nichts mehr
	if slit_info != null and is_instance_valid(slit_info):
		slit_info.visible = false
	_refresh_ware_prices()

## Ein Platz: der leere KNOPF fängt Klick und Zeiger, gezeichnet wird allein der
## flache Stellplatz darin. Der PREIS steht direkt darunter, mittig.
func _slit_seat(seat: int) -> Button:
	var pad_size := slit_size()
	var whole := _slit_seat_size()
	var button := Button.new()
	button.name = "SlitSeat"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_center_in_place(button, whole.x, whole.y)
	var pad := Panel.new()
	pad.name = "Pad"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.position = Vector2.ZERO
	pad.size = pad_size
	pad.add_theme_stylebox_override("panel", _slit_box())
	button.add_child(pad)
	_slit_pads.append(pad)
	var tag := CasinoStyle.label("", u * WARE_PRICE_FONT, NEON_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	tag.name = "Price"
	tag.position = Vector2(0.0, pad_size.y + u * WARE_PRICE_GAP)
	tag.size = Vector2(pad_size.x, _price_height())
	button.add_child(tag)
	_slit_prices.append(tag)
	# Nur der KLICK hängt hier: Anheben und Auskunft fragt scene_root je Bild ab.
	button.pressed.connect(_on_slit_pressed.bind(seat))
	return button

## Der Stellplatz ist eine flache Marke im Kartengrundriß - eine Karte liegt darauf.
func _slit_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#0b0a1ce6")
	box.border_color = Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.3)
	box.set_border_width_all(maxi(1, int(u * 0.18)))
	box.set_corner_radius_all(int(u * 0.8))
	return box

## STEHT die Reihe wirklich? Eine eben gebaute hat bis zum nächsten Sortieren
## ihres Bandes keine Rechtecke - wer stellt, mißt erst, wenn es soweit ist.
func slit_row_laid_out() -> bool:
	return not _slit_row_fresh

## Display-Pixel der STELLPLATZ-Mitten (leere eingeschlossen) - dort liegt die
## Kassette, und von dort fährt eine gekaufte los.
func slit_anchors() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for pad in _slit_pads:
		if is_instance_valid(pad):
			out.append(pad.get_global_rect().get_center())
	return out

## Dieselben Stellplätze als Rechtecke - die Rechteck-Treue prüft sich daran.
func slit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for pad in _slit_pads:
		if is_instance_valid(pad):
			out.append(pad.get_global_rect())
	return out

## Was in den Schlitzen steckt: je Platz sein Paket, null für verkauft oder nie
## gewürfelt. Die Lücken sind index-treu - ein Griff meint immer denselben Kaufweg.
func slit_stock() -> Array:
	var out: Array = []
	for seat in _slit_seats:
		out.append(_slit_pack(seat))
	return out

## Das Paket bzw. (Sonderposten-Platz) die einzelne Sonder-Karte eines Platzes.
func _slit_pack(seat: Dictionary) -> Resource:
	var index := int(seat["index"])
	if String(seat["kind"]) == KIND_SPECIAL:
		if index >= single_specials.size() or single_special_bought[index]:
			return null
		return single_specials[index]
	if index >= engraving_packs.size() or engraving_pack_bought[index]:
		return null
	return engraving_packs[index]

func _on_slit_pressed(seat: int) -> void:
	if seat < 0 or seat >= _slit_seats.size():
		return
	var entry := _slit_seats[seat]
	if _slit_pack(entry) == null:
		return
	if String(entry["kind"]) == KIND_SPECIAL:
		_on_single_special_pressed(int(entry["index"]))
	else:
		_on_pack_buy_pressed(int(entry["index"]))

## Der Platz EINES Angebots (-1 = keiner) - der Kauf-Komet startet dort.
func _seat_of(kind: String, index: int) -> int:
	for i in _slit_seats.size():
		if String(_slit_seats[i]["kind"]) == kind and int(_slit_seats[i]["index"]) == index:
			return i
	return -1

# --- Die Kassetten-Auskunft im Auskunfts-Band ----------------------------------
# Die Farbe nennt Sorte und Größe, das Schild den Preis - was in der Kassette
# steckt, sagt das Band, und nur mit Zeiger.

func _build_slit_info() -> void:
	slit_info = Control.new()
	slit_info.name = "SlitInfo"
	slit_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slit_info.visible = false
	slit_info_name = _wrapped_line(u * float(FLANK_NAME_STEPS[0]), NEON_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT)
	slit_info.add_child(slit_info_name)
	slit_info_body = _wrapped_line(u * float(FLANK_BODY_STEPS[0]), NEON_MUTED,
		HORIZONTAL_ALIGNMENT_LEFT)
	slit_info.add_child(slit_info_body)
	add_child(slit_info)
	_slit_info_key = ""

## Der Platz der Karten-Auskunft in globalen Pixeln: das AUSKUNFTS-BAND unter den
## Regalen. GEMESSEN - leer heißt, die Seite ist noch nicht ausgelegt.
func slit_flank_rect() -> Rect2:
	if ware_foot == null or not is_instance_valid(ware_foot):
		return Rect2()
	var band := ware_foot.get_global_rect()
	var margin := u * FOOTER_MARGIN
	if band.size.x - margin * 2.0 < u * FLANK_MIN_WIDTH or band.size.y < u * FLANK_MIN_HEIGHT:
		return Rect2()
	return Rect2(band.position + Vector2(margin, 0.0),
		Vector2(band.size.x - margin * 2.0, band.size.y))

## Der EINE Schreiber der Flanke (-1 = kein Platz gegriffen). Ein verkaufter oder
## nie gewürfelter Platz zeigt NICHTS - dort liegt keine Ware, die etwas sagen
## könnte. Idempotent: dieselbe Kassette schreibt nichts neu. `cell_hint` ist die
## Zeile der NETZ-ZELLE unter dem Zeiger (scene_root fragt den Körper): sie
## übersteuert die Wirkung des ganzen Pakets, der Name bleibt stehen.
func set_slit_hover(seat: int, cell_hint := "") -> void:
	if slit_info == null or not is_instance_valid(slit_info):
		return
	var pack: Resource = null
	if seat >= 0 and seat < _slit_seats.size():
		pack = _slit_pack(_slit_seats[seat])
	var key := "" if pack == null else "%d:%d:%s" % [seat, pack.get_instance_id(),
		cell_hint]
	if key == _slit_info_key:
		return
	_slit_info_key = key
	if pack == null:
		slit_info.visible = false
		_redraw_foot()  # das Wett-Ergebnis kehrt zurück
		return
	var flank := slit_flank_rect()
	if flank.size.x <= 0.0:
		slit_info.visible = false
		_slit_info_key = ""  # ungemessen: beim nächsten Bild noch einmal versuchen
		return
	slit_info.position = flank.position - get_global_rect().position
	slit_info.size = flank.size
	slit_info_name.text = String(pack.get("display_name"))
	if pack is CardPack:
		slit_info_name.modulate = PackDrawerView.card_pack_tint((pack as CardPack).sort)
		slit_info_body.text = cell_hint if cell_hint != "" else CardPack.info_body(pack)
	else:
		slit_info_name.modulate = PackDrawerView.pack_tint(pack as Pack)
		slit_info_body.text = cell_hint if cell_hint != "" else Pack.info_body(pack as Pack)
	_fit_slit_info(flank.size)
	slit_info.visible = true
	if _net_hint == "" and net_footer != null and is_instance_valid(net_footer):
		net_footer.visible = false

## Beide Zeilen passen sich in die Flanke ein: erst der Name in seinen Anteil,
## dann die Beschreibung in den Rest. Der Block bleibt in der Reihenhöhe und
## steht senkrecht mittig darin.
func _fit_slit_info(flank: Vector2) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var gap := u * FLANK_SEPARATION
	var lead := slit_info_body.get_theme_constant("line_spacing")
	var name_px := _block_font(font, slit_info_name.text, flank.x,
		flank.y * FLANK_NAME_SHARE, FLANK_NAME_STEPS, lead)
	var name_h := wrapped_height(font, slit_info_name.text, flank.x, name_px, lead)
	var body_px := _block_font(font, slit_info_body.text, flank.x,
		maxf(flank.y - name_h - gap, 1.0), FLANK_BODY_STEPS, lead)
	var body_h := wrapped_height(font, slit_info_body.text, flank.x, body_px, lead)
	var top := maxf((flank.y - name_h - gap - body_h) * 0.5, 0.0)
	_lay_wrapped(slit_info_name, name_px, Vector2(0.0, top), Vector2(flank.x, name_h))
	_lay_wrapped(slit_info_body, body_px, Vector2(0.0, top + name_h + gap),
		Vector2(flank.x, body_h))

## Eine umbrechende Zeile setzen: Grad, Platz, Rechteck. Sie MUSS clip_text tragen
## (siehe _wrapped_line) - sonst klemmt Godot ihre Höhe an einer Mindesthöhe, die
## aus der noch ungesetzten Breite gerechnet ist, und die Zeile wird meterhoch.
func _lay_wrapped(label: Label, px: int, at: Vector2, span: Vector2) -> void:
	label.add_theme_font_size_override("font_size", px)
	label.position = at
	label.size = span

## Eine frei gesetzte, umbrechende Zeile: kein Layout-Kind, also trägt sie ihr
## Rechteck selbst. clip_text nimmt ihr die autowrap-Mindesthöhe (und ist zugleich
## das Netz, falls eine Leiter je zu kurz wäre).
func _wrapped_line(font_size: float, color: Color, align: int) -> Label:
	var label := CasinoStyle.label("", font_size, color, align)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	return label

## Der größte Grad einer Leiter, in dem der umgebrochene Text noch in den Block
## paßt - sonst der kleinste.
func _block_font(font: Font, text: String, width: float, block: float, steps: Array,
		spacing: int) -> int:
	var smallest := maxi(8, int(u * float(steps[steps.size() - 1])))
	for step in steps:
		var px := maxi(8, int(u * float(step)))
		if wrapped_height(font, text, width, px, spacing) <= block:
			return px
	return smallest

## Wie hoch eine umbrechende Zeile WIRKLICH steht: Godot rechnet je Zeile
## Schrifthöhe PLUS Zeilenabstand - text_block_height läßt den letzten weg, und
## genau der schnitt die unterste Zeile ab.
static func wrapped_height(font: Font, text: String, width: float, px: int,
		spacing: int) -> float:
	if font == null:
		return 0.0
	return float(WorkshopView.text_block_lines(font, text, width, px)) \
		* (font.get_height(px) + float(spacing))

# --- Die Würfel-Auskunft im Auskunfts-Band -------------------------------------
# Eine rahmenlose Zeile - das Netz steht schon unter dem Würfel.
# EIN Schreiber (scene_root entscheidet, wer spricht), leer = unsichtbar.

func _build_net_footer() -> void:
	# Schlüsselwörter (Essenzen, Mult, Krit ...) sind Klickziele wie auf der
	# Charm-Karte - die Zeile hält dafür, solange der Zeiger auf dem Band liegt.
	net_footer = LexikonText.new()
	net_footer.name = "NetFooter"
	net_footer.center_h = true
	net_footer.center_v = true
	net_footer.set_style(int(u * float(FOOTER_STEPS[0])), NEON_MUTED)
	net_footer.share_hint(self, _keyword_hint_card(int(u * float(FOOTER_STEPS[0]))))
	net_footer.entry_requested.connect(func(id: String) -> void: lexikon_requested.emit(id))
	net_footer.visible = false
	ware_foot.add_child(net_footer)
	_net_hint = ""
	_foot_die_key = 0
	if bet_notice != "":
		# Erst ausgelegt kennt das Band sein Maß.
		ware_foot.resized.connect(_redraw_foot, CONNECT_ONE_SHOT)

## Die Zeile des Bandes.
func set_net_hint(text: String, exclude_id := "") -> void:
	if net_footer == null or not is_instance_valid(net_footer) \
			or ware_foot == null or not is_instance_valid(ware_foot):
		return
	if text == _net_hint and exclude_id == _net_exclude:
		return
	_net_hint = text
	_net_exclude = exclude_id
	_redraw_foot()

## Der eigene Eintrag der gezeigten Ware: ihr Name verweist nicht auf sich selbst.
var _net_exclude := ""

func _redraw_foot() -> void:
	if net_footer == null or not is_instance_valid(net_footer):
		return
	var text := _net_hint if _net_hint != "" else bet_notice
	net_footer.set_source(text, _net_exclude if _net_hint != "" else "")
	net_footer.visible = text != ""
	if text == "":
		return
	# Der Platz wird beim ANZEIGEN gerechnet: erst dann steht das Band gemessen da.
	var field := ware_foot.size
	var margin := u * FOOTER_MARGIN
	var room := Vector2(maxf(field.x - margin * 2.0, 1.0), maxf(field.y, 1.0))
	var px := _footer_font(room, u)
	net_footer.position = Vector2(margin, 0.0)
	net_footer.size = room
	net_footer.set_style(px, NEON_GREEN if _net_hint == "" else NEON_MUTED)

## Der Grad der Zeile: der größte, in dem sie umgebrochen noch ins Band paßt.
func _footer_font(block: Vector2, bay_u: float) -> int:
	var smallest := maxi(8, int(bay_u * float(FOOTER_STEPS[FOOTER_STEPS.size() - 1])))
	for step in FOOTER_STEPS:
		var px := maxi(8, int(bay_u * float(step)))
		if net_footer.measure(block.x, px) <= block.y:
			return px
	return smallest

## Hält der Zeiger die Zeile? Ein Schlüsselwort darin muß erreichbar bleiben,
## also spricht die Ware weiter, solange er auf dem gefüllten Band liegt.
func foot_holds(pixel: Vector2) -> bool:
	return net_footer != null and is_instance_valid(net_footer) and net_footer.visible \
		and _net_hint != "" and ware_foot.get_global_rect().has_point(pixel)

## Der EINE Schreiber der Auskunft der Bucht (null = nichts gegriffen): ein Würfel
## nennt Name, Seele und Wirkung, ein Modul Name, Phase, Wirkung und Preis.
## Idempotent je Instanz.
func set_die_hover(def: DieDefinition) -> void:
	set_ware_hover(def)

func set_ware_hover(item: Object) -> void:
	var key := 0 if item == null else item.get_instance_id()
	if key == _foot_die_key:
		return
	_foot_die_key = key
	var text := ""
	var own := ""
	if item is DicePack:
		text = "%s - %s" % [(item as DicePack).display_name,
			DicePack.info_body(item).replace("\n", " ")]
	elif item is DieDefinition:
		text = die_foot_text(item)
		if (item as DieDefinition).essence_id != "":
			own = "essence:%s" % (item as DieDefinition).essence_id
	elif item is ComboPart:
		text = part_foot_text(item)
		own = "part:%s" % (item as ComboPart).id
	set_net_hint(text, own)

## Die Auskunft eines Moduls als EINE Zeile.
func part_foot_text(part: ComboPart) -> String:
	var index := part_options.find(part)
	var tag := part_tag(index) if index >= 0 else ""
	return "%s · Phase: %s - %s  %s" % [part.display_name,
		Lexikon.PART_PHASE_NAMES.get(part.phase, ""), part.description, tag]

## Die Auskunft eines Würfels als EINE Zeile - aus derselben Quelle wie der
## Info-Schirm der Werkstatt.
static func die_foot_text(def: DieDefinition) -> String:
	var info := WorkshopInfoView.die_info(def)
	return "%s · %s - %s" % [info["title"], info["sub"], info["body"]]

# --- Die Bucht der Würfel (gemeldete Geometrie, kein Inhalt) ---------------------

## Das Buchten-Rechteck in globalen Display-Pixeln (leeres Rect = keine Bucht,
## etwa solange die Seite noch nicht ausgelegt ist).
func vitrine_rect_px() -> Rect2:
	if vitrine_field == null or not is_instance_valid(vitrine_field):
		return Rect2()
	return vitrine_field.get_global_rect()

## Das FELD darin: der Streifen ohne Fassung - dieselbe Rechnung wie am Magazin.
func vitrine_pit_rect() -> Rect2:
	var strip := vitrine_rect_px()
	if strip.size.x <= 0.0 or strip.size.y <= 0.0:
		return Rect2()
	return PackDrawerView.pit_rect_in(strip, u)

## Die PLÄTZE der Würfel in globalen Display-Pixeln, je Angebot einer (verkaufte
## eingeschlossen): mittig in ihrem Platz des Rasters. Leer = noch nicht ausgelegt.
func die_seats_px() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var strip := vitrine_rect_px()
	if strip.size.x <= 0.0 or strip.size.y <= 0.0:
		return out
	var gap := u * COLUMN_GAP
	var half := column_width_in(strip.size.x, gap) * 0.5
	for i in single_dice.size() + part_options.size():
		out.append(strip.position + Vector2(column_x(strip.size.x, gap, i) + half,
			strip.size.y * 0.5))
	return out

## Der BLOCK des Würfels index in Pixeln der Bucht: seine Spalte von der Kopfzeile
## über der Bucht bis unter das Netz - der Würfel liegt mitten darin.
func die_label_rect(index: int) -> Rect2:
	var strip := vitrine_rect_px()
	if strip.size.x <= 0.0 or die_head == null or not is_instance_valid(die_head) \
			or die_labels == null or not is_instance_valid(die_labels):
		return Rect2()
	var top := die_head.get_global_rect().position.y
	var bottom := die_labels.get_global_rect().end.y
	var gap := u * COLUMN_GAP
	return Rect2(Vector2(column_x(strip.size.x, gap, index), top - strip.position.y),
		Vector2(column_width_in(strip.size.x, gap), bottom - top))

func _soul_height() -> float:
	return ThemeDB.fallback_font.get_height(maxi(8, int(u * WARE_SOUL_FONT)))

## Name/Seele und Preis - die Kopfzeile über der Bucht.
func _die_head_height() -> float:
	var gap := u * WARE_PRICE_GAP
	return _soul_height() + gap * 0.5 + _price_height() + gap * 0.5

## Das Netz - die Zeile unter der Bucht.
func _die_label_height() -> float:
	return u * WARE_PRICE_GAP + u * DIE_NET_UNITS

## Der Würfel, über dessen NETZ der Zeiger liegt (globaler Display-Pixel; null =
## keiner). Solange die Blöcke wachsen oder schrumpfen, lögen ihre Rechtecke.
func die_at_net(pixel: Vector2) -> DicePack:
	if _net_growing:
		return null
	for i in mini(_net_blocks.size(), _net_dice.size()):
		var block := _net_blocks[i]
		if block == null or not is_instance_valid(block):
			continue
		var net := block.get_node_or_null("Net") as Control
		if net != null and net.get_global_rect().has_point(pixel):
			return _net_dice[i] as DicePack
	return null

## Das Modul, über dessen Wirkungs-Zeile der Zeiger liegt (null = keins).
func part_at_net(pixel: Vector2) -> ComboPart:
	if _net_growing:
		return null
	for i in mini(_net_blocks.size(), _net_dice.size()):
		var block := _net_blocks[i]
		if block == null or not is_instance_valid(block) or not (_net_dice[i] is ComboPart):
			continue
		var net := block.get_node_or_null("Net") as Control
		if net != null and net.get_global_rect().has_point(pixel):
			return _net_dice[i]
	return null

## Die SCHILDER der Auslage stellen: je Eintrag {def, anchor} (anchor = der Würfel
## in Pixeln der Bucht). Idempotent - dieselbe Auslage baut nichts neu. Je Würfel
## steht sein Block in seiner Spalte: Name/Seele und Preis über der Bucht, das Netz
## darunter. Nach einer echten ANKUNFT (grow) wächst er aus seinem Würfel, sonst
## steht er sofort.
func set_die_nets(entries: Array, grow := false) -> void:
	var signature := "%d" % entries.size()
	for entry in entries:
		var item: Object = entry["dice_pack"] if entry.has("dice_pack") else entry["part"]
		var anchor: Vector2 = entry.get("anchor", Vector2.ZERO)
		signature += "|%d@%.1f,%.1f" % [item.get_instance_id(), anchor.x, anchor.y]
	if signature == _net_signature:
		return  # derselbe Stand: ein Abgleich mitten im Wachstum stört es nicht
	_net_signature = signature
	_drop_die_nets()
	if vitrine_nets == null or not is_instance_valid(vitrine_nets):
		return
	var soul_height := _soul_height()
	var gap := u * WARE_PRICE_GAP
	var net_top := _die_head_height() + vitrine_rect_px().size.y + gap
	var info_px := _dice_info_px(entries)
	for entry in entries:
		if entry.has("part"):
			_build_part_block(entry, soul_height, gap, net_top)
			continue
		var dice_pack: DicePack = entry["dice_pack"]
		var rect := die_label_rect(single_dice.find(dice_pack))
		if rect.size.x <= 0.0:
			continue
		var anchor: Vector2 = entry.get("anchor", rect.position)
		var block := Control.new()
		block.name = "NetBlock"
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.position = rect.position
		block.size = rect.size
		block.pivot_offset = anchor - rect.position
		vitrine_nets.add_child(block)
		_net_blocks.append(block)
		_net_dice.append(dice_pack)
		var name_label := CasinoStyle.label(dice_pack.display_name, u * WARE_SOUL_FONT,
			PackDrawerView.dice_pack_tint(dice_pack.sort), HORIZONTAL_ALIGNMENT_CENTER)
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.size = Vector2(rect.size.x, soul_height)
		block.add_child(name_label)
		_net_souls.append(name_label)
		var tag := CasinoStyle.label("", u * WARE_PRICE_FONT, NEON_GOLD,
			HORIZONTAL_ALIGNMENT_CENTER)
		tag.position = Vector2(0.0, soul_height + gap * 0.5)
		tag.size = Vector2(rect.size.x, _price_height())
		block.add_child(tag)
		_net_prices.append(tag)
		var width := rect.size.x * DIE_NET_WIDTH_SHARE
		var info := _wrapped_line(u * WARE_SOUL_FONT, NEON_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		info.name = "Net"
		info.text = DicePack.info_body(dice_pack)
		info.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		if info_px > 0:
			info.add_theme_font_size_override("font_size", info_px)
		info.position = Vector2((rect.size.x - width) * 0.5, net_top)
		info.size = Vector2(width, u * DIE_NET_UNITS)
		block.add_child(info)
	_refresh_ware_prices()
	if grow:
		_grow_die_nets()

## EIN Grad für alle Würfel-Paket-Auskünfte: der größte, in dem jede ungeschnitten paßt.
func _dice_info_px(entries: Array) -> int:
	var font := ThemeDB.fallback_font
	if font == null:
		return 0
	var probe := _wrapped_line(u * WARE_SOUL_FONT, NEON_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var lead := probe.get_theme_constant("line_spacing")
	probe.free()
	var px := 0
	for entry in entries:
		if not entry.has("dice_pack"):
			continue
		var rect := die_label_rect(single_dice.find(entry["dice_pack"]))
		if rect.size.x <= 0.0:
			continue
		var fit := _block_font(font, DicePack.info_body(entry["dice_pack"]),
			rect.size.x * DIE_NET_WIDTH_SHARE, u * DIE_NET_UNITS, DIE_INFO_STEPS, lead)
		px = fit if px == 0 else mini(px, fit)
	return px

## Der Block des MODULS in derselben Grammatik wie ein Würfel: über der Bucht Name
## (in der Phasen-Tönung) und Preis, darunter statt des Netzes seine Wirkung.
func _build_part_block(entry: Dictionary, soul_height: float, gap: float, net_top: float) -> void:
	var part: ComboPart = entry["part"]
	var rect := die_label_rect(single_dice.size() + part_options.find(part))
	if rect.size.x <= 0.0:
		return
	var anchor: Vector2 = entry.get("anchor", rect.position)
	var block := Control.new()
	block.name = "PartBlock"
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.position = rect.position
	block.size = rect.size
	block.pivot_offset = anchor - rect.position
	vitrine_nets.add_child(block)
	_net_blocks.append(block)
	_net_dice.append(part)
	var name_label := CasinoStyle.label(part.display_name, u * WARE_SOUL_FONT, part.tint(),
		HORIZONTAL_ALIGNMENT_CENTER)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size = Vector2(rect.size.x, soul_height)
	block.add_child(name_label)
	_net_souls.append(name_label)
	var tag := CasinoStyle.label("", u * WARE_PRICE_FONT, NEON_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	tag.position = Vector2(0.0, soul_height + gap * 0.5)
	tag.size = Vector2(rect.size.x, _price_height())
	block.add_child(tag)
	_net_prices.append(tag)
	var width := rect.size.x * DIE_NET_WIDTH_SHARE
	var effect := _wrapped_line(u * WARE_SOUL_FONT, NEON_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	effect.name = "Net"
	effect.text = "Phase: %s\n%s" % [Lexikon.PART_PHASE_NAMES.get(part.phase, ""), part.description]
	effect.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	effect.position = Vector2((rect.size.x - width) * 0.5, net_top)
	effect.size = Vector2(width, u * DIE_NET_UNITS)
	block.add_child(effect)

## Die PROJEKTION: der fertige Block steht zuerst (Endzustand-zuerst), dann fährt er
## auf fast nichts am Würfel-Anker zurück und wächst in NET_GROW_TIME wieder heraus,
## mit Alpha-Einblendung und einer Spur Versatz je Würfel. Jeder Abbruch läßt ihn
## schlicht fertig stehen.
func _grow_die_nets() -> void:
	_kill_net_growth()
	if _net_blocks.is_empty():
		return
	_net_growing = true
	_net_grow_tween = create_tween().set_parallel(true)
	for i in _net_blocks.size():
		var block := _net_blocks[i]
		if block == null or not is_instance_valid(block):
			continue
		block.scale = Vector2.ONE * NET_GROW_FROM
		block.modulate.a = 0.0
		var delay := NET_GROW_STAGGER * float(i)
		var swell := _net_grow_tween.tween_property(block, "scale", Vector2.ONE,
			NET_GROW_TIME)
		swell.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_net_grow_tween.tween_property(block, "modulate:a", 1.0,
			NET_GROW_TIME * NET_FADE_SHARE).set_delay(delay)
	_net_grow_tween.finished.connect(func() -> void: _net_growing = false)

## Die ABSORPTION - das Wachstum rückwärts: vor JEDEM Abräumen (Umschlag wie
## Abgang) fahren die Blöcke in NET_GROW_TIME in ihren Würfel zurück, in derselben
## Staffelung von hinten nach vorn. Erst DANACH fährt die Maschine: die Würfel
## stehen noch, wenn ihre Anzeige eingesogen wird. Sie räumt sich am Ende selbst ab
## und liefert den ehrlichen Vorlauf (0 = es steht nichts zu saugen).
func absorb_die_nets() -> float:
	if _net_blocks.is_empty():
		return 0.0
	_kill_net_growth()
	_net_growing = true
	_net_absorbing = true
	var count := _net_blocks.size()
	_net_grow_tween = create_tween().set_parallel(true)
	for i in count:
		var block := _net_blocks[i]
		if block == null or not is_instance_valid(block):
			continue
		var delay := NET_GROW_STAGGER * float(count - 1 - i)
		var shrink := _net_grow_tween.tween_property(block, "scale",
			Vector2.ONE * NET_GROW_FROM, NET_GROW_TIME)
		shrink.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		# Erst schrumpfen, dann verlöschen - umgekehrt wäre der Block fort, bevor er
		# im Würfel angekommen ist.
		_net_grow_tween.tween_property(block, "modulate:a", 0.0,
			NET_GROW_TIME * NET_FADE_SHARE).set_delay(
				delay + NET_GROW_TIME * (1.0 - NET_FADE_SHARE))
	_net_grow_tween.finished.connect(func() -> void:
		_net_absorbing = false
		clear_die_nets())
	return absorb_time(count)

## Der ehrliche Deckel der Absorption: das Schrumpfen plus die rückwärts laufende
## Staffelung. Rein und prüfbar - der Wirt taktet beide Zonen danach.
static func absorb_time(count: int) -> float:
	if count <= 0:
		return 0.0
	return NET_GROW_TIME + NET_GROW_STAGGER * float(count - 1)

## Der EINE Abbruch-Pfad beider Projektionen: kein Tween mehr, jeder Block steht
## ausgewachsen. Ein harter Abbruch mitten in der Absorption räumt danach ohnehin
## ab - hier zählt nur, dass kein halb geschrumpfter Block liegen bleibt.
func _kill_net_growth() -> void:
	if _net_grow_tween != null and _net_grow_tween.is_valid():
		_net_grow_tween.kill()
	_net_grow_tween = null
	_net_growing = false
	_net_absorbing = false
	for block in _net_blocks:
		if block != null and is_instance_valid(block):
			block.scale = Vector2.ONE
			block.modulate.a = 1.0

## Ist gerade ein Block in Bewegung? Solange antwortet der Info-Fuß nicht:
## skalierte Rechtecke lögen - beim Wachsen wie beim Einsaugen.
func nets_growing() -> bool:
	return _net_growing

## Werden die Blöcke gerade eingesogen? Solange gehören sie der Absorption: ein
## Abräumen von außen risse sie mitten im Schrumpfen weg.
func nets_absorbing() -> bool:
	return _net_absorbing

## Der Ton der Seelen-Zeile: das Kantenglühen der Essenz selbst. Ein dunkler Ton
## (Vakuum glüht schwarz) wird auf ein lesbares Maß gehoben - sonst stünde die
## Zeile als Loch auf dunklem Grund.
static func soul_tint(essence_id: String) -> Color:
	var glow := Essence.glow_for(essence_id)
	if glow.get_luminance() >= SOUL_MIN_LUMINANCE:
		return glow
	return glow.lerp(Color(1, 1, 1), SOUL_LIFT)

func clear_die_nets() -> void:
	# Eine Auskunft über verschwundene Ware wäre eine Lüge.
	set_die_hover(null)
	set_net_hint("")
	if _net_signature == "":
		return
	_net_signature = ""
	_drop_die_nets()

## Der Preis des Würfel-Pakets, unter dem dieser Block liegt (-1 = keiner).
func _shown_die_price(item: Object) -> int:
	for i in single_dice.size():
		if single_dice[i] == item and i < single_dice_prices.size():
			return single_dice_prices[i]
	return -1

func net_count() -> int:
	if vitrine_nets == null or not is_instance_valid(vitrine_nets):
		return 0
	return vitrine_nets.get_child_count()

func _drop_die_nets() -> void:
	_kill_net_growth()
	_net_blocks.clear()
	_net_dice.clear()
	_net_prices.clear()
	_net_souls.clear()
	if vitrine_nets == null or not is_instance_valid(vitrine_nets):
		return
	for child in vitrine_nets.get_children():
		vitrine_nets.remove_child(child)
		child.queue_free()

# --- Die Auslage der Bucht (gemeldet, nie gezeichnet) --------------------------

## Der Ankunfts-Grad der zuletzt gezeigten Seite. scene_root liest ihn und fährt
## ihn EINMAL - jeder weitere Abgleich stellt hart nach.
func vitrine_grade() -> String:
	return _vitrine_grade

## Der Grad aus EINEM Fakt: liegt diese Seite gerade noch in der Auslage? Dann
## bleibt sie liegen, sonst steigt sie auf. Rein und prüfbar.
static func grade_for(standing: bool) -> String:
	return GRADE_STAND if standing else GRADE_RISE

## Die PHYSISCHE Regel schlägt die Seiten-Regel: eine Bucht OHNE Körper zeigt ihre
## Ware immer als ANKUNFT - die Seite mag liegen geblieben sein, ihre Körper sind
## seit dem Abgang körperlich fort (Wiedereintritt über den Laden-Knopf, gesperrtes
## Sortiment). Rein und prüfbar; der Wirt zählt die Körper.
static func grade_on_stand(grade: String, occupied: bool) -> String:
	return grade if occupied else GRADE_RISE

static func grade_rank(grade: String) -> int:
	return 1 if grade == GRADE_RISE else 0

## Der lautere von zwei Graden gewinnt: sammeln sich Meldungen an, bis die Bucht
## wirklich stellt, darf die leiseste die lauteste nicht verschlucken.
static func louder_grade(a: String, b: String) -> String:
	return a if grade_rank(a) >= grade_rank(b) else b

## Was körperlich in der Bucht liegt - seit dem Schlitz-Umbau NUR noch die offenen
## Würfel: alles Versiegelte steckt im Tisch. Ausverkauft ist SICHTBAR (der Platz
## bleibt leer), und die bought-Marken halten die Lücken index-treu, damit ein
## Griff immer denselben Kaufweg meint.
func vitrine_stock() -> Dictionary:
	var dice: Array = []
	for i in single_dice.size():
		dice.append(null if single_dice_bought[i] else single_dice[i])
	var parts: Array = []
	for i in part_options.size():
		parts.append(null if part_bought[i] else part_options[i])
	return {KIND_DIE: dice, KIND_PART: parts}

# --- Kauf-Eingänge der Bucht (scene_root meldet den Griff hierher) -------------

func buy_engraving_pack(index: int) -> void:
	_on_pack_buy_pressed(index)

func buy_single_die(index: int) -> void:
	_on_single_die_pressed(index)

## from_px = der Platz in der Bucht, von dem das Licht startet.
func buy_part(index: int, from_px := Vector2(-1, -1)) -> void:
	_on_part_clicked(index, from_px)

func buy_single_special(index: int) -> void:
	_on_single_special_pressed(index)

# --- Blättern ------------------------------------------------------------------

## Gebühr für die nächste NEUE Doppelseite; Wechselgeld-Charm UND eine hohe
## Fortschrittsstufe (TIER_CHEAP_FLIP) senken sie.
func _next_flip_fee() -> int:
	var base := maxi(1, FLIP_FEE_BASE + spreads.size() - 1)
	return maxi(0, roundi(base * run.shop_flip_fee_factor()))

## True, wenn Vorblättern eine neue Doppelseite auswürfeln würde.
func _next_flip_is_new() -> bool:
	return current_spread_index == spreads.size() - 1

func _on_page_next_pressed() -> void:
	if _next_flip_is_new():
		var fee := _next_flip_fee()
		if run.money < fee:
			return  # Knopf ist bei zu wenig Geld ohnehin deaktiviert
		run.add_money(-fee)
		spreads.append(_build_spread())
	current_spread_index += 1
	_show_spread()
	_play_flip_animation()

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
## neue Ware kommt - also erst hinter der ABSORPTION, die vor der Maschine läuft
## (die hat _show_spread eben angestoßen, ihr Vorlauf steht also schon).
func _play_flip_animation() -> void:
	if flip_tween != null and flip_tween.is_valid():
		flip_tween.kill()
	content_root.modulate = Color(1, 1, 1, 0)
	flip_tween = create_tween()
	flip_tween.tween_interval(
		absorb_time(_net_blocks.size() if _net_absorbing else 0) + FLIP_DELAY)
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
	var common_only := run.shop_common_charms_only()
	if common_only:
		available = _common_only(available)
	var rarity_factors := run.shop_charm_rarity_factors()
	var charm_slots := run.shop_charm_slots()
	var rarity_tier := 0 if common_only else run.shop_rarity_tier()
	# Raritäts-Schub: der erste Platz zieht garantiert einen Charm ab der zur Stufe
	# passenden Mindest-Rarität (Tier 1 ungewöhnlich, 2 selten, 3 legendär) - fällt
	# auf die nächst-niedrigere Schwelle zurück, falls keiner verfügbar ist.
	if rarity_tier >= 1 and charm_slots > 0:
		var premium := _charms_at_least(available, rarity_tier)
		if not premium.is_empty():
			var top := Charm.pick_weighted(premium, owned, rarity_factors)
			spread.charm_options.append(top)
			available.erase(top)
	# Restliche Plätze gewichtet nach Rarität und Besitz ziehen, ohne Zurücklegen.
	while spread.charm_options.size() < charm_slots and not available.is_empty():
		var pick := Charm.pick_weighted(available, owned, rarity_factors)
		spread.charm_options.append(pick)
		available.erase(pick)
	spread.charm_bought.resize(spread.charm_options.size())
	spread.charm_bought.fill(false)
	for i in run.shop_part_slots():
		spread.part_options.append(run.roll_shop_part())
	spread.part_bought.resize(spread.part_options.size())
	spread.part_bought.fill(false)

	# PAKETE: Sorte und Größe je Platz; Optionen und Wahlen fallen erst beim Kauf.
	for i in run.shop_packs_offered():
		spread.engraving_packs.append(CardPack.roll_shop())
	spread.engraving_pack_bought.resize(spread.engraving_packs.size())
	spread.engraving_pack_bought.fill(false)

	# Die WÜRFEL-PAKETE der Schale - Einzelwürfel führt der Laden nicht mehr.
	for i in run.shop_dice_slots():
		var dice_pack := DicePack.roll_shop(null, run.shop_dice_pack_quality_weights())
		spread.single_dice.append(dice_pack)
		spread.single_dice_prices.append(_dice_pack_price(dice_pack))
	spread.single_dice_bought.resize(spread.single_dice.size())
	spread.single_dice_bought.fill(false)
	# Leere Regale: die Plätze bleiben, die hinteren stehen leer - wie verkauft.
	for i in range(run.shop_dice_offered(), spread.single_dice.size()):
		spread.single_dice_bought[i] = true

	# Sonderposten ab Stufe SHOP_SPECIAL_TIER: er BELEGT den letzten Paket-Platz, statt
	# einen dazuzustellen - die Reihe bleibt gleich voll, und er kostet einen
	# normalen Wurf.
	if randf() < run.shop_special_chance():
		spread.single_specials.append(Pack.roll_special_pack())
		if not spread.engraving_packs.is_empty():
			spread.engraving_packs.remove_at(spread.engraving_packs.size() - 1)
			spread.engraving_pack_bought.resize(spread.engraving_packs.size())
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

## Nur die gewöhnlichen Charms (Ladenhüter); ein leerer Topf fällt auf den vollen zurück.
func _common_only(pool: Array[Charm]) -> Array[Charm]:
	var out: Array[Charm] = []
	for charm in pool:
		if charm.rarity == Charm.RARITY_COMMON:
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
	_vitrine_grade = grade_for(spread == _standing_spread)
	spread.presented = true
	_standing_spread = spread
	charm_options = spread.charm_options
	charm_bought = spread.charm_bought
	part_options = spread.part_options
	part_bought = spread.part_bought
	engraving_packs = spread.engraving_packs
	engraving_pack_bought = spread.engraving_pack_bought
	single_dice = spread.single_dice
	single_dice_prices = spread.single_dice_prices
	single_dice_bought = spread.single_dice_bought
	single_specials = spread.single_specials
	single_special_bought = spread.single_special_bought
	# Die Plätze bleiben, wo sie sind - nur die GATTUNG des letzten hängt daran,
	# ob diese Auslage einen Sonderposten führt. Kein Neuaufbau, keine Rechtecke.
	_slit_seats = slit_seats()

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
	charm_thumbs.clear()
	charm_stages.clear()
	charm_effects.clear()

## Baut das CHARM-Regal der Seite: Titel und drei Plätze, je Platz eine Karte
## mittig. Die Karte füllt das feste Band - schrumpfen darf die Karte, das Band nie.
func _rebuild_content(spread: MenuSpread) -> void:
	_clear_pages()

	content_root.add_child(_heading_row("CHARMS"))
	var charm_row := _shelf_row("CharmShelf", _charm_card_height())
	content_root.add_child(charm_row)
	var cm := _charm_metrics()
	var card_w := _charm_card_width()
	var name_px := card_name_px()
	var podest_index := 0 if run.shop_rarity_tier() >= 1 else -1
	var places := charm_row.get_children()
	for i in mini(spread.charm_options.size(), places.size()):
		var podest := i == podest_index
		places[i].add_child(_build_charm_card(spread.charm_options[i], i, cm.x, int(cm.y),
			card_w, name_px, podest))

## Signaturfarbe der aktuellen Fortschrittsstufe (wie der Hub-Rahmen); der Laden
## trägt sie dezent auf seinen Säumen.
func _tier_color() -> Color:
	if run == null:
		return Color.WHITE
	var last := HubView.TIER_COLORS.size() - 1
	return HubView.TIER_COLORS[clampi(run.progress_tier() - 1, 0, last)]

## Akzentfarbe leicht zur Stufenfarbe ziehen (Zusammenhalt ohne die Rubrik-Farbe
## zu verfälschen).
func _tinted(accent: Color) -> Color:
	return accent.lerp(_tier_color(), 0.15)

# --- Maße der Charm-Karte ------------------------------------------------------

const ZONE_SEPARATION := 1.2
const HEADING_FONT := 2.2
const CARD_MARGIN := 0.7
const CARD_SEPARATION := 0.3
const CARD_PRICE_FONT := 2.0
## Name und Wirkung tragen auf JEDER Karte denselben Grad (Spieler-Wunsch
## 2026-10-29): gewählt wird der größte, in dem der GANZE Katalog paßt - der
## Name einzeilig, die Wirkung umgebrochen in die Mittelfläche.
const CARD_NAME_STEPS := [2.8, 2.6, 2.4, 2.2, 2.0, 1.8, 1.6, 1.4]
const CARD_EFFECT_STEPS := [2.4, 2.2, 2.0, 1.85, 1.7, 1.55, 1.4, 1.3, 1.2, 1.1, 1.0, 0.9]
## Seitenrand der Seite (Margin) - die Plätze messen sich daran.
const PAGE_MARGIN := 3.0

## Das Preisschild AN der Ware: klein - kleiner als der Karten-Preis der Charms,
## damit die Hierarchie Charm-Karte > Ware bleibt.
const WARE_PRICE_FONT := 1.7
const WARE_PRICE_GAP := 0.6
## Die Namens-Zeile unter einem Würfel: eine Spur kleiner als der Preis.
const WARE_SOUL_FONT := 1.6
## Ab welcher Helligkeit ein Essenz-Glühen als Schriftfarbe taugt, und wie weit
## ein dunkleres zum Weiß gezogen wird (Vakuum glüht schwarz).
const SOUL_MIN_LUMINANCE := 0.45
const SOUL_LIFT := 0.6
## Wie breit ein Modell auf seiner Karte höchstens werden darf.
const THUMB_WIDTH_SHARE := 0.62
## Und der Boden, unter den es nicht fällt - kleiner liest es als Fleck.
const THUMB_MIN := 3.2

## Charm-Karte: (Kartenhöhe, Modell-Kantenlänge). Die HÖHE ist fest - das Band
## minus Titel; elastisch bleibt allein das Modell.
func _charm_metrics() -> Vector2:
	var thumb := minf(card_mid_height(), _charm_card_width() * THUMB_WIDTH_SHARE)
	return Vector2(_charm_card_height(), maxf(thumb, u * THUMB_MIN))

func _heading_height() -> float:
	var font := ThemeDB.fallback_font
	if font == null:
		return u * HEADING_FONT * 1.4
	return font.get_height(maxi(8, int(u * HEADING_FONT)))

## Die feste Kartenhöhe: das Band minus Titel und Fuge.
func _charm_card_height() -> float:
	return maxf(u * BAND_CHARM_UNITS - _heading_height() - u * ZONE_SEPARATION, u * 6.0)

## Die MITTELFLÄCHE einer Charm-Karte in Pixeln: die Karte minus Rand, Name und
## Preis. Sie ist FEST - im Ruhezustand steht das Modell darin, beim Hover der
## volle Wirkungstext an SEINER Stelle; die Karte reflowt dabei kein Pixel.
func card_mid_height() -> float:
	var font := ThemeDB.fallback_font
	if font == null:
		return maxf(_charm_card_height() * 0.5, u * THUMB_MIN)
	var price := font.get_height(maxi(8, int(u * CARD_PRICE_FONT)))
	var name_h := font.get_height(card_name_px())
	return maxf(_charm_card_height() - u * CARD_MARGIN * 2.0 - price - name_h \
		- u * CARD_SEPARATION * 2.0, u * THUMB_MIN)

## Die Breite EINER Karte: sie füllt ihren Platz - die Luft zwischen den Karten
## ist allein die Spaltenfuge.
func _charm_card_width() -> float:
	return column_width()

func _card_text_width() -> float:
	return _charm_card_width() - u * CARD_MARGIN * 2.0

## Namen und Wirkungen des ganzen Katalogs, EINMAL gebaut (Charm.all baut jede
## Instanz neu).
static var _catalog_names: Array[String] = []
static var _catalog_texts: Array[String] = []

static func _charm_catalog() -> void:
	if not _catalog_names.is_empty():
		return
	for charm in Charm.all():
		_catalog_names.append(charm.display_name)
		_catalog_texts.append(charm.description)

## Der EINE Namens-Grad aller Karten: jeder Katalog-Name einzeilig.
func card_name_px() -> int:
	_charm_catalog()
	return _row_font(_catalog_names, _card_text_width(), CARD_NAME_STEPS)

## Der EINE Wirkungs-Grad aller Karten: jede Katalog-Beschreibung umgebrochen in
## die Mittelfläche. Gecacht je Seitenmaß - die Frage kommt bei jedem Aufbau.
var _effect_px_key := Vector2.ZERO
var _effect_px := 0

func card_effect_px() -> int:
	var key := Vector2(_card_text_width(), card_mid_height())
	if key == _effect_px_key and _effect_px > 0:
		return _effect_px
	_charm_catalog()
	var font := ThemeDB.fallback_font
	var px := maxi(8, int(u * float(CARD_EFFECT_STEPS[CARD_EFFECT_STEPS.size() - 1])))
	if font != null:
		for step in CARD_EFFECT_STEPS:
			var try_px := maxi(8, int(u * float(step)))
			var fits := true
			for text in _catalog_texts:
				if WorkshopView.text_block_height(font, text, key.x, try_px, 0) > key.y:
					fits = false
					break
			if fits:
				px = try_px
				break
	_effect_px_key = key
	_effect_px = px
	return px

## Regal-Titel: Akzent-Raute, gesperrter Titel, auslaufende Lichtschiene - für
## alle drei Regale derselbe Stil.
func _heading_row(text: String) -> Control:
	var accent := _tinted(NEON_CYAN)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 1.2))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(CasinoStyle.label("◆", u * HEADING_FONT * 0.85, accent))
	row.add_child(CasinoStyle.label(_spaced(text), u * HEADING_FONT,
		Color(accent.r * 1.3, accent.g * 1.3, accent.b * 1.3)))
	var rail := CasinoStyle.rail(accent, u)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rail)
	return row

## Gesperrte Schrift ("CHARMS" -> "C H A R M S") - Premium-Look der Zonen-Titel.
func _spaced(text: String) -> String:
	var chars := PackedStringArray()
	for i in text.length():
		chars.append(text[i])
	return " ".join(chars)

## Charm-Karte: oben der NAME, in der Mitte das MODELL, unten der PREIS - und beim
## Hover tritt an die Stelle des Modells die volle Wirkung. Rahmen und Lichtfleck
## tragen die Charm-Rarität (weiß/grün/blau/violett). card_h, thumb_px und card_w
## kommen aus _charm_metrics/_charm_card_width; podest = garantierter Premium-Charm
## (Rarität freigeschaltet): breiter, stärkerer Lichtfleck, dickerer Saum.
func _build_charm_card(charm: Charm, index: int, card_h: float, thumb_px: int,
		card_w: float, name_px: int, podest := false) -> Control:
	var bought := charm_bought[index]
	# Voller Dock steht wie "gekauft" da: der Platz ist zu, egal was er kostet.
	var full := run.charms_full()
	var tint := charm.rarity_color()
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Alle Karten sind gleich groß und füllen ihren Platz; das Podest trägt nur den
	# stärkeren Saum und Lichtfleck.
	var width := card_w
	card.custom_minimum_size = Vector2(width, card_h)
	_center_in_place(card, width, card_h)
	var seam_alpha := 0.9 if podest else 0.65
	card.add_theme_stylebox_override("normal", _charm_card_box(Color("#1d1840cc"), tint, seam_alpha, 0.32 if podest else 0.22))
	card.add_theme_stylebox_override("hover", _charm_card_box(Color("#2a2158dd"), NEON_GOLD, 0.9, 0.3))
	card.add_theme_stylebox_override("pressed", _charm_card_box(Color("#352a68"), NEON_GOLD, 1.0, 0.3))
	card.add_theme_stylebox_override("disabled", _charm_card_box(Color("#16133466"), tint, 0.18, 0.0))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(u * CARD_SEPARATION))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	# Der NAME steht oben - eine Ware ohne Namen ist keine Ware.
	var text_width := width - u * CARD_MARGIN * 2.0
	column.add_child(_card_line(charm.display_name, name_px,
		NEON_MUTED if bought else NEON_TEXT))

	# Die MITTELFLÄCHE: eine feste Fläche, kein Container - beide Kinder liegen
	# deckungsgleich darin, also kostet der Tausch keinen Umbruch.
	var mid_h := card_mid_height()
	var mid := Control.new()
	mid.custom_minimum_size = Vector2(text_width, mid_h)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(mid)

	# Ruhezustand: das Modell im Lichtfleck. Der Fleck QUILLT über das Modell
	# hinaus, zählt aber nicht zur Mindesthöhe - sonst schöbe sein Rand den Preis
	# aus der Karte.
	var glow := tint if not bought else Color(tint.r, tint.g, tint.b, 0.3)
	var disc_side := thumb_px * (1.32 if podest else 1.18)
	var stage := CenterContainer.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var halo := Control.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.custom_minimum_size = Vector2(thumb_px, thumb_px)
	halo.size = halo.custom_minimum_size
	var disc := CasinoStyle.glow_disc(glow, disc_side)
	disc.position = Vector2.ONE * ((thumb_px - disc_side) * 0.5)
	disc.size = Vector2.ONE * disc_side
	halo.add_child(disc)
	var thumb := CharmThumb.new(charm, thumb_px)
	thumb.size = Vector2(thumb_px, thumb_px)
	halo.add_child(thumb)
	stage.add_child(halo)
	charm_thumbs.append(thumb)
	mid.add_child(stage)

	# Hover: an SEINER Stelle die volle Wirkung - ungekürzt, umbrechend, im EINEN
	# Grad aller Karten. Auch eine gekaufte oder gesperrte Karte tauscht: der Text
	# ist dann erst recht die einzige Auskunft.
	var effect := _card_effect(charm.description, text_width, mid_h, card_effect_px(),
		NEON_MUTED, "charm:%s" % charm.id)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.visible = false
	mid.add_child(effect)
	charm_stages.append(stage)
	charm_effects.append(effect)

	var tag := "gekauft" if bought else ("voll" if full else \
		("gratis" if _charm_price(charm) <= 0 else "$%d" % _charm_price(charm)))
	column.add_child(CasinoStyle.label(tag, u * CARD_PRICE_FONT,
		NEON_MUTED if bought or full else Color(1.4, 1.16, 0.14), HORIZONTAL_ALIGNMENT_CENTER))

	# Der Zeiger liegt auf dem Tisch, aber die Bewegung wird in den SubViewport
	# weitergeleitet - der Knopf meldet seinen Hover also selbst. Ein gesperrter
	# Knopf meldet ihn ebenso, seine Auskunft bleibt erreichbar.
	card.mouse_entered.connect(set_charm_hover.bind(index, true))
	card.mouse_exited.connect(_on_charm_card_exited.bind(card, index))

	# Der Handler hängt an JEDER ungekauften Karte: ein voller Dock sperrt sie nur
	# als Startzustand, ein Verkauf gibt sie ohne Neuverdrahtung wieder frei
	# (_on_charm_clicked prüft charms_full ohnehin selbst).
	if not bought:
		card.pressed.connect(_on_charm_clicked.bind(index))
	if bought or full:
		card.disabled = true
	charm_buttons.append(card)
	return card

## Ein Schlüsselwort im Text ist selbst ein Mausziel - der Knopf meldet beim
## Betreten ein Verlassen. Zurück aufs Bild geht es erst, wenn der Zeiger wirklich
## draußen ist, sonst flackert die Karte zwischen Bild und Text.
func _on_charm_card_exited(_card: Control, index: int) -> void:
	if not _pointer_on_card(index):
		set_charm_hover(index, false)

func _pointer_on_card(index: int) -> bool:
	if index < 0 or index >= charm_buttons.size() or not is_instance_valid(charm_buttons[index]):
		return false
	var card := charm_buttons[index]
	return card.is_visible_in_tree() \
		and card.get_global_rect().has_point(card.get_global_mouse_position())

## Der Rückweg aufs Bild, wenn der Knopf ihn verpaßt hat (sein Verlassen fiel
## schon beim Betreten eines Schlüsselworts).
func _process(_delta: float) -> void:
	for i in charm_effects.size():
		var effect := charm_effects[i]
		if is_instance_valid(effect) and effect.visible and not _pointer_on_card(i):
			set_charm_hover(i, false)

## Der TAUSCH auf der Karte: Modell weg, Text her - und zurück. Mehr passiert
## nicht, insbesondere bewegt sich kein Rechteck.
func set_charm_hover(index: int, hovered: bool) -> void:
	if index < 0 or index >= charm_stages.size() or index >= charm_effects.size():
		return
	if not is_instance_valid(charm_stages[index]) or not is_instance_valid(charm_effects[index]):
		return
	charm_stages[index].visible = not hovered
	charm_effects[index].visible = hovered

## Der Grad EINER Zeile für die ganze Kartenreihe: der erste, in dem JEDER Text
## noch einzeilig in die Karte paßt - sonst der kleinste. Karten nebeneinander,
## jede in ihrem eigenen Grad, lasen sich als Flickenteppich.
func _row_font(texts: Array[String], width: float, steps: Array) -> int:
	var font := ThemeDB.fallback_font
	var smallest := maxi(8, int(u * float(steps[steps.size() - 1])))
	if font == null:
		return smallest
	for step in steps:
		var px := maxi(8, int(u * float(step)))
		var fits := true
		for text in texts:
			if font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, px).x > width:
				fits = false
				break
		if fits:
			return px
	return smallest

## Eine einzeilige Kartenzeile im gesetzten Grad (der Name) - sie wird notfalls
## beschnitten, denn ein Name bricht nicht um.
func _card_line(text: String, px: int, color: Color) -> Label:
	var label := CasinoStyle.label(text, float(px), color, HORIZONTAL_ALIGNMENT_CENTER)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

## Der WIRKUNGSTEXT der Karte: umbrechend, mittig in der Mittelfläche. Er trägt
## die ganze Beschreibung - das ist die Auskunft, für die es früher einen Schirm
## gab, und beim Hover steht sie an der Stelle des Modells.
## Die EINE Hover-Karte der Schlüsselwörter, ganz vorn im Baum - das letzte Kind
## bleibt der jüngste Seitenaufbau, z_index hebt sie trotzdem nach oben.
var _keyword_hint: HintCard

func _keyword_hint_card(px: int) -> HintCard:
	if _keyword_hint == null or not is_instance_valid(_keyword_hint) \
			or _keyword_hint.is_queued_for_deletion():
		_keyword_hint = HintCard.new(maxf(2.0, px / 2.5))
		_keyword_hint.z_index = 10
		add_child(_keyword_hint)
		move_child(_keyword_hint, 0)
	return _keyword_hint

func _card_effect(text: String, width: float, block: float, px: int, color: Color,
		own := "") -> LexikonText:
	var label := LexikonText.new()
	label.center_h = true
	label.center_v = true
	label.custom_minimum_size = Vector2(width, block)
	label.set_style(px, color)
	label.set_source(text, own)
	label.share_hint(self, _keyword_hint_card(px))
	label.entry_requested.connect(func(id: String) -> void: lexikon_requested.emit(id))
	return label

## Kartenrahmen im Raritäts-Tint: Saum + weicher Außen-Glow (StyleBox-Schatten).
func _charm_card_box(fill: Color, border: Color, border_alpha: float, glow_alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color(border.r, border.g, border.b, border_alpha)
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(int(u * 1.2))
	box.set_content_margin_all(int(u * CARD_MARGIN))
	if glow_alpha > 0.0:
		box.shadow_color = Color(border.r, border.g, border.b, glow_alpha)
		box.shadow_size = int(u * 0.9)
	return box

## Kauf der Sonder-Karte: sie geht VERSIEGELT ins Magazin wie früher jede Einzelkarte,
## samt Kleingedrucktem und Lieferkomet.
func _on_single_special_pressed(index: int) -> void:
	if index < 0 or index >= single_specials.size() or single_special_bought[index] \
			or _choice_open():
		return
	var pack: Pack = single_specials[index]
	var price := _pack_price(pack)
	if run.money < price or run.packs_full():
		return
	var from_px := _buy_origin_px(KIND_SPECIAL, index)
	var refunded := run.purchase_pack(pack, price)
	single_special_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	pack_purchased.emit(from_px, pack.pack_uid)
	if refunded > 0:
		pack_refunded.emit(from_px, refunded)
	_show_spread()

## Kauf eines WÜRFEL-PAKETS: gebucht wird Preis UND Auswahl (Optionen, Wahlen) - die
## Grube zeigt sie danach.
func _on_single_die_pressed(index: int) -> void:
	if index < 0 or index >= single_dice.size() or single_dice_bought[index] \
			or _choice_open() or run.money < single_dice_prices[index]:
		return
	var from_px := _buy_origin_px(KIND_DIE, index)
	run.purchase_dice_pack(single_dice[index], single_dice_prices[index])
	single_dice_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	dice_pack_purchased.emit(index)
	if run.last_card_pack_refund > 0:
		pack_refunded.emit(from_px, run.last_card_pack_refund)
	_show_spread()

## Steht noch eine Paket-Auswahl offen? Dann kauft der Laden nichts - eines nach
## dem anderen.
func _choice_open() -> bool:
	return run != null and run.current_pack_choice() != null

# --- Neon-Bausteine --------------------------------------------------------------

# --- Die Preiszeile ------------------------------------------------------------

## Preiszeile und ihre Farbe - reine Funktionen, damit die Entscheidung
## "bezahlbar oder nicht" prüfbar ist und nur an EINER Stelle fällt.
static func price_text(price: int) -> String:
	return "$%d" % price

static func price_tint(price: int, money: int) -> Color:
	return NEON_GOLD if money >= price else CasinoStyle.RED

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
	return CasinoStyle.flat_box(bg, border, u * 0.22, u * 0.9, u * 0.8)

# --- Käufe ----------------------------------------------------------------------

## Jedes Paket trägt seinen Tabellenpreis; der Schnäppchenjäger zieht davon ab,
## danach Inflation/Skonto des Hauses. Auch die einzelne Sonder-Karte geht hier durch.
func _pack_price(pack: Resource) -> int:
	return run.shop_price(CharmEffects.pack_price(int(pack.get("price")), "", run.charm_ids()))

## Das Würfel-Paket: Schnäppchenjäger, dann die Würfel-Rabatte (Trickdieb, Mengenrabatt).
func _dice_pack_price(dice_pack: DicePack) -> int:
	var ids := run.charm_ids()
	return run.shop_price(CharmEffects.die_price(
		CharmEffects.pack_price(dice_pack.price, "", ids), ids))

## Der Hausgutschein schenkt den ERSTEN Charm des Blocks - danach zählt
## wieder der normale Preis samt Inflation/Skonto.
func _charm_price(charm: Charm) -> int:
	if run.charm_is_free():
		return 0
	return run.shop_price(CharmEffects.charm_price(charm.price, run.charm_ids()))

## Kauft ein Karten-Paket (je Angebot einmal): gebucht sind Preis und Auswahl, die
## Grube zeigt sie. Danach wird die Doppelseite neu bebaut.
func _on_pack_buy_pressed(index: int) -> void:
	if index < 0 or index >= engraving_packs.size() or engraving_pack_bought[index] \
			or _choice_open():
		return
	if _buy_card_pack(engraving_packs[index], KIND_ENGRAVING_PACK, index):
		engraving_pack_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
		_show_spread()

## Der Karten-Paket-Kauf: GameRun bucht Preis, Optionen und Wahlen; die Erstattung
## meldet ihr Licht. false = nicht bezahlbar.
func _buy_card_pack(pack: CardPack, kind: String, index: int) -> bool:
	var price := _pack_price(pack)
	if run.money < price:
		return false
	var from_px := _buy_origin_px(kind, index)
	run.purchase_card_pack(pack, price)
	if run.last_card_pack_refund > 0:
		pack_refunded.emit(from_px, run.last_card_pack_refund)
	return true

## Startpunkt eines Kauf-Kometen: ein versiegeltes Stück fährt aus SEINEM Schlitz
## los, offene Ware aus der Bucht.
func _buy_origin_px(kind: String, index: int) -> Vector2:
	var seat := _seat_of(kind, index)
	if seat >= 0 and seat < _slit_pads.size() and is_instance_valid(_slit_pads[seat]):
		return _slit_pads[seat].get_global_rect().get_center()
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
	run.purchase_charm(charm, _charm_price(charm))
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
		if not charm_bought[i] and i < charm_options.size():
			charm_buttons[i].disabled = run.charms_full() or money < _charm_price(charm_options[i])
	if page_back_button != null and is_instance_valid(page_back_button):
		page_back_button.disabled = current_spread_index == 0
	if page_next_button != null and is_instance_valid(page_next_button):
		if _next_flip_is_new():
			page_next_button.text = "$%d ›" % _next_flip_fee()
			page_next_button.disabled = money < _next_flip_fee()
		else:
			page_next_button.text = "›"
			page_next_button.disabled = false
	_refresh_ware_prices()

## Die Preisschilder AN der Ware - Kassette wie Würfel. Sie rechnen nichts nach:
## der Preis kommt aus derselben Quelle wie der Kauf (_pack_price bzw.
## single_dice_prices), gefärbt wird er von price_tint. Idempotent, und am
## Geldstand hängt er über _refresh_afford_state.
func _refresh_ware_prices() -> void:
	var money: int = run.money if run != null else 0
	for seat in mini(_slit_prices.size(), _slit_seats.size()):
		var tag := _slit_prices[seat]
		if tag == null or not is_instance_valid(tag):
			continue
		var pack: Resource = null
		if run != null:
			pack = _slit_pack(_slit_seats[seat])
		if pack == null:
			tag.text = ""  # leerer Platz: kein Schild
			continue
		# Ein volles Magazin steht DORT, wo der Preis stünde - dieselbe Grammatik
		# wie am Sitz des Hinterzimmers.
		if run != null and run.packs_full():
			tag.text = FULL_MARK
			tag.modulate = CasinoStyle.RED
			continue
		var price := _pack_price(pack)
		tag.text = price_text(price)
		tag.modulate = price_tint(price, money)
	for i in mini(_net_prices.size(), _net_dice.size()):
		var mark := _net_prices[i]
		if mark == null or not is_instance_valid(mark):
			continue
		if _net_dice[i] is ComboPart:
			_paint_part_tag(mark, part_options.find(_net_dice[i]))
			continue
		var price := _shown_die_price(_net_dice[i])
		if price < 0:
			mark.text = ""
			continue
		mark.text = price_text(price)
		mark.modulate = price_tint(price, money)

## Steckplätze belegt oder Teil wartend: die VOLL-Marke des Modul-Platzes zieht nach.
func _on_run_parts_changed(_key = "") -> void:
	if _live():
		_refresh_ware_prices()

func _on_run_money_changed(_money: int) -> void:
	if _live():
		_refresh_afford_state()

## Eine Seite, die noch steht, weil der Abgang läuft, zieht NICHTS mehr nach: sie
## ist ein Standbild, kein Laden.
func _live() -> bool:
	return visible and not _leaving

## Das Magazin hat sich geändert - die Preisschilder der Kassetten tragen die
## VOLL-Marke, sie müssen also nachziehen.
func _on_run_packs_changed() -> void:
	if _live():
		_refresh_ware_prices()

## Der Dock hat sich geändert (Kauf ODER Verkauf): der "voll"-Tag steckt in der
## Karte, die Auslage muss also neu gebaut werden. DEFERRED, weil
## ein Kauf-Klick charms_changed synchron feuert, bevor er seine charm_bought-
## Marke setzt - sonst bekäme der Neuaufbau den alten Stand.
func _on_run_charms_changed() -> void:
	if not _live() or spreads.is_empty() or _charm_rebuild_queued:
		return
	_charm_rebuild_queued = true
	_rebuild_after_charms_changed.call_deferred()

func _rebuild_after_charms_changed() -> void:
	_charm_rebuild_queued = false
	if _live() and not spreads.is_empty():
		_show_spread()

func _on_done_pressed() -> void:
	close()

## Laden zu - per "Fertig" oder weil der Spieler die Runde in der Grube aufnimmt.
## Die SEITE bleibt dabei STEHEN: auf IHR spielt die Abräum-Zeremonie der Auslage,
## und Ware, die auf der Roadmap versänke, stünde am falschen Ort. Die SPIEL-Logik
## wartet darauf nicht - closed feuert sofort, Runde und Kamera laufen wie immer -,
## nur die FLÄCHE gibt der Laden erst in finish_close() ab. Bis dahin ist er INERT.
func close() -> void:
	if _leaving or _suspended:
		return  # ein Laden schließt nur einmal - und ein abgetretener gar nicht
	_leaving = true
	closed.emit()

## Die Fläche wirklich abgeben: nach dem Abgang oder bei jedem Abbruch. Erst hier
## sterben die 3D-Vorschauen - bis dahin steht die Seite und zeigt sie.
func finish_close() -> void:
	if not _leaving:
		return
	_leaving = false
	_clear_pages()  # 3D-Vorschauen freigeben (kein Hintergrund-Rendern)
	visible = false

## Der Laden TRITT AB für eine Paket-Öffnung im Hub: derselbe Abgang wie close()
## (die Seite steht, bis die Auslage geschluckt ist), aber OHNE closed - die Runde
## rückt nicht vor, und reopen() bringt ihn unverändert zurück.
func suspend() -> void:
	if _leaving or _suspended or not visible:
		return
	_suspended = true
	_leaving = true

func suspended() -> bool:
	return _suspended

## Die Öffnung ist ohne Rückkehr zu Ende (die Runde ist weiter): kein Laden mehr da.
func cancel_suspend() -> void:
	_suspended = false
	finish_close()

## Räumt der Laden gerade ab? Dann steht seine Seite noch, ist aber tot - kein Kauf
## aus einem schließenden Laden.
func leaving() -> bool:
	return _leaving

# --- Der MODUL-Platz der Würfel-Bucht ----------------------------------------

func part_price(index: int) -> int:
	if run == null or index < 0 or index >= part_options.size():
		return 0
	return run.part_shop_price(part_options[index])

## Die Preiszeile des Modul-Platzes: gekauft, voll oder der Preis.
func part_tag(index: int) -> String:
	if index < 0 or index >= part_bought.size():
		return ""
	if part_bought[index]:
		return "gekauft"
	if run != null and not run.parts_room():
		return PARTS_FULL_TAG
	return price_text(part_price(index))

## Ist der Modul-Platz gerade kaufbar? Sonst steht sein Schild rot.
func part_buyable(index: int) -> bool:
	if run == null or index < 0 or index >= part_options.size() or part_bought[index]:
		return false
	return run.parts_room() and run.money >= part_price(index)

func _paint_part_tag(tag: Label, index: int) -> void:
	tag.text = part_tag(index)
	tag.modulate = NEON_GOLD if part_buyable(index) else CasinoStyle.RED

## Kauf: gebucht in pending_parts, dann fliegt das Licht; der Einbau folgt modal.
func _on_part_clicked(index: int, from_px := Vector2(-1, -1)) -> void:
	if index < 0 or index >= part_options.size() or part_bought[index]:
		return
	if from_px.x < 0.0:
		var bay := vitrine_rect_px()
		from_px = bay.get_center() if bay.size.x > 0.0 else get_global_rect().get_center()
	if not run.purchase_part(part_options[index], part_price(index)):
		return
	part_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	part_purchased.emit(from_px)
	_show_spread()
