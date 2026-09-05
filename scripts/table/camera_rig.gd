class_name CameraRig
extends Camera3D
## Spielkamera mit ZWEI Systemen, die einander ausschließen. FOKUS: Linksklick
## auf eine Zone fährt an ihre Station, Rechtsklick zurück - gerechnete Stufen,
## und nur hier wird bedient. FREIKAMERA: WASD schiebt den Blick, das Rad zoomt
## stufenlos, der Modus steht derweil auf OVERVIEW - reines Umsehen und Fahren.
## Das leichte Maus-Rundschauen läuft überall außer an den drei Stationen, deren
## Fenster das Bild füllt (Hub, Werkstatt, Titel) - dort verschöbe es nur.

enum Mode { OVERVIEW, PIT, POOL, COMBOS, CHARMS, HUB, SIDE_BETS, SCORE, SLOTS, CHIPS, WORKSHOP, SECRET_SHOP, TITLE }

signal mode_changed(new_mode: Mode)

const TILT_MAX_UP_DEGREES := 5.0
const TILT_MAX_DOWN_DEGREES := 5.0
const TILT_MAX_YAW_DEGREES := 5.0
# Die Winkel des Zoomblicks: sie gelten für jede fokussierte Station und für die
# geparkte Freikamera, die ebenfalls im Zoomblick steht.
const ZOOM_TILT_MAX_PITCH_DEGREES := 5.0
const ZOOM_TILT_MAX_YAW_DEGREES := 16.0
const TILT_SMOOTHING := 6.0
const ZOOM_DURATION := 0.6

## Nach dem Freigeben einer Tilt-Sperre: erst TILT_RESUME_HOLD stehen bleiben,
## dann über TILT_RESUME_EASE sanft wieder einblenden - kein harter Sprung.
const TILT_RESUME_HOLD := 0.5
const TILT_RESUME_EASE := 0.5

## EINE Zoom-Distanz für alle Ziele: zusammen mit ZOOM_BASIS steht die Kamera
## bei jedem Zoom in derselben Höhe und im selben Winkel, nur das Ziel wandert.
const ZOOM_DISTANCE := 20.0

## Die Grube wird bewusst etwas weiter weg gezeigt (mehr vom Screen im Blick).
const PIT_ZOOM_DISTANCE_BONUS := 5.0

## Der Chip-Haufen ist klein - deutlich näher heranfahren als an die Fenster.
const CHIPS_ZOOM_DISTANCE_CUT := 8.0

## Der Schwarzmarkt ist das kleinste Fenster (eine flache Tasche unter den
## Automaten): keine 500 Textur-px breit. Die Distanz ist
## deshalb der TEXTUR-Auflösung gerechnet, nicht dem Bildeindruck: bei Abzug 11
## lag das Fenster auf ~780 Bildschirm-px, also 0,58 Textur-px je Bildschirm-px -
## eine 1,7-fache Hochskalierung, die als "360p" gelesen wurde. Bei Abzug 4 füllen
## seine 451 Textur-px ~440 Bildschirm-px, das Bild wird also nie mehr gestreckt.
## Mehr Textur ginge nur über TableScreen.SUPERSAMPLE, und das kostet den ganzen
## Tisch (gemessen: 3 -> 4 hebt die Bildzeit von 35 auf 58 ms und erreicht
## trotzdem nur 0,77 tex/px). Die verlorene Bildgröße holt SecretShopView über
## seine kleinere CONTENT_UNITS zurück.
const SECRET_SHOP_ZOOM_DISTANCE_CUT := 4.0

## Untergrenze der weiten Werkbank-Sicht. Sie ist seit der WELLE X eine reine
## SICHERUNG, kein Maß: der Streifen ist zu EINER flachen Zeile geworden und paßt
## weit unter ZOOM_DISTANCE ganz ins Bild - der alte Boden hielt ihn auf halber
## Bildbreite fest. Gerechnet wird der Abstand in workshop_wide_distance.
const WORKSHOP_MIN_DISTANCE := 7.0
## Zugabe der weiten Werkbank-Sicht: reine Rahmungs-Luft. Einst deckte sie den
## ±5°-Schwenk des Rundschauens - das ruht in den Stationen, die Rahmung bleibt.
const WORKSHOP_WIDE_MARGIN := 1.14

## Zweite Werkbank-Stufe (Doppelklick auf leere Fläche): rahmt NUR Fenster und
## Schubladen, mit einem Hauch Zugabe - anders als der Titel (TITLE_MARGIN), der
## bewusst Tisch daneben zeigt. Über 1.0, damit die Ecke IMMER ganz ins Bild
## passt; wohin der Rest fällt, klärt _workshop_close_origin.
const WORKSHOP_CLOSE_MARGIN := 1.02
## Seitlich dagegen ein Hauch Luft: dort gibt es kein "fällt oben weg", ein zu
## enger Rahmen schneidet einfach die äußeren Schubladen an. Knapp halten - bei
## einem hochformatigeren Fenster schlägt die BREITE an und bestimmt allein,
## wie nah die Kamera kommt.
const WORKSHOP_CLOSE_SIDE_MARGIN := 1.01
## Zugabe der Hub-Sicht. Der Hub ist das höchste Fenster des Tisches, und der
## Blick auf ihn ist GENEIGT: seine Unterkante steht näher an der Kamera und
## bildet sich größer ab - beim alten festen ZOOM_DISTANCE fiel genau die
## Fußzeile aus dem Bild. Der Abstand wird darum gerechnet (hub_distance), diese
## Zahl ist nur die Luft darum herum.
const HUB_MARGIN := 1.04

## Werkstück-Sicht: der Würfel steht mit seiner Raumdiagonale im Bild, die Zugabe
## lässt ringsum Luft - er soll sich frei drehen lassen, ohne an den Rand zu
## stoßen. Über 2 heißt: der Würfel füllt knapp die halbe Bildhöhe.
const DIE_FOCUS_MARGIN := 2.2
## Ausgangslage des gegriffenen Würfels, in KAMERA-Achsen: erst um die Bildhoch-,
## dann um die Bildquerachse gedreht. Diese Dreiviertel-Ansicht zeigt drei Seiten
## auf einmal - eine Draufsicht allein sähe aus wie ein Quadrat.
const DIE_FOCUS_POSE := Vector3(-24.0, 32.0, 0.0)

