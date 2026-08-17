class_name WorkshopView
extends Panel
## Die Werkbank unter den Trays - das EINZIGE Fenster der Ecke. Ihre Grundseite
## liest sich von oben nach unten: gleich unter dem oberen Fensterrand die
## Projektoren der Aufspannung (die echten Würfel schweben darüber, scene_root
## stellt sie auf) und unter jedem sein Würfelnetz.
##
## Alles darunter liegt in der SCHÜRZE, und sie beginnt UNTER der Fensterkante:
## eine Naht, dann das Konsolen-Band (in seiner Mitte die flache Reihe der
## Presse-Plätze, in seiner rechten Flanke der EINE Handlungs-Sitz - Pressen /
## Fertig -, in seiner linken die Hinweiskarte), dieselbe Naht noch einmal, dann
## das MAGAZIN über die volle Fensterbreite: EIN eingelassenes Fach, in dem jedes
## versiegelte Paket als eigene Kassette in Spieler-Ordnung liegt (owned_packs);
## es endet auf der Unterkante des Hubs (scene_root misst das und schiebt es als
## apron_bottom herein). Getippt legt eine Kassette in den nächsten freien Platz
## (Würfel-Pakete öffnen ihre Wahl), gezogen sortiert sie um, ein Doppelklick auf
## leere Fach-Fläche räumt auf. Das Fenster gehört damit ganz der Aufspannung.
##
## Band und Magazin STEHEN durch jeden Ablauf - Wurf, Platzierung, Paket-Wahl,
## Dossier -, gesperrt nur, wo nichts anzufassen ist (shelf_locked). Das
## Fensterinnere bleibt dabei frei: nichts von der Schürze ragt mehr herein.
##
## Die Pressung ist EIN Griff: der Preis fällt, die Leser wirbeln, und ihre Beute
## LIEGT danach als nackte Chips im freien Band unter der Netzzeile - die ABLAGE.
## Von dort wird verteilt: der geführte Chip trägt den goldenen Rahmen, seine
## legalen Ziele leuchten IN den Netzen der Aufspannung. Erst das FERTIG macht den
## Guss hart; bis dahin ist jede Setzung nass und kommt per Klick auf ihre Plakette
## in die Ablage zurück. Nachpressen ist erlaubt - die Stücke legen sich dazu.
## Zustands-Mutation läuft über GameRun (open_pack/open_press/apply_press_*); die
## Zeremonien hängen an den Signalen und leben in scene_root.

## Ein Paket wurde geöffnet (scene_root hängt Ton/Licht daran).
signal pack_activated(uid: int)
## Die Pressung ist gefallen: sorts sind die Sorten der belegten Leser, readers je
## Leser die Nummern der Stücke, die er auswirft, cost die eben bezahlte Energie.
## Gebucht ist da längst - scene_root fährt daran die Zeremonie (Wirbel, Entladung,
## Meteore in die Ablage).
signal press_rolled(sorts: Array, readers: Array, cost: int)
## Ein Beutestück hat seinen Platz gefunden - scene_root lässt das Licht aus seinem
## Chip ins Netz fahren und den Projektor dieses Würfels aufblitzen. Der Startpunkt
## reist MIT: gebucht ist da längst und das Fenster schon neu gebaut.
signal piece_placed(die: DieDefinition, engraving_id: String, from_px: Vector2)
## Das Fertig hat die Reste der Hand in Geld aufgelöst - scene_root lässt die Zahl
## über der Konsole aufsteigen. Der Anker reist MIT: gebucht ist da längst und das
## Fenster schon neu gebaut.
signal press_cashed_out(amount: int, from_px: Vector2)
## Die Bühnen der Paket-Würfel haben sich geändert (Wahl, Einsetzen, Ende) -
## scene_root stellt die ECHTEN Würfel darüber neu auf.
signal die_stages_changed
## Ein Liefer-Licht ist auf seinem Magazin-Platz eingeschlagen - scene_root lässt
## den Körper dort aufleuchten (der Pluster lebt nicht mehr im 2D-Knopf).
signal pack_landed(uid: int)
## Ein Paket ist aus seinem Presse-Platz zurück ins Magazin gegangen - die Zelle
## dieses Platzes fliegt heim auf ihren Platz. Gebucht ist da längst.
signal pack_unslotted(slot_index: int, uid: int)
## Der Wurf beginnt: die eingesetzten Zellen geben ihre Daten an ihre Leser ab.
## Gemeldet wird VOR dem Öffnen, solange die Sockel noch stehen.
signal press_started

const TITLE_COLOR := Color("#8be9fd")
const TEXT_COLOR := Color(1.35, 1.35, 1.3)
const MUTED_COLOR := Color(0.75, 0.78, 0.9)
const GOLD := Color("#ffd319")

## Spaltenzahl der Pool-Auswahl = Spaltenzahl der echten Trays (DiceTrayView),
## damit das Raster wie das Tray darüber liest.
const POOL_COLUMNS := 6
## Maße des Hinweis-Schirms (Regal-Bucht, Leser, Netz-Zelle).
const INFO_TITLE := 2.4
const INFO_BODY := 1.9
## Innenrand des Schirms und der Abstand zwischen Titel und Wirkung. Nach außen
## hat er keinen: links steht er auf der Fensterkante, rechts trennt ihn die
## Naht des Handlungs-Sitzes (ACTION_GAP) vom Blech.
const INFO_PAD := 0.9
const INFO_LINE_GAP := 0.3
## Schriftgrade der Wirkungszeile, absteigend: der Schirm hat eine feste Größe,
## also nimmt der Text den ersten Grad, dessen Umbruch noch hineinpaßt. Der
## längste Satz des Spiels (der Pointer, 165 Zeichen) landet auf der letzten
## Stufe - darunter läse ihn niemand mehr, darüber stünde er halb im Rahmen.
const INFO_BODY_STEPS := [1.9, 1.65, 1.4, 1.2, 1.05]

## Höhe der Bühne eines schwebenden Paket-Würfels (Breiteneinheiten u): Platz für
## den Würfel UND seine Stasis-Station, die durch die Parallaxe ein Stück unter
## ihm auf der Fläche steht. Die BREITE gibt das Netz darunter vor - Würfel und
## Netz sind eine Spalte, und mit ihr rücken auch die drei Würfel auseinander.
const STAGE_HEIGHT := 9.3
const STAGE_GAP := 3.0
## Zellgröße des Netzes unter jedem Paket-Würfel: die Kachel, in der ein Würfel
## gezeigt wird, wenn man ÜBER ihn entscheidet. (Die Hover-Karte ist kleiner:
## sie ist nur Auskunft.)
const CHOICE_CELL := DieNetView.TRAY_TILE
## Fuge zwischen der Würfelspalte links und dem 30er-Raster rechts - auf der
## Dossier-Seite wie beim Einsetzen eines Paket-Würfels dieselbe. Sie ist der
## SEITENRAND des Inhalts (CONTENT_MARGIN_X, per Test festgenagelt): das Raster
## soll nach oben, unten und zu seiner Spalte hin genauso viel Luft haben wie zum
## rechten Fensterrand - eine Zahl, vier Abstände.
const BODY_GAP := 2.4
## Zeilenabstand der Dossier-Spalte und die LUFT zwischen der Bühne des Würfels
## und seinem Netz. INSPECT_NET_GAP ist die GEMESSENE Luft von Bühnenkante zu
## Netzkante - die zwei Zeilenabstände des Kastens liegen schon darin, der
## Zwischenraum trägt nur den Rest. Gut das Doppelte des bloßen Zeilenabstands:
## der Würfel soll über seinem Diagramm STEHEN, nicht darauf aufliegen.
const INSPECT_LINE_GAP := 0.6
const INSPECT_NET_GAP := 1.4
## Aufhellung des überfahrenen Netzes - es ist der Knopf, hat aber keinen Rahmen.
const NET_HOVER := Color(1.3, 1.3, 1.3)

## Presse-Plätze: strukturell sechs (PhantomPress.BATCH_CAP), unabhängig davon,
## wie viele Zwingen die Lizenz gerade aufspannt.
const BENCH_COLUMNS := PhantomPress.BATCH_CAP
## Spaltenluft und Kantenlänge eines Presse-Platzes (Einheiten u). Der Platz ist
## SIEGELGROSS: die Reihe ist eine flache Leiste, keine Kartenzeile.
const BENCH_GAP := 1.2
const PRESS_SLOT := 5.4
## Ein Leseschlitz ist ein LOCH, kein Ding: die Datenzelle STECKT senkrecht darin
## und ragt nur mit ihrer Kopfkante heraus - sie ist die ganze Anzeige.
const SOCKET_BG := Color("#0b0a18dd")
const SOCKET_RIM := Color("#3b356acc")
const SOCKET_LIVE_RIM := Color("#8be9fdcc")
## Der Schlitz muss die Zelle schlucken, und zwar in dem EINEN Maß, in dem sie
## überall steht (PackDrawerView.CASSETTE_SCALE): ihre Kappe gibt Breite UND Tiefe
## vor. Flach bleibt er trotzdem - ein Schlitz ist eine Kante, keine Bucht;
## SLIT_HEIGHT ist nur noch sein Mindestmaß.
const SOCKET_ROOM := 1.30
const SLIT_HEIGHT := 1.6
## Das Anzeigefeld über dem Schlitz - der eigentliche LESER: dunkel, solange
## nichts steckt; belegt trägt es das Siegelzeichen seiner Sorte, und im Wurf
## laufen darin die sechs Icons als Walze. Es ist so groß wie früher der ganze
## Platz: was der Automat auswirft, muss man aus der Bank-Entfernung lesen können.
const SLIT_DISPLAY := 6.0
const SLIT_DISPLAY_GAP := 0.4
## Die sechs Schlitze liegen in einem erhabenen KONSOLEN-BLECH: dieselbe gemalte
## Tiefe wie die Regal-Schalen (Lichtkante oben, Schattenkante unten), aber
## neutral - die Sortenfarbe gehört der Ware, nicht dem Gerät. Das Blech umfasst
## genau die sechs Plätze; über die Fensterbreite gedehnt wäre es leere Fläche.
const CONSOLE_BASE := Color("#2f2c3c")
const CONSOLE_SHEEN := Color("#bab7cd")
const CONSOLE_SHEEN_MIX := 0.44
const CONSOLE_SHADOW := Color(0.0, 0.0, 0.0, 0.7)
const CONSOLE_PAD_X := 1.2
const CONSOLE_PAD_Y := 0.72
const CONSOLE_EDGE := 0.33
const CONSOLE_RADIUS := 0.9
## Die Tasche eines Platzes: Feld und Schlitz liegen IM Blech, also Schatten oben
## und Licht unten - die Umkehrung der Konsolenkante. Sie ragt ein Stück über den
## Knopf hinaus, sonst schnitte ihr Band die Anzeige an.
const POCKET_BASE := Color("#14121f")
const POCKET_SHEEN := Color(0.66, 0.64, 0.76, 0.5)
const POCKET_SHADOW := Color(0.0, 0.0, 0.0, 0.75)
const POCKET_BLEED := 0.26
const POCKET_EDGE := 0.22
const POCKET_RADIUS := 0.7
## Kopfhöhe über der Projektor-Zeile: der schwebende Zwingen-Würfel ragt über
## seine Bühne hinaus, und in der Nahsicht sitzt die obere Fensterkante exakt am
## Bildrand - ohne diese Luft schnitte der Rahmen ihm die Oberseite ab.
## Zurückgenommen, als das breitere Fenster kürzer wurde: gemessen steht die
## Würfeloberkante damit noch gut zwei Einheiten unter dem Rand, und die
## gewonnene Höhe braucht die Ablage unter der Netzzeile.
const CLAMP_HEAD_ROOM := 1.0
## Luft zwischen der Projektor-Bühne und dem Netz darunter: die Aufspannung ist
## Bestand und soll über ihren Diagrammen STEHEN, nicht auf ihnen aufliegen.
## Gemessen am scheinbaren Würfelmaß der Bank (4,92 u breit): unter der
## Würfelunterkante liegen damit gut 3,9 u frei, also rund eine Würfelbreite.
const CLAMP_NET_GAP := 1.0
## Deckel der Netz-Zellgröße: die Netzzeile ist die Arbeitsfläche, aber unter ihr
## müssen Presse und Regal noch Platz finden - ohne Deckel liefe sie bei kleiner
## Aufspannung randlos auseinander. Die entfallene Prämientafel ist hierher und
## in die Regal-Karten geflossen; der Rest bleibt unten als Luft für die
## Hinweiskarte stehen.
const CLAMP_CELL_MAX := 3.9
## Die NAHT der Schürze - zweimal dasselbe Maß: Fensterkante zu Konsolenband und
## Konsolenband zu Regal. Das Band hängt zwischen zwei gleichen Fugen, es liegt
## nicht mehr auf der Kante.
const CONSOLE_SHELF_GAP := 2.1
## Mindesthöhe einer Bucht (Einheiten u) - ohne sie fiele der Streifen auf einem
## flachen Prüffenster zu einer Linie zusammen.
const SHELF_MIN_HEIGHT := 6.0
## Sollhöhe einer Bucht (Einheiten u). Am Tisch ist sie der REST bis zur
## Hub-Unterkante - dieses Maß ist die Gegenrichtung derselben Kette: scene_root
## rechnet daraus die Fensterhöhe (apron_units), und die Rechnung schließt sich,
## weil beide Seiten dieselbe Naht und dasselbe halbe Band ansetzen.
const SHELF_STRIP_UNITS := 15.0
## Ränder und Zeilenabstand des Fensterinhalts (Einheiten u).
const CONTENT_MARGIN_X := 2.4
const CONTENT_MARGIN_Y := 1.4
const CONTENT_GAP := 1.0

## Der EINE Handlungs-Sitz rechts neben der Konsole: er trägt der Reihe nach
## "Pressen (n)", "Nehmen" und "Fertig". EIN Maß für alle drei - der Sitz steht
## fest, nur seine Aufschrift wechselt, und die Grundseite fließt nie um.
const ACTION_WIDTH := 20.0
const ACTION_HEIGHT := 4.0
## Luft zwischen Konsolenblech und Sitz bzw. Sitz und Fensterrand.
const ACTION_GAP := 1.6

## Die Landung eines Beutestücks: sein Chip plustert einmal auf und lodert in
## seiner Sortenfarbe. Erst DA wird sichtbar, was gefallen ist.
const PIECE_POP := 1.14
const PIECE_POP_TIME := 0.10
const PIECE_FLARE_TIME := 0.45

