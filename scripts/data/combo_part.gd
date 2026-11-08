class_name ComboPart
extends Resource
## Ein MODUL für einen Steckplatz eines Kombinations-Chips. Nur Anzeige-Daten
## und die Phase; die Wirkung löst ComboPartEffects über die id auf. Teile
## tragen Zustand (Zählwerk), darum wird jedes beim Erwerb instanziiert.

# --- Modul-ids (Single Source of Truth) ---
const RESISTOR := "resistor"
const CAPACITOR := "capacitor"
const COIL := "coil"
const RELAY := "relay"
const OUTPUT_STAGE := "output_stage"
const SOLDER_JOINT := "solder_joint"
const SERIES_RESISTOR := "series_resistor"
const THERMISTOR := "thermistor"
const AMPLIFIER_TUBE := "amplifier_tube"
const COUNTER := "counter"
const COIN_VALIDATOR := "coin_validator"
const HIGH_VOLTAGE_TUBE := "high_voltage_tube"
const COUPLING := "coupling"
const EXPANSION_BOARD := "expansion_board"
const SERIES_TERMINAL := "series_terminal"
const STARTER := "starter"
const BLOCKING_DIODE := "blocking_diode"
const POWER_PICKUP := "power_pickup"
const SHUNT := "shunt"
const PARALLEL_CIRCUIT := "parallel_circuit"
const RESONATOR := "resonator"
const MAGNETRON := "magnetron"
const CROSS_BRIDGE := "cross_bridge"
const DOWN_BRIDGE := "down_bridge"
const ERROR_MEMORY := "error_memory"
const AFTERBURNER := "afterburner"

## Wirk-Phasen: die Phase entscheidet, WANN ein Teil in der Wertung feuert.
const PHASE_COMBO := "kombi"
const PHASE_DIE := "wuerfel"
const PHASE_CRIT := "krit"
const PHASE_ECONOMY := "oekonomie"
const PHASE_LINK := "verbindung"
const PHASE_NONE := ""

const RARITY_COMMON := "common"
const RARITY_RARE := "rare"
const RARITY_EPIC := "epic"
const RARITY_LEGENDARY := "legendary"

const RARITIES := {
	RESISTOR: RARITY_COMMON,
	CAPACITOR: RARITY_COMMON,
	COIL: RARITY_COMMON,
	RELAY: RARITY_RARE,
	OUTPUT_STAGE: RARITY_RARE,
	SOLDER_JOINT: RARITY_RARE,
	SERIES_RESISTOR: RARITY_COMMON,
	THERMISTOR: RARITY_RARE,
	AMPLIFIER_TUBE: RARITY_EPIC,
	COUNTER: RARITY_EPIC,
	COIN_VALIDATOR: RARITY_COMMON,
	HIGH_VOLTAGE_TUBE: RARITY_LEGENDARY,
	COUPLING: RARITY_LEGENDARY,
	EXPANSION_BOARD: RARITY_LEGENDARY,
	SERIES_TERMINAL: RARITY_RARE,
	STARTER: RARITY_COMMON,
	BLOCKING_DIODE: RARITY_RARE,
	POWER_PICKUP: RARITY_RARE,
	SHUNT: RARITY_EPIC,
	PARALLEL_CIRCUIT: RARITY_LEGENDARY,
	RESONATOR: RARITY_EPIC,
	MAGNETRON: RARITY_LEGENDARY,
	CROSS_BRIDGE: RARITY_LEGENDARY,
	DOWN_BRIDGE: RARITY_LEGENDARY,
	ERROR_MEMORY: RARITY_RARE,
	AFTERBURNER: RARITY_EPIC,
}

const RARITY_WEIGHTS := {
	RARITY_COMMON: 1.0,
	RARITY_RARE: 0.45,
	RARITY_EPIC: 0.2,
	RARITY_LEGENDARY: 0.08,
}

