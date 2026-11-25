class_name GameRun
extends RefCounted
## Persistenter Zustand eines Spiellaufs: Geld, Würfel-Pool, Charms, Gravuren,
## Rundenfortschritt. Reine Daten + Ökonomie, keine Nodes; UI mutiert den
## Zustand nur über die Methoden hier und hört auf die Signale.

signal money_changed(money: int)
signal charms_changed
signal packs_changed
## Die Steckplätze einer Kombination haben sich geändert (Einbau, Umstecken,
## Stilllegung). Brücken lesen den Nachbarn - Anzeigen frischen darum alle auf.
signal combo_parts_changed(combo_key: String)
signal pending_parts_changed
signal side_bets_changed
signal deals_changed
## Ein Pool-Würfel hat seinen Inhalt geändert (Kauf, Paket, Gravur, Nehmen-
## Effekt, Testmodus). EINZIGER Auffrischungs-Weg der Würfel-Anzeigen: die Trays,
## die Grubenwürfel und die Gravur-Station hängen alle hier - Instanzen werden
## NIE getauscht (become), also reicht ein Signal ohne Index.
signal pool_changed
signal pending_dice_changed
signal energy_changed(value: int)
signal secret_stock_changed
signal projectors_changed
## Die Serie der Werkbank hat sich geändert (Prägen, Slots, verbrauchte Karten).
signal press_changed

const POOL_SIZE := 30
## Je PROJEKTOR ein Charm-Platz; jeder hängt an einem der USB-Ports des Tisches.
const START_PROJECTORS := 3
const MAX_PROJECTORS := 10
## ⚡-Preis je Projektor im Schwarzmarkt: Schritt × (schon dazugekommene + 1).
const PROJECTOR_PRICE_STEP := 5
const SECRET_PROJECTOR_CHANCE := 0.15
## Statisch, damit Tests die Auslage festhalten können.
static var secret_projector_chance := SECRET_PROJECTOR_CHANCE
const BASE_GOAL := 150
## Blind-Kurve: Wachstum je Runde = BLIND_GROWTH_BASE + BLIND_GROWTH_STEP × Block.
const BLIND_GROWTH_BASE := 0.10
const BLIND_GROWTH_STEP := 0.05
## Gerundet wird nur das Ziel (abwärts auf Vielfache davon), nie der Akkumulator.
const BLIND_ROUNDING := 5
## Blocklänge der Ziel-Eskalation = die sechs am Hub gezeigten Stationen.
const GOAL_BLOCK := 6

## Fahrplan-Marker der Stresstest-Station (goal_roadmap_markers) samt Anzeige-
## Texten - eine Quelle für Hub-Kopfzeile und Fahrplan-Hinweis.
const STRESS_MARKER := "stress"
const STRESS_NAME := "Boss-Runde"
const STRESS_HINT := "Boss-Konditionen: das Haus diktiert, unter welcher Auflage gespielt wird."

## --- Verträge mit dem Haus ----------------------------------------------------
## Angebotsgröße je Runde (Standard-, Risiko-, Knebelvertrag).
const ROUTE_OFFER_COUNT := 3
## Anteil der Auslagen, in denen EIN Platz statt seines Vertrags ein
## Werbegeschenk zeigt.
const TREAT_CHANCE := 0.3
## Kommt ein Werbegeschenk, verteilt sich der ersetzte Platz so (Standard-,
## Risiko-, Knebelvertrag): meist der Standardplatz, nur selten der Knebelplatz.
const TREAT_TIER_WEIGHTS := [0.6, 0.3, 0.1]
## Zahlen der Klausel-Wirkungen - hier, nicht in DealClause: dort stehen Daten
## und Texte, die Wirkung lösen die Abfragen unten auf.
const ADVANCE_PAYMENT_MONEY := 12
const BLANK_CHEQUE_MONEY := 40
const SAVINGS_DIE_BONUS := 1
const SEED_CAPITAL_ENERGY := 1
const DISCHARGE_ENERGY := 2
const INSURANCE_FRAUD_MONEY := 15
const SERVICE_FEE_MONEY := 3
const RIP_OFF_PER_DIE := 1
const GOLD_VEIN_MONEY := 10
const WORK_HARDENING_GROWTH := 1
const INTEREST_PER := 10
const STAGE_CAP_LIMIT := 2
const HIGH_VOLTAGE_STAGES := 3
## Eichung: dauerhaft −10 % auf den Blind (der Winkeladvokat wendet sie zweimal an).
const CALIBRATION_FACTOR := 0.9
## Skalierung der Überladungs-Stufen: der Sicherungsfall schlägt das Netzbrummen.
const FUSE_FAILURE_SCALE := 4.0
const MAINS_HUM_SCALE := 3.0
const SHOP_INFLATION_FACTOR := 1.25
const SHOP_DISCOUNT_FACTOR := 0.8
## Stammkunde: Ladenpreise −15 % bis zur Abrechnung.
const REGULAR_CUSTOMER_FACTOR := 0.85
## Dauerhafte Blind-Hebungen: mit der Unterschrift auf blind_value multipliziert.
const BLIND_RAISE := {
	DealClause.QUOTA_SURCHARGE: 0.10,
	DealClause.QUOTA_SURCHARGE_II: 0.20,
	DealClause.QUOTA_SHOCK: 0.35,
	DealClause.USURY_CLAUSE: 0.50,
}
## Rundenweise Blind-Aufschläge (nur die Boss-Kondition) - nur sie bewacht _quota_blocked.
const QUOTA_MALUS := {
	DealClause.HIGH_EXPECTATIONS: 5.0,
}
## Pechsträhne: jeder echte Fumble der Runde hebt blind_value dauerhaft.
const BAD_STREAK_RAISE := 0.05
## Glücks-Klauseln: Glück je Unterschrift (Malus negativ).
const LUCK_CLAUSES := {
	DealClause.LUCKY_PENNY: 1,
	DealClause.LUCKY_STREAK: 2,
	DealClause.LUCKY_CHILD: 3,
	DealClause.UNLUCKY_NUMBER: -2,
}
## Glück auf Zeit: mit der Unterschrift dazu, mit dem Start der nächsten Runde wieder fort.
const TEMP_LUCK_CLAUSES := {
	DealClause.LUCKY_DAY: 3,
	DealClause.MATH_WEEK: 6,
	DealClause.SPECIAL_DELIVERY: 10,
}
## Freies Blättern: so viele Doppelseiten gratis.
const FREE_FLIPS := 3

## Überladung: das Rundenziel lässt sich bis zu OVERCHARGE_STAGES-mal füllen,
## jede Stufe fordert die doppelte Punktzahl der vorigen (150 / 300 / 600 / …).
## Der Punktestand ist kumulativ, Überschuss trägt automatisch weiter. Wie viele
## Stufen tatsächlich zählen, deckelt max_overcharge_stages.
const OVERCHARGE_STAGES := 5
## Supraleiter hebt den Deckel ganz auf; die Stufengrößen verdoppeln sich, ein
## großer Platzhalter begrenzt sich also von selbst.
const UNLIMITED_OVERCHARGE_STAGES := 99

## FORTSCHRITTSSTUFE: aus dem GLÜCK gerechnet (progress_tier). Sie trägt jede
## Leiter, die mit dem Lauf wächst - Laden, Wetten, Automaten, Börse.
const LUCK_PER_TIER := 3
const TIER_MAX := 10

## Feste Shop-Platzzahlen: drei Charms und EINE Paket-Fläche zu sechs Plätzen
## (Spieler-Entscheid 2026-11-16). Mit der Stufe wächst nur die Qualität.
const SHOP_CHARM_SLOTS := 3
const SHOP_PACK_PLACES := 6
## Leere Regale lassen so viele Plätze leer.
const EMPTY_SHELVES_CUT := 2

## Ab dieser Fortschrittsstufe führt auch das normale Regal Sonderposten - vorher
## gibt es sie einzig im Hinterzimmer.
const SHOP_SPECIAL_TIER := 8
## Chance je Auslage, dass einer dabei ist; auf der letzten Stufe liegt öfter
## einer aus als nicht.
const SHOP_SPECIAL_CHANCE := {8: 0.25, 9: 0.4, 10: 0.55}

## Schwellen der Fortschrittsstufe.
const TIER_RARITY_UNCOMMON := 6
const TIER_CHEAP_FLIP := 8    # halbierte Blätter-Gebühr
const TIER_RARITY_RARE := 9
const TIER_RARITY_LEGENDARY := 10

var money: int = 0:
	set(value):
		money = value
		money_changed.emit(money)

var round_number: int = 1
var round_goal: int = BASE_GOAL
## Der Blind ungerundet - Wachstum und dauerhafte Hebungen multiplizieren HIER.
var blind_value: float = float(BASE_GOAL)
## Wirklich gespielter Blind je geschaffter Runde (Index = Runde − 1) für den Fahrplan.
var blind_history: Array[int] = []
## GLÜCK: +1 je geschaffter Runde, Glücks-Klauseln drehen daran; trägt progress_tier.
## Jede Änderung gleicht den Glückswürfel an (Buchung vor dem Licht).
var luck: int = 0:
	set(value):
		luck = value
		sync_luck_die()
## Der GLÜCKSWÜRFEL: seine Augen wachsen mit dem wirkenden Glück, sein Wurf sind die Wahlen.
signal luck_die_changed(changes: Array)
var luck_die := LuckDie.new()

## Unterschriebene Klauseln des laufenden Blocks als {id, round}; round = Runde
## der Unterschrift und entscheidet, wie lange die Klausel wirkt (_scope_reaches -
## keine überlebt ihre Runde). Geleert erst bei der Abrechnung: die abgelaufenen
## Einträge bleiben stehen, denn sie sperren ihre Klausel für den Rest des Blocks.
var active_deals: Array[Dictionary] = []
## Auslage der kommenden Runde als Vertragskarten (CARD_*); leer = unterschrieben.
var route_offers: Array[Dictionary] = []

## Gedrosselte Kombinationen dieser Runde (leer = keine). Steht mit Rundenbeginn
## fest; nur die Boss-Konditionen (Allrounder, Standardprotokoll) lassen sie mit
## jeder genommenen Hand weiterwachsen.
var throttled_combos: Array[String] = []
## Hausgutschein: der nächste Charm im Laden ist gratis (verbraucht sich).
var free_charm_pending: bool = false
## Glück auf Zeit, das der nächste Rundenstart wieder abzieht.
var temp_luck: int = 0
## Freies Blättern: verbrauchte Gratis-Seiten dieser Runde.
var free_flips_used: int = 0
## Freispiel-Charm: der Gratisdreh dieses LADENBESUCHS ist verbraucht. Er hängt
## am Besuch, nicht an der Runde - begin_shop_visit setzt ihn zurück.
var free_spin_used_this_visit: bool = false

## Immer genau POOL_SIZE Einträge, jeder eine EIGENE DieDefinition-Instanz,
## damit eine Ätzung nie mehrere Würfel zugleich verändert.
var owned_pool: Array[DieDefinition] = []
var owned_charms: Array[Charm] = []
## Versiegelte Pakete im Werkstatt-Lager; sie warten dort beliebig lange. Eine
## Aufwertung existiert nur SO oder angewendet - einen losen Vorrat gibt es nicht.
## Das Magazin ist UNBEGRENZT (Welle 29): je Sorte ein Tablett, und jede Reihe rollt.
## Der Fizzle-Weg bleibt als toter Rückfall stehen - packs_full() ist immer false.
const PACK_FIZZLE_MONEY := 3
var owned_packs: Array[Pack] = []
## Laufende Paket-Nummer: _stash_pack stempelt sie beim Einlagern. An ihr hängen
## Magazin-Platz, Vormerkung und Körper - Indizes brechen beim Umsortieren.
var pack_serial: int = 0
## Beim Händler hinterlegte Würfel: in der Chip-Schale gekauft, aber noch nicht
## eingetauscht. Sie liegen im Laden, bis der Spieler selbst bestimmt, welchen
## Pool-Platz sie übernehmen - der Automat sucht ihn sonst allein aus, und eine
## Essenz ist angeboren und nicht wiederbeschaffbar.
var pending_dice: Array[DieDefinition] = []
## Platzierte Nebenwetten der kommenden Runde; am Rundenende geprüft und geleert.
var active_side_bets: Array[SideBet] = []
## Steckplätze je Kombination (Key -> Array aus ComboPart oder null, Länge =
## socket_count). Gelesen wird über parts_of, geschrieben nur hier.
var combo_parts: Dictionary = {}
## Gekaufte oder gewonnene Module, die noch ihren Steckplatz suchen (wie
## pending_dice: die Strecke bis zur Wahl, kein Lager).
var pending_parts: Array[ComboPart] = []
## Bestandene Stresstests - jeder hebt den Energie-Deckel um eine Fünfergruppe.
var stress_tests_passed: int = 0
## Hitzestau: die für DIESE Runde stillgelegten Teile (Instanz-id -> true).
var heat_disabled_parts: Dictionary = {}

# Zustand der Effektkatalog-Charms:
## Echte Fumbles des Laufs (sinkt nie) und des laufenden Blocks.
var farkle_count: int = 0
var block_fumbles: int = 0
## Hitzestau: das Modul, das der letzte Fumble zerstört hat (null = keins) - für die Anzeige.
var last_fumble_lost_part: ComboPart = null
var lumpensammler_value: int = 0  # Glückszahl, je Runde neu (0 = kein Lumpensammler)
var old_penny_payouts: int = 0  # Glücksgroschen: wächst erst NACH jeder Auszahlung
## Rampenlicht: die hervorgehobene Kombination dieser Runde ("" = keine) und ob
## sie schon kassiert wurde - je Runde höchstens EIN Wachstum.
var spotlight_combo: String = ""
var spotlight_claimed_this_round: bool = false
## Dauerhaftes Wachstum je Kombination (key -> Vector2i(Basispunkte, Mult)).
var combo_growth: Dictionary = {}
const SPOTLIGHT_POINTS := 5
const SPOTLIGHT_MULT := 1
## Goldener Handschlag: die Klausel vergoldet je Runde genau EINEN Würfel.
var golden_handshake_used_this_round: bool = false

## Speicher der Phosphoreszenz je Würfel-Exemplar (Instanz-id des DieDefinition):
## Basispunkte, und unter der Leuchtstoffröhre auch der Mult. Beide SAMMELN über
## den ganzen Run - sie sterben erst mit dem Run, nicht mit der Runde.
var essence_phosphor_store: Dictionary = {}
var essence_phosphor_mult: Dictionary = {}
## Auslösungen und Krits der bisherigen Hände DIESER Runde - Dunkelkammer und
## Gewitterfront schleppen sie in die nächste Hand mit.
var round_trigger_count: int = 0
var round_crit_count: int = 0
## Fumbles dieser Runde (Vulkanblitz) und der RUN-lange Zähler der Fumbles, bei
## denen ein Vulkanblitz in der Grube lag. Der zweite wird immer mitgeführt; ob
## er zählt, entscheidet allein die Aschewolke.
var round_fumbles: int = 0
var ash_fumbles: int = 0
## Materiallose Würfel, die diese Runde schon gewertet haben (Neonmarker).
var round_bare_dice: int = 0
## Würfel-Exemplare, die diese Runde schon gewertet haben - ihre nächste Wertung
## ist keine Erstwertung mehr (Sternschnuppe, Gammablitz).
var die_scored_this_round: Dictionary = {}


## Sitzungszustand der Fumble-Automaten (überlebt Zoom/Runden, bis Fumble oder
## Auszahlung ihn zurücksetzt). Ökonomie läuft über spin_slot/redeem_slots.
var slot_bank := SlotMachine.new()

func _init() -> void:
	charms_changed.connect(sync_luck_die)  # Glückspilz & Co. drehen am wirkenden Glück

static func new_run() -> GameRun:
	var run := GameRun.new()
	for i in POOL_SIZE:
		run.owned_pool.append(DieDefinition.standard())
	run._roll_secret_stock()  # der Schwarzmarkt steht ab Runde 1 offen
	return run

## Wirkende Charm-ids für Wertungen: Totems (Papagei/Echo) liefern die id ihres
## Nachbarn statt der eigenen; ein Totem auf Totem/Leere bleibt wirkungslos.
func charm_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in _resolved_charms():
		ids.append(entry["id"])
	return ids

## Besitz-Slot je Position aus charm_ids(). Ein Totem ohne Nachbarn fällt aus
## der Wirkungsliste heraus, dadurch verschieben sich die Positionen gegen die
## Besitz-Slots - wer einen Charm ANZEIGEN will (Vitrine, Dock-Pad), muss
## hierüber umrechnen.
func charm_slots() -> Array[int]:
	var slots: Array[int] = []
	for entry in _resolved_charms():
		slots.append(int(entry["slot"]))
	return slots

## Wirkende Charms als {id, slot}: ein Totem übernimmt die WIRKUNG des Nachbarn,
## behält aber SEINEN Besitz-Slot - dort steht seine Vitrine.
func _resolved_charms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in owned_charms.size():
		var charm_id := owned_charms[i].id
		match charm_id:
			Charm.PARROT_TOTEM:
				charm_id = _neighbor_id(i - 1)
			Charm.ECHO_TOTEM:
				charm_id = _neighbor_id(i + 1)
		if charm_id != "":
			result.append({"id": charm_id, "slot": i})
	return result

## Rohe ids ohne Totem-Auflösung - für Besitz-Prüfungen und Anzeige.
func owned_charm_ids() -> Array[String]:
	var ids: Array[String] = []
	for charm in owned_charms:
		ids.append(charm.id)
	return ids

func _neighbor_id(index: int) -> String:
	if index < 0 or index >= owned_charms.size():
		return ""
	var neighbor_id := owned_charms[index].id
	if neighbor_id == Charm.PARROT_TOTEM or neighbor_id == Charm.ECHO_TOTEM:
		return ""  # Totems kopieren keine Totems
	return neighbor_id

## Jede Geld-Buchung des Laufs. Happy Hour/Alles auf Rot vervielfachen NUR
## Einnahmen - ein Faktor auf Ausgaben würde Preise heimlich verteuern.
func add_money(amount: int) -> void:
	if amount > 0:
		amount = roundi(amount * money_gain_factor())
	money += amount

## Faktor auf jede positive Geld-Buchung der Runde (Happy Hour, Alles auf Rot).
## Bewusst hingenommen: ein verdoppelter Vorschuss läuft unter verdoppelter Happy
## Hour durch add_money und wird dort ein zweites Mal gehoben - der Winkeladvokat
## bearbeitet jede Klausel einzeln, nicht die Summe am Ende.
func money_gain_factor() -> float:
	if _clause_active(DealClause.BLACKOUT):
		return 0.0
	var factor := 1.0
	var boost := deal_bonus_factor()
	if _clause_active(DealClause.HAPPY_HOUR):
		factor *= 2.0 * boost
	if _clause_active(DealClause.ALL_ON_RED):
		factor *= 3.0 * boost
	return factor

## Rücknahme einer AUSGABE (Kleingedrucktes): das Geld hat den Lauf nie verlassen,
## also greift kein Einnahme-Faktor. Liefe eine Erstattung durch add_money, machte
## die Happy Hour aus jedem Paketkauf ein Geschäft - $6 hin, $24 zurück.
func refund_money(amount: int) -> void:
	money += maxi(0, amount)

# --- Fortschrittsstufe ---------------------------------------------------------

## 1..TIER_MAX aus dem Glück - ohne Glücks-Klauseln zwei Stufen je Block.
func progress_tier() -> int:
	return clampi(1 + effective_luck() / LUCK_PER_TIER, 1, TIER_MAX)

## Glückspilz: so viel Glück legt er drauf, solange er im Dock steht.
const LUCKY_MUSHROOM_LUCK := 5

## Das WIRKENDE Glück: der Laufzustand plus, was gehaltene Charms dazulegen.
func effective_luck() -> int:
	return luck + LUCKY_MUSHROOM_LUCK * charm_ids().count(Charm.LUCKY_MUSHROOM)

## Glück, ab dem die nächste Stufe kommt (-1 = schon die letzte).
func next_tier_luck() -> int:
	if progress_tier() >= TIER_MAX:
		return -1
	return progress_tier() * LUCK_PER_TIER

## Glück ändern (nie unter 0).
func add_luck(amount: int) -> void:
	luck = maxi(0, luck + amount)

## Der EINE Schreiber des Glückswürfels: Augen ans wirkende Glück angleichen und jede
## Änderung melden (die Zeremonie zeigt sie nur).
func sync_luck_die(rng: RandomNumberGenerator = null) -> Array:
	var changes := luck_die.sync(effective_luck(), rng)
	if not changes.is_empty():
		luck_die_changed.emit(changes)
	return changes

## Der Hover des Glückswürfels: "Glückswürfel · Glück 7 · nächstes Auge bei 10".
func luck_die_hint() -> String:
	var lucky := effective_luck()
	var next := LuckDie.next_threshold(lucky)
	var tail := "alle Seiten voll" if next < 0 else "nächstes Auge bei %d" % next
	return "Glückswürfel · Glück %d · %s" % [lucky, tail]

## Was die GLÜCKS-STATION zeigt, als reine Daten (free_bonus 0 = nichts zu holen).
func luck_station_state() -> Dictionary:
	var lucky := effective_luck()
	return {
		"luck": lucky,
		"prev": LuckDie.prev_threshold(lucky),
		"next": LuckDie.next_threshold(lucky),
		"expected": luck_die.expected(),
		"free_bonus": _free_hand_bonus(),
		"keeps": module_keeps,
	}

## Hinweis-Texte der drei Lauf-Anzeigen am Hub (die Anzeige kennt keinen GameRun).
func blind_hint() -> String:
	var percent := roundi(blind_growth(round_number + 1) * 100.0)
	return "Wächst je Runde um %d%% (dieser Block); Verträge heben ihn dauerhaft." % percent

func luck_hint() -> String:
	var text := "Stufe %d. " % progress_tier()
	var next := next_tier_luck()
	text += "Höchste Stufe erreicht." if next < 0 else "Ab Glück %d kommt Stufe %d." % [next, progress_tier() + 1]
	var eye := LuckDie.next_threshold(effective_luck())
	if eye >= 0:
		text += " Ab Glück %d bekommt der Glückswürfel ein Auge." % eye
	return text + " Jede geschaffte Runde bringt +1 Glück; die Stufe hebt Laden-Seltenheit, Wetten, Würfel und Automaten."

func fumble_hint() -> String:
	var lines := fumble_readers()
	var head := "%d in diesem Block." % block_fumbles
	if lines.is_empty():
		return head + " Noch liest nichts den Zähler."
	var nl := String.chr(10)
	return head + nl + nl.join(lines)

## Der EINE Weg an einen Prämien-Würfel: frisch gewürfelt, Seele garantiert,
## gratis ins Ausgabefach - und von dort SOFORT auf einen Vorrats-Platz. Liefert das
## HINTERLEGTE Exemplar - die Zeremonie fliegt genau dieses an. null = keine Vorlage.
func _grant_reward_die() -> DieDefinition:
	var die := DiceOffer.roll_reward_die(charm_ids(), owned_essence_ids(), progress_tier())
	if die == null:
		return null
	stash_die(die, 0)
	return pending_dice[pending_dice.size() - 1]

## --- Aus der Fortschrittsstufe abgeleitete Leitern ----------------------------
## Alles läuft über diese Abfragen, damit Aufrufer nie rohe Stufen vergleichen.

## Wirksame Zahl an Überladungs-Stufen: der Rahmen steht fest, Klauseln
## verschieben ihn. Erst der Deckel, dann der Bonus - Stufendeckel UND
## Hochspannung zusammen ergeben also Stufe 5, nicht 2. Hochspannung wird
## bewusst NICHT auf OVERCHARGE_STAGES geklemmt; die Stufengrößen bremsen selbst.
func max_overcharge_stages() -> int:
	var stages := overcharge_frame()
	if _clause_active(DealClause.STAGE_CAP):
		stages = mini(stages, STAGE_CAP_LIMIT)
	if _clause_active(DealClause.HIGH_VOLTAGE):
		stages += HIGH_VOLTAGE_STAGES * deal_bonus_factor()
	if _clause_active(DealClause.SUPERCONDUCTOR):
		stages = UNLIMITED_OVERCHARGE_STAGES
	return stages

## Rahmen OHNE Klausel-Wirkungen: fünf Stufen ab Runde 1, nur Klauseln
## verschieben ihn.
func overcharge_frame() -> int:
	return 5

## Halbierte Blätter-Gebühr ab TIER_CHEAP_FLIP (stapelt mit dem Wechselgeld-Charm);
## Freies Blättern macht sie 0, solange Gratis-Seiten übrig sind, der Blätter-Aufschlag verdoppelt sie.
func shop_flip_fee_factor() -> float:
	if free_flips_left() > 0:
		return 0.0
	var factor := 0.5 if progress_tier() >= TIER_CHEAP_FLIP else 1.0
	if _clause_active(DealClause.FLIP_SURCHARGE):
		factor *= 2.0
	return factor

func free_flips_left() -> int:
	if not _clause_active(DealClause.FREE_FLIP):
		return 0
	return maxi(0, FREE_FLIPS * deal_bonus_factor() - free_flips_used)

## Eine neue Doppelseite ist aufgeschlagen: eine Gratis-Seite verbraucht, falls übrig.
func note_shop_flip() -> void:
	if free_flips_left() > 0:
		free_flips_used += 1

## Die Fortschrittsstufe, mit der der LADEN würfelt (Seltenheit, Multiplikator,
## Sonderposten, Würfel-Augen).
func shop_tier() -> int:
	return progress_tier()

func shop_tier_weights() -> Array:
	return Pack.TIER_WEIGHTS

## Kennerblick: so viele legendäre Charms führt jede Doppelseite sicher (0 = keine Garantie).
func shop_guaranteed_legendaries() -> int:
	return deal_bonus_factor() if _clause_active(DealClause.CONNOISSEUR_EYE) else 0

## Ladenhüter: der Laden führt nur gewöhnliche Charms.
func shop_common_charms_only() -> bool:
	return _clause_active(DealClause.SHELF_WARMER)

## Seelen-Regel der Laden-Würfel ({"chance", "boost"}): Seelenmarkt immer mit Seele
## und seltene ×2, Seelenlos nie.
func shop_soul_rule() -> Dictionary:
	if _clause_active(DealClause.SOULLESS):
		return {"chance": 0.0, "boost": 1.0}
	if _clause_active(DealClause.SOUL_MARKET):
		return {"chance": 1.0, "boost": 2.0}
	return {}

## Wie viele Paket-Plätze der Laden belegt - die Plätze bleiben stehen, Leere Regale
## lassen die hinteren leer wie verkauft.
func shop_packs_offered() -> int:
	if _clause_active(DealClause.EMPTY_SHELVES):
		return maxi(1, SHOP_PACK_PLACES - EMPTY_SHELVES_CUT)
	return SHOP_PACK_PLACES

## Die Art eines Paket-Platzes (LANE_*) aus einem Wurf in [0, 1).
static func shop_pack_kind_for(roll: float) -> int:
	var total := 0
	for lane: int in SHOP_PACK_KIND_WEIGHTS:
		total += int(SHOP_PACK_KIND_WEIGHTS[lane])
	var at := roll * float(total)
	for lane: int in SHOP_PACK_KIND_WEIGHTS:
		at -= float(SHOP_PACK_KIND_WEIGHTS[lane])
		if at < 0.0:
			return lane
	return LANE_CARDS

## Raritäts-Stufe der Shop-Ware: 0 keine, 1 ungewöhnlich, 2 selten, 3 legendär.
## Steuert den garantierten Premium-Charm + die Gravur-Mindestrarität.
func shop_rarity_tier() -> int:
	var tier := shop_tier()
	if tier >= TIER_RARITY_LEGENDARY:
		return 3
	if tier >= TIER_RARITY_RARE:
		return 2
	if tier >= TIER_RARITY_UNCOMMON:
		return 1
	return 0

func shop_charm_slots() -> int:
	return SHOP_CHARM_SLOTS

func shop_pack_places() -> int:
	return SHOP_PACK_PLACES

## Chance auf EINEN Sonderposten in der Auslage (0 = keiner). Höchstens einer je
## Doppelseite: er ersetzt einen zufälligen Paket-Platz, statt einen dazuzustellen.
func shop_special_chance() -> float:
	var tier := shop_tier()
	if tier < SHOP_SPECIAL_TIER:
		return 0.0
	return float(SHOP_SPECIAL_CHANCE.get(tier, 0.0))

## Chance, daß eine Zahlen-Karte im Regal als MULTIPLIKATOR-NETZ ausliegt: selten am
## Anfang, mit jeder Fortschrittsstufe häufiger.
const MULTIPLIER_CHANCE_BASE := 0.04
const MULTIPLIER_CHANCE_STEP := 0.02
const MULTIPLIER_CHANCE_CAP := 0.25

func shop_multiplier_chance() -> float:
	var chance := MULTIPLIER_CHANCE_BASE \
		+ MULTIPLIER_CHANCE_STEP * float(maxi(shop_tier() - 1, 0))
	return minf(chance, MULTIPLIER_CHANCE_CAP)

## Kauf aus der Chip-Schale: bezahlt und SOFORT einzusetzen - pending_dice ist kein
## Zwischenlager, sondern die Strecke bis zum Raster (scene_root erzwingt die Wahl,
## siehe *Der ZWANG*). Hinterlegt wird eine eigene Instanz, denn die Auslage hält
## das Original weiter (Referenz-Regel).
func stash_die(def: DieDefinition, price: int) -> void:
	add_money(-price)
	pending_dice.append(def.instantiate())
	pending_dice_changed.emit()

## Bestandener Stresstest: EIN frisch gewürfelter Würfel mit Seelengarantie, gratis
## ins Ausgabefach. Liefert das hinterlegte
## Exemplar (null = keine Vorlage); zerfallen kann er nicht.
## Dazu ein PROJEKTOR, solange ein Port frei ist (Spieler-Entscheid 2026-11-23).
func grant_stress_reward() -> DieDefinition:
	stress_tests_passed += 1
	if projectors < MAX_PROJECTORS:
		_add_projector()
	return _grant_reward_die()

## Löst einen hinterlegten Würfel gegen einen Pool-Platz ein - der EINE Weg, auf dem
## ein Würfel den Vorrat je erreicht, und der Spieler geht ihn SOFORT. Der Pool-Eintrag
## wird IN SEINER Instanz überschrieben (become), nie getauscht - Rundendeck,
## Trays und Raster halten dieselbe Referenz. Gewarnt wird nicht: der Essenz-Chip
## im Raster zeigt vorher, welche Seele hier überschrieben würde.
func exchange_pending_die(pending_index: int, pool_index: int) -> bool:
	if pending_index < 0 or pending_index >= pending_dice.size():
		return false
	if pool_index < 0 or pool_index >= owned_pool.size():
		return false
	owned_pool[pool_index].become(pending_dice[pending_index])
	pending_dice.remove_at(pending_index)
	pool_changed.emit()
	pending_dice_changed.emit()
	return true

## Kauft einen Charm - der Preis wird nur fällig, wenn der Dock ihn auch aufnimmt.
func purchase_charm(charm: Charm, price: int) -> bool:
	if charms_full():
		return false
	add_money(-price)
	return _grant_charm(charm)

var projectors: int = START_PROJECTORS

func charm_capacity() -> int:
	return projectors

## Sind alle Projektoren belegt, gibt es KEINE Warteschlange - ein weiterer Charm ist
## nicht kaufbar.
func charms_full() -> bool:
	return owned_charms.size() >= charm_capacity()

## -1 = alle Ports belegt.
func projector_price() -> int:
	if projectors >= MAX_PROJECTORS:
		return -1
	return PROJECTOR_PRICE_STEP * (projectors - START_PROJECTORS + 1)

func _add_projector() -> void:
	projectors += 1
	projectors_changed.emit()
	charms_changed.emit()  # ein Platz ist frei geworden: Läden und Reihe ziehen nach

## Einziger Einzug eines Charms - Laden wie Schwarzmarkt gehen hier durch, damit
## der Sonderfall Lumpensammler (Glückszahl sofort würfeln) nie auseinanderläuft.
## false = der Dock ist voll, der Charm ist NICHT eingezogen.
func _grant_charm(charm: Charm) -> bool:
	if charms_full():
		return false
	owned_charms.append(charm)
	if charm.id == Charm.RAG_COLLECTOR:
		_roll_lumpensammler_value()
	charms_changed.emit()
	return true

## Reihenfolge ist spielrelevant: Totems kopieren Nachbarn, sie bestimmt die
## Tisch-Plätze (CharmRowView).
func move_charm(from_index: int, to_index: int) -> void:
	if from_index == to_index \
			or from_index < 0 or from_index >= owned_charms.size() \
			or to_index < 0 or to_index >= owned_charms.size():
		return
	var charm := owned_charms[from_index]
	owned_charms.remove_at(from_index)
	owned_charms.insert(to_index, charm)
	charms_changed.emit()

## Effektiver Verkaufserlös des Charms auf Platz index (Basis + Charm-Boni).
func charm_sell_value(index: int) -> int:
	if index < 0 or index >= owned_charms.size():
		return 0
	var value := CharmEffects.charm_sell_value(owned_charms[index].sell_value, charm_ids())
	if _clause_active(DealClause.BUYBACK):
		value = maxi(value, owned_charms[index].price)  # Rückkaufrecht: voller Preis
	return value

## Verkauft den Charm auf Platz index: entfernt ihn, Erlös aufs Konto.
func sell_charm(index: int) -> void:
	if index < 0 or index >= owned_charms.size():
		return
	var value := charm_sell_value(index)
	owned_charms.remove_at(index)
	add_money(value)
	charms_changed.emit()

# --- Pakete (Kauf im Laden, Öffnen in der Werkstatt) --------------------------

## Legt ein Fixinhalt-Paket mit genau dieser Gravur ins Lager - der Weg, den seit
## dem Werkstatt-Umbau JEDE Quelle geht, die früher lose Gravuren lieferte
## (Schmuckkästchen, Ernte, Schwarzmarkt).
func grant_engraving_pack(engraving: Engraving) -> Pack:
	if engraving == null:
		return null
	return grant_pack(Pack.fixed_engraving_pack(engraving))

## Fixinhalt-Paket zur Material-Gravur eines Materials. Liefert das Paket - die
## Zeremonien zielen ihre Kometen auf seine uid.
func grant_material_pack(material: DieMaterial) -> Pack:
	if material == null:
		return null
	return grant_engraving_pack(Engraving.material_engraving(material,
		Engraving.MATERIAL_RARITY.get(material.id, Engraving.Rarity.UNCOMMON)))

## Kauft ein versiegeltes Paket. Erst zahlen, dann würfelt das Kleingedruckte auf
## volle Rückerstattung - in dieser Reihenfolge, damit eine knappe Börse den Kauf
## weiter sperrt und der Erstattungswurf nie im Preis mitgerechnet wird. Liefert
## das zurückgegebene Geld (0 = keins); rng injizierbar, damit ein Test beide
## Ausgänge erzwingt.
func purchase_pack(pack: Pack, price: int, rng: RandomNumberGenerator = null) -> int:
	if packs_full():
		return 0  # prüfen VOR dem Zahlen - wie purchase_charm bei vollem Dock
	add_money(-price)
	grant_pack(pack)
	var chance := CharmEffects.pack_refund_chance(charm_ids())
	if price <= 0 or chance <= 0.0:
		return 0  # erst prüfen, dann würfeln: ohne Charm wird gar nicht gezogen
	if (rng.randf() if rng != null else randf()) >= chance:
		return 0
	refund_money(price)
	return price

## Was das Kleingedruckte beim letzten Paket-Kauf zurückgab (0 = nichts).
var last_card_pack_refund := 0

# --- Die PAKET-AUSWAHL -------------------------------------------------------------
# Ein Paket wird beim ÖFFNEN gewürfelt: Optionen und Zahl der Wahlen
# stehen ab da fest (Buchung vor dem Licht). Gebucht wird jede Wahl beim Bestätigen.

## Geöffnete Pakete, die noch auf ihre Wahl warten - eines nach dem anderen.
var pending_pack_choices: Array[PackChoice] = []
## In dieser Runde geöffnete Pakete (Freie Hand gilt nur dem ersten).
var packs_opened_this_round: int = 0
## Neu gemischt (Charm): der Gratis-Neuwurf dieser Runde ist verbraucht.
var free_reshuffle_used_this_round: bool = false
## Neu mischen kostet so viel ⚡.
const PACK_RESHUFFLE_ENERGY := 1
## Sammelalbum: so viel Geld je geöffnetem Paket und Kopie.
const ALBUM_MONEY := 1

## Kauft ein KARTEN-PAKET: zahlen, Kleingedrucktes würfeln, sofort ÖFFNEN.
## null = nichts gebucht.
func purchase_card_pack(card_pack: CardPack, price: int,
		rng: RandomNumberGenerator = null) -> PackChoice:
	return _purchase_open(card_pack, price, rng)

## Kauft ein WÜRFEL-PAKET - derselbe Weg.
func purchase_dice_pack(dice_pack: DicePack, price: int,
		rng: RandomNumberGenerator = null) -> PackChoice:
	return _purchase_open(dice_pack, price, rng)

func _purchase_open(pack: Resource, price: int, rng: RandomNumberGenerator) -> PackChoice:
	last_card_pack_refund = 0
	if pack == null:
		return null
	add_money(-price)
	_roll_purchase_refund(price, rng)
	return _open_pack(pack.duplicate(), false, rng)

## Das Kleingedruckte: volle Erstattung mit Glück (gemerkt in last_card_pack_refund).
func _roll_purchase_refund(price: int, rng: RandomNumberGenerator) -> void:
	var chance := CharmEffects.pack_refund_chance(charm_ids())
	if price > 0 and chance > 0.0 and (rng.randf() if rng != null else randf()) < chance:
		refund_money(price)
		last_card_pack_refund = price

## Kauft ein MODUL-PAKET: zahlen, die Optionen der Größe würfeln - ALLE fallen nach
## pending_parts -, und der Glückswürfel sagt, wie viele davon EINGEBAUT werden dürfen
## (module_keeps; der Rest verfällt mit dem Beutel). Leer = nichts gekauft.
func purchase_module_pack(module_pack: ModulePack, price: int,
		rng: RandomNumberGenerator = null) -> Array[ComboPart]:
	var out: Array[ComboPart] = []
	last_card_pack_refund = 0
	if module_pack == null:
		return out
	add_money(-price)
	_roll_purchase_refund(price, rng)
	var face := luck_die.roll(rng)
	var bonus := _free_hand_bonus()
	packs_opened_this_round += 1
	for part in ModulePack.roll_contents(module_pack, ModulePack.option_count(module_pack.size), rng):
		stash_part(part, true)
		out.append(pending_parts[pending_parts.size() - 1])
	var keeps := mini(luck_die.value(face) + bonus, out.size())
	module_keeps += keeps
	last_module_roll = {"face": face, "value": luck_die.value(face), "keeps": keeps}
	return out

## Wie viele Paket-Module noch EINGEBAUT werden dürfen (die Würfe aller offenen Beutel).
var module_keeps := 0
## Der letzte Wurf eines Modul-Pakets {face, value, keeps} - die Zeremonie liest ihn.
var last_module_roll := {}
## Was der letzte Einbau verfallen ließ (der Wurf ist aufgebraucht) - für die Zeremonie.
var last_lapsed_parts: Array[ComboPart] = []

## Freie Hand: das erste geöffnete Paket der Runde bekommt Wahlen dazu.
func _free_hand_bonus() -> int:
	if _clause_active(DealClause.FREE_HAND):
		return deal_bonus_factor()
	return 0

## Der Glückswürfel fällt beim Öffnen (gebucht in der Auswahl).
func _roll_luck_die(choice: PackChoice, rng: RandomNumberGenerator) -> void:
	choice.die_face = luck_die.roll(rng)
	choice.die_value = luck_die.value(choice.die_face)
	choice.free_bonus = _free_hand_bonus()

func _choice_picks(choice: PackChoice) -> int:
	return mini(choice.die_value + choice.free_bonus, choice.options.size())

# --- Die PAKET-ARTEN ---------------------------------------------------------------

const LANE_CARDS := 0
const LANE_DICE := 1
const LANE_MODULES := 2
## Jeder Platz würfelt seine Art unabhängig: Karten 3 : Würfel 2 : Module 1, keine Garantie.
const SHOP_PACK_KIND_WEIGHTS := {LANE_CARDS: 3, LANE_DICE: 2, LANE_MODULES: 1}

## Die Art eines Pakets (LANE_*).
static func pack_kind_of(pack: Resource) -> int:
	if pack is DicePack:
		return LANE_DICE
	if pack is ModulePack:
		return LANE_MODULES
	return LANE_CARDS

## Ein Gewinn-Paket öffnet sofort.
func _award_pack(pack: Resource, rng: RandomNumberGenerator) -> PackChoice:
	if pack == null:
		return null
	return _open_pack(pack, true, rng)

## Öffnet ein Paket in die Warteschlange der Auswahl.
func _open_pack(pack: Resource, from_bet: bool, rng: RandomNumberGenerator) -> PackChoice:
	var choice := PackChoice.new()
	choice.pack = pack
	choice.from_bet = from_bet
	choice.kind = PackChoice.KIND_DICE if pack is DicePack else PackChoice.KIND_CARDS
	_roll_luck_die(choice, rng)
	if pack is DicePack:
		_roll_dice_choice(choice, rng)
	else:
		choice.options = _roll_pack_options(pack, CardPack.option_count(int(pack.get("size"))), rng)
	choice.picks = _choice_picks(choice)
	return _queue_opened(choice)

func _queue_opened(choice: PackChoice) -> PackChoice:
	packs_opened_this_round += 1
	pending_pack_choices.append(choice)
	var album := charm_ids().count(Charm.ALBUM)
	if album > 0:
		add_money(ALBUM_MONEY * album)
	return choice

