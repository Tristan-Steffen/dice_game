class_name SlotMachine
extends RefCounted
## Die Fumble-Automaten (Slot-Bank): drei Automaten (Stufe I–III) mit steigenden
## Gewinnen. Reine Logik/Daten - die UI (SlotBankView) spiegelt den Zustand,
## GameRun bucht die Gewinne.
##
## Symbole sind Ware und Energie: die drei Gravur-Sorten (Zahlen/Material/
## Würfel-Gravur - dieselbe Dreiteilung wie Pakete und Schubladen), ⚡, der JOKER
## (★, mischt sich in jede Sorte) und Fumble.
## Eine Gravur-Reihe zahlt versiegelte PAKETE, keine einzelnen Gravuren.
## Geld gibt es hier nicht: der Automat setzt Energie in Ware und Energie um.
##
## Symbol-Wand: jeder Automat besitzt MACHINE_COLS=3 Spalten à ROWS=4 Symbole; alle
## drei gedreht ergeben eine 4×9-Wand. Symbole sind bloße Zeichen (kein Preis) -
## Gewinne entstehen erst durch REIHEN: 3+ gleiche Symbole waagerecht nebeneinander
## (Reihen dürfen Automaten-Grenzen überschreiten). Länger = mehr UND größere
## Pakete (PACK_LADDER) - der Automat ist neben dem Laden die zweite Größenquelle.
## Drei Fumbles nebeneinander in einer Reihe = Bust: der ganze Topf ist verloren.
##
## Jeder Dreh EINMAL je Automat. „Auszahlen" löst alle Reihen in Preise auf und
## setzt die Bank zurück. Der Topf ist NICHT gespeichert, sondern wird jederzeit aus
## der Wand neu berechnet (runs()) - so verlängert der nächste Dreh bestehende Reihen.

const MACHINE_COUNT := 3
const MACHINE_COLS := 3
const ROWS := 4
const TOTAL_COLS := MACHINE_COUNT * MACHINE_COLS  # 9
const MIN_RUN := 3          # ab so vielen gleichen nebeneinander zahlt eine Reihe
const BUST_RUN := 3         # so viele Fumbles nebeneinander beenden die Sitzung
## Einsatz je Dreh in ⚡ - für alle drei Automaten gleich: die Stufe entscheidet
## über den Gewinn, nicht über den Preis.
const SPIN_ENERGYS := [1, 1, 1]
const MACHINE_NAMES := ["Kupfer", "Silber", "Gold"]
## Die vier auszahlenden Sorten - der Joker gehört NICHT dazu (er zahlt nie allein).
const PAYOUT_KINDS := [SlotPrize.Kind.ENGRAVING, SlotPrize.Kind.MATERIAL,
	SlotPrize.Kind.DICE_ENGRAVING, SlotPrize.Kind.ENERGY]

## Reihen-Richtungen: waagerecht, senkrecht, Diagonale ↘, Diagonale ↗.
const DIRECTIONS := [[1, 0], [0, 1], [1, 1], [1, -1]]

## DIE AUSZAHLUNGSLEITER einer Gravur-Reihe: die LÄNGE entscheidet Menge UND
## Paketgröße - 3→1 Standard, 4→1 Groß, 5→1 Kolossal, und ab da hebt jede weitere
## Länge um EIN Kolossal (6→2, 7→3, … 9→5). Sie gilt für alle drei Gravur-Sorten
## GLEICH: die Sortenschere steckt schon in den Symbol-Gewichten (_symbol_table -
## viele Zahlen, kaum Würfel-Gravuren), eine seltene Reihe ist also von sich aus
## seltener; sie obendrein schlechter zu zahlen zählte die Knappheit doppelt.
## WELCHE Sorte fällt, sagt weiter das Symbol.
const PACK_LADDER := {
	3: {"count": 1, "tier": Pack.TIER_NORMAL},
	4: {"count": 1, "tier": Pack.TIER_GROSS},
}
## Ab hier läuft die Leiter kolossal weiter: 5→1, 6→2, … 9→5 (TOTAL_COLS ist die
## Decke). Abgeleitet statt ausgeschrieben - die Fortsetzung ist eine Regel.
const KOLOSSAL_FROM := 5

## DIE AUSZAHLUNGSLEITER einer ⚡-Reihe: 3→1, 4→2, 5→3, ab 6 fest ENERGY_MAX (4).
## Bewusst flach und bescheiden (Spieler-Entscheid) - ein Dreh kostet 1⚡, die
## Mindestreihe zahlt ihn also genau zurück.
const ENERGY_LADDER := {3: 1, 4: 2, 5: 3}
const ENERGY_MAX := 4

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

## Ob die Sitzung läuft (mindestens ein Automat gedreht). Ohne Gewinn und ohne
## Bust bleibt die Wand sonst stehen - die Anzeige braucht das für den Verwerfen-Knopf.
func any_spun() -> bool:
	return spun.has(true)

