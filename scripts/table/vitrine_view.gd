class_name VitrineView
extends Node3D
## Die VITRINE: die AUSLAGE unter einem Laden-Fenster, in der die Ware KÖRPERLICH
## liegt - und zwar AUF der Tischfläche. Es gibt keine Grube: die Ware tritt auf,
## indem sie durch die Fläche STEIGT, und geht, indem sie darin versinkt. Was
## darunter liegt, deckt das opake Display-Mesh weg (die Ausgabefach-Geste).
## Getrennt wird nach dem PLATZ, nicht nach der Lage: hinten das REGAL (versiegelte
## Data-Cells), vorn die SCHALE (die offene Ware: echte Würfel). Führt eine Auslage
## GAR KEINE Regalware - so der Laden, seit alles Versiegelte in den
## Kassetten-Schlitzen des Tisches steckt -, dann gehört die Tiefe der Schale
## allein, und die rückt an die HINTERE Kante: das freie Band davor trägt die
## Würfelnetze.
## Bezahlte Ware wartet hier NICHT: sie fährt an die Werkbank und landet in der
## Schale daneben (AusgabefachView) - der Hub kauft, die Werkstatt nutzt.
## In der Auslage hängt kein Preisschild - hinsehen nennt ihn.
## Aufgedeckt wird wie an einem Mahjong-Automaten: eine Lichtfuge kündigt an, dann
## fährt jede ZONE als BLOCK linear aus der Fläche und rastet mit einem Setz-Dip
## ein - Regal zuerst, Schale danach; beim Blättern taucht dieselbe Folge
## gespiegelt. Eine echte Bühne gibt es dabei nicht: das opake Display verschluckt,
## was unter der Fläche steht.
## Zwei Instanzen sind vorgesehen - Laden und Schwarzmarkt -, deshalb trägt jede
## ihren eigenen Namen und misst sich allein an dem Rechteck, das man ihr stellt.

## Würfel liegen in TRAY-Größe (Spec) - dasselbe Maß, in dem der Spieler seine
## Würfel überall sonst sieht.
const DIE_SCALE := DiceTrayView.DIE_SCALE

## Die Silhouette eines liegenden Würfels als Vielfaches seiner halben Kante:
## Eckkappen, Kantenbalken und Lichtlache stehen über seinem Quader hinaus.
const SILHOUETTE := 1.25
## Die Ware ruht AUF der Fläche - eine Haaresbreite darüber, sonst kämpfen ihre
## Unterseite und die Anzeige im Tiefenpuffer.
const FLOOR_CLEAR := 0.03

## Aufteilung der Auslagefläche (Anteile): Regal (hinten) und Schale (vorn) teilen
## sich die ganze Tiefe.
const SHELF_DEPTH_SHARE := 0.42
## Rand, den die Ware zur Kante der Auslage hält.
const EDGE_MARGIN := 0.10

## Greifen: das Stück hebt sich ein Stück und wird eine Spur größer (die
## Magazin-Geste - eine Akte, die man aus der Schublade zieht). Über der Auslage
## liegt nichts mehr, was den Hub deckeln müsste.
const HOVER_LIFT := DIE_SCALE * 0.45
const HOVER_SWELL := 1.08
const HOVER_TIME := 0.14

## Übergeben: das gekaufte Stück hebt sich kurz an und sinkt dann durch die
## Fläche - erst danach fährt die Lieferung damit los. Der EINZELKAUF fährt keinen
## Maschinenzyklus: er ist eine Übergabe, kein Aufdecken.
const TAKE_LIFT_TIME := 0.14
const TAKE_SINK_TIME := 0.3

## Die ZONEN der Hebebühne: hinten das Regal, davor die Schale. Sie fahren
## NACHEINANDER - innerhalb einer Zone aber SYNCHRON, als EIN Block. Im Laden führt
## die Auslage nur die Schale; ihre Regal-Zone ist die Kassetten-Schlitzreihe des
## Tisches, und die taktet scene_root nach denselben Zahlen.
const ZONE_SHELF := 0
const ZONE_BOWL := 1
const ZONE_COUNT := 2
## Die Überlappung des UMSCHLAGS (das Tauchen): Zone 2 taucht, wenn Zone 1 etwa
## zu zwei Dritteln unten ist.
const ZONE_LAG := 0.28
## Und die des AUFTRITTS: der Maschinenzyklus ist länger als ein Tauchgang, also
## darf die zweite Zone später anfahren - sie startet, während die erste noch
## senkt. Eigene Zahl, damit die Sink-Seite unberührt bleibt.
const LIFT_LAG := 0.42
## Die ANKÜNDIGUNG: so lange glüht die Lichtfuge, bevor sich in ihrer Zone etwas
## rührt. Der Automat meldet sich, dann fährt er.
const SEAM_LEAD := 0.26

## Die ECHTE Mechanik des Auftritts (der Mahjong-Automat) steckt im Schachtkörper -
## Senken, Einschub von hinten, gemeinsamer Hub. Ihre Zeiten gehören ihm
## (LiftShaftView.cycle_time), der Auslage gehört nur der Takt ihrer Zonen.
## Kopffreiheit über dem höchsten Stück: so tief fährt die Plattform, so tief
## wartet die Ware.
const SHAFT_ROOM := 1.45
## Rand, den der Schacht um seine Reihe hält - als Anteil der Reichweite des
## Stücks, damit er mit dem Inhalt wächst.
const SHAFT_MARGIN_SHARE := 0.35

## Der WARENUMSCHLAG des Blätterns: dieselbe Sprache rückwärts - je Zone ein
## synchroner Plunge, die Reihenfolge GESPIEGELT (die Schale taucht zuerst).
const SWAP_SINK := 0.24
const SWAP_TIME := SWAP_SINK + ZONE_LAG

## Greifradius eines Stücks in der Tischebene (Vielfaches seiner halben Kante).
const PICK_FACTOR := 1.15

## Der Greifradius, GEDECKELT auf die halbe Teilung der Reihe: sechs Würfel in der
## Schale rücken enger zusammen als ihr Wunschradius, und überlappende Kreise
## ließen einen Griff am Rand den Nachbarn meinen.
static func pick_radius(wanted: float, offsets: PackedFloat32Array) -> float:
	if offsets.size() < 2:
		return wanted
	return minf(wanted, absf(offsets[1] - offsets[0]) * 0.5)

## Die Schale steht (oder ist eben in Bewegung geraten). Die Netze der Ladenseite
## hängen daran: eine Beschriftung unter einem steigenden Würfel wäre eine Lüge.
## Gemeldet, nicht abgefragt.
signal dice_settled
signal dice_moving

## Ein Schacht steht offen bzw. ist zu. GEMELDET nach draußen, weil das LOCH in
## der Anzeige den Shadern gehört und eine View nicht in sie greift: scene_root
## reicht es an TableScreen weiter.
signal shaft_opened(zone: int, at: Vector3, half_extents: Vector2)
signal shaft_closed(zone: int)

## Zuletzt gestellte Maße - der Abgleich stellt idempotent nach.
var center := Vector3.ZERO
var half := Vector2.ZERO

## Die zuletzt gezeigte Auslage (ShopController.vitrine_stock).
var stock: Dictionary = {}

## Was die BESCHRIFTUNG vor der Schale beansprucht (Welt-Tiefe): Netze und
## Preisschilder der Seite liegen dort. Die Auslage weiß nichts von ihnen - sie
## bekommt nur die Zahl gesagt und stellt den Block aus Ware + Beschriftung
## MITTIG ins Band, statt die Ware an die hintere Kante zu drücken. Gesetzt von
## scene_root, das die Seite mißt.
var label_reserve := 0.0:
	set(value):
		var wanted := maxf(value, 0.0)
		if is_equal_approx(label_reserve, wanted):
			return
		label_reserve = wanted
		_layout()

## Je Stück ein Datensatz: {kind, index, key, spot (Welt), node, cell, radius}.
## Der Griff fragt sie ab, der Abgleich stellt sie nach.
var items: Array[Dictionary] = []

