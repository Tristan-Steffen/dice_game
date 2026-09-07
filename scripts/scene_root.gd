extends Node3D
## Spielablauf-Koordinator: Rundenziele, Shop, Würfel-Pool und UI-Verdrahtung.
##
## Kernregeln: Der Pool hat fest GameRun.POOL_SIZE Würfel und verteilt sich auf
## Warteschlangen- und Pool-Tray. GEMISCHT wird NICHT mehr zu Rundenbeginn
## (Spielregel 2026-08-30): gezogen wird in Pool-Reihenfolge, die EINZIGE Streuung
## ist die Ablage-Reihe, die im Pit erscheint (je Reihe einmal), und am Rundenende
## IST der Pit-Inhalt der neue Pool - in der Ordnung [Warteschlangen-Rest]
## [ungezogener Rest][Ablage]. "Nehmen"
## wertet die AUSGEWÄHLTEN Würfel als Hand und legt alle 6 ab; die Auswahl
## schützt außerdem vor dem nächsten "Neu würfeln" (nur ungeschützte Slots
## bekommen frisch gezogene Würfel). Farkle: bringt ein Neu-Würfeln nicht
## strikt mehr Punkte, wird die Hand ohne Punkte verworfen (der erste Wurf
## einer Hand kann nie farkeln). Die Runde endet, sobald der Rundenstand das
## Ziel erreicht - oder der Pool leer ist (Game Over); der Rest des Pools wird
## als kleinere Hand ausgespielt.

@export var throw_force: float = 50.0
@export var spin_strength: float = 14.0
@export var rest_linear_threshold: float = 0.15
@export var rest_angular_threshold: float = 0.15
@export var rest_time_required: float = 0.2

const HAND_SIZE := 6

## Einmal für den geschafften Benchmark - und erneut je Überladungs-Stufe, die
## nicht mehr in die Ladungs-Börse passt (siehe GameRun.energy_split).
const MONEY_PER_ROUND_CLEAR := 5
const MONEY_PER_UNUSED_DIE := 1  # je noch nicht gezogenem Würfel im Rundenpool

## Auszahlungs-Animation der Rundenbonus-Zeilen im Hub.
const PAYOUT_FLASH_DURATION := 0.3
const PAYOUT_TEXT_HOLD_DURATION := 0.35
const DIE_PAYOUT_STEP_INTERVAL := 0.09
## Charms zahlen langsamer als Würfel - jeder Posten soll einzeln lesbar sein.
const CHARM_PAYOUT_STEP_INTERVAL := 0.45
## Start-Takt der Frankiermaschinen-Salve: die Meteore starten dicht
## hintereinander, ohne auf die vorige Ankunft zu warten.
const STAMP_METEOR_GAP := 0.18
## Abklingzeit des Runen-Ausbruchs: kurz genug, dass der nächste Würfel seinen
## eigenen Ausbruch bekommt, lang genug zum Sehen.
const RUNE_FLARE_TIME := 0.45
## Pendel-Schwung: verlorener Mult steigt in Warnrot auf, gewonnener in Gold.
const PENDULUM_LOSS_COLOR := Color(1.0, 0.35, 0.3)
const PENDULUM_SWING_FONT := 0.7

## Bank-Entladung: je Überladungs-Stufe ein Komet aus dem Zielbalken (oberste
## Stufe zuerst). Der Abstand nach jeder Ankunft zieht leicht an (Accelerando).
const BANK_STAGE_GAP_START := 0.28
const BANK_STAGE_GAP_DECAY := 0.82
const BANK_STAGE_GAP_MIN := 0.12
const BANK_BAR_DRAIN_TIME := 0.45
## Stufen, die eine Energie prägen, fahren cyan statt in ihrer Stufenfarbe.
const ENERGY_COMET_COLOR := CasinoStyle.ENERGY

## --- Schwarzmarkt ---------------------------------------------------------------
## Anteil des Rasterplatzes, den die Bank einnimmt - knapp unter 1, nur noch ein
## Saum gegen die Nachbarzelle (das Raster soll den Platz sichtbar ausfüllen).
const CAPACITOR_SLOT_FILL := 0.97
## Der freie Chip-Platz ist flach (3.16:1); die Bank darf so viel höher in den
## freien Filz DARUNTER wachsen (unter dem Cluster liegt nur blanker Filz). Der
## Fußabdruck der Bank ist auf dieses Verhältnis mitgetrimmt.
const CAPACITOR_SLOT_TALL := 2.0
## Luft zwischen Automaten-Unterkante und Schwarzmarkt-Fenster.
const SECRET_SHOP_TOP_GAP := 30.0
## Seitenverhältnis des Schwarzmarkt-Fensters. Früher schnitt die Glas-Ellipse
## seine linke Kante zu; die ist fort, also steht das Maß jetzt AUTORISIERT da.
## Es bindet weiter die Breite: seit der Schwarzmarkt in den vom TOPF-Rückbau
## freigegebenen Filz hochwächst (Oberkante am kurzen Automaten-Fenster), skaliert
## der ganze Inhalt bei GLEICHEM Verhältnis mit (~786×437 statt 452×251, u ~7,9
## statt 4,5) - flach ist er nicht mehr, nur breiter als hoch.
const SECRET_SHOP_ASPECT := 1.8
## Violett der legendären Rarität - die Signaturfarbe des Schwarzmarkts.
const VIOLET_REVEAL_COLOR := Color(0.75, 0.35, 1.0)

## Würfel-Blitz beim Auszahlen: schneller Anstieg auf überstrahltes Gold plus
## Größen-Pop, langsameres Abklingen - die Blitze überlappen wie eine Welle.
const DIE_FLASH_PEAK_COLOR := Color(1.9, 1.55, 0.6)
## Goldener Handschlag: Sweep -> Blitz -> Zurücksetzen, zusammen ~0,8 s.
const HANDSHAKE_SWEEP_TIME := 0.32
const HANDSHAKE_FLASH_TIME := 0.16
const HANDSHAKE_SETTLE_TIME := 0.32
const HANDSHAKE_SWELL := 1.22
const DIE_FLASH_RAMP_UP := 0.07
const DIE_FLASH_RAMP_DOWN := 0.38
const DIE_FLASH_SCALE := 1.25

## Ruhefarbe der Tisch-Texte: leicht ÜBERHELLES Weiß (> 1.0), damit sie mit dem
## Szenen-Glow dezent leuchten; beim Aufleuchten wechseln sie auf das Gold.
const PAYOUT_LABEL_BASE_COLOR := Color(1.35, 1.35, 1.3)
const PAYOUT_LABEL_GLOW_COLOR := Color(2.1, 1.7, 0.15)

## Feste Position des Nachschub-Trays: mittig (Welt-Z = 0) und in der Höhe
## gleichmäßig zwischen Gruben-Südrand (X = -7.6) und Hub-Oberkante (X = -11),
## also X = -9.3. Y = 0 = Tischbildschirm-Oberfläche.
const QUEUE_TRAY_PIT_POSITION := Vector3(-9.3, 0.0, 0.0)

## Der SAUM eines Hebebühnen-Lochs um das Slotraster: ein halber Platz ringsum.
const TRAY_PIT_SEAM := DiceTrayView.SPACING * 0.5
## Der ABLAGE-Abschnitt des Trägers trägt das Dunkelrot des toten Ablage-Trays; der
## Vorrats-Abschnitt bleibt beim Tray-Blau seiner Pucks.
const ABLAGE_TINT := Color(0.55, 0.08, 0.08)
## Der Fußabdruck des SCHLUCK-Lochs: ein liegender Würfel plus einen schmalen Saum.
const SWALLOW_HALF := Vector2.ONE * (DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT * 1.55)
## Wie tief der VORRAT im Pit parkt (Spieler-Entscheid 2026-08-31): flach genug, dass
## die schwebenden Würfel um ihre halbe Höhe AUS dem Pit ragen. Die Plattform parkt auf
## -Tiefe, der Würfel schwebt FLOAT_HEIGHT darüber - Tiefe = FLOAT_HEIGHT setzt seine
## Mitte auf die Fläche (halber Würfel oben heraus). Die liegende Ablage fährt dieselbe
## Tiefe mit und bleibt darum um denselben Betrag TIEFER als der Vorrat. Kein Schirm mehr
## darüber - die herausragenden Würfel durchstießen ihn.
const POOL_PARK_DEPTH := DiceTrayView.FLOAT_HEIGHT
## Die drei Takte der Träger-Bühne: der gezogene Würfel sinkt an seinem Sitz in die
## Plattform, eine Ablage-Reihe schiebt von hinten ein, und der Träger rückt eine
## Reihen-Teilung vor.
const CARRIER_SINK_TIME := 0.34
const ABLAGE_SLIDE_TIME := 0.55
const CARRIER_SHIFT_TIME := 0.5
## Die Warteschlangen-Fahrten laufen DOPPELT so schnell und dicht GESTAFFELT statt
## nacheinander (Spieler-Entscheid 2026-08-30): je Platz eine eigene Maschine, der
## Versatz ist der Abstand zweier Starts von links nach rechts - der Abgang vom
## Träger taktet mit derselben Staffel.
const QUEUE_RIDE_SPEED := 2.0
const QUEUE_RIDE_STAGGER := 0.12
## Und der SCHLUCK ebenso: doppelt schnell, links nach rechts gestaffelt über drei
## Bahnen. Der Staffel-Versatz ist GERECHNET (Fahrtdauer durch Bahnenzahl), damit
## Salve und Bahnen genau ineinandergreifen.
const SWALLOW_SPEED := 2.0

## Die POSITION der Screen-Elemente hängt an frei verschiebbaren Editor-Ankern
## (Marker3D unter $ScreenAnchors); nur die GRÖSSEN stehen hier als Weltmaß.
const PIT_SCORE_WIDTH_WORLD := 10.0
const PIT_SCORE_HEIGHT_WORLD := 6.0  # höher: Platz für die Wertungs-Orbs

## Hub-Fläche unter der Grube (~grubenbreit, doppelte Gruben-Bildschirmhöhe).
const HUB_WIDTH_WORLD := 28.5
const HUB_HEIGHT_WORLD := 30.0

## Die Automaten-SPALTE: Unterkante höher als der Hub. Der Versatz stammt vom alten
## Tischrand und bleibt bewusst - der Schwarzmarkt hängt daran.
const SLOTS_BOTTOM_INSET_WORLD := 7.5
## Das Fenster füllt seit dem TOPF-Rückbau (vier Reihen, keine Topf-Anzeige) nur
## noch diesen Anteil der Spalte. Den Rest darunter nimmt jetzt der Schwarzmarkt:
## seine Oberkante folgt dem KURZEN Fenster (slots_rect), nicht der vollen Spalte.
const SLOTS_HEIGHT_SHARE := 0.78

## Luft zwischen der gelösten Streifen-Breite und der rechten Anzeigekante: der
## Tisch ist endlich, und ein Fenster, das darüber hinausliefe, wäre halb weg.
const WORKSHOP_RIGHT_MARGIN := 20.0
## ... und was unter ihm frei bleibt: der Streifen reicht seit der TREPPE bis fast
## an die Anzeigekante, denn sechs LIEGENDE Karten übereinander sind hoch.
const WORKSHOP_BOTTOM_MARGIN := 12.0
## Gefaktes Screen-Abstrahlen: gl_compatibility hat kein GI, also steht über
## jedem großen Fenster ein kurzes, getöntes Omni-Licht (Schatten aus) - Würfel,
## Chips und Props baden im Farbton "ihres" Screens (dunkler Raum, Lichtquelle
## Screens+Würfel). Zahl der Lichter im Blick behalten: alle treffen das eine
## Tisch-Mesh (project.godot max_lights_per_object).
const SPILL_ENERGY := 1.1
const SPILL_ATTENUATION := 1.7
const SPILL_HEIGHT_FACTOR := 0.55  # Höhe aus der schmaleren Fensterhälfte
const SPILL_HEIGHT_MIN := 1.8
const SPILL_HEIGHT_MAX := 5.0
const SPILL_RANGE_FACTOR := 1.35   # Reichweite über den Fensterrand hinaus
## Der Kombi-Cluster braucht mehr: nur dort stehen echte Körper (die Chips).
const CLUSTER_SPILL_FACTOR := 2.6

## Der Tisch hat keinen Rand mehr: alles außer dem Screen-Mesh verschwindet,
## stattdessen läuft der Filzboden (TableGround in room.tscn) endlos weiter.
## Auch die Chrom-Zarge: ohne Raumlicht spiegelt Chrom nichts und stand als
## fetter schwarzer Ring zwischen Glas und Filz.
const TABLE_HIDDEN_MESHES: Array[String] = ["Rail", "Skirt", "SkirtBottom", "Underglow", "LEDStrip", "ChromeTrim"]


## Automaten-Lichter: der Einsatz fährt als Energie (CasinoStyle.ENERGY), Ware und
## Würfel zyan - dieselbe Farbe trägt jede Lieferung zur Werkbank.
const SLOT_DIE_COLOR := Color(0.7, 1.7, 2.0, 0.9)

## Das Fußmaß des abgebauten Hüllen-Projektors (ehemals DiceShell.PUCK_RADIUS):
## es lebt allein als Layout-Zahl weiter und hält die Lücke zwischen Grube,
## Schatz-Screen und Nebenwetten-Fenster stabil.
const SHELL_FOOT_RADIUS := 1.4

## Wuchs-Faktor des Wett-Tresens (Spieler-Entscheid 2026-08-27): die Fenster-
## EINHEIT ist seine eigene Breite (SideBetPanel: size.x/UNIT_DIV), also wachsen
## Plots, Fassungen, Löcher UND Schrift gemeinsam um dieses Maß.
const WETTEN_ROOM := 1.3

## Die AUFDECKUNG: eine Seite, die der Scanner freilegt, blitzt so lange auf. Das
## GRÜN ist das eine, das die Ziffer eines Würfels je trägt - dieselbe Farbe, die
## der Vorschau-Wert im Pit und die Deltas des Netzes sprechen.
const SERIES_FLASH_TIME := 0.45
const REVEAL_FLASH_COLOR := DieFaceDisplay.PREVIEW_NUMBER_COLOR
## Ein Würfel schwebt über der Werkbank wie ein Tray-Würfel, auf derselben Höhe
## und über derselben Stasis-Station - er liegt nicht auf, er steht IM Feld.
const ENGRAVE_HOVER := DiceTrayView.FLOAT_HEIGHT
## Ab hier ist die Geste ein Drehen und kein Klick mehr (Bildschirmpixel).
const ENGRAVE_DRAG_THRESHOLD := 6.0
## Feldfarbe eines Würfels, der zur Auskunft über der Werkbank schwebt (Dossier):
## das Cyan der Werkstatt.
const PACK_EMITTER_TINT := Color(0.2, 0.65, 0.9)
## Feldfarbe der Zwingen: das Blau der Trays - sie sind Bestand, keine Zeremonie.
const CLAMP_EMITTER_TINT := Color(0.15, 0.35, 0.75)
## Schwebehöhe NUR der Zwingen: sie stehen als einzige über einem Diagramm, und
## der seitliche Versatz gegen dieses Netz wächst linear mit der Höhe, sobald die
## Kamera nicht in der kanonischen Werkbank-Lage steht (Nahsicht). Aus der
## Würfelgeometrie gelöst statt geschätzt: die Mitte steht eine ganze Kantenlänge
## über dem Glas, die freie Feldsäule darunter ist damit genau eine halbe
## Würfelhöhe - kürzer wäre kein Feld mehr, nur noch ein Sockel.
const CLAMP_HOVER := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT * 2.0
## Wechselt das Dossier den Würfel, WANDERT sein Körper - er verschwindet nicht.
const PACK_MOVE_TIME := 0.4
## Staffel, mit der eine frische Aufspannung in ihren Feldern entsteht.
const CLAMP_MATERIALIZE_STAGGER := 0.07
## Der TRAGE-BOGEN des ZIELWÜRFELS (Pool <-> Podest): die Zielwahl ist ein
## Spieler-Zug, er fliegt also ÜBER dem Tisch. Der Scheitel ist eine Würfelkante -
## sichtbar ein Bogen, aber kein Wurf.
const BENCH_CARRY_TIME := 0.5
const BENCH_CARRY_PEAK := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT * 2.0

## Die Datenzellen der Werkbank: Staffel, mit der eine Regal-Zeile aufgeht, und der
## Takt, in dem eine umsortierte Karte auf ihren neuen Platz gleitet.
## Luftzuschlag auf die Grubentiefe über der höchsten angezeigten Kassette.
const PACK_PIT_DEPTH_ROOM := 1.3
const DATA_CELL_STAGGER := 0.06
const DATA_CELL_SLIDE_TIME := 0.32
## DER TRAGE-BOGEN (Welle O): was der SPIELER bewegt, fliegt ÜBER dem Tisch -
## Magazin <-> Etage ist ein Spieler-Zug. Seit der Welle Y liegen BEIDE Enden in
## DERSELBEN Grube, also reist die Karte INNERHALB der Grube - und seit dem
## PATERNOSTER liegt sie schon, wenn sie aufbricht: das Umlegen (DATA_CELL_LIFT_TIME)
## und das Aufrichten daheim (DATA_CELL_PLUNGE_TIME) sind mit der stehenden Karte
## gestorben, es bleibt der flache Bogen durch den Durchbruch.
const CARRY_TIME := 0.45
const CARRY_PEAK := DataCellView.HEIGHT * 1.2
## Die Luft, die der Gruben-Bogen unter der Tischkante freiläßt: eine halbe
## Kartendicke. Über die Kante kommt in der Werkstatt keine Karte mehr.
const PIT_CARRY_CLEAR := TowerView.CARD_THICKNESS * 0.5
## Die zwei Sitze, auf denen ein Trage-Bogen endet - danach richtet sich sein
## harter Endzustand.
const CARRY_SEAT_SOCKET := "socket"
const CARRY_SEAT_PIT := "pit"

## Die zwei Seiten des PATERNOSTER-Hebels: hinauf blättert vor, hinab zurück.
const PAGE_UP := "page_up"
const PAGE_DOWN := "page_down"
## DAS DURCHLICHT: der Zähl-Takt des Licht-Netzes und der flache Scheitel, mit dem
## ein LICHTFUNKE vom Turmkopf in die Seite des Würfels schlägt.
const LIGHT_TICK_TIME := 0.22
const SPARK_PEAK := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT
## Wie hoch der Zielwürfel ÜBER dem Turmkopf schwebt: ZWEI Würfelkanten. GEMESSEN -
## dichter darüber deckt er an der geneigten Station das Licht-Netz zu und die
## Funken hätten keinen sichtbaren Weg, höher läuft er aus dem Rahmen.
const TOWER_DIE_CLEAR := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT * 4.0
## Wieviel der Kopfraum-Projektion der Turm SEITLICH abgibt: er steht am rechten
## Rand des Streifens, und ein hoher Körper wächst vom Bildmittelpunkt weg.
## GEMESSEN an der Weitsicht: bei 0,55 deckte die oberste Karte den GRIFF-Knopf
## noch halb zu, bei 1,0 steht er frei.
const TOWER_LEAN_SHARE := 1.0
## Zähl-Animation beim Nehmen (siehe _play_take_animation).
const SCORE_ROW_X := 2.0  # Reihen-X in der Grube (obere Hälfte)
const SCORE_ROW_SPACING := 2.9
const SCORE_HOVER_HEIGHT := 0.0  # 0 = die Würfel liegen beim Zählen auf dem Tisch
const SCORE_LIFT_TIME := 0.5
const SCORE_GLOW_SIZE_FACTOR := 1.5  # Glow-Kantenlänge als Vielfaches der Würfelgröße
const FULL_COUNTER_GLOW_FAINT := 0.32  # Vollzähler: schwacher Glow der Nicht-Kombi-Würfel
## Rhythmus: jeder Schritt wartet die ANKUNFT seines Kometen ab (Ursache→Wirkung
## sichtbar geschlossen), dann eine sich verkürzende Pause (Accelerando) - erste
## Würfel wirken bedacht, lange Hände ziehen sich zu einem Trommelwirbel zusammen.
const SCORE_STEP_GAP_START := 0.32
const SCORE_STEP_GAP_DECAY := 0.85
const SCORE_STEP_GAP_MIN := 0.1
## Krit: Extra-Halt nach der Komet-Ankunft, damit Hit-Stop + Einschlag des
## Mult-Orbs (TableScreen.crit_pit_mult) ausspielen, bevor der nächste Schritt
## den Trommelwirbel fortsetzt - der Krit bricht das Accelerando bewusst.
const CRIT_HOLD := 0.45
## LADUNG in der Zeremonie: der Blitz einer ladenden Zündung, der Rundum-Einschlag
## des Durchbrenners in die Grubenwände und der gedimmte Blitz des Entladens.
const CHARGE_FLASH_STRENGTH := 0.9
const CHARGE_BURN_SLAM := 1.0
const COOLING_FLASH_STRENGTH := 0.45
## Das Entladen am Rundenende: alle betroffenen Würfel zugleich, kurz gehalten.
const COOLING_TIME := 0.6
## Drain: Grunddauer + je Überladungs-Rollover; jeder Rollover hält kurz inne.
const DRAIN_BASE_TIME := 0.8
const DRAIN_PER_ROLLOVER := 0.4
const DRAIN_MAX_TIME := 2.5
const DRAIN_HOLD := 0.15
const DRAIN_SEGMENT_MIN := 0.25

## Streamende Zähl-Animation: Schritt-Index (seq) des nächsten Kometen, höchster
## bereits angewandter Index (hält die Anzeige monoton bei Ankunft in anderer
## Reihenfolge) und Zahl der noch fliegenden Kometen (Verschmelzungs-Gate).
var _score_seq := 0
var _score_applied := -1
var _score_pending := 0
var _score_gap := 0.0  # aktuelle Nach-Ankunft-Pause (Accelerando, je Hand zurückgesetzt)
## Augen-Pips: laufende Tick-Nummer, je Slot die zuletzt angewandte (hält die
## Ziffer monoton) und der Stand, auf den der Slot zuläuft.
var _eye_tick_seq := 0
var _eye_tick_applied := {}
var _eye_planned := {}

## Ständiges Würfelnetz-Feld der Grube, mittig über der langen Grubenachse;
## die Aktions-Knöpfe docken links/rechts an, der Bank-Knopf darunter
## (place_pit_actions leitet alles aus diesem Rechteck ab).
const PIT_INFO_BAR_INSET_X := 3.6  # Feldmitte unter der Würfelreihe (Welt -X)
const PIT_INFO_BAR_HALF_X := 2.0   # halbe Feldhöhe (Welt-X); klarer Abstand zur Grubenwand
const PIT_INFO_BAR_HALF_Z := 2.4   # halbe Feldbreite (Welt-Z)
## Deal-Marken-Streifen am OBEREN Grubenrand (Welt-X), gegenüber der Erklärleiste:
## zwischen Grubenwand (+7.6) und der Würfelreihe (X = 0). Links aus der Mitte
## gerückt, weil dort die Daten-Ader des Wertungsfensters in die Grube steigt -
## auf deren Spur darf keine Marke liegen.
const PIT_DEAL_RAIL_INSET_X := 5.3   # Streifenmitte (Welt +X)
const PIT_DEAL_RAIL_HALF_X := 1.3    # halbe Streifenhöhe (Welt-X)
const PIT_DEAL_RAIL_OFFSET_Z := -7.0 # Streifenmitte (Welt-Z), links der Ader
const PIT_DEAL_RAIL_HALF_Z := 5.0    # halbe Streifenbreite (Welt-Z)
## Einzeilige Material-Erklärleiste IM Gruben-Screen, zwischen Netz-Feld und
## Grubenwand (breit, kein Umbruch).
const PIT_HINT_INSET_X := 6.6  # Leistenmitte, zwischen Feld-Unterkante (-5.6) und Grubenwand (-7.6)
const PIT_HINT_HALF_X := 0.5   # halbe Leistenhöhe (Welt-X)
const PIT_HINT_HALF_Z := 9.0   # halbe Leistenbreite (Welt-Z) - viel Platz für eine Zeile
## Nachlauf des Netzes, nachdem die Maus den Würfel verlassen hat - die Zeit,
## um mit dem Cursor ins Netz-Feld zu fahren, ohne dass es sich leert.
const NET_LINGER_TIME := 0.7
## Danach blendet das Netz über diese Zeit aus (statt hart zu verschwinden);
## fährt die Maus während des Ausblendens ins Feld, kehrt es voll zurück.
const NET_FADE_TIME := 0.3

## Geld-Lichtanimation: Gutschriften schicken goldenes Licht Hub -> Chips,
## Käufe je bezahltem Chip einen Puls in dessen Farbe zurück zum Hub.
const MONEY_PULSE_GAP := 0.08
const MONEY_PULSE_BOOST := 2.2  # Chip-Farbe -> überhelle Leiterbahn-Farbe

## Energiefeld-Blitz bei Wandkontakt (siehe _on_die_wall_contact).
const FIELD_FLASH_MIN_SPEED := 2.0
const FIELD_FLASH_FULL_SPEED := 14.0
const FIELD_FLASH_MIN_STRENGTH := 0.35

const DECK_SHIFT_DURATION := 0.45  # Aufrück-Animation der Deck-Würfel

const REORDER_DRAG_THRESHOLD := 6.0  # Pixel, ab wann ein Klick als Zieh-Geste zählt
const REORDER_LIFT_HEIGHT := 0.8
const REORDER_DROP_RADIUS := 140.0  # Pixel-Toleranz beim Loslassen

const SHELL_FLY_DURATION := 0.4

## Reihe der geschützten Würfel am oberen Grubenrand: nah an der Mitte und eng
## gestellt, damit eine volle 6er-Reihe nicht in der elliptischen Wand steckt.
const PIT_TOP_ROW_X := 4.0
const PIT_TOP_ROW_SPACING := 2.1

## Nach dem Ausrollen gleiten ALLE Würfel in eine Reihe in der Grubenmitte.
const PIT_CENTER_ROW_X := 0.0
const LINEUP_DURATION := 0.35

## Verschiebung des Grubenzooms Richtung Charms (+X = Screen-oben).
const PIT_ZOOM_UP := 4.0

## Mausrad-Navigation: EIN Rad-Schritt = EINE Zoomstufe, also genau die Fahrten,
## die auch Klick und Rechtsklick auslösen - die Zoom-Distanzen sind gerechnet
## (Texturauflösung, gerahmte Rechtecke) und vertragen kein freies Heranfahren.
## Trackpads melden Bruchteile in factor, darum wird bis zu einer vollen Kerbe
## gesammelt; ein Richtungswechsel verwirft das Angesammelte.
const WHEEL_STEP_THRESHOLD := 1.0
var wheel_accum := 0.0

## Grobe Spielphase - genau EINE zur Zeit; Eingabe-Gates prüfen gegen sie.
## Nebenläufige Kosmetik (Deck-Aufrücken, Drags, Bogen-Abschluss) ist bewusst
## KEINE Phase und darf parallel laufen.
enum Phase { IDLE, SHELL_ANIMATING, ROLLING, SCORING, PAYOUT, SHOP, GAME_OVER }

@onready var settings_menu: VBoxContainer = $UI/SettingsMenu
@onready var settings_toggle_button: Button = $UI/SettingsToggleButton
@onready var reset_button: Button = $UI/SettingsMenu/ResetButton
@onready var debug_win_round_button: Button = $UI/SettingsMenu/DebugWinRoundButton
@onready var library_button: Button = $UI/SettingsMenu/LibraryButton

## Testmodus-Knopf (per Code angehängt): zufällige Materialien auf ALLEN
## Würfeln + unerschöpfliche Gravuren an/aus.
var test_materials_button: Button
var test_materials_enabled: bool = false

## Zweiter Testmodus: 1-5 zufällige Pointer auf ALLEN Würfeln an/aus -
## getrennt von den Materialien, damit die Kette allein prüfbar bleibt.
var test_pointers_button: Button
var test_pointers_enabled: bool = false

## Dritter Testmodus, kein Schalter sondern eine LIEFERUNG: je Datenkarten-Sorte
## außer den Würfel-Paketen ein voller Stapel ins Regal, damit die Presse ohne
## Einkaufsrunden geprüft werden kann.
var test_engravings_button: Button
const TEST_PACK_COUNT := 20

var charm_library: CharmLibraryView
@onready var hand_label: Label = $UI/HandLabel

## Der Shop lebt als Neon-Panel auf der Hub-Fläche (ohne Screen-Mesh als
## Fenster-UI); scene_root spricht ihn nur über open()/closed an.
const SHOP_SCENE := preload("res://scenes/shop_panel.tscn")
var charm_shop: ShopController
## Die Ladungs-Bank in der Geld-Ecke - das physische Gegenstück der ⚡-Börse.
var capacitor_bank: CapacitorBankView
## Klickzone des Schwarzmarkt-Fensters; erst mit der Entdeckung anfassbar.
var secret_shop_click_zone: StaticBody3D
## Vertragswahl auf dem Grubenboden; sie erscheint beim ersten Grubenzoom der
## Runde. route_pending = der Deal dieser Runde fehlt noch: bis dahin ruhen die
## Rundenbeginn-Wirkungen und der Wurf ist gesperrt.
var route_choice: RouteChoiceView
var route_pending := false
## Die Runde ist festgezurrt: der Vertrag ist unterschrieben bzw. - in einer Runde
## ohne Auslage - der erste Wurf ist gefallen. Bis dahin bleibt die Werkbank offen
## (siehe _dice_editing_locked), danach sind die Würfel tabu.
var round_committed := false
## Der Laden darf noch einmal aufmachen: gesetzt beim ERSTEN Schließen eines
## Besuchs, gelöscht mit der Unterschrift (bzw. dem ersten Wurf) - dasselbe
## Fenster wie die Werkbank. Der Wieder-Eintritt würfelt NICHTS neu.
var shop_reopen_allowed := false
## Der offene Laden ist ein Wieder-Eintritt: sein Schließen zieht die Runde NICHT
## noch einmal weiter.
var shop_reopened := false
## Rand der Auslage als Anteil der Grubenbreite (rundum gleich). Sie nimmt den
## ganzen Grubenboden - das Gruben-Mobiliar weicht ihr solange.
const ROUTE_CHOICE_INSET := 0.04

## Rückblick: die Chronik der laufenden Runde und ihr Fenster in der Grube.
## log_open ist das EINZIGE Arbitrierungs-Bit des Erinnerungs-Modus (die Phase
## bleibt IDLE) - solange es steht, schweigen alle Anzeigen-Schreiber pro Frame
## und der Tisch zeigt die aufgezeichnete Vergangenheit.
var round_log := RoundLog.new()
var log_view: LogView
var log_open := false
## (Eintrag, Schritt); Eintrag -1 = die Liste steht, noch nichts posiert.
var log_cursor := Vector2i(-1, 0)
var _log_posed_entry := -1
## Spiegel der lebenden Grube, gestellt beim Öffnen und beim Schließen zurück.
var _log_pit_mirror: Dictionary = {}
## Höhe der Schritt-Leiste als Anteil der Grubenhöhe - sie steht am oberen Rand,
## die posierten Würfel liegen darunter.
const LOG_BAR_HEIGHT := 0.16

## Titel-HUD (Startbildschirm + Menü) als Hub-Seite; davor stand die Kamera in
## title_prev_mode und kehrt beim "Weiterspielen" dorthin zurück.
var title_view: TitleView
var title_prev_mode: CameraRig.Mode = CameraRig.Mode.OVERVIEW

## Lexikon als Hub-Seite; geöffnet aus dem Hub-Fußknopf oder per Schlüsselwort-
## Klick (Laden-Tooltip). Schließen fliegt nach lexikon_prev_mode zurück.
var lexikon_view: LexikonView
var lexikon_prev_mode: CameraRig.Mode = CameraRig.Mode.HUB

## Auszahlungs-Seite des Rundenendes (Hub-Seite): sie steht, solange die
## Zeremonie zählt, und hält die Runde bis zum Kassieren an.
var payout_ledger: PayoutLedgerView

@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/VBoxContainer/GameOverLabel
@onready var game_over_reset_button: Button = $UI/GameOverPanel/VBoxContainer/GameOverResetButton

@onready var pool_tray_view: DiceTrayView = $PoolTrayView
@onready var queue_tray_view: DiceTrayView = $QueueTrayView
@onready var dice_shell: DiceShell = $DiceShell

## Editor-Anker der Screen-Elemente: im Editor frei verschiebbar, _ready
## rechnet ihre Weltposition auf den Screen um.
@onready var combos_anchor: Marker3D = $ScreenAnchors/CombosBlock
@onready var goal_bar_anchor: Marker3D = $ScreenAnchors/ScoreBar
@onready var base_counter_anchor: Marker3D = $ScreenAnchors/BaseCounter
@onready var mult_counter_anchor: Marker3D = $ScreenAnchors/MultCounter
@onready var hub_anchor: Marker3D = $ScreenAnchors/Hub

var combo_labels: Dictionary = {}  # DiceScoring-Key -> ComboCellView
var combo_chips: Dictionary = {}  # DiceScoring-Key -> ComboChipView (3D-Chip auf dem Glas)
var highlighted_combo_key: String = ""  # gerade golden hervorgehobene Kombination
## Trefferkörper der Übertaktungs-Schilder -> Kombinations-Key (Klick und Hover).
var combo_pick_keys: Dictionary = {}
var _hovered_combo_key: String = ""
## Stehen die Chip-Trefferkörper scharf? Der Einstieg in die Freikamera meldet
## keinen Moduswechsel, also hält der Zeiger-Abgleich je Bild die Waffe nach.
var _combo_picks_live: bool = false

@onready var camera_rig: CameraRig = $Camera3D
@onready var dice_pit: DicePit = $DiceTray
@onready var pit_click_zone: StaticBody3D = $DiceTray/PitClickZone
@onready var charm_row: CharmRowView = $Charms
## Geldstand als physische Neon-Pokerchips auf dem Tisch.
@onready var chip_stack: ChipStackView = $ChipStack
## Zuletzt ANGEZEIGTER Geldstand - Vergleichsbasis der Geld-Lichtanimation.
var _shown_money := 0

var dice: DiceController
var dice_audio: DiceAudio
var table_screen: TableScreen
var screen_reflection: ScreenReflection
var combos_click_zone: StaticBody3D
var charms_click_zone: StaticBody3D
var hub_click_zone: StaticBody3D
var side_bets_click_zone: StaticBody3D
var score_click_zone: StaticBody3D
var slots_click_zone: StaticBody3D
var workshop_click_zone: StaticBody3D
var repair_click_zone: StaticBody3D
## Die LADESÄULE: der Körper der Reparatur-Station, rechts neben dem Podest.
var charging_column: ChargingColumnView
var chips_click_zone: StaticBody3D
## Werkbank-Ecke ohne Trays (Display-Pixel): Ziel der Nahsicht und zugleich die
## Fläche, auf der ein Doppelklick sie öffnet.
var workshop_close_rect := Rect2()
## Chip-Umtausch (nur in der Chip-Zoomsicht): gezogener Turm als Geist zum
## Einwurf-Schlitz; -1 = keine Geste aktiv.
var chip_drag_value := -1
var chip_drag_count := 0
var chip_drag_ghost: Node3D
## Laufender Umtausch blockiert eine neue Geste; jede Geldänderung entwertet
## das Token und stoppt damit verspätete Umtausch-Etappen.
var _exchange_token := 0
var _exchange_busy := false
## Letzter weitergereichter Display-Pixel (relative-Feld der Motion-Events).
var last_screen_pixel := Vector2(-1, -1)

## Der Würfel auf einem der ZWEI Podeste der Werkstatt - dem EINEN Würfel-Halter
## des Spiels (das Podest am Ausgabefach ist mit der Bühnen-Straße gestorben). Er
## schwebt über dem EINEN Netz der Würfel-Spalte (null = es steht keiner).
var bench_stage: FloatingDie
## Sein ORT: er LIEGT im Pool, bis er zur Bühne WANDERT. Steht er hier, bleibt sein
## Pool-Sitz leer - ein Würfel wird nie zweimal gezeigt. Geschrieben wird er allein
## von _seat_bench_place.
var _bench_die: DieDefinition
## Und ob gerade eine Fahrt läuft - guardt das Doppel-Auslösen (Zielwahl UND
## Kamerawechsel im selben Bild) und hält den Bühnen-Schreiber von der fahrenden
## Ware fern.
var _bench_riding := false
## Der Schacht der Fahrt - dieselbe Maschine trägt beide Beine (Senken am Pool-Sitz,
## dann Heben an der Bühne).
## Generationsmarke der Fahrten: ein Abbruch (Reset/Laufwechsel) zählt sie hoch, ein
## noch laufender Tween meldet dann nichts mehr zurück.
var _bench_gen := 0

## Die physischen Datenzellen der Werkbank: je Magazin-Paket (uid) seine LIEGENDE
## Kassette auf ihrem Tablett und je belegter Turm-Etage die, die darin liegt.
## Weltkörper wie die Zwingen - reine ANZEIGE: sie tragen keine Kollision und
## fangen keinen Klick, der läuft weiter durch die leeren Knöpfe im Fenster
## (Chip-Schalen-Regel).
var shelf_cells: Dictionary = {}
var socket_cells: Array[DataCellView] = []
## Die Kassetten, die gerade einen TRAGE-BOGEN fliegen: Körper -> {"to", "seat",
## "uid"}. EIN Schreiber, EIN Aufräum-Pfad (_settle_carries).
var _carrying: Dictionary = {}
## uid je Schlitz, parallel zu socket_cells: daran erkennt der Abgleich SEINE
## Zelle wieder und gibt sie beim Auswerfen an ihren Magazin-Platz zurück.
var socket_uids: Array[int] = []
## Das LICHT-NETZ der laufenden Serien-Zeremonie (null = keines reitet) und die
## Generation dieser einen Zeremonie.
var _light_net: LightNetView
var _press_gen := 0
## Die LICHTFUNKEN des Einschlags - alle zugleich unterwegs, EIN Aufräum-Pfad.
var _sparks: Array[LightSparkView] = []
## Die Etage unter dem Zeiger (-1 = keine): ihre Karte fährt nach links heraus.
var _hovered_step := -1
## Läuft gerade ein DURCHLICHT? Dann führt die Zeremonie den Podest-Würfel, und der
## Steady-State-Schreiber der Bühne hält still.
var _durchlicht := false
## Der TURM selbst (null = steht gerade nicht) - sechs Etagen als EIN Körper.
var tower: TowerView
## Zellen unterwegs: heimfliegende Rückläufer (uid -> Körper; sie fehlen im
## Magazin-Abgleich, bis sie ankommen und dort selbst zur Kassette werden) und
## die Körper, die gerade dekomprimiert werden.
var _cell_returns: Dictionary = {}
## Ankunfts-Pluster, deren Kassette noch gar nicht wieder stand (uids).
var _pending_cell_pops: Array[int] = []
## Pakete, deren Kassette beim nächsten Abgleich aus dem GRUBENBODEN steigen soll
## statt an Ort und Stelle aufzuploppen - das ist die eine Ankunft des Magazins,
## wer auch immer liefert (uid -> true).
var _rising_packs: Dictionary = {}
## Nur der ZULETZT angestoßene Abgleich läuft nach dem gewarteten Bild weiter -
## sonst stellten zwei Aufbauten im selben Bild zwei Körper auf denselben Platz.
var _data_cell_gen := 0
## Die MAGAZIN-GRUBE: Wände, Boden und Kragen unter dem Loch, das screen_glass in
## die Anzeige schneidet. Möbel wie die Trays - sie steht ab dem Aufbau und tritt
## für keinen Ablauf ab. Die Läden stehen flächig.
var pack_pit: PackPitView
## Und die TURM-BUCHT: derselbe Körper, dieselbe Tiefe, zum Magazin hin OFFEN - die
## beiden bilden EINEN L-förmigen Raum, in dem der Turm steht (Welle Y).
var tower_pit: PackPitView
## Der PATERNOSTER in der Magazin-Grube: fünf Tabletts übereinander, gezeigt wird
## eines. Er TRÄGT die Karten (sie sind Kinder ihres Faches), also fahren sie mit.
var paternoster: PaternosterView
## Und der HEBEL auf dem Filz rechts neben der Grube, der blättert. Nur der SPIELER
## bewegt den Paternoster - nichts blättert von selbst.
var page_lever: LeverView
## Der an der Grube GEMESSENE Magazin-Deckel (0 = noch nicht gemessen). Er gehört
## dem Tisch, nicht dem Lauf: _sync_pack_pit liest ihn ab, _connect_run schiebt
## ihn jedem frischen Lauf herein (dasselbe Muster wie apron_bottom - core misst
## keine Fenster).
var _pack_capacity := 0
## ... und die SPALTEN, aus denen er fällt: so viele Kassetten liegen in EINE Reihe.
var _pack_columns := 0
## Der Filzboden rings um die Anzeige. Er muss dort ausblenden, wo die Grube steht,
## sonst blickt man durch das Loch auf Filz statt in die Vertiefung.
var table_ground: TableGround
## Die LADEN-AUSLAGE: die Ware, die auf der Ladenseite steht. Sie hängt an dem
## Rechteck, das ShopController meldet (apron_bottom-Muster) - der Laden weiß vom
## Tisch nichts.
var shop_vitrine: VitrineView
## Zuletzt entschiedener Stand der Auslage - der Entscheider läuft je Bild.
var _vitrine_curtain := false
## Wie beim Zellen-Abgleich: nur der ZULETZT angestoßene Aufbau misst weiter.
var _vitrine_gen := 0
## Wo das zuletzt gegriffene Stück in die Fläche gesunken ist (Display-Pixel):
## dort startet sein Liefer-Komet. (-1,-1) = keine gemerkte Stelle.
var _vitrine_depart_px := Vector2(-1, -1)
## Der aufgesparte Ankunfts-Grad: bei abgedeckter Auslage wird lautlos umgebaut,
## der Auftritt wartet aufs Aufdecken. Er wird EINMAL gefahren.
var _vitrine_grade := ShopController.GRADE_STAND
## Laufende Nummer des Warenumschlags - nur der jüngste stellt die Zielseite.
var _vitrine_swap := 0
## Solange die Auslage ihre Körper baut, bleibt sie abgedeckt: sonst deckte sie
## halb gestellt auf.
var _vitrine_building := false
## Die SCHLUCK-ZEREMONIE läuft: der Laden ist zu, die Ware fährt noch hinaus. EIN
## Schreiber (_play_vitrine_exit setzt, _hide_vitrine_hard löscht) - sonst startete
## der Entscheider je Bild eine neue Zeremonie oder verstecke die laufende sofort.
var _vitrine_leaving := false
## Laufende Nummer des Abgangs - nur der jüngste darf am Ende den Vorhang fallen
## lassen.
var _vitrine_exit := 0

## Die KASSETTEN-PLÄTZE der Ladenseite: je belegtem Platz eine LIEGENDE Zelle auf
## der Tischfläche (Platz-Index -> Körper). Der Laden markiert den Stellplatz, die
## Körper gehören scene_root.
var slit_cells: Dictionary = {}
## Identität des Pakets je Platz: eine neue Doppelseite bringt neue Kassetten,
## kein umgestecktes Blech.
var _slit_keys: Dictionary = {}
var _slit_gen := 0
## Die Kassetten, die gerade HINAUSFAHREN: sie gehören keinem Platz mehr. Der
## Band-Schritt gibt sie frei - und jeder Abbruch (_settle_slit_shaft).
var _slit_leaving: Array[DataCellView] = []
## Die HEBEBÜHNE der Reihe: dieselbe Maschine wie in einer Bucht, nur gehört ihr
## Schacht scene_root - die Schlitzreihe ist Tischmöbel, keine Auslage.
var slit_shaft: LiftShaftView

## Der WETT-TRESEN unter dem Nebenwetten-Fenster: je Angebot EIN Plot - das
## Rechteck seines Setzen-Knopfes - und darauf sein GEWINN.
## Das Fenster meldet die Plätze, die Körper gehören scene_root - dieselbe Grammatik
## wie die Kassetten-Schlitzreihe des Ladens.
## Die Körper sind reine ANZEIGE: keine Buchung hängt an einem von ihnen.
var bet_bodies: Dictionary = {}
## Signatur je Platz - eine andere Signatur heißt anderer Körper, kein umgestecktes
## Blech.
var _bet_keys: Dictionary = {}
## Wo jeder Körper auf seinem Plot sitzt (Platz-Schlüssel -> Weltpunkt auf dem Glas) -
## geschrieben vom EINEN Schreiber, gelesen von der Abrechnung.
var _bet_seats: Dictionary = {}
## Die GEPARKTEN Gruben: Plot-Index -> {depth, field}. Ihr Loch steht OFFEN und der
## Gewinn wartet unten sichtbar darin - ein legitimer ENDZUSTAND, den der Schreiber
## jederzeit hart wiederherstellt. Loch und Tiefe bleiben dabei gemerkt: ein neu
## gemessener Schacht ließe die wartende Ware springen.
var _bet_parked: Dictionary = {}
## Der gelandete EINSATZ, den die Sektion ihres Plots gleich SCHLUCKT (Plot-Index ->
## Wurfkörper). Vom Einsatz bleibt danach nichts liegen.
var _bet_swallow: Dictionary = {}
## Wo die Timeline gerade steht (die Regel dazu gehört dem Fenster,
## SideBetPanel.counter_lies): nichts, die offene Wettannahme, die laufende Runde
## oder in der Abrechnung allein die Gewinne.
var _bet_stage := SideBetPanel.STAGE_NONE
## Die gewonnenen Wetten der laufenden Abrechnung (nur für STAGE_WON).
var _bet_won: Array[SideBet] = []
## Wetten, deren Bedingung ERFÜLLT ist: ihr Gewinn fährt aus der Grube herauf.
## Gespeist allein aus der bestehenden Fortschritts-Rechnung (_note_bet_progress) -
## es gibt keine zweite Bedingungs-Auswertung.
var _bet_fulfilled: Array[SideBet] = []
## Und ihr Spiegel: Wetten, deren Bedingung GESCHEITERT ist - ihr Gewinn wird
## eingezogen. Dieselbe eine Quelle, derselbe Melder.
var _bet_failed: Array[SideBet] = []
## Die Körper, die gerade HINAUSFAHREN, je Plot geführt - freigegeben am Ende des
## Band-Schritts und beim Settle IHRER Sektion, nie durch die Fahrt eines Nachbarn.
var _bet_leaving: Dictionary = {}
## Die HEBEBÜHNEN des Tresens: je Plot EINE eigene Sektion mit eigenem Platz in der
## Löcherliste. Drei Wetten parken, fahren auf und gehen ab, ohne einander zu stören.
var bet_shafts: Array[LiftShaftView] = []
## Die WANDHAUT, die NUR sie bestellen: dunkle Technik-Paneele mit haarfeinen
## Leuchtlinien. JEDE Grube des Tisches trägt sie - Wett-Tresen, Laden, Hinterzimmer,
## Schlitzreihe und Magazin -, damit keine Vertiefung anders liest als die nächste.
const PIT_SKIN: Texture2D = preload("res://assets/textures/gruben_paneel.png")
## Und die TIEFFAHRT, die ebenfalls nur sie bestellen: zum Ein- und Ausfahren sinkt
## eine Wett-Grube doppelt so tief wie sie aussieht. Nur hier steht die Nachbargrube
## offen, und nur hier ragte die wartende Ware aus dem kurzen Hohlraum in ihr Loch.
const BET_PIT_DIVE := 2.0
## Ein AUFTRITT ist fällig, aber keiner schaut hin: der Tresen stellt still und
## fährt ihn nach, sobald er wirklich zu sehen ist (die Grad-Regel der Läden).
var _bet_pending_rise := false

## Die WÜRFEL-HEBEBÜHNEN (siehe die Region "Die WUERFEL-BUEHNE"): der Vorrat auf
## seinem Platz, die Warteschlange mit EINER Maschine JE PLATZ (Fahrten dürfen
## überlappen - eine Maschine ist ein Loch) und der SCHLUCK auf drei BAHNEN, damit
## eine gestaffelte Salve überlappen kann. Jede Maschine hat ihren festen Platz in
## der Löcherliste.
var pool_shaft: LiftShaftView = null
var _queue_shafts: Array[LiftShaftView] = []
var _swallow_shafts: Array[LiftShaftView] = []
## Steht das Pool-Tray oben auf dem Tisch? Ab dem Zurren der Runde ist es der TRÄGER
## im offenen Pit - sichtbar, nur tiefer. EIN Schreiber, alle fragen ihn.
var _pool_standing := true
## Sein Heimat-Ort - gemerkt, bevor er das erste Mal fährt; die Fahrt schreibt an
## global_position, gemessen wäre er danach falsch.
var _pool_tray_home := Vector3.ZERO
## Der eingefrorene Grundriß des offenen Pits ({at, half}). Neu gemessen ließe ein
## Würfelkauf mitten in der Runde das Loch unter dem Träger springen.
var _pool_parked_field: Dictionary = {}
## Wieviele Reihen der Träger schon vorgerückt ist: eine je leer gezogener Pool-Reihe.
## Das Loch steht fest, der Träger fährt darunter.
var _carrier_shift := 0
var _carrier_tween: Tween = null
## Die Sitze, deren Würfel gerade ABFAHREN - der Schreiber zeigt sie weiter, bis ihre
## Fahrt steht; sonst verschwände der Körper im Bild seines Aufbruchs.
var _carrier_leaving: Dictionary = {}
var _carrier_sinks: Array[Tween] = []
## Die ABLAGE im Träger: je Eintrag {def, face, seat, body}, in Pit-Ordnung. Sie ist
## am Rundenende der Schwanz des neuen Pools.
var _ablage_seats: Array[Dictionary] = []
## Was geschluckt ist, aber noch keine volle Reihe füllt (unsichtbar gepuffert).
var _ablage_buffer: Array[Dictionary] = []
## Wieviele Reihen gerade einfahren - das hintere Band schließt erst mit der letzten.
var _ablage_entering := 0
var _ablage_root: Node3D = null
## Die Abgänge, die noch geschluckt werden wollen, und je Bahn der fahrende Körper
## (null = die Bahn ist frei). Ein getöteter Tween meldet nie fertig - der harte
## Pfad räumt die Körper selbst.
var _swallow_queue: Array[Dictionary] = []
var _swallow_bodies: Array[Node3D] = []
## Die Lauf-/Generationsmarke der Bühnen-Zeremonien - jeder Abbruch dreht sie weiter.
var _tray_stage_gen := 0
## Die Warteschlangen-Bühne: steht die Reihe (alle Pucks) oben, und welcher Platz
## zeigt gerade einen Würfel? Der Schreiber diffed gegen diese Belegung.
var _queue_staged := false
var _queue_dice_up: Array[bool] = []
## Die Plätze, deren Einzel-Fahrt gerade läuft - für den harten Abbruch.
var _queue_ride_slots: Dictionary = {}

## Die ABLAGE der Auszahlungs-Seite: die gewonnene Ware steht NEBENEINANDER auf EINER
## Plattform, in den Zellen, die die Seite meldet. Jedes Stück steigt bei der Ankunft
## seines Lichts aus der Fläche und versinkt beim Kassieren wieder - reine ANZEIGE,
## gebucht ist längst.
var payout_bodies: Dictionary = {}
## Wo jeder von ihnen sitzt (Zellen-Index -> Weltpunkt auf dem Glas).
var _payout_seats: Dictionary = {}
## EINE Sektion mit EINEM Platz in der Löcherliste - eine Plattform, ein Loch.
var payout_shaft: LiftShaftView = null
## Ihre Tiefe, einmal am tiefsten Stück genommen: ein Neuschnitt mitten in der Reihe
## setzte die schon stehende Ware zurück.
var _payout_depth := 0.0
## Die zurückgehaltenen Gewinn-Pakete: ihre Kassette steigt erst NACH dem Kassieren.
var _payout_packs: Array[int] = []
## Was beim Kassieren noch als Licht an sein Ziel reist: je Wette {bet, money, energy}.
var _payout_claims: Array[Dictionary] = []
## Die Körper, die gerade VERSINKEN - freigegeben am Ende ihres Band-Schritts, und vom
## EINEN Aufräum-Pfad, falls er sie dort überholt.
var _payout_leaving: Array = []
## Laufende Nummer der Ablage - nur die jüngste räumt sie ab.
var _payout_gen := 0

## Die HINTERZIMMER-AUSLAGE: dieselbe Miniatur am Schwarzmarkt-Fenster. Sie steht,
## sobald der Schwarzmarkt freigeschaltet ist - unabhängig von der Kamera.
var secret_vitrine: VitrineView
var _secret_curtain := false
var _secret_gen := 0
var _secret_swap := 0
var _secret_grade := ShopController.GRADE_STAND
## Wo die zuletzt gekaufte Hehlerware in die Fläche gesunken ist.
var _secret_depart_px := Vector2(-1, -1)

## Das AUSGABEFACH: die offene Schale rechts der Werkbank, in der die gekauften
## Würfel liegen, bis der Spieler ihren Platz im Vorrat wählt. Sie steht IMMER -
## pending_dice sind Lauf-Zustand und überdauern Besuche und Runden.
var ausgabefach: AusgabefachView
## Der RASTER-UMSCHALTER am Grubenrand: er legt den Vorrat zwischen KÖRPER und
## RASTER um (siehe #region Die GLAS-ANSICHT). Er steht ebenfalls IMMER.
var raster_switch: RasterSwitchView
## Der nächste gemeldete Würfel ist noch unterwegs: der Abgleich hält seinen
## Körper zurück, bis sein Liefer-Komet angekommen ist.
var _fach_expecting := false

## Der laufende TAUSCH: der Pool-Eintrag, dessen Sitz LEER bleibt, bis der alte
## Würfel unten hinaus ist (der Eintrag selbst trägt schon den neuen Inhalt -
## become überschreibt IN der Instanz), die beiden fahrenden Körper und die
## Generations-Marke, an der jeder Abbruch hängt.
var _exchange_hidden: DieDefinition = null
var _exchange_body: Node3D = null
var _exchange_ghost: Node3D = null
var _exchange_gen := 0

## Die Kassette, die der Zeiger gerade aus der Grube zieht (0 = keine).
var _hovered_pack_uid := 0

## Zieh-Geste an einem schwebenden Würfel: der gegriffene, und ob der Zeiger
## seither einen Weg zurückgelegt hat (dann war es keine Wahl mehr).
var grabbed_stage: FloatingDie
var grab_start := Vector2.ZERO
var grab_moved := false

## Der herangeholte Würfel der INSPEKTION (null = keiner) und die Kamera-Lage, aus
## der heraus zugegriffen wurde - dorthin geht es beim Verlassen zurück.
var focused_stage: FloatingDie
var _die_focus_home: Dictionary = {}

var phase: Phase = Phase.IDLE
var has_rolled_current_hand: bool = false
var hand_total: int = 0

var displayed_points: int = 0  # läuft hand_total animiert hinterher
var points_tween: Tween

## Der persistente Zustand des Spiellaufs (siehe GameRun) - bei jedem Neustart
## frisch erzeugt und an Shop/Gravur-Station gereicht.
var run: GameRun

var hands_taken_this_round: int = 0
var chimney_sweep_used_this_round: bool = false
var phoenix_used_this_round: bool = false
## Ankerklausel: ihr Freischuss gilt je Runde einmal (wie der Schornsteinfeger).
var anchor_clause_used_this_round: bool = false

var round_pool_kinds: Array[DieDefinition] = []  # feste Zieh-Reihenfolge der Runde
var next_draw_index: int = 0
## Das Nachschub-Tray materialisiert erst beim ersten Grubenzoom einer Runde;
## davor liegen ALLE Würfel im großen Dice-Tray. Reset je Rundenbeginn.
var queue_activated: bool = false
var active_kinds: Array[DieDefinition] = []  # aktuell den 6 Slots zugewiesen

var last_throw_was_reroll: bool = false
## Slots des LETZTEN Wurfs - die Fumble-Umrisse blinken nur bei diesen.
var last_thrown_slots: Array[int] = []
var pre_reroll_values: Array[int] = []  # Werte VOR dem Neu-Würfeln (Farkle-Vergleich)
var pre_reroll_materials: Array[String] = []
var pre_reroll_essences: Dictionary = {}  # Essenzen VOR dem Neu-Würfeln
var pre_reroll_runes: Dictionary = {}  # Runen der oberen Seiten VOR dem Neu-Würfeln
var pre_reroll_det_links: Dictionary = {}  # Runen-Glieder VOR dem Neu-Würfeln
var pre_reroll_essence_links: Dictionary = {}  # Röntgen-Glieder VOR dem Neu-Würfeln
var pre_reroll_levels: Dictionary = {}  # Material-Zustände VOR dem Neu-Würfeln
var pre_reroll_charges: Dictionary = {}  # Ladungen VOR dem Neu-Würfeln
var pre_reroll_burned: Dictionary = {}  # Durchgebrannte VOR dem Neu-Würfeln
var pre_reroll_phosphor: Dictionary = {}  # Phosphor-Speicher VOR dem Neu-Würfeln
var pre_reroll_phosphor_mult: Dictionary = {}  # dito für den Mult-Speicher
var pre_reroll_order: Array[int] = []  # angesagte Reihenfolge VOR dem Neu-Würfeln
var pre_reroll_first_scoring: Dictionary = {}  # Erstwertungs-Marken VOR dem Neu-Würfeln
## Der einzige Zufall der Wertung: der Pointer. Ein eigener Generator, damit
## der Wurf je Zug genau EINMAL fällt und danach im ctx eingefroren steht.
var pointer_rng := RandomNumberGenerator.new()
## Eigener Würfelbecher der LADUNG - so verschiebt sie die Pointer-Würfe nicht.
var charge_rng := RandomNumberGenerator.new()
## Was die letzte Buchung der Ladung bewegt hat (Zug, Fumble, Rundenende) - die
## Zeremonien der Welle 3 hängen daran, heute liest sie niemand.
var _last_charge_results: Array[Dictionary] = []
var _last_fumble_charges: Array[Dictionary] = []
var _last_cooled_dice: Array[DieDefinition] = []
## Vom Spieler gelegte Zählreihenfolge der liegenden Würfel (Slot-Indizes).
## Jeder Wurf setzt sie auf die kanonische Reihe zurück; Ziehen permutiert sie,
## und die Reihe in der Grube wird DARAUS gerendert - nie umgekehrt.
var player_order: Array[int] = []

# Zustand der Effektkatalog-Charms (ctx-Schlüssel siehe CharmEffects):
var rerolls_this_hand: int = 0  # Anker
var taken_dice_this_round: int = 0  # nur Statistik/Report (Nebenwetten)
var pendulum_acc: int = 0  # Pendel: akkumulierter Mult, überlebt Runden (+2/Neuwurf, -1/genommen)
var full_reroll_stacks: int = 0  # Roter Knopf
var _pendulum_shown: int = 0  # zuletzt angezeigter Pendel-Mult (Schwung-Animation)
var momentum_streak: int = 0  # Schwungrad
var first_hand_after_farkle: bool = false  # Galgenhumor
var recycling_used_this_round: bool = false
var slot_draw_positions: Array[int] = []  # je Slot die Zieh-Position (Bodensatz)
var discarded_this_round: Array[DieDefinition] = []  # Phönixfeder
## Die Seite, mit der jeder abgelegte Würfel abgelegt wurde - parallel zur Ablage
## und ihre einzige Wahrheit: das Tray zeigt sie, Fuchsfeuer zählt ihre Augen.
var discarded_faces_this_round: Array[int] = []
var hand_note: String = ""  # transiente Meldung (z.B. Farkle)

# Rundenbilanz für die Nebenwetten-Auswertung (je Rundenbeginn zurückgesetzt).
## Platzhalter für "noch keine Hand genommen" (Vollgriff prüft das Minimum).
const NO_HAND_DICE := 99
var round_best_combo_rank: int = -1  # bester genommener Kombi-Rang (SideBet.combo_rank)
var round_best_hand_score: int = 0   # höchster Einzel-Hand-Score
var round_first_hand_score: int = 0  # Wertung der ERSTEN Hand (einmal gesetzt)
var round_farkled: bool = false
var round_combo_keys: Dictionary = {}   # genommene Kombi-Sorten (Set)
var round_combo_repeated: bool = false  # eine Sorte zweimal genommen
var round_fallback_taken: bool = false  # Höchste Zahl genommen
var round_high_hand: bool = false       # Hand aus 3+ Würfeln mit je 6+ Augen
var round_max_hand_dice: int = 0        # größte genommene Hand
var round_min_hand_dice: int = NO_HAND_DICE  # kleinste genommene Hand
## Wett-Fenster ist offen (nur vom Rundenbeginn bis zum ERSTEN Wurf platzierbar).
var betting_open: bool = false

var gameplay_ui_state_visible: bool = true  # false während Shop/GameOver
var is_pit_focused: bool = false

## Zuletzt im Würfelnetz gezeigter Würfel + Rest-Nachlauf (NET_LINGER_TIME) und
## Rest-Ausblendzeit (NET_FADE_TIME, läuft erst nach dem Nachlauf).
var _net_die_def: DieDefinition
var _net_linger := 0.0
var _net_fade := 0.0
## Seelen-Zeile des gezeigten Würfels - nur beim Wechsel gebaut (Essence.by_id
## legt den ganzen Katalog an, und _show_pit_net läuft je Frame).
var _net_essence_hint := ""
## Glühen des Miasma für seine Augen-Pips - aus demselben Grund einmal geholt.
var _miasma_glow := Color(0, 0, 0, 0)
## Dasselbe für das Radon, dessen Bestrahlung ebenfalls Augen schiebt.
var _radon_glow := Color(0, 0, 0, 0)

var lineup_tween: Tween

## Goldlichter der laufenden Zähl-Animation (siehe _cleanup_take_animation).
var take_anim_glows: Array[Control] = []

## Leucht-Podeste unter den AUSGEWÄHLTEN Würfeln (Slot -> Display-Knoten) -
## folgen den Würfeln jeden Frame, nur während der Auswahlphase sichtbar.
var _select_glows: Dictionary = {}

var deck_shift_ghosts: Array[Node3D] = []  # temporäre Würfel der Aufrück-Animation
var deck_shift_tween: Tween

## Ziehen/Klicken auf der Energie-Hülle: Drücken = Würfeln, Halten = Rütteln,
## Ziehen ohne Wurf = Drehen.
var shell_drag_active := false
var shell_drag_start_pos: Vector2
var shell_is_dragging := false
var shell_throw_pending := false  # der Druck hat einen Wurf ausgelöst

var queue_window_size: int = 0  # belegte Slots im Warteschlangen-Tray

## Umsortieren im Warteschlangen-Tray per Ziehen.
var reorder_drag_index: int = -1
var reorder_drag_start_pos: Vector2
var reorder_is_dragging: bool = false
var reorder_ghost: Node3D

## Umlegen der Zählreihenfolge in der Grube: Druck merkt sich den Würfel, erst
## der Weg entscheidet zwischen Auswahl-Klick und Ziehen (EINFÜGE-Semantik - die
## anderen rücken auf, wie in Balatro).
## Umlegen im Pool-Tray (-1 = keine Geste). Auch hier entscheidet erst der Weg
## zwischen Klick (Station öffnen) und Ziehen (Plätze tauschen).
var tray_drag_index: int = -1
var tray_drag_start_pos: Vector2
var tray_is_dragging: bool = false
var tray_drag_ghost: Node3D
var pit_drag_index: int = -1
var pit_drag_start_pos: Vector2
var pit_is_dragging: bool = false

## Der TAUSCH aus dem Ausgabefach (-1 = keine Geste): dieselbe Teilung wie im Tray -
## gezogen tauscht, getippt öffnet das Dossier des Neuzugangs.
var fach_drag_index: int = -1
var fach_drag_key: int = 0
var fach_drag_start_pos: Vector2
## Sein Platz in der Schale, gemerkt beim Anheben - danach hält die Schale ihn
## zurück und nennt ihn nicht mehr.
var fach_drag_home := Vector3.ZERO
var fach_is_dragging: bool = false
## Darf dieser Griff überhaupt tauschen? Einmal beim Drücken gefragt (Vorrat steht,
## Bearbeitungs-Fenster offen, das Tray ist die lokale Bühne); sonst bleibt nur das
## Dossier.
var fach_drag_swaps: bool = false
var fach_drag_ghost: Node3D

## Umsortieren der Tisch-Charms per Ziehen (gleiche Klick-oder-Drag-Logik).
var charm_drag_index: int = -1
var charm_drag_start_pos: Vector2
var charm_is_dragging: bool = false

## Startpositionen der 6 Spielwürfel vor dem ersten Wurf: der austarierte
## Fächer, um die Y-Achse gedreht, sodass er von der Energie-Hülle her kommt -
## Abstand zum Ursprung (und damit Wurfcharakter) bleibt exakt erhalten.
const DICE_START_POSITIONS: Array[Vector3] = [
	Vector3(6.5458, 17.095267, 7.7658),
	Vector3(3.2886, 17.095267, 6.7886),
	Vector3(0.0314, 17.095267, 5.8115),
	Vector3(-3.2258, 17.095267, 4.8343),
	Vector3(-6.4830, 17.095267, 3.8572),
	Vector3(-9.7402, 17.095267, 2.8800),
]

func _ready() -> void:
	# Die vier Runenzeichen EINMAL backen, bevor irgendein Würfel sie braucht -
	# sonst zahlt der erste beschriftete Würfel mitten im Spiel dafür. Hier kostet es
	# ~190 ms in einem Start, der ohnehin den ganzen Tisch aufbaut.
	RuneTextures.warm()
	_strip_table_rim()
	_setup_dice()
	_setup_table_screen()
	_setup_camera_targets()
	_setup_panels()
	_setup_settings_ui()

	_style_ui()
	_collect_combo_labels()
	_reset_game()
	# Der Tisch ist fertig gedeckt, die Runde läuft - der Spieler sieht davon
	# aber nur das Titel-HUD, bis er "Neues Spiel" drückt.
	_open_title(false, true)

## Blendet den Tisch-Korpus aus (siehe Konstante) - der Boden übernimmt.
func _strip_table_rim() -> void:
	for mesh_name: String in TABLE_HIDDEN_MESHES:
		var mi := $Room.find_child(mesh_name, true, false) as MeshInstance3D
		if mi != null:
			mi.visible = false

## Baut die 6 Spielwürfel samt Audio und Wandkontakt-Handlern.
func _setup_dice() -> void:
	# Der Heimat-Ort des Vorrats steht schon in der Szene - und die Werkbank-Ecke
	# samt Ausgabefach misst gleich an ihm, also gilt er ab hier.
	_pool_tray_home = pool_tray_view.global_position
	var roots: Array[Node3D] = []
	var bodies: Array[RigidBody3D] = []
	var face_displays: Array[DieFaceDisplay] = []
	for i in DICE_START_POSITIONS.size():
		var die := DieBuilder.build()
		$Dice.add_child(die)
		die.position = DICE_START_POSITIONS[i]
		# Tray-Größe, aber NUR Kollision + Optik skalieren, den RigidBody3D auf
		# Einheitsskala lassen: die Ruheerkennung liest die Körper-Basis per
		# Skalarprodukt gegen oben - mit skalierter Basis erreicht der Würfel
		# den Ausrichtungs-Schwellwert nie und käme nie zur Ruhe.
		var body: RigidBody3D = die.get_node("RigidBody3D")
		var die_scale := Vector3.ONE * DiceTrayView.DIE_SCALE
		(body.get_node("CollisionShape3D") as CollisionShape3D).scale = die_scale
		var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
		faces.scale = die_scale
		# Die Lache läuft bei jedem Würfel mit; hier endet sie zusätzlich an der
		# Grubenwand - sonst legte sie sich als Schleier über Ziel-Leiste und Filz.
		faces.set_pool_clip(DicePit.PIT_CENTER,
			Vector2(DicePit.PIT_HALF_X, DicePit.PIT_HALF_Z), DicePit.CORNER_RADIUS)
		ScreenReflection.mark_reflective(die)
		roots.append(die)
		bodies.append(body)
		face_displays.append(faces)
	dice = DiceController.new(roots, bodies, face_displays)

	dice_audio = DiceAudio.new()
	dice_audio.name = "DiceAudio"
	add_child(dice_audio)
	dice_audio.setup(bodies, dice)  # aktiviert auch contact_monitor der Würfel

	# DiceAudio hat die Kontaktmeldung schon eingeschaltet - hier hört ein
	# zweiter Handler mit und blitzt das getroffene Feldsegment auf.
	for body in bodies:
		body.body_entered.connect(_on_die_wall_contact.bind(body))

## Tisch-Display: ViewportTexture aufs "Screen"-Mesh. Fehlt das Mesh, läuft
## das Spiel einfach ohne Anzeige weiter.
func _setup_table_screen() -> void:
	table_screen = TableScreen.new()
	table_screen.name = "TableScreen"
	add_child(table_screen)
	# Der Filzboden muss hinter jedem Loch ausblenden - sonst blickt man durch die
	# Grube (oder einen offenen Schacht) auf Filz statt in die Vertiefung. Die
	# Löcherliste führt TableScreen; hier wird ihm nur der Boden gemeldet.
	table_ground = $Room.find_child("TableGround", true, false) as TableGround
	if table_ground != null and table_ground.felt_material != null:
		table_screen.set_ground_material(table_ground.felt_material)
	var screen_mesh := $Room.find_child("Screen", true, false) as MeshInstance3D
	if screen_mesh == null:
		push_warning("Tisch-Screen-Mesh nicht gefunden - Display bleibt aus (siehe TableScreen)")
		return

	# Spiegelung der Würfel auf dem Display-Glas (siehe ScreenReflection).
	screen_reflection = ScreenReflection.new()
	screen_reflection.name = "ScreenReflection"
	screen_reflection.main_camera = camera_rig
	add_child(screen_reflection)
	table_screen.attach_to(screen_mesh, screen_reflection)
	# JEDES Display-Fenster spiegelt - auch Trays samt Würfeln und die Hülle.
	for prop: Node in [pool_tray_view, queue_tray_view, dice_shell]:
		ScreenReflection.mark_reflective(prop)

	# Screen-Elemente an ihre Editor-Anker setzen; den Kombi-Cluster ERST
	# platzieren, DANN den Zoom einrichten (er liest das verschobene cluster_rect).
	table_screen.place_combo_cluster(table_screen.world_to_pixel(combos_anchor.global_position))
	_setup_combo_chips()
	_setup_combos_zoom()
	table_screen.place_goal_bar(table_screen.world_to_pixel(goal_bar_anchor.global_position))
	var ppw := table_screen.pixels_per_world()
	var score_size := Vector2(PIT_SCORE_WIDTH_WORLD * ppw, PIT_SCORE_HEIGHT_WORLD * ppw)
	table_screen.configure_pit_score(
		table_screen.world_to_pixel(base_counter_anchor.global_position),
		table_screen.world_to_pixel(mult_counter_anchor.global_position),
		score_size)
	# Zielbalken + Zähler zu EINEM Wertungs-Bildschirm rahmen, dann Zoom-Zone.
	table_screen.place_score_screen()
	_setup_score_zoom()
	table_screen.place_hub(
		table_screen.world_to_pixel(hub_anchor.global_position),
		Vector2(HUB_WIDTH_WORLD * ppw, HUB_HEIGHT_WORLD * ppw))
	_setup_hub_zoom()
	_refresh_hub_info()
	# Gruben-Fenster: der Rahmen zeichnet EXAKT die Kollisionslinie der
	# Energiewände nach (±PIT_HALF um die Grubenmitte, Eckenrundung der Wände).
	var pit_corner_a := table_screen.world_to_pixel(Vector3(
		DicePit.PIT_CENTER.x + DicePit.PIT_HALF_X, 0.0,
		DicePit.PIT_CENTER.z - DicePit.PIT_HALF_Z))
	var pit_corner_b := table_screen.world_to_pixel(Vector3(
		DicePit.PIT_CENTER.x - DicePit.PIT_HALF_X, 0.0,
		DicePit.PIT_CENTER.z + DicePit.PIT_HALF_Z))
	table_screen.place_pit_window(
		Rect2(pit_corner_a, Vector2.ZERO).expand(pit_corner_b),
		DicePit.CORNER_RADIUS * ppw)
	# Kompaktes Würfelnetz-Feld unter der Würfelreihe (mit Abstand zur Grubenwand).
	var pit_info_cx := DicePit.PIT_CENTER.x - PIT_INFO_BAR_INSET_X
	var pit_info_a := table_screen.world_to_pixel(Vector3(
		pit_info_cx + PIT_INFO_BAR_HALF_X, 0.0, DicePit.PIT_CENTER.z - PIT_INFO_BAR_HALF_Z))
	var pit_info_b := table_screen.world_to_pixel(Vector3(
		pit_info_cx - PIT_INFO_BAR_HALF_X, 0.0, DicePit.PIT_CENTER.z + PIT_INFO_BAR_HALF_Z))
	var pit_info_rect := Rect2(pit_info_a, Vector2.ZERO).expand(pit_info_b)
	table_screen.place_pit_info_bar(pit_info_rect)
	# Aktions-Knöpfe flankieren das Netz-Feld, der Bank-Knopf hängt darunter.
	table_screen.place_pit_actions(pit_info_rect)
	# Einzeilige Material-Erklärleiste im Gruben-Screen, zwischen Netz-Feld und
	# Grubenwand (breit).
	var hint_cx := DicePit.PIT_CENTER.x - PIT_HINT_INSET_X
	var hint_a := table_screen.world_to_pixel(Vector3(
		hint_cx + PIT_HINT_HALF_X, 0.0, DicePit.PIT_CENTER.z - PIT_HINT_HALF_Z))
	var hint_b := table_screen.world_to_pixel(Vector3(
		hint_cx - PIT_HINT_HALF_X, 0.0, DicePit.PIT_CENTER.z + PIT_HINT_HALF_Z))
	table_screen.place_pit_net_hint(Rect2(hint_a, Vector2.ZERO).expand(hint_b))
	# Deal-Marken am oberen Grubenrand - die Spiegelung der Hub-Marken.
	var rail_cx := DicePit.PIT_CENTER.x + PIT_DEAL_RAIL_INSET_X
	var rail_cz := DicePit.PIT_CENTER.z + PIT_DEAL_RAIL_OFFSET_Z
	var rail_a := table_screen.world_to_pixel(Vector3(
		rail_cx + PIT_DEAL_RAIL_HALF_X, 0.0, rail_cz - PIT_DEAL_RAIL_HALF_Z))
	var rail_b := table_screen.world_to_pixel(Vector3(
		rail_cx - PIT_DEAL_RAIL_HALF_X, 0.0, rail_cz + PIT_DEAL_RAIL_HALF_Z))
	table_screen.place_pit_deal_rail(Rect2(rail_a, Vector2.ZERO).expand(rail_b))
	# LED-Leiste ERST jetzt verlegen: sie führt um die Grube herum, braucht also
	# deren endgültiges Rechteck.
	table_screen.link_hub_to_cluster()
	# Charm-Konsolen unter der 3D-Charm-Reihe: je Charm eine Blende dort, wo der
	# 3D-Strahl auf den Screen trifft (= projizierter Platz), Karte darunter. Die
	# übergebenen Pixel sind die Blenden-Mitten; die Karten legt das Dock ab.
	var aperture_centers := PackedVector2Array()
	for i in CharmRowView.SPOT_COUNT:
		aperture_centers.append(table_screen.world_to_pixel(charm_row.spot_global_position(i)))
	var pad_spacing := aperture_centers[0].distance_to(aperture_centers[1]) if aperture_centers.size() > 1 else 200.0
	# Projektor = Kraftfeld-Durchmesser: Beam-Radius (Welt) -> Screen-Pixel.
	var proj_radius := CharmRowView.BEAM_RADIUS * table_screen.pixels_per_world()
	table_screen.place_charm_dock(aperture_centers, Vector2(pad_spacing * 0.66, pad_spacing * 0.66), proj_radius)
	if run != null:
		table_screen.charm_dock.set_charms(run.owned_charms, _charm_sell_values())
	# Wertungs-Leisten: Grube (Datenbus), Kombis und Charm-Dock münden in den Score.
	table_screen.link_score_strips()
	table_screen.take_action_button.pressed.connect(_on_take_button_pressed)
	table_screen.roll_action_button.pressed.connect(_on_throw_button_pressed)
	table_screen.bank_action_button.pressed.connect(_on_bank_button_pressed)
	table_screen.log_action_button.pressed.connect(_on_log_button_pressed)

	# Wett-Tresen LINKS in der Lücke NEBEN der Grube, der Schatz rechts daneben
	# (Tausch, Spieler-Entscheid 2026-08-27); Unterkante bündig mit Grube und
	# Kombinationen-Fenster. Es IST die Knopf-Spalte und meldet seine Maße selbst
	# (SideBetPanel.preferred_units); der Zuschnitt wächst um WETTEN_ROOM, und
	# weil die Fenster-Einheit die eigene Breite ist, wachsen Plots, Löcher und
	# Schrift gemeinsam mit - breitere Gruben UND größerer Text aus einer Zahl.
	var shell_px := table_screen.world_to_pixel(dice_shell.global_position)
	var pit_r := Rect2(table_screen.pit_window.position, table_screen.pit_window.size)
	var win_size := SideBetPanel.preferred_units() \
		* (table_screen.cluster_rect.size.x / 100.0) * WETTEN_ROOM
	# Nie höher als die Grube — der Tresen ist ihr Beiwerk, kein Turm.
	win_size.y = minf(win_size.y, pit_r.size.y)
	var win_pos := Vector2(pit_r.end.x + table_screen.size.x * 0.005,
		pit_r.end.y - win_size.y)
	table_screen.place_side_bet_window(Rect2(win_pos, win_size))
	_setup_side_bets_zoom()
	# Wurf und Auszahlung hängen am Fenster (einmalig verdrahtet - es überlebt
	# Run-Wechsel, nur sein run wird neu gesetzt).
	table_screen.side_bet_window.bet_selected.connect(_on_side_bet_selected)
	table_screen.side_bet_window.bet_placed.connect(_on_side_bet_placed)

	# Schatz-Screen RECHTS des Wett-Tresens; die echten 3D-Chips werden
	# mittig-oben darauf gestellt. Die AUSSENKANTE der Fensterzeile bleibt die
	# alte (Hüllen-Anker + 4,5 % Screen + UNGEWACHSENE Fensterbreite) - dahinter
	# beginnen die Vorrats-Fächer, an die nichts heranrücken darf.
	var side_r := Rect2(table_screen.side_bet_window.position, table_screen.side_bet_window.size)
	var gap_left := side_r.end.x + table_screen.size.x * 0.005
	var gap_right := shell_px.x + table_screen.size.x * 0.045 \
		+ SideBetPanel.preferred_units().x * (table_screen.cluster_rect.size.x / 100.0)
	# Doppelt so breit wie der Wett-Tresen, gleiche Höhe und Oberkante.
	var t_w := side_r.size.x * 2.0
	var t_top := side_r.position.y
	var t_size := Vector2(t_w, side_r.size.y)
	# Waagerecht mittig in seiner Lücke zwischen Wett-Tresen und Fächern.
	var t_cx := clampf((gap_left + gap_right) * 0.5,
		gap_left + t_w * 0.5, gap_right - t_w * 0.5)
	var t_pos := Vector2(t_cx - t_w * 0.5, t_top)
	table_screen.place_treasure_window(Rect2(t_pos, t_size))
	# Chips auf die Truhe stellen: Weltposition aus dem Truhen-Pixel zurückrechnen.
	# Weiter zur Hinterkante (kleineres Y): der Turm hält Abstand zu den Schlitzen
	# an der Vorderkante, hohe Türme ragen optisch nach Bildschirm-oben.
	var chip_px := Vector2(t_cx, t_top + t_size.y * 0.40)
	var chip_world := table_screen.pixel_to_world(chip_px)
	chip_stack.global_position = Vector3(chip_world.x, chip_stack.global_position.y, chip_world.z)
	# Weltpositionen der beiden Münzschlitze als lokale XZ-Versätze des Turms:
	# links wird gezahlt (Chips sinken), rechts kommt herein/Wechselgeld heraus.
	var pay_world := table_screen.pixel_to_world(t_pos + t_size * TreasureChestView.PAY_SLOT_FRAC)
	var rec_world := table_screen.pixel_to_world(t_pos + t_size * TreasureChestView.RECEIVE_SLOT_FRAC)
	chip_stack.pay_slot_offset = Vector2(pay_world.x - chip_world.x, pay_world.z - chip_world.z)
	chip_stack.receive_slot_offset = Vector2(rec_world.x - chip_world.x, rec_world.z - chip_world.z)
	# Klickzone zum Heranzoomen an den Chip-Haufen (Truhen-Fußabdruck).
	camera_rig.configure_chips_target(Vector3(chip_world.x, 1.5, chip_world.z))
	var tr_a := table_screen.pixel_to_world(t_pos)
	var tr_b := table_screen.pixel_to_world(t_pos + t_size)
	chips_click_zone = _add_click_zone("ChipsClickZone",
		Vector3(chip_world.x, 0.0, chip_world.z),
		Vector3(absf(tr_a.x - tr_b.x), 4.0, absf(tr_a.z - tr_b.z)))
	table_screen.link_hub_to_treasure()
	# Die Ladungs-Bank bekommt den freien Chip-Platz unten rechts im Cluster
	# (zwischen Grube und Kombinationen), nicht die Geld-Ecke.
	var free_slots := table_screen.free_cluster_slots()
	if not free_slots.is_empty():
		_setup_capacitor_bank(free_slots[free_slots.size() - 1])

	# Fumble-Automaten: linker Zwilling des Hubs - Spalte des Kombi-Clusters (gleiche
	# Rinne zum Hub), Ober- und Unterkante bündig mit dem Hub. Die Ablage ist zum
	# Pool-Tray gewandert, die linke Spalte also frei. Sichtbar erst ab Freischaltung.
	var hub_r := Rect2(table_screen.hub.position, table_screen.hub.size)
	# Die volle Spalte: der Schwarzmarkt-Anker; das Fenster selbst ist kürzer.
	var slots_column_rect := Rect2(
		Vector2(table_screen.cluster_rect.position.x, hub_r.position.y),
		Vector2(table_screen.cluster_rect.size.x, hub_r.size.y - SLOTS_BOTTOM_INSET_WORLD * ppw))
	var slots_rect := Rect2(slots_column_rect.position,
		Vector2(slots_column_rect.size.x, slots_column_rect.size.y * SLOTS_HEIGHT_SHARE))
	table_screen.place_slot_bank_window(slots_rect)
	slots_click_zone = _screen_zoom_zone("SlotsClickZone", slots_rect, camera_rig.configure_slots_target)
	table_screen.slot_bank_window.cashed_out.connect(_on_slot_cashed_out)
	table_screen.slot_bank_window.spin_paid.connect(_on_slot_spin_paid)
	table_screen.slot_bank_window.prize_dispatched.connect(_on_slot_prize_dispatched)
	# Die Walze wartet, bis die Energie am Automaten ist.
	table_screen.slot_bank_window.coin_travel_time = table_screen.slot_pay_travel_time()

	# Schwarzmarkt: direkt unter den Automaten in der Glas-Tasche, Unterkante
	# bündig mit dem Hub. Oberkante folgt dem KURZEN Automaten-Fenster (slots_rect),
	# nicht der vollen Spalte - so füllt er den Filz, den der TOPF-Rückbau freigab.
	# Eigener Zoom wie jedes Tisch-Fenster - auch vergittert anfassbar, denn der
	# Freischalt-Knopf liegt IM Fenster.
	var secret_rect := _secret_shop_rect(slots_rect, hub_r)
	table_screen.place_secret_shop_window(secret_rect)
	secret_shop_click_zone = _screen_zoom_zone("SecretShopClickZone", secret_rect,
		camera_rig.configure_secret_shop_target)

	# Werkstatt: die STATIONS-ZEILE rechts des Pools, auf Pool-Höhe. Alle Kanten
	# leiten sich aus den echten Pool-Slot-Positionen ab, damit ein späterer
	# Tray-Umzug den Streifen automatisch mitnimmt. Die alte Werkbank-Fläche
	# UNTER dem Pool ist damit frei geworden - dort wird nichts mehr gemalt.
	var pool_bounds := Rect2()
	var first_pool_slot := true
	for i in pool_tray_view.slot_roots.size():
		var seat := pool_tray_view.slot_home_position(i)
		var slot_px := table_screen.world_to_pixel(seat)
		pool_bounds = Rect2(slot_px, Vector2.ZERO) if first_pool_slot else pool_bounds.expand(slot_px)
		first_pool_slot = false
	# Slot-Mitten -> Außenkante, ringsum: je eine halbe Spaltenbreite Saum.
	var slot_half := DiceTrayView.SPACING.y * ppw * 0.5
	pool_bounds = pool_bounds.grow(slot_half)
	_pool_seam_px = slot_half  # dieselbe Naht trennt den Streifen von der Reihe

	# Das AUSGABEFACH steht für sich an der Bildschirm-rechten Pool-Kante; der
	# STATIONS-STREIFEN liegt UNTER dem Pool und hat mit ihm nichts mehr zu tun.
	_place_ausgabefach()
	_pool_row_px = pool_bounds
	var corner := _place_workshop_strip()
	_place_raster_switch()  # auf dem freien Filz über der Pool-Grube
	_setup_deck_glass()
	_setup_screen_spill_lights(corner)


## Die POOL-REIHE in Display-Pixeln - das Höhen- und Ortsbudget des Streifens.
## Gemessen in _setup_panels, gemerkt, damit eine Neuplatzierung nicht neu messen
## muss (der Pool steht fest, die Reihe wächst).
var _pool_row_px := Rect2()
## Die NAHT, um die die Pool-Reihe gewachsen ist (halbe Slot-Teilung) - dieselbe
## trennt den Streifen von der Pool-Unterkante. EIN Maß, kein Streuwert.
var _pool_seam_px := 0.0
## Serienlänge, für die der Streifen zuletzt gestellt wurde (-1 = noch nie). Wächst
## die Reihe, wächst der Streifen - je Bild gefragt, EIN Schreiber.
var _strip_slots := -1

## Der EINE Schreiber des STATIONS-STREIFENS: Fenster, gemeldete Maße, Magazin-
## Grube, Klickzone und die beiden Kamera-Rahmen. Er ist idempotent und wird
## WIEDERHOLT gerufen - die Schacht-Reihe wächst mit der Serienlänge, und mit ihr
## der Streifen (Welle L). Gibt die Ecke zurück, an der das Spill-Licht misst.
func _place_workshop_strip() -> Rect2:
	var pool_bounds := _pool_row_px
	# UNTER dem Pool (2026-09-04): linke Kante bündig mit der Pool-Reihe, Oberkante
	# eine Naht unter ihr. Die HÖHE bleibt das Pool-Budget, also bleiben Einheit und
	# Schürzen-Kette unverändert.
	var workshop_left := pool_bounds.position.x
	var workshop_top := pool_bounds.end.y + _pool_seam_px
	# Der freie Filz unter dem Pool bis an die Anzeigekante - der Streifen ist seit
	# der WELLE X EINE flache Zeile und braucht ihn längst nicht mehr ganz; er ist
	# nur noch die Schranke, an der gewarnt wird.
	var workshop_room := float(TableScreen.RESOLUTION.y) - workshop_top \
		- WORKSHOP_BOTTOM_MARGIN
	_strip_slots = _wanted_strip_slots()
	# Die Einheit ZUERST, und sie folgt der WÜRFELFLÄCHE (WELLE X): der Streifen ist
	# breiter als seine 100 u, also darf das Fenster sie nicht aus seiner Breite
	# ziehen (siehe WorkshopView.unit).
	if table_screen.workshop_window != null:
		table_screen.workshop_window.unit_px = _workshop_unit()
		table_screen.workshop_window.tower_lean = _tower_lean_px()
		table_screen.workshop_window.die_lean = _hover_die_head_px()
	var workshop_rect := _fit_workshop_rect(workshop_left, workshop_top, workshop_room)
	table_screen.place_workshop_window(workshop_rect)
	# Die Werkbank misst Magazin und Kerfe an der GRIFF-Zelle einer STEHENDEN
	# Datenzelle - sie muss sie also kennen, bevor sie auslegt (wie beim Wurf).
	if table_screen.workshop_window != null:
		table_screen.workshop_window.data_cell_px = _data_cell_apparent_px()
		# Und die NETZ-ZELLE ist die FLÄCHE eines echten Würfels (WELLE S).
		table_screen.workshop_window.die_face_px = _die_face_px()
		# Die Hub->Magazin-Ader ist gefallen: Lieferungen fliegen als Meteor-Bogen.
		# Die Grube steht ab jetzt: das Loch im Glas, der ausgeblendete Boden und
		# der Körper darunter hängen alle an DIESEM Streifen. Sie ist L-förmig -
		# Magazin plus Turm-Bucht, EIN Raum aus zwei Löchern.
		_sync_pack_pit(table_screen.workshop_window)
		_sync_tower_pit(table_screen.workshop_window)
	# Klick, Zeiger und Kamera messen sich an Fenster PLUS Schürze - der Pool
	# behält seine eigene Station.
	var bench_rect := table_screen.workshop_window.bench_rect() \
		if table_screen.workshop_window != null else workshop_rect
	# Die Oberkante des STREIFENS: bis dorthin reicht die Info-Säule am Fach.
	_bench_top_px = workshop_rect.position.y
	_free_own_child("WorkshopClickZone")  # eine Neuplatzierung ersetzt sie
	workshop_click_zone = _screen_zoom_zone("WorkshopClickZone", bench_rect,
		camera_rig.configure_workshop_target)

	# Der Zoom rahmt den STREIFEN samt Magazin - sonst nichts: der Streifen liest
	# ganz aus sich selbst, und der Pool bleibt an seiner eigenen Station (der
	# Pool-Tipp wählt weiter von dort).
	# KOPFRAUM für die schwebenden Körper: nach OBEN für beide, und weil ein hoher
	# Körper vom Bildmittelpunkt weg wächst, seitlich dorthin, wo er steht - seit der
	# WELLE Z steht das PODEST RECHTS in der Zeile, der Turm in ihrer Mitte.
	var head_px := _tower_head_px()
	var right_px := _hover_die_head_px()
	var corner := Rect2(bench_rect.position - Vector2(head_px, head_px),
		bench_rect.size + Vector2(head_px + right_px, head_px))
	var corner_a := table_screen.pixel_to_world(corner.position)
	var corner_b := table_screen.pixel_to_world(corner.end)
	camera_rig.configure_workshop_target(table_screen.pixel_to_world(corner.get_center()),
		Vector2(absf(corner_a.z - corner_b.z), absf(corner_a.x - corner_b.x)) * 0.5)

	# Nahsicht (Doppelklick): dieselbe Fläche - Fenster samt Schürze, flach auf dem
	# Tisch. workshop_close_rect bleibt als Prüffläche für den Doppelklick liegen
	# (nur darauf öffnet die zweite Stufe).
	workshop_close_rect = bench_rect
	# ... aber der RAHMEN bekommt oben KOPFRAUM: die Karte steckt nur noch zu einem
	# Viertel, steht also hoch über dem Blech und projiziert über die Streifen-
	# Oberkante hinaus. Ohne diese Zulage schnitte der 0°-Nahblick ihre Köpfe ab.
	# Der KOPFRAUM liegt OBEN: der Turmkopf samt Würfel steht am höchsten, und die
	# stehenden Magazin-Karten projizieren am Nahblick über den Rahmen hinaus.
	# Der Nahblick schaut GERADE nach unten: dort wächst ein hoher Körper radial vom
	# Bildmittelpunkt weg. RECHTS steht seit der WELLE Z der Podest-Würfel, also bekommt
	# diese Seite SEINEN Kopfraum, links der Turm den seinen.
	var head := _tower_head_px() + _lifted_card_head_px()
	var close_frame := Rect2(
		workshop_close_rect.position - Vector2(_tower_head_px(), head),
		workshop_close_rect.size
			+ Vector2(_tower_head_px() + _hover_die_head_px(), head))
	var close_a := table_screen.pixel_to_world(close_frame.position)
	var close_b := table_screen.pixel_to_world(close_frame.end)
	camera_rig.configure_workshop_close_target(
		table_screen.pixel_to_world(close_frame.get_center()),
		Vector2(absf(close_a.z - close_b.z), absf(close_a.x - close_b.x)) * 0.5)
	_place_charging_column(bench_rect, workshop_rect)
	_place_page_lever(bench_rect)
	return corner

## Die LADESÄULE steht RECHTS neben dem Streifen, auf der Zeilenhöhe des PODESTS:
## eine Streifen-Fuge hinter seiner Kante, mittig zur Podest-Zeile. Ihr Fußabdruck
## ist ein WELTMASS (die Elko-Dosen haben ihre eine Größe), also wird hier nur der
## ANKER geschnitten - die Säule mißt sich selbst.
func _place_charging_column(bench_rect: Rect2, workshop_rect: Rect2) -> void:
	if table_screen == null:
		return
	var left := bench_rect.end.x + _workshop_unit() * WorkshopView.STREET_GAP
	if left >= float(TableScreen.RESOLUTION.x) - WORKSHOP_RIGHT_MARGIN:
		return
	if charging_column == null or not is_instance_valid(charging_column):
		charging_column = ChargingColumnView.new()
		add_child(charging_column)
		_connect_charging_column()
	var row := workshop_rect.position.y + workshop_rect.size.y * 0.5
	var at := table_screen.pixel_to_world(Vector2(left, row))
	charging_column.setup(Vector3(at.x, 0.0, at.z))
	_wire_charging_column()
	_place_repair_zone()

## Der HEBEL des PATERNOSTERS steht auf dem Filz RECHTS neben der Magazin-Grube - in
## derselben Straße wie die Ladesäule, nur auf der Höhe des Magazins. Sein Platz ist
## ein reiner ANKER, die Maße bringt der Hebel selbst mit; sein SCHILD meldet er als
## Display-Pixel ans Fenster (dorthin fliegt, was auf einer parkenden Etage landet).
func _place_page_lever(bench_rect: Rect2) -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop):
		return
	var pit := workshop.shelf_pit_rect()
	if pit.size.x <= 0.0:
		return
	var left := bench_rect.end.x + _workshop_unit() * WorkshopView.STREET_GAP
	if left >= float(TableScreen.RESOLUTION.x) - WORKSHOP_RIGHT_MARGIN:
		return
	if page_lever == null or not is_instance_valid(page_lever):
		page_lever = LeverView.new("PageLever")
		add_child(page_lever)
		page_lever.setup(PAGE_UP, PAGE_DOWN)
		page_lever.page_requested.connect(_on_page_requested)
	var at := table_screen.pixel_to_world(Vector2(left, pit.get_center().y))
	page_lever.global_position = Vector3(at.x, 0.0, at.z)
	_write_page_sign()
	workshop.shelf_lever_px = table_screen.world_to_pixel(page_lever.sign_point())

## Die Aufschrift des Schildes: welche Etage gerade oben liegt.
func _write_page_sign() -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if page_lever == null or not is_instance_valid(page_lever) or workshop == null:
		return
	var rows := workshop.shelf_rows_shown()
	page_lever.set_sign("Reihe %d+%d" % [rows[0] + 1, rows[1] + 1])

## Der Kreislauf läuft NUR auf Spielerwunsch, und zyklisch: nach zehn Würfen steht
## wieder dieselbe Reihe hinten. Der Zustand ist ANZEIGE - er wohnt im Fenster,
## nicht im Lauf.
func _on_page_requested(delta: int) -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop) \
			or paternoster == null or not is_instance_valid(paternoster):
		return
	# Die FAHRT zuerst: das Fenster schiebt beim Umschreiben seinen Abgleich an, und
	# der dürfte die eben begonnene Fahrt nicht gleich wieder hart setzen. Der
	# Kreislauf sagt selbst, welche Reihe danach hinten liegt.
	paternoster.step(delta)
	workshop.shelf_head = paternoster.head()
	_write_page_sign()
	_settle_shelf_ride()

## Nach der Fahrt gleicht der Sitz-Schreiber EINMAL ab: währenddessen hält er still
## (die Tabletts tragen ihre Karten), danach steht jede wieder auf ihrem Platz.
func _settle_shelf_ride() -> void:
	var launched := run
	await get_tree().create_timer(PaternosterView.step_time() + 0.05).timeout
	if run != launched or table_screen == null:
		return
	_sync_data_cells()

## Der GRIFF am Hebel je Bild: bedient wird, wo das Magazin zu SEHEN ist (eigene
## Station und Freikamera - die Griff-Grammatik der Körper).
func _sync_page_lever() -> void:
	if page_lever == null or not is_instance_valid(page_lever):
		return
	page_lever.set_armed(_page_lever_live())
	page_lever.set_hovered(_page_lever_part(get_viewport().get_mouse_position()))

func _page_lever_live() -> bool:
	return _table_operable() and not _deck_glass \
		and _felt_pick_live(CameraRig.Mode.WORKSHOP)

## Welche Seite des Hebels liegt unter dem Zeiger ("" = keine)? Auf derselben
## Pick-Ebene steht auch die Ladesäule - darum entscheidet der NAME, nicht der Treffer.
func _page_lever_part(screen_pos: Vector2) -> String:
	if page_lever == null or not is_instance_valid(page_lever):
		return LeverView.PART_NONE
	var hit := _ray_pick(screen_pos, LeverView.PICK_LAYER)
	if hit.is_empty():
		return LeverView.PART_NONE
	var part := LeverView.part_of(hit.collider)
	return part if page_lever.direction_of(part) != 0 else LeverView.PART_NONE

## Der Druck auf den Hebel (true = verbraucht).
func _forward_page_lever_mouse(event: InputEventMouse) -> bool:
	if page_lever == null or not is_instance_valid(page_lever) or not _page_lever_live():
		return false
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	return page_lever.press(_page_lever_part(button.position))

## Das KABEL läuft von der Säule zum Podest-Puck - "die Säule lädt, der Würfel
## wird geladen".
func _wire_charging_column() -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop):
		return
	var podium := _bench_podium_target(workshop)
	if podium == Vector3.ZERO:
		return
	charging_column.set_cable_to(Vector3(podium.x, 0.0, podium.z))

## Klickzone und Kamera-Rahmen der Station - sie messen am Fußabdruck der Säule
## plus ihrem KOPFRAUM (sie ist HOCH, und ein hoher Körper projiziert an der
## geneigten Station nach oben).
func _place_repair_zone() -> void:
	if charging_column == null or not is_instance_valid(charging_column):
		return
	var lo := charging_column.bounds_min()  # (Welt-x, Welt-z)
	var hi := charging_column.bounds_max()
	# Welt +X ist Bildschirm-oben, Welt +Z Bildschirm-rechts.
	var rect_a := table_screen.world_to_pixel(Vector3(hi.x, 0.0, lo.y))
	var rect_b := table_screen.world_to_pixel(Vector3(lo.x, 0.0, hi.y))
	var rect := Rect2(rect_a, rect_b - rect_a)
	var head := ChargingColumnView.column_height() \
		* (WorkshopView.BENCH_TILT_TRIM / CLAMP_HOVER)
	var frame := Rect2(rect.position - Vector2(0.0, head), rect.size + Vector2(0.0, head))
	_free_own_child("RepairClickZone")  # eine Neuplatzierung ersetzt sie
	repair_click_zone = _screen_zoom_zone("RepairClickZone", rect,
		camera_rig.configure_repair_target)
	var corner_a := table_screen.pixel_to_world(frame.position)
	var corner_b := table_screen.pixel_to_world(frame.end)
	camera_rig.configure_repair_target(table_screen.pixel_to_world(frame.get_center()),
		Vector2(absf(corner_a.z - corner_b.z), absf(corner_a.x - corner_b.x)) * 0.5)

## Wie weit der Würfel über dem TURMKOPF nach oben projiziert, in Display-Pixeln:
## seine Welthöhe mal dem GEMESSENEN Aufwärts-Versatz der geneigten Station
## (BENCH_TILT_TRIM je CLAMP_HOVER). Der TURM selbst steht seit der Welle Y IN der
## Grube und ragt nirgends heraus - über die Kante kommt nur noch der Würfel.
func _tower_head_px() -> float:
	var tilt := WorkshopView.BENCH_TILT_TRIM / CLAMP_HOVER
	var head := TowerView.tower_height(_wanted_strip_slots()) + TOWER_DIE_CLEAR \
		+ DieBuilder.HALF_EXTENT * DiceTrayView.DIE_SCALE - _pit_floor_drop()
	return maxf(head, 0.0) * tilt

## Wie weit der Würfel ÜBER dem Turm sich im Bild nach RECHTS über dessen Grundriß
## hinauslehnt: die Kopfraum-Projektion. Seit der WELLE Z hält sie das ZIEL-NETZ auf
## Abstand (davor den GRIFF-Knopf).
func _tower_lean_px() -> float:
	return _tower_head_px() * TOWER_LEAN_SHARE

## Wie weit der schwebende PODEST-Würfel über seinen Platz hinaus projiziert: sein
## Schwebe-Versatz plus die REICHWEITE des gekippten Würfels (`VitrineView.SILHOUETTE`,
## die eine Quelle dafür). Er steht seit der WELLE Z als vorletzte Spalte, also braucht
## der Rahmen dort seinen Kopfraum - und der GRIFF-Knopf dahinter dieselbe Luft (die
## LEHNE der Bühne, gemeldet als die_lean); mit der halben FLÄCHE gerechnet deckte er ihn.
func _hover_die_head_px() -> float:
	var reach := _die_face_px() * DieBuilder.HALF_EXTENT / DieBuilder.FACE_SIZE * VitrineView.SILHOUETTE
	return WorkshopView.BENCH_TILT_TRIM + reach

## Wie weit eine Magazin-Karte über das Glas hinausragt, in Display-Pixeln: seit dem
## PATERNOSTER liegt sie IN der Grube, also ist das allein ihr GRIFF-Hub (der Hover
## ist die eine erlaubte Ausnahme von der Kante). Der Nahblick schaut gerade nach
## unten, also ist das genau der Kopfraum, den sein Rahmen oben braucht - er ist
## damit rund ein Viertel dessen, was die STEHENDE Karte verlangte.
func _lifted_card_head_px() -> float:
	if table_screen == null:
		return 0.0
	var over := DataCellView.lying_over(PackDrawerView.CASSETTE_SCALE) \
		+ PaternosterView.PROUD + PaternosterView.HOVER_PROUD
	var origin := table_screen.world_to_pixel(Vector3.ZERO)
	return absf(table_screen.world_to_pixel(Vector3(over, 0.0, 0.0)).y - origin.y)

## Wie viele Schächte die Reihe tragen soll: was das Fenster sagt, solange es
## steht (es zählt auch die steckenden Karten mit), sonst der Lauf.
func _wanted_strip_slots() -> int:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop != null and is_instance_valid(workshop) and workshop.is_inside_tree():
		return workshop.slot_count()
	return run.series_slots() if run != null else WorkshopView.FALLBACK_SLOTS

## Je Bild gefragt: wächst (oder schrumpft) die Serienlänge, wächst der STREIFEN
## mit ihr - die Karte behält ihre eine Größe. Idempotent, EIN Schreiber.
func _sync_workshop_strip() -> void:
	if table_screen == null or _pool_row_px.size.x <= 0.0:
		return
	if _wanted_strip_slots() == _strip_slots:
		return
	_setup_screen_spill_lights(_place_workshop_strip())

## Das Rechteck des STATIONS-STREIFENS: linke Kante bündig mit der Pool-Reihe,
## Oberkante eine Naht unter ihr. Er ist seit der WELLE X EINE flache Zeile, und
## seine HÖHE ist GEGEBEN statt gelöst: die höchste Spalte plus die beiden Ränder.
## Die BREITE folgt dem TURM - die Karte hat EINE Größe, also wächst der Streifen,
## statt sie zu zerdrücken.
func _fit_workshop_rect(left: float, top: float, room_below: float) -> Rect2:
	var u := _workshop_unit()
	var height := WorkshopView.bench_height_for(u, _workshop_net_px().y,
		_workshop_tower_px().y, _workshop_stage_px())
	var width := WorkshopView.bench_width_for(u, _workshop_net_px().x,
		_workshop_tower_px().x, _workshop_stage_px(), _workshop_lane_px(),
		_tower_lean_px(), _hover_die_head_px())
	# Der Tisch ist endlich: passt die gelöste Breite nicht mehr auf die Anzeige,
	# wird gekappt - die Karten stehen dann enger, sie schrumpfen aber nicht.
	var room := float(TableScreen.RESOLUTION.x) - left - WORKSHOP_RIGHT_MARGIN
	if width > room:
		push_warning("Werkstatt-Streifen gekappt: %.0f statt %.0f px breit" % [room, width])
		width = maxf(room, 1.0)
	var span := height + u * WorkshopView.apron_span_units() + _workshop_shelf_px(u)
	if span > room_below:
		push_warning("Werkstatt-Streifen zu hoch: %.0f von %.0f px freiem Filz"
			% [span, room_below])
	return Rect2(Vector2(left, top), Vector2(width, height))

## Die Maßeinheit u des Streifens: sie folgt der WÜRFELFLÄCHE (WELLE X) - im
## Streifen ist fast alles ein Weltmaß, also mißt auch die u-Kette daran.
func _workshop_unit() -> float:
	return WorkshopView.unit_for(_die_face_px())

## Der Fußabdruck des TURMS in Display-Pixeln: die liegende Karte plus Luft, und
## darin steckt die Kontaktleiste - dieselbe Rechnung wie tower_span_px im Fenster.
func _workshop_tower_px() -> Vector2:
	var lie := _data_cell_lying_px() * PackDrawerView.CASSETTE_SCALE \
		* WorkshopView.TOWER_ROOM
	return Vector2(lie.x / maxf(1.0 - TowerView.BAR_SHARE, 0.1), lie.y)

## Und die Spanne der PODEST-Bühne: die Würfelfläche mal ihrem Faktor.
func _workshop_stage_px() -> float:
	return _die_face_px() * WorkshopView.STAGE_FACES

## Die AUSWURF-BAHN links des Turms - dieselbe Rechnung wie eject_lane_px.
func _workshop_lane_px() -> float:
	return _data_cell_lying_px().x * PackDrawerView.CASSETTE_SCALE \
		* TowerView.eject_share(_wanted_strip_slots())

## Die MINDESTTIEFE des Magazins in Display-Pixeln: ZWEI LANES der liegenden Karte,
## dazwischen der SPALT, darunter die FUSSLUFT, plus die gemalte Fassung - dieselbe
## Rechnung wie shelf_min_height im Fenster (ein Test hält beide gleich).
func _workshop_shelf_px(u: float) -> float:
	return _data_cell_apparent_px().y * PackDrawerView.CASSETTE_SCALE \
		* PackDrawerView.RANK_SPAN * float(PackDrawerView.LANES) \
		+ PackDrawerView.ROW_GAP_PX + PackDrawerView.FOOT_GAP_PX \
		+ PackDrawerView.rim_inset(u) * 2.0

## Die Maße EINES Würfelnetzes in Display-Pixeln, in der Zelle der echten
## Würfelfläche - Spaltenbreite und Bandhöhe des Streifens folgen ihnen.
func _workshop_net_px() -> Vector2:
	return DieNetView.net_size(_die_face_px())

## Die FLÄCHE eines Würfels in Display-Pixeln, im Spielmaß und in derselben
## Projektion wie die Kartenmaße: das Zellmaß der Werkstatt-Netze (WELLE S).
func _die_face_px() -> float:
	if table_screen == null:
		return 0.0
	var origin := table_screen.world_to_pixel(Vector3.ZERO)
	return absf(table_screen.world_to_pixel(Vector3(0.0, 0.0,
		DieBuilder.FACE_SIZE * DiceTrayView.DIE_SCALE)).x - origin.x)

## Je großem Fenster ein Spill-Licht in dessen Farbwelt; die Werkbank-Ecke
## bekommt EIN gemeinsames Licht (ihre Fenster teilen sich den Zoom sowieso).
func _setup_screen_spill_lights(workshop_corner: Rect2) -> void:
	var cyan: Color = TableScreen.FRAME_COLOR
	var gold: Color = TreasureChestView.GOLD
	_add_spill_light("PitSpill",
		Rect2(table_screen.pit_window.position, table_screen.pit_window.size), cyan)
	# Kombi-Cluster heller: dort stehen echte 3D-Chips, die ohne Licht schwarz
	# blieben (die anderen Fenster beleuchten nur flaches Glas).
	_add_spill_light("ClusterSpill", table_screen.cluster_rect, Color("#ffd9f0"), CLUSTER_SPILL_FACTOR)
	_add_spill_light("ScoreSpill", table_screen.score_rect, cyan)
	_add_spill_light("HubSpill",
		Rect2(table_screen.hub.position, table_screen.hub.size), cyan)
	_add_spill_light("SideBetSpill", Rect2(table_screen.side_bet_window.position,
		table_screen.side_bet_window.size), gold)
	_add_spill_light("TreasureSpill", Rect2(table_screen.treasure_window.position,
		table_screen.treasure_window.size), gold)
	_add_spill_light("WorkshopSpill", workshop_corner, gold)

## Ein Fenster-Spill-Licht: mittig über dem Pixel-Rechteck, Höhe/Reichweite aus
## dessen Weltmaß - große Fenster strahlen weiter, schmale bleiben eng.
func _add_spill_light(light_name: String, rect_px: Rect2, tint: Color, energy_factor := 1.0) -> void:
	var a := table_screen.pixel_to_world(rect_px.position)
	var b := table_screen.pixel_to_world(rect_px.end)
	var half := Vector2(absf(a.x - b.x), absf(a.z - b.z)) * 0.5
	var height := clampf(minf(half.x, half.y) * SPILL_HEIGHT_FACTOR,
		SPILL_HEIGHT_MIN, SPILL_HEIGHT_MAX)
	_free_own_child(light_name)  # EIN Licht je Name: eine Neuplatzierung ersetzt es
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = Vector3((a.x + b.x) * 0.5, height, (a.z + b.z) * 0.5)
	light.light_color = tint
	light.light_energy = SPILL_ENERGY * energy_factor
	light.omni_range = maxf(half.x, half.y) * SPILL_RANGE_FACTOR + height
	light.omni_attenuation = SPILL_ATTENUATION
	light.shadow_enabled = false
	add_child(light)

## Ein eigenes Kind gleichen Namens abräumen - für die Bauteile, die eine
## Neuplatzierung des Streifens ERSETZT (Klickzone, Spill-Licht).
func _free_own_child(child_name: String) -> void:
	var known := get_node_or_null(NodePath(child_name))
	if known != null:
		remove_child(known)
		known.queue_free()

## Kamera-Zoomziele aus den echten Positionen ableiten, damit Editor-
## Verschiebungen den Zoom automatisch mitnehmen.
func _setup_camera_targets() -> void:
	# Das Nachschub-Tray lebt fest VOR der Grube (materialisiert erst beim
	# ersten Grubenzoom einer Runde, siehe _activate_queue).
	queue_tray_view.position = QUEUE_TRAY_PIT_POSITION

	_pool_tray_home = pool_tray_view.global_position
	# Die POOL-Station rahmt Vorrat UND Pit - sie stehen auf demselben Platz.
	camera_rig.configure_tray_targets(_pool_tray_home)
	# Grubenziel auf Tisch-Screen-Höhe (0), etwas Richtung Charms (+X = oben)
	# verschoben, damit die Charm-Konsolen mit im Blick sind.
	camera_rig.configure_pit_target(Vector3(DicePit.PIT_CENTER.x + PIT_ZOOM_UP, 0.0, DicePit.PIT_CENTER.z))
	_setup_charms_zoom()
	_setup_glide_bounds()

## Grenze des Gleitflugs: an der echten Anzeigefläche GEMESSEN (sie IST das
## Rechteck ihrer Textur), nie getippt - daneben liegt nur noch dunkler Raum.
func _setup_glide_bounds() -> void:
	if table_screen == null:
		return
	var near := table_screen.pixel_to_world(Vector2.ZERO)
	var far := table_screen.pixel_to_world(Vector2(table_screen.size))
	camera_rig.configure_glide_bounds(Rect2(
		Vector2(minf(near.x, far.x), minf(near.z, far.z)),
		Vector2(absf(far.x - near.x), absf(far.z - near.z))))

## Shop, Gravur-Station und Bogen-Enthüllung anlegen und verdrahten.
func _setup_panels() -> void:
	# Shop als Hub-Seite; ohne Screen-Mesh ersatzweise als Fenster-UI.
	charm_shop = SHOP_SCENE.instantiate()
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.attach_panel(charm_shop)
	else:
		$UI.add_child(charm_shop)
	charm_shop.closed.connect(_on_shop_closed)
	# Die Bucht: der Laden MELDET seine Auslage, die Körper stellt scene_root.
	charm_shop.vitrine_changed.connect(_on_vitrine_changed)
	# Der Vorhang hängt an der SEITENREGEL des Hubs, nicht nur am Laden-Ablauf:
	# verdrängt eine andere Seite (Lexikon, Titel) die Ladenseite, muss das Loch zu
	# sein - sonst stünde es offen unter fremdem Inhalt. GEFRAGT je Bild, nie
	# gemeldet: ShopController.close() versteckt die Seite, BEVOR es sein
	# closed-Signal wirft, und ein Melder an visibility_changed hätte den Vorhang
	# dort hart fallen lassen, ehe der Phasenwechsel die Schluck-Zeremonie erlaubt.
	# Die Stellplätze der Kassetten-Reihe sind auf den ECHTEN liegenden Grundriß
	# geschnitten - der Laden muss ihn kennen, bevor er auslegt.
	charm_shop.data_cell_lie_px = _data_cell_lying_px()

	# Vertragswahl liegt IN DER GRUBE, nicht am Hub: sie erscheint beim ersten
	# Grubenzoom der Runde, direkt über dem Boden, auf dem gleich die Würfel
	# landen. Ohne Screen-Mesh ersatzweise als Fenster-UI.
	route_choice = RouteChoiceView.new()
	if table_screen != null:
		table_screen.add_child(route_choice)
		_place_route_choice()
	else:
		$UI.add_child(route_choice)
	route_choice.route_chosen.connect(_on_route_chosen)

	# Der Rückblick teilt sich den Grubenboden mit der Vertragswahl - beide sind
	# Gruben-Mobiliar und reisen mit der Kamera ab.
	log_view = LogView.new()
	if table_screen != null:
		table_screen.add_child(log_view)
		_place_log_view()
	else:
		$UI.add_child(log_view)
	log_view.entry_selected.connect(_on_log_entry_selected)
	log_view.step_requested.connect(_log_step)
	log_view.close_requested.connect(_close_round_log)

	# Titel-HUD: eigene Hub-Seite, damit Menü, Einstellungen und Credits auf
	# demselben Fenster liegen wie der Shop. Ohne Hub gibt es keinen Titel -
	# dann startet das Spiel wie bisher direkt.
	if table_screen != null and table_screen.hub != null:
		title_view = TitleView.new()
		title_view.visible = false
		table_screen.hub.attach_panel(title_view)
		title_view.layout()
		title_view.set_settings(GameSettings.load_saved())
		title_view.settings.apply()
		title_view.settings_changed.connect(_on_settings_changed)
		title_view.new_game_requested.connect(_on_title_new_game)
		title_view.resume_requested.connect(_on_title_resume)
		title_view.quit_requested.connect(func() -> void: get_tree().quit())
		camera_rig.configure_title_target(
			Vector3(hub_anchor.global_position.x, 0.0, hub_anchor.global_position.z),
			Vector2(HUB_WIDTH_WORLD * 0.5, HUB_HEIGHT_WORLD * 0.5))

	# Lexikon: das Nachschlagewerk als Hub-Seite. Ohne Hub gibt es keins (wie
	# beim Titel) - alles, was das Spiel sagt, sagt es auf einem Display.
	if table_screen != null and table_screen.hub != null:
		lexikon_view = LexikonView.new()
		lexikon_view.visible = false
		table_screen.hub.attach_panel(lexikon_view)
		lexikon_view.layout()
		lexikon_view.close_requested.connect(_close_lexikon)

	# Auszahlungs-Seite: der Hub wird am Rundenende zur Cash-Out-Seite. Sie MELDET
	# nichts zurück außer dem Kassieren - gezählt wird, was die Zeremonie bucht.
	if table_screen != null and table_screen.hub != null:
		payout_ledger = PayoutLedgerView.new()
		payout_ledger.visible = false
		table_screen.hub.attach_panel(payout_ledger)
		payout_ledger.layout()

## Einstellungs-Menü, Charm-Bibliothek und Testmodus-Knopf verdrahten. Das
## Menü lebt auf dem Display (HubView); die 2D-Knöpfe bleiben als Rückfall
## ohne Tisch-Display.
func _setup_settings_ui() -> void:
	debug_win_round_button.pressed.connect(_on_debug_win_round_pressed)
	camera_rig.mode_changed.connect(_on_camera_mode_changed)
	settings_toggle_button.pressed.connect(_on_settings_toggle_pressed)
	var have_hub := table_screen != null and table_screen.hub != null
	if have_hub:
		settings_toggle_button.visible = false
		settings_menu.visible = false
		table_screen.hub.menu_requested.connect(_toggle_title)
		table_screen.hub.new_game_requested.connect(_on_reset_button_pressed)
		table_screen.hub.debug_win_round_requested.connect(_on_debug_win_round_pressed)
		table_screen.hub.debug_money_requested.connect(_on_debug_money_pressed)
		table_screen.hub.debug_energy_requested.connect(_on_debug_energy_pressed)
		table_screen.hub.test_materials_requested.connect(_on_test_materials_pressed)
		table_screen.hub.test_pointers_requested.connect(_on_test_pointers_pressed)
		table_screen.hub.test_engravings_requested.connect(_on_test_engravings_pressed)
		table_screen.hub.test_charges_requested.connect(_on_test_charges_pressed)
		table_screen.hub.hub_upgrade_requested.connect(_on_hub_upgrade_pressed)
		table_screen.hub.shop_reopen_requested.connect(_on_shop_reopen_requested)
		table_screen.hub.lexikon_requested.connect(func() -> void: open_lexikon())

	charm_library = CharmLibraryView.new()
	$UI.add_child(charm_library)
	library_button.pressed.connect(charm_library.toggle)
	if have_hub:
		table_screen.hub.library_requested.connect(charm_library.toggle)

	test_materials_button = Button.new()
	test_materials_button.custom_minimum_size = Vector2(0, 48)
	test_materials_button.pressed.connect(_on_test_materials_pressed)
	settings_menu.add_child(test_materials_button)
	CasinoStyle.style_button(test_materials_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, 14)
	_refresh_test_materials_button()

	test_pointers_button = Button.new()
	test_pointers_button.custom_minimum_size = Vector2(0, 48)
	test_pointers_button.pressed.connect(_on_test_pointers_pressed)
	settings_menu.add_child(test_pointers_button)
	CasinoStyle.style_button(test_pointers_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, 14)
	_refresh_test_pointers_button()

	test_engravings_button = Button.new()
	test_engravings_button.text = HubView.TEST_PACKS_LABEL
	test_engravings_button.custom_minimum_size = Vector2(0, 48)
	test_engravings_button.pressed.connect(_on_test_engravings_pressed)
	settings_menu.add_child(test_engravings_button)
	CasinoStyle.style_button(test_engravings_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, 14)

	var test_charges_button := Button.new()
	test_charges_button.text = "🧪 Ladung würfeln"
	test_charges_button.custom_minimum_size = Vector2(0, 48)
	test_charges_button.pressed.connect(_on_test_charges_pressed)
	settings_menu.add_child(test_charges_button)
	CasinoStyle.style_button(test_charges_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, 14)

## Test-Knopf: die Ladung aller Vorrats-Würfel zufällig neu setzen.
func _on_test_charges_pressed() -> void:
	if run == null:
		return
	run.randomize_charges()

## Casino-Look der verbliebenen 2D-Spiel-UI; der Shop stylt sich selbst.
func _style_ui() -> void:
	CasinoStyle.style_score_label(hand_label, 30)

	CasinoStyle.style_button(settings_toggle_button, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, 16)
	CasinoStyle.style_button(library_button, CasinoStyle.GREEN, CasinoStyle.GREEN_DARK, 16)
	CasinoStyle.style_button(reset_button, CasinoStyle.RED, CasinoStyle.RED_DARK, 16)
	CasinoStyle.style_button(debug_win_round_button, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, 14)
	CasinoStyle.style_button(game_over_reset_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK)

	CasinoStyle.style_panel(game_over_panel)

	CasinoStyle.style_score_label(game_over_label, 24)

func _on_settings_toggle_pressed() -> void:
	settings_menu.visible = not settings_menu.visible

## Öffnet das Titel-HUD: die Kamera fährt senkrecht ins Hub-Fenster, das damit
## das ganze Bild füllt. resumable = ein Lauf wartet dahinter ("Weiterspielen").
func _open_title(resumable: bool, instant := false) -> void:
	if title_view == null:
		return
	title_prev_mode = camera_rig.mode
	title_view.set_resumable(resumable)
	title_view.show_home()
	table_screen.hub.fade_page_in(title_view)  # Seitenregel blendet Home aus
	camera_rig.show_title(instant)

## Schließt das Titel-HUD und kehrt dorthin zurück, wo die Kamera vorher stand.
func _close_title() -> void:
	if title_view == null:
		return
	table_screen.hub.fade_page_out(title_view)
	if title_prev_mode == CameraRig.Mode.OVERVIEW:
		camera_rig.zoom_out(CameraRig.TITLE_TRAVEL, Tween.EASE_OUT)
	else:
		camera_rig.zoom_to(title_prev_mode, CameraRig.TITLE_TRAVEL, Tween.EASE_OUT)

## Escape und der Menü-Eintrag im Hub schalten das Titel-HUD um: erst eine
## offene Unterkarte zurück, dann das HUD selbst. Am Startbildschirm bleibt es
## stehen - dort gibt es nichts, wohin man zurückkönnte.
func _toggle_title() -> void:
	if title_view == null:
		return
	if camera_rig.mode == CameraRig.Mode.TITLE:
		if not title_view.go_back() and title_view.is_resumable():
			_close_title()
		return
	if not _can_open_title():
		return
	_open_title(true)

## Nur in Ruhephasen: während Wurf oder Zählen wird die Kamera gebraucht, und
## das Menü risse sie mitten aus der Bewegung.
func _can_open_title() -> bool:
	if camera_rig.is_animating or _dice_in_motion():
		return false
	return phase == Phase.IDLE or phase == Phase.SHOP or phase == Phase.GAME_OVER

## "Neues Spiel": erst blendet das Menü aus, DANN wird der Lauf aufgebaut -
## hinter der geschlossenen Blende und bei stehender Kamera. Umgekehrt schnitt
## das Menü hart weg und der Rückzieher startete auf dem Aufbau-Ruck.
func _on_title_new_game() -> void:
	if title_view == null:
		return
	if title_view.visible:
		table_screen.hub.fade_page_out(title_view, _begin_fresh_run)
	else:
		_begin_fresh_run()

func _begin_fresh_run() -> void:
	_reset_game()
	# Der Aufbau (30 Würfel neu bauen) kostet ein Fünftel einer Sekunde. Er läuft
	# im dunklen Moment ab; Einblende und Rückzieher starten erst danach, sonst
	# fräße der Ruck ihre ersten Bilder.
	await get_tree().process_frame
	await get_tree().process_frame
	table_screen.hub.fade_current_in()
	camera_rig.reveal_table()

func _on_title_resume() -> void:
	_close_title()

## Regler im Titel bewegt: sofort anwenden und auf Platte schreiben.
func _on_settings_changed() -> void:
	title_view.settings.apply()
	title_view.settings.save()

## 3D-Chips auf dem Glas: über jeder Kombinations-Zelle steht ein echtes
## Chip-Modell; die Zelle wird zum Sockel (socket_mode) und der Chip trägt
## Name/Punkte/×Mult selbst. Die Zellwerte bleiben die einzige Quelle -
## nach jedem set_score/set_level zieht _sync_combo_chip nach.
func _setup_combo_chips() -> void:
	var chips_root := Node3D.new()
	chips_root.name = "ComboChips"
	add_child(chips_root)
	for key: String in table_screen.combo_cells:
		var cell: ComboCellView = table_screen.combo_cells[key]
		cell.socket_mode = true
		var corner_a := table_screen.pixel_to_world(cell.position)
		var corner_b := table_screen.pixel_to_world(cell.position + cell.size)
		var chip := ComboChipView.new()
		chip.name = "Chip_%s" % key
		chips_root.add_child(chip)
		chip.position = (corner_a + corner_b) / 2.0
		# Modell-X entlang der Zellbreite (Welt+Z), Display-Band zum Spieler (-X).
		chip.rotation.y = -PI / 2.0
		chip.setup(absf(corner_b.z - corner_a.z), absf(corner_b.x - corner_a.x))
		chip.sync_cell(cell)
		combo_chips[key] = chip
		combo_pick_keys[chip.upgrade_pick_body()] = key
	ScreenReflection.mark_reflective(chips_root)

## Rampenlicht auf genau eine Kombination ("" = auf keine): ihr Chip atmet
## golden, alle anderen ruhen.
func _set_spotlight_combo(key: String) -> void:
	for combo_key: String in combo_chips:
		combo_chips[combo_key].set_spotlight(combo_key == key)

## Stresstest-Drossel auf den genannten Chips (leer = keine).
func _set_throttled_combos(keys: Array[String]) -> void:
	for combo_key: String in combo_chips:
		combo_chips[combo_key].set_throttled(keys.has(combo_key))

## Zieht den 3D-Chip einer Kombination auf den Stand seiner Zelle nach.
func _sync_combo_chip(key: String) -> void:
	if combo_chips.has(key) and combo_labels.has(key):
		combo_chips[key].sync_cell(combo_labels[key])

## Schreibt Stufe UND die daraus folgenden Werte einer Kombination in die Zelle
## und spiegelt sie auf den Chip. DIE Stelle, an der eine gestiegene Stufe
## sichtbar wird - set_level allein rechnet Basispunkte und Mult nicht neu, die
## kommen aus DiceScoring über die Stufentabelle des Laufs. Jede Stufen-Quelle
## (Kauf, Wettgewinn, Rampenlicht per Charm ODER Klausel) endet hier.
func _refresh_combo_display(key: String) -> void:
	if not combo_labels.has(key):
		return
	var row: ComboCellView = combo_labels[key]
	row.set_score(
		DiceScoring.points_for(key, run.combo_levels),
		DiceScoring.mult_for(key, run.combo_levels))
	row.set_level(run.combo_level(key))
	_sync_combo_chip(key)

## --- Übertakten am Chip ------------------------------------------------------

## Übertaktet wird am Kombinations-Zoom und in der Freikamera (_felt_pick_live);
## dort trägt jeder Chip sein Angebot (Preis, Deckung, Werte danach) - sichtbar
## erst beim Zeigerkontakt. Aus der ruhenden Übersicht bleibt der Klick auf den
## Cluster der FLUG dorthin, sonst kaufte eine Navigationsgeste eine Stufe.
## Idempotent: Moduswechsel, Ladungsänderung und jede gekaufte Stufe rufen dasselbe.
func _sync_combo_upgrade_buttons() -> void:
	var show := _felt_pick_live(CameraRig.Mode.COMBOS)
	_combo_picks_live = show
	for key: String in combo_chips:
		var chip: ComboChipView = combo_chips[key]
		chip.set_upgrade_visible(show)
		if show and run != null:
			var next_levels: Dictionary = run.combo_levels.duplicate()
			next_levels[key] = run.combo_level(key) + 1
			chip.set_upgrade_offer(run.overclock_cost(key), run.can_overclock(key),
				DiceScoring.points_for(key, next_levels), DiceScoring.mult_for(key, next_levels),
				run.free_overclocks > 0)
	if not show:
		_clear_combo_upgrade_hover()

## Kauft die Stufe der angeklickten Kombination. Reicht die Energie nicht,
## verpufft der Klick - er darf aber NICHT als Zoom-Klick weiterlaufen, sonst
## fährt die Kamera weg, weil man sich einen Chip nicht leisten kann.
func _try_combo_upgrade_click(screen_pos: Vector2) -> bool:
	if run == null or not _felt_pick_live(CameraRig.Mode.COMBOS):
		return false
	var hit := _ray_pick(screen_pos, ComboChipView.UPGRADE_PICK_LAYER)
	if hit.is_empty() or not combo_pick_keys.has(hit.get("collider")):
		return false
	var key: String = combo_pick_keys[hit["collider"]]
	run.overclock_combo(key)  # false = zu wenig Energie
	_sync_combo_upgrade_buttons()  # neuer Preis, neue Vorschau - der Zeiger steht ja noch drauf
	return true

## Zeigerkontakt am Chip (je Frame): der Zeiger liegt auf dem TISCH, nicht im
## SubViewport - mouse_entered feuert dort nie. Wie bei den Grubenmarken.
func _update_combo_upgrade_hover() -> void:
	var live := _felt_pick_live(CameraRig.Mode.COMBOS)
	# Der Einstieg in die Freikamera meldet keinen Moduswechsel - die Schilder
	# werden hier scharfgestellt bzw. wieder abgeräumt.
	if live != _combo_picks_live:
		_sync_combo_upgrade_buttons()
	if run == null or not live:
		_clear_combo_upgrade_hover()
		return
	var hit := _ray_pick(get_viewport().get_mouse_position(), ComboChipView.UPGRADE_PICK_LAYER)
	var key: String = combo_pick_keys.get(hit.get("collider"), "") if not hit.is_empty() else ""
	if key == _hovered_combo_key:
		return
	_clear_combo_upgrade_hover()
	if key != "":
		_hovered_combo_key = key
		combo_chips[key].set_upgrade_hover(true)

func _clear_combo_upgrade_hover() -> void:
	if _hovered_combo_key == "":
		return
	if combo_chips.has(_hovered_combo_key):
		combo_chips[_hovered_combo_key].set_upgrade_hover(false)
	_hovered_combo_key = ""

## Blendet das Glühen des 3D-Chips weich auf target (0 = Ruhe, 1 = aktiv).
func _glow_combo_chip(key: String, target: float) -> void:
	if not combo_chips.has(key):
		return
	var chip: ComboChipView = combo_chips[key]
	var tween := create_tween()
	tween.tween_method(chip.set_glow, chip.glow, target, 0.35)

## Sammelt die Kombinationszellen des Displays ein und versetzt sie in die
## leuchtende Ruhefarbe.
func _collect_combo_labels() -> void:
	combo_labels = table_screen.combo_cells
	for key: String in combo_labels:
		combo_labels[key].modulate = PAYOUT_LABEL_BASE_COLOR

## Kombinationen, deren Kauf-Licht gerade unterwegs ist: ihre Zellen zeigen
## bis zur Ankunft die ALTEN Werte (siehe _on_combo_upgraded).
var _pulsing_combos: Dictionary = {}

## Kombination übertaktet: gebucht ist beim Eintreffen des Signals längst, also
## zeigt die Zelle SOFORT die neuen Werte - der Spieler steht vor dem Chip. Das
## ⚡-Licht fährt danach aus der Bank über die Chip-Adern nach (nicht abgewartet,
## darum überlagern sich schnelle Klicks gefahrlos). Der Hitzestau senkt eine
## Stufe über dasselbe Signal: der wird nicht gefeiert.
func _on_combo_upgraded(combo_key: String, new_level: int) -> void:
	if table_screen == null or not combo_labels.has(combo_key):
		_refresh_combo_label_texts()
		return
	var row: ComboCellView = combo_labels[combo_key]
	var climbed := new_level > row.level
	_refresh_combo_display(combo_key)
	_sync_combo_upgrade_buttons()  # die nächste Stufe kostet mehr
	if not climbed:
		return
	if capacitor_bank != null:
		capacitor_bank.pulse()  # die Bank gibt ab
	await table_screen.play_energy_overclock_pulse(combo_key)
	if combo_chips.has(combo_key):
		combo_chips[combo_key].play_upgrade_flash()
	if combo_key != highlighted_combo_key:
		var flash := create_tween()
		flash.tween_method(func(c: Color) -> void: row.modulate = c, PAYOUT_LABEL_GLOW_COLOR, PAYOUT_LABEL_BASE_COLOR, 1.2)

## Rampenlicht-Schritt der Zähl-Animation: erst jetzt wird die Stufe gebucht -
## bricht ein Reset die Animation ab, bleibt die Kombination unverändert.
## false = Abbruch (Reset).
func _play_spotlight_step(step: Dictionary, combo_key: String) -> bool:
	if not run.claim_spotlight(combo_key):
		return true  # in dieser Runde schon kassiert
	var charm_index: int = step["charm_indices"][0]
	await _play_spotlight_upgrade(charm_index, combo_key)
	return phase == Phase.SCORING

## Dasselbe für ein Rampenlicht aus einer Klausel: kein Charm, also kein Pad zum
## Aufblitzen (charm_index -1), sonst identisch. false = Abbruch (Reset).
func _play_clause_spotlight(combo_key: String) -> bool:
	if not run.claim_spotlight(combo_key):
		return true
	await _play_spotlight_upgrade(-1, combo_key)
	return phase == Phase.SCORING

## Rampenlicht eingelöst: der Chip der hervorgehobenen Kombination bekommt
## dieselbe Übertaktungs-Zeremonie wie ein Kauf (Licht über die Leiterbahn),
## danach erlischt das Rampenlicht - je Runde steigt nur eine Stufe.
func _play_spotlight_upgrade(charm_index: int, combo_key: String) -> void:
	_flash_charm_and_pad(charm_index)
	if table_screen == null or not combo_labels.has(combo_key):
		_refresh_combo_label_texts()
		return
	_pulsing_combos[combo_key] = true
	_set_spotlight_combo("")
	await table_screen.play_overclock_pulse(combo_key)
	_pulsing_combos.erase(combo_key)
	_refresh_combo_display(combo_key)
	if combo_chips.has(combo_key):
		combo_chips[combo_key].play_upgrade_flash()

## Schreibt Basispunkte + Multiplikatoren inkl. Übertaktungs-Stufen neu;
## Zellen mit laufendem Kauf-Licht bleiben bis zur Ankunft unangetastet.
func _refresh_combo_label_texts() -> void:
	for key: String in combo_labels:
		if _pulsing_combos.has(key):
			continue
		_refresh_combo_display(key)

## Hebt genau die Kombination der gewürfelten Hand golden hervor ("" = keine).
func _refresh_combos(active_key: String) -> void:
	if active_key == highlighted_combo_key:
		return
	var previous := highlighted_combo_key
	highlighted_combo_key = active_key
	if previous != "" and combo_labels.has(previous):
		_tween_combo_label(combo_labels[previous], PAYOUT_LABEL_BASE_COLOR, 1.0)
		_glow_combo_chip(previous, 0.0)
	if active_key != "" and combo_labels.has(active_key):
		_tween_combo_label(combo_labels[active_key], PAYOUT_LABEL_GLOW_COLOR, 1.18)
		_glow_combo_chip(active_key, 1.0)

## Blendet eine Kombinationszelle weich in Farbe/Größe (um die Zellenmitte).
func _tween_combo_label(row: ComboCellView, color: Color, target_scale: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(row, "modulate", color, PAYOUT_FLASH_DURATION)
	tween.tween_property(row, "scale", row.base_scale * target_scale, PAYOUT_FLASH_DURATION)

func _on_charms_changed() -> void:
	charm_row.set_charms(run.owned_charms)
	if table_screen != null and table_screen.charm_dock != null:
		table_screen.charm_dock.set_charms(run.owned_charms, _charm_sell_values())
	_update_charm_badges()

## Zeigt die laufenden Werte der Zähler-Charms als Chip UNTER ihrer Dock-Karte
## (Position folgt Umsortieren/Kauf/Verkauf über die Besitz-Slots).
func _update_charm_badges() -> void:
	if table_screen == null or table_screen.charm_dock == null:
		return
	var texts := {}
	var ids := run.charm_ids()
	var pendulum := CharmEffects.pendulum_mult(_score_ctx())
	for j in ids.size():
		var slot := _charm_slot(j)
		if slot < 0:
			continue
		match ids[j]:
			Charm.ALL_OR_NOTHING:
				if full_reroll_stacks > 0:
					texts[slot] = "+%d" % (full_reroll_stacks * CharmEffects.ALL_OR_NOTHING_MULT)
			Charm.MOMENTUM:
				if momentum_streak > 0:
					texts[slot] = "+%d" % (momentum_streak * CharmEffects.MOMENTUM_MULT)
			Charm.PENDULUM:
				if pendulum > 0:
					texts[slot] = "+%d" % pendulum
			Charm.RAG_COLLECTOR:
				if run.lumpensammler_value > 0:
					texts[slot] = "%d" % run.lumpensammler_value
			Charm.OLD_PENNY:
				# Nicht der rohe Zähler, sondern was er JETZT auszahlen würde -
				# die Zahl, die der Spieler beim Rundenende sehen wird.
				texts[slot] = "$%d" % CharmEffects.old_penny_payout(run.old_penny_payouts)
			Charm.BROKEN_MIRROR:
				if run.farkle_count > 0:
					texts[slot] = "+%d" % run.farkle_count
			Charm.BOTTLE_RACK:
				var souls := _discard_souls()
				if souls > 0:
					texts[slot] = "+%d" % (souls * CharmEffects.BOTTLE_RACK_MULT)
	table_screen.charm_dock.set_badges(texts)
	_show_pendulum_swing(ids, pendulum)

## Pendel: jede Bewegung des Mults schwingt sichtbar - der Charm blitzt und die
## Differenz steigt als "+N"/"-N" an seinem Pad auf (Gold beim Gewinn, Rot beim
## Verlust). _pendulum_shown ist der zuletzt angezeigte Stand.
func _show_pendulum_swing(ids: Array[String], value: int) -> void:
	var resolved := ids.find(Charm.PENDULUM)
	if resolved < 0:
		_pendulum_shown = 0  # ohne Pendel gibt es nichts zu vergleichen
		return
	var delta := value - _pendulum_shown
	_pendulum_shown = value
	if delta == 0:
		return
	_flash_charm_and_pad(resolved)
	var color := CasinoStyle.GOLD if delta > 0 else PENDULUM_LOSS_COLOR
	table_screen.spawn_gain_number(_charm_trail_source_px([resolved]),
		"%+d" % delta, color, PENDULUM_SWING_FONT)

## Verkaufserlöse je Dock-Platz (Reihenfolge = Besitz) für den Verkaufs-Chip.
func _charm_sell_values() -> Array[int]:
	var values: Array[int] = []
	for i in run.owned_charms.size():
		values.append(run.charm_sell_value(i))
	return values

func _on_money_changed(new_money: int) -> void:
	var delta := new_money - _shown_money
	_shown_money = new_money
	_refresh_hub_info()
	_refresh_side_bet_affordability()
	_refresh_charging_column()  # Ableiten und Reparieren kosten Geld
	# Eine offene Umtausch-Geste/-Zeremonie abbrechen: Token entwerten, Geist
	# verwerfen - die Börse ist bereits endgültig gebucht.
	_exchange_token += 1
	_exchange_busy = false
	if chip_drag_value != -1:
		_finish_chip_drag(false)
	# Laufende Prägung abbrechen und die Anzeige auf die aktuelle Börse abgleichen
	# (eine unterbrochene Zwischen-Etappe würde sonst stehen bleiben).
	chip_stack.clear_mints()
	if chip_stack.wallet_total() != new_money - delta:
		chip_stack.seed_wallet(new_money - delta)  # Drift-Sicherung / Erstbefüllung
	else:
		chip_stack.show_wallet()
	# Ohne Tisch-Display oder während einer eigenen Nebenwetten-Choreografie:
	# Börse still mutieren, keine Präge-Animation.
	if delta == 0:
		return
	if table_screen == null or table_screen.hub == null or _suppress_money_light:
		_apply_wallet_delta(delta)
		chip_stack.show_wallet()
		return
	if delta > 0:
		_animate_money_gain(delta, new_money)
	else:
		_animate_money_spend(-delta)

## Mutiert die Börse um delta OHNE Animation (Nebenwetten / Rückfall ohne Display):
## Zuwachs kommt als gierige Chips herein, Zahlung folgt dem Zahlplan samt
## Wechselgeld. Die Börse bleibt stets deckungsgleich mit GameRun.money.
func _apply_wallet_delta(delta: int) -> void:
	if delta > 0:
		chip_stack.add_chips(ChipStackView.split_gain(delta))
	else:
		var plan := ChipStackView.payment_plan(chip_stack.wallet(), -delta)
		chip_stack.remove_chips(plan["spend"])
		chip_stack.add_chips(ChipStackView.split_gain(int(plan["change"])))

## Aufstieg-Knopf am Hub gedrückt: Ausbau über GameRun buchen (No-op wenn nicht
## bezahlbar oder max). Die Zeremonie folgt aus hub_level_changed.
func _on_hub_upgrade_pressed() -> void:
	if run == null:
		return
	run.upgrade_hub()

## Hub-Stufe gestiegen: Struktur-Freischaltungen anwenden + Aufstiegs-Zeremonie
## (Rahmen blitzt golden, Stoßwelle am Hub).
func _on_hub_level_changed(level: int) -> void:
	_sync_hub_level_state()
	_sync_secret_shop_state()  # der Börsen-Deckel wächst mit der Stufe
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.flash_frame(CasinoStyle.GOLD_INTENSE)
	# Prämien-Würfel und Belohnungs-Pakete sind schon gebucht (upgrade_hub) - die
	# Zeremonie zeigt nur, WAS die Stufe gebracht hat und wohin es gegangen ist.
	# Nicht awaiten: der Shop-Refresh darunter läuft parallel weiter.
	_play_hub_reward_ceremony(run.last_hub_reward_packs, run.last_hub_reward_fizzle,
		run.last_hub_reward_die)
	if charm_shop != null and charm_shop.visible:
		charm_shop.refresh_after_hub_upgrade()
	# Nebenwetten frisch installiert: Zeremonie + die Wettannahme sofort öffnen, damit
	# sich der Kauf noch in DIESER Runde auszahlt.
	if level == GameRun.HUB_SIDE_BETS_LEVEL and table_screen != null:
		table_screen.celebrate_side_bet_install(CasinoStyle.GOLD_INTENSE)
		if _side_bets_open_now():
			_open_side_bet_betting()
	# Ein frisch freigeschalteter Fumble-Automat feiert mit einer Stoßwelle.
	if level in GameRun.HUB_SLOT_LEVELS and table_screen != null:
		table_screen.celebrate_slot_bank_install(CasinoStyle.GOLD_INTENSE)

## Wendet den aktuellen Hub-Stufen-Zustand überall an: Plakette + Knopf am Hub,
## Shop-Knopf, und die Installation des Nebenwetten-Fensters. Idempotent - auch
## bei Spielstart und nach Reset aufgerufen.
func _sync_hub_level_state() -> void:
	if run == null:
		return
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_hub_level(run.hub_level, run.hub_level_name(),
			run.hub_next_level_name(), run.hub_next_unlock(), run.hub_upgrade_price())
		table_screen.hub.set_hub_upgrade_affordable(run.can_upgrade_hub())
	if table_screen != null:
		table_screen.set_side_bet_installed(true)
		if table_screen.side_bet_window != null:
			table_screen.side_bet_window.set_locked(not run.side_bets_unlocked())
		table_screen.set_slot_bank_installed(true)
		if table_screen.slot_bank_window != null:
			table_screen.slot_bank_window.set_locked(run.slots_unlocked() <= 0)
			table_screen.slot_bank_window.refresh()

## Laufende Nummer der Meteore eines Pakets - sie steuert die Ausbruch-Richtung,
## damit mehrere Stücke sichtbar auseinanderfliegen.
var _meteor_index := 0

## Temporäre Reveal-Auslage über der Hub-Mitte (Hub-Belohnung, Stresstest-Preis).
## Sie liegt im Feld, damit ein Lauf-Reset sie sicher wegräumen kann.
var _hub_reward_overlay: Control = null

## Welche Material-Gravuren das Schmuckkästchen an diesem Rundenende gefunden
## hat - gebucht beim Rundenabschluss, gezeigt an seinem Dock-Platz in der
## Charm-Zeremonie.
var _jewelry_box_upgrades: Array[Dictionary] = []

## Die Sonderposten, die das Füllhorn an diesem Rundenende gebucht hat - je
## Dock-Exemplar eines, gezeigt an seinem Platz in der Charm-Zeremonie.
var _encore_packs: Array[Pack] = []

## Unterdrückt das generische Schatz<->Hub-Geld-Licht, während eine Nebenwetten-
## Transaktion (Einsatz/Auszahlung) ihr eigenes Licht fährt.
var _suppress_money_light := false
## Die Magazin-Plätze der Pakete, die der nächste Einsatz verzehrt, und die Chips
## seines Zahlplans - gemerkt VOR der Buchung, denn danach steht an beiden Orten
## nichts mehr, das sich werfen ließe.
var _pending_bet_packs: Array[Vector2] = []
var _pending_bet_chips: Array[int] = []

## Überhellte Trail-Farbe eines Chips (fürs Bloom der Kometen).
func _money_trail_color(chip_color: Color) -> Color:
	return Color(chip_color.r * MONEY_PULSE_BOOST, chip_color.g * MONEY_PULSE_BOOST,
		chip_color.b * MONEY_PULSE_BOOST, 0.9)

## Gutschrift: die Börse bekommt die gierig gestückelten Chips SOFORT (bleibt
## deckungsgleich mit dem Geld), die Anzeige zeigt aber noch den alten Turm.
## Je Chip fährt ein Komet Hub -> Schatz; bei Ankunft leuchtet der Einzahlungs-
## Schlitz und ein Chip steigt daraus auf und hüpft auf den Turm. Nach dem
## Landen des letzten Chips baut sich der Turm neu auf (elastischer Pop).
func _animate_money_gain(delta: int, new_money: int) -> void:
	var treasure := table_screen.treasure_window
	var values := ChipStackView.split_gain(delta)
	chip_stack.add_chips(values)  # Börse sofort korrekt; Turm zeigt weiter ALT
	for i in values.size():
		var value: int = values[i]
		var chip_color := ChipStackView.denomination_color(value)
		var trail := _money_trail_color(chip_color)
		var fire := func() -> void:
			var travel: float = table_screen.money_comet(true, trail)
			get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
				if treasure != null:
					treasure.glint()
					treasure.flash_receive_slot(chip_color)
				chip_stack.mint_chip(value, true))
		if i == 0:
			fire.call()
		else:
			get_tree().create_timer(float(i) * MONEY_PULSE_GAP).timeout.connect(fire)
	var settle := float(maxi(0, values.size() - 1)) * MONEY_PULSE_GAP \
		+ table_screen.money_travel_time() + ChipStackView.MINT_TIME
	get_tree().create_timer(settle).timeout.connect(func() -> void:
		if _shown_money == new_money:
			chip_stack.show_wallet()
			chip_stack.pulse())

## Ausgabe: der Zahlplan bestimmt, welche Chips die Börse verlassen; die Börse
## wird sofort korrekt (Chips raus, Wechselgeld rein). Der Turm zeigt zunächst
## den Stand NACH der Zahlung (ohne Wechselgeld); je gezahltem Chip hebt einer
## ab und sinkt in den Auszahlungs-Schlitz, dann fährt sein Komet zum Hub. Steht
## Wechselgeld an, ploppt es danach aus dem Einzahlungs-Schlitz auf den Turm.
func _animate_money_spend(amount: int) -> void:
	var treasure := table_screen.treasure_window
	var plan := ChipStackView.payment_plan(chip_stack.wallet(), amount)
	var spend_values := _spend_list(plan["spend"])
	var change_values := ChipStackView.split_gain(int(plan["change"]))
	chip_stack.remove_chips(plan["spend"])
	chip_stack.add_chips(change_values)  # Börse jetzt endgültig (netto -Preis)
	# Zwischenbild: Börse OHNE das noch nicht sichtbare Wechselgeld.
	chip_stack.show_counts(ChipStackView.without(chip_stack.wallet(), change_values))

	for i in spend_values.size():
		var value: int = spend_values[i]
		var chip_color := ChipStackView.denomination_color(value)
		var lift := func() -> void:
			chip_stack.mint_chip(value, false)
			get_tree().create_timer(ChipStackView.MINT_TIME).timeout.connect(func() -> void:
				if treasure != null:
					treasure.flash_pay_slot(chip_color)
				var travel: float = table_screen.money_comet(false, _money_trail_color(chip_color))
				get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
					_on_payment_comet_arrived(chip_color)))
		if i == 0:
			lift.call()
		else:
			get_tree().create_timer(float(i) * MONEY_PULSE_GAP).timeout.connect(lift)

	# Wechselgeld tritt aus dem Einzahlungs-Schlitz, nachdem der letzte gezahlte
	# Chip absorbiert wurde.
	if change_values.is_empty():
		return
	var after_pay := float(maxi(0, spend_values.size() - 1)) * MONEY_PULSE_GAP + ChipStackView.MINT_TIME
	get_tree().create_timer(after_pay).timeout.connect(func() -> void:
		_animate_change_out(change_values))

## Wechselgeld: je Chip leuchtet der Einzahlungs-Schlitz und ein Chip hüpft auf
## den Turm; danach steht der Turm endgültig (Pop).
func _animate_change_out(change_values: Array) -> void:
	var treasure := table_screen.treasure_window
	for i in change_values.size():
		var value: int = int(change_values[i])
		var chip_color := ChipStackView.denomination_color(value)
		var pop := func() -> void:
			if treasure != null:
				treasure.flash_receive_slot(chip_color)
			chip_stack.mint_chip(value, true)
		if i == 0:
			pop.call()
		else:
			get_tree().create_timer(float(i) * MONEY_PULSE_GAP).timeout.connect(pop)
	var settle := float(maxi(0, change_values.size() - 1)) * MONEY_PULSE_GAP + ChipStackView.MINT_TIME
	get_tree().create_timer(settle).timeout.connect(func() -> void:
		chip_stack.show_wallet()
		chip_stack.pulse())

## Zahlplan {value: count} zur größten-zuerst geordneten Chip-Liste ausrollen.
func _spend_list(spend: Dictionary) -> Array:
	var out: Array = []
	for value in ChipStackView.VALUES:
		for _k in int(spend.get(value, 0)):
			out.append(value)
	return out

# --- Chip-Umtausch am Schlitz (Zieh-Geste in der Chip-Zoomsicht) -------------

## Maus auf Turm-lokale XZ-Koordinaten projizieren (null = kein Schnitt).
func _chip_local_at(screen_pos: Vector2) -> Variant:
	var hit: Variant = _mouse_on_plane(screen_pos, 0.0)
	if hit == null:
		return null
	var world: Vector3 = hit
	return Vector2(world.x - chip_stack.global_position.x, world.z - chip_stack.global_position.z)

## Beginnt das Ziehen eines ganzen Turms (nur in der Chip-Zoomsicht): der Turm
## verschwindet aus dem Rack und folgt als Geist der Maus zum Einwurf-Schlitz.
func _try_start_chip_drag(screen_pos: Vector2) -> bool:
	if _exchange_busy or run == null:
		return false
	var local: Variant = _chip_local_at(screen_pos)
	if local == null:
		return false
	var index := chip_stack.tower_at(local)
	if index == -1:
		return false
	var tower: Dictionary = chip_stack.towers()[index]
	chip_drag_value = int(tower["value"])
	chip_drag_count = int(tower["count"])
	# Anzeige ohne den gezogenen Turm; die Börse selbst bleibt unangetastet,
	# bis die Geste am Schlitz endet.
	var lifted: Array = []
	for _k in chip_drag_count:
		lifted.append(chip_drag_value)
	chip_stack.show_counts(ChipStackView.without(chip_stack.wallet(), lifted))
	chip_drag_ghost = chip_stack.build_ghost_tower(chip_drag_value, chip_drag_count)
	var at: Vector2 = tower["at"]
	chip_drag_ghost.position = Vector3(at.x, 0.8, at.y)
	camera_rig.set_tilt_locked(true)
	return true

## Zieh-Geste: Bewegung führt den Geist, Loslassen über einem Schlitz tauscht,
## sonst (oder per Rechtsklick) schnappt der Turm zurück.
func _handle_chip_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local: Variant = _chip_local_at(event.position)
		if local != null and chip_drag_ghost != null:
			var xz: Vector2 = local
			chip_drag_ghost.position = Vector3(xz.x, 0.8, xz.y)
		return
	if not (event is InputEventMouseButton) or event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_finish_chip_drag(false)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local: Variant = _chip_local_at(event.position)
	var over_slot := false
	if local != null:
		var xz: Vector2 = local
		over_slot = xz.distance_to(chip_stack.pay_slot_offset) <= ChipStackView.CHIP_RADIUS * 3.0 \
			or xz.distance_to(chip_stack.receive_slot_offset) <= ChipStackView.CHIP_RADIUS * 3.0
	_finish_chip_drag(over_slot)

## Beendet die Geste: drop=true versucht den Umtausch am Schlitz (nur wenn
## dabei ein höherer Chip entsteht), sonst kehrt der Turm ins Rack zurück.
func _finish_chip_drag(drop: bool) -> void:
	var value := chip_drag_value
	var count := chip_drag_count
	var ghost := chip_drag_ghost
	chip_drag_value = -1
	chip_drag_count = 0
	chip_drag_ghost = null
	camera_rig.set_tilt_locked(false)
	var upgraded := ChipStackView.exchange_values(value, count)
	if not drop or upgraded.is_empty() or ghost == null:
		# Kein Tausch: Geist verwerfen, Rack unverändert wieder zeigen.
		if ghost != null:
			ghost.queue_free()
		chip_stack.show_wallet()
		return
	_run_chip_exchange(value, count, upgraded, ghost)

## Umtausch-Zeremonie: der Geister-Turm sinkt in den Einwurf-Schlitz, dann
## treten die aufgewerteten Chips aus dem Ausgabe-Schlitz. Geldstand bleibt
## unverändert - nur die Stückelung der Börse ändert sich.
func _run_chip_exchange(value: int, count: int, upgraded: Array[int], ghost: Node3D) -> void:
	_exchange_busy = true
	_exchange_token += 1
	var token := _exchange_token
	var treasure := table_screen.treasure_window if table_screen != null else null
	var chip_color := ChipStackView.denomination_color(value)

	# Börse sofort endgültig umbuchen (Anzeige folgt der Choreografie).
	var swallowed: Dictionary = {}
	swallowed[value] = count
	chip_stack.remove_chips(swallowed)
	chip_stack.add_chips(upgraded)

	# Der Geist sinkt geschlossen in den Einwurf-Schlitz.
	var slot := chip_stack.pay_slot_offset
	if treasure != null:
		treasure.flash_pay_slot(chip_color)
	var sink := create_tween()
	sink.set_parallel(true)
	sink.tween_property(ghost, "position", Vector3(slot.x, 0.0, slot.y), 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	sink.tween_property(ghost, "scale", Vector3.ONE * 0.05, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	sink.chain().tween_callback(ghost.queue_free)

	# Danach treten die aufgewerteten Chips aus dem Ausgabe-Schlitz.
	get_tree().create_timer(0.38).timeout.connect(func() -> void:
		if token != _exchange_token:
			return
		for i in upgraded.size():
			var out_value: int = upgraded[i]
			var pop := func() -> void:
				if token != _exchange_token:
					return
				if treasure != null:
					treasure.flash_receive_slot(ChipStackView.denomination_color(out_value))
				chip_stack.mint_chip(out_value, true)
			if i == 0:
				pop.call()
			else:
				get_tree().create_timer(float(i) * MONEY_PULSE_GAP).timeout.connect(pop)
		var settle := float(maxi(0, upgraded.size() - 1)) * MONEY_PULSE_GAP + ChipStackView.MINT_TIME
		get_tree().create_timer(settle).timeout.connect(func() -> void:
			if token != _exchange_token:
				return
			_exchange_busy = false
			chip_stack.show_wallet()
			chip_stack.pulse()))

## Ankunft eines Zahlungs-Kometen am Hub: der Rahmen blitzt in Chip-Farbe.
func _on_payment_comet_arrived(chip_color: Color) -> void:
	var hub := table_screen.hub if table_screen != null else null
	if hub != null:
		hub.flash_frame(chip_color)

## Wette angeklickt (VOR der Zahlung): das generische Geld-Licht unterdrücken und
## merken, was gleich fliegt - der Zahlplan aus der Börse und, solange die Pakete
## noch liegen, ihre Magazin-Plätze. Danach steht an beiden Orten nichts mehr.
func _on_side_bet_selected(index: int) -> void:
	_suppress_money_light = true
	_pending_bet_packs.clear()
	_pending_bet_chips.clear()
	var panel := _side_bet_panel()
	if panel == null or index < 0 or index >= panel.offers.size():
		return
	var bet: SideBet = panel.offers[index]
	_pending_bet_packs = _bet_stake_pack_anchors(bet)
	_pending_bet_chips = _bet_stake_chips(bet)

## Die Chips, die der Spieler für diesen Einsatz WIRKLICH hinlegt - der Zahlplan
## seiner Börse, höchster Wert zuerst. Gefragt VOR der Buchung.
func _bet_stake_chips(bet: SideBet) -> Array[int]:
	var out: Array[int] = []
	if run == null or SideBetPanel.is_tax_bet(bet) \
			or bet.stake_kind != SideBet.Stake.MONEY:
		return out
	var plan := ChipStackView.payment_plan(chip_stack.wallet(), run.side_bet_stake(bet))
	var spend: Dictionary = plan["spend"]
	for value in ChipStackView.VALUES:
		for i in int(spend.get(value, 0)):
			out.append(int(value))
	return out

## Wette platziert (nach der Zahlung): der Einsatz WIRD GEWORFEN - Geld als
## gestapelte Salve von der Spitze des Schatzes, jedes geopferte Paket von seinem
## Magazin-Sitz, ⚡ als lose Zelle von der Bank. Er landet auf der PLATTFORM, und die
## senkt ihn ein: vom Einsatz liegt danach nie mehr etwas. In derselben Fahrt kommt
## der GEWINN in Sicht. Reines Schmuckwerk - gebucht ist der Einsatz längst.
func _on_side_bet_placed(index: int) -> void:
	_suppress_money_light = false
	var panel := table_screen.side_bet_window if table_screen != null else null
	if panel == null or index < 0 or index >= panel.offers.size():
		return
	var bet: SideBet = panel.offers[index]
	# Steuerwetten zahlen beim Platzieren nichts - es fliegt kein Körper. Ihr Gewinn
	# kommt sofort in Sicht, und die Rechnung tickt später als Licht.
	if SideBetPanel.is_tax_bet(bet):
		panel.glow_bet(index, SideBetPanel.GOLD)
		_write_bet_counter(ShopController.GRADE_RISE, true)
		return
	var glow_color := SideBetPanel.GOLD
	if bet.stake_kind == SideBet.Stake.PACKS:
		glow_color = SideBetPanel.ENGRAVING_GLOW
	elif bet.stake_kind == SideBet.Stake.ENERGY:
		glow_color = ENERGY_COMET_COLOR
	# Das Maß des Einsatzes wird JETZT genommen - bei der Landung steht der nächste
	# Zahlplan längst woanders, und der Schacht muß den ganzen Stapel schlucken.
	var stake_high := _bet_stake_height(bet, _pending_bet_chips)
	_throw_bet_stake(bet, _pending_bet_packs, _pending_bet_chips,
		_bet_seat_at(index), func(landed: Array) -> void:
			# Der Stapel steht: jetzt SCHLUCKT ihn die Sektion, und der Gewinn kommt
			# in derselben Fahrt herein.
			_bet_swallow[index] = {"bodies": landed, "height": stake_high}
			_write_bet_counter(ShopController.GRADE_RISE, true)
			panel.glow_bet(index, glow_color))

## Wie hoch der geworfene EINSATZ über der Plattform aufragt - der Schacht muß tief
## genug sein, dass der ganze Stapel beim Schlucken darin verschwindet. Gemessen an
## dem, was wirklich fliegt (der Wurf deckelt die Salve bei THROW_SALVO_CAP).
func _bet_stake_height(bet: SideBet, chips: Array[int]) -> float:
	match bet.stake_kind:
		SideBet.Stake.PACKS:
			return BetPrizeView.FLOOR_CLEAR \
				+ DataCellView.DEPTH * PackDrawerView.CASSETTE_SCALE
		SideBet.Stake.ENERGY:
			return BetPrizeView.FLOOR_CLEAR + CapacitorBankView.loose_cell_height()
	return BetPrizeView.FLOOR_CLEAR + ChipStackView.CHIP_HEIGHT \
		+ ChipStackView.stack_lift(mini(chips.size(), THROW_SALVO_CAP) - 1)

## Einsatz bezahlt: die Energie fährt vom Hub die Automaten-Ader entlang - eine
## Etappe wie jede ⚡-Zahlung (Schwarzmarkt-Grammatik), nicht zwei wie das Geld.
## Erst nach ihrer Ankunft läuft die Walze an.
func _on_slot_spin_paid(_machine: int) -> void:
	if table_screen == null:
		return
	table_screen.slot_pay_comet(CasinoStyle.ENERGY)

## Gewonnene Pakete: je Paket ein Licht vom Automaten ins Werkstatt-Lager, dicht
## gestaffelt wie die Frankiermaschinen-Salve. Erst die letzte Ankunft jubelt.
func _fly_slot_packs(packs: Array[Pack], from_px: Vector2) -> void:
	if packs.is_empty():
		return
	var tint: Color = PackIconRenderer.COLORS.get(packs[0].type, CasinoStyle.GOLD_INTENSE)
	var travel := 0.0
	for i in packs.size():
		if i > 0:
			await get_tree().create_timer(STAMP_METEOR_GAP).timeout
		if table_screen == null:
			return
		travel = table_screen.slot_pack_comet(from_px, tint)
	if travel > 0.0:
		await get_tree().create_timer(travel).timeout
	if table_screen != null:
		table_screen.celebrate_workshop_delivery(tint)

## Gewonnener Würfel: er geht denselben EINEN Weg wie jeder andere - ins
## AUSGABEFACH, wo er durch den Fachboden steigt. Gebucht hat das Automaten-Fenster
## längst (stash_die vor der Emission); zur Schale führt keine Leiterbahn, also
## fliegt das Licht ab dem Ader-Kopf als Meteor.
func _fly_slot_die_to_fach(def: DieDefinition, from_px: Vector2) -> void:
	if def == null or table_screen == null \
			or ausgabefach == null or not is_instance_valid(ausgabefach):
		return
	var rect := _fach_rect_px()
	if rect.size.x <= 0.0:
		return  # keine Schale gemessen: er liegt trotzdem längst hinterlegt da
	var launched := run
	ausgabefach.expect_arrival(def)
	var spread := _meteor_index
	_meteor_index += 1
	var travel := table_screen.tray_comet(from_px, rect.get_center(), SLOT_DIE_COLOR, spread)
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		if run == launched and is_instance_valid(ausgabefach):
			ausgabefach.deliver(def))

## Funkenflug: der Funke springt aus der Grube auf die bestehende ⚡-Route. Die
## Energie ist beim Aufruf SCHON gebucht - das hier ist reine Anzeige (wie bei
## den Nebenwetten), darum _fly_energy_to_capacitor(false). Dieselbe Salve trägt
## die Charm-Energie aus der Grube (Dynamo, Trostpreis) - sie kommt aus keiner
## Rune und fliegt darum ohne Funken.
## sparks nennt je ⚡ den Würfel, aus dem es springt: seine Rune lodert GENAU dann,
## wenn der Komet losfliegt. Der Funke, der von der Naht abspringt, und die
## Energie, die im Kondensator landet, werden so zu EINEM Vorgang - der stärkste
## Ursache-Wirkung-Lesbarkeitsgewinn, den das Runen-System zu bieten hat.
func _play_rune_energy_volley(count: int, sparks: Array[int] = []) -> void:
	var launched := run
	for i in count:
		var slot: int = sparks[i] if i < sparks.size() else -1
		if i == 0:
			_launch_rune_spark(slot)
		else:
			get_tree().create_timer(float(i) * STAMP_METEOR_GAP).timeout.connect(func() -> void:
				if run == launched:
					_launch_rune_spark(slot))

func _launch_rune_spark(slot: int) -> void:
	if slot >= 0 and slot < dice.count():
		_flare_runes(slot)
	_fly_energy_to_capacitor(false)

## Die ⚡-Salve AB HUB: je Energie ein Komet die Hub-Cluster-Ader zur Bank, dicht
## gestaffelt wie der Funkenflug. Die ⚡ sind beim Aufruf SCHON gebucht, hier fliegt
## nur das Licht (book=false); ein Laufwechsel während der Salve lässt den Rest liegen.
## Sie trägt die Kupfer-Energie eines Zuges und den kassierten Wett-Gewinn.
func _play_hub_energy_volley(count: int) -> void:
	if count <= 0 or table_screen == null:
		return
	var launched := run
	for i in count:
		if i == 0:
			_fly_energy_to_capacitor(false)
		else:
			get_tree().create_timer(float(i) * STAMP_METEOR_GAP).timeout.connect(func() -> void:
				if run == launched:
					_fly_energy_to_capacitor(false))

## Spiegelt die Lauf-Übersicht in den Hub - null-tolerant (kein Run/kein Hub).
func _refresh_hub_info() -> void:
	if run == null or table_screen == null or table_screen.hub == null:
		return
	table_screen.hub.set_run_info(run.round_number, run.money, _round_note())
	# Fahrplan-Block (6 Ziele, bleibt stehen bis das letzte geschafft ist) + Position
	# samt Markern (rot = Stresstest). Die Ziele sind die WIRKSAMEN: ein Deal mit
	# Benchmark-Aufschlag hebt die kommenden Stationen sichtbar an.
	table_screen.hub.set_goal_roadmap(run.goal_roadmap(6), run.goal_roadmap_index(6),
		run.goal_roadmap_markers(6), GameRun.block_of_round(run.round_number))
	_refresh_deal_tokens()
	# Aufstieg-Knopf folgt dem Geldstand (ausgegraut, wenn nicht bezahlbar).
	table_screen.hub.set_hub_upgrade_affordable(run.can_upgrade_hub())

## Deal-Marken: was gerade wirkt und wie lange noch - am Hub-Rad UND am oberen
## Grubenrand. Gespiegelt aus EINER Hand, damit die Wirkung auch dort steht, wo
## gewürfelt wird; beide Reihen zeigen dieselben Seiten in derselben Grammatik.
func _refresh_deal_tokens() -> void:
	var sides := run.active_deal_sides()
	table_screen.hub.set_deal_tokens(sides)
	table_screen.set_pit_deal_tokens(sides)

## Deal unterschrieben oder abgerechnet: Hub (Marken + Fahrplan) und die offene
## Wett-Auslage nachziehen - das Quotenpaket ändert Einsätze mitten in der
## Runde, der Setzen-Knopf darf keinen alten Preis versprechen.
func _on_deals_changed() -> void:
	_refresh_hub_info()
	if table_screen != null and table_screen.side_bet_window != null:
		table_screen.side_bet_window.refresh_betting()

## Kopfzeilen-Zusatz der laufenden Runde (die Deals zeigen die Marken).
func _round_note() -> String:
	return GameRun.STRESS_NAME if GameRun.is_stress_round(run.round_number) else ""

func _physics_process(delta: float) -> void:
	if phase != Phase.ROLLING:
		return
	if dice.physics_step(delta, rest_linear_threshold, rest_angular_threshold, rest_time_required):
		_on_roll_finished()

## Wandkontakt eines Würfels: das getroffene Feldsegment blitzt
## aufprallabhängig auf; andere Kontakte (Boden, Würfel↔Würfel) ignorieren wir.
func _on_die_wall_contact(other: Node, body: RigidBody3D) -> void:
	if not other.is_in_group("pit_wall"):
		return
	var speed := body.linear_velocity.length()
	if speed < FIELD_FLASH_MIN_SPEED:
		return
	var strength := clampf((speed - FIELD_FLASH_MIN_SPEED) / (FIELD_FLASH_FULL_SPEED - FIELD_FLASH_MIN_SPEED), 0.0, 1.0)
	dice_pit.flash_wall(other, lerpf(FIELD_FLASH_MIN_STRENGTH, 1.0, strength))

func _unhandled_input(event: InputEvent) -> void:
	if tray_drag_index != -1:
		_handle_tray_drag_input(event)
		return

	if fach_drag_index != -1:
		_handle_fach_drag_input(event)
		return

	if pit_drag_index != -1:
		_handle_pit_drag_input(event)
		return

	if reorder_drag_index != -1:
		_handle_reorder_input(event)
		return

	if charm_drag_index != -1:
		_handle_charm_drag_input(event)
		return

	if chip_drag_value != -1:
		_handle_chip_drag_input(event)
		return

	if shell_drag_active:
		_handle_shell_drag_input(event)
		return

	if grabbed_stage != null:
		_handle_floating_drag_input(event)
		return

	# Im Rückblick gehören die Pfeiltasten dem Cursor und Escape dem Schließen -
	# Tastatur erreicht die Fenster-UI nie, sie wird hier weitergereicht.
	if log_open:
		if event.is_action_pressed("ui_cancel"):
			_close_round_log()
			return
		if event.is_action_pressed("ui_left"):
			_log_step(-1)
			return
		if event.is_action_pressed("ui_right"):
			_log_step(1)
			return

	if event.is_action_pressed("ui_cancel"):
		_toggle_title()
		return

	# Die Freikamera hat KEINEN eigenen Zweig mehr: sie durchläuft dieselbe Kette
	# wie jede Station - erst die Weiterleitung an das, was sichtbar ist, dann die
	# physischen Griffe, und ganz zuletzt der Zonen-Klick als Flug. Rad und
	# Rechtsklick behalten dabei ihre Freikamera-Bedeutung (Zoom bzw. heim), weil
	# _handle_zoom_wheel und zoom_out sie selbst kennen.

	# Das offene Lexikon bekommt das Rad zuerst: über der Hub-Fläche scrollt es
	# den Text, überall sonst bleibt das Rad Kamera.
	if _forward_lexikon_wheel(event):
		return

	# Mausrad: hoch = heranfahren, runter = eine Stufe zurück. Steht hinter den
	# Zieh-Gesten (dort ist das Rad taub) und vor jeder Weiterleitung.
	if event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP
				or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_handle_zoom_wheel(event as InputEventMouseButton)
		return

	# Schwebende Würfel liegen ÜBER dem Werkstattfenster: der Griff danach muss vor
	# die Weiterleitung, sonst schluckt das Fenster den Klick - und vor die
	# Nahsicht, denn ein Würfel ist keine freie Bankfläche.
	if _try_grab_floating_die(event):
		return

	# Zweite Werkbank-Stufe: VOR der Weiterleitung, sonst verschluckt das
	# Werkstattfenster den Doppelklick.
	if _try_workshop_close_zoom(event):
		return

	# Display-UI: Mausereignisse über der Hub-Fläche gehen an die Controls AUF
	# dem Display - ein weitergereichter Klick löst keine 3D-Aktion mehr aus.
	if event is InputEventMouse and _forward_screen_mouse(event):
		return

	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		# Im Titel-HUD führt Rechtsklick nur eine Karte zurück - der Tisch
		# dahinter bleibt verdeckt, bis das Spiel wirklich startet.
		if camera_rig.mode == CameraRig.Mode.TITLE:
			if title_view.visible:
				title_view.go_back()
			return
		# Die Glas-Ansicht ist modal: Rechtsklick bricht sie ab, der Vorrat steigt
		# unverändert - die Kamera bleibt, wo sie steht.
		if _deck_glass:
			_close_deck_glass()
			return
		# Im Lexikon geht Rechtsklick den Verweis-Weg zurück: Historie, dann
		# Eintrag -> Index, und erst am Index klappt die Seite zu.
		if lexikon_view != null and lexikon_view.visible \
				and camera_rig.mode == CameraRig.Mode.HUB:
			if not lexikon_view.go_back():
				_close_lexikon()
			return
		# Der Rückblick schließt sich vor der Kamera - erst zurück in die
		# Gegenwart, dann darf man den Zoom verlassen.
		if log_open:
			_close_round_log()
			return
		# Aus der Inspektion führt Rechtsklick EINE Stufe zurück aufs Podest: der
		# Würfel legt sich in seine Schwebe-Ruhelage, abgewählt ist er noch nicht.
		if camera_rig.die_focus:
			_leave_die_focus()
			return
		# Steht ein Würfel auf dem Podest, wählt Rechtsklick ihn ab: er fährt per
		# Bühnen-Fahrt in seinen Pool-Sitz zurück.
		if _clear_workshop_target():
			return
		# Die Grube ist während der Runde frei begehbar - der Spieler darf sich
		# umsehen (auch bei liegender Auslage); nur das Bearbeiten der Würfel bleibt
		# bis zum Laden gesperrt und der Wurf bis zur Unterschrift.
		# Aus der Werkbank-Nahsicht geht es eine Stufe zurück, nicht ganz raus.
		if camera_rig.workshop_close:
			camera_rig.zoom_workshop_wide()
			return
		camera_rig.zoom_out()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Im Titel-HUD gibt es nur die Menü-Knöpfe (die schon weitergereicht sind).
	if camera_rig.mode == CameraRig.Mode.TITLE:
		return

	if is_pit_focused and _try_start_shell_drag(event.position):
		return

	if _try_start_charm_reorder(event.position):
		return

	if _can_toggle_selection():
		var index := _pick_die_index(event.position)
		if index != -1:
			# Druck startet eine MÖGLICHE Zieh-Geste; ob daraus ein Umsortieren
			# oder nur ein Auswahl-Klick wird, entscheidet erst der Weg bis zum
			# Loslassen (dieselbe Logik wie beim Warteschlangen-Würfel).
			pit_drag_index = index
			pit_drag_start_pos = event.position
			pit_is_dragging = false
			camera_rig.set_tilt_locked(true)
			return

	if not _dice_in_motion() and deck_shift_ghosts.is_empty() and _try_start_queue_reorder(event.position):
		return

	if not _dice_in_motion() and _try_start_pool_tray_drag(event.position):
		return

	if _felt_pick_live(CameraRig.Mode.CHIPS) and _try_start_chip_drag(event.position):
		return

	# Übertakten: die Chips liegen UNTER der Kombinations-Klickzone, ihr Griff
	# muss also vor den Zoom-Klick.
	if event.button_index == MOUSE_BUTTON_LEFT and _try_combo_upgrade_click(event.position):
		return

	_try_zoom_click(event.position)

## Physik-Raycast aus der Kamera durch screen_pos auf mask; leeres Dictionary
## = kein Treffer (oder keine Kamera).
func _ray_pick(screen_pos: Vector2, mask: int) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = mask
	return get_world_3d().direct_space_state.intersect_ray(query)

## Projiziert screen_pos auf eine waagerechte Ebene der Höhe height
## (Vector3 oder null).
func _mouse_on_plane(screen_pos: Vector2, height: float) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	return Plane(Vector3.UP, height).intersects_ray(
		camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))

## Ein Würfel im Stasis-Feld über der Werkbank; der Aufrufer lässt ihn landen.
## hover muss VOR setup stehen: die Station baut ihre Säule auf diese Höhe.
func _spawn_floating_die(def: DieDefinition, tint: Color, from: Vector3,
		hover: float = ENGRAVE_HOVER) -> FloatingDie:
	var stage := FloatingDie.new()
	stage.name = "FloatingDie"
	stage.hover_height = hover
	add_child(stage)
	stage.setup(def, tint, from)
	ScreenReflection.mark_reflective(stage)  # er schwebt über dem Werkbank-Glas
	return stage

## Landepunkt über einem Display-Pixel: auf die Tischfläche zurückprojiziert und
## senkrecht auf Schwebehöhe gehoben. Der ANKER ist der Projektor, nicht der
## Körper - die Station steht auf dem Glas, also in derselben Ebene wie das Netz,
## und zwei Dinge in einer Ebene treffen unter JEDER Kamera dasselbe Pixel. Darum
## braucht dieser Platz keine Kamera und keinen Ausgleich.
## height: die Höhe der KÖRPERMITTE über der Fläche; ein Körper, der auf dem Glas
## LIEGEN soll, übergibt seine halbe Kantenlänge (0 = die Kassette hebt sich selbst).
func _bench_hover_target(px: Vector2, height: float = ENGRAVE_HOVER) -> Vector3:
	return table_screen.pixel_to_world(px) + Vector3.UP * height

## DIE SERIE IST DURCH: der Würfel steht wieder auf dem Podest. Hier steht der EINE
## Aufräum-Pfad der Zeremonie - Endzustand zuerst (Licht, Netz und Funken fort, der
## gebuchte Stand auf dem Würfel), dann der SCHLAG auf den Körper auf dem Podest.
## Rein visuell; GameRun hat beim Griff gebucht.
func _on_series_applied(result: Dictionary, _from_px: Vector2) -> void:
	_settle_durchlicht()
	if result.is_empty() or bench_stage == null or not is_instance_valid(bench_stage):
		return
	bench_stage.pulse()

#region DAS DURCHLICHT
# Die Zeremonie des Griffs als KÖRPER: alle Karten rasten in ihre Kontaktzungen ein,
# der Zielwürfel fliegt vom Podest ÜBER den Turm, und aus der KAMMER am Turmfuß steigt
# ein LICHT durch alle Etagen. Jede Karte, die es passiert, flammt auf, gibt ihre
# Zellen an das mitreitende LICHT-NETZ ab und BRENNT AUS. Oben zerfällt das Netz in
# bis zu sechs LICHTFUNKEN, die ALLE ZUGLEICH in die Seitenmitten des Würfels
# schlagen - dort steht er mit seinem gebuchten Stand.
# Den TAKT gibt das Fenster (cards_latched/die_raised/light_passed/light_struck/
# die_returned), gefahren wird hier - ui/ faßt nie Körper an. Der EINE Aufräum-Pfad
# ist _settle_durchlicht.

## Die Karten, die das Licht schon gelesen hat und die gerade ausbrennen - sie sind
## aus socket_cells ausgetragen, also führt sie diese Liste, damit der Aufräum-Pfad
## sie mitnimmt.
var _burning_cards: Array[DataCellView] = []

## Der Griff beginnt: Licht, Netz und Funken der vorigen Zeremonie fahren nie mit.
func _on_press_started() -> void:
	_press_gen += 1
	_drop_light_net()
	_drop_sparks()

## ALLE KARTEN RASTEN EIN: sie fahren nach Bild-rechts bündig in ihre Etage, von
## unten nach oben gestaffelt, und ihr Mund in der Kontaktleiste blitzt dabei auf.
func _on_cards_latched(time: float) -> void:
	_durchlicht = true
	_bench_riding = true  # die Zeremonie führt den Podest-Würfel, nicht der Abgleich
	_sync_step_hover(-1)  # kein Zeiger zieht mehr an einer Karte
	_rebuild_target_stage()  # der leere Puck tritt an die Stelle des Würfels
	_latch_cards(time, _press_gen, run)  # nicht erwartet: die Fahrt läuft für sich

func _latch_cards(time: float, generation: int, launched: GameRun) -> void:
	var count := socket_cells.size()
	var span := maxf(time - WorkshopView.LATCH_STAGGER * float(maxi(count - 1, 0)), 0.05)
	for i in count:
		if run != launched or generation != _press_gen:
			return
		var cell := _socket_cell(i)
		if cell != null:
			cell.set_hovered(false)
			cell.glide_to(_tower_seat(i), span)
			_flash_latch(i, cell, span, generation, launched)  # nicht erwartet
		if i < count - 1:
			await get_tree().create_timer(WorkshopView.LATCH_STAGGER).timeout

## Der Mund-Blitz bei der Ankunft - die Karte steckt, das ist das Klicken.
func _flash_latch(index: int, cell: DataCellView, delay: float, generation: int,
		launched: GameRun) -> void:
	await get_tree().create_timer(maxf(delay, 0.0)).timeout
	if run != launched or generation != _press_gen:
		return
	if tower != null and is_instance_valid(tower):
		tower.latch_flash(index)
	if cell != null and is_instance_valid(cell):
		cell.flare()

## Der ZIELWÜRFEL fliegt vom Podest ÜBER den Turm - derselbe Körper, derselbe
## Trage-Bogen wie Pool ⇄ Podest. Zugleich zündet das Licht in der Kammer und steigt
## in die unterste Etage.
func _on_die_raised(time: float) -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if tower != null and is_instance_valid(tower) and workshop != null \
			and is_instance_valid(workshop):
		tower.light_on(_series_tint(workshop))
		tower.light_to(_light_stop(0), time)
	_ride_die_over_tower(_tower_die_point(), time, _press_gen, run)

## Der Würfel fährt DENSELBEN Bogen wie Pool ⇄ Podest - hin wie zurück.
func _ride_die_over_tower(target: Vector3, time: float, generation: int,
		launched: GameRun) -> void:
	var stage := bench_stage
	if stage == null or not is_instance_valid(stage) or target == Vector3.ZERO:
		return
	stage.set_process(false)  # kein Eigen-Wippen, solange der Bogen ihn führt
	var tween := stage.carry_to(target, time, BENCH_CARRY_PEAK)
	if tween == null:
		stage.set_process(true)
		stage.land_at(target, 0.0)
		return
	tween.finished.connect(func() -> void:
		if not is_instance_valid(stage):
			return
		stage.set_process(true)
		if generation == _press_gen and run == launched:
			stage.land_at(target, 0.0))

## Das Licht hat Etage index erreicht: ihre Karte flammt auf, gibt ihre Zellen ab und
## BRENNT AUS, das LICHT-NETZ tickt auf den neuen Stand - und die Ebene steigt weiter.
func _on_light_passed(index: int, faces: Array, values: Array, operator: String,
		time: float) -> void:
	var cell := _take_socket_cell(index)
	if cell != null:
		cell.set_net_drained(_drained_mask(faces))  # idempotent
		cell.flare()
		_burn_out_card(cell, time, _press_gen, run)  # nicht erwartet
	if _light_net == null or not is_instance_valid(_light_net):
		_spawn_light_net()
	if _light_net != null and is_instance_valid(_light_net):
		_light_net.tick_to(values, LIGHT_TICK_TIME)
		if operator == "":
			_light_net.strike()
		else:
			_light_net.punch(StampNet.operator_glyph(operator))
	if tower != null and is_instance_valid(tower):
		tower.light_to(_light_stop(index + 1), time)

## Die gelesene Karte ist verbraucht: sie dimmt, löst sich auf und ist fort, bevor
## das Licht die nächste Etage erreicht.
func _burn_out_card(cell: DataCellView, time: float, generation: int,
		launched: GameRun) -> void:
	_burning_cards.append(cell)
	cell.set_dimmed(true)
	cell.dematerialize()
	await get_tree().create_timer(maxf(time, 0.0)).timeout
	if run != launched or generation != _press_gen:
		return
	_burning_cards.erase(cell)
	_free_data_cell(cell)

## Wohin die Licht-Ebene als NÄCHSTES steigt: auf die Kartenhöhe der Etage index -
## und über der obersten auf den Turmkopf.
func _light_stop(index: int) -> float:
	if tower == null or not is_instance_valid(tower):
		return 0.0
	if index >= tower.floor_count():
		return tower.top_point().y
	return tower.floor_point(index).y + TowerView.CARD_THICKNESS * 0.5

## DER EINSCHLAG: das Licht-Netz zerfällt in seine LICHTFUNKEN - je benutzter Seite
## einer -, sie fliegen ALLE ZUGLEICH auf die Seitenmitten des Würfels, und dort
## steht er mit seinem GEBUCHTEN Stand. Der held_faces-Halt endet HIER.
func _on_light_struck(time: float) -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	var projection: Dictionary = workshop.burn_projection() if workshop != null \
		and is_instance_valid(workshop) else {}
	var stage := bench_stage
	var origin := _light_net.global_position if _light_net != null \
		and is_instance_valid(_light_net) else _tower_die_point()
	var tint := _series_tint(workshop) if workshop != null and is_instance_valid(workshop) \
		else PressNetView.VALUE_TINT
	var hits: Array[int] = []
	for face in StampNet.FACES:
		if _face_bonus(projection, face) == 0:
			continue
		hits.append(face)
		var spark := LightSparkView.new()
		add_child(spark)
		spark.setup(tint)
		spark.seat_at(origin)
		_sparks.append(spark)
		spark.fly_to(_die_face_point(stage, face), time, SPARK_PEAK)
	_drop_light_net()  # es IST in die Funken zerfallen
	if tower != null and is_instance_valid(tower):
		tower.light_off()
	_strike_die(hits, time, _press_gen, run)  # nicht erwartet: der Einschlag ist Licht

## Beim Einschlag steht der gebuchte Stand da - ALLE Seiten auf einmal -, die
## getroffenen blitzen grün, und der Würfel pulst.
func _strike_die(hits: Array[int], delay: float, generation: int,
		launched: GameRun) -> void:
	await get_tree().create_timer(maxf(delay, 0.0)).timeout
	if run != launched or generation != _press_gen:
		return
	_drop_sparks()
	var stage := bench_stage
	if stage == null or not is_instance_valid(stage) or stage.def == null:
		return
	stage.apply_definition(stage.def)
	stage.pulse()
	if stage.emitter != null and is_instance_valid(stage.emitter):
		stage.emitter.ripple()
	if stage.faces == null or not is_instance_valid(stage.faces):
		return
	for face in hits:
		stage.faces.set_face_number_tint(face, REVEAL_FLASH_COLOR)
	await get_tree().create_timer(SERIES_FLASH_TIME).timeout
	if run != launched or generation != _press_gen:
		return
	if stage != null and is_instance_valid(stage) and stage.faces != null \
			and is_instance_valid(stage.faces):
		stage.faces.reset_number_tints()

## Und der Würfel fliegt denselben Bogen zurück aufs Podest.
func _on_die_returned(time: float) -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop):
		return
	_ride_die_over_tower(_bench_podium_target(workshop), time, _press_gen, run)

## Der Bonus, den die Serie auf diese Seite geschrieben hat (0 = keiner) - die
## Projektion sagt es selbst, hier wird keine Regel nachgebaut.
static func _face_bonus(projection: Dictionary, face: int) -> int:
	var bonus: Array = projection.get("bonus", [])
	return int(bonus[face]) if face >= 0 and face < bonus.size() else 0

## Die SEITENMITTE einer Würfelseite in Welt: Würfelmitte plus ihre Richtung mal der
## halben Kante - dorthin schlägt ihr Funke ein.
func _die_face_point(stage: FloatingDie, face: int) -> Vector3:
	if stage == null or not is_instance_valid(stage) or stage.faces == null \
			or not is_instance_valid(stage.faces):
		return _tower_die_point()
	var centre := stage.center()
	var half := DieBuilder.HALF_EXTENT * DiceTrayView.DIE_SCALE
	var basis := stage.faces.global_basis.orthonormalized()
	for axis: String in DiceController.AXIS_FACE_INDEX:
		if int(DiceController.AXIS_FACE_INDEX[axis]) != face:
			continue
		var dir: Vector3 = basis * (DiceController.AXIS_DIRECTIONS[axis] as Vector3)
		return centre + dir * half
	return centre

## Der Schwebeplatz des Würfels ÜBER dem Turm: eine Würfelkante Luft über dem Kopf.
func _tower_die_point() -> Vector3:
	if tower == null or not is_instance_valid(tower):
		return Vector3.ZERO
	return tower.top_point() + Vector3.UP * TOWER_DIE_CLEAR

## Das LICHT-NETZ entsteht auf der Licht-Ebene und REITET von da an mit ihr.
func _spawn_light_net() -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop) or tower == null \
			or not is_instance_valid(tower):
		return
	_drop_light_net()
	var net := LightNetView.new()
	add_child(net)
	net.setup(_series_tint(workshop), _series_energy(workshop))
	tower.attach_to_light(net)
	net.position = Vector3.ZERO
	_light_net = net

## Der TON des Lichts: die Sorte der WERT-Karten (Operatoren sind amber, die
## Farbtrennung der Serie) - die Karten der laufenden Zeremonie sagen es selbst.
func _series_tint(workshop: WorkshopView) -> Color:
	for card: Dictionary in workshop.burning_cards():
		if String(card.get("operator", "")) != "" or String(card.get("catalyst", "")) != "":
			continue
		return PackDrawerView.COLORS.get(String(card.get("sort", "")),
			PressNetView.VALUE_TINT)
	return PressNetView.VALUE_TINT

## ... und seine INTENSITÄT: die höchste Paketgröße der Serie, dieselbe Leiter, die
## jede Kassette liest.
func _series_energy(workshop: WorkshopView) -> float:
	var tier := 0
	for card: Dictionary in workshop.burning_cards():
		tier = maxi(tier, int(card.get("tier", 0)))
	return DataCellView.TIER_ENERGY[clampi(tier, 0,
		DataCellView.TIER_ENERGY.size() - 1)]

## Die gemeldeten Seiten als Maske, wie sie die Kassette erwartet - eine Liste von
## Seiten-Indizes läse sich dort als Wahrheitswerte und träfe die falschen Zellen.
static func _drained_mask(faces: Array) -> Array:
	var mask: Array[bool] = []
	for face in StampNet.FACES:
		mask.append(faces.has(face))
	return mask

## Der EINE Aufräum-Pfad der Zeremonie, HART: Licht, Netz und Funken sind fort, jede
## noch liegende oder brennende Karte fällt weg, und der Würfel steht HART auf dem
## Podest mit seinem GEBUCHTEN Stand.
func _settle_durchlicht() -> void:
	_press_gen += 1
	_hovered_step = -1  # die überfahrene Etage ist mit ihrer Karte fort
	_drop_light_net()
	_drop_sparks()
	if tower != null and is_instance_valid(tower):
		tower.light_off()
	_settle_carries()  # ein noch fliegender Trage-Bogen steht erst hart
	for cell in socket_cells:
		_free_data_cell(cell)
	socket_cells.clear()
	socket_uids.clear()
	for burning in _burning_cards:
		_free_data_cell(burning)
	_burning_cards.clear()
	_durchlicht = false
	_bench_riding = false
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if bench_stage != null and is_instance_valid(bench_stage):
		var podium := _bench_podium_target(workshop) if workshop != null \
			and is_instance_valid(workshop) else Vector3.ZERO
		if podium != Vector3.ZERO:
			bench_stage.land_at(podium, 0.0)
		bench_stage.set_process(true)
		if bench_stage.def != null:
			bench_stage.apply_definition(bench_stage.def)
			if bench_stage.faces != null and is_instance_valid(bench_stage.faces):
				bench_stage.faces.reset_number_tints()
	_rebuild_target_stage()  # der Puck weicht wieder dem Körper

func _drop_light_net() -> void:
	if _light_net == null:
		return
	if is_instance_valid(_light_net):
		_light_net.settle()
		if _light_net.get_parent() != null:
			_light_net.get_parent().remove_child(_light_net)
		_light_net.queue_free()
	_light_net = null

func _drop_sparks() -> void:
	for spark in _sparks:
		if spark != null and is_instance_valid(spark):
			spark.settle()
			remove_child(spark)
			spark.queue_free()
	_sparks.clear()

## Die Karte der Etage index (null = keine) - und dieselbe AUSGETRAGEN, damit der
## Sockel-Schreiber sie nicht neu bestückt. Die Indizes der übrigen bleiben stehen.
func _socket_cell(index: int) -> DataCellView:
	if index < 0 or index >= socket_cells.size():
		return null
	var cell: DataCellView = socket_cells[index]
	return cell if cell != null and is_instance_valid(cell) else null

func _take_socket_cell(index: int) -> DataCellView:
	var cell := _socket_cell(index)
	if index >= 0 and index < socket_cells.size():
		socket_cells[index] = null
		if index < socket_uids.size():
			socket_uids[index] = 0
	return cell

#endregion

# --- Schwebende Würfel in der Hand -----------------------------------------------
# Ein schwebender Würfel IST die Ansicht: der ERSTE Tipp stellt ihn aufs Podest, der
# ZWEITE holt ihn heran (die INSPEKTION), und dort dreht ihn das Ziehen. Getroffen
# wird über die Bildschirm-Projektion; die Würfel tragen keine Kollisionsform.

## Alle gerade schwebenden Würfel, die man anfassen darf - seit der BÜHNEN-STRASSE
## (2026-09-03) ist das genau EINER: der Würfel auf dem WERKSTATT-PODEST.
func _floating_stages() -> Array[FloatingDie]:
	var stages: Array[FloatingDie] = []
	if bench_stage != null and is_instance_valid(bench_stage):
		stages.append(bench_stage)
	return stages

## Der schwebende Würfel unter dem Bildschirmpunkt (null = keiner). In der
## Inspektion kommt nur der herangeholte in Frage - die anderen stehen außerhalb.
func _stage_under(screen_pos: Vector2) -> FloatingDie:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	if camera_rig.die_focus:
		if focused_stage != null and is_instance_valid(focused_stage) \
				and focused_stage.under(camera, screen_pos):
			return focused_stage
		return null
	return _bench_stage_under(screen_pos)

## Druck auf einen schwebenden Würfel: er liegt ÜBER dem Werkstattfenster, der
## Griff muss also vor die Maus-Weiterleitung - sonst schluckt das Fenster den
## Klick.
func _try_grab_floating_die(event: InputEvent) -> bool:
	if camera_rig.is_animating:
		return false
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	var stage := _stage_under(button.position)
	if stage == null:
		return false
	# Doppelklick auf den Podest-Würfel holt ihn HERAN (INSPEKTION), statt einen
	# Dreh-Griff zu starten; der Ein-Tipp gehört dem Drehen.
	if button.double_click and not camera_rig.die_focus and stage == bench_stage:
		_focus_floating_die(stage)
		return true
	grabbed_stage = stage
	grab_start = button.position
	grab_moved = false
	return true

## Die Geste am gegriffenen Würfel: Ziehen dreht ihn (in der INSPEKTION UND am
## Podest, wo er an Ort dreht). Ein Ein-Tipp löst nichts aus - herangeholt wird per
## Doppelklick, und ein Weg macht aus keiner Geste eine Wahl.
func _handle_floating_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if not grab_moved and motion.position.distance_to(grab_start) > ENGRAVE_DRAG_THRESHOLD:
			grab_moved = true
		if grab_moved:
			grabbed_stage.spin(motion.relative, get_viewport().get_camera_3d())
		return
	var button := event as InputEventMouseButton
	if button == null or button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	grabbed_stage = null

## Der ZWEITE Tipp holt den Podest-Würfel HERAN: super nah, die Kamera steht still,
## und ab hier dreht ein Zug ihn. Es ist ein TEMPORÄRER Rahmen wie bei der
## Glas-Ansicht - kein Moduswechsel, also wählt der eigene Zoom das Podest nicht ab.
func _focus_floating_die(stage: FloatingDie) -> void:
	if stage == null or not is_instance_valid(stage) or camera_rig.die_focus:
		return
	focused_stage = stage
	_die_focus_home = camera_rig.camera_pose()
	camera_rig.set_tilt_locked(true)
	# Halbe Raumdiagonale: so passt der Würfel in JEDER Drehung ins Bild.
	var half := DieBuilder.HALF_EXTENT * DiceTrayView.DIE_SCALE * sqrt(3.0)
	camera_rig.zoom_die_focus(stage.center(), half)
	stage.pose_to(CameraRig.die_focus_basis(), CameraRig.ZOOM_DURATION)

## Eine Stufe zurück aufs Podest: der Würfel legt sich in seine Schwebe-Ruhelage,
## die Kamera an die gemerkte Station. Idempotent - Rechtsklick, Rad und der harte
## Weg gehen alle hier durch, und ein vergessenes Zuhause fliegt nicht.
func _leave_die_focus() -> void:
	var stage := focused_stage
	focused_stage = null
	if stage != null and is_instance_valid(stage):
		stage.pose_to(FloatingDie.rest_pose(), CameraRig.ZOOM_DURATION)
	var home := _die_focus_home
	_die_focus_home = {}
	if not camera_rig.die_focus:
		return
	camera_rig.zoom_die_focus_out()
	camera_rig.release_tilt_immediately()
	if not home.is_empty():
		camera_rig.restore_pose(home)

## Die Werkstatt hat ihre Bühne neu gelegt: der schwebende Würfel zieht nach.
func _on_die_stages_changed() -> void:
	_rebuild_bench_stage()
	_rebuild_target_stage()  # der leere Puck folgt demselben Layout
	_sync_data_cells()  # Magazin-Kassetten und Schlitze hängen am selben Layout

## Der Spieler hat im Raster gewählt, gewechselt oder abgewählt: der Zielwürfel
## fährt auf die Bühne bzw. denselben Weg zurück in den Pool.
func _on_workshop_target_chosen(_die: DieDefinition) -> void:
	_sync_bench_migration()
	if _deck_glass:
		_show_deck_glass_window()  # der Gold-Saum im Raster folgt der Wahl

## Die ZIELWAHL der Serie - EIN Weg für beide Tipps (Pool-Körper und Raster-Zelle).
## Der Ort-Zustand wohnt im Fenster: derselbe wählt ab, ein anderer wechselt.
func _choose_workshop_target(die: DieDefinition) -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop != null and is_instance_valid(workshop):
		workshop.set_target_die(die)

# --- Das PODEST: EIN Würfel fährt per Plattform aus dem Pool herauf ---------------
# Der ZIELWÜRFEL der Serienschaltung liegt im Pool (Träger), bis der Spieler ihn im
# Vorrat ANTIPPT - dann fährt er per Hebebühne auf das EINE Podest der Würfel-Spalte
# und bleibt dort, bis er ab- oder umgewählt wird (die ÜBERGABE auf ein zweites
# Podest ist mit der WELLE S gestorben). Ob er dort steht, sagt _bench_die (der EINE
# Ort-Zustand): der Bühnen-Körper ist ein FloatingDie (Würfel+Feld), der Pool-Körper
# der Tray-Slot selbst - nie beide zugleich sichtbar. Den PLATZ nennt das FENSTER
# (target_net_center samt seiner Projektor-Zeile).

## Der Würfel, der auf das PODEST gehört (null = keiner): schlicht die Zielwahl des
## Fensters. Seit der BÜHNEN-STRASSE hängt sie NICHT mehr an der Kamera-Station -
## es gibt nur noch dieses eine Podest, und der Pool-Tipp fährt IMMER dorthin (die
## Fahrt selbst wartet ohnehin auf den stehenden Vorrat, _sync_bench_migration).
func _wanted_bench_die() -> DieDefinition:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop) or not workshop.visible:
		return null
	return workshop.target_die()

## Wählt den Zielwürfel ab (true = es stand einer). Die Abwahl geht durch das
## FENSTER - dort wohnt der eine Ort-Zustand des Ziels.
func _clear_workshop_target() -> bool:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop) or workshop.target_die() == null:
		return false
	workshop.clear_target()
	return true

## Der Steady-State-Schreiber der BÜHNE: steht der Zielwürfel dort, hat er genau
## EINEN Körper über seinem Netz, sonst keinen. Wer schon steht, bleibt DERSELBE
## Körper und wandert nur (das Netz rückt beim Neuaufbau des Fensters). Eine
## laufende Fahrt führt ihre eigene Bühne - der Schreiber faßt sie nicht an.
func _rebuild_bench_stage() -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop):
		return
	if _bench_riding:
		return
	# Ein Körper des falschen Würfels wird neu gestellt, nicht umgesetzt.
	if bench_stage != null and is_instance_valid(bench_stage) \
			and bench_stage.def != _bench_die:
		_free_stage(bench_stage)
		bench_stage = null
	if _bench_die == null:
		if bench_stage != null and is_instance_valid(bench_stage) and bench_stage.visible:
			bench_stage.dematerialize()
		return
	# Der Platz steht erst nach dem Layout des Fensters fest - und ZWEI Bilder weit:
	# nach einem Neuaufbau hat der Kasten im ersten Bild erst seine Kinder, aber noch
	# keine sortierten Rechtecke.
	var launched := run
	var generation := _bench_gen
	await get_tree().process_frame
	if not is_instance_valid(workshop) or run != launched or run == null:
		return  # Laufwechsel während des Bildes: der nächste Aufbau räumt selbst auf
	await get_tree().process_frame
	if not is_instance_valid(workshop) or run != launched or run == null:
		return
	if generation != _bench_gen or _bench_riding or _bench_die == null:
		return
	var target := _bench_podium_target(workshop)
	if target == Vector3.ZERO:
		return
	if bench_stage != null and is_instance_valid(bench_stage):
		if bench_stage.visible:
			if not bench_stage.stands_at(target):
				bench_stage.move_to(target, PACK_MOVE_TIME)
			return
		bench_stage.land_at(target, 0.0)
		bench_stage.materialize()
		return
	bench_stage = _spawn_floating_die(_bench_die, CLAMP_EMITTER_TINT, target,
		CLAMP_HOVER)
	bench_stage.land_at(target, 0.0)
	bench_stage.materialize()

## Der Weltpunkt des PODESTS in der Würfel-Spalte - das Fenster meldet ihn
## (ZERO = der Platz steht gerade nicht).
func _bench_podium_target(workshop: WorkshopView) -> Vector3:
	var center := workshop.target_net_center()
	if center.x < 0.0:
		return Vector3.ZERO
	return _bench_hover_target(Vector2(center.x, workshop.target_projector_y()),
		CLAMP_HOVER)

## Der LEERE Puck, der den Podest-Platz lesen läßt. Steht der Würfel darauf, weicht
## er - zwei Pucks an einem Platz wären ein zweiter Leib. Idempotent: dieselbe
## Zielposition baut nichts neu, sie folgt nur dem Layout.
var target_stage: StasisEmitter

func _rebuild_target_stage() -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop):
		return
	# Während des DURCHLICHTS steht der Würfel über dem Turm - das Podest zeigt
	# derweil seinen leeren Puck.
	target_stage = _seat_podium_puck(target_stage, "TargetStage",
		_bench_podium_target(workshop), _bench_die == null or _durchlicht)

## Der EINE Schreiber des Pucks. Die Station steht auf der Fläche (Y=0) - der
## Anker ist der Projektor, nicht ein schwebender Körper (_bench_hover_target).
func _seat_podium_puck(puck: StasisEmitter, puck_name: String, at: Vector3,
		shown: bool) -> StasisEmitter:
	if at == Vector3.ZERO:
		return puck
	if puck == null or not is_instance_valid(puck):
		puck = StasisEmitter.new()
		puck.name = puck_name
		add_child(puck)
		puck.build(CLAMP_HOVER, DiceTrayView.DIE_SCALE, CLAMP_EMITTER_TINT)
		ScreenReflection.mark_reflective(puck)
	puck.global_position = at - Vector3.UP * CLAMP_HOVER
	puck.visible = shown
	return puck

# --- Die FAHRT Pool <-> Bühne (TRAGE-BOGEN) --------------------------------------
# Die Zielwahl ist ein SPIELER-Zug, also fliegt der Würfel ÜBER dem Tisch: EIN
# Körper reist im flachen Bogen vom Pool-Sitz auf das Podest und zurück (Welle T,
# 2026-09-05 - davor sank er durch ein Loch und stieg durch ein zweites). Der
# Ort-Zustand kippt beim ABFLUG (der Sitz wird leer, sobald der Träger fliegt) bzw.
# bei der ANKUNFT - ein Würfel wird nie zweimal gezeigt. Der EINE Aufräum-Pfad ist
# _reset_bench_migration_hard.

## Der EINE Schreiber des ORTS: welcher Würfel auf dem Podest steht (null = keiner).
## Er zieht den leeren Puck gleich mit - der weicht dem Körper und kommt zurück,
## sobald der Platz frei ist.
func _seat_bench_place(die: DieDefinition) -> void:
	_bench_die = die
	_rebuild_target_stage()
	_refresh_charging_column()

## Der EINE Abgleich: auf der Bühne steht, was das Fenster als Ziel meldet - und nur
## an der Werkstatt-Station. Idempotent und überspringt eine laufende Fahrt; jede
## fertige Fahrt gleicht erneut ab, wer also mitten in der Fahrt umwählt oder die
## Werkstatt verläßt, kehrt um, sobald sein Bein steht.
func _sync_bench_migration() -> void:
	if run == null or not _pool_standing or pool_tray_view == null or table_screen == null:
		return
	if _bench_riding:
		return
	var wanted := _wanted_bench_die()
	if wanted == _bench_die:
		return
	# Erst räumen, dann holen: es steht immer höchstens EINER auf der Bühne.
	if _bench_die != null:
		_ride_bench_to_pool(_bench_die)
		return
	_ride_bench_from_pool(wanted)

## Pool -> Bühne: der Würfel HEBT AB. Sein Sitz wird in demselben Bild leer, in dem
## der fliegende Körper an dessen Platz entsteht (nie zweimal gezeigt), und der
## Träger reist im TRAGE-BOGEN über den Tisch aufs Podest. Fire-and-forget.
func _ride_bench_from_pool(die: DieDefinition) -> void:
	if die == null:
		return
	# Fahrmarke SOFORT setzen - ein zweiter Trigger im selben Bild (Zielwahl UND
	# Kamerawechsel) sieht sie dann als fahrend und überspringt sie.
	_bench_riding = true
	var launched := run
	var generation := _bench_gen
	var workshop: WorkshopView = table_screen.workshop_window
	var bench_at := Vector3.ZERO
	if workshop != null and is_instance_valid(workshop) and workshop.bench_open():
		# Der Platz steht erst nach dem Layout des Fensters fest - zwei Bilder weit.
		await get_tree().process_frame
		await get_tree().process_frame
		if run != launched or generation != _bench_gen or not is_instance_valid(workshop) \
				or not _pool_standing or not workshop.bench_open():
			_bench_riding = false
			return
		bench_at = _bench_podium_target(workshop)
	# Der ABFLUG-Platz: der Sitz des Würfels im Pool - gerechnet, nie am Körper
	# gemessen. Ohne Sitz (er liegt gar nicht im Vorrat) startet er am Podest selbst.
	var seat := _pool_tray_source().find(die)
	var from := bench_at
	if seat >= 0 and pool_tray_view != null and seat < pool_tray_view.slot_roots.size():
		from = pool_tray_view.slot_home_position(seat, true)
	_seat_bench_place(die)  # ab jetzt LEER im Pool, er gehört dem Podest
	_refresh_deck_trays()  # der Schreiber bestätigt die Pool-Lücke
	if bench_at == Vector3.ZERO:
		# Kein Netz gemessen (Fenster noch ohne Layout): der Körper erscheint hart,
		# sobald es steht - _rebuild_bench_stage zeigt Ort == BÜHNE.
		_bench_riding = false
		_rebuild_bench_stage()
		_sync_bench_migration()  # wer derweil umwählte, kehrt um
		return
	var stage := _spawn_floating_die(die, CLAMP_EMITTER_TINT, from, CLAMP_HOVER)
	_free_stage(bench_stage)  # ein Rest der vorigen Wahl steht hier nie
	bench_stage = stage
	stage.set_process(false)  # kein Eigen-Wippen, solange der Bogen ihn führt
	var tween := stage.carry_to(bench_at, BENCH_CARRY_TIME, BENCH_CARRY_PEAK)
	if tween == null:
		stage.set_process(true)
		stage.land_at(bench_at, 0.0)
		stage.materialize()
		_bench_riding = false
		return
	tween.finished.connect(func() -> void:
		if is_instance_valid(stage):
			stage.set_process(true)
			if generation == _bench_gen and run == launched:
				stage.land_at(bench_at, 0.0)  # Feld rastet ein, dann wippt er
		_bench_riding = false
		if generation == _bench_gen and run == launched:
			_sync_bench_migration())  # wer derweil umwählte, kehrt um

## Der Ruhe-Punkt des Bühnen-Würfels: er wippt, sein Feld nicht - also mißt das Feld
## (Emitter plus Schwebehöhe). ZERO = kein Körper da.
func _bench_stage_rest() -> Vector3:
	if bench_stage == null or not is_instance_valid(bench_stage):
		return Vector3.ZERO
	return bench_stage.emitter.global_position + Vector3.UP * bench_stage.hover_height

## Bühne -> Pool: derselbe Bogen rückwärts. Der Träger fliegt über den Tisch auf
## den Sitz zurück, den er verlassen hat; erst bei der ANKUNFT fällt er weg und der
## Sitz zeigt wieder seinen Würfel. Ohne Körper (Bühne nie gelegt) entfällt der Flug.
func _ride_bench_to_pool(die: DieDefinition) -> void:
	if die == null:
		return
	_bench_riding = true
	var generation := _bench_gen
	var launched := run
	var stage := bench_stage
	var seat := _pool_tray_source().find(die)
	var flew := false
	if stage != null and is_instance_valid(stage) and _bench_stage_rest() != Vector3.ZERO \
			and seat >= 0 and pool_tray_view != null \
			and seat < pool_tray_view.slot_roots.size():
		stage.set_process(false)  # kein Eigen-Wippen, solange der Bogen ihn führt
		var tween := stage.carry_to(pool_tray_view.slot_home_position(seat, true),
			BENCH_CARRY_TIME, BENCH_CARRY_PEAK)
		if tween != null:
			flew = true
			tween.finished.connect(func() -> void:
				_finish_bench_sink(die, generation, launched))
	if not flew:
		_finish_bench_sink(die, generation, launched)

## Der Bogen ist ANGEKOMMEN: der Träger fällt weg und im selben Zug zeigt sein Sitz
## den Würfel wieder - kein Bild lang stehen beide da. Der Ort kippt auf POOL.
func _finish_bench_sink(die: DieDefinition, generation: int, launched: GameRun) -> void:
	_free_stage(bench_stage)
	bench_stage = null
	if generation != _bench_gen or run != launched:
		_bench_riding = false
		return
	_seat_bench_place(null)  # ab jetzt liegt er im Pool
	_seat_bench_pool_hard(_pool_tray_source().find(die))
	_refresh_deck_trays()
	_bench_riding = false
	_sync_bench_migration()

## Der Sitz steht wieder: an seinem Platz, spiegelnd, dem Schwebe-Takt zurückgegeben.
func _seat_bench_pool_hard(seat: int) -> void:
	if pool_tray_view == null or seat < 0 or seat >= pool_tray_view.slot_roots.size():
		return
	pool_tray_view.slot_roots[seat].global_position = \
		pool_tray_view.slot_home_position(seat, true)
	pool_tray_view.slot_emitter(seat).global_position = \
		pool_tray_view.slot_home_position(seat)
	pool_tray_view.set_slot_riding(seat, false)
	ScreenReflection.set_reflective(pool_tray_view.slot_roots[seat], true)
	ScreenReflection.set_reflective(pool_tray_view.slot_emitter(seat), true)

## Bühne -> Pool HART: das Zurren der Runde (Sicherheitsnetz - normal ist der Würfel
## längst zurückgefahren, der Spieler steht ja an der Grube) und jeder Abbruch.
## Endzustand zuerst - er gehört wieder dem Pool (sein Sitz füllt sich, der Träger
## nimmt ihn gleich mit hinab, siehe _sink_pool_tray). Jede laufende Fahrt wird hart
## beendet.
func _migrate_bench_to_pool() -> void:
	_reset_bench_migration_hard()
	# Der Bühnen-Körper tritt ab: off-screen (Kamera an der Grube), also hart frei
	# statt Fade - der Pool-Körper (Tray-Slot) übernimmt sofort wieder.
	_free_stage(bench_stage)
	bench_stage = null
	_seat_bench_place(null)

## Der EINE harte Aufräum-Pfad der Fahrt: ein abgebrochener Bogen steht sofort auf
## seinem Ziel (Endzustand zuerst - er schuldet nichts), jeder ridende Pool-Sitz
## liegt hart auf seinem Platz (ein Körper unter dem Tisch ist der schlimmste Rest
## - der Bogen legt keinen mehr dorthin, andere Fahrten schon), die Fahrmarke ist
## gelöscht. Reset, Laufwechsel und Abbruch gehen durch ihn. Er läßt den
## Ort-Zustand (_bench_die) unberührt - der ist Sache von _migrate_bench_to_pool.
func _reset_bench_migration_hard() -> void:
	_bench_gen += 1
	if bench_stage != null and is_instance_valid(bench_stage) and bench_stage.is_flying():
		bench_stage.land_at(_bench_stage_rest(), 0.0)
		bench_stage.set_process(true)
	if pool_tray_view != null:
		for i in pool_tray_view.slot_roots.size():
			if i < pool_tray_view.slot_riding.size() and pool_tray_view.slot_riding[i]:
				pool_tray_view.slot_roots[i].global_position = \
					pool_tray_view.slot_home_position(i, true)
				pool_tray_view.slot_emitter(i).global_position = \
					pool_tray_view.slot_home_position(i)
				pool_tray_view.set_slot_riding(i, false)
			# Die Fahrt-Marke der Spiegelung zurückgeben - nur solange der Vorrat
			# STEHT (der versenkte Träger spiegelt als Ganzes nicht).
			if _pool_standing:
				ScreenReflection.set_reflective(pool_tray_view.slot_roots[i], true)
				ScreenReflection.set_reflective(pool_tray_view.slot_emitter(i), true)
	_bench_riding = false

## Das Loch an einem Pool-Sitz: das Sitz-Feld, gegen Nachbar-Berührung zugeschnitten
## (die Schwarzmarkt-Regel - Wand plus Fuge weichen auf beiden Achsen zurück).
func _bench_pool_field(seat: int) -> Dictionary:
	var field := _tray_span_field(pool_tray_view, [seat])
	if field.is_empty():
		return {}
	var cut := LiftShaftView.WALL + 0.06
	var h: Vector2 = (field["half"] as Vector2) - Vector2(cut, cut)
	field["half"] = Vector2(maxf(h.x, 0.05), maxf(h.y, 0.05))
	return field

## Zieht die Augenzahlen des Bühnen-Würfels nach (geteilte Instanzen: eine
## Projektion ändert den Würfel, nicht seinen Platz). WÄHREND einer Zeremonie hält
## das Fenster den Stand VOR dem Griff - erst der Scanner deckt die neuen auf.
func _refresh_bench_stage_faces() -> void:
	if bench_stage == null or not is_instance_valid(bench_stage) or bench_stage.def == null:
		return
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop != null and is_instance_valid(workshop):
		var held := workshop.held_faces()
		if held != null:
			bench_stage.show_faces(held)
			return
	bench_stage.apply_definition(bench_stage.def)

# --- Die Datenzellen der Werkbank ------------------------------------------------
# Ein versiegeltes Paket ist ein DING: es liegt als Kassette auf dem Glas, im
# Regal als Stapel und in der Bucht als eingesetztes Stück. Die Körper gehören
# scene_root wie die Zwingen, ihre PLÄTZE nennt das Fenster (stack_anchor_px,
# press_slot_anchors). Sie tragen keine Kollision: geklickt wird der leere Knopf
# unter ihnen, es gibt keinen zweiten Trefferweg.

## Der EINE idempotente Schreiber: Regal-Stapel und Bucht-Zellen. Er läuft nach
## jedem Neuaufbau des Fensters - die Plätze stehen erst nach dessen Layout fest,
## daher das gewartete Bild.
func _sync_data_cells() -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop) or run == null:
		_drop_data_cells()
		return
	_sync_pack_pit(workshop)
	_sync_tower_pit(workshop)
	_sync_paternoster(workshop)
	_data_cell_gen += 1
	var generation := _data_cell_gen
	var launched := run
	# Zwei Bilder wie bei den Zwingen-Bühnen: nach einem Neuaufbau der Leiste
	# steht ihr Layout erst im zweiten - eine Messung im ersten liefert die Ecke.
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _data_cell_gen or run != launched or not is_instance_valid(workshop):
		return
	_sync_tower(workshop)  # der Turm steht, BEVOR eine Karte in ihm liegt
	_sync_shelf_cells(workshop)
	_sync_socket_cells(workshop)
	_flush_cell_pops()

## DER TURM: sechs Etagen als EIN Körper, gestellt an dem gemeldeten Rechteck des
## Fensters. Er steht auf dem BODEN der gemeinsamen Grube (Welle Y) - so ragt keine
## Karte je über die Tischkante. Idempotent, HART - er ist Möbel, keine Fahrt.
func _sync_tower(workshop: WorkshopView) -> void:
	var rect := workshop.tower_rect()
	if rect.size.x <= 0.0 or table_screen == null:
		_drop_tower()
		return
	if tower == null or not is_instance_valid(tower):
		tower = TowerView.new()
		add_child(tower)
	var origin := workshop.get_global_rect().position
	var seat := _data_cell_seat(origin + rect.get_center())
	seat.y -= _pit_floor_drop()
	tower.seat(seat, _world_span(rect.size), workshop.step_count())

## Ein Display-Rechteck in WELT-Spannen: x quer (Bild-hoch), y längs (Bild-breit).
func _world_span(px: Vector2) -> Vector2:
	var origin := table_screen.pixel_to_world(Vector2.ZERO)
	var span := table_screen.pixel_to_world(px) - origin
	return Vector2(absf(span.x), absf(span.z))

func _drop_tower() -> void:
	if tower == null:
		return
	_drop_light_net()  # das Netz reitet auf seinem Licht
	if is_instance_valid(tower):
		remove_child(tower)
		tower.queue_free()
	tower = null

## Die Grube unter dem Magazin: das Loch im Glas, der ausgeblendete Filz darunter
## und der Körper, den man hindurch sieht. Idempotent - dieselben Maße schreiben
## dasselbe. Die TIEFE ist das Liegemaß einer Kassette plus Luft: die Grube ist
## flach, gerade tief genug, dass nichts über ihren Rand ragt.
func _sync_pack_pit(workshop: WorkshopView) -> void:
	if table_screen == null:
		return
	var rect := workshop.shelf_pit_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	# Der DECKEL des Magazins wird an DIESER Grube gemessen: so viele Kassetten
	# liegen darin in voller Größe. Er geht in den Lauf, weil dort Kauf und Prämie
	# entschieden werden - core misst keine Fenster.
	_pack_columns = PackDrawerView.columns_for(rect.size, workshop.shelf_cell_px(), 1)
	_pack_capacity = _pack_columns * GameRun.PACK_ROWS
	if run != null:
		run.set_pack_grid(_pack_columns)
	table_screen.set_apron_pit(rect, workshop.shelf_pit_radius())
	var centre := table_screen.pixel_to_world(rect.get_center())
	if pack_pit == null or not is_instance_valid(pack_pit):
		pack_pit = PackPitView.new()
		pack_pit.wall_skin = PIT_SKIN
		add_child(pack_pit)
	# Die Wand zur BUCHT (Bild-oben = Welt +X) bekommt ihren DURCHBRUCH: Versatz und
	# Breite in Welt-Z, gemessen an der gemeldeten Bucht.
	var bay := workshop.tower_pit_rect()
	var gap := Vector2.ZERO
	# Und das Magazin trägt den EINEN Boden der ganzen L-Fläche: er reicht durch den
	# Durchbruch bis an die Rückwand der Bucht (Welle Z).
	var plate := _pit_world_rect(rect)
	if bay.size.x > 0.0:
		var bay_world := _pit_world_rect(bay)
		gap = Vector2(bay_world.get_center().y - centre.z, bay_world.size.y)
		plate = plate.merge(bay_world)
	pack_pit.floor_area = plate
	pack_pit.setup(centre, _pit_half(rect), _pack_pit_depth(),
		PackPitView.WALL_X_PLUS, gap)

## Die TURM-BUCHT: dasselbe Loch-Rezept, nur zum Magazin hin OFFEN. Sie ist der
## zweite Eintrag der Löcherliste; die beiden Rechtecke ergeben zusammen ein L.
func _sync_tower_pit(workshop: WorkshopView) -> void:
	if table_screen == null:
		return
	var rect := workshop.tower_pit_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	# Das LOCH greift um seinen Eckenradius in das Magazin hinein: rundeten seine
	# unteren Ecken auf der Nahtlinie, stünde dort je ein Splitter Glas im Rachen.
	var radius := workshop.tower_pit_radius()
	var cut := rect
	cut.size.y += radius
	table_screen.set_pit(TableScreen.PIT_TOWER, cut, radius)
	if tower_pit == null or not is_instance_valid(tower_pit):
		tower_pit = PackPitView.new("TowerPit")
		tower_pit.wall_skin = PIT_SKIN
		add_child(tower_pit)
	tower_pit.build_floor = false  # der Boden gehört dem Magazin - es ist EINER
	tower_pit.setup(table_screen.pixel_to_world(rect.get_center()), _pit_half(rect),
		_pack_pit_depth(), PackPitView.WALL_X_MINUS)

## DER PATERNOSTER: die zehn Tabletts in der Magazin-Grube, zwei davon in der
## Fläche. Möbel, idempotent - die FAHRT gehört dem Hebel, dieser Abgleich stellt
## nur und schreibt die Sorten-Ticks der Front-Blenden nach.
func _sync_paternoster(workshop: WorkshopView) -> void:
	if table_screen == null:
		return
	var rect := workshop.shelf_pit_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if paternoster == null or not is_instance_valid(paternoster):
		paternoster = PaternosterView.new()
		add_child(paternoster)
	paternoster.setup(table_screen.pixel_to_world(rect.get_center()),
		_world_span(rect.size), workshop.shelf_cell_scale(), _shelf_lanes(rect))
	# Nur ein echter Wechsel setzt hart: sonst risse dieser Abgleich jede laufende
	# Fahrt ab (die schreibt ihren Endzustand ohnehin sofort ins Fenster).
	if paternoster.head() != workshop.shelf_head:
		paternoster.set_head(workshop.shelf_head)
	for line in PackDrawerView.ROWS:
		paternoster.set_ticks(line, workshop.shelf_row_tints(line))

## Die LANE-Geometrie der Grube in WELT: je Lane ihre Mitte (Welt-X, relativ zur
## Grubenmitte) und ihre Tiefe. Das FENSTER meldet die Rechtecke in Display-Pixeln
## (Spalt und Fußluft stecken darin), scene_root rechnet sie um - ui/ faßt keine
## Körper an. Bild-unten ist Welt -X, also kehrt sich die Richtung um.
func _shelf_lanes(rect: Rect2) -> Array[Vector2]:
	var lanes: Array[Vector2] = []
	if rect.size.y <= 0.0:
		return lanes
	var span := _world_span(rect.size)
	var k := span.x / rect.size.y
	for lane_rect in PackDrawerView.lane_rects(rect.size):
		lanes.append(Vector2((rect.size.y * 0.5 - lane_rect.get_center().y) * k,
			lane_rect.size.y * k))
	return lanes

## Die halbe Welt-Ausdehnung eines Display-Rechtecks (x quer, y längs).
func _pit_half(rect: Rect2) -> Vector2:
	var a := table_screen.pixel_to_world(rect.position)
	var b := table_screen.pixel_to_world(rect.end)
	return Vector2(absf(a.x - b.x), absf(a.z - b.z)) * 0.5

## Dasselbe als WELT-XZ-Rechteck (x = Welt-X, y = Welt-Z), Ecke auf dem Kleinsten.
func _pit_world_rect(rect: Rect2) -> Rect2:
	var a := table_screen.pixel_to_world(rect.position)
	var b := table_screen.pixel_to_world(rect.end)
	var lo := Vector2(minf(a.x, b.x), minf(a.z, b.z))
	return Rect2(lo, Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) - lo)

## Die Tiefe der GEMEINSAMEN Grube: die STANDHÖHE einer Kassette plus Luft - dort
## steht sie bis zur Kopfkante im Loch. Sie ist zugleich die Strecke, die eine
## ankommende Zelle steigt, und die Höhe, um die der Turm tiefer sitzt.
func _pack_pit_depth() -> float:
	return DataCellView.STAND_HEIGHT * PackDrawerView.CASSETTE_SCALE * PACK_PIT_DEPTH_ROOM

## Wie weit der BODEN der Grube unter dem Glas liegt - darauf steht der Turm.
func _pit_floor_drop() -> float:
	return _pack_pit_depth() + PackPitView.WALL_SINK

# --- Die EINE Ankunft des Magazins ------------------------------------------
# Wer auch immer liefert - Laden, Hub-Prämie, Charm, Nebenwette, Hinterzimmer -,
# die Landung ist derselbe Vorgang: das Licht endet auf dem reservierten Platz,
# und dort steigt die Kassette aus dem Grubenboden.

## Wohin ein Liefer-Licht fliegt: auf den ANKER seines reservierten Platzes. Das
## Fach antwortet auch, wenn es gerade nicht steht - dann gerechnet (anchor_in).
func _pack_arrival_px(workshop: WorkshopView, uid: int) -> Vector2:
	return workshop.pack_anchor_px(uid) if workshop != null else Vector2.ZERO

## Die Ankunft selbst: kurzes Blitzen am Platz, dann steigt die Zelle. Nichts wird
## hier gebucht - gebucht war längst, das hier ist die Bühne.
func _land_pack_in_magazine(workshop: WorkshopView, uid: int, tint: Color) -> void:
	if workshop == null or not is_instance_valid(workshop):
		return
	_rising_packs[uid] = true
	if not workshop.deliver_pack(uid):
		_rising_packs.erase(uid)  # war gar nicht unterwegs
		return
	if table_screen != null:
		table_screen.pack_arrival_flash(_pack_arrival_px(workshop, uid), tint)

## Ein Abbruch mitten in einer Zeremonie darf keine Kassette unter dem Grubenboden
## vergessen: was noch schwebt, kommt sofort an.
func _land_pending_packs(workshop: WorkshopView, uids: Array[int]) -> void:
	for uid in uids:
		_land_pack_in_magazine(workshop, uid, CasinoStyle.GOLD_INTENSE)

## Eine Lieferung von aussen (Hinterzimmer, Automat, Charm): Quelle und Flug
## bleiben, das Ziel ist der Magazin-Platz. Liefert die Flugzeit.
func _fly_pack_to_magazine(workshop: WorkshopView, uid: int, from_px: Vector2,
		tint: Color) -> float:
	if workshop == null or not is_instance_valid(workshop) or table_screen == null:
		return 0.0
	var launched := run
	workshop.expect_pack_delivery(uid)
	var travel := table_screen.pack_delivery_comet(from_px, tint,
		_pack_arrival_px(workshop, uid))
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		if run == launched:
			_land_pack_in_magazine(workshop, uid, tint))
	return travel

# --- Die Laden-Auslage ------------------------------------------------------
# Dieselbe Kette wie das Magazin: der Laden MELDET sein Rechteck, scene_root
# stellt die Ware darauf.

## Stellt die Auslage auf die Ladenseite. Wie beim Zellen-Abgleich zwei Bilder
## Geduld: das Rechteck steht erst, wenn die Seite ausgelegt ist. reveal deckt sie
## danach auf - erst messen, dann zeigen.
func _sync_shop_vitrine(reveal := false) -> void:
	if table_screen == null or charm_shop == null:
		return
	# Solange gebaut wird, bleibt die Auslage abgedeckt: sonst stünde sie halb
	# gestellt auf der Seite.
	_vitrine_building = true
	_vitrine_gen += 1
	var generation := _vitrine_gen
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _vitrine_gen or not is_instance_valid(charm_shop):
		return
	_place_shop_vitrine()
	await get_tree().process_frame
	if generation != _vitrine_gen or not is_instance_valid(charm_shop):
		return
	_sync_vitrine_stock()  # die Körper stehen, die Auslage ist noch abgedeckt
	await get_tree().process_frame
	if generation != _vitrine_gen or not is_instance_valid(charm_shop):
		return
	_vitrine_building = false
	if reveal:
		_sync_vitrine_curtain()
	# Erst aufdecken, dann die Ware: der aufgesparte Grad IST der Auftritt des
	# Aufdeckens. Abgedeckt bleibt es beim harten Stellen.
	var grade := ShopController.GRADE_STAND
	if _vitrine_curtain:
		grade = _vitrine_grade
		_vitrine_grade = ShopController.GRADE_STAND
	# Der MASCHINENZYKLUS: beide Zonen fahren ihn GLEICHZEITIG - die Gravuren-Reihe
	# und die Bucht starten und stehen im selben Augenblick.
	_write_slit_cells(grade)
	_sync_vitrine_stock(grade)

## Die Auslage auf das gemeldete Rechteck stellen. Idempotent - dieselben Maße
## schreiben dasselbe.
func _place_shop_vitrine() -> void:
	var rect := charm_shop.vitrine_pit_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if shop_vitrine == null or not is_instance_valid(shop_vitrine):
		shop_vitrine = VitrineView.new("ShopVitrine")
		add_child(shop_vitrine)
		# Die Netze folgen der Schale: sie kommen, wenn sie steht, und gehen, sobald
		# sich etwas rührt. GEMELDET, nicht je Bild erfragt.
		shop_vitrine.dice_settled.connect(_on_vitrine_dice_settled)
		shop_vitrine.dice_moving.connect(_clear_vitrine_nets)
		_wire_shafts(shop_vitrine,
			[TableScreen.PIT_SHOP_SLITS, TableScreen.PIT_SHOP_BOWL] as Array[int])
	# Die bündige Plattform IST die Anzeige: ihre Haut zeigt deren echtes Bild.
	shop_vitrine.deck_skin = table_screen.display_skin()
	shop_vitrine.wall_skin = PIT_SKIN
	_place_vitrine(shop_vitrine, rect, _vitrine_curtain)

## Eine Auslage auf ihr gemeldetes Rechteck stellen. Beide Vitrinen gehen durch
## dieselbe Hand - eine zweite Rechnung liefe auseinander.
func _place_vitrine(bay: VitrineView, rect: Rect2, shown: bool) -> void:
	var a := table_screen.pixel_to_world(rect.position)
	var b := table_screen.pixel_to_world(rect.end)
	var half := Vector2(absf(a.x - b.x), absf(a.z - b.z)) * 0.5
	bay.setup(table_screen.pixel_to_world(rect.get_center()), half)
	bay.set_shown(shown)

## Die SCHÄCHTE einer Auslage: sie meldet, wann eines ihrer Löcher auf- und
## zugeht, geschnitten wird es von TableScreen (eine View greift nicht in die
## Shader). slots ist die EXPLIZITE Zone→Platz-Liste; eine Zone ohne Platz wird
## still übergangen. Die Ladenbucht führt keine Regalware, ihre Regal-Zone bleibt
## also unbenutzt - deren Platz gehört der Schlitzreihe, die scene_root selbst fährt.
func _wire_shafts(bay: VitrineView, slots: Array[int]) -> void:
	bay.shaft_opened.connect(func(zone: int, at: Vector3, hole: Vector2) -> void:
		if table_screen != null and zone >= 0 and zone < slots.size():
			table_screen.set_lift_pit(slots[zone], at, hole))
	bay.shaft_closed.connect(func(zone: int) -> void:
		if table_screen != null and zone >= 0 and zone < slots.size():
			table_screen.clear_pit(slots[zone]))

## Der EINE Aufräum-Pfad für die Löcher: nach jedem Auftritt, jedem Vorhangfall und
## jedem Laufwechsel ist JEDER Schacht zu. Ein offen gebliebenes Loch wäre der
## schlimmste denkbare Rest - deshalb räumen alle Abbrüche hier durch.
func _close_lift_shafts() -> void:
	if shop_vitrine != null and is_instance_valid(shop_vitrine):
		shop_vitrine.close_shafts()
	if secret_vitrine != null and is_instance_valid(secret_vitrine):
		secret_vitrine.close_shafts()
	_settle_slit_shaft()
	_settle_bet_shafts()
	if table_screen != null:
		table_screen.clear_lift_pits()

## Liegt in der Ladenauslage überhaupt noch ein KÖRPER? Gezählt werden BEIDE Zonen
## zusammen, denn sie fahren zusammen: Bucht und Kassetten-Schlitzreihe. Gefragt wird
## im Vorhangfall - dort ist die Antwort noch wahr.
func _shop_bay_occupied() -> bool:
	if not slit_cells.is_empty():
		return true
	return shop_vitrine != null and is_instance_valid(shop_vitrine) \
		and shop_vitrine.body_count() > 0

## Der EINE Schreiber der Ladenseite: die Auslage steht oder ist gar nicht da.
func _set_vitrine_shown(shown: bool) -> void:
	if shop_vitrine != null and is_instance_valid(shop_vitrine):
		shop_vitrine.set_shown(shown)

## Aufgedeckt wird nach der SEITENREGEL des Hubs - und erst, wenn die Auslage
## fertig gebaut ist. Sichtbar nur, solange die Ladenseite die sichtbare Seite ist
## und der Laden offen hat.
## Der VORHANGFALL ist ZWEIGETEILT, und das ist die Regel: schließt der LADEN
## (Phasenwechsel - Fertig, Grubenausgang), schluckt die Maschine die Ware, und zwar
## auf der STEHENDEN Ladenseite - die gibt ihre Fläche erst danach ab; fällt der
## Vorhang aus jedem anderen Grund (Seite verdrängt durch Lexikon oder Titel,
## Vorbau, Laufwechsel), bleibt der harte Sofort-Weg - und derselbe harte Weg ist
## der ABBRUCH einer laufenden Zeremonie.
## Der EINE Entscheider; er merkt sich seinen Stand, damit ein Aufruf je Bild nichts
## umsonst schreibt, und die laufende Zeremonie hält ihn still.
func _sync_vitrine_curtain() -> void:
	if charm_shop == null or not is_instance_valid(charm_shop):
		return
	var want := not _vitrine_building and phase == Phase.SHOP and charm_shop.visible
	if _vitrine_leaving:
		# Der Abgang hält die Ladenseite stehen, bis die Ware hinaus ist. Ihn brechen
		# nur zwei Dinge ab: ein WIEDER-Aufdecken und eine fremde Seite, die die
		# Ladenseite verdrängt - dann stünde die Ware auf der falschen Anzeige.
		if not want and charm_shop.visible:
			return
		_hide_vitrine_hard()
		if not want:
			return
	elif want == _vitrine_curtain:
		return
	_vitrine_curtain = want
	if want:
		_set_vitrine_shown(true)
		_sync_vitrine_nets()
		return
	if phase == Phase.SHOP:
		_hide_vitrine_hard()  # nur VERDRÄNGT: sofort fort, gar nicht da
		return
	_play_vitrine_exit()  # der Laden schließt: die Maschine schluckt

## Der harte Sofort-Weg - und zugleich der ABBRUCH jeder Schluck-Zeremonie: jede
## Maschine still, jedes Loch zu, kein Körper mehr da (auch keiner, der noch
## hinausfuhr), und die Ladenseite gibt ihre Fläche ab. Der EINE Aufräum-Pfad des
## Vorhangs. fade: der Abgang ist wirklich durch, die Startseite darf weich
## zurückkommen - jeder Abbruch wechselt hart.
func _hide_vitrine_hard(fade := false) -> void:
	_vitrine_leaving = false
	_vitrine_exit += 1  # eine laufende Zeremonie stellt nichts mehr
	_set_vitrine_shown(false)
	_close_lift_shafts()  # keine Maschine bleibt mit offenem Loch stehen
	_close_shop_page(fade)
	_sync_slit_visibility()
	_drop_vitrine_nets()  # auch ein halb eingesogener Block ist sofort fort
	# Die PHYSISCHE Regel, gestellt im EINEN Augenblick, in dem sie zu stellen ist:
	# ist die Auslage jetzt körperlich LEER (der Abgang hat die Ware hinausgefahren),
	# schuldet das nächste Aufdecken eine ANKUNFT - was die Seite über ihr Liegen auch
	# glaubt. Eine bloß VERDRÄNGTE Auslage behält ihre Körper und bleibt liegen.
	# Später ist die Frage nicht mehr zu stellen: der Vorbau stellt hart nach.
	_vitrine_grade = ShopController.grade_on_stand(_vitrine_grade, _shop_bay_occupied())

## Die Ladenseite gibt ihre Fläche ab - erst hier greift die Seitenregel des Hubs
## und die Startseite kommt zurück. Ein Laden, der gar nicht abräumt, hat nichts
## abzugeben.
func _close_shop_page(fade: bool) -> void:
	if charm_shop == null or not is_instance_valid(charm_shop) or not charm_shop.leaving():
		return
	charm_shop.finish_close()
	var hub: HubView = table_screen.hub if table_screen != null else null
	if hub == null:
		return
	# Ein Laden, den eine fremde Seite eben verdrängt hat, schließt UNSICHTBAR - die
	# Seitenregel dürfte ihn danach nicht als totes Standbild zurückholen.
	hub.forget_page(charm_shop)
	if fade:
		hub.fade_current_in()  # die Startseite kommt weich zurück

## Die SCHLUCK-ZEREMONIE: der Laden schließt, und die Maschine zieht die Ware ein -
## senken mit der Ware, vorn hinaus, Platte LEER herauf, Loch zu. Davor werden die
## NETZ-BLÖCKE in ihre Würfel zurück ABSORBIERT: die Würfel stehen noch, wenn ihre
## Anzeige eingesogen wird, und ihr Vorlauf gehört BEIDEN Zonen, damit sie zusammen
## bleiben. Sie spielt auf der STEHENDEN Ladenseite: gebucht ist längst, Runde und
## Kamera laufen unbeirrt weiter, nur der SEITENWECHSEL wartet. Jede Verdeckung wie
## jeder Laufwechsel bricht sie hart ab.
func _play_vitrine_exit() -> void:
	_vitrine_exit += 1
	var token := _vitrine_exit
	var launched := run
	var lead := 0.0
	if charm_shop != null and is_instance_valid(charm_shop):
		lead = charm_shop.absorb_die_nets()
	var cap := 0.0
	if shop_vitrine != null and is_instance_valid(shop_vitrine):
		cap = shop_vitrine.exit_all(lead)
	cap = maxf(cap, _exit_slit_cells(lead))
	if cap <= 0.0:
		_hide_vitrine_hard()  # nichts zu schlucken: der Vorhang fällt sofort
		return
	_vitrine_leaving = true
	await get_tree().create_timer(cap).timeout
	if token != _vitrine_exit or run != launched:
		return
	_hide_vitrine_hard(true)

## Die Auslage des Ladens stellen. Der Laden fasst nie einen Körper an - er
## meldet, was liegt, und die Auslage stellt es nach (idempotent).
func _sync_vitrine_stock(grade := ShopController.GRADE_STAND) -> void:
	if shop_vitrine == null or not is_instance_valid(shop_vitrine) or charm_shop == null:
		return
	# Erst die Reserve, dann die Ware: die Auslage soll ihre Plätze gleich richtig
	# rechnen, statt sie hinterher noch einmal zu verschieben.
	shop_vitrine.label_reserve = _vitrine_label_reserve()
	shop_vitrine.present_graded(charm_shop.vitrine_stock(), grade)
	_sync_vitrine_nets()  # die Netze hängen an den Plätzen, die eben gestellt wurden

## Der Laden zeigt eine Seite. Bei ZUGEDECKTER Bucht wird lautlos umgebaut und der
## Grad fürs Aufdecken aufgehoben; bei offener ist das Blättern ein sichtbarer
## WARENUMSCHLAG.
func _on_vitrine_changed() -> void:
	if charm_shop == null or not is_instance_valid(charm_shop):
		return
	var grade := charm_shop.vitrine_grade()
	# Die Maschine schluckt gerade: nichts stellt jetzt um. Der Grad wird aufgehoben,
	# gestellt wird beim nächsten Aufdecken - der Laden liest seinen Bestand dann
	# ohnehin neu.
	if _vitrine_leaving:
		_vitrine_grade = ShopController.louder_grade(_vitrine_grade, grade)
		return
	if not _vitrine_curtain:
		_vitrine_grade = ShopController.louder_grade(_vitrine_grade, grade)
		_sync_vitrine_stock()
		_sync_shop_slit_cells()  # nicht erwartet
		return
	# Vor jedem Abräumen werden die Netz-Blöcke in ihre Würfel eingesogen, und ERST
	# DANACH fährt die Maschine. Der Vorlauf ist EINER für beide Zonen.
	var lead := 0.0
	if grade == ShopController.GRADE_RISE:
		lead = charm_shop.absorb_die_nets()  # 0, wenn kein Netz steht
	_swap_vitrine_stock(grade, lead)
	_swap_slit_cells(grade, lead)  # beide Zonen blättern dieselbe Seite

## Die Schlitze blättern mit: bei einem Seitenwechsel fährt die Reihe den
## BAND-SCHRITT - die alten Kassetten vorn hinaus, die neuen von hinten nach. Ein
## Kauf lässt der harte Schreiber allein laufen (die verkaufte Kassette sinkt, die
## anderen bleiben stehen).
func _swap_slit_cells(grade: String, lead := 0.0) -> void:
	if grade == ShopController.GRADE_STAND:
		_sync_shop_slit_cells()  # nicht erwartet
		return
	_write_slit_cells(ShopController.GRADE_RISE, true, lead)

## Der Umschlag: EIN Förderband-Schritt der Maschine - die alte Ware geht vorn
## hinaus, während die neue von hinten nachrückt. Gebucht hat der Laden längst, das
## hier ist reine Bühne; ein Laufwechsel oder ein zweites Blättern räumt sie ab.
func _swap_vitrine_stock(grade: String, lead := 0.0) -> void:
	if shop_vitrine == null or not is_instance_valid(shop_vitrine) or charm_shop == null:
		return
	if grade == ShopController.GRADE_STAND:
		_sync_vitrine_stock()  # Kauf, Tausch, Sperre: dieselbe Seite bleibt liegen
		return
	_vitrine_swap += 1
	shop_vitrine.label_reserve = _vitrine_label_reserve()
	shop_vitrine.swap_to(charm_shop.vitrine_stock(), lead)
	_sync_vitrine_nets()  # die Netze hängen an den Plätzen, die eben gestellt wurden

# --- Die Kassetten-Schlitze der Ladenseite -------------------------------------
# Versiegelte Ware liegt nicht mehr in der Bucht: sie STECKT im Tisch, gleich
# unter der Charm-Zeile, in derselben Leser-Grammatik wie an der Werkbank. Der
# Laden schneidet die Kerbe und nennt ihre Mitte; die Körper gehören scene_root.
# Sie tragen keine Kollision - geklickt wird der leere Knopf unter ihnen.

## Der Anstoß: zwei Bilder Geduld wie beim Zellen-Abgleich, denn die Kerben haben
## erst nach dem Layout der Seite ein Rechteck.
func _sync_shop_slit_cells() -> void:
	if table_screen == null or charm_shop == null or not is_instance_valid(charm_shop):
		_drop_slit_cells()
		return
	_slit_gen += 1
	var generation := _slit_gen
	var launched := run
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _slit_gen or run != launched or not is_instance_valid(charm_shop):
		return
	_write_slit_cells()

## Der EINE idempotente Schreiber: was steht, bleibt derselbe Körper; was fehlt,
## STEIGT aus seiner Kerbe; was verkauft ist, sinkt ganz in den Tisch. Im Grad
## GRADE_RISE fährt die GANZE Reihe als Block die Hebebühne - auch, was schon
## steht, denn das Aufdecken ist der Auftritt der ganzen Zone.
func _write_slit_cells(grade := ShopController.GRADE_STAND, swap := false,
		lead := 0.0) -> void:
	if charm_shop == null or not is_instance_valid(charm_shop) or table_screen == null:
		return
	if _vitrine_leaving:
		return  # die Maschine schluckt: der Abgleich stellt nichts nach
	# Eine eben gebaute Stellplatz-Reihe (Hub-Aufstieg im offenen Laden) hat noch
	# kein Rechteck: gemessen wird, WENN ES SOWEIT IST - sonst lägen alle Anker
	# aufeinander und die ganze Reihe stapelte sich auf dem linkesten Platz.
	if not charm_shop.slit_row_laid_out():
		_write_slit_cells_when_laid(grade, swap, lead)  # nicht erwartet
		return
	# Jeder Schreiber räumt zuerst: Loch zu, Abgangsware frei. NACH dem Räumen darf
	# die stehende Reihe hinausfahren - sonst gäbe der Aufräum-Pfad sie gleich frei.
	_settle_slit_shaft()
	var outgoing: Array = []
	if swap:
		outgoing = _detach_slit_cells()
	var stock := charm_shop.slit_stock()
	var anchors := charm_shop.slit_anchors()
	var show := _slit_cells_visible()
	var wanted: Dictionary = {}
	for i in mini(stock.size(), anchors.size()):
		var pack: Pack = stock[i]
		if pack != null:
			wanted[i] = pack
	var rising := grade == ShopController.GRADE_RISE
	# Verkauft: die SEKTION des Stellplatzes fährt ihren eigenen Zyklus - es sei
	# denn, in diesem Zug fährt schon die ganze Reihe, dann ist die Karte schlicht
	# fort. Zwei Maschinen teilen sich kein Loch.
	# Und je Zug nur EINE Sektion: die Reihe hat den einen Schacht, umgeschnitten auf
	# einen Platz - ein zweiter Schnitt risse dem ersten die Plattform weg.
	var section := not (rising or swap)
	for seat: int in slit_cells.keys():
		var kept: Pack = wanted.get(seat)
		if kept == null or int(_slit_keys.get(seat, 0)) != kept.get_instance_id():
			if _take_slit_cell(seat, anchors, section):
				section = false
	# Steigt die Reihe, fährt sie als EIN Block die Hebebühne - gesammelt wird
	# zuerst, gefahren danach.
	var lift: Array = []
	for seat: int in wanted.keys():
		var pack: Pack = wanted[seat]
		var target := _data_cell_seat(anchors[seat])
		var cell: DataCellView = slit_cells.get(seat)
		if cell == null or not is_instance_valid(cell):
			cell = _spawn_data_cell(Pack.shelf_of(pack), pack.tier, target, pack.stamp_net)
			slit_cells[seat] = cell
			_slit_keys[seat] = pack.get_instance_id()
			cell.set_count(maxi(pack.count, 1))
			cell.visible = show
			if rising:
				_lay_slit_cell(cell, target)
				lift.append({"cell": cell, "target": target})
			else:
				_lay_fresh_slit_cell(cell, target)
			continue
		cell.set_count(maxi(pack.count, 1))
		if rising:
			_lay_slit_cell(cell, target)
			lift.append({"cell": cell, "target": target})
		elif not cell.busy():
			_lay_slit_cell(cell, target)
		cell.visible = show
	_run_slit_machine(lift if rising else [], outgoing, lead if swap else 0.0)

## Nachgesetzt, sobald die Reihe ausgelegt ist - die Zwei-Bilder-Geduld des
## Zellen-Abgleichs. Generations-Marke wie überall: ein neuerer Abgleich entwertet
## den wartenden, ein Laufwechsel ebenso.
func _write_slit_cells_when_laid(grade: String, swap: bool, lead: float) -> void:
	_slit_gen += 1
	var generation := _slit_gen
	var launched := run
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _slit_gen or run != launched or charm_shop == null \
			or not is_instance_valid(charm_shop) or not charm_shop.slit_row_laid_out():
		return
	_write_slit_cells(grade, swap, lead)

## Die Kassette LIEGT auf ihrem Stellplatz - flach, die große Fläche nach oben,
## ihre ×n-Marke auf der Karte statt daneben (im Nachbarplatz läge sie sonst).
func _lay_slit_cell(cell: DataCellView, target: Vector3) -> void:
	cell.badge_on_face = true
	cell.set_body_scale(PackDrawerView.CASSETTE_SCALE)
	cell.lie_on_glass(target)

## Ohne Ankunfts-Grad LIEGT eine frische Kassette schlicht da - dieselbe Geste, mit
## der auch die Bucht eine neue Zelle hinstellt (materialize, ihr eigenes
## Entstehen). Gefahren wird nur in einer ZEREMONIE, und die kennt keine Körperart.
func _lay_fresh_slit_cell(cell: DataCellView, target: Vector3) -> void:
	_lay_slit_cell(cell, target)
	cell.materialize()

## Die HEBEBÜHNE der Gravuren-Zone: dieselbe Maschine wie in einer Bucht, dieselben
## drei Fahrpläne. Kommt Ware und geht welche, ist es der BAND-SCHRITT; kommt nur
## welche, das Aufdecken; geht nur welche, der Abgang. Sie fährt GLEICHZEITIG mit
## der Bucht - denselben Vorlauf, dieselbe Fahrt.
func _run_slit_machine(entries: Array, outgoing: Array, delay := 0.0) -> void:
	var old_bodies: Array = []
	var old_seats: Array = []
	for entry: Dictionary in outgoing:
		old_bodies.append(entry["cell"])
		old_seats.append(entry["target"])
	if (entries.is_empty() and outgoing.is_empty()) or table_screen == null:
		_release_slit_bodies(old_bodies)
		return
	if _slit_shaft_on(_slit_shaft_rect()) == null:
		_release_slit_bodies(old_bodies)
		return  # ohne gemessene Spur bleibt es beim harten Stand
	var bodies: Array = []
	var seats: Array = []
	for entry: Dictionary in entries:
		bodies.append(entry["cell"])
		seats.append(entry["target"])
	var swap := not old_bodies.is_empty()
	var swept := _release_slit_bodies.bind(old_bodies)
	var tween: Tween
	if not swap:
		tween = slit_shaft.run_cycle(bodies, seats, delay)
	elif bodies.is_empty():
		tween = slit_shaft.run_exit(old_bodies, old_seats, delay, swept)
	else:
		tween = slit_shaft.run_swap(old_bodies, old_seats, bodies, seats, delay, swept)
	if tween == null:
		_release_slit_bodies(old_bodies)
		return
	tween.tween_callback(func() -> void:
		for cell: DataCellView in bodies:
			if is_instance_valid(cell):
				cell.flare())

## Der EINE Schachtkörper der Reihe, auf ein gemeldetes Display-Rechteck gestellt
## (null = keine Spur). Auftritt, Umschlag, Abgang und Kauf-Sektion teilen ihn -
## und damit auch den Platz seines Loches in der Anzeige.
func _slit_shaft_on(field: Rect2) -> LiftShaftView:
	if table_screen == null or field.size.x <= 0.0 or field.size.y <= 0.0:
		return null
	var a := table_screen.pixel_to_world(field.position)
	var b := table_screen.pixel_to_world(field.end)
	if slit_shaft == null or not is_instance_valid(slit_shaft):
		slit_shaft = LiftShaftView.new("SlitShaft")
		add_child(slit_shaft)
		slit_shaft.opened.connect(func(at: Vector3, hole: Vector2) -> void:
			table_screen.set_lift_pit(TableScreen.PIT_SHOP_SLITS, at, hole))
		slit_shaft.closed.connect(func() -> void:
			table_screen.clear_pit(TableScreen.PIT_SHOP_SLITS))
	slit_shaft.deck_skin = table_screen.display_skin()
	slit_shaft.order_skin(PIT_SKIN)
	slit_shaft.setup(table_screen.pixel_to_world(field.get_center()),
		Vector2(absf(a.x - b.x), absf(a.z - b.z)) * 0.5, VitrineView.shaft_depth())
	return slit_shaft

## Die SPUR der Reihe: die Stellplätze selbst, nichts daneben. Die Preisschilder
## hängen UNTER den Plätzen und bleiben außerhalb - ein Loch unter dem Preis fräße
## die Zahl.
func _slit_shaft_rect() -> Rect2:
	if charm_shop == null or not is_instance_valid(charm_shop):
		return Rect2()
	var field := Rect2()
	for rect: Rect2 in charm_shop.slit_rects():
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		field = rect if field.size.x <= 0.0 else field.merge(rect)
	return field

## Der Abbruch der Reihen-Maschine: Platte bündig, Schacht fort, Loch zu - und was
## hinausfuhr, ist frei. Teil des EINEN Aufräum-Pfades; die Kassetten legt der harte
## Schreiber selbst nach. Die zwei denkbaren Reste (offenes Loch, verwaiste
## Abgangs-Kassette) sterben hier zusammen.
func _settle_slit_shaft() -> void:
	if slit_shaft != null and is_instance_valid(slit_shaft):
		slit_shaft.settle_hard()
	_release_slit_bodies(_slit_leaving.duplicate())

## Die stehende Reihe verläßt ihre Plätze: ihre Zellen fahren nur noch hinaus, der
## Abgleich findet sie nicht mehr. Freigegeben werden sie am Ende des Band-Schritts -
## oder bei jedem Abbruch.
func _detach_slit_cells() -> Array:
	var out: Array = []
	var anchors := charm_shop.slit_anchors()
	for seat: int in slit_cells:
		var cell: DataCellView = slit_cells[seat]
		if cell == null or not is_instance_valid(cell) or seat >= anchors.size():
			continue
		cell.set_hovered(false)  # der Griff sitzt am Körper, nicht am Ort
		out.append({"cell": cell, "target": _data_cell_seat(anchors[seat])})
		_slit_leaving.append(cell)
	slit_cells.clear()
	_slit_keys.clear()
	charm_shop.set_slit_hover(-1)
	return out

func _release_slit_bodies(bodies: Array) -> void:
	for cell: DataCellView in bodies:
		_slit_leaving.erase(cell)
		_free_data_cell(cell)

## Der ABGANG der Reihe: sie geht mit der Bucht, dieselbe Maschine, derselbe Takt -
## samt dem gemeinsamen Vorlauf der Absorption.
func _exit_slit_cells(lead := 0.0) -> float:
	if slit_cells.is_empty():
		return 0.0
	_slit_gen += 1  # ein schwebender Abgleich stellt nichts mehr nach
	_settle_slit_shaft()
	var outgoing := _detach_slit_cells()
	_run_slit_machine([], outgoing, lead)
	return VitrineView.exit_time(outgoing.size(), lead)

## Verkauft: die SEKTION unter dem Stellplatz fährt ihren Zyklus - sie senkt sich
## MIT der Karte, die fährt durch die HINTERE Öffnung ab (Richtung Werkbank), die
## leere Sektion hebt sich bündig und das Loch ist zu. Derselbe Takt wie in der
## Bucht, denn es ist dieselbe Maschine. section = false heißt: die ganze Reihe
## fährt in diesem Zug ohnehin, die Karte ist schlicht fort. Meldet, ob wirklich
## eine Sektion losgefahren ist - es gibt nur die eine.
func _take_slit_cell(seat: int, anchors: Array[Vector2], section: bool) -> bool:
	var cell: DataCellView = slit_cells.get(seat)
	slit_cells.erase(seat)
	_slit_keys.erase(seat)
	if cell == null or not is_instance_valid(cell):
		return false
	var shaft := _slit_section_shaft(seat) if section else null
	if shaft == null or seat >= anchors.size():
		_free_data_cell(cell)
		return false
	cell.set_hovered(false)  # der Griff sitzt am Körper, nicht am Ort
	var target := _data_cell_seat(anchors[seat])
	cell.lie_on_glass(target)
	_slit_leaving.append(cell)
	if shaft.run_take([cell], [target], 0.0,
			_release_slit_bodies.bind([cell])) == null:
		_release_slit_bodies([cell])
		return false
	return true

## Der SEKTIONS-Schacht EINES Stellplatzes: derselbe Schacht der Reihe, nur auf
## seine eigene Kerbe geschnitten.
func _slit_section_shaft(seat: int) -> LiftShaftView:
	if charm_shop == null or not is_instance_valid(charm_shop):
		return null
	var rects := charm_shop.slit_rects()
	if seat < 0 or seat >= rects.size():
		return null
	return _slit_shaft_on(rects[seat])

## Die Körper der Ladenseite stehen nur, solange sie wirklich zu sehen ist -
## derselbe Entscheider wie der Vorhang der Bucht. Kassetten UND Charm-Modelle
## hängen daran: eine verdrängte Seite läßt nichts auf dem Tisch zurück. Die
## SCHLUCK-ZEREMONIE hält sie sichtbar, bis sie hinaus sind: sie ist der Abgang,
## nicht das Abdecken.
func _slit_cells_visible() -> bool:
	if _vitrine_leaving:
		return true
	return charm_shop != null and is_instance_valid(charm_shop) \
		and phase == Phase.SHOP and charm_shop.visible

func _sync_slit_visibility() -> void:
	var show := _slit_cells_visible()
	for seat: int in slit_cells:
		var cell: DataCellView = slit_cells[seat]
		if cell != null and is_instance_valid(cell) and cell.visible != show:
			cell.visible = show

## Der Griff auf einen Stellplatz: die liegende Kassette hebt sich an und leuchtet
## auf - dieselbe Geste wie im Magazin -, und in der freien RECHTEN Flanke der
## Reihe steht, was in ihr steckt (Name und Beschreibung). GEFRAGT je Bild (der
## Zeiger liegt auf dem Tisch), EIN Walker für Griff und Auskunft.
func _sync_slit_hover() -> void:
	if charm_shop == null or not is_instance_valid(charm_shop):
		return
	var pixel := Vector2(-1, -1)
	if _slit_cells_visible() and _table_operable():
		pixel = _screen_pixel(get_viewport().get_mouse_position())
	var rects := charm_shop.slit_rects()
	var hovered := -1
	for seat: int in slit_cells:
		var cell: DataCellView = slit_cells[seat]
		if cell == null or not is_instance_valid(cell):
			continue
		var on := pixel.x >= 0.0 and seat < rects.size() and rects[seat].has_point(pixel)
		cell.set_hovered(on)
		if on and hovered < 0:
			hovered = seat
	# Dieselbe Zell-Auskunft wie in der Werkstatt: liegt der Zeiger auf einer Zelle
	# des Prägenetzes, nennt die Flanke DEREN Wirkung statt der des ganzen Pakets.
	var cell_hint := ""
	if hovered >= 0:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			cell_hint = _cell_face_hint(slit_cells.get(hovered), camera,
				get_viewport().get_mouse_position())
	charm_shop.set_slit_hover(hovered, cell_hint)

## Laufwechsel: die Ware des alten Ladens liegt nirgends mehr.
func _drop_slit_cells() -> void:
	for seat: int in slit_cells:
		_free_data_cell(slit_cells[seat])
	slit_cells.clear()
	_slit_keys.clear()
	_settle_slit_shaft()  # auch, was noch hinausfuhr, gehört dem alten Laden

#region Der WURF
# Das Bewegungs-Gesetz liest sich nach URHEBER: was der SPIELER ZAHLT, fliegt als
# KÖRPER im ballistischen Bogen über den Filz - vom echten Zuhause der Ressource zum
# Ziel. (Was der TISCH liefert, reist als Licht über die gelegten Adern; was er
# präsentiert oder einzieht, fährt per Hebebühne - die bleibt dem Haus.)
# EINE Zeremonie für alle Zahlungen: sie bekommt fertige Körper samt Weg, staffelt
# sie zur Salve und meldet die Laufzeit. Die Körper gehören scene_root und sind reine
# Zeremonie - keine Buchung hängt an einem von ihnen, die Quelle rendert längst OHNE
# das geworfene Stück, und JEDER Abbruch läuft durch _settle_throws.

## Ein Wurf dauert eine halbe Sekunde; eine Salve staffelt sich um THROW_STAGGER.
const THROW_TIME := 0.5
const THROW_STAGGER := 0.06
## Scheitelhöhe des Bogens als Anteil der Wurfweite, gedeckelt - über den halben
## Tisch fliegt nichts in den Himmel.
const THROW_ARC_SHARE := 0.22
const THROW_ARC_MIN := 1.4
const THROW_ARC_MAX := 7.0
## Das SETZEN bei der Landung: das Stück federt kurz nach.
const THROW_SET := 0.35
const THROW_SET_TIME := 0.1
## Ein geworfenes Stück trudelt - und landet FLACH: das Trudeln endet auf GANZEN
## Umdrehungen je Achse, also genau in der Lage, in der das Stück gebaut wurde.
## Nichts bleibt schief im Glas stecken.
const THROW_SPIN := Vector3(TAU, TAU, TAU)
## Mehr Stücke wirft niemand: eine Salve ist eine Geste, keine Energie.
const THROW_SALVO_CAP := 8
## Wie weit eine Salve um ihren Platz streut - ein Haufen, kein Turm. Geld streut
## NICHT: es stapelt (throw_stack_lift).
const THROW_SCATTER := ChipStackView.CHIP_RADIUS * 1.5

## Was gerade FLIEGT, und die Fahrten dazu - der eine Aufräum-Pfad räumt beides.
var _thrown: Array[Node3D] = []
var _throw_tweens: Array[Tween] = []

## Die EINE Wurf-Zeremonie. entries sind {body, from, to} in Weltmaßen und fliegen
## der Reihe nach gestaffelt los; on_land feuert, wenn das LETZTE Stück liegt, und
## erst danach räumt die Zeremonie ihre Flugkörper ab. Liefert die Gesamtlaufzeit.
## hand_over: die gelandeten Körper gehören danach dem Aufrufer (er bekommt sie in
## on_land gereicht) - so kann die Hebebühne genau die Stücke einsenken, die eben
## gelandet sind, statt sie zu ersetzen.
func _throw_bodies(entries: Array, on_land := Callable(),
		hand_over := false) -> float:
	if entries.is_empty():
		if on_land.is_valid():
			if hand_over:
				on_land.call([] as Array)
			else:
				on_land.call()
		return 0.0
	var launched := run
	var bodies: Array[Node3D] = []
	var tweens: Array[Tween] = []
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var body: Node3D = entry["body"]
		if body == null or not is_instance_valid(body):
			continue
		bodies.append(body)
		_thrown.append(body)
		tweens.append(_throw_one(body, entry["from"], entry["to"],
			THROW_STAGGER * float(i)))
	var travel := THROW_TIME + THROW_SET_TIME \
		+ THROW_STAGGER * float(maxi(entries.size() - 1, 0))
	get_tree().create_timer(travel).timeout.connect(func() -> void:
		if run != launched:
			return  # der Laufwechsel hat längst alles abgeräumt
		# Erst die Fahrt aus, dann der Körper fort - ein Tween, der auf einen
		# entfernten Knoten schreibt, meldet einen Fehler.
		_kill_throws(tweens)
		if hand_over:
			for body: Node3D in bodies:
				_thrown.erase(body)
			if on_land.is_valid():
				on_land.call(bodies)
			return
		if on_land.is_valid():
			on_land.call()
		_clear_thrown(bodies))
	return travel

## EIN Wurf: ballistischer Bogen (XZ linear, Y als Parabel über dem Filz), Trudeln im
## Flug und ein kurzes Setzen bei der Landung.
func _throw_one(body: Node3D, from: Vector3, to: Vector3, delay: float) -> Tween:
	body.global_position = from
	body.visible = true
	var peak := clampf(Vector2(to.x - from.x, to.z - from.z).length() * THROW_ARC_SHARE,
		THROW_ARC_MIN, THROW_ARC_MAX)
	var spin := body.rotation + THROW_SPIN
	var tween := create_tween()
	_throw_tweens.append(tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(_fly_arc.bind(body, from, to, peak), 0.0, 1.0, THROW_TIME)
	tween.parallel().tween_property(body, "rotation", spin, THROW_TIME) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(body, "global_position", to + Vector3.UP * THROW_SET,
		THROW_SET_TIME * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "global_position", to, THROW_SET_TIME * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tween

## Die Bahn selbst - gebunden statt als Lambda, damit sie eine gewöhnliche Funktion
## bleibt (der Tween reicht den Fortschritt voran).
func _fly_arc(t: float, body: Node3D, from: Vector3, to: Vector3, peak: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var at := from.lerp(to, t)
	at.y += 4.0 * peak * t * (1.0 - t)
	body.global_position = at

## Wohin das i-te Stück einer Salve fällt: ein kleiner Fächer um den Platz - und
## immer FLOOR_CLEAR über der Fläche, sonst steckte das Stück im Glas.
func _throw_scatter(target: Vector3, index: int, count: int) -> Vector3:
	var lie := target + Vector3.UP * BetPrizeView.FLOOR_CLEAR
	if count <= 1:
		return lie
	var angle := TAU * float(index) / float(count) + 0.6
	return lie + Vector3(cos(angle), 0.0, sin(angle)) * THROW_SCATTER

## Die Spitze des SCHATZES - dort hebt jedes geworfene Geld ab.
func _treasure_throw_point() -> Vector3:
	return chip_stack.global_position + Vector3.UP * chip_stack.top_y()

## EIN Wurf-Chip in echter Stückelung, geliehen aus der Börse des Schatzes (ihre
## Meshes und Materialien, kein zweiter Satz) und hierher umgehängt.
func _throw_chip_body(value: int) -> Node3D:
	var ghost := chip_stack.build_ghost_tower(value, 1)
	chip_stack.remove_child(ghost)
	add_child(ghost)
	return ghost

## Die Körper einer GELD-Salve: ein Chip je Stückelung des Zahlplans, höchster Wert
## zuerst, gedeckelt - so fliegt sichtbar, was der Spieler wirklich hinlegt.
func _throw_chip_bodies(values: Array[int]) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i in mini(values.size(), THROW_SALVO_CAP):
		out.append(_throw_chip_body(values[i]))
	return out

## Eine lose Elko-Zelle als Wurfkörper - dieselbe Dose wie in der Bank, nur an einem
## Halter, dessen Ursprung der Flug fassen darf.
func _throw_energy_body() -> Node3D:
	var holder := Node3D.new()
	holder.name = "WurfElko"
	add_child(holder)
	holder.add_child(CapacitorBankView.build_loose_cell(true))
	return holder

## Eine liegende Kassette als Wurfkörper - dieselbe Ware, die auch im Magazin liegt,
## in IHRER Sorte und Größe: geopfert wird genau, was der Knopf genannt hat.
func _throw_cell_body(at: Vector3, sort := Pack.SHELF_SPECIAL,
		tier := Pack.TIER_NORMAL) -> Node3D:
	var cell := _spawn_data_cell(sort, tier, at)
	cell.set_body_scale(PackDrawerView.CASSETTE_SCALE)
	cell.lie_on_glass(at)
	return cell

## Der EINE Aufräum-Pfad des Wurfs: jede Fahrt aus, jeder Flugkörper fort. Ein
## Abbruch mitten im Flug hinterläßt weder Körper noch offene Schuld - gebucht war
## längst, und der Endzustand steht ohnehin.
func _settle_throws() -> void:
	_kill_throws(_throw_tweens.duplicate())
	_clear_thrown(_thrown.duplicate())

func _kill_throws(tweens: Array) -> void:
	for tween: Tween in tweens:
		if tween != null and tween.is_valid():
			tween.kill()
		_throw_tweens.erase(tween)

func _clear_thrown(bodies: Array) -> void:
	for body: Node3D in bodies:
		_thrown.erase(body)
		if body == null or not is_instance_valid(body):
			continue
		remove_child(body)
		body.queue_free()
#endregion

#region Die WUERFEL-BUEHNE
# Das PIT ist ein KREISLAUF. Mit dem Zurren der Runde sinkt das ganze Pool-Tray als
# TRÄGER auf die Plattform und bleibt dort SICHTBAR stehen - ein ordentliches Raster
# hinter fast durchsichtigem Glas. Jeder Deck-Eintrag hat EINEN festen Träger-Sitz
# (Buch-Ordnung wie das Tray); gezogene Würfel hinterlassen LÜCKEN, nichts rückt
# einzeln nach - und ist die vorderste Pool-Reihe leer, fährt der GANZE Träger eine
# Reihen-Teilung vor: das Loch steht fest, der Träger bewegt sich darunter.
# Abgelegte Würfel SCHLUCKT der Tisch an ihrem Liegeplatz in der Wurfgrube (eine
# würfelgroße Sektion, PIT_SWALLOW) und sammelt sie unsichtbar; je voller Reihe
# fahren sie EINMAL GEMISCHT von hinten in den Träger ein und LIEGEN dort mit der
# gemerkten Seite oben, im roten Ablage-Abschnitt hinter dem Teiler.
# Am Rundenende fährt der Träger schlicht herauf: sein Inhalt IST der neue Pool.
# Die WARTESCHLANGE fährt je Würfel eine eigene Plattform-Fahrt auf.

## Wie tief eine Würfel-Hebebühne fährt: der schwebende Würfel muß durch sein
## Öffnungsband passen (Schwebehöhe plus halber Würfel), sonst streift er den Sturz.
func _tray_shaft_depth() -> float:
	var top := DiceTrayView.FLOAT_HEIGHT + DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT
	return maxf(VitrineView.shaft_depth(), top * VitrineView.SHAFT_ROOM)

## Und wie tief der SCHLUCK: dort geht ein LIEGENDER Würfel durch, mehr nicht.
func _swallow_shaft_depth() -> float:
	var lying := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT * 2.0
	return maxf(VitrineView.shaft_depth(), lying * VitrineView.SHAFT_ROOM)

## Der Fußabdruck einer Platz-Spanne: ihr Slotraster plus einen halben Platz Saum.
## Gerechnet aus den SITZEN, nie an Körpern gemessen - wer gerade fährt, steht
## woanders.
func _tray_span_field(tray: DiceTrayView, slots: Array) -> Dictionary:
	if tray == null or slots.is_empty() or tray.slot_roots.is_empty():
		return {}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i: int in slots:
		if i < 0 or i >= tray.slot_roots.size():
			continue
		var at := tray.slot_home_position(i)
		lo = Vector2(minf(lo.x, at.x), minf(lo.y, at.z))
		hi = Vector2(maxf(hi.x, at.x), maxf(hi.y, at.z))
	if lo.x > hi.x:
		return {}
	return _field_of(lo, hi)

## Der Grundriß des Vorrats-Platzes - und damit des offenen PITs: das ganze
## Slotraster des Trays plus Saum, gerechnet vom HEIMAT-Ort. Der Träger rückt
## darunter vor, das Loch bleibt stehen.
func _pool_field() -> Dictionary:
	if pool_tray_view == null or pool_tray_view.slot_roots.is_empty():
		return {}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in pool_tray_view.slot_roots.size():
		var at := _pool_tray_home + pool_tray_view.slot_offset(i)
		lo = Vector2(minf(lo.x, at.x), minf(lo.y, at.z))
		hi = Vector2(maxf(hi.x, at.x), maxf(hi.y, at.z))
	return _field_of(lo, hi)

func _field_of(lo: Vector2, hi: Vector2) -> Dictionary:
	return {
		"at": Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.y + hi.y) * 0.5),
		"half": Vector2((hi.x - lo.x) * 0.5 + TRAY_PIT_SEAM.x,
			(hi.y - lo.y) * 0.5 + TRAY_PIT_SEAM.y),
	}

## Die Sektion des Vorrats, gestellt und verdrahtet - der EINE Schreiber ihrer
## Konfiguration, und sie kennt ZWEI: für die RUNDE flach (POOL_PARK_DEPTH) und ohne
## Schirm (der Vorrat ragt aus dem Pit, ein Glas darüber wäre durchstoßen), für die
## GLAS-ANSICHT tief (_tray_shaft_depth) mit Schirm und Anzeige-Haut. _deck_glass ist
## der einzige Entscheider - ohne ihn steht die Runden-Konfiguration unverändert da.
func _pool_shaft_on(field: Dictionary) -> LiftShaftView:
	if table_screen == null or field.is_empty():
		return null
	if pool_shaft == null or not is_instance_valid(pool_shaft):
		pool_shaft = LiftShaftView.new("PoolShaft")
		add_child(pool_shaft)
		pool_shaft.opened.connect(func(at: Vector3, hole: Vector2) -> void:
			table_screen.set_lift_pit(TableScreen.PIT_POOL, at, hole))
		pool_shaft.closed.connect(func() -> void:
			table_screen.clear_pit(TableScreen.PIT_POOL))
	pool_shaft.deck_skin = table_screen.display_skin()
	pool_shaft.order_skin(PIT_SKIN)
	if _deck_glass:
		pool_shaft.order_cover("", DECK_GLASS_TINT)
		pool_shaft.order_cover_skin(table_screen.deck_glass_skin())
		pool_shaft.setup(field["at"], field["half"], _tray_shaft_depth())
	else:
		pool_shaft.drop_cover()  # nimmt die Anzeige-Haut mit
		pool_shaft.setup(field["at"], field["half"], POOL_PARK_DEPTH)
	return pool_shaft

## Die Maschine EINES Warteschlangen-Platzes - je Platz eine eigene, damit die
## gestaffelten Fahrten überlappen dürfen (eine Maschine ist ein Loch).
func _queue_shaft_for(slot: int) -> LiftShaftView:
	if table_screen == null or queue_tray_view == null \
			or slot < 0 or slot >= queue_tray_view.slot_roots.size():
		return null
	var field := _tray_span_field(queue_tray_view, [slot])
	if field.is_empty():
		return null
	# Nachbar-Löcher berühren sich NIE (die Schwarzmarkt-Regel): der volle Saum
	# zweier Plätze stößt exakt aneinander, und die Wand einer Maschine ragt über
	# ihr Loch hinaus - also weicht jedes Loch um Wand plus Fuge zurück. Puck
	# (r 0,62) und Würfel (0,6) passen durch die verbleibenden 0,74.
	field["half"] = (field["half"] as Vector2) \
		- Vector2(0.0, LiftShaftView.WALL + 0.06)
	while _queue_shafts.size() <= slot:
		_queue_shafts.append(null)
	var shaft := _queue_shafts[slot]
	if shaft == null or not is_instance_valid(shaft):
		shaft = LiftShaftView.new("QueueShaft%d" % slot)
		add_child(shaft)
		var pit := TableScreen.queue_pit(slot)
		shaft.opened.connect(func(at: Vector3, hole: Vector2) -> void:
			table_screen.set_lift_pit(pit, at, hole))
		shaft.closed.connect(func() -> void:
			table_screen.clear_pit(pit))
		_queue_shafts[slot] = shaft
	shaft.deck_skin = table_screen.display_skin()
	shaft.order_skin(PIT_SKIN)
	shaft.setup(field["at"], field["half"], _tray_shaft_depth())
	return shaft

## Die Bahn des SCHLUCKS: ein würfelgroßes Loch, das unter den Liegeplatz des
## gerade abgehenden Würfels wandert. Drei Bahnen, damit die Staffel überlappt.
## Zuschnitt und Tiefe sind Parameter: derselbe Fahrweg zieht beim TAUSCH einen
## SCHWEBENDEN Würfel an seinem Pool-Sitz ein (anderes Feld, tieferer Schacht).
func _swallow_shaft_for(lane: int, at: Vector3, half := SWALLOW_HALF,
		depth := 0.0) -> LiftShaftView:
	if table_screen == null:
		return null
	while _swallow_shafts.size() < TableScreen.SWALLOW_PIT_COUNT:
		_swallow_shafts.append(null)
	var shaft := _swallow_shafts[lane]
	if shaft == null or not is_instance_valid(shaft):
		shaft = LiftShaftView.new("SwallowShaft%d" % lane)
		add_child(shaft)
		var pit := TableScreen.swallow_pit(lane)
		shaft.opened.connect(func(spot: Vector3, hole: Vector2) -> void:
			table_screen.set_lift_pit(pit, spot, hole))
		shaft.closed.connect(func() -> void:
			table_screen.clear_pit(pit))
		_swallow_shafts[lane] = shaft
	shaft.deck_skin = table_screen.display_skin()
	shaft.order_skin(PIT_SKIN)
	shaft.setup(Vector3(at.x, 0.0, at.z), half,
		depth if depth > 0.0 else _swallow_shaft_depth())
	return shaft

# --- Der TRÄGER: Sitz-Plan, Park, Reihen-Vorrücken ------------------------------

## Der Heimat-Ort des Trägers, um die schon gefahrenen Reihen versetzt.
func _carrier_home() -> Vector3:
	return _pool_tray_home + Vector3(float(_carrier_shift) * DiceTrayView.SPACING.x, 0.0, 0.0)

## Und derselbe Punkt auf der Grubensohle - dort steht er die ganze Runde.
func _carrier_park() -> Vector3:
	var at := _carrier_home()
	if pool_shaft != null and is_instance_valid(pool_shaft):
		at.y -= pool_shaft.park_y()
	return at

## Der WELT-Sitz eines Träger-Platzes (Pool-Sitz = Deck-Index, die Ablage hängt
## dahinter). Gerechnet aus dem Raster, nie am fahrenden Körper gemessen.
func _carrier_seat(seat: int) -> Vector3:
	return _carrier_park() + pool_tray_view.slot_offset(seat)

## Der erste Sitz der ABLAGE: gleich hinter dem letzten Pool-Sitz.
func _ablage_base() -> int:
	return round_pool_kinds.size()

## Wieviele Träger-Reihen schon leer sind - alles vor dem Warteschlangen-Fenster ist
## gezogen, und eine Reihe zählt erst, wenn sie GANZ leer ist.
func _wanted_carrier_shift() -> int:
	if pool_tray_view == null:
		return 0
	return DiceTrayView.rows_before(next_draw_index + _queue_display_capacity(),
		pool_tray_view.columns)

## Der EINE Schreiber des Träger-STANDES: je Bild gefragt, gefahren nur der
## Unterschied - und nie, während die Maschine ihn selbst führt. Endzustand zuerst:
## der Sitz-Plan gilt sofort, gefahren wird bloß der Weg dorthin.
func _sync_carrier_shift() -> void:
	if _pool_standing or pool_tray_view == null or _pool_parked_field.is_empty():
		return
	if _deck_glass:
		return  # in der Glas-Ansicht ist der Vorrat kein Träger, nur abgesenkt
	if pool_shaft == null or not is_instance_valid(pool_shaft) or pool_shaft.riding():
		return
	if _carrier_tween != null and _carrier_tween.is_valid() and _carrier_tween.is_running():
		return
	if not _carrier_leaving.is_empty():
		return  # dort sitzt noch einer und fährt gerade ab - die Reihe ist nicht leer
	var wanted := _wanted_carrier_shift()
	if wanted == _carrier_shift:
		return
	_carrier_shift = wanted
	_carrier_tween = create_tween()
	_carrier_tween.tween_property(pool_tray_view, "global_position", _carrier_park(),
		CARRIER_SHIFT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Der harte Stand des Trägers - jeder Abbruch geht durch ihn.
func _seat_carrier_hard() -> void:
	_stop_stage_tween(_carrier_tween)
	_carrier_tween = null
	if pool_tray_view == null:
		return
	pool_tray_view.visible = true
	pool_tray_view.global_position = _pool_tray_home if _pool_standing else _carrier_park()

func _stop_stage_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

## Das Zurren der Runde senkt den Vorrat: das Pool-Tray fährt als bleibendes CARGO
## der Plattform hinab und steht danach SICHTBAR im offenen Pit, der Schirm darüber.
## Endzustand zuerst: das Stehen-Bit fällt, bevor die Fahrt läuft.
func _sink_pool_tray() -> void:
	if not _pool_standing or pool_tray_view == null or table_screen == null:
		return
	# Der Träger braucht seinen ganzen Sitz-Plan, bevor sein Loch daran gemessen wird.
	pool_tray_view.ensure_capacity(maxi(round_pool_kinds.size(), 1))
	var field := _pool_field()
	if field.is_empty():
		return
	_pool_standing = false
	_pool_parked_field = field
	_carrier_shift = 0
	_tray_stage_gen += 1
	_refresh_deck_trays()  # ab hier trägt das Tray den Sitz-Plan, nicht die Aufreihung
	_rebuild_bench_stage()  # der Bühnen-Würfel sitzt jetzt im Träger
	# Versenkt spiegelt der Vorrat nicht - sein Bild geisterte sonst über der Fläche.
	ScreenReflection.set_reflective(pool_tray_view, false)
	var shaft := _pool_shaft_on(field)
	if shaft == null:
		_seat_carrier_hard()
		return
	var tween := shaft.run_park([], [], [], [], 0.0, Callable(),
		[pool_tray_view], [_carrier_home()])
	if tween == null:
		shaft.park_hard()
		_seat_carrier_hard()

## Der EINE Schreiber des PIT-Endzustands: die Grube steht offen auf dem Platz des
## Vorrats, die Plattform auf Park-Tiefe, das Glas darüber. Je Bild gefragt - ein
## fremder Aufräum-Pfad schließt sie, und hier steht sie beim nächsten Hinsehen
## wieder. Eine laufende Fahrt schreibt ihren Zustand selbst.
func _park_pool_shaft() -> void:
	if _pool_standing or _pool_parked_field.is_empty():
		return
	var shaft := _pool_shaft_on(_pool_parked_field)
	if shaft == null or shaft.riding():
		return
	if not shaft.visible or not is_equal_approx(shaft.platform_y(), -shaft.park_y()):
		shaft.park_hard()
		# Die Glas-Ansicht führt keinen Träger: ihr Vorrat steht schlicht auf der Sohle.
		if _deck_glass and pool_tray_view != null:
			pool_tray_view.global_position = _pool_tray_home - Vector3.UP * shaft.park_y()
	_sync_carrier_shift()

## Die Belegung des geparkten Trägers: Platz i IST Deck-Eintrag i. Belegt ab dem
## Warteschlangen-Fenster, davor Lücken; ein Sitz, dessen Würfel gerade ABFÄHRT,
## zeigt ihn weiter, bis seine Fahrt steht.
func _carrier_seats() -> Array[DieDefinition]:
	var seats: Array[DieDefinition] = []
	var start := next_draw_index + _queue_display_capacity()
	for d in round_pool_kinds.size():
		var def: DieDefinition = round_pool_kinds[d]
		if def == null or not _tray_shows(def):
			seats.append(null)
		elif d < start and not _carrier_leaving.has(d):
			seats.append(null)
		else:
			seats.append(def)
	return seats

## Der ABGANG eines gezogenen Würfels vom Träger: er sinkt an SEINEM Sitz in die
## Plattform - Träger-intern, das Loch steht ja offen. Gestaffelt, damit eine Fuhre
## als Folge einzelner Züge liest.
func _leave_carrier_seats(seats: Array) -> void:
	if _pool_standing or pool_tray_view == null:
		return
	var generation := _tray_stage_gen
	var launched := run
	var step := 0
	var deep := -DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT * 2.0
	# Der Abgang TAKTET mit der Staffel, die ihn abholt: derselbe Versatz wie
	# zwischen den Starts der Warteschlangen-Fahrten, links nach rechts.
	var gap := QUEUE_RIDE_STAGGER
	_carrier_sinks = _carrier_sinks.filter(func(t: Tween) -> bool:
		return t != null and t.is_valid())
	for seat: int in seats:
		if seat < 0 or seat >= pool_tray_view.slot_roots.size():
			continue
		if not pool_tray_view.slot_roots[seat].visible:
			continue
		_carrier_leaving[seat] = true
		pool_tray_view.set_slot_riding(seat, true)
		var root := pool_tray_view.slot_roots[seat]
		var tween := create_tween()
		tween.tween_interval(float(step) * gap)
		tween.tween_property(root, "position:y", deep, CARRIER_SINK_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			_finish_carrier_leave(seat, generation, launched))
		_carrier_sinks.append(tween)
		step += 1

func _finish_carrier_leave(seat: int, generation: int, launched: GameRun) -> void:
	if pool_tray_view == null or seat >= pool_tray_view.slot_roots.size():
		return
	_carrier_leaving.erase(seat)
	pool_tray_view.set_slot_visible(seat, false)
	pool_tray_view.slot_roots[seat].position.y = DiceTrayView.FLOAT_HEIGHT
	pool_tray_view.set_slot_riding(seat, false)
	if generation == _tray_stage_gen and run == launched:
		_refresh_deck_trays()  # der Schreiber bestätigt die Lücke

## Alle laufenden Abgänge hart beenden - ein getöteter Tween meldet nie fertig.
func _reset_carrier_leaving() -> void:
	for tween in _carrier_sinks:
		_stop_stage_tween(tween)
	_carrier_sinks.clear()
	if pool_tray_view != null:
		for seat: int in _carrier_leaving.keys():
			if seat < pool_tray_view.slot_roots.size():
				pool_tray_view.slot_roots[seat].position.y = DiceTrayView.FLOAT_HEIGHT
				pool_tray_view.set_slot_riding(seat, false)
	_carrier_leaving.clear()

# --- Der SCHLUCK: der Tisch zieht den abgelegten Würfel an Ort und Stelle ein ----

## Ein abgelegter Würfel verläßt den Tisch dort, wo er LIEGT: eine würfelgroße
## Sektion öffnet unter ihm, senkt ihn ein und schließt wieder (Hebebühne, kein
## Flug). Gebucht ist längst (discarded_this_round); gemerkt wird hier die Ablage-
## ORDNUNG, aus der am Rundenende der neue Pool entsteht.
## from[i] ist die WELT-Lage des echten Grubenkörpers (Transform3D) oder null - ein
## Würfel ohne Körper (leerer Slot am Poolende) wandert nur in den Puffer, zu fahren
## gibt es dort nichts. Geschluckt wird von LINKS nach RECHTS (Welt +Z), und der
## Doppelgänger steht SOFORT in der Lage des Originals da - der Rufer versteckt es
## im selben Bild, der Tausch ist unsichtbar.
func _swallow_dice(defs: Array[DieDefinition], faces: Array[int], from: Array) -> void:
	var items: Array[Dictionary] = []
	for i in defs.size():
		if defs[i] == null:
			continue
		items.append({
			"def": defs[i],
			"face": faces[i] if i < faces.size() else -1,
			"at": from[i] if i < from.size() else null,
		})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var az: float = (a["at"] as Transform3D).origin.z if a["at"] != null else INF
		var bz: float = (b["at"] as Transform3D).origin.z if b["at"] != null else INF
		return az < bz)
	for item in items:
		var entry := {"def": item["def"], "face": int(item["face"]), "landed": false}
		_ablage_buffer.append(entry)
		var pose: Variant = item["at"]
		if pose == null or _pool_standing or table_screen == null:
			entry["landed"] = true
			continue
		_swallow_queue.append({
			"body": _swallow_die_body(item["def"], pose as Transform3D),
			"seat": (pose as Transform3D).origin,
			"entry": entry,
		})
	_pump_swallow()
	_flush_ablage_rows()

## Sind noch Schlucke unterwegs oder bestellt?
func _swallow_busy() -> bool:
	if not _swallow_queue.is_empty():
		return true
	for body in _swallow_bodies:
		if body != null:
			return true
	return false

## Die STAFFEL der Abgänge: drei Bahnen, jede ist eine Maschine mit eigenem Loch.
## Ein Schub startet seine Fahrten dicht versetzt; danach hält die frei werdende
## Bahn den Takt von selbst (der Versatz ist Fahrtdauer durch Bahnenzahl).
func _pump_swallow() -> void:
	while _swallow_bodies.size() < TableScreen.SWALLOW_PIT_COUNT:
		_swallow_bodies.append(null)
	var stagger := LiftShaftView.take_cycle_time() / SWALLOW_SPEED \
		/ float(TableScreen.SWALLOW_PIT_COUNT)
	var burst := 0
	while not _swallow_queue.is_empty():
		var lane := _swallow_bodies.find(null)
		if lane == -1:
			return  # alle Bahnen fahren - die nächste freie pumpt weiter
		var item: Dictionary = _swallow_queue.pop_front()
		var body: Node3D = item["body"]
		var entry: Dictionary = item["entry"]
		var shaft := _swallow_shaft_for(lane, item["seat"])
		var tween: Tween = null
		if shaft != null:
			tween = shaft.run_take([body], [item["seat"]],
				float(burst) * stagger * SWALLOW_SPEED)
		if tween == null:
			_drop_stage_body(body)
			entry["landed"] = true
			_flush_ablage_rows()
			continue
		tween.set_speed_scale(SWALLOW_SPEED)
		burst += 1
		_swallow_bodies[lane] = body
		var generation := _tray_stage_gen
		var launched := run
		tween.finished.connect(func() -> void:
			_swallow_bodies[lane] = null
			_drop_stage_body(body)
			if generation != _tray_stage_gen or run != launched:
				return
			entry["landed"] = true
			_flush_ablage_rows()
			_pump_swallow())

## Der Wegwerf-Körper des Schlucks: derselbe Bau wie ein Grubenwürfel, aber ohne
## Physik - gespawnt in der LAGE des Originals, damit der Tausch unsichtbar ist;
## er geht so hinunter, wie er lag.
func _swallow_die_body(def: DieDefinition, pose: Transform3D) -> Node3D:
	var die := _lying_die_body(def, -1)
	add_child(die)
	die.global_transform = Transform3D(pose.basis.orthonormalized(), pose.origin)
	die.scale = Vector3.ONE * DiceTrayView.DIE_SCALE
	return die

func _drop_stage_body(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	body.get_parent().remove_child(body)
	body.queue_free()

# --- Die ABLAGE: Reihen erscheinen im Träger ------------------------------------

## Volle Reihen erscheinen erst, wenn ihre Würfel wirklich UNTEN sind ("landed",
## gesetzt von der Schluck-Fahrt) - ein noch fahrender Würfel stünde sonst doppelt
## im Bild. Der Puffer hält die Schluck-ORDNUNG, gelandet wird auch quer dazu.
func _flush_ablage_rows() -> void:
	if pool_tray_view == null or _pool_standing:
		return
	var width := pool_tray_view.columns
	while width > 0 and _row_landed(width):
		var row: Array = _ablage_buffer.slice(0, width)
		_ablage_buffer = _ablage_buffer.slice(width, _ablage_buffer.size())
		_play_ablage_row(row)

## Liegen die vordersten width Einträge des Puffers schon unten?
func _row_landed(width: int) -> bool:
	if _ablage_buffer.size() < width:
		return false
	for i in width:
		if not _ablage_buffer[i]["landed"]:
			return false
	return true

## Der Halter der Ablage - ein Kind des TRÄGERS, damit sie jede Fahrt mitmacht.
func _ablage_stage() -> Node3D:
	if _ablage_root == null or not is_instance_valid(_ablage_root):
		_ablage_root = Node3D.new()
		_ablage_root.name = "Ablage"
		pool_tray_view.add_child(_ablage_root)
	return _ablage_root

## Ein LIEGENDER Würfel in Tray-Lage: die gemerkte Seite oben, die Ziffer aufrecht.
func _lying_die_body(def: DieDefinition, face: int) -> Node3D:
	var die := DieBuilder.build()
	var pose := Quaternion(Vector3.UP, DiceTrayView.YAW_REST) * DiceTrayView.face_up_pose(face)
	die.transform = Transform3D(Basis(pose).scaled(Vector3.ONE * DiceTrayView.DIE_SCALE),
		Vector3.ZERO)
	var body: RigidBody3D = die.get_node("RigidBody3D")
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	var display: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	display.apply_definition(def)
	display.set_tint(DiceController.KIND_TINTS.get(def.style_id, Color.WHITE))
	return die

## Eine volle Ablage-Reihe erscheint: EINMAL gemischt (die eine Reststreuung der
## Runde), dann schiebt sie durch das hintere Öffnungsband auf ihre Träger-Sitze.
## Endzustand zuerst - die Sitze stehen, bevor die Fahrt läuft.
func _play_ablage_row(items: Array) -> void:
	if items.is_empty() or pool_tray_view == null or _pool_standing:
		return
	var row := DiceTrayView.shuffle_row(items)
	var lie := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT
	var behind := _ablage_entry_x()
	var tween := create_tween()
	tween.set_parallel(true)
	for k in row.size():
		var item: Dictionary = row[k]
		var seat := _ablage_base() + _ablage_seats.size()
		var body := _lying_die_body(item["def"], int(item["face"]))
		_ablage_stage().add_child(body)
		var home := pool_tray_view.slot_offset(seat) + Vector3.UP * lie
		body.position = Vector3(behind, home.y, home.z)
		_ablage_seats.append({"def": item["def"], "face": int(item["face"]),
			"seat": seat, "body": body})
		tween.tween_property(body, "position", home, ABLAGE_SLIDE_TIME) \
			.set_trans(Tween.TRANS_LINEAR)
	_ablage_entering += 1
	if pool_shaft != null and is_instance_valid(pool_shaft):
		pool_shaft.run_band(LiftShaftView.BAND_BACK, true)
	var generation := _tray_stage_gen
	var launched := run
	tween.chain().tween_callback(func() -> void:
		_ablage_entering = maxi(_ablage_entering - 1, 0)
		if generation != _tray_stage_gen or run != launched:
			return
		if _ablage_entering == 0 and pool_shaft != null and is_instance_valid(pool_shaft):
			pool_shaft.run_band(LiftShaftView.BAND_BACK, false))
	_sync_ablage_decor()

## Wo eine einfahrende Reihe wartet: im hinteren HOHLRAUM der Maschine, träger-lokal
## gerechnet - dort ist es dunkel, und das Band gibt den Weg frei.
func _ablage_entry_x() -> float:
	if pool_shaft == null or not is_instance_valid(pool_shaft) or _pool_parked_field.is_empty():
		return 0.0
	var at: Vector3 = _pool_parked_field["at"]
	var half: Vector2 = _pool_parked_field["half"]
	var world := at.x + half.x + LiftShaftView.WALL + pool_shaft.cavity_span() * 0.6
	return world - _carrier_home().x

## Der Ablage-Abschnitt liest sich als eigener Block: je Reihe eine dunkelrote
## Leuchtplatte unter den liegenden Würfeln, und davor der TEILER - ein heller Steg
## quer über den Träger. Ganz neu gebaut, nie geflickt (höchstens sechs Platten).
func _sync_ablage_decor() -> void:
	if pool_tray_view == null:
		return
	var stage := _ablage_stage()
	for child in stage.get_children():
		if child.name.begins_with("Ablagestreifen") or child.name == "Teiler":
			stage.remove_child(child)
			child.queue_free()
	if _ablage_seats.is_empty():
		return
	var width := maxi(pool_tray_view.columns, 1)
	var base := _ablage_base()
	var rows := int(ceil(float(_ablage_seats.size()) / float(width)))
	var span := Vector3(DiceTrayView.SPACING.x * 0.86, 0.03,
		float(width) * DiceTrayView.SPACING.y)
	for r in rows:
		var at := pool_tray_view.slot_offset(base + r * width)
		_stage_plate("Ablagestreifen%d" % r, stage, span,
			Vector3(at.x, 0.02, 0.0), ABLAGE_TINT, 1.4)
	var edge := pool_tray_view.slot_offset(base).x + DiceTrayView.SPACING.x * 0.5
	_stage_plate("Teiler", stage,
		Vector3(DiceTrayView.SPACING.x * 0.12, 0.05, span.z),
		Vector3(edge, 0.03, 0.0), LiftShaftView.GLOW_COLOR, 2.2)

func _stage_plate(plate_name: String, parent: Node3D, span: Vector3, at: Vector3,
		tint: Color, energy: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = span
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint.r * 0.4, tint.g * 0.4, tint.b * 0.4, 1.0)
	material.metallic = 0.0
	material.roughness = 0.5
	material.emission_enabled = true
	material.emission = Color(tint.r, tint.g, tint.b, 1.0)
	material.emission_energy_multiplier = energy
	var plate := MeshInstance3D.new()
	plate.name = plate_name
	plate.mesh = mesh
	plate.material_override = material
	plate.position = at
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(plate)

## Die Ablage fort - der EINE Aufräum-Pfad ihrer Körper.
func _reset_ablage_hard() -> void:
	_ablage_seats.clear()
	_ablage_buffer.clear()
	_ablage_entering = 0
	if _ablage_root != null and is_instance_valid(_ablage_root):
		_ablage_root.get_parent().remove_child(_ablage_root)
		_ablage_root.queue_free()
	_ablage_root = null

# --- Die Warteschlange fährt je Würfel eine eigene Plattform auf ----------------

## Der EINE Schreiber der Warteschlangen-Bühne. Er vergleicht die gewollte Belegung
## mit der stehenden und fährt NUR den Unterschied: die Reihe tritt als Ganzes auf
## (ein Auftritt), danach fährt je nachgerücktem Würfel eine EIGENE Sektion.
## Endzustand zuerst, also startet ein Re-Sync mitten in der Fahrt nichts neu.
func _sync_queue_stage(delay := 0.0) -> void:
	if queue_tray_view == null or table_screen == null:
		return
	var count := queue_tray_view.slot_roots.size()
	while _queue_dice_up.size() < count:
		_queue_dice_up.append(false)
	if not (queue_activated and _is_playing()):
		if _queue_staged:
			_lower_queue_row()
		return
	if not _queue_staged:
		_raise_queue_row(delay)
		return
	var wanted: Array[bool] = []
	for i in count:
		wanted.append(queue_tray_view.slot_defs[i] != null)
	var enter := DiceTrayView.stage_entering(wanted, _queue_dice_up)
	for i in count:
		# Den hat die Wurf-Zeremonie getragen - die Bühne holt ihn nicht nach.
		if not wanted[i]:
			_queue_dice_up[i] = false
	if not enter.is_empty():
		_run_queue_swap(enter, delay)

## Der AUFTRITT der ganzen Reihe: je Platz fährt SEINE Maschine, dicht gestaffelt
## von links nach rechts - EIN Auftritt in sechs Löchern.
func _raise_queue_row(delay: float) -> void:
	_stop_queue_rides()
	_queue_staged = true
	for i in queue_tray_view.slot_roots.size():
		queue_tray_view.set_slot_staged(i, true)
		_queue_dice_up[i] = queue_tray_view.slot_defs[i] != null
		var bodies: Array = [queue_tray_view.slot_emitter(i)]
		var seats: Array = [queue_tray_view.slot_home_position(i)]
		if _queue_dice_up[i]:
			bodies.append(queue_tray_view.slot_roots[i])
			seats.append(queue_tray_view.slot_home_position(i, true))
		_start_queue_ride(i, bodies, seats, [], [],
			delay + float(i) * QUEUE_RIDE_STAGGER)

## Das AUFFÜLLEN fährt je Würfel SEINE eigene Maschine: dicht gestaffelt von links
## nach rechts, die Fahrten überlappen. Der Puck sinkt als MITFAHRER mit der Platte
## und kommt beladen zurück. Endzustand zuerst: die Belegung steht sofort.
func _run_queue_swap(enter: Array, delay: float) -> void:
	for k in enter.size():
		var i: int = enter[k]
		_queue_dice_up[i] = true
		queue_tray_view.set_slot_staged(i, true)  # der Puck steht, er ist längst oben
		_seat_queue_body_below(i)
		_start_queue_ride(i, [queue_tray_view.slot_roots[i]],
			[queue_tray_view.slot_home_position(i, true)],
			[queue_tray_view.slot_emitter(i)],
			[queue_tray_view.slot_home_position(i)],
			delay + float(k) * QUEUE_RIDE_STAGGER)

## Ein Platz, der noch auf SEINE Fahrt wartet, hält seinen Würfel UNTER der Fläche:
## oben stünde er, bevor die Plattform ihn gebracht hat - und sein Zwilling fährt
## gerade erst vom Träger ab (ein Würfel wird nie zweimal gezeigt).
func _seat_queue_body_below(index: int) -> void:
	queue_tray_view.slot_roots[index].global_position = \
		queue_tray_view.slot_home_position(index, true) \
		- Vector3.UP * (_tray_shaft_depth() + DiceTrayView.FLOAT_HEIGHT)
	_set_queue_slot_reflective(index, false)  # steht unter der Fläche - nicht spiegeln

## EINE Einzel-Fahrt: doppelt schnell (set_speed_scale halbiert die GANZE Fahrt,
## der Vorlauf reist im Tween mit und wird darum vorgeteilt). Fällt die Maschine
## aus, steht der Platz sofort hart auf seinem Sitz.
func _start_queue_ride(slot: int, bodies: Array, seats: Array, riders: Array,
		rider_seats: Array, real_delay: float) -> void:
	queue_tray_view.set_slot_riding(slot, true)
	_set_queue_slot_reflective(slot, false)  # fährt unter der Fläche - nicht spiegeln
	var shaft := _queue_shaft_for(slot)
	var tween: Tween = null
	if shaft != null:
		tween = shaft.run_cycle(bodies, seats, real_delay * QUEUE_RIDE_SPEED,
			riders, rider_seats)
	if tween == null:
		_seat_queue_body_hard(slot)
		return
	tween.set_speed_scale(QUEUE_RIDE_SPEED)
	_queue_ride_slots[slot] = true
	var generation := _tray_stage_gen
	var launched := run
	tween.finished.connect(func() -> void:
		_queue_ride_slots.erase(slot)
		if generation != _tray_stage_gen or run != launched:
			return
		queue_tray_view.set_slot_riding(slot, false)
		_set_queue_slot_reflective(slot, true))  # oben angekommen - wieder spiegeln

## Ein Warteschlangen-Platz spiegelt sich nur, wenn er ÜBER der Fläche steht - unter
## dem Tisch geisterte sein Spiegelbild sonst als Reflexion durch die Anzeige
## (Spieler-Entscheid 2026-08-31). Würfel UND Puck, denn beide fahren mit.
func _set_queue_slot_reflective(index: int, on: bool) -> void:
	if queue_tray_view == null or index < 0 \
			or index >= queue_tray_view.slot_roots.size():
		return
	ScreenReflection.set_reflective(queue_tray_view.slot_roots[index], on)
	ScreenReflection.set_reflective(queue_tray_view.slot_emitter(index), on)

## Ein Platz, dessen Fahrt ausfällt oder abbricht, steht sofort auf seinem Sitz -
## ein Würfel, der unter der Fläche vergessen wird, ist der schlimmste Rest. Der
## Puck fährt bei Auftritt und Auffüllen mit, also sitzt auch er hart.
func _seat_queue_body_hard(index: int) -> void:
	if queue_tray_view == null or index < 0 \
			or index >= queue_tray_view.slot_roots.size():
		return
	queue_tray_view.slot_roots[index].global_position = \
		queue_tray_view.slot_home_position(index, true)
	queue_tray_view.slot_emitter(index).global_position = \
		queue_tray_view.slot_home_position(index)
	queue_tray_view.set_slot_riding(index, false)
	_set_queue_slot_reflective(index, true)  # steht auf seinem Sitz - wieder spiegeln

## Alle laufenden Einzel-Fahrten abbrechen: ein getöteter Tween meldet nie fertig,
## also settlet der Abbrecher jede beteiligte Maschine und setzt ihren Platz hart.
func _stop_queue_rides() -> void:
	for slot: int in _queue_ride_slots.keys():
		if slot < _queue_shafts.size() and _queue_shafts[slot] != null \
				and is_instance_valid(_queue_shafts[slot]):
			_queue_shafts[slot].settle_hard()
		_seat_queue_body_hard(slot)
	_queue_ride_slots.clear()

## Der ABGANG der Reihe: alles Stehende (Pucks und Restwürfel) geht per Plattform ab -
## je Platz seine Maschine, dicht gestaffelt von links nach rechts. Zurück kommt der
## Tween der LETZTEN Fahrt: wer auf ihn wartet, hat alle gesehen.
func _lower_queue_row(delay := 0.0) -> Tween:
	if not _queue_staged or queue_tray_view == null:
		return null
	_stop_queue_rides()
	_queue_staged = false
	var last: Tween = null
	for i in queue_tray_view.slot_roots.size():
		var bodies: Array = [queue_tray_view.slot_emitter(i)]
		var seats: Array = [queue_tray_view.slot_home_position(i)]
		if i < _queue_dice_up.size() and _queue_dice_up[i]:
			bodies.append(queue_tray_view.slot_roots[i])
			seats.append(queue_tray_view.slot_home_position(i, true))
		_queue_dice_up[i] = false
		_set_queue_slot_reflective(i, false)  # sinkt unter die Fläche - nicht spiegeln
		var slot := i  # je Lambda sein eigener Wert
		var shaft := _queue_shaft_for(i)
		var tween: Tween = null
		if shaft != null:
			tween = shaft.run_exit(bodies, seats,
				(delay + float(i) * QUEUE_RIDE_STAGGER) * QUEUE_RIDE_SPEED,
				func() -> void: _sweep_queue_slot(slot))
		if tween == null:
			_seat_queue_body_hard(i)
			queue_tray_view.set_slot_staged(i, false)
			continue
		tween.set_speed_scale(QUEUE_RIDE_SPEED)
		queue_tray_view.set_slot_riding(i, true)
		_queue_ride_slots[i] = true
		tween.finished.connect(func() -> void:
			_queue_ride_slots.erase(slot))
		last = tween
	return last

## Der Sweep EINES abgehenden Platzes: seine Körper sind unten hinaus, er steht
## wieder (unsichtbar) auf seinem Sitz und gehört dem Schwebe-Takt.
func _sweep_queue_slot(slot: int) -> void:
	if queue_tray_view == null or slot < 0 \
			or slot >= queue_tray_view.slot_roots.size():
		return
	_seat_queue_body_hard(slot)
	queue_tray_view.set_slot_staged(slot, false)

## Der harte Schreiber der Reihe: jeder Platz steht (oder eben nicht), auf seinem
## Sitz, ohne Fahrt. Jeder Abbruch geht durch ihn.
func _stage_queue_row_hard(up: bool) -> void:
	if queue_tray_view == null:
		return
	for i in queue_tray_view.slot_roots.size():
		queue_tray_view.set_slot_riding(i, false)
		queue_tray_view.slot_emitter(i).global_position = \
			queue_tray_view.slot_home_position(i)
		queue_tray_view.slot_roots[i].global_position = \
			queue_tray_view.slot_home_position(i, true)
		queue_tray_view.set_slot_staged(i, up)
		_set_queue_slot_reflective(i, true)  # steht auf seinem Sitz über der Fläche

## Die Warteschlange rückt IN der Fläche auf (das Gleiten der Ghosts): die Belegung
## wandert mit, ihr Schwanz wird frei - dort fährt gleich je Würfel eine Plattform.
func _shift_queue_occupancy(shift: int) -> void:
	if shift <= 0:
		return
	var count := _queue_dice_up.size()
	for i in count:
		_queue_dice_up[i] = i + shift < count and _queue_dice_up[i + shift]

## Welche Träger-Sitze ein Zug geleert hat: das Warteschlangen-Fenster ist um die
## gezogenen Würfel weitergerückt, also verlassen genau diese Sitze den Vorrat.
func _drawn_carrier_seats(before: int) -> Array[int]:
	var seats: Array[int] = []
	var window := _queue_display_capacity()
	for d in range(before + window, next_draw_index + window):
		if d >= 0 and d < round_pool_kinds.size():
			seats.append(d)
	return seats

# --- Das Rundenende: der Pit-Inhalt IST der neue Pool ---------------------------

## Erst wenn der letzte Schluck liegt, fährt die letzte TEIL-Reihe ein - sonst
## erschiene im Pit ein Würfel, den der Tisch noch schluckt. Gewartet wird per
## Polling mit Lauf-Wache: ein Reset darf nicht auf ein Signal warten, das nie kommt.
func _flush_ablage_tail(generation: int, launched: GameRun) -> void:
	while _swallow_busy():
		await get_tree().process_frame
		if generation != _tray_stage_gen or run != launched:
			return
	if not _ablage_buffer.is_empty():
		var rest := _ablage_buffer.duplicate()
		_ablage_buffer.clear()
		_play_ablage_row(rest)
	while _ablage_entering > 0:
		await get_tree().process_frame
		if generation != _tray_stage_gen or run != launched:
			return

## Der KREISLAUF: was im Pit steht, IST der neue Pool - [Warteschlangen-Rest]
## [ungezogener Rest][Ablage], alles in Pit-Ordnung. Gemischt wurde nur jede
## Ablage-Reihe, EINMAL, beim Erscheinen.
func _reorder_pool_from_pit() -> void:
	if run == null:
		return
	var order: Array[DieDefinition] = []
	order.assign(round_pool_kinds.slice(next_draw_index, round_pool_kinds.size()))
	for item: Dictionary in _ablage_seats:
		order.append(item["def"])
	run.reorder_pool_full(order)

## Das Rundenende ist ein VIER-Schlag: die letzte Ablage-Reihe fährt ein, die
## Warteschlange geht ab, der Pit-Inhalt wird zum neuen Pool - und dann hebt die
## Plattform den Träger schlicht herauf. Kein blindes Glas, kein Tausch dahinter.
## Fire-and-forget mit Lauf- und Generationsmarke; jeder Abbruch landet hart.
func _play_tray_return() -> void:
	var generation := _tray_stage_gen
	var launched := run
	await _flush_ablage_tail(generation, launched)
	if generation != _tray_stage_gen or run != launched:
		return
	var exit := _lower_queue_row()
	if exit != null:
		await exit.finished
		if generation != _tray_stage_gen or run != launched:
			return
	if _pool_standing or pool_shaft == null or not is_instance_valid(pool_shaft):
		_stand_pool_tray_hard()
		return
	_reorder_pool_from_pit()
	# Der Träger steht ab hier auf seinem Heimat-Sitz und trägt den neuen Pool in
	# BUCH-Ordnung: die Reihenfolge bleibt, nur das Raster normalisiert sich (die
	# liegende Ablage steigt in den Schwebe-Stand). Dann hebt ihn die Plattform.
	_reset_ablage_hard()
	_reset_carrier_leaving()
	_carrier_shift = 0
	_stop_stage_tween(_carrier_tween)
	_carrier_tween = null
	_pool_standing = true
	pool_tray_view.visible = true
	pool_tray_view.global_position = _pool_tray_home - Vector3.UP * pool_shaft.park_y()
	_refresh_dice_trays()
	var rise := pool_shaft.run_rise([pool_tray_view], [_pool_tray_home], 0.0)
	if rise == null:
		_stand_pool_tray_hard()
		return
	await rise.finished
	if generation != _tray_stage_gen or run != launched:
		return
	_stand_pool_tray_hard()

## Der harte Endzustand des Vorrats: das Tray steht gefüllt auf seinem Platz, die
## Grube ist zu, die Ablage fort.
func _stand_pool_tray_hard() -> void:
	_pool_standing = true
	_pool_parked_field = {}
	_carrier_shift = 0
	_reset_ablage_hard()
	_reset_carrier_leaving()
	_seat_carrier_hard()
	if pool_shaft != null and is_instance_valid(pool_shaft):
		pool_shaft.settle_hard()
	# Wieder oben: die Aufspannung liegt jetzt sichtbar im Pool (Ort == POOL), die Bank
	# steht leer, bis der Spieler die Werkstatt öffnet oder den Laden schließt.
	if run != null:
		_refresh_dice_trays()
		_rebuild_bench_stage()
	# Der Vorrat spiegelt wieder - NACH dem Auffüllen, damit neu gebaute Slots die
	# Marke bekommen (ensure_capacity baut den Würfelkörper frisch).
	if pool_tray_view != null:
		ScreenReflection.set_reflective(pool_tray_view, true)

## Der EINE harte Aufräum-Pfad der ganzen Bühne: Ablage fort, Puffer leer, alle drei
## Maschinen bündig, alle Löcher zu, das Pool-Tray steht und die Warteschlange ist
## fort. Laufwechsel, Rundenstart und jeder Abbruch gehen durch ihn.
func _reset_tray_stage_hard() -> void:
	_tray_stage_gen += 1
	for item: Dictionary in _swallow_queue:
		_drop_stage_body(item.get("body"))
	_swallow_queue.clear()
	for lane in _swallow_bodies.size():
		_drop_stage_body(_swallow_bodies[lane])
		_swallow_bodies[lane] = null
	for shaft in _swallow_shafts + _queue_shafts:
		if shaft != null and is_instance_valid(shaft):
			shaft.settle_hard()
	_stop_queue_rides()
	_queue_staged = false
	for i in _queue_dice_up.size():
		_queue_dice_up[i] = false
	_stage_queue_row_hard(false)
	_migrate_bench_to_pool()  # Bühnen-Fahrt hart beenden, der Zielwürfel gehört dem Pool
	_settle_exchange_hard()  # und jeden laufenden Tausch aus dem Ausgabefach
	_settle_deck_glass_hard()  # und eine offene Glas-Ansicht
	_stand_pool_tray_hard()
#endregion

#region Die GLAS-ANSICHT
# Der Vorrat hat ZWEI Ansichten, und der RASTER-UMSCHALTER am Grubenrand legt um: die
# KÖRPER (die schwebenden Würfel) oder das RASTER. Im Raster versinkt der Vorrat per
# Plattform TIEF im Tisch (unter dem Glas darf nichts herausragen), der Gruben-Schirm
# fährt darüber zu und trägt die ANZEIGE - und darauf liegt das Netz-Raster des ganzen
# Vorrats, Sitz i = Zelle i. Ein Tipp darin bucht den Tausch, solange ein Neuzugang im
# Ausgabefach wartet, und wählt sonst das Werkstatt-Ziel; ein Zug legt um.
# ZWEI Wege hinein, EIN Weg hinaus: der UMSCHALTER öffnet den DAUER-MODUS (kein
# Rahmen, keine gemerkte Station - das Raster steht, wo der Spieler steht), der TIPP
# auf einen Neuzugang die enge Tausch-Frage (Rahmen und gemerkte Station wie bisher,
# Wegzoomen bricht ab). Rechtsklick schließt beide. Danach steht die RUNDEN-
# Konfiguration der Maschine wieder unverändert da (flach, ohne Schirm).

## Der Akzent des Glases: das Teal der Maschine, keine Wett-Farbe.
const DECK_GLASS_TINT := LiftShaftView.GLOW_COLOR

## Wie eng die Ansicht gerahmt wird: der Kehrwert ist die Bildfüllung der KNAPPEREN
## Kante (1,08 ≈ 93 %, Saum ~7 %); der geneigte Blick bildet die fernere Kante
## kleiner ab, gemessen füllt der ganze Rahmen darum ~81 % der Bildhöhe.
const DECK_GLASS_FRAME_MARGIN := 1.08

## Zugabe auf die gemessene Bildschirm-Pixelzahl des Lochs (Texel je Bildschirmpixel
## soll deutlich über 1 liegen, auch wenn der Spieler noch etwas näher kommt), und
## die Deckel: das Vielfache des Display-Rechtecks und die längste Kante in Pixeln.
const DECK_GLASS_OVERSAMPLE := 1.35
const DECK_GLASS_MAX_SCALE := 6.0
const DECK_GLASS_MAX_EDGE := 2048.0

## Die Kopfzeile ohne Neuzugang: sie sagt, was der Tipp tut - im Dauer-Modus wird
## gewählt, nicht getauscht.
const DECK_GLASS_TITLE := "Tippen wählt das Werkstatt-Ziel"

## Steht die Ansicht? Dieses Bit ist der EINE Schreiber, und die Marke schützt jede
## Fahrt. _deck_glass_pinned trennt die beiden Wege hinein: der DAUER-Modus des
## Umschalters bleibt stehen, die enge Tausch-Frage schließt sich selbst.
var _deck_glass := false
var _deck_glass_pinned := false
var _deck_glass_gen := 0
## Fährt der Vorrat schon wieder herauf? Der Abbruch kommt aus zwei Richtungen
## (Rechtsklick UND Kamerawechsel), und zweimal schließen hieße zweimal fahren.
var _deck_glass_closing := false
## Die Kamera-Lage VOR dem Tipp ({} = keine gemerkt): dorthin kehrt sie beim
## Schließen zurück. Wer selbst wegfährt, vergißt sie - er ist schon unterwegs.
var _deck_glass_home: Dictionary = {}

func deck_glass_open() -> bool:
	return _deck_glass

## Trägt das Pool-Tray seine STEHENDE Sitzordnung? In der Glas-Ansicht ist es bloß
## abgesenkt - sein Sitz-Plan bleibt der des stehenden Vorrats, nicht der des Trägers.
func _pool_seated_standing() -> bool:
	return _pool_standing or _deck_glass

func _deck_glass_window() -> DeckGlassView:
	if table_screen == null or table_screen.deck_glass_window == null \
			or not is_instance_valid(table_screen.deck_glass_window):
		return null
	return table_screen.deck_glass_window

## Die zwei Gesten des Rasters, einmal verdrahtet: Tippen wählt, Ziehen legt um.
func _setup_deck_glass() -> void:
	var window := _deck_glass_window()
	if window == null or window.cell_pressed.is_connected(_on_deck_glass_cell_pressed):
		return
	window.cell_pressed.connect(_on_deck_glass_cell_pressed)
	window.cells_reordered.connect(_on_deck_glass_reordered)

## Das Rechteck des Pool-Lochs in Display-Pixeln - genau darauf liegt das Raster.
## Welt +X ist Bildschirm-oben, Welt +Z Bildschirm-rechts.
func _deck_glass_rect() -> Rect2:
	if table_screen == null:
		return Rect2()
	var field := _pool_parked_field if not _pool_parked_field.is_empty() else _pool_field()
	if field.is_empty():
		return Rect2()
	var at: Vector3 = field["at"]
	var half: Vector2 = field["half"]
	var a := table_screen.world_to_pixel(Vector3(at.x + half.x, 0.0, at.z - half.y))
	var b := table_screen.world_to_pixel(Vector3(at.x - half.x, 0.0, at.z + half.y))
	return Rect2(a, b - a)

## Der Rahmen der Ansicht in Welt-XZ: das Pool-Loch VEREINIGT mit dem Neuzugangs-
## Bereich (der Schale) - gefragt wird nach einem Platz für den Würfel, also
## müssen beide im Bild stehen. half = (halbe Bildbreite, halbe Bildhöhe).
func _deck_glass_frame() -> Dictionary:
	if table_screen == null:
		return {}
	var field := _pool_parked_field if not _pool_parked_field.is_empty() else _pool_field()
	if field.is_empty():
		return {}
	var at: Vector3 = field["at"]
	var half: Vector2 = field["half"]
	var lo := Vector2(at.x - half.x, at.z - half.y)
	var hi := Vector2(at.x + half.x, at.z + half.y)
	if ausgabefach != null and is_instance_valid(ausgabefach) and ausgabefach.half.x > 0.0:
		lo = lo.min(ausgabefach.bounds_min())
		hi = hi.max(ausgabefach.bounds_max())
	var middle := (lo + hi) * 0.5
	return {"at": Vector3(middle.x, 0.0, middle.y),
		"half": Vector2((hi.y - lo.y) * 0.5, (hi.x - lo.x) * 0.5)}

## Die Kamera eng auf diesen Rahmen (kein Moduswechsel - die Station bleibt).
func _frame_deck_glass() -> void:
	var frame := _deck_glass_frame()
	if frame.is_empty():
		return
	camera_rig.frame_rect(frame["at"], frame["half"], DECK_GLASS_FRAME_MARGIN)

## Zurück an die gemerkte Station - idempotent, denn Wahl, Abbruch und der harte
## Weg gehen alle hier durch.
func _restore_deck_glass_camera() -> void:
	camera_rig.release_tilt_immediately()
	if _deck_glass_home.is_empty():
		return
	var home := _deck_glass_home
	_deck_glass_home = {}
	camera_rig.restore_pose(home)

## Der Sitz des offenen Neuzugangs (-1 = keiner). Er ist IMMER 0: offen liegt nur
## der oberste (VISIBLE_CAP 1), und exchange_pending_die nimmt ihn aus der Liste.
func _deck_glass_pending() -> int:
	return 0 if run != null and not run.pending_dice.is_empty() else -1

func _deck_glass_die() -> DieDefinition:
	var pending := _deck_glass_pending()
	return run.pending_dice[pending] if pending >= 0 else null

## Der gesäumte Sitz des Rasters: das aktuelle Ziel der Werkstatt (-1 = keins).
func _deck_glass_target() -> int:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop) or run == null:
		return -1
	return run.owned_pool.find(workshop.target_die())

## ÖFFNEN: der Vorrat sinkt TIEF und mit bestelltem Schirm, und erst wenn das Glas
## GESCHLOSSEN steht, geht das Raster darauf auf. Fire-and-forget mit Lauf- und
## Generationsmarke; jeder Abbruch landet hart.
## pinned = der DAUER-Modus des Umschalters: er rahmt NICHT um (an der Werkstatt-
## Station soll die Straße im Bild bleiben) und merkt sich darum auch keine Station.
func _open_deck_glass(pinned: bool) -> void:
	if _deck_glass or run == null or not _fach_swap_live():
		return
	if not pinned and _deck_glass_pending() < 0:
		return
	if pool_tray_view == null or table_screen == null:
		return
	var field := _pool_field()
	if field.is_empty():
		return
	_deck_glass = true
	_deck_glass_pinned = pinned
	_deck_glass_closing = false
	_deck_glass_gen += 1
	var generation := _deck_glass_gen
	var launched := run
	# Die enge Tausch-Frage ist eine eigene kleine Station: eng gerahmt und STILL,
	# und die Lage davor wird gemerkt, denn dorthin geht es beim Schließen zurück.
	if not pinned:
		_deck_glass_home = camera_rig.camera_pose()
		camera_rig.set_tilt_locked(true)
		_frame_deck_glass()
	_pool_standing = false
	_pool_parked_field = field
	# Versenkt spiegelt der Vorrat nicht - sein Bild geisterte sonst über der Fläche.
	ScreenReflection.set_reflective(pool_tray_view, false)
	var shaft := _pool_shaft_on(field)
	if shaft == null:
		_settle_deck_glass_hard()
		return
	var tween := shaft.run_park([], [], [], [], 0.0, Callable(),
		[pool_tray_view], [_pool_tray_home])
	if tween != null:
		await tween.finished
		if generation != _deck_glass_gen or run != launched:
			return
	_seat_deck_glass_hard()
	_show_deck_glass_window()

## Der harte Endzustand der offenen Ansicht: Grube offen, Plattform ganz unten, Glas
## darüber zu - und der Vorrat steht auf der Sohle.
func _seat_deck_glass_hard() -> void:
	if not _deck_glass or pool_tray_view == null:
		return
	var shaft := _pool_shaft_on(_pool_parked_field)
	if shaft == null:
		return
	if not shaft.riding():
		shaft.park_hard()
	pool_tray_view.visible = true
	pool_tray_view.global_position = _pool_tray_home - Vector3.UP * shaft.park_y()

## Das Raster auf das geschlossene Glas legen (idempotent - der Abgleich nach einer
## Buchung ruft denselben Weg).
func _show_deck_glass_window() -> void:
	var window := _deck_glass_window()
	if window == null or run == null or not _deck_glass:
		return
	var rect := _deck_glass_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	table_screen.place_deck_glass_window(rect, _deck_glass_resolution(rect))
	var die := _deck_glass_die()
	var head := "Wohin mit %s?" % die.display_name if die != null else DECK_GLASS_TITLE
	window.show_pool(head, run.owned_pool, pool_tray_view.columns, _deck_glass_target())

## Die Auflösung des Glas-Viewports: GEMESSEN an der stehenden Kamera. Die vier
## Weltecken des Lochs werden projiziert, und der Viewport bekommt so viele Pixel,
## daß auf jeden Bildschirmpixel mindestens ein Texel kommt (mal Zugabe). Das
## Seitenverhältnis bleibt das des Display-Rechtecks - sonst zöge sich das Raster.
func _deck_glass_resolution(rect: Rect2) -> Vector2i:
	var span := _deck_glass_screen_span(rect)
	if span.x <= 0.0:
		return Vector2i(rect.size.round())
	var factor := maxf(span.x / rect.size.x, span.y / rect.size.y) * DECK_GLASS_OVERSAMPLE
	factor = clampf(factor, 1.0, DECK_GLASS_MAX_SCALE)
	var wanted := (rect.size * factor).round()
	var cap := maxf(wanted.x, wanted.y)
	if cap > DECK_GLASS_MAX_EDGE:
		wanted = (wanted * (DECK_GLASS_MAX_EDGE / cap)).round()
	return Vector2i(wanted)

## Der Bildschirm-Fußabdruck des Lochs unter der jetzigen Kamera (leer = kein Bild).
func _deck_glass_screen_span(rect: Rect2) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if camera == null or table_screen == null or rect.size.x <= 0.0:
		return Vector2.ZERO
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)]:
		var world := table_screen.pixel_to_world(corner)
		if camera.is_position_behind(world):
			return Vector2.ZERO
		var at := camera.unproject_position(world)
		lo = lo.min(at)
		hi = hi.max(at)
	return hi - lo

func _hide_deck_glass_window() -> void:
	if table_screen != null:
		table_screen.hide_deck_glass_window()

## SCHLIESSEN - Wahl wie Abbruch gehen hier durch: Raster aus, Glas auf, der Vorrat
## steigt. Endzustand zuerst: der Sitz-Plan steht (mit dem Neuen an seinem Platz),
## gefahren wird bloß der Weg dorthin.
func _close_deck_glass() -> void:
	if not _deck_glass or _deck_glass_closing:
		return
	_deck_glass_closing = true
	_deck_glass_gen += 1
	var generation := _deck_glass_gen
	var launched := run
	_restore_deck_glass_camera()  # der Rückflug läuft neben der Auffahrt
	_hide_deck_glass_window()
	if pool_shaft == null or not is_instance_valid(pool_shaft) or pool_tray_view == null:
		_settle_deck_glass_hard()
		_sync_bench_migration()
		return
	_pool_standing = true
	pool_tray_view.visible = true
	pool_tray_view.global_position = _pool_tray_home - Vector3.UP * pool_shaft.park_y()
	_refresh_dice_trays()
	var rise := pool_shaft.run_rise([pool_tray_view], [_pool_tray_home], 0.0)
	if rise != null:
		await rise.finished
		if generation != _deck_glass_gen or run != launched:
			return
	_settle_deck_glass_hard()
	# Im Raster gewählt: die Bühnen-Fahrt wartet auf den stehenden Vorrat - jetzt
	# steht er, also fährt der Zielwürfel aufs Podest.
	_sync_bench_migration()

## Der EINE harte Aufräum-Pfad: Fenster fort, Bestellung zurück, die Maschine wieder
## in der RUNDEN-Konfiguration, der Vorrat steht. Laufwechsel, Rundenstart und jeder
## Abbruch gehen hier durch - ein abgebrochener Tween schuldet nichts.
func _settle_deck_glass_hard() -> void:
	if not _deck_glass:
		return
	_deck_glass_gen += 1
	_hide_deck_glass_window()
	_restore_deck_glass_camera()
	_deck_glass = false
	_deck_glass_pinned = false
	_deck_glass_closing = false
	if pool_shaft != null and is_instance_valid(pool_shaft):
		pool_shaft.settle_hard()
	# _deck_glass steht schon auf false: der EINE Schreiber stellt damit die flache,
	# schirmlose Runden-Konfiguration wieder her.
	if not _pool_parked_field.is_empty():
		_pool_shaft_on(_pool_parked_field)
	_stand_pool_tray_hard()

## Tipp auf ein Netz - die Zelle bedeutet zweierlei, und der Neuzugang entscheidet:
## WARTET einer im Ausgabefach, ist die Zelle sein Tausch-Ziel (gebucht SOFORT,
## Buchung vor dem Licht; der Alte kommt schlicht nicht mehr mit herauf, seine Instanz
## trägt per become längst den neuen Inhalt). Wartet KEINER, wählt sie wie der Tipp
## auf den Pool-Körper das Ziel der Serie - die Bühnen-Fahrt holt es, sobald der
## Vorrat wieder steht.
## Liegen nach einem Tausch noch weitere Neuzugänge, SCHLIESST die enge Frage nicht:
## der nächste rückt per Boden-Lieferung ins Fach nach (die SERIE). Der DAUER-Modus
## schließt ohnehin nie von selbst.
func _on_deck_glass_cell_pressed(index: int) -> void:
	if not _deck_glass or run == null:
		return
	if index < 0 or index >= run.owned_pool.size():
		return
	var pending := _deck_glass_pending()
	if pending < 0:
		_choose_workshop_target(run.owned_pool[index])
		_show_deck_glass_window()
		return
	if not run.exchange_pending_die(pending, index):
		return
	if run.pending_dice.is_empty() and not _deck_glass_pinned:
		_close_deck_glass()
		return
	_show_deck_glass_window()

## Netz auf Netz gezogen: der Vorrat wird umgelegt, das Raster folgt über pool_changed.
func _on_deck_glass_reordered(from_index: int, to_index: int) -> void:
	if not _deck_glass or run == null or _dice_editing_locked():
		return
	run.reorder_pool(from_index, to_index)

# --- Der RASTER-UMSCHALTER am Grubenrand -----------------------------------------
# Eine flache Taste auf dem freien Filz ÜBER dem Vorrats-Loch (die rechte Kante gehört
# Schale und Info-Säule, unter dem Loch beginnt die Werkbank). Sie legt zwischen KÖRPER
# und RASTER um und ist bedienbar, wo sie zu sehen ist (Pool- wie Werkstatt-Station,
# Freikamera) - dieselbe Bedingung, unter der überhaupt am Vorrat gerührt werden darf.

## Die Taste an den Grubenrand stellen (idempotent). Ihr Ort ist aus der POOL-
## Geometrie gerechnet wie der der Schale, nie an einer Fensterkante gemessen.
func _place_raster_switch() -> void:
	if table_screen == null or pool_tray_view == null:
		return
	var field := _pool_field()
	if field.is_empty():
		return
	if raster_switch == null or not is_instance_valid(raster_switch):
		raster_switch = RasterSwitchView.new()
		add_child(raster_switch)
	raster_switch.setup(RasterSwitchView.spot_beside(field["at"], field["half"]))

## Ihr Rechteck in Display-Pixeln (leer = sie steht nicht).
func _raster_switch_rect_px() -> Rect2:
	if table_screen == null or raster_switch == null or not is_instance_valid(raster_switch) \
			or raster_switch.half.x <= 0.0:
		return Rect2()
	var lo := raster_switch.bounds_min()  # (Welt-x, Welt-z)
	var hi := raster_switch.bounds_max()
	# Welt +X ist Bildschirm-oben, Welt +Z Bildschirm-rechts.
	var a := table_screen.world_to_pixel(Vector3(hi.x, 0.0, lo.y))
	var b := table_screen.world_to_pixel(Vector3(lo.x, 0.0, hi.y))
	return Rect2(a, b - a)

## Das SICHTBARE Rechteck (leer = in den Werkbank-Nahstufen oder während einer Fahrt).
func _raster_switch_rect() -> Rect2:
	if not _table_operable() or camera_rig.workshop_close or camera_rig.die_focus:
		return Rect2()
	return _raster_switch_rect_px()

## Darf jetzt umgelegt werden? Hinein nur, wo auch getauscht werden dürfte
## (_fach_swap_live); hinaus immer - ein stehendes Raster muß man loswerden.
func _raster_switch_live() -> bool:
	return _deck_glass or _fach_swap_live()

## Aufschrift, Ton und Griff je Bild - der Zeiger liegt auf dem Tisch.
func _sync_raster_switch() -> void:
	if raster_switch == null or not is_instance_valid(raster_switch):
		return
	raster_switch.set_open(_deck_glass)
	raster_switch.set_live(_raster_switch_live())
	var rect := _raster_switch_rect()
	if rect.size.x <= 0.0:
		raster_switch.set_hovered(false)
		return
	raster_switch.set_hovered(
		rect.has_point(_screen_pixel(get_viewport().get_mouse_position())))

## Der Druck auf die Taste (true = verbraucht). Blind fällt er durch - dann gehört
## der Klick der Navigation, wie auf leerem Fachboden.
func _forward_raster_switch_mouse(event: InputEventMouse, pixel: Vector2) -> bool:
	var rect := _raster_switch_rect()
	if rect.size.x <= 0.0 or pixel.x < 0.0 or not rect.has_point(pixel):
		return false
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not _raster_switch_live():
		return false
	_toggle_deck_glass()
	return true

## Umlegen: EIN Weg hinein (der Dauer-Modus) und der EINE Weg hinaus.
func _toggle_deck_glass() -> void:
	if _deck_glass:
		_close_deck_glass()
		return
	_open_deck_glass(true)
#endregion

# --- Der WETT-TRESEN ------------------------------------------------------------
# Die Nebenwetten sind körperlich, und ihre Timeline ist die des Spielers. DER
# SETZEN-KNOPF IST DER STELLPLATZ: vor dem Setzen liegt NICHTS (der Knopf nennt den
# Preis), beim Setzen WIRFT der Spieler seinen Einsatz von dessen Zuhause auf die
# Plattform seines Plots - und der Tisch SCHLUCKT ihn: vom Einsatz liegt danach nie
# mehr etwas. In derselben Fahrt kommt der GEWINN in Sicht. Kann die Wette mitten in
# der Runde noch kippen (decides_early), wartet er UNTEN in der offen bleibenden
# Grube und fährt erst bei der Erfüllung herauf; eine grün beginnende Wette zeigt
# ihren Gewinn sofort ausgefahren, und er sinkt beim Scheitern.
# Gefahren wird das je Plot von SEINER eigenen Sektion - drei Hebebühnen, drei feste
# Plätze in der Löcherliste, drei unabhängige Lebensläufe. Die Körper sind reine
# ANZEIGE: keine Buchung hängt an einem von ihnen, jede Zahl steht in GameRun.

## Die eine Rolle, die ein Plot trägt: sein GEWINN. Vom Einsatz liegt nichts, und die
## Zählplatte der Steuerwetten ist tot - ihre Rechnung reist als Licht.
const BET_ROLE_PRIZE := "prize"

## Der Schlüssel EINES Körper-Platzes: Plot plus Rolle. Der ORT (unten/oben) gehört
## bewusst NICHT hinein - der Gewinn behält beim Auffahren SEINEN Körper, sonst wäre
## die Erfüllung ein Neubau statt einer Fahrt.
static func _bet_slot(spot: int, role: String) -> String:
	return "%d|%s" % [spot, role]

static func _bet_slot_spot(key: String) -> int:
	return int(key.get_slice("|", 0))

## Einen Eintrag in die Liste seines Plots legen (Plot-Index -> Array).
static func _bet_push(map: Dictionary, spot: int, entry: Dictionary) -> void:
	if not map.has(spot):
		map[spot] = []
	(map[spot] as Array).append(entry)

func _side_bet_panel() -> SideBetPanel:
	if table_screen == null or table_screen.side_bet_window == null \
			or not is_instance_valid(table_screen.side_bet_window):
		return null
	return table_screen.side_bet_window

## Die Plätze des Tresens - das Fenster meldet sie, die Körper gehören hierher.
func _bet_rects() -> Array[Rect2]:
	var empty: Array[Rect2] = []
	var panel := _side_bet_panel()
	return panel.counter_rects() if panel != null else empty

## Der Tresen zeigt nur, solange sein Fenster wirklich auf dem Tisch steht: ein
## abgebautes Fenster (Hub-Stufe zu niedrig, Laufwechsel) läßt nichts liegen - und
## ohne Sicht fährt auch keine Maschine, denn ihr Loch säße auf fremder Anzeige.
func _bet_counter_visible() -> bool:
	var panel := _side_bet_panel()
	return panel != null and panel.visible and panel.counter_laid_out()

## Hat das Fenster überhaupt schon ein Rechteck? Ohne Maß meldet es keine Plätze -
## und ohne Plätze schreibt niemand an ihm.
func _bet_counter_laid_out() -> bool:
	var panel := _side_bet_panel()
	return panel != null and panel.counter_laid_out()

## Gefahren wird, sobald der Tresen SICHTBAR steht und der Tisch Bedienung nimmt -
## nicht erst in einer Wett-Pose: die Auffahrt einer erfüllten Wette spielt SOFORT
## (Spieler-Entscheid 2026-08-26). Nur eine laufende Kamerafahrt und ein verdeckter
## Tresen sparen den Auftritt auf (_bet_pending_rise).
func _bet_counter_watched() -> bool:
	return _bet_counter_visible() and _table_operable()

## Die reine Regel des Fensters, auf die laufende Auslage angewandt: Plot-Index ->
## Liste von LIE_*. EINE Quelle für Bestand UND Ort (unten/oben).
func _bet_lies() -> Dictionary:
	var panel := _side_bet_panel()
	if panel == null or run == null:
		return {}
	# Der Lebenszyklus wird dem Fenster GEMELDET, und es antwortet mit der reinen
	# Regel: EINE Quelle für Körper, Ort und das Schweigen des Melders.
	panel.set_lifecycle(_bet_stage, _bet_fulfilled, _bet_failed, _bet_won)
	return panel.lies()

## Was auf dem Tresen stehen soll: Platz-Schlüssel -> Beschreibung. WELCHER Plot was
## trägt, entscheidet die reine Regel des Fensters; hier steht nur, WAS es ist und ob
## es unten in der Grube wartet.
func _bet_stock() -> Dictionary:
	var out: Dictionary = {}
	var panel := _side_bet_panel()
	if panel == null or run == null:
		return out
	var lies := _bet_lies()
	for index: int in lies:
		if index < 0 or index >= panel.offers.size():
			continue
		var bet: SideBet = panel.offers[index]
		if bet == null:
			continue
		for lie: String in lies[index]:
			var prize := _bet_price_spec(bet)
			prize["spot"] = index
			prize["role"] = BET_ROLE_PRIZE
			prize["pit"] = lie == SideBetPanel.LIE_PRIZE_PIT
			out[_bet_slot(index, BET_ROLE_PRIZE)] = prize
	return out

## Der Körper eines GEWINNS - was die Wette NENNT, liegt da: Geld als echte
## Stückelung, Energie als Stück Kondensator-Bank, ein Einzelstück als geprägte
## Marke. Und jedes Paket als versiegelte Kassette IHRER Sorte und Größe: die stehen
## seit dem Auswürfeln der Auslage fest, also wirbt der Tresen mit dem, was er wirklich
## ausschüttet.
func _bet_price_spec(bet: SideBet) -> Dictionary:
	var factor := run.side_bet_payout_factor()
	match bet.payout_kind:
		SideBet.Payout.MONEY:
			return {"body": "chips",
				"amount": CharmEffects.side_bet_money(bet.payout_money * factor, run.charm_ids())}
		SideBet.Payout.ENERGY:
			return {"body": "energy", "count": bet.payout_energy * factor}
		SideBet.Payout.COMBO_LEVEL:
			return {"body": "token", "text": "LVL+1", "tint": CasinoStyle.GOLD_INTENSE}
		SideBet.Payout.PRESS_BOOST:
			return {"body": "token", "text": "PRESSE",
				"tint": PackDrawerView.COLORS[Pack.SHELF_SPECIAL]}
		SideBet.Payout.SPECIAL:
			return {"body": "cell", "sort": Pack.SHELF_SPECIAL,
				"tier": Pack.TIER_NORMAL, "count": 1}
		SideBet.Payout.PACK:
			return _bet_pack_spec(bet, 1)
	return _bet_pack_spec(bet, maxi(bet.reward_packs * factor, 1))

## Die Kassetten eines Paket-Gewinns in seiner echten Sorte und Größe.
func _bet_pack_spec(bet: SideBet, count: int) -> Dictionary:
	return {"body": "cell", "sort": Pack.shelf_for_pack_type(bet.reward_pack_type),
		"tier": bet.reward_pack_tier, "count": count}

## Die Signatur eines Platzes: eine andere heißt ANDERER Körper. Der ORT (unten/oben)
## steht bewusst NICHT darin - die Auffahrt ist eine FAHRT desselben Körpers, kein
## Neubau.
func _bet_spec_key(spec: Dictionary) -> String:
	return "%s|%s|%d|%d|%d|%s|%s" % [spec.get("body", ""), spec.get("sort", ""),
		int(spec.get("tier", Pack.TIER_NORMAL)), int(spec.get("count", 0)),
		int(spec.get("amount", 0)), spec.get("text", ""), spec.get("role", "")]

## Wo ein Körper AUF seinem Plot sitzt: mittig - die Regel gehört dem Fenster.
func _bet_seat_at(spot: int) -> Vector3:
	var rects := _bet_rects()
	if spot < 0 or spot >= rects.size():
		return Vector3.ZERO
	return _data_cell_seat(SideBetPanel.seat_in(rects[spot]))

## Der EINE idempotente Schreiber des Tresens: was stehen soll, steht - was nicht
## mehr hingehört, fährt hinaus, und was unten warten soll, wartet in seiner offenen
## Grube. GRADE_RISE fährt die Hebebühnen, swap heißt zusätzlich, dass die
## abgeräumten Körper dabei durchs Band hinausfahren, statt still zu verschwinden.
func _write_bet_counter(grade := ShopController.GRADE_STAND,
		swap := false) -> void:
	if table_screen == null or not _bet_counter_laid_out():
		return
	# Die Abgangsware, die schon VOR diesem Schreiber unterwegs war: nur sie räumt
	# er beim Settle - was er selbst gleich auf die Reise schickt, fährt erst noch.
	var stale: Dictionary = {}
	for old_spot: int in _bet_leaving:
		stale[old_spot] = (_bet_leaving[old_spot] as Array).duplicate()
	var watched := _bet_counter_watched()
	var rising := grade == ShopController.GRADE_RISE and watched
	if grade == ShopController.GRADE_RISE and not watched:
		# Der aufgesparte Auftritt wartet GANZ: ein harter Stand verschlänge die
		# AUSGANGSLAGE der Fahrt (den Park), und der nachgeholte Auftritt fände nichts
		# mehr zu fahren - gemessen sprang der Gewinn in der Gruben-Pose in EINEM Bild
		# von -2,00 auf 0,00. Nur der gelandete Einsatz darf nicht liegen bleiben.
		_bet_pending_rise = true
		_drop_bet_swallow()
		return
	if rising:
		_bet_pending_rise = false
	var show := _bet_counter_visible()
	var wanted := _bet_stock()
	var plots := _bet_rects()
	# Je Plot: was hinausgeht, was hereinkommt, was stehen bleibt.
	var outgoing: Dictionary = {}
	var entering: Dictionary = {}
	var staying: Dictionary = {}
	# Was seinen Platz verliert (oder anders aussieht), verläßt ihn: mit laufender
	# Maschine durchs Band, sonst still.
	for key: String in bet_bodies.keys():
		var kept: Dictionary = wanted.get(key, {})
		if not kept.is_empty() and String(_bet_keys.get(key, "")) == _bet_spec_key(kept):
			continue
		var spot := _bet_slot_spot(key)
		var leaving: Node3D = bet_bodies[key]
		var was_at: Vector3 = _bet_seats.get(key, Vector3.ZERO)
		bet_bodies.erase(key)
		_bet_keys.erase(key)
		_bet_seats.erase(key)
		if swap and rising and spot >= 0 and spot < plots.size() \
				and is_instance_valid(leaving):
			_set_bet_hovered(leaving, false)  # der Griff sitzt am Körper, nicht am Ort
			_bet_push(outgoing, spot, {"body": leaving, "spot": spot, "target": was_at})
			_bet_note_leaving(spot, leaving)
		else:
			_free_bet_body(leaving)
	# Der gelandete EINSATZ gehört jetzt der Maschine: sie schluckt ihn in derselben
	# Fahrt, in der der Gewinn hereinkommt. Sein Sitz ist, wo er WIRKLICH liegt -
	# ein Stapel fiele sonst beim Senken in sich zusammen.
	for spot: int in _bet_swallow.keys():
		var stake: Dictionary = _bet_swallow[spot]
		for body: Node3D in stake["bodies"]:
			if body == null or not is_instance_valid(body):
				continue
			if not (rising and spot >= 0 and spot < plots.size()):
				_free_bet_body(body)
				continue
			_bet_note_leaving(spot, body)
			_bet_push(outgoing, spot, {"body": body, "spot": spot,
				"target": body.global_position, "height": float(stake["height"])})
	_bet_swallow.clear()
	for key: String in wanted.keys():
		var spec: Dictionary = wanted[key]
		var spot := int(spec["spot"])
		if spot < 0 or spot >= plots.size():
			continue
		var target := _bet_seat_at(spot)
		var body: Node3D = bet_bodies.get(key)
		var fresh := body == null or not is_instance_valid(body)
		if fresh:
			body = _spawn_bet_body(spec, target)
			if body == null:
				continue
			bet_bodies[key] = body
			_bet_keys[key] = _bet_spec_key(spec)
		_bet_seats[key] = target
		body.visible = show
		var entry := {"body": body, "spot": spot, "target": target}
		if fresh:
			_bet_push(entering, spot, entry)
		else:
			_bet_push(staying, spot, entry)
	for spot in SideBetPanel.OFFER_COUNT:
		var to_pit := bool(wanted.get(_bet_slot(spot, BET_ROLE_PRIZE),
			{}).get("pit", false))
		# Geräumt wird nur, was DIESER Schreiber anfasst: die laufende Fahrt eines
		# unveränderten Nachbarn spielt zu Ende (ihr Endzustand steht längst) - sonst
		# schluckte jeder zweite Klick die Schluck-Fahrt des ersten.
		if rising and not entering.has(spot) and not outgoing.has(spot) \
				and to_pit == _bet_parked.has(spot) and _bet_shaft_riding(spot):
			continue
		_settle_bet_shaft(spot, stale.get(spot, []) as Array)
		_run_bet_plot(spot, entering.get(spot, []), outgoing.get(spot, []),
			staying.get(spot, []), to_pit, rising, show)

## Ein frisch gebauter Körper für einen Platz (null = unbekannte Bauform). Er liegt
## in ECHTER Größe da und darf über seinen Plot hinausragen - der Schacht mißt an ihm.
func _spawn_bet_body(spec: Dictionary, target: Vector3) -> Node3D:
	var body_kind := String(spec.get("body", ""))
	if body_kind == "cell":
		var cell := _spawn_data_cell(String(spec.get("sort", Pack.SHELF_SPECIAL)),
			int(spec.get("tier", Pack.TIER_NORMAL)), target)
		cell.set_count(maxi(int(spec.get("count", 1)), 1))
		cell.badge_on_face = true  # neben der Karte läge die Marke im Nachbarplatz
		cell.set_body_scale(PackDrawerView.CASSETTE_SCALE)
		return cell
	var prize := BetPrizeView.new()
	add_child(prize)
	var tint: Color = spec.get("tint", CasinoStyle.GOLD_INTENSE)
	match body_kind:
		"chips":
			prize.setup_chips(int(spec.get("amount", 0)))
		"energy":
			prize.setup_energy(int(spec.get("count", 1)))
		"token":
			prize.setup_token(String(spec.get("text", "")), tint)
		_:
			remove_child(prize)
			prize.queue_free()
			return null
	prize.seat_hard(target)
	return prize

## Wie hoch ein Tresen-Körper über der Fläche steht - der Schacht muß tief genug
## sein, dass er beim Sinken ganz darin verschwindet.
func _bet_body_height(body: Node3D) -> float:
	if body is BetPrizeView:
		return (body as BetPrizeView).body_height()
	if body is DataCellView:
		return DataCellView.DEPTH * PackDrawerView.CASSETTE_SCALE
	return 0.0

## Hart auf seinen Platz - der Endzustand steht zuerst, gefahren wird nur der Weg.
func _seat_bet_body(body: Node3D, target: Vector3) -> void:
	if body is DataCellView:
		(body as DataCellView).lie_on_glass(target)
	elif body is BetPrizeView:
		(body as BetPrizeView).seat_hard(target)
	else:
		body.global_position = target

## Ein Körper taucht an Ort und Stelle auf - der Weg ohne Maschine (niemand sieht
## hin, also fährt nichts).
func _appear_bet_body(body: Node3D) -> void:
	if body is DataCellView:
		(body as DataCellView).materialize()
	elif body is BetPrizeView:
		(body as BetPrizeView).materialize()

func _flare_bet_body(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body is DataCellView:
		(body as DataCellView).flare()
	elif body is BetPrizeView:
		(body as BetPrizeView).flare()

func _set_bet_hovered(body: Node3D, on: bool) -> void:
	if body is DataCellView:
		(body as DataCellView).set_hovered(on)
	elif body is BetPrizeView:
		(body as BetPrizeView).set_hovered(on)

func _free_bet_body(body: Variant) -> void:
	if body == null or not is_instance_valid(body):
		return
	var node: Node3D = body
	remove_child(node)
	node.queue_free()

func _bodies_of(entries: Array) -> Array:
	var out: Array = []
	for entry: Dictionary in entries:
		out.append(entry["body"])
	return out

func _release_bet_bodies(bodies: Array) -> void:
	# Untypisiert: ein Band-Callback darf eine schon freigegebene Referenz reichen.
	for body in bodies:
		for spot: int in _bet_leaving:
			(_bet_leaving[spot] as Array).erase(body)
		_free_bet_body(body)

## Der gelandete EINSATZ, den keine Fahrt mehr schluckt: er gehört ab der Landung der
## Maschine, also verschwindet er mit ihr - liegen bleiben darf er nie.
func _drop_bet_swallow() -> void:
	for spot: int in _bet_swallow:
		for body: Node3D in (_bet_swallow[spot] as Dictionary)["bodies"]:
			_free_bet_body(body)
	_bet_swallow.clear()

## Merkt einen Abgangs-Körper unter seinem Plot.
func _bet_note_leaving(spot: int, body: Node3D) -> void:
	var list: Array = _bet_leaving.get(spot, [])
	list.append(body)
	_bet_leaving[spot] = list

func _bet_shaft_riding(spot: int) -> bool:
	if spot < 0 or spot >= bet_shafts.size():
		return false
	var shaft := bet_shafts[spot]
	return shaft != null and is_instance_valid(shaft) and shaft.riding()

## Die SEKTION EINES Plots: seine eigene Hebebühne mit seinem eigenen Loch. Sie kennt
## sechs Wege - Auftritt nach oben, Auftritt in den PARK (Loch bleibt offen, die Ware
## wartet sichtbar unten), Schluck-plus-Auftritt in beide Richtungen, Auffahrt aus dem
## Park, Abgang aus dem Park und Abgang von oben. Welcher es ist, sagt der Bestand.
## staying sind die Körper, die stehen bleiben und im offenen Loch mitfahren müssen.
func _run_bet_plot(spot: int, entering: Array, outgoing: Array, staying: Array,
		to_pit: bool, rising: bool, show: bool) -> void:
	var here := entering + outgoing + staying
	if here.is_empty() or table_screen == null:
		_release_bet_bodies(_bodies_of(outgoing))
		_bet_parked.erase(spot)
		_drop_bet_cover(spot)
		return
	var was_parked := _bet_parked.has(spot)
	var park: Dictionary = _bet_parked.get(spot, {})
	# Das Loch IST der Setzen-Knopf - für jede Fahrt und für den Park dasselbe
	# Rechteck. Eine geparkte Grube behält nur ihre TIEFE: neu gemessen ließe sie die
	# wartende Ware springen.
	var field := _bet_plot_field(spot)
	var deep: float = float(park["depth"]) if was_parked else _bet_shaft_depth(here)
	var shaft := _bet_shaft_on(spot, field, deep)
	if shaft == null:
		_release_bet_bodies(_bodies_of(outgoing))
		_bet_parked.erase(spot)
		_drop_bet_cover(spot)
		return  # ohne gemeldeten Plot bleibt es beim harten Stand
	# Der SCHIRM ist Teil des Park-Endzustands: nur eine parkende Grube bestellt ihn,
	# und er trägt die EINE Gewinn-Zeile des Fensters (der Schacht kennt keine Wetten).
	# Wer aus dem PARK fährt, nimmt ihn MIT: in der Fahrt rollt er sichtbar zur Seite,
	# und erst wenn sie steht, erlischt die Bestellung. Vorher geworfen verschwände er
	# in EINEM Bild - der Gewinn stiege dann aus einer Grube, die nie offen war.
	var cover_rides := was_parked and not to_pit and rising
	if to_pit:
		shaft.order_cover(_bet_cover_text(spot), _bet_cover_tint(spot))
		shaft.order_cover_goal(_bet_cover_goal(spot), _bet_cover_goal_tint(spot))
	elif not cover_rides:
		shaft.drop_cover()
	# ENDZUSTAND ZUERST: jeder bleibende Körper steht hart auf seinem Platz - im Park
	# um die Parkhöhe tiefer -, und erst dann fährt die Maschine den Weg dorthin.
	var drop := shaft.park_y() if to_pit else 0.0
	for entry: Dictionary in entering + staying:
		_seat_bet_body(entry["body"], (entry["target"] as Vector3) - Vector3.UP * drop)
	if to_pit:
		_bet_parked[spot] = {"depth": deep}
	else:
		_bet_parked.erase(spot)
	var out_bodies := _bodies_of(outgoing)
	if not rising:
		# Niemand sieht hin (oder es ist ein harter Stand): alles steht sofort.
		_release_bet_bodies(out_bodies)
		if show:
			if to_pit:
				_park_bet_shaft(spot)
			for entry: Dictionary in entering:
				_appear_bet_body(entry["body"])
		return
	var in_bodies := _bodies_of(entering)
	var swept := _release_bet_bodies.bind(out_bodies)
	var tween: Tween = null
	if to_pit:
		# Der Gewinn kommt in Sicht und BLEIBT unten: die Grube steht offen.
		tween = shaft.run_park(out_bodies, _seats_of(outgoing), in_bodies,
			_seats_of(entering), 0.0, swept, _bodies_of(staying), _seats_of(staying))
	elif was_parked and in_bodies.is_empty() and out_bodies.is_empty():
		tween = shaft.run_rise(_bodies_of(staying), _seats_of(staying), 0.0)
	elif was_parked and in_bodies.is_empty():
		tween = shaft.run_leave_park(out_bodies, _seats_of(outgoing), 0.0, swept,
			_bodies_of(staying), _seats_of(staying))
	elif in_bodies.is_empty():
		tween = shaft.run_exit(out_bodies, _seats_of(outgoing), 0.0, swept,
			_bodies_of(staying), _seats_of(staying))
	elif out_bodies.is_empty():
		tween = shaft.run_cycle(in_bodies, _seats_of(entering), 0.0,
			_bodies_of(staying), _seats_of(staying))
	else:
		tween = shaft.run_swap(out_bodies, _seats_of(outgoing), in_bodies,
			_seats_of(entering), 0.0, swept, _bodies_of(staying), _seats_of(staying))
	if tween == null:
		_release_bet_bodies(out_bodies)
		if cover_rides:
			shaft.drop_cover()  # ohne Fahrt gibt es nichts mitzunehmen
		if to_pit and show:
			_park_bet_shaft(spot)  # der Park ist ein Endzustand, er steht auch ohne Fahrt
		return
	tween.tween_callback(func() -> void:
		if cover_rides and is_instance_valid(shaft):
			shaft.drop_cover()  # die Fahrt steht, der Schirm ist zur Seite gerollt
		for body: Node3D in in_bodies:
			_flare_bet_body(body))

func _seats_of(entries: Array) -> Array:
	var out: Array = []
	for entry: Dictionary in entries:
		out.append(entry["target"])
	return out

## Was auf dem SCHIRM einer geparkten Grube steht: die Gewinn-Beschriftung, die der
## Setzen-Knopf schon nennt. EINE Textquelle - hier wird nichts formuliert.
func _bet_cover_text(spot: int) -> String:
	var panel := _side_bet_panel()
	return panel.prize_label(spot) if panel != null else ""

func _bet_cover_tint(spot: int) -> Color:
	var panel := _side_bet_panel()
	return panel.prize_accent(spot) if panel != null else CasinoStyle.GOLD_INTENSE

## Und die STEHENDE Zeile: Bedingung plus Live-Stand, dieselbe, die der Sitz als
## Melder trägt. EINE Formulierung aus DENSELBEN Stats - hier wird nichts gerechnet.
func _bet_cover_goal(spot: int) -> String:
	var panel := _side_bet_panel()
	return panel.meter_line(spot) if panel != null else ""

func _bet_cover_goal_tint(spot: int) -> Color:
	var panel := _side_bet_panel()
	return panel.meter_tint(spot) if panel != null else CasinoStyle.GOLD_INTENSE

## Zieht die stehende Zeile je geparkter Grube nach - gerufen aus der EINEN
## Stats-Stelle, nachdem das Fenster seine Melder gestellt hat.
func _sync_bet_cover_goals() -> void:
	for spot in mini(bet_shafts.size(), SideBetPanel.OFFER_COUNT):
		var shaft := bet_shafts[spot]
		if shaft == null or not is_instance_valid(shaft) or not shaft.has_cover():
			continue
		shaft.order_cover_goal(_bet_cover_goal(spot), _bet_cover_goal_tint(spot))

## Ein Plot parkt nicht mehr: seine Schirm-Bestellung erlischt. Ein Schirm ohne Grube
## darunter wäre ein Deckel über der blanken Anzeige.
func _drop_bet_cover(spot: int) -> void:
	if spot < 0 or spot >= bet_shafts.size():
		return
	var shaft := bet_shafts[spot]
	if shaft != null and is_instance_valid(shaft):
		shaft.drop_cover()

## Der Grundriß EINES Plots: sein Stellplatz, sonst nichts. Das Loch hat EXAKT die
## Maße des Setzen-Knopfs (und seine Eckenrundung) - die Grubenkante IST die Form des
## Knopfs, und der Plot trägt jeden Körper des Katalogs ganz.
func _bet_plot_field(spot: int) -> Rect2:
	var rects := _bet_rects()
	if spot < 0 or spot >= rects.size():
		return Rect2()
	return rects[spot]

## Die Eckenrundung dieses Lochs - gemeldet vom Fenster, das auch seine Fassung malt.
## Hier wird nichts gerechnet: eine zweite Zahl wäre eine zweite Form.
func _bet_plot_radius() -> float:
	var panel := _side_bet_panel()
	return panel.counter_plot_radius() if panel != null else 0.0

## Wie hoch EIN Eintrag über der Fläche aufragt. Ein geworfener Einsatz meldet sein
## Maß mit (ein Chip-Stapel ist kein Körper, den man messen könnte).
func _bet_entry_height(entry: Dictionary) -> float:
	if entry.has("height"):
		return float(entry["height"])
	return _bet_body_height(entry["body"])

## Wie tief die Sektion eines Plots fährt: das gewohnte Schachtmaß der Auslagen,
## mindestens aber so tief, dass das HÖCHSTE beteiligte Stück durch sein Öffnungsband
## paßt (Stückhöhe x SHAFT_ROOM) - im Kauf-Zyklus ist das meist der Einsatz-Stapel.
## EIN Maß für alle Fahrten, und der Park endet genau darauf.
func _bet_shaft_depth(entries: Array) -> float:
	var tallest := 0.0
	for entry: Dictionary in entries:
		tallest = maxf(tallest, _bet_entry_height(entry))
	return maxf(VitrineView.shaft_depth(), tallest * VitrineView.SHAFT_ROOM)

## Wie weit die Sektion eines Plots hinter ihrer Öffnung Platz nehmen darf: bis an
## den NACHBAR-Plot, nicht weiter. Die drei Plots stehen in einer Spalte, ihre
## Maschinen schieben längs derselben Achse - ein Hohlraum unter dem offenen Loch der
## Nachbarin läse sich dort als schwarzer Balken quer durch die Grube.
func _bet_cavity_reach() -> float:
	var rects := _bet_rects()
	if table_screen == null or rects.size() < 2:
		return 0.0
	var above: Rect2 = rects[0]
	var below: Rect2 = rects[1]
	var a := table_screen.pixel_to_world(Vector2(above.get_center().x, above.end.y))
	var b := table_screen.pixel_to_world(Vector2(below.get_center().x, below.position.y))
	# Vor und hinter dem Hohlraum steht je eine Wand - die zählen mit.
	return maxf(absf(a.x - b.x) - LiftShaftView.WALL * 2.0, 0.05)

## Die Sektion EINES Wett-Plots, auf ein Display-Rechteck gestellt (null = keine
## Spur). Je Plot ein eigener Schacht mit eigenem, festem Platz in der Löcherliste:
## zwei geparkte Gruben dürfen einander nicht schließen.
func _bet_shaft_on(spot: int, field: Rect2, deep: float) -> LiftShaftView:
	if table_screen == null or spot < 0 or spot >= SideBetPanel.OFFER_COUNT \
			or field.size.x <= 0.0 or field.size.y <= 0.0:
		return null
	while bet_shafts.size() < SideBetPanel.OFFER_COUNT:
		bet_shafts.append(null)
	var shaft := bet_shafts[spot]
	if shaft == null or not is_instance_valid(shaft):
		var slot := TableScreen.side_bet_pit(spot)
		shaft = LiftShaftView.new("BetShaft%d" % spot)
		add_child(shaft)
		shaft.opened.connect(func(at: Vector3, hole: Vector2) -> void:
			table_screen.set_lift_pit(slot, at, hole, _bet_plot_radius()))
		shaft.closed.connect(func() -> void:
			table_screen.clear_pit(slot))
		bet_shafts[spot] = shaft
	shaft.deck_skin = table_screen.display_skin()
	shaft.order_skin(PIT_SKIN)
	shaft.cavity_reach = _bet_cavity_reach()
	shaft.travel_share = BET_PIT_DIVE  # und der EINE Besteller der Tieffahrt
	var a := table_screen.pixel_to_world(field.position)
	var b := table_screen.pixel_to_world(field.end)
	shaft.setup(table_screen.pixel_to_world(field.get_center()),
		Vector2(absf(a.x - b.x), absf(a.z - b.z)) * 0.5, deep)
	return shaft

## Der EINE Schreiber des PARK-Endzustands: die Sektion steht auf dem Loch ihres
## Plots, ganz unten, Schirm darüber. Idempotent - dasselbe Feld schneidet nicht neu,
## und eine laufende Fahrt schreibt ihren Zustand selbst.
func _park_bet_shaft(spot: int) -> void:
	var park: Dictionary = _bet_parked.get(spot, {})
	if park.is_empty():
		return
	var shaft := _bet_shaft_on(spot, _bet_plot_field(spot), float(park["depth"]))
	if shaft == null or shaft.riding():
		return
	# Ein Neuschnitt baut den Körper neu, seine Platte steht dann wieder bündig - und
	# genau daran erkennt der Abgleich, dass der Park nachzustellen ist.
	if not shaft.visible or not is_equal_approx(shaft.platform_y(), -shaft.park_y()):
		shaft.park_hard()

## Der Abbruch der Maschine: jede Sektion bündig, jedes Loch zu - und was hinausfuhr,
## ist frei. Der EINE Aufräum-Pfad; die drei denkbaren Reste (offenes Loch, geparkte
## Grube, verwaister Abgangs-Körper) sterben hier zusammen. Was WEITER parken soll,
## stellt der Schreiber gleich danach wieder hin - bzw. _sync_bet_counter je Bild.
func _settle_bet_shafts() -> void:
	for shaft in bet_shafts:
		if shaft != null and is_instance_valid(shaft):
			shaft.settle_hard()  # nimmt den Schirm mit zurück
	var leaving: Array = []
	for spot: int in _bet_leaving:
		leaving.append_array(_bet_leaving[spot])
	_release_bet_bodies(leaving)

## Der Abbruch EINER Sektion: nur ihr Loch, nur ihre Abgangsware - die Fahrten der
## Nachbarn gehen sie nichts an. leaving nennt, was freizugeben ist (der Schreiber
## reicht hier nur die ALTE Ware, seine frisch geschluckte fährt erst noch).
func _settle_bet_shaft(spot: int, leaving: Array = []) -> void:
	if spot >= 0 and spot < bet_shafts.size():
		var shaft := bet_shafts[spot]
		if shaft != null and is_instance_valid(shaft):
			shaft.settle_hard()  # nimmt den Schirm mit zurück
	_release_bet_bodies(leaving.duplicate())

## Laufwechsel: der Tresen des alten Laufs liegt nirgends mehr - und was noch flog,
## fliegt nicht weiter.
func _drop_bet_bodies() -> void:
	for key: String in bet_bodies:
		_free_bet_body(bet_bodies[key])
	bet_bodies.clear()
	_bet_keys.clear()
	_bet_seats.clear()
	_bet_parked.clear()
	_drop_bet_swallow()
	_bet_pending_rise = false
	_bet_won.clear()
	_bet_fulfilled.clear()
	_bet_failed.clear()
	_bet_stage = SideBetPanel.STAGE_NONE
	for shaft in bet_shafts:
		if shaft != null and is_instance_valid(shaft):
			shaft.drop_cover()  # die Bestellung des alten Laufs gilt nicht mehr
	_settle_bet_shafts()
	_settle_throws()

## Je Bild: die Körper stehen nur, solange der Tresen zu sehen ist, und der Griff
## hebt an, was OBEN unter dem Zeiger steht (die Magazin-Geste - gefragt, nie
## gemeldet); geparkte Ware bleibt liegen, ihre Hover-Antwort ist der Schirm.
## Und die GEPARKTEN Gruben stehen, solange das Fenster steht: sie sind Möbel, nicht
## Zeremonie - ein fremder Aufräum-Pfad (Vorhangfall, Laufwechsel) schließt sie, und
## hier stehen sie beim nächsten Hinsehen wieder.
func _sync_bet_counter() -> void:
	if not _bet_counter_laid_out():
		return
	# Ein aufgesparter Auftritt fährt, sobald jemand hinsieht - EINMAL.
	if _bet_pending_rise and _bet_counter_watched():
		_bet_pending_rise = false
		_write_bet_counter(ShopController.GRADE_RISE, true)
	var show := _bet_counter_visible()
	var pixel := Vector2(-1, -1)
	if show and _table_operable():
		pixel = _screen_pixel(get_viewport().get_mouse_position())
	var rects := _bet_rects()
	for key: String in bet_bodies:
		var body: Node3D = bet_bodies[key]
		if body == null or not is_instance_valid(body):
			continue
		if body.visible != show:
			body.visible = show
		var spot := _bet_slot_spot(key)
		# Was UNTEN wartet, hebt sich nicht: der Schirm ist die Hover-Antwort der
		# geparkten Grube, der Griff gehört nur oben stehenden Körpern.
		_set_bet_hovered(body, not _bet_parked.has(spot)
			and pixel.x >= 0.0 and spot >= 0 and spot < rects.size()
			and rects[spot].has_point(pixel))
	for spot: int in _bet_parked:
		if spot < 0 or spot >= bet_shafts.size():
			continue
		var shaft := bet_shafts[spot]
		if shaft == null or not is_instance_valid(shaft):
			continue
		# Der SCHIRM sagt, was unten liegt - aber nur, solange der Zeiger auf dem Plot
		# steht. Gefragt je Bild, dieselbe Griff-Grammatik wie die Körper darüber, und
		# auch während einer Fahrt: eine Frage, die aussetzt, friert die Zeile ein.
		shaft.set_cover_hovered(pixel.x >= 0.0 and spot < rects.size()
			and rects[spot].has_point(pixel))
		if shaft.riding():
			continue  # eine laufende Fahrt schreibt ihren Zustand selbst
		if show:
			_park_bet_shaft(spot)
		elif shaft.visible:
			shaft.settle_hard()

## Die Steuer EINER genommenen Hand: gebucht hat GameRun, hier fliegt je zahlender
## Wette EIN Meteor vom Schatz zu ihrem Fenster. Reine Anzeige.
func _tax_side_bets(hand_dice: int) -> void:
	var live: Array[SideBet] = []
	for bet in run.active_side_bets:
		if not bet.voided and SideBetPanel.is_tax_bet(bet):
			live.append(bet)
	run.tax_side_bets(hand_dice)
	var broke := false
	for bet in live:
		if bet.voided:
			broke = true  # zahlungsunfähig: nichts kam herein, der Gewinn geht
			continue
		var due := run.side_bet_stake(bet)
		if bet.stake_kind == SideBet.Stake.MONEY_PER_DIE:
			due *= maxi(hand_dice, 0)
		if due > 0:
			_fly_bet_tax(bet)
	if broke:
		# Eine gerissene Steuerwette hat nichts mehr auf dem Tresen zu suchen: ihr
		# Gewinn fährt hinaus, wie alles Verlorene in der Abrechnung.
		_write_bet_counter(ShopController.GRADE_RISE, true)

## Die STEUER reist als LICHT: je Buchung EIN Meteor vom Schatz zum Wettfenster, und
## bei der Ankunft leuchtet die BEDINGUNG der Wette kurz auf. Das ist die benannte
## AUSNAHME vom Bewegungs-Gesetz - was der Spieler zahlt, fliegt sonst als Körper,
## aber eine Kleinsteuer je Hand ist keine Geste, sie ist ein Ticken.
## Fire-and-forget mit Lauf-Marke; gebucht ist längst.
func _fly_bet_tax(bet: SideBet) -> void:
	var panel := _side_bet_panel()
	if table_screen == null or panel == null or not _bet_counter_visible():
		return
	var index := panel.offers.find(bet)
	if index < 0:
		return
	var launched := run
	var travel := table_screen.side_bet_tax_comet(TableScreen.SIDE_MONEY_COLOR)
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		if run == launched:
			_flash_bet_condition(index))

## Das Aufleuchten selbst: über einer geparkten Grube spricht der SCHIRM, sonst der
## Melder im Sitz - dieselbe EINE Regel, die entscheidet, wo die Zeile überhaupt steht.
func _flash_bet_condition(index: int) -> void:
	var panel := _side_bet_panel()
	if panel == null:
		return
	if not panel.plot_parked(index):
		panel.flash_note(index)
		return
	if index < 0 or index >= bet_shafts.size():
		return
	var shaft := bet_shafts[index]
	if shaft != null and is_instance_valid(shaft):
		shaft.flash_cover_goal()

## Die ABRECHNUNG am Tresen. Erst nimmt das HAUS: alle nicht gewonnenen Gewinne fahren
## hinaus - was UNTEN wartete, verläßt seine Grube, ohne je aufzutauchen. Dann verläßt
## allein der gewonnene Preis den Tresen nach HINTEN: er reist zum Spieler.
## Nicht erwartet, Lauf- und Token-Marke - gebucht hat GameRun längst.
## Phase GELD der Wett-Abrechnung: je Geld-/⚡-Gewinn versinkt sein stehender Preis
## im Tisch, der Meteor reist die Ader zum Hub, und die Ankunft tickt seine Zeile.
## Nacheinander - gezählt wird EINE Wette nach der anderen; gebucht ist längst.
func _play_bet_money_payouts() -> void:
	for i in _payout_claims.size():
		var claim: Dictionary = _payout_claims[i]
		var bet: SideBet = claim["bet"]
		if _payout_body_wanted(bet):
			continue  # Ware zählt in der Karten-Phase danach
		await _count_bet_payout(i, bet, claim)
		if phase != Phase.PAYOUT:
			return

## Phase KARTEN: erst jetzt erscheinen Namen und Plattform der Seite, dann versinkt
## je Ware-Gewinn seine Kassette (bzw. Marke) am Tresen, reist als Meteor zum Hub
## und steigt dort in ihrer Zelle aus der Fläche - eine nach der anderen.
func _play_bet_goods_payouts() -> void:
	if payout_ledger != null:
		payout_ledger.set_plots(_payout_pending_plots)
	_payout_pending_plots = []
	var goods: Array[int] = []
	for i in _payout_claims.size():
		if _payout_body_wanted(_payout_claims[i]["bet"]):
			goods.append(i)
	if goods.is_empty():
		return
	var launched := run
	# ALLE ZUGLEICH (Spieler-Entscheid 2026-08-26): jede Karte versinkt in ihrer
	# eigenen Sektion im selben Schlag, die Meteore fliegen gemeinsam, und die
	# ganze Ware steigt in EINER Fahrt auf die eine Plattform der Seite.
	var taken := false
	for i in goods:
		if _take_bet_prize(_payout_claims[i]["bet"]):
			taken = true
	if taken:
		# Erst wenn die Preise unter der Fläche sind, reist ihr Licht.
		await get_tree().create_timer(LiftShaftView.SINK_TIME + 0.05).timeout
		if run != launched or phase != Phase.PAYOUT:
			return
	var travel := 0.05
	for i in goods:
		travel = maxf(travel, table_screen.side_bet_payout_comet(true,
			SideBetPanel.payout_accent(_payout_claims[i]["bet"])))
	await get_tree().create_timer(travel).timeout
	if run != launched or phase != Phase.PAYOUT:
		return
	for i in goods:
		var claim: Dictionary = _payout_claims[i]
		var bet: SideBet = claim["bet"]
		_ledger_money("bet_%d" % i, bet.display_name, int(claim.get("money", 0)),
			bet.description)
		_ledger_energy(int(claim.get("energy", 0)))
	_raise_payout_batch(goods)
	await get_tree().create_timer(LiftShaftView.cycle_time()).timeout

## Zählt EINE Geld-/⚡-Wette: ihr Preis versinkt am Tresen (die Kauf-Fahrt seiner
## Sektion - Gewonnenes reist zum Spieler), der Meteor startet, sobald er unter der
## Fläche ist, und die Ankunft tickt die Zeile.
func _count_bet_payout(index: int, bet: SideBet, claim: Dictionary) -> void:
	var launched := run
	if _take_bet_prize(bet):
		# Erst wenn der Preis unter der Fläche ist, reist sein Licht.
		await get_tree().create_timer(LiftShaftView.SINK_TIME + 0.05).timeout
		if run != launched or phase != Phase.PAYOUT:
			return
	var travel: float = table_screen.side_bet_payout_comet(true,
		SideBetPanel.payout_accent(bet))
	await get_tree().create_timer(maxf(travel, 0.05)).timeout
	if run != launched or phase != Phase.PAYOUT:
		return
	_ledger_money("bet_%d" % index, bet.display_name, int(claim.get("money", 0)),
		bet.description)
	_ledger_energy(int(claim.get("energy", 0)))
	await get_tree().create_timer(PAYOUT_TEXT_HOLD_DURATION * 0.5).timeout

## Nimmt den stehenden Preis EINER Wette vom Tresen (false = kein Körper da, der
## Meteor fliegt sofort). Genommen ist genommen: die Wette verläßt die Gewinner-
## Liste, damit kein späterer Schreiber ihren Preis wieder hinstellt.
func _take_bet_prize(bet: SideBet) -> bool:
	var panel := _side_bet_panel()
	var spot := panel.offers.find(bet) if panel != null else -1
	_bet_won.erase(bet)
	if spot < 0:
		return false
	var key := _bet_slot(spot, BET_ROLE_PRIZE)
	var body: Node3D = bet_bodies.get(key)
	if body == null or not is_instance_valid(body) or not _bet_seats.has(key):
		return false
	var seat: Vector3 = _bet_seats[key]
	_set_bet_hovered(body, false)
	bet_bodies.erase(key)
	_bet_keys.erase(key)
	_bet_seats.erase(key)
	_bet_parked.erase(spot)
	_drop_bet_cover(spot)
	_bet_note_leaving(spot, body)
	var entries: Array = [{"body": body, "spot": spot, "target": seat}]
	var bodies: Array = [body]
	var shaft := _bet_shaft_on(spot, _bet_plot_field(spot),
		_bet_shaft_depth(entries)) if _bet_counter_watched() else null
	if shaft == null or shaft.run_take(bodies, [seat], 0.0,
			_release_bet_bodies.bind(bodies)) == null:
		_release_bet_bodies(bodies)
		return false
	return true

## Der FORTSCHRITTS-MELDER und sein Spiegel, gespeist allein aus der EINEN
## bestehenden Fortschritts-Rechnung - es gibt keine zweite Bedingungs-Auswertung.
## Kippt der live_state einer Wette auf ON_TRACK, ist ihre Bedingung ERFÜLLT: ihr
## Gewinn fährt aus der geparkten Grube herauf und steht ausgefahren da. Kippt er auf
## FAILED, ist sie GESCHEITERT: ihr Gewinn wird eingezogen, das Loch schließt.
## Gemeldet wird je Wette genau EINMAL, und je Seite nur, wer dort überhaupt kippen
## kann - eine offen beginnende Wette (decides_early) erfüllt sich mitten in der
## Runde, eine grün beginnende kann nur noch scheitern.
func _note_bet_progress(stats: Dictionary) -> void:
	if run == null or _bet_stage != SideBetPanel.STAGE_ROUND:
		return
	var fresh := false
	for bet in run.active_side_bets:
		if _bet_fulfilled.has(bet) or _bet_failed.has(bet):
			continue
		var live := bet.live_state(stats)
		if live == SideBet.Live.FAILED:
			_bet_failed.append(bet)
			fresh = true
		elif live == SideBet.Live.ON_TRACK and bet.decides_early():
			_bet_fulfilled.append(bet)
			fresh = true
	if fresh:
		_write_bet_counter(ShopController.GRADE_RISE, true)

# --- Die ABLAGE der AUSZAHLUNGS-SEITE -------------------------------------------
# Der gewonnene Preis wird am Tresen geschluckt (die Take-Fahrt) und taucht auf der
# Auszahlungs-Seite wieder auf: je Wette EIN Licht über die Nebenwetten->Hub-Ader, und
# bei seiner Ankunft tickt ihre Zeile. Einen KÖRPER stellt dabei nur WARE (Kassette,
# Marke) - als Ablage-ZEILE unter GESAMT, links ihr Name, rechts die Fassung, aus der
# er steigt; Geld und ⚡ sind Zeilen wie jede andere Quelle. Das KASSIEREN senkt die
# Körper wieder ein, und erst DANN reist der Gewinn als Licht an sein Ziel. Die Körper
# sind reine ANZEIGE - jede Zahl steht längst in GameRun, keine Buchung hängt an ihnen.

## Ob der Gewinn dieser Wette als Körper auf der Ablage steht: Ware ja, Geld und ⚡
## nein. Ein am vollen Magazin GANZ zu Geld zerfallener Paket-Gewinn stellt nichts.
func _payout_body_wanted(bet: SideBet) -> bool:
	match bet.payout_kind:
		SideBet.Payout.SPECIAL, SideBet.Payout.PACK, SideBet.Payout.PACKS:
			return not bet.awarded_packs.is_empty()
		SideBet.Payout.MONEY, SideBet.Payout.ENERGY:
			return false
	return true  # die Marken (LVL+1, Presse-Schub): Ware

## Die gemeldeten ZELLEN der Ablage (Display-Pixel). ui/ meldet, scene_root stellt.
func _payout_cells() -> Array[Rect2]:
	var empty: Array[Rect2] = []
	return payout_ledger.payout_cells() if payout_ledger != null else empty

## Wo ein Körper in SEINER Zelle sitzt: mittig - dieselbe reine Regel wie am Tresen.
func _payout_seat_at(index: int) -> Vector3:
	var cells := _payout_cells()
	if index < 0 or index >= cells.size():
		return Vector3.ZERO
	return _data_cell_seat(SideBetPanel.seat_in(cells[index]))

## Die EINE Sektion der Ablage, auf die gemeldete Plattform gestellt (null = nichts
## gemeldet). Ihr Loch ist EINES: die ganze Ware steht nebeneinander darauf und fährt
## gemeinsam. Die Tiefe wächst nur - ein Neuschnitt setzte stehende Ware zurück.
func _payout_shaft_on(deep: float) -> LiftShaftView:
	if table_screen == null or payout_ledger == null:
		return null
	var field := payout_ledger.payout_platform()
	if field.size.x <= 0.0 or field.size.y <= 0.0:
		return null
	if payout_shaft == null or not is_instance_valid(payout_shaft):
		payout_shaft = LiftShaftView.new("PayoutShaft")
		add_child(payout_shaft)
		payout_shaft.opened.connect(func(at: Vector3, hole: Vector2) -> void:
			table_screen.set_lift_pit(TableScreen.PIT_PAYOUT, at, hole,
				_payout_plot_radius()))
		payout_shaft.closed.connect(func() -> void:
			table_screen.clear_pit(TableScreen.PIT_PAYOUT))
	payout_shaft.deck_skin = table_screen.display_skin()
	payout_shaft.order_skin(PIT_SKIN)
	_payout_depth = maxf(_payout_depth, deep)
	var a := table_screen.pixel_to_world(field.position)
	var b := table_screen.pixel_to_world(field.end)
	payout_shaft.setup(table_screen.pixel_to_world(field.get_center()),
		Vector2(absf(a.x - b.x), absf(a.z - b.z)) * 0.5, _payout_depth)
	return payout_shaft

## Die Eckenrundung des Lochs - gemeldet von der Seite, die auch die Fassung malt.
func _payout_plot_radius() -> float:
	return payout_ledger.payout_plot_radius() if payout_ledger != null else 0.0

## Wie tief die Sektion eines Ablage-Plots fährt: das gewohnte Schachtmaß, mindestens
## aber so tief, dass sein Stück durch das Öffnungsband paßt.
func _payout_shaft_depth(body: Node3D) -> float:
	return maxf(VitrineView.shaft_depth(), _bet_body_height(body) * VitrineView.SHAFT_ROOM)

## Der AUFTRITT der GANZEN Ware in EINER Fahrt: je PLOT ein Körper in SEINER
## Zelle - dieselbe Bauform, die am Tresen stand (die dortigen sind versunken),
## bei gesammelten Paket-Plots mit der summierten Stückzahl aus der Plot-Spec -,
## und die eine Plattform hebt alle zugleich. Mitfahrer braucht es nicht mehr:
## es gibt nur diese eine Fahrt.
func _raise_payout_batch(indices: Array[int]) -> void:
	if run == null or payout_ledger == null or not payout_ledger.visible:
		return
	var bodies: Array = []
	var seats: Array = []
	var deep := 0.0
	for index in indices:
		var claim: Dictionary = _payout_claims[index]
		var plot_id: String = claim.get("plot", "")
		if plot_id == "":
			continue
		var slot := payout_ledger.plot_index(plot_id)
		if slot < 0 or payout_bodies.has(slot) or slot >= _payout_cells().size():
			continue
		var target := _payout_seat_at(slot)
		var spec: Dictionary = _payout_plot_specs.get(plot_id,
			_bet_price_spec(claim["bet"]))
		var body := _spawn_bet_body(spec, target)
		if body == null:
			continue
		payout_bodies[slot] = body
		_payout_seats[slot] = target
		bodies.append(body)
		seats.append(target)
		deep = maxf(deep, _payout_shaft_depth(body))
	if bodies.is_empty():
		return
	var shaft := _payout_shaft_on(deep)
	if shaft == null or shaft.run_cycle(bodies, seats, 0.0) == null:
		for i in bodies.size():
			_seat_bet_body(bodies[i], seats[i])  # ohne Sektion steht sie einfach da
			_appear_bet_body(bodies[i])

## Je Bild: die Ablage-Körper stehen, solange die Auszahlungs-Seite steht. Es gibt
## hier keinen Hover und kein Klickziel - sie sind Ausweis, nicht Ware.
func _sync_payout_bodies() -> void:
	if payout_bodies.is_empty():
		return
	var show := payout_ledger != null and is_instance_valid(payout_ledger) \
		and payout_ledger.visible
	for index: int in payout_bodies:
		var body: Node3D = payout_bodies[index]
		if body != null and is_instance_valid(body) and body.visible != show:
			body.visible = show

## Das KASSIEREN räumt die Ablage: jeder Körper versinkt in seiner Fläche, dicht
## gestaffelt, und abgewartet wird EINE Zykluszeit - kein Minuten-Stau.
func _sink_payout_bodies() -> void:
	if payout_bodies.is_empty():
		_settle_payout_shafts()
		return
	_payout_gen += 1
	var token := _payout_gen
	var launched := run
	# EINE Plattform, EINE Fahrt: die ganze Ware sinkt gemeinsam und geht vorn hinaus.
	var leaving: Array = []
	var seats: Array = []
	var deep := 0.0
	for index: int in payout_bodies:
		var body: Node3D = payout_bodies[index]
		if body == null or not is_instance_valid(body):
			continue
		leaving.append(body)
		seats.append(_payout_seats.get(index, body.global_position))
		deep = maxf(deep, _payout_shaft_depth(body))
		_payout_leaving.append(body)
	payout_bodies.clear()
	_payout_seats.clear()
	var shaft := _payout_shaft_on(deep) if not leaving.is_empty() else null
	if shaft == null or shaft.run_exit(leaving, seats, 0.0,
			_free_payout_bodies.bind(leaving)) == null:
		_free_payout_bodies(leaving)
	else:
		await get_tree().create_timer(LiftShaftView.exit_cycle_time()).timeout
		if run != launched or token != _payout_gen:
			return
	_settle_payout_shafts()

## Und DANN je Gewinnart ihr ZIEL-Licht (gebucht ist alles längst): Geld zum Schatz,
## ⚡ zur Bank, Paket und Sonderposten auf ihren reservierten Magazin-Platz, wo die
## zurückgehaltene Kassette aus dem Grubenboden steigt. Die beiden Marken (LVL+1,
## Presse-Schub) zeigen sich selbst - Chip und Presse tragen es.
func _fly_payout_targets() -> void:
	if table_screen == null:
		_payout_claims.clear()
		_payout_packs.clear()
		return
	var workshop: WorkshopView = table_screen.workshop_window
	var hub_px := Vector2.ZERO
	if table_screen.hub != null:
		hub_px = table_screen.hub.position + table_screen.hub.size * 0.5
	var launched := run
	for i in _payout_claims.size():
		var claim: Dictionary = _payout_claims[i]
		var bet: SideBet = claim["bet"]
		var wait := float(i) * MONEY_PULSE_GAP
		var fire := func() -> void:
			if run == launched:
				_fly_payout_claim(bet, claim, workshop, hub_px)
		if wait <= 0.0:
			fire.call()
		else:
			get_tree().create_timer(wait).timeout.connect(fire)
	_payout_claims.clear()
	_payout_packs.clear()

## Das Licht EINER kassierten Wette. Ein Paket und sein Geld schließen einander nicht
## aus: ein am vollen Magazin zerfallener Gewinn zahlt bar. JEDES gewährte Paket
## bekommt seinen eigenen Kometen auf seinen reservierten Magazin-Platz.
func _fly_payout_claim(bet: SideBet, claim: Dictionary, workshop: WorkshopView,
		hub_px: Vector2) -> void:
	if workshop != null and is_instance_valid(workshop):
		var launched := run
		for i in bet.awarded_packs.size():
			var pack: Pack = bet.awarded_packs[i]
			if pack == null or pack.pack_uid <= 0:
				continue
			var tint: Color = PackIconRenderer.COLORS.get(pack.type,
				CasinoStyle.GOLD_INTENSE)
			if pack.fixed_engraving != null:
				tint = pack.fixed_engraving.rarity_color()
			if i == 0:
				_fly_pack_to_magazine(workshop, pack.pack_uid, hub_px, tint)
			else:
				get_tree().create_timer(float(i) * STAMP_METEOR_GAP).timeout.connect(
					func() -> void:
						if run == launched and is_instance_valid(workshop):
							_fly_pack_to_magazine(workshop, pack.pack_uid, hub_px, tint))
	var energy := int(claim.get("energy", 0))
	if energy > 0:
		_play_hub_energy_volley(energy)
	if int(claim.get("money", 0)) > 0:
		_fly_payout_money()

## Geld ab HUB: der Komet fährt die Schatz-Leiste hinunter, die Truhe quittiert.
func _fly_payout_money() -> void:
	var launched := run
	var travel := table_screen.money_comet(true, TableScreen.SIDE_MONEY_COLOR)
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		if run == launched and table_screen != null \
				and table_screen.treasure_window != null:
			table_screen.treasure_window.glint())

## Gewinn-Pakete bleiben ZURÜCKGEHALTEN: gebucht sind sie mit der Abrechnung, aber
## ihre Kassette steigt erst nach dem Kassieren im Magazin. Armiert wird im selben
## synchronen Zug wie die Buchung - dazwischen liegt kein Bild.
func _withhold_payout_packs(won: Array[SideBet]) -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop):
		return
	for bet in won:
		for pack in bet.awarded_packs:
			if pack != null and pack.pack_uid > 0:
				workshop.expect_pack_delivery(pack.pack_uid)
				_payout_packs.append(pack.pack_uid)

func _free_payout_bodies(bodies: Array) -> void:
	for body in bodies:
		_payout_leaving.erase(body)
		_free_bet_body(body)

func _settle_payout_shafts() -> void:
	if payout_shaft != null and is_instance_valid(payout_shaft):
		payout_shaft.settle_hard()

## Der EINE Aufräum-Pfad der Ablage: jeder Körper frei, jede Sektion bündig, jedes Loch
## zu - und eine zurückgehaltene Kassette kommt sofort an, damit keine unter dem
## Grubenboden vergessen wird. Reset und Laufwechsel laufen hier durch.
func _drop_payout_bodies() -> void:
	_payout_gen += 1
	for index: int in payout_bodies:
		_free_bet_body(payout_bodies[index])
	payout_bodies.clear()
	_payout_seats.clear()
	_free_payout_bodies(_payout_leaving.duplicate())
	_payout_claims.clear()
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop != null and is_instance_valid(workshop):
		_land_pending_packs(workshop, _payout_packs)
	_payout_packs.clear()
	_payout_pending_plots = []
	_payout_plot_specs.clear()
	_payout_depth = 0.0  # die nächste Ablage mißt ihre Tiefe neu
	_settle_payout_shafts()

# --- Die Fumble-Automaten: das Gewinn-Licht --------------------------------------
# Der Topf hat keinen Körper mehr: die Auszahlung ist der PERLENZUG im Fenster
# (SlotBankView), und je Preis fliegt bei seinem Abflug ein Licht - gebucht hat ihn
# das Fenster VOR der Emission, hier wird nur noch geflogen.

## Auszahlung gestartet: frischer Meteor-Fächer und der Gold-Blitz am Hub.
func _on_slot_cashed_out(_runs: int) -> void:
	_meteor_index = 0  # je Auszahlung ein frischer Fächer von Ausbruch-Richtungen
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.flash_frame(CasinoStyle.GOLD_INTENSE)

## Ein Gewinn verläßt den Automaten: Pakete ins Magazin an der Werkbank, ⚡ über
## den Hub in die Kondensator-Bank, Würfel in die Vorrats-Ablage.
func _on_slot_prize_dispatched(prize: SlotPrize, from_px: Vector2) -> void:
	if table_screen == null:
		return
	match prize.kind:
		SlotPrize.Kind.ENGRAVING, SlotPrize.Kind.MATERIAL, SlotPrize.Kind.DICE_ENGRAVING:
			_fly_slot_packs(prize.packs, from_px)
		SlotPrize.Kind.ENERGY:
			_fly_slot_energy(prize.energy, from_px)
		SlotPrize.Kind.DIE:
			# Gebucht hat das Fenster VOR der Emission - hinterlegt liegt er hinten.
			if run != null and not run.pending_dice.is_empty():
				_fly_slot_die_to_fach(run.pending_dice[run.pending_dice.size() - 1], from_px)

## Die gewonnene Energie reist die ZWEI Etappen jedes ⚡ im Spiel: die Automaten-Ader
## in den Hub, dann die Hub-Cluster-Ader zur Kondensator-Bank. Die Automaten sind
## die sechste ⚡-Quelle; gebucht ist längst, das hier ist reine Anzeige.
func _fly_slot_energy(count: int, from_px: Vector2) -> void:
	if count <= 0 or table_screen == null:
		return
	var launched := run
	var travel := table_screen.slot_prize_comet(from_px, CasinoStyle.ENERGY)
	if travel > 0.0:
		await get_tree().create_timer(travel).timeout
	if run != launched:
		return
	_play_hub_energy_volley(count)

## Die Magazin-Plätze der Pakete, die dieser Einsatz gleich verzehrt - gefragt VOR
## der Buchung, denn danach steht dort nichts mehr. WELCHE es sind, sagt GameRun
## (typ- und größengenau); hier wird nicht zweitgewählt.
func _bet_stake_pack_anchors(bet: SideBet) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or run == null or bet.stake_kind != SideBet.Stake.PACKS:
		return out
	for pack in run.stake_packs_for(bet):
		out.append(workshop.pack_anchor_px(pack.pack_uid))
	return out

## Der EINSATZ wird GEWORFEN: was der Spieler zahlt, fliegt als Körper von seinem
## echten Zuhause MITTIG auf den Plot - Geld als gestaffelte Salve von der Spitze des
## Schatzes, die sich dort zu EINEM flachen Turm stapelt, jedes geopferte Paket von
## SEINEM Magazin-Sitz, ⚡ als lose Zelle von der Kondensator-Bank. Erst wenn der
## Stapel VOLL steht, bekommt on_land die gelandeten Körper - und die Sektion senkt
## sie ein. Liefert die Laufzeit der Salve.
func _throw_bet_stake(bet: SideBet, pack_anchors: Array[Vector2],
		chips: Array[int], seat: Vector3, on_land: Callable) -> float:
	if table_screen == null or not _bet_counter_visible():
		on_land.call([] as Array)
		return 0.0
	var entries: Array = []
	match bet.stake_kind:
		SideBet.Stake.PACKS:
			# Je geopfertem Paket EINE Kassette, jede von IHREM Sitz - ohne Magazin
			# (Werkbank nicht gestellt) wirft der Schatz vom Hub-Rand her.
			var anchors := pack_anchors.duplicate()
			if anchors.is_empty():
				anchors.append(Vector2(-1, -1))  # kein Magazin: der Hub zahlt
			var sort := Pack.shelf_for_pack_type(bet.stake_pack_type)
			for i in anchors.size():
				var from := _data_cell_seat(anchors[i]) if anchors[i].x >= 0.0 \
					else _treasure_throw_point()
				entries.append({
					"body": _throw_cell_body(from, sort, bet.stake_pack_tier),
					"from": from, "to": _throw_scatter(seat, i, anchors.size())})
		SideBet.Stake.ENERGY:
			var count := BetPrizeView.energy_cells(run.side_bet_stake_energy(bet))
			var from := capacitor_bank.global_position if capacitor_bank != null \
				else _treasure_throw_point()
			for i in mini(count, THROW_SALVO_CAP):
				entries.append({"body": _throw_energy_body(), "from": from,
					"to": _throw_scatter(seat, i, mini(count, THROW_SALVO_CAP))})
		_:
			var bodies := _throw_chip_bodies(chips)
			var from := _treasure_throw_point()
			for i in bodies.size():
				entries.append({"body": bodies[i], "from": from,
					"to": seat + Vector3.UP * (BetPrizeView.FLOOR_CLEAR
						+ ChipStackView.stack_lift(i))})
	return _throw_bodies(entries, on_land, true)

# --- Die Würfelnetze unter der Auslage -----------------------------------------
# Steht die Schale, liegen unter jedem Würfel sein NETZ, seine SEELEN-ZEILE und
# sein PREIS auf der Ladenseite: dieselbe Zeichnung wie überall, nur als reine
# Auskunft ohne Maus - die Ware trägt, was der Spieler wissen muß. Sie sind fort,
# solange etwas steigt oder sinkt - eine Beschriftung unter einem fahrenden Würfel
# wäre eine Lüge - und fort, solange die Auslage abgedeckt ist.

## Luft zwischen Würfel und seinem Netz und der Rand zur Kante der Auslage, beide
## in Buchten-Einheiten (Breite/100).
## Die Luft zwischen Würfel und seinem Netz - nach Werkstatt-Vorbild großzügig:
## dort trennt spürbare Luft den schwebenden Würfel von seinem Diagramm.
const VITRINE_NET_GAP := 6.0
const VITRINE_NET_MARGIN := 2.5
## Wie viel der gemessenen Teilung ein Netz höchstens beansprucht - die Reihe
## steht sonst Kante an Kante.
const VITRINE_NET_SHARE := 0.9
## Und wie viel des Bandes: der Deckel ist die ZWEITE Quelle des Zellmaßes, und
## er muß in der Reserve und im wirklichen Aufbau derselbe sein - sonst rechnete
## die Auslage mit einem anderen Netz, als die Seite später zeichnet.
const VITRINE_NET_BAND_SHARE := 0.5
## Der Platz der BESCHRIFTUNG unter dem Netz, in Einheiten: Luft, Seelen-Zeile,
## Luft, Preisschild. Die Ware sagt hier selbst, was in ihr steckt und was sie
## kostet - dafür gibt der Beschriftungs-Streifen die Tiefe her.
const VITRINE_NET_LABELS := 6.4

## Was Beschriftung UND Info-Fuß zusammen vom Band nehmen. EINE Rechnung für die
## Reserve und den wirklichen Aufbau - drifteten die beiden, stünde die Ware auf
## anderen Plätzen, als die Seite später zeichnet. Die Fußzahl gehört dem Laden,
## der den Fuß auch baut.
static func _vitrine_label_units() -> float:
	return VITRINE_NET_LABELS + ShopController.VITRINE_FOOTER_UNITS

## Das Zellmaß der Buchten-Netze - EINE Quelle: die gemessene Teilung deckelt es,
## das freie Band ebenfalls.
static func _vitrine_net_cell(pitch: float, band: float) -> float:
	return DieNetView.cell_for(Vector2(pitch * VITRINE_NET_SHARE, band))

## Was die Beschriftung VOR der Schale beansprucht, in Welt-Tiefe: Luft, Netz,
## Seelen-Zeile und Preisschild - gemessen ab dem ANKER des Würfels, denn dort
## hängt sie an.
## Gerechnet aus der TEILUNG allein: so hängt der Platz der Würfel nicht an dem
## Band, das er selbst erst freiläßt.
func _vitrine_label_reserve() -> float:
	if charm_shop == null or not is_instance_valid(charm_shop) or table_screen == null:
		return 0.0
	var rect := charm_shop.vitrine_rect_px()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return 0.0
	var count := 0
	for die in charm_shop.vitrine_stock().get(ShopController.KIND_DIE, []):
		if die != null:
			count += 1
	if count <= 0:
		return 0.0
	var unit := maxf(rect.size.x, 1.0) / 100.0
	var pitch := rect.size.x * (1.0 - VitrineView.EDGE_MARGIN * 2.0) / float(count)
	var cell := _vitrine_net_cell(pitch, rect.size.y * VITRINE_NET_BAND_SHARE)
	var block := unit * VITRINE_NET_GAP + DieNetView.net_size(cell).y \
		+ unit * _vitrine_label_units()
	return block * _vitrine_depth_per_pixel(rect)

## Wieviel Welt-TIEFE ein Display-Pixel der Bucht wert ist (Pixel-y = Welt-x).
func _vitrine_depth_per_pixel(rect: Rect2) -> float:
	var a := table_screen.pixel_to_world(rect.position)
	var b := table_screen.pixel_to_world(rect.end)
	return absf(a.x - b.x) / maxf(rect.size.y, 1.0)

## Die Schale STEHT nach einer echten Fahrt (Auftritt oder Umschlag): erst das ist
## eine ANKUNFT, und nur dort projizieren sich die Blöcke aus ihren Würfeln.
func _on_vitrine_dice_settled() -> void:
	_sync_vitrine_nets(true)

func _sync_vitrine_nets(arrived := false) -> void:
	if shop_vitrine == null or not is_instance_valid(shop_vitrine) \
			or charm_shop == null or not is_instance_valid(charm_shop) or table_screen == null:
		return
	# Gemessen wird im STREIFEN: dort hängt der Netz-Layer, seine Pixel sind die
	# der Seite.
	var rect := charm_shop.vitrine_rect_px()
	if not _vitrine_curtain or not shop_vitrine.bowl_settled() \
			or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_clear_vitrine_nets()
		return
	var lying: Array = charm_shop.vitrine_stock().get(ShopController.KIND_DIE, [])
	var anchors: Array[Vector2] = []
	var defs: Array[DieDefinition] = []
	for i in lying.size():
		if lying[i] == null:
			continue
		var spot := shop_vitrine.spot_of(ShopController.KIND_DIE, i)
		if spot == Vector3.ZERO:
			continue
		defs.append(lying[i])
		anchors.append(table_screen.world_to_pixel(spot) - rect.position)
	if defs.is_empty():
		_clear_vitrine_nets()
		return
	var unit := maxf(rect.size.x, 1.0) / 100.0
	var gap := unit * VITRINE_NET_GAP
	var margin := unit * VITRINE_NET_MARGIN
	# Die Teilung ist GEMESSEN, nicht getippt: sie ist der Abstand, den die
	# aufgereihten Würfel wirklich halten.
	var pitch := rect.size.x
	if anchors.size() >= 2:
		pitch = absf(anchors[1].x - anchors[0].x)
	# Und das Band davor ist, was zwischen dem tiefsten Würfel und der Buchtkante
	# frei bleibt.
	var deepest := 0.0
	for anchor in anchors:
		deepest = maxf(deepest, anchor.y)
	# Seelen-Zeile, Preisschild und der Info-Fuß hängen unter dem Netz und zählen
	# zum Band.
	var band := rect.size.y - deepest - gap - margin - unit * _vitrine_label_units()
	# Derselbe Deckel wie in der Reserve: sonst zeichnete die Seite ein anderes
	# Netz, als die Auslage beim Stellen der Würfel eingeplant hat.
	band = minf(band, rect.size.y * VITRINE_NET_BAND_SHARE)
	var cell := _vitrine_net_cell(pitch, band)
	var span := DieNetView.net_size(cell)
	var entries: Array = []
	for i in defs.size():
		var pos := Vector2(anchors[i].x - span.x * 0.5, anchors[i].y + gap)
		pos.x = clampf(pos.x, margin, maxf(margin, rect.size.x - span.x - margin))
		pos.y = clampf(pos.y, margin,
			maxf(margin, rect.size.y - span.y - margin - unit * _vitrine_label_units()))
		# Der ANKER reist mit: der Block wächst aus dem Würfel, nicht aus seinem
		# eigenen Rechteck - und das steht nach dem Klemmen woanders.
		entries.append({"def": defs[i], "pos": pos, "anchor": anchors[i]})
	charm_shop.set_die_nets(entries, cell, arrived)

## Die Netze abräumen. Eine laufende ABSORPTION ist die Ausnahme: sie IST das
## Abräumen und legt am Ende selbst ab - ihr dazwischenzufahren risse die Blöcke
## mitten im Einsaugen weg.
func _clear_vitrine_nets() -> void:
	if charm_shop != null and is_instance_valid(charm_shop) and charm_shop.nets_absorbing():
		return
	_drop_vitrine_nets()

## Der harte Weg: was schrumpft, ist sofort fort (Verdrängung, Laufwechsel).
func _drop_vitrine_nets() -> void:
	_vitrine_soul_hints.clear()
	if charm_shop != null and is_instance_valid(charm_shop):
		charm_shop.clear_die_nets()

## Die Seelen-Zeile je Würfel-Instanz - Essence.by_id baut je Aufruf den ganzen
## Katalog, und gefragt wird je Bild (die Grammatik der Grubenkarte).
var _vitrine_soul_hints: Dictionary = {}

## Der EINE Schreiber des Info-Fusses: die Netz-Zelle unter dem Zeiger gewinnt,
## sonst antwortet der Würfelkörper mit seiner Seele, sonst steht dort nichts.
## Beides in EINER Hand, damit Zelle und Körper sich nicht gegenseitig löschen.
func _sync_vitrine_net_hover() -> void:
	if charm_shop == null or not is_instance_valid(charm_shop):
		return
	var rect := _shop_bay_rect()
	if not _vitrine_curtain or rect.size.x <= 0.0 or charm_shop.net_count() <= 0:
		charm_shop.set_net_hint("")
		return
	var pixel := _screen_pixel(get_viewport().get_mouse_position())
	if pixel.x < 0.0:
		charm_shop.set_net_hint("")
		return
	var hint := charm_shop.net_hint_at(pixel)
	if hint == "":
		hint = _vitrine_soul_hint(_bay_item_at(shop_vitrine, rect, pixel))
	charm_shop.set_net_hint(hint)

## Die Seele des gegriffenen Würfels ("" für alles andere) - dieselbe Zeile, die
## der Essenz-Chip im Netz erklärt.
func _vitrine_soul_hint(item: Dictionary) -> String:
	if item.is_empty() or String(item["kind"]) != ShopController.KIND_DIE:
		return ""
	var lying: Array = charm_shop.vitrine_stock().get(ShopController.KIND_DIE, [])
	var index := int(item["index"])
	if index < 0 or index >= lying.size():
		return ""
	var def: DieDefinition = lying[index]
	if def == null:
		return ""
	var key := def.get_instance_id()
	if not _vitrine_soul_hints.has(key):
		_vitrine_soul_hints[key] = DieNetView.hint_for(def, DieNetView.EDGE)
	return String(_vitrine_soul_hints[key])

# --- Griff und Beschriftung in der Auslage -------------------------------------

## Das Stück unter dem Zeiger: pro Bild gefragt, nie gemeldet - der Zeiger liegt
## auf dem Tisch, mouse_entered erreicht die Auslage nie (die Magazin-Grammatik).
## Der Griff hebt das Stück, das Fenster schreibt seine Beschriftung. BEIDE
## Auslagen laufen hier durch; ihre Rechteck-Geber sind Modus-gebunden, es kann
## also immer nur eine greifbar sein.
func _sync_vitrine_hover() -> void:
	# Der Tausch-Wähler hat kein Signal und der Kamera-Fokus keinen eigenen Ruf -
	# also wird beides hier je Bild mitgefragt.
	_sync_vitrine_curtain()
	_sync_secret_curtain()
	_sync_slit_visibility()
	_sync_slit_hover()
	_sync_bet_counter()
	_sync_payout_bodies()
	if charm_shop != null and is_instance_valid(charm_shop):
		# Im Laden HEBT der Griff nur - die Bucht selbst sagt nichts: unter jedem
		# Würfel liegen sein Netz, seine Seelen-Zeile und sein Preis, und die stehen
		# ohne Zeiger da. Was der Zeiger hinzufügt, schreibt der Info-Fuß - und der
		# hat seinen EIGENEN Schreiber daneben, nicht hier eingefädelt.
		_paint_bay_hover(shop_vitrine, _shop_bay_rect())
		_sync_vitrine_net_hover()
	var market := _secret_window()
	if market != null:
		# Der Zeiger auf der Charm-Karte schreibt ihren Text in DENSELBEN Fuß wie die
		# Bucht-Ware; sonst greift die Bucht wie gehabt. GEFRAGT je Bild - der Zeiger
		# liegt auf dem Tisch, mouse_entered erreicht die Karte im Fokus nicht sicher.
		if _secret_charm_hovered(market):
			market.hover_charm(true)
			secret_vitrine.set_hovered("", -1)
		else:
			market.hover_charm(false)
			_paint_bay_hover(secret_vitrine, _secret_bay_rect(), market.vitrine_annotation,
				func(data: Dictionary, anchor: Vector2) -> void:
					market.show_bay_annotation(data, anchor),
				func() -> void: market.hide_bay_annotation(),
				market.bay_annotation_has_point, market.foot_hover)
		_sync_secret_plates(market)

## Ob der Zeiger auf dem Charm-Sitz des Hinterzimmers liegt (leer = kein Charm,
## abgedeckt oder weggezoomt). Gleiches Tor wie die Bucht: nur am Fokus, und nur
## wenn der Tisch bedienbar ist.
func _secret_charm_hovered(market: SecretShopView) -> bool:
	if not _secret_curtain or not _table_operable():
		return false
	var seat := market.charm_seat_rect_px()
	if seat.size.x <= 0.0:
		return false
	var pixel := _screen_pixel(get_viewport().get_mouse_position())
	return pixel.x >= 0.0 and seat.has_point(pixel)

## Die STEHENDEN Schilder der Hinterzimmer-Bucht (Seelen-Zeile plus ⚡-Preis, die
## Laden-Grammatik "Hinsehen braucht keinen Zeiger"): je Bild gemeldet wie der
## Griff, das Fenster baut nur bei Änderung um (Signatur). Unter dem Vorhang und
## während einer Fahrt steht kein Schild - unter reisender Ware wäre es gelogen.
func _sync_secret_plates(market: SecretShopView) -> void:
	if secret_vitrine == null or not is_instance_valid(secret_vitrine) \
			or run == null or not _secret_curtain \
			or not secret_vitrine.bowl_settled():
		market.set_bay_plates([])
		return
	var entries: Array = []
	for kind: String in [ShopController.KIND_ENGRAVING_PACK, ShopController.KIND_DIE]:
		for i in run.secret_stock.size():
			var spot := secret_vitrine.spot_of(kind, i)
			if spot != Vector3.ZERO:
				entries.append({"kind": kind, "index": i,
					"px": table_screen.world_to_pixel(spot)})
	market.set_bay_plates(entries)

## Griff und (wo es eine gibt) Beschriftung EINER Auslage. Ein leeres Rechteck
## heißt: abgedeckt oder weggezoomt - dann ist nichts greifbar. Der LADEN greift
## nur (seine Ware trägt ihre Auskunft selbst und übergibt keine Callables), das
## Hinterzimmer schreibt zusätzlich auf seine Fenster-Karte. holds meldet, ob der
## Zeiger auf der stehenden Karte liegt - dort bleibt alles, wie es steht (ihre
## Schlüsselwörter sind Klickziele).
func _paint_bay_hover(bay: VitrineView, rect: Rect2, annotate := Callable(),
		show := Callable(), hide := Callable(), holds := Callable(),
		hold_hover := Callable()) -> void:
	if bay == null or not is_instance_valid(bay):
		return
	if rect.size.x <= 0.0:
		bay.set_hovered("", -1)
		if hide.is_valid():
			hide.call()
		return
	var pixel := _screen_pixel(get_viewport().get_mouse_position())
	if pixel.x >= 0.0 and holds.is_valid() and bool(holds.call(pixel)):
		# Der Zeiger steht auf der gehaltenen Auskunft: nur sie selbst darf noch
		# antworten (das Netz des Schwarzmarkt-Fußes hovert seine Zellen).
		if hold_hover.is_valid():
			hold_hover.call(pixel)
		return
	var item := _bay_item_at(bay, rect, pixel)
	if item.is_empty():
		bay.set_hovered("", -1)
		if hide.is_valid():
			hide.call()
		return
	var kind: String = item["kind"]
	var index: int = item["index"]
	bay.set_hovered(kind, index)
	if not annotate.is_valid() or not show.is_valid():
		return
	var data: Dictionary = annotate.call(kind, index)
	if data.is_empty():
		if hide.is_valid():
			hide.call()
		return
	show.call(data, table_screen.world_to_pixel(item["spot"]))

## Das Stück unter einem DISPLAY-Pixel ({} = keins): der Punkt geht zurück in die
## Tischebene, und dort fragt die Auslage ihre Plätze ab.
func _bay_item_at(bay: VitrineView, rect: Rect2, pixel: Vector2) -> Dictionary:
	if pixel.x < 0.0 or rect.size.x <= 0.0 or not rect.has_point(pixel):
		return {}
	return bay.item_at(table_screen.pixel_to_world(pixel))

## Das AUFGEDECKTE Auslage-Rechteck des Ladens (leer = abgedeckt oder noch nicht
## gemessen). GEGRIFFEN wird, wo die Ware LIEGT: der Vorhang ist die ganze
## Bedingung, die Kamerastation keine - nur eine laufende Fahrt macht sie taub.
func _shop_bay_rect() -> Rect2:
	if charm_shop == null or not is_instance_valid(charm_shop) or not _vitrine_curtain \
			or not _table_operable():
		return Rect2()
	return charm_shop.vitrine_pit_rect()

## Dasselbe im Hinterzimmer: die Ware steht immer, also antwortet der Griff überall,
## wo sie zu sehen ist. Nur der KAUF-Klick hängt an der Station (_forward_vitrine_mouse).
func _secret_bay_rect() -> Rect2:
	var market := _secret_window()
	if market == null or not _secret_curtain or not _table_operable():
		return Rect2()
	return market.vitrine_pit_rect()

func _secret_window() -> SecretShopView:
	if table_screen == null or table_screen.secret_shop_window == null \
			or not is_instance_valid(table_screen.secret_shop_window):
		return null
	return table_screen.secret_shop_window

## Klick-Schlichtung in den Auslage-Rechtecken (true = verbraucht). Die beiden
## Buchten liegen unter verschiedenen Fenstern, ihre Rechtecke überschneiden sich
## also nie - gefragt wird der Reihe nach, wer den Punkt hat.
func _forward_vitrine_mouse(event: InputEventMouse, pixel: Vector2) -> bool:
	if _forward_bay_mouse(shop_vitrine, _shop_bay_rect(), event, pixel,
			_buy_vitrine_item):
		return true
	# GEKAUFT wird nur an der eigenen Station (die Wett-Tresen-Regel, zweite benannte
	# Ausnahme von "Sichtbar heißt bedienbar"): aus der Ferne fällt der Klick durch
	# und wird zum Zoom. Bewegungen laufen weiter überall - Hover und Schilder auch.
	if event is InputEventMouseButton \
			and camera_rig.mode != CameraRig.Mode.SECRET_SHOP:
		return false
	var market := _secret_window()
	return _forward_bay_mouse(secret_vitrine, _secret_bay_rect(), event, pixel,
		_buy_secret_item,
		market.bay_annotation_has_point if market != null else Callable())

## Die Schlichtung EINER Auslage: liegt der Zeiger auf der Beschriftung, geht der
## Klick durch die normale Weiterleitung an ihre Schlüsselwörter; sonst kauft der
## physische Griff, und wo nichts liegt, schluckt die Auslage den Klick.
func _forward_bay_mouse(bay: VitrineView, rect: Rect2, event: InputEventMouse,
		pixel: Vector2, buy: Callable, holds := Callable()) -> bool:
	if bay == null or not is_instance_valid(bay) or rect.size.x <= 0.0 \
			or pixel.x < 0.0 or not rect.has_point(pixel):
		return false
	if holds.is_valid() and bool(holds.call(pixel)):
		return false
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return false
	var item := _bay_item_at(bay, rect, pixel)
	if not item.is_empty():
		buy.call(String(item["kind"]), int(item["index"]))
	return true

## Der Griff kauft: JEDER Weg läuft über die bestehenden Buchungen des Ladens -
## die Bucht ist Bühne, nicht Regel. In der Ladenbucht liegen nur noch WÜRFEL,
## alles Versiegelte steckt in den Kassetten-Schlitzen.
func _buy_vitrine_item(kind: String, index: int) -> void:
	if charm_shop == null or kind != ShopController.KIND_DIE:
		return
	# Den PLATZ dieses Stücks merken: dort startet der Komet, sobald der Körper
	# abgesunken ist. Danach ist der Platz leer und nicht mehr zu erfragen -
	# gemerkt wird also VOR der Buchung.
	var depart := Vector2(-1, -1)
	if table_screen != null and shop_vitrine != null and is_instance_valid(shop_vitrine):
		var spot := shop_vitrine.spot_of(kind, index)
		if spot != Vector3.ZERO:
			depart = table_screen.world_to_pixel(spot)
	_vitrine_depart_px = depart
	match kind:
		ShopController.KIND_ENGRAVING_PACK:
			charm_shop.buy_engraving_pack(index)
		ShopController.KIND_SPECIAL:
			charm_shop.buy_single_special(index)
		ShopController.KIND_DIE:
			_buy_single_die(index, depart)

## Der offene Würfel: er sinkt in der Bucht, fliegt als Komet die Werkstatt-Ader
## entlang und STEIGT in der Schale rechts der Bank herein. Der Abgleich hält ihn
## so lange zurück (_fach_expecting), damit er nicht schon dort liegt, während er
## fliegt.
func _buy_single_die(index: int, depart: Vector2) -> void:
	var before := run.pending_dice.size() if run != null else 0
	_fach_expecting = true
	charm_shop.buy_single_die(index)
	_fach_expecting = false
	if run == null or run.pending_dice.size() <= before:
		return  # nicht bezahlbar oder schon verkauft - es fliegt nichts
	_deliver_die_to_fach(run.pending_dice[run.pending_dice.size() - 1], depart)

# --- Das Ausgabefach an der BESTANDS-Station ------------------------------------
# Der Hub kauft, der Vorrat nimmt auf: ein bezahlter Würfel LIEGT in der offenen
# Schale an der Bildschirm-rechten Kante des Pool-Trays, bis der Spieler ihn auf
# einen Vorrats-Würfel ZIEHT. Ihr Platz liegt AUSSERHALB des Pool-Lochs - die
# Neuzugänge stehen auch während der Runde sichtbar oben. Gebucht wird weiter
# allein über GameRun.

## Die Schale neben das Pool-Loch stellen (idempotent). Ihr Ort ist aus der POOL-
## Geometrie gerechnet, nie an einer Fensterkante gemessen: Lochrand plus
## Schachtwand plus Fuge, so berührt sie das offene Pit nie.
func _place_ausgabefach() -> void:
	if table_screen == null or pool_tray_view == null:
		return
	var field := _pool_field()
	if field.is_empty():
		return
	if ausgabefach == null or not is_instance_valid(ausgabefach):
		ausgabefach = AusgabefachView.new()
		add_child(ausgabefach)
	var spot := AusgabefachView.spot_beside(field["at"], field["half"], LiftShaftView.WALL)
	# Auf EINEN Platz getrimmt: darunter steht die Info-Säule, nicht der nächste Würfel.
	ausgabefach.setup(spot, AusgabefachView.single_half())
	_sync_ausgabefach()

## Das Rechteck der Schale in Display-Pixeln, gerechnet aus ihrer WELT-Lage (leer =
## es steht keine). Ziel jedes Liefer-Lichts, Fläche für Zeiger und Griff.
func _fach_rect_px() -> Rect2:
	if table_screen == null or ausgabefach == null or not is_instance_valid(ausgabefach) \
			or ausgabefach.half.x <= 0.0 or ausgabefach.half.y <= 0.0:
		return Rect2()
	var lo := ausgabefach.bounds_min()  # (Welt-x, Welt-z)
	var hi := ausgabefach.bounds_max()
	# Welt +X ist Bildschirm-oben, Welt +Z Bildschirm-rechts.
	var a := table_screen.world_to_pixel(Vector3(hi.x, 0.0, lo.y))
	var b := table_screen.world_to_pixel(Vector3(lo.x, 0.0, hi.y))
	return Rect2(a, b - a)

## Die INFO-SÄULE steht UNTER der Schale (Bildschirm-unten = Welt −X): über ihr
## liegt der eine offene NEUZUGANG, darin steht, was er ist und tut. Sie muß auf der
## ANZEIGE liegen - reicht sie unter den Werkstatt-Streifen, wird sie an dessen
## Oberkante gekürzt; bleibt dann zu wenig übrig, steht sie gar nicht.
const FACH_NET_GAP_SHARE := 0.25   # Fuge unter der Schale, als Anteil ihrer Breite
const FACH_NET_WIDTH_SHARE := 1.9  # ihre Breite als Vielfaches der Schalenbreite
const FACH_NET_MIN_FILL := 0.7     # bleibt weniger davon übrig, steht sie gar nicht

## Oberkante des WERKSTATT-STREIFENS in Display-Pixeln (0 = noch nicht gemessen):
## dort endet der freie Filz unter dem Vorrat, und dort endet die Info-Säule.
var _bench_top_px := 0.0

## Ihre SPALTE in Display-Pixeln (x, Breite) - eine reine Funktion der Schale, ohne
## die Höhen-Frage.
func _fach_net_span() -> Vector2:
	var fach := _fach_rect_px()
	if fach.size.x <= 0.0:
		return Vector2.ZERO
	var wide := fach.size.x * FACH_NET_WIDTH_SHARE
	return Vector2(fach.get_center().x - wide * 0.5, wide)

## Ihr Rechteck in Display-Pixeln (leer = kein Platz oder keine Schale). Die HÖHE
## meldet die Säule selbst - hier wird keine gerechnet.
func _fach_net_rect() -> Rect2:
	if table_screen == null:
		return Rect2()
	var fach := _fach_rect_px()
	var span := _fach_net_span()
	if fach.size.y <= 0.0 or span.y <= 0.0:
		return Rect2()
	var top := fach.position.y + fach.size.y + fach.size.x * FACH_NET_GAP_SHARE
	var tall := FachNetView.height_for(span.y)
	# Unter dem Vorrat beginnt der Werkstatt-Streifen: bis dorthin, nicht bis zur
	# Displaykante.
	var floor_px := float(table_screen.size.y)
	if _bench_top_px > 0.0:
		floor_px = minf(floor_px, _bench_top_px)
	var room := floor_px - top
	if room < tall * FACH_NET_MIN_FILL:
		return Rect2()
	return Rect2(Vector2(span.x, top), Vector2(span.y, minf(tall, room)))

## Die Säule zeigt AUSSCHLIESSLICH den Neuzugang der Schale (2026-09-04: der
## Werkstatt-Zielwürfel hat sein eigenes Netz im Streifen). Leer heißt: sie
## steht gar nicht. Je Bild gefragt, gebaut nur der Wechsel.
func _sync_fach_nets() -> void:
	if table_screen == null or table_screen.fach_net_window == null \
			or not is_instance_valid(table_screen.fach_net_window):
		return
	var window := table_screen.fach_net_window
	var rect := _fach_net_rect()
	var shown: DieDefinition = null
	if ausgabefach != null and is_instance_valid(ausgabefach) \
			and not ausgabefach.items.is_empty():
		shown = ausgabefach.items[0]["def"]
	if shown == null or rect.size.x <= 0.0:
		window.set_die(null)
		table_screen.hide_fach_net_window()
		return
	table_screen.place_fach_net_window(rect)
	window.set_die(shown)

## Die hinterlegten Würfel in die Schale stellen - EIN idempotenter Schreiber.
## Ein Würfel, der noch unterwegs ist, bekommt seinen Platz und wartet mit dem
## Körper auf seinen Kometen.
func _sync_ausgabefach() -> void:
	if ausgabefach == null or not is_instance_valid(ausgabefach):
		return
	var stashed: Array[DieDefinition] = []
	if run != null:
		stashed = run.pending_dice
	if _fach_expecting and not stashed.is_empty():
		ausgabefach.expect_arrival(stashed[stashed.size() - 1])
	ausgabefach.present(stashed)

func _on_pending_dice_changed() -> void:
	_sync_ausgabefach()

## Die Fahrt eines gekauften Würfels: Absinken in der Bucht, Komet über die
## Hub-Ader bis zum Magazin, kurzer Meteor-Bogen in die Schale, Steigen darin.
## Reine Bühne - gebucht ist längst, und ein Laufwechsel mitten in der Fahrt lässt
## sie ins Leere laufen.
func _deliver_die_to_fach(def: DieDefinition, depart: Vector2) -> void:
	if table_screen == null or ausgabefach == null or not is_instance_valid(ausgabefach):
		return
	var from := depart
	if from.x < 0.0 and charm_shop != null:
		from = charm_shop.vitrine_pit_rect().get_center()
	var launched := run
	await get_tree().create_timer(VitrineView.take_out_time()).timeout
	if run != launched or table_screen == null or not is_instance_valid(ausgabefach):
		return
	var travel := table_screen.fach_delivery_comet(from, SLOT_DIE_COLOR,
		_fach_rect_px().get_center())
	await get_tree().create_timer(maxf(travel, 0.01)).timeout
	if run != launched or not is_instance_valid(ausgabefach):
		return
	ausgabefach.deliver(def)

## Das SICHTBARE Rechteck der Schale (leer = in einer der beiden Werkbank-
## Nahstufen, wo sie außerhalb des Rahmens liegt, oder während einer Fahrt). Sonst
## ist sie greifbar, wo sie zu sehen ist - auch aus der Freikamera.
func _fach_rect() -> Rect2:
	if not _table_operable() or camera_rig.workshop_close or camera_rig.die_focus:
		return Rect2()
	return _fach_rect_px()

## Der Würfel unter dem Zeiger hebt sich, die Auskunft läuft über den EINEN
## Kanal der Bank (Hinweis-Schirm). Gefragt je Bild - der Zeiger liegt auf dem
## Tisch, ein mouse_entered erreicht die Schale nie.
func _sync_fach_hover() -> Dictionary:
	if ausgabefach == null or not is_instance_valid(ausgabefach):
		return {}
	var rect := _fach_rect()
	if rect.size.x <= 0.0:
		ausgabefach.set_hovered(0)
		return {}
	var pixel := _screen_pixel(get_viewport().get_mouse_position())
	if pixel.x < 0.0 or not rect.has_point(pixel):
		ausgabefach.set_hovered(0)
		return {}
	var item := ausgabefach.item_at(table_screen.pixel_to_world(pixel))
	if item.is_empty():
		ausgabefach.set_hovered(0)
		return {}
	ausgabefach.set_hovered(int(item["key"]))
	return item

## Druck in der Schale (true = verbraucht): er startet eine MÖGLICHE Zieh-Geste an
## dem Würfel darunter - erst der Weg entscheidet zwischen Tausch und Dossier. Auf
## leerem Fachboden fällt der Klick durch, damit die Navigation ihn bekommt.
func _forward_fach_mouse(event: InputEventMouse, pixel: Vector2) -> bool:
	if _deck_glass:
		return false  # solange das Glas steht, schweigt die Schale
	var rect := _fach_rect()
	if rect.size.x <= 0.0 or pixel.x < 0.0 or not rect.has_point(pixel):
		return false
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	var item := ausgabefach.item_at(table_screen.pixel_to_world(pixel))
	if item.is_empty():
		return false
	fach_drag_index = int(item["index"])
	fach_drag_key = int(item["key"])
	fach_drag_start_pos = event.position
	fach_is_dragging = false
	fach_drag_swaps = _fach_swap_live()
	# KEIN Tilt-Lock (Spieler-Entscheid 2026-08-31): die Kamera neigt beim Tausch-Zug
	# weiter mit der Maus - der Ghost hängt an _mouse_on_plane und folgt je Bild.
	return true

## Darf jetzt getauscht werden? Dasselbe Fenster wie das Umlegen im Tray: der
## Vorrat steht, die Runde ist noch nicht unterschrieben, und das Tray ist die
## lokale Bühne (oder die Freikamera). Hover und Dossier antworten überall.
func _fach_swap_live() -> bool:
	if run == null or _dice_editing_locked() or not _pool_standing:
		return false
	if _exchange_hidden != null:
		return false  # ein Tausch fährt noch - er hat den Sitz
	return _felt_pick_live(CameraRig.Mode.WORKSHOP) or _felt_pick_live(CameraRig.Mode.POOL)

func _handle_fach_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		if fach_is_dragging:
			_snap_fach_ghost_home(fach_drag_ghost, fach_drag_home,
				ausgabefach.die_at(fach_drag_index))
			fach_drag_ghost = null
		_end_fach_drag()
		return
	if event is InputEventMouseMotion:
		# Erst der Weg macht die Geste - und nur, wo getauscht werden darf.
		if not fach_is_dragging and fach_drag_swaps \
				and event.position.distance_to(fach_drag_start_pos) > REORDER_DRAG_THRESHOLD:
			fach_is_dragging = true
			_begin_fach_drag()
		if fach_is_dragging:
			_update_fach_drag(event.position)
		return
	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if fach_is_dragging:
			_finish_fach_drag(event.position)
			return
		# Nur getippt: die GLAS-ANSICHT geht ENG auf - der Vorrat versinkt, und auf dem
		# geschlossenen Glas steht die Frage, wohin der Neue soll.
		_end_fach_drag()
		_open_deck_glass(false)

## Der gegriffene Neuzugang verlässt die Schale: sein Körper wird eingezogen (ein
## Würfel wird nie zweimal gezeigt), ein freier Ghost folgt ab jetzt der Maus.
func _begin_fach_drag() -> void:
	var def := ausgabefach.die_at(fach_drag_index)
	if def == null:
		fach_is_dragging = false
		return
	# Der Platz wird JETZT gemerkt: gleich hält die Schale den Würfel zurück, und
	# dann steht sein Platz nicht mehr in ihrer Liste.
	fach_drag_home = _fach_spot(fach_drag_key)
	ausgabefach.set_hovered(0)
	ausgabefach.expect_arrival(def)  # sein Platz bleibt, sein Körper geht
	fach_drag_ghost = _spawn_deck_ghost(def)
	fach_drag_ghost.global_position = fach_drag_home + Vector3.UP * REORDER_LIFT_HEIGHT

## Der Weltpunkt eines liegenden Fach-Würfels (die Schale kennt ihn, wir fragen nur).
func _fach_spot(key: int) -> Vector3:
	for item in ausgabefach.items:
		if int(item["key"]) == key:
			return item["spot"]
	return ausgabefach.global_position

func _update_fach_drag(screen_pos: Vector2) -> void:
	if fach_drag_ghost == null:
		return
	var hit: Variant = _mouse_on_plane(screen_pos,
		pool_tray_view.global_position.y + DiceTrayView.FLOAT_HEIGHT + REORDER_LIFT_HEIGHT)
	if hit != null:
		fach_drag_ghost.global_position = hit

## Loslassen: über einem belegten Pool-Sitz wird getauscht, sonst gleitet der
## Neuzugang zurück in die Schale.
func _finish_fach_drag(screen_pos: Vector2) -> void:
	var seat := _pool_tray_slot_at(screen_pos)
	var index := fach_drag_index
	var home := fach_drag_home
	var def := ausgabefach.die_at(index)
	var ghost := fach_drag_ghost
	fach_drag_ghost = null
	var swaps := fach_drag_swaps
	_end_fach_drag()
	if not swaps or seat < 0 or not _exchange_into_seat(index, seat, ghost):
		_snap_fach_ghost_home(ghost, home, def)

func _end_fach_drag() -> void:
	fach_drag_index = -1
	fach_drag_key = 0
	fach_is_dragging = false
	fach_drag_swaps = false

## Laufwechsel mitten in der Geste: der Ghost fällt, die Geste endet - gleiten
## würde er auf einen Platz, den es nicht mehr gibt.
func _drop_fach_drag_hard() -> void:
	_drop_stage_body(fach_drag_ghost)
	fach_drag_ghost = null
	if fach_drag_index != -1:
		_end_fach_drag()
	_settle_exchange_hard()

## Kein gültiges Ziel: der Ghost gleitet sichtbar in seinen Fach-Platz zurück und
## übergibt dort HART an den Schalen-Körper - kein zweiter Auftritt. Ohne Ghost
## steht der Körper sofort wieder: ein zurückgehaltener Würfel darf nie liegen
## bleiben.
func _snap_fach_ghost_home(ghost: Node3D, home: Vector3, def: DieDefinition) -> void:
	var land := func() -> void:
		_drop_stage_body(ghost)
		if ausgabefach != null and is_instance_valid(ausgabefach):
			if def != null:
				ausgabefach.deliver(def)
			ausgabefach.settle()
	if ghost == null or not is_instance_valid(ghost):
		land.call()
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ghost, "global_position", home, DECK_SHIFT_DURATION)
	tween.tween_callback(land)

# --- Der TAUSCH: Neuzugang auf einen Pool-Sitz gezogen ---------------------------
# Gebucht wird SOFORT (exchange_pending_die - Buchung vor dem Licht), erst danach
# fährt die Zeremonie: der ALTE Würfel sinkt in einer würfelgroßen Sektion unter
# seinem Sitz ein, der neue gleitet in den frei werdenden Platz. Kein Restwert -
# tauschen ist nie "Verkaufen light".

## true = gebucht und die Fahrt läuft. ghost ist der gezogene Körper; er wird
## Eigentum der Zeremonie.
func _exchange_into_seat(pending_index: int, seat: int, ghost: Node3D) -> bool:
	if run == null or pool_tray_view == null or seat < 0 \
			or seat >= pool_tray_view.slot_defs.size():
		return false
	var target: DieDefinition = pool_tray_view.slot_defs[seat]
	if target == null:
		return false
	var pool_index := run.owned_pool.find(target)
	if pool_index < 0:
		return false
	# Was versinkt, ist der ALTE Inhalt - nach become trägt die Instanz den neuen.
	var leaving := target.instantiate()
	var at := pool_tray_view.slot_global_position(seat)
	# Der Sitz gilt ab JETZT als leer, sonst zeigte der pool_changed-Abgleich den
	# neuen Würfel schon, während der alte noch fährt.
	_exchange_hidden = target
	if not run.exchange_pending_die(pending_index, pool_index):
		_exchange_hidden = null
		return false
	_refresh_dice_trays()
	_exchange_gen += 1
	var generation := _exchange_gen
	var launched := run
	_exchange_ghost = ghost
	if ghost != null and is_instance_valid(ghost):
		var glide := create_tween()
		glide.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glide.tween_property(ghost, "global_position", at, DECK_SHIFT_DURATION)
	_sink_exchanged_die(leaving, seat, at, generation, launched)
	return true

## Der alte Würfel geht dort hinaus, wo er SCHWEBTE: eine würfelgroße Sektion
## öffnet unter seinem Sitz und zieht ihn ein (dieselbe Bahn wie der Schluck - im
## Laden fährt dort nichts). Fällt sie aus, steht der Tausch sofort.
func _sink_exchanged_die(def: DieDefinition, seat: int, at: Vector3,
		generation: int, launched: GameRun) -> void:
	var field := _bench_pool_field(seat)
	var body: Node3D = null
	var tween: Tween = null
	if not field.is_empty() and table_screen != null:
		body = _spawn_deck_ghost(def)
		body.global_position = at
		# Unter der Fläche spiegelt er nicht - sein Bild geisterte sonst darüber.
		ScreenReflection.set_reflective(body, false)
		var shaft := _swallow_shaft_for(0, field["at"], field["half"], _tray_shaft_depth())
		if shaft != null:
			tween = shaft.run_exit([body], [at], 0.0)
	_exchange_body = body
	if tween == null:
		_land_exchange(seat, generation, launched)
		return
	tween.finished.connect(func() -> void:
		_land_exchange(seat, generation, launched))

## Die Fahrt steht: der Sitz zeigt seinen neuen Inhalt, das Feld rastet ein.
func _land_exchange(seat: int, generation: int, launched: GameRun) -> void:
	if generation != _exchange_gen or run != launched:
		return  # ein Abbruch hat längst hart aufgeräumt
	_settle_exchange_hard()
	if pool_tray_view != null and seat >= 0 and seat < pool_tray_view.slot_roots.size():
		pool_tray_view.slot_emitter(seat).ripple()

## Der EINE harte Aufräum-Pfad des Tauschs: beide Körper fort, die Sektion bündig,
## der Sitz wieder sichtbar. Laufwechsel, Reset und die fertige Fahrt gehen hier
## durch - ein abgebrochener Tween schuldet nichts.
func _settle_exchange_hard() -> void:
	_exchange_gen += 1
	# Unsere Bahn ist die des SCHLUCKS - bündig gestellt wird sie nur, wenn dieser
	# Tausch sie wirklich gefahren hat.
	if _exchange_body != null and _swallow_shafts.size() > 0 \
			and _swallow_shafts[0] != null and is_instance_valid(_swallow_shafts[0]):
		_swallow_shafts[0].settle_hard()
	_drop_stage_body(_exchange_body)
	_exchange_body = null
	_drop_stage_body(_exchange_ghost)
	_exchange_ghost = null
	if _exchange_hidden == null:
		return
	_exchange_hidden = null
	_refresh_dice_trays()

# --- Die Hinterzimmer-Auslage -----------------------------------------------
# Dieselbe Miniatur wie im Laden, nur ohne Ausgabefach - dort geht jede Ware
# versiegelt hinaus. Aufgedeckt wird nach der FREISCHALTUNG statt nach einer Phase
# oder der Kamera: die Ware steht, sobald es sie gibt.

## Stellt die Auslage an das Schwarzmarkt-Fenster. Wie im Laden zwei Bilder
## Geduld - das Rechteck steht erst, wenn die Seite ausgelegt ist.
func _sync_secret_vitrine() -> void:
	if _secret_window() == null:
		return
	_secret_gen += 1
	var generation := _secret_gen
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _secret_gen or _secret_window() == null:
		return
	_place_secret_vitrine()
	_sync_secret_curtain()
	# Erst aufdecken, dann die Ware: der aufgesparte Grad IST der Auftritt des
	# Aufdeckens. Abgedeckt bleibt es beim harten Stellen.
	if _secret_curtain:
		var grade := _secret_grade
		_secret_grade = ShopController.GRADE_STAND
		_sync_secret_stock(grade)
	else:
		_sync_secret_stock()

func _place_secret_vitrine() -> void:
	var market := _secret_window()
	var rect := market.vitrine_pit_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if not market.lexikon_requested.is_connected(open_lexikon):
		market.lexikon_requested.connect(open_lexikon)
	if secret_vitrine == null or not is_instance_valid(secret_vitrine):
		secret_vitrine = VitrineView.new("SecretVitrine")
		# EINE Reihe auf gleicher Tiefe, aber je Stück eine eigene Sektion.
		secret_vitrine.single_row = true
		add_child(secret_vitrine)
		_wire_shafts(secret_vitrine, TableScreen.secret_pits())
	secret_vitrine.deck_skin = table_screen.display_skin()
	secret_vitrine.wall_skin = PIT_SKIN
	_place_vitrine(secret_vitrine, rect, _secret_curtain)

## Der EINE Schreiber der Hinterzimmer-Auslage.
func _set_secret_shown(shown: bool) -> void:
	if secret_vitrine != null and is_instance_valid(secret_vitrine):
		secret_vitrine.set_shown(shown)

## Die Hehlerware steht IMMER auf dem Tisch, sobald sie freigeschaltet ist - die
## Kamera-Bedingung ist 2026-08-30 gefallen. Fort ist sie nur, wenn das Fenster fort
## ist, das Gitter noch steht oder der Lauf gewechselt hat; dann geht sie den harten
## Weg. GEKAUFT wird trotzdem nur an der eigenen Station (_forward_vitrine_mouse).
func _sync_secret_curtain() -> void:
	var market := _secret_window()
	var want := market != null and market.visible and run != null \
		and run.secret_shop_unlocked
	if want == _secret_curtain:
		return
	_secret_curtain = want
	if want:
		_set_secret_shown(true)
		return
	_hide_secret_hard()

## Der harte Sofort-Weg des Hinterzimmers - und der Abbruch jeder Fahrt.
func _hide_secret_hard() -> void:
	var market := _secret_window()
	if market != null:
		market.hide_bay_annotation(true)  # hart: keine Verweilzeit über dem Abbau
	_set_secret_shown(false)
	_close_lift_shafts()
	# Dieselbe physische Regel wie im Laden: eine körperlich LEERE Bucht schuldet
	# beim nächsten Aufdecken eine ANKUNFT.
	_secret_grade = ShopController.grade_on_stand(_secret_grade,
		secret_vitrine != null and is_instance_valid(secret_vitrine)
			and secret_vitrine.body_count() > 0)

## Die Auslage des Hinterzimmers stellen. Das Fenster fasst nie einen Körper an -
## es meldet, was liegt.
func _sync_secret_stock(grade := ShopController.GRADE_STAND) -> void:
	var market := _secret_window()
	if secret_vitrine == null or not is_instance_valid(secret_vitrine) or market == null:
		return
	secret_vitrine.present_graded(market.vitrine_stock(), grade)

## Neue Auslage gemeldet: bei zugedeckter Bucht wird lautlos umgebaut und der Grad
## fürs Aufdecken aufgehoben, bei offener ist ein Neuwurf ein sichtbarer
## Warenumschlag.
func _on_secret_vitrine_changed() -> void:
	var market := _secret_window()
	if market == null:
		return
	var grade := market.vitrine_grade()
	if not _secret_curtain:
		_secret_grade = ShopController.louder_grade(_secret_grade, grade)
		_sync_secret_stock()
		return
	_swap_secret_stock(grade)

## Der Neuwurf ist EIN Förderband-Schritt: die alte Ware vorn hinaus, die neue von
## hinten nach - eine Bewegung, ein Takt.
func _swap_secret_stock(grade: String) -> void:
	var market := _secret_window()
	if secret_vitrine == null or not is_instance_valid(secret_vitrine) or market == null:
		return
	if grade == ShopController.GRADE_STAND:
		_sync_secret_stock()  # ein Kauf lässt die übrige Ware liegen
		return
	_secret_swap += 1
	secret_vitrine.swap_to(market.vitrine_stock())

## Der Griff im Hinterzimmer kauft: Gattung und Index meinen denselben Auslage-
## Platz, gebucht wird über buy_secret_offer wie an der Karte. Der PLATZ wird VOR
## der Buchung gemerkt - danach ist er leer und nicht mehr zu erfragen.
func _buy_secret_item(kind: String, index: int) -> void:
	var market := _secret_window()
	if market == null or secret_vitrine == null or not is_instance_valid(secret_vitrine):
		return
	var spot := secret_vitrine.spot_of(kind, index)
	_secret_depart_px = table_screen.world_to_pixel(spot) if spot != Vector3.ZERO \
		else Vector2(-1, -1)
	market.buy_offer(index)

## Der gekaufte Seelenwürfel: derselbe Flug wie jede Hehlerware, nur endet er im
## AUSGABEFACH statt im Magazin - ein Würfel wird nie versiegelt. Gebucht hat
## buy_secret_offer längst (stash_die); hier fährt nur die Ware.
func _on_secret_die_purchased(def: DieDefinition) -> void:
	if table_screen == null or run == null or def == null \
			or ausgabefach == null or not is_instance_valid(ausgabefach):
		return
	var market := _secret_window()
	if market == null:
		return
	var launched := run
	ausgabefach.expect_arrival(def)
	var depart := _secret_depart_px
	_secret_depart_px = Vector2(-1, -1)
	if depart.x < 0.0:
		depart = market.position + market.size * 0.5  # die Karte am Sitz liegt nicht in der Bucht
	# Erst ist die Ware unten, dann fliegt sie.
	await get_tree().create_timer(VitrineView.take_out_time()).timeout
	if run != launched or table_screen == null or not is_instance_valid(ausgabefach):
		return
	var rect := _fach_rect_px()
	var target := rect.get_center() if rect.size.x > 0.0 else depart
	var travel := table_screen.secret_delivery_comet(depart, target, SLOT_DIE_COLOR)
	if travel > 0.0:
		await get_tree().create_timer(travel).timeout
	if run != launched or not is_instance_valid(ausgabefach):
		return
	ausgabefach.deliver(def)

## Hehlerware gekauft: KAUFEN HEISST ÜBERGEBEN. Der Körper sinkt ab, ein Komet
## fährt die Hinterzimmer-Ader in den Hub und weiter die Werkstatt-Ader, auf dem
## Magazin-Platz steigt die Kassette. Gebucht hat buy_secret_offer längst - hier
## fliegt nur noch die Ware.
func _on_secret_goods_purchased(uid: int) -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop) or run == null:
		return
	var pack := run.pack_by_uid(uid)
	var market := _secret_window()
	if pack == null or market == null:
		return
	var launched := run
	workshop.expect_pack_delivery(uid)
	var tint: Color = PackDrawerView.COLORS.get(Pack.shelf_of(pack), Color.WHITE)
	var depart := _secret_depart_px
	_secret_depart_px = Vector2(-1, -1)
	if depart.x < 0.0:
		depart = market.position + market.size * 0.5  # die Karte am Sitz liegt nicht in der Bucht
	# Erst ist die Ware unten, dann fliegt sie.
	await get_tree().create_timer(VitrineView.take_out_time()).timeout
	if run != launched or table_screen == null or not is_instance_valid(workshop):
		return
	var travel := table_screen.secret_delivery_comet(
		depart, _pack_arrival_px(workshop, uid), tint)
	if travel > 0.0:
		await get_tree().create_timer(travel).timeout
	if run != launched:
		return
	_land_pack_in_magazine(workshop, uid, tint)

## Die Magazin-Kassetten: je Paket (uid) EIN Körper, LIEGEND auf dem Tablett seiner
## ETAGE - Netz nach oben, lesbar ohne Hover. Wer schon liegt, bleibt derselbe
## Körper; ein neuer Platz in derselben Reihe (Umsortieren) ist ein GLEITEN, ein
## Etagenwechsel ein Umzug ins andere Fach.
func _sync_shelf_cells(workshop: WorkshopView) -> void:
	var entries := workshop.drawer_entries()
	var reserved := workshop.press_slot_uids()
	var wanted: Dictionary = {}
	for entry in entries:
		var uid := int(entry.get("uid", 0))
		# Was noch als Licht fliegt oder heimkehrt, hat keinen Körper im Fach.
		if uid <= 0 or bool(entry.get("withheld", false)) or _cell_returns.has(uid):
			continue
		wanted[uid] = entry.get("pack")
	for uid: int in shelf_cells.keys():
		# Reservierte nicht abräumen: ihre Körper übernimmt der Schlitz-Abgleich.
		if not wanted.has(uid) and not reserved.has(uid):
			_free_data_cell(shelf_cells[uid])
			shelf_cells.erase(uid)
	var fresh := 0
	# Fährt der Kreislauf gerade, gehören die Karten IHM: sie hängen an ihren
	# Tabletts und reisen mit. Der Sitz-Schreiber gleicht danach ab (_settle_shelf_ride).
	var riding := paternoster != null and is_instance_valid(paternoster) \
		and paternoster.riding()
	for entry in entries:
		var uid := int(entry.get("uid", 0))
		if not wanted.has(uid):
			continue
		var pack: Pack = wanted[uid]
		var line := workshop.shelf_row_of(uid)
		var target := _shelf_seat(workshop, uid, line)
		var cell: DataCellView = shelf_cells.get(uid)
		if cell == null or not is_instance_valid(cell):
			cell = _spawn_data_cell(Pack.shelf_of(pack), pack.tier, target, pack.stamp_net)
			cell.set_body_scale(workshop.shelf_cell_scale())
			shelf_cells[uid] = cell
			_show_shelf_cell(cell, uid, line, target, fresh)
			fresh += 1
		elif not cell.visible:
			_show_shelf_cell(cell, uid, line, target, fresh)
			fresh += 1
		elif cell.busy():
			pass  # sie gleitet oder richtet sich gerade - nicht dazwischenfunken
		elif riding:
			pass  # der KREISLAUF trägt sie; ein Gleiten daneben führe sie doppelt
		elif _shelf_seated(cell, line, target):
			pass  # sie liegt schon dort - der Abgleich schreibt nichts um
		elif paternoster != null and cell.get_parent() == paternoster.fach(line):
			cell.glide_to(target, DATA_CELL_SLIDE_TIME)  # dieselbe Reihe, neuer Platz
		else:
			_lay_shelf_hard(cell, line, target)  # ein Reihenwechsel zieht um
		# Die ×n-Marke heißt jetzt BÜNDEL: mehrere Stücke in EINER Karte.
		cell.set_count(maxi(pack.count, 1))
		cell.set_dimmed(workshop.shelf_locked())
		# Der Körper wächst mit seinem Platz - reine Anzeige, der Anker bleibt
		# derselbe Glaspunkt.
		cell.set_body_scale(workshop.shelf_cell_scale())
		# Der GRIFF zieht die liegende Akte aus der Grube bis über die Tischkante;
		# den Hub setzt der Wirt, ein Rückkehrer bekommt ihn in _finish_cell_return.
		cell.hover_lift = PaternosterView.hover_lift(workshop.shelf_cell_scale())
		cell.hover_slide = 0.0  # der Turm-Kanal gilt nur in seiner Etage

## Der PLATZ einer Kassette in der Welt: ihr Platz in der LANE ihrer Reihe
## (Display-Pixel des Fensters) auf der Höhe des Tabletts - die gehört dem
## Paternoster.
func _shelf_seat(workshop: WorkshopView, uid: int, line: int) -> Vector3:
	var at := _data_cell_seat(workshop.pack_seat_px(uid))
	if paternoster != null and is_instance_valid(paternoster):
		at.y = paternoster.card_seat(line)
	return at

func _shelf_seated(cell: DataCellView, line: int, target: Vector3) -> bool:
	if paternoster == null or not is_instance_valid(paternoster):
		return cell.glass_position().distance_to(target) <= 0.01
	return paternoster.seated(cell, line, target)

## Der EINE harte Schreiber einer Kassette in ihrem MAGAZIN: sie LIEGT flach auf der
## Trittfläche ihres Tabletts und ist dessen KIND - eine Fahrt trägt sie mit.
func _lay_shelf_hard(cell: DataCellView, line: int, target: Vector3) -> void:
	cell.badge_on_face = true  # liegend liegt die x-n-Marke AUF der Karte
	cell.lie_on_glass(target)
	if paternoster != null and is_instance_valid(paternoster):
		paternoster.host_card(cell, line)

## Eine Kassette tritt in ihrem Fach an: GELIEFERT steigt sie aus ihrem Tablett
## (und lodert oben selbst), sonst wächst sie an Ort und Stelle - ein Neuaufbau
## des Fensters ist keine Lieferung. Auf einer PARKENDEN Reihe spielt gar nichts:
## eine Maschine, die keiner sieht, hat nicht gespielt - dort quittiert das Schild
## am Hebel.
func _show_shelf_cell(cell: DataCellView, uid: int, line: int, target: Vector3,
		fresh: int) -> void:
	var delivered := _rising_packs.erase(uid)
	var parked := paternoster != null and is_instance_valid(paternoster) \
		and not paternoster.shows(line)
	if delivered:
		_pending_cell_pops.erase(uid)  # das Steigen bringt seinen Ausbruch mit
	if parked or not delivered:
		_lay_shelf_hard(cell, line, target)
		if delivered:
			if page_lever != null and is_instance_valid(page_lever):
				page_lever.flash_sign()
		else:
			cell.materialize(float(fresh) * DATA_CELL_STAGGER)
		return
	# Die Ankunft auf einer LIEGENDEN Reihe: erst der Wirt, dann der Weg - sie steigt
	# aus ihrem Tablett heraus.
	cell.badge_on_face = true
	if paternoster != null and is_instance_valid(paternoster):
		paternoster.host_card(cell, line)
	cell.rise_through_glass(target, float(fresh) * DATA_CELL_STAGGER,
		DataCellView.RISE_TIME, true, PaternosterView.PITCH)

## DER TURM: je belegter Etage eine Zelle, LIEGEND in ihr - die Fläche mit dem
## Prägenetz nach oben, Kontakte nach Bild-rechts. Solange die Zeremonie nicht
## läuft, liegt sie NICHT eingerastet (ein Stück nach links herausgezogen). Eine
## frisch gelegte ist der KÖRPER ihres Magazin-Platzes; er fliegt im TRAGE-BOGEN
## herüber und legt sich dort um, gebucht war die Vormerkung längst.
func _sync_socket_cells(workshop: WorkshopView) -> void:
	var sorts := workshop.press_slot_sorts()
	var uids := workshop.press_slot_uids()
	var anchors := workshop.press_slot_anchors()
	var scale := PackDrawerView.CASSETTE_SCALE  # EINE Kartengröße, überall
	# Gegriffen wird nach UID, nicht nach Platz: ein UMSORTIEREN verrückt die
	# Indizes, aber es sind dieselben Körper - sie FAHREN um, sie entstehen nicht neu.
	var standing: Dictionary = {}
	for i in socket_cells.size():
		var held: DataCellView = socket_cells[i]
		var was: int = socket_uids[i] if i < socket_uids.size() else 0
		if held != null and is_instance_valid(held) and was > 0 and uids.has(was) \
				and not standing.has(was):
			standing[was] = held
		else:
			_free_data_cell(held)
	socket_cells.clear()
	socket_uids.clear()
	socket_cells.resize(sorts.size())
	socket_uids.resize(sorts.size())
	socket_uids.fill(0)
	var count := sorts.size()
	for i in mini(count, anchors.size()):
		var target := _tower_rest(i, anchors.size())  # Versatz nach ETAGE, nicht nach Füllstand
		var uid: int = uids[i] if i < uids.size() else 0
		var cell: DataCellView = standing.get(uid)
		if cell != null and is_instance_valid(cell):
			socket_cells[i] = cell
			socket_uids[i] = uid
			# Nicht shelf_locked: während des Durchlichts WERDEN diese Karten gelesen,
			# sie liegen hell da, bis das Licht sie verbraucht.
			cell.set_dimmed(workshop.editing_locked)
			cell.set_body_scale(scale)
			_arm_tower_hover(cell)
			if cell.busy() or workshop.burning():
				continue  # die Zeremonie fährt sie selbst - der Abgleich rührt sie nicht
			if cell.glass_position().distance_to(target) > 0.01:
				cell.glide_to(target, DATA_CELL_SLIDE_TIME)  # das Umlegen FÄHRT
			else:
				_lay_cell_hard(cell, target)
			continue
		if workshop.burning():
			continue  # während der Fahrt entsteht keine Karte neu - sie werden gelesen
		# Der Magazin-Körper dieses Pakets wird ÜBERNOMMEN, nie verdoppelt.
		cell = shelf_cells.get(uid)
		if cell != null and is_instance_valid(cell):
			shelf_cells.erase(uid)
		else:
			var slotted: Pack = run.pack_by_uid(uid) if run != null else null
			var home := _shelf_seat(workshop, uid, workshop.shelf_row_of(uid))
			cell = _spawn_data_cell(sorts[i], slotted.tier if slotted != null else 0,
				home, slotted.stamp_net if slotted != null else [])
			cell.set_body_scale(PackDrawerView.CASSETTE_SCALE)  # das Magazin-Maß
			cell.badge_on_face = true
			cell.lie_on_glass(home)  # sie startet LIEGEND in der Grube, nicht auf dem Glas
		cell.set_dimmed(workshop.shelf_locked())
		_arm_tower_hover(cell)
		socket_cells[i] = cell
		socket_uids[i] = uid
		_carry_data_cell(cell, target)  # nicht erwartet: der Körper folgt der Buchung

## Im TURM wird nicht GEHOBEN, sondern HERAUSGEZOGEN: der zweite Hover-Kanal
## verschiebt die Karte längs ihrer Achse nach Bild-links, damit ihr Netz frei liest.
func _arm_tower_hover(cell: DataCellView) -> void:
	cell.hover_lift = 0.0
	cell.hover_slide = TowerView.HOVER_SLIDE

## Ein Paket ist aus seinem Schlitz zurück ins Magazin gegangen: seine Zelle
## fliegt heim auf ihren Platz und WIRD dort wieder die Magazin-Kassette.
func _on_pack_unslotted(slot_index: int, uid: int) -> void:
	if slot_index < 0 or slot_index >= socket_cells.size():
		return
	var cell: DataCellView = socket_cells[slot_index]
	socket_cells.remove_at(slot_index)
	if slot_index < socket_uids.size():
		socket_uids.remove_at(slot_index)
	if cell == null or not is_instance_valid(cell) or uid <= 0:
		_free_data_cell(cell)
		return
	_cell_returns[uid] = cell
	_return_data_cell(cell, uid)  # nicht erwartet

## Ein Liefer-Licht ist eingeschlagen: die Kassette dieses Pakets lodert auf.
## Steht ihr Körper gerade nicht (Presse, Paket-Wahl), wartet der Pluster - wie
## der des Fensters auf sein Fach.
func _on_pack_landed(uid: int) -> void:
	var cell: DataCellView = shelf_cells.get(uid)
	# Sichtbar heißt HIER: im Baum sichtbar - eine Karte auf einer parkenden Etage
	# hängt in einem unsichtbaren Fach, und dort lodert nichts.
	if cell == null or not is_instance_valid(cell) or not cell.is_visible_in_tree():
		if not _pending_cell_pops.has(uid):
			_pending_cell_pops.append(uid)
		return
	cell.flare()

func _flush_cell_pops() -> void:
	if _pending_cell_pops.is_empty():
		return
	var waiting := _pending_cell_pops.duplicate()
	_pending_cell_pops.clear()
	for uid in waiting:
		_on_pack_landed(int(uid))

## Standplatz einer Zelle über einem Display-Pixel: OHNE Hub. Die Kassette hebt
## ihren Körper selbst auf halbe Dicke, ihr Ursprung liegt also schon auf dem
## Glas - und damit projiziert sie unter jeder Kamera auf genau diesen Punkt.
func _data_cell_seat(px: Vector2) -> Vector3:
	return _bench_hover_target(px, 0.0)

## Der EINGERASTETE Platz der Karte von Etage index: der Turm rechnet die Höhe, denn
## sie gehört ihm (ZERO = der Turm steht nicht).
func _tower_seat(index: int) -> Vector3:
	if tower == null or not is_instance_valid(tower):
		return Vector3.ZERO
	return tower.floor_point(index)

## Und ihr RUHEPLATZ: nicht eingerastet liegt sie um UNLATCHED_PULL nach Bild-links
## herausgezogen, plus den BUCHRÜCKEN-Versatz ihrer Etage (unten am weitesten
## heraus) - so schauen die unteren Sorten unter der obersten hervor.
func _tower_rest(index: int, count: int) -> Vector3:
	var seat := _tower_seat(index)
	if seat == Vector3.ZERO:
		return seat
	var length := DataCellView.HEIGHT * PackDrawerView.CASSETTE_SCALE
	return seat - Vector3(0.0, 0.0, length * TowerView.pull_share(index, count))

## Der EINE harte Schreiber einer Karte in ihrem FACH: sie LIEGT dort auf der
## Trittfläche, die große Fläche mit dem Prägenetz nach oben.
func _lay_cell_hard(cell: DataCellView, at: Vector3) -> void:
	cell.set_body_scale(PackDrawerView.CASSETTE_SCALE)
	cell.badge_on_face = true  # liegend liegt die x-n-Marke AUF der Karte
	cell.lie_on_glass(at)
	cell.set_socketed(true)  # die Kopfkante brennt: sie ist Teil der Rechnung

func _spawn_data_cell(sort: String, tier: int, at: Vector3,
		net: Array = []) -> DataCellView:
	var cell := DataCellView.new()
	cell.name = "DataCell"
	add_child(cell)
	cell.setup(sort, tier, net)
	# Dieselbe Vierteldrehung wie ein Tray-Würfel: erst damit steht das Siegel
	# aufrecht im Bild (Bildschirm-oben = Welt+X).
	cell.rotation.y = -PI / 2.0
	cell.global_position = at
	return cell

## DER GRUBEN-BOGEN aus dem Magazin in die ETAGE: die Kassette gleitet flach von
## ihrem Tablett durch den DURCHBRUCH in die Turm-Bucht und steigt dort auf ihre
## Etage - alles UNTER der Tischkante. Sie LIEGT dabei schon (das Umlegen ist mit
## dem Paternoster gestorben), verlässt aber ihr Fach: ein Bogen unter einem
## fahrenden Tablett wäre kein Bogen.
func _carry_data_cell(cell: DataCellView, target: Vector3) -> void:
	var launched := run
	cell.set_hovered(false)
	PaternosterView.rehost(cell, self)  # sie gehört nicht mehr ihrem Tablett
	_carrying[cell] = {"to": target, "seat": CARRY_SEAT_SOCKET, "uid": 0}
	# Der Bogen startet, wo sie LIEGT - nicht auf ihrem Glaspunkt über dem Loch.
	cell.lie_on_glass(cell.global_position)
	cell.arc_to(target, CARRY_TIME, _pit_carry_peak(cell.global_position, target))
	await get_tree().create_timer(CARRY_TIME).timeout
	if run != launched or not _still_carrying(cell):
		return
	_lay_cell_hard(cell, target)
	_carrying.erase(cell)
	cell.flare()

## Der SCHEITEL des Gruben-Bogens: so hoch, daß die Oberkante der fliegenden Karte
## unter der Tischkante bleibt. Innerhalb EINER Grube reist ein Spieler-Zug DURCH
## die Grube, nie über ihre Kante - dafür sind die beiden Löcher verbunden.
func _pit_carry_peak(from: Vector3, to: Vector3) -> float:
	var rim := table_screen.pixel_to_world(Vector2.ZERO).y if table_screen != null else 0.0
	var head := DataCellView.lying_over(PackDrawerView.CASSETTE_SCALE)
	return clampf(rim - PIT_CARRY_CLEAR - head - maxf(from.y, to.y), 0.0, CARRY_PEAK)

## Fliegt DIESER Körper noch unseren Bogen? Ein Aufräum-Pfad hat ihn sonst längst
## hart gesetzt oder freigegeben.
func _still_carrying(cell: DataCellView) -> bool:
	return cell != null and is_instance_valid(cell) and _carrying.has(cell)

## Der EINE harte Aufräum-Pfad der Trage-Bögen: jede fliegende Kassette steht hart
## auf ihrem Ziel (Endzustand zuerst - sie schuldet nichts). Eine zweite Fahrt, ein
## Laufwechsel und jeder Abbruch gehen hier durch.
func _settle_carries() -> void:
	if _carrying.is_empty():
		return
	var riding := _carrying.duplicate()
	_carrying.clear()
	for cell: DataCellView in riding:
		if cell == null or not is_instance_valid(cell):
			continue
		var ride: Dictionary = riding[cell]
		var target: Vector3 = ride.get("to", cell.glass_position())
		if String(ride.get("seat", "")) == CARRY_SEAT_PIT:
			_lay_shelf_hard(cell, int(ride.get("row", 0)), target)
		else:
			_lay_cell_hard(cell, target)

## DER GRUBEN-BOGEN zurück ins Magazin: sie gleitet LIEGEND durch den Durchbruch
## heim auf ihr Tablett - auch heimwärts kommt nichts über die Tischkante, und
## aufrichten muß sie sich nirgends mehr. Ist ihre Reihe GEPARKT, fährt gar nichts:
## sie liegt dort einfach wieder, unsichtbar. Der Anker wird erst NACH dem Neuaufbau
## geholt: das Fach hat sich eben neu gelegt.
func _return_data_cell(cell: DataCellView, uid: int) -> void:
	var launched := run
	await get_tree().process_frame
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if run != launched or cell == null or not is_instance_valid(cell):
		return
	if workshop == null or not is_instance_valid(workshop):
		_finish_cell_return(cell, uid, false)
		return
	cell.set_hovered(false)
	cell.set_socketed(false)
	var line := workshop.shelf_row_of(uid)
	var target := _shelf_seat(workshop, uid, line)
	var landed := run != null and run.pack_by_uid(uid) != null
	if paternoster != null and is_instance_valid(paternoster) \
			and not paternoster.shows(line):
		_lay_shelf_hard(cell, line, target)  # eine parkende Reihe spielt nichts
		_finish_cell_return(cell, uid, landed)
		return
	_carrying[cell] = {"to": target, "seat": CARRY_SEAT_PIT, "uid": uid, "row": line}
	cell.arc_to(target, CARRY_TIME, _pit_carry_peak(cell.global_position, target))
	await get_tree().create_timer(CARRY_TIME).timeout
	if run != launched or not _still_carrying(cell):
		return
	_carrying.erase(cell)
	_lay_shelf_hard(cell, line, target)
	_finish_cell_return(cell, uid, run != null and run.pack_by_uid(uid) != null)

## Angekommen: der Rückläufer WIRD wieder die Magazin-Kassette seines Pakets -
## kein zweiter Körper, kein Abgang. Liegt das Paket nicht mehr (Laufwechsel,
## Wett-Einsatz), fällt die Zelle weg; der nächste Abgleich bestätigt den Rest.
func _finish_cell_return(cell: DataCellView, uid: int, adopt: bool) -> void:
	_cell_returns.erase(uid)
	if not adopt or cell == null or not is_instance_valid(cell):
		_free_data_cell(cell)
		return
	var standing: DataCellView = shelf_cells.get(uid)
	if standing != null and is_instance_valid(standing) and standing != cell:
		_free_data_cell(standing)  # sollte nie stehen - der Abgleich meidet Rückkehrer
	shelf_cells[uid] = cell
	# Sie ist wieder Magazin-Kassette: der GRIFF zieht sie liegend aus der Grube.
	cell.hover_lift = PaternosterView.hover_lift(PackDrawerView.CASSETTE_SCALE)
	cell.hover_slide = 0.0
	if cell.visible:
		cell.flare()

## Laufwechsel: alle Körper fallen weg, auch die noch unterwegs sind. Es ist der
## EINZIGE Abgang - das Magazin liegt in der Schürze und tritt für keinen Ablauf
## mehr ab.
func _drop_data_cells() -> void:
	_settle_durchlicht()  # eine Zeremonie des alten Laufs schuldet nichts mehr
	for uid: int in shelf_cells:
		_free_data_cell(shelf_cells[uid])
	shelf_cells.clear()
	for cell in socket_cells:
		_free_data_cell(cell)
	socket_cells.clear()
	socket_uids.clear()
	for uid: int in _cell_returns:
		_free_data_cell(_cell_returns[uid])
	_cell_returns.clear()
	_pending_cell_pops.clear()
	_drop_tower()  # der Turm des alten Laufs steht nirgends mehr
	_rising_packs.clear()  # eine Fahrt des alten Laufs endet nirgends mehr
	# Der PATERNOSTER fährt hart auf Reihe 1+2 zurück - ein neuer Lauf beginnt vorn.
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop != null and is_instance_valid(workshop):
		workshop.shelf_head = 0
	if paternoster != null and is_instance_valid(paternoster):
		paternoster.set_head(0)
	_write_page_sign()
	_hovered_pack_uid = 0
	_hovered_step = -1
	_carrying.clear()  # kein Trage-Bogen überlebt den Laufwechsel

func _free_data_cell(cell: DataCellView) -> void:
	if cell == null or not is_instance_valid(cell):
		return
	_carrying.erase(cell)  # der Bogen gehört einem Körper, den es nicht mehr gibt
	# Eine Magazin-Karte hängt an ihrem TABLETT, nicht an scene_root - sie geht dort
	# fort, wo sie steht.
	if cell.get_parent() != null:
		cell.get_parent().remove_child(cell)
	cell.queue_free()

## Fußabdruck einer STEHENDEN Datenzelle in Display-Pixeln: die GRIFF-Zelle, an der
## Reihe und Magazin teilen. Seit der Welle P steht sie HOCHKANT (Fläche nach
## Bild-links), also Grifftiefe breit × Kartenbreite tief; seit dem Kappen-Tod ist
## GRIP_DEPTH nur noch ein Maß, kein Körper - die Teilung bleibt dieselbe. Danach
## sind die Magazin-Plätze und die Schacht-Münder geschnitten.
func _data_cell_apparent_px() -> Vector2:
	if table_screen == null:
		return Vector2.ZERO
	var origin := table_screen.world_to_pixel(Vector3.ZERO)
	var wide := absf(table_screen.world_to_pixel(
		Vector3(0.0, 0.0, DataCellView.GRIP_DEPTH)).x - origin.x)
	var deep := absf(table_screen.world_to_pixel(
		Vector3(DataCellView.WIDTH, 0.0, 0.0)).y - origin.y)
	return Vector2(wide, deep)

## Fußabdruck einer LIEGENDEN Datenzelle in Display-Pixeln: die große Kartenfläche
## nach oben. QUER liegt ihre LANGSEITE waagerecht im Bild, ihre Breite nach vorn.
## Danach sind die Stellplätze der LÄDEN geschnitten - dort liegt die Ware.
func _data_cell_lying_px() -> Vector2:
	if table_screen == null:
		return Vector2.ZERO
	var origin := table_screen.world_to_pixel(Vector3.ZERO)
	var wide := absf(table_screen.world_to_pixel(
		Vector3(0.0, 0.0, DataCellView.HEIGHT)).x - origin.x)
	var deep := absf(table_screen.world_to_pixel(
		Vector3(DataCellView.WIDTH, 0.0, 0.0)).y - origin.y)
	return Vector2(wide, deep)

## Der Bühnen-Würfel unter dem Bildschirmpunkt (null = keiner). Bewusst NICHT in
## _floating_stages: der Projektor ist Anzeige, kein Griff - ein Klick auf ihn
## bleibt folgenlos.
func _bench_stage_under(screen_pos: Vector2) -> FloatingDie:
	var camera := get_viewport().get_camera_3d()
	if camera == null or bench_stage == null or not is_instance_valid(bench_stage) \
			or not bench_stage.visible:
		return null
	return bench_stage if bench_stage.under(camera, screen_pos) else null

## Paket im Laden gekauft: KAUFEN HEISST ÜBERGEBEN. Der Körper hebt sich und
## sinkt ab, ein Komet fährt die Werkstatt-Ader entlang, und auf dem Magazin-Platz
## steigt die Kassette. Gebucht hat der Laden längst - hier fliegt nur noch die
## Ware.
func _on_pack_purchased(from_px: Vector2, uid: int) -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop) or run == null:
		return
	var pack := run.pack_by_uid(uid)
	if pack == null:
		return
	var launched := run
	workshop.expect_pack_delivery(uid)
	var tint: Color = PackDrawerView.COLORS.get(Pack.shelf_of(pack), Color.WHITE)
	var depart := _vitrine_depart_px if _vitrine_depart_px.x >= 0.0 else from_px
	_vitrine_depart_px = Vector2(-1, -1)
	# Erst ist die Ware unten, dann fliegt sie: der Komet startet nicht, bevor das
	# Stück abgesunken ist.
	await get_tree().create_timer(VitrineView.take_out_time()).timeout
	if run != launched or table_screen == null or not is_instance_valid(workshop):
		return
	var travel := table_screen.pack_delivery_comet(depart, tint,
		_pack_arrival_px(workshop, uid))
	if travel > 0.0:
		await get_tree().create_timer(travel).timeout
	if run != launched:
		return  # der Laufwechsel hat die Lieferung mitgenommen
	_land_pack_in_magazine(workshop, uid, tint)

## Das Kleingedruckte hat den Kaufpreis zurückgegeben: er fährt vom Kaufknopf in
## die Truhe. Rein visuell - gebucht hat purchase_pack, sonst zahlte eine
## verpasste Ankunft den Spieler nie aus.
func _on_pack_refunded(from_px: Vector2, amount: int) -> void:
	if table_screen == null or amount <= 0:
		return
	var launched := run
	# Farbe wie bei jedem Geld-Kometen: die GRÖSSTE Stückelung des Betrags -
	# denomination_color(6) gäbe es als Chip nicht und liefe weiß.
	var packets := ChipStackView.split_gain(amount)
	var chip_color := ChipStackView.denomination_color(packets[0] if not packets.is_empty() else 1)
	var travel := table_screen.shop_refund_comet(from_px, _money_trail_color(chip_color))
	if travel <= 0.0:
		return
	await get_tree().create_timer(travel).timeout
	if run != launched or table_screen == null or table_screen.treasure_window == null:
		return
	table_screen.treasure_window.glint()
	table_screen.treasure_window.flash_receive_slot(chip_color)

## Volles Magazin: eine Prämie ist zu Geld zerfallen, statt still zu verschwinden.
## Gebucht hat GameRun beim Gewähren (book first, fly afterwards) - hier fährt nur
## das Geld in die Truhe, in derselben Chip-Grammatik wie jede andere Gutschrift.
## round_end nimmt die lange Rundenende-Bahn (Charm-Pad -> Truhe), sonst die kurze
## Hub-Bahn. Liefert die Flugzeit.
func _fly_pack_fizzle(from_px: Vector2, amount: int, round_end := false) -> float:
	if table_screen == null or amount <= 0:
		return 0.0
	var launched := run
	var packets := ChipStackView.split_gain(amount)
	var chip_color := ChipStackView.denomination_color(packets[0] if not packets.is_empty() else 1)
	var trail := _money_trail_color(chip_color)
	var travel := table_screen.charm_money_comet(from_px, trail) if round_end \
		else table_screen.shop_refund_comet(from_px, trail)
	if travel <= 0.0:
		return 0.0
	table_screen.spawn_gain_number(from_px, "+%d$" % amount, TableScreen.SIDE_MONEY_COLOR)
	get_tree().create_timer(travel).timeout.connect(func() -> void:
		if run != launched or table_screen == null or table_screen.treasure_window == null:
			return
		table_screen.treasure_window.glint()
		table_screen.treasure_window.flash_receive_slot(chip_color))
	return travel

## Takt der Hub-Belohnung: Siegel ploppen gestaffelt auf, stehen kurz, dann fährt
## je Paket ein Komet zur Werkbank.
const HUB_REWARD_POP_STAGGER := 0.06
const HUB_REWARD_POP_TIME := 0.32
const HUB_REWARD_HOLD := 0.7
const HUB_REWARD_SHRINK_TIME := 0.18

## Reveal des Hub-Ausbaus: über der Hub-Mitte steht je PAKETSORTE ein Siegel (bei
## mehreren ein "×n"), vorneweg das Würfel-Siegel der Prämie; danach fährt je
## PAKET ein Komet die Werkstatt-Ader hinunter, und der Würfel fährt dieselbe Ader
## bis ins AUSGABEFACH, wo er durch den Fachboden steigt.
## Rein visuell - Pakete wie Würfel sind längst gebucht.
## fizzled: so viele Pakete fanden im vollen Magazin keinen Platz mehr und sind zu
## Geld zerfallen - für sie fährt ein Geld-Komet in die Truhe statt einer Kassette
## zur Werkbank (gebucht hat GameRun beim Gewähren). Ein Würfel zerfällt nie.
func _play_hub_reward_ceremony(packs: Array[Pack], fizzled := 0,
		die: DieDefinition = null) -> void:
	if table_screen == null or table_screen.hub == null or (packs.is_empty() and die == null):
		if table_screen != null:
			if fizzled > 0 and table_screen.hub != null:
				_fly_pack_fizzle(table_screen.hub.position + table_screen.hub.size * 0.5,
					fizzled * GameRun.PACK_FIZZLE_MONEY)
			table_screen.celebrate_workshop_delivery(CasinoStyle.GOLD_INTENSE)
		return
	var launched := run
	_clear_hub_reward_overlay()  # ein zweiter Ausbau überholt den ersten nie
	var groups := _group_packs_by_type(packs, die)
	# Der Würfel wird ZURÜCKGEHALTEN wie eine Kassette: er liegt schon im Fach,
	# aber sein Körper wartet auf seinen Kometen.
	if die != null and ausgabefach != null and is_instance_valid(ausgabefach):
		ausgabefach.expect_arrival(die)
	var icons := _build_hub_reward_overlay(groups)
	# Die Prämie liegt längst im Lager - also wird sie hier ZURÜCKGEHALTEN, bis ihr
	# Komet auf ihrem Platz ankommt. Angemeldet wird VOR dem ersten Bild, damit
	# der Zellen-Abgleich sie gar nicht erst aufstellt.
	var workshop: WorkshopView = table_screen.workshop_window
	var waiting: Array[int] = []
	if workshop != null and is_instance_valid(workshop):
		for pack in packs:
			workshop.expect_pack_delivery(pack.pack_uid)
			waiting.append(pack.pack_uid)
	# Ab hier gehört die Zeremonie DIESER Auslage: ein späterer Ausbau setzt das
	# Feld neu, und dann räumt der alte Ablauf nur noch sich selbst weg.
	var overlay := _hub_reward_overlay
	if icons.is_empty():
		_drop_hub_reward_overlay(overlay)
		_land_pending_packs(workshop, waiting)
		_land_pending_die(die)
		table_screen.celebrate_workshop_delivery(CasinoStyle.GOLD_INTENSE)
		return

	await get_tree().process_frame  # Pivot braucht das fertige Layout
	if run != launched or not is_instance_valid(overlay):
		_drop_hub_reward_overlay(overlay)
		_land_pending_packs(workshop, waiting)
		_land_pending_die(die)
		return
	for i in icons.size():
		var icon: Control = icons[i]
		icon.pivot_offset = icon.size * 0.5
		var pop := create_tween()
		pop.tween_interval(float(i) * HUB_REWARD_POP_STAGGER)
		var grow := pop.tween_property(icon, "scale", Vector2.ONE, HUB_REWARD_POP_TIME)
		grow.set_trans(Tween.TRANS_BACK)
		grow.set_ease(Tween.EASE_OUT)
	var pop_done := float(icons.size()) * HUB_REWARD_POP_STAGGER + HUB_REWARD_POP_TIME
	await get_tree().create_timer(pop_done + HUB_REWARD_HOLD).timeout
	if run != launched or not is_instance_valid(overlay) or table_screen == null:
		_drop_hub_reward_overlay(overlay)
		_land_pending_packs(workshop, waiting)
		_land_pending_die(die)
		return

	# Je Sorte: das Siegel schrumpft weg, seine Pakete fahren einzeln los - jedes
	# auf seinen Magazin-Platz, wo es als Kassette aufsteigt. Das
	# Würfel-Siegel schickt stattdessen EINEN Kometen ins Ausgabefach.
	var travel := 0.0
	for i in icons.size():
		var icon: Control = icons[i]
		var tint: Color = PackIconRenderer.COLORS.get(String(groups[i]["type"]), CasinoStyle.GOLD_INTENSE)
		var from_px := _hub_reward_icon_center(overlay, icon)
		var shrink := create_tween()
		var fade := shrink.tween_property(icon, "scale", Vector2.ZERO, HUB_REWARD_SHRINK_TIME)
		fade.set_trans(Tween.TRANS_BACK)
		fade.set_ease(Tween.EASE_IN)
		if bool(groups[i].get("die", false)):
			travel = maxf(travel, _fly_reward_die_to_fach(from_px, die))
			die = null  # gefahren ist gefahren - der Nachlauf holt ihn nicht noch einmal
			continue
		var uids: Array = groups[i].get("uids", [])
		for k in int(groups[i]["count"]):
			var uid: int = int(uids[k]) if k < uids.size() else 0
			travel = maxf(travel, _fly_hub_reward_pack(workshop, uid, from_px, tint))
			waiting.erase(uid)
			if k + 1 < int(groups[i]["count"]):
				await get_tree().create_timer(STAMP_METEOR_GAP).timeout
				if run != launched or table_screen == null or not is_instance_valid(overlay):
					_drop_hub_reward_overlay(overlay)
					_land_pending_packs(workshop, waiting)
					_land_pending_die(die)
					return
	# Was im vollen Magazin keinen Platz mehr fand, fährt als Geld in die Truhe.
	if fizzled > 0 and table_screen.hub != null:
		travel = maxf(travel, _fly_pack_fizzle(
			table_screen.hub.position + table_screen.hub.size * 0.5,
			fizzled * GameRun.PACK_FIZZLE_MONEY))
	await get_tree().create_timer(maxf(travel, 0.05)).timeout
	_drop_hub_reward_overlay(overlay)
	_land_pending_packs(workshop, waiting)  # was noch schwebt, ist jetzt da
	_land_pending_die(die)
	if run == launched and table_screen != null:
		table_screen.celebrate_workshop_delivery(CasinoStyle.GOLD_INTENSE)

## Der Prämien-Würfel: Siegel -> Hub-Ader bis zum Magazin -> Meteor-Bogen in die
## Schale, wo er durch den Fachboden steigt. Liefert die Flugzeit. Ohne Schale fährt nichts - der Würfel
## liegt trotzdem längst hinterlegt (gebucht vor dem Licht).
func _fly_reward_die_to_fach(from_px: Vector2, def: DieDefinition) -> float:
	if table_screen == null or def == null \
			or ausgabefach == null or not is_instance_valid(ausgabefach):
		return 0.0
	var rect := _fach_rect_px()
	if rect.size.x <= 0.0:
		ausgabefach.deliver(def)  # keine Schale gemessen: er steht einfach da
		return 0.0
	var launched := run
	var travel := table_screen.fach_delivery_comet(from_px, SLOT_DIE_COLOR, rect.get_center())
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		if run == launched and is_instance_valid(ausgabefach):
			ausgabefach.deliver(def))
	return travel

## Ein Abbruch mitten in der Zeremonie darf keinen Würfel unsichtbar lassen.
func _land_pending_die(def: DieDefinition) -> void:
	if def != null and ausgabefach != null and is_instance_valid(ausgabefach):
		ausgabefach.deliver(def)

## EIN Paket der Prämie: Siegel -> Magazin-Platz -> Aufstieg. Liefert die Flugzeit.
## Ohne Werkbank fährt der Komet trotzdem (Fenstermitte), nur ohne Kassette am Ende.
func _fly_hub_reward_pack(workshop: WorkshopView, uid: int, from_px: Vector2,
		tint: Color) -> float:
	if workshop == null or not is_instance_valid(workshop) or uid <= 0:
		return table_screen.pack_delivery_comet(from_px, tint, Vector2(-1, -1))
	var launched := run
	var travel := table_screen.pack_delivery_comet(from_px, tint,
		_pack_arrival_px(workshop, uid))
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		if run == launched:
			_land_pack_in_magazine(workshop, uid, tint))
	return travel

## Pakete zu {type, count, uids} je Sorte, in der Reihenfolge ihres ersten
## Auftretens. Die uids reisen mit: je Komet muss GENAU EIN Paket ankommen.
## Ein Prämien-Würfel steht als eigene Gruppe VORNE - er ist die Schlagzeile der
## Stufe, und sein Siegel fährt in eine andere Richtung als die Kassetten.
func _group_packs_by_type(packs: Array[Pack], die: DieDefinition = null) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	if die != null:
		groups.append({"type": PackIconRenderer.SEAL_DIE, "count": 1, "uids": [], "die": true})
	for pack in packs:
		var found := false
		for group in groups:
			if String(group["type"]) == pack.type:
				group["count"] = int(group["count"]) + 1
				(group["uids"] as Array).append(pack.pack_uid)
				found = true
				break
		if not found:
			groups.append({"type": pack.type, "count": 1, "uids": [pack.pack_uid]})
	return groups

## Baut die Siegel-Reihe über der Hub-Mitte; liefert die Siegel-Kacheln in
## Gruppen-Reihenfolge. Alles ignoriert die Maus - der Tisch leitet Klicks weiter.
func _build_hub_reward_overlay(groups: Array[Dictionary]) -> Array[Control]:
	var hub := table_screen.hub
	var u := maxf(hub.size.x, 200.0) / 100.0
	_hub_reward_overlay = Control.new()
	_hub_reward_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hub_reward_overlay.position = hub.position
	_hub_reward_overlay.size = hub.size
	table_screen.add_child(_hub_reward_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hub_reward_overlay.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 3.0))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)

	var side := u * 13.0
	var icons: Array[Control] = []
	for group in groups:
		var pack_type := String(group["type"])
		var tint: Color = PackIconRenderer.COLORS.get(pack_type, CasinoStyle.GOLD_INTENSE)
		var tile := Control.new()
		tile.custom_minimum_size = Vector2(side, side)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.scale = Vector2.ZERO  # unsichtbar bis zum Pop (kein Aufblitzen)

		var disc := _reward_glow_disc(tint)
		disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		disc.offset_left = -side * 0.175
		disc.offset_top = -side * 0.175
		disc.offset_right = side * 0.175
		disc.offset_bottom = side * 0.175
		tile.add_child(disc)

		var seal := PackIconRenderer.for_type(pack_type)
		seal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.add_child(seal)

		if int(group["count"]) > 1:
			var badge := Label.new()
			badge.text = "×%d" % int(group["count"])
			badge.add_theme_font_size_override("font_size", maxi(10, int(u * 4.0)))
			badge.add_theme_color_override("font_color", CasinoStyle.GOLD_INTENSE)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(badge)
		row.add_child(tile)
		icons.append(tile)
	return icons

## Weiche Farbscheibe hinter einem Siegel (Vorbild: ShopController._glow_disc).
func _reward_glow_disc(tint: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(tint.r, tint.g, tint.b, 0.38), Color(tint.r, tint.g, tint.b, 0.14),
		Color(tint.r, tint.g, tint.b, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 96
	texture.height = 96
	var disc := TextureRect.new()
	disc.texture = texture
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return disc

## Mitte einer Siegel-Kachel in Display-Pixeln (Start des Kometen). Die Kachel
## sitzt in verschachtelten Containern, also über die Viewport-Koordinaten.
## Untypisiert aus demselben Grund wie _drop_hub_reward_overlay: die Auslage kann
## zwischen zwei Kometen freigegeben worden sein.
func _hub_reward_icon_center(overlay, icon) -> Vector2:
	if not is_instance_valid(overlay) or not is_instance_valid(icon):
		return table_screen.hub.position + table_screen.hub.size * 0.5
	return overlay.position + icon.global_position - overlay.global_position + icon.size * 0.5

## Räumt NUR die übergebene Auslage weg - eine inzwischen aufgebaute neue bleibt.
## Das Argument ist bewusst untypisiert: ein zweiter Ausbau gibt die alte Auslage
## frei, und ein freigegebenes Objekt scheitert schon an der Typprüfung des
## Parameters - is_instance_valid im Rumpf käme nie zum Zug.
func _drop_hub_reward_overlay(overlay) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	if _hub_reward_overlay == overlay:
		_hub_reward_overlay = null

func _clear_hub_reward_overlay() -> void:
	_drop_hub_reward_overlay(_hub_reward_overlay)

## Räumt einen schwebenden Würfel ab und löst alles, was noch auf ihn zeigt. War
## er herangeholt, fährt die Kamera mit zurück - sie stünde sonst vor nichts.
func _free_stage(stage: FloatingDie) -> void:
	if stage == null or not is_instance_valid(stage):
		return
	if grabbed_stage == stage:
		grabbed_stage = null
	if focused_stage == stage:
		focused_stage = null  # der Sterbende bekommt keine Ruhelage mehr
		_leave_die_focus()
	stage.queue_free()

## Klick auf einen Warteschlangen-Würfel: startet einen POTENZIELLEN
## Umsortier-Drag; ob es ein Drag oder nur ein folgenloser Klick wird, entscheidet
## REORDER_DRAG_THRESHOLD beim Loslassen. Die Warteschlange gehört der Grube -
## ihr Dossier zeigt das Netzfeld dort, nicht die Werkbank.
func _try_start_queue_reorder(screen_pos: Vector2) -> bool:
	var result := _ray_pick(screen_pos, DiceTrayView.SLOT_PICK_LAYER)
	if result.is_empty():
		return false
	var index: int = queue_tray_view.find_slot_index(result.collider)
	if index == -1:
		return false
	reorder_drag_index = index
	reorder_drag_start_pos = screen_pos
	reorder_is_dragging = false
	return true

## Maus-Bewegung/-Loslassen während eines Umsortier-Drags: Rechtsklick bricht
## ab; Bewegung über den Schwellwert hebt den Würfel an; Loslassen ohne Bewegung
## lässt ihn liegen.
func _handle_reorder_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_reorder_drag()
		return

	if event is InputEventMouseMotion:
		if not reorder_is_dragging and event.position.distance_to(reorder_drag_start_pos) > REORDER_DRAG_THRESHOLD:
			reorder_is_dragging = true
			_begin_reorder_drag()
		if reorder_is_dragging:
			_update_reorder_drag(event.position)
		return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if reorder_is_dragging:
			_finish_reorder_drag(event.position)
		reorder_drag_index = -1
		reorder_is_dragging = false

## Umlegen im Pool-Tray: Drücken merkt sich den Würfel, Loslassen über einem
## anderen SETZT ihn dort ein (die anderen rücken auf). Nur im Werkbank-Fenster
## (vor der Unterschrift bzw. im Laden) - danach ist der Vorrat für die Runde
## gestellt. Die Ablage bleibt außen vor: _return_dice_to_pool_tray leert sie zum
## Ladenbeginn, in der Werkbank-Zeit liegt dort also ohnehin nichts.
## Erst der Weg entscheidet: gezogen wird umgelegt, bloß getippt geht das Dossier
## des Würfels auf.
func _try_start_pool_tray_drag(screen_pos: Vector2) -> bool:
	# Und nur, solange das Tray überhaupt STEHT - versenkt gibt es nichts zu greifen.
	if run == null or _dice_editing_locked() or not _pool_standing:
		return false
	# Nur dort, wo das Tray die lokale Bühne ist (und in der Freikamera): aus der
	# ruhenden Übersicht muss der Druck zu den Zoom-Zonen durchfallen, sonst frisst
	# die Geste den Klick.
	if not _felt_pick_live(CameraRig.Mode.WORKSHOP) and not _felt_pick_live(CameraRig.Mode.POOL):
		return false
	var index := _pool_tray_slot_at(screen_pos)
	if index < 0:
		return false
	tray_drag_index = index
	tray_drag_start_pos = screen_pos
	tray_is_dragging = false
	camera_rig.set_tilt_locked(true)
	return true

func _handle_tray_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		if tray_is_dragging:
			_animate_tray_snapback()
		_end_tray_drag()
		return
	if event is InputEventMouseMotion:
		# Erst der Weg macht die Geste - der Würfel verlässt seinen Platz erst
		# ab dem Schwellwert, damit ein bloßer Klick nichts anfasst.
		if not tray_is_dragging \
				and event.position.distance_to(tray_drag_start_pos) > REORDER_DRAG_THRESHOLD:
			tray_is_dragging = true
			_begin_tray_drag()
		if tray_is_dragging:
			_update_tray_drag(event.position)
		return
	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if tray_is_dragging:
			_finish_tray_drag(event.position)
			return
		# Nur getippt: der Tipp wählt den Zielwürfel der Serie, er fährt per
		# Bühnen-Fahrt auf das Podest der Werkbank.
		var tapped: DieDefinition = pool_tray_view.slot_defs[tray_drag_index]
		_end_tray_drag()
		# Seit der BÜHNEN-STRASSE gibt es EIN Podest: der Tipp wählt IMMER den
		# Zielwürfel der Serie, an der Pool- wie an der Werkstatt-Station.
		_choose_workshop_target(tapped)

## Tray-Platz unter screen_pos - über DIESELBE Maske wie Klick und Hover.
func _pool_tray_slot_at(screen_pos: Vector2) -> int:
	var result := _ray_pick(screen_pos, DiceTrayView.SLOT_PICK_LAYER)
	if result.is_empty():
		return -1
	var index: int = pool_tray_view.find_slot_index(result.collider)
	if index < 0 or index >= pool_tray_view.slot_defs.size():
		return -1
	return index if pool_tray_view.slot_defs[index] != null else -1

func _end_tray_drag() -> void:
	tray_drag_index = -1
	tray_is_dragging = false
	camera_rig.release_tilt_immediately()

## Der gegriffene Würfel verlässt seinen Platz: der Slot wird leer, ein freier
## Ghost folgt ab jetzt der Maus - dieselbe Geste wie in der Warteschlange.
func _begin_tray_drag() -> void:
	var def: DieDefinition = pool_tray_view.slot_defs[tray_drag_index]
	pool_tray_view.set_slot_visible(tray_drag_index, false)
	tray_drag_ghost = _spawn_deck_ghost(def)
	tray_drag_ghost.global_position = pool_tray_view.slot_global_position(tray_drag_index) \
		+ Vector3.UP * REORDER_LIFT_HEIGHT

func _update_tray_drag(screen_pos: Vector2) -> void:
	if tray_drag_ghost == null:
		return
	var hit: Variant = _mouse_on_plane(screen_pos,
		pool_tray_view.global_position.y + DiceTrayView.FLOAT_HEIGHT + REORDER_LIFT_HEIGHT)
	if hit != null:
		tray_drag_ghost.global_position = hit

## Loslassen: über einem anderen belegten Platz rückt die Reihe sichtbar auf,
## sonst gleitet der Ghost auf seinen alten Platz zurück.
func _finish_tray_drag(screen_pos: Vector2) -> void:
	var from_slot := tray_drag_index
	var to_slot := _pool_tray_slot_at(screen_pos)
	var from_pool := -1
	var to_pool := -1
	if to_slot >= 0 and to_slot != from_slot:
		from_pool = run.owned_pool.find(pool_tray_view.slot_defs[from_slot])
		to_pool = run.owned_pool.find(pool_tray_view.slot_defs[to_slot])
	if from_pool >= 0 and to_pool >= 0:
		_animate_tray_reorder(from_slot, to_slot, from_pool, to_pool)
	else:
		_animate_tray_snapback()
	_end_tray_drag()

## Kein gültiges Ziel: der Ghost gleitet sichtbar auf seinen Platz zurück.
func _animate_tray_snapback() -> void:
	var ghost := tray_drag_ghost
	tray_drag_ghost = null
	if ghost == null:
		_refresh_dice_trays()
		return
	var home := pool_tray_view.slot_global_position(tray_drag_index)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ghost, "global_position", home, DECK_SHIFT_DURATION)
	tween.tween_callback(func() -> void:
		ghost.queue_free()
		_refresh_dice_trays())

## Umlegen im Pool-Tray mit der Aufrück-Animation der Warteschlange: jeder
## betroffene Platz wird zu einem Ghost, der zu seinem neuen Platz gleitet - der
## gezogene bringt seinen eigenen schon mit. Die Ghosts stehen VOR der Buchung,
## denn ihr Vorhandensein ist es, was den pool_changed-Refresh so lange anhält.
func _animate_tray_reorder(from_slot: int, to_slot: int, from_pool: int, to_pool: int) -> void:
	_cancel_deck_shift()
	var lo: int = mini(from_slot, to_slot)
	var hi: int = maxi(from_slot, to_slot)
	var targets: Array[Vector3] = []
	for index in range(lo, hi + 1):
		var ghost: Node3D
		if index == from_slot:
			ghost = tray_drag_ghost
			tray_drag_ghost = null
		else:
			# Eine Lücke hat keinen Körper, der aufrücken könnte - ihr Platz wandert
			# trotzdem mit, das zieht der Neuaufbau danach nach.
			if pool_tray_view.slot_defs[index] == null:
				continue
			ghost = _spawn_deck_ghost(pool_tray_view.slot_defs[index])
			ghost.global_position = pool_tray_view.slot_global_position(index)
			pool_tray_view.set_slot_visible(index, false)
		deck_shift_ghosts.append(ghost)
		targets.append(pool_tray_view.slot_global_position(
			_queue_index_after_move(index, from_slot, to_slot)))
	run.reorder_pool(from_pool, to_pool)
	deck_shift_tween = create_tween()
	deck_shift_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	deck_shift_tween.set_parallel(true)
	for i in deck_shift_ghosts.size():
		deck_shift_tween.tween_property(deck_shift_ghosts[i], "global_position", targets[i], DECK_SHIFT_DURATION)
	deck_shift_tween.chain().tween_callback(_finish_deck_shift)

## Bewegung/Loslassen in der Grube: unter dem Schwellwert bleibt es ein
## Auswahl-Klick, darüber wird die Reihe umgelegt. Rechtsklick bricht ab.
func _handle_pit_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_end_pit_drag()
		return
	if event is InputEventMouseMotion:
		if not pit_is_dragging \
				and event.position.distance_to(pit_drag_start_pos) > REORDER_DRAG_THRESHOLD:
			pit_is_dragging = true
		if pit_is_dragging:
			_drag_pit_die_to(event.position)
		return
	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if not pit_is_dragging:
			# Nur getippt: der alte Auswahl-Klick.
			dice.set_selected(pit_drag_index, not dice.selected[pit_drag_index])
			_line_up_settled_dice()  # Reihe gleitet in ihre neue Ordnung
			_refresh_ui()  # Kombination/Basis folgen der Auswahl sofort
			_update_charm_badges()  # Runde-Sache-Summe folgt der Auswahl
		_end_pit_drag()

## Schiebt den gezogenen Würfel an die Stelle unter dem Zeiger. EINFÜGEN, nicht
## Tauschen: die Reihe rückt auf, damit sich eine Hand umlegen lässt, ohne dass
## zwei Würfel die Plätze wechseln.
func _drag_pit_die_to(screen_pos: Vector2) -> void:
	var target := _pit_row_slot_at(screen_pos)
	var from := player_order.find(pit_drag_index)
	if target < 0 or from < 0 or target == from:
		return
	player_order.remove_at(from)
	player_order.insert(clampi(target, 0, player_order.size()), pit_drag_index)
	_line_up_settled_dice()  # die Reihe rendert die neue Ansage
	_refresh_ui()  # die Vorschau zählt ab jetzt in der neuen Reihenfolge

## Platz in der Reihe unter screen_pos: die Reihe läuft entlang Welt-Z, also
## entscheidet der projizierte Abstand zur Reihenmitte.
func _pit_row_slot_at(screen_pos: Vector2) -> int:
	if player_order.is_empty():
		return -1
	var hit: Variant = _mouse_on_plane(screen_pos, dice.bodies[player_order[0]].global_position.y)
	if hit == null:
		return -1
	var point: Vector3 = hit
	var span := PIT_TOP_ROW_SPACING * float(player_order.size() - 1)
	var start := DicePit.PIT_CENTER.z - span * 0.5
	var raw := (point.z - start) / PIT_TOP_ROW_SPACING
	return clampi(int(round(raw)), 0, player_order.size() - 1)

func _end_pit_drag() -> void:
	pit_drag_index = -1
	pit_is_dragging = false
	camera_rig.release_tilt_immediately()
	_line_up_settled_dice()

## Versteckt den Original-Slot; ein freier Ghost-Würfel folgt ab jetzt der Maus.
func _begin_reorder_drag() -> void:
	var def: DieDefinition = queue_tray_view.slot_defs[reorder_drag_index]
	queue_tray_view.set_slot_visible(reorder_drag_index, false)
	reorder_ghost = _spawn_deck_ghost(def)
	reorder_ghost.global_position = queue_tray_view.slot_global_position(reorder_drag_index) + Vector3.UP * REORDER_LIFT_HEIGHT

func _update_reorder_drag(screen_pos: Vector2) -> void:
	if reorder_ghost == null:
		return
	var hit: Variant = _mouse_on_plane(screen_pos, queue_tray_view.global_position.y + DiceTrayView.FLOAT_HEIGHT + REORDER_LIFT_HEIGHT)
	if hit != null:
		reorder_ghost.global_position = hit

## Loslassen: bei gültigem Zielslot umsortieren (betroffene Würfel gleiten),
## sonst zurück zum ursprünglichen Slot gleiten.
func _finish_reorder_drag(screen_pos: Vector2) -> void:
	var target_index := _nearest_queue_slot(screen_pos)
	if target_index != -1 and target_index != reorder_drag_index:
		_animate_reorder_move(reorder_drag_index, target_index)
	else:
		_animate_reorder_snapback()

func _cancel_reorder_drag() -> void:
	_animate_reorder_snapback()
	reorder_drag_index = -1
	reorder_is_dragging = false

## Bildschirmnächster belegter Warteschlangen-Slot (Projektion statt Raycast -
## der gezogene Würfel hat keine Kollision mehr); -1 außerhalb des Radius.
func _nearest_queue_slot(screen_pos: Vector2) -> int:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return -1
	var best_index := -1
	var best_dist := REORDER_DROP_RADIUS
	for i in queue_window_size:
		var slot_screen := camera.unproject_position(queue_tray_view.slot_global_position(i))
		var dist := slot_screen.distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best_index = i
	return best_index

## Kein gültiges Ziel: der Ghost gleitet sichtbar zu seinem Platz zurück.
func _animate_reorder_snapback() -> void:
	if reorder_ghost == null:
		_refresh_deck_trays()
		return
	var ghost := reorder_ghost
	reorder_ghost = null
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ghost, "global_position", queue_tray_view.slot_global_position(reorder_drag_index), DECK_SHIFT_DURATION)
	tween.tween_callback(func() -> void:
		ghost.queue_free()
		_refresh_deck_trays()
	)

## Neuer Index eines alten Slots nach dem Verschieben from -> to (Standard
## "Element verschieben"-Semantik wie remove_at + insert).
func _queue_index_after_move(old_index: int, from_index: int, to_index: int) -> int:
	if old_index == from_index:
		return to_index
	if from_index < to_index:
		if old_index > from_index and old_index <= to_index:
			return old_index - 1
	else:
		if old_index >= to_index and old_index < from_index:
			return old_index + 1
	return old_index

## Sortiert einen Würfel im sichtbaren Warteschlangen-Fenster um (wirkt nur
## auf round_pool_kinds[next_draw_index ..]); alle betroffenen Würfel gleiten
## sichtbar - der gezogene ist schon sein eigener Ghost.
func _animate_reorder_move(from_index: int, to_index: int) -> void:
	_cancel_deck_shift()
	var lo: int = min(from_index, to_index)
	var hi: int = max(from_index, to_index)

	var old_defs: Array[DieDefinition] = []
	for i in range(lo, hi + 1):
		old_defs.append(round_pool_kinds[next_draw_index + i])

	var abs_from := next_draw_index + from_index
	var abs_to := next_draw_index + to_index
	var moved: DieDefinition = round_pool_kinds[abs_from]
	round_pool_kinds.remove_at(abs_from)
	round_pool_kinds.insert(abs_to, moved)

	deck_shift_tween = create_tween()
	deck_shift_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	deck_shift_tween.set_parallel(true)
	for offset in old_defs.size():
		var old_index := lo + offset
		var new_index := _queue_index_after_move(old_index, from_index, to_index)
		var target_pos := queue_tray_view.slot_global_position(new_index)
		var ghost: Node3D
		if old_index == from_index:
			ghost = reorder_ghost
			reorder_ghost = null
		else:
			queue_tray_view.set_slot_visible(old_index, false)
			ghost = _spawn_deck_ghost(old_defs[offset])
			ghost.global_position = queue_tray_view.slot_global_position(old_index)
		deck_shift_ghosts.append(ghost)
		deck_shift_tween.tween_property(ghost, "global_position", target_pos, DECK_SHIFT_DURATION)
	deck_shift_tween.chain().tween_callback(_finish_deck_shift)

## Klick auf eine Dock-Kachel: startet einen POTENZIELLEN 2D-Umsortier-Drag.
## Nur in Gruben-/Charm-Sicht und in der Freikamera (in der ruhenden Übersicht
## bleibt der Klick ein Zoom); Loslassen ohne Bewegung führt zum Charm hin.
func _try_start_charm_reorder(screen_pos: Vector2) -> bool:
	if table_screen.charm_dock == null or not _table_operable():
		return false
	if not (is_pit_focused or _felt_pick_live(CameraRig.Mode.CHARMS)):
		return false
	# Konsolen-Karte ODER das schwebende 3D-Hologramm treffen denselben Charm -
	# so recentert/zieht ein Klick auf beides (das Hologramm schwebt über der Karte).
	var index := -1
	var pixel := _screen_pixel(screen_pos)
	if pixel.x >= 0.0:
		index = table_screen.charm_dock.pad_index_at(pixel)
	if index == -1:
		index = charm_row.charm_index_at_screen_pos(camera_rig, screen_pos)
	if index == -1:
		return false
	charm_drag_index = index
	charm_drag_start_pos = screen_pos
	charm_is_dragging = false
	return true

## Maus-Bewegung/-Loslassen während eines Charm-Drags (analog zum
## Warteschlangen-Drag); Loslassen über einem anderen Platz sortiert um.
func _handle_charm_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_charm_drag()
		return

	if event is InputEventMouseMotion:
		if not charm_is_dragging and event.position.distance_to(charm_drag_start_pos) > REORDER_DRAG_THRESHOLD:
			charm_is_dragging = true
			table_screen.charm_dock.begin_drag(charm_drag_index)
		if charm_is_dragging:
			var pixel := _screen_pixel(event.position)
			if pixel.x >= 0.0:
				table_screen.charm_dock.drag_to(pixel)
		return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if charm_is_dragging:
			_finish_charm_drag()
		elif _sell_pixel_hits(event.position):
			run.sell_charm(charm_drag_index)  # charms_changed baut Reihe + Dock neu
		elif camera_rig.mode == CameraRig.Mode.CHARMS:
			# Klick ohne Ziehen in der Charm-Sicht: Zoom auf diesen Charm schwenken.
			_pan_zoom_to_charm(charm_drag_index)
		elif is_pit_focused or camera_rig.free_camera:
			# Aus der Grube oder der Freikamera heraus: EIN Flug in die Charm-Sicht,
			# mittig auf den geklickten Charm. zoom_to setzt den Modus (die
			# Weiterleitung hängt daran), pan_to überschreibt im selben Frame nur den
			# Blickpunkt - gleiche Basis, gleicher Abstand, also kein zweiter Flug.
			camera_rig.zoom_to(CameraRig.Mode.CHARMS)
			_pan_zoom_to_charm(charm_drag_index)
		charm_drag_index = -1
		charm_is_dragging = false

## Ob die Fenster-Mausposition den Verkaufs-Chip des angeklickten Charms trifft.
func _sell_pixel_hits(screen_pos: Vector2) -> bool:
	var pixel := _screen_pixel(screen_pos)
	return pixel.x >= 0.0 and table_screen.charm_dock.sell_index_at(pixel) == charm_drag_index

## Schwenkt den Charm-Zoom mittig auf die Konsole i (deren Weltposition).
func _pan_zoom_to_charm(i: int) -> void:
	var consoles := table_screen.charm_dock.console_rects()
	if i < 0 or i >= consoles.size():
		return
	camera_rig.pan_to(table_screen.pixel_to_world(consoles[i].get_center()))

## Loslassen: auf einen anderen Platz umsortieren (die Reihenfolge ist
## spielrelevant - Totems kopieren Nachbarn), sonst Kachel zurück auf ihren Platz.
func _finish_charm_drag() -> void:
	var target_index := table_screen.charm_dock.drop_target()
	table_screen.charm_dock.end_drag()
	if target_index != -1 and target_index != charm_drag_index:
		run.move_charm(charm_drag_index, target_index)  # charms_changed baut Reihe + Dock neu

func _cancel_charm_drag() -> void:
	if charm_is_dragging:
		table_screen.charm_dock.end_drag()
	charm_drag_index = -1
	charm_is_dragging = false

## Display-Pixel unter der Fenster-Mausposition (Kamerastrahl auf die Screen-
## Ebene), oder x<0 bei Verfehlen.
func _screen_pixel(screen_pos: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector2(-1, -1)
	return table_screen.pixel_from_ray(
		camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))

## Schwarzmarkt-Fenster: die Tasche UNTER den Automaten. Rechte Kante und
## Unterkante sind gesetzt (bündig mit der Automaten-Spalte bzw. mit dem Hub),
## die Breite folgt der Höhe (SECRET_SHOP_ASPECT) - nie breiter als die Spalte.
func _secret_shop_rect(slots_rect: Rect2, hub_rect: Rect2) -> Rect2:
	var top := slots_rect.end.y + SECRET_SHOP_TOP_GAP
	var height := hub_rect.end.y - top
	var width := minf(height * SECRET_SHOP_ASPECT, slots_rect.size.x)
	return Rect2(Vector2(slots_rect.end.x - width, top), Vector2(width, height))

## Die Ladungs-Bank steht IM Chip-Raster: auf dem freien Platz unten rechts,
## zwischen Grube und Kombinationen. Das 5×5-Raster hat einen FESTEN Fußabdruck,
## also füllt es die Platzbreite exakt (span / max_length, ohne 1er-Deckel) -
## Es wird auf BEIDE Achsen eingepasst (die knappere gewinnt): der Fußabdruck ist
## auf das Platz-Verhältnis getrimmt, also füllen beide zugleich fast ganz - und
## kein Rundungsdrift kann die Bank je in die Nachbarzelle schieben. Bewusst auf
## blankem Filz, also NICHT spiegelnd (dort ist kein Glas).
func _setup_capacitor_bank(slot: Rect2) -> void:
	capacitor_bank = CapacitorBankView.new()
	capacitor_bank.name = "CapacitorBank"
	# Nach UNTEN in den freien Filz strecken (Oberkante bleibt an der Chip-Reihe):
	# der flache Platz allein ließe die Bank als schmalen Streifen liegen.
	slot = Rect2(slot.position, Vector2(slot.size.x, slot.size.y * CAPACITOR_SLOT_TALL))
	var center := table_screen.pixel_to_world(slot.get_center())
	capacitor_bank.position = Vector3(center.x, 0.0, center.z)
	# pixel_to_world dreht die Achsen: Platz-BREITE (Pixel-x) -> Welt-z, Platz-
	# HÖHE (Pixel-y) -> Welt-x. Lange Rasterachse liegt also auf der Breite.
	var a := table_screen.pixel_to_world(slot.position)
	var b := table_screen.pixel_to_world(slot.end)
	var fit_long := absf(a.z - b.z) / CapacitorBankView.max_length()
	var fit_short := absf(a.x - b.x) / CapacitorBankView.max_width()
	capacitor_bank.scale = Vector3.ONE * minf(fit_long, fit_short) * CAPACITOR_SLOT_FILL
	add_child(capacitor_bank)

## Flache Klickbox auf der Kamera-Klickebene (Layer 8, wie PitClickZone).
func _add_click_zone(zone_name: String, center: Vector3, box_size: Vector3) -> StaticBody3D:
	var zone := StaticBody3D.new()
	zone.name = zone_name
	zone.collision_layer = 8
	zone.collision_mask = 0
	zone.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	zone.add_child(shape)
	add_child(zone)
	return zone

## Zoom-Ziel + Klickzone EINES Display-Fensters aus seinem Screen-Rechteck -
## einheitlich für alle Tisch-Fenster (Kombis, Wettannahme, künftige Screens):
## Klick zoomt heran, Rechtsklick zurück; im Zoom steht die Kamera still.
func _screen_zoom_zone(zone_name: String, rect: Rect2, configure_target: Callable) -> StaticBody3D:
	var center := table_screen.pixel_to_world(rect.get_center())
	configure_target.call(center)
	# Weltausdehnung aus zwei gegenüberliegenden Ecken (Abbildung achsenparallel).
	var corner_a := table_screen.pixel_to_world(rect.position)
	var corner_b := table_screen.pixel_to_world(rect.end)
	return _add_click_zone(zone_name, center,
		Vector3(absf(corner_a.x - corner_b.x), 4.0, absf(corner_a.z - corner_b.z)))

## Zoom-Ziel + Klickzone des Kombi-Clusters aus der Display-Fläche ableiten.
func _setup_combos_zoom() -> void:
	combos_click_zone = _screen_zoom_zone("CombosClickZone",
		table_screen.cluster_rect, camera_rig.configure_combos_target)

## Zoom-Ziel + Klickzone des Wertungs-Bildschirms (gleiche Mechanik wie der Kombi-Cluster).
func _setup_score_zoom() -> void:
	score_click_zone = _screen_zoom_zone("ScoreClickZone",
		table_screen.score_rect, camera_rig.configure_score_target)

## Zoom-Ziel + Klickzone der Wettannahme (gleiche Mechanik wie der Kombi-Cluster).
func _setup_side_bets_zoom() -> void:
	var window := table_screen.side_bet_window
	side_bets_click_zone = _screen_zoom_zone("SideBetsClickZone",
		Rect2(window.position, window.size), camera_rig.configure_side_bets_target)

## Zoom-Ziel + Klickzone der Charms aus dem Dock-Rect (rahmt Konsolen UND
## Hologramme; Klick auf Karten/Info-Band zoomt ebenfalls heran).
func _setup_charms_zoom() -> void:
	charms_click_zone = _screen_zoom_zone("CharmsClickZone",
		Rect2(table_screen.charm_dock.position, table_screen.charm_dock.size),
		camera_rig.configure_charms_target)

## Zoom-Ziel + Klickzone des Hubs (Anker + HUB_*_WORLD).
func _setup_hub_zoom() -> void:
	var anchor := hub_anchor.global_position
	var center := Vector3(anchor.x, 0.0, anchor.z)  # 0 = Screen-Oberfläche
	# Halbe Fenstermaße mit: der Hub-Abstand wird daraus gerechnet (hub_distance),
	# damit die Fußzeile im geneigten Blick nicht unten herausfällt.
	camera_rig.configure_hub_target(center,
		Vector2(HUB_WIDTH_WORLD * 0.5, HUB_HEIGHT_WORLD * 0.5))
	# Welt-X = Bildschirm-Höhe des Hubs, Welt-Z = seine Breite.
	hub_click_zone = _add_click_zone("HubClickZone", center,
		Vector3(HUB_HEIGHT_WORLD, 4.0, HUB_WIDTH_WORLD))

## Reicht ein Mausereignis an die Display-Controls weiter (true = verbraucht):
## Kamerastrahl analytisch mit der Tischebene schneiden, Treffer in Display-
## Pixel übersetzen und als geklontes Ereignis per push_input in den
## SubViewport drücken. Rechtsklicks werden nie weitergereicht (Zoom-out).
func _forward_screen_mouse(event: InputEventMouse) -> bool:
	if camera_rig.is_animating or table_screen == null:
		return false
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var pixel := table_screen.pixel_from_ray(
		camera.project_ray_origin(event.position),
		camera.project_ray_normal(event.position))
	# Die Bucht schlichtet VOR der normalen Weiterleitung: unter dem Loch liegt
	# keine Seite mehr, die den Klick nehmen könnte. Die Schale der Bank ebenso -
	# sie steht auf blankem Filz neben dem Fenster.
	if _forward_vitrine_mouse(event, pixel):
		return true
	if _forward_fach_mouse(event, pixel):
		return true
	# Der RASTER-UMSCHALTER steht auf blankem Filz neben der Grube und legt um,
	# auch während das Raster liegt - er kommt darum VOR dessen Modalität.
	if _forward_raster_switch_mouse(event, pixel):
		return true
	# Die LADESÄULE ist ein KÖRPER auf blankem Filz neben dem Streifen - ihr Griff
	# wird per Strahl gepickt, nicht als Display-Pixel.
	if _forward_charging_column_mouse(event):
		return true
	# ... und der HEBEL des Paternosters daneben, auf derselben Pick-Ebene.
	if _forward_page_lever_mouse(event):
		return true
	# Die GLAS-ANSICHT wohnt in ihrem EIGENEN Viewport: sie bekommt den Zeiger
	# umgerechnet, nicht die Anzeige darunter. Modal - unter ihr liegt keine Fläche.
	if _deck_glass and pixel.x >= 0.0 and table_screen.push_deck_glass_input(event, pixel):
		last_screen_pixel = Vector2(-1, -1)
		return true
	if pixel.x < 0.0 or not _screen_forwards_pixel(pixel, event is InputEventMouseButton):
		last_screen_pixel = Vector2(-1, -1)  # Hover-Verlauf neu ansetzen
		return false
	var forwarded := event.duplicate() as InputEventMouse
	forwarded.position = pixel
	forwarded.global_position = pixel
	if forwarded is InputEventMouseMotion:
		# relative aus dem letzten weitergereichten Pixel ableiten (das
		# Original ist in Fenster-Pixeln, nicht in Display-Pixeln).
		forwarded.relative = (pixel - last_screen_pixel) if last_screen_pixel.x >= 0.0 else Vector2.ZERO
	last_screen_pixel = pixel
	table_screen.push_input(forwarded)
	return true

## Reicht das Mausrad an das offene Lexikon weiter (true = verbraucht): nur in
## der Hub-Sicht und nur über der Hub-Fläche - dort scrollt es den Text statt
## die Kamera. Der Freikamera-Einstieg per Rad ist am Hub solange geopfert;
## überall sonst (und bei zugeklapptem Lexikon) bleibt das Rad Kamera.
func _forward_lexikon_wheel(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return false
	if button.button_index != MOUSE_BUTTON_WHEEL_UP \
			and button.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return false
	if camera_rig.mode != CameraRig.Mode.HUB or camera_rig.is_animating:
		return false
	if lexikon_view == null or not lexikon_view.visible or table_screen == null \
			or table_screen.hub == null:
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var pixel := table_screen.pixel_from_ray(
		camera.project_ray_origin(button.position),
		camera.project_ray_normal(button.position))
	if pixel.x < 0.0 or not table_screen.hub.get_rect().has_point(pixel):
		return false
	var forwarded := button.duplicate() as InputEventMouseButton
	forwarded.position = pixel
	forwarded.global_position = pixel
	table_screen.push_input(forwarded)
	return true

## Ob ein Display-Pixel an die Bildschirm-UI geht. SICHTBAR HEISST BEDIENBAR: nicht
## die Kamerastation entscheidet, sondern der Zustand von Fenster und Seite - jedes
## sichtbare Fenster nimmt an, wo es wirklich zu sehen ist, auch aus der Freikamera.
## Die Feinregel steht EINMAL in TableScreen.window_takes_pixel; hier steht nur, WER
## gefragt wird und in welcher Reihenfolge.
func _screen_forwards_pixel(pixel: Vector2, is_click: bool) -> bool:
	if table_screen == null:
		return false
	var hub: HubView = table_screen.hub
	# Das Titel-HUD ist MODAL: es liegt über dem ganzen Tisch, dahinter nimmt
	# nichts mehr etwas an.
	if camera_rig.mode == CameraRig.Mode.TITLE:
		return hub != null and hub.get_rect().has_point(pixel)
	# Die INSPEKTION ist ebenfalls modal: im Bild steht nur noch der Würfel, und was
	# zufällig hinter ihm liegt, ist kein Klickziel.
	if camera_rig.die_focus:
		return false
	var flying := camera_rig.is_animating
	# Die GLAS-ANSICHT wird VOR dieser Kette bedient (_forward_screen_mouse reicht sie
	# in ihren eigenen Viewport) - hier taucht sie darum nicht mehr auf.
	# Das Gruben-Mobiliar meldet sich selbst: es steht nur, solange die Grube im
	# Blick ist, und hat keine leere Fläche, die etwas schlucken dürfte.
	if not flying and _pit_forwards_pixel(pixel):
		return true
	# GEWETTET wird nur an der EIGENEN Station (Spieler-Entscheid 2026-08-26):
	# aus der Übersicht fällt der Klick durch und wird zum Zoom auf den Tresen -
	# erst ranfahren, dann setzen. Bewegungen laufen weiter über die ganze
	# Fläche, damit der Knopf-Hover sauber bleibt.
	var bets_focused := camera_rig.mode == CameraRig.Mode.SIDE_BETS
	if TableScreen.window_takes_pixel(table_screen.side_bet_window,
			_window_rect(table_screen.side_bet_window), pixel, is_click,
			bets_focused, flying):
		return not is_click or bets_focused
	if TableScreen.window_takes_pixel(table_screen.slot_bank_window,
			_window_rect(table_screen.slot_bank_window), pixel, is_click,
			camera_rig.mode == CameraRig.Mode.SLOTS, flying):
		return true
	if TableScreen.window_takes_pixel(table_screen.secret_shop_window,
			_window_rect(table_screen.secret_shop_window), pixel, is_click,
			camera_rig.mode == CameraRig.Mode.SECRET_SHOP, flying):
		return true
	# Die Werkbank mißt sich samt SCHÜRZE - Konsole und Regal-Buchten hängen unter
	# der Fensterkante und müssen Klicks bekommen.
	var workshop: WorkshopView = table_screen.workshop_window
	if workshop != null and is_instance_valid(workshop) \
			and TableScreen.window_takes_pixel(workshop, workshop.bench_rect(), pixel,
				is_click, camera_rig.mode == CameraRig.Mode.WORKSHOP, flying):
		return true
	# Der Laden RÄUMT AB: seine Seite steht noch, ist aber tot - kein Kauf aus einem
	# schließenden Laden. Sie deckt den ganzen Hub, also schweigt der ganze Hub.
	if charm_shop != null and is_instance_valid(charm_shop) and charm_shop.leaving():
		return false
	return TableScreen.window_takes_pixel(hub, _window_rect(hub), pixel, is_click,
		camera_rig.mode == CameraRig.Mode.HUB, flying)

## Rechteck eines Display-Fensters in Display-Pixeln (leer = kein Fenster).
func _window_rect(window: Control) -> Rect2:
	if window == null or not is_instance_valid(window):
		return Rect2()
	return Rect2(window.position, window.size)

## Die Bedienteile der Grube: liegt die Vertrags-Auslage auf dem Boden, gehören
## die Klicks ihr, der Rückblick nimmt Liste wie Schritt-Leiste, sonst sind es die
## Aktions-Knöpfe. Alle drei stehen nur, solange die Grube Mobiliar zeigt.
func _pit_forwards_pixel(pixel: Vector2) -> bool:
	if route_choice != null and route_choice.visible \
			and Rect2(route_choice.position, route_choice.size).has_point(pixel):
		return true
	if log_view != null and log_view.hit(pixel):
		return true
	return table_screen.pit_actions_hit(pixel)

## Doppelklick auf FREIE Werkbank-Fläche öffnet die zweite Zoomstufe (näher,
## Trays aus dem Bild, Kamera steht still). Auf einem Knopf passiert nichts -
## der Doppelklick ist dort schon der zweite Klick auf die Karte.
func _try_workshop_close_zoom(event: InputEvent) -> bool:
	if camera_rig.mode != CameraRig.Mode.WORKSHOP or camera_rig.workshop_close \
			or camera_rig.die_focus:
		return false
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or not button.double_click \
			or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not _workshop_close_zoom_allowed(button.position):
		return false
	camera_rig.zoom_workshop_close()
	return true

## Ob an diesem Bildschirmpunkt die Werkbank-Nahsicht aufgehen darf: freie
## Bankfläche, kein aktiver Knopf darunter.
func _workshop_close_zoom_allowed(screen_pos: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null or table_screen == null:
		return false
	var pixel := table_screen.pixel_from_ray(
		camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))
	if pixel.x < 0.0 or not workshop_close_rect.has_point(pixel):
		return false
	return not _workshop_interactive_at(pixel)

## Spiegelung aus, wo gespiegelte Würfel ins Bild geistern: im Titel-HUD und in
## der Werkbank-Nahsicht (die Trays liegen dort knapp außerhalb des Rahmens und
## spiegelten sich quer über das Werkstattfenster).
func _sync_screen_reflection() -> void:
	if screen_reflection == null:
		return
	screen_reflection.set_enabled(camera_rig.mode != CameraRig.Mode.TITLE
		and not camera_rig.workshop_close)

## Ob unter dem Display-Pixel ein aktiver Knopf der Werkbank liegt - Station,
## Regal-Leiste und Hand-Leiste liegen seit dem Umbau alle in ihrem Fenster.
func _workshop_interactive_at(pixel: Vector2) -> bool:
	if table_screen.workshop_window != null and table_screen.workshop_window.visible \
			and TableScreen.interactive_under(table_screen.workshop_window, pixel):
		return true
	return false

## Klick auf eine Zoom-Zone (Layer 8): Kamera fährt heran. Der Grubenklick zoomt
## nur noch (kein Wurf mehr - dafür Energie-Hülle oder der "Würfeln"-Knopf).
func _try_zoom_click(screen_pos: Vector2) -> void:
	_zoom_to_mode(_zone_mode_at(screen_pos))

## Zoom-Ziel unter einem Bildschirmpunkt (Klickzonen-Layer 8); -1 = keines.
## Ein noch gesperrtes Fenster liefert -1, seine Zone steht aber schon da.
## EINE Quelle für Klick und Mausrad - sonst driften die beiden Wege auseinander.
func _zone_mode_at(screen_pos: Vector2) -> int:
	var result := _ray_pick(screen_pos, 8)
	if result.is_empty():
		return -1

	var collider: Object = result.collider
	var station := -1
	if collider == pit_click_zone:
		station = CameraRig.Mode.PIT
	elif collider == pool_tray_view.click_zone or collider == queue_tray_view.click_zone:
		station = CameraRig.Mode.POOL
	elif collider == combos_click_zone:
		station = CameraRig.Mode.COMBOS
	elif collider == charms_click_zone:
		station = CameraRig.Mode.CHARMS
	elif collider == hub_click_zone:
		station = CameraRig.Mode.HUB
	elif collider == side_bets_click_zone:
		station = CameraRig.Mode.SIDE_BETS
	elif collider == slots_click_zone:
		station = CameraRig.Mode.SLOTS
	elif collider == workshop_click_zone:
		station = CameraRig.Mode.WORKSHOP
	elif collider == repair_click_zone:
		station = CameraRig.Mode.REPAIR
	elif collider == score_click_zone:
		station = CameraRig.Mode.SCORE
	elif collider == chips_click_zone:
		station = CameraRig.Mode.CHIPS
	elif collider == secret_shop_click_zone:
		station = CameraRig.Mode.SECRET_SHOP
	return station if station != -1 and _station_available(station) else -1

## Ob eine Station offen steht. Die Klickzonen liegen zwar auch vergittert schon
## da (der Schwarzmarkt schaltet seine Kollision sogar ab), aber ein gesperrtes
## Fenster ist kein Ziel - EINE Wahrheit für den Fokus-Klick, gleich aus welchem
## System er kommt.
func _station_available(station: int) -> bool:
	match station:
		CameraRig.Mode.SIDE_BETS:
			return run != null and run.side_bets_unlocked()
		CameraRig.Mode.SLOTS:
			return run != null and run.slots_unlocked() > 0
		CameraRig.Mode.SECRET_SHOP:
			return run != null and run.secret_shop_unlocked
	return true

## Nimmt der Tisch Bedienung an bzw. antwortet ein Griff auf dem Filz? Die Regel
## steht in CameraRig (takes_input/felt_pick_live) - hier nur die Null-Sicherung.
func _table_operable() -> bool:
	return camera_rig != null and camera_rig.takes_input()

func _felt_pick_live(station: int) -> bool:
	return camera_rig != null and camera_rig.felt_pick_live(station)

## Fährt auf ein Zoom-Ziel aus _zone_mode_at; -1 tut nichts.
func _zoom_to_mode(target: int) -> void:
	if target == -1:
		return
	camera_rig.zoom_to(target as CameraRig.Mode)
	# Beim Wechsel auf den Automaten die Dreh-Knöpfe auf den aktuellen Geldstand
	# bringen (er kann sich seit dem letzten Aufbau geändert haben).
	if target == CameraRig.Mode.SLOTS and table_screen.slot_bank_window != null:
		table_screen.slot_bank_window.refresh_if_idle()

## Ein Rad-Schritt. Taub während einer Kamerafahrt (das ist zugleich die Sperre
## gegen nachlaufende Flicks). Die beiden senkrechten Werkbank-Stufen behalten
## ihr altes Rad - dort führt es zwischen den Stufen, nie aus der Zeremonie
## heraus. Überall sonst gehört das Rad der FREIKAMERA: es zoomt stufenlos und
## schaltet dabei aus dem Fokus in sie hinüber.
func _handle_zoom_wheel(event: InputEventMouseButton) -> void:
	# Im Rückblick ist das Rad taub: der Cursor gehört den Pfeilen, und ein
	# Radstups darf die Erinnerung nicht aus Versehen verlassen.
	if camera_rig.mode == CameraRig.Mode.TITLE or camera_rig.is_animating or log_open:
		wheel_accum = 0.0
		return

	var up := event.button_index == MOUSE_BUTTON_WHEEL_UP
	# Gekerbte Räder melden factor 0 - das ist eine volle Kerbe.
	var amount := event.factor if event.factor > 0.0 else 1.0
	var signed := amount if up else -amount
	if (signed > 0.0) != (wheel_accum > 0.0):
		wheel_accum = 0.0
	wheel_accum += signed
	if absf(wheel_accum) < WHEEL_STEP_THRESHOLD:
		return

	wheel_accum = 0.0
	# Die Inspektion ist eine senkrechte Stufe: Rad zurück geht aufs Podest.
	if camera_rig.die_focus:
		if not up:
			_leave_die_focus()
		return
	if camera_rig.workshop_close:
		if not up:
			camera_rig.zoom_workshop_wide()  # eine Stufe zurück, nicht ganz raus
		return
	if not camera_rig.free_camera:
		if not camera_rig.begin_free():
			return
		last_screen_pixel = Vector2(-1, -1)  # Hover-Verlauf neu ansetzen
	camera_rig.free_zoom(1.0 if up else -1.0)

## Ob WASD gerade greifen darf. Taub sind: jede laufende Zieh-Geste, der
## Rückblick (dort gehören die Tasten dem Cursor), das Titel-HUD, die Werkbank-
## Nahsicht und die Würfel-Inspektion - deren Rahmen ist randvoll, ein Fahren zöge
## nur die Trays herein. Spielphasen sperren nichts, so freizügig wie das Rad.
func _free_camera_allowed() -> bool:
	if camera_rig == null or log_open:
		return false
	# Der TITEL ist modal und die INSPEKTION auch; die Werkstatt-NAHSICHT war es
	# bis zum 2026-09-04 - sie ist es nicht mehr (Spieler-Entscheid: die
	# Werkstatt-Kamera soll sich bewegen wie die Übersicht).
	if camera_rig.mode == CameraRig.Mode.TITLE or camera_rig.die_focus:
		return false
	return tray_drag_index == -1 and pit_drag_index == -1 and reorder_drag_index == -1 \
		and charm_drag_index == -1 and chip_drag_value == -1 and not shell_drag_active \
		and grabbed_stage == null

## Blickfahrt je Bild: die erste Taste schaltet auf die Freikamera, danach bleibt
## sie stehen - Loslassen parkt sie, wo sie ist. Zurück in den Fokus führen nur
## Klick, Rechtsklick oder eine gerechnete Fahrt.
func _sync_free_camera(delta: float) -> void:
	if camera_rig == null:
		return
	var dir := Vector2.ZERO
	if _free_camera_allowed():
		dir = Input.get_vector("nav_left", "nav_right", "nav_down", "nav_up")
	if not camera_rig.free_camera:
		if dir == Vector2.ZERO:
			return
		if not camera_rig.begin_free():
			return
		last_screen_pixel = Vector2(-1, -1)  # Hover-Verlauf neu ansetzen
	camera_rig.free_step(dir, delta)

func _process(delta: float) -> void:
	_sync_free_camera(delta)
	_update_charm_hover()
	_update_pit_hover(delta)
	_update_workshop_hover()
	_sync_vitrine_hover()
	_update_combo_upgrade_hover()
	_update_selection_glows()
	_sync_screen_action_buttons()
	_sync_shell_hold()
	_park_pool_shaft()  # das PIT ist Möbel: es steht beim nächsten Hinsehen wieder
	_sync_fach_nets()  # und die Info-Säule zeigt den Neuzugang über ihr
	_sync_raster_switch()  # und die Taste am Grubenrand, was ihr Druck liefert
	_sync_charging_column()  # und die Ladesäule, wen sie gerade bedient
	_sync_page_lever()  # und der Hebel, welche Etage sein Druck heraufholt
	_sync_workshop_strip()  # und der Streifen wächst, wenn die Serie länger wird

## Der ZEIGER an der Werkstatt-Station: er hebt die Kassette im Magazin und den
## Würfel in der Schale, stellt das Hover-Highlight der Serie (Karte <-> Netz-Zellen)
## und schreibt die CAPTION unter dem Summen-Netz. Gefragt je Bild - der Zeiger liegt
## auf dem Tisch, ein mouse_entered erreicht das Fenster nie.
func _update_workshop_hover() -> void:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop):
		return
	# Die Bank antwortet, wo sie zu SEHEN ist - Station wie Freikamera. Fahrt und
	# Titel-HUD räumen ab: der Zeiger steht dann irgendwo, und eine überfahrene
	# Kachel bekäme ohne weitergereichte Bewegung nie ihr mouse_exited.
	if not workshop.visible or not _table_operable():
		_sync_pack_hover(0)
		_sync_fach_hover()
		workshop.sync_hover_at(Vector2(-1, -1))
		_sync_step_hover(-1)
		_write_workshop_caption(workshop, Vector2(-1, -1))
		return
	var pixel := _screen_pixel(get_viewport().get_mouse_position())
	var hover_uid := workshop.shelf_hover_uid_at(pixel)
	_sync_pack_hover(hover_uid)
	_sync_fach_hover()
	workshop.sync_hover_at(pixel)
	_sync_step_hover(workshop.slot_at(pixel))
	_write_workshop_caption(workshop, pixel)

## Der EINE Schreiber der CAPTION unter dem Summen-Netz (je Bild): eine NETZ-ZELLE
## erklärt sich selbst, sonst nennt der Zeiger den NAMEN der überfahrenen Karte -
## und liegt er nirgends, bleibt die Zeile leer. Nur der Wechsel schreibt
## (set_caption ist idempotent).
func _write_workshop_caption(workshop: WorkshopView, pixel: Vector2) -> void:
	if pixel.x < 0.0:
		workshop.set_caption(workshop.grip_blocker())
		return
	# Netz-Zelle im Fenster schlägt Zelle auf einem KÖRPER schlägt Kartenname.
	var cell_hint := workshop.net_hint_at(pixel)
	if cell_hint != "":
		workshop.set_caption(cell_hint)
		return
	var stamp := _stamp_cell_hint()
	if stamp != "":
		workshop.set_caption(stamp)
		return
	# Ohne Hover sagt die Zeile, WARUM der Griff schweigt - eine gesperrte Bremse
	# stünde sonst stumm im Knopf.
	var name_hint := workshop.hover_pack_name()
	workshop.set_caption(name_hint if name_hint != "" else workshop.grip_blocker())

## Die NETZ-ZELLE einer Kassette unter dem Zeiger, im Klartext ("" = keine).
## GEFRAGT werden die KÖRPER - sie schneiden den Zeigerstrahl selbst, das Fenster
## weiß von ihren Flächen nichts. Der SCHACHT zuerst: seine Karte steht über der
## Grube, also gewinnt sie, wo beide unter dem Zeiger lägen.
func _stamp_cell_hint() -> String:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return ""
	var screen := get_viewport().get_mouse_position()
	for cell in socket_cells:
		var shaft_hint := _cell_face_hint(cell, camera, screen)
		if shaft_hint != "":
			return shaft_hint
	for uid: int in shelf_cells:
		var pit_hint := _cell_face_hint(shelf_cells[uid], camera, screen)
		if pit_hint != "":
			return pit_hint
	return ""

## Dieselbe Frage an EINEN Körper - der EINE Ort, an dem Treffer und Klartext
## zusammenkommen (auch der Laden fragt hier).
func _cell_face_hint(cell: DataCellView, camera: Camera3D, screen: Vector2) -> String:
	# Was in einem parkenden Fach liegt, sieht man nicht - also fragt man es auch nicht.
	if cell == null or not is_instance_valid(cell) or not cell.is_visible_in_tree():
		return ""
	var face := cell.net_face_at(camera, screen)
	if face < 0:
		return ""
	return StampNet.cell_hint(StampNet.cell_at(cell.stamp_net, face))

## Die Karte der überfahrenen ETAGE fährt nach Bild-links aus dem Turm heraus, die
## vorige rutscht zurück - erst so liest ihr Netz frei von oben. Nur der WECHSEL
## schreibt.
func _sync_step_hover(index: int) -> void:
	if index == _hovered_step:
		return
	var previous := _socket_cell(_hovered_step)
	if previous != null:
		previous.set_hovered(false)
	_hovered_step = index
	var cell := _socket_cell(index)
	if cell != null:
		cell.set_hovered(true)

## Die Kassette unter dem Zeiger zieht sich ein Stück aus der Grube, die vorige
## sinkt zurück. Nur der WECHSEL - set_hovered ist idempotent, aber ein Aufruf je
## Bild an jede Zelle wäre Arbeit für nichts.
func _sync_pack_hover(uid: int) -> void:
	if uid == _hovered_pack_uid:
		return
	var previous: DataCellView = shelf_cells.get(_hovered_pack_uid)
	if previous != null and is_instance_valid(previous):
		previous.set_hovered(false)
	_hovered_pack_uid = uid
	var cell: DataCellView = shelf_cells.get(uid)
	if cell != null and is_instance_valid(cell):
		cell.set_hovered(true)

## Würfelnetz-Feld der Grube: zeigt den Würfel unter der Maus - ruhende
## Grubenwürfel (mit Gold-Rahmen auf der oben liegenden Seite) und die
## nächsten Würfel der Warteschlange (ohne Lage, die liegen ja noch nicht).
## Verlässt die Maus den Würfel, steht das Netz noch NET_LINGER_TIME - genug,
## um in das Feld zu fahren; dort hält es, und Zellen erklären ihr Material.
func _update_pit_hover(delta: float) -> void:
	if table_screen == null or log_open:
		return  # im Rückblick gehört das Netz-Feld den Gliedern der Vergangenheit
	if is_pit_focused and phase == Phase.IDLE and not camera_rig.is_animating:
		var mouse := get_viewport().get_mouse_position()
		var index := _hovered_die_index(mouse)
		if index >= 0:
			_show_pit_net(dice.slot_defs[index], dice.face_indices[index])
			return
		var queue_index := _hovered_queue_index(mouse)
		if queue_index >= 0:
			_show_pit_net(queue_tray_view.slot_defs[queue_index], -1)
			return
		if _net_die_def != null:
			var pixel := _screen_pixel(mouse)
			if table_screen.pit_info_bar.get_rect().has_point(pixel):
				# Maus im Feld: voll zurück in den Fokus (Ausblenden abbrechen),
				# Zelle unterm Cursor erklären.
				_net_linger = NET_LINGER_TIME
				_net_fade = NET_FADE_TIME
				table_screen.set_pit_net_alpha(1.0)
				table_screen.set_pit_net_hint(_net_face_hint(pixel))
				return
			table_screen.set_pit_net_hint("")
			if _net_linger > 0.0:
				_net_linger -= delta
				return
			# Nachlauf vorbei: über NET_FADE_TIME ausblenden.
			_net_fade -= delta
			if _net_fade > 0.0:
				table_screen.set_pit_net_alpha(_net_fade / NET_FADE_TIME)
				return
	_net_die_def = null
	table_screen.clear_pit_die()
	table_screen.set_pit_net_hint("")

## Zeigt def im Netz-Feld, voll deckend, und spannt Nachlauf + Ausblenden neu auf.
## Trägt der Würfel eine Seele, steht sie sofort in der Erklärzeile - dieselbe
## Zeile, die auch der Essenz-Chip des Netzes spricht (seelenlos bleibt sie leer).
func _show_pit_net(def: DieDefinition, up_face: int) -> void:
	if def != _net_die_def:
		_net_essence_hint = DieNetView.hint_for(def, DieNetView.EDGE)
	_net_die_def = def
	_net_linger = NET_LINGER_TIME
	_net_fade = NET_FADE_TIME
	table_screen.set_pit_die(def, up_face)
	table_screen.set_pit_net_alpha(1.0)
	table_screen.set_pit_net_hint(_net_essence_hint)

## Kurz-Erklärzeile zur Netz-Zelle unter pixel (siehe DieNetView.hint_for).
func _net_face_hint(pixel: Vector2) -> String:
	return DieNetView.hint_for(_net_die_def, table_screen.pit_net_face_at(pixel))

## Slot des ruhenden, sichtbaren Grubenwürfels unter screen_pos, sonst -1.
func _hovered_die_index(screen_pos: Vector2) -> int:
	var result := _ray_pick(screen_pos, 2)
	if result.is_empty():
		return -1
	var index := dice.index_of_body(result.collider)
	if index == -1 or not dice.roots[index].visible or not dice.settled[index]:
		return -1
	return index

## Slot des Warteschlangen-Würfels unter screen_pos, sonst -1 (leere Slots
## filtert find_slot_index über die Sichtbarkeit).
func _hovered_queue_index(screen_pos: Vector2) -> int:
	var result := _ray_pick(screen_pos, DiceTrayView.SLOT_PICK_LAYER)
	if result.is_empty():
		return -1
	return queue_tray_view.find_slot_index(result.collider)

## Hält die On-Screen-Buttons (Nehmen/Würfeln) jeden Frame im Takt des
## Spielzustands - unabhängig von den verstreuten Zustandswechseln.
func _sync_screen_action_buttons() -> void:
	if table_screen == null or table_screen.pit_actions_root == null:
		return
	# Die Auslage ist Gruben-Mobiliar: verlässt die Kamera die Grube, geht sie mit
	# (der nächste Grubenzoom legt sie wieder auf - _on_camera_mode_changed).
	if _route_choice_open() and not (gameplay_ui_state_visible and is_pit_focused):
		route_choice.close()
	# Der Rückblick ist ebenso Gruben-Mobiliar: die Grube zu verlassen schließt
	# ihn samt Wiederherstellung des lebenden Tisches.
	if log_open and not (gameplay_ui_state_visible and is_pit_focused):
		_close_round_log()
	if log_open:
		# Im Erinnerungs-Modus gehört der Grubenboden der Chronik; nur das
		# Netz-Feld bleibt, es zeigt die Glieder der Vergangenheit.
		table_screen.pit_actions_root.visible = false
		table_screen.pit_deal_rail.visible = false
		table_screen.pit_info_bar.visible = true
		table_screen.hide_pit_deal_hint()
		table_screen.clear_fumble_marks()
		return
	# Die Vertragswahl braucht den ganzen Grubenboden: solange sie liegt, weicht
	# das Mobiliar. Hier - nicht an den Setz-Stellen -, weil diese Funktion je
	# Frame läuft und damit auch zurücknimmt, was update_pit_score/_refresh_ui
	# nebenher wieder einschalten.
	var choosing := _route_choice_open()
	var show := gameplay_ui_state_visible and is_pit_focused and not choosing
	table_screen.pit_actions_root.visible = show
	# Das Würfelnetz-Feld steht dauerhaft neben den Knöpfen (leer ohne Hover).
	table_screen.pit_info_bar.visible = show
	# Die Deal-Marken am oberen Rand kommen und gehen mit dem Mobiliar.
	table_screen.pit_deal_rail.visible = show
	if choosing:
		table_screen.set_pit_net_hint("")
		table_screen.hide_pit_score()
	if not show:
		table_screen.hide_pit_deal_hint()
		table_screen.clear_fumble_marks()  # Nachglühen ist Gruben-Mobiliar
		return
	_sync_pit_deal_hint()
	var interactable := phase == Phase.IDLE and has_rolled_current_hand
	table_screen.take_action_button.disabled = not interactable or _hand_slots().is_empty()
	# Würfeln braucht mindestens einen ungeschützten Würfel - sind alle geschützt,
	# gibt es nichts neu zu würfeln (dann führt nur "Nehmen" weiter).
	var can_roll := phase == Phase.IDLE and _remaining_in_pool() > 0 and not _all_in_play_dice_selected()
	table_screen.roll_action_button.disabled = not can_roll
	# Bank-Knopf: erst ab der ersten gefüllten Überladungs-Stufe, zeigt die Stufenzahl.
	var stages := run.stages_cleared(hand_total) if run != null else 0
	var can_bank := phase == Phase.IDLE and stages >= 1
	table_screen.bank_action_button.visible = can_bank
	if can_bank:
		table_screen.set_bank_label("Beenden ⚡×%d" % stages)
	# Der Rückblick öffnet nur zwischen zwei Händen - dann liegt nichts, was er
	# verstellen könnte.
	table_screen.log_action_button.visible = _log_can_open()

## Nachglüh-Silhouetten des Fumbles: je liegendem Würfel sein Umriss an der
## projizierten Stelle, mit der Augenzahl, die oben lag. Die Würfel des LETZTEN
## Wurfs blinken - sie haben den Fumble ausgelöst.
func _show_fumble_marks() -> void:
	# Welcher Slot beim Fumble +1 bekam - und welcher dabei durchbrannte.
	var charged := {}
	var burned := {}
	for change in _last_fumble_charges:
		var slot := int(change.get("slot", -1))
		charged[slot] = true
		if bool(change.get("burned", false)):
			burned[slot] = true
	var marks: Array[Dictionary] = []
	for i in _visible_pit_slots():
		marks.append({
			"pixel": table_screen.world_to_pixel(dice.bodies[i].global_position),
			"value": dice.values[i],
			"fresh": last_thrown_slots.has(i),
			"charged": charged.has(i),
			"burned": burned.has(i),
		})
	table_screen.show_fumble_marks(marks, _die_pixel_side())

## Kantenlänge eines Würfels in Display-Pixeln (Weltmaß projiziert).
func _die_pixel_side() -> float:
	var origin := table_screen.world_to_pixel(Vector3.ZERO)
	var edge := table_screen.world_to_pixel(Vector3(0.0, 0.0, DiceController.DIE_HALF * 2.0))
	return absf(edge.x - origin.x)

## Hinweis-Karte der Gruben-Marken: dort erreicht die Maus die Marken nicht (der
## Zeiger liegt auf dem Tisch, nicht im SubViewport) - also je Frame das Pixel
## prüfen, statt auf mouse_entered zu warten.
func _sync_pit_deal_hint() -> void:
	var token := table_screen.pit_deal_token_at(
		_screen_pixel(get_viewport().get_mouse_position()))
	if token == null:
		table_screen.hide_pit_deal_hint()
	else:
		table_screen.show_pit_deal_hint(token)

## Nach dem Wurf: sind ALLE liegenden Würfel geschützt (ausgewählt), gibt es
## nichts mehr neu zu würfeln. Vor dem ersten Wurf einer Hand greift die Regel
## nicht (dann steht kein Würfel in der Grube).
func _all_in_play_dice_selected() -> bool:
	if not has_rolled_current_hand:
		return false
	var any_visible := false
	for i in dice.count():
		if not dice.roots[i].visible:
			continue
		any_visible = true
		if not dice.selected[i]:
			return false
	return any_visible

## Zeigt die Auswahl als goldenes Leucht-Podest unter jedem ausgewählten Würfel;
## folgt den Würfeln jeden Frame, nur in der Auswahlphase sichtbar. Mit Vollzähler
## zählt die ganze Grube: die Kombi-Würfel leuchten hell, alle übrigen liegenden
## schwach (sie werten mit, gehören aber nicht zur Kombination).
func _update_selection_glows() -> void:
	# Im Rückblick leuchten die AUFGEZEICHNETEN Auswahl-Flaggen; der Vollzähler
	# bleibt draußen, er läse die Charms der Gegenwart.
	var want := phase == Phase.IDLE and (has_rolled_current_hand or log_open)
	var die_world := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT * 2.0
	var glow_side := die_world * SCORE_GLOW_SIZE_FACTOR * table_screen.pixels_per_world()
	var full_counter := want and not log_open and run != null and run.charm_ids().has(Charm.FULL_COUNTER)
	var combo := {}
	if full_counter:
		for s in _pit_combination_slots():
			combo[s] = true
	for i in dice.count():
		# Glow-Stärke je Würfel: 1 hell, FAINT schwach, 0 aus.
		var intensity := 0.0
		if want and dice.roots[i].visible:
			if full_counter:
				# Vollzähler: Kombi-Würfel und vom Spieler ausgewählte hell,
				# der mitzählende Rest nur schwach.
				intensity = 1.0 if (combo.has(i) or dice.selected[i]) else FULL_COUNTER_GLOW_FAINT
			elif dice.selected[i]:
				intensity = 1.0
		if intensity > 0.0:
			var center := table_screen.world_to_pixel(dice.bodies[i].global_position)
			if _select_glows.has(i):
				var g: Control = _select_glows[i]
				g.position = center - g.size / 2.0
				g.modulate.a = intensity
			else:
				_select_glows[i] = table_screen.spawn_glow(center, glow_side, intensity)
		elif _select_glows.has(i):
			_select_glows[i].queue_free()
			_select_glows.erase(i)

## Hover-Info der Charms ins Dock-Band: Index erst über das 3D-Hologramm
## (Projektions-Nähe), sonst über die Dock-Karte unter der Maus - so leuchtet die
## Konsole aus jeder Sicht auf. Nicht während Kamerafahrt oder Drag.
func _update_charm_hover() -> void:
	if table_screen == null or table_screen.charm_dock == null:
		return
	# Nur Fahrt, Titel und der laufende Griff schweigen: die Konsole steht auch in
	# der Freikamera sichtbar da, und der Pick hat seinen eigenen Radius
	# (CharmRowView.PICK_RADIUS_PX) - er trifft nichts, was niemand meinte.
	if not _table_operable() or charm_is_dragging:
		return
	var mouse := get_viewport().get_mouse_position()
	var index := charm_row.charm_index_at_screen_pos(camera_rig, mouse)
	if index == -1:
		var pixel := _screen_pixel(mouse)
		if pixel.x >= 0.0:
			index = table_screen.charm_dock.pad_index_at(pixel)
	table_screen.charm_dock.set_hover(index)

## Mausdruck auf der Energie-Hülle: das Drücken WIRFT bereits (dieselben
## Vorbedingungen wie der Würfeln-Knopf, die Funktion prüft sie selbst). Bleibt
## die Taste liegen, packt _sync_shell_hold die Hülle, sobald sie zu rütteln
## beginnt - Drücken, Schütteln, Loslassen ist eine einzige Geste. Kam kein Wurf
## zustande, dreht Ziehen die Hülle nur (spin_impulse).
func _try_start_shell_drag(screen_pos: Vector2) -> bool:
	var result := _ray_pick(screen_pos, DiceShell.CLICK_LAYER)
	if result.is_empty():
		return false
	shell_drag_active = true
	shell_drag_start_pos = screen_pos
	shell_is_dragging = false
	_on_throw_button_pressed()
	shell_throw_pending = phase == Phase.SHELL_ANIMATING
	return true

## Gehaltene Taste: die Hülle des eben ausgelösten Wurfs geht in die Hand, sobald
## sie über der Grube ankommt. Je Frame geprüft - eine ruhig gehaltene Maus
## meldet keine Bewegung, über die das Packen sonst liefe.
func _sync_shell_hold() -> void:
	if not shell_drag_active or not shell_throw_pending or shell_is_dragging:
		return
	if dice_shell.state != DiceShell.State.SHAKE:
		return
	shell_is_dragging = true
	camera_rig.set_tilt_locked(true)
	dice_shell.set_grabbed(true)

func _handle_shell_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_end_shell_drag()
		return

	if event is InputEventMouseMotion:
		if not shell_is_dragging and event.position.distance_to(shell_drag_start_pos) > REORDER_DRAG_THRESHOLD:
			shell_is_dragging = true
			camera_rig.set_tilt_locked(true)  # Kamera ruhig halten, solange gedreht wird
			dice_shell.set_grabbed(true)  # hält beim Rütteln den Auskipp-Timer an
		if shell_is_dragging:
			if dice_shell.state == DiceShell.State.SHAKE:
				# Beim Rütteln schiebt der Spieler die Hülle frei über die Grube.
				var target: Variant = _shell_drag_target(event.position)
				if target != null:
					dice_shell.drag_to(target)
			else:
				dice_shell.spin_impulse(event.relative, get_viewport().get_camera_3d())
		return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_end_shell_drag()  # geworfen wurde schon beim Drücken

## Zieh-Ziel der Hülle (Vector3 oder null): Die Maus zeigt auf den GRUBENBODEN -
## dort soll die Hülle sichtbar über dem Zeiger schweben. Der Bodenpunkt wird
## in die Grube geklemmt und dann ENTLANG DES KAMERASTRAHLS auf die Rüttel-Höhe
## gehoben: so bleibt die Silhouette trotz Höhen-Parallaxe innerhalb der Wände.
func _shell_drag_target(screen_pos: Vector2) -> Variant:
	var camera := get_viewport().get_camera_3d()
	var ground: Variant = _mouse_on_plane(screen_pos, 0.0)
	if camera == null or ground == null:
		return null
	var g: Vector3 = ground
	var lim_x := DicePit.PIT_HALF_X - DiceShell.SHAKE_MARGIN
	var lim_z := DicePit.PIT_HALF_Z - DiceShell.SHAKE_MARGIN
	g.x = clampf(g.x, DicePit.PIT_CENTER.x - lim_x, DicePit.PIT_CENTER.x + lim_x)
	g.z = clampf(g.z, DicePit.PIT_CENTER.z - lim_z, DicePit.PIT_CENTER.z + lim_z)
	var c := camera.global_position
	if c.y <= DiceShell.SHAKE_HEIGHT + 0.1:
		return g + Vector3.UP * DiceShell.SHAKE_HEIGHT
	return c + (g - c) * ((c.y - DiceShell.SHAKE_HEIGHT) / c.y)

func _end_shell_drag() -> void:
	if shell_is_dragging:
		camera_rig.set_tilt_locked(false)
		dice_shell.set_grabbed(false)  # Loslassen beim Rütteln kippt sofort aus
	shell_drag_active = false
	shell_is_dragging = false
	shell_throw_pending = false

## True, solange der aktuelle Wurf sichtbar läuft (Hülle oder Physik).
func _dice_in_motion() -> bool:
	return phase == Phase.SHELL_ANIMATING or phase == Phase.ROLLING

## True in allen Phasen VOR dem Rundenabschluss (inklusive laufender Würfe).
func _is_playing() -> bool:
	return phase == Phase.IDLE or _dice_in_motion()

func _can_toggle_selection() -> bool:
	return phase == Phase.IDLE and has_rolled_current_hand

## Sind die Würfel tabu? Bearbeitet wird im Laden UND im Vorlauf der neuen Runde:
## Die Werkbank bleibt offen, bis der Vertrag der Runde steht (bzw. bis zum ersten
## Wurf, wenn keine Auslage kommt) - erst dann sind die Würfel im Spiel.
func _dice_editing_locked(_def: DieDefinition = null) -> bool:
	return round_committed and phase != Phase.SHOP

## Zieht die Sperre der Werkbank nach (Unterschrift/erster Wurf).
func _sync_editing_lock() -> void:
	if table_screen != null and table_screen.workshop_window != null:
		table_screen.workshop_window.editing_locked = _dice_editing_locked()
	# Die LADESÄULE ist bedienbar, solange die Werkstatt es ist.
	_refresh_charging_column()

func _pick_die_index(screen_pos: Vector2) -> int:
	var result := _ray_pick(screen_pos, 2)
	if result.is_empty():
		return -1
	return dice.index_of_body(result.collider)

## Seiten-Material der oben liegenden Seite je Wurf-Slot ("" = keins/ungewürfelt).
func _rolled_materials() -> Array[String]:
	var materials: Array[String] = []
	for i in dice.count():
		var face: int = dice.face_indices[i]
		var def: DieDefinition = dice.slot_defs[i]
		if face >= 0 and face < def.materials.size():
			materials.append(def.materials[face])
		else:
			materials.append("")
	return materials

## Die Defs bzw. Oben-Seiten eines Auswahl-Teilwurfs - dieselbe Umschlüsselung
## wie sel_values/sel_materials, damit der Zündungs-Plan in Auswahl-Indizes rechnet.
func _selected_defs(slots: Array[int]) -> Array[DieDefinition]:
	var defs: Array[DieDefinition] = []
	for s in slots:
		defs.append(dice.slot_defs[s])
	return defs

func _selected_faces(slots: Array[int]) -> Array[int]:
	var faces: Array[int] = []
	for s in slots:
		faces.append(dice.face_indices[s] if s < dice.face_indices.size() else -1)
	return faces

## Die GEZEIGTEN Werte der liegenden Würfel (Verwandlungskette + Essenz-Linse).
## Alles, was ordnet oder zielt, rechnet auf ihnen - eine per Fuchsschwanz zur 4
## verwandelte 3 IST für Reihe und Zielwahl eine 4.
func _shown_pit_values() -> Array[int]:
	if run == null:
		return dice.values
	return DiceScoring.shown_values(dice.values, run.charm_ids(),
		{DiceScoring.CTX_ESSENCE_SET: _effective_essence_sets()})

## Runen je Wurf-Slot (Slot -> Liste der Runen auf der OBEN liegenden Seite).
## Einmal HIER aufgelöst, wie die Pointer-Ketten - das Nachglühen ändert
## Auslösungen, also muss auch der Farkle-Vergleich dieselben Runen sehen.
func _slot_runes() -> Dictionary:
	var out := {}
	for i in dice.count():
		var def: DieDefinition = dice.slot_defs[i]
		if def == null:
			continue
		var face: int = dice.face_indices[i]
		var on_face := def.runes_on(face)
		if not on_face.is_empty():
			out[i] = on_face
	return out

## Essenz je Wurf-Slot (Slot -> id; Slots ohne Essenz fehlen). Einmal HIER
## aufgelöst, damit Vorschau, Nehmen und Farkle-Vergleich dieselben Würfel
## beseelt sehen.
func _slot_essences() -> Dictionary:
	var essences := {}
	for i in dice.count():
		var def: DieDefinition = dice.slot_defs[i]
		if def != null and def.essence_id != "":
			essences[i] = def.essence_id
	return essences

## Slot -> Ladung bzw. durchgebrannt, aus den Defs gelesen. Beide sind
## slot-gebunden, werden also umgeschlüsselt und für den Farkle-Vergleich
## mitgeschnappt; kalte und heile Würfel fehlen einfach.
func _slot_charges() -> Dictionary:
	var charges := {}
	for i in dice.count():
		var def: DieDefinition = dice.slot_defs[i]
		if def != null and def.charge > 0:
			charges[i] = def.charge
	return charges

func _slot_burned() -> Dictionary:
	var burned := {}
	for i in dice.count():
		var def: DieDefinition = dice.slot_defs[i]
		if def != null and def.burned_out:
			burned[i] = true
	return burned

## Gespeicherte Basispunkte je Wurf-Slot (Phosphoreszenz) - Zustand am Würfel-
## Exemplar, den nur GameRun führt; er sammelt über den ganzen Run.
func _phosphor_stores() -> Dictionary:
	var stores := {}
	for i in dice.count():
		var def: DieDefinition = dice.slot_defs[i]
		if def == null:
			continue
		var stored := run.phosphor_store(def)
		if stored > 0:
			stores[i] = stored
	return stores

## Gespeicherter Mult je Wurf-Slot (Phosphoreszenz + Leuchtstoffröhre).
func _phosphor_mults() -> Dictionary:
	var stores := {}
	for i in dice.count():
		var def: DieDefinition = dice.slot_defs[i]
		if def == null:
			continue
		var stored := run.phosphor_mult(def)
		if stored > 0.0:
			stores[i] = stored
	return stores

## Seelen der Würfel, die diese Runde schon in der Ablage liegen - der Alkahest
## reicht sie der Quintessenz nach. Ohne den Charm bleibt die Liste leer.
func _discarded_essence_ids() -> Array[String]:
	var ids: Array[String] = []
	if not run.charm_ids().has(Charm.ALKAHEST):
		return ids
	for def in discarded_this_round:
		if def != null and def.essence_id != "" and not ids.has(def.essence_id):
			ids.append(def.essence_id)
	return ids

## Wirksame Essenz-Mengen der liegenden Würfel - EINE Auflösung je Aufruf, damit
## die Quintessenz überall dieselben geborgten Seelen sieht (inkl. Ablage).
func _effective_essence_sets() -> Dictionary:
	return EssenceEffects.effective_sets(_slot_essences(), _discarded_essence_ids())

## Runen-Glieder je Wurf-Slot (Kehrseite): einmal HIER aufgelöst, damit
## Vorschau, Nehmen und Farkle-Vergleich dieselben Glieder sehen - über
## dieselbe Quelle wie die Nehmen-Effekte. Der Pointer steht NICHT hier: er
## wird beim Nehmen ausgewürfelt.
func _det_links() -> Dictionary:
	return _link_map(false)

## Essenz-Glieder je Wurf-Slot (Röntgenlicht) - sie feuern JE Würfel-Trigger;
## über die Antritte rollt die Wertung sie selbst weiter.
func _essence_links() -> Dictionary:
	return _link_map(true)

## Beide Glieder-Karten aus EINER Quelle: essence = das Röntgen-Glied, sonst die
## Runen-Glieder (der Stichel lässt die Kehrseite zweimal zünden).
func _link_map(essence: bool) -> Dictionary:
	var links := {}
	var sets := _effective_essence_sets()
	var ids := run.charm_ids()
	for i in dice.count():
		var face: int = dice.face_indices[i]
		var def: DieDefinition = dice.slot_defs[i]
		if face < 0 or def == null:
			continue
		var essence_ids := EssenceEffects.set_at(sets, i)
		var rune_ids := def.runes_on(face)
		var chain: Array[int] = EssenceEffects.link_faces(def, face, rune_ids)
		if essence:
			chain = EssenceEffects.essence_link_faces(def, face, essence_ids)
		if chain.is_empty():
			continue
		var entries: Array[Dictionary] = []
		for link_face in chain:
			var material: String = def.materials[link_face] if link_face < def.materials.size() else ""
			var level := MaterialEffects.face_level(def, link_face)
			var running: int = def.faces[link_face]
			# Der Stichel lässt die Kehrseite zweimal zünden; der Wert wandert dabei
			# mit wie beim Pointer-Wurf (Knochen wächst zwischen den Zündungen).
			var fires := 1 if essence else EssenceEffects.det_link_fire_count(face, link_face, rune_ids, ids)
			for _s in fires:
				entries.append({
					"face": link_face,
					"value": running,
					"material": material,
					"level": EssenceEffects.boosted_level(level, essence_ids),
					# Der ECHTE Zustand daneben: das Manometer rollt die Liste weiter
					# aus und muss dafür wandeln wie die Def, nicht wie die Wertung.
					"raw_level": level,
				})
				running = MaterialEffects.mutate_link_value_once(running, material, ids,
					level, essence_ids, run.clause_face_growth())
		links[i] = entries
	return links

## Würfelt die Pointer aller gewerteten Würfel aus - GENAU EINMAL je Zug, im
## Moment des Nehmens, wenn Kategorie, Zählreihenfolge und Echo-Slot feststehen.
## Auswahl-indiziert wie der übrige Zug-ctx; das Ergebnis wird eingefroren, nie
## neu gewürfelt (sonst zahlte der Zug andere Glieder, als er gezählt hat).
func _roll_pointer_fires(key: String, sel_values: Array[int], slots: Array[int], ids: Array[String], sel_ctx: Dictionary) -> Dictionary:
	var shape := DiceScoring.hand_shape(key, sel_values, ids, sel_ctx)
	var order: Array[int] = shape["order"]
	var echo_slot: int = shape["echo_slot"]
	var tail_slot: int = shape["tail_slot"]
	var combination: Array[int] = shape["participating"]
	var essences := DiceScoring.essence_sets_in(sel_ctx)
	var runes := DiceScoring.runes_in(sel_ctx)
	var is_stress := GameRun.is_stress_round(run.round_number)
	var shown := DiceScoring.shown_values(sel_values, ids, sel_ctx)
	var hands_taken := int(sel_ctx.get(DiceScoring.CTX_HANDS_TAKEN, 0))
	var fires := {}
	for k in order:
		var slot: int = slots[k]
		var def: DieDefinition = dice.slot_defs[slot]
		var face: int = dice.face_indices[slot]
		if def == null or face < 0 or def.pointer_target(face) < 0:
			continue
		var essence_ids := EssenceEffects.set_at(essences, k)
		var rune_ids := RuneEffects.runes_at(runes, k)
		var die_triggers := MaterialEffects.die_trigger_count(k, ids, echo_slot, essence_ids, is_stress,
			EssenceEffects.extra_activations(k, order, essences, ids, shown, hands_taken), order.size(), tail_slot,
			hands_taken == 0, combination.has(k))
		var face_triggers := MaterialEffects.face_trigger_count(shown[k], ids, RuneEffects.extra_activations(rune_ids, ids), essence_ids)
		# Auch der reine Fehlwurf wird eingefroren: das Erdungskabel zählt genau die
		# leeren Gruppen, und im ctx stehen nur Würfel MIT Pointer.
		fires[k] = DiceScoring.roll_pointer_fires(def, face, die_triggers, face_triggers,
			ids, essence_ids, pointer_rng,
			EssenceEffects.essence_repeat_count(k, order, essences, ids), run.clause_face_growth())
	return fires

## Material-Infos je Wurf-Slot: der Zustand des Materials der OBEREN Seite, dazu
## die Augensumme (Bernstein zahlt sie in beiden Zuständen).
func _material_levels() -> Dictionary:
	var levels := {}
	var sets := _effective_essence_sets()
	for i in dice.count():
		var def: DieDefinition = dice.slot_defs[i]
		if def == null:
			continue
		var eye_sum := 0
		for value in def.faces:
			eye_sum += value
		# Der Firnis legt eine zweite Schicht auf - nur für die Wertung.
		levels[i] = {
			"level": EssenceEffects.boosted_level(
				MaterialEffects.face_level(def, dice.face_indices[i]),
				EssenceEffects.set_at(sets, i)),
			"eye_sum": eye_sum,
		}
	return levels

## Wurf-/Runden-Zustand der Effektkatalog-Charms - in JEDE Wertung gereicht
## (Vorschau, Nehmen, Farkle-Vergleich), damit Anzeige und Rechnung gleich bleiben.
func _score_ctx() -> Dictionary:
	return {
		CharmEffects.CTX_PENDULUM: pendulum_acc,
		CharmEffects.CTX_FULL_REROLLS: full_reroll_stacks,
		CharmEffects.CTX_STREAK: momentum_streak,
		CharmEffects.CTX_POOL_EMPTY: _remaining_in_pool() <= 0,
		CharmEffects.CTX_AFTER_FARKLE: first_hand_after_farkle,
		CharmEffects.CTX_FARKLE_STACKS: run.farkle_count,
		CharmEffects.CTX_LATE_SLOTS: _late_slots(),
		# Die gelegte Reihenfolge reist wie jeder andere Slot-Zustand im ctx -
		# Vorschau, Zug, Farkle-Vergleich und Zähl-Animation lesen dieselbe Quelle.
		DiceScoring.CTX_PLAYER_ORDER: player_order.duplicate(),
		# Leer, sobald das Rampenlicht diese Runde kassiert ist - dann bekommt
		# es auch keinen Schritt mehr in der Zähl-Animation.
		CharmEffects.CTX_SPOTLIGHT: "" if run.spotlight_claimed_this_round else run.spotlight_combo,
		DiceScoring.CTX_THROTTLED: run.throttled_combos,  # Klausel-/Boss-Drossel
		DiceScoring.CTX_PARITY: run.parity_filter(),  # Schieflage/Gleichgewicht
		DiceScoring.CTX_DET_LINKS: _det_links(),  # Kehrseite-Rune
		DiceScoring.CTX_ESSENCE_LINKS: _essence_links(),  # Röntgenlicht
		DiceScoring.CTX_MATERIAL_LEVELS: _material_levels(),  # Veredelung der Seiten
		DiceScoring.CTX_ESSENCES: _slot_essences(),  # Seele je Würfel
		DiceScoring.CTX_EQUAL_FACES: _equal_face_values(),  # Gleichschliff
		# Die EINE Aggregation: die Quintessenz borgt sich hier die Seelen der
		# anderen liegenden Würfel - danach lesen alle Hooks nur fertige Mengen.
		DiceScoring.CTX_ESSENCE_SET: _effective_essence_sets(),
		DiceScoring.CTX_RUNES: _slot_runes(),  # Runen der oben liegenden Seiten
		# LADUNG: Stand und Ruß je Würfel plus die Regel-Parameter der Runde. Die
		# Würfe (CTX_CHARGE_ROLLS) fehlen hier mit Absicht - die Vorschau lädt nicht.
		DiceScoring.CTX_CHARGES: _slot_charges(),
		DiceScoring.CTX_BURNED: _slot_burned(),
		DiceScoring.CTX_CHARGE_RULE: run.charge_rule(),
		DiceScoring.CTX_EMBER_CORE: run.charm_ids().has(Charm.EMBER_CORE),  # Joker aus Ruß
		DiceScoring.CTX_STRESS: GameRun.is_stress_round(run.round_number),
		# Kaltverfestigung: hand-weit, also ohne Umschlüsselung in _score_ctx_for_slots.
		DiceScoring.CTX_CLAUSE_GROWTH: run.clause_face_growth(),
		DiceScoring.CTX_PHOSPHOR_STORE: _phosphor_stores(),  # Speicherlicht
		DiceScoring.CTX_PHOSPHOR_MULT: _phosphor_mults(),  # Speicherlicht + Leuchtstoffröhre
		# Was die bisherigen Hände der Runde gebracht haben - Dunkelkammer und
		# Gewitterfront lesen es, alle anderen fangen bei null an.
		DiceScoring.CTX_ROUND_TRIGGERS: run.round_trigger_count,
		DiceScoring.CTX_ROUND_CRITS: run.round_crit_count,
		# Lauf- und Rundenzustand der dritten Welle - alle hand-weit, also ohne
		# Umschlüsselung; nur die Erstwertungs-Marken hängen am Slot.
		DiceScoring.CTX_ENERGY: run.energy,
		DiceScoring.CTX_ROUND: run.round_number,
		DiceScoring.CTX_HANDS_TAKEN: hands_taken_this_round,
		DiceScoring.CTX_FUMBLES: run.round_fumbles,
		DiceScoring.CTX_ASH_FUMBLES: run.ash_fumbles,
		DiceScoring.CTX_DISCARD_SOULS: _discard_souls(),
		DiceScoring.CTX_DISCARD_VALUES: _discard_values(),
		DiceScoring.CTX_FIRST_SCORING: _first_scoring_flags(),
		DiceScoring.CTX_POOL_MATERIALS: _pool_material_faces(),  # Inventur
	}

## Material-Seiten im GANZEN Würfelpool (Inventur) - gezählt wird jede bemalte
## Seite, nicht der Würfel.
func _pool_material_faces() -> int:
	var count := 0
	for def: DieDefinition in run.owned_pool:
		if def == null:
			continue
		for material in def.materials:
			if material != "":
				count += 1
	return count

## Beseelte Würfel in der Ablage (Flaschenregal) - gezählt wird der WÜRFEL, zwei
## gleiche Seelen zählen also zweimal.
func _discard_souls() -> int:
	var souls := 0
	for def in discarded_this_round:
		if def != null and def.essence_id != "":
			souls += 1
	return souls

## Die oben liegenden Augen der Ablage - LIVE aus den Defs, damit ein späterer
## Wertwandel (Knochen, Glas) auch in der Ablage durchschlägt. Die Seite selbst
## steht fest, sie wurde beim Ablegen aufgezeichnet.
func _discard_values() -> Array[int]:
	var values: Array[int] = []
	for i in discarded_this_round.size():
		var def: DieDefinition = discarded_this_round[i]
		var face: int = discarded_faces_this_round[i] if i < discarded_faces_this_round.size() else -1
		if def == null or face < 0 or face >= def.faces.size():
			continue
		values.append(def.faces[face])
	return values

## Slot -> die Zahl, die auf ALLEN SECHS Seiten steht (Gleichschliff); ungleiche
## Würfel fehlen einfach. Aus der Def gelesen, nicht aus dem liegenden Wert.
func _equal_face_values() -> Dictionary:
	var uniform := {}
	for i in dice.count():
		var def: DieDefinition = dice.slot_defs[i]
		if def == null or def.faces.is_empty():
			continue
		var value: int = def.faces[0]
		var same := true
		for face in def.faces:
			if face != value:
				same = false
				break
		if same and value > 0:
			uniform[i] = value
	return uniform

## Slot -> wertet dieser Würfel in dieser Runde zum ersten Mal (Sternschnuppe,
## Gammablitz). Die Marke führt GameRun am Würfel-Exemplar.
func _first_scoring_flags() -> Dictionary:
	var flags := {}
	for i in dice.count():
		var def: DieDefinition = dice.slot_defs[i]
		if def != null and run.first_scoring(def):
			flags[i] = true
	return flags

## Liegt ein Vulkanblitz in der Grube? Die Aschewolke zählt genau diese Fumbles.
func _volcanic_in_pit() -> bool:
	for i in dice.count():
		var def: DieDefinition = dice.slot_defs[i]
		if def != null and dice.roots[i].visible and def.essence_id == Essence.VOLCANIC_LIGHTNING:
			return true
	return false

## Wie _score_ctx, aber auf einen Auswahl-Teilwurf umgerechnet: slot-bezogene
## Werte (late_slots) müssen auf die gefilterten Indizes übersetzt werden,
## sonst zeigt der Bodensatz auf falsche Positionen.
func _score_ctx_for_slots(slots: Array[int]) -> Dictionary:
	var ctx := _score_ctx()
	var to_filtered := {}
	for k in slots.size():
		to_filtered[slots[k]] = k
	var mapped_late: Array = []
	for s in ctx.get(CharmEffects.CTX_LATE_SLOTS, []):
		if to_filtered.has(s):
			mapped_late.append(to_filtered[s])
	ctx[CharmEffects.CTX_LATE_SLOTS] = mapped_late
	# Die angesagte Reihenfolge nennt Slots - auf die gefilterte Auswahl
	# umschlüsseln, sonst zählt die Vorschau in einer fremden Reihenfolge.
	var mapped_order: Array = []
	for s in ctx.get(DiceScoring.CTX_PLAYER_ORDER, []):
		if to_filtered.has(s):
			mapped_order.append(to_filtered[s])
	ctx[DiceScoring.CTX_PLAYER_ORDER] = mapped_order
	# Glieder hängen ebenfalls am Slot - auf die gefilterte Auswahl umschlüsseln,
	# sonst feuern sie am falschen Würfel (gilt für beide Glieder-Schlüssel).
	for link_key in [DiceScoring.CTX_DET_LINKS, DiceScoring.CTX_ESSENCE_LINKS,
			DiceScoring.CTX_POINTER_FIRES, DiceScoring.CTX_CHARGE_ROLLS]:
		var mapped_links := {}
		var links: Dictionary = ctx.get(link_key, {})
		for s in links:
			if to_filtered.has(s):
				mapped_links[to_filtered[s]] = links[s]
		ctx[link_key] = mapped_links
	# Material-Zustände hängen ebenso am Slot - ohne Umschlüsselung wertet jede
	# Auswahl-Vorschau die falschen Würfel als veredelt.
	var mapped_levels := {}
	var levels: Dictionary = ctx.get(DiceScoring.CTX_MATERIAL_LEVELS, {})
	for s in levels:
		if to_filtered.has(s):
			mapped_levels[to_filtered[s]] = levels[s]
	ctx[DiceScoring.CTX_MATERIAL_LEVELS] = mapped_levels
	# Essenzen, Runen und der Phosphor-Speicher hängen ebenso am Slot.
	for essence_key in [DiceScoring.CTX_ESSENCES, DiceScoring.CTX_ESSENCE_SET, DiceScoring.CTX_RUNES,
			DiceScoring.CTX_PHOSPHOR_STORE, DiceScoring.CTX_PHOSPHOR_MULT,
			DiceScoring.CTX_FIRST_SCORING, DiceScoring.CTX_EQUAL_FACES,
			DiceScoring.CTX_CHARGES, DiceScoring.CTX_BURNED]:
		var mapped := {}
		var source: Dictionary = ctx.get(essence_key, {})
		for slot in source:
			if to_filtered.has(slot):
				mapped[to_filtered[slot]] = source[slot]
		ctx[essence_key] = mapped
	return ctx

## Slots, deren Würfel aus den letzten 6 Stapel-Positionen gezogen wurden (Bodensatz).
func _late_slots() -> Array:
	var late: Array = []
	var threshold := round_pool_kinds.size() - 6
	for i in slot_draw_positions.size():
		if slot_draw_positions[i] >= threshold:
			late.append(i)
	return late

func _remaining_in_pool() -> int:
	return round_pool_kinds.size() - next_draw_index

func _draw_one() -> DieDefinition:
	var def: DieDefinition = round_pool_kinds[next_draw_index]
	next_draw_index += 1
	return def

## Merkt einen gebrauchten Würfel für die Runde (Phönixfeder, Fuchsfeuer, Alkahest).
## face ist die Seite, mit der er abgelegt wurde - das Fuchsfeuer zählt ihre Augen.
## Diese Liste ist die EINE Wahrheit der Wertung; die ABLAGE im Pit führt dieselben
## Würfel in ihrer eigenen (reihenweise gemischten) Ordnung.
func _discard_kind(def: DieDefinition, face: int) -> void:
	discarded_this_round.append(def)
	discarded_faces_this_round.append(face)

## Legt die ganze liegende Grube ab - je Würfel mit der Seite, die oben lag; der
## Tisch SCHLUCKT ihn an seinem Liegeplatz und er verschwindet aus der Grube (ein
## Würfel wird nie zweimal gezeigt). Auch ein Würfel ohne Körper wandert mit: die
## Ablage muss jeden abgelegten Würfel führen, sonst fehlt er im neuen Pool.
func _discard_pit() -> void:
	var defs: Array[DieDefinition] = []
	var faces: Array[int] = []
	var from: Array = []
	for i in active_kinds.size():
		var face: int = dice.face_indices[i] if i < dice.face_indices.size() else -1
		_discard_kind(active_kinds[i], face)
		defs.append(active_kinds[i])
		faces.append(face)
		if i < dice.count() and dice.roots[i].visible:
			from.append(dice.bodies[i].global_transform)
			dice.roots[i].visible = false
		else:
			from.append(null)
	_swallow_dice(defs, faces, from)

## Wie viele Warteschlangen-Würfel der nächste Wurf tatsächlich zieht: vor dem
## ersten Wurf HAND_SIZE, danach so viele, wie ungeschützte Slots neu geworfen
## werden - begrenzt auf den Pool-Rest.
func _current_queue_size() -> int:
	var wanted := HAND_SIZE
	if has_rolled_current_hand:
		wanted = 0
		for i in dice.count():
			if not dice.selected[i]:
				wanted += 1
	return min(wanted, _remaining_in_pool())

## Pool- und Warteschlangen-Tray zeigen zusammen den ungezogenen Pool-Rest:
## die Warteschlange ist ein festes Fenster am Zieh-Cursor, der Pool alles
## danach. Beide werden komplett neu befüllt - die Lücke entsteht immer hinten.
func _refresh_deck_trays() -> void:
	if not deck_shift_ghosts.is_empty():
		return  # Aufrück-Animation ruft am Ende selbst _refresh_deck_trays
	queue_tray_view.ensure_capacity(_queue_capacity())
	queue_window_size = min(_queue_display_capacity(), _remaining_in_pool())
	var queue_defs := round_pool_kinds.slice(next_draw_index, next_draw_index + queue_window_size)
	queue_tray_view.fill(queue_defs)  # leer, solange nicht aktiviert
	_sync_queue_stage()  # und die Plätze fahren auf, was der Pool hergibt
	if _pool_seated_standing():
		var seats := _tray_holes(_pool_tray_source())
		pool_tray_view.ensure_capacity(seats.size())  # Lücken belegen ihren Platz mit
		pool_tray_view.fill(seats)
		return
	# Geparkt trägt das Tray den SITZ-PLAN: Platz i IST Deck-Eintrag i, gezogene
	# hinterlassen Lücken - nichts rückt einzeln nach, nur der ganze Träger.
	pool_tray_view.ensure_capacity(maxi(round_pool_kinds.size(), 1))
	pool_tray_view.fill(_carrier_seats())
	_sync_carrier_shift()

## Die Belegung des Pool-Trays MIT allen Würfeln - auch denen, deren Körper
## gerade woanders steht. Im Laden ist die Runde vorbei und der ganze Vorrat
## liegt da, sonst der noch ungezogene Rest hinter dem Warteschlangen-Fenster.
func _pool_tray_source() -> Array[DieDefinition]:
	if run == null:
		return [] as Array[DieDefinition]
	if phase == Phase.SHOP:
		return run.owned_pool
	var pool_start := next_draw_index + _queue_display_capacity()
	return round_pool_kinds.slice(pool_start, round_pool_kinds.size())

## Zeigt ein Bank-Tray den Körper dieses Würfels? Ein Pool-Würfel LIEGT im Pool, bis
## er auf das PODEST fährt; dort ist sein Sitz leer (der EINE Ort-Zustand
## _bench_die) - daneben im Tray wäre er ein zweiter Leib. REINE Anzeige: gezogen, geworfen und gewertet
## wird er wie jeder andere, und die Warteschlange (Grube) zeigt ihn weiter.
func _tray_shows(def: DieDefinition) -> bool:
	# Beim TAUSCH bleibt der Sitz leer, bis der alte Würfel unten hinaus ist - der
	# Eintrag trägt schon den neuen Inhalt, aber gezeigt wird er erst danach.
	if def != null and def == _exchange_hidden:
		return false
	return DiceTrayView.seat_shows(def, null, def != null and def == _bench_die)

## Dieselbe Liste mit LÜCKEN statt Auslassungen: der Platz eines abwesenden
## Würfels bleibt leer, alle anderen behalten ihren Sitz. Nur so bleibt Platz i
## derselbe Würfel wie vorher - das Pool-Tray ist eine Ordnung, keine Aufreihung.
func _tray_holes(defs: Array[DieDefinition]) -> Array[DieDefinition]:
	var seats: Array[DieDefinition] = []
	for def in defs:
		seats.append(def if _tray_shows(def) else null)
	return seats

## Shop-Eröffnung: der ganze Bestand ruht sichtbar im Pool-Tray und die
## Warteschlange ist leer - die Runde ist vorbei, es wird nicht mehr gezogen.
func _return_dice_to_pool_tray() -> void:
	queue_tray_view.clear()
	_sync_queue_stage()
	if not _pool_seated_standing():
		return  # der Vorrat fährt gerade erst herauf (siehe _play_tray_return)
	pool_tray_view.ensure_capacity(run.owned_pool.size())
	pool_tray_view.fill(_tray_holes(_pool_tray_source()))

## Warteschlangen-Fenster: fest HAND_SIZE Plätze.
func _queue_capacity() -> int:
	return HAND_SIZE

## Sichtbare Warteschlangen-Größe: 0, solange das Tray dieser Runde noch nicht
## aktiviert ist (siehe _activate_queue), sonst die volle Kapazität.
func _queue_display_capacity() -> int:
	return _queue_capacity() if queue_activated else 0

## Weltposition des Deck-Eintrags deck_index bei Zieh-Cursor cursor (gleiche
## Aufteilung Warteschlange/Pool wie _refresh_deck_trays).
func _deck_slot_position(deck_index: int, cursor: int) -> Vector3:
	var offset := deck_index - cursor
	if offset < _queue_display_capacity():
		return queue_tray_view.slot_global_position(offset)
	# Im Pool-Tray hat JEDER Eintrag seinen Sitz - ein abwesender Würfel lässt ihn
	# leer, statt die Reihe aufrücken zu lassen. Also reine Indexrechnung.
	return pool_tray_view.slot_global_position(offset - _queue_display_capacity())

## Freier, nicht-kollidierender Würfel für die Gleit-Animationen.
func _spawn_deck_ghost(def: DieDefinition) -> Node3D:
	var ghost := FloatingDie.build_ghost(def)
	add_child(ghost)
	ScreenReflection.mark_reflective(ghost)  # gleitet über das Glas -> spiegelt sich
	return ghost

## Lässt die verbleibenden Deck-Würfel sichtbar aufrücken, nachdem shift
## Würfel gezogen wurden: beide Trays werden durch Ghost-Würfel ersetzt, die
## zu ihrer neuen Slot-Position gleiten; danach übernimmt die Slot-Anzeige.
func _animate_deck_shift(shift: int) -> void:
	if shift <= 0:
		return
	_cancel_deck_shift()
	var old_cursor := next_draw_index - shift
	queue_tray_view.clear()
	# Der geparkte Träger rührt sich nicht: dort ist der Sitz FEST, und geleert wird
	# ein Platz von seiner eigenen Abfahrt (_leave_carrier_seats).
	if _pool_standing:
		pool_tray_view.clear()
	deck_shift_tween = create_tween()
	deck_shift_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	deck_shift_tween.set_parallel(true)
	var cap := _queue_display_capacity()
	for deck_index in range(next_draw_index, round_pool_kinds.size()):
		var new_offset := deck_index - next_draw_index
		var old_offset := deck_index - old_cursor
		if new_offset >= cap:
			# Bleibt im Pool-Bereich: ein abwesender Würfel (aufgespannt, im Dossier)
			# hat keinen Körper, der aufrücken könnte, und im versenkten Vorrat rückt
			# sichtbar gar nichts auf.
			if not _pool_standing or not _tray_shows(round_pool_kinds[deck_index]):
				continue
		elif old_offset >= cap:
			# Kommt NEU aus dem versenkten Vorrat in die Warteschlange - der fährt per
			# Plattform hoch (_sync_queue_stage), nicht als Gleiter über den Tisch.
			continue
		# Ansonsten Umsortieren INNERHALB der Warteschlange: das gleitet an der Fläche.
		var ghost := _spawn_deck_ghost(round_pool_kinds[deck_index])
		ghost.global_position = _deck_slot_position(deck_index, old_cursor)
		deck_shift_ghosts.append(ghost)
		deck_shift_tween.tween_property(ghost, "global_position", _deck_slot_position(deck_index, next_draw_index), DECK_SHIFT_DURATION)
	deck_shift_tween.chain().tween_callback(_finish_deck_shift)

func _finish_deck_shift() -> void:
	_cancel_deck_shift()
	_refresh_dice_trays()

## Trays neu setzen, aus der richtigen Quelle: im Laden ist die Runde vorbei und
## der ganze Vorrat liegt im Pool-Tray, sonst zeigt es den Rundenstapel. Hält an,
## solange eine Aufrück-Animation läuft - die ruft am Ende selbst her.
func _refresh_dice_trays() -> void:
	if not deck_shift_ghosts.is_empty():
		return
	if phase == Phase.SHOP:
		_return_dice_to_pool_tray()
	else:
		_refresh_deck_trays()

func _cancel_deck_shift() -> void:
	if deck_shift_tween:
		deck_shift_tween.kill()
		deck_shift_tween = null
	for ghost in deck_shift_ghosts:
		ghost.queue_free()
	deck_shift_ghosts.clear()

func _on_throw_button_pressed() -> void:
	if phase != Phase.IDLE or route_pending:
		return
	if _remaining_in_pool() <= 0:
		return
	# Ohne Auslage (Runde 1) zurrt der erste Wurf die Runde fest.
	_commit_round()
	# Eine laufende Aufreihung beenden - der neue Wurf übernimmt die Würfel.
	_cancel_lineup()
	_close_side_bet_betting()  # der erste Wurf schließt die Wettannahme
	# Der Tisch schaltet scharf: der Rundenpuls läuft ab dem ersten Wurf bis zum
	# Shop (idempotent - jeder weitere Wurf blendet höchstens nach).
	if table_screen != null:
		table_screen.set_round_pulse(true)

	# Warteschlangen-Würfel VOR dem Ziehen merken (Position + Art) - genau die
	# fliegen gleich sichtbar in die Energie-Hülle.
	var used_count := _current_queue_size()
	var fly_positions: Array[Vector3] = []
	var fly_defs: Array[DieDefinition] = []
	for i in used_count:
		fly_positions.append(queue_tray_view.slot_global_position(i))
		fly_defs.append(queue_tray_view.slot_defs[i])

	# Ersetzte (ungeschützte) Würfel schluckt der Tisch an ihrem Liegeplatz.
	var discard_from: Array = []  # je Würfel seine WELT-Lage (Transform3D)
	var discard_defs: Array[DieDefinition] = []
	var discard_faces: Array[int] = []
	if has_rolled_current_hand:
		for i in dice.count():
			# Nur was wirklich in der Grube liegt, wandert ab - leere Slots (Rest-
			# Pool) haben keinen Würfel, den sie ablegen könnten.
			if dice.selected[i] or not dice.roots[i].visible:
				continue
			discard_from.append(dice.bodies[i].global_transform)
			discard_defs.append(active_kinds[i])
			discard_faces.append(dice.face_indices[i])
			dice.roots[i].visible = false

	# Geschützte Würfel gleiten an den oberen Grubenrand, statt zwischen den
	# frisch geworfenen unterzugehen.
	var move_top_indices: Array[int] = []
	var move_top_targets: Array[Vector3] = []
	if has_rolled_current_hand:
		var selected_indices: Array[int] = []
		for i in dice.count():
			if dice.selected[i]:
				selected_indices.append(i)
		# Nach Z sortiert behalten sie beim Hochgleiten ihre Reihen-Ordnung.
		selected_indices.sort_custom(func(a: int, b: int) -> bool:
			return dice.bodies[a].global_position.z < dice.bodies[b].global_position.z)
		for k in selected_indices.size():
			var i: int = selected_indices[k]
			move_top_indices.append(i)
			move_top_targets.append(_pit_top_row_position(k, selected_indices.size(), dice.bodies[i].global_position.y))

	phase = Phase.SHELL_ANIMATING

	var cursor_before_draw := next_draw_index
	last_throw_was_reroll = has_rolled_current_hand
	# Jeder Wurf setzt die Ansage zurück - die neue Lage legt der Spieler selbst;
	# der Farkle-Vergleich bekommt vorher noch die ALTE Ansage geschnappt.
	var declared_before := player_order.duplicate()
	player_order.clear()
	var thrown_indices: Array[int] = []
	if not has_rolled_current_hand:
		# Erster Wurf der Hand: die gequeuten Würfel wirklich ziehen und werfen.
		hand_note = ""
		active_kinds = []
		slot_draw_positions = []
		for i in HAND_SIZE:
			if _remaining_in_pool() <= 0:
				break
			slot_draw_positions.append(next_draw_index)  # Bodensatz
			active_kinds.append(_draw_one())
			thrown_indices.append(i)
		dice.set_slot_defs(active_kinds)
	else:
		# Neu würfeln: alle NICHT ausgewählten Slots bekommen einen neu
		# gezogenen Würfel; ausgewählte bleiben unangetastet liegen.
		pre_reroll_values = dice.values.duplicate()
		pre_reroll_materials = _rolled_materials()
		pre_reroll_essences = _slot_essences()
		pre_reroll_runes = _slot_runes()
		pre_reroll_det_links = _det_links()
		pre_reroll_essence_links = _essence_links()
		pre_reroll_levels = _material_levels()
		pre_reroll_charges = _slot_charges()
		pre_reroll_burned = _slot_burned()
		pre_reroll_phosphor = _phosphor_stores()
		pre_reroll_phosphor_mult = _phosphor_mults()
		pre_reroll_first_scoring = _first_scoring_flags()
		pre_reroll_order = declared_before
		for i in dice.count():
			if not dice.selected[i] and _remaining_in_pool() > 0:
				if i < slot_draw_positions.size():
					slot_draw_positions[i] = next_draw_index  # Bodensatz
				active_kinds[i] = _draw_one()
				thrown_indices.append(i)
		dice.set_slot_defs(active_kinds)
		# Effektkatalog-Zähler: Pendel, Anker, Roter Knopf.
		rerolls_this_hand += 1
		pendulum_acc += 2 * thrown_indices.size()  # Pendel schwingt hoch (überlebt Runden)
		if thrown_indices.size() == dice.count():
			full_reroll_stacks += 1
		_update_charm_badges()
	last_thrown_slots = thrown_indices.duplicate()
	# Die Warteschlange rückt IN der Fläche auf, ihr Schwanz wird frei - und vom
	# Träger fährt je gezogenem Würfel eine eigene Plattform ab. Beides VOR dem
	# Gleiten: danach kennt der Schreiber die Lücken.
	_shift_queue_occupancy(next_draw_index - cursor_before_draw)
	_leave_carrier_seats(_drawn_carrier_seats(cursor_before_draw))
	_animate_deck_shift(next_draw_index - cursor_before_draw)

	await _play_shell_roll(fly_positions, fly_defs, discard_from, discard_defs, discard_faces, move_top_indices, move_top_targets)
	if phase != Phase.SHELL_ANIMATING:
		dice_shell.clear_ghosts()
		return  # Spiel wurde während der Hüllen-Animation zurückgesetzt

	# poured_out feuert im Berst-Moment des Wirbels - erst dann starten die
	# echten Würfel. Die Berst-Stände werden VOR dem Abräumen geschnappt: Ort,
	# Lage und Bewegung jedes Taumel-Würfels gehen auf seinen Wurf-Würfel über,
	# der Wurf setzt die losgelassene Bewegung fort statt sie zu ersetzen.
	dice_shell.play_release()
	await dice_shell.poured_out
	var burst := dice_shell.release_states()
	dice_shell.clear_ghosts()
	if phase != Phase.SHELL_ANIMATING:
		return  # Spiel wurde während des Auskippens zurückgesetzt

	var start_positions := _throw_start_positions(burst)
	for k in thrown_indices.size():
		var i: int = thrown_indices[k]
		var basis := dice.start_transforms[i].basis
		if k < burst.size():
			basis = burst[k]["basis"]
		dice.start_transforms[i] = Transform3D(basis, start_positions[k])
	phase = Phase.ROLLING
	dice.throw_slots(thrown_indices, throw_force, spin_strength, DicePit.PIT_CENTER, burst)
	_refresh_ui()

## Startpositionen der Wurf-Würfel: die BERST-STÄNDE des Wirbels - jeder echte
## Würfel startet, wo sein Taumel-Würfel im Auskipp-Moment flog (burst =
## release_states, VOR clear_ghosts geschnappt). Geklemmt in den Gruben-
## Innenraum (die Energiewände sind 16 hoch - außerhalb spawnte er IN der
## Wand), und überschneidungsfrei gehalten: zu nahe Starts katapultiert die
## Physik-Depenetration aus der Wurfbahn, der spätere weicht nach oben aus.
## Rückfall ohne Bahn-Stand: das alte 3x2-Raster am Wirbel-Zentrum.
func _throw_start_positions(burst: Array[Dictionary]) -> Array[Vector3]:
	var mouth := dice_shell.mouth_position()
	var lim_x := DicePit.PIT_HALF_X - 2.3
	var lim_z := DicePit.PIT_HALF_Z - 2.3
	var center := mouth
	center.x = clampf(center.x, DicePit.PIT_CENTER.x - lim_x - 2.3, DicePit.PIT_CENTER.x + lim_x - 2.3)
	center.z = clampf(center.z, DicePit.PIT_CENTER.z - lim_z - 2.3, DicePit.PIT_CENTER.z + lim_z - 2.3)
	var dir := DicePit.PIT_CENTER - center
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var right := dir.cross(Vector3.UP).normalized()
	var positions: Array[Vector3] = []
	for i in dice.count():
		var p: Vector3
		if i < burst.size():
			p = burst[i]["position"]
		else:
			var col := float(i % 3) - 1.0
			var row := float(int(i / 3.0))
			p = center + right * col * 2.3 + Vector3.UP * row * 2.3 \
				+ dir * randf_range(-0.3, 0.3)
		p.x = clampf(p.x, DicePit.PIT_CENTER.x - lim_x, DicePit.PIT_CENTER.x + lim_x)
		p.z = clampf(p.z, DicePit.PIT_CENTER.z - lim_z, DicePit.PIT_CENTER.z + lim_z)
		positions.append(p)
	# Die Taumel-Würfel sind gleich groß wie die echten und kollidieren im
	# Wirbel miteinander - Berst-Stände stehen also schon physisch frei. Der
	# Schutz greift nur noch, wenn die Wand-Klemmung zwei zusammenschiebt;
	# die alte 2,3er-Schwelle hob sonst halbe Schwärme sichtbar an.
	for a in positions.size():
		for b in range(a + 1, positions.size()):
			if positions[a].distance_to(positions[b]) < 1.5:
				positions[b].y += 1.5
	return positions

## Zielposition eines geschützten Würfels am oberen Grubenrand: mittig
## zentrierte Reihe; y bleibt die des Würfels (kein Höhensprung).
func _pit_top_row_position(slot_number: int, count: int, y: float) -> Vector3:
	var span := PIT_TOP_ROW_SPACING * float(count - 1)
	var z := -span * 0.5 + PIT_TOP_ROW_SPACING * float(slot_number)
	return Vector3(DicePit.PIT_CENTER.x + PIT_TOP_ROW_X, y, DicePit.PIT_CENTER.z + z)

## Rückt die ausgerollten Würfel in eine zentrierte Reihe in der Grubenmitte -
## GENAU in der Zählreihenfolge (DiceScoring.trigger_order, Auswahl = Kombination):
## Reihe und Zählung sind dasselbe Ding, also darf es hier keinen zweiten
## Vergleicher geben. Die unbeteiligten Würfel hängen sich dahinter. Der
## Aufrichtung ist es egal - jeder Würfel behält seine gewürfelte Oben-Seite und
## dreht sich nur gerade. Die Körper werden eingefroren; der nächste Wurf gibt
## sie wieder frei.
func _line_up_settled_dice() -> void:
	_cancel_lineup()
	# Nur sichtbare Würfel - unsichtbare Slots sollen keine Lücken reißen.
	var indices: Array[int] = []
	for i in dice.count():
		if dice.roots[i].visible:
			indices.append(i)
	if indices.is_empty():
		return
	# Die Reihe wird aus der ANSAGE gerendert; nur was sie nicht nennt, fällt
	# hinten kanonisch ein (frisch gefallene Würfel vor dem ersten Aufräumen).
	# Gerechnet wird auf den GEZEIGTEN Werten - die Reihe ist die Zählreihenfolge.
	var shown := _shown_pit_values()
	# Die Auswahl IST die Kombination; die übrigen liegenden Würfel hängen sich
	# als "nur mitgezählt" dahinter - dieselbe Trennung, die trigger_order kennt.
	var selected: Array[int] = []
	for i in indices:
		if dice.selected[i]:
			selected.append(i)
	indices = DiceScoring.trigger_order(indices, shown, player_order, selected)
	player_order = indices.duplicate()
	# Alle auf die niedrigste Ruhehöhe der Gruppe - ein auf einem Nachbarn
	# liegen gebliebener Würfel würde sonst in der Reihe schweben.
	var rest_y := INF
	for i in indices:
		rest_y = minf(rest_y, dice.bodies[i].global_position.y)
	lineup_tween = create_tween()
	lineup_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lineup_tween.set_parallel(true)
	var span := PIT_TOP_ROW_SPACING * float(indices.size() - 1)
	for k in indices.size():
		var body := dice.bodies[indices[k]]
		body.freeze = true
		var target := Vector3(DicePit.PIT_CENTER.x + PIT_CENTER_ROW_X, rest_y,
			DicePit.PIT_CENTER.z - span * 0.5 + PIT_TOP_ROW_SPACING * float(k))
		lineup_tween.tween_property(body, "global_transform",
			Transform3D(_readable_upright_basis(body.global_basis), target), LINEUP_DURATION)

## Wie _snapped_upright_basis, zusätzlich so um die Hochachse gedreht, dass
## die Ziffer der Oben-Seite für den Spieler aufrecht steht.
func _readable_upright_basis(basis: Basis) -> Basis:
	var snapped := _snapped_upright_basis(basis)
	for axis: String in DiceController.AXIS_DIRECTIONS:
		if (snapped * DiceController.AXIS_DIRECTIONS[axis]).dot(Vector3.UP) < 0.9:
			continue
		var text_up: Vector3 = snapped * DiceController.FACE_TEXT_UP[axis]
		return Basis(Vector3.UP, atan2(text_up.z, text_up.x)) * snapped
	return snapped

## Nächstgelegene achsenparallele Ausrichtung: jede Achse rastet auf die
## Weltachse mit dem größten Anteil ein - die Oben-Seite bleibt oben.
func _snapped_upright_basis(basis: Basis) -> Basis:
	var x := _nearest_world_axis(basis.x, Vector3.ZERO)
	var y := _nearest_world_axis(basis.y, x)
	return Basis(x, y, x.cross(y))

## Weltachse (±X/±Y/±Z) mit dem größten Anteil an v, ausgenommen blocked.
func _nearest_world_axis(v: Vector3, blocked: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_dot := -INF
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		if absf(axis.dot(blocked)) > 0.5:
			continue
		for candidate: Vector3 in [axis, -axis]:
			if candidate.dot(v) > best_dot:
				best_dot = candidate.dot(v)
				best = candidate
	return best

func _cancel_lineup() -> void:
	if lineup_tween != null and lineup_tween.is_valid():
		lineup_tween.kill()

## Drei gleichzeitige Bewegungen beim Wurfstart: gezogene Würfel fliegen in
## die Energie-Hülle (und taumeln dort als Physik-Körper weiter, siehe
## DiceShell.capture_die), ersetzte SCHLUCKT der Tisch an ihrem Liegeplatz (die
## Hebebühne), geschützte gleiten an den oberen Grubenrand.
func _play_shell_roll(fly_positions: Array[Vector3], fly_defs: Array[DieDefinition], discard_from: Array, discard_defs: Array[DieDefinition], discard_faces: Array[int], move_top_indices: Array[int], move_top_targets: Array[Vector3]) -> void:
	if fly_defs.is_empty() and discard_defs.is_empty() and move_top_indices.is_empty():
		return

	# Der Schluck läuft eigenständig (eigene Kette, eigener Aufräum-Pfad); gebucht
	# wird unverändert erst bei der Ankunft der Hüllen-Fuhre.
	_swallow_dice(discard_defs, discard_faces, discard_from)

	var fly_tween := create_tween()
	fly_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Ein Takt, den nichts füllt, dauert trotzdem seine Zeit - ein leerer Tween
	# meldete sonst sofort fertig.
	fly_tween.tween_interval(SHELL_FLY_DURATION)
	fly_tween.set_parallel(true)

	var fly_ghosts: Array[Node3D] = []
	var mouth := dice_shell.mouth_position()
	for i in fly_defs.size():
		var ghost := _spawn_deck_ghost(fly_defs[i])
		ghost.global_position = fly_positions[i]
		fly_ghosts.append(ghost)
		var target := mouth + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.4), randf_range(-0.6, 0.6))
		fly_tween.tween_property(ghost, "global_position", target, SHELL_FLY_DURATION)

	for k in move_top_indices.size():
		var body := dice.bodies[move_top_indices[k]]
		body.freeze = true
		fly_tween.tween_property(body, "global_position", move_top_targets[k], SHELL_FLY_DURATION)

	await fly_tween.finished
	# Ankunft: Flug-Ghost gegen echten Taumel-Würfel in der Hülle tauschen.
	for i in fly_ghosts.size():
		dice_shell.capture_die(fly_defs[i], fly_ghosts[i].global_position)
		fly_ghosts[i].queue_free()
	for i in discard_defs.size():
		_discard_kind(discard_defs[i], discard_faces[i])

	if not fly_defs.is_empty():
		await dice_shell.play_shuffle()

func _on_roll_finished() -> void:
	phase = Phase.IDLE

	# Farkle-Prüfung: nur ein echtes Neu-Würfeln kann farkeln. Die alte Seite
	# rechnet mit IHREN Essenz-Gliedern (vor dem Neuwurf), wie mit den
	# alten Materialien.
	var old_ctx := _score_ctx()
	old_ctx[DiceScoring.CTX_DET_LINKS] = pre_reroll_det_links
	old_ctx[DiceScoring.CTX_ESSENCE_LINKS] = pre_reroll_essence_links
	old_ctx[DiceScoring.CTX_MATERIAL_LEVELS] = pre_reroll_levels
	old_ctx[DiceScoring.CTX_CHARGES] = pre_reroll_charges
	old_ctx[DiceScoring.CTX_BURNED] = pre_reroll_burned
	old_ctx[DiceScoring.CTX_ESSENCES] = pre_reroll_essences
	old_ctx[DiceScoring.CTX_ESSENCE_SET] = EssenceEffects.effective_sets(pre_reroll_essences, _discarded_essence_ids())
	old_ctx[DiceScoring.CTX_RUNES] = pre_reroll_runes
	old_ctx[DiceScoring.CTX_PHOSPHOR_STORE] = pre_reroll_phosphor
	old_ctx[DiceScoring.CTX_PHOSPHOR_MULT] = pre_reroll_phosphor_mult
	old_ctx[DiceScoring.CTX_FIRST_SCORING] = pre_reroll_first_scoring
	old_ctx[DiceScoring.CTX_PLAYER_ORDER] = pre_reroll_order
	if last_throw_was_reroll and not DiceScoring.is_strictly_better(dice.values, pre_reroll_values, run.charm_ids(), _rolled_materials(), pre_reroll_materials, run.combo_levels, _score_ctx(), old_ctx):
		# Anker: der ERSTE Neuwurf jeder Hand kann nicht farkeln.
		if CharmEffects.anchor_saves(run.charm_ids(), rerolls_this_hand):
			hand_note = "Anker: Der erste Neuwurf kann nicht fumblen – die Hand läuft weiter."
			_flash_charm_and_pad(run.charm_ids().find(Charm.ANCHOR))
			dice.clear_selection()
			_auto_select_best_combo()
			_line_up_settled_dice()
			has_rolled_current_hand = true
			last_throw_was_reroll = false
			_log_record_throw()
			_refresh_deck_trays()
			_refresh_ui()
			return
		# Löschgas: ein beteiligter CO2-Würfel schluckt den Fumble - ohne Limit
		# und ohne Preis. Der Anker geht trotzdem vor: er ist enger.
		var smother := run.smother_slot(active_kinds, _visible_pit_slots())
		if smother >= 0:
			hand_note = "Löschgas: Der Fumble verpufft."
			_flash_scoring_die(smother)
			dice.clear_selection()
			_auto_select_best_combo()
			_line_up_settled_dice()
			has_rolled_current_hand = true
			last_throw_was_reroll = false
			_log_record_throw()
			_refresh_deck_trays()
			_refresh_ui()
			return
		_on_farkle()
		return

	# Beste offene Kombination automatisch vorschlagen (frei umklickbar), erst
	# DANACH aufreihen - die Reihe sortiert die Kombinations-Würfel nach links.
	dice.clear_selection()
	_auto_select_best_combo()

	# Tote Hand (typisch beim ausgespielten Rest-Pool): nichts Wertbares liegt da
	# und nachgezogen werden kann auch nicht mehr - das ist ein Fumble, kein
	# Stillstand. Verzeihen hilft hier nicht weiter, die Hand käme nie voran.
	if _hand_slots().is_empty() and _remaining_in_pool() <= 0:
		_on_farkle(false)
		return

	_line_up_settled_dice()

	has_rolled_current_hand = true
	_log_record_throw()
	_refresh_deck_trays()
	_refresh_ui()

## Farkle: die Hand wird normalerweise ohne Punkte verworfen. Charms mildern:
## Schornsteinfeger verzeiht den ersten je Runde, Phönixfeder schickt die
## Würfel zurück in den Stapel, Kristallkugel zahlt fürs Überleben.
## forgivable = false bei einer toten Hand: Verzeihen ließe sie unspielbar liegen.
func _on_farkle(forgivable: bool = true) -> void:
	var ids := run.charm_ids()

	# Schornsteinfeger: die Hand läuft mit den aktuellen Würfeln weiter;
	# ein verziehener Farkle löst KEINE Farkle-Effekte aus.
	if forgivable and CharmEffects.forgives_first_farkle(ids) and not chimney_sweep_used_this_round:
		chimney_sweep_used_this_round = true
		hand_note = "Schornsteinfeger: Fumble verziehen – die Hand darf weiterlaufen."
		dice.clear_selection()
		_auto_select_best_combo()
		has_rolled_current_hand = true
		last_throw_was_reroll = false
		_log_record_throw()
		_refresh_deck_trays()
		_refresh_ui()
		return

	# Ankerklausel: der erste Farkle JEDER Runde ist verziehen - dieselbe
	# Mechanik wie der Schornsteinfeger, nur aus dem Vertrag.
	if forgivable and run.deal_anchor_active() and not anchor_clause_used_this_round:
		anchor_clause_used_this_round = true
		hand_note = "Ankerklausel: Der erste Fumble dieser Runde zählt nicht."
		dice.clear_selection()
		_auto_select_best_combo()
		has_rolled_current_hand = true
		last_throw_was_reroll = false
		_log_record_throw()
		_refresh_deck_trays()
		_refresh_ui()
		return

	# Flickenteppich: statt die Hand zu verlieren, bleibt der Würfel mit der
	# höchsten Augenzahl gehalten in der Grube - die Hand läuft mit ihm weiter.
	# Nur solange nachgezogen werden kann (sonst hinge die Hand ohne Neuwurf fest).
	if CharmEffects.farkle_keeps_high_die(ids) and _remaining_in_pool() > 0:
		_keep_highest_die_and_continue(ids)
		return

	# Kein 2D-Text mehr - die Fumble-Zeremonie (rotes Neon + Tisch-Stoßwelle)
	# quittiert den echten Farkle (verziehene oben raus). Charm-Meldungen
	# (Standuhr/Phönixfeder) dürfen die Leiste weiter nutzen.
	hand_note = ""
	# Der Fumble geht in die Chronik, solange die Würfel noch liegen.
	_log_record_farkle()
	if table_screen != null:
		table_screen.pit_fumble()

	# Ein verziehener Farkle (oben) zählt bewusst NICHT gegen die "Saubere Runde".
	round_farkled = true
	_refresh_side_bet_panel()

	# Zerbrochener Spiegel zählt, die Schwungrad-Serie reißt, Galgenhumor merkt vor.
	run.farkle_count += 1
	# Vulkanblitz/Aschewolke: der Zähler der Runde und der run-lange. Der
	# Trostpreis prägt seine Energie gleich mit - gebucht in GameRun, das Licht
	# fliegt erst hinterher.
	var consolation_energy := run.note_fumble(_volcanic_in_pit())
	if consolation_energy > 0:
		_flash_charm_and_pad(ids.find(Charm.CONSOLATION_PRIZE))
		_play_rune_energy_volley(consolation_energy)
	# LADUNG: der echte Fumble heizt die ganze Hand - erzwungenes +1 auf jeden
	# Würfel, der in der Grube liegt. Ein verziehener Fumble kommt nie hierher.
	_last_fumble_charges = run.charge_fumble_dice(active_kinds)
	# Beim Fumble fliegen die Würfel zu schnell weg, um sie zu lesen: an ihrer
	# Stelle bleibt der Umriss samt Augenzahl stehen. NACH der Ladungs-Buchung -
	# die Umrisse tragen sie mit. Vor dem Verwerfen; der Phönixfeder-Zweig nimmt
	# sie genauso mit.
	if table_screen != null:
		_show_fumble_marks()
	momentum_streak = 0
	_update_charm_badges()
	first_hand_after_farkle = true

	# Scherbengericht: $2 je verworfenem Würfel - als Chip-Pakete vom Charm-Pad
	# zur Truhe. Die Phase hält solange SCORING, damit kein Wurf dazwischenfunkt.
	var shard_income := CharmEffects.farkle_shard_income(active_kinds.size(), ids)
	if shard_income > 0:
		phase = Phase.SCORING
		await _play_charm_money_payout(ids.find(Charm.SHARD_COURT), shard_income, Phase.SCORING)
		if phase != Phase.SCORING:
			return  # Reset während der Zeremonie
		phase = Phase.IDLE

	# Standuhr: der Farkle verdoppelt die aktuellen Rundenpunkte.
	if CharmEffects.farkle_doubles_points(ids) and hand_total > 0:
		hand_total *= 2
		_animate_points_to(hand_total)
		hand_note = "Standuhr: Fumble – die Rundenpunkte verdoppeln sich!"

	# Phönixfeder: beim ERSTEN Fumble der Runde wandern die Würfel zurück in den
	# Nachziehstapel statt in die Ablage (die Hand bleibt trotzdem verloren).
	if CharmEffects.has_phoenix(ids) and not phoenix_used_this_round:
		phoenix_used_this_round = true
		round_pool_kinds.append_array(active_kinds)
		hand_note = "Phönixfeder: Fumble – die Würfel kehren in den Nachziehstapel zurück."
	else:
		_discard_pit()

	# Versicherungsbetrug: jeder echte Farkle zahlt Trostgeld.
	var consolation := run.farkle_consolation()
	if consolation > 0:
		run.add_money(consolation)

	_log_finish_entry()

	if _round_should_end():
		_on_round_complete()
	else:
		# Überlebter Farkle: Kristallkugel zahlt.
		var income := CharmEffects.farkle_survival_income(ids)
		if income > 0:
			run.add_money(income)
		_start_new_hand()

## Klausel-Wirkungen einer genommenen Hand: Hitzestau und die mitwachsende
## Boss-Drossel. Die GEBÜHREN stehen nicht mehr hier - sie zahlen an ihrem
## Auslöser (Servicegebühr beim Banken der Hand, Abzocke je gezähltem Würfel
## in der Zähl-Animation).
func _apply_hand_clauses(combo_key: String) -> void:
	if run.apply_heat_buildup(combo_key):
		hand_note = "Hitzestau: %s fällt eine Stufe zurück." % DiceScoring.label_for(combo_key)
	if run.note_hand_taken(combo_key):
		_set_throttled_combos(run.throttled_combos)

## Flickenteppich: der Würfel mit der höchsten Augenzahl bleibt als einziger
## gehalten liegen, alle anderen sind wieder frei - die Hand läuft weiter, statt
## verloren zu gehen (kein Farkle-Effekt, kein Verwerfen).
func _keep_highest_die_and_continue(ids: Array[String]) -> void:
	dice.clear_selection()
	var lying: Array[int] = []
	for i in dice.count():
		lying.append(i)
	# Gleichstand: der erste passende Würfel gewinnt (CharmEffects.target_die).
	var best := CharmEffects.target_die(_shown_pit_values(), lying, true)
	if best >= 0:
		dice.set_selected(best, true)
	_line_up_settled_dice()
	has_rolled_current_hand = true
	last_throw_was_reroll = false
	hand_note = "Flickenteppich: Der höchste Würfel bleibt liegen – die Hand läuft weiter."
	_flash_charm_and_pad(ids.find(Charm.PATCHWORK_RUG))
	_log_record_throw()
	_refresh_deck_trays()
	_refresh_ui()

## Nimmt die ausgewählten Würfel als Hand (mit Vollzähler ALLE liegenden - dann
## zählt die ganze Grube): sie bilden die Kombination und liefern Basispunkte;
## physisch wandern danach ohnehin alle liegenden Würfel in die Ablage.
func _on_take_button_pressed() -> void:
	if phase != Phase.IDLE or not has_rolled_current_hand:
		return

	var slots := _hand_slots()
	if slots.is_empty():
		return
	var ids := run.charm_ids()
	var materials := _rolled_materials()
	var sel_values: Array[int] = []
	var sel_materials: Array[String] = []
	for s in slots:
		sel_values.append(dice.values[s])
		sel_materials.append(materials[s])

	# is_first_hand VOR dem Hochzählen von hands_taken_this_round auswerten.
	var sel_ctx := _score_ctx_for_slots(slots)
	var hand := DiceScoring.best_hand(sel_values, ids, hands_taken_this_round == 0, sel_materials, run.combo_levels, sel_ctx)
	# Die Kategorie steht - jetzt die Pointer EINMAL auswürfeln und einfrieren.
	# Ab hier lesen Wertung, Schrittliste und Nehmen-Effekte dasselbe Ergebnis;
	# hand["score"] ist damit veraltet, gezahlt wird breakdown["total"].
	var sel_fires := _roll_pointer_fires(String(hand["key"]), sel_values, slots, ids, sel_ctx)
	sel_ctx[DiceScoring.CTX_POINTER_FIRES] = sel_fires
	# EINE Quelle wie in der Wertung - sonst nähme der Zug einen anderen Echo-Kopf
	# als die Punkte, die er gerade gezeigt hat.
	var sel_shape := DiceScoring.hand_shape(hand["key"], sel_values, ids, sel_ctx)
	var sel_participating: Array[int] = sel_shape["participating"]
	var sel_scored: Array[int] = sel_shape["scored"]
	var sel_order: Array[int] = sel_shape["order"]
	# LADUNG: die Würfe der Zündungen EINMAL je Zug auswürfeln und einfrieren, wie
	# die Pointer - danach ist die Wertung wieder rein.
	sel_ctx[DiceScoring.CTX_CHARGE_ROLLS] = DiceScoring.roll_charge_rolls(sel_scored, charge_rng)
	# Zähl-Reihenfolge steckt in der Wertung selbst (DiceScoring.trigger_order =
	# die aufgereihte Reihe) - kein Anordnungs-Parameter mehr, seit Krits am
	# Würfel hängen können und die Ordnung wertungsrelevant ist.
	# Schrittliste VOR den Nehmen-Effekten bauen (Knochen/Glas verändern gleich
	# die Seiten); ihre Indizes auf echte Slots zurückrechnen.
	var breakdown := ScoreBreakdown.build(hand["key"], sel_values, ids, hands_taken_this_round == 0, sel_materials, run.combo_levels, sel_ctx)
	# Geld, das EINZELNE Zündungen erzeugen (Goldseiten, Seelen-Geld), hängt an
	# seiner Zündung: der Plan reist in der Schrittliste mit, die Zeremonie zahlt
	# ihn dort. Noch in AUSWAHL-Indizes, also vor dem Rückrechnen anhängen.
	var sel_burned: Array[int] = []
	for k in sel_scored:
		if DiceScoring.burned_for(sel_ctx, k):
			sel_burned.append(k)
	ScoreBreakdown.attach_activation_money(breakdown, MaterialEffects.plan_activation_money(
		_selected_defs(slots), _selected_faces(slots), sel_materials, sel_scored, ids,
		int(sel_shape["echo_slot"]), DiceScoring.essence_sets_in(sel_ctx), sel_order,
		GameRun.is_stress_round(run.round_number), sel_fires, hands_taken_this_round,
		sel_participating, sel_burned))
	_remap_breakdown_to_slots(breakdown, slots)
	# Die Chronik hält den Zug fest, BEVOR irgendetwas gebucht wird: die Zerlegung
	# ist fertig und die Grube liegt noch so da, wie sie gezählt wurde.
	_log_begin_take(breakdown, String(hand["key"]), ids)
	# Die gewerteten Slots, in ECHTEN Slots - die Ladung bucht damit, bevor das
	# Licht läuft (Buchung vor dem Licht).
	var scored_slots: Array[int] = []
	for p in sel_scored:
		scored_slots.append(slots[p])
	_last_charge_results = run.book_charge_results(active_kinds, breakdown, scored_slots)
	hands_taken_this_round += 1
	var new_total: int = hand_total + int(breakdown["total"])
	# Verluste zahlen an ihrem Auslöser: Servicegebühr und Steuerwetten hängen an
	# der HAND, fallen also in dem Moment an, in dem sie gebankt wird - vor dem
	# Zählen. Nie über den Kassenstand hinaus; tax_side_bets klemmt selbst und
	# lässt eine ungedeckte Wette verfallen.
	var hand_fee := run.hand_fee()
	if hand_fee > 0:
		run.add_money(-mini(hand_fee, run.money))
	_tax_side_bets(slots.size())  # bucht wie eh und läßt je Zahlung einen Chip auflaufen
	await _play_take_animation(breakdown, new_total)
	if phase != Phase.SCORING:
		return  # Reset während der Animation - nichts mehr anwenden
	hand_total = new_total

	# Rundenbilanz für die Nebenwetten fortschreiben (beste Kombi + höchste Hand;
	# taken_dice_this_round folgt weiter unten, daher Fenster-Refresh erst danach).
	round_best_combo_rank = maxi(round_best_combo_rank, SideBet.combo_rank(hand["key"]))
	round_best_hand_score = maxi(round_best_hand_score, int(breakdown["total"]))

	# Nehmen-Effekte der Materialien - die gewerteten AUSGEWÄHLTEN Würfel (mit
	# Vollzähler ALLE liegenden), genau einmal hier (nie in der Vorschau);
	# Knochen/Glas verändern die Pool-Würfel dauerhaft. sel_shape steht schon.
	var participating: Array[int] = scored_slots.duplicate()
	# Durchgebrannte Slots und die Abbruch-Zündungen auf echte Slots: die
	# Nehmen-Effekte brechen an genau derselben Zündung ab wie die Wertung.
	var burned_slots: Array[int] = []
	for p in sel_burned:
		burned_slots.append(slots[p])
	# Die engere KOMBINATIONS-Menge auf echte Slots: Vollzähler und Krypton weiten
	# die gewertete Menge, gehören der Kombination aber nicht an (Zauberkarte).
	var combination: Array[int] = []
	for p in sel_participating:
		combination.append(slots[p])
	# Die übrige Rundenbilanz der Nebenwetten braucht die GEWERTETEN Würfel.
	_note_hand_for_side_bets(String(hand["key"]), int(breakdown["total"]), slots.size(),
		CharmEffects.transform_values(sel_values, ids), sel_scored)
	# Echo-Kammer: Kopf der Zählreihe, in Auswahl-Indizes bestimmt, dann auf den
	# echten Slot zurück.
	var echo_sel: int = sel_shape["echo_slot"]
	var echo_slot := slots[echo_sel] if echo_sel >= 0 else -1
	var take_order := DiceScoring.trigger_order(participating, _shown_pit_values(), player_order, combination)
	# Der gezündete Pointer zurück auf echte Slots - der ctx sprach in Auswahl-
	# Indizes, die Nehmen-Effekte arbeiten am Pool.
	var slot_fires := {}
	for k in sel_fires:
		slot_fires[slots[int(k)]] = sel_fires[k]
	var report := MaterialEffects.apply_take_effects(active_kinds, dice.face_indices, materials, participating,
		ids, echo_slot, _effective_essence_sets(), take_order,
		GameRun.is_stress_round(run.round_number), _visible_pit_slots(), slot_fires,
		hands_taken_this_round - 1, run.round_bare_dice, discarded_this_round, combination,
		run.clause_face_growth(), burned_slots)
	# Trinkgeldglas: nur die Bilanz - die Zeremonie hat jedes Paket längst an
	# seinem Krit losgeschickt, gebucht wird bei Ankunft.
	report.tip_money = ScoreBreakdown.tip_money_total(breakdown)
	# Erstwertung und Neonmarker-Zähler gehören dem Zug, nicht der Vorschau.
	run.note_dice_scored(active_kinds, participating)
	run.note_bare_dice(report.bare_dice)
	# Phosphoreszenz: der Anteil dieses Zuges wächst in den Speicher hinein - er
	# wird nie geleert. GameRun bucht, die Wertung bleibt pur. Dieselbe Stelle
	# schreibt die Hand-Zähler der Runde fort (Dunkelkammer, Gewitterfront).
	run.note_phosphor_stores(active_kinds, breakdown)
	run.note_hand_counters(breakdown)
	# Lasurpinsel: läuft die Firnis-Schicht auf einer Stufe-III-Seite ins Leere,
	# fällt stattdessen eine Material-Kopie in den Vorrat.
	run.apply_glaze_brush(active_kinds, dice.face_indices, participating)
	# Abguss-Rune: VOR Midashandschuh und Goldenem Handschlag - sie gießt das
	# Material ab, mit dem die Hand gezählt hat, nicht das frisch vergoldete.
	var cast_copies := run.apply_rune_cast(active_kinds, dice.face_indices, participating)
	if cast_copies > 0:
		hand_note = "Abguss: %d Material-Gravuren abgeformt." % cast_copies
	# Funkenflug ist die VIERTE ⚡-Quelle: sofort buchen, der Komet fliegt nur
	# hinterher (wie die Nebenwetten-Energie).
	if report.energy > 0:
		run.add_energy(report.energy)
		_play_rune_energy_volley(report.energy, report.sparks)
	# Tscherenkow: jeder Krit verbrennt eine Energie. Ausgeben animiert nicht -
	# der Speicher zieht sich still aus energy_changed nach.
	report.energy_spent = int(breakdown.get("energy_spent", 0))
	if report.energy_spent > 0:
		run.spend_energy(report.energy_spent)
	# Kupfer speist je Zündung; was über den Speicher hinausläuft, zahlt bar (das
	# Geld reitet die Geld-Bahn und braucht nichts Eigenes). Gebucht wird SOFORT,
	# das Licht fliegt hinterher - dieselbe Regel wie beim Funkenflug.
	if report.copper_energy > 0:
		var banked := run.energy
		run.book_copper_energy(report.copper_energy)
		_play_hub_energy_volley(run.energy - banked)
	# Streulicht und Einbrand feuern NICHT beim Zählen: der eine zahlt fürs
	# Danebenliegen, der andere wehrt einen Verlust ab. Beide brauchen darum ihren
	# eigenen Auslöser, sonst wäre ihre Wirkung die einzige, die man nie sieht.
	for slot in report.stray:
		_flare_runes(slot)
	for slot in report.blocked:
		_flare_runes(slot, true)
	# Nur der REST des Zug-Geldes: was an einer Zündung hing (Goldseiten,
	# Seelen-Geld), ist längst gebucht - Paket für Paket in seinem Moment.
	var take_money := report.money
	if not report.grown.is_empty() or not report.shrunk.is_empty() \
			or not report.decayed.is_empty() or report.discard_grown:
		# Knochen/Glas/Radon haben Pool-Würfel verändert - die in der Grube
		# liegenden Würfel zeigen ihre neuen Zahlen sofort (refresh_faces).
		run.note_pool_changed()

	# Midashandschuh: eine Hand über alle sechs Würfel vergoldet jede oben
	# liegende Seite - dauerhaft, also erst NACH den übrigen Nehmen-Effekten.
	var gilded := run.apply_midas_glove(active_kinds, dice.face_indices, participating)
	if not gilded.is_empty():
		_flash_charm_and_pad(ids.find(Charm.MIDAS_GLOVE))
		for slot in gilded:
			_flash_scoring_die(slot)
		hand_note = "Midashandschuh: %d Seiten vergoldet." % gilded.size()

	# Goldener Handschlag: "erster Würfel" ist der erste der Zähl-Reihenfolge.
	var handshake_slot: int = take_order[0] if not take_order.is_empty() else -1
	if handshake_slot >= 0 and handshake_slot < active_kinds.size():
		if run.apply_golden_handshake(active_kinds[handshake_slot], int(breakdown["total"])):
			hand_note = "Goldener Handschlag: der Würfel ist pures Gold."
			await _play_golden_handshake(handshake_slot)
			if phase != Phase.SCORING:
				return  # Reset während der Zeremonie

	# Lumpensammler beim Nehmen. Straßenmusiker zahlt NICHT hier, sondern pro
	# ausgelöstem Würfel während der Zähl-Animation (siehe _play_take_animation).
	take_money += CharmEffects.rag_collector_income(dice.values, run.lumpensammler_value, ids)
	# Jackpotglocke: schlägt die ERSTE Hand der Runde das Rundenziel, klingelt es.
	var jackpot := CharmEffects.jackpot_income(ids, int(breakdown["total"]),
		run.effective_goal(), hands_taken_this_round == 1)
	if jackpot > 0:
		take_money += jackpot
		_flash_charm_and_pad(ids.find(Charm.JACKPOT_BELL))
	if take_money > 0:
		# Gebucht wird sofort, das generische Hub->Truhe-Licht bleibt aus: der Zug
		# schickt EINEN eigenen Kometen aus der Grube hinterher.
		_suppress_money_light = true
		run.add_money(take_money)
		_suppress_money_light = false
		_play_take_money_comet(take_money)
	# Goldrausch: nur die ERSTE Hand der Runde, und nur wenn sie alle SECHS
	# Würfel nutzt -> Geld +20% (max. $50). hands_taken_this_round zählt oben schon.
	# Zahlt als Chip-Pakete vom Charm-Pad zur Truhe, wie die Rundenende-Charms;
	# die Phase bleibt solange SCORING, damit kein Wurf dazwischenfunkt.
	if CharmEffects.gold_rush_applies(ids, participating.size(), hands_taken_this_round == 1):
		var rush := CharmEffects.gold_rush_income(run.money)
		if rush > 0:
			await _play_charm_money_payout(ids.find(Charm.GOLD_RUSH), rush, Phase.SCORING)
			if phase != Phase.SCORING:
				return  # Reset während der Zeremonie
	phase = Phase.IDLE

	# Schwungrad/Galgenhumor/Pendel/Roter Knopf fortschreiben.
	momentum_streak += 1
	first_hand_after_farkle = false
	taken_dice_this_round += dice.count()
	pendulum_acc = maxi(0, pendulum_acc - dice.count())  # Pendel schwingt zurück, nie unter 0
	full_reroll_stacks = 0
	# Abzocke und Schutzgeld sind längst kassiert - die Abzocke je gezähltem
	# Würfel (_pay_die_fees), das Schutzgeld an seinem Charm-Schritt.
	_apply_hand_clauses(String(hand["key"]))
	_update_charm_badges()
	_refresh_side_bet_panel()  # Live-Fortschritt der Nebenwetten (alle Stats final)

	# Bumerang: die erste genommene Hand kehrt ans Stapel-Ende zurück.
	if CharmEffects.recycles_first_hand(ids) and not recycling_used_this_round:
		recycling_used_this_round = true
		round_pool_kinds.append_array(active_kinds)

	_discard_pit()

	_log_finish_entry()

	if _round_should_end():
		_on_round_complete()
	else:
		_start_new_hand()

## Zähl-Animation beim Nehmen (siehe ScoreBreakdown): Würfel gleiten in eine
## Reihe, dann bauen sich BASIS × MULT Schritt für Schritt auf (Kombination →
## Würfel → Charms), verschmelzen und fliegen in den Zielbalken. Ein Reset
## bricht sauber ab (phase != SCORING) - der Aufrufer wendet nichts mehr an.
func _play_take_animation(breakdown: Dictionary, new_total: int) -> void:
	phase = Phase.SCORING
	_score_seq = 0
	_score_applied = -1
	_score_pending = 0
	_score_gap = SCORE_STEP_GAP_START
	_eye_tick_applied.clear()
	_eye_planned.clear()
	_cancel_lineup()

	# 1) Schwebende Reihe: zählende Würfel zuerst, unbeteiligte rechts daneben.
	var counting: Array[int] = []
	for slot: int in breakdown["eye_slots"]:
		if slot < dice.count() and dice.roots[slot].visible:
			counting.append(slot)
	var row := counting.duplicate()
	for i in dice.count():
		if dice.roots[i].visible and not row.has(i):
			row.append(i)
	if not row.is_empty():
		var rest_y := INF
		for i in row:
			rest_y = minf(rest_y, dice.bodies[i].global_position.y)
		var hover_y := rest_y + SCORE_HOVER_HEIGHT
		var span := SCORE_ROW_SPACING * float(row.size() - 1)
		var lift := create_tween()
		lift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		lift.set_parallel(true)
		for k in row.size():
			var body := dice.bodies[row[k]]
			body.freeze = true
			var target := Vector3(DicePit.PIT_CENTER.x + SCORE_ROW_X, hover_y,
				DicePit.PIT_CENTER.z - span * 0.5 + SCORE_ROW_SPACING * float(k))
			lift.tween_property(body, "global_transform",
				Transform3D(_readable_upright_basis(body.global_basis), target), SCORE_LIFT_TIME)
		await lift.finished
	if phase != Phase.SCORING:
		_cleanup_take_animation()
		return

	# Goldenes Leucht-Podest unter jedem zählenden Würfel.
	var die_world := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT * 2.0
	var glow_side := die_world * SCORE_GLOW_SIZE_FACTOR * table_screen.pixels_per_world()
	var glow_by_slot := {}
	for i in counting:
		var glow := table_screen.spawn_glow(
			table_screen.world_to_pixel(dice.bodies[i].global_position), glow_side)
		take_anim_glows.append(glow)
		glow_by_slot[i] = glow

	# 2) Kombination: Basis UND Mult reisen als Kometen über die Kombi-Leiste in
	# den Score; die Zahlen springen bei Ankunft. Zuwachs-Zahlen sofort an der Zelle.
	var key: String = breakdown["key"]
	var combo_base: int = breakdown["combo"]["base_add"]
	var combo_mult: int = breakdown["combo"]["mult_add"]
	var combo_travel := 0.0
	if combo_labels.has(key):
		_tween_combo_label(combo_labels[key], PAYOUT_LABEL_GLOW_COLOR, 1.3)
		_glow_combo_chip(key, 1.0)
		var cell: Control = combo_labels[key]
		var cell_px: Vector2 = cell.position + cell.size / 2.0
		_spawn_score_gains(cell_px, combo_base, combo_mult)
		combo_travel = _fire_score_light(cell_px, "combos", ["base", "mult"],
			func() -> void: table_screen.update_pit_score(combo_base, combo_mult))
	else:
		table_screen.update_pit_score(combo_base, combo_mult)
	if not await _score_arrival_gap(combo_travel):
		return

	# 2b) Dreifacher Boden: je Kopie ein eigener Schlag vom Dock-Pad auf den Zähler.
	# Die Kombination reist pur, die Verdreifachung der Basis kommt sichtbar
	# hinterher - sonst stünde am Zähler eine Zahl ohne sichtbare Herkunft.
	for step: Dictionary in breakdown.get("combo_factor_steps", []):
		for charm_index: int in step["charm_indices"]:
			_flash_charm_and_pad(charm_index)
		var factor_px := _charm_trail_source_px(step["charm_indices"])
		var factor_base: int = step["base_after"]
		var factor_mult: float = step["mult_after"]
		_spawn_score_gains(factor_px, 0, 0, 2, 2.0)
		var factor_travel := _fire_score_light(factor_px, "charm", ["base", "mult"],
			func() -> void: table_screen.update_pit_score(factor_base, factor_mult))
		if not await _score_arrival_gap(factor_travel):
			return

	# Straßenmusiker zahlt PRO ausgelöstem Würfel: je Dock-Position ein $1-Paket,
	# im Moment des Würfel-Triggers (nicht gebündelt am Ende).
	var musician_indices: Array[int] = []
	var cids := run.charm_ids()
	for j in cids.size():
		if cids[j] == Charm.STREET_MUSICIAN:
			musician_indices.append(j)
	# Dieselbe Regel andersherum: die Abzocke kostet JE gezähltem Würfel und
	# fällt an SEINEM Schritt an, nicht gebündelt am Ende.
	var die_fee := run.scored_die_fee()

	# 3) Würfel-Schritte in Reihen-Ordnung: je Aktivierung Augen + Material,
	# dann die würfelgebundenen Charms DIESES Würfels (additiv, dann Krit) -
	# sie feuern mit ihm, nicht in der Charm-Phase. Alles strömt.
	for step: Dictionary in breakdown["die_steps"]:
		var slot: int = step["slot"]
		_pay_street_musician(musician_indices)
		_pay_die_fees(die_fee)
		var die_px := table_screen.world_to_pixel(dice.bodies[slot].global_position)
		# Zuwachs-Zahlen steigen aus dem Podest unter dem Würfel auf.
		var gain_px := die_px
		if glow_by_slot.has(slot):
			var glow: Control = glow_by_slot[slot]
			gain_px = glow.position + glow.size / 2.0
		if not await _play_die_step(step, slot, die_px, gain_px, glow_by_slot):
			return
		# Ursache→Wirkung geschlossen: das Podest dimmt bei Ankunft.
		if glow_by_slot.has(slot):
			_dim_glow(glow_by_slot[slot])

	# 4) Charm-Schritte strikt in Besitz-Reihenfolge (Boni UND Faktoren an ihrer
	# Position): je Komet vom Dock-Pad in die betroffene Zahl.
	for step: Dictionary in breakdown["charm_steps"]:
		# Schutzgeld: die Gebühr fällt an SEINEM Schritt an, nie über die Kasse
		# hinaus - Basis und Mult rührt sie nicht an.
		var fee := int(step.get("fee", 0))
		if fee > 0:
			run.add_money(-mini(fee, run.money))
		# Rampenlicht: wertet nicht, hebt an SEINER Position die Kombination.
		if step.get("spotlight", false):
			if not await _play_spotlight_step(step, String(breakdown["key"])):
				return
			continue
		# Pro-Würfel-Charms: ein Meteor je ausgelöstem Würfel (Bodensatz & Co.).
		if step.has("pulses") and not step["pulses"].is_empty():
			if not await _play_charm_pulses(step):
				return
			continue
		# Krits inszenieren sich selbst: heißer Komet, Hit-Stop, Einschlag.
		if float(step.get("crit_x", 1.0)) > 1.0:
			if not await _play_crit_step(step):
				return
			continue
		for charm_index: int in step["charm_indices"]:
			_flash_charm_and_pad(charm_index)
		var source_px := _charm_trail_source_px(step["charm_indices"])
		var ctargets: Array[String] = []
		if step["base_add"] != 0 or step["base_x"] != 1:
			ctargets.append("base")
		if step["mult_add"] != 0 or not is_equal_approx(float(step["mult_x"]), 1.0):
			ctargets.append("mult")
		var cbase: int = step["base_after"]
		var cmult: float = step["mult_after"]
		_spawn_score_gains(source_px, step["base_add"], step["mult_add"], step["base_x"], step["mult_x"])
		var charm_travel := 0.0
		if not ctargets.is_empty():
			charm_travel = _fire_score_light(source_px, "charm", ctargets,
				func() -> void: table_screen.update_pit_score(cbase, cmult))
		if not await _score_arrival_gap(charm_travel):
			return

	# 4b) Rampenlicht AUS EINER KLAUSEL hat keinen Charm im Dock, also auch keinen
	# Charm-Schritt, an dem es sich einlösen könnte - es bekommt seinen eigenen.
	# claim_spotlight ist je Runde einmalig, ein Charm-Rampenlicht von oben hat
	# hier also schon kassiert und dieser Aufruf läuft ins Leere.
	if not await _play_clause_spotlight(String(breakdown["key"])):
		return

	# 5) Auf alle fliegenden Kometen warten, dann zu Basis × Mult verschmelzen.
	if not await _wait_score_comets():
		return
	# Überheiß, wenn diese Hand eine neue Überladungs-Stufe knackt.
	var clears_goal := run.stages_cleared(new_total) > run.stages_cleared(hand_total)
	# Verschmelzungs-Zeremonie (Aufladen→Umkreisen→Hit-Stop→Einschlag→Halten):
	# genau ihre Gesamtdauer abwarten, dann weiter.
	var merge_dur := table_screen.merge_orbs(breakdown["merge_total"], clears_goal)
	if not await _score_step_wait(merge_dur):
		return

	# 6) Nach-Schritte arbeiten auf der Gesamtzahl - Kometen vom Dock in die Summe.
	for step: Dictionary in breakdown["post_steps"]:
		for charm_index: int in step["charm_indices"]:
			_flash_charm_and_pad(charm_index)
		var post_source := _charm_trail_source_px(step["charm_indices"])
		var total_after: int = step["total_after"]
		_spawn_total_gain(post_source, step["total_add"], step["total_x"])
		var post_travel := _fire_score_light(post_source, "charm", ["total"],
			func() -> void: table_screen.update_pit_total(total_after, clears_goal))
		if not await _score_arrival_gap(post_travel):
			return
	if not await _wait_score_comets():
		return

	# 7) Drain: der Gesamt-Orb schrumpft in den Balken, der Balken füllt 1:1 mit -
	# an jeder Überladungs-Schwelle hält beides kurz inne (magnitude-abhängig).
	await _drain_total_to_goal(displayed_points, new_total)
	_cleanup_take_animation()

## Straßenmusiker: je besessenem Exemplar ein $1-Chip-Paket vom Dock-Pad zur
## Bank, gebucht bei Ankunft (Phase SCORING trägt die Zähl-Animation). Feuert
## einmal pro ausgelöstem Würfel - der stetige Zufluss folgt dem Zählen.
func _pay_street_musician(musician_indices: Array[int]) -> void:
	for j in musician_indices:
		_flash_charm_and_pad(j)
		_fire_charm_money_packet(_charm_trail_source_px([j]), 1, Phase.SCORING)

## Der Verlust EINES gezählten Würfels: die Abzocke-Klausel. Gebucht im Moment
## seines Zähl-Schritts (die Ausgabe-Animation läuft von selbst), nie über den
## Kassenstand hinaus.
func _pay_die_fees(die_fee: int) -> void:
	if die_fee > 0:
		run.add_money(-mini(die_fee, run.money))

## Würfel-Schritt: jede Auslösung als eigene Kette Würfel-Puls (Augen+Material)
## -> Charm-Anteil (würfelgebundene Charms, Komet vom Dock-Pad) -> Krit-Schläge
## (Material, Essenz), mit eigener Ankunftspause je Glied - so ist das Mehrfach-Auslösen
## (Quecksilber, Retrigger-Charms, Echo-Kammer) als Verzahnung sichtbar.
## false = Abbruch (Reset).
func _play_die_step(step: Dictionary, slot: int, die_px: Vector2, gain_px: Vector2, glow_by_slot: Dictionary) -> bool:
	# Je Würfel-Trigger erst seine Seiten-Zündungen, dann die Pointer, die für
	# ihn gezündet hat - ein danebengegangener Wurf zeigt schlicht nichts.
	for group: Dictionary in step["die_triggers"]:
		for pulse: Dictionary in group["firings"]:
			if not await _play_die_pulse(pulse, slot, die_px, gain_px, glow_by_slot,
					step["eye_charm_indices"]):
				return false
		if not await _play_die_links(group["links"], slot, die_px, gain_px, glow_by_slot):
			return false
	# Runen-Glieder (Kehrseite) zuletzt - sie hängen am ganzen Würfel.
	if not await _play_die_links(step.get("det_links", []), slot, die_px, gain_px, glow_by_slot):
		return false
	# LADUNG: das Urteil des Würfels NACH seiner letzten Zündung, vor dem nächsten.
	_play_charge_beat(step.get("charge_step", {}), slot)
	return true

## Glieder-Pulse eines Würfel-Schritts: das Netz-Feld zeigt den Würfel mit dem
## GLIED im Gold-Rahmen - so wandert die Kette sichtbar. false = Abbruch (Reset).
func _play_die_links(links: Array, slot: int, die_px: Vector2, gain_px: Vector2, glow_by_slot: Dictionary) -> bool:
	for link: Dictionary in links:
		if slot < active_kinds.size():
			_show_pit_net(active_kinds[slot], int(link["face"]))
		if not await _play_die_pulse(link, slot, die_px, gain_px, glow_by_slot, []):
			return false
	return true

## Eine Auslösung des Würfel-Schritts - Aktivierung ODER Pointer-Glied:
## Augen+Material-Komet, dann Charm-Anteil vom Dock-Pad, dann JEDER Krit als
## eigener Schlag (crit_steps). false = Abbruch (Reset).
func _play_die_pulse(pulse: Dictionary, slot: int, die_px: Vector2, gain_px: Vector2, glow_by_slot: Dictionary, eye_charm_indices: Array) -> bool:
	var die_charm_indices: Array = pulse.get("die_charm_indices", [])
	_flash_scoring_die(slot)
	# Geld, das DIESE Zündung erzeugt, fliegt sofort los - eine Neon-Seele mit
	# zwei Auslösungen zahlt ihr erstes Paket vor ihrer zweiten Zündung.
	_fire_die_money(die_px, int(pulse.get("money", 0)))
	if glow_by_slot.has(slot):
		_pulse_glow(glow_by_slot[slot])
	for charm_index: int in eye_charm_indices:
		_flash_charm_and_pad(charm_index)
	var p_base: int = pulse["base_after"]
	var p_mult: float = pulse["mult_after"]
	var ptargets: Array[String] = ["base"]
	if int(pulse["mult_add"]) != 0:
		ptargets.append("mult")
	_spawn_score_gains(gain_px, int(pulse["base_add"]), int(pulse["mult_add"]))
	var travel := _fire_score_light(die_px, "pit", ptargets,
		func() -> void: table_screen.update_pit_score(p_base, p_mult))
	if not await _score_arrival_gap(travel):
		return false
	# Würfelgebundene Charms: der Anteil DIESER Auslösung vom Dock-Pad.
	var pc_base := int(pulse["charm_base_add"])
	var pc_mult := int(pulse["charm_mult_add"])
	if pc_base != 0 or pc_mult != 0:
		var pca_base: int = pulse["charm_base_after"]
		var pca_mult: float = pulse["charm_mult_after"]
		var pctargets: Array[String] = []
		if pc_base != 0:
			pctargets.append("base")
		if pc_mult != 0:
			pctargets.append("mult")
		for charm_index: int in die_charm_indices:
			_flash_charm_and_pad(charm_index)
		var pcharm_px := _charm_trail_source_px(die_charm_indices)
		_spawn_score_gains(pcharm_px, pc_base, pc_mult)
		var ctravel := _fire_score_light(pcharm_px, "charm", pctargets,
			func() -> void: table_screen.update_pit_score(pca_base, pca_mult))
		if not await _score_arrival_gap(ctravel):
			return false
	# Krit-Schläge dieser Auslösung, EINZELN: der Würfel blitzt je Schlag erneut,
	# dann schlägt der heiße Komet am Mult ein (Hit-Stop, Stoßwellen). Ein veredelter
	# Rubin im Härteofen schlägt darum zweimal ×2 statt einmal ×4.
	for crit: Dictionary in pulse.get("crit_steps", []):
		var crit_x := float(crit["crit_x"])
		var crit_indices: Array = crit["charm_indices"]
		_flash_scoring_die(slot)
		for charm_index: int in crit_indices:
			_flash_charm_and_pad(charm_index)
		# Material- und Essenz-Krit haben kein Dock-Pad - sie kommen vom Würfel.
		var from_die: bool = crit["from_die"]
		var crit_px := die_px if from_die else _charm_trail_source_px(crit_indices)
		# Trinkgeldglas: der Einschlag zahlt bar, aus demselben Punkt, aus dem er kommt.
		_fire_die_money(crit_px, int(crit.get("tip_money", 0)))
		# Grubengas zündet MIT dem Krit - seine Basis steht schon im Stand danach.
		var crit_base: int = crit["base_after"]
		var crit_mult: float = crit["mult_after"]
		var firedamp_add := int(crit.get("firedamp_add", 0))
		if firedamp_add != 0:
			table_screen.spawn_gain_number(crit_px, "+%d" % firedamp_add, table_screen.TRAIL_BASE_COLOR)
		table_screen.spawn_gain_number(crit_px, ScoreBreakdown.format_mult(crit_x), TableScreen.CRIT_COLOR, 1.2)
		var crit_travel := _fire_score_light(crit_px, "pit" if from_die else "charm", ["mult"],
			func() -> void: table_screen.crit_pit_mult(crit_base, crit_mult, crit_x),
			TableScreen.CRIT_COLOR)
		if not await _score_arrival_gap(crit_travel):
			return false
		if not await _score_step_wait(CRIT_HOLD):
			return false
	# Knochen/Glas wandeln die Seite ZWISCHEN den Auslösungen: die Ziffer auf dem
	# Würfel zieht nach, damit die nächste Auslösung sichtbar den neuen Wert zählt.
	if pulse.has("value_after"):
		_play_eye_pips(pulse, slot, die_px)
	return true

# --- Die LADESÄULE ----------------------------------------------------------------
# Die Reparatur-Station ist ein KÖRPER (ChargingColumnView, 2026-09-07; die 2D-Bucht
# RepairBayView ist mit ihr gestorben). Gebucht wird in GameRun, SOFORT beim Klick;
# erst danach fliegt das Licht. Die Säule selbst bucht nichts - sie MELDET.

## Zieht die Säule nach (Kunde, Bremsen, Preise) - idempotent, sie schreibt nur bei
## echtem Wechsel um.
func _refresh_charging_column() -> void:
	if charging_column == null or not is_instance_valid(charging_column):
		return
	# Der Kunde kommt vom PODEST: wer dort STEHT (nicht wer gewählt ist und noch
	# fliegt), wird repariert, geladen oder abgeleitet - und wer den Vorrat verlassen
	# hat, ist keiner mehr.
	var die := _bench_die
	if run != null and die != null and not run.owned_pool.has(die):
		die = null
	charging_column.set_customer(die)
	var open := not _dice_editing_locked()
	charging_column.set_live(RepairRules.charge_live(run, die, open),
		RepairRules.drain_live(run, die, open),
		RepairRules.repair_live(run, die, open))
	charging_column.set_prices(run)

func _connect_charging_column() -> void:
	if charging_column == null \
			or charging_column.repair_requested.is_connected(_on_repair_requested):
		return
	charging_column.repair_requested.connect(_on_repair_requested)
	charging_column.drain_requested.connect(_on_drain_requested)
	charging_column.charge_requested.connect(_on_charge_requested)

## Der GRIFF je Bild: der Zeiger liegt auf dem Tisch, ein mouse_entered erreicht
## einen Körper nie. Bedient wird, wo die Säule zu SEHEN ist - eigene Station und
## Freikamera (die Griff-Grammatik der Körper).
func _sync_charging_column() -> void:
	if charging_column == null or not is_instance_valid(charging_column):
		return
	_refresh_charging_column()
	if not _charging_column_live():
		charging_column.set_hovered(ChargingColumnView.PART_NONE)
		return
	charging_column.set_hovered(
		_charging_column_part(get_viewport().get_mouse_position()))

func _charging_column_live() -> bool:
	return _table_operable() and not _deck_glass \
		and _felt_pick_live(CameraRig.Mode.REPAIR)

## Welches Bedienelement liegt unter dem Zeiger ("" = keines)? Ein totes Element hat
## seine Kollision abgeschaltet, fängt den Strahl also gar nicht erst.
func _charging_column_part(screen_pos: Vector2) -> String:
	var hit := _ray_pick(screen_pos, ChargingColumnView.PICK_LAYER)
	if hit.is_empty():
		return ChargingColumnView.PART_NONE
	return ChargingColumnView.part_of(hit.collider)

## Der Druck auf Hebel oder Sicherung (true = verbraucht). Aus der Übersicht fällt er
## durch und wird zum FLUG auf die Station (die Klickzone darunter).
func _forward_charging_column_mouse(event: InputEventMouse) -> bool:
	if charging_column == null or not is_instance_valid(charging_column) \
			or not _charging_column_live():
		return false
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	var part := _charging_column_part(button.position)
	if part == ChargingColumnView.PART_NONE or not charging_column.press(part):
		return false
	charging_column.throw_lever(part)  # das Kippen ist Anzeige, gebucht ist längst
	return true

func _on_repair_requested(die: DieDefinition) -> void:
	if run == null:
		return
	var price := run.repair_price()
	if not run.repair_die(die):
		return
	# Die Asche fällt bei der ANKUNFT des Lichts - gebucht ist sie längst.
	if price.has("money"):
		_fly_repair_money(die)
	else:
		_fly_repair_energy(die)

func _on_drain_requested(die: DieDefinition) -> void:
	if run == null or not run.drain_die(die):
		return
	_fly_repair_money(die)

func _on_charge_requested(die: DieDefinition) -> void:
	if run == null or not run.charge_die(die):
		return
	_fly_repair_energy(die)

## Die SPITZE der Säule in Display-Pixeln - dort schlägt das Licht ein.
func _charging_column_px() -> Vector2:
	if charging_column == null or not is_instance_valid(charging_column) \
			or table_screen == null:
		return Vector2.ZERO
	return table_screen.world_to_pixel(charging_column.head_point())

## ⚡ aus der KONDENSATORBANK zur Säule - dieselbe Börse, aus der das Übertakten
## zahlt. Bei Ankunft pulst die Bank, dann läuft das Licht das KABEL entlang.
func _fly_repair_energy(die: DieDefinition) -> void:
	var guard := run
	var travel := table_screen.energy_comet(_charging_column_px(), CasinoStyle.ENERGY) \
		if table_screen != null else 0.0
	if travel > 0.0:
		await get_tree().create_timer(travel).timeout
	if run != guard:
		return
	if capacitor_bank != null and is_instance_valid(capacitor_bank):
		capacitor_bank.pulse()
	await _fly_column_to_die(die, CasinoStyle.ENERGY)

## Geld aus dem SCHATZ zur Säule (Ableiten, Isolierband-Reparatur).
func _fly_repair_money(die: DieDefinition) -> void:
	var guard := run
	var travel := table_screen.money_comet(false, TableScreen.SIDE_MONEY_COLOR) \
		if table_screen != null else 0.0
	if travel > 0.0:
		await get_tree().create_timer(travel).timeout
	if run != guard:
		return
	await _fly_column_to_die(die, TableScreen.SIDE_MONEY_COLOR)

## Die zweite Etappe: ein kurzer Lauf über das KABEL von der Säule zum Podest-
## Würfel. Bei SEINER Ankunft blitzt der Würfel - der Stand steht längst.
func _fly_column_to_die(die: DieDefinition, color: Color) -> void:
	var guard := run
	if charging_column != null and is_instance_valid(charging_column):
		charging_column.pulse()
	var from_px := _charging_column_px()
	var to_px := _bench_die_px()
	var travel := 0.0
	if table_screen != null and from_px != Vector2.ZERO and to_px != Vector2.ZERO:
		travel = table_screen.press_meteor(from_px, to_px, color)
	if travel > 0.0:
		await get_tree().create_timer(travel).timeout
	if run != guard:
		return
	_flash_repaired_die(die)

## Der Podest-Würfel in Display-Pixeln (Vector2.ZERO = keiner steht dort).
func _bench_die_px() -> Vector2:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	if workshop == null or not is_instance_valid(workshop):
		return Vector2.ZERO
	var center := workshop.target_net_center()
	if center.x < 0.0:
		return Vector2.ZERO
	return Vector2(center.x, workshop.target_projector_y())

## Der Blitz am Würfel: er zeigt den GEBUCHTEN Stand längst, das Licht quittiert
## ihn nur. Der Kunde steht auf dem PODEST (sein Pool-Sitz ist leer); ein Würfel
## ohne Körper bleibt still.
func _flash_repaired_die(die: DieDefinition) -> void:
	if die == null:
		return
	if bench_stage != null and is_instance_valid(bench_stage) and bench_stage.def == die \
			and bench_stage.faces != null and is_instance_valid(bench_stage.faces):
		bench_stage.faces.flash_charge(CHARGE_FLASH_STRENGTH)
		return
	if pool_tray_view == null:
		return
	for i in pool_tray_view.slot_defs.size():
		if pool_tray_view.slot_defs[i] != die:
			continue
		var display: DieFaceDisplay = pool_tray_view.slot_face_displays[i]
		if display != null:
			display.flash_charge(CHARGE_FLASH_STRENGTH)

## Das ENTLADEN am Rundenende: die betroffenen Vorrats-Würfel zeigen kurz ihre
## ALTE Stufe (gebucht ist die neue längst), blitzen gedimmt in Ladungsfarbe und
## fallen dann auf den gebuchten Stand zurück. Steht der Vorrat nicht im Bild,
## spielt nichts - eine Maschine, die keiner sieht, hat nicht gespielt.
func _play_cooling_ceremony(defs: Array[DieDefinition]) -> void:
	if defs.is_empty() or pool_tray_view == null or not pool_tray_view.visible:
		return
	var guard := run
	var lit: Array[DieFaceDisplay] = []
	for i in pool_tray_view.slot_defs.size():
		var def: DieDefinition = pool_tray_view.slot_defs[i]
		if def == null or not defs.has(def):
			continue
		var display: DieFaceDisplay = pool_tray_view.slot_face_displays[i]
		if display == null:
			continue
		display.set_charge_override(mini(def.charge + 1, DieDefinition.CHARGE_MAX), false)
		display.flash_charge(COOLING_FLASH_STRENGTH)
		lit.append(display)
	if lit.is_empty():
		return
	await get_tree().create_timer(COOLING_TIME).timeout
	if run != guard:
		return
	for display in lit:
		if is_instance_valid(display):
			display.clear_charge_override()

## Das Ladungs-URTEIL eines Würfels nach seiner letzten Zündung (charge_step),
## rein visuell: der Override zeigt den Stand der Aufschlüsselung - der GEBUCHTE
## steht schon in der Def und übernimmt am Ende der Zeremonie
## (clear_charge_override). Ein abgebrochener Tween schuldet damit nichts.
func _play_charge_beat(beat: Dictionary, slot: int) -> void:
	if beat.is_empty() or slot < 0 or slot >= dice.count():
		return
	var display: DieFaceDisplay = dice.face_displays[slot]
	if display == null:
		return
	# Lichtbogen: sein Pad blitzt mit dem Durchbrennen.
	for charm_index: int in beat.get("charm_indices", []):
		_flash_charm_and_pad(charm_index)
	if bool(beat.get("burned", false)):
		# DIE DURCHBRENN-ZEREMONIE: Einschlag in die Grubenwände, der Rundenpuls
		# stottert wie beim Fumble, dann fällt der Würfel dunkel.
		if dice_pit != null:
			dice_pit.slam(CHARGE_BURN_SLAM)
		if table_screen != null:
			table_screen.pit_flinch()
		display.set_charge_override(0, true)
		return
	display.set_charge_override(int(beat.get("charge_after", 0)), false)
	display.flash_charge(CHARGE_FLASH_STRENGTH)

## Nach der Zeremonie: der Def-Stand übernimmt an JEDEM Grubenwürfel.
func _clear_charge_overrides() -> void:
	for i in dice.count():
		var display: DieFaceDisplay = dice.face_displays[i]
		if display != null:
			display.clear_charge_override()

## Augen-Pips einer Zündung. Drei Volleys im PHYSISCHEN Bereich: erst die eigene
## Wandlung (Knochen wächst, Glas schrumpft, Helium hebt), dann der Miasma-
## Aushauch samt Weitergabe, zuletzt die Radon-Bestrahlung. value_after ist um den
## Eigenverlust schon gemindert, der Stand davor liegt also um ihn höher. Die
## Bestrahlung ist der Weihrauchfass-Fall: nichts fällt heraus, die Empfänger
## bekommen trotzdem. Nie abgewartet; kommt kein Pip zustande, setzt die Ziffer
## hart um - die Anzeige hängt nie an der Animation.
func _play_eye_pips(pulse: Dictionary, slot: int, die_px: Vector2) -> void:
	var after := int(pulse["value_after"])
	var before := int(pulse.get("value_before", after))
	var amount := int(pulse.get("miasma_amount", 0))
	var self_loss := int(pulse.get("miasma_self_loss", 0))
	var recipients: Array = pulse.get("miasma_recipients", [])
	var post_mutate := after + self_loss
	var launches := 0
	if _eye_pips_available():
		if post_mutate > before:
			launches += _rain_eyes_in(slot, before, post_mutate, TableScreen.EYE_PIP_COLOR, 0.0, die_px)
		elif post_mutate < before:
			launches += _drop_eyes_out(slot, before, post_mutate, TableScreen.EYE_PIP_LOSS_COLOR, 0.0, [], die_px)
		if amount > 0:
			var offset := float(launches) * TableScreen.EYE_PIP_GAP
			var tint := _miasma_pip_color()
			if self_loss > 0:
				# Der Aushauch fällt heraus; jeder Aufschlag trägt ihn weiter.
				launches += _drop_eyes_out(slot, post_mutate, after, tint, offset, recipients, die_px)
			else:
				# Weihrauchfass: nichts fällt heraus, angesteckt wird trotzdem.
				launches += _rain_miasma_gift(recipients, amount, tint, offset)
		var radon := int(pulse.get("radon_amount", 0))
		if radon > 0:
			launches += _rain_miasma_gift(pulse.get("radon_recipients", []), radon,
				_radon_pip_color(), float(launches) * TableScreen.EYE_PIP_GAP)
	if launches == 0:
		_tick_die_value(slot, after, _plan_eye_tick(slot, after), run)

## Pips brauchen die Grube - ohne sichtbares Fenster gibt es keine Kante, von der
## sie fallen könnten.
func _eye_pips_available() -> bool:
	return table_screen != null and table_screen.pit_window != null and table_screen.pit_window.visible

## Miasma-Pips tragen das Glühen ihrer Seele; einmal geholt, Essence.by_id baut
## sonst je Zündung den ganzen Katalog.
func _miasma_pip_color() -> Color:
	if _miasma_glow.a <= 0.0:
		_miasma_glow = Essence.glow_for(Essence.MIASMA)
		_miasma_glow.a = 1.0
	return _miasma_glow

## Dasselbe für die Bestrahlung - gemerkt aus demselben Grund.
func _radon_pip_color() -> Color:
	if _radon_glow.a <= 0.0:
		_radon_glow = Essence.glow_for(Essence.RADON)
		_radon_glow.a = 1.0
	return _radon_glow

## Gewonnene Augen regnen von der Grubendecke in den Würfel. Jede Ankunft setzt
## den ABSOLUTEN Zwischenstand - relative Schritte liefen bei verschränkten
## Volleys auseinander, absolute treffen am Ende genau das Ziel. Liefert die Zahl
## der gestarteten Pips.
func _rain_eyes_in(slot: int, start_value: int, target_value: int, color: Color, delay: float, die_px: Vector2) -> int:
	var pips := TableScreen.split_eyes(target_value - start_value)
	if pips.is_empty():
		return 0
	var launched := run
	var running := start_value
	for i in pips.size():
		var denom: int = pips[i]
		running += denom
		var value := running
		var seq := _plan_eye_tick(slot, value)
		var from_px := Vector2(die_px.x + _eye_pip_jitter(), table_screen.pit_ceiling_y())
		_launch_eye_pip(delay + float(i) * TableScreen.EYE_PIP_GAP, func() -> void:
			table_screen.spawn_eye_pip(from_px, die_px, denom, color, func() -> void:
				_tick_die_value(slot, value, seq, launched)))
	return pips.size()

## Verlorene Augen fallen AUS dem Würfel auf den Grubenboden: die Ziffer sinkt im
## Moment des Abwurfs (das Auge verlässt den Würfel), der Aufschlag schlägt eine
## Welle. Mit Empfängern trägt jeder Aufschlag seine Stückelung an JEDEN anderen
## gewerteten Würfel weiter - der Dunst geht nicht verloren.
func _drop_eyes_out(slot: int, start_value: int, target_value: int, color: Color, delay: float, recipients: Array, die_px: Vector2) -> int:
	var pips := TableScreen.split_eyes(start_value - target_value)
	if pips.is_empty():
		return 0
	var launched := run
	var running := start_value
	for i in pips.size():
		var denom: int = pips[i]
		running -= denom
		var value := running
		var seq := _plan_eye_tick(slot, value)
		# Die Weitergabe wird HIER geplant, nicht erst beim Aufschlag: nur so steht
		# sie in der Reihenfolge vor den Ticks der nächsten Zündung.
		var relay := _plan_miasma_relay(recipients, denom)
		var floor_x := die_px.x + _eye_pip_jitter()
		var to_px := Vector2(floor_x, table_screen.pit_floor_y(floor_x))
		_launch_eye_pip(delay + float(i) * TableScreen.EYE_PIP_GAP, func() -> void:
			_tick_die_value(slot, value, seq, launched)
			table_screen.spawn_eye_pip(die_px, to_px, denom, color, func() -> void:
				if run != launched or phase != Phase.SCORING:
					return
				table_screen.pit_impulse(to_px, "base", color)
				_fly_miasma_relay(relay, denom, color, launched)))
	return pips.size()

## Plant die Weitergabe EINES Aufschlags: je anderem gewerteten Würfel ein Tick
## auf seinen nächsten Stand. spread_miasma_once gibt jedem den vollen Betrag,
## also bekommt jeder dieselbe Stückelung - über alle Pips summiert genau ihn.
func _plan_miasma_relay(recipients: Array, denom: int) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	for other: int in recipients:
		var value := _planned_die_value(other) + denom
		plan.append({"slot": other, "value": value, "seq": _plan_eye_tick(other, value)})
	return plan

## Fliegt die geplante Weitergabe: je Empfänger ein Pip von der Decke herab.
func _fly_miasma_relay(plan: Array, denom: int, color: Color, launched: GameRun) -> void:
	for entry: Dictionary in plan:
		var other := int(entry["slot"])
		var value := int(entry["value"])
		var seq := int(entry["seq"])
		var die_px := _die_px_for(other)
		var from_px := Vector2(die_px.x + _eye_pip_jitter(), table_screen.pit_ceiling_y())
		table_screen.spawn_eye_pip(from_px, die_px, denom, color, func() -> void:
			_tick_die_value(other, value, seq, launched))

## Weihrauchfass: die Quelle verliert nichts, die Mitwürfel bekommen trotzdem -
## ihre Augen regnen ohne Umweg herein.
func _rain_miasma_gift(recipients: Array, amount: int, color: Color, delay: float) -> int:
	var launches := 0
	for i in recipients.size():
		var other: int = recipients[i]
		var start := _planned_die_value(other)
		launches += _rain_eyes_in(other, start, start + amount, color, delay + float(i) * TableScreen.EYE_PIP_GAP, _die_px_for(other))
	return launches

## Startet einen Pip nach delay - unter derselben Wache wie die Geld-Pakete
## (noch in der Zählung, noch dieselbe Partie).
func _launch_eye_pip(delay: float, launcher: Callable) -> void:
	if delay <= 0.0:
		launcher.call()
		return
	var launched := run
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if phase == Phase.SCORING and run == launched:
			launcher.call())

## Plant EINEN Ziffern-Tick. Die laufende Nummer wird in PLANUNGS-Reihenfolge
## vergeben, also genau der Folge, in der die Zahl stehen soll - ein verspätet
## ankommender Pip einer älteren Zündung wird damit verworfen (dieselbe Monotonie
## wie _score_applied), statt die Ziffer zurückzudrehen.
func _plan_eye_tick(slot: int, value: int) -> int:
	_eye_tick_seq += 1
	_eye_planned[slot] = value
	return _eye_tick_seq

## Der Stand, auf den dieser Würfel ZULÄUFT - noch fliegende Pips eingerechnet.
func _planned_die_value(slot: int) -> int:
	return int(_eye_planned.get(slot, _current_die_display_value(slot)))

## Ein Pip schaltet die Ziffer weiter - reine Anzeige, gebucht wird ohnehin erst
## nach der Zeremonie in apply_take_effects.
func _tick_die_value(slot: int, value: int, seq: int, launched: GameRun) -> void:
	if phase != Phase.SCORING or run != launched:
		return
	if seq < int(_eye_tick_applied.get(slot, 0)):
		return
	_eye_tick_applied[slot] = seq
	_show_die_value_progress(slot, value)

## Pixelmitte eines liegenden Würfels - Start und Ziel jedes Pips.
func _die_px_for(slot: int) -> Vector2:
	if table_screen == null or slot < 0 or slot >= dice.bodies.size():
		return Vector2.ZERO
	return table_screen.world_to_pixel(dice.bodies[slot].global_position)

## Die Zahl, die der Würfel GERADE zeigt (Überschreibung schlägt die Def).
func _current_die_display_value(slot: int) -> int:
	if slot < 0 or slot >= dice.count() or slot >= dice.face_indices.size():
		return 0
	if dice.value_overrides.has(slot):
		return int(dice.value_overrides[slot])
	var face := dice.face_indices[slot]
	if face < 0 or face >= dice.slot_defs[slot].faces.size():
		return 0
	return dice.slot_defs[slot].faces[face]

func _eye_pip_jitter() -> float:
	return randf_range(-TableScreen.EYE_PIP_JITTER, TableScreen.EYE_PIP_JITTER)

## Zwischenstand des physischen Werts auf dem liegenden Würfel: normal gefärbt,
## denn die Änderung ist dauerhaft. Trifft der Wert wieder die Def, verschwindet
## die Überschreibung - nach der Zeremonie schreibt apply_take_effects dieselbe
## Zahl in die Def, der Würfel zeigt also am Ende ohnehin das Richtige.
func _show_die_value_progress(slot: int, value: int) -> void:
	if slot < 0 or slot >= dice.count() or slot >= dice.face_indices.size():
		return
	var face := dice.face_indices[slot]
	if face < 0 or face >= dice.slot_defs[slot].faces.size():
		return
	var overrides := dice.value_overrides.duplicate()
	if value == dice.slot_defs[slot].faces[face]:
		overrides.erase(slot)
	else:
		overrides[slot] = value
	dice.set_value_overrides(overrides, false)

## Spielt einen STATISCHEN Krit-Schritt (Galgenhumor, Feierabendbier, Beherit):
## der Komet läuft in Krit-Magenta vom Dock-Pad zum Mult-Orb, bei Ankunft übernimmt
## TableScreen.crit_pit_mult (Hit-Stop -> Slam mit Stoßwellen -> Beben). Der
## Extra-Halt (CRIT_HOLD) lässt den Moment atmen. Material- und Essenz-Krits
## schlagen dagegen in _play_die_step ein. false = Abbruch (Reset).
func _play_crit_step(step: Dictionary) -> bool:
	for charm_index: int in step["charm_indices"]:
		_flash_charm_and_pad(charm_index)
	var source_px := _charm_trail_source_px(step["charm_indices"])
	# Trinkgeldglas: auch der statische Krit zahlt bar, aus seinem Dock-Pad.
	_fire_die_money(source_px, int(step.get("tip_money", 0)))
	var cbase: int = step["base_after"]
	var cmult: float = step["mult_after"]
	var crit_x: float = step["crit_x"]
	var firedamp_add := int(step.get("firedamp_add", 0))
	if firedamp_add != 0:
		table_screen.spawn_gain_number(source_px, "+%d" % firedamp_add, table_screen.TRAIL_BASE_COLOR)
	table_screen.spawn_gain_number(source_px, ScoreBreakdown.format_mult(crit_x), TableScreen.CRIT_COLOR, 1.2)
	var travel := _fire_score_light(source_px, "charm", ["mult"],
		func() -> void: table_screen.crit_pit_mult(cbase, cmult, crit_x),
		TableScreen.CRIT_COLOR)
	if not await _score_arrival_gap(travel):
		return false
	return await _score_step_wait(CRIT_HOLD)

## Spielt einen pro-Würfel-Charm-Schritt als Folge von Einzel-Meteoren: je Puls
## blitzt der Charm UND sein auslösender Würfel, ein Komet fliegt vom Dock-Pad in
## Basis/Mult, der Zähler springt bei Ankunft. false = Abbruch (Reset).
func _play_charm_pulses(step: Dictionary) -> bool:
	var source_px := _charm_trail_source_px(step["charm_indices"])
	for pulse: Dictionary in step["pulses"]:
		for charm_index: int in step["charm_indices"]:
			_flash_charm_and_pad(charm_index)
		_flash_scoring_die(int(pulse["slot"]))
		var pbase: int = pulse["base_after"]
		var pmult: float = pulse["mult_after"]
		var ptargets: Array[String] = []
		if int(pulse["base"]) != 0:
			ptargets.append("base")
		if int(pulse["mult"]) != 0:
			ptargets.append("mult")
		_spawn_score_gains(source_px, int(pulse["base"]), int(pulse["mult"]))
		var ptravel := 0.0
		if not ptargets.is_empty():
			ptravel = _fire_score_light(source_px, "charm", ptargets,
				func() -> void: table_screen.update_pit_score(pbase, pmult))
		if not await _score_arrival_gap(ptravel):
			return false
	return true

## Segmentierter Drain aus from_points auf to_points: Orb-Schrumpfen und
## Balken-Füllung laufen 1:1 parallel, mit Mikro-Halt an jeder Überladungs-Schwelle.
func _drain_total_to_goal(from_points: int, to_points: int) -> void:
	if points_tween:
		points_tween.kill()
	var thresholds := run.thresholds_crossed(from_points, to_points)
	var duration := minf(DRAIN_BASE_TIME + DRAIN_PER_ROLLOVER * float(thresholds.size()), DRAIN_MAX_TIME)
	var span := maxi(1, to_points - from_points)
	var bounds: Array[int] = [from_points]
	bounds.append_array(thresholds)
	bounds.append(to_points)
	table_screen.begin_total_drain(duration)
	var drain := create_tween()
	var done := 0
	for i in range(bounds.size() - 1):
		var seg_from: int = bounds[i]
		var seg_to: int = bounds[i + 1]
		var seg_span := seg_to - seg_from
		var seg_dur := maxf(DRAIN_SEGMENT_MIN, duration * float(seg_span) / float(span))
		var frac_from := float(done) / float(span)
		done += seg_span
		var frac_to := float(done) / float(span)
		drain.tween_method(func(t: float) -> void:
			_set_displayed_points(int(round(lerpf(float(seg_from), float(seg_to), t))))
			table_screen.set_total_drain(lerpf(frac_from, frac_to, t)),
			0.0, 1.0, seg_dur)
		if i < bounds.size() - 2:  # an jeder Schwelle (nicht am Ende) kurz halten
			drain.tween_interval(DRAIN_HOLD)
	drain.tween_callback(table_screen.finish_total_drain)
	await drain.finished

## Feuert die Zähl-Kometen eines Schritts (Quelle -> Score-Leiste -> Zähler) und
## plant apply auf ihre ANKUNFT. Absolutwerte + Schritt-Index (seq) halten die
## Anzeige monoton: ein später gestarteter Schritt darf einen früheren nie
## zurücksetzen, auch wenn Kometen verschiedener Leisten anders lange brauchen.
## Feuert die Kometen und liefert ihre (längste) Laufzeit - der Aufrufer taktet
## den nächsten Schritt auf die ANKUNFT (siehe _score_arrival_gap).
func _fire_score_light(from_px: Vector2, source: String, targets: Array, apply: Callable, comet_color := Color(0, 0, 0, 0)) -> float:
	var seq := _score_seq
	_score_seq += 1
	_score_pending += 1
	var travel := 0.0
	# Würfel-Gewinne schlagen zusätzlich als Punkt-Puls in der Grube ein.
	if source == "pit":
		for t: String in targets:
			table_screen.pit_impulse(from_px, t)
	for t: String in targets:
		travel = maxf(travel, table_screen.score_comet(from_px, source, t, comet_color))
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		_score_pending = maxi(0, _score_pending - 1)
		if phase != Phase.SCORING:
			return
		if seq > _score_applied:
			_score_applied = seq
			apply.call())
	return travel

## Wartet die ANKUNFT der Kometen dieses Schritts ab (travel) und danach die
## Accelerando-Pause; false = Abbruch (Reset).
func _score_arrival_gap(travel: float) -> bool:
	if not await _score_step_wait(maxf(travel, 0.05)):
		return false
	if not await _score_step_wait(_score_gap):
		return false
	_score_gap = maxf(SCORE_STEP_GAP_MIN, _score_gap * SCORE_STEP_GAP_DECAY)
	return true

## Wartet, bis alle Zähl-Kometen angekommen sind (Verschmelzungs-Gate); false = Abbruch.
func _wait_score_comets() -> bool:
	while _score_pending > 0:
		await get_tree().create_timer(0.03).timeout
		if phase != Phase.SCORING:
			_cleanup_take_animation()
			return false
	return true

## Besitz-Slot einer WIRKUNGS-Position (Index in run.charm_ids). Hologramme und
## Dock-Pads hängen am Besitz, die Wirkungsliste kann kürzer sein.
func _charm_slot(resolved_index: int) -> int:
	var slots := run.charm_slots()
	if resolved_index < 0 or resolved_index >= slots.size():
		return -1
	return slots[resolved_index]

## Blitzt einen Charm im 3D-Hologramm UND seinem Dock-Pad ("dieser Charm feuert").
## index ist eine WIRKUNGS-Position, keine Besitz-Position.
func _flash_charm_and_pad(index: int) -> void:
	var slot := _charm_slot(index)
	if slot < 0:
		return
	charm_row.flash_charm(slot)
	if table_screen != null and table_screen.charm_dock != null:
		table_screen.charm_dock.flash_pad(slot)

## Zuwachs eines Zählschritts als schwebende Zahl aus der Quelle: "+N" bzw.
## "×N"; Basis cyan, Mult gold. Rein schmückend, zusätzlich zu den Pointern.
func _spawn_score_gains(source_px: Vector2, base_add: int, mult_add: int, base_x: int = 1, mult_x: float = 1.0) -> void:
	if base_add != 0:
		table_screen.spawn_gain_number(source_px, "+%d" % base_add, table_screen.TRAIL_BASE_COLOR)
	if base_x != 1:
		table_screen.spawn_gain_number(source_px, "×%d" % base_x, table_screen.TRAIL_BASE_COLOR)
	if mult_add != 0:
		table_screen.spawn_gain_number(source_px, "+%d" % mult_add, table_screen.TRAIL_MULT_COLOR)
	if not is_equal_approx(mult_x, 1.0):
		table_screen.spawn_gain_number(source_px, ScoreBreakdown.format_mult(mult_x), table_screen.TRAIL_MULT_COLOR)

## Zuwachs eines Nach-Schritts auf der GESAMTZAHL; ganzzahlige Faktoren als
## "×N", sonst mit einer Nachkommastelle.
func _spawn_total_gain(source_px: Vector2, total_add: int, total_x: float) -> void:
	if total_add != 0:
		table_screen.spawn_gain_number(source_px, "+%d" % total_add, PitScoreView.TOTAL_COLOR)
	if not is_equal_approx(total_x, 1.0):
		table_screen.spawn_gain_number(source_px, ScoreBreakdown.format_mult(total_x), PitScoreView.TOTAL_COLOR)

## Wartet einen Zählschritt ab; false = Animation abgebrochen (Reset) -
## dann ist hier schon aufgeräumt und der Aufrufer steigt sofort aus.
func _score_step_wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds).timeout
	if phase != Phase.SCORING:
		_cleanup_take_animation()
		return false
	return true

## Räumt die Display-Reste der Zähl-Animation weg und stellt die Daueranzeige
## still auf 0 × 0 (_refresh_ui setzt danach wieder passende Werte).
func _cleanup_take_animation() -> void:
	for glow in take_anim_glows:
		glow.queue_free()
	take_anim_glows.clear()
	_score_seq = 0
	_score_applied = -1
	_score_pending = 0
	_eye_tick_applied.clear()
	_eye_planned.clear()
	_clear_charge_overrides()
	table_screen.reset_pit_score()

## Startpunkt des Zähl-Kometen eines Charm-Schritts: das Kontakt-Pad des ersten
## beteiligten Charms im Dock (von dort läuft das Licht über die Dock-Leiste).
## Startpunkt der Charm-Kometen: das Dock-Pad des ERSTEN beteiligten Charms
## (charm_indices sind Wirkungs-Positionen, siehe _charm_slot).
func _charm_trail_source_px(charm_indices: Array) -> Vector2:
	var slot := _charm_slot(int(charm_indices[0])) if not charm_indices.is_empty() else -1
	if slot < 0 or table_screen.charm_dock == null:
		return table_screen.world_to_pixel(DicePit.PIT_CENTER)
	return table_screen.charm_dock.pad_center(slot)

## Goldener Handschlag: der Würfel wird vor aller Augen zu Gold - Ton-Sweep mit
## Pop, Blitz auf dem Höhepunkt, dann zurück auf den Ruheton. Die Seiten TRAGEN
## das Gold bereits (apply_golden_handshake hat gebucht und pool_changed
## gemeldet), die Zeremonie erzählt nur die Verwandlung. Ein Reset bricht ab und
## setzt den Ton zurück.
func _play_golden_handshake(slot: int) -> void:
	if slot < 0 or slot >= dice.count() or not dice.roots[slot].visible:
		return
	var display: DieFaceDisplay = dice.face_displays[slot]
	if display == null:
		return
	var rest: Color = DiceController.KIND_TINTS.get(dice.slot_defs[slot].style_id, Color.WHITE)
	var base_scale := Vector3.ONE * DiceTrayView.DIE_SCALE
	var sweep := create_tween()
	sweep.set_parallel(true)
	sweep.tween_method(display.set_tint, rest, CasinoStyle.GOLD_INTENSE, HANDSHAKE_SWEEP_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sweep.tween_property(display, "scale", base_scale * HANDSHAKE_SWELL, HANDSHAKE_SWEEP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await sweep.finished
	if not _handshake_alive(display, rest):
		return
	var flash := create_tween()
	flash.tween_method(display.set_tint, CasinoStyle.GOLD_INTENSE, DIE_FLASH_PEAK_COLOR, HANDSHAKE_FLASH_TIME * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash.tween_method(display.set_tint, DIE_FLASH_PEAK_COLOR, CasinoStyle.GOLD_INTENSE, HANDSHAKE_FLASH_TIME * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await flash.finished
	if not _handshake_alive(display, rest):
		return
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_method(display.set_tint, CasinoStyle.GOLD_INTENSE, rest, HANDSHAKE_SETTLE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	settle.tween_property(display, "scale", base_scale, HANDSHAKE_SETTLE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await settle.finished

## Trägt die Phase die Handschlag-Zeremonie noch? Sonst fällt der Ton sofort
## zurück, damit kein Würfel golden hängen bleibt.
func _handshake_alive(display: DieFaceDisplay, rest: Color) -> bool:
	if not is_instance_valid(display):
		return false
	if phase == Phase.SCORING:
		return true
	display.set_tint(rest)
	return false

## Lässt den Wurf-Würfel in slot golden aufblitzen (Zähl-Animation).
func _flash_scoring_die(slot: int) -> void:
	if slot < 0 or slot >= dice.count() or not dice.roots[slot].visible:
		return
	var tint: Color = DiceController.KIND_TINTS.get(dice.slot_defs[slot].style_id, Color.WHITE)
	_flash_die_tint(dice.face_displays[slot], tint, Vector3.ONE * DiceTrayView.DIE_SCALE)
	_flare_runes(slot)

## Runen-Ausbruch im Aktivierungs-Puls: der Rune flammt auf und fällt zurück auf
## sein Ruhe-Schimmern. Die Essenz glüht durchgehend weiter - die zeitliche
## Signatur trennt die beiden Licht-Systeme.
## block = der Schutz-Blitz des Einbrands (ein verhinderter Schrumpf), sonst die
## Wertungs-Bewegung des jeweiligen Runen.
func _flare_runes(slot: int, block := false) -> void:
	var display: DieFaceDisplay = dice.face_displays[slot]
	if display == null:
		return
	# NUR die obere Seite: der Rune gehört der Seite, die gewertet wird - eine
	# Seitenfläche, die mitleuchtet, behauptet eine Wirkung, die es nicht gibt.
	var face_index: int = dice.face_indices[slot] if slot < dice.face_indices.size() else -1
	display.flare_runes(1.0, face_index, block)
	var tween := create_tween()
	tween.tween_method(func(strength: float) -> void:
		if is_instance_valid(display):
			display.flare_runes(strength, face_index, block), 1.0, 0.0, RUNE_FLARE_TIME)
	# Die Grubenkarte blitzt im selben Takt mit, sofern sie diesen Würfel zeigt.
	if table_screen != null and slot < dice.slot_defs.size():
		table_screen.flare_pit_runes(dice.slot_defs[slot], face_index, RUNE_FLARE_TIME)

## Kleiner Größen-Pop eines Goldlichts, wenn sein Würfel gezählt wird.
func _pulse_glow(glow: Control) -> void:
	glow.scale = Vector2.ONE * 1.35
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "scale", Vector2.ONE, 0.3)

## Dimmt das Podest eines Würfels bei Ankunft seines Kometen (Ursache→Wirkung).
func _dim_glow(glow: Control) -> void:
	var tween := create_tween()
	tween.tween_property(glow, "modulate:a", 0.3, 0.2)

## Markiert nach jedem Wurf automatisch die Würfel der besten offenen
## Kombination - ein Vorschlag, den der Spieler frei umklicken kann. Erkannt wird
## über die LIEGENDEN Würfel: leere Slots (ausgespielter Rest-Pool) haben keinen
## Wert, den man werten könnte.
func _auto_select_best_combo() -> void:
	for slot in _pit_combination_slots():
		dice.set_selected(slot, true)

## Slot-Indizes der AUSGEWÄHLTEN, sichtbaren Würfel - NUR sie bilden die Hand
## (Kombination + Basispunkte); Abgewähltes zählt nicht.
func _scoring_slots() -> Array[int]:
	var slots: Array[int] = []
	for i in dice.count():
		if dice.selected[i] and dice.roots[i].visible:
			slots.append(i)
	return slots

## Alle sichtbaren Würfel in der Grube (Auswahl egal) - Basis für Vollzähler.
func _visible_pit_slots() -> Array[int]:
	var slots: Array[int] = []
	for i in dice.count():
		if dice.roots[i].visible:
			slots.append(i)
	return slots

## Die als Hand gewerteten Slots: normal die ausgewählten, mit Vollzähler ALLE
## liegenden Würfel (dann zählt die Auswahl nicht - jeder Würfel in der Grube
## geht in die Wertung).
func _hand_slots() -> Array[int]:
	if run != null and run.charm_ids().has(Charm.FULL_COUNTER):
		return _visible_pit_slots()
	var slots := _scoring_slots()
	# Krypton zählt immer mit: er kommt auch ungewählt in die Hand, sonst erreicht
	# ihn die Wertung gar nicht. Aufsteigend, wie jede Slot-Liste hier.
	var sets := _effective_essence_sets()
	if sets.is_empty():
		return slots
	var widened: Array[int] = []
	for i in dice.count():
		if slots.has(i):
			widened.append(i)
		elif dice.roots[i].visible and EssenceEffects.always_scored_of(sets, i):
			widened.append(i)
	return widened

## Beteiligte Slots der besten Hand über ALLE liegenden Würfel (Vollzähler-Glow:
## diese leuchten hell, der Rest der Grube nur schwach).
func _pit_combination_slots() -> Array[int]:
	var slots := _visible_pit_slots()
	if slots.is_empty():
		return []
	var ids := run.charm_ids()
	var materials := _rolled_materials()
	var sel_values: Array[int] = []
	var sel_materials: Array[String] = []
	for s in slots:
		sel_values.append(dice.values[s])
		sel_materials.append(materials[s])
	var hand := DiceScoring.best_hand(sel_values, ids, hands_taken_this_round == 0, sel_materials, run.combo_levels, _score_ctx_for_slots(slots))
	var result: Array[int] = []
	for p in DiceScoring.participating_indices(hand["key"], sel_values, ids, _score_ctx_for_slots(slots)):
		result.append(slots[p])
	return result

## Rechnet die Indizes einer über den Auswahl-Teilwurf gebauten Schrittliste
## auf echte Würfel-Slots zurück - so leuchten die richtigen Würfel auf.
func _remap_breakdown_to_slots(breakdown: Dictionary, slots: Array[int]) -> void:
	var mapped_eyes: Array[int] = []
	for idx: int in breakdown["eye_slots"]:
		mapped_eyes.append(slots[idx])
	breakdown["eye_slots"] = mapped_eyes
	var mapped_part: Array[int] = []
	for idx: int in breakdown["participating"]:
		mapped_part.append(slots[idx])
	breakdown["participating"] = mapped_part
	for step: Dictionary in breakdown["die_steps"]:
		step["slot"] = slots[step["slot"]]
		# Die Ansteckung nennt ihre Empfänger ebenfalls in Auswahl-Indizes -
		# die Augen-Pips fliegen sonst auf fremde Würfel zu.
		for group: Dictionary in step["die_triggers"]:
			for firing: Dictionary in group["firings"]:
				if not firing.has("miasma_recipients"):
					continue
				var mapped: Array[int] = []
				for idx: int in firing["miasma_recipients"]:
					mapped.append(slots[idx])
				firing["miasma_recipients"] = mapped
	# LADUNG: END-Stände und Durchbrenner nennen ebenfalls Auswahl-Indizes.
	var mapped_charges := {}
	var charges: Dictionary = breakdown.get("charges_after", {})
	for idx in charges:
		mapped_charges[slots[int(idx)]] = int(charges[idx])
	breakdown["charges_after"] = mapped_charges
	var mapped_burned: Array[int] = []
	for idx: int in breakdown.get("burned_after", []):
		mapped_burned.append(slots[idx])
	breakdown["burned_after"] = mapped_burned
	# Auch die Pro-Würfel-Pulse tragen Auswahl-Indizes - auf echte Slots umrechnen.
	for step: Dictionary in breakdown["charm_steps"]:
		if step.has("pulses"):
			for pulse: Dictionary in step["pulses"]:
				pulse["slot"] = slots[int(pulse["slot"])]

func _on_reset_button_pressed() -> void:
	_reset_game()

## Testmodus umschalten: An = zufällige Materialien UND Seelen auf allen
## Würfeln + unbegrenzte Gravuren (KEINE Charms); Aus = beides entfernen.
## Beides startet die Runde neu, damit die Änderung sofort sichtbar ist.
func _on_test_materials_pressed() -> void:
	test_materials_enabled = not test_materials_enabled
	if not test_materials_enabled:
		run.clear_all_materials()
		run.clear_all_essences()
	_refresh_test_materials_button()
	_start_new_round()

## Beschriftung des Testmodus-Knopfs (2D-Rückfall UND Hub-Menü).
func _refresh_test_materials_button() -> void:
	var label := "🧪 Testmaterialien: %s" % ("AN" if test_materials_enabled else "aus")
	if test_materials_button != null:
		test_materials_button.text = label
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_test_materials_label(label)

## Pointer-Testmodus umschalten: An = 1-5 zufällige Pointer auf allen
## Würfeln; Aus = alle entfernen. Wie die Materialien startet es die Runde neu.
func _on_test_pointers_pressed() -> void:
	test_pointers_enabled = not test_pointers_enabled
	if not test_pointers_enabled:
		run.clear_all_pointers()
	_refresh_test_pointers_button()
	_start_new_round()

func _refresh_test_pointers_button() -> void:
	var label := "🧪 Testpointer: %s" % ("AN" if test_pointers_enabled else "aus")
	if test_pointers_button != null:
		test_pointers_button.text = label
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_test_pointers_label(label)

## Testlieferung: TEST_PACK_COUNT Datenkarten je Sorte ins Regal - Zahlen,
## Material, Runen und der Sonderbestand, aber KEINE Würfel-Pakete (die ändern
## den Pool und damit den ganzen Lauf). Rührt die Würfel nicht an, darum auch
## kein Rundenneustart; mehrfaches Drücken legt nach.
func _on_test_engravings_pressed() -> void:
	if run == null:
		return
	var delivery: Array[Pack] = []
	for i in TEST_PACK_COUNT:
		delivery.append(Pack.number_pack())
		delivery.append(Pack.material_pack())
		delivery.append(Pack.dice_mod_pack())
		for special_id in Engraving.SPECIAL_IDS:
			var special := Engraving.by_id(String(special_id))
			if special != null:
				delivery.append(Pack.fixed_engraving_pack(special))
	run.grant_packs(delivery)

func _reset_game() -> void:
	phase = Phase.IDLE  # bricht auch laufende Wurf-/Zähl-Koroutinen ab
	_cancel_deck_shift()
	_cancel_reorder_drag()
	_cancel_charm_drag()
	_cancel_lineup()
	_cleanup_take_animation()
	_reset_tray_stage_hard()  # Ablage, Löcher und alle drei Maschinen des alten Laufs
	dice_shell.reset_to_post()
	hand_note = ""
	last_throw_was_reroll = false
	momentum_streak = 0
	rerolls_this_hand = 0
	pendulum_acc = 0  # Pendel überlebt Runden, aber nicht einen neuen Run
	_pendulum_shown = 0
	full_reroll_stacks = 0
	# Der Laden des alten Laufs ist zu; _start_new_round zieht den Knopf nach.
	shop_reopen_allowed = false
	shop_reopened = false
	run = GameRun.new_run()
	_connect_run()
	# Reveal-Auslage des alten Laufs abräumen; ihr Ablauf merkt den Lauf-Wechsel
	# erst an seiner nächsten await-Grenze.
	_clear_hub_reward_overlay()
	_jewelry_box_upgrades.clear()  # Funde des alten Laufs sind fort
	_encore_packs.clear()
	last_thrown_slots.clear()
	if table_screen != null:
		table_screen.clear_fumble_marks()
	betting_open = false  # frische Auslage eröffnet die erste Runde
	charm_shop.visible = false  # Fenster-UI-Rückfall ohne Hub
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.reset_pages()
	if lexikon_view != null:
		lexikon_view.reset()  # die Verweis-Historie stirbt mit dem Lauf
	if payout_ledger != null:
		payout_ledger.reset()  # eine offene Abrechnung gehört dem alten Lauf
	game_over_panel.visible = false
	if title_view != null:
		title_view.clear_game_over()
	_set_gameplay_ui_visible(true)
	# Frischer Run: der Puls ruht, bis wieder zum ersten Mal gewürfelt wird.
	if table_screen != null:
		table_screen.set_round_pulse(false)
	if route_choice != null:
		route_choice.close()  # eine offene Wahl gehört zum alten Lauf
	route_pending = false
	if log_open:
		_close_round_log()
	round_log.clear()
	_start_new_round()

## Verdrahtet einen frisch erzeugten Run: Shop/Gravur-Station bekommen ihn
## gereicht, seine Signale halten die Anzeigen aktuell. Der alte Run wird
## mitsamt Verbindungen freigegeben (RefCounted).
func _connect_run() -> void:
	# Der gemessene Magazin-Deckel gehört dem TISCH: ein frischer Lauf bekommt ihn
	# sofort, bevor ein Fenster ihn abliest.
	if run != null and _pack_columns > 0:
		run.set_pack_grid(_pack_columns)
	# Ein Laden, der noch abräumt, gibt seine Fläche JETZT ab - der run-Setter gleich
	# darunter löscht seinen Abgangs-Zustand, danach weiß niemand mehr davon.
	if charm_shop != null and is_instance_valid(charm_shop):
		charm_shop.finish_close()
	charm_shop.run = run
	if table_screen != null and table_screen.secret_shop_window != null:
		table_screen.secret_shop_window.run = run
		if not table_screen.secret_shop_window.energy_spent.is_connected(_on_secret_shop_energy_spent):
			table_screen.secret_shop_window.energy_spent.connect(_on_secret_shop_energy_spent)
		if not table_screen.secret_shop_window.goods_purchased.is_connected(_on_secret_goods_purchased):
			table_screen.secret_shop_window.goods_purchased.connect(_on_secret_goods_purchased)
		if not table_screen.secret_shop_window.die_purchased.is_connected(_on_secret_die_purchased):
			table_screen.secret_shop_window.die_purchased.connect(_on_secret_die_purchased)
		if not table_screen.secret_shop_window.vitrine_changed.is_connected(_on_secret_vitrine_changed):
			table_screen.secret_shop_window.vitrine_changed.connect(_on_secret_vitrine_changed)
	if table_screen != null and table_screen.side_bet_window != null:
		table_screen.side_bet_window.run = run
	if table_screen != null and table_screen.slot_bank_window != null:
		table_screen.slot_bank_window.run = run
		table_screen.slot_bank_window.refresh()
	if table_screen != null and table_screen.workshop_window != null:
		# Erst verdrahten, DANN den Lauf reichen: der Setter baut das Fenster sofort
		# neu, und diese erste Meldung stellt die Zwingen-Würfel auf.
		if not table_screen.workshop_window.series_applied.is_connected(_on_series_applied):
			table_screen.workshop_window.series_applied.connect(_on_series_applied)
		if not table_screen.workshop_window.die_stages_changed.is_connected(_on_die_stages_changed):
			table_screen.workshop_window.die_stages_changed.connect(_on_die_stages_changed)
		# Die ZIELWAHL löst die Fahrt aus - nicht mehr die Kamera allein.
		if not table_screen.workshop_window.target_chosen.is_connected(_on_workshop_target_chosen):
			table_screen.workshop_window.target_chosen.connect(_on_workshop_target_chosen)
		# Die physischen Datenzellen: Ankunft, Rückgabe und Dekompression.
		if not table_screen.workshop_window.pack_landed.is_connected(_on_pack_landed):
			table_screen.workshop_window.pack_landed.connect(_on_pack_landed)
		if not table_screen.workshop_window.pack_unslotted.is_connected(_on_pack_unslotted):
			table_screen.workshop_window.pack_unslotted.connect(_on_pack_unslotted)
		if not table_screen.workshop_window.press_started.is_connected(_on_press_started):
			table_screen.workshop_window.press_started.connect(_on_press_started)
		# DER BLOCK und der SCANNER: das Fenster taktet, scene_root fährt die Körper.
		if not table_screen.workshop_window.cards_latched.is_connected(_on_cards_latched):
			table_screen.workshop_window.cards_latched.connect(_on_cards_latched)
			table_screen.workshop_window.die_raised.connect(_on_die_raised)
			table_screen.workshop_window.light_passed.connect(_on_light_passed)
			table_screen.workshop_window.light_struck.connect(_on_light_struck)
			table_screen.workshop_window.die_returned.connect(_on_die_returned)
		_drop_data_cells()  # die Ware des alten Laufs liegt nicht mehr auf der Bank
		table_screen.workshop_window.run = run
	# Die LADESÄULE liest denselben Lauf - sie bucht nichts, scene_root tut es.
	_connect_charging_column()
	_refresh_charging_column()
	# Ein frischer Lauf steht vor geschlossenem Laden: der Vorhang springt zu.
	if shop_vitrine != null and is_instance_valid(shop_vitrine):
		shop_vitrine.clear()
	# Und die Schale der Bank steht leer da - eine Fahrt des alten Laufs endet
	# nirgends mehr (ihr _arriving geht mit).
	if ausgabefach != null and is_instance_valid(ausgabefach):
		ausgabefach.clear()
	_fach_expecting = false
	_drop_fach_drag_hard()  # ein Tausch des alten Laufs schuldet nichts mehr
	_vitrine_depart_px = Vector2(-1, -1)
	_vitrine_curtain = false
	_vitrine_grade = ShopController.GRADE_STAND
	_vitrine_swap += 1  # ein Umschlag mitten in der Fahrt stellt nichts mehr
	_vitrine_gen += 1   # und ein Vorbau mitten im Bauen gibt den Vorhang nicht frei
	_vitrine_building = false
	_slit_gen += 1
	_drop_slit_cells()  # die versiegelte Ware des alten Ladens liegt nirgends mehr
	_drop_bet_bodies()  # und der Wett-Tresen des alten Laufs ebenso
	_drop_payout_bodies()  # samt der Ablage seiner Auszahlungs-Seite
	# (Einen laufenden Automaten-Perlenzug beendet _connect_run über refresh() -
	# das Fenster bucht dabei hart auf den ALTEN Lauf.)
	_hide_vitrine_hard()  # ein Abgang des alten Laufs endet hier, Loch und Ware fort
	# Und das Hinterzimmer steht wieder vergittert da.
	if secret_vitrine != null and is_instance_valid(secret_vitrine):
		secret_vitrine.clear()
	_secret_depart_px = Vector2(-1, -1)
	_secret_curtain = false
	_secret_grade = ShopController.GRADE_STAND
	_secret_swap += 1
	_hide_secret_hard()
	if charm_shop != null and not charm_shop.pack_purchased.is_connected(_on_pack_purchased):
		charm_shop.pack_purchased.connect(_on_pack_purchased)
	if charm_shop != null and not charm_shop.pack_refunded.is_connected(_on_pack_refunded):
		charm_shop.pack_refunded.connect(_on_pack_refunded)
	charm_library.run = run
	run.money_changed.connect(_on_money_changed)
	run.charms_changed.connect(_on_charms_changed)
	# Würfel-Änderungen (Kauf, Paket, Gravur, Nehmen-Effekt) laufen über EINEN Weg.
	run.pool_changed.connect(_on_pool_changed)
	# Die Schale rechts der Bank zeigt, was bezahlt ist und noch keinen Platz hat.
	run.pending_dice_changed.connect(_on_pending_dice_changed)
	# Die Zwingen stehen auf der Bank und fehlen darum in den Trays daneben.
	run.combo_upgraded.connect(_on_combo_upgraded)
	run.hub_level_changed.connect(_on_hub_level_changed)
	run.secret_shop_discovered.connect(_on_secret_shop_discovered)
	# Unterschrift/Abrechnung: Marken, Fahrplan und Wett-Preise sofort nachziehen.
	run.deals_changed.connect(_on_deals_changed)
	run.energy_changed.connect(_on_energy_changed)
	# Jedes Ladungs-Ereignis geht in die Chronik der Runde.
	run.charge_logged.connect(_log_record_charge)
	# Paket-Einsätze werden bezahlbar oder knapp, während die Wettannahme offen ist.
	run.packs_changed.connect(_refresh_side_bet_affordability)
	_shown_money = run.money  # kein Geld-Licht beim Spielstart
	_on_money_changed(run.money)
	_on_charms_changed()
	_refresh_combo_label_texts()
	_sync_hub_level_state()  # Hub-Plakette, Shop-Gate, Nebenwetten-Installation
	_sync_secret_shop_state()  # Börse + Eintrag (frischer Lauf: leer und verborgen)
	_sync_ausgabefach()  # und die Schale zeigt, was dieser Lauf hinterlegt hat

## Idempotenter Gesamtzustand: Bank = Bestand/Deckel. Das Schwarzmarkt-Fenster
## steht immer, vor der Lizenz als gesperrt markiert.
func _sync_secret_shop_state() -> void:
	if run == null:
		return
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_energy_display(run.energy, run.energy_cap())
	if table_screen != null:
		table_screen.set_secret_shop_installed(true)
		if table_screen.secret_shop_window != null:
			table_screen.secret_shop_window.set_locked(not run.secret_shop_unlocked)
	_sync_capacitor()
	if secret_shop_click_zone != null:
		secret_shop_click_zone.collision_layer = 8
	# Die Bucht misst sich am eben gestellten Fenster - idempotent, generationssicher.
	_sync_secret_vitrine()

func _sync_capacitor() -> void:
	if capacitor_bank == null or run == null:
		return
	capacitor_bank.set_energy(run.energy, run.energy_cap())

func _on_energy_changed(value: int) -> void:
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_energy_display(value, run.energy_cap())
	_sync_capacitor()
	_sync_combo_upgrade_buttons()  # die Preisschilder dimmen sich selbst
	_refresh_side_bet_affordability()
	_refresh_charging_column()  # die Hebel der Säule dimmen sich mit
	if table_screen != null and table_screen.slot_bank_window != null:
		table_screen.slot_bank_window.refresh_if_idle()  # der Einsatz kostet ⚡

## Die Lizenz hat das Gitter gehoben: der Hub quittiert golden, ein Licht fährt
## die Hinterzimmer-Ader hinüber und das Fenster meldet sich mit einer Stoßwelle -
## dieselbe Sprache wie ein neu installierter Automat. Gebucht ist längst.
func _on_secret_shop_discovered() -> void:
	var opening_run := run
	_sync_secret_shop_state()
	if table_screen == null:
		return
	if table_screen.hub != null:
		table_screen.hub.flash_frame(CasinoStyle.GOLD_INTENSE)
	var travel := table_screen.secret_shop_pay_comet(CasinoStyle.ENERGY)
	if travel > 0.0:
		await get_tree().create_timer(travel).timeout
	if run != opening_run or table_screen == null:
		return  # Reset während des Kometen
	table_screen.celebrate_secret_shop_install(VIOLET_REVEAL_COLOR)

## Energie für Ware oder Neuwurf: sie fährt dieselbe Ader wie das Eintrittsgeld.
func _on_secret_shop_energy_spent(_amount: int) -> void:
	if table_screen != null:
		table_screen.secret_shop_pay_comet(CasinoStyle.ENERGY)

## Ob die Auslage gerade auf dem Grubenboden liegt: dann weicht ihr das Mobiliar.
## Die Grube bleibt begehbar - gesperrt ist nur der Wurf (route_pending).
func _route_choice_open() -> bool:
	return route_choice != null and route_choice.visible

## Spannt die Auslage über den GANZEN Grubenboden - Netz-Feld, Erklärzeile,
## Aktions-Knöpfe und Wertungs-Orbs sind solange ausgeblendet.
func _place_route_choice() -> void:
	if route_choice == null or table_screen == null or table_screen.pit_window == null:
		return
	var pit := Rect2(table_screen.pit_window.position, table_screen.pit_window.size)
	var inset := pit.size.x * ROUTE_CHOICE_INSET
	route_choice.position = pit.position + Vector2(inset, inset)
	route_choice.size = pit.size - Vector2(inset, inset) * 2.0

## Erster Grubenzoom der Runde: die Auslage kommt auf den Grubenboden. Ohne
## Display-Fläche fällt die Wahl automatisch aufs erste Angebot (2D-Rückfall).
func _open_route_choice() -> void:
	if run.route_offers.is_empty():
		return
	if route_choice == null:
		_on_route_chosen(0)
		return
	_place_route_choice()
	route_choice.open(run.route_offers, GameRun.is_stress_round(run.round_number),
		run.deal_bonus_factor())

## Vertrag unterschrieben: Karten weg, JETZT erst greifen die Rundenbeginn-
## Wirkungen (die Boss-Kondition muss vor der Drossel stehen) - danach darf
## geworfen werden.
func _on_route_chosen(index: int) -> void:
	if not route_pending:
		return  # doppelte Unterschrift = doppelter Vorschuss
	var energy_before := run.energy
	run.take_route(index)
	# Startkapital & Co. prägen Energie SOFORT - GameRun hat gebucht, das Licht
	# holt nach: je ⚡ ein Komet auf dem Weg der Überladungs-Auszahlung.
	_play_deal_energy_volley(run.energy - energy_before)
	route_pending = false
	_commit_round()  # ab der Unterschrift sind die Würfel im Spiel
	if route_choice != null:
		route_choice.close()
	# Jetzt erst fährt der Nachschub auf - ohne Neuzoom, die Grube steht ja schon.
	if is_pit_focused and not queue_activated and _is_playing():
		_activate_queue()
	_apply_round_start_effects()
	_refresh_round_hud()  # ein Benchmark-Aufschlag verschiebt den Balken sofort
	_refresh_ui()

## Rundenbeginn-Wirkungen (Charms UND Deals): Glückszahl, Drossel, Rampenlicht,
## Wartungsvertrag. Läuft entweder direkt beim Rundenstart (Runde 1, ohne
## Auslage) oder mit der Unterschrift.
func _apply_round_start_effects() -> void:
	run.apply_round_start_charms()
	_update_charm_badges()  # frisch gewürfelte Glückszahl (Lumpensammler)
	if table_screen != null:
		_set_spotlight_combo(run.spotlight_combo)
		_set_throttled_combos(run.throttled_combos)  # Stresstest: Chips auf AUS

func _start_new_round() -> void:
	_cancel_deck_shift()
	_cancel_reorder_drag()
	_cancel_charm_drag()
	_cancel_lineup()
	# Die Runde ist noch nicht festgezurrt: die Werkbank bleibt bis zur
	# Unterschrift (bzw. bis zum ersten Wurf) bearbeitbar.
	round_committed = false
	_sync_editing_lock()
	_sync_shop_reopen_button()
	hands_taken_this_round = 0
	chimney_sweep_used_this_round = false
	anchor_clause_used_this_round = false
	phoenix_used_this_round = false
	taken_dice_this_round = 0
	recycling_used_this_round = false
	first_hand_after_farkle = false
	round_best_combo_rank = -1
	round_best_hand_score = 0
	round_first_hand_score = 0
	round_farkled = false
	round_combo_keys = {}
	round_combo_repeated = false
	round_fallback_taken = false
	round_high_hand = false
	round_max_hand_dice = 0
	round_min_hand_dice = NO_HAND_DICE
	discarded_this_round = []
	discarded_faces_this_round = []
	slot_draw_positions = []
	queue_activated = false  # Nachschub-Tray erst beim ersten Grubenzoom
	# Der Rückblick reicht genau eine Runde weit.
	if log_open:
		_close_round_log()
	round_log.clear()

	# Liegt eine Auslage bereit, warten die Rundenbeginn-Wirkungen auf die
	# Unterschrift: sonst stünde die Drossel fest, bevor die Boss-Kondition
	# gewählt ist, und der Wartungsvertrag käme eine Runde zu spät.
	route_pending = not run.route_offers.is_empty()
	if not route_pending:
		_apply_round_start_effects()

	if test_materials_enabled:
		run.randomize_all_materials()
		run.randomize_all_essences()
	if test_pointers_enabled:
		run.randomize_all_pointers()

	# Der Stapel liegt bis zur Unterschrift in der POOL-Reihenfolge: das ganze
	# Werkbank-Fenster über weiß der Spieler, wo ein Würfel steht (und ordnet ihn
	# per reorder_pool an). Gemischt wird erst beim Festzurren (_commit_round).
	round_pool_kinds = run.owned_pool.duplicate()

	next_draw_index = 0
	_reset_tray_stage_hard()
	hand_total = 0
	hand_note = ""
	_refresh_round_hud()
	_animate_points_to(0, false)
	# Nebenwetten laufen ab dem Shop; die erste Runde (kein vorheriger Shop)
	# eröffnet die Auslage hier. Eine schon offene bleibt samt Einsätzen stehen.
	if not betting_open:
		_open_side_bet_betting()
	_start_new_hand()

## Zurren der Runde - Unterschrift oder, ohne Auslage, der erste Wurf. Beides
## macht dasselbe und darf je Runde nur EINMAL passieren: die Werkbank schließt und
## der Vorrat versinkt. GEMISCHT wird hier NICHT mehr (Spielregel 2026-08-30): der
## Stapel zieht in Pool-Reihenfolge, und die einzige Streuung ist die Ablage-Reihe,
## die im Pit erscheint.
func _commit_round() -> void:
	if round_committed:
		return
	round_committed = true
	# Das Zurren löscht die Sperre des Wartungsvertrags, für die sie galt.
	run.note_round_committed()
	# Mit der Unterschrift ist die Ladenzeit vorbei - der Knopf geht mit.
	shop_reopen_allowed = false
	_sync_shop_reopen_button()
	# Zieh-Reihenfolge: die Partition zieht ihre Gruppe stabil nach vorn.
	if CharmEffects.draws_essences_first(run.charm_ids()):
		round_pool_kinds = _essences_first(round_pool_kinds)
	_sync_editing_lock()
	# Das RASTER darf nur stehen, solange der Vorrat stehen dürfte: das Zurren
	# schließt es HART, sonst fände _sink_pool_tray einen schon versenkten Vorrat.
	_settle_deck_glass_hard()
	# Die Aufspannung kehrt aus der Bank in den Pool zurück, BEVOR der Träger sinkt -
	# er versinkt dann mit ihm (Endzustand zuerst, siehe _migrate_bench_to_pool).
	_migrate_bench_to_pool()
	# Ab hier ist der Vorrat der TRÄGER im offenen Pit: das Pool-Tray sinkt und
	# steht dort sichtbar weiter. Vor dem Refresh, damit der ihn schon als Träger
	# füllt. (Das Zurren ist der eine Moment - Unterschrift ODER erster Wurf.)
	_sink_pool_tray()
	_refresh_deck_trays()

## Sortiert beseelte Würfel stabil an den Anfang (Frische Ware) - die Seele ist
## angeboren, also entscheidet allein essence_id.
func _essences_first(pool: Array[DieDefinition]) -> Array[DieDefinition]:
	var souls: Array[DieDefinition] = []
	var rest: Array[DieDefinition] = []
	for def in pool:
		if def != null and def.essence_id != "":
			souls.append(def)
		else:
			rest.append(def)
	return souls + rest

func _start_new_hand() -> void:
	has_rolled_current_hand = false
	active_kinds = []
	rerolls_this_hand = 0
	_update_charm_badges()
	# full_reroll_stacks bleibt stehen - der Rote Knopf stapelt bis zum
	# nächsten NEHMEN, nicht je Hand.
	dice.reset()
	_refresh_deck_trays()
	_refresh_ui()

## Bank-Knopf: Runde bei ≥1 gefüllter Überladungs-Stufe vorzeitig kassieren.
func _on_bank_button_pressed() -> void:
	if phase != Phase.IDLE or run.stages_cleared(hand_total) < 1:
		return
	_on_round_complete()

## Runde endet automatisch nur bei voller Überladung oder LEEREM Pool - der Rest
## des Stapels wird als kleinere Hand ausgespielt, nicht verschenkt; nach der
## ersten gefüllten Stufe kann der Spieler per Bank-Knopf früher beenden.
func _round_should_end() -> bool:
	return run.stages_cleared(hand_total) >= run.max_overcharge_stages() \
		or hands_taken_this_round >= run.max_hands_this_round() \
		or _remaining_in_pool() <= 0

## Rundenende: MONEY_PER_ROUND_CLEAR EINMAL für den geschafften Benchmark, je
## ungezogenem Würfel MONEY_PER_UNUSED_DIE - und je gefüllter Überladungs-Stufe
## eine Energie (⚡). Was nicht mehr in die Börse passt, fällt zum alten Satz als
## Geld an. Die Auszahlung läuft als Tisch-Animation, bevor der Shop aufgeht; die
## Phase springt schon auf PAYOUT, damit derweil nichts anklickbar bleibt.
## Die WAREN-Plots der Seite, gemerkt bei der Buchung und gesetzt erst in der
## Karten-Phase - die Namen erscheinen, wenn die Karten gezählt werden.
var _payout_pending_plots: Array[Dictionary] = []
## Die Körper-Spezifikation je Plot (id -> _bet_price_spec, bei gesammelten
## Paket-Plots mit SUMMIERTER Stückzahl) - der Ablage-Auftritt baut daraus.
var _payout_plot_specs: Dictionary = {}

## Der Sammel-Schlüssel der Ablage: PAKET-Gewinne GLEICHER Sorte und Größe stehen
## als EINE Zeile mit summierter Stückzahl; alles andere (Sonderposten, Marken)
## bleibt je Wette eigen - ein summierter Sonderposten löge über seinen Inhalt.
func _payout_merge_key(bet: SideBet) -> String:
	match bet.payout_kind:
		SideBet.Payout.PACK, SideBet.Payout.PACKS:
			return "%s|%d" % [bet.reward_pack_type, bet.reward_pack_tier]
	return ""

## MELDET Geld an die Auszahlungs-Seite - immer NEBEN einer bestehenden Buchung,
## nie statt ihrer. Außerhalb der Auszahlung schweigt sie (Nehmen-Geld u. a.).
## note ist der Untertitel der Zeile: die Wetten tragen dort ihre BEDINGUNG, und zwar
## den Satz der Wette selbst - hier wird nichts zweitformuliert.
func _ledger_money(id: String, caption: String, amount: int, note := "") -> void:
	if payout_ledger != null and phase == Phase.PAYOUT:
		payout_ledger.add_money(id, caption, amount, note)

## MELDET Energie an die Auszahlungs-Seite - eigene Zeile, nicht in der Summe.
func _ledger_energy(amount: int) -> void:
	if payout_ledger != null and phase == Phase.PAYOUT:
		payout_ledger.add_energy(amount)

func _on_round_complete() -> void:
	var stages := run.stages_cleared(hand_total)
	if stages >= 1:
		phase = Phase.PAYOUT
		# Der Hub wird zur Auszahlungs-Seite: leer aufschlagen, dann zählt sie mit.
		_drop_payout_bodies()  # ein Rest der Vorrunde liegt hier nie
		if payout_ledger != null:
			payout_ledger.reset()
			payout_ledger.set_round(run.round_number)
			table_screen.hub.fade_page_in(payout_ledger)
		# DER AUFDECK-SCHLAG ZUERST (Spieler-Entscheid 2026-08-26): jede noch offene
		# Wette mit Reiß-Bedingung hebt ihren Gewinn als GEWONNEN aus der Grube,
		# Verlierer sinken - und die Sieger BLEIBEN STEHEN. Gezählt (genommen, Meteor,
		# Zeile) werden sie erst NACH dem Geld der Runde, in ihren eigenen Phasen.
		# Gebucht ist trotzdem alles hier: Zinsen und Speicher-Raum rechnen auf dem
		# Stand NACH den Wetten - was zuerst aufgedeckt ist, ist zuerst gebucht.
		_resolve_side_bets(true)
		if _bet_stage == SideBetPanel.STAGE_WON:
			await get_tree().create_timer(LiftShaftView.swap_cycle_time()).timeout
			if phase != Phase.PAYOUT:
				return  # Spiel wurde während des Aufdeckens zurückgesetzt
		var ids := run.charm_ids()
		# Deal-Faktor auf die ganze Auszahlung; der Wartungsvertrag streicht die
		# Würfel-Zeile ganz, die Sparprämie legt auf sie drauf (wie das Sparschwein).
		var factor := run.round_payout_factor()
		var base_blind := roundi(MONEY_PER_ROUND_CLEAR * factor)
		var per_die := 0
		if run.unused_dice_pay():
			per_die = roundi((MONEY_PER_UNUSED_DIE + CharmEffects.unused_die_bonus(ids)
				+ run.deal_unused_die_bonus()) * factor)
		# Die übrigen Würfel: die ungezogenen UND die ungewertet in der Grube
		# liegenden (Beenden vor dem Nehmen) - EINMAL erfasst, dann geteilt.
		var leftover_dice := _unused_die_entries()
		# Knallgas: die Kettenreaktion im Stapel - je übrigem Würfel ein eigener
		# Satz. Der Wartungsvertrag streicht die Zeile ganz, also auch sie.
		var per_die_row := _leftover_die_payouts(per_die, ids, leftover_dice)
		# Schmuckkästchen: je übrigem Würfel 10% Chance auf eine Material-Gravur.
		# Gebucht HIER, gezeigt erst an seinem Dock-Platz in der Charm-Zeremonie.
		var leftover_defs: Array[DieDefinition] = []
		for entry in leftover_dice:
			leftover_defs.append(entry["def"])
		_jewelry_box_upgrades = run.apply_jewelry_box(leftover_defs)
		# LADUNG: was diese Runde nicht gewertet hat, kühlt eine Stufe ab -
		# gebucht VOR der Auszahlung.
		_last_cooled_dice = run.cool_unplayed_dice()
		await _play_cooling_ceremony(_last_cooled_dice)
		if phase != Phase.PAYOUT:
			return  # Reset während des Entladens
		# Füllhorn: die Prämie hängt am BALKEN, also an den geräumten Stufen -
		# gebucht hier, gezeigt an seinem Dock-Platz.
		_encore_packs = run.apply_encore(stages)
		# Aufteilung VOR jeder Buchung DIESER Zählsequenz (die Wetten haben schon
		# gezahlt, ihre ⚡ füllt die Börse zuerst): die Zeremonie plant daraus ihre
		# Kometen und bucht sie einzeln bei Ankunft.
		var split := run.energy_split(stages)
		# Zinsen rechnen auf demselben Stand - Wett-Geld verzinst also mit - und
		# reisen mit dem Benchmark-Kometen: ein eigener Komet für ein paar Dollar
		# wäre Zeremonie um ihrer selbst willen.
		var interest := run.interest_income()
		await _play_round_clear_payout(base_blind, interest, per_die_row, stages, split, leftover_dice)
		if phase != Phase.PAYOUT:
			return  # Spiel wurde während der Auszahlung zurückgesetzt
		# Rundenende-Charms: strikt links nach rechts, je Charm eine sichtbare
		# Wirkung (Geld-Komet zur Truhe, Gravur-Meteore in die Schublade).
		await _play_round_end_charm_ceremony(ids, stages)
		if phase != Phase.PAYOUT:
			return  # Spiel wurde während der Charm-Zeremonie zurückgesetzt
		# Glücksgroschen wächst ERST nach seiner Auszahlung (erste Runde: $3).
		if ids.has(Charm.OLD_PENNY):
			run.old_penny_payouts += 1
			_update_charm_badges()  # sein Chip zeigt ab jetzt die nächste Summe
		# NACH dem Geld der Runde werden die Wett-Gewinne gezählt: erst die
		# Geld-/⚡-Wetten (Preis versinkt, Meteor, Zeile), dann die KARTEN (Kassette
		# versinkt, Meteor, Auftritt auf der Seite) - eine nach der anderen.
		await _play_bet_money_payouts()
		if phase != Phase.PAYOUT:
			return
		await _play_bet_goods_payouts()
		if phase != Phase.PAYOUT:
			return
		_bet_stage = SideBetPanel.STAGE_NONE  # der Tresen ist abgerechnet und leer
		# Kein Deal überlebt seine Runde: die Marken wischen an JEDEM Rundenende -
		# NACH den Wetten, deren Quoten noch dazugehörten. Erst der sichtbare Wisch,
		# dann die Buchung, sonst wären die Marken fort, bevor der Spieler das Ende
		# bemerkt. Die Abrechnung des Stresstests räumt danach nur noch die Sperren.
		await _sweep_deal_tokens()
		if phase != Phase.PAYOUT:
			return  # Spiel wurde während des Wischs zurückgesetzt
		# Bestandener Stresstest: EIN beseelter Würfel als Preis. Gebucht wird hier
		# (ins Ausgabefach), geliefert erst unten am Hub.
		var stress_reward: DieDefinition = null
		if GameRun.is_stress_round(run.round_number):
			run.settle_block_deals()
			stress_reward = run.grant_stress_reward()
		# Die Seite steht still, bis der Spieler kassiert. Gepollt statt auf ein
		# Signal gewartet: ein Reset darf nicht auf etwas warten, das nie kommt.
		if payout_ledger != null:
			# Gezählt wird in der ÜBERSICHT, kassiert wird AM HUB: von dort steht die
			# ganze Seite im Bild - aus der Übersicht liegt ihre Unterkante samt
			# Summe und Knopf außerhalb des Bildes.
			camera_rig.zoom_to(CameraRig.Mode.HUB)
			await get_tree().create_timer(CameraRig.ZOOM_DURATION).timeout
			if phase != Phase.PAYOUT:
				return
			payout_ledger.show_cashout()
			while phase == Phase.PAYOUT and not payout_ledger.cashout_requested:
				await get_tree().process_frame
			if phase != Phase.PAYOUT:
				return  # Spiel wurde vor dem Kassieren zurückgesetzt
			# Das KASSIEREN räumt die Ablage: erst versinken die Körper in der Fläche,
			# dann erst reist jeder Gewinn als Licht an sein Ziel - eine Kassette, die
			# steigt, während ihr Körper noch auf der Seite steht, wäre zweimal da.
			await _sink_payout_bodies()
			if phase != Phase.PAYOUT:
				return
			_fly_payout_targets()
			table_screen.hub.fade_page_out(payout_ledger)
			# Die Blende wird ABGEWARTET: verdrängte der Laden die Seite mittendrin,
			# stünde sie in der Rückkehr-Liste und käme beim Ladenschluß wieder.
			await get_tree().create_timer(HubView.PAGE_FADE + 0.05).timeout
			if phase != Phase.PAYOUT:
				return
		phase = Phase.SHOP
		# Die Ladenzeit ist Werkbankzeit: die Sperre hängt an der Phase, also muss
		# jeder Phasenwechsel sie nachziehen.
		_sync_editing_lock()
		# Ab in den Shop: der Rundenpuls verklingt (lief noch durch die Auszahlung).
		# Die Drossel ist mit der Runde vorbei - der Chip soll im Shop kaufbar wirken.
		_set_throttled_combos([] as Array[String])
		if table_screen != null:
			table_screen.set_round_pulse(false)
		_set_gameplay_ui_visible(false)
		# Die letzte Ablage-Reihe fährt ein, die Warteschlange geht ab, und dann
		# hebt der Träger seinen Inhalt als NEUEN Pool heraus (_play_tray_return).
		_play_tray_return()
		# Kamera auf den Hub, dann den Shop öffnen.
		camera_rig.zoom_to(CameraRig.Mode.HUB)
		# Nebenwetten werden ZUGLEICH mit dem Shop verfügbar.
		_open_side_bet_betting()
		# Das Freispiel gehört dem BESUCH: der Laden öffnet, der Gratisdreh lebt auf.
		run.begin_shop_visit()
		charm_shop.open()
		# Der Laden deckt seine Bucht auf - gemessen wird erst, wenn die Seite steht.
		_sync_shop_vitrine(true)
		# Erst jetzt steht der Hub im Bild - der Preis zeigt sich darüber. Nicht
		# awaiten: der Spieler soll den Laden sofort bedienen können.
		if stress_reward != null:
			_play_hub_reward_ceremony([] as Array[Pack], 0, stress_reward)
	else:
		phase = Phase.GAME_OVER
		shop_reopen_allowed = false
		_sync_shop_reopen_button()
		if table_screen != null:
			table_screen.set_round_pulse(false)
		_show_game_over(hand_total)

## Rundenende: die Marken wischen von Hub UND Grubenrand (die Klauseln laufen mit
## der Runde ab, die Reihen bauen sich beim Rundenstart leer neu auf).
func _sweep_deal_tokens() -> void:
	var hub := table_screen.hub if table_screen != null else null
	var sweep := hub.sweep_deal_tokens() if hub != null else 0.0
	if table_screen != null:
		sweep = maxf(sweep, table_screen.sweep_pit_deal_tokens())
	if sweep > 0.0:
		# Etwas länger als der Wisch: ein Neuaufbau würde sonst Marken freigeben,
		# deren Tween im selben Frame noch endet.
		await get_tree().create_timer(sweep + 0.1).timeout

## Wertet die platzierten Nebenwetten gegen die Rundenbilanz aus. cleared =
## Runde geräumt (sonst verliert jede Wette). Das Ergebnis erscheint als Banner
## im gleich darauf öffnenden Shop.
func _resolve_side_bets(cleared: bool) -> void:
	if run.active_side_bets.is_empty():
		return
	var result := _side_bet_stats()
	result["cleared"] = cleared
	var placed := run.active_side_bets.size()
	# Auszahlung bucht Geld (add_money) - das generische Licht unterdrücken, damit
	# stattdessen die Nebenwetten-Kometen laufen.
	# Gemeldet wird, was gebucht WURDE: die Beträge rechnen mit denselben Formeln
	# wie GameRun._pay_side_bet gegen den Stand VOR der Buchung.
	var factor := run.side_bet_payout_factor()
	var ids := run.charm_ids()
	var energy_room := maxi(run.energy_cap() - run.energy, 0)
	_drop_payout_bodies()  # was die Vorrunde etwa liegenließ, geht VOR der Buchung
	_suppress_money_light = true
	var won := run.resolve_side_bets(result)
	_suppress_money_light = false
	# Im SELBEN synchronen Zug wie die Buchung: das Magazin hält die Gewinn-Kassette
	# zurück, bis kassiert ist - dazwischen liegt kein Bild, sie blitzt also nie auf.
	_withhold_payout_packs(won)
	var plan := _bet_ledger_plan(won, factor, ids, energy_room)
	_refresh_side_bet_panel()  # Wetten geleert -> Fenster zeigt "keine aktiv"
	# Die STELLPLÄTZE der Seite: nur WARE stellt einen Körper (Geld und ⚡ sind
	# Zeilen), je Stück mit seinem NAMEN aus der EINEN Formulierung des Fensters
	# (prize_label - hier wird nichts formuliert). PAKET-Gewinne GLEICHER Sorte
	# und Größe SAMMELN sich dabei in EINER Zeile mit summierter Stückzahl
	# (Spieler-Wunsch 2026-08-26: "4 Große Zahlen-Pakete" statt zweimal "2 …");
	# die Summe formuliert dieselbe Quelle, aus der prize_label liest
	# (Pack.amount_phrase).
	var panel := _side_bet_panel()
	_payout_pending_plots = []
	_payout_plot_specs.clear()
	var pack_plots: Dictionary = {}  # Sammel-Schlüssel -> Plot-Eintrag
	for i in won.size():
		var entry: Dictionary = plan[i] if i < plan.size() else {}
		var claim := {"bet": won[i], "money": int(entry.get("money", 0)),
			"energy": int(entry.get("energy", 0))}
		if _payout_body_wanted(won[i]) and panel != null:
			var bet: SideBet = won[i]
			var spec := _bet_price_spec(bet)
			var merge_key := _payout_merge_key(bet)
			if merge_key != "" and pack_plots.has(merge_key):
				var plot: Dictionary = pack_plots[merge_key]
				var plot_id: String = plot["id"]
				var total: int = int(_payout_plot_specs[plot_id].get("count", 1)) \
					+ int(spec.get("count", 1))
				_payout_plot_specs[plot_id]["count"] = total
				plot["label"] = Pack.amount_phrase(bet.reward_pack_type,
					bet.reward_pack_tier, total)
				claim["plot"] = plot_id
			else:
				var plot := {"id": "bet_%d" % i,
					"label": panel.prize_label(panel.offers.find(bet))}
				_payout_pending_plots.append(plot)
				_payout_plot_specs[plot["id"]] = spec
				if merge_key != "":
					pack_plots[merge_key] = plot
				claim["plot"] = plot["id"]
		_payout_claims.append(claim)
	# Der AUFDECK-Schlag: Sieger heben aus der Grube bzw. bleiben stehen, Verlierer
	# sinken - GENOMMEN wird noch NICHTS. Die Preise stehen auf dem Tresen, bis ihre
	# Zähl-Phase sie holt (_play_bet_money_payouts/_play_bet_goods_payouts, nach dem
	# Geld-Zählen der Runde).
	_bet_won = won.duplicate()
	_bet_stage = SideBetPanel.STAGE_WON
	_write_bet_counter(ShopController.GRADE_RISE, true)
	if won.is_empty():
		charm_shop.pending_bet_notice = "Nebenwetten: 0/%d gewonnen." % placed
		return
	var names: Array[String] = []
	for bet in won:
		names.append(bet.display_name)
	var doubled := " (Quotenbonus ×2)" if run.side_bet_payout_factor() > 1 else ""
	charm_shop.pending_bet_notice = "Nebenwette gewonnen (%d/%d): %s – Gewinn gutgeschrieben%s." \
		% [won.size(), placed, ", ".join(names), doubled]

## Was JEDE gewonnene Wette der Auszahlungs-Seite meldet: dieselben Formeln wie
## GameRun._pay_side_bet, gerechnet gegen den Stand VOR der Buchung. Sachgewinne
## (Pakete, LVL+1, Presse-Schub) melden nichts - nur was am vollen Magazin zu
## Geld zerfallen ist, steht ehrlich in der Zeile SEINER Wette.
func _bet_ledger_plan(won: Array[SideBet], factor: int, ids: Array[String],
		energy_room: int) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var room := energy_room
	for bet in won:
		var money := 0
		var energy := 0
		match bet.payout_kind:
			SideBet.Payout.MONEY:
				money = CharmEffects.side_bet_money(bet.payout_money * factor, ids)
			SideBet.Payout.ENERGY:
				var minted := bet.payout_energy * factor
				energy = clampi(minted, 0, room)
				room -= energy
				money = (minted - energy) * GameRun.ENERGY_OVERFLOW_MONEY
			SideBet.Payout.SPECIAL, SideBet.Payout.PACK, SideBet.Payout.PACKS:
				# Je am vollen Magazin zerfallenem Paket sein Fizzle-Geld.
				money = bet.awarded_fizzled * GameRun.PACK_FIZZLE_MONEY
		plan.append({"money": money, "energy": energy})
	return plan

## Darf eine frisch freigeschaltete Wettannahme SOFORT aufmachen? Gewettet wird vor
## dem ersten Wurf, also überall dort, wo die laufende Runde noch nicht festgezurrt
## ist - im Laden wie an jeder anderen Station. Nach dem Zurren wartet sie auf den
## nächsten Rundenbeginn. Und über eine schon offene Auslage geht nichts: ihre
## Angebote würden neu gewürfelt und die gesetzten Einsätze wären verwettet.
func _side_bets_open_now() -> bool:
	return not betting_open and (phase == Phase.SHOP or not round_committed)

## Öffnet die Wettannahme im Tisch-Fenster mit frischer Auslage.
func _open_side_bet_betting() -> void:
	if run == null or not run.side_bets_unlocked():
		return  # Nebenwetten erst ab Hub-Stufe 4 (Parkett) installiert
	betting_open = true
	if table_screen != null and table_screen.side_bet_window != null:
		# Ziele frieren HIER ein: der GESPEICHERTE Benchmark, nicht der wirksame -
		# eine später unterschriebene Klausel darf kein gedrucktes Ziel verschieben.
		# Und das MAGAZIN reicht seine Inventar-Sicht mit: eine Paket-Einsatz-Vorlage
		# liegt nur aus, wenn der Spieler die genannte Ware wirklich besitzt.
		table_screen.side_bet_window.open_betting(
			SideBet.roll_offers(SideBetPanel.OFFER_COUNT, run.hub_level, run.round_goal,
				run.pack_stock()))
		# Vor dem Setzen liegt NICHTS: der Tresen ist leer und die Knöpfe nennen die
		# Preise. Eine laufende Abrechnung bricht dabei ab - EIN Aufräum-Pfad, und
		# der räumt Loch wie Abgangs-Körper.
		_bet_won.clear()
		_bet_fulfilled.clear()
		_bet_failed.clear()
		_bet_stage = SideBetPanel.STAGE_OPEN
		_write_bet_counter()

## Schließt die Wettannahme (erster Wurf) - ab jetzt zeigt das Fenster Fortschritt.
func _close_side_bet_betting() -> void:
	if not betting_open:
		return
	betting_open = false
	if table_screen != null and table_screen.side_bet_window != null:
		table_screen.side_bet_window.close_betting()
		# Der Rundenbeginn nimmt dem Tresen nichts: die Gewinne stehen, wo sie stehen -
		# ab hier feuern nur die Melder für Erfüllung und Scheitern.
		_bet_stage = SideBetPanel.STAGE_ROUND
		_write_bet_counter()
	_refresh_side_bet_panel()

## Bezahlbarkeit der offenen Wett-Auslage nachziehen: Geld, Pakete und Energie
## ändern sich während der Wettannahme, der Setzen-Knopf muss das sofort zeigen.
func _refresh_side_bet_affordability() -> void:
	if not betting_open:
		return
	if table_screen != null and table_screen.side_bet_window != null:
		table_screen.side_bet_window.refresh_affordability()

## Aktualisiert den Live-Fortschritt der aktiven Wetten (Fortschritts-Modus).
func _refresh_side_bet_panel() -> void:
	if table_screen == null or table_screen.side_bet_window == null or run == null:
		return
	var stats := _side_bet_stats()
	table_screen.side_bet_window.update_progress(stats)
	_sync_bet_cover_goals()  # dieselbe Zeile auf den Schirm der geparkten Grube
	_note_bet_progress(stats)  # und meldet, wer eben erfüllt hat bzw. gescheitert ist

## Die Rundenbilanz, gegen die die Nebenwetten laufen - EINE Quelle für Live-
## Fortschritt und Abrechnung ("cleared" setzt nur die Abrechnung dazu).
func _side_bet_stats() -> Dictionary:
	return {
		"best_combo_rank": round_best_combo_rank,
		"best_hand_score": round_best_hand_score,
		"first_hand_score": round_first_hand_score,
		"dice_taken": taken_dice_this_round,
		"farkled": round_farkled,
		"stages_cleared": run.stages_cleared(hand_total),
		"distinct_combos": round_combo_keys.size(),
		"hands_taken": hands_taken_this_round,
		"combo_repeated": round_combo_repeated,
		"fallback_taken": round_fallback_taken,
		"high_hand": round_high_hand,
		"max_hand_dice": round_max_hand_dice,
		"min_hand_dice": round_min_hand_dice,
	}

## Schreibt die Rundenbilanz nach einer genommenen Hand fort. values = die
## ANGEZEIGTEN (verwandelten) Augen der Auswahl, scored = deren gewertete Indizes.
func _note_hand_for_side_bets(combo_key: String, score: int, hand_dice: int,
		values: Array[int], scored: Array[int]) -> void:
	if hands_taken_this_round == 1:
		round_first_hand_score = score
	# Dublette VOR dem Eintragen prüfen - danach steht die Sorte ja drin.
	if round_combo_keys.has(combo_key):
		round_combo_repeated = true
	round_combo_keys[combo_key] = true
	if combo_key == DiceScoring.ONE_KIND:
		round_fallback_taken = true
	round_max_hand_dice = maxi(round_max_hand_dice, hand_dice)
	round_min_hand_dice = mini(round_min_hand_dice, hand_dice)
	if _is_high_dice_hand(values, scored):
		round_high_hand = true

## Oberklasse: mindestens HIGH_DICE_MIN gewertete Würfel, jeder mit
## HIGH_DICE_EYES+ Augen - gemessen an dem, was in der Grube steht.
func _is_high_dice_hand(values: Array[int], scored: Array[int]) -> bool:
	if scored.size() < SideBet.HIGH_DICE_MIN:
		return false
	for i in scored:
		if i < 0 or i >= values.size() or values[i] < SideBet.HIGH_DICE_EYES:
			return false
	return true

## Zählt die Rundenposten nacheinander ab und MELDET jeden an die Auszahlungs-
## Seite; die übrigen Tray-Würfel blitzen im selben Takt mit (überzählige zahlen
## ohne eigenes Aufblitzen). Drei Posten: Benchmark (einmal Geld), Überladung
## (je Stufe ⚡ bzw. Überlauf-Geld nach split), übrige Würfel.
func _play_round_clear_payout(base_blind: int, interest: int, per_die_row: Array[int], stages: int,
		split: Dictionary, leftover_dice: Array) -> void:
	# Die Zählsequenz läuft in der Übersicht: Hub, Geldanzeige und beide Trays
	# sind gleichzeitig im Bild.
	camera_rig.zoom_out()
	await get_tree().create_timer(CameraRig.ZOOM_DURATION).timeout

	var hub := table_screen.hub
	# 1) Der geschaffte Benchmark zahlt EINMAL - ein goldener Komet, eine Buchung.
	var travel := table_screen.bank_comet(table_screen.stage_fill_color(1))
	await get_tree().create_timer(maxf(travel, 0.05)).timeout
	if phase != Phase.PAYOUT:
		return
	if hub != null:
		hub.flash_frame(CasinoStyle.GOLD_INTENSE)
	run.add_money(base_blind + interest)
	_ledger_money("benchmark", "Benchmark", base_blind)
	if interest > 0:
		_ledger_money("interest", "Zinsen", interest)
	await get_tree().create_timer(PAYOUT_TEXT_HOLD_DURATION).timeout

	# 2) Bank-Entladung: je Überladungs-Stufe ein Komet aus dem Zielbalken um die
	# Grube in den Hub - cyan, solange die Börse Platz hat, danach golden.
	await _play_bank_discharge(base_blind, int(split["stored"]), int(split["overflow"]),
		stages, hub)
	await get_tree().create_timer(PAYOUT_TEXT_HOLD_DURATION).timeout

	if not leftover_dice.is_empty():
		await get_tree().create_timer(PAYOUT_FLASH_DURATION).timeout
		for i in leftover_dice.size():
			_flash_die_tint(leftover_dice[i]["display"], leftover_dice[i]["tint"],
				leftover_dice[i]["scale"])
			var pay: int = per_die_row[i] if i < per_die_row.size() else 0
			run.add_money(pay)
			_ledger_money("dice", "Übrige Würfel", pay)
			await get_tree().create_timer(DIE_PAYOUT_STEP_INTERVAL).timeout

## Rundenende-Zeremonie der Charms: NACH der Rundenauszahlung, VOR dem Shop
## feuern die Rundenende-Charms strikt in Besitz-Reihenfolge (links nach
## rechts), und jeder ZEIGT seine Wirkung: Geld-Charms schicken einen Gold-
## Kometen vom Dock-Pad zur Schatztruhe (Buchung bei Ankunft), die Frankier-
## maschine schleudert je Gravur einen Meteor in ihre Vorrats-Schublade.
## Die Geld-Charms rechnen mit ZINSESZINS: CharmEffects.round_end_income_entries
## läuft die Dock-Reihenfolge mit einem fortgeschriebenen Stand ab, jeder Charm
## sieht also, was links von ihm schon gezahlt hat. Die Dock-Reihenfolge
## entscheidet damit über Geld genauso, wie sie längst über die Wertung
## entscheidet - zwei Zinsgroschen verzinsen einander.
## Gerechnet wird EINMAL vorab, gebucht weiterhin bei der Ankunft jedes Pakets;
## beide Wege enden auf demselben Betrag, weil jede Buchung abgewartet wird.
func _play_round_end_charm_ceremony(ids: Array[String], cleared_stages: int) -> void:
	var amounts := {}
	for entry in CharmEffects.round_end_income_entries(run.money, cleared_stages, ids,
			run.old_penny_payouts, run.owned_packs.size()):
		amounts[int(entry["charm_index"])] = int(entry["amount"])
	var jewelry_copy := 0
	var encore_copy := 0
	for j in ids.size():
		match ids[j]:
			Charm.INTEREST_PENNY, Charm.HIGH_FLYER, Charm.OLD_PENNY, Charm.EMERGENCY_FUND, \
					Charm.DEPOSIT_SHELF:
				if amounts.has(j):
					await _play_charm_money_payout(j, amounts[j])
			Charm.STAMP_MACHINE:
				await _play_stamp_machine_meteors(j)
			Charm.DYNAMO:
				await _play_dynamo_energy(j, CharmEffects.round_end_energy_at(j, ids))
			Charm.JEWELRY_BOX:
				await _play_jewelry_box_meteors(j, jewelry_copy)
				jewelry_copy += 1
			Charm.ENCORE:
				await _play_encore_meteor(j, encore_copy)
				encore_copy += 1
		if phase != Phase.PAYOUT:
			return

## Füllhorn: ab fünf geräumten Überladungs-Stufen fällt je Exemplar ein
## versiegelter Sonderposten an. Gebucht ist er, bevor das Licht startet - der
## Komet fliegt hinterher auf den Magazin-Platz, und dort steigt seine Kassette
## durch die Fläche (die eine Ankunft des Magazins).
func _play_encore_meteor(index: int, copy: int) -> void:
	if copy >= _encore_packs.size():
		return
	var pack := _encore_packs[copy]
	_flash_charm_and_pad(index)
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	var travel := 0.0
	if pack == null:
		# Volles Magazin: der Sonderposten ist zu Geld zerfallen (gebucht am
		# Rundenabschluss) - vom Pad fährt Geld statt einer Kassette.
		travel = _fly_pack_fizzle(_charm_trail_source_px([index]),
			GameRun.PACK_FIZZLE_MONEY, true)
		# Zerfallenes gehört ehrlich in die Zeile SEINES Charms.
		_ledger_money("charm_%d" % index, _charm_name(index), GameRun.PACK_FIZZLE_MONEY)
	elif workshop != null and is_instance_valid(workshop):
		var tint: Color = PackDrawerView.COLORS.get(Pack.shelf_of(pack), CasinoStyle.GOLD_INTENSE)
		travel = _fly_pack_to_magazine(workshop, pack.pack_uid,
			_charm_trail_source_px([index]), tint)
	await get_tree().create_timer(maxf(travel, 0.05)).timeout
	if phase != Phase.PAYOUT:
		return
	await get_tree().create_timer(CHARM_PAYOUT_STEP_INTERVAL).timeout

## Schmuckkästchen: je gefundener Material-Gravur ein Meteor vom Dock-Pad in die
## Material-Schublade, dicht gestaffelt wie die Frankiermaschine. Gebucht ist
## längst (Rundenabschluss) - die Salve zeigt nur, was dazugekommen ist.
func _play_jewelry_box_meteors(index: int, copy: int) -> void:
	var mine: Array[Dictionary] = []
	for grant in _jewelry_box_upgrades:
		if int(grant["copy"]) == copy:
			mine.append(grant)
	if mine.is_empty():
		return
	_flash_charm_and_pad(index)
	var from_px := _charm_trail_source_px([index])
	var travel := 0.0
	for i in mine.size():
		var grant: Dictionary = mine[i]
		if i == 0:
			travel = _fire_jewelry_box_meteor(grant, from_px, index)
		else:
			get_tree().create_timer(float(i) * STAMP_METEOR_GAP).timeout.connect(func() -> void:
				if phase == Phase.PAYOUT:
					_fire_jewelry_box_meteor(grant, from_px, index))
	var last_arrival := float(maxi(0, mine.size() - 1)) * STAMP_METEOR_GAP + maxf(travel, 0.05)
	await get_tree().create_timer(last_arrival).timeout
	if phase != Phase.PAYOUT:
		return
	await get_tree().create_timer(CHARM_PAYOUT_STEP_INTERVAL).timeout

## EIN Meteor der Salve: Dock-Pad -> Magazin-Platz seines Pakets. Das
## Schmuckkästchen schenkt ein FIXINHALT-PAKET, kein loses Stück - die Kassette
## bleibt verdeckt, bis das Licht ankommt. Liefert die Flugzeit.
func _fire_jewelry_box_meteor(grant: Dictionary, from_px: Vector2, index := -1) -> float:
	var workshop: WorkshopView = table_screen.workshop_window if table_screen != null else null
	var pack: Pack = grant.get("pack")
	if pack == null:
		# Volles Magazin: der Fund ist zu Geld zerfallen und fährt als Geld los -
		# der Betrag gehört ehrlich in die Zeile SEINES Charms.
		_ledger_money("charm_%d" % index, _charm_name(index), GameRun.PACK_FIZZLE_MONEY)
		return _fly_pack_fizzle(from_px, GameRun.PACK_FIZZLE_MONEY, true)
	if workshop == null or not is_instance_valid(workshop):
		return 0.0
	var material := DieMaterial.by_id(String(grant.get("material_id", "")))
	var tint := material.tint if material != null else CasinoStyle.GOLD
	workshop.expect_pack_delivery(pack.pack_uid)
	var travel := table_screen.charm_engraving_comet(from_px,
		_pack_arrival_px(workshop, pack.pack_uid), tint)
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		_land_pack_in_magazine(workshop, pack.pack_uid, tint))
	return travel

## Dynamo: die geräumte Runde prägt eine Energie. Gebucht ist sie, bevor das
## Licht startet - der Komet fliegt nur hinterher (book first, fly afterwards),
## darum die reine Anzeige-Salve.
func _play_dynamo_energy(index: int, count: int) -> void:
	if count <= 0:
		return
	run.add_energy(count)
	_ledger_energy(count)
	_flash_charm_and_pad(index)
	_play_deal_energy_volley(count)
	await get_tree().create_timer(CHARM_PAYOUT_STEP_INTERVAL).timeout

## EIN Geld-Charm zahlt sichtbar: Pad blitzt, "+N$" steigt am Pad auf, und der
## Betrag fährt als ECHTE Chip-Pakete (Stückelung 1/5/25/100, je in seiner
## Chipfarbe) dicht gestaffelt vom Pad zur Schatztruhe - jedes Paket bucht
## SEINEN Wert bei Ankunft (das generische Geld-Licht ist unterdrückt, die
## Pakete SIND die Gutschrift). Gewartet wird auf die letzte Ankunft.
## guard: Phase, die die Zeremonie trägt - ein Wechsel (Reset) bricht sie ab.
## Der Goldrausch zahlt beim Nehmen und hält solange SCORING.
func _play_charm_money_payout(index: int, amount: int, guard: Phase = Phase.PAYOUT) -> void:
	_flash_charm_and_pad(index)
	var from_px := _charm_trail_source_px([index])
	table_screen.spawn_gain_number(from_px, "+%d$" % amount, TableScreen.SIDE_MONEY_COLOR)
	var values := ChipStackView.split_gain(amount)
	# Die Auszahlungs-Seite hört an DERSELBEN Ankunft, die bucht - keine zweite Uhr.
	var caption := _charm_name(index)
	var on_book := func(value: int) -> void:
		_ledger_money("charm_%d" % index, caption, value)
	var travel := 0.0
	for i in values.size():
		var value: int = values[i]
		if i == 0:
			travel = _fire_charm_money_packet(from_px, value, guard, on_book)
		else:
			get_tree().create_timer(float(i) * MONEY_PULSE_GAP).timeout.connect(func() -> void:
				if phase == guard:
					_fire_charm_money_packet(from_px, value, guard, on_book))
	var last_arrival := float(maxi(0, values.size() - 1)) * MONEY_PULSE_GAP + maxf(travel, 0.05)
	await get_tree().create_timer(last_arrival).timeout
	if phase != guard:
		return
	await get_tree().create_timer(CHARM_PAYOUT_STEP_INTERVAL).timeout

## Schickt EIN Chip-Paket vom Dock-Pad los und bucht seinen Wert bei ANKUNFT.
## Liefert die Flugzeit.
func _fire_charm_money_packet(from_px: Vector2, value: int, guard: Phase = Phase.PAYOUT,
		on_book := Callable()) -> float:
	var chip_color := ChipStackView.denomination_color(value)
	var travel: float = table_screen.charm_money_comet(from_px, _money_trail_color(chip_color))
	_book_money_packet_on_arrival(travel, value, chip_color, guard, on_book)
	return travel

## Name des Charms an Dock-Platz index - die Beschriftung seiner Ledger-Zeile.
func _charm_name(index: int) -> String:
	if run == null or index < 0 or index >= run.owned_charms.size():
		return "Charm"
	return run.owned_charms[index].display_name

## Bucht den Wert eines Chip-Pakets bei ANKUNFT (Truhe glimmt, Einzahlungs-
## Schlitz blitzt in der Chipfarbe). Das generische Geld-Licht bleibt aus: die
## Pakete SIND die Gutschrift.
func _book_money_packet_on_arrival(travel: float, value: int, chip_color: Color, guard: Phase,
		on_book := Callable()) -> void:
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		if phase != guard:
			return
		_suppress_money_light = true
		run.add_money(value)
		_suppress_money_light = false
		if on_book.is_valid():
			on_book.call(value)
		if table_screen.treasure_window != null:
			table_screen.treasure_window.glint()
			table_screen.treasure_window.flash_receive_slot(chip_color))

## Geld EINER Zündung (Goldseite, Seelen-Geld): die Summe fährt als ECHTE
## Chip-Pakete dicht gestaffelt AUS DER GRUBE über die Zug-Bahn in die Truhe,
## jedes bucht seinen Wert bei Ankunft. Bewusst nicht abgewartet - die nächste
## Zündung muss nur NACH dem Start kommen, nicht nach der Ankunft.
## Die Zahl STEIGT aus dem Würfel auf - Geld kommt aus ihm heraus, Basis und Mult
## fallen weiter herab.
func _fire_die_money(from_px: Vector2, amount: int) -> void:
	if table_screen == null or amount <= 0:
		return
	table_screen.spawn_gain_number(from_px, "+%d$" % amount, TableScreen.SIDE_MONEY_COLOR, 1.0, true)
	var values := ChipStackView.split_gain(amount)
	for i in values.size():
		var value: int = values[i]
		if i == 0:
			_fire_die_money_packet(from_px, value)
		else:
			get_tree().create_timer(float(i) * MONEY_PULSE_GAP).timeout.connect(func() -> void:
				if phase == Phase.SCORING:
					_fire_die_money_packet(from_px, value))

## Ein Chip-Paket aus der Grube - dieselbe Buchung wie am Dock-Pad, nur reist es
## die Zug-Bahn (Grube -> Hub -> Geld-Leiste -> Truhe).
func _fire_die_money_packet(from_px: Vector2, value: int) -> void:
	var chip_color := ChipStackView.denomination_color(value)
	var travel: float = table_screen.take_money_comet(_money_trail_color(chip_color), from_px)
	_book_money_packet_on_arrival(travel, value, chip_color, Phase.SCORING)

## Geld eines Zuges, das NICHT an einer Zündung hängt (Zyanidgas/Scheidewasser,
## Neonmarker, Streulicht, Lumpensammler, Jackpotglocke): EIN Komet trägt den
## Rest von der Grube zur Truhe. Rein visuell - gebucht ist beim Nehmen, die
## Ankunft glimmt nur (book first, fly afterwards).
func _play_take_money_comet(amount: int) -> void:
	if amount <= 0 or table_screen == null:
		return
	var launched := run
	var packets := ChipStackView.split_gain(amount)
	var chip_color := ChipStackView.denomination_color(packets[0] if not packets.is_empty() else 1)
	var travel: float = table_screen.take_money_comet(_money_trail_color(chip_color))
	if travel <= 0.0:
		return
	get_tree().create_timer(travel).timeout.connect(func() -> void:
		if run != launched or table_screen == null or table_screen.treasure_window == null:
			return
		table_screen.treasure_window.glint()
		table_screen.treasure_window.flash_receive_slot(chip_color))

## Die Frankiermaschine schickt ihre 1er-Pakete als dichte Meteor-Salve auf
## die Adern: die Starts folgen im STAMP_METEOR_GAP-Takt, ohne auf die vorige
## Ankunft zu warten - jedes Paket liegt erst bei SEINER Ankunft im Lager
## (der Meteor ist das Paket, nicht seine Ankündigung).
func _play_stamp_machine_meteors(index: int) -> void:
	_flash_charm_and_pad(index)
	var from_px := _charm_trail_source_px([index])
	var launched := run
	var travel := 0.0
	for i in GameRun.STAMP_PACKS:
		var pack := run.roll_stamp_pack()
		if i == 0:
			travel = _fire_charm_pack(pack, from_px, index)
		else:
			get_tree().create_timer(float(i) * STAMP_METEOR_GAP).timeout.connect(func() -> void:
				if run == launched and phase == Phase.PAYOUT:
					_fire_charm_pack(pack, from_px, index))
	var last_arrival := float(GameRun.STAMP_PACKS - 1) * STAMP_METEOR_GAP + maxf(travel, 0.05)
	await get_tree().create_timer(last_arrival).timeout
	if phase != Phase.PAYOUT:
		return
	await get_tree().create_timer(CHARM_PAYOUT_STEP_INTERVAL).timeout

## Schickt EIN versiegeltes Paket über die Werkstatt-Ader ins Magazin und bucht es
## bei ANKUNFT; dort steigt es als Kassette durch die Fläche. Liefert die Flugzeit.
## Die Ankunft vergleicht die Lauf-INSTANZ, nicht nur die Phase: ein "Neues Spiel"
## im Flug bekäme sonst das Paket des alten Laufs gutgeschrieben.
func _fire_charm_pack(pack: Pack, from_px: Vector2, index := -1) -> float:
	if table_screen == null or table_screen.workshop_window == null:
		run.grant_pack(pack)  # ohne Display: still buchen, nichts verlieren
		return 0.0
	if run.packs_full():
		# Volles Magazin: das Paket zerfällt zu Geld - erst buchen, dann fliegt es
		# als Geld in die Truhe statt als Kassette zur Werkbank.
		run.grant_pack(pack)
		_ledger_money("charm_%d" % index, _charm_name(index), GameRun.PACK_FIZZLE_MONEY)
		return _fly_pack_fizzle(from_px, GameRun.PACK_FIZZLE_MONEY, true)
	var launched := run
	var workshop := table_screen.workshop_window
	var tint: Color = PackIconRenderer.COLORS.get(pack.type, TableScreen.SIDE_ENGRAVING_COLOR)
	# Das Paket entsteht erst bei der Ankunft, hat also noch keine uid: gezielt wird
	# auf den Platz, auf dem die NÄCHSTE Lieferung landet.
	var travel := table_screen.pack_delivery_comet(from_px, tint,
		workshop.arrival_anchor_px())
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		if run != launched or phase != Phase.PAYOUT or table_screen == null:
			return
		# Gebucht wird bei Ankunft - die Kassette steigt danach durch die Fläche,
		# statt auf ihrem Platz aufzuploppen.
		var stashed := run.grant_pack(pack)
		if stashed != null:
			_rising_packs[stashed.pack_uid] = true
			if is_instance_valid(workshop):
				table_screen.pack_arrival_flash(
					_pack_arrival_px(workshop, stashed.pack_uid), tint)
		table_screen.celebrate_workshop_delivery(tint))
	return travel

## Bank-Entladung: EIN Bank-Komet je geräumter STUFE (oberste zuerst), aus dem
## Zielbalken um die Grube in den Hub. Jede Ankunft entlädt den Balken eine Stufe
## und bucht, was GENAU DIESE Stufe geprägt hat - mit dem Doppellader zwei ⚡
## statt einer, nie zwei Kometen: doppelt so viele Einschläge läsen sich, als hätte
## der Spieler doppelt so viele Stufen geräumt.
## Was in die Börse passt, ist in energy_split vorausgeplant: die ersten stored
## ⚡ der Reihe. Eine Stufe kann darum GETEILT ankommen (ein Teil Energie, der
## Rest Geld) - genau dann, wenn die Börse mittendrin volläuft.
func _play_bank_discharge(base_blind: int, stored: int, overflow: int, cleared_stages: int,
		hub: HubView) -> void:
	var comets := cleared_stages
	if comets <= 0:
		return
	var per_stage := maxi(1, run.energy_per_stage())
	var vein := run.gold_vein_income()
	var gap := BANK_STAGE_GAP_START
	var minted := 0
	for k in range(comets, 0, -1):
		# Die ⚡ DIESER Stufe: erst was noch in die Börse passt, der Rest bar.
		var energys := clampi(stored - minted, 0, per_stage)
		var cash := per_stage - energys
		# Balken auf die verbleibenden Stufen schrumpfen (in der nächst-tieferen Farbe).
		var remaining_frac := float(k - 1) / float(comets)
		table_screen.drain_goal_bar(remaining_frac, table_screen.stage_fill_color(maxi(k - 1, 1)),
			BANK_BAR_DRAIN_TIME)
		var color := ENERGY_COMET_COLOR if energys > 0 else table_screen.stage_fill_color(k)
		var travel: float = table_screen.bank_comet(color)
		await get_tree().create_timer(travel).timeout
		if phase != Phase.PAYOUT:
			return  # Spiel während der Auszahlung zurückgesetzt
		if hub != null:
			hub.flash_frame(color)
		if energys > 0:
			# Zweite Etappe: vom Hub über die Schatz-Leiste zur Kondensator-Bank.
			# Bewusst NICHT abgewartet - die nächste Stufe startet sofort, wie bei
			# der Frankiermaschinen-Salve; gebucht wird bei der ANKUNFT.
			_fly_energy_to_capacitor(true, energys)
		if cash > 0:
			run.add_money(base_blind * cash)
			_ledger_money("overflow", "Speicher voll", base_blind * cash)
		minted += per_stage
		if vein > 0:
			run.add_money(vein)  # Goldader: je geräumter Stufe, nicht je Energie
			_ledger_money("gold_vein", "Goldader", vein)
		await get_tree().create_timer(gap).timeout
		gap = maxf(BANK_STAGE_GAP_MIN, gap * BANK_STAGE_GAP_DECAY)

## EINEN Kometen vom Hub zur Kondensator-Bank schicken: über die Hub-Cluster-Ader,
## an deren Eintritt die Bank steht. Gebucht wird bei der Ankunft (dort pulsen
## Bank und Börsen-Anzeige), damit die Zahl mit dem Licht steigt.
## amount = was DIESER Komet trägt: der Doppellader prägt zwei ⚡ je Stufe,
## und die reisen in EINEM Licht - eine Stufe, ein Einschlag.
## book = false: die Energie ist schon gebucht (Sofort-Klausel), es fliegt nur
## das Licht - sonst zählte dieselbe ⚡ zweimal.
func _fly_energy_to_capacitor(book: bool = true, amount: int = 1) -> void:
	var launched := run
	var travel := 0.0
	if table_screen != null and capacitor_bank != null:
		travel = table_screen.energy_comet(
			table_screen.world_to_pixel(capacitor_bank.global_position), ENERGY_COMET_COLOR)
	if travel <= 0.0:
		if book:
			run.add_energy(amount)  # ohne Display still buchen, nichts verlieren
		return
	get_tree().create_timer(travel).timeout.connect(func() -> void:
		if run != launched or (book and phase != Phase.PAYOUT):
			return  # Lauf während des Flugs zurückgesetzt
		if book:
			run.add_energy(amount)
			_ledger_energy(amount)  # book=false sind Sofort-Klauseln, nicht die Runde
		if capacitor_bank != null:
			capacitor_bank.pulse()
		if table_screen != null and table_screen.hub != null:
			table_screen.hub.pulse_energy())

## Sofort-Energie eines Vertrags (Startkapital & Co.): je ⚡ ein Komet, dicht
## gestaffelt wie die Frankiermaschinen-Salve. Reine Anzeige - gebucht hat
## GameRun mit der Unterschrift, hier wird NICHTS gebucht.
func _play_deal_energy_volley(count: int) -> void:
	if count <= 0 or table_screen == null:
		return
	var launched := run
	for i in count:
		if i == 0:
			_fly_deal_energy()
		else:
			get_tree().create_timer(float(i) * STAMP_METEOR_GAP).timeout.connect(func() -> void:
				if run == launched:
					_fly_deal_energy())

## EINE unterschriebene Energie: dieselben zwei Etappen wie die Überladungs-
## Auszahlung (Bank-Ader in den Hub, dann Hub-Cluster-Ader zur Bank) - jedes ⚡
## erreicht die Börse auf demselben Weg.
func _fly_deal_energy() -> void:
	var launched := run
	var travel := table_screen.bank_comet(ENERGY_COMET_COLOR)
	if travel <= 0.0:
		_fly_energy_to_capacitor(false)
		return
	get_tree().create_timer(travel).timeout.connect(func() -> void:
		if run != launched:
			return
		if table_screen.hub != null:
			table_screen.hub.flash_frame(ENERGY_COMET_COLOR)
		_fly_energy_to_capacitor(false))

## Auszahlung je noch ungezogenem Würfel, in STAPEL-Reihenfolge: normal überall
## per_die, mit Knallgas wächst der Satz hinter jedem Knallgas-Würfel.
func _leftover_die_payouts(per_die: int, ids: Array[String], entries: Array) -> Array[int]:
	var souls: Array[String] = []
	for entry in entries:
		souls.append((entry["def"] as DieDefinition).essence_id)
	return EssenceEffects.leftover_die_payouts(souls, per_die, ids)

## Alle ÜBRIGEN Würfel der Runde (Zieh-Reihenfolge): die noch nicht gezogenen
## (Warteschlange, dann Pool) UND die noch UNGEWERTET in der Grube liegenden. Die
## Grubenwürfel zählen genau dann mit, wenn der Spieler die Runde per "Beenden"
## beendet, ohne die Hand genommen zu haben - genommen wird die Grube geleert, hier
## liegt also nichts Doppeltes. Jeder Eintrag trägt seine Def (Seele fürs Fuchsfeuer,
## Schmuckkästchen), seine Anzeige (Blitz) und seinen Ton.
func _unused_die_entries() -> Array:
	var entries: Array = []
	for tray in [queue_tray_view, pool_tray_view]:
		for i in tray.slot_roots.size():
			if not tray.slot_roots[i].visible:
				continue
			var def: DieDefinition = tray.slot_defs[i]
			var disp: DieFaceDisplay = tray.slot_face_displays[i]
			entries.append({"def": def, "display": disp, "scale": disp.scale,
				"tint": DiceController.KIND_TINTS.get(def.style_id, Color.WHITE)})
	# Die Grubenwürfel werden von LINKS nach RECHTS gezählt: der Tisch liest +Z als
	# rechts (die Tray-Slots laufen so, siehe DiceTrayView), also aufsteigend nach z.
	var pit: Array[int] = []
	for i in dice.count():
		if i < active_kinds.size() and dice.roots[i].visible:
			pit.append(i)
	pit.sort_custom(func(a: int, b: int) -> bool:
		return dice.bodies[a].global_position.z < dice.bodies[b].global_position.z)
	for i in pit:
		var def: DieDefinition = active_kinds[i]
		var disp: DieFaceDisplay = dice.face_displays[i]
		entries.append({"def": def, "display": disp, "scale": disp.scale,
			"tint": DiceController.KIND_TINTS.get(def.style_id, Color.WHITE)})
	return entries

## Würfel-Blitz beim Auszahlen: schneller Anstieg auf überstrahltes Gold plus
## Pop, langsameres Abklingen - läuft im Hintergrund (Welle statt Warten).
func _flash_die_tint(display: DieFaceDisplay, original_tint: Color, base_scale: Vector3 = Vector3.ONE) -> void:
	var tint_tween := create_tween()
	tint_tween.tween_method(display.set_tint, original_tint, DIE_FLASH_PEAK_COLOR, DIE_FLASH_RAMP_UP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tint_tween.tween_method(display.set_tint, DIE_FLASH_PEAK_COLOR, original_tint, DIE_FLASH_RAMP_DOWN) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# base_scale = Ruhegröße der Anzeige (Grubenwürfel sind auf Tray-Größe skaliert).
	var scale_tween := create_tween()
	scale_tween.tween_property(display, "scale", base_scale * DIE_FLASH_SCALE, DIE_FLASH_RAMP_UP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(display, "scale", base_scale, DIE_FLASH_RAMP_DOWN) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_debug_win_round_pressed() -> void:
	if not _is_playing():
		return
	hand_total = run.effective_goal()
	_on_round_complete()  # setzt die Phase - stoppt auch einen laufenden Wurf

## Debug: +100$ je Klick (Menü bleibt offen für Mehrfach-Klick).
func _on_debug_money_pressed() -> void:
	if run != null:
		run.add_money(100)

## Debug-Energie, ohne Zeremonie: gebucht wird direkt in die Börse, denn der
## Komet gehört zu einer Wirkung, und hier gibt es keine. Der Deckel gilt weiter -
## was nicht mehr hineinpasst, verfällt (kein Überlauf-Geld wie beim Kupfer).
func _on_debug_energy_pressed() -> void:
	if run != null:
		run.add_energy(10)

## Sichtbarkeit der Spiel-UI nach Spielzustand (false während Shop/GameOver).
func _set_gameplay_ui_visible(is_visible: bool) -> void:
	gameplay_ui_state_visible = is_visible
	_update_gameplay_ui_visibility()

func _on_camera_mode_changed(new_mode: CameraRig.Mode) -> void:
	is_pit_focused = new_mode == CameraRig.Mode.PIT
	# Wer von der ENGEN Tausch-Frage wegfährt, hat abgebrochen gemeint: der Vorrat
	# steigt unverändert wieder herauf - und die gemerkte Station wird VERGESSEN,
	# sonst risse der Rückflug eine schon laufende Fahrt zurück. Der eigene enge
	# Rahmen meldet keinen Wechsel und kommt hier gar nicht an. Der DAUER-Modus des
	# Umschalters überlebt den Wechsel: das Raster gehört dem Vorrat, nicht der
	# Station - es geht durch die Taste oder den Rechtsklick wieder zu.
	if _deck_glass and not _deck_glass_pinned:
		_deck_glass_home = {}
		_close_deck_glass()
	# Wer aus der INSPEKTION wegzoomt, hat sie zugeklappt gemeint - das Zuhause wird
	# VERGESSEN, der Spieler ist schon unterwegs. Der eigene Fokus-Rahmen meldet
	# keinen Wechsel und kommt hier gar nicht an. Die ZIELWAHL überlebt den Wechsel:
	# das Podest gehört seit der Bühnen-Straße dem Fenster, nicht der Station.
	_die_focus_home = {}
	_sync_screen_reflection()
	# Wer mit offenem Lexikon wegfährt, hat es zugeklappt gemeint: hart zu, ohne
	# Rückflug (der Spieler ist schon unterwegs). Hart und VOR der Laden-Logik
	# unten, damit die Seitenregel einen verdrängten Laden JETZT zurückholt und
	# die Grubenfahrt ihn noch als offen sieht.
	if lexikon_view != null and lexikon_view.visible \
			and new_mode != CameraRig.Mode.HUB and new_mode != CameraRig.Mode.TITLE:
		lexikon_view.visible = false
	# Wer aus dem Laden in die Grube fährt, hat "Fertig" gemeint: der Laden macht
	# zu und die neue Runde steht - sonst säße der Spieler vor gesperrten Knöpfen.
	# Synchron, damit Nachschub-Tray und Vertragsauslage unten dieselbe Fahrt noch
	# erwischen.
	if is_pit_focused and phase == Phase.SHOP and charm_shop != null:
		charm_shop.close()
	# Beim ERSTEN Grubenzoom einer Runde materialisiert das Nachschub-Tray - aber
	# erst nach der Unterschrift: vor dem Vertrag fährt nichts auf.
	if is_pit_focused and not queue_activated and not route_pending and _is_playing():
		_activate_queue()
	# ...und dort wartet auch die Vertragswahl: der Spieler nimmt die Runde auf,
	# das Haus legt seine Konditionen auf den Tisch.
	if is_pit_focused and route_pending and phase == Phase.IDLE \
			and (route_choice == null or not route_choice.visible):
		_open_route_choice()
	# Der Zielwürfel gehört auf die Bühne, solange der Spieler an der Werkstatt steht:
	# das VERLASSEN bringt ihn an seinen Pool-Sitz zurück - derselbe Weg rückwärts.
	_sync_bench_migration()
	# Übertaktet wird nur vor den Chips - und dort jederzeit.
	_sync_combo_upgrade_buttons()
	_update_gameplay_ui_visibility()

## Aktiviert das Nachschub-Tray dieser Runde (einmalig): die nächsten Würfel
## wandern aus dem Dice-Tray hierher.
func _activate_queue() -> void:
	queue_activated = true
	_refresh_deck_trays()

## Der Hand-Hinweistext ist nur in der fokussierten Grubensicht sichtbar;
## die Display-Buttons steuern sich selbst (_sync_screen_action_buttons).
func _update_gameplay_ui_visibility() -> void:
	var show_ui := gameplay_ui_state_visible and is_pit_focused
	hand_label.visible = show_ui

# --- Reaktionen auf Laden und Werkbank --------------------------------------
# Käufe und Setzungen mutieren den GameRun direkt; die Anzeigen folgen über die
# Run-Signale. Hier nur Reaktionen, die echte Szenen-Arbeit brauchen.

## Ein Pool-Würfel hat sich geändert (Kauf, Paket, Gravur, Nehmen-Effekt,
## Testmodus): alle Anzeigen, die eine Würfel-Instanz zeigen, ziehen nach. Die
## Instanzen werden nie getauscht (GameRun.become), also reicht Neuzeichnen.
func _on_pool_changed() -> void:
	# Vor dem Zurren IST der Stapel der Pool: ein Anordnen (reorder_pool) muss
	# darum sofort in den Trays stehen. Danach ist er gemischt und unantastbar -
	# außer im Laden, wo die Runde vorbei ist und schlicht alles im Tray liegt.
	if not round_committed and next_draw_index == 0:
		round_pool_kinds = run.owned_pool.duplicate()
		_refresh_dice_trays()
	elif phase == Phase.SHOP:
		_refresh_dice_trays()
	pool_tray_view.refresh_faces()
	queue_tray_view.refresh_faces()
	dice.refresh_faces()  # die liegenden Grubenwürfel zeigen sonst alte Augen
	_refresh_bench_stage_faces()  # die Bühne hält eine geteilte Instanz
	_sync_transform_previews()  # refresh_faces malte gerade den rohen Wert zurück
	# Die Info-Säule hält eine GETEILTE Instanz: die Signatur sähe die Gravur nicht.
	if table_screen != null and table_screen.fach_net_window != null \
			and is_instance_valid(table_screen.fach_net_window):
		table_screen.fach_net_window.refresh()
		_sync_fach_nets()
	if _deck_glass:
		_show_deck_glass_window()  # das Raster auf dem Glas folgt der Buchung
	_refresh_charging_column()

## Shop geschlossen. Beim ERSTEN Mal beginnt damit die nächste Runde; ein
## Wieder-Eintritt (Hub-Knopf) macht beim Schließen nur die Anzeige zu. Nur der
## "Fertig"-Knopf fährt zurück in die Übersicht (dort ist das Wettannahme-Fenster
## im Blick); wer den Laden per Grubenzoom verlässt, ist schon unterwegs und
## bleibt es.
func _on_shop_closed() -> void:
	# Zwei Modi: das ERSTE Schließen eines Besuchs zieht die Runde weiter, ein
	# Wieder-Eintritt macht nur die Anzeige zu. Sonst rückte jeder Blick in den
	# Laden die Runde eine Stelle vor.
	var reopened := shop_reopened
	shop_reopened = false
	phase = Phase.IDLE
	# Die Anzeige kehrt über die Bucht zurück; die Ware bleibt wortlos unten stehen.
	_sync_vitrine_curtain()
	if reopened:
		_set_gameplay_ui_visible(true)
		_sync_editing_lock()
		_refresh_dice_trays()
		_sync_shop_reopen_button()
		if camera_rig.mode == CameraRig.Mode.HUB:
			camera_rig.zoom_out()
		return
	run.advance_round()  # würfelt zugleich die Auslage der neuen Runde
	_set_gameplay_ui_visible(true)
	if camera_rig.mode == CameraRig.Mode.HUB:
		camera_rig.zoom_out()
	_start_new_round()
	# Erst NACH dem Rundenstart (der die Sperren zurücksetzt): ab hier steht der
	# Knopf, bis die Runde festgezurrt ist.
	shop_reopen_allowed = true
	_sync_shop_reopen_button()

## Der Laden macht noch einmal auf - dieselbe Auslage, kein neuer Wurf, kein
## zweites Freispiel und keine neue Wettannahme (die gehören dem Besuch).
func _on_shop_reopen_requested() -> void:
	if run == null or not shop_reopen_allowed or phase != Phase.IDLE or charm_shop == null:
		return
	shop_reopened = true
	phase = Phase.SHOP
	_sync_editing_lock()
	_set_gameplay_ui_visible(false)
	_return_dice_to_pool_tray()
	_sync_shop_reopen_button()
	if camera_rig.mode != CameraRig.Mode.HUB:
		camera_rig.zoom_to(CameraRig.Mode.HUB)
	charm_shop.reopen()
	_sync_shop_vitrine(true)

## Zeigt den Laden-Knopf genau im Vorlauf der Runde (Laden zu, noch nichts
## unterschrieben) - sonst nie.
func _sync_shop_reopen_button() -> void:
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_shop_reopen_visible(shop_reopen_allowed and phase == Phase.IDLE)

## Öffnet das Lexikon auf entry_id ("" = Index) und merkt sich die Herkunft:
## Schließen fliegt dorthin zurück. Kamera und Seite starten im selben Frame,
## nicht awaited - das Muster des Laden-Wieder-Eintritts. Die Seitenregel
## verdrängt einen offenen Laden und holt ihn beim Schließen zurück (LIFO);
## ShopController.closed feuert dabei nie, die Runde rückt also nicht vor.
func open_lexikon(entry_id := "") -> void:
	if lexikon_view == null or table_screen == null or table_screen.hub == null:
		return
	var fresh := not lexikon_view.visible
	if fresh:
		lexikon_prev_mode = camera_rig.mode
		table_screen.hub.fade_page_in(lexikon_view)
	if entry_id.is_empty():
		lexikon_view.show_index()
	elif fresh:
		# Schlüsselwort-Klick von außen: ein Rechtsklick führt zurück ins Spiel.
		lexikon_view.open_landing(entry_id)
	else:
		lexikon_view.open_entry(entry_id)
	if camera_rig.mode != CameraRig.Mode.HUB:
		camera_rig.zoom_to(CameraRig.Mode.HUB)

## Klappt das Lexikon zu und fliegt zur Herkunft zurück - aber nur, wenn die
## Kamera wirklich noch am Hub steht (die Regel von _on_shop_closed: eine
## laufende Fahrt wird nie zurückgerissen).
func _close_lexikon() -> void:
	if lexikon_view == null or not lexikon_view.visible:
		return
	table_screen.hub.fade_page_out(lexikon_view)  # LIFO holt ggf. den Laden zurück
	if camera_rig.mode == CameraRig.Mode.HUB and lexikon_prev_mode != CameraRig.Mode.HUB:
		if lexikon_prev_mode == CameraRig.Mode.OVERVIEW:
			camera_rig.zoom_out()
		else:
			camera_rig.zoom_to(lexikon_prev_mode)

## Spielende auf dem Display: die Ende-Karte des Titel-HUDs übernimmt die
## Hub-Fläche, die Kamera fährt in die Nahsicht. Ohne Display bleibt das
## 2D-Panel als Rückfall.
func _show_game_over(total: int) -> void:
	_set_gameplay_ui_visible(false)
	if title_view == null:
		game_over_label.text = "Benchmark verfehlt: %d / %d Punkte.\nSpiel vorbei – klicke 'Neues Spiel' zum Neustart." % [total, run.effective_goal()]
		game_over_panel.visible = true
		return
	title_view.show_game_over(total, run.effective_goal(), run.round_number)
	table_screen.hub.fade_page_in(title_view)
	camera_rig.show_title()

func _refresh_ui() -> void:
	if log_open:
		return  # der gestellte Tisch gehört der Chronik
	_refresh_round_hud()
	_sync_transform_previews()

	if not has_rolled_current_hand:
		# Nur transiente Meldungen (Farkle/Anker o.Ä.), sonst leer.
		hand_label.text = hand_note
		_refresh_combos("")
		if phase != Phase.SCORING:
			table_screen.update_pit_score(0, 0)
	else:
		# Die Dauerzahlen über der Grube zeigen die Kombination der gewerteten
		# Würfel (mit Vollzähler die ganze Grube) und springen beim Um-/Abwählen
		# sofort mit; keine gewerteten = keine Hand (0 / 0).
		hand_label.text = ""
		var slots := _hand_slots()
		if slots.is_empty():
			_refresh_combos("")
			if phase != Phase.SCORING:
				table_screen.update_pit_score(0, 0)
		else:
			var all_materials := _rolled_materials()
			var sel_values: Array[int] = []
			var sel_materials: Array[String] = []
			for s in slots:
				sel_values.append(dice.values[s])
				sel_materials.append(all_materials[s])
			var hand := DiceScoring.best_hand(sel_values, run.charm_ids(), hands_taken_this_round == 0, sel_materials, run.combo_levels, _score_ctx_for_slots(slots))
			_refresh_combos(hand["key"])
			if phase != Phase.SCORING:
				table_screen.update_pit_score(
					DiceScoring.points_for(hand["key"], run.combo_levels),
					DiceScoring.mult_for(hand["key"], run.combo_levels))

## Verwandlungs-Charms (Glückszigaretten & Co.) am liegenden Würfel sichtbar
## machen: die obere Seite zeigt den WIRKSAMEN Wert in Grün - dieselbe Grammatik
## wie die Gravur-Vorschau an der Werkbank ("grün = steht nicht in der Def").
## Rein Anzeige; gewertet wird der verwandelte Wert ohnehin schon.
## Während des Zählens schweigt die Vorschau: dort führt der Wertwandel
## zwischen den Aktivierungen die Anzeige (siehe _play_die_pulse).
func _sync_transform_previews() -> void:
	if dice == null or run == null or phase == Phase.SCORING or log_open:
		return  # im Rückblick führen die aufgezeichneten laufenden Werte
	var ids := run.charm_ids()
	var sets := _effective_essence_sets()
	var overrides := {}
	for i in dice.count():
		if not dice.roots[i].visible or not dice.settled[i] or dice.face_indices[i] < 0:
			continue
		# Verwandlung UND Essenz-Linse (Wasserstoff verdoppelt) - was die Wertung
		# sieht, steht auch auf dem Würfel.
		var effective := DiceScoring.shown_value(dice.values[i], ids, EssenceEffects.set_at(sets, i))
		if effective != dice.values[i]:
			overrides[i] = effective
	dice.set_value_overrides(overrides)

## Statische Teile der Runden-Anzeige; der Punktestand läuft separat animiert
## über _animate_points_to. Harmlos bei Mehrfachaufruf ohne Änderung.
func _refresh_round_hud() -> void:
	_sync_goal_bar(displayed_points)
	_refresh_hub_info()

## Zählt den Punktestand sichtbar zu target hoch (Balatro-artig) statt zu
## springen; animate=false für den harten Rundenreset auf 0.
func _animate_points_to(target: int, animate: bool = true) -> void:
	if points_tween:
		points_tween.kill()
	if not animate:
		_set_displayed_points(target)
		return
	points_tween = create_tween()
	points_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	points_tween.tween_method(_set_displayed_points, displayed_points, target, 0.6)

func _set_displayed_points(value: int) -> void:
	displayed_points = value
	_sync_goal_bar(value)

## Übergibt den Balken den Überladungs-Fortschritt bei points (Stufe, Punkte in
## der Stufe, Stufengröße, gefüllte Stufen).
func _sync_goal_bar(points: int) -> void:
	if log_open:
		return  # der Balken zeigt den aufgezeichneten Stand
	var p := run.stage_progress(points)
	table_screen.set_goal_progress(p["into_stage"], p["stage_size"], p["stage"], p["cleared"])

#region Rückblick

## Der Anzeige-Block eines Moments: alles, was der Tisch zeigt, als reine Zahlen
## und Kopien. KEIN GameRun-Abzug - der Erinnerungs-Modus schreibt nie in den
## Lauf zurück, er malt nur die Anzeigen.
func _log_display_state() -> Dictionary:
	var queue_size := mini(_queue_display_capacity(), _remaining_in_pool())
	var pool_start := next_draw_index + _queue_display_capacity()
	return {
		"money": run.money,
		"energy": run.energy,
		"energy_cap": run.energy_cap(),
		"hand_total": hand_total,
		"round_number": run.round_number,
		"goal": run.stage_progress(hand_total).duplicate(),
		"combo_levels": run.combo_levels.duplicate(true),
		"throttled": run.throttled_combos.duplicate(),
		"spotlight": run.spotlight_combo,
		"deal_sides": run.active_deal_sides().duplicate(true),
		"queue_defs": RoundLog.copy_defs(round_pool_kinds.slice(next_draw_index, next_draw_index + queue_size)),
		"pool_defs": RoundLog.copy_defs(round_pool_kinds.slice(pool_start, round_pool_kinds.size())),
		"discard_defs": RoundLog.copy_defs(discarded_this_round),
		"discard_faces": discarded_faces_this_round.duplicate(),
	}

## Die liegende Grube als Chronik-Zeilen. Aufgezeichnet wird die SEITE, nicht nur
## der Wert: Material, Rune und Pointer hängen an ihr, und ein Wert kann auf
## mehreren Seiten stehen.
func _log_pit_state() -> Array[Dictionary]:
	var pit: Array[Dictionary] = []
	for i in dice.count():
		pit.append(RoundLog.pit_slot_record(dice.slot_defs[i], dice.face_indices[i],
			dice.values[i], dice.roots[i].visible, dice.selected[i]))
	return pit

func _log_entry_base(kind: String, label: String) -> Dictionary:
	return {
		"kind": kind,
		"hand_index": hands_taken_this_round,
		"label": label,
		"state": _log_display_state(),
		"pit": _log_pit_state(),
		"player_order": player_order.duplicate(),
	}

## Ein gefallener Wurf. Ein verziehener Fumble (Anker, Löschgas, Schornsteinfeger,
## Ankerklausel, Flickenteppich) ist auch einer - seine Notiz steht in der Zeile.
func _log_record_throw() -> void:
	if run == null:
		return
	var entry := _log_entry_base(RoundLog.ENTRY_THROW, "")
	entry["label"] = "Wurf: %s" % RoundLog.values_label(entry["pit"])
	if not hand_note.is_empty():
		entry["label"] += " — %s" % hand_note
	round_log.add_entry(entry)

## Der Zug, aufgezeichnet VOR jeder Buchung: die Schrittliste kommt aus der
## fertigen (schon auf echte Slots geremappten) Zerlegung, die Dock-Plätze der
## Charms reisen mit - der Erinnerungs-Modus fragt den Lauf nie nach ihnen.
func _log_begin_take(breakdown: Dictionary, key: String, ids: Array[String]) -> void:
	if run == null:
		return
	var entry := _log_entry_base(RoundLog.ENTRY_TAKE,
		"Zug: %s — %d Punkte" % [DiceScoring.label_for(key), int(breakdown["total"])])
	entry["breakdown"] = breakdown.duplicate(true)
	entry["steps"] = RoundLog.flatten(entry["breakdown"], ids)
	entry["charm_ids"] = ids.duplicate()
	entry["charm_slots"] = run.charm_slots().duplicate()
	entry["post_state"] = entry["state"].duplicate(true)
	round_log.add_entry(entry)

## Der Stand NACH den Buchungen des Zuges - der Ergebnis-Schritt zeigt ihn.
func _log_finish_entry() -> void:
	if run == null or round_log.is_empty():
		return
	round_log.entries[round_log.entries.size() - 1]["post_state"] = _log_display_state()

## Ein Ladungs-Ereignis (Aufladen, Durchbrennen, Entladen, Bucht): eine reine
## Pose-Zeile wie der Fumble - gebucht hat GameRun längst.
func _log_record_charge(text: String) -> void:
	if run == null or dice == null:
		return
	var entry := _log_entry_base(RoundLog.ENTRY_CHARGE, text)
	entry["post_state"] = entry["state"].duplicate(true)
	round_log.add_entry(entry)

func _log_record_farkle() -> void:
	if run == null:
		return
	var entry := _log_entry_base(RoundLog.ENTRY_FARKLE, "")
	entry["label"] = "Fumble: %s" % RoundLog.values_label(entry["pit"])
	entry["post_state"] = entry["state"].duplicate(true)
	round_log.add_entry(entry)

## Der Rückblick steht nur ZWISCHEN zwei Händen offen: die Grube ist leer, es
## gibt keine liegende Auswahl und keinen halben Zug, der zurückgestellt werden
## müsste. Eine unterschriftsreife Runde gehört den Vertragskarten.
func _log_can_open() -> bool:
	return run != null and phase == Phase.IDLE and not has_rolled_current_hand \
		and not route_pending and not round_log.is_empty()

func _on_log_button_pressed() -> void:
	if log_open:
		_close_round_log()
	elif _log_can_open():
		_open_round_log()

## Liste auf dem Grubenboden, Leiste auf dem Marken-Streifen am oberen Rand.
func _place_log_view() -> void:
	if log_view == null or table_screen == null or table_screen.pit_window == null:
		return
	var pit := Rect2(table_screen.pit_window.position, table_screen.pit_window.size)
	var inset := pit.size.x * ROUTE_CHOICE_INSET
	log_view.set_list_rect(Rect2(pit.position + Vector2(inset, inset),
		pit.size - Vector2(inset, inset) * 2.0))
	# Die Schritt-Leiste steht am oberen Grubenrand über die ganze Breite - der
	# Streifen der Deal-Marken sitzt links der Mitte und wäre viel zu schmal.
	log_view.set_bar_rect(Rect2(pit.position + Vector2(inset, inset),
		Vector2(pit.size.x - inset * 2.0, pit.size.y * LOG_BAR_HEIGHT)))

func _log_entry_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry in round_log.entries:
		rows.append({
			"label": String(entry.get("label", "")),
			"hand_index": int(entry.get("hand_index", 0)),
			"kind": String(entry.get("kind", "")),
		})
	return rows

func _open_round_log() -> void:
	if log_open or not _log_can_open():
		return
	_log_snapshot_live_pit()
	log_open = true  # ab hier schweigen die Anzeigen-Schreiber je Frame
	log_cursor = Vector2i(-1, 0)
	_log_posed_entry = -1
	if table_screen != null:
		table_screen.set_memory_veil(true)
		table_screen.move_child(log_view, table_screen.get_child_count() - 1)  # über den Schleier
	_place_log_view()
	log_view.open(_log_entry_rows())

## Spiegel der lebenden Grube. Die Defs reisen als REFERENZ mit - die Grube muss
## nach dem Rückblick wieder auf dieselben Instanzen zeigen wie der Pool.
func _log_snapshot_live_pit() -> void:
	var slots: Array[Dictionary] = []
	for i in dice.count():
		slots.append({
			"def": dice.slot_defs[i],
			"transform": dice.bodies[i].global_transform,
			"freeze": dice.bodies[i].freeze,
			"visible": dice.roots[i].visible,
			"selected": dice.selected[i],
			"value": dice.values[i],
			"face_index": dice.face_indices[i],
			"settled": dice.settled[i],
		})
	_log_pit_mirror = {
		"slots": slots,
		"player_order": player_order.duplicate(),
		"overrides": dice.value_overrides.duplicate(),
	}

func _on_log_entry_selected(index: int) -> void:
	if not log_open or index < 0 or index >= round_log.entries.size():
		return
	log_cursor = Vector2i(index, 0)
	log_view.set_compact(true)
	_log_render_cursor()

## Ein Schritt vor oder zurück - auch über Eintragsgrenzen hinweg.
func _log_step(delta: int) -> void:
	if not log_open or log_cursor.x < 0:
		return
	var next := round_log.advance(log_cursor, delta)
	if next == log_cursor:
		return
	log_cursor = next
	_log_render_cursor()

## Malt den Stand des Cursors. Idempotent: jeder Schritt trägt seine
## After-Stände selbst, es wird nie inkrementell animiert - nur so kann der
## Cursor auch rückwärts springen.
func _log_render_cursor() -> void:
	var entry := round_log.entry_at(log_cursor.x)
	if entry.is_empty():
		return
	var steps: Array = entry.get("steps", [])
	var step: Dictionary = steps[log_cursor.y - 1] if log_cursor.y > 0 and log_cursor.y <= steps.size() else {}
	var kind := String(step.get("kind", RoundLog.STEP_POSE))
	var is_result := kind == RoundLog.STEP_RESULT
	_log_apply_display(entry["post_state"] if is_result and entry.has("post_state") else entry["state"])

	var entry_changed := _log_posed_entry != log_cursor.x
	if entry_changed:
		_log_pose_pit(entry)
		_log_posed_entry = log_cursor.x

	if step.is_empty():
		table_screen.update_pit_score(0, 0)
		table_screen.clear_pit_die()
		log_view.set_cursor(log_cursor.x, log_cursor.y, round_log.step_count(log_cursor.x),
			String(entry.get("label", "")))
		return

	_log_apply_overrides(step.get("overrides", {}))
	if int(step.get("total_after", RoundLog.NO_TOTAL)) != RoundLog.NO_TOTAL:
		table_screen.update_pit_total(int(step["total_after"]), false)
	else:
		table_screen.update_pit_score(int(step.get("base_after", 0)), float(step.get("mult_after", 1.0)))
	_log_play_step_effects(entry, step, kind)
	log_view.set_cursor(log_cursor.x, log_cursor.y, round_log.step_count(log_cursor.x),
		String(step.get("label", "")))

## Die einmaligen Effekte eines Schritts: der Würfel blitzt, ein Krit wirft seine
## Zahl, das Glied zeigt sein Netz, die Charm-Pads schlagen an. Die Dock-Plätze
## kommen aus dem EINTRAG - der Rückblick fragt den Lauf nie nach ihnen.
func _log_play_step_effects(entry: Dictionary, step: Dictionary, kind: String) -> void:
	var slot := int(step.get("flash_slot", -1))
	if slot >= 0:
		_flash_scoring_die(slot)
	var net: Dictionary = step.get("net", {})
	if not net.is_empty():
		var pit: Array = entry.get("pit", [])
		var net_slot := int(net.get("slot", -1))
		if net_slot >= 0 and net_slot < pit.size():
			_show_pit_net(pit[net_slot]["def"], int(net.get("face", 0)))
	else:
		table_screen.clear_pit_die()
	var slots: Array = entry.get("charm_slots", [])
	for index: int in step.get("charm_indices", []):
		if index >= 0 and index < slots.size():
			_log_flash_charm(int(slots[index]))
	if kind == RoundLog.STEP_CRIT and slot >= 0 and slot < dice.count():
		table_screen.spawn_gain_number(
			table_screen.world_to_pixel(dice.bodies[slot].global_position),
			ScoreBreakdown.format_mult(float(step.get("crit_x", 1.0))), TableScreen.CRIT_COLOR, 1.2)

## Charm-Pad und Blende blitzen an einem AUFGEZEICHNETEN Dock-Platz.
func _log_flash_charm(slot: int) -> void:
	if slot < 0:
		return
	if charm_row != null:
		charm_row.flash_charm(slot)
	if table_screen != null and table_screen.charm_dock != null:
		table_screen.charm_dock.flash_pad(slot)

## Die laufenden Werte auf den Würfeln: ungetönt wie in der Zeremonie, denn die
## Änderung war dauerhaft. Trifft der Wert die Seite der Def, verschwindet sie.
func _log_apply_overrides(values: Dictionary) -> void:
	var overrides: Dictionary = {}
	for slot: int in values:
		if slot < 0 or slot >= dice.count() or slot >= dice.face_indices.size():
			continue
		var face := dice.face_indices[slot]
		if face < 0 or face >= dice.slot_defs[slot].faces.size():
			continue
		if int(values[slot]) != dice.slot_defs[slot].faces[face]:
			overrides[slot] = int(values[slot])
	dice.set_value_overrides(overrides, false)

## Der ganze Tisch auf den Stand eines Moments - reine Anzeige, kein Signal.
func _log_apply_display(state: Dictionary) -> void:
	if state.is_empty():
		return
	if chip_stack != null:
		chip_stack.clear_mints()
		chip_stack.seed_wallet(int(state.get("money", 0)))
	if capacitor_bank != null:
		capacitor_bank.set_energy(int(state.get("energy", 0)), int(state.get("energy_cap", 0)))
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_run_info(int(state.get("round_number", 1)), int(state.get("money", 0)), _round_note())
		table_screen.hub.set_energy_display(int(state.get("energy", 0)), int(state.get("energy_cap", 0)))
		var sides: Array[Dictionary] = []
		sides.assign(state.get("deal_sides", []))
		table_screen.hub.set_deal_tokens(sides)
	var goal: Dictionary = state.get("goal", {})
	if table_screen != null and not goal.is_empty():
		table_screen.set_goal_progress(int(goal["into_stage"]), int(goal["stage_size"]),
			int(goal["stage"]), int(goal["cleared"]))
	var levels: Dictionary = state.get("combo_levels", {})
	for key: String in combo_labels:
		var row: ComboCellView = combo_labels[key]
		row.set_score(DiceScoring.points_for(key, levels), DiceScoring.mult_for(key, levels))
		row.set_level(int(levels.get(key, 0)))
		_sync_combo_chip(key)
	var throttled: Array[String] = []
	throttled.assign(state.get("throttled", []))
	_set_throttled_combos(throttled)
	_set_spotlight_combo(String(state.get("spotlight", "")))
	_log_fill_trays(state)

func _log_fill_trays(state: Dictionary) -> void:
	var queue_defs: Array[DieDefinition] = []
	queue_defs.assign(state.get("queue_defs", []))
	var pool_defs: Array[DieDefinition] = []
	pool_defs.assign(state.get("pool_defs", []))
	queue_tray_view.ensure_capacity(_queue_capacity())
	queue_tray_view.fill(queue_defs)
	# Der geparkte Träger trägt seinen SITZ-PLAN, keine Aufreihung: ein Rückblick
	# malt dort nichts um, sonst spränge der Vorrat mitten in der Runde.
	if _pool_standing:
		pool_tray_view.fill(pool_defs)

## Stellt die Grube eines Eintrags: aufgezeichnete Defs in die Slots, jede Seite
## nach oben gekippt, dann die Reihe wie nach dem Aufreihen - hart gesetzt, denn
## ein Sprung zurück darf nicht erst hinterhertweenen.
func _log_pose_pit(entry: Dictionary) -> void:
	_cancel_lineup()
	var pit: Array = entry.get("pit", [])
	var defs: Array[DieDefinition] = []
	for slot: Dictionary in pit:
		defs.append(slot["def"])
	dice.set_slot_defs(defs)
	dice.clear_value_overrides()
	var order: Array = entry.get("player_order", [])
	var row: Array[int] = []
	for index: int in order:
		if index >= 0 and index < pit.size() and bool(pit[index].get("visible", false)):
			row.append(index)
	for i in pit.size():
		if bool(pit[i].get("visible", false)) and not row.has(i):
			row.append(i)
	for i in dice.count():
		var shown := i < pit.size() and bool(pit[i].get("visible", false))
		dice.roots[i].visible = shown
		dice.set_selected(i, shown and bool(pit[i].get("selected", false)))
		if not shown:
			continue
		dice.bodies[i].freeze = true
		dice.tip_to_face(i, int(pit[i].get("face_index", 0)))
	dice.note_pit_changed()  # auch die gestellte Erinnerung füllt die Grube
	var rest_y := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT
	var span := PIT_TOP_ROW_SPACING * float(maxi(row.size() - 1, 0))
	for k in row.size():
		var body := dice.bodies[row[k]]
		body.global_transform = Transform3D(_readable_upright_basis(body.global_basis),
			Vector3(DicePit.PIT_CENTER.x + PIT_CENTER_ROW_X, rest_y,
				DicePit.PIT_CENTER.z - span * 0.5 + PIT_TOP_ROW_SPACING * float(k)))
	player_order = row.duplicate()

## Zurück in die Gegenwart: erst schweigt der Erinnerungs-Modus, dann bekommt der
## Tisch seine echten Anzeigen zurück - die Grube wieder mit den POOL-Instanzen,
## nicht mit den Kopien der Chronik.
func _close_round_log() -> void:
	if not log_open:
		return
	log_open = false
	if log_view != null:
		log_view.close()
	if table_screen != null:
		table_screen.set_memory_veil(false)
		table_screen.clear_pit_die()
	dice.clear_value_overrides()
	_log_restore_pit()
	_log_posed_entry = -1
	log_cursor = Vector2i(-1, 0)
	_log_pit_mirror = {}
	if run == null:
		return
	if chip_stack != null:
		chip_stack.clear_mints()
		chip_stack.seed_wallet(run.money)
	_refresh_hub_info()
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_energy_display(run.energy, run.energy_cap())
	_sync_capacitor()
	for key: String in combo_labels:
		_refresh_combo_display(key)
	_set_throttled_combos(run.throttled_combos)
	_set_spotlight_combo(run.spotlight_combo)
	_refresh_deck_trays()
	if table_screen != null:
		table_screen.reset_pit_score()
	_refresh_ui()

func _log_restore_pit() -> void:
	var slots: Array = _log_pit_mirror.get("slots", [])
	if slots.is_empty():
		return
	var defs: Array[DieDefinition] = []
	for slot: Dictionary in slots:
		defs.append(slot["def"])  # die LEBENDEN Instanzen, nie die Kopien
	dice.set_slot_defs(defs)
	for i in mini(dice.count(), slots.size()):
		var slot: Dictionary = slots[i]
		dice.roots[i].visible = bool(slot["visible"])
		dice.set_selected(i, bool(slot["selected"]))
		dice.values[i] = int(slot["value"])
		dice.face_indices[i] = int(slot["face_index"])
		dice.settled[i] = bool(slot["settled"])
		dice.bodies[i].global_transform = slot["transform"]
		dice.bodies[i].freeze = bool(slot["freeze"])
	player_order.assign(_log_pit_mirror.get("player_order", []))
	dice.note_pit_changed()
	dice.refresh_faces()

#endregion