## HANDVERSCHIEBUNG der Nahsicht, falls der Ausschnitt anders sitzen soll: die
## Kamera wandert um x nach rechts und y nach oben (Weltmeter, in Bildrichtung),
## das Bild also gegenläufig. Null = die gerechnete Lage, die die Trays sicher
## draußen hält - wer hier schiebt, holt sie oben wieder herein.
const WORKSHOP_CLOSE_AIM := Vector2.ZERO

## Zoom-Blickpunkte - nur Rückfallwerte: scene_root überschreibt sie aus den
## echten Weltpositionen (configure_*_target), damit Editor-Verschiebungen den
## Zoom automatisch mitnehmen.
var pool_target := Vector3(-23.75, 0.4, 12)
var combos_target := Vector3(-8, 0, 0)
var pit_target := Vector3.ZERO
var charms_target := Vector3(24, 0, 0)
var hub_target := Vector3(-24, 0, 0)
## Halbe Hub-Fenstermaße (x = entlang Welt-Z = Bildbreite, y = entlang Welt-X =
## Bildhöhe) - scene_root misst sie am echten Rechteck.
var hub_half := Vector2(14.25, 15.0)
var side_bets_target := Vector3(0, 0, 24)
var score_target := Vector3(-4, 0, 0)
var slots_target := Vector3(-24, 0, -22)
var secret_shop_target := Vector3(-24, 0, -12)
var chips_target := Vector3(0, 1.5, 10)
var workshop_target := Vector3(-24, 0, 22)
## Halbe Ausmaße der GANZEN Ecke (Trays + Fenster + Schürze) - daraus rechnet die
## weite Sicht ihren Abstand.
var workshop_wide_half := Vector2(12.0, 14.0)
## Nahsicht-Ziel + halbe Ausmaße der Werkbank-Ecke ohne Trays (x = entlang
## Welt-Z, y = entlang Welt-X) - wie beim Titel aus den echten Rechtecken.
var workshop_close_target := Vector3(-24, 0, 22)
var workshop_close_half := Vector2(12.0, 10.0)
## Steht die Werkbank in der Nahsicht? Dort steht die Kamera zusätzlich STILL.
var workshop_close: bool = false
## Steht die Nahsicht auf einem schwebenden WÜRFEL? Sie ist ein TEMPORÄRER Rahmen
## wie frame_rect: kein Moduswechsel, keine Meldung - sonst bräche sie die Wahl ab,
## die sie zeigt. Der Aufrufer merkt sich die Lage davor selbst (camera_pose).
var die_focus: bool = false
## Titelziel + halbe Fenstermaße (x = entlang Welt-Z, y = entlang Welt-X).
var title_target := Vector3(-26, 0, 0)
var title_half := Vector2(14.25, 15.0)

## Feste, steile Draufsicht für ALLE Zoom-Ziele, unabhängig von der flacheren
## Übersichts-Kamera (Basis-Achsen als Spalten!).
const ZOOM_BASIS := Basis(
	Vector3(-4.371139e-08, 0.0, 1.0),
	Vector3(0.9659258, 0.25881907, 4.222196e-08),
	Vector3(-0.25881907, 0.9659258, -1.1313341e-08)
)
const ZOOM_FORWARD := Vector3(0.25881907, -0.9659258, 1.1313341e-08)  # = -ZOOM_BASIS.z

## Titelsicht: SENKRECHT von oben, Bild-Rechts = Welt +Z, Bild-Oben = Welt +X -
## genau die Laufrichtung der Display-Pixel. Der geneigte ZOOM_BASIS taugt hier
## nicht: er zeigte das Menü als Trapez, und die Illusion "flache Oberfläche"
## wäre hin.
const TITLE_BASIS := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))

## Alle drei Blickwinkel sind dieselbe Familie, nur anders geneigt: Bild-Rechts
## = Welt +Z, Bild-Oben kippt um Grad aus der Senkrechten (0 = TITLE_BASIS,
## 15 = ZOOM_BASIS).
static func tilted_basis(degrees: float) -> Basis:
	var angle := deg_to_rad(degrees)
	return Basis(Vector3(0, 0, 1), Vector3(cos(angle), sin(angle), 0),
		Vector3(-sin(angle), cos(angle), 0))

## Die Werkbank-Nahsicht blickt SENKRECHT von oben: aus der Nähe verzerrte schon
## ein kleiner Winkel das Fenster sichtbar zum Trapez. Die Werkbank ist flache
## Anzeige und soll wie ein Bildschirm liegen - wie das Titel-HUD.
const WORKSHOP_CLOSE_TILT_DEGREES := 0.0
static var WORKSHOP_CLOSE_BASIS: Basis = tilted_basis(WORKSHOP_CLOSE_TILT_DEGREES)

## Das Titel-Fenster liegt GANZ im Bild (die weitere Achse schlägt an) und
## bekommt Zugabe: der Tisch daneben - vor allem die Würfel-Ablage rechts -
## bleibt sichtbar, das Menü liegt erkennbar AUF dem Tisch.
const TITLE_MARGIN := 1.18

## Ein- und Ausfahrt des Titel-HUDs: ruhiger als die kurzen Zoomfahrten.
const TITLE_TRAVEL := 1.1

## Enthüllung nach "Neues Spiel": lang und ausklingend - das ist der Moment,
## in dem sich der Tisch zeigt.
const REVEAL_DURATION := 2.6

