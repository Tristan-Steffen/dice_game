class_name ShopController
extends Control
## Der Shop zwischen den Runden - ein Neon-Panel auf der Hub-Fläche des
## Tisch-Displays, bedient über die Maus-Weiterleitung. Die Seite liest sich von
## oben nach unten als vier Bänder mit FESTEN Anteilen: CHARM-ZEILE (digitale
## Ware, die als Karte bleibt und ihren VOLLEN Wirkungstext beim Hover zeigt), das
## GRAVUREN-Band mit den KASSETTEN-PLÄTZEN, auf denen die versiegelte Ware LIEGT,
## darunter die VITRINE mit den offenen Würfeln und zuletzt der Fuß. Kein Band
## wächst mit Lizenzstufe oder Bestand. Körper zeichnet dieser Laden nie selbst;
## er MELDET Rechtecke und Inhalte nach oben (vitrine_rect_px/vitrine_stock,
## slit_anchors/slit_stock), aufgestellt wird alles von scene_root.
## DIE WARE TRÄGT IHRE AUSKUNFT SELBST: es gibt keinen Hinweis-Schirm mehr. Die
## Charm-Karte trägt ihren Effekttext an der Stelle ihres Modells (Hover-Tausch,
## kein Reflow), die Kappe der Kassette ihre Sorte und
## Größe, und unter jedem Würfel liegen sein Netz, seine Seelen-Zeile und sein
## Preis. Zwei Sprecher antworten zusätzlich auf den Zeiger, beide ohne eigenen
## Kasten: die FLANKE der Schlitzreihe (Name + Beschreibung der gegriffenen
## Kassette, rechts neben der Reihe) und der INFO-FUSS am unteren Buchtrand
## (die hint_for-Zeile der Netz-Zelle bzw. die Seelen-Zeile des Würfelkörpers).
## Ohne Hover steht an beiden Stellen NICHTS.
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

## Was statt eines Preises steht, wenn das Lager zu ist - ein Kauf, der stumm
## scheitert, wäre schlimmer als eine Zahl weniger. Die lange Fassung trägt die
## Karte des Hinterzimmers, die kurze das schmale Preisschild einer Kassette.
const FULL_TAG := "MAGAZIN VOLL"
const FULL_MARK := "VOLL"

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

## Der gesperrte Pfeil ERKLÄRT SICH SELBST: Schloss plus die Stufe, ab der er
## aufgeht. Kein Hover, kein zweites Element - die Aufschrift IST die Auskunft.
static func pager_lock_text() -> String:
	return "%s %d" % [PAGER_LOCK, GameRun.HUB_FLIPPING_LEVEL]

## Der STELLPLATZ eines Kassetten-Schlitzes: die Ware LIEGT dort flach auf der
## Fläche, gemessen wird also ihr liegender Grundriß (Breite × Höhe der Karte)
## im EINEN Anzeigemaß (PackDrawerView.CASSETTE_SCALE), plus Stellluft. Die
## u-Maße sind nur ihr Boden, solange kein Grundriß gemeldet ist.
## Seit die Reihe das GANZE Band bekommt (der Schirm daneben ist tot), ist Breite
## keine Not mehr - die Stellluft steht auf einem bequemen Maß. Die Höhe ist die
## verbliebene Fessel: sie bestimmt das Band, und was das Band nimmt, fehlt der
## Bucht (gemessen: 1,3 kostet die Auslage 15 px).
const SLIT_ROOM := 1.3
const SLIT_MIN_WIDTH := 5.4
const SLIT_MIN_HEIGHT := 8.0
## Sitzhöhe eines Platzes und die Luft zwischen zwei Stellplätzen. Die Reihe steht
## jetzt über der vollen Seitenbreite, die Fuge darf also atmen.
const SLIT_SEAT_HEIGHT := 4.2
const SLIT_GAP := 2.4

## Die FLANKE der Schlitzreihe: die Reihe steht mittig, links wie rechts bleiben
## gemessene ~317 px frei. Die rechte davon ist der feste Platz der Auskunft -
## Fuge zur Reihe, Mindestbreite, unter der gar nichts geschrieben wird, und die
## Luft zwischen Name und Beschreibung.
const FLANK_GAP := 2.0
const FLANK_MIN_WIDTH := 14.0
const FLANK_SEPARATION := 0.7
## Wieviel der Reihenhöhe der NAME höchstens nimmt - der Rest gehört der
## Beschreibung, die als einzige umbricht.
const FLANK_NAME_SHARE := 0.38
const FLANK_NAME_STEPS := [2.4, 2.2, 2.0, 1.8, 1.6]
const FLANK_BODY_STEPS := [2.0, 1.8, 1.6, 1.45, 1.3, 1.15, 1.0]

