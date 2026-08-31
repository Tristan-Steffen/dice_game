class_name LiftShaftView
extends Node3D
## Der SCHACHT einer Hebebühne: die Maschine, mit der eine Auslage auffährt. Ein
## Loch im Tisch (das schneidet der Shader - TableScreen führt die Liste), darunter
## vier Wände und ein Lichtsaum knapp unter der Kante; der BODEN ist die bewegliche
## PLATTFORM. Rein per Code gebaut wie PackPitView - kein .tscn.
## Die Schnittkante steht NACKT: es gibt keinen Kragen und keine Fuge auf der
## Fläche. Was den Schacht lesbar macht, liegt IN ihm (der Lichtsaum), nicht auf
## der Anzeige darüber.
## Der Schacht ist SYMMETRISCH: Rück- und Vorderwand sind beide nur ein Sturz, unter
## dem ein Öffnungsband offen steht. Hinten (Welt-+X, Bildschirm-oben) ist der
## EINGANG - dort schiebt die Ware herein; vorn (Welt-−X, zum Betrachter) ist der
## AUSGANG - dort schiebt sie hinaus. Hinter jedem Band liegt ein HOHLRAUM, in dem
## die Ware wartet bzw. verschwindet; jeder ist mit Wand, Flanken und Decke
## geschlossen, und eine durchgehende Sohle spannt über beide, sonst sähe man durch
## den offenen Schacht auf den Raumboden.
## Die Plattform IST im bündigen Stand die Anzeige: ihre Deckhaut zeigt per Shader
## das ECHTE Bild des Displays an ihrer Stelle (TableScreen.display_skin), also ist
## der bündige Stand pixelidentisch - und beim Senken trägt die Platte ihr Stück
## Anzeige sichtbar mit hinunter (der Mahjong-Deckel).
## Drei Tischregeln wie in der Grube: nur EMISSION (die Bodenkacheln vertragen
## 16 Lichter), das Ruhelicht bleibt gedämpft, und gespiegelt wird nichts - ein
## Loch hat kein Spiegelbild.
## Neben "zu" und "fährt" kennt er einen dritten Zustand: den PARK - Loch offen,
## Plattform auf der ANZEIGE-Tiefe, Ware sichtbar darin (park_hard/run_park/run_rise/
## run_leave_park). Das ist ein ENDZUSTAND, den der Wirt jederzeit hart schreiben darf.
## Zum EIN- und AUSFAHREN darf er TIEFER sinken als der Park steht (travel_share): die
## Band-Ebene liegt dann unter der Sohle der Nachbargrube, und wartende Ware kann in
## deren offenem Loch nicht mehr erscheinen. Das Gruben-BILD bleibt davon unberührt.
## Über der geparkten Grube liegt der SCHIRM: zwei fast durchsichtige Paneele, die
## aus linker und rechter Wand herausfahren und sich in der Mitte treffen. Er wird
## von draußen BESTELLT (order_cover für die Gewinn-Zeile, order_cover_goal für die
## STEHENDE Bedingungs-Zeile) - eine Auslage ohne Bestellung baut keinen.
## Ebenso bestellt wird die WANDHAUT (order_skin): eine gemeldete Textur auf allen
## vier Wänden, beiden Stürzen und den BLENDEN vor den Öffnungsbändern. Geschlossen
## liest die Maschine damit auf allen vier Seiten gleich; ein Band öffnet nur für
## seinen Schritt, und nur das, welches der Schritt wirklich benutzt - oder im
## STAND per run_band, dem einen Handgriff, der KEIN Fahrplan ist (eine Ablage-
## Reihe schiebt in die geparkte Grube, die Plattform rührt sich nicht).

## Wandstärke und Dicke der Plattformplatte.
const WALL := 0.10
const DECK := 0.09

## Die Zeiten der Maschine: Senken, Einschub und Hub sind LINEAR - eine Maschine
## beschleunigt nicht weich -, und am Ende rastet die Bühne mit einem kurzen
## Setz-Dip ein. Der Zonen-Versatz gehört dem Wirt, diese Zahlen der Maschine.
const SINK_TIME := 0.4
const PUSH_TIME := 0.35
const LIFT_TIME := 0.45
## Der Dip ist ein festes Körpermaß, kein Anteil der Fahrt: eine kurze Bahn setzte
## sonst unsichtbar ein, und der Tisch blickt fast senkrecht darauf.
const DIP := DataCellView.HEIGHT * 0.075
const DIP_TIME := 0.08

## Wie weit die Wände unter die Schnittkante rücken - so sieht man ihre Oberkante
## nie über der Fläche stehen.
const WALL_SINK := 0.025

## Der Lichtsaum knapp unter der nackten Kante: ohne ihn verschluckt der dunkle
## Raum die Wände und der Schacht läse sich als schwarzes Rechteck statt als
## Vertiefung. Er liegt IM Schacht, er umrandet die Fläche nicht.
const GLOW_H := 0.05
const GLOW_DROP := 0.08
## Wie weit er von der Wand nach innen greift.
const GLOW_IN := 0.06
const GLOW_COLOR := Color(0.42, 0.86, 0.99)
const GLOW_ENERGY := 1.5

const WALL_ALBEDO := Color(0.070, 0.066, 0.098)
const WALL_EMISSION := Color(0.20, 0.23, 0.34)
const WALL_EMISSION_ENERGY := 0.95
## Der Hohlraum hinter dem Öffnungsband ist die dunkelste Fläche der Maschine -
## dort wartet die Ware, und dort soll das Auge nichts finden.
const CAVITY_ALBEDO := Color(0.028, 0.026, 0.042)
const CAVITY_EMISSION := Color(0.10, 0.12, 0.20)
const CAVITY_EMISSION_ENERGY := 0.45

## Die HAUT der Deckfläche: das echte Bild der Anzeige an ihrer Stelle. GEMELDET
## von draußen (TableScreen.display_skin) - ein Schacht greift nicht in die Szene.
## Ohne Haut (Probe, Test ohne Tisch) ist die Platte schlicht Maschine.
var deck_skin: Material = null:
	set(value):
		deck_skin = value
		_apply_deck_skin()
## Ihre Flanken sind Maschine, nicht Anzeige.
const DECK_SIDE := Color(0.16, 0.17, 0.24)
const DECK_EMISSION := Color(0.30, 0.34, 0.48)
const DECK_EMISSION_ENERGY := 0.55

## Die Höhe der Öffnungsbänder als Anteil der Schachttiefe: hoch genug für das
## höchste Stück (die Tiefe ist dessen Maß mal VitrineView.SHAFT_ROOM, also muß
## dieser Anteil über 1/SHAFT_ROOM liegen - ein Test hält das fest), niedrig genug,
## dass beidseits ein Sturz stehen bleibt.
const MOUTH_SHARE := 0.72
## Wie weit ein Hohlraum hinter sein Band reicht - dort wartet die Ware bzw. dorthin
## verschwindet sie. Sie wartet an seinem ENDE, denn durch das Öffnungsband blickt
## man ein Stück weit hinein: näher gestellt sähe man die Ware im Schacht liegen,
## bevor sie einfährt.
const CAVITY_SHARE := 1.05
## Luft zwischen dem Ende eines Hohlraums und der gemeldeten Reichweite. Die
## Reichweite endet an der WAND der Nachbarin, und wer sie ganz ausschöpft, stellt
## seine Stirnwand GENAU in deren Innenwand-Ebene: zwei koplanare Flächen, die sich
## im Tiefenpuffer streiten und die Nachbargrube in flimmernde Streifen schneiden.
## Ein Viertel Wandstärke weniger, und die Stirnwand endet IN der Nachbarwand statt
## in ihrer Ebene - sie bleibt gedeckt, und es entsteht kein Durchblick.
const REACH_CLEAR := WALL * 0.25

## Luft unter der gesenkten Plattform, damit ihre Unterseite nicht auf der Sohle
## aufsetzt und die beiden im Tiefenpuffer kämpfen.
const SOLE_CLEAR := 0.04

## Der GRUBEN-SCHIRM. Er sitzt KNAPP unter der Schnittkante und ÜBER dem Lichtsaum
## (GLOW_DROP), damit der Saum weiter die Tiefe trägt und der Schirm nur deckt.
const COVER_DROP := 0.034
const COVER_H := 0.010
## Ein eigener kurzer Takt: der Schirm fährt NACH dem Absenken aus und VOR jeder
## Fahrt wieder ein - nichts durchstößt ihn.
const COVER_TIME := 0.24
## Fast durchsichtig: die Ware in der Grube bleibt zu sehen, der Deckel liest sich
## als Glas. Nur Emission, nichts gespiegelt - ein Loch hat kein Spiegelbild.
const COVER_ALPHA := 0.13
const COVER_EMISSION_ENERGY := 0.85

## Die Aufschrift des Schirms: EIN Label, flach auf den Paneelen, in Tisch-
## Leserichtung, das ZWEI Zeilen trägt. Steht eine BEDINGUNG an, ist sie sichtbar,
## sobald der Schirm ausgefahren ist; der Zeiger schaltet auf die GEWINN-Zeile um.
## Ohne bestellte Bedingung bleibt die alte Regel: ohne Zeiger sagt der Deckel nichts.
const COVER_FONT := 64
## Anteil der Grube, den die Zeile höchstens einnimmt: längs (Welt-Z) ihre Breite,
## quer (Welt-X) ihre Zeilenhöhe. Der kleinere der beiden Grade gewinnt.
const COVER_TEXT_SHARE := 0.80
const COVER_LINE_SHARE := 0.30
## Und wieviele Zeilen sie höchstens umbricht: eine lange Gewinn-Zeile (der
## Press-Schub nennt Limit UND Chance) schrumpfte einzeilig zur Unlesbarkeit.
const COVER_LINES := 2
const COVER_OUTLINE := 14
const COVER_HOVER_TIME := 0.18
## Die Zeile trägt IMMER dasselbe helle Gold - der Akzent der Wette bleibt am Saum des
## Schirms. Überhellt aus der Haus-Goldquelle, damit sie über der Ware leuchtet.
const COVER_TEXT_GAIN := 1.6
## Ihr Umriß ist ein DUNKLES Gold derselben Familie: er trägt den Kontrast über heller
## Ware (dem Chip-Stapel), und im Einblenden liest zu keinem Zeitpunkt etwas Schwarzes.
const COVER_OUTLINE_GAIN := 0.45
## Die STEHENDE Bedingungs-Zeile trägt dagegen den GEMELDETEN Ton (grün/rot/neutral) -
## sie sagt einen Zustand, kein Geld. Dieselbe Familie, nur überhellt bzw. gedunkelt.
const COVER_GOAL_TEXT_GAIN := 1.35
const COVER_GOAL_OUTLINE_GAIN := 0.30
## Ihr AUFLEUCHTEN, wenn eine Steuer-Buchung als Meteor eintrifft: kurz heller, dann
## zurück in den gemeldeten Ton.
const COVER_FLASH_GAIN := 2.2
const COVER_FLASH_TIME := 0.5

## Die WANDHAUT und ihre BLENDEN. Die Haut ist eine gemeldete Textur; ihr WELTMASS ist
## eine Kachel, und weil sie per Welt-Triplanar liegt, laufen ihre Leuchtlinien als
## GLEICH HOHE Ringe um alle vier Wände - es gibt keine UV-Naht und keinen
## Maßstabssprung zwischen Seitenwand, Sturz und Blende.
## Die Map teilt eine Kachel in ~0,21/0,50/0,79: bei 2,0 stehen damit in der 2,0 tiefen
## Grube genau DREI Bänder (1,5 streift die Wand, 4,0 läßt eine einzige unter der Kante
## stehen und doppelt den Lichtsaum), und der Sprung der längs NICHT nahtlosen Map
## fällt genau auf die Sohle.
const SKIN_TILE := 2.0
## Mit Haut bringt die Textur ihren eigenen Ton mit: der fast schwarze Grundton der
## nackten Maschine würde sie ein zweites Mal abdunkeln.
const SKIN_ALBEDO := Color(0.34, 0.35, 0.44)
## Lesbar wird sie im dunklen Schacht nur über EMISSION aus derselben Map - multipliziert,
## nicht addiert, sonst legte ein konstanter Schleier die Paneele flach. Der Ton bleibt
## fast neutral-kühl, damit das Teal der Linien Teal bleibt; bei 0,9 verschwinden die
## Paneele, bei 1,5 treten die Linien neben den Lichtsaum statt unter ihn.
const SKIN_EMISSION := Color(0.55, 0.60, 0.72)
const SKIN_EMISSION_ENERGY := 1.3
## Die beiden Öffnungsbänder als Flaggen - ein Schritt nennt, welches er benutzt.
const BAND_BACK := 1
const BAND_FRONT := 2
## Der Takt einer Blende liegt IN den bestehenden Schlägen (Senken, Hub, Schirm): er
## muß unter den kürzesten von ihnen passen, dann kostet ein Band keine Zykluszeit.
const SHUTTER_TIME := 0.22

## Ein Schacht steht offen bzw. ist zu. GEMELDET nach draußen, weil das LOCH in der
## Anzeige den Shadern gehört und ein Körper nicht in sie greift.
signal opened(at: Vector3, half_extents: Vector2)
signal closed

## Wie lange EIN Zyklus dauert - der ehrliche Deckel jedes Auftritts.
static func cycle_time() -> float:
	return SINK_TIME + PUSH_TIME + LIFT_TIME + DIP_TIME

## Der TAUSCH ist derselbe Zyklus: der Einschub trägt nur zwei Fuhren statt einer -
## die alte hinaus, die neue herein, EIN Band-Schritt.
static func swap_cycle_time() -> float:
	return SINK_TIME + PUSH_TIME + LIFT_TIME + DIP_TIME

## Und der ABGANG ebenso - nur fährt die Platte am Ende LEER herauf.
static func exit_cycle_time() -> float:
	return SINK_TIME + PUSH_TIME + LIFT_TIME + DIP_TIME

## Der KAUF ist derselbe Zyklus in klein: nur die SEKTION unter dem gekauften Stück
## fährt. Dieselben vier Schläge, also dieselbe Dauer.
static func take_cycle_time() -> float:
	return SINK_TIME + PUSH_TIME + LIFT_TIME + DIP_TIME

## Wann das gekaufte Stück AUSSER SICHT ist: nach Senken und Band-Schritt. Dort
## startet seine Lieferung - auf die leer hochfahrende Sektion wartet kein Komet.
static func take_out_time() -> float:
	return SINK_TIME + PUSH_TIME

## Die drei PARK-Fahrpläne kennen ZWEI Ebenen - den Parkstand und die Band-Ebene -,
## und ob die auseinanderliegen, weiß nur der einzelne Schacht. Ihre Deckel hängen
## darum an ihm, nicht an der Klasse.
## Der PARK-Zyklus: gesenkt auf die Band-Ebene, ein Band-Schritt, zurück auf den
## Parkstand - und dort bleibt es; zuletzt fährt der Schirm aus. Fallen beide Ebenen
## zusammen, entfällt der Hub. Ohne bestellten Schirm ist die Fahrt kürzer.
func park_cycle_time() -> float:
	return SINK_TIME + PUSH_TIME + _park_leg(LIFT_TIME) + COVER_TIME

## Die AUFFAHRT aus dem Park kennt weder Senken noch Band-Schritt - nur der Schirm
## muss zuerst fort, sonst stieße die Ware ihn durch. Sie läuft vom Parkstand bündig
## herauf und weiß von der Band-Ebene nichts.
static func rise_cycle_time() -> float:
	return COVER_TIME + LIFT_TIME + DIP_TIME

## Der ABGANG aus dem Park: Schirm ein, hinunter auf die Band-Ebene, ein Band-Schritt,
## dann hebt die LEERE Platte.
func leave_park_time() -> float:
	return COVER_TIME + _park_leg(SINK_TIME) + PUSH_TIME + LIFT_TIME + DIP_TIME

## Ein Schlag, den es nur mit Tieffahrt gibt: liegen Park und Band-Ebene aufeinander,
## ist der Weg dazwischen null und der Schlag fällt aus.
func _park_leg(beat: float) -> float:
	return beat if park_rise() > 0.001 else 0.0

var _wall_material: StandardMaterial3D
var _cavity_material: StandardMaterial3D
var _glow_material: StandardMaterial3D
var _deck_side_material: StandardMaterial3D
## Die Deckhaut selbst - der eine Ort, an dem die gemeldete Haut landet.
var _deck_top: MeshInstance3D

## Zuletzt gestellte Maße - der Abgleich stellt idempotent nach.
var center := Vector3.ZERO
var half := Vector2.ZERO
var depth := 0.0
## Wie weit die Maschine HÖCHSTENS hinter ihrer Öffnung Platz nehmen darf (0 = so
## weit sie will). GEMELDET von draußen: ob nebenan ein zweites Loch offen steht,
## weiß der Wirt, nicht der Schacht - und ein Hohlraum unter einem fremden Loch läse
## sich dort als schwarzer Balken.
var cavity_reach := 0.0
## Wieviel TIEFER als der Parkstand die Maschine zum EIN- und AUSFAHREN sinkt (1 = gar
## nicht). GEMELDET von draußen wie cavity_reach: nur eine Grube, die OFFEN stehen
## bleibt, hat eine Nachbarin, in deren Loch die wartende Ware sonst erscheint - der
## Hohlraum ist kürzer als ein Stück, also ragt es hinaus. Auf doppelter Fahrt-Tiefe
## liegt es unter der Sohle der Nachbarin. Die ANZEIGE-Tiefe (der Park) bleibt davon
## unberührt: sie ist das sichtbare Gruben-Bild.
var travel_share := 1.0

var _platform: Node3D
## Mit welcher Reichweite und welcher Fahrt-Tiefe der stehende Körper gebaut wurde -
## sonst bliebe eine geänderte Meldung unbeachtet.
var _built_reach := -1.0
var _built_travel := -1.0
## Der EINE Tween des Zyklus - Platte und Ware fahren darin gemeinsam.
var _tween: Tween

## Der SCHIRM, sofern bestellt: seine Gewinn-Zeile und der Akzent seiner Wette.
var cover_text := ""
var cover_tint := GLOW_COLOR
## Und die STEHENDE Zeile darunter (leer = keine): die Bedingung samt Live-Stand, im
## gemeldeten Zustands-Ton. Der Schacht formuliert nichts, er bekommt sie fertig.
var cover_goal := ""
var cover_goal_tint := GLOW_COLOR
## Welche der beiden zuletzt auf dem Label stand - der Wechsel am Hover-Schwellwert
## schreibt Text, Grad und Ton neu, jedes andere Bild nur das Alpha.
var _cover_shown := ""
var _cover_wanted := false
var _cover: Node3D
var _cover_left: Node3D
var _cover_right: Node3D
var _cover_label: Label3D
var _cover_material: StandardMaterial3D
## 0 = in der Wand, 1 = geschlossen. Und wieviel von der Aufschrift zu sehen ist -
## dazu, wohin sie GEFÜHRT wird. Kein Tween: die Zeile wird je Bild gefragt, und ein
## Tween, den jedes Bild neu startet, kommt nie an (er kriecht exponentiell).
var _cover_share := 0.0
var _hover_share := 0.0
var _hover_goal := 0.0
## Das Aufleuchten der stehenden Zeile: 1 = frisch eingeschlagen, 0 = Ruhelicht.
var _goal_flash := 0.0
var _flash_tween: Tween

## Die WANDHAUT, sofern bestellt, und die beiden Blenden, die sie mitträgt.
var wall_skin: Texture2D = null
var _skin_wanted := false
var _shutters: Node3D
var _shutter_back: Node3D
var _shutter_front: Node3D
## 0 = zu (das Band ist blind), 1 = ganz offen.
var _back_open := 0.0
var _front_open := 0.0
## Der eigene Tween des Bandes im STAND (run_band) - er gehört zu keinem Fahrplan.
var _band_tween: Tween

func _init(shaft_name := "LiftShaft") -> void:
	name = shaft_name
	visible = false  # die Maschine existiert nur während eines Auftritts
	set_process(false)  # nur die Schirm-Zeile braucht einen Takt, und nur unterwegs

## Der EINZIGE Takt der Maschine: die Aufschrift des Schirms läuft je Bild ein Stück
## auf ihr Ziel zu. Angekommen legt sie sich selbst still.
func _process(delta: float) -> void:
	if not _cover_wanted or is_equal_approx(_hover_share, _hover_goal):
		set_process(false)
		return
	_set_hover_share(move_toward(_hover_share, _hover_goal,
		delta / maxf(COVER_HOVER_TIME, 0.0001)))
	if is_equal_approx(_hover_share, _hover_goal):
		set_process(false)

## Einziger Eingang: Mitte auf dem Glas, halbe Ausdehnung in Welt-X/Welt-Z und die
## Fahrstrecke der Plattform. Idempotent - dieselben Maße bauen nicht neu.
func setup(at: Vector3, half_extents: Vector2, shaft_depth: float) -> void:
	var wanted := Vector2(maxf(half_extents.x, 0.01), maxf(half_extents.y, 0.01))
	var travel := maxf(shaft_depth, 0.05)
	if center.is_equal_approx(at) and half.is_equal_approx(wanted) \
			and is_equal_approx(depth, travel) and _platform != null \
			and is_equal_approx(_built_reach, cavity_reach) \
			and is_equal_approx(_built_travel, travel_share):
		return
	center = at
	half = wanted
	depth = travel
	_built_reach = cavity_reach
	_built_travel = travel_share
	global_position = center
	for child in get_children():
		remove_child(child)
		child.queue_free()
	# Der Neubau nimmt auch den Schirm mit - die Bestellung überlebt, der Körper nicht.
	_cover = null
	_cover_left = null
	_cover_right = null
	_cover_label = null
	_cover_material = null
	# Und die Blenden ebenso - die Bestellung der Wandhaut überlebt, ihr Körper nicht.
	_shutters = null
	_shutter_back = null
	_shutter_front = null
	if _wall_material == null:
		_build_materials()
		_write_skin()
	_build_body()

## Wie tief ein Hohlraum wirklich wird: sein Wunschmaß, aber nie weiter als die
## gemeldete Reichweite - und die schöpft er nie ganz aus (REACH_CLEAR).
func cavity_span() -> float:
	var wanted := depth * CAVITY_SHARE
	if cavity_reach <= 0.0:
		return wanted
	return minf(wanted, maxf(cavity_reach - REACH_CLEAR, 0.01))

## Wie weit ein wartendes Stück HINTER der Rückwand steht: am Ende des Hohlraums,
## außerhalb des Blickwinkels durch das Öffnungsband.
func waiting_offset() -> float:
	return half.x + cavity_span()

## Und wie weit ein abgehendes Stück VOR die Vorderwand fährt - der Spiegel davon.
## Ein Band, das einen Schritt weiterfährt: derselbe Weg für beide Fuhren.
func exit_offset() -> float:
	return waiting_offset()

## Wie hoch ein Öffnungsband ist - darüber bleibt der Sturz stehen, und genau dieses
## Maß füllt die Blende, wenn sie zu ist. Es mißt am STÜCK (der Anzeige-Tiefe), sitzt
## aber ganz unten an der Fahrt-Ebene: oberhalb steht die Wand geschlossen.
func mouth_height() -> float:
	return depth * MOUTH_SHARE

## Wie tief die Plattform zum EIN- und AUSFAHREN fährt: die BAND-EBENE. Dasselbe Maß,
## um das die Ware unter ihrem Platz startet.
func drop() -> float:
	return depth * maxf(travel_share, 1.0)

## Und wie tief sie im PARK stehen bleibt: auf der ANZEIGE-Tiefe - das ist das
## sichtbare Gruben-Bild, und es hängt nie an der Fahrt.
func park_y() -> float:
	return depth

## Der Weg zwischen Band-Ebene und Parkstand. Ohne bestellte Tieffahrt ist er null,
## dann fallen die beiden Ebenen zusammen wie eh und je.
func park_rise() -> float:
	return maxf(drop() - park_y(), 0.0)

# --- Die Fahrt ------------------------------------------------------------------

## Der ganze Auftritt als EIN Tween: Loch auf und bündige LEERE Platte senken, Ware
## von hinten durch die Rückwandöffnung einschieben, Platte und Ware GEMEINSAM
## heben, Loch zu. bodies und seats sind index-parallel, und seats sind die
## FERTIGEN Plätze - der Endzustand steht längst, gefahren wird nur der Weg.
## Zwei getrennte Tweens (Platte hier, Ware dort) liefen auseinander, und die Ware
## steht auf der Platte.
## riders/rider_seats sind die MITFAHRER: Ware, die auf der Plattform stehen bleibt.
## Sie sinkt und hebt mit ihr, der Band-Schritt rührt sie nicht an - ohne das
## schwebte ein bleibender Körper über dem offenen Loch.
func run_cycle(bodies: Array, seats: Array, delay: float,
		riders: Array = [], rider_seats: Array = []) -> Tween:
	settle_hard()
	if bodies.is_empty() or bodies.size() != seats.size() or _platform == null:
		return null
	if riders.size() != rider_seats.size():
		riders = []
		rider_seats = []
	var behind := waiting_offset()
	# Wartestellung: hinter der Rückwand auf der Band-Ebene - dort deckt das opake
	# Display jedes Stück, bis es hereinschiebt.
	for i in bodies.size():
		var body: Node3D = bodies[i]
		if body != null and is_instance_valid(body):
			body.global_position = (seats[i] as Vector3) + Vector3(behind, -drop(), 0.0)
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_tween.tween_callback(_open)
	_together(riders, rider_seats, -drop(), SINK_TIME, Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT)
	_shutter_step(BAND_BACK, 0.0, 1.0, true)  # nur der EINGANG wird gebraucht
	_belt_step([], [], 0.0, bodies, seats)
	_lift_and_seat(bodies + riders, seats + rider_seats, BAND_BACK)
	_tween.tween_callback(_shut)
	return _tween

