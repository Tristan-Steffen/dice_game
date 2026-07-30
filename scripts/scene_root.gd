extends Node3D
## Spielablauf-Koordinator: Rundenziele, Shop, Würfel-Pool und UI-Verdrahtung.
##
## Kernregeln: Der Pool hat fest GameRun.POOL_SIZE Würfel; zu Rundenbeginn wird
## er gemischt und verteilt sich auf Warteschlangen- und Pool-Tray. "Nehmen"
## wertet die AUSGEWÄHLTEN Würfel als Hand und legt alle 6 ab; die Auswahl
## schützt außerdem vor dem nächsten "Neu würfeln" (nur ungeschützte Slots
## bekommen frisch gezogene Würfel). Farkle: bringt ein Neu-Würfeln nicht
## strikt mehr Punkte, wird die Hand ohne Punkte verworfen (der erste Wurf
## einer Hand kann nie farkeln). Die Runde endet, sobald der Rundenstand das
## Ziel erreicht - oder der Pool keine volle Hand mehr hergibt (Game Over).

@export var throw_force: float = 50.0
@export var spin_strength: float = 14.0
@export var rest_linear_threshold: float = 0.15
@export var rest_angular_threshold: float = 0.15
@export var rest_time_required: float = 0.2

const HAND_SIZE := 6

## Einmal für den geschafften Benchmark - und erneut je Überladungs-Stufe, die
## nicht mehr in die Ladungs-Börse passt (siehe GameRun.charge_split).
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
## Pendel-Schwung: verlorener Mult steigt in Warnrot auf, gewonnener in Gold.
const PENDULUM_LOSS_COLOR := Color(1.0, 0.35, 0.3)
const PENDULUM_SWING_FONT := 0.7

## Bank-Entladung: je Überladungs-Stufe ein Komet aus dem Zielbalken (oberste
## Stufe zuerst). Der Abstand nach jeder Ankunft zieht leicht an (Accelerando).
const BANK_STAGE_GAP_START := 0.28
const BANK_STAGE_GAP_DECAY := 0.82
const BANK_STAGE_GAP_MIN := 0.12
const BANK_BAR_DRAIN_TIME := 0.45
## Stufen, die eine Ladung prägen, fahren cyan statt in ihrer Stufenfarbe.
const CHARGE_COMET_COLOR := CasinoStyle.CHARGE

## --- Schwarzmarkt ---------------------------------------------------------------
## Anteil des Rasterplatzes, den die Bank einnimmt - knapp unter 1, nur noch ein
## Saum gegen die Nachbarzelle (das Raster soll den Platz sichtbar ausfüllen).
const CAPACITOR_SLOT_FILL := 0.97
## Luft zwischen Automaten-Unterkante und Schwarzmarkt-Fenster.
const SECRET_SHOP_TOP_GAP := 30.0
## Sicherheitsabstand der Fenster-Unterkante zur Glaskante (die Ellipse steigt
## nach links an - siehe _secret_shop_rect).
const SECRET_SHOP_GLASS_MARGIN := 12.0
## Violett der legendären Rarität - die Signaturfarbe des Schwarzmarkts.
const VIOLET_REVEAL_COLOR := Color(0.75, 0.35, 1.0)

## Würfel-Blitz beim Auszahlen: schneller Anstieg auf überstrahltes Gold plus
## Größen-Pop, langsameres Abklingen - die Blitze überlappen wie eine Welle.
const DIE_FLASH_PEAK_COLOR := Color(1.9, 1.55, 0.6)
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

## Die POSITION der Screen-Elemente hängt an frei verschiebbaren Editor-Ankern
## (Marker3D unter $ScreenAnchors); nur die GRÖSSEN stehen hier als Weltmaß.
const PIT_SCORE_WIDTH_WORLD := 10.0
const PIT_SCORE_HEIGHT_WORLD := 6.0  # höher: Platz für die Wertungs-Orbs

## Hub-Fläche unter der Grube (~grubenbreit, doppelte Gruben-Bildschirmhöhe).
const HUB_WIDTH_WORLD := 28.5
const HUB_HEIGHT_WORLD := 30.0

## Automaten-Fenster: Unterkante höher als der Hub. Der Versatz stammt vom
## alten Tischrand und bleibt bewusst - das Layout soll nicht verrutschen.
const SLOTS_BOTTOM_INSET_WORLD := 7.5

## SEITENVERHÄLTNIS der Werkbank, nicht ihre Breite: bei ~2:1 steht das 6×5-
## Ziel-Raster der Gravur-Station bündig neben der Würfel-Spalte. Ist das Fenster
## flacher, bleibt das Raster (höhenbegrenzt) schmaler als sein Platz und
## zwischen Spalte und Raster klafft tote Fläche. Die Breite folgt also der
## Höhe - und die Höhe nimmt, was das Glas hergibt.
const WORKSHOP_ASPECT := 2.0
## Die MASSEINHEIT der Ecke bleibt an der Tray-Breite hängen: hinge sie an der
## Werkbank-Breite, wüchse mit ihr die Schubladenhöhe und fräße den Höhengewinn.
## Abstände der Ecke in halben Slot-Breiten: oben zur Tray-Reihe, unten zum Rand.
## tray_bounds umfasst nur die Slot-MITTEN - unter 1.0 läge die unterste
## Würfelreihe körperlich auf der Werkbank.
const WORKSHOP_TOP_GAP := 1.15
const WORKSHOP_BOTTOM_GAP := 2.0

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


## Automaten-Lichter: Einsatz golden wie Geld, Charm violett wie im Regal,
## Würfel zyan wie das Würfel-Symbol der Walze.
const SLOT_COIN_COLOR := Color(2.0, 1.55, 0.35, 0.9)
const SLOT_CHARM_COLOR := Color(1.6, 0.9, 2.0, 0.9)
const SLOT_DIE_COLOR := Color(0.7, 1.7, 2.0, 0.9)

## Gravur-Zeremonie: der geklickte Würfel wird zum Ziel - sein Tray-Slot leert
## sich und der ECHTE Würfel fliegt über die Hub-Bühne (kein Abbild).
const ENGRAVE_TRAIL_TIME := 0.5
const ENGRAVE_ABSORB_COLOR := Color(2.0, 1.6, 0.3, 0.9)
const ENGRAVE_FLY_TIME := 0.55
const ENGRAVE_HOVER := DiceTrayView.REST_Y  # der Würfel BERÜHRT den Tisch

## Zähl-Animation beim Nehmen (siehe _play_take_animation).
const SCORE_ROW_X := 2.0  # Reihen-X in der Grube (obere Hälfte)
const SCORE_ROW_SPACING := 2.9
const SCORE_HOVER_HEIGHT := 0.0  # 0 = die Würfel liegen beim Zählen auf dem Tisch
const SCORE_LIFT_TIME := 0.5
const SCORE_GLOW_SIZE_FACTOR := 1.5  # Glow-Kantenlänge als Vielfaches der Würfelgröße
const FULL_COUNTER_GLOW_FAINT := 0.32  # Vollzähler: schwacher Glow der Nicht-Kombi-Würfel
const SCORE_TRAIL_TIME := 0.3
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
const MONEY_PULSE_GAP := 0.12
const MONEY_PULSE_BOOST := 2.2  # Chip-Farbe -> überhelle Leiterbahn-Farbe
## Kleiner Nachlauf, nachdem das letzte Geld-Licht den Hub erreicht hat, bevor
## der Übertaktungs-Puls losläuft (klare Kette Geld -> Hub -> Aufwertung).
const OVERCLOCK_MONEY_MARGIN := 0.12

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

## Zweiter Testmodus: 1-5 zufällige Leiterbahnen auf ALLEN Würfeln an/aus -
## getrennt von den Materialien, damit die Kette allein prüfbar bleibt.
var test_pointers_button: Button
var test_pointers_enabled: bool = false

## Dritter Testmodus: unerschöpfliches Gravur-Bord (jeder Archetyp, auch die
## Sonderposten) OHNE die Würfel anzutasten - die Testmaterialien schreiben
## jeden Würfel um, was zum Ausprobieren einer einzelnen Gravur zu viel ist.
var test_engravings_button: Button
var test_engravings_enabled: bool = false

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
## Rand der Auslage als Anteil der Grubenbreite (rundum gleich). Sie nimmt den
## ganzen Grubenboden - das Gruben-Mobiliar weicht ihr solange.
const ROUTE_CHOICE_INSET := 0.04

## Titel-HUD (Startbildschirm + Menü) als Hub-Seite; davor stand die Kamera in
## title_prev_mode und kehrt beim "Weiterspielen" dorthin zurück.
var title_view: TitleView
var title_prev_mode: CameraRig.Mode = CameraRig.Mode.OVERVIEW

@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/VBoxContainer/GameOverLabel
@onready var game_over_reset_button: Button = $UI/GameOverPanel/VBoxContainer/GameOverResetButton

## Die Gravur-Station - ebenfalls ein Hub-Panel (siehe _open_engraving).
var die_inspector: DieInspectorView

@onready var pool_tray_view: DiceTrayView = $PoolTrayView
@onready var discard_tray_view: DiceTrayView = $DiscardTrayView
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

## Zustand der Gravur-Zeremonie: der ECHTE Würfel fliegt als Weltobjekt aus
## dem Tray über die Hub-Bühne; sein Tray-Slot bleibt solange versteckt.
var engraving_active := false
var engraving_die: Node3D
var engraving_fly_tween: Tween
var engraving_source_root: Node3D        # versteckter Tray-Slot des Ziels
var engraving_source_tray: DiceTrayView
var engraving_prev_mode: CameraRig.Mode = CameraRig.Mode.OVERVIEW

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
var pre_reroll_values: Array[int] = []  # Werte VOR dem Neu-Würfeln (Farkle-Vergleich)
var pre_reroll_materials: Array[String] = []
var pre_reroll_edge_materials: Array[String] = []
var pre_reroll_links: Dictionary = {}  # Leiterbahn-Glieder VOR dem Neu-Würfeln
var pre_reroll_upgrades: Dictionary = {}  # Dotierungen VOR dem Neu-Würfeln

# Zustand der Effektkatalog-Charms (ctx-Schlüssel siehe CharmEffects):
var rerolls_this_hand: int = 0  # Anker
var taken_dice_this_round: int = 0  # nur Statistik/Report (Nebenwetten)
var pendulum_acc: int = 0  # Pendel: akkumulierter Mult, überlebt Runden (+2/Neuwurf, -1/genommen)
var full_reroll_stacks: int = 0  # Alles-oder-nichts
var _pendulum_shown: int = 0  # zuletzt angezeigter Pendel-Mult (Schwung-Animation)
var momentum_streak: int = 0  # Momentum
var first_hand_after_farkle: bool = false  # Galgenhumor
var recycling_used_this_round: bool = false
var slot_draw_positions: Array[int] = []  # je Slot die Zieh-Position (Bodensatz)
var discarded_this_round: Array[DieDefinition] = []  # Phönixfeder
var hand_note: String = ""  # transiente Meldung (z.B. Farkle)

# Rundenbilanz für die Nebenwetten-Auswertung (je Rundenbeginn zurückgesetzt).
var round_best_combo_rank: int = -1  # bester genommener Kombi-Rang (SideBet.combo_rank)
var round_best_hand_score: int = 0   # höchster Einzel-Hand-Score
var round_farkled: bool = false
## Wett-Fenster ist offen (nur vom Rundenbeginn bis zum ERSTEN Wurf platzierbar).
var betting_open: bool = false

var gameplay_ui_state_visible: bool = true  # false während Shop/GameOver
var is_pit_focused: bool = false

## Zuletzt im Würfelnetz gezeigter Würfel + Rest-Nachlauf (NET_LINGER_TIME) und
## Rest-Ausblendzeit (NET_FADE_TIME, läuft erst nach dem Nachlauf).
var _net_die_def: DieDefinition
var _net_linger := 0.0
var _net_fade := 0.0

var lineup_tween: Tween

## Goldlichter der laufenden Zähl-Animation (siehe _cleanup_take_animation).
var take_anim_glows: Array[Control] = []

## Leucht-Podeste unter den AUSGEWÄHLTEN Würfeln (Slot -> Display-Knoten) -
## folgen den Würfeln jeden Frame, nur während der Auswahlphase sichtbar.
var _select_glows: Dictionary = {}

var deck_shift_ghosts: Array[Node3D] = []  # temporäre Würfel der Aufrück-Animation
var deck_shift_tween: Tween

## Ziehen/Klicken auf der Energie-Hülle: Klick = Würfeln, Ziehen = Drehen.
var shell_drag_active := false
var shell_drag_start_pos: Vector2
var shell_is_dragging := false

var queue_window_size: int = 0  # belegte Slots im Warteschlangen-Tray