## Die LICHTFUGE der Hebebühne: der Umriss des Feldes glüht auf, BEVOR seine Ware
## kommt - die Ankündigung des Automaten. Zone 0 ist die Gravuren-Schlitzreihe,
## Zone 1 die Bucht, jede im Akzent ihres Bandes. Sie sind absolut gestellte
## Overlays, KEINE Layout-Kinder: die Bandrechte bleiben byte-gleich.
const SEAM_ZONE_SLIT := 0
const SEAM_ZONE_BAY := 1
const SEAM_ZONES := 2
const SEAM_PAD := 0.9
const SEAM_BORDER := 0.34
const SEAM_FADE := 0.12
## Überhell: die Fuge ist ein UMRISS, kein Feld - ihr Glühen kommt aus dem Bloom
## des Displays, nicht aus einer gefüllten Fläche (eine gefüllte deckte die Ware zu).
const SEAM_GLOW := 1.9

## Der GRUND dieser Seite, wie er am Tisch wirklich leuchtet - die bündige
## Plattform der Hebebühne trägt ihn, damit ihr Schließen nicht springt. GEMESSEN,
## nicht gerechnet: über dem Fenstergrund liegen noch die Gründe der Seite.
const BAY_GROUND := Color(0.149, 0.141, 0.277)

## Die Tiefe des INFO-FUSSES am unteren Buchtrand, in BUCHTEN-Einheiten
## (Streifenbreite/100) - dieselbe Einheit, in der scene_root seine Reserve
## rechnet, damit Reserve und wirklicher Aufbau nicht driften. Gemessen: die
## längste reale hint_for-Kette steht darin umgebrochen auf zwei Zeilen.
const VITRINE_FOOTER_UNITS := 4.4
const FOOTER_MARGIN := 2.0
const FOOTER_STEPS := [2.0, 1.8, 1.6, 1.4, 1.25, 1.1]

## Preis eines Schalen-Würfels aus dem ungerabatteten Angebotspreis.
static func single_die_price(offer_price: int) -> int:
	return maxi(1, roundi(float(offer_price) * SINGLE_DIE_DISCOUNT))
const FLIP_DURATION := 0.25
## Beide Zonen blättern DIESELBE Doppelseite: die Charm-Zeile wartet, bis die alte
## Ware unter dem Glas versunken ist, sonst stünden neue Karten über alter Ware.
## Spiegelt VitrineView.SWAP_TIME (ui/ greift nicht in table/ - ein Test hält die
## beiden Zahlen gleich).
const FLIP_DELAY := 0.52

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
		run = value
		# Ein frischer Lauf bekommt einen frischen Laden - auch ohne Sperre.
		sortiment_locked = false
		spreads = []
		_standing_spread = null
		_vitrine_grade = GRADE_STAND
		if run != null:
			run.money_changed.connect(_on_run_money_changed)
			run.charms_changed.connect(_on_run_charms_changed)
			run.packs_changed.connect(_on_run_packs_changed)

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
## Der INFO-FUSS am unteren Rand der Bucht: eine rahmenlose Zeile, die beim Hover
## einer Netz-Zelle deren hint_for-Zeile trägt und beim Hover des Würfelkörpers
## seine Seelen-Zeile. Ohne Hover unsichtbar - kein Kasten, kein Leerlauf.
var net_footer: Label
## Die LICHTFUGEN der beiden Zonen (Index = SEAM_ZONE_*). Reine Anzeige.
var lift_seams: Array[Panel] = []
var _seam_tweens: Array[Tween] = []
## Die Auskunft der Schlitzreihe in ihrer rechten Flanke (Name + Beschreibung).
## Absolut positioniertes Overlay der SEITE, kein Layout-Kind - die Bandhöhen
## bleiben davon unberührt.
var slit_info: Control
var slit_info_name: Label
var slit_info_body: Label
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
## Wessen Netz an welcher Stelle des Layers hängt - daran hängen die beiden Zeilen
## darunter.
var _net_dice: Array[DieDefinition] = []
## Je Netz sein Preisschild - dieselbe Quelle wie der Kauf (single_dice_prices),
## nur klein und an der Ware.
var _net_prices: Array[Label] = []
## Und dazwischen die SEELEN-ZEILE: der Name der Essenz im Glühton der Essenz. Sie
## steht IMMER (kein Hover) und bleibt leer, wo kein Würfel eine Seele hat.
var _net_souls: Array[Label] = []
## Wo die Netze liegen (Streifen-Pixel) und in welchem Zellmaß - daraus antwortet
## net_hint_at, ohne die Controls abzulaufen.
var _net_positions: Array[Vector2] = []
var _net_cell := 0.0
## Was im Fuß steht - idempotenter Schreiber, er läuft je Bild.
var _net_hint := ""
## Welche Kassette die Flanke gerade erklärt ("" = keine).
var _slit_info_key := ""

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
var charm_effects: Array[Label] = []
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

	# Die Flankenauskunft und die Lichtfugen stehen VOR dem Layout in der Kindliste:
	# sie sind Overlays, keine Bänder - und das Möbel der Seite bleibt so ihr
	# letztes Kind.
	_build_slit_info()
	_build_lift_seams()

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

	# EIN Band unter den Karten, und es gehört ganz der GRAVUREN-Reihe: seit der
	# Hinweis-Schirm tot ist, steht sie mittig über der vollen Seitenbreite. Sie
	# steht UNABHÄNGIG von der Doppelseite - ein Kauf baut sie nicht um.
	var gravur_band := VBoxContainer.new()
	gravur_band.name = "GravurBand"
	gravur_band.add_theme_constant_override("separation", int(u * ZONE_SEPARATION))
	gravur_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gravur_band.add_child(_heading_row("GRAVUREN", _tinted(NEON_CYAN), ""))
	var slit_center := CenterContainer.new()
	slit_center.name = "SlitCenter"
	slit_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slit_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slit_row = _build_slit_row()
	slit_center.add_child(slit_row)
	gravur_band.add_child(slit_center)
	root.add_child(gravur_band)

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
	_build_net_footer()
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
	footer.add_child(page_back_button)
	page_label = _label("Seite 1", u * 2.8, NEON_MUTED)
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(page_label)
	page_next_button = _neon_button("›", NEON_CYAN, u * 3.2, Vector2(u * 12.0, u * 5.0))
	page_next_button.pressed.connect(_on_page_next_pressed)
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
	_slit_info_key = ""  # die Reihe ist neu, die Flanke erklärt nichts mehr
	if slit_info != null and is_instance_valid(slit_info):
		slit_info.visible = false
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
	# Nur der KLICK hängt hier: das Anheben der liegenden Kassette und ihre
	# Flankenauskunft fragt scene_root je Bild ab - der Zeiger liegt auf dem Tisch.
	button.pressed.connect(_on_slit_pressed.bind(seat))
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

## Der Platz EINES Angebots (-1 = keiner) - der Kauf-Komet startet dort.
func _seat_of(kind: String, index: int) -> int:
	for i in _slit_seats.size():
		if String(_slit_seats[i]["kind"]) == kind and int(_slit_seats[i]["index"]) == index:
			return i
	return -1

# --- Die FLANKENAUSKUNFT der Schlitzreihe --------------------------------------
# Die Kappe nennt Sorte und Größe, das Schild den Preis - was in der Kassette
# steckt, sagt die Flanke, und nur mit Zeiger. Der Platz ist der freie Streifen
# RECHTS der mittigen Reihe.

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

## Die freie RECHTE Flanke in globalen Pixeln: von der Kante der Reihe plus Fuge
## bis zum Seitenrand, senkrecht auf der Reihe. GEMESSEN - ein leeres Rechteck
## heißt, dass die Seite noch nicht ausgelegt ist oder zu wenig Platz bleibt.
func slit_flank_rect() -> Rect2:
	if slit_row == null or not is_instance_valid(slit_row):
		return Rect2()
	var row := slit_row.get_global_rect()
	if row.size.x <= 0.0 or row.size.y <= 0.0:
		return Rect2()
	var left := row.end.x + u * FLANK_GAP
	var right := get_global_rect().end.x - u * PAGE_MARGIN
	if right - left < u * FLANK_MIN_WIDTH:
		return Rect2()
	return Rect2(Vector2(left, row.position.y), Vector2(right - left, row.size.y))

