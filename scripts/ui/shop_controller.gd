class_name ShopController
extends Control
## Der Shop zwischen den Runden - ein Neon-Panel auf der Hub-Fläche des
## Tisch-Displays, bedient über die Maus-Weiterleitung. Die Seite liest sich von
## oben nach unten als vier Bänder mit FESTEN Anteilen: CHARM-ZEILE (digitale
## Ware, die als Karte bleibt), das Info-Band (links der
## HINWEIS-SCHIRM - die EINE Anzeige, auf der jede Auskunft des Ladens steht -,
## rechts die KASSETTEN-PLÄTZE, auf denen die versiegelte Ware LIEGT), darunter
## die VITRINE mit den offenen Würfeln und zuletzt der Fuß. Kein Band wächst mit
## Lizenzstufe oder Bestand. Körper zeichnet dieser Laden nie selbst; er MELDET
## Rechtecke und Inhalte nach oben (vitrine_rect_px/vitrine_stock,
## slit_anchors/slit_stock), aufgestellt wird alles von scene_root.
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

## Die zwei ANKUNFTS-GRADE der Auslage: STEIGEN heißt, dass Ware durch die Fläche
## kommt, LIEGENBLEIBEN heißt, dass gar nichts geschehen ist - das sichtbar
## gemachte Versprechen der Sortiment-Sperre. Der Laden ENTSCHEIDET nur; gefahren
## wird in der Auslage.
const GRADE_STAND := "stand"
const GRADE_RISE := "rise"

## Was auf der Beschriftung statt des Preises steht, wenn das Lager zu ist.
const FULL_TAG := "MAGAZIN VOLL"
## Und wenn der Charm-Dock zu ist.
const DOCK_TAG := "DOCK VOLL"

## Die drei Sprecher des Hinweis-Schirms. Jeder nimmt nur seinen EIGENEN Text
## zurück: die Bucht fragt je Bild, die Karten melden - ohne das Kürzel löschte
## die eine Quelle, was die andere eben geschrieben hat.
const INFO_CHARM := "charm"
const INFO_SLIT := "slit"
const INFO_BAY := "bay"
## Die Netze unter der Ware sind der SPEZIFISCHERE Sprecher der Bucht: was sie
## sagen, schlägt die Grundzeile des Würfels darüber.
const INFO_NETS := "nets"
## Und die gesperrten Blätter-Pfeile: eine gesperrte Funktion erklärt sich auf dem
## Schirm, nicht in einem Satz im Fuß.
const INFO_PAGER := "pager"

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
const VITRINE_MIN_HEIGHT := 18.0

## FESTE PROPORTIONEN: die vier Bänder der Seite (Charm-Zeile, Info-Band,
## Bucht, Fuß) stehen in u, unabhängig von Lizenzstufe und Bestand. Was in ein
## Band nicht paßt, schrumpft - das Band selbst nie. Die Bucht ist das einzige
## Band mit EXPAND_FILL: sie bekommt, was die anderen übriglassen.
const BAND_CHARM_UNITS := 26.0
## Der Fuß trägt die höchsten Knöpfe der Seite (gemessen: die Blätter-Pfeile mit
## ihrem Grad 3,2 u brauchen 5,9 u) - die Zahl steht bewußt darüber, sonst
## bestimmte die Lizenzstufe über ihre Knöpfe die Bandhöhe.
const BAND_FOOTER_UNITS := 6.2

## Der Fuß trägt eine HIERARCHIE: das gefüllte Fertig, darunter der Aufstiegs-KAUF
## mit gedimmtem Saum, und ganz unten die Blätter-Pfeile. Der Aufstieg leiht sich
## das Gold nur halb - gefüllt ist auf dieser Seite genau ein Knopf.
const HUB_BUTTON_ACCENT := Color(NEON_GOLD.r, NEON_GOLD.g, NEON_GOLD.b, 0.5)
## Das Schloss auf einem gesperrten Blätter-Pfeil - dasselbe Zeichen wie an der
## Sortiment-Sperre.
const PAGER_LOCK := "🔒"
## Was der Schirm sagt, wenn der Zeiger auf einem gesperrten Pfeil liegt.
const PAGER_LOCK_TITLE := "Blättern"
const PAGER_LOCK_BODY := "Blättern ab Hub-Stufe 2."

## Der STELLPLATZ eines Kassetten-Schlitzes: die Ware LIEGT dort flach auf der
## Fläche, gemessen wird also ihr liegender Grundriß (Breite × Höhe der Karte)
## im EINEN Anzeigemaß (PackDrawerView.CASSETTE_SCALE), plus Stellluft. Die
## u-Maße sind nur ihr Boden, solange kein Grundriß gemeldet ist.
const SLIT_ROOM := 1.12
const SLIT_MIN_WIDTH := 5.4
const SLIT_MIN_HEIGHT := 8.0
## Sitzhöhe eines Platzes und die Luft zwischen zwei Stellplätzen. Vier liegende
## Karten samt Fugen müssen ins Drittel - die Fuge ist deshalb schmal.
const SLIT_SEAT_HEIGHT := 4.2
const SLIT_GAP := 1.2

## Der HINWEIS-SCHIRM: feste Höhe, fester Platz - er STEHT dunkel und leer, bis
## der Zeiger etwas findet. Text auf blankem Grund wäre Text im Nichts.
## Die Höhe ist knapp bemessen: der Schirm trägt die längste Auskunft des Ladens,
## aber die Schriftgrade walken sich ohnehin ein - was er nicht braucht, gehört
## der Charm-Zeile, die jetzt Modelle über ihren Karten trägt.
const INFO_HEIGHT := 16.0
const INFO_PAD := 1.0
const INFO_LINE_GAP := 0.4
const INFO_TITLE := 2.6
const INFO_BODY := 1.9
const INFO_PRICE := 2.2
## Höchster Anteil des Schirms, den die Kennung belegen darf - die Wirkung
## darunter braucht den Rest.
const INFO_TITLE_SHARE := 0.4
## Schriftgrade, von voll abwärts: genommen wird der erste, dessen Umbruch noch
## in den Schirm paßt (die Grammatik des Werkbank-Schirms).
const INFO_TITLE_STEPS := [2.6, 2.25, 1.95, 1.7, 1.45, 1.25]
const INFO_BODY_STEPS := [1.9, 1.68, 1.48, 1.3, 1.15, 1.0, 0.88, 0.78]

