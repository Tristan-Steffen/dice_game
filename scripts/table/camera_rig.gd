class_name CameraRig
extends Camera3D
## Spielkamera: feste Übersicht mit begrenztem Maus-Rundschauen plus
## Zoom-Ziele (Grube/Trays/Kombis/Charms/Hub). Mausrad hoch oder Linksklick auf
## eine Zone zoomt heran, Rad runter oder Rechtsklick zurück; auch im Zoom
## bleibt leichtes Rundschauen. Alle Wege lösen dieselben STUFEN aus - die
## Distanzen sind gerechnet, es gibt bewusst kein freies Heranfahren.

enum Mode { OVERVIEW, PIT, POOL, DISCARD, COMBOS, CHARMS, HUB, SIDE_BETS, SCORE, SLOTS, CHIPS, WORKSHOP, SECRET_SHOP, TITLE }

signal mode_changed(new_mode: Mode)

const TILT_MAX_UP_DEGREES := 5.0
const TILT_MAX_DOWN_DEGREES := 5.0
const TILT_MAX_YAW_DEGREES := 5.0
# Im Zoom bewusst kleine Winkel, damit das Ziel im Blick bleibt.
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

## Der Schwarzmarkt ist das kleinste Fenster (die Glaskante lässt unter den
## Automaten nur eine schmale Tasche): keine 500 Textur-px breit. Die Distanz ist
## deshalb der TEXTUR-Auflösung gerechnet, nicht dem Bildeindruck: bei Abzug 11
## lag das Fenster auf ~780 Bildschirm-px, also 0,58 Textur-px je Bildschirm-px -
## eine 1,7-fache Hochskalierung, die als "360p" gelesen wurde. Bei Abzug 4 füllen
## seine 451 Textur-px ~440 Bildschirm-px, das Bild wird also nie mehr gestreckt.
## Mehr Textur ginge nur über TableScreen.SUPERSAMPLE, und das kostet den ganzen
## Tisch (gemessen: 3 -> 4 hebt die Bildzeit von 35 auf 58 ms und erreicht
## trotzdem nur 0,77 tex/px). Die verlorene Bildgröße holt SecretShopView über
## seine kleinere CONTENT_UNITS zurück.
const SECRET_SHOP_ZOOM_DISTANCE_CUT := 4.0

## Die Werkbank rahmt Trays UND Fenster; darunter schneidet der obere Bildrand
## die erste Tray-Reihe an, und die ist Klickziel.
const WORKSHOP_ZOOM_DISTANCE_BONUS := 1.0

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
## HANDVERSCHIEBUNG der Nahsicht, falls der Ausschnitt anders sitzen soll: die
## Kamera wandert um x nach rechts und y nach oben (Weltmeter, in Bildrichtung),
## das Bild also gegenläufig. Null = die gerechnete Lage, die die Trays sicher
## draußen hält - wer hier schiebt, holt sie oben wieder herein.
const WORKSHOP_CLOSE_AIM := Vector2.ZERO

## Zoom-Blickpunkte - nur Rückfallwerte: scene_root überschreibt sie aus den
## echten Weltpositionen (configure_*_target), damit Editor-Verschiebungen den
## Zoom automatisch mitnehmen.
var pool_target := Vector3(-23.75, 0.4, 12)
var discard_target := Vector3(-26, 0.4, -12)
var combos_target := Vector3(-8, 0, 0)
var pit_target := Vector3.ZERO
var charms_target := Vector3(24, 0, 0)
var hub_target := Vector3(-24, 0, 0)
var side_bets_target := Vector3(0, 0, 24)
var score_target := Vector3(-4, 0, 0)
var slots_target := Vector3(-24, 0, -22)
var secret_shop_target := Vector3(-24, 0, -12)
var chips_target := Vector3(0, 1.5, 10)
var workshop_target := Vector3(-24, 0, 22)
## Nahsicht-Ziel + halbe Ausmaße der Werkbank-Ecke ohne Trays (x = entlang
## Welt-Z, y = entlang Welt-X) - wie beim Titel aus den echten Rechtecken.
var workshop_close_target := Vector3(-24, 0, 22)
var workshop_close_half := Vector2(12.0, 10.0)
## Steht die Werkbank in der Nahsicht? Dort steht die Kamera zusätzlich STILL.
var workshop_close: bool = false
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

var base_basis: Basis
var base_origin: Vector3

# Ruhelage des aktuellen Modus, um die das Rundschauen pendelt.
var anchor_basis: Basis
var anchor_origin: Vector3

var mode: Mode = Mode.OVERVIEW
var is_animating: bool = false
## Solange gesetzt, hält die Kamera ihre Ausrichtung (z.B. während der Spieler
## die Würfel-Projektion dreht), damit die Geste nicht zugleich den Blick schwenkt.
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

func _process(delta: float) -> void:
	# Im Titel-HUD steht die Kamera still: das Rundschauen schwenkte den Filz
	# ins Bild und verriete, dass das Menü auf einem Tisch liegt. In der
	# Werkbank-Nahsicht ebenso: dort ist der Rahmen randvoll, jedes Schwenken
	# holte die Trays herein.
	if is_animating or tilt_locked or mode == Mode.TITLE or workshop_close:
		return

	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	var mouse := get_viewport().get_mouse_position()
	var nx: float = clamp((mouse.x / vp_size.x) * 2.0 - 1.0, -1.0, 1.0)
	var ny: float = clamp((mouse.y / vp_size.y) * 2.0 - 1.0, -1.0, 1.0)

	var pitch_max: float
	var yaw_max: float
	if mode == Mode.OVERVIEW:
		# ny > 0 = Maus unten -> Blick Richtung Tisch (eigener Winkelbereich).
		pitch_max = TILT_MAX_DOWN_DEGREES if ny > 0.0 else TILT_MAX_UP_DEGREES
		yaw_max = TILT_MAX_YAW_DEGREES
	else:
		pitch_max = ZOOM_TILT_MAX_PITCH_DEGREES
		yaw_max = ZOOM_TILT_MAX_YAW_DEGREES
	var target_tilt := Vector2(-ny * pitch_max, -nx * yaw_max)
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

## Tray-Blickpunkte aus den echten Weltpositionen (Editor bleibt die Quelle).
func configure_tray_targets(pool: Vector3, discard: Vector3) -> void:
	pool_target = pool
	discard_target = discard

func configure_combos_target(target: Vector3) -> void:
	combos_target = target

func configure_pit_target(target: Vector3) -> void:
	pit_target = target

func configure_charms_target(target: Vector3) -> void:
	charms_target = target

func configure_hub_target(target: Vector3) -> void:
	hub_target = target

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

func configure_workshop_target(target: Vector3) -> void:
	workshop_target = target

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

## Beide Achsen getrennt gerechnet, weil sie bei der Werkbank fast gleichauf
## liegen und sonst mal die eine, mal die andere anschlägt. Diese beiden Zugaben
## sind die Stellschrauben für "wie nah": bei einem hochformatigen Fenster
## entscheidet die SEITEN-Zugabe allein, bei einem breiten die andere.
func workshop_close_distance() -> float:
	return maxf(
		_fit_distance(Vector2(workshop_close_half.x, 0.0), WORKSHOP_CLOSE_SIDE_MARGIN),
		_fit_distance(Vector2(0.0, workshop_close_half.y), WORKSHOP_CLOSE_MARGIN))

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
	global_transform = Transform3D(TITLE_BASIS, target_origin)

## Der Rückzieher aus dem Titel-HUD auf den ganzen Tisch.
func reveal_table() -> void:
	zoom_out(REVEAL_DURATION, Tween.EASE_OUT)

## Fährt zum Zoom-Ziel; No-Op, wenn schon dort.
func zoom_to(target_mode: Mode, duration := ZOOM_DURATION,
		ease_mode := Tween.EASE_IN_OUT) -> void:
	if mode == target_mode:
		return
	var target_point: Vector3
	match target_mode:
		Mode.PIT:
			target_point = pit_target
		Mode.POOL:
			target_point = pool_target
		Mode.DISCARD:
			target_point = discard_target
		Mode.COMBOS:
			target_point = combos_target
		Mode.CHARMS:
			target_point = charms_target
		Mode.HUB:
			target_point = hub_target
		Mode.SIDE_BETS:
			target_point = side_bets_target
		Mode.SCORE:
			target_point = score_target
		Mode.SLOTS:
			target_point = slots_target
		Mode.SECRET_SHOP:
			target_point = secret_shop_target
		Mode.CHIPS:
			target_point = chips_target
		Mode.WORKSHOP:
			target_point = workshop_target
		_:
			return
	var distance := ZOOM_DISTANCE
	if target_mode == Mode.PIT:
		distance += PIT_ZOOM_DISTANCE_BONUS
	# Der Chip-Haufen ist klein: näher heranfahren als an die Screen-Fenster.
	if target_mode == Mode.CHIPS:
		distance -= CHIPS_ZOOM_DISTANCE_CUT
	if target_mode == Mode.SECRET_SHOP:
		distance -= SECRET_SHOP_ZOOM_DISTANCE_CUT
	if target_mode == Mode.WORKSHOP:
		distance += WORKSHOP_ZOOM_DISTANCE_BONUS
	var target_origin := target_point - ZOOM_FORWARD * distance
	workshop_close = false  # jeder Moduswechsel verlässt die Nahsicht
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
	var target_origin := workshop_target \
		- ZOOM_FORWARD * (ZOOM_DISTANCE + WORKSHOP_ZOOM_DISTANCE_BONUS)
	anchor_basis = ZOOM_BASIS
	anchor_origin = target_origin
	tilt_offset = Vector2.ZERO
	mode_changed.emit(mode)  # siehe zoom_workshop_close
	_animate_to(target_origin, ZOOM_BASIS)

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

## Zurück zur Übersicht; No-Op, falls bereits dort.
func zoom_out(duration := ZOOM_DURATION, ease_mode := Tween.EASE_IN_OUT) -> void:
	if mode == Mode.OVERVIEW:
		return
	workshop_close = false
	mode = Mode.OVERVIEW
	mode_changed.emit(mode)
	anchor_basis = base_basis
	anchor_origin = base_origin
	tilt_offset = Vector2.ZERO
	_animate_to(base_origin, base_basis, duration, ease_mode)

func _animate_to(target_origin: Vector3, target_basis: Basis,
		duration := ZOOM_DURATION, ease_mode := Tween.EASE_IN_OUT) -> void:
	if active_tween:
		active_tween.kill()
	is_animating = true

	var from_basis := global_transform.basis
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE).set_ease(ease_mode)
	active_tween.set_parallel(true)
	active_tween.tween_property(self, "global_position", target_origin, duration)
	active_tween.tween_method(_apply_basis_slerp.bind(from_basis, target_basis), 0.0, 1.0, duration)
	active_tween.chain().tween_callback(func() -> void: is_animating = false)

func _apply_basis_slerp(t: float, from_basis: Basis, to_basis: Basis) -> void:
	global_transform.basis = from_basis.slerp(to_basis, t)