const RARITY_NAMES := {
	RARITY_COMMON: "gewöhnlich",
	RARITY_RARE: "selten",
	RARITY_EPIC: "episch",
	RARITY_LEGENDARY: "legendär",
}

const RARITY_COLORS := {
	RARITY_COMMON: Color(0.85, 0.9, 1.0),
	RARITY_RARE: Color(0.25, 0.55, 1.0),
	RARITY_EPIC: Color(0.75, 0.35, 1.0),
	RARITY_LEGENDARY: Color(1.0, 0.75, 0.2),
}

## Körper-Tönung nach Phase: Kombi-Teile nach ihrem Beitrag (Punkte = Chip-Cyan,
## Mult = Chip-Gold), Würfel grün, Krit violett, Ökonomie geldgrün.
const POINTS_TINT := Color("#00ffff")
const MULT_TINT := Color("#ffd319")
const DIE_TINT := Color("#50fa7b")
const CRIT_TINT := Color(0.75, 0.35, 1.0)
const ECONOMY_TINT := Color("#9ccf6a")
const BOARD_TINT := Color(0.62, 0.66, 0.74)
## Die Kopplung trägt beides, was sie kopiert - ein blasses Silber-Cyan.
const COUPLING_TINT := Color(0.78, 0.94, 1.0)
const LINK_TINT := Color(1.0, 0.45, 0.85)

## Artikel im Dativ ("Wohin mit dem Relais?").
const DATIVES := {
	RESISTOR: "dem", CAPACITOR: "dem", COIL: "der", RELAY: "dem",
	OUTPUT_STAGE: "der", SOLDER_JOINT: "dem", SERIES_RESISTOR: "dem",
	THERMISTOR: "dem", AMPLIFIER_TUBE: "der", COUNTER: "dem",
	COIN_VALIDATOR: "dem", HIGH_VOLTAGE_TUBE: "der", COUPLING: "der",
	EXPANSION_BOARD: "der", SERIES_TERMINAL: "der", STARTER: "dem",
	BLOCKING_DIODE: "der", POWER_PICKUP: "dem", SHUNT: "dem",
	PARALLEL_CIRCUIT: "der", RESONATOR: "dem", MAGNETRON: "dem",
	CROSS_BRIDGE: "der", DOWN_BRIDGE: "der",
	ERROR_MEMORY: "dem", AFTERBURNER: "dem",
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: String = RARITY_COMMON
@export var phase: String = PHASE_COMBO
## Nur im Schwarzmarkt (gegen ⚡); alle ×-Teile gehören hierher.
@export var secret: bool = false
## Grundpreis in $; der Schwarzmarkt rechnet ihn über secret_energy_price um.
@export var price: int = 6
## Zählwerk: dauerhafter Zuwachs, reist beim Umstecken mit. Fehlerspeicher: die
## Block-Fumbles; Nachbrenner: 1 = scharf (ein Fumble ist gefallen).
@export var counter: int = 0

static func _make(part_id: String, name: String, desc: String, part_phase: String,
		base_price: int, is_secret: bool = false) -> ComboPart:
	var part := ComboPart.new()
	part.id = part_id
	part.display_name = name
	part.description = desc
	part.rarity = RARITIES.get(part_id, RARITY_COMMON)
	part.phase = part_phase
	part.price = base_price
	part.secret = is_secret
	return part

## Eigene Instanz - nie eine geteilte Referenz, das Zählwerk trägt Zustand.
func instantiate() -> ComboPart:
	return duplicate() as ComboPart

func rarity_weight() -> float:
	return RARITY_WEIGHTS.get(rarity, 1.0)

func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS[RARITY_COMMON])

func rarity_name() -> String:
	return RARITY_NAMES.get(rarity, rarity)

func tint() -> Color:
	match phase:
		PHASE_DIE:
			return DIE_TINT
		PHASE_CRIT:
			return CRIT_TINT
		PHASE_ECONOMY:
			return ECONOMY_TINT
		PHASE_NONE:
			return BOARD_TINT
		PHASE_LINK:
			return LINK_TINT
	if id == COUPLING or id == SERIES_TERMINAL:
		return COUPLING_TINT
	return POINTS_TINT if id == RESISTOR else MULT_TINT

