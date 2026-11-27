class_name FloorPlan
extends Resource
## Eine ETAGE als GRUNDRISS (Welle 7 der Etagen-Karte): ein Hauptflur in Abschnitten,
## Flügel mit Räumen sehr verschiedener Größe, Seitenflure, Brandschutztüren, Aufzug,
## Büro und Schlüsselkarte auf einem Zellraster. Räume tragen den Bonus, Türen den Malus.
## Reine Daten und Regeln - die Klauseln würfelt GameRun über die Callables, die es hereinreicht.

const GRID := Vector2i(16, 11)

const ROOM_PREFIX := "raum"
const SECTION_PREFIX := "flur"
const DOOR_PREFIX := "tuer"
## Besitzer der Aufzugs-Zellen und Standort "" heißen beide Aufzug.
const ELEVATOR := "aufzug"
const ELEVATOR_NAME := "Aufzug"
const OFFICE_NAME := "Büro"

const DOOR_ROOM := "raum"
const DOOR_LINK := "verbindung"
const DOOR_FIRE := "brandschutz"
const DOOR_BOSS := "boss"

## Tür-Stufen: 0 offen/frei, 1..3 Riegel, TIER_BOSS das rote Tor.
const TIER_FREE := 0
const TIER_BOSS := 4

const MIN_ROOMS := 10
const MAX_ROOMS := 14
const MIN_SECTION_ROOMS := 2
const MAX_SECTION_ROOMS := 5
## Aufzug → Schlüsselkarte → Büro in Zügen, mindestens.
const MIN_KEY_MOVES := 3
## So viele Boss-Konditionen braucht das Büro höchstens (Flurtür plus bis zu zwei Verbindungstüren).
const BOSS_DOORS := 3
const MAX_ATTEMPTS := 80
## Mit diesem Seed baut der Erzeuger einen gültigen Grundriß (ein Test hält es fest).
const FALLBACK_SEED := 7

## Fläche in Zellen → Stufe: bis SMALL_AREA klein, ab LARGE_AREA groß.
const SMALL_AREA := 6
const LARGE_AREA := 12

const SECTION_MIN := 3
const SECTION_MAX := 5
const WING_DEPTHS := [0, 2, 3, 4]
const WING_DEPTH_WEIGHTS := [10, 20, 35, 35]
## Flügel-Grenzen springen um bis zu so viele Zellen gegen die Brandschutztür.
const WING_JITTER := 1
const ELEVATOR_SIZE := Vector2i(2, 2)
const SIDE_CORRIDOR_CHANCE := 0.5
const SECOND_SIDE_CORRIDOR_CHANCE := 0.25
const SIDE_FIRE_CHANCE := 0.3
const LINK_CHANCE := 0.25
## Ein Schnitt quer zum Flur (er schafft hintere Räume), wenn beide Richtungen gehen.
const CROSS_CUT_CHANCE := 0.35
const FOUR_SECTION_CHANCE := 0.35
const FOUR_SECTION_STEP := 0.1
const FOUR_SECTION_MAX := 0.75
## Eine Tür trägt meist die Stufe des Raums, in den sie führt, sonst eine darunter.
const DOOR_HIGH_CHANCE := 0.6
## So oft würfelt die Etage mit treat_chance um eine FREIE Tür.
const FREE_DOOR_THROWS := 3
const THEME_LIMIT := 2
## So oft versucht die Etage eine Themen-Verteilung, die jeden Deckel hält.
const THEME_ATTEMPTS := 12

const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# --- THEMEN ---------------------------------------------------------------------

const THEME_CASH := "kasse"
const THEME_BAR := "bar"
const THEME_BOUTIQUE := "boutique"
const THEME_WORKSHOP := "werkstatt"
const THEME_GENERATOR := "generator"
const THEME_LOUNGE := "lounge"
const THEME_BETTING := "wettbuero"
const THEME_STUDIO := "studio"
const THEME_TECH := "technikraum"
const THEME_BACK_ROOM := "hinterzimmer"
const THEME_GAUGE := "eichamt"
## Das Büro ist kein Thema der Tabelle, trägt aber seine Farbe wie eines.
const THEME_OFFICE := "buero"
const OFFICE_COLOR := "#c0413a"

## Kasse darf Geld-Grün, Generator Energie-Violett; alle anderen meiden die Wertungsfarben.
const THEMES := [
	{"id": THEME_CASH, "name": "Kasse", "alt": "Wechselschalter", "symbol": "muenze", "color": "#4fae78"},
	{"id": THEME_BAR, "name": "Bar", "alt": "Cocktailbar", "symbol": "glas", "color": "#c26a4a"},
	{"id": THEME_BOUTIQUE, "name": "Boutique", "alt": "Salon", "symbol": "tasche", "color": "#6f7fd2"},
	{"id": THEME_WORKSHOP, "name": "Werkstatt", "alt": "Prägerei", "symbol": "schluessel", "color": "#a9824e"},
	{"id": THEME_GENERATOR, "name": "Generator", "alt": "Umspannwerk", "symbol": "blitz", "color": "#8a6ad0"},
	{"id": THEME_LOUNGE, "name": "Lounge", "alt": "Spielsaal", "symbol": "klee", "color": "#a3a84f"},
	{"id": THEME_BETTING, "name": "Wettbüro", "alt": "Buchmacher", "symbol": "schein", "color": "#5b8db5"},
	{"id": THEME_STUDIO, "name": "Studio", "alt": "Galerie", "symbol": "diskette", "color": "#b98a94"},
	{"id": THEME_TECH, "name": "Technikraum", "alt": "Schaltraum", "symbol": "chip", "color": "#8a96a3"},
	{"id": THEME_BACK_ROOM, "name": "Hinterzimmer", "alt": "Separee", "symbol": "auge", "color": "#7d5a7a"},
	{"id": THEME_GAUGE, "name": "Eichamt", "alt": "Prüfstelle", "symbol": "waage", "color": "#c2b48a"},
]