## DIE ABLAGE: die gepressten Stücke liegen als nackte Chips auf dem Glas, im
## freien Band unter der Netzzeile. Der Streifen hängt am FENSTER (volle
## Inhaltsbreite, Unterkante am Inhaltsrand), nicht am Zeilenfluss - ob zwei oder
## vier Zwingen darüber stehen und ob er leer ist oder dreißig Chips trägt,
## ändert keinen Pixel der Grundseite.
## Höhe und Reihenzahl sind an DIESES Band gemessen: die Netze enden bei 26,8 u,
## der Inhalt bei 36,3 u - der Streifen füllt den Rest und liegt damit unter den
## Diagrammen statt auf ihnen. Zwei Reihen à 17 Spalten fassen auch den größten
## Wurf, weil gleiche Gravuren sich einen Platz teilen.
const ABLAGE_STRIP := 8.8
const ABLAGE_ROWS := 2
const ABLAGE_ROW_GAP := 0.9
const ABLAGE_CHIP_MAX := 5.4
## Spaltenteilung (Vielfaches der Chipkante) und die Streuung um den Rasterplatz -
## es ist ein Haufen, kein Setzkasten.
const ABLAGE_COLUMN_PITCH := 1.05
const ABLAGE_JITTER := 0.22
## Der weiche Schein unter einem Chip: seine Sortenfarbe, kein Rahmen - das Stück
## LIEGT da (Chip-Schalen-Regel).
const ABLAGE_GLOW_ALPHA := 0.38
const ABLAGE_FILL_ALPHA := 0.12
## Aufhellung des überfahrenen Chips (er ist der Knopf, hat aber keinen Rahmen).
const ABLAGE_HOVER := Color(1.35, 1.35, 1.35)
const ABLAGE_HOVER_LIFT := 1.09
## Das Aufräumen: kurze Pause nach dem letzten Einschlag, dann gleitet Stück für
## Stück von links nach rechts in die Reihe.
const ABLAGE_TIDY_DELAY := 0.28
const ABLAGE_TIDY_STAGGER := 0.035
const ABLAGE_TIDY_TIME := 0.34
## Gleiche Gravuren teilen sich EINEN Platz und liegen deckungsgleich: der
## Stapel zeigt sich allein an der goldenen ×n auf dem Icon, nicht an versetzten
## Kopien - die waren im Streifen kaum auszumachen.
const ABLAGE_COUNT_SIZE := 0.34

var run: GameRun:
	set(value):
		if run == value:
			return
		if run != null and run.packs_changed.is_connected(refresh):
			run.packs_changed.disconnect(refresh)
			run.clamped_changed.disconnect(refresh)
			run.press_changed.disconnect(refresh)
		_pending_arrivals.clear()  # Lieferungen des alten Laufs verfallen
		_queued_pops.clear()
		_abort_unseal()  # noch VOR dem Wechsel: der Inhalt gehört dem alten Lauf
		_drop_placement()  # ebenso ein Würfel, der noch einen Platz suchte
		_drop_press()  # und ein Wurf, der noch auf der Bank kollert
		_drop_inspect()  # und das Dossier eines Würfels, den es gleich nicht mehr gibt
		run = value
		if run != null:
			run.packs_changed.connect(refresh)
			run.clamped_changed.connect(refresh)  # die Netzzeile IST die Aufspannung
			run.press_changed.connect(refresh)  # Hand und nasse Plaketten hängen daran
		refresh()

## Werkbank-Zustand: die Grundseite, die Entsiegelung eines Pakets oder das
## Einsetzen seiner Würfel. Weder die Pressung noch der Platzierungs-Schritt ist
## eine Phase - die eine läuft in den Lesern der Grundseite, der andere hängt an
## der offenen Beute (siehe placing) und übersteht damit jeden Neuaufbau.
## CHOOSE_DIE liegt zwischen Entsiegeln und Einsetzen: Würfel-Pakete mit mehr
## als einem Würfel decken ALLE auf, der Spieler nimmt GENAU EINEN mit.
## INSPECT ist das Dossier eines Pool-Würfels: reine Auskunft, kein Werkzeug.
enum Phase { STASH, UNSEAL, CHOOSE_DIE, PLACE_DICE, INSPECT }

var _content: VBoxContainer
## Die Netze der Aufspannung, Reihenfolge = run.clamped_dice. Sie sind zugleich
## die Arbeitsfläche: im Platzierungs-Schritt leuchten IHRE Zellen.
var _clamp_nets: Array[PressNetView] = []
## Die leeren Projektor-Bühnen über den Netzen: dort schweben die echten
## Zwingen-Würfel, IM Fenster und gleich unter seinem oberen Rand.
var _clamp_stage_hosts: Array[Control] = []
## Die sechs Presse-Plätze; jeder ist ein Leseschlitz mit seinem Anzeigefeld.
var _press_slot_buttons: Array[Button] = []
## Die gezeichneten Schlitze selbst - IHRE Mitte ist der Steckplatz der Zelle,
## nicht die des Knopfes (der reicht bis über das Anzeigefeld).
var _press_slit_panels: Array[Panel] = []
## Die Anzeigefelder derselben Reihe - jedes ein Portal (Siegel, Wirbel,
## Entladung).
var _press_display_panels: Array[Panel] = []
var _press_portals: Array[PressPortalView] = []
## Das Magazin der Bank (null = gerade nicht gebaut).
var _drawer: PackDrawerView
## Das Konsolen-Band auf der unteren Fensterkante (null = gerade nicht gebaut).
var _band: Control
## Unterkante der SCHÜRZE in Fenster-Koordinaten: scene_root misst sie an der
## Unterkante des Hubs - dort enden die Buchten - und schiebt sie herein
## (<= size.y = noch nichts gemeldet, dann trägt der Rückfall).
var apron_bottom := 0.0:
	set(value):
		if is_equal_approx(apron_bottom, value):
			return
		apron_bottom = value
		refresh()
## Paket-uids, deren Liefer-Licht noch fährt (der Komet IST das Paket): ihr Platz
## im Magazin steht schon, der Chip erscheint erst bei der Landung.
var _pending_arrivals: Dictionary = {}
## Ankunfts-Pluster, die noch auf ihr Fach warten (es stand gerade nicht).
var _queued_pops: Array[int] = []

## Gesperrt, sobald die Runde unterschrieben ist - dasselbe Zeitfenster wie
## fürs Gravieren; scene_root schiebt den Stand herein. Die Presse hängt daran
## mit, darum baut ein Wechsel das Regal neu.
var editing_locked: bool = false:
	set(value):
		if editing_locked == value:
			return
		editing_locked = value
		refresh()
## Fußabdruck einer STEHENDEN Datenzelle in Display-Pixeln (ihre Kappe: Breite ×
## Kappentiefe); scene_root misst ihn an der Welt-Projektion und schiebt ihn
## herein (ZERO = noch unbekannt, dann trägt das Rückfallmaß der Leiste). Magazin
## und Schlitze messen sich daran - die Zelle ist ein Weltmaß, sie schrumpft nicht
## auf ein Fenster.
var data_cell_px := Vector2.ZERO:
	set(value):
		if data_cell_px.is_equal_approx(value):
			return
		data_cell_px = value
		refresh()

## Der Hinweis-Schirm am Konsolen-Band samt der Einheit, für die er gebaut wurde.
var _info_screen: Panel
var _info_title: Label
var _info_body: Label
var _info_tint: Color = CasinoStyle.CREAM

var _phase: Phase = Phase.STASH
## Für die Presse gewählte Pakete, als uids (Gravur-Pakete, höchstens BATCH_CAP) -
## uids, nicht Indizes: das Magazin darf unter der Vorwahl umsortiert werden.
var _selected_packs: Array[int] = []
## Der Platzierungs-Schritt: die NUMMER des geführten Stücks (0 = keins). Nach der
## Nummer, nicht nach Platz oder id: der Haufen liegt frei, und dieselbe Gravur
## darf mehrfach darin liegen.
var _held_uid := 0
## Die GRAVUR, die zuletzt in der Hand lag - sie überlebt ihr Stück, denn daran
## rückt die Hand nach, sobald es gesetzt ist.
var _held_id := ""
## Der erste Klick eines gerichteten Paares und der Würfel, auf dem er fiel.
var _first_face := -1
var _first_die: DieDefinition
## Die Ablage: ihr Wirt und je Stück sein Chip (Nummer -> Knopf).
var _ablage_host: Control
var _ablage_chips: Dictionary = {}
## Die aufgeräumte Reihe: Nummer -> ihr Platz, dazu die Länge der Reihe (sie
## trägt die Zentrierung). Wer hier steht, liegt in der Reihe; wer fehlt, im
## Haufen. Die Plätze FRIEREN EIN - ein gesetztes Stück verrückt keinen Nachbarn,
## und erst die nächste Pressung räumt alles neu.
var _ablage_order: Dictionary = {}
var _ablage_slots: int = 0
## Je Stück Tiefe, Anzahl und Spitze seines Stapels (Nummer -> Dictionary).
var _ablage_stack: Dictionary = {}
## Stücke, deren Meteor noch fliegt: sie liegen schon in GameRun, ihr Chip aber
## noch nicht auf dem Glas - aufgedeckt wird bei der LANDUNG. Solange hier etwas
## steht, läuft die Presse (siehe pressing).
var _withheld: Dictionary = {}
## Die Sorten der geschluckten Pakete: sie halten Leser und Portal in ihrer Farbe,
## solange die Pressung läuft - die Vormerkung ist da längst abgeräumt.
var _press_sorts: Array[String] = []
## Der Würfel des Dossiers samt den Wirten seiner Bühne und seines Netzes.
var _inspect_die: DieDefinition
var _inspect_stage_host: Control
var _inspect_net: Control
## Das Blech der Schlitzreihe (null = steht gerade nicht).
var _console: Panel
## Inhalt des gerade geöffneten Pakets.
var _revealed_dice: Array[DieDefinition] = []
## Der GANZE Würfel-Inhalt des Pakets, auch das gerade Abgewählte: ohne ihn wäre
## die Wahl unumkehrbar (siehe go_back).
var _pack_dice: Array[DieDefinition] = []
## Sorte des offenen Pakets (die Zeremonie zeigt sein Siegel).
var _open_pack_type := ""
## Die laufende Entsiegelung.
var _unseal: PackUnsealView
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
## Der Knopf des Handlungs-Sitzes vor der Pressung.
var _press_button: Button
## "Fertig" des Platzierungs-Schritts (null = steht gerade nicht).
var _apply_button: Button
## Würfel-Raster der Pool-Auswahl samt seinem Wirt und der zuletzt daraus
## errechneten Maßeinheit.
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
	# NICHT beschnitten: Konsolen-Band und Regal-Leiste hängen absichtlich unter
	# der Fensterkante heraus (die Schürze). Alles, was im Fenster BLEIBEN soll,
	# endet an der Oberkante des Bandes - siehe _refresh_content.
	clip_contents = false
	add_theme_stylebox_override("panel", TableScreen.window_style())
	refresh()

## Der HINWEIS-SCHIRM in der linken Flanke des Konsolen-Bandes: ein eigenes
## kleines Display neben der Presse, auf dem steht, was gerade überfahren wird -
## Regal-Bucht, Leser mit Beutestück oder Netz-Zelle. Er STEHT (dunkel und leer,
## wenn nichts unter dem Zeiger liegt), denn Text auf blankem Filz ist kein
## Text auf einem Tisch, sondern Text im Nichts: alles, was das Spiel sagt, sagt
## es auf einer Anzeige.
## tint färbt die WIRKUNGSZEILE - rot ist die eine Auskunft, die der Schirm selbst
## gibt: was gerade nicht zu bezahlen ist.
func show_hover_info(title: String, body: String, tint: Color = CasinoStyle.CREAM) -> void:
	if _info_title == null or not is_instance_valid(_info_title):
		return
	_info_title.text = title
	_info_title.visible = title != ""
	_info_body.text = body
	_info_body.visible = body != ""
	_info_body.modulate = tint if tint == CasinoStyle.RED else Color.WHITE
	_info_tint = tint
	_fit_info_body()

func clear_hover_info() -> void:
	show_hover_info("", "")

## Steht gerade ein Hinweis auf dem Schirm? (Der Schirm selbst steht immer.)
func hover_info_visible() -> bool:
	return _info_title != null and is_instance_valid(_info_title) \
		and (_info_title.visible or _info_body.visible)

## Breite des SCHIRMS: die ganze linke Flanke bis auf die Naht zum Blech. Links
## endet er nicht früher als das Fenster darüber - eine Kante, an der zwei
## Rahmen übereinander stehen, ist die einzige, die man wirklich sieht.
func info_width() -> float:
	var u := maxf(size.x, 200.0) / 100.0
	var flank := (size.x - console_size(u).x) * 0.5
	return maxf(flank - u * ACTION_GAP, u * 14.0)

## Sein Platz im Fenster: bündig mit dessen linker Kante, in der Höhe das Band -
## dieselben zwei Nähte, die auch das Blech von Fenster und Buchten trennen.
func info_screen_rect() -> Rect2:
	var u := maxf(size.x, 200.0) / 100.0
	var top := size.y + u * CONSOLE_SHELF_GAP
	return Rect2(Vector2(0.0, top),
		Vector2(info_width(), maxf(shelf_top() - u * CONSOLE_SHELF_GAP - top, u * 6.0)))

## Breite seines TEXTES: der Schirm abzüglich seines eigenen Randes.
func _info_text_width() -> float:
	var u := maxf(size.x, 200.0) / 100.0
	return maxf(info_width() - u * INFO_PAD * 2.0, u * 10.0)

## Der Schirm hat eine FESTE Größe, also passt sich der Text ein: vom vollen
## Schriftgrad abwärts wird der erste genommen, dessen Umbruch noch in die Höhe
## paßt. Ein langer Materialsatz wird damit kleiner statt abgeschnitten, und ein
## kurzer bleibt groß - gemessen an der Schrift selbst, nicht am Layout, damit
## die Antwort schon vor dem nächsten Bild steht.
func _fit_info_body() -> void:
	if _info_body == null or not is_instance_valid(_info_body):
		return
	var u := maxf(size.x, 200.0) / 100.0
	var width := _info_text_width()
	var font := _info_body.get_theme_font("font")
	var room := info_screen_rect().size.y - u * INFO_PAD * 2.0
	if _info_title.visible and font != null:
		room -= font.get_multiline_string_size(_info_title.text,
			HORIZONTAL_ALIGNMENT_CENTER, width, int(u * INFO_TITLE)).y + u * INFO_LINE_GAP
	for step in INFO_BODY_STEPS:
		var px := int(u * float(step))
		if font == null or px <= 0:
			_info_body.add_theme_font_size_override("font_size", px)
			return
		var block := font.get_multiline_string_size(_info_body.text,
			HORIZONTAL_ALIGNMENT_CENTER, width, px)
		_info_body.add_theme_font_size_override("font_size", px)
		if block.y <= room:
			return

