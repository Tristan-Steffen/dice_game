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
## bis zur Abrechnung nach dem Stresstest. KEINE Klausel ist mehr BLOCK - kein
## Deal überlebt seine Runde; die Stufe bleibt als Schiedsrichter (_scope_reaches).
enum Scope { INSTANT, ROUND, BLOCK }

enum Kind { BONUS, MALUS }

## Vertragsstufe. TREAT = Werbegeschenk (reiner Bonus), BOSS = Stresstest-
## Kondition (reiner Malus).
enum Tier { ONE, TWO, THREE, TREAT, BOSS }

## Themen-Etiketten. Bonus und Malus einer Karte dürfen kein Tag teilen - das
## verhindert Nullsummen-Paare ("Auszahlung ×2" gegen "Auszahlung ×0,5").
const TAG_PAYOUT := "auszahlung"
const TAG_BENCHMARK := "benchmark"
const TAG_SIDEBET := "nebenwette"
const TAG_OVERCHARGE := "überladung"
const TAG_LEFTOVER := "übrig"
const TAG_SHOP := "shop"
const TAG_SLOT := "automat"
const TAG_CHARGE := "ladung"
const TAG_THROTTLE := "drossel"
const TAG_MONEY := "geld"

# --- Klausel-ids (Single Source of Truth) --------------------------------------

# Bonus, Stufe 1
const SAVINGS_BONUS := "savings_bonus"
const OVERCLOCK_DISCOUNT := "overclock_discount"
const ADVANCE_PAYMENT := "advance_payment"
const SPOTLIGHT := "spotlight"
const CASH_DISCOUNT := "cash_discount"
const INSURANCE_FRAUD := "insurance_fraud"
const SEED_CAPITAL := "seed_capital"

# Bonus, Stufe 2
const MAINTENANCE_ENGRAVING := "maintenance_engraving"
const HIGH_VOLTAGE := "high_voltage"
const ANCHOR_CLAUSE := "anchor_clause"
const ODDS_BONUS := "odds_bonus"
const HAPPY_HOUR := "happy_hour"
const INTEREST := "interest"
const FREE_SPINS := "free_spins"
const DOUBLE_LOADER := "double_loader"
const CALIBRATION := "calibration"
const GOLDEN_HANDSHAKE := "golden_handshake"

# Bonus, Stufe 3
const ALL_ON_RED := "all_on_red"
const BLANK_CHEQUE := "blank_cheque"
const SUPERCONDUCTOR := "superconductor"
const GOLD_VEIN := "gold_vein"
const CARBON_COPY := "carbon_copy"

# Werbegeschenke
const TOURNAMENT_NIGHT := "tournament_night"
const POWER_SPIKE := "power_spike"
const SEED_CAPITAL_II := "seed_capital_ii"

# Malus, Stufe 1
const BENCHMARK_SURCHARGE := "benchmark_surcharge"
const BETTING_TAX := "betting_tax"
const EMPTIES := "empties"
const DEDUCTION := "deduction"
const SERVICE_FEE := "service_fee"
const INFLATION := "inflation"
const POWER_CUT := "power_cut"

# Malus, Stufe 2
const BENCHMARK_SURCHARGE_II := "benchmark_surcharge_ii"
const HALF_PAYOUT := "half_payout"
const STAGE_CAP := "stage_cap"
const MAINS_HUM := "mains_hum"
const DISCHARGE := "discharge"
const HEAT_WARNING := "heat_warning"
const RIP_OFF := "rip_off"

# Malus, Stufe 3
const BENCHMARK_SHOCK := "benchmark_shock"
const USURY_CLAUSE := "usury_clause"
const BLACKOUT := "blackout"
const FUSE_FAILURE := "fuse_failure"
const HEAT_BUILDUP := "heat_buildup"

# Stresstest-Konditionen (reiner Malus)
const HIGH_EXPECTATIONS := "high_expectations"
const ALL_IN := "all_in"
const STANDARD_PROTOCOL := "standard_protocol"
const ALL_ROUNDER := "all_rounder"
const TILTED_FLOOR := "tilted_floor"
const BALANCED_SCALES := "balanced_scales"