## Jede Bonus-Klausel ist die Variante GENAU EINES Raums.
const ROOM_OF_CLAUSE := {
	DealClause.ADVANCE_PAYMENT: THEME_CASH,
	DealClause.SAVINGS_BONUS: THEME_CASH,
	DealClause.INTEREST: THEME_CASH,
	DealClause.HAND_WAGE: THEME_CASH,
	DealClause.EXCHANGE_OFFICE: THEME_CASH,
	DealClause.BLANK_CHEQUE: THEME_CASH,
	DealClause.HAPPY_HOUR: THEME_BAR,
	DealClause.GOLDEN_HANDSHAKE: THEME_BAR,
	DealClause.ALL_ON_RED: THEME_BAR,
	DealClause.CASH_DISCOUNT: THEME_BOUTIQUE,
	DealClause.FREE_FLIP: THEME_BOUTIQUE,
	DealClause.BUYBACK: THEME_BOUTIQUE,
	DealClause.SOUL_MARKET: THEME_BOUTIQUE,
	DealClause.MATH_WEEK: THEME_BOUTIQUE,
	DealClause.REGULAR_CUSTOMER: THEME_BOUTIQUE,
	DealClause.SPECIAL_DELIVERY: THEME_BOUTIQUE,
	DealClause.TRIAL_RUN: THEME_WORKSHOP,
	DealClause.WORK_HARDENING: THEME_WORKSHOP,
	DealClause.MASTER_PRESS: THEME_WORKSHOP,
	DealClause.SEED_CAPITAL: THEME_GENERATOR,
	DealClause.DEPOSIT: THEME_GENERATOR,
	DealClause.HIGH_VOLTAGE: THEME_GENERATOR,
	DealClause.DOUBLE_LOADER: THEME_GENERATOR,
	DealClause.BIG_STORAGE: THEME_GENERATOR,
	DealClause.SUPERCONDUCTOR: THEME_GENERATOR,
	# Goldader zahlt je geräumter Überladungs-Stufe - ihr Auslöser ist der Generator.
	DealClause.GOLD_VEIN: THEME_GENERATOR,
	DealClause.LUCKY_PENNY: THEME_LOUNGE,
	DealClause.LUCKY_DAY: THEME_LOUNGE,
	DealClause.LUCKY_STREAK: THEME_LOUNGE,
	DealClause.LUCKY_CHILD: THEME_LOUNGE,
	DealClause.FREE_HAND: THEME_LOUNGE,
	DealClause.LOADED_LUCK_DIE: THEME_LOUNGE,
	DealClause.REINSURANCE: THEME_BETTING,
	DealClause.INSURANCE_FRAUD: THEME_BETTING,
	DealClause.ODDS_BONUS: THEME_BETTING,
	# Ankerklausel versichert den ersten Fumble - eine Police wie die Rückversicherung.
	DealClause.ANCHOR_CLAUSE: THEME_BETTING,
	DealClause.FREE_CHARM: THEME_STUDIO,
	DealClause.CONNOISSEUR_EYE: THEME_STUDIO,
	DealClause.SPOTLIGHT: THEME_TECH,
	DealClause.OVERTIME: THEME_TECH,
	DealClause.FULL_LOADOUT: THEME_TECH,
	DealClause.BACK_ROOM_CONTACT: THEME_BACK_ROOM,
	DealClause.CALIBRATION: THEME_GAUGE,
}

static func theme_info(theme_id: String) -> Dictionary:
	for entry: Dictionary in THEMES:
		if entry["id"] == theme_id:
			return entry
	if theme_id == THEME_OFFICE:
		return {"id": THEME_OFFICE, "name": OFFICE_NAME, "alt": OFFICE_NAME, "symbol": "schloss",
			"color": OFFICE_COLOR}
	return {}

static func theme_color(theme_id: String) -> Color:
	var info := theme_info(theme_id)
	return Color(String(info["color"])) if not info.is_empty() else Color(0.5, 0.5, 0.5)

## Die Bonus-Klauseln eines Themas in einer Raum-Stufe (1..3).
static var _clauses_cache: Dictionary = {}

static func clauses_of(theme_id: String, tier: int) -> Array[String]:
	var key := "%s|%d" % [theme_id, tier]
	if _clauses_cache.has(key):
		return _clauses_cache[key]
	var found: Array[String] = []
	for clause_id: String in ROOM_OF_CLAUSE:
		if ROOM_OF_CLAUSE[clause_id] != theme_id:
			continue
		var clause := DealClause.find(clause_id)
		if clause != null and int(clause.tier) == clause_tier(tier):
			found.append(clause_id)
	_clauses_cache[key] = found
	return found

## Raum-/Tür-Stufe 1..3 → DealClause.Tier.
static func clause_tier(tier: int) -> int:
	return clampi(tier - 1, DealClause.Tier.ONE, DealClause.Tier.THREE)

static func tier_of_area(area: int) -> int:
	if area <= SMALL_AREA:
		return 1
	return 3 if area >= LARGE_AREA else 2

# --- Zustand --------------------------------------------------------------------

@export var floor_index := 0
## Zelle → Besitzer (Raum-Id, Abschnitts-Id oder ELEVATOR); die Schlüssel sind der Umriß.
var cells: Dictionary = {}
## Je Flurabschnitt {id, rects, neighbors, side, parent}.
var sections: Array[Dictionary] = []
## Raum-Id → {id, rect, area, tier, theme, name, bonus, visited, has_key, is_office, back, section}.
var rooms: Dictionary = {}
## Je Tür {id, kind, a, b, section, cell, side, tier, free, malus, boss, scouted, passed}.
## cell gehört zu a, cell + side zu b; section ist der Flurabschnitt einer Flurtür, sonst "".
var doors: Array[Dictionary] = []
## {rect, section, cell, side} - cell + side ist die Flurzelle vor der Aufzugstür.
var elevator: Dictionary = {}
var office := ""
var key_room := ""
## Standort: "" = im Aufzug, sonst Raum-Id.
var position := ""
var key_taken := false
## Der gegangene Weg: je Zug {from, to, door, fire_door, section_from, section_to}.
var trail: Array[Dictionary] = []
## Erzeuger-Auskunft: Versuche bis zum gültigen Grundriß, Rückfall-Plan ja/nein.
var attempts := 0
var fallback := false

# --- Erzeugung ------------------------------------------------------------------

## Würfelt eine Etage nach den neun Schritten des Plans. offerable(id) -> bool ist GameRuns
## Auslage-Sperre; boss_ids sind die Konditionen der Büro-Türen in Reihenfolge.
static func roll(rng: RandomNumberGenerator, offerable: Callable, treat_chance: float,
		boss_ids: Array[String], floor_number: int = 0) -> FloorPlan:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var plan := FloorPlan.new()
	plan.floor_index = floor_number
	for attempt in MAX_ATTEMPTS:
		plan.attempts = attempt + 1
		if plan._build_layout(rng):
			plan._dress(rng, offerable, treat_chance, boss_ids)
			return plan
	plan = fallback_layout(floor_number)
	plan.attempts = MAX_ATTEMPTS
	plan._dress(rng, offerable, treat_chance, boss_ids)
	return plan

## Der garantiert gültige Rückfall: derselbe Erzeuger mit festem Seed.
static func fallback_layout(floor_number: int = 0) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.floor_index = floor_number
	var fixed := RandomNumberGenerator.new()
	fixed.seed = FALLBACK_SEED
	for attempt in MAX_ATTEMPTS:
		if plan._build_layout(fixed):
			break
	plan.fallback = true
	return plan

func _clear() -> void:
	cells.clear()
	sections.clear()
	rooms.clear()
	doors.clear()
	elevator = {}
	office = ""
	key_room = ""
	position = ""
	key_taken = false
	trail.clear()