## Körper nach ihrem body_key - wer schon steht, bleibt derselbe Körper.
var _bodies: Dictionary = {}
## Ruhemaßstab je Körper - der Hover schwellt um IHN, nicht um 1.
var _rest_scale: Dictionary = {}
## Laufende Ortsbewegungen (Auftritt, Gleiten) je Körper. settle räumt sie ab und
## legt hart - die Richtigkeit hängt an keinem Tween.
var _move_tweens: Dictionary = {}
var _hovered := ""
var _hover_tweens: Dictionary = {}
## Hub je Körper - der Abgleich rechnet ihn beim Auslegen, nicht der Griff.
var _hover_head: Dictionary = {}
## Steht die Schale? Gemessen wird am DECKEL des Auftritts (entry_time).
var _bowl_settled := true
var _settle_token := 0
## Je Zone ihr Schachtkörper und der EINE Tween ihres Maschinenzyklus - Platte und
## Ware fahren darin gemeinsam.
var _shafts: Dictionary = {}
var _zone_tweens: Dictionary = {}
## Der Ton, den die bündige Plattform trägt - der Grund des Fensters, in dem die
## Auslage steht. Gemeldet von draußen: die Auslage kennt ihre Seite nicht.
var deck_tint := LiftShaftView.DECK_TOP

## Was die höchste liegende Ware über der Tischfläche einnimmt: ein Würfel samt
## SILHOUETTE oder eine liegende Kassette. Daran misst sich der Weg durch die
## Fläche - tiefer muss nichts sinken, um verdeckt zu sein.
static func content_depth() -> float:
	var die_top := DieBuilder.HALF_EXTENT * DIE_SCALE * (1.0 + SILHOUETTE)
	var cell_top := DataCellView.lying_under(PackDrawerView.CASSETTE_SCALE) \
		+ DataCellView.lying_over(PackDrawerView.CASSETTE_SCALE)
	return FLOOR_CLEAR + maxf(die_top, cell_top)

## Der Weg DURCH die Fläche - hinunter wie herauf.
static func sink_drop() -> float:
	return content_depth()

## Was EIN Stück braucht, um verdeckt zu sein - sein eigenes Maß, nicht das des
## höchsten. Eine flache Kassette, die aus der Tiefe eines Würfels käme, verbrächte
## ihre Fahrt unsichtbar und ploppte am Ende heraus.
static func cell_drop() -> float:
	return FLOOR_CLEAR + DataCellView.lying_under(PackDrawerView.CASSETTE_SCALE) \
		+ DataCellView.lying_over(PackDrawerView.CASSETTE_SCALE)

static func die_drop() -> float:
	return FLOOR_CLEAR + DieBuilder.HALF_EXTENT * DIE_SCALE * (1.0 + SILHOUETTE)

## Und dasselbe für einen konkreten Körper.
static func body_drop(body: Node3D) -> float:
	return cell_drop() if body is DataCellView else die_drop()

## Plätze EINER Reihe: count Punkte, mittig über span verteilt. Die Teilung ist
## fest (pitch), solange sie passt - sonst rückt die Reihe zusammen. Reine
## Funktion: die Auslage rechnet ihre Plätze, sie misst keine Körper.
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

## Die Zone eines Platzes: die offene Ware liegt in der Schale, alles Versiegelte
## im Regal.
static func zone_of(kind: String) -> int:
	return ZONE_BOWL if kind == ShopController.KIND_DIE else ZONE_SHELF

static func zone_of_key(key: String) -> int:
	return zone_of(key.get_slice(":", 0))

## Wann die Zone ANFÄHRT: nach der Ankündigung, um ihren Platz im Takt versetzt.
static func lift_delay(zone: int) -> float:
	return SEAM_LEAD + LIFT_LAG * float(maxi(zone, 0))

## Wie lange EIN Maschinenzyklus dauert: Senken, Einschub, Hub und Setz-Dip.
static func machine_time() -> float:
	return LiftShaftView.cycle_time()

## Wie tief der Schacht ist - das höchste Stück der Auslage plus Kopffreiheit. EIN
## Maß für alle Schächte: sie sollen gleich tief lesen, und die Ware sinkt überall
## um dieselbe Strecke.
static func shaft_depth() -> float:
	return content_depth() * SHAFT_ROOM