## Der Schirm im LEERLAUF: das größte Element der Seitenmitte darf nicht das Auge
## auf nichts ziehen. Ohne Inhalt verliert er seinen hellen Rahmen - dunkel, Saum
## stark gedimmt, aber NIE weg: das Fixture bleibt ablesbar. Der Wechsel wartet
## eine kurze Gnadenfrist ab, damit ein Hover-Wackler ihn nicht flackern läßt;
## aufgehellt wird sofort.
const INFO_IDLE_GRACE := 0.3
const INFO_IDLE_FADE := 0.22
const INFO_IDLE_BG := Color("#0d0b20aa")
const INFO_IDLE_BORDER_ALPHA := 0.2
## Die Leerlaufzeile: eine Gebrauchszeile, klein und weit unter den Inhaltsfarben -
## sie darf aus zwei Metern Nichtssagen bestehen, nie mit Auskunft verwechselbar.
const INFO_IDLE_TEXT := "Zeige auf eine Ware."
const INFO_IDLE_FONT := 1.8
const INFO_IDLE_COLOR := Color(0.66, 0.7, 0.85, 0.42)

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
## Die VITRINE: hier malt der Laden NICHTS als die FASSUNG. Auf diesem Rechteck
## steht die echte Auslage - der Laden meldet es nur nach oben
## (apron_bottom-Muster), aufgestellt wird sie von scene_root.
var vitrine_slot: Control
## Das FELD der Bucht: der Streifen unter dem Zonentitel. Er ist es, den der Laden
## als Buchten-Rechteck meldet - der Titel wohnt IM Band, nicht in der Auslage.
var vitrine_field: Control
## Der NETZ-Layer der Auslage: unter jedem liegenden Würfel sein Würfelnetz. Reine
## Anzeige, sie fängt keine Maus - gefüllt wird sie von scene_root, das allein die
## Weltposition der Würfel kennt.
var vitrine_nets: Control
var page_label: Label
var done_button: Button
var page_back_button: Button
var page_next_button: Button
## Hub-Aufstieg-Knopf im Shop-Fuß.
var hub_upgrade_button: Button
## Umschalter der Sortiment-Sperre (Shop-Fuß).
var lock_button: Button

## Die KASSETTEN-PLÄTZE unter der Charm-Zeile: der Laden markiert die Stellplätze
## und meldet ihre Mitten, die Zellen stellt scene_root. NACKT - kein
## Anzeigefeld, kein Preisschild: die Kappe trägt Sorte, Zeichen und Größe.
var slit_row: HBoxContainer
var _slit_pads: Array[Panel] = []
## Je Platz sein Preisschild - es steht unter der liegenden Karte und ist leer,
## wo nichts liegt. Der Platz behält es: ein verkaufter Schlitz baut nichts um.
var _slit_prices: Array[Label] = []
## Je Platz {kind, index} - die Zahl hängt an der LIZENZ, nicht an der Auslage.
var _slit_seats: Array[Dictionary] = []

## Der HINWEIS-SCHIRM und wer gerade auf ihm steht.
var info_screen: Panel
var info_title: Label
## RichTextLabel statt Label: die Schlüsselwörter im Text sind Lexikon-Verweise.
var info_body: RichTextLabel
var info_price: Label
## Die Leerlaufzeile hängt FREI im Schirm (nicht in der Textspalte) - sonst
## verschöbe sie die Auskunft, sobald sie ein- oder ausblendet.
var info_idle: Label
var _info_source := ""
## Der NACKTE Wirkungstext - gemessen wird er, nicht sein BBCode.
var _info_body_text := ""
## Der Rahmen des Schirms und wie hell er gerade steht (1 = Inhalt, 0 = Leerlauf).
var _info_box: StyleBoxFlat
var _info_lit := 0.0
## Was zuletzt wirklich gezeichnet wurde (-1 = noch nie) - der Schirm wird je Bild
## gefragt, gemalt wird er nur bei echter Änderung.
var _info_lit_applied := -1.0
var _info_tween: Tween

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
## Unterschrift der stehenden Würfelnetze - gleiche Unterschrift, kein Neuaufbau.
var _net_signature := ""
## Wessen Netz an welcher Stelle des Layers hängt, und in welchem Zellmaß - die
## Hover-Auskunft der Netze fragt beides ab.
var _net_dice: Array[DieDefinition] = []
var _net_views: Array[Control] = []
## Je Netz sein Preisschild darunter - dieselbe Quelle wie der Kauf
## (single_dice_prices), nur klein und an der Ware.
var _net_prices: Array[Label] = []
var _net_cell := 0.0

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
	_kill_info_tween()  # der alte Schirm wird gleich freigegeben
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
	margin.add_theme_constant_override("margin_left", int(u * PAGE_MARGIN))
	margin.add_theme_constant_override("margin_right", int(u * PAGE_MARGIN))
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

	# Bildschirm-Zone: nur noch die Charm-Zeile - Lizenzen sind digitale Ware,
	# alles Körperliche liegt darunter. Ihre Höhe ist FEST: über den Karten
	# schweben die echten Charm-Modelle, und ein Band, das mit der Lizenzstufe
	# wüchse, verschöbe jedes Stück Ware unter sich.
	content_root = VBoxContainer.new()
	content_root.name = "Content"
	content_root.add_theme_constant_override("separation", int(u * 1.6))
	content_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content_root.custom_minimum_size = Vector2(0.0, u * BAND_CHARM_UNITS)
	root.add_child(content_root)

	# EIN Band unter den Karten: links der Schirm (zwei Drittel der Breite),
	# rechts stehen die Kassetten-Schlitze in seinem Drittel - der Schirm war
	# allein zu breit, und die Reihe braucht keine eigene Zeile. Beide stehen
	# UNABHÄNGIG von der Doppelseite - ein Kauf baut sie nicht um.
	var info_band := HBoxContainer.new()
	info_band.name = "InfoBand"
	info_band.add_theme_constant_override("separation", int(u * 1.6))
	root.add_child(info_band)
	info_screen = _build_info_screen()
	info_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_screen.size_flags_stretch_ratio = 2.0
	info_band.add_child(info_screen)
	# Die Reihe steht mittig in ihrem Drittel, unter dem Zonentitel in der
	# Charm-Regal-Grammatik; ihre Stellplätze melden weiter globale Rects, die
	# stehenden Kassetten folgen also von allein.
	var slit_third := VBoxContainer.new()
	slit_third.name = "SlitThird"
	slit_third.add_theme_constant_override("separation", int(u * ZONE_SEPARATION))
	slit_third.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slit_third.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slit_third.size_flags_stretch_ratio = 1.0
	slit_third.add_child(_heading_row("GRAVUREN", _tinted(NEON_CYAN), ""))
	var slit_center := CenterContainer.new()
	slit_center.name = "SlitCenter"
	slit_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slit_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slit_row = _build_slit_row()
	slit_center.add_child(slit_row)
	slit_third.add_child(slit_center)
	info_band.add_child(slit_third)

	# Die Bucht bekommt die ganze Resthöhe: sie ist die Auslage, nicht ein Fach
	# darin. Gemalt wird allein die FASSUNG - die Ware steht körperlich darauf.
	# Der Zonentitel wohnt IM Band, über dem gemeldeten Feld: das Band steht fest,
	# nur die Auslage darunter wird um seine Höhe kürzer.
	vitrine_slot = Control.new()
	vitrine_slot.name = "Vitrine"
	vitrine_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitrine_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vitrine_slot.custom_minimum_size = Vector2(0.0, u * VITRINE_MIN_HEIGHT)
	var bay_column := VBoxContainer.new()
	bay_column.name = "BayColumn"
	bay_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bay_column.add_theme_constant_override("separation", int(u * ZONE_SEPARATION))
	bay_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bay_column.add_child(_heading_row("WÜRFEL", _tinted(NEON_GREEN), ""))
	_net_signature = ""  # ein frischer Layer trägt nichts, was schon stünde
	vitrine_field = Control.new()
	vitrine_field.name = "VitrineField"
	vitrine_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitrine_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vitrine_nets = Control.new()
	vitrine_nets.name = "DieNets"
	vitrine_nets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitrine_nets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vitrine_field.add_child(vitrine_nets)
	bay_column.add_child(vitrine_field)
	vitrine_slot.add_child(bay_column)
	root.add_child(vitrine_slot)

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", int(u * 1.5))
	# Auch der Fuß steht fest: auf Stufe 1 stehen dort andere Knöpfe als auf 10.
	footer.custom_minimum_size = Vector2(0.0, u * BAND_FOOTER_UNITS)
	root.add_child(footer)
	page_back_button = _neon_button("‹", NEON_CYAN, u * 3.2, Vector2(u * 7.0, u * 5.0))
	page_back_button.pressed.connect(_on_page_back_pressed)
	page_back_button.mouse_entered.connect(_on_pager_hovered)
	page_back_button.mouse_exited.connect(clear_info.bind(INFO_PAGER))
	footer.add_child(page_back_button)
	page_label = _label("Seite 1", u * 2.8, NEON_MUTED)
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(page_label)
	page_next_button = _neon_button("›", NEON_CYAN, u * 3.2, Vector2(u * 12.0, u * 5.0))
	page_next_button.pressed.connect(_on_page_next_pressed)
	page_next_button.mouse_entered.connect(_on_pager_hovered)
	page_next_button.mouse_exited.connect(clear_info.bind(INFO_PAGER))
	footer.add_child(page_next_button)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_spacer)
	# Hub-Aufstieg direkt im Shop (der Hub-Rahmen ist von der Shop-Seite verdeckt).
	# Er ist ein KAUF, kein Abschluss: Umriss statt Fläche, gedimmter Saum und ein
	# Grad kleiner als das Fertig - seinen Preis färbt die Preis-Grammatik.
	hub_upgrade_button = _neon_button("⬆ Hub", HUB_BUTTON_ACCENT, u * 2.5,
		Vector2(u * 20.0, u * 5.0))
	hub_upgrade_button.pressed.connect(_on_hub_upgrade_pressed)
	footer.add_child(hub_upgrade_button)
	# Fertig ist die primäre Aktion der Seite - und ihr EINZIGER gefüllter Knopf.
	done_button = _neon_button("Fertig", NEON_GOLD, u * 3.0, Vector2(u * 18.0, u * 5.0))
	CasinoStyle.style_primary_button(done_button, NEON_GOLD, u)
	done_button.pressed.connect(_on_done_pressed)
	footer.add_child(done_button)
	_refresh_hub_footer()
	_refresh_lock_button()

