class_name StampNet
extends Resource
## Das PRÄGENETZ einer Kassette: sechs Zellen, eine je Würfelseite. Es wird bei
## der ERZEUGUNG gewürfelt, steht ab da fest und liegt im Laden offen - der Zufall
## lebt im Nachschub, nicht mehr an der Presse. Jede Zelle trägt GENAU EINES:
## Zahl-Bonus, Material, Rune, Operator, Veredelung oder Pointer.
##
## Hier stehen nur Daten und der Wurf. Wie sich mehrere Netze zu einer Serie
## verrechnen, weiß allein der SeriesResolver.

const FACES := 6

## Zell-Sorten - "kind" entscheidet, welche weiteren Felder eine Zelle trägt.
const KIND_VALUE := "value"        # {"value": int}
const KIND_MATERIAL := "material"  # {"id": DieMaterial-id}
const KIND_RUNE := "rune"          # {"id": Rune-id}
const KIND_OPERATOR := "operator"  # {"id": OP_*}
const KIND_DOPE := "dope"          # sättigt das Material dieser Seite
const KIND_POINTER := "pointer"    # {"to": Nachbarseite}

## --- Die OPERATOREN ------------------------------------------------------------
## Sonderbestand: genau eine Operator-Zelle je Karte. Sie rechnen ausschließlich im
## ZAHL-Kanal und auf der bis dahin AUFGELAUFENEN Summe - darum entscheidet die
## Position in der Serie über ihre Macht.

const OP_DOUBLER := "doubler"
const OP_MIRROR := "mirror"
const OP_COLLECTOR := "collector"

const OPERATOR_IDS := [OP_DOUBLER, OP_MIRROR, OP_COLLECTOR]

const OPERATORS := {
	OP_DOUBLER: {"name": "Verdoppler", "glyph": "×2", "price": 16,
		"effect": "Verdoppelt die aufgelaufene Summe dieser Seite"},
	OP_MIRROR: {"name": "Spiegel", "glyph": "⇄", "price": 14,
		"effect": "Kopiert die Summe dieser Seite auf die Gegenseite"},
	OP_COLLECTOR: {"name": "Sammler", "glyph": "◉", "price": 18,
		"effect": "Zieht die Summen aller Seiten auf diese eine"},
}

static func operator_name(op_id: String) -> String:
	return String(Dictionary(OPERATORS.get(op_id, {})).get("name", ""))

static func operator_effect(op_id: String) -> String:
	return String(Dictionary(OPERATORS.get(op_id, {})).get("effect", ""))

static func operator_glyph(op_id: String) -> String:
	return String(Dictionary(OPERATORS.get(op_id, {})).get("glyph", ""))

static func operator_price(op_id: String) -> int:
	return int(Dictionary(OPERATORS.get(op_id, {})).get("price", 0))

static func is_operator_id(op_id: String) -> bool:
	return OPERATORS.has(op_id)

## --- Die WURFTABELLEN ----------------------------------------------------------
## Alle Tabellen sind nach Paketgröße indiziert (0 Standard, 1 Groß, 2 Kolossal);
## sie stehen bewusst beieinander, damit Balancing eine Zahlenänderung bleibt.

## Zahlen: wie viele Zellen gefüllt werden [min, max] und wie hoch jede fällt.
const NUMBER_CELLS := [[1, 2], [3, 4], [5, 6]]
const NUMBER_VALUES := [[1, 2], [1, 3], [2, 5]]
## Statt Streuung würfelt Groß/Kolossal mit dieser Chance ein MUSTER.
const PATTERN_CHANCE := [0.0, 0.35, 0.35]
## Die beiden Muster der Größe Groß: alle sechs Zellen +1, oder eine Seite +5.
const PATTERN_ALL_VALUE := 1
const PATTERN_SPIKE_VALUE := 5
## Das Muster der Größe Kolossal: EINE Jackpot-Zelle in dieser Spanne.
const JACKPOT_RANGE := [10, 25]

## Material: so viele Chip-Zellen [min, max].
const MATERIAL_CELLS := [[1, 1], [2, 3], [4, 6]]
## Kolossal gießt mit dieser Chance stattdessen den GANZEN Würfel in EIN Material.
const MATERIAL_MONOLITH_CHANCE := [0.0, 0.0, 0.3]

## Runen: eine, zwei, drei.
const RUNE_CELLS := [[1, 1], [2, 2], [3, 3]]

## --- Zellen --------------------------------------------------------------------

static func empty_net() -> Array:
	var net: Array = []
	for i in FACES:
		net.append({})
	return net

static func value_cell(amount: int) -> Dictionary:
	return {"kind": KIND_VALUE, "value": amount}

static func material_cell(material_id: String) -> Dictionary:
	return {"kind": KIND_MATERIAL, "id": material_id}

static func rune_cell(rune_id: String) -> Dictionary:
	return {"kind": KIND_RUNE, "id": rune_id}

static func operator_cell(op_id: String) -> Dictionary:
	return {"kind": KIND_OPERATOR, "id": op_id}

static func dope_cell() -> Dictionary:
	return {"kind": KIND_DOPE}

static func pointer_cell(to_face: int) -> Dictionary:
	return {"kind": KIND_POINTER, "to": to_face}

## Sorte einer Zelle ("" = leer).
static func kind_of(cell: Dictionary) -> String:
	return String(cell.get("kind", ""))

static func is_filled(cell: Dictionary) -> bool:
	return kind_of(cell) != ""

## Zelle einer Seite - immer ein Dictionary, auch außerhalb des Netzes.
static func cell_at(net: Array, face: int) -> Dictionary:
	if face < 0 or face >= net.size():
		return {}
	var cell = net[face]
	return cell if cell is Dictionary else {}

static func filled_count(net: Array) -> int:
	var count := 0
	for face in FACES:
		if is_filled(cell_at(net, face)):
			count += 1
	return count

## Trägt das Netz überhaupt etwas? Katalysatoren tragen keins.
static func is_blank(net: Array) -> bool:
	return filled_count(net) == 0

## --- Der WURF ------------------------------------------------------------------

## Frisches Netz einer Gravur-Kategorie und Paketgröße.
static func roll(category: String, tier: int, rng: RandomNumberGenerator = null) -> Array:
	match category:
		Engraving.CATEGORY_MATERIAL:
			return _roll_material(tier, rng)
		Engraving.CATEGORY_DICE:
			return _roll_rune(tier, rng)
	return _roll_number(tier, rng)

static func _roll_number(tier: int, rng: RandomNumberGenerator) -> Array:
	var net := empty_net()
	var step := _tier(tier)
	if _roll_float(rng) < float(PATTERN_CHANCE[step]):
		return _number_pattern(step, rng)
	var span: Array = NUMBER_CELLS[step]
	var values: Array = NUMBER_VALUES[step]
	for face in _pick_faces(_range(rng, int(span[0]), int(span[1])), rng):
		net[face] = value_cell(_range(rng, int(values[0]), int(values[1])))
	return net

## Die Muster: Groß deckt entweder alle sechs Seiten flach ab oder setzt EINE
## Spitze; Kolossal legt seine ganze Kraft in eine Jackpot-Zelle.
static func _number_pattern(step: int, rng: RandomNumberGenerator) -> Array:
	var net := empty_net()
	if step >= 2:
		net[_range(rng, 0, FACES - 1)] = value_cell(
			_range(rng, int(JACKPOT_RANGE[0]), int(JACKPOT_RANGE[1])))
		return net
	if _roll_float(rng) < 0.5:
		for face in FACES:
			net[face] = value_cell(PATTERN_ALL_VALUE)
		return net
	net[_range(rng, 0, FACES - 1)] = value_cell(PATTERN_SPIKE_VALUE)
	return net

static func _roll_material(tier: int, rng: RandomNumberGenerator) -> Array:
	var net := empty_net()
	var step := _tier(tier)
	if _roll_float(rng) < float(MATERIAL_MONOLITH_CHANCE[step]):
		var monolith := _pick_material(rng)
		for face in FACES:
			net[face] = material_cell(monolith)
		return net
	var span: Array = MATERIAL_CELLS[step]
	for face in _pick_faces(_range(rng, int(span[0]), int(span[1])), rng):
		net[face] = material_cell(_pick_material(rng))
	return net

static func _roll_rune(tier: int, rng: RandomNumberGenerator) -> Array:
	var net := empty_net()
	var span: Array = RUNE_CELLS[_tier(tier)]
	for face in _pick_faces(_range(rng, int(span[0]), int(span[1])), rng):
		net[face] = rune_cell(_pick_rune(rng))
	return net

## Operator-Karte: genau EINE Zelle, auf einer gewürfelten Seite.
static func operator_net(op_id: String, rng: RandomNumberGenerator = null) -> Array:
	var net := empty_net()
	net[_range(rng, 0, FACES - 1)] = operator_cell(op_id)
	return net

## Netz eines FIXINHALTS: GENAU EINE Zelle auf einer gewürfelten Seite. Ein Bündel
## sind mehrere solcher Karten (Spieler-Entscheid 2026-09-11), nie mehr Zellen auf
## einer.
static func fixed_net(engraving: Engraving, rng: RandomNumberGenerator = null) -> Array:
	var net := empty_net()
	if engraving == null:
		return net
	var face := _range(rng, 0, FACES - 1)
	match engraving.id:
		Engraving.DOPING:
			net[face] = dope_cell()
		Engraving.POINTER:
			var neighbours := DieDefinition.adjacent_faces(face)
			net[face] = pointer_cell(neighbours[_range(rng, 0, neighbours.size() - 1)])
		_:
			var rune_id := Engraving.rune_id_of(engraving.id)
			if rune_id != "":
				net[face] = rune_cell(rune_id)
			elif engraving.material_id() != "":
				net[face] = material_cell(engraving.material_id())
	return net

## --- Anzeige -------------------------------------------------------------------

## Eine Zeile, die ein Netz zusammenfasst ("3 Zellen, +6 gesamt"). EINE Quelle für
## Regal, Magazin und Hinweis-Schirm.
static func line(net: Array) -> String:
	var cells := filled_count(net)
	if cells == 0:
		return "Kein Prägenetz"
	var op := ""
	var sum := 0
	for face in FACES:
		var cell := cell_at(net, face)
		match kind_of(cell):
			KIND_VALUE:
				sum += int(cell.get("value", 0))
			KIND_OPERATOR:
				op = operator_name(String(cell.get("id", "")))
	if op != "":
		return op
	if sum > 0:
		return "%d Zellen, +%d gesamt" % [cells, sum] if cells > 1 else "1 Zelle, +%d" % sum
	return "%d Zellen" % cells if cells > 1 else "1 Zelle"

## Was EINE Zelle tut, im Klartext ("" = leere Zelle). Die Quellen sind die
## bestehenden: das Material seine Seiten-Zeile, die Rune ihre, der Operator seine
## Wirkung - hier wird nichts zweitformuliert.
static func cell_hint(cell: Dictionary) -> String:
	match kind_of(cell):
		KIND_VALUE:
			return "Zahl: +%d auf diese Seite" % int(cell.get("value", 0))
		KIND_MATERIAL:
			return DieMaterial.face_hint(String(cell.get("id", "")))
		KIND_RUNE:
			return Rune.hint(String(cell.get("id", "")))
		KIND_OPERATOR:
			var op := String(cell.get("id", ""))
			return "%s: %s" % [operator_name(op), operator_effect(op)]
		KIND_DOPE:
			return "Veredelung: sättigt das Material dieser Seite"
		KIND_POINTER:
			return "Pointer: verdrahtet diese Seite auf Seite %d" % (int(cell.get("to", 0)) + 1)
	return ""

## --- Wurf-Werkzeug -------------------------------------------------------------

static func _tier(tier: int) -> int:
	return clampi(tier, 0, NUMBER_CELLS.size() - 1)

static func _roll_float(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()

static func _range(rng: RandomNumberGenerator, from: int, to: int) -> int:
	if to <= from:
		return from
	if rng != null:
		return rng.randi_range(from, to)
	return randi_range(from, to)

## count VERSCHIEDENE Seiten, gemischt - zwei Zellen auf derselben Seite gäbe es
## im Netz nicht, dort steht je Seite genau eine.
static func _pick_faces(count: int, rng: RandomNumberGenerator) -> Array[int]:
	var faces: Array[int] = []
	for i in FACES:
		faces.append(i)
	# Fisher-Yates mit dem injizierten rng - shuffle() nähme nur den globalen.
	for i in range(FACES - 1, 0, -1):
		var j := _range(rng, 0, i)
		var swap := faces[i]
		faces[i] = faces[j]
		faces[j] = swap
	return faces.slice(0, clampi(count, 0, FACES))

## Material bzw. Rune fallen nach der SELTENHEIT ihrer Gravur - Engraving.
## RARITY_WEIGHTS bleibt die eine Quelle, jetzt für den Netz-Wurf statt für den
## toten Ikonensatz.
## Beide Tabellen werden EINMAL gebaut: Engraving.weight_of baut sonst je Wurf den
## ganzen Archetypen-Katalog neu.
static var _material_weights: Dictionary = {}
static var _rune_weights: Dictionary = {}

static func _pick_material(rng: RandomNumberGenerator) -> String:
	if _material_weights.is_empty():
		for material in DieMaterial.all():
			_material_weights[material.id] = Engraving.weight_of(material.id)
	return _pick_weighted(_material_weights, rng)

static func _pick_rune(rng: RandomNumberGenerator) -> String:
	if _rune_weights.is_empty():
		for rune in Rune.all():
			_rune_weights[rune.id] = Engraving.weight_of(Engraving.RUNE_PREFIX + rune.id)
	return _pick_weighted(_rune_weights, rng)

static func _pick_weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for weight: float in weights.values():
		total += weight
	if total <= 0.0:
		return String(weights.keys()[0]) if not weights.is_empty() else ""
	var roll := _roll_float(rng) * total
	var last := ""
	for id: String in weights:
		roll -= float(weights[id])
		last = id
		if roll < 0.0:
			return id
	return last