## Schritte 1-8: Flur, Abschnitte, Flügel, Seitenflure, Räume, Türen, Aufzug, Büro,
## Schlüsselkarte und die PRÜFUNG. false = neu würfeln.
func _build_layout(rng: RandomNumberGenerator) -> bool:
	_clear()
	var four := minf(FOUR_SECTION_CHANCE + FOUR_SECTION_STEP * floor_index, FOUR_SECTION_MAX)
	var count := 4 if rng.randf() < four else 3
	var lengths := _section_lengths(count, rng)
	var total := 0
	for length in lengths:
		total += length
	var x0 := rng.randi_range(0, GRID.x - total)
	var cy := rng.randi_range(4, GRID.y - 5)
	var xs: Array[int] = [x0]
	for i in count:
		var sid := SECTION_PREFIX + str(i)
		var rect := Rect2i(xs[i], cy, lengths[i], 1)
		sections.append({"id": sid, "rects": [rect], "neighbors": [] as Array[String],
			"side": false, "parent": ""})
		_fill(rect, sid)
		xs.append(xs[i] + lengths[i])
	for i in count - 1:
		_add_fire_door(Vector2i(xs[i + 1] - 1, cy), Vector2i(1, 0), sections[i]["id"], sections[i + 1]["id"])
	# Bautiefen je Abschnitt und Seite (−1 oben, +1 unten), mindestens eine Seite ab zwei.
	var depth := {-1: [], 1: []}
	for i in count:
		var up := _roll_depth(rng)
		var down := _roll_depth(rng)
		if maxi(up, down) < 2:
			if rng.randf() < 0.5:
				up = 2 + rng.randi_range(0, 2)
			else:
				down = 2 + rng.randi_range(0, 2)
		depth[-1].append(up)
		depth[1].append(down)
	var lift := 1 if count == 3 else rng.randi_range(1, 2)
	var lift_sides: Array[int] = []
	for side in [-1, 1]:
		if int(depth[side][lift]) >= 2:
			lift_sides.append(side)
	var lift_side: int = lift_sides[rng.randi_range(0, lift_sides.size() - 1)]
	if int(depth[lift_side][lift]) == 3:
		depth[lift_side][lift] = 2 if rng.randf() < 0.5 else 4
	# Flügel: x-Grenzen springen gegen die Abschnitte, Seite für Seite unabhängig.
	var wings: Array[Dictionary] = []
	for side in [-1, 1]:
		var bounds: Array[int] = xs.duplicate()
		for i in range(1, count):
			var shift := rng.randi_range(-WING_JITTER, WING_JITTER)
			if bounds[i] + shift - bounds[i - 1] >= 2 and xs[i + 1] - (bounds[i] + shift) >= 2:
				bounds[i] += shift
		for i in count:
			var d := int(depth[side][i])
			if d <= 0:
				continue
			var y := cy - d if side < 0 else cy + 1
			wings.append({"rect": Rect2i(bounds[i], y, bounds[i + 1] - bounds[i], d), "side": side,
				"section": sections[i]["id"], "lift": side == lift_side and i == lift,
				"lift_x": [xs[lift], xs[lift + 1]]})
	var regions: Array[Dictionary] = []
	var side_candidates: Array[Dictionary] = []
	for wing in wings:
		if bool(wing["lift"]):
			if not _carve_elevator(wing, cy, rng, regions):
				return false
		elif (wing["rect"] as Rect2i).size.y >= 3 and (wing["rect"] as Rect2i).size.x >= 5:
			side_candidates.append(wing)
		else:
			regions.append({"rect": wing["rect"], "section": wing["section"]})
	_shuffle(side_candidates, rng)
	var side_count := 0
	if not side_candidates.is_empty() and rng.randf() < SIDE_CORRIDOR_CHANCE:
		side_count = 1
		if side_candidates.size() > 1 and rng.randf() < SECOND_SIDE_CORRIDOR_CHANCE:
			side_count = 2
	for i in side_candidates.size():
		if i < side_count:
			_carve_side_corridor(side_candidates[i], cy, rng, regions)
		else:
			regions.append({"rect": side_candidates[i]["rect"], "section": side_candidates[i]["section"]})
	# Räume durch unregelmäßige Schnitte.
	for region in regions:
		var parts: Array[Rect2i] = []
		_cut(region["rect"], rng, parts)
		for rect in parts:
			var room_id := ROOM_PREFIX + str(rooms.size())
			rooms[room_id] = {"id": room_id, "rect": rect, "area": rect.size.x * rect.size.y,
				"tier": tier_of_area(rect.size.x * rect.size.y), "theme": "", "name": "", "bonus": "",
				"visited": false, "has_key": false, "is_office": false, "back": false,
				"section": "", "home": region["section"]}
			_fill(rect, room_id)
	var room_count := rooms.size() - 1
	if room_count < MIN_ROOMS or room_count > MAX_ROOMS:
		return false
	_place_corridor_doors(rng)
	if not _place_office(rng):
		return false
	if not _place_links(rng):
		return false
	_assign_room_sections()
	if not _check_sections():
		return false
	if _distances("", false).size() < rooms.size() - 1:
		return false
	return _place_key(rng)

func _section_lengths(count: int, rng: RandomNumberGenerator) -> Array[int]:
	var lengths: Array[int] = []
	for i in count:
		lengths.append(rng.randi_range(SECTION_MIN, SECTION_MAX))
	var total := 0
	for length in lengths:
		total += length
	# Zu lang für das Raster: zufällige Abschnitte schrumpfen bis aufs Mindestmaß.
	while total > GRID.x:
		var i := rng.randi_range(0, count - 1)
		if lengths[i] > SECTION_MIN:
			lengths[i] -= 1
			total -= 1
	return lengths

func _roll_depth(rng: RandomNumberGenerator) -> int:
	var sum := 0
	for weight: int in WING_DEPTH_WEIGHTS:
		sum += weight
	var pick := rng.randi_range(0, sum - 1)
	for i in WING_DEPTHS.size():
		pick -= int(WING_DEPTH_WEIGHTS[i])
		if pick < 0:
			return int(WING_DEPTHS[i])
	return int(WING_DEPTHS[0])

func _fill(rect: Rect2i, owner: String) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells[Vector2i(x, y)] = owner