## Und wann sie TAUCHT - gespiegelt: die vorderste Zone geht zuerst.
static func sink_delay(zone: int) -> float:
	return ZONE_LAG * float(ZONE_COUNT - 1 - clampi(zone, 0, ZONE_COUNT - 1))

## Wie lange der Umschlag braucht, bis die Auslage leer ist: die letzte Zone taucht
## zuletzt. Die Zahl der Stücke sagt nur, OB überhaupt etwas geht - eine Zone fährt
## als Block, nicht Stück für Stück.
static func swap_time(count: int) -> float:
	if count <= 0:
		return 0.0
	return SWAP_TIME

## Wie lange ein Auftritt dauert - der ganze Maschinenzyklus: Ankündigung, der
## Versatz bis zur letzten Zone und deren Fahrt (Senken, Einschub, Hub, Setz-Dip).
## Liegenbleiben kostet nichts. Der EHRLICHE Deckel: keine Zone steht später als
## hier, und kein Schacht ist danach noch offen.
static func entry_time(count: int, grade: String) -> float:
	if count <= 0 or grade == ShopController.GRADE_STAND:
		return 0.0
	return lift_delay(ZONE_COUNT - 1) + machine_time()

func _init(vitrine_name := "Vitrine") -> void:
	name = vitrine_name
	visible = false  # zugedeckt heißt: gar nicht da

## Stellt die Auslage auf ihr gemeldetes Rechteck: Mitte auf der Tischebene, halbe
## Ausdehnung in Welt-X/Welt-Z. Idempotent - dieselben Maße stellen nichts um.
func setup(at: Vector3, half_extents: Vector2) -> void:
	var wanted := Vector2(maxf(half_extents.x, 0.01), maxf(half_extents.y, 0.01))
	var same := center.is_equal_approx(at) and half.is_equal_approx(wanted)
	center = at
	half = wanted
	if not same:
		_layout()

## Die Auslage zeigen oder abdecken. Zugedeckt ist von ihr KEIN Körper da: sie
## läge sonst auf der Anzeige einer fremden Seite - und kein Schacht bleibt offen,
## denn ein Loch ohne Maschine wäre der schlimmste Rest.
func set_shown(value: bool) -> void:
	if not value:
		settle()
	visible = value

## Die Tischebene: das BETT der ganzen Auslage. Alles Liegende ruht darauf.
func floor_y() -> float:
	return center.y

## Die Höhe der MITTE eines liegenden Körpers halber Höhe half_height: er RUHT mit
## seiner Unterkante auf der Fläche, eine Haaresbreite darüber.
func lie_y(half_height: float) -> float:
	return floor_y() + FLOOR_CLEAR + half_height

## Der Platz einer liegenden Kassette: dieselbe Auflage, nur um das gehoben, was
## ihre Kontaktfinnen unter ihren Ursprung ragen lassen.
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

## Der Umschlag: jede Zone taucht als BLOCK durch die Fläche, in gespiegelter
## Reihenfolge (die Schale zuerst). Danach ist die Auslage LEER - was sinkt, ist
## nicht mehr zu greifen. Liefert die Dauer, nach der die Zielseite kommen darf.
func sink_all() -> float:
	settle()
	_settle_token += 1  # eine laufende Frist gilt nicht mehr
	_mark_bowl(false)
	var keys := _bodies.keys()
	for i in keys.size():
		_sink_away(_bodies[keys[i]], sink_delay(zone_of_key(String(keys[i]))))
	_bodies.clear()
	_rest_scale.clear()
	_hover_tweens.clear()
	_hover_head.clear()
	_move_tweens.clear()
	items.clear()
	_hovered = ""
	return swap_time(keys.size())

## Alles, was gerade fährt, liegt sofort hart auf seinem Platz, und jede Maschine
## steht still: Platte bündig, Schacht fort, Loch zu. Ein Laufwechsel oder eine
## neue Auslage mitten im Auftritt darf nichts schuldig lassen - der EINE
## Aufräum-Pfad, den alle Abbrüche teilen.
func settle() -> void:
	close_shafts()
	for key: String in _move_tweens.keys():
		_kill(_move_tweens[key])
		var body: Node3D = _bodies.get(key)
		if body == null or not is_instance_valid(body):
			continue
		var spot := _spot_for_key(key)
		var cell := body as DataCellView
		if cell != null:
			cell.lie_on_glass(spot)
			continue
		body.global_position = _rest_position(key, spot)
	_move_tweens.clear()

