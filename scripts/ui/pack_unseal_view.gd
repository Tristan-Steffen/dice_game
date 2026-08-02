class_name PackUnsealView
extends Control
## Die Entsiegelung in drei Schlägen: das Siegel zittert und ZERBRICHT, der Inhalt
## springt als Zeichen in einen Kreis darum und HÄLT dort kurz an - das ist die
## Vorstellungsrunde -, dann wird jedes Stück zum Meteor und fliegt in seine
## Schublade (die Flugbahn baut TableScreen).
##
## Vor dem Bruch steht bewusst NICHTS auf dem Tisch: In diesem Spiel IST das
## Zeichen das Stück, es verriete den Inhalt, bevor er überhaupt unterwegs ist.
## Nach dem Bruch darf es das - da ist die Frage schon beantwortet.
##
## Die Zeremonie BUCHT nichts: sie meldet nur (chip_resolved / finished), die
## Werkstatt verbucht.

## Ein Stück verlässt seinen Platz im Kreis (Position in Fenster-Pixeln, von dort
## startet sein Meteor; Seltenheit für dessen Farbe).
signal chip_resolved(engraving_id: String, from_px: Vector2, rarity: int)
## Ein Würfel-Zeichen steht auf dem Platz, an dem der Würfel gleich schwebt, und
## wird dort körperlich - die Werkstatt lässt ihn erscheinen.
signal die_revealed(index: int)
## Die Zeremonie ist durch - die Werkstatt räumt bzw. geht zum Einsetzen über.
signal finished

## Zittern vor dem Bruch. FEST für jedes Paket - die Dauer darf nichts über den
## Inhalt verraten.
const CRACK_TIME := 0.25
## Flug der Zeichen aus dem Siegel auf ihre Plätze im Kreis.
const EJECT_TRAVEL := 0.15
## Vorstellungsrunde: so lange steht der Inhalt still und lässt sich ansehen.
const PAUSE := 0.5
## Abstand zwischen zwei abfliegenden Stücken.
const STAGGER := 0.12
## Zusätzliches Stocken vor einem Stück, das seltener ist als alles bisherige.
const HITCH := 0.15
## Nachlauf nach dem letzten Stück - die Meteore fliegen danach allein weiter.
const HOLD := 0.2
## Aus dem Zeichen wird der Körper: so lange dauert das Aufplustern-und-Verlöschen
## eines Würfel-Zeichens, während der echte Würfel an seiner Stelle erscheint.
const TRANSFORM_TIME := 0.18

enum State { CRACK, PRESENT, DEPART, DONE }

var _state: State = State.CRACK
var _elapsed := 0.0
var _unit := 6.0
var _accent := Color.WHITE
var _seal: PackIconRenderer
var _seal_home := Vector2.ZERO
## Der Inhalt: {"id": String, "rarity": int, "node": Control}. Das Zeichen steht
## erst ab dem Bruch auf dem Tisch (siehe _present).
var _pieces: Array[Dictionary] = []
## Würfel-Paket: die Zeichen fliegen NICHT in den Kreis, sondern gleich auf die
## Plätze, an denen die echten Würfel schweben werden - dort werden sie zu ihnen.
## So liegt kein Würfel je auf einem anderen.
var _dice_mode := false
## Woher die Plätze kommen (Fenster-Pixel, ein Punkt je Würfel). GEFRAGT statt
## mitgegeben: beim Aufbau der Zeremonie ist das Fenster noch nicht ausgelegt,
## seine Bühnen haben also noch kein Rechteck.
var die_target_source: Callable
## Ausflug-Reihenfolge (aufsteigend nach Seltenheit).
var _order: Array[int] = []
## Ausflug-Zeitpunkt je Eintrag in _order, ab Zeremonie-Start.
var _beat_times: Array[float] = []
var _next_piece := 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # Klick überspringt
	clip_contents = true

## Baut die Zeremonie für den ausgewürfelten Inhalt auf. Gravur- und Würfel-Pakete
## teilen sich den Ablauf; Würfel fliegen in keine Schublade (leere id).
func setup(pack_type: String, engravings: Array[Engraving], dice: Array[DieDefinition], u: float) -> void:
	_unit = maxf(u, 1.0)
	_accent = PackIconRenderer.COLORS.get(pack_type, Color.WHITE)

	_seal = PackIconRenderer.for_type(pack_type)
	add_child(_seal)

	if not engravings.is_empty():
		for engraving in engravings:
			var face := EngravingRenderer.for_engraving(engraving)
			face.ignite = 0.0   # das Zeichen zieht sich erst im Flug nach draußen
			_add_piece(face, engraving.id, int(engraving.rarity))
	else:
		# Würfel haben keine Seltenheit - ihre Veredelung ist sie (siehe _dice_rarity).
		_dice_mode = true
		var rarity := _dice_rarity(dice)
		for die in dice:
			_add_piece(PackIconRenderer.for_type(Pack.TYPE_DICE), "", rarity)

	_order = _eject_order()
	_beat_times = _schedule()
	_layout()
	resized.connect(_layout)
	set_process(true)

## Das Zeichen wartet unsichtbar: vor dem Bruch darf nichts von ihm zu sehen sein.
func _add_piece(node: Control, id: String, rarity: int) -> void:
	node.visible = false
	add_child(node)
	_pieces.append({"id": id, "rarity": rarity, "node": node})

## Aufsteigend nach Seltenheit - das seltenste Stück fliegt zuletzt.
func _eject_order() -> Array[int]:
	var order: Array[int] = []
	for i in _pieces.size():
		order.append(i)
	order.sort_custom(func(a, b): return int(_pieces[a]["rarity"]) < int(_pieces[b]["rarity"]))
	return order

## Ausflug-Zeitpunkte: Grundtakt, plus ein Stocken vor jedem neuen Bestwert - das
## Zögern vor dem Guten ist der Herzschlag der Zeremonie.
func _schedule() -> Array[float]:
	var times: Array[float] = []
	# Erst nach Flug UND Vorstellungsrunde geht das erste Stück auf die Reise.
	var t := CRACK_TIME + EJECT_TRAVEL + PAUSE
	var best := -1
	for i in _order.size():
		var rarity := int(_pieces[_order[i]]["rarity"])
		if i > 0:
			t += STAGGER
			if rarity > best:
				t += HITCH
		best = maxi(best, rarity)
		times.append(t)
	return times

## Würfel haben keine Seltenheit - die Veredelung ist ihre: eine Essenz zählt
## als selten, eine Material-Seite als ungewöhnlich, ein blanker Würfel als
## gewöhnlich.
func _dice_rarity(dice: Array[DieDefinition]) -> int:
	var best := int(Engraving.Rarity.COMMON)
	for die in dice:
		if die == null:
			continue
		if die.essence_id != "":
			best = maxi(best, int(Engraving.Rarity.RARE))
		elif die.materials.count("") < die.materials.size():
			best = maxi(best, int(Engraving.Rarity.UNCOMMON))
	return best

## Siegel mittig, die Zeichen auf einem Kreis darum. Von Hand gesetzt: ein
## Container meldete sein Mindestmaß ans Werkstatt-Fenster zurück.
func _layout() -> void:
	if _seal == null or not is_instance_valid(_seal):
		return
	_seal.size = Vector2.ONE * _unit * 11.0
	_seal_home = size * 0.5 - _seal.size * 0.5
	_seal.position = _seal_home

	var side := _unit * 6.5
	for i in _pieces.size():
		var node: Control = _pieces[i]["node"]
		if not is_instance_valid(node):
			continue
		node.size = Vector2.ONE * side
		# Vor dem Bruch sitzt alles im Siegel; danach hält der Kreis die Plätze.
		node.position = (_piece_point(i) if _state != State.CRACK else _seal_center()) - node.size * 0.5

## Mitte des Siegels - dort brechen die Zeichen heraus.
func _seal_center() -> Vector2:
	return size * 0.5

func _ring_radius() -> float:
	# Eng genug, dass Siegel und Inhalt EIN Ding bleiben, weit genug, dass die
	# Zeichen einander nicht überlagern.
	var room := minf(size.x, size.y) * 0.5 - _unit * 5.0
	return clampf(room, _unit * 12.0, _unit * 14.0)

## Platz eines Stücks im Kreis; erstes oben, dann im Uhrzeigersinn - ein einzelnes
## Stück steht damit über dem Siegel statt daneben.
func _ring_point(index: int) -> Vector2:
	var count := maxi(_pieces.size(), 1)
	var angle := TAU * float(index) / float(count) - TAU * 0.25
	return size * 0.5 + Vector2(cos(angle), sin(angle)) * _ring_radius()

## Der Platz, auf den ein Stück fliegt: bei Würfeln der Ort, an dem der echte
## Würfel gleich schwebt, sonst sein Platz im Kreis. Der Kreis ist der Rückfall,
## solange das Fenster noch kein Maß hat.
func _piece_point(index: int) -> Vector2:
	if not _dice_mode or not die_target_source.is_valid():
		return _ring_point(index)
	var targets: Array = die_target_source.call()
	if index >= targets.size():
		return _ring_point(index)
	var target: Vector2 = targets[index] - global_position
	return target if target != Vector2.ZERO else _ring_point(index)

# --- Ablauf ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	# Kein match: ein einzelner Aufruf darf mehrere Schläge überspringen (großes
	# delta, Tests), sonst verschenkte jeder Zustandswechsel ein Bild.
	if _state == State.CRACK:
		_animate_crack()
		if _elapsed >= CRACK_TIME:
			_present()
	if _state == State.PRESENT and _elapsed >= CRACK_TIME + EJECT_TRAVEL + PAUSE:
		_state = State.DEPART
	if _state == State.DEPART:
		while _next_piece < _order.size() and _elapsed >= _beat_times[_next_piece]:
			_depart(_order[_next_piece])
			_next_piece += 1
		if _next_piece >= _order.size() and _elapsed >= _last_beat() + HOLD:
			_state = State.DONE
			set_process(false)
			finished.emit()

func _last_beat() -> float:
	if _beat_times.is_empty():
		return CRACK_TIME
	return _beat_times[_beat_times.size() - 1]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		finish_now()

## Überspringt die Zeremonie: alles fliegt sofort los. Kein Stück geht dabei
## verloren - Ungeduld kostet nur die Vorführung.
func finish_now() -> void:
	if _state == State.DONE:
		return
	if _state == State.CRACK:
		_present()
	_state = State.DEPART
	while _next_piece < _order.size():
		_depart(_order[_next_piece])
		_next_piece += 1
	_state = State.DONE
	set_process(false)
	queue_redraw()
	finished.emit()

## Anspannung: das Siegel zittert zunehmend - zwei unrunde Frequenzen, damit es
## nicht wie ein Pendel schwingt.
func _animate_crack() -> void:
	if _seal == null or not is_instance_valid(_seal):
		return
	var p := clampf(_elapsed / CRACK_TIME, 0.0, 1.0)
	var shake := _unit * 0.5 * p
	_seal.position = _seal_home + Vector2(
		sin(_elapsed * 97.0) * shake, cos(_elapsed * 71.0) * shake)
	var glow := 1.0 + 1.6 * p * p
	_seal.modulate = Color(glow, glow, glow)

## Der Bruch und die Vorstellungsrunde: das Siegel reißt auf, und was darin lag,
## springt als Zeichen in den Kreis und bleibt dort einen Moment stehen.
func _present() -> void:
	_state = State.PRESENT
	if _seal != null and is_instance_valid(_seal):
		_seal.position = _seal_home
		_seal.pivot_offset = _seal.size * 0.5
		var burst := create_tween()
		burst.set_parallel(true)
		burst.tween_property(_seal, "scale", Vector2.ONE * 1.7, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		burst.tween_property(_seal, "modulate:a", 0.0, 0.16)
	for i in _pieces.size():
		_fly_out(i)

## Ein Zeichen springt aus dem Siegel auf seinen Platz und zieht sich dabei nach -
## wie eine Zündschnur, statt fertig dazustehen.
func _fly_out(index: int) -> void:
	var node: Control = _pieces[index]["node"]
	if not is_instance_valid(node):
		return
	node.position = _seal_center() - node.size * 0.5
	node.visible = true
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "position", _piece_point(index) - node.size * 0.5, EJECT_TRAVEL) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if node is EngravingRenderer:
		var face: EngravingRenderer = node
		tween.tween_property(face, "ignite", 1.0, EJECT_TRAVEL)
		face.set_process(face.rarity >= Engraving.Rarity.RARE)  # Seltenes atmet

## Ein Stück verlässt den Kreis: das Zeichen schnappt weg, und von seinem Platz
## startet der Meteor. Ein WÜRFEL-Zeichen fliegt nirgendwohin - es steht schon am
## Platz seines Würfels und wird dort zu ihm: es pluster kurz auf und verlischt,
## während der echte Würfel an derselben Stelle ins Feld kommt.
func _depart(index: int) -> void:
	if index < 0 or index >= _pieces.size():
		return
	var piece := _pieces[index]
	var node: Control = piece["node"]
	var from := _piece_point(index)
	if is_instance_valid(node):
		node.pivot_offset = node.size * 0.5
		var tween := node.create_tween()
		if _dice_mode:
			tween.set_parallel(true)
			tween.tween_property(node, "scale", Vector2.ONE * 1.35, TRANSFORM_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(node, "modulate:a", 0.0, TRANSFORM_TIME)
			tween.chain().tween_callback(node.hide)
		else:
			tween.tween_property(node, "scale", Vector2.ONE * 0.2, 0.1) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(node.hide)
	if _dice_mode:
		die_revealed.emit(index)
		return
	chip_resolved.emit(String(piece["id"]), from, int(piece["rarity"]))

## Der Schein um das Siegel, kurz bevor es nachgibt.
func _draw() -> void:
	if _state != State.CRACK:
		return
	var p := clampf(_elapsed / CRACK_TIME, 0.0, 1.0)
	var radius := _unit * (5.0 + 3.0 * p)
	draw_circle(size * 0.5, radius, Color(_accent.r, _accent.g, _accent.b, 0.06 + 0.16 * p * p))

# --- Auskunft (Tests, Ablauf-Planung) --------------------------------------------

## Höchste Seltenheit im Paket.
func tier() -> int:
	var best := 0
	for piece in _pieces:
		best = maxi(best, int(piece["rarity"]))
	return best

## Ausflug-Zeitpunkte in Ausflug-Reihenfolge.
func beat_times() -> Array[float]:
	return _beat_times

## Gesamtdauer der Vorführung (ohne die Flugzeit der Meteore).
func total_time() -> float:
	return _last_beat() + HOLD

func is_done() -> bool:
	return _state == State.DONE