## Farbe der Marke: das erste Tag bestimmt sie, damit gleiche Themen am Hub
## gleich aussehen. Tag-lose Klauseln erben die Stufenfarbe.
const TAG_COLORS := {
	TAG_PAYOUT: "#ffd319",
	TAG_BENCHMARK: "#ff5555",
	TAG_SIDEBET: "#ff79c6",
	TAG_OVERCHARGE: "#50fa7b",
	TAG_LEFTOVER: "#ffa62b",
	TAG_SHOP: "#bd93f9",
	TAG_SLOT: "#8be9fd",
	TAG_CHARGE: "#7ef9ff",
	TAG_THROTTLE: "#ff8c42",
	TAG_MONEY: "#ffd319",
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
## Doppelrolle: liegt zusätzlich im Werbegeschenk-Topf (Happy Hour).
@export var also_treat: bool = false
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
	return _bonus(SAVINGS_BONUS, "Sparprämie", "+1$ je übrigem Würfel",
		Scope.ROUND, Tier.ONE, [TAG_LEFTOVER, TAG_MONEY])

static func overclock_discount() -> DealClause:
	return _bonus(OVERCLOCK_DISCOUNT, "Übertaktungsrabatt", "Der erste Charm im Laden ist gratis",
		Scope.ROUND, Tier.ONE, [TAG_MONEY])

static func advance_payment() -> DealClause:
	return _bonus(ADVANCE_PAYMENT, "Vorschuss", "+12$ auf die Hand",
		Scope.INSTANT, Tier.ONE, [TAG_MONEY])

static func spotlight() -> DealClause:
	return _bonus(SPOTLIGHT, "Rampenlicht", "Eine Kombination steht im Rampenlicht",
		Scope.ROUND, Tier.ONE)

static func cash_discount() -> DealClause:
	return _bonus(CASH_DISCOUNT, "Skonto", "Ladenware 20% günstiger",
		Scope.ROUND, Tier.ONE, [TAG_SHOP])

static func insurance_fraud() -> DealClause:
	return _bonus(INSURANCE_FRAUD, "Versicherungsbetrug", "Jeder Farkle zahlt 15$ Trost",
		Scope.ROUND, Tier.ONE, [TAG_MONEY])

static func seed_capital() -> DealClause:
	return _bonus(SEED_CAPITAL, "Startkapital", "+1 Energie sofort",
		Scope.INSTANT, Tier.ONE, [TAG_CHARGE])

static func maintenance_engraving() -> DealClause:
	return _bonus(MAINTENANCE_ENGRAVING, "Wartungs-Gravur", "Je genommene Hand eine Zahl-Gravur",
		Scope.ROUND, Tier.TWO)

static func high_voltage() -> DealClause:
	return _bonus(HIGH_VOLTAGE, "Hochspannung", "+3 Überladungs-Stufen",
		Scope.ROUND, Tier.TWO, [TAG_OVERCHARGE])

static func anchor_clause() -> DealClause:
	return _bonus(ANCHOR_CLAUSE, "Ankerklausel", "Der erste Farkle dieser Runde zählt nicht",
		Scope.ROUND, Tier.TWO)

static func odds_bonus() -> DealClause:
	return _bonus(ODDS_BONUS, "Quotenbonus", "Nebenwetten zahlen doppelt",
		Scope.ROUND, Tier.TWO, [TAG_SIDEBET])

## Doppelrolle: Stufe-2-Bonus UND Werbegeschenk.
static func happy_hour() -> DealClause:
	var c := _bonus(HAPPY_HOUR, "Happy Hour", "Alles Geld dieser Runde doppelt",
		Scope.ROUND, Tier.TWO, [TAG_PAYOUT])
	c.also_treat = true
	return c

static func interest() -> DealClause:
	return _bonus(INTEREST, "Zinsen", "Rundenende: +1$ je vollen 10$ Guthaben",
		Scope.ROUND, Tier.TWO, [TAG_MONEY])

static func free_spins() -> DealClause:
	return _bonus(FREE_SPINS, "Freispiele", "Jeder Automat dreht einmal gratis",
		Scope.ROUND, Tier.TWO, [TAG_SLOT])

static func double_loader() -> DealClause:
	return _bonus(DOUBLE_LOADER, "Doppellader", "Überladungs-Stufen prägen 2 Energie",
		Scope.ROUND, Tier.TWO, [TAG_CHARGE])

static func calibration() -> DealClause:
	return _bonus(CALIBRATION, "Eichung", "Benchmark −50%",
		Scope.ROUND, Tier.TWO, [TAG_BENCHMARK])

static func golden_handshake() -> DealClause:
	return _bonus(GOLDEN_HANDSHAKE, "Goldener Handschlag",
		"Erfüllt EINE Hand den Benchmark allein: ihr erster Würfel wird pures Gold",
		Scope.ROUND, Tier.TWO)

static func all_on_red() -> DealClause:
	return _bonus(ALL_ON_RED, "Alles auf Rot", "Alles Geld dieser Runde dreifach",
		Scope.ROUND, Tier.THREE, [TAG_PAYOUT])

static func blank_cheque() -> DealClause:
	return _bonus(BLANK_CHEQUE, "Blankoscheck", "+40$ auf die Hand",
		Scope.INSTANT, Tier.THREE, [TAG_MONEY])

static func superconductor() -> DealClause:
	return _bonus(SUPERCONDUCTOR, "Supraleiter", "Unbegrenzte Überladungs-Stufen",
		Scope.ROUND, Tier.THREE, [TAG_OVERCHARGE])

static func gold_vein() -> DealClause:
	return _bonus(GOLD_VEIN, "Goldader", "+10$ je geräumter Überladungs-Stufe",
		Scope.ROUND, Tier.THREE, [TAG_CHARGE, TAG_MONEY])

static func carbon_copy() -> DealClause:
	return _bonus(CARBON_COPY, "Durchschlagpapier",
		"Die erste gewertete Hand kopiert jedes oben liegende Material als Gravur",
		Scope.ROUND, Tier.THREE)

# --- Werbegeschenke -----------------------------------------------------------

static func tournament_night() -> DealClause:
	return _bonus(TOURNAMENT_NIGHT, "Turniernacht", "Nebenwetten zahlen doppelt",
		Scope.ROUND, Tier.TREAT, [TAG_SIDEBET])

static func power_spike() -> DealClause:
	return _bonus(POWER_SPIKE, "Spannungsspitze", "Eine Kombination steht im Rampenlicht",
		Scope.ROUND, Tier.TREAT)

static func seed_capital_ii() -> DealClause:
	return _bonus(SEED_CAPITAL_II, "Startkapital", "+2 Energie sofort",
		Scope.INSTANT, Tier.TREAT, [TAG_CHARGE])

# --- Malusklauseln ------------------------------------------------------------

static func benchmark_surcharge() -> DealClause:
	return _malus(BENCHMARK_SURCHARGE, "Benchmark-Aufschlag", "Benchmark +50%",
		Scope.ROUND, Tier.ONE, [TAG_BENCHMARK])

static func betting_tax() -> DealClause:
	return _malus(BETTING_TAX, "Wettsteuer", "Wett-Einsätze kosten doppelt",
		Scope.ROUND, Tier.ONE, [TAG_SIDEBET])

static func empties() -> DealClause:
	return _malus(EMPTIES, "Leergut", "Übrige Würfel zahlen nichts",
		Scope.ROUND, Tier.ONE, [TAG_LEFTOVER])

static func deduction() -> DealClause:
	return _malus(DEDUCTION, "Abschlag", "Rundenauszahlung −25%",
		Scope.ROUND, Tier.ONE, [TAG_PAYOUT])

static func service_fee() -> DealClause:
	return _malus(SERVICE_FEE, "Servicegebühr", "Jede gespielte Hand: −3$",
		Scope.ROUND, Tier.ONE, [TAG_MONEY])

static func inflation() -> DealClause:
	return _malus(INFLATION, "Inflation", "Ladenpreise +25%",
		Scope.ROUND, Tier.ONE, [TAG_SHOP])

static func power_cut() -> DealClause:
	return _malus(POWER_CUT, "Stromsperre", "Der Automat bleibt aus",
		Scope.ROUND, Tier.ONE, [TAG_SLOT])

static func benchmark_surcharge_ii() -> DealClause:
	return _malus(BENCHMARK_SURCHARGE_II, "Benchmark-Aufschlag II", "Benchmark +100%",
		Scope.ROUND, Tier.TWO, [TAG_BENCHMARK])

static func half_payout() -> DealClause:
	return _malus(HALF_PAYOUT, "Halbe Auszahlung", "Rundenauszahlung ×0,5",
		Scope.ROUND, Tier.TWO, [TAG_PAYOUT])

static func stage_cap() -> DealClause:
	return _malus(STAGE_CAP, "Stufendeckel", "Überladung endet bei Stufe 2",
		Scope.ROUND, Tier.TWO, [TAG_OVERCHARGE])

static func mains_hum() -> DealClause:
	return _malus(MAINS_HUM, "Netzbrummen", "Überladungs-Stufen brauchen +25% Punkte",
		Scope.ROUND, Tier.TWO, [TAG_OVERCHARGE])

static func discharge() -> DealClause:
	return _malus(DISCHARGE, "Entladung", "−2 Energie sofort",
		Scope.INSTANT, Tier.TWO, [TAG_CHARGE])

static func heat_warning() -> DealClause:
	return _malus(HEAT_WARNING, "Hitzewarnung", "Die höchstgestufte Kombination wertet nicht",
		Scope.ROUND, Tier.TWO, [TAG_THROTTLE])

static func rip_off() -> DealClause:
	return _malus(RIP_OFF, "Abzocke", "Jeder gewertete Würfel kostet 1$",
		Scope.ROUND, Tier.TWO, [TAG_SIDEBET])

static func benchmark_shock() -> DealClause:
	return _malus(BENCHMARK_SHOCK, "Benchmark-Schock", "Benchmark +250%",
		Scope.ROUND, Tier.THREE, [TAG_BENCHMARK])

static func usury_clause() -> DealClause:
	return _malus(USURY_CLAUSE, "Wucherklausel", "Benchmark +400%",
		Scope.ROUND, Tier.THREE, [TAG_BENCHMARK])

static func blackout() -> DealClause:
	return _malus(BLACKOUT, "Blackout", "Übrige Würfel zahlen nichts",
		Scope.ROUND, Tier.THREE, [TAG_PAYOUT])

static func fuse_failure() -> DealClause:
	return _malus(FUSE_FAILURE, "Sicherungsfall", "Überladungen skalieren ×4 statt ×2",
		Scope.ROUND, Tier.THREE, [TAG_OVERCHARGE, TAG_CHARGE])

static func heat_buildup() -> DealClause:
	return _malus(HEAT_BUILDUP, "Hitzestau", "Jede gespielte Hand senkt ihre Stufe um 1",
		Scope.ROUND, Tier.THREE, [TAG_THROTTLE])

# --- Stresstest-Konditionen ---------------------------------------------------

static func high_expectations() -> DealClause:
	return _malus(HIGH_EXPECTATIONS, "Hohe Erwartungen", "Benchmark +500%",
		Scope.ROUND, Tier.BOSS, [TAG_BENCHMARK])

static func all_in() -> DealClause:
	return _malus(ALL_IN, "All in", "Nur EINE Hand diese Runde",
		Scope.ROUND, Tier.BOSS)

static func standard_protocol() -> DealClause:
	return _malus(STANDARD_PROTOCOL, "Standardprotokoll", "Nur EINE Kombinationsart zählt",
		Scope.ROUND, Tier.BOSS, [TAG_THROTTLE])

static func all_rounder() -> DealClause:
	return _malus(ALL_ROUNDER, "Allrounder", "Jede Kombination zählt nur einmal",
		Scope.ROUND, Tier.BOSS, [TAG_THROTTLE])

static func tilted_floor() -> DealClause:
	return _malus(TILTED_FLOOR, "Schieflage", "Nur ungerade Augen zählen",
		Scope.ROUND, Tier.BOSS, [TAG_THROTTLE])

static func balanced_scales() -> DealClause:
	return _malus(BALANCED_SCALES, "Gleichgewicht", "Nur gerade Augen zählen",
		Scope.ROUND, Tier.BOSS, [TAG_THROTTLE])

static func all() -> Array[DealClause]:
	return [
		savings_bonus(), overclock_discount(), advance_payment(), spotlight(),
		cash_discount(), insurance_fraud(), seed_capital(),
		maintenance_engraving(), high_voltage(), anchor_clause(), odds_bonus(),
		happy_hour(), interest(), free_spins(), double_loader(), calibration(),
		golden_handshake(),
		all_on_red(), blank_cheque(), superconductor(), gold_vein(), carbon_copy(),
		tournament_night(), power_spike(), seed_capital_ii(),
		benchmark_surcharge(), betting_tax(), empties(), deduction(),
		service_fee(), inflation(), power_cut(),
		benchmark_surcharge_ii(), half_payout(), stage_cap(), mains_hum(),
		discharge(), heat_warning(), rip_off(),
		benchmark_shock(), usury_clause(), blackout(), fuse_failure(), heat_buildup(),
		high_expectations(), all_in(), standard_protocol(), all_rounder(),
		tilted_floor(), balanced_scales(),
	]

## Alle Klausel-ids eines Topfes. Happy Hour liegt per also_treat in ZWEI Töpfen.
static func ids_for(clause_tier: Tier, clause_kind: Kind) -> Array[String]:
	var ids: Array[String] = []
	for clause in all():
		if clause.kind != clause_kind:
			continue
		if clause.tier == clause_tier or (clause_tier == Tier.TREAT and clause.also_treat):
			ids.append(clause.id)
	return ids

static func find(clause_id: String) -> DealClause:
	for clause in all():
		if clause.id == clause_id:
			return clause
	return null

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
			return "+24$ auf die Hand"
		BLANK_CHEQUE:
			return "+80$ auf die Hand"
		SEED_CAPITAL:
			return "+2 Energie sofort"
		SEED_CAPITAL_II:
			return "+4 Energie sofort"
		SAVINGS_BONUS:
			return "+2$ je übrigem Würfel"
		INSURANCE_FRAUD:
			return "Jeder Farkle zahlt 30$ Trost"
		HIGH_VOLTAGE:
			return "+6 Überladungs-Stufen"
		ODDS_BONUS, TOURNAMENT_NIGHT:
			return "Nebenwetten zahlen vierfach"
		HAPPY_HOUR:
			return "Alles Geld dieser Runde vierfach"
		ALL_ON_RED:
			return "Alles Geld dieser Runde sechsfach"
		INTEREST:
			return "Rundenende: +2$ je vollen 10$ Guthaben"
		DOUBLE_LOADER:
			return "Überladungs-Stufen prägen 4 Energie"
		CALIBRATION:
			return "Benchmark −75%"
		CASH_DISCOUNT:
			return "Ladenware 36% günstiger"
		GOLD_VEIN:
			return "+20$ je geräumter Überladungs-Stufe"
	return clause.text

static func tags_of(clause_id: String) -> Array[String]:
	var clause := find(clause_id)
	if clause == null:
		return []
	return clause.tags

static func has_tag(clause_id: String, tag: String) -> bool:
	return tags_of(clause_id).has(tag)

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
	return "Stresstest-Kondition"

## Ob die id überhaupt eine Klausel ist (Marken-Aufbau, Tests).
static func is_valid_id(clause_id: String) -> bool:
	return find(clause_id) != null