## Laufwechsel: die Auslage ist leer, ihr Raum bleibt stehen.
func clear() -> void:
	stock = {}
	settle()
	_settle_token += 1
	_mark_bowl(false)
	for key: String in _bodies.keys():
		_free_body(_bodies[key])
	_bodies.clear()
	_rest_scale.clear()
	_hover_tweens.clear()
	_hover_head.clear()
	_move_tweens.clear()
	items.clear()
	_hovered = ""

# --- Der Griff -----------------------------------------------------------------

## Das Stück über diesem WELT-Punkt der Tischebene ({} = keins). Gefragt, nicht
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

## Der Ankerpunkt eines Stücks in der Tischebene (die Beschriftung hängt darüber).
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

## Steht die Schale? Solange sie fährt, hängt keine Beschriftung unter ihr.
func bowl_settled() -> bool:
	return _bowl_settled

## Der Auftritt braucht so lange - danach steht die Schale. 0 heißt: sie steht
## schon. Ein zweiter Ruf entwertet den ersten (Marke), so kann ein Umschlag
## mitten im Auftritt nichts vorzeitig für gestanden erklären.
func _settle_after(delay: float) -> void:
	_settle_token += 1
	if delay <= 0.0:
		_mark_bowl(true)
		return
	_mark_bowl(false)
	var token := _settle_token
	var tree := get_tree()
	if tree == null:
		_mark_bowl(true)  # ohne Baum gibt es keine Bewegung
		return
	await tree.create_timer(delay).timeout
	if token == _settle_token:
		_mark_bowl(true)

func _mark_bowl(settled: bool) -> void:
	if settled == _bowl_settled:
		return
	_bowl_settled = settled
	if settled:
		dice_settled.emit()
	else:
		dice_moving.emit()

# --- Aufbau ---------------------------------------------------------------------

## Der eine Schreiber: Plätze rechnen, Körper nachstellen, Verkauftes versenken.
## Der Grad entscheidet allein, WIE die Körper auf ihre fertigen Plätze kommen.
func _layout(grade := ShopController.GRADE_STAND) -> void:
	settle()  # eine laufende Fahrt endet hier, nicht irgendwann
	items.clear()
	if half.x <= 0.0 or half.y <= 0.0:
		return
	var wanted: Dictionary = {}
	var stage: Dictionary = {}  # Zone -> die Stücke, die sie als Block fährt
	_lay_shelf(wanted, grade, stage)
	_lay_bowl(wanted, grade, stage)
	# Die Netze der Ladenseite folgen nur STEHENDER Ware: gemessen wird der Deckel
	# des Auftritts.
	_settle_after(entry_time(items.size(), grade))
	for zone: int in stage.keys():
		_run_machine(zone, stage[zone])
	for key: String in _bodies.keys():
		if not wanted.has(key):
			_sink_out(_bodies[key], float(_hover_head.get(key, 0.0)))
			_bodies.erase(key)
			_rest_scale.erase(key)
			_move_tweens.erase(key)
			_hover_tweens.erase(key)
			_hover_head.erase(key)
			if _hovered == key:
				_hovered = ""

## Hinten das Regal: jede versiegelte Kassette LIEGT auf ihrem Platz, große Fläche
## nach oben - Sortenfarbe, Zeichen und Größen-Streifen liest man von dort.
func _lay_shelf(wanted: Dictionary, grade: String, stage: Dictionary) -> void:
	var entries: Array[Dictionary] = []
	var row: Array = stock.get(ShopController.KIND_ENGRAVING_PACK, [])
	for i in row.size():
		entries.append({"kind": ShopController.KIND_ENGRAVING_PACK, "index": i, "pack": row[i]})
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
		# Von oben gelesen: die Zahl liegt AUF der Karte, nicht neben ihr.
		cell.badge_on_face = true
		cell.set_count(maxi(pack.count, 1))
		cell.set_body_scale(PackDrawerView.CASSETTE_SCALE)
		cell.hover_lift = DataCellView.HOVER_LIFT
		_hover_head[key] = DataCellView.HEIGHT * cell.body_scale() * cell.hover_lift
		cell.lie_on_glass(spot)
		items.append({"kind": entry["kind"], "index": entry["index"], "key": key, "spot": spot,
			"node": cell, "cell": cell, "radius": radius})
		_stage(key, cell, spot, grade, ZONE_SHELF, stage)