## "dem Relais", "der Spule".
func with_dative() -> String:
	return "%s %s" % [DATIVES.get(id, "dem"), display_name]

# --- Katalog v1 ---

static func resistor() -> ComboPart:
	return _make(RESISTOR, "Widerstand", "+15 Punkte.", PHASE_COMBO, 6)

static func capacitor() -> ComboPart:
	return _make(CAPACITOR, "Kondensator", "+3 Mult.", PHASE_COMBO, 7)

static func coil() -> ComboPart:
	return _make(COIL, "Spule", "+8 Punkte und +1 Mult.", PHASE_COMBO, 7)

static func relay() -> ComboPart:
	return _make(RELAY, "Relais", "Der erste Würfel der Kombination löst 1× zusätzlich aus.", PHASE_DIE, 10)

static func output_stage() -> ComboPart:
	return _make(OUTPUT_STAGE, "Endstufe", "Der letzte Würfel der Kombination löst 1× zusätzlich aus.", PHASE_DIE, 10)

static func solder_joint() -> ComboPart:
	return _make(SOLDER_JOINT, "Lötpunkt", "Jeder Kombinationswürfel: +1 Mult je Auslösung.", PHASE_DIE, 10)

static func series_resistor() -> ComboPart:
	return _make(SERIES_RESISTOR, "Vorwiderstand", "Jeder Kombinationswürfel: +4 Punkte je Auslösung.", PHASE_DIE, 6)

static func thermistor() -> ComboPart:
	return _make(THERMISTOR, "Thermistor", "+2 Mult je Ladung der Kombinationswürfel, je Auslösung.", PHASE_DIE, 10)

static func amplifier_tube() -> ComboPart:
	return _make(AMPLIFIER_TUBE, "Verstärkerröhre", "×1,5 Mult.", PHASE_CRIT, 30, true)

static func counter_part() -> ComboPart:
	return _make(COUNTER, "Zählwerk", "+1 Mult, wächst dauerhaft um +1 bei jeder Wertung dieser Kombination.", PHASE_COMBO, 14)

static func coin_validator() -> ComboPart:
	return _make(COIN_VALIDATOR, "Münzprüfer", "+$2 je Wertung dieser Kombination.", PHASE_ECONOMY, 5)

static func high_voltage_tube() -> ComboPart:
	return _make(HIGH_VOLTAGE_TUBE, "Hochspannungsröhre", "×2 Mult.", PHASE_CRIT, 50, true)

static func coupling() -> ComboPart:
	return _make(COUPLING, "Kopplung", "Kopiert das stärkste Kombi-Modul des Chips links daneben.", PHASE_COMBO, 50, true)

static func expansion_board() -> ComboPart:
	return _make(EXPANSION_BOARD, "Erweiterungsplatine", "Belegt einen Steckplatz und gibt dem Chip zwei neue.", PHASE_NONE, 40, true)

static func series_terminal() -> ComboPart:
	return _make(SERIES_TERMINAL, "Reihenklemme", "+5 Punkte und +1 Mult je Modul auf diesem Chip.", PHASE_COMBO, 10)

static func starter() -> ComboPart:
	return _make(STARTER, "Anlasser", "+6 Mult in der ersten Hand der Runde.", PHASE_COMBO, 6)

static func blocking_diode() -> ComboPart:
	return _make(BLOCKING_DIODE, "Sperrdiode", "Dieser Chip kann nicht gedrosselt oder stillgelegt werden.", PHASE_NONE, 8)

static func power_pickup() -> ComboPart:
	return _make(POWER_PICKUP, "Stromabnehmer", "+1 ⚡ je Wertung dieser Kombination.", PHASE_ECONOMY, 12)

static func shunt() -> ComboPart:
	return _make(SHUNT, "Nebenschluss", "Auch Würfel außerhalb der Kombination werden gewertet.", PHASE_DIE, 14)

static func parallel_circuit() -> ComboPart:
	return _make(PARALLEL_CIRCUIT, "Parallelschaltung", "Jeder Kombinationswürfel löst 1× zusätzlich aus.", PHASE_DIE, 60, true)

static func resonator() -> ComboPart:
	return _make(RESONATOR, "Schwingkreis", "×1,1 Mult, wächst dauerhaft um ×0,1 bei jeder Wertung dieser Kombination.", PHASE_CRIT, 40, true)

static func magnetron() -> ComboPart:
	return _make(MAGNETRON, "Magnetron", "×3 Mult. Jede Wertung lädt alle Kombinationswürfel sicher um +1.", PHASE_CRIT, 60, true)

static func cross_bridge() -> ComboPart:
	return _make(CROSS_BRIDGE, "Querbrücke", "Aktiviert auch die Kombination rechts daneben samt ihrer Module.", PHASE_LINK, 60, true)

static func down_bridge() -> ComboPart:
	return _make(DOWN_BRIDGE, "Längsbrücke", "Aktiviert auch die Kombination darunter samt ihrer Module.", PHASE_LINK, 60, true)

static func error_memory() -> ComboPart:
	return _make(ERROR_MEMORY, "Fehlerspeicher", "+1 Mult je Fumble dieses Blocks.", PHASE_COMBO, 9)

static func afterburner() -> ComboPart:
	return _make(AFTERBURNER, "Nachbrenner", "×2 Mult in der ersten Hand dieser Kombination nach einem Fumble.", PHASE_CRIT, 40, true)

static func all() -> Array[ComboPart]:
	return [
		resistor(), capacitor(), coil(), relay(), output_stage(), solder_joint(),
		series_resistor(), thermistor(), amplifier_tube(), counter_part(),
		coin_validator(), high_voltage_tube(), coupling(), expansion_board(),
		series_terminal(), starter(), blocking_diode(), power_pickup(), shunt(),
		parallel_circuit(), resonator(), magnetron(), cross_bridge(), down_bridge(),
		error_memory(), afterburner(),
	]

## Frisches Exemplar zu einer id (null = unbekannt).
static func make(part_id: String) -> ComboPart:
	for part in all():
		if part.id == part_id:
			return part
	return null

## Ladenware (flach, $) bzw. Schwarzmarkt-Ware (vervielfachend, ⚡).
static func pool(secret_only: bool) -> Array[ComboPart]:
	var out: Array[ComboPart] = []
	for part in all():
		if part.secret == secret_only:
			out.append(part)
	return out

## Gewichteter Griff nach Rarität; candidates darf nicht leer sein.
static func pick_weighted(candidates: Array[ComboPart], rng: RandomNumberGenerator = null) -> ComboPart:
	var total := 0.0
	for part in candidates:
		total += part.rarity_weight()
	var roll := (rng.randf() if rng != null else randf()) * total
	for part in candidates:
		roll -= part.rarity_weight()
		if roll <= 0.0:
			return part
	return candidates.back()

## Ein Laden-Modul (nie ein Schwarzmarkt-Teil), frisch.
static func roll_shop(rng: RandomNumberGenerator = null) -> ComboPart:
	return pick_weighted(pool(false), rng)

## Ein Schwarzmarkt-Modul, frisch.
static func roll_secret(rng: RandomNumberGenerator = null) -> ComboPart:
	return pick_weighted(pool(true), rng)

## Kopie einer Steckplatz-Belegung (Key -> Array) mit eigenen Instanzen - für
## Schnappschüsse, die später nicht mitwachsen dürfen.
static func copy_layout(layout: Dictionary) -> Dictionary:
	var out := {}
	for key in layout:
		var sockets: Array = []
		for part in layout[key]:
			sockets.append((part as ComboPart).instantiate() if part != null else null)
		out[key] = sockets
	return out