## Der WARENUMSCHLAG als EIN Förderband-Schritt: Loch auf, Platte und ALTE Ware
## GEMEINSAM senken, dann fährt das Band einen Schritt weiter - die alten Stücke
## gleiten vorn hinaus, WÄHREND die neuen von hinten auf ihre Plätze nachrücken,
## gleiche Richtung, gleiche Dauer -, dann heben Platte und NEUE Ware, Loch zu.
## Beide Fuhren legen genau exit_offset() zurück: ihr Abstand bleibt über die ganze
## Fahrt derselbe, sie können sich nicht einholen.
## on_swept meldet am Ende des Band-Schritts, dass die alte Ware draußen ist - dort
## gibt der Wirt ihre Körper frei.
func run_swap(old_bodies: Array, old_seats: Array, new_bodies: Array,
		new_seats: Array, delay: float, on_swept := Callable(),
		riders: Array = [], rider_seats: Array = []) -> Tween:
	settle_hard()
	if _platform == null or old_bodies.size() != old_seats.size() \
			or new_bodies.size() != new_seats.size():
		return null
	if old_bodies.is_empty() and new_bodies.is_empty():
		return null
	if riders.size() != rider_seats.size():
		riders = []
		rider_seats = []
	var behind := waiting_offset()
	var ahead := exit_offset()
	# Wartestellung der NEUEN: hinter der Rückwand auf der Band-Ebene - dort deckt das
	# opake Display jedes Stück, bis es hereinschiebt. Die alten stehen schon.
	for i in new_bodies.size():
		var body: Node3D = new_bodies[i]
		if body != null and is_instance_valid(body):
			body.global_position = (new_seats[i] as Vector3) + Vector3(behind, -drop(), 0.0)
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_tween.tween_callback(_open)
	var bands := _bands_of(new_bodies, old_bodies)
	# Senken MIT der alten Ware und den Mitfahrern: sie stehen auf der Platte.
	_together(old_bodies + riders, old_seats + rider_seats, -drop(), SINK_TIME,
		Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_shutter_step(bands, 0.0, 1.0, true)
	_belt_step(old_bodies, old_seats, ahead, new_bodies, new_seats)
	if on_swept.is_valid():
		_tween.tween_callback(on_swept)
	_lift_and_seat(new_bodies + riders, new_seats + rider_seats, bands)
	_tween.tween_callback(_shut)
	return _tween

## Der ABGANG: senken MIT der Ware, sie vorn hinausschieben, die Platte LEER wieder
## bündig heben und das Loch schließen. Danach ist die Auslage leer - die Platte IST
## die Fläche, also darf sie nicht unten stehen bleiben.
func run_exit(bodies: Array, seats: Array, delay: float,
		on_swept := Callable(), riders: Array = [], rider_seats: Array = []) -> Tween:
	settle_hard()
	if bodies.is_empty() or bodies.size() != seats.size() or _platform == null:
		return null
	if riders.size() != rider_seats.size():
		riders = []
		rider_seats = []
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_tween.tween_callback(_open)
	_together(bodies + riders, seats + rider_seats, -drop(), SINK_TIME,
		Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_shutter_step(BAND_FRONT, 0.0, 1.0, true)  # es geht nur hinaus
	_belt_step(bodies, seats, exit_offset(), [], [])
	if on_swept.is_valid():
		_tween.tween_callback(on_swept)
	_lift_and_seat(riders, rider_seats, BAND_FRONT)
	_tween.tween_callback(_shut)
	return _tween

## Der KAUF: derselbe Zyklus, nur fährt die SEKTION unter dem gekauften Stück. Sie
## senkt sich MIT ihm, dann fährt es durch die HINTERE Öffnung ab - die
## Gegenrichtung zum Abgang, denn Gekauftes reist zur Werkbank, es geht nicht
## zurück ins Lager -, danach hebt sich die leere Sektion bündig und das Loch ist
## zu. on_gone meldet das Ende des Band-Schritts: dort ist das Stück außer Sicht.
func run_take(bodies: Array, seats: Array, delay: float,
		on_gone := Callable()) -> Tween:
	settle_hard()
	if bodies.is_empty() or bodies.size() != seats.size() or _platform == null:
		return null
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_tween.tween_callback(_open)
	_together(bodies, seats, -drop(), SINK_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_shutter_step(BAND_BACK, 0.0, 1.0, true)  # Gekauftes reist nach hinten ab
	var behind := waiting_offset()
	for i in bodies.size():
		var step := _tween if i == 0 else _tween.parallel()
		step.tween_property(bodies[i], "global_position",
			(seats[i] as Vector3) + Vector3(behind, -drop(), 0.0), PUSH_TIME) \
			.set_trans(Tween.TRANS_LINEAR)
	if on_gone.is_valid():
		_tween.tween_callback(on_gone)
	_lift_and_seat([], [], BAND_BACK)
	_tween.tween_callback(_shut)
	return _tween

## Der PARK-ZYKLUS: wie der Warenumschlag, nur endet er UNTEN. Loch auf, Platte und
## alte Ware auf die BAND-EBENE senken, EIN Band-Schritt (die alte vorn hinaus, die
## neue von hinten auf ihren Platz), dann zurück auf den PARKSTAND - und dort bleibt
## es stehen: Loch OFFEN, die Ware sichtbar am Grubenboden. Zuletzt fährt der SCHIRM
## aus beiden Wänden darüber. Das ist ein ENDZUSTAND, kein Zwischenschritt.
func run_park(old_bodies: Array, old_seats: Array, new_bodies: Array,
		new_seats: Array, delay: float, on_swept := Callable(),
		riders: Array = [], rider_seats: Array = []) -> Tween:
	settle_hard()
	if _platform == null or old_bodies.size() != old_seats.size() \
			or new_bodies.size() != new_seats.size():
		return null
	if riders.size() != rider_seats.size():
		riders = []
		rider_seats = []
	# Ein Park NUR mit Mitfahrern ist ein voller Fahrplan: die Plattform nimmt ihre
	# stehende Ware mit hinab und bleibt dort - der Band-Schritt fährt dann leer.
	if old_bodies.is_empty() and new_bodies.is_empty() and riders.is_empty():
		return null
	var behind := waiting_offset()
	for i in new_bodies.size():
		var body: Node3D = new_bodies[i]
		if body != null and is_instance_valid(body):
			body.global_position = (new_seats[i] as Vector3) + Vector3(behind, -drop(), 0.0)
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_tween.tween_callback(_open)
	var bands := _bands_of(new_bodies, old_bodies)
	_together(old_bodies + riders, old_seats + rider_seats, -drop(), SINK_TIME,
		Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_shutter_step(bands, 0.0, 1.0, true)
	_belt_step(old_bodies, old_seats, exit_offset(), new_bodies, new_seats)
	if on_swept.is_valid():
		_tween.tween_callback(on_swept)
	# Aus der Tiefe zurück auf den Parkstand: nur DA ist die Grube so tief, wie sie
	# aussieht. Ohne Tieffahrt liegen beide Ebenen aufeinander, der Schlag entfällt.
	_park_step(new_bodies + riders, new_seats + rider_seats)
	_cover_step(0.0, 1.0)  # zuletzt schiebt sich der Schirm über die Grube
	# Im selben Schlag fallen die Bänder zu: die geparkte Grube steht auf allen vier
	# Seiten geschlossen da. Ohne Schirm nimmt die Blende einen eigenen Schlag - er
	# bleibt unter dem Deckel, den park_cycle_time ohnehin rechnet.
	_shutter_step(bands, 1.0, 0.0, _cover_wanted)
	return _tween

## Die AUFFAHRT aus dem Park: die Ware steht schon am Grubenboden, der Schirm fährt
## ein, dann hebt sie - kein Senken, kein Band-Schritt -, und danach ist das Loch zu.
func run_rise(bodies: Array, seats: Array, delay: float) -> Tween:
	if _platform == null or bodies.size() != seats.size() or bodies.is_empty():
		return null
	park_hard()
	for i in bodies.size():
		var body: Node3D = bodies[i]
		if body != null and is_instance_valid(body):
			body.global_position = (seats[i] as Vector3) - Vector3.UP * park_y()
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_cover_step(1.0, 0.0)  # erst der Deckel, dann die Ware - nichts durchstößt ihn
	# Kein Band wird gebraucht: die Ware steht schon in der Grube und fährt gerade herauf.
	_lift_and_seat(bodies, seats)
	_tween.tween_callback(_shut)
	return _tween

## Der ABGANG aus dem Park: der Schirm fährt ein, dann geht die Ware UNTEN vorn hinaus,
## ohne je aufzutauchen (sie steht ja schon auf Schachttiefe); danach hebt die leere
## Platte bündig und das Loch schließt.
func run_leave_park(bodies: Array, seats: Array, delay: float,
		on_swept := Callable(), riders: Array = [], rider_seats: Array = []) -> Tween:
	if _platform == null or bodies.size() != seats.size() or bodies.is_empty():
		return null
	if riders.size() != rider_seats.size():
		riders = []
		rider_seats = []
	park_hard()
	for i in bodies.size():
		var body: Node3D = bodies[i]
		if body != null and is_instance_valid(body):
			body.global_position = (seats[i] as Vector3) - Vector3.UP * park_y()
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_cover_step(1.0, 0.0)
	# Der AUSGANG öffnet im selben Schlag, in dem der Schirm einfährt - beides muß fort
	# sein, bevor die Ware losfährt.
	_shutter_step(BAND_FRONT, 0.0, 1.0, _cover_wanted)
	# Und hinaus geht es auf der BAND-EBENE: das Öffnungsband sitzt dort, nicht am
	# Parkstand. Ohne Tieffahrt entfällt der Schlag.
	_dive_step(bodies + riders, seats + rider_seats)
	_belt_step(bodies, seats, exit_offset(), [], [])
	if on_swept.is_valid():
		_tween.tween_callback(on_swept)
	_lift_and_seat(riders, rider_seats, BAND_FRONT)
	_tween.tween_callback(_shut)
	return _tween

## Der PARK-ZUSTAND, direkt hergestellt: Fahrt aus, Loch auf, Platte ganz unten - und
## der bestellte Schirm hart mit darüber. Der Schreiber darf ihn jederzeit hart
## schreiben (Endzustand zuerst) - nach einem Abbruch steht die geparkte Grube sofort
## wieder, ohne Fahrt.
func park_hard() -> void:
	_kill()
	visible = true
	_set_platform(-park_y())
	_cover_hard(1.0)
	_shutters_hard()  # eine geparkte Grube steht auf allen vier Seiten geschlossen
	opened.emit(center, half)

# --- Die WANDHAUT und ihre BLENDEN ----------------------------------------------
# Die Haut wird BESTELLT wie der Schirm; wer nichts bestellt, fährt die nackte
# Maschine mit ihren offenen Bändern (Laden, Hinterzimmer, Schlitzreihe, Magazin).
# Mit Haut bekommt jedes Öffnungsband eine BLENDE in genau derselben Haut: geschlossen
# liest die Wand durchgehend wie die Seitenwände, und das ist der ganze Zweck.

## Die Haut BESTELLEN. Idempotent - dieselbe Textur schreibt nichts neu, und der
## Zustand der Blenden überlebt.
func order_skin(texture: Texture2D) -> void:
	if texture == null:
		drop_skin()
		return
	var fresh := not _skin_wanted or _shutters == null or not is_instance_valid(_shutters)
	var changed := texture != wall_skin
	_skin_wanted = true
	wall_skin = texture
	if changed:
		_write_skin()
	if fresh:
		_build_shutters()
	_seat_shutters(_back_open, _front_open)

## Die Bestellung zurücknehmen: die Wände sind wieder nackt, die Bänder wieder offen.
func drop_skin() -> void:
	_skin_wanted = false
	wall_skin = null
	_back_open = 0.0
	_front_open = 0.0
	_drop_shutters()
	_write_skin()

func has_skin() -> bool:
	return _skin_wanted

## Wie weit ein Band offen steht (0 = blind, 1 = ganz auf).
func shutter_open(back: bool) -> float:
	return _back_open if back else _front_open

## Die Haut auf das EINE Wandmaterial legen - Wände, Stürze und Blenden tragen sie
## damit zugleich. Welt-Triplanar: der Maßstab ist ein WELTMASS, also laufen die
## Leuchtlinien über die Boxkanten durch, statt je Fläche neu anzusetzen.
func _write_skin() -> void:
	if _wall_material == null:
		return
	if wall_skin == null:
		_wall_material.albedo_texture = null
		_wall_material.emission_texture = null
		_wall_material.uv1_triplanar = false
		_wall_material.uv1_world_triplanar = false
		_wall_material.albedo_color = Color(WALL_ALBEDO.r, WALL_ALBEDO.g,
			WALL_ALBEDO.b, 1.0)
		_wall_material.emission = Color(WALL_EMISSION.r, WALL_EMISSION.g,
			WALL_EMISSION.b, 1.0)
		_wall_material.emission_energy_multiplier = WALL_EMISSION_ENERGY
		return
	_wall_material.albedo_texture = wall_skin
	_wall_material.albedo_color = Color(SKIN_ALBEDO.r, SKIN_ALBEDO.g, SKIN_ALBEDO.b, 1.0)
	_wall_material.emission_texture = wall_skin
	# MULTIPLY, nicht ADD: addiert legte ein konstanter Schleier die Paneele flach.
	_wall_material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_wall_material.emission = Color(SKIN_EMISSION.r, SKIN_EMISSION.g,
		SKIN_EMISSION.b, 1.0)
	_wall_material.emission_energy_multiplier = SKIN_EMISSION_ENERGY
	_wall_material.uv1_triplanar = true
	_wall_material.uv1_world_triplanar = true
	_wall_material.uv1_scale = Vector3.ONE / SKIN_TILE

## Der Körper beider Blenden. Ohne Schacht (Bestellung vor dem ersten setup) gibt es
## nichts zu verkleiden - _build_body holt es nach.
func _build_shutters() -> void:
	_drop_shutters()
	if _platform == null or half.x <= 0.0:
		return
	_shutters = Node3D.new()
	_shutters.name = "Blenden"
	add_child(_shutters)
	var top := -WALL_SINK
	var lintel := maxf(drop() - mouth_height(), 0.01)
	_shutter_back = _build_shutter("Hinten", 1.0, top, lintel)
	_shutter_front = _build_shutter("Vorn", -1.0, top, lintel)

## EINE Blende: eine Platte in der Wandhaut, bündig in der Ebene ihres Sturzes und
## genau so breit wie er. Sie hängt am Sturz-Rand und rollt per scale.y in ihn hinein -
## der Schacht hat oben keine Tasche, in die man sie schieben könnte (die Grammatik
## des Schirms, nur senkrecht).
func _build_shutter(band_name: String, dir: float, top: float,
		lintel: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Blende%s" % band_name
	holder.position = Vector3(dir * (half.x + WALL * 0.5), top - lintel, 0.0)
	_shutters.add_child(holder)
	var pane_h := maxf(drop() - lintel, 0.001)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(WALL, pane_h, half.y * 2.0 + WALL * 2.0)
	var pane := MeshInstance3D.new()
	pane.name = "Platte"
	pane.mesh = mesh
	pane.material_override = _wall_material
	pane.position = Vector3(0.0, -pane_h * 0.5, 0.0)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(pane)
	return holder

func _drop_shutters() -> void:
	if _shutters != null and is_instance_valid(_shutters):
		remove_child(_shutters)
		_shutters.queue_free()
	_shutters = null
	_shutter_back = null
	_shutter_front = null

## Die BLENDE im Stand fahren - der einzige Handgriff der Maschine, der KEIN
## Fahrplan ist: die Plattform rührt sich nicht, nur das Band gibt den Weg frei
## (eine Ablage-Reihe schiebt in die geparkte Grube). Ohne Wandhaut gibt es keine
## Blende und darum nichts zu fahren.
func run_band(bands: int, open: bool, time := SHUTTER_TIME) -> Tween:
	if not _skin_wanted or bands == 0:
		return null
	_stop(_band_tween)
	_band_tween = null
	var back := (bands & BAND_BACK) != 0
	var front := (bands & BAND_FRONT) != 0
	var goal := 1.0 if open else 0.0
	var setter := func(share: float) -> void:
		_seat_shutters(share if back else _back_open, share if front else _front_open)
	var from := _back_open if back else _front_open
	if time <= 0.0 or is_equal_approx(from, goal):
		setter.call(goal)
		return null
	_band_tween = create_tween()
	_band_tween.tween_method(setter, from, goal, time).set_trans(Tween.TRANS_SINE)
	return _band_tween

## Der harte Schreiber des Blenden-Zustands: BEIDE zu. Jeder Endzustand und jeder
## Abbruch geht durch ihn - eine offen gebliebene Blende wäre ein Loch in der Wand.
func _shutters_hard() -> void:
	_stop(_band_tween)  # ein offenes Band ist ein Zustand, kein Anspruch
	_band_tween = null
	_seat_shutters(0.0, 0.0)

func _seat_shutters(back_share: float, front_share: float) -> void:
	# Ungebeten gibt es keine Blende - und darum auch keinen Zustand, der eine behauptet.
	_back_open = clampf(back_share, 0.0, 1.0) if _skin_wanted else 0.0
	_front_open = clampf(front_share, 0.0, 1.0) if _skin_wanted else 0.0
	if _shutter_back != null and is_instance_valid(_shutter_back):
		_shutter_back.scale.y = maxf(1.0 - _back_open, 0.0001)
	if _shutter_front != null and is_instance_valid(_shutter_front):
		_shutter_front.scale.y = maxf(1.0 - _front_open, 0.0001)

## Welche Bänder ein Schritt wirklich benutzt: herein geht es hinten, hinaus vorn.
func _bands_of(incoming: Array, outgoing: Array) -> int:
	var bands := 0
	if not incoming.is_empty():
		bands |= BAND_BACK
	if not outgoing.is_empty():
		bands |= BAND_FRONT
	return bands

## Ein Schlag der Blenden im laufenden Fahrplan. beside heißt: NEBEN dem eben gesetzten
## Takt (Senken, Hub, Schirm), also kostet das Band keine Zykluszeit; nur wo kein Takt
## danebensteht, nimmt er einen eigenen - und der bleibt unter dem gerechneten Deckel.
func _shutter_step(bands: int, from: float, to: float, beside: bool) -> void:
	if not _skin_wanted or bands == 0 or _tween == null:
		return
	var back := (bands & BAND_BACK) != 0
	var front := (bands & BAND_FRONT) != 0
	var setter := func(share: float) -> void:
		_seat_shutters(share if back else _back_open,
			share if front else _front_open)
	var step := _tween.parallel() if beside else _tween
	step.tween_method(setter, from, to, SHUTTER_TIME).set_trans(Tween.TRANS_SINE)

# --- Der GRUBEN-SCHIRM ----------------------------------------------------------
# Zwei fast durchsichtige Paneele über der geparkten Grube. Sie fahren aus der linken
# und der rechten Wand heraus und treffen sich in der Mitte - und weil der Schacht
# seitlich KEINEN Hohlraum hat (die Hohlräume liegen vorn und hinten, und keiner darf
# unter ein fremdes Loch reichen), parkt ein Paneel auf Länge NULL in seinem
# Wandschlitz und rollt daraus hervor, statt in eine Tasche zu schieben.

## Der Schirm wird BESTELLT - eine Auslage ohne Bestellung baut keinen. Der Schacht
## kennt keine Wetten: WAS in der Grube liegt, meldet der Wirt als fertige Zeile.
func order_cover(text: String, accent: Color) -> void:
	var fresh := not _cover_wanted or _cover == null or not is_instance_valid(_cover)
	var changed := text != cover_text or accent != cover_tint
	_cover_wanted = true
	cover_text = text
	cover_tint = accent
	if fresh:
		_build_cover()
	elif changed:
		_write_cover()
	_seat_cover(_cover_share)

## Die STEHENDE Zeile bestellen: die Bedingung der Wette samt Live-Stand, im
## gemeldeten Ton. Sie hängt NICHT am Zeiger - sie steht, sobald der Schirm steht;
## leer heißt, es gibt keine. Idempotent, und sie baut nichts neu.
func order_cover_goal(text: String, tint: Color) -> void:
	if text == cover_goal and tint == cover_goal_tint:
		return
	cover_goal = text
	cover_goal_tint = tint
	_write_cover()

## Die Bestellung zurücknehmen - der Körper geht mit ihr.
func drop_cover() -> void:
	_cover_wanted = false
	cover_text = ""
	cover_goal = ""
	_cover_shown = ""
	set_process(false)
	_cover_share = 0.0
	_hover_share = 0.0
	_hover_goal = 0.0
	_kill_goal_flash()
	if _cover != null and is_instance_valid(_cover):
		remove_child(_cover)
		_cover.queue_free()
	_cover = null
	_cover_left = null
	_cover_right = null
	_cover_label = null
	_cover_material = null

func has_cover() -> bool:
	return _cover_wanted

## Wie weit der Schirm heraus ist (0 = in der Wand, 1 = geschlossen).
func cover_share() -> float:
	return _cover_share

## Und wieviel von seiner Aufschrift zu sehen ist. Ohne stehende Zeile gilt die alte
## Regel: ohne Zeiger nichts. MIT stehender Zeile ist der Hover-Weg der UMSCHALTER -
## die Schrift steht links und rechts davon ganz da und geht am Schwellwert (0,5)
## durch null, wo sie tauscht. EIN Label, EIN Fade, zwei Texte.
func cover_text_share() -> float:
	if cover_goal == "":
		return _hover_share * _cover_share
	return _cover_share * clampf(absf(_hover_share - 0.5) * 2.0, 0.0, 1.0)

## Der Zeiger liegt über der Grube: die Zeile blendet ein. GEFRAGT je Bild vom Wirt,
## wie jeder andere Griff auf dem Tisch - hier landet darum nur das ZIEL, geführt wird
## je Bild (_process). Ein Tween wäre der falsche Träger: der Wirt fragt je Bild, jede
## Frage startete ihn neu, und ein Neustart verwirft den Rest - die Zeile käme nie an.
func set_cover_hovered(on: bool) -> void:
	if not _cover_wanted:
		return
	_hover_goal = 1.0 if on else 0.0
	if not is_equal_approx(_hover_share, _hover_goal):
		set_process(true)

func cover_hovered() -> bool:
	return _hover_share > 0.5

## Die STEHENDE Zeile leuchtet kurz auf - der Einschlag eines Steuer-Meteors. Ohne
## bestellte Bedingung gibt es nichts zum Aufleuchten.
func flash_cover_goal() -> void:
	if not _cover_wanted or cover_goal == "":
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_set_goal_flash(1.0)  # der Einschlag steht SOFORT, der Tween fährt nur zurück
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_goal_flash, 1.0, 0.0, COVER_FLASH_TIME) \
		.set_trans(Tween.TRANS_SINE)

## Wie hell die stehende Zeile gerade über ihrem Ruhelicht steht.
func cover_goal_flash() -> float:
	return _goal_flash

func _set_goal_flash(value: float) -> void:
	_goal_flash = clampf(value, 0.0, 1.0)
	_sync_cover_label()

## Ein Schlag des Schirms im laufenden Fahrplan. Ohne Bestellung kostet er nichts -
## die Zyklus-Deckel rechnen ihn trotzdem mit, sie sind Decken, keine Versprechen.
func _cover_step(from: float, to: float) -> void:
	if not _cover_wanted:
		return
	_tween.tween_method(_set_cover_share, from, to, COVER_TIME) \
		.set_trans(Tween.TRANS_SINE)

## Der harte Schreiber des Schirm-Zustands - jeder Abbruch und jeder Endzustand geht
## durch ihn. Eingefahren nimmt er die Aufschrift mit: sie hinge sonst über nichts.
func _cover_hard(share: float) -> void:
	if share <= 0.001:
		set_process(false)
		_hover_share = 0.0
		_hover_goal = 0.0
		_kill_goal_flash()
	_seat_cover(share)

## Das Aufleuchten hart zurücknehmen - der EINE Aufräum-Pfad nimmt es mit.
func _kill_goal_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_goal_flash = 0.0

func _set_cover_share(share: float) -> void:
	_seat_cover(share)

func _set_hover_share(share: float) -> void:
	_hover_share = clampf(share, 0.0, 1.0)
	_sync_cover_label()

func _seat_cover(share: float) -> void:
	# Ungebeten gibt es keinen Schirm - und darum auch keinen Zustand, der einen
	# behauptet (Laden und Magazin fahren dieselbe Maschine).
	_cover_share = clampf(share, 0.0, 1.0) if _cover_wanted else 0.0
	if _cover == null or not is_instance_valid(_cover):
		return
	_cover.visible = _cover_share > 0.001
	# Der Maßstab IST die Ausfahrt: bei 0 steckt das Paneel als Nullstrich in seinem
	# Wandschlitz, bei 1 stößt es an die Mittelfuge.
	var out := maxf(_cover_share, 0.0001)
	if _cover_left != null and is_instance_valid(_cover_left):
		_cover_left.scale.z = out
	if _cover_right != null and is_instance_valid(_cover_right):
		_cover_right.scale.z = out
	_sync_cover_label()

func _sync_cover_label() -> void:
	if _cover_label == null or not is_instance_valid(_cover_label):
		return
	if _cover_key() != _cover_shown:
		_paint_cover_line()  # der Zeiger hat die Zeile getauscht
	var seen := cover_text_share()
	_cover_label.visible = seen > 0.004
	_paint_cover_colors(seen)

## Welche Zeile gerade gilt: ohne Zeiger die Bedingung, mit Zeiger der Gewinn.
func _cover_on_goal() -> bool:
	return cover_goal != "" and not cover_hovered()

func _cover_key() -> String:
	return ("goal:" if _cover_on_goal() else "prize:") \
		+ (cover_goal if _cover_on_goal() else cover_text)

## Der Körper des Schirms - je Wand ein Halter, dazwischen die eine Aufschrift.
func _build_cover() -> void:
	if _cover != null and is_instance_valid(_cover):
		remove_child(_cover)
		_cover.queue_free()
	_cover = Node3D.new()
	_cover.name = "Schirm"
	_cover.visible = false
	add_child(_cover)
	_cover_material = _glass_material()
	# Beide Hälften reichen bis GENAU zur Mitte: sie stoßen nahtlos, ohne Fuge und
	# ohne Überdeckung - ein Spalt läse als dunkler Strich, eine Überlappung (das
	# Glas schreibt keine Tiefe) als doppelt heller.
	var reach := maxf(half.y, 0.001)
	_cover_left = _build_cover_wing("Links", -1.0, reach)
	_cover_right = _build_cover_wing("Rechts", 1.0, reach)
	_cover_label = Label3D.new()
	_cover_label.name = "Aufschrift"
	_cover_label.font_size = COVER_FONT
	_cover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Der Prepass schreibt Tiefe (die Ziffern-Lehre der Würfel), damit die Zeile über
	# dem Glas und über der Ware sauber sortiert; die niedrige Schwelle läßt das
	# Einblenden trotzdem WEICH laufen, statt es hart umzuschalten.
	_cover_label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	_cover_label.alpha_scissor_threshold = 0.02
	_cover_label.outline_size = COVER_OUTLINE
	# Flach auf dem Schirm und in TISCH-Leserichtung: die Zeile läuft entlang Welt +Z
	# (Bildschirm rechts), ihre Oberkante zeigt nach Welt +X (Bildschirm oben).
	_cover_label.transform.basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	_cover_label.position = Vector3(0.0, -COVER_DROP + COVER_H, 0.0)
	_cover_label.visible = false
	_cover.add_child(_cover_label)
	_write_cover()

## EIN Flügel: eine flache Platte, die im Wandschlitz beginnt und zur Mitte wächst.
func _build_cover_wing(wing_name: String, dir: float, reach: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Fluegel%s" % wing_name
	holder.position = Vector3(0.0, -COVER_DROP, dir * half.y)
	holder.scale.z = 0.0001
	_cover.add_child(holder)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(half.x * 2.0, COVER_H, reach)
	var pane := MeshInstance3D.new()
	pane.name = "Scheibe"
	pane.mesh = mesh
	pane.material_override = _cover_material
	pane.position = Vector3(0.0, 0.0, -dir * reach * 0.5)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(pane)
	return holder

## Zeile und Akzent auf den bestehenden Körper schreiben - eine neue Wette baut
## keinen neuen Schirm.
func _write_cover() -> void:
	if _cover_material != null:
		_cover_material.albedo_color = Color(cover_tint.r * 0.5, cover_tint.g * 0.5,
			cover_tint.b * 0.5, COVER_ALPHA)
		_cover_material.emission = Color(cover_tint.r, cover_tint.g, cover_tint.b, 1.0)
	if _cover_label == null or not is_instance_valid(_cover_label):
		return
	_paint_cover_line()
	_sync_cover_label()

## Die geltende Zeile auf das Label schreiben: Text, Grad, Umbruch und Ton. Der Grad
## ist gerechnet, und er gilt für BEIDE Texte - eine Bedingung ist länger als ein
## Gewinn, also bricht sie eher um.
func _paint_cover_line() -> void:
	var goal := _cover_on_goal()
	var line := cover_goal if goal else cover_text
	_cover_shown = _cover_key()
	_cover_label.text = line
	var grade := _cover_font_scale(line)
	_cover_label.pixel_size = grade
	# Der Umbruch läuft auf der Grubenbreite, in Schrift-Pixeln gemessen - so bricht
	# die Zeile genau dort, wo der gewählte Grad es vorsieht.
	_cover_label.width = (half.y * 2.0) * COVER_TEXT_SHARE / maxf(grade, 0.0001)
	_cover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paint_cover_colors(cover_text_share())

## Ton und Alpha der geltenden Zeile - je Bild, denn Alpha und Aufleuchten laufen
## beide hier durch. Aufleuchten kann nur die STEHENDE Zeile: sie ist die Bedingung,
## und ihr gilt die Meldung.
func _paint_cover_colors(seen: float) -> void:
	if _cover_label == null or not is_instance_valid(_cover_label):
		return
	var goal := _cover_on_goal()
	var gain := 1.0 + (COVER_FLASH_GAIN - 1.0) * _goal_flash if goal else 1.0
	var body := cover_goal_text_color(cover_goal_tint) if goal else cover_text_color()
	var edge := cover_goal_outline_color(cover_goal_tint) if goal \
		else cover_outline_color()
	_cover_label.modulate = Color(body.r * gain, body.g * gain, body.b * gain, seen)
	_cover_label.outline_modulate = Color(edge.r, edge.g, edge.b, seen)

## Die EINE Farbe der Aufschrift, unabhängig von der Wette: das Haus-Gold, überhellt.
static func cover_text_color() -> Color:
	var gold := CasinoStyle.GOLD_INTENSE
	return Color(gold.r * COVER_TEXT_GAIN, gold.g * COVER_TEXT_GAIN,
		gold.b * COVER_TEXT_GAIN)

## Und der EINE Ton ihres Umrisses: dasselbe Gold, dunkel - nie Schwarz.
static func cover_outline_color() -> Color:
	var dark := CasinoStyle.GOLD_DARK
	return Color(dark.r * COVER_OUTLINE_GAIN, dark.g * COVER_OUTLINE_GAIN,
		dark.b * COVER_OUTLINE_GAIN)

## Die STEHENDE Zeile leuchtet dagegen im gemeldeten Ton - überhellt, damit sie über
## der Ware steht, und ihr Umriß dunkel aus derselben Farbe statt aus Schwarz.
static func cover_goal_text_color(tint: Color) -> Color:
	return Color(tint.r * COVER_GOAL_TEXT_GAIN, tint.g * COVER_GOAL_TEXT_GAIN,
		tint.b * COVER_GOAL_TEXT_GAIN)

static func cover_goal_outline_color(tint: Color) -> Color:
	return Color(tint.r * COVER_GOAL_OUTLINE_GAIN, tint.g * COVER_GOAL_OUTLINE_GAIN,
		tint.b * COVER_GOAL_OUTLINE_GAIN)

## Der Schriftgrad: die Zeile muß LÄNGS in die Grubenbreite (Welt-Z) und QUER in ihre
## Tiefe (Welt-X) passen - der kleinere der beiden Grade gewinnt. Gewählt wird die
## ZEILENZAHL, die den größten Grad erlaubt: kurze Gewinne stehen einzeilig groß, ein
## langer bricht um, statt auf ein Fünftel zu schrumpfen.
func _cover_font_scale(text: String) -> float:
	var chars := maxf(float(text.length()), 1.0)
	var best := 0.0
	for lines in range(1, COVER_LINES + 1):
		var per_line := ceilf(chars / float(lines))
		var wide := (half.y * 2.0) * COVER_TEXT_SHARE \
			/ maxf(per_line * float(COVER_FONT) * 0.6, 1.0)
		var high := (half.x * 2.0) * COVER_LINE_SHARE \
			/ (float(COVER_FONT) * float(lines))
		best = maxf(best, minf(wide, high))
	return maxf(best, 0.0002)

## Das GLAS des Schirms: fast durchsichtig, nur ein Saum Emission - der Blick fällt
## weiter auf die Ware darunter. Kein Tiefen-Schreiben, sonst verdeckte er sie.
func _glass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(cover_tint.r * 0.5, cover_tint.g * 0.5,
		cover_tint.b * 0.5, COVER_ALPHA)
	material.metallic = 0.0
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = Color(cover_tint.r, cover_tint.g, cover_tint.b, 1.0)
	material.emission_energy_multiplier = COVER_EMISSION_ENERGY
	return material

## Der Weg vom Band zurück auf den PARKSTAND (im Hub-Takt) und der hinunter (im
## Senk-Takt). Beides gibt es nur mit Tieffahrt; sonst ist der Weg null und der Takt
## wäre ein Stillstand.
func _park_step(bodies: Array, seats: Array) -> void:
	if park_rise() <= 0.001:
		return
	_together(bodies, seats, -park_y(), LIFT_TIME, Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT)

func _dive_step(bodies: Array, seats: Array) -> void:
	if park_rise() <= 0.001:
		return
	_together(bodies, seats, -drop(), SINK_TIME, Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT)

## Der BAND-SCHRITT: auf der Band-Ebene fahren alle Stücke um dasselbe Maß nach vorn -
## die abgehenden aus dem Schacht in den vorderen Hohlraum, die ankommenden aus dem
## hinteren auf ihre Plätze. EIN Takt, eine Bewegung.
func _belt_step(out_bodies: Array, out_seats: Array, ahead: float,
		in_bodies: Array, in_seats: Array) -> void:
	var deep := drop()
	var first := true
	for i in out_bodies.size():
		var step := _tween if first else _tween.parallel()
		first = false
		step.tween_property(out_bodies[i], "global_position",
			(out_seats[i] as Vector3) + Vector3(-ahead, -deep, 0.0), PUSH_TIME) \
			.set_trans(Tween.TRANS_LINEAR)
	for i in in_bodies.size():
		var step := _tween if first else _tween.parallel()
		first = false
		step.tween_property(in_bodies[i], "global_position",
			(in_seats[i] as Vector3) - Vector3.UP * deep, PUSH_TIME) \
			.set_trans(Tween.TRANS_LINEAR)
	if first:
		_tween.tween_interval(PUSH_TIME)  # ein leeres Band fährt trotzdem seinen Takt

## Der Hub samt Setz-Dip - der Schluss jedes Fahrplans. Ohne Ware fährt die Platte
## allein herauf.
## shut nennt die Bänder, die dieser Fahrplan geöffnet hat: sie fallen IM Hub-Takt
## wieder zu, also kosten sie nichts.
func _lift_and_seat(bodies: Array, seats: Array, shut := 0) -> void:
	_together(bodies, seats, 0.0, LIFT_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_shutter_step(shut, 1.0, 0.0, true)
	var dip := minf(DIP, depth * 0.5)
	_together(bodies, seats, -dip, DIP_TIME * 0.5, Tween.TRANS_SINE, Tween.EASE_OUT)
	_together(bodies, seats, 0.0, DIP_TIME * 0.5, Tween.TRANS_SINE, Tween.EASE_IN)

## Ein Schlag der gemeinsamen Fahrt: die Platte auf offset, jedes Stück um genau
## dasselbe Maß über seinem Platz. Identische Tweens statt einer Elternschaft, die
## niemandem gehört.
func _together(bodies: Array, seats: Array, offset: float, time: float,
		trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	_tween.tween_property(_platform, "position:y", offset, time) \
		.set_trans(trans).set_ease(ease_type)
	for i in bodies.size():
		_tween.parallel().tween_property(bodies[i], "global_position",
			(seats[i] as Vector3) + Vector3.UP * offset, time) \
			.set_trans(trans).set_ease(ease_type)

## Der EINE harte Endzustand, den JEDER Abbruch schreibt: Fahrt aus, Platte bündig,
## Maschine fort, Loch zu. Ein offenes Loch ist der schlimmste denkbare Rest.
func settle_hard() -> void:
	_kill()
	_shut()

func platform_y() -> float:
	return _platform.position.y if _platform != null else 0.0

## Fährt gerade eine Fahrt? Wer den Zustand von außen nachstellt, muss ihr aus dem
## Weg gehen - sie schreibt ihn selbst.
func riding() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()

## Bündig ist die Platte von der Anzeige nicht zu unterscheiden - das Öffnen ist
## deshalb nahtlos. Ein Schirm hat hier nichts zu suchen: gleich fährt Ware.
func _open() -> void:
	visible = true
	_set_platform(0.0)
	_cover_hard(0.0)
	_shutters_hard()  # jede Fahrt beginnt mit blinden Bändern
	opened.emit(center, half)

func _shut() -> void:
	_set_platform(0.0)
	_cover_hard(0.0)
	_shutters_hard()
	visible = false
	closed.emit()

func _set_platform(y: float) -> void:
	if _platform != null:
		_platform.position.y = y

func _kill() -> void:
	_stop(_tween)
	_tween = null

func _stop(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

# --- Der Körper -----------------------------------------------------------------

func _build_materials() -> void:
	_wall_material = _metal(WALL_ALBEDO, WALL_EMISSION, WALL_EMISSION_ENERGY)
	_cavity_material = _metal(CAVITY_ALBEDO, CAVITY_EMISSION, CAVITY_EMISSION_ENERGY)
	_glow_material = _metal(GLOW_COLOR * 0.3, GLOW_COLOR, GLOW_ENERGY)
	_deck_side_material = _metal(DECK_SIDE, DECK_EMISSION, DECK_EMISSION_ENERGY)

## Die gemeldete Haut auf die Deckfläche legen. Idempotent, und ohne Haut bleibt
## die Platte Maschine wie ihre Flanken.
func _apply_deck_skin() -> void:
	if _deck_top == null or not is_instance_valid(_deck_top):
		return
	_deck_top.material_override = deck_skin if deck_skin != null else _deck_side_material

func _metal(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(albedo.r, albedo.g, albedo.b, 1.0)
	material.metallic = 0.45
	material.roughness = 0.5
	material.emission_enabled = true
	material.emission = Color(emission.r, emission.g, emission.b, 1.0)
	material.emission_energy_multiplier = energy
	return material

## Alles in LOKALEN Koordinaten um die Schachtmitte auf dem Glas (y = 0 ist die
## Tischfläche, +X ist hinten).
func _build_body() -> void:
	var span := Vector2(half.x * 2.0, half.y * 2.0)
	var top := -WALL_SINK
	var mouth := mouth_height()
	var cavity := cavity_span()
	# Der ganze Kasten reicht bis auf die BAND-EBENE: Öffnungsband, Hohlraum und Sohle
	# sitzen dort, oberhalb steht die Wand geschlossen. Was man im Park sieht, deckt
	# ohnehin die Platte.
	var deep := drop()
	var sole_y := top - deep - SOLE_CLEAR - DECK

	# Zwei geschlossene Flanken; vorn und hinten steht je ein Sturz über einem
	# Öffnungsband - hinten schiebt die Ware herein, vorn hinaus.
	_box("WallLeft", Vector3(span.x, deep, WALL),
		Vector3(0.0, top - deep * 0.5, -half.y - WALL * 0.5), _wall_material)
	_box("WallRight", Vector3(span.x, deep, WALL),
		Vector3(0.0, top - deep * 0.5, half.y + WALL * 0.5), _wall_material)
	var lintel := maxf(deep - mouth, 0.01)
	_box("BackLintel", Vector3(WALL, lintel, span.y + WALL * 2.0),
		Vector3(half.x + WALL * 0.5, top - lintel * 0.5, 0.0), _wall_material)
	_box("FrontLintel", Vector3(WALL, lintel, span.y + WALL * 2.0),
		Vector3(-half.x - WALL * 0.5, top - lintel * 0.5, 0.0), _wall_material)

	# Je Band ein Hohlraum: Stirnwand, zwei Flanken und eine Decke, damit der Blick
	# durch keines der beiden Öffnungsbänder ins Freie fällt.
	_build_cavity("Back", 1.0, span, top, mouth, cavity)
	_build_cavity("Front", -1.0, span, top, mouth, cavity)

	# Die SOHLE unter Schacht und BEIDEN Hohlräumen: der Blick in den offenen Schacht
	# darf nie auf den Raumboden fallen (der Filz ist dort weggeblendet).
	_box("Sole", Vector3(span.x + WALL * 2.0 + cavity * 2.0, DECK,
		span.y + WALL * 2.0),
		Vector3(0.0, sole_y + DECK * 0.5, 0.0), _cavity_material)

	var glow_y := -GLOW_DROP - GLOW_H * 0.5
	# Rundum, denn beide Stürze stehen hoch genug: der Saum liegt auf ihnen, nicht
	# im Öffnungsband - und er liegt IM Schacht, er umrandet die Fläche nicht.
	_box("GlowFront", Vector3(GLOW_IN, GLOW_H, span.y),
		Vector3(-half.x + GLOW_IN * 0.5, glow_y, 0.0), _glow_material)
	_box("GlowBack", Vector3(GLOW_IN, GLOW_H, span.y),
		Vector3(half.x - GLOW_IN * 0.5, glow_y, 0.0), _glow_material)
	_box("GlowLeft", Vector3(span.x, GLOW_H, GLOW_IN),
		Vector3(0.0, glow_y, -half.y + GLOW_IN * 0.5), _glow_material)
	_box("GlowRight", Vector3(span.x, GLOW_H, GLOW_IN),
		Vector3(0.0, glow_y, half.y - GLOW_IN * 0.5), _glow_material)

	_build_platform(span)

	# Schirm und Blenden gehören zum Körper, nicht zur Fahrt: eine überlebende
	# Bestellung stellt sie nach dem Neubau in genau ihrem alten Zustand wieder hin.
	if _cover_wanted:
		_build_cover()
		_seat_cover(_cover_share)
	if _skin_wanted:
		_build_shutters()
		_seat_shutters(_back_open, _front_open)

## Ein HOHLRAUM hinter einem Öffnungsband, gespiegelt über dir (+1 = hinten, der
## Eingang; -1 = vorn, der Ausgang). Stirnwand, zwei Flanken und eine Decke - durch
## das Band blickt man ein Stück weit hinein, und dort soll das Auge nichts finden.
## Die Decke füllt das ganze Sturz-Band bis an die Schnittkante: bliebe darüber ein
## Schlitz, sähe man von einem NACHBAR-Loch senkrecht in den dunklen Hohlraum.
func _build_cavity(cavity_name: String, dir: float, span: Vector2, top: float,
		mouth: float, cavity: float) -> void:
	var mid := dir * (half.x + WALL + cavity * 0.5)
	var deep := drop()
	var lid := maxf(deep - mouth, 0.01)
	_box("Cavity%sEnd" % cavity_name, Vector3(WALL, deep, span.y + WALL * 2.0),
		Vector3(dir * (half.x + WALL * 1.5 + cavity), top - deep * 0.5, 0.0),
		_cavity_material)
	_box("Cavity%sLeft" % cavity_name, Vector3(cavity, deep, WALL),
		Vector3(mid, top - deep * 0.5, -half.y - WALL * 0.5), _cavity_material)
	_box("Cavity%sRight" % cavity_name, Vector3(cavity, deep, WALL),
		Vector3(mid, top - deep * 0.5, half.y + WALL * 0.5), _cavity_material)
	_box("Cavity%sLid" % cavity_name, Vector3(cavity, lid, span.y + WALL * 2.0),
		Vector3(mid, top - lid * 0.5, 0.0), _cavity_material)

## Die Plattform: eine Platte über die volle Schachtbreite. Ihr Ursprung liegt in
## der Glasebene, ihre DECKFLÄCHE also bündig - so ist "0" der bündige Stand und
## "-depth" der gesenkte, ohne dass ein Aufrufer die Plattendicke kennen müsste.
func _build_platform(span: Vector2) -> void:
	_platform = Node3D.new()
	_platform.name = "Platform"
	add_child(_platform)
	# Die DECKHAUT ist die Oberfläche - sie allein reicht bis zur Nullebene, die
	# Platte hängt vollständig darunter. Zwei koplanare Deckflächen kämpften im
	# Tiefenpuffer und zerschnitten die Fläche in Streifen.
	var skin_h := DECK * 0.12
	var skin := BoxMesh.new()
	skin.size = Vector3(span.x, skin_h, span.y)
	_deck_top = MeshInstance3D.new()
	_deck_top.name = "DeckTop"
	_deck_top.mesh = skin
	_deck_top.position = Vector3(0.0, -skin_h * 0.5, 0.0)
	_deck_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_platform.add_child(_deck_top)
	_apply_deck_skin()
	var deck := BoxMesh.new()
	deck.size = Vector3(span.x, DECK, span.y)
	var plate := MeshInstance3D.new()
	plate.name = "Deck"
	plate.mesh = deck
	plate.material_override = _deck_side_material
	plate.position = Vector3(0.0, -skin_h - DECK * 0.5, 0.0)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_platform.add_child(plate)

func _box(box_name: String, box_size: Vector3, at: Vector3,
		material: Material) -> void:
	if box_size.x <= 0.001 or box_size.y <= 0.001 or box_size.z <= 0.001:
		return
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