# --- Die Kassetten-Schlitze (gemeldete Geometrie, kein Inhalt) -----------------

## Die Plätze der Reihe: die Paket-Plätze der Lizenz, und die ist FLACH - vier,
## auf jeder Stufe. Der Sonderposten BELEGT den letzten davon, er stellt keinen
## dazu; die Zahl der Plätze ändert sich also nie, nur die Gattung des letzten.
## Ein verkaufter oder nie gewürfelter Platz behält seinen Stellplatz, sonst wäre
## jeder Kauf und jedes Blättern ein Umbau.
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

func _build_slit_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SlitRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(u * SLIT_GAP))
	row.custom_minimum_size = Vector2(0.0, u * SLIT_SEAT_HEIGHT)
	_slit_pads.clear()
	_slit_prices.clear()
	_slit_seats = slit_seats()
	for i in _slit_seats.size():
		row.add_child(_slit_seat(i))
	return row

## Ein Hub-Aufstieg mitten im Besuch gibt neue Paket-Plätze - die müssen sichtbar
## werden, das sticht die Rechteck-Treue.
func rebuild_slit_row() -> void:
	if slit_row == null or not is_instance_valid(slit_row):
		return
	for child in slit_row.get_children():
		child.queue_free()
	slit_row.add_theme_constant_override("separation", int(u * SLIT_GAP))
	slit_row.custom_minimum_size = Vector2(0.0, u * SLIT_SEAT_HEIGHT)
	_slit_pads.clear()
	_slit_prices.clear()
	_slit_seats = slit_seats()
	for i in _slit_seats.size():
		slit_row.add_child(_slit_seat(i))
	_refresh_ware_prices()

## Ein Platz: der leere KNOPF fängt Klick und Zeiger, gezeichnet wird allein der
## flache Stellplatz darin - unter einem physischen Ding steht kein Panel.
func _slit_seat(seat: int) -> Button:
	var pad_size := slit_size()
	# Der Platz trägt Stellfläche UND Preisschild - der Schilderplatz bleibt auch
	# leer stehen, sonst wäre jeder Kauf ein Umbau der Reihe.
	var price_height := ThemeDB.fallback_font.get_height(maxi(8, int(u * WARE_PRICE_FONT)))
	var block := pad_size.y + u * WARE_PRICE_GAP + price_height
	var seat_height := maxf(u * SLIT_SEAT_HEIGHT, block)
	var top := (seat_height - block) * 0.5
	var button := Button.new()
	button.name = "SlitSeat"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(pad_size.x, seat_height)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var pad := Panel.new()
	pad.name = "Pad"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.position = Vector2(0.0, top)
	pad.size = pad_size
	pad.add_theme_stylebox_override("panel", _slit_box())
	button.add_child(pad)
	_slit_pads.append(pad)
	var tag := _label("", u * WARE_PRICE_FONT, NEON_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	tag.name = "Price"
	tag.position = Vector2(0.0, top + pad_size.y + u * WARE_PRICE_GAP)
	tag.size = Vector2(pad_size.x, price_height)
	button.add_child(tag)
	_slit_prices.append(tag)
	button.pressed.connect(_on_slit_pressed.bind(seat))
	button.mouse_entered.connect(_on_slit_hovered.bind(seat))
	button.mouse_exited.connect(clear_info.bind(INFO_SLIT))
	return button

## Der Stellplatz ist eine flache Marke im Kartengrundriß - eine Karte liegt
## darauf, sie steckt nicht mehr darin.
func _slit_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#0b0a1ce6")
	box.border_color = Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.3)
	box.set_border_width_all(maxi(1, int(u * 0.18)))
	box.set_corner_radius_all(int(u * 0.8))
	return box

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

func _slit_pack(seat: Dictionary) -> Pack:
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

func _on_slit_hovered(seat: int) -> void:
	if seat < 0 or seat >= _slit_seats.size():
		return
	var entry := _slit_seats[seat]
	if _slit_pack(entry) == null:
		clear_info(INFO_SLIT)
		return
	show_info(INFO_SLIT, vitrine_annotation(String(entry["kind"]), int(entry["index"])))

## Der Platz EINES Angebots (-1 = keiner) - der Kauf-Komet startet dort.
func _seat_of(kind: String, index: int) -> int:
	for i in _slit_seats.size():
		if String(_slit_seats[i]["kind"]) == kind and int(_slit_seats[i]["index"]) == index:
			return i
	return -1

# --- Die Vitrine (gemeldete Geometrie, kein Inhalt) ----------------------------

## Das Buchten-Rechteck in globalen Display-Pixeln (leeres Rect = keine Bucht,
## etwa solange die Seite noch nicht ausgelegt ist).
func vitrine_rect_px() -> Rect2:
	if vitrine_field == null or not is_instance_valid(vitrine_field):
		return Rect2()
	return vitrine_field.get_global_rect()

## Das FELD darin: der Streifen ohne seine gemalte Fassung - dieselbe Rechnung wie
## am Magazin, damit beide Auslagen gleich im Fenster sitzen.
func vitrine_pit_rect() -> Rect2:
	var strip := vitrine_rect_px()
	if strip.size.x <= 0.0 or strip.size.y <= 0.0:
		return Rect2()
	return PackDrawerView.pit_rect_in(strip, u)

## Die WÜRFELNETZE der Auslage stellen: je Eintrag {def, pos} in Pixeln des
## Buchten-Streifens, cell = Zellmaß. Idempotent - dieselbe Auslage baut nichts
## neu. Gefüllt von scene_root, das die Weltposition der Würfel kennt.
func set_die_nets(entries: Array, cell: float) -> void:
	var signature := "%d|%.1f" % [entries.size(), cell]
	for entry in entries:
		var def: DieDefinition = entry["def"]
		var pos: Vector2 = entry["pos"]
		signature += "|%d@%.1f,%.1f" % [def.get_instance_id(), pos.x, pos.y]
	if signature == _net_signature:
		return
	_net_signature = signature
	_drop_die_nets()
	if vitrine_nets == null or not is_instance_valid(vitrine_nets):
		return
	_net_cell = cell
	var span := DieNetView.net_size(cell)
	var price_height := ThemeDB.fallback_font.get_height(maxi(8, int(u * WARE_PRICE_FONT)))
	for entry in entries:
		var def: DieDefinition = entry["def"]
		var net := DieNetView.build(def, VitrineView.die_up_face(), cell)
		net.position = entry["pos"]
		vitrine_nets.add_child(net)
		_net_dice.append(def)
		_net_views.append(net)
		# Das Preisschild hängt UNTER dem Netz - dieselbe Zahl, die der Kauf zahlt.
		var tag := _label("", u * WARE_PRICE_FONT, NEON_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		tag.position = entry["pos"] + Vector2(0.0, span.y + u * WARE_PRICE_GAP)
		tag.size = Vector2(span.x, price_height)
		vitrine_nets.add_child(tag)
		_net_prices.append(tag)
	_refresh_ware_prices()

func clear_die_nets() -> void:
	if _net_signature == "":
		return
	_net_signature = ""
	_drop_die_nets()

## Die Auskunft der NETZE unter der Ware ({} = der Zeiger liegt auf keinem):
## Zelle = ihre Material-/Veredelungs-/Runen-Zeile, Essenz-Ecke = die Seele -
## dieselbe EINE Quelle wie an der Werkbank. Gefragt, nicht gemeldet: der Zeiger
## liegt auf dem Tisch, die Netze bekommen nie ein mouse_entered.
func net_hint_at(pixel: Vector2) -> Dictionary:
	if vitrine_nets == null or not is_instance_valid(vitrine_nets) or _net_cell <= 0.0:
		return {}
	for i in mini(_net_dice.size(), _net_views.size()):
		var net := _net_views[i]
		if net == null or not is_instance_valid(net):
			continue
		var rect := net.get_global_rect()
		if not rect.has_point(pixel):
			continue
		var def: DieDefinition = _net_dice[i]
		var hint := DieNetView.hint_for(def, DieNetView.face_at(pixel - rect.position, _net_cell))
		if hint == "":
			return {}
		return {
			"title": def.display_name,
			"body": hint,
			"price": _shown_die_price(def),
			"money": run.money if run != null else 0,
			"blocked": "",
		}
	return {}

## Der Preis des Würfels, unter dem dieses Netz liegt (-1 = keiner gefunden).
func _shown_die_price(def: DieDefinition) -> int:
	for i in single_dice.size():
		if single_dice[i] == def and i < single_dice_prices.size():
			return single_dice_prices[i]
	return -1

func net_count() -> int:
	if vitrine_nets == null or not is_instance_valid(vitrine_nets):
		return 0
	return vitrine_nets.get_child_count()

func _drop_die_nets() -> void:
	_net_dice.clear()
	_net_views.clear()
	_net_prices.clear()
	_net_cell = 0.0
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
	return {KIND_DIE: dice}

## Die Auskunft EINES Stücks: Titel, Wirkung (die Lexikon-Verweise setzt der
## Schirm selbst) und Preis. Die EINE Inhaltsquelle - Kassette wie Würfel gehen
## hier durch, gezeigt wird beides auf dem Hinweis-Schirm. {} = kein solches Stück.
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
	# Kein Netz in der Auskunft: es LIEGT unter dem Würfel in der Seite - ein
	# Würfel wird nie zweimal gezeigt.
	return {
		"title": title,
		"body": body + tail,
		"price": price,
		"money": run.money,
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

## Fuß-Zeile an die Hub-Stufe anpassen: Blätter-Schloss und Aufstiegs-Knopf.
func _refresh_hub_footer() -> void:
	if run == null or page_back_button == null:
		return
	_refresh_pager_lock()
	if run.hub_level >= GameRun.HUB_MAX_LEVEL:
		hub_upgrade_button.visible = false
	else:
		hub_upgrade_button.visible = true
		var price := run.hub_upgrade_price()
		hub_upgrade_button.text = "⬆ %s ($%d)" % [run.hub_next_level_name(), price]
		hub_upgrade_button.disabled = not run.can_upgrade_hub()
		_tint_hub_price(price)

## Der Aufstieg trägt seinen Preis in der Preis-Grammatik der Seite: gelb, wenn die
## Börse ihn deckt, rot wenn nicht - auch gesperrt, sonst schluckte das Grau die
## Auskunft, die den Knopf überhaupt sperrt.
func _tint_hub_price(price: int) -> void:
	var tint := price_tint(price, run.money)
	hub_upgrade_button.add_theme_color_override("font_color", tint)
	hub_upgrade_button.add_theme_color_override("font_disabled_color",
		Color(tint.r, tint.g, tint.b, 0.75))

## Blättern gesperrt (Hub-Stufe 1): die Pfeile BLEIBEN stehen und tragen ein
## Schloss - erklärt wird die Sperre auf dem Hinweis-Schirm, den es genau dafür
## gibt, nicht in einem Satz im Fuß.
func _refresh_pager_lock() -> void:
	var locked := not run.shop_flipping_unlocked()
	var pagers: Array[Button] = [page_back_button, page_next_button]
	for button in pagers:
		if button == null or not is_instance_valid(button):
			continue
		button.visible = true
		if locked:
			button.text = PAGER_LOCK
			button.disabled = true
			# Gesperrt tragen beide dasselbe Zeichen - dann stehen sie auch gleich
			# breit; die Gebühren-Breite des Vorwärts-Pfeils braucht hier niemand.
			button.custom_minimum_size = Vector2(u * 7.0, u * 5.0)
			button.add_theme_stylebox_override("normal",
				_button_box(Color("#1a183666"), Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.22)))
		else:
			button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), NEON_CYAN))
	if not locked:
		page_back_button.text = "‹"
		page_back_button.custom_minimum_size = Vector2(u * 7.0, u * 5.0)
		page_next_button.text = "›"
		page_next_button.custom_minimum_size = Vector2(u * 12.0, u * 5.0)
		# Ein Aufstieg mitten im Besuch löst die Sperre - ihre Erklärung ist damit tot.
		clear_info(INFO_PAGER)
	page_label.visible = true

## Der Zeiger liegt auf einem Blätter-Pfeil: nur die SPERRE erklärt sich - ein
## offener Pfeil sagt schon mit seinem Preis, was er tut.
func _on_pager_hovered() -> void:
	if run == null or run.shop_flipping_unlocked():
		clear_info(INFO_PAGER)
		return
	show_info(INFO_PAGER, {
		"title": PAGER_LOCK_TITLE,
		"body": PAGER_LOCK_BODY,
		"price": -1,
		"money": 0,
		"blocked": "",
	})

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
	rebuild_slit_row()  # die neuen Paket-Plätze müssen sichtbar werden
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

	# Sonderposten ab der achten Lizenz: er BELEGT den letzten Paket-Platz, statt
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
	# Was eben noch auf dem Schirm stand, ist womöglich gekauft oder weggeblättert.
	clear_info()
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

## Baut die Bildschirm-Zone der Seite: seit dem Vitrinen-Umbau ist das NUR noch
## das Charm-Regal - Pakete, Einzelstücke und das Händler-Regal liegen körperlich
## darunter. Die Karten füllen die Breite UND das feste Band: schrumpfen darf die
## Karte, das Band nie.
func _rebuild_content(spread: MenuSpread) -> void:
	for child in content_root.get_children():
		child.queue_free()
	charm_buttons.clear()
	charm_thumbs.clear()

	var charm_zone := _make_zone(content_root, NEON_MAGENTA, "CHARM-REGAL",
		"je $%d" % _charm_price(), true)
	var charm_row := HBoxContainer.new()
	# Die Karten sind GEDECKELT und die Zeile steht mittig: zwei Angebote stehen
	# kompakt in der Mitte statt als zwei Panoramen.
	charm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	charm_row.add_theme_constant_override("separation", int(u * CARD_GAP))
	charm_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	charm_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	charm_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charm_zone.add_child(charm_row)
	var cm := _charm_metrics(spread.charm_options.size())
	var card_w := _charm_card_width(spread.charm_options.size())
	# Die Schriftgrade der Zeile gelten für die GANZE Seite: Karten nebeneinander,
	# jede in ihrem eigenen Grad, lasen sich als Flickenteppich.
	var text_w := card_w - u * CARD_MARGIN * 2.0
	var names: Array[String] = []
	var effects: Array[String] = []
	for charm in spread.charm_options:
		names.append(charm.display_name)
		effects.append(charm.description)
	var name_px := _row_font(names, text_w, CARD_NAME_STEPS)
	var effect_px := _row_font(effects, text_w, CARD_EFFECT_STEPS)
	var podest_index := 0 if run.shop_rarity_tier() >= 1 else -1
	for i in spread.charm_options.size():
		var podest := i == podest_index
		var ccard := _build_charm_card(spread.charm_options[i], i, cm.x, int(cm.y),
			card_w, name_px, effect_px, podest)
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

## Die Zahlen, aus denen das Charm-Band besteht - EINE Quelle für den Aufbau und
## für die Rechnung, die daraus die Kartengröße ableitet. Sonst driften Möbel und
## Maß auseinander, sobald jemand einen Rand verstellt.
const ZONE_MARGIN := 1.6
const ZONE_SEPARATION := 1.2
const HEADING_FONT := 2.6
const CARD_GAP := 1.4
const CARD_MARGIN := 0.7
const CARD_SEPARATION := 0.3
const CARD_PRICE_FONT := 2.0
## Der NAME steht IMMER auf der Karte - eine Ware ohne Namen ist keine Ware. Er
## walkt sich ein wie jede andere Zeile des Ladens und wird notfalls beschnitten.
const CARD_NAME_STEPS := [2.1, 1.9, 1.7, 1.5, 1.35]
## Die Wirkung darunter ist EINE Zeile: passt sie auch im kleinsten Grad nicht,
## FÄLLT SIE WEG statt umzubrechen - die Karte bleibt ruhig, den vollen Text
## trägt ohnehin der Hinweis-Schirm.
const CARD_EFFECT_STEPS := [1.6, 1.45, 1.3, 1.15, 1.05]
## Breiten-Deckel EINER Karte: zwei Angebote sollen kompakt und mittig stehen
## statt als Panorama. Gemessen an dem, was fünf Karten auf Stufe 10 bekommen.
const CARD_MAX_UNITS := 17.0
## Seitenrand der Seite (Margin) - die Kartenbreite mißt sich daran.
const PAGE_MARGIN := 3.0

## Das Preisschild AN der Ware: klein - kleiner als der Karten-Preis der Charms,
## damit die Hierarchie Charm-Karte > Ware bleibt. Der Schirm sagt den Rest.
const WARE_PRICE_FONT := 1.7
const WARE_PRICE_GAP := 0.6
## Wie breit ein Modell auf seiner Karte höchstens werden darf.
const THUMB_WIDTH_SHARE := 0.62
## Und der Boden, unter den es nicht fällt - kleiner liest es als Fleck.
const THUMB_MIN := 3.2

## Charm-Karte: (Kartenhöhe, Modell-Kantenlänge). Die HÖHE ist fest - sie ist das
## Band minus dem, was Zonenrand und Kopfzeile davon nehmen; elastisch bleibt
## allein das Modell, das mit der Kartenbreite schrumpft. Gemessen, nicht getippt:
## die Kopfzeile fragt ihre Schrifthöhe ab.
func _charm_metrics(count: int) -> Vector2:
	var font := ThemeDB.fallback_font
	var head := font.get_height(maxi(8, int(u * HEADING_FONT)))
	var price := font.get_height(maxi(8, int(u * CARD_PRICE_FONT)))
	# Name und Wirkungszeile sind FEST eingeplant, auch wo die Wirkung wegfällt -
	# sonst stünden auf einer Seite verschieden große Modelle.
	var name_h := font.get_height(maxi(8, int(u * float(CARD_NAME_STEPS[0]))))
	var effect_h := font.get_height(maxi(8, int(u * float(CARD_EFFECT_STEPS[0]))))
	var card_h := u * BAND_CHARM_UNITS - u * ZONE_MARGIN * 2.0 - head - u * ZONE_SEPARATION
	var thumb := card_h - u * CARD_MARGIN * 2.0 - price - name_h - effect_h \
		- u * CARD_SEPARATION * 3.0
	thumb = minf(thumb, _charm_card_width(count) * THUMB_WIDTH_SHARE)
	return Vector2(maxf(card_h, u * 6.0), maxf(thumb, u * THUMB_MIN))

## Die Breite EINER Karte: was die Zeile hergibt, aber höchstens CARD_MAX_UNITS.
## Das Podest zieht mehr Breite (Faktor 1,4), die anderen Karten also weniger -
## gerechnet wird mit dem ungünstigeren Fall.
func _charm_card_width(count: int) -> float:
	var span := size.x - u * PAGE_MARGIN * 2.0 - u * ZONE_MARGIN * 2.0 \
		- u * CARD_GAP * float(maxi(count - 1, 0))
	return minf(span / maxf(float(count) + 0.4, 1.0), u * CARD_MAX_UNITS)

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
	box.set_content_margin_all(int(u * ZONE_MARGIN))
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
	column.add_theme_constant_override("separation", int(u * ZONE_SEPARATION))
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
	row.add_child(_label(_spaced(text), u * HEADING_FONT,
		Color(accent.r * 1.3, accent.g * 1.3, accent.b * 1.3)))
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

## Charm-Karte: Symbol, NAME, eine Wirkungszeile und der Preis. Rahmen und
## Lichtfleck tragen die Charm-Rarität (weiß/grün/blau/violett). card_h, thumb_px
## und card_w kommen aus _charm_metrics/_charm_card_width; podest = garantierter
## Premium-Charm (Rarität freigeschaltet): breiter, stärkerer Lichtfleck, dickerer Saum.
func _build_charm_card(charm: Charm, index: int, card_h: float, thumb_px: int,
		card_w: float, name_px: int, effect_px: int, podest := false) -> Control:
	var bought := charm_bought[index]
	# Voller Dock steht wie "gekauft" da: der Platz ist zu, egal was er kostet.
	var full := run.charms_full()
	var tint := charm.rarity_color()
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Alle Karten sind gleich hoch: das Podest bekommt BREITE, keine Sonderhöhe -
	# eine höhere Karte spränge aus dem festen Band. Die Breite ist GEDECKELT, die
	# Karte dehnt sich also nicht mehr über die halbe Seite.
	var width := card_w * (1.4 if podest else 1.0)
	card.custom_minimum_size = Vector2(width, card_h)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var seam_alpha := 0.9 if podest else 0.65
	card.add_theme_stylebox_override("normal", _charm_card_box(Color("#1d1840cc"), tint, seam_alpha, 0.32 if podest else 0.22))
	card.add_theme_stylebox_override("hover", _charm_card_box(Color("#2a2158dd"), NEON_GOLD, 0.9, 0.3))
	card.add_theme_stylebox_override("pressed", _charm_card_box(Color("#352a68"), NEON_GOLD, 1.0, 0.3))
	card.add_theme_stylebox_override("disabled", _charm_card_box(Color("#16133466"), tint, 0.18, 0.0))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.mouse_entered.connect(_on_charm_hovered.bind(index))
	card.mouse_exited.connect(clear_info.bind(INFO_CHARM))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(u * CARD_SEPARATION))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	# Lichtfleck hinter dem Modell. Er QUILLT über das Modell hinaus, zählt aber
	# nicht zur Mindesthöhe: sonst schöbe sein Rand den Preis aus der Karte.
	var glow := tint if not bought else Color(tint.r, tint.g, tint.b, 0.3)
	var disc_side := thumb_px * (1.5 if podest else 1.27)
	var stage := CenterContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var halo := Control.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.custom_minimum_size = Vector2(thumb_px, thumb_px)
	halo.size = halo.custom_minimum_size
	var disc := _glow_disc(glow, disc_side)
	disc.position = Vector2.ONE * ((thumb_px - disc_side) * 0.5)
	disc.size = Vector2.ONE * disc_side
	halo.add_child(disc)
	var thumb := CharmThumb.new(charm, thumb_px)
	thumb.size = Vector2(thumb_px, thumb_px)
	halo.add_child(thumb)
	stage.add_child(halo)
	charm_thumbs.append(thumb)
	column.add_child(stage)

	# Der NAME steht immer da, die Wirkung als EINE Zeile darunter - passt sie
	# nicht, fällt sie weg; den vollen Text trägt der Hinweis-Schirm.
	var text_width := width - u * CARD_MARGIN * 2.0
	column.add_child(_card_line(charm.display_name, text_width, name_px,
		NEON_MUTED if bought else NEON_TEXT, false))
	var effect := _card_line(charm.description, text_width, effect_px, NEON_MUTED, true)
	if effect != null:
		column.add_child(effect)
	else:
		# Die weggefallene Zeile behält ihren PLATZ: sonst stünden Name und Preis
		# auf Nachbarkarten verschieden hoch.
		var hole := Control.new()
		hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hole.custom_minimum_size = Vector2(0.0, ThemeDB.fallback_font.get_height(effect_px))
		column.add_child(hole)

	var tag := "gekauft" if bought else ("voll" if full else \
		("gratis" if _charm_price() <= 0 else "$%d" % _charm_price()))
	column.add_child(_label(tag, u * CARD_PRICE_FONT,
		NEON_MUTED if bought or full else Color(1.4, 1.16, 0.14), HORIZONTAL_ALIGNMENT_CENTER))

	# Der Handler hängt an JEDER ungekauften Karte: ein voller Dock sperrt sie nur
	# als Startzustand, ein Verkauf gibt sie ohne Neuverdrahtung wieder frei
	# (_on_charm_clicked prüft charms_full ohnehin selbst).
	if not bought:
		card.pressed.connect(_on_charm_clicked.bind(index))
	if bought or full:
		card.disabled = true
	charm_buttons.append(card)
	return card

## Der Grad EINER Zeile für die ganze Kartenreihe: der erste, in dem JEDER Text
## noch einzeilig in die Karte paßt - sonst der kleinste. Die Grammatik des
## Hinweis-Schirms, nur auf eine Zeile statt auf einen Block.
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

## Eine Kartenzeile im gesetzten Grad. droppable heißt: paßt der Text auch so
## nicht einzeilig, FÄLLT die Zeile weg (null) statt umzubrechen - die Karte
## bleibt ruhig, den vollen Text trägt der Hinweis-Schirm.
func _card_line(text: String, width: float, px: int, color: Color, droppable: bool) -> Label:
	var font := ThemeDB.fallback_font
	if droppable and font != null \
			and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, px).x > width:
		return null
	var label := _label(text, float(px), color, HORIZONTAL_ALIGNMENT_CENTER)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

## Die Charm-Karte erklärt sich auf dem Schirm wie jede andere Ware - Name,
## Wirkung, Preis. Ein voller Dock steht dort, wo sonst der Preis steht.
func _on_charm_hovered(index: int) -> void:
	if run == null or index < 0 or index >= charm_options.size():
		return
	var charm: Charm = charm_options[index]
	var bought: bool = index < charm_bought.size() and charm_bought[index]
	var blocked := DOCK_TAG if run.charms_full() and not bought else ""
	show_info(INFO_CHARM, {
		"title": charm.display_name,
		"body": charm.description,
		"price": _charm_price(),
		"money": run.money,
		"blocked": blocked,
	})

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
	var from_px := _buy_origin_px(KIND_SPECIAL, index)
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

# --- Der Hinweis-Schirm --------------------------------------------------------

## Preiszeile und ihre Farbe - reine Funktionen, damit die Entscheidung
## "bezahlbar oder nicht" prüfbar ist und nur an EINER Stelle fällt.
static func price_text(price: int) -> String:
	return "$%d" % price

static func price_tint(price: int, money: int) -> Color:
	return NEON_GOLD if money >= price else CasinoStyle.RED

## Der Schirm hat eine FESTE Größe und einen festen Platz: er steht, was auch
## immer auf ihm steht. Gezeichnet wird auf ein Panel, nicht in einen Container -
## ein Container wüchse mit seinem Text und verschöbe die Bucht darunter.
func _build_info_screen() -> Panel:
	var screen := Panel.new()
	screen.name = "ShopInfoScreen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.clip_contents = true
	screen.custom_minimum_size = Vector2(0.0, u * INFO_HEIGHT)
	_info_box = TableScreen.window_style()
	screen.add_theme_stylebox_override("panel", _info_box)
	var column := VBoxContainer.new()
	column.name = "InfoText"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = u * INFO_PAD
	column.offset_right = -u * INFO_PAD
	column.offset_top = u * INFO_PAD
	column.offset_bottom = -u * INFO_PAD
	column.add_theme_constant_override("separation", int(u * INFO_LINE_GAP))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(column)

	info_title = Label.new()
	info_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.visible = false
	CasinoStyle.style_score_label(info_title, maxi(8, int(u * INFO_TITLE)), CasinoStyle.GOLD)
	column.add_child(info_title)

	info_body = RichTextLabel.new()
	info_body.bbcode_enabled = true
	info_body.fit_content = true
	info_body.scroll_active = false
	# STOP: die Schlüsselwörter sind Klickziele, der Schirm fängt sie ein.
	info_body.mouse_filter = Control.MOUSE_FILTER_STOP
	info_body.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	info_body.visible = false
	CasinoStyle.style_rich_body(info_body, maxi(8, int(u * INFO_BODY)))
	info_body.meta_clicked.connect(_on_info_meta)
	column.add_child(info_body)

	info_price = Label.new()
	info_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_price.visible = false
	CasinoStyle.style_score_label(info_price, maxi(8, int(u * INFO_PRICE)), NEON_GOLD)
	column.add_child(info_price)

	# Die Leerlaufzeile liegt ÜBER dem ganzen Schirm, nicht in seiner Spalte: so
	# rührt sie die Auskunft nicht an, wenn sie kommt und geht.
	info_idle = _label(INFO_IDLE_TEXT, u * INFO_IDLE_FONT, INFO_IDLE_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER)
	info_idle.name = "InfoIdle"
	info_idle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_idle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(info_idle)

	# Ein frischer Schirm steht leer - also gleich im Leerlauf, ohne Gnadenfrist.
	_info_lit_applied = -1.0
	_apply_info_lit(0.0)
	return screen

## Die EINE Stelle, an der Leerlauf und Inhalt sich unterscheiden: Grund, Saum und
## Leerlaufzeile hängen an einem Wert. Das Rechteck rührt sich dabei nie.
func _apply_info_lit(lit: float) -> void:
	var value := clampf(lit, 0.0, 1.0)
	# Der Schirm wird je Bild gefragt - eine unveränderte Stufe darf ihn nicht in
	# jedem Bild neu zeichnen lassen.
	if is_equal_approx(value, _info_lit_applied):
		_info_lit = value
		return
	_info_lit_applied = value
	_info_lit = value
	if _info_box != null:
		_info_box.bg_color = INFO_IDLE_BG.lerp(TableScreen.FRAME_BG, _info_lit)
		var edge := TableScreen.FRAME_COLOR
		_info_box.border_color = Color(edge.r, edge.g, edge.b,
			lerpf(INFO_IDLE_BORDER_ALPHA, 1.0, _info_lit))
	if info_idle != null and is_instance_valid(info_idle):
		info_idle.modulate.a = 1.0 - _info_lit

## Wie hell der Schirm gerade steht - der prüfbare Zustand (1 = Inhalt).
func info_lit() -> float:
	return _info_lit

## Inhalt kam: sofort hell, kein Warten.
func _light_info() -> void:
	_kill_info_tween()
	_apply_info_lit(1.0)

## Inhalt ging: erst die Gnadenfrist, dann weich zurück in den Leerlauf.
func _dim_info() -> void:
	_kill_info_tween()
	if not is_inside_tree():
		_apply_info_lit(0.0)
		return
	_info_tween = create_tween()
	_info_tween.tween_interval(INFO_IDLE_GRACE)
	_info_tween.tween_method(_apply_info_lit, _info_lit, 0.0, INFO_IDLE_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _kill_info_tween() -> void:
	if _info_tween != null and _info_tween.is_valid():
		_info_tween.kill()
	_info_tween = null

## Der EINE Schreiber des Schirms. data ist eine Auskunft aus vitrine_annotation
## (oder die einer Charm-Karte): title, body, price (-1 = keiner), money, blocked.
func show_info(source: String, data: Dictionary) -> void:
	if info_title == null or not is_instance_valid(info_title):
		return
	if data.is_empty():
		clear_info(source)
		return
	_info_source = source
	info_title.text = String(data.get("title", ""))
	info_title.visible = info_title.text != ""
	_info_body_text = String(data.get("body", ""))
	# EIN Engpass für alle Hover-Quellen: hier werden die Schlüsselwörter zu
	# Lexikon-Verweisen.
	info_body.text = Lexikon.linkify(_info_body_text)
	info_body.visible = _info_body_text != ""
	var blocked := String(data.get("blocked", ""))
	var price := int(data.get("price", -1))
	info_price.visible = blocked != "" or price >= 0
	if blocked != "":
		info_price.text = blocked
		info_price.add_theme_color_override("font_color", CasinoStyle.RED)
	elif price >= 0:
		info_price.text = price_text(price)
		info_price.add_theme_color_override("font_color",
			price_tint(price, int(data.get("money", 0))))
	_light_info()
	_fit_info()

## Leeren - aber nur, wenn der Rufer auch der Sprecher ist. "" räumt hart.
func clear_info(source: String = "") -> void:
	if info_title == null or not is_instance_valid(info_title):
		return
	if source != "" and source != _info_source:
		return
	_info_source = ""
	_info_body_text = ""
	info_title.text = ""
	info_title.visible = false
	info_body.text = ""
	info_body.visible = false
	info_price.visible = false
	_dim_info()

func info_source() -> String:
	return _info_source

## Der Platz des Schirms in globalen Display-Pixeln.
func info_screen_rect() -> Rect2:
	if info_screen == null or not is_instance_valid(info_screen):
		return Rect2()
	return info_screen.get_global_rect()

## Beide Zeilen passen sich EIN: erst die Kennung in ihren Anteil, dann die
## Wirkung in den Rest. Gemessen wird an der Schrift, nicht am Layout - die
## Antwort muss vor dem nächsten Bild stehen. Und gemessen wird der NACKTE Text:
## BBCode-Auszeichnung ist keine Schrift.
func _fit_info() -> void:
	if info_body == null or not is_instance_valid(info_body):
		return
	var width := maxf(_info_text_width(), u * 8.0)
	var room := u * INFO_HEIGHT - u * INFO_PAD * 2.0
	room -= _fit_info_title(width, room)
	if info_price.visible:
		var price_font := info_price.get_theme_font("font")
		if price_font != null:
			room -= price_font.get_height(info_price.get_theme_font_size("font_size")) \
				+ u * INFO_LINE_GAP
	var font := info_body.get_theme_font("normal_font")
	for step in INFO_BODY_STEPS:
		var px := maxi(8, int(u * float(step)))
		info_body.add_theme_font_size_override("normal_font_size", px)
		if font == null:
			return
		if WorkshopView.text_block_height(font, _info_body_text, width, px, 0) <= room:
			return

## Die Kennung nimmt den ersten Grad, der in ihren Anteil paßt, und meldet, wie
## viel Schirm sie samt Fuge verbraucht hat. EINE Zeile wird immer genommen.
func _fit_info_title(width: float, room: float) -> float:
	if info_title == null or not is_instance_valid(info_title) or not info_title.visible:
		return 0.0
	var font := info_title.get_theme_font("font")
	var spacing := info_title.get_theme_constant("line_spacing")
	var used := 0.0
	for step in INFO_TITLE_STEPS:
		var px := maxi(8, int(u * float(step)))
		info_title.add_theme_font_size_override("font_size", px)
		if font == null:
			return 0.0
		used = WorkshopView.text_block_height(font, info_title.text, width, px, spacing)
		if used <= room * INFO_TITLE_SHARE \
				or WorkshopView.text_block_lines(font, info_title.text, width, px) <= 1:
			break
	return used + u * INFO_LINE_GAP

func _info_text_width() -> float:
	var screen := info_screen_rect()
	var span := screen.size.x if screen.size.x > 0.0 else size.x - u * 6.0
	return maxf(span - u * INFO_PAD * 2.0, u * 8.0)

## Verweis-Klick auf dem Schirm: das Lexikon anfordern.
func _on_info_meta(meta: Variant) -> void:
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
	var from_px := _buy_origin_px(KIND_ENGRAVING_PACK, index)
	var refunded := run.purchase_pack(pack, price)
	engraving_pack_bought[index] = true  # liegt im Spread - übersteht den Neuaufbau
	pack_purchased.emit(from_px, pack.pack_uid)
	if refunded > 0:
		pack_refunded.emit(from_px, refunded)
	_show_spread()

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
	# Ein gesperrter Pager trägt sein Schloss - Gebühr und Seitenstand hätte er
	# sonst über das Zeichen geschrieben, das die Sperre überhaupt erklärt.
	if run.shop_flipping_unlocked():
		if page_back_button != null and is_instance_valid(page_back_button):
			page_back_button.disabled = current_spread_index == 0
		if page_next_button != null and is_instance_valid(page_next_button):
			if _next_flip_is_new():
				page_next_button.text = "$%d ›" % _next_flip_fee()
				page_next_button.disabled = money < _next_flip_fee()
			else:
				page_next_button.text = "›"
				page_next_button.disabled = false
	# Hub-Aufstieg-Knopf folgt dem Geldstand - Sperre wie Preisfarbe.
	if hub_upgrade_button != null and is_instance_valid(hub_upgrade_button) and hub_upgrade_button.visible:
		hub_upgrade_button.disabled = not run.can_upgrade_hub()
		_tint_hub_price(run.hub_upgrade_price())
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
		var pack: Pack = null
		if run != null:
			pack = _slit_pack(_slit_seats[seat])
		if pack == null:
			tag.text = ""  # leerer Platz: kein Schild
			continue
		var price := _pack_price(pack)
		tag.text = price_text(price)
		tag.modulate = price_tint(price, money)
	for i in mini(_net_prices.size(), _net_dice.size()):
		var mark := _net_prices[i]
		if mark == null or not is_instance_valid(mark):
			continue
		var price := _shown_die_price(_net_dice[i])
		if price < 0:
			mark.text = ""
			continue
		mark.text = price_text(price)
		mark.modulate = price_tint(price, money)

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
	clear_info()
	visible = false
	closed.emit()