## Baut den Schirm in die linke Flanke des Bandes - er gehört zum Band wie das
## Blech und der Sitz und wird mit ihm neu gelegt.
func _build_info_screen(band: Control, u: float) -> void:
	var standing_title := _info_title_text()  # VOR dem Neubau: gleich sind die Zeilen fort
	var standing_body := _info_body_text()
	var rect := info_screen_rect()
	var screen := Panel.new()
	screen.name = "InfoScreen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override("panel", TableScreen.window_style())
	screen.position = rect.position - band.position
	screen.size = rect.size
	band.add_child(screen)
	_info_screen = screen
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
	_info_title = _info_label(int(u * INFO_TITLE), CasinoStyle.GOLD)
	column.add_child(_info_title)
	_info_body = _info_label(int(u * INFO_BODY), CasinoStyle.CREAM)
	column.add_child(_info_body)
	show_hover_info(standing_title, standing_body, _info_tint)

## Eine Zeile des Schirms: mittig, umbrechend, ohne Maus.
func _info_label(px: int, tint: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(_info_text_width(), 0)
	label.visible = false
	if tint == CasinoStyle.GOLD:
		CasinoStyle.style_score_label(label, px, tint)
	else:
		CasinoStyle.style_body_label(label, px, tint)
	return label

## Der stehende Text übersteht den Neuaufbau des Bandes - sonst erlischt der
## Schirm bei jedem Bild, in dem sich sonst irgendetwas rührt.
func _info_title_text() -> String:
	return _info_title.text if _info_title != null and is_instance_valid(_info_title) else ""

func _info_body_text() -> String:
	return _info_body.text if _info_body != null and is_instance_valid(_info_body) else ""

## Baut das Fenster neu und meldet danach, wo die Würfel-Bühnen jetzt liegen -
## die ECHTEN Würfel darüber gehören scene_root, nicht diesem Fenster. Das gilt
## für die Paket-Würfel wie für die Zwingen über ihren Netzen.
func refresh() -> void:
	_refresh_content()
	die_stages_changed.emit()

func _refresh_content() -> void:
	if not is_inside_tree():
		return
	_die_stages.clear()  # sie hängen im alten Inhalt und fallen mit ihm weg
	_die_nets.clear()
	_clamp_nets.clear()
	_clamp_stage_hosts.clear()
	_press_slot_buttons.clear()
	_press_slit_panels.clear()
	_press_display_panels.clear()
	_press_portals.clear()
	_free_own(_drawer)  # Band, Magazin und Ablage hängen am Panel, nicht am Inhalt
	_drawer = null
	_free_own(_band)
	_band = null
	_free_own(_ablage_host)
	_ablage_host = null
	_ablage_chips.clear()
	_inspect_stage_host = null
	_inspect_net = null
	_prune_selection()
	# Ein Würfel, der nicht mehr im Pool steht, hat kein Dossier mehr - die Seite
	# fällt still auf die Grundseite zurück, statt auf eine tote Def zu zeigen.
	if _phase == Phase.INSPECT and (run == null or run.owned_pool.find(_inspect_die) < 0):
		_phase = Phase.STASH
		_inspect_die = null
	var u := maxf(size.x, 200.0) / 100.0
	_free_own(_content)
	_content = null  # queue_free wirkt erst am Bildende - sonst hängt hier ein Zombie
	_console = null
	_press_button = null
	_apply_button = null

	# Die Schürze steht IMMER: Konsolen-Band und Buchten gehören zur Bank, nicht
	# zu einem Ablauf. Weder Pressung noch Platzierung noch ein Paket nehmen sie
	# weg - gesperrt wird nur, was gerade niemand anfassen darf (shelf_locked).
	_prune_withheld()
	if placing():
		_sync_held()
	_build_press_slots(u)
	_build_drawer(u)
	_build_ablage()
	if _phase == Phase.UNSEAL:
		return  # die Entsiegelung hängt als eigenes Panel über dem Fensterinneren
	# Ein Würfel-Paket legt seine Plätze schon WÄHREND der Entsiegelung aus: die
	# Zeichen fliegen dorthin, wo ihre Würfel gleich stehen. Verraten wird dabei
	# nichts - die Netze bleiben verdeckt, bis ihr Würfel körperlich wird.

	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = u * CONTENT_MARGIN_X
	_content.offset_right = -u * CONTENT_MARGIN_X
	# Die Dossier-Seite steht in einem GLEICHEN Rand ringsum: ihr Raster soll oben
	# und unten so viel Luft haben wie zur Seite. Jede andere Seite behält den
	# flacheren Zeilenrand - dort zählt jede Einheit für die Netze.
	var margin_y := CONTENT_MARGIN_X if _phase == Phase.INSPECT else CONTENT_MARGIN_Y
	_content.offset_top = u * margin_y
	# Das Fensterinnere gehört ganz dem Inhalt: die Schürze hängt vollständig
	# darunter, es ragt nichts mehr herein.
	_content.offset_bottom = -u * margin_y
	_content.add_theme_constant_override("separation", int(u * CONTENT_GAP))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	# Die Wahl eines Paket-Würfels ERSETZT den Titel, statt sich eine zweite Zeile
	# zu nehmen: das Fenster gehört dann den drei Würfeln. Der WERKSTATT-Titel ist
	# ganz entfallen - die Grundseite gehört der Aufspannung.
	if _phase == Phase.CHOOSE_DIE:
		_content.add_child(_label("EINEN WÜRFEL WÄHLEN", u * 5.0, GOLD))
		_build_die_choice(u)
		return
	if _phase == Phase.PLACE_DICE:
		_build_dice_placement(u)
		return
	if _phase == Phase.INSPECT:
		_build_inspect(u)
		return

	_build_clamp_row(u)
	_content.add_child(_bottom_slack())

## Hängt ein eigenes Kind aus und gibt es frei; queue_free wirkt erst am
## Bildende, ein Neuaufbau träfe sonst auf seinen eigenen Vorgänger.
func _free_own(node: Node) -> void:
	if node != null and is_instance_valid(node):
		remove_child(node)
		node.queue_free()

# --- Grundseite: Aufspannung und Presse-Plätze ---------------------------------

## Die Zwingen-Zeile: je Spalte oben die leere Projektor-Bühne, darunter das
## Würfelnetz ihres Würfels. Jede Spalte nimmt ihr Viertel der GANZEN Fensterbreite -
## so weit auseinander, wie die Bank hergibt.
func _build_clamp_row(u: float) -> void:
	var head := Control.new()
	head.name = "ClampHeadRoom"
	head.custom_minimum_size = Vector2(0, u * CLAMP_HEAD_ROOM)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(head)
	var row := HBoxContainer.new()
	row.name = "ClampRow"
	row.add_theme_constant_override("separation", int(u * BENCH_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(row)
	var cell := clamp_cell(u)
	for def in _clamped_dice():
		row.add_child(_clamp_column(def, u, cell))

## Eine Zwingen-Spalte. Die Bühne ist LEER: über ihr schwebt der echte Würfel im
## Stasis-Feld (scene_root stellt ihn auf), ihre Höhe trägt Würfel UND Station -
## dieselbe Bühnen-Geometrie wie bei den Paket-Würfeln, nicht geschätzt.
func _clamp_column(def: DieDefinition, u: float, cell: float) -> Control:
	var column := VBoxContainer.new()
	column.name = "ClampColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", int(u * 0.4))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stage := Control.new()
	stage.name = "ClampStage"
	stage.custom_minimum_size = Vector2(0, u * STAGE_HEIGHT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage)
	_clamp_stage_hosts.append(stage)

	var air := Control.new()
	air.name = "ClampNetGap"
	air.custom_minimum_size = Vector2(0, u * CLAMP_NET_GAP)
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(air)

	var host := Control.new()
	host.name = "ClampNet"
	host.custom_minimum_size = DieNetView.net_size(cell)
	host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var net := _press_net(def, cell)
	host.add_child(net)
	column.add_child(host)
	_clamp_nets.append(net)
	return column

## Ein Arbeits-Netz: es zeigt den Würfel, führt das gehaltene Stück zu seinen
## legalen Seiten und trägt die Plaketten des nassen Gusses.
func _press_net(def: DieDefinition, cell: float) -> PressNetView:
	var net := PressNetView.new()
	net.def = def
	net.cell = cell
	net.locked = editing_locked
	if placing() and run.press_target_allowed(def):
		net.held_id = held_piece_id()
		net.stufe = _held_stufe()
		net.first_face = _first_face if _first_die == def else -1
	if run != null:
		net.marks = run.press_face_marks(def)
	net.build()
	net.face_pressed.connect(_on_net_face_pressed.bind(def))
	net.mark_pressed.connect(_on_net_mark_pressed.bind(def))
	return net

## Zellgröße der Netzzeile: was von der Spaltenbreite übrig bleibt, gedeckelt.
## Gerechnet über die WIRKLICHE Zahl der Zwingen - eine kleine Aufspannung
## bekommt größere Netze, keine leeren Spalten.
func clamp_cell(u: float) -> float:
	var count := maxi(_clamped_dice().size(), 1)
	var inner := maxf(size.x - u * CONTENT_MARGIN_X * 2.0, u * 20.0)
	var column := (inner - u * BENCH_GAP * float(count - 1)) / float(count)
	return minf(DieNetView.cell_for(Vector2(column, column)), u * CLAMP_CELL_MAX)

## Steht die Aufspannung gerade auf der Bank? Solange ein Paket (Entsiegeln, Wahl,
## Einsetzen) oder ein Dossier das Fenster füllt, gibt es keine Netzzeile - und
## damit auch keine Spalte, über der ein Zwingen-Würfel schweben dürfte. scene_root
## lässt sie darum abtreten, statt sie an alten Plätzen stehen zu lassen; im
## Dossier hinge eine Zwinge sonst über der Seite, die genau sie zeigt. Pressung
## und Platzierung lassen sie STEHEN - sie sind die Ziele.
## Die KAMERA fragt hier nicht mit: die Bank ist aus jedem Blickwinkel bestückt.
func clamps_on_bench() -> bool:
	return _phase == Phase.STASH

## Die Würfel der Aufspannung (ohne Lauf leer).
func _clamped_dice() -> Array[DieDefinition]:
	var dice: Array[DieDefinition] = []
	if run != null:
		dice = run.clamped_dice
	return dice

## Mitten der Netzkacheln in Display-Pixeln - sie geben die SPALTEN vor, über
## denen scene_root die echten Zwingen-Würfel aufstellt.
func clamp_net_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for net in _clamp_nets:
		if is_instance_valid(net):
			centers.append(net.get_global_rect().get_center())
	return centers

## Die Würfel der ausliegenden Arbeits-Netze, in derselben Reihenfolge wie
## clamp_net_centers - scene_root findet daran das Netz zu einem Würfel.
func net_dice() -> Array[DieDefinition]:
	var dice: Array[DieDefinition] = []
	for net in _clamp_nets:
		if is_instance_valid(net):
			dice.append(net.def)
	return dice

## Die ZEILE dazu: Bildschirm-Höhe der Projektoren. Sie liegt im Fenster, ein
## Stück unter seinem oberen Rand - der Filzstreifen zwischen Trays und Bank ist
## fort. Ohne Layout die Fenstermitte.
func clamp_projector_y() -> float:
	for stage in _clamp_stage_hosts:
		if is_instance_valid(stage):
			return stage.get_global_rect().get_center().y
	return get_global_rect().get_center().y

## Das Konsolen-Band: es liegt GANZ unter dem Fenster, eine Naht unter seiner
## Kante - und dieselbe Naht trennt es von den Buchten. Über die ganze
## Fensterbreite, damit Sitz und Hinweiskarte ihre Flanken bekommen.
func console_band_rect() -> Rect2:
	var u := maxf(size.x, 200.0) / 100.0
	return Rect2(Vector2(0.0, size.y + u * CONSOLE_SHELF_GAP),
		Vector2(size.x, console_size(u).y))

## Fenster PLUS Schürze in Display-Pixeln: alles, was zur Werkbank gehört. Klick-
## Weiterleitung, Zeiger-Abfrage und Kamera messen sich daran, nicht am Fenster.
func bench_rect() -> Rect2:
	var rect := get_global_rect()
	rect.size.y = maxf(rect.size.y, apron_bottom_y())
	return rect

## Breite/Höhe des Fensters, bei dem die DOSSIER-Seite bündig aufgeht: links die
## Würfelspalte (so breit wie ihr Netz), rechts das 30er-Raster, dessen Kacheln
## die Inhaltshöhe genau füllen. Die Breite ist damit nicht mehr gesetzt, sondern
## gelöst - die Seite mit dem größten Anspruch gibt sie vor, und Band und Buchten
## darunter ziehen ohnehin mit.
## Alles außer der Fensterhöhe misst in u = Breite/100, die Gleichung schließt
## sich also über die Breite; die Höhe kürzt sich heraus, es bleibt ein reines
## Verhältnis.
static func dossier_aspect() -> float:
	var rows := ceili(float(GameRun.POOL_SIZE) / float(POOL_COLUMNS))
	var span := DiceGridView.detail_span(POOL_COLUMNS, rows)
	var ratio := span.x / span.y
	# Was die Breite VOR dem Raster verbraucht: beide Inhaltsränder, die
	# Netzspalte und die Fuge dazwischen.
	var used := CONTENT_MARGIN_X * 2.0 + DieNetView.net_size(CHOICE_CELL).x + BODY_GAP
	# Oben und unten steht auf DIESER Seite derselbe Rand wie zur Seite.
	return 100.0 * ratio / (100.0 - used + ratio * CONTENT_MARGIN_X * 2.0)

## Wie tief die Schürze unter der Fensterkante hängt, in Einheiten u: Naht,
## ganzes Konsolen-Band, Naht, Bucht-Streifen. scene_root löst damit die
## Fensterhöhe aus der Spanne bis zur Hub-Unterkante auf.
## Das Band wird in ECHTEN u gemessen und zurückgerechnet: seit der Schlitz die
## Kappe der Kassette schluckt, hängt seine Höhe an einem Weltmaß (data_cell_px)
## und nicht mehr allein an u - console_size(1.0) läse das als Einheiten.
func apron_units() -> float:
	var u := maxf(size.x, 200.0) / 100.0
	return CONSOLE_SHELF_GAP * 2.0 + console_size(u).y / u + SHELF_STRIP_UNITS

## Unterkante der Schürze in Fenster-Koordinaten (siehe apron_bottom). Ohne
## gemeldete Linie legt die Kette sie selbst - ein geratener Anteil hinge am
## Seitenverhältnis und fiele mit dem nächsten auseinander.
func apron_bottom_y() -> float:
	if apron_bottom > size.y:
		return apron_bottom
	return size.y + maxf(size.x, 200.0) / 100.0 * apron_units()

## Die sechs Leseschlitze als flache Leiste - Kante statt Bucht, eingelassen in
## ihr Konsolen-Blech. Ein belegter Schlitz leuchtet in der Sortenfarbe; ein Klick
## nimmt sein Paket zurück ins Regal, im Wurf würfelt er seine Walze neu.
## Das Blech steht MITTIG im Band, der Handlungs-Sitz in dessen rechter Flanke.
func _build_press_slots(u: float) -> void:
	var band := Control.new()
	band.name = "PressBand"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)  # direktes Kind: das Band liegt auf der Fensterkante
	_band = band
	var rect := console_band_rect()
	band.position = rect.position
	band.size = rect.size
	var console := _press_console(u)
	band.add_child(console)
	_build_action_seat(band, u)
	_build_info_screen(band, u)
	var row := HBoxContainer.new()
	row.name = "PressSlots"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = u * CONSOLE_PAD_X
	row.offset_right = -u * CONSOLE_PAD_X
	row.offset_top = u * CONSOLE_PAD_Y
	row.offset_bottom = -u * CONSOLE_PAD_Y
	row.add_theme_constant_override("separation", int(u * BENCH_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	console.add_child(row)
	var sorts := _slot_sorts()
	_press_portals.resize(PhantomPress.BATCH_CAP)
	for i in PhantomPress.BATCH_CAP:
		row.add_child(_press_slot(i, u, sorts[i] if i < sorts.size() else ""))

## Sorte je Leser: in der laufenden Pressung die der geschluckten Pakete, sonst die
## der vorgemerkten. press_slot_sorts bleibt bewusst die reine Vormerkung - daran
## hängen die Datenzellen, und die sind in der Pressung längst geschluckt.
func _slot_sorts() -> Array[String]:
	return _press_sorts if pressing() else press_slot_sorts()

## Das Blech hinter der Schlitzreihe: erhabene Platte in neutralem Dunkelmetall.
## Es hängt mittig im Band - der Sitz daneben darf es nicht verschieben.
func _press_console(u: float) -> Panel:
	var console := Panel.new()
	console.name = "PressConsole"
	console.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var span := console_size(u)
	console.anchor_left = 0.5
	console.anchor_right = 0.5
	console.anchor_bottom = 1.0
	console.offset_left = -span.x * 0.5
	console.offset_right = span.x * 0.5
	_console = console
	var radius := int(u * CONSOLE_RADIUS)
	var box := StyleBoxFlat.new()
	box.bg_color = CONSOLE_BASE
	box.set_corner_radius_all(radius)
	box.shadow_color = PackDrawerView.LIP_DROP
	box.shadow_size = maxi(2, int(u * PackDrawerView.LIP_DROP_SIZE))
	box.shadow_offset = Vector2(0.0, maxf(2.0, u * PackDrawerView.LIP_DROP_DOWN))
	console.add_theme_stylebox_override("panel", box)
	var edge := maxi(2, int(u * CONSOLE_EDGE))
	console.add_child(PackDrawerView.edge_band("ConsoleLight",
		CONSOLE_BASE.lerp(CONSOLE_SHEEN, CONSOLE_SHEEN_MIX), edge, radius, true))
	console.add_child(PackDrawerView.edge_band("ConsoleShade", CONSOLE_SHADOW,
		edge, radius, false))
	return console

## Maße des Blechs: die sechs Plätze mit ihrer Luft dazwischen, plus Rand.
func console_size(u: float) -> Vector2:
	var slot := socket_size(u)
	var columns := float(BENCH_COLUMNS)
	var row := columns * slot.x + (columns - 1.0) * u * BENCH_GAP
	return Vector2(row + u * CONSOLE_PAD_X * 2.0, slot.y + u * CONSOLE_PAD_Y * 2.0)

## Die Vertiefung, in der Anzeigefeld und Schlitz eines Platzes liegen.
func _slot_pocket(u: float) -> Panel:
	var pocket := Panel.new()
	pocket.name = "SlotPocket"
	pocket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pocket.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bleed := u * POCKET_BLEED
	pocket.offset_left = -bleed
	pocket.offset_top = -bleed
	pocket.offset_right = bleed
	pocket.offset_bottom = bleed
	var radius := int(u * POCKET_RADIUS)
	var box := StyleBoxFlat.new()
	box.bg_color = POCKET_BASE
	box.set_corner_radius_all(radius)
	pocket.add_theme_stylebox_override("panel", box)
	var edge := maxi(2, int(u * POCKET_EDGE))
	pocket.add_child(PackDrawerView.edge_band("PocketShade", POCKET_SHADOW, edge, radius, true))
	pocket.add_child(PackDrawerView.edge_band("PocketLight", POCKET_SHEEN, edge, radius, false))
	return pocket

## Der EINE Handlungs-Sitz, rechts neben dem Blech: "Pressen (n)", und solange
## Beute liegt "Fertig". Sein Rechteck ist in JEDEM Zustand dasselbe - der Sitz ist
## ein fester Platz, die Aufschrift wechselt darin. Der Pressen-Knopf erscheint
## weiterhin erst mit dem ersten belegten Platz (ein leerer Knopf wäre bloß eine
## Frage ohne Gegenstand); der Sitz selbst steht trotzdem.
func _build_action_seat(band: Control, u: float) -> void:
	var seat := Control.new()
	seat.name = "ActionSeat"
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(seat)
	var span := action_size(u)
	var button := _seat_button(u)
	if button != null:
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		seat.add_child(button)
		# Erst im Baum messen: die Zeilenhöhe der Schrift ist der wahre Boden des
		# Sitzes - und sie ist für alle drei Aufschriften dieselbe.
		span.y = maxf(span.y, button.get_combined_minimum_size().y)
	seat.anchor_left = 1.0
	seat.anchor_right = 1.0
	seat.anchor_top = 0.5
	seat.anchor_bottom = 0.5
	seat.offset_left = -span.x - u * ACTION_GAP
	seat.offset_right = -u * ACTION_GAP
	seat.offset_top = -span.y * 0.5
	seat.offset_bottom = span.y * 0.5

## Der Knopf, der gerade auf dem Sitz steht (null = keiner). Zwei Zustände, denn
## die Pressung ist EIN Griff: es gibt keinen Stand zwischen Wurf und Beute mehr.
## Liegt Beute UND steckt ein Paket, gewinnt das Pressen - nachpressen ist erlaubt,
## und der Weg zum Fertig ist eine Auswurf-Taste entfernt.
func _seat_button(u: float) -> Button:
	if placing() and _selected_packs.is_empty():
		_apply_button = _seat_fit(_action_button("Fertig", GOLD, u, apply_placements), u)
		_apply_button.disabled = editing_locked
		return _apply_button
	_press_button = _seat_fit(
		_action_button("Pressen (%d)" % _selected_packs.size(), GOLD, u, start_press), u)
	_press_button.disabled = not can_press()
	_press_button.visible = not _selected_packs.is_empty()
	_seat_press_hint(_press_button)
	return _press_button

## Darf jetzt gepresst werden? Die Energie ist die einzige Bremse, die der Preis
## selbst setzt - alles andere ist Zustand der Bank.
func can_press() -> bool:
	return run != null and not editing_locked and not inspecting() and not pressing() \
		and not _selected_packs.is_empty() and run.can_press()

## Was eine Pressung kostet, steht NICHT auf dem Knopf (sein Rechteck ist fest) -
## sie sagt es dem Hinweis-Schirm, sobald der Zeiger sie greift.
func _seat_press_hint(button: Button) -> void:
	if run == null:
		return
	var cost := run.press_cost()
	var body := "Die erste Pressung der Runde ist frei."
	if cost > 0:
		body = "Diese Pressung kostet %d Energie." % cost
	button.set_meta("title", "Pressung")
	button.set_meta("body", body)
	if run.charge < cost:
		button.set_meta("body", "%s Die Bank hält %d." % [body, run.charge])
		button.set_meta("tint", CasinoStyle.RED)
	button.tooltip_text = String(button.get_meta("body", ""))

## Zwingt einen Knopf auf das Sitzmaß: clip_text nimmt der Aufschrift das Recht,
## das Rechteck zu verbreitern - erst dadurch ist der Sitz in jedem Zustand gleich.
func _seat_fit(button: Button, u: float) -> Button:
	button.clip_text = true
	button.custom_minimum_size = action_size(u)
	return button

## Maße des Sitzes: EIN Rechteck für alle drei Aufschriften, bemessen an der
## breitesten ("Pressen (6)").
func action_size(u: float) -> Vector2:
	return Vector2(u * ACTION_WIDTH, u * ACTION_HEIGHT)

## Das Magazin: EIN eingelassenes Fach über die volle Fensterbreite, je Paket
## seine eigene Kassette. Es ist die einzige Auslage versiegelter Ware - im
## Fenster steht nie eine Paketkarte.
func _build_drawer(u: float) -> void:
	_drawer = PackDrawerView.new()
	_drawer.pack_pressed.connect(_on_pack_pressed)
	_drawer.packs_reordered.connect(_on_packs_reordered)
	_drawer.tidy_requested.connect(_on_tidy_requested)
	add_child(_drawer)  # direktes Kind: das Fach liegt AUSSERHALB des Fensters
	var rect := shelf_rect()
	_drawer.position = rect.position
	_drawer.size = rect.size
	_drawer.build(drawer_entries(), u, shelf_locked(), data_cell_px, rect.size)
	if not _queued_pops.is_empty():
		_flush_queued_pops.call_deferred()  # der Pluster braucht das fertige Layout

## Der Streifen des Magazins: AUSSERHALB des Fensters, auf der GANZEN
## Fensterbreite (ganze Pixel, damit die Platz-Rechnung nicht driftet).
func shelf_strip_size() -> Vector2:
	var u := maxf(size.x, 200.0) / 100.0
	return Vector2(floorf(maxf(size.x, u * 20.0)),
		maxf(apron_bottom_y() - shelf_top(), u * SHELF_MIN_HEIGHT))

## Oberkante der Buchten: eine Naht unter dem Konsolen-Band. Der Abstand zur
## Konsole ist gesetzt, die HÖHE der Buchten folgt daraus - sie enden auf der
## Hub-Unterkante.
func shelf_top() -> float:
	return console_band_rect().end.y + maxf(size.x, 200.0) / 100.0 * CONSOLE_SHELF_GAP

## Der Platz des Regals: unter dem Band, mittig auf der Fensterbreite.
func shelf_rect() -> Rect2:
	var strip := shelf_strip_size()
	return Rect2(Vector2(roundf((size.x - strip.x) * 0.5), shelf_top()), strip)

## Derselbe Platz in Display-Pixeln (der Streifen misst sich am Fenster).
func shelf_rect_global() -> Rect2:
	var rect := shelf_rect()
	rect.position += get_global_rect().position
	return rect

## Das LOCH des Magazins in Display-Pixeln: der Streifen abzüglich seiner gemalten
## Fassung. scene_root schneidet danach das Glas und stellt die Grube darunter -
## das Fenster selbst weiß vom Tisch nichts.
func shelf_pit_rect() -> Rect2:
	return PackDrawerView.pit_rect_in(shelf_rect_global(), shelf_unit())

## Eckenradius des Lochs: der des Rahmens, um dessen Breite verkleinert.
func shelf_pit_radius() -> float:
	var unit := shelf_unit()
	return maxf(unit * PackDrawerView.RADIUS - PackDrawerView.rim_inset(unit), 0.0)

## Die Maßeinheit, in der die Schürze rechnet (u = Fensterbreite/100).
func shelf_unit() -> float:
	return maxf(size.x, 200.0) / 100.0

## Das Zellmaß, an dem sich das Magazin misst (ohne gemeldetes das Rückfallmaß).
func shelf_cell_px() -> Vector2:
	if data_cell_px.x > 0.0 and data_cell_px.y > 0.0:
		return data_cell_px
	return PackDrawerView.fallback_cell(maxf(size.x, 200.0) / 100.0)

## Anzeige-Maßstab der Magazin-Kassetten (scene_root skaliert die Körper darauf).
## Er steht auch, wenn das Fach gerade nicht gebaut ist - ein Rückläufer muss
## wissen, wie groß er liegt, während das Fenster einem Paket gehört.
func shelf_cell_scale() -> float:
	if _drawer != null and is_instance_valid(_drawer):
		return _drawer.cell_scale()
	return PackDrawerView.cell_scale_for(shelf_cell_px(),
		shelf_pit_rect().size, drawer_entries().size())

## Die Kassette unter dem Display-Pixel (0 = keine): scene_root zieht daran den
## Körper ein Stück aus der Grube. Gefragt, nicht gemeldet - der Zeiger liegt auf
## dem Tisch.
func shelf_hover_uid_at(pixel: Vector2) -> int:
	if _drawer != null and is_instance_valid(_drawer):
		return _drawer.hover_uid_at(pixel)
	return 0

## Ankunfts-Pluster, die auf ihr Fach gewartet haben (es stand während der
## Lieferung nicht da - Presse, Wahl oder Dossier füllten das Fenster).
func _flush_queued_pops() -> void:
	if _drawer == null or not is_instance_valid(_drawer):
		return
	for uid in _queued_pops:
		pack_landed.emit(uid)
	_queued_pops.clear()

## Die Restluft sammelt sich UNTEN - dort steht die Hinweiskarte, und nichts über
## ihr verrutscht, wenn eine Zeile dazukommt oder wegfällt.
func _bottom_slack() -> Control:
	return _slack("BenchSlack")

## Eine dehnbare Leerzeile. Zwei davon, oben und unten, zentrieren einen Block.
func _slack(slack_name: String) -> Control:
	var slack := Control.new()
	slack.name = slack_name
	slack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slack

## Ein Presse-Platz: seine Tasche im Blech, darin oben das Anzeigefeld (das
## PORTAL) und darunter der Leseschlitz. Der KNOPF spannt alles und fängt allein
## Klick und Zeiger - gezeichnet wird von seinen Kindern, die keine Maus sehen.
## Seine EINZIGE Rolle: ein Klick gibt das eingelegte Paket zurück ins Regal.
func _press_slot(index: int, u: float, sort: String) -> Button:
	var slot := Button.new()
	slot.name = "PressSlot"
	slot.focus_mode = Control.FOCUS_NONE
	slot.custom_minimum_size = socket_size(u)
	slot.disabled = true
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		slot.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	slot.add_child(_slot_pocket(u))

	var column := VBoxContainer.new()
	column.name = "SlitColumn"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", int(u * SLIT_DISPLAY_GAP))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var display := _slit_display(sort, u, index)
	column.add_child(display)
	var slit := Panel.new()
	slit.name = "Slit"
	slit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slit.custom_minimum_size = slit_size(u)
	slit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slit.add_theme_stylebox_override("panel", _slit_box(_socket_tint(sort), u))
	column.add_child(slit)
	slot.add_child(column)

	_arm_eject(slot, index)
	_press_slot_buttons.append(slot)
	_press_slit_panels.append(slit)
	_press_display_panels.append(display)
	return slot

## Grundseite: ein Klick auf den belegten Platz nimmt sein Paket zurück ins Magazin.
func _arm_eject(slot: Button, index: int) -> void:
	if index >= _selected_packs.size() or run == null:
		return
	var pack := run.pack_by_uid(_selected_packs[index])
	if pack == null:
		return
	slot.disabled = editing_locked
	slot.tooltip_text = pack.description
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.pressed.connect(clear_press_slot.bind(index))

## Name und Wirkung eines Beutestücks für den Hinweis-Schirm. Aus der Presse
## kommt jedes Stück flach - der Text steht darum auf Stufe 1; Material und
## Sonderposten haben keine Leiter und behalten ihren Grundtext.
func _seat_piece_hint(button: Button, engraving_id: String) -> void:
	var archetype := Engraving.by_id(engraving_id)
	if archetype == null:
		return
	var body := Engraving.stufe_text(engraving_id, 1)
	if body == "":
		body = archetype.description
	button.set_meta("title", archetype.display_name)
	button.set_meta("body", body)
	button.tooltip_text = "%s\n%s" % [archetype.display_name, body]

## Das Anzeigefeld über einem Schlitz - der Leser selbst, und er ist ein PORTAL:
## leer dunkel, belegt trägt es das Siegel seiner Sorte (dieselbe Zeichnung wie
## auf der Zelle), in der Pressung wirbelt es und entlädt sich.
func _slit_display(sort: String, u: float, index: int) -> Panel:
	var side := display_side(u)
	var field := Panel.new()
	field.name = "SlitDisplay"
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.clip_contents = true
	field.custom_minimum_size = Vector2.ONE * side
	field.add_theme_stylebox_override("panel", _display_box(_socket_tint(sort), u))
	var portal := PressPortalView.new()
	portal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.add_child(portal)
	portal.setup(sort, index, side)
	_press_portals[index] = portal
	return field

## Maße eines ganzen Platzes (Feld + Luft + Schlitz) und des Schlitzes allein.
func socket_size(u: float) -> Vector2:
	var side := display_side(u)
	return Vector2(side, side + u * SLIT_DISPLAY_GAP + slit_size(u).y)

## Kantenlänge des Anzeigefeldes: nie schmaler als der Schlitz darunter - der
## Leser wächst mit der Kassette, die er schluckt.
func display_side(u: float) -> float:
	return maxf(u * SLIT_DISPLAY, slit_size(u).x)

## Der Schlitz: so groß, dass die Kappe der Zelle hindurchgeht - in ihrem festen
## Anzeigemaß, denn genau so steckt sie später darin. Bewusst flach.
func slit_size(u: float) -> Vector2:
	var cap := data_cell_px * PackDrawerView.CASSETTE_SCALE * SOCKET_ROOM
	return Vector2(maxf(u * PRESS_SLOT, cap.x), maxf(u * SLIT_HEIGHT, cap.y))

## Die Farbe eines Platzes: leer der stumpfe Rand, belegt die Sortenfarbe - eine
## Quelle für Schlitzrand und Anzeigefeld.
func _socket_tint(sort: String) -> Color:
	if sort == "":
		return SOCKET_RIM
	return PackDrawerView.COLORS.get(sort, SOCKET_LIVE_RIM)

func _slit_box(rim: Color, u: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = SOCKET_BG
	box.border_color = rim
	box.set_border_width_all(maxi(1, int(u * 0.18)))
	box.set_corner_radius_all(int(slit_size(u).y * 0.35))
	return box

## Der Rahmen des Anzeigefeldes: leer der stumpfe Rand, gebucht die Sortenfarbe.
func _display_box(rim: Color, u: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = SOCKET_BG
	box.border_color = Color(rim.r, rim.g, rim.b, rim.a * 0.7)
	box.set_border_width_all(maxi(1, int(u * 0.14)))
	box.set_corner_radius_all(int(u * 0.4))
	return box

## Die Sorten der belegten Presse-Plätze, in Platz-Reihenfolge - scene_root legt
## daran seine Zellen ab.
func press_slot_sorts() -> Array[String]:
	var sorts: Array[String] = []
	if run == null:
		return sorts
	for uid in _selected_packs:
		var pack := run.pack_by_uid(uid)
		if pack != null:
			sorts.append(Pack.shelf_of(pack))
	return sorts

## Die uids derselben Reihe - scene_root übernimmt daran die Magazin-Körper in
## die Schlitze und gibt sie beim Auswerfen an ihre Plätze zurück.
func press_slot_uids() -> Array[int]:
	return _selected_packs.duplicate()

## Display-Pixel der SCHLITZ-Mitten (leere eingeschlossen) - dort steckt die Zelle
## eines belegten Platzes. Nicht die Knopfmitte: der Knopf reicht bis über das
## Anzeigefeld, die Zelle steht im Schlitz.
func press_slot_anchors() -> Array[Vector2]:
	var anchors: Array[Vector2] = []
	for slit in _press_slit_panels:
		if is_instance_valid(slit):
			anchors.append(slit.get_global_rect().get_center())
	return anchors

## Display-Pixel der ANZEIGEFELDER derselben Reihe (leere eingeschlossen) - dort
## wirbeln die Portale, und von dort starten die Meteore der Beute.
func press_display_anchors() -> Array[Vector2]:
	var anchors: Array[Vector2] = []
	for field in _press_display_panels:
		if is_instance_valid(field):
			anchors.append(field.get_global_rect().get_center())
	return anchors

## Läuft die Presse gerade? Genau solange, wie noch Beute unterwegs ist: der
## Automat ist fertig, wenn sein letzter Meteor liegt.
func pressing() -> bool:
	return not _withheld.is_empty()

## Ein Würfel-Paket hat die Bank: entsiegeln, wählen, einsetzen.
func _pack_flow() -> bool:
	return _phase == Phase.UNSEAL or _phase == Phase.CHOOSE_DIE or _phase == Phase.PLACE_DICE

## Das Regal ist zu: unterschrieben, der Automat läuft - oder ein Paket bzw. das
## Dossier hat die Bank. Niemand legt einem laufenden Automaten ein Paket nach,
## und wer gerade einen Würfel aussucht, entsiegelt nicht nebenher den nächsten.
## Eine LIEGENDE Ablage sperrt dagegen nichts mehr: nachpressen ist erlaubt, die
## Stücke legen sich dazu. Die Buchten STEHEN durch all das - sie fassen nur
## nichts an.
func shelf_locked() -> bool:
	return editing_locked or pressing() or _pack_flow() or inspecting()

## Legt GENAU dieses Paket in den nächsten freien Presse-Platz. false = kein
## Gravur-Paket, kein Platz frei oder das Magazin ist zu.
func slot_pack(uid: int) -> bool:
	if run == null or shelf_locked():
		return false
	if _selected_packs.size() >= PhantomPress.BATCH_CAP:
		return false
	var pack := run.pack_by_uid(uid)
	if pack == null or pack.is_dice_pack():
		return false
	if _selected_packs.has(uid) or _pending_arrivals.has(uid):
		return false
	_selected_packs.append(uid)
	refresh()
	return true

## Legt das VORDERSTE Paket einer Sorte ein - der programmatische Griff (Tests,
## Debug); am Tisch wählt der Spieler seine Kassette selbst.
func slot_pack_from_stack(stack_category: String) -> bool:
	if run == null:
		return false
	for pack in run.owned_packs:
		if _selected_packs.has(pack.pack_uid) or _pending_arrivals.has(pack.pack_uid):
			continue
		if not Pack.pack_belongs(pack, stack_category):
			continue
		return slot_pack(pack.pack_uid)
	return false

## Öffnet das VORDERSTE Würfel-Paket des Magazins (Tests, Debug) - es läuft nie
## durch die Presse.
func open_top_dice_pack() -> bool:
	if run == null or shelf_locked():
		return false
	for pack in run.owned_packs:
		if pack.is_dice_pack() and not _pending_arrivals.has(pack.pack_uid):
			open_pack_uid(pack.pack_uid)
			return true
	return false

## Nimmt ein Paket wieder aus seinem Presse-Platz - es liegt danach wieder auf
## seinem Magazin-Platz. Gemeldet wird VOR dem Neuaufbau: die Zelle dieses
## Platzes muss sich ausklinken, bevor die Sockel neu abgezählt werden.
func clear_press_slot(index: int) -> void:
	if index < 0 or index >= _selected_packs.size() or editing_locked:
		return
	var uid := _selected_packs[index]
	_selected_packs.remove_at(index)
	pack_unslotted.emit(index, uid)
	refresh()

# --- Das Magazin (versiegelte Ware) ---------------------------------------------

## Je Paket {uid, pack, withheld} in Magazin-Ordnung (= run.owned_packs). Was in
## einem Presse-Platz steckt, fehlt ganz; was noch als Licht fliegt, hält seinen
## Platz und bleibt bis zur Landung verdeckt.
func drawer_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if run == null:
		return entries
	for pack in run.owned_packs:
		if _selected_packs.has(pack.pack_uid):
			continue
		entries.append({"uid": pack.pack_uid, "pack": pack,
			"withheld": _pending_arrivals.has(pack.pack_uid)})
	return entries

## Ein Paket ist unterwegs: sein Platz steht, sein Chip erscheint erst mit der
## Landung (scene_root ruft das VOR dem Kometen).
func expect_pack_delivery(uid: int) -> void:
	_pending_arrivals[uid] = true
	refresh()

## Das Liefer-Licht ist angekommen: die Kassette kommt zum Vorschein und ploppt.
func deliver_pack(uid: int) -> void:
	if not _pending_arrivals.has(uid):
		return
	_pending_arrivals.erase(uid)
	refresh()
	if _drawer != null and is_instance_valid(_drawer):
		pack_landed.emit(uid)
		return
	_queued_pops.append(uid)  # das Fach steht gerade nicht - er wartet auf es

## Display-Pixel eines Magazin-Platzes - Standplatz des Körpers und Ziel der
## Liefer-Kometen. Steht das Fach gerade nicht (Presse, Wahl), wird der Platz
## GERECHNET - dieselbe Formel, damit ein Komet nicht springt, sobald es
## zurückkommt. Auch ein RESERVIERTES Paket bekommt eine Antwort: den Platz, auf
## den es beim Auswerfen zurückkehrt.
func pack_anchor_px(uid: int) -> Vector2:
	if _drawer != null and is_instance_valid(_drawer):
		var anchor := _drawer.pack_anchor_px(uid)
		if anchor.x >= 0.0:
			return anchor
	var index := -1
	var count := 0
	if run != null:
		for pack in run.owned_packs:
			if _selected_packs.has(pack.pack_uid) and pack.pack_uid != uid:
				continue
			if pack.pack_uid == uid:
				index = count
			count += 1
	var derived := PackDrawerView.anchor_in(shelf_pit_rect(), index, count,
		shelf_cell_px())
	return derived if derived.x >= 0.0 else shelf_rect_global().get_center()

## Der Platz, auf dem die NÄCHSTE Lieferung landet (extra staffelt eine Salve):
## hinten anschließend - eine Lieferung verrückt nie, was der Spieler sortiert hat.
func arrival_anchor_px(extra: int = 0) -> Vector2:
	var count := drawer_entries().size()
	return PackDrawerView.anchor_in(shelf_pit_rect(), count + extra,
		count + extra + 1, shelf_cell_px())

## Eine Kassette wurde angetippt: Gravur-Pakete wandern in den nächsten freien
## Presse-Platz, Würfel-Pakete öffnen sofort ihre Wahl auf der Bank.
func _on_pack_pressed(uid: int) -> void:
	var pack := run.pack_by_uid(uid) if run != null else null
	if pack == null:
		return
	if pack.is_dice_pack():
		if not shelf_locked():
			open_pack_uid(uid)
		return
	slot_pack(uid)

## Kassette auf Kassette gezogen: das Magazin legt um - dieselbe remove/insert-
## Semantik wie reorder_pool, und die Körper auf dem Glas gleiten hinterher
## (uid-gebundene Zellen, scene_root).
func _on_packs_reordered(from_uid: int, to_uid: int) -> void:
	if run == null or shelf_locked():
		return
	run.reorder_packs(run.pack_index_of(from_uid), run.pack_index_of(to_uid))

## Doppelklick auf leere Fach-Fläche: aufräumen nach Sorte, Inhalt, uid.
func _on_tidy_requested() -> void:
	if run == null or shelf_locked():
		return
	run.tidy_packs()

# --- Der Platzierungs-Schritt (die Beute in der Ablage) ------------------------
# Keine losen Aufwertungen: die gepresste Beute LIEGT auf der Werkbank und muss
# von dort ihre Plätze finden. Der Schritt hängt allein an ihr - damit übersteht
# er jede Kamerafahrt, den Laden und jeden Neuaufbau des Fensters, und die Bank
# ist erst wieder frei, wenn jedes Stück sitzt oder verpufft ist.

## Der Schritt steht, solange etwas offen ist ODER etwas nass liegt: eine leere
## Hand beendet ihn NICHT mehr - erst das Fertig macht den Guss hart, und bis
## dahin gehört die Bank ihm (Herausnehmen inbegriffen).
func placing() -> bool:
	if run == null:
		return false
	return not run.press_pieces.is_empty() or not run.press_journal.is_empty()

## Offene Anwendungen der Hand je Gravur-id.
func press_piece_counts() -> Dictionary:
	var counts := {}
	if run == null:
		return counts
	for piece in run.press_pieces:
		var id := String(piece.get("id", ""))
		if id == "":
			continue
		counts[id] = int(counts.get(id, 0)) + int(piece.get("applications", 1))
	return counts

## Die Nummer eines Stücks - der Griff, an dem Chip, Platz und Führung hängen.
## Von Hand gelegte Stücke (Tests) tragen keine: sie bekommen eine aus ihrem
## Index, die genauso stabil steht, solange der Haufen sich nicht verschiebt.
func _piece_uid(piece: Dictionary, index: int) -> int:
	var uid := int(piece.get("piece_uid", 0))
	return uid if uid != 0 else -(index + 1)

## Index dieses Stücks in run.press_pieces (-1 = liegt nicht mehr da).
func _piece_index(uid: int) -> int:
	if run == null or uid == 0:
		return -1
	for i in run.press_pieces.size():
		if _piece_uid(run.press_pieces[i], i) == uid:
			return i
	return -1

## Das geführte Stück ({} = keins).
func _held_piece() -> Dictionary:
	var index := _piece_index(_held_uid)
	return run.press_pieces[index] if index >= 0 else {}

## Welche Gravur gerade geführt wird ("" = keine) - das Netz zielt danach.
func held_piece_id() -> String:
	return String(_held_piece().get("id", ""))

## Die Nummer des geführten Stücks (0 = keins).
func held_uid() -> int:
	return _held_uid

## Stufe, auf der das geführte Stück wirkt - sie steht in der Beute, nicht am
## Werkzeug (aus der Presse ist sie immer 1).
func _held_stufe() -> int:
	return int(_held_piece().get("stufe", 1))

## Es liegt IMMER ein Stück in der Hand, und nach einer Setzung rückt die NÄCHSTE
## GLEICHE Gravur nach, solange noch eine liegt - wer eine Reihe Kerben setzt, will
## nicht nach jedem Klick neu greifen. Erst wenn dieser Stapel leer ist, greift die
## Hand ans LINKE ENDE der Reihe: ablage_order IST diese Reihe (auch eine
## eingefrorene hat ihre Plätze in dieser Folge bekommen).
func _sync_held() -> void:
	if _piece_index(_held_uid) >= 0:
		return
	if run == null or run.press_pieces.is_empty():
		_held_uid = 0
		_held_id = ""
		_clear_pair()
		return
	var order := ablage_order()
	var pick: int = order[0]
	for uid in order:
		if _piece_id(uid) == _held_id:
			pick = uid
			break
	_held_uid = pick
	_held_id = _piece_id(pick)
	_clear_pair()

func _clear_pair() -> void:
	_first_face = -1
	_first_die = null

## Nimmt ein Stück aus der Ablage in die Hand (das vorige legt es dabei ab).
func hold_piece(uid: int) -> void:
	var index := _piece_index(uid)
	if not placing() or index < 0:
		return
	_held_uid = uid
	_held_id = _piece_id(uid)
	_clear_pair()
	refresh()

## "Fertig": der einzige Abschluss des Schritts, und er steht IMMER offen. Was noch
## in den Lesern liegt, zahlt er als Restwert aus - einzeln verkauft wird kein
## Stück. Macht den nassen Guss hart (beides bucht GameRun); press_changed beendet
## den Schritt über den normalen Neuaufbau.
func apply_placements() -> void:
	if run == null or editing_locked:
		return
	var cash := run.press_cash_out_value()
	var anchor := hand_anchor_px()
	if run.apply_press_placements() and cash > 0:
		press_cashed_out.emit(cash, anchor)

# --- Ziel-Klicks im Netz --------------------------------------------------------

## Klick auf eine Netz-Zelle: das geführte Stück sucht hier seinen Platz. Ohne
## Stück in der Hand ist das Netz reine Anzeige.
func _on_net_face_pressed(face: int, die: DieDefinition) -> void:
	if run == null or editing_locked or not placing():
		return
	var piece := _piece_index(_held_uid)
	if piece < 0 or not run.press_target_allowed(die):
		return
	# Die id und den Platz des Chips VOR dem Setzen merken: das Buchen räumt das
	# Stück ab und rückt die Hand nach - danach wüsste niemand mehr, was gerade
	# geflogen ist und von wo.
	var placed := String(run.press_pieces[piece].get("id", ""))
	var from_px := piece_anchor_px(_held_uid)
	match PressTargeting.kind_of(placed):
		PressTargeting.TARGET_WHOLE_DIE:
			_book(run.apply_press_number(piece, die, _faces([])), die, placed, from_px)
		PressTargeting.TARGET_PAIR_DIRECTED:
			_pair_click(piece, die, face, placed, from_px)
		_:
			if PressTargeting.face_eligible(die, placed, face):
				_book(_apply_single(piece, die, face, placed), die, placed, from_px)

## Gerichtete Paare lesen Quelle → Ziel. Der zweite Klick muss auf DENSELBEN
## Würfel fallen - ein Meißel schöpft nicht aus einem fremden Körper; ein Klick
## auf die Quelle nimmt sie zurück.
func _pair_click(piece: int, die: DieDefinition, face: int, placed: String,
		from_px: Vector2) -> void:
	if _first_die != die or _first_face < 0:
		if not PressTargeting.face_eligible(die, placed, face):
			return
		_first_die = die
		_first_face = face
		refresh()
		return
	if face == _first_face:
		_clear_pair()
		refresh()
		return
	if not PressTargeting.face_eligible(die, placed, face, _first_face):
		return
	var done := false
	if placed == Engraving.POINTER:
		done = run.apply_press_pointer(piece, die, _first_face, face)
	else:
		done = run.apply_press_number(piece, die, _faces([_first_face, face]))
	_book(done, die, placed, from_px)

## Einseitige Stücke: Material, Rune oder Kerbe auf die geklickte Seite.
func _apply_single(piece: int, die: DieDefinition, face: int, placed: String) -> bool:
	if DieMaterial.is_valid_id(placed):
		return run.apply_press_material(piece, die, face)
	if Engraving.is_rune_id(placed):
		return run.apply_press_rune(piece, die, face,
			PressTargeting.free_rune_slot(die, face, run.extra_rune_slots()))
	if placed == Engraving.DOPING:
		return run.apply_press_doping(piece, die, face)
	if placed == Engraving.NOTCH:
		return run.apply_press_number(piece, die, _faces([face]))
	return false

## Nach einer Setzung: das Paar ist verbraucht, und der Würfel meldet den Treffer
## (scene_root lässt seinen Projektor aufblitzen). Neu gebaut wird über
## press_changed - GameRun hat da längst gebucht.
func _book(done: bool, die: DieDefinition, engraving_id: String, from_px: Vector2) -> void:
	if not done:
		return
	_clear_pair()
	piece_placed.emit(die, engraving_id, from_px)

## Klick auf die Plakette einer nassen Setzung: sie kommt wieder heraus und liegt
## danach zurück in der Hand. Die Schicht-Regel entscheidet in GameRun.
func _on_net_mark_pressed(face: int, die: DieDefinition) -> void:
	if run == null or editing_locked:
		return
	var index := run.press_mark_at(die, face)
	if index >= 0:
		run.unseat_press_piece(index)

## GDScript wandelt ein untypisiertes Literal nicht in Array[int] - die Presse
## verlangt es getypt.
func _faces(values: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(values)
	return typed

## Display-Pixel eines Beutestücks: der Platz SEINES Chips in der Ablage - dort
## liegt es, und von dort startet sein Licht.
func piece_anchor_px(uid: int) -> Vector2:
	return ablage_spot_px(uid)

## Display-Pixel der Konsole (ohne sie die Fenstermitte) - über ihr steigt die
## Restwert-Zahl des Fertig auf: die Hand IST die Leserreihe.
func hand_anchor_px() -> Vector2:
	if _console != null and is_instance_valid(_console) and _console.get_global_rect().size.x > 0.0:
		return _console.get_global_rect().get_center()
	return get_global_rect().get_center()

# --- Die Ablage (die Beute liegt auf dem Glas) ---------------------------------
# Nach der Pressung LIEGEN die Stücke da: nackte Chips im freien Band unter der
# Netzzeile, ohne Kachel und ohne Rahmen (Chip-Schalen-Regel). Ihr Platz folgt
# allein aus ihrer Nummer - ein Neuaufbau legt denselben Haufen, und ein
# gesetztes Stück verrückt keinen Nachbarn.

## Der Streifen der Ablage in Fenster-Koordinaten: volle Inhaltsbreite, Unterkante
## am Inhaltsrand. Er hängt am FENSTER, nicht am Zeilenfluss - darum verrückt ihn
## keine Zwinge und kein Chip.
func ablage_rect() -> Rect2:
	var u := maxf(size.x, 200.0) / 100.0
	var height := u * ABLAGE_STRIP
	return Rect2(Vector2(u * CONTENT_MARGIN_X, size.y - u * CONTENT_MARGIN_Y - height),
		Vector2(maxf(size.x - u * CONTENT_MARGIN_X * 2.0, u * 20.0), height))

## Kantenlänge eines Chips: die drei Reihen füllen den Streifen, gedeckelt.
func ablage_chip_size() -> float:
	var u := maxf(size.x, 200.0) / 100.0
	var rows := float(ABLAGE_ROWS)
	return minf((ablage_rect().size.y - u * ABLAGE_ROW_GAP * (rows - 1.0)) / rows,
		u * ABLAGE_CHIP_MAX)

func _ablage_columns() -> int:
	var pitch := maxf(ablage_chip_size() * ABLAGE_COLUMN_PITCH, 1.0)
	return maxi(int(ablage_rect().size.x / pitch), 1)

## Ein Streuwert -1..1 aus den Bits einer Nummer - dieselbe Nummer, dieselbe Lage.
func _ablage_jitter(key: int, shift: int) -> float:
	return float((key >> shift) & 0xff) / 127.5 - 1.0

## Der Platz EINES Stücks in Fenster-Koordinaten (Mitte seines Chips): in der
## Reihe, sobald es aufgeräumt ist - sonst der Rasterplatz samt Streuung aus
## seiner Nummer. Zwei Stücke im Haufen dürfen sich überlagern, es IST ein Haufen.
func ablage_spot(uid: int) -> Vector2:
	if _ablage_order.has(uid):
		return _ablage_row_spot(int(_ablage_order[uid]))
	var u := maxf(size.x, 200.0) / 100.0
	var rect := ablage_rect()
	var chip := ablage_chip_size()
	var columns := _ablage_columns()
	var key := absi(hash(uid))
	var slot := key % (columns * ABLAGE_ROWS)
	var pitch := rect.size.x / float(columns)
	var at := rect.position + Vector2(pitch * (float(slot % columns) + 0.5),
		(chip + u * ABLAGE_ROW_GAP) * float(slot / columns) + chip * 0.5)
	at += Vector2(_ablage_jitter(key, 9), _ablage_jitter(key, 17)) * chip * ABLAGE_JITTER
	return _in_strip(at, rect, chip)

## Der Platz slot in der aufgeräumten Reihe: feste Teilung, jede Zeile für sich
## mittig, der Block mittig im Streifen - keine Streuung, das IST der Unterschied
## zum Haufen. Reicht die Reihe nicht, rücken die Spalten enger, statt eine
## vierte Zeile aus dem Streifen zu schieben.
func _ablage_row_spot(slot: int) -> Vector2:
	var u := maxf(size.x, 200.0) / 100.0
	var rect := ablage_rect()
	var chip := ablage_chip_size()
	var columns := maxi(mini(_ablage_slots, _ablage_columns()), 1)
	var rows := maxi(ceili(float(_ablage_slots) / float(columns)), 1)
	if rows > ABLAGE_ROWS:
		columns = ceili(float(_ablage_slots) / float(ABLAGE_ROWS))
		rows = ABLAGE_ROWS
	var pitch := minf(chip * ABLAGE_COLUMN_PITCH, rect.size.x / float(columns))
	var line := chip + u * ABLAGE_ROW_GAP
	var row := clampi(slot / columns, 0, rows - 1)
	var in_row := mini(columns, maxi(_ablage_slots - row * columns, 1))
	var at := Vector2(
		rect.get_center().x + pitch * (float(slot % columns) + 0.5 - float(in_row) * 0.5),
		rect.get_center().y - (line * float(rows) - u * ABLAGE_ROW_GAP) * 0.5
			+ line * float(row) + chip * 0.5)
	return _in_strip(at, rect, chip)

## Hält einen Platz ganz im Streifen - ein Chip hängt nie über der Kante.
func _in_strip(at: Vector2, rect: Rect2, chip: float) -> Vector2:
	var half := chip * 0.5
	return Vector2(clampf(at.x, rect.position.x + half, rect.end.x - half),
		clampf(at.y, rect.position.y + half, rect.end.y - half))

## Derselbe Platz in Display-Pixeln - Ziel der Meteore, Start des Setz-Lichts.
func ablage_spot_px(uid: int) -> Vector2:
	return get_global_rect().position + ablage_spot(uid)

## Sortierschlüssel eines Beutestücks: erst die Sorte in Regal-Reihenfolge, dann
## die Seltenheit AUFSTEIGEND (häufig links, episch rechts - die Reihe wächst zum
## Wertvollen hin), dann die Gravur, damit Gleiches beieinander liegt. Die Nummer
## bricht den Gleichstand - sort_custom ist nicht stabil.
static func ablage_sort_key(piece: Dictionary, uid: int) -> Array:
	var index: int = Pack.SHELF_ORDER.find(String(piece.get("sort", "")))
	var archetype := Engraving.by_id(String(piece.get("id", "")))
	return [index if index >= 0 else Pack.SHELF_ORDER.size(),
		int(archetype.rarity) if archetype != null else 0,
		String(piece.get("id", "")), uid]

static func _key_precedes(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false

## Die Nummern der liegenden Beute in Reihen-Reihenfolge.
func ablage_order() -> Array[int]:
	var keys: Array[Array] = []
	if run != null:
		for i in run.press_pieces.size():
			var uid := _piece_uid(run.press_pieces[i], i)
			keys.append(ablage_sort_key(run.press_pieces[i], uid))
	keys.sort_custom(_key_precedes)
	var out: Array[int] = []
	for key in keys:
		out.append(int(key[key.size() - 1]))
	return out

## Die Gravur eines Stücks ("" = liegt nicht mehr).
func _piece_id(uid: int) -> String:
	var index := _piece_index(uid)
	return String(run.press_pieces[index].get("id", "")) if index >= 0 else ""

## Tiefe, Anzahl und Spitze JE STÜCK. Gleiche Gravuren teilen sich einen Platz
## und liegen deckungsgleich; die Tiefe sagt nur noch, WELCHE Kopie obenauf liegt
## und damit die Zahl trägt. Neu gezählt bei jedem Aufbau: die Zahl muss stimmen,
## wenn eine Kopie gesetzt ist.
func _ablage_stacking() -> Dictionary:
	var seating := ablage_order()
	var counts := {}
	for uid in seating:
		var key: Variant = _ablage_order.get(uid, "u%d" % uid)  # ungeordnet = für sich
		counts[key] = int(counts.get(key, 0)) + 1
	# Die Zahl gehört auf das Icon, das VORN liegt: sonst deckt das geführte Stück
	# sie zu. Sonst trägt sie die zuletzt gelegte Kopie.
	var tops := {}
	for uid in seating:
		var key: Variant = _ablage_order.get(uid, "u%d" % uid)
		if not tops.has(key) or int(tops[key]) != _held_uid:
			tops[key] = uid  # zuletzt gelegt liegt vorn, das geführte davor
	var out := {}
	var seen := {}
	for uid in seating:
		var key: Variant = _ablage_order.get(uid, "u%d" % uid)
		var depth := int(seen.get(key, 0))
		seen[key] = depth + 1
		out[uid] = {"depth": depth, "count": int(counts[key]), "top": tops[key] == uid}
	return out

## Nach dem letzten Einschlag räumt sich die Ablage auf: die Ordnung steht sofort
## (Zustand - ein Neuaufbau legt die Reihe hart hin), das Gleiten kommt hinterher.
## Gleiche Gravuren bekommen EINEN Platz; ihre Zahl steht auf dem Icon.
func tidy_ablage() -> void:
	var order := ablage_order()
	_ablage_order.clear()
	var slot := -1
	var previous := ""
	for uid in order:
		var id := _piece_id(uid)
		if id != previous or slot < 0:
			slot += 1
			previous = id
		_ablage_order[uid] = slot
	_ablage_slots = slot + 1
	_ablage_stack = _ablage_stacking()
	for uid in order:
		_sync_chip_badge(uid)
	_glide_ablage(order)

## Die Chips gleiten auf ihre Plätze, von links nach rechts gestaffelt. Reine
## Anzeige: übersprungen liegt die Reihe trotzdem richtig.
func _glide_ablage(order: Array[int]) -> void:
	if _ablage_host == null or not is_instance_valid(_ablage_host):
		return
	var chip := ablage_chip_size()
	var corner := ablage_rect().position + Vector2.ONE * chip * 0.5
	for i in order.size():
		var button: Button = _ablage_chips.get(order[i])
		if button == null or not is_instance_valid(button):
			continue
		var target := ablage_spot(order[i]) - corner
		if button.position.is_equal_approx(target):
			_sync_chip_cover(order[i])
			continue
		var glide := button.create_tween()
		glide.tween_interval(ABLAGE_TIDY_DELAY + float(i) * ABLAGE_TIDY_STAGGER)
		glide.tween_property(button, "position", target, ABLAGE_TIDY_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		glide.tween_callback(_sync_chip_cover.bind(order[i]))  # erst am Ziel

## Legt den Haufen aus: je Stück ein Chip, in Reihen-Reihenfolge (von gleichen
## Gravuren liegt die letzte obenauf und trägt die Zahl). Was noch fliegt, fehlt -
## aufgedeckt wird bei der Landung.
func _build_ablage() -> void:
	if run == null or run.press_pieces.is_empty() or _phase != Phase.STASH:
		return
	var host := Control.new()
	host.name = "Ablage"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.position = ablage_rect().position
	host.size = ablage_rect().size
	add_child(host)  # direktes Kind: der Haufen liegt ÜBER dem Zeilenfluss
	_ablage_host = host
	_ablage_stack = _ablage_stacking()
	for uid in ablage_order():
		if not _withheld.has(uid):
			_seat_ablage_chip(uid)
	_raise_held_chip()

## Das geführte Stück nach vorn: deckungsgleiche Kopien lägen sonst über seinem
## goldenen Rahmen, und die Auswahl wäre unsichtbar.
func _raise_held_chip() -> void:
	var held: Button = _ablage_chips.get(_held_uid)
	if held != null and is_instance_valid(held):
		held.move_to_front()

## Legt EINEN Chip in den stehenden Haufen - der Weg der Landung: ein Meteor
## verrückt keinen Nachbarn, also wird auch nichts neu gebaut.
func _seat_ablage_chip(uid: int) -> void:
	if _ablage_host == null or not is_instance_valid(_ablage_host) or _ablage_chips.has(uid):
		return
	var index := _piece_index(uid)
	if index < 0:
		return
	var chip := ablage_chip_size()
	var button := _ablage_chip(run.press_pieces[index], uid, chip)
	if button == null:
		return
	button.position = ablage_spot(uid) - ablage_rect().position - Vector2.ONE * chip * 0.5
	_ablage_host.add_child(button)
	_ablage_chips[uid] = button
	_sync_chip_badge(uid)
	_sync_chip_cover(uid)

## Ein Chip der Ablage: das nackte Siegel über einem weichen Schein in seiner
## Sortenfarbe. Der Knopf zeichnet NICHTS (StyleBoxEmpty in jedem Zustand) - das
## Stück liegt einfach da; nur das geführte trägt seinen goldenen Rahmen.
func _ablage_chip(piece: Dictionary, uid: int, chip: float) -> Button:
	var archetype := Engraving.by_id(String(piece.get("id", "")))
	if archetype == null:
		return null
	var button := Button.new()
	button.name = "AblageChip"
	button.focus_mode = Control.FOCUS_NONE
	button.size = Vector2.ONE * chip
	button.pivot_offset = Vector2.ONE * chip * 0.5
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.disabled = editing_locked
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var tint: Color = PackDrawerView.COLORS.get(String(piece.get("sort", "")), GOLD)
	var glow := Panel.new()
	glow.name = "ChipGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.add_theme_stylebox_override("panel", _ablage_glow_box(tint, chip, uid == _held_uid))
	button.add_child(glow)

	var seal := EngravingRenderer.for_engraving(archetype)
	seal.bare = true  # der Haufen IST der Grund - keine zweite Kachel darauf
	# Dreißig atmende Seltenheits-Siegel zeichneten je Bild neu - der Haufen liegt
	# still, sein Licht kommt aus dem Schein darunter.
	if seal.is_node_ready():
		seal.set_process(false)
	else:
		seal.ready.connect(func() -> void: seal.set_process(false))
	seal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := chip * 0.06
	seal.offset_left = inset
	seal.offset_top = inset
	seal.offset_right = -inset
	seal.offset_bottom = -inset
	button.add_child(seal)

	_seat_piece_hint(button, String(piece.get("id", "")))
	button.pressed.connect(hold_piece.bind(uid))
	button.mouse_entered.connect(func() -> void: _lift_chip(button, true))
	button.mouse_exited.connect(func() -> void: _lift_chip(button, false))
	return button

## Der Schein unter einem Chip; das geführte Stück bekommt darüber den goldenen
## Rahmen - er IST die ganze Auswahl des Schritts.
func _ablage_glow_box(tint: Color, chip: float, held: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(tint.r, tint.g, tint.b, ABLAGE_FILL_ALPHA)
	box.set_corner_radius_all(int(chip * 0.22))
	box.shadow_color = Color(tint.r, tint.g, tint.b, ABLAGE_GLOW_ALPHA)
	box.shadow_size = maxi(2, int(chip * 0.15))
	if held:
		box.border_color = GOLD
		box.set_border_width_all(maxi(2, int(chip * 0.10)))
	return box

## Die goldene ×n auf dem obersten Icon - sie ALLEIN zeigt, dass mehrere Kopien
## auf dem Platz liegen. Ein einzelnes Stück trägt keine ("×1" wäre Lärm).
func _sync_chip_badge(uid: int) -> void:
	var button: Button = _ablage_chips.get(uid)
	if button == null or not is_instance_valid(button):
		return
	var entry: Dictionary = _ablage_stack.get(uid, {})
	var count := int(entry.get("count", 1))
	var badge: Label = button.get_node_or_null("Count")
	if not bool(entry.get("top", false)) or count <= 1:
		if badge != null:
			badge.queue_free()
			badge.name = "CountGone"  # der freie Name muss sofort wieder frei sein
		return
	if badge == null:
		badge = Label.new()
		badge.name = "Count"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		badge.add_theme_color_override("font_color", GOLD)
		badge.add_theme_color_override("font_outline_color", CasinoStyle.INK)
		badge.add_theme_constant_override("outline_size",
			maxi(2, int(button.size.x * 0.07)))
		badge.add_theme_font_size_override("font_size",
			maxi(8, int(button.size.x * ABLAGE_COUNT_SIZE)))
		button.add_child(badge)
	badge.text = "×%d" % count

## Deckungsgleiche Kopien werden NICHT gezeichnet: nur das vorderste Icon eines
## Platzes steht da. Sonst addieren sich ihre Scheine zu einem helleren Chip, und
## die Menge hinge an der Helligkeit statt allein an der Zahl.
func _sync_chip_cover(uid: int) -> void:
	var button: Button = _ablage_chips.get(uid)
	if button == null or not is_instance_valid(button):
		return
	var entry: Dictionary = _ablage_stack.get(uid, {})
	button.visible = bool(entry.get("top", true))

## Greifen zeigt sich am Inhalt, nicht an einem Rahmen: der Chip hebt sich.
func _lift_chip(button: Button, on: bool) -> void:
	if not is_instance_valid(button):
		return
	button.modulate = ABLAGE_HOVER if on else Color.WHITE
	button.scale = Vector2.ONE * (ABLAGE_HOVER_LIFT if on else 1.0)

## Stücke, deren Meteor noch fliegt: ihr Chip bleibt verdeckt, bis er landet.
## scene_root meldet das VOR der Zeremonie an - ohne Zeremonie liegt der Haufen
## sofort da.
func withhold_press_pieces(uids: Array) -> void:
	for uid in uids:
		_withheld[int(uid)] = true
	refresh()

## Ein Meteor ist eingeschlagen: SEIN Chip kommt zum Vorschein und plustert auf.
## Erst hier wird sichtbar, was gefallen ist. Der LETZTE gibt die Bank wieder frei
## (das Regal hing an pressing) - dazwischen wird nur eingelegt, nie neu gebaut.
func land_press_piece(uid: int) -> void:
	if not _withheld.has(uid):
		return
	_withheld.erase(uid)
	if _withheld.is_empty():
		_press_sorts.clear()
	if _withheld.is_empty() or _ablage_host == null or not is_instance_valid(_ablage_host):
		refresh()
	else:
		_seat_ablage_chip(uid)
	pop_ablage(uid)
	if _withheld.is_empty():
		tidy_ablage()  # der letzte Einschlag: der Haufen richtet sich aus

## Wirft ab, was nicht mehr in der Beute liegt (Verfall, Laufwechsel) - sonst
## bliebe die Presse für immer am Laufen.
func _prune_withheld() -> void:
	if _withheld.is_empty():
		return
	for uid: int in _withheld.keys():
		if _piece_index(uid) < 0:
			_withheld.erase(uid)
	if _withheld.is_empty():
		_press_sorts.clear()

## Der Einschlag: der frisch gelandete Chip plustert auf und lodert einmal.
## Reine Anzeige - ein übersprungener Tween ändert am Stand nichts.
func pop_ablage(uid: int) -> void:
	var chip: Button = _ablage_chips.get(uid)
	if chip == null or not is_instance_valid(chip):
		return
	var swell := chip.create_tween()
	swell.tween_property(chip, "scale", Vector2.ONE * PIECE_POP, PIECE_POP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swell.tween_property(chip, "scale", Vector2.ONE, PIECE_POP_TIME * 2.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var flare := chip.create_tween()
	flare.tween_property(chip, "modulate", Color(1.9, 1.9, 1.9), PIECE_POP_TIME)
	flare.tween_property(chip, "modulate", Color.WHITE, PIECE_FLARE_TIME) \
		.set_trans(Tween.TRANS_SINE)

## Lässt die Portale der belegten Leser wirbeln (scene_root staffelt sie).
func swirl_press_portal(slot: int, delay: float) -> void:
	if slot < 0 or slot >= _press_portals.size():
		return
	var portal: PressPortalView = _press_portals[slot]
	if portal != null and is_instance_valid(portal):
		portal.swirl(delay)

## Name und Wirkung des Dings unter pixel ({} = keins): das Magazin spricht
## zuerst, dann der Haufen (das oberste Stück gewinnt), zuletzt der Handlungs-Sitz
## mit seinem Preis - alle schreiben auf denselben Hinweis-Schirm.
func chip_hint_at(pixel: Vector2) -> Dictionary:
	if _drawer != null and is_instance_valid(_drawer):
		var hint := _drawer.hint_at(pixel)
		if hint.has("stock"):
			return _stock_hint()
		if not hint.is_empty():
			return hint
	if _ablage_host != null and is_instance_valid(_ablage_host):
		var chips := _ablage_host.get_children()
		for i in range(chips.size() - 1, -1, -1):
			var found := _meta_hint(chips[i] as Control, pixel)
			if not found.is_empty():
				return found
	return _meta_hint(_press_button, pixel)

## Die Fach-Fläche nennt den BESTAND am Deckel - dort, wo die Karten liegen, und
## nicht auf den Karten selbst (eine Kassette nennt ihren Inhalt, das Fach seinen
## Füllstand). Live vom Lauf gefragt: der gemessene Deckel kommt erst nach dem
## Layout herein, ein beim Aufbau eingebackener wäre alt.
func _stock_hint() -> Dictionary:
	var capacity := run.pack_capacity if run != null else 0
	if capacity <= 0:
		return {"title": PackDrawerView.EMPTY_TITLE, "body": PackDrawerView.EMPTY_BODY}
	var stock := run.owned_packs.size()
	var free := maxi(capacity - stock, 0)
	var body := PackDrawerView.EMPTY_BODY
	if stock > 0:
		body = PackDrawerView.FULL_BODY if free == 0 else PackDrawerView.STOCK_BODY % free
	return {"title": PackDrawerView.STOCK_TITLE % [stock, capacity], "body": body}

## Die Meta-Auskunft eines Knopfes, wenn der Zeiger auf ihm steht ({} = nicht).
func _meta_hint(node: Control, pixel: Vector2) -> Dictionary:
	if node == null or not is_instance_valid(node) or not node.visible \
			or not node.has_meta("title") or not node.get_global_rect().has_point(pixel):
		return {}
	return {"title": String(node.get_meta("title", "")),
		"body": String(node.get_meta("body", "")),
		"tint": node.get_meta("tint", CasinoStyle.CREAM)}

## Ankunfts-Pluster eines frisch aufgedeckten Netzes (wie pop_ablage am Chip).
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

## Öffnet das WÜRFEL-Paket auf Platz index (Alt-Eingang der Tests).
func open_pack(index: int) -> void:
	if run == null or index < 0 or index >= run.owned_packs.size():
		return
	open_pack_uid(run.owned_packs[index].pack_uid)

## Öffnet GENAU dieses Würfel-Paket. Der Inhalt entsteht ERST JETZT (GameRun),
## bleibt aber unverbucht, bis die Entsiegelung ihn zündet. Gravur-Pakete laufen
## nicht hier durch, sondern über die Presse (start_press). Die Presse-Vorwahl
## bleibt stehen - uids überleben das Rutschen des Lagers.
func open_pack_uid(uid: int) -> void:
	if run == null:
		return
	var pack := run.pack_by_uid(uid)
	if pack == null or not pack.is_dice_pack():
		return
	_open_pack_type = pack.type
	# Phase VOR dem Öffnen setzen: packs_changed baut sofort neu auf.
	_phase = Phase.UNSEAL
	_selected_slot = -1
	var result := run.open_pack_by_uid(uid)
	_revealed_dice.assign(result["dice"])
	_pack_dice.assign(result["dice"])
	# Die Würfel-Plätze stehen ab jetzt - die Zeichen brauchen ihr Ziel. Körperlich
	# ist noch keiner: das entscheidet die Zeremonie, Zeichen für Zeichen.
	_materialized.clear()
	_materialized.resize(_revealed_dice.size())
	_materialized.fill(false)
	if not _revealed_dice.is_empty():
		_phase = Phase.CHOOSE_DIE if _revealed_dice.size() > 1 else Phase.PLACE_DICE
	pack_activated.emit(uid)
	refresh()
	_begin_unseal()

## Baut die Entsiegelung als Vollflächen-Panel über dem Lager auf.
func _begin_unseal() -> void:
	var u := maxf(size.x, 200.0) / 100.0
	_unseal = PackUnsealView.new()
	_unseal.name = "Unseal"
	add_child(_unseal)
	# Das GANZE Fensterinnere: die Schürze mit Konsole und Buchten steht auch
	# während der Entsiegelung darunter, sie wird nur nicht angefasst.
	_unseal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_unseal.die_revealed.connect(_on_die_revealed)
	_unseal.finished.connect(_on_unseal_finished)
	# Die Zeichen fragen selbst nach den Plätzen: beim Aufbau ist das Fenster
	# noch nicht ausgelegt, seine Bühnen haben also noch kein Rechteck.
	_unseal.die_target_source = die_stage_centers
	_unseal.setup(_open_pack_type, [] as Array[Engraving], _revealed_dice, u)

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

## Vorzeitiges Ende der Zeremonie (Station, Laufwechsel): abräumen, zurück ins
## Lager - OHNE refresh, weil die Aufrufer selbst gerade neu bauen.
func _abort_unseal() -> void:
	if _phase != Phase.UNSEAL and _phase != Phase.CHOOSE_DIE:
		return
	_clear_unseal()
	_phase = Phase.STASH
	_open_pack_type = ""
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

# --- Die Presse ----------------------------------------------------------------
# Mehrere Gravur-Pakete gehen in EINE Pressung, und die ist EIN Griff: ein Preis,
# dann wirft jedes Paket seine Menge aus. Pressen ist bindend - gewählt wird
# darum vorher, im Regal.

## Wirft uids aus der Vorwahl, hinter denen kein Gravur-Paket mehr liegt: das
## Lager schrumpft auch anderswo (Wett-Einsatz, Laufwechsel).
func _prune_selection() -> void:
	if _selected_packs.is_empty():
		return
	var kept: Array[int] = []
	for uid in _selected_packs:
		var pack := run.pack_by_uid(uid) if run != null else null
		if pack != null and not pack.is_dice_pack():
			kept.append(uid)
	_selected_packs = kept

## DIE PRESSUNG: ein Griff, und danach liegt die Beute. Gemeldet wird VOR dem
## Buchen (die Dekompression der Zellen braucht sie noch in ihren Schlitzen),
## gebucht wird atomar in GameRun, und press_rolled übergibt der Zeremonie, was
## welcher Leser auswirft.
func start_press() -> void:
	if not can_press():
		return
	var sorts := press_slot_sorts()
	press_started.emit()
	# Die Sorten überleben das Schlucken: Leser und Portal brennen weiter in ihrer
	# Farbe, bis der letzte Meteor liegt.
	_press_sorts = sorts
	# Die Vorwahl hält uids - die Presse frisst Indizes, aufgelöst erst jetzt.
	var indices: Array[int] = []
	for uid in _selected_packs:
		var index := run.pack_index_of(uid)
		if index >= 0:
			indices.append(index)
	var result := run.open_press(indices)
	var readers: Array = result.get("readers", [])
	if readers.is_empty():
		_press_sorts.clear()
		refresh()  # die Energie reichte nicht: die Zellen kommen zurück in ihre Schlitze
		return
	_selected_packs.clear()
	refresh()
	press_rolled.emit(sorts, readers, int(result.get("cost", 0)))

## Eine Pressung gehört dem laufenden Spiel: beim Laufwechsel verfällt sie samt
## der Beute, die noch flöge.
func _drop_press() -> void:
	_selected_packs.clear()
	_withheld.clear()
	_press_sorts.clear()
	_ablage_order.clear()
	_ablage_slots = 0
	_ablage_stack.clear()
	_held_uid = 0
	_held_id = ""
	_clear_pair()

## Zurück ans Lager - der Inhalt ist verbucht bzw. abgelehnt.
func finish_ceremony() -> void:
	_clear_unseal()
	_phase = Phase.STASH
	_open_pack_type = ""
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
## Das Dossier zeigt den GANZEN Besitz statt der Tray-Sitzordnung: gemustert wird,
## was einem gehört, auch wenn es gerade in der Grube liegt.
func _pool_defs() -> Array[DieDefinition]:
	var pool: Array[DieDefinition] = []
	if run != null:
		pool = run.owned_pool
	if _phase == Phase.INSPECT:
		return pool
	if not _pool_order.is_empty():
		return _pool_order
	return pool

## Kachel -> Pool-Platz. -1 für leere Kacheln und für Runden-Leihgaben
## (Glücksknoten), die gar nicht im Pool stehen.
func _pool_index_of(grid_index: int) -> int:
	var defs := _pool_defs()
	if run == null or grid_index < 0 or grid_index >= defs.size() or defs[grid_index] == null:
		return -1
	return run.owned_pool.find(defs[grid_index])

## Kachel auf Kachel gezogen: der Würfel wird am Ziel EINGESETZT, die anderen
## rücken auf - die Würfel selbst bleiben, was sie sind. Gesperrt, sobald die
## Runde unterschrieben ist - dasselbe Zeitfenster wie fürs Gravieren.
func _on_pool_slots_reordered(from_grid: int, to_grid: int) -> void:
	if run == null or editing_locked:
		return
	var from_pool := _pool_index_of(from_grid)
	var to_pool := _pool_index_of(to_grid)
	if from_pool < 0 or to_pool < 0:
		return
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

## Der hervorgehobene Platz als Liste - das Raster nimmt nur getypte Arrays. Im
## Dossier ist es der gezeigte Würfel, sonst der gewählte Platz.
func _highlighted_slots() -> Array[int]:
	var chosen: Array[int] = []
	if _phase == Phase.INSPECT:
		var shown := _pool_defs().find(_inspect_die)
		if shown >= 0:
			chosen.append(shown)
		return chosen
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
	# Die Arbeits-Netze erklären ihre Zellen wie jedes andere Netz.
	for net in _clamp_nets:
		if not is_instance_valid(net):
			continue
		var face := net.face_at_pixel(pixel)
		if face != -1:
			return DieNetView.hint_for(net.def, face)
	for i in _die_nets.size():
		var button := _die_nets[i]
		if not is_instance_valid(button) or not die_materialized(i) or i >= _revealed_dice.size():
			continue
		var rect := button.get_global_rect()
		if not rect.has_point(pixel):
			continue
		return DieNetView.hint_for(_revealed_dice[i],
			DieNetView.face_at(pixel - rect.position, u * CHOICE_CELL))
	# Das Netz des Dossiers erklärt seine Zellen wie jedes andere.
	if _inspect_net != null and is_instance_valid(_inspect_net) and _inspect_die != null:
		var net_rect := _inspect_net.get_global_rect()
		if net_rect.has_point(pixel):
			return DieNetView.hint_for(_inspect_die,
				DieNetView.face_at(pixel - net_rect.position, u * CHOICE_CELL))
	# Das Pool-Raster nennt die Seele der überfahrenen Kachel. Nur solange es
	# wirklich steht: danach hängt _pool_grid noch am freigegebenen Inhalt und
	# träfe mit einem veralteten Rechteck.
	if _pool_grid_open() and _pool_grid != null and is_instance_valid(_pool_grid):
		return _pool_grid.hint_at(pixel)
	return ""

## Steht gerade ein 30er-Raster im Fenster? Beim Einsetzen eines Paket-Würfels
## und im Dossier.
func _pool_grid_open() -> bool:
	return _phase == Phase.PLACE_DICE or _phase == Phase.INSPECT

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
## Das Dossier ist derselbe Schritt zurück: es schließt vor der Kamera.
func go_back() -> bool:
	if _phase == Phase.INSPECT:
		close_inspect()
		return true
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

# --- Das Dossier (nur ansehen) --------------------------------------------------
# Ein getippter Tray-Würfel kommt auf die Bank: links steht er selbst im
# Stasis-Feld, darunter sein Netz mit Namen und Augensumme, rechts der Pool, aus
# dem der nächste gewählt wird. Nichts davon verändert einen Würfel - graviert
# wird auf den Netzen der Aufspannung, nirgends sonst.

## Öffnet das Dossier eines Pool-Würfels. Von der Grundseite aus - ein Wurf,
## offene Beute oder ein Paket haben die Bank - ODER aus einem offenen Dossier
## heraus: dann WECHSELT es. Der Griff ins Tray ist damit derselbe Weg wie der
## Griff ins Raster, und beide führen auf dieselbe Seite. false = jetzt nicht.
func open_inspect(def: DieDefinition) -> bool:
	if run == null or def == null or placing():
		return false
	if _phase != Phase.STASH and _phase != Phase.INSPECT:
		return false
	if def == _inspect_die:
		return true  # er steht schon auf der Bühne
	if run.owned_pool.find(def) < 0:
		return false
	_inspect_die = def
	_phase = Phase.INSPECT
	refresh()
	return true

func close_inspect() -> void:
	if _phase != Phase.INSPECT:
		return
	_drop_inspect()
	refresh()

func inspecting() -> bool:
	return _phase == Phase.INSPECT

## Der gezeigte Würfel (null = die Seite steht nicht) - scene_root stellt seinen
## ECHTEN Körper über die Bühne und lässt seinen Tray-Sitz leer.
func inspected_die() -> DieDefinition:
	return _inspect_die if _phase == Phase.INSPECT else null

## Mitte der Dossier-Bühne in Display-Pixeln (x < 0 = sie steht gerade nicht).
func inspect_stage_center() -> Vector2:
	if _inspect_stage_host != null and is_instance_valid(_inspect_stage_host):
		return _inspect_stage_host.get_global_rect().get_center()
	return Vector2(-1, -1)

func _drop_inspect() -> void:
	if _phase == Phase.INSPECT:
		_phase = Phase.STASH
	_inspect_die = null

## Klick auf eine Raster-Kachel: das Dossier wechselt auf diesen Würfel. Derselbe
## Körper tritt ab und der neue entsteht an seinem Platz (scene_root).
func inspect_slot(grid_index: int) -> void:
	if _phase != Phase.INSPECT:
		return
	var pool_index := _pool_index_of(grid_index)
	if pool_index < 0 or run.owned_pool[pool_index] == _inspect_die:
		return
	_inspect_die = run.owned_pool[pool_index]
	refresh()

func _build_inspect(u: float) -> void:
	if _inspect_die == null:
		return
	var body := HBoxContainer.new()
	body.name = "InspectBody"
	body.add_theme_constant_override("separation", int(u * BODY_GAP))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(body)
	body.add_child(_inspect_side(u))
	body.add_child(_pool_grid_host(false, inspect_slot))

## Linke Spalte: die leere Bühne des schwebenden Würfels, darunter sein Netz mit
## Namen und Augensumme - dieselbe Auskunft wie auf der Hover-Karte, nur groß.
## Der ganze Block steht SENKRECHT MITTIG im Fenster (gleiche Restluft oben wie
## unten): oben angeschlagen hing der schwebende Würfel über der Fensterkante,
## und darunter stand ein leeres Drittel.
func _inspect_side(u: float) -> Control:
	var column := VBoxContainer.new()
	column.name = "InspectSide"
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", int(u * INSPECT_LINE_GAP))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_slack("InspectSlackTop"))

	var span := DieNetView.net_size(u * CHOICE_CELL)
	var stage := Control.new()
	stage.name = "InspectStage"
	stage.custom_minimum_size = Vector2(span.x, u * STAGE_HEIGHT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_stage_host = stage
	column.add_child(stage)

	var air := Control.new()
	air.name = "InspectNetGap"
	air.custom_minimum_size = Vector2(0,
		maxf(u * (INSPECT_NET_GAP - INSPECT_LINE_GAP * 2.0), 0.0))
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(air)

	var host := Control.new()
	host.name = "InspectNet"
	host.custom_minimum_size = span
	host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(DieNetView.build(_inspect_die, -1, u * CHOICE_CELL))
	_inspect_net = host
	column.add_child(host)

	column.add_child(_inspect_line(_inspect_die.display_name, u * 2.6, GOLD, span.x))
	column.add_child(_inspect_line("Augensumme %d" % DiceRowView.eye_total(_inspect_die),
		u * 2.0, CasinoStyle.CREAM, span.x))
	column.add_child(_slack("InspectSlackBottom"))
	return column

## Eine Zeile unter dem Netz, auf dessen Breite zentriert - so steht sie unter dem
## Würfel und zieht die Spalte nicht auseinander.
func _inspect_line(text: String, font_size: float, color: Color, width: float) -> Label:
	var label := _label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label

func _build_dice_placement(u: float) -> void:
	if _revealed_dice.is_empty():
		return
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", int(u * BODY_GAP))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(body)

	body.add_child(_placement_side(u))
	# Nur die Werkbank legt um - die Tausch-Auswahl des Ladens und das Dossier
	# bleiben reine Ziele (dasselbe Raster, andere Rolle).
	body.add_child(_pool_grid_host(true, toggle_slot))
	_sync_selection()

## Linke Spalte: die Bühne des schwebenden Würfels, darunter Einsetzen und
## Verwerfen. Auch hier ist der ECHTE Würfel die Anzeige - keine Miniatur.
func _placement_side(u: float) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", int(u * 0.8))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	column.add_child(_die_column(0, u, false))

	_place_button = _action_button("Einsetzen", GOLD, u, confirm_placement)
	_place_button.custom_minimum_size = Vector2(u * 20.0, u * 4.4)
	column.add_child(_place_button)
	var discard := _action_button("Verwerfen", MUTED_COLOR, u, discard_dice)
	discard.custom_minimum_size = Vector2(u * 20.0, u * 4.0)
	column.add_child(discard)
	return column

## Das 30er-Raster in seinem Wirt: nackter Control, KEIN Container - ein Container
## meldete das Mindestmaß des Rasters zurück, aus dem es seine Größe zieht, und
## das Fenster wüchse mit.
func _pool_grid_host(reorder: bool, on_pressed: Callable) -> Control:
	_pool_host = Control.new()
	_pool_host.name = "PoolHost"
	_pool_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pool_host.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_pool_unit = 0.0
	_pool_grid = DiceGridView.new()
	_pool_grid.name = "PoolGrid"
	_pool_grid.reorder_enabled = reorder
	_pool_grid.slot_pressed.connect(on_pressed)
	if reorder:
		_pool_grid.slots_reordered.connect(_on_pool_slots_reordered)
	_pool_host.add_child(_pool_grid)
	_pool_host.resized.connect(_fit_pool_grid)
	_fit_pool_grid()
	return _pool_host

## Größtes Kachelmaß, das die 30 Plätze in den Wirt bringt; danach mittig gesetzt
## (der nackte Wirt legt nichts aus). Das Raster FÜLLT seinen Bereich - die Luft
## nach außen ist der Inhaltsrand des Fensters, nicht noch ein zweiter Rand
## darin; genau darauf ist die Fensterbreite gelöst (dossier_aspect).
func _fit_pool_grid() -> void:
	if _pool_grid == null or not is_instance_valid(_pool_grid) \
			or _pool_host == null or not is_instance_valid(_pool_host):
		return
	var pool := _pool_defs()
	var rows := maxi(int(ceil(float(pool.size()) / float(_pool_columns))), 1)
	var unit := maxf(size.x, 200.0) / 100.0  # Rückfall, solange der Wirt kein Maß hat
	if _pool_host.size.x > 0.0:
		unit = DiceGridView.unit_for(_pool_columns, rows, _pool_host.size)
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
