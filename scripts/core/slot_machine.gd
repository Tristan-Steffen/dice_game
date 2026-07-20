class_name SlotMachine
extends RefCounted
## Die Fumble-Automaten (Slot-Bank): drei Automaten (Stufe I–III) mit steigenden
## Einsätzen und Gewinnen. Reine Logik/Daten - die UI (SlotBankView) spiegelt den
## Zustand, GameRun bucht die Gewinne.
##
## Symbol-Wand: jeder Automat besitzt MACHINE_COLS=3 Spalten à ROWS=3 Symbole; alle
## drei gedreht ergeben eine 3×9-Wand. Symbole sind bloße Zeichen (kein Preis) -
## Gewinne entstehen erst durch REIHEN: 3+ gleiche Symbole waagerecht nebeneinander
## (Reihen dürfen Automaten-Grenzen überschreiten). Länger = überproportional mehr.
## Drei Fumbles nebeneinander in einer Reihe = Bust: der ganze Topf ist verloren.
##
## Jeder Dreh EINMAL je Automat. „Auszahlen" löst alle Reihen in Preise auf und
## setzt die Bank zurück. Der Topf ist NICHT gespeichert, sondern wird jederzeit aus
## der Wand neu berechnet (runs()) - so verlängert der nächste Dreh bestehende Reihen.

const MACHINE_COUNT := 3
const MACHINE_COLS := 3
const ROWS := 5
const TOTAL_COLS := MACHINE_COUNT * MACHINE_COLS  # 9
const MIN_RUN := 3          # ab so vielen gleichen nebeneinander zahlt eine Reihe
const BUST_RUN := 3         # so viele Fumbles nebeneinander beenden die Sitzung
const SPIN_PRICES := [8, 14, 24]
const MACHINE_NAMES := ["Kupfer", "Silber", "Gold"]

## Geld je Zelle nach Automat (Spalte/MACHINE_COLS): Kupfer/Silber/Gold. Der
## Reihenwert ist die Zellsumme × Längen-Bonus (siehe _length_bonus).
const MONEY_CELL := [1, 2, 3]

## Reihen-Richtungen: waagerecht, senkrecht, Diagonale ↘, Diagonale ↗.
const DIRECTIONS := [[1, 0], [0, 1], [1, 1], [1, -1]]

## Aktuelle Wand: TOTAL_COLS Spalten, jede leer (ungedreht) oder ROWS Symbol-Kinds
## (SlotPrize.Kind als Symbol-Enum). Spalte c gehört Automat c / MACHINE_COLS.
var cells: Array = []
var spun := [false, false, false]
var busted := false                  # drei Fumbles in einer Reihe haben gebustet
## Test-Override: <0 = Tabellen-Gewichte (Fumble inklusive). 0.0 = nie Fumble,
## 1.0 = jede Zelle Fumble. Dazwischen: Fumble-Wahrscheinlichkeit je Zelle.
var fumble_chance := -1.0
var _rng: RandomNumberGenerator

func _init() -> void:
	reset_session()

## Ob Automat machine noch drehbar ist (Sitzung offen, Automat frisch).
func can_spin(machine: int) -> bool:
	return not busted and machine >= 0 and machine < MACHINE_COUNT and not spun[machine]

## Alle Gewinn-Reihen der Wand (leer bei Bust) - waagerecht, senkrecht UND diagonal.
## Je Reihe ein Deskriptor mit kind, length, cells (globale [col,row]), direction,
## specs (Belohnungs-Vorlagen für SlotPrize.from_spec) und label (Anzeigetext).
func runs() -> Array:
	if busted:
		return []
	var out: Array = []
	for direction in DIRECTIONS:
		for seg in _line_segments(direction[0], direction[1]):
			if seg["kind"] != SlotPrize.Kind.FUMBLE and seg["cells"].size() >= MIN_RUN:
				out.append(_make_run(seg["kind"], seg["cells"], direction))
	return out

## Zellen [col,row], die zu einer Fumble-Reihe (Länge ≥ min_len) gehören - in allen
## Richtungen, für die Bedrohungs-/Bust-Hervorhebung der Anzeige.
func fumble_run_cells(min_len: int = 2) -> Array:
	var out: Array = []
	for direction in DIRECTIONS:
		for seg in _line_segments(direction[0], direction[1]):
			if seg["kind"] == SlotPrize.Kind.FUMBLE and seg["cells"].size() >= min_len:
				for cell in seg["cells"]:
					out.append(cell)
	return out