## Der EINE Schreiber der Flanke (-1 = kein Platz gegriffen). Ein verkaufter oder
## nie gewürfelter Platz zeigt NICHTS - dort liegt keine Ware, die etwas sagen
## könnte. Idempotent: dieselbe Kassette schreibt nichts neu.
func set_slit_hover(seat: int) -> void:
	if slit_info == null or not is_instance_valid(slit_info):
		return
	var pack: Pack = null
	if seat >= 0 and seat < _slit_seats.size():
		pack = _slit_pack(_slit_seats[seat])
	var key := "" if pack == null else "%d:%d" % [seat, pack.get_instance_id()]
	if key == _slit_info_key:
		return
	_slit_info_key = key
	if pack == null:
		slit_info.visible = false
		return
	var flank := slit_flank_rect()
	if flank.size.x <= 0.0:
		slit_info.visible = false
		_slit_info_key = ""  # ungemessen: beim nächsten Bild noch einmal versuchen
		return
	slit_info.position = flank.position - get_global_rect().position
	slit_info.size = flank.size
	slit_info_name.text = pack.display_name
	slit_info_name.modulate = PackDrawerView.COLORS.get(Pack.shelf_of(pack), NEON_TEXT)
	slit_info_body.text = pack.description
	_fit_slit_info(flank.size)
	slit_info.visible = true

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
	var label := _label("", font_size, color, align)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	return label

## Der größte Grad einer Leiter, in dem der umgebrochene Text noch in den Block
## paßt - sonst der kleinste. Dieselbe Grammatik wie _card_block_font, nur mit
## der Leiter als Parameter.
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

# --- Der INFO-FUSS der Bucht ---------------------------------------------------
# Eine flache, rahmenlose Zeile am unteren Bandrand: die EINE hint_for-Auskunft
# der Netz-Zelle unter dem Zeiger, bzw. die Seelen-Zeile des Würfelkörpers. EIN
# Schreiber (scene_root entscheidet, wer spricht), leer = unsichtbar.

