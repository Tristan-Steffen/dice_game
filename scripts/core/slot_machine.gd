class_name SlotMachine
extends RefCounted
## Die Fumble-Automaten (Slot-Bank): drei Automaten (Stufe I–III) mit steigenden
## Einsätzen und Gewinnen. Reine Logik/Daten - die UI (SlotBankView) spiegelt den
## Zustand, GameRun bucht die Gewinne.
##
## Push-your-luck: jeder Automat EINMAL je Sitzung drehbar, in beliebiger
## Reihenfolge. Mit FUMBLE_CHANCE landet das Namensgeber-Symbol „Fumble" - es
## löscht den GESAMTEN aufgelaufenen Gewinn und beendet die Sitzung. Sonst wandert
## der Gewinn in den Zwischenspeicher (pending). „Auszahlen" nimmt alles
## ×Trefferzahl (1 Treffer ×1, 2 ×2, 3 ×3) und setzt die Bank zurück.

const MACHINE_COUNT := 3
const FUMBLE_CHANCE := 0.35
const SPIN_PRICES := [4, 7, 12]
const MACHINE_NAMES := ["Kupfer", "Silber", "Gold"]

## Gewinn-Tische je Automat (0..2), gewichtete Vorlagen (siehe SlotPrize.from_spec).
## Höhere Automaten: mehr Geld, seltenere Sigille, Charms und ein Würfel.
const PRIZE_TABLES := [
	[  # I – Kupfer: kleines Geld, ein Sigill.
		{"weight": 4, "kind": "money", "amount": 5},
		{"weight": 2, "kind": "money", "amount": 8},
		{"weight": 3, "kind": "sigil", "count": 1, "floor": Sigil.Rarity.COMMON},
	],
	[  # II – Silber: mehr Geld, zwei Sigille, gelegentlich ein Charm.
		{"weight": 4, "kind": "money", "amount": 12},
		{"weight": 2, "kind": "money", "amount": 16},
		{"weight": 3, "kind": "sigil", "count": 2, "floor": Sigil.Rarity.UNCOMMON},
		{"weight": 1, "kind": "charm", "floor": Charm.RARITY_UNCOMMON},
	],
	[  # III – Gold: großes Geld, seltene Charms, ein Würfel.
		{"weight": 3, "kind": "money", "amount": 22},
		{"weight": 2, "kind": "money", "amount": 30},
		{"weight": 2, "kind": "sigil", "count": 3, "floor": Sigil.Rarity.RARE},
		{"weight": 2, "kind": "charm", "floor": Charm.RARITY_RARE},
		{"weight": 1, "kind": "die"},
	],
]

var pending: Array[SlotPrize] = []   # eingesammelte Treffer (in Dreh-Reihenfolge)
var spun := [false, false, false]
var busted := false                  # ein Fumble hat die Sitzung beendet
## Fumble-Wahrscheinlichkeit je Dreh (überschreibbar, v.a. für Tests).
var fumble_chance := FUMBLE_CHANCE
var _rng: RandomNumberGenerator

## Ob Automat machine noch drehbar ist (Sitzung offen, Automat frisch).
func can_spin(machine: int) -> bool:
	return not busted and machine >= 0 and machine < MACHINE_COUNT and not spun[machine]

## Zahl der bisherigen Treffer = Multiplikator-Basis.
func hit_count() -> int:
	return pending.size()

## Auszahlungs-Multiplikator: 1 Treffer ×1, 2 ×2, 3 ×3 (nie unter 1).
func multiplier() -> int:
	return maxi(1, pending.size())

## Dreht Automat machine (rng optional für deterministische Tests). Fumble löscht
## pending + beendet die Sitzung; sonst wandert der Preis in pending. Liefert den
## gelandeten Preis (oder null, wenn der Automat nicht drehbar war).
func spin(machine: int, rng: RandomNumberGenerator = null) -> SlotPrize:
	if not can_spin(machine):
		return null
	spun[machine] = true
	if rng == null:
		rng = _fallback_rng()
	if rng.randf() < fumble_chance:
		pending.clear()
		busted = true
		return SlotPrize.fumble()
	var prize := _roll_prize(machine, rng)
	pending.append(prize)
	return prize

## Setzt die Bank für eine frische Sitzung zurück (nach Auszahlung oder Fumble).
func reset_session() -> void:
	pending.clear()
	spun = [false, false, false]
	busted = false

## Gewichtete Auswahl einer Gewinn-Vorlage aus dem Tisch des Automaten.
func _roll_prize(machine: int, rng: RandomNumberGenerator) -> SlotPrize:
	var table: Array = PRIZE_TABLES[machine]
	var total := 0.0
	for entry in table:
		total += float(entry["weight"])
	var pick := rng.randf() * total
	var chosen: Dictionary = table[0]
	for entry in table:
		pick -= float(entry["weight"])
		if pick <= 0.0:
			chosen = entry
			break
	return SlotPrize.from_spec(chosen)

func _fallback_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng
