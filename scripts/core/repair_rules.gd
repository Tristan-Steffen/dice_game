class_name RepairRules
extends RefCounted
## Die BREMSEN der LADESÄULE als reine Regel - was darf jetzt, und warum nicht.
## Kein Node, keine Buchung: sie liest GameRun und DieDefinition und antwortet.
## Die Säule (table/) fragt sie je Bild, GameRun bucht (check-then-spend); beide
## lesen dieselbe Wahrheit, also kann ein lebendes Bedienelement nie ins Leere
## greifen.

## Ohne Kunden: kein Bedienelement lebt.
const EMPTY_TEXT := "Wähle einen Würfel im Vorrat"
## Die Warnung vor der letzten Sprosse: wer auf 3 geht, spielt ums Durchbrennen.
const WARN_TOP := "Bei 3 brennt die nächste Zündung durch"

const BLOCK_LOCKED := "Wartungsvertrag - Bucht geschlossen"
const BLOCK_ROUND := "Runde läuft"
const BLOCK_ENERGY := "Nicht genug Energie"
const BLOCK_MONEY := "Nicht genug Geld"

## Steht die Säule überhaupt unter Strom? Bedienbarkeit wie die Werkstatt
## (enabled = not _dice_editing_locked()), plus die Sperre des Wartungsvertrags.
static func open(run: GameRun, enabled: bool) -> bool:
	return run != null and enabled and not run.repair_locked()

## Der Ladungs-Deckel dieses Laufs - der Kühlkörper senkt ihn (dieselbe Quelle,
## aus der GameRun.charge_die bucht).
static func charge_cap(run: GameRun) -> int:
	if run == null:
		return DieDefinition.CHARGE_MAX
	return int(run.charge_rule().get("cap", DieDefinition.CHARGE_MAX))

static func charge_live(run: GameRun, die: DieDefinition, enabled: bool) -> bool:
	if not open(run, enabled) or die == null or die.burned_out \
			or die.charge >= charge_cap(run):
		return false
	return run.energy >= GameRun.CHARGE_UP_ENERGY

static func drain_live(run: GameRun, die: DieDefinition, enabled: bool) -> bool:
	if not open(run, enabled) or die == null or die.burned_out or die.charge <= 0:
		return false
	return run.money >= GameRun.DRAIN_MONEY

static func repair_live(run: GameRun, die: DieDefinition, enabled: bool) -> bool:
	if not open(run, enabled) or die == null or not die.burned_out:
		return false
	var price := run.repair_price()
	if price.has("money"):
		return run.money >= int(price["money"])
	return run.energy >= int(price["energy"])

## WARUM gerade nichts geht ("" = keine Bremse). Genannt wird die erste
## geschlossene Bremse - erst die Sperren, dann das fehlende Guthaben; ein kalter,
## voller oder heiler Würfel ist keine Bremse, sein Hebel steht einfach grau.
static func blocker(run: GameRun, die: DieDefinition, enabled: bool) -> String:
	if run == null or die == null:
		return EMPTY_TEXT if run != null else ""
	if not enabled:
		return BLOCK_ROUND
	if run.repair_locked():
		return BLOCK_LOCKED
	if die.burned_out:
		var price := run.repair_price()
		if price.has("money"):
			return BLOCK_MONEY if run.money < int(price["money"]) else ""
		return BLOCK_ENERGY if run.energy < int(price["energy"]) else ""
	if die.charge > 0 and run.money < GameRun.DRAIN_MONEY:
		return BLOCK_MONEY
	if die.charge < charge_cap(run) and run.energy < GameRun.CHARGE_UP_ENERGY:
		return BLOCK_ENERGY
	return ""

## Steht der Kunde eine Sprosse vor dem Durchbrennen?
static func warns(run: GameRun, die: DieDefinition) -> bool:
	return die != null and not die.burned_out and die.charge == charge_cap(run) - 1

# --- Die Preise am Körper ----------------------------------------------------------
# EINE Quelle für jedes Schild: die Zahlen stehen in GameRun.

static func charge_price_text() -> String:
	return "%d ⚡" % GameRun.CHARGE_UP_ENERGY

static func drain_price_text() -> String:
	return "$%d" % GameRun.DRAIN_MONEY

## Mit Isolierband kostet die Reparatur Geld statt Energie.
static func repair_price_text(run: GameRun) -> String:
	var price := run.repair_price() if run != null else {"energy": GameRun.REPAIR_ENERGY}
	if price.has("money"):
		return "$%d" % int(price["money"])
	return "%d ⚡" % int(price["energy"])