## Maximale Segmente gleicher Symbol-Art entlang einer Richtung (dc,dr): je Segment
## {kind, cells}. Nur besetzte Zellen; ein Segment beginnt, wo die vorige Zelle in
## der Richtung fehlt oder anders ist. Basis für Gewinn-, Fumble- und Bust-Prüfung.
func _line_segments(dc: int, dr: int) -> Array:
	var segs: Array = []
	for row in ROWS:
		for col in TOTAL_COLS:
			if not _has_col(col):
				continue
			var kind: int = cells[col][row]
			var pc := col - dc
			var pr := row - dr
			if _in_bounds(pc, pr) and _has_col(pc) and cells[pc][pr] == kind:
				continue  # kein Startpunkt - Vorgänger gehört zum selben Segment
			var seg_cells: Array = [[col, row]]
			var nc := col + dc
			var nr := row + dr
			while _in_bounds(nc, nr) and _has_col(nc) and cells[nc][nr] == kind:
				seg_cells.append([nc, nr])
				nc += dc
				nr += dr
			segs.append({"kind": kind, "cells": seg_cells})
	return segs

func _in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < TOTAL_COLS and row >= 0 and row < ROWS

## Zahl der Gewinn-Reihen (gated die Auszahlung).
func hit_count() -> int:
	return runs().size()

## Summiert alle Reihen-Belohnungen zu einer Gesamtausschüttung (für die Topf-
## Anzeige): {money:int, engravings:int, charms:Array[String]-Raritäten, dice:int}.
func pot_summary() -> Dictionary:
	var money := 0
	var engravings := 0
	var charms: Array = []
	var dice := 0
	for run in runs():
		for spec: Dictionary in run["specs"]:
			match String(spec["kind"]):
				"money": money += int(spec["amount"])
				"engraving": engravings += int(spec["count"])
				"charm": charms.append(String(spec["rarity"]))
				"die": dice += 1
	return {"money": money, "engravings": engravings, "charms": charms, "dice": dice}

## Dreht Automat machine: füllt seine MACHINE_COLS Spalten mit gewichteten Symbolen
## und prüft die Wand auf einen Bust (drei Fumbles nebeneinander). Liefert den
## gedrehten Block (Array von MACHINE_COLS Spalten à ROWS Kinds) für die
## Animation - oder [], wenn der Automat nicht drehbar war.
func spin(machine: int, rng: RandomNumberGenerator = null) -> Array:
	if not can_spin(machine):
		return []
	spun[machine] = true
	if rng == null:
		rng = _fallback_rng()
	var block: Array = []
	for lc in MACHINE_COLS:
		var col: Array = []
		for r in ROWS:
			col.append(_roll_cell(machine, rng))
		cells[machine * MACHINE_COLS + lc] = col
		block.append(col)
	_detect_bust()
	return block

## Setzt die Bank für eine frische Sitzung zurück (nach Auszahlung oder Bust).
func reset_session() -> void:
	cells = []
	for c in TOTAL_COLS:
		cells.append([])
	spun = [false, false, false]
	busted = false

# --- Reihen-Belohnung ----------------------------------------------------------

func _make_run(kind: int, run_cells: Array, direction: Array) -> Dictionary:
	var length := run_cells.size()
	var run_cols: Array = []
	for cell in run_cells:
		run_cols.append(cell[0])
	var specs := _run_specs(kind, length, run_cols)
	return {
		"kind": kind, "length": length, "cells": run_cells, "direction": direction,
		"start_col": run_cells[0][0], "specs": specs, "label": _run_label(kind, length, specs),
	}

## Belohnungs-Vorlage(n) einer Reihe (für SlotPrize.from_spec). Meist eine; eine
## lange Würfel-Reihe liefert zwei. Länge und überspannte Automaten bestimmen Wert
## und Rarität.
func _run_specs(kind: int, length: int, run_cols: Array) -> Array:
	match kind:
		SlotPrize.Kind.MONEY:
			var sum := 0.0
			for col in run_cols:
				sum += MONEY_CELL[col / MACHINE_COLS]
			return [{"kind": "money", "amount": int(round(sum * _length_bonus(length)))}]
		SlotPrize.Kind.ENGRAVING:
			return [{"kind": "engraving", "count": length - 1, "floor": _engraving_floor(run_cols)}]
		SlotPrize.Kind.CHARM:
			return [{"kind": "charm", "rarity": _charm_rarity(length)}]
		SlotPrize.Kind.DIE:
			var specs: Array = [{"kind": "die"}]
			if length >= 4:
				specs.append({"kind": "die"})
			return specs
	return []

