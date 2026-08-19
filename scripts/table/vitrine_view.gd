class_name VitrineView
extends Node3D
## Die VITRINE: die Bucht unter einem Laden-Fenster, in der die Ware KÖRPERLICH
## liegt - und zwar ALLES, auf dem Grubenboden. Die Bucht ist darum FLACH: was
## nicht steht, braucht keine Standhöhe, und ihr Boden ist das Bett der ganzen
## Auslage (später auch ihre Rollfläche). Getrennt wird nach dem PLATZ, nicht nach
## der Lage: hinten das REGAL (versiegelte Data-Cells - Gravur-Pakete und ein
## gerollter Katalysator als seine Kassette), vorn die SCHALE (die offene Ware:
## bis zu sechs echte Würfel und, wenn der Sonderposten eine Gravur ist, ihr
## blanker Chip). Bezahlte Ware wartet hier NICHT mehr: sie fährt unterflur an die
## Werkbank und landet in der Schale rechts daneben (AusgabefachView) - der Hub
## kauft, die Werkstatt nutzt.
## In der Bucht hängt kein Preisschild - die Schalen-Regel gilt für den ganzen
## Laden, und der Preis steht allein auf der Scheibe darüber.
## Zwei Instanzen sind vorgesehen - Laden und Schwarzmarkt -, deshalb trägt jede
## ihren eigenen Namen und misst sich allein an dem Rechteck, das man ihr stellt.
## Gespiegelt wird NICHTS darin: ein Loch hat kein Spiegelbild (Grubenregel).

## Der Lichtsaum der Bucht ist AMBER - die Marquee-Farbe ihrer Auskleidung
## (PackPitView.bay_look): Kragensaum, Fugen der Klappe und die Birnenreihen an den
## Wänden sprechen dieselbe Sprache. Sein Produkt mit der Energie bleibt unter der
## Ruhe-Schwelle, ein Archiv-Lavendel bliebe es auch bei 1,4.
const GLOW := Color(1.0, 0.745, 0.235)
const GLOW_ENERGY := 0.82

## Würfel liegen in TRAY-Größe (Spec) - dasselbe Maß, in dem der Spieler seine
## Würfel überall sonst sieht.
const DIE_SCALE := DiceTrayView.DIE_SCALE

## Luft zwischen dem Grubenboden-Bett und der Anzeigefläche, die die WARE für sich
## verlangt (Anteil der Würfel-Anzeigegröße) - das Maß, aus dem content_depth()
## gelöst ist. Was der Griff wirklich an Luft hat, ist seit der Verdopplung mehr:
## _hover_room misst gegen die Anzeigefläche, nicht gegen diese Zahl.
const CONTENT_DROP := 0.32
## Wie viel tiefer die Bucht steht, als ihre Ware misst. Zwei ist eine BÜHNEN-Zahl:
## sie macht aus der Schale einen Kasten, gibt dem Wurf Raum unter der Anzeige und
## hebt den Deckel-Kompromiss der flachen Bucht auf.
const DEPTH_FACTOR := 2.0
## Die Silhouette eines liegenden Würfels als Vielfaches seiner halben Kante:
## Eckkappen, Kantenbalken und Lichtlache stehen über seinem Quader hinaus, und
## genau die stachen einmal durch die Anzeige.
const SILHOUETTE := 1.25
## Die Ware ruht AUF dem Boden - eine Haaresbreite darüber, sonst kämpfen ihre
## Unterseite und die Bodenplatte im Tiefenpuffer.
const FLOOR_CLEAR := 0.03

## Aufteilung der Buchtfläche (Anteile): Regal (hinten) und Schale (vorn) teilen
## sich die ganze Tiefe.
const SHELF_DEPTH_SHARE := 0.42
## Rand, den die Ware zur Buchtwand hält - bei 15° verschluckt die nahe Wand
## sonst, was zu dicht an ihr steht.
const WALL_MARGIN := 0.10

## Der Sonderposten-Chip: ein flaches Plättchen mit dem Gravur-Zeichen über
## weichem Sortenglühen - die Ablage-Grammatik der Presse, nur körperlich.
const CHIP_SIZE := DIE_SCALE * 2.2
const CHIP_TEXTURE := 192
const CHIP_ENERGY := 1.25
const CHIP_GLOW_SIZE := CHIP_SIZE * 1.7
const CHIP_GLOW_ENERGY := 0.55
## Die Glühplatte hängt eine Haaresbreite UNTER dem Zeichen. Sie muss kleiner
## bleiben als FLOOR_CLEAR, sonst schneidet sie in den Grubenboden.
const CHIP_GLOW_DROP := 0.01

## Greifen: das Stück hebt sich ein Stück und wird eine Spur größer (die
## Magazin-Geste - eine Akte, die man aus der Schublade zieht). Der Hub ist hier
## aber GEDECKELT: über der Bucht liegt sichtbares Glas, und was hindurchstößt,
## ist kein Griff mehr. Gemessen wird je Stück, wie viel Luft es bis zur
## Scheibenebene hat; das Magazin (keine Scheibe darüber) hebt weiter voll.
const HOVER_LIFT := DIE_SCALE * 0.45
const HOVER_SWELL := 1.08
const HOVER_TIME := 0.14
## Rest, den auch das gegriffene Stück unter der Anzeigefläche behält.
const GLASS_CLEAR := 0.02

## Übergeben: das gekaufte Stück hebt sich kurz an und sinkt dann durch seine
## Luke - erst danach fährt das Förderwerk damit los.
const LIFT_TIME := 0.14
const SINK_TIME := 0.3

## Der WARENUMSCHLAG des Blätterns: alles sinkt gestaffelt durch seine Luke, ohne
## Anheben - das Anheben ist die Geste der Übergabe, nicht die des Blätterns. Die
## Staffelung ist gedeckelt, sonst würde Stöbern in einem vollen Laden zäh.
const SWAP_SINK := 0.22
const SWAP_STAGGER := 0.02
const SWAP_SPREAD_MAX := 0.10
const SWAP_TIME := SWAP_SINK + SWAP_SPREAD_MAX

## Die Bestückung: die Körper treten gestaffelt auf (Hub-Prämien-Größenordnung),
## und auch diese Staffelung ist gedeckelt.
const ENTER_STAGGER := 0.06
const ENTER_SPREAD_MAX := 0.18

## Das ANROLLEN ist ECHTE PHYSIK. Der Würfel läuft keine gezeichnete Bahn ab, er
## wird GEWORFEN: für die Dauer des Auftritts legt sich ein unsichtbarer
## Kollisions-Käfig in die Bucht (Boden, vier Wände, ein Deckel und eine Sperre vor
## dem Regal), ein Stellvertreter-Körper rollt darin, und der gezeigte Würfel folgt
## ihm Bild für Bild. Wer ruht, GLEITET auf seinen Verkaufsplatz und richtet sich
## dabei lesbar auf - erst Physik, dann Ordnung, die Grammatik der Grube.
## Der gezeigte Würfel bleibt körperlos: Kollision trägt allein der Stellvertreter,
## und der lebt nur, solange gerollt wird.

## Eigene Kollisionsschicht: Käfig und rollende Würfel sehen einander und sonst
## NICHTS - weder die Grube noch die Spielwürfel noch eine Klickzone.
const ROLL_LAYER := 4

## Die Würfel treten NACHEINANDER durch die Klappe; die Staffelung ist gedeckelt,
## sonst trüge eine volle Schale länger als ihr Budget.
const ROLL_STAGGER := 0.13
const ROLL_SPREAD_MAX := 0.5
## Harte Frist je Würfel: wer dann nicht ruht, gleitet trotzdem in die Reihe - die
## Richtigkeit hängt an keiner Simulation.
const ROLL_DEADLINE := 1.05
## Das AUFREIHEN: aus der Ruhelage auf den Verkaufsplatz, Drehung eingeschlossen.
## Es darf nicht schneller sein als das Rollen selbst, sonst liest es als Sprung -
## und ein Würfel, der weit hinten liegen bleibt, hat den weitesten Weg.
const ROLL_LINEUP := 0.42
## Der Deckel des ganzen Anrollens - länger trägt eine Auslage nie, auch mit sechs
## Würfeln nicht. Es ist bewusst die teuerste Bewegung der Bucht: der Wurf IST die
## Aussage "hier wurde neu gewürfelt".
const ROLL_BUDGET := ROLL_SPREAD_MAX + ROLL_DEADLINE + ROLL_LINEUP

## Ruhe wie in der Grube: langsam UND flach - die scharfkantige Box balanciert
## sonst scheinbar stabil auf einer Kante (DiceController.SETTLE_ALIGNMENT_MIN_DOT).
const ROLL_REST_LINEAR := 0.4
const ROLL_REST_ANGULAR := 0.7
const ROLL_REST_TIME := 0.06

## Der Wurf zielt auf den eigenen Verkaufsplatz - so verteilen sich sechs Würfel,
## statt sich an der Klappe zu stauen (die Bahnen-Regel der Grube). Gebremst wird er
## von der REIBUNG, nicht von der Zeit: sein Weg wächst mit dem QUADRAT der
## Geschwindigkeit, also folgt der Wurf der WURZEL aus seiner Entfernung. Eine
## Weg-durch-Zeit-Rechnung schickte alle sechs gleich schnell los, und am Ende lagen
## sie auf einem Haufen. Der Faktor ist die gemessene Bremsung der Bahn.
const ROLL_DRAG := 30.0
const ROLL_SPEED_MIN := 4.5
const ROLL_SPEED_MAX := 24.0
## Ein Sprung beim Eintreten und Drall um alle drei Achsen (Radiant je Sekunde).
## Der Drall liegt in der Größenordnung des ABROLLENS (Geschwindigkeit durch halbe
## Kante) - darunter schlittert der Würfel bloß, und das ist kein Wurf.
## Der Sprung war in der flachen Bucht vom Deckel gekappt - er durfte gar nicht
## ausfliegen. Der Kasten deckelt ihn nicht mehr, also steht hier, wie hoch: etwa
## eine Würfelkante. Höher las es sich als Popcornmaschine, nicht als Wurf.
const ROLL_LOFT := 2.6
const ROLL_SPIN := 16.0
const ROLL_GRAVITY := 3.5

## Wie weit hinter der Klappenmündung die Bahn beginnt (Kantenmaße) - weit genug,
## dass der Würfel GANZ in der Bucht steht, wenn er losläuft. Genau das macht den
## Käfig zu einem geschlossenen Kasten: keine Wand braucht ein Loch, keine Klappe
## eine Nische.
const ROLL_ENTRY := 0.7
## Die WARTENDEN stehen im Schacht hinter ihrer Wand, einer hinter dem anderen:
## dort deckt sie die Rückwand der Klappe. Bei genug Eintritten wartet niemand -
## jeder Würfel bekommt sein eigenes Tor.
const ROLL_QUEUE := 1.1
## Der Deckel liegt UNTER der Glasebene, um diesen Rest (in Kantenmaßen). In der
## flachen Bucht war er ein Zugeständnis: sie war niedriger als die
## Flächendiagonale eines Würfels, also musste ein kippender Würfel über den Tisch
## ragen dürfen. Die doppelt tiefe Bucht braucht das nicht mehr - kein Würfel
## überragt noch die Anzeigefläche, ein Test hält das fest. Gemessen ist der Rest
## an der SILHOUETTE: liegt ein Würfel bündig unter dem Deckel, steht seine
## Lichtlache noch ein Stück über seinem Quader, und die zählt mit.
const ROLL_HEAD := 0.16
## Die Bahn vor der Sperre bleibt mindestens so breit (Kantenmaße) - eine
## zugemauerte Bahn ist keine.
const ROLL_LANE := 1.9
## Wandstärke des Käfigs: dick genug, dass ihn kein Würfel durchschlägt.
const CAGE_WALL := 1.0

## Die KLAPPEN: sie kippen auf, während der erste Würfel schon losläuft (ihr Fallen
## IST der Anfang seines Weges - ein Vorlauf hätte den Umschlag über sein Budget
## gehoben), und schließen bündig, sobald der letzte liegt. Nur die GENUTZTEN
## rühren sich: eine Wand voll aufklappender Tore wäre ein Scheunentor.
const HATCH_OPEN := 0.2
const HATCH_CLOSE := 0.25
## Bis zu so viele Eintritte trägt eine Bucht, und wenigstens so viele hat jede -
## auch das enge Hinterzimmer, dessen Wände wenig hergeben.
const MAX_HATCHES := 8
const MIN_HATCHES := 2
## Mindestteilung zweier Tore auf derselben Wand (Vielfaches ihrer Breite). Enger
## gestellt läse die Wand als Perforation, nicht als Reihe von Toren.
const HATCH_PITCH := 2.2
## Maße der Öffnung: anderthalb Würfelkanten breit, und über ihrem Kopf bleibt
## dieser Rest Wand bis zum Kragen stehen - ohne ihn wäre die Wand ein Loch.
const HATCH_WIDTH_FACTOR := 1.5
const HATCH_CLEARANCE := 0.06
## Und so HOCH, dass ein taumelnder Würfel hindurchkommt - nicht so hoch wie die
## Wand. Abgekippt liegt das Blatt als Rampe in der Bucht, und seit die Bucht
## doppelt so tief steht, läge eine wandhohe Rampe quer über die ganze Auslage.
const HATCH_HEIGHT_FACTOR := 1.7

## Greifradius eines Stücks in der Glasebene (Vielfaches seiner halben Kante).
const PICK_FACTOR := 1.15

## Der Greifradius, GEDECKELT auf die halbe Teilung der Reihe: sechs Würfel in der
## Schale rücken enger zusammen als ihr Wunschradius, und überlappende Kreise
## ließen einen Griff am Rand den Nachbarn meinen.
static func pick_radius(wanted: float, offsets: PackedFloat32Array) -> float:
	if offsets.size() < 2:
		return wanted
	return minf(wanted, absf(offsets[1] - offsets[0]) * 0.5)

var pit: PackPitView

## Zuletzt gestellte Maße - der Abgleich stellt idempotent nach.
var center := Vector3.ZERO
var half := Vector2.ZERO

## Die zuletzt gezeigte Auslage (ShopController.vitrine_stock).
var stock: Dictionary = {}

## Je Stück ein Datensatz: {kind, index, key, spot (Welt), node, cell, radius}.
## Der Griff fragt sie ab, der Abgleich stellt sie nach.
var items: Array[Dictionary] = []

## Körper nach ihrem body_key - wer schon steht, bleibt derselbe Körper.
var _bodies: Dictionary = {}
## Ruhemaßstab je Körper - der Hover schwellt um IHN, nicht um 1.
var _rest_scale: Dictionary = {}
## Ruhelage je gerolltem Körper - das Anrollen dreht ihn, settle dreht ihn zurück.
var _rest_basis: Dictionary = {}
## Laufende Ortsbewegungen (Auftritt, Gleiten, Rollen) je Körper. settle räumt sie
## ab und legt hart - die Richtigkeit hängt an keinem Tween.
var _move_tweens: Dictionary = {}
var _hovered := ""
var _hover_tweens: Dictionary = {}
## Gemessener Hub je Körper: was er bis zur Scheibenebene an Luft hat (siehe
## HOVER_LIFT). Der Abgleich rechnet ihn beim Auslegen, nicht der Griff.
var _hover_head: Dictionary = {}
## Die laufenden Bewegungen der Klappen (Index -> Tween) - settle legt sie hart zu.
var _hatch_tweens: Dictionary = {}
## Wie viele Würfel dieser Auftritt anrollen lässt (0 = alle Klappen bleiben zu),
## und durch WELCHE Tore sie kommen (Index -> true).
var _rolling := 0
var _rolling_hatches: Dictionary = {}
## Die Ziehung der Eintritte. Eigener Generator, damit ein Test sie prüfen kann.
var roll_rng := RandomNumberGenerator.new()
## Die laufenden Würfe: je Eintrag {key, body, spot, start, delay, time, rest,
## proxy}. Der Käfig steht, solange einer davon lebt.
var _rolls: Array[Dictionary] = []
var _cage: StaticBody3D
## Laufende Nummer der Auftritte EINER Bestückung - sie staffelt sie.
var _entering := 0

## Was die WARE an Tiefe braucht: die höchste liegende Ware (ein Würfel mit seiner
## Silhouette) plus die Luft unter der Scheibe. In einer Verkaufs-Bucht steht
## nichts, alles LIEGT auf ihrem Boden - eine stehende Kassette misst hier nichts.
static func content_depth() -> float:
	var half_die := DieBuilder.HALF_EXTENT * DIE_SCALE
	return (DIE_SCALE * CONTENT_DROP + FLOOR_CLEAR + half_die * (1.0 + SILHOUETTE)
		- PackPitView.WALL_SINK)

## Die Tiefe jeder Verkaufs-Bucht: DOPPELT so tief, wie ihre Ware misst. Der
## Zuschlag ist keine Ablagefläche, er ist der KASTEN - eine Auslage hinter Glas
## hat Raum über sich, und der Wurf hat endlich einen Deckel UNTER der Anzeige
## (siehe roll_lid_y). Das Magazin behält seine eigene Tiefe: dort steht die Ware.
static func pit_depth() -> float:
	return content_depth() * DEPTH_FACTOR

## Plätze EINER Reihe: count Punkte, mittig über span verteilt. Die Teilung ist
## fest (pitch), solange sie passt - sonst rückt die Reihe zusammen. Reine
## Funktion: die Bucht rechnet ihre Plätze, sie misst keine Körper.
static func row_spots(count: int, span: float, pitch: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if count <= 0 or span <= 0.0:
		return out
	var step := minf(maxf(pitch, 0.01), span / float(count))
	var first := -step * float(count - 1) * 0.5
	for i in count:
		out.append(first + step * float(i))
	return out

## Der Schlüssel eines Platzes - Gattung und Index sind zusammen der Kaufweg, und
## in der Auslage ist der Platz zugleich der Schlüssel des KÖRPERS.
static func slot_key(kind: String, index: int) -> String:
	return "%s:%d" % [kind, index]

## Der Grad EINES Stücks. Nur die offenen Würfel der Schale kollern: eine
## versiegelte Kassette wird abgerufen statt geworfen.
## Rollen heißt Zufall, Steigen heißt Abruf.
static func item_grade(kind: String, grade: String) -> String:
	if grade == ShopController.GRADE_ROLL_IN and kind != ShopController.KIND_DIE:
		return ShopController.GRADE_RISE
	return grade

## Wie lange der Umschlag braucht, bis die Bucht leer ist.
static func swap_time(count: int) -> float:
	if count <= 0:
		return 0.0
	return SWAP_SINK + minf(SWAP_STAGGER * float(count - 1), SWAP_SPREAD_MAX)

## Der Vorlauf des n-ten anrollenden Würfels - gedeckelt, damit eine volle Schale
## nicht länger auf ihren letzten wartet als auf alle anderen zusammen.
static func roll_delay(ordinal: int) -> float:
	return minf(ROLL_STAGGER * float(maxi(ordinal, 0)), ROLL_SPREAD_MAX)

## Die WURFREIHENFOLGE der Schale (Platz-Index -> laufende Nummer): der fernste
## Würfel zuerst. Er hat die freie Bahn und kommt am weitesten, die späteren bleiben
## der Reihe nach davor liegen - so ist die ausgerollte Ordnung schon die Ordnung
## der Reihe, und kein Würfel wird beim Aufreihen quer durch seine Nachbarn gezogen.
## Die Klappe liegt am -Z-Ende, also ist der GRÖSSTE Index der fernste.
static func roll_order(entries: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	var ordinal := 0
	var i := entries.size() - 1
	while i >= 0:
		var entry: Dictionary = entries[i]
		if entry["kind"] == ShopController.KIND_DIE and entry["value"] != null:
			out[i] = ordinal
			ordinal += 1
		i -= 1
	return out

## Wie lange eine Bestückung dauert - die längste Bahn darin. Das Anrollen rechnet
## mit seiner harten Frist, nicht mit der wirklichen Ruhezeit: gemessen wird der
## schlimmste Fall, gefahren der echte.
static func entry_time(count: int, grade: String) -> float:
	if count <= 0 or grade == ShopController.GRADE_STAND:
		return 0.0
	var rise := minf(ENTER_STAGGER * float(count - 1), ENTER_SPREAD_MAX) \
		+ DataCellView.RISE_TIME
	if grade != ShopController.GRADE_ROLL_IN:
		return rise
	return maxf(rise, roll_delay(count - 1) + ROLL_DEADLINE + ROLL_LINEUP)

func _init(vitrine_name := "Vitrine") -> void:
	name = vitrine_name
	visible = false  # zugedeckt heißt: gar nicht da (die Vorhang-Invariante)

func _ready() -> void:
	set_physics_process(false)  # die Bucht tickt nur, solange etwas rollt

## Stellt die Bucht unter das gemeldete Loch: Mitte auf dem Glas, halbe Ausdehnung
## in Welt-X/Welt-Z. Idempotent - dieselben Maße bauen die Grube nicht neu.
func setup(at: Vector3, half_extents: Vector2) -> void:
	var wanted := Vector2(maxf(half_extents.x, 0.01), maxf(half_extents.y, 0.01))
	var same := pit != null and is_instance_valid(pit) \
		and center.is_equal_approx(at) and half.is_equal_approx(wanted)
	center = at
	half = wanted
	if pit == null or not is_instance_valid(pit):
		pit = PackPitView.new("VitrinePit")
		pit.glow_color = GLOW
		pit.glow_energy = GLOW_ENERGY
		pit.bay_look = true  # Automaten-Gehäuse statt Archiv - hier wird verkauft
		add_child(pit)
	if not same:
		_measure_hatches()
		pit.setup(at, wanted, pit_depth())
		_layout()

## Der VORHANG der Bucht. Bei zu ist KEIN Körper der Bucht da - Grube, Ware und
## Klappe verschwinden zusammen. Sie stünden sonst eine Haaresbreite unter der
## Anzeige und flimmerten als Grubenkontur durch die Hub-Startseite.
func set_open(value: float) -> void:
	visible = value > 0.0

## Die Öffnungen der Anrollbahnen: ihre Schwelle IST der Grubenboden - der Würfel
## kollert über das abgekippte Blatt auf genau die Fläche, auf der er liegen
## bleibt, ohne Absatz dazwischen. Maße misst sich alles an dem, was durch sie
## kommt; wie viele es sind und wo sie sitzen, sagt die Bucht selbst.
func _measure_hatches() -> void:
	if pit == null or not is_instance_valid(pit):
		return
	var edge := DieBuilder.HALF_EXTENT * DIE_SCALE * 2.0
	var head := -PackPitView.WALL_SINK - HATCH_CLEARANCE
	pit.hatch_sill = floor_y() - center.y
	pit.hatch_height = clampf(edge * HATCH_HEIGHT_FACTOR, edge * 0.4,
		maxf(head - pit.hatch_sill, edge * 0.4))
	pit.hatch_width = edge * HATCH_WIDTH_FACTOR
	pit.hatches = hatch_specs()

## Wie viele Tore je SEITENWAND (x) und auf die VORDERE Wand (y) passen. Die
## Bucht deckelt sich als Ganzes: passen mehr hinein, als sie tragen soll, geben
## alle drei Wände anteilig nach; und unter MIN_HATCHES fällt keine Bucht.
static func hatch_share(side_run: float, front_run: float, pitch: float) -> Vector2i:
	var step := maxf(pitch, 0.01)
	var side := maxi(int(floorf(side_run / step)) + 1, 0) if side_run >= 0.0 else 0
	var front := maxi(int(floorf(front_run / step)) + 1, 0) if front_run >= 0.0 else 0
	if side * 2 + front > MAX_HATCHES:
		side = mini(side, int(floorf(float(MAX_HATCHES) * 0.375)))
		front = maxi(MAX_HATCHES - side * 2, 0)
	if side * 2 + front < MIN_HATCHES:
		front = MIN_HATCHES - side * 2
	return Vector2i(side, front)

## Wo die Tore sitzen. NUR an Wandabschnitten, die an die Würfel-Zone grenzen:
## die beiden Seitenwände VOR der Sperre und die ganze vordere Wand. Durch das
## Regal kommt kein Würfel herein - hinter der Sperre läge ein Tor in der Ware.
func hatch_specs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var width := DieBuilder.HALF_EXTENT * DIE_SCALE * 2.0 * HATCH_WIDTH_FACTOR
	var pitch := width * HATCH_PITCH
	var lane_back := roll_barrier_x() - center.x
	var lane_front := -half.x
	var side_run := maxf(lane_back - lane_front - width, 0.0)
	var front_run := maxf(half.y * 2.0 - width, 0.0)
	var share := hatch_share(side_run, front_run, pitch)
	# Was die Wand nicht hergibt, gibt sie auch nicht her: der Wunsch (MIN_HATCHES)
	# endet an der Stelle, an der zwei Öffnungen ineinander liefen.
	share.x = mini(share.x, maxi(int(floorf(side_run / (width * 1.15))) + 1, 0))
	share.y = mini(share.y, maxi(int(floorf(front_run / (width * 1.15))) + 1, 0))
	var lane := row_spots(share.x, side_run, pitch)
	var lane_mid := (lane_back + lane_front) * 0.5
	for i in lane.size():
		# Auf einer Z-Wand läuft der Versatz längs Welt-X, auf der +Z-Wand
		# gespiegelt (ihre Längsrichtung zeigt nach -X).
		out.append({"wall": PackPitView.WALL_Z_MINUS, "offset": lane_mid + lane[i]})
		out.append({"wall": PackPitView.WALL_Z_PLUS, "offset": -(lane_mid + lane[i])})
	var front := row_spots(share.y, front_run, pitch)
	for i in front.size():
		out.append({"wall": PackPitView.WALL_X_MINUS, "offset": -front[i]})
	return out

## Je Wurf ein Eintritt: ZUFÄLLIG gezogen, ohne Zurücklegen, bis der Topf leer ist
## und dann neu gefüllt. Streuen ist der Punkt - eine Auslage, die immer durch
## dieselbe Klappe kommt, ist eine Rutsche, keine Auslieferung.
static func draw_entries(count: int, pot: int,
		rng: RandomNumberGenerator) -> PackedInt32Array:
	var out := PackedInt32Array()
	if count <= 0 or pot <= 0 or rng == null:
		return out
	var bag := PackedInt32Array()
	while out.size() < count:
		if bag.is_empty():
			for i in pot:
				bag.append(i)
			for i in range(bag.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var swap := bag[i]
				bag[i] = bag[j]
				bag[j] = swap
		out.append(bag[bag.size() - 1])
		bag.remove_at(bag.size() - 1)
	return out

## Die Welt-XZ-Grenzen des Lochs (der Bodenshader blendet genau sie aus).
func bounds_min() -> Vector2:
	return Vector2(center.x - half.x, center.z - half.y)

func bounds_max() -> Vector2:
	return Vector2(center.x + half.x, center.z + half.y)

## Die Oberfläche des Grubenbodens: das BETT der ganzen Auslage und die Rollfläche
## des Anrollens. Alles Liegende ruht darauf, nichts schwebt mehr darüber.
func floor_y() -> float:
	return center.y - PackPitView.WALL_SINK - pit_depth()

## Der Weg durch die LUKE - hinunter wie herauf. Er misst, was ein Körper braucht,
## um hinter der Bodenplatte zu verschwinden, NICHT die Grubentiefe: seit die
## Bucht doppelt so tief steht, wäre die ein Sturz statt eines Absinkens.
static func sink_drop() -> float:
	return content_depth()

## Die Höhe der MITTE eines liegenden Körpers halber Höhe half_height: er RUHT mit
## seiner Unterkante auf dem Grubenboden, eine Haaresbreite darüber.
func lie_y(half_height: float) -> float:
	return floor_y() + FLOOR_CLEAR + half_height

## Der Platz einer liegenden Kassette: dieselbe Bodenauflage, nur um das gemessen,
## was ihre Kontaktfinnen unter ihren Ursprung ragen lassen.
func cell_y() -> float:
	return lie_y(0.0) + DataCellView.lying_under(PackDrawerView.CASSETTE_SCALE)

## Die Auslage zeigen. EIN idempotenter Schreiber: was schon steht, bleibt
## derselbe Körper; was fehlt, entsteht; was verkauft ist, sinkt weg.
func present(new_stock: Dictionary) -> void:
	present_graded(new_stock, ShopController.GRADE_STAND)

## Die Auslage in ihrem ANKUNFTS-GRAD zeigen. Jeder Grad endet in exakt dem
## Zustand, den ein hartes present schriebe - der Abgleich stellt zuerst hart,
## gefahren wird danach nur noch der WEG dorthin.
func present_graded(new_stock: Dictionary, grade: String) -> void:
	stock = new_stock
	_layout(grade)

## Der Umschlag: alles Stehende sinkt gestaffelt durch seine Luke. Danach ist die
## Bucht LEER - was sinkt, ist nicht mehr zu greifen. Liefert die Dauer, nach der
## die Zielseite kommen darf.
func sink_all() -> float:
	settle()
	var keys := _bodies.keys()
	for i in keys.size():
		_sink_away(_bodies[keys[i]], minf(SWAP_STAGGER * float(i), SWAP_SPREAD_MAX))
	_bodies.clear()
	_rest_scale.clear()
	_rest_basis.clear()
	_hover_tweens.clear()
	_hover_head.clear()
	_move_tweens.clear()
	items.clear()
	_hovered = ""
	return swap_time(keys.size())

## Alles, was gerade fährt, liegt sofort hart auf seinem Platz. Ein Laufwechsel
## oder eine neue Auslage mitten im Auftritt darf nichts schuldig lassen.
func settle() -> void:
	for index: int in _hatch_tweens.keys():
		_kill(_hatch_tweens[index])
	_hatch_tweens.clear()
	_drop_rolls()
	_rolling = 0
	_rolling_hatches.clear()
	if pit != null and is_instance_valid(pit):
		pit.close_all_hatches()  # ein Laufwechsel legt jede Klappe hart zu
	for key: String in _move_tweens.keys():
		_kill(_move_tweens[key])
		var body: Node3D = _bodies.get(key)
		if body == null or not is_instance_valid(body):
			continue
		var spot := _spot_for_key(key)
		var cell := body as DataCellView
		if cell != null:
			cell.lie_in_pit(spot)
			continue
		body.global_position = _rest_position(key, spot)
		if _rest_basis.has(key):
			body.global_basis = _rest_basis[key]
	_move_tweens.clear()

## Laufwechsel: die Bucht ist leer, ihr Raum bleibt stehen.
func clear() -> void:
	stock = {}
	settle()
	for key: String in _bodies.keys():
		_free_body(_bodies[key])
	_bodies.clear()
	_rest_scale.clear()
	_rest_basis.clear()
	_hover_tweens.clear()
	_hover_head.clear()
	_move_tweens.clear()
	items.clear()
	_hovered = ""

# --- Der Griff -----------------------------------------------------------------

## Das Stück über diesem WELT-Punkt der Glasebene ({} = keins). Gefragt, nicht
## gemeldet: der Zeiger liegt auf dem Tisch, mouse_entered erreicht ihn nie.
func item_at(world: Vector3) -> Dictionary:
	var best := {}
	var best_distance := INF
	for item in items:
		var spot: Vector3 = item["spot"]
		var radius: float = item["radius"]
		var distance := Vector2(world.x - spot.x, world.z - spot.z).length()
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best = item
	return best

## Der Ankerpunkt eines Stücks in der Glasebene (die Beschriftung hängt darüber).
func spot_of(kind: String, index: int) -> Vector3:
	for item in items:
		if item["kind"] == kind and int(item["index"]) == index:
			return item["spot"]
	return Vector3.ZERO

## Der Zeiger liegt auf einem Stück: es hebt sich und wird eine Spur größer. Nur
## der WECHSEL wird gefahren - ein Ruf je Bild an jeden Körper wäre Arbeit für
## nichts (die Magazin-Regel).
func set_hovered(kind: String, index: int) -> void:
	var key := ""
	for item in items:
		if item["kind"] == kind and int(item["index"]) == index:
			key = item["key"]
			break
	if key == _hovered:
		return
	_apply_hover(_hovered, false)
	_hovered = key
	_apply_hover(_hovered, true)

func hovered_key() -> String:
	return _hovered

# --- Aufbau ---------------------------------------------------------------------

## Der eine Schreiber: Plätze rechnen, Körper nachstellen, Verkauftes versenken.
## Der Grad entscheidet allein, WIE die Körper auf ihre fertigen Plätze kommen.
func _layout(grade := ShopController.GRADE_STAND) -> void:
	settle()  # eine laufende Fahrt endet hier, nicht irgendwann
	items.clear()
	_entering = 0
	_rolling = 0
	if half.x <= 0.0 or half.y <= 0.0:
		return
	var wanted: Dictionary = {}
	_lay_shelf(wanted, grade)
	_lay_bowl(wanted, grade)
	_drive_hatch()
	for key: String in _bodies.keys():
		if not wanted.has(key):
			_sink_out(_bodies[key], float(_hover_head.get(key, 0.0)))
			_bodies.erase(key)
			_rest_scale.erase(key)
			_rest_basis.erase(key)
			_move_tweens.erase(key)
			_hover_tweens.erase(key)
			_hover_head.erase(key)
			if _hovered == key:
				_hovered = ""

## Hinten das Regal: jede versiegelte Kassette LIEGT auf ihrem Platz, große Fläche
## nach oben - Sortenfarbe, Zeichen und Größen-Streifen liest man von dort. Ein
## gerollter Katalysator liegt mit dabei, er belegt ja einen Paket-Platz.
func _lay_shelf(wanted: Dictionary, grade: String) -> void:
	var entries: Array[Dictionary] = []
	var row: Array = stock.get(ShopController.KIND_ENGRAVING_PACK, [])
	for i in row.size():
		entries.append({"kind": ShopController.KIND_ENGRAVING_PACK, "index": i, "pack": row[i]})
	var specials: Array = stock.get(ShopController.KIND_SPECIAL, [])
	for i in specials.size():
		var pack: Pack = specials[i]
		if pack != null and pack.is_catalyst():
			entries.append({"kind": ShopController.KIND_SPECIAL, "index": i, "pack": pack})
	var pitch := DataCellView.WIDTH * PackDrawerView.CASSETTE_SCALE * PackDrawerView.CELL_SPAN
	var offsets := row_spots(entries.size(), _field_width(), pitch)
	var radius := pick_radius(
		DataCellView.WIDTH * PackDrawerView.CASSETTE_SCALE * PICK_FACTOR, offsets)
	var x := _band_depths().x
	var rest := cell_y()
	for i in entries.size():
		var entry := entries[i]
		var spot := Vector3(x, rest, _field_center_z() + offsets[i])
		var key := slot_key(entry["kind"], entry["index"])
		var pack: Pack = entry["pack"]
		if pack == null:
			continue  # verkauft: der Platz bleibt LEER, die Lücke ist die Auskunft
		wanted[key] = true
		var cell: DataCellView = _bodies.get(key)
		if cell == null or not is_instance_valid(cell):
			cell = _spawn_cell(pack)
			_bodies[key] = cell
			_rest_scale[key] = 1.0
			cell.materialize()
		# Von oben gelesen: die Zahl liegt AUF der Karte, nicht neben ihr - neben
		# ihr steckte sie in der Grubenwand.
		cell.badge_on_face = true
		cell.set_count(maxi(pack.count, 1))
		cell.set_body_scale(PackDrawerView.CASSETTE_SCALE)
		cell.hover_lift = _cell_hover_share(cell)
		_hover_head[key] = DataCellView.HEIGHT * cell.body_scale() * cell.hover_lift
		cell.lie_in_pit(spot)
		items.append({"kind": entry["kind"], "index": entry["index"], "key": key, "spot": spot,
			"node": cell, "cell": cell, "radius": radius})
		_enter(key, entry["kind"], cell, spot, grade)

## Vorn die Schale: die offene Ware, die man vor dem Kauf SIEHT - echte Würfel
## und der blanke Sonderposten-Chip.
func _lay_bowl(wanted: Dictionary, grade: String) -> void:
	var entries: Array[Dictionary] = []
	var dice: Array = stock.get(ShopController.KIND_DIE, [])
	for i in dice.size():
		entries.append({"kind": ShopController.KIND_DIE, "index": i, "value": dice[i]})
	var specials: Array = stock.get(ShopController.KIND_SPECIAL, [])
	for i in specials.size():
		var pack: Pack = specials[i]
		if pack != null and not pack.is_catalyst():
			entries.append({"kind": ShopController.KIND_SPECIAL, "index": i, "value": pack})
	var pitch := CHIP_SIZE * 1.35
	var offsets := row_spots(entries.size(), _field_width(), pitch)
	var radius := pick_radius(CHIP_SIZE * 0.5 * PICK_FACTOR, offsets)
	var x := _band_depths().y
	# Der FERNSTE Platz wird zuerst geworfen: er hat die freie Bahn, und die
	# späteren bleiben der Reihe nach davor liegen. Ohne diese Ordnung stauen sich
	# die ersten mitten in der Bucht, und das Aufreihen zieht die letzten quer durch
	# sie hindurch.
	var order := roll_order(entries)
	# Und durch WELCHES Tor jeder kommt, wird gezogen - je Wurf einer, ohne
	# Zurücklegen. Wer ein Tor mit einem Vorgänger teilt, wartet dahinter im
	# Schacht; bei genug Toren wartet niemand.
	var pot := pit.hatch_count() if pit != null and is_instance_valid(pit) else 0
	var drawn := draw_entries(order.size(), pot, roll_rng)
	var queued := {}
	for i in entries.size():
		var entry := entries[i]
		if entry["value"] == null:
			continue  # verkauft: der Platz bleibt leer
		var is_die: bool = entry["kind"] == ShopController.KIND_DIE
		var lift := DieBuilder.HALF_EXTENT * DIE_SCALE if is_die else 0.0
		var spot := Vector3(x, lie_y(lift), _field_center_z() + offsets[i])
		var key := slot_key(entry["kind"], entry["index"])
		wanted[key] = true
		var body: Node3D = _bodies.get(key)
		if body == null or not is_instance_valid(body):
			body = _spawn_bowl_body(entry)
			_bodies[key] = body
			_rest_scale[key] = DIE_SCALE if is_die else 1.0
		# Der Würfel trägt seine Silhouette über dem Quader, der flache Chip nicht.
		var crown := lift * SILHOUETTE if is_die else 0.0
		_hover_head[key] = _hover_room(spot.y + crown, crown * (HOVER_SWELL - 1.0))
		_seat(key, body, spot)
		items.append({"kind": entry["kind"], "index": entry["index"], "key": key, "spot": spot,
			"node": body, "cell": null, "radius": radius})
		var ordinal := int(order.get(i, 0))
		var gate := int(drawn[ordinal]) if ordinal < drawn.size() else 0
		var behind := int(queued.get(gate, 0))
		if order.has(i):
			queued[gate] = behind + 1
		_enter(key, entry["kind"], body, spot, grade, ordinal, gate, behind)

## Wie weit eine liegende Kassette bzw. das höchste Stück der Schale von seiner
## Mitte aus nach vorn und hinten reicht - daran messen sich die beiden Bänder.
static func shelf_reach() -> float:
	return DataCellView.HEIGHT * PackDrawerView.CASSETTE_SCALE * 0.5

static func bowl_reach() -> float:
	return maxf(DieBuilder.HALF_EXTENT * DIE_SCALE * SILHOUETTE, CHIP_SIZE * 0.5)

## Die Tiefenmitten der beiden Bänder (x = Regal, y = Schale). Normalerweise stehen
## sie auf ihren Anteilen; liegend ist eine Kassette aber länger als ihr Band in
## einer engen Bucht (das Hinterzimmer), und dann rücken beide auf Anschlag an ihre
## Wände und teilen sich die Tiefe nach ihren wirklichen Längen.
func _band_depths() -> Vector2:
	var margin := half.x * 2.0 * WALL_MARGIN
	var back := center.x + half.x - margin
	var front := center.x - half.x + margin
	var shelf := minf(_depth_at(0.0, SHELF_DEPTH_SHARE), back - shelf_reach())
	var bowl := maxf(_depth_at(SHELF_DEPTH_SHARE, 1.0), front + bowl_reach())
	var need := shelf_reach() + bowl_reach()
	if shelf - bowl >= need:
		return Vector2(shelf, bowl)
	if need > back - front:
		var squeeze := (back - front) / need
		return Vector2(back - shelf_reach() * squeeze, front + bowl_reach() * squeeze)
	return Vector2(back - shelf_reach(), front + bowl_reach())

## Tiefenmitte eines Bandes (0 = hintere Wand, 1 = vordere), Wandrand abgezogen.
## HINTEN ist Welt-+X: world_to_pixel spiegelt die Tiefenachse (v = x_max - x),
## der Bildschirm-oben liegt also am GRÖSSEREN x.
func _depth_at(share_start: float, share_end: float) -> float:
	var margin := half.x * 2.0 * WALL_MARGIN
	var usable := maxf(half.x * 2.0 - margin * 2.0, 0.01)
	return center.x + half.x - margin - usable * (share_start + share_end) * 0.5

## Nutzbare Breite der Auslage: die ganze Bucht ohne den Wandrand. Bezahlte Ware
## wartet hier nicht mehr, also gehört die Fläche der Auslage allein.
func _field_width() -> float:
	return maxf(half.y * 2.0 * (1.0 - WALL_MARGIN * 2.0), 0.01)

func _field_center_z() -> float:
	return center.z

func _spawn_cell(pack: Pack) -> DataCellView:
	var cell := DataCellView.new()
	cell.name = "VitrineCell"
	add_child(cell)
	cell.setup(Pack.shelf_of(pack), pack.tier)
	# Dieselbe Vierteldrehung wie ein Tray-Würfel: erst damit steht das Siegel
	# aufrecht im Bild (Bildschirm-oben = Welt+X).
	cell.rotation.y = -PI / 2.0
	return cell

func _spawn_bowl_body(entry: Dictionary) -> Node3D:
	if entry["kind"] == ShopController.KIND_DIE:
		var die := _spawn_die(entry["value"])
		add_child(die)
		return die
	var chip := _build_special_chip(entry["value"])
	add_child(chip)
	return chip

## Ein Würfel in der Bucht hat keinen Tisch unter sich: seine Boden-Lache hinge
## als Lichtfleck AUF der Scheibe statt unter ihm.
func _spawn_die(def: DieDefinition) -> Node3D:
	var die := FloatingDie.build_ghost(def)
	var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	faces.set_pool_enabled(false)
	return die

## Der Sonderposten-Chip: sein Zeichen, EINMAL in eine Textur gebacken, auf einem
## flachen Plättchen über weichem Sortenglühen - dieselbe Zeichnung wie in der
## Ablage der Presse, nur körperlich.
func _build_special_chip(pack: Pack) -> Node3D:
	var root := Node3D.new()
	root.name = "SpecialChip"
	# Weiches Sortenglühen darunter: ein RADIALER Verlauf, keine Kachel - eine
	# Fläche mit harter Kante läse sich als Panel unter einem physischen Ding.
	root.add_child(_chip_plate("Glow", _glow_texture(
		PackDrawerView.COLORS.get(Pack.shelf_of(pack), PackDrawerView.GOLD)),
		CHIP_GLOW_SIZE, CHIP_GLOW_ENERGY, -CHIP_GLOW_DROP))
	root.add_child(_chip_plate("Face",
		EngravingRenderer.bare_texture(pack.fixed_engraving, CHIP_TEXTURE, root),
		CHIP_SIZE, CHIP_ENERGY, 0.0))
	return root

func _chip_plate(plate_name: String, texture: Texture2D, side: float,
		energy: float, drop: float) -> MeshInstance3D:
	var plate := MeshInstance3D.new()
	plate.name = plate_name
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * side
	plate.mesh = mesh
	plate.rotation.x = -PI / 2.0
	plate.position.y = drop
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(energy, energy, energy, 1.0)
	material.albedo_texture = texture
	plate.material_override = material
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return plate

func _glow_texture(tint: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(tint.r, tint.g, tint.b, 0.42), Color(tint.r, tint.g, tint.b, 0.16),
		Color(tint.r, tint.g, tint.b, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 96
	texture.height = 96
	return texture

## Wie hoch ein Stück greifen darf: bis knapp unter die Anzeigefläche, über der
## die Scheibe liegt - nie hindurch. top ist seine Oberkante in Ruhe, swell, was
## das Anschwellen zusätzlich hebt.
func _hover_room(top: float, swell: float) -> float:
	return clampf(center.y - GLASS_CLEAR - (top + swell), 0.0, HOVER_LIFT)

## Derselbe Deckel für eine liegende Kassette, in IHREM Maß (Anteil der Höhe - so
## rechnet die Zelle ihren Hub). Im Magazin liegt keine Scheibe über der Grube,
## dort behält sie ihren vollen Hub.
func _cell_hover_share(cell: DataCellView) -> float:
	var span := DataCellView.HEIGHT * cell.body_scale()
	if span <= 0.0:
		return 0.0
	var top := cell_y() + DataCellView.lying_over(cell.body_scale())
	return clampf(_hover_room(top, 0.0) / span, 0.0, DataCellView.HOVER_LIFT)

## Wo ein Körper wirklich ruht: auf seinem Platz, gegriffen um seinen Hub höher.
func _rest_position(key: String, spot: Vector3) -> Vector3:
	if key != _hovered:
		return spot
	return spot + Vector3.UP * float(_hover_head.get(key, 0.0))

## Hart auf seinen Platz - die Richtigkeit hängt an keinem Tween. Ein gegriffenes
## Stück behält dabei seinen Hub: der Abgleich darf ihm nicht in die Hand fallen.
func _seat(key: String, body: Node3D, spot: Vector3) -> void:
	if body == null or not is_instance_valid(body):
		return
	body.global_position = _rest_position(key, spot)

## Der AUFTRITT eines Stücks. Sein Platz steht schon hart - hier bekommt er nur
## seinen Weg dorthin, gestaffelt in der Reihenfolge, in der die Bucht rechnet.
func _enter(key: String, kind: String, body: Node3D, spot: Vector3, grade: String,
		ordinal := 0, gate := 0, behind := 0) -> void:
	var mode := item_grade(kind, grade)
	if mode == ShopController.GRADE_STAND or body == null or not is_instance_valid(body):
		return
	_kill(_move_tweens.get(key))
	_kill(_hover_tweens.get(key))
	if not (body is DataCellView):
		body.scale = Vector3.ONE * float(_rest_scale.get(key, 1.0))
	# Das Anrollen zählt seine eigene Staffelung: die Würfel gehen durch ihre
	# gezogenen Tore, die steigenden Kassetten durch ihre je eigene Luke.
	if mode == ShopController.GRADE_ROLL_IN:
		_roll_in(key, body, spot, ordinal, gate, behind)
		return
	var delay := minf(ENTER_STAGGER * float(_entering), ENTER_SPREAD_MAX)
	_entering += 1
	_rise(key, body, spot, delay)

## Steigen heißt Abruf: dasselbe Stück kommt in seiner gemerkten Lage aus der Luke
## zurück. Es ist kein Wurf - es ist dieselbe Ware.
func _rise(key: String, body: Node3D, spot: Vector3, delay: float) -> void:
	var cell := body as DataCellView
	if cell != null:
		cell.rise_into_pit(spot, sink_drop(), delay, DataCellView.RISE_TIME, true)
		# Die Zelle fährt ihren Tween selbst - gemerkt wird nur, DASS sie unterwegs
		# ist, damit settle sie hart auf ihren Platz legen kann.
		_move_tweens[key] = null
		return
	var target := _rest_position(key, spot)
	body.global_position = target - Vector3.UP * sink_drop()
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(body, "global_position", target, DataCellView.RISE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tweens[key] = tween

## Anrollen heißt Zufall - und der Zufall ist hier zweifach ECHT: durch WELCHES
## Tor der Würfel kommt, wird gezogen, und was danach geschieht, ist Physik. Er
## wird in die vordere Bahn geworfen, rollt gegen Wände und Nachbarn aus und
## gleitet erst nach seiner Ruhe auf den Verkaufsplatz. Sein Weg beginnt an der
## Klappenmündung - keine Wand wird durchquert -, und teilt er sein Tor mit einem
## Vorgänger, wartet er im Schacht dahinter, wo ihn die Rückwand deckt.
func _roll_in(key: String, body: Node3D, spot: Vector3, ordinal: int,
		gate: int, behind: int) -> void:
	var rest: Basis = _rest_basis.get(key, body.global_basis)
	_rest_basis[key] = rest
	var edge := DieBuilder.HALF_EXTENT * DIE_SCALE * 2.0
	_rolling += 1
	_rolling_hatches[gate] = true
	var mouth := _hatch_mouth(gate, edge)
	body.global_position = mouth - _gate_inward(gate) * edge * ROLL_QUEUE * float(behind)
	body.global_basis = rest
	# Gemerkt wird nur, DASS er unterwegs ist - settle legt ihn dann hart auf
	# seinen Platz, ganz ohne Tween.
	_move_tweens[key] = null
	_rolls.append({"key": key, "body": body, "spot": spot, "start": mouth,
		"gate": gate, "delay": roll_delay(ordinal), "time": 0.0, "rest": 0.0,
		"proxy": null})
	set_physics_process(true)

## Der Takt des Anrollens: jeder laufende Wurf bekommt seinen Schritt, und mit dem
## letzten verschwindet der Käfig wieder - die Bucht ist in Ruhe körperlos.
func _physics_process(delta: float) -> void:
	var index := 0
	while index < _rolls.size():
		if _step_roll(_rolls[index], delta):
			index += 1
		else:
			_rolls.remove_at(index)
	if _rolls.is_empty():
		_drop_cage()
		_close_hatch()
		set_physics_process(false)

## Ein Schritt EINES Wurfs; false, sobald er aus der Liste darf. Erst läuft sein
## Vorlauf ab, dann folgt der gezeigte Würfel seinem Stellvertreter, und Ruhe oder
## Frist schicken ihn in die Reihe.
func _step_roll(roll: Dictionary, delta: float) -> bool:
	var body: Node3D = roll["body"]
	if body == null or not is_instance_valid(body):
		_free_proxy(roll)
		return false
	roll["time"] = float(roll["time"]) + delta
	var proxy: RigidBody3D = roll["proxy"]
	if proxy == null or not is_instance_valid(proxy):
		if float(roll["time"]) < float(roll["delay"]):
			return true
		_launch_roll(roll)
		return true
	# Der Maßstab kommt aus der RUHELAGE, nicht aus dem Körper: über hunderte Bilder
	# zurückgelesen driftete er sonst weg.
	var rest: Basis = _rest_basis.get(roll["key"], Basis.IDENTITY)
	body.global_transform = Transform3D(
		proxy.global_basis.orthonormalized().scaled(rest.get_scale()), proxy.global_position)
	var flat := _flat_dot(proxy.global_basis) >= DiceController.SETTLE_ALIGNMENT_MIN_DOT
	var slow := proxy.linear_velocity.length() < ROLL_REST_LINEAR \
		and proxy.angular_velocity.length() < ROLL_REST_ANGULAR
	if slow and flat:
		roll["rest"] = float(roll["rest"]) + delta
	else:
		roll["rest"] = 0.0
	var due := float(roll["delay"]) + ROLL_DEADLINE
	if float(roll["rest"]) < ROLL_REST_TIME and float(roll["time"]) < due:
		return true
	_free_proxy(roll)
	_line_up(roll)
	return false

## Der Wurf selbst: der Stellvertreter entsteht an der Klappenmündung und wird auf
## den eigenen Verkaufsplatz geworfen - gedeckelt, damit er weder liegen bleibt
## noch quer durch die Bucht schießt. Der Drall ist frei, das ist der Punkt.
func _launch_roll(roll: Dictionary) -> void:
	_build_cage()
	var body: Node3D = roll["body"]
	var start: Vector3 = roll["start"]
	var spot: Vector3 = roll["spot"]
	var proxy := _spawn_proxy()
	proxy.global_transform = Transform3D(body.global_basis.orthonormalized(), start)
	var reach := Vector3(spot.x - start.x, 0.0, spot.z - start.z)
	var speed := clampf(sqrt(ROLL_DRAG * reach.length()), ROLL_SPEED_MIN, ROLL_SPEED_MAX)
	# Steht sein Platz fast auf der Mündung, läuft er wenigstens in die Bucht
	# hinein - nach außen zeigt sein Tor.
	var heading := reach.normalized() if reach.length() > 0.01 \
		else _gate_inward(int(roll.get("gate", 0)))
	proxy.linear_velocity = heading * speed + Vector3.UP * ROLL_LOFT
	proxy.angular_velocity = Vector3(
		randf_range(-ROLL_SPIN, ROLL_SPIN),
		randf_range(-ROLL_SPIN, ROLL_SPIN),
		randf_range(-ROLL_SPIN, ROLL_SPIN))
	body.global_position = start  # der Wartende tritt in diesem Bild aus dem Schacht
	roll["proxy"] = proxy

## Aufreihen zur Inspektion: aus der ausgerollten Lage auf den Verkaufsplatz, und
## dabei zurück in die lesbare Ruhelage - erst Physik, dann Ordnung. Der Endzustand
## ist byteweise der, den ein hartes present schriebe.
func _line_up(roll: Dictionary) -> void:
	var key: String = roll["key"]
	var body: Node3D = roll["body"]
	var rest: Basis = _rest_basis.get(key, body.global_basis)
	var from := body.global_transform
	var target := _rest_position(key, roll["spot"])
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void: _pose_along(body, from, target, rest, t),
		0.0, 1.0, ROLL_LINEUP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_move_tweens[key] = tween

static func _pose_along(body: Node3D, from: Transform3D, target: Vector3,
		rest: Basis, t: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	if t >= 1.0:
		body.global_transform = Transform3D(rest, target)  # das Ende ist gestellt, nicht gerechnet
		return
	var turn := from.basis.orthonormalized().slerp(rest.orthonormalized(), t)
	body.global_transform = Transform3D(
		turn.scaled(rest.get_scale()), from.origin.lerp(target, t))

## Wie flach der Körper liegt: das Skalarprodukt der bestausgerichteten Achse mit
## oben (1 = liegt exakt flach). Dieselbe Prüfung wie in der Grube.
static func _flat_dot(basis: Basis) -> float:
	var best := -INF
	for axis: String in DiceController.AXIS_DIRECTIONS:
		var direction: Vector3 = DiceController.AXIS_DIRECTIONS[axis]
		best = maxf(best, (basis * direction).normalized().dot(Vector3.UP))
	return best

# --- Der Käfig ------------------------------------------------------------------

## Die hintere Grenze der Rollbahn: eine unsichtbare SPERRE vor dem Regal, damit
## kein anrollender Würfel in die liegende Ware pflügt. Sie lässt der Bahn
## mindestens ROLL_LANE Kanten Platz und weicht in einer engen Bucht bis an die
## Regalkante zurück, statt die Bahn zuzumauern.
func roll_barrier_x() -> float:
	var edge := DieBuilder.HALF_EXTENT * DIE_SCALE * 2.0
	var bands := _band_depths()
	var lane := center.x - half.x + edge * ROLL_LANE
	return minf(maxf(bands.y + bowl_reach(), lane), bands.x - shelf_reach())

## Der Deckel des Käfigs. Er liegt UNTER der Anzeigefläche: die Bucht ist tiefer
## als die Flächendiagonale eines Würfels, also bleibt der ganze Wurf im Kasten.
func roll_lid_y() -> float:
	return center.y - DieBuilder.HALF_EXTENT * DIE_SCALE * 2.0 * ROLL_HEAD

## Der Käfig entsteht erst mit dem ERSTEN Wurf - nicht im Bild, in dem die Bucht
## gebaut wird - und verschwindet mit dem letzten. Er ist ein GESCHLOSSENER Kasten:
## Boden, Deckel, die Sperre vor dem Regal und die drei echten Buchtwände. Nischen
## und Wandlücken brauchte er, solange der Würfel halb in der Wand startete; seit
## ROLL_ENTRY weit genug hineinmisst, beginnt jeder Wurf INNEN.
func _build_cage() -> void:
	if _cage != null and is_instance_valid(_cage):
		return
	_cage = StaticBody3D.new()
	_cage.name = "RollCage"
	_cage.collision_layer = ROLL_LAYER
	_cage.collision_mask = 0
	_cage.physics_material_override = _roll_surface()
	add_child(_cage)
	_cage.global_position = Vector3.ZERO
	var bottom := floor_y()
	var lid := roll_lid_y()
	var height := lid - bottom
	var mid_y := (bottom + lid) * 0.5
	var back := roll_barrier_x()
	var front := center.x - half.x
	var mid_x := (back + front) * 0.5
	var span_x := back - front
	var z0 := center.z - half.y
	var z1 := center.z + half.y
	var span_z := z1 - z0
	var plate := Vector3(span_x + CAGE_WALL * 2.0, CAGE_WALL, span_z + CAGE_WALL * 2.0)
	_cage_box("Floor", plate, Vector3(mid_x, bottom - CAGE_WALL * 0.5, center.z))
	_cage_box("Lid", plate, Vector3(mid_x, lid + CAGE_WALL * 0.5, center.z))
	var side := Vector3(CAGE_WALL, height, span_z + CAGE_WALL * 2.0)
	_cage_box("Barrier", side, Vector3(back + CAGE_WALL * 0.5, mid_y, center.z))
	_cage_box("Front", side, Vector3(front - CAGE_WALL * 0.5, mid_y, center.z))
	var wall := Vector3(span_x, height, CAGE_WALL)
	_cage_box("WallZPlus", wall, Vector3(mid_x, mid_y, z1 + CAGE_WALL * 0.5))
	_cage_box("WallZMinus", wall, Vector3(mid_x, mid_y, z0 - CAGE_WALL * 0.5))

func _cage_box(box_name: String, box_size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = box_name
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	shape.position = at
	_cage.add_child(shape)

## Dieselbe Oberfläche wie Grubenwand und Spielwürfel - beide Seiten eines
## Aufpralls geben gleich viel zurück.
static func _roll_surface() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.bounce = DieBuilder.BOUNCE
	material.friction = DieBuilder.FRICTION
	return material

## Der Stellvertreter: ein nackter Körper in Würfelgröße, der NUR den Käfig und
## seinesgleichen sieht. Der gezeigte Würfel bleibt der körperlose Ghost.
func _spawn_proxy() -> RigidBody3D:
	var proxy := RigidBody3D.new()
	proxy.name = "RollProxy"
	proxy.collision_layer = ROLL_LAYER
	proxy.collision_mask = ROLL_LAYER
	proxy.gravity_scale = ROLL_GRAVITY
	proxy.linear_damp = 0.2
	proxy.angular_damp = 0.4
	proxy.continuous_cd = true
	proxy.physics_material_override = _roll_surface()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * DieBuilder.HALF_EXTENT * 2.0 * DIE_SCALE
	shape.shape = box
	proxy.add_child(shape)
	add_child(proxy)
	return proxy

## Der Stellvertreter geht SOFORT aus dem Spiel - eingefroren und ohne Schichten -,
## freigegeben wird er danach: einen Körper mitten im Physikschritt aus dem Baum zu
## reißen, ist die eine Sache, die Godot einem übelnimmt.
func _free_proxy(roll: Dictionary) -> void:
	var proxy: RigidBody3D = roll.get("proxy")
	roll["proxy"] = null
	if proxy == null or not is_instance_valid(proxy):
		return
	proxy.freeze = true
	proxy.collision_layer = 0
	proxy.collision_mask = 0
	proxy.queue_free()

## Ein Laufwechsel, eine neue Auslage, ein übersprungener Auftritt: die Physik hört
## sofort auf, und kein Körper bleibt zurück.
func _drop_rolls() -> void:
	for roll in _rolls:
		_free_proxy(roll)
	_rolls.clear()
	_drop_cage()
	set_physics_process(false)

func _drop_cage() -> void:
	if _cage == null or not is_instance_valid(_cage):
		_cage = null
		return
	_cage.collision_layer = 0
	_cage.queue_free()
	_cage = null

## Wohin der Wurf aus diesem Tor läuft (ohne Grube: die alte -Z-Richtung).
func _gate_inward(gate: int) -> Vector3:
	if pit == null or not is_instance_valid(pit) or pit.hatch_count() <= 0:
		return Vector3.BACK
	return pit.hatch_inward(gate)

## Die Mündung EINES Tores: der Punkt auf dem abgekippten Blatt, auf dem der
## Würfel losläuft - schon GANZ in der Bucht. Ohne Klappe (Probe ohne Grube)
## bleibt es die alte Wandkante.
func _hatch_mouth(gate: int, edge: float) -> Vector3:
	if pit == null or not is_instance_valid(pit) or pit.hatch_count() <= 0:
		return Vector3(_band_depths().y, lie_y(edge * 0.5),
			bounds_min().y + edge * ROLL_ENTRY)
	return pit.hatch_hinge(gate) + pit.hatch_inward(gate) * edge * ROLL_ENTRY \
		+ Vector3.UP * (FLOOR_CLEAR + edge * 0.5)

## Die GENUTZTEN Klappen kippen ab, während der erste Würfel schon läuft;
## geschlossen werden sie erst, wenn der LETZTE ausgerollt ist - eine Physik weiß
## vorher nicht, wann das sein wird, also meldet sie es (_physics_process). Tore,
## durch die niemand kommt, rühren sich nicht.
func _drive_hatch() -> void:
	if pit == null or not is_instance_valid(pit):
		return
	for index: int in _hatch_tweens.keys():
		_kill(_hatch_tweens[index])
	_hatch_tweens.clear()
	if _rolling <= 0:
		pit.close_all_hatches()
		return
	for gate: int in _rolling_hatches.keys():
		_move_hatch(gate, 1.0, HATCH_OPEN, Tween.EASE_OUT)

func _close_hatch() -> void:
	if pit == null or not is_instance_valid(pit):
		return
	for gate: int in _rolling_hatches.keys():
		_move_hatch(gate, 0.0, HATCH_CLOSE, Tween.EASE_IN)

func _move_hatch(gate: int, to: float, time: float, ease_mode: Tween.EaseType) -> void:
	_kill(_hatch_tweens.get(gate))
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: pit.set_hatch_open(gate, value),
		pit.hatch_open_amount(gate), to, time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(ease_mode)
	_hatch_tweens[gate] = tween

func _apply_hover(key: String, on: bool) -> void:
	if key == "":
		return
	var body: Node3D = _bodies.get(key)
	if body == null or not is_instance_valid(body):
		return
	if body is DataCellView:
		(body as DataCellView).set_hovered(on)
		return
	var base: float = _rest_scale.get(key, 1.0)
	var spot := _spot_for_key(key)
	_kill(_hover_tweens.get(key))
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "global_position",
		spot + Vector3.UP * (float(_hover_head.get(key, 0.0)) if on else 0.0), HOVER_TIME)
	tween.tween_property(body, "scale",
		Vector3.ONE * base * (HOVER_SWELL if on else 1.0), HOVER_TIME)
	_hover_tweens[key] = tween

func _spot_for_key(key: String) -> Vector3:
	for item in items:
		if item["key"] == key:
			return item["spot"]
	return Vector3.ZERO

func _kill(tween: Variant) -> void:
	var running := tween as Tween
	if running != null and running.is_valid():
		running.kill()

## Wie lange ein übergebenes Stück braucht, bis es unter dem Grubenboden ist -
## erst dann fährt das Förderwerk (scene_root richtet seine Fahrt danach).
static func take_out_time() -> float:
	return LIFT_TIME + SINK_TIME

## Verkauft: der Körper hebt sich kurz an - die Übergabe - und sinkt dann durch
## seine Luke unter den Grubenboden, wo ihn das Förderwerk übernimmt. Auch dieses
## Anheben bleibt unter der Scheibe: es ist derselbe gemessene Hub wie beim Griff.
func _sink_out(body: Node3D, lift: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var cell := body as DataCellView
	if cell != null:
		cell.set_hovered(false)
	var tween := create_tween()
	tween.tween_property(body, "global_position",
		body.global_position + Vector3.UP * lift, LIFT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "global_position",
		body.global_position - Vector3.UP * (sink_drop() + DataCellView.HEIGHT), SINK_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(_free_body.bind(body))

## Umschlag: das Stück sinkt einfach weg. Kein Anheben - beim Blättern wird nichts
## übergeben, die Seite wird gewechselt.
func _sink_away(body: Node3D, delay: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var cell := body as DataCellView
	if cell != null:
		cell.set_hovered(false)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(body, "global_position",
		body.global_position - Vector3.UP * (sink_drop() + DataCellView.HEIGHT), SWAP_SINK) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(_free_body.bind(body))

func _free_body(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.get_parent() == self:
		remove_child(body)
	body.queue_free()