## --- Freikamera (WASD + Mausrad) ---------------------------------------------
## Zwei Kamera-Systeme schließen einander aus. Die Freikamera ist reines
## Umsehen-und-Fahren: WASD schiebt den Blick über die Zoom-Ebene, das Rad zoomt
## stufenlos. Der Modus steht dabei die GANZE Zeit auf OVERVIEW - eine freie
## Kamera hat keinen Fokus, und nur so darf zoom_to auch auf die eben verlassene
## Station zurückfahren. Verlassen wird sie nur über eine gerechnete Fahrt
## (_animate_to ist der EINE Ausstieg) - Klick auf eine Zone, Rechtsklick auf die
## Übersicht oder irgendeine Zeremonie.

## GEFÜHLSWERT: Weltmeter je Sekunde bei voller Auslenkung auf ZOOM_DISTANCE.
## Gemessen am Tisch spannen die Stationen 63 m (Kombis -> Ablage) bzw. 53 m
## (Hub -> Charms), das sind ~1,8 bzw. ~1,5 s von Rand zu Rand.
const GLIDE_SPEED := 36.0
## Anlauf- und Auslaufzeit der Richtung: ein Tipper soll nicht rucken.
const GLIDE_ACCEL := 0.15
## Luft um die Anzeigefläche, in die der Blick noch hinausfahren darf. Weiter
## hinaus geht es nicht: draußen ist nur noch dunkler Raum.
const GLIDE_BOUNDS_MARGIN := 6.0

## Das Tempo hängt an der Höhe (Kartengrammatik): dicht über den Würfeln wäre
## der volle Wert unlenkbar, ganz oben ein Kriechen. Die Grenzen halten beides
## im Griff.
const FREE_SPEED_MIN := 4.0
const FREE_SPEED_MAX := 70.0

## Eine Radkerbe ändert die Distanz um diesen Anteil - klein genug, dass ein
## Stups nicht springt, groß genug für einen zügigen Weg über die ganze Spanne.
const FREE_ZOOM_STEP := 0.12
## Nachlauf der Zoomfahrt: die Distanz nähert sich ihrem Ziel exponentiell an,
## sonst hakt jede Kerbe.
const FREE_ZOOM_SMOOTH := 0.12
## Untergrenze: 2,4 m über der Fläche, also über allem, was auf ihr liegt oder
## in einem Stasisfeld darüber schwebt. Ein liegender Würfel füllt dort schon gut
## die halbe Bildhöhe - näher braucht reines Umsehen nicht, und darunter fährt
## die Kamera durch die schwebenden Würfel der Werkbank hindurch.
const FREE_ZOOM_MIN := 2.5
## Obergrenze, gemessen an der Übersicht: ein Stück ÜBER ihr ist erlaubt, damit
## der ganze Tisch bequem ins Bild passt.
const FREE_ZOOM_MAX_FACTOR := 1.4
## Einstieg: nur der WINKEL gleicht sich an (Übersicht 20°, Zoomblick 15°) -
## Höhe und Blickpunkt bleiben, wo der Spieler sie sieht. Kein Sinkflug.
const FREE_SETTLE := 0.35

## Waagerechter Anteil einer Richtung (Länge 1); ZERO, wenn sie senkrecht steht.
static func flatten(v: Vector3) -> Vector3:
	var flat := Vector3(v.x, 0.0, v.z)
	return flat.normalized() if flat.length() > 0.0001 else Vector3.ZERO

## Bild-Achsen des Zoomblicks auf die Tischebene projiziert - die Laufrichtungen
## der Tasten. Abgeleitet, nicht getippt: Bild-Rechts = Welt +Z, Bild-Oben = +X.
static var GLIDE_RIGHT: Vector3 = flatten(ZOOM_BASIS.x)
static var GLIDE_UP: Vector3 = flatten(-ZOOM_BASIS.z)

## Steht die Freikamera? Sie ist kein Sonderfall der Bedienung mehr - SICHTBAR
## HEISST BEDIENBAR gilt dort wie an jeder Station; das Bit entscheidet nur noch
## über die Griffe auf dem Filz (felt_pick_live) und über Zoom/Heimfahrt.
var free_camera: bool = false
## Rechteck der Anzeigefläche in Welt-XZ (x = Welt-X, y = Welt-Z); scene_root
## misst es an der echten Fläche.
var glide_bounds := Rect2(-50.0, -50.0, 100.0, 100.0)
## Abstand der Übersichtskamera zu ihrem Blickpunkt - in _ready am echten
## Transform gemessen, denn daran hängt die obere Zoomgrenze.
var overview_distance := ZOOM_DISTANCE * 2.5

## Blickpunkt auf der Tischebene, um den die Freikamera rechnet.
var _free_target := Vector3.ZERO
var _free_velocity := Vector3.ZERO
## Gezeigte und gewünschte Distanz - die eine läuft der anderen nach.
var _free_distance := ZOOM_DISTANCE
var _free_zoom_goal := ZOOM_DISTANCE
## Einstiegs-Winkel und sein Fortschritt (0 = Einstieg, 1 = Zoomblick).
var _free_from_basis := Basis()
var _free_blend := 0.0
## Liegt gerade eine Taste? Im Fahren blickt die Kamera geradeaus.
var _free_moving := false

## Hält einen Blickpunkt auf der Anzeigefläche plus margin fest - ins Leere
## hinaus zu fahren darf es nicht geben.
static func clamp_to_bounds(point: Vector3, bounds: Rect2, margin: float) -> Vector3:
	var room := bounds.grow(margin)
	return Vector3(
		clampf(point.x, room.position.x, room.end.x),
		point.y,
		clampf(point.z, room.position.y, room.end.y))

## Fahrtempo auf einer Höhe: linear an der Distanz, aber unten wie oben begrenzt.
static func free_speed(distance: float) -> float:
	return clampf(GLIDE_SPEED * distance / ZOOM_DISTANCE, FREE_SPEED_MIN, FREE_SPEED_MAX)

