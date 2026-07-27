class_name SideBet
extends RefCounted
## Eine Nebenwette der "Bank": vor einer Runde platziert (Einsatz sofort fällig),
## wird sie am Rundenende gegen die Rundenbilanz geprüft. Gewinn = eine
## Aufwertungs-Ausschüttung (Gravuren). Reine Daten/Logik, keine Nodes.

## Bedingung, die die Runde erfüllen muss:
## COMBO       - eine genommene Hand mindestens vom Rang target_combo,
## HAND_SCORE  - eine einzelne Hand mit >= target Punkten,
## FEW_DICE    - die Runde mit höchstens target genommenen Würfeln räumen,
## NO_FARKLE   - die Runde ohne einen einzigen Farkle räumen.
enum Condition { COMBO, HAND_SCORE, FEW_DICE, NO_FARKLE }

## Womit der Einsatz bezahlt wird: Geld oder geopferte Gravuren.
enum Stake { MONEY, ENGRAVINGS }
## Was der Gewinn ausschüttet: Geld oder Gravuren (Aufwertungen).
enum Payout { ENGRAVINGS, MONEY }

var id: String = ""
var condition: int = Condition.COMBO
var target: int = 0             # HAND_SCORE: Punkte; FEW_DICE: max. Würfel
var target_combo: String = ""   # nur COMBO: DiceScoring-Kategorie-Key
var stake_kind: int = Stake.MONEY
var stake: int = 0              # nur Stake.MONEY: Einsatz in Geld
var stake_engravings: int = 0      # nur Stake.ENGRAVINGS: Anzahl geopferter Gravuren
var payout_kind: int = Payout.ENGRAVINGS
var reward_engravings: int = 1     # nur Payout.ENGRAVINGS: Anzahl gewürfelter Aufwertungen
var payout_money: int = 0      # nur Payout.MONEY: Gewinn in Geld
var display_name: String = ""
var description: String = ""

## Vorlagen der Auslage (id -> Parameter). Vier Wett-Sorten über zwei Achsen:
## Einsatz in Geld ODER geopferten Gravuren, Gewinn in Gravuren ODER Geld.
## Fehlende Schlüssel = Standard (Geld-Einsatz, Gravur-Gewinn).
## desc = NUR die Gewinnbedingung; Einsatz und Gewinn stehen bereits auf dem Knopf.
const TEMPLATES := [
	# Geld -> Gravuren: der Brotalltag der Bank.
	{"id": "two_pair", "condition": Condition.COMBO, "combo": DiceScoring.TWO_PAIR,
		"stake": 4, "reward": 1, "name": "Doppelspiel",
		"desc": "Nimm zwei Paare oder besser."},
	{"id": "full_house", "condition": Condition.COMBO, "combo": DiceScoring.FULL_HOUSE,
		"stake": 6, "reward": 2, "name": "Volles Haus",
		"desc": "Nimm ein Full House oder besser."},
	{"id": "large_straight", "condition": Condition.COMBO, "combo": DiceScoring.LARGE_STRAIGHT,
		"stake": 9, "reward": 3, "name": "Die lange Reihe",
		"desc": "Nimm eine Große Straße."},
	{"id": "big_hand", "condition": Condition.HAND_SCORE, "target": 400,
		"stake": 6, "reward": 2, "name": "Großer Wurf",
		"desc": "Werte eine einzelne Hand mit 400+ Punkten."},
	{"id": "economist", "condition": Condition.FEW_DICE, "target": 9,
		"stake": 6, "reward": 2, "name": "Sparsam",
		"desc": "Räume die Runde mit höchstens 9 genommenen Würfeln."},
	# Geld -> Geld: reines Glücksspiel, hohe Quote.
	{"id": "jackpot", "condition": Condition.COMBO, "combo": DiceScoring.FULL_HOUSE,
		"stake": 6, "payout": Payout.MONEY, "payout_money": 18, "name": "Jackpot",
		"desc": "Nimm ein Full House oder besser."},
	{"id": "high_roller", "condition": Condition.HAND_SCORE, "target": 900,
		"stake": 10, "payout": Payout.MONEY, "payout_money": 32, "name": "Hoher Einsatz",
		"desc": "Werte eine Hand mit 900+ Punkten."},
	# Gravur -> Geld: ein Siegel verpfänden und auf Bargeld hoffen.
	{"id": "pawn", "condition": Condition.NO_FARKLE, "stake_kind": Stake.ENGRAVINGS, "stake_engravings": 1,
		"payout": Payout.MONEY, "payout_money": 16, "name": "Pfandleihe",
		"desc": "Räume die Runde ohne Farkle."},
	{"id": "collateral", "condition": Condition.HAND_SCORE, "target": 500,
		"stake_kind": Stake.ENGRAVINGS, "stake_engravings": 2,
		"payout": Payout.MONEY, "payout_money": 34, "name": "Sicherheit",
		"desc": "Werte eine Hand mit 500+ Punkten."},
	# Gravur -> Gravuren: ein Siegel riskieren, um bessere zu prägen.
	{"id": "refinement", "condition": Condition.COMBO, "combo": DiceScoring.LARGE_STRAIGHT,
		"stake_kind": Stake.ENGRAVINGS, "stake_engravings": 1, "reward": 3, "name": "Veredelung",
		"desc": "Nimm eine Große Straße."},
	# Gravur -> Gravuren: saubere Runde tauscht eins gegen zwei.
	{"id": "clean_run", "condition": Condition.NO_FARKLE, "stake_kind": Stake.ENGRAVINGS, "stake_engravings": 1,
		"reward": 2, "name": "Saubere Runde",
		"desc": "Räume die Runde ohne Farkle."},
]

## Gravur-Kategorien, die ein Gewinn ausschüttet (Zahl + Material; kein Menü/
## Würfel-Sonderfall, damit die Belohnung immer im Inventar landet).
const REWARD_KINDS := [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL]

static func _from_template(t: Dictionary) -> SideBet:
	var bet := SideBet.new()
	bet.id = t["id"]
	bet.condition = t["condition"]
	bet.target = int(t.get("target", 0))
	bet.target_combo = t.get("combo", "")
	bet.stake_kind = int(t.get("stake_kind", Stake.MONEY))
	bet.stake = int(t.get("stake", 0))
	bet.stake_engravings = int(t.get("stake_engravings", 0))
	bet.payout_kind = int(t.get("payout", Payout.ENGRAVINGS))
	bet.reward_engravings = int(t.get("reward", 1))
	bet.payout_money = int(t.get("payout_money", 0))
	bet.display_name = t["name"]
	bet.description = t["desc"]
	return bet

## Würfelt count verschiedene Wett-Angebote aus (ohne Zurücklegen).
static func roll_offers(count: int) -> Array[SideBet]:
	var templates := TEMPLATES.duplicate()
	templates.shuffle()
	var bets: Array[SideBet] = []
	for i in mini(count, templates.size()):
		bets.append(_from_template(templates[i]))
	return bets

## Prüft die Wette gegen die Rundenbilanz (siehe scene_root._round_result).
## Eine nicht geräumte Runde (Game Over) verliert jede Wette.
func evaluate(result: Dictionary) -> bool:
	if not result.get("cleared", false):
		return false
	match condition:
		Condition.COMBO:
			return int(result.get("best_combo_rank", -1)) >= combo_rank(target_combo)
		Condition.HAND_SCORE:
			return int(result.get("best_hand_score", 0)) >= target
		Condition.FEW_DICE:
			return int(result.get("dice_taken", 9999)) <= target
		Condition.NO_FARKLE:
			return not bool(result.get("farkled", true))
	return false

## Rang einer Kombination: höher = seltener/besser. Über HAND_PRIORITY
## abgeleitet (Index 0 = beste), damit ">= rank" einen "oder besser"-Vergleich ist.
static func combo_rank(key: String) -> int:
	var index := DiceScoring.HAND_PRIORITY.find(key)
	if index == -1:
		return -1
	return DiceScoring.HAND_PRIORITY.size() - index

## Live-Zustand während der Runde (für die Fortschrittsanzeige): PENDING = noch
## offen, ON_TRACK = aktuell erfüllt, FAILED = nicht mehr erreichbar.
enum Live { PENDING, ON_TRACK, FAILED }

## result trägt dieselben Schlüssel wie evaluate(), aber ohne "cleared" (die
## Runde läuft noch). Siehe scene_root._refresh_side_bet_panel.
func live_state(result: Dictionary) -> int:
	match condition:
		Condition.COMBO:
			return Live.ON_TRACK if int(result.get("best_combo_rank", -1)) >= combo_rank(target_combo) else Live.PENDING
		Condition.HAND_SCORE:
			return Live.ON_TRACK if int(result.get("best_hand_score", 0)) >= target else Live.PENDING
		Condition.FEW_DICE:
			return Live.FAILED if int(result.get("dice_taken", 0)) > target else Live.ON_TRACK
		Condition.NO_FARKLE:
			return Live.FAILED if bool(result.get("farkled", false)) else Live.ON_TRACK
	return Live.PENDING

## Balkenfüllung 0..1 (COMBO/NO_FARKLE sind binär).
func progress_fraction(result: Dictionary) -> float:
	match condition:
		Condition.COMBO:
			return 1.0 if int(result.get("best_combo_rank", -1)) >= combo_rank(target_combo) else 0.0
		Condition.HAND_SCORE:
			return clampf(float(result.get("best_hand_score", 0)) / float(maxi(target, 1)), 0.0, 1.0)
		Condition.FEW_DICE:
			return clampf(float(result.get("dice_taken", 0)) / float(maxi(target, 1)), 0.0, 1.0)
		Condition.NO_FARKLE:
			return 1.0
	return 0.0

## Kurzer Fortschrittstext für die Anzeige.
func status_label(result: Dictionary) -> String:
	match condition:
		Condition.COMBO:
			var met := int(result.get("best_combo_rank", -1)) >= combo_rank(target_combo)
			return "%s%s" % [DiceScoring.label_for(target_combo), " ✓" if met else ""]
		Condition.HAND_SCORE:
			return "%d / %d" % [int(result.get("best_hand_score", 0)), target]
		Condition.FEW_DICE:
			return "%d / %d Würfel" % [int(result.get("dice_taken", 0)), target]
		Condition.NO_FARKLE:
			return "Farkle!" if bool(result.get("farkled", false)) else "sauber"
	return ""

## Die bei Gewinn gutzuschreibenden Gravuren (zufällig aus REWARD_KINDS).
func reward_list() -> Array[Engraving]:
	var pool: Array[Engraving] = []
	for engraving in Engraving.all():
		if REWARD_KINDS.has(engraving.category):
			pool.append(engraving)
	var result: Array[Engraving] = []
	if pool.is_empty():
		return result
	for i in reward_engravings:
		result.append(pool[randi() % pool.size()])
	return result

## Einsatz-Etikett: Geldbetrag oder Anzahl geopferter Gravuren. factor = Deal-
## Aufschlag (Quotenpaket) - der Knopf muss den WIRKLICH fälligen Einsatz zeigen.
func stake_label(factor: int = 1) -> String:
	if stake_kind == Stake.ENGRAVINGS:
		var count := stake_engravings * factor
		return "%d Gravur%s" % [count, "" if count == 1 else "en"]
	return "$%d" % (stake * factor)

## Gewinn-Etikett: Barbetrag oder Anzahl gewürfelter Gravuren (klar benannt, damit
## der Knopf nicht "1×" wie einen Geld-Multiplikator zeigt). factor wie oben.
func reward_label(factor: int = 1) -> String:
	if payout_kind == Payout.MONEY:
		return "$%d" % (payout_money * factor)
	var count := reward_engravings * factor
	return "%d Gravur%s" % [count, "" if count == 1 else "en"]