## Alle Gewinn-Reihen der Wand (leer bei Bust) - waagerecht, senkrecht UND diagonal.
## Je Reihe ein Deskriptor mit kind, length, cells (globale [col,row]), direction,
## specs (Belohnungs-Vorlagen für SlotPrize.from_spec) und label (Anzeigetext).
func runs() -> Array:
	if busted:
		return []
	var out: Array = []
	for direction in DIRECTIONS:
		for kind: int in PAYOUT_KINDS:
			for seg in _kind_segments(direction[0], direction[1], kind):
				if seg.size() >= MIN_RUN:
					out.append(_make_run(kind, seg, direction))
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

## Ob Zelle [col,row] zur Sorte kind zählt - der JOKER (★) zählt zu JEDER Sorte.
func _matches(col: int, row: int, kind: int) -> bool:
	if not _in_bounds(col, row) or not _has_col(col):
		return false
	var c: int = cells[col][row]
	return c == kind or c == SlotPrize.Kind.WILD

## Maximale {kind ODER Joker}-Segmente entlang (dc,dr) - ein Segment zählt nur, wenn
## es MINDESTENS EIN echtes kind trägt (reiner Joker-Streifen zahlt nicht). So
## verlängert und vervollständigt der Joker Reihen jeder Sorte, ohne selbst eine zu
## bilden. Ein Joker zwischen zwei Sorten gehört BEIDEN Suchen - er mischt mit allen.
func _kind_segments(dc: int, dr: int, kind: int) -> Array:
	var segs: Array = []
	for row in ROWS:
		for col in TOTAL_COLS:
			if not _matches(col, row, kind):
				continue
			if _matches(col - dc, row - dr, kind):
				continue  # kein Startpunkt - Vorgänger gehört zum selben Segment
			var seg_cells: Array = []
			var has_real := false
			var nc := col
			var nr := row
			while _matches(nc, nr, kind):
				seg_cells.append([nc, nr])
				if cells[nc][nr] == kind:
					has_real = true
				nc += dc
				nr += dr
			if has_real:
				segs.append(seg_cells)
	return segs

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
## Anzeige): je Gravur-Sorte die PAKETZAHL, dazu die Energie-Summe und Würfel.
## "packs" gliedert dieselben Pakete zusätzlich nach GRÖSSE - eine bloße Zahl
## verschwiege den ganzen Unterschied zwischen einer 4er- und einer 6er-Reihe.
func pot_summary() -> Dictionary:
	var counts := {SlotPrize.Kind.ENGRAVING: 0, SlotPrize.Kind.MATERIAL: 0, SlotPrize.Kind.DICE_ENGRAVING: 0}
	var tiers := {}       # Symbol → {Größe → Paketzahl}
	var energy := 0
	var dice := 0
	for run in runs():
		for spec: Dictionary in run["specs"]:
			match String(spec["kind"]):
				"pack":
					var symbol := int(spec["symbol"])
					var amount := int(spec["count"])
					var pack_tier := int(spec.get("tier", Pack.TIER_NORMAL))
					counts[symbol] += amount
					if not tiers.has(symbol):
						tiers[symbol] = {}
					tiers[symbol][pack_tier] = int(tiers[symbol].get(pack_tier, 0)) + amount
				"energy": energy += int(spec["amount"])
				"die": dice += 1
	return {
		"engravings": counts[SlotPrize.Kind.ENGRAVING],
		"materials": counts[SlotPrize.Kind.MATERIAL],
		"edges": counts[SlotPrize.Kind.DICE_ENGRAVING],
		"packs": _pack_lines(tiers),
		"energy": energy, "dice": dice,
	}

## Die Paketzeilen des Topfs, je Sorte und Größe eine: {symbol, tier, count}. Feste
## Reihenfolge (Sorte wie in der Legende, Größe aufsteigend) - eine Dictionary-
## Reihenfolge ließe die Anzeige zwischen zwei Drehs springen.
func _pack_lines(tiers: Dictionary) -> Array:
	var out: Array = []
	for symbol in [SlotPrize.Kind.ENGRAVING, SlotPrize.Kind.MATERIAL,
			SlotPrize.Kind.DICE_ENGRAVING]:
		var by_tier: Dictionary = tiers.get(symbol, {})
		for pack_tier in [Pack.TIER_NORMAL, Pack.TIER_GROSS, Pack.TIER_KOLOSSAL]:
			var amount := int(by_tier.get(pack_tier, 0))
			if amount > 0:
				out.append({"symbol": symbol, "tier": pack_tier, "count": amount})
	return out

## Würfelt den Block eines Automaten (MACHINE_COLS Spalten à ROWS Kinds), OHNE ihn
## auf die Wand zu schreiben - so kann die Anzeige den Block erst nach der Walzen-
## Animation committen (Topf/Bust erscheinen mit der Landung, nicht beim Einwurf).
## Markiert den Automaten sofort als gedreht (Einsatz bezahlt, kein zweiter Dreh);
## [] wenn nicht drehbar.
func roll(machine: int, rng: RandomNumberGenerator = null) -> Array:
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
		block.append(col)
	return block

