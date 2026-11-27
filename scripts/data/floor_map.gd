class_name FloorMap
extends Resource
## Eine ETAGE des Casinos: Eingang, acht Räume, das Büro, verbunden durch Türen.
## Räume tragen den Bonus, Türen den Malus; jeder Zug durch eine Tür ist eine Runde.
## Reine Daten - die Klauseln würfelt GameRun über die Callables, die es hereinreicht.

enum DoorState { OPEN, PASSED, LOCKED }

const ENTRANCE := "eingang"
const OFFICE := "buero"
const ROOM_PREFIX := "raum"
const DOOR_PREFIX := "tuer"
const ENTRANCE_NAME := "Eingang"
const OFFICE_NAME := "Büro"

const ROOM_COUNT := 8
const BOSS_DOORS := 3
## Kürzester Weg Eingang → Büro in Zügen, in jeder Vorlage gleich.
const SHORTEST_MOVES := 4
## Stufen der acht Räume; Sackgassen bekommen zuerst die höchste.
const ROOM_TIERS := [DealClause.Tier.THREE, DealClause.Tier.THREE, DealClause.Tier.TWO,
	DealClause.Tier.TWO, DealClause.Tier.TWO, DealClause.Tier.ONE, DealClause.Tier.ONE,
	DealClause.Tier.ONE]
## Eine Tür trägt meist die höhere Stufe ihrer Räume, sonst eine darunter.
const DOOR_HIGH_CHANCE := 0.6
## So oft würfelt die Etage mit treat_chance um eine FREIE Tür.
const FREE_DOOR_THROWS := 3

## Rasterplätze: Eingang links, Büro rechts, die Räume in drei Spalten dazwischen.
const ENTRANCE_CELL := Vector2i(0, 1)
const OFFICE_CELL := Vector2i(4, 1)
## Grundriß-Vorlagen: acht Raum-Plätze, Türen als Paare. Jeder Raum der dritten
## Spalte hat zusätzlich seine Büro-Tür (drei je Vorlage).
const TEMPLATES := [
	{
		"name": "Flur",
		"rooms": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
			Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)],
		"doors": [[ENTRANCE_CELL, Vector2i(1, 1)], [ENTRANCE_CELL, Vector2i(1, 2)],
			[Vector2i(1, 1), Vector2i(2, 1)], [Vector2i(2, 1), Vector2i(2, 0)],
			[Vector2i(2, 1), Vector2i(2, 2)], [Vector2i(2, 0), Vector2i(3, 0)],
			[Vector2i(2, 1), Vector2i(3, 1)], [Vector2i(2, 2), Vector2i(3, 2)],
			[Vector2i(3, 0), Vector2i(3, 1)]],
	},
	{
		"name": "Zwei Flügel",
		"rooms": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 0), Vector2i(2, 1),
			Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)],
		"doors": [[ENTRANCE_CELL, Vector2i(1, 0)], [ENTRANCE_CELL, Vector2i(1, 2)],
			[Vector2i(1, 0), Vector2i(1, 1)], [Vector2i(1, 0), Vector2i(2, 0)],
			[Vector2i(2, 0), Vector2i(2, 1)], [Vector2i(2, 0), Vector2i(3, 0)],
			[Vector2i(2, 1), Vector2i(3, 1)], [Vector2i(3, 1), Vector2i(3, 2)]],
	},
	{
		"name": "Zickzack",
		"rooms": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
			Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)],
		"doors": [[ENTRANCE_CELL, Vector2i(1, 1)], [Vector2i(1, 1), Vector2i(1, 0)],
			[Vector2i(1, 1), Vector2i(2, 1)], [Vector2i(2, 1), Vector2i(2, 2)],
			[Vector2i(2, 2), Vector2i(3, 2)], [Vector2i(2, 1), Vector2i(2, 0)],
			[Vector2i(2, 0), Vector2i(3, 0)], [Vector2i(3, 0), Vector2i(3, 1)],
			[Vector2i(2, 1), Vector2i(3, 1)]],
	},
	{
		"name": "Galerie",
		"rooms": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, 2),
			Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)],
		"doors": [[ENTRANCE_CELL, Vector2i(1, 0)], [ENTRANCE_CELL, Vector2i(1, 1)],
			[Vector2i(1, 1), Vector2i(1, 2)], [Vector2i(1, 1), Vector2i(2, 1)],
			[Vector2i(1, 2), Vector2i(2, 2)], [Vector2i(2, 1), Vector2i(3, 1)],
			[Vector2i(2, 2), Vector2i(3, 2)], [Vector2i(3, 1), Vector2i(3, 0)]],
	},
	{
		"name": "Sackgassen",
		"rooms": [Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
			Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)],
		"doors": [[ENTRANCE_CELL, Vector2i(1, 0)], [ENTRANCE_CELL, Vector2i(1, 2)],
			[Vector2i(1, 0), Vector2i(2, 0)], [Vector2i(1, 2), Vector2i(2, 2)],
			[Vector2i(2, 0), Vector2i(2, 1)], [Vector2i(2, 0), Vector2i(3, 0)],
			[Vector2i(2, 2), Vector2i(3, 2)], [Vector2i(3, 0), Vector2i(3, 1)]],
	},
]

## Raum-Namen nach dem ersten Tag des Bonus - reine Kosmetik, jeder einmal je Etage.
const NAMES_BY_TAG := {
	DealClause.TAG_MONEY: ["Bar", "Kasse"],
	DealClause.TAG_PAYOUT: ["Bar", "Kasse"],
	DealClause.TAG_WORKSHOP: ["Werkstatt"],
	DealClause.TAG_SHOP: ["Lager", "Hinterzimmer"],
	DealClause.TAG_LUCK: ["Lounge"],
	DealClause.TAG_CHARM: ["Empore"],
	DealClause.TAG_MODULE: ["Labor-Flur"],
	DealClause.TAG_ENERGY: ["Generator"],
}
const VAULT_NAME := "Tresor"
const SPARE_NAMES := ["Salon", "Spielsaal", "Foyer", "Kabinett", "Wandelhalle", "Rauchsalon",
	"Spiegelsaal", "Galerie", "Garderobe", "Treppenhaus"]

@export var template_index := 0
## Raum-id -> {id, name, bonus, tier, cell, visited}; Eingang und Büro stehen mit darin.
var rooms: Dictionary = {}
## Je Tür {id, a, b, tier, malus, boss, state, scouted, free}.
var doors: Array[Dictionary] = []
var entrance := ENTRANCE
var office := OFFICE
## Der Raum, in dem der Puck steht.
var position := ENTRANCE

## Nur der Grundriß: Räume ohne Klausel, alle Türen offen und unerkundet.
static func build(template: int) -> FloorMap:
	var map := FloorMap.new()
	map.template_index = clampi(template, 0, TEMPLATES.size() - 1)
	var spec: Dictionary = TEMPLATES[map.template_index]
	var by_cell := {ENTRANCE_CELL: ENTRANCE, OFFICE_CELL: OFFICE}
	map.rooms[ENTRANCE] = _room(ENTRANCE, ENTRANCE_NAME, ENTRANCE_CELL)
	map.rooms[ENTRANCE]["visited"] = true
	map.rooms[OFFICE] = _room(OFFICE, OFFICE_NAME, OFFICE_CELL)
	var cells: Array = spec["rooms"]
	for i in cells.size():
		var room_id := ROOM_PREFIX + str(i)
		by_cell[cells[i]] = room_id
		map.rooms[room_id] = _room(room_id, "", cells[i])
	var pairs: Array = (spec["doors"] as Array).duplicate()
	for cell: Vector2i in cells:
		if cell.x == OFFICE_CELL.x - 1:
			pairs.append([cell, OFFICE_CELL])
	for pair: Array in pairs:
		map.doors.append({"id": DOOR_PREFIX + str(map.doors.size()),
			"a": String(by_cell[pair[0]]), "b": String(by_cell[pair[1]]),
			"tier": -1, "malus": "", "boss": "", "state": DoorState.OPEN,
			"scouted": false, "free": false})
	return map

static func _room(room_id: String, room_name: String, cell: Vector2i) -> Dictionary:
	return {"id": room_id, "name": room_name, "bonus": "", "tier": -1, "cell": cell, "visited": false}

## Würfelt eine Etage: Grundriß, Raum-Boni samt Stufen, Tür-Stufen, freie Türen und die
## Boss-Konditionen der Büro-Türen. offerable(id) -> bool ist GameRuns Auslage-Sperre.
static func roll(rng: RandomNumberGenerator, offerable: Callable, treat_chance: float,
		boss_ids: Array[String], template: int = -1) -> FloorMap:
	var pick := template if template >= 0 else _rand_index(rng, TEMPLATES.size())
	var map := build(pick)
	map._roll_rooms(rng, offerable)
	map._roll_doors(rng, treat_chance, boss_ids)
	map._name_rooms(rng)
	return map

func _roll_rooms(rng: RandomNumberGenerator, offerable: Callable) -> void:
	var ids := room_ids()
	_shuffle(ids, rng)
	var dead: Array[String] = []
	var rest: Array[String] = []
	for room_id in ids:
		if is_dead_end(room_id):
			dead.append(room_id)
		else:
			rest.append(room_id)
	var order: Array[String] = []
	order.append_array(dead)
	order.append_array(rest)
	var used: Array[String] = []
	for i in order.size():
		var tier: int = ROOM_TIERS[i]
		var bonus := _draw(DealClause.ids_for(tier, DealClause.Kind.BONUS), used, [] as Array[String],
			offerable, rng)
		rooms[order[i]]["tier"] = tier
		rooms[order[i]]["bonus"] = bonus
		if bonus != "":
			used.append(bonus)

func _roll_doors(rng: RandomNumberGenerator, treat_chance: float, boss_ids: Array[String]) -> void:
	var boss_at := 0
	for entry in doors:
		if is_office_door(entry):
			entry["tier"] = DealClause.Tier.BOSS
			entry["boss"] = boss_ids[boss_at] if boss_at < boss_ids.size() else ""
			entry["scouted"] = true
			boss_at += 1
			continue
		var high := maxi(int(rooms[entry["a"]]["tier"]), int(rooms[entry["b"]]["tier"]))
		high = maxi(high, DealClause.Tier.ONE)
		entry["tier"] = high if _roll(rng) < DOOR_HIGH_CHANCE else maxi(DealClause.Tier.ONE, high - 1)
	for i in FREE_DOOR_THROWS:
		if _roll(rng) >= treat_chance:
			continue
		var open: Array[Dictionary] = []
		for entry in doors:
			if not is_office_door(entry) and not bool(entry["free"]):
				open.append(entry)
		if not open.is_empty():
			open[_rand_index(rng, open.size())]["free"] = true

func _name_rooms(rng: RandomNumberGenerator) -> void:
	var taken: Array[String] = []
	var ids := room_ids()
	# Sackgassen zuerst, damit der Tresor an eine fällt, wenn sie Stufe 3 trägt.
	ids.sort_custom(func(a: String, b: String) -> bool: return is_dead_end(a) and not is_dead_end(b))
	for room_id in ids:
		var info: Dictionary = rooms[room_id]
		var wanted: Array = []
		if is_dead_end(room_id) and int(info["tier"]) == DealClause.Tier.THREE:
			wanted.append(VAULT_NAME)
		var tags := DealClause.tags_of(String(info["bonus"]))
		if not tags.is_empty():
			wanted.append_array(NAMES_BY_TAG.get(tags[0], []))
		var chosen := ""
		for candidate: String in wanted:
			if not taken.has(candidate):
				chosen = candidate
				break
		if chosen == "":
			var spare: Array[String] = []
			for candidate: String in SPARE_NAMES:
				if not taken.has(candidate):
					spare.append(candidate)
			chosen = spare[_rand_index(rng, spare.size())] if not spare.is_empty() else room_id
		taken.append(chosen)
		info["name"] = chosen

## Erkundet alle Türen des Raums: ihr Malus fällt JETZT, mit dem Zustand von jetzt.
func scout_from(room_id: String, rng: RandomNumberGenerator, offerable: Callable) -> void:
	for entry in doors_from(room_id):
		if not bool(entry["scouted"]):
			scout(entry, rng, offerable)

## Malus aus dem Topf der Tür-Stufe: kein Tag mit dem Bonus ihrer Räume, keine Klausel
## doppelt auf der Etage. Läuft der Topf leer, wird die Tür frei.
func scout(entry: Dictionary, rng: RandomNumberGenerator, offerable: Callable) -> void:
	entry["scouted"] = true
	if bool(entry["free"]) or String(entry["boss"]) != "" or is_office_door(entry):
		return
	var taboo: Array[String] = []
	taboo.append_array(DealClause.tags_of(String(rooms[entry["a"]]["bonus"])))
	taboo.append_array(DealClause.tags_of(String(rooms[entry["b"]]["bonus"])))
	var pool := DealClause.ids_for(int(entry["tier"]), DealClause.Kind.MALUS)
	entry["malus"] = _draw(pool, floor_clause_ids(), taboo, offerable, rng, false)

## Zieht eine Klausel des Topfes; mit fallback darf eine schon vergebene wiederkommen.
static func _draw(pool: Array[String], used: Array[String], taboo: Array[String],
		offerable: Callable, rng: RandomNumberGenerator, fallback: bool = true) -> String:
	var fits: Array[String] = []
	var unused: Array[String] = []
	for clause_id in pool:
		if used.has(clause_id) or shares_tag(clause_id, taboo):
			continue
		unused.append(clause_id)
		if not offerable.is_valid() or offerable.call(clause_id):
			fits.append(clause_id)
	if fits.is_empty() and fallback:
		fits = unused if not unused.is_empty() else pool
	return fits[_rand_index(rng, fits.size())] if not fits.is_empty() else ""

static func shares_tag(clause_id: String, taboo: Array[String]) -> bool:
	for tag in DealClause.tags_of(clause_id):
		if taboo.has(tag):
			return true
	return false

# --- Abfragen -------------------------------------------------------------------

func room(room_id: String) -> Dictionary:
	return rooms.get(room_id, {})

func door(door_id: String) -> Dictionary:
	for entry in doors:
		if entry["id"] == door_id:
			return entry
	return {}

## Die acht Räume ohne Eingang und Büro, in Vorlagen-Reihenfolge.
func room_ids() -> Array[String]:
	var ids: Array[String] = []
	for i in ROOM_COUNT:
		if rooms.has(ROOM_PREFIX + str(i)):
			ids.append(ROOM_PREFIX + str(i))
	return ids

func doors_from(room_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in doors:
		if entry["a"] == room_id or entry["b"] == room_id:
			found.append(entry)
	return found

func other_side(entry: Dictionary, room_id: String) -> String:
	return String(entry["b"]) if entry["a"] == room_id else String(entry["a"])

func is_office_door(entry: Dictionary) -> bool:
	return entry["a"] == office or entry["b"] == office

## Gangbar = offen oder ausgebrannt; nur eine gesperrte Tür hält auf.
func passable(entry: Dictionary) -> bool:
	return int(entry["state"]) != DoorState.LOCKED

## Ein Raum mit genau einer Tür (Eingang und Büro zählen nicht).
func is_dead_end(room_id: String) -> bool:
	return room_id != entrance and room_id != office and doors_from(room_id).size() == 1

## Züge über gangbare Türen von from nach to (−1 = unerreichbar).
func shortest_moves(from: String, to: String, without_door: String = "") -> int:
	var dist := {from: 0}
	var queue: Array[String] = [from]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if here == to:
			return int(dist[here])
		for entry in doors_from(here):
			if entry["id"] == without_door or not passable(entry):
				continue
			var next := other_side(entry, here)
			if not dist.has(next):
				dist[next] = int(dist[here]) + 1
				queue.append(next)
	return -1

func reaches_office(from: String, without_door: String = "") -> bool:
	return shortest_moves(from, office, without_door) >= 0

## Türen, die ein Fumble sperren darf: offen, und ohne sie bleibt das Büro erreichbar.
func lock_candidates() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in doors:
		if int(entry["state"]) == DoorState.OPEN and reaches_office(position, String(entry["id"])):
			found.append(entry)
	return found

## Alle Klauseln, die auf der Etage schon liegen (Boni, gefallene Mali, Boss-Konditionen).
func floor_clause_ids() -> Array[String]:
	var ids: Array[String] = []
	for room_id: String in rooms:
		if String(rooms[room_id]["bonus"]) != "":
			ids.append(String(rooms[room_id]["bonus"]))
	for entry in doors:
		for key in ["malus", "boss"]:
			if String(entry[key]) != "":
				ids.append(String(entry[key]))
	return ids

## "Bar → Tresor" - die Tür in Worten, vom Standraum aus gelesen.
func door_label(door_id: String) -> String:
	var entry := door(door_id)
	if entry.is_empty():
		return ""
	var near := String(entry["a"])
	var far := String(entry["b"])
	if far == position:
		near = far
		far = String(entry["a"])
	return "%s → %s" % [room(near)["name"], room(far)["name"]]

# --- Zufall (rng optional, sonst der globale) ---------------------------------

static func _rand_index(rng: RandomNumberGenerator, count: int) -> int:
	if count <= 1:
		return 0
	return rng.randi_range(0, count - 1) if rng != null else randi_range(0, count - 1)

static func _roll(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rand_index(rng, i + 1)
		var keep: Variant = items[i]
		items[i] = items[j]
		items[j] = keep
