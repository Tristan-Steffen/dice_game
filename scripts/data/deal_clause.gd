class_name DealClause
extends Resource
## Eine Klausel eines Vertrags mit dem Haus. Eine Vertragskarte = 1 Bonus- +
## 1 Malusklausel DERSELBEN Stufe; Werbegeschenke tragen nur einen Bonus,
## Stresstest-Konditionen nur einen Malus.
##
## Hier stehen nur Daten und Texte; die WIRKUNG lösen GameRun-Abfragen über die
## id auf (effective_goal, round_payout_factor, ...) - nie ein stiller Zweig in
## scene_root.

## Laufzeit einer Klausel: sofort einmalig, nur die Runde der Unterschrift, oder
## bis zur Abrechnung nach der Boss-Runde (allein der Stammkunde).
enum Scope { INSTANT, ROUND, BLOCK }

enum Kind { BONUS, MALUS }

## Vertragsstufe. TREAT = Werbegeschenk (reiner Bonus), BOSS = Stresstest-
## Kondition (reiner Malus).
enum Tier { ONE, TWO, THREE, TREAT, BOSS }

## Themen-Etiketten. Bonus und Malus einer Karte dürfen kein Tag teilen - das
## verhindert Nullsummen-Paare ("Auszahlung ×2" gegen "Auszahlung ×0,5").
const TAG_PAYOUT := "auszahlung"
const TAG_QUOTA := "quota"
const TAG_SIDEBET := "nebenwette"
const TAG_OVERCHARGE := "überladung"
const TAG_LEFTOVER := "übrig"
const TAG_SHOP := "shop"
const TAG_ENERGY := "energie"
const TAG_THROTTLE := "drossel"
const TAG_MONEY := "geld"
## Alles, was an der Serienlänge der Presse dreht - Bonus wie Malus tragen
## dasselbe Etikett, damit die Paarungsregel nie beide auf EINE Karte legt.
const TAG_SERIES := "serie"
## Alles, was am GLÜCK des Laufs dreht.
const TAG_LUCK := "glück"
const TAG_WORKSHOP := "werkstatt"
const TAG_CHARM := "charm"
const TAG_MODULE := "modul"

# --- Klausel-ids (Single Source of Truth) --------------------------------------

# Bonus, Stufe 1
const SAVINGS_BONUS := "savings_bonus"
const FREE_CHARM := "free_charm"
const ADVANCE_PAYMENT := "advance_payment"
const SPOTLIGHT := "spotlight"
const CASH_DISCOUNT := "cash_discount"
const INSURANCE_FRAUD := "insurance_fraud"
const SEED_CAPITAL := "seed_capital"
const LUCKY_PENNY := "lucky_penny"
const LUCKY_DAY := "lucky_day"
const FREE_FLIP := "free_flip"
const BUYBACK := "buyback"
const REINSURANCE := "reinsurance"
const TRIAL_RUN := "trial_run"
const HAND_WAGE := "hand_wage"
const DEPOSIT := "deposit"

# Bonus, Stufe 2
const HIGH_VOLTAGE := "high_voltage"
const ANCHOR_CLAUSE := "anchor_clause"
const ODDS_BONUS := "odds_bonus"
const HAPPY_HOUR := "happy_hour"
const INTEREST := "interest"
const DOUBLE_LOADER := "double_loader"
const CALIBRATION := "calibration"
const GOLDEN_HANDSHAKE := "golden_handshake"
const WORK_HARDENING := "work_hardening"
const LUCKY_STREAK := "lucky_streak"
const SOUL_MARKET := "soul_market"
const MATH_WEEK := "math_week"
const BACK_ROOM_CONTACT := "back_room_contact"
const BIG_STORAGE := "big_storage"
const OVERTIME := "overtime"
const EXCHANGE_OFFICE := "exchange_office"

# Bonus, Stufe 3
const ALL_ON_RED := "all_on_red"
const BLANK_CHEQUE := "blank_cheque"
const SUPERCONDUCTOR := "superconductor"
const GOLD_VEIN := "gold_vein"
const LUCKY_CHILD := "lucky_child"
const REGULAR_CUSTOMER := "regular_customer"
const SPECIAL_DELIVERY := "special_delivery"
const FREE_HAND := "free_hand"
const CONNOISSEUR_EYE := "connoisseur_eye"
const LOADED_LUCK_DIE := "loaded_luck_die"
const MASTER_PRESS := "master_press"
const FULL_LOADOUT := "full_loadout"

# Malus, Stufe 1
const QUOTA_SURCHARGE := "quota_surcharge"
const BETTING_TAX := "betting_tax"
const DEDUCTION := "deduction"
const SERVICE_FEE := "service_fee"
const INFLATION := "inflation"
const EMPTY_SHELVES := "empty_shelves"
const SOULLESS := "soulless"
const FLIP_SURCHARGE := "flip_surcharge"
const MAINS_HUM := "mains_hum"
const SLOW_START := "slow_start"
const WORKSHOP_BAN := "workshop_ban"

# Malus, Stufe 2
const QUOTA_SURCHARGE_II := "quota_surcharge_ii"
const EMPTIES := "empties"
const HALF_PAYOUT := "half_payout"
const STAGE_CAP := "stage_cap"
const DISCHARGE := "discharge"
const HEAT_WARNING := "heat_warning"
const RIP_OFF := "rip_off"
const UNLUCKY_NUMBER := "unlucky_number"
const BAD_STREAK := "bad_streak"
const SHELF_WARMER := "shelf_warmer"
const FUSE_FAILURE := "fuse_failure"
const LOOSE_CONTACT := "loose_contact"
const PROJECTOR_FAILURE := "projector_failure"
const SHORT_TIME := "short_time"

# Malus, Stufe 3
const QUOTA_SHOCK := "quota_shock"
const USURY_CLAUSE := "usury_clause"
const BLACKOUT := "blackout"
const HEAT_BUILDUP := "heat_buildup"
const SEIZURE := "seizure"
const FORCED_AUCTION := "forced_auction"
const SHOP_CLOSED := "shop_closed"
const SCRAP_PRESS := "scrap_press"
const UNLUCKY_PACT := "unlucky_pact"

# Stresstest-Konditionen (reiner Malus)
const HIGH_EXPECTATIONS := "high_expectations"
const ALL_IN := "all_in"
const STANDARD_PROTOCOL := "standard_protocol"
const ALL_ROUNDER := "all_rounder"
const TILTED_FLOOR := "tilted_floor"
const BALANCED_SCALES := "balanced_scales"
const PENALTY_FEE := "penalty_fee"

## Farbe der Marke: das erste Tag bestimmt sie, damit gleiche Themen am Hub
## gleich aussehen. Tag-lose Klauseln erben die Stufenfarbe.
const TAG_COLORS := {
	TAG_PAYOUT: "#ffd319",
	TAG_QUOTA: "#ff5555",
	TAG_SIDEBET: "#ff79c6",
	TAG_OVERCHARGE: "#50fa7b",
	TAG_LEFTOVER: "#ffa62b",
	TAG_SHOP: "#bd93f9",
	TAG_ENERGY: "#7ef9ff",
	TAG_THROTTLE: "#ff8c42",
	TAG_MONEY: "#ffd319",
	TAG_SERIES: "#6effc7",
	TAG_LUCK: "#9dff6b",
	TAG_WORKSHOP: "#f1fa8c",
	TAG_CHARM: "#e6e6ff",
	TAG_MODULE: "#3ddc97",
}
const TIER_FALLBACK_COLORS := ["#9aa6ff", "#c9a2ff", "#ff9ecf", "#ffd319", "#ff5555"]

@export var id: String = ""
@export var display_name: String = ""
## Spielertext der Wirkung (eine Zeile auf der Karte).
@export var text: String = ""
@export var kind: Kind = Kind.BONUS
@export var scope: Scope = Scope.ROUND
@export var tier: Tier = Tier.ONE
@export var tags: Array[String] = []
@export var color: Color = Color.WHITE

static func _make(clause_id: String, name: String, effect: String, clause_kind: Kind,
		clause_scope: Scope, clause_tier: Tier, clause_tags: Array[String]) -> DealClause:
	var clause := DealClause.new()
	clause.id = clause_id
	clause.display_name = name
	clause.text = effect
	clause.kind = clause_kind
	clause.scope = clause_scope
	clause.tier = clause_tier
	clause.tags = clause_tags
	clause.color = _color_for(clause_tags, clause_tier)
	return clause

static func _color_for(clause_tags: Array[String], clause_tier: Tier) -> Color:
	if not clause_tags.is_empty() and TAG_COLORS.has(clause_tags[0]):
		return Color(TAG_COLORS[clause_tags[0]])
	return Color(TIER_FALLBACK_COLORS[int(clause_tier)])

static func _bonus(clause_id: String, name: String, effect: String, clause_scope: Scope,
		clause_tier: Tier, clause_tags: Array[String] = []) -> DealClause:
	return _make(clause_id, name, effect, Kind.BONUS, clause_scope, clause_tier, clause_tags)

static func _malus(clause_id: String, name: String, effect: String, clause_scope: Scope,
		clause_tier: Tier, clause_tags: Array[String] = []) -> DealClause:
	return _make(clause_id, name, effect, Kind.MALUS, clause_scope, clause_tier, clause_tags)

# --- Bonusklauseln ------------------------------------------------------------

static func savings_bonus() -> DealClause:
	return _bonus(SAVINGS_BONUS, "Sparprämie", "+$1 je übrigem Würfel.",
		Scope.ROUND, Tier.ONE, [TAG_LEFTOVER, TAG_MONEY])

static func free_charm() -> DealClause:
	return _bonus(FREE_CHARM, "Hausgutschein", "Erster Charm im Laden gratis.",
		Scope.ROUND, Tier.ONE, [TAG_MONEY])

static func advance_payment() -> DealClause:
	return _bonus(ADVANCE_PAYMENT, "Vorschuss", "+$12 sofort.",
		Scope.INSTANT, Tier.ONE, [TAG_MONEY])

static func spotlight() -> DealClause:
	return _bonus(SPOTLIGHT, "Rampenlicht", "Eine Kombination im Rampenlicht.",
		Scope.ROUND, Tier.ONE)

static func cash_discount() -> DealClause:
	return _bonus(CASH_DISCOUNT, "Skonto", "Ladenware −20 %.",
		Scope.ROUND, Tier.ONE, [TAG_SHOP])

static func insurance_fraud() -> DealClause:
	return _bonus(INSURANCE_FRAUD, "Versicherungsbetrug", "Fumble: +$15.",
		Scope.ROUND, Tier.ONE, [TAG_MONEY])

static func seed_capital() -> DealClause:
	return _bonus(SEED_CAPITAL, "Startkapital", "+1 ⚡ sofort.",
		Scope.INSTANT, Tier.ONE, [TAG_ENERGY])

static func high_voltage() -> DealClause:
	return _bonus(HIGH_VOLTAGE, "Hochspannung", "+3 Überladungs-Stufen.",
		Scope.ROUND, Tier.TWO, [TAG_OVERCHARGE])

static func anchor_clause() -> DealClause:
	return _bonus(ANCHOR_CLAUSE, "Ankerklausel", "Erster Fumble der Runde wird verziehen.",
		Scope.ROUND, Tier.TWO)

static func odds_bonus() -> DealClause:
	return _bonus(ODDS_BONUS, "Quotenbonus", "Nebenwetten zahlen doppelt.",
		Scope.ROUND, Tier.TWO, [TAG_SIDEBET])

static func happy_hour() -> DealClause:
	return _bonus(HAPPY_HOUR, "Happy Hour", "Alles Geld dieser Runde doppelt.",
		Scope.ROUND, Tier.TWO, [TAG_PAYOUT])

static func interest() -> DealClause:
	return _bonus(INTEREST, "Zinsen", "Rundenende: +$1 je $10 in Besitz.",
		Scope.ROUND, Tier.TWO, [TAG_MONEY])

static func double_loader() -> DealClause:
	return _bonus(DOUBLE_LOADER, "Doppellader", "Jede Überladungs-Stufe: +2 ⚡.",
		Scope.ROUND, Tier.TWO, [TAG_ENERGY])

static func calibration() -> DealClause:
	return _bonus(CALIBRATION, "Eichung", "Blinds dauerhaft −10 %.",
		Scope.INSTANT, Tier.TWO, [TAG_QUOTA])

static func lucky_penny() -> DealClause:
	return _bonus(LUCKY_PENNY, "Glückspfennig", "Glück +1.",
		Scope.INSTANT, Tier.ONE, [TAG_LUCK])

static func lucky_streak() -> DealClause:
	return _bonus(LUCKY_STREAK, "Glückssträhne", "Glück +2.",
		Scope.INSTANT, Tier.TWO, [TAG_LUCK])

static func lucky_child() -> DealClause:
	return _bonus(LUCKY_CHILD, "Glückskind", "Glück +3.",
		Scope.INSTANT, Tier.THREE, [TAG_LUCK])

static func golden_handshake() -> DealClause:
	return _bonus(GOLDEN_HANDSHAKE, "Goldener Handschlag",
		"Eine Hand schafft den Blind allein: ihr erster Würfel wird Gold.",
		Scope.ROUND, Tier.TWO)

## Ein Knochen auf Zeit: solange die Klausel steht, wächst jede ausgelöste Seite.
static func work_hardening() -> DealClause:
	return _bonus(WORK_HARDENING, "Kaltverfestigung", "Jede ausgelöste Seite dauerhaft +1.",
		Scope.ROUND, Tier.TWO)

static func all_on_red() -> DealClause:
	return _bonus(ALL_ON_RED, "Alles auf Rot", "Alles Geld dieser Runde ×3.",
		Scope.ROUND, Tier.THREE, [TAG_PAYOUT])

static func blank_cheque() -> DealClause:
	return _bonus(BLANK_CHEQUE, "Blankoscheck", "+$40 sofort.",
		Scope.INSTANT, Tier.THREE, [TAG_MONEY])

static func superconductor() -> DealClause:
	return _bonus(SUPERCONDUCTOR, "Supraleiter", "Überladungs-Stufen unbegrenzt.",
		Scope.ROUND, Tier.THREE, [TAG_OVERCHARGE])

static func gold_vein() -> DealClause:
	return _bonus(GOLD_VEIN, "Goldader", "+$10 je geräumter Überladungs-Stufe.",
		Scope.ROUND, Tier.THREE, [TAG_ENERGY, TAG_MONEY])

static func lucky_day() -> DealClause:
	return _bonus(LUCKY_DAY, "Glückstag", "Glück +3 diese Runde.",
		Scope.ROUND, Tier.ONE, [TAG_LUCK])

static func connoisseur_eye() -> DealClause:
	return _bonus(CONNOISSEUR_EYE, "Kennerblick", "Laden führt sicher einen legendären Charm.",
		Scope.ROUND, Tier.THREE, [TAG_SHOP])

static func soul_market() -> DealClause:
	return _bonus(SOUL_MARKET, "Seelenmarkt", "Laden-Würfel tragen immer eine Seele.",
		Scope.ROUND, Tier.TWO, [TAG_SHOP])

static func free_flip() -> DealClause:
	return _bonus(FREE_FLIP, "Freies Blättern", "Blättern im Laden 3× gratis.",
		Scope.ROUND, Tier.ONE, [TAG_SHOP])

static func buyback() -> DealClause:
	return _bonus(BUYBACK, "Rückkaufrecht", "Charms verkaufen zum vollen Preis.",
		Scope.ROUND, Tier.ONE, [TAG_MONEY])

static func math_week() -> DealClause:
	return _bonus(MATH_WEEK, "Rechenwoche", "Glück +6 diese Runde.",
		Scope.ROUND, Tier.TWO, [TAG_LUCK])

## Die einzige BLOCK-Klausel: sie gilt bis zur Abrechnung nach der Boss-Runde.
static func regular_customer() -> DealClause:
	return _bonus(REGULAR_CUSTOMER, "Stammkunde", "Ladenpreise −15 % bis zur Boss-Runde.",
		Scope.BLOCK, Tier.THREE, [TAG_SHOP])

static func special_delivery() -> DealClause:
	return _bonus(SPECIAL_DELIVERY, "Sonderlieferung", "Glück +10 diese Runde.",
		Scope.ROUND, Tier.THREE, [TAG_LUCK])

static func back_room_contact() -> DealClause:
	return _bonus(BACK_ROOM_CONTACT, "Hinterzimmer-Kontakt",
		"Schwarzmarkt: −1 ⚡ je Ware.", Scope.ROUND, Tier.TWO, [TAG_SHOP])

static func reinsurance() -> DealClause:
	return _bonus(REINSURANCE, "Rückversicherung", "Verlorene Nebenwette: Einsatz zurück.",
		Scope.ROUND, Tier.ONE, [TAG_SIDEBET])

static func big_storage() -> DealClause:
	return _bonus(BIG_STORAGE, "Großer Speicher", "Eine Powerbank: Börse +5 ⚡ Platz.",
		Scope.INSTANT, Tier.TWO, [TAG_ENERGY])

static func free_hand() -> DealClause:
	return _bonus(FREE_HAND, "Freie Hand", "Jedes Paket dieser Runde: +1 Wahl.",
		Scope.ROUND, Tier.THREE, [TAG_SHOP])

static func trial_run() -> DealClause:
	return _bonus(TRIAL_RUN, "Probelauf", "Prägen: +1 Mal.",
		Scope.ROUND, Tier.ONE, [TAG_WORKSHOP])

static func hand_wage() -> DealClause:
	return _bonus(HAND_WAGE, "Lohnfortzahlung", "Jede Hand: +$2.",
		Scope.ROUND, Tier.ONE, [TAG_MONEY])

static func deposit() -> DealClause:
	return _bonus(DEPOSIT, "Pfandflasche", "+1 ⚡ je geöffnetem Paket.",
		Scope.ROUND, Tier.ONE, [TAG_ENERGY])

static func overtime() -> DealClause:
	return _bonus(OVERTIME, "Überstunden", "Kombination mit 3 Modulen: +1 Auslösung.",
		Scope.ROUND, Tier.TWO, [TAG_MODULE])

static func exchange_office() -> DealClause:
	return _bonus(EXCHANGE_OFFICE, "Wechselstube", "Rundenende: +$3 je ⚡.",
		Scope.ROUND, Tier.TWO, [TAG_MONEY, TAG_ENERGY])

static func loaded_luck_die() -> DealClause:
	return _bonus(LOADED_LUCK_DIE, "Gezinkter Glückswürfel",
		"Erstes Paket: der Glückswürfel zeigt seine beste Seite.", Scope.ROUND, Tier.THREE, [TAG_LUCK])

static func master_press() -> DealClause:
	return _bonus(MASTER_PRESS, "Meisterprägung", "Prägen unbegrenzt.",
		Scope.ROUND, Tier.THREE, [TAG_WORKSHOP])

static func full_loadout() -> DealClause:
	return _bonus(FULL_LOADOUT, "Vollbestückung", "Alle Module wirken doppelt.",
		Scope.ROUND, Tier.THREE, [TAG_MODULE])

# --- Malusklauseln ------------------------------------------------------------

static func empty_shelves() -> DealClause:
	return _malus(EMPTY_SHELVES, "Leere Regale", "Laden: zwei Paket-Plätze bleiben leer.",
		Scope.ROUND, Tier.ONE, [TAG_SHOP])

static func shelf_warmer() -> DealClause:
	return _malus(SHELF_WARMER, "Ladenhüter", "Laden führt nur gewöhnliche Charms.",
		Scope.ROUND, Tier.TWO, [TAG_SHOP])

static func soulless() -> DealClause:
	return _malus(SOULLESS, "Seelenlos", "Laden-Würfel ohne Seele.",
		Scope.ROUND, Tier.ONE, [TAG_SHOP])

static func flip_surcharge() -> DealClause:
	return _malus(FLIP_SURCHARGE, "Blätter-Aufschlag", "Blättern kostet doppelt.",
		Scope.ROUND, Tier.ONE, [TAG_SHOP])

static func quota_surcharge() -> DealClause:
	return _malus(QUOTA_SURCHARGE, "Blind-Aufschlag", "Blinds dauerhaft +10 %.",
		Scope.INSTANT, Tier.ONE, [TAG_QUOTA])

static func betting_tax() -> DealClause:
	return _malus(BETTING_TAX, "Wettsteuer", "Alle Wett-Einsätze erneut zahlen.",
		Scope.INSTANT, Tier.ONE, [TAG_SIDEBET])

static func empties() -> DealClause:
	return _malus(EMPTIES, "Leergut", "Übrige Würfel zahlen nichts.",
		Scope.ROUND, Tier.TWO, [TAG_LEFTOVER])

static func deduction() -> DealClause:
	return _malus(DEDUCTION, "Abschlag", "Rundenauszahlung −25 %.",
		Scope.ROUND, Tier.ONE, [TAG_PAYOUT])

static func service_fee() -> DealClause:
	return _malus(SERVICE_FEE, "Servicegebühr", "Jede Hand: −$3.",
		Scope.ROUND, Tier.ONE, [TAG_MONEY])

static func inflation() -> DealClause:
	return _malus(INFLATION, "Inflation", "Ladenpreise +25 %.",
		Scope.ROUND, Tier.ONE, [TAG_SHOP])

static func quota_surcharge_ii() -> DealClause:
	return _malus(QUOTA_SURCHARGE_II, "Blind-Aufschlag II", "Blinds dauerhaft +20 %.",
		Scope.INSTANT, Tier.TWO, [TAG_QUOTA])

static func unlucky_number() -> DealClause:
	return _malus(UNLUCKY_NUMBER, "Unglückszahl", "Glück −2.",
		Scope.INSTANT, Tier.TWO, [TAG_LUCK])

static func bad_streak() -> DealClause:
	return _malus(BAD_STREAK, "Pechsträhne", "Fumble: Blinds dauerhaft +5 %.",
		Scope.ROUND, Tier.TWO, [TAG_QUOTA])

static func half_payout() -> DealClause:
	return _malus(HALF_PAYOUT, "Halbe Auszahlung", "Rundenauszahlung −50 %.",
		Scope.ROUND, Tier.TWO, [TAG_PAYOUT])

static func stage_cap() -> DealClause:
	return _malus(STAGE_CAP, "Stufendeckel", "Überladung endet bei Stufe 2.",
		Scope.ROUND, Tier.TWO, [TAG_OVERCHARGE])

static func mains_hum() -> DealClause:
	return _malus(MAINS_HUM, "Netzbrummen", "Jede Überladungs-Stufe benötigt ×3 statt ×2.",
		Scope.ROUND, Tier.ONE, [TAG_OVERCHARGE])

static func discharge() -> DealClause:
	return _malus(DISCHARGE, "Entladung", "−2 ⚡ sofort.",
		Scope.INSTANT, Tier.TWO, [TAG_ENERGY])

static func heat_warning() -> DealClause:
	return _malus(HEAT_WARNING, "Hitzewarnung", "Kombination mit den meisten Modulen wertet nicht.",
		Scope.ROUND, Tier.TWO, [TAG_THROTTLE])

static func rip_off() -> DealClause:
	return _malus(RIP_OFF, "Abzocke", "Jeder gewertete Würfel: −$1.",
		Scope.ROUND, Tier.TWO, [TAG_SIDEBET])

static func quota_shock() -> DealClause:
	return _malus(QUOTA_SHOCK, "Blind-Schock", "Blinds dauerhaft +35 %.",
		Scope.INSTANT, Tier.THREE, [TAG_QUOTA])

static func usury_clause() -> DealClause:
	return _malus(USURY_CLAUSE, "Wucherklausel", "Blinds dauerhaft +50 %.",
		Scope.INSTANT, Tier.THREE, [TAG_QUOTA])

static func blackout() -> DealClause:
	return _malus(BLACKOUT, "Blackout", "Diese Runde kein Geld.",
		Scope.ROUND, Tier.THREE, [TAG_PAYOUT, TAG_MONEY])

static func fuse_failure() -> DealClause:
	return _malus(FUSE_FAILURE, "Sicherungsfall", "Jede Überladungs-Stufe benötigt ×4 statt ×2.",
		Scope.ROUND, Tier.TWO, [TAG_OVERCHARGE, TAG_ENERGY])

static func heat_buildup() -> DealClause:
	return _malus(HEAT_BUILDUP, "Hitzestau", "Fumble: ein zufälliges Modul wird zerstört.",
		Scope.ROUND, Tier.THREE, [TAG_THROTTLE])

static func slow_start() -> DealClause:
	return _malus(SLOW_START, "Anlaufzeit", "Erste Hand: halbe Punkte.",
		Scope.ROUND, Tier.ONE, [TAG_THROTTLE])

static func workshop_ban() -> DealClause:
	return _malus(WORKSHOP_BAN, "Werkstattsperre", "Prägen gesperrt.",
		Scope.ROUND, Tier.ONE, [TAG_WORKSHOP])

static func loose_contact() -> DealClause:
	return _malus(LOOSE_CONTACT, "Wackelkontakt", "Glückswürfel zeigt höchstens 2 Augen.",
		Scope.ROUND, Tier.TWO, [TAG_LUCK])

static func projector_failure() -> DealClause:
	return _malus(PROJECTOR_FAILURE, "Projektor-Ausfall", "Ein zufälliger Charm ist aus.",
		Scope.ROUND, Tier.TWO, [TAG_CHARM])

static func short_time() -> DealClause:
	return _malus(SHORT_TIME, "Kurzarbeit", "6 Würfel weniger im Pool.",
		Scope.ROUND, Tier.TWO, [TAG_THROTTLE])

static func seizure() -> DealClause:
	return _malus(SEIZURE, "Pfändung", "Die Hälfte deines Geldes ist weg.",
		Scope.INSTANT, Tier.THREE, [TAG_MONEY])

static func forced_auction() -> DealClause:
	return _malus(FORCED_AUCTION, "Zwangsversteigerung", "Dein teuerster Charm wird verkauft.",
		Scope.INSTANT, Tier.THREE, [TAG_CHARM])

static func shop_closed() -> DealClause:
	return _malus(SHOP_CLOSED, "Ladenschluss", "Kein Laden nach dieser Runde.",
		Scope.ROUND, Tier.THREE, [TAG_SHOP])

static func scrap_press() -> DealClause:
	return _malus(SCRAP_PRESS, "Schrottpresse", "Ein zufälliges Modul wird zerstört.",
		Scope.INSTANT, Tier.THREE, [TAG_MODULE])

static func unlucky_pact() -> DealClause:
	return _malus(UNLUCKY_PACT, "Pechvogel-Pakt", "Glück −4.",
		Scope.INSTANT, Tier.THREE, [TAG_LUCK])

# --- Stresstest-Konditionen ---------------------------------------------------

static func high_expectations() -> DealClause:
	return _malus(HIGH_EXPECTATIONS, "Hohe Erwartungen", "Blind ×6.",
		Scope.ROUND, Tier.BOSS, [TAG_QUOTA])

static func all_in() -> DealClause:
	return _malus(ALL_IN, "All in", "Nur eine Hand.",
		Scope.ROUND, Tier.BOSS)

static func standard_protocol() -> DealClause:
	return _malus(STANDARD_PROTOCOL, "Standardprotokoll", "Nur eine Kombinationsart zählt.",
		Scope.ROUND, Tier.BOSS, [TAG_THROTTLE])

static func all_rounder() -> DealClause:
	return _malus(ALL_ROUNDER, "Allrounder", "Jede Kombination zählt nur einmal.",
		Scope.ROUND, Tier.BOSS, [TAG_THROTTLE])

static func tilted_floor() -> DealClause:
	return _malus(TILTED_FLOOR, "Schieflage", "Nur ungerade Augen zählen.",
		Scope.ROUND, Tier.BOSS, [TAG_THROTTLE])

static func balanced_scales() -> DealClause:
	return _malus(BALANCED_SCALES, "Gleichgewicht", "Nur gerade Augen zählen.",
		Scope.ROUND, Tier.BOSS, [TAG_THROTTLE])

static func penalty_fee() -> DealClause:
	return _malus(PENALTY_FEE, "Strafgebühr", "Fumble: ein zufälliger Charm wird zerstört.",
		Scope.ROUND, Tier.BOSS, [TAG_MONEY])

static func all() -> Array[DealClause]:
	return [
		savings_bonus(), free_charm(), advance_payment(), spotlight(),
		cash_discount(), insurance_fraud(), seed_capital(),
		high_voltage(), anchor_clause(), odds_bonus(),
		happy_hour(), interest(), double_loader(), calibration(),
		golden_handshake(), work_hardening(),
		all_on_red(), blank_cheque(), superconductor(), gold_vein(),
		quota_surcharge(), betting_tax(), empties(), deduction(),
		service_fee(), inflation(),
		quota_surcharge_ii(), half_payout(), stage_cap(), mains_hum(),
		discharge(), heat_warning(), rip_off(),
		quota_shock(), usury_clause(), blackout(), fuse_failure(), heat_buildup(),
		high_expectations(), all_in(), standard_protocol(), all_rounder(),
		tilted_floor(), balanced_scales(), penalty_fee(),
		lucky_penny(), lucky_streak(), lucky_child(), unlucky_number(), bad_streak(),
		lucky_day(), connoisseur_eye(), soul_market(), free_flip(),
		buyback(), math_week(), regular_customer(), special_delivery(),
		back_room_contact(), reinsurance(),
		big_storage(),
		empty_shelves(), shelf_warmer(), soulless(), flip_surcharge(),
		free_hand(),
		trial_run(), hand_wage(), deposit(), overtime(), exchange_office(),
		loaded_luck_die(), master_press(), full_loadout(),
		slow_start(), workshop_ban(), loose_contact(), projector_failure(), short_time(),
		seizure(), forced_auction(), shop_closed(), scrap_press(), unlucky_pact(),
	]

## Alle Klausel-ids eines Topfes. TREAT hat keinen eigenen Topf mehr - das
## Werbegeschenk zieht aus dem normalen Bonustopf seiner Stufe.
static func ids_for(clause_tier: Tier, clause_kind: Kind) -> Array[String]:
	var ids: Array[String] = []
	for clause in all():
		if clause.kind == clause_kind and clause.tier == clause_tier:
			ids.append(clause.id)
	return ids

## Nachschlage-Tabelle id -> Klausel, EINMAL gebaut. all() legt 48 frische
## Resources an, und find() lief je Frame dutzendfach (die Überladungs-Stufen
## fragen über _clause_active durch) - bei hohen Punktzahlen kostete allein das
## Millisekunden pro Frame. Alle Aufrufer LESEN nur, ein geteiltes Exemplar
## genügt also.
static var _by_id: Dictionary = {}

static func find(clause_id: String) -> DealClause:
	if _by_id.is_empty():
		for clause in all():
			_by_id[clause.id] = clause
	return _by_id.get(clause_id, null)

## Wirkungstext einer Klausel, gelesen mit dem Bonus-Faktor des Winkeladvokats.
## Die verdoppelte Fassung steht ausgeschrieben da, statt aus der Grundfassung
## gerechnet zu werden: "doppelt" wird "vierfach", nicht "doppelt ×2". Klauseln
## ohne Zahl (Rampenlicht & Co.) und jeder Malus behalten ihren Text.
static func text_for(clause_id: String, bonus_factor: int = 1) -> String:
	var clause := find(clause_id)
	if clause == null:
		return ""
	if bonus_factor <= 1:
		return clause.text
	match clause_id:
		ADVANCE_PAYMENT:
			return "+$24 sofort."
		FREE_HAND:
			return "Jedes Paket dieser Runde: +2 Wahlen."
		BLANK_CHEQUE:
			return "+$80 sofort."
		SEED_CAPITAL:
			return "+2 ⚡ sofort."
		SAVINGS_BONUS:
			return "+$2 je übrigem Würfel."
		INSURANCE_FRAUD:
			return "Fumble: +$30."
		HIGH_VOLTAGE:
			return "+6 Überladungs-Stufen."
		ODDS_BONUS:
			return "Nebenwetten zahlen vierfach."
		HAPPY_HOUR:
			return "Alles Geld dieser Runde vierfach."
		ALL_ON_RED:
			return "Alles Geld dieser Runde ×6."
		INTEREST:
			return "Rundenende: +$2 je $10 in Besitz."
		DOUBLE_LOADER:
			return "Jede Überladungs-Stufe: +4 ⚡."
		CALIBRATION:
			return "Blinds dauerhaft −19 %."
		LUCKY_PENNY:
			return "Glück +2."
		LUCKY_STREAK:
			return "Glück +4."
		LUCKY_CHILD:
			return "Glück +6."
		CASH_DISCOUNT:
			return "Ladenware −36 %."
		GOLD_VEIN:
			return "+$20 je geräumter Überladungs-Stufe."
		WORK_HARDENING:
			return "Jede ausgelöste Seite dauerhaft +2."
		LUCKY_DAY:
			return "Glück +6 diese Runde."
		CONNOISSEUR_EYE:
			return "Laden führt sicher zwei legendäre Charms."
		MATH_WEEK:
			return "Glück +12 diese Runde."
		SPECIAL_DELIVERY:
			return "Glück +20 diese Runde."
		FREE_FLIP:
			return "Blättern im Laden 6× gratis."
		REGULAR_CUSTOMER:
			return "Ladenpreise −28 % bis zur Boss-Runde."
		BACK_ROOM_CONTACT:
			return "Schwarzmarkt: −2 ⚡ je Ware."
		BIG_STORAGE:
			return "Zwei Powerbanks: Börse +10 ⚡ Platz."
		TRIAL_RUN:
			return "Prägen: +2 Mal."
		HAND_WAGE:
			return "Jede Hand: +$4."
		DEPOSIT:
			return "+2 ⚡ je geöffnetem Paket."
		OVERTIME:
			return "Kombination mit 3 Modulen: +2 Auslösungen."
		EXCHANGE_OFFICE:
			return "Rundenende: +$6 je ⚡."
		LOADED_LUCK_DIE:
			return "Erste zwei Pakete: der Glückswürfel zeigt seine beste Seite."
		FULL_LOADOUT:
			return "Alle Module wirken dreifach."
	return clause.text

static func tags_of(clause_id: String) -> Array[String]:
	var clause := find(clause_id)
	if clause == null:
		return []
	return clause.tags

## Laufzeit-Etikett der Klausel ("sofort" / "diese Runde" / "bis zur Abrechnung").
static func scope_label(clause_scope: Scope) -> String:
	match clause_scope:
		Scope.INSTANT:
			return "sofort"
		Scope.ROUND:
			return "diese Runde"
	return "bis zur Abrechnung"

## Vertragsname der Stufe - die Spielersprache dieses Systems.
static func tier_label(clause_tier: Tier) -> String:
	match clause_tier:
		Tier.ONE:
			return "Standardvertrag"
		Tier.TWO:
			return "Risikovertrag"
		Tier.THREE:
			return "Knebelvertrag"
		Tier.TREAT:
			return "Werbegeschenk"
	return "Boss-Kondition"

## Ob die id überhaupt eine Klausel ist (Marken-Aufbau, Tests).
static func is_valid_id(clause_id: String) -> bool:
	return find(clause_id) != null