## Distanz nach notches Radkerben (positiv = heran), in ihren Grenzen. Der Schritt
## ist multiplikativ: oben große Sprünge, unten feine - sonst ist das letzte
## Stück über den Würfeln nicht zu treffen.
static func zoom_step_distance(current: float, notches: float,
		min_distance: float, max_distance: float) -> float:
	return clampf(current * pow(1.0 - FREE_ZOOM_STEP, notches), min_distance, max_distance)

## Neuer Blickpunkt, wenn um den Punkt unter dem Cursor gezoomt wird: die Kamera
## rückt entlang der Geraden Cursor->Standort, also wandert auch der Blickpunkt
## um denselben Faktor auf den Cursor zu. So bleibt liegen, worauf man zeigt.
static func zoom_anchor(look: Vector3, cursor: Vector3, factor: float) -> Vector3:
	return cursor + (look - cursor) * factor

var base_basis: Basis
var base_origin: Vector3

# Ruhelage des aktuellen Modus, um die das Rundschauen pendelt.
var anchor_basis: Basis
var anchor_origin: Vector3

var mode: Mode = Mode.OVERVIEW
var is_animating: bool = false
## Solange gesetzt, hält die Kamera ihre Ausrichtung (z.B. während der Spieler
## einen Grubenwürfel zieht), damit die Geste nicht zugleich den Blick schwenkt.
var tilt_locked: bool = false
var tilt_offset := Vector2.ZERO  # geglättete Blickabweichung (Grad: x=Pitch, y=Yaw)
## Nachlauf nach dem Entsperren: Zeit seit Freigabe (< 0 = kein Nachlauf).
var _tilt_resume_time := -1.0
var _frozen_offset := Vector2.ZERO
## Zuletzt TATSÄCHLICH angewandte Abweichung - beim erneuten Sperren muss von
## hier eingefroren werden, nicht vom vorgelaufenen tilt_offset (sonst Sprung).
var _applied_offset := Vector2.ZERO

var active_tween: Tween

func _ready() -> void:
	base_basis = global_transform.basis
	base_origin = global_transform.origin
	anchor_basis = base_basis
	anchor_origin = base_origin
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(base_origin, -base_basis.z)
	if hit is Vector3:
		overview_distance = maxf(base_origin.distance_to(hit as Vector3), ZOOM_DISTANCE)

## Obere Zoomgrenze der Freikamera: ein Stück über der Übersicht.
func free_zoom_max() -> float:
	return overview_distance * FREE_ZOOM_MAX_FACTOR

## Nimmt der Tisch gerade Bedienung an? SICHTBAR HEISST BEDIENBAR - zwei Ausnahmen
## bleiben: das Titel-HUD ist MODAL (dahinter ist nichts anzufassen), und während
## einer Kamerafahrt ist alles taub, denn halbe Übergänge klicken sich schlecht.
func takes_input() -> bool:
	return mode != Mode.TITLE and not is_animating

## Ob ein physischer Griff auf dem FILZ antwortet - Tray-Würfel, Chip-Stufe,
## Dock-Kachel: an seiner eigenen Station und in der FREIKAMERA, wo der Spieler
## bewusst an ein Ding heranfährt. Aus der RUHENDEN Übersicht bleibt der Klick der
## FLUG dorthin, sonst fräße die Geste die Navigation - diese Griffe liegen unter
## den Zoom-Zonen, anders als ein Knopf, der sein eigenes Fenster hat.
func felt_pick_live(station: int) -> bool:
	if not takes_input():
		return false
	return free_camera or mode == station

## Hub, Titel und WERKSTATT stehen STILL: ihr Fenster füllt das Bild, ein Schwenk
## verschöbe es nur. Das Rundschauen an der Werkstatt ist am 2026-09-04 wieder
## gefallen (Spieler: es erschwert das Arbeiten) - Nahsicht und Werkstück-Sicht
## bleiben WORKSHOP und stehen damit mit still. WASD bleibt: das ist Absicht.
func _tilt_frozen_mode() -> bool:
	return mode == Mode.HUB or mode == Mode.TITLE or mode == Mode.WORKSHOP

func _process(delta: float) -> void:
	if is_animating or tilt_locked or _tilt_frozen_mode():
		return

	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	var mouse := get_viewport().get_mouse_position()
	var nx: float = clamp((mouse.x / vp_size.x) * 2.0 - 1.0, -1.0, 1.0)
	var ny: float = clamp((mouse.y / vp_size.y) * 2.0 - 1.0, -1.0, 1.0)

	var pitch_max: float
	var yaw_max: float
	if free_camera or mode != Mode.OVERVIEW:
		# Fokus-Stationen und die geparkte Freikamera stehen im Zoomblick.
		pitch_max = ZOOM_TILT_MAX_PITCH_DEGREES
		yaw_max = ZOOM_TILT_MAX_YAW_DEGREES
	else:
		# ny > 0 = Maus unten -> Blick Richtung Tisch (eigener Winkelbereich).
		pitch_max = TILT_MAX_DOWN_DEGREES if ny > 0.0 else TILT_MAX_UP_DEGREES
		yaw_max = TILT_MAX_YAW_DEGREES
	var target_tilt := Vector2(-ny * pitch_max, -nx * yaw_max)
	# Im Fahren blickt die Kamera geradeaus: das Rundschauen blendet über
	# dieselbe Glättung aus und beim Parken wieder ein - keine Sperre nötig.
	if free_camera and _free_moving:
		target_tilt = Vector2.ZERO
	tilt_offset = tilt_offset.lerp(target_tilt, clamp(delta * TILT_SMOOTHING, 0.0, 1.0))

	# Im Nachlauf vom eingefrorenen Blick sanft auf das lebende Rundschauen
	# blenden: halten (gain 0), dann weich einblenden (gain 0->1).
	var applied := tilt_offset
	if _tilt_resume_time >= 0.0:
		_tilt_resume_time += delta
		var gain: float
		if _tilt_resume_time <= TILT_RESUME_HOLD:
			gain = 0.0
		elif _tilt_resume_time >= TILT_RESUME_HOLD + TILT_RESUME_EASE:
			gain = 1.0
			_tilt_resume_time = -1.0
		else:
			gain = smoothstep(0.0, 1.0, (_tilt_resume_time - TILT_RESUME_HOLD) / TILT_RESUME_EASE)
		applied = _frozen_offset.lerp(tilt_offset, gain)

	_applied_offset = applied
	var yaw := Basis(anchor_basis.y, deg_to_rad(applied.y))
	var pitch := Basis(anchor_basis.x, deg_to_rad(applied.x))
	global_transform = Transform3D(yaw * pitch * anchor_basis, anchor_origin)