## Der Aufzug: ein 2 × 2-Kern am Flur seines Abschnitts; der Rest des Flügels wird Regionen.
func _carve_elevator(wing: Dictionary, cy: int, rng: RandomNumberGenerator, regions: Array[Dictionary]) -> bool:
	var rect: Rect2i = wing["rect"]
	var side: int = wing["side"]
	var lift_x: Array = wing["lift_x"]
	var options: Array[int] = []
	for ex in range(rect.position.x, rect.end.x - ELEVATOR_SIZE.x + 1):
		var left := ex - rect.position.x
		var right := rect.end.x - ex - ELEVATOR_SIZE.x
		if (left == 1) or (right == 1):
			continue
		if ex < int(lift_x[0]) or ex + ELEVATOR_SIZE.x > int(lift_x[1]):
			continue
		options.append(ex)
	if options.is_empty():
		return false
	var ex: int = options[rng.randi_range(0, options.size() - 1)]
	var near_y := cy - ELEVATOR_SIZE.y if side < 0 else cy + 1
	var core := Rect2i(ex, near_y, ELEVATOR_SIZE.x, ELEVATOR_SIZE.y)
	_fill(core, ELEVATOR)
	var door_x := ex + rng.randi_range(0, ELEVATOR_SIZE.x - 1)
	var door_y := cy - 1 if side < 0 else cy + 1
	elevator = {"rect": core, "section": wing["section"], "cell": Vector2i(door_x, door_y),
		"side": Vector2i(0, 1 if side < 0 else -1)}
	var home: String = wing["section"]
	if ex > rect.position.x:
		regions.append({"rect": Rect2i(rect.position.x, rect.position.y, ex - rect.position.x, rect.size.y), "section": home})
	if rect.end.x > core.end.x:
		regions.append({"rect": Rect2i(core.end.x, rect.position.y, rect.end.x - core.end.x, rect.size.y), "section": home})
	var behind := rect.size.y - ELEVATOR_SIZE.y
	if behind >= 2:
		var by := rect.position.y if side < 0 else core.end.y
		regions.append({"rect": Rect2i(ex, by, ELEVATOR_SIZE.x, behind), "section": home})
	return true

## Ein senkrechter Seitenflur in einen tiefen Flügel, mit SIDE_FIRE_CHANCE ein eigener Abschnitt.
func _carve_side_corridor(wing: Dictionary, cy: int, rng: RandomNumberGenerator, regions: Array[Dictionary]) -> void:
	var rect: Rect2i = wing["rect"]
	var side: int = wing["side"]
	var d := rect.size.y
	var xc := rng.randi_range(rect.position.x + 2, rect.end.x - 3)
	var reach := d
	if d >= 4 and rng.randf() < 0.5:
		reach = d - 2
	var parent: String = cells.get(Vector2i(xc, cy), wing["section"])
	var sid := parent
	var near_y := cy - reach if side < 0 else cy + 1
	var corridor := Rect2i(xc, near_y, 1, reach)
	if rng.randf() < SIDE_FIRE_CHANCE:
		sid = SECTION_PREFIX + str(sections.size())
		sections.append({"id": sid, "rects": [corridor], "neighbors": [] as Array[String],
			"side": true, "parent": parent})
		var first := Vector2i(xc, cy - 1 if side < 0 else cy + 1)
		_add_fire_door(Vector2i(xc, cy), first - Vector2i(xc, cy), parent, sid)
	else:
		(section(parent)["rects"] as Array).append(corridor)
	_fill(corridor, sid)
	if xc > rect.position.x:
		regions.append({"rect": Rect2i(rect.position.x, near_y, xc - rect.position.x, reach), "section": sid})
	if rect.end.x > xc + 1:
		regions.append({"rect": Rect2i(xc + 1, near_y, rect.end.x - xc - 1, reach), "section": sid})
	if reach < d:
		var cap_y := rect.position.y if side < 0 else cy + 1 + reach
		regions.append({"rect": Rect2i(rect.position.x, cap_y, rect.size.x, d - reach), "section": sid})

func _add_fire_door(cell: Vector2i, side: Vector2i, a: String, b: String) -> void:
	doors.append(_door(DOOR_FIRE, a, b, "", cell, side))
	(section(a)["neighbors"] as Array).append(b)
	(section(b)["neighbors"] as Array).append(a)

func _door(kind: String, a: String, b: String, on_section: String, cell: Vector2i, side: Vector2i) -> Dictionary:
	return {"id": DOOR_PREFIX + str(doors.size()), "kind": kind, "a": a, "b": b, "section": on_section,
		"cell": cell, "side": side, "tier": TIER_FREE, "free": false, "malus": "", "boss": "",
		"scouted": kind == DOOR_FIRE, "passed": false}

## Rekursive Schnitte; die Haltewahrscheinlichkeit fällt mit der Fläche, also bleiben
## Räume sehr verschiedener Größe stehen. Mindestmaß 2 × 2.
func _cut(rect: Rect2i, rng: RandomNumberGenerator, out: Array[Rect2i]) -> void:
	var area := rect.size.x * rect.size.y
	var can_x := rect.size.x >= 4
	var can_y := rect.size.y >= 4
	if not can_x and not can_y:
		out.append(rect)
		return
	var stop := 0.0
	if area <= SMALL_AREA:
		stop = 1.0
	elif area < LARGE_AREA:
		stop = 0.6
	elif area <= 16:
		stop = 0.5
	elif area <= 20:
		stop = 0.1
	if rng.randf() < stop:
		out.append(rect)
		return
	var cross := can_y and (not can_x or rng.randf() < CROSS_CUT_CHANCE)
	if cross:
		var at := rng.randi_range(2, rect.size.y - 2)
		_cut(Rect2i(rect.position, Vector2i(rect.size.x, at)), rng, out)
		_cut(Rect2i(rect.position.x, rect.position.y + at, rect.size.x, rect.size.y - at), rng, out)
	else:
		var at := rng.randi_range(2, rect.size.x - 2)
		_cut(Rect2i(rect.position, Vector2i(at, rect.size.y)), rng, out)
		_cut(Rect2i(rect.position.x + at, rect.position.y, rect.size.x - at, rect.size.y), rng, out)

## Kanten eines Raums zu Nachbarn: [Zelle im Raum, Seite] je Kante, wo pick(owner) gilt.
func _edges_of(room_id: String, pick: Callable) -> Array:
	var rect: Rect2i = rooms[room_id]["rect"]
	var found: Array = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			for side: Vector2i in SIDES:
				var other: String = cells.get(cell + side, "")
				if other != room_id and pick.call(other):
					found.append([cell, side, other])
	return found

## Schritt 6a: jeder Raum mit Flurwand bekommt EINE Flurtür, bevorzugt an seinem Abschnitt.
func _place_corridor_doors(rng: RandomNumberGenerator) -> void:
	for room_id: String in rooms:
		var edges := _edges_of(room_id, func(o: String) -> bool: return is_section(o))
		if edges.is_empty():
			rooms[room_id]["back"] = true
			continue
		var home: Array = []
		for edge: Array in edges:
			if edge[2] == rooms[room_id]["home"]:
				home.append(edge)
		var pool := home if not home.is_empty() else edges
		var edge: Array = pool[rng.randi_range(0, pool.size() - 1)]
		doors.append(_door(DOOR_ROOM, room_id, edge[2], edge[2], edge[0], edge[1]))

## Die Nachbarn eines Raums mit ihren gemeinsamen Kanten (Raum-Id → [[Zelle, Seite] …]).
func _room_neighbors(room_id: String) -> Dictionary:
	var by: Dictionary = {}
	for edge: Array in _edges_of(room_id, func(o: String) -> bool: return o.begins_with(ROOM_PREFIX)):
		if not by.has(edge[2]):
			by[edge[2]] = []
		by[edge[2]].append([edge[0], edge[1]])
	return by

## Schritt 7b: das Büro - ein mittlerer Raum mit Flurtür im Abschnitt, der vom Aufzug am
## weitesten liegt; seine Flurtür und ein bis zwei Verbindungstüren werden BOSS-Türen.
func _place_office(rng: RandomNumberGenerator) -> bool:
	var dist := _section_distances(String(elevator["section"]))
	var far := 0
	for sid: String in dist:
		far = maxi(far, int(dist[sid]))
	var picks: Array[String] = []
	var medium: Array[String] = []
	for entry in doors:
		if entry["kind"] != DOOR_ROOM or int(dist.get(entry["section"], -1)) != far:
			continue
		var room_id: String = entry["a"]
		if _room_neighbors(room_id).is_empty():
			continue
		picks.append(room_id)
		if int(rooms[room_id]["tier"]) == 2:
			medium.append(room_id)
	if picks.is_empty():
		return false
	var pool := medium if not medium.is_empty() else picks
	office = pool[rng.randi_range(0, pool.size() - 1)]
	rooms[office]["is_office"] = true
	rooms[office]["theme"] = THEME_OFFICE
	rooms[office]["name"] = OFFICE_NAME
	for entry in doors:
		if entry["a"] == office:
			entry["kind"] = DOOR_BOSS
	var near := _room_neighbors(office)
	var ids: Array = near.keys()
	_shuffle(ids, rng)
	var links := mini(rng.randi_range(1, 2), ids.size())
	for i in links:
		var edges: Array = near[ids[i]]
		var edge: Array = edges[rng.randi_range(0, edges.size() - 1)]
		doors.append(_door(DOOR_BOSS, office, ids[i], "", edge[0], edge[1]))
	return true

## Schritt 6b: hintere Räume hängen über eine Verbindungstür an einem verbundenen Nachbarn
## (nie am Büro), dann mit LINK_CHANCE je gemeinsamer Wand eine weitere Verbindungstür.
func _place_links(rng: RandomNumberGenerator) -> bool:
	var joined: Dictionary = {}
	var waiting: Array[String] = []
	for room_id: String in rooms:
		if room_id == office:
			continue
		if bool(rooms[room_id]["back"]):
			waiting.append(room_id)
		else:
			joined[room_id] = true
	var linked: Dictionary = {}
	while not waiting.is_empty():
		var progress := false
		for room_id in waiting.duplicate():
			var near := _room_neighbors(room_id)
			var hosts: Array = []
			for other: String in near:
				if joined.has(other):
					hosts.append(other)
			if hosts.is_empty():
				continue
			var host: String = hosts[rng.randi_range(0, hosts.size() - 1)]
			var edges: Array = near[host]
			var edge: Array = edges[rng.randi_range(0, edges.size() - 1)]
			doors.append(_door(DOOR_LINK, room_id, host, "", edge[0], edge[1]))
			linked[_pair_key(room_id, host)] = true
			joined[room_id] = true
			waiting.erase(room_id)
			progress = true
		if not progress:
			return false
	for room_id: String in rooms:
		if room_id == office:
			continue
		var near := _room_neighbors(room_id)
		for other: String in near:
			if other == office or other < room_id or linked.has(_pair_key(room_id, other)):
				continue
			if rng.randf() < LINK_CHANCE:
				var edges: Array = near[other]
				var edge: Array = edges[rng.randi_range(0, edges.size() - 1)]
				doors.append(_door(DOOR_LINK, room_id, other, "", edge[0], edge[1]))
				linked[_pair_key(room_id, other)] = true
	return true

static func _pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

## Abschnitt jedes Raums: der seiner Flurtür, ein hinterer erbt ihn über Verbindungstüren.
func _assign_room_sections() -> void:
	var queue: Array[String] = []
	for entry in doors:
		if entry["section"] != "" and rooms.has(entry["a"]):
			rooms[entry["a"]]["section"] = entry["section"]
			queue.append(entry["a"])
	while not queue.is_empty():
		var here: String = queue.pop_front()
		for entry in doors:
			if entry["kind"] != DOOR_LINK:
				continue
			var other := ""
			if entry["a"] == here:
				other = entry["b"]
			elif entry["b"] == here:
				other = entry["a"]
			if other != "" and String(rooms[other]["section"]) == "":
				rooms[other]["section"] = rooms[here]["section"]
				queue.append(other)

func _check_sections() -> bool:
	for info in sections:
		var count := 0
		for room_id: String in rooms:
			if rooms[room_id]["section"] == info["id"]:
				count += 1
		if count < MIN_SECTION_ROOMS or count > MAX_SECTION_ROOMS:
			return false
	return true

## Schritt 7c: die Schlüsselkarte - nicht im Abschnitt des Büros (ab vier Abschnitten auch
## nicht in dem des Aufzugs), Aufzug → Karte → Büro mindestens MIN_KEY_MOVES, bevorzugt hinten.
func _place_key(rng: RandomNumberGenerator) -> bool:
	var office_section: String = rooms[office]["section"]
	var lift_section: String = elevator["section"]
	var from_lift := _distances("", false)
	var picks: Array[String] = []
	var back: Array[String] = []
	for room_id: String in rooms:
		if room_id == office or not from_lift.has(room_id):
			continue
		var sid: String = rooms[room_id]["section"]
		if sid == office_section or (sections.size() >= 4 and sid == lift_section):
			continue
		var to_office := int(_distances(room_id, true).get(office, -1))
		if to_office < 0 or int(from_lift[room_id]) + to_office < MIN_KEY_MOVES:
			continue
		picks.append(room_id)
		if bool(rooms[room_id]["back"]):
			back.append(room_id)
	if picks.is_empty():
		return false
	var pool := back if not back.is_empty() else picks
	key_room = pool[rng.randi_range(0, pool.size() - 1)]
	rooms[key_room]["has_key"] = true
	return true

## Schritt 9 und Tür-Stufen: Themen, Boni, Namen, Stufen, freie Türen, Boss-Konditionen.
func _dress(rng: RandomNumberGenerator, offerable: Callable, treat_chance: float,
		boss_ids: Array[String]) -> void:
	var picks: Array = []
	for attempt in THEME_ATTEMPTS:
		picks = _assign_themes(rng, offerable, true)
		if not picks.is_empty():
			break
	if picks.is_empty():
		picks = _assign_themes(rng, offerable, false)
	var theme_count: Dictionary = {}
	for pick: Array in picks:
		var room_id: String = pick[0]
		var theme_id: String = pick[1]
		var seen := int(theme_count.get(theme_id, 0))
		theme_count[theme_id] = seen + 1
		var info := theme_info(theme_id)
		rooms[room_id]["theme"] = theme_id
		rooms[room_id]["name"] = String(info["name"] if seen == 0 else info["alt"])
		rooms[room_id]["bonus"] = pick[2]
	var boss_at := 0
	for entry in doors:
		match String(entry["kind"]):
			DOOR_BOSS:
				entry["tier"] = TIER_BOSS
				entry["boss"] = boss_ids[boss_at] if boss_at < boss_ids.size() else ""
				entry["scouted"] = true
				boss_at += 1
			DOOR_ROOM, DOOR_LINK:
				var high := int(rooms[entry["a"]]["tier"])
				if entry["kind"] == DOOR_LINK:
					high = maxi(high, int(rooms[entry["b"]]["tier"]))
				entry["tier"] = high if rng.randf() < DOOR_HIGH_CHANCE else maxi(1, high - 1)
	for i in FREE_DOOR_THROWS:
		if rng.randf() >= treat_chance:
			continue
		var open: Array[Dictionary] = []
		for entry in doors:
			if (entry["kind"] == DOOR_ROOM or entry["kind"] == DOOR_LINK) and not bool(entry["free"]):
				open.append(entry)
		if not open.is_empty():
			var entry: Dictionary = open[rng.randi_range(0, open.size() - 1)]
			entry["free"] = true
			entry["tier"] = TIER_FREE

## Je Raum [Raum-Id, Thema, Klausel], der am engsten gebundene Raum zuerst. Mit limit hält
## jeder Raum den Themen-Deckel ([] = so nicht lösbar); ohne darf er zur Not brechen.
func _assign_themes(rng: RandomNumberGenerator, offerable: Callable, limit: bool) -> Array:
	var open := room_ids()
	_shuffle(open, rng)
	var used: Array[String] = []
	var theme_count: Dictionary = {}
	var picks: Array = []
	while not open.is_empty():
		var best := ""
		var best_options: Dictionary = {}
		for room_id in open:
			var tier := int(rooms[room_id]["tier"])
			var options := _theme_options(tier, used, theme_count, offerable, true, true)
			if options.is_empty():
				options = _theme_options(tier, used, theme_count, offerable, true, false)
			if best == "" or options.size() < best_options.size():
				best = room_id
				best_options = options
		if best_options.is_empty():
			if limit:
				return []
			best_options = _theme_options(int(rooms[best]["tier"]), used, theme_count, offerable, false, false)
		open.erase(best)
		var theme_id := THEME_LOUNGE
		var clause_id := ""
		if not best_options.is_empty():
			var themes: Array = best_options.keys()
			theme_id = themes[rng.randi_range(0, themes.size() - 1)]
			var free: Array[String] = best_options[theme_id]
			clause_id = free[rng.randi_range(0, free.size() - 1)]
			used.append(clause_id)
		theme_count[theme_id] = int(theme_count.get(theme_id, 0)) + 1
		picks.append([best, theme_id, clause_id])
	return picks

## Thema → freie Klauseln dieser Stufe, unter Deckel und Auslage-Sperre nach Wunsch.
func _theme_options(tier: int, used: Array[String], theme_count: Dictionary, offerable: Callable,
		limit: bool, ask_offer: bool) -> Dictionary:
	var options: Dictionary = {}
	for entry: Dictionary in THEMES:
		var theme_id: String = entry["id"]
		if limit and int(theme_count.get(theme_id, 0)) >= THEME_LIMIT:
			continue
		var free: Array[String] = []
		for clause_id in clauses_of(theme_id, tier):
			if used.has(clause_id):
				continue
			if ask_offer and offerable.is_valid() and not offerable.call(clause_id):
				continue
			free.append(clause_id)
		if not free.is_empty():
			options[theme_id] = free
	return options

# --- Abfragen -------------------------------------------------------------------

func room(room_id: String) -> Dictionary:
	return rooms.get(room_id, {})

func door(door_id: String) -> Dictionary:
	for entry in doors:
		if entry["id"] == door_id:
			return entry
	return {}

func section(section_id: String) -> Dictionary:
	for info in sections:
		if info["id"] == section_id:
			return info
	return {}

static func is_section(owner: String) -> bool:
	return owner.begins_with(SECTION_PREFIX)

## Alle Räume ohne das Büro, in Erzeugungs-Reihenfolge.
func room_ids() -> Array[String]:
	var ids: Array[String] = []
	for room_id: String in rooms:
		if room_id != office:
			ids.append(room_id)
	return ids

func doors_of(room_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in doors:
		if entry["kind"] != DOOR_FIRE and (entry["a"] == room_id or entry["b"] == room_id):
			found.append(entry)
	return found

## Die Abschnitte, an denen der Standort eine Flurtür hat; der Aufzug hat seinen.
func own_sections(standpoint: String) -> Array[String]:
	var found: Array[String] = []
	if standpoint == "":
		if not elevator.is_empty():
			found.append(String(elevator["section"]))
		return found
	for entry in doors:
		if entry["a"] == standpoint and entry["section"] != "" and not found.has(entry["section"]):
			found.append(String(entry["section"]))
	return found

## Die Züge von einem Standort: (a) Räume am eigenen Abschnitt, (b) Verbindungstür-Nachbarn,
## (c) Räume am Nachbar-Abschnitt hinter genau EINER Brandschutztür. Das Büro nur mit Karte.
func moves_from(standpoint: String, with_key: bool) -> Array[Dictionary]:
	var own := own_sections(standpoint)
	var found: Array[Dictionary] = []
	var seen: Dictionary = {}
	for entry in doors:
		var kind: String = entry["kind"]
		if kind == DOOR_FIRE:
			continue
		var on: String = entry["section"]
		if on != "":
			if own.has(on):
				_offer_move(found, seen, standpoint, entry["a"], entry, "", on, on, with_key)
		elif entry["a"] == standpoint:
			_offer_move(found, seen, standpoint, entry["b"], entry, "", "", "", with_key)
		elif entry["b"] == standpoint:
			_offer_move(found, seen, standpoint, entry["a"], entry, "", "", "", with_key)
	for sid in own:
		for fire in doors:
			if fire["kind"] != DOOR_FIRE or (fire["a"] != sid and fire["b"] != sid):
				continue
			var beyond: String = fire["b"] if fire["a"] == sid else fire["a"]
			if own.has(beyond):
				continue
			for entry in doors:
				if entry["kind"] != DOOR_FIRE and entry["section"] == beyond:
					_offer_move(found, seen, standpoint, entry["a"], entry, fire["id"], sid, beyond, with_key)
	return found

func _offer_move(found: Array[Dictionary], seen: Dictionary, standpoint: String, target: String,
		entry: Dictionary, fire_id: String, from_section: String, to_section: String, with_key: bool) -> void:
	if target == standpoint or not rooms.has(target) or seen.has(entry["id"]):
		return
	if (target == office or entry["kind"] == DOOR_BOSS) and not with_key:
		return
	seen[entry["id"]] = true
	found.append({"room": target, "door": entry["id"], "fire_door": fire_id,
		"section_from": from_section, "section_to": to_section})

## Die gangbaren Züge von jetzt.
func reachable_moves() -> Array[Dictionary]:
	return moves_from(position, key_taken)

## Die gangbaren Zielräume von jetzt, ohne Doppel.
func reachable_rooms() -> Array[String]:
	var found: Array[String] = []
	for move in reachable_moves():
		if not found.has(move["room"]):
			found.append(String(move["room"]))
	return found

## Kosten-Rang eines Zugs: ausgebrannt vor offen vor niedriger Stufe, ohne Brandschutztür vor mit.
func move_rank(move: Dictionary) -> int:
	var entry := door(String(move["door"]))
	var cost := 0 if bool(entry.get("passed", false)) else 1 + int(entry.get("tier", 0))
	return cost * 2 + (1 if String(move["fire_door"]) != "" else 0)

## Der billigste gangbare Zug in einen Raum ({} = keiner).
func cheapest_move(room_id: String) -> Dictionary:
	var best: Dictionary = {}
	for move in reachable_moves():
		if move["room"] != room_id:
			continue
		if best.is_empty() or move_rank(move) < move_rank(best):
			best = move
	return best

## Züge von from zu jedem Raum (Breitensuche über die Zug-Regel).
func _distances(from: String, with_key: bool) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array[String] = [from]
	var steps := {from: 0}
	while not queue.is_empty():
		var here: String = queue.pop_front()
		for move in moves_from(here, with_key):
			var target: String = move["room"]
			if not steps.has(target):
				steps[target] = int(steps[here]) + 1
				dist[target] = steps[target]
				queue.append(target)
	return dist

## Kürzeste Züge von from nach to (−1 = unerreichbar); "" ist der Aufzug.
func shortest_moves(from: String, to: String, with_key: bool) -> int:
	if from == to:
		return 0
	return int(_distances(from, with_key).get(to, -1))

## Aufzug → Schlüsselkarte → Büro in Zügen.
func key_route_moves() -> int:
	var to_key := shortest_moves("", key_room, false)
	var to_office := shortest_moves(key_room, office, true)
	return -1 if to_key < 0 or to_office < 0 else to_key + to_office

## Abschnitts-Abstand über Brandschutztüren.
func _section_distances(from: String) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[String] = [from]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		for other: String in section(here)["neighbors"]:
			if not dist.has(other):
				dist[other] = int(dist[here]) + 1
				queue.append(other)
	return dist

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

func side_corridor_count() -> int:
	var count := 0
	for info in sections:
		if bool(info["side"]):
			count += 1
		else:
			count += (info["rects"] as Array).size() - 1
	return count

func back_room_count() -> int:
	var count := 0
	for room_id in room_ids():
		if bool(rooms[room_id]["back"]):
			count += 1
	return count

# --- Zug und Erkunden -----------------------------------------------------------

## Erkundet die Türen aller gangbaren Züge: ihr Malus fällt JETZT, mit dem Zustand von jetzt.
func scout(rng: RandomNumberGenerator, offerable: Callable) -> void:
	for move in reachable_moves():
		var entry := door(String(move["door"]))
		if not bool(entry["scouted"]):
			scout_door(entry, rng, offerable)

## Malus aus dem Topf der Tür-Stufe: kein Tag mit dem Bonus der Räume an ihr, keine Klausel
## doppelt auf der Etage. Läuft der Topf leer, wird die Tür frei.
func scout_door(entry: Dictionary, rng: RandomNumberGenerator, offerable: Callable) -> void:
	entry["scouted"] = true
	var kind: String = entry["kind"]
	if bool(entry["free"]) or (kind != DOOR_ROOM and kind != DOOR_LINK):
		return
	var taboo: Array[String] = []
	taboo.append_array(DealClause.tags_of(String(rooms[entry["a"]]["bonus"])))
	if kind == DOOR_LINK:
		taboo.append_array(DealClause.tags_of(String(rooms[entry["b"]]["bonus"])))
	var pool := DealClause.ids_for(clause_tier(int(entry["tier"])), DealClause.Kind.MALUS)
	var used := floor_clause_ids()
	var fits: Array[String] = []
	for clause_id in pool:
		if used.has(clause_id) or _shares_tag(clause_id, taboo):
			continue
		if offerable.is_valid() and not offerable.call(clause_id):
			continue
		fits.append(clause_id)
	if fits.is_empty():
		entry["free"] = true
		entry["tier"] = TIER_FREE
		return
	var pick := rng.randi_range(0, fits.size() - 1) if rng != null else randi_range(0, fits.size() - 1)
	entry["malus"] = fits[pick]

static func _shares_tag(clause_id: String, taboo: Array[String]) -> bool:
	for tag in DealClause.tags_of(clause_id):
		if taboo.has(tag):
			return true
	return false

## Führt einen gangbaren Zug aus und schreibt NUR den Etagen-Zustand. Liefert, was er auslöst:
## {bonus, malus, boss, tolls, took_key} ({} = der Zug ist nicht gangbar).
func apply_move(move: Dictionary) -> Dictionary:
	var chosen: Dictionary = {}
	for option in reachable_moves():
		if option["door"] == move.get("door", "") and option["fire_door"] == move.get("fire_door", ""):
			chosen = option
			break
	if chosen.is_empty():
		return {}
	var entry := door(String(chosen["door"]))
	var target: String = chosen["room"]
	var info: Dictionary = rooms[target]
	var result := {"bonus": "", "malus": "", "boss": "", "tolls": 0, "took_key": false}
	if not bool(entry["passed"]):
		result["malus"] = entry["malus"]
	if entry["kind"] == DOOR_BOSS:
		result["boss"] = entry["boss"]
	if not bool(info["visited"]):
		result["bonus"] = info["bonus"]
	if String(chosen["fire_door"]) != "":
		result["tolls"] = 1
		door(String(chosen["fire_door"]))["passed"] = true
	if bool(info["has_key"]) and not key_taken:
		key_taken = true
		result["took_key"] = true
	entry["passed"] = true
	info["visited"] = true
	trail.append({"from": position, "to": target, "door": chosen["door"], "fire_door": chosen["fire_door"],
		"section_from": chosen["section_from"], "section_to": chosen["section_to"]})
	position = target
	return result

# --- Geometrie ------------------------------------------------------------------

## Mitte einer Tür in Zellkoordinaten (die Mitte der Wandkante).
static func door_center(entry: Dictionary) -> Vector2:
	return Vector2(entry["cell"]) + Vector2(0.5, 0.5) + Vector2(entry["side"]) * 0.5

## Liegt die Wand der Tür senkrecht (Tür zwischen links und rechts)?
static func door_vertical(entry: Dictionary) -> bool:
	return (entry["side"] as Vector2i).x != 0

## Kante zwischen zwei Zellen, normiert auf rechts/unten.
static func _edge_key(cell: Vector2i, side: Vector2i) -> String:
	if side.x < 0 or side.y < 0:
		cell += side
		side = -side
	return "%d,%d,%d,%d" % [cell.x, cell.y, side.x, side.y]

## Die Wände als zusammengefaßte Strecken in Zellkoordinaten {a, b, outer}. Türen lassen
## eine Lücke vom Anteil door_gap ihrer Kante; zwischen zwei Flurzellen steht keine Wand.
func wall_segments(door_gap: float = 0.6) -> Array[Dictionary]:
	var gaps: Dictionary = {}
	for entry in doors:
		if entry["kind"] != DOOR_FIRE:
			gaps[_edge_key(entry["cell"], entry["side"])] = true
	if not elevator.is_empty():
		gaps[_edge_key(elevator["cell"], elevator["side"])] = true
	var pieces: Array[Dictionary] = []
	for cell: Vector2i in cells:
		var owner: String = cells[cell]
		for side: Vector2i in SIDES:
			var other: String = cells.get(cell + side, "")
			if other == owner:
				continue
			if other != "" and (side.x < 0 or side.y < 0):
				continue
			if is_section(owner) and is_section(other):
				continue
			var a := Vector2(cell)
			var b := Vector2(cell)
			if side == Vector2i(1, 0):
				a += Vector2(1, 0)
				b += Vector2(1, 1)
			elif side == Vector2i(-1, 0):
				b += Vector2(0, 1)
			elif side == Vector2i(0, 1):
				a += Vector2(0, 1)
				b += Vector2(1, 1)
			else:
				b += Vector2(1, 0)
			var outer := other == ""
			if gaps.has(_edge_key(cell, side)):
				var rest := (1.0 - door_gap) * 0.5
				pieces.append({"a": a, "b": a.lerp(b, rest), "outer": outer})
				pieces.append({"a": b.lerp(a, rest), "b": b, "outer": outer})
			else:
				pieces.append({"a": a, "b": b, "outer": outer})
	return _merge_segments(pieces)

## Fügt kollineare, sich berührende Stücke gleicher Art zusammen.
static func _merge_segments(pieces: Array[Dictionary]) -> Array[Dictionary]:
	var lines: Dictionary = {}
	for piece in pieces:
		var a: Vector2 = piece["a"]
		var b: Vector2 = piece["b"]
		var horizontal := is_equal_approx(a.y, b.y)
		if (horizontal and a.x > b.x) or (not horizontal and a.y > b.y):
			var keep := a
			a = b
			b = keep
		var key := "%s|%s|%s" % [horizontal, a.y if horizontal else a.x, piece["outer"]]
		if not lines.has(key):
			lines[key] = []
		lines[key].append([a, b, horizontal, piece["outer"]])
	var merged: Array[Dictionary] = []
	for key: String in lines:
		var runs: Array = lines[key]
		var horizontal: bool = runs[0][2]
		runs.sort_custom(func(p: Array, q: Array) -> bool:
			return (p[0] as Vector2).x < (q[0] as Vector2).x if horizontal else (p[0] as Vector2).y < (q[0] as Vector2).y)
		var start: Vector2 = runs[0][0]
		var end: Vector2 = runs[0][1]
		for i in range(1, runs.size()):
			var next_a: Vector2 = runs[i][0]
			if next_a.distance_to(end) < 0.001:
				end = runs[i][1]
			else:
				merged.append({"a": start, "b": end, "outer": runs[0][3]})
				start = next_a
				end = runs[i][1]
		merged.append({"a": start, "b": end, "outer": runs[0][3]})
	return merged

# --- Ansicht und Geschichte -----------------------------------------------------

## Der Endzustand als reine Werte für die Turm-Geschichte: die Zeichnung ohne Züge.
func snapshot() -> Dictionary:
	var view := view_state()
	view["moves"] = [] as Array[Dictionary]
	for info: Dictionary in view["rooms"]:
		info["reachable"] = false
	for entry: Dictionary in view["doors"]:
		entry["reachable"] = false
	return view

## Alles für die Zeichnung, als reine Werte. Ein Malus steht erst da, wenn erkundet.
func view_state() -> Dictionary:
	var moves := reachable_moves()
	var reach_rooms: Dictionary = {}
	var reach_doors: Dictionary = {}
	for move in moves:
		reach_rooms[move["room"]] = true
		reach_doors[move["door"]] = true
		if String(move["fire_door"]) != "":
			reach_doors[move["fire_door"]] = true
	var room_views: Array[Dictionary] = []
	for room_id: String in rooms:
		var info: Dictionary = rooms[room_id]
		var theme := theme_info(String(info["theme"]))
		var clause := DealClause.find(String(info["bonus"]))
		room_views.append({"id": room_id, "rect": info["rect"], "tier": info["tier"], "theme": info["theme"],
			"symbol": theme.get("symbol", ""), "color": theme_color(String(info["theme"])),
			"name": info["name"], "bonus": info["bonus"],
			"bonus_name": clause.display_name if clause != null else "",
			"visited": info["visited"], "has_key": bool(info["has_key"]) and not key_taken,
			"is_office": info["is_office"], "back": info["back"], "section": info["section"],
			"current": room_id == position, "reachable": reach_rooms.has(room_id)})
	var door_views: Array[Dictionary] = []
	for entry in doors:
		door_views.append({"id": entry["id"], "kind": entry["kind"], "a": entry["a"], "b": entry["b"],
			"section": entry["section"],
			"center": door_center(entry), "vertical": door_vertical(entry), "cell": entry["cell"],
			"side": entry["side"], "tier": entry["tier"], "free": entry["free"],
			"malus": entry["malus"] if bool(entry["scouted"]) else "", "scouted": entry["scouted"],
			"boss": entry["boss"], "passed": entry["passed"], "reachable": reach_doors.has(entry["id"])})
	var corridor_views: Array[Dictionary] = []
	for info in sections:
		corridor_views.append({"id": info["id"], "rects": (info["rects"] as Array).duplicate(),
			"side": info["side"], "neighbors": (info["neighbors"] as Array).duplicate()})
	var lift := elevator.duplicate(true)
	if not lift.is_empty():
		lift["center"] = Vector2(lift["cell"]) + Vector2(0.5, 0.5) + Vector2(lift["side"]) * 0.5
	return {"grid": GRID, "floor_index": floor_index, "outline": cells.keys(), "walls": wall_segments(),
		"corridors": corridor_views, "rooms": room_views, "doors": door_views, "elevator": lift,
		"office": office, "key_room": key_room, "key_taken": key_taken, "position": position,
		"moves": moves, "trail": trail.duplicate(true)}

# --- Zufall ---------------------------------------------------------------------

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var keep: Variant = items[i]
		items[i] = items[j]
		items[j] = keep