## Umsortieren im Warteschlangen-Tray per Ziehen.
var reorder_drag_index: int = -1
var reorder_drag_start_pos: Vector2
var reorder_is_dragging: bool = false
var reorder_ghost: Node3D

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
	for prop: Node in [pool_tray_view, queue_tray_view, discard_tray_view, dice_shell]:
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

	# Nebenwetten-Fenster rechts von der Energie-Hülle, in den Maßen des
	# Kombi-Fensters; Unterkante bündig mit Grube und Kombinationen-Fenster.
	var shell_px := table_screen.world_to_pixel(dice_shell.global_position)
	var pit_r := Rect2(table_screen.pit_window.position, table_screen.pit_window.size)
	var win_size := table_screen.cluster_rect.size
	var win_pos := Vector2(shell_px.x + table_screen.size.x * 0.045, pit_r.end.y - win_size.y)
	table_screen.place_side_bet_window(Rect2(win_pos, win_size))
	_setup_side_bets_zoom()
	# Einsatz/Auszahlung als Licht über die Schatz-Leiste (einmalig verdrahtet -
	# das Fenster überlebt Run-Wechsel, nur sein run wird neu gesetzt).
	table_screen.side_bet_window.bet_selected.connect(_on_side_bet_selected)
	table_screen.side_bet_window.bet_placed.connect(_on_side_bet_placed)

	# Schatz-Screen unter der Energie-Hülle, in der Lücke zwischen Grube und
	# Nebenwetten; die echten 3D-Chips werden mittig-oben darauf gestellt.
	var side_r := Rect2(table_screen.side_bet_window.position, table_screen.side_bet_window.size)
	var gap_left := pit_r.end.x
	var gap_right := side_r.position.x
	var t_w := minf((gap_right - gap_left) * 0.9, table_screen.size.x * 0.15)
	# Oberkante hergeleitet statt fest: der Projektor-Fuß der Hülle bekommt nach
	# unten (Screen-Oberkante) genau so viel Luft wie nach oben (Grubenoberkante).
	# Die Unterkante bleibt auf der gemeinsamen Linie mit Grube und Nebenwetten.
	var puck_px := DiceShell.PUCK_RADIUS * ppw
	var puck_margin := maxf((shell_px.y - puck_px) - pit_r.position.y, 0.0)
	var t_top := shell_px.y + puck_px + puck_margin
	var t_size := Vector2(t_w, maxf(pit_r.end.y - t_top, t_w * 0.4))
	# Waagerecht unter die Hülle, aber in der Lücke gehalten.
	var t_cx := clampf(shell_px.x, gap_left + t_w * 0.5, gap_right - t_w * 0.5)
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
	var slots_rect := Rect2(
		Vector2(table_screen.cluster_rect.position.x, hub_r.position.y),
		Vector2(table_screen.cluster_rect.size.x, hub_r.size.y - SLOTS_BOTTOM_INSET_WORLD * ppw))
	table_screen.place_slot_bank_window(slots_rect)
	slots_click_zone = _screen_zoom_zone("SlotsClickZone", slots_rect, camera_rig.configure_slots_target)
	table_screen.slot_bank_window.cashed_out.connect(_on_slot_cashed_out)
	table_screen.slot_bank_window.spin_paid.connect(_on_slot_spin_paid)
	table_screen.slot_bank_window.prize_dispatched.connect(_on_slot_prize_dispatched)
	# Die Walze wartet, bis die Münze beide Etappen hinter sich hat.
	table_screen.slot_bank_window.coin_travel_time = \
		table_screen.money_travel_time() + table_screen.slot_pay_travel_time()

	# Schwarzmarkt: direkt unter den Automaten in der Glas-Tasche, Unterkante
	# bündig mit dem Hub. Eigener Zoom wie jedes Tisch-Fenster - auch vergittert
	# anfassbar, denn der Freischalt-Knopf liegt IM Fenster.
	var secret_rect := _secret_shop_rect(slots_rect, hub_r)
	table_screen.place_secret_shop_window(secret_rect)
	secret_shop_click_zone = _screen_zoom_zone("SecretShopClickZone", secret_rect,
		camera_rig.configure_secret_shop_target)

	# Werkstatt: der letzte freie Fleck des Tisches, genau UNTER den beiden
	# Würfel-Trays und bündig mit deren Außenkanten. Hier werden gekaufte Pakete
	# geöffnet. Alle drei Kanten leiten sich aus den echten Slot-Positionen ab,
	# damit ein späterer Tray-Umzug das Fenster automatisch mitnimmt.
	var tray_bounds := Rect2()
	var first_slot := true
	for tray: DiceTrayView in [pool_tray_view, discard_tray_view]:
		for i in tray.slot_roots.size():
			var slot_px := table_screen.world_to_pixel(tray.slot_global_position(i))
			tray_bounds = Rect2(slot_px, Vector2.ZERO) if first_slot else tray_bounds.expand(slot_px)
			first_slot = false
	# Slot-Mitten -> Außenkante: je eine halbe Spaltenbreite nach außen.
	var slot_half := DiceTrayView.SPACING.y * ppw * 0.5
	var workshop_top := tray_bounds.end.y + slot_half * WORKSHOP_TOP_GAP
	# EINE Maßeinheit für die ganze Werkbank-Ecke: die schmalen Schubladen dürfen
	# ihre Schrift nicht aus der eigenen Breite ableiten, sonst wird sie winzig.
	# Sie hängt an der TRAY-Breite, nicht an der gewachsenen Werkbank-Breite.
	var corner_unit := (tray_bounds.size.x + slot_half * 2.0) / 100.0
	var drawer_rects := _supply_drawer_rects(
		Vector2(tray_bounds.position.x - slot_half, 0.0),
		tray_bounds.size.x + slot_half * 2.0, corner_unit)
	var drawer_height: float = drawer_rects[0].size.y
	var drawer_gap := slot_half
	var info_height := corner_unit * 6.0 + 10.0
	# Die Werkbank nimmt, was zwischen Tray-Reihe und Anzeigenrand übrig bleibt,
	# nachdem Schubladen und Info-Leiste ihren Platz haben. Der Rand ist RUND:
	# maßgeblich ist nicht die Rechteckkante, sondern wie tief das Glas in der
	# Spalte der rechten unteren Ecke noch trägt - sonst schneidet die Glaskante
	# Info-Leiste und Vitrine schräg an.
	# Die Info-Leiste ist der TIEFSTE Punkt der Ecke, und wie tief das Glas trägt,
	# hängt daran, wie weit rechts sie endet. Sie hört deshalb schon über der
	# zweiten Schublade auf: jeder Pixel, den sie kürzer ist, wird zu Höhe für
	# die Werkbank - und eine Hinweiszeile braucht die Breite nicht.
	var info_right := drawer_rects[1].end.x
	var corner_bottom := table_screen.glass_bottom_limit(info_right) - slot_half * WORKSHOP_BOTTOM_GAP
	var workshop_height := corner_bottom - workshop_top - drawer_gap * 1.5 - drawer_height - info_height
	# Breite AUS der Höhe (siehe WORKSHOP_ASPECT), aber nie schmaler als die
	# Schubladenreihe darunter - sie muss unter der Werkbank Platz haben.
	var drawer_span := drawer_rects[drawer_rects.size() - 1].end.x - drawer_rects[0].position.x
	var workshop_rect := Rect2(
		Vector2(tray_bounds.position.x - slot_half, workshop_top),
		Vector2(maxf(workshop_height * WORKSHOP_ASPECT, drawer_span), workshop_height))
	# Die Vitrine steht rechts der Werkbank und ist damit der äußerste Punkt: die
	# Werkbank darf nur so breit werden, dass die Vitrine an ihrer UNTERKANTE
	# (dort ist das Glas am schmalsten) noch ganz auf der Anzeige steht.
	var special_width := SupplyDrawerView.size_for(SupplyDrawerView.CATEGORY_SPECIAL, corner_unit).x
	var right_room := table_screen.glass_right_limit(workshop_rect.end.y) \
		- slot_half * WORKSHOP_BOTTOM_GAP - drawer_gap - special_width
	workshop_rect.size.x = minf(workshop_rect.size.x, right_room - workshop_rect.position.x)
	table_screen.place_workshop_window(workshop_rect)
	workshop_click_zone = _screen_zoom_zone("WorkshopClickZone", workshop_rect, camera_rig.configure_workshop_target)

	# Schubladen-Reihe direkt unter die Werkbank schieben.
	var drawer_top := workshop_rect.end.y + drawer_gap
	for i in drawer_rects.size():
		drawer_rects[i].position.y = drawer_top
	table_screen.place_supply_drawers(drawer_rects, corner_unit)

	# Sonderbestand: schmale Vitrine RECHTS der Werkbank, so hoch wie sie, für
	# die Sonderposten (Leiterbahn & Co.) - in der Würfel-Schublade machte die
	# dritte Platz-Reihe die ganze Reihe höher und drückte die Werkbank zusammen.
	var special_rect := Rect2(
		Vector2(workshop_rect.end.x + drawer_gap, workshop_rect.position.y),
		Vector2(special_width, workshop_rect.size.y))
	table_screen.place_special_stock(special_rect, corner_unit)
	for drawer in table_screen.supply_drawers:
		drawer.hovered.connect(_on_supply_hovered)

	# Info-Leiste unter der Schubladen-Reihe: flach und deutlich schmaler als die
	# Reihe - rechts eingekürzt, damit der Lichtsaum der Tischkante sie nicht
	# anschneidet. Hier landet die Hinweiszeile der Gravur-Station.
	var info_rect := Rect2(
		Vector2(drawer_rects[0].position.x, drawer_top + drawer_height + drawer_gap * 0.5),
		Vector2(info_right - drawer_rects[0].position.x, info_height))
	table_screen.place_supply_info_bar(info_rect, corner_unit)

	# Der Zoom rahmt die GANZE Werkbank-Ecke - Trays oben, Fenster, Schubladen,
	# Sonderbestand und Info-Leiste unten. Nur so liegt der Ziel-Würfel mit im Bild.
	var corner := workshop_rect.merge(tray_bounds).merge(info_rect).merge(special_rect)
	for rect in drawer_rects:
		corner = corner.merge(rect)
	camera_rig.configure_workshop_target(table_screen.pixel_to_world(corner.get_center()))

	# Nahsicht (Doppelklick): dieselbe Ecke OHNE die Trays - genau der Teil, der
	# flach auf dem Glas liegt. workshop_close_rect bleibt als Prüffläche für den
	# Doppelklick liegen (nur darauf öffnet die zweite Stufe).
	workshop_close_rect = workshop_rect.merge(info_rect).merge(special_rect)
	for rect in drawer_rects:
		workshop_close_rect = workshop_close_rect.merge(rect)
	var close_a := table_screen.pixel_to_world(workshop_close_rect.position)
	var close_b := table_screen.pixel_to_world(workshop_close_rect.end)
	camera_rig.configure_workshop_close_target(
		table_screen.pixel_to_world(workshop_close_rect.get_center()),
		Vector2(absf(close_a.z - close_b.z), absf(close_a.x - close_b.x)) * 0.5)

	_setup_screen_spill_lights(corner)

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
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = Vector3((a.x + b.x) * 0.5, height, (a.z + b.z) * 0.5)
	light.light_color = tint
	light.light_energy = SPILL_ENERGY * energy_factor
	light.omni_range = maxf(half.x, half.y) * SPILL_RANGE_FACTOR + height
	light.omni_attenuation = SPILL_ATTENUATION
	light.shadow_enabled = false
	add_child(light)

## Kamera-Zoomziele aus den echten Positionen ableiten, damit Editor-
## Verschiebungen den Zoom automatisch mitnehmen.
func _setup_camera_targets() -> void:
	# Das Nachschub-Tray lebt fest VOR der Grube (materialisiert erst beim
	# ersten Grubenzoom einer Runde, siehe _activate_queue).
	queue_tray_view.position = QUEUE_TRAY_PIT_POSITION

	camera_rig.configure_tray_targets(
		pool_tray_view.global_position,
		discard_tray_view.global_position)
	# Grubenziel auf Tisch-Screen-Höhe (0), etwas Richtung Charms (+X = oben)
	# verschoben, damit die Charm-Konsolen mit im Blick sind.
	camera_rig.configure_pit_target(Vector3(DicePit.PIT_CENTER.x + PIT_ZOOM_UP, 0.0, DicePit.PIT_CENTER.z))
	_setup_charms_zoom()

## Shop, Gravur-Station und Bogen-Enthüllung anlegen und verdrahten.
func _setup_panels() -> void:
	# Shop als Hub-Seite; ohne Screen-Mesh ersatzweise als Fenster-UI.
	charm_shop = SHOP_SCENE.instantiate()
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.attach_panel(charm_shop)
	else:
		$UI.add_child(charm_shop)
	charm_shop.closed.connect(_on_shop_closed)

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

	# Gravur-Station in der WERKSTATT: dort liegen die Vorräte, dort werden sie
	# angewandt (ohne Werkstatt-Fenster: keine Zeremonie).
	die_inspector = DieInspectorView.new()
	die_inspector.visible = false
	if table_screen != null and table_screen.workshop_window != null:
		table_screen.workshop_window.attach_station(die_inspector)
	else:
		$UI.add_child(die_inspector)
	if table_screen != null:
		die_inspector.set_drawers(table_screen.supply_drawers)
		die_inspector.set_prompt_label(table_screen.supply_info_label)
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

	die_inspector.closed.connect(_end_engraving_ceremony)
	die_inspector.applied.connect(_on_engraving_applied)
	die_inspector.select_tray_die.connect(_on_tray_die_selected)
	die_inspector.changed.connect(_on_die_engraved)
	# Beim Drehen der Würfel-Projektion die Kamera festhalten.
	die_inspector.rotating_die.connect(func(active: bool) -> void: camera_rig.set_tilt_locked(active))
	# Auswahl auch am ECHTEN schwebenden Würfel violett hervorheben.
	die_inspector.selection_changed.connect(func(_face: int) -> void: _highlight_engraving_die())

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
		table_screen.hub.test_materials_requested.connect(_on_test_materials_pressed)
		table_screen.hub.test_pointers_requested.connect(_on_test_pointers_pressed)
		table_screen.hub.test_engravings_requested.connect(_on_test_engravings_pressed)
		table_screen.hub.hub_upgrade_requested.connect(_on_hub_upgrade_pressed)

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
	test_engravings_button.custom_minimum_size = Vector2(0, 48)
	test_engravings_button.pressed.connect(_on_test_engravings_pressed)
	settings_menu.add_child(test_engravings_button)
	CasinoStyle.style_button(test_engravings_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, 14)
	_refresh_test_engravings_button()

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

## Nur in Ruhephasen: während Wurf, Zählen oder Gravur-Zeremonie wird die
## Kamera gebraucht, und das Menü risse sie mitten aus der Bewegung.
func _can_open_title() -> bool:
	if camera_rig.is_animating or engraving_active or _dice_in_motion():
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

## Blendet das Glühen des 3D-Chips weich auf target (0 = Ruhe, 1 = aktiv).
func _glow_combo_chip(key: String, target: float) -> void:
	if not combo_chips.has(key):
		return
	var chip: ComboChipView = combo_chips[key]
	var tween := create_tween()
	tween.tween_method(chip.set_glow, chip.glow, target, 0.35)

## Sammelt die Kombinationszellen des Displays ein und versetzt sie (und die
## Rundenbonus-Zeilen) in die leuchtende Ruhefarbe.
func _collect_combo_labels() -> void:
	combo_labels = table_screen.combo_cells
	for key: String in combo_labels:
		combo_labels[key].modulate = PAYOUT_LABEL_BASE_COLOR
	if table_screen.hub != null and table_screen.hub.blind_payout_label != null:
		table_screen.hub.blind_payout_label.modulate = PAYOUT_LABEL_BASE_COLOR
		table_screen.hub.die_payout_label.modulate = PAYOUT_LABEL_BASE_COLOR

## Kombinationen, deren Kauf-Licht gerade unterwegs ist: ihre Zellen zeigen
## bis zur Ankunft die ALTEN Werte (siehe _on_combo_upgraded).
var _pulsing_combos: Dictionary = {}

## Kombination übertaktet: erst wandert das bezahlte Geld zum Hub (der Kauf
## löste zugleich _animate_money_spend aus), dann - nach OVERCLOCK_MONEY_DELAY -
## zündet der Hub und schickt das Licht über die Leiterbahnen zum Chip
## (play_overclock_pulse). Erst bei Ankunft zeigt die Zelle die neuen Werte.
func _on_combo_upgraded(combo_key: String, new_level: int) -> void:
	if table_screen == null or not combo_labels.has(combo_key):
		_refresh_combo_label_texts()
		return
	_pulsing_combos[combo_key] = true
	# Warten, bis das letzte bezahlte Geld-Licht den Hub erreicht hat (der Kauf
	# löste über money_changed zugleich _animate_money_spend samt Kometen aus):
	# so viele Kometen wie der Zahlplan Chips zog; jede Ankunft lädt den Hub
	# eine Stufe weiter golden auf.
	var chips := maxi(1, _last_payment_comets)
	_hub_charge_expected += chips
	# Jeder Zahlungs-Komet fährt erst NACH dem Absorbieren seines Chips (MINT_TIME).
	var delay := float(maxi(0, chips - 1)) * MONEY_PULSE_GAP \
		+ ChipStackView.MINT_TIME + table_screen.money_travel_time() + OVERCLOCK_MONEY_MARGIN
	await get_tree().create_timer(delay).timeout
	_hub_charge_expected = 0
	_hub_charge_received = 0
	await table_screen.play_overclock_pulse(combo_key)
	_pulsing_combos.erase(combo_key)
	var row: ComboCellView = combo_labels[combo_key]
	row.set_score(
		DiceScoring.points_for(combo_key, run.combo_levels),
		DiceScoring.mult_for(combo_key, run.combo_levels))
	row.set_level(run.combo_level(combo_key))
	_sync_combo_chip(combo_key)
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

## Rampenlicht eingelöst: der Chip der hervorgehobenen Kombination bekommt
## dieselbe Übertaktungs-Zeremonie wie ein Kauf (Licht über die Leiterbahnen),
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
	var row: ComboCellView = combo_labels[combo_key]
	row.set_score(
		DiceScoring.points_for(combo_key, run.combo_levels),
		DiceScoring.mult_for(combo_key, run.combo_levels))
	row.set_level(run.combo_level(combo_key))
	_sync_combo_chip(combo_key)
	if combo_chips.has(combo_key):
		combo_chips[combo_key].play_upgrade_flash()

## Schreibt Basispunkte + Multiplikatoren inkl. Übertaktungs-Stufen neu;
## Zellen mit laufendem Kauf-Licht bleiben bis zur Ankunft unangetastet.
func _refresh_combo_label_texts() -> void:
	for key in combo_labels:
		if _pulsing_combos.has(key):
			continue
		combo_labels[key].set_score(
			DiceScoring.points_for(key, run.combo_levels),
			DiceScoring.mult_for(key, run.combo_levels))
		combo_labels[key].set_level(run.combo_level(key))
		_sync_combo_chip(key)

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
					texts[slot] = "+%d" % momentum_streak
			Charm.PENDULUM:
				if pendulum > 0:
					texts[slot] = "+%d" % pendulum
			Charm.RAG_COLLECTOR:
				if run.lumpensammler_value > 0:
					texts[slot] = "%d" % run.lumpensammler_value
			Charm.ROUND_NUMBER:
				var used := _used_faces_sum()
				if used > 0:
					texts[slot] = "%d" % used
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

## Augensumme der aktuell gewerteten (beteiligten) Würfel nach Verwandlung -
## genau der Wert, den Runde Sache prüft; als Chip sichtbar, damit man auf ein
## Vielfaches von 10 hinspielen kann. 0 = keine Hand (Chip bleibt versteckt).
func _used_faces_sum() -> int:
	if not has_rolled_current_hand:
		return 0
	var slots := _hand_slots()
	if slots.is_empty():
		return 0
	var ids := run.charm_ids()
	var materials := _rolled_materials()
	var edges := _edge_materials()
	var sel_values: Array[int] = []
	var sel_materials: Array[String] = []
	var sel_edges: Array[String] = []
	for s in slots:
		sel_values.append(dice.values[s])
		sel_materials.append(materials[s])
		sel_edges.append(edges[s])
	var hand := DiceScoring.best_hand(sel_values, ids, hands_taken_this_round == 0, sel_materials, sel_edges, run.combo_levels, _score_ctx_for_slots(slots))
	var transformed := CharmEffects.transform_values(sel_values, ids)
	var sum := 0
	for i in DiceScoring.participating_indices(hand["key"], sel_values, ids, _score_ctx_for_slots(slots)):
		sum += transformed[i]
	return sum

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
	if charm_shop != null and charm_shop.visible:
		charm_shop.refresh_after_hub_upgrade()
	# Nebenwetten frisch installiert: Zeremonie + im Shop sofort die Wettannahme
	# öffnen, damit sich der Kauf gleich auszahlt.
	if level == GameRun.HUB_SIDE_BETS_LEVEL and table_screen != null:
		table_screen.celebrate_side_bet_install(CasinoStyle.GOLD_INTENSE)
		if phase == Phase.SHOP:
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
		table_screen.set_side_bet_installed(run.side_bets_unlocked())
		table_screen.set_slot_bank_installed(run.slots_unlocked() > 0)
		if table_screen.slot_bank_window != null:
			table_screen.slot_bank_window.refresh()

## Offene Gold-Ladung des Hubs: Chips, die für einen Übertaktungs-Kauf
## unterwegs sind - jede Ankunft lädt den Hub eine Stufe weiter auf statt zu
## blitzen (siehe _on_combo_upgraded).
var _hub_charge_expected := 0
var _hub_charge_received := 0
## Anzahl Zahlungs-Kometen der letzten Ausgabe (= gezahlte Chips lt. Zahlplan).
## _on_combo_upgraded liest sie, um den Hub-Goldlader richtig zu skalieren.
var _last_payment_comets := 0
## Laufende Nummer der Meteore eines Pakets - sie steuert die Ausbruch-Richtung,
## damit mehrere Stücke sichtbar auseinanderfliegen.
var _meteor_index := 0

## Unterdrückt das generische Schatz<->Hub-Geld-Licht, während eine Nebenwetten-
## Transaktion (Einsatz/Auszahlung) ihr eigenes Licht fährt.
var _suppress_money_light := false
## Knopfmitte der zuletzt gesetzten Wette (Screen-Pixel), Ziel des Diffusions-Lichts.
var _pending_bet_center := Vector2(-1, -1)

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
	_last_payment_comets = spend_values.size()

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

## Ankunft eines Zahlungs-Kometen am Hub: lädt eine wartende Übertaktung weiter
## golden auf (siehe _on_combo_upgraded), sonst blitzt der Rahmen in Chip-Farbe.
func _on_payment_comet_arrived(chip_color: Color) -> void:
	var hub := table_screen.hub if table_screen != null else null
	if hub == null:
		return
	if _hub_charge_expected > 0:
		_hub_charge_received = mini(_hub_charge_received + 1, _hub_charge_expected)
		hub.charge_gold(float(_hub_charge_received) / float(_hub_charge_expected))
	else:
		hub.flash_frame(chip_color)

## Wette angeklickt (vor der Zahlung): das generische Geld-Licht unterdrücken und
## die Knopfmitte merken (sie ist gleich, nachdem der Knopf zu "platziert" wird).
func _on_side_bet_selected(index: int) -> void:
	_suppress_money_light = true
	if table_screen != null and table_screen.side_bet_window != null:
		_pending_bet_center = table_screen.side_bet_window.bet_button_center(index)

## Wette platziert (nach der Zahlung): der Einsatz reist als Licht zum Fenster
## (Geld vom Schatz, Gravur vom Hub), diffundiert in den Knopf und lässt ihn
## golden/violett glühen. Reines Schmuckwerk - der Einsatz ist bereits gebucht.
func _on_side_bet_placed(index: int) -> void:
	_suppress_money_light = false
	var panel := table_screen.side_bet_window if table_screen != null else null
	if panel == null or index < 0 or index >= panel.offers.size():
		return
	var bet: SideBet = panel.offers[index]
	var from_hub := bet.stake_kind == SideBet.Stake.ENGRAVINGS
	var comet_color := TableScreen.SIDE_ENGRAVING_COLOR if from_hub else TableScreen.SIDE_MONEY_COLOR
	var glow_color := SideBetPanel.ENGRAVING_GLOW if from_hub else SideBetPanel.GOLD
	var center := _pending_bet_center
	var travel := table_screen.side_bet_stake_comet(from_hub, comet_color)
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		if center.x < 0.0:
			panel.glow_bet(index, glow_color)
			return
		var diffuse: float = table_screen.diffuse_into_side_bet(center, comet_color)
		get_tree().create_timer(maxf(diffuse, 0.05)).timeout.connect(func() -> void:
			panel.glow_bet(index, glow_color)))

## Automaten-Sitzung ausgezahlt: der Hub-Rahmen quittiert mit einem goldenen
## Blitz; die Ware selbst fliegt einzeln (siehe _on_slot_prize_dispatched).
func _on_slot_cashed_out(_multiplier: int) -> void:
	_meteor_index = 0  # je Auszahlung ein frischer Fächer von Ausbruch-Richtungen
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.flash_frame(CasinoStyle.GOLD_INTENSE)

## Einsatz bezahlt: die Münze fährt in zwei Etappen zum Automaten - erst als
## Geld-Licht vom Münzfenster in den Hub (das läuft schon über money_changed),
## dann die Automaten-Ader entlang. Erst danach läuft die Walze an.
func _on_slot_spin_paid(_machine: int) -> void:
	if table_screen == null:
		return
	await get_tree().create_timer(table_screen.money_travel_time()).timeout
	table_screen.slot_pay_comet(SLOT_COIN_COLOR)

## Ein Gewinn verlässt den Automaten: Gravuren fliegen als Meteore in ihre
## Schubladen, Charms die Automaten-Ader hinauf in den Hub, Würfel im Bogen auf
## die Vorrats-Ablage. Gebucht hat ihn das Fenster beim Abflug.
func _on_slot_prize_dispatched(prize: SlotPrize, from_px: Vector2) -> void:
	if table_screen == null:
		return
	match prize.kind:
		SlotPrize.Kind.ENGRAVING, SlotPrize.Kind.MATERIAL, SlotPrize.Kind.EDGE:
			for engraving in prize.engravings:
				_fly_slot_engraving(engraving, from_px)
		SlotPrize.Kind.CHARM:
			var travel := table_screen.slot_prize_comet(from_px, SLOT_CHARM_COLOR)
			if travel > 0.0:
				await get_tree().create_timer(travel).timeout
			if table_screen != null and table_screen.hub != null:
				table_screen.hub.flash_frame(CasinoStyle.GOLD_INTENSE)
		SlotPrize.Kind.DIE:
			_fly_die_to_pool(from_px)

## Gewonnene Gravur: fährt das ganze Adernetz vom Automaten bis in ihren Platz -
## anders als beim Paket, das schon an der Werkbank liegt.
func _fly_slot_engraving(engraving: Engraving, from_px: Vector2) -> void:
	for drawer in table_screen.supply_drawers:
		var target := drawer.slot_center_px(engraving.id)
		if target.x < 0.0:
			continue
		var tint: Color = EngravingRenderer.SEAM_COLORS[int(engraving.rarity)]
		var travel := table_screen.slot_engraving_comet(from_px, drawer.category, target, tint)
		if travel > 0.0:
			await get_tree().create_timer(travel).timeout
		if is_instance_valid(drawer):
			drawer.pop(engraving.id, tint)
		return

## Gewonnener Würfel: Licht in die Vorrats-Ablage, in deren nächsten freien Platz
## er beim Rundenstart auftaucht. Ohne Ablage (Fenster-UI-Rückfall) passiert nichts.
func _fly_die_to_pool(from_px: Vector2) -> void:
	if pool_tray_view == null or pool_tray_view.slot_roots.is_empty():
		return
	var slot := mini(maxi(run.owned_pool.size() - 1, 0), pool_tray_view.slot_roots.size() - 1)
	var target := table_screen.world_to_pixel(pool_tray_view.slot_global_position(slot))
	var spread := _meteor_index
	_meteor_index += 1
	table_screen.tray_comet(from_px, target, SLOT_DIE_COLOR, spread)

## Auszahlungs-Lichter gewonnener Wetten: je Wette EIN Komet vom Nebenwetten-
## Fenster zurück (Geld zum Schatz, Gravur zum Hub), leicht gestaffelt.
func _play_side_bet_payouts(won: Array[SideBet]) -> void:
	if table_screen == null or won.is_empty():
		return
	for i in won.size():
		var bet: SideBet = won[i]
		var to_hub := bet.payout_kind == SideBet.Payout.ENGRAVINGS
		var color := TableScreen.SIDE_ENGRAVING_COLOR if to_hub else TableScreen.SIDE_MONEY_COLOR
		var fire := func() -> void:
			var travel: float = table_screen.side_bet_payout_comet(to_hub, color)
			get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
				if to_hub:
					if table_screen.hub != null:
						table_screen.hub.flash_frame(SideBetPanel.ENGRAVING_GLOW)
				elif table_screen.treasure_window != null:
					table_screen.treasure_window.glint())
		if i == 0:
			fire.call()
		else:
			get_tree().create_timer(float(i) * MONEY_PULSE_GAP).timeout.connect(fire)

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

	if event.is_action_pressed("ui_cancel"):
		_toggle_title()
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
		# In der Zeremonie bricht Rechtsklick erst einen laufenden Zweitschritt
		# ab, dann die Zeremonie selbst - sie darf nie offen zurückbleiben,
		# während die Kamera schon woanders steht.
		if engraving_active:
			if die_inspector.has_pending_action():
				die_inspector.cancel_pending()
			else:
				die_inspector.close()  # closed -> _end_engraving_ceremony
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
			dice.set_selected(index, not dice.selected[index])
			_line_up_settled_dice()  # Reihe gleitet in ihre neue Ordnung
			_refresh_ui()  # Kombination/Basis folgen der Auswahl sofort
			_update_charm_badges()  # Runde-Sache-Summe folgt der Auswahl
			return

	# Warteschlangen-Umsortieren nur außerhalb der Zeremonie - dort holt ein
	# Klick den Würfel ins Edit-Panel statt eine Zieh-Geste zu starten.
	if not engraving_active and not _dice_in_motion() and deck_shift_ghosts.is_empty() and _try_start_queue_reorder(event.position):
		return

	if not _dice_in_motion() and _try_tray_die_click(event.position):
		return

	if camera_rig.mode == CameraRig.Mode.CHIPS and _try_start_chip_drag(event.position):
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

## Klick auf einen sichtbaren Tray-Würfel (SLOT_PICK_LAYER) - öffnet die
## Gravur-Zeremonie für genau diesen Würfel (bzw. wechselt das Ziel). Am Hub
## zählt JEDES Tray (der Nutzer will bearbeiten, nicht navigieren), sonst nur
## das gerade fokussierte - aus der Übersicht zoomt ein Klick stattdessen.
func _try_tray_die_click(screen_pos: Vector2) -> bool:
	var candidate_trays: Array[DiceTrayView] = []
	if engraving_active or camera_rig.mode == CameraRig.Mode.WORKSHOP:
		candidate_trays = [pool_tray_view, discard_tray_view, queue_tray_view]
	else:
		match camera_rig.mode:
			CameraRig.Mode.POOL:
				candidate_trays = [pool_tray_view]
			CameraRig.Mode.DISCARD:
				candidate_trays = [discard_tray_view]
			_:
				return false

	var result := _ray_pick(screen_pos, DiceTrayView.SLOT_PICK_LAYER)
	if result.is_empty():
		return false

	for target_tray in candidate_trays:
		var index: int = target_tray.find_slot_index(result.collider)
		if index != -1:
			_open_engraving(target_tray.slot_defs[index], target_tray.slot_roots[index], target_tray)
			return true
	return false

# --- Gravur-Zeremonie ------------------------------------------------------------
# Der geklickte Würfel wird zum GRAVUR-ZIEL: sein Tray-Platz leert sich, das
# Hub-Panel öffnet, die Kamera zoomt auf den Hub - bleibt aber frei. Ein Klick
# auf einen anderen Tray-Würfel wechselt das Ziel; Fertig schließt.

## Öffnet die Zeremonie ODER wechselt das Ziel. def ist die echte
## Pool-Instanz; ohne Hub öffnet nur das Panel als Fenster-UI.
func _open_engraving(def: DieDefinition, source_root: Node3D, source_tray: DiceTrayView) -> void:
	# Der Würfel ist immer einsehbar; während der Runde bleiben nur die Gravuren
	# gesperrt (bearbeiten erst im Laden).
	die_inspector.set_editing_locked(_round_in_progress())
	if table_screen == null or table_screen.workshop_window == null:
		die_inspector.show_die(def)
		return
	if not engraving_active:
		engraving_active = true
		engraving_prev_mode = camera_rig.mode
		engraving_source_root = null
	_grab_engraving_die(def, source_root, source_tray)

## Macht def zum aktuellen Gravur-Ziel: der bisherige Slot wird wieder
## sichtbar, der neue verschwindet und der ECHTE Würfel fliegt an seiner
## Stelle über die Hub-Bühne.
func _grab_engraving_die(def: DieDefinition, source_root: Node3D, source_tray: DiceTrayView) -> void:
	if source_root == engraving_source_root:
		camera_rig.zoom_to(CameraRig.Mode.WORKSHOP)  # schon das Ziel - nur herzoomen
		return
	if engraving_source_root != null and is_instance_valid(engraving_source_root):
		engraving_source_root.visible = true
	engraving_source_root = source_root
	engraving_source_tray = source_tray
	var start_pos: Vector3 = source_root.global_position
	source_root.visible = false
	die_inspector.show_die(def)
	_refresh_engraving_target_grid()
	camera_rig.zoom_to(CameraRig.Mode.WORKSHOP)
	_fly_engraving_die(def, start_pos)

## Lässt den echten Würfel vom Tray-Slot über die Hub-Bühne gleiten (in
## Tray-Größe); ein alter schwebender Würfel wird zuvor freigegeben.
func _fly_engraving_die(def: DieDefinition, start_pos: Vector3) -> void:
	if engraving_fly_tween != null and engraving_fly_tween.is_valid():
		engraving_fly_tween.kill()
	if engraving_die != null and is_instance_valid(engraving_die):
		engraving_die.queue_free()
	engraving_die = _spawn_deck_ghost(def)
	engraving_die.global_position = start_pos

	# Landeziel erst berechnen, wenn das frisch gebaute Panel ausgelegt ist.
	await get_tree().process_frame
	if not engraving_active or engraving_die == null or not is_instance_valid(engraving_die):
		return
	var target: Vector3 = _station_hover_target()
	engraving_fly_tween = create_tween()
	engraving_fly_tween.tween_property(engraving_die, "global_position", target, ENGRAVE_FLY_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Landepunkt: die Bühnen-Mitte auf die Tischfläche zurückprojiziert, dann
## entlang des Kamerastrahls auf Auflagehöhe gehoben (Parallaxe kompensiert).
func _station_hover_target() -> Vector3:
	var stage_px: Vector2 = die_inspector.stage_center_px()
	var surface: Vector3 = table_screen.pixel_to_world(stage_px)
	var zoom_distance := CameraRig.ZOOM_DISTANCE + CameraRig.WORKSHOP_ZOOM_DISTANCE_BONUS
	var cam_pos: Vector3 = camera_rig.workshop_target - CameraRig.ZOOM_FORWARD * zoom_distance
	var hover_y := surface.y + ENGRAVE_HOVER
	var denom := surface.y - cam_pos.y
	if is_zero_approx(denom):
		return Vector3(surface.x, hover_y, surface.z)
	var t := (hover_y - cam_pos.y) / denom
	return cam_pos + (surface - cam_pos) * t

## Ätzung angewandt: goldene Leiterbahn Gravur-Kachel -> schwebender Würfel;
## bei der Ankunft absorbiert er die Kraft (Seiten nachziehen + Blitz-Pop).
func _on_engraving_applied(_engraving_id: String, slot_px: Vector2) -> void:
	if not engraving_active:
		return
	table_screen.spawn_trace(slot_px, die_inspector.stage_center_px(), ENGRAVE_ABSORB_COLOR, ENGRAVE_TRAIL_TIME)
	await get_tree().create_timer(ENGRAVE_TRAIL_TIME).timeout
	if not engraving_active:
		return
	_refresh_engraving_die_faces()
	_flash_engraving_die()

## Zieht die Augenzahlen des schwebenden Würfels aus current_def nach.
func _refresh_engraving_die_faces() -> void:
	if engraving_die == null or not is_instance_valid(engraving_die):
		return
	if die_inspector.current_def == null:
		return
	var faces: DieFaceDisplay = engraving_die.get_node("RigidBody3D/Faces")
	faces.apply_definition(die_inspector.current_def)
	faces.set_tint(DiceController.KIND_TINTS.get(die_inspector.current_def.style_id, Color.WHITE))
	_highlight_engraving_die()  # apply_definition setzt die Seiten zurück

## Hebt die gewählte Seite (bzw. den Kanten-Rahmen) am ECHTEN schwebenden
## Würfel violett hervor - dieselbe Auswahl wie an der 3D-Projektion.
func _highlight_engraving_die() -> void:
	if engraving_die == null or not is_instance_valid(engraving_die):
		return
	if die_inspector.current_def == null:
		return
	var faces: DieFaceDisplay = engraving_die.get_node("RigidBody3D/Faces")
	faces.set_tint(DiceController.KIND_TINTS.get(die_inspector.current_def.style_id, Color.WHITE))
	faces.reset_number_tints()
	if die_inspector.edges_targeted():
		# Gehaltene Kanten-Gravur: der Rahmen ist das Ziel.
		faces.set_edge_tint(RotatableDieView.SELECT_FACE_COLOR)
	elif die_inspector.selected_face != -1:
		# Nur die gewählte ZIFFER leuchtet - der Würfelkörper bleibt neutral.
		faces.set_face_number_tint(die_inspector.selected_face, RotatableDieView.SELECT_FACE_COLOR)

## Absorptions-Blitz: heller Aufpluster-Pop bei der Ankunft der Leiterbahn.
func _flash_engraving_die() -> void:
	if engraving_die == null or not is_instance_valid(engraving_die):
		return
	var base := Vector3.ONE * DiceTrayView.DIE_SCALE
	var pop := create_tween()
	pop.tween_property(engraving_die, "scale", base * 1.18, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(engraving_die, "scale", base, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Beendet die Zeremonie: Tray-Slot wieder sichtbar, Kamera zurück in die
## Ansicht von vor der Zeremonie; was der Hub zeigt, entscheidet er selbst.
func _end_engraving_ceremony() -> void:
	if not engraving_active:
		return
	engraving_active = false
	camera_rig.release_tilt_immediately()  # falls noch eine Dreh-Geste "hängt"
	_free_engraving_die()
	if engraving_source_root != null and is_instance_valid(engraving_source_root):
		engraving_source_root.visible = true
	engraving_source_root = null
	engraving_source_tray = null
	if engraving_prev_mode == CameraRig.Mode.OVERVIEW:
		camera_rig.zoom_out()
	else:
		camera_rig.zoom_to(engraving_prev_mode)
	_on_die_engraved()  # Trays sicher aktuell

## Paket im Laden gekauft: es FÄHRT als Licht die Hub-Werkstatt-Ader entlang und
## liegt erst bei Ankunft im Lager - der Komet ist das Paket, nicht seine Ankündigung.
func _on_pack_purchased(from_px: Vector2, pack_type: String) -> void:
	if table_screen == null or table_screen.workshop_window == null:
		return
	var window := table_screen.workshop_window
	window.expect_delivery()
	var tint: Color = PackIconRenderer.COLORS.get(pack_type, Color.WHITE)
	var travel := table_screen.pack_delivery_comet(from_px, tint)
	if travel > 0.0:
		await get_tree().create_timer(travel).timeout
	if is_instance_valid(window):
		window.deliver_pack()

## Ein Stück fliegt aus dem zerbrochenen Siegel: als Meteor in seiner SELTENHEITS-
## farbe, geschleudert und doch auf seine Schublade zu. Der Einschlag ist die
## eigentliche Auflösung - der getroffene Platz glüht danach nach, damit der
## Spieler in Ruhe liest, was angekommen ist. Der Takt kommt aus der Zeremonie.
func _on_engraving_dispatched(engraving_id: String, from_px: Vector2, rarity: int) -> void:
	_fly_engraving_to_drawer(engraving_id, from_px, rarity)

## Der Meteor selbst - geteilt von der Paket-Zeremonie und den Automaten-Gewinnen:
## beide schicken eine Gravur aus einem Fenster in ihren Schubladen-Platz.
func _fly_engraving_to_drawer(engraving_id: String, from_px: Vector2, rarity: int) -> void:
	if table_screen == null or table_screen.workshop_window == null:
		return
	for drawer in table_screen.supply_drawers:
		var target := drawer.slot_center_px(engraving_id)
		if target.x < 0.0:
			continue
		var tint: Color = EngravingRenderer.SEAM_COLORS[rarity]
		var spread := _meteor_index
		_meteor_index += 1
		var travel := table_screen.meteor_comet(from_px, drawer.category, target, tint, spread)
		if travel > 0.0:
			await get_tree().create_timer(travel).timeout
		if is_instance_valid(drawer):
			drawer.pop(engraving_id, tint)
		return

## Klick ins Würfel-Raster der Station: Ziel auf diesen Würfel wechseln
## (No-Op, wenn es der bereits gegriffene ist).
func _on_tray_die_selected(slot: int) -> void:
	if not engraving_active or engraving_source_tray == null:
		return
	if slot < 0 or slot >= engraving_source_tray.slot_roots.size():
		return
	_grab_engraving_die(engraving_source_tray.slot_defs[slot],
		engraving_source_tray.slot_roots[slot], engraving_source_tray)

## Füllt das Würfel-Raster der Station mit dem Ursprungs-Tray (leere Slots als
## leere Zellen), der gerade bearbeitete Würfel ist hervorgehoben.
func _refresh_engraving_target_grid() -> void:
	if engraving_source_tray == null:
		return
	var tray := engraving_source_tray
	var slot_defs: Array[DieDefinition] = []
	for i in tray.slot_roots.size():
		var occupied: bool = tray.slot_roots[i].visible or tray.slot_roots[i] == engraving_source_root
		slot_defs.append(tray.slot_defs[i] if occupied else null)
	# In der FORM des Trays (Spaltenzahl übernommen): das Raster im Editor liest
	# sich wie das echte Tray darüber, Platz für Platz.
	die_inspector.set_target_grid(tray.columns, slot_defs, tray.slot_roots.find(engraving_source_root))

## Harter Abbruch der Zeremonie ohne Animationen (Spiel-Reset).
func _abort_engraving() -> void:
	engraving_active = false
	_free_engraving_die()
	if engraving_source_root != null and is_instance_valid(engraving_source_root):
		engraving_source_root.visible = true
	engraving_source_root = null
	engraving_source_tray = null
	die_inspector.visible = false  # ohne closed-Signal

## Gibt den schwebenden Zeremonien-Würfel frei und stoppt seinen Flug-Tween.
func _free_engraving_die() -> void:
	if engraving_fly_tween != null and engraving_fly_tween.is_valid():
		engraving_fly_tween.kill()
	engraving_fly_tween = null
	if engraving_die != null and is_instance_valid(engraving_die):
		engraving_die.queue_free()
	engraving_die = null

## Klick auf einen Warteschlangen-Würfel: startet einen POTENZIELLEN
## Umsortier-Drag; ob es ein Drag oder nur ein Klick (öffnet die Gravur)
## wird, entscheidet REORDER_DRAG_THRESHOLD beim Loslassen.
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
## ab; Bewegung über den Schwellwert hebt den Würfel an; Loslassen ohne
## Bewegung öffnet stattdessen die Gravur-Station.
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
		else:
			_open_engraving(queue_tray_view.slot_defs[reorder_drag_index], queue_tray_view.slot_roots[reorder_drag_index], queue_tray_view)
		reorder_drag_index = -1
		reorder_is_dragging = false

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
## Nur in Gruben-/Charm-Sicht (in der Übersicht bleibt der Klick ein Zoom);
## Loslassen ohne Bewegung tut nichts (der Hover-Tooltip zeigt schon alles).
func _try_start_charm_reorder(screen_pos: Vector2) -> bool:
	if camera_rig.is_animating or table_screen.charm_dock == null:
		return false
	if not (is_pit_focused or camera_rig.mode == CameraRig.Mode.CHARMS):
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

## Schwarzmarkt-Fenster: die Glas-Tasche UNTER den Automaten. Rechte Kante und
## Unterkante sind gesetzt (bündig mit der Automaten-Spalte bzw. mit dem Hub);
## die LINKE Kante ist ausgerechnet, nicht geraten - die Ellipse steigt nach links
## an, also rückt sie so weit nach rechts, bis das Glas die Unterkante trägt.
func _secret_shop_rect(slots_rect: Rect2, hub_rect: Rect2) -> Rect2:
	var top := slots_rect.end.y + SECRET_SHOP_TOP_GAP
	var bottom := hub_rect.end.y
	var right := slots_rect.end.x
	var left := slots_rect.position.x
	# Schrittweise nach rechts, bis das Glas an dieser Spalte tief genug reicht.
	var step := (right - left) / 64.0
	while left < right - step \
			and table_screen.glass_bottom_limit(left) < bottom + SECRET_SHOP_GLASS_MARGIN:
		left += step
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))

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

## Die Schubladen-Reihe unter der Werkbank: je Kategorie so breit wie ihr Inhalt
## (Zahlen am breitesten, Kanten am schmalsten), zusammen auf der Werkbank-Breite
## verteilt. Die y-Position setzt der Aufrufer.
func _supply_drawer_rects(origin: Vector2, total_width: float, unit: float) -> Array[Rect2]:
	var sizes: Array[Vector2] = []
	var content_width := 0.0
	var height := 0.0
	for drawer_category in Engraving.CATEGORIES:
		var drawer_size := SupplyDrawerView.size_for(drawer_category, unit)
		sizes.append(drawer_size)
		content_width += drawer_size.x
		height = maxf(height, drawer_size.y)
	# Luft dazwischen, aber gedeckelt - sonst driften die drei Schubladen über die
	# ganze Werkbank-Breite auseinander und wirken wie drei fremde Fenster.
	var slack := maxf(0.0, total_width - content_width)
	var gap := minf(slack / float(maxi(sizes.size() - 1, 1)), unit * 4.0)
	var rects: Array[Rect2] = []
	# Linksbündig unter der Werkbank: die breiteste Schublade (Zahlen) beginnt an
	# derselben Kante wie das Fenster darüber.
	var x := origin.x
	for drawer_size in sizes:
		rects.append(Rect2(Vector2(x, origin.y), Vector2(drawer_size.x, height)))
		x += drawer_size.x + gap
	return rects

## Zoom-Ziel + Klickzone EINES Display-Fensters aus seinem Screen-Rechteck -
## einheitlich für alle Tisch-Fenster (Kombis, Wettannahme, künftige Screens):
## Klick zoomt heran, Rechtsklick zurück, im Zoom leichtes Rundschauen.
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
	camera_rig.configure_hub_target(center)
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

## Ob ein Display-Pixel an die Bildschirm-UI geht: Hub-Sicht = ganzes Panel;
## Grubensicht = nur die Aktions-Buttons; sonst gehen KLICKS nur an
## interaktive Punkte (leere Hub-Fläche bleibt Zoom), Bewegungen aber über
## der ganzen Fläche (sauberer Button-Hover).
func _screen_forwards_pixel(pixel: Vector2, is_click: bool) -> bool:
	match camera_rig.mode:
		CameraRig.Mode.HUB, CameraRig.Mode.TITLE:
			return table_screen.hub != null and table_screen.hub.get_rect().has_point(pixel)
		CameraRig.Mode.PIT:
			# Liegt die Auslage auf dem Grubenboden, gehören die Klicks ihr.
			if route_choice != null and route_choice.visible \
					and Rect2(route_choice.position, route_choice.size).has_point(pixel):
				return true
			return table_screen.pit_actions_hit(pixel)
		CameraRig.Mode.SIDE_BETS:
			# Im Zoom auf die Wettannahme gehen Klicks/Hover an die Setzen-Knöpfe.
			return _side_bet_window_has_point(pixel)
		CameraRig.Mode.SLOTS:
			# Im Zoom auf die Automaten gehen Klicks/Hover an die Dreh-/Auszahlen-Knöpfe.
			return _slot_bank_window_has_point(pixel)
		CameraRig.Mode.SECRET_SHOP:
			# Im Zoom auf den Schwarzmarkt an die Angebots-Karten und den Misch-Knopf.
			return _secret_shop_window_has_point(pixel)
		CameraRig.Mode.WORKSHOP:
			# Im Zoom auf die Werkstatt gehen Klicks/Hover an die Lager-Karten.
			return _workshop_window_has_point(pixel)
	if table_screen.hub == null or not table_screen.hub.get_rect().has_point(pixel):
		return false
	return not is_click or table_screen.hub.interactive_at(pixel)

## Ob ein Display-Pixel im sichtbaren Wettannahme-Fenster liegt.
func _side_bet_window_has_point(pixel: Vector2) -> bool:
	if table_screen == null:
		return false
	var window := table_screen.side_bet_window
	return window != null and window.visible \
		and Rect2(window.position, window.size).has_point(pixel)

## Ob ein Display-Pixel im sichtbaren Schwarzmarkt-Fenster liegt.
func _secret_shop_window_has_point(pixel: Vector2) -> bool:
	if table_screen == null:
		return false
	var window := table_screen.secret_shop_window
	return window != null and window.visible \
		and Rect2(window.position, window.size).has_point(pixel)

## Ob ein Display-Pixel im sichtbaren Automaten-Fenster liegt.
func _slot_bank_window_has_point(pixel: Vector2) -> bool:
	if table_screen == null:
		return false
	var window := table_screen.slot_bank_window
	return window != null and window.visible \
		and Rect2(window.position, window.size).has_point(pixel)

## Doppelklick auf FREIE Werkbank-Fläche öffnet die zweite Zoomstufe (näher,
## Trays aus dem Bild, Kamera steht still). Auf einem Knopf passiert nichts -
## der Doppelklick ist dort schon der zweite Klick auf die Karte.
func _try_workshop_close_zoom(event: InputEvent) -> bool:
	if camera_rig.mode != CameraRig.Mode.WORKSHOP or camera_rig.workshop_close:
		return false
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or not button.double_click \
			or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null or table_screen == null:
		return false
	var pixel := table_screen.pixel_from_ray(
		camera.project_ray_origin(button.position), camera.project_ray_normal(button.position))
	if pixel.x < 0.0 or not workshop_close_rect.has_point(pixel):
		return false
	if _workshop_interactive_at(pixel):
		return false
	camera_rig.zoom_workshop_close()
	return true

## Spiegelung aus, wo gespiegelte Würfel ins Bild geistern: im Titel-HUD und in
## der Werkbank-Nahsicht (die Trays liegen dort knapp außerhalb des Rahmens und
## spiegelten sich quer über das Werkstattfenster).
func _sync_screen_reflection() -> void:
	if screen_reflection == null:
		return
	screen_reflection.set_enabled(camera_rig.mode != CameraRig.Mode.TITLE
		and not camera_rig.workshop_close)

## Ob unter dem Display-Pixel ein aktiver Knopf der Werkbank-Ecke liegt
## (Fenster samt Station, Schubladen).
func _workshop_interactive_at(pixel: Vector2) -> bool:
	if table_screen.workshop_window != null and table_screen.workshop_window.visible \
			and TableScreen.interactive_under(table_screen.workshop_window, pixel):
		return true
	for drawer in table_screen.supply_drawers:
		if drawer.visible and TableScreen.interactive_under(drawer, pixel):
			return true
	return false

## Ob ein Display-Pixel in der Werkbank-Ecke liegt - Fenster ODER Schublade;
## die Zeremonie reicht über beide (Werkzeug links unten, Würfel im Fenster).
func _workshop_window_has_point(pixel: Vector2) -> bool:
	if table_screen == null:
		return false
	var window := table_screen.workshop_window
	if window != null and window.visible and Rect2(window.position, window.size).has_point(pixel):
		return true
	for drawer in table_screen.supply_drawers:
		if drawer.visible and Rect2(drawer.position, drawer.size).has_point(pixel):
			return true
	return false

## Klick auf eine Zoom-Zone (Layer 8): Kamera fährt heran. Der Grubenklick zoomt
## nur noch (kein Wurf mehr - dafür Energie-Hülle oder der "Würfeln"-Knopf).
func _try_zoom_click(screen_pos: Vector2) -> void:
	var result := _ray_pick(screen_pos, 8)
	if result.is_empty():
		return

	var collider: Object = result.collider
	if collider == pit_click_zone:
		camera_rig.zoom_to(CameraRig.Mode.PIT)
	elif collider == pool_tray_view.click_zone or collider == queue_tray_view.click_zone:
		camera_rig.zoom_to(CameraRig.Mode.POOL)
	elif collider == discard_tray_view.click_zone:
		camera_rig.zoom_to(CameraRig.Mode.DISCARD)
	elif collider == combos_click_zone:
		camera_rig.zoom_to(CameraRig.Mode.COMBOS)
	elif collider == charms_click_zone:
		camera_rig.zoom_to(CameraRig.Mode.CHARMS)
	elif collider == hub_click_zone:
		camera_rig.zoom_to(CameraRig.Mode.HUB)
	elif collider == side_bets_click_zone and run != null and run.side_bets_unlocked():
		camera_rig.zoom_to(CameraRig.Mode.SIDE_BETS)
	elif collider == slots_click_zone and run != null and run.slots_unlocked() > 0:
		camera_rig.zoom_to(CameraRig.Mode.SLOTS)
		# Beim Wechsel auf den Automaten die Dreh-Knöpfe auf den aktuellen Geldstand
		# bringen (er kann sich seit dem letzten Aufbau geändert haben).
		if table_screen.slot_bank_window != null:
			table_screen.slot_bank_window.refresh_if_idle()
	elif collider == workshop_click_zone:
		camera_rig.zoom_to(CameraRig.Mode.WORKSHOP)
	elif collider == score_click_zone:
		camera_rig.zoom_to(CameraRig.Mode.SCORE)
	elif collider == chips_click_zone:
		camera_rig.zoom_to(CameraRig.Mode.CHIPS)
	elif collider == secret_shop_click_zone:
		camera_rig.zoom_to(CameraRig.Mode.SECRET_SHOP)

func _process(delta: float) -> void:
	_update_charm_hover()
	_update_pit_hover(delta)
	_update_selection_glows()
	_sync_screen_action_buttons()

## Würfelnetz-Feld der Grube: zeigt den Würfel unter der Maus - ruhende
## Grubenwürfel (mit Gold-Rahmen auf der oben liegenden Seite) und die
## nächsten Würfel der Warteschlange (ohne Lage, die liegen ja noch nicht).
## Verlässt die Maus den Würfel, steht das Netz noch NET_LINGER_TIME - genug,
## um in das Feld zu fahren; dort hält es, und Zellen erklären ihr Material.
func _update_pit_hover(delta: float) -> void:
	if table_screen == null:
		return
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
func _show_pit_net(def: DieDefinition, up_face: int) -> void:
	_net_die_def = def
	_net_linger = NET_LINGER_TIME
	_net_fade = NET_FADE_TIME
	table_screen.set_pit_die(def, up_face)
	table_screen.set_pit_net_alpha(1.0)
	table_screen.set_pit_net_hint("")

## Kurz-Erklärzeile zur Netz-Zelle unter pixel: Materialname + Kurzwirkung
## (face_hint/edge_hint), plus die Leiterbahn der Seite. EDGE-Chip erklärt das
## Kanten-Material; "" ohne Material/Bahn oder außerhalb der Zellen.
func _net_face_hint(pixel: Vector2) -> String:
	if _net_die_def == null:
		return ""
	var face := table_screen.pit_net_face_at(pixel)
	if face == DieNetView.EDGE:
		return DieMaterial.edge_hint(_net_die_def.edge_material)
	if face < 0 or face >= _net_die_def.materials.size():
		return ""
	var hint := DieMaterial.face_hint(_net_die_def.materials[face], MaterialEffects.face_is_upgraded(_net_die_def, face))
	var target: int = _net_die_def.pointers[face] if face < _net_die_def.pointers.size() else -1
	if target >= 0:
		var pointer_hint := "Leiterbahn: löst die Seite mit Wert %d einmal mit aus" % _net_die_def.faces[target]
		hint = "%s  ·  %s" % [hint, pointer_hint] if hint != "" else pointer_hint
	return hint

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
		table_screen.bank_action_button.text = "Beenden ⚡×%d" % stages

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
	var want := phase == Phase.IDLE and has_rolled_current_hand
	var die_world := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT * 2.0
	var glow_side := die_world * SCORE_GLOW_SIZE_FACTOR * table_screen.pixels_per_world()
	var full_counter := want and run != null and run.charm_ids().has(Charm.FULL_COUNTER)
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
	if camera_rig.is_animating or charm_is_dragging:
		return
	var mouse := get_viewport().get_mouse_position()
	var index := charm_row.charm_index_at_screen_pos(camera_rig, mouse)
	if index == -1:
		var pixel := _screen_pixel(mouse)
		if pixel.x >= 0.0:
			index = table_screen.charm_dock.pad_index_at(pixel)
	table_screen.charm_dock.set_hover(index)

## Mausdruck auf der Energie-Hülle: Klick (unter REORDER_DRAG_THRESHOLD) =
## derselbe Wurf wie der Würfeln-Button, Ziehen dreht die Hülle - und hält
## während des Mischens den Misch-Timer offen (DiceShell.spin_impulse).
func _try_start_shell_drag(screen_pos: Vector2) -> bool:
	var result := _ray_pick(screen_pos, DiceShell.CLICK_LAYER)
	if result.is_empty():
		return false
	shell_drag_active = true
	shell_drag_start_pos = screen_pos
	shell_is_dragging = false
	return true

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
		if not shell_is_dragging:
			_on_throw_button_pressed()  # prüft alle Vorbedingungen selbst
		_end_shell_drag()

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

## True, solange der aktuelle Wurf sichtbar läuft (Hülle oder Physik).
func _dice_in_motion() -> bool:
	return phase == Phase.SHELL_ANIMATING or phase == Phase.ROLLING

## True in allen Phasen VOR dem Rundenabschluss (inklusive laufender Würfe).
func _is_playing() -> bool:
	return phase == Phase.IDLE or _dice_in_motion()

func _can_toggle_selection() -> bool:
	return phase == Phase.IDLE and has_rolled_current_hand

## true, solange eine Runde läuft: die Würfel sind dann tabu - Aufwertungen
## werden nur zwischen den Runden im Laden (Phase.SHOP) angewandt.
func _round_in_progress() -> bool:
	return phase != Phase.SHOP

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

## Kanten-Material je Wurf-Slot ("" = keins).
func _edge_materials() -> Array[String]:
	var materials: Array[String] = []
	for i in dice.count():
		materials.append(dice.slot_defs[i].edge_material)
	return materials

## Leiterbahn-Glieder je Wurf-Slot (nur Slots mit Kette): einmal HIER aufgelöst,
## damit Vorschau, Nehmen und Farkle-Vergleich dieselben Glieder sehen.
func _pointer_links() -> Dictionary:
	var links := {}
	for i in dice.count():
		var face: int = dice.face_indices[i]
		var def: DieDefinition = dice.slot_defs[i]
		if face < 0 or def == null:
			continue
		var chain := def.pointer_chain(face)
		if chain.is_empty():
			continue
		var entries: Array[Dictionary] = []
		for link_face in chain:
			entries.append({
				"face": link_face,
				"value": def.faces[link_face],
				"material": def.materials[link_face] if link_face < def.materials.size() else "",
				"upgraded": MaterialEffects.face_is_upgraded(def, link_face),
			})
		links[i] = entries
	return links

## Dotierungs-Infos je Wurf-Slot: ist das Material der OBEREN Seite auf Stufe II,
## dazu die beiden würfelweiten Zahlen, an denen dotierte Materialien hängen.
func _material_upgrades() -> Dictionary:
	var upgrades := {}
	for i in dice.count():
		var def: DieDefinition = dice.slot_defs[i]
		if def == null:
			continue
		var eye_sum := 0
		for value in def.faces:
			eye_sum += value
		upgrades[i] = {
			"upgraded": MaterialEffects.face_is_upgraded(def, dice.face_indices[i]),
			"eye_sum": eye_sum,
			"mercury_faces": def.materials.count(DieMaterial.MERCURY),
		}
	return upgrades

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
		CharmEffects.CTX_EDGE_DICE: run.edge_die_count(),
		# Leer, sobald das Rampenlicht diese Runde kassiert ist - dann bekommt
		# es auch keinen Schritt mehr in der Zähl-Animation.
		CharmEffects.CTX_SPOTLIGHT: "" if run.spotlight_claimed_this_round else run.spotlight_combo,
		DiceScoring.CTX_THROTTLED: run.throttled_combos,  # Klausel-/Boss-Drossel
		DiceScoring.CTX_PARITY: run.parity_filter(),  # Schieflage/Gleichgewicht
		DiceScoring.CTX_POINTER_LINKS: _pointer_links(),  # Leiterbahn-Ketten
		DiceScoring.CTX_MATERIAL_UPGRADES: _material_upgrades(),  # Dotierungen
	}

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
	# Leiterbahn-Glieder hängen ebenfalls am Slot - auf die gefilterte Auswahl
	# umschlüsseln, sonst feuert die Kette am falschen Würfel.
	var mapped_links := {}
	var links: Dictionary = ctx.get(DiceScoring.CTX_POINTER_LINKS, {})
	for s in links:
		if to_filtered.has(s):
			mapped_links[to_filtered[s]] = links[s]
	ctx[DiceScoring.CTX_POINTER_LINKS] = mapped_links
	# Dotierungen hängen ebenso am Slot - ohne Umschlüsselung wertet jede
	# Auswahl-Vorschau die falschen Würfel als gehoben.
	var mapped_upgrades := {}
	var upgrades: Dictionary = ctx.get(DiceScoring.CTX_MATERIAL_UPGRADES, {})
	for s in upgrades:
		if to_filtered.has(s):
			mapped_upgrades[to_filtered[s]] = upgrades[s]
	ctx[DiceScoring.CTX_MATERIAL_UPGRADES] = mapped_upgrades
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

## Schickt einen gebrauchten Würfel ins Ablage-Tray (gemerkt für die Phönixfeder).
func _discard_kind(def: DieDefinition) -> void:
	discarded_this_round.append(def)
	discard_tray_view.add_die(def)

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
	var pool_start := next_draw_index + _queue_display_capacity()
	pool_tray_view.fill(round_pool_kinds.slice(pool_start, round_pool_kinds.size()))

## Shop-Eröffnung: der ganze Bestand ruht sichtbar im Pool-Tray, Warteschlange
## und Ablage sind leer - die Runde ist vorbei, es wird nicht mehr gezogen.
func _return_dice_to_pool_tray() -> void:
	queue_tray_view.clear()
	discard_tray_view.clear()
	pool_tray_view.ensure_capacity(run.owned_pool.size())
	pool_tray_view.fill(run.owned_pool)

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
	return pool_tray_view.slot_global_position(offset - _queue_display_capacity())

## Freier, nicht-kollidierender Würfel für die Gleit-Animationen.
func _spawn_deck_ghost(def: DieDefinition) -> Node3D:
	var ghost := DieBuilder.build()
	add_child(ghost)
	ScreenReflection.mark_reflective(ghost)  # gleitet über das Glas -> spiegelt sich
	ghost.rotation.y = -PI / 2.0  # gleiche Ausrichtung wie die Tray-Würfel
	ghost.scale = Vector3.ONE * DiceTrayView.DIE_SCALE
	var body: RigidBody3D = ghost.get_node("RigidBody3D")
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	var faces: DieFaceDisplay = ghost.get_node("RigidBody3D/Faces")
	faces.apply_definition(def)
	faces.set_tint(DiceController.KIND_TINTS.get(def.style_id, Color.WHITE))
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
	pool_tray_view.clear()
	deck_shift_tween = create_tween()
	deck_shift_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	deck_shift_tween.set_parallel(true)
	for deck_index in range(next_draw_index, round_pool_kinds.size()):
		var ghost := _spawn_deck_ghost(round_pool_kinds[deck_index])
		ghost.global_position = _deck_slot_position(deck_index, old_cursor)
		deck_shift_ghosts.append(ghost)
		deck_shift_tween.tween_property(ghost, "global_position", _deck_slot_position(deck_index, next_draw_index), DECK_SHIFT_DURATION)
	deck_shift_tween.chain().tween_callback(_finish_deck_shift)

func _finish_deck_shift() -> void:
	_cancel_deck_shift()
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

	# Ersetzte (ungeschützte) Würfel fliegen gleichzeitig Richtung Ablage-Tray.
	var discard_from: Array[Vector3] = []
	var discard_defs: Array[DieDefinition] = []
	var discard_to: Array[Vector3] = []
	if has_rolled_current_hand:
		var next_free := discard_tray_view.next_free_index
		for i in dice.count():
			if dice.selected[i]:
				continue
			if next_free >= discard_tray_view.slot_roots.size():
				break
			discard_from.append(dice.bodies[i].global_position)
			discard_defs.append(active_kinds[i])
			discard_to.append(discard_tray_view.slot_global_position(next_free))
			dice.roots[i].visible = false
			next_free += 1

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
		pre_reroll_edge_materials = _edge_materials()
		pre_reroll_links = _pointer_links()
		pre_reroll_upgrades = _material_upgrades()
		for i in dice.count():
			if not dice.selected[i] and _remaining_in_pool() > 0:
				if i < slot_draw_positions.size():
					slot_draw_positions[i] = next_draw_index  # Bodensatz
				active_kinds[i] = _draw_one()
				thrown_indices.append(i)
		dice.set_slot_defs(active_kinds)
		# Effektkatalog-Zähler: Pendel, Anker, Alles-oder-nichts.
		rerolls_this_hand += 1
		pendulum_acc += 2 * thrown_indices.size()  # Pendel schwingt hoch (überlebt Runden)
		if thrown_indices.size() == dice.count():
			full_reroll_stacks += 1
		_update_charm_badges()
	_animate_deck_shift(next_draw_index - cursor_before_draw)

	await _play_shell_roll(fly_positions, fly_defs, discard_from, discard_defs, discard_to, move_top_indices, move_top_targets)
	if phase != Phase.SHELL_ANIMATING:
		dice_shell.clear_ghosts()
		return  # Spiel wurde während der Hüllen-Animation zurückgesetzt

	# poured_out feuert im Berst-Moment der Hülle - erst dann starten die
	# echten Würfel an der aktuellen Hüllenposition (kein Teleportieren).
	dice_shell.play_release()
	await dice_shell.poured_out
	dice_shell.clear_ghosts()
	if phase != Phase.SHELL_ANIMATING:
		return  # Spiel wurde während des Auskippens zurückgesetzt

	var start_positions := _throw_start_positions()
	for k in thrown_indices.size():
		var i: int = thrown_indices[k]
		dice.start_transforms[i] = Transform3D(dice.start_transforms[i].basis, start_positions[k])
	phase = Phase.ROLLING
	dice.throw_slots(thrown_indices, throw_force, spin_strength, DicePit.PIT_CENTER)
	_refresh_ui()

## Startpositionen der Wurf-Würfel: 3x2-Raster quer zur Flugrichtung am
## Berst-Punkt der Hülle. Abstand > Würfelbreite - überschneidungsfrei,
## sonst katapultiert die Physik-Depenetration die Würfel aus der Wurfbahn.
## Das Rasterzentrum wird in den Grubep-Innenraum geklemmt: die Energiewände
## sind 16 hoch - ein Berst-Punkt außerhalb des Rands spawnt sonst IN der Wand.
func _throw_start_positions() -> Array[Vector3]:
	var mouth := dice_shell.mouth_position()
	var center := mouth
	var lim_x := DicePit.PIT_HALF_X - 4.6  # Rasterarm (2.3) + Würfel-/Wandrand
	var lim_z := DicePit.PIT_HALF_Z - 4.6
	center.x = clampf(center.x, DicePit.PIT_CENTER.x - lim_x, DicePit.PIT_CENTER.x + lim_x)
	center.z = clampf(center.z, DicePit.PIT_CENTER.z - lim_z, DicePit.PIT_CENTER.z + lim_z)
	var dir := DicePit.PIT_CENTER - center
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var right := dir.cross(Vector3.UP).normalized()
	var positions: Array[Vector3] = []
	for i in dice.count():
		var col := float(i % 3) - 1.0
		var row := float(int(i / 3.0))
		positions.append(center + right * col * 2.3 + Vector3.UP * row * 2.3
			+ dir * randf_range(-0.3, 0.3))
	return positions

## Zielposition eines geschützten Würfels am oberen Grubenrand: mittig
## zentrierte Reihe; y bleibt die des Würfels (kein Höhensprung).
func _pit_top_row_position(slot_number: int, count: int, y: float) -> Vector3:
	var span := PIT_TOP_ROW_SPACING * float(count - 1)
	var z := -span * 0.5 + PIT_TOP_ROW_SPACING * float(slot_number)
	return Vector3(DicePit.PIT_CENTER.x + PIT_TOP_ROW_X, y, DicePit.PIT_CENTER.z + z)

## Rückt die ausgerollten Würfel in eine zentrierte Reihe in der Grubenmitte:
## erst die Kombinations-Würfel (Auswahl), dann die übrigen, je mit den
## höchsten Augen zuerst. Reine Kosmetik - jeder Würfel behält seine
## gewürfelte Oben-Seite und dreht sich nur gerade. Die Körper werden
## eingefroren; der nächste Wurf gibt sie wieder frei.
func _line_up_settled_dice() -> void:
	_cancel_lineup()
	# Nur sichtbare Würfel - unsichtbare Slots sollen keine Lücken reißen.
	var indices: Array[int] = []
	for i in dice.count():
		if dice.roots[i].visible:
			indices.append(i)
	if indices.is_empty():
		return
	indices.sort_custom(func(a: int, b: int) -> bool:
		if dice.selected[a] != dice.selected[b]:
			return dice.selected[a]  # Kombinations-Würfel nach links
		if dice.values[a] != dice.values[b]:
			return dice.values[a] > dice.values[b]
		return a < b)
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
## DiceShell.capture_die), ersetzte fliegen Richtung Ablage (erst bei der
## Ankunft wirklich abgelegt), geschützte gleiten an den oberen Grubenrand.
func _play_shell_roll(fly_positions: Array[Vector3], fly_defs: Array[DieDefinition], discard_from: Array[Vector3], discard_defs: Array[DieDefinition], discard_to: Array[Vector3], move_top_indices: Array[int], move_top_targets: Array[Vector3]) -> void:
	if fly_defs.is_empty() and discard_defs.is_empty() and move_top_indices.is_empty():
		return

	var fly_tween := create_tween()
	fly_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fly_tween.set_parallel(true)

	var fly_ghosts: Array[Node3D] = []
	var mouth := dice_shell.mouth_position()
	for i in fly_defs.size():
		var ghost := _spawn_deck_ghost(fly_defs[i])
		ghost.global_position = fly_positions[i]
		fly_ghosts.append(ghost)
		var target := mouth + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.4), randf_range(-0.6, 0.6))
		fly_tween.tween_property(ghost, "global_position", target, SHELL_FLY_DURATION)

	var discard_ghosts: Array[Node3D] = []
	for i in discard_defs.size():
		var ghost := _spawn_deck_ghost(discard_defs[i])
		ghost.global_position = discard_from[i]
		discard_ghosts.append(ghost)
		fly_tween.tween_property(ghost, "global_position", discard_to[i], SHELL_FLY_DURATION)

	for k in move_top_indices.size():
		var body := dice.bodies[move_top_indices[k]]
		body.freeze = true
		fly_tween.tween_property(body, "global_position", move_top_targets[k], SHELL_FLY_DURATION)

	await fly_tween.finished
	# Ankunft: Flug-Ghost gegen echten Taumel-Würfel in der Hülle tauschen.
	for i in fly_ghosts.size():
		dice_shell.capture_die(fly_defs[i], fly_ghosts[i].global_position)
		fly_ghosts[i].queue_free()
	for i in discard_ghosts.size():
		discard_ghosts[i].queue_free()
		_discard_kind(discard_defs[i])

	if not fly_defs.is_empty():
		await dice_shell.play_shuffle()

func _on_roll_finished() -> void:
	phase = Phase.IDLE

	# Farkle-Prüfung: nur ein echtes Neu-Würfeln kann farkeln. Die alte Seite
	# rechnet mit IHREN Leiterbahn-Gliedern (vor dem Neuwurf), wie mit den
	# alten Materialien.
	var old_ctx := _score_ctx()
	old_ctx[DiceScoring.CTX_POINTER_LINKS] = pre_reroll_links
	old_ctx[DiceScoring.CTX_MATERIAL_UPGRADES] = pre_reroll_upgrades
	if last_throw_was_reroll and not DiceScoring.is_strictly_better(dice.values, pre_reroll_values, run.charm_ids(), _rolled_materials(), pre_reroll_materials, _edge_materials(), pre_reroll_edge_materials, run.combo_levels, _score_ctx(), old_ctx):
		# Anker: der ERSTE Neuwurf jeder Hand kann nicht farkeln.
		if CharmEffects.anchor_saves(run.charm_ids(), rerolls_this_hand):
			hand_note = "Anker: Der erste Neuwurf kann nicht farkeln – die Hand läuft weiter."
			_flash_charm_and_pad(run.charm_ids().find(Charm.ANCHOR))
			dice.clear_selection()
			_auto_select_best_combo()
			_line_up_settled_dice()
			has_rolled_current_hand = true
			last_throw_was_reroll = false
			_refresh_deck_trays()
			_refresh_ui()
			return
		_on_farkle()
		return

	# Beste offene Kombination automatisch vorschlagen (frei umklickbar), erst
	# DANACH aufreihen - die Reihe sortiert die Kombinations-Würfel nach links.
	dice.clear_selection()
	_auto_select_best_combo()
	_line_up_settled_dice()

	has_rolled_current_hand = true
	_refresh_deck_trays()
	_refresh_ui()

## Farkle: die Hand wird normalerweise ohne Punkte verworfen. Charms mildern:
## Schornsteinfeger verzeiht den ersten je Runde, Phönixfeder schickt die
## Würfel zurück in den Stapel, Kristallkugel zahlt fürs Überleben.
func _on_farkle() -> void:
	var ids := run.charm_ids()

	# Schornsteinfeger: die Hand läuft mit den aktuellen Würfeln weiter;
	# ein verziehener Farkle löst KEINE Farkle-Effekte aus.
	if CharmEffects.forgives_first_farkle(ids) and not chimney_sweep_used_this_round:
		chimney_sweep_used_this_round = true
		hand_note = "Schornsteinfeger: Farkle verziehen – die Hand darf weiterlaufen."
		dice.clear_selection()
		_auto_select_best_combo()
		has_rolled_current_hand = true
		last_throw_was_reroll = false
		_refresh_deck_trays()
		_refresh_ui()
		return

	# Ankerklausel: der erste Farkle JEDER Runde ist verziehen - dieselbe
	# Mechanik wie der Schornsteinfeger, nur aus dem Vertrag.
	if run.deal_anchor_active() and not anchor_clause_used_this_round:
		anchor_clause_used_this_round = true
		hand_note = "Ankerklausel: Der erste Farkle dieser Runde zählt nicht."
		dice.clear_selection()
		_auto_select_best_combo()
		has_rolled_current_hand = true
		last_throw_was_reroll = false
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
	if table_screen != null:
		table_screen.pit_fumble()

	# Ein verziehener Farkle (oben) zählt bewusst NICHT gegen die "Saubere Runde".
	round_farkled = true
	_refresh_side_bet_panel()

	# Zerbrochener Spiegel zählt, die Momentum-Serie reißt, Galgenhumor merkt vor.
	run.farkle_count += 1
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
		hand_note = "Standuhr: Farkle – die Rundenpunkte verdoppeln sich!"

	# Phönixfeder: beim ERSTEN Fumble der Runde wandern die Würfel zurück in den
	# Nachziehstapel statt in die Ablage (die Hand bleibt trotzdem verloren).
	if CharmEffects.has_phoenix(ids) and not phoenix_used_this_round:
		phoenix_used_this_round = true
		round_pool_kinds.append_array(active_kinds)
		hand_note = "Phönixfeder: Fumble – die Würfel kehren in den Nachziehstapel zurück."
	else:
		for kind in active_kinds:
			_discard_kind(kind)

	# Versicherungsbetrug: jeder echte Farkle zahlt Trostgeld.
	var consolation := run.farkle_consolation()
	if consolation > 0:
		run.add_money(consolation)

	if _round_should_end():
		_on_round_complete()
	else:
		# Überlebter Farkle: Kristallkugel zahlt.
		var income := CharmEffects.farkle_survival_income(ids)
		if income > 0:
			run.add_money(income)
		_start_new_hand()

## Klausel-Wirkungen einer genommenen Hand: Gebühren, Wartungs-Gravur, Hitzestau
## und die mitwachsende Boss-Drossel. Gebühren nehmen nie mehr, als da ist - ein
## negativer Kontostand hätte im ganzen Laden keine Bedeutung.
func _apply_hand_clauses(combo_key: String, scored_dice: int) -> void:
	var fee := run.hand_fee() + run.scored_die_fee() * scored_dice
	if fee > 0:
		run.add_money(-mini(fee, run.money))
	if run.grants_engraving_per_hand():
		run.grant_engraving(run.roll_stamp_engraving())
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
	var best := CharmEffects.target_die(dice.values, lying, true)
	if best >= 0:
		dice.set_selected(best, true)
	_line_up_settled_dice()
	has_rolled_current_hand = true
	last_throw_was_reroll = false
	hand_note = "Flickenteppich: Der höchste Würfel bleibt liegen – die Hand läuft weiter."
	_flash_charm_and_pad(ids.find(Charm.PATCHWORK_RUG))
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
	var edge_materials := _edge_materials()
	var sel_values: Array[int] = []
	var sel_materials: Array[String] = []
	var sel_edges: Array[String] = []
	for s in slots:
		sel_values.append(dice.values[s])
		sel_materials.append(materials[s])
		sel_edges.append(edge_materials[s])

	# is_first_hand VOR dem Hochzählen von hands_taken_this_round auswerten.
	var sel_ctx := _score_ctx_for_slots(slots)
	var hand := DiceScoring.best_hand(sel_values, ids, hands_taken_this_round == 0, sel_materials, sel_edges, run.combo_levels, sel_ctx)
	# Zähl-Reihenfolge steckt in der Wertung selbst (DiceScoring.trigger_order =
	# die aufgereihte Reihe) - kein Anordnungs-Parameter mehr, seit Krits am
	# Würfel hängen können und die Ordnung wertungsrelevant ist.
	# Schrittliste VOR den Nehmen-Effekten bauen (Knochen/Glas verändern gleich
	# die Seiten); ihre Indizes auf echte Slots zurückrechnen.
	var breakdown := ScoreBreakdown.build(hand["key"], sel_values, ids, hands_taken_this_round == 0, sel_materials, sel_edges, run.combo_levels, sel_ctx)
	_remap_breakdown_to_slots(breakdown, slots)
	hands_taken_this_round += 1
	var new_total: int = hand_total + int(breakdown["total"])
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
	# Knochen/Glas verändern die Pool-Würfel dauerhaft.
	var sel_participating := DiceScoring.participating_indices(hand["key"], sel_values, ids, sel_ctx)
	var sel_scored := CharmEffects.scored_indices(sel_participating, sel_values.size(), ids)
	var participating: Array[int] = []
	for p in sel_scored:
		participating.append(slots[p])
	# Echo-Kammer: in Auswahl-Indizes bestimmt, dann auf den echten Slot zurück.
	var echo_sel := CharmEffects.first_participating(sel_values, sel_scored)
	var echo_slot := slots[echo_sel] if echo_sel >= 0 else -1
	var report := MaterialEffects.apply_take_effects(active_kinds, dice.face_indices, materials, participating, edge_materials, ids, echo_slot)
	var take_money := report.money

	# Midashandschuh: eine Hand über alle sechs Würfel vergoldet jede oben
	# liegende Seite - dauerhaft, also erst NACH den übrigen Nehmen-Effekten.
	var gilded := run.apply_midas_glove(active_kinds, dice.face_indices, participating)
	if not gilded.is_empty():
		_flash_charm_and_pad(ids.find(Charm.MIDAS_GLOVE))
		for slot in gilded:
			_flash_scoring_die(slot)
		hand_note = "Midashandschuh: %d Seiten vergoldet." % gilded.size()

	# Lumpensammler beim Nehmen. Straßenmusiker zahlt NICHT hier, sondern pro
	# ausgelöstem Würfel während der Zähl-Animation (siehe _play_take_animation).
	take_money += CharmEffects.rag_collector_income(dice.values, run.lumpensammler_value, ids)
	if take_money > 0:
		run.add_money(take_money)
	# Goldrausch: nur die ERSTE Hand der Runde, und nur wenn sie alle liegenden
	# Würfel nutzt -> Geld +20% (max. $50). hands_taken_this_round zählt oben schon.
	# Zahlt als Chip-Pakete vom Charm-Pad zur Truhe, wie die Rundenende-Charms;
	# die Phase bleibt solange SCORING, damit kein Wurf dazwischenfunkt.
	if CharmEffects.gold_rush_applies(ids, participating.size(), dice.count(), hands_taken_this_round == 1):
		var rush := CharmEffects.gold_rush_income(run.money)
		if rush > 0:
			await _play_charm_money_payout(ids.find(Charm.GOLD_RUSH), rush, Phase.SCORING)
			if phase != Phase.SCORING:
				return  # Reset während der Zeremonie
	phase = Phase.IDLE

	# Momentum/Galgenhumor/Pendel/Alles-oder-nichts fortschreiben.
	momentum_streak += 1
	first_hand_after_farkle = false
	taken_dice_this_round += dice.count()
	pendulum_acc = maxi(0, pendulum_acc - dice.count())  # Pendel schwingt zurück, nie unter 0
	full_reroll_stacks = 0
	_apply_hand_clauses(String(hand["key"]), participating.size())
	_update_charm_badges()
	_refresh_side_bet_panel()  # Live-Fortschritt der Nebenwetten (alle Stats final)

	# Recycling: die erste genommene Hand kehrt ans Stapel-Ende zurück.
	if CharmEffects.recycles_first_hand(ids) and not recycling_used_this_round:
		recycling_used_this_round = true
		round_pool_kinds.append_array(active_kinds)

	for kind in active_kinds:
		_discard_kind(kind)

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

	# Straßenmusiker zahlt PRO ausgelöstem Würfel: je Dock-Position ein $1-Paket,
	# im Moment des Würfel-Triggers (nicht gebündelt am Ende).
	var musician_indices: Array[int] = []
	var cids := run.charm_ids()
	for j in cids.size():
		if cids[j] == Charm.STREET_MUSICIAN:
			musician_indices.append(j)

	# 3) Würfel-Schritte in Reihen-Ordnung: je Aktivierung Augen + Material,
	# dann die würfelgebundenen Charms DIESES Würfels (additiv, dann Krit) -
	# sie feuern mit ihm, nicht in der Charm-Phase. Alles strömt.
	for step: Dictionary in breakdown["die_steps"]:
		var slot: int = step["slot"]
		_pay_street_musician(musician_indices)
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
		if int(step.get("crit_x", 1)) > 1:
			if not await _play_crit_step(step):
				return
			continue
		for charm_index: int in step["charm_indices"]:
			_flash_charm_and_pad(charm_index)
		var source_px := _charm_trail_source_px(step["charm_indices"])
		var ctargets: Array[String] = []
		if step["base_add"] != 0 or step["base_x"] != 1:
			ctargets.append("base")
		if step["mult_add"] != 0 or step["mult_x"] != 1:
			ctargets.append("mult")
		var cbase: int = step["base_after"]
		var cmult: int = step["mult_after"]
		_spawn_score_gains(source_px, step["base_add"], step["mult_add"], step["base_x"], step["mult_x"])
		var charm_travel := 0.0
		if not ctargets.is_empty():
			charm_travel = _fire_score_light(source_px, "charm", ctargets,
				func() -> void: table_screen.update_pit_score(cbase, cmult))
		if not await _score_arrival_gap(charm_travel):
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

## Würfel-Schritt: jede Auslösung als eigene Kette Würfel-Puls (Augen+Material)
## -> Charm-Anteil (würfelgebundene Charms, Komet vom Dock-Pad) -> Krit-Schlag
## (Beherit), mit eigener Ankunftspause je Glied - so ist das Mehrfach-Auslösen
## (Quecksilber, Retrigger-Charms, Echo-Kammer) als Verzahnung sichtbar.
## false = Abbruch (Reset).
func _play_die_step(step: Dictionary, slot: int, die_px: Vector2, gain_px: Vector2, glow_by_slot: Dictionary) -> bool:
	for pulse: Dictionary in step["activations"]:
		if not await _play_die_pulse(pulse, slot, die_px, gain_px, glow_by_slot,
				step["eye_charm_indices"], step["die_charm_indices"], step["crit_charm_indices"]):
			return false
	# Leiterbahn-Glieder: NACH allen Aktivierungen, je Glied einmal. Das Netz-Feld
	# zeigt den Würfel mit dem GLIED im Gold-Rahmen - so wandert die Kette sichtbar.
	for link: Dictionary in step.get("links", []):
		if slot < active_kinds.size():
			_show_pit_net(active_kinds[slot], int(link["face"]))
		if not await _play_die_pulse(link, slot, die_px, gain_px, glow_by_slot,
				[], link["die_charm_indices"], link["crit_charm_indices"]):
			return false
	return true

## Eine Auslösung des Würfel-Schritts - Aktivierung ODER Leiterbahn-Glied:
## Augen+Material-Komet, dann Charm-Anteil vom Dock-Pad, dann Krit-Schlag.
## false = Abbruch (Reset).
func _play_die_pulse(pulse: Dictionary, slot: int, die_px: Vector2, gain_px: Vector2, glow_by_slot: Dictionary, eye_charm_indices: Array, die_charm_indices: Array, crit_charm_indices: Array) -> bool:
	_flash_scoring_die(slot)
	if glow_by_slot.has(slot):
		_pulse_glow(glow_by_slot[slot])
	for charm_index: int in eye_charm_indices:
		_flash_charm_and_pad(charm_index)
	var p_base: int = pulse["base_after"]
	var p_mult: int = pulse["mult_after"]
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
		var pca_mult: int = pulse["charm_mult_after"]
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
	# Krit-Schlag (Beherit) dieser Auslösung: der Würfel blitzt erneut,
	# dann schlägt der heiße Komet am Mult ein (Hit-Stop, Stoßwellen).
	var crit_x := int(pulse["crit_x"])
	if crit_x != 1:
		_flash_scoring_die(slot)
		for charm_index: int in crit_charm_indices:
			_flash_charm_and_pad(charm_index)
		# Material-Krit (dotierter Rubin/Glas) hat kein Dock-Pad - er kommt vom Würfel.
		var from_die: bool = crit_charm_indices.is_empty() and bool(pulse.get("crit_from_die", false))
		var crit_px := die_px if from_die else _charm_trail_source_px(crit_charm_indices)
		var crit_base: int = pulse["charm_base_after"]
		var crit_mult: int = pulse["mult_after_crit"]
		table_screen.spawn_gain_number(crit_px, "×%d" % crit_x, TableScreen.CRIT_COLOR, 1.2)
		var crit_travel := _fire_score_light(crit_px, "pit" if from_die else "charm", ["mult"],
			func() -> void: table_screen.crit_pit_mult(crit_base, crit_mult, crit_x),
			TableScreen.CRIT_COLOR)
		if not await _score_arrival_gap(crit_travel):
			return false
		if not await _score_step_wait(CRIT_HOLD):
			return false
	return true

## Spielt einen STATISCHEN Krit-Schritt (Galgenhumor, Feierabendbier): der Komet
## läuft in Krit-Magenta vom Dock-Pad zum Mult-Orb, bei Ankunft übernimmt
## TableScreen.crit_pit_mult (Hit-Stop -> Slam mit Stoßwellen -> Beben). Der
## Extra-Halt (CRIT_HOLD) lässt den Moment atmen. Beherit ist würfelgebunden
## und schlägt in _play_die_step ein. false = Abbruch (Reset).
func _play_crit_step(step: Dictionary) -> bool:
	for charm_index: int in step["charm_indices"]:
		_flash_charm_and_pad(charm_index)
	var source_px := _charm_trail_source_px(step["charm_indices"])
	var cbase: int = step["base_after"]
	var cmult: int = step["mult_after"]
	var crit_x: int = step["crit_x"]
	table_screen.spawn_gain_number(source_px, "×%d" % crit_x, TableScreen.CRIT_COLOR, 1.2)
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
		var pmult: int = pulse["mult_after"]
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
## "×N"; Basis cyan, Mult gold. Rein schmückend, zusätzlich zu den Leiterbahnen.
func _spawn_score_gains(source_px: Vector2, base_add: int, mult_add: int, base_x: int = 1, mult_x: int = 1) -> void:
	if base_add != 0:
		table_screen.spawn_gain_number(source_px, "+%d" % base_add, table_screen.TRAIL_BASE_COLOR)
	if base_x != 1:
		table_screen.spawn_gain_number(source_px, "×%d" % base_x, table_screen.TRAIL_BASE_COLOR)
	if mult_add != 0:
		table_screen.spawn_gain_number(source_px, "+%d" % mult_add, table_screen.TRAIL_MULT_COLOR)
	if mult_x != 1:
		table_screen.spawn_gain_number(source_px, "×%d" % mult_x, table_screen.TRAIL_MULT_COLOR)

## Zuwachs eines Nach-Schritts auf der GESAMTZAHL; ganzzahlige Faktoren als
## "×N", sonst mit einer Nachkommastelle.
func _spawn_total_gain(source_px: Vector2, total_add: int, total_x: float) -> void:
	if total_add != 0:
		table_screen.spawn_gain_number(source_px, "+%d" % total_add, PitScoreView.TOTAL_COLOR)
	if not is_equal_approx(total_x, 1.0):
		var text := "×%d" % int(total_x) if is_equal_approx(total_x, float(int(total_x))) else "×%.1f" % total_x
		table_screen.spawn_gain_number(source_px, text, PitScoreView.TOTAL_COLOR)

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

## Lässt den Wurf-Würfel in slot golden aufblitzen (Zähl-Animation).
func _flash_scoring_die(slot: int) -> void:
	if slot < 0 or slot >= dice.count() or not dice.roots[slot].visible:
		return
	var tint: Color = DiceController.KIND_TINTS.get(dice.slot_defs[slot].style_id, Color.WHITE)
	_flash_die_tint(dice.face_displays[slot], tint, Vector3.ONE * DiceTrayView.DIE_SCALE)

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
## Kombination - ein Vorschlag, den der Spieler frei umklicken kann.
func _auto_select_best_combo() -> void:
	var ids := run.charm_ids()
	# Beste Hand MIT vollem Kontext (Materialien, Kanten, Menü-Stufen, Charms):
	# die Vorauswahl schlägt die real punktträchtigste Kombination vor, nicht die
	# bloß ranghöchste.
	var hand := DiceScoring.best_hand(dice.values, ids, hands_taken_this_round == 0,
		_rolled_materials(), _edge_materials(), run.combo_levels, _score_ctx())
	for position in DiceScoring.participating_indices(hand["key"], dice.values, ids, _score_ctx()):
		dice.set_selected(position, true)

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
	return _scoring_slots()

## Beteiligte Slots der besten Hand über ALLE liegenden Würfel (Vollzähler-Glow:
## diese leuchten hell, der Rest der Grube nur schwach).
func _pit_combination_slots() -> Array[int]:
	var slots := _visible_pit_slots()
	if slots.is_empty():
		return []
	var ids := run.charm_ids()
	var materials := _rolled_materials()
	var edges := _edge_materials()
	var sel_values: Array[int] = []
	var sel_materials: Array[String] = []
	var sel_edges: Array[String] = []
	for s in slots:
		sel_values.append(dice.values[s])
		sel_materials.append(materials[s])
		sel_edges.append(edges[s])
	var hand := DiceScoring.best_hand(sel_values, ids, hands_taken_this_round == 0, sel_materials, sel_edges, run.combo_levels, _score_ctx_for_slots(slots))
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
	# Auch die Pro-Würfel-Pulse tragen Auswahl-Indizes - auf echte Slots umrechnen.
	for step: Dictionary in breakdown["charm_steps"]:
		if step.has("pulses"):
			for pulse: Dictionary in step["pulses"]:
				pulse["slot"] = slots[int(pulse["slot"])]

func _on_reset_button_pressed() -> void:
	_reset_game()

## Testmodus umschalten: An = zufällige Materialien auf allen Würfeln +
## unbegrenzte Gravuren (KEINE Charms); Aus = Materialien entfernen. Beides
## startet die Runde neu, damit die Änderung sofort sichtbar ist.
func _on_test_materials_pressed() -> void:
	test_materials_enabled = not test_materials_enabled
	if not test_materials_enabled:
		run.clear_all_materials()
	_refresh_test_materials_button()
	_start_new_round()

## Beschriftung des Testmodus-Knopfs (2D-Rückfall UND Hub-Menü).
func _refresh_test_materials_button() -> void:
	var label := "🧪 Testmaterialien: %s" % ("AN" if test_materials_enabled else "aus")
	if test_materials_button != null:
		test_materials_button.text = label
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_test_materials_label(label)

## Leiterbahn-Testmodus umschalten: An = 1-5 zufällige Leiterbahnen auf allen
## Würfeln; Aus = alle entfernen. Wie die Materialien startet es die Runde neu.
func _on_test_pointers_pressed() -> void:
	test_pointers_enabled = not test_pointers_enabled
	if not test_pointers_enabled:
		run.clear_all_pointers()
	_refresh_test_pointers_button()
	_start_new_round()

func _refresh_test_pointers_button() -> void:
	var label := "🧪 Testleiterbahnen: %s" % ("AN" if test_pointers_enabled else "aus")
	if test_pointers_button != null:
		test_pointers_button.text = label
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_test_pointers_label(label)

## Gravur-Testmodus umschalten: An = jeder Archetyp unerschöpflich am Bord.
## Rührt die Würfel NICHT an, darum auch kein Rundenneustart - das Bord baut
## an der Bestandsänderung selbst neu, mitten in der Zeremonie.
func _on_test_engravings_pressed() -> void:
	test_engravings_enabled = not test_engravings_enabled
	run.unlimited_engravings = test_engravings_enabled or test_materials_enabled
	_refresh_test_engravings_button()

func _refresh_test_engravings_button() -> void:
	var label := "🧪 Testgravuren: %s" % ("AN" if test_engravings_enabled else "aus")
	if test_engravings_button != null:
		test_engravings_button.text = label
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_test_engravings_label(label)

func _reset_game() -> void:
	phase = Phase.IDLE  # bricht auch laufende Wurf-/Zähl-Koroutinen ab
	_cancel_deck_shift()
	_cancel_reorder_drag()
	_cancel_charm_drag()
	_cancel_lineup()
	_cleanup_take_animation()
	dice_shell.reset_to_post()
	hand_note = ""
	last_throw_was_reroll = false
	momentum_streak = 0
	rerolls_this_hand = 0
	pendulum_acc = 0  # Pendel überlebt Runden, aber nicht einen neuen Run
	_pendulum_shown = 0
	full_reroll_stacks = 0
	run = GameRun.new_run()
	_connect_run()
	_abort_engraving()  # falls der Reset mitten in der Zeremonie kam
	betting_open = false  # frische Auslage eröffnet die erste Runde
	charm_shop.visible = false  # Fenster-UI-Rückfall ohne Hub
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.reset_pages()
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
	_start_new_round()

## Verdrahtet einen frisch erzeugten Run: Shop/Gravur-Station bekommen ihn
## gereicht, seine Signale halten die Anzeigen aktuell. Der alte Run wird
## mitsamt Verbindungen freigegeben (RefCounted).
func _connect_run() -> void:
	charm_shop.run = run
	if table_screen != null and table_screen.secret_shop_window != null:
		table_screen.secret_shop_window.run = run
		if not table_screen.secret_shop_window.unlock_requested.is_connected(_on_secret_shop_unlock_requested):
			table_screen.secret_shop_window.unlock_requested.connect(_on_secret_shop_unlock_requested)
	die_inspector.run = run
	if table_screen != null and table_screen.side_bet_window != null:
		table_screen.side_bet_window.run = run
	if table_screen != null and table_screen.slot_bank_window != null:
		table_screen.slot_bank_window.run = run
		table_screen.slot_bank_window.refresh()
	if table_screen != null and table_screen.workshop_window != null:
		table_screen.workshop_window.run = run
		if not table_screen.workshop_window.engraving_dispatched.is_connected(_on_engraving_dispatched):
			table_screen.workshop_window.engraving_dispatched.connect(_on_engraving_dispatched)
		if not table_screen.workshop_window.die_placed.is_connected(_on_pack_die_placed):
			table_screen.workshop_window.die_placed.connect(_on_pack_die_placed)
		if not table_screen.workshop_window.pack_activated.is_connected(_on_pack_opened):
			table_screen.workshop_window.pack_activated.connect(_on_pack_opened)
	if charm_shop != null and not charm_shop.pack_purchased.is_connected(_on_pack_purchased):
		charm_shop.pack_purchased.connect(_on_pack_purchased)
	if table_screen != null:
		for drawer in table_screen.supply_drawers:
			drawer.run = run
	charm_library.run = run
	run.money_changed.connect(_on_money_changed)
	run.charms_changed.connect(_on_charms_changed)
	run.combo_upgraded.connect(_on_combo_upgraded)
	run.hub_level_changed.connect(_on_hub_level_changed)
	# Unterschrift/Abrechnung: Marken, Fahrplan und Wett-Preise sofort nachziehen.
	run.deals_changed.connect(_on_deals_changed)
	run.charge_changed.connect(_on_charge_changed)
	_shown_money = run.money  # kein Geld-Licht beim Spielstart
	_on_money_changed(run.money)
	_on_charms_changed()
	_refresh_combo_label_texts()
	_sync_hub_level_state()  # Hub-Plakette, Shop-Gate, Nebenwetten-Installation
	_sync_secret_shop_state()  # Börse + Eintrag (frischer Lauf: leer und verborgen)

## Idempotenter Gesamtzustand: Bank = Bestand/Deckel. Das Schwarzmarkt-Fenster
## steht IMMER auf dem Tisch und ist immer anklickbar - vergittert, bis das
## Eintrittsgeld bezahlt ist. Ein frischer Lauf schließt es damit sofort wieder
## zu, OHNE Zeremonie; die spielt nur den Übergang.
func _sync_secret_shop_state() -> void:
	if run == null:
		return
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_charge_display(run.charge, run.charge_cap())
	if table_screen != null:
		table_screen.set_secret_shop_installed(true)
		if table_screen.secret_shop_window != null:
			table_screen.secret_shop_window.set_locked(not run.secret_shop_unlocked,
				run.charge >= GameRun.SECRET_UNLOCK_PRICE)
	_sync_capacitor()
	if secret_shop_click_zone != null:
		secret_shop_click_zone.collision_layer = 8

func _sync_capacitor() -> void:
	if capacitor_bank == null or run == null:
		return
	capacitor_bank.set_charge(run.charge, run.charge_cap())

func _on_charge_changed(value: int) -> void:
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_charge_display(value, run.charge_cap())
	_sync_capacitor()
	# Der Freischalt-Knopf des vergitterten Ladens folgt dem Ladungsstand.
	if table_screen != null and table_screen.secret_shop_window != null and run != null:
		table_screen.secret_shop_window.set_locked(not run.secret_shop_unlocked,
			value >= GameRun.SECRET_UNLOCK_PRICE)

## Eintrittsgeld bezahlt: der Hub quittiert golden, das Gitter fällt und das
## Fenster meldet sich mit einer Stoßwelle - dieselbe Sprache wie ein neu
## installierter Automat.
func _on_secret_shop_unlock_requested() -> void:
	if run == null or not run.unlock_secret_shop():
		return
	_sync_secret_shop_state()
	if table_screen == null:
		return
	if table_screen.hub != null:
		table_screen.hub.flash_frame(CasinoStyle.GOLD_INTENSE)
	table_screen.celebrate_secret_shop_install(VIOLET_REVEAL_COLOR)

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
	route_choice.open(run.route_offers, GameRun.is_stress_round(run.round_number))

## Vertrag unterschrieben: Karten weg, JETZT erst greifen die Rundenbeginn-
## Wirkungen (die Boss-Kondition muss vor der Drossel stehen) - danach darf
## geworfen werden.
func _on_route_chosen(index: int) -> void:
	if not route_pending:
		return  # doppelte Unterschrift = doppelter Vorschuss
	run.take_route(index)
	route_pending = false
	if route_choice != null:
		route_choice.close()
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
	_abort_engraving()  # eine im Laden offene Station leckt nicht in die Runde
	hands_taken_this_round = 0
	chimney_sweep_used_this_round = false
	anchor_clause_used_this_round = false
	phoenix_used_this_round = false
	taken_dice_this_round = 0
	recycling_used_this_round = false
	first_hand_after_farkle = false
	round_best_combo_rank = -1
	round_best_hand_score = 0
	round_farkled = false
	discarded_this_round = []
	slot_draw_positions = []
	queue_activated = false  # Nachschub-Tray erst beim ersten Grubenzoom

	# Liegt eine Auslage bereit, warten die Rundenbeginn-Wirkungen auf die
	# Unterschrift: sonst stünde die Drossel fest, bevor die Boss-Kondition
	# gewählt ist, und der Wartungsvertrag käme eine Runde zu spät.
	route_pending = not run.route_offers.is_empty()
	if not route_pending:
		_apply_round_start_effects()

	# Testmodus: unbedingt gesetzt, damit der Zugriff beim Ausschalten und auf
	# frischen Runs mit umschaltet.
	run.unlimited_engravings = test_materials_enabled or test_engravings_enabled
	if test_materials_enabled:
		run.randomize_all_materials()
	if test_pointers_enabled:
		run.randomize_all_pointers()

	var ids := run.charm_ids()
	round_pool_kinds = run.owned_pool.duplicate()
	round_pool_kinds.shuffle()
	# Zieh-Reihenfolge: jede Partition zieht ihre Gruppe stabil nach vorn -
	# die ZULETZT angewandte gewinnt (Frische Ware > Magnetring).
	if CharmEffects.draws_edges_first(ids):
		round_pool_kinds = _edges_first(round_pool_kinds)
	if CharmEffects.draws_materials_first(ids):
		round_pool_kinds = _materials_first(round_pool_kinds)

	next_draw_index = 0
	discard_tray_view.clear()
	hand_total = 0
	hand_note = ""
	_refresh_round_hud()
	_animate_points_to(0, false)
	# Nebenwetten laufen ab dem Shop; die erste Runde (kein vorheriger Shop)
	# eröffnet die Auslage hier. Eine schon offene bleibt samt Einsätzen stehen.
	if not betting_open:
		_open_side_bet_betting()
	_start_new_hand()

## Sortiert Würfel mit Kanten-Material stabil an den Anfang (Magnetring).
func _edges_first(pool: Array[DieDefinition]) -> Array[DieDefinition]:
	var edged: Array[DieDefinition] = []
	var rest: Array[DieDefinition] = []
	for def in pool:
		if def.edge_material != "":
			edged.append(def)
		else:
			rest.append(def)
	return edged + rest

## Sortiert Würfel mit Material (Seite ODER Kante) stabil an den Anfang
## (Frische Ware). Gravuren in materials zählen nicht - nur echte Materialien.
func _materials_first(pool: Array[DieDefinition]) -> Array[DieDefinition]:
	var material: Array[DieDefinition] = []
	var rest: Array[DieDefinition] = []
	for def in pool:
		if _has_material(def):
			material.append(def)
		else:
			rest.append(def)
	return material + rest

func _has_material(def: DieDefinition) -> bool:
	if DieMaterial.is_valid_id(def.edge_material):
		return true
	for material_id in def.materials:
		if DieMaterial.is_valid_id(material_id):
			return true
	return false

func _start_new_hand() -> void:
	has_rolled_current_hand = false
	active_kinds = []
	rerolls_this_hand = 0
	_update_charm_badges()
	# full_reroll_stacks bleibt stehen - Alles-oder-nichts stapelt bis zum
	# nächsten NEHMEN, nicht je Hand.
	dice.reset()
	_refresh_deck_trays()
	_refresh_ui()

## Bank-Knopf: Runde bei ≥1 gefüllter Überladungs-Stufe vorzeitig kassieren.
func _on_bank_button_pressed() -> void:
	if phase != Phase.IDLE or run.stages_cleared(hand_total) < 1:
		return
	_on_round_complete()

## Runde endet automatisch nur bei voller Überladung oder erschöpftem Pool;
## nach der ersten gefüllten Stufe kann der Spieler per Bank-Knopf früher beenden.
func _round_should_end() -> bool:
	return run.stages_cleared(hand_total) >= run.max_overcharge_stages() \
		or hands_taken_this_round >= run.max_hands_this_round() \
		or _remaining_in_pool() < HAND_SIZE

## Rundenende: MONEY_PER_ROUND_CLEAR EINMAL für den geschafften Benchmark, je
## ungezogenem Würfel MONEY_PER_UNUSED_DIE - und je gefüllter Überladungs-Stufe
## eine Ladung (⚡). Was nicht mehr in die Börse passt, fällt zum alten Satz als
## Geld an. Die Auszahlung läuft als Tisch-Animation, bevor der Shop aufgeht; die
## Phase springt schon auf PAYOUT, damit derweil nichts anklickbar bleibt.
func _on_round_complete() -> void:
	var stages := run.stages_cleared(hand_total)
	if stages >= 1:
		phase = Phase.PAYOUT
		var ids := run.charm_ids()
		# Deal-Faktor auf die ganze Auszahlung; der Wartungsvertrag streicht die
		# Würfel-Zeile ganz, die Sparprämie legt auf sie drauf (wie das Sparschwein).
		var factor := run.round_payout_factor()
		var base_blind := roundi(MONEY_PER_ROUND_CLEAR * factor)
		var per_die := 0
		if run.unused_dice_pay():
			per_die = roundi((MONEY_PER_UNUSED_DIE + CharmEffects.unused_die_bonus(ids)
				+ run.deal_unused_die_bonus()) * factor)
		# Schmuckkästchen: übrige Würfel haben je 10% Chance auf eine Material-Seite.
		run.apply_jewelry_box(round_pool_kinds.slice(next_draw_index, round_pool_kinds.size()))
		# Aufteilung VOR jeder Buchung: die Zeremonie plant daraus ihre Kometen und
		# bucht sie einzeln bei Ankunft.
		var split := run.charge_split(stages)
		# Zinsen rechnen auf dem Stand VOR jeder Buchung und reisen mit dem
		# Benchmark-Kometen - ein eigener Komet für ein paar Dollar wäre Zeremonie
		# um ihrer selbst willen.
		var interest := run.interest_income()
		await _play_round_clear_payout(base_blind, interest, per_die, stages, split)
		if phase != Phase.PAYOUT:
			return  # Spiel wurde während der Auszahlung zurückgesetzt
		# Rundenende-Charms: strikt links nach rechts, je Charm eine sichtbare
		# Wirkung (Geld-Komet zur Truhe, Gravur-Meteore in die Schublade).
		await _play_round_end_charm_ceremony(ids)
		if phase != Phase.PAYOUT:
			return  # Spiel wurde während der Charm-Zeremonie zurückgesetzt
		# Glücksgroschen wächst ERST nach seiner Auszahlung (erste Runde: $3).
		if ids.has(Charm.OLD_PENNY):
			run.old_penny_payouts += 1
		# Nebenwetten gegen die geräumte Rundenbilanz auswerten (Gewinne landen
		# als Gravuren im Inventar, sichtbar im Shop/an der Gravur-Station).
		_resolve_side_bets(true)
		# Kein Deal überlebt seine Runde: die Marken wischen an JEDEM Rundenende -
		# NACH den Wetten, deren Quoten noch dazugehörten. Erst der sichtbare Wisch,
		# dann die Buchung, sonst wären die Marken fort, bevor der Spieler das Ende
		# bemerkt. Die Abrechnung des Stresstests räumt danach nur noch die Sperren.
		await _sweep_deal_tokens()
		if phase != Phase.PAYOUT:
			return  # Spiel wurde während des Wischs zurückgesetzt
		if GameRun.is_stress_round(run.round_number):
			run.settle_block_deals()
		phase = Phase.SHOP
		# Ab in den Shop: der Rundenpuls verklingt (lief noch durch die Auszahlung).
		# Die Drossel ist mit der Runde vorbei - der Chip soll im Shop kaufbar wirken.
		_set_throttled_combos([] as Array[String])
		if table_screen != null:
			table_screen.set_round_pulse(false)
		_set_gameplay_ui_visible(false)
		_return_dice_to_pool_tray()
		# Läuft noch die Zeremonie, sauber beenden - sonst schwebte der echte
		# Zeremonien-Würfel weiter über der Hub-Fläche und verdeckte die Seiten.
		if engraving_active:
			die_inspector.close()
		# Kamera auf den Hub, dann den Shop öffnen.
		camera_rig.zoom_to(CameraRig.Mode.HUB)
		# Nebenwetten werden ZUGLEICH mit dem Shop verfügbar.
		_open_side_bet_betting()
		charm_shop.open()
	else:
		phase = Phase.GAME_OVER
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
	var result := {
		"cleared": cleared,
		"best_combo_rank": round_best_combo_rank,
		"best_hand_score": round_best_hand_score,
		"dice_taken": taken_dice_this_round,
		"farkled": round_farkled,
	}
	var placed := run.active_side_bets.size()
	# Auszahlung bucht Geld (add_money) - das generische Licht unterdrücken, damit
	# stattdessen die Nebenwetten-Kometen laufen.
	_suppress_money_light = true
	var won := run.resolve_side_bets(result)
	_suppress_money_light = false
	_refresh_side_bet_panel()  # Wetten geleert -> Fenster zeigt "keine aktiv"
	_play_side_bet_payouts(won)
	if won.is_empty():
		charm_shop.pending_bet_notice = "Nebenwetten: 0/%d gewonnen." % placed
		return
	var names: Array[String] = []
	for bet in won:
		names.append(bet.display_name)
	var doubled := " (Turniernacht ×2)" if run.side_bet_payout_factor() > 1 else ""
	charm_shop.pending_bet_notice = "Nebenwette gewonnen (%d/%d): %s – Gewinn gutgeschrieben%s." \
		% [won.size(), placed, ", ".join(names), doubled]

## Öffnet die Wettannahme im Tisch-Fenster mit frischer Auslage.
func _open_side_bet_betting() -> void:
	if run == null or not run.side_bets_unlocked():
		return  # Nebenwetten erst ab Hub-Stufe 3 installiert
	betting_open = true
	if table_screen != null and table_screen.side_bet_window != null:
		table_screen.side_bet_window.open_betting(SideBet.roll_offers(SideBetPanel.OFFER_COUNT))

## Schließt die Wettannahme (erster Wurf) - ab jetzt zeigt das Fenster Fortschritt.
func _close_side_bet_betting() -> void:
	if not betting_open:
		return
	betting_open = false
	if table_screen != null and table_screen.side_bet_window != null:
		table_screen.side_bet_window.close_betting()
	_refresh_side_bet_panel()

## Aktualisiert den Live-Fortschritt der aktiven Wetten (Fortschritts-Modus).
func _refresh_side_bet_panel() -> void:
	if table_screen == null or table_screen.side_bet_window == null or run == null:
		return
	table_screen.side_bet_window.update_progress({
		"best_combo_rank": round_best_combo_rank,
		"best_hand_score": round_best_hand_score,
		"dice_taken": taken_dice_this_round,
		"farkled": round_farkled,
	})

## Lässt die Rundenbonus-Zeilen im Hub nacheinander golden aufleuchten,
## synchron zur tatsächlichen Gutschrift; die übrigen Tray-Würfel blitzen im
## selben Takt mit (überzählige zahlen ohne eigenes Aufblitzen). Drei Posten
## nacheinander: Benchmark (einmal Geld), Überladung (je Stufe ⚡ bzw. Überlauf-
## Geld nach split), übrige Würfel.
func _play_round_clear_payout(base_blind: int, interest: int, per_die: int, stages: int,
		split: Dictionary) -> void:
	# Die Zählsequenz läuft in der Übersicht: Hub, Geldanzeige und beide Trays
	# sind gleichzeitig im Bild.
	camera_rig.zoom_out()
	await get_tree().create_timer(CameraRig.ZOOM_DURATION).timeout

	var hub := table_screen.hub
	var blind_label: Label = hub.blind_payout_label if hub != null else null
	# 1) Der geschaffte Benchmark zahlt EINMAL - ein goldener Komet, eine Buchung.
	if blind_label != null:
		blind_label.text = "%d$ pro Benchmark" % base_blind
		if interest > 0:
			blind_label.text += "  ·  Zinsen +%d$" % interest
		blind_label.modulate = PAYOUT_LABEL_BASE_COLOR
	var travel := table_screen.bank_comet(table_screen.stage_fill_color(1))
	await get_tree().create_timer(maxf(travel, 0.05)).timeout
	if phase != Phase.PAYOUT:
		return
	if hub != null:
		hub.flash_frame(CasinoStyle.GOLD_INTENSE)
	run.add_money(base_blind + interest)
	_pop_payout_label(blind_label)
	await get_tree().create_timer(PAYOUT_TEXT_HOLD_DURATION).timeout

	# 2) Bank-Entladung: je Überladungs-Stufe ein Komet aus dem Zielbalken um die
	# Grube in den Hub - cyan, solange die Börse Platz hat, danach golden.
	var stored := int(split["stored"])
	var overflow := int(split["overflow"])
	if blind_label != null:
		blind_label.text = "Überladung ⚡+%d" % stored
		if overflow > 0:
			blind_label.text += "  ·  %d×%d$ – Speicher voll" % [overflow, base_blind]
	await _play_bank_discharge(base_blind, stored, overflow, stages, hub)
	await get_tree().create_timer(PAYOUT_TEXT_HOLD_DURATION).timeout
	_fade_payout_label(blind_label)

	var remaining := _remaining_in_pool()
	if remaining > 0:
		await _light_up_payout_label(hub.die_payout_label if hub != null else null)
		var die_entries := _unused_die_entries()
		for i in remaining:
			if i < die_entries.size():
				_flash_die_tint(die_entries[i]["display"], die_entries[i]["tint"])
			run.add_money(per_die)
			await get_tree().create_timer(DIE_PAYOUT_STEP_INTERVAL).timeout
		_fade_payout_label(hub.die_payout_label if hub != null else null)

## Rundenende-Zeremonie der Charms: NACH der Rundenauszahlung, VOR dem Shop
## feuern die Rundenende-Charms strikt in Besitz-Reihenfolge (links nach
## rechts), und jeder ZEIGT seine Wirkung: Geld-Charms schicken einen Gold-
## Kometen vom Dock-Pad zur Schatztruhe (Buchung bei Ankunft), die Frankier-
## maschine schleudert je Gravur einen Meteor in ihre Vorrats-Schublade.
## Die Beträge von Zinsgroschen/Überflieger/Glücksgroschen rechnen alle auf
## dem Stand VOR der Zeremonie (kein Zinseszins); nur der Notgroschen füllt
## an seiner Position auf den LAUFENDEN Stand auf - was rechts von ihm zahlt,
## landet obendrauf.
func _play_round_end_charm_ceremony(ids: Array[String]) -> void:
	var amounts := {}
	for entry in CharmEffects.round_end_income_entries(run.money, hand_total - run.effective_goal(), ids, run.old_penny_payouts):
		amounts[int(entry["charm_index"])] = int(entry["amount"])
	for j in ids.size():
		match ids[j]:
			Charm.INTEREST_PENNY, Charm.HIGH_FLYER, Charm.OLD_PENNY:
				if amounts.has(j):
					await _play_charm_money_payout(j, amounts[j])
			Charm.EMERGENCY_FUND:
				var missing := CharmEffects.money_floor(ids) - run.money
				if missing > 0:
					await _play_charm_money_payout(j, missing)
			Charm.STAMP_MACHINE:
				await _play_stamp_machine_meteors(j)
		if phase != Phase.PAYOUT:
			return

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
	var travel := 0.0
	for i in values.size():
		var value: int = values[i]
		if i == 0:
			travel = _fire_charm_money_packet(from_px, value, guard)
		else:
			get_tree().create_timer(float(i) * MONEY_PULSE_GAP).timeout.connect(func() -> void:
				if phase == guard:
					_fire_charm_money_packet(from_px, value, guard))
	var last_arrival := float(maxi(0, values.size() - 1)) * MONEY_PULSE_GAP + maxf(travel, 0.05)
	await get_tree().create_timer(last_arrival).timeout
	if phase != guard:
		return
	await get_tree().create_timer(CHARM_PAYOUT_STEP_INTERVAL).timeout

## Schickt EIN Chip-Paket los und bucht seinen Wert bei ANKUNFT (Truhe glimmt,
## Einzahlungs-Schlitz blitzt in der Chipfarbe). Liefert die Flugzeit.
func _fire_charm_money_packet(from_px: Vector2, value: int, guard: Phase = Phase.PAYOUT) -> float:
	var chip_color := ChipStackView.denomination_color(value)
	var travel: float = table_screen.charm_money_comet(from_px, _money_trail_color(chip_color))
	get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
		if phase != guard:
			return
		_suppress_money_light = true
		run.add_money(value)
		_suppress_money_light = false
		if table_screen.treasure_window != null:
			table_screen.treasure_window.glint()
			table_screen.treasure_window.flash_receive_slot(chip_color))
	return travel

## Die Frankiermaschine schickt ihre Zahl-Gravuren als dichte Meteor-Salve auf
## die Adern: die Starts folgen im STAMP_METEOR_GAP-Takt, ohne auf die vorige
## Ankunft zu warten - jede Gravur liegt erst bei IHRER Ankunft im Vorrat
## (der Meteor ist die Gravur, nicht ihre Ankündigung).
func _play_stamp_machine_meteors(index: int) -> void:
	_flash_charm_and_pad(index)
	var from_px := _charm_trail_source_px([index])
	var travel := 0.0
	for i in GameRun.STAMP_ENGRAVINGS:
		var engraving := run.roll_stamp_engraving()
		if i == 0:
			travel = _fire_charm_engraving(engraving, from_px)
		else:
			get_tree().create_timer(float(i) * STAMP_METEOR_GAP).timeout.connect(func() -> void:
				if phase == Phase.PAYOUT:
					_fire_charm_engraving(engraving, from_px))
	var last_arrival := float(GameRun.STAMP_ENGRAVINGS - 1) * STAMP_METEOR_GAP + maxf(travel, 0.05)
	await get_tree().create_timer(last_arrival).timeout
	if phase != Phase.PAYOUT:
		return
	await get_tree().create_timer(CHARM_PAYOUT_STEP_INTERVAL).timeout

## Schickt EINEN Gravur-Meteor über die Adern in den Schubladen-Platz und
## grantet bei ANKUNFT; der Einschlag lässt den Platz in der Seltenheitsfarbe
## nachglühen. Liefert die Flugzeit.
func _fire_charm_engraving(engraving: Engraving, from_px: Vector2) -> float:
	if table_screen == null or table_screen.workshop_window == null:
		run.grant_engraving(engraving)  # ohne Display: still buchen, nichts verlieren
		return 0.0
	for drawer in table_screen.supply_drawers:
		var target := drawer.slot_center_px(engraving.id)
		if target.x < 0.0:
			continue
		var tint: Color = EngravingRenderer.SEAM_COLORS[int(engraving.rarity)]
		var travel := table_screen.charm_engraving_comet(from_px, drawer.category, target, tint)
		get_tree().create_timer(maxf(travel, 0.05)).timeout.connect(func() -> void:
			if phase != Phase.PAYOUT:
				return
			run.grant_engraving(engraving)
			if is_instance_valid(drawer):
				drawer.pop(engraving.id, tint))
		return travel
	run.grant_engraving(engraving)  # kein Schubladen-Platz: still buchen
	return 0.0

## Bank-Entladung: schießt je geräumter Stufe (oberste zuerst) einen Bank-Komet
## aus dem Zielbalken um die Grube in den Hub. Jede Ankunft entlädt den Balken eine
## Stufe und bucht IHRE Stufe einzeln - die ersten stored Stufen als Ladung (cyaner
## Komet, Börse pulst), die restlichen overflow als Geld (goldener Komet), weil die
## Börse voll ist. So kommen N Stufen in N Stößen an, statt schlagartig.
func _play_bank_discharge(base_blind: int, stored: int, overflow: int, cleared_stages: int,
		hub: HubView) -> void:
	var comets := stored + overflow
	# Der Doppellader schickt zwei Kometen je Stufe - die Goldader zahlt aber je
	# STUFE, also nur bei jedem n-ten Einschlag.
	var per_stage := maxi(1, run.charge_per_stage())
	var vein := run.gold_vein_income() if cleared_stages > 0 else 0
	var gap := BANK_STAGE_GAP_START
	var minted := 0
	for k in range(comets, 0, -1):
		var is_charge := minted < stored
		# Balken auf die verbleibenden Stufen schrumpfen (in der nächst-tieferen Farbe).
		var remaining_frac := float(k - 1) / float(comets)
		table_screen.drain_goal_bar(remaining_frac, table_screen.stage_fill_color(maxi(k - 1, 1)),
			BANK_BAR_DRAIN_TIME)
		var color := CHARGE_COMET_COLOR if is_charge else table_screen.stage_fill_color(k)
		var travel: float = table_screen.bank_comet(color)
		await get_tree().create_timer(travel).timeout
		if phase != Phase.PAYOUT:
			return  # Spiel während der Auszahlung zurückgesetzt
		if hub != null:
			hub.flash_frame(color)
		if is_charge:
			# Zweite Etappe: vom Hub über die Schatz-Leiste zur Kondensator-Bank.
			# Bewusst NICHT abgewartet - die nächste Stufe startet sofort, wie bei
			# der Frankiermaschinen-Salve; gebucht wird bei der ANKUNFT.
			_fly_charge_to_capacitor()
		else:
			run.add_money(base_blind)
		minted += 1
		if vein > 0 and minted % per_stage == 0:
			run.add_money(vein)  # Goldader: je geräumter Stufe, nicht je Ladung
		_pop_payout_label(hub.blind_payout_label if hub != null else null)
		await get_tree().create_timer(gap).timeout
		gap = maxf(BANK_STAGE_GAP_MIN, gap * BANK_STAGE_GAP_DECAY)

## EINE Ladung vom Hub zur Kondensator-Bank schicken: über die Hub-Cluster-Ader,
## an deren Eintritt die Bank steht. Gebucht wird bei der Ankunft (dort pulsen
## Bank und Börsen-Anzeige), damit die Zahl mit dem Licht steigt.
func _fly_charge_to_capacitor() -> void:
	var travel := 0.0
	if table_screen != null and capacitor_bank != null:
		travel = table_screen.charge_comet(
			table_screen.world_to_pixel(capacitor_bank.global_position), CHARGE_COMET_COLOR)
	if travel <= 0.0:
		run.add_charge(1)  # ohne Display still buchen, nichts verlieren
		return
	get_tree().create_timer(travel).timeout.connect(func() -> void:
		if phase != Phase.PAYOUT:
			return
		run.add_charge(1)
		if capacitor_bank != null:
			capacitor_bank.pulse()
		if table_screen != null and table_screen.hub != null:
			table_screen.hub.pulse_charge())

## Kurzer Größen-Pop + Aufleuchten einer Auszahlungs-Zeile (Bank-Komet trifft ein).
func _pop_payout_label(label: Label) -> void:
	if label == null:
		return
	label.pivot_offset = label.size / 2.0
	label.modulate = PAYOUT_LABEL_GLOW_COLOR
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.28, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Alle Anzeigen noch nicht gezogener Würfel (Warteschlange zuerst, dann
## Pool) in Zieh-Reihenfolge.
func _unused_die_entries() -> Array:
	var entries: Array = []
	for tray in [queue_tray_view, pool_tray_view]:
		for i in tray.slot_roots.size():
			if not tray.slot_roots[i].visible:
				continue
			var def: DieDefinition = tray.slot_defs[i]
			entries.append({
				"display": tray.slot_face_displays[i],
				"tint": DiceController.KIND_TINTS.get(def.style_id, Color.WHITE),
			})
	return entries

## Blendet eine Rundenbonus-Zeile auf Gold auf und wartet darauf.
## null-tolerant: ohne Hub nur die Flash-Zeit warten (gleicher Takt).
func _light_up_payout_label(label: Label) -> void:
	if label == null:
		await get_tree().create_timer(PAYOUT_FLASH_DURATION).timeout
		return
	label.pivot_offset = label.size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(c: Color) -> void: label.modulate = c, label.modulate, PAYOUT_LABEL_GLOW_COLOR, PAYOUT_FLASH_DURATION)
	tween.tween_property(label, "scale", Vector2.ONE * 1.3, PAYOUT_FLASH_DURATION)
	await tween.finished

## Blendet eine Rundenbonus-Zeile zurück in die Ruhefarbe (blockiert nicht).
func _fade_payout_label(label: Label) -> void:
	if label == null:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(c: Color) -> void: label.modulate = c, label.modulate, PAYOUT_LABEL_BASE_COLOR, PAYOUT_FLASH_DURATION)
	tween.tween_property(label, "scale", Vector2.ONE, PAYOUT_FLASH_DURATION)

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

## Sichtbarkeit der Spiel-UI nach Spielzustand (false während Shop/GameOver).
func _set_gameplay_ui_visible(is_visible: bool) -> void:
	gameplay_ui_state_visible = is_visible
	_update_gameplay_ui_visibility()

func _on_camera_mode_changed(new_mode: CameraRig.Mode) -> void:
	is_pit_focused = new_mode == CameraRig.Mode.PIT
	_sync_screen_reflection()
	# Die Gravur-Station lebt an der Werkbank: verlässt die Kamera sie, ist die
	# Zeremonie vorbei. Kein Rekursions-Risiko - _end_engraving_ceremony löscht
	# engraving_active, bevor es selbst zurückfährt.
	if engraving_active and new_mode != CameraRig.Mode.WORKSHOP:
		die_inspector.close()
	# Beim ERSTEN Grubenzoom einer Runde materialisiert das Nachschub-Tray.
	if is_pit_focused and not queue_activated and _is_playing():
		_activate_queue()
	# ...und dort wartet auch die Vertragswahl: der Spieler nimmt die Runde auf,
	# das Haus legt seine Konditionen auf den Tisch.
	if is_pit_focused and route_pending and phase == Phase.IDLE \
			and (route_choice == null or not route_choice.visible):
		_open_route_choice()
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

## Die überfahrene Vorrats-Kachel schreibt ihre Beschreibung in die Info-Leiste -
## auch an der Station: dort überschreibt das Überfahren kurz den Werkzeug-Prompt
## und gibt die Leiste beim Verlassen wieder frei (zurück zum Stations-Prompt).
func _on_supply_hovered(info_text: String) -> void:
	if table_screen == null or table_screen.supply_info_label == null:
		return
	if engraving_active:
		if info_text != "":
			table_screen.supply_info_label.text = info_text
		else:
			die_inspector.refresh_prompt()
		return
	table_screen.supply_info_label.text = info_text

# --- Reaktionen auf Shop/Gravur-Station -------------------------------------
# Käufe und Gravur-Verbrauch mutieren den GameRun direkt; die Anzeigen folgen
# über die Run-Signale. Hier nur Reaktionen, die echte Szenen-Arbeit brauchen.

## Ätzung angewandt: die faces sind schon verändert, nur Trays neu zeichnen.
func _on_die_engraved() -> void:
	pool_tray_view.refresh_faces()
	queue_tray_view.refresh_faces()
	discard_tray_view.refresh_faces()

## Paket-Würfel eingesetzt: GameRun hat den Pool-Würfel an Ort und Stelle
## überschrieben (place_pack_die) - die Trays halten dieselbe Instanz.
func _on_pack_die_placed(_pool_index: int) -> void:
	_on_die_engraved()

## Paket geöffnet: der Werkstatt die FORM des Pool-Trays reichen (Reihenfolge und
## Spaltenzahl). Der Pool liegt gemischt im Tray - ohne das zeigte die Kachel oben
## links einen anderen Würfel als der Platz oben links auf dem Tisch.
func _on_pack_opened(_index: int) -> void:
	_meteor_index = 0  # je Paket ein frischer Fächer von Ausbruch-Richtungen
	if table_screen == null or table_screen.workshop_window == null:
		return
	var slot_defs: Array[DieDefinition] = []
	for i in pool_tray_view.slot_roots.size():
		slot_defs.append(pool_tray_view.slot_defs[i] if pool_tray_view.slot_roots[i].visible else null)
	table_screen.workshop_window.set_pool_order(slot_defs, pool_tray_view.columns)

## Shop mit "Fertig" geschlossen: zurück in die Übersicht (dort ist das
## Wettannahme-Fenster im Blick und platzierbar), dann die nächste Runde.
func _on_shop_closed() -> void:
	run.advance_round()  # würfelt zugleich die Auslage der neuen Runde
	phase = Phase.IDLE
	_set_gameplay_ui_visible(true)
	camera_rig.zoom_out()
	_start_new_round()

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
	_refresh_round_hud()

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
			var all_edges := _edge_materials()
			var sel_values: Array[int] = []
			var sel_materials: Array[String] = []
			var sel_edges: Array[String] = []
			for s in slots:
				sel_values.append(dice.values[s])
				sel_materials.append(all_materials[s])
				sel_edges.append(all_edges[s])
			var hand := DiceScoring.best_hand(sel_values, run.charm_ids(), hands_taken_this_round == 0, sel_materials, sel_edges, run.combo_levels, _score_ctx_for_slots(slots))
			_refresh_combos(hand["key"])
			if phase != Phase.SCORING:
				table_screen.update_pit_score(
					DiceScoring.points_for(hand["key"], run.combo_levels),
					DiceScoring.mult_for(hand["key"], run.combo_levels))

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
	var p := run.stage_progress(points)
	table_screen.set_goal_progress(p["into_stage"], p["stage_size"], p["stage"], p["cleared"])
