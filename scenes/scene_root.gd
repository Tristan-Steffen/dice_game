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

const MONEY_PER_ROUND_CLEAR := 5  # Belohnung fürs Rundenziel-Erreichen (einmalig, nicht pro Hand), siehe _on_round_complete
const MONEY_PER_UNUSED_DIE := 1  # Bonus je noch nicht gezogenem Würfel im Rundenpool beim Rundenziel-Erreichen, siehe _on_round_complete/_remaining_in_pool

## Auszahlungs-Animation der beiden Tisch-Texte (siehe blind_payout_label3d/
## dice_payout_label3d, _play_round_clear_payout) - PAYOUT_FLASH_DURATION ist
## die Zeit zum Auf-/Abblenden ins/aus dem Gold, PAYOUT_TEXT_HOLD_DURATION die
## Pause, in der der Blind-Text golden stehen bleibt, bevor die Würfel dran
## sind, und DIE_PAYOUT_STEP_INTERVAL der Takt, in dem die Würfel nacheinander
## mit aufleuchten.
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

## Kantenlänge (Pixel) der Mini-3D-Würfelvorschau je Zeile der Würfel-Sammlung.
const DICE_THUMB_SIZE := 72

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
## Ruhefarbe der Tisch-Texte (Belohnungen UND Kombinationsliste): helles Weiß mit
## schwarzem Umriss (siehe .tscn: outline_modulate). Beim Aufleuchten (Auszahlung
## bzw. gerade gewürfelte Kombination) wechseln sie nach CasinoStyle.GOLD_INTENSE.
const PAYOUT_LABEL_BASE_COLOR := Color(0.96, 0.96, 0.93)

## Position, an die das Warteschlangen-Tray andockt, solange die Kamera auf
## die Grube fokussiert ist: knapp vor deren Südrand, mittig - am unteren
## Bildschirmrand der gezoomten Grubenansicht, da Welt-X = Bildschirm-oben
## und Welt-Z = Bildschirm-rechts gilt (siehe CameraRig.ZOOM_BASIS). Empirisch
## getroffen (siehe scenes/dice_tray.tscn für die Kollisions-Maße der Grube;
## das sichtbare Tischmodell ist größer als diese Kollisionsboxen). Danach
## zieht sich das Tray wieder an seinen Normalplatz neben dem Pool-Tray zurück
## (siehe _update_queue_tray_dock).
const QUEUE_TRAY_PIT_POSITION := Vector3(-13.0, 0.0, 0.0)
const QUEUE_TRAY_MOVE_DURATION := 0.6

const DECK_SHIFT_DURATION := 0.45  # Aufrück-Animation der Deck-Würfel nach einem Wurf, siehe _animate_deck_shift

const REORDER_DRAG_THRESHOLD := 6.0  # Pixel, ab wann ein Klick auf einen Warteschlangen-Würfel als Zieh-Geste zählt
const REORDER_LIFT_HEIGHT := 0.8  # Wie weit der gezogene Würfel über das Tray angehoben wird
const REORDER_DROP_RADIUS := 140.0  # Pixel-Toleranz beim Loslassen, siehe _nearest_queue_slot

const CUP_FLY_DURATION := 0.4  # wie lange die gezogenen Würfel zum Becher fliegen, siehe _play_cup_roll
const CUP_SHAKE_COUNT := 3  # wie oft der Becher vor dem Ausschütten wackelt, siehe DiceCup.play_shake

## Wo geschützte (ausgewählte, noch nicht genommene) Würfel beim nächsten Wurf
## hingleiten (siehe _pit_top_row_position/_play_cup_roll): eine mittig
## zentrierte Reihe am oberen Rand der Grube (Welt-X positiv = Bildschirm-oben,
## siehe QUEUE_TRAY_PIT_POSITION), innerhalb der elliptischen Grubenwand
## (Halbachse 10.5, siehe scripts/dice_tray.gd) mit Sicherheitsabstand zur Wand.
const PIT_TOP_ROW_X := 7.0
const PIT_TOP_ROW_SPACING := 2.4

## Grobe Spielphase - genau EINE zur Zeit (ersetzt die frühere Kombination aus
## game_state + is_rolling + is_cup_animating, deren Konjunktionen an jeder
## Eingabe-Stelle einzeln stimmen mussten). Eingabe-Gates prüfen gegen die Phase
## (siehe _can_toggle_selection/_dice_in_motion/_is_playing): IDLE = wartet auf
## Spieler-Eingabe · CUP_ANIMATING = gezogene Würfel fliegen zum Becher, er
## schüttelt und kippt · ROLLING = Physikwurf läuft · PAYOUT = Rundenziel-
## Auszahlung (Tisch-Animation vor dem Shop) · SHOP/GAME_OVER = entsprechendes
## Panel offen. Nebenläufige Kosmetik (Deck-Aufrücken, Umsortier-Drag,
## Bogen-Abschluss) ist bewusst KEINE Phase - sie hat ihre eigenen kleinen
## Zustände (deck_shift_ghosts/reorder_drag_index/sheet_animating) und darf
## parallel zu einer Phase laufen.
enum Phase { IDLE, CUP_ANIMATING, ROLLING, PAYOUT, SHOP, GAME_OVER }

@onready var take_button: Button = $UI/TakeButton
@onready var select_all_button: Button = $UI/SelectAllButton
@onready var settings_menu: VBoxContainer = $UI/SettingsMenu
@onready var settings_toggle_button: Button = $UI/SettingsToggleButton
@onready var reset_button: Button = $UI/SettingsMenu/ResetButton
@onready var debug_win_round_button: Button = $UI/SettingsMenu/DebugWinRoundButton
@onready var round_hud: Control = $UI/RoundHud
@onready var round_badge_label: Label = $UI/RoundHud/RoundBadgeLabel
@onready var points_bar: ProgressBar = $UI/RoundHud/PointsBar
@onready var points_label: Label = $UI/RoundHud/PointsBar/PointsLabel
@onready var hand_label: Label = $UI/HandLabel
@onready var charms_label: Label = $UI/CharmsLabel
@onready var money_label: Label = $UI/MoneyLabel
@onready var coupons_label: Label = $UI/CouponsLabel

## Der Shop ist ein eigenständiger Controller auf dem ShopPanel (siehe
## ShopController) - scene_root spricht ihn nur über charm_shop.open() an,
## reicht ihm den laufenden GameRun (run) herein und reagiert auf sein
## closed-Signal.
@onready var charm_shop: ShopController = $UI/ShopPanel

@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/VBoxContainer/GameOverLabel
@onready var game_over_reset_button: Button = $UI/GameOverPanel/VBoxContainer/GameOverResetButton

@onready var die_inspector: DieInspectorView = $UI/DieInspectorView

@onready var legend_toggle_button: Button = $UI/LegendToggleButton
@onready var legend_panel: Panel = $UI/LegendPanel
@onready var legend_content_label: Label = $UI/LegendPanel/Margin/LegendContentLabel

## Öffnet die Würfel-Sammlung (siehe _on_dice_list_toggle_pressed) - alle Würfel
## des Pools, nach Augensumme sortiert, mit Mini-Vorschau + Seiten-Übersicht.
@onready var dice_list_toggle_button: Button = $UI/DiceListToggleButton
var dice_list_panel: Panel  # komplett per Code aufgebaut (siehe _build_dice_list_panel)
var dice_list_rows: VBoxContainer  # Zeilencontainer; bei jedem Öffnen neu befüllt

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

@onready var blind_payout_label3d: Label3D = $BlindPayoutLabel3D
@onready var dice_payout_label3d: Label3D = $DicePayoutLabel3D
## Anker der Tisch-Kombinationsliste (Position/Ausrichtung/Größe) - die 13
## Zeilen-Labels sind feste Kinder in der Szene, je nach DiceScoring-Key benannt
## (siehe _collect_combo_labels). Der Anker selbst rendert nichts (Text leer).
@onready var combos_anchor: Label3D = $Combinations

var combo_labels: Dictionary = {}  # DiceScoring-key -> Label3D (eine Zeile der Tischliste)
var highlighted_combo_key: String = ""  # gerade golden hervorgehobene Kombination (siehe _refresh_combos)

@onready var camera_rig: CameraRig = $Camera3D
@onready var pit_click_zone: StaticBody3D = $DiceTray/PitClickZone
@onready var charm_row: CharmRowView = $Charms

var dice: DiceController

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
var hand_note: String = ""  # transiente Meldung (z.B. Farkle) für die Pause zwischen Händen

var gameplay_ui_state_visible: bool = true  # true während PLAYING, false während Shop/GameOver
var is_pit_focused: bool = false  # true, solange die Kamera auf die Würfelgrube gezoomt ist

var queue_tray_home_position: Vector3  # Normalplatz neben dem Pool-Tray, siehe _ready
var queue_tray_tween: Tween

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
	Vector3(6.5458, 13.695267, 7.7658),
	Vector3(3.2886, 13.695267, 6.7886),
	Vector3(0.0314, 13.695267, 5.8115),
	Vector3(-3.2258, 13.695267, 4.8343),
	Vector3(-6.4830, 13.695267, 3.8572),
	Vector3(-9.7402, 13.695267, 2.8800),
]

func _ready() -> void:
	var roots: Array[Node3D] = []
	var bodies: Array[RigidBody3D] = []
	var face_displays: Array[DieFaceDisplay] = []
	for i in DICE_START_POSITIONS.size():
		var die := DieBuilder.build()
		$Dice.add_child(die)
		die.position = DICE_START_POSITIONS[i]
		roots.append(die)
		bodies.append(die.get_node("RigidBody3D"))
		face_displays.append(die.get_node("RigidBody3D/Faces"))
	dice = DiceController.new(roots, bodies, face_displays)

	queue_tray_home_position = queue_tray_view.position

	charm_shop.closed.connect(_on_shop_closed)
	die_inspector.changed.connect(_on_die_engraved)
	debug_win_round_button.pressed.connect(_on_debug_win_round_pressed)
	camera_rig.mode_changed.connect(_on_camera_mode_changed)
	legend_toggle_button.pressed.connect(_on_legend_toggle_pressed)
	dice_list_toggle_button.pressed.connect(_on_dice_list_toggle_pressed)
	settings_toggle_button.pressed.connect(_on_settings_toggle_pressed)

	_style_ui()
	_populate_legend()
	_collect_combo_labels()
	_build_dice_list_panel()
	_build_sheet_preview()
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
	CasinoStyle.style_body_label(charms_label, 15, CasinoStyle.PURPLE)
	CasinoStyle.style_body_label(coupons_label, 15, CasinoStyle.GREEN)
	CasinoStyle.style_chip_label(money_label, 20, CasinoStyle.GOLD)

	CasinoStyle.style_button(take_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK)
	CasinoStyle.style_button(select_all_button, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK)
	CasinoStyle.style_button(legend_toggle_button, CasinoStyle.GREEN, CasinoStyle.GREEN_DARK, 16)
	CasinoStyle.style_button(dice_list_toggle_button, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, 16)
	CasinoStyle.style_button(settings_toggle_button, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, 16)
	CasinoStyle.style_button(reset_button, CasinoStyle.RED, CasinoStyle.RED_DARK, 16)
	CasinoStyle.style_button(debug_win_round_button, CasinoStyle.BLUE, CasinoStyle.BLUE_DARK, 14)
	CasinoStyle.style_button(game_over_reset_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK)

	CasinoStyle.style_panel(game_over_panel)
	CasinoStyle.style_panel(legend_panel)

	CasinoStyle.style_score_label(game_over_label, 24)
	CasinoStyle.style_body_label(legend_content_label, 15)
	# Der Shop stylt sich selbst (siehe ShopController._ready).

## Klappt die Einstellungsleiste unten rechts (Neues Spiel / Debug) auf/zu.
func _on_settings_toggle_pressed() -> void:
	settings_menu.visible = not settings_menu.visible

## Klappt die Kombinationen-Übersicht auf/zu (siehe LegendToggleButton).
func _on_legend_toggle_pressed() -> void:
	legend_panel.visible = not legend_panel.visible
	if legend_panel.visible:
		dice_list_panel.visible = false  # nicht beide rechten Panels gleichzeitig

## Klappt die Würfel-Sammlung auf/zu (siehe DiceListToggleButton). Beim Öffnen
## wird die Liste frisch aus owned_pool gebaut (bildet Käufe/Ätzungen ab); beim
## Schließen werden die Zeilen samt ihrer Mini-Vorschau-Viewports wieder
## freigegeben, damit im Hintergrund nichts weiterrendert.
func _on_dice_list_toggle_pressed() -> void:
	dice_list_panel.visible = not dice_list_panel.visible
	if dice_list_panel.visible:
		legend_panel.visible = false
		_rebuild_dice_list()
	else:
		_clear_dice_list()

## Gibt alle Zeilen der Würfel-Sammlung frei (siehe _on_dice_list_toggle_pressed).
func _clear_dice_list() -> void:
	for child in dice_list_rows.get_children():
		child.queue_free()

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
func _show_sheet_reveal(sheet: CouponSheet, kind: int) -> void:
	sheet_preview_title.text = "%s (%d×%d)" % [_sheet_kind_name(kind), sheet.cols, sheet.rows]
	sheet_preview_view.show_sheet(sheet, 120.0)
	sheet_preview.visible = true

func _sheet_kind_name(kind: int) -> String:
	match kind:
		CouponSheet.Kind.SNIPPET:
			return "Schnipsel"
		CouponSheet.Kind.SHEET:
			return "Bogen"
		CouponSheet.Kind.LARGE:
			return "Großbogen"
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
	var last_end := 0.0
	for idx in views.size():
		var view: CouponSheetView.TileView = views[idx]
		var node: Control = view.node
		var home := node.position + node.size * 0.5
		var out_dir := (home - center).normalized() if home.distance_to(center) > 1.0 else Vector2.UP
		var scattered := node.position + out_dir * 46.0
		var delay := idx * SHEET_ANIM_STAGGER

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
func _grant_chip_coupon() -> void:
	run.add_money(CHIP_COUPON_VALUE)
	_pulse_money_label()

## Eine Ätzung ist an ihrem Zähler angekommen: ins Inventar legen (die
## HUD-Coupon-Zeile aktualisiert sich über run.coupons_changed), Zähler
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

## Baut Rahmen der Würfel-Sammlung einmalig auf (Panel + Titel + scrollbare
## Zeilenliste). Die Zeilen selbst füllt _rebuild_dice_list bei jedem Öffnen neu.
func _build_dice_list_panel() -> void:
	dice_list_panel = Panel.new()
	dice_list_panel.visible = false
	dice_list_panel.offset_left = 812.0
	dice_list_panel.offset_top = 64.0
	dice_list_panel.offset_right = 1256.0
	dice_list_panel.offset_bottom = 726.0
	CasinoStyle.style_panel(dice_list_panel)
	$UI.add_child(dice_list_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0
	vbox.offset_top = 14.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -14.0
	vbox.add_theme_constant_override("separation", 10)
	dice_list_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Würfel-Sammlung"
	CasinoStyle.style_score_label(title, 22, CasinoStyle.GOLD)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	dice_list_rows = VBoxContainer.new()
	dice_list_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_list_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(dice_list_rows)

## Befüllt die Würfel-Sammlung neu: eine Zeile pro Pool-Würfel, absteigend nach
## Augensumme (die "eyes-reichsten" oben). Alte Zeilen werden vorher freigegeben
## (samt ihrer Mini-Vorschau-Viewports).
func _rebuild_dice_list() -> void:
	for child in dice_list_rows.get_children():
		child.queue_free()
	var sorted := run.owned_pool.duplicate()
	sorted.sort_custom(func(a: DieDefinition, b: DieDefinition) -> bool: return _die_eye_total(a) > _die_eye_total(b))
	for def in sorted:
		dice_list_rows.add_child(_build_die_row(def))

## Augensumme (Summe aller Seiten) eines Würfels - Sortier- und Anzeigewert.
func _die_eye_total(def: DieDefinition) -> int:
	var total := 0
	for value in def.faces:
		total += value
	return total

## Eine Zeile der Sammlung: Mini-3D-Vorschau des Würfels, seine Augensumme und
## die Seiten-Übersicht (je vorkommender Wert ein Chip mit ×Anzahl, wie im
## Würfel-Inspektor).
func _build_die_row(def: DieDefinition) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var row_box := StyleBoxFlat.new()
	row_box.bg_color = Color(1, 1, 1, 0.05)
	row_box.set_corner_radius_all(8)
	row_box.set_content_margin_all(8)
	row_panel.add_theme_stylebox_override("panel", row_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row_panel.add_child(row)

	row.add_child(_build_die_thumb(def))

	var total_label := Label.new()
	total_label.text = "%d" % _die_eye_total(def)
	total_label.custom_minimum_size = Vector2(52, 0)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CasinoStyle.style_score_label(total_label, 26, CasinoStyle.GOLD)
	row.add_child(total_label)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var counts := {}
	for value in def.faces:
		counts[value] = counts.get(value, 0) + 1
	var values := counts.keys()
	values.sort()
	for value in values:
		chips.add_child(_build_collection_chip(value, counts[value]))
	row.add_child(chips)
	return row_panel

## Kleiner Seiten-Chip für die Sammlung (weiß, abgerundet, dunkle Ziffer, im Look
## der echten Würfel); count > 1 hängt ein "×N" an. Rein informativ (kein Klick).
func _build_collection_chip(value: int, count: int) -> Control:
	var chip := Label.new()
	chip.text = "%d" % value if count == 1 else "%d ×%d" % [value, count]
	chip.custom_minimum_size = Vector2(34, 34)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_font_size_override("font_size", 18)
	chip.add_theme_color_override("font_color", CasinoStyle.INK)
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.border_color = Color(0.72, 0.76, 0.8)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(5)
	chip.add_theme_stylebox_override("normal", box)
	return chip

## Kleine statische 3D-Vorschau eines Würfels für die Sammlung (eigener
## SubViewport, rendert dank UPDATE_ONCE nur ein Bild und kostet danach nichts).
## Baut denselben Würfel wie überall (DieBuilder) und stellt ihn schräg dar.
func _build_die_thumb(def: DieDefinition) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(DICE_THUMB_SIZE, DICE_THUMB_SIZE)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(DICE_THUMB_SIZE, DICE_THUMB_SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-50, 35, 0)
	key_light.light_energy = 1.1
	viewport.add_child(key_light)

	var camera := Camera3D.new()
	camera.fov = 30.0
	# looking_at als reine Transform-Mathematik statt camera.look_at, das den
	# Knoten schon im Baum bräuchte (hier wird der Würfel noch losgelöst gebaut).
	camera.transform = Transform3D(Basis(), Vector3(0, 2.6, 5.4)).looking_at(Vector3.ZERO, Vector3.UP)
	viewport.add_child(camera)

	var die := DieBuilder.build()
	viewport.add_child(die)
	die.rotation_degrees = Vector3(-20, 30, 0)
	var body: RigidBody3D = die.get_node("RigidBody3D")
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	faces.apply_definition(def)
	faces.set_tint(DiceController.KIND_TINTS.get(def.style_id, Color.WHITE))
	return container

## Baut den Text der Legende einmalig aus DiceScoring.CATEGORIES auf –
## von der prestigeträchtigsten zur schwächsten Hand (siehe HAND_PRIORITY),
## damit die Anzeige immer zur tatsächlichen Wertungslogik passt.
func _populate_legend() -> void:
	var lines: Array[String] = ["Kombinationen (Basis × Mult):"]
	for key in DiceScoring.HAND_PRIORITY:
		var label: String = DiceScoring.label_for(key)
		var mult: int = DiceScoring.mult_for(key)
		lines.append("%s  ×%d" % [label, mult])
	legend_content_label.text = "\n".join(lines)

## Sammelt die fest in der Szene angelegten Kombinations-Labels (Kinder des
## Combinations-Ankers, je nach DiceScoring-Key benannt) in combo_labels ein,
## damit _refresh_combos genau die gewürfelte Hand aufleuchten lassen kann.
## Die Labels selbst (Text, Größe, Umriss, Position) pflegt man in der Szene.
func _collect_combo_labels() -> void:
	for key in DiceScoring.HAND_PRIORITY:
		var node: Node = combos_anchor.get_node_or_null(NodePath(key))
		if node is Label3D:
			combo_labels[key] = node
		else:
			push_warning("Kombinations-Label fehlt in der Szene: Combinations/%s" % key)

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
		_tween_combo_label(combo_labels[active_key], CasinoStyle.GOLD_INTENSE, 1.18)

## Blendet eine Kombinationszeile weich in Farbe/Größe (Aufleuchten oder zurück
## in die Ruhefarbe) - gleiche Dauer wie die Belohnungstexte (PAYOUT_FLASH_DURATION).
func _tween_combo_label(label: Label3D, color: Color, target_scale: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate", color, PAYOUT_FLASH_DURATION)
	tween.tween_property(label, "scale", Vector3.ONE * target_scale, PAYOUT_FLASH_DURATION)

## Der Charm-Besitz hat sich geändert (siehe run.charms_changed): 2D-Namensliste
## und physische Tisch-Charms gemeinsam aktualisieren.
func _on_charms_changed() -> void:
	_refresh_charms_label()
	charm_row.set_charms(run.owned_charms)

## Aktualisiert die Charm-Anzeige (Namen, durch Komma getrennt) - rein
## informativ, damit besessene Charms beim Testen sichtbar sind.
func _refresh_charms_label() -> void:
	if run.owned_charms.is_empty():
		charms_label.text = "Keine Charms"
		return
	var names: Array[String] = []
	for charm in run.owned_charms:
		names.append(charm.display_name)
	charms_label.text = "Charms: %s" % ", ".join(names)

## Aktualisiert die Coupon-Anzeige (siehe run.coupons_changed) - gleiche Coupons
## werden als "Name ×Anzahl" zusammengefasst, da man beliebig viele horten kann.
func _refresh_coupons_label() -> void:
	if run.owned_coupons.is_empty():
		coupons_label.text = "Keine Coupons"
		return
	var counts := {}
	var order: Array[String] = []  # erste Auftrittsreihenfolge beibehalten
	for coupon in run.owned_coupons:
		if not counts.has(coupon.display_name):
			counts[coupon.display_name] = 0
			order.append(coupon.display_name)
		counts[coupon.display_name] += 1
	var parts: Array[String] = []
	for name in order:
		var count: int = counts[name]
		parts.append("%s ×%d" % [name, count] if count > 1 else name)
	coupons_label.text = "Coupons: %s" % ", ".join(parts)

## Der Geldstand hat sich geändert (siehe run.money_changed) - jede Gutschrift
## und jeder Kauf laufen über GameRun, die Anzeige folgt hier automatisch.
func _on_money_changed(new_money: int) -> void:
	money_label.text = "$%d" % new_money

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

func _unhandled_input(event: InputEvent) -> void:
	if reorder_drag_index != -1:
		_handle_reorder_input(event)
		return

	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		camera_rig.zoom_out()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if is_pit_focused and _try_cup_click(event.position):
		return

	if _can_toggle_selection():
		var index := _pick_die_index(event.position)
		if index != -1:
			dice.set_selected(index, not dice.selected[index])
			_refresh_action_buttons()
			return

	if not _dice_in_motion() and deck_shift_ghosts.is_empty() and _try_start_queue_reorder(event.position):
		return

	if not _dice_in_motion() and _try_tray_die_click(event.position):
		return

	_try_zoom_click(event.position)

## Klick auf einen einzelnen (sichtbaren) Würfel im GERADE FOKUSSIERTEN Tray
## (Layer 16, siehe DiceTrayView.SLOT_PICK_LAYER) - öffnet die freie 3D-
## Vorschau (DieInspectorView) für genau diesen Würfel. Erst wenn die Kamera
## bereits auf das jeweilige Tray gezoomt ist (camera_rig.mode), lässt sich so
## ein Würfel darin anklicken - ein Klick davor löst stattdessen ganz normal
## den Zoom aus (siehe _try_zoom_click). Ohne diese Gate wäre ein Würfel
## theoretisch schon aus der Übersicht per Raycast treffbar, auch wenn er auf
## dem Bildschirm winzig ist.
## Das Warteschlangen-Tray läuft NICHT mehr über diese Funktion - dort
## entscheidet _try_start_queue_reorder/_handle_reorder_input zwischen Klick
## (öffnet ebenfalls die Vorschau) und Zieh-Geste (sortiert um).
func _try_tray_die_click(screen_pos: Vector2) -> bool:
	var candidate_trays: Array[DiceTrayView] = []
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
			die_inspector.show_die(target_tray.slot_defs[index])
			return true
	return false

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
			die_inspector.show_die(queue_tray_view.slot_defs[reorder_drag_index])
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

## Klick auf die Würfelgrube oder eines der Trays (Layer 4) -> Kamera fährt
## näher heran. Läuft unabhängig vom Halten-Klick auf Würfel (Layer 2).
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
		camera_rig.zoom_to(CameraRig.Mode.PIT)
	elif collider == pool_tray_view.click_zone or collider == queue_tray_view.click_zone:
		camera_rig.zoom_to(CameraRig.Mode.POOL)
	elif collider == discard_tray_view.click_zone:
		camera_rig.zoom_to(CameraRig.Mode.DISCARD)

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

func _remaining_in_pool() -> int:
	return round_pool_kinds.size() - next_draw_index

func _draw_one() -> DieDefinition:
	var def: DieDefinition = round_pool_kinds[next_draw_index]
	next_draw_index += 1
	return def

## Schickt einen einzelnen gebrauchten Würfel ins Ablage-Tray.
func _discard_kind(def: DieDefinition) -> void:
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
	queue_window_size = min(HAND_SIZE, _remaining_in_pool())
	var queue_defs := round_pool_kinds.slice(next_draw_index, next_draw_index + queue_window_size)
	queue_tray_view.fill(queue_defs)
	var pool_start := next_draw_index + HAND_SIZE
	pool_tray_view.fill(round_pool_kinds.slice(pool_start, round_pool_kinds.size()))

## Weltposition, an der der Deck-Eintrag deck_index angezeigt wird, wenn der
## Zieh-Cursor bei cursor steht: die ersten HAND_SIZE Einträge nach dem Cursor
## liegen im Warteschlangen-Tray, alles danach im Pool-Tray (gleiche Aufteilung
## wie _refresh_deck_trays).
func _deck_slot_position(deck_index: int, cursor: int) -> Vector3:
	var offset := deck_index - cursor
	if offset < HAND_SIZE:
		return queue_tray_view.slot_global_position(offset)
	return pool_tray_view.slot_global_position(offset - HAND_SIZE)

## Baut einen freien, nicht-kollidierenden Würfel für die diversen Gleit-
## Animationen (Aufrücken nach einem Wurf, Umsortieren im Warteschlangen-Tray)
## - zeigt def in der passenden Art-Farbe, ist aber keinem Tray-Slot zugeordnet.
func _spawn_deck_ghost(def: DieDefinition) -> Node3D:
	var ghost := DieBuilder.build()
	add_child(ghost)
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
		for i in HAND_SIZE:
			if _remaining_in_pool() <= 0:
				break
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
		for i in dice.count():
			if not dice.selected[i] and _remaining_in_pool() > 0:
				active_kinds[i] = _draw_one()
				thrown_indices.append(i)
		dice.set_slot_defs(active_kinds)
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
	dice.throw_slots(thrown_indices, throw_force, spin_strength)
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
	return Vector3(PIT_TOP_ROW_X, y, z)

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

	# Farkle-Prüfung: nur ein echtes Neu-Würfeln kann farkeln – der erste Wurf
	# einer Hand nie. Bringt der Wurf nicht mehr Punkte als der Stand direkt
	# davor (gleich viele oder weniger), ist die ganze Hand verloren.
	if last_throw_was_reroll and not DiceScoring.is_strictly_better(dice.values, pre_reroll_values, run.charm_ids()):
		_on_farkle()
		return

	# Nehmen-Auswahl für die jetzt liegenden Würfel neu setzen: automatisch die
	# beste offene Kombination vorschlagen (siehe _auto_select_best_combo),
	# der Spieler kann sie danach frei umklicken.
	dice.clear_selection()
	_auto_select_best_combo()

	has_rolled_current_hand = true
	_refresh_action_buttons()
	_refresh_deck_trays()
	_refresh_ui()

## Farkle: die komplette Hand wird normalerweise ohne Punkte verworfen (nichts
## war ja schon genommen - Nehmen wirkt immer auf alle 6, siehe
## _on_take_button_pressed). Charms können das mildern (siehe CharmEffects):
## der Schornsteinfeger verzeiht den ersten Farkle jeder Runde (die Hand läuft
## einfach weiter), der Umgedrehte Spiegel rettet die Hälfte der Punkte, und
## die Kristallkugel zahlt Geld für jeden überlebten Farkle. Die verbrauchten
## Würfel sind bereits aus dem Pool gezogen; danach geht es mit der nächsten
## Hand weiter (bzw. die Runde endet, wenn das Ziel jetzt doch erreicht wurde -
## etwa durch geretteten Punkte - oder der Pool keine volle Hand mehr hergibt).
func _on_farkle() -> void:
	var ids := run.charm_ids()

	# Schornsteinfeger: erster Farkle der Runde wird verziehen - die Hand wird
	# NICHT verworfen, sondern läuft mit den aktuellen Würfeln weiter (der
	# Spieler kann nehmen oder erneut würfeln), als hätte der schlechte Wurf
	# nur nicht verbessert.
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

	# Umgedrehter Spiegel: statt null bleibt ein Anteil der Punkte erhalten, die
	# die Hand vor dem farkelnden Wurf wert war (pre_reroll_values, ihr
	# Höchststand).
	var kept := CharmEffects.farkle_kept_fraction(ids)
	if kept > 0.0:
		var peak: int = DiceScoring.best_hand(pre_reroll_values, ids)["score"]
		var salvage := int(floor(peak * kept))
		if salvage > 0:
			hand_total += salvage
			_animate_points_to(hand_total)
			hand_note = "Umgedrehter Spiegel: Farkle – %d Punkte (Hälfte) gerettet." % salvage

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

## Nimmt die komplette Hand (alle 6 Würfel, siehe DiceScoring.best_hand über
## dice.values): der Wert wird zum Rundenstand addiert, alle 6 wandern ins
## Ablage-Tray. Welche Würfel gerade ausgewählt (siehe DiceController.selected)
## sind, spielt für Nehmen keine Rolle - die Auswahl steuert nur noch, welche
## Würfel beim nächsten "Neu würfeln" geschützt sind (siehe
## _on_throw_button_pressed).
func _on_take_button_pressed() -> void:
	if phase != Phase.IDLE or not has_rolled_current_hand:
		return

	# is_first_hand für Charms, die nur die erste genommene Hand der Runde
	# betreffen (Zauberkarte) - VOR dem Hochzählen von hands_taken_this_round
	# auswerten.
	var hand := DiceScoring.best_hand(dice.values, run.charm_ids(), hands_taken_this_round == 0)
	hand_total += hand["score"]
	hands_taken_this_round += 1
	_animate_points_to(hand_total)

	for kind in active_kinds:
		_discard_kind(kind)

	if hand_total >= run.round_goal or _remaining_in_pool() < HAND_SIZE:
		_on_round_complete()
	else:
		_start_new_hand()

## Markiert alle Würfel fürs nächste "Neu würfeln" als geschützt (siehe
## DiceController.select_all) - nützlich, um versehentliches Neu-Würfeln der
## kompletten Hand zu vermeiden.
func _on_select_all_button_pressed() -> void:
	if phase != Phase.IDLE or not has_rolled_current_hand:
		return
	dice.select_all()
	_refresh_action_buttons()

## Markiert nach jedem Wurf automatisch die Würfel, die gerade die beste offene
## Kombination bilden (siehe DiceScoring.best_hand_indices), z.B. bei 3 Vierern
## + 2 Zweiern + einer 5 das Full House aus den 5 Vierern/Zweiern, ohne die
## unbeteiligte 5 - reiner Vorschlag fürs Schützen vor dem nächsten
## "Neu würfeln" (Nehmen nimmt ohnehin immer alle 6). Der Spieler kann die
## Vorschläge danach frei umklicken.
func _auto_select_best_combo() -> void:
	for position in DiceScoring.best_hand_indices(dice.values):
		dice.set_selected(position, true)

## Aktualisiert Nehmen/Alle-auswählen: beide sind nutzbar, sobald eine Hand
## liegt und weder gewürfelt noch der Becher gerade animiert wird - Nehmen
## hängt (anders als in einer früheren Version) nicht mehr von einer Auswahl
## ab, da es immer die komplette Hand nimmt (siehe _on_take_button_pressed).
func _refresh_action_buttons() -> void:
	var interactable := phase == Phase.IDLE and has_rolled_current_hand
	take_button.disabled = not interactable
	select_all_button.disabled = not interactable

func _on_reset_button_pressed() -> void:
	_reset_game()

func _reset_game() -> void:
	phase = Phase.IDLE  # bricht auch laufende Wurf-Koroutinen ab (siehe _on_throw_button_pressed)
	_cancel_deck_shift()
	_cancel_reorder_drag()
	_clear_cup_interior_ghosts()
	hand_note = ""
	last_throw_was_reroll = false
	run = GameRun.new_run()
	_connect_run()
	charm_shop.visible = false
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
	run.money_changed.connect(_on_money_changed)
	run.charms_changed.connect(_on_charms_changed)
	run.coupons_changed.connect(_refresh_coupons_label)
	run.sheet_purchased.connect(_show_sheet_reveal)
	_on_money_changed(run.money)
	_on_charms_changed()
	_refresh_coupons_label()

func _start_new_round() -> void:
	_cancel_deck_shift()
	_cancel_reorder_drag()
	hands_taken_this_round = 0
	chimney_sweep_used_this_round = false

	var ids := run.charm_ids()
	round_pool_kinds = run.owned_pool.duplicate()
	# Glücksknoten (siehe CharmEffects.extra_round_dice): jede Runde bekommt
	# zusätzliche Standardwürfel in den Pool - mehr Hände und mehr Geld für
	# übrige Würfel.
	for i in CharmEffects.extra_round_dice(ids):
		round_pool_kinds.append(DieDefinition.standard())
	round_pool_kinds.shuffle()
	# Wünschelrute (siehe CharmEffects.draws_specials_first): Spezialwürfel nach
	# vorne, damit sie in den frühesten Händen gezogen werden.
	if CharmEffects.draws_specials_first(ids):
		round_pool_kinds = _specials_first(round_pool_kinds)

	next_draw_index = 0
	discard_tray_view.clear()
	hand_total = 0
	hand_note = ""
	_refresh_round_hud()
	_animate_points_to(0, false)
	_start_new_hand()

## Sortiert die Spezialwürfel (nicht "normal") stabil an den Anfang, normale
## dahinter - Grundlage der Wünschelrute (siehe _start_new_round).
func _specials_first(pool: Array[DieDefinition]) -> Array[DieDefinition]:
	var specials: Array[DieDefinition] = []
	var normals: Array[DieDefinition] = []
	for def in pool:
		if def.style_id == "normal":
			normals.append(def)
		else:
			specials.append(def)
	return specials + normals

func _start_new_hand() -> void:
	has_rolled_current_hand = false
	active_kinds = []
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
		var blind := MONEY_PER_ROUND_CLEAR + CharmEffects.round_clear_bonus(ids)  # Glücksgroschen
		var per_die := MONEY_PER_UNUSED_DIE + CharmEffects.unused_die_bonus(ids)  # Sparschwein
		await _play_round_clear_payout(blind, per_die)
		if phase != Phase.PAYOUT:
			return  # Spiel wurde während der Auszahlungs-Animation zurückgesetzt
		phase = Phase.SHOP
		_set_gameplay_ui_visible(false)
		charm_shop.open()
	else:
		phase = Phase.GAME_OVER
		_show_game_over(hand_total)

## Lässt die beiden Tisch-Texte (siehe blind_payout_label3d/dice_payout_label3d)
## nacheinander golden aufleuchten, synchron zur tatsächlichen Gutschrift: erst
## der Fixbetrag blind, dann - falls noch Würfel im Pool übrig sind - je per_die
## pro übrigem Würfel, während die betroffenen Würfel in Warteschlangen- und
## Pool-Tray im selben Takt mit aufleuchten (siehe _unused_die_entries). blind
## und per_die kommen schon inklusive Charm-Boni herein (siehe
## _on_round_complete). Die Auszahlung folgt der wahren Anzahl übriger Würfel
## (_remaining_in_pool), auch falls mehr Würfel übrig sind, als das Pool-Tray
## anzeigen kann - dann zahlen die überzähligen ohne eigenes Aufblitzen.
func _play_round_clear_payout(blind: int, per_die: int) -> void:
	# Die ganze Zählsequenz läuft unfokussiert in der Übersicht: Tisch-Texte,
	# Geldanzeige und beide Trays sind gleichzeitig im Bild, statt auf ein
	# einzelnes Tray zu fokussieren. Am Ende geht es zurück in die Grubensicht,
	# damit nach dem Shop die normale Spielansicht steht.
	camera_rig.zoom_out()
	await get_tree().create_timer(CameraRig.ZOOM_DURATION).timeout

	await _light_up_payout_label(blind_payout_label3d)
	run.add_money(blind)
	_pulse_money_label()
	_show_money_popup(blind)
	await get_tree().create_timer(PAYOUT_TEXT_HOLD_DURATION).timeout
	_fade_payout_label(blind_payout_label3d)

	var remaining := _remaining_in_pool()
	if remaining > 0:
		await _light_up_payout_label(dice_payout_label3d)
		var die_entries := _unused_die_entries()
		for i in remaining:
			if i < die_entries.size():
				_flash_die_tint(die_entries[i]["display"], die_entries[i]["tint"])
			run.add_money(per_die)
			_pulse_money_label()
			_show_money_popup(per_die)
			await get_tree().create_timer(DIE_PAYOUT_STEP_INTERVAL).timeout
		_fade_payout_label(dice_payout_label3d)

	camera_rig.zoom_to(CameraRig.Mode.PIT)
	await get_tree().create_timer(CameraRig.ZOOM_DURATION).timeout

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

## Blendet einen Tisch-Text von seiner aktuellen Farbe auf CasinoStyle.GOLD auf
## und lässt ihn dabei leicht aufplustern - wartet, bis das fertig ist (siehe
## _play_round_clear_payout, das die eigentliche Gutschrift danach auslöst).
func _light_up_payout_label(label: Label3D) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(c: Color) -> void: label.modulate = c, label.modulate, CasinoStyle.GOLD_INTENSE, PAYOUT_FLASH_DURATION)
	tween.tween_property(label, "scale", Vector3.ONE * 1.3, PAYOUT_FLASH_DURATION)
	await tween.finished

## Blendet einen Tisch-Text zurück in seine gedämpfte Ruhefarbe - läuft im
## Hintergrund weiter, blockiert die aufrufende Animation also nicht.
func _fade_payout_label(label: Label3D) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(c: Color) -> void: label.modulate = c, label.modulate, PAYOUT_LABEL_BASE_COLOR, PAYOUT_FLASH_DURATION)
	tween.tween_property(label, "scale", Vector3.ONE, PAYOUT_FLASH_DURATION)

## Lässt einen einzelnen Würfel beim Auszahlen aufblitzen: sehr schneller
## Anstieg (ease-out) auf überstrahltes Gold plus Größen-Pop, danach deutlich
## langsameres Abklingen (ease-out = schneller Abfall mit sanftem Ausläufer,
## wie ein echtes Aufblitzen) zurück zu Stilfarbe und Normalgröße. Läuft im
## Hintergrund weiter, damit sich aufeinanderfolgende Würfel in
## _play_round_clear_payout wie eine Welle überlappen statt zu warten.
func _flash_die_tint(display: DieFaceDisplay, original_tint: Color) -> void:
	var tint_tween := create_tween()
	tint_tween.tween_method(display.set_tint, original_tint, DIE_FLASH_PEAK_COLOR, DIE_FLASH_RAMP_UP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tint_tween.tween_method(display.set_tint, DIE_FLASH_PEAK_COLOR, original_tint, DIE_FLASH_RAMP_DOWN) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var scale_tween := create_tween()
	scale_tween.tween_property(display, "scale", Vector3.ONE * DIE_FLASH_SCALE, DIE_FLASH_RAMP_UP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(display, "scale", Vector3.ONE, DIE_FLASH_RAMP_DOWN) \
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
	charms_label.visible = show_ui
	coupons_label.visible = show_ui
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

## Der Shop wurde mit "Fertig" geschlossen (er blendet sich selbst aus): nächste
## Runde vorbereiten und ins Spiel zurückkehren.
func _on_shop_closed() -> void:
	run.advance_round()
	phase = Phase.IDLE
	_set_gameplay_ui_visible(true)
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
	else:
		var hand := DiceScoring.best_hand(dice.values, run.charm_ids(), hands_taken_this_round == 0)
		var value_strings: Array[String] = []
		for v in dice.values:
			value_strings.append(str(v))
		hand_label.text = "%s  →  %s ×%d  =  %d Punkte" % [" ".join(value_strings), hand["label"], hand["mult"], hand["score"]]
		_refresh_combos(hand["key"])

## Aktualisiert die statischen Teile der Runden-Anzeige (Rundenzahl, Balken-
## Obergrenze) - der aktuell gezeigte Punktestand läuft separat und animiert
## über _animate_points_to, damit ein Zuwachs sichtbar hochzählt statt zu
## springen. Harmlos, auch wenn mehrfach ohne echte Änderung aufgerufen (siehe
## _refresh_ui - läuft nach jedem Wurf, nicht nur bei neuer Punktzahl).
func _refresh_round_hud() -> void:
	round_badge_label.text = "Runde %d" % run.round_number
	points_bar.max_value = run.round_goal

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

## Kurzes elastisches Aufplustern des Punktetexts, sobald sich der Stand
## erhöht - kleiner "Arcade-Pop", der einen Punktezuwachs zusätzlich zum
## Hochzählen spürbar macht.
func _pulse_points_label() -> void:
	points_label.pivot_offset = points_label.size / 2.0
	points_label.scale = Vector2(1.35, 1.35)
	var pulse := create_tween()
	pulse.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(points_label, "scale", Vector2.ONE, 0.4)