## Längen-Bonus: superlinear, damit lange (spaltenübergreifende) Reihen zünden.
## Kürzeste zahlende Reihe ist jetzt 3 (MIN_RUN).
func _length_bonus(length: int) -> float:
	match length:
		3: return 1.0
		4: return 1.6
		5: return 2.4
		6: return 3.4
	return 3.4 + (length - 6) * 1.2

## Gravur-Untergrenze = höchster überspannter Automat (Kupfer→Common … Gold→Rare).
func _engraving_floor(run_cols: Array) -> int:
	var tier := 0
	for col in run_cols:
		tier = maxi(tier, col / MACHINE_COLS)
	match tier:
		0: return Engraving.Rarity.COMMON
		1: return Engraving.Rarity.UNCOMMON
	return Engraving.Rarity.RARE

## Charm-Rarität GENAU nach Reihenlänge (immer nur ein Charm; die Länge bestimmt die
## Rarität): 3→gewöhnlich, 4→ungewöhnlich, 5→selten, 6+→legendär.
func _charm_rarity(length: int) -> String:
	match length:
		3: return Charm.RARITY_COMMON
		4: return Charm.RARITY_UNCOMMON
		5: return Charm.RARITY_RARE
	return Charm.RARITY_LEGENDARY

func _run_label(kind: int, length: int, specs: Array) -> String:
	var sym := SlotPrize.symbol_for(kind)
	match kind:
		SlotPrize.Kind.MONEY:
			return "%s ×%d → $%d" % [sym, length, int(specs[0]["amount"])]
		SlotPrize.Kind.ENGRAVING:
			var n := int(specs[0]["count"])
			return "%s ×%d → %d Gravur%s" % [sym, length, n, "" if n == 1 else "en"]
		SlotPrize.Kind.CHARM:
			return "%s ×%d → Charm" % [sym, length]
		SlotPrize.Kind.DIE:
			var n := specs.size()
			return "%s ×%d → %d Würfel" % [sym, length, n]
	return "%s ×%d" % [sym, length]

# --- Wurf / Bust ---------------------------------------------------------------

func _has_col(c: int) -> bool:
	return not cells[c].is_empty()

## Bust, sobald BUST_RUN Fumbles in einer Richtung (waagerecht/senkrecht/diagonal)
## nebeneinander liegen.
func _detect_bust() -> void:
	if fumble_run_cells(BUST_RUN).size() > 0:
		busted = true

func _roll_cell(machine: int, rng: RandomNumberGenerator) -> int:
	if fumble_chance >= 0.0:
		if rng.randf() < fumble_chance:
			return SlotPrize.Kind.FUMBLE
		return _roll_symbol(machine, rng, true)
	return _roll_symbol(machine, rng, false)

## Gewichtete Symbol-Auswahl aus dem Tisch des Automaten (ohne Fumble, wenn skip).
func _roll_symbol(machine: int, rng: RandomNumberGenerator, skip_fumble: bool) -> int:
	var table := _symbol_table(machine)
	var total := 0.0
	for entry in table:
		if skip_fumble and entry[0] == SlotPrize.Kind.FUMBLE:
			continue
		total += float(entry[1])
	var pick := rng.randf() * total
	for entry in table:
		if skip_fumble and entry[0] == SlotPrize.Kind.FUMBLE:
			continue
		pick -= float(entry[1])
		if pick <= 0.0:
			return entry[0]
	return SlotPrize.Kind.MONEY

## Symbol-Gewichte je Automat als [kind, weight]. Höhere Automaten: seltenere
## Symbole (Charm/Würfel). Fumble überall ähnlich häufig.
func _symbol_table(machine: int) -> Array:
	match machine:
		0: return [[SlotPrize.Kind.MONEY, 7], [SlotPrize.Kind.ENGRAVING, 6], [SlotPrize.Kind.FUMBLE, 3]]
		1: return [[SlotPrize.Kind.MONEY, 7], [SlotPrize.Kind.ENGRAVING, 6],
			[SlotPrize.Kind.CHARM, 2], [SlotPrize.Kind.FUMBLE, 3]]
	return [[SlotPrize.Kind.MONEY, 6], [SlotPrize.Kind.ENGRAVING, 6],
		[SlotPrize.Kind.CHARM, 3], [SlotPrize.Kind.DIE, 2], [SlotPrize.Kind.FUMBLE, 3]]

func _fallback_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng
