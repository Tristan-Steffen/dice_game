class_name RoundEvent
extends Resource
## Datensatz eines Runden-Ereignisses: 1-2 Stationen je Fahrplan-Block tragen
## eines (GameRun.roll_block_events), immer als Chance, nie als Strafe - die
## Bedrohung bleibt allein beim Stresstest. Wirkung lösen GameRun-Abfragen
## über die id auf (round_payout_factor, side_bet_payout_factor, Rampenlicht).

# --- Ereignis-ids (Single Source of Truth) ---
const HAPPY_HOUR := "happy_hour"            # Rundenauszahlung ×2
const POWER_SPIKE := "power_spike"          # Gratis-Rampenlicht ohne Charm
const TOURNAMENT_NIGHT := "tournament_night"  # Nebenwetten zahlen ×2

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## Ankündigungsfarbe: Punkt an der Fahrplan-Station, ehe die Runde beginnt.
@export var color: Color = Color.WHITE

static func _make(event_id: String, name: String, desc: String, tint: Color) -> RoundEvent:
	var event := RoundEvent.new()
	event.id = event_id
	event.display_name = name
	event.description = desc
	event.color = tint
	return event

static func happy_hour() -> RoundEvent:
	return _make(HAPPY_HOUR, "Happy Hour",
		"Die Rundenauszahlung zählt doppelt.", Color("#ffd319"))

static func power_spike() -> RoundEvent:
	return _make(POWER_SPIKE, "Spannungsspitze",
		"Eine zufällige Kombination steht im Rampenlicht.", Color("#8be9fd"))

static func tournament_night() -> RoundEvent:
	return _make(TOURNAMENT_NIGHT, "Turniernacht",
		"Gewonnene Nebenwetten zahlen doppelt.", Color("#ff79c6"))

static func all() -> Array[RoundEvent]:
	return [happy_hour(), power_spike(), tournament_night()]

static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for event in all():
		ids.append(event.id)
	return ids

static func find(event_id: String) -> RoundEvent:
	for event in all():
		if event.id == event_id:
			return event
	return null
