class_name Labor
extends RefCounted
## Das LABOR: EIN Auftrag zur Zeit an einer von vier Stationen. Reine Regeln und der
## Auftrag als Daten; gebucht wird in GameRun (start_labor_job, collect_labor).

const SEELE := "seele"
const CHARM := "charm"
const MODUL := "modul"
const KARTEN := "karten"
const STATIONS := [SEELE, CHARM, MODUL, KARTEN]

const NAMES := {
	SEELE: "Seelen-Transfer",
	CHARM: "Charm-Kopierer",
	MODUL: "Modul-Kopierer",
	KARTEN: "Karten-Presse",
}
const TEXTS := {
	SEELE: "Zwei Vorrats-Würfel: das Ziel bekommt die Seele der Quelle.",
	CHARM: "Ein Charm: er setzt aus und kommt mit einer Kopie zurück.",
	MODUL: "Ein gestecktes Modul: es setzt aus und kommt mit einer Kopie zurück.",
	KARTEN: "1 bis 6 Karten: je Karte eine neue derselben Sorte, mit +10 Glück.",
}

const PHASE_READY := "bereit"
const PHASE_RUNNING := "laeuft"
const PHASE_DONE := "fertig"

## Wartezeit = LABOR_ROUNDS − Augen des Glückswürfels; eine 6 ist sofort fertig.
const LABOR_ROUNDS := 6
const MAX_CARDS := 6
## Die Karten-Presse würfelt mit so viel Glück über dem wirkenden.
const CARD_LUCK := 10

var station: String = ""
## Der Einsatz in der Form, in der er gegeben wurde (siehe GameRun.start_labor_job).
var inputs: Dictionary = {}
var die_face: int = -1
var die_value: int = 0
var rounds_left: int = 0
var done: bool = false
## Die Dinge selbst - Referenzen, nie Indizes (Plätze dürfen rücken).
var dice: Array[DieDefinition] = []
var charm: Charm = null
var part: ComboPart = null
var packs: Array[Pack] = []

static func station_name(id: String) -> String:
	return String(NAMES.get(id, ""))

static func station_text(id: String) -> String:
	return String(TEXTS.get(id, ""))

static func wait_for(value: int) -> int:
	return clampi(LABOR_ROUNDS - value, 0, LABOR_ROUNDS)

## Eine zufällige Station, nie die aktuelle.
static func next_station(current: String, rng: RandomNumberGenerator = null) -> String:
	var pool: Array[String] = []
	for id: String in STATIONS:
		if id != current:
			pool.append(id)
	var at := rng.randi_range(0, pool.size() - 1) if rng != null else randi_range(0, pool.size() - 1)
	return pool[at]

static func make(id: String, given: Dictionary, face: int, value: int) -> Labor:
	var job := Labor.new()
	job.station = id
	job.inputs = given.duplicate(true)
	job.die_face = face
	job.die_value = value
	job.rounds_left = wait_for(value)
	job.done = job.rounds_left == 0
	return job

## Eine Runde vergeht; true = dadurch fertig geworden.
func tick() -> bool:
	if done:
		return false
	rounds_left = maxi(0, rounds_left - 1)
	done = rounds_left == 0
	return done

func phase() -> String:
	return PHASE_DONE if done else PHASE_RUNNING

## Nur der Datensatz; die Dinge bindet der Spielstand neu (es gibt noch keinen).
func to_dict() -> Dictionary:
	return {"station": station, "inputs": inputs.duplicate(true), "die_face": die_face,
		"die_value": die_value, "rounds_left": rounds_left, "done": done}

static func from_dict(data: Dictionary) -> Labor:
	var job := Labor.new()
	job.station = String(data.get("station", ""))
	job.inputs = (data.get("inputs", {}) as Dictionary).duplicate(true)
	job.die_face = int(data.get("die_face", -1))
	job.die_value = int(data.get("die_value", 0))
	job.rounds_left = int(data.get("rounds_left", 0))
	job.done = bool(data.get("done", false))
	return job