## Vorn die Schale: die offene Ware, die man vor dem Kauf SIEHT - echte Würfel.
func _lay_bowl(wanted: Dictionary, grade: String, stage: Dictionary) -> void:
	var entries: Array[Dictionary] = []
	var dice: Array = stock.get(ShopController.KIND_DIE, [])
	for i in dice.size():
		entries.append({"kind": ShopController.KIND_DIE, "index": i, "value": dice[i]})
	# Die Schale VERTEILT sich über die ganze Auslagebreite, statt sich an einer
	# Wunschteilung zu drängen: unter jedem Würfel steht sein Netz, und das
	# braucht die Breite. row_spots deckelt ohnehin auf span/count.
	var pitch := _field_width()
	var offsets := row_spots(entries.size(), _field_width(), pitch)
	var radius := pick_radius(bowl_reach() * PICK_FACTOR, offsets)
	var x := _band_depths().y
	for i in entries.size():
		var entry := entries[i]
		if entry["value"] == null:
			continue  # verkauft: der Platz bleibt leer
		var lift := DieBuilder.HALF_EXTENT * DIE_SCALE
		var spot := Vector3(x, lie_y(lift), _field_center_z() + offsets[i])
		var key := slot_key(entry["kind"], entry["index"])
		wanted[key] = true
		var body: Node3D = _bodies.get(key)
		if body == null or not is_instance_valid(body):
			body = _spawn_die(entry["value"])
			add_child(body)
			_bodies[key] = body
			_rest_scale[key] = DIE_SCALE
		_hover_head[key] = HOVER_LIFT
		_seat(key, body, spot)
		items.append({"kind": entry["kind"], "index": entry["index"], "key": key, "spot": spot,
			"node": body, "cell": null, "radius": radius})
		_stage(key, body, spot, grade, ZONE_BOWL, stage)

## Wie weit eine liegende Kassette bzw. das höchste Stück der Schale von seiner
## Mitte aus nach vorn und hinten reicht - daran messen sich die beiden Bänder.
static func shelf_reach() -> float:
	return DataCellView.HEIGHT * PackDrawerView.CASSETTE_SCALE * 0.5

static func bowl_reach() -> float:
	return DieBuilder.HALF_EXTENT * DIE_SCALE * SILHOUETTE

## Wie viele REGAL-Plätze diese Auslage führt (leere eingeschlossen). Gezählt wird
## am Platz, nicht am Inhalt: ein verkauftes Regal darf die Bänder nicht
## verrücken, sonst rutschte die Schale mitten im Besuch nach hinten.
func _shelf_slots() -> int:
	var row: Array = stock.get(ShopController.KIND_ENGRAVING_PACK, [])
	return row.size()

## Die Tiefenmitten der beiden Bänder (x = Regal, y = Schale). Normalerweise stehen
## sie auf ihren Anteilen; liegend ist eine Kassette aber länger als ihr Band in
## einer engen Auslage (das Hinterzimmer), und dann rücken beide auf Anschlag an
## ihre Kanten und teilen sich die Tiefe nach ihren wirklichen Längen.
func _band_depths() -> Vector2:
	var margin := half.x * 2.0 * EDGE_MARGIN
	var back := center.x + half.x - margin
	var front := center.x - half.x + margin
	# Ohne Regal gehört die Tiefe der Schale allein, und der BLOCK aus Würfel und
	# seiner Beschriftung steht mittig darin: was die Beschriftung nicht braucht,
	# liegt zu gleichen Teilen vor und hinter ihm.
	if _shelf_slots() <= 0:
		# Der Block reicht von der Silhouette HINTER dem Würfel bis ans Ende der
		# Beschriftung davor - vor ihm liegt nur, was die Reserve nennt.
		var lead := maxf((back - front - bowl_reach() - label_reserve) * 0.5, 0.0)
		return Vector2(back, back - lead - bowl_reach())
	var shelf := minf(_depth_at(0.0, SHELF_DEPTH_SHARE), back - shelf_reach())
	var bowl := maxf(_depth_at(SHELF_DEPTH_SHARE, 1.0), front + bowl_reach())
	var need := shelf_reach() + bowl_reach()
	if shelf - bowl >= need:
		return Vector2(shelf, bowl)
	if need > back - front:
		var squeeze := (back - front) / need
		return Vector2(back - shelf_reach() * squeeze, front + bowl_reach() * squeeze)
	return Vector2(back - shelf_reach(), front + bowl_reach())

## Tiefenmitte eines Bandes (0 = hintere Kante, 1 = vordere), Rand abgezogen.
## HINTEN ist Welt-+X: world_to_pixel spiegelt die Tiefenachse (v = x_max - x),
## der Bildschirm-oben liegt also am GRÖSSEREN x.
func _depth_at(share_start: float, share_end: float) -> float:
	var margin := half.x * 2.0 * EDGE_MARGIN
	var usable := maxf(half.x * 2.0 - margin * 2.0, 0.01)
	return center.x + half.x - margin - usable * (share_start + share_end) * 0.5

## Nutzbare Breite der Auslage: die ganze Fläche ohne ihren Rand.
func _field_width() -> float:
	return maxf(half.y * 2.0 * (1.0 - EDGE_MARGIN * 2.0), 0.01)

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

## Ein Würfel der Auslage liegt auf der Anzeige: seine Boden-Lache hinge als
## Lichtfleck darauf statt unter ihm.
func _spawn_die(def: DieDefinition) -> Node3D:
	var die := FloatingDie.build_ghost(def)
	var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	faces.set_pool_enabled(false)
	return die

## Welche Seite ein Würfel der Auslage oben zeigt - die Ruhelage des Tray-Ghosts,
## nur um die Hochachse gedreht.
static func die_up_face() -> int:
	return DiceController.AXIS_FACE_INDEX["OBEN"]

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

## Der AUFTRITT eines Stücks. Sein Platz steht schon hart - hier wird es nur in
## seine ZONE eingereiht: die fährt danach als EIN Block, denn eine Hebebühne hebt
## keine Einzelstücke.
func _stage(key: String, body: Node3D, spot: Vector3, grade: String, zone: int,
		stage: Dictionary) -> void:
	if grade == ShopController.GRADE_STAND or body == null or not is_instance_valid(body):
		return
	_kill(_move_tweens.get(key))
	_kill(_hover_tweens.get(key))
	if not (body is DataCellView):
		body.scale = Vector3.ONE * float(_rest_scale.get(key, 1.0))
	# Gemerkt wird nur, DASS es unterwegs ist - settle legt es hart auf seinen Platz.
	_move_tweens[key] = null
	if not stage.has(zone):
		stage[zone] = []
	(stage[zone] as Array).append({"key": key, "body": body, "spot": spot})

# --- Die HEBEBÜHNE --------------------------------------------------------------
# Der Auftritt ist eine echte Maschine, nicht ein Durchscheinen: das Loch geht auf,
# die BÜNDIGE leere Plattform senkt sich, die Ware schiebt VON HINTEN durch die
# Rückwandöffnung auf sie, dann fahren Platte und Ware GEMEINSAM herauf und das
# Loch schließt sich. EIN Tween je Zone trägt alles - zwei liefen auseinander, und
# die Ware steht auf der Platte.

