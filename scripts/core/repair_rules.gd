class_name RepairRules
extends RefCounted
## Die BREMSEN der SICHERUNGS-FASSUNG als reine Regel - darf jetzt repariert
## werden, und wenn nicht, warum nicht. Kein Node, keine Buchung: sie liest GameRun
## und DieDefinition und antwortet. Die Fassung (table/) fragt sie je Bild, GameRun
## bucht (check-then-spend); beide lesen dieselbe Wahrheit, also kann eine lebende
## Sicherung nie ins Leere greifen. Aufladen und Ableiten sind am 2026-09-10
## gestorben - die Fassung kennt nur noch die Reparatur.

## Ohne Kunden: die Sicherung lebt nicht.
const EMPTY_TEXT := "Wähle einen Würfel im Vorrat"

const BLOCK_LOCKED := "Wartungsvertrag - Fassung geschlossen"
const BLOCK_ROUND := "Runde läuft"
const BLOCK_ENERGY := "Nicht genug Energie"
const BLOCK_MONEY := "Nicht genug Geld"

## Steht die Fassung überhaupt unter Strom? Bedienbarkeit wie die Werkstatt
## (enabled = not _dice_editing_locked()), plus die Sperre des Wartungsvertrags.
static func open(run: GameRun, enabled: bool) -> bool:
	return run != null and enabled and not run.repair_locked()

static func repair_live(run: GameRun, die: DieDefinition, enabled: bool) -> bool:
	if not open(run, enabled) or die == null or not die.burned_out:
		return false
	var price := run.repair_price()
	if price.has("money"):
		return run.money >= int(price["money"])
	return run.energy >= int(price["energy"])

## WARUM gerade nichts geht ("" = keine Bremse). Genannt wird die erste geschlossene
## Bremse - erst die Sperren, dann das fehlende Guthaben; ein heiler Würfel ist keine
## Bremse, seine Sicherung liegt einfach ruhig.
static func blocker(run: GameRun, die: DieDefinition, enabled: bool) -> String:
	if run == null or die == null:
		return EMPTY_TEXT if run != null else ""
	if not enabled:
		return BLOCK_ROUND
	if run.repair_locked():
		return BLOCK_LOCKED
	if not die.burned_out:
		return ""
	var price := run.repair_price()
	if price.has("money"):
		return BLOCK_MONEY if run.money < int(price["money"]) else ""
	return BLOCK_ENERGY if run.energy < int(price["energy"]) else ""

## Das Preisschild - EINE Quelle: die Zahl steht in GameRun.repair_price(). Mit
## Isolierband kostet die Reparatur Geld statt Energie.
static func repair_price_text(run: GameRun) -> String:
	var price := run.repair_price() if run != null else {"energy": GameRun.REPAIR_ENERGY}
	if price.has("money"):
		return "$%d" % int(price["money"])
	return "%d ⚡" % int(price["energy"])
