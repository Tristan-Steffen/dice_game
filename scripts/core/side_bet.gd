class_name SideBet
extends RefCounted
## Eine Nebenwette der "Bank": vor einer Runde platziert (Einsatz sofort fällig
## oder als laufende Steuer je Hand), wird sie am Rundenende gegen die
## Rundenbilanz geprüft. Reine Daten/Logik, keine Nodes.

## Bedingung, die die Runde erfüllen muss:
## COMBO           - eine genommene Hand mindestens vom Rang target_combo,
## HAND_SCORE      - eine einzelne Hand mit >= target Punkten,
## FEW_DICE        - die Runde mit höchstens target genommenen Würfeln räumen,
## NO_FARKLE       - die Runde ohne einen einzigen Farkle räumen,
## FIRST_HAND      - schon die ERSTE genommene Hand wertet >= target Punkte,
## OVERCHARGE      - die Runde räumt >= target Überladungs-Stufen,
## DISTINCT_COMBOS - >= target VERSCHIEDENE Kombinationen genommen,
## HAND_LIMIT      - die Runde mit höchstens target Händen räumen,
## COMEBACK        - nach einem Farkle trotzdem geräumt,
## HIGH_DICE       - eine Hand aus >= HIGH_DICE_MIN Würfeln, alle mit >= HIGH_DICE_EYES Augen,
## CLEARED         - nur räumen (die Steuerwetten tragen die Herausforderung im Einsatz),
## MAX_HAND_DICE   - keine Hand nutzt mehr als target Würfel,
## FULL_HANDS      - JEDE Hand nutzt alle sechs Würfel,
## NO_REPEAT       - keine Kombination zweimal genommen,
## NO_FALLBACK     - nie die Rückfall-Kategorie (Höchste Zahl) genommen.
enum Condition { COMBO, HAND_SCORE, FEW_DICE, NO_FARKLE, FIRST_HAND, OVERCHARGE,
	DISTINCT_COMBOS, HAND_LIMIT, COMEBACK, HIGH_DICE, CLEARED, MAX_HAND_DICE,
	FULL_HANDS, NO_REPEAT, NO_FALLBACK }

## Womit der Einsatz bezahlt wird. MONEY/ENGRAVINGS/CHARGE sind beim Platzieren
## fällig, MONEY_PER_HAND/MONEY_PER_DIE laufen als Steuer je genommener Hand -
## reicht das Geld dafür nicht, verfällt die Wette (voided).
enum Stake { MONEY, ENGRAVINGS, MONEY_PER_HAND, MONEY_PER_DIE, CHARGE }
## Was der Gewinn ausschüttet.
enum Payout { ENGRAVINGS, MONEY, SPECIAL, CHARGE, PACK, COMBO_LEVEL }

## Hub-Stufe, ab der eine Wette ohne eigenen "unlock" ausliegt (= die Stufe, die
## die Nebenwetten überhaupt installiert, GameRun.HUB_SIDE_BETS_LEVEL).
const UNLOCK_BASE := 4

## Eine "volle" Hand nutzt alle sechs Würfel der Grube.
const FULL_HAND_DICE := 6

## Oberklasse: so viele Würfel muss die Hand werten, jeder mit so vielen Augen.
const HIGH_DICE_MIN := 3
const HIGH_DICE_EYES := 6

var id: String = ""
var condition: int = Condition.COMBO
var target: int = 0             # HAND_SCORE: Punkte; FEW_DICE: max. Würfel; ...
var target_combo: String = ""   # COMBO/COMBO_LEVEL: DiceScoring-Kategorie-Key
## > 0: target wird beim Auslegen aus dem Benchmark gerechnet (siehe _nice_target).
var target_factor: float = 0.0
var stake_kind: int = Stake.MONEY
var stake: int = 0              # Geld-Einsatz (einmalig bzw. je Hand/Würfel)
var stake_engravings: int = 0      # nur Stake.ENGRAVINGS: Anzahl geopferter Gravuren
var stake_charge: int = 0          # nur Stake.CHARGE: Ladung (⚡)
var payout_kind: int = Payout.ENGRAVINGS
var reward_engravings: int = 1     # nur Payout.ENGRAVINGS: Anzahl gewürfelter Aufwertungen
var payout_money: int = 0      # nur Payout.MONEY: Gewinn in Geld
var payout_charge: int = 0     # nur Payout.CHARGE: Gewinn in Ladung (⚡)
var special_id: String = ""    # nur Payout.SPECIAL: Engraving.SPECIAL_IDS
var unlock_level: int = UNLOCK_BASE
var display_name: String = ""
var description: String = ""
## Zahlungsunfähig geworden (Steuer nicht mehr bezahlbar) - die Wette ist tot.
var voided: bool = false
## Was ein PACK-Gewinn tatsächlich ausgeschüttet hat (die Zeremonie liest die
## Sorte für ihren Farbton).
var awarded_pack: Pack = null

## Vorlagen der Auslage (id -> Parameter). Fehlende Schlüssel = Standard
## (Geld-Einsatz, Gravur-Gewinn, unlock UNLOCK_BASE).
## desc = NUR die Gewinnbedingung; Einsatz und Gewinn stehen bereits auf dem Knopf.
## Mit target_factor ist desc ein Formatstring: der Benchmark füllt die Zahl.
const TEMPLATES := [
	# --- Grundstock (ab UNLOCK_BASE) ---
	{"id": "two_pair", "condition": Condition.COMBO, "combo": DiceScoring.TWO_PAIR,
		"stake": 4, "reward": 1, "name": "Doppelspiel",
		"desc": "Nimm zwei Paare oder besser."},
	{"id": "full_house", "condition": Condition.COMBO, "combo": DiceScoring.FULL_HOUSE,
		"stake": 6, "reward": 2, "name": "Volles Haus",
		"desc": "Nimm ein Full House oder besser."},
	{"id": "large_straight", "condition": Condition.COMBO, "combo": DiceScoring.LARGE_STRAIGHT,
		"stake": 9, "reward": 3, "name": "Die lange Reihe",
		"desc": "Nimm eine Große Straße."},
	{"id": "big_hand", "condition": Condition.HAND_SCORE, "target_factor": 1.0,
		"stake": 6, "reward": 2, "name": "Großer Wurf",
		"desc": "Werte eine einzelne Hand mit %d+ Punkten."},
	{"id": "economist", "condition": Condition.FEW_DICE, "target": 9,
		"stake": 6, "reward": 2, "name": "Sparsam",
		"desc": "Räume die Runde mit höchstens 9 genommenen Würfeln."},
	{"id": "jackpot", "condition": Condition.COMBO, "combo": DiceScoring.FULL_HOUSE,
		"stake": 6, "payout": Payout.MONEY, "payout_money": 18, "name": "Jackpot",
		"desc": "Nimm ein Full House oder besser."},
	{"id": "pawn", "condition": Condition.NO_FARKLE, "stake_kind": Stake.ENGRAVINGS, "stake_engravings": 1,
		"payout": Payout.MONEY, "payout_money": 16, "name": "Pfandleihe",
		"desc": "Räume die Runde ohne Farkle."},
	{"id": "clean_run", "condition": Condition.NO_FARKLE, "stake_kind": Stake.ENGRAVINGS, "stake_engravings": 1,
		"reward": 2, "name": "Saubere Runde",
		"desc": "Räume die Runde ohne Farkle."},
	# --- Salon (5) ---
	{"id": "high_roller", "condition": Condition.HAND_SCORE, "target_factor": 2.0,
		"stake": 10, "payout": Payout.MONEY, "payout_money": 32, "name": "Hoher Einsatz",
		"unlock": 5, "desc": "Werte eine Hand mit %d+ Punkten."},
	{"id": "quick_start", "condition": Condition.FIRST_HAND, "target_factor": 0.6,
		"stake": 5, "reward": 2, "name": "Blitzstart", "unlock": 5,
		"desc": "Werte schon die erste Hand mit %d+ Punkten."},
	{"id": "overclocker", "condition": Condition.OVERCHARGE, "target": 2,
		"stake": 6, "reward": 2, "name": "Übertakter", "unlock": 5,
		"desc": "Räume mindestens zwei Überladungs-Stufen."},
	{"id": "table_fee", "condition": Condition.CLEARED,
		"stake_kind": Stake.MONEY_PER_HAND, "stake": 3, "reward": 2, "name": "Tischgebühr",
		"unlock": 5, "desc": "Räume die Runde - jede genommene Hand kostet."},
	# --- VIP-Lounge (6) ---
	{"id": "collateral", "condition": Condition.HAND_SCORE, "target_factor": 1.3,
		"stake_kind": Stake.ENGRAVINGS, "stake_engravings": 2,
		"payout": Payout.MONEY, "payout_money": 34, "name": "Sicherheit",
		"unlock": 6, "desc": "Werte eine Hand mit %d+ Punkten."},
	{"id": "refinement", "condition": Condition.COMBO, "combo": DiceScoring.LARGE_STRAIGHT,
		"stake_kind": Stake.ENGRAVINGS, "stake_engravings": 1, "reward": 3, "name": "Veredelung",
		"unlock": 6, "desc": "Nimm eine Große Straße."},
	{"id": "connoisseur", "condition": Condition.DISTINCT_COMBOS, "target": 3,
		"stake": 6, "reward": 2, "name": "Kenner", "unlock": 6,
		"desc": "Nimm drei verschiedene Kombinationen."},
	{"id": "upper_class", "condition": Condition.HIGH_DICE,
		"stake": 6, "payout": Payout.MONEY, "payout_money": 20, "name": "Oberklasse",
		"unlock": 6, "desc": "Werte eine Hand aus mindestens drei Würfeln mit je 6+ Augen."},
	{"id": "dice_toll", "condition": Condition.CLEARED,
		"stake_kind": Stake.MONEY_PER_DIE, "stake": 1,
		"payout": Payout.MONEY, "payout_money": 30, "name": "Würfelzoll",
		"unlock": 6, "desc": "Räume die Runde - jeder genommene Würfel kostet Zoll."},
	{"id": "variety", "condition": Condition.NO_REPEAT,
		"stake": 5, "payout": Payout.MONEY, "payout_money": 18, "name": "Abwechslung",
		"unlock": 6, "desc": "Nimm keine Kombination zweimal."},
	# --- Suite (7) ---
	{"id": "efficiency", "condition": Condition.HAND_LIMIT, "target": 3,
		"stake": 8, "reward": 3, "name": "Effizienz", "unlock": 7,
		"desc": "Räume die Runde mit höchstens drei Händen."},
	{"id": "comeback", "condition": Condition.COMEBACK,
		"stake": 4, "payout": Payout.MONEY, "payout_money": 16, "name": "Comeback",
		"unlock": 7, "desc": "Räume die Runde nach einem Farkle."},
	{"id": "small_fry", "condition": Condition.MAX_HAND_DICE, "target": 3,
		"stake": 7, "reward": 3, "name": "Kleinvieh", "unlock": 7,
		"desc": "Nimm keine Hand aus mehr als drei Würfeln."},
	{"id": "no_scraps", "condition": Condition.NO_FALLBACK,
		"stake": 5, "payout": Payout.MONEY, "payout_money": 18, "name": "Keine Resterampe",
		"unlock": 7, "desc": "Nimm nie die Höchste Zahl."},
	# --- Penthouse (8) ---
	{"id": "deep_charge", "condition": Condition.OVERCHARGE, "target": 4,
		"stake_kind": Stake.ENGRAVINGS, "stake_engravings": 1, "reward": 3,
		"name": "Tiefenladung", "unlock": 8,
		"desc": "Räume mindestens vier Überladungs-Stufen."},
	{"id": "blank_check", "condition": Condition.FIRST_HAND, "target_factor": 1.2,
		"stake": 12, "payout": Payout.MONEY, "payout_money": 45, "name": "Blankoscheck",
		"unlock": 8, "desc": "Werte schon die erste Hand mit %d+ Punkten."},
	{"id": "feedback_loop", "condition": Condition.OVERCHARGE, "target": 3,
		"stake_kind": Stake.CHARGE, "stake_charge": 4,
		"payout": Payout.CHARGE, "payout_charge": 8, "name": "Rückkopplung",
		"unlock": 8, "desc": "Räume mindestens drei Überladungs-Stufen."},
	{"id": "patent", "condition": Condition.COMBO, "combo": DiceScoring.FULL_HOUSE,
		"stake": 12, "payout": Payout.COMBO_LEVEL, "name": "Patent", "unlock": 8,
		"desc": "Nimm ein Full House oder besser."},
	# --- Privatclub (9) ---
	{"id": "collector", "condition": Condition.DISTINCT_COMBOS, "target": 5,
		"stake_kind": Stake.ENGRAVINGS, "stake_engravings": 1, "reward": 4,
		"name": "Sammler", "unlock": 9,
		"desc": "Nimm fünf verschiedene Kombinationen."},
	{"id": "whale", "condition": Condition.HAND_SCORE, "target_factor": 2.5,
		"stake": 25, "payout": Payout.MONEY, "payout_money": 90, "name": "Der Wal",
		"unlock": 9, "desc": "Werte eine Hand mit %d+ Punkten."},
	{"id": "shipment", "condition": Condition.FEW_DICE, "target": 8,
		"stake": 10, "payout": Payout.PACK, "name": "Warensendung", "unlock": 9,
		"desc": "Räume die Runde mit höchstens 8 genommenen Würfeln."},
	{"id": "full_grip", "condition": Condition.FULL_HANDS,
		"stake_kind": Stake.ENGRAVINGS, "stake_engravings": 1, "reward": 4,
		"name": "Vollgriff", "unlock": 9,
		"desc": "Nimm jede Hand mit allen sechs Würfeln."},
	# --- High Roller (10): die Sonderposten ---
	{"id": "circuit_contract", "condition": Condition.OVERCHARGE, "target": 5,
		"stake": 20, "payout": Payout.SPECIAL, "special": Engraving.POINTER,
		"name": "Platinenauftrag", "unlock": 10,
		"desc": "Räume mindestens fünf Überladungs-Stufen."},
	{"id": "clean_room", "condition": Condition.HAND_SCORE, "target_factor": 2.0,
		"stake": 20, "payout": Payout.SPECIAL, "special": Engraving.DOPING,
		"name": "Reinraum", "unlock": 10,
		"desc": "Werte eine Hand mit %d+ Punkten."},
	{"id": "all_in_hand", "condition": Condition.HAND_LIMIT, "target": 1,
		"stake": 15, "reward": 5, "name": "Alles auf eine Hand", "unlock": 10,
		"desc": "Räume die Runde mit einer einzigen Hand."},
]

## Gravur-Kategorien, die ein Gewinn ausschüttet (Zahl + Material; kein Menü/
## Würfel-Sonderfall, damit die Belohnung immer im Inventar landet).
const REWARD_KINDS := [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL]

## Kleinstes ausgelegtes Punktziel.
const MIN_TARGET := 25

## Rundet ein aus dem Benchmark gerechnetes Punktziel auf eine lesbare Zahl:
## unter 1000 auf 25er, darüber auf 100er - eine "1137" auf dem Knopf sähe aus
## wie ein Rechenfehler.
static func _nice_target(raw: float) -> int:
	var step := 100 if raw >= 1000.0 else MIN_TARGET
	return maxi(MIN_TARGET, roundi(raw / float(step)) * step)

## benchmark = der GESPEICHERTE Rundenbenchmark (nicht effective_goal): eine
## erst nach der Wettannahme unterschriebene Klausel darf ein aufgedrucktes Ziel
## nicht mehr verschieben.
static func _from_template(t: Dictionary, benchmark: int = 0) -> SideBet:
	var bet := SideBet.new()
	bet.id = t["id"]
	bet.condition = t["condition"]
	bet.target = int(t.get("target", 0))
	bet.target_combo = t.get("combo", "")
	bet.target_factor = float(t.get("target_factor", 0.0))
	bet.stake_kind = int(t.get("stake_kind", Stake.MONEY))
	bet.stake = int(t.get("stake", 0))
	bet.stake_engravings = int(t.get("stake_engravings", 0))
	bet.stake_charge = int(t.get("stake_charge", 0))
	bet.payout_kind = int(t.get("payout", Payout.ENGRAVINGS))
	bet.reward_engravings = int(t.get("reward", 1))
	bet.payout_money = int(t.get("payout_money", 0))
	bet.payout_charge = int(t.get("payout_charge", 0))
	bet.special_id = t.get("special", "")
	bet.unlock_level = int(t.get("unlock", UNLOCK_BASE))
	bet.display_name = t["name"]
	bet.description = t["desc"]
	if bet.target_factor > 0.0:
		bet.target = _nice_target(float(benchmark) * bet.target_factor)
		bet.description = t["desc"] % bet.target
	return bet

## Würfelt count verschiedene Wett-Angebote aus (ohne Zurücklegen). hub_level
## filtert die Auslage (jede Vorlage hat ihre Freischalt-Stufe), benchmark füllt
## die skalierten Punktziele - beide werden HIER eingefroren.
static func roll_offers(count: int, hub_level: int, benchmark: int) -> Array[SideBet]:
	var templates: Array = []
	for t: Dictionary in TEMPLATES:
		if int(t.get("unlock", UNLOCK_BASE)) <= hub_level:
			templates.append(t)
	templates.shuffle()
	var bets: Array[SideBet] = []
	for i in mini(count, templates.size()):
		bets.append(_from_template(templates[i], benchmark))
	return bets

## Prüft die Wette gegen die Rundenbilanz (siehe scene_root._round_result).
## Eine nicht geräumte Runde (Game Over) und eine verfallene Wette verlieren immer.
func evaluate(result: Dictionary) -> bool:
	if voided or not result.get("cleared", false):
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
		Condition.FIRST_HAND:
			return int(result.get("first_hand_score", 0)) >= target
		Condition.OVERCHARGE:
			return int(result.get("stages_cleared", 0)) >= target
		Condition.DISTINCT_COMBOS:
			return int(result.get("distinct_combos", 0)) >= target
		Condition.HAND_LIMIT:
			return int(result.get("hands_taken", 9999)) <= target
		Condition.COMEBACK:
			return bool(result.get("farkled", false))
		Condition.HIGH_DICE:
			return bool(result.get("high_hand", false))
		Condition.CLEARED:
			return true
		Condition.MAX_HAND_DICE:
			return int(result.get("max_hand_dice", 0)) <= target
		Condition.FULL_HANDS:
			return int(result.get("hands_taken", 0)) >= 1 \
				and int(result.get("min_hand_dice", 0)) >= FULL_HAND_DICE
		Condition.NO_REPEAT:
			return not bool(result.get("combo_repeated", false))
		Condition.NO_FALLBACK:
			return not bool(result.get("fallback_taken", false))
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
	if voided:
		return Live.FAILED  # zahlungsunfähig - die Steuer hat die Wette gerissen
	match condition:
		Condition.COMBO:
			return Live.ON_TRACK if int(result.get("best_combo_rank", -1)) >= combo_rank(target_combo) else Live.PENDING
		Condition.HAND_SCORE:
			return Live.ON_TRACK if int(result.get("best_hand_score", 0)) >= target else Live.PENDING
		Condition.FEW_DICE:
			return Live.FAILED if int(result.get("dice_taken", 0)) > target else Live.ON_TRACK
		Condition.NO_FARKLE:
			return Live.FAILED if bool(result.get("farkled", false)) else Live.ON_TRACK
		Condition.FIRST_HAND:
			# Vor der ersten Hand offen, danach endgültig entschieden.
			if int(result.get("hands_taken", 0)) <= 0:
				return Live.PENDING
			return Live.ON_TRACK if int(result.get("first_hand_score", 0)) >= target else Live.FAILED
		Condition.OVERCHARGE:
			return Live.ON_TRACK if int(result.get("stages_cleared", 0)) >= target else Live.PENDING
		Condition.DISTINCT_COMBOS:
			return Live.ON_TRACK if int(result.get("distinct_combos", 0)) >= target else Live.PENDING
		Condition.HAND_LIMIT:
			return Live.FAILED if int(result.get("hands_taken", 0)) > target else Live.ON_TRACK
		Condition.COMEBACK:
			return Live.ON_TRACK if bool(result.get("farkled", false)) else Live.PENDING
		Condition.HIGH_DICE:
			return Live.ON_TRACK if bool(result.get("high_hand", false)) else Live.PENDING
		Condition.CLEARED:
			return Live.ON_TRACK
		Condition.MAX_HAND_DICE:
			return Live.FAILED if int(result.get("max_hand_dice", 0)) > target else Live.ON_TRACK
		Condition.FULL_HANDS:
			return Live.FAILED if int(result.get("min_hand_dice", FULL_HAND_DICE)) < FULL_HAND_DICE else Live.ON_TRACK
		Condition.NO_REPEAT:
			return Live.FAILED if bool(result.get("combo_repeated", false)) else Live.ON_TRACK
		Condition.NO_FALLBACK:
			return Live.FAILED if bool(result.get("fallback_taken", false)) else Live.ON_TRACK
	return Live.PENDING

## Balkenfüllung 0..1 (binäre Bedingungen liefern 0 oder 1).
func progress_fraction(result: Dictionary) -> float:
	match condition:
		Condition.COMBO:
			return 1.0 if int(result.get("best_combo_rank", -1)) >= combo_rank(target_combo) else 0.0
		Condition.HAND_SCORE:
			return _ratio(int(result.get("best_hand_score", 0)))
		Condition.FEW_DICE:
			return _ratio(int(result.get("dice_taken", 0)))
		Condition.NO_FARKLE:
			return 1.0
		Condition.FIRST_HAND:
			return _ratio(int(result.get("first_hand_score", 0)))
		Condition.OVERCHARGE:
			return _ratio(int(result.get("stages_cleared", 0)))
		Condition.DISTINCT_COMBOS:
			return _ratio(int(result.get("distinct_combos", 0)))
		Condition.HAND_LIMIT:
			return _ratio(int(result.get("hands_taken", 0)))
		Condition.COMEBACK:
			return 1.0 if bool(result.get("farkled", false)) else 0.0
		Condition.HIGH_DICE:
			return 1.0 if bool(result.get("high_hand", false)) else 0.0
		Condition.CLEARED:
			return 1.0
		Condition.MAX_HAND_DICE:
			return _ratio(int(result.get("max_hand_dice", 0)))
		Condition.FULL_HANDS:
			return 0.0 if int(result.get("min_hand_dice", FULL_HAND_DICE)) < FULL_HAND_DICE else 1.0
		Condition.NO_REPEAT:
			return 0.0 if bool(result.get("combo_repeated", false)) else 1.0
		Condition.NO_FALLBACK:
			return 0.0 if bool(result.get("fallback_taken", false)) else 1.0
	return 0.0

func _ratio(value: int) -> float:
	return clampf(float(value) / float(maxi(target, 1)), 0.0, 1.0)

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
		Condition.FIRST_HAND:
			if int(result.get("hands_taken", 0)) <= 0:
				return "offen / %d" % target
			return "%d / %d" % [int(result.get("first_hand_score", 0)), target]
		Condition.OVERCHARGE:
			return "%d / %d Stufen" % [int(result.get("stages_cleared", 0)), target]
		Condition.DISTINCT_COMBOS:
			return "%d / %d Sorten" % [int(result.get("distinct_combos", 0)), target]
		Condition.HAND_LIMIT:
			return "%d / %d Hände" % [int(result.get("hands_taken", 0)), target]
		Condition.COMEBACK:
			return "Farkle ✓" if bool(result.get("farkled", false)) else "noch kein Farkle"
		Condition.HIGH_DICE:
			return "erreicht" if bool(result.get("high_hand", false)) else "offen"
		Condition.CLEARED:
			return "läuft"
		Condition.MAX_HAND_DICE:
			return "max. %d / %d" % [int(result.get("max_hand_dice", 0)), target]
		Condition.FULL_HANDS:
			return "zu klein" if int(result.get("min_hand_dice", FULL_HAND_DICE)) < FULL_HAND_DICE else "voll"
		Condition.NO_REPEAT:
			return "Dublette!" if bool(result.get("combo_repeated", false)) else "verschieden"
		Condition.NO_FALLBACK:
			return "Rückfall!" if bool(result.get("fallback_taken", false)) else "sauber"
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

## Die Sonderposten-Gravur eines SPECIAL-Gewinns (null, wenn keine id steht).
func special_engraving() -> Engraving:
	if special_id == "":
		return null
	for engraving in Engraving.all():
		if engraving.id == special_id:
			return engraving
	return null

## Einsatz-Etikett: Geld, geopferte Gravuren, Ladung oder laufende Steuer.
## factor = Deal-Aufschlag (Quotenpaket) - der Knopf muss den WIRKLICH fälligen
## Einsatz zeigen.
func stake_label(factor: int = 1) -> String:
	match stake_kind:
		Stake.ENGRAVINGS:
			var count := stake_engravings * factor
			return "%d Gravur%s" % [count, "" if count == 1 else "en"]
		Stake.MONEY_PER_HAND:
			return "$%d je Hand" % (stake * factor)
		Stake.MONEY_PER_DIE:
			return "$%d je Würfel" % (stake * factor)
		Stake.CHARGE:
			return "%d ⚡" % (stake_charge * factor)
	return "$%d" % (stake * factor)

## Gewinn-Etikett: Barbetrag oder Anzahl gewürfelter Gravuren (klar benannt, damit
## der Knopf nicht "1×" wie einen Geld-Multiplikator zeigt). factor wie oben -
## Einzelstücke (Sonderposten, Paket, Chipstufe) verdoppelt die Turniernacht NICHT.
## charm_ids nur für den Barbetrag: das Quotenblatt muss auf dem Knopf stehen,
## sonst verspricht er weniger, als die Abrechnung zahlt.
func reward_label(factor: int = 1, charm_ids: Array[String] = []) -> String:
	match payout_kind:
		Payout.MONEY:
			return "$%d" % CharmEffects.side_bet_money(payout_money * factor, charm_ids)
		Payout.CHARGE:
			return "%d ⚡" % (payout_charge * factor)
		Payout.SPECIAL:
			var special := special_engraving()
			return "1 %s" % (special.display_name if special != null else special_id)
		Payout.PACK:
			return "1 Paket"
		Payout.COMBO_LEVEL:
			return "+1 Stufe"
	var count := reward_engravings * factor
	return "%d Gravur%s" % [count, "" if count == 1 else "en"]