## Schreibt einen gewürfelten Block auf die Wand und prüft auf Bust - erst hier
## erscheint das Ergebnis im Topf. Die Anzeige ruft das nach der Landung.
func commit(machine: int, block: Array) -> void:
	for lc in MACHINE_COLS:
		if lc < block.size():
			cells[machine * MACHINE_COLS + lc] = block[lc]
	_detect_bust()

## Dreht sofort: Wurf UND Commit in einem (für Tests/Direktnutzung). Liefert den
## gedrehten Block oder [], wenn der Automat nicht drehbar war.
func spin(machine: int, rng: RandomNumberGenerator = null) -> Array:
	var block := roll(machine, rng)
	if not block.is_empty():
		commit(machine, block)
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
	var specs := _run_specs(kind, length)
	return {
		"kind": kind, "length": length, "cells": run_cells, "direction": direction,
		"start_col": run_cells[0][0], "specs": specs, "label": _run_label(kind, length, specs),
	}

## Belohnungs-Vorlage(n) einer Reihe (für SlotPrize.from_spec). Meist eine; eine
## lange Würfel-Reihe liefert zwei. Die Länge bestimmt Menge UND Paketgröße - eine
## Rarität gibt es seit dem Werkstatt-Umbau nicht mehr, die Stärke kommt aus der Hand.
func _run_specs(kind: int, length: int) -> Array:
	match kind:
		SlotPrize.Kind.ENGRAVING, SlotPrize.Kind.MATERIAL, SlotPrize.Kind.DICE_ENGRAVING:
			var payout := pack_payout(length)
			return [{"kind": "pack", "symbol": kind, "count": int(payout["count"]),
				"tier": int(payout["tier"])}]
		SlotPrize.Kind.ENERGY:
			return [{"kind": "energy", "amount": energy_payout(length)}]
		SlotPrize.Kind.DIE:
			var specs: Array = [{"kind": "die"}]
			if length >= 4:
				specs.append({"kind": "die"})
			return specs
	return []

## Was eine Gravur-Reihe dieser Länge auswirft: {count, tier} aus der Leiter, ab
## KOLOSSAL_FROM abgeleitet. Kopie, weil ein const-Dictionary schreibgeschützt ist.
static func pack_payout(length: int) -> Dictionary:
	if length >= KOLOSSAL_FROM:
		return {"count": length - KOLOSSAL_FROM + 1, "tier": Pack.TIER_KOLOSSAL}
	return (PACK_LADDER.get(length, PACK_LADDER[MIN_RUN]) as Dictionary).duplicate()

## Was eine ⚡-Reihe dieser Länge auswirft - der EINE Lesezugriff auf die Leiter
## (Spiegel von pack_payout).
static func energy_payout(length: int) -> int:
	if length <= MIN_RUN:
		return int(ENERGY_LADDER[MIN_RUN])
	return int(ENERGY_LADDER.get(length, ENERGY_MAX))

func _run_label(kind: int, length: int, specs: Array) -> String:
	var sym := SlotPrize.symbol_for(kind)
	match kind:
		SlotPrize.Kind.ENGRAVING, SlotPrize.Kind.MATERIAL, SlotPrize.Kind.DICE_ENGRAVING:
			var n := int(specs[0]["count"])
			var pack_tier := int(specs[0].get("tier", Pack.TIER_NORMAL))
			return "%s ×%d → %d %s" % [sym, length, n,
				SlotPrize.pack_name_tiered(kind, n, pack_tier)]
		SlotPrize.Kind.ENERGY:
			return "%s ×%d → %d⚡" % [sym, length, int(specs[0]["amount"])]
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
	return SlotPrize.Kind.ENGRAVING

## Symbol-Gewichte [kind, weight] - ALLE drei Automaten teilen EINE Tabelle (die
## Tiers unterscheiden sich seit 2026-08-30 nur noch über die Zahl der Drehungen,
## nicht über den Mix), gefittet auf die gewünschte Topf-Verteilung ~55/20/15/10
## (Zahlen/Material/Runen/Energie; gemessen, weil Reihen sich aus Nachbarn
## bilden und Übergewicht sich verstärkt - die Gewichte sind darum flacher als die
## Zielquoten). Einen physischen Würfel wirft der Automat NICHT (Kind.DIE fehlt).
## Fumble steuert die Bust-Rate und bleibt außen vor.
const W_ZAHLEN := 5.7
const W_MATERIAL := 4.0
const W_GRAVUR := 3.6
const W_ENERGIE := 3.1
const W_FUMBLE := 2.2
## Der Joker ist SELTEN - er vervollständigt Reihen und zählt für alle Sorten, ein
## häufiger Joker verschöbe den Mix und machte fast jede Wand zum Gewinn.
const W_JOKER := 1.0

func _symbol_table(_machine: int) -> Array:
	return [[SlotPrize.Kind.ENGRAVING, W_ZAHLEN], [SlotPrize.Kind.MATERIAL, W_MATERIAL],
		[SlotPrize.Kind.DICE_ENGRAVING, W_GRAVUR], [SlotPrize.Kind.ENERGY, W_ENERGIE],
		[SlotPrize.Kind.WILD, W_JOKER], [SlotPrize.Kind.FUMBLE, W_FUMBLE]]

func _fallback_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng
