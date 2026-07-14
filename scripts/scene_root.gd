extends Node3D
## Spielablauf-Koordinator: Rundenziele, Shop, Würfel-Pool und UI-Verdrahtung.
## Wertung: DiceScoring · Würfelphysik: DiceController · Pool-/Warteschlangen-/
## Ablage-Anzeige: DiceTrayView (drei Instanzen) · Look: PageStyle.
##
## Würfel-Pool statt Hände-/Reroll-Zähler: die Sammlung besteht aus fest 30
## Würfeln (anfangs alle "normal"; ein Shop-Kauf ersetzt einen zufälligen
## bestehenden Eintrag durch den neuen Spezialwürfel, der Pool bleibt also
## immer 30 groß). Zu Rundenbeginn wird der Pool gemischt; die noch nicht
## gezogenen 30 Würfel verteilen sich sichtbar auf zwei Trays, die zusammen
## eine Einheit bilden (siehe _refresh_deck_trays): die kleine Warteschlange
## (immer die als Nächstes gezogenen, max. 6 Würfel - beim Wurf werden genau
## diese tatsächlich verbraucht) und dahinter das größere Pool-Tray mit dem
## Rest. Beim tatsächlichen Wurf verschwinden die gezogenen Würfel aus der
## Warteschlange, alles rückt nach (die Lücke entsteht hinten, nicht
## mittendrin) und die Würfel wandern - sobald sie nicht mehr im Spiel sind
## (Neu-Würfeln ersetzt sie, oder sie werden genommen/verworfen) - ins
## Ablage-Tray. Die Runde endet sofort, sobald der Rundenstand das Rundenziel
## erreicht (siehe _on_round_complete) - oder, falls das nie gelingt, sobald
## der Pool keine volle Hand mehr hergibt (dann Game Over statt Shop). Beim
## Rundenziel-Erreichen gibt es Geld: einmalig MONEY_PER_ROUND_CLEAR plus
## MONEY_PER_UNUSED_DIE je Würfel, der im Pool noch gar nicht gezogen wurde -
## frühes Erreichen mit vielen übrigen Würfeln lohnt sich also.
##
## Nehmen nimmt immer die komplette Hand (alle 6 Würfel, siehe
## DiceScoring.best_hand über dice.values): ihr Wert wird verbucht, alle 6
## wandern ins Ablage-Tray, danach beginnt die nächste Hand. Die Auswahl
## einzelner Würfel (siehe DiceController.selected/DiceTray-Klick, "Alle
## auswählen") entscheidet NICHT, was Nehmen nimmt, sondern nur, welche
## Würfel vor dem nächsten "Neu würfeln" geschützt sind - ausgewählte Würfel
## bleiben unangetastet liegen, alle anderen bekommen einen neu gezogenen
## Würfel und werden geworfen (siehe throw_slots). Nach jedem Wurf markiert
## das Spiel automatisch die aktuell beste offene Kombination zum Schutz vor
## (siehe _auto_select_best_combo) - der Spieler kann das frei umklicken.
##
## Farkle (wie im gleichnamigen Spiel): Bringt ein Neu-Würfeln nicht mehr
## Punkte als der Stand direkt davor (gleich viele oder weniger), "farklet" -
## die komplette Hand wird ohne Punkte verworfen (nichts war ja schon
## genommen, siehe _on_take_button_pressed). Der erste Wurf einer Hand kann
## nie farkeln.

@export var throw_force: float = 50.0
@export var spin_strength: float = 14.0
@export var rest_linear_threshold: float = 0.15
@export var rest_angular_threshold: float = 0.15
@export var rest_time_required: float = 0.2

const HAND_SIZE := 6

const MONEY_PER_ROUND_CLEAR := 10  # Belohnung fürs Rundenziel-Erreichen (einmalig, nicht pro Hand), siehe _on_round_complete
const MONEY_PER_UNUSED_DIE := 1  # Bonus je noch nicht gezogenem Würfel im Rundenpool beim Rundenziel-Erreichen, siehe _on_round_complete/_remaining_in_pool

## Auszahlungs-Animation der beiden Rundenbonus-Zeilen im Hub (siehe
## HubView.blind_payout_label/die_payout_label, _play_round_clear_payout) -
## PAYOUT_FLASH_DURATION ist die Zeit zum Auf-/Abblenden ins/aus dem Gold,
## PAYOUT_TEXT_HOLD_DURATION die Pause, in der die Blind-Zeile golden stehen
## bleibt, bevor die Würfel dran sind, und DIE_PAYOUT_STEP_INTERVAL der Takt,
## in dem die Würfel nacheinander mit aufleuchten.
const PAYOUT_FLASH_DURATION := 0.3
const PAYOUT_TEXT_HOLD_DURATION := 0.35
const DIE_PAYOUT_STEP_INTERVAL := 0.09

## Würfel-Blitz beim Auszahlen (siehe _flash_die_tint): schneller Anstieg auf
## ein überstrahltes Gold (heller als GOLD_INTENSE, wirkt wie ein Aufblitzen)
## plus kurzer Größen-Pop, danach deutlich langsameres Abklingen zurück zur
## Stilfarbe - die Blitze der Würfel überlappen sich dadurch wie eine Welle.
const DIE_FLASH_PEAK_COLOR := Color(1.9, 1.55, 0.6)
const DIE_FLASH_RAMP_UP := 0.07
const DIE_FLASH_RAMP_DOWN := 0.38
const DIE_FLASH_SCALE := 1.25

## Abschluss-Animation eines gekauften Bogens (siehe _play_sheet_finish_animation):
## Kacheln lösen sich, Geld-Coupons fliegen nach oben links (Geldzähler), Ätzungen
## nach rechts (Zähler je Ätzungstyp), Werbeflächen verblassen.
const CHIP_COUPON_VALUE := 1  # Chips je Geld-Coupon (Chip-Coupon, siehe Obsidian "02 Gravuren")
const SHEET_ANIM_MONEY_TARGET := Vector2(72, 148)  # Bildschirmziel der Geld-Coupons (nahe money_label)
const SHEET_ANIM_COUNTER_X := 980.0  # linke Kante der Ätzungs-Zähler rechts
const SHEET_ANIM_COUNTER_TOP := 250.0
const SHEET_ANIM_COUNTER_ROW := 48.0
const SHEET_ANIM_SEPARATE_TIME := 0.28
const SHEET_ANIM_FLY_TIME := 0.45
const SHEET_ANIM_STAGGER := 0.05
## Ruhefarbe der Tisch-Texte (Belohnungen UND Kombinationsliste): leicht
## ÜBERHELLES Weiß (> 1.0), damit sie mit dem Szenen-Glow (siehe
## scene_root.tscn: Environment) dezent weiß leuchten. Beim Aufleuchten
## (Auszahlung bzw. gerade gewürfelte Kombination) wechseln sie auf das noch
## deutlich hellere PAYOUT_LABEL_GLOW_COLOR - dann strahlen sie golden.
const PAYOUT_LABEL_BASE_COLOR := Color(1.35, 1.35, 1.3)
## Aufleucht-Gold der Tisch-Texte: stark überhelles Gold (Basis
## CasinoStyle.GOLD_INTENSE), damit der Glow beim Hervorheben sichtbar
## "aufgedreht" wird statt nur die Farbe zu wechseln.
const PAYOUT_LABEL_GLOW_COLOR := Color(2.1, 1.7, 0.15)

## Position, an die das Warteschlangen-Tray andockt, solange die Kamera auf
## die Grube fokussiert ist: knapp vor deren Südrand, mittig - am unteren
## Bildschirmrand der gezoomten Grubenansicht, da Welt-X = Bildschirm-oben
## und Welt-Z = Bildschirm-rechts gilt (siehe CameraRig.ZOOM_BASIS). Empirisch
## getroffen (siehe scenes/dice_tray.tscn für die Kollisions-Maße der Grube;
## das sichtbare Tischmodell ist größer als diese Kollisionsboxen). Danach
## zieht sich das Tray wieder an seinen Normalplatz neben dem Pool-Tray zurück
## (siehe _update_queue_tray_dock).
## Knapp unterhalb (Bildschirm-unten = -X) der Grubenwand: kurze Halbachse 7.6
## um PIT_CENTER.x 0 -> Wand bei -7.6, plus 1 Einheit Abstand. Y = 0 (die
## Tischbildschirm-Oberfläche, siehe SPOT_Y/Tray-Ausgangshöhe), damit die
## Würfel im angedockten Tray AUF dem Screen liegen statt darüber zu schweben.
const QUEUE_TRAY_PIT_POSITION := Vector3(-8.6, 0.0, 0.0)
const QUEUE_TRAY_MOVE_DURATION := 0.6

## POSITION der Screen-Elemente hängt an frei verschiebbaren Editor-Ankern - je
## einem Marker3D unter $ScreenAnchors: CombosBlock (Kombi-Cluster), ScoreBar
## (Rundenziel-Balken) sowie BaseCounter und MultCounter (die beiden Zähler,
## einzeln verschiebbar). _ready rechnet ihre Weltposition per
## TableScreen.world_to_pixel auf den Screen um. Um etwas zu verschieben, einfach
## den Marker im Editor greifen (kein Code nötig). Nur die GRÖSSE der Zähler-
## Fläche bleibt hier als Weltmaß (die Schriftgröße folgt daraus, siehe
## TableScreen.configure_pit_score).
const PIT_SCORE_WIDTH_WORLD := 14.0   # Breite der Zähler-Fläche (Zahl bleibt zentriert)
const PIT_SCORE_HEIGHT_WORLD := 3.5   # Höhe der Zähler (Schriftgröße folgt daraus)

## Der HUB (siehe HubView): reservierter Display-Abschnitt unter der Grube,
## zwischen Pool- und Ablage-Tray - etwa grubenbreit und doppelt so hoch wie die
## Grube. Position über den Anker ScreenAnchors/Hub, Größe hier als Weltmaß.
const HUB_WIDTH_WORLD := 28.5   # ~ Grubenbreite (2 × DicePit.PIT_HALF_Z)
const HUB_HEIGHT_WORLD := 30.0  # ~ doppelte Gruben-Bildschirmhöhe (2 × 2 × PIT_HALF_X)

## Gravur-Zeremonie (siehe _open_engraving): der im Tray geklickte Würfel wird
## zum GRAVUR-ZIEL - sein Tray-Platz leert sich und der ECHTE Würfel (ein
## Weltobjekt) fliegt aus dem Tray herüber und schwebt über der Hub-Bühne (siehe
## _grab_engraving_die / DieInspectorView.stage). Es ist kein gerendertes Abbild,
## sondern derselbe Würfel, der zum Hub gleitet. Jede angewandte Ätzung schickt
## eine goldene Leiterbahn von der Coupon-Kachel zum schwebenden Würfel; bei der
## Ankunft "absorbiert" er die Kraft (Gold-Blitz-Pop, siehe _on_engraving_applied).
## Die Kamera bleibt frei: ein Klick auf einen ANDEREN Tray-Würfel macht ihn zum
## neuen Ziel und springt zum Hub; die Würfel-Leiste im Panel wechselt auch bei
## Hub-Zoom (siehe _refresh_engraving_tray_strip). Fertig (Panel) schließt.
const ENGRAVE_TRAIL_TIME := 0.5       # Leiterbahn Coupon -> Würfel (dann Absorption)
const ENGRAVE_ABSORB_COLOR := Color(2.0, 1.6, 0.3, 0.9)  # überhelles Gold (wie der Mult-Trail)
const ENGRAVE_FLY_TIME := 0.55        # Flug des Würfels vom Tray über die Hub-Bühne
const ENGRAVE_HOVER := DiceTrayView.REST_Y  # Auflagehöhe: der Würfel BERÜHRT den Tisch (wie im Tray), er schwebt nicht

## Zähl-Animation beim Nehmen (siehe _play_take_animation): die Würfel gleiten
## in eine schwebende Reihe in der oberen Grubenhälfte (X positiv =
## Bildschirm-oben), jeder zählende Würfel bekommt ein Goldlicht auf dem
## Display, dann werden Basis/Mult Schritt für Schritt hochgezählt.
const SCORE_ROW_X := 2.0  # Reihen-X in der Grube (obere Hälfte)
const SCORE_ROW_SPACING := 2.9  # Z-Abstand der Würfel in der Zählreihe (weiter auseinander = besser sichtbar)
const SCORE_HOVER_HEIGHT := 0.0  # 0 = die Würfel liegen beim Zählen auf dem Tisch (kein Schweben)
const SCORE_LIFT_TIME := 0.5  # Gleitdauer in die schwebende Reihe
const SCORE_STEP_TIME := 0.45  # Takt der Zählschritte (Kombination/Würfel/Charms)
const SCORE_SUBSTEP_TIME := 0.25  # kürzere Pause zwischen Augen- und Material-Zuwachs
const SCORE_MERGE_TIME := 0.75  # Standzeit der verschmolzenen Gesamtzahl
const SCORE_FLY_TIME := 0.55  # Flugdauer der Gesamtzahl in den Zielbalken
const SCORE_GLOW_SIZE_FACTOR := 1.5  # Kantenlänge des Würfel-Glow-Rechtecks als Vielfaches der Würfelgröße (50% größer)
const SCORE_TRAIL_TIME := 0.3  # Flugdauer eines Licht-Trails Quelle -> Zahl (die Zahl wächst beim Einschlag)

## Energiefeld-Blitz bei Wandkontakt (siehe _on_die_wall_contact / DicePit): unter
## FIELD_FLASH_MIN_SPEED bleibt das Feld ruhig (fast unsichtbar), ab
## FIELD_FLASH_FULL_SPEED blitzt es voll auf; auch der leiseste zählende Treffer
## zeigt mindestens FIELD_FLASH_MIN_STRENGTH.
const FIELD_FLASH_MIN_SPEED := 2.0
const FIELD_FLASH_FULL_SPEED := 14.0
const FIELD_FLASH_MIN_STRENGTH := 0.35

const DECK_SHIFT_DURATION := 0.45  # Aufrück-Animation der Deck-Würfel nach einem Wurf, siehe _animate_deck_shift

const REORDER_DRAG_THRESHOLD := 6.0  # Pixel, ab wann ein Klick auf einen Warteschlangen-Würfel als Zieh-Geste zählt
const REORDER_LIFT_HEIGHT := 0.8  # Wie weit der gezogene Würfel über das Tray angehoben wird
const REORDER_DROP_RADIUS := 140.0  # Pixel-Toleranz beim Loslassen, siehe _nearest_queue_slot

const CHARM_LIFT_HEIGHT := 1.2  # Wie weit der gezogene Charm über die Tischfläche angehoben wird
const CHARM_DROP_RADIUS := 90.0  # Pixel-Toleranz beim Loslassen über einem Charm-Platz, siehe _nearest_charm_spot

const CUP_FLY_DURATION := 0.4  # wie lange die gezogenen Würfel zum Becher fliegen, siehe _play_cup_roll
const CUP_SHAKE_COUNT := 3  # wie oft der Becher vor dem Ausschütten wackelt, siehe DiceCup.play_shake

## Wo geschützte (ausgewählte, noch nicht genommene) Würfel beim nächsten Wurf
## hingleiten (siehe _pit_top_row_position/_play_cup_roll): eine mittig
## zentrierte Reihe am oberen Rand der Grube (Welt-X positiv = Bildschirm-oben,
## siehe QUEUE_TRAY_PIT_POSITION), innerhalb der elliptischen Grubenwand
## (um DicePit.PIT_CENTER, kurze Halbachse 7.6 in X, lange 8.4 in Z - siehe
## scripts/table/dice_tray.gd). Reihe nah an der Mitte und eng gestellt, damit
## eine volle 6er-Reihe nicht in der Wand steckt (bei x=4 erlaubt die Ellipse
## |z| bis ~7.1, die Reihe endet bei 6.25 inkl. Würfelbreite).
const PIT_TOP_ROW_X := 4.0
const PIT_TOP_ROW_SPACING := 2.1

## Nach dem Ausrollen gleiten ALLE Würfel in eine mittig zentrierte Reihe in
## der Grubenmitte (siehe _line_up_settled_dice) - gleiche Abstände wie die
## Reihe der geschützten Würfel am oberen Rand, nur auf Höhe der Grubenmitte.
const PIT_CENTER_ROW_X := 0.0
const LINEUP_DURATION := 0.35  # Gleitdauer der Aufreihung nach dem Ausrollen

## Grobe Spielphase - genau EINE zur Zeit (ersetzt die frühere Kombination aus
## game_state + is_rolling + is_cup_animating, deren Konjunktionen an jeder
## Eingabe-Stelle einzeln stimmen mussten). Eingabe-Gates prüfen gegen die Phase
## (siehe _can_toggle_selection/_dice_in_motion/_is_playing): IDLE = wartet auf
## Spieler-Eingabe · CUP_ANIMATING = gezogene Würfel fliegen zum Becher, er
## schüttelt und kippt · ROLLING = Physikwurf läuft · SCORING = Zähl-Animation
## einer genommenen Hand (siehe _play_take_animation) · PAYOUT = Rundenziel-
## Auszahlung (Tisch-Animation vor dem Shop) · SHOP/GAME_OVER = entsprechendes
## Panel offen. Nebenläufige Kosmetik (Deck-Aufrücken, Umsortier-Drag,
## Bogen-Abschluss) ist bewusst KEINE Phase - sie hat ihre eigenen kleinen
## Zustände (deck_shift_ghosts/reorder_drag_index/sheet_animating) und darf
## parallel zu einer Phase laufen.
enum Phase { IDLE, CUP_ANIMATING, ROLLING, SCORING, PAYOUT, SHOP, GAME_OVER }

@onready var take_button: Button = $UI/TakeButton
@onready var select_all_button: Button = $UI/SelectAllButton
@onready var settings_menu: VBoxContainer = $UI/SettingsMenu
@onready var settings_toggle_button: Button = $UI/SettingsToggleButton
@onready var reset_button: Button = $UI/SettingsMenu/ResetButton
@onready var debug_win_round_button: Button = $UI/SettingsMenu/DebugWinRoundButton
@onready var library_button: Button = $UI/SettingsMenu/LibraryButton

## Testmodus-Knopf (im Einstellungs-Menü, per Code angehängt - siehe _ready):
## schaltet zufällige Seiten- + Kanten-Materialien auf ALLEN Würfeln an/aus
## (siehe _on_test_materials_pressed / GameRun.randomize_all_materials).
var test_materials_button: Button
var test_materials_enabled: bool = false

## Charms, die der Testmodus von Anfang an mitgibt (siehe _test_mode_charms /
## _on_test_materials_pressed): Goldener Skarabäus, Goldschmied, Kleinvieh.
const TEST_MODE_CHARM_IDS := [Charm.GOLDEN_SCARAB, Charm.GOLDSMITH, Charm.SMALL_FRY]

## Die Charm-Bibliothek (alle Charms + Beschreibungen, siehe CharmLibraryView),
## per Bibliothek-Knopf im Einstellungs-Menü auf-/zugeklappt.
var charm_library: CharmLibraryView
@onready var round_hud: Control = $UI/RoundHud
@onready var round_badge_label: Label = $UI/RoundHud/RoundBadgeLabel
@onready var points_bar: ProgressBar = $UI/RoundHud/PointsBar
@onready var points_label: Label = $UI/RoundHud/PointsBar/PointsLabel
@onready var hand_label: Label = $UI/HandLabel
@onready var money_label: Label = $UI/MoneyLabel

## Der Shop ist ein eigenständiger Controller auf dem ShopPanel (siehe
## ShopController) - seit dem Hub-Umbau lebt er als Neon-Panel AUF dem
## Tisch-Display in der Hub-Fläche (siehe HubView.attach_shop; ohne Screen-Mesh
## ersatzweise als Fenster-UI). scene_root spricht ihn nur über charm_shop.open()
## an, reicht ihm den laufenden GameRun (run) herein und reagiert auf sein
## closed-Signal. Erzeugt in _ready (siehe SHOP_SCENE).
const SHOP_SCENE := preload("res://scenes/shop_panel.tscn")
var charm_shop: ShopController

@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/VBoxContainer/GameOverLabel
@onready var game_over_reset_button: Button = $UI/GameOverPanel/VBoxContainer/GameOverResetButton

## Die Gravur-Station - seit dem Hub-Umbau ein Neon-Panel auf dem Tisch-Display
## (siehe HubView.attach_panel), Teil der Gravur-Zeremonie (_open_engraving).
## Erzeugt in _ready.
var die_inspector: DieInspectorView

# Enthüllungs-Overlay für einen gekauften Coupon-Bogen (siehe _build_sheet_preview
## / GameRun.buy_coupon_sheet / CouponSheet).
var sheet_preview: Control
var sheet_preview_backdrop: ColorRect
var sheet_preview_view: CouponSheetView
var sheet_preview_title: Label
var sheet_animating: bool = false  # true während der Abschluss-Animation (Klicks ignorieren)
var sheet_anim_nodes: Array[Node] = []  # temporäre Animations-Nodes (Kacheln/Zähler), am Ende freigegeben

@onready var pool_tray_view: DiceTrayView = $PoolTrayView
@onready var discard_tray_view: DiceTrayView = $DiscardTrayView
@onready var queue_tray_view: DiceTrayView = $QueueTrayView
@onready var dice_cup: DiceCup = $DiceCup

## Editor-Anker der Screen-Elemente (Marker3D unter $ScreenAnchors): im
## Editor frei verschiebbar, _ready rechnet ihre Weltposition auf den Screen um
## (siehe TableScreen.place_combo_cluster/place_goal_bar/configure_pit_score/
## place_hub).
@onready var combos_anchor: Marker3D = $ScreenAnchors/CombosBlock
@onready var goal_bar_anchor: Marker3D = $ScreenAnchors/ScoreBar
@onready var base_counter_anchor: Marker3D = $ScreenAnchors/BaseCounter
@onready var mult_counter_anchor: Marker3D = $ScreenAnchors/MultCounter
@onready var hub_anchor: Marker3D = $ScreenAnchors/Hub

var combo_labels: Dictionary = {}  # DiceScoring-key -> ComboCellView (Sic-Bo-Zelle auf dem TableScreen)
var highlighted_combo_key: String = ""  # gerade golden hervorgehobene Kombination (siehe _refresh_combos)

@onready var camera_rig: CameraRig = $Camera3D
@onready var dice_pit: DicePit = $DiceTray  # Grube samt Energiefeld (siehe DicePit.flash_wall)
@onready var pit_click_zone: StaticBody3D = $DiceTray/PitClickZone
@onready var charm_row: CharmRowView = $Charms
## Der Geldstand als physische Neon-Pokerchips auf dem Tisch (zwischen Pool und
## Becher, siehe ChipStackView) - folgt automatisch jeder Geldänderung.
@onready var chip_stack: ChipStackView = $ChipStack

# Hover-Tooltip der Charm-Ansicht (siehe _build_charm_tooltip /
# _update_charm_tooltip): folgt dem Cursor, zeigt Name + Wirkung des Charms.
var charm_tooltip: PanelContainer
var charm_tooltip_title: Label
var charm_tooltip_body: Label

var dice: DiceController
var dice_audio: DiceAudio  # Aufprall-/Roll-Sounds der Spielwürfel (siehe _ready)
var table_screen: TableScreen  # Display auf der Tischfläche (siehe _ready)
var combos_click_zone: StaticBody3D  # Klickfläche über dem Kombi-Cluster (Zoom, siehe _setup_combos_zoom)
var charms_click_zone: StaticBody3D  # Klickfläche über der Charm-Reihe (Zoom, siehe _setup_charms_zoom)
var hub_click_zone: StaticBody3D  # Klickfläche über dem Hub (Zoom, siehe _setup_hub_zoom)
## Letzter Display-Pixel der Maus-Weiterleitung in den Hub (siehe
## _forward_screen_mouse) - Grundlage für das relative-Feld der Motion-Events.
var last_screen_pixel := Vector2(-1, -1)

## Zustand der Gravur-Zeremonie (siehe _open_engraving/_end_engraving_ceremony).
## Der ECHTE Würfel fliegt als eigenes Weltobjekt (engraving_die) aus dem Tray
## über die Hub-Bühne; sein Tray-Slot bleibt solange versteckt (kehrt beim
## Schließen/Wechsel zurück).
var engraving_active := false
var engraving_die: Node3D                 # der schwebende Würfel über dem Hub (freies Weltobjekt)
var engraving_fly_tween: Tween            # laufender Flug/Umwähl-Tween (wird bei Wechsel/Ende gekillt)
var engraving_source_root: Node3D         # versteckter Tray-Slot (das aktuelle Gravur-Ziel)
var engraving_source_tray: DiceTrayView   # Tray des Ziels (fürs Umwählen, siehe _refresh_engraving_tray_strip)
var engraving_prev_mode: CameraRig.Mode = CameraRig.Mode.OVERVIEW

var phase: Phase = Phase.IDLE  # siehe Phase - jeder Übergang setzt genau einen neuen Wert
var has_rolled_current_hand: bool = false
var hand_total: int = 0

var displayed_points: int = 0  # aktuell im Zielbalken/-text gezeigter Punktestand, läuft hand_total animiert hinterher (siehe _animate_points_to)
var points_tween: Tween

## Der persistente Zustand des laufenden Spiellaufs: Geld, Würfel-Sammlung,
## Charms, Coupons, Rundenfortschritt (siehe GameRun - reine Daten + Ökonomie,
## kein Node). Wird bei jedem Neustart frisch erzeugt (siehe _reset_game) und
## an Shop (charm_shop.run) und Gravur-Station (die_inspector.run) gereicht;
## seine Signale halten die HUD-Anzeigen aktuell (siehe _connect_run).
var run: GameRun

var hands_taken_this_round: int = 0  # wie viele Hände in dieser Runde schon genommen wurden - für Charms, die nur die erste Hand betreffen (Zauberkarte, siehe _is_first_scored_hand)
var chimney_sweep_used_this_round: bool = false  # ob der Schornsteinfeger-Charm seinen einmaligen Farkle-Erlass diese Runde schon verbraucht hat (siehe _on_farkle)

var round_pool_kinds: Array[DieDefinition] = []  # feste Zieh-Reihenfolge der laufenden Runde (GameRun.POOL_SIZE Einträge)
var next_draw_index: int = 0  # wie viele davon schon gezogen wurden
var active_kinds: Array[DieDefinition] = []  # aktuell den 6 Würfel-Slots zugewiesene Würfel

var last_throw_was_reroll: bool = false  # war der zuletzt gestartete Wurf ein Neu-Würfeln?
var pre_reroll_values: Array[int] = []  # Würfelwerte VOR dem Neu-Würfeln (für Farkle-Vergleich)
var pre_reroll_materials: Array[String] = []  # oben liegende Seiten-Materialien VOR dem Neu-Würfeln (siehe _rolled_materials)
var pre_reroll_edge_materials: Array[String] = []  # Kanten-Materialien VOR dem Neu-Würfeln (siehe _edge_materials; Neu-Würfeln kann Slots neu besetzen)
var last_thrown_indices: Array[int] = []  # Slots des zuletzt gestarteten Wurfs - für die Gold-Kanten-Auszahlung je Wurf (siehe _on_roll_finished)

# --- Zustand der Effektkatalog-Charms (siehe CharmEffects: ctx-Schlüssel) ---
var rerolled_dice_this_hand: int = 0  # Pendel (+2 Mult je neu geworfenem Würfel)
var rerolls_this_hand: int = 0  # Anker (der ERSTE Neuwurf kann nicht farkeln)
var taken_dice_this_round: int = 0  # Pendel (−1 Mult je genommenem Würfel)
var full_reroll_stacks: int = 0  # Alles-oder-nichts: volle Neuwürfe seit dem letzten Nehmen (stapelt)
var momentum_streak: int = 0  # Momentum (+1 Mult je Hand in Folge ohne Farkle)
var first_hand_after_farkle: bool = false  # Galgenhumor (+3 Krit nach Farkle)
var recycling_used_this_round: bool = false  # Recycling wirkt nur auf die erste Hand
var slot_draw_positions: Array[int] = []  # je Slot die Zieh-Position im Stapel (Bodensatz)
var discarded_this_round: Array[DieDefinition] = []  # Ablage der Runde (Phönixfeder)
var hand_note: String = ""  # transiente Meldung (z.B. Farkle) für die Pause zwischen Händen

var gameplay_ui_state_visible: bool = true  # true während PLAYING, false während Shop/GameOver
var is_pit_focused: bool = false  # true, solange die Kamera auf die Würfelgrube gezoomt ist

var queue_tray_home_position: Vector3  # Normalplatz neben dem Pool-Tray, siehe _ready
var queue_tray_tween: Tween

var lineup_tween: Tween  # Aufreihung der ausgerollten Würfel, siehe _line_up_settled_dice

## Goldlichter der laufenden Zähl-Animation (Display-Knoten, siehe
## TableScreen.spawn_glow) - am Ende bzw. bei einem Reset freigegeben
## (siehe _cleanup_take_animation).
var take_anim_glows: Array[Control] = []

var deck_shift_ghosts: Array[Node3D] = []  # temporäre Würfel der Aufrück-Animation, siehe _animate_deck_shift
var deck_shift_tween: Tween

## Fake-Würfel, die nach dem Hineinfliegen sichtbar im Becher "liegen" (in
## $DiceCup/MeshRoot eingehängt, siehe _play_cup_roll - dadurch wackeln sie
## beim Schütteln automatisch mit, ganz ohne echte Physik). Verschwinden
## wieder im Moment des Auskippens (DiceCup.poured_out), sobald die echten
## Wurf-Würfel übernehmen - siehe _on_throw_button_pressed.
var cup_interior_ghosts: Array[Node3D] = []

var queue_window_size: int = 0  # wie viele Slots im Warteschlangen-Tray gerade belegt sind, siehe _refresh_deck_trays

## Umsortieren im Warteschlangen-Tray per Ziehen - siehe _try_start_queue_reorder/_handle_reorder_input.
var reorder_drag_index: int = -1  # Slot-Index im QueueTrayView, der gerade gezogen wird, oder -1
var reorder_drag_start_pos: Vector2
var reorder_is_dragging: bool = false
var reorder_ghost: Node3D

## Umsortieren der Tisch-Charms per Ziehen (gleiche Klick-oder-Drag-Logik wie
## das Warteschlangen-Tray) - siehe _try_start_charm_reorder/_handle_charm_drag_input.
var charm_drag_index: int = -1  # Position in charm_row/run.owned_charms, die gerade gezogen wird, oder -1
var charm_drag_start_pos: Vector2
var charm_is_dragging: bool = false

## Startpositionen der 6 Spielwürfel, bevor sie zum ersten Mal geworfen
## werden (nur die Position zählt - throw_slots() berechnet die Wurfrichtung
## daraus, die Rotation ist irrelevant, da die Würfel bis zum ersten Wurf
## unsichtbar sind). Das ist der ursprünglich für die Grube austarierte
## Fächer aus 6 Positionen (siehe throw_slots: Wurfrichtung = Richtung zum
## Ursprung), nur um die Y-Achse gedreht, sodass er vom Würfelbecher (siehe
## DiceCup, rechter Rand der Grube) her kommt statt von der alten,
## becherlosen Seite - der Abstand jeder Position zum Ursprung (und damit
## Wurfweite/-charakter) bleibt exakt erhalten.
const DICE_START_POSITIONS: Array[Vector3] = [
	Vector3(6.5458, 17.095267, 7.7658),
	Vector3(3.2886, 17.095267, 6.7886),
	Vector3(0.0314, 17.095267, 5.8115),
	Vector3(-3.2258, 17.095267, 4.8343),
	Vector3(-6.4830, 17.095267, 3.8572),
	Vector3(-9.7402, 17.095267, 2.8800),
]

func _ready() -> void:
	var roots: Array[Node3D] = []
	var bodies: Array[RigidBody3D] = []
	var face_displays: Array[DieFaceDisplay] = []
	for i in DICE_START_POSITIONS.size():
		var die := DieBuilder.build()
		$Dice.add_child(die)
		die.position = DICE_START_POSITIONS[i]
		# Gleiche Würfelgröße wie in den Trays, ABER nur Kollision + Optik skalieren
		# und den RigidBody3D selbst auf Einheitsskala lassen: Ein skalierter Körper
		# trägt den Faktor in seiner Basis, und die Ruheerkennung (siehe
		# DiceController._top_axis_info) liest genau diese Basis per Skalarprodukt
		# gegen oben - mit skalierter Basis erreicht der Würfel den Ausrichtungs-
		# Schwellwert nie und käme nie zur Ruhe (Auswahl bliebe gesperrt).
		var body: RigidBody3D = die.get_node("RigidBody3D")
		var die_scale := Vector3.ONE * DiceTrayView.DIE_SCALE
		(body.get_node("CollisionShape3D") as CollisionShape3D).scale = die_scale
		var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
		faces.scale = die_scale
		faces.set_light_enabled(true)  # nur die 6 Spielwürfel beleuchten ihre Umgebung
		roots.append(die)
		bodies.append(body)
		face_displays.append(faces)
	dice = DiceController.new(roots, bodies, face_displays)

	dice_audio = DiceAudio.new()
	dice_audio.name = "DiceAudio"
	add_child(dice_audio)
	dice_audio.setup(bodies, dice)  # aktiviert auch contact_monitor der Würfel

	# Energiefeld-Blitz bei Wandkontakt: DiceAudio hat die Kontaktmeldung schon
	# eingeschaltet, hier hört ein zweiter Handler mit und blitzt das getroffene
	# Feldsegment auf (siehe _on_die_wall_contact / DicePit.flash_wall).
	for body in bodies:
		body.body_entered.connect(_on_die_wall_contact.bind(body))

	# Tisch-Display: ViewportTexture auf das "Screen"-Mesh des importierten
	# Tischs legen (siehe TableScreen). Fehlt das Mesh (anderes Tischmodell),
	# läuft das Spiel einfach ohne Anzeige weiter.
	table_screen = TableScreen.new()
	table_screen.name = "TableScreen"
	add_child(table_screen)
	var screen_mesh := $Room.find_child("Screen", true, false) as MeshInstance3D
	if screen_mesh != null:
		table_screen.attach_to(screen_mesh)
		# Alle drei Screen-Elemente hängen an frei verschiebbaren Editor-Ankern
		# (Marker3D unter $ScreenAnchors); Pixel-Positionen erst nach attach_to
		# ableitbar. Den Kombi-Cluster ERST an seinen Anker setzen, DANN den Zoom
		# einrichten (er liest das nun verschobene cluster_rect).
		table_screen.place_combo_cluster(table_screen.world_to_pixel(combos_anchor.global_position))
		_setup_combos_zoom()
		table_screen.place_goal_bar(table_screen.world_to_pixel(goal_bar_anchor.global_position))
		var ppw := table_screen.pixels_per_world()
		# Basis- und Mult-Zähler getrennt: jeder zentriert sich auf seinem Anker.
		var score_size := Vector2(PIT_SCORE_WIDTH_WORLD * ppw, PIT_SCORE_HEIGHT_WORLD * ppw)
		table_screen.configure_pit_score(
			table_screen.world_to_pixel(base_counter_anchor.global_position),
			table_screen.world_to_pixel(mult_counter_anchor.global_position),
			score_size)
		# Hub unter der Grube (siehe HubView): Fläche aufspannen, Kamera-Zoomziel
		# + Klickzone einrichten und die Lauf-Übersicht erstmalig füllen.
		table_screen.place_hub(
			table_screen.world_to_pixel(hub_anchor.global_position),
			Vector2(HUB_WIDTH_WORLD * ppw, HUB_HEIGHT_WORLD * ppw))
		_setup_hub_zoom()
		_refresh_hub_info()
	else:
		push_warning("Tisch-Screen-Mesh nicht gefunden - Display bleibt aus (siehe TableScreen)")

	queue_tray_home_position = queue_tray_view.position

	# Kamera-Zoomziele der Trays aus ihren echten Positionen ableiten, damit ein
	# Verschieben der Trays im Editor den Zoom automatisch mitnimmt (siehe
	# CameraRig.configure_tray_targets). Der Pool-Zoom zeigt Pool- UND
	# Warteschlangen-Tray zusammen -> ihr Mittelpunkt; der Ablage-Zoom das
	# Ablage-Tray. queue_tray_view steht hier noch auf seinem Normalplatz.
	camera_rig.configure_tray_targets(
		(pool_tray_view.global_position + queue_tray_view.global_position) * 0.5,
		discard_tray_view.global_position)
	# Grubenziel auf Tisch-Screen-Höhe (0) - damit die Grubenkamera genau so hoch
	# steht wie alle anderen Zooms (gleiche Höhe UND Winkel; die Y der Grubenmitte
	# ist fürs Werfen ohnehin bedeutungslos).
	camera_rig.configure_pit_target(Vector3(DicePit.PIT_CENTER.x, 0.0, DicePit.PIT_CENTER.z))
	_setup_charms_zoom()

	# Shop als Neon-Panel in die Hub-Fläche hängen (siehe HubView.attach_shop) -
	# bedient über die Maus-Weiterleitung (_forward_screen_mouse). Ohne
	# Screen-Mesh (kein Hub) ersatzweise als normales Fenster-UI.
	charm_shop = SHOP_SCENE.instantiate()
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.attach_panel(charm_shop)
	else:
		$UI.add_child(charm_shop)
	charm_shop.closed.connect(_on_shop_closed)

	# Gravur-Station ebenfalls als Hub-Panel (siehe _open_engraving); ohne
	# Screen-Mesh ersatzweise als Fenster-UI (dann ohne Zeremonie).
	die_inspector = DieInspectorView.new()
	die_inspector.visible = false
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.attach_panel(die_inspector)
	else:
		$UI.add_child(die_inspector)
	die_inspector.closed.connect(_end_engraving_ceremony)
	die_inspector.applied.connect(_on_engraving_applied)
	die_inspector.select_tray_die.connect(_on_tray_die_selected)
	die_inspector.changed.connect(_on_die_engraved)
	debug_win_round_button.pressed.connect(_on_debug_win_round_pressed)
	camera_rig.mode_changed.connect(_on_camera_mode_changed)
	settings_toggle_button.pressed.connect(_on_settings_toggle_pressed)

	charm_library = CharmLibraryView.new()
	$UI.add_child(charm_library)
	library_button.pressed.connect(charm_library.toggle)

	# Testmodus-Knopf ans Ende des Einstellungs-Menüs hängen (im Code, damit die
	# Szene unverändert bleibt) - siehe _on_test_materials_pressed.
	test_materials_button = Button.new()
	test_materials_button.custom_minimum_size = Vector2(0, 48)
	test_materials_button.pressed.connect(_on_test_materials_pressed)
	settings_menu.add_child(test_materials_button)
	CasinoStyle.style_button(test_materials_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK, 14)
	_refresh_test_materials_button()

	_style_ui()
	_collect_combo_labels()
	_build_sheet_preview()
	_build_charm_tooltip()
	_reset_game()

## Verpasst der gesamten 2D-Spiel-UI den bunten Casino-/Balatro-Look (siehe
## CasinoStyle) - jede Aktion bekommt ihre eigene Akzentfarbe: Nehmen = Gold,
## Auswählen = Blau, Kombinationen = Grün, Einstellungen = Lila, Neues Spiel =
## Rot (Gefahr), Debug = Blau. Der Punktetext leuchtet cremeweiß mit Umriss.
func _style_ui() -> void:
	CasinoStyle.style_score_label(hand_label, 30)
	CasinoStyle.style_chip_label(round_badge_label, 20)
	CasinoStyle.style_progress_bar(points_bar)
	CasinoStyle.style_score_label(points_label, 17)
	CasinoStyle.style_chip_label(money_label, 20, CasinoStyle.GOLD)

	CasinoStyle.style_button(take_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK)
	CasinoStyle.style_button(select_all_button, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK)
	CasinoStyle.style_button(settings_toggle_button, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, 16)
	CasinoStyle.style_button(library_button, CasinoStyle.GREEN, CasinoStyle.GREEN_DARK, 16)
	CasinoStyle.style_button(reset_button, CasinoStyle.RED, CasinoStyle.RED_DARK, 16)
	CasinoStyle.style_button(debug_win_round_button, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, 14)
	CasinoStyle.style_button(game_over_reset_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK)

	CasinoStyle.style_panel(game_over_panel)

	CasinoStyle.style_score_label(game_over_label, 24)
	# Der Shop stylt sich selbst (siehe ShopController._ready).

## Klappt die Einstellungsleiste unten rechts (Neues Spiel / Debug) auf/zu.
func _on_settings_toggle_pressed() -> void:
	settings_menu.visible = not settings_menu.visible

## Baut die Coupon-Bogen-Enthüllung auf: abgedunkelter Vollbild-Hintergrund +
## zentrierter Titel + CouponSheetView. Wird beim Kauf eines Bogens im Shop
## gezeigt (siehe run.sheet_purchased -> _show_sheet_reveal); Klick auf den
## Hintergrund schließt sie wieder.
func _build_sheet_preview() -> void:
	sheet_preview = Control.new()
	sheet_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet_preview.visible = false
	$UI.add_child(sheet_preview)

	sheet_preview_backdrop = ColorRect.new()
	sheet_preview_backdrop.color = Color(0, 0, 0, 0.6)
	sheet_preview_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet_preview_backdrop.gui_input.connect(_on_sheet_preview_input)
	sheet_preview.add_child(sheet_preview_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet_preview.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	sheet_preview_title = Label.new()
	sheet_preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet_preview_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(sheet_preview_title, 24, CasinoStyle.GOLD)
	column.add_child(sheet_preview_title)

	sheet_preview_view = CouponSheetView.new()
	sheet_preview_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# IGNORE, damit ein Klick auf den Bogen selbst (nicht nur daneben) bis zum
	# Backdrop durchfällt und die Abschluss-Animation startet (siehe _on_sheet_preview_input).
	sheet_preview_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(sheet_preview_view)

## Zeigt einen gekauften Bogen als Enthüllung über dem Shop (Klick schließt).
## Die Zellgröße schrumpft bei großen Bögen, damit auch ein Riesenbogen (9×9,
## mit Großformat-Charm 10×10) samt Titel auf den Schirm passt - kleine Bögen
## behalten ihre großen Zellen.
func _show_sheet_reveal(sheet: CouponSheet, kind: int) -> void:
	sheet_preview_title.text = "%s (%d×%d)" % [_sheet_kind_name(kind), sheet.cols, sheet.rows]
	var cell_px := minf(120.0, 640.0 / float(maxi(sheet.cols, sheet.rows)))
	sheet_preview_view.show_sheet(sheet, cell_px)
	sheet_preview.visible = true

func _sheet_kind_name(kind: int) -> String:
	match kind:
		CouponSheet.Kind.SNIPPET:
			return "Schnipsel"
		CouponSheet.Kind.SHEET:
			return "Bogen"
		CouponSheet.Kind.LARGE:
			return "Großbogen"
		CouponSheet.Kind.POSTER:
			return "Plakat"
		CouponSheet.Kind.JUMBO:
			return "Riesenbogen"
	return "Bogen"

## Klick auf die Bogen-Enthüllung "verabschiedet" den Bogen: die Abschluss-
## Animation zerlegt ihn (siehe _play_sheet_finish_animation). Während sie läuft,
## werden weitere Klicks ignoriert.
func _on_sheet_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not sheet_animating:
			_play_sheet_finish_animation()

## Abschluss-Animation des gekauften Bogens: alle Kacheln lösen sich vom Bogen,
## dann fliegen Geld-Coupons zum Geldzähler (oben links, +CHIP_COUPON_VALUE je
## Stück), Ätzungen zu je einem Zähler rechts (Anzahl je Ätzungstyp; hier landen
## sie auch endgültig im Inventar) und Werbeflächen verblassen einfach. Danach
## wird alles aufgeräumt und die Enthüllung geschlossen.
## Laufender Zähler einer Ätzungs-Sorte während der Abschluss-Animation (die
## Zeile rechts, zu der die Kacheln fliegen) - typisiert statt als Dictionary.
class EtchCounter:
	extends RefCounted

	var label: Label
	var count: int = 0
	var target: Vector2  # Flugziel der Kacheln (etwas rechts der Zeilenmitte)

func _play_sheet_finish_animation() -> void:
	sheet_animating = true
	var views: Array[CouponSheetView.TileView] = sheet_preview_view.tile_views.duplicate()

	# Streuzentrum = Mittel der Kachelmitten (Bildschirmkoordinaten).
	var center := Vector2.ZERO
	for view in views:
		center += view.node.global_position + view.node.size * 0.5
	if not views.is_empty():
		center /= float(views.size())

	# Rest des Bogens (Papier/Perforation/Titel) ausblenden, Hintergrund aufhellen,
	# damit der Geldzähler oben links sichtbar wird.
	var dim := create_tween()
	dim.set_parallel(true)
	dim.tween_property(sheet_preview_view, "modulate:a", 0.0, 0.22)
	dim.tween_property(sheet_preview_title, "modulate:a", 0.0, 0.22)
	dim.tween_property(sheet_preview_backdrop, "color:a", 0.18, 0.3)

	# Kacheln in die Overlay-Ebene umhängen (Bildschirmkoordinaten, Position bleibt).
	for view in views:
		view.node.reparent(sheet_preview, true)
		view.node.pivot_offset = view.node.size * 0.5
		sheet_anim_nodes.append(view.node)

	# Zähler je Ätzungstyp rechts anlegen (Reihenfolge des ersten Auftretens).
	var etch_counters := {}  # display_name -> EtchCounter
	for view in views:
		if view.tile.kind != CouponSheet.TileKind.ETCHING:
			continue
		var nm: String = view.tile.coupon.display_name
		if etch_counters.has(nm):
			continue
		var label := Label.new()
		label.position = Vector2(SHEET_ANIM_COUNTER_X, SHEET_ANIM_COUNTER_TOP + etch_counters.size() * SHEET_ANIM_COUNTER_ROW)
		label.text = "%s  ×0" % nm
		CasinoStyle.style_chip_label(label, 20, CasinoStyle.GREEN)
		label.modulate.a = 0.0
		sheet_preview.add_child(label)
		sheet_anim_nodes.append(label)
		var counter := EtchCounter.new()
		counter.label = label
		counter.target = label.position + Vector2(150, 14)
		etch_counters[nm] = counter
		var appear := create_tween()
		appear.tween_property(label, "modulate:a", 1.0, 0.3)

	# Jede Kachel: erst nach außen lösen, dann an ihr Ziel fliegen (gestaffelt).
	# Bei großen Bögen (Plakat/Riesenbogen: bis zu 81+ Kacheln) schrumpft der
	# Stagger, damit die Gesamtdauer gedeckelt bleibt.
	var stagger := minf(SHEET_ANIM_STAGGER, 2.5 / float(maxi(1, views.size())))
	var last_end := 0.0
	for idx in views.size():
		var view: CouponSheetView.TileView = views[idx]
		var node: Control = view.node
		var home := node.position + node.size * 0.5
		var out_dir := (home - center).normalized() if home.distance_to(center) > 1.0 else Vector2.UP
		var scattered := node.position + out_dir * 46.0
		var delay := idx * stagger

		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(node, "position", scattered, SHEET_ANIM_SEPARATE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		match view.tile.kind:
			CouponSheet.TileKind.MONEY:
				tw.tween_property(node, "position", SHEET_ANIM_MONEY_TARGET - node.size * 0.5, SHEET_ANIM_FLY_TIME) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(node, "scale", Vector2(0.18, 0.18), SHEET_ANIM_FLY_TIME)
				tw.parallel().tween_property(node, "modulate:a", 0.0, SHEET_ANIM_FLY_TIME)
				tw.tween_callback(_grant_chip_coupon)
			CouponSheet.TileKind.ETCHING:
				var counter: EtchCounter = etch_counters[view.tile.coupon.display_name]
				tw.tween_property(node, "position", counter.target - node.size * 0.5, SHEET_ANIM_FLY_TIME) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(node, "scale", Vector2(0.28, 0.28), SHEET_ANIM_FLY_TIME)
				tw.parallel().tween_property(node, "modulate:a", 0.0, SHEET_ANIM_FLY_TIME)
				tw.tween_callback(_grant_etching.bind(view.tile.coupon, counter))
			_:  # AD: Werbefläche verblasst einfach
				tw.tween_property(node, "scale", Vector2(0.7, 0.7), 0.3)
				tw.parallel().tween_property(node, "modulate:a", 0.0, 0.3)

		last_end = maxf(last_end, delay + SHEET_ANIM_SEPARATE_TIME + SHEET_ANIM_FLY_TIME)

	var finish := create_tween()
	finish.tween_interval(last_end + 0.25)
	finish.tween_callback(_cleanup_sheet_animation)

## Ein Geld-Coupon ist am Geldzähler angekommen: Chips gutschreiben + pulsen.
## Doppelte Perforation hebt den Chip-Wert (siehe CharmEffects.chip_coupon_value).
func _grant_chip_coupon() -> void:
	run.add_money(CharmEffects.chip_coupon_value(CHIP_COUPON_VALUE, run.charm_ids()))
	_pulse_money_label()

## Eine Ätzung ist an ihrem Zähler angekommen: ins Inventar legen, Zähler
## hochzählen und die Zeile kurz aufpulsen.
func _grant_etching(coupon: Coupon, counter: EtchCounter) -> void:
	run.grant_coupon(coupon)
	counter.count += 1
	counter.label.text = "%s  ×%d" % [coupon.display_name, counter.count]
	_pulse_control(counter.label)

## Räumt die Abschluss-Animation ab: temporäre Nodes freigeben, Overlay schließen
## und die Enthüllungs-Ansicht für den nächsten Kauf zurücksetzen.
func _cleanup_sheet_animation() -> void:
	for node in sheet_anim_nodes:
		if is_instance_valid(node):
			node.queue_free()
	sheet_anim_nodes.clear()
	sheet_preview.visible = false
	sheet_preview_view.modulate.a = 1.0
	sheet_preview_title.modulate.a = 1.0
	sheet_preview_backdrop.color.a = 0.6
	sheet_animating = false

## Kurzer elastischer Größen-Puls eines UI-Elements (wie _pulse_money_label).
func _pulse_control(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(1.4, 1.4)
	var pulse := create_tween()
	pulse.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(control, "scale", Vector2.ONE, 0.35)

## Verdrahtet die Kombinationsliste: Die Zellen liegen als gedrucktes Layout
## auf dem Tisch-Display (siehe TableScreen.combo_cells, Sic-Bo-Stil) - hier
## werden sie eingesammelt und in die leuchtende Ruhefarbe versetzt.
func _collect_combo_labels() -> void:
	combo_labels = table_screen.combo_cells
	for key: String in combo_labels:
		combo_labels[key].modulate = PAYOUT_LABEL_BASE_COLOR  # überhelle Ruhefarbe (leichter Glow)
	# Auch die Rundenbonus-Zeilen im Hub starten in der leuchtenden Ruhefarbe
	# (sie blitzen beim Rundenende golden auf, siehe _play_round_clear_payout).
	if table_screen.hub != null and table_screen.hub.blind_payout_label != null:
		table_screen.hub.blind_payout_label.modulate = PAYOUT_LABEL_BASE_COLOR
		table_screen.hub.die_payout_label.modulate = PAYOUT_LABEL_BASE_COLOR

## Ein Gericht wurde gegessen (siehe GameRun.eat_meal): die Tischliste zeigt
## den neuen Multiplikator der Kombination und blitzt die Zeile kurz golden auf.
func _on_combo_upgraded(combo_key: String, _new_level: int) -> void:
	_refresh_combo_label_texts()
	if combo_labels.has(combo_key) and combo_key != highlighted_combo_key:
		var row: ComboCellView = combo_labels[combo_key]
		var flash := create_tween()
		flash.tween_method(func(c: Color) -> void: row.modulate = c, PAYOUT_LABEL_GLOW_COLOR, PAYOUT_LABEL_BASE_COLOR, 1.2)

## Schreibt Basispunkte + Multiplikatoren der Tisch-Kombinationsliste neu,
## wobei beide die Menü-Stufen einrechnen (siehe DiceScoring.points_for/
## mult_for / GameRun.combo_levels).
func _refresh_combo_label_texts() -> void:
	for key in combo_labels:
		combo_labels[key].set_score(
			DiceScoring.points_for(key, run.combo_levels),
			DiceScoring.mult_for(key, run.combo_levels))

## Hebt genau die Kombination der gerade gewürfelten Hand golden hervor (analog
## zum Aufleuchten der Belohnungstexte), alle anderen bleiben im Ruhe-Weiß.
## active_key == "" (noch nicht gewürfelt) = keine Hervorhebung.
func _refresh_combos(active_key: String) -> void:
	if active_key == highlighted_combo_key:
		return
	var previous := highlighted_combo_key
	highlighted_combo_key = active_key
	if previous != "" and combo_labels.has(previous):
		_tween_combo_label(combo_labels[previous], PAYOUT_LABEL_BASE_COLOR, 1.0)
	if active_key != "" and combo_labels.has(active_key):
		_tween_combo_label(combo_labels[active_key], PAYOUT_LABEL_GLOW_COLOR, 1.18)

## Blendet eine Kombinationszelle weich in Farbe/Größe (Aufleuchten oder zurück
## in die Ruhefarbe) - gleiche Dauer wie die Belohnungstexte (PAYOUT_FLASH_DURATION).
## Die Größe wächst relativ zur Grundgröße der Zelle (base_scale, um die
## Zellenmitte dank pivot_offset), statt auf einen absoluten Wert zu springen.
func _tween_combo_label(row: ComboCellView, color: Color, target_scale: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(row, "modulate", color, PAYOUT_FLASH_DURATION)
	tween.tween_property(row, "scale", row.base_scale * target_scale, PAYOUT_FLASH_DURATION)

## Der Charm-Besitz hat sich geändert (siehe run.charms_changed): die physischen
## Tisch-Charms aktualisieren.
func _on_charms_changed() -> void:
	charm_row.set_charms(run.owned_charms)

## Der Geldstand hat sich geändert (siehe run.money_changed) - jede Gutschrift
## und jeder Kauf laufen über GameRun, die Anzeige folgt hier automatisch.
func _on_money_changed(new_money: int) -> void:
	money_label.text = "$%d" % new_money
	chip_stack.set_money(new_money)
	_refresh_hub_info()

## Spiegelt die Lauf-Übersicht in den Hub (siehe HubView.set_run_info) - nach
## jeder Geld-/Runden-/Ziel-Änderung. null-tolerant: vor dem ersten Spielstart
## (run fehlt noch) und ohne Screen-Mesh (hub fehlt) passiert einfach nichts.
func _refresh_hub_info() -> void:
	if run == null or table_screen == null or table_screen.hub == null:
		return
	table_screen.hub.set_run_info(run.round_number, run.money, run.round_goal)

## Kurzes elastisches Aufplustern des Geldtexts, analog zu _pulse_points_label.
func _pulse_money_label() -> void:
	money_label.pivot_offset = money_label.size / 2.0
	money_label.scale = Vector2(1.35, 1.35)
	var pulse := create_tween()
	pulse.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(money_label, "scale", Vector2.ONE, 0.4)

## Kleiner "+$N"-Text, der neben der Geldanzeige aufsteigt und ausblendet -
## z.B. für jeden Auszahlungsschritt in _play_round_clear_payout.
func _show_money_popup(amount: int) -> void:
	var popup := Label.new()
	popup.text = "+$%d" % amount
	CasinoStyle.style_chip_label(popup, 16, CasinoStyle.GOLD)
	money_label.add_child(popup)
	popup.position = Vector2(64, -2)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 26.0, 0.7)
	tween.tween_property(popup, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(popup.queue_free)

func _physics_process(delta: float) -> void:
	if phase != Phase.ROLLING:
		return
	if dice.physics_step(delta, rest_linear_threshold, rest_angular_threshold, rest_time_required):
		_on_roll_finished()

## Ein Würfel hat etwas berührt (body_entered, siehe _ready): war es eine
## Grubenwand, blitzt das getroffene Feldsegment aufprallabhängig auf - sonst
## bleibt das Feld ruhig (fast unsichtbar). Andere Kontakte (Boden, Würfel↔
## Würfel) ignorieren wir; der Sound läuft getrennt über DiceAudio.
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

	# Display-UI: In der Hub-Ansicht gehen Mausereignisse über der Hub-Fläche an
	# die Controls AUF dem Tisch-Display (Buttons/Hover, siehe
	# _forward_screen_mouse) - ein weitergereichter Klick löst keine 3D-Aktion
	# mehr aus. Rechtsklick bleibt Zoom-out (wird nicht weitergereicht).
	if event is InputEventMouse and _forward_screen_mouse(event):
		return

	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		# Während der Gravur-Zeremonie bricht ein Rechtsklick erst einen laufenden
		# Zweitschritt (zweite Seite/Zielwert) ab; sonst navigiert er wie sonst
		# (Herauszoomen). Geschlossen wird die Station über den Fertig-Knopf.
		if engraving_active and die_inspector.mode != DieInspectorView.Mode.SELECT:
			die_inspector._cancel_pending()
			return
		camera_rig.zoom_out()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Die Kamera bleibt während der Zeremonie FREI: Linksklicks laufen ganz
	# normal weiter (Zoom-Zonen navigieren, ein Klick auf einen Tray-Würfel
	# wechselt über _open_engraving das Ziel und springt zum Hub). Die Hub-UI
	# (Panel/Würfel-Leiste) ist oben schon weitergereicht.

	if is_pit_focused and _try_cup_click(event.position):
		return

	if is_pit_focused and _try_start_charm_reorder(event.position):
		return

	if _can_toggle_selection():
		var index := _pick_die_index(event.position)
		if index != -1:
			dice.set_selected(index, not dice.selected[index])
			# Umsortieren wie im Warteschlangen-Tray: die Reihe gleitet in ihre
			# neue Ordnung (Kombination links), bleibt aber Reihe (siehe
			# _line_up_settled_dice - _can_toggle_selection garantiert, dass die
			# Würfel gerade ausgerollt daliegen).
			_line_up_settled_dice()
			_refresh_action_buttons()
			# Kombination und Basis richten sich nach der Auswahl (siehe
			# _refresh_ui / _scoring_slots) - sofort mitziehen lassen.
			_refresh_ui()
			return

	# Warteschlangen-Umsortieren nur außerhalb der Zeremonie - läuft sie, soll ein
	# Klick auf einen Warteschlangen-Würfel ihn ins Edit-Panel holen (siehe
	# _try_tray_die_click), nicht eine Zieh-Geste starten.
	if not engraving_active and not _dice_in_motion() and deck_shift_ghosts.is_empty() and _try_start_queue_reorder(event.position):
		return

	if not _dice_in_motion() and _try_tray_die_click(event.position):
		return

	_try_zoom_click(event.position)

## Klick auf einen einzelnen (sichtbaren) Würfel eines Trays (Layer 16, siehe
## DiceTrayView.SLOT_PICK_LAYER) - öffnet die Gravur-Zeremonie für genau diesen
## Würfel (bzw. wechselt das Ziel, wenn sie schon läuft).
##
## Am Hub (Zeremonie läuft ODER Übersicht) holt ein Klick auf IRGENDEINEN
## sichtbaren Tray-Würfel (auch Ablage oder Warteschlange, egal wohin die Kamera
## zeigt) ihn direkt ins Edit-Panel - statt in das Tray zu zoomen: am Hub will der
## Nutzer den Würfel bearbeiten, nicht navigieren. Sonst zählt nur das GERADE
## FOKUSSIERTE Tray (Pool/Ablage) - ein Klick aus der Übersicht löst dort nur den
## Zoom aus (siehe _try_zoom_click), sonst wäre ein winziger Würfel schon von weit
## weg treffbar.
func _try_tray_die_click(screen_pos: Vector2) -> bool:
	var candidate_trays: Array[DiceTrayView] = []
	if engraving_active or camera_rig.mode == CameraRig.Mode.HUB:
		candidate_trays = [pool_tray_view, discard_tray_view, queue_tray_view]
	else:
		match camera_rig.mode:
			CameraRig.Mode.POOL:
				candidate_trays = [pool_tray_view]
			CameraRig.Mode.DISCARD:
				candidate_trays = [discard_tray_view]
			_:
				return false

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false

	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 16
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false

	for target_tray in candidate_trays:
		var index: int = target_tray.find_slot_index(result.collider)
		if index != -1:
			_open_engraving(target_tray.slot_defs[index], target_tray.slot_roots[index], target_tray)
			return true
	return false

# --- Gravur-Zeremonie ----------------------------------------------------------
# Der geklickte Würfel wird zum GRAVUR-ZIEL: sein Tray-Platz leert sich, das
# Hub-Panel zeigt ihn als 3D-Miniatur AUF dem Display (siehe DieInspectorView),
# die Kamera zoomt auf den Hub. Die Kamera bleibt frei: rechtsklick/Klick auf
# Zonen navigieren; ein Klick auf einen anderen Tray-Würfel macht ihn zum neuen
# Ziel (und springt zurück auf den Hub, siehe _grab_engraving_die). Fertig
# schließt. Jede Ätzung schickt eine goldene Leiterbahn von der Coupon-Kachel in
# die Miniatur (Absorption).

## Öffnet die Zeremonie ODER wechselt das Ziel (wenn schon offen). def ist die
## echte Pool-Instanz, source_root ihr Tray-Slot, source_tray ihr Tray. Ohne Hub
## (kein Screen-Mesh) öffnet nur das Panel als Fenster-UI.
func _open_engraving(def: DieDefinition, source_root: Node3D, source_tray: DiceTrayView) -> void:
	if table_screen == null or table_screen.hub == null:
		die_inspector.show_die(def)
		return
	if not engraving_active:
		engraving_active = true
		engraving_prev_mode = camera_rig.mode
		engraving_source_root = null
		table_screen.hub.set_content_visible(false)
	_grab_engraving_die(def, source_root, source_tray)

## Macht (def, source_root im Tray source_tray) zum aktuellen Gravur-Ziel: der
## bisherige Slot wird wieder sichtbar, der neue verschwindet, und AN SEINER
## STELLE hebt der echte Würfel ab und gleitet über die Hub-Bühne (derselbe
## Würfel, kein Abbild). Das Panel stellt um, die Kamera springt auf den Hub.
func _grab_engraving_die(def: DieDefinition, source_root: Node3D, source_tray: DiceTrayView) -> void:
	if source_root == engraving_source_root:
		camera_rig.zoom_to(CameraRig.Mode.HUB)  # schon das Ziel - nur wieder herzoomen
		return
	if engraving_source_root != null and is_instance_valid(engraving_source_root):
		engraving_source_root.visible = true  # alten Slot wieder zeigen (Würfel kehrt zurück)
	engraving_source_root = source_root
	engraving_source_tray = source_tray
	var start_pos: Vector3 = source_root.global_position  # exakte Abhebestelle im Tray
	source_root.visible = false
	die_inspector.show_die(def)
	_refresh_engraving_tray_strip()
	camera_rig.zoom_to(CameraRig.Mode.HUB)
	_fly_engraving_die(def, start_pos)

## Lässt den echten Würfel von seinem Tray-Slot (start_pos) über die Hub-Bühne
## gleiten - in Tray-Größe (er wächst NICHT). Der alte schwebende Würfel (bei
## einem Wechsel) wird zuvor freigegeben. Das Landeziel ergibt sich aus der
## Bühnen-Mitte des Panels, so projiziert, dass der schwebende Würfel dort mittig
## über der Hub-Fläche erscheint (siehe _hub_hover_target).
func _fly_engraving_die(def: DieDefinition, start_pos: Vector3) -> void:
	if engraving_fly_tween != null and engraving_fly_tween.is_valid():
		engraving_fly_tween.kill()
	if engraving_die != null and is_instance_valid(engraving_die):
		engraving_die.queue_free()
	engraving_die = _spawn_deck_ghost(def)  # schon in DiceTrayView.DIE_SCALE
	engraving_die.global_position = start_pos

	# Landeziel erst berechnen, wenn das frisch gebaute Panel einmal ausgelegt ist
	# (die Bühnen-Rect steht sonst noch auf null).
	await get_tree().process_frame
	if not engraving_active or engraving_die == null or not is_instance_valid(engraving_die):
		return
	var target: Vector3 = _hub_hover_target()
	engraving_fly_tween = create_tween()
	engraving_fly_tween.tween_property(engraving_die, "global_position", target, ENGRAVE_FLY_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Weltpunkt, an dem der Würfel landet: die Bühnen-Mitte (Display-Pixel) auf die
## Tisch-Oberfläche zurückprojiziert, dann auf Auflagehöhe (ENGRAVE_HOVER) gehoben,
## sodass er den Tisch berührt und - vom festen Hub-Blickwinkel aus - genau mittig
## über der Bühne erscheint (Parallaxe entlang des Kamerastrahls kompensiert).
func _hub_hover_target() -> Vector3:
	var stage_px: Vector2 = die_inspector.stage_center_px()
	var surface: Vector3 = table_screen.pixel_to_world(stage_px)  # auf Y = 0 (Screen-Oberfläche)
	var cam_pos: Vector3 = camera_rig.hub_target - CameraRig.ZOOM_FORWARD * CameraRig.ZOOM_DISTANCE
	var hover_y := surface.y + ENGRAVE_HOVER
	# Punkt auf dem Strahl Kamera -> Bühnenpunkt in Auflagehöhe (projiziert mittig).
	var denom := surface.y - cam_pos.y
	if is_zero_approx(denom):
		return Vector3(surface.x, hover_y, surface.z)
	var t := (hover_y - cam_pos.y) / denom
	return cam_pos + (surface - cam_pos) * t

## Eine Ätzung wurde angewandt (siehe DieInspectorView.applied): eine goldene
## Leiterbahn läuft von der Coupon-Kachel zum schwebenden Würfel über der Bühne;
## bei der Ankunft absorbiert er die Kraft (Seiten nachziehen + Gold-Blitz-Pop,
## siehe _refresh_engraving_die_faces / _flash_engraving_die).
func _on_engraving_applied(_coupon_id: String, slot_px: Vector2) -> void:
	if not engraving_active:
		return
	# Der schwebende Würfel ist so platziert, dass er genau auf die Bühnen-Mitte
	# projiziert - dort endet die Absorptions-Bahn.
	table_screen.spawn_trace(slot_px, die_inspector.stage_center_px(), ENGRAVE_ABSORB_COLOR, ENGRAVE_TRAIL_TIME)
	await get_tree().create_timer(ENGRAVE_TRAIL_TIME).timeout
	if not engraving_active:
		return
	_refresh_engraving_die_faces()  # geätzte Seiten am schwebenden Würfel nachziehen
	_flash_engraving_die()          # Gold-Blitz-Pop bei der Ankunft

## Zieht die Augenzahlen des schwebenden Würfels aus current_def nach (nach einer
## Ätzung, die die Definition mutiert hat).
func _refresh_engraving_die_faces() -> void:
	if engraving_die == null or not is_instance_valid(engraving_die):
		return
	if die_inspector.current_def == null:
		return
	var faces: DieFaceDisplay = engraving_die.get_node("RigidBody3D/Faces")
	faces.apply_definition(die_inspector.current_def)
	faces.set_tint(DiceController.KIND_TINTS.get(die_inspector.current_def.style_id, Color.WHITE))

## Kurzer Absorptions-Blitz: heller Aufpluster-Pop des schwebenden Würfels bei der
## Ankunft der Leiterbahn.
func _flash_engraving_die() -> void:
	if engraving_die == null or not is_instance_valid(engraving_die):
		return
	var base := Vector3.ONE * DiceTrayView.DIE_SCALE
	var pop := create_tween()
	pop.tween_property(engraving_die, "scale", base * 1.18, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(engraving_die, "scale", base, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Beendet die Zeremonie (siehe DieInspectorView.closed): der Tray-Slot wird
## wieder sichtbar, der Hub zeigt seine Übersicht, die Kamera kehrt in die
## Ansicht von vor der Zeremonie zurück.
func _end_engraving_ceremony() -> void:
	if not engraving_active:
		return
	engraving_active = false
	_free_engraving_die()
	if table_screen.hub != null:
		table_screen.hub.set_content_visible(true)
	if engraving_source_root != null and is_instance_valid(engraving_source_root):
		engraving_source_root.visible = true
	engraving_source_root = null
	engraving_source_tray = null
	if engraving_prev_mode == CameraRig.Mode.OVERVIEW:
		camera_rig.zoom_out()
	else:
		camera_rig.zoom_to(engraving_prev_mode)
	_on_die_engraved()  # Trays sicher aktuell (die Werte können sich geändert haben)

## Das Würfel-Raster des Panels wurde angeklickt (siehe DieInspectorView.
## select_tray_die): slot ist der ECHTE Slot-Index im Ziel-Tray. Wechselt auf
## diesen Würfel (No-Op, wenn es der bereits gegriffene ist - _grab_engraving_die
## fängt das ab).
func _on_tray_die_selected(slot: int) -> void:
	if not engraving_active or engraving_source_tray == null:
		return
	if slot < 0 or slot >= engraving_source_tray.slot_roots.size():
		return
	_grab_engraving_die(engraving_source_tray.slot_defs[slot], engraving_source_tray.slot_roots[slot], engraving_source_tray)

## Baut das Würfel-Raster des Panels neu: das komplette rows×columns-Raster des
## Ziel-Trays in Buchreihenfolge (leere Slots als leere Zellen), der gegriffene
## als aktueller markiert - spiegelt so das Tray und lässt das Ziel auch bei
## Hub-Zoom wechseln, wo die echten Tray-Würfel nicht im Bild sind.
func _refresh_engraving_tray_strip() -> void:
	if engraving_source_tray == null:
		return
	var tray := engraving_source_tray
	var slot_defs: Array[DieDefinition] = []
	for i in tray.slot_roots.size():
		var occupied: bool = tray.slot_roots[i].visible or tray.slot_roots[i] == engraving_source_root
		slot_defs.append(tray.slot_defs[i] if occupied else null)
	var current_slot: int = tray.slot_roots.find(engraving_source_root)
	die_inspector.set_tray_grid(tray.rows, tray.columns, slot_defs, current_slot)

## Harter Abbruch der Zeremonie ohne Animationen (Spiel-Reset, siehe _reset_game).
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

## Klick auf einen Würfel im Warteschlangen-Tray (Layer 16) - startet einen
## POTENZIELLEN Umsortier-Drag (siehe reorder_drag_index/_handle_reorder_input).
## Ob daraus wirklich ein Umsortieren wird oder nur die Würfel-Vorschau wie bei
## den anderen Trays öffnet, entscheidet sich erst beim Loslassen anhand von
## REORDER_DRAG_THRESHOLD. Exklusiv fürs Warteschlangen-Tray - Pool-/Ablage-
## Tray laufen weiterhin nur über _try_tray_die_click.
func _try_start_queue_reorder(screen_pos: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = DiceTrayView.SLOT_PICK_LAYER
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var index: int = queue_tray_view.find_slot_index(result.collider)
	if index == -1:
		return false
	reorder_drag_index = index
	reorder_drag_start_pos = screen_pos
	reorder_is_dragging = false
	return true

## Verarbeitet Maus-Bewegung/-Loslassen während eines potenziellen/aktiven
## Umsortier-Drags (siehe _try_start_queue_reorder). Ein Rechtsklick bricht
## ihn ab; Bewegung über REORDER_DRAG_THRESHOLD hinaus hebt den Würfel sichtbar
## an (siehe _begin_reorder_drag) und lässt ihn der Maus folgen; Loslassen ohne
## Bewegung öffnet stattdessen die Würfel-Vorschau wie bei den anderen Trays.
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

## Versteckt den Original-Slot und lässt einen freien Ghost-Würfel (gleiches
## Muster wie die Ghosts der Aufrück-Animation, siehe _animate_deck_shift) an
## seiner Stelle schweben - ab jetzt folgt er der Maus (_update_reorder_drag).
func _begin_reorder_drag() -> void:
	var def: DieDefinition = queue_tray_view.slot_defs[reorder_drag_index]
	queue_tray_view.set_slot_visible(reorder_drag_index, false)
	reorder_ghost = _spawn_deck_ghost(def)
	reorder_ghost.global_position = queue_tray_view.slot_global_position(reorder_drag_index) + Vector3.UP * REORDER_LIFT_HEIGHT

## Lässt den Ghost-Würfel der Maus folgen: projiziert screen_pos auf eine
## waagerechte Ebene auf Anhebehöhe über dem Warteschlangen-Tray.
func _update_reorder_drag(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or reorder_ghost == null:
		return
	var plane := Plane(Vector3.UP, queue_tray_view.global_position.y + REORDER_LIFT_HEIGHT)
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var hit = plane.intersects_ray(from, dir)
	if hit != null:
		reorder_ghost.global_position = hit

## Loslassen nach einem Zieh-Drag: sortiert bei einem gültigen Zielslot um und
## lässt alle davon betroffenen Würfel gleiten (siehe _animate_reorder_move),
## sonst gleitet der gezogene Würfel einfach zu seinem ursprünglichen Slot
## zurück (siehe _animate_reorder_snapback).
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

## Bildschirmnächster belegter Slot im Warteschlangen-Tray zu screen_pos
## (analog zu RotatableDieView._pick_die: Bildschirm-Projektion statt Physik-
## Raycast, da der gezogene Würfel selbst keine Kollision mehr hat). -1, wenn
## außerhalb von REORDER_DROP_RADIUS losgelassen wurde.
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

## Kein gültiger Zielslot (oder auf dem eigenen Slot losgelassen): der
## gezogene Ghost-Würfel gleitet zu seinem ursprünglichen Platz zurück - statt
## einfach zu verschwinden, während der Slot sich schlagartig wieder füllt.
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

## Wie sich ein alter Slot-Index innerhalb des Warteschlangen-Fensters durch
## das Verschieben von from_index nach to_index verändert (Standard "Element
## verschieben"-Semantik, wie bei remove_at()+insert() auf einem Array).
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

## Sortiert einen Würfel innerhalb des sichtbaren Warteschlangen-Fensters um:
## entfernt ihn bei from_index und fügt ihn bei to_index wieder ein (wie eine
## Karte in der Hand verschieben - dazwischenliegende Würfel rücken nach).
## Wirkt nur innerhalb von round_pool_kinds[next_draw_index ..
## next_draw_index+queue_window_size) - der Pool-Teil des Decks ist davon nie
## betroffen, da beide Indizes aus diesem Fenster stammen (siehe
## _try_start_queue_reorder/_nearest_queue_slot). Alle zwischen from_index und
## to_index liegenden Würfel gleiten sichtbar zu ihrem neuen Slot (gleiche
## Ghost-Technik wie die Aufrück-Animation nach einem Wurf, siehe
## _animate_deck_shift) - der gezogene Würfel ist dabei schon sein eigener
## Ghost (reorder_ghost) und gleitet einfach zur Zielposition weiter, statt
## neu gespawnt zu werden.
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

## Klick auf einen Tisch-Charm in der Grubenansicht - startet einen POTENZIELLEN
## Umsortier-Drag (siehe charm_drag_index/_handle_charm_drag_input). Ob daraus
## ein Umsortieren wird, entscheidet REORDER_DRAG_THRESHOLD beim Bewegen; ein
## Loslassen ohne Bewegung tut nichts (Name + Wirkung zeigt schon der Hover-
## Tooltip, siehe _update_charm_tooltip).
func _try_start_charm_reorder(screen_pos: Vector2) -> bool:
	if camera_rig.is_animating:
		return false
	var index := charm_row.charm_index_at_screen_pos(camera_rig, screen_pos)
	if index == -1:
		return false
	charm_drag_index = index
	charm_drag_start_pos = screen_pos
	charm_is_dragging = false
	return true

## Verarbeitet Maus-Bewegung/-Loslassen während eines potenziellen/aktiven
## Charm-Drags (siehe _try_start_charm_reorder). Ein Rechtsklick bricht ab;
## Bewegung über REORDER_DRAG_THRESHOLD hinaus hebt den Charm an und lässt ihn
## der Maus folgen; Loslassen über einem anderen belegten Platz sortiert um
## (run.move_charm -> charms_changed baut die Reihe neu), sonst gleitet der
## Charm zu seinem Platz zurück.
func _handle_charm_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_charm_drag()
		return

	if event is InputEventMouseMotion:
		if not charm_is_dragging and event.position.distance_to(charm_drag_start_pos) > REORDER_DRAG_THRESHOLD:
			charm_is_dragging = true
			_begin_charm_drag()
		if charm_is_dragging:
			_update_charm_drag(event.position)
		return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if charm_is_dragging:
			_finish_charm_drag(event.position)
		charm_drag_index = -1
		charm_is_dragging = false

## Hebt das Charm-Modell von der Tischfläche an - ab jetzt folgt es der
## Maus (_update_charm_drag). Anders als beim Warteschlangen-Tray braucht es
## keinen Ghost: die Charm-Modelle sind freie Nodes ohne Physik.
func _begin_charm_drag() -> void:
	var node: Node3D = charm_row.charm_nodes[charm_drag_index]
	node.global_position = charm_row.spot_global_position(charm_drag_index) + Vector3.UP * CHARM_LIFT_HEIGHT

## Lässt den gezogenen Charm der Maus folgen: projiziert screen_pos auf eine
## waagerechte Ebene auf Anhebehöhe über den Charm-Plätzen.
func _update_charm_drag(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var plane := Plane(Vector3.UP, charm_row.spot_global_position(charm_drag_index).y + CHARM_LIFT_HEIGHT)
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var hit = plane.intersects_ray(from, dir)
	if hit != null:
		charm_row.charm_nodes[charm_drag_index].global_position = hit

## Loslassen nach einem Charm-Drag: über einem anderen belegten Platz wird
## umsortiert (die Reihenfolge ist spielrelevant - Totems kopieren Nachbarn,
## siehe GameRun.charm_ids), sonst gleitet der Charm zurück.
func _finish_charm_drag(screen_pos: Vector2) -> void:
	var target_index := _nearest_charm_spot(screen_pos)
	if target_index != -1 and target_index != charm_drag_index:
		run.move_charm(charm_drag_index, target_index)  # charms_changed -> _on_charms_changed baut die Reihe neu
	else:
		charm_row.glide_charm_to_spot(charm_drag_index)

func _cancel_charm_drag() -> void:
	if charm_is_dragging:
		charm_row.glide_charm_to_spot(charm_drag_index)
	charm_drag_index = -1
	charm_is_dragging = false

## Bildschirmnächster BELEGTER Charm-Platz zu screen_pos (gleiche Projektions-
## Logik wie _nearest_queue_slot). -1, wenn außerhalb von CHARM_DROP_RADIUS
## losgelassen wurde - leere Plätze sind keine Ziele, die Reihe bleibt lückenlos
## (set_charms packt in Besitz-Reihenfolge).
func _nearest_charm_spot(screen_pos: Vector2) -> int:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return -1
	var best_index := -1
	var best_dist := CHARM_DROP_RADIUS
	for i in charm_row.current_charms.size():
		var spot_screen := camera.unproject_position(charm_row.spot_global_position(i))
		var dist := spot_screen.distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best_index = i
	return best_index

## Klick auf die Würfelgrube oder eines der Trays (Layer 4) -> Kamera fährt
## näher heran. Läuft unabhängig vom Halten-Klick auf Würfel (Layer 2).
## Richtet Zoom-Ziel und Klickfläche des Kombinations-Clusters ein: Blickpunkt
## aus der Cluster-Mitte des Displays (TableScreen.pixel_to_world), plus eine
## flache Klickbox (Layer 8 wie PitClickZone) über der Cluster-Fläche, damit ein
## Linksklick darauf heranzoomt (siehe _try_zoom_click). Folgt automatisch, wenn
## der Cluster auf dem Display umzieht.
func _setup_combos_zoom() -> void:
	var rect := table_screen.cluster_rect
	var center := table_screen.pixel_to_world(rect.get_center())
	camera_rig.configure_combos_target(center)

	# Weltausdehnung der Cluster-Fläche aus zwei gegenüberliegenden Ecken (die
	# Abbildung ist achsenparallel: Screen-x -> Welt-z, Screen-y -> Welt-x).
	var corner_a := table_screen.pixel_to_world(rect.position)
	var corner_b := table_screen.pixel_to_world(rect.end)
	var box := BoxShape3D.new()
	box.size = Vector3(absf(corner_a.x - corner_b.x), 4.0, absf(corner_a.z - corner_b.z))

	combos_click_zone = StaticBody3D.new()
	combos_click_zone.name = "CombosClickZone"
	combos_click_zone.collision_layer = 8  # Kamera-Klickebene, wie PitClickZone
	combos_click_zone.collision_mask = 0
	combos_click_zone.position = center
	var shape := CollisionShape3D.new()
	shape.shape = box
	combos_click_zone.add_child(shape)
	add_child(combos_click_zone)

## Richtet Zoom-Ziel und Klickfläche der Charm-Reihe ein: Blickpunkt = Mitte der
## Linie (siehe CharmRowView.LINE_X), plus eine flache Klickbox (Layer 8) über
## der ganzen Reihe. Maße folgen den CharmRowView-Konstanten, damit ein
## Verschieben/Umbau der Reihe automatisch mitgezogen wird.
func _setup_charms_zoom() -> void:
	var center: Vector3 = charm_row.to_global(Vector3(CharmRowView.LINE_X, CharmRowView.SPOT_Y, 0.0))
	camera_rig.configure_charms_target(center)

	var half_z := float(CharmRowView.SPOT_COUNT - 1) * 0.5 * CharmRowView.LINE_SPACING + CharmRowView.BEAM_RADIUS
	var box := BoxShape3D.new()
	box.size = Vector3(CharmRowView.BEAM_RADIUS * 2.0, 4.0, half_z * 2.0)

	charms_click_zone = StaticBody3D.new()
	charms_click_zone.name = "CharmsClickZone"
	charms_click_zone.collision_layer = 8  # Kamera-Klickebene, wie PitClickZone
	charms_click_zone.collision_mask = 0
	charms_click_zone.position = center
	var shape := CollisionShape3D.new()
	shape.shape = box
	charms_click_zone.add_child(shape)
	add_child(charms_click_zone)

## Richtet Kamera-Zoomziel und Klickzone des Hubs ein (siehe HubView): Blickpunkt
## = Hub-Anker auf Tischhöhe, Klickbox (Layer 8) über der ganzen Hub-Fläche.
## Maße folgen HUB_*_WORLD - ein Verschieben des Ankers im Editor zieht Zoom und
## Klickzone automatisch mit.
func _setup_hub_zoom() -> void:
	var anchor := hub_anchor.global_position
	var center := Vector3(anchor.x, 0.0, anchor.z)  # 0 = Screen-Oberfläche
	camera_rig.configure_hub_target(center)

	# Welt-X = Bildschirm-Höhe des Hubs, Welt-Z = seine Breite (siehe world_to_pixel).
	var box := BoxShape3D.new()
	box.size = Vector3(HUB_HEIGHT_WORLD, 4.0, HUB_WIDTH_WORLD)

	hub_click_zone = StaticBody3D.new()
	hub_click_zone.name = "HubClickZone"
	hub_click_zone.collision_layer = 8  # Kamera-Klickebene, wie PitClickZone
	hub_click_zone.collision_mask = 0
	hub_click_zone.position = center
	var shape := CollisionShape3D.new()
	shape.shape = box
	hub_click_zone.add_child(shape)
	add_child(hub_click_zone)

## Reicht ein Mausereignis an die Controls auf dem Tisch-Display weiter (siehe
## HubView) - liefert true, wenn es weitergereicht wurde (der Aufrufer soll es
## dann nicht mehr als 3D-Klick behandeln). Nur in der Hub-Ansicht aktiv
## (CameraRig.Mode.HUB, nicht während der Kamerafahrt) und nur für Ereignisse,
## deren Kamerastrahl die Hub-Fläche trifft: Der Strahl wird analytisch mit der
## Tischebene geschnitten (TableScreen.pixel_from_ray, kein Physik-Raycast), der
## Treffer in Display-Pixel übersetzt und als geklontes Ereignis in den
## SubViewport gedrückt (push_input) - dort verhalten sich Buttons/Hover wie
## normale Godot-UI. Rechtsklicks werden nie weitergereicht (Zoom-out).
func _forward_screen_mouse(event: InputEventMouse) -> bool:
	if camera_rig.mode != CameraRig.Mode.HUB or camera_rig.is_animating:
		return false
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null or table_screen == null or table_screen.hub == null:
		return false
	var pixel := table_screen.pixel_from_ray(
		camera.project_ray_origin(event.position),
		camera.project_ray_normal(event.position))
	if pixel.x < 0.0 or not table_screen.hub.get_rect().has_point(pixel):
		last_screen_pixel = Vector2(-1, -1)  # Hover-Verlauf neu ansetzen
		return false
	var forwarded := event.duplicate() as InputEventMouse
	forwarded.position = pixel
	forwarded.global_position = pixel
	if forwarded is InputEventMouseMotion:
		# relative aus dem letzten weitergereichten Pixel ableiten (der
		# Original-Wert ist in Fenster-Pixeln, nicht in Display-Pixeln).
		forwarded.relative = (pixel - last_screen_pixel) if last_screen_pixel.x >= 0.0 else Vector2.ZERO
	last_screen_pixel = pixel
	table_screen.push_input(forwarded)
	return true

func _try_zoom_click(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 8
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Object = result.collider
	if collider == pit_click_zone:
		# Grubenklick, je nach aktueller Ansicht:
		# - schon in der Grubenansicht: wirft den nächsten Wurf (wie Becher/
		#   Würfeln-Button - _on_throw_button_pressed prüft selbst, ob das gerade
		#   erlaubt ist).
		# - sonst (Übersicht oder ein anderer Zoom): in die (einzige) Grubenansicht.
		# Herauszoomen weiterhin per Rechtsklick.
		if camera_rig.mode == CameraRig.Mode.PIT:
			_on_throw_button_pressed()
		else:
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

## Baut den (zunächst verdeckten) Hover-Tooltip der Charms: Name in Gold,
## darunter die Wirkung. Folgt in _update_charm_tooltip dem Cursor.
func _build_charm_tooltip() -> void:
	charm_tooltip = PanelContainer.new()
	charm_tooltip.visible = false
	charm_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_panel(charm_tooltip)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charm_tooltip.add_child(box)
	charm_tooltip_title = Label.new()
	charm_tooltip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(charm_tooltip_title, 20, CasinoStyle.GOLD)
	box.add_child(charm_tooltip_title)
	charm_tooltip_body = Label.new()
	charm_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	charm_tooltip_body.custom_minimum_size = Vector2(280, 0)
	charm_tooltip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_body_label(charm_tooltip_body, 15, CasinoStyle.CREAM)
	box.add_child(charm_tooltip_body)
	$UI.add_child(charm_tooltip)

func _process(_delta: float) -> void:
	_update_charm_tooltip()

## Hover-Tooltip der Charms: aktiv aus JEDER Ansicht, sobald der Cursor über
## einem Charm liegt (Projektions-Nähe, siehe CharmRowView.charm_at_screen_pos) -
## nur nicht während der Kamerafahrt oder beim Umsortier-Drag. Zeigt Name +
## Wirkung des Charms und folgt der Maus, am Bildrand eingeklemmt.
func _update_charm_tooltip() -> void:
	if charm_tooltip == null:
		return
	if camera_rig.is_animating or charm_is_dragging:
		charm_tooltip.visible = false
		return
	var mouse := get_viewport().get_mouse_position()
	var charm := charm_row.charm_at_screen_pos(camera_rig, mouse)
	if charm == null:
		charm_tooltip.visible = false
		return
	charm_tooltip_title.text = charm.display_name
	charm_tooltip_body.text = charm.description
	charm_tooltip.visible = true
	charm_tooltip.reset_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var pos := mouse + Vector2(18, 18)
	pos.x = minf(pos.x, viewport_size.x - charm_tooltip.size.x - 8.0)
	pos.y = minf(pos.y, viewport_size.y - charm_tooltip.size.y - 8.0)
	charm_tooltip.position = pos

## Klick auf den Würfelbecher (eigene Kollisions-Ebene, siehe DiceCup.CLICK_LAYER)
## löst denselben Wurf wie der Würfeln-/Neu-würfeln-Button aus - nur während
## die Kamera auf die Grube fokussiert ist (dort ist der Becher auch sichtbar/
## erreichbar, siehe Aufrufer in _unhandled_input). _on_throw_button_pressed
## prüft alle Vorbedingungen selbst, ein "ungültiger" Klick auf den Becher
## verhält sich also wie ein Klick auf den (ggf. deaktivierten) Button.
func _try_cup_click(screen_pos: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = DiceCup.CLICK_LAYER
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	_on_throw_button_pressed()
	return true

## True, solange der aktuelle Wurf sichtbar läuft (Becher-Animation oder
## Physik) - währenddessen sind Tray-Klicks und Umsortieren gesperrt.
func _dice_in_motion() -> bool:
	return phase == Phase.CUP_ANIMATING or phase == Phase.ROLLING

## True in allen Phasen VOR dem Rundenabschluss (inklusive laufender Würfe) -
## das frühere game_state == PLAYING (siehe _on_debug_win_round_pressed).
func _is_playing() -> bool:
	return phase == Phase.IDLE or _dice_in_motion()

func _can_toggle_selection() -> bool:
	return phase == Phase.IDLE and has_rolled_current_hand

func _pick_die_index(screen_pos: Vector2) -> int:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return -1

	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return -1

	return dice.index_of_body(result.collider)

## Seiten-Material der aktuell oben liegenden Seite je Wurf-Slot ("" = keins
## oder noch nicht gewürfelt) - parallel zu dice.values, Grundlage der
## Material-Wertung (siehe MaterialEffects/DiceScoring).
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

## Kanten-Material je Wurf-Slot ("" = keins) - parallel zu dice.values. Wirkt
## unabhängig von der oben liegenden Seite (siehe MaterialEffects).
func _edge_materials() -> Array[String]:
	var materials: Array[String] = []
	for i in dice.count():
		materials.append(dice.slot_defs[i].edge_material)
	return materials

## Wurf-/Runden-Zustand für die Effektkatalog-Charms (ctx-Schlüssel siehe
## CharmEffects) - wird in JEDE Wertung gereicht (Vorschau, Nehmen,
## Farkle-Vergleich), damit Anzeige und Rechnung identisch bleiben.
func _score_ctx() -> Dictionary:
	return {
		"rerolled": rerolled_dice_this_hand,
		"taken_dice": taken_dice_this_round,
		"full_rerolls": full_reroll_stacks,
		"streak": momentum_streak,
		"last_hand": _remaining_in_pool() < HAND_SIZE,  # nach dieser Hand geht keine volle mehr
		"after_farkle": first_hand_after_farkle,
		"farkle_stacks": run.farkle_count,
		"last_settled": dice.last_settled_index,
		"late_slots": _late_slots(),
	}

## Wie _score_ctx, aber auf einen Auswahl-Teilwurf (siehe _scoring_slots)
## umgerechnet: die SLOT-bezogenen ctx-Werte (last_settled, late_slots) tragen
## echte Würfel-Slots, die Wertung des Teilwurfs indiziert aber gefiltert
## (0..len-1). Ohne diese Übersetzung würden slot-abhängige Charms (Nachzügler,
## Bodensatz) beim Wählen einzelner Würfel auf die falschen Positionen zeigen.
func _score_ctx_for_slots(slots: Array[int]) -> Dictionary:
	var ctx := _score_ctx()
	var to_filtered := {}
	for k in slots.size():
		to_filtered[slots[k]] = k
	ctx["last_settled"] = to_filtered.get(ctx["last_settled"], -1)
	var mapped_late: Array = []
	for s in ctx.get("late_slots", []):
		if to_filtered.has(s):
			mapped_late.append(to_filtered[s])
	ctx["late_slots"] = mapped_late
	return ctx

## Slots, deren Würfel aus den letzten 6 Positionen des Nachziehstapels gezogen
## wurden (Bodensatz-Charm, siehe slot_draw_positions).
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

## Schickt einen einzelnen gebrauchten Würfel ins Ablage-Tray (und merkt ihn
## sich für die Phönixfeder, siehe discarded_this_round/_on_farkle).
func _discard_kind(def: DieDefinition) -> void:
	discarded_this_round.append(def)
	discard_tray_view.add_die(def)

## Wie viele der im Warteschlangen-Tray angezeigten Würfel beim nächsten Wurf
## tatsächlich gezogen werden (siehe fill()-Aufruf in _refresh_deck_trays):
## vor dem ersten Wurf einer Hand immer HAND_SIZE, danach genau so viele, wie
## nicht ausgewählte (also nicht geschützte) Slots neu geworfen werden
## (begrenzt auf das, was der Pool noch hergibt) - ausgewählte Würfel
## brauchen keinen Nachschub, siehe _on_throw_button_pressed.
func _current_queue_size() -> int:
	var wanted := HAND_SIZE
	if has_rolled_current_hand:
		wanted = 0
		for i in dice.count():
			if not dice.selected[i]:
				wanted += 1
	return min(wanted, _remaining_in_pool())

## Pool-Tray und Warteschlangen-Tray zusammen zeigen genau den noch nicht
## gezogenen Teil des Pools (POOL_SIZE Würfel insgesamt): die Warteschlange
## ist ein fest reserviertes 6er-Fenster direkt am Zieh-Cursor, der Pool zeigt
## alles danach. Das Fenster selbst ändert sich nur, wenn next_draw_index
## vorrückt (siehe _draw_one) - also erst beim tatsächlichen Wurf, nicht schon
## beim Halten/Loslassen einzelner Würfel in der Grube. Beide Trays werden bei
## jeder Änderung komplett neu befüllt, nie einzeln ausgeblendet - dadurch
## rückt beim Ziehen immer alles kompakt nach, die Lücke entsteht hinten
## (unten rechts) statt mittendrin.
func _refresh_deck_trays() -> void:
	if not deck_shift_ghosts.is_empty():
		return  # Aufrück-Animation läuft noch - sie ruft am Ende selbst _refresh_deck_trays auf
	queue_tray_view.ensure_capacity(_queue_capacity())
	queue_window_size = min(_queue_capacity(), _remaining_in_pool())
	var queue_defs := round_pool_kinds.slice(next_draw_index, next_draw_index + queue_window_size)
	queue_tray_view.fill(queue_defs)
	var pool_start := next_draw_index + _queue_capacity()
	pool_tray_view.fill(round_pool_kinds.slice(pool_start, round_pool_kinds.size()))

## Größe des Warteschlangen-Fensters: die üblichen HAND_SIZE Plätze plus die
## dauerhaften Extra-Plätze des Ausziehtischs (siehe GameRun.queue_bonus_slots
## und _on_round_complete). Beim allerersten Aufbau (_reset_game räumt auf,
## BEVOR der Run existiert) gibt es noch keinen Run - dann gilt die Basisgröße.
func _queue_capacity() -> int:
	if run == null:
		return HAND_SIZE
	return HAND_SIZE + run.queue_bonus_slots

## Weltposition, an der der Deck-Eintrag deck_index angezeigt wird, wenn der
## Zieh-Cursor bei cursor steht: die ersten _queue_capacity() Einträge nach dem
## Cursor liegen im Warteschlangen-Tray, alles danach im Pool-Tray (gleiche
## Aufteilung wie _refresh_deck_trays).
func _deck_slot_position(deck_index: int, cursor: int) -> Vector3:
	var offset := deck_index - cursor
	if offset < _queue_capacity():
		return queue_tray_view.slot_global_position(offset)
	return pool_tray_view.slot_global_position(offset - _queue_capacity())

## Baut einen freien, nicht-kollidierenden Würfel für die diversen Gleit-
## Animationen (Aufrücken nach einem Wurf, Umsortieren im Warteschlangen-Tray)
## - zeigt def in der passenden Art-Farbe, ist aber keinem Tray-Slot zugeordnet.
func _spawn_deck_ghost(def: DieDefinition) -> Node3D:
	var ghost := DieBuilder.build()
	add_child(ghost)
	ghost.rotation.y = -PI / 2.0  # gleiche Ausrichtung wie die Tray-Würfel (siehe DiceTrayView._build_slots)
	ghost.scale = Vector3.ONE * DiceTrayView.DIE_SCALE
	var body: RigidBody3D = ghost.get_node("RigidBody3D")
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	var faces: DieFaceDisplay = ghost.get_node("RigidBody3D/Faces")
	faces.apply_definition(def)
	faces.set_tint(DiceController.KIND_TINTS.get(def.style_id, Color.WHITE))
	return ghost

## Lässt die verbleibenden Deck-Würfel sichtbar aufrücken, nachdem shift Würfel
## gezogen wurden (Aufruf direkt nach den _draw_one()-Aufrufen eines Wurfs):
## beide Trays werden geleert und durch temporäre Geister-Würfel ersetzt, die
## von ihrer alten zu ihrer neuen Slot-Position gleiten - die vordersten
## Pool-Würfel wandern dabei sichtbar hinüber ins Warteschlangen-Tray. Danach
## übernimmt wieder die normale Slot-Anzeige (_refresh_deck_trays).
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
	if phase != Phase.IDLE:
		return
	if _remaining_in_pool() <= 0:
		return
	# Eine evtl. noch laufende Aufreihung des letzten Wurfs beenden - der neue
	# Wurf übernimmt die Würfel (siehe _line_up_settled_dice).
	_cancel_lineup()

	# Die gerade sichtbaren Warteschlangen-Würfel VOR dem Ziehen merken (Position
	# + Art) - das sind exakt die, die dieser Wurf tatsächlich zieht (siehe
	# _current_queue_size) und die gleich sichtbar in den Becher fliegen sollen.
	var used_count := _current_queue_size()
	var fly_positions: Array[Vector3] = []
	var fly_defs: Array[DieDefinition] = []
	for i in used_count:
		fly_positions.append(queue_tray_view.slot_global_position(i))
		fly_defs.append(queue_tray_view.slot_defs[i])

	# Alle nicht ausgewählten (also ungeschützten) Würfel, die dieser Wurf
	# ersetzt (siehe _current_queue_size), fliegen jetzt sichtbar Richtung
	# Ablage-Tray, gleichzeitig mit den neuen Würfeln, die aus der
	# Warteschlange in den Becher fliegen (siehe _play_cup_roll). Vor dem
	# allerersten Wurf einer Hand ist active_kinds noch leer, daher nur
	# relevant, wenn schon mindestens einmal geworfen wurde.
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

	# Ausgewählte, noch nicht genommene Würfel sind vor diesem Wurf geschützt
	# (siehe _current_queue_size) - sie gleiten beim selben Wurf sichtbar an
	# den oberen Rand der Grube (siehe _pit_top_row_position), statt zwischen
	# den frisch geworfenen Würfeln unterzugehen.
	var move_top_indices: Array[int] = []
	var move_top_targets: Array[Vector3] = []
	if has_rolled_current_hand:
		var selected_indices: Array[int] = []
		for i in dice.count():
			if dice.selected[i]:
				selected_indices.append(i)
		# In der aktuellen Reihen-Reihenfolge belassen (siehe _line_up_settled_dice):
		# die Würfel liegen entlang der Z-Achse aufgereiht, der obere Rand nutzt
		# dieselbe Achse - nach Z sortiert behalten sie beim Hochgleiten ihre
		# Ordnung, statt in die Slot-Reihenfolge zurückzuspringen.
		selected_indices.sort_custom(func(a: int, b: int) -> bool:
			return dice.bodies[a].global_position.z < dice.bodies[b].global_position.z)
		for k in selected_indices.size():
			var i: int = selected_indices[k]
			move_top_indices.append(i)
			move_top_targets.append(_pit_top_row_position(k, selected_indices.size(), dice.bodies[i].global_position.y))

	phase = Phase.CUP_ANIMATING
	take_button.disabled = true
	select_all_button.disabled = true

	var cursor_before_draw := next_draw_index
	last_throw_was_reroll = has_rolled_current_hand
	var thrown_indices: Array[int] = []
	if not has_rolled_current_hand:
		# Erster Wurf der Hand: die markierten (gequeuten) Würfel jetzt wirklich
		# ziehen und alle gezogenen Slots werfen.
		hand_note = ""
		active_kinds = []
		slot_draw_positions = []
		for i in HAND_SIZE:
			if _remaining_in_pool() <= 0:
				break
			slot_draw_positions.append(next_draw_index)  # Bodensatz (siehe _late_slots)
			active_kinds.append(_draw_one())
			thrown_indices.append(i)
		dice.set_slot_defs(active_kinds)
	else:
		# Neu würfeln: alle NICHT ausgewählten (also nicht geschützten) Slots
		# bekommen einen neu gezogenen Würfel und werden geworfen (siehe
		# throw_slots). Ausgewählte Würfel (siehe set_selected/
		# _auto_select_best_combo) sind geschützt und bleiben komplett
		# unangetastet liegen.
		pre_reroll_values = dice.values.duplicate()
		pre_reroll_materials = _rolled_materials()
		pre_reroll_edge_materials = _edge_materials()
		for i in dice.count():
			if not dice.selected[i] and _remaining_in_pool() > 0:
				if i < slot_draw_positions.size():
					slot_draw_positions[i] = next_draw_index  # Bodensatz (siehe _late_slots)
				active_kinds[i] = _draw_one()
				thrown_indices.append(i)
		dice.set_slot_defs(active_kinds)
		# Effektkatalog-Zähler: Pendel zählt neu geworfene Würfel, der Anker den
		# WIEVIELTEN Neuwurf die Hand hat, Alles-oder-nichts stapelt volle
		# Neuwürfe bis zum nächsten Nehmen (+5 Mult je Stapel).
		rerolls_this_hand += 1
		rerolled_dice_this_hand += thrown_indices.size()
		if thrown_indices.size() == dice.count():
			full_reroll_stacks += 1
	last_thrown_indices = thrown_indices.duplicate()
	_animate_deck_shift(next_draw_index - cursor_before_draw)

	await _play_cup_roll(fly_positions, fly_defs, discard_from, discard_defs, discard_to, move_top_indices, move_top_targets)
	if phase != Phase.CUP_ANIMATING:
		_clear_cup_interior_ghosts()
		return  # Spiel wurde während der Becher-Animation zurückgesetzt/beendet

	# Der Becher schwingt tatsächlich durch den Raum Richtung Grube (siehe
	# DiceCup.play_throw); poured_out feuert erst genau im Tiefpunkt dieses
	# Schwungs - erst dann verschwinden die Fake-Würfel im Becher und die
	# echten Wurf-Würfel starten an der dann aktuellen Mündungsposition
	# (siehe _throw_start_positions), damit sie nie teleportieren, sondern
	# sichtbar aus dem Becher heraus in die Grube rollen.
	dice_cup.play_throw()
	await dice_cup.poured_out
	_clear_cup_interior_ghosts()
	if phase != Phase.CUP_ANIMATING:
		return  # Spiel wurde während des Wurfschwungs zurückgesetzt/beendet

	var start_positions := _throw_start_positions()
	for k in thrown_indices.size():
		var i: int = thrown_indices[k]
		dice.start_transforms[i] = Transform3D(dice.start_transforms[i].basis, start_positions[k])
	phase = Phase.ROLLING
	dice.throw_slots(thrown_indices, throw_force, spin_strength, DicePit.PIT_CENTER)
	_refresh_ui()

## Startpositionen der echten Wurf-Würfel für den Moment von poured_out: ein
## enges Bündel um die aktuelle (geschwungene) Becher-Mündung, mit kleinem
## Zufalls-Versatz je Würfel für eine natürliche Streuung beim Landen -
## sodass sie sichtbar aus der Mündung kommen statt an einer festen,
## unabhängigen Stelle zu erscheinen (siehe DiceController.throw_slots:
## Wurfrichtung/-stärke ergeben sich pro Würfel automatisch aus seiner
## Startposition relativ zum Grubenzentrum).
func _throw_start_positions() -> Array[Vector3]:
	var mouth := dice_cup.mouth_position()
	var positions: Array[Vector3] = []
	for i in dice.count():
		positions.append(mouth + Vector3(randf_range(-0.6, 0.6), randf_range(-0.2, 0.2), randf_range(-0.6, 0.6)))
	return positions

## Zielposition für einen geschützten (ausgewählten, noch nicht genommenen)
## Würfel, der beim nächsten Wurf an den oberen Grubenrand gleitet (siehe
## _on_throw_button_pressed): eine mittig zentrierte Reihe, deren Breite sich
## nach der Anzahl geschützter Würfel richtet. y bleibt die des jeweiligen
## Würfels selbst (flacher Boden - nur X/Z ändern sich, kein Höhensprung).
func _pit_top_row_position(slot_number: int, count: int, y: float) -> Vector3:
	var span := PIT_TOP_ROW_SPACING * float(count - 1)
	var z := -span * 0.5 + PIT_TOP_ROW_SPACING * float(slot_number)
	return Vector3(DicePit.PIT_CENTER.x + PIT_TOP_ROW_X, y, DicePit.PIT_CENTER.z + z)

## Rückt die gerade ausgerollten Würfel in eine mittig zentrierte Reihe in der
## Grubenmitte auf - wie die geschützten Würfel am oberen Rand, nur für ALLE 6.
## Sortiert von links nach rechts: erst die Würfel der aktuellen Kombination
## (die Auswahl, siehe _auto_select_best_combo - daher NACH ihr aufrufen),
## dann alle übrigen, beide Gruppen mit den höchsten Augen zuerst. Reine
## Kosmetik nach dem Wurf: die Augen sind zu diesem Zeitpunkt schon gelesen,
## und jeder Würfel behält seine gewürfelte Oben-Seite - er dreht sich nur
## gerade (siehe _snapped_upright_basis), damit die Reihe ordentlich liegt.
## Die Körper werden dafür eingefroren und erst vom nächsten Wurf wieder
## freigegeben (siehe DiceController.throw_slots); ein neuer Wurf während des
## Gleitens bricht die Aufreihung ab (_cancel_lineup), damit Tween und Physik
## nicht um die Würfel ringen.
func _line_up_settled_dice() -> void:
	_cancel_lineup()
	# Nur sichtbare Würfel aufreihen - am Rundenende sind weniger als 6 im
	# Spiel (leergezogener Pool), und unsichtbare Slots sollen keine Lücken in
	# die Reihe reißen.
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
			return dice.values[a] > dice.values[b]  # dann absteigend nach Augen
		return a < b)
	# Alle auf die niedrigste Ruhehöhe der Gruppe setzen - ein Würfel, der auf
	# einem Nachbarn liegen geblieben ist, würde sonst in der Reihe schweben.
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

## Wie _snapped_upright_basis, aber zusätzlich so um die Hochachse gedreht,
## dass die Ziffer der Oben-Seite für den Spieler aufrecht steht: ihr
## "oben" (siehe DiceController.FACE_TEXT_UP) zeigt nach Bildschirm-oben
## (= Welt +X, siehe PIT_TOP_ROW_X). Die gewürfelte Oben-Seite bleibt dabei
## unverändert oben - es dreht nur die Lesbarkeit zurecht.
func _readable_upright_basis(basis: Basis) -> Basis:
	var snapped := _snapped_upright_basis(basis)
	for axis: String in DiceController.AXIS_DIRECTIONS:
		if (snapped * DiceController.AXIS_DIRECTIONS[axis]).dot(Vector3.UP) < 0.9:
			continue
		var text_up: Vector3 = snapped * DiceController.FACE_TEXT_UP[axis]
		return Basis(Vector3.UP, atan2(text_up.z, text_up.x)) * snapped
	return snapped

## Die nächstgelegene achsenparallele Ausrichtung einer Würfel-Basis: jede
## Achse rastet auf die Weltachse mit dem größten Anteil ein. Ein ausgerollter
## Würfel liegt ohnehin fast flach - so bleibt seine Oben-Seite oben, aber die
## Kanten werden parallel zur Reihe gerade gezogen.
func _snapped_upright_basis(basis: Basis) -> Basis:
	var x := _nearest_world_axis(basis.x, Vector3.ZERO)
	var y := _nearest_world_axis(basis.y, x)
	return Basis(x, y, x.cross(y))

## Die Weltachse (±X/±Y/±Z) mit dem größten Anteil an v - ausgenommen die
## bereits vergebene Achsrichtung blocked (Schutz gegen entartete Basen).
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

## Gibt die Fake-Würfel frei, die während des Schüttelns sichtbar im Becher
## liegen (siehe cup_interior_ghosts/_play_cup_roll) - aufgerufen im Moment
## des Auskippens, sobald die echten Wurf-Würfel übernehmen, sowie defensiv
## bei einem Reset mitten in der Animation (siehe _reset_game).
func _clear_cup_interior_ghosts() -> void:
	for ghost in cup_interior_ghosts:
		ghost.queue_free()
	cup_interior_ghosts.clear()

## Lässt beim Start eines Wurfs drei Bewegungen gleichzeitig ablaufen: die
## tatsächlich gezogenen Würfel (fly_defs, vorher an den
## Warteschlangen-Positionen fly_positions) fliegen sichtbar in den
## Würfelbecher; die dadurch ersetzten Würfel (discard_defs, vorher an
## discard_from) fliegen sichtbar Richtung Ablage-Tray (discard_to); und die
## geschützten, ausgewählten Würfel (move_top_indices, ihre echten
## RigidBody3D - keine Ghosts, sie bleiben ja im Spiel) gleiten an ihre neue
## Position am oberen Grubenrand (move_top_targets, siehe
## _pit_top_row_position). Erst wenn alles fertig geflogen ist, werden die
## Ablage-Würfel wirklich im Ablage-Tray sichtbar (siehe _discard_kind); die
## im Becher angekommenen Würfel werden NICHT gelöscht, sondern in
## $DiceCup/MeshRoot eingehängt (siehe cup_interior_ghosts) - dadurch liegen
## sie sichtbar im Becher und wackeln beim Schütteln (siehe
## DiceCup.play_shake) automatisch mit, ganz ohne eigene Physik. Sie
## verschwinden erst im Aufrufer (_on_throw_button_pressed), sobald der
## Becher tatsächlich auskippt.
func _play_cup_roll(fly_positions: Array[Vector3], fly_defs: Array[DieDefinition], discard_from: Array[Vector3], discard_defs: Array[DieDefinition], discard_to: Array[Vector3], move_top_indices: Array[int], move_top_targets: Array[Vector3]) -> void:
	if fly_defs.is_empty() and discard_defs.is_empty() and move_top_indices.is_empty():
		return

	var fly_tween := create_tween()
	fly_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fly_tween.set_parallel(true)

	var cup_ghosts: Array[Node3D] = []
	var mouth := dice_cup.mouth_position()
	for i in fly_defs.size():
		var ghost := _spawn_deck_ghost(fly_defs[i])
		ghost.global_position = fly_positions[i]
		cup_ghosts.append(ghost)
		var target := mouth + Vector3(randf_range(-0.4, 0.4), randf_range(-0.15, 0.15), randf_range(-0.4, 0.4))
		fly_tween.tween_property(ghost, "global_position", target, CUP_FLY_DURATION)

	var discard_ghosts: Array[Node3D] = []
	for i in discard_defs.size():
		var ghost := _spawn_deck_ghost(discard_defs[i])
		ghost.global_position = discard_from[i]
		discard_ghosts.append(ghost)
		fly_tween.tween_property(ghost, "global_position", discard_to[i], CUP_FLY_DURATION)

	for k in move_top_indices.size():
		var body := dice.bodies[move_top_indices[k]]
		body.freeze = true
		fly_tween.tween_property(body, "global_position", move_top_targets[k], CUP_FLY_DURATION)

	await fly_tween.finished
	for ghost in cup_ghosts:
		ghost.reparent(dice_cup.mesh_root, true)
		ghost.position = Vector3(randf_range(-0.7, 0.7), randf_range(0.15, 0.5), randf_range(-0.7, 0.7))
		ghost.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))
		cup_interior_ghosts.append(ghost)
	for i in discard_ghosts.size():
		discard_ghosts[i].queue_free()
		_discard_kind(discard_defs[i])

	if not fly_defs.is_empty():
		await dice_cup.play_shake(CUP_SHAKE_COUNT).finished

func _on_roll_finished() -> void:
	phase = Phase.IDLE

	# Gold-Kanten zahlen bei JEDEM Wurf der betroffenen Würfel - noch vor der
	# Farkle-Prüfung (auch ein farkelnder Wurf ist ein Wurf). Der Rahmenvergolder
	# verdoppelt die Auszahlung (siehe MaterialEffects.roll_money).
	var roll_income := MaterialEffects.roll_money(_edge_materials(), last_thrown_indices, run.charm_ids())
	if roll_income > 0:
		run.add_money(roll_income)
		_pulse_money_label()
		_show_money_popup(roll_income)

	# Farkle-Prüfung: nur ein echtes Neu-Würfeln kann farkeln – der erste Wurf
	# einer Hand nie. Bringt der Wurf nicht mehr Punkte als der Stand direkt
	# davor (gleich viele oder weniger), ist die ganze Hand verloren.
	if last_throw_was_reroll and not DiceScoring.is_strictly_better(dice.values, pre_reroll_values, run.charm_ids(), _rolled_materials(), pre_reroll_materials, _edge_materials(), pre_reroll_edge_materials, run.combo_levels, _score_ctx()):
		# Anker: der ERSTE Neuwurf jeder Hand kann nicht farkeln - der Wurf
		# zählt, die Hand läuft einfach weiter (wie ein verziehener Farkle).
		if CharmEffects.anchor_saves(run.charm_ids(), rerolls_this_hand):
			hand_note = "Anker: Der erste Neuwurf kann nicht farkeln – die Hand läuft weiter."
			dice.clear_selection()
			_auto_select_best_combo()
			_line_up_settled_dice()
			has_rolled_current_hand = true
			last_throw_was_reroll = false
			_refresh_action_buttons()
			_refresh_deck_trays()
			_refresh_ui()
			return
		_on_farkle()
		return

	# Nehmen-Auswahl für die jetzt liegenden Würfel neu setzen: automatisch die
	# beste offene Kombination vorschlagen (siehe _auto_select_best_combo), der
	# Spieler kann sie danach frei umklicken. Erst DANACH aufreihen - die Reihe
	# sortiert die Kombinations-Würfel nach links (siehe _line_up_settled_dice).
	dice.clear_selection()
	_auto_select_best_combo()
	_line_up_settled_dice()

	has_rolled_current_hand = true
	_refresh_action_buttons()
	_refresh_deck_trays()
	_refresh_ui()

## Farkle: die komplette Hand wird normalerweise ohne Punkte verworfen (nichts
## war ja schon genommen - Nehmen wirkt immer auf alle 6, siehe
## _on_take_button_pressed). Charms können das mildern (siehe CharmEffects):
## der Schornsteinfeger verzeiht den ersten Farkle jeder Runde (die Hand läuft
## einfach weiter), die Phönixfeder schickt die Würfel zurück in den
## Nachziehstapel, und die Kristallkugel zahlt Geld für jeden überlebten
## Farkle. Die verbrauchten Würfel sind bereits aus dem Pool gezogen; danach
## geht es mit der nächsten Hand weiter (bzw. die Runde endet, wenn das Ziel
## jetzt doch erreicht wurde oder der Pool keine volle Hand mehr hergibt).
func _on_farkle() -> void:
	var ids := run.charm_ids()

	# Schornsteinfeger: erster Farkle der Runde wird verziehen - die Hand wird
	# NICHT verworfen, sondern läuft mit den aktuellen Würfeln weiter (der
	# Spieler kann nehmen oder erneut würfeln), als hätte der schlechte Wurf
	# nur nicht verbessert. Ein verziehener Farkle löst KEINE Farkle-Effekte aus.
	if CharmEffects.forgives_first_farkle(ids) and not chimney_sweep_used_this_round:
		chimney_sweep_used_this_round = true
		hand_note = "Schornsteinfeger: Farkle verziehen – die Hand darf weiterlaufen."
		dice.clear_selection()
		_auto_select_best_combo()
		has_rolled_current_hand = true
		last_throw_was_reroll = false
		_refresh_action_buttons()
		_refresh_deck_trays()
		_refresh_ui()
		return

	hand_note = "Farkle! Keine höhere Punktzahl – die Hand wird ohne Punkte verworfen."

	# Effektkatalog: der Farkle zählt für den Zerbrochenen Spiegel (dauerhafter
	# Mult je Farkle), reißt die Momentum-Serie ab und markiert die nächste
	# Hand für den Galgenhumor.
	run.farkle_count += 1
	momentum_streak = 0
	first_hand_after_farkle = true

	# Scherbengericht: der Farkle zahlt $2 je verworfenem Würfel.
	var shard_income := CharmEffects.farkle_shard_income(active_kinds.size(), ids)
	if shard_income > 0:
		run.add_money(shard_income)
		_pulse_money_label()
		_show_money_popup(shard_income)

	# Standuhr: der Farkle verdoppelt die aktuellen Rundenpunkte.
	if CharmEffects.farkle_doubles_points(ids) and hand_total > 0:
		hand_total *= 2
		_animate_points_to(hand_total)
		hand_note = "Standuhr: Farkle – die Rundenpunkte verdoppeln sich!"

	# Flickenteppich: die Höchste-Zahl-Wertung des farkelnden Wurfs bleibt.
	if CharmEffects.farkle_keeps_high_card(ids):
		var high_card := DiceScoring.score_category(DiceScoring.ONE_KIND, dice.values, ids, false, _rolled_materials(), _edge_materials(), run.combo_levels, _score_ctx())
		if high_card > 0:
			hand_total += high_card
			_animate_points_to(hand_total)

	# Phönixfeder: die geworfenen Würfel wandern bei JEDEM Farkle ans Ende des
	# Nachziehstapels zurück statt in die Ablage - sie kommen später in der
	# Runde wieder (die Hand selbst bleibt trotzdem verloren).
	if CharmEffects.has_phoenix(ids):
		round_pool_kinds.append_array(active_kinds)
		hand_note = "Phönixfeder: Farkle – die Würfel kehren in den Nachziehstapel zurück."
	else:
		for kind in active_kinds:
			_discard_kind(kind)

	if hand_total >= run.round_goal or _remaining_in_pool() < HAND_SIZE:
		_on_round_complete()
	else:
		# Überlebter Farkle (Runde geht weiter): Kristallkugel zahlt Geld.
		var income := CharmEffects.farkle_survival_income(ids)
		if income > 0:
			run.add_money(income)
			_pulse_money_label()
			_show_money_popup(income)
		_start_new_hand()

## Nimmt die aktuell AUSGEWÄHLTEN Würfel als Hand (siehe _scoring_slots /
## DiceController.selected): nur sie bilden die Kombination und liefern die
## Basispunkte. Der Wert wird zum Rundenstand addiert; physisch wandern danach
## weiterhin alle liegenden Würfel ins Ablage-Tray. Ohne Auswahl gibt es nichts
## zu nehmen (der Nehmen-Knopf ist dann ohnehin gesperrt, siehe
## _refresh_action_buttons).
func _on_take_button_pressed() -> void:
	if phase != Phase.IDLE or not has_rolled_current_hand:
		return

	# Auswahl-Teilwurf: nur die gewählten Würfel zählen. participating u.Ä. zeigen
	# danach in diesen Teilwurf und werden über slots auf echte Slots
	# zurückgerechnet (siehe _remap_breakdown_to_slots).
	var slots := _scoring_slots()
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

	# is_first_hand für Charms, die nur die erste genommene Hand der Runde
	# betreffen (Zauberkarte) - VOR dem Hochzählen von hands_taken_this_round
	# auswerten.
	var sel_ctx := _score_ctx_for_slots(slots)
	var hand := DiceScoring.best_hand(sel_values, ids, hands_taken_this_round == 0, sel_materials, sel_edges, run.combo_levels, sel_ctx)
	# Die Zähl-Animation braucht die Wertung in Einzelschritten (Kombination →
	# Würfel → Charms → Verschmelzen) - VOR den Nehmen-Effekten bauen, da
	# Knochen/Glas gleich die Seiten der Pool-Würfel verändern. Die Slot-Indizes
	# der Schritte werden auf echte Würfel zurückgerechnet.
	var breakdown := ScoreBreakdown.build(hand["key"], sel_values, ids, hands_taken_this_round == 0, sel_materials, sel_edges, run.combo_levels, sel_ctx)
	_remap_breakdown_to_slots(breakdown, slots)
	hands_taken_this_round += 1
	var new_total: int = hand_total + int(breakdown["total"])
	await _play_take_animation(breakdown, new_total)
	if phase != Phase.SCORING:
		return  # Reset/Neustart während der Animation - nichts mehr anwenden
	phase = Phase.IDLE
	hand_total = new_total

	# Nehmen-Effekte der Materialien (Gold-Seite zahlt, Knochen wächst, Glas
	# schrumpft - Seiten wie Kanten) - nur für Würfel der genommenen
	# Kombination, genau einmal hier (nie in der Vorschau). Knochen/Glas
	# verändern die Pool-Würfel dauerhaft; das Ablage-Tray zeigt gleich die
	# schon veränderten Werte. Charms verstärken einzelne Materialien (siehe
	# MaterialEffects: Goldschmied/Knochenleim/Glasbläserlunge).
	# participating auf dem Auswahl-Teilwurf berechnen und auf echte Slots
	# zurückrechnen - nur die beteiligten AUSGEWÄHLTEN Würfel tragen Material-
	# Nehmen-Effekte (Gold zahlt, Knochen wächst, Glas schrumpft).
	var participating: Array[int] = []
	for p in DiceScoring.participating_indices(hand["key"], sel_values):
		participating.append(slots[p])
	var report := MaterialEffects.apply_take_effects(active_kinds, dice.face_indices, materials, participating, edge_materials, ids)
	var take_money := report.money

	# --- Effektkatalog-Charms beim Nehmen ---
	# Straßenmusiker: jede genommene Hand zahlt $1 je beteiligtem Würfel.
	take_money += CharmEffects.take_income(ids, participating.size())
	# Lumpensammler: die gleich abgelegten Würfel mit der Glückszahl oben zahlen.
	take_money += CharmEffects.rag_collector_income(dice.values, run.lumpensammler_value, ids)
	if take_money > 0:
		run.add_money(take_money)
		_pulse_money_label()
		_show_money_popup(take_money)
	# Goldrausch: nutzt die Kombination ALLE liegenden Würfel, wächst das Geld
	# um 50% (gedeckelt auf $50 Zuwachs).
	if CharmEffects.gold_rush_applies(ids, participating.size(), dice.count()):
		var rush := mini(run.money / 2, 50)
		if rush > 0:
			run.add_money(rush)
			_pulse_money_label()
			_show_money_popup(rush)
	# Hausrezept: die Kombination mit den meisten Menü-Stufen steigt beim
	# Nehmen erneut (nur wenn sie überhaupt Stufen hat).
	if ids.has(Charm.HOUSE_RECIPE):
		var level: int = run.combo_levels.get(hand["key"], 0)
		if level > 0 and level >= _max_combo_level():
			run.eat_meal(hand["key"])
	# Momentum/Galgenhumor/Pendel/Alles-oder-nichts: Zähler fortschreiben
	# (die Alles-oder-nichts-Stapel sind mit dieser Hand verbraucht).
	momentum_streak += 1
	first_hand_after_farkle = false
	taken_dice_this_round += dice.count()
	full_reroll_stacks = 0

	# Recycling: die erste genommene Hand der Runde kehrt ans Ende des
	# Nachziehstapels zurück (die Würfel liegen trotzdem sichtbar in der Ablage).
	if CharmEffects.recycles_first_hand(ids) and not recycling_used_this_round:
		recycling_used_this_round = true
		round_pool_kinds.append_array(active_kinds)

	for kind in active_kinds:
		_discard_kind(kind)

	if hand_total >= run.round_goal or _remaining_in_pool() < HAND_SIZE:
		_on_round_complete()
	else:
		_start_new_hand()

## Die Zähl-Animation beim Nehmen einer Hand (siehe ScoreBreakdown): Alle
## sichtbaren Würfel gleiten in eine schwebende Reihe über der Grube (zählende
## links, in Wertungsreihenfolge), jeder zählende Würfel bekommt ein Goldlicht
## auf dem Display. Dann bauen sich BASIS × MULT in der Grube Schritt für
## Schritt auf: erst die Kombination (feste Punkte + Kategorie-Mult), dann je
## Würfel von links nach rechts Augen- und Material-Zuwachs, dann die Charms
## (jeder feuernde blitzt auf, siehe CharmRowView.flash_charm), zum Schluss
## verschmelzen beide Zahlen zur Gesamtzahl und fliegen in den Zielbalken.
## Ein Reset während der Animation bricht sauber ab (siehe _score_step_wait) -
## der Aufrufer erkennt das an phase != SCORING und wendet nichts mehr an.
func _play_take_animation(breakdown: Dictionary, new_total: int) -> void:
	phase = Phase.SCORING
	take_button.disabled = true
	select_all_button.disabled = true
	_cancel_lineup()

	# 1) Schwebende Reihe: zählende Würfel zuerst (= Reihenfolge der
	# Zählschritte), unbeteiligte rechts daneben.
	var counting: Array[int] = []
	for slot: int in breakdown["eye_slots"]:
		if slot < dice.count() and dice.roots[slot].visible:
			counting.append(slot)
	var row := counting.duplicate()
	for i in dice.count():
		if dice.roots[i].visible and not row.has(i):
			row.append(i)
	if not row.is_empty():
		# Gemeinsame Ruhehöhe wie bei der Aufreihung (siehe _line_up_settled_dice).
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

	# Goldenes, abgerundetes Leucht-Rechteck als "Podest" unter jedem zählenden
	# Würfel - ~150% der Würfelgröße (siehe SCORE_GLOW_SIZE_FACTOR).
	var die_world := DiceTrayView.DIE_SCALE * DieBuilder.HALF_EXTENT * 2.0
	var glow_side := die_world * SCORE_GLOW_SIZE_FACTOR * table_screen.pixels_per_world()
	var glow_by_slot := {}
	for i in counting:
		var glow := table_screen.spawn_glow(
			table_screen.world_to_pixel(dice.bodies[i].global_position), glow_side)
		take_anim_glows.append(glow)
		glow_by_slot[i] = glow

	# 2) Kombination: ihre Werte stehen SCHON in der Daueranzeige (seit dem
	# Ausrollen, siehe _refresh_ui) - als Startsignal popt die Zelle der
	# Kombination, und je eine Leiterbahn verbindet sie kurz mit Basis- UND
	# Mult-Zähler (die Kombination ist die Quelle beider Startwerte). Bei der
	# Ankunft popen die Zähler; die Werte werden defensiv gestellt (No-Op, wenn
	# sie schon stimmen).
	var key: String = breakdown["key"]
	if combo_labels.has(key):
		_tween_combo_label(combo_labels[key], PAYOUT_LABEL_GLOW_COLOR, 1.3)
		var cell: Control = combo_labels[key]
		var cell_px: Vector2 = cell.position + cell.size / 2.0
		table_screen.spawn_score_trail(cell_px, "base", SCORE_TRAIL_TIME)
		table_screen.spawn_score_trail(cell_px, "mult", SCORE_TRAIL_TIME)
		if not await _score_step_wait(SCORE_TRAIL_TIME):
			return
		table_screen.pulse_pit_score()
	table_screen.update_pit_score(breakdown["combo"]["base_add"], breakdown["combo"]["mult_add"])
	if not await _score_step_wait(SCORE_STEP_TIME):
		return

	# 3) Würfel-Schritte von links nach rechts: je Zuwachs leuchtet eine
	# Leiterbahn vom Würfel in die wachsende Zahl auf (Cyan -> Basis, Gold ->
	# Mult, siehe ScoreTraceView); die Zahl springt erst bei der Ankunft hoch.
	# Erst die Augen, dann (falls vorhanden) der Material-Zuwachs als eigener
	# kleiner Schritt. Charms, die am Augenwert dieses Würfels drehen (z.B.
	# Kleinvieh, Hasenpfote), blitzen auf UND schicken GLEICHZEITIG mit dem
	# Würfel eine eigene Leiterbahn in die Basis - der Zuwachs kommt sichtbar
	# aus beiden Quellen.
	for step: Dictionary in breakdown["die_steps"]:
		var slot: int = step["slot"]
		_flash_scoring_die(slot)
		if glow_by_slot.has(slot):
			_pulse_glow(glow_by_slot[slot])
		for charm_index: int in step["eye_charm_indices"]:
			charm_row.flash_charm(charm_index)
			table_screen.spawn_score_trail(_charm_trail_source_px([charm_index]), "base", SCORE_TRAIL_TIME)
		var die_px := table_screen.world_to_pixel(dice.bodies[slot].global_position)
		table_screen.spawn_score_trail(die_px, "base", SCORE_TRAIL_TIME)
		if not await _score_step_wait(SCORE_TRAIL_TIME):
			return
		var mult_before_material: int = step["mult_after"] - step["mat_mult_add"]
		table_screen.update_pit_score(step["base_after_eye"], mult_before_material)
		if step["mat_base_add"] != 0 or step["mat_mult_add"] != 0:
			if not await _score_step_wait(SCORE_SUBSTEP_TIME):
				return
			_flash_scoring_die(slot)
			if step["mat_base_add"] != 0:
				table_screen.spawn_score_trail(die_px, "base", SCORE_TRAIL_TIME)
			if step["mat_mult_add"] != 0:
				table_screen.spawn_score_trail(die_px, "mult", SCORE_TRAIL_TIME)
			if not await _score_step_wait(SCORE_TRAIL_TIME):
				return
			table_screen.update_pit_score(step["base_after"], step["mult_after"])
		if not await _score_step_wait(SCORE_STEP_TIME):
			return

	# 4) Charm-Schritte (additive Boni, Einserkult, Krit): Charm blitzt, sein
	# Trail fliegt vom Charm-Platz (hinter der Display-Oberkante - der Trail
	# startet sichtbar aus seiner Richtung am Rand) in die betroffene Zahl.
	for step: Dictionary in breakdown["charm_steps"]:
		for charm_index: int in step["charm_indices"]:
			charm_row.flash_charm(charm_index)
		var source_px := _charm_trail_source_px(step["charm_indices"])
		if step["base_add"] != 0 or step["base_x"] != 1:
			table_screen.spawn_score_trail(source_px, "base", SCORE_TRAIL_TIME)
		if step["mult_add"] != 0 or step["mult_x"] != 1:
			table_screen.spawn_score_trail(source_px, "mult", SCORE_TRAIL_TIME)
		if not await _score_step_wait(SCORE_TRAIL_TIME):
			return
		table_screen.update_pit_score(step["base_after"], step["mult_after"])
		if not await _score_step_wait(SCORE_STEP_TIME):
			return

	# 5) Verschmelzen zu Basis × Mult; die Nach-Schritte (Regenbogenforelle,
	# Zauberkarte, Feierabendbier) arbeiten auf der Gesamtzahl weiter - auch
	# hier je ein Trail vom Charm in die Gesamtzahl.
	table_screen.show_pit_total(breakdown["merge_total"])
	if not await _score_step_wait(SCORE_MERGE_TIME):
		return
	for step: Dictionary in breakdown["post_steps"]:
		for charm_index: int in step["charm_indices"]:
			charm_row.flash_charm(charm_index)
		table_screen.spawn_score_trail(_charm_trail_source_px(step["charm_indices"]), "total", SCORE_TRAIL_TIME)
		if not await _score_step_wait(SCORE_TRAIL_TIME):
			return
		table_screen.show_pit_total(step["total_after"])
		if not await _score_step_wait(SCORE_STEP_TIME):
			return

	# 6) Die Gesamtzahl fliegt in den Zielbalken, der Punktestand zählt synchron
	# hoch (HUD-Balken UND Display-Balken, siehe _set_displayed_points).
	var fly := table_screen.fly_total_to_goal(SCORE_FLY_TIME)
	_animate_points_to(new_total)
	await fly.finished
	_cleanup_take_animation()

## Wartet einen Zählschritt ab. false = die Animation wurde abgebrochen (Reset
## hat die Phase umgesetzt) - dann ist hier schon aufgeräumt und der Aufrufer
## soll sofort aussteigen.
func _score_step_wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds).timeout
	if phase != Phase.SCORING:
		_cleanup_take_animation()
		return false
	return true

## Räumt die Display-Reste der Zähl-Animation weg (Goldlichter) und stellt die
## Daueranzeige still auf 0 × 0 - am normalen Ende, bei Abbruch und defensiv
## beim Reset (_refresh_ui setzt danach wieder die passenden Kombi-Werte).
func _cleanup_take_animation() -> void:
	for glow in take_anim_glows:
		glow.queue_free()
	take_anim_glows.clear()
	table_screen.reset_pit_score()

## Startpunkt (Display-Pixel) des Licht-Trails eines Charm-Schritts: der
## Tisch-Platz des ersten beteiligten Charms. Die Charm-Reihe steht hinter der
## Display-Oberkante - spawn_score_trail klemmt den Punkt an den Rand, der
## Trail kommt dann sichtbar aus der Richtung des Charms.
func _charm_trail_source_px(charm_indices: Array) -> Vector2:
	if charm_indices.is_empty():
		return table_screen.world_to_pixel(DicePit.PIT_CENTER)
	return table_screen.world_to_pixel(charm_row.spot_global_position(int(charm_indices[0])))

## Lässt den Wurf-Würfel in Slot slot golden aufblitzen (Zähl-Animation) -
## mit der halben Tray-Größe der Grubenwürfel als Ruhegröße (siehe _ready).
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

## Die höchste Menü-Stufe über alle Kombinationen (0 = keine Gerichte gegessen)
## - Grundlage des Hausrezepts (siehe _on_take_button_pressed).
func _max_combo_level() -> int:
	var best := 0
	for key in run.combo_levels:
		best = maxi(best, int(run.combo_levels[key]))
	return best

## Markiert alle Würfel fürs nächste "Neu würfeln" als geschützt (siehe
## DiceController.select_all) - nützlich, um versehentliches Neu-Würfeln der
## kompletten Hand zu vermeiden.
func _on_select_all_button_pressed() -> void:
	if phase != Phase.IDLE or not has_rolled_current_hand:
		return
	dice.select_all()
	_line_up_settled_dice()  # neue Ordnung (alle in der Kombination) angleiten
	_refresh_action_buttons()
	_refresh_ui()  # jetzt zählen alle Würfel - Kombination/Basis sofort nachziehen

## Markiert nach jedem Wurf automatisch die Würfel, die gerade die beste offene
## Kombination bilden (siehe DiceScoring.best_hand_indices), z.B. bei 3 Vierern
## + 2 Zweiern + einer 5 das Full House aus den 5 Vierern/Zweiern, ohne die
## unbeteiligte 5 - ein Vorschlag, den der Spieler danach frei umklicken kann.
## Die Auswahl bestimmt sowohl, welche Würfel beim nächsten "Neu würfeln"
## geschützt sind, ALS AUCH, welche für die Hand zählen (siehe _scoring_slots).
func _auto_select_best_combo() -> void:
	for position in DiceScoring.best_hand_indices(dice.values):
		dice.set_selected(position, true)

## Die echten Slot-Indizes der aktuell AUSGEWÄHLTEN, sichtbaren Würfel (siehe
## DiceController.selected / _auto_select_best_combo). NUR diese Würfel bilden die
## Hand: sie bestimmen die Kombination und liefern die Basispunkte. Ein abgewählter
## Würfel gehört nicht zur Hand - deselektiert der Spieler bei drei Dreien eine
## Drei, bleibt ein Paar (statt Dreierpasch), und die abgewählte Drei zählt keine
## Basispunkte mehr.
func _scoring_slots() -> Array[int]:
	var slots: Array[int] = []
	for i in dice.count():
		if dice.selected[i] and dice.roots[i].visible:
			slots.append(i)
	return slots

## Rechnet die Slot-Indizes einer über die AUSGEWÄHLTEN Würfel gebauten
## Schrittliste (ScoreBreakdown.build wurde mit dem Auswahl-Teilwurf gefüttert,
## seine Indizes zeigen also in diesen Teilwurf) auf die echten Würfel-Slots
## zurück: slots[gefilterter_index] = echter Slot. So leuchten in der
## Zähl-Animation genau die tatsächlich gewählten Würfel auf.
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

## Aktualisiert Nehmen/Alle-auswählen: beide sind nutzbar, sobald eine Hand
## liegt und weder gewürfelt noch der Becher gerade animiert wird. Nehmen
## verlangt zusätzlich mindestens einen ausgewählten Würfel - ohne Auswahl gibt
## es keine Hand zu nehmen (siehe _scoring_slots / _on_take_button_pressed).
func _refresh_action_buttons() -> void:
	var interactable := phase == Phase.IDLE and has_rolled_current_hand
	take_button.disabled = not interactable or _scoring_slots().is_empty()
	select_all_button.disabled = not interactable

func _on_reset_button_pressed() -> void:
	_reset_game()

## Testmodus umschalten: An = jede Runde bekommen ALLE Würfel zufällige Seiten-
## und Kanten-Materialien (siehe _start_new_round / GameRun.randomize_all_materials);
## Aus = Materialien werden von allen Würfeln entfernt. Beides startet die Runde
## neu, damit die geänderten Würfel sofort in Grube und Trays sichtbar sind.
func _on_test_materials_pressed() -> void:
	test_materials_enabled = not test_materials_enabled
	if not test_materials_enabled:
		run.clear_all_materials()
		run.remove_charms(TEST_MODE_CHARM_IDS)
	_refresh_test_materials_button()
	_start_new_round()

## Frische Instanzen der Testmodus-Charms (siehe TEST_MODE_CHARM_IDS).
func _test_mode_charms() -> Array[Charm]:
	return [Charm.golden_scarab(), Charm.goldsmith(), Charm.small_fry()]

## Aktualisiert die Beschriftung des Testmodus-Knopfs nach dem aktuellen Zustand.
func _refresh_test_materials_button() -> void:
	if test_materials_button != null:
		test_materials_button.text = "🧪 Testmaterialien: %s" % ("AN" if test_materials_enabled else "aus")

func _reset_game() -> void:
	phase = Phase.IDLE  # bricht auch laufende Wurf-/Zähl-Koroutinen ab (siehe _on_throw_button_pressed/_play_take_animation)
	_cancel_deck_shift()
	_cancel_reorder_drag()
	_cancel_charm_drag()
	_cancel_lineup()
	_cleanup_take_animation()
	_clear_cup_interior_ghosts()
	hand_note = ""
	last_throw_was_reroll = false
	momentum_streak = 0
	rerolled_dice_this_hand = 0
	rerolls_this_hand = 0
	full_reroll_stacks = 0
	run = GameRun.new_run()
	_connect_run()
	charm_shop.visible = false
	_abort_engraving()  # falls der Reset mitten in der Gravur-Zeremonie kam
	if table_screen != null and table_screen.hub != null:
		table_screen.hub.set_content_visible(true)  # falls der Reset mitten im Shop kam
	game_over_panel.visible = false
	_set_gameplay_ui_visible(true)
	_start_new_round()

## Verdrahtet einen frisch erzeugten Run (siehe _reset_game): Shop und
## Gravur-Station bekommen ihn gereicht, seine Signale halten die HUD-Anzeigen
## aktuell, und alle Anzeigen werden einmal auf den Startzustand gebracht.
## Der alte Run wird mitsamt seinen Verbindungen freigegeben (RefCounted).
func _connect_run() -> void:
	charm_shop.run = run
	die_inspector.run = run
	charm_library.run = run
	run.money_changed.connect(_on_money_changed)
	run.charms_changed.connect(_on_charms_changed)
	run.sheet_purchased.connect(_show_sheet_reveal)
	run.combo_upgraded.connect(_on_combo_upgraded)
	_on_money_changed(run.money)
	_on_charms_changed()
	_refresh_combo_label_texts()

func _start_new_round() -> void:
	_cancel_deck_shift()
	_cancel_reorder_drag()
	_cancel_charm_drag()
	_cancel_lineup()
	hands_taken_this_round = 0
	chimney_sweep_used_this_round = false
	taken_dice_this_round = 0
	recycling_used_this_round = false
	first_hand_after_farkle = false
	discarded_this_round = []
	slot_draw_positions = []

	# Rundenbeginn-Wirkungen der Effektkatalog-Charms (Mitternachtssnack,
	# Frankiermaschine, Schmuckkästchen; setzt auch den Gravierstift zurück) -
	# VOR dem Poolaufbau, damit frische Materialien sofort mitspielen.
	run.apply_round_start_charms()

	# Testmodus (siehe Einstellungs-Menü): jede Runde bekommen ALLE Würfel neue
	# zufällige Seiten- + Kanten-Materialien, plus die festen Testmodus-Charms
	# (Goldener Skarabäus, Goldschmied, Kleinvieh) - zum Ausprobieren der Wertung.
	if test_materials_enabled:
		run.randomize_all_materials()
		run.grant_charms(_test_mode_charms())

	var ids := run.charm_ids()
	round_pool_kinds = run.owned_pool.duplicate()
	# Glücksknoten (siehe CharmEffects.extra_round_dice): jede Runde bekommt
	# zusätzliche Standardwürfel in den Pool - mehr Hände und mehr Geld für
	# übrige Würfel.
	for i in CharmEffects.extra_round_dice(ids):
		round_pool_kinds.append(DieDefinition.standard())
	round_pool_kinds.shuffle()
	# Zieh-Reihenfolge: jede Partition zieht ihre Gruppe stabil nach vorn - die
	# ZULETZT angewandte gewinnt die vorderste Position (Frische Ware > Magnetring).
	if CharmEffects.draws_edges_first(ids):
		round_pool_kinds = _edges_first(round_pool_kinds)
	if CharmEffects.draws_fresh_first(ids):
		round_pool_kinds = _fresh_first(round_pool_kinds)
	run.newly_purchased = []  # Frische gilt nur für die nächste Runde nach dem Kauf

	next_draw_index = 0
	discard_tray_view.clear()
	hand_total = 0
	hand_note = ""
	_refresh_round_hud()
	_animate_points_to(0, false)
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

## Sortiert die zuletzt gekauften Würfel stabil an den Anfang (Frische Ware,
## siehe GameRun.newly_purchased - dieselben Pool-Instanzen).
func _fresh_first(pool: Array[DieDefinition]) -> Array[DieDefinition]:
	var fresh: Array[DieDefinition] = []
	var rest: Array[DieDefinition] = []
	for def in pool:
		if run.newly_purchased.has(def):
			fresh.append(def)
		else:
			rest.append(def)
	return fresh + rest

func _start_new_hand() -> void:
	has_rolled_current_hand = false
	active_kinds = []
	rerolled_dice_this_hand = 0
	rerolls_this_hand = 0
	# full_reroll_stacks bleibt bewusst stehen - Alles-oder-nichts stapelt bis
	# zum nächsten NEHMEN (siehe _on_take_button_pressed), nicht je Hand.
	dice.reset()
	take_button.disabled = true
	select_all_button.disabled = true
	_refresh_deck_trays()
	_refresh_ui()

## Rundenende: bei erreichtem Ziel gibt's einmalig MONEY_PER_ROUND_CLEAR plus
## MONEY_PER_UNUSED_DIE je Würfel, der im Rundenpool noch gar nicht gezogen
## wurde (siehe _remaining_in_pool) - wer das Ziel früh erreicht und den Rest
## des Pools ungenutzt lässt, wird also fürs Nicht-Ausreizen belohnt. Die
## Auszahlung läuft erst als Tisch-Animation ab (siehe
## _play_round_clear_payout), bevor der Shop aufgeht - die Phase springt dafür
## schon jetzt auf PAYOUT, damit während der Animation nichts anklickbar
## bleibt, obwohl Grube und Rundenanzeige optisch noch stehen bleiben.
func _on_round_complete() -> void:
	take_button.disabled = true
	select_all_button.disabled = true
	if hand_total >= run.round_goal:
		phase = Phase.PAYOUT
		var ids := run.charm_ids()
		# Glücksgroschen skaliert mit bereits erreichten Zielen (Runde N = das
		# (N-1)-te Ziel war schon geschafft).
		var blind := MONEY_PER_ROUND_CLEAR + CharmEffects.round_clear_bonus(ids, run.round_number - 1)
		var per_die := MONEY_PER_UNUSED_DIE + CharmEffects.unused_die_bonus(ids)  # Sparschwein
		# Schmuckkästchen: die übrigen (jetzt ausgezahlten) Würfel haben je 10%
		# Chance auf eine zufällige Material-Seite - dauerhaft im Pool.
		run.apply_jewelry_box(round_pool_kinds.slice(next_draw_index, round_pool_kinds.size()))
		# Ausziehtisch: Rundenziel doppelt übertroffen -> die Warteschlange
		# wächst dauerhaft um einen Platz (siehe _queue_capacity).
		if ids.has(Charm.EXTENSION_TABLE) and hand_total >= run.round_goal * 2:
			run.queue_bonus_slots += 1
		await _play_round_clear_payout(blind, per_die)
		if phase != Phase.PAYOUT:
			return  # Spiel wurde während der Auszahlungs-Animation zurückgesetzt
		# Rundenende-Geld der Effektkatalog-Charms: Zinsgroschen (auf den Stand
		# NACH der Auszahlung, max. $50) und Überflieger (max. $50) - danach
		# hält der Notgroschen den Mindeststand ($25).
		var extra := CharmEffects.round_end_income(run.money, hand_total - run.round_goal, ids)
		if extra > 0:
			run.add_money(extra)
			_pulse_money_label()
			_show_money_popup(extra)
		var floor_value := CharmEffects.money_floor(ids)
		if run.money < floor_value:
			run.money = floor_value
		phase = Phase.SHOP
		_set_gameplay_ui_visible(false)
		# Der Shop übernimmt die Hub-Fläche auf dem Display: Hub-Inhalt weg,
		# Shop auf, Kamera auf den Hub (dort läuft die Maus-Weiterleitung).
		if table_screen.hub != null:
			table_screen.hub.set_content_visible(false)
		charm_shop.open()
		camera_rig.zoom_to(CameraRig.Mode.HUB)
	else:
		phase = Phase.GAME_OVER
		_show_game_over(hand_total)

## Lässt die beiden Rundenbonus-Zeilen im Hub (siehe HubView.blind_payout_label/
## die_payout_label) nacheinander golden aufleuchten, synchron zur tatsächlichen
## Gutschrift: erst der Fixbetrag blind, dann - falls noch Würfel im Pool übrig
## sind - je per_die pro übrigem Würfel, während die betroffenen Würfel in
## Warteschlangen- und Pool-Tray im selben Takt mit aufleuchten (siehe
## _unused_die_entries). blind und per_die kommen schon inklusive Charm-Boni
## herein (siehe _on_round_complete). Die Auszahlung folgt der wahren Anzahl
## übriger Würfel (_remaining_in_pool), auch falls mehr Würfel übrig sind, als
## das Pool-Tray anzeigen kann - dann zahlen die überzähligen ohne eigenes
## Aufblitzen.
func _play_round_clear_payout(blind: int, per_die: int) -> void:
	# Die ganze Zählsequenz läuft unfokussiert in der Übersicht: Hub (mit den
	# Bonus-Zeilen), Geldanzeige und beide Trays sind gleichzeitig im Bild, statt
	# auf ein einzelnes Element zu fokussieren. Am Ende geht es zurück in die
	# Grubensicht, damit nach dem Shop die normale Spielansicht steht.
	camera_rig.zoom_out()
	await get_tree().create_timer(CameraRig.ZOOM_DURATION).timeout

	var hub := table_screen.hub
	await _light_up_payout_label(hub.blind_payout_label if hub != null else null)
	run.add_money(blind)
	_pulse_money_label()
	_show_money_popup(blind)
	await get_tree().create_timer(PAYOUT_TEXT_HOLD_DURATION).timeout
	_fade_payout_label(hub.blind_payout_label if hub != null else null)

	var remaining := _remaining_in_pool()
	if remaining > 0:
		await _light_up_payout_label(hub.die_payout_label if hub != null else null)
		var die_entries := _unused_die_entries()
		for i in remaining:
			if i < die_entries.size():
				_flash_die_tint(die_entries[i]["display"], die_entries[i]["tint"])
			run.add_money(per_die)
			_pulse_money_label()
			_show_money_popup(per_die)
			await get_tree().create_timer(DIE_PAYOUT_STEP_INTERVAL).timeout
		_fade_payout_label(hub.die_payout_label if hub != null else null)
	# Wohin es nach dem Auszählen geht, entscheidet der Aufrufer (der Shop
	# zoomt auf den Hub, siehe _on_round_complete).

## Alle Würfel-Anzeigen, die gerade einen noch nicht gezogenen Würfel dieser
## Runde zeigen - Warteschlangen-Tray zuerst, dann Pool-Tray, in genau der
## Reihenfolge, in der sie als Nächstes gezogen würden (siehe
## _refresh_deck_trays). Zusammen genau _remaining_in_pool() Einträge.
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

## Blendet eine Rundenbonus-Zeile im Hub von ihrer aktuellen Farbe auf Gold auf
## und lässt sie dabei leicht aufplustern - wartet, bis das fertig ist (siehe
## _play_round_clear_payout, das die eigentliche Gutschrift danach auslöst).
## null-tolerant (kein Screen-Mesh -> kein Hub): dann nur die Flash-Zeit warten,
## damit der Auszahlungs-Takt gleich bleibt.
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

## Blendet eine Rundenbonus-Zeile zurück in ihre gedämpfte Ruhefarbe - läuft im
## Hintergrund weiter, blockiert die aufrufende Animation also nicht.
func _fade_payout_label(label: Label) -> void:
	if label == null:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(c: Color) -> void: label.modulate = c, label.modulate, PAYOUT_LABEL_BASE_COLOR, PAYOUT_FLASH_DURATION)
	tween.tween_property(label, "scale", Vector2.ONE, PAYOUT_FLASH_DURATION)

## Lässt einen einzelnen Würfel beim Auszahlen aufblitzen: sehr schneller
## Anstieg (ease-out) auf überstrahltes Gold plus Größen-Pop, danach deutlich
## langsameres Abklingen (ease-out = schneller Abfall mit sanftem Ausläufer,
## wie ein echtes Aufblitzen) zurück zu Stilfarbe und Normalgröße. Läuft im
## Hintergrund weiter, damit sich aufeinanderfolgende Würfel in
## _play_round_clear_payout wie eine Welle überlappen statt zu warten.
func _flash_die_tint(display: DieFaceDisplay, original_tint: Color, base_scale: Vector3 = Vector3.ONE) -> void:
	var tint_tween := create_tween()
	tint_tween.tween_method(display.set_tint, original_tint, DIE_FLASH_PEAK_COLOR, DIE_FLASH_RAMP_UP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tint_tween.tween_method(display.set_tint, DIE_FLASH_PEAK_COLOR, original_tint, DIE_FLASH_RAMP_DOWN) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# base_scale = Ruhegröße der Anzeige (die Grubenwürfel sind auf Tray-Größe
	# skaliert, siehe _ready - Tray-Slots bleiben bei 1).
	var scale_tween := create_tween()
	scale_tween.tween_property(display, "scale", base_scale * DIE_FLASH_SCALE, DIE_FLASH_RAMP_UP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(display, "scale", base_scale, DIE_FLASH_RAMP_DOWN) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_debug_win_round_pressed() -> void:
	if not _is_playing():
		return
	hand_total = run.round_goal
	_on_round_complete()  # setzt die Phase - stoppt damit auch einen laufenden Wurf

## Steuert die Sichtbarkeit der Spiel-UI (Text + Würfel-Buttons) anhand des
## Spielzustands (false während Shop/GameOver) - kombiniert mit dem
## Kamera-Fokus (siehe _on_camera_mode_changed) in _update_gameplay_ui_visibility.
func _set_gameplay_ui_visible(is_visible: bool) -> void:
	gameplay_ui_state_visible = is_visible
	_update_gameplay_ui_visibility()

func _on_camera_mode_changed(new_mode: CameraRig.Mode) -> void:
	is_pit_focused = new_mode == CameraRig.Mode.PIT
	_update_gameplay_ui_visibility()
	_update_queue_tray_dock()

## Lässt das Warteschlangen-Tray zur Grube andocken, sobald die Kamera dorthin
## zoomt (siehe QUEUE_TRAY_PIT_POSITION), und wieder zurück an seinen
## Normalplatz, sobald sie das nicht mehr tut - so ist immer sichtbar, welche
## Würfel als Nächstes geworfen werden, ohne aus der Grube heraus zoomen zu
## müssen.
func _update_queue_tray_dock() -> void:
	var target := QUEUE_TRAY_PIT_POSITION if is_pit_focused else queue_tray_home_position
	if queue_tray_tween:
		queue_tray_tween.kill()
	queue_tray_tween = create_tween()
	queue_tray_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	queue_tray_tween.tween_property(queue_tray_view, "position", target, QUEUE_TRAY_MOVE_DURATION)

## UI-Text und Würfeln/Nehmen-Buttons sind nur sichtbar, wenn die Kamera auf
## die Grube fokussiert ist UND der Spielzustand sie erlaubt (nicht während
## Shop/GameOver).
func _update_gameplay_ui_visibility() -> void:
	var show_ui := gameplay_ui_state_visible and is_pit_focused
	hand_label.visible = show_ui
	round_hud.visible = show_ui
	take_button.visible = show_ui
	select_all_button.visible = show_ui

# --- Reaktionen auf Shop/Gravur-Station --------------------------------------
# Käufe und Coupon-Verbrauch mutieren den GameRun direkt (ShopController.run /
# DieInspectorView.run); die HUD-Anzeigen folgen über die Run-Signale (siehe
# _connect_run). Hier stehen nur noch die Reaktionen, die echte Szenen-Arbeit
# brauchen (Trays neu zeichnen, Rundenwechsel).

## Eine Ätzung wurde in der Gravur-Station angewandt (siehe DieInspectorView):
## die faces des Pool-Würfels sind bereits verändert, hier nur die Tray-Anzeigen
## neu zeichnen (slot_defs teilen die Instanz, siehe refresh_faces).
func _on_die_engraved() -> void:
	pool_tray_view.refresh_faces()
	queue_tray_view.refresh_faces()
	discard_tray_view.refresh_faces()

## Der Shop wurde mit "Fertig" geschlossen (er blendet sich selbst aus): der Hub
## zeigt wieder seine Lauf-Übersicht, die Kamera kehrt in die Grubensicht zurück,
## nächste Runde vorbereiten.
func _on_shop_closed() -> void:
	if table_screen.hub != null:
		table_screen.hub.set_content_visible(true)
	run.advance_round()
	phase = Phase.IDLE
	_set_gameplay_ui_visible(true)
	camera_rig.zoom_to(CameraRig.Mode.PIT)
	_start_new_round()

func _show_game_over(total: int) -> void:
	game_over_label.text = "Ziel verfehlt: %d / %d Punkte.\nSpiel vorbei – klicke 'Neues Spiel' zum Neustart." % [total, run.round_goal]
	_set_gameplay_ui_visible(false)
	game_over_panel.visible = true

func _refresh_ui() -> void:
	_refresh_round_hud()

	if not has_rolled_current_hand:
		hand_label.text = hand_note if hand_note != "" else "Klicke den Würfelbecher zum Würfeln"
		_refresh_combos("")
		if phase != Phase.SCORING:
			table_screen.update_pit_score(0, 0)  # Daueranzeige in Ruhestellung
	else:
		# Keine Punkte-Vorschau mehr im HUD-Text: Die Dauerzahlen über der Grube
		# zeigen die Kombination (Basispunkte × Mult inkl. Menü-Stufen) der aktuell
		# AUSGEWÄHLTEN Würfel (siehe _scoring_slots) - sie springen sofort mit,
		# sobald der Spieler per Klick um-/abwählt, und die Zähl-Animation beim
		# Nehmen zählt darauf weiter. Nichts ausgewählt = keine Hand (0 / 0).
		hand_label.text = ""
		var slots := _scoring_slots()
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

## Aktualisiert die statischen Teile der Runden-Anzeige (Rundenzahl, Balken-
## Obergrenze) - der aktuell gezeigte Punktestand läuft separat und animiert
## über _animate_points_to, damit ein Zuwachs sichtbar hochzählt statt zu
## springen. Harmlos, auch wenn mehrfach ohne echte Änderung aufgerufen (siehe
## _refresh_ui - läuft nach jedem Wurf, nicht nur bei neuer Punktzahl).
func _refresh_round_hud() -> void:
	round_badge_label.text = "Runde %d" % run.round_number
	points_bar.max_value = run.round_goal
	# Der Zielbalken auf dem Tisch-Display zeigt dasselbe (z.B. neues Rundenziel
	# nach dem Shop, auch ohne Punktänderung); die Hub-Übersicht läuft mit.
	table_screen.set_goal_progress(displayed_points, run.round_goal)
	_refresh_hub_info()

## Lässt die Punkteanzeige (Balken + Zahl) von ihrem aktuell gezeigten Wert
## sichtbar zu target hochzählen (Balatro-artiger "Chips fliegen rein"-Effekt)
## statt sofort zu springen - inklusive kurzem Aufplustern des Zahlentexts bei
## einem Zuwachs (siehe _pulse_points_label). animate=false für den harten
## Rundenreset auf 0 (siehe _start_new_round), da dort nichts "erspielt" wurde.
func _animate_points_to(target: int, animate: bool = true) -> void:
	if points_tween:
		points_tween.kill()
	if not animate:
		_set_displayed_points(target)
		return
	var gained := target > displayed_points
	points_tween = create_tween()
	points_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	points_tween.tween_method(_set_displayed_points, displayed_points, target, 0.6)
	if gained:
		_pulse_points_label()

func _set_displayed_points(value: int) -> void:
	displayed_points = value
	points_bar.value = value
	points_label.text = "%d / %d Punkte" % [value, run.round_goal]
	table_screen.set_goal_progress(value, run.round_goal)  # Display-Balken läuft synchron mit

## Kurzes elastisches Aufplustern des Punktetexts, sobald sich der Stand
## erhöht - kleiner "Arcade-Pop", der einen Punktezuwachs zusätzlich zum
## Hochzählen spürbar macht.
func _pulse_points_label() -> void:
	points_label.pivot_offset = points_label.size / 2.0
	points_label.scale = Vector2(1.35, 1.35)
	var pulse := create_tween()
	pulse.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(points_label, "scale", Vector2.ONE, 0.4)