## Sperrt/entsperrt das Maus-Rundschauen; das Entsperren startet den Nachlauf.
func set_tilt_locked(locked: bool) -> void:
	if locked:
		tilt_locked = true
		_tilt_resume_time = -1.0
	elif tilt_locked:
		tilt_locked = false
		_frozen_offset = _applied_offset
		_tilt_resume_time = 0.0

## Hebt eine Sperre SOFORT und ohne Nachlauf auf (Sicherheitsnetz beim
## Schließen der Gravur-Station).
func release_tilt_immediately() -> void:
	tilt_locked = false
	_tilt_resume_time = -1.0

## Der Tray-Blickpunkt aus der echten Weltposition (Editor bleibt die Quelle). Die
## POOL-Station rahmt Vorrat UND Pit - sie stehen auf demselben Platz.
func configure_tray_targets(pool: Vector3) -> void:
	pool_target = pool

func configure_combos_target(target: Vector3) -> void:
	combos_target = target

func configure_pit_target(target: Vector3) -> void:
	pit_target = target

func configure_charms_target(target: Vector3) -> void:
	charms_target = target

## half_extent = halbe Ausmaße des Hub-Fensters; ZERO lässt das zuletzt gemessene
## Maß stehen (dieselbe Regel wie bei der Werkbank).
func configure_hub_target(target: Vector3, half_extent := Vector2.ZERO) -> void:
	hub_target = target
	if half_extent.x > 0.0 and half_extent.y > 0.0:
		hub_half = half_extent

func configure_side_bets_target(target: Vector3) -> void:
	side_bets_target = target

func configure_score_target(target: Vector3) -> void:
	score_target = target

func configure_slots_target(target: Vector3) -> void:
	slots_target = target

func configure_secret_shop_target(target: Vector3) -> void:
	secret_shop_target = target

func configure_chips_target(target: Vector3) -> void:
	chips_target = target

## half_extent = halbe Ausmaße der Ecke; ZERO (die Klickzone meldet nur den Punkt)
## lässt das zuletzt gemessene Maß stehen.
func configure_workshop_target(target: Vector3, half_extent := Vector2.ZERO) -> void:
	workshop_target = target
	if half_extent.x > 0.0 and half_extent.y > 0.0:
		workshop_wide_half = half_extent

func configure_workshop_close_target(center: Vector3, half_extent: Vector2) -> void:
	workshop_close_target = center
	workshop_close_half = half_extent

func configure_title_target(center: Vector3, half_extent: Vector2) -> void:
	title_target = center
	title_half = half_extent

## Abstand, bei dem ein Rechteck der halben Ausmaße half ganz im Bild steht
## (Maximum der beiden Achsen; Seitenverhältnis aus dem laufenden Viewport).
## margin < 1 überfüllt bewusst, > 1 lässt Luft.
func _fit_distance(half: Vector2, margin: float) -> float:
	var half_fov := tan(deg_to_rad(fov * 0.5))
	if half_fov <= 0.0:
		return ZOOM_DISTANCE
	var aspect := 1.0
	var viewport := get_viewport()
	if viewport != null:
		var vp_size := viewport.get_visible_rect().size
		if vp_size.x > 0.0 and vp_size.y > 0.0:
			aspect = vp_size.x / vp_size.y
	return maxf(half.y / half_fov, half.x / (half_fov * aspect)) * margin

func title_distance() -> float:
	return _fit_distance(title_half, TITLE_MARGIN)

## Abstand der Hub-Sicht: das höchste Fenster des Tisches, im geneigten Blick -
## eine reine Höhenrechnung schnitte seine Fußzeile ab.
func hub_distance() -> float:
	return maxf(ZOOM_DISTANCE, tilted_fit_distance(hub_half, HUB_MARGIN))

## Abstand, bei dem ein Rechteck im GENEIGTEN Zoomblick ganz im Bild steht - die
## EINE Rechnung dafür. BEIDE Achsen messen an den vier Ecken, denn im geneigten
## Blick steht die untere Kante NÄHER an der Kamera und bildet sich größer ab -
## auch in der BREITE (das schlug erst zu, als der Werkstatt-Streifen zu einer
## flachen, breiten Zeile wurde und die Höhe nicht mehr band).
## margin > 1 läßt Luft, sein Kehrwert IST die Bildfüllung.
func tilted_fit_distance(half: Vector2, margin: float) -> float:
	var need := _fit_distance(Vector2(half.x, 0.0), margin)
	var half_fov := tan(deg_to_rad(fov * 0.5))
	if half_fov <= 0.0:
		return need
	var aspect := 1.0
	var viewport := get_viewport()
	if viewport != null:
		var vp_size := viewport.get_visible_rect().size
		if vp_size.x > 0.0 and vp_size.y > 0.0:
			aspect = vp_size.x / vp_size.y
	var up := ZOOM_BASIS.y
	var forward := -ZOOM_BASIS.z
	var wide := half.x * margin / maxf(half_fov * aspect, 0.001)
	for edge: Vector3 in [Vector3.RIGHT, Vector3.LEFT]:  # Bild-oben/-unten = Welt ±X
		var to_edge := edge * half.y
		var depth := to_edge.dot(forward)
		need = maxf(need, absf(to_edge.dot(up)) * margin / half_fov - depth)
		need = maxf(need, wide - depth)
	return need

## Beide Achsen getrennt gerechnet, weil sie bei der Werkbank fast gleichauf
## liegen und sonst mal die eine, mal die andere anschlägt. Diese beiden Zugaben
## sind die Stellschrauben für "wie nah": bei einem hochformatigen Fenster
## entscheidet die SEITEN-Zugabe allein, bei einem breiten die andere.
func workshop_close_distance() -> float:
	return maxf(
		_fit_distance(Vector2(workshop_close_half.x, 0.0), WORKSHOP_CLOSE_SIDE_MARGIN),
		_fit_distance(Vector2(0.0, workshop_close_half.y), WORKSHOP_CLOSE_MARGIN))

## Abstand der WEITEN Werkbank-Sicht: sie rahmt die ganze Ecke - Trays oben,
## Fenster und Schürze darunter. Der alte feste Abstand bleibt Untergrenze: näher
## als früher kommt sie nie.
func workshop_wide_distance() -> float:
	return maxf(WORKSHOP_MIN_DISTANCE,
		tilted_fit_distance(workshop_wide_half, WORKSHOP_WIDE_MARGIN))

## Kamerastandort der Nahsicht. Die Ecke passt immer ganz ins Bild (Zugabe ≥ 1),
## füllt es aber fast nie genau aus - und wo die überschüssige Luft landet,
## entscheidet alles: ÜBER der Ecke liegen die Trays, UNTER ihr nur nackter Filz.
## Also sitzt die OBERKANTE am oberen Bildrand und die Luft sammelt sich unten.
## Exakt gelöst statt geschätzt: für einen Punkt P ist die Bildhöhe
## dot(P-Ziel, up) / ((dot(P-Ziel, forward) + d) * tan) - nach der Verschiebung s
## mit Bildhöhe = +1 aufgelöst. Zuletzt die Handverschiebung obendrauf.
func _workshop_close_origin() -> Vector3:
	var distance := workshop_close_distance()
	var up := WORKSHOP_CLOSE_BASIS.y
	var forward := -WORKSHOP_CLOSE_BASIS.z
	var to_top := up * workshop_close_half.y
	var shift := to_top.dot(up) \
		- tan(deg_to_rad(fov * 0.5)) * (to_top.dot(forward) + distance)
	return workshop_close_target + up * shift - forward * distance \
		+ WORKSHOP_CLOSE_BASIS.x * WORKSHOP_CLOSE_AIM.x + up * WORKSHOP_CLOSE_AIM.y

## Fährt in die Titelsicht; instant = ohne Fahrt (Spielstart).
func show_title(instant := false) -> void:
	var target_origin := title_target + Vector3.UP * title_distance()
	workshop_close = false
	die_focus = false
	mode = Mode.TITLE
	mode_changed.emit(mode)
	anchor_basis = TITLE_BASIS
	anchor_origin = target_origin
	tilt_offset = Vector2.ZERO
	_applied_offset = Vector2.ZERO
	_tilt_resume_time = -1.0
	if not instant:
		_animate_to(target_origin, TITLE_BASIS, TITLE_TRAVEL, Tween.EASE_OUT)
		return
	if active_tween:
		active_tween.kill()
	is_animating = false
	free_camera = false  # der Sprung ins Titel-HUD geht an _animate_to vorbei
	global_transform = Transform3D(TITLE_BASIS, target_origin)

## Der Rückzieher aus dem Titel-HUD auf den ganzen Tisch.
func reveal_table() -> void:
	zoom_out(REVEAL_DURATION, Tween.EASE_OUT)

## Ob eine Lage eine STATION ist, also einen eigenen Blickpunkt hat. Übersicht
## und Titel sind keine: die eine ist der Ausgangspunkt, der andere ein eigener
## Rahmen.
static func is_station(check_mode: Mode) -> bool:
	return check_mode != Mode.OVERVIEW and check_mode != Mode.TITLE

## Blickpunkt einer Station - die eine Tabelle, die zoom_to anfährt.
func station_target(target_mode: Mode) -> Vector3:
	match target_mode:
		Mode.PIT:
			return pit_target
		Mode.POOL:
			return pool_target
		Mode.COMBOS:
			return combos_target
		Mode.CHARMS:
			return charms_target
		Mode.HUB:
			return hub_target
		Mode.SIDE_BETS:
			return side_bets_target
		Mode.SCORE:
			return score_target
		Mode.SLOTS:
			return slots_target
		Mode.SECRET_SHOP:
			return secret_shop_target
		Mode.CHIPS:
			return chips_target
		Mode.WORKSHOP:
			return workshop_target
	return Vector3.ZERO

## Fährt zum Zoom-Ziel; No-Op, wenn schon dort.
func zoom_to(target_mode: Mode, duration := ZOOM_DURATION,
		ease_mode := Tween.EASE_IN_OUT) -> void:
	if mode == target_mode or not is_station(target_mode):
		return
	var target_point := station_target(target_mode)
	var distance := ZOOM_DISTANCE
	if target_mode == Mode.PIT:
		distance += PIT_ZOOM_DISTANCE_BONUS
	# Der Chip-Haufen ist klein: näher heranfahren als an die Screen-Fenster.
	if target_mode == Mode.CHIPS:
		distance -= CHIPS_ZOOM_DISTANCE_CUT
	if target_mode == Mode.SECRET_SHOP:
		distance -= SECRET_SHOP_ZOOM_DISTANCE_CUT
	if target_mode == Mode.WORKSHOP:
		distance = workshop_wide_distance()
	# Das höchste Fenster des Tisches: sein Abstand wird gerechnet, nicht gesetzt.
	if target_mode == Mode.HUB:
		distance = hub_distance()
	var target_origin := target_point - ZOOM_FORWARD * distance
	workshop_close = false  # jeder Moduswechsel verlässt die Werkbank-Stufe
	die_focus = false  # und die Würfel-Nahsicht
	mode = target_mode
	mode_changed.emit(mode)
	anchor_basis = ZOOM_BASIS
	anchor_origin = target_origin
	tilt_offset = Vector2.ZERO
	_animate_to(target_origin, ZOOM_BASIS, duration, ease_mode)