## Die Optionen eines KARTEN-Pakets nach seiner Sorte.
func _roll_pack_options(pack: Resource, count: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if pack is CardPack:
		for card in CardPack.roll_contents(pack as CardPack, shop_multiplier_chance(),
				rng, count):
			out.append(card)
	return out

## Ein WÜRFEL-Paket würfelt GENAU so viele Würfel wie Augen - gebucht in der Auswahl,
## mit dem Glück der Güte obendrauf. Die Wahlen sagt der Glückswürfel.
func _roll_dice_choice(choice: PackChoice, rng: RandomNumberGenerator) -> void:
	var dice_pack := choice.pack as DicePack
	var luck := pack_luck(dice_pack)
	var count := DicePack.base_count(dice_pack.size)
	choice.base_count = count
	var souls := owned_essence_ids()
	choice.options = []
	for i in count:
		var die := DiceOffer.roll_pack_die(dice_pack.sort, shop_tier(), charm_ids(), souls,
			shop_soul_rule(), luck)
		if die != null:
			choice.options.append(die)

## Das Glück, mit dem ein Paket seinen INHALT würfelt: das wirkende Glück plus das seiner
## Güte (Würfel- und Karten-Pakete; Modul-Pakete haben keine). Den Glückswürfel hebt es nicht.
func pack_luck(pack: Resource) -> int:
	if pack is DicePack or pack is CardPack:
		return effective_luck() + DicePack.quality_luck(int(pack.get("quality")))
	return effective_luck()

## Die Güte-Gewichte der Würfel-Pakete im Laden (Haken für künftige Klauseln).
func shop_dice_pack_quality_weights() -> Array:
	return DicePack.shop_quality_weights(shop_tier())

## Die Güte-Gewichte der Karten-Pakete - dieselbe Leiter wie bei den Würfel-Paketen.
func shop_card_pack_quality_weights() -> Array:
	return DicePack.shop_quality_weights(shop_tier())

## Die Auswahl, die gerade dran ist (null = keine).
func current_pack_choice() -> PackChoice:
	return pending_pack_choices[0] if not pending_pack_choices.is_empty() else null

## Was Neu mischen gerade kostet (0 = gratis, -1 = nicht mehr erlaubt).
func pack_reshuffle_cost(choice: PackChoice) -> int:
	# Würfel-Pakete mischen nie neu (Spieler-Entscheid 2026-11-17).
	if choice == null or choice.rerolled or choice.is_dice():
		return -1
	if charm_ids().has(Charm.RESHUFFLE) and not free_reshuffle_used_this_round:
		return 0
	return PACK_RESHUFFLE_ENERGY

func can_reshuffle_pack(choice: PackChoice) -> bool:
	var cost := pack_reshuffle_cost(choice)
	return cost >= 0 and energy >= cost

## NEU MISCHEN: Karten-Pakete tauschen die Optionen (Zahl und Wahlen bleiben),
## Würfel-Pakete würfeln ALLES neu - Zahl, Würfel, Wahlen.
func reshuffle_pack_choice(choice: PackChoice, rng: RandomNumberGenerator = null) -> bool:
	if not can_reshuffle_pack(choice) or not pending_pack_choices.has(choice):
		return false
	var cost := pack_reshuffle_cost(choice)
	if cost == 0:
		free_reshuffle_used_this_round = true
	else:
		spend_energy(cost)
	if choice.is_dice():
		_roll_dice_choice(choice, rng)
		choice.picks = _choice_picks(choice)
		choice.rerolled = true
		return true
	choice.options = _roll_pack_options(choice.pack, choice.options.size(), rng)
	choice.picks = mini(choice.picks, choice.options.size())
	choice.rerolled = true
	return true

## BESTÄTIGEN eines KARTEN-Pakets: jede gewählte Karte geht ins Magazin, Ungewähltes
## verfällt (Würfel-Pakete bucht confirm_dice_choice). Liefert {"cards": Array[Pack]}
## (leer bei ungültiger Wahl).
func confirm_pack_choice(choice: PackChoice, indices: Array) -> Dictionary:
	var result := {"cards": [] as Array[Pack]}
	if choice == null or choice.is_dice() or not pending_pack_choices.has(choice) \
			or not choice.valid_selection(indices):
		return result
	pending_pack_choices.erase(choice)
	var sorted := indices.duplicate()
	sorted.sort()
	for index in sorted:
		var card := grant_pack(choice.options[int(index)] as Pack)
		if card != null:
			(result["cards"] as Array[Pack]).append(card)
	return result

## WÄHLEN IST EINSETZEN: assignments = {Options-Index: Pool-Index}. Bucht ALLE Paare
## atomar per become in die Pool-Instanzen (ein pool_changed) und liefert je Paar
## {option (die Pool-Instanz), option_index, pool_index, replaced (Kopie des alten
## Würfels)}. Ungültig =
## nichts gebucht, leeres Array; ein leeres Dictionary schließt die Auswahl ("Nichts nehmen").
func confirm_dice_choice(choice: PackChoice, assignments: Dictionary) -> Array:
	var out: Array = []
	if choice == null or not choice.is_dice() or not pending_pack_choices.has(choice) \
			or not choice.valid_selection(assignments.keys()):
		return out
	var seats := {}
	for key in assignments:
		var seat := int(assignments[key])
		if seat < 0 or seat >= owned_pool.size() or seats.has(seat) \
				or not (choice.options[int(key)] is DieDefinition):
			return out
		seats[seat] = true
	pending_pack_choices.erase(choice)
	var keys := assignments.keys()
	keys.sort()
	for key in keys:
		var seat := int(assignments[key])
		var option := (choice.options[int(key)] as DieDefinition).instantiate()
		var replaced := owned_pool[seat].instantiate()
		owned_pool[seat].become(option)
		out.append({"option": owned_pool[seat], "option_index": int(key), "pool_index": seat,
			"replaced": replaced})
	if not out.is_empty():
		pool_changed.emit()
	return out

## Der EINE Einlagerungsweg: stempelt die uid und legt das Paket an seinen Platz
## in der Magazin-Ordnung - die ist seit dem 2026-10-28 IMMER nach Typ sortiert
## (Spieler-Wunsch), eine Lieferung landet also mitten unter ihresgleichen.
## Bewusst ohne Signal: das setzt der Aufrufer, damit eine Sammellieferung nur
## einmal meldet. Das Magazin ist unbegrenzt - null kommt hier nie mehr zurück.
func _stash_pack(pack: Pack) -> Pack:
	pack_serial += 1
	pack.pack_uid = pack_serial
	owned_packs.append(pack)
	_sort_packs()
	return pack

## Das Magazin ist UNBEGRENZT (Welle 29) - die Frage bleibt für ihre Aufrufer stehen.
func packs_full() -> bool:
	return false

## Freie Plätze im Magazin - unbegrenzt, also mehr als jedes Bündel je verlangt.
func pack_room() -> int:
	return PACK_ROOM_UNBOUNDED

const PACK_ROOM_UNBOUNDED := 1 << 20

# --- Das SORTEN-MODELL des Magazins -----------------------------------------------
# Je Sorte (Pack.SHELF_ORDER) EIN Tablett; eine Karte liegt IMMER im Tablett ihrer
# Sorte, ihr PLATZ ist ihr Rang unter den Paketen dieser Sorte in Listenordnung.

## Das TABLETT eines Pakets (-1 = liegt nicht im Lager).
func pack_tray_of(uid: int) -> int:
	var pack := pack_by_uid(uid)
	return Pack.shelf_rank(pack) if pack != null else -1

## Sein PLATZ im Tablett: der Rang unter den Paketen DERSELBEN Sorte.
func pack_cell_of(uid: int) -> int:
	var index := pack_index_of(uid)
	if index < 0:
		return -1
	var tray := Pack.shelf_rank(owned_packs[index])
	var cell := 0
	for i in index:
		if Pack.shelf_rank(owned_packs[i]) == tray:
			cell += 1
	return cell

## Wie viele Pakete im Tablett liegen.
func pack_tray_count(tray: int) -> int:
	var count := 0
	for pack in owned_packs:
		if Pack.shelf_rank(pack) == tray:
			count += 1
	return count

## Wohin die NÄCHSTE Lieferung DIESES Pakets fällt: {Tablett, Platz}; extra staffelt
## eine Salve derselben Sorte.
func next_pack_spot(pack: Pack, extra: int = 0) -> Vector2i:
	var tray := Pack.shelf_rank(pack)
	# Sortiert: sie landet HINTER allen ihres Typs (ihre uid ist die größte).
	var type_key := _type_key(pack)
	var before := 0
	for owned in owned_packs:
		if Pack.shelf_rank(owned) == tray and _type_key(owned) <= type_key:
			before += 1
	return Vector2i(tray, before + maxi(extra, 0))

## Volles Magazin: die Prämie zerfällt zu Geld statt still zu verschwinden. Es ist
## EINKOMMEN wie die liegengebliebene Pressbeute, also add_money (Multiplikatoren
## gelten) - refund_money ist die Umkehr einer Ausgabe und hier falsch.
func _fizzle_pack() -> void:
	add_money(PACK_FIZZLE_MONEY)

## Das Paket zu einer uid (null = liegt nicht im Lager).
func pack_by_uid(uid: int) -> Pack:
	var index := pack_index_of(uid)
	return owned_packs[index] if index >= 0 else null

func pack_index_of(uid: int) -> int:
	if uid <= 0:
		return -1
	for i in owned_packs.size():
		if owned_packs[i].pack_uid == uid:
			return i
	return -1

## Räumt das Magazin auf: nach Typ (_type_key), dann uid. Seit die Ordnung immer
## sortiert ist (2026-10-28), ändert das nur noch etwas, wenn sich ein Netz geändert
## hat - die Verdichtung sortiert ihren Rohling selbst nach.
func tidy_packs() -> void:
	if owned_packs.size() < 2:
		return
	_sort_packs()
	packs_changed.emit()

func _sort_packs() -> void:
	owned_packs.sort_custom(func(a: Pack, b: Pack) -> bool:
		return _tidy_key(a) < _tidy_key(b))

## Sortierschlüssel eines Pakets: Typ, dann uid - der explizite Endvergleich, weil
## sort_custom nicht stabil ist.
func _tidy_key(pack: Pack) -> Array:
	return _type_key(pack) + [pack.pack_uid]

## Der TYP eines Pakets: Sorten-Rang, Inhalts-id und - für Material- und Runen-Karten,
## deren Inhalt sonst gleich hieße - das häufigste Material bzw. die häufigste Rune
## ihres Netzes. So liegen Glas-Karten bei Glas-Karten.
func _type_key(pack: Pack) -> Array:
	var shelf_rank := Pack.SHELF_ORDER.find(Pack.shelf_of(pack))
	if shelf_rank < 0:
		shelf_rank = Pack.SHELF_ORDER.size()
	var content := pack.type
	if pack.is_catalyst():
		content = pack.catalyst_id
	elif pack.is_operator():
		content = pack.operator_id
	elif pack.blank_id != "":
		content = Pack.BLANK
	elif pack.is_multiplier():
		content = Pack.MULTIPLIER_NAME
	elif pack.fixed_engraving != null:
		content = pack.fixed_engraving.id
	return [shelf_rank, content, _dominant_id(pack.stamp_net)]

## Die häufigste Material- bzw. Runen-id eines Netzes ("" = keine); gleich häufige
## entscheidet die id selbst, damit der Schlüssel fest steht.
static func _dominant_id(net: Array) -> String:
	var counts := {}
	for cell in net:
		if cell is Dictionary and (cell.get("kind") == StampNet.KIND_MATERIAL
				or cell.get("kind") == StampNet.KIND_RUNE):
			var id := String(cell.get("id", ""))
			counts[id] = int(counts.get(id, 0)) + 1
	var best := ""
	var most := 0
	for id: String in counts:
		var count := int(counts[id])
		if count > most or (count == most and id < best):
			best = id
			most = count
	return best

## Legt ein Paket ohne Zahlung ins Lager (Wett-Gewinn). null = das Magazin war
## voll, das Paket ist zu Geld zerfallen (gebucht) - der Aufrufer fliegt dann Geld
## statt einer Kassette.
func grant_pack(pack: Pack) -> Pack:
	var stashed := _stash_pack(pack)
	if stashed == null:
		_fizzle_pack()
		return null
	packs_changed.emit()
	return stashed

## Eine ganze Lieferung auf einmal - EINE Bestandsmeldung, sonst baut das Regal
## bei einer Testlieferung achtzigmal neu. Liefert je übergebenem Paket seinen
## Platz in der Antwort: das gelandete Paket oder null für ein zerfallenes. So
## bleibt die Zuordnung Exemplar -> Zeremonie erhalten, auch wenn nur ein Teil
## der Salve noch Platz fand.
func grant_packs(packs: Array[Pack]) -> Array[Pack]:
	var landed: Array[Pack] = []
	if packs.is_empty():
		return landed
	var any := false
	for pack in packs:
		var stashed := _stash_pack(pack)
		landed.append(stashed)
		if stashed == null:
			_fizzle_pack()
		else:
			any = true
	if any:
		packs_changed.emit()
	return landed

# --- Die SERIENSCHALTUNG: Kassetten in Reihe, EINE Projektion -----------------

## --- Die SERIENLÄNGE ----------------------------------------------------------
## Die Walze hat sechs Scheiben; ein Lauf beginnt mit ZWEI freigeschalteten, jede
## weitere kostet Energie = bisherige Scheiben + 1 (Spieler-Entscheid 2026-11-23).
const START_DRUM_SLOTS := 2
## Deckel = Scheiben der Walze (Layout E, Spieler-Entscheid 2026-11-25).
const SERIES_SLOT_CAP := 6

var drum_slots: int = START_DRUM_SLOTS

func series_slots() -> int:
	return clampi(drum_slots, 1, SERIES_SLOT_CAP)

## ⚡-Preis der nächsten Scheibe (-1 = alle frei).
func drum_slot_price() -> int:
	if drum_slots >= SERIES_SLOT_CAP:
		return -1
	return drum_slots + 1

func can_buy_drum_slot() -> bool:
	var price := drum_slot_price()
	return price > 0 and energy >= price

func buy_drum_slot() -> bool:
	if not can_buy_drum_slot():
		return false
	spend_energy(drum_slot_price())
	drum_slots += 1
	press_changed.emit()
	return true

## --- EINE Prägung je Runde (Spieler-Entscheid 2026-11-23) -------------------------
## Zurückgesetzt beim Rundenstart; die Erdungsklemme prägt, ohne sie zu verbrauchen -
## auch dann noch, wenn sie schon verbraucht ist.
var press_used_this_round := false

func press_allowed() -> bool:
	return not press_used_this_round

## Darf DIESE Serie jetzt prägen? (Prägung frei oder eine Erdungsklemme steckt.)
func series_press_allowed(pack_uids: Array[int]) -> bool:
	if press_allowed():
		return true
	var parts := _series_parts(_series_indices(pack_uids))
	return bool(series_terms(parts["catalysts"]).get("free", false))

## --- Die KATALYSATOREN einer Serie --------------------------------------------
## Eine Katalysator-Kassette prägt nichts; sie besetzt einen Serien-Slot als Preis
## und legt der EINEN Serie, in der sie steckt, ihre Terme bei.

const CATALYST_PROPELLANT_STEP := 1

## Was die Katalysatoren dieser Serie zulegen: {propellant, free}. "free" = dieses
## Prägen verbraucht die Prägung der Runde nicht (Erdungsklemme).
static func catalyst_terms(packs: Array[Pack]) -> Dictionary:
	var terms := {"propellant": 0, "free": false}
	for pack in packs:
		if pack == null:
			continue
		match pack.catalyst_id:
			Pack.CATALYST_PROPELLANT:
				terms["propellant"] = int(terms["propellant"]) + CATALYST_PROPELLANT_STEP
			Pack.CATALYST_GROUND:
				terms["free"] = true
	return terms

## Die EINE Quelle der Serien-Terme für Vorschau, Buchung und Übertragung: die
## Katalysatoren plus der Lötkolben aus dem Dock (pointer_add).
func series_terms(catalysts: Array[Pack]) -> Dictionary:
	var terms := catalyst_terms(catalysts)
	terms["pointer_add"] = charm_ids().has(Charm.SOLDERING_IRON)
	return terms

## Zusätzliche Runen-Plätze aus dem Dock: die Glasglocke gibt dem Vakuum einen
## dritten.
func extra_rune_slots() -> int:
	return 1 if charm_ids().has(Charm.BELL_JAR) else 0

## Die Karten dieser Serie in STECKREIHENFOLGE - uids, weil Magazin-Indizes beim
## Umsortieren brechen. Doppelte fallen heraus, die Länge deckelt series_slots().
func _series_indices(pack_uids: Array[int]) -> Array[int]:
	var chosen: Array[int] = []
	for uid in pack_uids:
		var index := pack_index_of(uid)
		if index < 0 or chosen.has(index):
			continue
		chosen.append(index)
		if chosen.size() >= series_slots():
			break
	return chosen

## Serie in Netze und Katalysatoren zerlegt: {"nets", "catalysts"}.
func _series_parts(indices: Array[int]) -> Dictionary:
	var nets: Array = []
	var catalysts: Array[Pack] = []
	for index in indices:
		var pack := owned_packs[index]
		if pack.is_catalyst():
			catalysts.append(pack)
		else:
			nets.append(pack.stamp_net)
	return {"nets": nets, "catalysts": catalysts}

## VORSCHAU: was diese Serie auf diesem Würfel ergäbe. Mutiert nichts und ist
## buchstäblich dieselbe Rechnung, die apply_series bucht.
func resolve_series(pack_uids: Array[int], die: DieDefinition) -> Dictionary:
	var parts := _series_parts(_series_indices(pack_uids))
	return SeriesResolver.resolve(parts["nets"], die,
		series_terms(parts["catalysts"]))

## --- DIE VERDICHTUNG (2026-10-26) ----------------------------------------------
## Mehrere gewöhnliche Karten werden zu EINER dichteren gepresst. Der ROHLING aus dem
## Schwarzmarkt liegt dabei auf dem Podest und WIRD die neue Karte; das Futter wird
## verbraucht. Sie ist das Gegenstück zum Prägen und teilt dessen Grammatik - prüfen,
## rechnen, schreiben, Karten verbrauchen -, aber nicht dessen Rechnung: beim
## Verdichten ADDIEREN die Faktoren (siehe SeriesResolver.compress).

## Die Futter-Netze einer Verdichtung, plus was sie SPERRT. Verdichtet wird nur, was
## ein Netz trägt: Katalysatoren wirken auf einen WÜRFEL und würden hier bloß
## verbraucht, Operatoren und Pointer schreiben auf FREMDE Seiten und lassen sich darum
## gar nicht auf eine Zelle zusammenlegen.
func _compress_parts(indices: Array[int]) -> Dictionary:
	var nets: Array = []
	var blocker := ""
	for index in indices:
		var pack: Pack = owned_packs[index]
		if pack.is_catalyst():
			blocker = "catalyst"
		elif pack.is_operator():
			blocker = "operator"
		elif pack.from_blank():
			# Ein Rohling verdichtet nicht in den nächsten - sonst wüchse EINE Karte
			# ohne Grenze weiter (Spieler-Entscheid 2026-10-26).
			blocker = "compressed"
		elif not SeriesResolver.compressible([pack.stamp_net]):
			blocker = "pointer"
		elif not StampNet.is_blank(pack.stamp_net):
			nets.append(pack.stamp_net)
	return {"nets": nets, "blocker": blocker}

## VORSCHAU: was diese Serie in einem Rohling ergäbe. Mutiert nichts.
## Liefert {"net", "fizzled", "cards"} - oder {} mit "blocker", wenn nichts geht.
func compressible_series(pack_uids: Array[int], blank_uid: int) -> Dictionary:
	var blank := pack_by_uid(blank_uid)
	if blank == null or not blank.is_blank_card():
		return {"blocker": "blank"}
	var chosen := _series_indices(pack_uids)
	chosen.erase(pack_index_of(blank_uid))  # der Rohling ist das ZIEL, nie sein Futter
	var parts := _compress_parts(chosen)
	var blocker := String(parts["blocker"])
	if blocker != "":
		return {"blocker": blocker}
	var nets: Array = parts["nets"]
	if nets.is_empty():
		return {"blocker": "empty"}
	var out := SeriesResolver.compress(nets)
	out["cards"] = nets.size()
	return out

## DAS VERDICHTEN: EINE atomare Buchung. Der Rohling nimmt das zusammengepresste Netz
## auf und ist danach eine gewöhnliche Kassette; das Futter wird verbraucht (mit
## demselben Überlebens-Wurf der Zwinge wie beim Prägen). Kein Würfel wird angefasst.
## Liefert {"net", "fizzled", "cards", "kept", "uid"} oder {}.
func compress_series(pack_uids: Array[int], blank_uid: int,
		rng: RandomNumberGenerator = null) -> Dictionary:
	var preview := compressible_series(pack_uids, blank_uid)
	if preview.has("blocker"):
		return {}
	var blank := pack_by_uid(blank_uid)
	var chosen := _series_indices(pack_uids)
	chosen.erase(pack_index_of(blank_uid))
	# Der Rohling steckt NIE in chosen (erase oben), wird also nie sein eigenes Futter.
	blank.stamp_net = preview["net"]
	var kept := _consume_series_cards(chosen, rng)
	_sort_packs()  # sein neues Netz kann ihn unter einen anderen Typ legen
	packs_changed.emit()
	press_changed.emit()
	return {"net": preview["net"], "fizzled": preview["fizzled"],
		"cards": int(preview["cards"]), "kept": kept, "uid": blank_uid}

## DAS PRÄGEN: eine Serie, EINE atomare Buchung - prüfen, rechnen, schreiben,
## Karten verbrauchen. EINMAL je Runde (press_allowed), mit jeder Kartenzahl ab 1;
## ohne prägende Karte oder ohne freie Prägung geschieht NICHTS (leeres Dictionary).
## Liefert {"projection", "cards", "kept"}.
func apply_series(pack_uids: Array[int], die: DieDefinition,
		rng: RandomNumberGenerator = null) -> Dictionary:
	if die == null:
		return {}
	var chosen := _series_indices(pack_uids)
	if chosen.is_empty():
		return {}
	var parts := _series_parts(chosen)
	var nets: Array = parts["nets"]
	var terms := series_terms(parts["catalysts"])
	if not press_allowed() and not bool(terms.get("free", false)):
		return {}
	if nets.is_empty():
		return {}  # eine Serie aus lauter Katalysatoren prägt nicht
	var projection := SeriesResolver.resolve(nets, die, terms)
	_project(die, projection)
	if not bool(terms.get("free", false)):
		press_used_this_round = true
	var kept := _consume_series_cards(chosen, rng)
	packs_changed.emit()
	press_changed.emit()
	note_pool_changed()
	return {"projection": projection, "cards": chosen.size(), "kept": kept}

## Der EINE Schreibweg einer Projektion: über die vorhandenen DieDefinition-Wege,
## damit Veredelung, Runen-Plätze und Einbrand-Regel gelten wie überall.
func _project(die: DieDefinition, projection: Dictionary) -> void:
	var extra := extra_rune_slots()
	for face in SeriesResolver.FACES:
		die.faces[face] = int(projection["faces_after"][face])
		var material := String(projection["materials"][face])
		if material != "":
			die.set_face_material(face, material)
		if bool(projection["doped"][face]):
			die.dope(face)
		var runes: Array = projection["runes"][face]
		for slot in runes.size():
			if String(runes[slot]) != "":
				die.set_rune(face, String(runes[slot]), slot, extra)

## Karten verbrauchen: je Karte ein Überlebens-Wurf der Zwinge - eine Überlebende
## hat trotzdem voll gewirkt und bleibt im Magazin. Gilt für JEDE Karte der Serie,
## Fixinhalte und Katalysatoren eingeschlossen: eine Karte ist eine Karte.
func _consume_series_cards(indices: Array[int], rng: RandomNumberGenerator) -> int:
	var survive := CharmEffects.pack_survive_chance(charm_ids())
	var kept := 0
	var burned: Array[int] = []
	for index in indices:
		var roll := rng.randf() if rng != null else randf()
		if survive > 0.0 and roll < survive:
			kept += 1
		else:
			burned.append(index)
	burned.sort()
	for k in range(burned.size() - 1, -1, -1):
		owned_packs.remove_at(burned[k])
	return kept

# --- Steckplätze: Module auf den Kombinations-Chips -------------------------

## Grundzahl der Steckplätze je Chip - alle ab Runde 1 offen.
const SOCKETS_PER_COMBO := 3

## Steckplätze eines Chips: fest drei.
func socket_count(_combo_key: String) -> int:
	return SOCKETS_PER_COMBO

## Belegung eines Chips, auf socket_count aufgefüllt (null = frei). NUR lesen -
## geschrieben wird über install_pending_part/move_part.
func parts_of(combo_key: String) -> Array:
	if not DiceScoring.HAND_PRIORITY.has(combo_key):
		return []
	var fitted := _fit_sockets(combo_parts.get(combo_key, []))
	combo_parts[combo_key] = fitted
	return fitted

## Freie Steckplätze über alle Chips.
func free_socket_count() -> int:
	var free := 0
	for key: String in DiceScoring.HAND_PRIORITY:
		free += socket_count(key) - ComboPartEffects.part_count(combo_parts.get(key, []))
	return free

## Hat ein weiteres Modul noch Platz? Die wartenden zählen schon mit.
func parts_room() -> bool:
	return free_socket_count() - pending_parts.size() >= 1

## Die Belegung, mit der gewertet wird: stillgelegte Teile (Hitzestau) fehlen.
func scoring_parts() -> Dictionary:
	if heat_disabled_parts.is_empty():
		return combo_parts
	var out := {}
	for key in combo_parts:
		var sockets: Array = []
		for part in combo_parts[key]:
			sockets.append(null if is_part_disabled(part) else part)
		out[key] = sockets
	return out

## Ein echter Fumble scharft jeden gesteckten Nachbrenner (counter 1 = scharf).
func _arm_afterburners() -> void:
	for key in combo_parts:
		for part in combo_parts[key]:
			if part != null and part.id == ComboPart.AFTERBURNER and part.counter == 0:
				part.counter = 1
				combo_parts_changed.emit(String(key))

## Was den Fumble-Zähler gerade liest, je Zeile "Name: Wirkung" - für den Hub-Hinweis.
func fumble_readers() -> Array[String]:
	var lines: Array[String] = []
	var ids := charm_ids()
	var mult := CharmEffects.unlucky_bird_mult(farkle_count) * ids.count(Charm.UNLUCKY_BIRD)
	if mult > 0:
		lines.append("Pechvogel: +%d Mult" % mult)
	if ids.has(Charm.BROKEN_MIRROR) and farkle_count > 0:
		lines.append("Zerbrochener Spiegel: +%d Mult" % (farkle_count * ids.count(Charm.BROKEN_MIRROR)))
	var pension := CharmEffects.fumble_pension(farkle_count) * ids.count(Charm.FUMBLE_PENSION)
	if pension > 0:
		lines.append("Fumble-Rente: +$%d am Rundenende" % pension)
	var cat := CharmEffects.black_cat_discount(farkle_count, ids)
	if cat > 0.0:
		lines.append("Schwarze Katze: Ladenpreise −%d%%" % roundi(cat * 100.0))
	if ids.has(Charm.GALLOWS_REPRIEVE) and round_fumbles > 0:
		lines.append("Galgenfrist: Blind dieser Runde −%d%%" % roundi((1.0 - _round_goal_factor_reprieve()) * 100.0))
	var joker := SlotMachine.joker_weight(farkle_count)
	if joker > SlotMachine.W_JOKER:
		lines.append("Automaten: Joker ×%s häufiger" % String.num(joker / SlotMachine.W_JOKER, 2))
	return lines

func _round_goal_factor_reprieve() -> float:
	var reprieve := charm_ids().count(Charm.GALLOWS_REPRIEVE)
	return pow(1.0 - CharmEffects.GALLOWS_REPRIEVE_CUT, round_fumbles * reprieve)

## Ladenpreis eines Modul-Pakets in $ (Supraleiter wie bei Modulen, dann Inflation/Skonto).
func module_pack_shop_price(module_pack: ModulePack) -> int:
	return shop_price(CharmEffects.part_price(module_pack.price, charm_ids()))

## Die Stufen-Gewichte der Modul-Pakete im Laden.
func shop_module_pack_grade_weights() -> Array:
	return ModulePack.shop_grade_weights(shop_tier())

## Bucht ein Modul in pending_parts - als EIGENE Instanz (Zählwerk-Zustand).
## from_pack = aus einem Modul-Paket: sein Einbau darf ein steckendes VERDRÄNGEN.
func stash_part(part: ComboPart, from_pack := false) -> void:
	var own := part.instantiate()
	own.from_pack = from_pack
	pending_parts.append(own)
	pending_parts_changed.emit()

## Was der Einbau des nächsten Teils auf diesem Platz verdrängt (null = nichts) -
## und ob es dabei VERLOREN geht (Modul aus einem Paket).
func install_displaces(combo_key: String, slot: int, pending_index := 0) -> ComboPart:
	if pending_index < 0 or pending_index >= pending_parts.size() \
			or not _valid_socket(combo_key, slot):
		return null
	return parts_of(combo_key)[slot]

func install_loses_displaced(pending_index := 0) -> bool:
	return pending_index >= 0 and pending_index < pending_parts.size() \
		and pending_parts[pending_index].from_pack

## Baut das nächste wartende Teil ein (Wett- und Rampenlicht-Module gehen der Reihe nach).
func install_pending_part(combo_key: String, slot: int) -> bool:
	return install_pending_part_at(0, combo_key, slot)

## Baut das wartende Teil pending_index in combo_key/slot ein. Ein belegter Platz
## tauscht: das alte Teil wird zum nächsten offenen Einbau - kommt das neue aus
## einem Modul-Paket, ist das alte VERLOREN (sonst kreiste es ewig).
func install_pending_part_at(pending_index: int, combo_key: String, slot: int) -> bool:
	if pending_index < 0 or pending_index >= pending_parts.size() \
			or not _valid_socket(combo_key, slot):
		return false
	var part := pending_parts[pending_index]
	var sockets := parts_of(combo_key).duplicate()
	var displaced: ComboPart = sockets[slot]
	sockets[slot] = part
	combo_parts[combo_key] = _fit_sockets(sockets)
	var from_pack := part.from_pack
	part.from_pack = false
	pending_parts.remove_at(pending_index)
	if displaced != null and not from_pack:
		pending_parts.insert(0, displaced)
	last_lapsed_parts.clear()
	# Nur ein Wurf zählt herunter (direkt gestashte Paket-Module kennen keinen).
	if from_pack and module_keeps > 0:
		module_keeps -= 1
		if module_keeps == 0:
			_lapse_pack_parts()
	_settle_module_keeps()
	_release_guarded(combo_key)
	pending_parts_changed.emit()
	combo_parts_changed.emit(combo_key)
	return true

## VERWERFEN: ein neues Paket-Modul zurück in den Beutel - es ist dann weg.
## Nur from_pack-Module; ein verdrängtes oder gewonnenes bleibt.
func discard_pending_part(index: int) -> bool:
	if index < 0 or index >= pending_parts.size() or not pending_parts[index].from_pack:
		return false
	pending_parts.remove_at(index)
	_settle_module_keeps()
	pending_parts_changed.emit()
	return true

## Der Wurf ist aufgebraucht: jedes übrige Paket-Modul verfällt mit dem Beutel.
func _lapse_pack_parts() -> void:
	for i in range(pending_parts.size() - 1, -1, -1):
		if pending_parts[i].from_pack:
			last_lapsed_parts.insert(0, pending_parts[i])
			pending_parts.remove_at(i)

## Ohne wartendes Paket-Modul gibt es auch nichts mehr einzubauen.
func _settle_module_keeps() -> void:
	for part in pending_parts:
		if part.from_pack:
			return
	module_keeps = 0

## Der erste freie Steckplatz eines Chips (-1 = keiner).
func first_free_socket(combo_key: String) -> int:
	return parts_of(combo_key).find(null)

## Wohin ein Tipp beim EINBAU steckt (-1 = nirgends): ein freier Platz immer, ein
## belegter nur im Bearbeitungs-Fenster (sonst wäre der Tausch ein Umstecken
## mitten in der Runde); slot -1 = der Chip selbst, also sein erster freier.
func install_target(combo_key: String, slot: int, editable: bool) -> int:
	if not DiceScoring.HAND_PRIORITY.has(combo_key):
		return -1
	if slot < 0:
		return first_free_socket(combo_key)
	if not _valid_socket(combo_key, slot):
		return -1
	if parts_of(combo_key)[slot] == null or editable:
		return slot
	return -1

## Kann ein wartendes Teil jetzt überhaupt stecken? Ohne freien Platz nur per
## Tausch, und der braucht das Bearbeitungs-Fenster.
func can_install_pending(editable: bool) -> bool:
	if pending_parts.is_empty():
		return false
	return free_socket_count() > 0 or editable

## Steckt ein Teil um; ein belegtes Ziel tauscht. editable = das Bearbeitungs-
## Fenster des Aufrufers (Laden, vor der Unterschrift) - zu, dann bleibt alles.
func move_part(from_key: String, from_slot: int, to_key: String, to_slot: int, editable: bool = true) -> bool:
	if not editable or not _valid_socket(from_key, from_slot) or not _valid_socket(to_key, to_slot):
		return false
	if from_key == to_key and from_slot == to_slot:
		return false
	var part: ComboPart = parts_of(from_key)[from_slot]
	if part == null:
		return false
	if from_key == to_key:
		var sockets := parts_of(from_key).duplicate()
		sockets[from_slot] = sockets[to_slot]
		sockets[to_slot] = part
		combo_parts[from_key] = sockets
	else:
		var from_sockets := parts_of(from_key).duplicate()
		var to_sockets := parts_of(to_key).duplicate()
		from_sockets[from_slot] = to_sockets[to_slot]
		to_sockets[to_slot] = part
		combo_parts[from_key] = from_sockets
		combo_parts[to_key] = to_sockets
		_release_guarded(to_key)
		combo_parts_changed.emit(to_key)
	_release_guarded(from_key)
	combo_parts_changed.emit(from_key)
	return true

## Was eine Wertung dieser Kombination mitzündet (sie selbst zuerst, dann die Brücken,
## soweit die Energie reicht - gefragt VOR dem Abbuchen der Hand).
func chain_keys(combo_key: String) -> Array[String]:
	return ComboPartEffects.chain_keys(scoring_parts(), combo_key, throttled_combos, energy)

## Alle Steckplätze dieser Kette - das, womit die Würfel der Hand zünden.
func chain_chip(combo_key: String) -> Array:
	return ComboPartEffects.merged_chip(scoring_parts(), chain_keys(combo_key), energy)

## Die Kette wurde gewertet: Zählwerke und Schwingkreise wachsen, Münzprüfer zahlen.
## Gebucht beim Nehmen, VOR der Zeremonie. Liefert das gezahlte Geld.
func book_combo_scored(combo_key: String) -> int:
	var money_gain := 0
	var parts := scoring_parts()
	for key in chain_keys(combo_key):
		var sockets: Array = parts.get(key, [])
		var grew := false
		for part in sockets:
			if part != null and (part.id == ComboPart.COUNTER or part.id == ComboPart.RESONATOR):
				part.counter += ComboPartEffects.weight(sockets, part)  # die Kopplung zählt mit
				grew = true
			elif part != null and part.id == ComboPart.AFTERBURNER and part.counter > 0:
				part.counter = 0  # der Nachbrenner hat gezündet
				grew = true
		money_gain += ComboPartEffects.scoring_money(sockets)
		if grew:
			combo_parts_changed.emit(key)
	if money_gain > 0:
		add_money(money_gain)
	return money_gain

## Stromabnehmer: Energie je Wertung; was über den Deckel läuft, zahlt bar.
## Liefert, was wirklich im Speicher ankam - so viele Lichter fliegen.
func book_part_energy(combo_key: String) -> int:
	var count := ComboPartEffects.scoring_energy(chain_chip(combo_key))
	if count <= 0:
		return 0
	var before := energy
	book_copper_energy(count)
	return energy - before

## Sperrdiode: dieser Chip wird nie gedrosselt und nie stillgelegt.
func _chip_guarded(combo_key: String) -> bool:
	return ComboPartEffects.has_part(combo_parts.get(combo_key, []), ComboPart.BLOCKING_DIODE)

## Eine frisch gesteckte Sperrdiode hebt auf, was den Chip schon getroffen hat.
func _release_guarded(combo_key: String) -> void:
	if not _chip_guarded(combo_key):
		return
	throttled_combos.erase(combo_key)
	for part in combo_parts.get(combo_key, []):
		if part != null:
			heat_disabled_parts.erase(part.get_instance_id())

func _valid_socket(combo_key: String, slot: int) -> bool:
	return DiceScoring.HAND_PRIORITY.has(combo_key) and slot >= 0 and slot < socket_count(combo_key)

## Bringt eine Belegung auf die drei Plätze: auffüllen mit null, was darüber liegt, rückt
## in freie Plätze davor (alte Belegungen mit mehr Plätzen).
func _fit_sockets(sockets: Array) -> Array:
	var out := sockets.duplicate()
	while out.size() < SOCKETS_PER_COMBO:
		out.append(null)
	while out.size() > SOCKETS_PER_COMBO:
		var tail = out.pop_back()
		var free := out.find(null)
		if tail != null and free >= 0:
			out[free] = tail
	return out

## Rundenbeginn: Runden-Marken zurücksetzen, Lumpensammler würfelt seine
## Glückszahl neu - je Vorkommen einmal. Auch Drossel und Rampenlicht werden hier
## gesetzt; die Klauseln der Runde stehen zu diesem Zeitpunkt schon
## (unterschrieben wird VOR dem Rundenstart).
func apply_round_start_charms() -> void:
	roll_essence_round_state()
	var ids := charm_ids()
	if ids.has(Charm.RAG_COLLECTOR):
		_roll_lumpensammler_value()
	throttled_combos = _round_throttled_combos()
	_clear_heat_disabled()
	spotlight_claimed_this_round = false
	golden_handshake_used_this_round = false
	packs_opened_this_round = 0
	free_reshuffle_used_this_round = false
	if press_used_this_round:
		press_used_this_round = false
		press_changed.emit()
	# Rampenlicht per Charm ODER Klausel - nie auf einem gedrosselten Chip
	# (der wertet nicht, das Licht wäre verschenkt).
	if CharmEffects.has_spotlight(ids) or _clause_active(DealClause.SPOTLIGHT):
		var pool := DiceScoring.HAND_PRIORITY.filter(
			func(key: String) -> bool: return not throttled_combos.has(key))
		spotlight_combo = pool.pick_random() if not pool.is_empty() else ""
	else:
		spotlight_combo = ""

# --- Stresstest ---------------------------------------------------------------

## Stresstest: die letzte Runde jedes Blocks (Runde 6, 12, ...).
static func is_stress_round(n: int) -> bool:
	return n % GOAL_BLOCK == 0

## Block-Nummer einer Runde (0-basiert) - Klauseln laufen bis zum Blockende.
static func block_of_round(n: int) -> int:
	return (n - 1) / GOAL_BLOCK

## Die heißesten Chips zuerst: die meisten Module, bei Gleichstand der
## ranghöhere (HAND_PRIORITY). Deterministisch, damit der Spieler im Shop davor
## planen kann.
func hottest_combos(count: int) -> Array[String]:
	var keys: Array[String] = []
	for key: String in DiceScoring.HAND_PRIORITY:
		if not _chip_guarded(key):
			keys.append(key)
	# Gleichstand ausdrücklich über den Rang brechen: sort_custom sortiert nicht
	# stabil, die Reihenfolge aus HAND_PRIORITY allein trägt also nicht.
	keys.sort_custom(func(a: String, b: String) -> bool:
		var parts_a := ComboPartEffects.part_count(parts_of(a))
		var parts_b := ComboPartEffects.part_count(parts_of(b))
		if parts_a != parts_b:
			return parts_a > parts_b
		return DiceScoring.HAND_PRIORITY.find(a) < DiceScoring.HAND_PRIORITY.find(b))
	return keys.slice(0, maxi(0, count))

## Der heißeste Chip ("" = keiner) - Kurzform von hottest_combos.
## Gedrosselte Chips beim Rundenbeginn: nur noch die Hitzewarnung drosselt von
## sich aus - der Stresstest hat dafür seine eigenen Konditionen.
func _round_throttled_combos() -> Array[String]:
	if _clause_active(DealClause.HEAT_WARNING):
		return hottest_combos(1)
	return [] as Array[String]

## Meldet eine genommene Hand an die Boss-Konditionen: Allrounder sperrt genau
## diese Kombination, das Standardprotokoll alle anderen. Liefert true, wenn die
## Drossel dadurch gewachsen ist (die Chips müssen dann neu gezeichnet werden).
func note_hand_taken(combo_key: String) -> bool:
	var before := throttled_combos.size()
	if _clause_active(DealClause.ALL_ROUNDER) and not throttled_combos.has(combo_key) and not _chip_guarded(combo_key):
		throttled_combos.append(combo_key)
	if _clause_active(DealClause.STANDARD_PROTOCOL):
		for key: String in DiceScoring.HAND_PRIORITY:
			if key != combo_key and not throttled_combos.has(key) and not _chip_guarded(key):
				throttled_combos.append(key)
	return throttled_combos.size() > before

## Hitzestau: ein echter Fumble zerstört ein zufälliges Modul - Chips mit Sperrdiode
## bleiben verschont. Liefert das zerstörte Modul (null = keins).
func destroy_fumble_part(rng: RandomNumberGenerator = null) -> ComboPart:
	if not _clause_active(DealClause.HEAT_BUILDUP):
		return null
	var spots: Array[Array] = []
	for key: String in DiceScoring.HAND_PRIORITY:
		if _chip_guarded(key):
			continue
		var sockets: Array = combo_parts.get(key, [])
		for slot in sockets.size():
			if sockets[slot] != null:
				spots.append([key, slot])
	if spots.is_empty():
		return null
	var at := rng.randi_range(0, spots.size() - 1) if rng != null else randi_range(0, spots.size() - 1)
	var key := String(spots[at][0])
	var slot := int(spots[at][1])
	var part: ComboPart = combo_parts[key][slot]
	combo_parts[key][slot] = null
	combo_parts_changed.emit(key)
	return part

## Strafgebühr (Boss): Platz des Charms, den dieser Fumble zerstört (-1 = keiner).
## Gewählt wird hier, entfernt erst mit destroy_charm - die Diskette muss vorher heraus.
func fumble_charm_loss(rng: RandomNumberGenerator = null) -> int:
	if not _clause_active(DealClause.PENALTY_FEE) or owned_charms.is_empty():
		return -1
	return rng.randi_range(0, owned_charms.size() - 1) if rng != null \
		else randi_range(0, owned_charms.size() - 1)

## Entfernt den Charm auf Platz index ersatzlos.
func destroy_charm(index: int) -> void:
	if index < 0 or index >= owned_charms.size():
		return
	owned_charms.remove_at(index)
	charms_changed.emit()

## Ist dieses Teil in der laufenden Runde stillgelegt (Hitzestau)?
func is_part_disabled(part: ComboPart) -> bool:
	return part != null and heat_disabled_parts.has(part.get_instance_id())

func _clear_heat_disabled() -> void:
	if heat_disabled_parts.is_empty():
		return
	heat_disabled_parts.clear()
	combo_parts_changed.emit("")

## Paritäts-Filter der Boss-Konditionen (DiceScoring.PARITY_*).
func parity_filter() -> int:
	if _clause_active(DealClause.TILTED_FLOOR):
		return DiceScoring.PARITY_ODD
	if _clause_active(DealClause.BALANCED_SCALES):
		return DiceScoring.PARITY_EVEN
	return DiceScoring.PARITY_ANY

## All in: so viele Hände dürfen diese Runde genommen werden.
func max_hands_this_round() -> int:
	return 1 if _clause_active(DealClause.ALL_IN) else POOL_SIZE

## Fahrplan-Marker je Station: STRESS_MARKER oder "". Nur für die Hub-Anzeige.
func goal_roadmap_markers(count: int) -> Array[String]:
	var markers: Array[String] = []
	var first_round := round_number - goal_roadmap_index(count)
	for i in count:
		markers.append(STRESS_MARKER if is_stress_round(first_round + i) else "")
	return markers

# --- Verträge: Auslage, Unterschrift, Abrechnung ------------------------------
## Eine Vertragskarte der Auslage: Stufe + die beiden Klausel-ids ("" = die Karte
## hat diese Seite nicht - Werbegeschenke ohne Kleingedrucktes, Boss ohne Bonus).
const CARD_TIER := "tier"
const CARD_BONUS := "bonus"
const CARD_MALUS := "malus"

## Würfelt die Auslage der kommenden Runde: von links nach rechts immer Standard-,
## Risiko- und Knebelvertrag. Mit TREAT_CHANCE fällt bei EINEM Platz das
## Kleingedruckte weg - sein Bonus kommt aus dem normalen Topf seiner Stufe, die
## Karte zeigt sich als Werbegeschenk; welcher Platz, verteilt TREAT_TIER_WEIGHTS. In der Stresstest-Runde liegen stattdessen
## drei Boss-Konditionen aus: dort entscheidet der Spieler, WIE er den Test angeht.
func roll_route_offers() -> void:
	route_offers.clear()
	if is_stress_round(round_number):
		_roll_boss_offers()
		return
	var treat_slot := _roll_treat_slot()
	var tiers: Array[DealClause.Tier] = [
		DealClause.Tier.ONE, DealClause.Tier.TWO, DealClause.Tier.THREE]
	for i in tiers.size():
		route_offers.append(_draw_card(tiers[i], i == treat_slot))

## Chance, dass überhaupt ein Werbegeschenk ausliegt - die Werbetrommel verdreifacht
## sie. Erster Charm am Vertragswesen: die Wirkung ist eine Abfrage hier, weil sie
## an active_deals bzw. dem Angebots-Wurf hängt, nicht an der Wertung.
func treat_chance() -> float:
	var factor := 3.0 if charm_ids().has(Charm.AD_DRUM) else 1.0
	return minf(1.0, TREAT_CHANCE * factor)

## Der Winkeladvokat liest jede BONUS-Klausel doppelt - linear auf ihrer Zahl, bei
## den beiden Nachlässen (Skonto, Eichung) als zweite Anwendung. Bewusst ohne
## Stapelung: zwei Exemplare wirken wie eines.
func deal_bonus_factor() -> int:
	return 2 if charm_ids().has(Charm.SHYSTER) else 1

## Platz, den ein Werbegeschenk ersetzt (−1 = keins). treat_chance entscheidet, OB
## eins kommt; TREAT_TIER_WEIGHTS, WELCHER Platz.
func _roll_treat_slot() -> int:
	if randf() >= treat_chance():
		return -1
	var r := randf()
	var acc := 0.0
	for i in TREAT_TIER_WEIGHTS.size():
		acc += TREAT_TIER_WEIGHTS[i]
		if r < acc:
			return i
	return 0

## Drei der sechs Stresstest-Konditionen, ohne einen zweiten Quota-Aufschlag.
func _roll_boss_offers() -> void:
	var pool: Array[String] = []
	for clause_id in DealClause.ids_for(DealClause.Tier.BOSS, DealClause.Kind.MALUS):
		if not _quota_blocked(clause_id):
			pool.append(clause_id)
	pool.shuffle()
	for i in mini(ROUTE_OFFER_COUNT, pool.size()):
		route_offers.append({CARD_TIER: DealClause.Tier.BOSS, CARD_BONUS: "", CARD_MALUS: pool[i]})

## Baut eine Vertragskarte: erst das Kleingedruckte, dann der Bonus - dessen Topf
## muss die Tags des Malus meiden (sonst entstehen Nullsummen-Paare). Das
## Werbegeschenk zieht seinen Bonus aus demselben Topf seiner Stufe und lässt nur
## den Malus weg; TREAT ist reine Anzeigestufe.
func _draw_card(tier: DealClause.Tier, treat: bool = false) -> Dictionary:
	var malus_id := ""
	if not treat:
		malus_id = _draw_clause(tier, DealClause.Kind.MALUS, [] as Array[String])
	var bonus_id := _draw_clause(tier, DealClause.Kind.BONUS, DealClause.tags_of(malus_id))
	var card_tier: DealClause.Tier = DealClause.Tier.TREAT if treat else tier
	return {CARD_TIER: card_tier, CARD_BONUS: bonus_id, CARD_MALUS: malus_id}

## Zieht eine Klausel des Topfes: nie eine, die schon in der Auslage liegt oder in
## diesem Block unterschrieben wurde, nie eine mit einem verbotenen Tag, nie einen
## ZWEITEN Quota-Malus (sonst baut sich der Spieler ein unerreichbares Ziel).
## Läuft der Topf dadurch leer, sind Wiederholungen erlaubt - ein leerer Platz
## wäre schlimmer als eine bekannte Klausel.
func _draw_clause(tier: DealClause.Tier, kind: DealClause.Kind,
		taboo_tags: Array[String]) -> String:
	var all_ids := DealClause.ids_for(tier, kind)
	var listed := _listed_clause_ids()
	var pool: Array[String] = []
	for clause_id in all_ids:
		if listed.has(clause_id) or _taken_this_block(clause_id):
			continue
		if _shares_tag(clause_id, taboo_tags) or _quota_blocked(clause_id):
			continue
		if clause_id == DealClause.BIG_STORAGE and storage_rows >= max_storage_rows():
			continue
		pool.append(clause_id)
	if pool.is_empty():
		pool = all_ids
	return pool.pick_random() if not pool.is_empty() else ""

## Alle Klausel-ids, die schon in der Auslage liegen - keine darf doppelt.
func _listed_clause_ids() -> Array[String]:
	var ids: Array[String] = []
	for card in route_offers:
		for key in [CARD_BONUS, CARD_MALUS]:
			var clause_id := String(card.get(key, ""))
			if clause_id != "":
				ids.append(clause_id)
	return ids

func _shares_tag(clause_id: String, taboo_tags: Array[String]) -> bool:
	for tag in DealClause.tags_of(clause_id):
		if taboo_tags.has(tag):
			return true
	return false

## Ob die Klausel als zweiter RUNDENWEISER Blind-Aufschlag ausgeschlossen ist -
## dauerhafte Hebungen dürfen sich stapeln.
func _quota_blocked(clause_id: String) -> bool:
	return QUOTA_MALUS.has(clause_id) and _quota_already_raised()

## Unterschreibt die Vertragskarte index der Auslage.
func take_route(index: int) -> void:
	if index < 0 or index >= route_offers.size():
		return
	var card := route_offers[index]
	var ids: Array[String] = []
	for key in [CARD_BONUS, CARD_MALUS]:
		var clause_id := String(card.get(key, ""))
		if clause_id != "":
			ids.append(clause_id)
	route_offers.clear()
	sign_clauses(ids)

## Zieht Klauseln in den Vertrag ein und feuert ihre SOFORT-Wirkungen. Einziger
## Weg in active_deals - Auslage wie Test gehen hier durch.
func sign_clauses(clause_ids: Array[String]) -> void:
	for clause_id in clause_ids:
		if not DealClause.is_valid_id(clause_id):
			continue
		active_deals.append({"id": clause_id, "round": round_number})
		_apply_instant_clause(clause_id)
	deals_changed.emit()

## Wirkungen, die mit der Unterschrift verfallen (Scope.INSTANT) - plus die
## Zähler, die eine Runden-Klausel beim Einzug aufstellt.
func _apply_instant_clause(clause_id: String) -> void:
	var boost := deal_bonus_factor()
	if BLIND_RAISE.has(clause_id):
		raise_blind(1.0 + float(BLIND_RAISE[clause_id]))
	if LUCK_CLAUSES.has(clause_id):
		var amount := int(LUCK_CLAUSES[clause_id])
		add_luck(amount * boost if amount > 0 else amount)
	if TEMP_LUCK_CLAUSES.has(clause_id):
		var lent := int(TEMP_LUCK_CLAUSES[clause_id]) * boost
		temp_luck += lent
		add_luck(lent)
	match clause_id:
		DealClause.CALIBRATION:
			# Nachlass: zweimal angewandt statt verdoppelt.
			raise_blind(pow(CALIBRATION_FACTOR, boost))
		DealClause.ADVANCE_PAYMENT:
			add_money(ADVANCE_PAYMENT_MONEY * boost)
		DealClause.BLANK_CHEQUE:
			add_money(BLANK_CHEQUE_MONEY * boost)
		DealClause.SEED_CAPITAL:
			add_energy(instant_clause_energy(clause_id, boost))
		DealClause.DISCHARGE:
			spend_energy(DISCHARGE_ENERGY)
		DealClause.FREE_CHARM:
			free_charm_pending = true
		DealClause.BIG_STORAGE:
			storage_rows = mini(storage_rows + boost, max_storage_rows())
			energy_changed.emit(energy)  # der Deckel ist gewachsen
		DealClause.BETTING_TAX:
			repay_side_bet_stakes()

## Energie, die diese Klausel mit der Unterschrift prägt (0 = keine). Eine Quelle
## für Buchung und Zeremonie: scene_root schickt je ⚡ einen Kometen zum Ring.
static func instant_clause_energy(clause_id: String, bonus_factor: int = 1) -> int:
	match clause_id:
		DealClause.SEED_CAPITAL:
			return SEED_CAPITAL_ENERGY * bonus_factor
	return 0

## Abrechnung: der Stresstest ist überstanden, alle Klauseln des Blocks verfallen.
func settle_block_deals() -> void:
	if active_deals.is_empty():
		return
	active_deals.clear()
	free_charm_pending = false
	deals_changed.emit()

## Ob die Klausel in diesem Block schon unterschrieben wurde (auch wenn ihre
## Wirkung längst abgelaufen ist) - sie wird dann nicht erneut angeboten.
func _taken_this_block(clause_id: String) -> bool:
	for entry in active_deals:
		if entry["id"] == clause_id:
			return true
	return false

func _quota_already_raised() -> bool:
	for clause_id: String in QUOTA_MALUS:
		if _clause_active(clause_id):
			return true
	return false

## Ob eine Klausel mit dieser Laufzeit in Runde n noch wirkt: INSTANT verfällt mit
## der Unterschrift, ROUND gilt nur in ihrer eigenen Runde, BLOCK bis zur
## Abrechnung am Ende des Blocks (keine Klausel trägt BLOCK noch - die Stufe
## bleibt der Schiedsrichter für künftige Laufzeiten).
func _scope_reaches(entry: Dictionary, scope: DealClause.Scope, n: int) -> bool:
	var signed := int(entry["round"])
	match scope:
		DealClause.Scope.INSTANT:
			return false
		DealClause.Scope.ROUND:
			return n == signed
	return n >= signed and block_of_round(n) == block_of_round(signed)

## Einzige Auflösung "wirkt diese Klausel gerade?" - Bonus wie Malus, denn die
## Art steckt in der Klausel selbst.
func _clause_active(clause_id: String, n: int = -1) -> bool:
	var clause := DealClause.find(clause_id)
	if clause == null:
		return false
	var round_at := round_number if n < 0 else n
	for entry in active_deals:
		if entry["id"] == clause_id and _scope_reaches(entry, clause.scope, round_at):
			return true
	return false

## Wirkende Klauseln als {id, bonus, scope, text} - Grundlage der Marken-Reihen.
## Der Text kommt fertig mit: so bleibt DealTokenRow ohne GameRun und zeigt
## trotzdem die Zahlen, die der Winkeladvokat wirklich bucht.
func active_deal_sides() -> Array[Dictionary]:
	var sides: Array[Dictionary] = []
	var boost := deal_bonus_factor()
	for entry in active_deals:
		var clause := DealClause.find(entry["id"])
		if clause == null or not _scope_reaches(entry, clause.scope, round_number):
			continue
		var is_bonus := clause.kind == DealClause.Kind.BONUS
		sides.append({"id": clause.id, "bonus": is_bonus, "scope": clause.scope,
			"text": DealClause.text_for(clause.id, boost if is_bonus else 1)})
	return sides

# --- Klausel-Wirkungen (einzige Auflösung der ids) ----------------------------

## Tatsächliches Rundenziel: das GESETZTE Grundziel × rundenweise Faktoren (Hohe
## Erwartungen, Galgenfrist). Über round_goal, damit ein direkt gesetztes Ziel zählt.
func effective_goal() -> int:
	return roundi(round_goal * _round_goal_factor())

## Rundenweise Faktoren auf den Blind DIESER Runde - blind_value bleibt unberührt.
func _round_goal_factor() -> float:
	var factor := 1.0
	for entry in active_deals:
		var clause := DealClause.find(entry["id"])
		if clause == null or not _scope_reaches(entry, clause.scope, round_number):
			continue
		if QUOTA_MALUS.has(clause.id):
			factor *= 1.0 + float(QUOTA_MALUS[clause.id])
	return factor * _round_goal_factor_reprieve()

## Wachstum des Blinds beim Eintritt in Runde n: 10 % im ersten Block, je Block +5 %.
static func blind_growth(n: int) -> float:
	return BLIND_GROWTH_BASE + BLIND_GROWTH_STEP * float(block_of_round(n))

## Abwärts auf Vielfache von BLIND_ROUNDING, mindestens eines davon.
static func floor_to_blind(value: float) -> int:
	var steps := int(floor(value / float(BLIND_ROUNDING) + 0.000001))
	return maxi(BLIND_ROUNDING, steps * BLIND_ROUNDING)

## Hebt (oder senkt) den Blind DAUERHAFT; die laufende Runde zieht sofort mit.
func raise_blind(factor: float) -> void:
	blind_value *= factor
	round_goal = floor_to_blind(blind_value)

## Projektion des Blinds der Runde k (ohne künftige Verträge), gerundet.
func projected_blind(k: int) -> int:
	var value := blind_value
	for n in range(round_number + 1, k + 1):
		value *= 1.0 + blind_growth(n)
	return floor_to_blind(value)

## Fahrplan-Wert der Runde n: gespielt (Historie), laufend (wirksam) oder projiziert.
func roadmap_goal(n: int) -> int:
	if n < round_number:
		if n >= 1 and n - 1 < blind_history.size():
			return blind_history[n - 1]
		return floor_to_blind(float(BASE_GOAL))
	if n == round_number:
		return effective_goal()
	return projected_blind(n)

## Faktor auf die GESAMTE Rundenauszahlung (Bank + übrige Würfel). Happy Hour und
## Alles auf Rot stehen bewusst NICHT hier, sondern in money_gain_factor - sonst
## zahlte die Runde doppelt.
func round_payout_factor() -> float:
	var factor := 1.0
	if _clause_active(DealClause.DEDUCTION):
		factor *= 0.75
	if _clause_active(DealClause.HALF_PAYOUT):
		factor *= 0.5
	if _clause_active(DealClause.BLACKOUT):
		factor = 0.0
	return factor

## Sparprämie: Aufschlag je übrigem Würfel (zusätzlich zum Sparschwein-Charm).
func deal_unused_die_bonus() -> int:
	return SAVINGS_DIE_BONUS * deal_bonus_factor() if _clause_active(DealClause.SAVINGS_BONUS) else 0

## Kaltverfestigung: ein Knochen auf Zeit - jede ausgelöste Seite (obere Seite
## wie deterministisches Glied) wächst dauerhaft um so viele Augen.
func clause_face_growth() -> int:
	return WORK_HARDENING_GROWTH * deal_bonus_factor() if _clause_active(DealClause.WORK_HARDENING) else 0

## Leergut/Blackout: übrige Würfel zahlen gar nichts.
func unused_dice_pay() -> bool:
	return not (_clause_active(DealClause.EMPTIES) or _clause_active(DealClause.BLACKOUT))

## Ankerklausel: der erste Farkle der Runde ist verziehen (scene_root merkt sich,
## ob er schon verbraucht wurde).
func deal_anchor_active() -> bool:
	return _clause_active(DealClause.ANCHOR_CLAUSE)

## Versicherungsbetrug: Trostgeld für jeden Farkle.
func farkle_consolation() -> int:
	return INSURANCE_FRAUD_MONEY * deal_bonus_factor() if _clause_active(DealClause.INSURANCE_FRAUD) else 0

## Servicegebühr: Abzug je genommener Hand.
func hand_fee() -> int:
	return SERVICE_FEE_MONEY if _clause_active(DealClause.SERVICE_FEE) else 0

## Abzocke: Abzug je gewertetem Würfel einer genommenen Hand.
func scored_die_fee() -> int:
	return RIP_OFF_PER_DIE if _clause_active(DealClause.RIP_OFF) else 0

## Zinsen: Rundenende-Ertrag auf das gehaltene Guthaben.
func interest_income() -> int:
	return (money / INTEREST_PER) * deal_bonus_factor() if _clause_active(DealClause.INTEREST) else 0

## Goldader: Geld je geräumter Überladungs-Stufe (0 = die Klausel ruht).
func gold_vein_income() -> int:
	return GOLD_VEIN_MONEY * deal_bonus_factor() if _clause_active(DealClause.GOLD_VEIN) else 0

## Doppellader: wie viele ⚡ eine geräumte Überladungs-Stufe prägt.
func energy_per_stage() -> int:
	return 2 * deal_bonus_factor() if _clause_active(DealClause.DOUBLE_LOADER) else 1

## Ladenpreis-Faktor (Inflation ×1,25, Skonto ×0,8 - beide multiplikativ).
func shop_price_factor() -> float:
	var factor := 1.0
	if _clause_active(DealClause.INFLATION):
		factor *= SHOP_INFLATION_FACTOR
	if _clause_active(DealClause.CASH_DISCOUNT):
		# Nachlass wie die Eichung: zweimal angewandt statt verdoppelt.
		factor *= pow(SHOP_DISCOUNT_FACTOR, deal_bonus_factor())
	if _clause_active(DealClause.REGULAR_CUSTOMER):
		factor *= pow(REGULAR_CUSTOMER_FACTOR, deal_bonus_factor())
	factor *= 1.0 - CharmEffects.black_cat_discount(farkle_count, charm_ids())
	return factor

## Ladenpreis einer Ware; jeder Preisschild-Aufrufer geht hier durch.
func shop_price(base: int) -> int:
	if base <= 0:
		return base
	return maxi(1, roundi(base * shop_price_factor()))

## Hausgutschein: der nächste Charm im Laden ist gratis.
func charm_is_free() -> bool:
	return free_charm_pending and _clause_active(DealClause.FREE_CHARM)

func consume_free_charm() -> void:
	free_charm_pending = false


## Der Laden öffnet: der Gratisdreh des Freispiels lebt wieder auf.
func begin_shop_visit() -> void:
	free_spin_used_this_visit = false

## Freispiel-Charm: der erste Dreh dieses Besuchs geht aufs Haus - egal an
## welchem Automaten.
func charm_free_spin_open() -> bool:
	return not free_spin_used_this_visit and CharmEffects.has_free_spin(charm_ids())

## Faktor auf den GEWINNWERT gewonnener Nebenwetten (Quotenbonus).
func side_bet_payout_factor() -> float:
	if _clause_active(DealClause.ODDS_BONUS):
		return 2.0 * deal_bonus_factor()
	return 1.0

## Faktor auf den Einsatz - Anzeige UND Abbuchung lesen das hier, gerundet wird
## aufwärts (SideBet.scaled). Keine Klausel dreht mehr daran.
func side_bet_stake_factor() -> float:
	return 1.0

## Wettsteuer: jede laufende Wette zahlt ihren Einsatz noch einmal. Was nicht reicht,
## entfällt - die Wette läuft trotzdem weiter, als wäre gezahlt. Steuerwetten zahlen
## beim Setzen nichts und hier darum auch nichts.
func repay_side_bet_stakes() -> void:
	var changed := false
	for bet in active_side_bets:
		if bet.voided:
			continue
		match bet.stake_kind:
			SideBet.Stake.PACKS:
				var packs := stake_packs_for(bet)
				if not packs.is_empty():
					bet.paid_packs.append_array(packs)
					_consume_packs(packs)
					changed = true
			SideBet.Stake.ENERGY:
				var due := mini(energy, side_bet_stake_energy(bet))
				if due > 0:
					spend_energy(due)
					bet.paid_energy += due
					changed = true
			SideBet.Stake.MONEY_PER_HAND, SideBet.Stake.MONEY_PER_DIE:
				pass
			_:
				var due := mini(maxi(money, 0), side_bet_stake(bet))
				if due > 0:
					add_money(-due)
					bet.paid_money += due
					changed = true
	if changed:
		side_bets_changed.emit()

## Fälliger Bar-Einsatz einer Wette.
func side_bet_stake(bet: SideBet) -> int:
	return SideBet.scaled(bet.stake, side_bet_stake_factor())

## Fälliger Paket-Einsatz einer Wette.
func side_bet_stake_packs(bet: SideBet) -> int:
	return SideBet.scaled(bet.stake_packs, side_bet_stake_factor())

## Fälliger Ladungs-Einsatz einer Wette (⚡).
func side_bet_stake_energy(bet: SideBet) -> int:
	return SideBet.scaled(bet.stake_energy, side_bet_stake_factor())

## Lauf-Daten, mit denen eine Wette ihren Würfel-Gewinn würfelt (reine Daten).
func side_bet_context() -> Dictionary:
	return {"charm_ids": charm_ids(), "owned_essences": owned_essence_ids(),
		"tier": progress_tier()}

## Rückversicherung: verlorene Wetten geben ihren Einsatz zurück.
func side_bet_reinsured() -> bool:
	return _clause_active(DealClause.REINSURANCE)

## Frankiermaschine: so viele 1er-Pakete prägt sie am Rundenende - je eines pro
## Meteor der Rundenende-Zeremonie (scene_root treibt Flug und grant).
const STAMP_PACKS := 1

## Würfelt EIN 1er-Gravur-Paket der Frankiermaschine aus (Sorte nach den
## Regal-Gewichten) - noch ohne grant: es liegt erst im Lager, wenn sein Meteor
## angekommen ist.
func roll_stamp_pack() -> Pack:
	return Pack.roll_engraving_pack()

## Neue Glückszahl würfeln und sie in die Beschreibung jedes Lumpensammlers
## schreiben (die Karten-Instanzen, die der Dock live liest).
func _roll_lumpensammler_value() -> void:
	lumpensammler_value = randi_range(1, 6)
	for charm in owned_charms:
		if charm.id == Charm.RAG_COLLECTOR:
			charm.description = Charm.rag_collector_description(lumpensammler_value)

## Füllhorn: räumt die Rundenauszahlung mindestens so viele Überladungs-Stufen,
## fällt je Exemplar ein versiegelter Sonderposten an. Gezählt wird der BALKEN
## (wie beim Überflieger), und der Ort erledigt das "einmal je Runde".
const ENCORE_STAGES := 5

## Bucht die Prämie und liefert je Exemplar seinen Platz (leer = nichts, null =
## volles Magazin, das Paket ist zu Geld zerfallen). Die Plätze bleiben stehen,
## damit die Zeremonie ihr Exemplar am Dock weiter wiederfindet.
func apply_encore(cleared_stages: int) -> Array[Pack]:
	var granted: Array[Pack] = []
	if cleared_stages < ENCORE_STAGES:
		return granted
	for _i in charm_ids().count(Charm.ENCORE):
		# Das Füllhorn verspricht einen SONDERPOSTEN - kein Katalysator.
		var pack := Pack.roll_special_engraving_pack()
		pack.price = 0  # gefunden, nicht gekauft
		granted.append(pack)
	return grant_packs(granted)

## Schmuckkästchen: je Vorkommen und übrigem Würfel 10% Chance auf ein
## Fixinhalt-Mini-Paket des gefundenen Materials - nie auf den Würfel selbst.
## Liefert je Fund {material_id, copy, pack} für die Zeremonie; "copy" ist das
## Exemplar, dem er gehört (der Dock-Platz, von dem er ausgeht), "pack" das
## gelandete Paket - null heißt volles Magazin, der Fund ist zu Geld zerfallen.
func apply_jewelry_box(unused_dice: Array[DieDefinition]) -> Array[Dictionary]:
	var grants: Array[Dictionary] = []
	for i in charm_ids().count(Charm.JEWELRY_BOX):
		for _die in unused_dice:
			if randf() < 0.1:
				var material: DieMaterial = DieMaterial.all().pick_random()
				var pack := grant_material_pack(material)
				grants.append({"material_id": material.id, "copy": i, "pack": pack})
	return grants

## Rampenlicht: Wird die hervorgehobene Kombination gewertet, wächst sie
## dauerhaft um +5 Basispunkte und +1 Mult - höchstens einmal je Runde.
## true = eingelöst (der Aufrufer spielt die Zeremonie, siehe scene_root).
func claim_spotlight(combo_key: String) -> bool:
	if spotlight_claimed_this_round or combo_key == "" or combo_key != spotlight_combo:
		return false
	spotlight_claimed_this_round = true
	combo_growth[combo_key] = growth_of(combo_key) + Vector2i(SPOTLIGHT_POINTS, SPOTLIGHT_MULT)
	return true

## Dauerhaftes Wachstum einer Kombination (Basispunkte, Mult).
func growth_of(combo_key: String) -> Vector2i:
	return combo_growth.get(combo_key, Vector2i.ZERO)

## Midashandschuh: jede oben liegende Seite der gewerteten Würfel wird dauerhaft
## Gold (Pool-Instanzen). Liefert die vergoldeten Slots - leer, wenn die Hand
## nicht alle sechs Würfel nutzt oder alles schon Gold war.
func apply_midas_glove(defs: Array[DieDefinition], face_indices: Array[int], participating: Array[int]) -> Array[int]:
	var gilded: Array[int] = []
	if not CharmEffects.midas_applies(charm_ids(), participating.size()):
		return gilded
	for i in participating:
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0 or face >= defs[i].materials.size() or defs[i].materials[face] == DieMaterial.GOLD:
			continue
		defs[i].set_face_material(face, DieMaterial.GOLD)
		gilded.append(i)
	if not gilded.is_empty():
		pool_changed.emit()
	return gilded

## Goldener Handschlag: schafft EINE Hand die Quota im Alleingang, wird ihr
## erster Würfel ganz Gold - je Runde einmal. Eingebrannte Seiten mit Material
## bleiben, wie sie sind (Einbrand sperrt das Übermalen).
func apply_golden_handshake(def: DieDefinition, hand_points: int) -> bool:
	if def == null or golden_handshake_used_this_round:
		return false
	if not _clause_active(DealClause.GOLDEN_HANDSHAKE) or hand_points < effective_goal():
		return false
	for face in def.materials.size():
		if def.materials[face] != "" and RuneEffects.protects_face_value(def.runes_on(face)):
			continue
		def.set_face_material(face, DieMaterial.GOLD)
	golden_handshake_used_this_round = true
	pool_changed.emit()
	return true

## Lasurpinsel: läuft die Firnis-Schicht ins Leere, weil die obere Seite schon
## veredelt ist, fällt stattdessen ein versiegeltes Veredelungs-Paket an - einmal
## je gewertetem Firnis-Würfel und Zug. Liefert die Zahl der Pakete.
func apply_glaze_brush(defs: Array[DieDefinition], face_indices: Array[int],
		participating: Array[int]) -> int:
	if not charm_ids().has(Charm.GLAZE_BRUSH):
		return 0
	var copied := 0
	for i in participating:
		if i >= defs.size() or i >= face_indices.size() or defs[i] == null:
			continue
		if defs[i].essence_id != Essence.VARNISH:
			continue
		var face: int = face_indices[i]
		if face < 0 or face >= defs[i].materials.size():
			continue
		if defs[i].material_level(face) < DieMaterial.MAX_LEVEL:
			continue
		grant_engraving_pack(Engraving.by_id(Engraving.DOPING))
		copied += 1
	return copied

## Rundenzustand der Essenzen: die Hand-Zähler der Runde fangen neu an. Der Phosphor-Speicher NICHT - er sammelt über den ganzen Run.
## Alles hängt am Würfel-Exemplar, also an seiner Instanz-id - eine Def wandert
## nie zwischen Pool-Plätzen.
func roll_essence_round_state() -> void:
	die_scored_this_round.clear()
	round_trigger_count = 0
	round_crit_count = 0
	round_fumbles = 0
	round_bare_dice = 0

## Gespeicherte Basispunkte dieses Würfel-Exemplars (0 = leer).
func phosphor_store(die: DieDefinition) -> int:
	if die == null or die.essence_id != Essence.PHOSPHORESCENCE:
		return 0
	return int(essence_phosphor_store.get(die.get_instance_id(), 0))

## Gespeicherter Mult dieses Würfel-Exemplars - nur die Leuchtstoffröhre füllt ihn.
func phosphor_mult(die: DieDefinition) -> float:
	if die == null or die.essence_id != Essence.PHOSPHORESCENCE:
		return 0.0
	return float(essence_phosphor_mult.get(die.get_instance_id(), 0.0))

## Bucht die Speicher nach dem Zug: der Beitrag DIESES Zuges kommt oben drauf -
## der Speicher wird nie geleert, er wächst. Der ausgezahlte Stand steckt nicht im
## Beitrag (die Schrittliste misst nach der Auszahlung), er zahlt sich also nie
## selbst nach. breakdown ist die auf echte Slots umgerechnete Schrittliste.
func note_phosphor_stores(defs: Array[DieDefinition], breakdown: Dictionary) -> void:
	var keeps_mult := charm_ids().has(Charm.FLUORESCENT_TUBE)
	for step: Dictionary in breakdown.get("die_steps", []):
		var slot := int(step.get("slot", -1))
		if slot < 0 or slot >= defs.size() or defs[slot] == null:
			continue
		if defs[slot].essence_id != Essence.PHOSPHORESCENCE:
			continue
		var key := defs[slot].get_instance_id()
		essence_phosphor_store[key] = int(essence_phosphor_store.get(key, 0)) \
			+ int(step.get("base_contribution", 0))
		if keeps_mult:
			essence_phosphor_mult[key] = float(essence_phosphor_mult.get(key, 0.0)) \
				+ float(step.get("mult_contribution", 0.0))

## Schreibt die Hand-Zähler der Runde fort (Dunkelkammer, Gewitterfront).
func note_hand_counters(breakdown: Dictionary) -> void:
	round_trigger_count += maxi(0, int(breakdown.get("triggers", 0)))
	round_crit_count += maxi(0, int(breakdown.get("crits", 0)))

## Ein Fumble ist gefallen. volcanic = ein Vulkanblitz lag dabei in der Grube;
## dieser Zähler läuft IMMER mit, gelesen wird er nur unter der Aschewolke.
## Liefert die Energie, die der Trostpreis dabei geprägt hat - HIER gebucht, das
## Licht fliegt erst hinterher (book first, fly afterwards).
func note_fumble(volcanic: bool) -> int:
	round_fumbles += 1
	farkle_count += 1
	block_fumbles += 1
	if volcanic:
		ash_fumbles += 1
	if _clause_active(DealClause.BAD_STREAK):
		raise_blind(1.0 + BAD_STREAK_RAISE)
	_arm_afterburners()
	last_fumble_lost_part = destroy_fumble_part()
	var minted := CharmEffects.fumble_energy(charm_ids())
	if minted > 0:
		add_energy(minted)
	return minted

## Wertet dieses Würfel-Exemplar in dieser Runde zum ersten Mal? Die Marke hängt
## am Exemplar wie jede andere Runden-Marke.
func first_scoring(die: DieDefinition) -> bool:
	return die != null and not die_scored_this_round.has(die.get_instance_id())

## Merkt die gewerteten Würfel als "hat diese Runde gewertet" - beim Buchen des
## Zuges, nie schon in der Vorschau.
func note_dice_scored(defs: Array[DieDefinition], participating: Array[int]) -> void:
	for i in participating:
		if i >= 0 and i < defs.size() and defs[i] != null:
			die_scored_this_round[defs[i].get_instance_id()] = true

## Neonmarker: die materiallosen Würfel dieses Zuges wachsen in den Rundenzähler.
func note_bare_dice(count: int) -> void:
	round_bare_dice += maxi(0, count)

## Fumble: die Narbe wächst an der oberen Seite um +1 (faces = obere Seite je Slot).
func scar_fumble_dice(defs: Array[DieDefinition], faces: Array[int] = []) -> void:
	var scarred := false
	for i in defs.size():
		var die: DieDefinition = defs[i]
		if die == null:
			continue
		var face: int = faces[i] if i < faces.size() else -1
		if EssenceEffects.scars_on_fumble(die.essence_id) and face >= 0 and face < die.faces.size():
			die.faces[face] += EssenceEffects.SCAR_GROWTH
			scarred = true
	if scarred:
		note_pool_changed()

## Erster beteiligter Löschgas-Würfel (-1 = keiner). Er schluckt JEDEN Fumble,
## an dem er beteiligt war - kein Rundenlimit, kein Preis.
func smother_slot(defs: Array[DieDefinition], slots: Array[int]) -> int:
	for i in slots:
		if i >= defs.size() or defs[i] == null:
			continue
		if EssenceEffects.smothers_farkle(defs[i].essence_id):
			return i
	return -1

## Was auf dem Tisch schon steht (Charm.FEATURE_*): ein Charm, dessen Spielzeug
## fehlt, ist so tot wie ein Essenz-Charm ohne Seele. EINE Quelle für Auslage,
## Schwarzmarkt und Automat.
func charm_offer_features() -> Dictionary:
	return {
		Charm.FEATURE_SECRET_SHOP: true,
		Charm.FEATURE_SLOT_MACHINE: true,
	}

## Alle Essenzen im Besitz - Grundlage der Unikat-Sperre im Angebot.
func owned_essence_ids() -> Array[String]:
	var ids: Array[String] = []
	for die in owned_pool:
		if die.essence_id != "" and not ids.has(die.essence_id):
			ids.append(die.essence_id)
	return ids

func note_pool_changed() -> void:
	pool_changed.emit()

## Legt EINEN Würfel auf einen anderen Pool-PLATZ um: er wird herausgenommen und
## dort wieder eingesetzt, alle dazwischen rücken auf. Kein Tausch - der Würfel
## liegt danach genau dort, wo er losgelassen wurde, und die Reihe schließt sich
## hinter ihm (dieselbe Rechnung wie beim Warteschlangen-Umlegen).
## Das ist ANORDNUNG, nicht Ersetzung: die Instanzen wandern mitsamt ihrer
## Identität, ihr Inhalt wird nie überschrieben (become gilt nur beim Ersetzen).
## Damit bleibt jeder instanz-gebundene Zustand - der Phosphor-Speicher, die
## Löschgas-Ladung - automatisch am richtigen Würfel.
## Die Pool-Reihenfolge IST die Ziehreihenfolge des Rundendecks; das Umlegen vor
## der Runde ist also Strategie und wird nirgends nachträglich normalisiert.
func reorder_pool(from_index: int, to_index: int) -> bool:
	if from_index == to_index:
		return false
	if from_index < 0 or from_index >= owned_pool.size():
		return false
	if to_index < 0 or to_index >= owned_pool.size():
		return false
	var moved := owned_pool[from_index]
	owned_pool.remove_at(from_index)
	owned_pool.insert(to_index, moved)
	pool_changed.emit()
	return true

## Die GANZE Pool-Ordnung auf einmal setzen - der Kreislauf am Rundenende, wo der
## Pit-Inhalt zum neuen Pool wird. order muß eine PERMUTATION derselben Instanzen
## sein (dieselbe Identitäts-Regel wie reorder_pool); alles andere lässt den Pool
## unberührt, statt ihn halb umzuschreiben.
func reorder_pool_full(order: Array[DieDefinition]) -> bool:
	if order.size() != owned_pool.size():
		return false
	var seen := {}
	for die in order:
		if die == null or seen.has(die.get_instance_id()):
			return false
		seen[die.get_instance_id()] = true
	for die in owned_pool:
		if not seen.has(die.get_instance_id()):
			return false
	owned_pool = order.duplicate()
	pool_changed.emit()
	return true

## Die Inventar-Sicht der Wett-Auslage: Sorte+Größe -> Anzahl, reine Daten. Nur
## würfelbare Gravur-Pakete zählen - ein Fixinhalt oder Katalysator ist kein Einsatz.
func pack_stock() -> Dictionary:
	var out: Dictionary = {}
	for pack in owned_packs:
		if not _stakeable(pack):
			continue
		var key := SideBet.pack_stock_key(pack.type, pack.tier)
		out[key] = int(out.get(key, 0)) + 1
	return out

## Was ein Paket-Einsatz nehmen darf: Regalware mit Größe - ein Multiplikator-Netz
## ist kein Zahlen-Paket, das man verwettet.
static func _stakeable(pack: Pack) -> bool:
	return Pack.tierable(pack) and not pack.is_multiplier()

## Welche Pakete ein Paket-Einsatz WIRKLICH verzehrt: die letzten passenden, typ- und
## größengenau. EINE Auswahl - die Buchung nimmt sie, und die Wurf-Anker der Zeremonie
## fragen dieselbe VOR der Buchung.
func stake_packs_for(bet: SideBet) -> Array[Pack]:
	var out: Array[Pack] = []
	if bet.stake_kind != SideBet.Stake.PACKS:
		return out
	var wanted := side_bet_stake_packs(bet)
	for i in range(owned_packs.size() - 1, -1, -1):
		if out.size() >= wanted:
			break
		var pack := owned_packs[i]
		if _stakeable(pack) and pack.type == bet.stake_pack_type \
				and pack.tier == bet.stake_pack_tier:
			out.append(pack)
	return out

## Ob der Einsatz einer Wette bezahlbar ist. Steuerwetten sind immer platzierbar -
## sie kosten erst beim Nehmen (und reißen dort ab, siehe tax_side_bets).
func can_place_side_bet(bet: SideBet) -> bool:
	match bet.stake_kind:
		SideBet.Stake.PACKS:
			# Der Knopf NENNT seine Ware, also wird genau sie geprüft - die Werkstatt
			# kann sie mitten in der Wettannahme verbraucht haben.
			return stake_packs_for(bet).size() >= side_bet_stake_packs(bet)
		SideBet.Stake.ENERGY:
			return energy >= side_bet_stake_energy(bet)
		SideBet.Stake.MONEY_PER_HAND, SideBet.Stake.MONEY_PER_DIE:
			return true
	return money >= side_bet_stake(bet)

## Platziert eine Nebenwette: Einsatz sofort fällig (Geld, geopferte Pakete
## oder Energie), Auswertung am Rundenende.
func place_side_bet(bet: SideBet) -> void:
	bet.paid_money = 0
	bet.paid_energy = 0
	bet.paid_packs.clear()
	match bet.stake_kind:
		SideBet.Stake.PACKS:
			var packs := stake_packs_for(bet)
			bet.paid_packs.assign(packs)
			_consume_packs(packs)
		SideBet.Stake.ENERGY:
			bet.paid_energy = mini(energy, side_bet_stake_energy(bet))
			spend_energy(side_bet_stake_energy(bet))
		SideBet.Stake.MONEY_PER_HAND, SideBet.Stake.MONEY_PER_DIE:
			pass  # Steuerwette: die Rechnung kommt Hand für Hand
		_:
			bet.paid_money = side_bet_stake(bet)
			add_money(-side_bet_stake(bet))
	active_side_bets.append(bet)
	side_bets_changed.emit()

## Zieht die laufende Steuer der Steuerwetten für EINE genommene Hand ein
## (hand_dice = Würfel dieser Hand). Reicht das Geld nicht, verfällt die Wette:
## sie zahlt nichts mehr und ist verloren. Liefert das insgesamt Gezahlte.
func tax_side_bets(hand_dice: int) -> int:
	var paid := 0
	var changed := false
	for bet in active_side_bets:
		if bet.voided:
			continue
		var due := 0
		match bet.stake_kind:
			SideBet.Stake.MONEY_PER_HAND:
				due = side_bet_stake(bet)
			SideBet.Stake.MONEY_PER_DIE:
				due = side_bet_stake(bet) * maxi(hand_dice, 0)
		if due <= 0:
			continue
		changed = true
		if money < due:
			bet.voided = true
			continue
		add_money(-due)
		bet.paid_money += due
		paid += due
	if changed:
		side_bets_changed.emit()
	return paid

## Opfert GENAU diese Pakete (Einsatz einer Paket-Wette). Welche es sind, sagt
## stake_packs_for - hier wird nichts zweitgewählt.
func _consume_packs(packs: Array[Pack]) -> void:
	var removed := false
	for pack in packs:
		var index := owned_packs.find(pack)
		if index >= 0:
			owned_packs.remove_at(index)
			removed = true
	if removed:
		packs_changed.emit()

## Wertet alle platzierten Wetten gegen die Rundenbilanz aus, schüttet die
## Gewinne aus (Gravuren oder Bargeld je payout_kind) und leert die Auslage.
## Liefert die gewonnenen Wetten für die Auszahlungs-Anzeige.
## Was die Rückversicherung bei der letzten Abrechnung erstattet hat (Anzeige).
var last_side_bet_refund: Dictionary = {}

func resolve_side_bets(result: Dictionary) -> Array[SideBet]:
	var won: Array[SideBet] = []
	var factor := side_bet_payout_factor()
	var reinsured := side_bet_reinsured()
	last_side_bet_refund = {"money": 0, "energy": 0, "packs": [] as Array[Pack]}
	for bet in active_side_bets:
		if bet.evaluate(result):
			won.append(bet)
			_pay_side_bet(bet, factor)
		elif reinsured:
			_refund_side_bet(bet)
	active_side_bets.clear()
	side_bets_changed.emit()
	return won

## Rückversicherung: Geld, ⚡ und gezahlte Steuer zurück, die geopferten Karten
## (dieselben Exemplare) zurück ins Magazin. Eine Erstattung ist keine Einnahme.
func _refund_side_bet(bet: SideBet) -> void:
	if bet.paid_money > 0:
		refund_money(bet.paid_money)
		last_side_bet_refund["money"] = int(last_side_bet_refund["money"]) + bet.paid_money
	if bet.paid_energy > 0:
		var overflow := add_energy(bet.paid_energy)
		if overflow > 0:
			refund_money(overflow * ENERGY_OVERFLOW_MONEY)
		last_side_bet_refund["energy"] = int(last_side_bet_refund["energy"]) \
			+ bet.paid_energy - overflow
	if not bet.paid_packs.is_empty():
		var back: Array[Pack] = last_side_bet_refund["packs"]
		for pack in grant_packs(bet.paid_packs):
			if pack != null:
				back.append(pack)
	bet.paid_money = 0
	bet.paid_energy = 0
	bet.paid_packs.clear()

## Schüttet EINEN gewonnenen Einsatz in seiner Ware aus; factor hebt den
## Gewinnwert. JEDES gewährte Paket wird in awarded_packs GEMERKT (und jedes am
## vollen Magazin zerfallene gezählt): die Auszahlungs-Seite hält die Kassetten
## bis zum Kassieren zurück und zielt dann auf ihre uids.
func _pay_side_bet(bet: SideBet, factor: float) -> void:
	bet.awarded_choice = null
	bet.awarded_packs.clear()
	bet.awarded_fizzled = 0
	bet.awarded_pack = null
	bet.awarded_die = null
	match bet.payout_kind:
		SideBet.Payout.MONEY:
			# Quotenblatt hebt NUR das Bargeld.
			add_money(CharmEffects.side_bet_money(bet.reward_money(factor), charm_ids()))
		SideBet.Payout.ENERGY:
			var overflow := add_energy(bet.reward_energy(factor))
			if overflow > 0:
				add_money(overflow * ENERGY_OVERFLOW_MONEY)  # volle Börse zahlt bar
		SideBet.Payout.PART:
			var part := bet.reward_part()
			if part != null:
				stash_part(part)
		SideBet.Payout.CARD_PACK:
			bet.awarded_choice = _award_pack(bet.reward_card_pack(factor), null)
		SideBet.Payout.DICE_PACK:
			bet.awarded_choice = _award_pack(bet.reward_dice_pack(factor), null)
		SideBet.Payout.DIE:
			# Der Weg des Ladenkaufs: ins Ausgabefach, und von dort SOFORT in den Vorrat.
			var die := bet.reward_die(factor)
			if die != null:
				stash_die(die, 0)
				bet.awarded_die = pending_dice[pending_dice.size() - 1]
		_:
			# Genau die Karten, die in der Grube lagen.
			for pack in bet.reward_cards(factor):
				bet.note_awarded(grant_pack(pack))
			if not bet.awarded_packs.is_empty():
				bet.awarded_pack = bet.awarded_packs[0]

# --- Fumble-Automaten (Slot-Bank) ---------------------------------------------

## Einsatz für einen Dreh an Automat machine in ⚡ (Freispiele drehen gratis).
func slot_spin_energy(machine: int) -> int:
	if charm_free_spin_open():
		return 0
	return SlotMachine.SPIN_ENERGYS[clampi(machine, 0, SlotMachine.MACHINE_COUNT - 1)]

## Ob der Spieler Automat machine gerade drehen darf: in der Sitzung noch frei und
## der Einsatz bezahlbar.
func can_spin_slot(machine: int) -> bool:
	return slot_bank.can_spin(machine) and energy >= slot_spin_energy(machine)

## Bezahlt den Einsatz und WÜRFELT Automat machine, schreibt das Ergebnis aber noch
## NICHT auf die Wand - das tut commit_slot erst nach der Walzen-Animation, damit
## Topf und Bust mit der Landung erscheinen und nicht schon beim Einwurf. Liefert
## den gewürfelten Block (oder [], wenn der Dreh nicht möglich war).
func spin_slot(machine: int) -> Array:
	if not can_spin_slot(machine):
		return []
	if charm_free_spin_open():
		free_spin_used_this_visit = true  # ein Freispiel je Besuch, nicht je Automat
	else:
		spend_energy(slot_spin_energy(machine))
	return slot_bank.roll(machine, null, farkle_count)


## Schreibt den gewürfelten Block auf die Wand (Topf/Bust) - die Anzeige ruft das,
## sobald die Walze gelandet ist.
func commit_slot(machine: int, block: Array) -> void:
	slot_bank.commit(machine, block)

## Zahlt die Sitzung aus: löst jede Gewinn-Reihe in ihre Preise auf (der Längen-
## Bonus steckt schon in den specs) und setzt die Bank zurück. Gebucht wird NOCH
## NICHT - das tut book_slot_prize, sobald der Gewinn als Licht das Automaten-
## Fenster verlässt; sonst füllten sich Schubladen und Pool schon während der
## Anzeige. Liefert die Preise und die Reihen-Deskriptoren (für die Anzeige) -
## VOR dem Reset eingefroren.
func redeem_slots() -> Dictionary:
	var runs := slot_bank.runs()
	var prizes: Array[SlotPrize] = []
	for run in runs:
		for spec: Dictionary in run["specs"]:
			prizes.append(SlotPrize.from_spec(spec, progress_tier()))
	slot_bank.reset_session()
	return {"prizes": prizes, "runs": runs}

## Bucht EINEN Automaten-Gewinn (Aufruf beim Abflug seines Lichts).
func book_slot_prize(prize: SlotPrize) -> void:
	_book_slot_prize(prize, 1)

func _book_slot_prize(prize: SlotPrize, mult: int) -> void:
	match prize.kind:
		SlotPrize.Kind.ENGRAVING, SlotPrize.Kind.MATERIAL, SlotPrize.Kind.DICE_ENGRAVING:
			for i in mult:
				for pack in prize.packs:
					grant_pack(pack.duplicate())  # sonst teilte der Multiplikator eine Resource
		SlotPrize.Kind.ENERGY:
			var overflow := add_energy(prize.energy * mult)
			if overflow > 0:
				add_money(overflow * ENERGY_OVERFLOW_MONEY)  # voller Speicher zahlt bar
		SlotPrize.Kind.DIE:
			# EIN Weg für jeden Würfel: auch der Automaten-Gewinn liegt erst im
			# Ausgabefach, bis der Spieler ihm selbst einen Pool-Platz gibt.
			if prize.die != null:
				for i in mult:
					stash_die(prize.die, 0)

## Nächste Runde (läuft nur nach einer geschafften): gespielten Blind merken, Glück
## +1, Blind wachsen lassen und die Auslage würfeln. Runde 1 bekommt keine Auslage.
func advance_round() -> void:
	while blind_history.size() < round_number - 1:
		blind_history.append(floor_to_blind(float(BASE_GOAL)))
	blind_history.append(effective_goal())
	if temp_luck > 0:
		add_luck(-temp_luck)
		temp_luck = 0
	add_luck(1)
	free_flips_used = 0
	var old_block := block_of_round(round_number)
	round_number += 1
	if block_of_round(round_number) != old_block:
		block_fumbles = 0
	blind_value *= 1.0 + blind_growth(round_number)
	round_goal = floor_to_blind(blind_value)
	roll_route_offers()

## Fahrplan-BLOCK der Runden-Ziele: die Ziele stehen zu je count fest und bleiben
## stehen, bis das letzte des Blocks geschafft ist - erst dann rückt ein frischer
## Block nach. Rein für die Hub-Anzeige.
func goal_roadmap(count: int) -> Array[int]:
	var goals: Array[int] = []
	if count <= 0:
		return goals
	var first_round := round_number - goal_roadmap_index(count)
	for i in count:
		goals.append(roadmap_goal(first_round + i))
	return goals

## Position des AKTUELLEN Ziels im Block (0-basiert): davor = geschafft, danach
## = noch offen.
func goal_roadmap_index(count: int) -> int:
	return (round_number - 1) % maxi(1, count)

## --- Überladung (Overcharge) --------------------------------------------------

## Punktebedarf der Stufe (1-basiert): Basisziel × Skalierung^(stufe-1) → 150,
## 300, 600 … Basis ist das WIRKSAME Ziel, damit ein Quota-Malus den ganzen
## Balken mitzieht (Stufen, Schwellen, Sieg-Prüfung).
func stage_size(stage: int) -> int:
	return roundi(effective_goal() * pow(stage_scale(), stage - 1))

## Sicherungsfall ×4, Netzbrummen ×3, sonst ×2 - der schärfere Malus gewinnt.
func stage_scale() -> float:
	if _clause_active(DealClause.FUSE_FAILURE):
		return FUSE_FAILURE_SCALE
	if _clause_active(DealClause.MAINS_HUM):
		return MAINS_HUM_SCALE
	return 2.0

## Kumulative Punktschwelle zum ABSCHLUSS der Stufe (Summe der Stufengrößen);
## bei ×2 und ohne Aufschlag ergibt das die alten 150, 450, 1050, 2250, 4650.
func cumulative_threshold(stage: int) -> int:
	var total := 0
	for s in range(1, stage + 1):
		total += stage_size(s)
	return total

## Anzahl vollständig gefüllter Überladungs-Stufen bei points (0..max_overcharge_stages).
func stages_cleared(points: int) -> int:
	var cap := max_overcharge_stages()
	var cleared := 0
	while cleared < cap and points >= cumulative_threshold(cleared + 1):
		cleared += 1
	return cleared

## Kumulative Stufen-Schwellen, die im Intervall (old_points, new_points] liegen
## - die Rollover-Punkte, an denen der Drain kurz innehält. Bis zum Deckel.
func thresholds_crossed(old_points: int, new_points: int) -> Array[int]:
	var crossed: Array[int] = []
	for stage in range(1, max_overcharge_stages() + 1):
		var t := cumulative_threshold(stage)
		if t > new_points:
			break  # Schwellen wachsen monoton - der Rest liegt erst recht darüber
		if t > old_points:
			crossed.append(t)
	return crossed

## Balken-Fortschritt bei points: aktuelle Stufe (1-basiert), gefüllte Stufen,
## Punkte IN der aktuellen Stufe und deren Größe. Alles geräumt -> letzte Stufe voll.
func stage_progress(points: int) -> Dictionary:
	var cap := max_overcharge_stages()
	var cleared := stages_cleared(points)
	if cleared >= cap:
		var full := stage_size(cap)
		return {"stage": cap, "cleared": cleared, "into_stage": full, "stage_size": full}
	var current := cleared + 1
	return {"stage": current, "cleared": cleared,
		"into_stage": points - cumulative_threshold(cleared), "stage_size": stage_size(current)}

## --- Energie (⚡) & Schwarzmarkt -----------------------------------------------
## Geräumte Überladungs-Stufen zahlen kein Geld mehr, sie prägen je eine Energie in
## eine GEDECKELTE Börse; was nicht mehr hineinpasst, fällt zum alten Satz als Geld
## an. GameRun rechnet nur die Aufteilung (energy_split), gebucht wird in der
## Auszahlungs-Zeremonie.

## Der Deckel wächst NUR in Fünferschritten, damit eine neue Stufe als "eine Gruppe
## des Energie-Rings erwacht" lesbar ist - nie als krumme Zahl.
const ENERGY_ROW := 5
## Mehr fasst der Ring nicht, was immer den Deckel künftig hebt.
const ENERGY_CAP_LIMIT := 50

## Barwert einer ⚡, die nicht mehr in die Börse passt (Wett-Gewinn) - derselbe
## Satz wie eine übergelaufene Überladungs-Stufe.
const ENERGY_OVERFLOW_MONEY := 5

## Preise der Schwarzmarkt-Ware in Energie. Der Charm kostet genau eine volle
## Reihe: schon der Grunddeckel (5) deckt den ganzen Laden ab.
const SECRET_CHARM_PRICE := 5

## Stärken der Sonderposten-Karte: Zellen auf EINER Karte, ⚡-Preis und
## Ziehgewicht. Der Schwarzmarkt verkauft nie mehr als eine Karte auf einmal
## (Spieler-Entscheid 2026-10-29, statt der Bündel einzelner Karten) - je stärker,
## desto seltener.
const SECRET_SPECIAL_GRADES := [
	{"cells": 2, "price": 4, "weight": 3},
	{"cells": 3, "price": 6, "weight": 2},
	{"cells": 4, "price": 8, "weight": 1},
]
## Preis des Neuwurfs - FLACH, jedes Mal derselbe. Die alte Fibonacci-Leiter
## machte den zweiten Wurf eines Besuchs unbezahlbar; der Laden soll benutzbar
## bleiben, die ⚡ selbst ist die Schranke.
const SECRET_REROLL_BASE := 3
## Aufteilung des Wildcard-Platzes: ein Drittel Essenzwürfel, sonst Sonderbestand.
const SECRET_WILDCARD_DIE_CHANCE := 0.34

## Preis eines Essenzwürfels je Seltenheit seiner Seele - die Leiter des Ladens
## (5 ⚡ = eine volle Grundreihe) nach oben verlängert.
const SECRET_DIE_PRICES := {
	Essence.Rarity.RARE: 6,
	Essence.Rarity.EPIC: 9,
	Essence.Rarity.LEGENDARY: 13,
}

## Schlüssel eines Angebots (Single Source of Truth wie die id-Konstanten).
const OFFER_KIND := "kind"
const OFFER_ITEM := "item"
const OFFER_PRICE := "price"
const OFFER_SOLD := "sold"
const KIND_CHARM := "charm"
const KIND_ENGRAVING := "engraving"
const KIND_DIE := "die"
## Katalysator-Kassette: die zweite Familie des Sonderbestands, also auch die
## zweite Ware des Sonderposten-Platzes.
const KIND_CATALYST := "catalyst"
const KIND_BLANK := "blank"
## Ein Modul (nur die vervielfachenden Schwarzmarkt-Teile).
const KIND_PART := "part"
## Ein Charm-Projektor: er ersetzt BEIDE Ware-Plätze der Auslage, OFFER_ITEM ist null.
const KIND_PROJECTOR := "projector"
## Eine Powerbank (+1 Fünfergruppe Energie-Deckel) auf dem Wildcard-Platz, OFFER_ITEM ist null.
const KIND_POWERBANK := "powerbank"
const POWERBANK_PRICE_BASE := 4
const SECRET_POWERBANK_CHANCE := 0.25
## Statisch, damit Tests die Auslage festhalten können.
static var secret_powerbank_chance := SECRET_POWERBANK_CHANCE

## Umrechnungskurs des Hinterzimmers: zehn Dollar auf die Energie. Jede Ware, die
## beide Läden führen (die Katalysatoren), preist sich danach, statt eine zweite
## Tabelle zu pflegen.
const SECRET_MONEY_PER_ENERGY := 10
## Anteil der Katalysatoren am Sonderposten-Platz - die Gravur bleibt die Regel.
const SECRET_CATALYST_CHANCE := 0.35
## Eigene Ziehchance des ROHLINGS - er ist NUR hier zu haben (nie in Pack.SPECIAL_ROLL_WEIGHTS).
const SECRET_BLANK_CHANCE := 0.25
## Eigene Ziehchance eines Moduls im Sonderbestand-Platz.
const SECRET_PART_CHANCE := 0.25

## ⚡-Preis eines Dollar-Preises im Hinterzimmer, aufgerundet und nie unter 1.
static func secret_energy_price(money_price: int) -> int:
	return maxi(1, ceili(float(money_price) / float(SECRET_MONEY_PER_ENERGY)))

var energy: int = 0:
	set(value):
		if energy == value:
			return
		energy = value
		energy_changed.emit(energy)

var secret_rerolls: int = 0
var secret_stock: Array[Dictionary] = []

## Deckel der Börse: eine Fünfergruppe, plus eine je Powerbank (Spieler-Entscheid
## 2026-11-22: der Stresstest hebt ihn nicht mehr).
func energy_cap() -> int:
	return mini(energy_cap_rows() * ENERGY_ROW, ENERGY_CAP_LIMIT)

func energy_cap_rows() -> int:
	return 1 + storage_rows

## Zusätzliche Fünfergruppen der Börse: Powerbanks des Schwarzmarkts und der Große Speicher.
var storage_rows: int = 0

## So viele Powerbanks passen höchstens in die Börse.
func max_storage_rows() -> int:
	return ENERGY_CAP_LIMIT / ENERGY_ROW - 1

## ⚡-Preis der nächsten Powerbank, nie über dem Deckel (-1 = der Speicher ist voll ausgebaut).
func powerbank_price() -> int:
	if energy_cap() >= ENERGY_CAP_LIMIT:
		return -1
	return POWERBANK_PRICE_BASE + storage_rows

## Aufteilung von stages in Börse und Überlauf - reine Vorschau gegen den
## aktuellen Stand, damit die Zeremonie ihre Kometen vorab planen kann.
## stages sind ÜBERLADUNGS-STUFEN, nicht ⚡: der Doppellader prägt zwei je
## Stufe. Was gebucht wird, zählt add_energy in ⚡.
func energy_split(stages: int) -> Dictionary:
	return _split_energy(maxi(stages, 0) * energy_per_stage())

func _split_energy(minted: int) -> Dictionary:
	var stored := mini(minted, maxi(energy_cap() - energy, 0))
	return {"stored": stored, "overflow": minted - stored}

## Prägt count ⚡ bis zum Deckel und liefert, was nicht mehr hineinpasste -
## der Aufrufer zahlt diesen Überlauf als Geld aus.
func add_energy(count: int) -> int:
	var split := _split_energy(maxi(count, 0))
	energy += int(split["stored"])
	return int(split["overflow"])

func spend_energy(count: int) -> void:
	energy = maxi(0, energy - count)

## Bucht die Kupfer-Energie eines Zuges: was in die Börse passt, wird geprägt;
## was darüber hinausläuft, zahlt bar. Liefert das ausgezahlte Geld - dieselbe
## Überlauf-Grammatik wie die Stufen-Auszahlung, nur zum Kupfer-Satz.
func book_copper_energy(count: int) -> int:
	if count <= 0:
		return 0
	var overflow := add_energy(count)
	if overflow <= 0:
		return 0
	var paid := overflow * MaterialEffects.COPPER_OVERFLOW_MONEY
	add_money(paid)
	return paid

## Preis des nächsten Neuwurfs - immer derselbe. Die Hehlerware drückt ihn NICHT:
## ein Neuwurf ist keine Ware.
func secret_reroll_cost() -> int:
	return SECRET_REROLL_BASE

## Fälliger ⚡-Preis EINES Angebots (Hehlerware drückt ihn, nie unter 1). Einzige
## Quelle für Anzeige, Bezahlbarkeit und Abbuchung.
func secret_offer_price(offer: Dictionary) -> int:
	var price := int(offer.get(OFFER_PRICE, 0))
	if price <= 0:
		return price
	if offer.get(OFFER_KIND) == KIND_PART:
		price = CharmEffects.part_price(price, charm_ids())
	price -= CharmEffects.secret_price_cut(charm_ids())
	if _clause_active(DealClause.BACK_ROOM_CONTACT):
		price -= deal_bonus_factor()  # Hinterzimmer-Kontakt
	return maxi(1, price)

## Würfelt die GANZE Auslage neu (auch verkaufte Plätze); false, wenn die Energie
## nicht reicht.
func reroll_secret_stock() -> bool:
	var cost := secret_reroll_cost()
	if energy < cost:
		return false
	spend_energy(cost)
	secret_rerolls += 1
	_roll_secret_stock()
	secret_stock_changed.emit()
	return true

## Kauft Platz index; je Auslage einmal, der verkaufte Platz bleibt leer.
func buy_secret_offer(index: int) -> bool:
	if index < 0 or index >= secret_stock.size():
		return false
	var offer := secret_stock[index]
	var price := secret_offer_price(offer)
	if bool(offer[OFFER_SOLD]) or energy < price:
		return false
	# Voller Dock: der Charm-Platz bleibt liegen, die Energie wird nicht abgebucht.
	if offer[OFFER_KIND] == KIND_CHARM and charms_full():
		return false
	if offer[OFFER_KIND] == KIND_PART and not parts_room():
		return false
	if offer[OFFER_KIND] == KIND_PROJECTOR and projectors >= MAX_PROJECTORS:
		return false
	if offer[OFFER_KIND] == KIND_POWERBANK and powerbank_price() < 0:
		return false
	# Volles Magazin: alles VERSIEGELTE sperrt der Deckel wie eine knappe Börse -
	# prüfen vor dem Zahlen, sonst zerfiele bezahlte Ware zu $3. Der Würfel geht ins
	# Ausgabefach und kennt darum keinen Deckel.
	if offer[OFFER_KIND] != KIND_CHARM and offer[OFFER_KIND] != KIND_DIE \
			and offer[OFFER_KIND] != KIND_PART and offer[OFFER_KIND] != KIND_PROJECTOR \
			and offer[OFFER_KIND] != KIND_POWERBANK and pack_room() < 1:
		return false
	spend_energy(price)
	match offer[OFFER_KIND]:
		KIND_POWERBANK:
			storage_rows += 1
			energy_changed.emit(energy)  # der Deckel ist gewachsen
		KIND_PROJECTOR:
			_add_projector()
		KIND_CHARM:
			var charm: Charm = offer[OFFER_ITEM]
			_grant_charm(charm)
		KIND_DIE:
			# Ware wie jeder gekaufte Würfel: ab ins Ausgabefach, den Pool-Platz
			# sucht der Spieler selbst - kein stiller Tausch.
			var die: DieDefinition = offer[OFFER_ITEM]
			stash_die(die, 0)
		KIND_PART:
			stash_part(offer[OFFER_ITEM] as ComboPart)
		_:
			# Jede versiegelte Ware liegt als fertige Kassette im Angebot - sie geht,
			# wie sie ist, also bekommt der Spieler genau das gezeigte Netz.
			grant_pack(offer[OFFER_ITEM] as Pack)
	offer[OFFER_SOLD] = true
	secret_stock_changed.emit()
	return true

## Feste Plätze: legendärer Charm, Spezial-Gravur, Wildcard - oder, mit
## secret_projector_chance, statt der beiden Ware-Plätze EIN Projektor.
func _roll_secret_stock() -> void:
	secret_stock.clear()
	secret_stock.append(_secret_charm_offer())
	if projectors < MAX_PROJECTORS and randf() < secret_projector_chance:
		secret_stock.append(_secret_offer(KIND_PROJECTOR, null, projector_price()))
		return
	secret_stock.append(_secret_special_offer())
	secret_stock.append(_secret_wildcard_offer())

## Der Sonderposten-Platz führt beide Familien des Sonderbestands: meist ein
## starke Gravur-Karte, manchmal eine Katalysator-Kassette.
## EIN Eingang, damit der Wildcard-Platz dieselbe Auswahl bekommt.
func _secret_special_offer() -> Dictionary:
	if randf() < SECRET_BLANK_CHANCE and not _secret_blank_listed():
		return _secret_blank_card()
	if randf() < SECRET_PART_CHANCE:
		return _secret_part_offer()
	if randf() < SECRET_CATALYST_CHANCE:
		var card := _secret_catalyst_offer()
		if not card.is_empty():
			return card
	return _secret_engraving_offer()

## Eine Katalysator-Kassette, die nicht schon in der Auslage liegt - zwei gleiche
## Plätze lesen sich als Fehler. Liegen alle, weicht der Platz auf eine
## Gravur aus statt leer zu bleiben.
func _secret_catalyst_offer() -> Dictionary:
	var listed := _secret_catalyst_listed()
	var pool: Array[String] = []
	for id in Pack.catalyst_ids():
		if not listed.has(id):
			pool.append(id)
	if pool.is_empty():
		return {}
	return _secret_catalyst_card(String(pool.pick_random()))

## Die Katalysator-ids, die schon in der Auslage liegen.
func _secret_catalyst_listed() -> Array[String]:
	var listed: Array[String] = []
	for offer in secret_stock:
		if offer[OFFER_KIND] == KIND_CATALYST:
			var shown: Pack = offer[OFFER_ITEM]
			listed.append(shown.catalyst_id)
	return listed

func _secret_catalyst_card(id: String) -> Dictionary:
	return _secret_offer(KIND_CATALYST, Pack.catalyst(id),
		secret_energy_price(Pack.catalyst_price(id)))

## Ein ROHLING als Angebot. Er reist wie eine Katalysator-Kassette (KIND_CATALYST
## trägt ein fertiges Pack, das buy_secret_offer unverändert durchreicht).
func _secret_blank_card() -> Dictionary:
	return _secret_offer(KIND_BLANK, Pack.blank_card(),
		secret_energy_price(Pack.BLANK_PRICE))

## Ein vervielfachendes Modul - nur hier zu haben, Preis in ⚡ aus seinem
## Grundpreis (Supraleiter drückt ihn in secret_offer_price).
func _secret_part_offer() -> Dictionary:
	var part := ComboPart.roll_secret()
	return _secret_offer(KIND_PART, part, secret_energy_price(part.price))

## Liegt schon ein Rohling in der Auslage? Zwei gleiche Plätze lesen sich als Fehler.
func _secret_blank_listed() -> bool:
	for offer in secret_stock:
		if offer.get(OFFER_KIND) == KIND_BLANK:
			return true
	return false

## Der dritte Platz würfelt nur noch WARE: Essenzwürfel oder Sonderbestand. Der
## Würfel ist der EINZIGE Weg an eine Schwarzmarkt-Seele - im normalen Handel
## liegen sie nie. Kein Charm-Zweig mehr: das Hinterzimmer hat genau EINEN
## Karten-Sitz, und der gehört dem legendären Platz - nie zwei Karten, nie null
## (nur der Erschöpfungs-Rückfall des legendären Topfes lässt ihn leer).
func _secret_wildcard_offer() -> Dictionary:
	if powerbank_price() >= 0 and randf() < secret_powerbank_chance:
		return _secret_offer(KIND_POWERBANK, null, powerbank_price())
	if randf() < SECRET_WILDCARD_DIE_CHANCE:
		var die_offer := _secret_die_offer()
		if not die_offer.is_empty():
			return die_offer
	return _secret_special_offer()

## Essenzwürfel: ein frischer Würfel mit einer Schwarzmarkt-Seele. Unikate, die
## der Spieler schon besitzt, fallen weg; ist der Topf leer, liefert der Platz
## {} und der Aufrufer weicht auf Charm/Gravur aus.
func _secret_die_offer() -> Dictionary:
	var owned := owned_essence_ids()
	var pool: Array[Essence] = []
	for essence in Essence.all():
		if essence.secret and not (essence.unique and owned.has(essence.id)):
			pool.append(essence)
	if pool.is_empty():
		return {}
	var essence: Essence = pool.pick_random()
	var die := DiceOffer.make_die(DiceOffer.TEMPLATES.pick_random(), progress_tier())
	die.essence_id = essence.id
	die.display_name = essence.display_name
	return _secret_offer(KIND_DIE, die, int(SECRET_DIE_PRICES.get(essence.rarity, SECRET_CHARM_PRICE)))

## Legendärer Charm, den der Spieler weder besitzt noch schon in der Auslage
## liegen hat. Ist der Topf leer, rückt eine Spezial-Gravur nach - die sind
## beliebig oft kaufbar, die Auslage kann also nie tot sein.
func _secret_charm_offer() -> Dictionary:
	var taken := owned_charm_ids()
	for offer in secret_stock:
		if offer[OFFER_KIND] == KIND_CHARM:
			var listed: Charm = offer[OFFER_ITEM]
			taken.append(listed.id)
	var pool: Array[Charm] = []
	# Auch das Hinterzimmer führt keinen Essenz-Charm, dessen Seele fehlt.
	for charm in Charm.offerable(Charm.all(), owned_essence_ids(), charm_offer_features()):
		if charm.rarity == Charm.RARITY_LEGENDARY and not taken.has(charm.id):
			pool.append(charm)
	if pool.is_empty():
		return _secret_engraving_offer()
	return _secret_offer(KIND_CHARM, Charm.pick_weighted(pool), SECRET_CHARM_PRICE)

## Eine Gravur aus dem Sonderbestand (Engraving.SPECIAL_IDS), die nicht schon in
## der Auslage liegt - zwei gleiche Plätze zum selben Preis lesen sich als Fehler.
## Sind alle Sonderposten gelistet, sind Wiederholungen erlaubt: ein leerer Platz
## wäre schlechter (wie beim Charm-Platz).
func _secret_engraving_offer() -> Dictionary:
	var listed: Array[String] = []
	for offer in secret_stock:
		if offer[OFFER_KIND] == KIND_ENGRAVING:
			var shown: Pack = offer[OFFER_ITEM]
			listed.append(shown.fixed_engraving.id)
	var pool: Array[Engraving] = []
	var all_specials: Array[Engraving] = []
	for engraving in Engraving.all():
		if not Engraving.is_special_id(engraving.id):
			continue
		all_specials.append(engraving)
		if not listed.has(engraving.id):
			pool.append(engraving)
	if pool.is_empty():
		pool = all_specials
	# Das Netz wird HIER gewürfelt, nicht beim Kauf: gekauft wird, was ausliegt.
	var grade := _roll_special_grade()
	var card := Pack.fixed_engraving_pack(pool.pick_random(), 1, 0, null, int(grade["cells"]))
	return _secret_offer(KIND_ENGRAVING, card, int(grade["price"]))

## Gewichteter Griff in SECRET_SPECIAL_GRADES - die stärkste Karte ist der Fund,
## nicht der Regelfall.
func _roll_special_grade() -> Dictionary:
	var total := 0
	for grade: Dictionary in SECRET_SPECIAL_GRADES:
		total += int(grade["weight"])
	var pick := randi() % maxi(total, 1)
	for grade: Dictionary in SECRET_SPECIAL_GRADES:
		pick -= int(grade["weight"])
		if pick < 0:
			return grade
	return SECRET_SPECIAL_GRADES[0]

func _secret_offer(kind: String, item: Resource, price: int) -> Dictionary:
	return {OFFER_KIND: kind, OFFER_ITEM: item, OFFER_PRICE: price, OFFER_SOLD: false}

# --- Testhilfen (Testmodus im Einstellungs-Menü) -----------------------------

## Chance, eine Seite im Testmodus veredelt auszuliefern - sonst wäre der
## veredelte Zustand nur über die Gravur zu sehen.
const TEST_LEVEL_CHANCE := 0.34

## Belegt jede Seite aller Pool-Würfel mit zufälligen Materialien und veredelt
## einen Teil davon. Jeder Würfel bekommt frische Arrays (nie geteilt).
func randomize_all_materials() -> void:
	var ids: Array[String] = []
	for material in DieMaterial.all():
		ids.append(material.id)
	for die in owned_pool:
		var mats: Array[String] = []
		var levels: Array[int] = []
		for i in die.materials.size():
			mats.append(ids.pick_random())
			var level := 1
			while level < DieMaterial.MAX_LEVEL and randf() < TEST_LEVEL_CHANCE:
				level += 1
			levels.append(level)
		die.materials = mats
		die.levels = levels
	pool_changed.emit()

func clear_all_materials() -> void:
	for die in owned_pool:
		var mats: Array[String] = []
		var levels: Array[int] = []
		for i in die.materials.size():
			mats.append("")
			levels.append(0)  # ohne Material kein Zustand
		die.materials = mats
		die.levels = levels
	pool_changed.emit()

## Debug: jede Seite jedes Pool-Würfels bekommt eine zufällige Rune (Slot 0).
func debug_rune_all_dice(rng: RandomNumberGenerator = null) -> void:
	var ids: Array[String] = []
	for rune in Rune.all():
		ids.append(rune.id)
	for die in owned_pool:
		for face in die.runes.size():
			var pick := rng.randi_range(0, ids.size() - 1) if rng != null else randi() % ids.size()
			die.set_rune(face, ids[pick])
	pool_changed.emit()

## Debug: jede Seite jedes Pool-Würfels bekommt eine Zufallszahl 1..2000.
func debug_randomize_faces(rng: RandomNumberGenerator = null) -> void:
	for die in owned_pool:
		for face in die.faces.size():
			die.faces[face] = rng.randi_range(1, 2000) if rng != null else randi_range(1, 2000)
	pool_changed.emit()

## Verteilt Seelen über den ganzen Pool. Der EINZIGE Weg im Spiel, der eine
## bestehende Essenz überschreibt - angeboren heißt sonst angeboren (siehe
## test_essence_immutability). Ausgeteilt statt gewürfelt: der gemischte Katalog
## wird reihum vergeben, damit alle Raritätsstufen nebeneinander liegen; 30
## Zufallszüge zeigten womöglich keine einzige legendäre Animationsstufe.
func randomize_all_essences() -> void:
	var deck: Array[Essence] = Essence.all()
	deck.shuffle()
	var repeatable: Array[Essence] = []
	for essence in deck:
		if not essence.unique:
			repeatable.append(essence)
	for i in owned_pool.size():
		# Mehr Würfel als Seelen: Unikate bleiben Unikate, der Rest wiederholt.
		var essence: Essence = deck[i] if i < deck.size() else repeatable.pick_random()
		owned_pool[i].essence_id = essence.id
	pool_changed.emit()

## Nimmt jedem Pool-Würfel die Seele - und mit dem Vakuum den zweite Rune,
## den allein seine Schale trägt (rune_slots).
func clear_all_essences() -> void:
	for die in owned_pool:
		die.essence_id = ""
		die.second_runes = ["", "", "", "", "", ""] as Array[String]
	pool_changed.emit()