func _build_net_footer() -> void:
	net_footer = _wrapped_line(u * float(FOOTER_STEPS[0]), NEON_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	net_footer.name = "NetFooter"
	net_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	net_footer.visible = false
	vitrine_field.add_child(net_footer)
	_net_hint = ""

func set_net_hint(text: String) -> void:
	if net_footer == null or not is_instance_valid(net_footer) \
			or vitrine_field == null or not is_instance_valid(vitrine_field):
		return
	if text == _net_hint:
		return
	_net_hint = text
	net_footer.text = text
	net_footer.visible = text != ""
	if text == "":
		return
	# Der Platz wird beim ANZEIGEN gerechnet: erst dann steht das Feld gemessen da.
	var field := vitrine_field.size
	var bay_u := maxf(field.x, 1.0) / 100.0
	var margin := bay_u * FOOTER_MARGIN
	var room := Vector2(maxf(field.x - margin * 2.0, 1.0), bay_u * VITRINE_FOOTER_UNITS)
	var font := ThemeDB.fallback_font
	var px := maxi(8, int(bay_u * float(FOOTER_STEPS[FOOTER_STEPS.size() - 1])))
	if font != null:
		px = _footer_font(font, text, room, bay_u)
	_lay_wrapped(net_footer, px, Vector2(margin, maxf(field.y - room.y, 0.0)), room)

## Der Grad der Fußzeile: der größte, in dem die Zeile umgebrochen noch in den
## Fuß paßt. Gemessen in BUCHTEN-Einheiten, nicht in denen der Seite - der Fuß
## gehört der Bucht.
func _footer_font(font: Font, text: String, block: Vector2, bay_u: float) -> int:
	var smallest := maxi(8, int(bay_u * float(FOOTER_STEPS[FOOTER_STEPS.size() - 1])))
	var lead := net_footer.get_theme_constant("line_spacing")
	for step in FOOTER_STEPS:
		var px := maxi(8, int(bay_u * float(step)))
		if wrapped_height(font, text, block.x, px, lead) <= block.y:
			return px
	return smallest

## Die hint_for-Zeile der Netz-Zelle unter einem globalen Display-Pixel ("" =
## keine). Gerechnet wird im STREIFEN, denn dort hängen die Netze.
func net_hint_at(pixel: Vector2) -> String:
	if _net_cell <= 0.0 or _net_positions.is_empty():
		return ""
	var strip := vitrine_rect_px()
	if strip.size.x <= 0.0 or not strip.has_point(pixel):
		return ""
	var local := pixel - strip.position
	var span := DieNetView.net_size(_net_cell)
	for i in mini(_net_dice.size(), _net_positions.size()):
		var box := Rect2(_net_positions[i], span)
		if not box.has_point(local):
			continue
		return DieNetView.hint_for(_net_dice[i],
			DieNetView.face_at(local - _net_positions[i], _net_cell))
	return ""

# --- Die LICHTFUGEN der Hebebühne ----------------------------------------------
# Der Automat kündigt an, bevor er fährt: der Umriss des Feldes glüht auf, bleibt
# über die Fahrt und verlischt, sobald die Zone steht. Getaktet wird von scene_root
# (dort liegen die Zeiten der Bühne) - hier wird nur gemalt.

func _build_lift_seams() -> void:
	lift_seams.clear()
	_seam_tweens.clear()
	for zone in SEAM_ZONES:
		var seam := Panel.new()
		seam.name = "LiftSeam%d" % zone
		seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seam.visible = false
		seam.modulate = Color(1, 1, 1, 0)
		seam.add_theme_stylebox_override("panel", _seam_box(seam_tint(zone)))
		add_child(seam)
		lift_seams.append(seam)
		_seam_tweens.append(null)

## Jede Zone glüht im Akzent ihres Bandes - Gravuren cyan, Würfel grün.
static func seam_tint(zone: int) -> Color:
	return NEON_GREEN if zone == SEAM_ZONE_BAY else NEON_CYAN

func _seam_box(accent: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false  # unter einer Fuge liegt Ware, kein Panel
	box.border_color = Color(accent.r * SEAM_GLOW, accent.g * SEAM_GLOW, accent.b * SEAM_GLOW)
	box.set_border_width_all(maxi(2, int(u * SEAM_BORDER)))
	box.set_corner_radius_all(int(u * 1.0))
	box.anti_aliasing = true
	return box

## Das Feld, aus dem gleich Ware kommt (leer = die Seite steht noch nicht).
func seam_field(zone: int) -> Rect2:
	if zone == SEAM_ZONE_SLIT:
		if slit_row == null or not is_instance_valid(slit_row):
			return Rect2()
		return slit_row.get_global_rect()
	return vitrine_rect_px()

## Die Fuge EINER Zone an- oder abblenden. Reine Anzeige - sie läßt keinen Zustand
## zurück, den ein Abbruch aufräumen müßte (hide_lift_seams löscht hart).
func set_lift_seam(zone: int, on: bool) -> void:
	if zone < 0 or zone >= lift_seams.size():
		return
	var seam := lift_seams[zone]
	if seam == null or not is_instance_valid(seam):
		return
	if on:
		var field := seam_field(zone)
		if field.size.x <= 0.0 or field.size.y <= 0.0:
			return
		var pad := u * SEAM_PAD
		seam.position = field.position - get_global_rect().position - Vector2(pad, pad)
		seam.size = field.size + Vector2(pad, pad) * 2.0
		seam.visible = true
	_kill_seam_tween(zone)
	var fade := create_tween()
	_seam_tweens[zone] = fade
	fade.tween_property(seam, "modulate:a", 1.0 if on else 0.0, SEAM_FADE)
	if not on:
		fade.tween_callback(func() -> void:
			if is_instance_valid(seam):
				seam.visible = false)

## Vorhangfall oder Laufwechsel: beide Fugen sind sofort fort.
func hide_lift_seams() -> void:
	for zone in lift_seams.size():
		_kill_seam_tween(zone)
		var seam := lift_seams[zone]
		if seam == null or not is_instance_valid(seam):
			continue
		seam.modulate = Color(1, 1, 1, 0)
		seam.visible = false

func _kill_seam_tween(zone: int) -> void:
	if zone < 0 or zone >= _seam_tweens.size():
		return
	var running := _seam_tweens[zone]
	if running != null and running.is_valid():
		running.kill()
	_seam_tweens[zone] = null

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
	var font := ThemeDB.fallback_font
	var soul_height := font.get_height(maxi(8, int(u * WARE_SOUL_FONT)))
	var price_height := font.get_height(maxi(8, int(u * WARE_PRICE_FONT)))
	for entry in entries:
		var def: DieDefinition = entry["def"]
		var net := DieNetView.build(def, VitrineView.die_up_face(), cell)
		net.position = entry["pos"]
		vitrine_nets.add_child(net)
		_net_dice.append(def)
		_net_positions.append(entry["pos"])
		# Unter dem Netz die SEELE, darunter der PREIS - die Ware sagt selbst, was
		# in ihr steckt und was sie kostet. Beide Zeilen stehen immer, damit die
		# Reihe nicht je Würfel anders hoch wird.
		var soul_y: float = entry["pos"].y + span.y + u * WARE_PRICE_GAP
		var essence := Essence.by_id(def.essence_id)
		var soul := _label(essence.display_name if essence != null else "",
			u * WARE_SOUL_FONT, soul_tint(def.essence_id), HORIZONTAL_ALIGNMENT_CENTER)
		soul.position = Vector2(entry["pos"].x, soul_y)
		soul.size = Vector2(span.x, soul_height)
		vitrine_nets.add_child(soul)
		_net_souls.append(soul)
		var tag := _label("", u * WARE_PRICE_FONT, NEON_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		tag.position = Vector2(entry["pos"].x, soul_y + soul_height + u * WARE_PRICE_GAP)
		tag.size = Vector2(span.x, price_height)
		vitrine_nets.add_child(tag)
		_net_prices.append(tag)
	_refresh_ware_prices()

## Der Ton der Seelen-Zeile: das Kantenglühen der Essenz selbst. Ein dunkler Ton
## (Vakuum glüht schwarz) wird auf ein lesbares Maß gehoben - sonst stünde die
## Zeile als Loch auf dunklem Grund.
static func soul_tint(essence_id: String) -> Color:
	var glow := Essence.glow_for(essence_id)
	if glow.get_luminance() >= SOUL_MIN_LUMINANCE:
		return glow
	return glow.lerp(Color(1, 1, 1), SOUL_LIFT)

func clear_die_nets() -> void:
	set_net_hint("")  # ein Fuß unter verschwundenen Netzen wäre eine Lüge
	if _net_signature == "":
		return
	_net_signature = ""
	_drop_die_nets()

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
	_net_prices.clear()
	_net_souls.clear()
	_net_positions.clear()
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

## Blättern gesperrt (Hub-Stufe 1): die Pfeile BLEIBEN stehen und tragen Schloss
## UND die nötige Stufe ("🔒 2") - eine gesperrte Funktion erklärt sich in ihrer
## eigenen Aufschrift, nicht in einem Hover woanders.
func _refresh_pager_lock() -> void:
	var locked := not run.shop_flipping_unlocked()
	var pagers: Array[Button] = [page_back_button, page_next_button]
	for button in pagers:
		if button == null or not is_instance_valid(button):
			continue
		button.visible = true
		if locked:
			button.text = pager_lock_text()
			button.disabled = true
			# Gesperrt tragen beide dieselbe Aufschrift - dann stehen sie auch gleich
			# breit; die Gebühren-Breite des Vorwärts-Pfeils braucht hier niemand.
			button.custom_minimum_size = Vector2(u * 12.0, u * 5.0)
			button.add_theme_stylebox_override("normal",
				_button_box(Color("#1a183666"), Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.22)))
		else:
			button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), NEON_CYAN))
	if not locked:
		page_back_button.text = "‹"
		page_back_button.custom_minimum_size = Vector2(u * 7.0, u * 5.0)
		page_next_button.text = "›"
		page_next_button.custom_minimum_size = Vector2(u * 12.0, u * 5.0)
	page_label.visible = true

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

## Baut die Bildschirm-Zone der Seite: seit dem Vitrinen-Umbau ist das NUR noch
## das Charm-Regal - Pakete, Einzelstücke und das Händler-Regal liegen körperlich
## darunter. Die Karten füllen die Breite UND das feste Band: schrumpfen darf die
## Karte, das Band nie.
func _rebuild_content(spread: MenuSpread) -> void:
	for child in content_root.get_children():
		child.queue_free()
	charm_buttons.clear()
	charm_thumbs.clear()
	charm_stages.clear()
	charm_effects.clear()

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
	# Der NAMENS-Grad gilt für die GANZE Zeile: Namen nebeneinander, jeder in seinem
	# eigenen Grad, lasen sich als Flickenteppich. Der Wirkungstext dagegen sucht
	# sich seinen Grad je KARTE - es ist ohnehin immer nur eine gehovert.
	var text_w := card_w - u * CARD_MARGIN * 2.0
	var names: Array[String] = []
	for charm in spread.charm_options:
		names.append(charm.display_name)
	var name_px := _row_font(names, text_w, CARD_NAME_STEPS)
	var podest_index := 0 if run.shop_rarity_tier() >= 1 else -1
	for i in spread.charm_options.size():
		var podest := i == podest_index
		var ccard := _build_charm_card(spread.charm_options[i], i, cm.x, int(cm.y),
			card_w, name_px, podest)
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
## Die WIRKUNG steht VOLLSTÄNDIG auf der Karte, aber erst beim HOVER: sie nimmt
## den Platz des Modells ein, nie einen eigenen. Weil immer nur EINE Karte gehovert
## ist, sucht sich jede Karte ihren Grad selbst - der oberste, der umgebrochen noch
## in ihre Mittelfläche paßt. Der letzte Grad trägt nachweislich alle 145 echten
## Beschreibungen, auch auf der schmalsten Karte (Hub 10).
const CARD_EFFECT_STEPS := [1.8, 1.65, 1.5, 1.35, 1.2, 1.1, 1.0, 0.95, 0.85]
## Breiten-Deckel EINER Karte: zwei Angebote sollen kompakt und mittig stehen
## statt als Panorama. Gemessen an dem, was fünf Karten auf Stufe 10 bekommen.
const CARD_MAX_UNITS := 17.0
## Seitenrand der Seite (Margin) - die Kartenbreite mißt sich daran.
const PAGE_MARGIN := 3.0

## Das Preisschild AN der Ware: klein - kleiner als der Karten-Preis der Charms,
## damit die Hierarchie Charm-Karte > Ware bleibt.
const WARE_PRICE_FONT := 1.7
const WARE_PRICE_GAP := 0.6
## Die SEELEN-ZEILE unter einem Würfelnetz: eine Spur kleiner als der Preis - der
## Preis ist die Entscheidung, die Seele ihr Grund.
const WARE_SOUL_FONT := 1.6
## Ab welcher Helligkeit ein Essenz-Glühen als Schriftfarbe taugt, und wie weit
## ein dunkleres zum Weiß gezogen wird (Vakuum glüht schwarz).
const SOUL_MIN_LUMINANCE := 0.45
const SOUL_LIFT := 0.6
## Wie breit ein Modell auf seiner Karte höchstens werden darf.
const THUMB_WIDTH_SHARE := 0.62
## Und der Boden, unter den es nicht fällt - kleiner liest es als Fleck.
const THUMB_MIN := 3.2

## Charm-Karte: (Kartenhöhe, Modell-Kantenlänge). Die HÖHE ist fest - sie ist das
## Band minus dem, was Zonenrand und Kopfzeile davon nehmen; elastisch bleibt
## allein das Modell, das mit der Kartenbreite schrumpft. Gemessen, nicht getippt:
## die Kopfzeile fragt ihre Schrifthöhe ab.
func _charm_metrics(count: int) -> Vector2:
	var thumb := minf(card_mid_height(), _charm_card_width(count) * THUMB_WIDTH_SHARE)
	return Vector2(_charm_card_height(), maxf(thumb, u * THUMB_MIN))

## Die feste Kartenhöhe: das Band minus Zonenrand und Kopfzeile.
func _charm_card_height() -> float:
	var font := ThemeDB.fallback_font
	var head := u * HEADING_FONT * 1.4
	if font != null:
		head = font.get_height(maxi(8, int(u * HEADING_FONT)))
	return maxf(u * BAND_CHARM_UNITS - u * ZONE_MARGIN * 2.0 - head - u * ZONE_SEPARATION,
		u * 6.0)

## Die MITTELFLÄCHE einer Charm-Karte in Pixeln: die Karte minus Rand, Name und
## Preis. Sie ist FEST - im Ruhezustand steht das Modell darin, beim Hover der
## volle Wirkungstext an SEINER Stelle. Getauscht wird nur die Sichtbarkeit, das
## Maß nie, also reflowt die Karte über den Tausch kein Pixel.
func card_mid_height() -> float:
	var font := ThemeDB.fallback_font
	if font == null:
		return maxf(_charm_card_height() * 0.5, u * THUMB_MIN)
	var price := font.get_height(maxi(8, int(u * CARD_PRICE_FONT)))
	var name_h := font.get_height(maxi(8, int(u * float(CARD_NAME_STEPS[0]))))
	return maxf(_charm_card_height() - u * CARD_MARGIN * 2.0 - price - name_h \
		- u * CARD_SEPARATION * 2.0, u * THUMB_MIN)

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
	var disc := _glow_disc(glow, disc_side)
	disc.position = Vector2.ONE * ((thumb_px - disc_side) * 0.5)
	disc.size = Vector2.ONE * disc_side
	halo.add_child(disc)
	var thumb := CharmThumb.new(charm, thumb_px)
	thumb.size = Vector2(thumb_px, thumb_px)
	halo.add_child(thumb)
	stage.add_child(halo)
	charm_thumbs.append(thumb)
	mid.add_child(stage)

	# Hover: an SEINER Stelle die volle Wirkung - ungekürzt, umbrechend, im größten
	# Grad, den DIESE Mittelfläche hergibt. Auch eine gekaufte oder gesperrte Karte
	# tauscht: der Text ist dann erst recht die einzige Auskunft.
	var effect := _card_effect(charm.description, text_width, mid_h,
		_card_block_font(charm.description, text_width, mid_h), NEON_MUTED)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.visible = false
	mid.add_child(effect)
	charm_stages.append(stage)
	charm_effects.append(effect)

	var tag := "gekauft" if bought else ("voll" if full else \
		("gratis" if _charm_price() <= 0 else "$%d" % _charm_price()))
	column.add_child(_label(tag, u * CARD_PRICE_FONT,
		NEON_MUTED if bought or full else Color(1.4, 1.16, 0.14), HORIZONTAL_ALIGNMENT_CENTER))

	# Der Zeiger liegt auf dem Tisch, aber die Bewegung wird in den SubViewport
	# weitergeleitet - der Knopf meldet seinen Hover also selbst. Ein gesperrter
	# Knopf meldet ihn ebenso, seine Auskunft bleibt erreichbar.
	card.mouse_entered.connect(set_charm_hover.bind(index, true))
	card.mouse_exited.connect(set_charm_hover.bind(index, false))

	# Der Handler hängt an JEDER ungekauften Karte: ein voller Dock sperrt sie nur
	# als Startzustand, ein Verkauf gibt sie ohne Neuverdrahtung wieder frei
	# (_on_charm_clicked prüft charms_full ohnehin selbst).
	if not bought:
		card.pressed.connect(_on_charm_clicked.bind(index))
	if bought or full:
		card.disabled = true
	charm_buttons.append(card)
	return card

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

## Der Grad des WIRKUNGSTEXTES EINER Karte: der erste, in dem er umgebrochen noch
## in ihre Mittelfläche paßt. Je Karte gefunden, denn gehovert ist immer nur eine -
## eine Karte darf so groß schreiben, wie ihre eigene Fläche hergibt. Der letzte
## Schritt der Leiter trägt nachweislich alle 145 Beschreibungen; abgeschnitten
## wird nie.
func _card_block_font(text: String, width: float, block: float) -> int:
	var font := ThemeDB.fallback_font
	var smallest := maxi(8, int(u * float(CARD_EFFECT_STEPS[CARD_EFFECT_STEPS.size() - 1])))
	if font == null:
		return smallest
	for step in CARD_EFFECT_STEPS:
		var px := maxi(8, int(u * float(step)))
		if WorkshopView.text_block_height(font, text, width, px, 0) <= block:
			return px
	return smallest

## Eine einzeilige Kartenzeile im gesetzten Grad (der Name) - sie wird notfalls
## beschnitten, denn ein Name bricht nicht um.
func _card_line(text: String, px: int, color: Color) -> Label:
	var label := _label(text, float(px), color, HORIZONTAL_ALIGNMENT_CENTER)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

## Der WIRKUNGSTEXT der Karte: umbrechend, mittig in der Mittelfläche. Er trägt
## die ganze Beschreibung - das ist die Auskunft, für die es früher einen Schirm
## gab, und beim Hover steht sie an der Stelle des Modells.
func _card_effect(text: String, width: float, block: float, px: int, color: Color) -> Label:
	var label := _label(text, float(px), color, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(width, block)
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

# --- Neon-Bausteine --------------------------------------------------------------

func _label(text: String, font_size: float, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

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
		var price := _shown_die_price(_net_dice[i])
		if price < 0:
			mark.text = ""
			continue
		mark.text = price_text(price)
		mark.modulate = price_tint(price, money)

func _on_run_money_changed(_money: int) -> void:
	if visible:
		_refresh_afford_state()

## Das Magazin hat sich geändert - die Preisschilder der Kassetten tragen die
## VOLL-Marke, sie müssen also nachziehen.
func _on_run_packs_changed() -> void:
	if visible:
		_refresh_ware_prices()

## Der Dock hat sich geändert (Kauf ODER Verkauf): der "voll"-Tag steckt in der
## Karte, die Auslage muss also neu gebaut werden. DEFERRED, weil
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