## Der Zyklus EINER Zone. Der Endzustand steht längst (die Stücke sind hart
## gesetzt); hier bekommen sie nur ihren Weg - und der ist die Maschine.
func _run_machine(zone: int, entries: Array) -> void:
	if entries.is_empty():
		return
	var shaft := _shaft_for(zone)
	if shaft == null:
		return
	var bodies: Array = []
	var seats: Array = []
	var cells: Array = []
	for entry: Dictionary in entries:
		bodies.append(entry["body"])
		seats.append(_rest_position(String(entry["key"]), entry["spot"]))
		var cell := entry["body"] as DataCellView
		if cell != null:
			cells.append(cell)
	var tween := shaft.run_cycle(bodies, seats, lift_delay(zone))
	if tween == null:
		return
	_zone_tweens[zone] = tween
	# Erst oben lodert die Kassette: ein Ausbruch im Schacht sähe niemand.
	tween.tween_callback(func() -> void:
		for cell: DataCellView in cells:
			if is_instance_valid(cell):
				cell.flare())

## Der Schacht einer Zone: seine Spur ist die Reihe, seine Tiefe die des höchsten
## Stücks. Er bleibt IM Buchtenrechteck - ein Loch daneben fräße die Seite an.
func _shaft_for(zone: int) -> LiftShaftView:
	var bands := _band_depths()
	var depth_x := bands.x if zone == ZONE_SHELF else bands.y
	var reach := shelf_reach() if zone == ZONE_SHELF else bowl_reach()
	var margin := reach * SHAFT_MARGIN_SHARE
	var back := minf(depth_x + reach + margin, center.x + half.x)
	var front := maxf(depth_x - reach - margin, center.x - half.x)
	if back - front <= 0.0:
		return null
	var span := minf(_field_width() * 0.5 + margin, half.y)
	var shaft: LiftShaftView = _shafts.get(zone)
	if shaft == null or not is_instance_valid(shaft):
		shaft = LiftShaftView.new("LiftShaft%d" % zone)
		add_child(shaft)
		_shafts[zone] = shaft
		# Das Loch meldet die Auslage weiter - geschnitten wird es ganz woanders.
		shaft.opened.connect(func(at: Vector3, hole: Vector2) -> void:
			shaft_opened.emit(zone, at, hole))
		shaft.closed.connect(func() -> void: shaft_closed.emit(zone))
	shaft.deck_color = deck_tint
	shaft.setup(Vector3((back + front) * 0.5, center.y, _field_center_z()),
		Vector2((back - front) * 0.5, span), shaft_depth())
	return shaft

## Jede Maschine steht still, jedes Loch ist zu. Der eine Weg, den settle, ein
## Vorhangfall und ein Laufwechsel gemeinsam gehen.
func close_shafts() -> void:
	_zone_tweens.clear()
	for zone: int in _shafts.keys():
		var shaft: LiftShaftView = _shafts[zone]
		if shaft != null and is_instance_valid(shaft):
			shaft.settle_hard()

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

## Wie lange ein übergebenes Stück braucht, bis es unter der Tischfläche ist -
## erst dann fährt die Lieferung (scene_root richtet ihren Abflug danach).
static func take_out_time() -> float:
	return TAKE_LIFT_TIME + TAKE_SINK_TIME

## Verkauft: der Körper hebt sich kurz an - die Übergabe - und sinkt dann durch
## die Fläche, wo ihn das Display-Mesh verdeckt.
func _sink_out(body: Node3D, lift: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var cell := body as DataCellView
	if cell != null:
		cell.set_hovered(false)
	var tween := create_tween()
	tween.tween_property(body, "global_position",
		body.global_position + Vector3.UP * lift, TAKE_LIFT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "global_position",
		body.global_position - Vector3.UP * (sink_drop() + DataCellView.HEIGHT),
		TAKE_SINK_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(_free_body.bind(body))

## Umschlag: die Zone taucht als Block weg - linear wie die Fahrt herauf. Kein
## Anheben: beim Blättern wird nichts übergeben, die Seite wird gewechselt.
func _sink_away(body: Node3D, delay: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var cell := body as DataCellView
	if cell != null:
		cell.set_hovered(false)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	# Sein EIGENES Maß: der Weg endet, wo der Körper verdeckt ist - nicht tiefer.
	tween.tween_property(body, "global_position",
		body.global_position - Vector3.UP * body_drop(body), SWAP_SINK) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(_free_body.bind(body))

func _free_body(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.get_parent() == self:
		remove_child(body)
	body.queue_free()