## Zweite Werkbank-Stufe: rahmt Fenster + Schubladen, die Trays fallen aus dem
## Bild. Der Modus bleibt WORKSHOP - die Nahsicht ist derselbe Arbeitsplatz,
## nur näher, und erbt damit Klickweiterleitung und Zeremonie unverändert.
func zoom_workshop_close() -> void:
	if workshop_close or mode != Mode.WORKSHOP:
		return
	workshop_close = true
	var target_origin := _workshop_close_origin()
	anchor_basis = WORKSHOP_CLOSE_BASIS
	anchor_origin = target_origin
	tilt_offset = Vector2.ZERO
	_applied_offset = Vector2.ZERO
	_tilt_resume_time = -1.0
	# Der Modus bleibt WORKSHOP, die SICHT ändert sich trotzdem: melden, damit
	# scene_root nachzieht (Spiegelung aus) - sonst muss jeder Aufrufer daran denken.
	mode_changed.emit(mode)
	_animate_to(target_origin, WORKSHOP_CLOSE_BASIS)

## Aus der Nahsicht zurück auf die ganze Werkbank-Ecke (eine Stufe, nicht raus).
func zoom_workshop_wide() -> void:
	if not workshop_close:
		return
	workshop_close = false
	var target_origin := workshop_target - ZOOM_FORWARD * workshop_wide_distance()
	anchor_basis = ZOOM_BASIS
	anchor_origin = target_origin
	tilt_offset = Vector2.ZERO
	mode_changed.emit(mode)  # siehe zoom_workshop_close
	_animate_to(target_origin, ZOOM_BASIS)

## Ein TEMPORÄRER Rahmen: die Kamera fährt so nah heran, daß das Rechteck (Mitte
## in Welt-XZ, half = halbe Bildbreite entlang Welt-Z und halbe Bildhöhe entlang
## Welt-X) das Bild bis auf den Saum füllt. Sie MELDET keinen Wechsel und rührt
## den Modus nicht an - die Station bleibt, wo sie war, und der Aufrufer merkt sich
## ihre Lage selbst (camera_pose/restore_pose).
func frame_rect(center: Vector3, half: Vector2, margin: float,
		duration := ZOOM_DURATION) -> void:
	var target_origin := center - ZOOM_FORWARD * tilted_fit_distance(half, margin)
	anchor_basis = ZOOM_BASIS
	anchor_origin = target_origin
	tilt_offset = Vector2.ZERO
	_applied_offset = Vector2.ZERO
	_tilt_resume_time = -1.0
	_animate_to(target_origin, ZOOM_BASIS, duration)

## Die WERKSTÜCK-Sicht: der schwebende Würfel allein im Bild. center ist seine
## Weltmitte, half seine halbe Raumdiagonale - so passt er in JEDER Drehung ins
## Bild, und der Ausschnitt springt beim Drehen nicht. Wie frame_rect ein
## TEMPORÄRER Rahmen: kein Moduswechsel, keine Meldung. Die Kamera steht still,
## der Spieler dreht den WÜRFEL, nicht den Blick.
func zoom_die_focus(center: Vector3, half: float) -> void:
	if die_focus:
		return
	die_focus = true
	var target_origin := center - ZOOM_FORWARD * _fit_distance(Vector2(half, half), DIE_FOCUS_MARGIN)
	anchor_basis = ZOOM_BASIS
	anchor_origin = target_origin
	tilt_offset = Vector2.ZERO
	_applied_offset = Vector2.ZERO
	_tilt_resume_time = -1.0
	_animate_to(target_origin, ZOOM_BASIS)

## Der Fokus endet - die Fahrt zurück gehört dem Aufrufer (restore_pose).
func zoom_die_focus_out() -> void:
	die_focus = false

## Ruhelage des gegriffenen Würfels: die Dreiviertel-Ansicht aus DIE_FOCUS_POSE,
## in den Achsen der Werkstück-Kamera. Der Spieler dreht von hier aus weiter.
static func die_focus_basis() -> Basis:
	return ZOOM_BASIS * Basis.from_euler(Vector3(
		deg_to_rad(DIE_FOCUS_POSE.x), deg_to_rad(DIE_FOCUS_POSE.y), deg_to_rad(DIE_FOCUS_POSE.z)))

## Die gemerkte Lage: Anker-Ursprung, Anker-Achsen und ob die Freikamera stand.
func camera_pose() -> Dictionary:
	return {"origin": anchor_origin, "basis": anchor_basis, "free": free_camera}

## Zurück an eine gemerkte Lage, ebenfalls ohne Moduswechsel; stand die Freikamera,
## steigt sie am Ende der Fahrt an Ort und Stelle wieder ein.
func restore_pose(pose: Dictionary, duration := ZOOM_DURATION) -> void:
	if pose.is_empty():
		return
	var origin: Vector3 = pose.get("origin", anchor_origin)
	var pose_basis: Basis = pose.get("basis", anchor_basis)
	anchor_basis = pose_basis
	anchor_origin = origin
	tilt_offset = Vector2.ZERO
	_applied_offset = Vector2.ZERO
	_tilt_resume_time = -1.0
	_animate_to(origin, pose_basis, duration)
	if bool(pose.get("free", false)) and active_tween != null:
		active_tween.chain().tween_callback(begin_free)

## Verschiebt den Zoom-Blick auf target_point OHNE den Modus zu wechseln (z.B.
## von Charm zu Charm) - gleicher Winkel/Abstand, nur der Blickpunkt wandert.
func pan_to(target_point: Vector3) -> void:
	if mode == Mode.OVERVIEW:
		return
	var target_origin := target_point - ZOOM_FORWARD * ZOOM_DISTANCE
	anchor_basis = ZOOM_BASIS
	anchor_origin = target_origin
	tilt_offset = Vector2.ZERO
	_animate_to(target_origin, ZOOM_BASIS)

## Zurück zur Übersicht; No-Op, falls bereits dort. Die Freikamera ist die
## Ausnahme: dort STEHT der Modus schon auf OVERVIEW, die Kamera aber mitten auf
## dem Tisch - sie muss trotzdem heimfahren.
func zoom_out(duration := ZOOM_DURATION, ease_mode := Tween.EASE_IN_OUT) -> void:
	if mode == Mode.OVERVIEW and not free_camera:
		return
	workshop_close = false
	die_focus = false
	var changed := mode != Mode.OVERVIEW
	mode = Mode.OVERVIEW
	if changed:
		mode_changed.emit(mode)
	anchor_basis = base_basis
	anchor_origin = base_origin
	tilt_offset = Vector2.ZERO
	_animate_to(base_origin, base_basis, duration, ease_mode)

## Rechteck der Anzeigefläche in Welt-XZ (Grenze der Freikamera).
func configure_glide_bounds(bounds: Rect2) -> void:
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		glide_bounds = bounds

## Schaltet auf die Freikamera (false = hier nicht erlaubt). Die LAGE bleibt, wo
## der Spieler sie sieht - nur der Modus fällt auf OVERVIEW, ohne dorthin zu
## fahren. Eine laufende Fahrt ist unantastbar: sie hat ein Ziel.
func begin_free() -> bool:
	if free_camera:
		return true
	if workshop_close or die_focus or mode == Mode.TITLE or is_animating:
		return false
	var origin := global_transform.origin
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, -global_transform.basis.z)
	var look := (hit as Vector3) if hit is Vector3 else anchor_origin + ZOOM_FORWARD * ZOOM_DISTANCE
	_free_target = clamp_to_bounds(Vector3(look.x, 0.0, look.z), glide_bounds, GLIDE_BOUNDS_MARGIN)
	_free_distance = clampf(origin.distance_to(_free_target), FREE_ZOOM_MIN, free_zoom_max())
	_free_zoom_goal = _free_distance
	# Angeglichen wird nur der RUHE-Winkel; die Rundschau-Neigung läuft
	# ununterbrochen weiter, sonst ruckte der Einstieg um ihren Betrag.
	_free_from_basis = anchor_basis
	_free_blend = 0.0
	_free_velocity = Vector3.ZERO
	_free_moving = false
	free_camera = true
	if mode != Mode.OVERVIEW:
		mode = Mode.OVERVIEW
		mode_changed.emit(mode)
	return true

## Ein Bild Freikamera: dir in Bild-Achsen (x = rechts, y = oben), schon
## normalisiert. Wird auch mit ZERO gerufen - die Zoomfahrt läuft weiter.
func free_step(dir: Vector2, delta: float) -> void:
	if not free_camera:
		return
	_free_moving = dir != Vector2.ZERO
	var wish := (GLIDE_RIGHT * dir.x + GLIDE_UP * dir.y) * free_speed(_free_distance)
	_free_velocity = _free_velocity.lerp(wish, clampf(delta / GLIDE_ACCEL, 0.0, 1.0))
	_free_target += _free_velocity * delta
	if not is_equal_approx(_free_distance, _free_zoom_goal):
		var next := lerpf(_free_distance, _free_zoom_goal,
			clampf(delta / FREE_ZOOM_SMOOTH, 0.0, 1.0))
		# Zoom auf den Cursor: der Punkt unter ihm bleibt liegen. Bild für Bild
		# neu gefragt, damit er es über die ganze Annäherung tut.
		var cursor: Variant = _cursor_on_table()
		if cursor != null:
			_free_target = zoom_anchor(_free_target, cursor as Vector3, next / _free_distance)
		_free_distance = next
	_free_target = clamp_to_bounds(_free_target, glide_bounds, GLIDE_BOUNDS_MARGIN)
	_free_blend = minf(_free_blend + delta / FREE_SETTLE, 1.0)
	anchor_basis = _free_from_basis.slerp(ZOOM_BASIS, smoothstep(0.0, 1.0, _free_blend))
	anchor_origin = _free_target - _free_forward() * _free_distance
	global_transform = Transform3D(anchor_basis, anchor_origin)

## Eine Radkerbe (positiv = heran). Ändert nur das ZIEL - die Fahrt dorthin
## läuft in free_step, damit jede Kerbe weich anschließt.
func free_zoom(notches: float) -> void:
	if not free_camera:
		return
	_free_zoom_goal = zoom_step_distance(_free_zoom_goal, notches,
		FREE_ZOOM_MIN, free_zoom_max())

## Blickrichtung der Freikamera - während des Winkel-Angleichs die eben
## gemischte, danach der reine Zoomblick.
func _free_forward() -> Vector3:
	return -anchor_basis.z

## Punkt unter dem Mauszeiger auf der Tischebene; null, wenn der Strahl sie nicht
## trifft (Blick über den Horizont) oder es keinen Viewport gibt.
func _cursor_on_table() -> Variant:
	var viewport := get_viewport()
	if viewport == null:
		return null
	var mouse := viewport.get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		project_ray_origin(mouse), project_ray_normal(mouse))
	return hit if hit is Vector3 else null

func _animate_to(target_origin: Vector3, target_basis: Basis,
		duration := ZOOM_DURATION, ease_mode := Tween.EASE_IN_OUT) -> void:
	if active_tween:
		active_tween.kill()
	is_animating = true
	# DER Ausstieg aus der Freikamera: jede gerechnete Fahrt gewinnt, egal wer
	# sie auslöst. Ein Aufrufer muss daran nie denken.
	free_camera = false
	_free_moving = false

	var from_basis := global_transform.basis
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE).set_ease(ease_mode)
	active_tween.set_parallel(true)
	active_tween.tween_property(self, "global_position", target_origin, duration)
	active_tween.tween_method(_apply_basis_slerp.bind(from_basis, target_basis), 0.0, 1.0, duration)
	active_tween.chain().tween_callback(func() -> void:
		is_animating = false)

func _apply_basis_slerp(t: float, from_basis: Basis, to_basis: Basis) -> void:
	global_transform.basis = from_basis.slerp(to_basis, t)
